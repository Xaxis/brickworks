// Does a big design keep the page alive? Drives one in a real browser and
// times the page while it happens.
//
//   set -a; . ./.env; set +a
//   node tools/web/freeze_check.mjs --dir=build/web            a local export, served here
//   BW_BYPASS=… node tools/web/freeze_check.mjs --url=<preview>/app
//
// The owner asked the assistant for a Falcon Heavy on the web app and it
// "damn near froze my computer". The design is in
// src/dev/fixtures/falcon_heavy.json: the 4,252 parts it came to, read off
// their tab. This plays Claude's part over the connector, as claude.ai does
// (connector_flow.mjs has how), and makes the calls a design makes with it —
// check it, submit it, read it back, look at it, edit it, review it — and
// for each one measures, in the page:
//
//   - long tasks (PerformanceObserver "longtask"): the main thread busy over
//     50 ms, with nothing else able to run, input included;
//   - the longest gap between frames, which is how long the canvas froze;
//   - how long a mouse move over the canvas took to be handled, every 250 ms
//     while the call runs: that is the page being unresponsive, as a person
//     feels it;
//   - the bricks, batches and triangles BrickWorld reports, and the memory:
//     the engine's WebAssembly heap and the JavaScript heap.
//
// --calls=FILE replays a design's calls instead ([{name, input}], as
// pulled from a Claude Code session log).
//
// Passes when no frame of the app's own work is over --budget ms (default
// 200) and every call is answered. A build from before the app timed its
// own frames is judged by its longest task instead (--task-budget, 10 s). The app's own work is timed by the app,
// from a frame's start to its drawing (Main._watch_own_frames), because a
// browser here draws in software, on SwiftShader: an idle page's every frame
// is a long task of half a second or more, so long tasks and input delay are
// printed, against the idle page's, and judged by eye. Costs nothing: no
// model is called.
import { launch } from "./browser.mjs";
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/freeze";
mkdirSync(out, { recursive: true });
const budget = Number(args.budget || 200);
// For a build from before the app timed its own frames, which has nothing
// else to be judged by: the longest task, drawing and all.
const taskBudget = Number(args["task-budget"] || 10000);
const bypass = process.env.BW_BYPASS || "";

// A port nobody is using, for a local export.
async function freePort() {
  return new Promise((done) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => { const { port } = s.address(); s.close(() => done(port)); });
  });
}

let server = null;
let url = args.url;
if (!url) {
  const dir = args.dir || "build/web";
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${dir}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}
const stop = (code) => { if (server) server.kill(); process.exit(code); };

function falconCalls() {
  const design = JSON.parse(readFileSync(new URL("../../src/dev/fixtures/falcon_heavy.json", import.meta.url)));
  const bricks = design.bricks.map(([part, color, x, y, z, face, rot]) =>
    (face === "up" ? { part, color, x, y, z, rot } : { part, color, x, y, z, face, rot }));
  const input = { name: design.name, description: "a large design", bricks };
  return [
    { name: "clear_model", input: {} },
    { name: "check_design", input },
    { name: "submit_design", input },
    { name: "look_at_model", input: {} },
    { name: "view_model", input: { from: "corner" } },
    // Recolour the first brick look_at_model listed: a one-brick change.
    { name: "edit_model", input: { recolor: [{ bricks: ["first listed"], color: 4 }] } },
    { name: "review_model", input: {} },
    // And submitted onto a bare baseplate with nothing checked first, so all
    // 4,242 parts go up in the build animation.
    { name: "clear_model", input: {} },
    { name: "submit_design", input },
  ];
}
const calls = args.calls ? JSON.parse(readFileSync(args.calls)) : falconCalls();

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(url).origin });
// What the page does, recorded in the page, from before the engine starts.
await context.addInitScript(() => {
  const perf = { longtasks: [], gaps: [], frames: 0, mems: [] };
  window.brickworksPerf = perf;
  new PerformanceObserver((list) => {
    for (const e of list.getEntries()) perf.longtasks.push([e.startTime, e.duration]);
  }).observe({ type: "longtask", buffered: true });
  let last = 0;
  const tick = (t) => {
    if (last && t - last > 50) perf.gaps.push([last, t - last]);
    last = t;
    perf.frames += 1;
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
  // The engine's heap is a WebAssembly.Memory; keep hold of it to read its size.
  const Real = WebAssembly.Memory;
  const Kept = function (descriptor) { const m = new Real(descriptor); perf.mems.push(m); return m; };
  Kept.prototype = Real.prototype;
  WebAssembly.Memory = Kept;
});
const page = await context.newPage();
// What the app printed, with when: its own account of where the time went.
// Written as it comes, so a run that is cut off still leaves it.
const started = Date.now();
writeFileSync(`${out}/console.log`, "");
page.on("console", (m) => appendFileSync(`${out}/console.log`,
  `${((Date.now() - started) / 1000).toFixed(1)}s ${m.text()}\n`));
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });

async function control(name, minutes = 5) {
  for (let tries = 0; tries < minutes * 120; tries++) {
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/never_showed_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed "${name}"; see ${out}/never_showed_${name}.png`);
}
const click = async (name) => { const at = await control(name); await page.mouse.click(at.x, at.y); };

await click("connect_claude");
await page.waitForTimeout(3000);
await click("connector_copy");
await page.waitForTimeout(1500);
const address = await page.evaluate(() => navigator.clipboard.readText());
if (!address.includes("/api/mcp")) {
  console.log(`FAIL  no connector address on the clipboard: ${address.slice(0, 80)}`);
  await browser.close();
  stop(1);
}
const view = await control("view");

let sent = 0;
async function claude(method, params) {
  sent += 1;
  const headers = { "content-type": "application/json", accept: "application/json, text/event-stream" };
  if (bypass) headers["x-vercel-protection-bypass"] = bypass;
  const answer = await fetch(address, {
    method: "POST", headers,
    body: JSON.stringify({ jsonrpc: "2.0", id: sent, method, params }),
  });
  return answer.json();
}
await claude("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "freeze_check", version: "1" } });
await claude("tools/list", {});

const now = () => page.evaluate(() => performance.now());
// How the page is doing, read in one go.
const state = () => page.evaluate(() => {
  const s = window.brickworksState || {};
  const p = window.brickworksPerf;
  const wasm = p.mems.reduce((a, m) => a + m.buffer.byteLength, 0);
  const js = performance.memory ? performance.memory.usedJSHeapSize : 0;
  return { bricks: s.bricks, batches: s.batches, triangles: s.triangles, wasm, js,
    frames: p.frames, now: s.now || 0, slow: s.slow || [], playing: !!s.playing };
});
// The app's own slow frames since engine tick [from]: its work, not drawing,
// and apart from it the longest wait for a picture to be read back.
const own = (slow, from) => {
  const since = slow.filter(([t]) => t >= from);
  const worst = since.reduce((a, b) => (b[1] > (a ? a[1] : -1) ? b : a), null);
  return { ownLongest: worst ? worst[1] : 0, ownSlow: since.length,
    pictureWait: Math.max(0, ...since.map(([, , gpu]) => gpu || 0)),
    ownDoing: worst ? String(worst[3] || "") : "" };
};
const window_ = (from, to) => page.evaluate(([a, b]) => {
  const p = window.brickworksPerf;
  const tasks = p.longtasks.filter(([t]) => t >= a && t <= b);
  const gaps = p.gaps.filter(([t]) => t >= a && t <= b);
  const sorted = tasks.map(([, d]) => d).sort((x, y) => x - y);
  return {
    longest: Math.max(0, ...sorted),
    busy: sorted.reduce((s, d) => s + d, 0),
    count: tasks.length,
    median: sorted.length ? sorted[sorted.length >> 1] : 0,
    frozen: Math.max(0, ...gaps.map(([, d]) => d)),
    span: b - a,
  };
}, [from, to]);

// A person's pointer over the model, moved every 250 ms while a call runs:
// how long each move takes to be handled is how long the page ignored them.
let poking = false;
let worstInput = 0;
async function poke() {
  let n = 0;
  while (poking) {
    n += 1;
    const t0 = Date.now();
    await page.mouse.move(view.x + (n % 2 ? 40 : -40), view.y + 30).catch(() => {});
    worstInput = Math.max(worstInput, Date.now() - t0);
    await new Promise((done) => setTimeout(done, 250));
  }
}

// Quiet: no build animation playing and three seconds without a slow frame
// of the app's own. Up to two minutes. Not "no long task": drawn in
// software, an idle page's every frame is one.
async function settle() {
  const start = Date.now();
  while (Date.now() - start < 120000) {
    await page.waitForTimeout(1000);
    const s = await state();
    const recent = s.slow.filter(([t]) => t >= s.now - 3000);
    if (!s.playing && recent.length === 0 && Date.now() - start > 3000) return;
  }
}

const rows = [];
let firstListed = 0;
let failures = 0;
await settle();
const before = await state();
console.log(`page up: ${before.bricks} bricks, wasm ${(before.wasm / 1048576).toFixed(0)} MB, js ${(before.js / 1048576).toFixed(0)} MB`);
// What the page costs doing nothing, to read the rest against.
const idleFrom = await now();
const idleFrames = before.frames;
await page.waitForTimeout(10000);
const idle = await window_(idleFrom, await now());
const idleRate = ((await state()).frames - idleFrames) / (idle.span / 1000);
console.log(`idle: ${idleRate.toFixed(1)} frames a second, ${idle.count} long tasks in ${(idle.span / 1000).toFixed(0)} s, the longest ${idle.longest.toFixed(0)} ms, median ${idle.median.toFixed(0)} ms`);
console.log("     call              took  own frame  picture   longest task  busy (of)        frozen  input  | bricks batches triangles  wasm MB js MB");
for (const call of calls) {
  if (call.name === "save_model") continue;
  const engineFrom = (await state()).now;
  const from = await now();
  const t0 = Date.now();
  worstInput = 0;
  poking = true;
  const poking_ = poke();
  const input = JSON.parse(JSON.stringify(call.input).replace('"first listed"', String(firstListed)));
  const answer = await claude("tools/call", { name: call.name, arguments: input });
  const took = Date.now() - t0;
  await settle();
  poking = false;
  await poking_;
  const to = await now();
  const w = await window_(from, to);
  const s = await state();
  const text = (answer.result?.content || []).map((c) => c.text || "").join(" ").replace(/\s+/g, " ");
  const listed = /#(\d+)\s/.exec(text);
  if (call.name === "look_at_model" && listed) firstListed = Number(listed[1]);
  const mine = own(s.slow, engineFrom);
  delete s.slow;
  const row = { call: call.name, took, ...mine, ...w, input: worstInput, ...s, said: text.slice(0, 70) };
  rows.push(row);
  const unanswered = /did not answer|is not open|not connected/i.test(text);
  const timed = s.now > 0;
  const over = (timed ? mine.ownLongest > budget : w.longest > taskBudget) || unanswered;
  if (over) failures += 1;
  if (mine.ownDoing) console.log(`       (its longest own frame was during: ${mine.ownDoing.slice(0, 80)})`);
  console.log(`${over ? "FAIL" : "ok  "} ${call.name.padEnd(14)} ${String(took).padStart(6)} ms ${String(mine.ownLongest).padStart(6)} ms ${String(mine.pictureWait).padStart(6)} ms ${w.longest.toFixed(0).padStart(7)} ms ${w.busy.toFixed(0).padStart(7)} (${(w.span / 1000).toFixed(0).padStart(3)} s) ${w.frozen.toFixed(0).padStart(7)} ${String(worstInput).padStart(6)}  | ${String(s.bricks).padStart(6)} ${String(s.batches ?? "?").padStart(7)} ${String(s.triangles ?? "?").padStart(9)} ${(s.wasm / 1048576).toFixed(0).padStart(7)} ${(s.js / 1048576).toFixed(0).padStart(5)}  ${text.slice(0, 50)}`);
}
await page.screenshot({ path: `${out}/after.png`, timeout: 120000 }).catch(() => {});
writeFileSync(`${out}/freeze.json`, JSON.stringify({ url, budget, idle, idleRate, rows }, null, 1));
await browser.close();
const longest = Math.max(...rows.map((r) => r.ownLongest));
const task = Math.max(...rows.map((r) => r.longest));
const slowest = Math.max(...rows.map((r) => r.input));
const timed = rows.some((r) => r.now > 0);
const judged = timed
  ? `the app's longest frame was ${longest} ms (budget ${budget})`
  : `this build does not time its own frames, so by the longest task: ${task.toFixed(0)} ms (budget ${taskBudget})`;
console.log(failures
  ? `${failures} call(s) over budget or unanswered: ${judged}; the longest task ${task.toFixed(0)} ms and the slowest input ${slowest} ms, against ${idle.longest.toFixed(0)} ms idle`
  : `the page stayed alive: ${judged}; the longest task ${task.toFixed(0)} ms and the slowest input ${slowest} ms, against ${idle.longest.toFixed(0)} ms idle`);
stop(failures ? 1 : 0);
