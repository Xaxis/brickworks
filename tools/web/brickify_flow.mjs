// Brickify a 3D model in a real browser: an OBJ brought in through the
// page's own file chooser, its size typed in, Brickify pressed, and the
// model placed as a sub-assembly named after the file.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/brickify_flow.mjs --url=https://<a preview>/app --out=shots/brickify_web
//   node tools/web/brickify_flow.mjs --url=http://127.0.0.1:8147/index.html --out=…   (a local export)
//
// Presses I (a key is a press a browser lets open its file chooser), answers
// the chooser with tests/fixtures/brickify/bunny.obj, photographs the panel
// with the bunny turning in it, types 30 into the size box, presses
// Brickify and waits for it to land. It fails if a control never appears,
// no chooser comes up, the bunny does not arrive as the sub-assembly
// "bunny#1" holding every part placed (window.brickworksState.tree), it is
// not all selected, or a script error reaches the console. The web build
// works it out on a worker (BrickifyDialog), so the page goes on drawing
// meanwhile: the frames are timed while it works.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
// A preview sits behind Vercel's login; with BW_BYPASS the first load
// carries the bypass and sets its cookie, so the pack and the parts answer.
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/brickify_web";
mkdirSync(out, { recursive: true });
const model = resolve(args.model || "tests/fixtures/brickify/bunny.obj");
const studs = String(args.studs || 30);

const browser = await launch();
const errors = [];
const said = [];
const t0 = Date.now();
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
// Choosers are caught by a listener there from the start (studio_flow.mjs
// says why).
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) errors.push(m.text().slice(0, 300));
});

const controls = () => page.evaluate(() => window.brickworksControls || {});
const state = () => page.evaluate(() => window.brickworksState || null);
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 120000 });
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds, what) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await page.waitForTimeout(500);
  }
  await shot(`never_${what.replace(/\W+/g, "_")}.png`);
  return false;
}
async function where(name, seconds = 120) {
  if (!(await until(async () => Boolean((await controls())[name]), seconds, name))) {
    throw new Error(`the app never showed "${name}"`);
  }
  return (await controls())[name];
}
async function click(name) {
  const at = await where(name);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await until(async () => Boolean((await controls()).open), 400, "app"), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));

// I, with the pointer over the model so the key goes to the canvas; tried
// again if no chooser came, since the app reads a key at its next frame and
// a software frame can take seconds.
const view = await where("view");
let chooser = null;
for (let n = 0; n < 3 && !chooser; n++) {
  page.choosers.length = 0;
  await page.mouse.move(view.x, view.y);
  await page.keyboard.press("i");
  for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
  chooser = page.choosers.shift() || null;
}
ok(Boolean(chooser), "I brings up the page's file chooser");
if (chooser) await chooser.setFiles(model);
const panel = await until(async () => Boolean((await controls()).brickify_go), 120, "panel");
ok(panel, `the Brickify panel comes up for ${model.split("/").pop()}`);
await page.waitForTimeout(6000);
await shot("1_panel.png");

const box = await where("brickify_studs");
await page.mouse.click(box.x, box.y);
await page.keyboard.press("Control+A");
await page.keyboard.type(studs, { delay: 60 });
await page.keyboard.press("Enter");
await page.waitForTimeout(2000);
await shot("2_sized.png");

const before = (await state())?.bricks || 0;
await click("brickify_go");
// The frames while it works: a worker does the work, so they keep coming.
const frames = await page.evaluate(() => new Promise((done) => {
  const times = [];
  let last = performance.now();
  const tick = (now) => {
    times.push(now - last);
    last = now;
    if (times.length < 20) requestAnimationFrame(tick);
    else done(times);
  };
  requestAnimationFrame(tick);
}));
const longest = Math.round(Math.max(...frames));
const landed = await until(async () => {
  const s = await state();
  return s && s.tree && s.tree["bunny#1"] && !(await controls()).brickify_go;
}, 600, "landed");
const s = await state();
const parts = (s?.bricks || 0) - before;
// The tree lists each sub-assembly's own parts by number, "3001,3004".
const inside = String(s?.tree?.["bunny#1"] || "").split(",").filter(Boolean).length;
ok(landed && parts > 300 && inside === parts,
  `it lands as the sub-assembly bunny#1: ${parts} parts placed, ${inside} of them in it, the tree ${Object.keys(s?.tree || {})}`);
ok(s?.selected === parts, `all of it selected, to move or turn: ${s?.selected}`);
ok(true, `frames while it worked: the longest ${longest} ms of ${frames.length}`);
await page.waitForTimeout(8000);
await shot("3_placed_selected.png");
await page.mouse.move(view.x, view.y);
await page.keyboard.press("Escape");
await page.waitForTimeout(8000);
await shot("4_placed.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `brickify flow: ${failed} problem(s); screenshots in ${out}`
  : `brickify flow: an OBJ brought in, sized, brickified and placed as a sub-assembly; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
