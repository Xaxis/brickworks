// Verifying a Brickworks sign-in, server side.
//
// Everyone who uses Brickworks has an account (2026-10-11): an email
// address, signed in with a code sent to it (api/otp.js). Supabase holds
// the accounts and issues the session; this checks the access token a
// client sends as "Authorization: Bearer …".
//
// Supabase signs its access tokens with ES256 and publishes the public
// half at a JWKS endpoint, so a token's signature is checked here against
// a cached key; whether its session is still there is one read of the
// database, held a few seconds (sessionOf). The relay (api/mcp.js) asks
// this on every connector switching on.
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

  // An account that has orangecheck (2026-10-23, api/orangecheck.js), or
  // the made-up address of one, has its session asked after: still there,
  // and if orangecheck started it, not ended everywhere on orangecheck.
  // Its code is loaded only for those who have it.
  if (claims.app_metadata?.orangecheck === true || /@oc\.brickworks\.diy$/i.test(String(claims.email || ""))) {
    const { sessionStanding } = await import("./_oc.js");
    const standing = await sessionStanding(claims, request?.method);
    if (standing.refused) throw new AuthError(standing.refused, standing.status);
    return claims;
  }

  // Everybody else's session is asked whether it is still there. A
  // signature says only who Supabase gave the token to, for an hour: Sign
  // out everywhere (/admin, admin_sign_out) deletes the account's sessions,
  // and before 2026-11-18 every token they had handed out went on working
  // here until it ran out (c3review). A token is refused once its session
  // is gone, however that went: signed out everywhere, signed out of that
  // device (the app's Sign out), deleting the account. One handed out
  // after, by a new sign-in, has a new session and works.
  await stillSignedIn(claims, request?.method);
  return claims;
}

// What Supabase holds of each session (rpc/oc_session_of, supabase/
// orangecheck.sql: {exists, bound, did, rh, aud, iat, linked}), read at
// most once in SESSION_HELD_MS an instance: a page asks several routes at
// once, and most calls then cost no round trip. A session found there is
// asked again after that; one found gone never comes back (Supabase never
// makes a session again under its id), so it is held for good. Each
// instance reads for itself, so a session ended is refused within
// SESSION_HELD_MS everywhere, and at once by an instance that had not read
// it in that time. Shared with api/_oc.js, which asks the same of an
// orangecheck session.
const sessions = new Map();
export const SESSION_HELD_MS = 5000;
// How long that read is waited for. It is in the way of every signed-in
// call: given the 15 s of any other read, a slow database held each one 15 s
// before the rule below let a read go on (s5review). After it, as when the
// database is down: reads go on, writes are refused for now (503).
export const SESSION_READ_S = 3;
const READS = new Set(["GET", "HEAD", "OPTIONS"]);

/// The session [id], as Supabase holds it: {exists, ...}. Throws when the
/// database cannot be asked. Calls made at once share one read.
export async function sessionOf(id) {
  const held = sessions.get(id);
  if (held && (held.gone || Date.now() - held.at < SESSION_HELD_MS)) return held.read;
  const { db } = await import("./_db.js");
  if (sessions.size > 2000) sessions.clear();
  const entry = { at: Date.now(), gone: false, read: db("rpc/oc_session_of", { method: "POST", body: { session: id },
    seconds: SESSION_READ_S }) };
  sessions.set(id, entry);
  try {
    const value = await entry.read;
    if (value?.exists === false) entry.gone = true;
    return value;
  } catch (trouble) {
    if (sessions.get(id) === entry) sessions.delete(id);
    throw trouble;
  }
}

/// The session [id] known to be gone, as [value] was (ended here).
export function sessionEnded(id, value = {}) {
  if (!id) return;
  sessions.set(id, { at: Date.now(), gone: true, read: Promise.resolve({ ...value, exists: false }) });
}

/// The way, google or github, that started session [id] (api/_ways.js
/// keep, supabase/sign_in_ways.sql), or null: an emailed code's,
/// orangecheck's, a test password's. Throws when the database cannot be
/// asked.
export async function sessionWay(id) {
  const { db } = await import("./_db.js");
  const way = await db("rpc/way_session_of", { method: "POST", body: { session: id }, seconds: SESSION_READ_S });
  return way === "google" || way === "github" ? way : null;
}

/// Who started the session behind [claims], when it was not a code to its
/// address (or a test account's password): "google" or "github"
/// (way_sessions), "orangecheck" (bound, oc_sessions), else null. The
/// owner's console opens to none of them (signin4, F8). Throws when the
/// database cannot be asked.
export async function startedBy(claims) {
  if (!claims?.session_id) return null;
  const [session, way] = await Promise.all([sessionOf(claims.session_id), sessionWay(claims.session_id)]);
  return way || (session?.bound ? "orangecheck" : null);
}

/// What this instance has read of sessions, forgotten (for tests).
export function forgetSessions() {
  sessions.clear();
}

/// Throws when the session behind [claims] is gone. While that cannot be
/// known (the database is not answering), a request of [method] that reads
/// goes on and one that writes is refused for now, as an orangecheck
/// session's is (api/_oc.js sessionStanding). A token with no session_id
/// is not one Supabase hands a person (every sign-in grant writes one), so
/// it has nothing to ask after.
async function stillSignedIn(claims, method) {
  if (!claims.session_id) return;
  let session;
  try {
    session = await sessionOf(claims.session_id);
  } catch (trouble) {
    console.error(`auth: a session was not read: ${String(trouble?.message || trouble).slice(0, 120)}`);
    session = null;
  }
  if (session?.exists === false) throw new AuthError("You were signed out. Sign in again.");
  if (session?.exists !== true && !READS.has(String(method || "POST").toUpperCase())) {
    throw new AuthError("Brickworks could not check your sign-in just now. Try again in a minute.", 503);
  }
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
