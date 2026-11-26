// signreview4: what bounds a flood of real provider accounts now that nothing is counted per network
// (signin6). From one network, K Google identities sign in T times each, against a relay with
// fault4.mjs answering Supabase's verify itself (429), so no verify is spent: the count is of how
// many sign-ins reach the verify, which in production each spend one of the server's shared 90 a
// quarter-hour. Then each identity once more, which its own count refuses.
//
//   node flood4.mjs --r=http://127.0.0.1:12226 --rules=/abs/rules.json --log=/abs/fault.log [--k=12] [--t=10]
import { createHash, randomBytes } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount } from "../../../tools/web/session.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R = arg("r").replace(/\/+$/, "");
const RULES = arg("rules");
const LOG = arg("log");
const K = Number(arg("k", "12"));
const T = Number(arg("t", "10"));
const tag = randomBytes(3).toString("hex");
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const qs = (o) => new URLSearchParams(o).toString();
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];
const reached = () => readFileSync(LOG, "utf8").split("\n").filter((l) => / verify429 /.test(l)).length;
const from = `198.18.${randomBytes(1)[0]}.7`;

async function viaGoogle(email) {
  const verifier = b64url(randomBytes(32));
  const st = await fetch(`${R}/auth/google?${qs({ then: "/gallery", take: challengeOf(verifier) })}`,
    { redirect: "manual", headers: { "x-forwarded-for": from } });
  const location = st.headers.get("location") || "";
  const state = location.startsWith("https://") ? new URL(location).searchParams.get("state") : "";
  const cookie = cookieNamed(st.headers.getSetCookie?.() || [], "bw_way_google");
  const back = await fetch(`${R}/auth/callback/google?${qs({ code: codeFor(location, { email, verified: true, hd: "resend.dev" }), state })}`,
    { redirect: "manual", headers: { cookie, "x-forwarded-for": from } });
  return new URL(back.headers.get("location") || "/", "http://x").searchParams.get("failed") || "handed";
}

const made = [];
writeFileSync(RULES, JSON.stringify({ verify429: true }));
const before = reached();
const answers = {};
const t0 = Date.now();
try {
  for (let k = 0; k < K; k += 1) {
    const email = `delivered+bw-sr4-flood${k}-${tag}@resend.dev`;
    made.push(email);
    for (let t = 0; t < T; t += 1) {
      const why = await viaGoogle(email);
      answers[why] = (answers[why] || 0) + 1;
    }
  }
  const atVerify = reached() - before;
  const last = [];
  for (const email of made.slice(0, 3)) last.push(await viaGoogle(email));
  console.log(`  --      ${K} Google identities x ${T} sign-ins, one network, in ${Math.round((Date.now() - t0) / 1000)} s: `
    + `${JSON.stringify(answers)}; reached Supabase's verify: ${atVerify} (production's server has 30 at once, then 1 each 10 s)`);
  console.log(`  --      each identity's ${T + 1}th: ${last.join(", ")}`);
  const finding = atVerify >= K * T;
  console.log(`  ${finding ? "FINDING" : "ok     "} N1. one network, ${K} free provider accounts: every sign-in reaches the shared verify; `
    + `only each identity's own ${T} bound it (${Math.ceil(90 / T)} identities hold the server's whole quarter-hour, ${Math.ceil(30 / T)} its burst)`);
} finally {
  writeFileSync(RULES, "{}");
  let gone = 0;
  for (const email of made) if (await deleteAccount(email).catch(() => false)) gone += 1;
  console.log(`  --      accounts made ${made.length}, deleted ${gone}`);
}
