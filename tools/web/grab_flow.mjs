// Grabbing a part in the view and moving it on its joint, in a real browser,
// by mouse, as a person does it with the Select tool.
//
//   set -a; . ./.env; set +a
//   node tools/web/grab_flow.mjs --url=https://<preview>.vercel.app/app --bypass=$VERCEL_BYPASS --out=shots/grab_web
//   node tools/web/grab_flow.mjs --url=http://127.0.0.1:8820/ --out=shots/grab_web
//
// The web build draws with the Compatibility renderer on one thread shared
// with everything else, which no desktop probe vouches for. This opens a
// small crane through Open… > From a file (a turret on a turntable, an arm on
// a hinge on it, no sub-models: the joints are read off the parts), then
// takes hold of the arm with the mouse (window.brickworksGrab says where it
// is on the page) and drags it up: the arm turns on its hinge while the
// button is down, the status bar says what moves and how the model stands,
// and letting go keeps it as one step. Ctrl+Z puts it back where it was. Then
// the turret is dragged round on its turntable, carrying the arm. Beside it a
// four-bar lies flat, two cranks pinned to a beam 15 and a coupler across
// their ends: a crank dragged round turns the other one by the loop (Linkage),
// as a steering's arms turn. Left of the crane a beam 7 hangs on a pin without
// friction from a Technic brick on a tower: dragged out and let go, it swings
// under its own weight, back and forth, and comes to rest hanging (Swing).
// Further left a gear 40 lies flat on an axle standing free in a plate's
// hole: taken by its rim, turned round and let go while it turns, it coasts
// on at the pointer's speed and
// stops against its bearing's friction (Swing, flung). Last it opens a tube
// the app laid from a hole on the floor to one on an arm on a hinge
// (tests/fixtures/grab10/made_hose.ldr) and drags the arm: the tube is laid
// again between its holes every frame (FlexFollow), and the app's own work
// in a drag frame with it is gated as the others are (--no-hose leaves it
// out). The page asks for the
// handles (window.brickworksGrabAsk): the app finds them only when asked.
//
//   ... --big=vendor/omr/files/42082-1.mpd --only-big
//
// opens that model instead and, the page not asking for handles as a
// person's never does, times its frames standing still for --seconds (20):
// the handles were found twice a second for every model, raycasting each
// body's parts, and held a 4,000-part model's frames 180 to 460 ms. Fails if
// nothing turns, the arm does not come back on undo, the app's own work in a
// drag frame passes --work ms (33), the page stops answering for longer than
// --stall ms (5000: a hang), or a script error reaches the console. Pictures
// of each step in OUT, and the page's longest wait in each drag, said.
//
// The page's wait was the gate until 2026-10-17, at 250 ms. It is mostly
// SwiftShader drawing on this box's CPU, not the app: five runs each of the
// live build and m54 both waited 300-800 ms on the first drag at load 30-43,
// while the app's own drag frames never passed 7.3 ms, and it held m54's
// turntable fix three times.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/grab_web";
const stallLimit = Number(args.stall || 60000);
// The page's longest waits, judged at the end against what drawing a frame
// costs on this box: [ms, what].
const stalls = [];
let drawWorst = 0;
const workLimit = Number(args.work || 33);
// The app's own work when a swing is let go and when it is kept, ms: a
// tenth of a second, about when a person sees a click wait. And the reading
// of the model's joints after the keep, which waits for the model to stand
// still a quarter second first: a quarter second. On this box, in software
// at load 11 to 21 and with the browser held to two cores alike, the
// crane's let-go is 0.2 to 0.3 ms, its keep 15 ms (the flywheel's 66), the
// reading 44 to 82 ms. The page's wait in the same seconds is SwiftShader
// drawing the swing's first frames (MECHANISMS section 14).
const keepLimit = Number(args.keep || 100);
const readLimit = Number(args.read || 250);
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

// LDraw's own coordinates (-Y up): a 2x2 turntable on a 4x4 plate, a hinge
// brick on the turntable's top and a long arm on the hinge's top. The hinge
// faces the way the arm rises (3937's top tips one way only, as
// flex_pose_flow.mjs says): faced the other way, the drag up stopped 5.9°
// on, where the top met its base, which only just passed for a turn.
const model = path.resolve(out, "grab_crane.ldr");
writeFileSync(model, [
  "0 Grab crane",
  "0 Name: grab_crane.ldr",
  "1 71 0 0 0 1 0 0 0 1 0 0 0 1 3031.dat",
  "1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat",
  "1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat",
  "1 15 0 -32 0 -1 0 0 0 1 0 0 0 -1 3937.dat",
  "1 4 0 -32 0 -1 0 0 0 1 0 0 0 -1 3938.dat",
  "1 4 0 -40 -50 0 0 1 0 1 0 -1 0 0 3795.dat",
  // The four-bar, flat beside it: a beam 15 the frame, two beams 5 its
  // cranks pinned 120 apart, a beam 7 the coupler across their far ends.
  "1 71 200 0 0 1 0 0 0 1 0 0 0 1 32278.dat",
  "1 14 240 -20 -60 0 0 1 0 1 0 -1 0 0 32316.dat",
  "1 14 240 -20 60 0 0 1 0 1 0 -1 0 0 32316.dat",
  "1 4 280 -40 0 1 0 0 0 1 0 0 0 1 32524.dat",
  "1 0 200 -10 -60 0 -1 0 1 0 0 0 0 1 3673.dat",
  "1 0 200 -10 60 0 -1 0 1 0 0 0 0 1 3673.dat",
  "1 0 280 -30 -60 0 -1 0 1 0 0 0 0 1 3673.dat",
  "1 0 280 -30 60 0 -1 0 1 0 0 0 0 1 3673.dat",
  // The pendulum, left of the crane: a tower of six 2x4 bricks, a Technic
  // brick 1x4 with holes on it, and a beam 7 hanging on a pin without
  // friction in front of it.
  ...Array.from({ length: 6 }, (_, k) => `1 4 -120 ${-24 * (k + 1)} 10 1 0 0 0 1 0 0 0 1 3001.dat`),
  "1 7 -120 -168 0 1 0 0 0 1 0 0 0 1 3701.dat",
  "1 0 -120 -158 -10 0 0 -1 0 1 0 1 0 0 3673.dat",
  "1 14 -120 -98 -20 -1 0 0 0 0 1 0 1 0 32524.dat",
  // The flywheel, further left: a Technic gear 40 lying flat on an axle 3
  // standing in a Technic plate 2x4 with holes on a tower of three bricks
  // 2x4. Upright, the axle's line is a long one on the page, so a drag round
  // the gear turns it rather than sliding it along its axle.
  ...Array.from({ length: 3 }, (_, k) => `1 4 -300 ${-24 * (k + 1)} 0 1 0 0 0 1 0 0 0 1 3001.dat`),
  "1 7 -300 -80 0 1 0 0 0 1 0 0 0 1 3709b.dat",
  "1 0 -300 -102 0 0 -1 0 1 0 0 0 0 1 4519.dat",
  "1 7 -300 -112 0 1 0 0 0 0 1 0 -1 0 3649.dat",
  "",
].join("\n"));
const PARTS = 29;

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const page = await context.newPage();
// The app finds the grab handles only when a page asks for them.
await page.addInitScript(() => { window.brickworksGrabAsk = true; });
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
// The app finds the grab handles only when a page asks for them: found for
// every page twice a second, they held a timeline step 6 s in a browser.
await page.addInitScript(() => { window.brickworksGrabAsk = true; });
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
});
let failed = 0;
const t0 = Date.now();
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};
const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const grab = async () => (await page.evaluate(() => window.brickworksGrab || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: path.join(out, name), timeout: 180000 });
    console.log(`        picture: ${path.join(out, name)}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function where(name, seconds = 120) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name}.png`);
  throw new Error(`the app never showed "${name}"`);
}
async function until(read, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    const now = await read();
    if (test(now)) return now;
    await page.waitForTimeout(500);
  }
  return null;
}
async function open(file) {
  const at = await where("open", 400);
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
      await page.waitForTimeout(500);
    }
    const picker = page.choosers.shift();
    if (picker) {
      const before = (await state()).said;
      await picker.setFiles(file);
      await dontSave(before);
      return;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}
// An open over a model with changes not saved asks first whether to save
// them (ModelBar.ask_to_replace), as the crane has by the time the tube
// opens: its turns are this run's, so Don't save. When nothing is asked,
// waits only until the status bar says, in place of [before], that the open
// has begun or ended.
async function dontSave(before) {
  for (let n = 0; n < 40; n++) {
    const asked = (await controls()).replace_discard;
    if (asked) {
      console.log("        asked to save the model first: Don't save");
      await page.mouse.click(asked.x, asked.y);
      return;
    }
    const said = (await state()).said || "";
    if (said !== before && /open|read/i.test(said)) return;
    await page.waitForTimeout(500);
  }
}
// The app's own work at the let-go and at the keep of the swing that came to
// rest as [rested], and at the reading of the model's joints after it
// (GrabDrag.let_go_ms, kept_ms, ready_ms): the swing's frames are gated each
// on their own, and these were gated by nothing. Waits for the reading,
// which comes a quarter second after the keep.
async function letGoAndKeep(rested, what) {
  const read = (rested && await until(grab, (g) => g.ready && g.revision === rested.revision
    && !g.swinging && !g.grabbing, 30)) || rested || {};
  const onThread = read.ready_off_thread ? "on a worker" : "on this thread";
  check(Boolean(rested) && Number(read.let_go_ms) <= keepLimit && Number(read.kept_ms) <= keepLimit
    && (read.ready_off_thread || Number(read.ready_ms) <= readLimit),
    `the app's own work letting ${what} go and keeping it stays under ${keepLimit} ms, and reading `
    + `its joints again under ${readLimit}: let go ${read.let_go_ms} ms, kept ${read.kept_ms} ms, `
    + `read again ${read.ready_ms} ms ${onThread}`);
  return { let_go_ms: read.let_go_ms, kept_ms: read.kept_ms, ready_ms: read.ready_ms };
}
async function heartbeat() {
  await page.evaluate(() => {
    window.__beat = { last: performance.now(), worst: 0 };
    clearInterval(window.__beatTimer);
    window.__beatTimer = setInterval(() => {
      const now = performance.now();
      window.__beat.worst = Math.max(window.__beat.worst, now - window.__beat.last - 50);
      window.__beat.last = now;
    }, 50);
  });
}
// A drag by mouse from a handle: down, along a line in steps, a picture
// half way, up. Returns the app's state mid-drag.
async function drag(from, by, steps, picture) {
  await page.mouse.move(from.x, from.y, { steps: 3 });
  await page.waitForTimeout(600);
  await heartbeat();
  await page.mouse.down();
  let mid = null;
  for (let n = 1; n <= steps; n++) {
    await page.mouse.move(from.x + by.x * n / steps, from.y + by.y * n / steps);
    await page.waitForTimeout(60);
    if (n === Math.round(steps / 2)) {
      await page.waitForTimeout(700);
      mid = await grab();
      await shot(picture);
    }
  }
  await page.waitForTimeout(500);
  const stall = await page.evaluate(() => Math.round(window.__beat.worst));
  await page.mouse.up();
  await page.waitForTimeout(1500);
  return { mid, stall };
}

const timings = {};
// A Chromium performance trace of one stretch of the flow, to FILE.
const TRACED = ["devtools.timeline", "disabled-by-default-devtools.timeline", "toplevel", "gpu",
  "disabled-by-default-devtools.timeline.frame", "v8.execute", "blink", "cc", "viz"];
async function traceStart(file) {
  if (file) await browser.startTracing(page, { path: String(file), screenshots: false, categories: TRACED });
}
async function traceStop(file) {
  if (file) await browser.stopTracing();
}
// The page's frames, timed by requestAnimationFrame for [seconds]: the
// longest gaps, and how many passed 50 and 100 ms.
async function frameGaps(seconds) {
  return page.evaluate((ms) => new Promise((done) => {
    const gaps = [];
    let last = performance.now();
    const end = last + ms;
    const tick = (now) => {
      gaps.push(now - last);
      last = now;
      if (now < end) requestAnimationFrame(tick);
      else {
        gaps.sort((a, b) => b - a);
        done({ frames: gaps.length, longest: gaps.slice(0, 5).map(Math.round),
          over50: gaps.filter((g) => g > 50).length, over100: gaps.filter((g) => g > 100).length });
      }
    };
    requestAnimationFrame(tick);
  }), seconds * 1000);
}
// The frames the app drew from FROM ({drawn, at}) until it stops drawing:
// {frames, seconds, per_second}. A page's requestAnimationFrame comes every
// 17 ms whether or not the app draws, and a drag draws only when the pointer
// moves, so the gaps between the page's frames are mostly frames with
// nothing drawn (window.brickworksGrab.drawn, said twice a second at most).
async function drawnFrom() {
  const now = await grab();
  return { drawn: now.drawn || 0, at: Date.now() };
}
async function drawnUntilStill(from) {
  let last = await grab();
  let changedAt = Date.now();
  for (let n = 0; n < 240; n++) {
    await page.waitForTimeout(250);
    const now = await grab();
    if (now.drawn !== last.drawn) {
      last = now;
      changedAt = Date.now();
    } else if (Date.now() - changedAt > 1500) break;
  }
  const frames = (last.drawn || 0) - from.drawn;
  const seconds = Math.max((changedAt - from.at) / 1000, 0.001);
  return { frames, seconds: Number(seconds.toFixed(2)), per_second: Number((frames / seconds).toFixed(2)) };
}
// The page's frames recorded from now until read: their gaps, by
// requestAnimationFrame, while something else goes on.
async function startGaps() {
  await page.evaluate(() => {
    window.__gaps = [];
    window.__gapsOn = true;
    let last = performance.now();
    const tick = (now) => {
      window.__gaps.push(now - last);
      last = now;
      if (window.__gapsOn) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}
async function readGaps() {
  return page.evaluate(() => {
    window.__gapsOn = false;
    const gaps = window.__gaps.slice(1);
    const total = gaps.reduce((a, b) => a + b, 0);
    gaps.sort((a, b) => a - b);
    return { frames: gaps.length, mean: Math.round(total / Math.max(gaps.length, 1)),
      median: Math.round(gaps[Math.floor(gaps.length / 2)] || 0), worst: Math.round(gaps[gaps.length - 1] || 0) };
  });
}
if (args.big) {
  try {
    await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
    check(Boolean(await where("open", 400)), "the app came up");
    await page.waitForTimeout(Number(args.load || 15000));
    await page.evaluate(() => { window.brickworksGrabAsk = false; });
    await open(path.resolve(args.big));
    const opened = await until(state, (s) => (s.bricks || 0) > 500 && !/arriving|opening|reading/i.test(s.said || ""), 900);
    check(Boolean(opened), `${path.basename(args.big)} opened: ${(await state()).bricks} parts`);
    // Read for a grab (GrabDrag reads a model's joints once it stands still),
    // and quiet: its parts arrived and drawn, five seconds in a row with no
    // frame past 100 ms (a big model drawn in software takes a while).
    await until(grab, (g) => g.ready, 300);
    let quiet = null;
    for (let n = 0; n < 36 && !quiet; n++) {
      const probe = await frameGaps(5);
      if (probe.over100 === 0) quiet = probe;
    }
    check(Boolean(quiet), "the page went quiet once the model was in");
    const seconds = Number(args.seconds || 20);
    // Found so far (the page asked as it loaded, before this model).
    const foundBefore = (await grab()).handles_found;
    const gaps = await frameGaps(seconds);
    console.log(`      standing still ${seconds} s, the page not asking: ${gaps.frames} frames, longest `
      + `${gaps.longest.join(", ")} ms; ${gaps.over50} past 50 ms, ${gaps.over100} past 100 ms`);
    timings.big = { model: path.basename(args.big), ...gaps };
    const unasked = await grab();
    check((unasked.handles || []).length === 0 && unasked.handles_found === foundBefore,
      `no handles found while the page does not ask (${(unasked.handles || []).length}; found ${unasked.handles_found} `
      + `times in all, ${foundBefore} before)`);
    check(gaps.over100 === 0, `no frame past 100 ms standing still on ${path.basename(args.big)} (${gaps.over100})`);
    // Asked, they are found once, and not again while nothing changes.
    await page.evaluate(() => { window.brickworksGrabAsk = true; });
    const askedGaps = await frameGaps(10);
    const asked = await grab();
    console.log(`      asked for 10 s: found ${asked.handles_found} time(s), the last in ${asked.handles_ms} ms, `
      + `${(asked.handles || []).length} handles; frames longest ${askedGaps.longest.join(", ")} ms`);
    timings.big_asked = { found: asked.handles_found, ms: asked.handles_ms, ...askedGaps };
    check(asked.handles_found === foundBefore + 1,
      `asked, they are found once and kept while nothing changes (${asked.handles_found - foundBefore})`);
    await shot("big.png");
  } catch (trouble) {
    check(false, `stopped: ${trouble.message}`);
    await shot("stopped.png");
  }
}
try {
  if (args["only-big"]) throw new Error("only the big model was asked for");
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  check(Boolean(await where("open", 400)), "the app came up");
  await page.waitForTimeout(Number(args.load || 15000));
  let opened = null;
  for (let attempt = 0; attempt < 3 && !opened; attempt++) {
    await open(model);
    opened = await until(state, (s) => s.bricks === PARTS && !/arriving/.test(s.said || ""), 240);
    if (!opened) await page.waitForTimeout(15000);
  }
  if (!check(Boolean(opened), `the crane opened: ${(await state()).bricks} parts`)) {
    // Which of the file's parts the app has not got.
    const now = await state();
    const wanted = [...new Set(readFileSync(model, "utf8").split("\n").filter((l) => l.startsWith("1 "))
      .map((l) => l.trim().split(/\s+/).pop().replace(/\.dat$/, "")))];
    const have = new Set(now.parts || []);
    console.log(`        not in the model: ${wanted.filter((p) => !have.has(p)).join(", ") || "none by number"}; `
      + `the bar says "${now.said}"`);
  }
  await page.keyboard.press("Shift+F");
  await page.waitForTimeout(4000);
  const ready = await until(grab, (g) => (g.handles || []).length >= 2, 60);
  check(Boolean(ready), `the arm and the turret are there to take hold of: `
    + `${ready ? ready.handles.map((h) => `${h.part} on its ${h.kind}`).join(", ")
      : JSON.stringify(await grab())}`);
  if (!ready) throw new Error("no handles to take hold of");
  await shot("1_before.png");
  const arm = ready.handles.find((h) => h.part === "3795") || ready.handles.find((h) => h.kind === "hinge");
  const revision = (await grab()).revision;

  // The arm, up on its hinge.
  await startGaps();
  await traceStart(args["trace-drag"]);
  const up = await drag(arm, { x: 0, y: -160 }, 24, "2_arm_mid_drag.png");
  await traceStop(args["trace-drag"]);
  const dragGaps = await readGaps();
  console.log(`      the page's frames during the arm's drag: ${dragGaps.frames}, gaps median ${dragGaps.median}, `
    + `mean ${dragGaps.mean}, worst ${dragGaps.worst} ms`);
  timings.drag_frames = dragGaps;
  check(Boolean(up.mid && up.mid.grabbing && Math.abs(up.mid.angle || 0) > 5),
    `while the button is down the arm turns on its hinge: ${up.mid && up.mid.angle}° (${up.mid && up.mid.what})`);
  const after = await until(grab, (g) => !g.grabbing && g.revision !== revision, 10);
  check(Boolean(after) && /hinge/.test(after.said || ""),
    `let go, it is kept and said: "${after && after.said}"`);
  check(Boolean(after) && Number(after.worst_ms) <= workLimit,
    `the app's own work in a drag frame stays under ${workLimit} ms: worst ${after && after.worst_ms} ms`);
  stalls.push([up.stall, "the drag"]);
  timings.arm = { frames: after && after.frames, mean_ms: after && after.mean_ms,
    worst_ms: after && after.worst_ms, stall_ms: up.stall };
  console.log(`      the app's own cost of a drag frame: mean ${after && after.mean_ms} ms, worst `
    + `${after && after.worst_ms} ms over ${after && after.frames} frames`);
  await shot("3_arm_after.png");
  const moved = (await until(grab, (g) => (g.handles || []).length >= 2, 10)).handles
    .find((h) => h.id === arm.id);
  // Measured at the arm's far end (far_x, far_y: the end of its part
  // furthest from the hinge's line), where a turn shows most. The handle
  // itself is the first corner the pointer lands on: m131's was 8 LDU from
  // the hinge, and the arm kept 20 degrees up moved it 3 pixels.
  const far = (h) => [Number(h.far_x ?? h.x), Number(h.far_y ?? h.y)];
  const [armX, armY] = far(arm);
  const [movedX, movedY] = moved ? far(moved) : [NaN, NaN];
  check(Boolean(moved) && Math.hypot(movedX - armX, movedY - armY) > 5,
    `the arm stands somewhere else now: its far end at ${movedX},${movedY} from ${armX},${armY}`);

  // Undo: back where it was.
  await page.keyboard.press("Control+z");
  await page.waitForTimeout(2500);
  const back = (await until(grab, (g) => (g.handles || []).some((h) => h.id === arm.id), 10)).handles
    .find((h) => h.id === arm.id);
  const [backX, backY] = back ? far(back) : [NaN, NaN];
  check(Boolean(back) && Math.hypot(backX - armX, backY - armY) <= 2,
    `Ctrl+Z puts the arm back as one step: its far end at ${backX},${backY}`);

  // The turret round on its turntable, carrying the arm.
  const turret = (await grab()).handles.find((h) => h.kind === "turntable");
  if (check(Boolean(turret), "the turret is there to take hold of")) {
    const round = await drag(turret, { x: 140, y: 30 }, 20, "4_turret_mid_drag.png");
    check(Boolean(round.mid && round.mid.grabbing && Math.abs(round.mid.angle || 0) > 5),
      `the turret turns on its turntable: ${round.mid && round.mid.angle}° (${round.mid && round.mid.what})`);
    const kept = await until(grab, (g) => !g.grabbing && /turntable/.test(g.said || ""), 10);
    check(Boolean(kept), `and is kept: "${kept && kept.said}"`);
    timings.turret = { frames: kept && kept.frames, mean_ms: kept && kept.mean_ms,
      worst_ms: kept && kept.worst_ms, stall_ms: round.stall };
    await shot("5_turret_after.png");
  }

  // The four-bar: a crank taken by the mouse and dragged round; the loop
  // turns the other crank and carries the coupler.
  // A crank is said by the part under its handle: the beam 5 or its pin.
  const isCrank = (h) => h.kind === "pin" && (h.part === "32316" || h.part === "3673");
  const bars = await until(grab, (g) => !g.grabbing && (g.handles || []).some(isCrank), 20);
  const crank = bars && bars.handles.find(isCrank);
  if (check(Boolean(crank), `a crank of the four-bar is there to take hold of `
    + `(${bars ? bars.handles.map((h) => `${h.part} on its ${h.kind}`).join(", ") : "none"})`)) {
    const others = (h) => h.kind === "pin" && h.id !== crank.id;
    const before = bars.handles.filter(others);
    const loop = await drag(crank, { x: 60, y: -90 }, 24, "6_fourbar_mid_drag.png");
    check(Boolean(loop.mid && loop.mid.grabbing && /loop/.test(loop.mid.what || "")
      && Math.abs(loop.mid.angle || 0) > 5),
      `the crank turns and takes its loop: ${loop.mid && loop.mid.angle}° (${loop.mid && loop.mid.what})`);
    const kept = await until(grab, (g) => !g.grabbing && /loop/.test(g.said || ""), 10);
    check(Boolean(kept), `and is kept: "${kept && kept.said}"`);
    check(Boolean(kept) && Number(kept.worst_ms) <= workLimit,
      `the app's own work in a four-bar frame stays under ${workLimit} ms: worst ${kept && kept.worst_ms} ms`);
    stalls.push([loop.stall, "the four-bar's drag"]);
    timings.fourbar = { frames: kept && kept.frames, mean_ms: kept && kept.mean_ms,
      worst_ms: kept && kept.worst_ms, stall_ms: loop.stall };
    console.log(`      the app's own cost of a four-bar frame: mean ${kept && kept.mean_ms} ms, worst `
      + `${kept && kept.worst_ms} ms over ${kept && kept.frames} frames`);
    const after = ((await until(grab, (g) => (g.handles || []).length >= 2, 10)) || { handles: [] }).handles;
    const moved = before.filter((h) => {
      const now = after.find((a) => a.id === h.id);
      return now && Math.hypot(now.x - h.x, now.y - h.y) > 6;
    });
    check(moved.length >= 1,
      `the loop carried what the crank does not hold: ${moved.map((h) => h.part).join(", ") || "nothing"} moved`);
    await shot("7_fourbar_after.png");
  }

  // The pendulum: dragged out and let go, it swings, and is kept at rest.
  // Timed in one swing with no picture taken (a picture in a browser drawing
  // in software holds the page's frames for seconds), drawn in a second.
  const isBeam = (h) => h.part === "32524" && h.x < arm.x;
  const swingOnce = async (pictures) => {
    const hung = await until(grab, (g) => !g.grabbing && !g.swinging && (g.handles || []).some(isBeam), 20);
    const beam = hung && hung.handles.find(isBeam);
    if (!beam) return null;
    await page.mouse.move(beam.x, beam.y, { steps: 3 });
    await page.waitForTimeout(600);
    await heartbeat();
    await page.mouse.down();
    for (let n = 1; n <= 16; n++) {
      await page.mouse.move(beam.x + 150 * n / 16, beam.y - 40 * n / 16);
      await page.waitForTimeout(60);
    }
    await page.waitForTimeout(400);
    const held = await grab();
    if (!pictures) await startGaps();
    // --trace=FILE: a Chromium performance trace of the swing, release to rest.
    if (!pictures) await traceStart(args.trace);
    await page.mouse.up();
    let seen = false;
    let shots = 0;
    for (let n = 0; n < 400; n++) {
      const now = await grab();
      if (now.swinging) {
        seen = true;
        if (pictures && shots < 2) await shot(`8_pendulum_swinging_${shots++}.png`);
      } else if (seen || n > 10) break;
      await page.waitForTimeout(150);
    }
    // Drawn in software a frame of this model takes 0.5 to 3 s on a loaded
    // box, and a picture as long again: the swing's 3 s, drawn a quarter
    // second a frame at most, came to rest after the minute this waited.
    const rested = await until(grab, (g) => !g.swinging && /came to rest/.test(g.said || ""), 180);
    if (!pictures) await traceStop(args.trace);
    const stall = await page.evaluate(() => Math.round(window.__beat.worst));
    const gaps = pictures ? null : await readGaps();
    return { held, seen, rested, stall, gaps };
  };
  const timed = await swingOnce(false);
  if (check(Boolean(timed), "the pendulum's beam is there to take hold of")) {
    const { held, seen, rested, stall, gaps } = timed;
    console.log(`      the page's frames from the release to rest: ${gaps.frames}, gaps median ${gaps.median}, `
      + `mean ${gaps.mean}, worst ${gaps.worst} ms`);
    check(Boolean(held && held.grabbing) && Math.abs(held.angle || 0) > 10,
      `the beam turns out on its free pin: ${held && held.angle}°`);
    check(seen, "let go, it swings");
    check(Boolean(rested), `and comes to rest, said: "${rested && rested.said}"`);
    check(Boolean(rested) && Number(rested.swing_worst_ms) <= workLimit,
      `the app's own work in a swing frame stays under ${workLimit} ms: mean ${rested && rested.swing_mean_ms}, `
      + `worst ${rested && rested.swing_worst_ms} ms over ${rested && rested.swing_frames} frames`);
    stalls.push([stall, "the swing"]);
    const kept = await letGoAndKeep(rested, "the pendulum");
    // A frame steps the swing at most a quarter second and 8 ms of the app's
    // work: where the page draws slower than that (software drawing on a
    // loaded box), the swing is drawn slower than it is.
    console.log(`      the swing: ${rested && rested.swing_s} s simulated, drawn over ${rested && rested.swing_clock_s} s `
      + `on the clock in ${rested && rested.swing_frames} frames`);
    // Drawn frames a second, said against the view turning's below.
    const perSecond = rested ? rested.swing_frames / Math.max(rested.swing_clock_s, 0.001) : 0;
    timings.swing_fps = perSecond;
    timings.swing = { frames: rested && rested.swing_frames, mean_ms: rested && rested.swing_mean_ms,
      worst_ms: rested && rested.swing_worst_ms, stall_ms: stall, simulated_s: rested && rested.swing_s,
      clock_s: rested && rested.swing_clock_s, page_frames: gaps, ...kept };
    await page.keyboard.press("Control+z");
    await page.waitForTimeout(2500);
    const drawn = await swingOnce(true);
    if (!check(Boolean(drawn && drawn.rested), "swung again for its pictures, and at rest again")) {
      const now = await grab();
      console.log(`        found the beam: ${Boolean(drawn)}; at release: grabbing ${drawn && drawn.held && drawn.held.grabbing}, `
        + `angle ${drawn && drawn.held && drawn.held.angle}, swung ${drawn && drawn.seen}; now: swinging ${now.swinging}, `
        + `said "${now.said}"`);
    }
    await shot("9_pendulum_rest.png");
    // For reference, the page's frames while every frame is drawn anew and
    // nothing of the grab runs: the view turned by a right-drag, a move each
    // frame for three seconds.
    await page.mouse.move(700, 450);
    await page.waitForTimeout(1500);
    const viewFrom = await drawnFrom();
    await startGaps();
    await traceStart(args["trace-view"]);
    await page.mouse.down({ button: "right" });
    const began = Date.now();
    for (let n = 0; Date.now() - began < 3000; n++) {
      await page.mouse.move(700 + 120 * Math.sin(n / 10), 450);
      await page.waitForTimeout(16);
    }
    await page.mouse.up({ button: "right" });
    await traceStop(args["trace-view"]);
    const turning = await readGaps();
    const viewDrawn = await drawnUntilStill(viewFrom);
    console.log(`      for reference, the page's frames while the view turns: ${turning.frames}, gaps median `
      + `${turning.median}, mean ${turning.mean}, worst ${turning.worst} ms; the app drew ${viewDrawn.frames} `
      + `in ${viewDrawn.seconds} s, ${viewDrawn.per_second} a second`);
    timings.view_turning_frames = turning;
    drawWorst = turning.worst;
    timings.view_turning_drawn = viewDrawn;
    // Like with like: frames the app drew a second, the swing's and the
    // view turning's. The page's median gap, the bar until 2026-10-17, is
    // mostly frames with nothing to draw: on SwiftShader every drawn frame
    // of this model costs the same, a drag's, a swing's or a turn's
    // (MECHANISMS section 14). The two are timed a minute apart on a shared
    // box. Said, not gated: the rate is SwiftShader's on a loaded CPU, a turn
    // timed a minute later drew 1.0 one run and 2.4 the next, and the swing
    // fell short of three quarters of it once in two. What the app controls,
    // its own work in a swing frame, is gated above.
    console.log(`      drawn a second: the swing ${timings.swing_fps.toFixed(1)}, `
      + `the view turning ${viewDrawn.per_second.toFixed(1)}`);
    await page.waitForTimeout(1500);
  }
  // The flywheel: taken by its rim and turned round by the mouse at half a
  // turn a second for two seconds by the clock (a browser drawing in
  // software reads the pointer a few times a second, and the speed is read
  // over those), then let go at once: it carries on at that speed and
  // coasts to a stop against its bearing's friction, and says so.
  // The only part on an axle here: the gear 40's, or its axle's. (Not told
  // by where it is on the page: the view has been turned since the arm.)
  const isWheel = (h) => h.part === "3649" || h.kind === "axle";
  const wheelAt = await until(grab, (g) => !g.grabbing && !g.swinging && (g.handles || []).some(isWheel), 20);
  const wheel = wheelAt && wheelAt.handles.find(isWheel);
  if (check(Boolean(wheel), `the flywheel is there to take hold of (${wheelAt
    ? wheelAt.handles.map((h) => `${h.part} on its ${h.kind}`).join(", ") : "none"})`)) {
    // Round the axle's point on the page (pivot_x, pivot_y), through the
    // handle on the gear.
    const cx = wheel.pivot_x ?? wheel.x;
    const cy = wheel.pivot_y ?? wheel.y;
    const r = Math.max(Math.hypot(wheel.x - cx, wheel.y - cy), 10);
    const a0 = Math.atan2(wheel.x - cx, -(wheel.y - cy));
    await page.mouse.move(cx + r * Math.sin(a0), cy - r * Math.cos(a0), { steps: 3 });
    await page.waitForTimeout(600);
    await heartbeat();
    await page.mouse.down();
    const began = Date.now();
    let heldMid = null;
    // Two seconds round, and on until the app has hold of it and has turned
    // it (at most ten): a browser drawing a frame a second reads the press
    // a frame late, and read once at a second the drag had not begun.
    const turned = (g) => Boolean(g && g.grabbing) && Math.abs(g.angle || 0) > 5;
    while (Date.now() - began < 10000 && (Date.now() - began < 2000 || !turned(heldMid))) {
      const a = a0 + Math.PI * (Date.now() - began) / 1000;
      await page.mouse.move(cx + r * Math.sin(a), cy - r * Math.cos(a));
      await page.waitForTimeout(16);
      if (Date.now() - began > 1000 && !turned(heldMid)) heldMid = await grab();
    }
    await page.mouse.up();
    let coasting = null;
    for (let n = 0; n < 200 && !coasting; n++) {
      const now = await grab();
      if (now.swinging && Math.abs(now.coast_deg_s || 0) > 0) coasting = now;
      else if (!now.swinging && /coasted|stopped at|not moved|, \d+°/.test(now.said || "") && n > 4) break;
      await page.waitForTimeout(100);
    }
    const rested = await until(grab, (g) => !g.swinging && !g.grabbing && /coasted/.test(g.said || ""), 120);
    const stall = await page.evaluate(() => Math.round(window.__beat.worst));
    check(Boolean(heldMid && heldMid.grabbing) && Math.abs(heldMid.angle || 0) > 5,
      `the flywheel turns on its axle while the button is down: `
      + `${heldMid && heldMid.angle}° (${heldMid && heldMid.what})`);
    if (!check(Boolean(rested), `let go while it turns, it coasts and says how far: "${rested && rested.said}"`)) {
      const now = await grab();
      console.log(`        held at the release: ${heldMid && heldMid.angle}°; coasting seen: ${Boolean(coasting)}; `
        + `now: swinging ${now.swinging}, grabbing ${now.grabbing}, let go at ${now.coast_deg_s}° a second, said "${now.said}"`);
    }
    console.log(`      let go at ${rested && rested.coast_deg_s}° a second (the mouse went round at 180), `
      + `${rested && rested.swing_s} s simulated over ${rested && rested.swing_clock_s} s on the clock in `
      + `${rested && rested.swing_frames} frames`);
    check(Boolean(rested) && Number(rested.swing_worst_ms) <= workLimit,
      `the app's own work in a coasting frame stays under ${workLimit} ms: mean ${rested && rested.swing_mean_ms}, `
      + `worst ${rested && rested.swing_worst_ms} ms over ${rested && rested.swing_frames} frames`);
    stalls.push([stall, "the flick"]);
    const coastKept = await letGoAndKeep(rested, "the flywheel");
    timings.coast = { said: rested && rested.said, deg_s: rested && rested.coast_deg_s,
      frames: rested && rested.swing_frames, mean_ms: rested && rested.swing_mean_ms,
      worst_ms: rested && rested.swing_worst_ms, simulated_s: rested && rested.swing_s,
      clock_s: rested && rested.swing_clock_s, stall_ms: stall, ...coastKept };
    await shot("10_flywheel_after.png");
  }
  // A pneumatic tube laid from a hole on the floor to one on an arm on a
  // hinge (tests/fixtures/grab10/made_hose.ldr, laid by the app): the arm
  // dragged round, the tube is laid again between its holes every frame
  // (FlexFollow), and the app's own work in a drag frame stays under the
  // gate with it.
  if (!args["no-hose"]) {
    await open(path.resolve("tests/fixtures/grab10/made_hose.ldr"));
    const hoseOpen = await until(state, (s) => s.bricks >= 40 && !/arriving/.test(s.said || ""), 240);
    check(Boolean(hoseOpen), `the tube and its arm opened: ${(await state()).bricks} parts`);
    await page.keyboard.press("Shift+F");
    await page.waitForTimeout(4000);
    const isArm = (h) => h.part === "3004" || h.part === "3700" || h.kind === "hinge";
    const armAt = await until(grab, (g) => !g.grabbing && (g.handles || []).some(isArm), 60);
    const hoseArm = armAt && armAt.handles.find(isArm);
    if (check(Boolean(hoseArm), `the arm the tube goes to is there to take hold of (${armAt
      ? armAt.handles.map((h) => `${h.part} on its ${h.kind}`).join(", ") : "none"})`)) {
      await shot("11_hose_before.png");
      const bent = await drag(hoseArm, { x: 70, y: 40 }, 20, "12_hose_mid_drag.png");
      const keptHose = await until(grab, (g) => !g.grabbing && /hinge/.test(g.said || ""), 30);
      check(Boolean(bent.mid && bent.mid.grabbing && Math.abs(bent.mid.angle || 0) > 3),
        `the arm turns on its hinge while the button is down: ${bent.mid && bent.mid.angle}°`);
      check(Boolean(keptHose) && Number(keptHose.hoses) >= 1,
        `and the tube is bent with it: ${keptHose && keptHose.hoses} laid again, `
        + `at most ${keptHose && keptHose.hose_worst_ms} ms a frame`);
      check(Boolean(keptHose) && Number(keptHose.worst_ms) <= workLimit,
        `the app's own work in a drag frame with the tube stays under ${workLimit} ms: `
        + `mean ${keptHose && keptHose.mean_ms}, worst ${keptHose && keptHose.worst_ms} ms over `
        + `${keptHose && keptHose.frames} frames`);
      check(bent.stall <= stallLimit, `the page did not hang in the tube's drag: its longest wait ${bent.stall} ms`);
      timings.hose = { said: keptHose && keptHose.said, hoses: keptHose && keptHose.hoses,
        hose_worst_ms: keptHose && keptHose.hose_worst_ms, mean_ms: keptHose && keptHose.mean_ms,
        worst_ms: keptHose && keptHose.worst_ms, frames: keptHose && keptHose.frames, stall_ms: bent.stall };
      await shot("13_hose_after.png");
    }
  }
} catch (trouble) {
  if (!args["only-big"]) {
    check(false, `stopped: ${trouble.message}`);
    await shot("stopped.png");
  }
}
// The page's longest waits are said, and fail only past a minute, a page
// frozen. What the app itself does is gated above: each drag and swing
// frame, the let-go and the keep (GrabDrag.let_go_ms, kept_ms). What is left
// in a wait is SwiftShader drawing, and that grows with the box's load, not
// the code: m78 and m79 pinned to the same cores waited alike, 3.7 and 3.5 s
// on four, 11.4 and 12.1 s on two (bench/results/letgo-2026-10-18), and a
// gate at twice a frame of the view turning held m79 three times for that.
for (const [ms, what] of stalls) {
  const ratio = drawWorst > 0 ? ` (${(ms / drawWorst).toFixed(1)} frames of the view turning at worst, ${drawWorst} ms)` : "";
  if (ms <= stallLimit) {
    console.log(`      the page's longest wait in ${what}: ${ms} ms${ratio}`);
  } else {
    check(false, `the page froze in ${what}: its longest wait ${ms} ms, over ${stallLimit}${ratio}`);
  }
}
writeFileSync(path.join(out, "timings.json"), JSON.stringify(timings, null, 2));
check(errors.length === 0, `no script errors (${errors.slice(0, 3).join(" | ")})`);
console.log(failed === 0 ? "grab in a browser: all passed" : `grab in a browser: ${failed} FAILED`);
await browser.close();
process.exit(failed === 0 ? 0 : 1);
