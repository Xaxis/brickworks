// When Claude says a design is done, how long until the model is on the
// screen? Plays Claude's part over the connector in a real browser and times
// it, from submit_design's answer to the last brick drawn and the page idle.
//
//   set -a; . ./.env; set +a
//   node tools/web/arrival_check.mjs --dir=build/web          a local export, served here
//   BW_BYPASS=… node tools/web/arrival_check.mjs --url=<preview>/app
//
// The owner, 2026-10-11: "things are building but the rendering after Claude
// reports being done is EXTREMELY SLOW". Claude designs from claude.ai with
// the Brickworks tab out of view, says it is done, and only then does the
// model come up in the tab, slowly. So each case is run twice:
//
//   shown   the tab in view throughout;
//   hidden  out of view from before the check until --wait ms (5 s: Claude
//           writing its reply) after submit_design answers, then shown.
//
// and timed from the moment the tab is in view with the design built:
//
//   drawn   the first frame from which every frame asks WebGL to draw what
//           the last one does, to within 1%: every brick is on the screen;
//   idle    the end of the last frame with over 100 ms of the engine's own
//           work.
//
// Each frame is timed in the page, from the engine's frame callback, less
// the time spent inside WebGL calls: drawn in software (SwiftShader) a frame
// waits a second or more on the rasteriser there, which a graphics card does
// in milliseconds, and that is not the app's work. So this reads the same on
// a build from before the app timed itself. A tab out of view is made the
// way connector_flow.mjs makes it: document.hidden, and the browser's frames
// stopped, because a browser driven from here never hides a page itself, not
// even behind another tab. The designs are the owner's Falcon Heavy
// (src/dev/fixtures/falcon_heavy.json) and its lowest 300 and 2,000 parts.
// Every case is a fresh page, so no part is cached from the case before.
// --flow=submit submits with no check first, so every brick is new to it.
//
// Passes when every case is drawn within three frames of being in view, on
// no more than --budget ms (2,000) of the engine's own work. Costs nothing:
// no model is called.
import { launch } from "./browser.mjs";
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/arrival";
mkdirSync(out, { recursive: true });
const budget = Number(args.budget || 2000);
const wait = Number(args.wait || 5000);
const quiet = Number(args.quiet || 3000);
const longest = Number(args.longest || 600000);
const sizes = String(args.sizes || "300,2000,4242").split(",").map(Number);
const modes = String(args.modes || "shown,hidden").split(",");
// "check": check_design and then submit_design of the same design, as a
// design ends; the check puts the model down and the submit keeps it.
// "submit": submit_design alone onto the bare baseplate, so every brick of it
// is new when it is built.
const flow = String(args.flow || "check");
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
  const dir = args.dir || "build/web";
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${dir}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}
const stop = (code) => { if (server) server.kill(); process.exit(code); };

// The Falcon's lowest [size] parts, the way they stand: a smaller design
// that is still the owner's, and still stands.
const falcon = JSON.parse(readFileSync(new URL("../../src/dev/fixtures/falcon_heavy.json", import.meta.url)));
function design(size) {
  const rows = falcon.bricks.map((row, n) => [row, n])
    .sort((a, b) => a[0][3] - b[0][3] || a[1] - b[1]).slice(0, size).map(([row]) => row);
  const bricks = rows.map(([part, color, x, y, z, face, rot]) =>
    (face === "up" ? { part, color, x, y, z, rot } : { part, color, x, y, z, face, rot }));
  return { name: `${falcon.name} (${bricks.length})`, description: "a large design", bricks };
}

// In the page before anything else runs: every engine frame timed, with the
// instances it asked WebGL to draw; long tasks; and a gate on the browser's
// frames for a tab out of view.
function instrument() {
  const perf = { frames: [], longtasks: [], cur: null, changes: [], lastEach: "" };
  window.brickworksPerf = perf;
  new PerformanceObserver((list) => {
    for (const e of list.getEntries()) perf.longtasks.push([e.startTime, e.duration]);
  }).observe({ type: "longtask", buffered: true });
  const real = window.requestAnimationFrame.bind(window);
  const gate = { stopped: false, held: [] };
  window.brickworksTestFrames = gate;
  const browserFrame = (callback) => {
    if (gate.stopped) { gate.held.push(callback); return 0; }
    return real(callback);
  };
  // Whatever the page puts in place of requestAnimationFrame (the connector
  // does, to keep the app running out of view) is kept and called; what the
  // engine hands it is timed, once however many hands it passes through.
  const timed = (callback) => (time) => {
    if (perf.cur) { callback(time); return; }
    const frame = { t0: performance.now(), instances: 0, draws: 0, gl: 0, worst: 0, worstCall: "", each: [] };
    perf.cur = frame;
    try { callback(time); } finally {
      perf.cur = null;
      const ms = performance.now() - frame.t0;
      // [start, length, the engine's own part of it, instances, draws, the
      // slowest WebGL call and how long it took]
      perf.frames.push([frame.t0, ms, ms - frame.gl, frame.instances, frame.draws,
        frame.worstCall, frame.worst]);
      // And, when what is drawn changed, each instanced draw's count: which
      // draws a change was in.
      const each = frame.each.join(",");
      if (each !== perf.lastEach) { perf.changes.push([frame.t0, each]); perf.lastEach = each; }
    }
  };
  let inner = browserFrame;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
  // Time spent inside WebGL, taken off the frame to leave the engine's own
  // work. Drawn in software (SwiftShader), the page waits on the rasteriser
  // inside these calls for a second or more a frame however little the app
  // did; on a graphics card that is a few milliseconds.
  const gl = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(gl)) {
    const d = Object.getOwnPropertyDescriptor(gl, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    const instanced = name === "drawElementsInstanced" || name === "drawArraysInstanced";
    const draw = instanced || name === "drawElements" || name === "drawArrays";
    gl[name] = function (...a) {
      const f = perf.cur;
      if (!f) return was.apply(this, a);
      if (draw) {
        f.draws += 1;
        if (instanced) { f.instances += a[a.length - 1]; f.each.push(a[a.length - 1]); }
      }
      const t0 = performance.now();
      try { return was.apply(this, a); } finally {
        const took = performance.now() - t0;
        f.gl += took;
        if (took > f.worst) { f.worst = took; f.worstCall = name; }
      }
    };
  }
}

async function runCase(size, mode) {
  const tag = `${size}_${mode}${flow === "submit" ? "_submit" : ""}`;
  const browser = await launch();
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
  await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(url).origin });
  await context.addInitScript(instrument);
  const page = await context.newPage();
  const started = Date.now();
  writeFileSync(`${out}/${tag}.console.log`, "");
  page.on("console", (m) => appendFileSync(`${out}/${tag}.console.log`,
    `${((Date.now() - started) / 1000).toFixed(1)}s ${m.text()}\n`));
  const first = bypass
    ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
    : url;
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });

  const controls = () => page.evaluate(() => window.brickworksControls || {});
  async function control(names, minutes = 5) {
    for (let tries = 0; tries < minutes * 120; tries++) {
      const shown = await controls();
      for (const name of names) if (shown[name]) return [name, shown[name]];
      await page.waitForTimeout(500);
    }
    await page.screenshot({ path: `${out}/${tag}_never_showed.png` }).catch(() => {});
    throw new Error(`the app never showed ${names.join(" or ")}`);
  }
  // Connected the way this build offers: one button, or the private address.
  const [way, at] = await control(["connect_claude", "connector_private"]);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(3000);
  if (way === "connector_private") {
    const [, here] = await control(["claude_here"]);
    await page.mouse.click(here.x, here.y);
    await page.waitForTimeout(3000);
  }
  const [, copy] = await control(["connector_copy", "connector_private_copy"]);
  await page.mouse.click(copy.x, copy.y);
  await page.waitForTimeout(1500);
  const address = await page.evaluate(() => navigator.clipboard.readText());
  if (!address.includes("/api/mcp")) throw new Error(`no connector address: ${address.slice(0, 80)}`);
  const view = (await control(["view"]))[1];

  let sent = 0;
  async function claude(method, params) {
    sent += 1;
    const headers = { "content-type": "application/json", accept: "application/json, text/event-stream" };
    if (bypass) headers["x-vercel-protection-bypass"] = bypass;
    const answer = await fetch(address, {
      method: "POST", headers, body: JSON.stringify({ jsonrpc: "2.0", id: sent, method, params }),
    });
    return answer.json();
  }
  const said = (answer) => (answer.result?.content || []).map((c) => c.text || "").join(" ").replace(/\s+/g, " ");
  await claude("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "arrival_check", version: "1" } });
  await claude("tools/list", {});

  const now = () => page.evaluate(() => performance.now());
  const frames = (from) => page.evaluate((from) => window.brickworksPerf.frames.filter(([t]) => t >= from), from);
  const seeing = (hidden) => page.evaluate((hidden) => {
    Object.defineProperty(document, "hidden", { value: hidden, configurable: true });
    Object.defineProperty(document, "visibilityState", { value: hidden ? "hidden" : "visible", configurable: true });
    const gate = window.brickworksTestFrames;
    gate.stopped = hidden;
    document.dispatchEvent(new Event("visibilitychange"));
    if (!hidden) gate.held.splice(0).forEach((f) => window.requestAnimationFrame(f));
  }, hidden);
  // Settled: for [quiet] ms and three frames at least, the instances drawn a
  // frame unchanged and no frame with over 100 ms of the engine's own work,
  // and no animation the app says is playing; by [until] at the latest.
  // Three frames because drawn in software on a loaded machine a frame can
  // take three seconds, and three seconds of frames was then never three of
  // them. A case waited past the moment, 90 s after the last call, when the
  // assistant panel closes Claude's card; what was drawn changed a little
  // then, and read as the model arriving.
  async function settle(from, until) {
    while (Date.now() < until) {
      await page.waitForTimeout(1000);
      const f = await frames(from);
      if (f.length < 3) continue;
      const end = f[f.length - 1][0];
      let recent = f.filter(([t]) => t >= end - quiet);
      if (recent.length < 3) recent = f.slice(-3);
      if (end - from < quiet || recent.length < 3) continue;
      const same = recent.every(([, , , n]) => n === recent[0][3]);
      const calm = recent.every(([, , own]) => own <= 100);
      const playing = await page.evaluate(() => !!(window.brickworksState || {}).playing);
      if (same && calm && !playing) return true;
    }
    return false;
  }

  await settle(await now(), Date.now() + 120000);
  // Asked until the tab itself answers: a fresh page's connector can take a
  // while to be the one the relay hands work to, and until then every call
  // comes back from the relay as "not open" in no time at all.
  for (let tries = 0; ; tries++) {
    const cleared = said(await claude("tools/call", { name: "clear_model", arguments: {} }));
    if (!/is not open|switched off/.test(cleared)) break;
    if (tries >= 24) throw new Error(`the tab never answered: ${cleared.slice(0, 60)}`);
    await page.waitForTimeout(5000);
  }
  await settle(await now(), Date.now() + 120000);

  const input = design(size);
  const checkedAt = await now();
  if (mode === "hidden") { await seeing(true); await page.waitForTimeout(1000); }
  let t = Date.now();
  const checked = flow === "check"
    ? await claude("tools/call", { name: "check_design", arguments: input }) : {};
  const checkMs = Date.now() - t;
  t = Date.now();
  const submitted = await claude("tools/call", { name: "submit_design", arguments: input });
  const submitMs = Date.now() - t;
  const answeredAt = await now();
  if (mode === "hidden") { await page.waitForTimeout(wait); await seeing(false); }
  const shownAt = await now();
  const shownWall = Date.now();

  // The page asked something every 250 ms: how long the answer takes is how
  // long the page would have ignored a person. Not a pointer moved over the
  // model, which moves the held part's ghost and so changes what is drawn.
  let poking = true;
  let worstInput = 0;
  const poker = (async () => {
    let n = 0;
    while (poking) {
      n += 1;
      const t0 = Date.now();
      await page.evaluate(() => 0).catch(() => {});
      worstInput = Math.max(worstInput, Date.now() - t0);
      await new Promise((done) => setTimeout(done, 250));
    }
  })();
  const settled = await settle(shownAt, shownWall + longest);
  poking = false;
  await poker;

  const f = await frames(checkedAt);
  const after = f.filter(([t0]) => t0 >= shownAt);
  const final = after.length ? after[after.length - 1][3] : 0;
  // Drawn: the first frame in view from which every frame draws what the
  // last does, to within 1%, at the moment the engine had asked for it (its
  // start and its own work, not the rasteriser's). Within 1% because the
  // ground is laid wider under a design that outgrew it once it is built,
  // which moves a few plates a frame or two later; a step of the build
  // animation is eight bricks, a hundred instances and more.
  const near = (n) => Math.abs(n - final) <= final * 0.01;
  let drawnAt = null;
  for (let n = after.length - 1; n >= 0 && near(after[n][3]); n--) drawnAt = after[n];
  const drawnMs = drawnAt ? Math.round(drawnAt[0] + drawnAt[2] - shownAt) : null;
  // And in frames, with the engine's own work until then. Drawn in software a
  // frame of a big model is seconds of rasterising that a graphics card does
  // in milliseconds, so the milliseconds above are this machine's; the
  // frames and the work are the app's.
  const drawnFrame = drawnAt ? after.indexOf(drawnAt) + 1 : null;
  const ownToDrawn = drawnAt
    ? Math.round(after.slice(0, drawnFrame).reduce((sum, [, , own]) => sum + own, 0)) : null;
  // Idle: the end of the last frame in view with over 100 ms of own work.
  let idleMs = drawnMs;
  for (const [t0, , own] of after) if (own > 100) idleMs = Math.max(idleMs, Math.round(t0 + own - shownAt));
  const between = f.filter(([t0]) => t0 >= answeredAt && t0 < shownAt);
  const worstOwn = Math.max(0, ...after.map(([, , own]) => own));
  const tasks = await page.evaluate(([a]) => window.brickworksPerf.longtasks.filter(([t]) => t >= a), [shownAt]);
  const worstTask = Math.max(0, ...tasks.map(([, d]) => d));
  const state = await page.evaluate(() => window.brickworksState || {});
  await page.screenshot({ path: `${out}/${tag}.png`, timeout: 120000 }).catch(() => {});
  const changes = await page.evaluate((a) => window.brickworksPerf.changes.filter(([t]) => t >= a), checkedAt);
  writeFileSync(`${out}/${tag}.frames.json`, JSON.stringify({ checkedAt, answeredAt, shownAt, frames: f, tasks, changes }));
  await browser.close();
  return {
    size, mode, bricks: state.bricks, checkMs, submitMs, settled,
    drawnMs, drawnFrame, ownToDrawn, idleMs, instances: final, worstOwn: Math.round(worstOwn), worstTask: Math.round(worstTask),
    worstInput, waitFrames: between.length,
    waitWork: Math.round(between.reduce((s, [, , own]) => s + own, 0)),
    checkSaid: said(checked).slice(0, 60), submitSaid: said(submitted).slice(0, 60),
  };
}

const rows = [];
let failures = 0;
console.log("     size mode     check   submit |  drawn  (frame, own work)    idle  own frame   task  input | bricks instances  frames before shown (own work)");
for (const size of sizes) {
  for (const mode of modes) {
    // A page whose connector never comes up is tried again, twice: the test
    // account is shared with every other check on the machine, and a page
    // that came up with "Sign in to Brickworks again to connect Claude" was
    // nothing to do with how fast a model arrives.
    let row;
    for (let attempt = 1; ; attempt++) {
      try {
        row = await runCase(size, mode);
      } catch (trouble) {
        row = { size, mode, error: trouble.message };
      }
      if (!row.error || !/never answered/.test(row.error) || attempt >= 3) break;
      console.log(`     ${String(size).padStart(4)} ${mode.padEnd(6)} the tab never answered the connector; a fresh page`);
    }
    rows.push(row);
    writeFileSync(`${out}/arrival.json`, JSON.stringify({ url, budget, wait, rows }, null, 1));
    if (row.error) {
      failures += 1;
      console.log(`FAIL ${String(size).padStart(4)} ${mode.padEnd(6)} ${row.error}`);
      continue;
    }
    // Within three frames of being in view (the ground laid wider under a
    // design that outgrew it is the second), on the app's own work.
    const over = !row.settled || row.drawnFrame === null || row.drawnFrame > 3
      || row.ownToDrawn > budget;
    if (over) failures += 1;
    const s = (ms) => (ms === null ? "never" : `${(ms / 1000).toFixed(1)} s`);
    console.log(`${over ? "FAIL" : "ok  "} ${String(size).padStart(4)} ${mode.padEnd(6)} ${s(row.checkMs).padStart(7)} ${s(row.submitMs).padStart(8)} | ${(row.settled ? s(row.drawnMs) : `>${s(longest)}`).padStart(7)} ${(row.settled ? `(${row.drawnFrame}, ${row.ownToDrawn} ms)` : "").padEnd(16)} ${(row.settled ? s(row.idleMs) : "-").padStart(8)} ${String(row.worstOwn).padStart(7)} ms ${String(row.worstTask).padStart(6)} ${String(row.worstInput).padStart(6)} | ${String(row.bricks).padStart(6)} ${String(row.instances).padStart(9)}  ${row.waitFrames} (${s(row.waitWork)})  ${row.submitSaid.slice(0, 40)}`);
  }
}
console.log(failures
  ? `${failures} case(s) not on the screen within 3 frames and ${budget} ms of the app's work of being in view`
  : `every design was on the screen within 3 frames and ${budget} ms of the app's work of being in view`);
stop(failures ? 1 : 0);
