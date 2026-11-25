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
//      each with its mark, as tall and wide as Email me a code, each link
//      with the challenge of a verifier the page keeps; no box to tick; one
//      line that signing in without orangecheck also makes the orangecheck
//      account, with a link to what that is; nothing sideways.
//   2. Sign in with Google: to Google (the stand-in's page, here), and back
//      to the very page, signed in, the age question answered on the way:
//      no second account for an address a code signed in before.
//   3. Sign in with GitHub from /profile?sign-in, a new address: back on
//      /profile, signed in, asked its age first; answered, its orangecheck
//      account made, the address for orangecheck to check.
//   4. Settings: How you sign in lists the code, Google and GitHub; the
//      orangecheck part says the account signing in made. Unlink GitHub,
//      signed in with GitHub: signed out, and asked for a code, in words.
//   7. Sign in with GitHub to the account a code made: the dialog asks a
//      code to the address this once; typed, back on the very page signed
//      in, and GitHub's id kept for the account.
//   5. A refused sign-in (an address Google has not verified) comes back to
//      the dialog with words for why.
//   6. The owner's console (the relay's --owner, a throwaway): Switches,
//      Sign in with Google and GitHub, each on with its steps hidden.
//   8. The owner's address with Google (signin4): back to the dialog, told
//      the account signs in only with a code, not signed in.
//   9. Refused for signing in too often: the dialog says so, and that a
//      code still signs in.
//  10. Nothing reached Google or GitHub (signin5, signreview2 SR4): no
//      request of any sign-in went to either's host, every provider's page
//      was the relay's stand-in (/__ways/authorize/<way>), and this
//      Chromium cannot reach either at all (browser.mjs NO_PROVIDERS).
// Pictures of each at 1280 and 390 in --out. Every account is deleted.
import { mkdirSync } from "node:fs";
import path from "node:path";
import { randomBytes } from "node:crypto";
import { launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
import { WHO_HEADER, whoHeader } from "./ways_stand_in.mjs";

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

// Every request any context made to Google's or GitHub's hosts, and every
// provider page the stand-in answered (each case's hop to it), for 10.
const PROVIDER = /^(?:[a-z0-9-]+\.)*(?:google\.com|googleapis\.com|github\.com)$/i;
const toProviders = [];
const pagesHere = [];

/// A context at [width] whose Google and GitHub are the stand-in's: the
/// relay sends its sign-ins to the stand-in's page (WHO_HEADER), which
/// answers at once as [who] says, straight back to the callback. A route
/// here could not: Playwright continues the provider's hop, a redirect's,
/// without asking one, and runs reached the real Google (SR4).
async function context(width, who = {}) {
  // Each person a network of their own (198.18.0.0/15, set aside for tests),
  // as Vercel says it: the sign-ins' limits count by network for 15
  // minutes, across runs and relays (api/_ways.js LIMITS). No service worker:
  // web/sw.js fetches a page's navigations itself once it controls the page,
  // and Playwright's routes do not see what a service worker fetches.
  const from = `198.18.${randomBytes(1)[0]}.${1 + (randomBytes(1)[0] % 254)}`;
  const ctx = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, colorScheme: "light",
    extraHTTPHeaders: { "x-forwarded-for": from, [WHO_HEADER]: whoHeader(who) }, serviceWorkers: "block" });
  ctx.on("request", (request) => {
    const url = new URL(request.url());
    if (PROVIDER.test(url.hostname)) toProviders.push(`${url.host}${url.pathname}`);
    if (/^\/__ways\/authorize\/(google|github)$/.test(url.pathname)) pagesHere.push(url.pathname);
  });
  return ctx;
}

// The page a case last opened: pictured, with where it was, when the flow stops.
let lastPage = null;

function listen(page, name) {
  lastPage = page;
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
      && /^\/auth\/google\?then=%2Fgallery%3Fsort%3Dnew&take=[A-Za-z0-9_-]{43}$/.test(looks.google.href || "")
      && await page.evaluate((href) => Boolean(JSON.parse(localStorage.getItem("bw_way_takes") || "{}")[new URL(href, location.href)
        .searchParams.get("take")]?.v), looks.google.href), JSON.stringify(looks));
    check(`1. ${width}: no box; one line that signing in makes the orangecheck account, with what that is`,
      looks.boxes === 0 && looks.lineShown && looks.line === "Signing in without orangecheck also makes your orangecheck account. What is that?"
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
    const ctx = await context(1280, { google: { email: a, verified: true, hd: "resend.dev" } });
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
    check("3. its age answered over 13: its orangecheck account made, with the address, for orangecheck to check",
      state.provisions.some((one) => one.user_id === kept?.user_id && one.email === d && one.email_verified === false),
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
  // Signed in with GitHub, unlinking it ends this session too (the review's
  // F2): signed out here, and the sign-in asks for a code, saying why.
  await hubPage.locator("#ways li", { hasText: "GitHub" }).getByRole("button", { name: "Unlink" }).click();
  await hubPage.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 }).catch(() => null);
  const unlinked = await hubPage.locator("dialog.sign-in").textContent().catch(() => "");
  check("4. Unlink GitHub, signed in with it: signed out, asked for a code in words",
    /GitHub no longer signs you in\. You had signed in here with it, so sign in again with a code we email you\./.test(unlinked || "")
    && !(await keptOf(hubPage)) && await hubPage.locator("#signed-out").isVisible(), (unlinked || "").slice(0, 200));
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

  // 7.
  for (const width of [1280]) {
    const ctx = await context(width, { github: { email: a, verified: true } });
    const page = await ctx.newPage();
    listen(page, "confirm");
    await openDialog(page);
    await page.locator("dialog.sign-in #way-github").click();
    await page.waitForURL((url) => url.pathname === "/profile" && url.searchParams.get("failed") === "confirm", { timeout: 60000 });
    await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
    const said = await page.locator("dialog.sign-in").textContent();
    check(`7. ${width}: GitHub to the account a code made: no session, the dialog asks a code this once`,
      /This address has a Brickworks account already\. Sign in with a code we email you this once, and GitHub signs you in from then on\./
        .test(said || "") && !(await keptOf(page)), (said || "").slice(0, 240));
    await page.evaluate(() => Promise.all(document.querySelector("dialog.sign-in").getAnimations({ subtree: true })
      .filter((one) => one.effect?.getTiming?.().iterations !== Infinity).map((one) => one.finished)));
    await shot(page, `github_confirm_${width}.png`);
    await page.fill("dialog.sign-in input[type=email]", a);
    await page.click('dialog.sign-in button[type="submit"]');
    await page.waitForFunction(() => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility(), null, { timeout: 30000 });
    const typed = await mintCode(a, { welcome: false });
    await page.fill("dialog.sign-in .code-boxes input:first-child", typed);
    await page.waitForURL((url) => url.pathname === "/gallery" && url.searchParams.get("sort") === "new", { timeout: 60000 });
    const kept = await keptOf(page);
    // GitHub's id is kept in way_links (signin4, supabase/way_links.sql).
    const held = await (await fetch(`${String(process.env.SUPABASE_URL).replace(/\/+$/, "")}/rest/v1/rpc/way_links_of`, { method: "POST",
      headers: { apikey: process.env.SUPABASE_SECRET_KEY, authorization: `Bearer ${process.env.SUPABASE_SECRET_KEY}`, "content-type": "application/json" },
      body: JSON.stringify({ account: before.kept.user_id }) })).json().catch(() => null);
    check(`7. ${width}: the code typed: back on the very page, signed in to that account, GitHub's id kept for it`,
      kept?.user_id === before.kept.user_id && held?.github?.state === "on" && /^\d+$/.test(String(held?.github?.id || "")),
      `${page.url()} ${JSON.stringify({ ...kept, refresh_token: undefined })} ${JSON.stringify(held)}`);
    const again = await context(width, { github: { email: a, verified: true } });
    const next = await again.newPage();
    listen(next, "confirm again");
    await openDialog(next);
    await next.locator("dialog.sign-in #way-github").click();
    await next.waitForURL((url) => url.pathname === "/gallery" && url.searchParams.get("sort") === "new", { timeout: 60000 });
    check(`7. ${width}: and GitHub signs it in from then on`, (await keptOf(next))?.user_id === before.kept.user_id);
    await again.close();
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

    // 8. The owner's address with Google: refused, in words, signed out.
    for (const width of [1280, 390]) {
      const ctx = await context(width, { google: { email: owner, verified: true, hd: "resend.dev" } });
      const page = await ctx.newPage();
      listen(page, `owner ${width}`);
      await openDialog(page);
      await page.locator("dialog.sign-in #way-google").click();
      await page.waitForURL((url) => url.pathname === "/profile" && url.searchParams.get("failed") === "code_only", { timeout: 60000 });
      await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
      const said = await page.locator("dialog.sign-in").textContent();
      check(`8. ${width}: the owner's address with Google: back to the sign-in, told it signs in only with a code, not signed in`,
        /This account signs in only with a code we email you\./.test(said || "") && !(await keptOf(page)) && !(await sideways(page)),
        (said || "").slice(0, 200));
      await shot(page, `owner_code_only_${width}.png`);
      await ctx.close();
    }
  }

  // 9. Refused for signing in too often (ways_check 12 drives the limit):
  // the words, as the way back gives them.
  for (const width of [1280, 390]) {
    const ctx = await context(width);
    const page = await ctx.newPage();
    listen(page, `often ${width}`);
    await page.goto(`${site}/profile?${new URLSearchParams({ "sign-in": "", then: "/gallery", with: "github", failed: "often" })}`,
      { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
    const said = await page.locator("dialog.sign-in").textContent();
    check(`9. ${width}: refused for signing in too often: the dialog says so, and that a code still signs in`,
      /Too many sign-ins with GitHub just now\. Try again in a few minutes, or sign in with a code we email you\./.test(said || "")
      && !(await sideways(page)), (said || "").slice(0, 200));
    await shot(page, `often_${width}.png`);
    await ctx.close();
  }

  // 10. Nothing reached a provider. Seven sign-ins went to a provider's
  // page above (2, 3, 5, 7 twice, 8 twice): each the stand-in's.
  const asked = await (await fetch(`${site}/__ways/state`)).json().catch(() => ({}));
  console.log(`  --    requests to Google's or GitHub's hosts: ${toProviders.length}; provider pages answered by the stand-in: `
    + `${pagesHere.length} seen, ${asked.pages} answered`);
  check("10. no request of any sign-in went to Google's or GitHub's hosts", toProviders.length === 0, toProviders.slice(0, 5).join(" "));
  check("10. every provider's page was the relay's stand-in", pagesHere.length >= (owner ? 7 : 5) && asked.pages >= pagesHere.length,
    `${pagesHere.length} ${asked.pages}`);
  // And this Chromium cannot reach either: a hop that escaped would fail
  // here. Asked from a context of its own, not counted above.
  {
    const bare = await browser.newContext();
    const tab = await bare.newPage();
    const tried = [];
    for (const where of ["https://accounts.google.com/o/oauth2/v2/auth", "https://github.com/login/oauth/authorize"]) {
      tried.push(await tab.goto(where, { timeout: 30000 }).then(() => "answered", (trouble) => String(trouble.message).split("\n")[0]));
    }
    check("10. this Chromium cannot reach Google's or GitHub's sign-in at all", tried.every((one) => /ERR_NAME_NOT_RESOLVED/.test(one)),
      tried.join(" | "));
    await bare.close();
  }
  check("no refusal from the page's security policy, and no error", errors.length === 0, errors.slice(0, 3).join(" | "));
} catch (trouble) {
  const where = lastPage && !lastPage.isClosed() ? lastPage.url() : "";
  if (where) await shot(lastPage, "stopped.png");
  check("the flow finished", false, `${where ? `at ${where} (stopped.png): ` : ""}${String(trouble?.stack || trouble).slice(0, 600)}`);
} finally {
  await browser.close();
  for (const email of made) await deleteAccount(email).catch(() => false);
}
console.log(`ways_flow: ${failed ? `${failed} failed` : "all passed"} (pictures in ${out})`);
process.exit(failed ? 1 : 0);
