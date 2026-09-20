// Verifying a Brickworks sign-in, server side.
//
// Supabase signs its access tokens with ES256 and publishes the public
// half at a JWKS endpoint, which means this can be checked here with no
// call back to Supabase on the hot path — a signature check against a
// cached key instead of a network round trip per design. That matters:
// the assistant endpoint is already waiting on Claude, and adding a
// second hop before it starts would be felt.
//
// No libraries. Node's WebCrypto does ECDSA, and a JWT is three
// base64url segments; pulling in a JWT package to do that would be more
// supply chain than the job is worth.
//
// A token this rejects is one the caller cannot fix by retrying, so the
// failures below are named rather than boolean — the endpoint turns them
// into something a person can act on.

import { webcrypto } from "node:crypto";

const JWKS_TTL_MS = 10 * 60_000;
// Long enough to survive a key rotation without a thundering herd,
// short enough that a revoked key stops working the same morning.
let cached = { at: 0, keys: null, url: null };

export class AuthError extends Error {
  constructor(reason, status = 401) {
    super(reason);
    this.status = status;
  }
}

function projectUrl() {
  const url = process.env.SUPABASE_URL;
  return url ? url.replace(/\/+$/, "") : null;
}

/// Whether this deployment has accounts at all. A build without Supabase
/// configured is a legitimate deployment — it just has no assistant —
/// so this is a question, not an assertion.
export function authConfigured() {
  return Boolean(projectUrl() && process.env.SUPABASE_PUBLISHABLE_KEY);
}

function b64urlToBytes(segment) {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/");
  return Buffer.from(padded, "base64");
}

async function jwks() {
  const base = projectUrl();
  const fresh = cached.keys && cached.url === base && Date.now() - cached.at < JWKS_TTL_MS;
  if (fresh) return cached.keys;

  const response = await fetch(`${base}/auth/v1/.well-known/jwks.json`, {
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) {
    // Keep serving the stale set rather than locking everyone out over a
    // blip at the key endpoint. An expired cache is a weaker guarantee
    // than a fresh one; no cache at all is an outage.
    if (cached.keys && cached.url === base) return cached.keys;
    throw new AuthError("cannot reach the sign-in service", 503);
  }
  const body = await response.json();
  cached = { at: Date.now(), keys: body.keys || [], url: base };
  return cached.keys;
}

const ALGORITHMS = {
  ES256: { import: { name: "ECDSA", namedCurve: "P-256" }, verify: { name: "ECDSA", hash: "SHA-256" } },
  RS256: { import: { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, verify: { name: "RSASSA-PKCS1-v1_5" } },
};

/// Check a bearer token and return its claims. Throws AuthError with a
/// reason the caller can show, never a bare false — "your session ran
/// out" and "that is not a token" want different words on screen.
export async function verify(token) {
  if (!token) throw new AuthError("sign in to use the design assistant");

  const parts = token.split(".");
  if (parts.length !== 3) throw new AuthError("that sign-in is not readable");

  let header;
  let claims;
  try {
    header = JSON.parse(b64urlToBytes(parts[0]).toString("utf8"));
    claims = JSON.parse(b64urlToBytes(parts[1]).toString("utf8"));
  } catch {
    throw new AuthError("that sign-in is not readable");
  }

  const algorithm = ALGORITHMS[header.alg];
  // Named explicitly, because "whatever the header says" includes "none".
  if (!algorithm) throw new AuthError("that sign-in uses an algorithm we do not accept");

  const key = (await jwks()).find((candidate) => candidate.kid === header.kid);
  if (!key) throw new AuthError("that sign-in was issued by a key we do not know");

  const publicKey = await webcrypto.subtle.importKey(
    "jwk",
    { ...key, ext: true },
    algorithm.import,
    false,
    ["verify"],
  );
  const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const ok = await webcrypto.subtle.verify(
    algorithm.verify,
    publicKey,
    b64urlToBytes(parts[2]),
    signed,
  );
  if (!ok) throw new AuthError("that sign-in did not check out");

  // Signature first, claims second. Checking expiry before the signature
  // would mean trusting a number an attacker wrote.
  const now = Math.floor(Date.now() / 1000);
  if (typeof claims.exp === "number" && claims.exp < now) {
    throw new AuthError("your session ran out — sign in again");
  }
  const issuer = `${projectUrl()}/auth/v1`;
  if (claims.iss !== issuer) throw new AuthError("that sign-in is for somewhere else");
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audience.includes("authenticated")) throw new AuthError("that sign-in is not for a person");
  if (!claims.sub) throw new AuthError("that sign-in names nobody");

  return claims;
}

export function bearer(request) {
  const header = request.headers.authorization || request.headers.Authorization || "";
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : null;
}

/// Ask Postgres, as the service role, for the caller's tier and their
/// place against this month's budget — in one statement, so two requests
/// landing together cannot both decide they were under it.
///
/// [design] names the conversation. A design is a dozen round trips and
/// sometimes forty, so every turn of one claims against the same id and
/// only the first costs anything. Without it a single lighthouse spent
/// six of a sixty-a-month budget.
export async function claimDesign(account, tier, design) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) throw new AuthError("accounts are not fully configured here", 503);

  const budget = BUDGETS[tier] ?? BUDGETS.builder;
  const response = await fetch(`${projectUrl()}/rest/v1/rpc/claim_design`, {
    method: "POST",
    headers: {
      apikey: secret,
      authorization: `Bearer ${secret}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ account, budget, design: design || null }),
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) throw new AuthError("could not check your remaining designs", 503);

  const [row] = await response.json();
  return { allowed: Boolean(row?.allowed), used: row?.used ?? 0, budget };
}

/// Designs — conversations, not requests — per calendar month. Generous
/// enough that nobody building for an evening meets it, low enough that
/// a leaked password cannot empty the account.
export const BUDGETS = { builder: 60, pro: 400 };

/// A conversation id from the client, reduced to something safe to store
/// and impossible to use as an injection. Anything unusable becomes null
/// and Postgres invents one, which costs the caller a design per turn —
/// the right way round for a client that cannot follow the protocol.
export function designId(raw) {
  if (typeof raw !== "string") return null;
  const clean = raw.trim().slice(0, 64);
  return /^[A-Za-z0-9_-]{8,64}$/.test(clean) ? clean : null;
}

export async function tierFor(account) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) return "builder";
  try {
    const response = await fetch(
      `${projectUrl()}/rest/v1/profiles?select=tier&id=eq.${encodeURIComponent(account)}`,
      {
        headers: { apikey: secret, authorization: `Bearer ${secret}` },
        signal: AbortSignal.timeout(5000),
      },
    );
    if (!response.ok) return "builder";
    const [row] = await response.json();
    return row?.tier || "builder";
  } catch {
    // A profile that cannot be read is treated as the standard tier
    // rather than as no access: the row exists, we just could not see
    // it, and locking a paying account out over a timeout is worse than
    // briefly giving a pro account the smaller budget.
    return "builder";
  }
}
