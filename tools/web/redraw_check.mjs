// A brick moved is drawn where it went, in the browser.
//
//   node tools/web/redraw_check.mjs --url=<preview>/app --bypass=… [--out=shots/redraw]
//
// On the web build of 8e07c69 and on brickworks.diy a brick turned (R),
// mirrored (Shift-M) and nudged (arrows) kept being drawn where it had been
// while its selection outline moved on: the world had moved it, the screen
// had not. Desktop OpenGL drew the same writes; a browser drew a batch's
// instance data only when the batch got a new buffer (BrickWorld._fresh_slots).
// This puts one red brick on an empty baseplate, does that to it, and finds
// the red on the canvas after each step.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/redraw";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });

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
// Where the red is on the canvas, within `reach` of the view's middle: its
// middle and how much of it there is, in page pixels.
async function red(view, reach = 360) {
  return page.evaluate(({ view, reach }) => {
    const canvas = document.querySelector("canvas");
    const scale = canvas.width / canvas.clientWidth;
    const probe = document.createElement("canvas");
    probe.width = canvas.width;
    probe.height = canvas.height;
    const ctx = probe.getContext("2d");
    ctx.drawImage(canvas, 0, 0);
    const x0 = Math.max(0, Math.round((view.x - reach) * scale));
    const y0 = Math.max(0, Math.round((view.y - reach) * scale));
    const w = Math.min(canvas.width - x0, Math.round(2 * reach * scale));
    const h = Math.min(canvas.height - y0, Math.round(2 * reach * scale));
    const { data } = ctx.getImageData(x0, y0, w, h);
    let sx = 0, sy = 0, count = 0;
    for (let y = 0; y < h; y += 2) {
      for (let x = 0; x < w; x += 2) {
        const i = (y * w + x) * 4;
        if (data[i] > 115 && data[i + 1] < 50 && data[i + 2] < 50) {
          sx += x; sy += y; count += 1;
        }
      }
    }
    if (count === 0) return { x: -1, y: -1, count: 0 };
    return { x: (x0 + sx / count) / scale, y: (y0 + sy / count) / scale, count };
  }, { view, reach });
}
const wait = (ms) => page.waitForTimeout(ms);
let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}
const fmt = (p) => `(${Math.round(p.x)}, ${Math.round(p.y)}; ${p.count})`;

await controlAt("model_name");
await wait(8000);
const fresh = await controlAt("new");
await page.mouse.click(fresh.x, fresh.y);
await wait(1500);
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) {
  await page.keyboard.press("Enter");
  await wait(1500);
}
const view = await controlAt("view");
// A red brick in hand (Q takes the last part, red by default), put down in
// the middle, and Escape back to Select.
await page.mouse.move(view.x, view.y + 40, { steps: 3 });
await page.keyboard.press("q");
await wait(800);
await page.mouse.move(view.x + 1, view.y + 40, { steps: 2 });
await wait(400);
await page.mouse.click(view.x + 1, view.y + 40);
await wait(1200);
await page.keyboard.press("Escape");
await wait(800);
check(`one brick on the baseplate (${(await state()).bricks})`, (await state()).bricks === 1);
// Off the brick, so the pointer's highlight is not what moves.
await page.mouse.move(view.x + 300, view.y + 250, { steps: 3 });
await wait(1500);
const put = await red(view);
await page.screenshot({ path: `${out}/1_put.png` });
check(`it is drawn ${fmt(put)}`, put.count > 50);

await page.keyboard.press("Control+a");
await wait(800);
const steps = [["r", "turned"], ["Shift+M", "mirrored"], ["ArrowRight", "nudged once"],
  ["ArrowRight", "nudged twice"], ["ArrowRight", "nudged three times"]];
let was = put;
const seen = [put];
for (const [press, name] of steps) {
  await page.keyboard.press(press);
  await wait(2500);
  const now = await red(view);
  seen.push(now);
  await page.screenshot({ path: `${out}/${seen.length}_${name.replace(/\W+/g, "_")}.png` });
  console.log(`    ${name}: red at ${fmt(now)}`);
  was = now;
}
// Nothing selected, so only the brick is drawn red-ish where it is.
await page.keyboard.press("Escape");
await wait(2500);
const last = await red(view);
await page.screenshot({ path: `${out}/9_let_go.png` });
const travelled = Math.hypot(last.x - put.x, last.y - put.y);
check(`three studs to the right, the red moved with it ${fmt(put)} -> ${fmt(last)}, ${Math.round(travelled)} px`,
  travelled > 25 && last.count > 50);
// And the world agrees it moved.
const now = await state();
console.log(`  state: ${JSON.stringify({ bricks: now.bricks, mode: now.mode })}`);

await browser.close();
console.log(failed === 0 ? "redraw: a moved brick is drawn where it went" : `redraw: ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
