// Does the Render dialog open smoothly the first time? Opens it in a fresh
// browser, as a person does from the toolbar, and times every frame of the
// page from the press until its first draft is shown; then closes it and
// opens it again, for what an open costs once nothing is new.
//
//   set -a; . ./.env; set +a
//   node tools/web/render_open_check.mjs --dir=build/web          a local export, served here
//   BW_BYPASS=… node tools/web/render_open_check.mjs --url=<preview>/app
//
// The first open froze a browser drawing in software for 9 s on a preview
// (2026-10-12), and for a second at a time here: the set draws the bricks'
// shaders in ways the window never does and has two of its own, and under
// Compatibility a shader is built in the frame that first draws it each
// way. Eighteen programs went in four frames, eleven in one, and the
// read-backs in those frames waited for the card to build and draw them.
// StudioRender._warm now draws each new thing alone, a frame each, and
// _read waits on a fence: on local exports the first open's longest frame
// was 950-1,120 ms before and 115-237 ms after. A frame here is the
// engine's frame callback, timed in the page, the WebGL calls in it
// included (building a program is a WebGL call the page waits in), and the
// programs it linked are counted and timed apart.
//
// Fails when a frame of the first open is over --budget ms (250), when the
// draft never comes, or when a script error reaches the console. Prints the
// second open's longest frame beside it, with --programs every program
// linked and the frame it was linked in, and with --before=N the longest
// frames of the N s before the press. Leaves open.json and pictures of
// both opens in --out (shots/render_open).
//
// The press comes once the page has gone quiet, and by then the panel has
// made its renderer ready (RenderDialog._warm_when_idle): its viewports, and
// the sweep's and the contact shadow's shaders built while nobody was using
// the window. Before that (2026-10-17) the sweep's first draw built six
// programs in one frame of the open, the slowest, 136-140 ms here at a light
// load; now each frame of the open builds one at most, and the longest was
// 88-91 ms.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/render_open";
mkdirSync(out, { recursive: true });
const budget = Number(args.budget || 250);
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
// callback ran, how much of that was inside WebGL, how many draws it made,
// and the programs it linked with how long linking and checking them took.
function instrument() {
  const perf = { frames: [], cur: null, programs: [], frame: 0 };
  window.brickworksOpen = perf;
  const real = window.requestAnimationFrame.bind(window);
  const timed = (callback) => (time) => {
    if (perf.cur) { callback(time); return; }
    const frame = { t0: performance.now(), draws: 0, gl: 0, linked: 0, linking: 0, calls: {} };
    perf.cur = frame;
    perf.frame += 1;
    try { callback(time); } finally {
      perf.cur = null;
      // [start, length, inside WebGL, draws, programs linked, linking ms]
      // and the WebGL calls it waited longest in, by name.
      const waits = Object.entries(frame.calls).filter(([, ms]) => ms >= 20)
        .sort((a, b) => b[1] - a[1]).slice(0, 4).map(([k, ms]) => `${k} ${Math.round(ms)}`).join(", ");
      perf.frames.push([frame.t0, performance.now() - frame.t0, frame.gl, frame.draws,
        frame.linked, frame.linking, waits]);
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
  // What each shader is, by the #defines the engine put at its head: a
  // variant of the scene shader is told apart by them.
  const sources = new WeakMap();
  const attached = new WeakMap();
  const pending = new WeakMap();
  const wrap = (name, after) => {
    const was = gl[name];
    gl[name] = function (...a) {
      const f = perf.cur;
      const t0 = performance.now();
      try { return was.apply(this, a); } finally {
        const ms = performance.now() - t0;
        if (f) { f.gl += ms; f.calls[name] = (f.calls[name] || 0) + ms; }
        if (after) after(a, ms, f);
      }
    };
  };
  for (const name of Object.getOwnPropertyNames(gl)) {
    const d = Object.getOwnPropertyDescriptor(gl, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    if (/^(shaderSource|attachShader|linkProgram|getProgramParameter|compileShader|getShaderParameter)$/.test(name)) continue;
    const draw = /^draw(Arrays|Elements)(Instanced)?$/.test(name);
    wrap(name, draw ? (_a, _ms, f) => { if (f) f.draws += 1; } : null);
  }
  wrap("shaderSource", ([shader, text]) => {
    const defines = (text.match(/^#define [A-Z_0-9]+/gm) || []).map((d) => d.slice(8));
    sources.set(shader, { defines, length: text.length });
  });
  wrap("attachShader", ([program, shader]) => {
    if (!attached.has(program)) attached.set(program, []);
    attached.get(program).push(shader);
  });
  wrap("compileShader", ([shader], ms) => {
    const s = sources.get(shader);
    if (s) s.compile = (s.compile || 0) + ms;
  });
  wrap("linkProgram", ([program], ms, f) => {
    pending.set(program, { at: performance.now(), frame: perf.frame, ms, f });
  });
  // The check after linking is where a browser waits for the program to
  // be built, with KHR_parallel_shader_compile or without.
  const counted = (program, ms) => {
    const p = pending.get(program);
    if (!p) return;
    pending.delete(program);
    const shaders = (attached.get(program) || []).map((s) => sources.get(s) || {});
    const compile = shaders.reduce((sum, s) => sum + (s.compile || 0), 0);
    const total = p.ms + ms + compile;
    const defines = [...new Set(shaders.flatMap((s) => s.defines || []))];
    perf.programs.push([p.at, total, p.frame, defines.join(" "), shaders.map((s) => s.length || 0).join("+")]);
    const f = perf.cur;
    if (f) { f.linked += 1; f.linking += total; }
  };
  wrap("getProgramParameter", ([program], ms) => counted(program, ms));
  wrap("getShaderParameter", ([shader], ms) => {
    const s = sources.get(shader);
    if (s) s.compile = (s.compile || 0) + ms;
  });
}

browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
await context.addInitScript(instrument);
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
});
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });

async function where(name, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = await page.evaluate((k) => (window.brickworksControls || {})[k], name);
    if (at) return at;
    await page.waitForTimeout(500);
  }
  return null;
}
if (!(await where("tool_render", 300))) {
  await page.screenshot({ path: `${out}/never_showed.png` }).catch(() => {});
  console.log("FAIL the toolbar's Render never showed");
  await stop(1);
}

const now = () => page.evaluate(() => performance.now());
const frames = (from, to = Infinity) => page.evaluate(([a, b]) =>
  window.brickworksOpen.frames.filter(([t]) => t >= a && t <= b), [from, to]);
const programs = (from, to = Infinity) => page.evaluate(([a, b]) =>
  window.brickworksOpen.programs.filter(([t]) => t >= a && t <= b), [from, to]);
// Quiet: [span] ms with no frame drawn, by [longest] ms at the latest.
async function quiet(span, longest) {
  const until = Date.now() + longest;
  const from = await now();
  while (Date.now() < until) {
    await page.waitForTimeout(500);
    const t = await now();
    if (t - from < span) continue;
    const recent = await frames(t - span);
    if (recent.length >= 3 && recent.every(([, , , draws]) => draws === 0)) return true;
  }
  return false;
}

// The example car and its parts arrive after the toolbar, and the bin's
// pictures after them: opened before it is all in, the open would be timed
// with the arrival.
const loaded = Date.now();
const settled = await quiet(4000, 180000);
console.log(`${settled ? "settled" : "never went quiet"} ${((Date.now() - loaded) / 1000).toFixed(0)} s after the toolbar showed`);
await page.waitForTimeout(Number(args.after || 5000));
const before = await programs(0);
console.log(`  ${before.length} programs linked before the dialog was opened, `
  + `${(before.reduce((s, p) => s + p[1], 0) / 1000).toFixed(1)} s of it`);
// With --before=N, the longest frames of the N s before the press: what the
// page cost while it sat there, the panel making its renderer ready included.
if (args.before) {
  const t = await now();
  const sat = (await frames(t - Number(args.before) * 1000)).sort((a, b) => b[1] - a[1]).slice(0, 6);
  for (const [at, ms, , draws, n, linkMs] of sat) {
    console.log(`    ${String(Math.round(ms)).padStart(5)} ms at ${String(Math.round(at - t)).padStart(7)}: `
      + `${draws} draws, ${n} linked (${Math.round(linkMs)} ms)`);
  }
}

// Press Render; time every frame until the draft is shown and the page
// has gone quiet after it.
async function open(label) {
  const button = await where("tool_render", 30);
  // A closed dialog stops telling the page anything, so what it said last
  // is still there: the draft is the one this open draws, once it has.
  await page.evaluate(() => { window.brickworksRender = null; });
  const from = await now();
  await page.mouse.click(button.x, button.y);
  const t0 = Date.now();
  let shown = null;
  let drafted = null;
  let status = "";
  let drawing = false;
  while (Date.now() - t0 < 240000) {
    const seen = await page.evaluate(() => ({ render: window.brickworksRender || {},
      picture: Boolean((window.brickworksControls || {}).render_picture), t: performance.now() }));
    if (shown === null && seen.picture) shown = seen.t - from;
    status = seen.render.status || "";
    drawing = drawing || seen.render.working === "draft";
    if (drawing && seen.render.open && seen.render.working === "" && /Render draws/.test(status)) {
      drafted = seen.t - from;
      break;
    }
    await page.waitForTimeout(250);
  }
  await quiet(2000, 30000);
  const to = await now();
  const span = await frames(from, to);
  const linked = await programs(from, to);
  const worst = span.reduce((a, b) => (b[1] > a[1] ? b : a), [0, 0, 0, 0, 0, 0, ""]);
  const row = {
    label, shown, drafted, status,
    frames: span.length,
    longest: Math.round(worst[1]), longestInGl: Math.round(worst[2]),
    longestLinked: worst[4], longestLinking: Math.round(worst[5]),
    over: span.filter(([, ms]) => ms > budget).length,
    programs: linked.length,
    linking: Math.round(linked.reduce((s, p) => s + p[1], 0)),
    slowestProgram: Math.round(Math.max(0, ...linked.map((p) => p[1]))),
    mostInAFrame: Math.max(0, ...span.map((f) => f[4])),
    worstFrames: span.slice().sort((a, b) => b[1] - a[1]).slice(0, 6)
      .map(([t, ms, glMs, draws, n, linkMs, waits]) => ({ at: Math.round(t - from), ms: Math.round(ms),
        gl: Math.round(glMs), draws, linked: n, linking: Math.round(linkMs), waits })),
    linked: linked.map(([t, ms, frame, defines, size]) => ({ at: Math.round(t - from), ms: Math.round(ms), frame, defines, size })),
  };
  await page.screenshot({ path: `${out}/${label}.png`, timeout: 120000 }).catch(() => {});
  console.log(`${label}: the dialog up in ${shown === null ? "never" : `${Math.round(shown)} ms`}, `
    + `the draft in ${drafted === null ? "never" : `${(drafted / 1000).toFixed(1)} s`}; `
    + `${span.length} frames, the longest ${row.longest} ms (${row.longestInGl} in WebGL, `
    + `${row.longestLinked} programs linked in it, ${row.longestLinking} ms), ${row.over} over ${budget} ms`);
  console.log(`  ${row.programs} programs linked, ${(row.linking / 1000).toFixed(1)} s of it, the slowest `
    + `${row.slowestProgram} ms, at most ${row.mostInAFrame} in one frame`);
  console.log("  the longest frames:");
  for (const f of row.worstFrames) {
    console.log(`    ${String(f.ms).padStart(5)} ms at ${String(f.at).padStart(6)}: ${f.draws} draws, ${f.linked} linked; waited in ${f.waits || "nothing"}`);
  }
  if (args.programs) {
    for (const p of row.linked) console.log(`    ${String(p.at).padStart(7)} ms  ${String(p.ms).padStart(5)} ms  frame ${p.frame}  ${p.size}  ${p.defines.slice(0, 160)}`);
  }
  return row;
}

const rows = [];
let failures = 0;
const check = (what, held) => {
  console.log(`${held ? "ok  " : "FAIL"} ${what}`);
  if (!held) failures += 1;
};
try {
  const firstOpen = await open("first_open");
  rows.push(firstOpen);
  const close = await where("render_close", 10);
  if (close) await page.mouse.click(close.x, close.y);
  await quiet(3000, 60000);
  const again = await open("second_open");
  rows.push(again);
  check(`the first open drew its draft (${firstOpen.status.slice(0, 60)})`, firstOpen.drafted !== null);
  check(`no frame of the first open over ${budget} ms (the longest ${firstOpen.longest} ms; `
    + `${firstOpen.programs} programs linked; the second open's longest ${again.longest} ms)`,
    firstOpen.longest <= budget);
} catch (error) {
  check(String(error), false);
}
check(`no script errors (${errors.length})`, errors.length === 0);
for (const e of errors.slice(0, 5)) console.log(`      ${e}`);
writeFileSync(`${out}/open.json`, JSON.stringify({ url, budget, rows,
  before: before.map(([, ms, frame, defines, size]) => ({ ms: Math.round(ms), frame, defines, size })) }, null, 1));
console.log(failures ? `${failures} FAILURE(S)` : "the Render dialog opened smoothly the first time");
await stop(failures ? 1 : 0);
