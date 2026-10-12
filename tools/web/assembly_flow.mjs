// Sub-assemblies in the browser, as a person builds a small vehicle: a body,
// a wing and a cockpit, each made a named sub-assembly; the wing copied and
// mirrored to the other side; saved, opened again, and one wing changed —
// the other follows it, in its other hand.
//
//   node tools/web/assembly_flow.mjs --url=<preview>/app --bypass=… [--ratio=2] [--out=shots/assembly_web]
//
// Every step is a click or a key on what the page says is where
// (window.brickworksControls), and every result is read back off the app
// (window.brickworksState.tree: each sub-assembly's path and its parts).
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/assembly_web";
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
// Wait until the app's state says so, up to `seconds`.
async function until(test, seconds = 20) {
  let now = await state();
  for (let n = 0; n < seconds * 2 && !test(now); n++) {
    await page.waitForTimeout(500);
    now = await state();
  }
  return now;
}
async function click(at, options = {}) {
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await wait(250);
  if (options.modifier) await page.keyboard.down(options.modifier);
  await page.mouse.click(at.x, at.y, { button: options.button || "left", clickCount: options.count || 1 });
  if (options.modifier) await page.keyboard.up(options.modifier);
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
const tree = async () => (await state()).tree || {};
// Where a sub-assembly's own parts are on the page (brickworksState.places).
const placeOf = async (path) => ((await state()).places || {})[path];
// What the app says after a step, for reading a run back.
async function report(label) {
  const s = await state();
  console.log(`    ${label}: mode ${s.mode}, ${s.selected} selected, editing ${JSON.stringify(s.editing)}, `
    + `${s.bricks} bricks, tree ${JSON.stringify(s.tree)}`);
}
const parts = (entry) => (entry || "").split(",").filter((p) => p);

// Take a part by its number, as a person does: search, then the first tile.
async function take(number) {
  await click(await controlAt("part search"));
  await key("Control+a", 200);
  await type(number);
  await wait(1500);
  await click(await controlAt("first part"));
  // That part, not merely a part: one fetched on demand takes a moment.
  const held = await until((s) => s.mode === "place" && String(s.held || "").startsWith(number), 30);
  if (!String(held.held || "").startsWith(number)) console.log(`    (asked for ${number}, holding ${held.held})`);
  return held;
}
// Put what is in hand down at `at`, nudging the pointer so the ghost is
// aimed there first.
async function put(at) {
  await page.mouse.move(at.x - 2, at.y, { steps: 3 });
  await wait(400);
  await page.mouse.move(at.x, at.y, { steps: 2 });
  await wait(400);
  const before = (await state()).bricks;
  await click(at);
  return until((s) => s.bricks > before, 8);
}
// Name the selection as a sub-assembly: Ctrl-G, the name, Enter.
async function group(name) {
  await key("Control+g", 1200);
  await key("Control+a", 200);
  await type(name);
  await key("Enter", 1200);
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

console.log("  a body, a wing and a cockpit");
// The body: two 2x4 bricks side by side.
await take("3001");
await put(spot(-40, 40));
await put(spot(40, 40));
await key("Escape");
await key("Control+a");
await group("Body");
await report("body");
let now = await tree();
check(`the two bricks are the sub-assembly Body (${JSON.stringify(now)})`,
  parts(now["Body#1"]).length === 2);

// The wing: a right-hand wing plate (41769a, whose left hand is 41770a) on
// the left, and a brick on it.
await take("41769a");
const wingAt = spot(-210, 40);
await put(wingAt);
await take("3004");
await put(spot(-205, 34));
await key("Escape");
// Everything, less the body: a click with shift on it lets the whole of
// it go.
await key("Control+a");
await click(spot(-40, 40), { modifier: "Shift" });
const picked = (await state()).selected;
await group("Wing");
await report("wing");
now = await tree();
check(`...the wedge and the brick on it are Wing (${picked} picked; ${JSON.stringify(now)})`,
  parts(now["Wing#1"]).length === 2);

// The cockpit: one brick on top of the body, made a sub-assembly of its own.
await take("3004");
await put(spot(40, 34));
await key("Escape");
const before = await tree();
await click(spot(40, 22));
await group("Cockpit");
await report("cockpit");
now = await tree();
const cockpit = Object.keys(now).find((p) => p.startsWith("Cockpit"));
check(`...and the brick on top is Cockpit (${JSON.stringify(now)})`,
  cockpit !== undefined && parts(now[cockpit]).length === 1
    && Object.keys(before).filter((p) => !p.includes("/")).length === 2);
await shot("three_named");

console.log("  the wing copied to the other side, mirrored");
await key("Escape");
await click((await placeOf("Wing#1")) || wingAt);
check(`a click on the wing takes all of it (${(await state()).selected})`, (await state()).selected === 2);
await key("Control+d", 1000);
await report("Ctrl-D");
// Low on the right: the properties panel covers the model's top right, and
// a click there is the panel's (its Edit inside, under a selected wing).
const otherSide = spot(150, 60);
await page.mouse.move(otherSide.x - 2, otherSide.y, { steps: 4 });
await wait(500);
await page.mouse.move(otherSide.x, otherSide.y, { steps: 2 });
await wait(500);
await click(otherSide);
await report("put down");
now = await until((s) => Object.keys(s.tree || {}).includes("Wing#2"), 8);
check(`put down, the copy is a second Wing (${JSON.stringify(now.tree)})`,
  parts((now.tree || {})["Wing#2"]).length === 2);
// The copy selected, mirrored where it stands.
if ((await state()).selected !== 2) await click((await placeOf("Wing#2")) || otherSide);
await key("Shift+m", 1500);
await report("Shift-M");
now = await tree();
check(`Shift-M makes it the left wing: the other hand of the wedge (${now["Wing#2"]})`,
  parts(now["Wing#2"]).some((p) => p.startsWith("41770")));
await key("Escape");
await shot("mirrored_copy");

console.log("  saved and opened again");
const field = await controlAt("model_name");
await click(field);
await key("Control+a", 200);
await type("Kit car");
await key("Enter", 1200);
await key("Control+s", 2500);
const saved = await tree();
// A new model, then the saved one back from Open's list: the first saved
// model is the second entry, under "From a file".
await page.mouse.click(fresh.x, fresh.y);
await wait(1500);
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) await key("Enter", 1500);
check(`a new model is empty (${(await state()).bricks})`, (await state()).bricks === 0);
await click(await controlAt("open"));
await key("ArrowDown", 300);
await key("ArrowDown", 300);
await key("Enter", 4000);
now = await until((s) => s.bricks > 0, 20);
const reopened = now.tree || {};
check(`opened again, the same tree (${JSON.stringify(reopened)})`,
  JSON.stringify(Object.keys(reopened).sort()) === JSON.stringify(Object.keys(saved).sort())
    && Object.keys(saved).every((p) => parts(saved[p]).sort().join() === parts(reopened[p]).sort().join()));
check(`...under its name (${await page.title()})`, (await page.title()).startsWith("Kit car"));
await shot("reopened");

console.log("  one wing changed, the other follows");
// A double-click on the first wing edits inside it: where it is now, as
// opening the model framed the view on it afresh.
const wingNow = (await placeOf("Wing#1")) || wingAt;
await click(wingNow, { count: 2 });
await report("double-click");
now = await until((s) => (s.editing || "") !== "", 6);
check(`a double-click edits inside the wing (${now.editing})`, (now.editing || "").startsWith("Wing"));
await shot("editing_inside");
const editing = now.editing;
const other = editing === "Wing#1" ? "Wing#2" : "Wing#1";
await take("3023");
const inside = (await placeOf(editing)) || wingNow;
await put({ x: inside.x, y: inside.y - 6 });
await key("Escape");
await report("plate put down");
now = await tree();
check(`a plate put down goes into ${editing} (${now[editing]})`, parts(now[editing]).length === 3);
check(`...and ${other} has one too (${now[other]})`, parts(now[other]).length === 3);
await shot("other_follows");
await key("Escape");
now = await state();
check(`Escape is out of the wing again (${JSON.stringify(now.editing)})`, !now.editing);

writeFileSync(`${out}/tree_${ratio}x.json`, JSON.stringify({ saved, reopened, last: now.tree }, null, 2));
await browser.close();
console.log(failed === 0
  ? `assembly flow (${ratio}x): three named sub-assemblies, a mirrored copy, saved, reopened, and the copy followed`
  : `assembly flow (${ratio}x): ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
