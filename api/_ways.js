// Signing in with Google and with GitHub (signin3, 2026-11-24), beside the
// emailed code (api/otp.js) and orangecheck (api/orangecheck.js). The
// owner: "both gmail and github oauth as signin options".
//
// Supabase's own Google and GitHub sign-in cannot make an account here:
// Brickworks takes no sign-ups at Supabase (disable_signup since
// 2026-10-24, supabase/no_new_ways_in.sql), since a public sign-up made an
// account at any address, and Supabase refuses a provider's new person
// then. So Brickworks is the client of each itself, by the authorization
// code with PKCE (RFC 7636, S256) and its own secret, and the account is
// the address, as for a code: the one Google or GitHub says is verified,
// found or made by the admin API as api/otp.js makes one, and signed in to
// with a session minted as orangecheck's is (api/_minted.js). An address
// that signs in by code is the same account when Google or GitHub gives it
// verified: never a second.
//
//   GET  /auth/google, /auth/github     (api/otp.js ?op=way_start&with=):
//        ?then=/path&take=<challenge>   where to land, on this site, and the
//                                       S256 challenge of a verifier the
//                                       page made and keeps (web/account.js
//                                       wayLink): the session handed back
//                                       opens only with it.
//        ?app=<loopback>&state=&code_challenge=
//                                       the desktop app, through the
//                                       person's own browser and back to it
//                                       on 127.0.0.1 (src/account/
//                                       orangecheck_sign_in.gd).
//   GET  /auth/callback/google|github   (?op=way_back) Google's or GitHub's
//                                       answer: the session handed over, to
//                                       /profile?then=…&with=…&take=…, which
//                                       takes it with ?op=way_take and its
//                                       verifier and goes on to then; or to
//                                       the app, as a sealed one-time code
//                                       it takes with ?op=way_app and its
//                                       PKCE verifier. Refused, the same
//                                       places with ?failed=<why>.
//   POST ?op=way_take {code_verifier}   the session the callback left, once.
//   POST ?op=way_app {code, code_verifier}
//   POST ?op=way_bind (signed in by a code just now)
//                                       GitHub's id, which met an account
//                                       it had not signed in to, kept for
//                                       it: GitHub signs it in from then on.
//   GET  ?op=ways (signed in)           {code, google, github, offered}:
//                                       how this account signs in.
//   POST ?op=ways {with, on}            Google or GitHub unlinked (on false:
//                                       it no longer signs in to this
//                                       account, and every session it
//                                       started ends; the session read
//                                       live) or linked again (a code of
//                                       the last five minutes first,
//                                       api/_oc.js stepUp). The address is
//                                       told of either. The code to the
//                                       address always stays.
//
// Each is offered where its keys are (GOOGLE_CLIENT_ID and
// GOOGLE_CLIENT_SECRET, GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET, in
// Vercel) and its switch in the owner's console is not off
// (/admin#switches; site_settings sign_in_google, sign_in_github: never
// set, it follows its keys).
//
// What the browser holds between the start and the callback (the state,
// the PKCE verifier, Google's nonce, where to land) and the session handed
// to the page or the app are sealed (AES-256-GCM), each kind with its own
// key drawn from the server's secret, so that none opens where another is
// taken (signinreview F1: the app's code, sent as the page's cookie, gave
// the session without its verifier). In cookies only this site's server
// reads (HttpOnly), for ten minutes and two; the session handed over opens
// only with the verifier whose challenge its start carried, and only once
// (its id spent, F4). Every session Google or GitHub starts is written down
// before it is handed out (supabase/sign_in_ways.sql), so that it is never
// taken for an emailed code (api/_oc.js codeOf) and Unlink ends it (F2).
// The provider's token is used once, for the address, and let go (GitHub's
// revoked).
//
// Whose word is taken for an address (F3): Google's only where Google is
// its authority, a Gmail address or a Workspace one whose hd is its
// domain; GitHub's, for an account it has not signed in to before, only
// after a code to that address (?op=way_bind), and its numeric id after
// that. An address that is not plain ASCII is no one's here (F5). Never
// for the owner's (MASTER_EMAIL), whose account opens the console, which
// moves money and data: it signs in by a code alone, and Google and GitHub
// are refused for it before anything is made or minted (signin4, F8).
//
// Whether a way signs an account in, or was unlinked from it, and GitHub's
// id, are rows of supabase/way_links.sql, changed only by its functions,
// one at a time per account and way, so a sign-in and an Unlink at the same
// moment never lose the Unlink: "off" always wins (F7). They were keys of
// the account's app_metadata, which GoTrue writes whole.
//
// How often (F9): each sign-in spends one of Supabase's verifies from this
// server's own address (api/_minted.js), shared by everyone's Google,
// GitHub and orangecheck sign-ins, so each Google or GitHub account is
// counted (LIMITS, below) right before it would spend one, once Google or
// GitHub has said who it is and the way is vetted, and one in a loop is
// refused before it spends any. Nothing is counted before that, and
// nothing per network (signin6, signreview2 SR2, signreview3 R2): a count
// anyone can fill from a school's or a carrier's address, with free
// accounts or none, locks out everyone there, and a try it refused used up
// the person's own count.
//
// A Claude connection approved from a Google or GitHub session is that
// way's: the code names the session, and is traded only while the session
// is there and its way still on, asked under the Unlink's lock, which then
// ends the connection with the sessions (api/oauth.js; signin6, SR1, R1).
// Whatever this file hands out on a session's say (a session taken, GitHub's
// id kept, Unlink's "this was you") asks that session as it is, never a
// held answer (api/_auth.js standingOf).

import { createCipheriv, createDecipheriv, createHash, hkdfSync, randomBytes } from "node:crypto";
import { afterAnswer } from "./_after.js";
import { AuthError, bearer, isMaster, sessionEnded, standingOf, verify } from "./_auth.js";
import { db, reach } from "./_db.js";
import { claimsOf as tokenClaims, clientAddress, mintedSession } from "./_minted.js";
import { raiseSignup } from "./_notify.js";
import { originOf } from "./_oauth.js";
import { scopeOf, settingOf } from "./_settings.js";

const NAMES = ["google", "github"];
const SAID = { google: "Google", github: "GitHub" };

/// Each provider as Brickworks is its client: where it signs people in,
/// its scopes, and how a code becomes a verified address.
export const WAYS = {
  google: {
    authorize: "https://accounts.google.com/o/oauth2/v2/auth",
    token: "https://oauth2.googleapis.com/token",
    // Who the person is, and the address: nothing else of theirs.
    scope: "openid email",
    keys: () => keysOf("GOOGLE"),
    extra: (start) => ({ nonce: start.n, prompt: "select_account" }),
    identify: googleAddress,
  },
  github: {
    authorize: "https://github.com/login/oauth/authorize",
    token: "https://github.com/login/oauth/access_token",
    // The addresses, to find the primary verified one; the profile is public.
    scope: "user:email",
    keys: () => keysOf("GITHUB"),
    extra: () => ({}),
    identify: githubAddress,
  },
};

function keysOf(prefix) {
  const id = String(process.env[`${prefix}_CLIENT_ID`] || "").trim();
  const secret = String(process.env[`${prefix}_CLIENT_SECRET`] || "").trim();
  return id && secret ? { id, secret } : null;
}

/// Which of Google and GitHub sign people in where [request] was made:
/// {google, github}, each true when its keys are here and the console's
/// switch there is not off.
export async function waysOffered(request) {
  const out = {};
  for (const name of NAMES) {
    if (!WAYS[name].keys()) {
      out[name] = false;
      continue;
    }
    const set = await settingOf(`sign_in_${name}`, request);
    out[name] = set?.value !== "off";
  }
  return out;
}

/// Where the provider sends the person back: this deployment's own
/// callback, which is the address registered with it (brickworks.diy's,
/// /admin#switches says which).
export function callbackOf(request, name) {
  return `${originOf(request)}/auth/callback/${name}`;
}

// ---------------------------------------------------------------------------
// Sealing: what the browser carries for the server, unreadable and unforgeable
// by it.

// Each kind of seal its own key: a start cookie, the page's session, the
// app's code and GitHub's id waiting for a code each open only as
// themselves.
const PURPOSES = new Set(["start", "take", "app", "bind"]);

function sealKey(purpose) {
  if (!PURPOSES.has(purpose)) throw new Error(`ways: no such seal: ${purpose}`);
  return Buffer.from(hkdfSync("sha256", String(process.env.SUPABASE_SECRET_KEY || ""), "",
    `brickworks sign-in ways 2 ${purpose}`, 32));
}

/// [value] sealed for [purpose] alone.
export function seal(value, purpose) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", sealKey(purpose), iv);
  const sealed = Buffer.concat([cipher.update(JSON.stringify(value), "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), sealed]).toString("base64url");
}

/// [text] opened as [purpose]'s, or null when it is not one of those, or
/// has run out (its x).
export function unseal(text, purpose) {
  try {
    const bytes = Buffer.from(String(text || ""), "base64url");
    if (bytes.length < 29) return null;
    const decipher = createDecipheriv("aes-256-gcm", sealKey(purpose), bytes.subarray(0, 12));
    decipher.setAuthTag(bytes.subarray(12, 28));
    const value = JSON.parse(Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString("utf8"));
    return value && typeof value === "object" && Number(value.x) > Date.now() ? value : null;
  } catch {
    return null;
  }
}

/// [held]'s id spent: true the first time it is redeemed, on any instance,
/// false ever after while it lasts (_oc.js spendToken's table). Throws when
/// that cannot be asked.
async function spend(held) {
  return (await db("rpc/oc_spend", { method: "POST",
    body: { token_id: `way ${held.i}`, until: new Date(Number(held.x)).toISOString() } })) === true;
}

const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");

function cookiesOf(request) {
  const out = {};
  for (const part of String(request.headers?.cookie || "").split(";")) {
    const at = part.indexOf("=");
    if (at > 0) out[part.slice(0, at).trim()] = part.slice(at + 1).trim();
  }
  return out;
}

function cookie(request, name, value, path, seconds) {
  const secure = originOf(request).startsWith("https:") ? "; Secure" : "";
  return `${name}=${value}; Path=${path}; Max-Age=${seconds}; HttpOnly; SameSite=Lax${secure}`;
}

// ---------------------------------------------------------------------------
// Where to land, and the app's way back.

/// [then], a path on this site to land on, or "/": never another site's
/// address (//host, /\host, a scheme), nor one too long to be a page's.
export function safeThen(then) {
  const path = String(then || "");
  return /^\/(?![/\\])[A-Za-z0-9._~!$&'()*+,;=:@%/?#-]{0,600}$/.test(path) ? path : "/";
}

// The desktop app's own address on this computer, as orangecheck's native
// sign-in has it (api/orangecheck.js): 127.0.0.1, a port, a plain path.
const LOOPBACK = /^http:\/\/127\.0\.0\.1:\d{1,5}\/[A-Za-z0-9._~/-]*$/;
const APP_STATE = /^[A-Za-z0-9_-]{8,128}$/;
const CHALLENGE = /^[A-Za-z0-9_-]{43}$/;
// A start's id, 16 random bytes (wayStart): one sealed before it has none,
// and is refused (all such would share one id).
const START_ID = /^[A-Za-z0-9_-]{22}$/;
const VERIFIER = /^[A-Za-z0-9._~-]{43,128}$/;

function appOf(query) {
  if (query?.app === undefined) return null;
  const app = { r: String(query.app || ""), s: String(query.state || ""), c: String(query.code_challenge || "") };
  return LOOPBACK.test(app.r) && APP_STATE.test(app.s) && CHALLENGE.test(app.c) ? app : false;
}

// ---------------------------------------------------------------------------
// How often (F9).
//
// Supabase allows the server's address 30 verifies at once and then one
// each 10 s: 90 in a quarter of an hour, for everyone's Google, GitHub and
// orangecheck sign-ins together, and a sign-in that finds none left reads
// "busy". So one Google or GitHub account, or one orangecheck id, comes
// back signed in at most 10 times in any 15 minutes: a loop of it takes 10
// of the 90, a third of the 30 at once, never all of either. Not 5
// (signin5): with nothing counted per network any more, every try of a
// person's is a real sign-in, and one who signs in at work on the site, the
// app and a phone, then at home, was shut out by their own (signreview3
// N2). Counted per identity its provider has verified, and only there
// (api/_minted.js, right before the verify): never per network, nor before
// anyone is known (signin6). A start costs nothing but the provider's page,
// and a way back is the one its start was for, its start's id spent first
// (wayBack), so a start cookie sent again is refused before Google or
// GitHub is asked. Each made-up way back costs one start, and one call of
// Google's or GitHub's token endpoint, which refuses it (signreview3 N1). A
// code to the address is never limited by these, so the words point to it.
export const LIMITS = { minutes: 15, account: 10 };

/// What each count is kept under in way_attempts (way_may_try): a provider
/// account's, by its id, and an orangecheck id's (api/orangecheck.js, as
/// many as a provider account's).
export const COUNTED = {
  account: (name, id) => `back ${name} ${id}`,
  orangecheck: (did) => `oc ${did}`,
};

/// The network [request] came from, as one key: an IPv4 address, or an
/// IPv6 address's first 64 bits. Nothing counts by it since signin6; kept
/// for the checks that prove so, which fill signin5's count of a network
/// under this key and sign in from it all the same (tools/web/ways_check.mjs
/// 12, signreview3's attack3.mjs).
export function networkOf(request) {
  const said = String(request?.headers?.["x-forwarded-for"] || "").split(",")[0].trim()
    || String(request?.socket?.remoteAddress || "");
  const address = said.replace(/^::ffff:(?=\d+\.\d+\.\d+\.\d+$)/i, "").toLowerCase();
  if (!address.includes(":")) return address.slice(0, 64);
  const [head, tail = null] = address.split("::");
  const left = head ? head.split(":") : [];
  const right = tail === null ? [] : tail ? tail.split(":") : [];
  const groups = tail === null ? left : [...left, ...Array(Math.max(0, 8 - left.length - right.length)).fill("0"), ...right];
  return `${groups.slice(0, 4).map((group) => group.replace(/^0+(?=.)/, "")).join(":")}::/64`;
}

/// Where a refused sign-in goes: back to the app with its error, or to the
/// site's sign-in with words for why (web/profile.js wayFailed).
function failed(response, name, why, start) {
  if (start?.a) {
    const back = new URL(start.a.r);
    back.searchParams.set("error", why);
    back.searchParams.set("state", start.a.s);
    return response.status(302).setHeader("Location", back.toString()).end();
  }
  const to = new URLSearchParams({ "sign-in": "", then: safeThen(start?.t), with: name, failed: why });
  return response.status(302).setHeader("Location", `/profile?${to}`).end();
}

// ---------------------------------------------------------------------------
// The routes.

/// GET /auth/<name>: to Google or GitHub, with this deployment's client, the
/// scope, a fresh state, and a PKCE challenge whose verifier the person's
/// browser holds sealed until the callback. From a page, take is the
/// challenge of the page's own verifier: without one, nothing is started.
export async function wayStart(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const name = String(request.query?.with || "");
  const way = WAYS[name];
  if (!way) return response.status(404).json({ error: "No such way to sign in." });
  const app = appOf(request.query);
  const then = safeThen(request.query?.then);
  if (app === false) return response.status(422).json({ error: "The app's sign-in did not come through. Try again." });
  const keys = way.keys();
  if (!keys || !(await waysOffered(request))[name]) return failed(response, name, "off", { t: then, a: app });
  const take = app ? "" : String(request.query?.take || "");
  if (!app && !CHALLENGE.test(take)) return failed(response, name, "again", { t: then });
  const verifier = b64url(randomBytes(32));
  // i: its id, spent at its way back, which it buys once (SR2).
  const start = { w: name, s: b64url(randomBytes(16)), v: verifier, n: b64url(randomBytes(16)), t: then, a: app, k: take,
    i: b64url(randomBytes(16)), x: Date.now() + 600_000 };
  const to = new URLSearchParams({
    client_id: keys.id,
    redirect_uri: callbackOf(request, name),
    response_type: "code",
    scope: way.scope,
    state: start.s,
    code_challenge: challengeOf(verifier),
    code_challenge_method: "S256",
    ...way.extra(start),
  });
  response.setHeader("Set-Cookie", cookie(request, `bw_way_${name}`, seal(start, "start"), `/auth/callback/${name}`, 600));
  return response.status(302).setHeader("Location", `${way.authorize}?${to}`).end();
}

/// GET /auth/callback/<name>: the code traded for the person's verified
/// address, their account found or made, a session minted for it, written
/// down as this way's, and handed to the page or the app.
export async function wayBack(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const name = String(request.query?.with || "");
  const way = WAYS[name];
  if (!way) return response.status(404).json({ error: "No such way to sign in." });
  const start = unseal(cookiesOf(request)[`bw_way_${name}`], "start");
  // Used once, whatever comes of it.
  response.setHeader("Set-Cookie", cookie(request, `bw_way_${name}`, "", `/auth/callback/${name}`, 0));
  if (!start || start.w !== name || String(request.query?.state || "") !== start.s) return failed(response, name, "again", start);
  if (!start.a && !CHALLENGE.test(String(start.k || ""))) return failed(response, name, "again", start);
  if (request.query?.error) return failed(response, name, request.query.error === "access_denied" ? "denied" : "failed", start);
  const code = String(request.query?.code || "");
  const keys = way.keys();
  if (!code || code.length > 2048 || !keys) return failed(response, name, keys ? "failed" : "off", start);
  // One start, one way back (SR2): its id spent before Google or GitHub is
  // asked or anything counted, so its cookie sent again, by anyone, is
  // refused here, at no cost to the start's network.
  if (!START_ID.test(String(start.i || ""))) return failed(response, name, "again", start);
  try {
    if (!(await spend(start))) return failed(response, name, "again", start);
  } catch (trouble) {
    console.error(`ways: the start was not spent: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed(response, name, "failed", start);
  }

  let who;
  try {
    who = await way.identify({ code, keys, verifier: start.v, nonce: start.n, redirect: callbackOf(request, name) });
  } catch (trouble) {
    console.error(`ways: ${name} gave no address: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed(response, name, trouble?.unverified ? trouble.reason : "failed", start);
  }
  // The owner's account: by a code alone (F8). Nothing is made or minted.
  if (isMaster({ email: who.email })) return failed(response, name, "code_only", start);

  let minted;
  let made = false;
  try {
    made = await accountFor(who.email);
    // Counted by this Google or GitHub account alone, once the way is
    // vetted, right before Supabase's verify is spent (signin6).
    minted = await mintedSession(who.email, { vet: (user) => vetFor(name, who, user, made),
      count: { key: COUNTED.account(name, who.id), per: LIMITS.account, minutes: LIMITS.minutes }, from: clientAddress(request) });
  } catch (trouble) {
    if (trouble?.unlinked) return failed(response, name, "unlinked", start);
    if (trouble?.confirm) return confirmFirst(request, response, name, who, trouble.account, start);
    if (trouble?.often) return failed(response, name, "often", start);
    console.error(`ways: no session: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed(response, name, trouble?.busy ? "busy" : "failed", start);
  }
  const account = minted.account;
  try {
    await keep(name, who, minted, made);
  } catch (trouble) {
    await db("rpc/oc_end_session", { method: "POST", body: { session: minted.sessionId } })
      .catch((again) => console.error(`ways: a session not handed out is left to run out: ${String(again?.message || again).slice(0, 120)}`));
    if (trouble?.unlinked) return failed(response, name, "unlinked", start);
    if (trouble?.confirm) return confirmFirst(request, response, name, who, account, start);
    console.error(`ways: not handed out: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed(response, name, "failed", start);
  }
  if (made) afterAnswer(() => raiseSignup({ account, email: who.email, scope: scopeOf(request), via: name }), "ways: sign-up");

  const s = minted.session;
  const session = { access_token: s.access_token, refresh_token: s.refresh_token, expires_in: s.expires_in,
    token_type: s.token_type, user: { id: s.user.id, email: s.user.email }, with: name, new_account: made };
  // Each handed over once (its id, spent at the take) and to the verifier
  // its start carried alone.
  const i = b64url(randomBytes(16));
  const x = Date.now() + 120_000;
  if (start.a) {
    const back = new URL(start.a.r);
    back.searchParams.set("code", seal({ s: session, c: start.a.c, i, x }, "app"));
    back.searchParams.set("state", start.a.s);
    return response.status(302).setHeader("Location", back.toString()).end();
  }
  response.setHeader("Set-Cookie", [cookie(request, `bw_way_${name}`, "", `/auth/callback/${name}`, 0),
    cookie(request, "bw_way_take", seal({ s: session, c: start.k, i, x }, "take"), "/api/otp", 120)]);
  const to = new URLSearchParams({ then: start.t, with: name, take: start.k });
  return response.status(302).setHeader("Location", `/profile?${to}`).end();
}

const unlinked = () => Object.assign(new Error("unlinked"), { unlinked: true });
const unconfirmed = (account) => Object.assign(new Error("confirm"), { confirm: true, account });

/// Whether [name] may sign in to [user]'s account, asked before a session
/// is minted, so that one refused spends nothing: never once it is
/// unlinked; GitHub, to an account it did not make just now and has not
/// signed in to with this id, only after a code (confirm, F3: an address
/// GitHub verified once may have changed hands). keep() asks again, and
/// decides.
async function vetFor(name, who, user, made) {
  const link = (await linksOf(String(user?.id || "")))[name];
  if (link?.state === "off") throw unlinked();
  if (name === "github" && !made && String(link?.id || "") !== who.id) throw unconfirmed(String(user?.id || ""));
}

/// [minted]'s session kept as [name]'s, or ended, in one step
/// (way_signed_in, supabase/way_links.sql): written down as the way's, and
/// the way signing the account in, unless the way is unlinked or, for
/// GitHub, this is not the id kept (nor one to keep: [made], a new
/// account). It holds the account's way while it reads and writes, as an
/// Unlink does, so the two never undo each other, and "off" always wins
/// (F7). Throws when it is not kept.
async function keep(name, who, minted, made) {
  const kept = await db("rpc/way_signed_in", { method: "POST", body: { session: minted.sessionId,
    account: minted.account, way: name, provider_id: name === "github" ? who.id : null, bind: made } });
  if (kept === "off") throw unlinked();
  if (kept === "confirm") throw unconfirmed(minted.account);
  if (kept !== "on") throw new Error("the session was not written down");
}

/// GitHub's address is an account's here that GitHub has not signed in to
/// with this id: nothing is handed out. Its id, sealed, waits in this
/// browser for 15 minutes while the page signs in with a code to that
/// address, then keeps it (?op=way_bind). The app is told to sign in with
/// a code, and with GitHub on the site once.
function confirmFirst(request, response, name, who, account, start) {
  if (start.a || !account) return failed(response, name, "confirm", start);
  const held = { a: account, w: name, n: who.id, i: b64url(randomBytes(16)), x: Date.now() + 900_000 };
  response.setHeader("Set-Cookie", [cookie(request, `bw_way_${name}`, "", `/auth/callback/${name}`, 0),
    cookie(request, "bw_way_bind", seal(held, "bind"), "/api/otp", 900)]);
  return failed(response, name, "confirm", start);
}

const GONE = "That sign-in took too long or was finished already. Sign in again.";

/// [held] handed over, the first time its id is redeemed, and only while
/// its session is there, as its way's, read as it is now: an Unlink in the
/// two minutes since the callback ended it (signin6).
async function handOver(held, response) {
  let first;
  let standing;
  try {
    first = await spend(held);
    standing = first ? await standingOf(tokenClaims(held.s.access_token)) : null;
  } catch (trouble) {
    console.error(`ways: not handed over: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return response.status(503).json({ error: "Brickworks could not finish signing you in just now. Sign in again in a minute." });
  }
  if (!first || !standing?.exists || standing.way !== held.s.with) return response.status(410).json({ error: GONE });
  return response.status(200).json(held.s);
}

/// POST ?op=way_take {code_verifier}: the session the callback left this
/// browser, once, for the verifier whose challenge the page started with
/// (web/account.js takeWay, from /profile).
export async function wayTake(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const held = unseal(cookiesOf(request).bw_way_take, "take");
  response.setHeader("Set-Cookie", cookie(request, "bw_way_take", "", "/api/otp", 0));
  const verifier = String(bodyOf(request)?.code_verifier || "");
  if (!held?.s?.access_token || !VERIFIER.test(verifier) || held.c !== challengeOf(verifier)) {
    return response.status(410).json({ error: GONE });
  }
  return handOver(held, response);
}

/// POST ?op=way_app {code, code_verifier}: the desktop app's session, once,
/// for the verifier whose challenge it started with.
export async function wayApp(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const body = bodyOf(request);
  const verifier = typeof body?.code_verifier === "string" ? body.code_verifier : "";
  const held = VERIFIER.test(verifier) ? unseal(body?.code, "app") : null;
  if (!held?.s?.access_token || held.c !== challengeOf(verifier)) {
    return response.status(410).json({ error: "That sign-in took too long or did not come through. Sign in again." });
  }
  return handOver(held, response);
}

/// POST ?op=way_bind: GitHub's id that met this account (confirmFirst)
/// kept for it, once its person has signed in with a code to its address
/// in the last five minutes (api/_oc.js codeOf): GitHub signs it in from
/// then on. {with}. Not yet signed in so: 403 {fresh: false}, and the id
/// waits on.
export async function wayBind(request, response) {
  response.setHeader("Cache-Control", "no-store");
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    return response.status(trouble instanceof AuthError ? trouble.status : 401).json({ error: trouble.message });
  }
  const held = unseal(cookiesOf(request).bw_way_bind, "bind");
  const done = () => response.setHeader("Set-Cookie", cookie(request, "bw_way_bind", "", "/api/otp", 0));
  if (!held || !WAYS[held.w] || held.a !== claims.sub) {
    done();
    return response.status(410).json({ error: "That GitHub sign-in took too long, or was for another account. Sign in with GitHub again." });
  }
  try {
    // The one rule (api/_oc.js stepUp): the session as it is now (gone,
    // 401) and a code of the last five minutes; and that code an emailed
    // one, never a test account's password.
    const { stepUp } = await import("./_oc.js");
    const may = await stepUp(claims);
    if (may.status && may.status !== 403) return response.status(may.status).json(may.body);
    if (may.status || !may.asked.emailed) {
      return response.status(403).json({ error: "Sign in with a code we email you first.", fresh: false });
    }
    done();
    if (!(await spend(held))) return response.status(410).json({ error: GONE });
    const bound = await db("rpc/way_bind", { method: "POST", body: { account: claims.sub, way: held.w, provider_id: held.n } });
    if (bound === "off") {
      return response.status(409).json({ error: "GitHub is unlinked from your account. Link it again in Settings first." });
    }
    if (bound !== "on") throw new Error(`way_bind said ${JSON.stringify(bound)}`);
  } catch (trouble) {
    if (trouble instanceof AuthError) return response.status(trouble.status).json({ error: trouble.message });
    console.error(`ways: GitHub not kept: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return response.status(502).json({ error: "Brickworks could not keep GitHub for you just now. Sign in with GitHub again in a minute." });
  }
  return response.status(200).json({ with: held.w });
}

/// GET ?op=ways: how the account signed in here signs in: {code, google,
/// github, offered}, each of google and github "on" (it has signed in with
/// it), "off" (unlinked) or "never". POST ?op=ways {with, on}: one unlinked
/// or linked again; unlinked, every session it started ends, and
/// signed_out: true when this was one of them.
export async function waysRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    return response.status(trouble instanceof AuthError ? trouble.status : 401).json({ error: trouble.message });
  }
  // An orangecheck account's made-up address has no code, nor any provider's.
  const code = !/@oc\.brickworks\.diy$/i.test(String(claims.email || ""));
  let links;
  let you = false;
  let changed = null;
  try {
    if (request.method === "POST") {
      const body = bodyOf(request);
      const name = String(body?.with || "");
      if (!WAYS[name] || typeof body?.on !== "boolean") return response.status(422).json({ error: "Google or GitHub, on or off." });
      if (!code) return response.status(409).json({ error: "This account signs in only with orangecheck." });
      if (body.on) {
        // Linked again gives the account a way in: the one rule (api/_oc.js
        // stepUp, signin7), the session as it is now and a code of the last
        // five minutes, so neither the way's own session nor one an Unlink
        // has just ended can undo the Unlink (signreview4 R4-1 L1).
        const { stepUp } = await import("./_oc.js");
        const may = await stepUp(claims);
        if (may.status) return response.status(may.status).json(may.body);
        // Only a way unlinked is linked again, as never used, so GitHub asks
        // a code once more before it signs in. One signing in already (a
        // stale tab that still shows Unlinked) is left as it is: way_set
        // would have dropped its row, and GitHub's id with it (N3).
        if ((await linksOf(claims.sub))[name]?.state === "off") {
          await db("rpc/way_set", { method: "POST", body: { account: claims.sub, way: name, turned_on: true } });
          changed = "on";
        }
      } else {
        // Unlinked takes a way away and gives none, so it asks the session
        // as it is now alone (standingOf, never verify()'s held read): one
        // gone is 401 here too; and whether it is one the way started, before
        // it ends. Off, GitHub's id let go, and every session the way started
        // ended (F2), in one step that waits for a sign-in of the same way, or
        // makes it wait (F7).
        const standing = await standingOf(claims);
        if (!standing.exists) return response.status(401).json({ error: "You were signed out. Sign in again." });
        you = standing.way === name;
        const was = (await linksOf(claims.sub))[name]?.state;
        await db("rpc/way_set", { method: "POST", body: { account: claims.sub, way: name, turned_on: false } });
        if (was === "on") changed = "off";
        if (you) sessionEnded(claims.session_id);
      }
      // The address told, as orangecheck's link and unlink tell it (N4).
      if (changed) {
        const told = String(claims.email || "");
        afterAnswer(async () => {
          const { AFTER, tell } = await import("./_oc.js");
          await tell(told, changed === "on" ? `${SAID[name]} signs you in to Brickworks again`
            : `${SAID[name]} no longer signs you in to Brickworks`, changed === "on"
            ? `${SAID[name]} was linked to your Brickworks account again just now, so it can sign you in. ${AFTER}`
            : `${SAID[name]} was unlinked from your Brickworks account just now, and the sign-ins it started were ended. ${AFTER}`);
        }, "ways: notice");
      }
    }
    links = await linksOf(claims.sub);
  } catch (trouble) {
    console.error(`ways: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return response.status(502).json({ error: "Brickworks could not read how you sign in just now. Try again in a minute." });
  }
  const state = (name) => links[name]?.state === "off" ? "off" : links[name] ? "on" : "never";
  // The owner's account signs in by a code alone (F8): neither is offered.
  const offered = isMaster(claims) ? { google: false, github: false } : await waysOffered(request);
  return response.status(200).json({ code, google: state("google"), github: state("github"),
    offered, ...(you ? { signed_out: true } : {}) });
}

// ---------------------------------------------------------------------------
// The account.

function admin() {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" };
}

function supabase() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// [email]'s account made, as api/otp.js mint makes one, when it has none:
/// true when it was made just now.
async function accountFor(email) {
  const made = await reach("auth POST admin/users", 10, `${supabase()}/auth/v1/admin/users`, {
    method: "POST", headers: admin(), body: JSON.stringify({ email, email_confirm: true }) });
  if (!made.ok && made.status !== 422) throw new Error(`auth: no account made: ${made.status}`);
  return made.ok;
}

/// How [account] signs in with Google and GitHub (way_links_of): {google:
/// {state, id}, github: {...}}, each "on" or "off", a way never used left
/// out. Throws when it cannot be read.
async function linksOf(account) {
  const links = await db("rpc/way_links_of", { method: "POST", body: { account } });
  return links && typeof links === "object" ? links : {};
}

// ---------------------------------------------------------------------------
// The providers.

function claimsOf(jwt) {
  try {
    return JSON.parse(Buffer.from(String(jwt).split(".")[1], "base64url").toString("utf8"));
  } catch {
    return {};
  }
}

/// Refused as no verified address of the person's: [reason] is what the
/// page and the app are told (failed): unverified, or vouch (Google is not
/// the authority for that address).
const unverified = (why, reason = "unverified") => Object.assign(new Error(why), { unverified: true, reason });

// An address as a provider gives it: plain ASCII, or it is no one's here.
// JavaScript lowercases some letters of other scripts into ASCII ones
// (U+212A KELVIN SIGN into k), so one could sign in to another's account
// (F5).
const ASCII_ADDRESS = /^[!-~]{1,200}@[!-~]{1,200}$/;

// The domains whose addresses Google itself holds, and so vouches for.
const GOOGLE_HELD = new Set(["gmail.com", "googlemail.com"]);

/// Whether Google is the authority for [email] (lowercased), its ID token
/// saying [hd]: a Gmail address, or a Workspace one of that very domain.
export function googleVouches(email, hd) {
  const domain = String(email || "").slice(String(email || "").lastIndexOf("@") + 1);
  return Boolean(domain) && (GOOGLE_HELD.has(domain) || (typeof hd === "string" && hd.trim().toLowerCase() === domain));
}

/// Google's answer to [code]: the ID token, from Google's own token
/// endpoint over TLS, so its signature needs no checking (OpenID Connect
/// Core 3.1.3.7); its issuer, audience, expiry and the nonce this sign-in
/// began with are checked, and the address taken only as Google says it is
/// verified, and only where Google is the authority for it: a Gmail
/// address, or a Workspace one whose hd is its own domain. Of any other,
/// Google says email_verified "is not authoritative" and its ownership "may
/// have since changed" (F3), so it is refused, and never reaches an account
/// here.
async function googleAddress({ code, keys, verifier, nonce, redirect }) {
  const reply = await reach("Google POST token", 10, WAYS.google.token, {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
    body: new URLSearchParams({ code, client_id: keys.id, client_secret: keys.secret, redirect_uri: redirect,
      grant_type: "authorization_code", code_verifier: verifier }).toString() });
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok || !body.id_token) throw new Error(`Google token: ${reply.status} ${String(body.error || "").slice(0, 40)}`);
  const said = claimsOf(body.id_token);
  if (!["https://accounts.google.com", "accounts.google.com"].includes(said.iss) || said.aud !== keys.id
    || said.nonce !== nonce || !(Number(said.exp) * 1000 > Date.now())) {
    throw new Error("Google's ID token was not for this sign-in");
  }
  const given = String(said.email || "").trim();
  if (!given || !(said.email_verified === true || said.email_verified === "true")) throw unverified("Google: no verified address");
  if (!ASCII_ADDRESS.test(given)) throw unverified("Google: an address that is not plain ASCII");
  const email = given.toLowerCase();
  if (!googleVouches(email, said.hd)) throw unverified("Google: not the authority for that address", "vouch");
  return { email, id: String(said.sub || "") };
}

/// GitHub's answer to [code]: an access token, used for the person's
/// numeric id and primary address as GitHub says it is verified, and then
/// revoked. A GitHub noreply address takes no mail, so it is no account
/// here.
async function githubAddress({ code, keys, verifier, redirect }) {
  const reply = await reach("GitHub POST token", 10, WAYS.github.token, {
    method: "POST", headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({ client_id: keys.id, client_secret: keys.secret, code, redirect_uri: redirect,
      code_verifier: verifier }) });
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok || !body.access_token) throw new Error(`GitHub token: ${reply.status} ${String(body.error || "").slice(0, 40)}`);
  const headers = { authorization: `Bearer ${body.access_token}`, accept: "application/vnd.github+json",
    "user-agent": "Brickworks", "x-github-api-version": "2022-11-28" };
  const [asked, them] = await Promise.all([
    reach("GitHub GET user/emails", 10, "https://api.github.com/user/emails", { headers }),
    reach("GitHub GET user", 10, "https://api.github.com/user", { headers }),
  ]);
  const [emails, user] = await Promise.all([asked.json().catch(() => null), them.json().catch(() => null)]);
  afterAnswer(() => reach("GitHub DELETE token", 10, `https://api.github.com/applications/${encodeURIComponent(keys.id)}/token`, {
    method: "DELETE", headers: { authorization: `Basic ${Buffer.from(`${keys.id}:${keys.secret}`).toString("base64")}`,
      accept: "application/vnd.github+json", "user-agent": "Brickworks", "content-type": "application/json" },
    body: JSON.stringify({ access_token: body.access_token }) }), "ways: GitHub token");
  if (!asked.ok || !Array.isArray(emails)) throw new Error(`GitHub emails: ${asked.status}`);
  if (!them.ok || !Number.isSafeInteger(user?.id) || user.id <= 0) throw new Error(`GitHub user: ${them.status}`);
  const primary = emails.find((one) => one?.primary === true && one?.verified === true);
  const given = String(primary?.email || "").trim();
  if (!given || /@users\.noreply\.github\.com$/i.test(given)) throw unverified("GitHub: no verified address that takes mail");
  if (!ASCII_ADDRESS.test(given)) throw unverified("GitHub: an address that is not plain ASCII");
  return { email: given.toLowerCase(), id: String(user.id) };
}

function bodyOf(request) {
  if (typeof request.body !== "string") return request.body || {};
  try {
    return JSON.parse(request.body);
  } catch {
    return {};
  }
}

export { SAID };
