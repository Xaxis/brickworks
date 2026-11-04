// Does the landing page hold together in a browser?
//
//   node tools/web/landing_check.mjs --url=https://brickworks.diy
//   node tools/web/landing_check.mjs --file=web/index.html
//
// The deploy asked the landing page for its status code and nothing
// else, so it could only catch a page that was missing. What it missed
// for as long as the page has existed: five header links are 405px wide
// in a 358px bar and the nav does not wrap, so on a phone the document
// came out 566px wide and the whole page scrolled sideways. A status
// code cannot see that. A browser at 390px can.
//
// And the strip of the gallery's Top, in the community (#top, web/landing.js),
// at both widths in light and dark: shown with every card's picture drawn
// when the gallery has three models with pictures, else hidden, never an
// empty box. Its seven pictures never loaded, so it never showed, for as
// long as it had been on the page (walk180, 2026-10-23). With --file there
// is no gallery behind the page, and the strip must stay hidden. --out=DIR
// keeps a picture of it at each width and theme. Then the four real sets,
// the month's challenge, and the first model of Made in Brickworks in 3D
// (landing, 2026-11-03).
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";
import { serveDir } from "./static_server.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
// A file is served from its directory over http, not opened as a file: the
// page names its stylesheet and pictures from the root (/site.css), which
// file:// would look for at the top of the disk, and an unstyled page
// measures nothing anyone sees.
const file = resolve(args.file || "web/index.html");
const site = args.url ? null : await serveDir(dirname(file));
const target = args.url || `${site.url}/${basename(file)}`;
const bypass = process.env.VERCEL_BYPASS;

const out = args.out ? resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });

const browser = await launch({ signedOut: true });  // a page of the site, not the app
const problems = [];

// A phone first, because that is where it was broken, then a laptop.
for (const [label, width, height] of [["phone", 390, 844], ["laptop", 1280, 900]]) {
  const page = await browser.newPage({ viewport: { width, height } });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  const response = await page.goto(target, { waitUntil: "load", timeout: 45000 });
  if (response && !response.ok()) {
    problems.push(`${label}: the page answered ${response.status()}`);
    await page.close();
    continue;
  }

  const seen = await page.evaluate(() => {
    const doc = document.documentElement;
    const wide = [];
    for (const el of document.querySelectorAll("body *")) {
      const r = el.getBoundingClientRect();
      if (r.width > 0 && r.right > doc.clientWidth + 1) {
        wide.push(el.tagName.toLowerCase()
          + (el.className ? "." + String(el.className).split(" ")[0] : ""));
      }
    }
    return {
      scrollW: doc.scrollWidth,
      clientW: doc.clientWidth,
      wide: [...new Set(wide)].slice(0, 4),
      // The one thing every visitor must be able to do.
      intoTheApp: [...document.querySelectorAll('a[href="/app"]')]
        .filter((a) => a.getBoundingClientRect().width > 0).length,
      h1: (document.querySelector("h1") || {}).textContent || "",
    };
  });

  if (seen.scrollW > seen.clientW + 1) {
    problems.push(`${label}: the page scrolls sideways — ${seen.scrollW}px of `
      + `content in ${seen.clientW}px, from ${seen.wide.join(", ") || "something"}`);
  }
  if (seen.intoTheApp < 1) {
    problems.push(`${label}: nothing visible links to /app`);
  }
  if (!seen.h1.trim()) {
    problems.push(`${label}: no heading`);
  }
  console.log(`  ${label.padEnd(7)} ${seen.scrollW}px in ${seen.clientW}px, `
    + `${seen.intoTheApp} way${seen.intoTheApp === 1 ? "" : "s"} into the app`);
  await page.close();
  for (const theme of ["light", "dark"]) await strip(label, width, height, theme);
  await setsStrip(label, width, height);
  await challengeTile(label, width, height);
  await made(label, width, height);
}

/// Real sets, ready to open: every picture a set LDraw has a 3D model of,
/// its page offering to build it in 3D. Asked by size alone, 7 of its 8
/// cards had no model and opened only as parts (the owner, 2026-11-01).
/// Four, or none and the tile's glyph.
async function setsStrip(label, width, height) {
  const page = await browser.newPage({ viewport: { width, height } });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  await page.goto(target, { waitUntil: "load", timeout: 45000 });
  await page.evaluate(() => document.getElementById("sets")?.scrollIntoView({ block: "center" }));
  const settled = await page.waitForFunction(() => document.documentElement.dataset.sets, null, { timeout: 30000 })
    .then(() => true, () => false);
  const seen = await page.evaluate(async () => {
    const cards = [...document.querySelectorAll("#sets-models a")];
    const opened = await Promise.all(cards.map(async (card) => {
      const href = card.getAttribute("href") || "";
      let build = false;
      try {
        const reply = await fetch(href, { headers: { accept: "text/html" } });
        build = reply.ok && /data-build3d/.test(await reply.text());
      } catch { /* no page */ }
      return { href, model3d: card.dataset.model3d === "yes", build };
    }));
    const drawn = cards.filter((card) => card.querySelector("img")?.naturalWidth > 0).length;
    const glyph = Boolean(document.querySelector("#sets-models > .glyph"));
    return { said: document.documentElement.dataset.sets || "", opened, drawn, glyph };
  });
  const where = `${label} sets`;
  if (!settled) {
    problems.push(`${where}: the sets never settled (no data-sets after 30 s)`);
  } else if (seen.said === "none") {
    if (!seen.glyph || seen.opened.length) problems.push(`${where}: said none but shows ${seen.opened.length} sets and ${seen.glyph ? "its" : "no"} glyph`);
  } else {
    if (seen.opened.length !== 4 || seen.drawn !== 4) problems.push(`${where}: ${seen.opened.length} sets, ${seen.drawn} pictures drawn, of 4`);
    for (const one of seen.opened) {
      if (!one.model3d) problems.push(`${where}: ${one.href} has no 3D model, so it opens only as parts`);
      else if (!one.build) problems.push(`${where}: ${one.href} has no Build it in 3D`);
    }
  }
  const good = seen.opened.filter((one) => one.model3d && one.build).length;
  console.log(`  ${where.padEnd(13)} ${seen.said === "none" ? "hidden" : `${good} of ${seen.opened.length} cards open in 3D`}`);
  await page.close();
}

/// This month's challenge, as the challenge page has it: its name and days
/// once there is one open (or the next told), else the tile's own words.
async function challengeTile(label, width, height) {
  const page = await browser.newPage({ viewport: { width, height } });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  await page.goto(target, { waitUntil: "load", timeout: 45000 });
  await page.evaluate(() => document.getElementById("community")?.scrollIntoView({ block: "start" }));
  const settled = await page.waitForFunction(() => document.documentElement.dataset.challenge, null, { timeout: 30000 })
    .then(() => true, () => false);
  const seen = await page.evaluate(async () => {
    let asked = null;
    try {
      const reply = await fetch("/api/people?op=challenge", { headers: { accept: "application/json" } });
      if (reply.ok) asked = await reply.json();
    } catch { /* no server behind the page */ }
    const open = asked?.challenge?.state === "open" && !asked.challenge.test;
    return {
      said: document.documentElement.dataset.challenge || "",
      name: document.getElementById("challenge-h")?.textContent.trim() || "",
      days: document.getElementById("challenge-days")?.hidden ? "" : document.getElementById("challenge-days")?.textContent.trim() || "",
      want: open ? asked.challenge.title : asked?.next && !asked.next.test ? asked.next.title : "",
    };
  });
  const where = `${label} challenge`;
  if (!settled) problems.push(`${where}: never settled (no data-challenge after 30 s)`);
  else if (seen.want && seen.name !== seen.want) problems.push(`${where}: shows "${seen.name}" for "${seen.want}"`);
  else if (seen.want && !seen.days) problems.push(`${where}: "${seen.name}" without its days`);
  else if (!seen.want && (seen.said !== "none" || !seen.name)) problems.push(`${where}: said ${seen.said} with "${seen.name}" and none asked`);
  console.log(`  ${where.padEnd(13)} ${seen.said}: ${seen.name}${seen.days ? `, ${seen.days}` : ""}`);
  await page.close();
}

/// Made in Brickworks: its five pictures drawn, and its first model in 3D
/// in its picture's place once pressed (with a gallery behind the page;
/// without one, the view says it could not come and the picture stays).
async function made(label, width, height) {
  const page = await browser.newPage({ viewport: { width, height } });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  await page.goto(target, { waitUntil: "load", timeout: 45000 });
  await page.evaluate(() => document.getElementById("made-lead")?.scrollIntoView({ block: "center" }));
  const pictures = await page.evaluate(async () => {
    const imgs = [...document.querySelectorAll("#made .tile img")];
    await Promise.all(imgs.map((img) => { img.loading = "eager"; return img.decode().catch(() => {}); }));
    return { all: imgs.length, drawn: imgs.filter((img) => img.naturalWidth > 0).length };
  });
  const where = `${label} made`;
  if (pictures.all !== 5 || pictures.drawn !== 5) problems.push(`${where}: ${pictures.drawn} of ${pictures.all} pictures drawn, of 5`);
  // The 3D view's code is asked for once the picture is in the window.
  const armed = await page.waitForFunction(() => [...document.styleSheets].some((sheet) => /\/view3d\.css$/.test(sheet.href || "")), null,
    { timeout: 15000 }).then(() => true, () => false);
  await page.waitForTimeout(500);
  await page.locator("#made-lead .picture").click();
  const state = await page.waitForFunction(() => {
    const view = document.querySelector("#made-lead .view3d");
    return view && ["ready", "failed"].includes(view.dataset.state) ? view.dataset.state : false;
  }, null, { timeout: 120000, polling: 500 }).then((h) => h.jsonValue(), () => "none");
  const stayed = page.url() === target || page.url().replace(/\/$/, "") === target.replace(/\/$/, "");
  if (!armed) problems.push(`${where}: the 3D view's looks never came`);
  if (!stayed) problems.push(`${where}: pressing the picture left the page for ${page.url()}`);
  if (state === "none") problems.push(`${where}: pressed, no 3D view came or said why in 120 s`);
  else if (site === null && state !== "ready") problems.push(`${where}: the 3D view ${state}`);
  console.log(`  ${where.padEnd(13)} ${pictures.drawn} of ${pictures.all} pictures, 3D ${state}`);
  await page.close();
}

/// The strip as a visitor meets it: scrolled to, it asks the gallery, and
/// shows its cards only once their pictures are in.
async function strip(label, width, height, theme) {
  const page = await browser.newPage({ viewport: { width, height }, colorScheme: theme });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  await page.goto(target, { waitUntil: "load", timeout: 45000 });
  await page.evaluate(() => document.getElementById("community")?.scrollIntoView({ block: "start" }));
  const settled = await page.waitForFunction(() => document.documentElement.dataset.strip, null, { timeout: 30000 })
    .then(() => true, () => false);
  const seen = await page.evaluate(async () => {
    const made = document.getElementById("top");
    made?.scrollIntoView({ block: "start" });
    const cards = [...document.querySelectorAll("#top-models .model")];
    // What the gallery has to show: Top builds, as the strip asks it.
    let listed = null;
    try {
      const reply = await fetch("/api/share?op=list&page=1&sort=top", { headers: { accept: "application/json" } });
      if (reply.ok) listed = ((await reply.json()).models || []).filter((m) => m && (m.thumb || m.image)).length;
      // Less the five Made in Brickworks already shows.
      listed = Math.max(0, listed - document.querySelectorAll("#made .tile").length);
    } catch { /* no gallery behind the page */ }
    return {
      said: document.documentElement.dataset.strip || "",
      shown: Boolean(made && !made.hidden && made.getBoundingClientRect().height > 0),
      cards: cards.length,
      drawn: cards.filter((card) => {
        const img = card.querySelector(".frame img");
        return img && img.complete && img.naturalWidth > 0 && img.getBoundingClientRect().width > 0;
      }).length,
      named: cards.filter((card) => card.querySelector("a.open b")?.textContent.trim()).length,
      empty: document.querySelectorAll("#top-models .frame.none").length,
      listed,
    };
  });
  const where = `${label} ${theme}`;
  if (!settled) {
    problems.push(`${where}: the strip never settled (no data-strip after 30 s)`);
  } else if (seen.said === "none") {
    // Hidden is honest only when the gallery has fewer than three to show.
    if (seen.shown || seen.cards) problems.push(`${where}: the strip said none but shows ${seen.cards} cards`);
    if (seen.listed !== null && seen.listed >= 3) {
      problems.push(`${where}: the strip stayed hidden with ${seen.listed} models with pictures in the gallery`);
    }
  } else {
    const n = Number(seen.said);
    if (!seen.shown || seen.cards !== n || n < 3) problems.push(`${where}: the strip said ${seen.said} and shows ${seen.cards} cards (${seen.shown ? "shown" : "hidden"})`);
    if (seen.drawn !== seen.cards || seen.empty) problems.push(`${where}: ${seen.drawn} of ${seen.cards} cards' pictures drawn, ${seen.empty} with none`);
    if (seen.named !== seen.cards) problems.push(`${where}: ${seen.named} of ${seen.cards} cards named`);
  }
  if (out && seen.shown) {
    await page.locator("#top").screenshot({ path: `${out}/strip_${width}_${theme}.png` });
  }
  console.log(`  ${where.padEnd(13)} strip ${seen.said === "none" ? "hidden" : `of ${seen.cards} cards, ${seen.drawn} pictures drawn`}`
    + `${seen.listed === null ? ", no gallery behind the page" : `, ${seen.listed} in the gallery with pictures`}`);
  await page.close();
}

await browser.close();
if (site) site.close();
if (problems.length) {
  for (const p of problems) console.log(`  FAIL  ${p}`);
  process.exit(1);
}
console.log("  the landing page holds together");
