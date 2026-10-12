// Draw a print and sculpt a mould in the figure builder, in a real browser,
// wear them, place the figure, and find them all still there after a reload.
//
//   node tools/web/print_flow.mjs --url=http://127.0.0.1:8147/index.html --out=shots/print_web
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/print_flow.mjs --url=https://<a preview>/app --out=…
//
// Presses M; in the Head slot "Draw a print…", draws a face on the canvas
// with the mouse — two eyes in one mirrored dab, a grin — and saves it; in
// the Torso slot draws a badge and saves it; in the Headgear slot "Make a
// mould…" and pulls the hair's top up with the mouse and saves it; places
// the figure; reloads the page. The web build draws with the Compatibility
// renderer (WebGL 2), keeps made parts and their pictures in IndexedDB and
// builds them in GDScript compiled to WebAssembly, so this is the path the
// desktop probes cannot vouch for. It fails if a control never appears, if a
// save does not add a part made here (window.brickworksState.custom), if the
// figure does not go down with those parts in it (window.brickworksBricks),
// if after a reload the parts made here are gone, or if a script error
// reaches the console — a print shader that does not compile on WebGL says
// so there.
//
// Driven by position, as minifig_flow.mjs is: the app publishes where its
// controls are (window.brickworksControls). The canvas and the sculpting
// view are published as their middles; a face is drawn round the middle.
// Serve a local export with --parts, as element_flow.mjs says.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
// A preview sits behind Vercel's login; with BW_BYPASS (the project's
// VERCEL_BYPASS) the first load carries the bypass and sets its cookie, so
// the pack, the parts and the API answer too.
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/print_web";
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader/i.test(m.text())
      && !/warning/i.test(m.text())) errors.push(m.text().slice(0, 300));
});

const state = () => page.evaluate(() => window.brickworksState || null);
const controls = () => page.evaluate(() => window.brickworksControls || {});
const said = [];
const t0 = Date.now();
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};
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
async function click(name, seconds = 120) {
  const at = await where(name, seconds);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}
// A stroke through points, in small steps as a hand moves.
// Each step is a frame of the app's on SwiftShader, which under load can
// take seconds, so long sweeps go in few steps.
async function stroke(points, button = "left", steps = 6) {
  await page.mouse.move(points[0][0], points[0][1]);
  await page.mouse.down({ button });
  for (let n = 1; n < points.length; n++) {
    await page.mouse.move(points[n][0], points[n][1], { steps });
  }
  await page.mouse.up({ button });
  await page.waitForTimeout(800);
}
const custom = async () => (await state())?.custom || [];

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await until(async () => Boolean((await controls()).make_part || (await controls()).parts_rail
  || Object.keys(await controls()).length > 5), 400, "app"), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));

// A face.
await page.mouse.move(700, 120);
await page.keyboard.press("m");
await click("minifig_head");
await click("minifig_make");
const canvas = await where("print_canvas");
ok(Boolean(canvas), "Draw a print… opens the canvas");
await page.waitForTimeout(4000);
// From a clean sheet: the figure's head is printed, and the editor starts
// from its print. The eraser over all of it, a broad sweep.
await click("print_tool_eraser");
const size = await where("print_size");
await page.mouse.click(size.x + 60, size.y);
for (let dy = -75; dy <= 75; dy += 50) {
  await stroke([[canvas.x - 240, canvas.y + dy], [canvas.x + 240, canvas.y + dy]], "left", 3);
}
await click("print_tool_brush");
await page.mouse.click(size.x - 40, size.y);
await click("print_ink_0");
await click("print_mirror");
await stroke([[canvas.x - 60, canvas.y - 30], [canvas.x - 58, canvas.y - 30]]);
await click("print_mirror");
const grin = [];
for (let n = 0; n <= 12; n++) {
  const t = n / 12;
  grin.push([canvas.x - 70 + 140 * t, canvas.y + 35 + 25 * Math.sin(Math.PI * t)]);
}
await stroke(grin);
await page.waitForTimeout(3000);
await shot("1_face.png");
const beforeFace = await custom();
await click("print_save");
ok(await until(async () => (await custom()).some((id) => /^bw-3626c-p/.test(id)
  && !beforeFace.includes(id)), 120, "face saved"),
  `Save print made a printed head: [${(await custom()).filter((id) => /^bw-3626c-p/.test(id))}]`);

// A torso badge.
await click("minifig_torso");
await click("minifig_make");
const torso = await where("print_canvas");
await click("print_tool_oval");
await click("print_ink_14");
await stroke([[torso.x + 40, torso.y - 80], [torso.x + 110, torso.y - 10]]);
await click("print_tool_box");
await click("print_ink_1");
await stroke([[torso.x - 120, torso.y + 40], [torso.x - 50, torso.y + 110]]);
await page.waitForTimeout(3000);
await shot("2_torso.png");
await click("print_save");
ok(await until(async () => (await custom()).some((id) => /^bw-973-p/.test(id)), 120, "torso saved"),
  "Save print made a printed torso");

// A mould: the hair's top pulled up.
await click("minifig_headwear");
await click("minifig_make");
const view = await where("mould_view");
ok(Boolean(view), "Make a mould… opens the sculpting view");
await page.waitForTimeout(6000);
await click("mould_tool_grab");
await stroke([[view.x, view.y - 40], [view.x, view.y - 70], [view.x + 5, view.y - 100]]);
await click("mould_tool_pull");
for (let n = 0; n < 4; n++) {
  await stroke([[view.x - 40, view.y - 30], [view.x + 40, view.y - 40]]);
}
await page.waitForTimeout(3000);
await shot("3_mould.png");
await click("mould_save");
ok(await until(async () => (await custom()).some((id) => /^bw-3901-m/.test(id)), 180, "mould saved"),
  "Save mould made a hair piece");
await page.waitForTimeout(5000);
await shot("4_builder.png");

// The figure in the model.
const count = () => page.evaluate(() => window.brickworksBricks || 0);
const before = await count();
await click("minifig_place");
const spot = { x: Number(args.x || 480), y: Number(args.y || 790) };
let after = before;
for (const [dx, dy] of [[0, 0], [170, 20], [320, 20], [-220, 40]]) {
  await page.mouse.move(spot.x + dx - 20, spot.y + dy - 20);
  await page.waitForTimeout(1500);
  await page.mouse.move(spot.x + dx, spot.y + dy);
  await page.waitForTimeout(6000);
  await page.mouse.click(spot.x + dx, spot.y + dy);
  for (let n = 0; n < 40 && after === before; n++) {
    await page.waitForTimeout(500);
    after = await count();
  }
  if (after !== before) break;
}
await page.keyboard.press("Escape");
await page.waitForTimeout(3000);
await shot("5_placed.png");
ok(after - before >= 9, `the figure stands in the model: ${before} parts, then ${after}`);
const made = await custom();

// The autosave runs a few seconds after a change; then the page goes.
await page.waitForTimeout(6000);
await page.reload({ waitUntil: "domcontentloaded" });
ok(await until(async () => Object.keys(await controls()).length > 5, 400, "app again"),
  "the app came back after a reload");
await page.waitForTimeout(Number(args.load || 15000));
const kept = await custom();
const ours = made.filter((id) => /^bw-(3626c|973|3901)-[pm]/.test(id));
ok(ours.length >= 3 && ours.every((id) => kept.includes(id)),
  `the print, the torso and the mould are still made here: [${ours}]`);
ok((await count()) === after, `and the model came back with the figure, ${await count()} parts`);
await shot("6_reloaded.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `print flow: ${failed} problem(s); screenshots in ${out}`
  : `print flow: drawn, sculpted, worn, placed and kept in the browser; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
