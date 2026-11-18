// Where the studio's start goes, phase by phase, and what it grows its
// memory to: two builds timed at the same moment, each in a browser of its
// own (webstart11, 2026-11-18).
//
//   set -a; . ./.env; set +a
//   node tools/web/start_phases.mjs --urls=http://127.0.0.1:10711/index.html,http://127.0.0.1:10712/index.html \
//     --labels=base,after --config=cpu4 --pairs=5 [--warm] --out=DIR
//
//   --config   desktop   Chromium, 1280 x 800, broadband (20 Mbps, 40 ms)
//              phone     Chromium as a phone (390 x 844 at 3x, touch), no throttle
//              cpu4      the phone with its page held to a quarter of this box's
//                        speed (CDP Emulation.setCPUThrottlingRate) on Fast 4G
//              iphone13  Playwright's WebKit as an iPhone 13, drawing in
//                        software; WebKit takes no CPU or network throttle here
//   --warm     a return too: the same profile's second tab, everything cached
//
// Each pair starts both builds together, each in its own child process (so
// /proc counts each browser's own threads), and alternates which is
// launched first. The box's load swings between runs in turn, so builds are
// never timed one after the other (same-moment pairs, kinefast 2026-11-13).
//
// The phases, on the page's clock from its navigation:
//   fetch        the engine's wasm, its pack and the data pack arrived
//                (Resource Timing responseEnd)
//   compile      WebAssembly.compileStreaming of the wasm, begun to done:
//                the page's instantiateStreaming is split in two to say so
//   instantiate  the module made an instance (the engine's workers too)
//   engine       to the engine's "Build configuration" line: its own start
//   scripts      to Main's "compiled" mark: the first screen's GDScript
//   data         to Main's "data": waiting for the data pack after that
//   catalogue    to "catalogue": the parts catalogue read
//   window       to "ui": the window built
//   first part   to "model": the start's model laid; and working, its 61
//                parts all drawn (awaited 0), as phonetruth_flow says it
// Memory: the Wasm memory's size at each mark (the app's marks are caught
// as they are set) and its largest, the content process's Pss at working.
// CPU: each thread's from /proc at working (proc_cpu.mjs), never a trace.
//
// Writes DIR/pairs.json, and DIR/phases.md: each phase's median per build
// and the median of each pair's ratio.
import { chromium, devices, webkit } from "playwright";
import { SOFTWARE, START_MS, WEBKIT_SOFTWARE } from "./browser.mjs";
import { canSignIn, signInContext } from "./session.mjs";
import { descendants, pageRenderer, threads } from "./proc_cpu.mjs";
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { loadavg, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || "shots/start_phases"));
mkdirSync(out, { recursive: true });

const FAST4G = { offline: false, downloadThroughput: 9e6 / 8 * 0.9, uploadThroughput: 1.5e6 / 8 * 0.9, latency: 60 * 2.75 };
const BROADBAND = { offline: false, downloadThroughput: 20e6 / 8, uploadThroughput: 5e6 / 8, latency: 40 };
const PHONE = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true };
function without({ defaultBrowserType, ...rest }) { return rest; }
const CONFIGS = {
  desktop: { engine: "chromium", context: { viewport: { width: 1280, height: 800 } }, net: BROADBAND },
  phone: { engine: "chromium", context: PHONE },
  cpu4: { engine: "chromium", context: PHONE, cpu: 4, net: FAST4G },
  iphone13: { engine: "webkit", context: without(devices["iPhone 13"]) },
};
const PHASES = [
  ["fetch", "the engine's files in"],
  ["compile", "wasm compiled"],
  ["instantiate", "wasm instantiated"],
  ["engine", "engine's own start"],
  ["scripts", "scripts compiled"],
  ["data", "data pack waited for"],
  ["catalogue", "catalogue read"],
  ["window", "window built"],
  ["first_part", "first part laid"],
  ["working", "working (61 parts drawn)"],
];

if (args.one) {
  const result = await one(JSON.parse(Buffer.from(String(args.one), "base64url").toString()));
  writeFileSync(String(args.result), JSON.stringify(result, null, 2));
  process.exit(0);
}

const urls = String(args.urls || "").split(",").filter(Boolean);
const labels = String(args.labels || urls.map((_, i) => `build${i + 1}`).join(",")).split(",");
const configName = String(args.config || "cpu4");
if (urls.length < 1 || !CONFIGS[configName]) {
  console.log(`start_phases: --urls=A[,B] and --config=${Object.keys(CONFIGS).join("|")} are needed`);
  process.exit(2);
}
if (!canSignIn()) {
  console.log("start_phases: no Supabase keys in the environment (set -a; . ./.env; set +a)");
  process.exit(2);
}
const pairs = Number(args.pairs || 5);
const all = [];
for (let n = 0; n < pairs; n++) {
  const order = n % 2 ? [...urls.keys()].reverse() : [...urls.keys()];
  const load = loadavg()[0];
  const runs = await Promise.all(order.map((i) => child({ url: urls[i], label: labels[i], config: configName,
    warm: Boolean(args.warm), shot: join(out, `${configName}-${labels[i]}-${n + 1}`) })));
  const pair = { n: n + 1, load, builds: {} };
  for (const [k, i] of order.entries()) pair.builds[labels[i]] = runs[k];
  all.push(pair);
  console.log(`pair ${n + 1} at load ${load.toFixed(0)}: ${labels.map((l) => `${l} ${said(pair.builds[l])}`).join("; ")}`);
  writeFileSync(join(out, "pairs.json"), JSON.stringify({ config: configName, urls, labels, pairs: all }, null, 2));
}
writeFileSync(join(out, "phases.md"), table(all));
console.log(`\n${table(all)}`);
process.exit(0);

// -- the parent ---------------------------------------------------------------

function child(job) {
  const file = join(mkdtempSync(join(tmpdir(), "start-phases-")), "result.json");
  return new Promise((done) => {
    const kid = spawn(process.execPath, [fileURLToPath(import.meta.url),
      `--one=${Buffer.from(JSON.stringify(job)).toString("base64url")}`, `--result=${file}`],
    { stdio: ["ignore", "inherit", "inherit"], env: process.env });
    kid.on("exit", () => {
      try { done(JSON.parse(readFileSync(file, "utf8"))); } catch { done({ why: "the child wrote nothing" }); }
      rmSync(join(file, ".."), { recursive: true, force: true });
    });
  });
}

function sec(ms) { return Number.isFinite(ms) ? (ms / 1000).toFixed(1) : "-"; }
function mbs(b) { return Number.isFinite(b) ? `${Math.round(b / 1e6)}` : "-"; }
function median(xs) {
  const s = xs.filter(Number.isFinite).sort((a, b) => a - b);
  if (!s.length) return NaN;
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
}
function said(run) {
  if (!run?.cold) return `failed (${run?.why || "?"})`;
  const c = run.cold;
  return `working ${sec(c.at.working)} s, wasm ${mbs(c.memory.most)} MB${run.warm ? `, return ${sec(run.warm.at.working)} s` : ""}`;
}

/// Each phase's end and length, each build's median, and the median of the
/// pairs' ratios (after / before) for the last build against the first.
function table(rows) {
  const lines = [`# The start by phase: ${configName}`, "",
    `${rows.length} pairs, both builds at the same moment; load ${rows.map((r) => r.load.toFixed(0)).join(", ")}.`,
    "Each phase's end on the page's clock from its navigation, median s, then its own length (median s).", ""];
  for (const visit of ["cold", "warm"]) {
    if (!rows.some((r) => Object.values(r.builds).some((b) => b?.[visit]))) continue;
    lines.push(`## ${visit === "cold" ? "First visit" : "Return"}`, "",
      `| phase | ${labels.map((l) => `${l}: ends | ${l}: lasts`).join(" | ")} | ratio, lasts (${labels.at(-1)}/${labels[0]}) |`,
      `|---|${labels.map(() => "---|---").join("|")}|---|`);
    for (const [phase, words] of PHASES) {
      const cells = labels.map((l) => {
        const ends = median(rows.map((r) => r.builds[l]?.[visit]?.at?.[phase]));
        const lasts = median(rows.map((r) => r.builds[l]?.[visit]?.lasts?.[phase]));
        return `${sec(ends)} | ${sec(lasts)}`;
      });
      const ratio = median(rows.map((r) => {
        const a = r.builds[labels[0]]?.[visit]?.lasts?.[phase];
        const b = r.builds[labels.at(-1)]?.[visit]?.lasts?.[phase];
        return a > 0 ? b / a : NaN;
      }));
      lines.push(`| ${words} | ${cells.join(" | ")} | ${Number.isFinite(ratio) ? `x${ratio.toFixed(2)}` : "-"} |`);
    }
    const row = (name, fn, unit) => lines.push(`| ${name} | ${labels.map((l) => {
      const m = median(rows.map((r) => fn(r.builds[l]?.[visit])));
      return `${Number.isFinite(m) ? unit(m) : "-"} | `;
    }).join(" | ")} |`);
    row("Wasm memory at its largest, MB", (b) => b?.memory?.most, (m) => Math.round(m / 1e6));
    row("… at the catalogue mark, MB", (b) => b?.memory?.at?.catalogue, (m) => Math.round(m / 1e6));
    row("… at the scripts' mark, MB", (b) => b?.memory?.at?.compiled, (m) => Math.round(m / 1e6));
    row("… at the engine's own start, MB", (b) => b?.memory?.at?.engine, (m) => Math.round(m / 1e6));
    row("content process Pss at working, MB", (b) => b?.pss, (m) => Math.round(m / 1e6));
    row("main thread CPU to working, s", (b) => b?.cpu?.main, (m) => m.toFixed(1));
    row("all threads' CPU to working, s", (b) => b?.cpu?.all, (m) => m.toFixed(1));
    lines.push("");
  }
  return lines.join("\n");
}

// -- one browser --------------------------------------------------------------

async function one(job) {
  const config = CONFIGS[job.config];
  const dir = mkdtempSync(join(tmpdir(), "start-phases-profile-"));
  const type = config.engine === "webkit" ? webkit : chromium;
  const options = config.engine === "webkit" ? { env: { ...process.env, ...WEBKIT_SOFTWARE } } : { args: SOFTWARE };
  const result = { url: job.url, label: job.label, config: job.config, load: loadavg()[0] };
  const context = await type.launchPersistentContext(dir, { ...options, ...config.context });
  try {
    await signInContext(context);
    await context.addInitScript(instrument);
    result.cold = await visit(context, config, job, "cold");
    if (job.warm && Number.isFinite(result.cold?.at?.working)) result.warm = await visit(context, config, job, "warm");
    result.pss = result.cold?.pss;
    result.cpu = result.cold?.cpu;
  } catch (trouble) {
    result.why = String(trouble.stack || trouble).slice(0, 500);
  } finally {
    await context.close().catch(() => {});
    rmSync(dir, { recursive: true, force: true });
  }
  return result;
}

/// The content process of this browser: Chromium's page renderer (the one
/// with the engine's workers), or WebKit's biggest web process.
function contentPid(engine) {
  if (engine === "chromium") return pageRenderer(process.pid);
  let best = 0;
  let most = -1;
  for (const pid of descendants(process.pid)) {
    try {
      if (!/WebProcess/.test(readFileSync(`/proc/${pid}/cmdline`, "utf8").split("\0")[0])) continue;
      const n = Object.keys(threads(pid)).length;
      if (n > most) { most = n; best = pid; }
    } catch { /* gone */ }
  }
  return best;
}

function ticks(rows, main) {
  let all = 0;
  let mine = 0;
  for (const [tid, t] of Object.entries(rows)) {
    all += t.cpu;
    if (Number(tid) === main) mine += t.cpu;
  }
  return { all, main: mine };
}

async function visit(context, config, job, which) {
  const page = await context.newPage();
  if (config.engine === "chromium") {
    const cdp = await context.newCDPSession(page);
    // The visit counter kept out by blocking it: a route turns the cache off.
    await cdp.send("Network.enable");
    await cdp.send("Network.setBlockedURLs", { urls: ["*overlook.technology*"] });
    if (config.cpu) await cdp.send("Emulation.setCPUThrottlingRate", { rate: config.cpu });
    if (config.net) await cdp.send("Network.emulateNetworkConditions", config.net);
  }
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  await page.goto(job.url, { waitUntil: "commit", timeout: 180000 });
  const deadline = Date.now() + START_MS * 2;
  let state = null;
  for (;;) {
    state = await page.evaluate(() => {
      const s = window.brickworksState || {};
      return { bricks: s.bricks || 0, awaited: s.awaited ?? -1, ui: Boolean((window.brickworksBoot || {}).ui), now: performance.now() };
    }).catch(() => null);
    if (state && state.ui && state.awaited === 0 && state.bricks >= 61) break;
    if (Date.now() > deadline) break;
    await page.waitForTimeout(100);
  }
  // The page's process is found once its workers are made, and counted
  // whole: it was made for this page (a cold visit's first, a return's new
  // tab) and spent nothing to speak of before the navigation.
  const pid = contentPid(config.engine);
  const before = {};
  const after = pid ? threads(pid) : {};
  const marks = await page.evaluate(() => {
    const at = window.__phases;
    const res = (pattern) => Math.max(0, ...performance.getEntriesByType("resource")
      .filter((r) => pattern.test(r.name)).map((r) => r.responseEnd));
    const said = (pattern) => ((at.said.find(([, line]) => pattern.test(line)) || [NaN])[0]);
    // The memory as the engine's own start ended, before any script.
    at.memory.engine = (at.said.find(([, line]) => /^Build configuration/.test(line)) || [0, "", NaN])[2];
    return { boot: { ...(window.brickworksBoot || {}) }, wasm: at.wasm, memory: at.memory, timeline: at.timeline,
      firstFrame: at.firstFrame, fetched: { wasm: res(/index\.wasm(\?|$)/), pck: res(/index\.pck(\?|$)/), data: res(/index\.data\.pck(\?|$)/) },
      banner: said(/^Godot Engine v/), configured: said(/^Build configuration/), most: window.__phases.most() };
  });
  const b = marks.boot;
  const fetchEnd = Math.max(marks.fetched.wasm, marks.fetched.pck);
  const at = {
    fetch: fetchEnd || NaN,
    compile: marks.wasm.compiled || NaN,
    instantiate: marks.wasm.instantiated || NaN,
    engine: marks.configured,
    scripts: b.compiled,
    data: b.data || b.compiled,
    catalogue: b.catalogue,
    window: b.ui,
    first_part: b.model,
    working: state && state.awaited === 0 && state.bricks >= 61 ? state.now : NaN,
  };
  // Each phase's own length: from the end of the one before it, except the
  // compile, which streams under the download and is timed from its call.
  const lasts = {};
  let previous = 0;
  for (const [phase] of PHASES) {
    const end = at[phase];
    lasts[phase] = phase === "compile" ? end - (marks.wasm.asked || NaN) : end - previous;
    if (Number.isFinite(end)) previous = end;
  }
  const t = ticks(before, pid);
  const u = ticks(after, pid);
  let pss = NaN;
  try {
    pss = Number((readFileSync(`/proc/${pid}/smaps_rollup`, "utf8").match(/^Pss:\s+(\d+) kB/m) || [])[1]) * 1024;
  } catch { /* gone */ }
  const top = Object.entries(after).map(([tid, r]) => ({ tid: Number(tid), comm: r.comm,
    s: (r.cpu - (before[tid]?.cpu || 0)) / 100 })).sort((x, y) => y.s - x.s).slice(0, 8);
  await page.screenshot({ path: `${job.shot}-${which}.png`, timeout: 60000 }).catch(() => {});
  await page.close().catch(() => {});
  return { at, lasts, memory: { at: marks.memory, most: marks.most, timeline: marks.timeline }, marks,
    pss, cpu: { main: (u.main - t.main) / 100, all: (u.all - t.all) / 100, top }, errors: errors.slice(0, 5),
    bricks: state?.bricks, awaited: state?.awaited };
}

// In the page before anything runs: the wasm's compile and instance timed
// apart, the Wasm memory kept and read at each of the app's marks, the
// engine's console lines, and the first frame drawn once the app runs.
function instrument() {
  try { localStorage.setItem("ov_ignore", "1"); } catch {}
  const at = { wasm: {}, memory: {}, timeline: [], said: [], firstFrame: 0 };
  window.__phases = at;
  const memories = [];
  const bytes = () => memories.reduce((most, m) => Math.max(most, m.buffer.byteLength), 0);
  let most = 0;
  at.most = () => Math.max(most, bytes());
  const Real = WebAssembly.Memory;
  function Memory(descriptor) {
    const made = new Real(descriptor);
    memories.push(made);
    return made;
  }
  Memory.prototype = Real.prototype;
  WebAssembly.Memory = Memory;
  const keep = (got) => {
    try {
      for (const value of Object.values((got.instance || got).exports || {})) if (value instanceof Real) memories.push(value);
    } catch {}
    return got;
  };
  // instantiateStreaming in two: compileStreaming, then instantiate, each
  // timed. The same work a browser does in one call.
  const compileStreaming = WebAssembly.compileStreaming.bind(WebAssembly);
  const instantiate = WebAssembly.instantiate.bind(WebAssembly);
  WebAssembly.instantiateStreaming = async (source, imports) => {
    at.wasm.asked = performance.now();
    const module = await compileStreaming(source);
    at.wasm.compiled = performance.now();
    const instance = await instantiate(module, imports);
    at.wasm.instantiated = performance.now();
    return keep({ module, instance });
  };
  WebAssembly.instantiate = (...a) => instantiate(...a).then(keep);
  // The app's marks, each with the memory's size as it was set.
  const marks = {};
  Object.defineProperty(window, "brickworksBoot", {
    configurable: true,
    get() { return new Proxy(marks, { set(target, key, value) {
      target[key] = value;
      at.memory[key] = bytes();
      return true;
    } }); },
    set(v) { Object.assign(marks, v); },
  });
  setInterval(() => {
    const now = bytes();
    if (now > most) { most = now; at.timeline.push([Math.round(performance.now()), now]); }
  }, 100);
  for (const kind of ["log", "warn", "error"]) {
    const was = console[kind].bind(console);
    console[kind] = (...a) => {
      if (at.said.length < 40) at.said.push([Math.round(performance.now()), String(a[0]).slice(0, 100), bytes()]);
      return was(...a);
    };
  }
  let running = false;
  let state;
  Object.defineProperty(window, "brickworksState", {
    configurable: true,
    get() { return state; },
    set(v) { running = true; state = v; },
  });
  const getContext = HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
    const gl = getContext.call(this, kind, ...rest);
    if (!gl || !/webgl/.test(String(kind)) || gl.__phasesHooked) return gl;
    gl.__phasesHooked = true;
    let bound = null;
    const bind = gl.bindFramebuffer.bind(gl);
    gl.bindFramebuffer = (target, fb) => {
      if (target === gl.FRAMEBUFFER || target === gl.DRAW_FRAMEBUFFER) bound = fb;
      return bind(target, fb);
    };
    for (const name of ["drawArrays", "drawElements", "blitFramebuffer"]) {
      const call = gl[name] && gl[name].bind(gl);
      if (!call) continue;
      gl[name] = (...a) => {
        if (bound === null && running && !at.firstFrame) at.firstFrame = performance.now();
        return call(...a);
      };
    }
    return gl;
  };
}
