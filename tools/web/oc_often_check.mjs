// Signing in with orangecheck, counted per orangecheck id alone, right
// before Supabase's verify would be spent, and never per network (signin6,
// 2026-11-25: signreview2 SR3, signreview3 R3), checked on
// api/orangecheck.js's own handler against the real project's counter
// (way_may_try):
//
//   set -a; . ./.env; set +a
//   node --experimental-test-module-mocks tools/web/oc_often_check.mjs
//
// orangecheck's token check and spend are stood in for (each token is the
// orangecheck id it names; one starting "junk" does not check out), and so
// is everything around the count: the account an id signs in to is a
// made-up one, read and given a link by stand-ins, and the verify that
// would mint its session fails, so a sign-in that gets past the count
// answers 502 and nothing is made, minted or kept. One counted out answers
// 429, and asks no verify.
//
//   1. One orangecheck id: as many sign-ins in a quarter-hour as a Google or
//      GitHub account (api/_ways.js LIMITS, 10), each from a network of its
//      own, get to the verify; the next, from another, is refused in words,
//      and no verify is asked for it.
//   2. Another id, from where the first was refused: past the count.
//   3. Junk from one network, 40 tokens that do not check out: refused,
//      with nothing asked of the database, and a real sign-in there next
//      gets past (signreview3 O).
//   4. No network is counted: 25 ids from 25 addresses of one IPv6 /64,
//      and 25 from one IPv4 address, all get past.
// Each run counts under ids of its own, so runs never meet.
import { mock } from "node:test";
import { randomBytes, randomUUID } from "node:crypto";

const api = (file) => new URL(`../../api/${file}`, import.meta.url).href;
const realDb = await import(api("_db.js"));
const realOc = await import(api("_oc.js"));
const COUNT = "rpc/way_may_try";
const ACCOUNT = "00000000-0000-4000-8000-0000000c0c0c";
// The owner's server-errors note each 502 asks to write (api/_noted.js):
// refused here, as everything but the count is.
const REFUSED = new Set(["owner_notify_errors"]);
const asked = [];
let verifies = 0;
const json = (body) => new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
mock.module(api("_db.js"), {
  exports: {
    ...realDb,
    db: async (path, init) => {
      asked.push(path);
      if (path === COUNT) return realDb.db(path, init);
      if (path === "rpc/oc_account_of") return ACCOUNT;
      throw new Error(`oc_often_check: ${path} is not asked here`);
    },
    reach: async (what) => {
      asked.push(what);
      if (what === "auth GET admin/users") {
        return json({ id: ACCOUNT, email: "oc-often@resend.dev", app_metadata: { orangecheck: true } });
      }
      if (what === "auth POST admin/generate_link") return json({ hashed_token: "stand-in", id: ACCOUNT, user: { id: ACCOUNT } });
      if (what === "auth POST verify") verifies += 1;
      throw new Error(`oc_often_check: ${what} is not asked here`);
    },
  },
});
mock.module(api("_oc.js"), {
  exports: {
    ...realOc,
    ocConfigured: () => true,
    checkToken: async (token) => {
      if (token.startsWith("junk")) return { status: 401, error: "That sign-in did not check out. Sign in with orangecheck again." };
      const now = Math.floor(Date.now() / 1000);
      return { session: { did_oc: token, jti: randomUUID(), rh: "stand-in", aud: "stand-in", iat: now, exp: now + 300 } };
    },
    spendToken: async () => true,
  },
});
const { default: handler } = await import(api("orangecheck.js"));
const { LIMITS } = await import(api("_ways.js"));

let failed = 0;
const check = (what, ok, detail = "") => {
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${ok || !detail ? "" : `: ${String(detail).slice(0, 600)}`}`);
};
const hex = (n) => randomBytes(n).toString("hex");
const did = () => `did:oc:${hex(16)}`;
const v4 = () => `198.${18 + (randomBytes(1)[0] & 1)}.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;

/// A sign-in with [token] from [from]: {status, error, verified}, verified
/// the verifies it asked.
async function signIn(token, from) {
  const response = { statusCode: 200, body: null, status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; return this; }, setHeader() { return this; } };
  const before = verifies;
  await handler({ method: "POST", query: { op: "signin" }, headers: { "x-forwarded-for": from }, body: { token } }, response);
  return { status: response.statusCode, error: response.body?.error || "", verified: verifies - before };
}
const PAST = 502;
const OFTEN = "Too many sign-ins with this orangecheck account just now. Wait a few minutes and try again.";
const past = (t) => t.status === PAST && t.verified === 1;

// 1. and 2.
const one = did();
const tries = [];
for (let n = 0; n <= LIMITS.account; n += 1) tries.push(await signIn(one, v4()));
const over = tries[LIMITS.account];
check(`1. one orangecheck id: ${LIMITS.account} sign-ins from ${LIMITS.account} networks get to the verify, the next is refused in words and asks none`,
  tries.slice(0, LIMITS.account).every(past) && over.status === 429 && over.error === OFTEN && over.verified === 0,
  JSON.stringify(tries));
const other = await signIn(did(), v4());
check("2. another id: past the count", past(other), JSON.stringify(other));

// 3.
const there = v4();
const askedBefore = asked.length;
const junk = [];
for (let n = 0; n < 40; n += 1) junk.push(await signIn(`junk${hex(8)}`, there));
const junkAsked = asked.slice(askedBefore);
const after = await signIn(did(), there);
check("3. 40 junk tokens from one network: each refused as not checking out, nothing asked of the database; a real sign-in there gets past",
  junk.every((t) => t.status === 401 && t.verified === 0) && junkAsked.length === 0 && past(after),
  `${JSON.stringify(junk.slice(-2))} asked ${junkAsked.join(" ")} then ${JSON.stringify(after)}`);

// 4.
const net = `2001:db8:${hex(2)}:${hex(2)}`;
const crowd = [];
for (let n = 1; n <= 25; n += 1) crowd.push(await signIn(did(), `${net}::${n.toString(16)}`));
const shared = v4();
const home = [];
for (let n = 1; n <= 25; n += 1) home.push(await signIn(did(), shared));
check("4. no network is counted: 25 ids from one IPv6 /64 and 25 from one IPv4 address, all past",
  crowd.every(past) && home.every(past), JSON.stringify([...crowd, ...home].filter((t) => !past(t)).slice(0, 3)));
check("nothing asked but the count, the account, its link and the verify (the errors' note refused); never oc_may_try",
  asked.every((path) => path === COUNT || REFUSED.has(path) || path === "rpc/oc_account_of" || path.startsWith("auth "))
  && !asked.includes("rpc/oc_may_try"), [...new Set(asked)].join(" "));
console.log(`oc_often_check: ${failed ? `${failed} failed` : "all passed"}`);
process.exit(failed ? 1 : 0);
