// What each of the page's threads costs a person: the CPU of the page's main
// thread, of each of the engine's workers and of the browser's own threads,
// over a minute standing still with a model open and a minute of building,
// read from the operating system (/proc), not from a trace.
//
//   python3 tools/web/serve.py build/web 9960 --parts assets/generated/parts --delay 0 \
//       --accounts --compressed --cached &
//   set -a; . ./.env; set +a
//   node tools/web/thread_cpu.mjs --url=http://127.0.0.1:9960/index.html --out=DIR
//     --profile=desktop|phone   1400 x 900, or 390 x 844 at 3x by a finger
//     --idle=60 --build=60      the two windows, in seconds
//     --most=10                 fail if any worker takes more than this % of a
//                               core standing still
//
// Read from /proc (proc_cpu.mjs), not a trace: a trace counts a worker
// parked in a futex wait as busy. One engine thread really was: the audio
// driver's mix thread spun a core for the whole visit (spinworker,
// 2026-11-05: project.godot [audio]).
//
// Workers all carry the kernel name "DedicatedWorker". Each is named from a
// short sampled trace taken after the windows: the engine's threads by the
// wasm function at the bottom of their stacks (indices of the 4.7.2 web
// template, which the export ships byte for byte), the page's own JS workers
// by their script. Writes thread_cpu.json to --out.
//
// While building it times what a person meets first: the first search (the
// first letter typed to the part listed first, typed 40 ms a letter), the first part (its tile
// clicked to it in hand with its ghost), and the first drag of a part put
// down (the longest engine frame in it). The page is told the app's state
// twice a second, so the first two are to about half a second.
import { launch, START_MS } from "./browser.mjs";
import { pageRenderer, snapshot, spent } from "./proc_cpu.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:9960/index.html");
const out = String(args.out || "shots/thread_cpu");
const profile = String(args.profile || "desktop");
const idleS = Number(args.idle || 60);
const buildS = Number(args.build || 60);
const most = Number(args.most || 10);
const phone = profile === "phone";
mkdirSync(out, { recursive: true });

// Engine threads by wasm functions in their stacks (absolute function
// indices of Godot 4.7.2's web_release template, read from its code: it has
// no names). V8 inlines a hot thread's own function into the one that
// starts it, so each is known by more than one: the dummy driver's mix
// thread (47402) by what it calls, audio_server_process (9528) and
// OS::delay_usec (69057); a pool thread (30182) by the GDScript VM (2315)
// run under a condition variable's wait (672).
const ENGINE = [
  [[47402], [9528], [69057], "audio: the dummy driver's mix thread (AudioDriverDummy::thread_func)"],
  [[30182], [2315, 672], "WorkerThreadPool: a pool thread"],
  [[37637], "IP: the name resolver's thread"],
];

// ----- the page: each engine frame's length (a rAF callback's), for stalls
function instrument() {
  const log = window.__frames = [];
  const real = window.requestAnimationFrame.bind(window);
  let inner = real;
  const timed = (cb) => (time) => {
    const t0 = performance.now();
    try { cb(time); } finally {
      log.push([t0, performance.now() - t0]);
      if (log.length > 40000) log.splice(0, 20000);
    }
  };
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (cb) => at(timed(cb)); },
    set(f) { inner = f; },
  });
}

const browser = await launch();
const context = await browser.newContext(phone
  ? { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true }
  : { viewport: { width: 1400, height: 900 } });
await context.addInitScript(instrument);
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
const cdp = await context.newCDPSession(page);
const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const now = () => page.evaluate(() => performance.now());
const frames = (from, to = 1e12) => page.evaluate(([a, b]) => window.__frames.filter(([t]) => t >= a && t <= b), [from, to]);
const longest = (f) => Math.round(f.reduce((m, [, ms]) => Math.max(m, ms), 0));
const load = () => readFileSync("/proc/loadavg", "utf8").split(" ").slice(0, 3).join(" ");

const row = { url, profile, load: { start: load() }, firsts: {}, errors };
console.log(`${profile}: ${url}  load ${row.load.start}`);
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
let view = null;
for (let n = 0; n < START_MS / 500 && !view; n++) {
  view = (await controls()).view;
  if (!view) await page.waitForTimeout(500);
}
if (!view) {
  console.log("FAIL the app never showed the model's view");
  await browser.close();
  process.exit(1);
}
// Settled: the packs fetched and written and the bin's pictures drawn;
// twenty seconds is past all of it on this box (idle_check).
await page.waitForTimeout(20000);
const renderer = pageRenderer();
row.renderer = renderer;

// ----- standing still, a model open (the example the app opens with)
row.load.idle = load();
let a = snapshot(renderer);
await page.waitForTimeout(idleS * 1000);
row.idle = spent(a, snapshot(renderer));

// ----- building
const PARTS = ["3001", "3020", "3023b", "3010", "3039", "3004", "3068b", "3022"];
async function search(id) {
  let c = await controls();
  // On a phone the bin is a sheet, opened by Parts and gone with the pick.
  if (phone && !c["part search"] && c.phone_parts) {
    await page.touchscreen.tap(c.phone_parts.x, c.phone_parts.y);
    for (let n = 0; n < 40 && !c["part search"]; n++) { await page.waitForTimeout(250); c = await controls(); }
    await page.waitForTimeout(1000); // told once it has stayed put a publish
    c = await controls();
  }
  const field = c["part search"];
  if (!field) { console.log(`  (no part search; the controls: ${Object.keys(c).slice(0, 60).join(", ")})`); return NaN; }
  if (phone) await page.touchscreen.tap(field.x, field.y); else await page.mouse.click(field.x, field.y);
  await page.waitForTimeout(450);
  await page.keyboard.press("Control+a");
  await page.waitForTimeout(150);
  const t0 = await now();
  await page.keyboard.type(id, { delay: 40 });
  for (let n = 0; n < 200; n++) {
    const s = await state();
    if (Array.isArray(s.found) && s.found[0] === id) return (await now()) - t0;
    await page.waitForTimeout(50);
  }
  console.log(`  (the search for ${id} listed ${JSON.stringify(((await state()).found || []).slice(0, 3))} first)`);
  await page.screenshot({ path: `${out}/search_${id}.png`, timeout: 120000 }).catch(() => {});
  return NaN;
}
// The first tile taken, whatever the search listed first (3023 lists 3023b).
async function pick() {
  await page.waitForTimeout(1200); // a tile is told once it has stayed put a publish
  const tile = (await controls())["first part"];
  const id = String(((await state()).found || [])[0] || "");
  if (!tile || !id) return NaN;
  const t0 = await now();
  if (phone) await page.touchscreen.tap(tile.x, tile.y); else await page.mouse.click(tile.x, tile.y);
  if (!phone) await page.mouse.move(view.x, view.y, { steps: 4 });
  for (let n = 0; n < 300; n++) {
    const s = await state();
    if (String(s.held || "") === id) return (await now()) - t0;
    await page.waitForTimeout(50);
  }
  return NaN;
}
const spots = (k) => [view.x - 120 + 60 * (k % 5), view.y + (phone ? 120 : 200) + 30 * Math.floor(k / 5) % 3];
async function put(k) {
  const [x, y] = spots(k);
  if (phone) { await page.touchscreen.tap(x, y); } else {
    await page.mouse.move(x, y, { steps: 3 });
    await page.waitForTimeout(250);
    await page.mouse.click(x, y);
  }
  await page.waitForTimeout(400);
}
async function drag(k) {
  const [x, y] = spots(k);
  const t0 = await now();
  await page.mouse.move(x, y, { steps: 2 });
  await page.mouse.down();
  for (let n = 1; n <= 8; n++) {
    await page.mouse.move(x + 6 * n, y - 3 * n);
    await page.waitForTimeout(50);
  }
  await page.mouse.up();
  await page.waitForTimeout(500);
  return longest(await frames(t0));
}
row.load.build = load();
const bricks0 = (await state()).bricks;
a = snapshot(renderer);
const until = Date.now() + buildS * 1000;
let k = 0;
let round = 0;
while (Date.now() < until) {
  const id = PARTS[round % PARTS.length];
  const sought = await search(id);
  const held = await pick();
  if (round === 0) { row.firsts.search_ms = Math.round(sought); row.firsts.part_ms = Math.round(held); }
  for (let n = 0; n < 3 && Date.now() < until; n++) await put(k++);
  const select = phone && (await controls()).phone_select;
  if (select) await page.touchscreen.tap(select.x, select.y); else await page.keyboard.press("Escape");
  await page.waitForTimeout(300);
  if (!phone && Date.now() < until) {
    const worst = await drag(k - 1);
    if (round === 0) row.firsts.drag_longest_frame_ms = worst;
    await page.mouse.move(view.x, view.y);
    await page.mouse.wheel(0, round % 2 ? -120 : 120);
  }
  round += 1;
}
row.build = spent(a, snapshot(renderer));
row.build.rounds = round;
row.build.parts_put = k;
await page.waitForTimeout(1000);
row.build.bricks = [bricks0, (await state()).bricks];

// ----- naming the workers: a few seconds of V8's sampled profile
const roles = {};
try {
  await cdp.send("Tracing.start", { transferMode: "ReturnAsStream", streamFormat: "json",
    traceConfig: { recordMode: "recordAsMuchAsPossible", includedCategories: ["-*", "v8.execute", "disabled-by-default-v8.cpu_profiler"] } });
  await page.mouse.move(view.x + 5, view.y + 5);
  await page.waitForTimeout(4000);
  const complete = new Promise((resolve) => cdp.once("Tracing.tracingComplete", resolve));
  await cdp.send("Tracing.end");
  const { stream } = await complete;
  let text = "";
  for (;;) {
    const { data, eof, base64Encoded } = await cdp.send("IO.read", { handle: stream, size: 1 << 22 });
    if (data) text += base64Encoded ? Buffer.from(data, "base64").toString() : data;
    if (eof) break;
  }
  writeFileSync(`${out}/naming_trace.json`, text);
  const events = JSON.parse(text);
  const list = Array.isArray(events) ? events : events.traceEvents || [];
  const tidOf = {};
  for (const e of list) if (e.name === "Profile") tidOf[`${e.pid}:${e.id}`] = e.tid;
  const seen = {};
  for (const e of list) {
    if (e.name !== "ProfileChunk") continue;
    const tid = tidOf[`${e.pid}:${e.id}`];
    const nodes = (((e.args || {}).data || {}).cpuProfile || {}).nodes || [];
    for (const n of nodes) {
      const cf = n.callFrame || {};
      const w = /wasm-function\[(\d+)\]/.exec(cf.functionName || "") || /^\$?(\d+)$/.exec(cf.functionName || "");
      const name = w && String(cf.url || "").startsWith("wasm://") ? Number(w[1]) : cf.functionName;
      (seen[tid] = seen[tid] || new Set()).add(name);
      if (cf.url && !String(cf.url).startsWith("wasm://")) seen[tid].add(`url:${cf.url}`);
    }
  }
  for (const [tid, names] of Object.entries(seen)) {
    const engine = ENGINE.find((e) => e.slice(0, -1).some((all) => all.every((fn) => names.has(fn))));
    if (engine) { roles[tid] = engine[engine.length - 1]; continue; }
    const urls = [...names].filter((n) => typeof n === "string" && n.startsWith("url:blob:"));
    if (urls.length) roles[tid] = "the page's own JS worker (a blob: the pack fetcher or the connector's clock)";
  }
} catch (e) {
  console.log(`  (no trace to name the workers: ${String(e).split("\n")[0]})`);
}
const named = (r) => roles[r.tid] || (r.tid === renderer ? "the page's main thread (the engine's frames, WebGL calls)"
  : r.comm === "DedicatedWorker" ? "a worker with nothing sampled (an unused engine thread, or an idle JS worker)" : `browser: ${r.comm}`);
for (const w of [row.idle, row.build]) for (const r of w.threads) r.role = named(r);

// ----- said
function say(what, w) {
  const page = Math.round(w.threads.reduce((s, r) => s + r.pct, 0) * 10) / 10;
  w.page = page;
  console.log(`\n${what}, ${w.seconds} s: the page's renderer ${page}% of a core; GPU process ${w.procs["gpu-process"] ?? "-"}%, browser ${w.procs.browser ?? "-"}%`);
  const rows = w.threads.filter((r) => r.pct >= 0.5 || r.comm === "DedicatedWorker" || r.tid === renderer)
    .sort((x, y) => y.pct - x.pct);
  for (const r of rows) console.log(`  ${String(r.pct).padStart(6)}%  ${String(r.tid).padEnd(8)} ${r.role}`);
  const small = w.threads.filter((r) => !rows.includes(r));
  if (small.length) console.log(`  ${String(Math.round(small.reduce((s, r) => s + r.pct, 0) * 10) / 10).padStart(6)}%  the other ${small.length} threads together`);
}
say(`standing still (load ${row.load.idle})`, row.idle);
say(`building (load ${row.load.build}): ${row.build.rounds} parts searched and taken, ${row.build.parts_put} clicks to put them down, `
  + `the model ${row.build.bricks[0]} to ${row.build.bricks[1]} bricks`, row.build);
console.log(`\nfirsts: search ${row.firsts.search_ms} ms, part in hand ${row.firsts.part_ms} ms`
  + `${phone ? "" : `, longest frame of the first drag ${row.firsts.drag_longest_frame_ms} ms`}`);
if (errors.length) console.log(`page errors: ${errors.slice(0, 3).join(" | ")}`);
writeFileSync(`${out}/thread_cpu.json`, JSON.stringify(row, null, 1));
const worker = row.idle.threads.filter((r) => r.comm === "DedicatedWorker").sort((x, y) => y.pct - x.pct)[0];
const ok = worker ? worker.pct <= most : false;
console.log(`${ok ? "ok  " : "FAIL"} no worker over ${most}% of a core standing still (the most: ${worker ? `${worker.pct}%, ${worker.role}` : "no workers found"})`);
await browser.close();
process.exit(ok ? 0 : 1);
