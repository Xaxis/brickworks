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
// Then the first screen as a visitor opens it (landing, 2026-11-22,
// docs/HOME.md), at a phone's 390 x 844 and a laptop's 1280 x 800, light
// and dark: the search and Start building whole in the window, and the
// shelf's real models with their pictures drawn, at least one whole in
// the window; the page moving not at all (CLS 0.01 at most) as the shelf's
// live answer comes. Its tabs by press and by arrow, each showing its own
// cards and See all going to its own list. The search finding as it is
// typed (models, builders and sets, then the gallery's and the sets' own
// search), its arrows and Escape, and Enter sending it to the gallery.
// The month's challenge as the gallery's front has it; the talk's place
// shown only with talk in it; the four real sets.
//
// With --file there is no gallery behind the page and no deploy wrote its
// cards in: the shelf must take itself away, never stand empty. --out=DIR
// keeps a picture of the first screen at each size and theme.
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
const bypass = process.env.VERCEL_BYPASS || process.env.BW_BYPASS;
// A gallery behind the page: a deploy's, or a preview's.
const live = site === null;
// As web/landing.js: the fewest cards worth a tab.
const FEWEST = 4;

const out = args.out ? resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });

const browser = await launch({ signedOut: true });  // a page of the site, not the app
const problems = [];

async function open(width, height, { theme = "light" } = {}) {
  const phone = width < 600;
  const page = await browser.newPage({ viewport: { width, height }, colorScheme: theme, isMobile: phone, hasTouch: phone });
  if (bypass) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  // Every layout shift no press made, and where it came from.
  await page.addInitScript(() => {
    window.__shifts = [];
    try {
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) window.__shifts.push({ at: Math.round(entry.startTime), value: entry.value,
            from: (entry.sources || []).map((s) => s.node?.id || s.node?.className || s.node?.nodeName || "?").join(" ") });
        }
      }).observe({ type: "layout-shift", buffered: true });
    } catch { /* no layout-shift entries in this browser */ }
  });
  const response = await page.goto(target, { waitUntil: "load", timeout: 45000 });
  return { page, response };
}

/// What [path] answers the page's own origin, read from inside [page].
const asked = (page, path) => page.evaluate(async (where) => {
  try {
    const reply = await fetch(where, { headers: { accept: "application/json" } });
    return reply.ok ? await reply.json() : null;
  } catch {
    return null;
  }
}, path);

// A phone first, because that is where it was broken, then a laptop.
for (const [label, width, height] of [["phone", 390, 844], ["laptop", 1280, 800]]) {
  const { page, response } = await open(width, height);
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
      if (r.width > 0 && r.right > doc.clientWidth + 1 && !el.closest(".scroller")) {
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
  for (const theme of ["light", "dark"]) await firstScreen(label, width, height, theme);
  await tabs(label, width, height);
  await search(label, width, height);
  await challengeTile(label, width, height);
  await talk(label, width, height);
  await setsStrip(label, width, height);
}

/// The first screen as it opens: the search and Start building whole in
/// the window, the shelf's models with their pictures drawn, and nothing
/// moving as the shelf's live answer comes.
async function firstScreen(label, width, height, theme) {
  const { page } = await open(width, height, { theme });
  const where = `${label} ${theme}`;
  const settled = await page.waitForFunction(() => document.documentElement.dataset.shelfLive, null, { timeout: 30000 })
    .then(() => true, () => false);
  await page.waitForTimeout(1000);
  const seen = await page.evaluate(() => {
    const whole = (el) => {
      if (!el) return false;
      const r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && r.top >= 0 && r.bottom <= innerHeight && r.left >= 0 && r.right <= innerWidth;
    };
    const shelf = document.getElementById("shelf");
    const panel = shelf?.querySelector('[role="tabpanel"]:not([hidden])');
    const cards = [...(panel?.querySelectorAll(":scope > .model") || [])];
    const drawn = (card) => {
      const img = card.querySelector(".frame img");
      return Boolean(img && img.complete && img.naturalWidth > 0);
    };
    // A card in the window: the rest of the row is lazy, asked for as it is scrolled to.
    const seen = (card) => {
      const r = card.getBoundingClientRect();
      return r.right > 0 && r.left < innerWidth && r.bottom > 0 && r.top < innerHeight;
    };
    const pictures = cards.filter((card) => drawn(card) && whole(card.querySelector(".frame img"))).length;
    return {
      said: document.documentElement.dataset.shelfLive || "",
      served: shelf?.dataset.shelf || "",
      shown: Boolean(shelf && !shelf.hidden && shelf.getBoundingClientRect().height > 0),
      cards: cards.length,
      inView: cards.filter(seen).length,
      drawn: cards.filter((card) => !seen(card) || drawn(card)).length,
      named: cards.filter((card) => card.querySelector("a.open b")?.textContent.trim()).length,
      skeletons: panel?.querySelectorAll(".skeleton-card").length || 0,
      pictures,
      search: whole(document.getElementById("find-q")),
      start: whole(document.querySelector('#home a[href^="/app"]')),
      shifts: window.__shifts || [],
    };
  });
  const moved = seen.shifts.reduce((sum, s) => sum + s.value, 0);
  if (!settled) problems.push(`${where}: the shelf never settled (no data-shelf-live after 30 s)`);
  if (!seen.search) problems.push(`${where}: the search is not whole in the first screen`);
  if (!seen.start) problems.push(`${where}: Start building is not whole in the first screen`);
  if (seen.shown) {
    if (seen.cards < FEWEST || seen.drawn !== seen.cards || seen.named !== seen.cards || seen.skeletons) {
      problems.push(`${where}: the shelf shows ${seen.cards} cards, ${seen.drawn} pictures drawn, ${seen.named} named, ${seen.skeletons} skeletons`);
    }
    if (seen.pictures < 1) problems.push(`${where}: no model's picture is whole in the first screen`);
  } else if (live) {
    problems.push(`${where}: the shelf is not shown with a gallery behind the page (${seen.said})`);
  }
  // A page with cards written in moves nothing as the live ones come; one
  // without (a checkout's) takes the shelf away, which may.
  if (seen.served === "served" && moved > 0.01) {
    problems.push(`${where}: the first screen moved ${moved.toFixed(3)} as it came (${seen.shifts.map((s) => `${s.value.toFixed(3)}@${s.at} ${s.from}`).join("; ")})`);
  }
  if (out) await page.screenshot({ path: `${out}/first_${width}_${theme}.png` });
  console.log(`  ${where.padEnd(13)} shelf ${seen.shown ? `${seen.cards} cards (${seen.served}, then ${seen.said}), ${seen.inView} in view, ${seen.pictures} whole` : `hidden (${seen.said})`}; `
    + `search ${seen.search ? "in view" : "OUT"}, Start building ${seen.start ? "in view" : "OUT"}; moved ${moved.toFixed(3)}`);
  await page.close();
}

/// Each tab by press and by arrow: its own panel and cards, See all to its list.
async function tabs(label, width, height) {
  const { page } = await open(width, height);
  const where = `${label} tabs`;
  await page.waitForFunction(() => document.documentElement.dataset.shelfLive, null, { timeout: 30000 }).catch(() => null);
  if (!(await page.evaluate(() => Boolean(document.getElementById("shelf")) && !document.getElementById("shelf").hidden))) {
    if (live) problems.push(`${where}: no shelf to try`);
    console.log(`  ${where.padEnd(13)} no shelf`);
    await page.close();
    return;
  }
  const state = () => page.evaluate(() => {
    const on = document.querySelector('#shelf [role="tab"][aria-selected="true"]');
    const panels = [...document.querySelectorAll('#shelf [role="tabpanel"]')].filter((p) => !p.hidden);
    const cards = [...(panels[0]?.querySelectorAll(":scope > .model") || [])];
    // The cards in the window drawn; the rest of the row is lazy.
    const seen = (card) => {
      const r = card.getBoundingClientRect();
      return r.right > 0 && r.left < innerWidth && r.bottom > 0 && r.top < innerHeight;
    };
    return { tab: on?.id || "", focused: document.activeElement?.id || "", panels: panels.map((p) => p.id),
      live: panels[0]?.dataset.live || "", cards: cards.length,
      drawn: cards.filter((c) => !seen(c) || c.querySelector(".frame img")?.naturalWidth > 0).length,
      all: document.getElementById("shelf-all")?.getAttribute("href") || "", want: panels[0]?.dataset.all || "" };
  });
  const settle = () => page.waitForFunction(() => {
    const panel = [...document.querySelectorAll('#shelf [role="tabpanel"]')].find((p) => !p.hidden);
    return panel && panel.dataset.live && panel.dataset.live !== "asking";
  }, null, { timeout: 30000 }).catch(() => null);
  const drawnInView = () => page.waitForFunction(() => {
    const panel = [...document.querySelectorAll('#shelf [role="tabpanel"]')].find((p) => !p.hidden);
    return [...(panel?.querySelectorAll(":scope > .model") || [])].every((card) => {
      const r = card.getBoundingClientRect();
      const inView = r.right > 0 && r.left < innerWidth && r.bottom > 0 && r.top < innerHeight;
      return !inView || card.querySelector(".frame img")?.naturalWidth > 0;
    });
  }, null, { timeout: 20000 }).catch(() => null);
  await page.locator("#tab-new").click();
  await settle();
  await drawnInView();
  const pressed = await state();
  if (pressed.tab !== "tab-new" || pressed.panels.join() !== "shelf-new") problems.push(`${where}: pressing New shows ${pressed.panels.join(", ")} (${pressed.tab} selected)`);
  if (live && (pressed.cards < FEWEST || pressed.drawn !== pressed.cards)) problems.push(`${where}: New shows ${pressed.cards} cards, ${pressed.drawn} drawn`);
  if (!pressed.all.endsWith(pressed.want)) problems.push(`${where}: See all goes to ${pressed.all} on New, not ${pressed.want}`);
  await page.locator("#tab-new").focus();
  await page.keyboard.press("ArrowRight");
  await settle();
  await drawnInView();
  const arrowed = await state();
  if (arrowed.tab !== "tab-sets" || arrowed.focused !== "tab-sets" || arrowed.panels.join() !== "shelf-sets") {
    problems.push(`${where}: the right arrow from New left ${arrowed.tab} selected, ${arrowed.focused} focused, ${arrowed.panels.join(", ")} shown`);
  }
  if (live && (arrowed.cards < FEWEST || arrowed.drawn !== arrowed.cards)) problems.push(`${where}: the sets tab shows ${arrowed.cards} cards, ${arrowed.drawn} drawn`);
  if (!arrowed.all.endsWith(arrowed.want)) problems.push(`${where}: See all goes to ${arrowed.all} on the sets, not ${arrowed.want}`);
  console.log(`  ${where.padEnd(13)} New ${pressed.cards} cards (${pressed.live}), see all ${pressed.all}; → ${arrowed.tab} ${arrowed.cards} cards, see all ${arrowed.all}`);
  await page.close();
}

/// The search as it is typed, its arrows and Escape, and Enter sending it
/// to the gallery's own.
async function search(label, width, height) {
  const { page } = await open(width, height);
  const where = `${label} search`;
  await page.locator("#find-q").click();
  await page.keyboard.type("castle", { delay: 40 });
  const listed = await page.waitForFunction(() => {
    const list = document.getElementById("find-list");
    return list && !list.hidden && list.querySelectorAll('[role="option"]').length ? true : false;
  }, null, { timeout: 20000 }).then(() => true, () => false);
  const seen = await page.evaluate(() => {
    const options = [...document.querySelectorAll('#find-list [role="option"]')];
    return { options: options.length, kinds: [...document.querySelectorAll("#find-list .kind")].map((k) => k.textContent.trim()),
      expanded: document.getElementById("find-q").getAttribute("aria-expanded"),
      last: options.map((o) => o.getAttribute("href")).slice(-2) };
  });
  if (!listed) problems.push(`${where}: typing "castle" listed nothing in 20 s`);
  else {
    if (seen.expanded !== "true") problems.push(`${where}: the list is open but the field says aria-expanded=${seen.expanded}`);
    if (live && !seen.kinds.length) problems.push(`${where}: "castle" found no models, builders or sets`);
    if (!/\/gallery\?q=castle$/.test(seen.last[0] || "") || !/\/library\?q=castle$/.test(seen.last[1] || "")) problems.push(`${where}: its last rows go to ${seen.last.join(", ")}`);
  }
  await page.keyboard.press("ArrowDown");
  const moved = await page.evaluate(() => {
    const id = document.getElementById("find-q").getAttribute("aria-activedescendant");
    return id && document.getElementById(id)?.getAttribute("aria-selected") === "true" ? id : "";
  });
  if (listed && moved !== "find-0") problems.push(`${where}: the down arrow moved to "${moved}", not the first row`);
  await page.keyboard.press("Escape");
  const closed = await page.evaluate(() => document.getElementById("find-list").hidden);
  if (listed && !closed) problems.push(`${where}: Escape left the list open`);
  await Promise.all([page.waitForURL(/\/gallery\?q=castle$/, { timeout: 15000 }).catch(() => null), page.keyboard.press("Enter")]);
  const went = page.url();
  if (!/\/gallery\?q=castle$/.test(went)) problems.push(`${where}: Enter went to ${went}`);
  console.log(`  ${where.padEnd(13)} ${seen.options} rows (${seen.kinds.join(", ") || "only the searches"}), down ${moved || "nothing"}, Escape ${closed ? "closed" : "OPEN"}, Enter ${went.replace(/^https?:\/\/[^/]+/, "")}`);
  await page.close();
}

/// This month's challenge, as the gallery's front has it: its name and days
/// once there is one open (or the next told), else the tile's own words.
async function challengeTile(label, width, height) {
  const { page } = await open(width, height);
  const settled = await page.waitForFunction(() => document.documentElement.dataset.challenge, null, { timeout: 30000 })
    .then(() => true, () => false);
  const front = await asked(page, "/api/share?op=shelves");
  const c = front?.challenge && !front.challenge.test && ["open", "upcoming"].includes(front.challenge.state) ? front.challenge : null;
  const seen = await page.evaluate(() => {
    const r = document.getElementById("challenge")?.getBoundingClientRect();
    return {
      said: document.documentElement.dataset.challenge || "",
      name: document.getElementById("challenge-h")?.textContent.trim() || "",
      days: document.getElementById("challenge-days")?.textContent.trim() || "",
      left: document.getElementById("challenge-left")?.hidden ? "" : document.getElementById("challenge-left")?.textContent.trim() || "",
      foot: r ? Math.round(r.bottom + scrollY) : 0,
    };
  });
  const where = `${label} challenge`;
  if (!settled) problems.push(`${where}: never settled (no data-challenge after 30 s)`);
  else if (c && seen.name !== c.title) problems.push(`${where}: shows "${seen.name}" for "${c.title}"`);
  else if (c && c.state === "open" && (!seen.days || !seen.left)) problems.push(`${where}: "${seen.name}" without its days (${seen.days}) or what is left (${seen.left})`);
  else if (!c && (seen.said !== "none" || !seen.name)) problems.push(`${where}: said ${seen.said} with "${seen.name}" and none asked`);
  if (seen.foot > 2 * height) problems.push(`${where}: ends ${seen.foot} px down, past the first two screens (${2 * height})`);
  console.log(`  ${where.padEnd(13)} ${seen.said}: ${seen.name}${seen.days ? `, ${seen.days}` : ""}${seen.left ? `, ${seen.left}` : ""}; ends at ${seen.foot} px`);
  await page.close();
}

/// What builders are talking about: shown with three threads or more,
/// each a link; else hidden, never an empty box.
async function talk(label, width, height) {
  const { page } = await open(width, height);
  await page.evaluate(() => {
    const next = document.getElementById("community");
    if (next) scrollTo(0, Math.max(0, next.offsetTop - 2 * innerHeight));
  });
  const settled = await page.waitForFunction(() => document.documentElement.dataset.talk, null, { timeout: 30000 })
    .then(() => true, () => false);
  await page.waitForTimeout(300);
  const answer = await asked(page, "/api/talk?op=latest");
  const seen = await page.evaluate(() => {
    const band = document.getElementById("talk");
    return { said: document.documentElement.dataset.talk || "", shown: Boolean(band && !band.hidden),
      threads: document.querySelectorAll("#talk-latest > li a[href]").length };
  });
  const where = `${label} talk`;
  const has = (answer?.threads || []).length;
  if (!settled) problems.push(`${where}: never settled (no data-talk after 30 s)`);
  else if (seen.shown && seen.threads < 3) problems.push(`${where}: shown with ${seen.threads} threads`);
  else if (!seen.shown && seen.said !== "none") problems.push(`${where}: said ${seen.said} but stayed hidden`);
  else if (has >= 3 && !seen.shown) problems.push(`${where}: hidden with ${has} threads to show`);
  console.log(`  ${where.padEnd(13)} ${seen.shown ? `${seen.threads} threads` : "hidden"} (Talk answers ${answer ? `${has} threads` : "nothing"})`);
  await page.close();
}

/// Real sets, ready to open: every picture a set LDraw has a 3D model of,
/// its page offering to build it in 3D. Asked by size alone, 7 of its 8
/// cards had no model and opened only as parts (the owner, 2026-11-01).
/// Four, or none and the tile's glyph.
async function setsStrip(label, width, height) {
  const { page } = await open(width, height);
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

await browser.close();
if (site) site.close();
if (problems.length) {
  for (const p of problems) console.log(`  FAIL  ${p}`);
  process.exit(1);
}
console.log("  the landing page holds together");
