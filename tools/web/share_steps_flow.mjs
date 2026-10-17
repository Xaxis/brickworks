// Building from a shared link on a slow phone: how long each page of Build
// it takes, from the finger lifting to the page drawn, and how long the
// first step takes to come up from the link.
//
//   tools/export.sh web
//   node tools/web/share_steps_flow.mjs --build=build/web --port=8800 --out=DIR
//   set -a; . ./.env; set +a
//   BW_BYPASS=… node tools/web/share_steps_flow.mjs --url=<preview> --publish --out=DIR
//
// The models are the lowest 300, 1,000 and 4,000 parts of Orthanc
// (models/orthanc.ldr), Brickworks' own file, so the steps are worked out
// as they are for any model made here. --build serves the export here
// (tools/web/serve.py, one link per size with --share ID=FILE, parts from
// assets/generated/parts at once); --url with --publish publishes them to
// that deployment from a throwaway probe account (a Resend test address,
// so the gallery never lists them), and takes them down and deletes the
// account at the end.
//
// In Chromium on SwiftShader, as a phone: 390 x 844 at three device pixels
// to the point, touch, the CPU slowed four times (CDP
// Emulation.setCPUThrottlingRate) from before the link is opened. For each
// size: the link, Build it tapped the moment it is offered and Start the
// moment the cover is up; then Next three times, Back, a tap on the
// progress bar at step 30 (where the model has that many), and End.
//
// Each engine frame is timed in the page (the frame callback, and the time
// inside WebGL apart, as cad_frames.mjs does). A turn is timed from the
// finger lifting (touchend, as the page heard it) to the end of the frame
// that drew the new page — the first frame after the tap, in which the app
// handles it — and to the start of the frame after that, by when the
// browser has put it on the screen. The app also says which frame drew a
// page (window.brickworksBuildDrawn, [page, when]; a build from before
// that is read by its frames alone). The first step is timed from the
// page's first frame drawn by the engine.
//
// Bars: a turn under 100 ms on screen for 300 and 1,000 parts and under
// 200 ms for 4,000; the first step drawn within 3 s of the first frame for
// 300 and 1,000 parts (4,000 said). --report-only says them and judges
// nothing (for a build from before). Pictures of steps 1, 4, 30 and the
// last in --out (<size>_step<n>.png), taken with the CPU at full speed,
// and times.json.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const out = path.resolve(String(args.out || "shots/share_steps"));
mkdirSync(out, { recursive: true });
const sizes = String(args.sizes || "300,1000,4000").split(",").map(Number);
const rate = Number(args.rate || 4);
const reportOnly = Boolean(args["report-only"]);
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const JUMP = Number(args.jump || 30);
const BAR = (parts) => (parts > 1000 ? 200 : 100);
const FIRST_BAR = 3000;
const FIRST_BAR_BIG = 5000;
const PICTURES_BAR = 1000;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const say = (what) => console.log(`  --    ${what}`);

// The lowest [n] parts of Orthanc's own model, its minifigures left out.
function model(n) {
  const text = readFileSync(path.join(root, "models/orthanc.ldr"), "utf8");
  const main = text.split(/\r?\n0 FILE /)[0].split(/\r?\n/);
  const parts = main.filter((line) => /^1 /.test(line) && /\.dat\s*$/i.test(line)).slice(0, n);
  if (parts.length < n) throw new Error(`Orthanc has only ${parts.length} parts of its own`);
  return [`0 FILE steps_${n}.ldr`, `0 Steps ${n}`, `0 Name: steps_${n}.ldr`, "0 Author: Brickworks",
    "", ...parts, ""].join("\r\n");
}

// --- the models, with their steps carried --------------------------------
//
// Each shared as the app shares it: its steps worked out and written at
// the end of its text (SharedPages, by src/dev/share_pages_probe.gd
// --write, the same code the Share panel runs), so the phone reads them
// and works nothing out. --bare shares the text alone, as a link from
// before carried steps is: the phone works them out.
const texts = {};
{
  const dir = path.join(out, "models");
  mkdirSync(dir, { recursive: true });
  const pairs = [];
  for (const n of sizes) {
    const bare = path.join(dir, `steps_${n}_bare.ldr`);
    writeFileSync(bare, model(n));
    texts[n] = bare;
    pairs.push(bare, path.join(dir, `steps_${n}.ldr`));
  }
  if (!args.bare) {
    const made = spawnSync("godot", ["--headless", "--path", root, "--script", "src/dev/share_pages_probe.gd",
      "--", "--write", ...pairs], { encoding: "utf8", timeout: 900000,
      // Never the person's own app data: the checkout's scratch copy.
      env: { ...process.env, XDG_DATA_HOME: process.env.XDG_DATA_HOME || path.join(root, ".scratch-data") } });
    for (const line of String(made.stdout || "").split("\n").filter((l) => / -> /.test(l))) say(line.trim());
    for (const n of sizes) {
      const carried = path.join(dir, `steps_${n}.ldr`);
      if (!/0 !BRICKWORKS PAGES /.test(readFileSync(carried, "utf8"))) {
        throw new Error(`no steps written for ${n} parts: ${String(made.stderr || "").slice(-300)}`);
      }
      texts[n] = carried;
    }
  }
}

// --- where the links are -------------------------------------------------

let site = String(args.url || "").replace(/\/$/, "");
let server = null;
const links = {};
let probe = "";
let token = "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass } : {};
if (args.build) {
  const port = Number(args.port || 8800);
  const shared = [];
  for (const n of sizes) {
    links[n] = `Steps${String(n).padStart(5, "0")}`;
    shared.push("--share", `${links[n]}=${texts[n]}`);
  }
  server = spawn("python3", [path.join(here, "serve.py"), path.resolve(String(args.build)), String(port),
    "--parts", path.join(root, "assets/generated/parts"), "--delay", "0", ...shared],
  { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done, fail) => {
    server.stdout.on("data", (chunk) => { if (/serving/.test(String(chunk))) done(); });
    server.on("exit", (code) => fail(new Error(`serve.py ended (${code})`)));
  });
  site = `http://127.0.0.1:${port}`;
} else if (args.publish) {
  probe = `delivered+bw-sharesteps-${randomBytes(4).toString("hex")}@resend.dev`;
  token = (await mintSession(probe)).access_token;
  for (const n of sizes) {
    const reply = await fetch(`${site}/api/share`, {
      method: "POST",
      headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${token}` },
      body: JSON.stringify({ name: `Steps ${n}`, model: readFileSync(texts[n], "utf8") }),
    });
    const body = await reply.json().catch(() => ({}));
    if (!body.id) throw new Error(`publishing ${n} parts: ${reply.status} ${body.error || ""}`);
    links[n] = body.id;
    console.log(`published ${n} parts as ${body.id} (${body.parts} parts)`);
  }
} else if (args.ids) {
  for (const pair of String(args.ids).split(",")) {
    const [n, id] = pair.split(":");
    links[Number(n)] = id;
  }
} else {
  throw new Error("--build=DIR, or --url=<deployment> with --publish or --ids=300:ID,...");
}

// --- in the page, before the engine starts --------------------------------

function instrument() {
  const perf = { frames: [], taps: [] };
  window.stepFrames = perf;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  let gl = 0;
  let draws = 0;
  let calls = 0;
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    gl = 0;
    draws = 0;
    calls = 0;
    const t0 = performance.now();
    try { callback(time); } finally {
      inside = false;
      perf.frames.push([t0, performance.now() - t0, gl, draws, calls]);
      if (perf.frames.length > 40000) perf.frames.splice(0, 20000);
    }
  };
  const context = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(context)) {
    const d = Object.getOwnPropertyDescriptor(context, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    const drawing = name.startsWith("draw");
    context[name] = function (...a) {
      if (drawing) draws += 1;
      calls += 1;
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
  window.addEventListener("touchend", () => perf.taps.push(performance.now()), true);
  // What the app said it was doing, as it changed: where the first step's
  // time went (the app tells the page twice a second).
  // When the app tells the page all it says (Main._tell_page, twice a
  // second): a turn whose frame did that too is said so.
  perf.tells = [];
  let told = undefined;
  Object.defineProperty(window, "brickworksState", { configurable: true,
    get() { return told; },
    set(v) { told = v; perf.tells.push(performance.now()); if (perf.tells.length > 4000) perf.tells.splice(0, 2000); } });
  perf.phases = [];
  let said = "";
  setInterval(() => {
    const view = ((window.brickworksShare || {}).view || {}).state || "";
    const work = (((window.brickworksState || {}).working || {}).words || "").replace(/[\d,]+ of [\d,]+$/, "");
    const build = ((window.brickworksShare || {}).build || {}).page;
    const now = `${view} | ${work} | ${build ?? ""}`;
    if (now !== said) { said = now; perf.phases.push([Math.round(performance.now()), now]); }
  }, 100);
}

const share = (page) => page.evaluate(() => window.brickworksShare || {});
const build = async (page) => (await share(page)).build || {};
const controls = (page) => page.evaluate(() => window.brickworksControls || {});

async function until(page, test, what, seconds = 300, arg = null, every = 100) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(every);
  }
}

async function where(page, name, seconds = 600) {
  return until(page, (n) => (window.brickworksControls || {})[n], `${name} on the page`, seconds, name);
}

// Frames go quiet: none in the last [span] ms with over 30 ms of the app's
// own work, and none with draw calls for the camera still gliding.
// The app's own laps of the last turn (Main._build_go), once it has told
// the page.
async function laps(page) {
  await page.waitForTimeout(700);
  const said = await build(page);
  return said.turn_last ? { ...said.turn_last, frames: said.turn_frames, told: said.told_laps } : {};
}

async function settle(page, span = 1200, seconds = 60) {
  await page.waitForTimeout(300);
  await until(page, (s) => {
    const t = performance.now();
    const recent = window.stepFrames.frames.filter(([t0]) => t0 >= t - s);
    return recent.length > 0 && recent.every(([, d, g, n]) => d - g < 30 && n === 0);
  }, "the page going quiet", seconds, span, 200).catch(() => null);
}

// A turn timed: the finger's lift as the page heard it, and the frames.
async function timedTap(page, at, wanted) {
  const before = await page.evaluate(() => [window.stepFrames.taps.length,
    (window.brickworksBuildDrawn || [null, 0])[1]]);
  await page.touchscreen.tap(at.x, at.y);
  await until(page, (n) => window.stepFrames.taps.length > n, "the tap heard", 20, before[0], 20);
  const done = await until(page, ([page, n, drawnBefore]) => {
    const b = (window.brickworksShare || {}).build || {};
    const mark = window.brickworksBuildDrawn;
    const tap = window.stepFrames.taps[n];
    const after = window.stepFrames.frames.filter(([t0]) => t0 >= tap);
    const marked = mark && mark[1] > drawnBefore && mark[0] === page;
    if (!(marked || b.page === page) || after.length < 2) return null;
    return { tap, after: after.slice(0, 12), mark: marked ? mark[1] : null };
  }, `page ${wanted}`, 60, [wanted, before[0], before[1]], 50);
  // ...and the parts' pictures along the bottom, every one drawn (the app
  // says when: window.brickworksPicturesDrawn = [page, when]).
  const pictures = await until(page, ([wanted, tap]) => {
    const mark = window.brickworksPicturesDrawn;
    return mark && mark[0] === wanted && mark[1] >= tap ? mark[1] : null;
  }, "the parts' pictures", 30, [wanted, done.tap], 50).catch(() => null);
  const first = done.after[0];
  const handled = first[0] + first[1];
  const shown = done.after[1][0];
  const drawn = done.mark !== null ? done.mark : handled;
  const next = done.after.find(([t0]) => t0 >= drawn) || done.after[done.after.length - 1];
  return {
    page: wanted,
    // The frame that handled it: its own work and its time in WebGL.
    frame: Math.round(first[1]), own: Math.round(first[1] - first[2]), webgl: Math.round(first[2]),
    draws: first[3], calls: first[4],
    waited: Math.round(first[0] - done.tap),
    handled: Math.round(handled - done.tap),
    drawn: Math.round(drawn - done.tap),
    shown: Math.round(Math.max(next[0], shown) - done.tap),
    marked: done.mark !== null,
    pictures: pictures !== null ? Math.round(pictures - done.tap) : null,
    told: await page.evaluate(([from, to]) => window.stepFrames.tells.some((t) => t >= from && t <= to),
      [first[0], handled]),
  };
}

const shot = async (page, cdp, name) => {
  await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
  await page.waitForTimeout(1500);
  // The page as it comes to rest, so pictures of two builds compare: the
  // view arrived (its distance the same twice, half a second apart) and
  // every part's picture along the bottom drawn. On a busy box the camera
  // was still gliding in at 1.5 s, and step 1 was framed further out.
  let distance = -1;
  for (let n = 0; n < 60; n += 1) {
    const now = await page.evaluate(() => [((window.brickworksState || {}).view || {}).distance,
      ((window.brickworksShare || {}).build || {}).pictures, ((window.brickworksShare || {}).build || {}).lots]);
    if (now[0] === distance && now[1] === now[2]) break;
    distance = now[0];
    await page.waitForTimeout(500);
  }
  // ...and twenty frames more, by which the camera's glide (a share of the
  // way each frame, by the frame's length) has arrived.
  const frames = await page.evaluate(() => window.stepFrames.frames.length);
  await until(page, (n) => window.stepFrames.frames.length >= n + 20, "twenty frames", 60, frames, 100)
    .catch(() => null);
  await page.screenshot({ path: path.join(out, name), timeout: 180000 })
    .catch((trouble) => say(`no picture ${name}: ${String(trouble).split("\n")[0]}`));
  await cdp.send("Emulation.setCPUThrottlingRate", { rate });
  await settle(page);
};

const times = {};

// --trace=DIR: a Chromium trace of the turns (Next, Back, the jump), and
// what in each turn's frame took the time: the app marks the frame
// (console.timeStamp "bw:turned", "bw:process_frame", "bw:first_node",
// "bw:last_node", "bw:pre_draw", "bw:post_draw"), and the trace says what
// ran between, garbage collection and all.
const traceDir = args.trace ? path.resolve(String(args.trace)) : "";
const TRACED = ["devtools.timeline", "v8", "v8.execute", "disabled-by-default-v8.gc", "blink.console", "toplevel"];

function readTrace(file) {
  const events = JSON.parse(readFileSync(file, "utf8")).traceEvents || [];
  const marks = events.filter((e) => e.name === "TimeStamp" && /^bw:/.test(e.args?.data?.message || ""));
  const out = [];
  for (let n = 0; n < marks.length; n += 1) {
    if (marks[n].args.data.message !== "bw:turned") continue;
    const { pid, tid } = marks[n];
    const at = {};
    for (let k = n; k < marks.length && !(k > n && marks[k].args.data.message === "bw:turned"); k += 1) {
      at[marks[k].args.data.message.slice(3)] = marks[k].ts;
    }
    const from = at.turned;
    const to = at.post_draw || from;
    const inside = events.filter((e) => e.pid === pid && e.tid === tid && e.ph === "X" && e.dur
      && e.ts >= from && e.ts + e.dur <= to + 1000);
    const gc = inside.filter((e) => /GC|Scavenge|MarkCompact|MinorMS|MajorMS/i.test(e.name));
    const sum = (list) => Math.round(list.reduce((t, e) => t + e.dur, 0) / 1000);
    const top = inside.filter((e) => !/RunTask|ThreadControllerImpl|FireAnimationFrame|FunctionCall|v8.callFunction/
      .test(e.name)).sort((a, b) => b.dur - a.dur).slice(0, 4)
      .map((e) => `${e.name} ${Math.round(e.dur / 1000)}`);
    const step = (a, b) => (at[a] && at[b] ? Math.round((at[b] - at[a]) / 1000) : null);
    out.push({ frame: Math.round((to - from) / 1000), gc: sum(gc), gc_events: gc.length,
      to_processing: step("turned", "process_frame"), before_nodes: step("process_frame", "first_node"),
      nodes: step("first_node", "last_node"), after_nodes: step("last_node", "pre_draw"),
      drawing: step("pre_draw", "post_draw"), top });
  }
  return out;
}
const browser = await launch({ signedOut: true });
try {
  for (const n of sizes) {
    const id = links[n];
    console.log(`\n${n} parts (${site}/m/${id}), a phone, 390 x 844 at 3x, touch, CPU slowed ${rate}x`);
    const context = await browser.newContext({ viewport: { width: 390, height: 844 },
      deviceScaleFactor: 3, isMobile: true, hasTouch: true, extraHTTPHeaders: headers });
    await context.addInitScript(instrument);
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error/.test(m.text())) errors.push(m.text().slice(0, 220));
    });
    const cdp = await context.newCDPSession(page);
    const record = { parts: n, id, turns: [] };
    times[n] = record;

    // The link; slowed from the engine's first frame (the download and the
    // engine starting are not what is timed, and slowed they took over ten
    // minutes here); Build it the moment it is offered; Start the moment
    // the cover is up.
    const opened = Date.now();
    await page.goto(`${site}/m/${id}`, { waitUntil: "domcontentloaded", timeout: 180000 });
    // On a deployment the link is the model's own page, whose button opens
    // it in the app (serve.py goes straight on).
    const cta = await page.$('.actions a.cta[href^="/app?view="]').catch(() => null);
    if (cta) {
      await Promise.all([page.waitForURL(/\/app\?view=/, { timeout: 180000 }), cta.tap()]);
    }
    const firstFrame = await until(page, () => (window.stepFrames.frames.find(([, , , d]) => d > 0) || [0])[0],
      "the engine's first frame", 600, null, 50);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate });
    say(`the engine's first frame ${((Date.now() - opened) / 1000).toFixed(1)} s after the link was opened; slowed from there`);
    const offeredAt = await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready"
      && (window.brickworksControls || {}).view_build, "Build it", 900);
    const offered = await page.evaluate(() => performance.now());
    // Tapped the moment it is offered, as a person would. A build from
    // before 2026-10-17 drops a tap made while the steps are still being
    // worked out, so then it is tapped again once the timeline is up, where
    // the button is by then.
    let buildIt = offeredAt;
    for (let tries = 1; ; tries += 1) {
      await page.touchscreen.tap(buildIt.x, buildIt.y);
      // Open as soon as the app says so; its controls are told the page a
      // telling or two later, which on a busy box is seconds.
      const isOpen = () => ((window.brickworksShare || {}).build || {}).open === true;
      await until(page, () => ((window.brickworksShare || {}).build || {}).open === true
        || ((window.brickworksShare || {}).steps || []).length > 0, "the cover or the timeline", 600, null, 100);
      const open = await until(page, isOpen, "the cover", 20, null, 100).catch(() => null);
      if (open) {
        await until(page, () => (window.brickworksControls || {}).build_next, "Start on the cover", 120);
        break;
      }
      if (tries >= 3) throw new Error("Build it tapped three times and no cover");
      record.tapped_again = (record.tapped_again || 0) + 1;
      buildIt = await until(page, () => ((window.brickworksShare || {}).steps || []).length > 0
        && (window.brickworksControls || {}).view_build, "the timeline up", 600);
    }
    const start = (await controls(page)).build_next;
    // When the cover was drawn, as the app says, and the Build it tap
    // before it; then Start.
    const cover = await page.evaluate(() => [window.stepFrames.taps[window.stepFrames.taps.length - 1],
      (window.brickworksBuildDrawn || [null, 0])[1], window.brickworksStepsReady || 0,
      Boolean((window.brickworksShare || {}).carried)]);
    const first = await timedTap(page, start, 1);
    const tapAt = await page.evaluate(() => window.stepFrames.taps[window.stepFrames.taps.length - 1]);
    const firstStep = Math.round(tapAt + first.shown - firstFrame);
    // The same with every tap made the moment the app could take it: when
    // its steps were ready (Build it does nothing useful sooner), the cover
    // as long as it took from then, and step 1 as long as it took from
    // Start. The flow's own polling (the page hears where a control is
    // half a second after it appears) is not the app's time.
    const [buildTap, coverDrawn, stepsReady, carried] = cover;
    const ready = stepsReady || offered;
    const atOnce = coverDrawn > 0 && stepsReady > 0
      ? Math.round(ready - firstFrame + (coverDrawn - Math.max(buildTap, ready)) + first.shown) : firstStep;
    record.first = { first_frame: Math.round(firstFrame), build_it_offered: Math.round(offered - firstFrame),
      steps_ready: stepsReady ? Math.round(stepsReady - firstFrame) : null, carried,
      cover_ms: coverDrawn ? Math.round(coverDrawn - Math.max(buildTap, ready)) : null,
      first_step: firstStep, first_step_at_once: atOnce, start: first };
    record.first.phases = await page.evaluate((from) => window.stepFrames.phases
      .map(([t, what]) => [t - Math.round(from), what]), firstFrame);
    // Where the wait went: the engine's frames between the first and step 1,
    // their own work and their time in WebGL, and the time between them.
    record.first.frames = await page.evaluate(([from, to]) => {
      const frames = window.stepFrames.frames.filter(([t0]) => t0 >= from && t0 <= to);
      const sum = (f) => Math.round(frames.reduce((n, x) => n + f(x), 0));
      return { count: frames.length, own: sum(([, d, g]) => d - g), webgl: sum(([, , g]) => g),
        longest: Math.round(Math.max(0, ...frames.map(([, d]) => d))), wall: Math.round(to - from) };
    }, [firstFrame, tapAt + first.shown]);
    say(`from the first frame to step 1: ${JSON.stringify(record.first.frames)} (ms)`);
    say(`on the way: ${record.first.phases.map(([t, what]) => `${(t / 1000).toFixed(1)} s ${what}`).join(" · ")}`);
    const s1 = await build(page);
    say(`Build it offered ${Math.round(offered - firstFrame)} ms after the first frame; `
      + `step 1 on screen ${firstStep} ms after it ("${s1.caption}", ${s1.fresh} new parts, ${s1.lots} lots)`);
    say(`steps ${carried ? "carried with the link" : "worked out here"}, ready ${record.first.steps_ready} ms `
      + `after the first frame; the cover ${record.first.cover_ms} ms after Build it; step 1 on screen `
      + `${first.shown} ms after Start; with each tap at once, step 1 ${atOnce} ms after the first frame `
      + `(as tapped here, ${firstStep})`);
    record.first.opened = (await share(page)).opened || {};
    say(`the viewer's way there (ms from its start): ${JSON.stringify(record.first.opened)}`);
    if (!reportOnly) {
      const bar = n > 1000 ? FIRST_BAR_BIG : FIRST_BAR;
      check(`the first step is drawn within ${bar / 1000} s of the page's first frame, each tap made at once `
        + `(${atOnce} ms)`, atOnce <= bar);
    }
    await settle(page);
    await shot(page, cdp, `${n}_step1.png`);

    // The turns.
    if (traceDir) {
      mkdirSync(traceDir, { recursive: true });
      await browser.startTracing(page, { path: path.join(traceDir, `${n}_turns.json`), categories: TRACED });
    }
    const next = (await controls(page)).build_next;
    const back = (await controls(page)).build_back;
    for (let k = 2; k <= 4; k += 1) {
      record.turns.push({ what: "next", ...(await timedTap(page, next, k)), laps: await laps(page) });
      await settle(page);
    }
    await shot(page, cdp, `${n}_step4.png`);
    record.turns.push({ what: "back", ...(await timedTap(page, back, 3)), laps: await laps(page) });
    await settle(page);
    const last = (await build(page)).last;
    const bar = (await controls(page)).build_progress;
    if (bar && last >= JUMP) {
      // The progress bar is the steps across: a tap lands on the step under
      // it. Aimed at the middle of step 30's share.
      const x = bar.x - bar.w / 2 + (bar.w * (JUMP - 0.5)) / last;
      record.turns.push({ what: `jump to ${JUMP}`, ...(await timedTap(page, { x, y: bar.y }, JUMP)),
        laps: await laps(page) });
      await settle(page);
      await shot(page, cdp, `${n}_step${JUMP}.png`);
    } else {
      say(bar ? `only ${last} steps: no jump to ${JUMP}` : "no progress bar to tap (a build from before): no jump");
    }
    if (traceDir) {
      await browser.stopTracing();
      record.traced = readTrace(path.join(traceDir, `${n}_turns.json`));
      for (const turn of record.traced) say(`traced: ${JSON.stringify(turn)}`);
    }
    // End, a jump to the last step, as a key.
    const endAt = await page.evaluate(() => performance.now());
    const endDrawn = (await page.evaluate(() => (window.brickworksBuildDrawn || [0, 0])[1]));
    await page.keyboard.press("End");
    const end = await until(page, ([since, drawnBefore, wanted]) => {
      const b = (window.brickworksShare || {}).build || {};
      const mark = window.brickworksBuildDrawn;
      const marked = mark && mark[1] > drawnBefore && mark[0] === wanted;
      const after = window.stepFrames.frames.filter(([t0]) => t0 >= since);
      if (!(marked || b.page === wanted) || after.length < 2) return null;
      const handler = after.find(([, d, g]) => d - g > 5) || after[0];
      return { frame: Math.round(handler[1]), own: Math.round(handler[1] - handler[2]),
        drawn: Math.round((marked ? mark[1] : handler[0] + handler[1]) - since) };
    }, "the last step", 60, [endAt, endDrawn, last], 50);
    record.turns.push({ what: "end (key)", page: last, ...end });
    await settle(page);
    await shot(page, cdp, `${n}_step${last}.png`);

    const s = await build(page);
    record.turn_most = s.turn_most;
    record.told_most_ms = (await page.evaluate(() => (window.brickworksState || {}).told_most_ms));
    for (const turn of record.turns) {
      const line = `${turn.what} to ${turn.page}: on screen ${turn.shown ?? "?"} ms, drawn ${turn.drawn} ms `
        + `(frame ${turn.frame} ms: own ${turn.own}, WebGL ${turn.webgl ?? "?"} in ${turn.calls ?? "?"} calls, `
        + `${turn.draws ?? "?"} draws; waited ${turn.waited ?? "?"} for it${turn.told ? "; the page told all in it" : ""})`
        + (turn.laps ? ` ${JSON.stringify(turn.laps)}` : "");
      if (turn.what === "end (key)" || reportOnly) say(line);
      else check(`${line} under ${BAR(n)} ms`, turn.shown <= BAR(n));
      if (turn.what !== "end (key)" && !reportOnly) {
        check(`...and every part's picture along the bottom within ${PICTURES_BAR} ms of the tap `
          + `(${turn.pictures ?? "never, in 30 s"})`, turn.pictures !== null && turn.pictures <= PICTURES_BAR);
      }
    }
    say(`the page's own work in its slowest turn: ${JSON.stringify(s.turn_most)}; `
      + `telling the page up to ${record.told_most_ms} ms a frame`);
    check(`no script errors (${errors.length})`, errors.length === 0);
    for (const e of errors.slice(0, 5)) console.log(`        ${e}`);
    await context.close();
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  await browser.close();
  writeFileSync(path.join(out, "times.json"), JSON.stringify(times, null, 1));
  if (server) server.kill();
  if (probe) {
    for (const id of Object.values(links)) {
      await fetch(`${site}/api/share?op=unpublish&id=${id}`, { method: "POST",
        headers: { ...headers, authorization: `Bearer ${token}` } }).catch(() => {});
    }
    check(`the probe account deleted, and its links with it (${probe})`, await deleteAccount(probe));
  }
}
console.log(failed ? `\n${failed} FAILED` : (reportOnly ? "\nsaid, not judged"
  : "\na shared model's pages turn quickly on a slow phone, and its first step comes up quickly"));
process.exit(failed ? 1 : 0);
