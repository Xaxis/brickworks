// Does a visitor read the site in their own language? (tools/site_lang.py,
// web/theme.js, src/boot/shell.html)
//
//   node tools/web/site_lang_flow.mjs [--out=DIR]               this checkout's web/, served here
//   node tools/web/site_lang_flow.mjs --url=<deployment>        a deployment's pages, as they are
//   ... --app=<address>  the app's loading page too: a deployment's /app, or a web
//                        export's index.html (node tools/web/relay_server.mjs PORT
//                        --static=build/web; --app=http://127.0.0.1:PORT/index.html)
//   [--widths=1280,390]  [--langs=en,de,fr,es]  [--pages=home,download,plans,faq,compare,gallery,library]
//
// The landing page and the download page, and the app's loading page
// between them and the app, in German, French and Spanish (2026-11-01);
// then the plans, the FAQ, the comparison, the gallery and the LDraw
// library (2026-11-01). A browser that asks for each language first
// (Accept-Language and navigator.languages, as Playwright's locale sets
// both), at 1280 and 390 px, opens each (/, /download, /plans, /faq,
// /compare, /gallery, /library) and must land on that language's copy
// (/de, /de/download...; English stays where it is) with:
//
//   its words: <html lang>, the title, the heading and the header's Sign in
//     as web/_lang/<code>.json says them, and the download offer's button
//     and "New in", the gallery's and the library's count of what they
//     list, as their scripts say them;
//   no English left: no English word (the, and, your, with...) in any text
//     of the page, shown or folded away, nor in an alt, title, aria-label
//     or placeholder, apart from names and what is typed (code), and
//     the cards of the live strips, whose names are people's, and the
//     library's themes the app too keeps under the catalogue's names;
//   nothing cut short: no words wider than the box that hides what
//     overflows it (a card's mark on a phone, "Tipp der Woc") where the
//     English page at that width shows its own whole (English is opened
//     first for that, asked for or not);
//   its way into the app: every link to /app carries ?lang=<code> (none in
//     English), so the app opens in it (src/ui/language.gd);
//   the footer's Language showing it.
//
// Then the choice: on /de, choosing English in the footer opens / and keeps
// it there on a reload, though the browser asks for German, and its links
// into the app say lang=en; choosing Deutsch goes back. A page with no copy
// (the changelog) carries the browser's language into the app all the same.
// With --app, the loading page says its words in the language the address
// asks for, or the one kept, and in English with neither.
//
// With no --url nothing leaves this machine: the pages are served by
// design_stand_in.mjs from this checkout's web/. Pictures with --out:
// <code>-<page>-<width>.png, the whole page.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const app = args.app ? String(args.app) : "";
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const widths = String(args.widths || "1280,390").split(",").map(Number);
const langs = String(args.langs || "en,de,fr,es").split(",");
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = bypass && (remote || /^https:/.test(app)) ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

const ASKED = {
  en: { locale: "en-US", header: "en-US,en;q=0.9" },
  de: { locale: "de-DE", header: "de-DE,de;q=0.9,en;q=0.5" },
  fr: { locale: "fr-FR", header: "fr-FR,fr;q=0.9,en;q=0.5" },
  es: { locale: "es-ES", header: "es-ES,es;q=0.9,en;q=0.5" },
};
// Each language's words, as tools/site_lang.py puts them in its pages.
const WORDS = Object.fromEntries(["de", "fr", "es"].map((code) => [code,
  JSON.parse(readFileSync(path.join(root, "web/_lang", `${code}.json`), "utf8"))]));
const plain = (html) => html.replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
const page = (code, english) => (code === "en" ? english : WORDS[code].pages[english] ?? `(no words for ${english})`);
const script = (code, english, values = {}) => (code === "en" ? english : WORDS[code].scripts[english] ?? english)
  .replace(/\{(\w+)\}/g, (all, name) => (name in values ? String(values[name]) : all));
const PAGES = [
  { name: "home", path: "", title: "Brickworks — design LEGO® models with AI, in your browser",
    heading: "#hero-h", says: "Design LEGO® models with AI, <em>in your browser</em>" },
  { name: "download", path: "/download", title: "Download Brickworks for Linux, macOS and Windows",
    heading: "#get-h", says: "Download Brickworks" },
  { name: "plans", path: "/plans", title: "Pricing · Brickworks" },
  { name: "faq", path: "/faq", title: "Questions · Brickworks", heading: "main h1", says: "Questions" },
  { name: "compare", path: "/compare", title: "Brickworks beside Studio, Mecabricks, LeoCAD and LDCad",
    heading: "main h1", says: "Studio exists. Why Brickworks?" },
  // Their lists drawn first: what their scripts say about them is checked too.
  { name: "gallery", path: "/gallery", title: "Gallery · Models built in Brickworks", heading: "#gallery-h",
    says: "Gallery", ready: "gallery", count: "#found", noun: ["model", "models"] },
  { name: "library", path: "/library", title: "Library · Every LEGO® set and its parts, in Brickworks",
    heading: "#library-h", says: "Library", ready: "library", count: "#found-said", noun: ["set", "sets"] },
];
const only = args.pages ? String(args.pages).split(",") : null;
// English that is never a word of German, French or Spanish.
const ENGLISH = /\b(the|and|with|your|you|this|that|from|without|what|which|every|they|their|into|would|could|should|our|are|isn't|don't|can't|it's)\b/i;
// What stays as it is in every language: names, and the words of a name.
const NAMES = /Brickworks|LEGO®[^.,;:]*?(?=\s|$)|Claude Code|Claude|ChatGPT|BrickLink Studio|BrickLink|Rebrickable|LDraw™?|LDCad|Mecabricks|GitHub|English|Deutsch|Français|Español/g;

let passed = 0;
let failed = 0;
const check = (ok, what) => {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  return ok;
};

async function newContext(browser, code, width) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, locale: ASKED[code].locale,
    extraHTTPHeaders: { ...headers, "accept-language": ASKED[code].header },
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), state: {} });
  return context;
}

/// Every text of the page a person can read or hear, shown or folded away,
/// but the names of the cards in its live strips and what is typed. And a
/// library theme's pill under the catalogue's own name (Star Wars, The LEGO
/// Movie), as the app keeps it: one the app names in the language
/// (locale/<code>.po, "theme") is read like any other word.
function readable() {
  const SKIP = "script, style, code, kbd, template, svg, [translate='no'], article.model .words, article.model .frame";
  const said = [];
  const walk = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
  for (let node = walk.nextNode(); node; node = walk.nextNode()) {
    const parent = node.parentElement;
    if (!parent || parent.closest(SKIP)) continue;
    if (parent.closest("#themes [data-pick]")?.dataset.pick === node.textContent.trim()) continue;
    // A <noscript>'s inside is its markup as text where scripts run.
    const text = parent.closest("noscript") ? node.textContent.replace(/<[^>]+>/g, " ") : node.textContent;
    if (text.trim()) said.push(text.trim());
  }
  for (const el of document.querySelectorAll("[alt], [title], [aria-label], [placeholder]")) {
    if (el.closest(SKIP)) continue;
    for (const name of ["alt", "title", "aria-label", "placeholder"]) {
      if (el.hasAttribute(name) && el.getAttribute(name).trim()) said.push(el.getAttribute(name));
    }
  }
  for (const meta of document.querySelectorAll("meta[name='description'], meta[property^='og:'], meta[name^='twitter:']")) {
    if (/description|title|alt/.test(meta.getAttribute("name") || meta.getAttribute("property"))) said.push(meta.content);
  }
  return said;
}

/// The words a box cuts off sideways: a text wider than the element that
/// hides what overflows it (a card's marks, a pill, a button), so a reader
/// sees "Tipp der Woc". A box cut short downwards (the marks' second row)
/// is how it is made, and a row that scrolls is not cut.
function cut() {
  const said = [];
  for (const el of document.querySelectorAll("body *")) {
    if (el.childElementCount || !el.textContent.trim() || !el.getClientRects().length) continue;
    let box = el;
    while (box && !/hidden|clip|auto|scroll/.test(getComputedStyle(box).overflowX)) box = box.parentElement;
    if (!box || box === document.documentElement || box === document.body) continue;
    if (/auto|scroll/.test(getComputedStyle(box).overflowX)) continue;
    const own = el.getBoundingClientRect();
    const room = box.getBoundingClientRect();
    // Not shown at all: said to a screen reader only (.visually-hidden).
    if (!own.width || room.width < 2 || room.height < 2) continue;
    const over = box === el ? el.scrollWidth > el.clientWidth + 1 : own.right > room.right + 1 || own.left < room.left - 1;
    if (over) said.push(el.textContent.trim());
  }
  return said;
}

// What the English page cuts (people's long model names, as it is made),
// by page and width: a copy may cut those and nothing else.
const cutInEnglish = new Map();

async function onePage(browser, code, one, width) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} ${one.name} ${width}`;
  try {
    await tab.goto(`${base}${one.path || "/"}`, { waitUntil: "load" });
    // web/theme.js gives way to the copy before the page is drawn.
    await tab.waitForLoadState("load");
    const want = code === "en" ? one.path || "/" : `/${code}${one.path}`;
    check(new URL(tab.url()).pathname === want, `${where}: opens ${want} (at ${new URL(tab.url()).pathname})`);
    check(await tab.evaluate(() => document.documentElement.lang) === code, `${where}: <html lang="${code}">`);
    const title = await tab.title();
    check(title === plain(page(code, one.title)), `${where}: its title says "${title}"`);
    if (one.heading) {
      const heading = (await tab.locator(one.heading).first().innerText()).replace(/\s+/g, " ").trim();
      check(heading === plain(page(code, one.says)), `${where}: its heading says "${heading}"`);
    }
    if (one.ready) {
      // Its list drawn, and counted in the language: "24 Modelle", "1.234 Sets".
      await tab.waitForFunction((name) => ["ready", "broken"].includes(document.documentElement.dataset[name]), one.ready,
        { timeout: 30000 });
      const counted = (await tab.locator(one.count).innerText()).trim();
      const nouns = one.noun.map((noun) => script(code, noun));
      check(await tab.evaluate((name) => document.documentElement.dataset[name], one.ready) === "ready"
        && nouns.some((noun) => counted.includes(noun)), `${where}: its list drawn and counted, "${counted}"`);
    }
    // The header's Sign in, once web/follow.js has said who is here.
    await tab.waitForFunction(() => document.querySelector(".site-head a[data-account]")?.textContent.trim(), null, { timeout: 15000 });
    const signIn = await tab.locator(".site-head .nav a[data-account]").textContent();
    check(signIn.trim() === script(code, "Sign in"), `${where}: the header's Sign in says "${signIn.trim()}"`);
    if (one.name === "download") {
      // Its script's words: the offer for this computer, and what is new.
      await tab.waitForFunction(() => !document.getElementById("notes").hidden, null, { timeout: 15000 });
      // The release the page offers: the one its own /releases.json names.
      const version = await tab.evaluate(() => fetch("/releases.json").then((reply) => reply.json()).then((list) => list.latest));
      const newIn = (await tab.locator("#notes-h").innerText()).trim();
      check(newIn === script(code, "New in {version}", { version }), `${where}: "${newIn}"`);
      if (width >= 600) {
        const offer = (await tab.locator("#offer-button").innerText()).trim();
        check(offer === script(code, "Download for {system}", { system: "Linux" }), `${where}: the offer says "${offer}"`);
      }
    }
    // No English left but names.
    if (code !== "en") {
      const left = (await tab.evaluate(readable)).map((text) => text.replace(NAMES, " ")).filter((text) => ENGLISH.test(text));
      check(!left.length, `${where}: no English left${left.length ? `: ${left.length}, first "${left[0].slice(0, 120)}"` : ""}`);
    }
    // Nothing cut short that the English page shows whole.
    const cuts = await tab.evaluate(cut);
    if (code === "en") cutInEnglish.set(`${one.name} ${width}`, new Set(cuts));
    else {
      const english = cutInEnglish.get(`${one.name} ${width}`) || new Set();
      const short = cuts.filter((text) => !english.has(text));
      check(!short.length, `${where}: nothing cut short${short.length ? `: ${short.length}, "${short.slice(0, 3).join('", "')}"` : ""}`);
    }
    // Every way into the app in the language.
    const apps = await tab.evaluate(() => [...document.querySelectorAll("a[href]")].map((a) => new URL(a.href))
      .filter((url) => url.pathname === "/app").map((url) => url.searchParams.get("lang")));
    const wrong = apps.filter((lang) => lang !== (code === "en" ? null : code));
    check(apps.length >= 3 && !wrong.length, `${where}: ${apps.length} links into the app${code === "en" ? " ask no language" : ` say lang=${code}`}${wrong.length ? `, ${wrong.length} not: ${wrong[0]}` : ""}`);
    const shown = await tab.locator(".site-foot select[data-lang-choice]").inputValue();
    check(shown === code, `${where}: the footer's Language shows ${shown}`);
    if (out) {
      // Every section drawn: a .defer section off the screen is skipped
      // (content-visibility), and a whole-page picture would show it blank.
      await tab.addStyleTag({ content: ".defer { content-visibility: visible !important; }" });
      await tab.screenshot({ path: path.join(out, `${code}-${one.name}-${width}.png`), fullPage: true });
    }
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

async function choosing(browser) {
  const context = await newContext(browser, "de", 1280);
  const tab = await context.newPage();
  try {
    await tab.goto(`${base}/de`, { waitUntil: "load" });
    await Promise.all([tab.waitForURL((url) => url.pathname === "/"), tab.selectOption(".site-foot select[data-lang-choice]", "en")]);
    check(new URL(tab.url()).pathname === "/", "choosing English on /de opens /");
    await tab.reload({ waitUntil: "load" });
    check(new URL(tab.url()).pathname === "/" && await tab.evaluate(() => document.documentElement.lang) === "en",
      "and / stays English on a reload, though the browser asks for German");
    const langs = await tab.evaluate(() => [...document.querySelectorAll('a[href^="/app"]')].map((a) => new URL(a.href).searchParams.get("lang")));
    check(langs.length >= 3 && langs.every((lang) => lang === "en"), `and its ${langs.length} links into the app say lang=en`);
    await tab.goto(`${base}/download`, { waitUntil: "load" });
    check(new URL(tab.url()).pathname === "/download", "and /download stays English too");
    await Promise.all([tab.waitForURL((url) => url.pathname === "/de/download"), tab.selectOption(".site-foot select[data-lang-choice]", "de")]);
    check(new URL(tab.url()).pathname === "/de/download", "choosing Deutsch on /download opens /de/download");
    await tab.goto(`${base}/`, { waitUntil: "load" });
    check(new URL(tab.url()).pathname === "/de", "and / opens /de from then on");
    await tab.goto(`${base}/gallery`, { waitUntil: "load" });
    check(new URL(tab.url()).pathname === "/de/gallery", "and /gallery opens /de/gallery");
    await tab.goto(`${base}/changelog`, { waitUntil: "load" });
    const shown = await tab.locator(".site-foot select[data-lang-choice]").inputValue();
    const into = await tab.evaluate(() => [...document.querySelectorAll('a[href^="/app"]')].map((a) => new URL(a.href).searchParams.get("lang")));
    check(shown === "de" && into.length >= 1 && into.every((lang) => lang === "de"),
      `and the changelog, still in English, shows Deutsch chosen (${shown}) and opens the app in it (${into.length} links)`);
  } catch (trouble) {
    check(false, `choosing: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
  // A page with no copy still carries the browser's language into the app.
  const french = await newContext(browser, "fr", 1280);
  const changes = await french.newPage();
  try {
    await changes.goto(`${base}/changelog`, { waitUntil: "load" });
    const langs = await changes.evaluate(() => [...document.querySelectorAll('a[href^="/app"]')].map((a) => new URL(a.href).searchParams.get("lang")));
    check(new URL(changes.url()).pathname === "/changelog" && langs.length >= 1 && langs.every((lang) => lang === "fr"),
      `the changelog, in English, sends a French browser into a French app (${langs.length} links)`);
  } catch (trouble) {
    check(false, `changelog: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await french.close();
  }
}

// The app's loading page, before the engine has started.
const LOADER = {
  en: { tagline: "Every brick, at the size it really is.", of: "of", legal: "LEGO® is a trademark of the LEGO Group of companies" },
  de: { tagline: "Jeder Stein, in seiner wahren Größe.", of: "von", legal: "LEGO® ist eine Marke der LEGO Unternehmensgruppe" },
  fr: { tagline: "Chaque brique, à sa vraie taille.", of: "sur", legal: "LEGO® est une marque du groupe de sociétés LEGO" },
  es: { tagline: "Cada ladrillo, a su tamaño real.", of: "de", legal: "LEGO® es una marca del grupo de empresas LEGO" },
};
async function loader(browser) {
  const read = async (tab) => tab.evaluate(() => ({
    lang: document.documentElement.lang,
    tagline: document.querySelector("#boot .tagline")?.textContent.trim(),
    of: document.getElementById("count-of")?.textContent.trim(),
    legal: document.getElementById("legal")?.textContent.replace(/\s+/g, " ").trim(),
    links: document.querySelectorAll("#legal a").length,
  }));
  for (const code of langs) {
    for (const width of widths) {
      const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, extraHTTPHeaders: headers });
      const tab = await context.newPage();
      try {
        await tab.goto(`${app}${code === "en" ? "" : `?lang=${code}`}`, { waitUntil: "domcontentloaded" });
        await tab.waitForSelector("#boot .tagline", { state: "attached" });
        const said = await read(tab);
        const want = LOADER[code];
        check(said.tagline === want.tagline && said.of === want.of && said.legal.includes(want.legal) && said.links === 2,
          `the loading page${code === "en" ? "" : ` with ?lang=${code}`} (${width}): "${said.tagline}", "${said.of}", the notice in it, its two licences linked`);
        if (out) await tab.screenshot({ path: path.join(out, `${code}-app-${width}.png`) });
      } catch (trouble) {
        check(false, `loading page ${code} ${width}: ${String(trouble.message || trouble).split("\n")[0]}`);
      } finally {
        await context.close();
      }
    }
  }
  // Kept, with no ?lang: as the site or the app's Settings left it.
  const context = await browser.newContext({ extraHTTPHeaders: headers });
  await context.addInitScript(() => localStorage.setItem("brickworks.lang", "es"));
  const tab = await context.newPage();
  try {
    await tab.goto(app, { waitUntil: "domcontentloaded" });
    await tab.waitForSelector("#boot .tagline", { state: "attached" });
    const said = await read(tab);
    check(said.lang === "es" && said.tagline === LOADER.es.tagline, `the loading page with Spanish kept says "${said.tagline}"`);
  } catch (trouble) {
    check(false, `loading page kept: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

const browser = await launch({ signedOut: true });
try {
  console.log(`site in four languages on ${base}`);
  for (const code of langs.includes("en") ? langs : ["en", ...langs]) {
    for (const one of PAGES.filter((page) => !only || only.includes(page.name))) {
      for (const width of widths) await onePage(browser, code, one, width);
    }
  }
  await choosing(browser);
  if (app) await loader(browser);
  else console.log("  --    the app's loading page: --app=<a deployment's /app, or a web export's index.html>");
} finally {
  await browser.close();
}
console.log(`\nsite language flow: ${passed} checks passed, ${failed} failed`);
process.exit(failed || !passed ? 1 : 0);
