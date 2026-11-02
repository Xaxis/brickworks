// Does a visitor read the site in their own language? (tools/site_lang.py,
// web/theme.js, src/boot/shell.html)
//
//   node tools/web/site_lang_flow.mjs [--out=DIR]               this checkout's web/, served here
//   node tools/web/site_lang_flow.mjs --url=<deployment>        a deployment's pages, as they are
//   ... --app=<address>  the app's loading page too: a deployment's /app, or a web
//                        export's index.html (node tools/web/relay_server.mjs PORT
//                        --static=build/web; --app=http://127.0.0.1:PORT/index.html)
//   [--widths=1280,390]  [--langs=en,de,fr,es]
//   [--pages=home,download,plans,faq,compare,gallery,library,set,model,sitemaps,signin,firststeps,
//            profile,ldraw,embed,viewer,server,challenge,collections,account,
//            feed,notifications,builds,feedback,beta,beta-hub,terms,privacy,guidelines,takedown,
//            changelog,missing,consent]
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
// width: from Sign in on /profile, where the header's Sign in and the
// app's orangecheck send people, and from Like on the
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
// And where a model's copy leads (2026-11-01, languages5), each in the
// language at each width, no English left but what people wrote:
//   profile  its designer's page, /u/<handle> opened as /de/u/<handle>: its
//            title, alternates, canonical, Edit profile and its tabs, every
//            model it links to in the language;
//   ldraw    a set of the LDraw library, /library/<id> as /de/library/<id>;
//   embed    the copy's embed code, its frame named in the language and
//            opening /de/m/<id>/embed, and that page in the language;
//   viewer   the 3D view over the copy's picture: its tools, its label and
//            its status, and where the model cannot come, why, and Try again;
//   server   what the server tells a visitor, said in the language: why
//            they may not comment or follow (why_not), a challenge's rules
//            and what a model breaks of them, and the app's reasons a model
//            is not Tested, each part and colour in them named as the parts
//            list names it, and in German a capital after a colon. The
//            owner's sign-in is planted in the browser and every answer it
//            would bring is made there, so nothing of it reaches a
//            deployment; any other call goes out signed out.
//
// And the last pages the site links to (2026-11-02, languages6), each in
// the language at each width, no English left but what people wrote:
//   challenge    /challenge, its rules, days, Coming next and Past
//                challenges, and why an account under 13 may not vote
//                (planted, as server's are); and /challenge?id=N's head:
//                its title and words, canonical /de/challenge?id=N and the
//                alternates;
//   collections  /collections and a collection's /c/<id>: titles, tabs,
//                alternates and every card and link in the language;
//   account      your own /profile, each of its tabs and Edit profile, and
//                /settings: the deployment's pages, signed in only in the
//                browser, every call they make (its Supabase's too)
//                answered here by the stand-in.
//
// And the last English pages the site linked to (2026-11-02, languages7),
// each in the language at each width, no English left but what people
// wrote and the release notes:
//   feed, notifications, beta, beta-hub, feedback, consent
//                the account menu's pages and the connector's consent page
//                (/oauth/authorize, asking to let Claude build), signed in
//                only in the browser as account's are, every call answered
//                here; the feed's and the notifications' lines said whole
//                by the server in the language; the beta's form's refusal,
//                the feedback dialog, and the beta hub's cards as we wrote
//                them (lang="en");
//   builds       every photo of a real build, signed out;
//   terms, privacy, guidelines, takedown
//                the rules, each copy opening with one line that the English
//                text binds, whose link opens it in English and keeps it so;
//   changelog    its heads, dates and links in the language, the notes as
//                written, lang="en";
//   missing      an address with nothing at it, /de/<it> after the
//                browser's language, answered 404 in it.
// The docs alone stay English: choosing above opens them.
//
// With no --url nothing leaves this machine: the pages are served by
// design_stand_in.mjs from this checkout's web/. Pictures with --out:
// <code>-<page>-<width>.png, the whole page; the pages languages5 reads,
// a screen at a time as a reader scrolls them (<code>-<page>-<width>-1.png),
// since a whole phone page repeats itself past about 16,000 px.
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
function readable(asked = "") {
  // What else to skip, and the part of the page to read ({more, root}).
  const { more = "", root = "" } = typeof asked === "string" ? { more: asked } : asked;
  const SKIP = "script, style, code, kbd, template, svg, [translate='no'], article.model .words, article.model .frame, "
    + `.lot-list .name, .lot-list .meta, .lot-list .group > span:not(.n)${more ? `, ${more}` : ""}`;
  const said = [];
  const top = root ? document.querySelector(root) : document.documentElement;
  if (!top) return said;
  const walk = document.createTreeWalker(top, NodeFilter.SHOW_TEXT);
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
  for (const el of [top, ...top.querySelectorAll("[alt], [title], [aria-label], [placeholder]")]) {
    if (el.closest(SKIP)) continue;
    for (const name of ["alt", "title", "aria-label", "placeholder"]) {
      if (el.hasAttribute(name) && el.getAttribute(name).trim()) said.push(el.getAttribute(name));
    }
  }
  if (root) return said;
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
    await tab.goto(`${base}/docs`, { waitUntil: "load" });
    const shown = await tab.locator(".site-foot select[data-lang-choice]").inputValue();
    const into = await tab.evaluate(() => [...document.querySelectorAll('a[href^="/app"]')].map((a) => new URL(a.href).searchParams.get("lang")));
    check(new URL(tab.url()).pathname === "/docs" && shown === "de" && into.length >= 1 && into.every((lang) => lang === "de"),
      `and the docs, still in English, show Deutsch chosen (${shown}) and open the app in it (${into.length} links)`);
  } catch (trouble) {
    check(false, `choosing: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
  // A page with no copy (the docs, since languages7) still carries the
  // browser's language into the app.
  const french = await newContext(browser, "fr", 1280);
  const changes = await french.newPage();
  try {
    await changes.goto(`${base}/docs`, { waitUntil: "load" });
    const langs = await changes.evaluate(() => [...document.querySelectorAll('a[href^="/app"]')].map((a) => new URL(a.href).searchParams.get("lang")));
    check(new URL(changes.url()).pathname === "/docs" && langs.length >= 1 && langs.every((lang) => lang === "fr"),
      `the docs, in English, send a French browser into a French app (${langs.length} links)`);
  } catch (trouble) {
    check(false, `docs: ${String(trouble.message || trouble).split("\n")[0]}`);
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

// Where a model's copy leads (languages5). What a person wrote on their
// profile, and the names it says: as they wrote them. A set of the LDraw
// library: its name as LEGO® publishes it, and who modelled it. The embed:
// the model's name.
const THEIRS_PROFILE = ".who h1, .bio, .links, .start-with a, .follows .pills a, .won, [data-award='won'], .people-list .name";
const THEIRS_SET = "h1, .modelled-by b, .shared-by .names, .tags";
const THEIRS_EMBED = ".embed-bar b";

/// The page as a reader scrolls it, a screen at a time, as
/// <name>-1.png...: a whole-page shot of a phone repeats itself past about
/// 16,000 px.
async function screens(tab, name, most = 4) {
  if (!out) return;
  await tab.addStyleTag({ content: ".defer { content-visibility: visible !important; }" });
  const tall = await tab.evaluate(() => document.documentElement.scrollHeight);
  const high = tab.viewportSize().height;
  for (let at = 0, n = 1; at < tall && n <= most; at += high, n += 1) {
    await tab.evaluate((y) => window.scrollTo(0, y), at);
    await tab.waitForTimeout(200);
    // SwiftShader now and then fails a capture while a page's first
    // pictures decode ("Unable to capture screenshot"): a picture, not
    // the page, so it is asked again once.
    const shot = { path: path.join(out, `${name}-${n}.png`) };
    await tab.screenshot(shot).catch(() => tab.waitForTimeout(1000).then(() => tab.screenshot(shot)));
  }
  await tab.evaluate(() => window.scrollTo(0, 0));
}

/// The English left on [tab]'s page, or in [root] of it, but what [theirs]
/// picks and the names it says wherever they are said.
async function englishIn(tab, theirs, root = "") {
  const names = await tab.evaluate((theirs) => [...document.querySelectorAll(theirs)].map((el) => el.textContent.trim())
    .filter(Boolean).sort((a, b) => b.length - a.length), theirs);
  // A page's description that is the start of what they wrote (a bio
  // longer than 160, api/people.js) is theirs too.
  const flat = names.map((name) => name.replace(/\s+/g, " "));
  const started = (text) => {
    const start = text.replace(/\s+/g, " ").replace(/…$/, "").trim();
    return start.length >= 20 && flat.some((name) => name.startsWith(start));
  };
  return (await tab.evaluate(readable, { more: theirs, root }))
    .filter((text) => !started(text))
    .map((text) => names.reduce((rest, name) => rest.split(name).join(" "), text).replace(NAMES, " "))
    .filter((text) => ENGLISH.test(text));
}

/// A server-made page of a model's copy in [code], opened at its English
/// address [at] by a browser asking for the language: on its copy, with the
/// five alternates and its own canonical; and its words, title and links.
async function copyOpened(tab, code, at, where) {
  const own = code === "en" ? at : `/${code}${at}`;
  await tab.goto(`${base}${at}`, { waitUntil: "load" });
  await tab.waitForLoadState("load");
  const said = await tab.evaluate(() => ({
    path: location.pathname,
    lang: document.documentElement.lang,
    title: document.title,
    name: document.querySelector("main h1")?.textContent.trim() || "",
    alternates: Object.fromEntries([...document.querySelectorAll('link[rel="alternate"][hreflang]')]
      .map((link) => [link.hreflang, new URL(link.href).pathname])),
    canonical: new URL(document.querySelector('link[rel="canonical"]')?.href || location.href).pathname,
  }));
  check(said.path === own && said.lang === code, `${where}: opens ${own} in ${code} (at ${said.path}, lang ${said.lang})`);
  const want = { en: at, de: `/de${at}`, fr: `/fr${at}`, es: `/es${at}`, "x-default": at };
  check(JSON.stringify(said.alternates) === JSON.stringify(want) && said.canonical === own,
    `${where}: ${Object.keys(said.alternates).length} alternates, canonical ${said.canonical}`);
  return said;
}

/// Where on [tab]'s page [text] is said: its element and the two round it.
async function whereSaid(tab, text) {
  return tab.evaluate((text) => {
    const named = (el) => `${el.localName}${el.id ? `#${el.id}` : ""}${[...el.classList].map((one) => `.${one}`).join("")}`;
    const walk = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
    let el = null;
    for (let node = walk.nextNode(); node && !el; node = walk.nextNode()) {
      if (node.textContent.includes(text) && !node.parentElement.closest("script, style, template")) el = node.parentElement;
    }
    el ||= [...document.querySelectorAll("*")].find((one) => [...one.attributes].some((at) => at.value.includes(text)));
    const chain = [];
    for (; el && chain.length < 3; el = el.parentElement) chain.unshift(named(el));
    return chain.join(" > ") || "?";
  }, text.slice(0, 40));
}

/// No English but [theirs], nothing cut short that English shows whole,
/// the footer's Language (where the page has the site's [footer]), and the
/// pictures: the end of each page's check.
async function copyRead(tab, code, width, where, kind, theirs, footer = true) {
  if (code !== "en") {
    const left = await englishIn(tab, theirs);
    check(!left.length, `${where}: no English left${left.length
      ? `: ${left.length}, first "${left[0].slice(0, 120)}" in ${await whereSaid(tab, left[0].trim())}` : ""}`);
  }
  const cuts = await tab.evaluate(cut);
  if (code === "en") cutInEnglish.set(`${kind} ${width}`, new Set(cuts));
  else {
    const english = cutInEnglish.get(`${kind} ${width}`) || new Set();
    const short = cuts.filter((text) => !english.has(text));
    check(!short.length, `${where}: nothing cut short${short.length ? `: ${short.length}, "${short.slice(0, 3).join('", "')}"` : ""}`);
  }
  if (footer) {
    const shown = await tab.locator(".site-foot select[data-lang-choice]").inputValue().catch(() => "");
    check(shown === code, `${where}: the footer's Language shows ${shown}`);
  }
  await screens(tab, `${code}-${kind}-${width}`);
}

/// A designer's profile in [code], from /u/[handle]: its words, and every
/// model it links to opening the model's copy.
async function profileSaid(browser, code, width, handle) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} profile ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    const said = await copyOpened(tab, code, `/u/${handle}`, where);
    const titles = ["{name} (@{handle}) — a designer in Brickworks", "{name} (@{handle}) — models built in Brickworks"]
      .map((english) => script(code, english, { name: said.name, handle }));
    check(titles.includes(said.title), `${where}: its title says "${said.title}"`);
    const chrome = await tab.evaluate(() => ({
      edit: document.querySelector(".profile-head [data-edit-own]")?.textContent.trim() || "",
      tabs: [...document.querySelectorAll("nav.tabs a")].map((a) => a.firstChild.textContent.trim()),
      models: [...document.querySelectorAll("main a[href]")].map((a) => new URL(a.href, location.href))
        .filter((url) => url.origin === location.origin && /^(?:\/[a-z]{2})?\/m\/[A-Za-z0-9]{10}$/.test(url.pathname))
        .map((url) => url.pathname),
    }));
    const tabs = ["Models", "Builds", "Collections", "Likes"].map((word) => script(code, word));
    check(chrome.edit === script(code, "Edit profile") && chrome.tabs.length && chrome.tabs.every((word) => tabs.includes(word)),
      `${where}: "${chrome.edit}", its tabs ${chrome.tabs.join(" / ")}`);
    const wrong = chrome.models.filter((at) => !at.startsWith(`${lang}/m/`));
    check(chrome.models.length && !wrong.length, `${where}: ${chrome.models.length} links to its models open them in ${code}`
      + `${wrong.length ? `, ${wrong.length} not: ${wrong[0]}` : ""}`);
    await copyRead(tab, code, width, where, "profile", THEIRS_PROFILE);
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// A set of the LDraw library in [code], from /library/[id]: its crumbs,
/// its tabs and its links to the set's own page, in the language.
async function ldrawSaid(browser, code, width, id) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} LDraw set ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    await copyOpened(tab, code, `/library/${id}`, where);
    const chrome = await tab.evaluate(() => ({
      crumbs: [...document.querySelectorAll(".crumbs a")].map((a) => [a.textContent.trim(), new URL(a.href).pathname]),
      tabs: [...document.querySelectorAll("#page-tabs a")].map((a) => a.firstChild.textContent.trim()),
      sets: [...document.querySelectorAll("main a[href*='/library/set/']")].map((a) => new URL(a.href).pathname),
    }));
    check(chrome.crumbs[0]?.[1] === `${lang}/library` && chrome.sets.length && chrome.sets.every((at) => at.startsWith(`${lang}/library/set/`)),
      `${where}: its crumbs ${chrome.crumbs.map(([text, to]) => `"${text}" ${to}`).join(", ")}; ${chrome.sets.length} links to the set's page`);
    const tabs = ["About", "Parts"].map((word) => script(code, word));
    check(tabs.every((word) => chrome.tabs.includes(word)), `${where}: its tabs ${chrome.tabs.join(" / ")}`);
    await copyRead(tab, code, width, where, "ldraw", THEIRS_SET);
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// The embed code on the model's copy in [code]: its frame named in the
/// language and opening the copy's embed, and that page in the language.
async function embedSaid(browser, code, width, at) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} embed ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    await tab.goto(`${base}${lang}${at}`, { waitUntil: "load" });
    // Its designer, More by and the rest: each profile's copy.
    const people = await tab.evaluate(() => [...document.querySelectorAll("a[href]")].map((a) => new URL(a.href))
      .filter((url) => url.origin === location.origin && /^(?:\/[a-z]{2})?\/u\//.test(url.pathname)).map((url) => url.pathname));
    const away = people.filter((to) => !to.startsWith(`${lang}/u/`));
    check(people.length && !away.length, `${where}: the copy's ${people.length} links to a profile open it in ${code}`
      + `${away.length ? `, ${away.length} not: ${away[0]}` : ""}`);
    const snippet = await tab.evaluate(() => document.getElementById("share-embed")?.value || "");
    const src = /src="([^"]+)"/.exec(snippet)?.[1] || "";
    const title = /title="([^"]+)"/.exec(snippet)?.[1] || "";
    check(src && new URL(src).pathname === `${lang}${at}/embed` && title === script(code, "A Brickworks model"),
      `${where}: the embed code opens ${src ? new URL(src).pathname : "nothing"}, its frame named "${title}"`);
    // The frame's page, from here: the code names this deployment.
    const frame = src ? `${base}${new URL(src).pathname}` : `${base}${lang}${at}/embed`;
    const reply = await tab.goto(frame, { waitUntil: "load" });
    const said = await tab.evaluate(() => ({
      lang: document.documentElement.lang,
      opens: [...document.querySelectorAll(".embed-bar a.words[href]")].map((a) => new URL(a.href).pathname),
      app: [...document.querySelectorAll(".embed a.picture[href], .embed-bar a.cta[href]")].map((a) => new URL(a.href)),
      view: document.querySelector(".embed a.picture .go")?.textContent.trim() || "",
    }));
    check(reply?.status() === 200 && said.lang === code && said.opens.length && said.opens.every((to) => to === `${lang}${at}`)
      && said.view === script(code, "View in 3D") && said.app.length === 2
      && said.app.every((to) => (code === "en" ? !to.searchParams.has("lang") : to.searchParams.get("lang") === code)),
      `${where}: ${new URL(frame).pathname} answers ${reply?.status()} in ${said.lang}, "${said.view}", opening ${said.opens[0] || "nothing"}`
      + ` and the app at ${said.app.map((to) => to.search).join(", ")}`);
    if (code !== "en") {
      const left = await englishIn(tab, THEIRS_EMBED);
      check(!left.length, `${where}: no English left in the frame${left.length ? `: ${left.length}, first "${left[0].slice(0, 120)}"` : ""}`);
    }
    await screens(tab, `${code}-embed-${width}`, 1);
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// The 3D view over the copy's picture in [code]: its tools, its label and
/// what it says; and where its model cannot come, why, and Try again.
async function viewerSaid(browser, code, width, at) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} 3D view ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  const picture = "main a.picture[data-scene]";
  const settled = () => tab.waitForFunction(() => /^(ready|big|failed)$/.test(document.querySelector(".view3d")?.dataset.state || ""),
    null, { timeout: 90000 });
  try {
    await tab.goto(`${base}${lang}${at}`, { waitUntil: "load" });
    await tab.locator(picture).click();
    await settled();
    if (await tab.evaluate(() => document.querySelector(".view3d").dataset.state) === "big") {
      // A deployment's model may be past what this device turns smoothly.
      const big = await tab.evaluate(() => [...document.querySelectorAll(".view3d-said button")].map((b) => b.textContent.trim()));
      check(big.includes(script(code, "Turn it anyway")), `${where}: a big model asks "${big.join('", "')}"`);
      await tab.locator(".view3d-said button.ghost").click();
      await settled();
    }
    const said = await tab.evaluate(() => ({
      state: document.querySelector(".view3d").dataset.state,
      tools: [...document.querySelectorAll(".view3d-tools [data-act]")].map((b) => b.getAttribute("aria-label")),
      bar: document.querySelector(".view3d-tools")?.getAttribute("aria-label") || "",
      app: document.querySelector(".view3d-app")?.textContent.trim() || "",
      stage: document.querySelector(".view3d .stage")?.getAttribute("aria-label") || "",
      name: document.querySelector("main h1")?.textContent.trim() || "",
    }));
    const tools = ["Zoom out", "Zoom in", "Reset the view", "Full screen", "Back to the picture"].map((word) => script(code, word));
    check(said.state === "ready" && JSON.stringify(said.tools) === JSON.stringify(tools) && said.bar === script(code, "3D view")
      && said.app === script(code, "Open in the app"),
      `${where}: ${said.state}, its tools ${said.tools.map((name) => `"${name}"`).join(", ")}, "${said.app}"`);
    const label = script(code, "{name} in 3D. Drag to turn it. With it focused, the arrow keys turn it, plus and minus zoom, "
      + "0 goes back to the start and F is full screen.", { name: said.name });
    check(said.stage === label, `${where}: its label says "${said.stage.slice(0, 80)}…"`);
    if (code !== "en") {
      const left = await englishIn(tab, "main h1", ".view3d");
      check(!left.length, `${where}: no English in the view${left.length ? `: ${left.length}, first "${left[0].slice(0, 120)}"` : ""}`);
    }
    await tab.locator(".view3d").scrollIntoViewIfNeeded();
    if (out) await tab.screenshot({ path: path.join(out, `${code}-viewer-${width}-1.png`) });
    // Its model not coming: the site answers 404 for it, here in the browser.
    const scene = await tab.locator(picture).getAttribute("data-scene");
    await tab.route((url) => url.pathname === new URL(scene, base).pathname, (route) => route.fulfill({ status: 404, body: "" }));
    await tab.reload({ waitUntil: "load" });
    await tab.locator(picture).click();
    await settled();
    const failed = await tab.evaluate(() => ({
      state: document.querySelector(".view3d").dataset.state,
      said: document.querySelector(".view3d-said")?.firstChild?.textContent.trim() || "",
      again: document.querySelector(".view3d-said button")?.textContent.trim() || "",
    }));
    const why = script(code, "The 3D view could not load: {why}. The picture is still here.",
      { why: script(code, "the site said {status}", { status: 404 }) });
    check(failed.state === "failed" && failed.said === why && failed.again === script(code, "Try again"),
      `${where}: its model not coming, "${failed.said}" "${failed.again}"`);
    await tab.locator(".view3d").scrollIntoViewIfNeeded();
    if (out) await tab.screenshot({ path: path.join(out, `${code}-viewer-${width}-2.png`) });
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

// The owner's sign-in, planted in the browser for what the server tells
// only them: its answers are made here, and nothing with it leaves.
const PLANTED = "languages5-flow";
const UNDER_13_COMMENTS = "Comments are for people 13 and over, so you can read them here but not add one. "
  + "Building, your models and sharing by link are all yours.";
const UNDER_13_VOTE = "Voting is for people 13 and over, so this account cannot vote. The entries are here to look at "
  + "all the same.";
const UNDER_13_FOLLOW = "Following people is for people 13 and over, because a follow is counted in public. "
  + "Building, your models and sharing by link are all yours.";
// The app's reasons, as src/assembly/tested.gd words them, naming two of
// the model's own parts and one of its colours (whysOf).
let WHYS = {};
const whysOf = ({ part, other, colour }) => ({
  stands: `At step 3 it tipped over to the left and lies on its side; At step 7 ${part} hangs from ${other} `
    + "on 2 studs past where it lets go; and 4 more steps",
  parts: `${part} (3) never made in ${colour}`,
  whole: `1 piece is held by nothing, and comes away when the model is lifted: ${part} falls off ${other}`,
});

/// The model at [at]'s parts list, in [code] (?lang=): a deployment's, or
/// the stand-in's from this checkout's handlers.
async function lotsOf(at, code = "en") {
  const asked = `${at}/parts.json${code === "en" ? "" : `?lang=${code}`}`;
  const text = remote ? await (await fetch(`${remote}${asked}`, { headers })).text()
    : (await stand.serverPage(path.join(root, "api"), asked)).html;
  return JSON.parse(text).lots || [];
}

/// Two of the model at [at]'s parts and one of its colours that [code]
/// names its own way, as the app writes them and as the language says them.
async function namedIn(at, code) {
  const said = new Map((await lotsOf(at, code)).map((lot) => [`${lot.part}/${lot.colour}`, lot]));
  const lots = (await lotsOf(at)).map((lot) => ({ ...lot, ...said.get(`${lot.part}/${lot.colour}`), name: lot.name }))
    .filter((lot) => !lot.custom && lot.said && lot.said !== lot.name);
  const [one, two] = [lots[0], lots.find((lot) => lot.name !== lots[0]?.name)];
  const tint = lots.find((lot) => lot.colour_said && lot.colour_said !== lot.colour_name);
  if (!one || !two || !tint) return null;
  return { english: { part: one.name, other: two.name, colour: tint.colour_name },
    said: { part: one.said, other: two.said, colour: tint.colour_said } };
}

/// The owner's answers, as the server makes them (api/_challenges.js,
/// api/share.js testedOwn, api/_comments.js, api/_follows.js), for
/// [route] if it is one; else a read goes out signed out, and anything
/// else with the planted sign-in goes nowhere.
async function ownersAnswer(route) {
  const request = route.request();
  if (request.headers().authorization !== `Bearer ${PLANTED}`) return route.fallback();
  const url = new URL(request.url());
  const op = url.origin === new URL(base).origin && url.pathname.startsWith("/api/") ? url.searchParams.get("op") : "";
  const json = (status, body) => route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
  const rules = { most_parts: 1500, set_number: null, set_name: null, tested: true };
  const checked = { ok: false, parts: { ok: false, has: 1612, most: 1500 }, tested: { ok: false } };
  const broken = [{ rule: "parts", said: "It has 1,612 parts: this challenge allows at most 1,500." },
    { rule: "tested", said: "Its newest version is not marked Tested: the app tests a model as it is shared (it stands at "
      + "every step, every part made in its colour)." }];
  if (op === "challenge_entry") {
    return json(200, { mine: true, ready: true, challenge: { id: 9, title: "Castle November", starts_on: "2026-11-01",
      ends_on: "2026-11-30", days_said: "1 Nov 2026 to 30 Nov 2026",
      rules_said: ["At most 1,500 parts", "Marked Tested: it stands at every step, and every part is made in its colour"], rules },
    entry: null, entries: 4, in_gallery: true, keeps: false, broken, check: checked });
  }
  if (op === "enter") {
    return json(422, { error: `It does not keep this challenge's rules. ${broken.map((one) => one.said).join(" ")}`,
      refused: "rules", broken, check: checked });
  }
  if (op === "challenge" && !url.searchParams.has("id")) {
    // This month's, as anybody is shown it, and why this account may not
    // vote in it (api/_challenges.js VOTE_SAID.under_13).
    const asked = new URL(url.pathname + url.search, stand.ORIGIN);
    const out = { ...request.headers() };
    delete out.authorization;
    const body = remote ? await (await route.fetch({ headers: out })).json() : stand.apiAnswer({ url: asked, state: {} }).json;
    return json(200, { ...body, you: { signed_in: true, voted: { hand: null, assistant: null }, entries: [], may_vote: false,
      why_not: UNDER_13_VOTE } });
  }
  if (op === "tested") {
    const tests = Object.fromEntries(["stands", "steps", "parts", "whole"].map((name) => [name, WHYS[name]
      ? { ok: false, said: { stands: "Not shown to stand at every step", parts: "A part is not made in its colour",
        whole: "It does not go together" }[name], why: WHYS[name] } : { ok: true, said: "every step reachable", why: "" }]));
    return json(200, { id: url.searchParams.get("id"), mine: true, version: 1, tested: { passed: false, cleared: false, tests } });
  }
  if (op === "comments") {
    const v = Number(url.searchParams.get("v")) || 1;
    return json(200, { model: url.searchParams.get("id"), ready: true, version: v, newest: v, open: true, replies: true, count: 0,
      comments: [], you: { signed_in: true, may_write: false, why_not: UNDER_13_COMMENTS, owner: false } });
  }
  if (op === "follows") {
    return json(200, { ready: true, handle: url.searchParams.get("handle"), followers: 3, you_follow: false, mine: false,
      signed_in: true, may: false, why_not: UNDER_13_FOLLOW });
  }
  if (request.method() !== "GET" || !op) return json(401, { error: "signed out" });
  const headers = { ...request.headers() };
  delete headers.authorization;
  return route.fallback({ headers });
}

/// What the server tells a visitor on the model's copy in [code]: why
/// they may not comment or follow, a challenge's rules and what the model
/// breaks of them, and why it is not Tested, each in the language.
async function serverSaid(browser, code, width, at) {
  const named = await namedIn(at, code);
  if (!named) return check(false, `${code} server words ${width}: two parts and a colour of ${at} the language names`);
  WHYS = whysOf(named.english);
  const context = await newContext(browser, code, width);
  await context.addInitScript((planted) => {
    localStorage.setItem("brickworks.session", JSON.stringify({ refresh_token: planted, email: "flow@example.invalid",
      user_id: "", url: "", key: "" }));
    sessionStorage.setItem("brickworks.access", JSON.stringify({ token: planted, until: Date.now() + 3600000,
      email: "flow@example.invalid" }));
  }, PLANTED);
  await context.route("**/*", ownersAnswer);
  const tab = await context.newPage();
  const where = `${code} server words ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    await tab.goto(`${base}${lang}${at}`, { waitUntil: "load" });
    // Why they may not comment: its comments asked for as they near.
    await tab.evaluate(() => (document.getElementById("comments-hold") || document.getElementById("comments"))?.scrollIntoView());
    await tab.waitForFunction(() => document.querySelector("#comments .comment-why .note")?.textContent.trim(), null, { timeout: 30000 });
    const why = (await tab.locator("#comments .comment-why .note").first().textContent()).trim();
    check(why === script(code, UNDER_13_COMMENTS), `${where}: why not comment, "${why.slice(0, 70)}…"`);
    // Why they may not follow its designer.
    const follow = tab.locator(".shared-by button.follow").first();
    await follow.waitFor({ state: "visible", timeout: 15000 });
    await follow.click();
    const told = await tab.waitForFunction(() => document.querySelector(".shared-by .said")?.textContent.trim(), null,
      { timeout: 15000 }).then((said) => said.jsonValue());
    check(told === script(code, UNDER_13_FOLLOW), `${where}: why not follow, "${told.slice(0, 70)}…"`);
    // Why it is not Tested: its parts and colour named as its parts list
    // names them in the language, in German a whole sentence after a
    // colon opened with a capital ("Bei Schritt 3: Es ist ..."), and in
    // French a narrow space before every colon and semicolon.
    await tab.waitForFunction(() => document.documentElement.dataset.testedNote === "shown", null, { timeout: 15000 });
    const note = await tab.evaluate(() => {
      const shown = document.getElementById("tested-note");
      return { text: shown.textContent.trim(), english: [...shown.querySelectorAll("[lang='en']")].map((one) => one.textContent),
        failed: [...shown.querySelectorAll("[data-failed]")].map((one) => one.textContent.trim()) };
    });
    const heads = [script(code, "Not shown to stand at every step"), script(code, "A part is not made in its colour"),
      script(code, "It does not go together")];
    const left = code === "en" ? [] : note.failed.filter((line) => ENGLISH.test(line) || /\b(?:step|tipped|hangs|piece|never)\b/.test(line)
      || Object.values(named.english).some((name) => line.includes(name)));
    const unnamed = Object.values(named.said).filter((name) => !note.failed.some((line) => line.includes(name)));
    const small = code === "de" ? note.failed.filter((line) => /: \p{Ll}/u.test(line)) : [];
    const bare = code === "fr" ? note.failed.filter((line) => /[^\s\u202f\u00a0][:;](?:\s|$)/u.test(line)) : [];
    const colon = code === "fr" ? "\u202f: " : ": ";
    check(note.failed.length === 3 && note.failed.every((line, n) => line.startsWith(`${heads[n]}${colon}`)) && !note.english.length
      && !left.length && !unnamed.length && !small.length && !bare.length,
      `${where}: why not Tested, "${(note.failed[0] || "").slice(0, 110)}…", naming ${Object.values(named.said).join(", ")}`
      + `${left.length ? `; English: "${left[0].slice(0, 100)}"` : ""}${note.english.length ? `; marked English: "${note.english[0]}"` : ""}`
      + `${unnamed.length ? `; not named: ${unnamed.join(", ")}` : ""}${small.length ? `; small after a colon: "${small[0].slice(0, 100)}"` : ""}`
      + `${bare.length ? `; no space before a colon: "${bare[0].slice(0, 100)}"` : ""}`);
    if (out) {
      await tab.locator("#tested-note").scrollIntoViewIfNeeded();
      await tab.screenshot({ path: path.join(out, `${code}-server-${width}-1.png`) });
    }
    // This month's challenge: its rules, and what the model breaks of them.
    const enter = tab.locator("button[data-enter]");
    await enter.waitFor({ state: "visible", timeout: 15000 });
    await enter.click();
    const dialog = tab.locator("dialog.enter");
    await dialog.waitFor({ state: "visible", timeout: 10000 });
    const [n1500, n1612] = await tab.evaluate((code) => [1500, 1612].map((n) => n.toLocaleString(code)), code);
    const rules = await dialog.evaluate((box) => ({ lede: box.querySelector("p")?.textContent.trim() || "",
      rules: [...box.querySelectorAll("ul li")].map((li) => li.textContent.trim()) }));
    const wanted = [script(code, "At most {parts}", { parts: `${n1500} ${script(code, "parts")}` }),
      script(code, "Marked Tested: it stands at every step, and every part is made in its colour")];
    check(rules.lede === script(code, "Brickworks checks its rules on this model as you shared it:")
      && JSON.stringify(rules.rules) === JSON.stringify(wanted),
      `${where}: the challenge's rules, "${rules.lede}" ${rules.rules.map((one) => `"${one}"`).join(", ")}`);
    await dialog.locator("input[name=way][value=hand]").check();
    await dialog.locator("button[type=submit]").click();
    await tab.waitForFunction(() => document.documentElement.dataset.challengeRefused, null, { timeout: 10000 });
    const refused = await dialog.evaluate((box) => [...box.querySelectorAll(".status li, [role=status] li")].map((li) => li.textContent.trim()));
    const breaks = [script(code, "It has {parts}: this challenge allows at most {most}.",
      { parts: `${n1612} ${script(code, "parts")}`, most: n1500 }),
    script(code, "Its newest version is not marked Tested: the app tests a model as it is shared (it stands at every step, "
      + "every part made in its colour).")];
    check(JSON.stringify(refused) === JSON.stringify(breaks), `${where}: what it breaks, ${refused.map((one) => `"${one.slice(0, 60)}…"`).join(", ")}`);
    if (out) await tab.screenshot({ path: path.join(out, `${code}-server-${width}-2.png`) });
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

// The pages languages6 put in each language. What people wrote on them,
// and the names they say: as they wrote them. A challenge's title and
// brief are the owner's, written in English for every visitor.
const THEIRS_CHALLENGE = "#title, #crumb, #brief, #next-title, #next-brief, .past-one h3, .winner-cards .words";
const THEIRS_LIST = ".list-head h1, .list-head .handle a, .list-head .bio";
const THEIRS_COLLECTIONS = ".list-card .name, .list-card .who";
const THEIRS_OWN = "#title, #handle-line, #bio-shown, #links-shown, .list-card .name, .list-card .who, .people-list .name, "
  + ".people-list .handle, #pins .words, #lists .name, #following a, .follows .pills a, #email-shown, .email, [data-email], "
  + "#owned-counts .name, .lot .name, figure.build q";

/// This month's challenge in [code], from /challenge: its words, its days
/// and rules as the language says them, and why this account may not vote
/// (its sign-in planted, as serverSaid's); then a challenge's own link,
/// /challenge?id=N, its head in the language.
async function challengeSaid(browser, code, width, past) {
  const context = await newContext(browser, code, width);
  await context.addInitScript((planted) => {
    localStorage.setItem("brickworks.session", JSON.stringify({ refresh_token: planted, email: "flow@example.invalid",
      user_id: "", url: "", key: "" }));
    sessionStorage.setItem("brickworks.access", JSON.stringify({ token: planted, until: Date.now() + 3600000,
      email: "flow@example.invalid" }));
  }, PLANTED);
  await context.route("**/*", ownersAnswer);
  const tab = await context.newPage();
  const where = `${code} challenge ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    await tab.goto(`${base}/challenge`, { waitUntil: "load" });
    const at = new URL(tab.url()).pathname;
    check(at === `${lang}/challenge` && await tab.evaluate(() => document.documentElement.lang) === code,
      `${where}: opens ${lang}/challenge in ${code} (at ${at})`);
    await tab.waitForFunction(() => document.documentElement.dataset.challenge, null, { timeout: 20000 });
    const state = await tab.evaluate(() => document.documentElement.dataset.challenge);
    const title = await tab.title();
    const name = (await tab.locator("#title").textContent()).trim();
    check(title === script(code, "{title} · a Brickworks challenge", { title: name }), `${where}: its title says "${title}"`);
    const shown = await tab.evaluate(() => ({ why: document.querySelector("#groups .why-not")?.textContent.trim() || "",
      eyebrow: document.getElementById("eyebrow")?.textContent.trim() || "", days: document.getElementById("days")?.textContent.trim() || "",
      rules: [...document.querySelectorAll("#rules li")].map((li) => li.textContent.trim()) }));
    check(["open", "ended", "upcoming"].includes(state), `${where}: drawn (${state}), "${shown.eyebrow}", "${shown.days}"`);
    if (state === "open") {
      check(shown.why === script(code, UNDER_13_VOTE), `${where}: why this account may not vote, "${shown.why.slice(0, 80)}…"`);
    }
    await copyRead(tab, code, width, where, "challenge", THEIRS_CHALLENGE);
    // A challenge's own link, its head made by the server in the language.
    if (past) {
      await tab.goto(`${base}/challenge?id=${past.id}`, { waitUntil: "load" });
      const head = await tab.evaluate(() => ({ path: location.pathname + location.search, lang: document.documentElement.lang,
        title: document.querySelector('meta[property="og:title"]')?.content || "",
        about: document.querySelector('meta[name="description"]')?.content || "",
        canonical: new URL(document.querySelector('link[rel="canonical"]')?.href || location.href),
        alternates: Object.fromEntries([...document.querySelectorAll('link[rel="alternate"][hreflang]')]
          .map((link) => [link.hreflang, new URL(link.href).pathname + new URL(link.href).search])) }));
      const own = `${lang}/challenge?id=${past.id}`;
      const english = `/challenge?id=${past.id}`;
      const want = { en: english, de: `/de${english}`, fr: `/fr${english}`, es: `/es${english}`, "x-default": english };
      // Its head as the server made it: the page's script names the tab
      // itself once it has drawn the challenge.
      const titled = script(code, "{title} · Brickworks challenge", { title: past.title });
      const when = code === "en" ? "" : script(code, "Ran {days}: see who won.").split("{days}")[0];
      check(head.path === own && head.lang === code && head.title === titled && head.canonical.pathname + head.canonical.search === own
        && JSON.stringify(head.alternates) === JSON.stringify(want) && head.about.includes(when),
        `${where}: ${own} answers in ${head.lang}, "${head.title}", "…${head.about.slice(-60)}", canonical ${head.canonical.pathname}`
        + `${head.canonical.search}, ${Object.keys(head.alternates).length} alternates`);
    }
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// Every collection in [code], from /collections, and one of them, from
/// /c/[id]: in the language, but their names and who made them; the
/// collection's people and models each linked in it.
async function collectionsSaid(browser, code, width, id) {
  const context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const lang = code === "en" ? "" : `/${code}`;
  let where = `${code} collections ${width}`;
  try {
    const said = await copyOpened(tab, code, "/collections", where);
    const chrome = await tab.evaluate(() => ({
      tabs: [...document.querySelectorAll("nav.tabs a")].map((a) => [a.textContent.trim(), new URL(a.href).pathname]),
      lists: [...document.querySelectorAll(".list-card a.name")].map((a) => new URL(a.href).pathname),
    }));
    const tabs = ["Recently added to", "Most followed"].map((word) => script(code, word));
    check(said.title === script(code, "Collections — the Brickworks gallery") && JSON.stringify(chrome.tabs.map(([text]) => text)) === JSON.stringify(tabs)
      && chrome.tabs.every(([, to]) => to === `${lang}/collections`),
      `${where}: "${said.title}", its tabs ${chrome.tabs.map(([text, to]) => `"${text}" ${to}`).join(", ")}`);
    const away = chrome.lists.filter((to) => !to.startsWith(`${lang}/c/`));
    check(chrome.lists.length && !away.length, `${where}: ${chrome.lists.length} collections open in ${code}${away.length ? `, not: ${away[0]}` : ""}`);
    await copyRead(tab, code, width, where, "collections", THEIRS_COLLECTIONS);
    where = `${code} collection ${width}`;
    const list = await copyOpened(tab, code, `/c/${id}`, where);
    const shown = await tab.evaluate(() => ({ name: document.querySelector(".list-head h1")?.textContent.trim() || "",
      eyebrow: document.querySelector(".list-head .eyebrow")?.textContent.trim() || "",
      by: document.querySelector(".list-head .handle")?.textContent.trim() || "",
      who: document.querySelector(".list-head .handle a")?.textContent.trim() || "",
      links: [...document.querySelectorAll("main a[href]")].map((a) => new URL(a.href, location.href))
        .filter((url) => url.origin === location.origin && /^(?:\/[a-z]{2})?\/[mu]\//.test(url.pathname)).map((url) => url.pathname) }));
    const collected = script(code, "Collected by {who} · updated {when}", { who: shown.who, when: "" });
    const wrong = shown.links.filter((to) => !to.startsWith(`${lang}/`) || !/^\/(?:[a-z]{2}\/)?[mu]\//.test(to) || (code !== "en" && !to.startsWith(`/${code}/`)));
    check(list.title === script(code, "{name} — a collection in the Brickworks gallery", { name: shown.name })
      && shown.eyebrow === script(code, "Collection") && shown.by.startsWith(collected.trim()) && shown.links.length && !wrong.length,
      `${where}: "${list.title}", "${shown.eyebrow}", "${shown.by}", ${shown.links.length} links to its people and models in ${code}`
      + `${wrong.length ? `, not: ${wrong[0]}` : ""}`);
    await copyRead(tab, code, width, where, "collection", THEIRS_LIST);
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

/// The deployment's Supabase project, which a page signed in on it asks.
let projectAsked = null;
const projectOf = () => (projectAsked ||= remote ? fetch(`${remote}/api/account`, { headers }).then((reply) => reply.json())
  .then((said) => new URL(said.url).origin).catch(() => "") : Promise.resolve(""));

/// Your own profile and your settings in [code], signed in as the
/// stand-in's Sam: the sign-in kept in this browser only, and every API
/// call answered here, a deployment's pages or not. Each tab of the
/// profile, its Edit dialog, and the settings page, none of it English but
/// what Sam wrote.
async function ownSaid(browser, code, width, kind) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, locale: ASKED[code].locale,
    extraHTTPHeaders: { ...headers, "accept-language": ASKED[code].header },
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  const db = await projectOf();
  await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), remote, headers, remoteDb: db });
  const kept = JSON.parse(JSON.stringify(stand.signedInStorage()).split(stand.DB).join(db || stand.DB));
  await context.addInitScript((kept) => {
    localStorage.setItem("brickworks.session", JSON.stringify(kept.session));
    sessionStorage.setItem("brickworks.access", JSON.stringify(kept.access));
  }, kept);
  const tab = await context.newPage();
  const where = `${code} ${kind} ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  try {
    await tab.goto(`${base}/${kind}`, { waitUntil: "load" });
    const at = new URL(tab.url()).pathname;
    check(at === `${lang}/${kind}` && await tab.evaluate(() => document.documentElement.lang) === code,
      `${where}: opens ${lang}/${kind} in ${code} (at ${at})`);
    const title = await tab.title();
    check(title === page(code, kind === "profile" ? "Your profile · Brickworks" : "Settings · Brickworks"), `${where}: its title says "${title}"`);
    await tab.waitForFunction((kind) => ["ready", "signed-out"].includes(document.documentElement.dataset[kind]), kind, { timeout: 30000 });
    check(await tab.evaluate((kind) => document.documentElement.dataset[kind], kind) === "ready", `${where}: drawn signed in`);
    if (kind === "profile") {
      // Each of its tabs, and what each says.
      const tabs = await tab.evaluate(() => [...document.querySelectorAll("#tabs a[data-tab]")].filter((a) => !a.hidden)
        .map((a) => [a.dataset.tab, a.firstChild.textContent.trim(), new URL(a.href).pathname]));
      const away = tabs.filter(([, , to]) => to !== `${lang}/profile`);
      check(tabs.length >= 4 && !away.length, `${where}: its tabs ${tabs.map(([, text]) => text).join(" / ")}${away.length ? `, ${away[0][0]} opens ${away[0][2]}` : ""}`);
      for (const [name] of tabs) {
        await tab.locator(`#tabs a[data-tab="${name}"]`).click();
        await tab.waitForFunction((name) => document.querySelector(`#tabs a[data-tab="${name}"]`)?.getAttribute("aria-current") === "page"
          && !document.querySelector("#tab-loading:not([hidden])"), name, { timeout: 15000 });
        await tab.waitForTimeout(500);
        if (code !== "en") {
          const left = await englishIn(tab, THEIRS_OWN);
          check(!left.length, `${where}: its ${name} tab, no English left${left.length
            ? `: ${left.length}, first "${left[0].slice(0, 120)}" in ${await whereSaid(tab, left[0].trim())}` : ""}`);
        }
        await screens(tab, `${code}-${kind}-${name}-${width}`, 2);
      }
      // Edit profile: its dialog.
      await tab.locator("#edit").click();
      await tab.locator("#edit-dialog").waitFor({ state: "visible", timeout: 10000 });
      if (code !== "en") {
        const left = await englishIn(tab, `${THEIRS_OWN}, #edit-dialog input, #edit-dialog textarea, #edit-dialog option`, "#edit-dialog");
        check(!left.length, `${where}: Edit profile, no English left${left.length ? `: ${left.length}, first "${left[0].slice(0, 120)}"` : ""}`);
      }
      if (out) await tab.screenshot({ path: path.join(out, `${code}-${kind}-edit-${width}.png`) });
      await tab.keyboard.press("Escape");
    }
    await copyRead(tab, code, width, where, kind, THEIRS_OWN);
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

// The last pages languages7 put in each language, by their English file:
// [file], where it is, whether it is drawn signed in (planted, as ownSaid's),
// what marks it drawn, and what on it is people's (or the release notes).
const PKCE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";
const CONSENT = `/oauth/authorize?response_type=code&client_id=flow&redirect_uri=${encodeURIComponent("https://claude.ai/api/mcp/auth_callback")}`
  + `&code_challenge=${PKCE}&code_challenge_method=S256&state=flow`;
const SEVENTH = [
  { name: "feed", file: "feed.html", at: "/feed", signedIn: true, drawn: () => document.documentElement.dataset.feed === "ready",
    theirs: ".feed-row .what b, .feed-row .what a, .feed-row q, .feed-photo figcaption, .people-list .name, .people-list .handle" },
  { name: "notifications", file: "notifications.html", at: "/notifications", signedIn: true,
    drawn: () => document.documentElement.dataset.notifications === "ready", theirs: ".notice h2 a, .notice .what b, .notice q" },
  { name: "builds", file: "builds.html", at: "/builds", drawn: () => ["ready", "none"].includes(document.documentElement.dataset.builds),
    theirs: "figure.build q, figure.build figcaption a" },
  { name: "feedback", file: "feedback.html", at: "/feedback", signedIn: true, drawn: () => true, theirs: "" },
  { name: "beta", file: "beta.html", at: "/beta", signedIn: true,
    drawn: () => document.getElementById("apply-wait")?.hidden && !document.querySelector("#spots .bone"), theirs: "" },
  { name: "beta-hub", file: "beta-hub.html", at: "/beta-hub", signedIn: true, drawn: () => !document.getElementById("hub")?.hidden,
    theirs: "[lang='en']" },
  ...["terms", "privacy", "guidelines", "takedown"].map((name) => ({ name, file: `${name}.html`, at: `/${name}`, binds: true,
    drawn: () => true, theirs: "" })),
  { name: "changelog", file: "changelog.html", at: "/changelog", drawn: () => true, theirs: ".release-notes, .release-head h2" },
  { name: "missing", file: "404.html", at: "/no-such-brick", drawn: () => true, theirs: "" },
  { name: "consent", file: "authorize.html", at: CONSENT, signedIn: true,
    drawn: () => !document.getElementById("allow-step")?.classList.contains("hide"), theirs: "#signed-in-as, #back-to b" },
];
const titleOf = (file) => plain(/<title>([^<]*)<\/title>/.exec(readFileSync(path.join(root, "web", file), "utf8"))[1]);
const headingOf = (file) => plain(/<main\b[\s\S]*?<h1[^>]*>([\s\S]*?)<\/h1>/.exec(readFileSync(path.join(root, "web", file), "utf8"))[1]);
const BOUND = 'This is a translation. The <a href="{english}">English text</a> is the one that binds.';
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

/// One of [one]'s pages in [code] at [width], from its English address as a
/// browser asking for the language opens it: on its copy, its words, the
/// checks of its own, then copyRead's.
async function seventhSaid(browser, code, width, one) {
  const phone = width < 600;
  let context;
  if (one.signedIn) {
    // Signed in in this browser only: every call the page makes is answered
    // here, a deployment's pages or not (ownSaid).
    context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, locale: ASKED[code].locale,
      extraHTTPHeaders: { ...headers, "accept-language": ASKED[code].header },
      ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
    const db = await projectOf();
    await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), remote, headers, remoteDb: db });
    const kept = JSON.parse(JSON.stringify(stand.signedInStorage()).split(stand.DB).join(db || stand.DB));
    await context.addInitScript((kept) => {
      localStorage.setItem("brickworks.session", JSON.stringify(kept.session));
      sessionStorage.setItem("brickworks.access", JSON.stringify(kept.access));
    }, kept);
  } else context = await newContext(browser, code, width);
  const tab = await context.newPage();
  const where = `${code} ${one.name} ${width}`;
  const lang = code === "en" ? "" : `/${code}`;
  const asked = new URL(one.at, "https://x");
  const own = `${lang}${asked.pathname === "/" ? "" : asked.pathname}`;
  // The status each page of the tab was answered with.
  const statuses = [];
  tab.on("response", (reply) => {
    if (reply.request().isNavigationRequest() && reply.frame() === tab.mainFrame()) statuses.push(reply.status());
  });
  try {
    await tab.goto(`${base}${one.at}`, { waitUntil: "load" });
    await tab.waitForURL((url) => url.pathname === own, { timeout: 10000 }).catch(() => {});
    await tab.waitForLoadState("load");
    const at = new URL(tab.url());
    check(at.pathname === own && at.search === asked.search && await tab.evaluate(() => document.documentElement.lang) === code,
      `${where}: opens ${own}${asked.search ? "?…" : ""} in ${code} (at ${at.pathname}, lang ${await tab.evaluate(() => document.documentElement.lang)})`);
    const title = await tab.title();
    check(title === plain(page(code, titleOf(one.file))), `${where}: its title says "${title}"`);
    await tab.waitForFunction(one.drawn, null, { timeout: 30000 });
    if (one.name === "missing") {
      const said = (await tab.locator("main h1").textContent()).trim();
      check(statuses.at(-1) === 404 && said === page(code, "This brick is missing."),
        `${where}: answered ${statuses.at(-1)}, "${said}"`);
    }
    if (one.binds) {
      // One line under its heading: the English binds, a link to it.
      const line = await tab.evaluate(() => {
        const said = document.querySelector("main .binding");
        return said ? { text: said.textContent.trim(), to: said.querySelector("a")?.getAttribute("href") || "",
          after: said.previousElementSibling?.localName || "" } : null;
      });
      if (code === "en") check(line === null, `${where}: no line saying what binds`);
      else {
        check(line && line.text === plain(page(code, BOUND)) && line.to === `${one.at}?lang=en` && line.after === "h1",
          `${where}: "${line?.text}", its link ${line?.to}`);
        // Its link opens the English text, and it stays English.
        if (width === widths[0]) {
          await Promise.all([tab.waitForURL((url) => url.pathname === one.at, { timeout: 10000 }), tab.locator("main .binding a").click()]);
          await tab.waitForTimeout(500);
          const english = await tab.evaluate(() => ({ at: location.pathname, lang: document.documentElement.lang,
            h1: document.querySelector("main h1")?.textContent.trim() || "" }));
          check(english.at === one.at && english.lang === "en" && english.h1 === headingOf(one.file),
            `${where}: the link opens ${english.at} in ${english.lang}, "${english.h1}"`);
          await tab.goto(`${base}${own}`, { waitUntil: "load" });
        }
      }
    }
    if (one.name === "changelog") {
      const said = await tab.evaluate(() => ({
        notes: [...document.querySelectorAll(".release-notes")].map((notes) => notes.getAttribute("lang") || ""),
        first: [...document.querySelectorAll(".release time[datetime]")].map((time) => [time.dateTime, time.textContent.trim()])[0],
        download: [...document.querySelectorAll(".release .when a")].map((a) => [a.textContent.trim(), new URL(a.href).pathname])[0],
      }));
      const [iso, shown] = said.first || ["", ""];
      const [y, m, d] = iso.split("-").map(Number);
      const want = script(code, "{day} {month} {year}", { day: d, month: script(code, MONTHS[m - 1]), year: y });
      const notesWant = code === "en" ? "" : "en";
      check(said.notes.length >= 5 && said.notes.every((one) => one === notesWant) && shown === want
        && said.download?.[0] === script(code, "Download") && said.download?.[1] === `${lang}/download`,
        `${where}: ${said.notes.length} releases' notes ${code === "en" ? "" : 'lang="en", '}"${shown}", "${said.download?.[0]}" ${said.download?.[1]}`);
    }
    if (one.name === "feed" || one.name === "notifications") {
      // The lines the server said in the language, {who} where it puts them.
      const lines = await tab.evaluate(() => [...document.querySelectorAll(".feed-row .what, .notice .what")]
        .map((what) => what.textContent.replace(/\s+/g, " ").trim()));
      check(lines.length >= 3, `${where}: ${lines.length} lines, first "${lines[0]?.slice(0, 90)}"`);
    }
    if (one.name === "beta") {
      // The form's refusal, said by its script in the language.
      await tab.locator("#apply-send").click();
      await tab.waitForFunction(() => document.getElementById("apply-said")?.textContent.trim(), null, { timeout: 10000 });
      const said = (await tab.locator("#apply-said").textContent()).trim();
      const want = script(code, "Say what you would build, in a sentence or two: at least {n} characters.", { n: 20 });
      check(said === want, `${where}: an empty form is told "${said}"`);
    }
    if (one.name === "feedback") {
      // The feedback dialog, opened from the page, in the language.
      await tab.locator('[data-feedback="bug"]').first().click();
      await tab.locator("dialog.feedback[open]").waitFor({ state: "visible", timeout: 10000 });
      if (code !== "en") {
        const left = await englishIn(tab, "dialog.feedback textarea, dialog.feedback input", "dialog.feedback");
        check(!left.length, `${where}: its dialog, no English left${left.length ? `: ${left.length}, first "${left[0].slice(0, 120)}"` : ""}`);
      }
      if (out) await tab.screenshot({ path: path.join(out, `${code}-${one.name}-dialog-${width}.png`) });
      await tab.keyboard.press("Escape");
    }
    if (one.name === "consent") {
      // As plain() reads the words: a French narrow space before "?" a space.
      const said = plain(await tab.locator("#allow-step h1").textContent());
      const allow = (await tab.locator("#allow").textContent()).trim();
      check(said === plain(page(code, 'Let <span class="client">Claude</span> build in Brickworks?')) && allow === script(code, "Allow"),
        `${where}: asks "${said}", "${allow}"`);
    }
    // The consent page is a card of its own, with no site footer.
    await copyRead(tab, code, width, where, one.name, one.theirs || "[translate='no']", one.name !== "consent");
  } catch (trouble) {
    check(false, `${where}: ${String(trouble.message || trouble).split("\n")[0]}`);
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
  // Where a model's copy leads (languages5): the stand-in's watchtower, its
  // designer and the library's King's Castle; or a deployment's first
  // listed model, its designer, and the set its first model is of.
  const leads = ["profile", "ldraw", "embed", "viewer", "server"].filter((name) => !only || only.includes(name));
  if (leads.length) {
    let at = `/m/${stand.MODEL_ID}`;
    let handle = "design-tester";
    let set = "omr-6080-1";
    if (remote) {
      const listed = await (await fetch(`${remote}/api/share?op=list&page=1`, { headers })).json().catch(() => ({}));
      at = listed.models?.[0] ? `/m/${listed.models[0].id}` : "";
      const page = at ? await (await fetch(`${remote}${at}`, { headers })).text() : "";
      handle = /href="\/u\/([a-z0-9-]{3,24})"/.exec(page)?.[1] || "";
      const library = await (await fetch(`${remote}/library/set/6080-1`, { headers })).text();
      set = /href="\/library\/(omr-[A-Za-z0-9_.-]+)"/.exec(library)?.[1] || "";
    }
    for (const code of langs.includes("en") ? langs : ["en", ...langs]) {
      for (const width of widths) {
        if (leads.includes("profile")) await (handle ? profileSaid(browser, code, width, handle) : check(false, "a designer to open"));
        if (leads.includes("ldraw")) await (set ? ldrawSaid(browser, code, width, set) : check(false, "an LDraw set to open"));
        if (leads.includes("embed")) await embedSaid(browser, code, width, at);
        if (leads.includes("viewer")) await viewerSaid(browser, code, width, at);
        if (leads.includes("server") && code !== "en") await serverSaid(browser, code, width, at);
      }
    }
  }
  // The pages languages6 put in each language: this month's challenge and
  // one that ran, every collection and one, your own profile and your
  // settings. The stand-in's, or a deployment's: its challenges, and the
  // first collection it lists.
  const sixth = ["challenge", "collections", "account"].filter((name) => !only || only.includes(name));
  if (sixth.length) {
    let past = { id: 2, title: "Castle September" };
    let list = "ListAbcde1";
    if (remote) {
      const shown = await (await fetch(`${remote}/api/people?op=challenge`, { headers })).json().catch(() => ({}));
      past = shown.past?.[0] ? { id: shown.past[0].id, title: shown.past[0].title } : null;
      const listed = await (await fetch(`${remote}/collections`, { headers })).text().catch(() => "");
      list = /href="\/c\/([A-Za-z0-9]{10})"/.exec(listed)?.[1] || "";
    }
    for (const code of langs.includes("en") ? langs : ["en", ...langs]) {
      for (const width of widths) {
        if (sixth.includes("challenge")) await challengeSaid(browser, code, width, past);
        if (sixth.includes("collections")) await (list ? collectionsSaid(browser, code, width, list) : check(false, "a collection to open"));
        if (sixth.includes("account")) {
          await ownSaid(browser, code, width, "profile");
          await ownSaid(browser, code, width, "settings");
        }
      }
    }
  }
  // The last pages languages7 put in each language.
  const seventh = SEVENTH.filter((one) => !only || only.includes(one.name));
  for (const code of seventh.length ? (langs.includes("en") ? langs : ["en", ...langs]) : []) {
    for (const width of widths) {
      for (const one of seventh) await seventhSaid(browser, code, width, one);
    }
  }
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
