// Prove signing in on a deployed site, as a person does it.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/account_flow.mjs --url=<a preview>/app --out=shots/account
//   node tools/web/account_flow.mjs --url=https://brickworks.diy/app --out=shots/account
//
// A clean browser, so a first visit: the sign-in screen must be all there
// is — a click on the model places nothing, a key does nothing. Then the
// way a person signs in: an address typed, Email me a code pressed (the
// deployment really sends one, to a Resend test address that delivers it
// nowhere), and the code typed and Sign in pressed. The code is minted
// here with Supabase's admin API, because a test has no inbox; minting it
// replaces the one that was emailed, so the one typed is the only one
// that works. Then a reload must find them still signed in, let in at
// once with no sign-in screen on the way while the kept session is
// renewed behind the model (walk256's A17); the admin
// page must refuse their account; Account on the bar must say who they
// are; and Sign out must bring the screen back. The browser's console must
// carry no refusal from the security policy throughout.
//
// --master also signs in as MASTER_EMAIL (minted the same way: no email is
// sent) and checks the admin page lists the accounts. It signs the owner's
// account in, in a throwaway browser, so it is not the default.
//
// A preview's functions sit behind Vercel's login, so BW_BYPASS goes to the
// page as a cookie for that domain, never anywhere else.
import { launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/account";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const origin = new URL(url).origin;
const email = `delivered+bwflow${Date.now()}@resend.dev`;

let failures = 0;
const check = (ok, what) => { console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`); if (!ok) failures += 1; };

const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
const refusals = [];
const page = await context.newPage();
const watch = (p) => p.on("console", (m) => {
  if (/Content Security Policy|Refused to connect/i.test(m.text())) refusals.push(m.text().slice(0, 200));
});
watch(page);

const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;

async function account(p = page) {
  return p.evaluate(() => window.brickworksAccount || null);
}

async function until(test, what, seconds = 300, p = page) {
  for (let i = 0; i < seconds * 2; i++) {
    const state = await account(p);
    if (state && test(state)) return state;
    await p.waitForTimeout(500);
  }
  await p.screenshot({ path: `${out}/never_${what.replace(/\W+/g, "_")}.png` }).catch(() => {});
  throw new Error(`never ${what}; last said: ${JSON.stringify(await account(p))}`);
}

async function controls(p = page) {
  return p.evaluate(() => window.brickworksControls || {});
}

async function click(name, p = page) {
  for (let tries = 0; tries < 600; tries++) {
    const where = (await controls(p))[name];
    if (where) return p.mouse.click(where.x, where.y);
    await p.waitForTimeout(500);
  }
  await p.screenshot({ path: `${out}/never_showed_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed "${name}"`);
}

async function shot(name, p = page) {
  await p.screenshot({ path: `${out}/${name}.png`, timeout: 120000 }).catch(() => {});
}

try {
  console.log(`a first visit to ${url}`);
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  const gated = await until((s) => s.state === "signed_out" && s.gated, "showed the sign-in screen");
  check(gated.gated, "the sign-in screen is up on a first visit");
  // The page is told where a control is once two of the app's reports agree:
  // the form appears as the screen stops checking, a moment before that.
  for (let i = 0; i < 60 && !(await controls()).signin_email; i++) await page.waitForTimeout(500);
  const offered = Object.keys(await controls());
  check(offered.length > 0 && offered.every((name) => name.startsWith("signin_")),
    `nothing but the sign-in form can be pressed: ${offered.join(", ")}`);
  // Offered to everybody, as the deployment says (api/_oc_config.js, the
  // one switch); off, to nobody.
  const offer = (await (await fetch(new URL("/api/account", url), {
    headers: bypass ? { "x-vercel-protection-bypass": bypass } : {} })).json()).orangecheck || {};
  check(offered.includes("signin_orangecheck") === Boolean(offer.everyone),
    offer.everyone ? "Sign in with orangecheck is offered beside the email" : "Sign in with orangecheck is offered to nobody, as the deployment says");
  await shot("1_first_visit");

  // Sign in with orangecheck goes to the site's sign-in, which says it
  // brings the person back (web/profile.js): the app's page cannot hear
  // orangecheck's window. Looked at in a page of its own.
  if (offer.everyone) {
    const other = await context.newPage();
    await other.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
    await until((s) => s.state === "signed_out" && s.gated, "showed the sign-in screen again", 300, other);
    for (let i = 0; i < 60 && !(await controls(other)).signin_orangecheck; i++) await other.waitForTimeout(500);
    await click("signin_orangecheck", other);
    await other.waitForURL(/\/profile\?then=%2Fapp/, { timeout: 60000 }).catch(() => null);
    const there = await other.locator("dialog.sign-in #oc-sign-in").waitFor({ state: "visible", timeout: 60000 }).then(() => true, () => false);
    check(there && /\/profile\?then=%2Fapp/.test(other.url()),
      `...which opens the site's sign-in, with Sign in with orangecheck, to come back to the app: ${other.url().replace(/[?&]x-vercel[^&]*/g, "")}`);
    await shot("1b_orangecheck_on_the_site", other);
    await other.close();
  }

  // The builder behind it cannot be used: a click where the model is, and
  // the keys that would change it.
  const bricks = await page.evaluate(() => window.brickworksBricks);
  const box = page.viewportSize();
  await page.mouse.click(Math.round(box.width / 2), Math.round(box.height * 0.7));
  for (const key of ["Delete", "KeyN", "KeyR", "Control+KeyZ"]) await page.keyboard.press(key);
  await page.waitForTimeout(1500);
  check(await page.evaluate(() => window.brickworksBricks) === bricks
      && (await account()).gated,
    `a click on the model and keys change nothing behind it (${bricks} bricks)`);

  console.log("signing in");
  await click("signin_email");
  await page.keyboard.type("not-an-address");
  await click("signin_send");
  await page.waitForTimeout(1500);
  await shot("2_not_an_address");
  check((await controls()).signin_email && !(await controls()).signin_code,
    "an address that is not one stays on the address");

  await click("signin_email");
  await page.keyboard.press("Control+A");
  await page.keyboard.type(email);
  // The keys reach the field a frame at a time, and a click straight after
  // the last one can land first: Email me a code then saw the old text.
  await page.waitForTimeout(1500);
  await click("signin_send");
  for (let i = 0; i < 120 && !(await controls()).signin_code; i++) await page.waitForTimeout(500);
  check(Boolean((await controls()).signin_code),
    "Email me a code: the deployment sends one, and the form asks for it");
  await shot("3_check_your_email");

  await click("signin_code");
  await page.keyboard.type("000000");
  await click("signin_go");
  await page.waitForTimeout(4000);
  check((await account()).gated, "a wrong code does not let anyone in");
  await shot("4_wrong_code");

  const code = await mintCode(email);
  await click("signin_code");
  await page.keyboard.press("Control+A");
  await page.keyboard.type(code);
  await page.waitForTimeout(1500);
  await click("signin_go");
  // Supabase lets one machine check so many codes in five minutes, and
  // every flow and agent on this box shares that count: m165's preview held
  // twice on "Too many attempts just now" with the right code in the field
  // (2026-10-24). The form keeps the code after a refusal, so the same code
  // is pressed again once the limit has had a minute; a wrong code still
  // fails all three tries.
  const signedIn = (s) => s.state === "signed_in" && (!s.gated || s.age_ask);
  let inside = await until(signedIn, "signed in", 45).catch(() => null);
  for (let again = 1; again <= 2 && !inside; again++) {
    console.log(`  --    not in after try ${again}; waiting out the code-check limit, then Sign in again`);
    await page.waitForTimeout(65000);
    await click("signin_go");
    inside = await until(signedIn, "signed in", 45).catch(() => null);
  }
  inside ||= await until(signedIn, "signed in", 5);
  if (inside.age_ask) {
    // The age question (supabase/trust.sql), once that is applied: asked
    // once, in the sign-in screen, and answered 13 or over here
    // (tools/web/age_flow.mjs is about the question itself).
    for (let i = 0; i < 60 && !(await controls()).age_go; i++) await page.waitForTimeout(500);
    check(Boolean((await controls()).age_go), "a new account is asked its age once, in the sign-in screen");
    // Laid out a frame after it is first told, and keys reach the field a
    // frame at a time: a pause before each, as for the address above.
    await page.waitForTimeout(1500);
    await click("age_month_3");
    await click("age_year");
    await page.keyboard.type(String(new Date().getUTCFullYear() - 30));
    await page.waitForTimeout(1500);
    await click("age_go");
    inside = await until((s) => s.state === "signed_in" && !s.gated, "let in after the age question");
  }
  check(inside.email === email, `the code signs in, and the screen goes: ${inside.email}`);
  await page.waitForTimeout(2000);
  await shot("5_signed_in");
  const kept = await page.evaluate((k) => JSON.parse(localStorage.getItem(k) || "{}"), STORAGE_KEY);
  check(Boolean(kept.refresh_token) && kept.email === email && !kept.access_token,
    "the browser keeps the session: a refresh token and the address, not the access token");

  console.log("staying signed in");
  await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
  // Let in at once from what the browser kept, and renewed behind the
  // model (Account.renewing): the sign-in screen never comes up on the
  // way. walk256's A17 sat on "Signing you in…" about 18 s at every load.
  let screened = false;
  let back = null;
  for (let i = 0; i < 600 && !back; i++) {
    const s = await account().catch(() => null);
    if (s && s.gated) screened = true;
    if (s && s.state !== "checking" && s.renewing !== true) back = s;
    else await page.waitForTimeout(200);
  }
  back ||= await until((s) => s.state !== "checking" && s.renewing !== true, "worked out who is here after a reload");
  check(back.state === "signed_in" && !back.gated && back.email === email,
    `a reload finds them still signed in, with no sign-in screen: ${back.state}`);
  check(!screened, "...and the sign-in screen never came up while the kept session was renewed");
  await page.waitForTimeout(2000);
  await shot("6_after_reload");

  console.log("the admin page");
  const admin = await context.newPage();
  watch(admin);
  await admin.goto(`${origin}/admin`, { waitUntil: "domcontentloaded", timeout: 60000 });
  await admin.waitForFunction(() => !/Checking/.test(document.getElementById("gate-note").textContent),
    undefined, { timeout: 30000 }).catch(() => {});
  const refused = await admin.evaluate(() => document.getElementById("gate-note").textContent);
  check(/cannot see this page/.test(refused), `it is not theirs to see: "${refused}"`);
  await shot("7_admin_refused", admin);
  await admin.close();

  console.log("the account panel");
  await click("account");
  for (let i = 0; i < 40 && !(await controls()).sign_out; i++) await page.waitForTimeout(250);
  check(Boolean((await controls()).sign_out), "Account on the bar opens the panel, with Sign out");
  await page.waitForTimeout(800);
  await shot("8_account_panel");
  await click("sign_out");
  const outside = await until((s) => s.state === "signed_out" && s.gated, "signed out");
  check(outside.gated && !outside.email, "Sign out brings the sign-in screen back");
  const left = await page.evaluate((k) => localStorage.getItem(k), STORAGE_KEY);
  check(left === null, "...and the session is gone from the browser");
  await page.waitForTimeout(1000);
  await shot("9_signed_out");

  if (args.master) {
    console.log("the owner's account");
    const { kept: owner } = await mintSession(process.env.MASTER_EMAIL);
    const theirs = await context.newPage();
    await theirs.addInitScript(([k, v]) => localStorage.setItem(k, v), [STORAGE_KEY, JSON.stringify(owner)]);
    await theirs.goto(`${origin}/admin`, { waitUntil: "domcontentloaded", timeout: 60000 });
    await theirs.waitForSelector("#view:not(.hide)", { timeout: 30000 }).catch(() => {});
    const listed = await theirs.evaluate(() => ({
      shown: !document.getElementById("view").classList.contains("hide"),
      accounts: document.getElementById("n-accounts").textContent,
      rows: document.querySelectorAll("#people tr").length,
    }));
    check(listed.shown && listed.rows > 0, `the owner sees the accounts: ${listed.accounts}, ${listed.rows} rows`);
    await shot("10_admin_owner", theirs);
    await theirs.evaluate((k) => localStorage.removeItem(k), STORAGE_KEY);
  }
} catch (trouble) {
  failures += 1;
  console.log(`  FAIL  ${trouble.message}`);
  await shot("failed");
}

check(refusals.length === 0, `no refusals from the security policy${refusals.length ? ": " + refusals[0] : ""}`);
await browser.close();
const removed = await deleteAccount(email).catch(() => false);
console.log(`  (throwaway account ${removed ? "removed" : "not found to remove"})`);
console.log(failures ? `${failures} failure(s)` : "signing in works on this deployment");
process.exit(failures ? 1 : 0);
