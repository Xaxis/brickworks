// The frames a builder feels, in a browser: opening a model, turning the
// view, a part in hand over the model, selecting it all, delete and undo,
// and a step of the timeline. The browser half of tools/bench/cadtask.py
// frames; src/dev/cadtask_frames.gd is the desktop half.
//
//   python3 tools/web/serve.py build/web 8862 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/cad_frames.mjs --url=http://127.0.0.1:8862/ --out=DIR MODEL.mpd ...
//
// Every engine frame is timed in the page, as progress_check.mjs times
// them: the whole frame callback (the app's work and its WebGL calls, which
// on SwiftShader are the software drawing) and, apart, the time inside
// WebGL. Each act is a person's: the file handed to File, Open; a right
// drag; a part taken by its number and the pointer swept over the model;
// Ctrl-A; Delete; Ctrl-Z; B and Right. Writes DIR/web_frames.json and a
// picture of each model. Judges nothing: SwiftShader on a shared box is not
// a phone or a graphics card, so the report says these as this box's.
import { launch, openColumnFor } from "./browser.mjs";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith("--")).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const models = process.argv.slice(2).filter((a) => !a.startsWith("--")).map((m) => resolve(m));
const url = args.url || "http://127.0.0.1:8862/";
const out = args.out || "shots/cad_frames";
mkdirSync(out, { recursive: true });
// --only=step,undo: those acts alone, each model opened first, written over
// the same acts of an earlier run's web_frames.json and the rest kept.
const only = args.only ? String(args.only).split(",") : null;
const wanted = (name) => !only || only.includes(name);

// In the page before the engine starts: every engine frame timed, with the
// time it spent inside WebGL (progress_check.mjs's instrument, frames only).
function instrument() {
  const perf = { frames: [] };
  window.cadFrames = perf;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  let gl = 0;
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    gl = 0;
    const t0 = performance.now();
    try { callback(time); } finally {
      inside = false;
      perf.frames.push([t0, performance.now() - t0, gl]);
      if (perf.frames.length > 40000) perf.frames.splice(0, 20000);
    }
  };
  const context = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(context)) {
    const d = Object.getOwnPropertyDescriptor(context, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    context[name] = function (...a) {
      const t0 = performance.now();
      try { return was.apply(this, a); } finally { gl += performance.now() - t0; }
    };
  }
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
}

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
await context.addInitScript(instrument);
const page = await context.newPage();
const choosers = [];
page.on("filechooser", (chooser) => choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });

const state = () => page.evaluate(() => window.brickworksState || {});
const controls = () => page.evaluate(() => window.brickworksControls || {});
const now = () => page.evaluate(() => performance.now());
async function where(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    // A control in a closed column: its rail opens it, as a person would.
    if (n === 2) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function until(test, seconds = 60) {
  let s = await state();
  for (let n = 0; n < seconds * 4 && !test(s); n++) {
    await page.waitForTimeout(250);
    s = await state();
  }
  return s;
}
// Quiet: nothing working and [span] ms of frames under 100 ms.
async function quiet(span = 2000, longest = 120000) {
  const end = Date.now() + longest;
  while (Date.now() < end) {
    await page.waitForTimeout(500);
    const ok = await page.evaluate((s) => {
      const t = performance.now();
      const recent = window.cadFrames.frames.filter(([t0]) => t0 >= t - s);
      const busy = Object.keys((window.brickworksState || {}).working || {}).length > 0;
      return !busy && t > s && recent.every(([, d]) => d < 100);
    }, span);
    if (ok) return true;
  }
  return false;
}
function stats(frames) {
  const whole = frames.map(([, d]) => d).sort((a, b) => a - b);
  const own = frames.map(([, d, g]) => d - g).sort((a, b) => a - b);
  const at = (list, q) => (list.length ? list[Math.min(list.length - 1, Math.ceil(list.length * q) - 1)] : 0);
  const r = (v) => Math.round(v * 10) / 10;
  // The frames that drew: an engine frame with nothing changed draws
  // nothing (IdleDraw) and costs a millisecond, and a median over those says
  // nothing about the ones a person sees.
  const drawn = frames.filter(([, , g]) => g > 1).map(([, d]) => d).sort((a, b) => a - b);
  return { frames: frames.length, median_ms: r(at(whole, 0.5)), p95_ms: r(at(whole, 0.95)),
    max_ms: r(whole.length ? whole[whole.length - 1] : 0), own_median_ms: r(at(own, 0.5)),
    own_max_ms: r(own.length ? own[own.length - 1] : 0), drawn: drawn.length,
    drawn_median_ms: r(at(drawn, 0.5)), drawn_p95_ms: r(at(drawn, 0.95)) };
}
// The frames from [from] to now.
async function since(from) {
  return page.evaluate((a) => window.cadFrames.frames.filter(([t0]) => t0 >= a), from);
}
// The app's scripts in the frames from [engineFrom] (the engine's own clock,
// window.brickworksState.now) on: its frames whose own work, process_frame to
// drawing, was over 50 ms (Main._slow_frames), the worst of them in ms, and
// how many. Apart from the frame less its WebGL, which also holds the
// engine's own drawing work on the processor and, on a loaded box, the time
// the page waited for a core.
async function scripts(engineFrom) {
  await page.waitForTimeout(600);
  const s = await state();
  const slow = (s.slow || []).filter(([at]) => at >= engineFrom);
  // Every frame over 8 ms of its own work, where the build keeps them.
  const busy = (s.busy || []).filter(([at]) => at >= engineFrom);
  const most = Math.max(slow.reduce((m, [, ms]) => Math.max(m, ms), 0),
    busy.reduce((m, [, ms]) => Math.max(m, ms), 0));
  return { scripts_max_ms: most, scripts_busy: busy.length, scripts_slow: slow.length,
    scripts_kept: Array.isArray(s.busy), told_most_ms: s.told_most_ms || 0 };
}
async function engineNow() {
  const s = await state();
  // The state is written twice a second: its clock, and the time since.
  return (s.now || 0) - 600;
}
async function act(name, doing, settle = 1500) {
  const engineFrom = await engineNow();
  const from = await now();
  await doing();
  await page.waitForTimeout(settle);
  const row = stats(await since(from));
  row.ms = Math.round((await now()) - from);
  Object.assign(row, await scripts(engineFrom));
  console.log(`  ${name}: ${JSON.stringify(row)}`);
  return row;
}
// An act that is done when the page's state says so ([done]), however long
// its frames take, and the frames from the press to then and a second on.
async function actUntil(name, doing, done, seconds = 300) {
  const engineFrom = await engineNow();
  const from = await now();
  await doing();
  const s = await until(done, seconds);
  await page.waitForTimeout(1000);
  const row = stats(await since(from));
  row.ms = Math.round((await now()) - from);
  row.done = done(s);
  Object.assign(row, await scripts(engineFrom));
  console.log(`  ${name}: ${JSON.stringify(row)}`);
  return row;
}

await where("model_name");
await page.waitForTimeout(5000);
await quiet(3000, 180000);
const rows = [];
for (const model of models) {
  console.log(`frames: ${basename(model)}`);
  const row = { file: basename(model) };
  // File, Open, From a file: the file handed over is the press.
  const at = await where("open");
  let chooser = null;
  for (let n = 0; n < 3 && !chooser; n++) {
    choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(3000 + 3000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && choosers.length === 0; wait++) await page.waitForTimeout(500);
    chooser = choosers.shift() || null;
    if (!chooser) await page.keyboard.press("Escape");
  }
  if (!chooser) throw new Error("no file chooser came up for Open");
  const before = (await state()).bricks || 0;
  const opened = await now();
  await chooser.setFiles(model);
  const s = await until((x) => (x.bricks || 0) > 0 && (x.bricks || 0) !== before
    && Object.keys(x.working || {}).length === 0 && !x.playing, 600);
  const placed = await now();
  await quiet(3000, 300000);
  row.open = { ...stats(await since(opened)), placed: s.bricks, said: String(s.said || "").slice(0, 120),
    to_placed_ms: Math.round(placed - opened), to_quiet_ms: Math.round((await now()) - opened) };
  console.log(`  open: ${JSON.stringify(row.open)}`);
  // Keyboard focus on the model, not a field.
  await page.keyboard.press("Escape");
  const view = await where("view");
  await page.mouse.move(view.x, view.y);
  await page.waitForTimeout(1000);
  await quiet(2000, 60000);
  if (wanted("idle")) row.idle = await act("idle", async () => {}, 3000);
  // Turn the view: a right drag across the middle, as a person turns it.
  if (wanted("orbit")) {
    row.orbit = await act("orbit", async () => {
      await page.mouse.move(view.x - 150, view.y);
      await page.mouse.down({ button: "right" });
      await page.mouse.move(view.x + 150, view.y + 20, { steps: 40 });
      await page.mouse.up({ button: "right" });
    });
    await quiet(2000, 60000);
  }
  // A 2 x 4 brick in hand, swept across the model.
  if (wanted("place")) {
    await page.mouse.click((await where("part search")).x, (await where("part search")).y);
    await page.keyboard.press("Control+a");
    await page.keyboard.type("3001", { delay: 30 });
    await page.waitForTimeout(2500);
    const first = await where("first part");
    await page.mouse.click(first.x, first.y);
    await until((x) => String(x.held || "") === "3001", 30);
    await page.mouse.move(view.x - 200, view.y);
    await page.waitForTimeout(1500);
    await quiet(2000, 60000);
    row.place = await act("place", async () => {
      await page.mouse.move(view.x + 200, view.y + 30, { steps: 40 });
    });
    row.place.ghost = (await state()).ghost !== null;
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.mouse.move(view.x, view.y);
    await quiet(2000, 60000);
  }
  const all = (await state()).bricks;
  if (wanted("select_all")) {
    row.select_all = await actUntil("select_all", () => page.keyboard.press("Control+a"),
      (x) => (x.selected || 0) > 0);
    row.select_all.selected = (await state()).selected;
    await quiet(2000, 60000);
  }
  // Everything selected nudged a stud (D), then Ctrl-Z and Ctrl-Shift-Z: the
  // move's frames in a window of their own, its undo and redo until the
  // status bar says they were done.
  if (wanted("move") && (await state()).selected > 0) {
    row.move = await act("move", () => page.keyboard.press("d"), 4000);
    await quiet(2000, 120000);
    row.undo_move = await actUntil("undo_move", () => page.keyboard.press("Control+z"),
      (x) => /^undid/.test(String(x.said || "")), 300);
    await quiet(2000, 120000);
    row.redo_move = await actUntil("redo_move", () => page.keyboard.press("Control+Shift+z"),
      (x) => /^redid/.test(String(x.said || "")), 300);
    await quiet(2000, 60000);
  }
  if (wanted("delete")) {
    row.delete = await actUntil("delete", () => page.keyboard.press("Delete"),
      (x) => (x.bricks || 0) < all);
    row.delete.removed = all - (await state()).bricks;
    await quiet(2000, 60000);
  }
  if (wanted("undo")) {
    row.undo = await actUntil("undo", () => page.keyboard.press("Control+z"),
      (x) => x.bricks === all);
    row.undo.back = (await state()).bricks === all;
    await page.keyboard.press("Escape");
    await quiet(2000, 60000);
  }
  // The timeline, then a step at a time by its Next, as a person clicks it.
  if (wanted("step")) {
    const opening = await now();
    await page.keyboard.press("b");
    const t = await until((x) => x.timeline && x.timeline.at && Object.keys(x.working || {}).length === 0, 300);
    row.timeline_open_ms = Math.round((await now()) - opening);
    row.timeline = t.timeline || {};
    await quiet(2000, 60000);
    // Right, which Main steps the timeline with: does it?
    const atKey = ((await state()).timeline || {}).at || [];
    await page.keyboard.press("ArrowRight");
    const afterKey = (await until((x) => ((x.timeline || {}).at || [])[0] !== atKey[0], 20)).timeline || {};
    row.right_key_steps = (afterKey.at || [])[0] !== atKey[0];
    const steps = [];
    for (let k = 0; k < 5; k++) {
      const was = (((await state()).timeline || {}).at || [])[0];
      const next = await where("steps_next");
      steps.push(await actUntil(`step ${k + 1}`, () => page.mouse.click(next.x, next.y),
        (x) => ((x.timeline || {}).at || [])[0] !== was, 120));
    }
    const drawnTimes = steps.map((r) => r.max_ms);
    row.step = { frames: steps.reduce((a, r) => a + r.frames, 0),
      median_ms: drawnTimes.slice().sort((a, b) => a - b)[2], p95_ms: Math.max(...drawnTimes),
      max_ms: Math.max(...drawnTimes), own_max_ms: Math.max(...steps.map((r) => r.own_max_ms)),
      scripts_max_ms: Math.max(...steps.map((r) => r.scripts_max_ms)),
      own_median_ms: steps.map((r) => r.own_max_ms).sort((a, b) => a - b)[2],
      each: steps, at: ((await state()).timeline || {}).at };
  }
  await page.screenshot({ path: `${out}/web_${basename(model, ".mpd")}.png` }).catch(() => {});
  if (wanted("step")) await page.keyboard.press("b");
  await page.keyboard.press("Escape");
  await quiet(2000, 60000);
  rows.push(row);
  let merged = rows;
  if (only && existsSync(`${out}/web_frames.json`)) {
    // The acts measured now over the same acts of the earlier run.
    const earlier = JSON.parse(readFileSync(`${out}/web_frames.json`, "utf8")).models || [];
    merged = earlier.map((m) => ({ ...m, ...(rows.find((r) => r.file === m.file) || {}) }));
    for (const r of rows) if (!earlier.some((m) => m.file === r.file)) merged.push(r);
  }
  writeFileSync(`${out}/web_frames.json`, JSON.stringify({ url, models: merged, errors }, null, 1));
}
console.log(`frames: ${rows.length} models written to ${out}/web_frames.json`);
await browser.close();
