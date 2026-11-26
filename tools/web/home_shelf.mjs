// The home page's first posts, written into the page as it is served
// (homefeed, 2026-11-23; landing's shelf before it): the feed's first
// FIRST posts, real models with their pictures, Talk's threads with their
// latest reply and the month's challenge with its entries, drawn as
// web/home-feed.js draws them in the browser.
//
//   node tools/web/home_shelf.mjs OUT [--from=https://brickworks.diy] [--save] [--offline]
//
// OUT is the site put together (tools/site.py OUT): its index.html and each
// language's (OUT/de/index.html, ...). tools/deploy.sh runs it after
// tools/site.py. Each of the feed's answers (ASKS, as web/landing.js asks
// them for somebody signed out) is asked of --from; what cannot be read
// there is read from web/_home.json, the answers kept the last time --save
// was given, so a deploy never ships a first screen that waits on the
// server. --offline reads web/_home.json alone (tests, a checkout's look).
//
// Each post is the site's own (web/home-feed.js postHtml), in the page's
// language from the words its copy carries (#site-words); each picture of a
// model in them is copied into OUT/img/home/, so the first screen's pictures
// come from the CDN beside the page and never wait on a function or the
// bucket. web/landing.js asks each answer again once the page is in, tells
// each post its counts as they are now and puts in the rest under them.
//
// It changes nothing it cannot fill: a page without the feed's markers is
// refused and said; nothing to show leaves the skeletons, and says so.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { escapeHtml, pictureOf } from "../../web/card.js";
import { EAGER, FIRST, compose, postHtml } from "../../web/home-feed.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const SNAPSHOT = join(ROOT, "web/_home.json");
const LANGS = ["", "de", "fr", "es"];
/// What the feed is made of, as web/landing.js feeds() asks it signed out.
export const ASKS = {
  top: "/api/share?op=list&page=1&sort=top",
  newest: "/api/share?op=list&page=1&sort=newest",
  shelves: "/api/share?op=shelves",
  challenge: "/api/people?op=challenge",
  talk: "/api/people?op=talk_latest&n=6&reply=1&talking=24",
  latest: "/api/people?op=latest",
};
export { EAGER, FIRST };

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

/// The feed's first posts from [given] (each of ASKS's answers, by name):
/// what web/landing.js would draw first for somebody signed out.
export function decide(given) {
  return compose(given, { tab: "foryou" }).slice(0, FIRST);
}

/// Every picture of a model in [items]: the builds', the studio's to try
/// and the challenge's entries'.
export function picturesOf(items) {
  const models = items.flatMap((item) => (item.kind === "build" || item.kind === "try" ? [item.model]
    : item.kind === "challenge" ? (item.entries || []).slice(0, 4) : []));
  return [...new Set(models.map((m) => pictureOf(m)).filter((src) => src.startsWith("/")))];
}

/// Where a picture of the site is copied to under img/home/, by its address.
const copyName = (src) => `${src.replace(/^\/+/, "").replace(/\?v=/, "-").replace(/[^A-Za-z0-9.-]+/g, "-")}`.replace(/\.webp-/, "-") + (/\.webp$/.test(src) ? "" : ".webp");

/// Each of [wanted] copied into [dir], each its address on the site once
/// copied: a Map of the site's address to the copy's.
async function copyPictures(wanted, dir) {
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
        // Left at its own address: the post still shows it, from the server.
      }
    }
  };
  await Promise.all(Array.from({ length: 6 }, one));
  return copied;
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

const MARKERS = /<!--feed-->[\s\S]*?<!--\/feed-->/;

/// [page] with [items] written in as posts, in [code]'s language; [copied]
/// the pictures' copies.
export function filled(page, code, items, copied) {
  if (!MARKERS.test(page)) throw new Error("the feed has no <!--feed--> markers");
  if (!items.length) return page;
  const words = code ? wordsOf(page) : null;
  let posts = inLanguage(code, words, () => items.map((item, i) => postHtml(item, { eager: i < EAGER })).join("\n"));
  for (const [src, copy] of copied) posts = posts.replaceAll(`src="${escapeHtml(src)}"`, `src="${copy}" data-from="${escapeHtml(src)}"`);
  return page.replace(MARKERS, () => `<!--feed-->${posts}<!--/feed-->`)
    .replace('<div class="stream" id="stream" data-stream="skeleton"', '<div class="stream" id="stream" data-stream="served"');
}

/// Only what a first screen and its posts show, of each answer, to keep.
function kept(name, answer) {
  if (name === "top" || name === "newest") return { models: (answer.models || []).slice(0, FIRST + 4) };
  if (name === "shelves") return { pick: answer.pick || null, challenge: answer.challenge || null, prompt_now: answer.prompt_now || null };
  if (name === "challenge") {
    const c = answer.challenge;
    return { ready: answer.ready, challenge: c ? { ...c, groups: (c.groups || []).map((g) => ({ ...g, entries: (g.entries || []).slice(0, 4) })) } : null,
      prompt_now: answer.prompt_now || null };
  }
  if (name === "talk") return { ready: answer.ready, threads: (answer.threads || []).slice(0, 4), talking: (answer.talking || []).slice(0, 12) };
  if (name === "latest") return { models: [], photos: (answer.photos || []).slice(0, 2), designers: (answer.designers || []).slice(0, 4) };
  return answer;
}

async function main() {
  if (!out || !existsSync(join(out, "index.html"))) {
    console.error("home_shelf: give the site's folder (tools/site.py OUT), with its index.html");
    process.exit(2);
  }
  const snapshot = existsSync(SNAPSHOT) ? JSON.parse(readFileSync(SNAPSHOT, "utf8")) : { answers: {} };
  const given = {};
  const said = [];
  for (const [name, path] of Object.entries(ASKS)) {
    const live = args.offline ? null : await ask(path);
    given[name] = live || snapshot.answers?.[path] || null;
    said.push(`${name}: ${live ? "live" : given[name] ? `kept (${snapshot.at || "?"})` : "none"}`);
  }
  const items = decide(given);
  if (args.save && !args.offline) {
    const keep = Object.fromEntries(Object.entries(ASKS).filter(([name]) => given[name]).map(([name, path]) => [path, kept(name, given[name])]));
    writeFileSync(SNAPSHOT, `${JSON.stringify({ at: new Date().toISOString().slice(0, 10), answers: keep }, null, 1)}\n`);
  }
  const copied = args.offline ? new Map() : await copyPictures(picturesOf(items), join(out, "img/home"));
  let pages = 0;
  for (const code of LANGS) {
    const where = join(out, code, "index.html");
    if (!existsSync(where)) continue;
    writeFileSync(where, filled(readFileSync(where, "utf8"), code, items, copied));
    pages += 1;
  }
  const kinds = items.map((item) => item.kind).join(", ");
  console.log(`home_shelf: ${items.length ? `${items.length} posts (${kinds})` : "NOTHING to show: the skeletons stay, and web/landing.js asks"}; `
    + `${copied.size} pictures copied; ${pages} pages; ${said.join(", ")}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
