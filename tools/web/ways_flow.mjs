// Sign in with Google and GitHub in a browser, and the orangecheck line in
// place of the box (signin3, 2026-11-24), at 1280 and 390, against the
// relay with Google, GitHub and orangecheck's Connect stood in for
// (tools/web/ways_stand_in.mjs; ways_check.mjs proves the server's side):
//
//   set -a; . ./.env; set +a
//   OWNER=delivered+bw-ways-owner-$RANDOM@resend.dev
//   node tools/web/relay_server.mjs 11702 --ways-stand-in --owner=$OWNER &
//   node tools/web/ways_flow.mjs --url=http://127.0.0.1:11702 --owner=$OWNER --out=DIR
//
//   1. The sign-in dialog, signed out, on a page with more to it than the
//      sign-in (/gallery?sort=new): Sign in with Google and with GitHub,
//      each with its mark, as tall and wide as Email me a code; no box to
//      tick; one line that signing in also makes the orangecheck account,
//      with a link to what that is; nothing sideways.
//   2. Sign in with Google: to Google (the stand-in's page, here), and back
//      to the very page, signed in, the age question answered on the way:
//      no second account for an address a code signed in before.
//   3. Sign in with GitHub from /profile?sign-in, a new address: back on
//      /profile, signed in, asked its age first; answered, its orangecheck
//      account made.
//   4. Settings: How you sign in lists the code, Google and GitHub;
//      Unlink takes Google off and says the code still signs in; the
//      orangecheck part says the account signing in made.
//   5. A refused sign-in (an address Google has not verified) comes back to
//      the dialog with words for why.
//   6. The owner's console (the relay's --owner, a throwaway): Switches,
//      Sign in with Google and GitHub, each on with its steps hidden.
// Pictures of each at 1280 and 390 in --out. Every account is deleted.
import { mkdirSync } from "node:fs";
import path from "node:path";
import { randomBytes } from "node:crypto";
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { codeFor } from "./ways_stand_in.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const site = arg("url", "http://127.0.0.1:11702").replace(/\/+$/, "");
const owner = arg("owner");
const out = arg("out", "shots/ways");
mkdirSync(out, { recursive: true });
let failed = 0;
const check = (what, ok, detail = "") => {
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${ok || !detail ? "" : `: ${String(detail).slice(0, 600)}`}`);
};
const tag = randomBytes(3).toString("hex");
const address = (name) => `delivered+bw-ways-flow-${name}-${tag}@resend.dev`;
const made = [];
const errors = [];
const browser = await launch({ signedOut: true });

/// A context at [width] whose Google and GitHub are the stand-in's: their
/// sign-in page answers at once as [who] says, straight back to the callback.
async function context(width, who = {}) {
  const ctx = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, colorScheme: "light" });
  for (const host of ["https://accounts.google.com/**", "https://github.com/login/oauth/authorize**"]) {
    await ctx.route(host, (route) => {
      const asked = new URL(route.request().url());
      const name = asked.host === "github.com" ? "github" : "google";
      const back = new URL(asked.searchParams.get("redirect_uri"));
      back.searchParams.set("code", codeFor(asked.toString(), who[name] || { email: "nobody@example.com", verified: false }));
      back.searchParams.set("state", asked.searchParams.get("state"));
      return route.fulfill({ status: 302, headers: { location: back.toString() } });
    });
  }
  return ctx;
}

function listen(page, name) {
  page.on("pageerror", (trouble) => errors.push(`${name}: ${trouble.message}`));
  page.on("console", (message) => {
    if (message.type() === "error" && /Content Security Policy|Refused/.test(message.text())) errors.push(`${name}: ${message.text()}`);
  });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name) }).catch(() => null);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1);
const keptOf = (page) => page.evaluate((key) => {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch {
    return null;
  }
}, STORAGE_KEY);

async function openDialog(page, at = "/gallery?sort=new") {
  await page.goto(`${site}${at}`, { waitUntil: "domcontentloaded", timeout: 120000 });
  const opened = await page.evaluate(async () => {
    const account = await import("/account.js");
    account.askToSignIn();
    return true;
  });
  await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
  await page.locator("dialog.sign-in #way-google:not([hidden])").waitFor({ state: "visible", timeout: 15000 });
  return opened;
}

/// The age question, answered 30, where it is asked.
async function answerAge(page) {
  const age = page.locator("dialog.age");
  if (!(await age.waitFor({ state: "visible", timeout: 20000 }).then(() => true, () => false))) return false;
  await page.selectOption("#age-month", "1");
  await page.selectOption("#age-year", String(new Date().getUTCFullYear() - 30));
  await page.locator("#age-go").click();
  return true;
}

try {
  // 1.
  for (const width of [1280, 390]) {
    const ctx = await context(width);
    const page = await ctx.newPage();
    listen(page, `dialog ${width}`);
    await openDialog(page);
    await page.locator("dialog.sign-in #oc-made-line").waitFor({ state: "visible", timeout: 15000 });
    const looks = await page.evaluate(() => {
      const box = (el) => el?.getBoundingClientRect();
      const go = box(document.querySelector("dialog.sign-in button[type=submit]"));
      const way = (id) => {
        const el = document.getElementById(id);
        const r = box(el);
        return { shown: Boolean(el?.checkVisibility()), height: Math.round(r?.height || 0), width: Math.round(r?.width || 0),
          mark: Boolean(el?.querySelector("svg.way-mark")), words: el?.textContent.trim(), href: el?.getAttribute("href") };
      };
      const line = document.getElementById("oc-made-line");
      return { go: { height: Math.round(go.height), width: Math.round(go.width) }, google: way("way-google"), github: way("way-github"),
        boxes: document.querySelectorAll('dialog.sign-in input[type="checkbox"]').length,
        line: line?.textContent.trim(), link: line?.querySelector("a")?.getAttribute("href"), lineShown: Boolean(line?.checkVisibility()) };
    });
    check(`1. ${width}: Sign in with Google and with GitHub, each with its mark, as tall and wide as Email me a code`,
      looks.google.shown && looks.github.shown && looks.google.mark && looks.github.mark
      && looks.google.words === "Sign in with Google" && looks.github.words === "Sign in with GitHub"
      && looks.google.height === looks.go.height && looks.github.width === looks.go.width
      && looks.google.href === "/auth/google?then=%2Fgallery%3Fsort%3Dnew", JSON.stringify(looks));
    check(`1. ${width}: no box; one line that signing in makes the orangecheck account, with what that is`,
      looks.boxes === 0 && looks.lineShown && looks.line === "Signing in also makes your orangecheck account. What is that?"
      && looks.link === "/docs/account#orangecheck", JSON.stringify(looks));
    check(`1. ${width}: nothing sideways`, !(await sideways(page)));
    // Its open animation done before the picture, and still open after it
    // (run 1's 1280 picture had the page under it, the dialog gone).
    await page.evaluate(() => Promise.all(document.querySelector("dialog.sign-in").getAnimations({ subtree: true })
      .filter((one) => one.effect?.getTiming?.().iterations !== Infinity).map((one) => one.finished)));
    await shot(page, `dialog_${width}.png`);
    check(`1. ${width}: the dialog still open at its picture`, await page.locator("dialog.sign-in[open]").isVisible());
    await ctx.close();
  }

  // 2.
  const a = address("a");
  made.push(a);
  const before = await mintSession(a, { age: true });
  {
    const ctx = await context(1280, { google: { email: a, verified: true } });
    const page = await ctx.newPage();
    listen(page, "google");
    await openDialog(page);
    await page.locator("dialog.sign-in #way-google").click();
    await page.waitForURL((url) => url.pathname === "/gallery" && url.searchParams.get("sort") === "new", { timeout: 60000 });
    const kept = await keptOf(page);
    check("2. Sign in with Google: back on the very page, signed in, as the account a code signs in to",
      kept?.user_id === before.kept.user_id && kept?.email === a && Boolean(kept?.refresh_token), JSON.stringify({ ...kept, refresh_token: undefined }));
    await page.waitForTimeout(1500);
    await shot(page, "google_back_1280.png");
    await ctx.close();
  }

  // 3.
  const d = address("d");
  made.push(d);
  let hubPage = null;
  let hubCtx = null;
  {
    hubCtx = await context(390, { github: { email: d, verified: true } });
    const page = await hubCtx.newPage();
    hubPage = page;
    listen(page, "github");
    await page.goto(`${site}/profile?sign-in`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.locator("dialog.sign-in #way-github:not([hidden])").waitFor({ state: "visible", timeout: 30000 });
    await shot(page, "profile_sign_in_390.png");
    await page.locator("dialog.sign-in #way-github").click();
    // Back on /profile from the callback (?then=&with=github), the address
    // then put back to /profile alone: never ?sign-in again.
    await page.waitForURL((url) => url.pathname === "/profile" && !url.searchParams.has("sign-in"), { timeout: 60000 });
    const asked = await answerAge(page);
    await page.waitForFunction((key) => Boolean(localStorage.getItem(key)), STORAGE_KEY, { timeout: 30000 }).catch(() => null);
    const kept = await keptOf(page);
    check("3. Sign in with GitHub, a new address: signed in on /profile, asked its age first", asked && kept?.email === d
      && Boolean(kept?.user_id), JSON.stringify({ ...kept, refresh_token: undefined }));
    await page.waitForTimeout(4000);
    const state = await (await fetch(`${site}/__ways/state`)).json();
    check("3. its age answered over 13: its orangecheck account made, with the address GitHub verified",
      state.provisions.some((one) => one.user_id === kept?.user_id && one.email === d && one.email_verified === true),
      JSON.stringify(state.provisions.slice(-3)));
    await page.keyboard.press("Escape").catch(() => null);
    await shot(page, "github_back_390.png");
  }

  // 4.
  for (const width of [1280, 390]) {
    await hubPage.setViewportSize({ width, height: width < 600 ? 844 : 900 });
    await hubPage.goto(`${site}/settings#ways-part`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await hubPage.locator("#ways li").nth(1).waitFor({ state: "visible", timeout: 30000 });
    const rows = await hubPage.locator("#ways li").allTextContents();
    const oc = await hubPage.locator("#oc-said").textContent().catch(() => "");
    check(`4. ${width}: How you sign in: the code to the address, GitHub signing in, Google not used yet`,
      rows.length === 3 && /A code we email you/.test(rows[0]) && /GitHub.*Signs you in.*Unlink/.test(rows[2])
      && /Google.*Not used yet/.test(rows[1]), JSON.stringify(rows));
    check(`4. ${width}: the orangecheck part says the account signing in made`, /was made when you signed in/.test(oc || ""), oc);
    check(`4. ${width}: nothing sideways`, !(await sideways(hubPage)));
    await hubPage.locator("#ways-part").scrollIntoViewIfNeeded();
    await shot(hubPage, `settings_ways_${width}.png`);
  }
  await hubPage.locator("#ways li", { hasText: "GitHub" }).getByRole("button", { name: "Unlink" }).click();
  await hubPage.waitForFunction(() => /no longer signs you in here/.test(document.getElementById("ways-status")?.textContent || ""), null,
    { timeout: 30000 }).catch(() => null);
  const unlinked = await hubPage.locator("#ways-status").textContent();
  const rowsAfter = await hubPage.locator("#ways li").allTextContents();
  check("4. Unlink GitHub: said, the code still signs in, and Link again offered", /GitHub no longer signs you in here\. A code we email you still does\./
    .test(unlinked || "") && rowsAfter.some((row) => /GitHub.*Unlinked.*Link again/.test(row)), `${unlinked} ${JSON.stringify(rowsAfter)}`);
  await shot(hubPage, "settings_unlinked_390.png");
  await hubCtx.close();

  // 5.
  {
    const ctx = await context(390, { google: { email: address("unverified"), verified: false } });
    const page = await ctx.newPage();
    listen(page, "refused");
    await openDialog(page);
    await page.locator("dialog.sign-in #way-google").click();
    await page.waitForURL((url) => url.pathname === "/profile" && url.searchParams.get("failed") === "unverified", { timeout: 60000 });
    await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
    const said = await page.locator("dialog.sign-in").textContent();
    check("5. an address Google has not verified: back to the sign-in, with why", /Google gave no verified email address of yours/.test(said || "")
      && !(await keptOf(page)), (said || "").slice(0, 200));
    await shot(page, "refused_390.png");
    await ctx.close();
  }

  // 6.
  if (owner) {
    made.push(owner);
    for (const width of [1280, 390]) {
      const ctx = await context(width);
      const { kept } = await mintSession(owner, { age: true });
      await ctx.addInitScript(([key, value]) => localStorage.setItem(key, value), [STORAGE_KEY, JSON.stringify(kept)]);
      const page = await ctx.newPage();
      listen(page, `console ${width}`);
      await page.goto(`${site}/admin#switches`, { waitUntil: "domcontentloaded", timeout: 120000 });
      await page.locator("#way-google-is").waitFor({ state: "visible", timeout: 60000 });
      await page.waitForFunction(() => document.getElementById("way-google-is")?.textContent.trim() !== "", null, { timeout: 60000 })
        .catch(() => null);
      const is = [await page.locator("#way-google-is").textContent(), await page.locator("#way-github-is").textContent()];
      const steps = await page.locator("#way-google ol.way-steps").isVisible();
      check(`6. ${width}: the console's Sign in with Google and GitHub: each on, its keys here, its steps put away`,
        is[0] === "on" && is[1] === "on" && !steps, JSON.stringify(is));
      await page.locator("#h-ways").scrollIntoViewIfNeeded();
      await shot(page, `console_ways_${width}.png`);
      // And as the owner first meets it: no keys, its steps out.
      await page.evaluate(() => {
        for (const form of document.querySelectorAll("form[data-way]")) {
          form.querySelector("ol.way-steps").hidden = false;
          form.querySelector(".way-is").textContent = "off: no keys yet";
          form.querySelector('button[type="submit"]').disabled = true;
          form.querySelector('button[type="submit"]').textContent = "Turn it on";
        }
      });
      await shot(page, `console_ways_steps_${width}.png`);
      await ctx.close();
    }
  }
  check("no refusal from the page's security policy, and no error", errors.length === 0, errors.slice(0, 3).join(" | "));
} catch (trouble) {
  check("the flow finished", false, String(trouble?.stack || trouble).slice(0, 600));
} finally {
  await browser.close();
  for (const email of made) await deleteAccount(email).catch(() => false);
}
console.log(`ways_flow: ${failed ? `${failed} failed` : "all passed"} (pictures in ${out})`);
process.exit(failed ? 1 : 0);
