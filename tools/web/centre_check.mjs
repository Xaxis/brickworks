// Is the model in the middle of the room it has, and does a click there find
// the part drawn under it?
//
//   node tools/web/centre_check.mjs --url=<preview>/app --bypass=… [--out=shots/centre]
//
// The 3D draws across the whole page, behind the columns, and the view was
// centred on the page: in a laptop's window, with one column open, the model
// sat 168 units to the side of its own column. The lens is now shifted to the
// middle of the model's part of the page (CadCamera.seen). The first try at
// that drew the model in the right place and then missed every click, because
// Godot's ray from the screen assumes a centred lens. So this looks and
// clicks, in a 1280 x 720 window at one and two device pixels to the point,
// with each column folded in turn:
//
//   - after Fit (F), the middle of the model (brickworksLayout.centre, where
//     the build draws the middle of what is built) is within 2% of the middle
//     of the model's part of the page (brickworksLayout.view);
//   - five parts the build names (brickworksLayout.targets: a point on each
//     one's top that a straight line from the eye reaches first, chosen in
//     the world, not through the screen), each clicked with Select, select
//     exactly that part (brickworksState.selection).
//
// A build from before the shift fails the first: the model's middle is about
// 18% of the view's width to the side.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/centre";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}

const browser = await launch();
for (const ratio of [1, 2]) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: ratio });
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  const slow = ratio > 1 ? 2 : 1;
  const wait = (ms) => page.waitForTimeout(ms * slow);
  const state = () => page.evaluate(() => window.brickworksState || {});
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  // What the page says once the app has said it again since now.
  async function fresh() {
    const was = (await state()).now || 0;
    for (let n = 0; n < 50; n++) {
      await page.waitForTimeout(100);
      const now = await state();
      if ((now.now || 0) > was) return now;
    }
    return state();
  }
  async function controlAt(name, seconds = 400) {
    for (let n = 0; n < seconds * 2; n++) {
      const where = await controls();
      if (where[name]) return where[name];
      await page.waitForTimeout(500);
    }
    throw new Error(`the app never showed "${name}"`);
  }
  async function key(name) {
    await page.keyboard.press(name);
    await wait(500);
    await fresh();
  }
  async function click(at) {
    await page.mouse.move(at.x, at.y, { steps: 3 });
    await wait(300);
    await page.mouse.click(at.x, at.y, { button: "left" });
    await wait(600);
    return fresh();
  }
  async function layout() {
    await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
    for (let n = 0; n < 40; n++) {
      const said = await page.evaluate(() => window.brickworksLayout || null);
      if (said) return said;
      await page.waitForTimeout(250);
    }
    return null;
  }

  await controlAt("model_name");
  await wait(8000);
  await key("Escape");
  const columns = (await state()).columns || {};
  console.log(`  ${ratio}x: 1280 x 720, ${(await state()).bricks} parts, columns ${columns.share}`);

  for (const folded of ["assistant", "parts"]) {
    const keep = folded === "assistant" ? "parts" : "assistant";
    // In a window with room for one column, opening the one kept folds the
    // other; with room for both, the other's own rail folds it.
    for (let n = 0; n < 2; n++) {
      const open = (await state()).columns || {};
      if (open[keep] === false) await click(await controlAt(`${keep}_rail`));
      else if (open[folded] === true) await click(await controlAt(`${folded}_rail`));
      else break;
      await wait(1500);
    }
    const now = (await state()).columns || {};
    check(`${ratio}x: the ${folded} folded and the ${keep} open`, now[folded] === false && now[keep] === true);
    await key("Escape");
    await key("KeyF");
    await wait(1500);
    const seen = await layout();
    if (!seen || !seen.centre) {
      check(`${ratio}x, ${folded} folded: the build says where the model's middle is drawn`, false);
      continue;
    }
    const [x, y, w, h] = seen.view;
    const dx = seen.centre.x - (x + w / 2);
    const dy = seen.centre.y - (y + h / 2);
    check(`${ratio}x, ${folded} folded: after Fit the model's middle is ${(100 * Math.abs(dx) / w).toFixed(1)}% across and ${(100 * Math.abs(dy) / h).toFixed(1)}% down from the middle of its part of the page [${seen.view}]`,
      Math.abs(dx) <= 0.02 * w && Math.abs(dy) <= 0.02 * h);
    const targets = seen.targets || [];
    let picked = 0;
    const said = [];
    for (const target of targets) {
      const after = await click(target);
      const chosen = after.selection || [];
      if (chosen.length === 1 && chosen[0] === target.brick) picked += 1;
      else said.push(`part ${target.brick} at ${target.x},${target.y} chose [${chosen}]`);
    }
    check(`${ratio}x, ${folded} folded: a click on each of ${targets.length} parts selects exactly that part (${picked})${said.length ? ": " + said.join("; ") : ""}`,
      targets.length === 5 && picked === targets.length);
    await key("Escape");
    await page.screenshot({ path: `${out}/${ratio}x_${folded}_folded.png`, timeout: 120000 }).catch(() => {});
  }
  await page.close();
}
await browser.close();
console.log(failed === 0
  ? "centre check: the model in the middle of its part of the page after Fit, and every click on the part drawn there, at 1x and 2x with either column folded"
  : `centre check: ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
