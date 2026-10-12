// A person's first ten minutes with the controls, counted.
//
//   node tools/web/controls_flow.mjs --url=<preview>/app --bypass=… [--ratio=2] [--recipe=new|old]
//
// The owner: "it's super awkward to switch between selecting a placed piece
// and placing a new piece ... switching between view controls and orbiting
// and rotation and moving around doesn't follow standard CAD." So these are
// the tasks a person does in their first minutes — place ten parts, select
// one, move it, turn it, orbit, slide, zoom to the pointer, place more,
// rename the model — each done the way the build at --url wants it done
// (--recipe=old is the build before 2026-10-11's controls, where a part was
// always in hand and a right click took one off), each counted in clicks,
// drags and keys, and each checked to have done what it set out to.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/controls";
const ratio = Number(args.ratio || 1);
const recipe = args.recipe || "new";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: ratio });
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
const slow = ratio > 1 ? 2 : 1;

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
function differ(a, b) {
  let total = 0;
  for (let i = 0; i < a.length; i += 1) total += Math.abs(a[i] - b[i]);
  return total / a.length;
}
const wait = (ms) => page.waitForTimeout(ms * slow);

// Each input a person makes, counted as it is made.
let inputs = 0;
const log = [];
async function click(x, y, options = {}) {
  inputs += 1;
  await page.mouse.move(x, y, { steps: 3 });
  await wait(250);
  if (options.modifier) await page.keyboard.down(options.modifier);
  await page.mouse.click(x, y, { button: options.button || "left" });
  if (options.modifier) await page.keyboard.up(options.modifier);
  await wait(500);
}
async function drag(from, to, options = {}) {
  inputs += 1;
  await page.mouse.move(from.x, from.y, { steps: 3 });
  await wait(250);
  if (options.modifier) await page.keyboard.down(options.modifier);
  await page.mouse.down({ button: options.button || "left" });
  for (let n = 1; n <= 10; n += 1) {
    await page.mouse.move(from.x + (to.x - from.x) * n / 10, from.y + (to.y - from.y) * n / 10);
    await wait(60);
  }
  await page.mouse.up({ button: options.button || "left" });
  if (options.modifier) await page.keyboard.up(options.modifier);
  await wait(800);
}
async function key(name) {
  inputs += 1;
  await page.keyboard.press(name);
  await wait(400);
}
async function type(text) {
  inputs += 1; // typing the name is one act, however long the name
  await page.keyboard.type(text, { delay: 25 });
  await wait(300);
}

let failed = 0;
async function task(name, doIt, proved) {
  const before = inputs;
  const was = { frame: await frameOf(), state: await state() };
  await doIt();
  await wait(1200);
  const now = { frame: await frameOf(), state: await state() };
  const ok = await proved(was, now);
  const took = inputs - before;
  log.push({ task: name, inputs: took, ok });
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${name}: ${took} input${took === 1 ? "" : "s"}`);
  if (!ok) failed += 1;
  await page.screenshot({ path: `${out}/${String(log.length).padStart(2, "0")}_${name.replace(/\W+/g, "_")}.png`, timeout: 120000 })
    .catch(() => {});
}

await controlAt("model_name");
await wait(8000);
// From an empty baseplate, as a new model starts.
const fresh = await controlAt("new");
await page.mouse.click(fresh.x, fresh.y);
await wait(1500);
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) {
  await page.keyboard.press("Enter");
  await wait(1500);
}
const view = await controlAt("view");
const box = page.viewportSize();
// Ten places on the baseplate, in two rows in front of the middle.
const spots = [];
for (let row = 0; row < 2; row += 1) {
  for (let n = 0; n < 5; n += 1) spots.push({ x: view.x - 240 + n * 120, y: view.y + 60 + row * 110 });
}
const moved = { x: spots[0].x + 60, y: spots[0].y - 70 };
const sky = { x: view.x, y: Math.round(box.height * 0.18) };

if (recipe === "new") {
  await task("take a part", async () => { await key("KeyQ"); },
    async (_was, now) => now.state.mode === "place");
}
await task("place ten parts", async () => {
  for (const at of spots) await click(at.x, at.y);
}, async (was, now) => now.state.bricks === was.state.bricks + 10);
await task("select one", async () => {
  if (recipe === "new") {
    await key("Escape");
    await click(spots[0].x, spots[0].y - 4);
  } else {
    await click(spots[0].x, spots[0].y - 4, { modifier: "Shift" });
  }
}, async (_was, now) => recipe === "old" ? true : now.state.selected >= 1 && now.state.mode === "select");
await task("move it", async () => {
  if (recipe === "new") {
    await drag({ x: spots[0].x, y: spots[0].y - 4 }, moved);
  } else {
    await page.mouse.move(spots[0].x, spots[0].y - 4);
    await key("KeyX");
    await click(moved.x, moved.y);
  }
}, async (was, now) => differ(was.frame, now.frame) > 0.15 && now.state.bricks === was.state.bricks);
await task("turn it", async () => {
  if (recipe === "old") await click(moved.x, moved.y - 4, { modifier: "Shift" });
  await key("KeyR");
}, async (was, now) => differ(was.frame, now.frame) > 0.2);
await task("orbit", async () => {
  await drag(view, { x: view.x + 120, y: view.y }, { button: "right" });
}, async (was, now) => differ(was.frame, now.frame) > 2 && now.state.bricks === was.state.bricks);
await task("slide the view", async () => {
  await drag(view, { x: view.x - 120, y: view.y + 40 },
    recipe === "new" ? { button: "middle" } : { button: "middle", modifier: "Shift" });
}, async (was, now) => differ(was.frame, now.frame) > 2);
await task("zoom to the pointer", async () => {
  inputs += 1;
  await page.mouse.move(spots[3].x, spots[3].y);
  for (let n = 0; n < 3; n += 1) { await page.mouse.wheel(0, -240); await wait(350); }
}, async (was, now) => differ(was.frame, now.frame) > 2);
await key("Digit0"); // back to the usual view; not counted below
inputs -= 1;
await wait(1500);
await task("place three more", async () => {
  if (recipe === "new") await key("KeyQ");
  for (const at of spots.slice(5, 8)) await click(at.x, at.y - 160);
}, async (was, now) => now.state.bricks === was.state.bricks + 3);
await task("rename the model, then turn the view by a key", async () => {
  const field = await controlAt("model_name");
  await click(field.x, field.y);
  await key("Control+A");
  await type("Ten parts");
  await key("Enter");
  // On the old build the name kept the keys whatever came next (Enter, a
  // click on the model, Tab, Escape: tools/web/focus_check.mjs), so this
  // is where it fails there.
  await key("Digit1");
}, async (was, now) => differ(was.frame, now.frame) > 2 && (await page.title()).startsWith("Ten parts"));

const total = log.reduce((sum, entry) => sum + entry.inputs, 0);
writeFileSync(`${out}/counts_${recipe}_${ratio}x.json`, JSON.stringify({ recipe, ratio, total, log }, null, 2));
console.log(`controls flow (${recipe}, ${ratio}x): ${total} inputs in all${failed ? `, ${failed} FAILED` : ""}`);
await browser.close();
process.exit(failed ? 1 : 0);
