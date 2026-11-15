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
//      it was. Signed in there, the page is the same page and the header
//      shows the avatar, with no reload.
//   2. A signed-out visit to /profile opens the dialog by itself.
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
const only = String(args.only || "header,profile,code,orangecheck").split(",");

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
    if (op === "feed_count") return json(route, 200, { signed_in: true, me: { handle: "builder", name: "A Builder" }, count: 0 });
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
const session_ = deployed ? await import("./session.mjs") : null;
if (deployed) await session_.mintSession(person, { age: true, welcome: true });
const codeFor = async () => (deployed ? session_.mintCode(person) : RIGHT);

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

/// Open the header's Sign in: the bar's link, or on a phone the Menu's.
async function headerSignIn(page, phone) {
  const press = (selector) => pressAt(page, selector, phone);
  if (phone) {
    await press(".site-head .menu summary");
    await page.locator(".site-head .menu a[data-account]").waitFor({ state: "visible", timeout: 5000 });
    await press(".site-head .menu a[data-account]");
  } else {
    await press(".site-head .nav a[data-account]");
  }
}

/// The address typed and Email me a code pressed: true once the code is asked for.
async function toCode(page) {
  await page.locator("dialog.sign-in input[type=email]").fill(person);
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
    await page.waitForTimeout(500);
    const header = await avatar(page);
    check(`${label}: signed in, the same page, the header the avatar, no reload`,
      page.url() === before.url && header.avatar && !header.signIn && await page.evaluate(() => window.__kept === true),
      `${page.url()} ${JSON.stringify(header)}`);
    await shot(page, `signed_in_${width}_${theme}`);
    await made.close();
  }

  // 2. A signed-out /profile.
  if (only.includes("profile")) {
    for (const width of [1280, 430]) {
      const made = await context(width, "light", { touch: width < 600 });
      const page = await made.newPage();
      listen(page, `profile ${width}`);
      await page.goto(`${site}/profile`, { waitUntil: "load", timeout: 120000 });
      const opened = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 10000);
      check(`${width}: a signed-out /profile opens the sign-in by itself`, opened);
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
          const r = (one) => one?.getBoundingClientRect();
          const go = r(document.querySelector("dialog.sign-in button[type=submit]"));
          const oc = r(document.querySelector("#oc-sign-in"));
          const or = document.querySelector("dialog.sign-in .or");
          return { go: [Math.round(go.width), Math.round(go.height)], oc: [Math.round(oc.width), Math.round(oc.height)],
            or: Boolean(or?.checkVisibility()) && /\bor\b/.test(or.textContent), below: oc.top > go.bottom,
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
  if (deployed) await session_.deleteAccount(person).catch(() => null);
}

check("no script errors on any page", errors.length === 0, errors.slice(0, 3).join(" | "));
console.log(failed ? `signin_flow: ${failed} FAILED` : "signin_flow: all ok");
process.exit(failed ? 1 : 0);
