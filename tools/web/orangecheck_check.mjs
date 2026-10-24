// Signing in with orangecheck, checked on this machine against the real
// database: api/orangecheck.js run in this process, with only orangecheck
// itself stood in for. The tokens are signed here with a key of our own,
// served as ochk.io's key set; the project's rule and the list of ended
// sessions are answered here too. Everything on Brickworks' side is real:
// supabase/orangecheck.sql's functions, Supabase's admin API, the session
// minted and then used against api/account.js.
//
//   set -a; . ./.env; set +a
//   node tools/web/orangecheck_check.mjs
//
// One line a check, then "orangecheck_check: N passed, M failed". Every
// account it makes is deleted at the end, whatever happened.

import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import { deleteAccount, mintCode, mintSession } from "./session.mjs";

const AUD = "http://127.0.0.1:8841";
process.env.OC_AUDIENCE = AUD;
process.env.OC_PROJECT_KEY ||= "pk_test_orangecheck_check";
process.env.OC_SIGNING_SECRET ||= "orangecheck-check-secret";
delete process.env.VERCEL_ENV;
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SECRET_KEY || !process.env.SUPABASE_PUBLISHABLE_KEY) {
  console.error("orangecheck_check: no SUPABASE_* — source .env");
  process.exit(2);
}
const SB = process.env.SUPABASE_URL.replace(/\/+$/, "");
const ADMIN = { apikey: process.env.SUPABASE_SECRET_KEY, authorization: `Bearer ${process.env.SUPABASE_SECRET_KEY}` };
const PUBLIC = { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" };

// orangecheck, stood in for.
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const stranger = generateKeyPairSync("ed25519");
const KID = "check-key";
const jwk = { ...publicKey.export({ format: "jwk" }), kid: KID, alg: "EdDSA", use: "sig" };
const ochk = {
  jwksStatus: 200,
  rule: { ok: true, require_bond: null },
  ruleStatus: 200,
  list: () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: {} }),
  listStatus: 200,
  revoked: [],
};

const made = new Set();
// Brickworks' own answers, reached into for the review's races (oc205): run
// once just before a session is bound; the last session Supabase minted;
// what the database says of a session, changed.
const hooks = { beforeBind: null, minted: null, sessionOf: null, mail: [], signupOff: new Set() };
// Two email accounts, at Resend's test addresses, which reach nobody.
const tag = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-oc-ada-${tag}@resend.dev`;
const bobEmail = `delivered+bw-oc-bob-${tag}@resend.dev`;
const real = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = String(input?.url || input);
  const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
  if (url === "https://ochk.io/.well-known/jwks.json") return ochk.jwksStatus === 200 ? json(200, { keys: [jwk] }) : json(ochk.jwksStatus, {});
  if (url.startsWith("https://me.ochk.io/api/integrator/revocations")) return json(ochk.listStatus, ochk.list());
  if (/^https:\/\/me\.ochk\.io\/api\/integrator\/[^/]+\/sign-in$/.test(url)) return json(ochk.ruleStatus, ochk.rule);
  if (url === "https://ochk.io/api/auth/revoke") {
    ochk.revoked.push(...JSON.parse(init.body).tokens);
    return json(200, { ok: true, revoked: 1 });
  }
  if (/^https:\/\/([a-z0-9-]+\.)*ochk\.(io|app)\//.test(url)) throw new Error(`orangecheck_check: unexpected ${url}`);
  // Mail is caught here, never sent: api/otp.js's codes, and the notices
  // linking sends.
  if (url === "https://api.resend.com/emails") {
    hooks.mail.push(JSON.parse(init.body));
    return json(200, { id: "caught-by-orangecheck-check" });
  }
  // Supabase taking no sign-ups, for one new address: its first code.
  if (url === `${SB}/auth/v1/admin/generate_link` && hooks.signupOff.has(JSON.parse(init.body || "{}").email)) {
    hooks.signupOff.delete(JSON.parse(init.body).email);
    return json(422, { code: 422, error_code: "signup_disabled", msg: "Signups not allowed for this instance" });
  }
  if (url === `${SB}/rest/v1/rpc/oc_bind_session` && hooks.beforeBind) {
    const before = hooks.beforeBind;
    hooks.beforeBind = null;
    await before();
  }
  const reply = await real(input, init);
  if (url === `${SB}/auth/v1/verify` && reply.ok) hooks.minted = await reply.clone().json();
  if (url === `${SB}/rest/v1/rpc/oc_session_of` && hooks.sessionOf && reply.ok) return json(200, hooks.sessionOf(await reply.json()));
  // Every account Supabase makes for this run, so the end can delete them.
  if (url === `${SB}/auth/v1/admin/users` && (init.method || "GET") === "POST" && reply.ok) {
    const copy = await reply.clone().json();
    if (copy.id) made.add(copy.id);
  }
  return reply;
};

const b64 = (value) => Buffer.from(typeof value === "string" ? value : JSON.stringify(value)).toString("base64url");
function token(claims = {}, { key = privateKey, kid = KID, alg = "EdDSA" } = {}) {
  const now = Math.floor(Date.now() / 1000);
  const body = { iss: "https://ochk.io", aud: AUD, sub: `acct_${randomBytes(6).toString("hex")}`,
    did_oc: `did:oc:${randomBytes(16).toString("hex")}`, jti: randomBytes(12).toString("hex"),
    rh: randomBytes(16).toString("base64url"), iat: now, exp: now + 3600, ...claims };
  for (const [name, value] of Object.entries(claims)) if (value === undefined) delete body[name];
  const head = b64({ alg, kid, typ: "JWT" });
  const signed = `${head}.${b64(body)}`;
  return { jwt: `${signed}.${sign(null, Buffer.from(signed), key).toString("base64url")}`, claims: body };
}

const { forgetForTests } = await import("../../api/_oc.js");
const signInRoute = (await import("../../api/orangecheck.js")).default;
/// The route, with what it read from orangecheck (the rule, the list)
/// forgotten, as on a new instance.
async function route() {
  forgetForTests();
  return signInRoute;
}

// Each call from an address of its own (2001:db8::/32 is for documentation),
// unless it says which: the rate limit is checked on its own, below.
const anywhere = () => `2001:db8::${randomBytes(4).toString("hex").replace(/(.{4})/, "$1:")}`;

async function call(handler, body, { method = "POST", op = "signin", ip = anywhere() } = {}) {
  let status = 0;
  let answer = null;
  const response = {
    headers: {},
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; return this; },
    status(code) { status = code; return this; },
    json(value) { answer = value; return this; },
    end() { return this; },
  };
  await handler({ method, query: { op }, headers: { "x-forwarded-for": ip }, body }, response);
  return { status, body: answer, headers: response.headers };
}

const account = (await import("../../api/account.js")).default;
/// What /api/account says of a session: who it is.
async function whoIs(access) {
  let status = 0;
  let answer = null;
  const response = { setHeader() { return this; }, status(code) { status = code; return this; }, json(value) { answer = value; return this; } };
  await account({ method: "GET", query: {}, headers: access ? { authorization: `Bearer ${access}` } : {} }, response);
  return { status, body: answer };
}

let passed = 0;
let failed = 0;
/// [text] with every token in it taken out: a JWT (a session's, or
/// orangecheck's), a Brickworks key, and any field that holds one.
const redact = (text) => String(text)
  .replace(/eyJ[\w-]+\.[\w-]+\.[\w-]*/g, "[token]")
  .replace(/\bbw[a-z]_[\w-]{16,}/g, "[token]")
  .replace(/"(access_token|refresh_token|token|code|password)"\s*:\s*"[^"]*"/g, '"$1":"[token]"');
function check(name, ok, said = "") {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`${ok ? "pass" : "FAIL"} ${name}${said ? `: ${redact(said)}` : ""}`);
}

/// A session renewed, as a page does: a new access token, which carries the
/// account as it is now.
async function refreshed(refreshToken) {
  const reply = await real(`${SB}/auth/v1/token?grant_type=refresh_token`, { method: "POST",
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
    body: JSON.stringify({ refresh_token: refreshToken }) });
  return (await reply.json()).access_token;
}

async function adminUser(id) {
  const reply = await real(`${SB}/auth/v1/admin/users/${id}`, { headers: ADMIN });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

const claimsOf = (jwt) => {
  try {
    return JSON.parse(Buffer.from(String(jwt).split(".")[1], "base64url").toString());
  } catch {
    return {};
  }
};
const amrOf = (jwt) => (claimsOf(jwt).amr || []).map((one) => one.method);

const closed = (status) => status === 401 || status === 403;

/// The account at [email], from Supabase's own list, or null.
async function accountAt(email) {
  const listed = await (await real(`${SB}/auth/v1/admin/users?page=1&per_page=1000`, { headers: ADMIN })).json();
  return (listed.users || []).find((one) => (one.email || "").toLowerCase() === email.toLowerCase()) || null;
}

async function rpc(name, body) {
  const reply = await real(`${SB}/rest/v1/rpc/${name}`, { method: "POST", headers: { ...ADMIN, "content-type": "application/json" },
    body: JSON.stringify(body) });
  return reply.json().catch(() => null);
}

/// A password set on the account from one of its sessions, as Supabase
/// lets anybody signed in (oc188's review, H1): the status.
async function setPassword(access, password) {
  const reply = await real(`${SB}/auth/v1/user`, { method: "PUT", headers: { ...PUBLIC, authorization: `Bearer ${access}` },
    body: JSON.stringify({ password }) });
  return reply.status;
}

/// An address change asked for from a session, as Supabase lets anybody
/// signed in: the status.
async function changeAddress(access, email) {
  const reply = await real(`${SB}/auth/v1/user`, { method: "PUT", headers: { ...PUBLIC, authorization: `Bearer ${access}` },
    body: JSON.stringify({ email }) });
  return reply.status;
}

/// A session signed in by that password: Supabase's answer.
async function passwordSession(email, password) {
  if (!email) return {};
  const reply = await real(`${SB}/auth/v1/token?grant_type=password`, { method: "POST", headers: PUBLIC,
    body: JSON.stringify({ email, password }) });
  return reply.json().catch(() => ({}));
}

try {
  let handler = await route();

  // A first sign-in: a new account, a working session, the token ended at orangecheck.
  const first = token();
  const one = await call(handler, { token: first.jwt });
  check("a first sign-in is a new account", one.status === 200 && one.body.orangecheck?.new_account === true,
    `${one.status} ${one.body.error || ""}`);
  check("its address is random at oc.brickworks.diy", /^[0-9a-f]{32}@oc\.brickworks\.diy$/.test(one.body.user?.email || "")
    && !one.body.user.email.includes(first.claims.did_oc.slice(7, 39)));
  check("the answer is never cached", one.headers["cache-control"] === "no-store");
  const me = one.status === 200 ? await whoIs(one.body.access_token) : null;
  check("the session it gives is a Brickworks sign-in", me?.body?.signed_in === true && me.body.email === one.body.user?.email,
    `signed_in ${me?.body?.signed_in}`);
  check("the token is ended at orangecheck", ochk.revoked.includes(first.jwt));
  check("the token is not in the answer", !JSON.stringify(one.body).includes(first.jwt));

  // The same token again, on this instance and on a fresh one.
  const again = await call(handler, { token: first.jwt });
  check("the same token is refused a second time", again.status === 409, `${again.status} ${again.body.error || ""}`);
  const elsewhere = await call(await route(), { token: first.jwt });
  check("and on another instance", elsewhere.status === 409, `${elsewhere.status}`);

  // The same person again, with a new token: the same account.
  const second = token({ did_oc: first.claims.did_oc });
  const two = await call(handler, { token: second.jwt });
  check("the same orangecheck id signs in to the same account", two.status === 200 && two.body.user?.id === one.body.user?.id
    && two.body.orangecheck?.new_account === false, `${two.status}`);

  // Tokens refused.
  const refused = async (name, jwt, status) => {
    const answer = await call(handler, { token: jwt });
    check(name, answer.status === status && typeof answer.body.error === "string" && answer.body.error.length > 10,
      `${answer.status} ${answer.body.error || ""}`);
  };
  await refused("a token with no rh is refused", token({ rh: undefined }).jwt, 401);
  await refused("a token for another site is refused", token({ aud: "https://example.com" }).jwt, 401);
  await refused("a token with no audience is refused", token({ aud: undefined }).jwt, 401);
  await refused("a token signed by another key is refused", token({}, { key: stranger.privateKey }).jwt, 401);
  await refused("a token from another issuer is refused", token({ iss: "https://evil.example" }).jwt, 401);
  await refused("an expired token is refused", token({ iat: 1000, exp: 2000 }).jwt, 401);
  await refused("a token with no did is refused", token({ did_oc: undefined }).jwt, 401);
  await refused("a malformed did is refused", token({ did_oc: "did:oc:NOTHEX" }).jwt, 401);
  await refused("nothing at all is refused", "", 422);
  await refused("not a token is refused", "not.a.token", 401);
  const none = `${b64({ alg: "none", typ: "JWT" })}.${b64(token().claims)}.`;
  await refused("an unsigned token is refused", none, 401);

  // A session the person ended everywhere.
  const ended = token();
  ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: { [ended.claims.rh]: ended.claims.iat + 5 } });
  handler = await route();
  process.env.OC_AUDIENCE = "http://127.0.0.1:8842";
  const endedAt = token({ aud: "http://127.0.0.1:8842", rh: ended.claims.rh, iat: ended.claims.iat });
  const endedAnswer = await call(handler, { token: endedAt.jwt });
  check("a session ended everywhere is refused", endedAnswer.status === 401 && /ended/.test(endedAnswer.body.error || ""),
    `${endedAnswer.status} ${endedAnswer.body.error || ""}`);
  const later = token({ aud: "http://127.0.0.1:8842", rh: ended.claims.rh, iat: ended.claims.iat + 60 });
  const laterAnswer = await call(handler, { token: later.jwt });
  check("one started after the cutoff signs in", laterAnswer.status === 200, `${laterAnswer.status} ${laterAnswer.body.error || ""}`);

  // The list cannot be read: nobody signs in with orangecheck, and says why.
  process.env.OC_AUDIENCE = "http://127.0.0.1:8843";
  ochk.listStatus = 403;
  ochk.list = () => ({ ok: false, reason: "domain_unverified" });
  handler = await route();
  const unread = await call(handler, { token: token({ aud: "http://127.0.0.1:8843" }).jwt });
  check("while the list cannot be read, no orangecheck sign-in", unread.status === 503 && /orangecheck/.test(unread.body.error || ""),
    `${unread.status} ${unread.body.error || ""}`);
  ochk.listStatus = 200;
  ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: {} });

  // The project's rule.
  process.env.OC_AUDIENCE = "http://127.0.0.1:8844";
  ochk.rule = { ok: true, require_bond: { min_sats: 100000, min_days: 30 } };
  handler = await route();
  const unbacked = await call(handler, { token: token({ aud: "http://127.0.0.1:8844" }).jwt });
  check("a rule asking for a backed account refuses one that is not", unbacked.status === 403
    && unbacked.body.back_url === "https://ochk.app/me/account#backing", `${unbacked.status} ${unbacked.body.error || ""}`);
  // A floor without max_age_secs, as orangecheck answers one (/me/require-bond).
  const bond = { v: 1, sats_floor: 250000, days_floor: 90, height: 900000, checked_at: Math.floor(Date.now() / 1000) - 60,
    nullifier: randomBytes(32).toString("hex") };
  const backed = await call(handler, { token: token({ aud: "http://127.0.0.1:8844", oc_bond: bond }).jwt });
  check("a floor of {min_sats, min_days} alone, without max_age_secs, is read, and lets an account backed above it in", backed.status === 200,
    `${backed.status} ${backed.body.error || ""}`);
  ochk.ruleStatus = 503;
  ochk.rule = { ok: false };
  handler = await route();
  const noRule = await call(handler, { token: token({ aud: "http://127.0.0.1:8844" }).jwt });
  check("a rule that cannot be read lets nobody in", noRule.status === 503, `${noRule.status}`);
  ochk.ruleStatus = 200;
  ochk.rule = { ok: true, require_bond: null };

  // orangecheck's keys cannot be read: a token is neither good nor bad, so
  // 503, never "not for Brickworks" (checkOcToken's unavailable).
  ochk.jwksStatus = 503;
  handler = await route();
  const noKeys = await call(handler, { token: token({ aud: "http://127.0.0.1:8844" }).jwt });
  check("while orangecheck's keys cannot be read, a sign-in is answered 503 in words, not 401", noKeys.status === 503
    && /orangecheck could not be asked/.test(noKeys.body.error || ""), `${noKeys.status} ${noKeys.body.error || ""}`);
  ochk.jwksStatus = 200;

  // Production takes tokens for brickworks.diy alone, never for the
  // deployment's own address (oc188's review of step 1, L1).
  {
    const { audiences } = await import("../../api/_oc_config.js");
    const was = { env: process.env.VERCEL_ENV, url: process.env.VERCEL_URL };
    process.env.VERCEL_URL = "brickworks-oc-check.vercel.app";
    process.env.VERCEL_ENV = "production";
    const production = audiences();
    const own = await call(await route(), { token: token({ aud: "https://brickworks-oc-check.vercel.app" }).jwt });
    process.env.VERCEL_ENV = "preview";
    const preview = audiences();
    for (const [name, value] of [["VERCEL_ENV", was.env], ["VERCEL_URL", was.url]]) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    check("step 1's L1: production takes tokens for https://brickworks.diy alone, not its own *.vercel.app address",
      JSON.stringify(production) === JSON.stringify(["https://brickworks.diy"]) && own.status === 401,
      `${JSON.stringify(production)} ${own.status}`);
    check("and a Preview deployment, for its own address", JSON.stringify(preview) === JSON.stringify(["https://brickworks-oc-check.vercel.app"]),
      JSON.stringify(preview));
  }

  // Two first sign-ins of one person at once: one account, none left over.
  process.env.OC_AUDIENCE = AUD;
  handler = await route();
  const did = `did:oc:${randomBytes(16).toString("hex")}`;
  const before = new Set(made);
  const [a, b] = await Promise.all([call(handler, { token: token({ did_oc: did }).jwt }), call(handler, { token: token({ did_oc: did }).jwt })]);
  const raced = [...made].filter((id) => !before.has(id));
  const left = [];
  for (const id of raced) if (id !== a.body.user?.id && (await adminUser(id)).status !== 404) left.push(id);
  check("two first sign-ins at once make one account", a.status === 200 && b.status === 200 && a.body.user?.id === b.body.user?.id,
    `${a.status} ${b.status}`);
  check("and leave no account over", left.length === 0, `${raced.length} made, ${left.length} left`);

  // Three tabs signing the same person in at once: each gets in, as them.
  const tabs = await Promise.all([0, 1, 2].map(() => call(handler, { token: token({ did_oc: did }).jwt })));
  check("three sign-ins of one account at once all get in", tabs.every((t) => t.status === 200 && t.body.user?.id === a.body.user?.id),
    tabs.map((t) => t.status).join(" "));

  // Deleting an orangecheck account: a fresh sign-in as the same person,
  // never the made-up address.
  const quit = async (access, body) => {
    let status = 0;
    let answer = null;
    const response = { setHeader() { return this; }, status(code) { status = code; return this; }, json(value) { answer = value; return this; } };
    await account({ method: "POST", query: { op: "delete" }, headers: { authorization: `Bearer ${access}` }, body }, response);
    return { status, body: answer };
  };
  const leaver = token();
  const signedUp = await call(handler, { token: leaver.jwt });
  check("an orangecheck account to delete", signedUp.status === 200, `${signedUp.status} ${signedUp.body.error || ""}`);
  const access = signedUp.body.access_token;
  const typedIt = await quit(access, { confirm: signedUp.body.user?.email });
  check("an orangecheck account is not deleted by its made-up address", typedIt.status !== 200, `${typedIt.status} ${typedIt.body?.error || ""}`);
  const someoneElse = await quit(access, { orangecheck: token().jwt });
  check("nor by somebody else's orangecheck sign-in", someoneElse.status === 403, `${someoneElse.status} ${someoneElse.body?.error || ""}`);
  const proof = token({ did_oc: leaver.claims.did_oc });
  const gone = await quit(access, { orangecheck: proof.jwt });
  check("a fresh sign-in as itself deletes it", gone.status === 200 && gone.body?.deleted === true, `${gone.status} ${gone.body?.error || ""}`);
  const after = await real(`${SB}/rest/v1/rpc/oc_account_of`, { method: "POST", headers: { ...ADMIN, "content-type": "application/json" },
    body: JSON.stringify({ did: leaver.claims.did_oc }) }).then((r) => r.json());
  check("and its orangecheck id with it", after === null, JSON.stringify(after));
  const reused = await quit(access, { orangecheck: proof.jwt });
  check("the sign-in that deleted it is spent", reused.status !== 200, `${reused.status}`);
  const back = await call(handler, { token: token({ did_oc: leaver.claims.did_oc }).jwt });
  check("signing in again afterwards is a new account", back.status === 200 && back.body.orangecheck?.new_account === true
    && back.body.user?.id !== signedUp.body.user?.id, `${back.status}`);

  // Linking orangecheck to an account that has its own email.
  const route2 = async (handlerOf, { method = "GET", op = "", access, body, query = {} } = {}) => {
    let status = 0;
    let answer = null;
    const response = { setHeader() { return this; }, status(code) { status = code; return this; }, json(value) { answer = value; return this; } };
    const headers = { "x-forwarded-for": anywhere(), ...(access ? { authorization: `Bearer ${access}` } : {}) };
    await handlerOf({ method, query: { op, ...query }, headers, body }, response);
    return { status, body: answer || {} };
  };
  const ocRoute = (options) => route2(signInRoute, options);
  const ada = await mintSession(adaEmail, { age: true });
  const bob = await mintSession(bobEmail, { age: true });
  let st = await ocRoute({ op: "status", access: ada.access_token });
  check("an email account: nothing linked, and a code just now counts as fresh", st.status === 200 && st.body.did === null
    && st.body.only === false && st.body.fresh === true, JSON.stringify(st.body));
  const linkDid = `did:oc:${randomBytes(16).toString("hex")}`;
  let linked = await ocRoute({ method: "POST", op: "link", access: ada.access_token, body: { token: token({ did_oc: linkDid }).jwt } });
  check("it links orangecheck, and its address is told", linked.status === 200 && linked.body.did === linkDid && linked.body.told === "dry",
    `${linked.status} ${linked.body.error || JSON.stringify(linked.body)}`);
  const marked = (await adminUser(ada.kept.user_id)).body;
  check("the account is marked as having orangecheck, and keeps what else it had", marked.app_metadata?.orangecheck === true
    && marked.app_metadata?.provider === "email", JSON.stringify(marked.app_metadata));
  const twice = await ocRoute({ method: "POST", op: "link", access: ada.access_token, body: { token: token().jwt } });
  check("a second orangecheck id for it is refused", twice.status === 409, `${twice.status} ${twice.body.error || ""}`);
  const taken = await ocRoute({ method: "POST", op: "link", access: bob.access_token, body: { token: token({ did_oc: linkDid }).jwt } });
  check("an id another account has is refused", taken.status === 409 && /another/.test(taken.body.error || ""), `${taken.status} ${taken.body.error || ""}`);
  const noSignIn = await ocRoute({ method: "POST", op: "link", access: "not.a.token", body: { token: token().jwt } });
  check("linking without a sign-in is refused", noSignIn.status === 401, `${noSignIn.status}`);

  // Signing in with the linked id: Ada's own account, a session bound to it.
  const viaOc = await call(handler, { token: token({ did_oc: linkDid }).jwt });
  check("the linked id signs in to that same account", viaOc.status === 200 && viaOc.body.user?.id === ada.kept.user_id
    && viaOc.body.orangecheck?.new_account === false, `${viaOc.status} ${viaOc.body.error || ""}`);
  const ocAccess = viaOc.body.access_token;
  const ocStatus = await ocRoute({ op: "status", access: ocAccess });
  check("a session orangecheck started is never fresh enough to link or unlink", ocStatus.body.fresh === false, JSON.stringify(ocStatus.body));
  const ocUnlink = await ocRoute({ method: "POST", op: "unlink", access: ocAccess });
  check("so it cannot unlink", ocUnlink.status === 403, `${ocUnlink.status} ${ocUnlink.body.error || ""}`);

  // Sign out everywhere on orangecheck: the session it started is ended, the emailed code's is not.
  const theme = (access) => route2(account, { method: "POST", op: "theme", access, body: { theme: "dark" } });
  const ocClaims = JSON.parse(Buffer.from(ocAccess.split(".")[1], "base64url").toString());
  check("the session orangecheck started works", (await whoIs(ocAccess)).body?.signed_in === true && (await theme(ocAccess)).status === 200);
  const bound = await real(`${SB}/rest/v1/rpc/oc_session_of`, { method: "POST", headers: { ...ADMIN, "content-type": "application/json" },
    body: JSON.stringify({ session: ocClaims.session_id }) }).then((r) => r.json());
  check("its rh, aud and iat were kept with it", bound.bound === true && bound.aud === AUD && typeof bound.rh === "string", JSON.stringify(bound));
  // The list unreadable: it reads, it does not write; the email session of the same account does both.
  ochk.listStatus = 503;
  forgetForTests();
  const adaFresh = await refreshed(ada.kept.refresh_token);
  const ocRead = await whoIs(ocAccess);
  const ocWrite = await theme(ocAccess);
  check("while orangecheck's list cannot be read, its session reads", ocRead.body?.signed_in === true, JSON.stringify(ocRead.body).slice(0, 120));
  check("and does not write, in words", ocWrite.status === 503 && /orangecheck/.test(ocWrite.body.error || ""), `${ocWrite.status} ${ocWrite.body.error || ""}`);
  check("an emailed code's session of the same account writes all the same", (await theme(adaFresh)).status === 200);
  ochk.listStatus = 200;
  ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: { [bound.rh]: Math.floor(Date.now() / 1000) } });
  forgetForTests();
  const endedRead = await whoIs(ocAccess);
  check("ended everywhere on orangecheck, its session is refused", endedRead.body?.signed_in === false && /orangecheck/.test(endedRead.body.reason || ""),
    JSON.stringify(endedRead.body).slice(0, 160));
  const renewed = await fetch(`${SB}/auth/v1/token?grant_type=refresh_token`, { method: "POST",
    headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
    body: JSON.stringify({ refresh_token: viaOc.body.refresh_token }) });
  check("and cannot be renewed", !renewed.ok, String(renewed.status));
  check("while the emailed code's session goes on", (await whoIs(adaFresh)).body?.signed_in === true && (await theme(adaFresh)).status === 200);
  ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: {} });
  forgetForTests();

  // Unlinking, with a fresh code: the sessions the id started end.
  const again2 = await call(handler, { token: token({ did_oc: linkDid }).jwt });
  const unlinked = await ocRoute({ method: "POST", op: "unlink", access: adaFresh });
  check("unlinked with a fresh code, its address told", unlinked.status === 200 && unlinked.body.did === linkDid && unlinked.body.ended >= 1
    && unlinked.body.told === "dry", `${unlinked.status} ${unlinked.body.error || JSON.stringify(unlinked.body)}`);
  forgetForTests();
  check("and the sign-in that id started there is ended", (await whoIs(again2.body.access_token)).body?.signed_in === false);
  check("the emailed code's sign-in is not", (await whoIs(adaFresh)).body?.signed_in === true);
  const afterUnlink = await call(handler, { token: token({ did_oc: linkDid }).jwt });
  check("the id then signs in to an account of its own, never Ada's", afterUnlink.status === 200
    && afterUnlink.body.user?.id !== ada.kept.user_id && afterUnlink.body.orangecheck?.new_account === true, `${afterUnlink.status}`);
  const onlyStatus = await ocRoute({ op: "status", access: afterUnlink.body.access_token });
  check("an orangecheck account says so, and cannot link or unlink", onlyStatus.body.only === true
    && (await ocRoute({ method: "POST", op: "link", access: afterUnlink.body.access_token, body: { token: token().jwt } })).status === 409
    && (await ocRoute({ method: "POST", op: "unlink", access: afterUnlink.body.access_token })).status === 409, JSON.stringify(onlyStatus.body));

  // A Claude connection approved while signed in with orangecheck ends with that sign-in.
  {
    const oauth = (await import("../../api/oauth.js")).default;
    const { grantOf } = await import("../../api/_oauth.js");
    const CLAUDE = "https://claude.ai/oauth/mcp-oauth-client-metadata";
    const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
    const resource = "https://brickworks.diy/api/mcp";
    const verifier = randomBytes(32).toString("base64url");
    const challenge = createHash("sha256").update(verifier).digest("base64url");
    const access = afterUnlink.body.access_token;
    const approved = await route2(oauth, { method: "POST", op: "approve", access, body: { response_type: "code", client_id: CLAUDE,
      redirect_uri: CALLBACK, code_challenge: challenge, code_challenge_method: "S256", state: "s", resource, scope: "build" } });
    const code = approved.body.redirect ? new URL(approved.body.redirect).searchParams.get("code") : null;
    const issued = await route2(oauth, { method: "POST", op: "token", body: { grant_type: "authorization_code", code,
      redirect_uri: CALLBACK, client_id: CLAUDE, code_verifier: verifier, resource } });
    const connected = issued.body.access_token ? await grantOf(issued.body.access_token, resource) : null;
    check("an orangecheck sign-in connects Claude", Boolean(connected) && !connected.unsure, `${approved.status} ${issued.status}`);
    const ocSession = await real(`${SB}/rest/v1/rpc/oc_session_of`, { method: "POST", headers: { ...ADMIN, "content-type": "application/json" },
      body: JSON.stringify({ session: JSON.parse(Buffer.from(access.split(".")[1], "base64url").toString()).session_id }) }).then((r) => r.json());
    ochk.listStatus = 503;
    forgetForTests();
    const unsure = await grantOf(issued.body.access_token, resource);
    check("while orangecheck's list cannot be read, the connection waits rather than ends", unsure?.unsure === true);
    ochk.listStatus = 200;
    ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: { [ocSession.rh]: Math.floor(Date.now() / 1000) } });
    forgetForTests();
    check("ended everywhere on orangecheck, the connection it approved is ended too", (await grantOf(issued.body.access_token, resource)) === null);
    const renew = await route2(oauth, { method: "POST", op: "token", body: { grant_type: "refresh_token",
      refresh_token: issued.body.refresh_token, client_id: CLAUDE } });
    check("and its refresh token is no good", renew.status === 400, `${renew.status} ${JSON.stringify(renew.body).slice(0, 100)}`);
    ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: {} });
    forgetForTests();
  }

  // oc188's review, H1: any session could set a password on its account at
  // Supabase and sign in with it, a session nothing here started, and
  // setting one signed the account's other sessions out. Now Supabase
  // refuses it (supabase/no_new_ways_in.sql), and a change of address too.
  // Signed in with orangecheck twice, a password tried from one session,
  // then an address: both refused, nothing to sign in with, and the other
  // session not signed out. Then Sign out everywhere ends them both.
  {
    handler = await route();
    const theirs = token();
    const signedIn = await call(handler, { token: theirs.jwt });
    const other = await call(handler, { token: token({ did_oc: theirs.claims.did_oc, rh: theirs.claims.rh }).jwt });
    const password = `${randomBytes(18).toString("base64url")}-Aa1`;
    const set = signedIn.status === 200 ? await setPassword(signedIn.body.access_token, password) : 0;
    const second = await passwordSession(signedIn.body.user?.email, password);
    check("H1: a password set from an orangecheck sign-in is refused at Supabase, and none signs in", signedIn.status === 200
      && set >= 400 && !second.access_token, `${signedIn.status} ${set} ${amrOf(second.access_token)}`);
    check("H1: and trying signs out none of the account's other sessions", other.status === 200
      && (await whoIs(other.body.access_token)).body?.signed_in === true && Boolean(await refreshed(other.body.refresh_token)));
    // Supabase writes an address change asked from a session only once it
    // can send the confirmation (and answers 429 while its mail limit is
    // spent), so the same write is asked through the admin API too, which
    // sends nothing: the trigger refuses either.
    const moved = await changeAddress(signedIn.body.access_token, `delivered+bw-oc-moved-${tag}@resend.dev`);
    const movedByAdmin = await real(`${SB}/auth/v1/admin/users/${signedIn.body.user?.id}`, { method: "PUT",
      headers: { ...ADMIN, "content-type": "application/json" }, body: JSON.stringify({ email: `bw-oc-moved-${tag}@example.invalid` }) });
    const kept = (await adminUser(signedIn.body.user?.id)).body;
    check("H1: nor can the account's address be changed, from a session or at all", moved >= 400 && movedByAdmin.status >= 400
      && kept.email === signedIn.body.user?.email && !kept.new_email, `${moved} ${movedByAdmin.status} ${kept.email} ${kept.new_email || ""}`);
    ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: { [theirs.claims.rh]: Math.floor(Date.now() / 1000) } });
    forgetForTests();
    check("H1: signed out everywhere on orangecheck, both its sessions get 401", (await theme(signedIn.body.access_token)).status === 401
      && (await theme(other.body.access_token)).status === 401);
    ochk.list = () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: {} });
    forgetForTests();
  }

  // Signing in by an emailed code, as api/otp.js mints one, is as it was: a
  // new address that is not a test's, a code asked for twice (Send again)
  // before the second is used, and a test account by its password
  // (tools/web/session.mjs).
  {
    const newcomer = `bw-oc-new-${tag}@example.invalid`;
    await mintCode(newcomer);
    const byCode = await mintSession(newcomer, { age: false });
    check("a new person signs in by an emailed code, asked for twice, as before", Boolean(byCode.access_token)
      && amrOf(byCode.access_token)[0] === "otp" && (await whoIs(byCode.access_token)).body?.signed_in === true);
    if (byCode.kept.user_id) made.add(byCode.kept.user_id);
    const again = await mintSession(newcomer, { age: false });
    check("and signs in by a code again", (await whoIs(again.access_token)).body?.signed_in === true);
    check("a test account signs in by its password, as the tests do", amrOf(ada.access_token)[0] === "password"
      && (await whoIs(ada.access_token)).body?.signed_in === true);
  }

  // Eve: an account with its own email, at an address that takes no mail
  // (.invalid), so nothing here or at Supabase reaches anybody, and not a
  // test address, so no password of hers is a test's.
  {
    handler = await route();
    const eveEmail = `bw-oc-eve-${tag}@example.invalid`;
    const madeEve = await fetch(`${SB}/auth/v1/admin/users`, { method: "POST", headers: { ...ADMIN, "content-type": "application/json" },
      body: JSON.stringify({ email: eveEmail, email_confirm: true }) });
    const eve = (await madeEve.json()).id;
    const eveDid = `did:oc:${randomBytes(16).toString("hex")}`;
    // Linked as oc_link links, the mark left off: an account whose marking
    // failed, or a session handed out before it was marked.
    const linkedEve = await rpc("oc_link", { did: eveDid, account: eve });
    const viaOc = await call(handler, { token: token({ did_oc: eveDid }).jwt });
    check("L1: the id of an account not marked as having orangecheck signs in, and the session's own token carries the mark",
      linkedEve === "linked" && viaOc.status === 200 && claimsOf(viaOc.body.access_token).app_metadata?.orangecheck === true
      && (await adminUser(eve)).body.app_metadata?.orangecheck === true, `${linkedEve} ${viaOc.status} ${viaOc.body.error || ""}`);

    // H1, the unlink variant: her emailed code first, then a password tried
    // from the orangecheck sign-in. Refused, so there is no password session
    // to unlink with, and her own session is not signed out by the try.
    const eveCode = await mintSession(eveEmail, { age: true });
    const password = `${randomBytes(18).toString("base64url")}-Aa1`;
    const set = await setPassword(viaOc.body.access_token, password);
    const second = await passwordSession(eveEmail, password);
    check("H1, the unlink variant: a password set from an orangecheck sign-in of an account with its own email is refused",
      set >= 400 && !second.access_token && (await rpc("oc_did_of", { account: eve })) === eveDid, `${set} ${amrOf(second.access_token)}`);
    const codeStatus = await ocRoute({ op: "status", access: eveCode.access_token });
    check("her emailed code's session is still signed in, and counts as fresh", codeStatus.body.fresh === true
      && amrOf(eveCode.access_token)[0] === "otp", JSON.stringify(codeStatus.body));

    // L4: deleting from the orangecheck sign-in.
    const fromOc = await quit(viaOc.body.access_token, { confirm: eveEmail });
    check("L4: deleting the account from its orangecheck sign-in asks for the same fresh emailed code as unlinking",
      fromOc.status === 403 && fromOc.body?.fresh === false && (await adminUser(eve)).status === 200,
      `${fromOc.status} ${fromOc.body?.error || ""}`);

    // L2: a Claude connection's code, approved in the orangecheck sign-in.
    const oauth = (await import("../../api/oauth.js")).default;
    const CLAUDE = "https://claude.ai/oauth/mcp-oauth-client-metadata";
    const CALLBACK = "https://claude.ai/api/mcp/auth_callback";
    const resource = "https://brickworks.diy/api/mcp";
    const verifier = randomBytes(32).toString("base64url");
    const challenge = createHash("sha256").update(verifier).digest("base64url");
    const approvedCode = async (access) => {
      const approved = await route2(oauth, { method: "POST", op: "approve", access, body: { response_type: "code", client_id: CLAUDE,
        redirect_uri: CALLBACK, code_challenge: challenge, code_challenge_method: "S256", state: "s", resource, scope: "build" } });
      return approved.body.redirect ? new URL(approved.body.redirect).searchParams.get("code") : null;
    };
    const exchange = (code) => route2(oauth, { method: "POST", op: "token", body: { grant_type: "authorization_code", code,
      redirect_uri: CALLBACK, client_id: CLAUDE, code_verifier: verifier, resource } });
    const kept = await approvedCode(viaOc.body.access_token);
    const stale = await approvedCode(viaOc.body.access_token);
    // As one read just before an unlink: its id is no longer Eve's.
    await real(`${SB}/rest/v1/oauth_codes?hash=eq.${createHash("sha256").update(String(stale)).digest("hex")}`, { method: "PATCH",
      headers: { ...ADMIN, "content-type": "application/json" }, body: JSON.stringify({ oc_did: `did:oc:${randomBytes(16).toString("hex")}` }) });
    const late = await exchange(stale);
    check("L2: a code approved in an orangecheck sign-in whose id is no longer the account's is refused", Boolean(stale)
      && late.status === 400 && /unlinked/.test(late.body.error_description || ""), `${late.status} ${JSON.stringify(late.body).slice(0, 120)}`);
    const unlinked = await rpc("oc_unlink", { account: eve });
    const exchangedAfter = await exchange(kept);
    check("L2: unlinking deletes the codes that sign-in was given, so none is exchanged after", Boolean(kept) && unlinked?.codes >= 1
      && exchangedAfter.status === 400, `${JSON.stringify(unlinked)} ${exchangedAfter.status}`);

    // M1: unlinked between the sign-in finding the account and binding the
    // session it minted.
    await rpc("oc_link", { did: eveDid, account: eve });
    hooks.beforeBind = () => rpc("oc_unlink", { account: eve });
    hooks.minted = null;
    const raced = await call(handler, { token: token({ did_oc: eveDid }).jwt });
    const minted = hooks.minted;
    check("M1: unlinked between finding the account and binding the session, refused in words, and no session handed out",
      raced.status === 409 && !raced.body.access_token && /unlinked/.test(raced.body.error || ""), `${raced.status} ${raced.body.error || ""}`);
    check("M1: and the session minted for it is ended", Boolean(minted?.refresh_token) && !(await refreshed(minted.refresh_token)));
    check("M1: oc_bind_session binds nothing for an id that is not the account's", (await rpc("oc_bind_session", { session: randomUUID(),
      account: eve, did: eveDid, rh: "rh", aud: AUD, iat: 1 })) === false);

    // M1, the other half: a binding whose id is no longer the account's
    // (made before oc_bind_session checked, which nothing now can) is
    // refused and ended.
    await rpc("oc_link", { did: eveDid, account: eve });
    const boundAgain = await call(handler, { token: token({ did_oc: eveDid }).jwt });
    hooks.sessionOf = (said) => (said.bound ? { ...said, linked: false } : said);
    forgetForTests();
    const orphan = await theme(boundAgain.body.access_token);
    hooks.sessionOf = null;
    check("M1: a session bound by an id that is no longer the account's is refused, in words, and ended", boundAgain.status === 200
      && orphan.status === 401 && /unlinked/.test(orphan.body.error || "") && !(await refreshed(boundAgain.body.refresh_token)),
      `${boundAgain.status} ${orphan.status} ${orphan.body.error || ""}`);

    // Nothing about an emailed code changes: Eve's deletes the account by
    // its address, as every email account does.
    const byCode = await quit(eveCode.access_token, { confirm: eveEmail });
    check("an emailed code's session deletes the account with its address typed, as before", byCode.status === 200
      && byCode.body?.deleted === true, `${byCode.status} ${byCode.body?.error || ""}`);
  }

  // orangecheck's second re-check, N1: the keys a page holds, the
  // publishable key and a session's token, reach nothing in the database:
  // the catalogue says so (supabase/client_exposure.sql), and PostgREST
  // refuses every table and every function, to a throwaway emailed-code
  // session and to anon alike.
  {
    const exposure = await rpc("client_exposure", {});
    const bad = Array.isArray(exposure?.bad) ? exposure.bad : ["client_exposure() could not be read"];
    check("N1: nothing in public for anon, authenticated or PUBLIC, and no default that would grant it", bad.length === 0,
      `${bad.length}: ${bad.slice(0, 8).join("; ")}${bad.length > 8 ? "; ..." : ""}`);
    const visitor = await mintSession(`bw-oc-n1-${tag}@example.invalid`, { age: false });
    if (visitor.kept.user_id) made.add(visitor.kept.user_id);
    const tables = exposure?.tables || [];
    const functions = (exposure?.functions || []).filter((one) => !one.trigger && one.named);
    const inTurn = async (items, ask) => {
      const open = [];
      for (let at = 0; at < items.length; at += 12) open.push(...(await Promise.all(items.slice(at, at + 12).map(ask))).filter(Boolean));
      return open;
    };
    for (const [who, as] of [["an emailed code's session", { authorization: `Bearer ${visitor.access_token}` }], ["anon", {}]]) {
      // Each column on its own: a column may be granted where its table is
      // not, and a select of them all is refused for the one that is not.
      const asks = tables.flatMap((table) => ["*", ...table.columns].map((column) => [table.name, column]));
      const openTables = await inTurn(asks, async ([table, column]) => {
        const reply = await real(`${SB}/rest/v1/${encodeURIComponent(table)}?select=${encodeURIComponent(column)}&limit=1`,
          { headers: { ...PUBLIC, ...as } });
        return closed(reply.status) ? null : `${table}.${column} ${reply.status}`;
      });
      check(`N1: as ${who}, every table and view in public, and each of its columns, is refused (${tables.length}, ${asks.length} asked)`,
        tables.length > 0 && openTables.length === 0, `${openTables.length} answered: ${openTables.slice(0, 8).join(", ")}`);
      const openFunctions = await inTurn(functions, async (fn) => {
        const reply = await real(`${SB}/rest/v1/rpc/${fn.name}`, { method: "POST", headers: { ...PUBLIC, ...as },
          body: JSON.stringify(Object.fromEntries(fn.args.map((name) => [name, null]))) });
        const said = await reply.json().catch(() => ({}));
        return closed(reply.status) || said?.code === "42501" ? null : `${fn.name} ${reply.status}`;
      });
      check(`N1: as ${who}, every function in public is refused (${functions.length}, triggers aside)`, functions.length > 0
        && openFunctions.length === 0, `${openFunctions.length} ran or were not refused: ${openFunctions.slice(0, 8).join(", ")}`);
    }

    // And no second factor can be enrolled from a session.
    const enrol = await real(`${SB}/auth/v1/factors`, { method: "POST", headers: { ...PUBLIC, authorization: `Bearer ${visitor.access_token}` },
      body: JSON.stringify({ factor_type: "totp", friendly_name: "orangecheck check" }) });
    check("enrolling a second factor (an authenticator app) from a session is refused at Supabase", enrol.status >= 400, String(enrol.status));
  }

  // N2: public sign-up is open, and Supabase confirms an address itself,
  // so a sign-up with a password handed out a session at once. Supabase
  // now refuses it (supabase/no_new_ways_in.sql). Should one ever be
  // handed out, api/_auth.js refuses it (403) and ends it.
  {
    const email = `bw-oc-signup-${tag}@example.invalid`;
    const reply = await real(`${SB}/auth/v1/signup`, { method: "POST", headers: PUBLIC,
      body: JSON.stringify({ email, password: `${randomBytes(18).toString("base64url")}-Aa1` }) });
    const signedUp = await reply.json().catch(() => ({}));
    const left = await accountAt(email);
    if (left) made.add(left.id);
    check("N2: a public sign-up with a password is refused at Supabase, with no session handed out", reply.status >= 400
      && !signedUp.access_token, `${reply.status} ${amrOf(signedUp.access_token)}`);
    check("N2: and it leaves no account behind", !left);
    if (signedUp.access_token) {
      const write = await theme(signedUp.access_token);
      check("N2: the session it handed out is refused at /api, 403, and ended", write.status === 403
        && !(await refreshed(signedUp.refresh_token)), `${write.status} ${write.body.error || ""}`);
    }
  }

  // A new person signs in by a code from api/otp.js itself (its mail
  // caught above, never sent), as Supabase is now and once it takes no
  // sign-ups (its disable_signup): then the server makes the account first.
  {
    const otp = (await import("../../api/otp.js")).default;
    for (const [how, off] of [["as Supabase is now", false], ["once Supabase takes no sign-ups", true]]) {
      const email = `bw-oc-otp-${off ? "off" : "on"}-${tag}@example.invalid`;
      if (off) hooks.signupOff.add(email);
      const asked = await route2(otp, { method: "POST", body: { email } });
      const letter = hooks.mail.filter((one) => one.to?.[0] === email).pop();
      const code = /code is (\d+)/.exec(letter?.text || "")?.[1];
      const verified = code ? await (await real(`${SB}/auth/v1/verify`, { method: "POST", headers: PUBLIC,
        body: JSON.stringify({ type: "email", email, token: code }) })).json().catch(() => ({})) : {};
      if (verified.user?.id) made.add(verified.user.id);
      check(`a new person signs in by a code from api/otp.js, ${how}`, asked.status === 200 && amrOf(verified.access_token)[0] === "otp"
        && (await whoIs(verified.access_token)).body?.signed_in === true && !hooks.signupOff.has(email),
        `${asked.status} ${asked.body?.error || ""} ${code ? "" : "no code mailed"}`);
    }
  }

  // Without the project's key or secret, nobody signs in with orangecheck.
  const offered = (await whoIs(undefined)).body?.orangecheck;
  check("/api/account says orangecheck takes a token here, offered to everybody", offered?.ready === true
    && offered?.everyone === true, JSON.stringify(offered));
  const key = process.env.OC_SIGNING_SECRET;
  delete process.env.OC_SIGNING_SECRET;
  const unset = await call(await route(), { token: token().jwt });
  check("without the project's secret, nobody signs in with orangecheck, and it says it is unavailable", unset.status === 503
    && unset.body.error === "Signing in with orangecheck is unavailable here. Sign in with your email instead.", `${unset.status} ${unset.body.error}`);
  const unsetOffer = (await whoIs(undefined)).body?.orangecheck;
  check("and /api/account says so, for the button to say it", unsetOffer?.ready === false, JSON.stringify(unsetOffer));
  process.env.OC_SIGNING_SECRET = key;
  delete process.env.OC_AUDIENCE;
  const noAudience = await call(await route(), { token: token().jwt });
  check("without an audience, nobody signs in with orangecheck", noAudience.status === 503, `${noAudience.status}`);
  process.env.OC_AUDIENCE = AUD;

  // Twenty tries from one address in a quarter of an hour, then no more.
  const from = anywhere();
  const tries = [];
  for (let n = 0; n < 21; n += 1) tries.push((await call(handler, { token: "not.a.token" }, { ip: from })).status);
  check("twenty tries from one address, the next refused", tries.slice(0, 20).every((s) => s === 401) && tries[20] === 429,
    tries.join(" "));

  // Only POST ?op=signin.
  const wrong = await call(handler, { token: token().jwt }, { method: "GET" });
  check("anything but POST ?op=signin is refused", wrong.status === 405, `${wrong.status}`);
} catch (trouble) {
  check("the run finished", false, String(trouble?.stack || trouble).slice(0, 400));
} finally {
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => false);
  let gone = 0;
  for (const id of made) {
    const reply = await real(`${SB}/auth/v1/admin/users/${id}`, { method: "DELETE", headers: ADMIN });
    if (reply.ok || reply.status === 404) gone += 1;
  }
  console.log(`orangecheck_check: ${made.size} accounts made, ${gone} deleted`);
  console.log(`orangecheck_check: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}
