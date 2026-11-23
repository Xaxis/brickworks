// Does the home's hero, our mark in bricks (hero3d, 2026-11-23), hold up as
// a visitor meets it?
//
//   node tools/web/hero_check.mjs --url=<deployment> [--out=DIR]
//   node tools/web/hero_check.mjs --dir=OUT [--from=<deployment>] [--out=DIR]
//
// --dir serves a site put together (tools/site.py OUT, then
// tools/web/home_shelf.mjs OUT --offline), asking --from (a preview, with
// BW_BYPASS) for what only a deployment has: the posts' pictures and the
// API. At 1280 x 800 and 390 x 844 (touch), light and dark, signed out:
//
// - the first paint is the poster (in the HTML, drawn, its size given), and
//   nothing moves from then on, the 3D taking its place included (CLS 0);
// - the 3D takes its place once the page is in (html data-hero="3d"), and
//   the viewer's code was not asked for before the page's load (the 3D is
//   on here whatever the machine's speed; the time a frame takes is said);
// - once a visit it assembles, a course at a time, at 30 frames a second or
//   better, each frame drawn to the end (a pixel read back waits for the
//   graphics: SwiftShader draws behind the page), then sways; a second
//   visit in the same tab does not assemble again;
// - a drag turns it and it settles back; the arrow keys turn it, focused; a
//   brick lifts under a mouse;
// - the stage is named, keyboard-focusable, and Open it in the studio is a
//   link into the app;
// - for somebody who asks for less motion: no assembly, no sway, still
//   turnable by hand; with no WebGL: the poster, and no error.
//
// --out keeps the pictures: the first screen at its first paint, the
// assembly half way, and the mark built, at each size and theme.
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
const FPS = 30;

const browser = await launch({ signedOut: true });
const problems = [];
const said = (line) => console.log(`  ${line}`);

async function open(width, height, theme, { still = false, noGl = false, page: given = null, hold = false } = {}) {
  const phone = width < 600;
  const page = given || await browser.newPage({ viewport: { width, height }, colorScheme: theme, isMobile: phone, hasTouch: phone,
    reducedMotion: still ? "reduce" : "no-preference" });
  // Held: the viewer's code waits until let go, so the first paint's
  // picture is the page as it is before any 3D (on a fast load the 3D
  // otherwise starts while the picture is taken).
  let letGo = () => {};
  if (hold) {
    const held = new Promise((r) => { letGo = r; });
    await page.route(/\/viewer3d\.js(\?.*)?$/, async (route) => { await held; await route.continue(); });
  }
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
  if (!given) {
    await page.addInitScript((noWebGl) => {
      window.__shifts = [];
      window.__paints = {};
      window.__asked = [];
      try {
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) if (!e.hadRecentInput) window.__shifts.push({ at: Math.round(e.startTime), value: e.value });
        }).observe({ type: "layout-shift", buffered: true });
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) window.__paints[e.name] = Math.round(e.startTime);
        }).observe({ type: "paint", buffered: true });
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) window.__paints.lcp = { at: Math.round(e.startTime), what: e.element?.className || e.element?.tagName || "" };
        }).observe({ type: "largest-contentful-paint", buffered: true });
      } catch { /* this browser has none */ }
      addEventListener("load", () => { window.__loadedAt = Math.round(performance.now()); });
      // The 3D on whatever this machine's speed (a check's box is loaded):
      // how fast it draws is measured, and said, apart.
      try { sessionStorage.setItem("brickworks.hero.slow", "100000"); } catch { /* none kept */ }
      if (noWebGl) {
        const real = HTMLCanvasElement.prototype.getContext;
        HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
          return /webgl/.test(kind) ? null : real.call(this, kind, ...rest);
        };
      }
    }, noGl);
  }
  page.on("request", (r) => { if (/viewer3d\.js|hero\/mark\.json/.test(r.url())) page.__asked = (page.__asked || []).concat([[r.url(), Date.now()]]); });
  await page.goto(`${base}/`, { waitUntil: "domcontentloaded", timeout: 60000 });
  return { page, errors, letGo };
}

const heroState = (page) => page.evaluate(() => ({ hero: document.documentElement.dataset.hero || "",
  state: window.brickworksHero?.state || "", angle: window.brickworksHero?.angle?.() || null }));

// The frames drawn while it assembles, each waited for to its end.
async function assemblyFrames(page) {
  return page.evaluate(() => new Promise((done) => {
    const canvas = document.querySelector(".hero-canvas");
    const gl = canvas && canvas.getContext("webgl2");
    if (!gl) { done({ frames: 0, seconds: 0, worst: 0 }); return; }
    const times = [];
    const pixel = new Uint8Array(4);
    let begun = 0;
    const tick = (now) => {
      gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
      const at = performance.now();
      const state = window.brickworksHero?.state;
      if (state === "assembling") {
        if (!begun) begun = at;
        times.push(at);
      }
      if (state !== "assembling" && begun) {
        const gaps = times.slice(1).map((t, i) => t - times[i]).sort((a, b) => a - b);
        done({ frames: times.length, seconds: (times[times.length - 1] - begun) / 1000,
          median: Math.round(gaps[Math.floor(gaps.length / 2)] || 0), worst: Math.round(gaps[gaps.length - 1] || 0) });
        return;
      }
      if (now > 120000) { done({ frames: times.length, seconds: 0, worst: 0, timedOut: true }); return; }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }));
}

for (const [label, width, height] of [["laptop", 1280, 800], ["phone", 390, 844]]) {
  for (const theme of ["light", "dark"]) {
    const where = `${label} ${theme}`;
    const { page, errors, letGo } = await open(width, height, theme, { hold: true });
    const first = await page.evaluate(() => {
      const img = document.querySelector("#hero-stage .hero-poster");
      const r = document.getElementById("hero-stage")?.getBoundingClientRect();
      return { poster: Boolean(img), sized: Boolean(img && img.getAttribute("width") && img.getAttribute("height")),
        stage: r ? [Math.round(r.top), Math.round(r.left), Math.round(r.width), Math.round(r.height)] : null,
        canvas: Boolean(document.querySelector(".hero-canvas")) };
    });
    await page.waitForFunction(() => document.querySelector("#hero-stage .hero-poster")?.complete, null, { timeout: 30000 }).catch(() => null);
    if (out) await page.screenshot({ path: `${out}/first_${width}_${theme}.png` });
    letGo();
    if (!first.poster || !first.sized) problems.push(`${where}: no poster with its size given in the HTML`);
    if (first.canvas) problems.push(`${where}: the 3D was there before the page was drawn`);
    // The 3D, once the page is in.
    await page.waitForFunction(() => /^(3d|kept)/.test(document.documentElement.dataset.hero || ""), null, { timeout: 120000 }).catch(() => null);
    let s = await heroState(page);
    if (s.hero !== "3d") problems.push(`${where}: the 3D did not take the poster's place (data-hero ${s.hero || "none"})`);
    const loadedAt = await page.evaluate(() => window.__loadedAt || 0);
    const askedAt = await page.evaluate(() => performance.getEntriesByType("resource").find((e) => /viewer3d\.js/.test(e.name))?.startTime || 0);
    if (askedAt && loadedAt && askedAt < loadedAt) problems.push(`${where}: the viewer was asked for at ${Math.round(askedAt)} ms, before the page's load at ${loadedAt}`);
    let frames = null;
    if (s.state === "assembling") {
      // Counted with nothing else asked of the page (a picture stalls it).
      frames = await assemblyFrames(page);
      const fps = frames.seconds ? frames.frames / frames.seconds : 0;
      // Pictures taken during it stall the page: judged on the median frame.
      const steady = frames.median ? 1000 / frames.median : 0;
      said(`${where}: assembled in ${frames.seconds.toFixed(2)} s, ${frames.frames} frames, ${fps.toFixed(1)} fps overall, median frame ${frames.median} ms (${steady.toFixed(1)} fps), worst ${frames.worst} ms`);
      if (steady < FPS) problems.push(`${where}: the assembly drew at ${steady.toFixed(1)} fps (median frame ${frames.median} ms), under ${FPS}`);
    } else if (s.hero === "3d") problems.push(`${where}: a first visit's 3D did not assemble (${s.state})`);
    await page.waitForFunction(() => window.brickworksHero?.state === "ready", null, { timeout: 30000 }).catch(() => null);
    await page.waitForTimeout(1200);
    if (out) await page.screenshot({ path: `${out}/built_${width}_${theme}.png` });
    // Sways once built.
    const a1 = (await heroState(page)).angle;
    await page.waitForTimeout(700);
    const a2 = (await heroState(page)).angle;
    if (!a1 || !a2 || Math.abs(a2.round - a1.round) < 0.003) problems.push(`${where}: it does not sway once built`);
    const named = await page.evaluate(() => {
      const stage = document.getElementById("hero-stage");
      const open = document.getElementById("hero-open");
      return { label: stage?.getAttribute("aria-label") || "", tab: stage?.tabIndex, open: open?.getAttribute("href") || "",
        openText: open?.textContent || "", pieces: document.getElementById("hero-pieces")?.textContent || "" };
    });
    if (!named.label || named.tab !== 0) problems.push(`${where}: the 3D is not named and focusable (${named.label}, tabindex ${named.tab})`);
    if (!/^\/app\?(view=[A-Za-z0-9]{10}|model=res:\/\/models\/brickworks_mark\.ldr)$/.test(named.open)) problems.push(`${where}: Open it in the studio goes to ${named.open || "nowhere"}`);
    // The keys turn it.
    await page.focus("#hero-stage");
    const k1 = (await heroState(page)).angle;
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(150);
    const k2 = (await heroState(page)).angle;
    if (!k1 || !k2 || Math.abs(k2.round - k1.round) < 0.15) problems.push(`${where}: an arrow key did not turn it`);
    if (width >= 600) {
      // A drag turns it, and it settles back; a brick lifts under the mouse.
      await page.waitForTimeout(3600);
      const box = await page.locator("#hero-stage").boundingBox();
      const cx = box.x + box.width / 2;
      const cy = box.y + box.height / 2;
      const before = (await heroState(page)).angle;
      await page.mouse.move(cx, cy);
      await page.mouse.down();
      for (let k = 1; k <= 8; k++) await page.mouse.move(cx + k * 20, cy, { steps: 2 });
      const held = (await heroState(page)).angle;
      await page.mouse.up();
      if (!before || !held || Math.abs(held.round - before.round) < 0.2) problems.push(`${where}: a drag did not turn it`);
      await page.waitForTimeout(2600);
      const settled = await page.evaluate(() => window.brickworksHero?.angle?.());
      const swayNow = settled ? Math.abs(settled.round - Math.PI / 4) : 9;
      if (swayNow > 0.45) problems.push(`${where}: it did not settle back after a drag (${swayNow.toFixed(2)} rad from its own view)`);
      await page.mouse.move(cx, cy + box.height * 0.18);
      await page.waitForTimeout(500);
      const lifted = await page.evaluate(() => window.brickworksHero?.lifted?.() ?? -1);
      if (lifted < 0) problems.push(`${where}: no brick lifted under the mouse`);
      await page.mouse.move(2, 2);
    }
    const shifts = await page.evaluate(() => window.__shifts || []);
    const moved = shifts.reduce((sum, e) => sum + e.value, 0);
    if (moved > 0) problems.push(`${where}: the page moved ${moved.toFixed(4)} (${shifts.map((e) => `${e.value.toFixed(4)}@${e.at}`).join(", ")})`);
    const paints = await page.evaluate(() => window.__paints || {});
    const took = await page.evaluate(() => window.brickworksHero?.took ?? -1);
    said(`${where}: the finished mark drawn in ${took} ms (over 50, a device this slow keeps the poster: web/landing.js SLOW)`);
    said(`${where}: poster at first paint, stage ${first.stage?.join(",")}; first paint ${paints["first-contentful-paint"]} ms, `
      + `LCP ${paints.lcp?.at} ms (${paints.lcp?.what}), load ${loadedAt} ms, viewer asked ${Math.round(askedAt)} ms; moved ${moved.toFixed(4)}; `
      + `${s.hero}; label "${named.label.slice(0, 40)}…"; open ${named.open}`);
    if (errors.length) problems.push(`${where}: page errors: ${errors.slice(0, 3).join("; ")}`);
    // A second visit in this tab: built at once.
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^(3d|kept)/.test(document.documentElement.dataset.hero || ""), null, { timeout: 120000 }).catch(() => null);
    s = await heroState(page);
    if (s.state === "assembling") problems.push(`${where}: it assembled again on a second visit`);
    await page.close();
    if (out) {
      // The assembly half way, in a visit of its own.
      const again = await open(width, height, theme);
      await again.page.waitForFunction(() => window.brickworksHero?.state === "assembling", null, { timeout: 120000 }).catch(() => null);
      await again.page.waitForTimeout(1150);
      await again.page.screenshot({ path: `${out}/assembling_${width}_${theme}.png` });
      await again.page.close();
    }
  }
}

// Less motion: finished at once, still, and turned by hand.
{
  const { page, errors } = await open(1280, 800, "light", { still: true });
  await page.waitForFunction(() => /^(3d|kept)/.test(document.documentElement.dataset.hero || ""), null, { timeout: 120000 }).catch(() => null);
  const s1 = await heroState(page);
  await page.waitForTimeout(1500);
  const s2 = await heroState(page);
  if (s1.state !== "ready") problems.push(`less motion: it is ${s1.state || "nothing"}, not finished at once`);
  if (!s1.angle || !s2.angle || Math.abs(s2.angle.round - s1.angle.round) > 1e-4) problems.push("less motion: it moves by itself");
  await page.focus("#hero-stage");
  await page.keyboard.press("ArrowLeft");
  await page.waitForTimeout(200);
  const s3 = await heroState(page);
  if (!s3.angle || Math.abs(s3.angle.round - s2.angle.round) < 0.15) problems.push("less motion: the keys do not turn it");
  if (out) await page.screenshot({ path: `${out}/still_1280_light.png` });
  if (errors.length) problems.push(`less motion: page errors: ${errors.slice(0, 3).join("; ")}`);
  said(`less motion: ${s1.state}, still ${!s2.angle || Math.abs(s2.angle.round - s1.angle.round) <= 1e-4}, keys turn it`);
  await page.close();
}

// No WebGL: the poster, and nothing said wrong.
{
  const { page, errors } = await open(1280, 800, "dark", { noGl: true });
  await page.waitForLoadState("load");
  await page.waitForTimeout(4000);
  const s = await heroState(page);
  const poster = await page.evaluate(() => {
    const img = document.querySelector("#hero-stage .hero-poster");
    return Boolean(img && img.complete && img.naturalWidth > 0 && getComputedStyle(img).opacity === "1");
  });
  if (s.hero !== "poster" || !poster) problems.push(`no WebGL: data-hero ${s.hero}, poster shown ${poster}`);
  if (errors.length) problems.push(`no WebGL: page errors: ${errors.slice(0, 3).join("; ")}`);
  if (out) await page.screenshot({ path: `${out}/nogl_1280_dark.png` });
  said(`no WebGL: ${s.hero}, the poster shown ${poster}, ${errors.length} errors`);
  await page.close();
}

await browser.close();
site?.close();
if (problems.length) {
  console.log(`hero_check: ${problems.length} problem(s)`);
  for (const p of problems) console.log(`  - ${p}`);
  process.exit(1);
}
console.log("hero_check: the hero holds up");
