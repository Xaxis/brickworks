// LDD's .lxf, the cut-away and x-ray, in a real browser, as a person uses
// them: open an LDD model, cut away a tower to its rooms, and x-ray a
// sub-assembly inside it.
//
//   set -a; . ./.env; set +a
//   node tools/web/see_inside_flow.mjs --url=<a preview>/app --bypass=$VERCEL_BYPASS --out=shots/see_inside_web
//
// Opens src/dev/fixtures/49311_test.lxf (saved by LDD 4.3) through Open… >
// From a file, the page's own file picker answered by Playwright, and checks
// its 16 parts came in. Opens Orthanc (models/orthanc.ldr, 8,785 parts) the
// same way; brings the view in on Saruman with the wheel; presses the
// toolbar's cut button and checks the plane is on; clicks the strip's slider
// to put the cut just over his head (window.brickworksState.heights says how
// high he is); double-clicks him and checks that edits inside him — he is in
// a room, and only the cut lets the click reach him; presses I, and checks everything
// else is see-through; takes the cut off with K, and checks a click still
// reaches him through the walls. Every step is a click, a drag or a key on
// what window.brickworksControls says is where, and every result is read
// off window.brickworksState. Pictures of each in --out. It fails if a step
// does not happen or a script error reaches the console.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/see_inside_web";
mkdirSync(out, { recursive: true });
const lxf = resolve("src/dev/fixtures/49311_test.lxf");
const tower = resolve(args.tower || "models/orthanc.ldr");

const t0 = Date.now();
const said = [];
const errors = [];
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) {
    errors.push(m.text().slice(0, 300));
  }
});

const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
    console.log(`        picture: ${out}/${name}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds) {
  let now = await state();
  for (let n = 0; n < seconds * 2; n++) {
    if (test(now)) return now;
    await page.waitForTimeout(500);
    now = await state();
  }
  return test(now) ? now : null;
}
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name}.png`);
  throw new Error(`the app never showed "${name}"`);
}
async function press(name) {
  const at = await where(name);
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await page.waitForTimeout(300);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}
// Open… > From a file, answered with a file. The app reads a click a frame
// or more after the page does, so a press that brought no picker is tried
// again (studio_flow.mjs has the same reason at length).
async function open(file) {
  const at = await where("open");
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
      await picker.setFiles(file);
      return;
    }
    await shot(`no_picker_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}
async function key(name) {
  await page.keyboard.press(name);
  await page.waitForTimeout(1500);
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(Boolean(await where("open", 400)), "the app came up, signed in");
await page.waitForTimeout(Number(args.load || 15000));

// An LDD model. In a browser a part not yet fetched is said to be arriving,
// and the model is opened again once it has, as the status bar tells a
// person to.
let note = null;
for (let attempt = 0; attempt < 3; attempt++) {
  await open(lxf);
  note = await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
  console.log(`        the status bar: "${note ? note.said : (await state()).said}"`);
  if (note && !/arriving/.test(note.said)) break;
  await page.waitForTimeout(20000);
}
ok((await state()).bricks === 16, `49311_test.lxf opened through Open… > From a file: ${(await state()).bricks} parts`);
ok(Boolean(note) && /opened 16 parts/.test(note.said) && !/left out|not in the library/.test(note.said),
  `and the status bar says so, with nothing left out: "${note ? note.said : ""}"`);
await page.waitForTimeout(6000);
await shot("1_lxf.png");

// A tower.
await open(tower);
const big = await until((s) => s.bricks > 8000, 600);
ok(Boolean(big), `the tower opened: ${(await state()).bricks} parts`);
await page.waitForTimeout(20000);
await shot("2_tower.png");
const before = await state();
// The white wizard, in his room two thirds of the way up (renamed with the
// tower, docs/TRADEMARKS.md).
const figure = Object.keys(before.places || {}).find((p) => /^white[ _]wizard/i.test(p))
  || Object.keys(before.places || {})[0];
ok(Boolean(figure), `a figure in it to look for: ${figure}, his parts at heights ${JSON.stringify((before.heights || {})[figure])}`);
// Closer, with the wheel, which zooms to the pointer: framed whole, a figure
// is a few pixels.
const far = before.view.distance;
const aim = before.places[figure];
for (let notch = 0; notch < 10; notch++) {
  await page.mouse.move(aim.x, aim.y + 10, { steps: 2 });
  await page.mouse.wheel(0, -120);
  await page.waitForTimeout(1200);
}
await until((s) => s.view.distance < far * 0.5, 60);
await page.waitForTimeout(4000);
ok((await state()).view.distance < far * 0.5,
  `the wheel brings the view in on him (${Math.round(far)} to ${Math.round((await state()).view.distance)})`);

// Cut away from the toolbar.
await press("tool_cut");
const cut = await until((s) => s.cut && s.cut.on, 120);
ok(Boolean(cut), `the toolbar's cut button cuts it along ${cut ? "XYZ"[cut.cut.axis] : "?"} at ${cut ? Math.round(cut.cut.at) : "?"}`);
await page.waitForTimeout(8000);
await shot("3_cut.png");

// Then down to just over his head — under the ceiling of his room, over
// him. A click on the slider's track puts the cut there, so two clicks
// measure how many LDU a pixel of it is, and a third puts it where it goes:
// three of the app's frames, where a drag a step at a time was dozens, and a
// frame of a close view in a software browser is many seconds.
const slider = await where("cut_slider");
async function clickSlider(x) {
  const before = (await state()).cut.at;
  await page.mouse.move(x, slider.y, { steps: 2 });
  await page.mouse.click(x, slider.y);
  const now = await until((s) => s.cut && Math.abs(s.cut.at - before) > 0.5, 120);
  return now ? now.cut.at : (await state()).cut.at;
}
const left = await clickSlider(slider.x - 60);
const right = await clickSlider(slider.x + 60);
const perPixel = (right - left) / 120;
const over = (before.heights[figure] || [0, 0])[1] + Number(args.headroom || 40);
const aimAt = slider.x - 60 + (over - 10 - left) / perPixel;
const reached = await clickSlider(aimAt);
ok(perPixel > 0 && reached <= over && reached > over - 60,
  `clicks on the slider measure ${perPixel.toFixed(1)} LDU a pixel and put the cut at ${Math.round(reached)}, just over his head (${Math.round(over)})`);
await page.waitForTimeout(6000);
await shot("4a_cut_over_his_head.png");
// A double-click on him edits inside him: the cut is all that lets it reach.
let inside = null;
for (const below of [8, 16]) {
  const place = ((await state()).places || {})[figure];
  if (!place) break;
  await page.mouse.move(place.x, place.y + below, { steps: 3 });
  await page.waitForTimeout(1000);
  await page.mouse.dblclick(place.x, place.y + below);
  inside = await until((s) => (s.editing || "").startsWith(figure), 30);
  if (inside) break;
  await key("Escape");
}
const now = await state();
ok(Boolean(inside), `a double-click reaches him through the cut: editing "${now.editing}"`);
await page.waitForTimeout(4000);
await shot("4_cut_down_to_the_room.png");

// X-ray him.
await key("i");
const xrayed = await until((s) => s.xray > 8000, 240);
ok(Boolean(xrayed), `I draws everything but ${figure} see-through (${(await state()).xray} parts)`);
await page.waitForTimeout(8000);
await shot("5_xray_cut.png");
await key("k");
const whole = await until((s) => s.cut && !s.cut.on, 120);
ok(Boolean(whole), "K takes the cut off, and x-ray stays");
await page.waitForTimeout(10000);
await shot("6_xray.png");
// Through the walls: his place is clicked, and he is what is selected.
await key("Escape");
await until((s) => s.selected === 0, 20);
const place = ((await state()).places || {})[figure];
if (place) {
  await page.mouse.click(place.x, place.y + 8);
  await page.waitForTimeout(3000);
}
const picked = await until((s) => s.selected > 0, 30);
ok(Boolean(picked), `a click goes through the walls to him: ${(await state()).selected} selected`);
await shot("7_picked_through.png");

await browser.close();
for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed === 0
  ? "see inside, in a browser: an LDD model opens, a tower is cut away to a room, and x-ray sees a figure through its walls"
  : `see inside, in a browser: ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
