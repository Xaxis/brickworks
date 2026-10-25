// How long a first visit to /app waits, and for how many bytes.
//
//   set -a; . ./.env; set +a
//   node tools/web/load_check.mjs --url=<origin>/app [--bypass=…]
//     --profiles=broadband,slow   the networks (below); broadband alone by default
//     --runs=3                    cold loads of each, and the median said
//     --warm                      and a warm load after each cold one
//     --max-bytes=MB --max-interactive=S   the gate, on broadband's cold medians
//     --pick=ID [--max-pick=S]    then ID taken from the bin at once, timed to
//                                 its ghost over the model (each load's held)
//     --out=DIR                   each run's files and timeline as JSON
//
// A visit is a fresh browser profile, so nothing is cached, signed in as
// the tests are (browser.mjs): the app shows a person nothing but its
// sign-in until they are. A profile on disk, not the incognito context a
// flow gets: that keeps its cache in memory, which holds no file over a
// few megabytes, so a warm load there fetched the 21 MB pack again. The network is held to a profile by Chromium's
// own throttling (Network.emulateNetworkConditions):
//
//   broadband   20 Mbps down, 5 up, 40 ms round trip
//   slow         5 Mbps down, 1 up, 100 ms
//   none         not held: a local export's start alone
//
// Each load is timed from the page's request, in the page's clock:
//
//   started      the engine's startGame resolved (the shell's #boot done);
//   first frame  the first frame drawn to the window once the app is
//                running (its first window.brickworksState);
//   bin drawn    the first frame drawn once the app has told the page the
//                parts the bin lists first (brickworksState.found): the bin
//                on the screen;
//   interactive  the parts bin usable as a flow finds it: its search and
//                first tile told to the page (window.brickworksControls),
//                which waits for them to stay put a publish (Main), and the
//                parts it lists first;
//   net          when the last byte of the build's own files (the engine's
//                script, wasm and pack) arrived;
//   main thread  its CPU before interactive (Chrome's own ThreadTime),
//                which the box's load does not stretch, and its long tasks
//                by the page's clock; all threads, the engine's and the wasm
//                compiler's too (ProcessTime). The wall clock past the
//                network and the main thread is mostly the drawing, done
//                here in software (SwiftShader) on a shared box;
//   bytes        what came over the wire before interactive, as sent
//                (compressed), headers and all.
//
// Every file is listed with its size as sent, its encoding and its cache
// header. With --max-bytes or --max-interactive it is a gate: exit 1 when
// broadband's cold median is over either.
import { chromium } from "playwright";
import { SOFTWARE, START_MS } from "./browser.mjs";
import { canSignIn, signInContext } from "./session.mjs";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("load_check: --url=<origin>/app is required");
  process.exit(2);
}
const bypass = args.bypass && args.bypass !== true ? String(args.bypass) : (process.env.BW_BYPASS || "");
const url = bypass
  ? `${args.url}${args.url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : String(args.url);
const PROFILES = {
  broadband: { down: 20, up: 5, rtt: 40 },
  slow: { down: 5, up: 1, rtt: 100 },
  none: null,
};
const profiles = String(args.profiles || "broadband").split(",");
for (const p of profiles) if (!(p in PROFILES)) { console.error(`load_check: no profile ${p}`); process.exit(2); }
const runs = Number(args.runs || 3);
const warm = Boolean(args.warm);
const out = args.out ? String(args.out) : "";
if (out) mkdirSync(out, { recursive: true });
const maxBytes = args["max-bytes"] ? Number(args["max-bytes"]) * 1e6 : 0;
const maxInteractive = args["max-interactive"] ? Number(args["max-interactive"]) * 1000 : 0;
// --pick=ID: once the bin is usable, the part ID taken from it as a person
// quick off the mark would, and timed from the click until its ghost is over
// the model; --max-pick=S holds the longest of those.
const pickId = args.pick && args.pick !== true ? String(args.pick) : "";
const maxPick = args["max-pick"] ? Number(args["max-pick"]) * 1000 : 0;

// In the page before anything of its own runs: long tasks, when the engine
// started, and each frame drawn to the window (a draw, clear or blit with
// no framebuffer of the app's bound) once the app has told the page it runs.
function instrument() {
  const at = { started: 0, running: 0, firstFrame: 0, listed: 0, binDrawn: 0, longtasks: [], said: [] };
  window.__load = at;
  // What the engine says as it starts (its banner, the renderer), timed.
  for (const kind of ["log", "warn", "error"]) {
    const was = console[kind].bind(console);
    console[kind] = (...a) => {
      if (at.said.length < 30) at.said.push([Math.round(performance.now()), String(a[0]).slice(0, 100)]);
      return was(...a);
    };
  }
  console.timeStamp(`load_check zero ${performance.now()}`);
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) at.longtasks.push([e.startTime, e.duration]);
    }).observe({ type: "longtask", buffered: true });
  } catch {}
  let state;
  Object.defineProperty(window, "brickworksState", {
    configurable: true,
    get() { return state; },
    set(v) {
      if (!at.running) at.running = performance.now();
      if (!at.listed && v && Array.isArray(v.found) && v.found.length) at.listed = performance.now();
      state = v;
    },
  });
  const watchBoot = () => {
    const boot = document.getElementById("boot");
    if (!boot) return false;
    new MutationObserver(() => {
      if (!at.started && boot.classList.contains("done")) at.started = performance.now();
    }).observe(boot, { attributes: true, attributeFilter: ["class"] });
    return true;
  };
  if (!watchBoot()) document.addEventListener("DOMContentLoaded", watchBoot);
  const getContext = HTMLCanvasElement.prototype.getContext;
  HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
    const gl = getContext.call(this, kind, ...rest);
    if (!gl || !/webgl/.test(String(kind)) || gl.__loadHooked) return gl;
    gl.__loadHooked = true;
    let bound = null;
    const bind = gl.bindFramebuffer.bind(gl);
    gl.bindFramebuffer = (target, fb) => {
      if (target === gl.FRAMEBUFFER || target === gl.DRAW_FRAMEBUFFER) bound = fb;
      return bind(target, fb);
    };
    for (const name of ["drawArrays", "drawElements", "drawArraysInstanced", "drawElementsInstanced", "blitFramebuffer"]) {
      const call = gl[name] && gl[name].bind(gl);
      if (!call) continue;
      gl[name] = (...a) => {
        if (bound === null) {
          if (!at.firstFrame && at.running) at.firstFrame = performance.now();
          if (!at.binDrawn && at.listed) at.binDrawn = performance.now();
        }
        return call(...a);
      };
    }
    return gl;
  };
}

const median = (xs) => {
  const s = xs.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!s.length) return NaN;
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
};
const sec = (ms) => (Number.isFinite(ms) ? (ms / 1000).toFixed(1) : "-");
const mb = (b) => (b / 1e6).toFixed(2);

// The renderer's CPU so far, from Chrome's own counters: the page's main
// thread (ThreadTime) and the whole process (ProcessTime, the engine's
// threads and the wasm compiler's too), in ms.
async function cpuNow(cdp) {
  try {
    const { metrics } = await cdp.send("Performance.getMetrics");
    const m = Object.fromEntries(metrics.map(({ name, value }) => [name, value]));
    return { main: (m.ThreadTime || 0) * 1000, all: (m.ProcessTime || 0) * 1000, tasks: (m.TaskDuration || 0) * 1000 };
  } catch {
    return { main: NaN, all: NaN, tasks: NaN };
  }
}

// The part [id] typed into the bin's search and its first tile clicked, as
// placing_flow.mjs takes one, the pointer then over the middle of the window
// (the model): ms on the page's clock from the click until the app holds it
// with its ghost drawn, which needs its geometry, and whether that was
// fetched from the store on its own.
async function pickFirst(page, id) {
  const now = () => page.evaluate(() => performance.now());
  const read = () => page.evaluate(() => ({ c: window.brickworksControls || {}, s: window.brickworksState || {} }));
  let { c } = await read();
  if (!c["part search"]) return { ms: NaN, why: "no part search" };
  await page.mouse.click(c["part search"].x, c["part search"].y);
  await page.keyboard.press("Control+a");
  await page.keyboard.type(id, { delay: 30 });
  for (let n = 0; n < 200; n++) {
    const { s } = await read();
    if (Array.isArray(s.found) && s.found[0] === id) break;
    await page.waitForTimeout(100);
  }
  // The tile is told once it has stayed put a publish.
  await page.waitForTimeout(1200);
  ({ c } = await read());
  if (!c["first part"]) return { ms: NaN, why: "no first part" };
  const view = page.viewportSize();
  const t0 = await now();
  await page.mouse.click(c["first part"].x, c["first part"].y);
  await page.mouse.move(Math.round(view.width / 2), Math.round(view.height / 2), { steps: 4 });
  for (let n = 0; n < 300; n++) {
    const got = await page.evaluate((want) => {
      const s = window.brickworksState || {};
      return String(s.held || "") === want && Array.isArray(s.ghost_pose) ? performance.now() : 0;
    }, id);
    if (got) return { ms: got - t0, at: t0 };
    await page.waitForTimeout(50);
  }
  return { ms: NaN, at: t0, why: "never held with a ghost" };
}

// One load of [url] in [context]: what came and when, and the marks.
async function load(context, profile, label) {
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send("Network.enable");
  // The visit counter kept out (a check is not a visit) by blocking it, not
  // by answering it as the flows do (browser.mjs quietCounter): a route
  // turns the browser's cache off for the whole context.
  await cdp.send("Network.setBlockedURLs", { urls: ["*overlook.technology*"] });
  await cdp.send("Performance.enable", { timeDomain: "threadTicks" }).catch(() => {});
  const p = PROFILES[profile];
  if (p) {
    await cdp.send("Network.emulateNetworkConditions", {
      offline: false, latency: p.rtt,
      downloadThroughput: (p.down * 1e6) / 8, uploadThroughput: (p.up * 1e6) / 8,
    });
  }
  const requests = new Map();
  let zero = 0;
  cdp.on("Network.requestWillBeSent", (e) => {
    if (!zero && e.type === "Document") zero = e.timestamp;
    if (!requests.has(e.requestId)) requests.set(e.requestId, { url: e.request.url, start: e.timestamp, chunks: [] });
  });
  cdp.on("Network.responseReceived", (e) => {
    const r = requests.get(e.requestId);
    if (!r) return;
    const h = Object.fromEntries(Object.entries(e.response.headers || {}).map(([k, v]) => [k.toLowerCase(), v]));
    Object.assign(r, { status: e.response.status, encoding: h["content-encoding"] || "", cache: h["cache-control"] || "",
      type: h["content-type"] || "", cached: Boolean(e.response.fromDiskCache || e.response.fromPrefetchCache || e.response.fromServiceWorker),
      headers: e.response.encodedDataLength || 0 });
  });
  cdp.on("Network.dataReceived", (e) => {
    const r = requests.get(e.requestId);
    if (r) r.chunks.push([e.timestamp, e.encodedDataLength || 0]);
  });
  cdp.on("Network.loadingFinished", (e) => {
    const r = requests.get(e.requestId);
    if (r) Object.assign(r, { end: e.timestamp, bytes: e.encodedDataLength || 0 });
  });
  cdp.on("Network.loadingFailed", (e) => {
    const r = requests.get(e.requestId);
    if (r) Object.assign(r, { end: e.timestamp, failed: e.errorText || "failed", bytes: 0 });
  });
  // A worker's requests (the later parts, src/boot/shell.html) are not the
  // page's in Chrome's own protocol; Playwright reports them with the page's.
  const seen = [];
  page.on("requestfinished", (request) => {
    seen.push(Promise.all([request.sizes(), request.response()]).then(([sizes, response]) => ({
      url: request.url(), timing: request.timing(), headers: response ? response.headers() : {},
      bytes: sizes.responseBodySize + sizes.responseHeadersSize })).catch(() => null));
  });
  await page.addInitScript(instrument);
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  await page.goto(url, { waitUntil: "commit", timeout: 120000 });
  // Counted from the page's own process, which the navigation may have
  // changed: what it had spent as it began.
  const cpu0 = await cpuNow(cdp);
  let marks = null;
  let cpu1 = null;
  const deadline = Date.now() + START_MS;
  for (;;) {
    const now = await page.evaluate(() => {
      const c = window.brickworksControls || {};
      const s = window.brickworksState || {};
      return { at: { ...window.__load, boot: window.brickworksBoot || {}, later: window.brickworksLater || null }, bin: Boolean(c["part search"] && c["first part"]),
        found: Array.isArray(s.found) ? s.found.length : 0, now: performance.now() };
    }).catch(() => null);
    if (now && now.bin && now.found > 0) { marks = { ...now.at, interactive: now.now }; cpu1 = await cpuNow(cdp); break; }
    if (Date.now() > deadline) { marks = now ? { ...now.at, interactive: NaN } : null; break; }
    await page.waitForTimeout(100);
  }
  const navStart = await page.evaluate(() => performance.timeOrigin).catch(() => 0);
  const cpu = cpu1 ? cpu1.main - cpu0.main : NaN;
  const picked = pickId && Number.isFinite(marks?.interactive) ? await pickFirst(page, pickId).catch((e) => ({ ms: NaN, why: String(e).slice(0, 120) })) : null;
  const cpuAll = cpu1 ? cpu1.all - cpu0.all : NaN;
  const busy = (marks?.longtasks || []).filter(([t]) => t <= (marks?.interactive ?? Infinity)).reduce((n, [, d]) => n + d, 0);
  // Request times to the page's clock: the document's request is its zero
  // within a few ms (the navigation's own start).
  const rel = (t) => (t - zero) * 1000;
  const files = [...requests.values()].filter((r) => !r.url.startsWith("data:")).map((r) => ({
    path: r.url.replace(/^https?:\/\/[^/]+/, "").replace(/[?#].*$/, ""), host: (r.url.match(/^https?:\/\/([^/]+)/) || [])[1] || "",
    status: r.status || 0, encoding: r.encoding || "", cache: r.cache || "", cached: Boolean(r.cached), type: r.type || "",
    bytes: Math.max(r.bytes || 0, r.chunks.reduce((n, [, b]) => n + b, 0)), start: rel(r.start), end: r.end ? rel(r.end) : NaN,
    before: r.chunks.filter(([t]) => rel(t) <= (marks?.interactive ?? Infinity)).reduce((n, [, b]) => n + b, 0)
      + (r.end && rel(r.end) <= (marks?.interactive ?? Infinity) ? (r.headers || 0) : 0),
    failed: r.failed || "",
  }));
  // What came by a worker: on the page's clock from the timings' epoch.
  for (const one of await Promise.all(seen)) {
    if (!one || requests.size === 0 || [...requests.values()].some((r) => r.url === one.url)) continue;
    const begun = one.timing.startTime - navStart;
    const end = begun + Math.max(0, one.timing.responseEnd);
    files.push({ path: one.url.replace(/^https?:\/\/[^/]+/, "").replace(/[?#].*$/, ""), host: (one.url.match(/^https?:\/\/([^/]+)/) || [])[1] || "",
      status: 200, encoding: one.headers["content-encoding"] || "", cache: one.headers["cache-control"] || "",
      cached: false, type: one.headers["content-type"] || "", bytes: one.bytes, start: begun, end,
      before: end <= (marks?.interactive ?? Infinity) ? one.bytes : 0, failed: "", worker: true });
  }
  const build = files.filter((f) => /\/index\.(wasm|pck|js)$/.test(f.path) || /\.pck$/.test(f.path));
  const ends = build.filter((f) => f.end <= (marks?.interactive ?? Infinity)).map((f) => f.end);
  const net = ends.length ? Math.max(...ends) : NaN;
  const bytes = files.reduce((n, f) => n + f.before, 0);
  if (marks) delete marks.longtasks;
  if (picked && picked.at) {
    // A part of the pick fetched alone from the store, after the click.
    picked.fetched = files.filter((f) => f.path.endsWith(".lbm") && f.start >= picked.at).length;
  }
  const run = { label, profile, marks, net, cpu, cpuAll, busy, bytes, files, errors: errors.slice(0, 5), navStart, picked };
  await page.close().catch(() => {});
  return run;
}

function sayRun(run) {
  const m = run.marks || {};
  const b = m.boot || {};
  const banner = (m.said || []).find(([, line]) => /^Godot Engine/.test(line));
  console.log(`  ${run.label}: interactive ${sec(m.interactive)} s (bin drawn ${sec(m.binDrawn)} s), first frame ${sec(m.firstFrame)} s, `
    + `started ${sec(m.started)} s, net ${sec(run.net)} s, main thread ${sec(run.cpu)} s on a CPU (${sec(run.busy)} s in long tasks; `
    + `${sec(run.cpuAll)} s all threads), ${mb(run.bytes)} MB before interactive`
    + (run.errors.length ? ` (page errors: ${run.errors.join(" | ")})` : ""));
  if (run.picked) {
    console.log(`    first pick of ${pickId}: in hand with its ghost ${Number.isFinite(run.picked.ms) ? `${Math.round(run.picked.ms)} ms` : `never (${run.picked.why})`}`
      + ` after the click, ${run.picked.fetched ?? 0} part file${run.picked.fetched === 1 ? "" : "s"} fetched for it alone`);
  }
  // Where the wait after the download went: the engine's start, then the
  // app's own (Main._boot_mark).
  if (args.laps) {
    const laps = Object.entries(b).sort((x, y) => x[1] - y[1]);
    console.log(`    laps: ${laps.map(([k, v], n) => `${k} ${sec(v)}${n ? ` (+${((v - laps[n - 1][1]) / 1000).toFixed(2)})` : ""}`).join(", ")}`);
  }
  if (b.ready) {
    console.log(`    the start: engine banner ${sec(banner ? banner[0] : NaN)} s, app ready ${sec(b.ready)} s, `
      + `catalogue +${sec(b.catalogue - b.ready)} s, interface +${sec(b.ui - b.catalogue)} s, model +${sec(b.model - b.ui)} s, `
      + `then interactive +${sec(m.interactive - b.model)} s`);
  }
}

function sayFiles(run) {
  const rows = run.files.filter((f) => f.bytes > 0 || f.cached).sort((a, b) => b.bytes - a.bytes);
  console.log(`  files of ${run.label}, largest first (as sent):`);
  for (const f of rows.slice(0, 24)) {
    console.log(`    ${mb(f.bytes).padStart(7)} MB  ${(f.encoding || "-").padEnd(4)} ${String(f.status).padEnd(3)} `
      + `${sec(f.start).padStart(5)}-${sec(f.end).padEnd(5)} s  ${f.cached ? "cache " : ""}${f.worker ? "(a worker's) " : ""}${f.host === new URL(args.url).host ? "" : f.host}${f.path}`
      + `  [${f.cache || "no cache-control"}]`);
  }
  const rest = rows.slice(24);
  if (rest.length) console.log(`    ${mb(rest.reduce((n, f) => n + f.bytes, 0)).padStart(7)} MB in ${rest.length} more`);
}

// A browser of its own for each cold load, on a profile of its own on
// disk, signed in as a returning visitor; its warm load after in the same.
async function visitor() {
  const dir = mkdtempSync(join(tmpdir(), "load_check-"));
  const context = await chromium.launchPersistentContext(dir, { args: SOFTWARE, viewport: { width: 1280, height: 800 } });
  if (canSignIn()) await signInContext(context).catch((e) => console.log(`  (could not sign in: ${e.message})`));
  else console.log("  (not signed in: no Supabase keys in the environment, so the app shows its sign-in screen)");
  return { context, done: async () => { await context.close().catch(() => {}); rmSync(dir, { recursive: true, force: true }); } };
}

const results = [];
let failed = false;
for (const profile of profiles) {
  const held = PROFILES[profile] ? `${PROFILES[profile].down} Mbps, ${PROFILES[profile].rtt} ms` : "not held";
  console.log(`load_check: ${args.url}, ${profile} (${held}), ${runs} cold${warm ? " and warm" : ""}`);
  for (let n = 1; n <= runs; n++) {
    const { context, done } = await visitor();
    try {
      const cold = await load(context, profile, `cold ${n}`);
      results.push(cold);
      sayRun(cold);
      if (n === 1) sayFiles(cold);
      if (warm) {
        const again = await load(context, profile, `warm ${n}`);
        results.push(again);
        sayRun(again);
        if (n === 1) sayFiles(again);
      }
    } catch (trouble) {
      console.log(`  run ${n} FAILED: ${String(trouble.message || trouble).slice(0, 300)}`);
      failed = true;
    } finally {
      await done();
    }
  }
}

console.log("\nload_check: medians (s; MB before interactive)");
const summary = {};
for (const profile of profiles) {
  for (const kind of warm ? ["cold", "warm"] : ["cold"]) {
    const these = results.filter((r) => r.profile === profile && r.label.startsWith(kind));
    if (!these.length) continue;
    const row = {
      interactive: median(these.map((r) => r.marks?.interactive)),
      firstFrame: median(these.map((r) => r.marks?.firstFrame)),
      binDrawn: median(these.map((r) => r.marks?.binDrawn)),
      started: median(these.map((r) => r.marks?.started)),
      net: median(these.map((r) => r.net)),
      cpu: median(these.map((r) => r.cpu)),
      busy: median(these.map((r) => r.busy)),
      cpuAll: median(these.map((r) => r.cpuAll)),
      bytes: median(these.map((r) => r.bytes)),
      pick: pickId ? Math.max(...these.map((r) => r.picked?.ms ?? NaN)) : NaN,
      runs: these.length,
    };
    summary[`${profile} ${kind}`] = row;
    console.log(`  ${`${profile} ${kind}`.padEnd(15)} interactive ${sec(row.interactive).padStart(5)}  bin drawn ${sec(row.binDrawn).padStart(5)}  first frame ${sec(row.firstFrame).padStart(5)}  `
      + `${pickId ? `pick ${Number.isFinite(row.pick) ? `${Math.round(row.pick)} ms` : "-"} (longest)  ` : ""}`
      + `started ${sec(row.started).padStart(5)}  net ${sec(row.net).padStart(5)}  main ${sec(row.cpu).padStart(5)} (long ${sec(row.busy)}, all ${sec(row.cpuAll)})  ${mb(row.bytes).padStart(6)} MB  (${row.runs} runs)`);
  }
}
if (out) writeFileSync(`${out}/load.json`, JSON.stringify({ url: args.url, summary, results }, null, 1));

const gate = summary["broadband cold"];
if (maxBytes || maxInteractive) {
  if (!gate) { console.log("FAIL no broadband cold run to judge"); failed = true; } else {
    if (maxBytes) {
      const ok = gate.bytes <= maxBytes;
      console.log(`${ok ? "ok  " : "FAIL"} ${mb(gate.bytes)} MB before interactive, ceiling ${mb(maxBytes)} MB`);
      failed ||= !ok;
    }
    if (maxInteractive) {
      const ok = gate.interactive <= maxInteractive;
      console.log(`${ok ? "ok  " : "FAIL"} interactive at ${sec(gate.interactive)} s, ceiling ${sec(maxInteractive)} s`);
      failed ||= !ok;
    }
  }
}
if (maxPick) {
  for (const r of results) {
    const ms = r.picked?.ms;
    const ok = Number.isFinite(ms) && ms <= maxPick;
    console.log(`${ok ? "ok  " : "FAIL"} ${r.profile} ${r.label}: ${pickId} in hand ${Number.isFinite(ms) ? `${Math.round(ms)} ms` : "never"} after its click, ceiling ${Math.round(maxPick)} ms`);
    failed ||= !ok;
  }
}
for (const r of results) if (!Number.isFinite(r.marks?.interactive)) { console.log(`FAIL ${r.profile} ${r.label} never became interactive`); failed = true; }
console.log(failed ? "load_check: FAIL" : "load_check: ok");
process.exit(failed ? 1 : 0);
