// Does the studio say it heard you, and stay alive, while it works? Presses
// each slow thing in a real browser and times it.
//
//   set -a; . ./.env; set +a
//   node tools/web/progress_check.mjs --dir=build/web            a local export, served here
//   BW_BYPASS=… node tools/web/progress_check.mjs --url=<preview>/app
//   … --only=timeline,booklet                                    some of them
//
// The owner (2026-10-12): "when user clicks the 'timeline' function there
// should be the standard pattern for progress bar or whatever indicating what
// is happening and what is loading, same for all functions that obviously
// take a lot of time or between context switches so the studio doesn't
// appear and functionally act frozen." Each slow thing now reports to one bar
// in the status bar (src/ui/working.gd), which says on the page when it was
// first drawn and when it went (window.brickworksWork).
//
// For every press it measures, against the press's own time in the page:
//
//   said     the app's own work from the press until it put the bar up:
//            every engine frame and input handler from the press to the one
//            the bar was begun in (its first drawing less the app's own
//            ms from begin to drawn, which it tells the page), that one
//            whole. What is judged: a long act that says nothing until it is
//            done does its work there, and one that begins the bar and works
//            on in the same frame does it in the frame counted whole;
//   heard    how long before the bar was drawn, by the page's clock: the end
//            of the engine frame it was first drawn in. A build without the
//            bar is read by its page state instead (the status line, the
//            timeline's buttons, the parts), polled every quarter second,
//            and marked ~. Said, not judged: on SwiftShader that frame waits
//            on the software drawing of the frames before it, or is held for
//            a picture read back (GpuFence), as long as the box's load says;
//   own      the longest of the app's own work in one go from the press to
//            the end, which is what is judged: an engine frame or one of its
//            input handlers (a press can be handled outside a frame, and
//            Timeline's eight seconds were). After it, said and not judged,
//            the same by the page's clock less the time inside WebGL calls,
//            or the app's slowest frame by its own clock (brickworksState.slow,
//            labelled with what it was doing), whichever is longer;
//   frame    the longest engine frame callback, timed in the page as
//            render_open_check.mjs does: the app's work and its WebGL calls,
//            which on SwiftShader wait for the software drawing of the frame
//            before whenever the box is busy. Said, not judged;
//   held     the longest the page ran no timer at all, drawing included.
//            Said, not judged;
//   total    from the press until it is done;
//   gone     whether the bar is gone once it is done.
//
// Two pages: a first visit (the example car) for the parts bin's first open,
// Instructions, the Render dialog, LEGO Art's Build of a picture and
// Brickify of the bunny; then Orthanc (9,429 parts) opened from a file, for
// Timeline, Save, File > Export > LDraw, Same colour from one part, Mirror
// and Shift-E of all of it, Check stability, Delete of all of it, Undo, and
// New's "Save, then start new" (the owner's freeze, 2026-10-13) — or New
// without saving, with --only=new. The commands after Timeline are the ones
// src/dev/command_probe.gd found holding the window longest.
//
// The app's own work is its time on a CPU (traceFrom): on a busy box the
// page's clock counts the time the page waited for a core, and on
// SwiftShader for the drawing, which is the box and not the app.
//
// Fails when a press that is meant to show the bar (EXPECT) does not, or
// does over --said ms (150) of its own work first; when one of the four that
// must stay alive (ALIVE) has over --budget ms (300) of its own in one go;
// or when the bar is still up at the end. The bars, from m145's and m146's
// builds three times each at load 26 to 52 (2026-10-22): the most a press
// did before its bar was 82 ms (Export; another Export's 27 ms before
// it was 1,195 ms heard by the page), and the longest frame of the four
// was 241 ms (Timeline finding its joints; 184 to 241 across the six).
// A CPU's time stops growing with the load once every core's two threads
// are busy, at 24, so a loaded box is the worst case and an idle one is
// faster. 150 is the app's own line for a command it must say before it
// runs (Working.SAY_FIRST_MS); 300 is a quarter over the worst frame seen,
// still under the 355 and 377 ms frames this check found in Brick Art
// (2026-10-15), though over the 273 ms Timeline slice it found then. Every
// one of the six failed the old bars by the page's clock (heard up to
// 3,667 ms, a frame of 315 ms).
// --report-only prints the table and passes, for a build from before.
// --model=FILE --parts=N opens FILE, of N parts, where Orthanc is opened:
// --only=timeline with a model whose author's steps are taken out times the
// planner (Instructions.plan_paced) in the browser.
import { controlsWith, launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { deflateSync } from "node:zlib";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/progress";
mkdirSync(out, { recursive: true });
const budget = Number(args.budget || 300);
const saidBudget = Number(args.said || 150);
const reportOnly = Boolean(args["report-only"]);
const only = args.only ? String(args.only).split(",") : null;
const wanted = (name) => !only || only.includes(name);
const bypass = process.env.BW_BYPASS || "";
// The presses that show the bar, and the ones held to the frame budget.
const EXPECT = new Set(["timeline", "booklet", "art", "brickify", "open", "delete", "undo", "new",
  "save", "export", "save_new", "mirror", "select_colour", "turn", "stability"]);
const ALIVE = new Set(["timeline", "booklet", "art", "brickify"]);

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
const withBypass = (u) => (bypass
  ? `${u}${u.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : u);

// The galaxy art_flow.mjs lays, 96 x 64, written as a PNG.
function crc32(bytes) {
  let c = ~0;
  for (const b of bytes) {
    c ^= b;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}
function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4, "ascii");
  const tail = Buffer.alloc(4);
  tail.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0);
  return Buffer.concat([head, data, tail]);
}
function galaxy(w, h) {
  const rows = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    rows[y * (w * 3 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const dx = (x - w / 2) / (w / 2);
      const dy = (y - h / 2) / (h / 2);
      const r = Math.hypot(dx * 0.9 + dy * 0.3, (dy - dx * 0.2) * 1.8);
      const disc = Math.max(0, 1 - r);
      const core = Math.max(0, 1 - r * 4);
      const at = y * (w * 3 + 1) + 1 + x * 3;
      rows[at] = Math.min(255, 10 + disc * 150 + core * 105);
      rows[at + 1] = Math.min(255, 12 + disc * 110 + core * 130);
      rows[at + 2] = Math.min(255, 40 + disc * 170 + core * 45);
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(w, 0);
  header.writeUInt32BE(h, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header), chunk("IDAT", deflateSync(rows)), chunk("IEND", Buffer.alloc(0))]);
}
const picture = resolve(out, "galaxy.png");
writeFileSync(picture, galaxy(96, 64));
const bunny = resolve("tests/fixtures/brickify/bunny.obj");
const orthanc = resolve(args.model || "models/orthanc.ldr");
// When the big model is open, and when its opening is heard: Orthanc's
// counts, or a little under --parts and a ninth of it.
const opened = args.parts ? Number(args.parts) * 0.95 : 9000;
const begun = args.parts ? Number(args.parts) / 9 : 1000;

// In the page before the engine starts: every engine frame timed, and every
// press noted, in the page's own clock.
function instrument() {
  const perf = { frames: [], presses: [] };
  window.brickworksFrames = perf;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  // Time spent inside WebGL calls in the frame going: what is left of a
  // frame without it is the app's own work, input handled in the frame
  // included, which the app's own clock (OwnFrames) starts after.
  let gl = 0;
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    gl = 0;
    const t0 = performance.now();
    try { callback(time); } finally {
      inside = false;
      perf.frames.push([t0, performance.now() - t0, "frame", gl]);
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
  // And the engine's own input handlers, which run outside its frame: a
  // button's press can do its work there, and the first version of this
  // check missed Timeline's eight seconds because it timed frames alone.
  const wrapped = new WeakMap();
  const add = EventTarget.prototype.addEventListener;
  const remove = EventTarget.prototype.removeEventListener;
  EventTarget.prototype.addEventListener = function (type, listener, options) {
    if (typeof listener !== "function" || !/^(pointer|mouse|key|wheel|touch|click|contextmenu)/.test(type)) {
      return add.call(this, type, listener, options);
    }
    let timedListener = wrapped.get(listener);
    if (!timedListener) {
      timedListener = function (...a) {
        if (inside) return listener.apply(this, a);
        inside = true;
        const t0 = performance.now();
        try { return listener.apply(this, a); } finally {
          inside = false;
          perf.frames.push([t0, performance.now() - t0, "input", 0]);
        }
      };
      wrapped.set(listener, timedListener);
    }
    return add.call(this, type, timedListener, options);
  };
  EventTarget.prototype.removeEventListener = function (type, listener, options) {
    return remove.call(this, type, wrapped.get(listener) || listener, options);
  };
  // The page held, whatever held it: how late a timer every 20 ms ran.
  perf.stalls = [];
  let beat = performance.now();
  setInterval(() => {
    const now = performance.now();
    if (now - beat > 70) perf.stalls.push([beat, now - beat - 20]);
    beat = now;
  }, 20);
  for (const kind of ["pointerdown", "keydown"]) {
    window.addEventListener(kind, () => perf.presses.push(performance.now()), true);
  }
}

const rows = [];
let failures = 0;
const browser = await launch();
const errors = [];

async function openPage(address) {
  const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  await context.addInitScript(instrument);
  const page = await context.newPage();
  page.choosers = [];
  page.on("filechooser", (chooser) => page.choosers.push(chooser));
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 200));
  });
  await page.goto(withBypass(address), { waitUntil: "domcontentloaded", timeout: 180000 });
  return { context, page };
}

function helpers(page) {
  const controls = () => page.evaluate(() => window.brickworksControls || {});
  const state = () => page.evaluate(() => window.brickworksState || {});
  const now = () => page.evaluate(() => performance.now());
  async function where(name, seconds = 120) {
    for (let n = 0; n < seconds * 2; n++) {
      const at = (await controls())[name];
      if (at) return at;
      if (n === 2) await openColumnFor(page, name);
      await page.waitForTimeout(500);
    }
    await page.screenshot({ path: `${out}/never_${name}.png` }).catch(() => {});
    throw new Error(`the app never showed "${name}"`);
  }
  // Quiet: no bar up and [span] ms of engine frames under 100 ms, by
  // [longest] ms at the latest.
  async function quiet(span = 3000, longest = 120000) {
    const until = Date.now() + longest;
    while (Date.now() < until) {
      await page.waitForTimeout(500);
      const ok = await page.evaluate((s) => {
        const t = performance.now();
        const recent = window.brickworksFrames.frames.filter(([t0]) => t0 >= t - s);
        const busy = Object.keys((window.brickworksState || {}).working || {}).length > 0;
        return !busy && t > s && recent.every(([, d]) => d < 100);
      }, span);
      if (ok) return true;
    }
    return false;
  }
  return { controls, state, now, where, quiet };
}

// Each engine frame and input handler of a press, timed on a CPU: Chrome's
// trace says how long each callback ran on the page's thread (tdur), which
// the box's load does not stretch. The page's clock counts the time the
// thread waited for a core too, and on SwiftShader for the drawing: m145's
// Timeline had a 263 ms frame of its own by it at load 29, and m146's booklet
// 378 ms at load 38. The page stamps the trace with its own clock, and its
// entries are found there by when they began.
async function traceFrom(page) {
  try {
    await browser.startTracing(page, { categories: ["devtools.timeline"] });
  } catch {
    return null;
  }
  return page.evaluate(() => {
    const t = performance.now();
    console.timeStamp(`progress ${t}`);
    return t;
  });
}
// A function of a page entry ([t0, ms, kind, gl]) to its CPU ms, or null
// where the trace has none.
async function traceTo(mark) {
  const none = Object.assign(() => null, { traced: false });
  if (mark === null) return none;
  let events;
  try {
    events = JSON.parse((await browser.stopTracing()).toString()).traceEvents;
  } catch {
    return none;
  }
  const stamp = events.find((e) => e.name === "TimeStamp" && e.args?.data?.message === `progress ${mark}`);
  if (!stamp) return none;
  const offset = stamp.ts - mark * 1000;
  const calls = { frame: [], input: [] };
  for (const e of events) {
    if (e.ph !== "X" || e.pid !== stamp.pid || e.tid !== stamp.tid || e.tdur === undefined) continue;
    if (e.name === "FireAnimationFrame") calls.frame.push(e);
    else if (e.name === "FunctionCall") calls.input.push(e);
  }
  for (const list of Object.values(calls)) list.sort((a, b) => a.ts - b.ts);
  // The innermost callback of its kind that it began in: the last to begin
  // before it, of those it lies inside. One begun after it is a call of its.
  return Object.assign(([t0, , kind]) => {
    const list = calls[kind === "frame" ? "frame" : "input"];
    const at = t0 * 1000 + offset;
    let lo = 0;
    let hi = list.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (list[mid].ts <= at + 100) lo = mid + 1;
      else hi = mid;
    }
    for (let n = lo - 1; n >= 0 && n >= lo - 50; n--) {
      if (at <= list[n].ts + list[n].dur) return list[n].tdur / 1000;
    }
    return null;
  }, { traced: true });
}

// One press, measured. [press] does it; [done] says, from the page's state,
// when it has finished; [heard] says, for a build without the bar, whether
// anything on screen has answered yet.
// With [settle], done is when the page has also gone quiet after it: the
// parts bin is open at once, and then draws its pictures.
async function measure(page, name, press, done, heard, seconds = 300, settle = false) {
  const { state, now, quiet } = helpers(page);
  const from = await now();
  const engineFrom = (await state()).now || 0;
  const mark = await traceFrom(page);
  await press();
  const t0 = Date.now();
  let heardAt = null;
  let doneAt = null;
  let last = {};
  while (Date.now() - t0 < seconds * 1000) {
    const [s, t, c] = await Promise.all([state(), now(),
      page.evaluate(() => window.brickworksControls || {})]);
    last = s;
    if (heardAt === null && (Object.keys(s.working || {}).length > 0 || (await heard(s, c)))) heardAt = t;
    if (await done(s, c)) { doneAt = t; break; }
    await page.waitForTimeout(250);
  }
  await quiet(2000, 60000);
  if (settle && doneAt !== null) doneAt = (await now()) - 2000;
  const facts = await page.evaluate(([a]) => {
    const p = window.brickworksFrames;
    const press = p.presses.filter((t) => t >= a)[0] ?? a;
    const work = (window.brickworksWork || []).filter((e) => e.at >= press);
    const shown = work.find((e) => e.shown);
    // The frame the bar was first drawn in ends after it said so.
    const frameOf = shown ? p.frames.find(([t0, d]) => t0 <= shown.at && shown.at <= t0 + d + 1) : null;
    // The frame or handler the bar was begun in: its first drawing less
    // the app's own ms from then. One begun outside them (a file's bytes
    // handed over by a callback) has the ones before it.
    const setAt = shown ? Math.max(press, shown.at - (shown.ms || 0)) : -1;
    const setIn = shown ? p.frames.find(([t0, d]) => t0 - 1 <= setAt && setAt <= t0 + d + 1) : null;
    const until = setIn ? setIn[0] : setAt;
    const before = p.frames.filter(([t0]) => t0 >= press && t0 <= until);
    return { press, shownAt: shown ? (frameOf ? frameOf[0] + frameOf[1] : shown.at) : null,
      setAt: shown ? setAt - press : null, before,
      what: shown ? shown.what : "", frames: p.frames.filter(([t0]) => t0 >= press),
      stalls: p.stalls.filter(([t0]) => t0 >= press - 20) };
  }, [from]);
  const cpu = await traceTo(mark);
  const end = doneAt ?? (await now());
  const during = facts.frames.filter(([t0]) => t0 <= end);
  const longest = Math.max(0, ...during.map(([, d]) => d));
  // How long the page went without running a timer, drawing included.
  const stall = Math.max(0, ...facts.stalls.filter(([t0]) => t0 <= end).map(([, d]) => d));
  const s = await state();
  // Its slowest frames by its own clock (scripts, from a frame's start to
  // its drawing: Main._watch_own_frames), said for what they were doing.
  const slow = (s.slow || []).filter(([t]) => t >= engineFrom).sort((a, b) => b[1] - a[1]).slice(0, 3);
  // The app's own work, which is what is judged: each engine frame and
  // input handler's time on a CPU, or where there is no trace, its time
  // less the time it spent inside WebGL calls.
  const work = (entry) => cpu(entry) ?? entry[1] - (entry[3] || 0);
  const own = Math.max(0, ...during.map(work));
  const ownWall = Math.max(0, ...slow.map(([, ms]) => ms), ...during.map(([, d, , g]) => d - (g || 0)));
  const gone = Object.keys(s.working || {}).length === 0;
  const heardMs = facts.shownAt !== null ? facts.shownAt - facts.press
    : (heardAt !== null ? heardAt - facts.press : null);
  const row = {
    name, heard: heardMs === null ? null : Math.round(heardMs), byBar: facts.shownAt !== null,
    ownBefore: facts.shownAt === null ? null : Math.round(facts.before.reduce((a, e) => a + work(e), 0)),
    ownBeforeWall: facts.shownAt === null ? null : Math.round(facts.before.reduce((a, [, d, , g]) => a + d - g, 0)),
    setAt: facts.setAt === null ? null : Math.round(facts.setAt), traced: cpu.traced,
    untraced: during.filter((e) => cpu(e) === null).length,
    before: facts.before.map((e) => [Math.round(e[0] - facts.press), Math.round(e[1]), e[2], Math.round(e[3]),
      cpu(e) === null ? null : Math.round(cpu(e))]),
    // Its longest four, as [ms from the press, ms, kind, ms in WebGL, ms on a CPU].
    longestFour: [...during].sort((a, b) => b[1] - a[1]).slice(0, 4).map((e) => [Math.round(e[0] - facts.press),
      Math.round(e[1]), e[2], Math.round(e[3]), cpu(e) === null ? null : Math.round(cpu(e))]),
    own: Math.round(own), ownWall: Math.round(ownWall), longest: Math.round(longest), stall: Math.round(stall), total: doneAt === null ? null : Math.round(doneAt - facts.press),
    gone, frames: during.length, what: facts.what, said: String(last.said || "").slice(0, 80),
  };
  const problems = [];
  if (doneAt === null) problems.push("never finished");
  if (EXPECT.has(name) && !row.byBar) problems.push("no bar");
  else if (EXPECT.has(name) && row.ownBefore > saidBudget) problems.push(`${row.ownBefore} ms of its own before the bar`);
  if (ALIVE.has(name) && row.own > budget) problems.push(`a ${row.own} ms frame of its own`);
  if (!gone) problems.push("the bar is still up");
  row.problems = problems;
  rows.push(row);
  const failed = problems.length > 0 && !reportOnly;
  if (failed) failures += 1;
  const heardText = row.heard === null ? "never" : `${row.byBar ? "" : "~"}${row.heard} ms`;
  const saidText = row.ownBefore === null ? "—" : `${row.ownBefore} ms`;
  console.log(`${failed ? "FAIL" : "ok  "}  ${name.padEnd(10)} said ${saidText.padStart(7)}  heard ${heardText.padStart(9)}`
    + `  own ${String(row.own).padStart(6)} ms (${row.ownWall} wall)`
    + `  frame ${String(row.longest).padStart(6)} ms  page held ${String(row.stall).padStart(6)} ms`
    + `  total ${row.total === null ? "    —" : String(row.total).padStart(7) + " ms"}  ${gone ? "gone" : "STILL UP"}`
    + `  ${row.what || row.said}${problems.length ? "  [" + problems.join("; ") + "]" : ""}`);
  // What it was busy with in its slowest frames.
  if (slow.length) {
    row.slowest = slow;
    const said = slow.map(([, ms, , doing]) => `${ms} ms ${String(doing || "").slice(0, 60)}`);
    console.log(`        (its slowest frames: ${said.join("; ")})`);
  }
  await page.screenshot({ path: `${out}/${name}.png`, timeout: 120000 }).catch(() => {});
  return row;
}

const said = (pattern) => (s) => pattern.test(String(s.said || ""));
const idle = (s) => Object.keys(s.working || {}).length === 0;
// A command from a menu, as a person picks it: the menu opened, a word that
// only its item starts with typed (a menu jumps to what is typed, searching
// on from where it is; a space would press the item it is on, and the rest
// go to the app as keys: "Select by" pressed Select all and then B, the
// timeline), or Down to it ([word, downs]), a submenu opened with the right
// arrow; the caller presses Enter, and that is the press that is timed
// (the menu opened and typed into took five seconds before it, and timed
// from the first click Export was "heard" after 5.5 s).
async function fromMenu(page, control, path) {
  const at = await helpers(page).where(control);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
  for (let n = 0; n < path.length; n++) {
    const [word, downs] = Array.isArray(path[n]) ? path[n] : [path[n], 0];
    if (/\s/.test(word)) throw new Error(`a menu is typed into a word at a time, not "${word}"`);
    if (word) await page.keyboard.type(word, { delay: 120 });
    for (let d = 0; d < downs; d++) {
      await page.waitForTimeout(300);
      await page.keyboard.press("ArrowDown");
    }
    await page.waitForTimeout(600);
    if (n < path.length - 1) {
      await page.keyboard.press("ArrowRight");
      await page.waitForTimeout(1200);
    }
  }
}
const press = (page, name) => async () => {
  const at = await helpers(page).where(name);
  await page.mouse.click(at.x, at.y);
};

try {
  // -- a first visit: the example car ----------------------------------------
  const { context, page } = await openPage(url);
  const h = helpers(page);
  await h.where("open", 400);
  console.log(`car page up; settling…`);
  await h.quiet(4000, 180000);

  if (wanted("bin")) {
    await measure(page, "bin", press(page, "parts_rail"),
      async (s) => Boolean(s.columns && s.columns.parts), async () => false, 60, true);
    await h.quiet(3000, 120000);
  }
  if (wanted("booklet")) {
    const opened = context.waitForEvent("page", { timeout: 600000 }).catch(() => null);
    let tab = null;
    opened.then((t) => { tab = t; });
    await measure(page, "booklet", press(page, "instructions"),
      async (s) => said(/booklet is open|wrote|nothing to write/)(s)
        || (tab !== null && (await tab.evaluate(() => document.querySelectorAll("section.page").length).catch(() => 0)) > 0),
      async (s) => said(/booklet|planning|setting out|drawing/)(s), 600);
    if (tab) await tab.close().catch(() => {});
    await h.quiet(3000, 60000);
  }
  if (wanted("render")) {
    await page.evaluate(() => { window.brickworksRender = null; });
    await measure(page, "render", press(page, "tool_render"),
      async () => /Render draws/.test(String((await page.evaluate(() => window.brickworksRender || {})).status || "")),
      async (_s, c) => Boolean(c.render_picture), 240);
    // Waited for, after the timing: a control is told to the page only once
    // it has stayed where it is drawn (Main._page_places).
    const close = (await controlsWith(page, ["render_close"])).render_close;
    if (close) await page.mouse.click(close.x, close.y);
    else await page.keyboard.press("Escape");
    await h.quiet(3000, 60000);
  }
  if (wanted("art")) {
    let chooser = null;
    for (let n = 0; n < 3 && !chooser; n++) {
      page.choosers.length = 0;
      const menu = await h.where("menu_make");
      await page.mouse.click(menu.x, menu.y);
      await page.waitForTimeout(1500);
      await page.keyboard.type("Mosaic", { delay: 120 });
      await page.waitForTimeout(800);
      await page.keyboard.press("Enter");
      for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
      chooser = page.choosers.shift() || null;
      if (!chooser) await page.keyboard.press("Escape");
    }
    if (chooser) {
      await chooser.setFiles(picture);
      await h.where("mosaic_build", 120);
      await page.waitForTimeout(8000);
      await measure(page, "art", press(page, "mosaic_build"),
        async (s) => Boolean(s.art && s.art.parts > 0 && s.art.pieces > 0),
        async (s) => said(/laying|panels/)(s), 600);
    } else {
      console.log("FAIL  art: no file chooser came up");
      failures += 1;
    }
    await h.quiet(3000, 120000);
  }
  if (wanted("brickify")) {
    const view = await h.where("view");
    let chooser = null;
    for (let n = 0; n < 3 && !chooser; n++) {
      page.choosers.length = 0;
      await page.mouse.move(view.x, view.y);
      await page.keyboard.press("Control+i");
      for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
      chooser = page.choosers.shift() || null;
    }
    if (chooser) {
      await chooser.setFiles(bunny);
      await h.where("brickify_go", 120);
      await page.waitForTimeout(6000);
      await measure(page, "brickify", press(page, "brickify_go"),
        async (s, c) => Boolean(s.tree && s.tree["bunny#1"]) && !c.brickify_go,
        async () => true, 600);
      // Its card ("bunny" is down) closed, as a person closes it: left up, it
      // lay over the timeline's Done, the timeline stayed at Orthanc's first
      // step, and Ctrl-A after it took that step's two parts (2026-10-19).
      const card = (await h.controls()).brickify_done;
      if (card) await page.mouse.click(card.x, card.y);
    } else {
      console.log("FAIL  brickify: no file chooser came up");
      failures += 1;
    }
    await h.quiet(3000, 120000);
  }

  // -- Orthanc, opened from a file -------------------------------------------
  const big = ["open", "timeline", "save", "export", "select_colour", "mirror", "turn",
    "stability", "delete", "undo", "new", "save_new"].some(wanted);
  if (big) {
    let chooser = null;
    const at = await h.where("open");
    for (let n = 0; n < 3 && !chooser; n++) {
      page.choosers.length = 0;
      await page.mouse.click(at.x, at.y);
      await page.waitForTimeout(3000 + 3000 * n);
      await page.mouse.click(at.x + 40, at.y + 22);
      for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
      chooser = page.choosers.shift() || null;
      if (!chooser) await page.keyboard.press("Escape");
    }
    if (!chooser) throw new Error("no file chooser came up for Open");
    // The press is the file handed over: what a person does last. Over the
    // bunny Brickify left unsaved, the open asks first whether to save it
    // (ModelBar.ask_to_replace, 6d3eb0bd): it is this run's, so Don't save,
    // and that is the press.
    await measure(page, "open", async () => {
      await page.evaluate(() => window.brickworksFrames.presses.push(performance.now()));
      await chooser.setFiles(orthanc);
      for (let n = 0; n < 40; n++) {
        const asked = (await h.controls()).replace_discard;
        if (asked) {
          console.log("        asked to save the model first: Don't save");
          await page.evaluate(() => {
            const presses = window.brickworksFrames.presses;
            presses[presses.length - 1] = performance.now();
          });
          await page.mouse.click(asked.x, asked.y);
          break;
        }
        if (said(/open|reading|orthanc/i)(await h.state())) break;
        await page.waitForTimeout(500);
      }
    }, async (s) => (s.bricks || 0) > opened && !s.playing,
    async (s) => said(/open|reading|orthanc/i)(s) || (s.bricks || 0) > begun, 600);
    await h.quiet(4000, 300000);
    if (wanted("timeline")) {
      await measure(page, "timeline", press(page, "tool_timeline"),
        async (s, c) => Boolean(c.steps_done) && Object.keys(s.working || {}).length === 0,
        async (_s, c) => Boolean(c.steps_done), 600);
      const doneAt = (await h.controls()).steps_done;
      if (doneAt) await page.mouse.click(doneAt.x, doneAt.y);
      await h.quiet(3000, 120000);
    }
    // The owner (2026-10-13): "when I clicked 'Save and then new' it seemingly
    // froze the app". Save worked out the build order on one frame; and
    // every slow command now says so on the bar before it holds the page
    // (Working.attend).
    if (wanted("save")) {
      await measure(page, "save", press(page, "save"),
        async (s) => idle(s) && said(/saved|in this browser|could not save|stopped saving/)(s),
        async (s) => said(/sav/i)(s), 600);
      await h.quiet(3000, 120000);
    }
    if (wanted("export")) {
      await fromMenu(page, "menu_file", ["Export", "LDraw"]);
      await measure(page, "export", () => page.keyboard.press("Enter"),
      async (s) => idle(s) && said(/downloaded|stopped|could not/)(s),
      async (s) => said(/export/i)(s), 600);
      await h.quiet(3000, 120000);
    }
    const view = await h.where("view");
    // With all of it selected, from the menus and keys a person would use.
    const everything = async () => {
      await page.mouse.move(view.x, view.y);
      await page.keyboard.press("Control+a");
      await page.waitForTimeout(3000);
      await h.quiet(2000, 60000);
    };
    const putBack = async () => {
      await page.mouse.move(view.x, view.y);
      await page.keyboard.press("Control+z");
      await h.quiet(3000, 120000);
    };
    if (wanted("select_colour")) {
      // One part selected, then every part of its colour, from the
      // toolbar's Select by.
      await page.mouse.click(view.x, view.y);
      await page.waitForTimeout(3000);
      await h.quiet(2000, 60000);
      // Its first item, Same colour, by Down: a menu searches on from the
      // item it is on, so "Same" typed ran on past it, to Everything
      // connected.
      await fromMenu(page, "tool_select", [["", 1]]);
      await measure(page, "select_colour", () => page.keyboard.press("Enter"),
      async (s) => idle(s), async () => false, 300, true);
      await page.keyboard.press("Escape");
      await h.quiet(3000, 60000);
    }
    if (wanted("mirror")) {
      await everything();
      await measure(page, "mirror", async () => {
        await page.mouse.move(view.x, view.y);
        await page.keyboard.press("Shift+M");
      }, async (s) => idle(s) && said(/mirror/)(s), async (s) => said(/mirror/)(s), 300, true);
      await putBack();
    }
    if (wanted("turn")) {
      await page.keyboard.press("Escape");
      await measure(page, "turn", async () => {
        await page.mouse.move(view.x, view.y);
        await page.keyboard.press("Shift+E");
      }, async (s) => idle(s), async () => false, 300, true);
      await page.keyboard.press("Shift+Q");
      await h.quiet(3000, 120000);
    }
    if (wanted("stability")) {
      await fromMenu(page, "menu_tools", ["Check"]);
      // The joints' line ("it stands up", "2 weak joints") gives way to the
      // balance's ("Stands, 3 studs inside…", "Tips over, …") once it is
      // weighed, so either is the end; the old pattern knew only the first
      // and read every check as never finishing (2026-10-16).
      await measure(page, "stability", () => page.keyboard.press("Enter"),
      async (s) => idle(s) && said(/stands up|weak joint|stands, |tips over, /i)(s),
      async (s) => said(/stands|weak|tips over/i)(s), 300);
      await page.keyboard.press("Escape");
      await h.quiet(3000, 120000);
    }
    if (wanted("delete") || wanted("undo")) {
      await page.mouse.move(view.x, view.y);
      await page.keyboard.press("Control+a");
      await page.waitForTimeout(3000);
      await measure(page, "delete", async () => {
        await page.mouse.move(view.x, view.y);
        await page.keyboard.press("Delete");
      }, async (s) => (s.bricks || 0) < 100, async (s) => (s.bricks || 0) < 9000, 300);
      await h.quiet(3000, 120000);
      await measure(page, "undo", async () => {
        await page.mouse.move(view.x, view.y);
        await page.keyboard.press("Control+z");
      }, async (s) => (s.bricks || 0) > 9000, async (s) => (s.bricks || 0) > 100, 300);
      await h.quiet(3000, 120000);
    }
    if (wanted("save_new")) {
      // New asks first when the model has changed since it was opened; this
      // presses its "Save, then start new".
      const button = await h.where("new");
      await page.mouse.click(button.x, button.y);
      await page.waitForTimeout(4000);
      // The question's button waited for, before the press that is timed.
      const answer = (await controlsWith(page, ["new_save"])).new_save;
      if (answer && ((await h.state()).bricks || 0) > 9000) {
        await measure(page, "save_new", async () => { await page.mouse.click(answer.x, answer.y); },
          async (s) => (s.bricks || 0) < 100 && idle(s), async (s) => said(/sav/i)(s), 600);
      } else {
        console.log(`  (save_new: ${answer ? "no question asked" : "no button to press in this build"}; not measured)`);
        await page.keyboard.press("Escape");
      }
      await h.quiet(3000, 120000);
    }
    if (wanted("new") && ((await h.state()).bricks || 0) > 9000) {
      // New asks first when the model has changed since it was opened, and
      // it has: the press that clears it is the one that says so.
      const button = await h.where("new");
      await page.mouse.click(button.x, button.y);
      await page.waitForTimeout(4000);
      if (((await h.state()).bricks || 0) > 9000) {
        await measure(page, "new", async () => { await page.keyboard.press("Enter"); },
          async (s) => (s.bricks || 0) < 100, async (s) => (s.bricks || 0) < 9000, 300);
      } else {
        console.log("  (new: no question asked; not measured)");
      }
    }
  }
} catch (error) {
  console.log(`FAIL  ${String(error).split("\n")[0]}`);
  failures += 1;
} finally {
  for (const e of errors.slice(0, 8)) console.log(`  error: ${e}`);
  writeFileSync(`${out}/progress.json`, JSON.stringify({ url, budget, saidBudget, rows }, null, 1));
  await browser.close().catch(() => {});
  if (server) server.kill();
}
const worst = rows.filter((r) => ALIVE.has(r.name)).reduce((a, r) => Math.max(a, r.own), 0);
console.log(failures
  ? `${failures} problem(s); the longest frame of the four kept alive was ${worst} ms (budget ${budget}); see ${out}`
  : `every slow thing said so and kept the page alive: the longest frame of the four was ${worst} ms (budget ${budget}); see ${out}`);
process.exit(failures ? 1 : 0);
