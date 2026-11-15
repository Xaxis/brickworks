// sireview (2026-11-15): attacks on signinux's sign-in dialog, stood in
// (this checkout's web/ served here, or --web=<dir>, an older copy; /api/*,
// Supabase and orangecheck's window answered here). Made checks by sifix:
// each case says what it must see, and the run exits 1 on any failure.
//
//   node tools/web/sirev_standin.mjs --out=DIR [--only=paste,fill,...] [--web=DIR]
//
// paste   one rule for a pasted code (web/code-boxes.js readCode): a run of
//         exactly eight digits, one space or dash allowed inside, is sent,
//         the email's words around it or not; anything else is laid from the
//         first box and waits.
// fill    the one-time-code fill into the first box, by each way a browser
//         fills it, a digit typed there first or not: sent once.
// keys    typing, Backspace across boxes, the arrows, Home/End, Delete, a
//         letter refused; eight digits then Enter twice send once.
// wrong   a wrong code: read-only while checked, Escape keeps the dialog,
//         emptied, the focus to the first box, said; a refusal for asking
//         too often keeps the digits, and the last digit typed again sends.
// limit   four codes asked for in fifteen minutes: when to try again, by the
//         clock ("Try again after 14:32"), asking and asking again.
// a11y    the address and code steps' names, Tab kept in the dialog, and
//         contrast: words 4.5:1, the boxes' edge 3:1, in both themes.
// phone   390 and 320 wide: the dialog fits, no sideways scroll.
// oc2     orangecheck's window: closed, refused, Cancel, signed in in place.
// wrong2  as wrong, each step waited on as it happens.
// header2 signed in from the header 400 px down: the page stays there.
// signout signing out on /profile opens no dialog.
// tab2    Tab and Shift+Tab stay in the dialog; a code box's edge is a field's.
// header3 a mouse's press, the header's count answered at once or late: the
//         page stays where it was and the focus never falls to the page.
// focusjump every focus() and scroll logged: nothing moves the page.
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "sirev_out";
mkdirSync(out, { recursive: true });
const only = args.only ? String(args.only).split(",") : null;
const want = (name) => !only || only.includes(name);
const served = await serveDir(args.web || path.join(path.dirname(new URL(import.meta.url).pathname), "../../web"));
const site = served.url;
const results = [];
let failed = 0;
const note = (what, ok, detail = "") => {
  results.push({ what, ok, detail });
  if (ok === false) failed += 1;
  console.log(`  ${ok === true ? "ok  " : ok === false ? "FAIL" : "info"}  ${what}${detail ? `: ${typeof detail === "string" ? detail : JSON.stringify(detail)}` : ""}`);
};
const until = (page, test, arg = null, ms = 6000) => page.waitForFunction(test, arg, { timeout: ms, polling: 100 })
  .then(() => true, () => false);

const SUPABASE = "https://stand-in.supabase.test";
const RIGHT = "12345678";
const LIMITED = "99999999";
const OC = "https://me.ochk.io";
const state = { verified: [], otp: "ok", exchange: "ok", admin: false, verifyMs: 600, digits: 8, windowAnswer: "stay", feedMs: 0 };
// When a locked address may ask again (api/otp.js retry_at).
const FREE = new Date(Date.now() + 14 * 60000).toISOString();

const session = (email) => ({ access_token: `at-${Math.random().toString(16).slice(2)}`, refresh_token: "rt",
  expires_in: 3600, token_type: "bearer", user: { id: "00000000-0000-4000-8000-000000000001", email } });

async function standIn(context) {
  const json = (route, status, body) => route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
  await context.route(`${site}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    const auth = route.request().headers().authorization;
    if (url.pathname === "/api/account") {
      if (auth) return json(route, 200, { signed_in: true, age: { ask: false, over_13: true }, beta: null });
      return json(route, 200, { enabled: true, url: SUPABASE, key: "k", orangecheck: { ready: true, everyone: true, connect: true } });
    }
    if (url.pathname === "/api/otp") {
      if (state.otp === "limit") {
        return json(route, 429, { error: "Too many codes asked for. Wait a few minutes and try again.", retry_at: FREE });
      }
      return json(route, 200, { ok: true, expires_in_minutes: 10, digits: state.digits });
    }
    if (url.pathname === "/api/people" && url.searchParams.get("op") === "feed_count") {
      if (state.feedMs) await new Promise((done) => setTimeout(done, state.feedMs));
      return json(route, 200, { signed_in: true, me: { handle: "builder", name: "A Builder" }, count: 0, ...(state.admin ? { admin: true } : {}) });
    }
    if (url.pathname === "/api/orangecheck" && url.searchParams.get("op") === "signin") {
      return state.exchange === "ok" ? json(route, 200, session("0123@oc.brickworks.diy"))
        : json(route, 503, { error: "orangecheck could not confirm the sign-in just now. Try again in a minute." });
    }
    return json(route, 503, { error: "stood in" });
  });
  await context.route(`${SUPABASE}/**`, async (route) => {
    const url = new URL(route.request().url());
    const body = route.request().postDataJSON() || {};
    if (url.pathname === "/auth/v1/verify") {
      state.verified.push(body.token);
      await new Promise((done) => setTimeout(done, state.verifyMs));
      if (body.token === LIMITED) return json(route, 429, { code: 429, error_code: "over_request_rate_limit", msg: "Too many requests" });
      return body.token === RIGHT ? json(route, 200, session(body.email))
        : json(route, 403, { code: 403, error_code: "otp_expired", msg: "Token has expired or is invalid" });
    }
    if (url.pathname === "/auth/v1/token") return json(route, 200, session("builder@example.org"));
    return json(route, 404, {});
  });
  await context.route(`${OC}/**`, (route) => route.fulfill({ status: 200, contentType: "text/html", body: `<!doctype html>
<title>oc stand-in</title><body>orangecheck, stood in.<script>
window.answer = () => opener.postMessage({ type: "oc-signin-success", account: { did: "did:oc:x" }, token: "oc-token" }, "*");
${state.windowAnswer === "token" ? "setTimeout(window.answer, 400);" : ""}</script>` }));
}

const browser = await launch({ signedOut: true });
async function fresh(width = 1280, { theme = "light", touch = false, height = null } = {}) {
  const context = await browser.newContext({ viewport: { width, height: height || (width < 600 ? 844 : 900) }, colorScheme: theme,
    ...(touch ? { isMobile: true, hasTouch: true } : {}) });
  await standIn(context);
  await context.addInitScript(contrastMaths);
  const page = await context.newPage();
  page.errors = [];
  page.on("pageerror", (e) => page.errors.push(String(e).slice(0, 200)));
  return { context, page };
}
async function openDialog(page, at = "/faq") {
  await page.goto(`${site}${at}`, { waitUntil: "load" });
  await page.evaluate(() => { window.__kept = 1; });
  await page.locator(".site-head .nav a[data-account]").click();
  return until(page, () => document.querySelector("dialog.sign-in")?.open);
}
async function toCode(page, email = "builder@example.org") {
  await page.locator("dialog.sign-in input[type=email]").fill(email);
  await page.locator("dialog.sign-in form.by-email button[type=submit]").click();
  return until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility());
}
const boxes = (page) => page.evaluate(() => {
  const row = document.querySelector("dialog.sign-in .code-boxes");
  const all = [...(row?.querySelectorAll("input") || [])];
  return { values: all.map((b) => b.value).join("|"), focus: all.indexOf(document.activeElement), readOnly: all.some((b) => b.readOnly),
    said: document.querySelector("dialog.sign-in form .said")?.textContent || "", tone: document.querySelector("dialog.sign-in form .said")?.dataset.tone || "",
    open: Boolean(document.querySelector("dialog.sign-in")?.open) };
});
const pasteText = (page, text) => page.evaluate((words) => {
  const data = new DataTransfer();
  data.setData("text/plain", words);
  document.activeElement.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }));
}, text);
// Each Tab moved the focus on: no control twice running (a box's select()
// a frame late took the focus back to it, sifix).
const movedOn = (seen) => seen.every((one, i) => i === 0 || one.name !== seen[i - 1].name);
const row = (digits) => Array.from({ length: 8 }, (_, i) => digits[i] || "").join("|");
// What the page's focus is, and whether it is inside the dialog.
const where = (page) => page.evaluate(() => {
  const a = document.activeElement;
  return { tag: a?.tagName || "", inDialog: Boolean(a?.closest("dialog.sign-in")),
    name: `${(a?.tagName || "").toLowerCase()}:${(a?.getAttribute("aria-label") || a?.textContent || a?.type || "").trim().slice(0, 28)}` };
});
// Contrast (WCAG), a colour with alpha laid over what is under it: put on
// each page before its own scripts (a page's policy may refuse eval).
function contrastMaths() {
  const parse = (c) => (c.match(/[\d.]+/g) || []).map(Number);
  const over = ([r, g, b, a = 1], [R, G, B]) => [r * a + R * (1 - a), g * a + G * (1 - a), b * a + B * (1 - a)];
  const lum = (rgb) => rgb.slice(0, 3).map((v) => { v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; })
    .reduce((s, v, i) => s + v * [0.2126, 0.7152, 0.0722][i], 0);
  const ratio = (x, y) => { const [p, q] = [lum(x), lum(y)].sort((m, n) => n - m); return +((p + 0.05) / (q + 0.05)).toFixed(2); };
  window.__contrast = { parse, over, ratio };
}

try {
  // 1. Pastes of every shape, from the first box and from the fourth:
  // [text, the box it is pasted in, sent, what the boxes hold after].
  if (want("paste")) {
    for (const [text, from, sent, laid] of [[" 1234 5678\n", 0, true, RIGHT], ["1234-5678", 0, true, RIGHT],
      ["\n12345678 ", 3, true, RIGHT], ["123456", 0, false, "123456"], ["123456789", 0, false, RIGHT],
      ["abcdefgh", 0, false, ""], ["Your code: 12345678", 0, true, RIGHT], ["Expires in 10 min. Code 12345678", 0, true, RIGHT],
      ["Your Brickworks sign-in code is 12345678. It works once and expires in 10 minutes.", 0, true, RIGHT],
      ["1234567", 2, false, "1234567"], ["12 34 56 78 9", 0, false, RIGHT]]) {
      const { context, page } = await fresh();
      await openDialog(page);
      await toCode(page);
      await page.locator(`dialog.sign-in .code-boxes input >> nth=${from}`).focus();
      state.verified = [];
      await pasteText(page, text);
      if (sent) await until(page, () => !document.querySelector("dialog.sign-in"), null, 6000);
      else await page.waitForTimeout(1200);
      const got = await boxes(page);
      const ok = sent ? state.verified.length === 1 && state.verified[0] === RIGHT && !got.open
        : state.verified.length === 0 && got.open && got.values === row(laid);
      note(`paste ${JSON.stringify(text)} at box ${from + 1}: ${sent ? "sent" : `laid ${laid || "nothing"}, not sent`}`, ok,
        { sent: state.verified, boxes: got.values, focus: got.focus, open: got.open, said: got.said });
      await context.close();
    }
  }

  // 2. The one-time-code fill into the first box, as a browser fills it:
  // replacing what the box holds, or put after a digit typed there first,
  // or as one insertText. Each sends the code once.
  if (want("fill")) {
    for (const [how, before] of [["replace", ""], ["replace", "5"], ["append", "5"], ["insertText", ""]]) {
      const { context, page } = await fresh();
      await openDialog(page);
      await toCode(page);
      if (before) {
        await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
        await page.keyboard.type(before);
      }
      state.verified = [];
      await page.evaluate(([how, code]) => {
        const box = document.querySelector("dialog.sign-in .code-boxes input");
        if (how === "insertText") {
          box.value = code;
          box.dispatchEvent(new InputEvent("input", { inputType: "insertText", data: code, bubbles: true }));
        } else {
          box.value = how === "append" ? box.value + code : code;
          box.dispatchEvent(new InputEvent("input", { inputType: "insertReplacementText", bubbles: true }));
        }
      }, [how, RIGHT]);
      await until(page, () => !document.querySelector("dialog.sign-in"), null, 6000);
      const got = await boxes(page);
      note(`one-time-code fill (${how}, "${before}" typed in the box first): sent once`,
        state.verified.length === 1 && state.verified[0] === RIGHT && !got.open, { sent: state.verified, boxes: got.values, open: got.open });
      await context.close();
    }
  }

  // 3. Keys: typing, Backspace across, arrows, over a filled box, a letter.
  if (want("keys")) {
    const { context, page } = await fresh();
    await openDialog(page);
    await toCode(page);
    state.verified = [];
    const steps = [];
    const step = async (key) => {
      await page.keyboard.press(key);
      const got = await boxes(page);
      steps.push(`${key}->${got.values}@${got.focus}`);
    };
    for (const k of ["1", "2", "3", "a", " ", "Backspace", "Backspace", "ArrowRight", "4", "ArrowLeft", "ArrowLeft", "9", "End", "Home", "Delete"]) await step(k);
    const expect = [["1", "1", 1], ["2", "12", 2], ["3", "123", 3], ["a", "123", 3], [" ", "123", 3], ["Backspace", "12", 2],
      ["Backspace", "1", 1], ["ArrowRight", "1", 2], ["4", ["1", "", "4"], 3], ["ArrowLeft", ["1", "", "4"], 2],
      ["ArrowLeft", ["1", "", "4"], 1], ["9", "194", 2], ["End", "194", 7], ["Home", "194", 0], ["Delete", ["", "9", "4"], 0]]
      .map(([k, v, f]) => `${k}->${row(v)}@${f}`);
    note("keys: typed digits move on, a letter and a space are refused, Backspace steps back, the arrows, Home, End and Delete",
      steps.join("  ") === expect.join("  "), steps.join("  "));
    await page.evaluate(() => document.querySelectorAll("dialog.sign-in .code-boxes input").forEach((b) => { b.value = ""; b.dataset.held = ""; }));
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    state.verified = [];
    await page.keyboard.type("1234567");
    await page.keyboard.press("8");
    await page.keyboard.press("Enter");
    await page.keyboard.press("Enter");
    await page.locator("dialog.sign-in form.by-email button[type=submit]").click({ force: true, timeout: 1000 }).catch(() => null);
    await until(page, () => !document.querySelector("dialog.sign-in"), null, 6000);
    await page.waitForTimeout(500);
    note("eight digits typed then Enter, Enter, Sign in at once: verifies sent", state.verified.length === 1, state.verified);
    await context.close();
  }

  // 4. Wrong code: emptied, focus to the first box, said; then right. Escape while checking.
  if (want("wrong")) {
    const { context, page } = await fresh();
    await openDialog(page);
    await toCode(page);
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    state.verified = [];
    state.verifyMs = 1500;
    await page.keyboard.type("1111111");
    await page.keyboard.press("2");
    await page.waitForTimeout(200);
    const during = await boxes(page);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(100);
    const afterEsc = await boxes(page);
    await until(page, () => document.querySelector("dialog.sign-in form .said")?.dataset.tone === "bad", null, 8000);
    const after = await boxes(page);
    note("wrong code: read-only while checked", during.readOnly === true, during);
    note("Escape while checked keeps the dialog", afterEsc.open === true, afterEsc.open);
    note("wrong code: boxes emptied, focus box 1, said in trouble's tone, sent once",
      after.values === row("") && after.focus === 0 && after.tone === "bad" && state.verified.length === 1, { after, sent: state.verified });
    state.verifyMs = 600;
    // Refused for asking too often: the digits kept, said; the last digit
    // typed again (Backspace and 9) sends it again.
    state.verified = [];
    await pasteText(page, LIMITED);
    await until(page, () => /Too many/.test(document.querySelector("dialog.sign-in form .said")?.textContent || ""), null, 8000);
    const limited = await boxes(page);
    note("verify 429: the digits kept, sent once, said", limited.values === row(LIMITED) && state.verified.length === 1
      && /Too many/.test(limited.said) && limited.tone === "bad", { ...limited, sent: state.verified });
    state.verified = [];
    await page.locator("dialog.sign-in .code-boxes input >> nth=7").focus();
    await page.keyboard.press("Backspace");
    await page.keyboard.press("9");
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes")?.getAttribute("aria-busy") === "true", null, 3000);
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes")?.getAttribute("aria-busy") !== "true", null, 6000);
    note("after a limit, the last digit typed again sends again", state.verified.length === 1 && state.verified[0] === LIMITED,
      { sent: state.verified });
    await page.keyboard.press("Escape");
    await until(page, () => !document.querySelector("dialog.sign-in")?.open, null, 3000);
    note("Escape after: closed", !(await boxes(page)).open);
    await context.close();
  }

  // 5. The send's limit, and resend: when to try again, by the clock.
  if (want("limit")) {
    const { context, page } = await fresh();
    await openDialog(page);
    const time = await page.evaluate((iso) => new Date(iso).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), FREE);
    state.otp = "limit";
    await page.locator("dialog.sign-in input[type=email]").fill("builder@example.org");
    await page.locator("dialog.sign-in form.by-email button[type=submit]").click();
    await until(page, () => document.querySelector("dialog.sign-in form .said")?.textContent, null, 6000);
    const first = await boxes(page);
    note(`send refused by the limit: "Try again after ${time}", in trouble's tone`,
      first.said.includes(`Try again after ${time}`) && first.tone === "bad" && !/few minutes/.test(first.said), first);
    state.otp = "ok";
    await toCode(page);
    state.otp = "limit";
    await page.getByRole("button", { name: "Send a new code" }).click();
    await until(page, () => /Try again/.test(document.querySelector("dialog.sign-in form .said")?.textContent || ""), null, 6000);
    const again = await boxes(page);
    note(`resend refused by the limit: "Try again after ${time}"`, again.said.includes(`Try again after ${time}`) && again.tone === "bad", again);
    state.otp = "ok";
    await context.close();
  }

  // 6. The steps' names, Tab kept in the dialog, contrast.
  if (want("a11y")) {
    for (const theme of ["light", "dark"]) {
      const { context, page } = await fresh(1280, { theme });
      await page.addInitScript((t) => { try { localStorage.setItem("brickworks.theme", t); } catch {} }, theme);
      await openDialog(page);
      const address = await page.locator("dialog.sign-in").ariaSnapshot();
      if (theme === "light") {
        note("address step: a dialog named Sign in, the address a labelled text box (Email)",
          /dialog "Sign in/.test(address) && /textbox "Email"/.test(address), address.split("\n").slice(0, 8).join(" / "));
      }
      const order0 = [];
      for (let i = 0; i < 9; i++) {
        await page.keyboard.press("Tab");
        order0.push(await where(page));
      }
      if (theme === "light") note("Tab, address step: kept in the dialog", order0.every((one) => one.inDialog), order0.map((one) => one.name).join(" > "));
      await toCode(page);
      const code = await page.locator("dialog.sign-in").ariaSnapshot();
      if (theme === "light") {
        note("code step: one group named for the address, eight boxes Digit 1 of 8 to Digit 8 of 8",
          /group "The code sent to/.test(code) && Array.from({ length: 8 }, (_, i) => `textbox "Digit ${i + 1} of 8"`).every((one) => code.includes(one)),
          code.split("\n").slice(0, 14).join(" / "));
      }
      const order = [];
      for (let i = 0; i < 14; i++) {
        await page.keyboard.press("Tab");
        order.push(await where(page));
      }
      if (theme === "light") note("Tab, code step: kept in the dialog, each press on to the next", order.every((one) => one.inDialog) && movedOn(order),
        order.map((one) => one.name).join(" > "));
      // Contrast: the words and the boxes' edges against the dialog.
      await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
      await page.keyboard.type("1111111");
      await page.keyboard.press("2");
      await until(page, () => document.querySelector("dialog.sign-in form .said")?.dataset.tone === "bad", null, 6000);
      await page.locator("dialog.sign-in .code-links button").first().focus();
      const contrast = await page.evaluate(() => {
        const { parse, over, ratio } = window.__contrast;
        const dialog = document.querySelector("dialog.sign-in");
        const bg = parse(getComputedStyle(dialog).backgroundColor);
        const of = (el) => (el ? ratio(over(parse(getComputedStyle(el).color), bg), bg) : null);
        const box = dialog.querySelector(".code-box:nth-child(5)");
        const fill = over(parse(getComputedStyle(box).backgroundColor), bg);
        const edge = over(parse(getComputedStyle(box).borderTopColor), fill);
        box.value = "4";
        const digit = ratio(over(parse(getComputedStyle(box).color), fill), fill);
        box.value = "";
        return { said: of(dialog.querySelector("form .said")), note: of(dialog.querySelector(".code-step .note")),
          link: of(dialog.querySelector(".code-links button")), boxEdge: ratio(edge, bg), boxEdgeOnFill: ratio(edge, fill), digit,
          boxEdgeColor: getComputedStyle(box).borderTopColor };
      });
      const words = [contrast.said, contrast.note, contrast.link, contrast.digit].filter((one) => one !== null);
      note(`contrast ${theme}: words 4.5:1 or more, the boxes' edge 3:1 or more on the dialog and on its fill`,
        words.every((one) => one >= 4.5) && contrast.boxEdge >= 3 && contrast.boxEdgeOnFill >= 3, contrast);
      await page.screenshot({ path: path.join(out, `code_wrong_${theme}.png`) });
      await context.close();
    }
  }

  // 7. 390 x 844, a phone: fits, no sideways scroll; the boxes' size.
  if (want("phone")) {
    for (const width of [390, 320]) {
      const { context, page } = await fresh(width, { touch: true, height: 844 });
      await page.goto(`${site}/faq`, { waitUntil: "load" });
      await page.locator(".site-head .menu summary").tap();
      await page.locator(".site-head .menu a[data-account]").tap();
      await until(page, () => document.querySelector("dialog.sign-in")?.open);
      await toCode(page);
      const fit = await page.evaluate(() => {
        const d = document.querySelector("dialog.sign-in").getBoundingClientRect();
        const bs = [...document.querySelectorAll("dialog.sign-in .code-box")].map((b) => b.getBoundingClientRect());
        return { dialog: [Math.round(d.left), Math.round(d.right), Math.round(d.width)], vw: innerWidth, scrollW: document.documentElement.scrollWidth,
          box: bs.length ? [Math.round(bs[0].width), Math.round(bs[0].height)] : null, rowRight: bs.length ? Math.round(bs.at(-1).right) : null,
          fontSize: getComputedStyle(document.querySelector("dialog.sign-in .code-box")).fontSize };
      });
      note(`${width}x844: dialog fits, boxes`, fit.scrollW <= fit.vw && fit.rowRight <= fit.dialog[1], fit);
      await page.screenshot({ path: path.join(out, `code_${width}.png`) });
      await context.close();
    }
  }

  // 8b. orangecheck, each step waited on as it happens.
  if (want("oc2")) {
    const { context, page } = await fresh();
    await openDialog(page);
    await until(page, () => document.querySelector("#oc-sign-in")?.checkVisibility(), null, 10000);
    const ocLine = () => page.evaluate(() => ({ said: document.querySelector(".oc-said")?.textContent, tone: document.querySelector(".oc-said")?.dataset.tone,
      role: document.querySelector(".oc-said")?.getAttribute("role"), focus: document.activeElement?.id || document.activeElement?.textContent,
      waiting: !document.querySelector("dialog.sign-in .waiting").hidden, waitSaid: document.querySelector(".waiting-said")?.textContent,
      form: !document.querySelector("dialog.sign-in form.by-email").hidden, open: Boolean(document.querySelector("dialog.sign-in")?.open) }));
    const press = async () => {
      const [popup] = await Promise.all([context.waitForEvent("page", { timeout: 15000 }), page.locator("#oc-sign-in").click()]);
      await popup.waitForLoadState("load").catch(() => null);
      await until(page, () => !document.querySelector("dialog.sign-in .waiting").hidden, null, 10000);
      return popup;
    };
    // closed by the person
    let popup = await press();
    await popup.close();
    const t0 = Date.now();
    const closedOk = await until(page, () => document.querySelector(".oc-said")?.dataset.tone === "calm", null, 15000);
    note("window closed by the person: calm line, focus on orangecheck", closedOk && (await ocLine()).focus === "oc-sign-in", { ms: Date.now() - t0, ...(await ocLine()) });
    // refused by the server
    state.exchange = "refuse";
    popup = await press();
    await popup.evaluate(() => window.answer());
    const refusedOk = await until(page, () => document.querySelector(".oc-said")?.dataset.tone === "bad", null, 15000);
    note("token refused by the server: words in trouble's colour, the ways back", refusedOk && (await ocLine()).form, await ocLine());
    state.exchange = "ok";
    // Cancel, then the window answers late (a message from it after Cancel)
    popup = await press();
    await page.getByRole("button", { name: "Cancel" }).click();
    await until(page, () => document.querySelector("dialog.sign-in .waiting").hidden, null, 10000);
    note("Cancel: window closed", popup.isClosed(), await ocLine());
    // signed in
    popup = await press();
    await popup.evaluate(() => window.answer());
    const signed = await until(page, () => !document.querySelector("dialog.sign-in") && [...document.querySelectorAll(".site-head .account-btn")].some((o) => o.checkVisibility()), null, 15000);
    note("orangecheck signs in in place, no reload", signed && await page.evaluate(() => window.__kept === 1), { errors: page.errors });
    await context.close();
  }

  // 4b. Wrong code waited on, then a limit, then the last digit typed again.
  if (want("wrong2")) {
    const { context, page } = await fresh();
    await openDialog(page);
    await toCode(page);
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    state.verified = [];
    await page.keyboard.type("11111112");
    const done = await until(page, () => document.querySelector("dialog.sign-in form .said")?.dataset.tone === "bad", null, 15000);
    note("wrong code: emptied, focus box 1, said, sent once", done && (await boxes(page)).values === row("") && (await boxes(page)).focus === 0 && state.verified.length === 1,
      { ...(await boxes(page)), sent: state.verified });
    state.verified = [];
    await pasteText(page, LIMITED);
    await until(page, () => /Too many/.test(document.querySelector("dialog.sign-in form .said")?.textContent || ""), null, 15000);
    const limited = await boxes(page);
    note("verify 429: the digits kept, said", limited.values === row(LIMITED) && /Too many/.test(limited.said), limited);
    state.verified = [];
    await page.locator("dialog.sign-in .code-boxes input >> nth=7").focus();
    await page.keyboard.press("9");
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes")?.getAttribute("aria-busy") === "true", null, 3000);
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes")?.getAttribute("aria-busy") !== "true", null, 6000);
    note("after a limit, the last digit typed again into a full row sends again", state.verified.length === 1 && state.verified[0] === LIMITED,
      { sent: state.verified });
    await context.close();
  }

  // 9b. Header sign in, the page scrolled: where it is after.
  if (want("header2")) {
    state.admin = true;
    const { context, page } = await fresh();
    await page.goto(`${site}/faq`, { waitUntil: "load" });
    await page.evaluate(() => { window.__kept = 1; scrollTo(0, 400); });
    await page.waitForTimeout(300);
    const y0 = await page.evaluate(() => scrollY);
    const at = await page.locator(".site-head .nav a[data-account]").boundingBox();
    await page.mouse.click(at.x + at.width / 2, at.y + at.height / 2);
    await until(page, () => document.querySelector("dialog.sign-in")?.open);
    const y1 = await page.evaluate(() => scrollY);
    await toCode(page);
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    await pasteText(page, RIGHT);
    const signed = await until(page, () => !document.querySelector("dialog.sign-in"), null, 15000);
    const y2 = await page.evaluate(() => scrollY);
    await page.waitForTimeout(1500);
    const after = await page.evaluate(() => ({ kept: window.__kept, y: scrollY, url: location.pathname,
      admin: [...document.querySelectorAll(".site-head a")].some((a) => /\/admin/.test(a.getAttribute("href") || "")),
      focus: `${document.activeElement?.tagName}.${document.activeElement?.className}`, avatar: [...document.querySelectorAll(".site-head .account-btn")].some((o) => o.checkVisibility()) }));
    note("header sign in 400 px down: the page stays there at open, at close and after; the avatar, the owner's Admin, the focus on the avatar",
      signed && [y1, y2, after.y].every((y) => Math.abs(y - y0) <= 2) && after.kept === 1 && after.avatar && after.admin
      && /account-btn/.test(after.focus), { y0, y1, y2, ...after, signed });
    state.admin = false;
    await context.close();
  }
  // 10. Signing out on /profile: the page's own Sign in, no dialog.
  if (want("signout")) {
    const { context, page } = await fresh();
    await page.goto(`${site}/faq`, { waitUntil: "load" });
    await page.locator(".site-head .nav a[data-account]").click();
    await toCode(page);
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    await pasteText(page, RIGHT);
    await until(page, () => !document.querySelector("dialog.sign-in"), null, 15000);
    await page.goto(`${site}/profile`, { waitUntil: "load" });
    await until(page, () => [...document.querySelectorAll(".site-head .account-btn")].some((o) => o.checkVisibility()), null, 10000);
    const before = await page.evaluate(() => ({ dialog: Boolean(document.querySelector("dialog.sign-in")?.open), signed: Boolean(localStorage.getItem("brickworks.session")) }));
    await page.locator(".site-head .account-menu summary").click();
    await Promise.all([page.waitForEvent("load", { timeout: 15000 }), page.locator(".site-head .account-menu button.sign-out").click()]);
    const opened = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 4000);
    const signed = await page.evaluate(() => Boolean(localStorage.getItem("brickworks.session")));
    note("signed out from the account menu on /profile: signed out, and no sign-in dialog opens",
      before.signed && !before.dialog && !opened && !signed, { before, openedAfterSignOut: opened, signed });
    await page.screenshot({ path: path.join(out, "profile_after_sign_out.png") });
    await context.close();
  }

  // 11. Tab from the code step's last link, and Shift+Tab from the first box.
  if (want("tab2")) {
    const { context, page } = await fresh();
    await openDialog(page);
    await toCode(page);
    await page.getByRole("button", { name: "Use a different address" }).focus();
    const seq = [await where(page)];
    for (let i = 0; i < 3; i++) { await page.keyboard.press("Tab"); seq.push(await where(page)); }
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    const back = [await where(page)];
    for (let i = 0; i < 3; i++) { await page.keyboard.press("Shift+Tab"); back.push(await where(page)); }
    note("code step: Tab from the last link stays in the dialog, each press on to the next", seq.every((one) => one.inDialog) && movedOn(seq),
      seq.map((one) => one.name).join(" > "));
    note("code step: Shift+Tab from the first box stays in the dialog, each press back to the one before", back.every((one) => one.inDialog)
      && movedOn(back), back.map((one) => one.name).join(" < "));
    const edges = await page.evaluate(() => {
      const { parse, over, ratio } = window.__contrast;
      const d = document.querySelector("dialog.sign-in");
      const box = d.querySelector(".code-box:nth-child(5)");
      const email = document.createElement("input");
      email.type = "email";
      d.append(email);
      const bg = parse(getComputedStyle(d).backgroundColor);
      const of = (el) => {
        const fill = over(parse(getComputedStyle(el).backgroundColor), bg);
        const edge = over(parse(getComputedStyle(el).borderTopColor), fill);
        return { edge: getComputedStyle(el).borderTopColor, onDialog: ratio(edge, bg), onFill: ratio(edge, fill) };
      };
      const r = { codeBox: of(box), email: of(email) };
      email.remove();
      return r;
    });
    note("a code box's edge is the site's own text field's, 3:1 or more", edges.codeBox.edge === edges.email.edge
      && Math.min(edges.codeBox.onDialog, edges.codeBox.onFill) >= 3, edges);
    await context.close();
  }
  // 9c. Header sign in pressed where it is drawn (a mouse's click), the
  // header's count answered at once and after 800 ms: scroll and focus.
  if (want("header3")) {
    for (const feedMs of [0, 800]) {
      state.feedMs = feedMs;
      const { context, page } = await fresh();
      await page.goto(`${site}/faq`, { waitUntil: "load" });
      await page.evaluate(() => { window.__kept = 1; scrollTo(0, 400); });
      await page.waitForTimeout(300);
      const box = await page.locator(".site-head .nav a[data-account]").boundingBox();
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      await until(page, () => document.querySelector("dialog.sign-in")?.open);
      const y1 = await page.evaluate(() => scrollY);
      await page.locator("dialog.sign-in input[type=email]").fill("builder@example.org");
      await page.keyboard.press("Enter");
      await until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility());
      await page.keyboard.type(RIGHT);
      await until(page, () => !document.querySelector("dialog.sign-in"), null, 15000);
      const focusAt = [];
      for (const ms of [0, 300, 1500]) {
        await page.waitForTimeout(ms);
        focusAt.push(await page.evaluate(() => `${document.activeElement?.tagName}.${document.activeElement?.className}`));
      }
      const y = await page.evaluate(() => scrollY);
      note(`header sign in by mouse, feed_count after ${feedMs} ms: the page stays at 400 px and the focus on the avatar, never the page`,
        y1 === 400 && y === 400 && focusAt.every((one) => !one.startsWith("BODY")) && /account-btn/.test(focusAt.at(-1)),
        { y0: 400, y1, y, focusAt });
      await context.close();
    }
    state.feedMs = 0;
  }
  // 9d. Which call moves the page: every focus() and scroll logged.
  if (want("focusjump")) {
    const { context, page } = await fresh();
    await page.addInitScript(() => {
      window.__log = [];
      const focus = HTMLElement.prototype.focus;
      HTMLElement.prototype.focus = function logged(...how) {
        const before = scrollY;
        const r = focus.apply(this, how);
        window.__log.push(`focus ${this.tagName}.${this.className} ${JSON.stringify(how)} ${before}->${scrollY}`);
        return r;
      };
      addEventListener("scroll", () => window.__log.push(`scroll ${scrollY}`), { passive: true });
    });
    await page.goto(`${site}/faq`, { waitUntil: "load" });
    await page.evaluate(() => { scrollTo(0, 400); });
    await page.waitForTimeout(300);
    await page.evaluate(() => window.__log.push("-- at 400"));
    const box = await page.locator(".site-head .nav a[data-account]").boundingBox();
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    await until(page, () => document.querySelector("dialog.sign-in")?.open);
    await page.locator("dialog.sign-in input[type=email]").fill("builder@example.org");
    await page.keyboard.press("Enter");
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility());
    await page.evaluate(() => window.__log.push("-- typing the code"));
    await page.keyboard.type(RIGHT);
    await until(page, () => !document.querySelector("dialog.sign-in"), null, 15000);
    await page.waitForTimeout(1500);
    const log = await page.evaluate(() => window.__log);
    const since = log.slice(log.indexOf("-- at 400") + 1);
    const moved = since.filter((line) => (line.startsWith("scroll ") && line !== "scroll 400") || / (\d+)->(?!\1$)\d+$/.test(line));
    note("focus and scroll log, header sign in from 400 px down: nothing moves the page", moved.length === 0 && await page.evaluate(() => scrollY) === 400,
      (moved.length ? moved : since).filter((l, i, a) => !(l.startsWith("scroll") && a[i - 1] === l)).join(" | "));
    await context.close();
  }
} catch (trouble) {
  note(`ran to the end (${String(trouble).split("\n")[0]})`, false);
} finally {
  writeFileSync(path.join(out, "standin.json"), JSON.stringify(results, null, 1));
  await browser.close();
  served.close();
}
console.log(failed ? `sirev_standin: ${failed} FAILED` : "sirev_standin: all ok");
process.exit(failed ? 1 : 0);
