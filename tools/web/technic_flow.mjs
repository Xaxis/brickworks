// Technic by hand in the browser, as a person builds it: a beam on the
// baseplate, two pins into its holes, a second beam onto both pins, an axle
// through the second beam's free hole with a gear on its top, and a bar in a
// round brick's hollow stud with a clip on the bar.
//
//   node tools/web/technic_flow.mjs --url=<preview>/app --bypass=… [--ratio=2] [--out=shots/technic_web]
//
// Every step is a click or a key: a part taken from the bin by its number,
// the pointer moved onto the connector where the page says it is
// (window.brickworksState.joints, each connector's middle on the page), a
// click. What happened is read back off the app: whether the ghost was on a
// joint and allowed (brickworksState.on_joint, can_place), what the status
// bar said (hint), and how many parts there are. Pictures at each step, to
// be looked at.
import { launch, withAssistant } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = withAssistant(args.url || "https://brickworks.diy/app");
const out = args.out || "shots/technic_web";
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
async function until(test, seconds = 20) {
  let now = await state();
  for (let n = 0; n < seconds * 2 && !test(now); n++) {
    await page.waitForTimeout(500);
    now = await state();
  }
  return now;
}
async function click(at) {
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await wait(250);
  await page.mouse.click(at.x, at.y);
  await wait(700);
}
async function key(name, ms = 600) {
  await page.keyboard.press(name);
  await wait(ms);
}
async function type(text) {
  await page.keyboard.type(text, { delay: 30 });
  await wait(400);
}

let failed = 0;
let shots = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}
async function shot(name) {
  shots += 1;
  const path = `${out}/${String(shots).padStart(2, "0")}_${name}.png`;
  await page.screenshot({ path, timeout: 120000 }).catch(() => {});
  console.log(`    picture: ${path}`);
}

// Take a part by its number: search, then the first tile.
async function take(number) {
  await click(await controlAt("part search"));
  await key("Control+a", 200);
  await type(number);
  await wait(1500);
  await click(await controlAt("first part"));
  const held = await until((s) => s.mode === "place" && String(s.held || "") === number, 30);
  check(`${number} is in hand (${held.held})`, String(held.held || "") === number);
  return held;
}
// The pointer onto a point, the way a hand comes to rest there, and what
// the app says once the ghost has followed it.
async function hover(at) {
  await page.mouse.move(at.x - 6, at.y + 4, { steps: 4 });
  await wait(300);
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await wait(900);
  return state();
}
// Put what is in hand down at `at`, on the studs.
async function put(at) {
  await hover(at);
  const before = (await state()).bricks;
  await click(at);
  return until((s) => s.bricks > before, 8);
}
// The connectors the page says are there, of one kind, on one part.
async function joints(part, kind) {
  const all = (await state()).joints || [];
  return all.filter((j) => j.part === part && j.kind === kind);
}
// Onto a connector: hover it, say what the ghost says, click if it may go.
async function onto(site, said) {
  const now = await hover(site);
  console.log(`    over ${site.part} ${site.kind} at ${site.x},${site.y}: on a joint ${now.on_joint}, `
    + `may go ${now.can_place}; "${now.hint}"`);
  check(`${said}: the ghost is on the joint and may go`, now.on_joint && now.can_place);
  return now;
}
async function click_down(site) {
  const before = (await state()).bricks;
  await click(site);
  const now = await until((s) => s.bricks > before, 8);
  return now.bricks > before;
}

await controlAt("model_name");
await wait(8000);
const fresh = await controlAt("new");
await page.mouse.click(fresh.x, fresh.y);
await wait(1500);
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) {
  await key("Enter", 1500);
}
const view = await controlAt("view");
const spot = (dx, dy) => ({ x: view.x + dx, y: view.y + dy });

console.log("  two beams joined by pins");
await take("32523");
let now = await put(spot(0, 40));
check(`a Technic beam 3 lies on the baseplate (${now.bricks} parts)`, now.bricks === 1);
await key("Escape");
// The view on what is built, near enough to aim at a hole, and out a
// little so what stands on it stays on the page.
await key("f", 2500);
for (let n = 0; n < 3; n++) await key("Minus", 500);
await take("3673");
let holes = await joints("32523", "pin_hole");
check(`the page says where the beam's three holes are (${holes.length})`, holes.length === 3);
// Along the beam: an end hole, then the middle one.
const line = (a, b) => (b.x - a.x) * (holes[2].x - holes[0].x) + (b.y - a.y) * (holes[2].y - holes[0].y);
holes.sort((a, b) => line(holes[0], a) - line(holes[0], b));
now = await onto(holes[0], "a pin over the beam's end hole");
check(`...and the status bar says it is in the pin hole ("${now.hint}")`,
  String(now.hint).includes("pin hole of Technic Beam"));
await shot("pin_aimed_at_hole");
// R turns it about the hole; Shift-R back.
await key("r", 900);
now = await state();
check(`R turns the pin on its hole and it still may go (${now.on_joint}, ${now.can_place})`,
  now.on_joint && now.can_place);
await shot("pin_turned_on_hole");
await key("Shift+r", 900);
check("a click puts the pin in", await click_down(holes[0]));
now = await onto(holes[1], "a second pin over the middle hole");
check("a click puts it in", await click_down(holes[1]));
await shot("two_pins_in");
await key("Escape");

await take("32523");
let pins = await joints("3673", "pin");
// Each pin has two halves, one in the beam; the free one is the higher on
// the page.
const free = {};
for (const site of pins) {
  if (!free[site.brick] || site.y < free[site.brick].y) free[site.brick] = site;
}
const tops = Object.values(free);
check(`the page says where both pins stand (${tops.length})`, tops.length === 2);
now = await onto(tops[0], "a second beam over a pin");
await shot("beam_aimed_at_pin");
check("a click puts the beam on the pins", await click_down(tops[0]));
const upper = Math.max(...(await joints("32523", "pin_hole")).map((h) => h.brick));
await key("Escape");
await shot("beams_joined");

console.log("  an axle with a gear");
await take("3705");
// The upper beam's hole with no pin in it is the one the axle may go in.
let through = null;
for (const hole of (await joints("32523", "pin_hole")).filter((h) => h.brick === upper)) {
  const s = await hover(hole);
  if (s.on_joint && s.can_place) {
    through = hole;
    break;
  }
}
check(`the upper beam's free hole takes an axle (${JSON.stringify(through)})`, through !== null);
if (through) {
  now = await onto(through, "an axle over the free hole");
  await shot("axle_aimed_at_hole");
  check("a click puts the axle through", await click_down(through));
}
await key("Escape");
// The axle stands four studs up: the view on all of it again, so its top
// is on the page.
await key("f", 2500);
await key("Minus", 500);
await take("3647");
const tips = await joints("3705", "axle");
const top = tips.sort((a, b) => a.y - b.y)[0];
check(`the page says where the axle's tips are (${tips.length})`, tips.length === 2);
if (top) {
  now = await onto(top, "a gear over the axle's top");
  await shot("gear_aimed_at_axle");
  check("a click puts the gear on", await click_down(top));
}
await key("Escape");
await shot("axle_and_gear");

console.log("  a clip on a bar");
await take("3062b");
now = await put(spot(-160, 60));
await key("Escape");
await take("30374");
const stud = (await joints("3062b", "bore"))[0];
check(`the page says where the hollow stud is (${JSON.stringify(stud)})`, stud !== undefined);
if (stud) {
  now = await onto(stud, "a bar over the hollow stud");
  await shot("bar_aimed_at_stud");
  check("a click stands the bar in it", await click_down(stud));
}
await key("Escape");
await take("4085c");
const bar = (await joints("30374", "shaft"))[0];
check(`the page says where the bar is (${JSON.stringify(bar)})`, bar !== undefined);
if (bar) {
  now = await onto(bar, "a clip over the bar");
  check(`...and the status bar says it is on the bar ("${now.hint}")`, String(now.hint).includes("bar of"));
  await shot("clip_aimed_at_bar");
  check("a click puts the clip on", await click_down(bar));
}
await key("Escape");
await key("f", 2500);
now = await state();
check(`nine parts in all (${now.bricks})`, now.bricks === 9);
await shot("finished");

await browser.close();
console.log(failed === 0
  ? `technic flow (${ratio}x): two beams joined by pins, an axle with a gear and a clip on a bar, built by hand`
  : `technic flow (${ratio}x): ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
