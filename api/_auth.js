// Verifying a Brickworks sign-in, server side.
//
// Everyone who uses Brickworks has an account (2026-10-11): an email
// address, signed in with a code sent to it (api/otp.js). Supabase holds
// the accounts and issues the session; this checks the access token a
// client sends as "Authorization: Bearer …".
//
// Supabase signs its access tokens with ES256 and publishes the public
// half at a JWKS endpoint, so a token is checked here with no call back
// to Supabase on the hot path — a signature check against a cached key.
// The relay (api/mcp.js) asks this on every connector switching on.
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

/// Whether this deployment has accounts at all. One without Supabase
/// configured (a local server, somebody's own copy) has nothing to sign
/// in to, and the app then does not ask.
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

  let response;
  try {
    response = await fetch(`${base}/auth/v1/.well-known/jwks.json`, {
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    response = null;
  }
  if (!response || !response.ok) {
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
///
/// [request], when given, is what the token came with: its method says
/// whether it reads or writes, which matters to an account that has
/// orangecheck (below).
export async function verify(token, request = null) {
  if (!token) throw new AuthError("sign in to Brickworks first");

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

  // An account that has orangecheck (2026-10-23, api/orangecheck.js), or
  // the made-up address of one, has its session asked after: still there,
  // and if orangecheck started it, not ended everywhere on orangecheck.
  // Everybody else's never is, so nothing about orangecheck, working or
  // not, touches them; and its code is loaded only for those who have it.
  if (claims.app_metadata?.orangecheck === true || /@oc\.brickworks\.diy$/i.test(String(claims.email || ""))) {
    const { sessionStanding } = await import("./_oc.js");
    const standing = await sessionStanding(claims, request?.method);
    if (standing.refused) throw new AuthError(standing.refused, standing.status);
  }

  // Brickworks signs people in with an emailed code or with orangecheck,
  // never a password. Supabase let anybody signed in set one on their
  // account and sign in with it: a session nothing here started, which
  // neither unlinking nor ending every session on orangecheck could end
  // (oc188's review, H1). It now refuses to (supabase/no_new_ways_in.sql);
  // a password session that gets here all the same is refused, and ended,
  // but a test account's (tools/web/session.mjs), whose address nobody
  // receives mail at.
  if (signedInByPassword(claims) && !isTestAccount(claims)) {
    await endSession(claims.session_id);
    throw new AuthError("Brickworks signs you in with a code we email you or with orangecheck, never a password. "
      + "Sign in again.", 403);
  }

  return claims;
}

function signedInByPassword(claims) {
  return (Array.isArray(claims.amr) ? claims.amr : []).some((one) => one?.method === "password");
}

/// Supabase's session [id] deleted, with its refresh tokens: it cannot be
/// renewed. Said in the log when it cannot be.
async function endSession(id) {
  if (!id) return;
  try {
    const { db } = await import("./_db.js");
    await db("rpc/oc_end_session", { method: "POST", body: { session: id } });
  } catch (trouble) {
    console.error(`auth: a password session was not ended: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

export function bearer(request) {
  const header = request.headers?.authorization || request.headers?.Authorization || "";
  const match = /^Bearer\s+(.+)$/i.exec(String(header).trim());
  return match ? match[1].trim() : null;
}

/// The owner's account: the one that can see /api/admin.
///
/// Set MASTER_EMAIL on the project; unset means nobody, which fails
/// closed rather than open.
export function isMaster(claims) {
  const master = (process.env.MASTER_EMAIL || "").trim().toLowerCase();
  if (!master) return false;
  const email = String(claims?.email || "").trim().toLowerCase();
  // email_verified is Supabase's word for "this address answered". An
  // unverified one is a claim about somebody else's inbox.
  if (claims?.email_verified === false) return false;
  return email !== "" && email === master;
}

/// Whether the session is a test's: signed in at a Resend test address,
/// as every probe and flow is (tools/web/session.mjs, SignInHelper). Mail
/// to resend.dev reaches nobody, so no person can sign in at one. What
/// such an account publishes is marked a test and kept out of every public
/// list (api/share.js, supabase/test_models.sql).
export function isTestAccount(claims) {
  return /@resend\.dev$/i.test(String(claims?.email || "").trim());
}
