// What a frame costs in a browser drawing in software (SwiftShader, which is
// what a weak device is here), setting by setting; and what a person's acts
// cost with whatever look the app chose for itself (FrameBudget).
//
//   python3 tools/web/serve.py build/web 9441 --parts assets/generated/parts --delay 0 \
//       --share L00kM0del1=vendor/omr/files/6392-1.mpd --share Pl4yFl0w01=vendor/omr/files/8808-1.mpd &
//   set -a; . ./.env; set +a
//   node tools/web/look_cost.mjs --url=http://127.0.0.1:9441 --out=DIR --mode=cuts
//   node tools/web/look_cost.mjs --url=http://127.0.0.1:9441 --out=DIR --mode=acts [--gate]
//
// Scenes: "empty", the editor with nothing on the baseplate; "model", the
// editor with a 500-part set copied in from its link (?copy=, 6392-1);
// "share", 8808-1 in the shared viewer (/m/<id>). Sizes: "laptop", 1280 x
// 800 at 1x by the mouse; "phone", 390 x 844 at 3x.
//
// --mode=cuts: for each scene and size, each of --cuts is pinned in the
// page (window.brickworksLookAsk) and --frames frames drawn on purpose and
// timed, by the app (the time from one drawing's end to the next's, less
// the frame's own work) and by the page (the gaps between its frames), in
// --rounds rounds with the cuts taken in turn, so the box's load falls on
// each alike. "none" is the look as it is; "ui" the interface not drawn;
// "ladder" every cut the app would make. Needs a build with FrameBudget.
//
// --mode=acts: the acts a person makes, timed by the page on any build:
// in the editor, the view turned (a right drag), a part dragged (a left
// drag from the middle of the model, undone after) and a 2 x 4 brick in
// hand swept across the model; in the viewer, the steering wheel turned
// (Play). Each says its drawn frames and the gap between them, and the
// look the app chose by then (none on a build without FrameBudget).
// --gate: and fails unless the app chose a lighter look on every page,
// which a build without FrameBudget never does.
//
// Writes DIR/look_<mode>.json. Says the box's load beside every number:
// a frame drawn in software on a shared box costs what the box lets it.
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { loadavg } from "node:os";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:9441").replace(/\/$/, "");
const out = String(args.out || "shots/look_cost");
const mode = String(args.mode || "cuts");
const rounds = Number(args.rounds || 2);
const frames = Number(args.frames || 10);
const modelId = String(args["model-id"] || "L00kM0del1");
const shareId = String(args["share-id"] || "Pl4yFl0w01");
const sizes = String(args.sizes || "laptop,phone").split(",");
const scenes = String(args.scenes || "empty,model,share").split(",");
const CUTS = String(args.cuts || "none,msaa,glow,shadow_soft,shadow_size,shadow,scale,dense,ui,ladder").split(",");
const SIZES = {
  laptop: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 },
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
};
mkdirSync(out, { recursive: true });
const load = () => Math.round(loadavg()[0] * 10) / 10;
const t0 = Date.now();
const log = (line) => console.log(`${line}  [${Math.round((Date.now() - t0) / 1000)}s, load ${load()}]`);
const median = (list) => {
  const s = list.slice().sort((a, b) => a - b);
  return s.length ? Math.round(s[Math.floor(s.length / 2)] * 10) / 10 : 0;
};

// In the page before the engine starts: each engine frame's start and
// length, and whether it drew (a WebGL clear or draw in it). Counting the
// calls, not timing each, so the cost is the same on every build.
function instrument() {
  const perf = { frames: [] };
  window.lookFrames = perf;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  let calls = 0;
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    calls = 0;
    const start = performance.now();
    try { callback(time); } finally {
      inside = false;
      perf.frames.push([start, performance.now() - start, calls]);
      if (perf.frames.length > 20000) perf.frames.splice(0, 10000);
    }
  };
  const context = WebGL2RenderingContext.prototype;
  for (const name of ["clear", "drawElements", "drawArrays", "drawElementsInstanced", "drawArraysInstanced"]) {
    const was = context[name];
    context[name] = function (...a) { calls += 1; return was.apply(this, a); };
  }
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
}

const now = (page) => page.evaluate(() => performance.now());
const state = (page) => page.evaluate(() => window.brickworksState || {});
const look = async (page) => (await state(page)).look || null;
async function until(page, test, what, seconds = 300, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}
// The page's frames from [from] on: how many, how many drew, and the gaps
// between the drawn ones (start to start: what a person waits a step).
async function framesSince(page, from) {
  const list = await page.evaluate((a) => window.lookFrames.frames.filter(([s]) => s >= a), from);
  const drawn = list.filter(([, , c]) => c > 0);
  const gaps = [];
  for (let n = 1; n < drawn.length; n++) gaps.push(drawn[n][0] - drawn[n - 1][0]);
  return { frames: list.length, drawn: drawn.length, gap_median_ms: median(gaps),
    gap_worst_ms: Math.round(Math.max(0, ...gaps)), drawn_median_ms: median(drawn.map(([, d]) => d)) };
}
// Quiet: nothing working and [span] ms of frames under 100 ms.
async function quiet(page, span = 2000, longest = 120000) {
  const end = Date.now() + longest;
  while (Date.now() < end) {
    await page.waitForTimeout(500);
    const ok = await page.evaluate((s) => {
      const t = performance.now();
      const recent = window.lookFrames.frames.filter(([t0]) => t0 >= t - s);
      const busy = Object.keys((window.brickworksState || {}).working || {}).length > 0;
      return !busy && t > s && recent.length > 0 && recent.every(([, d]) => d < 100);
    }, span).catch(() => false);
    if (ok) return true;
  }
  return false;
}

async function open(browser, size, scene) {
  const shape = SIZES[size];
  const context = await browser.newContext({ ...shape });
  await context.addInitScript(instrument);
  await context.addInitScript(() => { window.brickworksGrabAsk = true; });
  const page = await context.newPage();
  page.on("pageerror", (e) => console.log(`  page error: ${String(e).slice(0, 200)}`));
  const address = scene === "share" ? `${site}/m/${shareId}`
    : scene === "model" ? `${site}/?copy=${modelId}` : `${site}/`;
  await page.goto(address, { waitUntil: "domcontentloaded", timeout: 180000 });
  if (scene === "share") {
    await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the shared model", 600);
  } else {
    await until(page, () => (window.brickworksControls || {}).model_name, "the editor", 600);
    if (scene === "model") {
      await until(page, () => {
        const s = window.brickworksState || {};
        return (s.bricks || 0) > 400 && (s.awaited || 0) === 0 && !s.playing
          && Object.keys(s.working || {}).length === 0;
      }, "the set copied in", 900);
    }
  }
  await quiet(page, 3000, 240000);
  return { context, page };
}

// --- cuts --------------------------------------------------------------------

async function measureCut(page, cut, ladder) {
  const cuts = cut === "none" ? [] : cut === "ladder" ? ladder : [cut];
  // Asked, then looked at once it is taken: the app reads the ask at its
  // next telling of the page (Main._tell_page).
  await page.evaluate((c) => { window.brickworksLookAsk = { cuts: c }; }, cuts);
  await until(page, (c) => {
    const l = (window.brickworksState || {}).look || {};
    return l.pinned && JSON.stringify(l.cuts) === JSON.stringify(c);
  }, `the cuts ${cuts}`, 120, cuts);
  // A frame drawn with them first, then the look.
  await page.waitForTimeout(1500);
  const from = await now(page);
  const looks = ((await look(page)) || {}).looks || 0;
  await page.evaluate((n) => { window.brickworksLookAsk = { look: n }; }, frames);
  const l = await until(page, ([n, was]) => {
    const x = (window.brickworksState || {}).look || {};
    return x.looks > was && x.looking === 0 && (x.timed || []).length >= Math.min(3, n) ? x : null;
  }, "the look done", 600, [frames, looks]);
  const page_side = await framesSince(page, from);
  return { cut, app_ms: median(l.timed), app_timed: l.timed, page_gap_ms: page_side.gap_median_ms,
    drawn: page_side.drawn, load: load() };
}

async function cutsMode(browser) {
  const rows = [];
  for (const size of sizes) {
    for (const scene of scenes) {
      log(`${size}, ${scene}: opening`);
      const { context, page } = await open(browser, size, scene);
      const first = await look(page);
      if (!first) throw new Error("this build has no FrameBudget (window.brickworksState.look)");
      log(`${size}, ${scene}: the app chose ${JSON.stringify(first.cuts)} (judged ${JSON.stringify(first.judged)})`);
      const wanted = CUTS.filter((c) => c !== "dense" || SIZES[size].deviceScaleFactor > 1);
      for (let round = 1; round <= rounds; round++) {
        for (const cut of wanted) {
          const row = { size, scene, round, ...(await measureCut(page, cut, first.ladder)) };
          rows.push(row);
          log(`  ${size} ${scene} r${round} ${cut}: app ${row.app_ms} ms, page ${row.page_gap_ms} ms (${row.drawn} drawn)`);
          writeFileSync(path.join(out, "look_cuts.json"), JSON.stringify({ site, rows }, null, 1));
        }
      }
      await page.evaluate(() => { window.brickworksLookAsk = { cuts: null }; });
      await page.screenshot({ path: path.join(out, `${size}_${scene}.png`) }).catch(() => {});
      await context.close();
    }
  }
  // The table: each cut's median over the rounds, and against "none".
  const table = {};
  for (const r of rows) {
    const key = `${r.size} ${r.scene}`;
    table[key] = table[key] || {};
    (table[key][r.cut] = table[key][r.cut] || []).push(r.app_ms);
  }
  console.log("\ncut costs (the app's timing, ms a drawn frame, median of the rounds; saved against none):");
  for (const [key, cuts] of Object.entries(table)) {
    const base = median(cuts.none || [0]);
    console.log(`  ${key}: ${Object.entries(cuts).map(([c, v]) => `${c} ${median(v)}${c === "none" ? "" : ` (${Math.round(100 * (1 - median(v) / base))}%)`}`).join(", ")}`);
  }
  writeFileSync(path.join(out, "look_cuts.json"), JSON.stringify({ site, rows, table }, null, 1));
}

// --- acts --------------------------------------------------------------------

async function act(page, name, doing, settle = 1500) {
  const from = await now(page);
  const began = Date.now();
  await doing();
  await page.waitForTimeout(settle);
  const row = { act: name, ms: Date.now() - began, ...(await framesSince(page, from)), load: load() };
  log(`    ${name}: ${row.drawn} drawn in ${row.ms} ms, ${row.gap_median_ms} ms apart (worst ${row.gap_worst_ms})`);
  return row;
}

async function where(page, name, seconds = 120) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await page.evaluate(() => window.brickworksControls || {}))[name];
    if (at) return at;
    if (n === 2) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}

async function editorActs(page, size) {
  const rows = [];
  await page.keyboard.press("Escape");
  const view = await where(page, "view");
  const span = Math.min(150, Math.round(SIZES[size].viewport.width / 3));
  rows.push(await act(page, "orbit", async () => {
    await page.mouse.move(view.x - span, view.y);
    await page.mouse.down({ button: "right" });
    await page.mouse.move(view.x + span, view.y + 20, { steps: 30 });
    await page.mouse.up({ button: "right" });
  }));
  await quiet(page, 2000, 120000);
  const before = (await state(page)).bricks;
  rows.push(await act(page, "drag", async () => {
    await page.mouse.move(view.x, view.y);
    await page.mouse.down();
    await page.mouse.move(view.x + span / 2, view.y + 10, { steps: 20 });
    await page.mouse.up();
  }));
  await quiet(page, 2000, 120000);
  await page.keyboard.press("Control+z");
  await quiet(page, 2000, 120000);
  rows.at(-1).bricks_kept = (await state(page)).bricks === before;
  // A 2 x 4 brick in hand, swept across the model.
  try {
    const search = await where(page, "part search");
    await page.mouse.click(search.x, search.y);
    await page.keyboard.press("Control+a");
    await page.keyboard.type("3001", { delay: 30 });
    await page.waitForTimeout(2500);
    const first = await where(page, "first part");
    await page.mouse.click(first.x, first.y);
    await until(page, () => String((window.brickworksState || {}).held || "") === "3001", "a brick in hand", 60);
    const there = await where(page, "view");
    await page.mouse.move(there.x - span, there.y);
    await quiet(page, 2000, 120000);
    rows.push(await act(page, "place", async () => {
      await page.mouse.move(there.x + span, there.y + 30, { steps: 30 });
    }));
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
  } catch (trouble) {
    log(`    place: not measured (${String(trouble.message || trouble).slice(0, 120)})`);
  }
  return rows;
}

function arc(handle, degrees, steps) {
  const cx = Number(handle.pivot_x ?? handle.x);
  const cy = Number(handle.pivot_y ?? handle.y);
  let dx = handle.x - cx;
  let dy = handle.y - cy;
  if (Math.hypot(dx, dy) < 12) { dx = 0; dy = -30; }
  const reach = Math.hypot(dx, dy);
  if (reach < 30) degrees *= Math.min(30 / reach, 2.4);
  const points = [];
  for (let n = 1; n <= steps; n += 1) {
    const a = (degrees * Math.PI / 180) * n / steps;
    points.push({ x: cx + dx * Math.cos(a) - dy * Math.sin(a), y: cy + dx * Math.sin(a) + dy * Math.cos(a) });
  }
  return points;
}

async function viewerActs(page) {
  const handle = await until(page, () => ((window.brickworksGrab || {}).handles || [])
    .find((h) => h.play === "steering") || null, "the steering wheel's handle", 180);
  const points = arc(handle, 50, 12);
  const row = await act(page, "play_drag", async () => {
    await page.mouse.move(handle.x, handle.y);
    await page.mouse.down();
    for (const p of points) await page.mouse.move(p.x, p.y, { steps: 2 });
    await page.mouse.up();
  });
  return [row];
}

async function actsMode(browser) {
  const rows = [];
  let failed = 0;
  for (const size of sizes) {
    for (const scene of scenes) {
      log(`${size}, ${scene}: opening`);
      const { context, page } = await open(browser, size, scene);
      const chosen = await look(page);
      log(`  the look: ${chosen ? JSON.stringify(chosen.cuts) : "(no FrameBudget in this build)"}`);
      const acts = scene === "share" ? await viewerActs(page) : await editorActs(page, size);
      for (const r of acts) rows.push({ size, scene, look: chosen ? chosen.cuts : null, ...r });
      if (args.gate) {
        const lighter = Boolean(chosen && chosen.cuts.length > 0);
        console.log(`  ${lighter ? "ok  " : "FAIL"}  ${size} ${scene}: drawn in software, the app chose a lighter look `
          + `(${chosen ? JSON.stringify(chosen.cuts) : "none: no FrameBudget"}; judged ${chosen ? JSON.stringify(chosen.judged) : "-"})`);
        if (!lighter) failed += 1;
      }
      await page.screenshot({ path: path.join(out, `${size}_${scene}_acts.png`) }).catch(() => {});
      writeFileSync(path.join(out, "look_acts.json"), JSON.stringify({ site, rows }, null, 1));
      await context.close();
    }
  }
  return failed;
}

const signedOut = scenes.every((s) => s === "share");
const browser = await launch({ signedOut });
let failed = 0;
try {
  if (mode === "cuts") await cutsMode(browser);
  else failed = await actsMode(browser);
} finally {
  await browser.close();
}
console.log(`look_cost: ${mode} done${args.gate ? (failed ? `, ${failed} FAILED` : ", every check passed") : ""}`);
process.exit(failed ? 1 : 0);
