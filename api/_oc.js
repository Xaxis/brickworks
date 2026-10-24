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
//     configuration, never from the request; while orangecheck's keys
//     cannot be read, a token is neither good nor bad, and is answered 503;
//   - the project's rule for who may sign in, even while it lets everyone;
//   - a token with no rh is refused, since nothing could end what it starts;
//   - the list of sessions people ended: an ended one is refused, and while
//     the list cannot be read no token is taken (taking one is a write),
//     which touches nobody signing in by email.
// OC_PROJECT_KEY and OC_SIGNING_SECRET are the project's (ochk.app). Without
// either, or without an audience, no token is taken here.
//
// Step 4 (2026-10-24): every token's rh is kept with its id (oc_handles,
// supabase/orangecheck_merge_connect.sql), so that once somebody merges two
// orangecheck accounts, the one they keep signs in to the Brickworks
// account the other had (merged). And orangecheck Connect, with
// OC_CONNECT_KEY: an orangecheck account made at the person's tick
// (provision), and deleted with their Brickworks account (unprovision).

import { isTestAccount } from "./_auth.js";
import { db } from "./_db.js";
import { audiences, ocConfigured } from "./_oc_config.js";
import {
  _resetJwksCachesForTests, bondMeets, checkOcToken, connectDelete, connectProvision, integratorRevocationCheck, matchMergedUser,
  mergedHandles,
} from "./_orangecheck.js";

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
/// null when it is not known. orangecheck's answer is {min_sats, min_days}
/// (/me/require-bond); max_age_secs is read only if it is ever there.
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
  _resetJwksCachesForTests();
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
  const checked = aud ? await checkOcToken(token.trim(), { audience: aud }).catch(() => ({ status: "invalid" })) : { status: "invalid" };
  if (checked.status === "unavailable") {
    return { status: 503, error: "orangecheck could not be asked just now. Try again in a minute, or sign in with your email." };
  }
  const session = checked.status === "valid" ? checked.session : null;
  const unended = checked.reason === "no_session_handle" || (session && (typeof session.rh !== "string" || !session.rh));
  if (unended) {
    return { status: 401, error: "That sign-in could never be ended from orangecheck, so Brickworks does not take it. Try again." };
  }
  if (!session || session.aud !== aud) return { status: 401, error: "That sign-in was not for Brickworks, or it has run out. Try again." };
  const { did_oc: did, jti, iat, exp } = session;
  if (!DID.test(String(did || "")) || typeof jti !== "string" || !jti || !Number.isFinite(iat) || !Number.isFinite(exp)) {
    return { status: 401, error: "That sign-in was not one Brickworks can read. Try again." };
  }
  const allowed = await whoMaySignIn();
  if (!allowed) return { status: 503, error: "orangecheck could not be asked just now. Try again in a minute, or sign in with your email." };
  if (allowed.kind === "backed"
    && !bondMeets(session, { minSats: allowed.minSats, minDays: allowed.minDays, maxAgeSecs: allowed.maxAgeSecs })) {
    return { status: 403, error: "Brickworks takes orangecheck accounts backed by bitcoin, and this one is not yet.", more: { back_url: BACK_URL } };
  }
  let state;
  try {
    state = await endedSessions().status({ rh: session.rh, aud, iat });
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

/// [session]'s rh kept with its id, for a merge to find later (merged).
/// Never in the way of the sign-in or link it came with: not kept is said
/// in the log, and only a later merge misses it.
export async function keepHandle(session) {
  try {
    const kept = await db("rpc/oc_keep_handle", { method: "POST", body: { did: session.did_oc, rh: session.rh, aud: session.aud } });
    if (kept !== true) console.error("orangecheck: a handle was not kept: its id is linked to no account");
  } catch (trouble) {
    console.error(`orangecheck: a handle was not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

/// The Brickworks account a merged orangecheck account had, for a checked
/// token whose id has none here: its merged_rh, our handle for each account
/// merged into it (read from the checked token alone), looked up among the
/// handles kept, by orangecheck's matchMergedUser. {account, email, was}
/// when they name one account, which is now the token's id's
/// (oc_follow_merge: was is the id it had, whose sessions there are ended;
/// email, the account's address); {conflict} when they name
/// two, and neither is picked; null when they name none, and the id is a
/// new person. Throws with again when the account changed under it (the
/// person tries again), or when the database cannot be asked.
export async function merged(session) {
  const handles = mergedHandles(session);
  if (!handles.length) return null;
  const rows = await db("rpc/oc_accounts_of_handles", { method: "POST", body: { handles, aud: session.aud } });
  const whose = new Map((Array.isArray(rows) ? rows : []).map((row) => [row.rh, row.account]));
  const match = await matchMergedUser(session, (rh) => whose.get(rh) || null);
  if (match.kind === "none") return null;
  if (match.kind === "conflict") {
    console.error(`orangecheck: merged handles name ${match.users.length} accounts; signed in to none`);
    return { conflict: match.users };
  }
  const moved = await db("rpc/oc_follow_merge", { method: "POST",
    body: { did: session.did_oc, account: match.user, handles, aud: session.aud } });
  if (!moved?.account) throw Object.assign(new Error("the merge no longer held"), { again: true });
  return { account: moved.account, email: moved.email || "", was: moved.was };
}

/// Whether orangecheck Connect is set up here: its key (ochk.app, the
/// project's Sign-in, Your own login). A unit's preview has none
/// (tools/deploy.sh --unit).
export function connectConfigured() {
  return Boolean(process.env.OC_CONNECT_KEY);
}

/// An orangecheck account made for [account], which ticked the box for it:
/// {made, did} or {made: false, reason}. Asked of orangecheck with consent
/// and the account's id; and with [emailed], when the request is a fresh
/// emailed code's for that address (codeOf), the address as verified, so
/// that signing in to ochk.app with it offers the account to claim. Written
/// down first, so deleting the account deletes that one too whatever the
/// answer. Never throws: a refusal or an outage is an answer, as Connect's
/// own calls give them.
export async function provision(account, emailed = null) {
  try {
    await db("rpc/oc_connect_asked", { method: "POST", body: { account } });
  } catch (trouble) {
    console.error(`orangecheck: Connect not asked, nothing kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { made: false, reason: "unavailable" };
  }
  let made;
  try {
    made = await connectProvision({ apiKey: process.env.OC_CONNECT_KEY, userId: account, consent: true,
      ...(emailed ? { email: emailed, emailVerified: true } : {}) });
  } catch (trouble) {
    console.error(`orangecheck: Connect: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { made: false, reason: "unavailable" };
  }
  if (!made.ok) {
    console.error(`orangecheck: Connect made no account: ${made.reason} ${made.status}`);
    return { made: false, reason: made.reason };
  }
  await db("rpc/oc_connect_made", { method: "POST", body: { account, did: made.did_oc } })
    .catch((trouble) => console.error(`orangecheck: Connect's id not kept: ${String(trouble?.message || trouble).slice(0, 120)}`));
  return { made: true, did: made.did_oc };
}

/// The orangecheck account Connect made for [account], asked to be deleted
/// before the account itself is (site-attest's L1, 2026-10-24: a person can
/// always delete their Brickworks account):
///   "gone"    deleted, the person's own now they claimed it, or never made;
///   "kept"    orangecheck refuses for good (it holds earnings, or cannot be
///             erased): it stays theirs at ochk.app, and ours goes all the
///             same;
///   "outage"  orangecheck could not be asked, or asks us to wait: try again;
///   "unset"   no Connect key here (nothing is asked), or orangecheck does not
///             know it: Brickworks' setup fault, so nothing is deleted until
///             it is fixed (orangecheck's final ruling).
const CONNECT_OUTAGES = new Set(["unavailable", "rate_limited"]);
const CONNECT_UNSET = new Set(["invalid_api_key"]);
export async function unprovision(account) {
  if (!connectConfigured()) return "unset";
  let gone;
  try {
    gone = await connectDelete({ apiKey: process.env.OC_CONNECT_KEY, userId: account });
  } catch (trouble) {
    console.error(`orangecheck: Connect: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return "outage";
  }
  if (gone.ok || gone.reason === "unknown_user") return "gone";
  console.error(`orangecheck: Connect did not delete an account: ${gone.reason} ${gone.status}`);
  if (CONNECT_OUTAGES.has(gone.reason)) return "outage";
  if (CONNECT_UNSET.has(gone.reason)) return "unset";
  return "kept";
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

/// [claims]'s session ended here, refused in [words]: Supabase's row
/// deleted, so it cannot be renewed either.
async function endHere(claims, session, words) {
  try {
    await db("rpc/oc_end_session", { method: "POST", body: { session: claims.session_id } });
  } catch (trouble) {
    console.error(`orangecheck: a session was not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
  standings.set(claims.session_id, { at: Date.now(), value: { ...session, exists: false } });
  return { refused: words, status: 401 };
}

/// Whether the session behind [claims], an account that has orangecheck,
/// may go on with a request of [method]: {} when it may, or {refused,
/// status} in words. A session that is gone (signed out, unlinked, ended)
/// is refused. One orangecheck started is refused once the person ended
/// every session on orangecheck, or once the id that started it is no
/// longer the account's, and ended here too; while that cannot be known
/// (the list, or this session's binding, cannot be read), it reads but does
/// not write. An emailed code's session of the same account is asked only
/// whether it is still there. An orangecheck account's made-up address
/// takes no code (api/otp.js), so orangecheck starts every session it has:
/// one it did not, by a password set from one of its sessions (oc188's
/// review, H1), is ended.
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
  if (!session.bound) {
    return madeUp(claims.email)
      ? endHere(claims, session, "That sign-in was not made with orangecheck, so it has ended. Sign in with orangecheck.")
      : {};
  }
  if (session.linked === false) {
    return endHere(claims, session, "orangecheck was unlinked from this account, so this sign-in has ended. Sign in again.");
  }
  if (!(process.env.OC_PROJECT_KEY && process.env.OC_SIGNING_SECRET)) return unsure;
  let state;
  try {
    state = await endedSessions().status({ rh: session.rh, aud: session.aud, iat: Number(session.iat) });
  } catch {
    state = "unverified";
  }
  if (state === "revoked") {
    return endHere(claims, session, "You signed out of orangecheck everywhere, so this sign-in has ended. Sign in again.");
  }
  return state === "live" ? {} : unsure;
}

// How recent an emailed code must be for linking, unlinking, or deleting
// from a session orangecheck started: the person has just proved the inbox,
// not merely that a tab of theirs was open.
const FRESH_SECONDS = 300;

/// The session behind [claims], as linking, unlinking and deleting ask
/// after it: {bound, fresh, emailed}. bound, when orangecheck started it;
/// fresh, when it is an emailed code of the last five minutes; emailed, the
/// address that code went to, when it is one (amr otp alone, never a test
/// account's password), which Connect may send orangecheck as verified
/// (orangecheck's answer, 2026-10-24). A session
/// orangecheck started says "otp" too (it is minted from a one-time link),
/// so it is told apart by its binding, and is never fresh. Nor is a
/// password, but a test account's (tools/web/session.mjs), whose address
/// nobody can receive mail at: anybody signed in could set a password on
/// their account (oc188's review, H1; supabase/no_new_ways_in.sql now
/// refuses it). Throws when the binding cannot be read.
export async function codeOf(claims) {
  const session = claims.session_id ? await sessionOf(claims.session_id) : null;
  const amr = Array.isArray(claims.amr) ? claims.amr : [];
  const bound = Boolean(session && session.bound);
  const recent = (one) => Boolean(one && session && session.exists && !bound
    && Date.now() / 1000 - Number(one.timestamp) <= FRESH_SECONDS);
  const fresh = recent(amr.find((one) => one?.method === "otp" || (one?.method === "password" && isTestAccount(claims))));
  const address = String(claims.email || "").trim().toLowerCase();
  const emailed = recent(amr.find((one) => one?.method === "otp")) && address && !madeUp(address) ? address : null;
  return { bound, fresh, emailed };
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
