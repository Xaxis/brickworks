// The site's own ask (web/kit.js ask, docs/DESIGN_SYSTEM.md "Ask"), where the
// browser's confirm() was until 2026-11-23 (owner: "it opens up the system
// browser confirm and not our consistent ui/ux modal dialog"), driven as a
// person drives it, with the mouse, the keyboard alone, and read as a screen
// reader reads it, on /admin and on /settings:
//
//   node tools/web/ask_flow.mjs [--out=DIR]              this checkout's web/ and api/, served here
//   node tools/web/ask_flow.mjs --url=<deployment>       a deployment's files, the API answered here
//   [--themes=light,dark] [--widths=1280,390] [--only=gallery,sheet,site,settings,profile,comment,helper]
//
// The API is the stand-in's (design_stand_in.mjs: Sam, the site's owner for
// /admin), so nothing is sent anywhere; each act's POST is counted here.
//
//   1. /admin › Gallery, Take out (a danger ask): the alertdialog named by
//      its question and described by its line, the focus on Cancel, the
//      answer in the danger style; Escape, Cancel by Enter, and a press on
//      the scrim (not a double click's second press) each send nothing and give the focus back to Take out once
//      it is let go; Tab and Shift+Tab stay in the ask; Enter on Take it out
//      sends op=unlist once.
//   2. /admin › an account's sheet, Sign out everywhere: the ask over the
//      sheet; Escape closes the ask alone, the sheet still open and the
//      focus back in it on Sign out everywhere.
//   3. /admin › Site, Run now (an ask that is no danger): the focus on Run
//      now, the yellow button; Enter sends op=run_cron once.
//   4. /settings, Delete this account: the address typed, Delete my account
//      asks; Cancel sends nothing, the focus back on Delete my account; in
//      German at /de/settings its words are German.
//   5. /profile, a list's Delete: Escape sends nothing, the focus back
//      on Delete.
//   6. A model's page, Block on a comment's row (web/block.js): Enter on
//      Cancel sends nothing, the focus back on Block once it is let go;
//      Shift+Tab to Block in the ask and Enter sends op=block once.
//   7. tools/web/asks.mjs, as the other flows use it: No sends nothing,
//      then one Yes sends the delete once, each ask's words heard.
//   And the browser's own dialog never opens; pictures of the asks at each
//   width and theme (admin_ask_*, delete_ask_*).
import { answerAsks } from "./asks.mjs";
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
const widths = String(args.widths || "1280,390").split(",").map(Number);
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

let remoteDb = "";
if (remote) {
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* the stand-in's own */ }
}

const until = (page, test, arg = null, ms = 10000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const asking = (page) => until(page, () => Boolean(document.querySelector("dialog.ask[open]")));
const gone = (page) => until(page, () => !document.querySelector("dialog.ask"));
const focused = (page) => page.evaluate(() => {
  const el = document.activeElement;
  return { tag: el?.tagName.toLowerCase() || "", words: (el?.textContent || "").trim().slice(0, 60), answer: el?.dataset?.answer || "",
    inAsk: Boolean(el?.closest("dialog.ask")), inSheet: Boolean(el?.closest("dialog.sheet")), id: el?.id || "" };
});

/// A page of the site at [width] in [theme], signed in as Sam, the owner
/// where [admin]; each POST it sends counted by its op, each native dialog
/// it opens counted and dismissed.
async function visit(browser, address, { width = 1280, theme = "light", admin = false } = {}) {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, colorScheme: theme,
    reducedMotion: "reduce", extraHTTPHeaders: headers, isMobile: width < 600, hasTouch: width < 600 });
  await stand.serveSite(context, { web, api, remote, headers, remoteDb, state: { admin } });
  const kept = JSON.parse((remoteDb ? (t) => t.split(stand.DB).join(remoteDb) : (t) => t)(JSON.stringify(stand.signedInStorage())));
  await context.addInitScript(([session, access]) => {
    try {
      localStorage.setItem("brickworks.session", session);
      sessionStorage.setItem("brickworks.access", access);
    } catch { /* a browser that keeps nothing */ }
  }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
  const page = await context.newPage();
  const posts = [];
  page.on("request", (request) => {
    if (request.method() !== "POST") return;
    const url = new URL(request.url());
    if (url.pathname.startsWith("/api/")) posts.push(`${url.pathname.slice(5)} ${url.searchParams.get("op") || ""}`);
  });
  const natives = [];
  page.on("dialog", (dialog) => {
    natives.push(`${dialog.type()}: ${dialog.message().slice(0, 80)}`);
    dialog.dismiss().catch(() => {});
  });
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  await page.goto(base + address, { waitUntil: "load", timeout: 60000 });
  return { context, page, posts, natives, errors };
}

/// What a screen reader is told of the open ask: its role, name and
/// description from the browser's accessibility tree.
async function readAloud(page) {
  const cdp = await page.context().newCDPSession(page);
  const { nodes } = await cdp.send("Accessibility.getFullAXTree");
  await cdp.detach();
  const node = nodes.find((one) => one.role?.value === "alertdialog" && !one.ignored);
  if (!node) return null;
  return { name: node.name?.value || "", description: node.description?.value || "" };
}

async function shot(page, name) {
  if (out) await page.screenshot({ path: path.join(out, `${name}.png`) }).catch(() => {});
}

/// The ask as it opened: read aloud by its question and line, the focus on
/// [start] ("yes" or "no"), its answer in [style] ("danger" or "primary").
async function judgeAsk(page, label, { title, body, start, style }) {
  check(await asking(page), `${label}: the site's own ask opens`);
  const said = await readAloud(page);
  check(said && said.name === title, `${label}: a screen reader hears an alertdialog named "${title}" (${said ? `"${said.name}"` : "none"})`);
  if (body) check(said && said.description.startsWith(body), `${label}: and its line "${body.slice(0, 50)}…" (${said ? `"${said.description.slice(0, 50)}"` : "none"})`);
  const now = await focused(page);
  check(now.inAsk && now.answer === start, `${label}: the focus starts on ${start === "no" ? "Cancel, the safe choice" : "the answer"} (${now.words})`);
  const yes = await page.evaluate(() => {
    const button = document.querySelector('dialog.ask[open] [data-answer="yes"]');
    return { danger: button.matches(".danger"), primary: button.matches(".cta:not(.ghost)"), modal: document.querySelector("dialog.ask").matches(":modal") };
  });
  check(yes.modal, `${label}: it is modal, over the scrim`);
  check(style === "danger" ? yes.danger : yes.primary, `${label}: its answer is the ${style} button`);
}

const JOURNEYS = {
  // 1. A danger ask on /admin › Gallery.
  async gallery(browser, { theme, width }) {
    const label = `/admin gallery ${width} ${theme}`;
    const { context, page, posts, natives, errors } = await visit(browser, "/admin#gallery", { width, theme, admin: true });
    const take = page.locator("#gallery button", { hasText: "Take out" }).first();
    await take.waitFor({ timeout: 30000 });
    await take.click();
    const asked = await page.evaluate(() => document.querySelector("dialog.ask h2")?.textContent || "");
    check(/^Take ".+" out of the gallery\?$/.test(asked), `${label}: it asks "${asked}"`);
    await judgeAsk(page, label, { title: asked, body: "Its owner will not be able to list it again.", start: "no", style: "danger" });
    await shot(page, `admin_ask_${width}_${theme}`);
    if (width === 1280) {
      // Tab and Shift+Tab stay in it, round its two buttons.
      await page.keyboard.press("Tab");
      const after = await focused(page);
      await page.keyboard.press("Shift+Tab");
      const back = await focused(page);
      check(after.inAsk && after.answer === "yes" && back.inAsk && back.answer === "no",
        `${label}: Tab and Shift+Tab stay in the ask (${after.words}, then ${back.words})`);
      // Escape: nothing sent, the focus back on Take out once it is let go.
      await page.keyboard.press("Escape");
      check(await gone(page), `${label}: Escape closes it`);
      await until(page, () => document.activeElement?.textContent === "Take out", null, 3000);
      let now = await focused(page);
      check(now.words === "Take out", `${label}: the focus back on Take out (${now.words || "the page"})`);
      // Again from the keyboard: Enter opens it, Enter on Cancel answers no.
      await page.keyboard.press("Enter");
      check(await asking(page), `${label}: Enter on Take out asks again`);
      await page.keyboard.press("Enter");
      check(await gone(page), `${label}: Enter on Cancel closes it`);
      await until(page, () => document.activeElement?.textContent === "Take out", null, 3000);
      now = await focused(page);
      check(now.words === "Take out", `${label}: the focus back on Take out (${now.words || "the page"})`);
      // A double click on Take out: its second press, on the scrim the
      // moment the ask is open, leaves the ask open.
      await take.dblclick();
      await page.waitForTimeout(600);
      check(await page.evaluate(() => Boolean(document.querySelector("dialog.ask[open]"))),
        `${label}: a double click on Take out leaves the ask open`);
      // A press beside it, on the scrim.
      await page.mouse.click(8, 8);
      check(await gone(page), `${label}: a press on the scrim closes it`);
      check(!posts.some((one) => one.endsWith(" unlist")), `${label}: and none of the three sent anything (${posts.join(", ") || "none"})`);
      // Enter on Take it out does it, once.
      await until(page, () => !document.querySelector("#gallery button:disabled"), null, 3000);
      await take.click();
      await asking(page);
      await page.keyboard.press("Tab");
      const on = await focused(page);
      await page.keyboard.press("Enter");
      await until(page, () => !document.querySelector("dialog.ask"), null, 3000);
      await page.waitForTimeout(500);
      check(on.answer === "yes" && posts.filter((one) => one.endsWith(" unlist")).length === 1,
        `${label}: Enter on Take it out sends op=unlist once (${posts.join(", ") || "none"})`);
    }
    check(natives.length === 0, `${label}: the browser's own dialog never opened${natives.length ? `: ${natives.join("; ")}` : ""}`);
    check(errors.length === 0, `${label}: no script error${errors.length ? `: ${errors[0]}` : ""}`);
    await context.close();
  },

  // 2. An ask over /admin's account sheet.
  async sheet(browser, { theme, width }) {
    if (width !== 1280 || theme !== "light") return;
    const label = `/admin account sheet ${width} ${theme}`;
    const { context, page, posts, natives } = await visit(browser, `/admin#people/${stand.OWNERS.ROBIN}`, { width, theme, admin: true });
    const out = page.locator("dialog.sheet[open] button", { hasText: "Sign out everywhere" });
    await out.waitFor({ timeout: 30000 });
    await out.click();
    check(await asking(page), `${label}: Sign out everywhere asks over the sheet`);
    const tabbed = [];
    for (let i = 0; i < 3; i += 1) {
      await page.keyboard.press("Tab");
      tabbed.push(await focused(page));
    }
    check(tabbed.every((one) => one.inAsk), `${label}: Tab stays in the ask, never into the sheet under it`);
    await page.keyboard.press("Escape");
    check(await gone(page), `${label}: Escape closes the ask`);
    const sheetOpen = await page.evaluate(() => Boolean(document.querySelector("dialog.sheet[open]")));
    check(sheetOpen, `${label}: and the sheet stays open`);
    await until(page, () => document.activeElement?.textContent === "Sign out everywhere", null, 3000);
    const now = await focused(page);
    check(now.inSheet && now.words === "Sign out everywhere", `${label}: the focus back in the sheet on Sign out everywhere (${now.words || "the page"})`);
    check(!posts.some((one) => one.endsWith(" sign_out")), `${label}: nothing sent`);
    check(natives.length === 0, `${label}: the browser's own dialog never opened`);
    await context.close();
  },

  // 3. An ask that is no danger: /admin › Site, Run now.
  async site(browser, { theme, width }) {
    if (width !== 1280 || theme !== "light") return;
    const label = `/admin site ${width} ${theme}`;
    const { context, page, posts, natives } = await visit(browser, "/admin#site", { width, theme, admin: true });
    const run = page.locator("button", { hasText: "Run now" }).first();
    if (!(await run.waitFor({ timeout: 30000 }).then(() => true, () => false))) {
      check(false, `${label}: a Run now to press`);
      await context.close();
      return;
    }
    await run.click();
    const asked = await page.evaluate(() => document.querySelector("dialog.ask h2")?.textContent || "");
    await judgeAsk(page, label, { title: asked, start: "yes", style: "primary" });
    check(/^Run \/api\/\S+ now\?$/.test(asked), `${label}: it asks "${asked}"`);
    await page.keyboard.press("Enter");
    await gone(page);
    await page.waitForTimeout(500);
    check(posts.filter((one) => one.endsWith(" run_cron")).length === 1, `${label}: Enter on Run now sends op=run_cron once (${posts.join(", ") || "none"})`);
    check(natives.length === 0, `${label}: the browser's own dialog never opened`);
    await context.close();
  },

  // 5. Your profile: Delete a list.
  async profile(browser, { theme, width }) {
    if (width !== 1280 || theme !== "light") return;
    const label = `/profile lists ${width} ${theme}`;
    const { context, page, posts, natives, errors } = await visit(browser, "/profile?tab=saved", { width, theme });
    const drop = page.locator("#lists button", { hasText: "Delete" }).first();
    if (!(await drop.waitFor({ timeout: 30000 }).then(() => true, () => false))) {
      check(false, `${label}: a list's Delete to press`);
      await context.close();
      return;
    }
    const name = await page.locator("#lists input:not([type=checkbox])").first().inputValue();
    await drop.click();
    await judgeAsk(page, label, { title: `Delete the list "${name}"?`, body: "The models in it are not touched.", start: "no",
      style: "danger" });
    await page.keyboard.press("Escape");
    check(await gone(page), `${label}: Escape closes it`);
    const now = await focused(page);
    check(now.words === "Delete", `${label}: the focus back on Delete (${now.words || "the page"})`);
    await page.waitForTimeout(300);
    check(!posts.some((one) => one.endsWith(" uncollection")), `${label}: nothing sent (${posts.join(", ") || "none"})`);
    check(natives.length === 0, `${label}: the browser's own dialog never opened`);
    check(errors.length === 0, `${label}: no script error${errors.length ? `: ${errors[0]}` : ""}`);
    await context.close();
  },

  // 6. A model's page: Block on a comment's row (web/block.js).
  async comment(browser, { theme, width }) {
    if (width !== 1280 || theme !== "light") return;
    const label = `/m/ comment Block ${width} ${theme}`;
    // A deployment serves its own /m/ pages, and the stand-in's model is not
    // one of them: it answered 404 there in every release since this was
    // written (rel-m324's and rel-m325's previews). Said, not judged.
    if (remote) {
      console.log(`  --    ${label}: the stand-in's ${stand.MODEL_ID} is no model on ${remote}; run it on the stand-in`);
      return;
    }
    const { context, page, posts, natives, errors } = await visit(browser, `/m/${stand.MODEL_ID}#comments`, { width, theme });
    const block = page.locator("button[data-block-comment]").first();
    if (!(await block.waitFor({ state: "attached", timeout: 30000 }).then(() => true, () => false))) {
      check(false, `${label}: a comment's Block to press`);
      await context.close();
      return;
    }
    await block.scrollIntoViewIfNeeded();
    const named = (await block.getAttribute("aria-label")).replace(/^Block /, "");
    await block.click();
    await judgeAsk(page, label, { title: `Block ${named}?`, body: "Their models leave your gallery and feed", start: "no", style: "danger" });
    await page.keyboard.press("Enter");
    check(await gone(page), `${label}: Enter on Cancel closes it`);
    await until(page, () => document.activeElement?.matches("button[data-block-comment]"), null, 3000);
    const now = await focused(page);
    check(now.words === "Block", `${label}: the focus back on Block once it is let go (${now.words || "the page"})`);
    await page.waitForTimeout(300);
    check(!posts.some((one) => one.endsWith(" block")), `${label}: nothing sent (${posts.join(", ") || "none"})`);
    await page.keyboard.press("Enter");
    check(await asking(page), `${label}: Enter on Block asks again`);
    await page.keyboard.press("Shift+Tab");
    await page.keyboard.press("Enter");
    await gone(page);
    await page.waitForTimeout(800);
    check(posts.filter((one) => one.endsWith(" block")).length === 1, `${label}: Enter on Block in the ask sends op=block once (${posts.join(", ") || "none"})`);
    check(natives.length === 0, `${label}: the browser's own dialog never opened`);
    check(errors.length === 0, `${label}: no script error${errors.length ? `: ${errors[0]}` : ""}`);
    await context.close();
  },

  // 7. tools/web/asks.mjs, which the other flows answer the ask with.
  async helper(browser, { theme, width }) {
    if (width !== 1280 || theme !== "light") return;
    const label = "asks.mjs on /settings";
    const { context, page, posts, natives } = await visit(browser, "/settings", { width, theme });
    const heard = await answerAsks(page, { answer: "no" });
    const press = async () => {
      if (!(await page.isVisible("#delete-confirm"))) await page.locator("#delete-part summary").click();
      await page.fill("#delete-confirm", stand.EMAIL);
      await page.locator("#delete-go").click();
      await page.waitForTimeout(800);
    };
    await press();
    check(heard.length === 1 && heard[0] === "Delete this account and everything in it, for good?"
      && !posts.some((one) => one.startsWith("account ")), `${label}: answer "no" heard "${heard[0] || ""}" and sent nothing`);
    await answerAsks(page, { answer: "yes", times: 1 });
    await press();
    check(heard.length === 2 && posts.filter((one) => one.startsWith("account ")).length === 1,
      `${label}: then times 1 of "yes" sent the delete once (${posts.join(", ") || "none"})`);
    check(natives.length === 0, `${label}: the browser's own dialog never opened`);
    await context.close();
  },

  // 4. Delete this account on /settings, and in German.
  async settings(browser, { theme, width }) {
    for (const [lang, at, words] of [["en", "/settings", { title: "Delete this account and everything in it, for good?",
      yes: "Delete my account", no: "Cancel" }], ["de", "/de/settings", { title: "Dieses Konto und alles darin endgültig löschen?",
      yes: "Mein Konto löschen", no: "Abbrechen" }]]) {
      if (lang === "de" && (width !== 1280 || theme !== "light")) continue;
      const label = `${at} ${width} ${theme}`;
      const { context, page, posts, natives, errors } = await visit(browser, at, { width, theme });
      const summary = page.locator("#delete-part summary");
      await summary.waitFor({ timeout: 30000 });
      await summary.click();
      await page.fill("#delete-confirm", stand.EMAIL);
      await page.locator("#delete-go").click();
      await judgeAsk(page, label, { title: words.title, start: "no", style: "danger" });
      const buttons = await page.evaluate(() => [...document.querySelectorAll("dialog.ask button")].map((b) => b.textContent));
      check(buttons[0] === words.yes && buttons[1] === words.no, `${label}: its buttons say ${words.yes} and ${words.no} (${buttons.join(", ")})`);
      if (lang === "en") await shot(page, `delete_ask_${width}_${theme}`);
      await page.locator('dialog.ask [data-answer="no"]').click();
      check(await gone(page), `${label}: Cancel closes it`);
      const now = await focused(page);
      check(now.id === "delete-go", `${label}: the focus back on Delete my account (${now.id || now.words || "the page"})`);
      await page.waitForTimeout(300);
      check(!posts.some((one) => one.startsWith("account ")), `${label}: nothing sent (${posts.join(", ") || "none"})`);
      check(natives.length === 0, `${label}: the browser's own dialog never opened${natives.length ? `: ${natives.join("; ")}` : ""}`);
      check(errors.length === 0, `${label}: no script error${errors.length ? `: ${errors[0]}` : ""}`);
      await context.close();
    }
  },
};

console.log(`ask flow: ${remote || `${root} (its web/ and api/, served here)`}`);
const browser = await launch({ signedOut: true });
try {
  for (const width of widths) {
    for (const theme of themes) {
      for (const [name, journey] of Object.entries(JOURNEYS)) {
        if (only && !only.includes(name)) continue;
        try {
          await journey(browser, { theme, width });
        } catch (trouble) {
          check(false, `${name} ${width} ${theme}: ${String(trouble).split("\n")[0]}`);
        }
      }
    }
  }
} finally {
  await browser.close();
}
console.log(`\nask flow: ${passed} checks passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
