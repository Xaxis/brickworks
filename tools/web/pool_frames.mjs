// How long each of the app's pool tasks holds a frame where the engine has
// no threads (the iPhone and iPad export, web-nothreads), done as a person
// does each: a model opened by File, Open, From a file, every part arrived,
// then each act by its menu, its key or its gesture, and the app let go
// quiet after each. Modelled on cad_frames.mjs, whose instrument and
// readings it shares.
//
//   python3 tools/web/serve.py EXPORT 10851 --parts assets/generated/parts --delay 0
//   set -a; . ./.env; set +a
//   node tools/web/pool_frames.mjs --engine=webkit --url=http://127.0.0.1:10851/ \
//     --out=DIR --acts=search,place,put,nudge,drag,stability,sections,stress MODEL
//
// Per act: the worst frame of the app's own work (the most of its "busy" and
// "slow" frames, window.brickworksState, Main._watch_own_frames), how many
// of its frames took over 50 and over 100 ms, what the status bar said it
// was doing in each slow one, and the act's wall time. The stability weigh
// that follows every change of the model runs in the frame on this export
// (Main._weigh, about a second after the change): the "nudge" act moves one
// part a stud to read its cost on this model, and each later act's frames of
// about that size, after it changed the model, are said as "the weigh"
// apart from the act's own. Writes DIR/pool_frames.json after every act.
import { controlsWith, launch, openColumnFor, openFromFile, typeInMenu } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith("--")).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const model = resolve(process.argv.slice(2).find((a) => !a.startsWith("--")) || "vendor/omr/files/75969-1.mpd");
const url = args.url || "http://127.0.0.1:10851/";
const out = args.out || "shots/pool_frames";
mkdirSync(out, { recursive: true });
const acts = String(args.acts || "search,place,put,nudge,drag,stability,sections,stress,hidden,simulate,"
  + "motions,timeline,replace,render,gif,instructions,brickify").split(",");
// How long one act may take before it is said as not done and the next
// begins: a frame of software drawing on a loaded box is seconds.
const actSeconds = Number(args["act-seconds"] || 420);
const bunny = resolve(args.mesh || "tests/fixtures/brickify/bunny.obj");

// cad_frames.mjs's instrument: every engine frame timed in the page, with
// its time inside WebGL.
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

const browser = await launch(args.engine === "webkit" ? { engine: "webkit" } : {});
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
await context.addInitScript(instrument);
const page = await context.newPage();
const choosers = [];
page.on("filechooser", (chooser) => choosers.push(chooser));
page.on("download", (d) => d.cancel().catch(() => {}));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
const started = Date.now();
const log = (line) => console.log(`[${Math.round((Date.now() - started) / 1000)}s] ${line}`);
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });

const state = () => page.evaluate(() => window.brickworksState || {});
const controls = () => page.evaluate(() => window.brickworksControls || {});
const now = () => page.evaluate(() => performance.now());
const busyNow = (s) => Object.keys(s.working || {}).length > 0;
async function where(name, seconds = 120) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    if (n % 10 === 2) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function press(name, seconds = 120) {
  const at = await where(name, seconds);
  await page.mouse.click(at.x, at.y);
  return at;
}
async function until(test, seconds = 60) {
  let s = await state();
  for (let n = 0; n < seconds * 4 && !test(s); n++) {
    await page.waitForTimeout(250);
    s = await state();
  }
  return s;
}
// cad_frames' quiet(): nothing working and [span] ms of frames under 100 ms.
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
// The engine's clock (Time.get_ticks_msec, which the slow and busy frames
// are stamped with) against the page's performance.now(): the state is
// written in a frame, so the least of (page now - state.now) over a few
// fresh writes is the engine's start on the page's clock, to a frame.
async function engineStart() {
  return page.evaluate(() => new Promise((done) => {
    let seen = window.brickworksState;
    let least = Infinity;
    const t0 = performance.now();
    const look = setInterval(() => {
      const s = window.brickworksState;
      if (s && s !== seen && typeof s.now === "number") least = Math.min(least, performance.now() - s.now);
      seen = s;
      if (performance.now() - t0 > 4000) { clearInterval(look); done(least); }
    }, 20);
  }));
}
let start = 0;
const r = (v) => Math.round(v * 10) / 10;
// The weigh's cost on this model, from the nudge (null until then).
let weighMs = null;

// One act: [doing] pressed, [done] waited for (by default nothing working),
// then quiet, and its frames read: the page's frames from the press on, and
// the app's own busy and slow frames, each placed after the press.
async function measure(name, doing, { done = null, settle = 1500, seconds = actSeconds, edits = false } = {}) {
  const from = await now();
  const t0 = Date.now();
  const row = { act: name };
  try {
    const said = await doing();
    if (said !== undefined) row.note = said;
    await page.waitForTimeout(settle);
    const s = await until((x) => (done ? done(x) : !busyNow(x)), seconds);
    row.done = done ? Boolean(done(s)) : !busyNow(s);
    row.quiet = await quiet(2000, Math.max(30000, seconds * 1000 - (Date.now() - t0)));
  } catch (trouble) {
    row.error = String(trouble.message || trouble).split("\n")[0].slice(0, 200);
  }
  row.wall_ms = Date.now() - t0;
  await page.waitForTimeout(600);
  const s = await state();
  const page_frames = await page.evaluate((a) => window.cadFrames.frames.filter(([t0]) => t0 >= a), from);
  const after = (tick) => Math.round(tick + start - from);
  const slow = (s.slow || []).map(([at, ms, gpu, doing]) => ({ at: after(at), ms, gpu, doing }))
    .filter((f) => f.at >= -50);
  const busy = (s.busy || []).map(([at, ms]) => ({ at: after(at), ms })).filter((f) => f.at >= -50);
  // The weigh: on an act that changed the model, a frame of the nudge's
  // weigh's size (within a third either way) a half second or more after
  // the press, when the status bar names nothing it is doing.
  const isWeigh = (f) => edits && weighMs !== null && f.at >= 500 && f.ms >= weighMs * 0.67
    && f.ms <= weighMs * 1.5 && !f.doing;
  const own = busy.filter((f) => !slow.some((g) => isWeigh(g) && Math.abs(g.at - f.at) < 30 && Math.abs(g.ms - f.ms) < 2));
  const ownSlow = slow.filter((f) => !isWeigh(f));
  const weighs = slow.filter(isWeigh);
  row.own_worst_ms = Math.max(0, ...own.map((f) => f.ms), ...ownSlow.map((f) => f.ms));
  row.own_over_50 = ownSlow.filter((f) => f.ms > 50).length;
  row.own_over_100 = ownSlow.filter((f) => f.ms > 100).length;
  row.own_over_8 = own.length;
  row.doing = [...new Set(ownSlow.filter((f) => f.doing).map((f) => f.doing))].slice(0, 8);
  row.weigh = weighs.map((f) => ({ at: f.at, ms: f.ms }));
  row.slow = slow.slice(0, 60);
  row.busy_kept = busy.length;
  // The page's frames: the whole frame (the app and its WebGL, which in
  // software is the drawing) and less its WebGL.
  row.page_frames = page_frames.length;
  row.page_over_100 = page_frames.filter(([, d]) => d > 100).length;
  row.page_worst_ms = r(Math.max(0, ...page_frames.map(([, d]) => d)));
  row.page_worst_less_gl_ms = r(Math.max(0, ...page_frames.map(([, d, g]) => d - g)));
  row.said = String(s.said || "").slice(0, 140);
  log(`  ${name}: own worst ${row.own_worst_ms} ms, ${row.own_over_50} over 50, ${row.own_over_100} over 100, `
    + `weigh ${JSON.stringify(row.weigh)}, wall ${row.wall_ms} ms, done ${row.done}, quiet ${row.quiet}`
    + `${row.error ? `, ERROR ${row.error}` : ""}${row.note ? `, ${row.note}` : ""}; doing ${JSON.stringify(row.doing)}; `
    + `said "${row.said}"`);
  return row;
}
// A menu's row by its title and the first letters of its words, as
// cad_frames' --motions opens Build, Motions….
async function menu(title, words) {
  const at = await where(`menu_${title}`);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(800);
  await typeInMenu(page, words);
  await page.waitForTimeout(400);
  await page.keyboard.press("Enter");
}
// File, Render…: its letters land on Render queue…, the row below it, so
// one row up; and Render queue… by its letters alone.
async function openRender(queue = false) {
  const at = await where("menu_file");
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(800);
  await typeInMenu(page, "Render");
  await page.waitForTimeout(400);
  if (!queue) await page.keyboard.press("ArrowUp");
  await page.keyboard.press("Enter");
  const shown = await controlsWith(page, [queue ? "queue_add" : "render_picture"], 120000);
  if (!shown[queue ? "queue_add" : "render_picture"]) {
    if (shown.queue_close) await press("queue_close", 10);
    throw new Error(`File, ${queue ? "Render queue…" : "Render…"} never opened`);
  }
}
async function shot(name) {
  await page.screenshot({ path: `${out}/${basename(model).replace(/\.[^.]+$/, "")}_${name}.png`, timeout: 120000 })
    .catch(() => {});
}
async function escape() {
  await page.keyboard.press("Escape");
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);
}
async function undo(name) {
  return measure(name, () => page.keyboard.press("Control+z"),
    { done: (x) => /^undid/i.test(String(x.said || "")) && !busyNow(x), edits: true });
}
// The bin's search field emptied and [words] typed in. Not by Ctrl+A:
// Playwright's WebKit says it is a Mac, where the app's field takes Ctrl+A
// as the line's start, so "3001" went in after the last search's words,
// nothing matched, and the run waited on a "first part" never shown (the
// nothreads unit's Orthanc run died there too).
async function searchFor(words) {
  const search = await where("part search");
  await page.mouse.click(search.x, search.y);
  await page.keyboard.press("End");
  for (let n = 0; n < 40; n++) await page.keyboard.press("Backspace");
  await page.keyboard.type(words, { delay: 30 });
}
// A part taken in hand from the bin by its number, only once the bin lists
// it first: a press on another tile can open a set in place of the model.
async function takeInHand(number) {
  await searchFor(number);
  const listed = await until((x) => (x.found || [])[0] === number, 120);
  if ((listed.found || [])[0] !== number) throw new Error(`the bin never listed ${number} first`);
  await press("first part", 240);
  const s = await until((x) => String(x.held || "") === number, 60);
  return String(s.held || "") === number;
}

await where("model_name", 400);
await page.waitForTimeout(5000);
await quiet(3000, 180000);
const result = { url, model: basename(model), engine: args.engine || "chromium", acts: [], errors };
const write = () => writeFileSync(`${out}/pool_frames.json`, JSON.stringify(result, null, 1));

// File, Open, From a file, until every part arrived (cad_frames --arrive=300).
log(`pool: ${basename(model)}`);
start = await engineStart();
const before = (await state()).bricks || 0;
const open = await measure("open", async () => {
  const chooser = await openFromFile(page, null, { choosers, shots: out });
  await chooser.setFiles(model);
}, { done: (x) => (x.bricks || 0) > 0 && (x.bricks || 0) !== before && !busyNow(x) && !x.playing
  && (x.awaited || 0) === 0, seconds: 900, settle: 3000 });
open.bricks = (await state()).bricks;
result.acts.push(open);
write();
await shot("open");
await page.keyboard.press("Escape");
const view = await where("view");
await page.mouse.move(view.x, view.y);
await quiet(2000, 120000);
start = await engineStart();
const all = (await state()).bricks;

for (const name of acts) {
  let rows = [];
  // Every act on the model opened: one that opened another in its place
  // ends the run, and the acts after it are not this model's.
  const count = (await state()).bricks || 0;
  if (Math.abs(count - all) > Math.max(30, all * 0.05)) {
    result.acts.push({ act: name, error: `the model changed: ${count} parts, ${all} opened; run ended` });
    log(`  ${name}: the model changed (${count} parts of ${all}); run ended`);
    write();
    break;
  }
  try {
    if (name === "search") {
      // The bin's search (PartsBin, on a worker where there are threads).
      rows.push(await measure("search", () => searchFor("brick 1 x 2"),
        { done: (x) => (x.found || []).length > 0 && !busyNow(x) }));
      await escape();
    } else if (name === "place") {
      // A 2 x 4 brick in hand swept across the model (GrabDrag in hand).
      const held = await takeInHand("3001");
      await page.mouse.move(view.x - 200, view.y);
      await page.waitForTimeout(1500);
      await quiet(2000, 120000);
      rows.push(await measure("place", () => page.mouse.move(view.x + 200, view.y + 30, { steps: 40 })
        .then(() => (held ? "3001 in hand" : "nothing in hand"))));
      rows[0].ghost = (await state()).ghost !== null;
    } else if (name === "put") {
      // ...and put down where the pointer is, then undone.
      if (String((await state()).held || "") !== "3001") await takeInHand("3001");
      await page.mouse.move(view.x, view.y - 40, { steps: 10 });
      await quiet(2000, 120000);
      const was = (await state()).bricks;
      rows.push(await measure("put", () => page.mouse.click(view.x, view.y - 40),
        { done: (x) => (x.bricks || 0) > was && !busyNow(x), edits: true, settle: 3000 }));
      await escape();
      await quiet(2000, 120000);
      if ((await state()).bricks > was) rows.push(await undo("undo put"));
      // The weigh read from the put and its undo when no nudge read it: their
      // biggest frame a half second or more on, which names nothing it does.
      if (weighMs === null) {
        const late = rows.flatMap((x) => (x.slow || []).filter((f) => f.at >= 500 && !f.doing));
        if (late.length) weighMs = Math.max(...late.map((f) => f.ms));
        rows[0].weigh_ms = weighMs;
      }
    } else if (name === "nudge") {
      // One part clicked and moved a stud by D: the weigh's cost on this
      // model, the act itself next to nothing.
      await escape();
      await page.mouse.click(view.x, view.y);
      let s = await until((x) => (x.selected || 0) > 0, 10);
      if (!s.selected) {
        await page.keyboard.press("Control+a");
        s = await until((x) => (x.selected || 0) > 0, 60);
      }
      await quiet(2000, 120000);
      const row = await measure("nudge", () => page.keyboard.press("d"), { settle: 4000 });
      row.selected = s.selected;
      // The weigh: the biggest frame a half second on.
      const later = row.slow.filter((f) => f.at >= 500);
      if (later.length) weighMs = Math.max(...later.map((f) => f.ms));
      row.weigh_ms = weighMs;
      row.note = `the weigh read as ${weighMs} ms (${s.selected} selected)`;
      rows.push(row);
      await quiet(2000, 120000);
      // Undone only when it moved something: an undo of nothing undoes the
      // open itself, and the model before it comes back.
      if (row.said && !/^undid/i.test(row.said)) rows.push(await undo("undo nudge"));
      await escape();
    } else if (name === "drag") {
      // A part dragged with Select (GrabDrag: the joints read, the let-go
      // checked), let go, then undone.
      await escape();
      await page.mouse.move(view.x, view.y);
      await quiet(2000, 60000);
      rows.push(await measure("drag", async () => {
        await page.mouse.down();
        await page.mouse.move(view.x + 120, view.y + 20, { steps: 30 });
        await page.mouse.up();
      }, { edits: true, settle: 3000 }));
      await quiet(2000, 120000);
      if (/moved|put|seat/i.test(rows[0].said)) rows.push(await undo("undo drag"));
      await escape();
    } else if (name === "replace") {
      // Everything selected, a 1 x 2 brick in hand, Edit, Replace with the
      // part in hand (Builder's replace plan past 600 parts), then undone.
      await escape();
      await page.keyboard.press("Control+a");
      await until((x) => (x.selected || 0) > 0, 60);
      const held = await takeInHand("3004");
      const sel = (await state()).selected;
      rows.push(await measure("replace", async () => {
        await menu("edit", "Replace");
        return `${sel} selected, ${held ? "3004 in hand" : "nothing in hand"}`;
      }, { edits: true, settle: 3000 }));
      await quiet(2000, 120000);
      if (/replac/i.test(rows[0].said)) rows.push(await undo("undo replace"));
      await escape();
    } else if (name === "stability") {
      await escape();
      rows.push(await measure("check stability", () => menu("tools", "Check")));
      await escape();
    } else if (name === "sections") {
      await escape();
      rows.push(await measure("suggest sections", () => menu("build", "Suggest")));
      await shot("sections");
      await escape();
    } else if (name === "stress") {
      await escape();
      rows.push(await measure("stress on", () => menu("view", "Stre")));
      await shot("stress");
      if ((await controls()).stress_strengthen) {
        rows.push(await measure("strengthen", () => press("stress_strengthen", 30)));
        await shot("strengthen");
        await escape();
      } else rows.push({ act: "strengthen", error: "no Strengthen in the stress panel" });
      if ((await controls()).stress_lift) {
        // Lift, and once the status bar asks for the part, the part under
        // the middle of the view clicked; done when it no longer asks.
        await press("stress_lift", 30);
        await until((x) => /click the part/i.test(String(x.said || "")), 60);
        await quiet(2000, 60000);
        rows.push(await measure("lift by a part", () => page.mouse.click(view.x, view.y),
          { settle: 4000, done: (x) => !/click the part/i.test(String(x.said || "")) && !busyNow(x) }));
        await shot("lift");
        await escape();
      } else rows.push({ act: "lift by a part", error: "no Lift in the stress panel" });
      rows.push(await measure("stress off", () => menu("view", "Stre")));
      await escape();
    } else if (name === "hidden") {
      await escape();
      rows.push(await measure("colour the hidden parts", () => menu("tools", "Colour")));
      await shot("hidden");
      if ((await controls()).hidden_close) await press("hidden_close", 10);
      await escape();
    } else if (name === "simulate") {
      await escape();
      rows.push(await measure("simulate", () => menu("tools", "Simulate")));
      await shot("simulate");
      if ((await controls()).simulate_play) {
        rows.push(await measure("simulate play", () => press("simulate_play", 10), { settle: 5000 }));
        if ((await controls()).simulate_play) await press("simulate_play", 10);
      }
      if ((await controls()).simulate_close) await press("simulate_close", 10);
      await escape();
    } else if (name === "motions") {
      await escape();
      rows.push(await measure("motions open", () => menu("build", "Motions"),
        { done: (x) => !busyNow(x) }));
      const m = await page.evaluate(() => window.brickworksMotions || {});
      const c = await controls();
      if (!(m.motions || []).length && c.motion_keep_0) await press("motion_keep_0", 10);
      await page.waitForTimeout(2000);
      if ((await controls()).motion_play_0) {
        rows.push(await measure("motion play", () => press("motion_play_0", 10), {
          settle: 3000, done: () => true }));
        await page.waitForFunction(() => !(window.brickworksMotions || {}).playing, null, { timeout: 120000 })
          .catch(() => {});
      } else rows.push({ act: "motion play", error: `no motion to play (${(m.motions || []).length} kept, `
        + `${(m.suggested || []).length} suggested)` });
      await shot("motions");
      if ((await controls()).motions_close) await press("motions_close", 10);
      await escape();
    } else if (name === "timeline") {
      await escape();
      rows.push(await measure("timeline", () => page.keyboard.press("b"),
        { done: (x) => x.timeline && x.timeline.at && !busyNow(x) }));
      await page.keyboard.press("b");
      await escape();
    } else if (name === "render") {
      await escape();
      // The render queue's Add this view first (RenderQueue's encode).
      try {
        await openRender(true);
        rows.push(await measure("render queue add", () => press("queue_add", 10),
          { settle: 4000, done: (x) => !busyNow(x) }));
        await shot("queue");
        if ((await controls()).queue_close) await press("queue_close", 10);
      } catch (trouble) {
        rows.push({ act: "render queue add", error: String(trouble.message || trouble).slice(0, 200) });
      }
      await escape();
      await openRender();
      if ((await controls()).render_quick) await press("render_quick", 10);
      await page.waitForTimeout(1500);
      rows.push(await measure("render a picture", () => press("render_picture", 10),
        { settle: 4000, done: (x) => !busyNow(x) }));
      await shot("render");
      if ((await controls()).render_close) await press("render_close", 10);
      await escape();
    } else if (name === "gif") {
      // A turntable kept as a GIF, at the fewest frames offered.
      await escape();
      await openRender();
      await where("render_turntable", 120);
      if ((await controls()).render_quick) await press("render_quick", 10);
      if ((await controls()).render_kept_gif) await press("render_kept_gif", 10);
      const fewest = Object.keys(await controls()).filter((k) => k.startsWith("render_frames_"))
        .sort((a, b) => parseInt(a.slice(14), 10) - parseInt(b.slice(14), 10))[0];
      if (fewest) await press(fewest, 10);
      await page.waitForTimeout(1500);
      rows.push(await measure("turntable GIF", async () => { await press("render_turntable", 10); return fewest || ""; },
        { settle: 4000, done: (x) => !busyNow(x) }));
      await shot("gif");
      if ((await controls()).render_close) await press("render_close", 10);
      await escape();
    } else if (name === "instructions") {
      await escape();
      rows.push(await measure("instructions", () => menu("build", "Instructions"),
        { settle: 5000, done: (x) => !busyNow(x) }));
      await shot("instructions");
      await escape();
      await escape();
    } else if (name === "brickify") {
      // Make, Brickify a 3D model (Ctrl+I), the bunny, Brickify.
      await escape();
      choosers.length = 0;
      await page.mouse.move(view.x, view.y);
      await page.keyboard.press("Control+i");
      for (let n = 0; n < 60 && !choosers.length; n++) await page.waitForTimeout(500);
      const chooser = choosers.shift();
      if (!chooser) throw new Error("Ctrl+I brought no file chooser");
      rows.push(await measure("brickify read", () => chooser.setFiles(bunny),
        { done: (x) => !busyNow(x) && x.brickify_studs, settle: 3000 }));
      await where("brickify_go", 120);
      await page.waitForTimeout(2000);
      rows.push(await measure("brickify", () => press("brickify_go", 10),
        { done: (x) => !busyNow(x) && x.brickified, settle: 5000, edits: true }));
      await shot("brickify");
      if ((await controls()).brickify_done) await press("brickify_done", 10);
      await escape();
      const s = await state();
      if (s.bricks > all) rows.push(await undo("undo brickify"));
    } else {
      rows.push({ act: name, error: "no such act" });
    }
  } catch (trouble) {
    rows.push({ act: name, error: String(trouble.message || trouble).split("\n")[0].slice(0, 200) });
    log(`  ${name}: ERROR ${rows[rows.length - 1].error}`);
    await shot(`error_${name}`);
    await escape();
  }
  result.acts.push(...rows);
  result.weigh_ms = weighMs;
  write();
  await page.mouse.move(view.x, view.y);
  await quiet(2000, 120000);
}
result.wall_s = Math.round((Date.now() - started) / 1000);
write();
log(`pool: ${result.acts.length} acts written to ${out}/pool_frames.json`);
await browser.close();
