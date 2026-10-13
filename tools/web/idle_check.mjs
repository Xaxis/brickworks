// Does the web build stop drawing when nothing changes, and still draw what
// does? Loads the app in a real browser, lets it settle, and counts what an
// idle page costs: the engine's frames, the ones that asked WebGL to draw,
// the page's main thread and the CPU of every Chromium process.
//
//   set -a; . ./.env; set +a
//   node tools/web/idle_check.mjs --dir=build/web          a local export, served here
//   BW_BYPASS=… node tools/web/idle_check.mjs --url=<preview>/app
//
// The app drew every frame with nothing moving, sixty a second, which in a
// browser drawing in software is the rasteriser busy all the time and on a
// laptop's graphics card a fan and a battery (2026-10-11). Now it draws only
// what changed (IdleDraw). Then it does what a person does and requires each
// to be drawn, and the page to go quiet after: a wheel notch over the model,
// the - key, the pointer moving over the model with a part in hand.
//
// Fails past --most (1) frames drawn a second standing still, or a tenth of
// the engine's frames, or where a change was not drawn or the page did not
// go quiet again. Leaves idle.json
// and idle.png in --out (shots/idle).
//
// --floor=none (or grid) first puts the model on that floor, by View >
// Floor and the menu's keys: with no baseplate the ground catches the
// model's shadow, and that must cost nothing standing still either.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/idle";
mkdirSync(out, { recursive: true });
const seconds = Number(args.seconds || 15);
const most = Number(args.most || 1);
const after = Number(args.after || 20000);
const bypass = process.env.BW_BYPASS || "";

async function freePort() {
  return new Promise((done) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => { const { port } = s.address(); s.close(() => done(port)); });
  });
}

let server = null;
let url = args.url;
if (!url) {
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${args.dir || "build/web"}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}
let browser = null;
const stop = async (code) => {
  if (browser) await browser.close().catch(() => {});
  if (server) server.kill();
  process.exit(code);
};

// In the page before anything else runs: every engine frame, how long its
// callback ran, how much of that was inside WebGL, and how many draws it made.
function instrument() {
  const perf = { frames: [], cur: null, idleCalls: {} };
  window.brickworksIdle = perf;
  const real = window.requestAnimationFrame.bind(window);
  const timed = (callback) => (time) => {
    if (perf.cur) { callback(time); return; }
    const frame = { t0: performance.now(), draws: 0, gl: 0, calls: [] };
    perf.cur = frame;
    try { callback(time); } finally {
      perf.cur = null;
      // [start, length, inside WebGL, draws, WebGL calls]
      perf.frames.push([frame.t0, performance.now() - frame.t0, frame.gl, frame.draws, frame.calls.length]);
      // What a frame that drew nothing still asked of WebGL, by name.
      if (frame.draws === 0) for (const name of frame.calls) perf.idleCalls[name] = (perf.idleCalls[name] || 0) + 1;
      if (perf.frames.length > 20000) perf.frames.splice(0, 10000);
    }
  };
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
  const gl = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(gl)) {
    const d = Object.getOwnPropertyDescriptor(gl, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    const draw = /^draw(Arrays|Elements)(Instanced)?$/.test(name);
    gl[name] = function (...a) {
      const f = perf.cur;
      if (!f) return was.apply(this, a);
      if (draw) f.draws += 1;
      f.calls.push(name);
      const t0 = performance.now();
      try { return was.apply(this, a); } finally { f.gl += performance.now() - t0; }
    };
  }
}

// CPU time of the browser and every process under it, in seconds, by the
// kind of process: the page (renderer), and SwiftShader rasterising in the
// GPU process.
function chromiumCpu(root) {
  const children = new Map();
  const kind = (pid) => {
    try {
      const type = /--type=([a-z-]+)/.exec(readFileSync(`/proc/${pid}/cmdline`, "utf8"));
      return type ? type[1] : "browser";
    } catch { return "gone"; }
  };
  for (const name of readdirSync("/proc")) {
    if (!/^\d+$/.test(name)) continue;
    try {
      const stat = readFileSync(`/proc/${name}/stat`, "utf8");
      const fields = stat.slice(stat.lastIndexOf(")") + 2).split(" ");
      const parent = Number(fields[1]);
      if (!children.has(parent)) children.set(parent, []);
      children.get(parent).push([Number(name), Number(fields[11]) + Number(fields[12])]);
    } catch { /* gone */ }
  }
  const by = {};
  const add = (pid, t) => { const k = kind(pid); by[k] = (by[k] || 0) + t / 100; };
  const walk = (pid) => {
    for (const [child, t] of children.get(pid) || []) { add(child, t); walk(child); }
  };
  try {
    const stat = readFileSync(`/proc/${root}/stat`, "utf8");
    const fields = stat.slice(stat.lastIndexOf(")") + 2).split(" ");
    add(root, Number(fields[11]) + Number(fields[12]));
  } catch { /* gone */ }
  walk(root);
  by.all = Object.entries(by).reduce((sum, [, v]) => sum + v, 0);
  return by;
}

browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
await context.addInitScript(instrument);
const page = await context.newPage();
const cdp = await context.newCDPSession(page);
await cdp.send("Performance.enable");
const metric = async (name) => ((await cdp.send("Performance.getMetrics")).metrics
  .find((m) => m.name === name) || { value: 0 }).value;
// The browser's own process, the root of the tree whose CPU is counted.
const browserPid = (() => {
  for (const name of readdirSync("/proc")) {
    if (!/^\d+$/.test(name)) continue;
    try {
      const cmd = readFileSync(`/proc/${name}/cmdline`, "utf8");
      if (cmd.includes("--remote-debugging-pipe") && !cmd.includes("--type=")
          && Number(readFileSync(`/proc/${name}/stat`, "utf8").split(") ")[1].split(" ")[1]) === process.pid) {
        return Number(name);
      }
    } catch { /* gone */ }
  }
  return 0;
})();

const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });

let view = null;
for (let tries = 0; tries < 600 && !view; tries++) {
  view = await page.evaluate(() => (window.brickworksControls || {}).view);
  if (!view) await page.waitForTimeout(500);
}
if (!view) {
  await page.screenshot({ path: `${out}/never_showed.png` }).catch(() => {});
  console.log("FAIL the app never showed the model's view");
  await stop(1);
}

// On another floor, chosen as a person chooses it.
if (args.floor) {
  const words = { none: "No floor", grid: "Grid" }[args.floor];
  const want = args.floor.toUpperCase();
  let on = false;
  for (let tries = 0; tries < 3 && !on; tries++) {
    const menu = await page.evaluate(() => (window.brickworksControls || {}).menu_view);
    await page.mouse.click(menu.x, menu.y);
    await page.waitForTimeout(2000 + 2000 * tries);
    await page.keyboard.type("Floor", { delay: 110 });
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(1200);
    await page.keyboard.type(words, { delay: 110 });
    await page.keyboard.press("Enter");
    for (let n = 0; n < 40 && !on; n++) {
      await page.waitForTimeout(500);
      on = await page.evaluate((want) => (window.brickworksState || {}).floor === want, want);
    }
    if (!on) await page.keyboard.press("Escape");
  }
  console.log(`${on ? "ok  " : "FAIL"} on ${words}, by View > Floor`);
  if (!on) await stop(1);
}

const now = () => page.evaluate(() => performance.now());
const frames = (from) => page.evaluate((from) => window.brickworksIdle.frames.filter(([t]) => t >= from), from);
const drew = (f) => f.filter(([, , , draws]) => draws > 0);
// Quiet: [span] ms with no frame drawn, or (a build that draws every frame)
// every one of them alike in cost; by [longest] ms at the latest.
async function quiet(span, longest) {
  const until = Date.now() + longest;
  const from = await now();
  while (Date.now() < until) {
    await page.waitForTimeout(500);
    const t = await now();
    if (t - from < span) continue;
    const recent = await frames(t - span);
    if (recent.length >= 3 && drew(recent).length === 0) return true;
  }
  return false;
}

// Settled: the model, its parts and the bin's pictures arrived, and nothing
// left moving. A build that draws every frame never goes quiet; it is given
// three minutes and measured anyway.
const loaded = Date.now();
const settled = await quiet(4000, 180000);
console.log(`${settled ? "settled" : "never went quiet"} ${((Date.now() - loaded) / 1000).toFixed(0)} s after the view showed`);
// And then a while longer, for SwiftShader to finish what loading queued:
// drawn in software the GPU process rasterises seconds behind the page, and
// measured straight after settling it was still at 160% of a core on frames
// the page had drawn before it went quiet.
await page.waitForTimeout(after);

// Standing still.
const t0 = await now();
const named0 = await page.evaluate(() => ({ ...window.brickworksIdle.idleCalls }));
const task0 = await metric("TaskDuration");
const cpu0 = browserPid ? chromiumCpu(browserPid) : {};
const wall0 = Date.now();
await page.waitForTimeout(seconds * 1000);
const span = (Date.now() - wall0) / 1000;
const cpu1 = browserPid ? chromiumCpu(browserPid) : {};
const cpuBy = Object.fromEntries(Object.keys(cpu1).map((k) => [k, (cpu1[k] - (cpu0[k] || 0)) / span]));
const cpu = browserPid ? cpuBy.all : -1;
const busy = (await metric("TaskDuration") - task0) / span;
const idle = await frames(t0);
const idleDrawn = drew(idle);
const idleCalls = idle.reduce((sum, [, , , , calls]) => sum + calls, 0);
const named = Object.fromEntries(Object.entries(await page.evaluate(() => window.brickworksIdle.idleCalls))
  .map(([k, v]) => [k, v - (named0[k] || 0)]).filter(([, v]) => v > 0));
const inFrames = idle.reduce((s, [, ms]) => s + ms, 0) / 1000 / span;
const inGl = idle.reduce((s, [, , gl]) => s + gl, 0) / 1000 / span;
const row = {
  url, seconds: span, frames: idle.length, drawn: idleDrawn.length,
  framesPerSecond: idle.length / span, drawnPerSecond: idleDrawn.length / span,
  mainThread: busy, inFrames, inWebGl: inGl, chromiumCpu: cpu, chromiumCpuBy: cpuBy,
  webGlCalls: idleCalls, webGlCallsByName: named,
};
console.log(`standing still for ${span.toFixed(0)} s: ${idle.length} engine frames, ${idleDrawn.length} drawn (${row.drawnPerSecond.toFixed(1)} a second)`);
console.log(`  ${idleCalls} WebGL calls in those frames${idleCalls ? ` (${Object.entries(named).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([k, v]) => `${k} ${v}`).join(", ")})` : ""}`);
console.log(`  main thread busy ${(busy * 100).toFixed(0)}%, in the engine's frames ${(inFrames * 100).toFixed(0)}% (WebGL ${(inGl * 100).toFixed(0)}%), Chromium CPU ${cpu < 0 ? "unknown" : `${(cpu * 100).toFixed(0)}% of a core`}`
  + ` (${Object.entries(cpuBy).filter(([k]) => k !== "all").map(([k, v]) => `${k} ${(v * 100).toFixed(0)}%`).join(", ")})`);

let failures = 0;
const check = (what, held) => {
  console.log(`${held ? "ok  " : "FAIL"} ${what}`);
  if (!held) failures += 1;
};
// And at most a tenth of the engine's frames: drawn in software a frame of
// the old build took over a second, so it drew under one a second while
// drawing every frame it had.
check(`at most ${most} frame drawn a second standing still, and a tenth of the engine's frames `
  + `(${idleDrawn.length} of ${idle.length} in ${span.toFixed(0)} s)`,
  row.drawnPerSecond <= most && idleDrawn.length <= idle.length * 0.1 && idle.length >= 10);

// Then what a person does: each drawn, and quiet again after.
async function drawnBy(what, act) {
  await quiet(2000, 20000);
  const from = await now();
  await act();
  await page.waitForTimeout(1500);
  const after = drew(await frames(from));
  const still = await quiet(2000, 20000);
  check(`${what}: ${after.length} frames drawn, then quiet again`, after.length > 0 && still);
  return after.length;
}
row.wheel = await drawnBy("a wheel notch over the model", async () => {
  await page.mouse.move(view.x, view.y);
  await page.mouse.wheel(0, 120);
});
row.key = await drawnBy("the - key", async () => {
  await page.keyboard.press("Minus");
});
const held = (await page.evaluate(() => window.brickworksState || {})).held;
if (held) {
  // Into hand as a person puts it there, Q for the last part: Select is
  // where the app rests (2026-10-11), and shows no ghost.
  await page.mouse.move(view.x, view.y);
  await page.keyboard.press("q");
  row.hover = await drawnBy(`the pointer over the model with ${held} in hand`, async () => {
    for (let n = 1; n <= 8; n++) {
      await page.mouse.move(view.x + n * 14, view.y + n * 6);
      await page.waitForTimeout(120);
    }
  });
  await page.keyboard.press("Escape");
} else {
  console.log("     (nothing in hand, so no ghost to follow the pointer)");
}
await page.screenshot({ path: `${out}/idle.png`, timeout: 120000 }).catch(() => {});
writeFileSync(`${out}/idle.json`, JSON.stringify(row, null, 1));
console.log(failures ? `${failures} FAILURE(S)` : "the page draws nothing standing still, and every change");
await stop(failures ? 1 : 0);
