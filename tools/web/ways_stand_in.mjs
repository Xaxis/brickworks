// Google, GitHub and orangecheck's Connect, stood in for in the relay
// (relay_server.mjs --ways-stand-in; signin3, 2026-11-24): the deployment's
// own sign-in code (api/_ways.js, api/_oc.js) runs against the real
// project, and the three services it calls answer from here, so a check
// proves a sign-in with Google or GitHub and the orangecheck account made
// around it without a client of either, or a real orangecheck account.
//
// The provider's sign-in page is the check's: it makes the code Google or
// GitHub would hand back (codeFor), which carries who signs in and the
// PKCE challenge and nonce the deployment sent; the token endpoints answer
// it only for the deployment's client id and secret, its redirect address,
// and the verifier whose S256 is that challenge, as the real ones do.
//
//   GET  /__ways/state             {provisions, deletes, revoked, tokens}
//   POST /__ways/oc {mode}         up, down (503), or slow (20 s, then up)
//
// The keys are the stand-in's own, set over whatever .env has, so nothing
// here is ever sent anywhere with a real one.
import { createHash, randomBytes } from "node:crypto";

export const KEYS = {
  GOOGLE_CLIENT_ID: "stand-in.apps.googleusercontent.com",
  GOOGLE_CLIENT_SECRET: "stand-in-google-secret",
  GITHUB_CLIENT_ID: "Iv1.standin0000000000",
  GITHUB_CLIENT_SECRET: "stand-in-github-secret",
  OC_CONNECT_KEY: "oc_connect_stand_in",
};

const state = { provisions: [], deletes: [], revoked: [], tokens: 0, mode: "up" };
const made = new Map();
const github = new Map();
let realFetch = null;

/// The GitHub id the stand-in gives [email] when a check names none.
export function githubId(email) {
  return 1 + (parseInt(createHash("sha256").update(String(email || "")).digest("hex").slice(0, 12), 16) % 2_000_000_000);
}

const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(String(verifier)).digest("base64url");
const json = (status, value) => new Response(value === null ? null : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });

/// The code Google or GitHub would hand back for [who] ({email, verified,
/// emails?, hd?, id?}), at the authorize address the deployment sent the
/// browser to. hd: the Google Workspace domain Google says the account is
/// of; id: GitHub's numeric id (by default one drawn from the address).
export function codeFor(authorize, who) {
  const asked = new URL(authorize);
  return b64({ ...who, client: asked.searchParams.get("client_id"), challenge: asked.searchParams.get("code_challenge"),
    nonce: asked.searchParams.get("nonce") || "", redirect: asked.searchParams.get("redirect_uri") });
}

function opened(code) {
  try {
    return JSON.parse(Buffer.from(String(code), "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

/// Whether [code] was made for this client, address and verifier.
function fits(code, { id, secret, redirect, verifier }, prefix) {
  return code && code.client === id && id === process.env[`${prefix}_CLIENT_ID`] && secret === process.env[`${prefix}_CLIENT_SECRET`]
    && redirect === code.redirect && challengeOf(verifier) === code.challenge;
}

async function answer(where, init) {
  const url = new URL(where);
  const method = String(init?.method || "GET").toUpperCase();
  if (url.href === "https://oauth2.googleapis.com/token" && method === "POST") {
    state.tokens += 1;
    const form = new URLSearchParams(String(init.body || ""));
    const code = opened(form.get("code"));
    if (form.get("grant_type") !== "authorization_code" || !fits(code, { id: form.get("client_id"), secret: form.get("client_secret"),
      redirect: form.get("redirect_uri"), verifier: form.get("code_verifier") }, "GOOGLE")) {
      return json(400, { error: "invalid_grant" });
    }
    const now = Math.floor(Date.now() / 1000);
    const said = { iss: "https://accounts.google.com", aud: code.client, sub: createHash("sha256").update(code.email).digest("hex").slice(0, 21),
      email: code.email, email_verified: code.verified !== false, nonce: code.nonce, iat: now, exp: now + 3600,
      ...(code.hd ? { hd: code.hd } : {}) };
    return json(200, { access_token: "ya29.stand-in", expires_in: 3599, scope: "openid email", token_type: "Bearer",
      id_token: `${b64({ alg: "RS256", kid: "stand-in" })}.${b64(said)}.c3RhbmQtaW4` });
  }
  if (url.href === "https://github.com/login/oauth/access_token" && method === "POST") {
    state.tokens += 1;
    const body = JSON.parse(String(init.body || "{}"));
    const code = opened(body.code);
    if (!fits(code, { id: body.client_id, secret: body.client_secret, redirect: body.redirect_uri, verifier: body.code_verifier }, "GITHUB")) {
      return json(200, { error: "bad_verification_code" });
    }
    const token = `gho_${randomBytes(18).toString("hex")}`;
    github.set(token, { emails: code.emails || [{ email: code.email, primary: true, verified: code.verified !== false, visibility: "private" }],
      id: Number.isSafeInteger(code.id) ? code.id : githubId(code.email || code.emails?.[0]?.email) });
    return json(200, { access_token: token, token_type: "bearer", scope: "user:email" });
  }
  if (url.href === "https://api.github.com/user/emails" && method === "GET") {
    const token = String(new Headers(init?.headers).get("authorization") || "").replace(/^Bearer /, "");
    return github.has(token) ? json(200, github.get(token).emails) : json(401, { message: "Bad credentials" });
  }
  if (url.href === "https://api.github.com/user" && method === "GET") {
    const token = String(new Headers(init?.headers).get("authorization") || "").replace(/^Bearer /, "");
    return github.has(token) ? json(200, { id: github.get(token).id, login: `stand-in-${github.get(token).id}` })
      : json(401, { message: "Bad credentials" });
  }
  const revoke = /^\/applications\/([^/]+)\/token$/.exec(url.pathname);
  if (url.host === "api.github.com" && revoke && method === "DELETE") {
    const basic = Buffer.from(String(new Headers(init?.headers).get("authorization") || "").replace(/^Basic /, ""), "base64").toString();
    const { access_token: token } = JSON.parse(String(init.body || "{}"));
    if (basic !== `${process.env.GITHUB_CLIENT_ID}:${process.env.GITHUB_CLIENT_SECRET}` || !github.delete(token)) return json(404, { message: "Not Found" });
    state.revoked.push(token.slice(0, 8));
    return new Response(null, { status: 204 });
  }
  if (url.origin === "https://ochk.io" && url.pathname.startsWith("/api/connect/")) {
    if (new Headers(init?.headers).get("authorization") !== `Bearer ${KEYS.OC_CONNECT_KEY}`) return json(401, { ok: false, reason: "invalid_api_key" });
    const body = JSON.parse(String(init.body || "{}"));
    if (url.pathname === "/api/connect/provision") {
      state.provisions.push({ user_id: body.user_id, consent: body.consent, email: body.email || null,
        email_verified: body.email_verified ?? null, mode: state.mode, at: Date.now() });
      if (state.mode === "down") return json(503, { ok: false, reason: "unavailable" });
      if (state.mode === "slow") await new Promise((done) => setTimeout(done, 20000));
      const known = made.get(body.user_id);
      const did = known || `did:oc:${createHash("sha256").update(`stand-in ${body.user_id}`).digest("hex").slice(0, 32)}`;
      made.set(body.user_id, did);
      return json(200, { ok: true, did_oc: did, is_new: !known });
    }
    if (url.pathname === "/api/connect/delete") {
      state.deletes.push(body.user_id);
      const was = made.delete(body.user_id);
      return json(200, { ok: true, result: was ? "deleted" : "already_deleted" });
    }
    return json(404, { ok: false, reason: "not_found" });
  }
  return null;
}

/// Google, GitHub and Connect answered here from now on, with the
/// stand-in's keys in the environment.
export function standInWays() {
  if (realFetch) return;
  Object.assign(process.env, KEYS);
  realFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const where = String(input?.url || input);
    if (/^https:\/\/(oauth2\.googleapis\.com|github\.com\/login\/oauth|api\.github\.com|ochk\.io)\//.test(where)) {
      const said = await answer(where, init);
      if (said) return said;
      throw new Error(`ways stand-in: nothing here answers ${where.split("?")[0]}`);
    }
    return realFetch(input, init);
  };
  console.log("ways stand-in: Google, GitHub and orangecheck Connect answered here");
}

/// /__ways/...: what a check reads and sets.
export function waysRoute(url, method, body) {
  if (url.pathname === "/__ways/state" && method === "GET") {
    return { status: 200, value: { ...state, made: Object.fromEntries(made) } };
  }
  if (url.pathname === "/__ways/oc" && method === "POST" && ["up", "down", "slow"].includes(body?.mode)) {
    state.mode = body.mode;
    return { status: 200, value: { mode: state.mode } };
  }
  return null;
}
