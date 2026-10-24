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

import { generateKeyPairSync, randomBytes, sign } from "node:crypto";

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

// orangecheck, stood in for.
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const stranger = generateKeyPairSync("ed25519");
const KID = "check-key";
const jwk = { ...publicKey.export({ format: "jwk" }), kid: KID, alg: "EdDSA", use: "sig" };
const ochk = {
  rule: { ok: true, require_bond: null },
  ruleStatus: 200,
  list: () => ({ v: 1, at: Math.floor(Date.now() / 1000), tokens: [], accounts: {}, handles: {} }),
  listStatus: 200,
  revoked: [],
};

const made = new Set();
const real = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = String(input?.url || input);
  const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
  if (url === "https://ochk.io/.well-known/jwks.json") return json(200, { keys: [jwk] });
  if (url.startsWith("https://me.ochk.io/api/integrator/revocations")) return json(ochk.listStatus, ochk.list());
  if (/^https:\/\/me\.ochk\.io\/api\/integrator\/[^/]+\/sign-in$/.test(url)) return json(ochk.ruleStatus, ochk.rule);
  if (url === "https://ochk.io/api/auth/revoke") {
    ochk.revoked.push(...JSON.parse(init.body).tokens);
    return json(200, { ok: true, revoked: 1 });
  }
  if (/^https:\/\/([a-z0-9-]+\.)*ochk\.(io|app)\//.test(url)) throw new Error(`orangecheck_check: unexpected ${url}`);
  const reply = await real(input, init);
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
function check(name, ok, said = "") {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`${ok ? "pass" : "FAIL"} ${name}${said ? `: ${said}` : ""}`);
}

async function adminUser(id) {
  const reply = await real(`${SB}/auth/v1/admin/users/${id}`, { headers: ADMIN });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
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
  ochk.ruleStatus = 503;
  ochk.rule = { ok: false };
  handler = await route();
  const noRule = await call(handler, { token: token({ aud: "http://127.0.0.1:8844" }).jwt });
  check("a rule that cannot be read lets nobody in", noRule.status === 503, `${noRule.status}`);
  ochk.ruleStatus = 200;
  ochk.rule = { ok: true, require_bond: null };

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

  // Without the project's key or secret, nobody signs in with orangecheck.
  const offered = (await whoIs(undefined)).body?.orangecheck;
  check("/api/account says orangecheck takes a token here, offered to a flagged tab only", offered?.ready === true
    && offered?.everyone === false, JSON.stringify(offered));
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
  let gone = 0;
  for (const id of made) {
    const reply = await real(`${SB}/auth/v1/admin/users/${id}`, { method: "DELETE", headers: ADMIN });
    if (reply.ok || reply.status === 404) gone += 1;
  }
  console.log(`orangecheck_check: ${made.size} accounts made, ${gone} deleted`);
  console.log(`orangecheck_check: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}
