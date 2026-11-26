// signreview4: Delete account from a Google or GitHub session, against a relay of signin6's tree with Google
// and GitHub stood in for and the real Supabase project behind it. Throwaway accounts only: each one this
// deletes is its own, and the rest are deleted at the end.
//
//   --r  the stand-in relay
//
//   Y. a session GitHub started (an account GitHub made, as for anyone new), then one Google started: each
//      deletes the account with its address typed, and nothing else asked (an orangecheck session is asked
//      for an emailed code from the last five minutes first, api/account.js).
//   Z. the same from Google's session the moment its Unlink has ended it, still read as signed in.
// Supabase verifies spent from this box: 3.
import { createHash, randomBytes } from "node:crypto";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount, mintSession } from "../../../tools/web/session.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R = arg("r").replace(/\/+$/, "");
const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-sr4-${name}-${tag}@resend.dev`;
const made = [];
let findings = 0;
const say = (kind, what, detail = "") => {
  if (kind === "FINDING") findings += 1;
  console.log(`  ${kind.padEnd(7)} ${what}${detail ? `: ${String(detail).slice(0, 1000)}` : ""}`);
};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const network = () => `198.18.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
const qs = (o) => new URLSearchParams(o).toString();
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];
async function call(path, { method = "GET", token = "", body, cookie = "", from = "" } = {}) {
  const headers = { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(cookie ? { cookie } : {}),
    ...(from ? { "x-forwarded-for": from } : {}), ...(body !== undefined ? { "content-type": "application/json" } : {}) };
  const reply = await fetch(`${R}${path}`, { method, redirect: "manual", headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = null; }
  return { status: reply.status, json, text, location: reply.headers.get("location") || "", cookies: reply.headers.getSetCookie?.() || [] };
}
async function viaWay(name, who) {
  const from = network();
  const verifier = b64url(randomBytes(32));
  const st = await call(`/auth/${name}?${qs({ then: "/gallery", take: challengeOf(verifier) })}`, { from });
  const state = st.location.startsWith("https://") ? new URL(st.location).searchParams.get("state") : "";
  const back = await call(`/auth/callback/${name}?${qs({ code: codeFor(st.location, who), state })}`,
    { cookie: cookieNamed(st.cookies, `bw_way_${name}`), from });
  const take = cookieNamed(back.cookies, "bw_way_take");
  const took = take ? await call("/api/otp?op=way_take", { method: "POST", cookie: take, body: { code_verifier: verifier }, from }) : null;
  return took?.json?.access_token ? took.json : { failed: new URL(back.location || "/", "http://x").searchParams.get("failed") || "?" };
}
const exists = async (email) => {
  const reply = await fetch(`${SB}/auth/v1/admin/users?${qs({ filter: email, per_page: "5" })}`, { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  return ((await reply.json()).users || []).some((u) => String(u.email || "").toLowerCase() === email.toLowerCase());
};
const remove = (token, email) => call("/api/account?op=delete", { method: "POST", token, body: { confirm: email } });

try {
  console.log("Y. Delete account from a session Google or GitHub started");
  {
    const p = address("ghdel");
    made.push(p);
    const g = await viaWay("github", { email: p, verified: true });
    if (!g.access_token) throw new Error(`Y: GitHub did not sign in: ${g.failed}`);
    const gone = await remove(g.access_token, p);
    const still = await exists(p);
    say(gone.status === 200 && !still ? "FINDING" : "ok",
      "Y1. GitHub's session (an account GitHub made) deletes the account: its address typed, no emailed code asked",
      `new account ${g.new_account}; delete ${gone.status} ${gone.text.slice(0, 120)}; the account there now: ${still}`);
  }
  await wait(5000);
  {
    const p = address("gdel");
    made.push(p);
    await mintSession(p, { age: true });
    const g = await viaWay("google", { email: p, verified: true, hd: "resend.dev" });
    if (!g.access_token) throw new Error(`Y: Google did not sign in: ${g.failed}`);
    const gone = await remove(g.access_token, p);
    const still = await exists(p);
    say(gone.status === 200 && !still ? "FINDING" : "ok",
      "Y2. Google's session deletes an account a code made: its address typed, no emailed code asked",
      `delete ${gone.status} ${gone.text.slice(0, 120)}; the account there now: ${still}`);
  }
  await wait(5000);
  console.log("Z. Delete account from Google's session the moment its Unlink ended it");
  {
    const p = address("zdel");
    made.push(p);
    const own = await mintSession(p, { age: true });
    const g = await viaWay("google", { email: p, verified: true, hd: "resend.dev" });
    if (!g.access_token) throw new Error(`Z: Google did not sign in: ${g.failed}`);
    const S = g.access_token;
    let stop = false;
    let deleted = null;
    const loop = (async () => {
      while (!stop) {
        const seen = await call("/api/otp?op=ways", { token: S });
        if (!deleted && seen.status === 200 && seen.json?.google === "off") {
          const at = Date.now();
          const r = await remove(S, p);
          deleted = { status: r.status, text: r.text.slice(0, 120), at };
        }
        await wait(150);
      }
    })();
    await wait(1500);
    const un = await call("/api/otp?op=ways", { method: "POST", token: own.access_token, body: { with: "google", on: false } });
    const answered = Date.now();
    await wait(6000);
    stop = true;
    await loop;
    const still = await exists(p);
    say(deleted?.status === 200 && !still ? "FINDING" : "ok",
      "Z1. the intruder's Google session, ended by the person's Unlink but still read as signed in, deletes the account",
      `Unlink ${un.status}; delete ${deleted ? `${deleted.status} ${deleted.at - answered} ms after the Unlink answered ${deleted.text}` : "never sent"}; `
      + `the account there now: ${still}`);
  }
} catch (trouble) {
  say("FAIL", "the attack finished", String(trouble?.stack || trouble).slice(0, 900));
} finally {
  let left = 0;
  for (const email of made) if (await exists(email).catch(() => true)) { if (!(await deleteAccount(email).catch(() => false))) left += 1; }
  console.log(`  --      accounts named: ${made.length}, left after the clean-up: ${left}`);
}
console.log(`attack4b: ${findings} finding line(s)`);
