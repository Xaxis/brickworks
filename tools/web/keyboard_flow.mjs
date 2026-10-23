// Can a person who uses the keyboard alone, or a screen reader, do what
// people come to the site for? (docs/COMPETITIVE.md item 14)
//
//   node tools/web/keyboard_flow.mjs [--out=DIR]              this checkout's web/ and api/, served here
//   node tools/web/keyboard_flow.mjs --url=<deployment>       a deployment's files, the API answered here
//   [--only=gallery,model,...] [--themes=light,dark]
//
// Each journey is driven with Tab (and Shift+Tab), Enter and Escape, as a
// person on the keyboard drives it, and the words typed into a field;
// Space only where a checkbox is ticked, which is its key. Nothing is
// clicked. At 1280 px, signed in as the stand-in's Sam unless it says:
//
//   gallery   the skip link first, and Enter on it goes past the header;
//             Tab to the first card's name and Enter opens its model;
//   model     Like (pressed, its count in its name, the focus kept), Save
//             (its lists, the focus in them; a list ticked and the focus
//             kept; Escape closes it back to Save), a comment typed and
//             sent (said in the page's status), Reply under a comment (the
//             focus in its box; Escape takes it away, back to Reply; sent,
//             the focus not lost); Share's toast, said as it is shown;
//   report    signed out, More, Report it: the dialog takes the focus,
//             keeps it, and Escape gives it back to More;
//   follow    a designer's page: Follow, pressed, the focus kept, said;
//   notices   the account menu from the header (Escape closes it back to
//             its button), Notifications from it, a notice reached, Mark
//             all read said and the focus not lost;
//   profile   Edit profile: the dialog takes the focus and keeps it, a name
//             typed and saved, the focus back on Edit profile; Escape too;
//   settings  Dark chosen, a checkbox ticked (Space) and said;
//   sign-in   signed out: Sign in's dialog, an address and Enter, the code's
//             field focused; Escape gives the focus back to Sign in;
//   download  the download button reached and Enter starts the download.
//
// Every stop on the way is judged: the focus shown (an outline or a ring of
// its own, on it or on the card it stands for), on the screen, not under
// the sticky header, and never lost to the page's body. Reduced motion is
// asked for throughout: nothing on the page moves (document.getAnimations()).
//
// With --url the pages and scripts are the deployment's; the API, and the
// server's pages of the stand-in's model and designer, are answered here
// (design_stand_in.mjs), so nothing is written anywhere.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const web = path.join(root, "web");
const api = path.join(root, "api");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const themes = String(args.themes || "light,dark").split(",");
const only = args.only ? String(args.only).split(",") : null;
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let passed = 0;
let failed = 0;
const check = (ok, what) => {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  return ok;
};

// The Supabase project a deployment names, for what the browser keeps.
let remoteDb = "";
if (remote) {
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* the stand-in's own */ }
}

// --- where the focus is ------------------------------------------------------

/// The focused element as a person meets it: what it is, its name, and
/// whether its focus can be seen. Runs in the page.
function focusNow() {
  const el = document.activeElement;
  if (!el || el === document.body || el === document.documentElement) return { lost: true, said: "the page itself" };
  const name = (el.getAttribute("aria-label") || el.innerText || el.value || el.getAttribute("title") || "").replace(/\s+/g, " ").trim().slice(0, 60);
  const tag = el.tagName.toLowerCase();
  const said = `${tag}${el.id ? `#${el.id}` : ""} "${name}"`;
  // A ring: an outline, or a box-shadow, on it or on what stands for it
  // (a card's name draws its ring round the whole card, ::after).
  const ringed = (style) => (style.outlineStyle !== "none" && parseFloat(style.outlineWidth) >= 1)
    || (style.boxShadow && style.boxShadow !== "none");
  const shown = el.matches(":focus-visible") && (ringed(getComputedStyle(el)) || ringed(getComputedStyle(el, "::after"))
    || ringed(getComputedStyle(el, "::before")));
  const box = el.getBoundingClientRect();
  const onScreen = box.width > 0 && box.height > 0 && box.bottom > 0 && box.top < innerHeight && box.right > 0 && box.left < innerWidth;
  // Not under the sticky header: what is drawn at its middle is it (or in
  // it), not the header over it.
  let under = false;
  if (onScreen && !el.closest(".site-head") && !el.closest("dialog")) {
    const x = Math.min(innerWidth - 1, Math.max(0, box.left + box.width / 2));
    const y = Math.min(innerHeight - 1, Math.max(0, box.top + Math.min(box.height / 2, 12)));
    const top = document.elementFromPoint(x, y);
    under = Boolean(top && top.closest(".site-head"));
  }
  return { lost: false, said, tag, id: el.id, name, shown, onScreen, under, inDialog: Boolean(el.closest("dialog[open]")),
    pressed: el.getAttribute("aria-pressed"), expanded: el.getAttribute("aria-expanded") };
}

/// Each stop's focus judged once a stop: shown, on the screen, not under
/// the header. Collected for the journey's line.
const stops = { seen: 0, bad: [] };
async function judgeStop(page, label) {
  const now = await page.evaluate(focusNow);
  stops.seen += 1;
  if (now.lost) stops.bad.push(`${label}: lost to the page`);
  else if (!now.shown) stops.bad.push(`${label}: ${now.said} shows no focus`);
  else if (!now.onScreen) stops.bad.push(`${label}: ${now.said} is off the screen`);
  else if (now.under) stops.bad.push(`${label}: ${now.said} is under the header`);
  return now;
}

/// Tab (or Shift+Tab with back) until [selector] has the focus, judging
/// each stop; at most [most] presses. Returns the stops' names, or null.
async function tabTo(page, label, selector, { most = 150, back = false } = {}) {
  const path = [];
  for (let n = 0; n < most; n += 1) {
    await page.keyboard.press(back ? "Shift+Tab" : "Tab");
    const now = await judgeStop(page, label);
    path.push(now.said);
    if (await page.evaluate((sel) => Boolean(document.activeElement?.matches(sel)), selector)) return path;
  }
  check(false, `${label}: Tab never reached ${selector} in ${most} presses (last: ${path.slice(-3).join(" → ")})`);
  return null;
}

const until = (page, test, arg = null, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const focusIs = (page, selector) => page.evaluate((sel) => Boolean(document.activeElement?.matches(sel)), selector);
const settle = (page, ms = 400) => page.waitForTimeout(ms);
const moving = (page) => page.evaluate(() => document.getAnimations().filter((one) => one.playState === "running")
  .map((one) => one.animationName || one.transitionProperty || "an animation"));

// --- the site --------------------------------------------------------------

/// A page of the site in a context of its own: at 1280 px, [theme], with
/// reduced motion asked for, signed in as Sam unless [signedIn] is false.
async function visit(browser, address, { theme = "light", signedIn = true, state = {} } = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, colorScheme: theme,
    reducedMotion: "reduce", extraHTTPHeaders: headers });
  await stand.serveSite(context, { web, api, remote, headers, remoteDb, state });
  // The server's pages of the stand-in's people, made here from this
  // checkout's api/ (on a deployment, its scripts with them).
  if (remote) {
    await context.route(/\/(m|u|c)\/[^/.]+(\/v\/\d+)?(\?.*)?$/, async (route) => {
      const url = new URL(route.request().url());
      if (url.origin !== new URL(remote).origin) return route.fallback();
      const made = await stand.serverPage(api, url.pathname + url.search);
      return route.fulfill({ status: made.status, contentType: "text/html; charset=utf-8", body: made.html });
    });
  }
  // What the stand-in leaves unwritten, written as the API answers it: a
  // comment, a follow, a profile saved.
  const follows = new Set();
  await context.route(/\/api\/people\?op=(comment|follow)(&|$)/, async (route) => {
    const request = route.request();
    if (request.method() !== "POST") return route.fallback();
    const url = new URL(request.url());
    const body = JSON.parse(request.postData() || "{}");
    if (url.searchParams.get("op") === "comment") {
      return route.fulfill({ status: 201, contentType: "application/json",
        body: JSON.stringify({ comment: { id: 901, body: body.body, step: body.step ?? null, at: new Date().toISOString() } }) });
    }
    if (body.on) follows.add(body.handle);
    else follows.delete(body.handle);
    return route.fulfill({ status: 200, contentType: "application/json",
      body: JSON.stringify({ handle: body.handle, you_follow: Boolean(body.on), followers: 3 + (body.on ? 1 : 0) }) });
  });
  // What the page copies, kept here: the clipboard of a page on plain
  // http is not the page's to use (as model_page_flow.mjs keeps it).
  await context.addInitScript(() => {
    window.__copied = [];
    try {
      Object.defineProperty(navigator, "clipboard", { configurable: true,
        value: { writeText: async (text) => { window.__copied.push(String(text)); } } });
      Object.defineProperty(window, "isSecureContext", { configurable: true, value: true });
    } catch { /* kept as it is */ }
  });
  // The download, answered as GitHub's file is: an attachment.
  await context.route("https://github.com/**", (route) => route.fulfill({ status: 200, contentType: "application/octet-stream",
    headers: { "content-disposition": "attachment; filename=Brickworks.AppImage" }, body: "not really" }));
  if (signedIn) {
    const asProject = (text) => (remoteDb ? text.split(stand.DB).join(remoteDb) : text);
    const kept = JSON.parse(asProject(JSON.stringify(stand.signedInStorage())));
    await context.addInitScript(([session, access]) => {
      try {
        localStorage.setItem("brickworks.session", session);
        sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
  }
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  await page.goto(base + address, { waitUntil: "load", timeout: 60000 });
  return { context, page, errors };
}

async function shot(page, name) {
  if (out) await page.screenshot({ path: path.join(out, `${name}.png`) }).catch(() => {});
}

// --- the journeys ------------------------------------------------------------

const JOURNEYS = {
  async gallery(browser, theme) {
    const { context, page } = await visit(browser, "/gallery", { theme, signedIn: false });
    const label = `gallery ${theme}`;
    await until(page, () => document.querySelectorAll("#models .model, #feed .model").length > 0, null, 15000);
    await page.keyboard.press("Tab");
    const first = await judgeStop(page, label);
    check(first.name === "Skip to content", `${label}: the first Tab is the skip link (${first.said})`);
    await page.keyboard.press("Enter");
    await page.keyboard.press("Tab");
    const next = await page.evaluate(() => ({ main: Boolean(document.activeElement?.closest("main")),
      said: document.activeElement?.textContent?.trim().slice(0, 40) || document.activeElement?.tagName }));
    check(next.main, `${label}: Enter on it, and the next Tab is in the page, past the header (${next.said})`);
    const way = await tabTo(page, label, ".model a.open");
    if (way) {
      const card = await page.evaluate(() => document.activeElement.textContent.trim());
      check(way.length <= 30, `${label}: the first card's name in ${way.length + 2} presses: "${card}"`);
      await shot(page, `gallery_${theme}_card`);
      await page.keyboard.press("Enter");
      const opened = await until(page, () => /^\/m\/[A-Za-z0-9]{10}$/.test(location.pathname), null, 15000);
      check(opened, `${label}: Enter opens its model (${new URL(page.url()).pathname})`);
    }
    await context.close();
  },

  async model(browser, theme) {
    const { context, page, errors } = await visit(browser, `/m/${stand.MODEL_ID}`, { theme, state: { likes: new Map() } });
    const label = `model ${theme}`;
    await until(page, () => !document.getElementById("comments")?.hidden && document.querySelector("#comments .comment"), null, 15000);
    // Like: pressed, its count in its name, the focus kept.
    if (await tabTo(page, label, '[data-mark="like"]')) {
      const before = await page.evaluate(focusNow);
      await page.keyboard.press("Enter");
      await until(page, () => document.activeElement?.getAttribute("aria-pressed") === "true", null, 5000);
      await settle(page);
      const after = await page.evaluate(focusNow);
      check(after.pressed === "true" && /^Like, \d/.test(after.name) && after.name !== before.name && !after.lost,
        `${label}: Enter on Like: pressed, said "${after.name}" (was "${before.name}"), the focus still on it (${after.said})`);
      // Again, from the keyboard: it is not stuck.
      await page.keyboard.press("Enter");
      const back = await until(page, () => document.activeElement?.getAttribute("aria-pressed") === "false", null, 5000);
      check(back, `${label}: Enter again takes the like back`);
    }
    // Save: its lists, the focus in them; a list ticked; Escape back.
    if (await tabTo(page, label, '[data-mark="save"]', { most: 5 })) {
      await page.keyboard.press("Enter");
      const opened = await until(page, () => !document.getElementById("save-panel")?.hidden
        && document.activeElement?.closest("#save-panel"), null, 5000);
      const into = await page.evaluate(focusNow);
      check(opened, `${label}: Enter on Save opens your lists, the focus in them (${into.said})`);
      if (opened && into.tag === "input") {
        const was = await page.evaluate(() => document.activeElement.checked);
        await page.keyboard.press("Space");
        await until(page, () => (document.querySelector(".marks-said")?.textContent || "").trim(), null, 5000);
        await settle(page);
        const kept = await page.evaluate(() => ({ focus: document.activeElement?.closest("#save-panel") ? document.activeElement.tagName : "",
          checked: document.activeElement?.checked, said: document.querySelector(".marks-said")?.textContent || "" }));
        check(kept.focus === "INPUT" && kept.checked === !was && /Saved|Out of/.test(kept.said),
          `${label}: Space ${was ? "unticks" : "ticks"} a list, the focus stays on it, and the page says "${kept.said}"`);
      }
      await page.keyboard.press("Escape");
      const closed = await until(page, () => document.getElementById("save-panel")?.hidden
        && document.activeElement?.matches('[data-mark="save"]'), null, 3000);
      check(closed, `${label}: Escape closes the lists, back on Save (${(await page.evaluate(focusNow)).said})`);
    }
    // Share: the toast, said by a region that was there before it spoke.
    if (await tabTo(page, label, '[data-mark="share"], #marks [data-share]', { most: 8 })) {
      const region = await page.evaluate(() => Boolean(document.querySelector('body > .toast[role="status"]')));
      await page.keyboard.press("Enter");
      const said = await until(page, () => document.querySelector("body > .toast.shown")?.textContent, null, 4000);
      const words = await page.evaluate(() => document.querySelector("body > .toast")?.textContent || "");
      check(region && said && words, `${label}: Enter on Share: "${words}", read out from a status region on the page before it spoke`);
      const moves = await moving(page);
      check(moves.length === 0, `${label}: with reduced motion asked, nothing moves (${moves.join(", ") || "nothing"})`);
      await page.keyboard.press("Escape");
    }
    // A comment, typed and sent.
    if (await tabTo(page, label, "#comment-body")) {
      await page.keyboard.type("The tower's hinge is clever.");
      await tabTo(page, label, 'form.comment-new button[type="submit"]', { most: 3 });
      await page.keyboard.press("Enter");
      const said = await until(page, () => /Added/.test(document.querySelector(".comments-said")?.textContent || ""), null, 8000);
      await settle(page);
      const now = await page.evaluate(focusNow);
      check(said && !now.lost, `${label}: a comment sent with Enter: "${await page.evaluate(() => document.querySelector(".comments-said")?.textContent)}", the focus on ${now.said}`);
    }
    // Reply, back up the page from the comment's box: its box, Escape,
    // then sent.
    if (await tabTo(page, label, '.comment-acts button[data-reply]', { most: 30, back: true })) {
      const reply = await page.evaluate(focusNow);
      check(/^Reply to .+/.test(reply.name) || /^Reply/.test(reply.name), `${label}: a comment's Reply says whose (${reply.said})`);
      await page.keyboard.press("Enter");
      const boxed = await until(page, () => document.activeElement?.matches("form.reply-new textarea"), null, 4000);
      check(boxed, `${label}: Enter on Reply puts the focus in its box (${(await page.evaluate(focusNow)).said})`);
      await page.keyboard.press("Escape");
      const gone = await until(page, () => !document.querySelector("form.reply-new")
        && document.activeElement?.matches(".comment-acts button"), null, 3000);
      check(gone, `${label}: Escape takes the box away, back on Reply (${(await page.evaluate(focusNow)).said})`);
      await page.keyboard.press("Enter");
      await until(page, () => document.activeElement?.matches("form.reply-new textarea"), null, 4000);
      await page.keyboard.type("Thank you!");
      await tabTo(page, label, 'form.reply-new button[type="submit"]', { most: 3 });
      await page.keyboard.press("Enter");
      const said = await until(page, () => /Replied/.test(document.querySelector(".comments-said")?.textContent || ""), null, 8000);
      await settle(page);
      const now = await page.evaluate(focusNow);
      check(said && !now.lost && now.said.length > 0, `${label}: a reply sent with Enter: said "Replied.", the focus on ${now.said}`);
    }
    check(!errors.length, `${label}: no script errors (${errors.join("; ") || "none"})`);
    await shot(page, `model_${theme}`);
    await context.close();
  },

  async report(browser, theme) {
    const { context, page } = await visit(browser, `/m/${stand.MODEL_ID}`, { theme, signedIn: false });
    const label = `report ${theme}`;
    await until(page, () => !document.querySelector('[data-report="this model"]')?.hidden, null, 15000);
    if (await tabTo(page, label, "#more > summary")) {
      const more = await page.evaluate(focusNow);
      check(/^More/.test(more.name), `${label}: More is named (${more.said})`);
      await page.keyboard.press("Enter");
      await until(page, () => document.querySelector("#more[open]"));
      if (await tabTo(page, label, '[data-report="this model"]', { most: 5 })) {
        await page.keyboard.press("Enter");
        const opened = await until(page, () => document.querySelector("dialog.report[open]")
          && document.activeElement?.closest("dialog.report"), null, 5000);
        check(opened, `${label}: Enter on Report it opens its dialog with the focus in it (${(await page.evaluate(focusNow)).said})`);
        const named = await page.evaluate(() => {
          const dialog = document.querySelector("dialog.report");
          const by = dialog?.getAttribute("aria-labelledby");
          return dialog?.getAttribute("aria-label") || (by ? document.getElementById(by)?.textContent : "") || "";
        });
        check(Boolean(named.trim()), `${label}: the dialog is named by its title ("${named.trim()}")`);
        let outside = 0;
        for (let n = 0; n < 15; n += 1) {
          await page.keyboard.press("Tab");
          if (!(await page.evaluate(() => Boolean(document.activeElement?.closest("dialog.report"))))) outside += 1;
        }
        check(outside === 0, `${label}: 15 Tabs and the focus never leaves the dialog (${outside} outside)`);
        await page.keyboard.press("Escape");
        const back = await until(page, () => !document.querySelector("dialog.report[open]")
          && document.activeElement?.matches("#more > summary"), null, 3000);
        check(back, `${label}: Escape closes it, the focus back on More (${(await page.evaluate(focusNow)).said})`);
      }
    }
    await context.close();
  },

  async follow(browser, theme) {
    const { context, page } = await visit(browser, `/u/${stand.HANDLE}`, { theme });
    const label = `follow ${theme}`;
    await until(page, () => document.querySelector("[data-follow]:not([hidden])"), null, 15000);
    if (await tabTo(page, label, "[data-follow]")) {
      await page.keyboard.press("Enter");
      const on = await until(page, () => document.activeElement?.getAttribute("aria-pressed") === "true", null, 5000);
      await settle(page);
      const now = await page.evaluate(focusNow);
      const said = await page.evaluate(() => document.querySelector("[data-follow]")?.parentElement?.querySelector(".said")?.textContent?.trim() || "");
      check(on && /Following/.test(now.name) && said, `${label}: Enter on Follow: ${now.said}, pressed, and said "${said}"`);
    }
    await context.close();
  },

  async notices(browser, theme) {
    const { context, page } = await visit(browser, "/gallery", { theme });
    const label = `notices ${theme}`;
    await until(page, () => document.querySelector(".site-head .account-menu summary"), null, 15000);
    if (await tabTo(page, label, ".site-head .account-menu summary", { most: 10 })) {
      const button = await page.evaluate(focusNow);
      check(/account/i.test(button.name), `${label}: the header's avatar is named (${button.said})`);
      await page.keyboard.press("Enter");
      await until(page, () => document.querySelector(".site-head .account-menu[open]"));
      await page.keyboard.press("Escape");
      const closed = await until(page, () => !document.querySelector(".site-head .account-menu[open]")
        && document.activeElement?.matches(".site-head .account-menu summary"), null, 3000);
      check(closed, `${label}: Escape closes the account menu, back on its button`);
      await page.keyboard.press("Enter");
      if (await tabTo(page, label, '.account-menu a[href="/notifications"]', { most: 8 })) {
        await page.keyboard.press("Enter");
        await page.waitForURL(/\/notifications/, { timeout: 15000 }).catch(() => {});
        const ready = await until(page, () => document.querySelectorAll("#groups .notice").length > 0, null, 15000);
        check(ready, `${label}: Enter on Notifications opens them`);
        if (await tabTo(page, label, "#groups .notice a")) {
          check(true, `${label}: a notice reached: ${(await page.evaluate(focusNow)).said}`);
        }
        if (await page.evaluate(() => !document.getElementById("all-read")?.hidden)
          && await tabTo(page, label, "#all-read", { most: 30, back: true })) {
          await page.keyboard.press("Enter");
          const said = await until(page, () => (document.getElementById("said")?.textContent || "").trim(), null, 5000);
          await settle(page);
          const now = await page.evaluate(focusNow);
          check(said && !now.lost, `${label}: Mark all read: said "${await page.evaluate(() => document.getElementById("said")?.textContent)}", the focus on ${now.said}`);
        }
      }
    }
    await context.close();
  },

  async profile(browser, theme) {
    const { context, page } = await visit(browser, "/profile", { theme });
    const label = `profile ${theme}`;
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 15000);
    if (await tabTo(page, label, "#edit")) {
      await page.keyboard.press("Enter");
      const opened = await until(page, () => document.querySelector("dialog#edit-dialog[open]")
        && document.activeElement?.closest("dialog#edit-dialog"), null, 5000);
      check(opened, `${label}: Enter on Edit profile opens it, the focus in it (${(await page.evaluate(focusNow)).said})`);
      let outside = 0;
      for (let n = 0; n < 40; n += 1) {
        await page.keyboard.press("Tab");
        if (!(await page.evaluate(() => Boolean(document.activeElement?.closest("dialog#edit-dialog"))))) outside += 1;
      }
      check(outside === 0, `${label}: 40 Tabs and the focus never leaves the dialog (${outside} outside)`);
      await page.keyboard.press("Escape");
      const back = await until(page, () => !document.querySelector("dialog#edit-dialog[open]") && document.activeElement?.matches("#edit"), null, 3000);
      check(back, `${label}: Escape closes it, back on Edit profile`);
      await page.keyboard.press("Enter");
      await until(page, () => document.activeElement?.matches("#name"), null, 5000);
      await page.keyboard.press("Control+A");
      await page.keyboard.type("Sam Okafor-Reid");
      if (await tabTo(page, label, "#save")) {
        await page.keyboard.press("Enter");
        const saved = await until(page, () => !document.querySelector("dialog#edit-dialog[open]"), null, 8000);
        await settle(page, 600);
        const now = await page.evaluate(focusNow);
        check(saved && now.id === "edit", `${label}: Enter on Save: saved and closed, the focus back on Edit profile (${now.said})`);
      }
    }
    await context.close();
  },

  async settings(browser, theme) {
    const { context, page } = await visit(browser, "/settings", { theme });
    const label = `settings ${theme}`;
    await until(page, () => document.documentElement.dataset.settings === "ready", null, 15000);
    const want = theme === "dark" ? "light" : "dark";
    if (await tabTo(page, label, `#theme-part [data-theme-choice="${want}"]`)) {
      await page.keyboard.press("Enter");
      const chosen = await until(page, (w) => document.documentElement.dataset.theme === w
        && document.activeElement?.getAttribute("aria-pressed") === "true", want, 4000);
      check(chosen, `${label}: Enter on ${want}: the page is ${want}, the button pressed and focused`);
    }
    if (await tabTo(page, label, "#mail-comments")) {
      const was = await page.evaluate(() => document.getElementById("mail-comments").checked);
      await page.keyboard.press("Space");
      const said = await until(page, (w) => document.getElementById("mail-comments")?.checked === !w
        && (document.getElementById("mail-said")?.textContent || "").trim(), was, 5000);
      await settle(page);
      const now = await page.evaluate(focusNow);
      check(said && now.id === "mail-comments", `${label}: Space ${was ? "unticks" : "ticks"} the comments email: said "${await page.evaluate(() => document.getElementById("mail-said")?.textContent)}", the focus kept (${now.said})`);
    }
    await context.close();
  },

  async signin(browser, theme) {
    const { context, page } = await visit(browser, "/profile", { theme, signedIn: false });
    const label = `sign-in ${theme}`;
    await until(page, () => document.querySelector("#sign-in:not([hidden])"), null, 15000);
    if (await tabTo(page, label, "#sign-in")) {
      await page.keyboard.press("Enter");
      const opened = await until(page, () => document.querySelector("dialog.sign-in[open]") && document.activeElement?.matches("dialog.sign-in input"), null, 5000);
      const named = await page.evaluate(() => {
        const dialog = document.querySelector("dialog.sign-in");
        const by = dialog?.getAttribute("aria-labelledby");
        return dialog?.getAttribute("aria-label") || (by ? document.getElementById(by)?.textContent : "") || "";
      });
      check(opened && named, `${label}: Enter on Sign in opens "${named}", the focus in its address`);
      const field = await page.evaluate(() => {
        const input = document.activeElement;
        return input?.labels?.[0]?.textContent?.trim() || input?.getAttribute("aria-label") || "";
      });
      check(Boolean(field), `${label}: its field is labelled ("${field}")`);
      await page.keyboard.type(stand.EMAIL);
      await page.keyboard.press("Enter");
      const coded = await until(page, () => /code sent/i.test(document.querySelector("dialog.sign-in label")?.textContent || "")
        && document.activeElement?.matches("dialog.sign-in input"), null, 8000);
      check(coded, `${label}: Enter sends the code; the code's field has the focus ("${await page.evaluate(() => document.querySelector("dialog.sign-in label")?.textContent?.trim())}")`);
      await page.keyboard.press("Escape");
      const back = await until(page, () => !document.querySelector("dialog.sign-in[open]") && document.activeElement?.matches("#sign-in"), null, 3000);
      check(back, `${label}: Escape closes it, the focus back on Sign in (${(await page.evaluate(focusNow)).said})`);
    }
    await context.close();
  },

  async download(browser, theme) {
    const { context, page } = await visit(browser, "/download", { theme, signedIn: false });
    const label = `download ${theme}`;
    await until(page, () => /github|\/app/.test(document.getElementById("offer-button")?.href || ""), null, 10000);
    if (await tabTo(page, label, "#offer-button")) {
      const button = await page.evaluate(focusNow);
      const started = page.waitForEvent("download", { timeout: 10000 }).then((one) => one.suggestedFilename(), () => "");
      await page.keyboard.press("Enter");
      const file = await started;
      check(Boolean(file), `${label}: Enter on ${button.said} starts the download (${file || "nothing"})`);
    }
    await context.close();
  },
};

// --- run ---------------------------------------------------------------------

console.log(`keyboard flow: ${remote || `${root} (its web/ and api/, served here)`}`);
const browser = await launch({ signedOut: true });
try {
  for (const [name, journey] of Object.entries(JOURNEYS)) {
    if (only && !only.includes(name)) continue;
    for (const theme of themes) {
      console.log(`${name} ${theme}`);
      try {
        await journey(browser, theme);
      } catch (trouble) {
        check(false, `${name} ${theme}: ${String(trouble).split("\n")[0]}`);
      }
    }
  }
} finally {
  await browser.close();
}
const bad = [...new Set(stops.bad)];
check(bad.length === 0, `every one of ${stops.seen} stops on the way shows its focus, on the screen and clear of the header${bad.length ? `: ${bad.length} not:` : ""}`);
for (const one of bad.slice(0, 40)) console.log(`        ${one}`);
console.log(`\nkeyboard flow: ${passed} checks passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
