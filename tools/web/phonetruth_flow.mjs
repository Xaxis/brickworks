// Does the studio really work on phones (phonetruth, 2026-11-18)? Every
// release checks it at a phone's size by finger (phone_flow, phonewalk_flow,
// tablet_flow), but always in desktop Chromium pretending to be a phone, on
// this box's fast CPU. This measures it on what is closest here to a real
// phone's engine, speed and network, and writes the table docs/PHONE.md
// keeps:
//
//   chromium   today's checks: Chromium as a phone, 390 x 844 at 3x
//   iphone13   Playwright's WebKit, the engine of every iPhone browser, as an
//   iphone15   iPhone 13 or 15 (Safari's window, its bars taken off: 390 x 664
//              and 393 x 659), drawing in software (Mesa's llvmpipe)
//   cpu4       Chromium as a phone with its main thread held to a quarter of
//   cpu6       this box's speed (CDP Emulation.setCPUThrottlingRate), as a
//              mid-range and a slower Android phone, on DevTools' "Fast 4G"
//              (9 Mbps down, 1.5 up, 165 ms)
//
// On each, from a fresh profile kept on disk (so a return has its cache, as
// load_check keeps one; no route, which would turn the cache off, so the
// parts bucket is read as a visitor reads it):
//
//   load     the first visit, cold, to working: the phone's layout up
//            (phone_parts) and the car's 61 parts laid (awaited 0); and a
//            return, the same in a new tab of the same profile
//   frames   two fingers turning the view, on the car and on Orthanc (9,429
//            parts, /app?model=models/orthanc.ldr): every engine frame timed
//            in the page (the app's own work, apart from its time inside
//            WebGL) and the turn to a WebGL fence (browser.mjs fenced), so
//            what the drawing behind the page cost is counted too
//   ladder   gallery models opened in the viewer (/app?view=<id>, where a
//            model's page leads), smallest first: each held open 20 s and
//            turned, until one does not open within --model-s or the tab
//            dies; the largest that opened and stayed open is the finding
//   beyond   past the gallery's largest: Wizard's Tower --beyond times over
//            (2,3,5 by default), side by side, as one shared model whose
//            reply is handed to the page, on the same ladder, so what a
//            bigger model costs is measured rather than guessed
//
// Memory throughout, every 2 s, its peak in each: the Wasm memory's size (the
// engine's heap, from the WebAssembly.Memory the page made), the JS heap
// (Chromium's, by CDP; WebKit says none), and the content process's own
// memory from /proc (Pss and Private_Dirty of the renderer, or WebKit's
// WPEWebProcess, whose WebGL is in software here and so in its own memory,
// as it is in a phone's WebContent footprint), against the per-tab limits in
// docs/PHONE.md.
//
//   set -a; . ./.env; set +a
//   node tools/web/phonetruth_flow.mjs --url=https://brickworks.diy/app --out=DIR \
//     [--configs=chromium,iphone13,iphone15,cpu4,cpu6] [--steps=load,frames,ladder,beyond]
//     [--ladder=ID:PARTS,…] [--beyond=2,3,5] [--model-s=360]
//   node tools/web/phonetruth_flow.mjs --table --out=DIR
//     the table from DIR/<config>.json and the walks' DIR/walk-<config>/phonewalk.json
//
// The walk itself is phonewalk_flow.mjs with --engine, --device, --cpu and
// --net (bench/results/phonetruth-2026-11-18/run_walks.sh). Run it all under
// heavy. Writes DIR/<config>.json as each config ends, and DIR/phonetruth.md.
// Exits 0 when every config named ran, 1 when one could not start at all.
import { chromium, devices, webkit } from "playwright";
import { fenced, SOFTWARE, START_MS, WEBKIT_SOFTWARE } from "./browser.mjs";
import { canSignIn, signInContext } from "./session.mjs";
import { fingersOf } from "./fingers.mjs";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir, loadavg } from "node:os";
import { join, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || "shots/phonetruth"));
mkdirSync(out, { recursive: true });

// DevTools' own "Fast 4G" (phonewalk_flow.mjs NETS).
const FAST4G = { offline: false, downloadThroughput: 9e6 / 8 * 0.9, uploadThroughput: 1.5e6 / 8 * 0.9, latency: 60 * 2.75 };
const PHONE = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true };
const without = ({ defaultBrowserType, ...rest }) => rest;
export const CONFIGS = {
  chromium: { engine: "chromium", said: "Chromium as a phone (today's checks)", context: PHONE },
  iphone13: { engine: "webkit", said: "WebKit as an iPhone 13", device: "iPhone 13", context: without(devices["iPhone 13"]) },
  iphone15: { engine: "webkit", said: "WebKit as an iPhone 15", device: "iPhone 15", context: without(devices["iPhone 15"]) },
  cpu4: { engine: "chromium", said: "Chromium, CPU 1/4, Fast 4G", cpu: 4, net: "fast4g", context: PHONE },
  cpu6: { engine: "chromium", said: "Chromium, CPU 1/6, Fast 4G", cpu: 6, net: "fast4g", context: PHONE },
};
// The gallery on 2026-11-18 (GET /api/share?op=gallery), smallest to largest
// of the sizes a person meets; Wizard's Tower is its largest.
const LADDER = [
  ["rtqf6Xtpb4", 151, "A friendly maintenance robot"],
  ["ZpvBGwuKRu", 362, "21011 Brandenburg Gate"],
  ["XqW6brmPQs", 741, "6080 King's Castle"],
  ["uoRqCfPWYJ", 1032, "A barn owl"],
  ["kfpYMjke5U", 2497, "A castle, from one sentence"],
  ["EzEXhtXE2C", 10101, "Wizard's Tower"],
];
const ladder = args.ladder ? String(args.ladder).split(",").map((one) => {
  const [id, parts] = one.split(":");
  return [id, Number(parts), id];
}) : LADDER;
const MODEL_MS = Number(args["model-s"] || 360) * 1000;
// Orthanc is the gallery's Wizard's Tower: models/orthanc.ldr lays 10,101.
const ORTHANC = 10101;
// Towers0002…: Wizard's Tower K times over (step beyond).
const TOWER = "EzEXhtXE2C";
const TOWERS = /^Towers(\d{4})$/;
const towersId = (k) => `Towers${String(k).padStart(4, "0")}`;
// The most a first visit or a return may take: a phone held to a sixth of
// this box on Fast 4G is given a quarter of an hour.
const VISIT_MS = 15 * 60 * 1000;

const t0 = Date.now();
const said = (line) => console.log(`  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);

if (args.table) {
  writeTable();
  process.exit(0);
}
if (!args.url) {
  console.log("phonetruth_flow: --url=<origin>/app is required (or --table)");
  process.exit(2);
}
if (!canSignIn()) {
  console.log("phonetruth_flow: no Supabase keys in the environment (set -a; . ./.env; set +a)");
  process.exit(2);
}
const base = String(args.url);
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const withBypass = (u) => (bypass
  ? `${u}${u.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true` : u);
const app = (query = "") => new URL(`${new URL(base).pathname}${query}`, base).href;
const names = String(args.configs || Object.keys(CONFIGS).join(",")).split(",");
const steps = new Set(String(args.steps || "load,frames,ladder").split(","));
if (steps.has("beyond")) {
  steps.add("ladder");
  for (const k of String(args.beyond || "2,3,5").split(",").map(Number).filter((n) => Number.isInteger(n) && n >= 2 && n < 10000)) {
    ladder.push([towersId(k), ORTHANC * k, `Wizard's Tower ×${k}`]);
  }
}
// The tower's own reply, the towers made from it (step beyond).
const towerReply = ladder.some(([id]) => TOWERS.test(id))
  ? await fetch(`${new URL(base).origin}/api/share?id=${TOWER}`, { headers: bypass ? { "x-vercel-protection-bypass": bypass } : {} })
    .then((reply) => (reply.ok ? reply.json() : null)).catch(() => null)
  : null;
/// Wizard's Tower [k] times over, 2,000 LDU apart in a row: one model
/// whose first file places the tower's own (wizard's_tower.ldr) [k] times.
function towers(k) {
  const model = String(towerReply.model);
  const main = /^0 FILE (.+)$/m.exec(model)[1].trim();
  const head = [`0 FILE wizard's_towers_x${k}.ldr`, `0 Wizard's Tower x${k}`, `0 Name: wizard's_towers_x${k}.ldr`, "0 Author: Brickworks"];
  for (let i = 0; i < k; i += 1) head.push(`1 16 ${i * 2000} 0 0 1 0 0 0 1 0 0 0 1 ${main}`);
  return { ...towerReply, id: towersId(k), name: `Wizard's Tower ×${k}`, parts: ORTHANC * k, versions: [], builds: 0,
    model: `${head.join("\n")}\n0 NOFILE\n${model}` };
}
let broken = 0;
for (const name of names) {
  const config = CONFIGS[name];
  if (!config) {
    console.log(`no config is named ${name}; there are ${Object.keys(CONFIGS).join(", ")}`);
    broken += 1;
    continue;
  }
  config.name = name;
  console.log(`\n${name}: ${config.said}`);
  const result = { name, said: config.said, engine: config.engine, device: config.device || "", cpu: config.cpu || 1,
    net: config.net || "", url: base, at: new Date().toISOString(), load: loadavg()[0] };
  try {
    await measure(config, result);
  } catch (trouble) {
    result.threw = String(trouble.stack || trouble).slice(0, 600);
    console.log(`  FAIL  ${name} stopped: ${result.threw}`);
    if (!result.cold) broken += 1;
  }
  result.load_after = loadavg()[0];
  writeFileSync(join(out, `${name}.json`), JSON.stringify(result, null, 2));
}
writeTable();
process.exit(broken ? 1 : 0);

// -- one config ---------------------------------------------------------------

async function measure(config, result) {
  const dir = mkdtempSync(join(tmpdir(), "phonetruth-"));
  const type = config.engine === "webkit" ? webkit : chromium;
  const options = config.engine === "webkit"
    ? { env: { ...process.env, ...WEBKIT_SOFTWARE } }
    : { args: SOFTWARE, realStore: true };
  const context = await type.launchPersistentContext(dir, { ...options, ...config.context });
  try {
    await signInContext(context);
    if (towerReply) {
      await context.route((url) => url.pathname === "/api/share" && TOWERS.test(url.searchParams.get("id") || "")
        && !url.searchParams.get("op"), (route) => {
        const k = Number(TOWERS.exec(new URL(route.request().url()).searchParams.get("id"))[1]);
        return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(towers(k)) });
      });
    }
    await context.addInitScript(instrument);
    // WebKit's MiniBrowser ends with its last page, so its first is kept
    // (blank; the sampler reads the biggest content process alone).
    if (config.engine !== "webkit") for (const page of context.pages()) await page.close().catch(() => {});
    const memory = sampler(context, config);
    // The first visit, cold, and a return.
    result.cold = await visit(context, config, withBypass(app()), memory, "cold", { ms: VISIT_MS });
    said(`cold: ${seconds(result.cold.working)} to working, ${mb(result.cold.bytes)} over the wire`);
    if (!Number.isFinite(result.cold.working)) throw new Error("the first visit never came to working");
    const back = await visit(context, config, app(), memory, "return", { keep: true, ms: VISIT_MS });
    result.back = back.row;
    said(`return: ${seconds(result.back.working)} to working`);
    if (steps.has("frames") && Number.isFinite(result.back.working)) {
      result.frames = {};
      result.frames.car = await orbit(back.page, config);
      said(`car: ${frameSaid(result.frames.car)}`);
      await back.page.close().catch(() => {});
      const big = await visit(context, config, app("?model=models/orthanc.ldr"), memory, "orthanc",
        { keep: true, parts: ORTHANC, ms: MODEL_MS * 2 });
      result.orthanc = big.row;
      if (Number.isFinite(big.row.working)) {
        result.frames.orthanc = await orbit(big.page, config);
        said(`Orthanc: open in ${seconds(big.row.working)}; ${frameSaid(result.frames.orthanc)}`);
      } else {
        said(`Orthanc: not open within ${MODEL_MS * 2 / 1000} s (${big.row.why || ""})`);
      }
      await big.page.close().catch(() => {});
    } else {
      await back.page.close().catch(() => {});
    }
    if (steps.has("ladder")) {
      result.ladder = [];
      for (const [id, parts, name] of ladder) {
        const step = await visit(context, config, app(`?view=${id}`), memory, `view ${id}`,
          { keep: true, parts, viewer: true, ms: MODEL_MS });
        const row = { id, parts, name, ...step.row };
        if (Number.isFinite(row.working) && !row.crashed) {
          // Held open, and turned: does it stay?
          await step.page.waitForTimeout(20000);
          row.turn = await orbit(step.page, config, 1).catch((trouble) => ({ why: String(trouble.message).slice(0, 200) }));
          row.after = await step.page.evaluate(() => (window.brickworksState || {}).bricks).catch(() => null);
          row.stayed = !step.crashed() && row.after !== null;
          row.peak = memory.peak(`view ${id}`);
        }
        result.ladder.push(row);
        said(`${name} (${parts} parts): ${Number.isFinite(row.working) ? `open in ${seconds(row.working)}` : `not open (${row.why})`}`
          + `${row.stayed === false ? ", and the tab did not stay" : ""}; peak ${mb(row.peak?.process?.pss)} Pss, `
          + `${mb(row.peak?.wasm)} Wasm`);
        await step.page.close().catch(() => {});
        if (!row.stayed) break;
      }
    }
    result.peaks = memory.all();
    memory.stop();
  } finally {
    await context.close().catch(() => {});
    rmSync(dir, { recursive: true, force: true });
  }
}

// In the page before anything runs: every engine frame timed (cad_frames.mjs's
// instrument), the Wasm memory the engine makes kept, and the visit counter
// told this browser is not a visitor (its own ov_ignore).
function instrument() {
  try { localStorage.setItem("ov_ignore", "1"); } catch {}
  // Each WebGL call is timed only while a turn is (perf.on): it costs a
  // clock read a call, which a first visit's timing should not carry.
  const perf = { frames: [], on: false };
  window.cadFrames = perf;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  let gl = 0;
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    gl = 0;
    const began = performance.now();
    try { callback(time); } finally {
      inside = false;
      perf.frames.push([began, performance.now() - began, gl]);
      if (perf.frames.length > 40000) perf.frames.splice(0, 20000);
    }
  };
  const context = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(context)) {
    const d = Object.getOwnPropertyDescriptor(context, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    context[name] = function (...a) {
      if (!perf.on) return was.apply(this, a);
      const began = performance.now();
      try { return was.apply(this, a); } finally { gl += performance.now() - began; }
    };
  }
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
  // The engine's memory: made by the page with threads, exported by the
  // module without.
  const memories = [];
  const Real = WebAssembly.Memory;
  function Memory(descriptor) {
    const made = new Real(descriptor);
    memories.push(made);
    return made;
  }
  Memory.prototype = Real.prototype;
  WebAssembly.Memory = Memory;
  for (const name of ["instantiate", "instantiateStreaming"]) {
    const was = WebAssembly[name];
    if (typeof was !== "function") continue;
    WebAssembly[name] = function (...a) {
      return was.apply(this, a).then((got) => {
        try {
          for (const value of Object.values((got.instance || got).exports || {})) if (value instanceof Real) memories.push(value);
        } catch {}
        return got;
      });
    };
  }
  window.brickworksWasmBytes = () => memories.reduce((most, m) => Math.max(most, m.buffer.byteLength), 0);
}

// -- a visit ------------------------------------------------------------------

/// [url] opened in a new tab of [context] and timed, by the page's own clock
/// from its navigation, to: its first byte (responseStart), the engine
/// started (the shell's screen gone, brickworksBoot.ui), the phone's layout
/// up (phone_parts), and working: the model's parts all laid (awaited 0, and
/// [parts] standing). A viewer's working is its "ready". {row, page,
/// crashed()} with { keep }, else the row alone.
async function visit(context, config, url, memory, phase, { keep = false, parts = 61, viewer = false, ms = START_MS } = {}) {
  const page = await context.newPage();
  let crashed = false;
  page.on("crash", () => { crashed = true; });
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => { if (/SCRIPT ERROR|USER ERROR|out of memory|Aborted/i.test(m.text())) errors.push(m.text().slice(0, 240)); });
  let cdp = null;
  if (config.engine === "chromium") {
    cdp = await context.newCDPSession(page);
    if (config.cpu) await cdp.send("Emulation.setCPUThrottlingRate", { rate: config.cpu });
    if (config.net) {
      await cdp.send("Network.enable");
      await cdp.send("Network.emulateNetworkConditions", FAST4G);
    }
  }
  page.phoneCdp = cdp;
  memory.watch(page, cdp, phase);
  const row = { url: url.replace(/x-vercel-protection-bypass=[^&]+&?/, ""), parts };
  const began = Date.now();
  await page.goto(url, { waitUntil: "commit", timeout: 180000 }).catch((trouble) => { row.why = String(trouble.message).slice(0, 160); });
  const deadline = began + ms;
  for (;;) {
    const now = await page.evaluate(() => {
      const s = window.brickworksState || {};
      const c = window.brickworksControls || {};
      const v = (window.brickworksShare || {}).view || {};
      const boot = window.brickworksBoot || {};
      const nav = performance.getEntriesByType("navigation")[0] || {};
      return { now: performance.now(), first: nav.responseStart || NaN, ui: boot.ui || NaN, phone: Boolean(c.phone_parts),
        bricks: s.bricks || 0, awaited: s.awaited ?? -1, view: v.state || "", note: document.getElementById("note")?.textContent || "" };
    }).catch(() => null);
    if (now) {
      if (Number.isFinite(now.first)) row.first_byte = now.first;
      if (Number.isFinite(now.ui) && !row.engine) row.engine = now.ui;
      if (now.phone && !row.layout) row.layout = now.now;
      row.bricks = now.bricks;
      row.note = now.note;
      const laid = now.awaited === 0 && now.bricks >= parts;
      if (viewer ? now.view === "ready" && laid : now.phone && laid) {
        row.working = now.now;
        break;
      }
      if (viewer && (now.view === "gone" || now.view === "failed")) {
        row.why = `the viewer said ${now.view}`;
        break;
      }
      if (/missing|could not|failed/i.test(now.note || "") && !now.phone) {
        row.why = `the loader said "${now.note}"`;
        break;
      }
    }
    if (crashed) {
      row.why = "the tab died (crash)";
      break;
    }
    if (Date.now() > deadline) {
      row.why = row.why || `not within ${Math.round(ms / 1000)} s (${now ? `${now.bricks} parts, ${now.awaited} awaited` : "no answer"})`;
      break;
    }
    await page.waitForTimeout(250);
  }
  if (!Number.isFinite(row.working)) row.working = NaN;
  row.crashed = crashed;
  // What came over the wire: the page's own resources, as sent (a worker's
  // are not the page's, nor in its list).
  row.bytes = await page.evaluate(() => performance.getEntriesByType("resource")
    .concat(performance.getEntriesByType("navigation"))
    .reduce((n, r) => n + (r.transferSize || 0), 0)).catch(() => NaN);
  // When the engine's own files had come (the wasm and the pack): from
  // there to the engine's window is what a phone takes to start it, which
  // the loader's estimate adds to the download (api/_phone.js phone_start_s).
  row.files = await page.evaluate(() => Math.max(0, ...performance.getEntriesByType("resource")
    .filter((r) => /\/index\.(wasm|pck)(\?|$)/.test(r.name)).map((r) => r.responseEnd))).catch(() => NaN);
  row.peak = memory.peak(phase);
  row.errors = errors.slice(0, 5);
  await page.screenshot({ path: join(out, `${config.name || ""}${phase.replace(/\W+/g, "_")}.png`), timeout: 60000 }).catch(() => {});
  if (keep) return { row, page, crashed: () => crashed };
  await page.close().catch(() => {});
  return row;
}

// -- frames -------------------------------------------------------------------

/// Two fingers turning the view across the middle of the canvas and back,
/// [sweeps] times, as a person turns it on a phone (phone_flow 9): every
/// engine frame in it, and the whole turn to a fence.
async function orbit(page, config, sweeps = 3) {
  const touch = fingersOf(page, page.phoneCdp || null);
  const box = await page.evaluate(() => {
    const r = (document.getElementById("canvas") || document.querySelector("canvas")).getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height * 0.42, w: r.width };
  });
  // The drawing caught up first, and the view drawn once before it is timed.
  await fenced(page, 300);
  const from = await page.evaluate(() => { window.cadFrames.on = true; return performance.now(); });
  const span = Math.min(120, box.w * 0.3);
  for (let n = 0; n < sweeps; n++) {
    for (const [a, b] of [[-span, span], [span, -span]]) {
      await touch("touchStart", [{ x: box.x + a - 30, y: box.y }, { x: box.x + a + 30, y: box.y }]);
      for (let i = 1; i <= 20; i++) {
        const x = box.x + a + ((b - a) * i) / 20;
        await touch("touchMove", [{ x: x - 30, y: box.y }, { x: x + 30, y: box.y }]);
        await page.waitForTimeout(16);
      }
      await touch("touchEnd", []);
    }
  }
  const asked = await page.evaluate(() => performance.now());
  const drawn = await fenced(page, 600);
  const frames = await page.evaluate((t) => { window.cadFrames.on = false; return window.cadFrames.frames.filter(([at]) => at >= t); }, from);
  const own = frames.map(([, d, gl]) => d - gl).sort((a, b) => a - b);
  const whole = frames.map(([, d]) => d).sort((a, b) => a - b);
  const q = (list, p) => (list.length ? list[Math.min(list.length - 1, Math.floor(p * list.length))] : NaN);
  const wall = drawn.passed - from;
  return { frames: frames.length, asked_ms: Math.round(asked - from), wall_ms: Math.round(wall),
    fps: frames.length ? Math.round((frames.length / (wall / 1000)) * 10) / 10 : 0,
    own_p50: round(q(own, 0.5)), own_p95: round(q(own, 0.95)), whole_p95: round(q(whole, 0.95)), worst: round(whole.at(-1)) };
}

// -- memory -------------------------------------------------------------------

/// Every 2 s: the Wasm memory and the JS heap of the page being watched, and
/// the content process's own memory, each phase's peak kept.
function sampler(context, config) {
  const peaks = {};
  let watched = null;
  let phase = "";
  const keep = (key, value) => {
    if (!Number.isFinite(value)) return;
    const p = peaks[phase] || (peaks[phase] = { process: {} });
    if (key.startsWith("process.")) {
      const k = key.slice(8);
      p.process[k] = Math.max(p.process[k] || 0, value);
    } else {
      p[key] = Math.max(p[key] || 0, value);
    }
  };
  const timer = setInterval(async () => {
    if (!watched) return;
    const { page, cdp } = watched;
    const wasm = await page.evaluate(() => (window.brickworksWasmBytes ? window.brickworksWasmBytes() : NaN)).catch(() => NaN);
    keep("wasm", wasm);
    if (cdp) {
      const heap = await cdp.send("Runtime.getHeapUsage").catch(() => null);
      if (heap) keep("js_heap", heap.usedSize);
    }
    const tree = processes(config.engine);
    keep("process.pss", tree.content.pss);
    keep("process.dirty", tree.content.dirty);
    keep("process.gpu_pss", tree.gpu.pss);
    keep("process.all_pss", tree.all);
  }, 2000);
  return {
    watch(page, cdp, name) { watched = { page, cdp }; phase = name; },
    peak: (name) => peaks[name] || null,
    all: () => peaks,
    stop: () => clearInterval(timer),
  };
}

/// This process's browser and its children from /proc: the biggest content
/// process (Chromium's renderer, WebKit's WPEWebProcess), the GPU process,
/// and all of them, in bytes (smaps_rollup).
function processes(engine) {
  const kids = new Map();
  for (const d of readdirSync("/proc")) {
    if (!/^\d+$/.test(d)) continue;
    try {
      const parent = readFileSync(`/proc/${d}/stat`, "utf8").split(") ")[1].split(" ")[1];
      if (!kids.has(parent)) kids.set(parent, []);
      kids.get(parent).push(d);
    } catch {}
  }
  const all = [];
  const walk = (pid) => { for (const k of kids.get(pid) || []) { all.push(k); walk(k); } };
  walk(String(process.pid));
  const content = { pss: 0, dirty: 0 };
  const gpu = { pss: 0 };
  let total = 0;
  for (const pid of all) {
    let line = "";
    let rollup = "";
    try {
      line = readFileSync(`/proc/${pid}/cmdline`, "utf8");
      rollup = readFileSync(`/proc/${pid}/smaps_rollup`, "utf8");
    } catch { continue; }
    const kb = (key) => Number((rollup.match(new RegExp(`^${key}:\\s+(\\d+) kB`, "m")) || [])[1] || 0) * 1024;
    const pss = kb("Pss");
    const dirty = kb("Private_Dirty");
    total += pss;
    const isContent = engine === "webkit" ? /WebProcess/.test(line.split("\0")[0]) : /--type=renderer/.test(line);
    const isGpu = engine === "webkit" ? /GPUProcess/.test(line.split("\0")[0]) : /--type=gpu-process/.test(line);
    if (isContent && pss > content.pss) Object.assign(content, { pss, dirty });
    if (isGpu) gpu.pss = Math.max(gpu.pss, pss);
  }
  return { content, gpu, all: total };
}

// -- the table ----------------------------------------------------------------

function writeTable() {
  const rows = Object.keys(CONFIGS).map((name) => [name, join(out, `${name}.json`)]).filter(([, f]) => existsSync(f))
    .map(([name, f]) => ({ name, ...JSON.parse(readFileSync(f, "utf8")) }));
  const walks = Object.fromEntries(Object.keys(CONFIGS).map((name) => [name, walkOf(name)]));
  const lines = [
    `# The studio on phones: what was measured`,
    ``,
    `Written by tools/web/phonetruth_flow.mjs on ${new Date().toISOString().slice(0, 16)}Z from ${out}.`,
    `Memory is each phase's peak: the content process's Pss (WebKit's WPEWebProcess, Chromium's renderer),`,
    `the Wasm memory the engine had grown to, and Chromium's JS heap. Times are from the page's navigation.`,
    ``,
    `| | ${rows.map((r) => r.said).join(" | ")} |`,
    `|---|${rows.map(() => "---").join("|")}|`,
  ];
  const cell = (fn) => rows.map((r) => { try { return fn(r) ?? "–"; } catch { return "–"; } }).join(" | ");
  lines.push(`| first visit, cold, to working | ${cell((r) => seconds(r.cold?.working))} |`);
  lines.push(`| … engine's files had come | ${cell((r) => seconds(r.cold?.files || NaN))} |`);
  lines.push(`| … engine started | ${cell((r) => seconds(r.cold?.engine))} |`);
  lines.push(`| … started once its files had come | ${cell((r) => seconds(r.cold?.files ? r.cold.engine - r.cold.files : NaN))} |`);
  lines.push(`| … over the wire | ${cell((r) => mb(r.cold?.bytes))} |`);
  lines.push(`| a return, to working | ${cell((r) => seconds(r.back?.working))} |`);
  lines.push(`| peak memory, first visit (Pss / Wasm / JS heap) | ${cell((r) => memSaid(r.cold?.peak))} |`);
  lines.push(`| Orthanc (10,101 parts) opened | ${cell((r) => (r.orthanc ? Number.isFinite(r.orthanc.working) ? seconds(r.orthanc.working) : `no: ${r.orthanc.why}` : null))} |`);
  lines.push(`| peak memory, Orthanc | ${cell((r) => memSaid(r.orthanc?.peak))} |`);
  lines.push(`| turning the car: frames/s; own work p95 | ${cell((r) => frameCell(r.frames?.car))} |`);
  lines.push(`| turning Orthanc: frames/s; own work p95 | ${cell((r) => frameCell(r.frames?.orthanc))} |`);
  lines.push(`| largest model open and kept | ${cell((r) => largest(r.ladder))} |`);
  // Each once: a run's beyond step adds its towers to LADDER itself.
  const climbed = new Map([...LADDER, ...[2, 3, 5].map((k) => [towersId(k), ORTHANC * k, `Wizard's Tower ×${k}`])]
    .map((rung) => [rung[0], rung]));
  for (const [id, parts, name] of climbed.values()) {
    if (!rows.some((r) => (r.ladder || []).some((s) => s.id === id))) continue;
    lines.push(`| … ${name} (${parts.toLocaleString("en-US")}) | ${cell((r) => {
      const step = (r.ladder || []).find((s) => s.id === id);
      if (!step) return null;
      return Number.isFinite(step.working) ? `${seconds(step.working)}${step.stayed === false ? ", died" : ""}; ${memSaid(step.peak)}`
        : `no: ${step.why}`;
    })} |`);
  }
  lines.push(`| the walk by finger: acts done | ${cell((r) => walks[r.name]?.summary)} |`);
  lines.push(`| box load at the start | ${cell((r) => (Number.isFinite(r.load) ? r.load.toFixed(0) : null))} |`);
  lines.push(``);
  for (const r of rows) {
    const w = walks[r.name];
    if (!w || !w.short.length) continue;
    lines.push(`## ${r.said}: what the walk could not do`, ``);
    for (const one of w.short) lines.push(`- **${one.id}**: ${one.why}`);
    lines.push(``);
  }
  const table = lines.join("\n");
  writeFileSync(join(out, "phonetruth.md"), `${table}\n`);
  console.log(`\n${table}`);
}

/// The walk's own result for [name]: how many acts were done, and those not.
function walkOf(name) {
  const file = join(out, `walk-${name}`, "phonewalk.json");
  if (!existsSync(file)) return null;
  const all = JSON.parse(readFileSync(file, "utf8"));
  const sizes = Object.values(all.results || all).filter((r) => r && r.rows);
  const rows = sizes.flatMap((size) => Object.entries(size.rows).map(([id, row]) => ({ id, ...row })));
  if (!rows.length) return { summary: sizes.some((s) => s.up === false) ? "never came up" : "none ran", short: [] };
  const done = rows.filter((r) => r.done).length;
  return { summary: `${done} of ${rows.length}`, short: rows.filter((r) => !r.done).map((r) => ({ id: r.id, why: r.why || "not done" })) };
}

function largest(steps) {
  const kept = (steps || []).filter((s) => Number.isFinite(s.working) && s.stayed);
  const last = kept.at(-1);
  return last ? `${last.name} (${last.parts.toLocaleString("en-US")})` : steps ? "none" : null;
}
function memSaid(p) {
  if (!p) return null;
  return `${mb(p.process?.pss)} / ${mb(p.wasm)} / ${p.js_heap ? mb(p.js_heap) : "–"}`;
}
function frameCell(f) {
  if (!f || f.why) return f?.why || null;
  return `${f.fps}/s; ${f.own_p95} ms`;
}
function frameSaid(f) {
  return f.why ? f.why : `${f.frames} frames over ${f.wall_ms} ms to the fence (${f.fps}/s), own work p50 ${f.own_p50} ms, p95 ${f.own_p95} ms, whole p95 ${f.whole_p95} ms`;
}
function seconds(ms) { return Number.isFinite(ms) ? `${(ms / 1000).toFixed(1)} s` : "–"; }
function mb(bytes) { return Number.isFinite(bytes) && bytes > 0 ? `${Math.round(bytes / 1e6)} MB` : "–"; }
function round(x) { return Number.isFinite(x) ? Math.round(x * 10) / 10 : NaN; }
