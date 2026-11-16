// Signing in from wherever a person is (signinux, 2026-11-13), in a real
// browser:
//
//   node tools/web/signin_flow.mjs --out=shots/signin              this checkout's web/, all stood in
//   node tools/web/signin_flow.mjs --web=<dir> --out=...           another copy of web/ (an older commit's)
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/signin_flow.mjs --url=<deployment> --out=...
//
//   1. The header's Sign in opens the sign-in dialog over the page, in one
//      click, at 1280 (its link in the bar) and 430 (in the phone's Menu,
//      a touch context), the address unchanged; Not now leaves the page as
//      it was. Signed in there, the page is the same page, where it was
//      scrolled, the header shows the avatar with no reload and the focus
//      stays on it, a late answer to the header's count too.
//   2. /profile?sign-in, the header's link without scripts, opens the
//      dialog by itself, the ?sign-in gone from the address.
//   5. Signing out on /profile shows its Sign in and opens no dialog.
//   6. Two tabs: a sign-in in one is the avatar in the other, no reload; a
//      sign-out in one reloads the other signed out, but for a tab with
//      words typed and not sent, which keeps them, Sign in in its header.
//   7. /admin: Sign in at the right of its bar and in its gate, signed in
//      in place, the console asked again, still on /admin.
//   8. (Stood in) a locked address is told "Try again after HH:MM".
//   9. (Stood in) a field's edge is 3:1 on the dialog and its fill, both themes.
//   10. (design_stand_in.mjs) the connector's sign-in page sends no code
//      short of digits, and drops the last refusal's red line as the next
//      code is checked.
//   11. (design_stand_in.mjs, its own model) a read of how a model stands,
//      answered after Like and Follow went through, is dropped.
//   3. The code is a box per digit (as many as the deployment says): one
//      labelled group, "Digit 1 of 8", the number pad, the first box focused
//      and the one-time-code fill's target. Typed digits move on, a letter
//      is refused, Backspace empties and steps back, the arrows move; a
//      paste of "8765 4321" and of "8765-4321" fills every box from the
//      first, goes by itself, and, refused, shakes the row empty with the
//      focus back in the first box and the words said; the code filled into
//      the first box as a password manager fills it goes by itself and
//      signs in, the boxes read-only while it is checked.
//   4. (Stood in only: orangecheck's window is me.ochk.io, answered here.)
//      Two equal ways in, the same height and width, "or" between. While
//      the window is open the dialog says so, with Show the orangecheck
//      window (bringing the same window back, no second one) and Cancel
//      (closing it, the dialog as it was). Closed unfinished: the dialog
//      back as it was, a calm line in orangecheck's words, the focus on its
//      button. Blocked: a callout in orangecheck's words, the focus on its
//      button. A token the server refuses: its words, in the trouble's
//      colour, the button to try again. Signed in: the dialog gone, the
//      page the same, the avatar in the header the moment it goes.
//   Pictures of each state at 1280, 768 and 430, light and dark (--shots=all
//   for every size; the default shoots the checks' own sizes).
//
// Stood in, nothing is asked of Supabase or orangecheck: /api/account,
// /api/otp, Supabase's verify and token, /api/people's few answers and
// orangecheck's window are answered here (the right code is 12345678). On
// a deployment, steps 1-3 sign in a throwaway test address (deleted after)
// by a code minted with the admin API, as account_flow does; orangecheck's
// real window is oc_flow's.
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";
import { mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/signin";
mkdirSync(out, { recursive: true });
const deployed = Boolean(args.url);
const served = deployed ? null : await serveDir(args.web || path.join(path.dirname(new URL(import.meta.url).pathname), "../../web"));
const site = deployed ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : served.url;
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const allSizes = args.shots === "all";
const only = String(args.only || "header,profile,code,orangecheck,signout,tabs,admin,limit,edge,consent,stale").split(",");

let failed = 0;
const check = (what, ok, said = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${said && !ok ? `: ${said}` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const listen = (page, who) => page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
const shot = (page, name) => page.screenshot({ path: path.join(out, `${name}.png`), timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
// Polled on a clock, not on frames: a browser drawing slowly on a busy
// machine still answers.
const until = (page, test, arg = null, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms, polling: 100 })
  .then(() => true, () => false);

// --- what is stood in -------------------------------------------------
const SUPABASE = "https://stand-in.supabase.test";
const RIGHT = "12345678";
// A code Supabase answers with its limit, as it does many tries from one machine.
const LIMITED = "99999999";
const OC = "https://me.ochk.io";
let windowAnswer = "stay"; // "stay": the window waits; "token": it hands a token back
let exchangeAnswer = "ok"; // what /api/orangecheck?op=signin answers a token
const verified = [];

const session = (email) => ({ access_token: `at-${randomBytes(4).toString("hex")}`, refresh_token: "rt-stand-in",
  expires_in: 3600, token_type: "bearer", user: { id: "00000000-0000-4000-8000-000000000001", email } });

async function standIn(context) {
  const json = (route, status, body) => route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
  await context.route(`${site}/api/account*`, (route) => {
    if (route.request().headers().authorization) return json(route, 200, { signed_in: true, age: { ask: false, over_13: true }, beta: null });
    return json(route, 200, { enabled: true, url: SUPABASE, key: "stand-in-key",
      orangecheck: { ready: true, everyone: true, connect: true } });
  });
  await context.route(`${site}/api/otp`, (route) => json(route, 200, { ok: true, expires_in_minutes: 10, digits: RIGHT.length }));
  await context.route(`${SUPABASE}/**`, async (route) => {
    const url = new URL(route.request().url());
    const body = route.request().postDataJSON() || {};
    if (url.pathname === "/auth/v1/verify") {
      verified.push(body.token);
      // As long as Supabase takes to answer, so the boxes are seen waiting.
      await new Promise((done) => setTimeout(done, 900));
      if (body.token === LIMITED) return json(route, 429, { code: 429, error_code: "over_request_rate_limit", msg: "Too many requests" });
      return body.token === RIGHT ? json(route, 200, session(body.email))
        : json(route, 403, { code: 403, error_code: "otp_expired", msg: "Token has expired or is invalid" });
    }
    if (url.pathname === "/auth/v1/token") return json(route, 200, session("builder@example.org"));
    return json(route, 404, {});
  });
  await context.route(`${site}/api/people*`, (route) => {
    const op = new URL(route.request().url()).searchParams.get("op");
    // Answered late, as a busy server does: the header drawn again after
    // the dialog has closed (sifix: that put the focus on the page).
    if (op === "feed_count") {
      return new Promise((done) => setTimeout(done, 800))
        .then(() => json(route, 200, { signed_in: true, me: { handle: "builder", name: "A Builder" }, count: 0 }));
    }
    return json(route, 503, { error: "stood in" });
  });
  await context.route(`${site}/api/orangecheck*`, (route) => {
    const op = new URL(route.request().url()).searchParams.get("op");
    if (op !== "signin") return json(route, 200, {});
    return exchangeAnswer === "ok" ? json(route, 200, session("0123456789abcdef0123456789abcdef@oc.brickworks.diy"))
      : json(route, 503, { error: "orangecheck could not confirm the sign-in just now. Try again in a minute." });
  });
  await context.route(`${OC}/**`, (route) => route.fulfill({ status: 200, contentType: "text/html", body: `<!doctype html>
<title>orangecheck (stood in)</title><body style="font:16px sans-serif;padding:24px">orangecheck, stood in.
<script>${windowAnswer === "token" ? `setTimeout(() => opener.postMessage({ type: "oc-signin-success",
  account: { did: "did:oc:stand-in" }, token: "oc-token-stand-in" }, "*"), 400);` : ""}</script>` }));
}

async function context(width, theme, { touch = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height: width < 600 ? 932 : width < 1000 ? 1024 : 800 },
    colorScheme: theme, ...(touch ? { isMobile: true, hasTouch: true } : {}) });
  if (deployed) {
    await made.route(`${site}/**`, (route) => route.continue({ headers: { ...route.request().headers(), ...headers } }));
    // Supabase refuses a wrong code in a fraction of a second, before a
    // look 300 ms after the paste sees the boxes wait on it (6 fails on a
    // unit's preview, 2026-11-15): held as long as the stand-in holds its
    // answer, then sent on and answered by Supabase itself.
    await made.route("**/auth/v1/verify", async (route) => {
      await new Promise((done) => setTimeout(done, 900));
      return route.continue();
    });
  } else {
    await standIn(made);
  }
  await made.addInitScript((chosen) => {
    try {
      localStorage.setItem("brickworks.theme", chosen);
    } catch { /* none */ }
  }, theme);
  return made;
}

const browser = await launch({ signedOut: true });
const person = deployed ? `delivered+bw-signin-${randomBytes(4).toString("hex")}@resend.dev` : "builder@example.org";
// A code is sent an address four times in any fifteen minutes, no more
// (api/otp.js may_ask_for_code): the header's three sizes ask three for
// [person], so the two tabs and /admin ask theirs for [second]. All five
// for one address, /admin's was refused, and it read as the console never
// asked again (rel-m305, 10:02:37Z, the fifth in five minutes).
const second = deployed ? `delivered+bw-signin2-${randomBytes(4).toString("hex")}@resend.dev` : person;
const session_ = deployed ? await import("./session.mjs") : null;
if (deployed) {
  await session_.mintSession(person, { age: true, welcome: true });
  await session_.mintSession(second, { age: true, welcome: true });
}
const codeFor = async (who = person) => (deployed ? session_.mintCode(who) : RIGHT);
/// A sign-in as this browser keeps it (localStorage brickworks.session):
/// on a deployment a new one each time, by the password grant (a refresh
/// token used twice ends the whole session).
const keptSession = async () => (deployed ? (await session_.mintSession(person, { age: true, welcome: true })).kept
  : { refresh_token: "rt-stand-in", email: person, user_id: "00000000-0000-4000-8000-000000000001", url: SUPABASE, key: "stand-in-key" });
/// [made]'s pages signed in from their first load, once a tab: a reload
/// after signing out stays signed out.
async function signedInFrom(made) {
  await made.addInitScript((kept) => {
    try {
      if (!sessionStorage.getItem("flow.seeded")) {
        localStorage.setItem("brickworks.session", kept);
        sessionStorage.setItem("flow.seeded", "1");
      }
    } catch { /* none */ }
  }, JSON.stringify(await keptSession()));
}
/// The sign-in's line, and whether it is said as trouble.
const saidIn = (page) => page.evaluate(() => ({ said: document.querySelector("dialog.sign-in form .said")?.textContent || "",
  tone: document.querySelector("dialog.sign-in form .said")?.dataset.tone || "" }));
/// Sign out from the header's account menu (the page loads again).
async function signOutHere(page) {
  await page.locator(".site-head .account-menu summary").click();
  await Promise.all([page.waitForEvent("load", { timeout: 30000 }), page.locator(".site-head .account-menu button.sign-out").click()]);
}

const dialogOpen = (page) => page.evaluate(() => Boolean(document.querySelector("dialog.sign-in")?.open));
const avatar = (page) => page.evaluate(() => ({
  avatar: [...document.querySelectorAll(".site-head .account-btn")].some((one) => one.checkVisibility()),
  signIn: [...document.querySelectorAll(".site-head a[data-account]")].some((one) => one.checkVisibility()),
}));
const boxesOf = (page) => page.evaluate(() => {
  const row = document.querySelector("dialog.sign-in .code-boxes");
  const boxes = [...(row?.querySelectorAll("input") || [])];
  return { row: Boolean(row), values: boxes.map((one) => one.value), focus: boxes.indexOf(document.activeElement),
    readOnly: boxes.some((one) => one.readOnly), shook: row?.classList.contains("shake") || false,
    said: document.querySelector("dialog.sign-in form .said")?.textContent || "" };
});

/// [target] pressed where it is drawn, as a person presses it: a locator's
/// click first scrolls the element into view, and for the sticky header
/// under the page's scroll-padding-top that scrolled the page to its top
/// (300 -> 0 at 1280, 300 -> 177 at 430), which no click of a person's does.
async function pressAt(page, target, phone) {
  const box = await (typeof target === "string" ? page.locator(target) : target).boundingBox();
  const [x, y] = [box.x + box.width / 2, box.y + box.height / 2];
  if (phone) await page.touchscreen.tap(x, y);
  else await page.mouse.click(x, y);
}

/// Open the header's Sign in: the bar's link, or the Menu's where the bar
/// has no room for its links (under 900 px, so 768 with a mouse too).
/// [phone]: a finger's tap, not a click.
async function headerSignIn(page, phone) {
  const press = (selector) => pressAt(page, selector, phone);
  if (await page.locator(".site-head .menu summary").isVisible()) {
    await press(".site-head .menu summary");
    await page.locator(".site-head .menu a[data-account]").waitFor({ state: "visible", timeout: 5000 });
    await press(".site-head .menu a[data-account]");
  } else {
    await press(".site-head .nav a[data-account]");
  }
}

/// The address typed and Email me a code pressed: true once the code is asked for.
async function toCode(page, who = person) {
  await page.locator("dialog.sign-in input[type=email]").fill(who);
  await page.locator("dialog.sign-in button[type=submit]").click();
  return until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility(), null, 30000);
}

async function paste(page, text) {
  await page.evaluate(async (words) => {
    await navigator.clipboard.writeText(words);
  }, text).catch(() => null);
  const kept = await page.evaluate(() => navigator.clipboard.readText()).catch(() => "");
  if (kept === text) {
    await page.keyboard.press("ControlOrMeta+V");
  } else {
    // A browser that keeps no clipboard here: the paste event as a browser sends it.
    await page.evaluate((words) => {
      const data = new DataTransfer();
      data.setData("text/plain", words);
      document.activeElement.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }));
    }, text);
  }
}

try {
  // 1 + 3: the header's Sign in, the code's boxes, signed in in place.
  for (const [width, phone, theme] of [[1280, false, "light"], [430, true, "dark"], [390, true, "light"]]) {
    if (!only.includes("header") && !only.includes("code")) break;
    const label = `${width}${phone ? " phone" : ""}`;
    const made = await context(width, theme, { touch: phone });
    await made.grantPermissions(["clipboard-read", "clipboard-write"], { origin: site }).catch(() => null);
    const page = await made.newPage();
    listen(page, label);
    await page.goto(`${site}/faq`, { waitUntil: "load", timeout: 120000 });
    // Kept on the page until it is loaded again.
    await page.evaluate(() => {
      window.__kept = true;
      scrollTo(0, 300);
    });
    const before = { url: page.url(), y: await page.evaluate(() => scrollY) };
    await headerSignIn(page, phone);
    const opened = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
    check(`${label}: the header's Sign in opens the sign-in dialog in one click, on the same page`,
      opened && page.url() === before.url, `open ${opened}, at ${page.url()}`);
    if (!opened) {
      await shot(page, `header_${width}_${theme}`);
      await made.close();
      continue;
    }
    // Its opening drawn out (the dialog rises in) before the picture.
    await page.waitForTimeout(500);
    await shot(page, `header_${width}_${theme}`);
    await pressAt(page, page.locator("dialog.sign-in .foot button, dialog.sign-in button:text-is('Not now')").first(), phone);
    const left = await until(page, () => !document.querySelector("dialog.sign-in"), null, 3000);
    const after = await page.evaluate(() => scrollY);
    check(`${label}: Not now leaves the page exactly as it was`, left && page.url() === before.url
      && Math.abs(after - before.y) < 2, `closed ${left}, ${page.url()}, scrolled ${before.y} -> ${after}`);
    await headerSignIn(page, phone);
    await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);

    // 3. The code.
    const asked = await toCode(page);
    check(`${label}: Email me a code asks for the code in boxes`, asked);
    if (!asked) {
      await shot(page, `code_${width}_${theme}_missing`);
      await made.close();
      continue;
    }
    const minted = deployed ? await codeFor() : RIGHT;
    const shape = await page.evaluate(() => {
      const row = document.querySelector("dialog.sign-in .code-boxes");
      const boxes = [...row.querySelectorAll("input")];
      const named = document.getElementById(row.getAttribute("aria-labelledby") || "")?.textContent || "";
      const rect = (one) => one.getBoundingClientRect();
      const d = rect(document.querySelector("dialog.sign-in"));
      // The form's own width, as its Sign in button has it.
      const form = rect(document.querySelector("dialog.sign-in button[type=submit]"));
      const first = rect(boxes[0]);
      const last = rect(boxes[boxes.length - 1]);
      return { count: boxes.length, group: row.getAttribute("role"), named,
        labels: boxes.map((one) => one.getAttribute("aria-label")),
        pad: boxes.every((one) => one.inputMode === "numeric" && one.pattern === "[0-9]*"),
        fill: boxes[0].autocomplete, others: boxes.slice(1).every((one) => one.autocomplete === "off"),
        focus: boxes.indexOf(document.activeElement), tall: Math.round(first.height), wide: Math.round(first.width),
        centred: Math.abs((first.left - d.left) - (d.right - last.right)) <= 2,
        inside: first.left >= form.left - 0.5 && last.right <= form.right + 0.5,
        sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 };
    });
    check(`${label}: one box per digit of the code (${shape.count} for a ${minted.length}-digit code), one group named "${shape.named}"`,
      shape.count === minted.length && shape.group === "group" && /The code sent to/.test(shape.named), JSON.stringify(shape));
    check(`${label}: each said as "Digit 1 of ${shape.count}"..., the number pad, the first box the one-time-code fill's and focused`,
      shape.labels[0] === `Digit 1 of ${shape.count}` && shape.labels.at(-1) === `Digit ${shape.count} of ${shape.count}`
      && shape.pad && shape.fill === "one-time-code" && shape.others && shape.focus === 0, JSON.stringify(shape));
    check(`${label}: sized for a thumb (${shape.wide}x${shape.tall}), centred, within the form's width, nothing sideways`,
      shape.tall >= 48 && shape.wide >= 28 && shape.centred && shape.inside && !shape.sideways, JSON.stringify(shape));
    await shot(page, `code_${width}_${theme}`);
    await page.keyboard.type("1234");
    let now = await boxesOf(page);
    check(`${label}: four digits typed fill four boxes, the focus on the fifth`,
      now.values.join("") === "1234" && now.values[4] === "" && now.focus === 4, JSON.stringify(now));
    await page.keyboard.type("a");
    now = await boxesOf(page);
    check(`${label}: a letter is refused`, now.values.join("") === "1234" && now.focus === 4, JSON.stringify(now));
    await page.keyboard.press("Backspace");
    now = await boxesOf(page);
    check(`${label}: Backspace on an empty box empties the one before and steps back`,
      now.values.join("") === "123" && now.focus === 3, JSON.stringify(now));
    await page.keyboard.press("Backspace");
    now = await boxesOf(page);
    check(`${label}: and again`, now.values.join("") === "12" && now.focus === 2, JSON.stringify(now));
    await page.keyboard.press("ArrowLeft");
    const leftOne = (await boxesOf(page)).focus;
    await page.keyboard.press("ArrowRight");
    check(`${label}: the arrows move between boxes`, leftOne === 1 && (await boxesOf(page)).focus === 2);
    const asks = verified.length;
    for (const typed of ["8765 4321", "8765-4321"]) {
      await paste(page, typed);
      await page.waitForTimeout(300);
      now = await boxesOf(page);
      check(`${label}: "${typed}" pasted in the third box fills every box from the first, and goes by itself, read-only while checked`,
        now.values.join("") === "87654321" && now.readOnly, JSON.stringify(now));
      const refused = await until(page, () => {
        const boxes = [...document.querySelectorAll("dialog.sign-in .code-boxes input")];
        return boxes.every((one) => !one.value && !one.readOnly) && document.activeElement === boxes[0];
      }, null, 30000);
      now = await boxesOf(page);
      check(`${label}: refused, the row shakes empty, the focus in the first box, and says so ("${now.said}")`,
        refused && now.shook && /wrong or has expired/.test(now.said), JSON.stringify(now));
      if (typed === "8765 4321") await shot(page, `code_wrong_${width}_${theme}`);
      await page.keyboard.press("ArrowRight");
      await page.keyboard.press("ArrowRight");
    }
    if (!deployed) {
      check(`${label}: each paste sent once, by its last digit`, verified.length - asks === 2, verified.slice(asks).join(" "));
      // A limit, not a wrong code: the digits kept to send again, said in
      // the trouble's colour, nothing shaken (the last refusal's shake
      // taken off first, so a new one would show).
      await page.evaluate(() => document.querySelector("dialog.sign-in .code-boxes")?.classList.remove("shake"));
      await page.keyboard.press("Home");
      await page.keyboard.type(LIMITED);
      const limited = await until(page, () => /Too many tries/.test(document.querySelector("dialog.sign-in form .said")?.textContent || "")
        && ![...document.querySelectorAll("dialog.sign-in .code-boxes input")].some((one) => one.readOnly), null, 30000);
      now = await boxesOf(page);
      const tone = await page.evaluate(() => document.querySelector("dialog.sign-in form .said")?.dataset.tone || "");
      check(`${label}: a limit keeps the digits to send again, says so in the trouble's colour, shakes nothing`,
        limited && now.values.join("") === LIMITED && !now.shook && tone === "bad", `${JSON.stringify(now)} tone ${tone}`);
    }
    // A password manager's fill: the whole code into the first box.
    await page.locator("dialog.sign-in .code-boxes input").first().fill(minted);
    const filled = await boxesOf(page);
    const gone = await until(page, () => !document.querySelector("dialog.sign-in"), null, 45000);
    check(`${label}: the code filled into the first box (a password manager's fill) fans out and goes by itself`,
      filled.values.join("") === minted && gone, JSON.stringify(filled));
    // The page where it was, and the focus on the avatar the whole time
    // the header's count is still coming (sifix: 1829 px down became 1411
    // at 1280, a plain focus() scrolling the sticky header into view; and
    // the count, redrawing the avatar, dropped the focus to the page).
    const stayed = [];
    for (const ms of [0, 300, 1500]) {
      await page.waitForTimeout(ms);
      stayed.push(await page.evaluate(() => ({ y: Math.round(scrollY),
        on: document.activeElement?.classList.contains("account-btn") ? "avatar" : document.activeElement?.tagName || "" })));
    }
    check(`${label}: signed in, the page stays where it was (${before.y} px) and the focus stays on the avatar`,
      stayed.every((one) => Math.abs(one.y - before.y) < 3 && one.on === "avatar"), JSON.stringify(stayed));
    const header = await avatar(page);
    check(`${label}: signed in, the same page, the header the avatar, no reload`,
      page.url() === before.url && header.avatar && !header.signIn && await page.evaluate(() => window.__kept === true),
      `${page.url()} ${JSON.stringify(header)}`);
    await shot(page, `signed_in_${width}_${theme}`);
    await made.close();
  }

  // 2. A signed-out /profile come to sign in (the header's link, opened
  // in a new tab or where its script did not run: /profile?sign-in).
  if (only.includes("profile")) {
    for (const width of [1280, 430]) {
      const made = await context(width, "light", { touch: width < 600 });
      const page = await made.newPage();
      listen(page, `profile ${width}`);
      await page.goto(`${site}/profile?sign-in`, { waitUntil: "load", timeout: 120000 });
      const opened = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 10000);
      check(`${width}: /profile?sign-in, signed out, opens the sign-in by itself, and its address loses ?sign-in`,
        opened && !new URL(page.url()).searchParams.has("sign-in"), page.url());
      await shot(page, `profile_${width}_light`);
      if (opened) {
        await page.keyboard.press("Escape");
        check(`${width}: closed, the page's own Sign in has the focus`,
          await until(page, () => document.activeElement?.id === "sign-in", null, 3000));
      }
      await made.close();
    }
    // A page that draws only for somebody signed in (/lists), signed in
    // there from the header: drawn for them where they are, no reload.
    if (!deployed) {
      const made = await context(1280, "light");
      const page = await made.newPage();
      listen(page, "lists");
      await page.goto(`${site}/lists`, { waitUntil: "load", timeout: 120000 });
      await until(page, () => document.documentElement.dataset.lists === "signed-out", null, 10000);
      await page.evaluate(() => { window.__kept = true; });
      await headerSignIn(page, false);
      const drawn = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000)
        && await toCode(page);
      if (drawn) await page.keyboard.type(RIGHT);
      const after = drawn && await until(page, () => !document.querySelector("dialog.sign-in")
        && document.documentElement.dataset.lists !== "signed-out" && document.getElementById("signed-out")?.hidden, null, 30000);
      check("1280: signed in from the header on /lists, the page draws for them there, no reload",
        after && page.url() === `${site}/lists` && await page.evaluate(() => window.__kept === true),
        `${page.url()} ${await page.evaluate(() => document.documentElement.dataset.lists)}`);
      await made.close();
    }
  }

  // 5. Signing out on /profile (sifix, 2026-11-15: the sign-in opened at
  // once after it, as it did for a sign-in that ran out): the page with its
  // own Sign in, no dialog nobody asked for.
  if (only.includes("signout")) {
    const made = await context(1280, "light");
    await signedInFrom(made);
    const page = await made.newPage();
    listen(page, "signout");
    await page.goto(`${site}/profile`, { waitUntil: "load", timeout: 120000 });
    const shown = await until(page, () => [...document.querySelectorAll(".site-head .account-btn")].some((one) => one.checkVisibility()), null, 20000);
    if (shown) await signOutHere(page);
    await page.waitForTimeout(2500);
    const after = await page.evaluate(() => ({ dialog: Boolean(document.querySelector("dialog.sign-in")?.open),
      signedOut: !document.getElementById("signed-out")?.hidden, button: Boolean(document.getElementById("sign-in")?.checkVisibility()),
      kept: Boolean(localStorage.getItem("brickworks.session")) }));
    check("1280: signed out from the account menu on /profile, the page shows its own Sign in and opens no dialog",
      shown && !after.dialog && after.signedOut && after.button && !after.kept, JSON.stringify({ shown, ...after }));
    await shot(page, "profile_signed_out_1280_light");
    await made.close();
  }

  // 6. Two tabs (sifix: tab B kept its avatar after tab A signed out). A
  // sign-in in one reaches the other at once, drawn there with no reload;
  // a sign-out reaches it too: a tab with nothing typed is loaded again,
  // signed out; one holding words typed and not sent keeps them, its
  // header back to Sign in.
  if (only.includes("tabs")) {
    const made = await context(1280, "light");
    const [a, b, c] = [await made.newPage(), await made.newPage(), await made.newPage()];
    listen(a, "tab A");
    listen(b, "tab B");
    listen(c, "tab C");
    for (const [page, at] of [[a, "/faq"], [b, "/download"], [c, "/takedown"]]) {
      await page.goto(`${site}${at}`, { waitUntil: "load", timeout: 120000 });
      await page.evaluate(() => { window.__kept = true; });
    }
    // A takedown notice half written, not sent.
    const words = c.locator("#what");
    const typed = await words.isVisible().catch(() => false);
    if (typed) await words.fill("Half a note, not sent yet.");
    check("tab C: words typed into a field of its page", typed);
    await headerSignIn(a, false);
    const signed = await until(a, () => document.querySelector("dialog.sign-in")?.open, null, 6000) && await toCode(a, second);
    if (signed) {
      await a.locator("dialog.sign-in .code-boxes input").first().focus();
      await a.keyboard.type(await codeFor(second));
    }
    const inA = signed && await until(a, () => !document.querySelector("dialog.sign-in"), null, 45000);
    const inB = await until(b, () => [...document.querySelectorAll(".site-head .account-btn")].some((one) => one.checkVisibility())
      && window.__kept === true, null, 15000);
    check("tab A signed in: tab B's header is the avatar at once, no reload", inA && inB,
      JSON.stringify({ inA, a: (await saidIn(a)).said, b: await avatar(b) }));
    if (inA) await signOutHere(a);
    const outB = await until(b, () => [...document.querySelectorAll(".site-head a[data-account]")].some((one) => one.checkVisibility())
      && ![...document.querySelectorAll(".site-head .account-btn")].some((one) => one.checkVisibility()), null, 15000);
    const reloadedB = await b.evaluate(() => window.__kept !== true);
    check("tab A signed out: tab B, nothing typed in it, is loaded again, signed out", outB && reloadedB,
      JSON.stringify({ header: await avatar(b), reloaded: reloadedB }));
    if (typed) {
      const outC = await until(c, () => [...document.querySelectorAll(".site-head a[data-account]")].some((one) => one.checkVisibility()), null, 15000);
      const keptC = await c.evaluate(() => ({ kept: window.__kept === true, words: document.getElementById("what")?.value || "" }));
      check("tab A signed out: tab C keeps the words typed in it, no reload, its header back to Sign in",
        outC && keptC.kept && keptC.words === "Half a note, not sent yet.", JSON.stringify({ header: await avatar(c), ...keptC }));
    }
    await made.close();
  }

  // 7. /admin (sifix: no Sign in in its bar, and its gate's link went to
  // /profile and never came back): signed in there, in place, the console
  // asked again with the sign-in, still on /admin. The test account is not
  // the owner, so the gate then says it cannot see the page.
  if (only.includes("admin")) {
    const made = await context(1280, "light");
    if (!deployed) {
      await made.route(`${site}/api/admin*`, (route) => route.fulfill({ status: 404, contentType: "application/json",
        body: JSON.stringify({ error: "not found" }) }));
    }
    const page = await made.newPage();
    listen(page, "admin");
    await page.goto(`${site}/admin#people`, { waitUntil: "load", timeout: 120000 });
    await until(page, () => !/Checking/.test(document.getElementById("gate-note")?.textContent || ""), null, 20000);
    await page.evaluate(() => { window.__kept = true; });
    const bar = await page.evaluate(() => {
      const button = document.getElementById("sign-in");
      const bar = document.querySelector(".console-bar .wrap")?.getBoundingClientRect();
      const at = button?.getBoundingClientRect();
      return { shown: Boolean(button?.checkVisibility()), right: bar && at ? Math.round(bar.right - at.right) : null,
        note: document.getElementById("gate-note")?.textContent || "" };
    });
    check("/admin signed out: Sign in in its bar, at the far right", bar.shown && bar.right !== null && bar.right < 40, JSON.stringify(bar));
    await shot(page, "admin_signed_out_1280_light");
    let opened = false;
    if (bar.shown) {
      await page.locator("#gate-sign-in").click();
      const gateOpens = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
      check("/admin: the gate's Sign in opens the sign-in over the console, on /admin", gateOpens && /\/admin/.test(page.url()), page.url());
      if (gateOpens) {
        await page.locator("dialog.sign-in .foot button").click();
        await until(page, () => !document.querySelector("dialog.sign-in"), null, 3000);
      }
      await pressAt(page, "#sign-in", false);
      opened = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
    }
    const coded = opened && await toCode(page, second);
    if (coded) {
      await page.locator("dialog.sign-in .code-boxes input").first().focus();
      await page.keyboard.type(await codeFor(second));
    }
    const asked = coded && await until(page, () => !document.querySelector("dialog.sign-in")
      && /cannot see this page/.test(document.getElementById("gate-note")?.textContent || ""), null, 45000);
    const after = await page.evaluate(() => ({ url: location.pathname + location.hash, kept: window.__kept === true,
      bar: Boolean(document.getElementById("sign-in")?.checkVisibility()), note: document.getElementById("gate-note")?.textContent || "",
      dialog: document.querySelector("dialog.sign-in form .said")?.textContent ?? null }));
    check("/admin: signed in from its bar in place, the console asked again with the sign-in, still on /admin#people, no reload",
      asked && after.url === "/admin#people" && after.kept && !after.bar, JSON.stringify(after));
    await made.close();
  }

  // 8. Four codes asked for an address in fifteen minutes lock it (the
  // limit stays: it protects people). Said when to try again, by the
  // person's clock, not "a few minutes" (sifix).
  if (only.includes("limit") && !deployed) {
    const made = await context(1280, "light");
    const free = new Date(Date.now() + 14 * 60000).toISOString();
    await made.route(`${site}/api/otp`, (route) => route.fulfill({ status: 429, contentType: "application/json",
      body: JSON.stringify({ error: "Too many codes asked for. Wait a few minutes and try again.", retry_at: free }) }));
    const page = await made.newPage();
    listen(page, "limit");
    await page.goto(`${site}/faq`, { waitUntil: "load", timeout: 120000 });
    await headerSignIn(page, false);
    await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
    await page.locator("dialog.sign-in input[type=email]").fill(person);
    await page.locator("dialog.sign-in button[type=submit]").click();
    await until(page, () => document.querySelector("dialog.sign-in form .said")?.textContent, null, 10000);
    const time = await page.evaluate((iso) => new Date(iso).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), free);
    const said = await saidIn(page);
    check(`a locked address is told when to try again: "Try again after ${time}"`,
      said.said.includes(`Try again after ${time}`) && said.tone === "bad" && !/few minutes/.test(said.said), JSON.stringify(said));
    await shot(page, "limit_1280_light");
    await made.close();
  }

  // 9. A field's edge (WCAG 1.4.11, 3:1; sifix: 1.7:1 in light and 1.5:1 in
  // dark), the email's and a code box's, on the dialog and on its own fill.
  if (only.includes("edge") && !deployed) {
    for (const theme of ["light", "dark"]) {
      const made = await context(1280, theme);
      const page = await made.newPage();
      listen(page, `edge ${theme}`);
      await page.goto(`${site}/faq`, { waitUntil: "load", timeout: 120000 });
      await headerSignIn(page, false);
      await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
      const edgeOf = (selector) => page.evaluate((chosen) => {
        const parse = (c) => (c.match(/[\d.]+/g) || []).map(Number);
        const over = ([r, g, b, a = 1], [R, G, B]) => [r * a + R * (1 - a), g * a + G * (1 - a), b * a + B * (1 - a)];
        const lum = (rgb) => rgb.map((v) => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; })
          .reduce((s, v, i) => s + v * [0.2126, 0.7152, 0.0722][i], 0);
        const ratio = (x, y) => { const [p, q] = [lum(x), lum(y)].sort((m, n) => n - m); return +((p + 0.05) / (q + 0.05)).toFixed(2); };
        const field = document.querySelector(chosen);
        const ground = parse(getComputedStyle(document.querySelector("dialog.sign-in")).backgroundColor);
        const fill = over(parse(getComputedStyle(field).backgroundColor), ground);
        const edge = over(parse(getComputedStyle(field).borderTopColor), fill);
        return { onDialog: ratio(edge, ground), onFill: ratio(edge, fill), edge: getComputedStyle(field).borderTopColor };
      }, selector);
      await page.mouse.move(1, 1);
      // Not the one being typed in: its edge is the accent's.
      await page.locator("dialog.sign-in .foot button").focus();
      // Its edge's change of colour run to its end.
      await page.waitForTimeout(500);
      const email = await edgeOf("dialog.sign-in input[type=email]");
      await toCode(page);
      const box = await edgeOf("dialog.sign-in .code-boxes input:nth-child(4)");
      check(`${theme}: a field's edge is 3:1 or more on the dialog and on its fill: the email ${email.onDialog}/${email.onFill}, a code box ${box.onDialog}/${box.onFill}`,
        Math.min(email.onDialog, email.onFill, box.onDialog, box.onFill) >= 3, JSON.stringify({ email, box }));
      await shot(page, `edge_code_1280_${theme}`);
      await made.close();
    }
  }

  // 10. The connector's sign-in page (/oauth/authorize, web/authorize.js),
  // the site as design_stand_in.mjs stands it in: a code short of digits is
  // never sent, said as the dialog says it (sifix: the page sent it); and
  // the last refusal's red line goes as the next code is checked (sifix: it
  // stayed under "Signing in…").
  const stand = !deployed && (only.includes("consent") || only.includes("stale")) ? await import("./design_stand_in.mjs") : null;
  const checkout = path.join(path.dirname(new URL(import.meta.url).pathname), "../..");
  if (only.includes("consent") && !deployed) {
    // The page in a browser of its own, at its code step: the codes it
    // sent to the verify, and [hold] how long their answers are held.
    const atCode = async () => {
      const made = await browser.newContext({ viewport: { width: 1280, height: 800 } });
      await stand.serveSite(made, { web: args.web || path.join(checkout, "web"), api: path.join(checkout, "api") });
      const sent = { tokens: [], hold: 0 };
      await made.route(`${stand.DB}/auth/v1/verify`, async (route) => {
        sent.tokens.push(route.request().postDataJSON()?.token);
        if (sent.hold) await new Promise((done) => setTimeout(done, sent.hold));
        return route.fallback();
      });
      const page = await made.newPage();
      listen(page, "consent");
      const asked = new URL(`${stand.ORIGIN}/oauth/authorize`);
      for (const [k, v] of Object.entries({ response_type: "code", client_id: "https://claude.ai/oauth/mcp-oauth-client-metadata",
        redirect_uri: "https://claude.ai/api/mcp/auth_callback", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256", state: "signin-flow", scope: "build" })) asked.searchParams.set(k, v);
      await page.goto(asked.href, { waitUntil: "load", timeout: 120000 });
      await page.waitForSelector("#email-step:not(.hide)", { timeout: 30000 });
      await page.fill("#email", person);
      await page.click("#send");
      await page.waitForSelector("#code-step:not(.hide)", { timeout: 30000 });
      await page.locator("#code-1").focus();
      return { made, page, sent };
    };
    const sayOf = (page) => page.evaluate(() => ({ say: document.getElementById("say")?.textContent || "",
      bad: Boolean(document.getElementById("say")?.classList.contains("bad")),
      step: ["email-step", "code-step", "allow-step"].find((id) => !document.getElementById(id)?.classList.contains("hide")) || "",
      focus: [...document.querySelectorAll("#code-step .code-box")].indexOf(document.activeElement) }));

    // A refused code, then the next one: its red line gone while it is checked.
    {
      const { made, page, sent } = await atCode();
      await page.keyboard.type(stand.WRONG_CODE);
      const refused = await until(page, () => document.getElementById("say")?.classList.contains("bad")
        && document.querySelector("#code-step .code-boxes")?.getAttribute("aria-busy") !== "true", null, 15000);
      sent.hold = 1200;
      await page.keyboard.type("1234567");
      await page.keyboard.press("8");
      for (let n = 0; n < 30 && sent.tokens.length < 2; n++) await page.waitForTimeout(100);
      await page.waitForTimeout(300);
      const during = await sayOf(page);
      check("consent page: a code refused, the next one checked: the refusal's red line gone while it is",
        refused && sent.tokens.length === 2 && during.step === "code-step" && !during.bad && !/wrong/.test(during.say),
        JSON.stringify({ tokens: sent.tokens, ...during }));
      const allowed = await until(page, () => !document.getElementById("allow-step")?.classList.contains("hide"), null, 30000);
      check("consent page: the right code signs in, Allow asked", allowed);
      await made.close();
    }
    // Three digits of eight and Sign in: nothing sent, all eight asked for.
    {
      const { made, page, sent } = await atCode();
      await page.keyboard.type("123");
      await page.click("#verify");
      await page.waitForTimeout(600);
      const short = await sayOf(page);
      check("consent page: Sign in with three digits of eight sends nothing and asks for all eight",
        sent.tokens.length === 0 && short.step === "code-step" && /Enter all 8 digits/.test(short.say) && short.focus === 3,
        JSON.stringify({ tokens: sent.tokens, ...short }));
      await made.close();
    }
  }

  // 11. A stale answer (sifix: a read still out when Like was pressed drew
  // it unpressed after it went through; follow.js the same). Stood in only,
  // on the stand-in's model, never a real person's: signed in from the
  // header, the page's reads of how it stands are held; Like and Follow are
  // pressed and answered; then the held reads answer what was. The page
  // keeps what the presses made.
  if (only.includes("stale") && !deployed) {
    const made = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await stand.serveSite(made, { web: args.web || path.join(checkout, "web"), api: path.join(checkout, "api") });
    const held = [];
    let holding = true;
    await made.route(`${stand.ORIGIN}/api/people*`, async (route) => {
      const op = new URL(route.request().url()).searchParams.get("op");
      const mine = route.request().headers().authorization;
      if (holding && mine && ["marks", "follows"].includes(op) && !held.some((one) => one.op === op)) {
        await new Promise((release) => held.push({ op, release }));
      }
      return route.fallback();
    });
    const page = await made.newPage();
    listen(page, "stale");
    await page.goto(`${stand.ORIGIN}/m/${stand.MODEL_ID}`, { waitUntil: "load", timeout: 120000 });
    await page.locator('[data-mark="like"]').waitFor({ timeout: 30000 });
    await headerSignIn(page, false);
    await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
    await page.locator("dialog.sign-in input[type=email]").fill(stand.EMAIL);
    await page.locator("dialog.sign-in button[type=submit]").click();
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility(), null, 15000);
    await page.locator("dialog.sign-in .code-boxes input").first().focus();
    await page.keyboard.type("12345678");
    await until(page, () => !document.querySelector("dialog.sign-in"), null, 15000);
    for (let n = 0; n < 50 && held.length < 2; n++) await page.waitForTimeout(100);
    const both = held.length;
    holding = false;
    const follow = page.locator("button[data-follow]:visible").first();
    const hasFollow = await follow.count().then((n) => n > 0);
    await page.locator('[data-mark="like"]').click();
    await until(page, () => !document.querySelector('[data-mark="like"]')?.disabled, null, 10000);
    if (hasFollow) {
      await follow.click();
      await until(page, () => ![...document.querySelectorAll("button[data-follow]")].find((one) => one.checkVisibility())?.disabled, null, 10000);
    }
    const pressed = await page.evaluate(() => ({ like: document.querySelector('[data-mark="like"]')?.getAttribute("aria-pressed"),
      follow: [...document.querySelectorAll("button[data-follow]")].find((one) => one.checkVisibility())?.getAttribute("aria-pressed") || null }));
    for (const one of held) one.release();
    await page.waitForTimeout(1500);
    const after = await page.evaluate(() => ({ like: document.querySelector('[data-mark="like"]')?.getAttribute("aria-pressed"),
      follow: [...document.querySelectorAll("button[data-follow]")].find((one) => one.checkVisibility())?.getAttribute("aria-pressed") || null }));
    check(`a read answered after Like (and Follow) went through is dropped: pressed ${JSON.stringify(pressed)}, after ${JSON.stringify(after)} (${both} reads held)`,
      both >= 1 && pressed.like === "true" && after.like === pressed.like && after.follow === pressed.follow, JSON.stringify({ held: held.map((one) => one.op) }));
    await made.close();
  }

  // 4. orangecheck's window, stood in.
  if (only.includes("orangecheck") && !deployed) {
    const sizes = allSizes ? [[1280, false], [768, false], [430, true]] : [[1280, false], [430, true]];
    for (const [width, phone] of sizes) {
      for (const theme of ["light", "dark"]) {
        const label = `${width} ${theme}`;
        const at = `${width}_${theme}`;
        const made = await context(width, theme, { touch: phone });
        const page = await made.newPage();
        listen(page, `orangecheck ${label}`);
        let windows = 0;
        page.on("popup", () => { windows += 1; });
        await page.goto(`${site}/faq`, { waitUntil: "load", timeout: 120000 });
        // Opened as the page's header opens it, or by /profile on an older copy.
        await headerSignIn(page, phone);
        if (!(await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 4000))) {
          await page.goto(`${site}/profile`, { waitUntil: "load" });
          if (!(await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 4000))) await page.click("#sign-in");
        }
        await page.locator("#oc-sign-in svg[data-oc-mark]").waitFor({ timeout: 15000 }).catch(() => null);
        const ways = await page.evaluate(() => {
          // Layout sizes, not the box on screen: the dialog rises in at 0.98
          // of its size (site.css), and a loaded box measured it mid-rise,
          // 363x43 for 368x44 (2026-11-14).
          const size = (one) => [one.offsetWidth, one.offsetHeight];
          const goes = document.querySelector("dialog.sign-in button[type=submit]");
          const ocs = document.querySelector("#oc-sign-in");
          const or = document.querySelector("dialog.sign-in .or");
          return { go: size(goes), oc: size(ocs),
            or: Boolean(or?.checkVisibility()) && /\bor\b/.test(or.textContent),
            below: ocs.getBoundingClientRect().top > goes.getBoundingClientRect().bottom,
            mark: Math.round(document.querySelector("#oc-sign-in svg")?.getBoundingClientRect().width || 0) };
        });
        if (theme === "light") {
          check(`${label}: email and orangecheck are two equal ways in, "or" between: ${ways.go} and ${ways.oc}`,
            ways.or && ways.below && ways.go[0] === ways.oc[0] && ways.go[1] === ways.oc[1] && ways.oc[1] >= 44 && ways.mark >= 20,
            JSON.stringify(ways));
        }
        await page.mouse.move(1, 1);
        await shot(page, `oc_idle_${at}`);

        // Waiting, brought back, cancelled.
        windowAnswer = "stay";
        const [first] = await Promise.all([page.waitForEvent("popup", { timeout: 30000 }).catch(() => null), page.locator("#oc-sign-in").click()]);
        await page.waitForTimeout(400);
        const waiting = await page.evaluate(() => {
          const panel = document.querySelector("dialog.sign-in .waiting");
          const buttons = [...(panel?.querySelectorAll("button") || [])].filter((one) => one.checkVisibility()).map((one) => one.textContent.trim());
          return { shown: Boolean(panel?.checkVisibility()), said: panel?.textContent.replace(/\s+/g, " ").trim() || "",
            buttons, focus: document.activeElement?.textContent?.trim() || "",
            ways: Boolean(document.querySelector("dialog.sign-in form")?.checkVisibility()) };
        });
        check(`${label}: while orangecheck's window is open the dialog says so, with Show the window and Cancel`,
          Boolean(first) && waiting.shown && /Finish signing in in the orangecheck window/.test(waiting.said)
          && waiting.buttons.includes("Show the orangecheck window") && waiting.buttons.includes("Cancel") && !waiting.ways,
          JSON.stringify(waiting));
        await shot(page, `oc_waiting_${at}`);
        if (waiting.shown) {
          await page.locator("dialog.sign-in .waiting button", { hasText: "Show the orangecheck window" }).click();
          await page.waitForTimeout(400);
          check(`${label}: Show the orangecheck window brings the same window back, no second one`,
            windows === 1 && first && !first.isClosed());
          await page.locator("dialog.sign-in .waiting button", { hasText: "Cancel" }).click();
          const back = await until(page, () => document.querySelector("dialog.sign-in form")?.checkVisibility()
            && !document.querySelector("dialog.sign-in .waiting")?.checkVisibility() && document.activeElement?.id === "oc-sign-in", null, 4000);
          check(`${label}: Cancel closes the window and puts the dialog back as it was`, back && first.isClosed());
        }

        // Closed unfinished.
        const [second] = await Promise.all([page.waitForEvent("popup", { timeout: 30000 }).catch(() => null), page.locator("#oc-sign-in").click()]);
        await page.waitForTimeout(400);
        await second?.close();
        const closed = await until(page, () => document.querySelector("dialog.sign-in form")?.checkVisibility()
          && /closed before you finished/.test(document.querySelector("dialog.sign-in .oc-said")?.textContent || ""), null, 15000);
        const calm = await page.evaluate(() => {
          const line = document.querySelector("dialog.sign-in .oc-said");
          const ink = getComputedStyle(document.querySelector("dialog.sign-in .lead") || document.body).color;
          return { tone: line?.dataset.tone, colour: line ? getComputedStyle(line).color : "", ink, focus: document.activeElement?.id,
            waiting: Boolean(document.querySelector("dialog.sign-in .waiting")?.checkVisibility()) };
        });
        check(`${label}: closed unfinished, the dialog back as it was, a calm line in orangecheck's words, the focus on its button`,
          closed && calm.tone === "calm" && calm.focus === "oc-sign-in" && !calm.waiting, JSON.stringify(calm));
        await page.mouse.move(1, 1);
        await shot(page, `oc_closed_${at}`);

        // Blocked.
        await page.evaluate(() => {
          window.__open = window.open;
          window.open = () => null;
        });
        await page.locator("#oc-sign-in").click();
        const blocked = await until(page, () => /blocked the sign-in window/.test(document.querySelector("dialog.sign-in .oc-said")?.textContent || ""), null, 15000);
        const told = await page.evaluate(() => {
          const line = document.querySelector("dialog.sign-in .oc-said");
          return { tone: line?.dataset.tone, role: line?.getAttribute("role"), focus: document.activeElement?.id,
            boxed: line ? getComputedStyle(line).borderLeftWidth : "" };
        });
        check(`${label}: a blocked window is a callout in orangecheck's words, with how to allow it, the focus on its button`,
          blocked && told.tone === "blocked" && told.role === "alert" && told.focus === "oc-sign-in" && told.boxed !== "0px", JSON.stringify(told));
        await page.mouse.move(1, 1);
        await shot(page, `oc_blocked_${at}`);
        await page.evaluate(() => {
          window.open = window.__open;
        });

        // The server refuses the token.
        windowAnswer = "token";
        exchangeAnswer = "refuse";
        await page.locator("#oc-sign-in").click();
        const refused = await until(page, () => /could not confirm/.test(document.querySelector("dialog.sign-in .oc-said")?.textContent || ""), null, 10000);
        const bad = await page.evaluate(() => {
          const line = document.querySelector("dialog.sign-in .oc-said");
          return { tone: line?.dataset.tone, focus: document.activeElement?.id, open: document.querySelector("dialog.sign-in")?.open,
            again: !document.querySelector("#oc-sign-in")?.hasAttribute("aria-busy") };
        });
        check(`${label}: a refused sign-in says what happened in plain words, its button there to try again`,
          refused && bad.tone === "bad" && bad.focus === "oc-sign-in" && bad.open && bad.again, JSON.stringify(bad));
        await page.mouse.move(1, 1);
        await shot(page, `oc_error_${at}`);

        // Signed in: no flash of the signed-out header.
        exchangeAnswer = "ok";
        await page.evaluate(() => {
          window.__flash = null;
          new MutationObserver((changes, watching) => {
            if (document.querySelector("dialog.sign-in")) return;
            window.__flash = [...document.querySelectorAll(".site-head a[data-account]")].some((one) => one.checkVisibility());
            watching.disconnect();
          }).observe(document.body, { childList: true });
        });
        const from = page.url();
        await page.locator("#oc-sign-in").click();
        const inside = await until(page, () => !document.querySelector("dialog.sign-in") && window.__flash !== null, null, 10000);
        const header = await avatar(page);
        const flash = await page.evaluate(() => window.__flash);
        check(`${label}: signed in with orangecheck, the dialog gone, the same page, the avatar there the moment it goes`,
          inside && page.url() === from && header.avatar && flash === false, `${JSON.stringify(header)} flash ${flash}`);
        await page.waitForTimeout(300);
        await shot(page, `oc_signed_in_${at}`);
        windowAnswer = "stay";
        await made.close();
      }
    }
  }
} catch (trouble) {
  check(`ran to the end (${String(trouble).split("\n")[0]})`, false);
} finally {
  await browser.close();
  served?.close();
  if (deployed) {
    await session_.deleteAccount(person).catch(() => null);
    await session_.deleteAccount(second).catch(() => null);
  }
}

check("no script errors on any page", errors.length === 0, errors.slice(0, 3).join(" | "));
console.log(failed ? `signin_flow: ${failed} FAILED` : "signin_flow: all ok");
process.exit(failed ? 1 : 0);
