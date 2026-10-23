// Signing in with orangecheck (2026-10-23), beside the emailed code
// (api/otp.js).
//
//   POST ?op=signin, {token}: the token orangecheck's sign-in window gave
//   the page (web/account.js, web/oc-popup.mjs). Checked (api/_oc.js),
//   spent, and exchanged for a Brickworks session: Supabase's, the same as
//   an emailed code gives, so the page keeps it where the app finds it and
//   the app is signed in too. The answer is that session, as Supabase's own
//   verify answers.
//
// The token is never kept, here or in the page. What is (supabase/
// orangecheck.sql): which account the person's orangecheck id signs in to,
// the token's id until it expires so it signs in once, and the token's rh,
// aud and iat beside the session it started, so that ending every session
// on orangecheck can end this one.
//
// A new orangecheck id is a new account, made through Supabase's admin API
// with an address of 32 random hex digits at oc.brickworks.diy. Never one
// worked out from the id: anybody could work it out too and make that
// account first, and the first sign-in would walk into it. Nothing is ever
// mailed there (api/otp.js refuses the domain, api/_comments.js skips it).
// Rate limited per address in the database, as codes are.

import { randomBytes } from "node:crypto";
import { db } from "./_db.js";
import { checkToken, endToken, ocConfigured, spendToken } from "./_oc.js";

function supabase() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

function admin() {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" };
}

function claimsOf(jwt) {
  try {
    return JSON.parse(Buffer.from(String(jwt).split(".")[1], "base64url").toString("utf8"));
  } catch {
    return {};
  }
}

/// A new account for a new orangecheck id: its id, made by Supabase. The
/// address is random and refused if it exists, so nobody can have made it
/// first.
async function newAccount() {
  const email = `${randomBytes(16).toString("hex")}@oc.brickworks.diy`;
  const reply = await fetch(`${supabase()}/auth/v1/admin/users`, {
    method: "POST", headers: admin(), signal: AbortSignal.timeout(10000),
    body: JSON.stringify({ email, email_confirm: true, app_metadata: { orangecheck: true } }) });
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok || !body.id) throw new Error(`auth: no account made: ${reply.status}`);
  return body.id;
}

async function dropAccount(account) {
  const reply = await fetch(`${supabase()}/auth/v1/admin/users/${account}`, {
    method: "DELETE", headers: admin(), signal: AbortSignal.timeout(10000) });
  if (!reply.ok && reply.status !== 404) console.error(`orangecheck: an account made for a lost race was not deleted: ${reply.status}`);
}

/// A Supabase session for [account], minted here: a one-time link for its
/// address, asked for without sending anything, and redeemed at once. Each
/// step must name [account], or nothing is handed out. An account has one
/// such link at a time, so two sign-ins of it at once (two tabs, or two
/// first sign-ins racing) can each spoil the other's: the one refused asks
/// again, after a moment that differs each time.
async function sessionFor(account) {
  const who = await fetch(`${supabase()}/auth/v1/admin/users/${account}`, {
    headers: admin(), signal: AbortSignal.timeout(10000) });
  const user = await who.json().catch(() => ({}));
  if (!who.ok || user.id !== account || !user.email) throw new Error(`auth: the account was not read: ${who.status}`);
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await redeemedFor(account, user.email);
    } catch (trouble) {
      if (attempt >= 4 || !trouble.spoiled) throw trouble;
      await new Promise((done) => setTimeout(done, 100 + Math.random() * 400 * attempt));
    }
  }
}

async function redeemedFor(account, email) {
  const link = await fetch(`${supabase()}/auth/v1/admin/generate_link`, {
    method: "POST", headers: admin(), signal: AbortSignal.timeout(10000),
    body: JSON.stringify({ type: "magiclink", email }) });
  const made = await link.json().catch(() => ({}));
  const hashed = made.hashed_token || made.properties?.hashed_token;
  if (!link.ok || !hashed || (made.id || made.user?.id) !== account) throw new Error(`auth: no link: ${link.status}`);
  const verify = await fetch(`${supabase()}/auth/v1/verify`, {
    method: "POST", signal: AbortSignal.timeout(10000),
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
    body: JSON.stringify({ type: "magiclink", token_hash: hashed }) });
  const session = await verify.json().catch(() => ({}));
  if (verify.status === 403 || verify.status === 401) {
    throw Object.assign(new Error(`auth: the link was spoiled: ${verify.status}`), { spoiled: true });
  }
  // Supabase counts redemptions by address, and every one of these is this
  // server's.
  if (verify.status === 429) throw Object.assign(new Error("auth: verify answered 429"), { busy: true });
  const claims = claimsOf(session.access_token);
  if (!verify.ok || !session.refresh_token || session.user?.id !== account || claims.sub !== account || !claims.session_id) {
    throw new Error(`auth: the session was not for this account: ${verify.status}`);
  }
  return { session, sessionId: claims.session_id };
}

async function endSession(access) {
  await fetch(`${supabase()}/auth/v1/logout?scope=local`, {
    method: "POST", signal: AbortSignal.timeout(10000),
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, authorization: `Bearer ${access}` } }).catch(() => null);
}

function addressOf(request) {
  return (request.headers["x-forwarded-for"] || "").split(",")[0].trim() || request.socket?.remoteAddress || "";
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

async function signIn(request, response) {
  if (!ocConfigured()) return say(response, 503, "Signing in with orangecheck is unavailable here. Sign in with your email instead.");
  const body = bodyOf(request);
  const token = typeof body?.token === "string" ? body.token.trim() : "";
  // Counted before anything else is asked, so a stranger cannot make this
  // server ask orangecheck and the database for them as often as they like.
  if (token) {
    let may;
    try {
      may = await db("rpc/oc_may_try", { method: "POST", body: { from_ip: addressOf(request) } });
    } catch (trouble) {
      console.error(`orangecheck: ${String(trouble?.message || trouble).slice(0, 120)}`);
      return say(response, 503, "Brickworks could not start a sign-in just now. Try again in a minute.");
    }
    if (may !== true) return say(response, 429, "Too many sign-ins tried from here. Wait a few minutes and try again.");
  }

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

  let account;
  let made = false;
  let minted;
  try {
    account = await db("rpc/oc_account_of", { method: "POST", body: { did } });
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
    if (trouble?.busy) return say(response, 503, "A lot of people are signing in just now. Try again in a minute.");
    return say(response, 502, "Brickworks could not finish the sign-in just now. Try again in a minute.");
  }

  // Bound before it is handed out, so a session orangecheck can end is never
  // in a browser without the means to end it.
  try {
    await db("rpc/oc_bind_session", { method: "POST", body: { session: minted.sessionId, account, did, rh, aud, iat } });
  } catch (trouble) {
    console.error(`orangecheck: the session was not bound: ${String(trouble?.message || trouble).slice(0, 120)}`);
    await endSession(minted.session.access_token);
    return say(response, 502, "Brickworks could not finish the sign-in just now. Try again in a minute.");
  }
  await endToken(token);

  const s = minted.session;
  return response.status(200).json({
    access_token: s.access_token,
    refresh_token: s.refresh_token,
    expires_in: s.expires_in,
    token_type: s.token_type,
    user: { id: s.user.id, email: s.user.email },
    orangecheck: { did, new_account: made },
  });
}

export default async function handler(request, response) {
  // Asked only by the site's own pages: no cross-origin answer, and nothing
  // kept by any cache.
  response.setHeader("Cache-Control", "no-store");
  const op = String(request.query?.op || "");
  if (request.method === "POST" && op === "signin") return signIn(request, response);
  return say(response, 405, "POST ?op=signin");
}
