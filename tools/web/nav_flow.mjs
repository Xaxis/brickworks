// Navigating with the left button alone, in a browser: no right button, no
// middle button.
//
//   node tools/web/nav_flow.mjs --url=<preview>/app --bypass=… [--ratio=2] [--out=shots/nav]
//
// The owner: "there should be a way to use the mouse to move and navigate
// the view and pan and not placing bricks." A trackpad has no middle button
// and a right drag on one is awkward. So this does everything with left
// clicks and drags, the wheel as a trackpad sends it, a pinch (a wheel with
// Ctrl, as a browser reports one) and keys: turns the view all the way
// round, slides it, zooms to a part, fits, uses the view tools, the keys
// held to navigate and the view cube, takes a part into hand and turns the
// view with it held — and checks after every one that no brick was put down
// — then puts three bricks down and selects one.
//
// It reads where the view is off the page (window.brickworksState.view:
// the turn in all, unwrapped; the tilt; the distance; what it looks at).
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/nav";
const ratio = Number(args.ratio || 1);
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: ratio });
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
const slow = ratio > 1 ? 2 : 1;
const wait = (ms) => page.waitForTimeout(ms * slow);

async function controls() {
  return (await page.evaluate(() => window.brickworksControls || {})) || {};
}
async function controlAt(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await controls();
    if (where[name]) return where[name];
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function state() {
  return page.evaluate(() => window.brickworksState || {});
}
// What the page says once it has said it again since now: the app tells the
// page every half second, so a read straight after an input can be from
// before it. Drawing only what changed (IdleDraw), frames come sixty a
// second rather than one, the half second is all that is left between an
// input and its read, and a drag "on nothing" read the line from where the
// pointer was before and started on a part.
async function fresh() {
  const was = (await state()).now || 0;
  for (let n = 0; n < 50; n++) {
    await page.waitForTimeout(100);
    const now = await state();
    if ((now.now || 0) > was) return now;
  }
  return state();
}
async function view() {
  const s = await state();
  return s.view || { yaw: 0, pitch: 0, distance: 0, focus: [0, 0, 0] };
}
const focusMoved = (a, b) => Math.hypot(a.focus[0] - b.focus[0], a.focus[1] - b.focus[1], a.focus[2] - b.focus[2]);
// The picture itself, small and grey, for a build that does not say where
// its view is: a drag that turned the view changed it.
async function frameOf() {
  return page.evaluate(() => {
    const canvas = document.querySelector("canvas");
    const probe = document.createElement("canvas");
    probe.width = 64;
    probe.height = 36;
    const ctx = probe.getContext("2d");
    ctx.drawImage(canvas, 0, 0, 64, 36);
    const { data } = ctx.getImageData(0, 0, 64, 36);
    const values = [];
    for (let i = 0; i < data.length; i += 4) values.push((data[i] + data[i + 1] + data[i + 2]) / 3);
    return values;
  });
}
const differ = (a, b) => a.reduce((sum, value, n) => sum + Math.abs(value - b[n]), 0) / a.length;

// Left button only, every one of them.
let inputs = 0;
async function click(at, options = {}) {
  inputs += 1;
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await wait(200);
  if (options.modifier) await page.keyboard.down(options.modifier);
  await page.mouse.click(at.x, at.y, { button: "left" });
  if (options.modifier) await page.keyboard.up(options.modifier);
  await wait(600);
  await fresh();
}
async function drag(from, to, options = {}) {
  inputs += 1;
  await page.mouse.move(from.x, from.y, { steps: 3 });
  await wait(200);
  for (const key of options.hold || []) await page.keyboard.down(key);
  await page.mouse.down({ button: "left" });
  for (let n = 1; n <= 12; n += 1) {
    await page.mouse.move(from.x + (to.x - from.x) * n / 12, from.y + (to.y - from.y) * n / 12);
    await wait(40);
  }
  await page.mouse.up({ button: "left" });
  for (const key of [...(options.hold || [])].reverse()) await page.keyboard.up(key);
  await wait(700);
  await fresh();
}
async function wheel(at, dx, dy, times, options = {}) {
  inputs += 1;
  await page.mouse.move(at.x, at.y, { steps: 2 });
  for (const key of options.hold || []) await page.keyboard.down(key);
  for (let n = 0; n < times; n += 1) {
    await page.mouse.wheel(dx, dy);
    await wait(60);
  }
  for (const key of [...(options.hold || [])].reverse()) await page.keyboard.up(key);
  await wait(700);
  await fresh();
}
async function key(name) {
  inputs += 1;
  await page.keyboard.press(name);
  await wait(500);
  await fresh();
}

let failed = 0;
const log = [];
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  log.push({ what, ok });
  if (!ok) failed += 1;
}
let shots = 0;
async function shot(name) {
  shots += 1;
  await page.screenshot({ path: `${out}/${String(shots).padStart(2, "0")}_${name}.png`, timeout: 120000 })
    .catch(() => {});
}

await controlAt("model_name");
await wait(8000);
const box = await controlAt("view");
await key("Escape");
const bricks = (await state()).bricks;
console.log(`  the model on the baseplate: ${bricks} bricks`);
const spot = (dx, dy) => ({ x: box.x + dx, y: box.y + dy });

// Somewhere with no part under it, by what the status line says a drag
// from there would do. The view moves between tries, so it is asked anew.
async function nothingAt(candidates) {
  for (const at of candidates) {
    await page.mouse.move(at.x, at.y, { steps: 2 });
    await wait(400);
    const hint = String((await fresh()).hint || "");
    if (!hint.includes("click selects it")) return at;
  }
  return candidates[0];
}
const corners = [spot(-280, 220), spot(280, 220), spot(-300, -60), spot(300, -60), spot(0, 260)];
async function nothingPlaced(what) {
  const now = (await state()).bricks;
  check(`...and nothing was put down (${now} bricks)${what ? " " + what : ""}`, now === bricks);
}

console.log("  turning all the way round with a left drag on nothing");
let at = await nothingAt(corners);
const hintThere = String((await state()).hint || "");
check(`the status line says what a drag there does ("${hintThere.slice(0, 60)}…")`,
  /drag turns the view/.test(hintThere));
let start = await view();
let drags = 0;
const pictureBefore = await frameOf();
while (drags < 14) {
  at = await nothingAt(corners);
  await drag(at, { x: at.x + 220, y: at.y });
  drags += 1;
  if (drags === 1) {
    const once = await view();
    const changed = differ(pictureBefore, await frameOf());
    check(`one left drag turns the view (${(once.yaw - start.yaw).toFixed(2)} rad; the picture changed ${changed.toFixed(1)})`,
      Math.abs(once.yaw - start.yaw) > 0.3 && changed > 2);
    if (Math.abs(once.yaw - start.yaw) <= 0.3) break;
  }
  if (Math.abs((await view()).yaw - start.yaw) >= 2 * Math.PI) break;
}
const round = await view();
check(`...all the way round in ${drags} drags (${(Math.abs(round.yaw - start.yaw) / Math.PI * 180).toFixed(0)}°)`,
  Math.abs(round.yaw - start.yaw) >= 2 * Math.PI);
await nothingPlaced();
check(`...and nothing was selected (${(await state()).selected})`, (await state()).selected === 0);
await shot("round");

console.log("  sliding");
start = await view();
at = await nothingAt(corners);
await drag(at, { x: at.x + 160, y: at.y - 60 }, { hold: ["Shift"] });
check(`Shift and a left drag slide the view (${focusMoved(start, await view()).toFixed(1)} LDU)`,
  focusMoved(start, await view()) > 5);
start = await view();
await drag(spot(0, 0), spot(-150, 40), { hold: ["Space"] });
check(`Space held and a drag slide it, from on the model too (${focusMoved(start, await view()).toFixed(1)} LDU)`,
  focusMoved(start, await view()) > 5);
await nothingPlaced();

console.log("  the keys held to navigate");
start = await view();
await drag(spot(0, 0), spot(160, 0), { hold: ["Alt"] });
check(`Alt and a drag turn it, from on the model (${((await view()).yaw - start.yaw).toFixed(2)} rad)`,
  Math.abs((await view()).yaw - start.yaw) > 0.3);
start = await view();
await drag(spot(0, 0), spot(-120, 50), { hold: ["Alt", "Shift"] });
check("Alt-Shift and a drag slide it", focusMoved(start, await view()) > 5);
start = await view();
await drag(spot(0, 0), spot(0, -120), { hold: ["Control", "Alt"] });
check(`Ctrl-Alt and a drag zoom (${start.distance.toFixed(0)} to ${(await view()).distance.toFixed(0)})`,
  Math.abs((await view()).distance - start.distance) > 20);
await nothingPlaced();
check(`...and Alt let go, the tool is Select again (${(await state()).mode})`, (await state()).mode === "select");

console.log("  a trackpad: two fingers and a pinch");
start = await view();
await wheel(spot(0, 0), 6, 4, 12);
const swiped = await view();
check(`two fingers turn the view (${(swiped.yaw - start.yaw).toFixed(2)} rad, ${(swiped.pitch - start.pitch).toFixed(2)} tilt)`,
  Math.abs(swiped.yaw - start.yaw) + Math.abs(swiped.pitch - start.pitch) > 0.1);
start = await view();
await wheel(spot(0, 0), 0, 6, 12, { hold: ["Shift"] });
check("Shift and two fingers slide it", focusMoved(start, await view()) > 2);
start = await view();
await wheel(spot(0, 0), 0, -8, 10, { hold: ["Control"] });
check(`a pinch zooms in (${start.distance.toFixed(0)} to ${(await view()).distance.toFixed(0)})`,
  (await view()).distance < start.distance - 5);
await nothingPlaced();

console.log("  the view tools");
// On the model framed, not wherever the trackpad left the view. The view is
// centred on the model's column (CadCamera.seen), so the pinch above, at the
// middle of the view, drives straight in: it left the eye 2 LDU under the
// baseplate, a stud 355 px across and the page all dark green, where a slide
// that keeps the grabbed surface under the pointer moved the focus 0.3 LDU
// and nothing on the page. Before, the pinch went in 170 px to one side.
await key("Digit0");
await key("KeyF");
await wait(1500);
await key("KeyO");
check(`O is the Orbit tool (${(await state()).mode})`, (await state()).mode === "orbit");
start = await view();
await drag(spot(0, 0), spot(150, 0));
check(`...whose drag on the model turns the view (${((await view()).yaw - start.yaw).toFixed(2)} rad)`,
  Math.abs((await view()).yaw - start.yaw) > 0.3);
check(`...and selects nothing (${(await state()).selected})`, (await state()).selected === 0);
await key("KeyH");
start = await view();
const beforePan = await frameOf();
await drag(spot(0, 0), spot(-120, 60));
// Slid: the focus moved, the picture with it, and the view did not turn.
const after = await view();
const panned = focusMoved(start, after);
const turned = Math.abs(after.yaw - start.yaw) + Math.abs(after.pitch - start.pitch);
const panChanged = differ(beforePan, await frameOf());
check(`H, the Pan tool, slides it (${(await state()).mode}; ${panned.toFixed(1)} LDU at ${after.distance.toFixed(0)} back, turned ${turned.toFixed(3)} rad, the picture changed ${panChanged.toFixed(1)})`,
  (await state()).mode === "pan" && panned > 5 && turned < 0.001 && panChanged > 2);
await key("KeyZ");
start = await view();
await drag(spot(0, 0), spot(0, 100));
check(`Z, the Zoom tool, zooms it (${(await state()).mode})`,
  (await state()).mode === "zoom" && Math.abs((await view()).distance - start.distance) > 20);
// With a view tool on, a click on the toolbar or a panel still presses what
// it is on. The sheet that keeps a drag's pointer over the panels went up
// for the Orbit and Pan tools' pointers whenever the tool was on, and every
// click turned the view instead (brickworks.diy at 91ae209, 2026-10-12).
for (const [press, tool] of [["KeyO", "orbit"], ["KeyH", "pan"], ["KeyZ", "zoom"]]) {
  await key(press);
  await page.mouse.move(spot(0, 0).x, spot(0, 0).y, { steps: 3 });
  await wait(400);
  await click(await controlAt("tool_mode_paint"));
  check(`with ${tool} on, a click on Paint on the toolbar presses it (${(await state()).mode})`,
    (await state()).mode === "paint");
  await key(press);
  await openColumnFor(page, "first part");
  await page.mouse.move(spot(0, 0).x, spot(0, 0).y, { steps: 3 });
  await wait(400);
  await click(await controlAt("first part"));
  check(`...and a click on a part in the parts bin takes it (${(await state()).mode})`,
    (await state()).mode === "place");
  await key("Escape");
}
await key("KeyZ");
await key("Escape");
check(`Esc is back to Select (${(await state()).mode})`, (await state()).mode === "select");
await nothingPlaced();

console.log("  the view cube");
// From the usual view, where the cube shows its top, front and a side.
await key("Digit0");
await wait(1500);
const top = (await controls()).cube_top;
console.log(`    the cube's faces in view: ${Object.keys(await controls()).filter((n) => n.startsWith("cube_")).join(", ")}`);
if (top) {
  await click(top);
  check(`a click on the cube's top looks down on the model (tilt ${(await view()).pitch.toFixed(2)})`,
    (await view()).pitch > 1.2);
} else {
  check("the cube shows its top", false);
}
start = await view();
await click(await controlAt("cube_turn_right"));
check("its right arrow turns the view a step", Math.abs((await view()).yaw - start.yaw) > 0.1);
start = await view();
const pad = await controlAt("cube_pan");
await drag(pad, { x: pad.x + 40, y: pad.y + 10 });
check("dragging its pad slides the view", focusMoved(start, await view()) > 2);
start = await view();
await click(await controlAt("cube_zoom_in"));
check("its + zooms in", (await view()).distance < start.distance);
await nothingPlaced("by the cube");
await shot("cube");

console.log("  zoom to a part, and fit");
await key("Digit0");
await key("KeyF");
start = await view();
await wheel(spot(0, 0), 0, -8, 12, { hold: ["Control"] });
check(`a pinch on a part zooms to it (${start.distance.toFixed(0)} to ${(await view()).distance.toFixed(0)})`,
  (await view()).distance < start.distance * 0.8);
await shot("zoomed");
start = await view();
await click(await controlAt("tool_fit"));
check(`Fit shows the whole model again (${start.distance.toFixed(0)} to ${(await view()).distance.toFixed(0)})`,
  (await view()).distance > start.distance * 1.1);
await nothingPlaced();

console.log("  with a part in hand, a drag still only moves the view");
await key("KeyQ");
check(`Q takes a part into hand (${(await state()).mode})`, (await state()).mode === "place");
start = await view();
await drag(spot(-100, 60), spot(80, 60));
check(`a left drag with it in hand turns the view (${((await view()).yaw - start.yaw).toFixed(2)} rad)`,
  Math.abs((await view()).yaw - start.yaw) > 0.3);
start = await view();
await drag(spot(-100, 60), spot(0, 20), { hold: ["Shift"] });
check("...Shift and a drag slide it", focusMoved(start, await view()) > 5);
await nothingPlaced("with a part in hand");
check(`...and the part is still in hand (${(await state()).mode}, ${(await state()).held})`,
  (await state()).mode === "place");
await shot("in_hand");

console.log("  three bricks put down, and one selected");
await key("Digit0");
await key("KeyF");
await wait(800);
const placed = [];
const tries = [spot(-220, 160), spot(-160, 170), spot(-100, 180), spot(200, 160), spot(260, 150),
  spot(-260, 100), spot(240, 100), spot(0, 200)];
for (const where of tries) {
  if (placed.length === 3) break;
  const before = (await state()).bricks;
  await page.mouse.move(where.x - 3, where.y, { steps: 2 });
  await wait(300);
  await click(where);
  if ((await state()).bricks === before + 1) placed.push(where);
}
check(`three clicks with the part in hand put down three bricks (${(await state()).bricks - bricks} new, ${inputs} inputs so far)`,
  placed.length === 3 && (await state()).bricks === bricks + 3);
await key("Escape");
if (placed.length > 0) {
  await click({ x: placed[0].x, y: placed[0].y - 4 });
  check(`a click selects one (${(await state()).selected} selected, ${(await state()).mode})`,
    (await state()).selected >= 1 && (await state()).mode === "select");
}
await shot("placed");

writeFileSync(`${out}/nav_${ratio}x.json`, JSON.stringify({ ratio, inputs, log }, null, 2));
await browser.close();
console.log(failed === 0
  ? `nav flow (${ratio}x): all the way round, slid, zoomed, fitted and three bricks down with the left button alone, ${inputs} inputs`
  : `nav flow (${ratio}x): ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
