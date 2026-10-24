// An orangecheck token, checked (2026-10-23): what signing in with
// orangecheck (api/orangecheck.js) and deleting an orangecheck account
// (api/account.js) both ask of the token orangecheck's window hands a page.
// And a session orangecheck started, asked after on each request
// (sessionStanding, from api/_auth.js), so "Sign out everywhere" on
// orangecheck ends it here within about two minutes.
//
// From orangecheck's public docs (ochk.io/docs/me/quickstart and /me/sdk),
// with its own code for the checks (api/_orangecheck.js, made by
// tools/web/vendor_orangecheck.sh):
//   - the signature and the audience: this deployment's own origin, from
//     configuration, never from the request;
//   - the project's rule for who may sign in, even while it lets everyone;
//   - a token with no rh is refused, since nothing could end what it starts;
//   - the list of sessions people ended: an ended one is refused, and while
//     the list cannot be read no token is taken (taking one is a write),
//     which touches nobody signing in by email.
// OC_PROJECT_KEY and OC_SIGNING_SECRET are the project's (ochk.app). Without
// either, or without an audience, no token is taken here.

import { db } from "./_db.js";
import { audiences, ocConfigured } from "./_oc_config.js";
import { bondMeets, integratorRevocationCheck, verifyOcToken } from "./_orangecheck.js";

export { audiences, ocConfigured };

const DID = /^did:oc:[0-9a-f]{32}$/;
const ME = "https://me.ochk.io";
const AUTH_HOST = "https://ochk.io";
const BACK_URL = "https://ochk.app/me/account#backing";

/// Whether an address is one an orangecheck account was made with
/// (api/orangecheck.js): random, at a domain that takes no mail.
export function madeUp(address) {
  return /@oc\.brickworks\.diy$/i.test(String(address || ""));
}

/// The audience [token] names, unchecked: only to choose which of ours to
/// check it against.
function namedAudience(token) {
  try {
    return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8")).aud;
  } catch {
    return undefined;
  }
}

// Said once an instance, loudly, in production: a deployment without the
// project's key and secret could never hear that somebody ended their
// sessions, so it takes no token rather than start sessions nobody can end.
if (process.env.VERCEL_ENV === "production" && !(process.env.OC_PROJECT_KEY && process.env.OC_SIGNING_SECRET)) {
  console.error("orangecheck: OC_PROJECT_KEY or OC_SIGNING_SECRET is not set; nobody can sign in with orangecheck");
}

// One list of ended sessions an instance (orangecheck's own check, read at
// most once a minute an audience).
let ended = null;
function endedSessions() {
  ended ||= integratorRevocationCheck({
    projectKey: process.env.OC_PROJECT_KEY,
    signingSecret: process.env.OC_SIGNING_SECRET,
  });
  return ended;
}

// The project's rule for who may sign in, read from orangecheck at most
// once a minute; when it cannot be read, the last one read stands for ten
// minutes, and after that no token is taken until it can.
let rule = { at: 0, tried: 0, value: undefined };

/// {kind: "everyone"} or {kind: "backed", minSats, minDays, maxAgeSecs}, or
/// null when it is not known.
async function whoMaySignIn() {
  const now = Date.now();
  const known = rule.value !== undefined;
  if (known && now - rule.at < 60_000) return rule.value;
  if (now - rule.tried >= 10_000) {
    rule.tried = now;
    try {
      const reply = await fetch(`${ME}/api/integrator/${encodeURIComponent(process.env.OC_PROJECT_KEY)}/sign-in`, {
        signal: AbortSignal.timeout(4000) });
      const body = await reply.json();
      if (!reply.ok || body?.ok !== true || !("require_bond" in body)) throw new Error(`answered ${reply.status}`);
      const bond = body.require_bond;
      let value;
      if (bond === null) value = { kind: "everyone" };
      else if (bond && Number.isFinite(bond.min_sats) && Number.isFinite(bond.min_days)) {
        value = { kind: "backed", minSats: bond.min_sats, minDays: bond.min_days,
          ...(Number.isFinite(bond.max_age_secs) ? { maxAgeSecs: bond.max_age_secs } : {}) };
      } else throw new Error("a rule it does not state plainly");
      rule = { at: now, tried: now, value };
      return value;
    } catch (trouble) {
      console.error(`orangecheck: who may sign in was not read: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
  return known && now - rule.at < 600_000 ? rule.value : null;
}

/// What this instance has read from orangecheck, forgotten: for
/// tools/web/orangecheck_check.mjs, which changes what orangecheck says.
export function forgetForTests() {
  rule = { at: 0, tried: 0, value: undefined };
  ended = null;
  standings.clear();
}

/// [token] checked: {session} with its claims (did_oc, jti, rh, aud, iat,
/// exp), or {status, error, more} to answer with, in words. Not spent:
/// spendToken does that.
export async function checkToken(token) {
  if (!ocConfigured()) return { status: 503, error: "Signing in with orangecheck is unavailable here. Sign in with your email instead." };
  if (typeof token !== "string" || !token.trim() || token.length > 8192) {
    return { status: 422, error: "The sign-in did not come through from orangecheck. Try again." };
  }
  const aud = audiences().find((one) => one === namedAudience(token.trim()));
  const session = aud ? await verifyOcToken(token.trim(), { audience: aud }).catch(() => null) : null;
  if (!session || session.aud !== aud) return { status: 401, error: "That sign-in was not for Brickworks, or it has run out. Try again." };
  const { did_oc: did, jti, rh, iat, exp } = session;
  if (!DID.test(String(did || "")) || typeof jti !== "string" || !jti || !Number.isFinite(iat) || !Number.isFinite(exp)) {
    return { status: 401, error: "That sign-in was not one Brickworks can read. Try again." };
  }
  if (typeof rh !== "string" || !rh) {
    return { status: 401, error: "That sign-in could never be ended from orangecheck, so Brickworks does not take it. Try again." };
  }
  const allowed = await whoMaySignIn();
  if (!allowed) return { status: 503, error: "orangecheck could not be asked just now. Try again in a minute, or sign in with your email." };
  if (allowed.kind === "backed"
    && !bondMeets(session, { minSats: allowed.minSats, minDays: allowed.minDays, maxAgeSecs: allowed.maxAgeSecs })) {
    return { status: 403, error: "Brickworks takes orangecheck accounts backed by bitcoin, and this one is not yet.", more: { back_url: BACK_URL } };
  }
  let state;
  try {
    state = await endedSessions().status({ rh, aud, iat });
  } catch {
    state = "unverified";
  }
  if (state === "revoked") return { status: 401, error: "That orangecheck sign-in was ended. Sign in again." };
  if (state !== "live") {
    return { status: 503, error: "orangecheck could not confirm the sign-in just now. Try again in a minute, or sign in with your email." };
  }
  return { session };
}

/// [jti] spent until [exp] (seconds): true the first time, false ever after
/// while the token lasts, on every instance. Throws when it cannot be asked.
export async function spendToken(jti, exp) {
  return (await db("rpc/oc_spend", { method: "POST", body: { token_id: jti, until: new Date(exp * 1000).toISOString() } })) === true;
}

/// The token ended at orangecheck once it has been taken, so it is good for
/// nothing anywhere else either. Its id is spent here whatever orangecheck
/// answers.
export async function endToken(token) {
  try {
    const reply = await fetch(`${AUTH_HOST}/api/auth/revoke`, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ tokens: [token] }), signal: AbortSignal.timeout(5000) });
    if (!reply.ok) console.error(`orangecheck: the token was not ended there: ${reply.status}`);
  } catch (trouble) {
    console.error(`orangecheck: the token was not ended there: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

// What a session was found to be, for a few seconds an instance: a page
// asks several routes at once, and an ended session must still be refused
// within seconds of being found ended.
const standings = new Map();
const HELD_MS = 5000;
const READS = new Set(["GET", "HEAD", "OPTIONS"]);

async function sessionOf(id) {
  const held = standings.get(id);
  if (held && Date.now() - held.at < HELD_MS) return held.value;
  const value = await db("rpc/oc_session_of", { method: "POST", body: { session: id } });
  if (standings.size > 2000) standings.clear();
  standings.set(id, { at: Date.now(), value });
  return value;
}

/// Whether the session behind [claims], an account that has orangecheck,
/// may go on with a request of [method]: {} when it may, or {refused,
/// status} in words. A session that is gone (signed out, unlinked, ended)
/// is refused. One orangecheck started is refused once the person ended
/// every session on orangecheck, and ended here too; while that cannot be
/// known (the list, or this session's binding, cannot be read), it reads
/// but does not write. An emailed code's session of the same account is
/// asked only whether it is still there.
export async function sessionStanding(claims, method) {
  const write = !READS.has(String(method || "POST").toUpperCase());
  const unsure = write
    ? { refused: "Brickworks could not check your orangecheck sign-in just now. Try again in a minute.", status: 503 }
    : {};
  if (!claims.session_id) return unsure;
  let session;
  try {
    session = await sessionOf(claims.session_id);
  } catch (trouble) {
    console.error(`orangecheck: a session was not read: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return unsure;
  }
  if (!session || session.exists === false) return { refused: "You were signed out. Sign in again.", status: 401 };
  if (!session.bound) return {};
  if (!(process.env.OC_PROJECT_KEY && process.env.OC_SIGNING_SECRET)) return unsure;
  let state;
  try {
    state = await endedSessions().status({ rh: session.rh, aud: session.aud, iat: Number(session.iat) });
  } catch {
    state = "unverified";
  }
  if (state === "revoked") {
    try {
      await db("rpc/oc_end_session", { method: "POST", body: { session: claims.session_id } });
    } catch (trouble) {
      console.error(`orangecheck: an ended session was not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    standings.set(claims.session_id, { at: Date.now(), value: { ...session, exists: false } });
    return { refused: "You signed out of orangecheck everywhere, so this sign-in has ended. Sign in again.", status: 401 };
  }
  return state === "live" ? {} : unsure;
}

/// Whether a Claude connection approved while signed in with orangecheck
/// (its oc_rh, oc_aud and oc_iat) still stands: "live", "revoked" once the
/// person ended every session on orangecheck, or "unverified" while that
/// cannot be known.
export async function grantStanding(grant) {
  if (!(process.env.OC_PROJECT_KEY && process.env.OC_SIGNING_SECRET)) return "unverified";
  try {
    return await endedSessions().status({ rh: grant.oc_rh, aud: grant.oc_aud, iat: Number(grant.oc_iat) });
  } catch {
    return "unverified";
  }
}
