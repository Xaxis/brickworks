// The documentation at /docs (tools/docs_site.py makes it from docs-site/),
// as a reader meets it.
//
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/docs_flow.mjs --url=<deployment> --out=DIR
//   node tools/web/docs_flow.mjs --root=DIR --out=DIR     a site put together by
//                                                         tools/site.py DIR, served here
//
//   1. /docs and every page its pages list names answer 200, each with its
//      own title and canonical link; on a deployment /docs/<page>.html
//      answers 308 to /docs/<page> and /docs/ to /docs.
//   2. Every link on every docs page to the site answers (200 after its
//      redirects), and every #fragment is an id on its page.
//   3. /docs and a long page in light and dark at 390 and 1400 px: drawn
//      in the theme's own colours, nothing sideways, no error logged.
//   4. Search: Ctrl+K opens it; "fresh eyes" and "Build together" each
//      find their own page first; Enter goes there; Escape closes it and
//      gives the focus back; / opens it too.
//   5. The pages list: at 390 px hidden behind Browse the docs, which opens
//      it, and a link in it goes to its page; at 1400 px down the left, with
//      the page being read marked; what is on this page marks the section
//      scrolled to; a deep link lands with its heading in view.
//
// Pictures in --out: docs_<width>_<theme>.png and search_<width>_<theme>.png.
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
let served = null;
if (args.root) served = await serveDir(path.resolve(String(args.root)));
const site = served ? served.url : String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("docs_flow: --url=<deployment> or --root=<a site from tools/site.py>");
  process.exit(2);
}
const remote = !served;
const out = path.resolve(String(args.out || "shots/docs"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let failed = 0;
const check = (what, ok, detail = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${!ok && detail ? ` (${detail})` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
async function get(address, redirect = "follow") {
  for (let attempt = 0; ; attempt += 1) {
    try {
      const answer = await fetch(address.startsWith("http") ? address : site + address, { headers, redirect });
      return { status: answer.status, location: answer.headers.get("location") || "", body: redirect === "follow" ? await answer.text() : "" };
    } catch (trouble) {
      if (attempt >= 2) return { status: 0, location: "", body: String(trouble) };
      await new Promise((done) => setTimeout(done, 1000));
    }
  }
}

// -- 1. the pages ------------------------------------------------------------
console.log("docs_flow: the pages");
const start = await get("/docs");
check("/docs answers 200", start.status === 200, String(start.status));
const pages = ["/docs", ...new Set([...start.body.matchAll(/<nav class="docs-side"[\s\S]*?<\/nav>/g)]
  .flatMap((m) => [...m[0].matchAll(/href="(\/docs\/[a-z0-9-]+)"/g)].map((h) => h[1])))];
check(`the pages list names ${pages.length - 1} pages besides /docs`, pages.length > 20, String(pages.length));
const bodies = new Map();
const titles = new Set();
for (const page of pages) {
  const answer = page === "/docs" ? start : await get(page);
  bodies.set(page, answer.body);
  const title = (answer.body.match(/<title>([^<]*)<\/title>/) || [])[1] || "";
  const canonical = (answer.body.match(/<link rel="canonical" href="([^"]+)"/) || [])[1] || "";
  const fine = answer.status === 200 && title && !titles.has(title) && canonical === `https://brickworks.diy${page}`;
  titles.add(title);
  if (!fine) check(`${page} answers 200 with its own title and canonical`, false, `${answer.status} "${title}" ${canonical}`);
}
check(`all ${pages.length} pages answer 200 with their own title and canonical link`, [...bodies.values()].every(Boolean));
if (remote) {
  const old = await get("/docs/shortcuts.html", "manual");
  check("/docs/shortcuts.html answers 308 to /docs/shortcuts", old.status === 308 && old.location.endsWith("/docs/shortcuts"), `${old.status} ${old.location}`);
  const slash = await get("/docs/", "manual");
  check("/docs/ answers 308 to /docs", slash.status === 308 && slash.location.replace(site, "").replace("https://brickworks.diy", "") === "/docs", `${slash.status} ${slash.location}`);
}

// -- 2. every link resolves ------------------------------------------------------
console.log("docs_flow: every link");
const ids = new Map();
for (const [page, body] of bodies) ids.set(page, new Set([...body.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1])));
const targets = new Map();
for (const [page, body] of bodies) {
  for (const [, attr, raw] of body.matchAll(/\s(href|src)="([^"]+)"/g)) {
    const target = raw.replace(/&amp;/g, "&");
    if (/^(https?:|mailto:)/.test(target) && !target.startsWith("https://brickworks.diy")) continue;
    const local = target.replace("https://brickworks.diy", "");
    if (local.startsWith("https://")) continue;
    const [where, fragment] = local.split("#");
    const address = where || page;
    if (!targets.has(address)) targets.set(address, new Set());
    targets.get(address).add(`${page}${fragment ? ` #${fragment}` : ""}`);
    if (fragment && ids.has(address) && !ids.get(address).has(fragment)) {
      check(`${page} links ${local}, an id on its page`, false, "no such id");
    }
  }
}
// Canonical and the Open Graph card name brickworks.diy itself; the rest of
// the site is checked by site_check.mjs. Here: every address the docs reach.
let dead = 0;
for (const address of targets.keys()) {
  if (bodies.has(address)) continue;
  if (address.startsWith("/app")) continue; // the app, which site_check boots
  // The server's pages, made by api/: a deployment has them, a folder does not.
  if (!remote && /^\/(collections|m|u|c|api|oauth)(\/|$)/.test(address)) continue;
  const answer = await get(address);
  if (answer.status !== 200) {
    dead += 1;
    check(`${address} answers (linked from ${[...targets.get(address)][0]})`, false, String(answer.status));
  }
}
check(`every one of ${targets.size} addresses the docs link or show answers, and each #fragment is on its page`, dead === 0);

// -- 3-5. in a browser ----------------------------------------------------------
const browser = await launch({ signedOut: true });
async function open(address, { width, dark }) {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 },
    extraHTTPHeaders: headers, colorScheme: dark ? "dark" : "light", isMobile: width < 600, hasTouch: width < 600 });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/overlook|favicon|Failed to load resource/.test(m.text())) errors.push(m.text()); });
  await page.goto(site + address, { waitUntil: "networkidle" });
  return { page, context, errors };
}
const sideways = (page) => page.evaluate(() => document.scrollingElement.scrollWidth - window.innerWidth);
const LONG = "/docs/shortcuts";
for (const width of [390, 1400]) {
  for (const dark of [false, true]) {
    const theme = dark ? "dark" : "light";
    console.log(`docs_flow: ${width} px, ${theme}`);
    for (const address of ["/docs", LONG, "/docs/mcp-tools"]) {
      const { page, context, errors } = await open(address, { width, dark });
      const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      const want = dark ? "rgb(14, 16, 19)" : "rgb(244, 245, 247)";
      check(`${address} at ${width} ${theme}: drawn in the theme, nothing sideways, no error`,
        bg === want && (await sideways(page)) <= 0 && !errors.length,
        `background ${bg}, ${await sideways(page)} px sideways, ${errors.join("; ")}`);
      if (address === "/docs") await page.screenshot({ path: `${out}/docs_${width}_${theme}.png`, fullPage: false });
      if (address === LONG && width === 1400 && !dark) await page.screenshot({ path: `${out}/shortcuts_${width}_${theme}.png` });
      await context.close();
    }
  }
}

console.log("docs_flow: search");
for (const [width, dark] of [[1400, false], [390, true]]) {
  const theme = dark ? "dark" : "light";
  const { page, context } = await open("/docs/building", { width, dark });
  await page.keyboard.press("Control+K");
  const opened = await page.waitForFunction(() => document.querySelector("dialog.docs-search")?.open
    && document.activeElement === document.querySelector("dialog.docs-search input"), null, { timeout: 4000 }).then(() => true, () => false);
  check(`${width} ${theme}: Ctrl+K opens search with the box focused`, opened);
  for (const [query, want] of [["fresh eyes", "/docs/fresh-eyes"], ["Build together", "/docs/build-together"]]) {
    await page.fill("dialog.docs-search input", query);
    const first = await page.waitForFunction(() => document.querySelector(".docs-results li a")?.getAttribute("href"), null, { timeout: 6000 })
      .then((h) => h.jsonValue(), () => "");
    check(`"${query}" finds ${want} first`, first.split("#")[0] === want, first);
    if (query === "fresh eyes" && width === 1400) await page.screenshot({ path: `${out}/search_${width}_${theme}.png` });
    if (query === "fresh eyes" && width === 390) await page.screenshot({ path: `${out}/search_${width}_${theme}.png` });
  }
  await page.keyboard.press("Enter");
  await page.waitForURL(/\/docs\/build-together/, { timeout: 8000 }).catch(() => {});
  check("Enter goes to the result chosen", new URL(page.url()).pathname === "/docs/build-together", page.url());
  await page.keyboard.press("/");
  const slash = await page.waitForFunction(() => document.querySelector("dialog.docs-search")?.open, null, { timeout: 3000 }).then(() => true, () => false);
  await page.keyboard.press("Escape");
  const closed = await page.waitForFunction(() => !document.querySelector("dialog.docs-search")?.open, null, { timeout: 3000 }).then(() => true, () => false);
  check("/ opens search and Escape closes it", slash && closed);
  await context.close();
}

console.log("docs_flow: the pages list and what is on this page");
{
  const { page, context } = await open("/docs/selecting", { width: 390, dark: false });
  const hidden = await page.evaluate(() => getComputedStyle(document.getElementById("docs-side")).display === "none");
  await page.click(".docs-menu-button");
  const shown = await page.evaluate(() => getComputedStyle(document.getElementById("docs-side")).display !== "none"
    && document.querySelector(".docs-menu-button").getAttribute("aria-expanded") === "true");
  check("390 px: the pages list folded behind Browse the docs, which opens it", hidden && shown);
  await page.screenshot({ path: `${out}/docs_390_light_menu.png` });
  await page.click('#docs-side a[href="/docs/the-view"]');
  await page.waitForURL(/\/docs\/the-view$/, { timeout: 8000 }).catch(() => {});
  check("a link in it goes to its page", new URL(page.url()).pathname === "/docs/the-view", page.url());
  await context.close();
}
{
  const { page, context } = await open("/docs/selecting", { width: 1400, dark: true });
  const side = await page.evaluate(() => {
    const nav = document.getElementById("docs-side");
    return getComputedStyle(nav).display !== "none" && nav.getBoundingClientRect().left < 300
      && nav.querySelector('a[aria-current="page"]')?.getAttribute("href");
  });
  check("1400 px: the pages list down the left, this page marked", side === "/docs/selecting", String(side));
  const heads = await page.$$eval(".docs-article h2[id]", (all) => all.map((h) => h.id));
  const last = heads[heads.length - 1];
  await page.evaluate((id) => document.getElementById(id).scrollIntoView(), last);
  const marked = await page.waitForFunction((id) => document.querySelector(`.docs-toc a[aria-current="true"]`)?.hash === `#${id}`, last, { timeout: 4000 })
    .then(() => true, () => false);
  check("what is on this page marks the section scrolled to", marked, last);
  await context.close();
  const deep = await open(`/docs/selecting#${heads[1]}`, { width: 1400, dark: false });
  const inView = await deep.page.evaluate((id) => {
    const r = document.getElementById(id).getBoundingClientRect();
    return r.top >= 0 && r.top < innerHeight / 2;
  }, heads[1]);
  check(`a deep link (#${heads[1]}) lands with its heading in view`, inView);
  await deep.context.close();
}

await browser.close();
if (served) served.close();
console.log(failed ? `docs_flow: FAILED, ${failed} check(s)` : "docs_flow: every check passed");
process.exit(failed ? 1 : 0);
