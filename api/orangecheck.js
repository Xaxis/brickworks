// Signing in with orangecheck (2026-10-23), beside the emailed code
// (api/otp.js).
//
//   POST ?op=signin, {token}: the token orangecheck's sign-in window gave
//   the page (web/account.js, web/oc-button.mjs). Checked (api/_oc.js),
//   spent, and exchanged for a Brickworks session: Supabase's, the same as
//   an emailed code gives, so the page keeps it where the app finds it and
//   the app is signed in too. The answer is that session, as Supabase's own
//   verify answers.
//   POST ?op=native, {code, code_verifier, redirect_uri}: the desktop app's
//   sign-in (2026-10-24, src/account/orangecheck_sign_in.gd), which has no
//   window to open: a one-time code orangecheck sent the person's browser
//   back to the app with, at 127.0.0.1. Traded at orangecheck for the token
//   the window would have given (api/_oc.js tradeCode), then exactly as
//   ?op=signin: counted, checked, spent, the same account, the same
//   session. Only where it is offered (api/_oc_config.js nativeOffered).
//
//   With a sign-in (/settings, web/settings.js):
//   GET ?op=status       {did, only, fresh}: the orangecheck id linked, if
//                        any; whether the account signs in only with it;
//                        whether this session is an emailed code of the
//                        last five minutes, which linking and unlinking ask
//                        (api/_oc.js codeOf).
//   POST ?op=link        {token}: orangecheck linked to an account that has
//                        its own email, after a fresh code, and only an id
//                        no other account has. The address is told.
//   POST ?op=unlink      the same fresh code: the id unlinked, and every
//                        session it started on the account ended. Told too.
//   status also says {made}: the orangecheck account Connect made for this
//   one, if any. Since signin3 (2026-11-24) every sign-in by an emailed
//   code, Google or GitHub makes it, with no box to tick (the sign-in says
//   so): the server, after the sign-in's first word with /api/account
//   (api/_oc.js ensureOrangecheck). ?op=connect, the box's, is gone.
//
// The token is never kept, here or in the page. What is (supabase/
// orangecheck.sql): which account the person's orangecheck id signs in to,
// the token's id until it expires so it signs in once, and the token's rh,
// aud and iat beside the session it started, so that ending every session
// on orangecheck can end this one. And each rh with its id (supabase/
// orangecheck_merge_connect.sql): an id new here whose token says which
// accounts were merged into it signs in to the account they had (api/_oc.js
// merged), the account's address told.
//
// A new orangecheck id is a new account, made through Supabase's admin API
// with an address of 32 random hex digits at oc.brickworks.diy. Never one
// worked out from the id: anybody could work it out too and make that
// account first, and the first sign-in would walk into it. Nothing is ever
// mailed there (api/otp.js refuses the domain, api/_comments.js skips it).
// Rate limited per network in the database, as codes are, and per
// orangecheck id once its token checks out, as a Google or GitHub account
// is (signin5, signreview2 SR3): each sign-in spends one of Supabase's
// verifies from this server's address (api/_minted.js), shared with
// everyone's Google and GitHub sign-ins, and one orangecheck account in a
// loop from a few addresses emptied it.

import { noted } from "./_noted.js";
import { afterAnswer } from "./_after.js";
import { randomBytes } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, reach } from "./_db.js";
import { mintedSession } from "./_minted.js";
import { raiseSignup } from "./_notify.js";
import { scopeOf } from "./_settings.js";
import { COUNTED, LIMITS, networkOf } from "./_ways.js";
import {
  checkToken, codeOf, endToken, keepHandle, madeUp, merged, nativeOffered, ocConfigured, spendToken, tradeCode,
} from "./_oc.js";

function supabase() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

function admin() {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" };
}

/// A new account for a new orangecheck id: its id, made by Supabase. The
/// address is random and refused if it exists, so nobody can have made it
/// first.
async function newAccount() {
  const email = `${randomBytes(16).toString("hex")}@oc.brickworks.diy`;
  const reply = await reach("auth POST admin/users", 10, `${supabase()}/auth/v1/admin/users`, {
    method: "POST", headers: admin(),
    body: JSON.stringify({ email, email_confirm: true, app_metadata: { orangecheck: true } }) });
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok || !body.id) throw new Error(`auth: no account made: ${reply.status}`);
  return body.id;
}

async function dropAccount(account) {
  const reply = await reach("auth DELETE admin/users", 10, `${supabase()}/auth/v1/admin/users/${account}`, {
    method: "DELETE", headers: admin() });
  if (!reply.ok && reply.status !== 404) console.error(`orangecheck: an account made for a lost race was not deleted: ${reply.status}`);
}

/// A Supabase session for [account], minted here (api/_minted.js): a
/// one-time link for its address, redeemed at once, each step naming
/// [account]. An account its id signs in to and not marked as having
/// orangecheck is marked first, so the session's own token carries the mark
/// and has every request asked after (oc188's review, L1).
async function sessionFor(account) {
  const who = await reach("auth GET admin/users", 10, `${supabase()}/auth/v1/admin/users/${account}`, {
    headers: admin() });
  const user = await who.json().catch(() => ({}));
  if (!who.ok || user.id !== account || !user.email) throw new Error(`auth: the account was not read: ${who.status}`);
  if (user.app_metadata?.orangecheck !== true) await mark(account, true);
  return mintedSession(user.email, { account });
}

async function endSession(access) {
  await fetch(`${supabase()}/auth/v1/logout?scope=local`, {
    method: "POST", signal: AbortSignal.timeout(10000),
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, authorization: `Bearer ${access}` } }).catch(() => null);
}

const say = (response, status, error, more = {}) => response.status(status).json({ error, ...more });

function bodyOf(request) {
  if (typeof request.body !== "string") return request.body || {};
  try {
    return JSON.parse(request.body);
  } catch {
    return {};
  }
}

/// Whether [request]'s network may try another sign-in, answered when not.
/// Counted before anything else is asked, so a stranger cannot make this
/// server ask orangecheck and the database for them as often as they like.
/// The network as Google's and GitHub's are counted (api/_ways.js
/// networkOf): an IPv6 /64, which one person holds whole, is one.
async function counted(request, response) {
  let may;
  try {
    may = await db("rpc/oc_may_try", { method: "POST", body: { from_ip: networkOf(request) } });
  } catch (trouble) {
    console.error(`orangecheck: ${String(trouble?.message || trouble).slice(0, 120)}`);
    say(response, 503, "Brickworks could not start a sign-in just now. Try again in a minute.");
    return false;
  }
  if (may !== true) say(response, 429, "Too many sign-ins tried from here. Wait a few minutes and try again.");
  return may === true;
}

async function signIn(request, response) {
  if (!ocConfigured()) return say(response, 503, "Signing in with orangecheck is unavailable here. Sign in with your email instead.");
  const body = bodyOf(request);
  const token = typeof body?.token === "string" ? body.token.trim() : "";
  if (token && !(await counted(request, response))) return;
  return signInWith(token, response, request);
}

// What the app sends: orangecheck's code, a PKCE verifier (RFC 7636: 43 to
// 128 of its letters) and the loopback address the code came to, with no
// query. Anything else is refused before anything is asked or counted.
const CODE = /^[\x21-\x7e]{8,512}$/;
const VERIFIER = /^[A-Za-z0-9._~-]{43,128}$/;
const LOOPBACK = /^http:\/\/127\.0\.0\.1:\d{1,5}\/[A-Za-z0-9._~/-]*$/;

async function native(request, response) {
  if (!nativeOffered()) {
    return say(response, 503, "Signing in with orangecheck from the app is not offered here. Sign in with your email instead.");
  }
  const body = bodyOf(request);
  const [code, verifier, redirect] = ["code", "code_verifier", "redirect_uri"].map((name) => (typeof body?.[name] === "string" ? body[name] : ""));
  if (!CODE.test(code) || !VERIFIER.test(verifier) || !LOOPBACK.test(redirect)) {
    return say(response, 422, "The sign-in did not come through from orangecheck. Try again.");
  }
  if (!(await counted(request, response))) return;
  const traded = await tradeCode({ code, verifier, redirect });
  if (!traded.token) return say(response, traded.status, traded.error, traded.more);
  return signInWith(traded.token, response, request);
}

/// [token], orangecheck's, checked and exchanged for a Brickworks session,
/// answered: the window's sign-in and the app's alike. An account made
/// here is told to the owner (api/_notify.js), for [request]'s deployment.
async function signInWith(token, response, request = null) {
  const checked = await checkToken(token);
  if (!checked.session) return say(response, checked.status, checked.error, checked.more);
  const { did_oc: did, jti, rh, aud, iat, exp } = checked.session;

  // Spent here, after it has checked out, before anything is made with it:
  // the same token at another instance, or again, finds it spent.
  try {
    if (!(await spendToken(jti, exp))) return say(response, 409, "That sign-in was used already. Sign in with orangecheck again.");
  } catch (trouble) {
    console.error(`orangecheck: not spent: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return say(response, 503, "Brickworks could not finish the sign-in just now. Try again in a minute.");
  }
  // And counted by orangecheck id, before anything is made or minted (SR3):
  // as many as one Google or GitHub account signs in (api/_ways.js LIMITS),
  // from however many addresses. Refused when it cannot be counted, as the
  // network's count is.
  let often;
  try {
    often = (await db("rpc/way_may_try", { method: "POST",
      body: { try_key: COUNTED.orangecheck(did), per: LIMITS.account, window_minutes: LIMITS.minutes } })) !== true;
  } catch (trouble) {
    console.error(`orangecheck: not counted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return say(response, 503, "Brickworks could not finish the sign-in just now. Try again in a minute.");
  }
  if (often) {
    return say(response, 429, "Too many sign-ins with this orangecheck account just now. Wait a few minutes and try again.");
  }

  let account;
  let made = false;
  let followed = null;
  let minted;
  try {
    account = await db("rpc/oc_account_of", { method: "POST", body: { did } });
    // New here: an account merged into this one on orangecheck may have had
    // a Brickworks account, and then this is that one's now.
    if (!account) {
      followed = await merged(checked.session);
      if (followed?.conflict) {
        return say(response, 409, "This orangecheck account was merged from two that each have a Brickworks account, "
          + "so Brickworks cannot tell which one is yours. If one has your email, sign in with it and link orangecheck in Settings.");
      }
      account = followed?.account || null;
      // Told now: the account is the kept id's from here, whether or not
      // this sign-in goes on to finish.
      if (followed) {
        await tell(followed.email, "orangecheck signs you in to Brickworks with the account you kept",
          `You merged orangecheck accounts, and the one you kept (${did}) now signs you in to your Brickworks account, `
          + `in place of ${followed.was}. ${AFTER}`);
      }
    }
    if (!account) {
      const fresh = await newAccount();
      try {
        account = await db("rpc/oc_claim", { method: "POST", body: { did, account: fresh } });
      } catch (trouble) {
        await dropAccount(fresh);
        throw trouble;
      }
      // Another sign-in of the same person made theirs first: that one is
      // theirs, and the one made here goes.
      if (account !== fresh) await dropAccount(fresh);
      made = account === fresh;
      if (!account) throw new Error("the claim named no account");
    }
    minted = await sessionFor(account);
  } catch (trouble) {
    console.error(`orangecheck: no session: ${String(trouble?.message || trouble).slice(0, 160)}`);
    if (trouble?.again) return say(response, 409, "Your Brickworks account changed just now. Sign in with orangecheck again.");
    if (trouble?.busy) return say(response, 503, "A lot of people are signing in just now. Try again in a minute.");
    return say(response, 502, "Brickworks could not finish the sign-in just now. Try again in a minute.");
  }

  // Bound before it is handed out, so a session orangecheck can end is never
  // in a browser without the means to end it; and only while the id is
  // still the account's, so an unlink since it was looked up leaves no
  // session of that id behind (oc188's review, M1).
  let bound;
  try {
    bound = await db("rpc/oc_bind_session", { method: "POST", body: { session: minted.sessionId, account, did, rh, aud, iat } });
  } catch (trouble) {
    console.error(`orangecheck: the session was not bound: ${String(trouble?.message || trouble).slice(0, 120)}`);
    await endSession(minted.session.access_token);
    return say(response, 502, "Brickworks could not finish the sign-in just now. Try again in a minute.");
  }
  if (bound !== true) {
    await endSession(minted.session.access_token);
    return say(response, 409, "orangecheck was unlinked from that Brickworks account just now. Sign in with orangecheck again.");
  }
  await Promise.all([endToken(token), keepHandle(checked.session)]);
  if (made) afterAnswer(() => raiseSignup({ account, email: null, scope: scopeOf(request), via: "orangecheck" }), "orangecheck: sign-up");

  const s = minted.session;
  return response.status(200).json({
    access_token: s.access_token,
    refresh_token: s.refresh_token,
    expires_in: s.expires_in,
    token_type: s.token_type,
    user: { id: s.user.id, email: s.user.email },
    orangecheck: { did, new_account: made, merged: Boolean(followed) },
  });
}

/// The account asking, from its sign-in: {claims, did, only, fresh,
/// emailed} (api/_oc.js codeOf).
/// Throws AuthError when there is none.
async function asking(request) {
  const claims = await verify(bearer(request), request);
  const [{ fresh, emailed }, did] = await Promise.all([
    codeOf(claims),
    db("rpc/oc_did_of", { method: "POST", body: { account: claims.sub } }),
  ]);
  return { claims, did: did || null, only: madeUp(claims.email), fresh, emailed };
}

/// orangecheck's mark on the account (app_metadata.orangecheck), which is
/// what has its sessions asked after on every request (api/_auth.js).
async function mark(account, on) {
  const reply = await reach("auth PUT admin/users", 10, `${supabase()}/auth/v1/admin/users/${account}`, {
    method: "PUT", headers: admin(),
    body: JSON.stringify({ app_metadata: { orangecheck: on } }) });
  if (!reply.ok) throw new Error(`auth: the account was not marked: ${reply.status}`);
}

const SENDER = "Brickworks <noreply@brickworks.diy>";

/// The account's own address told of a change to how it signs in: "sent",
/// "dry" for a test address (Resend's, which reaches nobody), or "failed".
async function tell(email, subject, text) {
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

const AFTER = "If this was not you, sign in to Brickworks with an emailed code and change it in Settings: "
  + "https://brickworks.diy/settings";

async function signedInAs(request, response) {
  try {
    return await asking(request);
  } catch (trouble) {
    if (trouble instanceof AuthError) say(response, trouble.status, trouble.message);
    else {
      console.error(`orangecheck: ${String(trouble?.message || trouble).slice(0, 120)}`);
      say(response, 502, "Brickworks could not read your account just now. Try again in a minute.");
    }
    return null;
  }
}

async function status(request, response) {
  const who = await signedInAs(request, response);
  if (!who) return;
  // The orangecheck account Connect made for this one (oc_connected), when
  // it signs in otherwise: unknown (null) when it cannot be read.
  const connected = who.only || who.did ? null
    : await db("rpc/oc_connected_of", { method: "POST", body: { account: who.claims.sub } }).catch(() => undefined);
  return response.status(200).json({ did: who.did, only: who.only, fresh: who.fresh, ready: ocConfigured(),
    made: connected === undefined ? null : connected?.did ? { did: connected.did, at: connected.made_at } : false });
}

async function link(request, response) {
  if (!ocConfigured()) return say(response, 503, "Signing in with orangecheck is not set up here.");
  const who = await signedInAs(request, response);
  if (!who) return;
  if (who.only) return say(response, 409, "This account signs in with orangecheck already.");
  if (who.did) return say(response, 409, "This account has orangecheck linked already. Unlink it first.");
  if (!who.fresh) return say(response, 403, "Confirm it is you first, with a code we email you.", { fresh: false });
  const body = bodyOf(request);
  const token = typeof body?.token === "string" ? body.token.trim() : "";
  const checked = await checkToken(token);
  if (!checked.session) return say(response, checked.status, checked.error, checked.more);
  const { did_oc: did, jti, exp } = checked.session;
  try {
    if (!(await spendToken(jti, exp))) return say(response, 409, "That sign-in was used already. Sign in with orangecheck again.");
    // Marked first: an account that has orangecheck is never one whose
    // sessions go unasked.
    await mark(who.claims.sub, true);
    const said = await db("rpc/oc_link", { method: "POST", body: { did, account: who.claims.sub } });
    if (said === "taken") return say(response, 409, "That orangecheck account already signs in to another Brickworks account.");
    if (said === "has_one") return say(response, 409, "This account has orangecheck linked already. Unlink it first.");
    if (said !== "linked") throw new Error(`oc_link said ${said}`);
  } catch (trouble) {
    console.error(`orangecheck: not linked: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return say(response, 502, "Brickworks could not link orangecheck just now. Try again in a minute.");
  }
  await Promise.all([endToken(token), keepHandle(checked.session)]);
  const told = await tell(who.claims.email, "orangecheck now signs you in to Brickworks",
    `orangecheck (${did}) was linked to your Brickworks account just now, so it can sign you in too. ${AFTER}`);
  return response.status(200).json({ did, told });
}

async function unlink(request, response) {
  const who = await signedInAs(request, response);
  if (!who) return;
  if (who.only) return say(response, 409, "This account signs in only with orangecheck, so it keeps it.");
  if (!who.did) return say(response, 404, "orangecheck is not linked to this account.");
  if (!who.fresh) return say(response, 403, "Confirm it is you first, with a code we email you.", { fresh: false });
  let gone;
  try {
    gone = await db("rpc/oc_unlink", { method: "POST", body: { account: who.claims.sub } });
  } catch (trouble) {
    console.error(`orangecheck: not unlinked: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return say(response, 502, "Brickworks could not unlink orangecheck just now. Try again in a minute.");
  }
  if (!gone) return say(response, 404, "orangecheck is not linked to this account.");
  // Unmarked after: until then its sessions are still asked after, which
  // costs a read and nothing else.
  await mark(who.claims.sub, false).catch((trouble) => console.error(`orangecheck: ${String(trouble?.message || trouble).slice(0, 120)}`));
  const told = await tell(who.claims.email, "orangecheck no longer signs you in to Brickworks",
    `orangecheck (${gone.did}) was unlinked from your Brickworks account just now, and the sign-ins it started were ended. ${AFTER}`);
  return response.status(200).json({ did: gone.did, ended: gone.ended, told });
}

async function handler(request, response) {
  // Asked only by the site's own pages: no cross-origin answer, and nothing
  // kept by any cache.
  response.setHeader("Cache-Control", "no-store");
  const op = String(request.query?.op || "");
  if (request.method === "POST" && op === "signin") return signIn(request, response);
  if (request.method === "POST" && op === "native") return native(request, response);
  if (request.method === "GET" && op === "status") return status(request, response);
  if (request.method === "POST" && op === "link") return link(request, response);
  if (request.method === "POST" && op === "unlink") return unlink(request, response);
  return say(response, 405, "POST ?op=signin, ?op=native, ?op=link or ?op=unlink, or GET ?op=status");
}

// Each 5xx kept for the owner's server-errors notification (api/_noted.js).
export default noted("orangecheck", handler);
