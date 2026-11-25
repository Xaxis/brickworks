// Signing in with orangecheck, counted per orangecheck id and per network
// (signin5, 2026-11-25: signreview2 SR3), checked on api/orangecheck.js's own
// handler against the real project's counters (oc_may_try, way_may_try):
//
//   set -a; . ./.env; set +a
//   node --experimental-test-module-mocks tools/web/oc_often_check.mjs
//
// orangecheck's token check and spend are stood in for (each token is the
// orangecheck id it names), and so is everything after the counts: the
// account an id signs in to is a made-up one, and reading it from Supabase
// fails, so a sign-in that gets past the counts answers 502 and nothing is
// made, minted or kept. One counted out answers 429.
//
//   1. One orangecheck id: 5 sign-ins in a quarter-hour from 5 networks get
//      past the count; the 6th, from a 6th network, is refused in words.
//   2. Another id, from where the first was refused: past the count.
//   3. A network is an IPv6 /64, as Google's and GitHub's are counted
//      (api/_ways.js networkOf): 20 sign-ins from 20 addresses of one /64,
//      each its own id, get past; the 21st, from a 21st address, is
//      refused; another /64's is not.
// Each run counts under ids and networks of its own (198.18.0.0/15 and
// 2001:db8::/32, set aside for tests), so runs never meet.
import { mock } from "node:test";
import { randomBytes, randomUUID } from "node:crypto";

const api = (file) => new URL(`../../api/${file}`, import.meta.url).href;
const realDb = await import(api("_db.js"));
const realOc = await import(api("_oc.js"));
const COUNTS = new Set(["rpc/oc_may_try", "rpc/way_may_try"]);
// The owner's server-errors note each 502 asks to write (api/_noted.js):
// refused here, as everything but the counts is.
const REFUSED = new Set(["owner_notify_errors"]);
const asked = [];
mock.module(api("_db.js"), {
  exports: {
    ...realDb,
    db: async (path, init) => {
      asked.push(path);
      if (COUNTS.has(path)) return realDb.db(path, init);
      if (path === "rpc/oc_account_of") return "00000000-0000-4000-8000-0000000c0c0c";
      throw new Error(`oc_often_check: ${path} is not asked here`);
    },
    reach: async (what) => {
      throw new Error(`oc_often_check: ${what} is not asked here`);
    },
  },
});
mock.module(api("_oc.js"), {
  exports: {
    ...realOc,
    ocConfigured: () => true,
    checkToken: async (token) => {
      const now = Math.floor(Date.now() / 1000);
      return { session: { did_oc: token, jti: randomUUID(), rh: "stand-in", aud: "stand-in", iat: now, exp: now + 300 } };
    },
    spendToken: async () => true,
  },
});
const { default: handler } = await import(api("orangecheck.js"));

let failed = 0;
const check = (what, ok, detail = "") => {
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${ok || !detail ? "" : `: ${String(detail).slice(0, 600)}`}`);
};
const hex = (n) => randomBytes(n).toString("hex");
const did = () => `did:oc:${hex(16)}`;
const v4 = () => `198.${18 + (randomBytes(1)[0] & 1)}.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;

/// A sign-in with [token] from [from]: {status, error}.
async function signIn(token, from) {
  const response = { statusCode: 200, body: null, status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; return this; }, setHeader() { return this; } };
  await handler({ method: "POST", query: { op: "signin" }, headers: { "x-forwarded-for": from }, body: { token } }, response);
  return { status: response.statusCode, error: response.body?.error || "" };
}
const PAST = 502;
const OFTEN = "Too many sign-ins with this orangecheck account just now. Wait a few minutes and try again.";

// 1. and 2.
const one = did();
const tries = [];
for (let n = 0; n < 6; n += 1) tries.push(await signIn(one, v4()));
check("1. one orangecheck id: 5 sign-ins from 5 networks get past the count, the 6th is refused in words",
  tries.slice(0, 5).every((t) => t.status === PAST) && tries[5].status === 429 && tries[5].error === OFTEN,
  JSON.stringify(tries));
const other = await signIn(did(), v4());
check("2. another id: past the count", other.status === PAST, JSON.stringify(other));

// 3.
const net = `2001:db8:${hex(2)}:${hex(2)}`;
const crowd = [];
for (let n = 1; n <= 21; n += 1) crowd.push(await signIn(did(), `${net}::${n.toString(16)}`));
const elsewhere = await signIn(did(), `2001:db8:${hex(2)}:${hex(2)}::1`);
check("3. one IPv6 /64 is one network: 20 of its addresses get past, the 21st is refused; another /64's is not",
  crowd.slice(0, 20).every((t) => t.status === PAST) && crowd[20].status === 429 && /from here/.test(crowd[20].error)
  && elsewhere.status === PAST, JSON.stringify(crowd.slice(18)) + JSON.stringify(elsewhere));
check("nothing asked but the counts and the account's id (the errors' note refused)",
  asked.every((path) => COUNTS.has(path) || REFUSED.has(path) || path === "rpc/oc_account_of"), [...new Set(asked)].join(" "));
console.log(`oc_often_check: ${failed ? `${failed} failed` : "all passed"}`);
process.exit(failed ? 1 : 0);
