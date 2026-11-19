// What web/tally.js does at a time in the studio, timed in node on a studio
// larger than any real one: every timer and handler it sets, each run
// alone, at most 16 ms of a frame (tests/test_insights.py asks it). The
// collector runs for real here (this browser said yes); its beacons go to
// a fetch that only counts them.
//
//   node tests/fixtures/insights/frame_check.mjs
//
// Prints one JSON object: each kind of work's slowest run in ms, and how
// many beacons went.
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const web = new URL("../../../web/", import.meta.url);
const timers = [];
const handlers = [];
const frames = [];
const sent = [];
globalThis.window = globalThis;
globalThis.location = new URL("https://brickworks.diy/app");
globalThis.document = { querySelector: (q) => (q === "canvas" ? { getBoundingClientRect: () => ({ left: 0, top: 0 }) } : null),
  documentElement: { lang: "en" }, referrer: "", visibilityState: "visible" };
const kept = new Map([["brickworks.counting", "yes"]]);
globalThis.localStorage = { getItem: (key) => kept.get(key) ?? null, setItem: (key, value) => kept.set(key, String(value)) };
const session = new Map();
globalThis.sessionStorage = { getItem: (key) => session.get(key) ?? null, setItem: (key, value) => session.set(key, String(value)) };
globalThis.screen = { width: 2560, height: 1440 };
globalThis.addEventListener = (type, fn) => handlers.push([type, fn]);
globalThis.dispatchEvent = () => true;
globalThis.setInterval = (fn, ms) => timers.push(["every", ms, fn]);
globalThis.setTimeout = (fn, ms) => timers.push(["once", ms, fn]);
globalThis.requestAnimationFrame = (fn) => frames.push(fn);
// Node makes Request, Response and Blob on first use (undici, about 15 ms),
// which a browser has from the start: made here, before anything is timed.
void [globalThis.Request, globalThis.Response, globalThis.Blob];
globalThis.fetch = (url, init) => {
  sent.push(String(init?.body || ""));
  return Promise.resolve({ ok: true, status: 204 });
};

// A studio larger than any real one: 3,000 controls on the screen, every
// panel's state there, a part in hand that changes each second.
const controls = {};
for (let i = 0; i < 3000; i += 1) controls[`control_${i}_${"x".repeat(i % 40)}`] = { x: (i * 37) % 2560, y: (i * 53) % 1440, w: 40, h: 24 };
let held = 0;
globalThis.brickworksControls = controls;
globalThis.brickworksBoot = { ui: 12000, ready: 9000 };
const state = () => ({ mode: held % 2 ? "paint" : "place", put: { id: `part${held}` }, palette: { open: true, lit: "render" },
  panels: { colour: true, steps: held % 3 === 0 }, dialog: held % 5 === 0 ? "render" : "" });
globalThis.brickworksState = state();

const here = mkdtempSync(join(tmpdir(), "frames-"));
writeFileSync(join(here, "counting.mjs"), readFileSync(new URL("counting.js", web), "utf8"));
writeFileSync(join(here, "tally.mjs"), readFileSync(new URL("tally.js", web), "utf8")
  .replaceAll('"/counting.js"', JSON.stringify(pathToFileURL(join(here, "counting.mjs")).href))
  .replaceAll('"/counting-ask.js"', '"data:text/javascript,export const ask = () => {}"'));
await import(pathToFileURL(join(here, "tally.mjs")).href);

// What a turn costs the page's own thread: its CPU time, not the clock's.
// On a box at load 100 the clock also counts the time the thread waited for
// a core (18.8 ms, against 4.7 ms idle, in the 11-19 gate), which a person's
// device does not add. Node before 23.9 has no thread clock: there the
// clock, as before.
const slowest = {};
const cpu = typeof process.threadCpuUsage === "function"
  ? () => { const used = process.threadCpuUsage(); return (used.user + used.system) / 1000; }
  : () => performance.now();
const time = (kind, fn) => {
  const began = cpu();
  fn();
  const took = cpu() - began;
  slowest[kind] = Math.max(slowest[kind] || 0, Math.round(took * 1000) / 1000);
};
// Ten minutes of the studio: each second's look, a press on each second, a
// command each ten, a frame sample's frames, each beacon.
for (let second = 0; second < 600; second += 1) {
  held += 1;
  globalThis.brickworksState = state();
  for (const [how, ms, fn] of timers.filter(([, ms]) => ms === 1000)) time("each_second", fn);
  for (const [type, fn] of handlers.filter(([type]) => type === "pointerdown")) {
    time("a_press", () => fn({ isTrusted: true, clientX: (second * 41) % 2560, clientY: (second * 29) % 1440 }));
  }
  if (second % 10 === 0) {
    for (const [type, fn] of handlers.filter(([type]) => type === "keydown")) time("a_command", () => fn({ isTrusted: true, key: "Enter" }));
  }
  if (second % 15 === 0) for (const [how, ms, fn] of timers.filter(([, ms]) => ms === 15000)) time("a_beacon", fn);
}
// A frame sample: its frames, each one call.
for (const [how, ms, fn] of timers.filter(([, ms]) => ms === 60000)) time("a_sample_starts", fn);
for (let i = 0; i < 400 && frames.length; i += 1) {
  const next = frames.shift();
  time("a_frame", () => next(performance.now()));
}
// Leaving: the last beacon.
for (const [type, fn] of handlers.filter(([type]) => type === "pagehide")) time("leaving", () => fn({}));
await new Promise((resolve) => globalThis.queueMicrotask(resolve));
process.stdout.write(`${JSON.stringify({ slowest, beacons: sent.length, controls: Object.keys(controls).length,
  largest_beacon: Math.max(0, ...sent.map((body) => body.length)) })}\n`);
process.exit(0);
