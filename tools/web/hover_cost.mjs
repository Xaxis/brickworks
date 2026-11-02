// What the pointer moving over a model costs a page drawing in software
// (SwiftShader): from the mouse moving to the page's thread having the move's
// last step, which is when Together says where the pointer is (its "send"
// stage on the rich car, tools/web/together_flow.mjs 5f), without a session
// or a second page. Each move is the together check's: a part's middle, then
// another's, in two steps of the mouse.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 8871 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/hover_cost.mjs --url=http://127.0.0.1:8871/ --out=DIR [--moves=40] [--label=B] MODEL
//
// A browser hands the page a mouse move at the start of its next frame, and
// a frame begins only once the last one is drawn: so the move's second step
// waits out whatever the first one's frame drew. Per move, in ms from the
// move: the page given its first step ("first") and its second ("second"),
// the engine's first frame after that ("seen": the step had there), and the
// frame between, which the first step began ("between": its whole time and
// its time inside WebGL, which in software is the drawing). Writes
// DIR/hover_<label>.json. Says the box's load: a frame drawn in software on
// a shared box costs what the box lets it.
//
// --floor=none: the model's floor taken away first (set_floor), to tell the
// floor's share of a frame from the parts'.
import { askApp, launch, openFromFile } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { loadavg } from "node:os";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith("--")).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const model = process.argv.slice(2).filter((a) => !a.startsWith("--")).map((m) => resolve(m))[0];
if (!model) throw new Error("usage: hover_cost.mjs --url=URL --out=DIR MODEL");
const url = args.url || "http://127.0.0.1:8871/";
const out = args.out || "shots/hover_cost";
const label = args.label || "run";
const moves = Number(args.moves || 40);
mkdirSync(out, { recursive: true });

// In the page before the engine starts: every engine frame, unix ms, with
// its time inside WebGL; and every mouse move the page is given.
function instrument() {
  const perf = { frames: [], moves: [] };
  window.hoverCost = perf;
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
      perf.frames.push([performance.timeOrigin + t0, performance.now() - t0, gl]);
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
  window.addEventListener("mousemove", (event) => {
    perf.moves.push([performance.timeOrigin + performance.now(), event.clientX, event.clientY]);
    if (perf.moves.length > 20000) perf.moves.splice(0, 10000);
  }, true);
}

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
await context.addInitScript(instrument);
const page = await context.newPage();
const choosers = [];
page.on("filechooser", (chooser) => choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });

const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const state = () => page.evaluate(() => window.brickworksState || {});
const controls = () => page.evaluate(() => window.brickworksControls || {});
async function where(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await wait(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function until(test, seconds = 60) {
  let s = await state();
  for (let n = 0; n < seconds * 4 && !test(s); n++) {
    await wait(250);
    s = await state();
  }
  return s;
}
// Quiet: nothing working and [span] ms of frames under 100 ms.
async function quiet(span = 2000, longest = 120000) {
  const end = Date.now() + longest;
  while (Date.now() < end) {
    await wait(500);
    const ok = await page.evaluate((s) => {
      const t = performance.timeOrigin + performance.now();
      const recent = window.hoverCost.frames.filter(([t0]) => t0 >= t - s);
      const busy = Object.keys((window.brickworksState || {}).working || {}).length > 0;
      return !busy && recent.every(([, d]) => d < 100);
    }, span);
    if (ok) return true;
  }
  return false;
}
// Edits and tools through the app's own code (Together.check_edit), as
// together_flow asks them.
async function ask(asks) {
  await page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = a; }, asks);
  for (let n = 0; n < 600; n++) {
    const done = await page.evaluate(() => window.brickworksTogetherDone);
    if (done) return done;
    await wait(300);
  }
  throw new Error("the page never answered");
}

await where("model_name");
await wait(5000);
await quiet(3000, 180000);
// File, Open, From a file, as cad_frames.mjs opens one.
await openFromFile(page, model, { choosers, shots: out });
await until((x) => (x.bricks || 0) > 0 && (x.awaited || 0) === 0 && Object.keys(x.working || {}).length === 0
  && !x.playing, 600);
if (args.floor) {
  const [said] = await ask([{ op: "tool", name: "set_floor", arguments: { kind: String(args.floor) } }]);
  console.log(`  set_floor: ${String(said?.words || "").split("\n")[0].slice(0, 120)}`);
  await until((x) => (x.awaited || 0) === 0, 120);
}
await page.keyboard.press("Escape");
await page.keyboard.press("Escape");
await quiet(3000, 300000);
const opened = await state();
console.log(`  ${opened.bricks} parts, ${opened.scenery} of floor, ${opened.triangles} triangles in ${opened.batches}`
  + ` batches, tool ${opened.mode}, look ${JSON.stringify((opened.look || {}).cuts || [])}`);

// The parts' middles on the page, as together_flow aims at them.
const laid = ((await askApp(page, "Layout", { seconds: 60 })) || {}).targets || [];
if (laid.length < 2) throw new Error(`only ${laid.length} parts to aim at`);

const rows = [];
let last = null;
for (let n = 0; n < moves; n++) {
  const others = laid.filter((one) => one.brick !== last);
  const aim = others[n % others.length];
  last = aim.brick;
  const t0 = Date.now();
  await page.mouse.move(aim.x, aim.y, { steps: 2 });
  await wait(1500);
  const seen = await page.evaluate((from) => ({
    moves: window.hoverCost.moves.filter(([t]) => t >= from - 2),
    frames: window.hoverCost.frames.filter(([t]) => t >= from - 2),
  }), t0);
  const [first, second] = seen.moves;
  const after = (t) => seen.frames.find(([f]) => f >= t);
  const row = { aim: [aim.x, aim.y], part: aim.part };
  if (first && second) {
    const between = after(first[0]);
    const had = after(second[0]);
    row.first = Math.round(first[0] - t0);
    row.second = Math.round(second[0] - t0);
    row.seen = had ? Math.round(had[0] - t0) : null;
    row.between = between ? Math.round(between[1]) : null;
    row.between_gl = between ? Math.round(between[2]) : null;
  }
  row.longest = Math.round(Math.max(0, ...seen.frames.map(([, d]) => d)));
  // The frames that took a frame's time or more, from the move: when each
  // began, how long it took, and its time in WebGL.
  row.frames = seen.frames.filter(([, d]) => d >= 16).map(([f, d, g]) => [f - t0, d, g].map(Math.round));
  row.steps = seen.moves.map(([t]) => Math.round(t - t0));
  rows.push(row);
  await wait(200);
}
const p = (list, q) => {
  const sorted = list.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  return sorted.length ? sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * q) - 1)] : null;
};
const both = (key) => `${p(rows.map((r) => r[key]), 0.5)}, ${p(rows.map((r) => r[key]), 0.95)}`;
const load = loadavg().map((x) => x.toFixed(1)).join(" ");
const summary = { label, model, moves: rows.length, load, parts: opened.bricks, scenery: opened.scenery,
  triangles: opened.triangles, look: opened.look || {},
  seen: p(rows.map((r) => r.seen), 0.5), seen_p95: p(rows.map((r) => r.seen), 0.95),
  between: p(rows.map((r) => r.between), 0.5), between_gl: p(rows.map((r) => r.between_gl), 0.5) };
console.log(`  ${label} (p50, p95 ms, load ${load}): second step given ${both("second")}; seen ${both("seen")};`
  + ` the frame between ${both("between")}, in WebGL ${both("between_gl")}; longest frame ${both("longest")}`);
writeFileSync(`${out}/hover_${label}.json`, JSON.stringify({ summary, rows, errors }, null, 1));
await browser.close();
