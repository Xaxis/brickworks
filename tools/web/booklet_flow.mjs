// Press Instructions in a real browser and read the booklet it opens.
//
//   node tools/web/booklet_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=shots/booklet_web
//   node tools/web/booklet_flow.mjs --url=https://brickworks.diy/app --out=…
//
// A first visit has the example car on the baseplate. This clicks the
// toolbar's Instructions (the app publishes where it is,
// window.brickworksControls.instructions, see main._tell_page), and the app
// opens a tab while the click still counts as one and writes the booklet
// into it when its pictures are drawn (BookletMaker.open_tab, fill_tab).
// The web build draws with the Compatibility renderer, which the desktop
// booklet probe runs under too, but only here does the tab, the click and
// the browser's own rules about popups get exercised.
//
// Fails if the button never appears, no tab opens, the booklet never
// arrives in it, a picture in it does not decode, it has no step pages
// or no parts list, or a script error reaches either console. Leaves
// OUT/app.png, OUT/page-N.png and OUT/booklet.pdf.
//
// Then presses the booklet's own Save as PDF and Save pages as PNG, as a
// person does, and reads what each downloads (OUT/saved.pdf, OUT/saved_
// pages.zip) with tools/booklet_pdf_check.py against the booklet as the
// tab has it (OUT/booklet.html): poppler (and pypdf, where BOOKLET_PYPDF
// names it) finds its pages, its step pictures the booklet's own JPEGs,
// its words, and the zip a PNG a page; the pages photographed here are
// held against the PDF's.
//
// --model=FILE opens that model first (Open… > From a file, as
// steps_flow.mjs does) and makes its booklet instead of the car's; a
// model with no steps of its own gets the planner's. --pages=1,4,9 or
// --pages=all photographs those pages, as a reader turns them; the first
// three and the last by default.
import { controlsWith, launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

// Until the booklet in the tab is whole, or ms have gone: it is written in
// as it is drawn (BookletOut, 2026-10-23), its first pages read while the
// rest are drawn, and whole once the app closes the document. Its first
// page is not the booklet: read then, it has no parts pages. Says whether
// it came whole.
async function bookletWhole(tab, ms) {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    const state = await tab.evaluate(() => document.readyState).catch(() => "");
    if (state === "complete") return true;
    await tab.waitForTimeout(2000);
  }
  return false;
}

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
// A preview is behind Vercel's protection: the bypass, and a cookie for
// what the page fetches after.
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/booklet_web";
mkdirSync(out, { recursive: true });

const model = args.model ? path.resolve(args.model) : "";

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
const listen = (p, who) => {
  p.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  p.on("console", (m) => {
    // A refusal by the security policy too: the booklet's tab is under the
    // app's, and its Print once did nothing for that.
    if (/SCRIPT ERROR|Parse Error|ERROR:|Content Security Policy/.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 200)}`);
    }
  });
};
listen(page, "app");
let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};
// Open… > From a file, answered with a file: tried again when a press
// brought no picker, as steps_flow.mjs does.
async function open(file) {
  const at = await page.evaluate(() => (window.brickworksControls || {}).open);
  if (!at) throw new Error("the app never showed Open");
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
      await page.waitForTimeout(500);
    }
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  const until = Date.now() + 300000;
  let at = null;
  while (!(at = await page.evaluate(() => (window.brickworksControls || {}).instructions))) {
    if (Date.now() > until) throw new Error("the Instructions button never appeared");
    await page.waitForTimeout(1000);
  }
  // The example car's parts arrive over the network after the button does.
  await page.waitForTimeout(Number(args.load || 20000));
  if (model) {
    await open(model);
    // Its parts arrive over the network too: settled when the app says
    // none is still on its way. The count holding between two looks was
    // the test, and it holds between two arrivals: 7636 was photographed,
    // and its booklet asked for, with a hundred parts still to come, each
    // redrawing a page that draws in software (2026-10-16). A build that
    // does not say (before brickworksState.awaited) gets the old test.
    const started = Date.now();
    let last = -1;
    let parts = 0;
    let waiting = null;
    for (let n = 0; n < 240; n++) {
      await page.waitForTimeout(2000);
      const now = await page.evaluate(() => window.brickworksState || {});
      parts = now.bricks || 0;
      waiting = now.awaited;
      if (parts > 0 && (waiting === undefined ? parts === last && n > 5 : waiting === 0)) break;
      last = parts;
    }
    console.log(`  (every part arrived in ${Math.round((Date.now() - started) / 1000)} s; `
      + `${waiting === undefined ? "the build does not say what is still on its way" : `${waiting} still on the way`})`);
    check(`${path.basename(model)} opens (${parts} parts)`, parts > 0 && !waiting);
    at = await page.evaluate(() => (window.brickworksControls || {}).instructions);
  }
  // A picture of the app before the press, kept and not checked: a frame
  // of 7636's 372 parts drawn in SwiftShader at a load of 60 to 90 took 5
  // to 14 s, and a screenshot behind a few of them 76 s, so Playwright's
  // 30 s ended the run before Instructions was pressed (2026-10-16).
  await page.screenshot({ path: path.join(out, "app.png"), timeout: 180000 })
    .catch((e) => console.log(`  (no app.png: ${String(e).split("\n")[0].slice(0, 100)})`));
  check("the toolbar has Instructions", Boolean(at));

  // Where it is now, waited for: the toolbar is laid out again as the car's
  // parts land, and a control is told to the page only once it has stayed
  // where it is drawn (Main._page_places).
  at = (await controlsWith(page, ["instructions"])).instructions || at;
  const opened = context.waitForEvent("page", { timeout: 30000 });
  await page.mouse.click(at.x, at.y);
  let tab = null;
  try {
    tab = await opened;
  } catch {
    tab = null;
  }
  check("pressing it opens a tab", tab !== null);
  if (tab) {
    listen(tab, "booklet");
    const started = Date.now();
    const limit = Number(args.wait || 600) * 1000;
    let pages = 0;
    // When its first page and its first page of steps were in front of the
    // reader, and when it was whole: it is written in as it is drawn.
    let steps = -1;
    while (Date.now() - started < limit) {
      [pages, steps] = await tab.evaluate(() => [document.querySelectorAll("section.page").length,
        document.querySelectorAll("section.page.steps").length]).catch(() => [0, 0]);
      if (pages > 0) break;
      await tab.waitForTimeout(500);
    }
    const seconds = (Date.now() - started) / 1000;
    let stepsAt = steps > 0 ? seconds : -1;
    while (stepsAt < 0 && pages > 0 && Date.now() - started < limit) {
      steps = await tab.evaluate(() => document.querySelectorAll("section.page.steps").length)
        .catch(() => 0);
      if (steps > 0) stepsAt = (Date.now() - started) / 1000;
      else await tab.waitForTimeout(500);
    }
    check(`the booklet arrives in it (its first page at ${seconds.toFixed(1)} s, `
      + `its first page of steps at ${stepsAt.toFixed(1)} s)`, pages > 0);
    if (pages > 0) {
      const whole = await bookletWhole(tab, Math.max(0, limit - (Date.now() - started)));
      pages = await tab.evaluate(() => document.querySelectorAll("section.page").length).catch(() => 0);
      check(`...and is whole (${pages} pages, ${((Date.now() - started) / 1000).toFixed(1)} s)`, whole);
      const facts = await tab.evaluate(() => ({
        steps: document.querySelectorAll("section.page.steps").length,
        parts: document.querySelectorAll("section.page.parts").length,
        cover: Boolean(document.querySelector("section.page.cover")),
        pictures: document.images.length,
        broken: [...document.images].filter((i) => !i.complete || i.naturalWidth === 0).length,
        boxes: document.querySelectorAll(".box").length,
        partPictures: document.querySelectorAll("i.pt").length,
        title: document.title,
      }));
      check(`a cover, ${facts.steps} pages of steps and ${facts.parts} of parts`,
        facts.cover && facts.steps > 0 && facts.parts > 0);
      check(`every picture decodes (${facts.pictures - facts.broken} of ${facts.pictures})`,
        facts.pictures > 0 && facts.broken === 0);
      check(`parts boxes with pictures (${facts.boxes} boxes, ${facts.partPictures} parts)`,
        facts.boxes > 0 && facts.partPictures > facts.boxes);
      // Print, pressed as a person does; print itself counted, not shown.
      await tab.evaluate(() => { window.printed = 0; window.print = () => { window.printed += 1; }; });
      await tab.click(".bar button");
      await tab.waitForTimeout(500);
      const printed = await tab.evaluate(() => window.printed);
      check(`Print prints (${printed})`, printed === 1);
      await tab.setViewportSize({ width: 1060, height: 800 });
      await tab.addStyleTag({ content: ".bar { display: none !important; }" });
      const wanted = args.pages === "all"
        ? [...Array(pages).keys()].map((n) => n + 1)
        : args.pages ? String(args.pages).split(",").map(Number) : [1, 2, 3, pages];
      for (const n of wanted) {
        const section = tab.locator(`section.page >> nth=${n - 1}`);
        if ((await section.count()) > 0) {
          await section.screenshot({ path: path.join(out, `page-${n}.png`) });
        }
      }
      await tab.emulateMedia({ media: "print" });
      await tab.pdf({ path: path.join(out, "booklet.pdf"), format: "A4", landscape: true,
        printBackground: true, preferCSSPageSize: true });
      await tab.emulateMedia({ media: "screen" });
      console.log(`  (${facts.title}; pages and booklet.pdf in ${out})`);

      // Save as PDF and Save pages as PNG, pressed in the booklet: the app
      // writes each from the booklet in the tab and downloads it.
      const html = path.join(out, "booklet.html");
      writeFileSync(html, await tab.evaluate(() => "<!doctype html>\n" + document.documentElement.outerHTML));
      const saved = {};
      for (const [id, file] of [["save-pdf", "saved.pdf"], ["save-png", "saved_pages.zip"]]) {
        const shown = await tab.evaluate((id) => {
          const button = document.getElementById(id);
          return Boolean(button && !button.hidden && button.offsetWidth > 0);
        }, id).catch(() => false);
        check(`the booklet shows ${id === "save-pdf" ? "Save as PDF" : "Save pages as PNG"}`, shown);
        if (!shown) continue;
        const started = Date.now();
        const downloaded = page.waitForEvent("download", { timeout: 300000 });
        await tab.click(`#${id}`);
        try {
          const download = await downloaded;
          saved[id] = path.join(out, file);
          await download.saveAs(saved[id]);
          const said = await tab.evaluate(() => document.getElementById("saved").textContent);
          check(`...which downloads ${download.suggestedFilename()} in `
            + `${((Date.now() - started) / 1000).toFixed(1)} s, and says so (${said})`,
            said.startsWith("downloaded "));
        } catch (error) {
          check(`...which downloads it (${String(error).split("\n")[0].slice(0, 120)})`, false);
        }
      }
      if (saved["save-pdf"]) {
        const checker = fileURLToPath(new URL("../booklet_pdf_check.py", import.meta.url));
        const run = spawnSync("python3", [checker, html, saved["save-pdf"], "--out", out,
          "--shots", out, ...(saved["save-png"] ? ["--zip", saved["save-png"]] : [])],
          { encoding: "utf8" });
        for (const line of (run.stdout + run.stderr).trim().split("\n")) console.log(`      ${line}`);
        check("the PDF and the pages are the booklet (tools/booklet_pdf_check.py)", run.status === 0);
      }
    }
  }
  const said = await page.evaluate(() => document.title);
  console.log(`  (the app's title: ${said})`);
} catch (error) {
  check(String(error), false);
} finally {
  check(`no script errors (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 6)) console.log(`        ${e}`);
  await browser.close();
}
process.exit(failed ? 1 : 0);
