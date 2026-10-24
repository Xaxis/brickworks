// Signing in with orangecheck, checked on this machine against the real
// database: api/orangecheck.js run in this process, with only orangecheck
// itself stood in for. The tokens are signed here with a key of our own,
// served as ochk.io's key set; the project's rule and the list of ended
// sessions are answered here too. Everything on Brickworks' side is real:
// supabase/orangecheck.sql's functions, Supabase's admin API, the session
// minted and then used against api/account.js. Step 4 (oc225): an
// orangecheck account merge follows to the same Brickworks account
// (merged_rh), and orangecheck Connect makes an orangecheck account only at
// a tick, and deletes it with the Brickworks account. oc237: the desktop's
// sign-in (?op=native), a code from orangecheck's authorize page traded
// for the token, and an account deleted while Connect is still making it
// one (orangecheck's review, L2).
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
// Never the real Connect key: every call to Connect is answered here.
process.env.OC_CONNECT_KEY = "ock_test_orangecheck_check";
delete process.env.VERCEL_ENV;
// orangecheck's own hosts, stood in for below, never a test stack's.
delete process.env.OC_ISSUER;
delete process.env.OC_ME_ORIGIN;
delete process.env.OC_NATIVE;
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
  // Connect (ochk.io/api/connect/*): each call kept, as it was asked, and
  // answered as set.
  connect: [],
  provision: (body) => [200, { ok: true, did_oc: `did:oc:${createHash("sha256").update(body.user_id).digest("hex").slice(0, 32)}`, is_new: true }],
  remove: () => [200, { ok: true, result: "deleted" }],
  // The desktop's sign-in: each code the authorize page gave the app's
  // listener, with the challenge, redirect and claims it was given for
  // (nativeCode, below); every trade asked, as it was asked; every token
  // a trade gave; and the trade's answer when orangecheck is down.
  codes: new Map(),
  traded: [],
  minted: [],
  tradeStatus: 200,
};

const made = new Set();
// supabase/orangecheck_connect_leaving.sql as it is now (a mark written
// with or without a row, lapsing after 15 minutes), answered here over the
// real oc_connected rows while the project has only its first version (the
// run says so): a deletion's mark is kept here with its time, for an
// account whether or not it has a row, as the file writes a row of the
// mark alone (which oc_connected_of reads as none); kept is false while
// the row is gone or a mark is under 15 minutes old.
const leavingSql = { missing: false, marks: new Map() };
const LAPSE_MS = 15 * 60 * 1000;
// Brickworks' own answers, reached into for the review's races (oc205): run
// once just before a session is bound; the last session Supabase minted;
// what the database says of a session, changed.
const hooks = { beforeBind: null, minted: null, sessionOf: null, mail: [], signupOff: new Set(), holdDelete: null };
// Two email accounts, at Resend's test addresses, which reach nobody.
const tag = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-oc-ada-${tag}@resend.dev`;
const bobEmail = `delivered+bw-oc-bob-${tag}@resend.dev`;
const carolEmail = `delivered+bw-oc-carol-${tag}@resend.dev`;
const danEmail = `delivered+bw-oc-dan-${tag}@resend.dev`;
const pwEmail = `delivered+bw-oc-pw-${tag}@resend.dev`;
const real = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = String(input?.url || input);
  const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
  if (url === "https://ochk.io/.well-known/jwks.json") return ochk.jwksStatus === 200 ? json(200, { keys: [jwk] }) : json(ochk.jwksStatus, {});
  if (url.startsWith("https://me.ochk.io/api/integrator/revocations")) return json(ochk.listStatus, ochk.list());
  if (/^https:\/\/me\.ochk\.io\/api\/integrator\/[^/]+\/sign-in$/.test(url)) return json(ochk.ruleStatus, ochk.rule);
  if (url === "https://ochk.io/api/connect/provision" || url === "https://ochk.io/api/connect/delete") {
    const body = JSON.parse(init.body);
    ochk.connect.push({ path: new URL(url).pathname, body, key: String(init.headers?.authorization || "") === `Bearer ${process.env.OC_CONNECT_KEY}`,
      redirect: init.redirect });
    const [status, answer] = await (url.endsWith("/provision") ? ochk.provision(body) : ochk.remove(body));
    return json(status, answer);
  }
  // orangecheck's token endpoint for an app's code (me-client's
  // exchangeNativeCode): a code works once, whatever the answer, and only
  // with the verifier its challenge was made from, for this project and
  // the exact redirect it was given for.
  if (url === "https://ochk.io/api/auth/native/token") {
    const asked = JSON.parse(init.body);
    ochk.traded.push({ ...asked, redirect: init.redirect });
    if (ochk.tradeStatus !== 200) return json(ochk.tradeStatus, {});
    const grant = ochk.codes.get(asked.code);
    ochk.codes.delete(asked.code);
    const challenge = createHash("sha256").update(String(asked.code_verifier)).digest("base64url");
    if (!grant || asked.grant_type !== "authorization_code" || asked.project !== process.env.OC_PROJECT_KEY
      || asked.redirect_uri !== grant.redirect || challenge !== grant.challenge) {
      return json(400, { ok: false, reason: "invalid_grant" });
    }
    const minted = token({ azp: "native", ...grant.claims });
    ochk.minted.push(minted);
    return json(200, { ok: true, token: minted.jwt });
  }
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
  // Supabase taking no sign-ups, for the addresses named: generate_link
  // makes no account, so it answers only for an account that is there.
  if (url === `${SB}/auth/v1/admin/generate_link` && hooks.signupOff.has(JSON.parse(init.body || "{}").email)) {
    const asked = JSON.parse(init.body).email;
    if (!(await accountAt(asked))) return json(422, { code: 422, error_code: "signup_disabled", msg: "Signups not allowed for this instance" });
    hooks.signupOff.delete(asked);
  }
  if (leavingSql.missing && /^rpc\/oc_connect_(leaving|kept)$/.test(url.slice(`${SB}/rest/v1/`.length))) {
    const asked = JSON.parse(init.body);
    const row = await rpc("oc_connected_of", { account: asked.account });
    if (url.endsWith("_leaving")) {
      leavingSql.marks.set(asked.account, Date.now());
      return json(200, row);
    }
    const mark = leavingSql.marks.get(asked.account);
    if (!row || (mark !== undefined && Date.now() - mark < LAPSE_MS)) return json(200, false);
    await rpc("oc_connect_made", { account: asked.account, did: asked.did });
    return json(200, true);
  }
  // An account's own deletion held at its last step until the test says.
  if (hooks.holdDelete && (init.method || "GET") === "DELETE" && url === `${SB}/auth/v1/admin/users/${hooks.holdDelete.account}`) {
    const held = hooks.holdDelete;
    hooks.holdDelete = null;
    held.reached?.();
    await held.until;
    if (held.fails) return json(500, { msg: "orangecheck_check: this deletion fails" });
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

/// What orangecheck's authorize page sends the app's listener once the
/// person signs in: a code for a token of [claims], given for the challenge
/// of the verifier made here and for [redirect].
function nativeCode(claims = {}, redirect = "http://127.0.0.1:53111/oc/callback") {
  const verifier = randomBytes(32).toString("base64url");
  const code = randomBytes(32).toString("base64url");
  ochk.codes.set(code, { challenge: createHash("sha256").update(verifier).digest("base64url"), redirect, claims });
  return { code, code_verifier: verifier, redirect_uri: redirect };
}

/// A token's id as the list of ended sessions names it (auth-core's
/// revocationKey): its first 16 bytes of SHA-256, base64url.
const endedJti = (jti) => createHash("sha256").update(`ocrev1:jti:${jti}`).digest().subarray(0, 16).toString("base64url");

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

// Supabase redeems 30 sign-in links from one address at once, then one
// every 10 s, and every agent on this machine shares the address (step 4
// took the run past 30). A sign-in turned away for that is tried again
// after the wait, with a token of its own like the first's, as the person
// would: the first was spent.
const BUSY = /A lot of people are signing in/;

/// A code redeemed at Supabase as a page redeems one, tried again after
/// the wait while the same limit answers 429: {status, body}.
async function redeemCode(email, token) {
  for (let attempt = 0; ; attempt += 1) {
    const reply = await real(`${SB}/auth/v1/verify`, { method: "POST", headers: PUBLIC,
      body: JSON.stringify({ type: "email", email, token }) });
    const body = await reply.json().catch(() => ({}));
    if (reply.status !== 429 || attempt >= 8) return { status: reply.status, body };
    await new Promise((done) => setTimeout(done, 11000));
  }
}
async function call(handler, body, { method = "POST", op = "signin", ip = anywhere() } = {}) {
  for (let attempt = 0; ; attempt += 1) {
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
    if (!(status === 503 && BUSY.test(answer?.error || "") && attempt < 8 && body?.token)) {
      return { status, body: answer, headers: response.headers, retried: attempt };
    }
    await new Promise((done) => setTimeout(done, 11000));
    body = { ...body, token: token({ ...claimsOf(body.token), jti: randomBytes(12).toString("hex") }).jwt };
  }
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
  // The first version marks only a row that is there, so it answers a
  // made-up account null; the file as it is now writes the mark, which no
  // made-up account can have (its key is auth.users'), and refuses it.
  leavingSql.missing = (await real(`${SB}/rest/v1/rpc/oc_connect_leaving`, { method: "POST", headers: { ...ADMIN, "content-type": "application/json" },
    body: JSON.stringify({ account: randomUUID() }) })).status === 200;
  if (leavingSql.missing) {
    console.log("orangecheck_check: supabase/orangecheck_connect_leaving.sql as it is now is not applied: its two functions are answered here");
  }

  // A first sign-in: a new account, a working session, the token ended at orangecheck.
  const first = token();
  const one = await call(handler, { token: first.jwt });
  check("a first sign-in is a new account", one.status === 200 && (one.body.orangecheck?.new_account === true || one.retried > 0),
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
  // A sign-in turned away by Supabase's limit after its account was made
  // finds that account on the try again (call): new all the same.
  check("signing in again afterwards is a new account", back.status === 200
    && (back.body.orangecheck?.new_account === true || back.retried > 0)
    && back.body.user?.id !== signedUp.body.user?.id, `${back.status} ${JSON.stringify(back.body.orangecheck)} ${back.retried}`);

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
    && afterUnlink.body.user?.id !== ada.kept.user_id && (afterUnlink.body.orangecheck?.new_account === true || afterUnlink.retried > 0),
    `${afterUnlink.status} ${JSON.stringify(afterUnlink.body.orangecheck)} ${afterUnlink.retried}`);
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

  // N2: public sign-up was open, and Supabase confirmed an address
  // itself, so a sign-up with a password handed out a session at once.
  // Whatever Supabase does with one (supabase/no_new_ways_in.sql refuses
  // it; once orangecheck turns sign-up off, Supabase itself does, which
  // tools/web/signup_check.mjs holds), /api takes no such session: none is
  // handed out, or api/_auth.js refuses it, 403, and ends it (run while
  // nothing at Supabase refused it, 2026-10-24: 403, and ended).
  {
    const email = `bw-oc-signup-${tag}@example.invalid`;
    const reply = await real(`${SB}/auth/v1/signup`, { method: "POST", headers: PUBLIC,
      body: JSON.stringify({ email, password: `${randomBytes(18).toString("base64url")}-Aa1` }) });
    const signedUp = await reply.json().catch(() => ({}));
    const left = await accountAt(email);
    if (left) made.add(left.id);
    const write = signedUp.access_token ? await theme(signedUp.access_token) : null;
    check("N2: a public sign-up with a password gives /api no session: none handed out, or refused there (403) and ended",
      !signedUp.access_token || (write.status === 403 && !(await refreshed(signedUp.refresh_token))),
      `${reply.status} ${write ? `${write.status} ${write.body.error || ""}` : "no session"}`);
  }

  // A new person signs in by a code from api/otp.js itself (its mail
  // caught above, never sent): the account made by the admin API, then
  // generate_link asked for an account that is there. So as Supabase is
  // now, and as it will be once it takes no sign-ups (its disable_signup),
  // when generate_link makes no account (stood in for above).
  {
    const otp = (await import("../../api/otp.js")).default;
    for (const [how, off] of [["as Supabase is now", false], ["once Supabase takes no sign-ups", true]]) {
      const email = `bw-oc-otp-${off ? "off" : "on"}-${tag}@example.invalid`;
      if (off) hooks.signupOff.add(email);
      const asked = await route2(otp, { method: "POST", body: { email } });
      const letter = hooks.mail.filter((one) => one.to?.[0] === email).pop();
      const code = /code is (\d+)/.exec(letter?.text || "")?.[1];
      const redeemed = code ? await redeemCode(email, code) : { status: 0, body: {} };
      const verified = redeemed.body;
      if (verified.user?.id) made.add(verified.user.id);
      check(`a new person signs in by a code from api/otp.js, ${how}`, asked.status === 200 && amrOf(verified.access_token)[0] === "otp"
        && (await whoIs(verified.access_token)).body?.signed_in === true && !hooks.signupOff.has(email),
        `${asked.status} ${asked.body?.error || ""} ${code ? `redeemed ${redeemed.status} ${verified.error_code || ""}` : "no code mailed"}`);
    }
  }


  // Step 4: an orangecheck account merge (me-client 0.45.0, merged_rh).
  // Somebody with two orangecheck accounts, each signed in here once, merges
  // one into the other: the one they stop using no longer signs in, and the
  // one they keep brings our handle for the other (merged_rh). It signs in
  // to the Brickworks account the other had, as long as the handles name
  // one account; two, and it signs in to neither and makes nothing.
  {
    handler = await route();
    // A new account, and none of [others]: a sign-in turned away by
    // Supabase's limit after its account was made finds it on the try again.
    const isNew = (answer, others = []) => answer.status === 200 && !others.includes(answer.body.user?.id)
      && (answer.body.orangecheck?.new_account === true || answer.retried > 0);
    const handleOf = async (rh) => (await rpc("oc_accounts_of_handles", { handles: [rh], aud: AUD }))?.[0]?.account || null;
    const old = token();
    const was = await call(handler, { token: old.jwt });
    check("step 4: a sign-in's handle (rh) is kept with the account it signed in to", was.status === 200
      && (await handleOf(old.claims.rh)) === was.body.user?.id, `${was.status} ${was.body.error || ""}`);
    const kept = token({ merged_rh: [old.claims.rh] });
    const before = new Set(made);
    const merged = await call(handler, { token: kept.jwt });
    check("step 4: an id that has no account, merged from one that has, signs in to that same account", merged.status === 200
      && merged.body.user?.id === was.body.user?.id && merged.body.orangecheck?.new_account === false
      // Turned away by Supabase's limit after the merge was followed, the
      // try again finds the id already the account's.
      && (merged.body.orangecheck?.merged === true || merged.retried > 0) && [...made].every((id) => before.has(id)),
      `${merged.status} ${merged.body.error || ""} ${merged.body.user?.id === was.body.user?.id} ${JSON.stringify(merged.body.orangecheck)} ${merged.retried}`);
    check("step 4: the account is now the kept id's, and the old id's no longer",
      (await rpc("oc_account_of", { did: kept.claims.did_oc })) === was.body.user?.id && (await rpc("oc_account_of", { did: old.claims.did_oc })) === null
      && (await handleOf(old.claims.rh)) === was.body.user?.id && (await handleOf(kept.claims.rh)) === was.body.user?.id);
    forgetForTests();
    check("step 4: and the session the old id started there is ended", (await whoIs(was.body.access_token)).body?.signed_in === false);
    const again = await call(handler, { token: token({ did_oc: kept.claims.did_oc }).jwt });
    check("step 4: the kept id signs in to it again, as itself", again.status === 200 && again.body.user?.id === was.body.user?.id
      && again.body.orangecheck?.merged === false, `${again.status}`);
    // The kept id has an account already: its own, whatever it says it merged.
    const otherToken = token();
    const other = await call(handler, { token: otherToken.jwt });
    const own = await call(handler, { token: token({ did_oc: kept.claims.did_oc, merged_rh: [otherToken.claims.rh] }).jwt });
    check("step 4: an id with an account signs in to its own, never to one its merged handles name", other.status === 200 && own.status === 200
      && own.body.user?.id === was.body.user?.id && (await rpc("oc_account_of", { did: otherToken.claims.did_oc })) === other.body.user?.id, `${own.status}`);
    // Handles that name nobody: a new person.
    const stranger = await call(handler, { token: token({ merged_rh: [randomBytes(16).toString("base64url")] }).jwt });
    check("step 4: merged handles that name nobody here are a new account", isNew(stranger, [was.body.user?.id, other.body.user?.id]),
      `${stranger.status}`);
    // Two accounts named: neither, nothing made, said in words.
    const one = token();
    const two = token();
    const ones = await call(handler, { token: one.jwt });
    const twos = await call(handler, { token: two.jwt });
    const both = token({ merged_rh: [one.claims.rh, two.claims.rh] });
    const counted = new Set(made);
    const torn = await call(handler, { token: both.jwt });
    check("step 4: merged handles that name two accounts sign in to neither, make nothing, and say why", ones.status === 200 && twos.status === 200
      && torn.status === 409 && !torn.body.access_token && /two/.test(torn.body.error || "") && [...made].every((id) => counted.has(id))
      && (await rpc("oc_account_of", { did: both.claims.did_oc })) === null, `${torn.status} ${torn.body.error || ""}`);
    // A merged handle read from the token only: one the claim cannot hold
    // (more than 16) is read as none.
    const many = await call(handler, { token: token({ merged_rh: [one.claims.rh, ...Array.from({ length: 16 }, () => randomBytes(8).toString("hex"))] }).jwt });
    check("step 4: a merged_rh of more than 16 handles is read as none: a new account", isNew(many, [ones.body.user?.id]), `${many.status}`);

    // Linking keeps its handle too, and an unlinked id's handles name nobody.
    const dan = await mintSession(danEmail, { age: true });
    const danLink = token();
    const linkedDan = await ocRoute({ method: "POST", op: "link", access: dan.access_token, body: { token: danLink.jwt } });
    const danMerged = token({ merged_rh: [danLink.claims.rh] });
    const viaMerge = await call(handler, { token: danMerged.jwt });
    check("step 4: an id merged from one linked to an email account signs in to that account", linkedDan.status === 200
      && viaMerge.status === 200 && viaMerge.body.user?.id === dan.kept.user_id && (await rpc("oc_did_of", { account: dan.kept.user_id })) === danMerged.claims.did_oc,
      `${linkedDan.status} ${viaMerge.status} ${viaMerge.body.error || ""}`);
    const unlinkedDan = await rpc("oc_unlink", { account: dan.kept.user_id });
    const afterUnlink = await call(handler, { token: token({ merged_rh: [danLink.claims.rh, danMerged.claims.rh] }).jwt });
    check("step 4: once unlinked, its handles name nobody: a merge from it is a new account, never the one that unlinked it",
      unlinkedDan?.did === danMerged.claims.did_oc && isNew(afterUnlink, [dan.kept.user_id]),
      `${JSON.stringify(unlinkedDan)} ${afterUnlink.status} ${JSON.stringify(afterUnlink.body.orangecheck)} ${afterUnlink.retried}`);
    check("step 4: oc_follow_merge gives nothing for handles that do not name the account", (await rpc("oc_follow_merge",
      { did: `did:oc:${randomBytes(16).toString("hex")}`, account: ones.body.user?.id, handles: [two.claims.rh], aud: AUD })) === null);
  }

  // Step 4: orangecheck Connect (me-client 0.39.0+, connectProvision and
  // connectDelete). A tick of the box under Sign in with orangecheck, after
  // a sign-in by emailed code, asks orangecheck to make the person an
  // account; no tick, no call. It never blocks or fails the sign-in.
  // Deleting the Brickworks account deletes that one first.
  {
    const connected = (account) => rpc("oc_connected_of", { account });
    const carol = await mintSession(carolEmail, { age: true });
    const asked = (access, body = { consent: true }) => ocRoute({ method: "POST", op: "connect", access, body });
    const key = process.env.OC_CONNECT_KEY;
    delete process.env.OC_CONNECT_KEY;
    const noKey = await asked(carol.access_token);
    process.env.OC_CONNECT_KEY = key;
    check("Connect: without the Connect key, nothing is asked of orangecheck, and it says so", noKey.status === 503
      && ochk.connect.length === 0, `${noKey.status} ${noKey.body.error || ""}`);
    const unticked = await asked(carol.access_token, {});
    const falsely = await asked(carol.access_token, { consent: "yes" });
    check("Connect: no tick (consent not true) makes no call", unticked.status === 422 && falsely.status === 422 && ochk.connect.length === 0
      && (await connected(carol.kept.user_id)) === null, `${unticked.status} ${falsely.status} ${ochk.connect.length}`);
    const nobody = await asked("not.a.token");
    check("Connect: without a sign-in, refused, and no call", nobody.status === 401 && ochk.connect.length === 0, `${nobody.status}`);
    const ticked = await asked(carol.access_token);
    const call1 = ochk.connect.filter((one) => one.path === "/api/connect/provision");
    check("Connect: a tick after a sign-in by code asks orangecheck once, with consent, the account's id and the Connect key, and nowhere else",
      ticked.status === 200 && ticked.body.made === true && call1.length === 1 && call1[0].body.consent === true
      && call1[0].body.user_id === carol.kept.user_id && call1[0].key && call1[0].redirect === "error"
      && Object.keys(call1[0].body).sort().join(",") === "consent,user_id", `${ticked.status} ${JSON.stringify(ticked.body)} ${call1.length}`);
    const row = await connected(carol.kept.user_id);
    check("Connect: the id orangecheck made is kept with the account", row?.did === ticked.body.did && Boolean(row?.made_at), JSON.stringify(row));
    // orangecheck refusing or down: answered, never thrown, and the
    // sign-in it followed goes on.
    ochk.provision = () => [503, { ok: false }];
    const down = await asked(carol.access_token);
    check("Connect: orangecheck down, the answer says nothing was made, and the sign-in goes on", down.status === 200 && down.body.made === false
      && (await whoIs(carol.access_token)).body?.signed_in === true && (await theme(carol.access_token)).status === 200,
      `${down.status} ${JSON.stringify(down.body)}`);
    ochk.provision = () => { throw new Error("orangecheck_check: Connect timed out"); };
    const thrown = await asked(carol.access_token);
    check("Connect: and a call that never answers too", thrown.status === 200 && thrown.body.made === false, `${thrown.status} ${JSON.stringify(thrown.body)}`);
    ochk.provision = (body) => [200, { ok: true, did_oc: `did:oc:${createHash("sha256").update(body.user_id).digest("hex").slice(0, 32)}`, is_new: false }];
    // Not for somebody who has orangecheck already: their sign-in gave it.
    const counted = ochk.connect.length;
    const ocOnly = await call(handler, { token: token().jwt });
    const fromOc = await asked(ocOnly.body.access_token);
    const danNow = await mintSession(danEmail, { age: true });
    await rpc("oc_link", { did: `did:oc:${randomBytes(16).toString("hex")}`, account: danNow.kept.user_id });
    const linkedOne = await asked(danNow.access_token);
    check("Connect: an account that has orangecheck (its own, or linked) is never made a second one", fromOc.status !== 200 || fromOc.body.made === false);
    check("Connect: ...and no call is made for it", ochk.connect.length === counted && linkedOne.body.made === false,
      `${fromOc.status} ${linkedOne.status} ${JSON.stringify(linkedOne.body)}`);
    // Deleting: Connect's account first, then ours; refused whole while
    // orangecheck cannot delete it.
    ochk.remove = () => [503, {}];
    const held = await quit(carol.access_token, { confirm: carolEmail });
    check("Connect: while orangecheck cannot delete the account it made, the Brickworks account is not deleted either, and it says so",
      held.status === 503 && /orangecheck/.test(held.body?.error || "") && (await adminUser(carol.kept.user_id)).status === 200,
      `${held.status} ${held.body?.error || ""}`);
    ochk.remove = () => [200, { ok: true, result: "deleted" }];
    const removed = ochk.connect.filter((one) => one.path === "/api/connect/delete").length;
    const gone = await quit(carol.access_token, { confirm: carolEmail });
    const deletes = ochk.connect.filter((one) => one.path === "/api/connect/delete");
    check("Connect: deleting the account calls connectDelete for it, with the key, then deletes it", gone.status === 200
      && deletes.length === removed + 1 && deletes.at(-1).body.user_id === carol.kept.user_id && deletes.at(-1).key
      && (await adminUser(carol.kept.user_id)).status === 404 && (await connected(carol.kept.user_id)) === null,
      `${gone.status} ${gone.body?.error || ""} ${deletes.length - removed}`);
    // site-attest's L1: a person can always delete their Brickworks account.
    // orangecheck refusing for good (the account holds earnings, or cannot
    // be erased) deletes ours all the same, and says plainly that theirs
    // stays at ochk.app; only an outage holds it (503, above). orangecheck's
    // final ruling: a Connect account with no Connect key here, or one
    // orangecheck does not know, is our setup fault, and deleting would
    // leave their orangecheck account behind unsaid, so it is paused: 503,
    // nothing deleted, in those words.
    const deleteCalls = () => ochk.connect.filter((one) => one.path === "/api/connect/delete").length;
    const PAUSED = "Deleting is paused while Brickworks fixes a setup problem. Nothing has been deleted.";
    for (const reason of ["holds_earnings", "not_deletable"]) {
      const email = `delivered+bw-oc-${reason.replace("_", "")}-${tag}@resend.dev`;
      const leaving = await mintSession(email, { age: true });
      await rpc("oc_connect_asked", { account: leaving.kept.user_id });
      ochk.remove = () => [409, { ok: false, reason }];
      const asked = deleteCalls();
      const left = await quit(leaving.access_token, { confirm: email });
      check(`Connect, L1: orangecheck refusing for good (${reason}), the Brickworks account is deleted all the same, and says theirs stays at ochk.app`,
        left.status === 200 && left.body?.deleted === true && left.body?.orangecheck?.kept === true
        && /stays yours/.test(left.body?.orangecheck?.said || "") && /ochk\.app/.test(left.body?.orangecheck?.said || "")
        && deleteCalls() === asked + 1 && (await adminUser(leaving.kept.user_id)).status === 404,
        `${left.status} ${JSON.stringify(left.body)} ${deleteCalls() - asked}`);
      await deleteAccount(email).catch(() => false);
    }
    ochk.remove = () => [200, { ok: true, result: "deleted" }];
    {
      const email = `delivered+bw-oc-nokey-${tag}@resend.dev`;
      const leaving = await mintSession(email, { age: true });
      await rpc("oc_connect_asked", { account: leaving.kept.user_id });
      const keyWas = process.env.OC_CONNECT_KEY;
      delete process.env.OC_CONNECT_KEY;
      const asked = deleteCalls();
      let left;
      try {
        left = await quit(leaving.access_token, { confirm: email });
      } finally {
        process.env.OC_CONNECT_KEY = keyWas;
      }
      check("Connect, L1: without the Connect key, a Connect account's deletion is paused: 503, in those words, nothing deleted, orangecheck asked nothing",
        left.status === 503 && left.body?.error === PAUSED && deleteCalls() === asked
        && (await adminUser(leaving.kept.user_id)).status === 200 && (await connected(leaving.kept.user_id)) !== null,
        `${left.status} ${JSON.stringify(left.body)} ${deleteCalls() - asked} calls`);
      await deleteAccount(email).catch(() => false);
    }
    {
      const email = `delivered+bw-oc-badkey-${tag}@resend.dev`;
      const leaving = await mintSession(email, { age: true });
      await rpc("oc_connect_asked", { account: leaving.kept.user_id });
      ochk.remove = () => [401, { ok: false, reason: "invalid_api_key" }];
      const left = await quit(leaving.access_token, { confirm: email });
      ochk.remove = () => [200, { ok: true, result: "deleted" }];
      check("Connect, L1: with a key orangecheck does not know, a Connect account's deletion is paused: 503, in those words, nothing deleted",
        left.status === 503 && left.body?.error === PAUSED
        && (await adminUser(leaving.kept.user_id)).status === 200 && (await connected(leaving.kept.user_id)) !== null,
        `${left.status} ${JSON.stringify(left.body)}`);
      await deleteAccount(email).catch(() => false);
    }
    // site-attest: deleting without connectDelete's success is an allow-list.
    // Through the route, with orangecheck stood in: bad_request is paused in
    // those words, and a reason nobody knows holds the deletion too (me-client
    // reads it as unavailable, so it says to try again). Nothing deleted.
    for (const [why, answer, words] of [["bad_request", [400, { ok: false, reason: "bad_request" }], PAUSED],
      ["a reason nobody knows", [409, { ok: false, reason: "made_up_reason" }], null]]) {
      const email = `delivered+bw-oc-${why === "bad_request" ? "badreq" : "oddreason"}-${tag}@resend.dev`;
      const leaving = await mintSession(email, { age: true });
      await rpc("oc_connect_asked", { account: leaving.kept.user_id });
      ochk.remove = () => answer;
      const left = await quit(leaving.access_token, { confirm: email });
      ochk.remove = () => [200, { ok: true, result: "deleted" }];
      check(`Connect, allow-list: orangecheck answering ${why}, the deletion is held, 503${words ? ", in those words" : ""}, nothing deleted`,
        left.status === 503 && (words ? left.body?.error === words : typeof left.body?.error === "string")
        && (await adminUser(leaving.kept.user_id)).status === 200 && (await connected(leaving.kept.user_id)) !== null,
        `${left.status} ${JSON.stringify(left.body)}`);
      await deleteAccount(email).catch(() => false);
    }
    // And in Brickworks' own code, past me-client's mapping: unprovision
    // given each answer straight. Only unknown_user, deleted, detached,
    // already_deleted, holds_earnings and not_deletable let the deletion go.
    {
      const { unprovision } = await import("../../api/_oc.js");
      const TRY = /Try again in a minute/;
      const cases = [
        ["an unrecognised reason", { ok: false, reason: "made_up_reason", status: 409 }, { go: false, error: PAUSED }],
        ["an unrecognised ok result", { ok: true, result: "archived" }, { go: false, error: PAUSED }],
        ["ok with no result", { ok: true }, { go: false, error: PAUSED }],
        ["invalid_api_key", { ok: false, reason: "invalid_api_key", status: 401 }, { go: false, error: PAUSED }],
        ["bad_request", { ok: false, reason: "bad_request", status: 400 }, { go: false, error: PAUSED }],
        ["unavailable", { ok: false, reason: "unavailable", status: 0 }, { go: false, error: TRY }],
        ["rate_limited", { ok: false, reason: "rate_limited", status: 429 }, { go: false, error: TRY }],
        ["a throw", new Error("orangecheck_check: thrown"), { go: false, error: TRY }],
        ["unknown_user", { ok: false, reason: "unknown_user", status: 404 }, { go: true }],
        ["deleted", { ok: true, result: "deleted" }, { go: true }],
        ["detached", { ok: true, result: "detached" }, { go: true }],
        ["already_deleted", { ok: true, result: "already_deleted" }, { go: true }],
        ["holds_earnings", { ok: false, reason: "holds_earnings", status: 409 }, { go: true, kept: true }],
        ["not_deletable", { ok: false, reason: "not_deletable", status: 409 }, { go: true, kept: true }],
      ];
      const wrong = [];
      for (const [name, answer, wanted] of cases) {
        let asked = 0;
        const decided = await unprovision(randomUUID(), async () => {
          asked += 1;
          if (answer instanceof Error) throw answer;
          return answer;
        }).catch((trouble) => ({ threw: String(trouble?.message || trouble) }));
        const right = asked === 1 && decided?.go === wanted.go
          && (wanted.go ? Boolean(decided.kept) === Boolean(wanted.kept)
            : decided.status === 503 && (wanted.error instanceof RegExp ? wanted.error.test(decided.error || "") : decided.error === wanted.error));
        if (!right) wrong.push(`${name}: ${JSON.stringify(decided)} (${asked} asked)`);
      }
      check(`Connect, allow-list in Brickworks' own unprovision: ${cases.length} answers fed straight in, only the six known ones delete, the rest 503`,
        wrong.length === 0, wrong.join("; "));
    }

    // Somebody who never ticked the box never waits on orangecheck to leave:
    // with orangecheck down, and with no Connect key, their account is
    // deleted at once, and nothing is asked of orangecheck (0 calls).
    for (const [how, setUp] of [["orangecheck down", () => { ochk.remove = () => [503, {}]; }],
      ["no Connect key", () => { delete process.env.OC_CONNECT_KEY; }]]) {
      const email = `delivered+bw-oc-plain-${how.split(" ")[0]}-${tag}@resend.dev`;
      const plain = await mintSession(email, { age: true });
      const keyWas = process.env.OC_CONNECT_KEY;
      const before = ochk.connect.length;
      setUp();
      let plainGone;
      try {
        plainGone = await quit(plain.access_token, { confirm: email });
      } finally {
        process.env.OC_CONNECT_KEY = keyWas;
        ochk.remove = () => [200, { ok: true, result: "deleted" }];
      }
      check(`Connect: an account that never ticked the box is deleted with ${how}, asking orangecheck nothing (0 calls), and told nothing of it`,
        plainGone.status === 200 && plainGone.body?.deleted === true && ochk.connect.length === before && !plainGone.body?.orangecheck
        && (await adminUser(plain.kept.user_id)).status === 404, `${plainGone.status} ${JSON.stringify(plainGone.body)} ${ochk.connect.length - before} calls`);
      await deleteAccount(email).catch(() => false);
    }

    // orangecheck's answer (2026-10-24): the address goes with email_verified
    // only when the same request carries a fresh emailed code's session for
    // that very address (amr otp, within the five minutes linking asks).
    // Never for a password or an orangecheck session, a stale code, or an
    // address the request names. Each refusal is checked beside the one
    // case that sends it, so none passes by sending no address at all.
    const provisions = () => ochk.connect.filter((one) => one.path === "/api/connect/provision");
    const sentFor = async (access, body) => {
      const from = provisions().length;
      const answer = await asked(access, body);
      return { answer, sent: provisions().slice(from).map((one) => one.body) };
    };
    const unverified = (one) => one.sent.every((body) => !("email" in body) && !("email_verified" in body));
    const codedEmail = `bw-oc-verified-${tag}@example.invalid`;
    const code = await mintCode(codedEmail);
    const coded = (await redeemCode(codedEmail, code)).body;
    if (coded.user?.id) made.add(coded.user.id);
    const fromCode = await sentFor(coded.access_token);
    const verifiedOwn = amrOf(coded.access_token)[0] === "otp" && fromCode.answer.status === 200 && fromCode.sent.length === 1
      && fromCode.sent[0].email === codedEmail && fromCode.sent[0].email_verified === true;
    check("Connect: a fresh emailed code's session provisions with its own address, email_verified", verifiedOwn,
      `${fromCode.answer.status} ${JSON.stringify(fromCode.sent)}`);
    const password = await mintSession(pwEmail, { age: true });
    const fromPassword = await sentFor(password.access_token);
    check("Connect: a password session (a test account's) provisions without email_verified, where a fresh code's has it",
      verifiedOwn && amrOf(password.access_token)[0] === "password" && fromPassword.sent.length === 1 && unverified(fromPassword),
      `${fromPassword.answer.status} ${JSON.stringify(fromPassword.sent)}`);
    const other = `bw-oc-someone-else-${tag}@example.invalid`;
    const fromOther = await sentFor(coded.access_token, { consent: true, email: other, email_verified: true });
    check("Connect: an address the request names is never sent as verified, only the code's own",
      verifiedOwn && fromOther.sent.length === 1 && fromOther.sent.every((body) => body.email === codedEmail),
      `${fromOther.answer.status} ${JSON.stringify(fromOther.sent)}`);
    // Six minutes on: the same code's session is stale.
    const now = Date.now;
    Date.now = () => now() + 6 * 60 * 1000;
    forgetForTests();
    let fromStale;
    try {
      fromStale = await sentFor(coded.access_token);
    } finally {
      Date.now = now;
      forgetForTests();
    }
    check("Connect: a code's session past five minutes never provisions with email_verified, where a fresh one does",
      verifiedOwn && unverified(fromStale), `${fromStale.answer.status} ${JSON.stringify(fromStale.sent)}`);
    // site-attest's A: counted, not read through every(), which holds of no
    // calls at all. Refused, fresh: false, and nothing asked of orangecheck.
    check("Connect: a code's session past five minutes is refused 403, fresh: false, and asks orangecheck nothing (0 calls)",
      fromStale.answer.status === 403 && fromStale.answer.body?.fresh === false && fromStale.sent.length === 0,
      `${fromStale.answer.status} ${JSON.stringify(fromStale.answer.body)} ${fromStale.sent.length} calls`);
    // An orangecheck session of the same account, linked first.
    await rpc("oc_link", { did: `did:oc:${randomBytes(16).toString("hex")}`, account: coded.user?.id });
    const viaOc = await call(handler, { token: token({ did_oc: await rpc("oc_did_of", { account: coded.user?.id }) }).jwt });
    const fromItsOc = await sentFor(viaOc.body.access_token);
    check("Connect: an orangecheck session never provisions with email_verified, where a fresh code does",
      // Answered "has orangecheck" first: what keeps it from sending, said.
      verifiedOwn && viaOc.status === 200 && viaOc.body.user?.id === coded.user?.id && unverified(fromItsOc)
      && fromItsOc.answer.status === 200 && fromItsOc.answer.body?.made === false && fromItsOc.answer.body?.reason === "has_orangecheck",
      `${viaOc.status} ${fromItsOc.answer.status} ${JSON.stringify(fromItsOc.answer.body)} ${JSON.stringify(fromItsOc.sent)}`);
  }

  // orangecheck's review of step 4, L2: an account deleted while Connect is
  // still making it an orangecheck account. Deleting asked orangecheck to
  // delete one that was not made yet (unknown_user), and the answer that
  // came after made one nothing here knew of, which nobody could ever
  // delete. Now an answer for an account gone, or going, deletes what it
  // made (supabase/orangecheck_connect_leaving.sql). Twice: the account
  // deleted whole before orangecheck answers; and only marked as going, its
  // own deletion held at the last step until the answer is written down.
  {
    // The accounts orangecheck holds, as it would.
    const theirs = new Set();
    const didOf = (id) => `did:oc:${createHash("sha256").update(id).digest("hex").slice(0, 32)}`;
    const provisionWas = ochk.provision;
    const removeWas = ochk.remove;
    const unmade = (body) => (theirs.delete(body.user_id) ? [200, { ok: true, result: "deleted" }] : [404, { ok: false, reason: "unknown_user" }]);
    const ticks = (access) => ocRoute({ method: "POST", op: "connect", access, body: { consent: true } });
    for (const how of ["deleted whole", "only marked as going"]) {
      const email = `delivered+bw-oc-l2-${how.split(" ")[0]}-${tag}@resend.dev`;
      const fay = await mintSession(email, { age: true });
      let deleting = null;
      let release = () => {};
      ochk.remove = unmade;
      ochk.provision = async (body) => {
        if (how === "deleted whole") deleting = await quit(fay.access_token, { confirm: email });
        else {
          let heard;
          const deleteAsked = new Promise((done) => { heard = done; });
          ochk.remove = (asked) => { heard(); return unmade(asked); };
          hooks.holdDelete = { account: fay.kept.user_id, until: new Promise((done) => { release = done; }) };
          deleting = quit(fay.access_token, { confirm: email });
          await deleteAsked;
          ochk.remove = unmade;
        }
        theirs.add(body.user_id);
        return [200, { ok: true, did_oc: didOf(body.user_id), is_new: true }];
      };
      let ticked;
      let left;
      try {
        ticked = await ticks(fay.access_token);
      } finally {
        release();
        left = await deleting;
        hooks.holdDelete = null;
        ochk.provision = provisionWas;
        ochk.remove = removeWas;
      }
      const orphan = theirs.has(fay.kept.user_id);
      check(`Connect, L2: an account ${how} while orangecheck was making it one leaves no orangecheck account behind`,
        ticked.status === 200 && ticked.body?.made === false && left?.status === 200 && !orphan
        && (await adminUser(fay.kept.user_id)).status === 404,
        `${ticked.status} ${JSON.stringify(ticked.body)}, deleted ${left?.status}${orphan ? ", orphaned at orangecheck" : ""}`);
      await deleteAccount(email).catch(() => false);
    }
    // site-attest's race, step by step (its bw237/l2_race.mjs, on our own
    // SQL): (a) the deletion marks first, before any oc_connected row is
    // there; (b) a first tick asks, and the row is written; (c) orangecheck
    // answers, and the answer is asked to be kept; (d) the deletion goes
    // on, and the account goes, its row with it.
    {
      const email = `delivered+bw-oc-l2-race-${tag}@resend.dev`;
      const hal = await mintSession(email, { age: true });
      let reached;
      let release = () => {};
      const marked = new Promise((done) => { reached = done; });
      hooks.holdDelete = { account: hal.kept.user_id, reached, until: new Promise((done) => { release = done; }) };
      ochk.remove = unmade;
      ochk.provision = (body) => {
        theirs.add(body.user_id);
        return [200, { ok: true, did_oc: didOf(body.user_id), is_new: true }];
      };
      // (a), held just before (d).
      const deleting = quit(hal.access_token, { confirm: email });
      let ticked;
      let left;
      try {
        await Promise.race([marked, deleting]);
        // (b) and (c).
        ticked = await ticks(hal.access_token);
      } finally {
        release();
        // (d).
        left = await deleting;
        hooks.holdDelete = null;
        ochk.provision = provisionWas;
        ochk.remove = removeWas;
      }
      const orphan = theirs.has(hal.kept.user_id);
      check("Connect, L2 race: the deletion marks before any row, a first tick asks, orangecheck answers, the account goes: no orangecheck account left behind",
        ticked?.status === 200 && ticked.body?.made === false && left?.status === 200 && !orphan
        && (await adminUser(hal.kept.user_id)).status === 404,
        `${ticked?.status} ${JSON.stringify(ticked?.body)}, deleted ${left?.status}${orphan ? ", orphaned at orangecheck" : ""}`);
      await deleteAccount(email).catch(() => false);
    }
    // site-attest's R1 (its bw237/l2_stays.mjs): two deletions of one
    // account at once (a double submit). A is held at its last step; B
    // fails there; a tick lands between; then A goes through and the
    // account goes with its row. B's failure must not lift the mark A
    // still relies on. R1: an account that never ticked, its first tick
    // made then; R1b: one that ticked before, whose old orangecheck
    // account A deletes, and the tick makes it a new one.
    for (const r of ["R1", "R1b"]) {
      const email = `delivered+bw-oc-l2-${r.toLowerCase()}-${tag}@resend.dev`;
      const jo = await mintSession(email, { age: true });
      let made = 0;
      ochk.remove = unmade;
      ochk.provision = (body) => {
        made += 1;
        theirs.add(body.user_id);
        return [200, { ok: true, did_oc: didOf(`${body.user_id}:${made}`), is_new: true }];
      };
      if (r === "R1b") await ticks(jo.access_token);
      const before = theirs.has(jo.kept.user_id);
      let reached;
      let release = () => {};
      const heldA = new Promise((done) => { reached = done; });
      hooks.holdDelete = { account: jo.kept.user_id, reached, until: new Promise((done) => { release = done; }) };
      const a = quit(jo.access_token, { confirm: email });
      let b;
      let ticked;
      let left;
      try {
        await Promise.race([heldA, a]);
        hooks.holdDelete = { account: jo.kept.user_id, until: Promise.resolve(), fails: true };
        b = await quit(jo.access_token, { confirm: email });
        hooks.holdDelete = null;
        ticked = await ticks(jo.access_token);
      } finally {
        release();
        left = await a;
        hooks.holdDelete = null;
        ochk.provision = provisionWas;
        ochk.remove = removeWas;
      }
      const orphan = theirs.has(jo.kept.user_id);
      check(`Connect, L2 ${r}: two deletions at once, one failing while the other goes on, and a tick between: no orangecheck account left behind`,
        (r === "R1" || before) && b?.status === 502 && ticked?.status === 200 && ticked.body?.made === false && left?.status === 200 && !orphan
        && (await adminUser(jo.kept.user_id)).status === 404,
        `${r === "R1b" ? `ticked before ${before}, ` : ""}B ${b?.status}, tick ${ticked?.status} ${JSON.stringify(ticked?.body)}, A ${left?.status}${orphan ? ", orphaned at orangecheck" : ""}`);
      await deleteAccount(email).catch(() => false);
    }
    // A deletion that fails after its mark leaves the mark (it lapses), and
    // for an account Connect was never asked for, its row of the mark alone
    // reads as never asked, so the next deletion asks orangecheck nothing.
    {
      const email = `delivered+bw-oc-l2-fails-${tag}@resend.dev`;
      const ivy = await mintSession(email, { age: true });
      hooks.holdDelete = { account: ivy.kept.user_id, until: Promise.resolve(), fails: true };
      const failed = await quit(ivy.access_token, { confirm: email });
      hooks.holdDelete = null;
      const leftOver = await rpc("oc_connected_of", { account: ivy.kept.user_id });
      const calls = ochk.connect.length;
      ochk.remove = () => [503, {}];
      const second = await quit(ivy.access_token, { confirm: email });
      ochk.remove = removeWas;
      check("Connect, L2: after a deletion that fails past its mark, an account that never ticked reads as never asked, and its next deletion asks orangecheck nothing",
        failed.status === 502 && leftOver === null && second.status === 200 && ochk.connect.length === calls,
        `${failed.status} ${JSON.stringify(leftOver)} ${second.status} ${ochk.connect.length - calls} calls`);
      await deleteAccount(email).catch(() => false);
    }
    // A tick within 15 minutes of a deletion that was held (orangecheck
    // down) deletes what it makes, and says so: the mark lapses rather than
    // being lifted, which fails safe (that it lapses is the dry run's,
    // tools/orangecheck_connect_leaving_try.sql).
    const email = `delivered+bw-oc-l2-held-${tag}@resend.dev`;
    const gil = await mintSession(email, { age: true });
    await rpc("oc_connect_asked", { account: gil.kept.user_id });
    ochk.remove = () => [503, {}];
    const held = await quit(gil.access_token, { confirm: email });
    ochk.remove = unmade;
    ochk.provision = (body) => {
      theirs.add(body.user_id);
      return [200, { ok: true, did_oc: didOf(`${body.user_id}:held`), is_new: true }];
    };
    const again = await ticks(gil.access_token);
    ochk.provision = provisionWas;
    ochk.remove = removeWas;
    check("Connect, L2: a tick within 15 minutes of a deletion that was held deletes what orangecheck made, and says so", held.status === 503
      && again.status === 200 && again.body?.made === false && again.body?.reason === "account_leaving" && !theirs.has(gil.kept.user_id),
      `${held.status} ${again.status} ${JSON.stringify(again.body)}`);
    await deleteAccount(email).catch(() => false);
  }

  // The desktop's sign-in (?op=native, oc237): orangecheck's authorize page
  // hands the app's listener a code, the app posts it here with its PKCE
  // verifier and the redirect it listened at, and the code is traded for
  // the token the window would have given (me-client's exchangeNativeCode),
  // then taken as ?op=signin takes one. Each refusal is beside a case that
  // signs in, so none passes by refusing everything.
  {
    const native = async (body) => call(await route(), body, { op: "native" });
    /// A sign-in from the app that should get in, signed in again with a
    /// new code of the same [claims] while Supabase's redemption limit
    /// turns it away (BUSY), as the person would: {answer, sent}, the last.
    const getsIn = async (claims, extra = {}) => {
      for (let attempt = 0; ; attempt += 1) {
        const sent = nativeCode(claims);
        const answer = await native({ ...sent, ...extra });
        if (!(answer.status === 503 && BUSY.test(answer.body?.error || "")) || attempt >= 8) return { answer, sent };
        await new Promise((done) => setTimeout(done, 11000));
      }
    };
    const refusedInWords = (answer, status) => answer.status === status && typeof answer.body?.error === "string" && answer.body.error.length > 10;

    const off = await native(nativeCode());
    check("native: not offered here (no OC_NATIVE, no NATIVE_FOR_EVERYONE), refused in words, and orangecheck asked nothing",
      refusedInWords(off, 503) && ochk.traded.length === 0 && (await whoIs(undefined)).body?.orangecheck?.native === null,
      `${off.status} ${off.body?.error || ""} ${ochk.traded.length}`);
    process.env.OC_NATIVE = "1";
    const offer = (await whoIs(undefined)).body?.orangecheck?.native;
    check("native: offered, /api/account tells the app where to sign in: the project, orangecheck's host, this audience",
      offer?.project === process.env.OC_PROJECT_KEY && offer?.auth === "https://ochk.io" && offer?.audience === AUD, JSON.stringify(offer));

    const did = `did:oc:${randomBytes(16).toString("hex")}`;
    const { answer: first, sent: firstCode } = await getsIn({ did_oc: did }, { project: "pk_test_someone_else" });
    const trade = ochk.traded.at(-1);
    const minted = ochk.minted.at(-1);
    check("native: a code signs in, a new account, with a session that is a Brickworks sign-in", first.status === 200
      && first.body.orangecheck?.did === did && first.body.orangecheck?.new_account === true
      && (await whoIs(first.body.access_token)).body?.signed_in === true, `${first.status} ${first.body?.error || ""}`);
    check("native: traded once, with this project's key from configuration (never the app's), the app's code, verifier and redirect, never redirected",
      ochk.traded.filter((one) => one.code === firstCode.code).length === 1 && trade.project === process.env.OC_PROJECT_KEY && trade.grant_type === "authorization_code"
      && trade.code === firstCode.code && trade.code_verifier === firstCode.code_verifier && trade.redirect_uri === firstCode.redirect_uri
      && trade.redirect === "error", JSON.stringify({ ...trade, code: "[code]", code_verifier: "[verifier]" }));
    check("native: the token it was traded for is ended at orangecheck, and not in the answer", ochk.revoked.includes(minted?.jwt)
      && !JSON.stringify(first.body).includes(minted?.jwt));
    const popup = await call(handler, { token: minted.jwt });
    check("native: and its token is spent, as the window's: sent to ?op=signin after, refused", popup.status === 409, `${popup.status}`);
    const reused = await native(firstCode);
    check("native: a code used already is refused", refusedInWords(reused, 401), `${reused.status} ${reused.body?.error || ""}`);
    const { answer: second } = await getsIn({ did_oc: did });
    const byWindow = await call(handler, { token: token({ did_oc: did }).jwt });
    check("native: the same orangecheck id signs in to the same account, from the app and from the window", second.status === 200
      && second.body.user?.id === first.body.user?.id && byWindow.status === 200 && byWindow.body.user?.id === first.body.user?.id,
      `${second.status} ${byWindow.status}`);

    const wrongVerifier = nativeCode();
    const tried = await native({ ...wrongVerifier, code_verifier: randomBytes(32).toString("base64url") });
    check("native: a code with a verifier its challenge was not made from is refused", refusedInWords(tried, 401), `${tried.status} ${tried.body?.error || ""}`);
    const thenRight = await native(wrongVerifier);
    check("native: ...and is spent by trying: the right verifier after it is refused too", refusedInWords(thenRight, 401), `${thenRight.status}`);
    const elsewhere = nativeCode();
    const otherPort = await native({ ...elsewhere, redirect_uri: "http://127.0.0.1:53112/oc/callback" });
    check("native: a code sent with a redirect_uri other than the one it was given for is refused", refusedInWords(otherPort, 401),
      `${otherPort.status} ${otherPort.body?.error || ""}`);
    const accountsBefore = made.size;
    const forOther = await native(nativeCode({ aud: "https://example.com" }));
    check("native: a code whose token is for another audience is refused, and no account is made", refusedInWords(forOther, 401)
      && made.size === accountsBefore, `${forOther.status} ${forOther.body?.error || ""}`);
    const unended = await native(nativeCode({ rh: undefined }));
    check("native: a code whose token has no rh is refused", refusedInWords(unended, 401), `${unended.status} ${unended.body?.error || ""}`);

    const asks = ochk.traded.length;
    const shapes = [
      ["a redirect_uri that is not 127.0.0.1", { ...nativeCode(), redirect_uri: "https://evil.example/oc/callback" }],
      ["a redirect_uri at localhost", { ...nativeCode(), redirect_uri: "http://localhost:53111/oc/callback" }],
      ["a redirect_uri with a query", { ...nativeCode(), redirect_uri: "http://127.0.0.1:53111/oc/callback?then=x" }],
      ["a verifier too short", { ...nativeCode(), code_verifier: "short" }],
      ["no code", { ...nativeCode(), code: "" }],
      ["nothing at all", {}],
    ];
    const wrongShapes = [];
    for (const [name, body] of shapes) {
      const answer = await native(body);
      if (!refusedInWords(answer, 422)) wrongShapes.push(`${name}: ${answer.status}`);
    }
    check(`native: ${shapes.length} malformed asks refused 422 in words, orangecheck asked nothing`, wrongShapes.length === 0
      && ochk.traded.length === asks, `${wrongShapes.join("; ")} ${ochk.traded.length - asks} asked`);
    ochk.tradeStatus = 503;
    const down = await native(nativeCode());
    ochk.tradeStatus = 200;
    check("native: orangecheck down, 503 in words, nobody signed in", refusedInWords(down, 503) && !down.body.access_token,
      `${down.status} ${down.body?.error || ""}`);
    const wrongMethod = await call(await route(), nativeCode(), { op: "native", method: "GET" });
    check("native: only POST", wrongMethod.status === 405, `${wrongMethod.status}`);
    delete process.env.OC_NATIVE;
  }

  // site-attest: a token orangecheck ended by its id (POST /api/auth/revoke,
  // the list's `tokens`) before it reached us is refused at the exchange,
  // by the window and by the app alike. The requests after are asked
  // without the id: our own revoke of the token right after the exchange
  // puts its id on the list, and must sign nobody out.
  {
    const listWith = (jtis) => () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: jtis.map(endedJti), accounts: {}, handles: {} });
    const listWas = ochk.list;
    try {
      const ended = token();
      const other = token({ rh: ended.claims.rh });
      ochk.list = listWith([ended.claims.jti]);
      const refused = await call(await route(), { token: ended.jwt });
      check("an orangecheck token whose id was ended before sign-in is refused at the exchange, 401 in words",
        refused.status === 401 && /ended/.test(refused.body?.error || "") && !refused.body?.access_token,
        `${refused.status} ${refused.body?.error || ""}`);
      const sibling = await call(await route(), { token: other.jwt });
      check("...where a token of the same sign-in (rh) with an id not ended gets in", sibling.status === 200,
        `${sibling.status} ${sibling.body?.error || ""}`);
      process.env.OC_NATIVE = "1";
      const appCode = nativeCode({ jti: ended.claims.jti, rh: ended.claims.rh });
      const fromApp = await call(await route(), appCode, { op: "native" });
      delete process.env.OC_NATIVE;
      check("...and from the app (?op=native), a code whose token's id was ended is refused, 401",
        fromApp.status === 401 && !fromApp.body?.access_token, `${fromApp.status} ${fromApp.body?.error || ""}`);
      ochk.list = listWith([]);
      const fresh = await call(await route(), { token: token().jwt });
      ochk.list = listWith([claimsOf(ochk.revoked.at(-1)).jti]);
      forgetForTests();
      const after = await whoIs(fresh.body.access_token);
      const wrote = await theme(fresh.body.access_token);
      check("our own revoke of the token right after the exchange puts its id on the list, and its session still reads and writes",
        fresh.status === 200 && claimsOf(ochk.revoked.at(-1)).did_oc === fresh.body.orangecheck?.did
        && after.body?.signed_in === true && wrote.status === 200, `${fresh.status} ${after.body?.signed_in} ${wrote.status}`);
    } finally {
      delete process.env.OC_NATIVE;
      ochk.list = listWas;
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
  for (const email of [adaEmail, bobEmail, carolEmail, danEmail, pwEmail]) await deleteAccount(email).catch(() => false);
  let gone = 0;
  for (const id of made) {
    const reply = await real(`${SB}/auth/v1/admin/users/${id}`, { method: "DELETE", headers: ADMIN });
    if (reply.ok || reply.status === 404) gone += 1;
  }
  console.log(`orangecheck_check: ${made.size} accounts made, ${gone} deleted`);
  console.log(`orangecheck_check: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}
