// The landing page's pictures of the app, taken from a real deployment.
//
//   node tools/web/app_shot.mjs --url=https://brickworks.diy/app --out=web/_shot-app.png
//   BW_BYPASS=… node tools/web/app_shot.mjs --url=<a preview>/app --out=…
//   node tools/web/app_shot.mjs --ratio=2 --model=res://models/castle.ldr \
//       --menu=menu_view:Key --click=outliner --fold=assistant --out=shots/site/hero.png
//   node tools/web/app_shot.mjs --ratio=2 --plan=shots.json
//
// Opens a model (--model, the castle by default) on a clean browser, so the
// panels are what a first visit sees. --ratio is the device pixel ratio (2
// for a picture that stays sharp on a high-density screen: the app draws its
// interface and the 3D at the page's full resolution); --width and --height
// the window in CSS pixels (1600 x 900, the size the app is laid out for).
// --fold=assistant or --fold=parts closes that column by its rail, for more
// of the model; --menu=CONTROL:WORD opens a menu by its control and picks
// the item that word starts (menu_view:Key turns the key strip off); --click
// presses controls by name, in order (the app publishes where they are, see
// main._tell_page).
//
// --plan=FILE takes several pictures in one run, one after another in the
// same browser: a JSON list of objects with the same keys (model, fold,
// menu, click, settle, after, out). On a busy machine the wait for a turn
// to run is most of the cost, and this pays it once.
//
// Why it exists: the picture at the top of the landing page was taken once,
// by hand, on 19 September, and was still there three weeks later showing a
// toolbar, a panel and a "Sign out" that the app no longer had. A picture
// that can only be retaken by hand is retaken when someone notices.
import { readFileSync } from "node:fs";
import { controlsWith, launch } from "./browser.mjs";

const args = {};
for (const a of process.argv.slice(2)) {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  const value = rest.join("=") || true;
  args[k] = k in args ? [].concat(args[k], value) : value;
}
const url = args.url || "https://brickworks.diy/app";
const ratio = Number(args.ratio || 1);
const width = Number(args.width || 1600);
const height = Number(args.height || 900);
const plan = args.plan ? JSON.parse(readFileSync(args.plan, "utf8")) : [args];

const browser = await launch();

async function take(shot) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: ratio });
  const query = [`model=${shot.model || "res://models/castle.ldr"}`];
  if (process.env.BW_BYPASS) {
    query.push(`x-vercel-protection-bypass=${process.env.BW_BYPASS}`,
      "x-vercel-set-bypass-cookie=true");
  }
  await page.goto(`${url}${url.includes("?") ? "&" : "?"}${query.join("&")}`,
    { waitUntil: "domcontentloaded", timeout: 120000 });

  // The app is up when it has said where its controls are.
  const until = Date.now() + 300000;
  while (!(await page.evaluate(() => Boolean(window.brickworksControls)))) {
    if (Date.now() > until) throw new Error("the app never came up");
    await page.waitForTimeout(1000);
  }
  // Long enough for a big model to finish loading and the camera to settle
  // on it, which nothing on the page announces.
  await page.waitForTimeout(Number(shot.settle || 30000));

  const pause = Number(shot.pause || 4000);
  // Each control waited for, as a person waits for a menu or a panel: one
  // is told to the page only once it has stayed where it is drawn.
  const where = async (name) => (await controlsWith(page, [name]))[name];
  async function press(name) {
    const at = await where(name);
    if (!at) throw new Error(`the app is not showing "${name}"`);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(pause);
  }
  for (const pick of [].concat(shot.menu || [])) {
    const [control, word] = pick.split(":");
    const at = await where(control);
    if (!at) throw new Error(`the app is not showing "${control}"`);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(1500);
    await page.keyboard.type(word, { delay: 120 });
    await page.waitForTimeout(600);
    await page.keyboard.press("Enter");
    await page.waitForTimeout(pause);
  }
  for (const column of [].concat(shot.fold || [])) {
    const open = await page.evaluate((c) => ((window.brickworksState || {}).columns || {})[c], column);
    if (open !== false) await press(`${column}_rail`);
  }
  for (const name of [].concat(shot.click || [])) await press(name);
  // The pointer off the canvas, so no part is outlined under it.
  await page.mouse.move(width - 2, height - 2);
  await page.waitForTimeout(Number(shot.after || 8000));
  const out = shot.out || "shots/app.png";
  await page.screenshot({ path: out, timeout: 180000 });
  await page.close();
  console.log(`wrote ${out} (${width * ratio} x ${height * ratio})`);
}

let failed = 0;
for (const shot of plan) {
  try {
    await take(shot);
  } catch (trouble) {
    failed += 1;
    console.log(`FAIL ${shot.out}: ${trouble.message.split("\n")[0]}`);
  }
}
await browser.close();
process.exit(failed ? 1 : 0);
