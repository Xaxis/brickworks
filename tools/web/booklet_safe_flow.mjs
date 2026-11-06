// A shared model's file never runs script in the booklet tab, in a real browser.
//
//   node tools/web/booklet_safe_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=shots/booklet_safe
//
// On the web the booklet is written into a tab of the site's own
// (BookletTab, BookletOut), with its storage and its sign-in, and its words
// and pictures come from the model's file, which anyone may have made. A
// page's picture went into its HTML as the file had it, so data that was
// not base64 could break out of the attribute and run (2026-11-06, found by
// the psreview review; booklet_safe_probe checks each place headless).
//
// This writes a model of two steps whose page carries two pictures of its
// designer's: a good PNG, and one whose data breaks out of the attribute to
// set a harmless flag; and whose page is set up with a picture behind it
// (pagesetup) whose data breaks out of the stylesheet's url() to do the
// same. It opens the model (Open > From a file), presses Instructions and
// reads the tab. Fails if the flag is set, if the picture behind the pages
// is drawn, if the good picture is not shown or any picture does not
// decode, if the booklet's
// security policy is not the first thing in it, if script put into the tab
// afterwards runs (the policy honoured in a document.write tab), or if
// Print does not print.
import { controlsWith, launch, openFromFile } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:9960/index.html";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/booklet_safe";
mkdirSync(out, { recursive: true });

// A PNG of one pixel, and the same with data after it that ends the src
// attribute and adds a handler setting a flag.
const PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
const BROKEN = PNG + "x\" onerror=\"window.__booksafe=1\" x=\"";
const BEHIND = PNG + "x);}</style><img src=x onerror=\"window.__booksafe=4\"><style>{";
const model = path.resolve(out, "booksafe.ldr");
writeFileSync(model, [
  "0 Booklet safe",
  "0 Name: booksafe.ldr",
  "0 Author: booklet_safe_flow",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "0 !BRICKWORKS IMAGE 150 30 40 30 brickworks-page-1.png",
  "0 !BRICKWORKS IMAGE 150 70 40 30 brickworks-page-2.png",
  "0 !BRICKWORKS PAGE_SETUP PICTURE brickworks-page-behind.png",
  "0 STEP",
  "1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "0 STEP",
  "0 !DATA brickworks-page-1.png",
  `0 !: ${PNG}`,
  "0 !DATA brickworks-page-2.png",
  `0 !: ${BROKEN}`,
  "0 !DATA brickworks-page-behind.png",
  `0 !: ${BEHIND}`,
  "",
].join("\n"));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};
page.on("pageerror", (e) => errors.push(`app: ${String(e).slice(0, 200)}`));

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  const until = Date.now() + 300000;
  while (!(await page.evaluate(() => (window.brickworksControls || {}).instructions))) {
    if (Date.now() > until) throw new Error("the Instructions button never appeared");
    await page.waitForTimeout(1000);
  }
  await page.waitForTimeout(Number(args.load || 20000));
  await openFromFile(page, model, { shots: out });
  let parts = 0;
  let waiting = null;
  for (let n = 0; n < 240; n++) {
    await page.waitForTimeout(2000);
    const now = await page.evaluate(() => window.brickworksState || {});
    parts = now.bricks || 0;
    waiting = now.awaited;
    if (parts === 2 && waiting === 0) break;
  }
  check(`the crafted model opens (${parts} parts)`, parts === 2 && !waiting);

  const at = (await controlsWith(page, ["instructions"])).instructions;
  const opened = context.waitForEvent("page", { timeout: 30000 });
  await page.mouse.click(at.x, at.y);
  const tab = await opened.catch(() => null);
  check("pressing Instructions opens a tab", tab !== null);
  if (tab) {
    tab.on("pageerror", (e) => errors.push(`booklet: ${String(e).slice(0, 200)}`));
    const started = Date.now();
    const limit = Number(args.wait || 900) * 1000;
    let whole = false;
    while (Date.now() - started < limit) {
      const [state, pages] = await tab.evaluate(() => [document.readyState,
        document.querySelectorAll("section.page").length]).catch(() => ["", 0]);
      if (state === "complete" && pages > 0) { whole = true; break; }
      await tab.waitForTimeout(2000);
    }
    check(`the booklet arrives whole (${((Date.now() - started) / 1000).toFixed(1)} s)`, whole);
    await tab.waitForTimeout(1500);
    const facts = await tab.evaluate(() => {
      const designers = [...document.images].filter((i) => i.alt === "A picture of the designer's");
      const first = document.head && document.head.firstElementChild;
      const policy = document.querySelector('meta[http-equiv="Content-Security-Policy"]');
      return {
        flag: window.__booksafe, opener: window.opener ? window.opener.__booksafe : undefined,
        pictures: document.images.length,
        broken: [...document.images].filter((i) => !i.complete || i.naturalWidth === 0).length,
        designers: designers.length,
        shown: designers.filter((i) => i.naturalWidth > 0).length,
        handlers: [...document.querySelectorAll("*")].filter((e) =>
          [...e.attributes].some((a) => a.name.startsWith("on"))).length,
        first: first ? first.outerHTML.slice(0, 80) : "",
        policy: policy ? policy.content : "",
        policyFirst: Boolean(policy) && [...document.head.children].indexOf(policy) <= 1,
        styles: document.querySelectorAll("style").length,
        behind: getComputedStyle(document.querySelector("section.page")).backgroundImage,
      };
    });
    writeFileSync(path.join(out, "booklet.html"),
      await tab.evaluate(() => "<!doctype html>\n" + document.documentElement.outerHTML));
    check(`the file's picture data ran nothing (flag ${facts.flag}, in the app ${facts.opener})`,
      facts.flag === undefined && facts.opener === undefined);
    check(`no element has a handler of the file's (${facts.handlers})`, facts.handlers === 0);
    check(`the picture behind the pages that broke out of its url() left out (${facts.styles} styles, `
      + `behind the page: ${facts.behind.slice(0, 40)})`, facts.behind === "none");
    check(`the good picture of the designer's shown (${facts.shown} of ${facts.designers})`,
      facts.designers === 1 && facts.shown === 1);
    check(`every picture decodes (${facts.pictures - facts.broken} of ${facts.pictures})`,
      facts.pictures > 1 && facts.broken === 0);
    check(`the booklet's policy comes first (${facts.policy || facts.first})`,
      facts.policyFirst && /script-src 'none'/.test(facts.policy));

    // Script put into the tab now, as a page that broke out would: refused
    // by the policy the tab was written with.
    const refused = await tab.evaluate(async () => {
      const said = [];
      document.addEventListener("securitypolicyviolation", (e) => said.push(e.violatedDirective));
      const script = document.createElement("script");
      script.textContent = "window.__booksafe = 2";
      document.body.append(script);
      document.body.insertAdjacentHTML("beforeend",
        "<img src=\"data:image/png;base64,x\" onerror=\"window.__booksafe = 3\">");
      await new Promise((done) => setTimeout(done, 1000));
      return { flag: window.__booksafe, said };
    });
    check(`script put into the tab runs nothing (flag ${refused.flag}; refused: ${refused.said.join(", ")})`,
      refused.flag === undefined && refused.said.length >= 2);

    await tab.evaluate(() => { window.printed = 0; window.print = () => { window.printed += 1; }; });
    await tab.click(".bar button");
    await tab.waitForTimeout(500);
    const printed = await tab.evaluate(() => window.printed);
    check(`Print prints (${printed})`, printed === 1);
    await tab.locator("section.page >> nth=1").screenshot({ path: path.join(out, "page-2.png") })
      .catch(() => {});
  }
} catch (error) {
  check(String(error), false);
} finally {
  check(`no script errors (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 6)) console.log(`        ${e}`);
  await browser.close();
}
process.exit(failed ? 1 : 0);
