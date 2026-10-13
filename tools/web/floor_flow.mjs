// What a model stands on, in a real browser: View > Floor switched to no
// floor, the grid floor and a tan 16 x 16 baseplate, a part put down on
// each, and the baseplate made part of the model.
//
//   PARTS_URL=http://127.0.0.1:8761/parts/ tools/export.sh web
//   python3 tools/web/serve.py build/web 8761 --parts assets/generated/parts &
//   node tools/web/floor_flow.mjs --url=http://127.0.0.1:8761/index.html --out=shots/floor_web
//
// Every menu is driven by the keys a person would use in it: the View menu
// clicked, "Floor" typed to find the submenu, the arrow into it, the item's
// first words, Enter. A part is put down with Q (the last part back in hand)
// and a click on the middle of the model's part of the window, which after
// New is the floor. Every result is read off window.brickworksState: the
// floor's words, how many plates are scenery, whether the model has its own
// plate, and how many parts it has. Pictures in --out. It fails if a step
// does not happen or a script error reaches the console.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8761/index.html";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(args.out || "shots/floor_web");
mkdirSync(out, { recursive: true });

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
// A menu, then (for a submenu) its row typed and the arrow into it, then
// the item typed and Enter. Tried again if the state did not change, as a
// click the app read a frame late is.
async function menu(title, path, done) {
  const at = await where(`menu_${title}`);
  for (let n = 0; n < 3; n++) {
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(2000 + 2000 * n);
    // A row is its first words typed, or a number: that many presses of
    // the down arrow from the first row of a submenu, for rows whose words
    // the menu's type-to-find cannot tell apart.
    for (const [index, words] of path.entries()) {
      if (typeof words === "number") {
        for (let k = 0; k < words; k++) {
          await page.keyboard.press("ArrowDown");
          await page.waitForTimeout(250);
        }
      } else {
        await page.keyboard.type(words, { delay: 110 });
      }
      await page.waitForTimeout(700);
      if (index < path.length - 1) {
        await page.keyboard.press("ArrowRight");
        await page.waitForTimeout(1200);
      }
    }
    if (n === 0) await shot(`menu_${path.join("_").replace(/\W+/g, "_")}.png`);
    await page.keyboard.press("Enter");
    const got = await until(done, 30);
    if (got) return got;
    await shot(`no_${path.join("_").replace(/\W+/g, "_")}_${n}.png`);
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(2000);
  }
  return null;
}
// Q, then a click on the middle of the model's part of the window.
async function placeOne(name) {
  const before = (await state()).bricks;
  for (let n = 0; n < 3; n++) {
    const first = await where("view");
    await page.mouse.move(first.x, first.y + 40);
    await page.keyboard.press("q");
    // A part in hand brings the parts bin out, and in a window with room
    // for one column the model's part of the window moves: aimed again.
    await page.waitForTimeout(3500);
    const view = await where("view");
    await page.mouse.move(view.x + 3, view.y + 42, { steps: 4 });
    await page.waitForTimeout(1500);
    await page.mouse.click(view.x + 3, view.y + 42);
    const got = await until((s) => s.bricks === before + 1, 30);
    if (got) {
      await page.keyboard.press("Escape");
      await page.waitForTimeout(1500);
      await shot(name);
      return got;
    }
  }
  await shot(`not_${name}`);
  return null;
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(Boolean(await where("menu_view", 400)), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));
await shot("0_first_visit.png");
const opening = await state();
ok(/^BASEPLATE /.test(opening.floor || "") && opening.scenery >= 1,
  `a first visit stands on a baseplate, as before (${opening.floor}, ${opening.scenery} plate)`);

// File > New: an empty model on the floor new models start on.
const fresh = await menu("file", ["New"], (s) => s.bricks === 0);
ok(Boolean(fresh), `File > New: an empty model (${(await state()).bricks} parts, ${(await state()).floor})`);

const floors = [
  [["Floor", "No floor"], (s) => s.floor === "NONE" && s.scenery === 0, "no floor, no plate"],
  [["Floor", "Grid"], (s) => s.floor === "GRID" && s.scenery === 0, "the grid floor, no plate"],
  [["Floor", 0], (s) => /^BASEPLATE 16 16 /.test(s.floor) && s.scenery === 1,
    "a 16 x 16 baseplate, the submenu's first row"],
];
let count = 0;
for (const [index, [path, done, words]] of floors.entries()) {
  const now = await menu("view", path, done);
  ok(Boolean(now), `View > Floor: ${words} (${(await state()).floor}, ${(await state()).scenery} plates)`);
  const placed = await placeOne(`${index + 1}_${String(path[1]).replace(/\W+/g, "_").toLowerCase()}.png`);
  count += 1;
  ok(Boolean(placed) && placed.bricks === count, `...and a part goes down on it with a click (${(await state()).bricks} parts)`);
}

// The colour, then the baseplate made part of the model.
const tan = await menu("view", ["Floor", 4, "Tan"], (s) => / 19$/.test(s.floor || ""));
ok(Boolean(tan), `View > Floor > Baseplate colour > Tan (${(await state()).floor})`);
const parts = (await state()).bricks;
const owned = await menu("view", ["Floor", 7], (s) => s.own_plate === true);
ok(Boolean(owned) && owned.scenery === 0 && owned.bricks === parts + 1,
  `View > Floor > The baseplate is part of the model: ${owned ? owned.bricks : "?"} parts, `
  + `${owned ? owned.scenery : "?"} plates of scenery`);
await page.waitForTimeout(3000);
await shot("5_part_of_the_model.png");

await browser.close();
for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
writeFileSync(`${out}/result.txt`, said.join("\n") + "\n");
console.log(failed
  ? `floor flow: ${failed} problem(s); screenshots in ${out}`
  : `floor flow: no floor, the grid and a tan baseplate chosen from View > Floor, a part put down on each, and the plate made part of the model; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
