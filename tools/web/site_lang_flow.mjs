// Does a visitor read the site in their own language? (tools/site_lang.py,
// web/theme.js, src/boot/shell.html)
//
//   node tools/web/site_lang_flow.mjs [--out=DIR]               this checkout's web/, served here
//   node tools/web/site_lang_flow.mjs --url=<deployment>        a deployment's pages, as they are
//   ... --app=<address>  the app's loading page too: a deployment's /app, or a web
//                        export's index.html (node tools/web/relay_server.mjs PORT
//                        --static=build/web; --app=http://127.0.0.1:PORT/index.html)
//   [--widths=1280,390]  [--langs=en,de,fr,es]
//   [--pages=home,download,plans,faq,compare,gallery,library,set,model,sitemaps,signin,firststeps]
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
//     library's themes the app too keeps under the catalogue's names; and
//     each theme the language words its own way (locale/<code>.po,
//     "theme": Sammelminifiguren) said so;
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
// And signing in (2026-11-01, web/account.js), in each language at each
// width: from Sign in on /profile, a page with no copy, where the header's
// Sign in and the app's orangecheck send people, and from Like on the
// gallery's copy. The dialog in the language, none of it English or cut
// short; the server's "too many codes" in it; the code's step; a wrong
// code's error; and on the stand-in, signed in, the age question with the
// months as the language names them. No mail is sent: /api/otp is answered
// in the browser, and on a deployment only the wrong code is asked of its
// Supabase, once a run per language and width.
//
// A set's page (2026-11-01, api/_sets.js, written on the server): from
// /library/set/<number> a browser asking for a language lands on its copy,
// /de/library/set/<number>, with <html lang>, the title, the crumbs (the
// theme as locale/<code>.po words it), the facts, the actions and the parts
// list's heads in it, the set's name as LEGO® publishes it, the five
// hreflang alternates and a canonical that is the page itself. Its parts
// list names each part, colour and kind as the app's parts bin does in the
// language (api/_parts.js partNames: Platte, Plaque, Placa...), a part the
// app has no words for as LDraw writes it, marked as English.
//
// And a model's page (/m/<id>, the stand-in's watchtower or a deployment's
// first listed model, api/share.js, written on the server): from /m/<id> a
// browser asking for a language lands on its copy, /de/m/<id>, with <html
// lang>, the title, the crumbs, the tabs, the actions, the comments' Reply
// and step pills, every date as the language writes it and no English but
// what its builder wrote; the five alternates and its own canonical. Its
// parts list names each part and colour as a set's does. And a card of the
// gallery's copy opens the model's copy (/de/gallery to /de/m/<id>).
//
// The header keeps the Brickworks wordmark on every page, in every language,
// at every width checked (390 included): Open the app takes two lines first.
//
// And the sitemaps (/sitemaps/index.xml): the sets' pages in English and
// each language's copies, a file each (sets-de-1.xml), every address in it,
// and the models' copies (models-de.xml), one for each model /sitemap.xml
// lists.
//
// And First steps (web/first-steps.js), opened over the gallery's copy as a
// first sign-in opens it, and on the stand-in after the age question: each
// step's words in the language, none English, nothing cut short.
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
// The themes each language words its own way (locale/<code>.po, "theme"),
// by the app's names, which mark the catalogue's LEGO and Legoland
// (web/card.js themeSaid), as tools/site_lang.py puts them in the copies.
const marked = (name) => name.replace(/\bLEGO\b(?!®| Group)/g, "LEGO®").replace(/\bLegoland\b|\bLEGOLAND\b(?!®)/g, "LEGOLAND®");
const THEMES = Object.fromEntries(["de", "fr", "es"].map((code) => {
  const po = readFileSync(path.join(root, "locale", `${code}.po`), "utf8");
  const said = {};
  for (const [, english, own] of po.matchAll(/^msgctxt "theme"\nmsgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"/gm)) {
    const [name, words] = [JSON.parse(`"${english}"`), JSON.parse(`"${own}"`)];
    if (words && words !== name) said[name] = words;
  }
  return [code, said];
}));
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
  // A set built in 3D whose theme is a word in each language.
  { name: "set", path: "/library/set/10297-1", set: { number: "10297-1", name: "Boutique Hotel", theme: "Modular Buildings" },
    title: (code) => script(code, "{name}, LEGO® set {set}: every part — Brickworks", { name: "Boutique Hotel", set: "10297-1" }),
    heading: "main h1", says: () => "Boutique Hotel" },
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

async function newContext(browser, code, width, state = {}) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, locale: ASKED[code].locale,
    extraHTTPHeaders: { ...headers, "accept-language": ASKED[code].header },
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), state });
  return context;
}

/// Every text of the page a person can read or hear, shown or folded away,
/// but the names of the cards in its live strips, what is typed, and a
/// parts list's part, colour and kind names (as LDraw writes those the app
/// has no words for: lotsSaid checks each). And a
/// library theme's pill under the catalogue's own name (Star Wars, The LEGO®
/// Movie, marked), as the app keeps it: one the app names in the language
/// (locale/<code>.po, "theme") is read like any other word.
function readable(more = "") {
  const SKIP = "script, style, code, kbd, template, svg, [translate='no'], article.model .words, article.model .frame, "
    + `.lot-list .name, .lot-list .meta, .lot-list .group > span:not(.n)${more ? `, ${more}` : ""}`;
  const said = [];
  const walk = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
  for (let node = walk.nextNode(); node; node = walk.nextNode()) {
    const parent = node.parentElement;
    if (!parent || parent.closest(SKIP)) continue;
    const pick = parent.closest("#themes [data-pick]")?.dataset.pick;
    if (pick && pick.replace(/\bLEGO\b(?!®| Group)/g, "LEGO®").replace(/\bLegoland\b|\bLEGOLAND\b(?!®)/g, "LEGOLAND®")
      === node.textContent.trim()) continue;
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
/// is how it is made, and a row that scrolls is not cut; nor a parts
/// list's names, one line each in every language, whole on their tooltip
/// (lotsSaid checks they are).
function cut() {
  const said = [];
  for (const el of document.querySelectorAll("body *")) {
    if (el.childElementCount || !el.textContent.trim() || !el.getClientRects().length) continue;
    if (el.closest(".lot-list .name, .lot-list .meta")) continue;
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

/// Whether the header shows the Brickworks wordmark's word beside the
/// mark, on its line: it wraps out of sight where the bar has no room.
function markShown() {
  const mark = document.querySelector(".site-head .mark");
  const word = mark && [...mark.childNodes].find((node) => node.nodeType === 3 && node.textContent.trim());
  if (!word) return false;
  const range = document.createRange();
  range.selectNodeContents(word);
  const shown = range.getBoundingClientRect();
  const box = mark.getBoundingClientRect();
  return shown.width > 0 && shown.top < box.bottom - 2 && shown.right <= box.right + 1;
}

// A word each language names a plate with, as the app's parts bin does
// (src/parts/part_words.gd): every set and model here has plates.
const PLATE = { de: "Platte", fr: "Plaque", es: "Placa" };

/// The parts list on [tab], drawn, against its own JSON asked in [code]
/// (?lang=): each row's part named as the JSON says it in the language, or
/// as LDraw writes it where the app has no words, marked as English where
/// the page is not, and each colour's head likewise.
async function lotsSaid(tab, code, where, plate = true) {
  await tab.locator("#parts").scrollIntoViewIfNeeded();
  await tab.waitForFunction(() => document.documentElement.dataset.parts === "drawn", null, { timeout: 30000 });
  const said = await tab.evaluate(async (code) => {
    const section = document.getElementById("parts");
    const asked = new URL(section.dataset.parts, location.href);
    if (code !== "en") asked.searchParams.set("lang", code);
    const body = await fetch(asked).then((reply) => reply.json());
    const page = document.documentElement.lang || "en";
    const marked = (element, words, inIt) => {
      const want = inIt ? (code === page ? "" : code) : (page === "en" ? "" : "en");
      return element.textContent === words && (element.getAttribute("lang") || "") === want;
    };
    const byKey = new Map(body.lots.map((lot) => [`${lot.part}/${lot.colour}`, lot]));
    const rows = [...section.querySelectorAll(".lot-list li.lot")];
    const wrong = [];
    for (const row of rows) {
      const lot = byKey.get(`${row.dataset.part}/${row.dataset.colour}`);
      const name = row.querySelector(".name");
      // And whole on its tooltip, where the row cuts it to one line.
      if (!lot || !marked(name, lot.said || lot.name, Boolean(lot.said)) || !name.title.startsWith(name.textContent)) {
        wrong.push(name.textContent);
      }
    }
    const heads = [...section.querySelectorAll(".lot-list li.group > span:not(.n)")];
    const colours = new Set(body.lots.map((lot) => lot.colour_said || lot.colour_name));
    return { lots: body.lots.length, rows: rows.length, said: body.lots.filter((lot) => lot.said).length,
      colours: body.lots.filter((lot) => lot.colour_said).length, wrong,
      heads: heads.filter((head) => !colours.has(head.textContent)).map((head) => head.textContent),
      names: rows.map((row) => row.querySelector(".name").textContent) };
  }, code);
  const plates = code === "en" ? [] : said.names.filter((name) => name.startsWith(`${PLATE[code]} `));
  const first = plates[0] || said.names[0] || "";
  check(said.rows === said.lots && !said.wrong.length && !said.heads.length
    && (code === "en" ? said.said === 0 : said.said > said.lots / 3 && said.colours > said.lots / 2 && (!plate || plates.length > 0)),
    `${where}: ${said.said} of ${said.lots} parts and ${said.colours} colours named in ${code}${code === "en" ? "" : `, "${first}"`}`
    + `${said.wrong.length ? `, ${said.wrong.length} rows not as said: "${said.wrong[0]}"` : ""}`
    + `${said.heads.length ? `, heads "${said.heads.slice(0, 2).join('", "')}"` : ""}`);
}

// What a builder wrote on a model's page, and the people and models it
// names: read as they wrote them, in no language of the site's.
const THEIRS = "h1, .description, .tags, .shared-by .names, .modelled-by b, .comment-body, .comment-head a, "
  + ".comment-head b, .build q, .build .by a, .version-note, .versions q, .from a, .line a, .list-card, .based a, .based q";

/// A model's page in [code] (/de/m/<id>), from its English address [at] as
/// a browser asking for the language opens it: its words, the parts list's
/// names as the app says them, the comments' chrome, its dates, the
/// alternates and its own canonical.
async function modelSaid(browser, code, width, at) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} model ${width}`;
  const own = code === "en" ? at : `/${code}${at}`;
  try {
    await tab.goto(`${base}${at}`, { waitUntil: "load" });
    await tab.waitForLoadState("load");
    check(new URL(tab.url()).pathname === own && await tab.evaluate(() => document.documentElement.lang) === code,
      `${where}: opens ${own} in ${code} (at ${new URL(tab.url()).pathname})`);
    const said = await tab.evaluate(() => ({
      name: document.querySelector("h1")?.textContent.trim() || "",
      title: document.title,
      crumbs: [...document.querySelectorAll(".crumbs a")].map((a) => [a.textContent.trim(), new URL(a.href).pathname]),
      alternates: Object.fromEntries([...document.querySelectorAll('link[rel="alternate"][hreflang]')]
        .map((link) => [link.hreflang, new URL(link.href).pathname])),
      canonical: new URL(document.querySelector('link[rel="canonical"]')?.href || location.href).pathname,
      url: new URL(document.querySelector('meta[property="og:url"]')?.content || location.href).pathname,
      tabs: [...document.querySelectorAll("#page-tabs a")].map((a) => a.firstChild.textContent.trim()),
      actions: [...document.querySelectorAll(".side .actions a")].map((a) => a.textContent.trim()),
      heads: [...document.querySelectorAll(".rest section > h2")].map((h) => h.textContent.trim()),
    }));
    check(said.title === script(code, "{name} — a Brickworks model", { name: said.name }), `${where}: its title says "${said.title}"`);
    const want = { en: at, de: `/de${at}`, fr: `/fr${at}`, es: `/es${at}`, "x-default": at };
    check(JSON.stringify(said.alternates) === JSON.stringify(want) && said.canonical === own && said.url === own,
      `${where}: ${Object.keys(said.alternates).length} alternates, canonical and og:url ${said.canonical}`);
    const lang = code === "en" ? "" : `/${code}`;
    check(said.crumbs[0]?.[0] === script(code, "Gallery") && said.crumbs[0]?.[1] === `${lang}/gallery`,
      `${where}: its crumbs, ${said.crumbs.map(([text, to]) => `"${text}" ${to}`).join(", ")}`);
    const tabs = ["About", "Parts", "Comments", "Builds", "Remixes"].map((word) => script(code, word));
    const actions = ["Build it", "Open in Brickworks", "Download"].map((word) => script(code, word));
    check(tabs.every((word) => said.tabs.includes(word)) && actions.every((word) => said.actions.includes(word)),
      `${where}: its tabs ${said.tabs.join(" / ")}; ${said.actions.map((text) => `"${text}"`).join(", ")}`);
    // The comments drawn by its script: the Reply under each and a step's
    // pill in the language, each date as the language writes it.
    await tab.locator("#comments").scrollIntoViewIfNeeded();
    await tab.waitForFunction(() => !document.getElementById("comments")?.hidden
      && document.querySelector("#comments .comment-list li"), null, { timeout: 30000 });
    const chrome = await tab.evaluate(() => ({
      reply: document.querySelector("#comments button[data-reply]")?.textContent.trim() || "",
      none: document.querySelector("#comments .comment-list li.none")?.textContent.trim() || "",
      step: document.querySelector("#comments .pill.step")?.textContent.trim() || "",
      send: document.querySelector("#comments form.comment-new button[type=submit]")?.textContent.trim() || "",
      dates: [...document.querySelectorAll("time[datetime]")].map((time) => [time.dateTime, time.textContent.trim()]),
    }));
    const stepWord = script(code, "Step {n}", { n: "" }).trim();
    // A model nobody has commented on says so; one with comments, Reply
    // under each, and its step's pill where one is on a step.
    check((chrome.none ? chrome.none === script(code, "Nobody has commented yet.")
      : chrome.reply === script(code, "Reply") && (!chrome.step || chrome.step.startsWith(stepWord)))
      && chrome.send === script(code, "Sign in and add it"),
      `${where}: the comments say ${[chrome.none, chrome.reply, chrome.step, chrome.send].filter(Boolean).map((text) => `"${text}"`).join(", ")}`);
    const day = new Intl.DateTimeFormat(code === "en" ? "en-GB" : code, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
    const wrongDates = chrome.dates.filter(([iso, text]) => !text.startsWith(day.format(new Date(iso))));
    check(chrome.dates.length >= 1 && !wrongDates.length, `${where}: ${chrome.dates.length} dates as ${code} writes them`
      + `${wrongDates.length ? `, ${wrongDates.length} not: "${wrongDates[0][1]}"` : `, "${chrome.dates[0]?.[1]}"`}`);
    // Its parts list's names as the app says them in the language.
    await lotsSaid(tab, code, where, false);
    // The header's Sign in, once web/follow.js has said who is here.
    await tab.waitForFunction(() => document.querySelector(".site-head a[data-account]")?.textContent.trim(), null, { timeout: 15000 });
    const signIn = (await tab.locator(".site-head .nav a[data-account]").textContent()).trim();
    check(signIn === script(code, "Sign in"), `${where}: the header's Sign in says "${signIn}"`);
    check(await tab.evaluate(markShown), `${where}: the header shows the Brickworks wordmark`);
    // No English left but what its builder wrote, and the names in it.
    if (code !== "en") {
      const names = await tab.evaluate((theirs) => [...document.querySelectorAll(theirs)].map((el) => el.textContent.trim())
        .filter(Boolean).sort((a, b) => b.length - a.length), THEIRS);
      // Its description cut short for a link's preview (its meta), its
      // paragraphs run together, is theirs too.
      const flat = (text) => text.replace(/\s+/g, " ").trim();
      const cutFrom = (text) => text.endsWith("…") && names.some((name) => flat(name).startsWith(flat(text.slice(0, -1))));
      const left = (await tab.evaluate(readable, THEIRS)).filter((text) => !cutFrom(text))
        .map((text) => names.reduce((rest, name) => rest.split(name).join(" "), text).replace(NAMES, " ")).filter((text) => ENGLISH.test(text));
      check(!left.length, `${where}: no English left${left.length ? `: ${left.length}, first "${left[0].slice(0, 120)}"` : ""}`);
    }
    const cuts = await tab.evaluate(cut);
    if (code === "en") cutInEnglish.set(`model ${width}`, new Set(cuts));
    else {
      const english = cutInEnglish.get(`model ${width}`) || new Set();
      const short = cuts.filter((text) => !english.has(text));
      check(!short.length, `${where}: nothing cut short${short.length ? `: ${short.length}, "${short.slice(0, 3).join('", "')}"` : ""}`);
    }
    const apps = await tab.evaluate(() => [...document.querySelectorAll("a[href]")].map((a) => new URL(a.href))
      .filter((url) => url.pathname === "/app").map((url) => url.searchParams.get("lang")));
    const wrong = apps.filter((asked) => asked !== (code === "en" ? null : code));
    check(apps.length >= 2 && !wrong.length, `${where}: ${apps.length} links into the app${code === "en" ? " ask no language" : ` say lang=${code}`}${wrong.length ? `, ${wrong.length} not: ${wrong[0]}` : ""}`);
    const shown = await tab.locator(".site-foot select[data-lang-choice]").inputValue();
    check(shown === code, `${where}: the footer's Language shows ${shown}`);
    if (out) {
      await tab.addStyleTag({ content: ".defer { content-visibility: visible !important; }" });
      await tab.screenshot({ path: path.join(out, `${code}-model-${width}.png`), fullPage: true });
    }
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// The gallery's copy in [code]: a model's card opens the model's page in
/// the language.
async function galleryToModel(browser, code, width) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} gallery to a model ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    await tab.goto(`${base}${lang}/gallery`, { waitUntil: "load" });
    await tab.waitForFunction(() => document.documentElement.dataset.gallery === "ready", null, { timeout: 30000 });
    const card = tab.locator("article.model a.open[href*='/m/']").first();
    const href = await card.getAttribute("href");
    await Promise.all([tab.waitForURL((url) => /\/m\/[A-Za-z0-9]{10}$/.test(url.pathname), { timeout: 30000 }), card.click()]);
    const landed = new URL(tab.url()).pathname;
    check(href.startsWith(`${lang}/m/`) && landed === href && await tab.evaluate(() => document.documentElement.lang) === code,
      `${where}: a card links to ${href} and opens ${landed} in ${code}`);
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// The sitemaps: the index names the sets' pages in English and in each
/// language, and each language's first file lists its copies, as many as
/// the English one lists; and the models' copies, one file a language
/// listing a copy of each model /sitemap.xml lists.
async function sitemaps(browser) {
  const context = await newContext(browser, "en", 1280);
  const tab = await context.newPage();
  try {
    await tab.goto(`${base}/`, { waitUntil: "load" });
    const said = await tab.evaluate(async () => {
      const text = (at) => fetch(at).then((reply) => (reply.ok ? reply.text() : `${reply.status}`));
      const locs = (xml) => [...xml.matchAll(/<loc>([^<]*)<\/loc>/g)].map((found) => new URL(found[1]).pathname);
      const index = locs(await text("/sitemaps/index.xml"));
      const files = {};
      for (const code of ["en", "de", "fr", "es"]) {
        files[code] = locs(await text(`/sitemaps/sets-${code === "en" ? "" : `${code}-`}1.xml`));
      }
      const models = {};
      for (const code of ["en", "de", "fr", "es"]) {
        models[code] = locs(await text(code === "en" ? "/sitemap.xml" : `/sitemaps/models-${code}.xml`));
      }
      return { index, files, models, other: await text("/sitemaps/sets-xx-1.xml") };
    });
    const english = said.files.en;
    check(english.length > 1000 && english.every((at) => at.startsWith("/library/set/")),
      `the English sets' sitemap lists ${english.length} pages`);
    for (const code of ["de", "fr", "es"]) {
      const listed = said.files[code];
      check(said.index.includes(`/sitemaps/sets-${code}-1.xml`) && listed.length === english.length
        && listed.every((at, n) => at === `/${code}${english[n]}`),
        `the index names /sitemaps/sets-${code}-1.xml, ${listed.length} pages, each /${code}${english[0] || ""}...`);
    }
    const models = said.models.en.filter((at) => /^\/m\/[A-Za-z0-9]{10}$/.test(at));
    for (const code of ["de", "fr", "es"]) {
      const listed = said.models[code];
      check(models.length >= 1 && said.index.includes(`/sitemaps/models-${code}.xml`) && listed.length === models.length
        && listed.every((at, n) => at === `/${code}${models[n]}`),
        `the index names /sitemaps/models-${code}.xml, ${listed.length} of ${models.length} models, each /${code}${models[0] || ""}...`);
    }
  } catch (trouble) {
    check(false, `sitemaps: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
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
    const words = (value) => (typeof value === "function" ? value(code) : plain(page(code, value)));
    check(title === words(one.title), `${where}: its title says "${title}"`);
    if (one.heading) {
      const heading = (await tab.locator(one.heading).first().innerText()).replace(/\s+/g, " ").trim();
      check(heading === words(one.says), `${where}: its heading says "${heading}"`);
    }
    if (one.set) await setSaid(tab, code, one, where);
    if (one.ready) {
      // Its list drawn, and counted in the language: "24 Modelle", "1.234 Sets".
      await tab.waitForFunction((name) => ["ready", "broken"].includes(document.documentElement.dataset[name]), one.ready,
        { timeout: 30000 });
      const counted = (await tab.locator(one.count).innerText()).trim();
      const nouns = one.noun.map((noun) => script(code, noun));
      check(await tab.evaluate((name) => document.documentElement.dataset[name], one.ready) === "ready"
        && nouns.some((noun) => counted.includes(noun)), `${where}: its list drawn and counted, "${counted}"`);
    }
    if (one.name === "library") {
      // Each theme the language words its own way said so (Sammelminifiguren),
      // the rest, product lines' and licences' names, as they are, LEGO®
      // marked as the app draws it (LEGO® Exclusive).
      const pills = await tab.evaluate(() => [...document.querySelectorAll("#themes [data-pick]")]
        .filter((pill) => pill.dataset.pick).map((pill) => [pill.dataset.pick, pill.textContent.trim()]));
      const want = (name) => THEMES[code]?.[marked(name)] ?? marked(name);
      const worded = pills.filter(([name]) => THEMES[code]?.[marked(name)]);
      const wrong = pills.filter(([name, said]) => said !== want(name));
      check(pills.length > 20 && (code === "en" || worded.length > 10) && !wrong.length, `${where}: ${worded.length} of its `
        + `${pills.length} themes in the language, the rest as they are${wrong.length
          ? `, ${wrong.length} not: ${wrong.slice(0, 3).map(([name, said]) => `"${said}" for ${name}`).join(", ")}`
          : worded.length ? `, "${worded[0][1]}"` : ""}`);
    }
    // The header's Sign in, once web/follow.js has said who is here.
    await tab.waitForFunction(() => document.querySelector(".site-head a[data-account]")?.textContent.trim(), null, { timeout: 15000 });
    const signIn = await tab.locator(".site-head .nav a[data-account]").textContent();
    check(signIn.trim() === script(code, "Sign in"), `${where}: the header's Sign in says "${signIn.trim()}"`);
    check(await tab.evaluate(markShown), `${where}: the header shows the Brickworks wordmark`);
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

/// A set's page in [code]: its crumbs, facts, actions and parts list in
/// the language, the theme as the app words it, the alternates and its own
/// canonical.
async function setSaid(tab, code, one, where) {
  const at = code === "en" ? "" : `/${code}`;
  const own = `${at}${one.path}`;
  const said = await tab.evaluate(() => ({
    crumbs: [...document.querySelectorAll(".crumbs a")].map((a) => [a.textContent.trim(), new URL(a.href).pathname]),
    alternates: Object.fromEntries([...document.querySelectorAll('link[rel="alternate"][hreflang]')]
      .map((link) => [link.hreflang, new URL(link.href).pathname])),
    canonical: new URL(document.querySelector('link[rel="canonical"]').href).pathname,
    url: new URL(document.querySelector('meta[property="og:url"]').content).pathname,
    parts: document.querySelector(".facts [data-parts]")?.textContent.trim() || "",
    actions: [...document.querySelectorAll(".side .actions a")].map((a) => a.textContent.trim()),
    tabs: [...document.querySelectorAll(".parts-bar [data-group]")].map((button) => button.textContent.trim()),
  }));
  const theme = code === "en" ? one.set.theme : THEMES[code][one.set.theme];
  check(said.crumbs[0]?.[0] === script(code, "Library") && said.crumbs[0]?.[1] === `${at}/library`
    && said.crumbs[1]?.[0] === theme, `${where}: its crumbs, ${said.crumbs.map(([text, to]) => `"${text}" ${to}`).join(", ")}`);
  const want = { en: one.path, de: `/de${one.path}`, fr: `/fr${one.path}`, es: `/es${one.path}`, "x-default": one.path };
  check(JSON.stringify(said.alternates) === JSON.stringify(want) && said.canonical === own && said.url === own,
    `${where}: ${Object.keys(said.alternates).length} alternates, canonical and og:url ${said.canonical}`);
  check(said.parts.endsWith(` ${script(code, "parts")}`) && said.actions.includes(script(code, "Open its parts in Brickworks"))
    && said.tabs.join("|") === [script(code, "Colour"), script(code, "Kind")].join("|"),
    `${where}: "${said.parts}", ${said.actions.map((text) => `"${text}"`).join(", ")}, ${said.tabs.join(" / ")}`);
  // The parts list drawn by its script, its heads in the language.
  await tab.waitForFunction(() => document.querySelector(".lot-list li.group .n"), null, { timeout: 30000 });
  const head = await tab.locator(".lot-list li.group .n").first().innerText();
  check(head.trim().endsWith(` ${script(code, "parts")}`) || head.trim().endsWith(` ${script(code, "part")}`),
    `${where}: the parts list's heads count in it, "${head.trim()}"`);
  await lotsSaid(tab, code, where);
}

/// First steps' every word a person reads or hears but people's and
/// models' names, and what overflows it.
function stepsSaid() {
  const dialog = document.querySelector("dialog.first-steps[open]");
  if (!dialog) return null;
  const SKIP = ".person-row .names, article.model .words, article.model .frame, .face, svg";
  const said = [];
  const walk = document.createTreeWalker(dialog, NodeFilter.SHOW_TEXT);
  for (let node = walk.nextNode(); node; node = walk.nextNode()) {
    if (node.parentElement.closest(SKIP) || !node.textContent.trim()) continue;
    said.push(node.textContent.trim());
  }
  for (const el of dialog.querySelectorAll("[aria-label], [placeholder], [title]")) {
    if (el.closest(SKIP)) continue;
    for (const name of ["aria-label", "placeholder", "title"]) if (el.getAttribute(name)) said.push(el.getAttribute(name));
  }
  const cut = [...dialog.querySelectorAll("button, label, h2, h3, p, a.cta")]
    .filter((el) => !el.closest(SKIP) && el.offsetWidth && el.scrollWidth > el.clientWidth + 1).map((el) => el.textContent.trim());
  return { lang: dialog.closest("[lang]")?.lang || "", step: dialog.dataset.step || "",
    count: dialog.querySelector(".eyebrow")?.textContent.trim() || "", title: dialog.querySelector("h2")?.textContent.trim() || "",
    said, cut, wide: dialog.getBoundingClientRect().right > innerWidth + 1 };
}

const STEPS = { profile: "Make your profile", kinds: "What do you build?", start: "Designers and models to start with" };

/// First steps in [code] at [width], on the [tab] it is open in: each
/// step's words, moving on by Skip, then Done.
async function stepping(tab, code, width, label) {
  const seen = [];
  for (let at = 0; at < 3; at += 1) {
    await tab.waitForFunction((was) => {
      const step = document.querySelector("dialog.first-steps[open]")?.dataset.step;
      return step && step !== was;
    }, seen.at(-1)?.step || "", { timeout: 20000 });
    await tab.waitForTimeout(300);
    const one = await tab.evaluate(stepsSaid);
    seen.push(one);
    // A label in English where the language has its own word (German's
    // Name is Name).
    const labels = ["Skip", "Next", "Follow", "Following", "Done", "Name", "Handle"].filter((word) => script(code, word) !== word);
    const left = code === "en" ? [] : one.said.map((text) => text.replace(NAMES, " ")).filter((text) => ENGLISH.test(text)
      || labels.includes(text));
    const all = Object.keys(STEPS).length;
    check(one.lang === code && one.title === script(code, STEPS[one.step]) && one.count.length > 0 && !left.length,
      `${label}: step ${at + 1} in ${one.lang}, "${one.count}", "${one.title}"${left.length ? `; English left: "${left[0].slice(0, 100)}"` : ""}`);
    check(!one.cut.length && !one.wide, `${label}: step ${at + 1} has nothing cut short${one.cut.length ? `: "${one.cut[0]}"` : ""}`);
    if (out) await tab.locator("dialog.first-steps").screenshot({ path: path.join(out, `${code}-firststeps-${one.step}-${width}.png`) });
    if (one.step === "start" || at + 1 === all) break;
    await tab.click("#first-skip");
  }
  check(seen.at(-1)?.step === "start", `${label}: ends on its designers and models (${seen.map((one) => one.step).join(", ")})`);
  await tab.click("#first-done");
  await tab.waitForFunction(() => !document.querySelector("dialog.first-steps"), null, { timeout: 10000 });
}

/// First steps opened over the gallery's copy as a first sign-in opens it.
async function firstSteps(browser, code, width) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const label = `${code} first steps ${width}`;
  try {
    await tab.goto(`${base}${code === "en" ? "" : `/${code}`}/gallery`, { waitUntil: "load" });
    await tab.waitForFunction(() => document.documentElement.dataset.gallery === "ready", null, { timeout: 30000 });
    await tab.evaluate(() => { import("/first-steps.js").then((steps) => steps.firstSteps()); });
    await stepping(tab, code, width, label);
  } catch (trouble) {
    check(false, `${label}: ${String(trouble.message || trouble).split("\n")[0]}`);
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

// The sign-in dialog (web/account.js), on a copy and on a page with none.
const ADDRESS = "delivered+brickworks-lang@resend.dev";
const TOO_MANY = "Too many codes asked for. Wait a few minutes and try again.";
const WRONG = "That code is wrong or has expired. Check it, or ask for a new one.";

/// The dialog's every word a person reads or hears, and what overflows it.
function dialogSaid() {
  const dialog = document.querySelector("dialog.sign-in[open]");
  if (!dialog) return null;
  const said = [];
  const walk = document.createTreeWalker(dialog, NodeFilter.SHOW_TEXT);
  for (let node = walk.nextNode(); node; node = walk.nextNode()) {
    if (node.parentElement.closest("[hidden], .visually-hidden") && !node.parentElement.closest("select")) continue;
    if (node.textContent.trim()) said.push(node.textContent.trim());
  }
  for (const el of dialog.querySelectorAll("[aria-label], [placeholder]")) {
    for (const name of ["aria-label", "placeholder"]) if (el.getAttribute(name)) said.push(el.getAttribute(name));
  }
  const cut = [...dialog.querySelectorAll("button, label, h2, p")].filter((el) => el.offsetWidth && el.scrollWidth > el.clientWidth + 1)
    .map((el) => el.textContent.trim());
  return { lang: dialog.closest("[lang]")?.lang || "", title: dialog.querySelector("h2")?.textContent.trim() || "",
    label: dialog.querySelector("label")?.firstChild?.textContent.trim() || "", go: dialog.querySelector('button[type="submit"]')?.textContent.trim() || "",
    note: dialog.querySelector(".said")?.textContent.trim() || "", said, cut,
    wide: dialog.scrollWidth > dialog.clientWidth + 1 || dialog.getBoundingClientRect().right > innerWidth + 1 };
}

/// Signing in, in [code] at [width], from [where]: Sign in on /profile, a
/// page still in English that the header's Sign in and the app's
/// orangecheck send people to, or a card's Like on the gallery's copy. The
/// dialog's words, the code asked for (the server's "too many" first), the
/// code's step, a wrong code's error, and on the stand-in the right code's
/// age question, all in the language. /api/otp is answered here as the
/// server answers, so no mail goes to anyone; on a deployment the wrong code
/// goes to its Supabase, which refuses it (from /profile only: eight verifies a run).
async function signingIn(browser, code, width, where) {
  const context = await newContext(browser, code, width, where === "profile" && !remote ? { fresh: { aged: false, profile: null, follows: new Set() } } : {});
  const tab = await context.newPage();
  const label = `${code} sign-in from ${where} ${width}`;
  let asked = 0;
  await tab.route("**/api/otp", (route) => {
    asked += 1;
    return route.fulfill({ status: asked === 1 ? 429 : 200, contentType: "application/json",
      body: JSON.stringify(asked === 1 ? { error: TOO_MANY } : { ok: true, expires_in_minutes: 10 }) });
  });
  const until = (test, what, arg) => tab.waitForFunction(test, arg, { timeout: 20000 }).catch(() => {
    throw new Error(`no ${what}`);
  });
  try {
    if (where === "profile") {
      await tab.goto(`${base}/profile`, { waitUntil: "load" });
      await tab.click("#sign-in");
    } else {
      await tab.goto(`${base}${code === "en" ? "" : `/${code}`}/gallery`, { waitUntil: "load" });
      await tab.waitForFunction(() => document.documentElement.dataset.gallery === "ready", null, { timeout: 30000 });
      await tab.locator("[data-like]").first().click();
    }
    await until(() => document.querySelector("dialog.sign-in[open]"), "dialog");
    // Its first face, whole, before anything is asked for.
    await tab.waitForTimeout(400);
    let seen = await tab.evaluate(dialogSaid);
    const left = code === "en" ? [] : seen.said.map((text) => text.replace(NAMES, " ")).filter((text) => ENGLISH.test(text) || /^(Email|Not now|Month|Year)$/.test(text));
    check(seen.lang === code && seen.title === script(code, "Sign in to Brickworks") && seen.go === script(code, "Email me a code")
      && seen.label === script(code, "Email") && !left.length,
      `${label}: in ${seen.lang}, "${seen.title}", "${seen.label}", "${seen.go}"${left.length ? `; English left: "${left[0].slice(0, 100)}"` : ""}`);
    check(!seen.cut.length && !seen.wide, `${label}: nothing cut short or wider than the window${seen.cut.length ? `: "${seen.cut[0]}"` : ""}`);
    if (out) await tab.locator("dialog.sign-in").screenshot({ path: path.join(out, `${code}-signin-${where}-${width}.png`) });
    // The code asked for: the server's "too many", then sent.
    await tab.fill("dialog.sign-in input", ADDRESS);
    await tab.click('dialog.sign-in button[type="submit"]');
    await until(() => document.querySelector("dialog.sign-in .said")?.textContent.trim(), "answer to the first ask");
    seen = await tab.evaluate(dialogSaid);
    check(seen.note === script(code, TOO_MANY), `${label}: the server's "too many" says "${seen.note}"`);
    await tab.click('dialog.sign-in button[type="submit"]');
    const sent = script(code, "The code sent to {address}", { address: ADDRESS });
    await until((want) => document.querySelector("dialog.sign-in label")?.firstChild?.textContent.trim() === want, "code's step", sent);
    seen = await tab.evaluate(dialogSaid);
    check(seen.go === script(code, "Sign in"), `${label}: the code's step, "${seen.label}", "${seen.go}"`);
    if (remote && where !== "profile") return;
    // A wrong code, refused in the language.
    await tab.fill("dialog.sign-in input", "000000");
    await tab.click('dialog.sign-in button[type="submit"]');
    await until(() => document.querySelector("dialog.sign-in .said")?.textContent.trim(), "answer to the wrong code");
    seen = await tab.evaluate(dialogSaid);
    check(seen.note === script(code, WRONG), `${label}: a wrong code says "${seen.note}"`);
    if (out) await tab.locator("dialog.sign-in").screenshot({ path: path.join(out, `${code}-signin-${where}-${width}-wrong.png`) });
    if (remote || where !== "profile") return;
    // The right one, and the age question a new account is asked.
    await tab.fill("dialog.sign-in input", "123456");
    await tab.click('dialog.sign-in button[type="submit"]');
    await until(() => document.querySelector("dialog.age[open]"), "age question");
    const age = await tab.evaluate(() => {
      const dialog = document.querySelector("dialog.age[open]");
      return { lang: dialog.closest("[lang]")?.lang || "", title: dialog.querySelector("h2").textContent.trim(),
        months: [...document.querySelectorAll("#age-month option")].map((one) => one.textContent.trim()),
        go: document.getElementById("age-go").textContent.trim() };
    });
    const january = new Intl.DateTimeFormat(code === "en" ? "en-US" : code, { month: "long", timeZone: "UTC" }).format(Date.UTC(2000, 0, 1));
    check(age.lang === code && age.title === script(code, "One question first") && age.months[0] === script(code, "Month")
      && age.months[1] === january && age.go === script(code, "Carry on"),
      `${label}: the age question, "${age.title}", ${age.months.slice(0, 2).join(", ")}, "${age.go}"`);
    if (out) await tab.locator("dialog.age").screenshot({ path: path.join(out, `${code}-age-${width}.png`) });
    // Thirteen or over: First steps, in the language too.
    await tab.selectOption("#age-month", { index: 1 });
    await tab.selectOption("#age-year", "1990");
    await tab.click("#age-go");
    await stepping(tab, code, width, `${label}, then first steps`);
  } catch (trouble) {
    check(false, `${label}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
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
  if (!only || only.includes("model")) {
    // The stand-in's watchtower, or a deployment's first listed model.
    let at = `/m/${stand.MODEL_ID}`;
    if (remote) {
      const listed = await (await fetch(`${remote}/api/share?op=list&page=1`, { headers })).json().catch(() => ({}));
      at = listed.models?.[0] ? `/m/${listed.models[0].id}` : "";
    }
    for (const code of langs.includes("en") ? langs : ["en", ...langs]) {
      for (const width of widths) {
        if (at) await modelSaid(browser, code, width, at);
        else check(false, "a model to open: the deployment lists none");
        await galleryToModel(browser, code, width);
      }
    }
  }
  if (!only || only.includes("sitemaps")) await sitemaps(browser);
  await choosing(browser);
  if (!only || only.includes("signin")) {
    for (const code of langs) {
      for (const width of widths) {
        for (const where of ["profile", "gallery"]) await signingIn(browser, code, width, where);
      }
    }
  }
  if (!only || only.includes("firststeps")) {
    for (const code of langs) {
      for (const width of widths) await firstSteps(browser, code, width);
    }
  }
  if (app) await loader(browser);
  else console.log("  --    the app's loading page: --app=<a deployment's /app, or a web export's index.html>");
} finally {
  await browser.close();
}
console.log(`\nsite language flow: ${passed} checks passed, ${failed} failed`);
process.exit(failed || !passed ? 1 : 0);
