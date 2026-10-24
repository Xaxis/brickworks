// A set from the library opened in a tab, as Library > Open opens one
// (?library=<id>): over work not saved it asks first, and a big one is on
// the screen in seconds.
//
//   set -a; . ./.env; set +a
//   python3 tools/web/serve.py build/web 8921 --parts-url "$PARTS_URL" &
//   node tools/web/library_tab_flow.mjs --url=http://127.0.0.1:8921/index.html --out=shots/library_tab
//   BW_BYPASS=… node tools/web/library_tab_flow.mjs --url=<a preview>/app --out=…
//
// Both from walk180 (A8). The library's sets come from the parts store the
// deployment names, so a local export is served with --parts-url.
//
// 1. Over work not saved (--no-unsaved skips it). The tab's car, one part
//    taken off, and then ?library=omr-106-1 typed into the same tab: its
//    reload brought the car back, and the set was not opened, said only in
//    the status bar. Now it asks, as every other open asks (ModelBar
//    .ask_to_replace): Cancel keeps the car as it was, Don't save opens the
//    set, and Undo brings the car back. Pictures asked.png and set.png.
//
// 2. A big set in a tab of its own (--no-big skips it; --id, omr-10297-1:
//    the Boutique Hotel, 3,164 parts), timed from the page's start: when its
//    first picture is on the screen and when it is fully open. The walk
//    waited 60 to 90 s on the live site in a browser drawing in software,
//    with nothing of it on the screen until all of it was. The page is
//    pictured every --every ms (1000) and its viewport compared with the
//    last picture: the first picture is the first in which --like (0.9) of
//    the pixels the model changes from the empty baseplate the tab began
//    on are as they end. Fully open is when the parts are all down and none
//    is on its way, the status bar has nothing to do, and the picture has
//    stopped changing. Both are counted from the page's start and from the
//    open's own (the status bar's "Fetching … from the library"), so a slow
//    start of the engine is told apart from the open. Fails when the open
//    never ends (--timeout, 600 s), when the parts down are not --parts
//    (3164; 0 skips), when the first picture comes after --first-s or the
//    open after --open-s (0: not held). Prints the open's phases
//    (ModelStore.open_phases), what the status bar said and when, its
//    frames' longest own work and when the parts' geometry came. Writes
//    timeline.json, first.png and open.png, and the autosave's part lines
//    sorted (parts.txt), so two builds' opens are compared with cmp.
//
// Fails too when a script error reaches the console.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { inflateSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8921/index.html");
const id = String(args.id || "omr-10297-1");
const out = String(args.out || "shots/big_open");
const every = Number(args.every || 1000);
const like = Number(args.like || 0.9);
const timeout = Number(args.timeout || 600) * 1000;
const wanted = Number(args.parts ?? 3164);
const firstS = Number(args["first-s"] || 0);
const openS = Number(args["open-s"] || 0);
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;

// A PNG as Chromium writes a screenshot: 8 bits a channel, RGB or RGBA, not
// interlaced. {width, height, rgb: one byte a channel, three a pixel}.
function decode(png) {
  let at = 8, width = 0, height = 0, channels = 4;
  const data = [];
  while (at < png.length) {
    const size = png.readUInt32BE(at);
    const kind = png.toString("ascii", at + 4, at + 8);
    const body = png.subarray(at + 8, at + 8 + size);
    if (kind === "IHDR") {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      channels = { 2: 3, 6: 4 }[body[9]] || 4;
    } else if (kind === "IDAT") data.push(body);
    at += 12 + size;
  }
  const raw = inflateSync(Buffer.concat(data));
  const stride = width * channels;
  const rows = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? rows[y * stride + x - channels] : 0;
      const b = y > 0 ? rows[(y - 1) * stride + x] : 0;
      const c = x >= channels && y > 0 ? rows[(y - 1) * stride + x - channels] : 0;
      let v = line[x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      rows[y * stride + x] = v & 255;
    }
  }
  const rgb = Buffer.alloc(width * height * 3);
  for (let n = 0; n < width * height; n++) {
    rgb[n * 3] = rows[n * channels];
    rgb[n * 3 + 1] = rows[n * channels + 1];
    rgb[n * 3 + 2] = rows[n * channels + 2];
  }
  return { width, height, rgb };
}
// Whether pixel [n] of two pictures is the same, near enough for software
// drawing's dither.
const same = (a, b, n) => Math.abs(a.rgb[n * 3] - b.rgb[n * 3]) + Math.abs(a.rgb[n * 3 + 1] - b.rgb[n * 3 + 1])
  + Math.abs(a.rgb[n * 3 + 2] - b.rgb[n * 3 + 2]) < 24;

const browser = await launch();
const problems = [];
// A context of its own for each part, so neither opens the other's set.
async function freshPage(timed = false) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
  // Every engine frame timed, whole and inside WebGL, as library_flow.mjs
  // --live times them: window.__frames, [start, ms, ms in WebGL].
  if (timed) await context.addInitScript(FRAMES);
  const page = await context.newPage();
  page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  if (bypass) {
    await page.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
    await page.goto("about:blank");
  }
  return page;
}
const FRAMES = () => {
  const frames = [];
  window.__frames = frames;
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
      frames.push([t0, performance.now() - t0, gl]);
      if (frames.length > 40000) frames.splice(0, 20000);
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
};
const stateOf = (page) => page.evaluate(() => ({ ...(window.brickworksState || {}),
  controls: window.brickworksControls || {}, title: document.title }));
// The viewport: the model's part of the window, right of the parts column
// and above the status bar, as the walk's pictures have it.
const VIEW = { x: 340, y: 100, width: 920, height: 680 };
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await new Promise((done) => setTimeout(done, 500));
  }
  return false;
}
// The tab's working model, as it keeps it: its text, or null.
const autosaved = (page) => page.evaluate(() => new Promise((resolve) => {
  const req = indexedDB.open("/userfs");
  req.onerror = () => resolve(null);
  req.onsuccess = () => {
    const db = req.result;
    if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); resolve(null); return; }
    const walk = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").openCursor();
    walk.onsuccess = () => {
      const at = walk.result;
      if (!at) { resolve(null); return; }
      if (/autosave\.ldr$/.test(String(at.key)) && at.value && at.value.contents) {
        resolve(new TextDecoder().decode(at.value.contents));
        return;
      }
      at.continue();
    };
    walk.onerror = () => resolve(null);
  };
}));
const partLines = (text) => (text || "").split("\n").map((l) => l.trim()).filter((l) => l.startsWith("1 ")).sort();

// 1. ?library= typed into a tab with work not saved.
async function overUnsaved() {
  console.log("\n?library=omr-106-1 typed into a tab with work not saved");
  const page = await freshPage();
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  const up = await until(async () => (await stateOf(page)).controls.model_name && (await stateOf(page)).bricks > 0, 300);
  const car = await stateOf(page);
  if (!check(`the tab is up with its model: "${car.title}", ${car.bricks} parts`, up)) return;
  // A part of it taken off: clicked where the model is, then Delete.
  let picked = false;
  for (const [dx, dy] of [[0, 0], [0, 40], [-60, 20], [60, 20], [0, -40], [-30, 60]]) {
    await page.mouse.click(VIEW.x + VIEW.width / 2 + dx, VIEW.y + VIEW.height / 2 + dy);
    if (await until(async () => (await stateOf(page)).selected > 0, 4)) { picked = true; break; }
  }
  if (!check("a part of it picked", picked)) return;
  await page.keyboard.press("Delete");
  const less = car.bricks - 1;
  check(`...and taken off: ${(await stateOf(page)).bricks} parts`,
    await until(async () => (await stateOf(page)).bricks === less, 20));
  check("...kept as the tab's working model",
    await until(async () => partLines(await autosaved(page)).length === less, 30));
  const named = (await stateOf(page)).title;
  // The set's address typed into the same tab: it reloads.
  const typed = async () => {
    await page.goto(join(url, "library=omr-106-1"), { waitUntil: "domcontentloaded", timeout: 180000 });
    return until(async () => Boolean((await stateOf(page)).controls.replace_cancel), 180);
  };
  const asked = await typed();
  await page.screenshot({ path: `${out}/asked.png` });
  const back = await stateOf(page);
  check(`it asks first: "Save changes?" with Save, Don't save and Cancel; the car back meanwhile, `
    + `${back.bricks} parts (said: "${back.said || ""}")`, asked && back.bricks === less);
  if (!asked) return;
  let at = back.controls.replace_cancel;
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(3000);
  const kept = await stateOf(page);
  check(`Cancel keeps it as it was: "${kept.title}", ${kept.bricks} parts, "${kept.said}"`,
    kept.bricks === less && kept.title === named && /nothing opened/.test(kept.said || ""));
  check("...asked once, and gone", !kept.controls.replace_cancel);
  check("...typed again, it asks again", await typed());
  at = (await stateOf(page)).controls.replace_discard;
  await page.mouse.click(at.x, at.y);
  const opened = await until(async () => {
    const now = await stateOf(page);
    return now.bricks === 65 && !now.awaited && /^106-1 UNICEF Van/.test(now.title);
  }, 180);
  const set = await stateOf(page);
  await page.screenshot({ path: `${out}/set.png` });
  check(`Don't save opens the set: "${set.title}", ${set.bricks} parts`, opened);
  await page.mouse.move(VIEW.x + VIEW.width / 2, VIEW.y + 40);
  await page.keyboard.press("Control+z");
  const undone = await until(async () => (await stateOf(page)).bricks === less, 60);
  check(`...and Undo brings the car back: "${(await stateOf(page)).title}", ${(await stateOf(page)).bricks} parts`,
    undone);
  await page.context().close();
}

// 2. A big set in a tab of its own, timed.
async function bigOpen() {
  const page = await freshPage(true);
  const state = () => stateOf(page);
  // Each part's geometry and each library file fetched, when it was asked and
  // when it came, from the page's start: [kind, asked, came].
  const fetches = new Map();
  let began = Date.now();
  const kindOf = (u) => (/\.lbm(\?|$)/.test(u) ? "part" : /\/library\//.test(u) ? "library"
    : /\/ldraw\//.test(u) ? "ldraw" : "");
  page.on("request", (r) => { if (kindOf(r.url())) fetches.set(r, [kindOf(r.url()), Date.now() - began, 0]); });
  const came = (r) => { const f = fetches.get(r); if (f) f[2] = Date.now() - began; };
  page.on("requestfinished", came);
  page.on("requestfailed", came);
  console.log(`\n${id} in a tab of its own, as Library > Open opens it`);
  began = Date.now();
  await page.goto(join(url, `new=1&library=${id}`), { waitUntil: "domcontentloaded", timeout: 180000 });
  const shots = [];
  let up = 0;
  let quiet = 0;
  let last = null;
  while (Date.now() - began < timeout) {
    const t = Date.now() - began;
    const s = await state().catch(() => ({}));
    if (s.controls && s.controls.model_name && !up) up = t;
    if (up) {
      const png = await page.screenshot({ clip: VIEW, timeout: 60000 }).catch(() => null);
      if (png) {
        const shot = { t, png, bricks: s.bricks || 0, awaited: s.awaited || 0,
          working: (s.working || {}).words || "" };
        shots.push(shot);
        // Fully open, if it holds: every part down, none on its way, the
        // bar idle, and the picture as the last one was.
        const done = shot.bricks > 0 && shot.awaited === 0 && !shot.working;
        if (done && last && last.png.equals(png)) quiet += 1;
        else quiet = 0;
        last = shot;
        if (quiet >= 4) break;
      }
    }
    const spent = Date.now() - began - t;
    if (spent < every) await page.waitForTimeout(every - spent);
  }
  const end = await state();
  const work = await page.evaluate(() => window.brickworksWork || []);
  // When the open began: the status bar's first line of it, in the page's
  // clock, against when the page began in it.
  const fetching = work.find((w) => /^Fetching /.test(w.what || ""));
  const navAt = await page.evaluate(() => performance.timeOrigin);
  const openFrom = fetching ? Math.round(fetching.at - (fetching.ms || 0)) + Math.round(navAt - began) : 0;
  check(`the app came up ${(up / 1000).toFixed(1)} s in`, up > 0);
  const final = shots.length ? decode(shots[shots.length - 1].png) : null;
  // The empty baseplate the tab began on: the last picture while the set
  // was still being fetched. Not the last before any part was down, as the
  // page is told that only twice a second at most, and a picture can be
  // newer than what it was told.
  const before = shots.filter((shot) => /^Fetching /.test(shot.working) && shot.bricks === 0);
  const blank = shots.length ? decode((before.length ? before[before.length - 1] : shots[0]).png) : null;
  // The pixels the model changes: those the last picture has unlike that.
  const mask = [];
  if (final && blank) for (let n = 0; n < final.width * final.height; n++) if (!same(final, blank, n)) mask.push(n);
  let first = null;
  let whole = null;
  const timeline = [];
  for (const shot of shots) {
    const p = decode(shot.png);
    let alike = 0;
    for (const n of mask) if (same(p, final, n)) alike += 1;
    shot.like = mask.length ? alike / mask.length : 0;
    if (!first && shot.like >= like) first = shot;
    timeline.push({ t: shot.t, bricks: shot.bricks, awaited: shot.awaited, working: shot.working,
      like: Number(shot.like.toFixed(3)) });
  }
  // Fully open: the first picture of the run that ends it, all down.
  for (let n = shots.length - 1; n >= 0; n--) {
    const shot = shots[n];
    if (shot.bricks !== end.bricks || shot.awaited !== 0 || shot.working || !shot.png.equals(shots[shots.length - 1].png)) break;
    whole = shot;
  }
  const s = (ms) => `${(ms / 1000).toFixed(1)} s`;
  const fromOpen = (ms) => (openFrom ? ` (${s(ms - openFrom)} from the open's start)` : "");
  console.log(`  the model changes ${mask.length} of the viewport's ${VIEW.width * VIEW.height} pixels`);
  console.log(`  the open began ${openFrom ? s(openFrom) : "?"} in: "${fetching ? fetching.what : "no Fetching line"}"`);
  check(`first picture ${first ? s(first.t) : "never"}${first ? fromOpen(first.t) : ""}: ${first ? first.bricks : 0} parts down, `
    + `${first ? first.awaited : 0} to come, ${first ? Math.round(first.like * 100) : 0}% of the model as it ends`
    + (firstS ? ` (at most ${firstS} s)` : ""),
  Boolean(first) && (!firstS || first.t - openFrom <= firstS * 1000));
  check(`fully open ${whole ? s(whole.t) : "never"}${whole ? fromOpen(whole.t) : ""}: ${end.bricks} parts`
    + (openS ? ` (at most ${openS} s)` : ""),
  Boolean(whole) && (!openS || whole.t - openFrom <= openS * 1000));
  if (wanted) check(`...the parts down are the set's ${wanted}: ${end.bricks}`, end.bricks === wanted);
  console.log(`  ...the open's phases: ${JSON.stringify(end.open_phases || {})}`);
  const said = work.filter((w) => w.what).map((w) => `${s(Math.round(w.at - (w.ms || 0) + navAt - began))} ${w.what}`
    + (w.ended ? ` (${Math.round(w.ms)} ms)` : ""));
  console.log(`  ...the status bar: ${said.join(" | ")}`);
  const own = await page.evaluate(() => {
    const frames = window.__frames.map(([t0, d, g]) => ({ t0, d, own: d - g })).sort((x, y) => y.own - x.own);
    return { n: frames.length, top: frames.slice(0, 5).map((f) => Math.round(f.own)) };
  });
  console.log(`  ...its frames' own work, the longest five of ${own.n}: ${own.top.join(", ")} ms`);
  // Each second: its frames, and their whole and own ms, and the parts
  // asked for and arrived.
  const seconds = await page.evaluate((offset) => {
    const by = {};
    for (const [t0, d, g] of window.__frames) {
      const at = Math.floor((t0 + offset) / 1000);
      const one = by[at] || (by[at] = { frames: 0, whole: 0, own: 0 });
      one.frames += 1; one.whole += d; one.own += d - g;
    }
    return by;
  }, navAt - began);
  const asked = [...fetches.values()];
  for (const [kind, from, to] of asked) {
    const one = seconds[Math.floor(from / 1000)] || (seconds[Math.floor(from / 1000)] = { frames: 0, whole: 0, own: 0 });
    one[`${kind}_asked`] = (one[`${kind}_asked`] || 0) + 1;
    if (to) {
      const two = seconds[Math.floor(to / 1000)] || (seconds[Math.floor(to / 1000)] = { frames: 0, whole: 0, own: 0 });
      two[`${kind}_came`] = (two[`${kind}_came`] || 0) + 1;
    }
  }
  const parts = asked.filter(([kind]) => kind === "part");
  console.log(`  ...part geometry fetched: ${parts.length}, the first asked ${parts.length ? s(Math.min(...parts.map((f) => f[1]))) : "-"}, `
    + `the last came ${parts.length ? s(Math.max(...parts.map((f) => f[2]))) : "-"}`);
  if (first) writeFileSync(`${out}/first.png`, first.png);
  if (whole) writeFileSync(`${out}/open.png`, whole.png);
  writeFileSync(`${out}/timeline.json`, JSON.stringify({ up, openFrom, first: first && first.t,
    open: whole && whole.t, timeline, work, seconds, fetches: asked }, null, 1));
  // The model as the tab keeps it, its part lines sorted: two builds' opens
  // compared with cmp.
  const lines = partLines(await autosaved(page));
  writeFileSync(`${out}/parts.txt`, lines.join("\n") + "\n");
  console.log(`  ...the autosave keeps ${lines.length} part lines (parts.txt)`);
  await page.context().close();
}

try {
  if (!args["no-unsaved"]) await overUnsaved();
  if (!args["no-big"]) await bigOpen();
} catch (trouble) {
  check(`the flow ran: ${trouble.message}`, false);
} finally {
  for (const p of problems) check(`no script error: ${p}`, false);
  await browser.close();
}
console.log(failed ? `\n${failed} FAILED` : "\nall passed");
process.exit(failed ? 1 : 0);
