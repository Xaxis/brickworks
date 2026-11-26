// signin7: the one rule (api/_oc.js stepUp) on the routes signreview4's scripts do not drive, against a
// relay of this tree with Google and GitHub stood in for (--ways-stand-in) and a throwaway as its owner
// (--owner), the real Supabase project behind it. Throwaway accounts only; each one is deleted at the end.
//
//   --r      the relay        --owner  the relay's owner (a throwaway at resend.dev)   --out  pictures
//
//   A. A session Google started links orangecheck, and unlinks it: both refused, 403 fresh:false, before
//      anything is asked of orangecheck.
//   B. An account GitHub made just now answers the age question under 13 from GitHub's session: deleted
//      there and then (a new account's answer needs no code).
//   C. The console, from an owner's session signed in more than five minutes ago: Delete an account and
//      a sign-in switch, both refused 403 fresh:false, the account still there; signed in again by code,
//      the delete goes through.
//   D. Settings, signed in more than five minutes ago, Link again for Google (unlinked): a code sent and
//      asked for in #ways-code, "Confirm it is you, then press Link again."; the code typed, "Thank you.
//      Now press Link again."; Link again pressed: "Google signs you in here again.", and the account's
//      Google is "never" (linked again, as never used).
// Supabase verifies spent from this box: 3 (two ways' sign-ins and the code typed in D).
import { mkdirSync } from "node:fs";
import path from "node:path";
import { createHash, randomBytes } from "node:crypto";
import { launch } from "../../../tools/web/browser.mjs";
import { codeFor } from "../../../tools/web/ways_stand_in.mjs";
import { deleteAccount, mintCode, mintSession, signInContext } from "../../../tools/web/session.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const R = arg("r").replace(/\/+$/, "");
const OWNER = arg("owner");
const out = arg("out", "/tmp/rule7");
mkdirSync(out, { recursive: true });
const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-si7-${name}-${tag}@resend.dev`;
const made = [OWNER];
let passed = 0;
let failed = 0;
const check = (what, ok, detail = "") => {
  if (ok) passed += 1; else failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"} ${what}${detail ? `: ${String(detail).slice(0, 400)}` : ""}`);
};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");
const challengeOf = (verifier) => createHash("sha256").update(verifier).digest("base64url");
const network = () => `198.18.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
const qs = (o) => new URLSearchParams(o).toString();
const cookieNamed = (cookies, name) => (cookies.find((one) => one.startsWith(`${name}=`)) || "").split(";")[0];
async function call(pathname, { method = "GET", token = "", body, cookie = "", from = "" } = {}) {
  const headers = { ...(token ? { authorization: `Bearer ${token}` } : {}), ...(cookie ? { cookie } : {}),
    ...(from ? { "x-forwarded-for": from } : {}), ...(body !== undefined ? { "content-type": "application/json" } : {}) };
  const reply = await fetch(`${R}${pathname}`, { method, redirect: "manual", headers, body: body === undefined ? undefined : JSON.stringify(body) });
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
async function userOf(email) {
  const reply = await fetch(`${SB}/auth/v1/admin/users?${qs({ filter: email, per_page: "5" })}`, { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  return ((await reply.json()).users || []).find((u) => String(u.email || "").toLowerCase() === email.toLowerCase()) || null;
}
const refusedFresh = (one) => one.status === 403 && one.json?.fresh === false;

let browser = null;
try {
  if (!R || !/@resend\.dev$/.test(OWNER)) throw new Error("--r and a throwaway --owner at resend.dev, please");
  const started = Date.now();
  // C's owner and its account to delete, and D's person, all signed in now (more than five minutes before
  // they act).
  const boss = await mintSession(OWNER, { age: true });
  const T = address("target");
  made.push(T);
  await mintSession(T, { age: true });
  const target = await userOf(T);
  const P = address("link");
  made.push(P);
  const code = await mintSession(P, { age: true });

  console.log("A. orangecheck's link and unlink from a session Google started");
  const g = await viaWay("google", { email: P, verified: true, hd: "resend.dev" });
  if (!g.access_token) throw new Error(`A: Google did not sign in: ${g.failed}`);
  const link = await call("/api/orangecheck?op=link", { method: "POST", token: g.access_token, body: { token: "made-up.orangecheck.token" } });
  check("A1. Google's session links orangecheck: refused, a code asked", refusedFresh(link), `${link.status} ${link.text.slice(0, 160)}`);
  const unlink = await call("/api/orangecheck?op=unlink", { method: "POST", token: g.access_token, body: {} });
  check("A2. Google's session unlinks orangecheck: refused, a code asked", refusedFresh(unlink), `${unlink.status} ${unlink.text.slice(0, 160)}`);

  console.log("B. an account GitHub made just now answers the age question under 13");
  const Q = address("young");
  made.push(Q);
  const h = await viaWay("github", { email: Q, verified: true });
  if (!h.access_token) throw new Error(`B: GitHub did not sign in: ${h.failed}`);
  const year = new Date().getUTCFullYear() - 9;
  const young = await call("/api/account?op=age", { method: "POST", token: h.access_token, body: { month: 1, year } });
  check("B1. deleted there and then, no code asked", young.status === 403 && young.json?.deleted === true && !(await userOf(Q)),
    `new account ${h.new_account}; age ${young.status} ${young.text.slice(0, 160)}`);

  // D's Google unlinked from P's code session, while it is fresh.
  const off = await call("/api/otp?op=ways", { method: "POST", token: code.access_token, body: { with: "google", on: false } });
  if (off.json?.google !== "off") throw new Error(`D: Google was not unlinked: ${off.status} ${off.text.slice(0, 160)}`);
  browser = await launch({ signedOut: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, colorScheme: "light",
    extraHTTPHeaders: { "x-forwarded-for": network() }, serviceWorkers: "block" });
  await signInContext(context, P);

  const rest = 310_000 - (Date.now() - started);
  console.log(`-- waiting ${Math.round(rest / 1000)} s, so that every session above is more than five minutes old`);
  await wait(rest);

  console.log("C. the console, from an owner's session signed in more than five minutes ago");
  const del = await call(`/api/admin?op=delete_account&account=${target.id}`, { method: "POST", token: boss.access_token,
    body: { confirm: T, reason: "signin7 check" } });
  const sw = await call("/api/admin?op=sign_in_switch", { method: "POST", token: boss.access_token, body: { with: "google", on: false } });
  check("C1. Delete an account: refused, a code asked; the account still there", refusedFresh(del) && Boolean(await userOf(T)),
    `${del.status} ${del.text.slice(0, 200)}`);
  check("C2. a sign-in switch: refused, a code asked", refusedFresh(sw), `${sw.status} ${sw.text.slice(0, 200)}`);

  console.log("D. Settings' Link again, signed in more than five minutes ago");
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (trouble) => errors.push(trouble.message));
  await page.goto(`${R}/settings#ways-part`, { waitUntil: "domcontentloaded" });
  const again = page.locator("#ways li", { hasText: "Google" }).getByRole("button", { name: "Link again" });
  await again.waitFor({ timeout: 30000 });
  await again.click();
  await page.locator("#ways-code").waitFor({ state: "visible", timeout: 30000 });
  const asked = await page.locator("#ways-status").textContent();
  const to = await page.locator("#ways-code-said").textContent();
  await page.screenshot({ path: path.join(out, "d1_code_asked.png") });
  check("D1. Link again: a code sent and asked for, in words", asked === "Confirm it is you, then press Link again."
    && to.includes(P), `${asked} | ${to}`);
  const typed = await mintCode(P, { welcome: false });
  await page.locator("#ways-code .code-boxes input").first().fill(typed);
  await page.waitForFunction(() => document.querySelector("#ways-status")?.textContent === "Thank you. Now press Link again.",
    null, { timeout: 30000 }).catch(() => null);
  const thanked = await page.locator("#ways-status").textContent();
  const hidden = await page.locator("#ways-code").isHidden();
  const focused = await page.evaluate(() => document.activeElement?.textContent || "");
  await page.screenshot({ path: path.join(out, "d2_thanked.png") });
  check("D2. the code typed: thanked, the form gone, Link again focused", thanked === "Thank you. Now press Link again."
    && hidden && focused === "Link again", `${thanked} | hidden ${hidden} | focus ${focused}`);
  await again.click();
  await page.waitForFunction(() => /signs you in here again/.test(document.querySelector("#ways-status")?.textContent || ""),
    null, { timeout: 30000 }).catch(() => null);
  const done = await page.locator("#ways-status").textContent();
  const now = await call("/api/otp?op=ways", { token: (await mintSession(P, { age: false, welcome: false })).access_token });
  await page.screenshot({ path: path.join(out, "d3_linked.png") });
  check("D3. Link again once more: linked again, as never used", done === "Google signs you in here again." && now.json?.google === "never",
    `${done} | ${JSON.stringify(now.json)}`);
  check("D4. no error on the page", errors.length === 0, errors.join(" | "));

  console.log("C. again, the owner signed in by code just now");
  const fresh = await mintSession(OWNER, { age: false, welcome: false });
  const del2 = await call(`/api/admin?op=delete_account&account=${target.id}`, { method: "POST", token: fresh.access_token,
    body: { confirm: T, reason: "signin7 check" } });
  check("C3. Delete an account: deleted, and gone from Supabase", del2.status === 200 && !(await userOf(T)), `${del2.status} ${del2.text.slice(0, 160)}`);
} catch (trouble) {
  check("the check ran to its end", false, trouble?.stack || trouble);
} finally {
  await browser?.close().catch(() => null);
  let left = 0;
  for (const one of made) {
    await deleteAccount(one).catch(() => null);
    if (await userOf(one).catch(() => null)) left += 1;
  }
  console.log(`  --   accounts named: ${made.length}, left after the clean-up: ${left}`);
  console.log(`rule7: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}
