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
// Then the first screen as a visitor opens it (homefeed, 2026-11-23,
// docs/HOME.md; landing's shelf before it), at a phone's 390 x 844 and a
// laptop's 1280 x 800, light and dark: the search and Start building whole
// in the window; on a phone the first post's picture begun in it, and on a
// laptop at least 60% of each first-row picture's height in it, real builds
// plainly seen beside the hero (the lead, 2026-11-23), "in it" meaning over
// the beta bar; the pictures drawn; the page moving not at all (CLS 0.01 at
// most) as the feed's live answers come. And the band's foot in the page's
// rhythm (homefix, 2026-11-23, the owner on its caption sitting on the line
// and the heading under it): at least 24 px from the band's last line (the
// mark's caption, the search's row) down to its edge and from the edge to
// "What builders are making" (48 from 600 px, 24 on a phone), the two the
// same within 8 px.
// Signed out there are no tabs, one stream, and Show more puts more posts
// under it, none twice. The search finding as it is typed (models, builders
// and sets, then the gallery's and the sets' own search), its arrows and
// Escape, and Enter sending it to the gallery. The month's challenge in the
// stream as the gallery's front has it, third at the latest; Talk's threads
// in the stream when Talk has any, never an empty post; the four real sets.
// tools/web/homefeed_check.mjs drives each post's own ways (like, comment,
// follow, 3D, Try it here) and the signed-in tabs.
//
// With --file there is no gallery behind the page and no deploy wrote its
// posts in: the skeletons must give way to words, never stand empty.
// --out=DIR keeps a picture of the first screen at each size and theme.
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
// The fewest posts a first page of the feed has, with a gallery behind it.
const FEWEST = 4;
// The share of each first-row picture's height a laptop's first screen shows.
const SHOWN = 0.6;

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
  await stream(label, width, height);
  await search(label, width, height);
  await challengePost(label, width, height);
  await talk(label, width, height);
  await setsStrip(label, width, height);
}

/// The first screen as it opens: the search and Start building whole in
/// the window, the first post's picture begun in it on a phone and 60% of
/// each first-row picture in it on a laptop (SHOWN), the pictures drawn, and
/// nothing moving as the live answers come.
async function firstScreen(label, width, height, theme) {
  const { page } = await open(width, height, { theme });
  const where = `${label} ${theme}`;
  const settled = await page.waitForFunction(() => document.documentElement.dataset.feedLive, null, { timeout: 30000 })
    .then(() => true, () => false);
  await page.waitForTimeout(1000);
  const seen = await page.evaluate(() => {
    // The window down to the beta bar, docked at its foot (site.css): what
    // is under the bar is not seen.
    const bar = document.querySelector("#beta-bar.shown");
    const foot = bar ? Math.min(innerHeight, bar.getBoundingClientRect().top) : innerHeight;
    const whole = (el) => {
      if (!el) return false;
      const r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && r.top >= 0 && r.bottom <= foot && r.left >= 0 && r.right <= innerWidth;
    };
    const stream = document.getElementById("stream");
    const posts = [...(stream?.querySelectorAll(":scope > .post:not(.skeleton)") || [])];
    const inView = (el) => {
      const r = el.getBoundingClientRect();
      return r.right > 0 && r.left < innerWidth && r.bottom > 0 && r.top < innerHeight;
    };
    // A picture in the window drawn; the rest are lazy, asked for as they near.
    const pictures = posts.flatMap((post) => [...post.querySelectorAll(".post-pic img")]).filter(inView);
    const drawn = (img) => img.complete && img.naturalWidth > 0;
    // The first row: the posts level with the first, each its picture's
    // share of its height over the window's foot.
    const top0 = posts[0] ? posts[0].getBoundingClientRect().top : 0;
    const row = posts.filter((post) => Math.abs(post.getBoundingClientRect().top - top0) < 2)
      .map((post) => post.querySelector(".post-pic img")).filter(Boolean).map((img) => img.getBoundingClientRect());
    const share = (r) => (r.height ? Math.max(0, Math.min(r.bottom, foot) - Math.max(r.top, 0)) / r.height : 0);
    return {
      row: row.length,
      rowShown: row.length ? Math.min(...row.map(share)) : 0,
      firstPicture: row.length ? Math.round(row[0].top) : -1,
      foot: Math.round(foot),
      said: document.documentElement.dataset.feedLive || "",
      served: stream?.dataset.stream || "",
      posts: posts.length,
      kinds: posts.slice(0, 6).map((post) => post.dataset.kind),
      first: posts[0] ? Math.round(posts[0].getBoundingClientRect().top + scrollY) : -1,
      pictures: pictures.length,
      drawn: pictures.filter(drawn).length,
      whole: pictures.filter((img) => drawn(img) && whole(img)).length,
      named: posts.filter((post) => post.querySelector(".post-title")?.textContent.trim()).length,
      skeletons: stream?.querySelectorAll(".skeleton").length || 0,
      words: document.getElementById("stream-said")?.textContent.trim() || "",
      tabs: Boolean(document.getElementById("feed-tabs")?.offsetHeight),
      search: whole(document.getElementById("find-q")),
      // The room under the band's last line and over the feed's heading.
      room: (() => {
        const band = document.getElementById("home")?.getBoundingClientRect();
        const line = document.getElementById("feed")?.getBoundingClientRect().top;
        const heading = document.getElementById("feed-h")?.getBoundingClientRect();
        const last = [...document.querySelectorAll("#home .hero-credit, #home .home-acts, #home .note")]
          .filter((el) => el.offsetHeight).map((el) => el.getBoundingClientRect().bottom);
        return band && heading && last.length ? { under: Math.round(band.bottom - Math.max(...last)), over: Math.round(heading.top - line) } : null;
      })(),
      start: whole(document.querySelector('#home a[href^="/app"]')),
      shifts: window.__shifts || [],
    };
  });
  const moved = seen.shifts.reduce((sum, s) => sum + s.value, 0);
  if (!settled) problems.push(`${where}: the feed never settled (no data-feed-live after 30 s)`);
  if (!seen.search) problems.push(`${where}: the search is not whole in the first screen`);
  if (!seen.room || seen.room.under < 24 || seen.room.over < 24 || Math.abs(seen.room.under - seen.room.over) > 8) {
    problems.push(`${where}: the band's foot is out of the page's rhythm: ${seen.room ? `${seen.room.under} px under its last line, ${seen.room.over} px over the feed's heading` : "not measured"}`);
  }
  if (!seen.start) problems.push(`${where}: Start building is not whole in the first screen`);
  if (seen.tabs) problems.push(`${where}: a visitor is shown the signed-in tabs`);
  if (seen.posts) {
    if (seen.posts < FEWEST || seen.named !== seen.posts || seen.skeletons || seen.drawn !== seen.pictures) {
      problems.push(`${where}: the feed shows ${seen.posts} posts, ${seen.named} named, ${seen.drawn} of ${seen.pictures} pictures in view drawn, ${seen.skeletons} skeletons`);
    }
    if (width < 600 && !(seen.firstPicture >= 0 && seen.firstPicture < seen.foot)) {
      problems.push(`${where}: the first post's picture begins at ${seen.firstPicture} px, not in the first screen (its foot ${seen.foot})`);
    }
    if (width >= 600 && seen.rowShown < SHOWN) {
      problems.push(`${where}: a first-row picture shows ${Math.round(seen.rowShown * 100)}% of its height in the first screen, under ${SHOWN * 100}%`);
    }
  } else if (live) {
    problems.push(`${where}: the feed shows nothing with a gallery behind the page (${seen.said})`);
  } else if (seen.skeletons || !seen.words) {
    problems.push(`${where}: with nothing behind the page the feed shows ${seen.skeletons} skeletons and says "${seen.words}"`);
  }
  // A page with posts written in moves nothing as the live ones come.
  if (seen.served === "served" && moved > 0.01) {
    problems.push(`${where}: the first screen moved ${moved.toFixed(3)} as it came (${seen.shifts.map((s) => `${s.value.toFixed(3)}@${s.at} ${s.from}`).join("; ")})`);
  }
  if (out) await page.screenshot({ path: `${out}/first_${width}_${theme}.png` });
  console.log(`  ${where.padEnd(13)} feed ${seen.posts ? `${seen.posts} posts (${seen.served}, then ${seen.said}: ${seen.kinds.join(" ")}), first at ${seen.first} px, its picture at ${seen.firstPicture} (foot ${seen.foot}), first row's least shown ${Math.round(seen.rowShown * 100)}% of ${seen.row}, ${seen.whole} pictures whole` : `empty (${seen.said}: "${seen.words}")`}; `
    + `search ${seen.search ? "in view" : "OUT"}, Start building ${seen.start ? "in view" : "OUT"}; `
    + `room ${seen.room ? `${seen.room.under}/${seen.room.over} px` : "?"}; moved ${moved.toFixed(3)}`);
  await page.close();
}

/// Signed out, one stream: Show more puts more posts under it, none twice,
/// nothing above it moving.
async function stream(label, width, height) {
  const { page } = await open(width, height);
  const where = `${label} more`;
  await page.waitForFunction(() => document.documentElement.dataset.feedLive, null, { timeout: 30000 }).catch(() => null);
  const keys = () => page.evaluate(() => [...document.querySelectorAll("#stream > .post:not(.skeleton)")]
    .map((post) => `${post.dataset.kind}:${post.dataset.id || post.dataset.thread || post.dataset.photo || ""}`));
  const before = await keys();
  const more = page.locator("#feed-more");
  if (!(await more.isVisible())) {
    if (live && before.length >= 12) problems.push(`${where}: ${before.length} posts and no Show more`);
    console.log(`  ${where.padEnd(13)} ${before.length} posts, no Show more`);
    await page.close();
    return;
  }
  const firstTop = await page.evaluate(() => document.querySelector("#stream > .post")?.getBoundingClientRect().top + scrollY);
  await more.scrollIntoViewIfNeeded();
  await more.click();
  await page.waitForFunction((n) => document.querySelectorAll("#stream > .post:not(.skeleton)").length > n, before.length, { timeout: 20000 }).catch(() => null);
  const after = await keys();
  const twice = after.filter((key, i) => after.indexOf(key) !== i);
  const stillTop = await page.evaluate(() => document.querySelector("#stream > .post")?.getBoundingClientRect().top + scrollY);
  if (after.length <= before.length) problems.push(`${where}: Show more put nothing in (${before.length} posts)`);
  if (twice.length) problems.push(`${where}: posts shown twice: ${[...new Set(twice)].join(", ")}`);
  if (after.slice(0, before.length).join() !== before.join()) problems.push(`${where}: Show more changed the posts above it`);
  if (Math.abs(stillTop - firstTop) > 1) problems.push(`${where}: the first post moved from ${firstTop} to ${stillTop} px`);
  console.log(`  ${where.padEnd(13)} ${before.length} posts, then ${after.length}, ${twice.length} twice`);
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

/// This month's challenge, as the gallery's front has it: its post in the
/// stream, third at the latest, with its name and days once there is one
/// open (or the next told); none at all when there is none.
async function challengePost(label, width, height) {
  const { page } = await open(width, height);
  const settled = await page.waitForFunction(() => document.documentElement.dataset.challenge
    && document.documentElement.dataset.feedLive, null, { timeout: 30000 }).then(() => true, () => false);
  const front = await asked(page, "/api/share?op=shelves");
  const c = front?.challenge && !front.challenge.test && ["open", "upcoming"].includes(front.challenge.state) ? front.challenge : null;
  const seen = await page.evaluate(() => {
    const posts = [...document.querySelectorAll("#stream > .post:not(.skeleton)")];
    return {
      said: document.documentElement.dataset.challenge || "",
      at: posts.findIndex((post) => post.id === "challenge"),
      name: document.getElementById("challenge-h")?.textContent.trim() || "",
      days: document.getElementById("challenge-days")?.textContent.trim() || "",
      left: document.getElementById("challenge-left")?.hidden ? "" : document.getElementById("challenge-left")?.textContent.trim() || "",
      go: document.getElementById("challenge-go")?.getAttribute("href") || "",
    };
  });
  const where = `${label} challenge`;
  if (!settled) problems.push(`${where}: never settled (no data-challenge after 30 s)`);
  else if (c && seen.name !== c.title) problems.push(`${where}: shows "${seen.name}" for "${c.title}"`);
  else if (c && c.state === "open" && (!seen.days || !seen.left)) problems.push(`${where}: "${seen.name}" without its days (${seen.days}) or what is left (${seen.left})`);
  else if (c && (seen.at < 0 || seen.at > 2)) problems.push(`${where}: its post is ${seen.at < 0 ? "not in the stream" : `post ${seen.at + 1}`}, not third at the latest`);
  else if (c && !/\/challenge$/.test(seen.go)) problems.push(`${where}: Enter the challenge goes to "${seen.go}"`);
  else if (!c && (seen.said !== "none" || seen.at >= 0)) problems.push(`${where}: said ${seen.said} with its post at ${seen.at} and none asked`);
  console.log(`  ${where.padEnd(13)} ${seen.said}: ${seen.name}${seen.days ? `, ${seen.days}` : ""}${seen.left ? `, ${seen.left}` : ""}; post ${seen.at + 1}`);
  await page.close();
}

/// Talk's threads in the stream (/api/people?op=talk_latest&reply=1): with
/// Talk applied and threads in it, one in the first page at least, each its
/// title linked to its thread and its latest reply or the ask for one;
/// without, none, and never an empty post.
async function talk(label, width, height) {
  const { page } = await open(width, height);
  const settled = await page.waitForFunction(() => document.documentElement.dataset.feedLive, null, { timeout: 30000 })
    .then(() => true, () => false);
  const seen = await page.evaluate(() => [...document.querySelectorAll("#stream > .post.talk")].map((post) => ({
    href: post.querySelector(".post-title a")?.getAttribute("href") || "",
    title: post.querySelector(".post-title")?.textContent.trim() || "",
    reply: post.querySelector(".said-room")?.textContent.trim() || "",
  })));
  const answer = await asked(page, "/api/people?op=talk_latest&n=6&reply=1");
  const has = Array.isArray(answer?.threads) ? answer.threads.length : 0;
  const where = `${label} talk`;
  if (!settled) problems.push(`${where}: never settled (no data-feed-live after 30 s)`);
  else if (has && !seen.length) problems.push(`${where}: Talk answers ${has} threads and the stream shows none`);
  else if (!has && seen.length) problems.push(`${where}: ${seen.length} Talk posts with Talk answering none`);
  for (const one of seen) {
    if (!/\/talk\/t\/[1-9]/.test(one.href) || !one.title || !one.reply) problems.push(`${where}: a Talk post "${one.title}" to "${one.href}" with "${one.reply}"`);
  }
  console.log(`  ${where.padEnd(13)} ${seen.length} Talk posts (Talk answers ${answer ? `${has} threads` : "nothing"})`);
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
