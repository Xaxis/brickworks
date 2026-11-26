// Does the home's hero, the studio at work (herostudio, 2026-11-26), hold up
// as a visitor meets it, and does the header's mark turn as it should?
//
//   node tools/web/hero_check.mjs --url=<deployment> [--out=DIR]
//   node tools/web/hero_check.mjs --dir=OUT [--from=<deployment>] [--out=DIR]
//
// --dir serves a site put together (tools/site.py OUT, then
// tools/web/home_shelf.mjs OUT --offline), or web/ itself, asking --from (a
// preview, with BW_BYPASS) for what only a deployment has: the posts'
// pictures and the API. At 1280 x 800 and 390 x 844 (touch), light and
// dark, signed out:
//
// - the first paint is the loop's poster (in the HTML, its size given): the
//   desktop's cut on a laptop, the phone's under 600 px, drawn by the load;
// - the loop itself is not asked for before the page's load, and then it
//   plays: that width's cut, AV1 where the browser plays it (else H.264),
//   muted, looping, inline, no controls, under 1.5 MB, and nothing moves
//   (CLS 0) as it takes the poster's place;
// - its captions come in turn as it plays, and Pause stops it (pressed, the
//   picture still) until Play;
// - nothing of three.js is asked for: not the hero's, not the header's;
// - the header's mark turns as our mark in bricks (web/img/hero/mark-turn.webp,
//   asked for only after the page's load, icon.svg at rest) once as a visit
//   begins, not again on the next page in that tab, and again when a
//   pointer comes onto it;
// - for somebody who asks for less motion, or to save data: the poster
//   alone, no loop asked for, and a mark that never turns.
//
// --out keeps the pictures: each first paint, and each loop half way.
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url && !args.dir) {
  console.error("hero_check: --url=<deployment> or --dir=<site put together>");
  process.exit(2);
}
const bypass = process.env.VERCEL_BYPASS || process.env.BW_BYPASS;
const site = args.dir ? await serveDir(resolve(String(args.dir))) : null;
const base = site ? site.url : String(args.url).replace(/\/+$/, "");
const from = args.from ? String(args.from).replace(/\/+$/, "") : "";
const out = args.out ? resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
// The most a cut of the loop may weigh (hero_capture.py aims under 1.45 MB).
const MOST = 1.5 * 1024 * 1024;

const browser = await launch({ signedOut: true });
const problems = [];
const said = (line) => console.log(`  ${line}`);

async function open(width, height, theme, { still = false, saveData = false, context = null } = {}) {
  const phone = width < 600;
  const holder = context || await browser.newContext({ viewport: { width, height }, colorScheme: theme, isMobile: phone, hasTouch: phone,
    reducedMotion: still ? "reduce" : "no-preference" });
  const page = await holder.newPage();
  if (bypass && !site) await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  if (site && from) {
    // What only a deployment has, from --from.
    await page.route(/^[^?]*\/(m\/[^/?]+\.(webp|png)|api\/[^?]*)(\?.*)?$/, async (route) => {
      const url = new URL(route.request().url());
      try {
        const answer = await fetch(from + url.pathname + url.search, { headers: bypass ? { "x-vercel-protection-bypass": bypass } : {} });
        await route.fulfill({ status: answer.status, headers: { "content-type": answer.headers.get("content-type") || "application/octet-stream" },
          body: Buffer.from(await answer.arrayBuffer()) });
      } catch {
        await route.abort();
      }
    });
  }
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  const asked = [];
  page.on("request", (r) => asked.push({ url: r.url(), at: Date.now() }));
  const sizes = {};
  page.on("response", async (r) => {
    if (/\.mp4(\?|$)/.test(r.url())) sizes[r.url()] = Number(r.headers()["content-length"] || 0) || (await r.body().catch(() => Buffer.alloc(0))).length;
  });
  await page.addInitScript((saving) => {
    window.__shifts = [];
    window.__paints = {};
    try {
      new PerformanceObserver((list) => {
        for (const e of list.getEntries()) if (!e.hadRecentInput) window.__shifts.push({ at: Math.round(e.startTime), value: e.value });
      }).observe({ type: "layout-shift", buffered: true });
      new PerformanceObserver((list) => {
        for (const e of list.getEntries()) window.__paints.lcp = { at: Math.round(e.startTime), what: e.element?.className || e.element?.tagName || "" };
      }).observe({ type: "largest-contentful-paint", buffered: true });
    } catch { /* this browser has none */ }
    addEventListener("load", () => { window.__loadedAt = Date.now(); });
    // Each time the header's mark begins a turn, however short the page's load.
    window.__markTurns = 0;
    new MutationObserver((list) => {
      for (const m of list) if (m.target.matches?.(".site-head .mark .chip.turning") && !String(m.oldValue).includes("turning")) window.__markTurns += 1;
    }).observe(document, { subtree: true, attributes: true, attributeFilter: ["class"], attributeOldValue: true });
    if (saving) Object.defineProperty(navigator, "connection", { value: { saveData: true, effectiveType: "4g" }, configurable: true });
  }, saveData);
  await page.goto(`${base}/`, { waitUntil: "load", timeout: 60000 });
  return { page, errors, asked, sizes, context: holder };
}

/// The header's mark now: its picture, its size, whether it is turning.
const markNow = (page) => page.evaluate(() => {
  const chip = document.querySelector(".site-head .mark .chip");
  if (!chip) return null;
  const style = getComputedStyle(chip);
  const r = chip.getBoundingClientRect();
  return { picture: style.backgroundImage, size: [Math.round(r.width), Math.round(r.height)],
    turning: chip.classList.contains("turning"), running: chip.getAnimations().length, turns: window.__markTurns };
});

/// The loop now: what <html data-hero> says, its video, its caption, its button.
const loopNow = (page) => page.evaluate(() => {
  const video = document.querySelector("#hero-loop video");
  const say = document.getElementById("loop-say");
  const stop = document.getElementById("loop-stop");
  return {
    hero: document.documentElement.dataset.hero || "",
    video: video ? { src: video.currentSrc || video.src, cut: video.dataset.cut, muted: video.muted, loop: video.loop,
      inline: video.playsInline, controls: video.controls, paused: video.paused, time: video.currentTime,
      shown: getComputedStyle(video).opacity === "1", w: video.videoWidth, h: video.videoHeight } : null,
    caption: say?.classList.contains("shown") ? say.textContent.trim() : "",
    stop: stop && !stop.hidden ? { pressed: stop.getAttribute("aria-pressed"), name: stop.textContent.trim().replace(/\s+/g, " ") } : null,
  };
});

for (const [label, width, height] of [["laptop", 1280, 800], ["phone", 390, 844]]) {
  const cut = width < 600 ? "phone" : "desktop";
  for (const theme of ["light", "dark"]) {
    const where = `${label} ${theme}`;
    const { page, errors, asked, sizes, context } = await open(width, height, theme);
    const first = await page.evaluate(() => {
      const img = document.querySelector("#hero-loop .loop-poster");
      const r = img?.getBoundingClientRect();
      return { poster: img ? img.currentSrc : "", drawn: Boolean(img?.complete && img.naturalWidth > 0),
        sized: Boolean(img?.getAttribute("width") && img?.getAttribute("height")), box: r ? [Math.round(r.width), Math.round(r.height)] : null,
        lcp: window.__paints.lcp || null, loadedAt: window.__loadedAt };
    });
    if (out) await page.screenshot({ path: `${out}/first_${width}_${theme}.png` });
    if (!first.drawn || !first.sized) problems.push(`${where}: the poster is not drawn by the load with its size given (${first.poster || "none"})`);
    if (!new RegExp(`/img/hero/studio-${cut}-\\d+\\.webp$`).test(first.poster)) problems.push(`${where}: the poster is ${first.poster || "none"}, not the ${cut}'s`);
    // Then the loop: asked for after the load, playing within 20 s.
    await page.waitForFunction(() => ["playing", "kept-failed", "still"].includes(document.documentElement.dataset.hero), null, { timeout: 20000 }).catch(() => null);
    const loopAsked = asked.filter((a) => /\/img\/hero\/studio-[a-z]+\.(av1|h264)\.mp4/.test(a.url));
    const loadedAt = await page.evaluate(() => window.__loadedAt);
    if (!loopAsked.length) problems.push(`${where}: the loop was never asked for`);
    else if (loopAsked[0].at < loadedAt) problems.push(`${where}: the loop was asked for ${loadedAt - loopAsked[0].at} ms before the page's load`);
    const av1 = await page.evaluate(() => document.createElement("video").canPlayType('video/mp4; codecs="av01.0.08M.08"'));
    const want = `/img/hero/studio-${cut}.${av1 ? "av1" : "h264"}.mp4`;
    await page.waitForTimeout(2500);
    const s = await loopNow(page);
    if (s.hero !== "playing" || !s.video) problems.push(`${where}: the loop is not playing (data-hero ${s.hero || "none"})`);
    else {
      if (!s.video.src.endsWith(want)) problems.push(`${where}: the loop plays ${s.video.src}, not ${want}`);
      if (!s.video.muted || !s.video.loop || !s.video.inline || s.video.controls) problems.push(`${where}: the loop is not muted, looping and inline without controls`);
      if (s.video.paused || !(s.video.time > 0.5)) problems.push(`${where}: the loop is not moving (at ${s.video.time.toFixed(2)} s)`);
      if (!s.video.shown) problems.push(`${where}: the loop plays unseen`);
    }
    for (const [url, bytes] of Object.entries(sizes)) if (bytes > MOST) problems.push(`${where}: ${url} is ${(bytes / 1048576).toFixed(2)} MB, over 1.5`);
    // Its captions, in turn.
    const words = new Set(s.caption ? [s.caption] : []);
    for (let i = 0; i < 24 && words.size < 3; i++) {
      await page.waitForTimeout(800);
      const now = await loopNow(page);
      if (now.caption) words.add(now.caption);
    }
    if (words.size < 2) problems.push(`${where}: its captions did not change as it played (${[...words].join(", ") || "none"})`);
    if (out) await page.screenshot({ path: `${out}/playing_${width}_${theme}.png` });
    // Pause, then Play.
    let paused = null;
    let played = null;
    if (s.stop) {
      await page.locator("#loop-stop").click();
      await page.waitForTimeout(600);
      const p1 = await loopNow(page);
      await page.waitForTimeout(800);
      const p2 = await loopNow(page);
      paused = p1.stop?.pressed === "true" && p1.video?.paused && p2.video?.time === p1.video?.time && p1.hero === "paused";
      await page.locator("#loop-stop").click();
      await page.waitForTimeout(1200);
      const p3 = await loopNow(page);
      played = p3.stop?.pressed === "false" && !p3.video?.paused && p3.video?.time > (p2.video?.time ?? 0);
      if (!paused) problems.push(`${where}: Pause did not stop the loop (${JSON.stringify(p1.stop)}, ${p1.hero})`);
      if (!played) problems.push(`${where}: Play did not start it again`);
      if (!/pause/i.test(s.stop.name)) problems.push(`${where}: the loop's button is named "${s.stop.name}"`);
    } else problems.push(`${where}: no Pause beside the playing loop`);
    // Nothing moved; no three.js.
    const shifts = await page.evaluate(() => window.__shifts);
    const moved = shifts.reduce((sum, e) => sum + e.value, 0);
    if (moved > 0.001) problems.push(`${where}: the page moved ${moved.toFixed(4)} (${shifts.map((e) => `${e.value.toFixed(4)}@${e.at}`).join(", ")})`);
    const three = asked.filter((a) => /\/viewer3d\.js|\/hero\/mark\.json/.test(a.url));
    if (three.length) problems.push(`${where}: three.js asked for on the home (${three.map((a) => new URL(a.url).pathname).join(", ")})`);
    // The header's mark: turned as the visit began, then still.
    const m1 = await markNow(page);
    if (!m1 || !/icon\.svg|mark-turn\.webp/.test(m1.picture) || m1.size.join("x") !== "30x30") problems.push(`${where}: the header's mark is ${JSON.stringify(m1)}, not the 30 px mark`);
    // Its turn's frames: asked for, and only once the page was in.
    const frames = await page.evaluate(() => {
      const loaded = performance.getEntriesByType("navigation")[0]?.loadEventStart || 0;
      const one = performance.getEntriesByType("resource").find((e) => /mark-turn\.webp/.test(e.name));
      return one ? { at: Math.round(one.startTime), loaded: Math.round(loaded) } : null;
    });
    if (!frames) problems.push(`${where}: the mark's frames never came`);
    else if (frames.at < frames.loaded) problems.push(`${where}: the mark's frames were asked for at ${frames.at} ms, before the page's load at ${frames.loaded}`);
    if (errors.length) problems.push(`${where}: page errors: ${errors.slice(0, 3).join("; ")}`);
    const bytes = Object.values(sizes).reduce((a, b) => Math.max(a, b), 0);
    said(`${where.padEnd(13)} poster ${first.poster.replace(/^.*\/img\/hero\//, "")} ${first.box?.join("x")} (LCP ${first.lcp ? `${first.lcp.what} at ${first.lcp.at} ms` : "?"}); `
      + `loop ${s.hero} ${s.video ? s.video.src.replace(/^.*\/img\/hero\//, "") : "-"} ${s.video ? `${s.video.w}x${s.video.h}` : ""}, ${(bytes / 1048576).toFixed(2)} MB, asked ${loopAsked.length ? `${loopAsked[0].at - loadedAt} ms after load` : "never"}; `
      + `captions ${[...words].map((w) => `"${w}"`).join(" ")}; pause ${paused} play ${played}; moved ${moved.toFixed(4)}; three.js ${three.length ? "ASKED" : "not asked"}`);
    await context.close();
  }
}

// The mark as a visit begins, on the next page in that tab, and on a hover.
{
  const { page, context } = await open(1280, 800, "light");
  // Its turn begins once the page is in and its frames have come.
  await page.waitForFunction(() => window.__markTurns >= 1, null, { timeout: 8000 }).catch(() => null);
  const atLoad = await markNow(page);
  await page.waitForTimeout(1600);
  const after = await markNow(page);
  // The same tab's next page (sessionStorage is the tab's).
  await page.goto(`${base}/gallery`, { waitUntil: "load" });
  await page.waitForTimeout(400);
  const next = await markNow(page);
  await page.hover(".site-head .mark");
  await page.waitForTimeout(150);
  const hovered = await markNow(page);
  await page.waitForTimeout(1500);
  const settled = await markNow(page);
  if (!(atLoad?.turns >= 1)) problems.push("mark: it did not turn as the visit began");
  if (after?.turning || after?.running) problems.push("mark: it was still turning 1.6 s on");
  if (next?.turns) problems.push("mark: it turned again on the next page in the same tab");
  if (!hovered?.turning || !hovered?.running) problems.push("mark: a pointer coming onto it did not turn it");
  if (settled?.turning || settled?.running) problems.push("mark: it kept turning after a hover");
  said(`mark: turned ${atLoad?.turns ?? "?"}x as the visit began, then ${after?.turning ? "TURNING" : "still"}; the next page ${next?.turns ? "TURNED" : "still"}; `
    + `a hover ${hovered?.running ? "turns it" : "NOTHING"}, then ${settled?.turning ? "TURNING" : "still"}`);
  await context.close();
}

// Less motion, and saving data: the poster alone, and a mark that never turns.
for (const [name, given] of [["less motion", { still: true }], ["saving data", { saveData: true }]]) {
  for (const [width, height] of [[1280, 800], [390, 844]]) {
    const { page, errors, asked, context } = await open(width, height, "dark", given);
    await page.waitForTimeout(3500);
    if (given.still) await page.hover(".site-head .mark").catch(() => null);
    await page.waitForTimeout(200);
    const s = await loopNow(page);
    const m = await markNow(page);
    const poster = await page.evaluate(() => {
      const img = document.querySelector("#hero-loop .loop-poster");
      return Boolean(img && img.complete && img.naturalWidth > 0);
    });
    const loops = asked.filter((a) => /\.mp4(\?|$)/.test(a.url)).length;
    const where = `${name} ${width}`;
    if (s.hero !== "still" || s.video || loops || !poster) problems.push(`${where}: data-hero ${s.hero}, video ${Boolean(s.video)}, ${loops} loops asked for, poster drawn ${poster}`);
    if (given.still && (m?.turns || m?.running)) problems.push(`${where}: the mark turns`);
    if (errors.length) problems.push(`${where}: page errors: ${errors.slice(0, 3).join("; ")}`);
    if (out) await page.screenshot({ path: `${out}/${given.still ? "still" : "savedata"}_${width}_dark.png` });
    said(`${where.padEnd(17)} ${s.hero}, ${loops} loops asked for, the poster ${poster ? "drawn" : "NOT DRAWN"}${given.still ? `, the mark ${m?.turning || m?.running ? "TURNS" : "still"} under a pointer` : ""}`);
    await context.close();
  }
}

await browser.close();
site?.close();
if (problems.length) {
  console.log(`hero_check: ${problems.length} problem(s)`);
  for (const p of problems) console.log(`  - ${p}`);
  process.exit(1);
}
console.log("hero_check: the hero holds up");
