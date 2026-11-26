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
//   - the list of sessions people ended: an ended one is refused, and so,
//     at the exchange alone, is a token ended by its own id (site-attest,
//     2026-10-24); while the list cannot be read no token is taken (taking
//     one is a write), which touches nobody signing in by email.
// OC_PROJECT_KEY and OC_SIGNING_SECRET are the project's (ochk.app). Without
// either, or without an audience, no token is taken here.
//
// Step 4 (2026-10-24): every token's rh is kept with its id (oc_handles,
// supabase/orangecheck_merge_connect.sql), so that once somebody merges two
// orangecheck accounts, the one they keep signs in to the Brickworks
// account the other had (merged). And orangecheck Connect, with
// OC_CONNECT_KEY: an orangecheck account made for the person as they sign in
// (ensureOrangecheck, provision; at their tick of a box until signin3), and
// deleted with their Brickworks account (unprovision).
//
// The desktop app (2026-10-24, oc237): it cannot open orangecheck's window,
// so it opens orangecheck in the person's own browser, which hands a
// one-time code back to the app on 127.0.0.1; the app posts the code here
// with its PKCE verifier, traded at orangecheck for the token the window
// would have given (tradeCode, me-client's exchangeNativeCode). From there
// the token is taken as the window's is: checkToken, then the same
// sign-in.

import { AuthError, forgetSessions, isTestAccount, sessionEnded, sessionOf, standingOf } from "./_auth.js";
import { db } from "./_db.js";
import { audiences, nativeOffered, ocConfigured, ocHosts } from "./_oc_config.js";
import {
  _resetJwksCachesForTests, bondMeets, checkOcToken, connectDelete, connectProvision, exchangeNativeCode, integratorRevocationCheck,
  matchMergedUser, mergedHandles,
} from "./_orangecheck.js";

export { audiences, nativeOffered, ocConfigured };

const DID = /^did:oc:[0-9a-f]{32}$/;
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
    meOrigin: ocHosts().me,
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
      const reply = await fetch(`${ocHosts().me}/api/integrator/${encodeURIComponent(process.env.OC_PROJECT_KEY)}/sign-in`, {
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
  forgetSessions();
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
  const checked = aud
    ? await checkOcToken(token.trim(), { audience: aud, issuer: ocHosts().auth }).catch(() => ({ status: "invalid" }))
    : { status: "invalid" };
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
  // With the token's own id here, at the exchange: a token orangecheck
  // ended by itself (its revoke) before it reached us is refused
  // (site-attest). Never on the requests after (sessionStanding,
  // grantStanding): endToken revokes this very token right after the
  // exchange, and its id on the list must sign nobody out. Its sub too:
  // orangecheck folds the ended tokens it can no longer list one by one
  // under the account (sub), not the handle, so a check without it would
  // take a token ended and folded before it reached us (ochk-95, 11-21).
  let state;
  try {
    state = await endedSessions().status({ rh: session.rh, aud, iat, jti, sub: session.sub });
  } catch {
    state = "unverified";
  }
  if (state === "revoked") return { status: 401, error: "That orangecheck sign-in was ended. Sign in again." };
  if (state !== "live") {
    return { status: 503, error: "orangecheck could not confirm the sign-in just now. Try again in a minute, or sign in with your email." };
  }
  return { session };
}

/// The desktop app's code (api/orangecheck.js ?op=native) traded at
/// orangecheck for its token, by me-client's exchangeNativeCode: the code
/// with the verifier its challenge was made from and the exact loopback
/// address it was sent to, for this project, bound to this deployment's
/// audience, checked against the list of ended sessions (the trade is a
/// write) and the project's rule. {token}, which the caller then takes as
/// it takes the window's (checkToken, and the rest of the sign-in); or
/// {status, error, more} to answer with, in words. A code works once,
/// whatever the answer, so each refusal asks for a new sign-in.
export async function tradeCode({ code, verifier, redirect }) {
  const { auth, me } = ocHosts();
  let out;
  try {
    out = await exchangeNativeCode({ code, codeVerifier: verifier, redirectUri: redirect, audience: audiences()[0] },
      { projectKey: process.env.OC_PROJECT_KEY.trim(), issuer: auth, meOrigin: me, revocation: endedSessions() });
  } catch (trouble) {
    // What it refuses by throwing is a malformed input.
    console.error(`orangecheck: a code was not traded: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { status: 422, error: "The sign-in did not come through from orangecheck. Try again." };
  }
  if (out.status === "valid") return { token: out.token };
  if (out.status === "unavailable") {
    console.error(`orangecheck: a code was not traded: ${out.reason}`);
    return { status: 503, error: "orangecheck could not be asked just now. Sign in with orangecheck again in a minute, or with your email." };
  }
  if (out.reason === "bond_required") {
    return { status: 403, error: "Brickworks takes orangecheck accounts backed by bitcoin, and this one is not yet.", more: { back_url: BACK_URL } };
  }
  if (out.reason === "session_ended") return { status: 401, error: "That orangecheck sign-in was ended. Sign in again." };
  if (out.reason === "not_offered" || out.reason === "unknown_project_key") {
    console.error(`orangecheck: a code was not traded: ${out.reason}`);
    return { status: 503, error: "Signing in with orangecheck from the app is not offered just now. Sign in with your email instead." };
  }
  return { status: 401, error: "That sign-in ran out, was used already, or was not for Brickworks. Sign in with orangecheck again." };
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

/// An orangecheck account made for [account], which signed in, told that
/// signing in makes one (ensureOrangecheck; until signin3 it ticked a box):
/// {made, did} or {made: false, reason}. Asked of orangecheck with consent
/// and the account's id, and with [address] ({email, verified}), so that
/// signing in to ochk.app with it offers the account to claim: verified
/// only when the request is a fresh emailed code's for that very address
/// (codeOf), as orangecheck asked (2026-10-24), never on Google's or
/// GitHub's word (signinreview F2). Its row is claimed first
/// (ensureOrangecheck), so deleting the account deletes that one too
/// whatever the answer. And once orangecheck has answered, kept only while the account
/// is neither gone nor marked as leaving in the last 15 minutes
/// (supabase/orangecheck_connect_leaving.sql): one deleted while
/// orangecheck was asked, even on a first tick that began after its
/// deletion did (site-attest's race), would leave an orangecheck account
/// nothing here could ever delete (orangecheck's review, L2), so that one
/// is deleted at once, and the answer is {made: false, reason:
/// "account_leaving"}. Never throws: a refusal or an outage is an answer,
/// as Connect's own calls give them.
export async function provision(account, address = null) {
  let made;
  try {
    made = await connectProvision({ apiKey: process.env.OC_CONNECT_KEY, userId: account, consent: true,
      ...(address ? { email: address.email, emailVerified: address.verified === true } : {}) });
  } catch (trouble) {
    console.error(`orangecheck: Connect: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { made: false, reason: "unavailable" };
  }
  if (!made.ok) {
    console.error(`orangecheck: Connect made no account: ${made.reason} ${made.status}`);
    return { made: false, reason: made.reason };
  }
  const kept = await db("rpc/oc_connect_kept", { method: "POST", body: { account, did: made.did_oc } })
    .catch((trouble) => console.error(`orangecheck: Connect's id not kept: ${String(trouble?.message || trouble).slice(0, 120)}`));
  if (kept === false) {
    const gone = await unprovision(account);
    if (!gone.go) console.error(`orangecheck: Connect made ${made.did_oc} for an account deleted meanwhile, and it is not deleted: delete it at orangecheck`);
    return { made: false, reason: "account_leaving" };
  }
  return { made: true, did: made.did_oc };
}

// A session whose sign-in began this long ago or less is a sign-in, for
// ensureOrangecheck: Supabase keeps the sign-in's own time in amr through
// every renewal, so a session left open for days is not one.
const SIGNED_IN_JUST_NOW_S = 900;

/// Whether the session behind [claims] began in the last 15 minutes.
export function signedInJustNow(claims, now = Date.now()) {
  const times = (Array.isArray(claims?.amr) ? claims.amr : []).map((one) => Number(one?.timestamp)).filter(Number.isFinite);
  return times.length > 0 && now / 1000 - Math.max(...times) <= SIGNED_IN_JUST_NOW_S;
}

/// The orangecheck account every sign-in makes (signin3, 2026-11-24: the
/// owner, "wrap around both of them the orangecheck account creation, remove
/// the checkbox"): for the account behind [claims], once, by Connect
/// (provision), as the box did when it was ticked, now without one: the
/// sign-in says so in one line, with a link, on every surface it is made
/// at. Asked by api/account.js after a sign-in's first word with it (the
/// site's dialog and /profile, and the app, ask it as soon as they are
/// signed in), never in the sign-in's way. None for an account that has
/// orangecheck (signed in with it, or linked) or one Connect made already
/// (that one is kept and reused: never two). The ask is claimed in one
/// statement (oc_connect_claim, supabase/sign_in_ways.sql): of the first
/// requests of a sign-in, made at once, one asks, and none again within a
/// minute (signinreview F6: each of six asked when the minute was read,
/// then written). The account's address goes with it, as verified when
/// [emailed] is that address (codeOf: a code emailed in the last five
/// minutes), as one orangecheck has still to check otherwise: a sign-in
/// with Google or GitHub, or the age answered after those five minutes
/// (F11). {made, did} or {made: false, reason}; throws when the database
/// cannot be read.
export async function ensureOrangecheck(claims, emailed = null) {
  if (!connectConfigured()) return { made: false, reason: "not_here" };
  if (madeUp(claims.email)) return { made: false, reason: "has_orangecheck" };
  const [did, connected] = await Promise.all([
    db("rpc/oc_did_of", { method: "POST", body: { account: claims.sub } }),
    db("rpc/oc_connected_of", { method: "POST", body: { account: claims.sub } }),
  ]);
  if (did) return { made: false, reason: "has_orangecheck" };
  if (connected?.did) return { made: false, reason: "has_one", did: connected.did };
  let claimed;
  try {
    claimed = await db("rpc/oc_connect_claim", { method: "POST", body: { account: claims.sub } });
  } catch (trouble) {
    console.error(`orangecheck: Connect not asked, nothing kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { made: false, reason: "unavailable" };
  }
  if (claimed !== true) return { made: false, reason: "asked_just_now" };
  const email = String(claims.email || "").trim().toLowerCase();
  return provision(claims.sub, email ? { email, verified: Boolean(emailed) && emailed === email } : null);
}

/// The orangecheck account Connect made for [account], asked to be deleted
/// before the account itself is, and whether the account may go: {go: true}
/// (and kept: words to tell, when theirs stays at ochk.app), or {go: false,
/// status: 503, error} and nothing is deleted. An allow-list, in Brickworks'
/// own hands (site-attest, 2026-10-24), whatever me-client makes of an
/// answer: the account goes only when orangecheck's is gone (unknown_user,
/// deleted, detached: the person's own now they claimed it, already_deleted)
/// or orangecheck refuses for good (holds_earnings, not_deletable: it stays
/// theirs at ochk.app, said plainly; a person can always delete their
/// Brickworks account). An outage (unavailable, rate_limited, a network
/// failure, a throw) asks them to try again. Anything else (no key here, a
/// key orangecheck does not know, bad_request, any answer not named here)
/// is Brickworks' setup fault, and deleting would leave their orangecheck
/// account behind unsaid: paused (orangecheck's final ruling). [ask] is
/// connectDelete, or a stand-in for tools/web/orangecheck_check.mjs.
const PAUSED = "Deleting is paused while Brickworks fixes a setup problem. Nothing has been deleted.";
const TRY_AGAIN = "orangecheck could not delete the orangecheck account made for you just now, so nothing is deleted yet. "
  + "Try again in a minute.";
const KEPT = "orangecheck could not delete the orangecheck account made for you, so it stays yours at ochk.app, "
  + "to claim or delete there.";
const GONE_RESULTS = new Set(["deleted", "detached", "already_deleted"]);
const KEPT_REASONS = new Set(["holds_earnings", "not_deletable"]);
const OUTAGE_REASONS = new Set(["unavailable", "rate_limited"]);
export async function unprovision(account, ask = connectDelete) {
  const held = (error, why) => {
    console.error(`orangecheck: a Connect account's deletion is held: ${why}`);
    return { go: false, status: 503, error };
  };
  if (!connectConfigured()) return held(PAUSED, "no OC_CONNECT_KEY here");
  let answer;
  try {
    answer = await ask({ apiKey: process.env.OC_CONNECT_KEY, userId: account });
  } catch (trouble) {
    return held(TRY_AGAIN, `Connect threw: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
  if (answer?.ok === true && GONE_RESULTS.has(answer.result)) return { go: true };
  if (answer?.ok === false && answer.reason === "unknown_user") return { go: true };
  if (answer?.ok === false && KEPT_REASONS.has(answer.reason)) {
    console.error(`orangecheck: Connect keeps an account (${answer.reason}); ours is deleted all the same`);
    return { go: true, kept: KEPT };
  }
  const said = String(answer?.ok === true ? `ok ${answer.result}` : `${answer?.reason} ${answer?.status}`).slice(0, 80);
  if (answer?.ok === false && OUTAGE_REASONS.has(answer.reason)) return held(TRY_AGAIN, said);
  return held(PAUSED, said);
}

/// The token ended at orangecheck once it has been taken, so it is good for
/// nothing anywhere else either. Its id is spent here whatever orangecheck
/// answers.
export async function endToken(token) {
  try {
    const reply = await fetch(`${ocHosts().auth}/api/auth/revoke`, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ tokens: [token] }), signal: AbortSignal.timeout(5000) });
    if (!reply.ok) console.error(`orangecheck: the token was not ended there: ${reply.status}`);
  } catch (trouble) {
    console.error(`orangecheck: the token was not ended there: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

// What a session was found to be is api/_auth.js's sessionOf, which every
// account's sign-in asks: read once in a few seconds an instance, since a
// page asks several routes at once, and an ended session must still be
// refused within seconds of being found ended.
const READS = new Set(["GET", "HEAD", "OPTIONS"]);

/// [claims]'s session ended here, refused in [words]: Supabase's row
/// deleted, so it cannot be renewed either.
async function endHere(claims, session, words) {
  try {
    await db("rpc/oc_end_session", { method: "POST", body: { session: claims.session_id } });
  } catch (trouble) {
    console.error(`orangecheck: a session was not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
  sessionEnded(claims.session_id, session);
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
/// after it: {bound, way, fresh, emailed}. bound, when orangecheck started
/// it; way, google or github when either did (api/_ways.js); fresh, when it
/// is an emailed code of the last five minutes; emailed, the address that
/// code went to, when it is one (amr otp alone, never a test account's
/// password), which Connect may send orangecheck as verified (orangecheck's
/// answer, 2026-10-24). A session orangecheck, Google or GitHub started
/// says "otp" too (each is minted from a one-time link), so each is told
/// apart by what was written down as it was handed out, and is never fresh
/// (signinreview F2: a GitHub sign-in passed linking's step-up, with no
/// code sent). Nor is a password, but a test account's
/// (tools/web/session.mjs), whose address nobody can receive mail at:
/// anybody signed in could set a password on their account (oc188's
/// review, H1; supabase/no_new_ways_in.sql now refuses it).
///
/// All of it from one read of the session as it is now (api/_auth.js
/// standingOf), never a held one: a way's session, read gone, was read as a
/// code's while another instance held it alive (signin6, the class of
/// signreview3 R1). Throws AuthError 401 when the session is gone, and
/// throws when it cannot be read: whoever asked refuses.
export async function codeOf(claims) {
  const standing = await standingOf(claims);
  if (!standing.exists) throw new AuthError("You were signed out. Sign in again.");
  const amr = Array.isArray(claims.amr) ? claims.amr : [];
  const coded = standing.by === "code";
  const recent = (one) => Boolean(one && coded && Date.now() / 1000 - Number(one.timestamp) <= FRESH_SECONDS);
  const fresh = recent(amr.find((one) => one?.method === "otp" || (one?.method === "password" && isTestAccount(claims))));
  const address = String(claims.email || "").trim().toLowerCase();
  const emailed = recent(amr.find((one) => one?.method === "otp")) && address && !madeUp(address) ? address : null;
  return { bound: Boolean(standing.bound), way: standing.way, fresh, emailed };
}

// ---------------------------------------------------------------------------
// The one rule for a change to how an account signs in, or to end it
// (signin7, signreview4 R4-1).

export const CONFIRM_FIRST = "Confirm it is you first, with a code we email you.";
const NOT_CHECKED = "Brickworks could not check your sign-in just now, so nothing was changed. Try again in a minute.";

/// Whether the session behind [claims] may give its account a way in, or
/// end the account: Delete account (and an age answer that deletes it), Link
/// again, linking orangecheck, keeping GitHub's id, the console's delete and
/// its sign-in switches; and whatever changes how it signs in from here on
/// (unlinking orangecheck). Two things, for every kind of session alike: the
/// session as it is now (codeOf, one live read: gone is 401, unreadable 503,
/// never verify()'s held answer, which passed for up to 5 s after an Unlink
/// had ended the session, R4-1 Z1 and L1), and a sign-in by a code emailed
/// to the account in the last five minutes (codeOf's fresh), which no
/// session Google, GitHub or orangecheck started can be (Y1, Y2). An account
/// whose address is made up (orangecheck's own, api/orangecheck.js) takes no
/// code: its proof is [orangecheck], a fresh sign-in with orangecheck as the
/// id this account has, checked and spent here. {asked} (codeOf's answer)
/// when it may; otherwise {status, body} to answer with: 401 signed out,
/// 403 {fresh: false} (or {orangecheck: true}), 503 when it cannot be read.
/// Unlinking Google or GitHub takes a way away and gives none: it asks the
/// session as it is now alone (api/_ways.js waysRoute), so a way's own
/// session can still end itself.
export async function stepUp(claims, { orangecheck = undefined } = {}) {
  let asked;
  try {
    asked = await codeOf(claims);
  } catch (trouble) {
    if (trouble instanceof AuthError) return { status: trouble.status, body: { error: trouble.message } };
    console.error(`auth: a change's sign-in was not read: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { status: 503, body: { error: NOT_CHECKED } };
  }
  if (madeUp(claims.email)) {
    if (orangecheck === undefined) {
      return { status: 403, body: { error: "Sign in with orangecheck again first, as this account.", orangecheck: true } };
    }
    const proved = await sameOrangecheck(claims, orangecheck);
    return proved || { asked };
  }
  if (!asked.fresh) return { status: 403, body: { error: CONFIRM_FIRST, fresh: false } };
  return { asked };
}

/// [token], a fresh sign-in with orangecheck, checked as the id [claims]'
/// account has and spent: null when it is, else {status, body}.
async function sameOrangecheck(claims, token) {
  const checked = await checkToken(token);
  if (!checked.session) return { status: checked.status, body: { error: checked.error, ...(checked.more || {}) } };
  try {
    const whose = await db("rpc/oc_account_of", { method: "POST", body: { did: checked.session.did_oc } });
    if (whose !== claims.sub) {
      return { status: 403, body: { error: "That orangecheck sign-in is not this account's. Sign in with the one you use here." } };
    }
    if (!(await spendToken(checked.session.jti, checked.session.exp))) {
      return { status: 409, body: { error: "That sign-in was used already. Sign in with orangecheck again." } };
    }
  } catch (trouble) {
    console.error(`orangecheck: a change's sign-in was not checked: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { status: 502, body: { error: NOT_CHECKED } };
  }
  await endToken(String(token).trim());
  return null;
}

const SENDER = "Brickworks <noreply@brickworks.diy>";

/// What every notice of a change to how an account signs in ends with.
export const AFTER = "If this was not you, sign in to Brickworks with an emailed code and change it in Settings: "
  + "https://brickworks.diy/settings";

/// The account's own address told of a change to how it signs in: "sent",
/// "dry" for a test address (Resend's, which reaches nobody), or "failed".
/// orangecheck's link and unlink, and Google's and GitHub's Unlink and Link
/// again (signreview4 N4).
export async function tell(email, subject, text) {
  if (/@resend\.dev$/i.test(email)) return "dry";
  const key = process.env.RESEND_API_KEY;
  if (!key || !email || madeUp(email)) return "failed";
  try {
    const reply = await fetch("https://api.resend.com/emails", {
      method: "POST", headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ from: process.env.EMAIL_FROM || SENDER, to: [email], subject, text,
        tags: [{ name: "kind", value: "sign_in_notice" }] }),
      signal: AbortSignal.timeout(10000) });
    if (!reply.ok) console.error(`orangecheck: Resend refused a notice: ${reply.status}`);
    return reply.ok ? "sent" : "failed";
  } catch (trouble) {
    console.error(`orangecheck: a notice did not go: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return "failed";
  }
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
