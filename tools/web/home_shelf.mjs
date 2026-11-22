// The home page's first screen, written into the page as it is served
// (landing, 2026-11-22, docs/HOME.md): the shelf's cards, real models with
// their pictures, and the month's challenge's name, brief and days.
//
//   node tools/web/home_shelf.mjs OUT [--from=https://brickworks.diy] [--save] [--offline]
//
// OUT is the site put together (tools/site.py OUT): its index.html and each
// language's (OUT/de/index.html, ...). tools/deploy.sh runs it after
// tools/site.py. Each tab of the shelf (web/index.html #shelf, its panels'
// data-ask) is asked of --from's gallery as anybody signed out asks it, and
// /api/share?op=shelves for this week's pick and the challenge. What cannot
// be read there is read from web/_home.json, the answers kept the last time
// --save was given, so a deploy never ships a first screen that waits on the
// server. --offline reads web/_home.json alone (tests, a checkout's look).
//
// Each card is the site's own (web/card.js cardHtml, as the server draws
// one), in the page's language from the words its copy carries
// (#site-words); its picture is copied into OUT/img/home/, so the first
// screen's pictures come from the CDN beside the page and never wait on a
// function or the bucket. The first tab shown is Trending once the week's
// list has FEWEST models with pictures, else Top, with this week's pick
// first. web/landing.js asks each list again once the page is in and puts
// in what changed, a card for a card.
//
// It changes nothing it cannot fill: a page without the shelf's markers is
// left as it is and said; nothing to show leaves the skeletons, and says so.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { cardHtml, escapeHtml, marksOf, pictureOf, quietMarks } from "../../web/card.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const SNAPSHOT = join(ROOT, "web/_home.json");
const LANGS = ["", "de", "fr", "es"];
const TABS = ["trending", "top", "new", "sets"];
/// Cards a tab shows: a row that scrolls, half again what a laptop shows.
export const CARDS = 10;
/// The fewest cards with pictures that make a tab worth showing.
export const FEWEST = 4;
/// The first cards of the tab shown whose pictures are asked for at once:
/// the first only. With four (the first card of each place a laptop shows),
/// a laptop's first paint came 726 ms later than with one (median of ten
/// rounds at the same moments, later in 8; bench/results/landing-2026-11-22
/// timing3): four pictures decoded in time are drawn into the first frame.
/// The rest of the row, lazy, are asked for as it is laid out, a moment
/// after the first paint, into frames already their size.
export const EAGER = 1;
const MODEL = /^[A-Za-z0-9]{10}$/;
const SET = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith("--")).map((a) => {
  const [k, ...rest] = a.slice(2).split("=");
  return [k, rest.join("=") || true];
}));
const out = process.argv.slice(2).find((a) => !a.startsWith("--"));
const from = String(args.from || "https://brickworks.diy").replace(/\/+$/, "");
// A preview asked by hand (BW_BYPASS, as the flows take it): past its protection.
const HEADERS = { "user-agent": "brickworks-deploy",
  ...(process.env.BW_BYPASS && /\.vercel\.app$/.test(new URL(from).host) ? { "x-vercel-protection-bypass": process.env.BW_BYPASS } : {}) };

/// What [path] answers as JSON, or null.
async function ask(path) {
  try {
    const reply = await fetch(from + path, { headers: { ...HEADERS, accept: "application/json" },
      signal: AbortSignal.timeout(20000) });
    return reply.ok ? await reply.json() : null;
  } catch {
    return null;
  }
}

/// The cards of [answer] (a list's) a tab may show: real ones with pictures.
export function shown(answer) {
  return (answer?.models || []).filter((m) => m && (MODEL.test(String(m.id)) || SET.test(String(m.id))) && pictureOf(m));
}

/// Each tab's models, this week's pick first on the first, and which tab
/// is shown: what [answers] (each panel's data-ask's answer, and shelves)
/// hold.
export function decide(asks, answers) {
  const lists = Object.fromEntries(TABS.map((tab) => [tab, shown(answers[asks[tab]])]));
  const tabs = TABS.filter((tab) => lists[tab].length >= FEWEST);
  const first = tabs.includes("trending") ? "trending" : tabs.includes("top") ? "top" : tabs[0] || "";
  const pick = answers.shelves?.pick?.model && MODEL.test(String(answers.shelves.pick.model.id)) && pictureOf(answers.shelves.pick.model)
    ? answers.shelves.pick.model : null;
  const cards = {};
  for (const tab of tabs) {
    const leads = tab === first && pick && tab !== "sets" ? [pick] : [];
    const rest = lists[tab].filter((m) => !leads.some((one) => one.id === m.id));
    cards[tab] = [...leads, ...rest].slice(0, CARDS);
  }
  const c = answers.shelves?.challenge;
  const challenge = c && !c.test && ["open", "upcoming"].includes(c.state) && c.title ? c : null;
  return { tabs, first, cards, pick: pick?.id || "", challenge };
}

/// Where a picture of the site is copied to under img/home/, by its address.
const copyName = (src) => `${src.replace(/^\/+/, "").replace(/\?v=/, "-").replace(/[^A-Za-z0-9.-]+/g, "-")}`.replace(/\.webp-/, "-") + (/\.webp$/.test(src) ? "" : ".webp");

/// Every picture of [cards] copied into [dir], each its address on the
/// site once copied: a Map of the site's address to the copy's.
async function copyPictures(cards, dir) {
  const wanted = [...new Set(cards.map((m) => pictureOf(m)).filter((src) => src.startsWith("/")))];
  const copied = new Map();
  mkdirSync(dir, { recursive: true });
  let next = 0;
  const one = async () => {
    while (next < wanted.length) {
      const src = wanted[next++];
      try {
        const reply = await fetch(from + src, { headers: { ...HEADERS, accept: "image/webp" }, signal: AbortSignal.timeout(20000) });
        const type = reply.headers.get("content-type") || "";
        if (!reply.ok || !type.startsWith("image/webp")) continue;
        const body = Buffer.from(await reply.arrayBuffer());
        if (body.length < 64) continue;
        const name = copyName(src);
        writeFileSync(join(dir, name), body);
        copied.set(src, `/img/home/${name}`);
      } catch {
        // Left at its own address: the card still shows it, from the server.
      }
    }
  };
  await Promise.all(Array.from({ length: 6 }, one));
  return copied;
}

/// "1–30 November" in [locale], as web/landing.js says a challenge's days.
export function days(from, to, locale) {
  const at = (day) => new Date(`${day}T12:00:00Z`);
  try {
    return new Intl.DateTimeFormat(locale, { day: "numeric", month: "long", timeZone: "UTC" }).formatRange(at(from), at(to));
  } catch {
    return "";
  }
}

/// The words a copy's scripts say ([page]'s #site-words), or none in English.
function wordsOf(page) {
  const found = /<script type="application\/json" id="site-words">(.*?)<\/script>/s.exec(page);
  return found ? JSON.parse(found[1].replace(/<\\\//g, "</")) : null;
}

/// [draw] in [code]'s language, as the server draws a page in one
/// (api/_directory.js inLanguage).
function inLanguage(code, words, draw) {
  if (!code || !words) return draw();
  globalThis.brickworksLang = { code, locale: code, say: (english) => words[english] ?? english };
  try {
    return draw();
  } finally {
    delete globalThis.brickworksLang;
  }
}

/// [page] with [plan]'s cards and challenge written in, in [code]'s
/// language; [copied] the pictures' copies.
export function filled(page, code, plan, copied) {
  const words = code ? wordsOf(page) : null;
  let text = page;
  for (const tab of TABS) {
    const marker = new RegExp(`<!--shelf:${tab}-->[\\s\\S]*?<!--/shelf:${tab}-->`);
    if (!marker.test(text)) throw new Error(`the shelf's ${tab} has no <!--shelf:${tab}--> markers`);
    const cards = plan.cards[tab] || [];
    // A tab with nothing to show keeps what it holds (the top's skeletons).
    if (!cards.length) continue;
    const html = inLanguage(code, words, () => cards.map((m, i) => {
      const shownFirst = tab === plan.first;
      let card = cardHtml(m, { eager: shownFirst && i < EAGER, pick: shownFirst && i === 0 && m.id === plan.pick });
      const src = pictureOf(m);
      if (copied.has(src)) card = card.replace(`src="${escapeHtml(src)}"`, `src="${copied.get(src)}" data-from="${escapeHtml(src)}"`);
      return card;
    }).join(""));
    text = text.replace(marker, `<!--shelf:${tab}-->${html}<!--/shelf:${tab}-->`);
  }
  if (plan.first) {
    // The tab shown, and the rest at hand.
    for (const tab of TABS) {
      const on = tab === plan.first;
      const ours = plan.tabs.includes(tab);
      text = text.replace(new RegExp(`<button type="button" role="tab" id="tab-${tab}"[^>]*>`), (button) => button
        .replace(/ aria-selected="(true|false)"/, ` aria-selected="${on}"`)
        .replace(/ tabindex="-1"/, "").replace(/ hidden/, "")
        .replace(/>$/, `${on ? "" : ' tabindex="-1"'}${ours ? "" : " hidden"}>`));
      text = text.replace(new RegExp(`(<div class="models scroller" id="shelf-${tab}" role="tabpanel"[^>]*?)( hidden)?(\\s*\\n?\\s*data-ask=)`),
        (all, start, _hidden, rest) => `${start}${on ? "" : " hidden"}${rest}`);
    }
    const all = new RegExp(`id="shelf-${plan.first}"[^>]*data-all="([^"]*)"`).exec(text)?.[1] || "/gallery";
    text = text.replace(/<a id="shelf-all" href="[^"]*">/, `<a id="shelf-all" href="${code ? `/${code}` : ""}${all}">`);
    text = text.replace('<div class="shelf" id="shelf" data-shelf="skeleton">', '<div class="shelf" id="shelf" data-shelf="served">');
  }
  // The marks nearly every card carries are not said (web/card.js
  // quietPage, which the gallery's cards run as they are drawn).
  const quiet = quietMarks(Object.values(plan.cards).flat().map(marksOf));
  if (quiet) text = text.replace(/<body>/, `<body data-quiet="${quiet}">`);
  const c = plan.challenge;
  if (c) {
    // Its maker's words, as written (English): marked so; its days in the page's.
    text = text.replace(/<h2 id="challenge-h">[^<]*<\/h2>/, `<h2 id="challenge-h" lang="en">${escapeHtml(c.title)}</h2>`);
    if (c.brief) text = text.replace(/<p id="challenge-brief">[^<]*<\/p>/, `<p id="challenge-brief" lang="en">${escapeHtml(c.brief)}</p>`);
    const span = days(c.starts_on, c.ends_on, code || "en-GB");
    if (span) text = text.replace(/<p class="note" id="challenge-days">[^<]*<\/p>/, `<p class="note" id="challenge-days">${escapeHtml(span)}</p>`);
  }
  return text;
}

async function main() {
  if (!out || !existsSync(join(out, "index.html"))) {
    console.error("home_shelf: give the site's folder (tools/site.py OUT), with its index.html");
    process.exit(2);
  }
  const english = readFileSync(join(out, "index.html"), "utf8");
  const asks = Object.fromEntries(TABS.map((tab) => [tab,
    (new RegExp(`id="shelf-${tab}"[^>]*data-ask="([^"]*)"`).exec(english)?.[1] || "").replace(/&amp;/g, "&")]));
  const wanted = [...Object.values(asks).filter(Boolean), "/api/share?op=shelves"];
  const kept = existsSync(SNAPSHOT) ? JSON.parse(readFileSync(SNAPSHOT, "utf8")) : { answers: {} };
  const answers = {};
  const said = [];
  for (const path of wanted) {
    const live = args.offline ? null : await ask(path);
    answers[path] = live || kept.answers?.[path] || null;
    said.push(`${path.replace("/api/share?op=", "")}: ${live ? "live" : answers[path] ? `kept (${kept.at || "?"})` : "none"}`);
  }
  answers.shelves = answers["/api/share?op=shelves"];
  const plan = decide(asks, answers);
  if (args.save && !args.offline) {
    // Only what a first screen shows: each list's first models, the pick and the challenge.
    const kept = (path, answer) => (path === "/api/share?op=shelves" ? { pick: answer.pick || null, challenge: answer.challenge || null }
      : { models: (answer.models || []).slice(0, CARDS + 2) });
    const keep = Object.fromEntries(wanted.filter((path) => answers[path]).map((path) => [path, kept(path, answers[path])]));
    writeFileSync(SNAPSHOT, `${JSON.stringify({ at: new Date().toISOString().slice(0, 10), answers: keep }, null, 1)}\n`);
  }
  const all = Object.values(plan.cards).flat();
  const copied = args.offline ? new Map() : await copyPictures(all, join(out, "img/home"));
  let pages = 0;
  for (const code of LANGS) {
    const where = join(out, code, "index.html");
    if (!existsSync(where)) continue;
    writeFileSync(where, filled(readFileSync(where, "utf8"), code, plan, copied));
    pages += 1;
  }
  console.log(`home_shelf: ${plan.first ? `${plan.tabs.join(", ")} (${plan.first} first${plan.pick ? `, the pick ${plan.pick}` : ""})`
    : "NOTHING to show: the skeletons stay, and web/landing.js asks"}; ${all.length} cards, ${copied.size} pictures copied; `
    + `${plan.challenge ? `the challenge "${plan.challenge.title}"` : "no challenge"}; ${pages} pages; ${said.join(", ")}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
