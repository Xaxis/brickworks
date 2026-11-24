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
//        ?then=/path                    where to land, on this site.
//        ?app=<loopback>&state=&code_challenge=
//                                       the desktop app, through the
//                                       person's own browser and back to it
//                                       on 127.0.0.1 (src/account/
//                                       orangecheck_sign_in.gd).
//   GET  /auth/callback/google|github   (?op=way_back) Google's or GitHub's
//                                       answer: the session handed over, to
//                                       /profile?then=…&with=…, which takes
//                                       it with ?op=way_take and goes on to
//                                       then; or to the app, as a sealed
//                                       one-time code it takes with
//                                       ?op=way_app and its PKCE verifier.
//                                       Refused, the same places with
//                                       ?failed=<why>.
//   POST ?op=way_take                   the session the callback left, once.
//   POST ?op=way_app {code, code_verifier}
//   GET  ?op=ways (signed in)           {code, google, github, offered}:
//                                       how this account signs in.
//   POST ?op=ways {with, on}            Google or GitHub unlinked (on false:
//                                       it no longer signs in to this
//                                       account) or linked again. The code to
//                                       the address always stays.
//
// Each is offered where its keys are (GOOGLE_CLIENT_ID and
// GOOGLE_CLIENT_SECRET, GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET, in
// Vercel) and its switch in the owner's console is not off
// (/admin#switches; site_settings sign_in_google, sign_in_github: never
// set, it follows its keys).
//
// What the browser holds between the start and the callback (the state,
// the PKCE verifier, Google's nonce, where to land) and the session handed
// to the page are sealed (AES-256-GCM, a key drawn from the server's
// secret), in cookies only this site's server reads (HttpOnly), for ten
// minutes and two. Nothing is kept in the database, and the provider's
// token is used once, for the address, and let go (GitHub's revoked).

import { createCipheriv, createDecipheriv, createHash, hkdfSync, randomBytes } from "node:crypto";
import { afterAnswer } from "./_after.js";
import { AuthError, bearer, verify } from "./_auth.js";
import { reach } from "./_db.js";
import { mintedSession } from "./_minted.js";
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

function sealKey() {
  return Buffer.from(hkdfSync("sha256", String(process.env.SUPABASE_SECRET_KEY || ""), "", "brickworks sign-in ways 1", 32));
}

export function seal(value) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", sealKey(), iv);
  const sealed = Buffer.concat([cipher.update(JSON.stringify(value), "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), sealed]).toString("base64url");
}

/// [text] opened, or null when it is not one of ours, or has run out (its x).
export function unseal(text) {
  try {
    const bytes = Buffer.from(String(text || ""), "base64url");
    if (bytes.length < 29) return null;
    const decipher = createDecipheriv("aes-256-gcm", sealKey(), bytes.subarray(0, 12));
    decipher.setAuthTag(bytes.subarray(12, 28));
    const value = JSON.parse(Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString("utf8"));
    return value && typeof value === "object" && Number(value.x) > Date.now() ? value : null;
  } catch {
    return null;
  }
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
const VERIFIER = /^[A-Za-z0-9._~-]{43,128}$/;

function appOf(query) {
  if (query?.app === undefined) return null;
  const app = { r: String(query.app || ""), s: String(query.state || ""), c: String(query.code_challenge || "") };
  return LOOPBACK.test(app.r) && APP_STATE.test(app.s) && CHALLENGE.test(app.c) ? app : false;
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
/// browser holds sealed until the callback.
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
  const verifier = b64url(randomBytes(32));
  const start = { w: name, s: b64url(randomBytes(16)), v: verifier, n: b64url(randomBytes(16)), t: then, a: app,
    x: Date.now() + 600_000 };
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
  response.setHeader("Set-Cookie", cookie(request, `bw_way_${name}`, seal(start), `/auth/callback/${name}`, 600));
  return response.status(302).setHeader("Location", `${way.authorize}?${to}`).end();
}

/// GET /auth/callback/<name>: the code traded for the person's verified
/// address, their account found or made, a session minted for it, and
/// handed to the page or the app.
export async function wayBack(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const name = String(request.query?.with || "");
  const way = WAYS[name];
  if (!way) return response.status(404).json({ error: "No such way to sign in." });
  const start = unseal(cookiesOf(request)[`bw_way_${name}`]);
  // Used once, whatever comes of it.
  response.setHeader("Set-Cookie", cookie(request, `bw_way_${name}`, "", `/auth/callback/${name}`, 0));
  if (!start || start.w !== name || String(request.query?.state || "") !== start.s) return failed(response, name, "again", start);
  if (request.query?.error) return failed(response, name, request.query.error === "access_denied" ? "denied" : "failed", start);
  const code = String(request.query?.code || "");
  const keys = way.keys();
  if (!code || code.length > 2048 || !keys) return failed(response, name, keys ? "failed" : "off", start);

  let who;
  try {
    who = await way.identify({ code, keys, verifier: start.v, nonce: start.n, redirect: callbackOf(request, name) });
  } catch (trouble) {
    console.error(`ways: ${name} gave no address: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed(response, name, trouble?.unverified ? "unverified" : "failed", start);
  }

  let minted;
  let made = false;
  try {
    made = await accountFor(who.email);
    minted = await mintedSession(who.email, {
      vet: (user) => {
        if (user?.app_metadata?.ways?.[name] === "off") throw Object.assign(new Error("unlinked"), { unlinked: true });
      },
    });
  } catch (trouble) {
    if (trouble?.unlinked) return failed(response, name, "unlinked", start);
    console.error(`ways: no session: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed(response, name, trouble?.busy ? "busy" : "failed", start);
  }
  // That it signs this account in, for Settings, after the answer.
  const account = minted.account;
  const ways = { ...(minted.user?.app_metadata?.ways || {}), [name]: new Date().toISOString() };
  afterAnswer(() => accountRecord(account, { ways }), "ways: kept");
  if (made) afterAnswer(() => raiseSignup({ account, email: who.email, scope: scopeOf(request), via: name }), "ways: sign-up");

  const s = minted.session;
  const session = { access_token: s.access_token, refresh_token: s.refresh_token, expires_in: s.expires_in,
    token_type: s.token_type, user: { id: s.user.id, email: s.user.email }, with: name, new_account: made };
  if (start.a) {
    const back = new URL(start.a.r);
    back.searchParams.set("code", seal({ s: session, c: start.a.c, x: Date.now() + 120_000 }));
    back.searchParams.set("state", start.a.s);
    return response.status(302).setHeader("Location", back.toString()).end();
  }
  response.setHeader("Set-Cookie", [cookie(request, `bw_way_${name}`, "", `/auth/callback/${name}`, 0),
    cookie(request, "bw_way_take", seal({ s: session, x: Date.now() + 120_000 }), "/api/otp", 120)]);
  const to = new URLSearchParams({ then: start.t, with: name });
  return response.status(302).setHeader("Location", `/profile?${to}`).end();
}

/// POST ?op=way_take: the session the callback left this browser, once
/// (web/account.js takeWay, from /profile).
export function wayTake(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const held = unseal(cookiesOf(request).bw_way_take);
  response.setHeader("Set-Cookie", cookie(request, "bw_way_take", "", "/api/otp", 0));
  if (!held?.s?.access_token) {
    return response.status(410).json({ error: "That sign-in took too long or was finished already. Sign in again." });
  }
  return response.status(200).json(held.s);
}

/// POST ?op=way_app {code, code_verifier}: the desktop app's session, for
/// the verifier whose challenge it started with.
export function wayApp(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const body = bodyOf(request);
  const verifier = typeof body?.code_verifier === "string" ? body.code_verifier : "";
  const held = VERIFIER.test(verifier) ? unseal(body?.code) : null;
  if (!held?.s?.access_token || held.c !== challengeOf(verifier)) {
    return response.status(410).json({ error: "That sign-in took too long or did not come through. Sign in again." });
  }
  return response.status(200).json(held.s);
}

/// GET ?op=ways: how the account signed in here signs in: {code, google,
/// github, offered}, each of google and github "on" (it has signed in with
/// it), "off" (unlinked) or "never". POST ?op=ways {with, on}: one unlinked
/// or linked again.
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
  let kept;
  try {
    kept = (await accountRecord(claims.sub)).ways || {};
    if (request.method === "POST") {
      const body = bodyOf(request);
      const name = String(body?.with || "");
      if (!WAYS[name] || typeof body?.on !== "boolean") return response.status(422).json({ error: "Google or GitHub, on or off." });
      if (!code) return response.status(409).json({ error: "This account signs in only with orangecheck." });
      const ways = { ...kept };
      if (body.on) delete ways[name];
      else ways[name] = "off";
      // The way back in that stays: a code to the address, whatever is unlinked.
      kept = (await accountRecord(claims.sub, { ways })).ways || {};
    }
  } catch (trouble) {
    console.error(`ways: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return response.status(502).json({ error: "Brickworks could not read how you sign in just now. Try again in a minute." });
  }
  const state = (name) => (kept[name] === "off" ? "off" : kept[name] ? "on" : "never");
  return response.status(200).json({ code, google: state("google"), github: state("github"),
    offered: await waysOffered(request) });
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

/// The account's server-only record (app_metadata): read, or [change]
/// merged into it key by key.
async function accountRecord(account, change = null) {
  const reply = await reach(`auth ${change ? "PUT" : "GET"} admin/users`, 10, `${supabase()}/auth/v1/admin/users/${encodeURIComponent(account)}`, {
    method: change ? "PUT" : "GET", headers: admin(), body: change ? JSON.stringify({ app_metadata: change }) : undefined });
  if (!reply.ok) throw new Error(`auth: the account was not ${change ? "kept" : "read"}: ${reply.status}`);
  return (await reply.json())?.app_metadata || {};
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

const unverified = (why) => Object.assign(new Error(why), { unverified: true });

/// Google's answer to [code]: the ID token, from Google's own token
/// endpoint over TLS, so its signature needs no checking (OpenID Connect
/// Core 3.1.3.7); its issuer, audience, expiry and the nonce this sign-in
/// began with are checked, and the address taken only as Google says it is
/// verified.
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
  const email = String(said.email || "").trim().toLowerCase();
  if (!email || !(said.email_verified === true || said.email_verified === "true")) throw unverified("Google: no verified address");
  return { email, id: String(said.sub || "") };
}

/// GitHub's answer to [code]: an access token, used for the person's
/// primary address as GitHub says it is verified, and then revoked. A
/// GitHub noreply address takes no mail, so it is no account here.
async function githubAddress({ code, keys, verifier, redirect }) {
  const reply = await reach("GitHub POST token", 10, WAYS.github.token, {
    method: "POST", headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({ client_id: keys.id, client_secret: keys.secret, code, redirect_uri: redirect,
      code_verifier: verifier }) });
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok || !body.access_token) throw new Error(`GitHub token: ${reply.status} ${String(body.error || "").slice(0, 40)}`);
  const asked = await reach("GitHub GET user/emails", 10, "https://api.github.com/user/emails", {
    headers: { authorization: `Bearer ${body.access_token}`, accept: "application/vnd.github+json",
      "user-agent": "Brickworks", "x-github-api-version": "2022-11-28" } });
  const emails = await asked.json().catch(() => null);
  afterAnswer(() => reach("GitHub DELETE token", 10, `https://api.github.com/applications/${encodeURIComponent(keys.id)}/token`, {
    method: "DELETE", headers: { authorization: `Basic ${Buffer.from(`${keys.id}:${keys.secret}`).toString("base64")}`,
      accept: "application/vnd.github+json", "user-agent": "Brickworks", "content-type": "application/json" },
    body: JSON.stringify({ access_token: body.access_token }) }), "ways: GitHub token");
  if (!asked.ok || !Array.isArray(emails)) throw new Error(`GitHub emails: ${asked.status}`);
  const primary = emails.find((one) => one?.primary === true && one?.verified === true);
  const email = String(primary?.email || "").trim().toLowerCase();
  if (!email || /@users\.noreply\.github\.com$/.test(email)) throw unverified("GitHub: no verified address that takes mail");
  return { email, id: "" };
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
