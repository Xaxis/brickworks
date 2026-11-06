// Every key typed in the parts bin's search, in a browser: the ten searches
// src/dev/bin_keys_probe.gd types on the desktop, a letter at a time, each
// key's frames timed in the page, as the web build gives them to a person.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 9950 --parts assets/generated/parts --delay 0 &
//   node tools/web/bin_keys_flow.mjs --url=http://127.0.0.1:9950/ --out=DIR
//
// Every engine frame is timed whole, up to a WebGL fence: the frame
// callback, then gl.finish(), so a frame's drawing is in it and not drawn
// behind the page by SwiftShader and paid for by a later one. Each is said
// as its script (the app's own work, less its time in WebGL calls), its
// WebGL calls, and its drawing (the finish). For each key, its longest frame
// whole and the longest frame's script, over the frames from its press to the
// next key's (--gap ms apart, 300: the web's script runs two to three times
// the desktop's). What each search's first tiles say (brickworksState.found,
// tile_names) is kept, for a build before a change to be put beside one after
// it. Writes DIR/bin_keys.json. Judges nothing: SwiftShader on a shared box
// is not a phone or a graphics card, so the numbers are this box's.
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { loadavg } from "node:os";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:9950/");
const out = String(args.out || "shots/bin_keys");
const gap = Number(args.gap || 300);
const label = String(args.label || "");
mkdirSync(out, { recursive: true });
const QUERIES = ["brick 2x4", "slope", "technic beam", "plate 1x2", "tile 2x2",
  "round 1x1", "hinge", "wedge", "panel", "axle"];

// In the page before the engine starts: every engine frame timed, its time
// in WebGL calls apart, and then its drawing waited for (gl.finish).
function instrument() {
  const perf = { frames: [], gl: null };
  window.binFrames = perf;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  let gl = 0;
  let calls = {};
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    gl = 0;
    calls = {};
    const t0 = performance.now();
    let script = 0;
    let finish = 0;
    try { callback(time); } finally {
      script = performance.now() - t0;
      if (perf.gl) {
        const f0 = performance.now();
        perf.gl.finish();
        finish = performance.now() - f0;
      }
      inside = false;
      // A frame long in WebGL says which calls it was long in.
      const most = gl < 50 ? "" : Object.entries(calls).sort((a, b) => b[1][0] - a[1][0]).slice(0, 3)
        .map(([n, [ms, k]]) => `${n} ${Math.round(ms)} ms x${k}`).join(", ");
      perf.frames.push([t0, script + finish, gl, finish, most]);
      if (perf.frames.length > 40000) perf.frames.splice(0, 20000);
    }
  };
  const context = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(context)) {
    const d = Object.getOwnPropertyDescriptor(context, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    context[name] = function (...a) {
      if (!perf.gl) perf.gl = this;
      const t0 = performance.now();
      try { return was.apply(this, a); } finally {
        const dt = performance.now() - t0;
        gl += dt;
        const c = calls[name] || (calls[name] = [0, 0]);
        c[0] += dt;
        c[1] += 1;
      }
    };
  }
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
}

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
await context.addInitScript(instrument);
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });

const state = () => page.evaluate(() => window.brickworksState || {});
const controls = () => page.evaluate(() => window.brickworksControls || {});
const now = () => page.evaluate(() => performance.now());
async function where(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    if (n % 10 === 2) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
// Quiet: nothing working and [span] ms of frames under 100 ms.
async function quiet(span = 2000, longest = 120000) {
  const end = Date.now() + longest;
  while (Date.now() < end) {
    await page.waitForTimeout(500);
    const ok = await page.evaluate((s) => {
      const t = performance.now();
      const recent = window.binFrames.frames.filter(([t0]) => t0 >= t - s);
      const busy = Object.keys((window.brickworksState || {}).working || {}).length > 0;
      return !busy && t > s && recent.every(([, d]) => d < 100);
    }, span);
    if (ok) return true;
  }
  return false;
}
const r = (v) => Math.round(v * 10) / 10;

await where("model_name");
const search = await where("part search");
await page.waitForTimeout(3000);
await quiet(3000, 300000);
console.log(`the bin's search in a 1400x900 page, a key every ${gap} ms (load ${loadavg().map(r).join(" ")})`);
await page.mouse.click(search.x, search.y);
await page.waitForTimeout(500);
const rows = [];
let worst = 0;
let worstScript = 0;
for (const query of QUERIES) {
  await page.keyboard.press("Control+a");
  const presses = [];
  for (const c of query) {
    presses.push(await now());
    await page.keyboard.press(c === " " ? "Space" : c);
    await page.waitForTimeout(gap);
  }
  presses.push(await now());
  // The last key's list in, and drawn.
  await page.waitForTimeout(1500);
  await quiet(1500, 60000);
  const frames = await page.evaluate((from) => window.binFrames.frames.filter(([t0]) => t0 >= from),
    presses[0]);
  const keys = [];
  for (let n = 0; n < query.length; n++) {
    const mine = frames.filter(([t0]) => t0 >= presses[n] && t0 < presses[n + 1]);
    let longest = [0, 0, 0, 0, ""];
    for (const f of mine) if (f[1] > longest[1]) longest = f;
    keys.push({ typed: query.slice(0, n + 1), frames: mine.length, longest_ms: r(longest[1]),
      script_ms: r(longest[1] - longest[3] - longest[2]), webgl_ms: r(longest[2]), drawing_ms: r(longest[3]),
      webgl_in: longest[4] || "",
      most_script_ms: r(mine.reduce((m, f) => Math.max(m, f[1] - f[3] - f[2]), 0)) });
    worst = Math.max(worst, longest[1]);
    worstScript = Math.max(worstScript, keys[n].most_script_ms);
  }
  const s = await state();
  const row = { query, keys, found: (s.found || []).slice(0, 6), tile_names: (s.tile_names || []).slice(0, 16) };
  rows.push(row);
  console.log(`  "${query}": each key's longest frame, ms (whole: script+webgl+drawing): ${keys.map((k) =>
    `${k.typed.replace(/ /g, "_")} ${Math.round(k.longest_ms)} (${Math.round(k.script_ms)}+${Math.round(k.webgl_ms)}+${Math.round(k.drawing_ms)})`).join(", ")}`);
  console.log(`      first found: ${row.found.join(" ")}`);
  const long = keys.filter((k) => k.webgl_in);
  if (long.length) console.log(`      long in WebGL: ${long.map((k) => `${k.typed.replace(/ /g, "_")}: ${k.webgl_in}`).join("; ")}`);
}
const result = { label, url, gap, load: loadavg().map(r), worst_ms: r(worst), worst_script_ms: r(worstScript),
  rows, errors };
writeFileSync(`${out}/bin_keys.json`, JSON.stringify(result, null, 2));
console.log(`every key's longest frame: ${r(worst)} ms whole, its script at most ${r(worstScript)} ms (load ${loadavg().map(r).join(" ")})`);
if (errors.length) console.log(`page errors: ${errors.join(" | ")}`);
await browser.close();
