// Sections in the browser, by clicks and keys: a real set opened (21016-1
// Sungnyemun, 325 parts built as one model), Suggest sections pressed, a
// suggestion chosen, renamed, merged and split in the model tree, all
// accepted as sub-assemblies, one evaluated, broken out with Y and put back
// with Y, each way undone and redone, and the exploded view with Shift+Y.
//
//   node tools/web/sections_flow.mjs --url=<preview>/app --bypass=… [--out=shots/sections_web]
//        [--set=vendor/omr/files/21016-1.mpd]
//
// Every step is a click or a key on what the page says is where
// (window.brickworksControls, and brickworksState.sections.rows for the
// model tree's rows), and every result is read back off the app
// (window.brickworksState.sections, .tree, .bricks).
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/sections_web";
const set = resolve(String(args.set || "vendor/omr/files/21016-1.mpd"));
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
const wait = (ms) => page.waitForTimeout(ms);

async function controls() {
  return (await page.evaluate(() => window.brickworksControls || {})) || {};
}
async function controlAt(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await controls();
    if (where[name]) return where[name];
    // The tree's buttons are in the parts column, under the model tree, which
    // a first visit has folded: its column opened and its header clicked.
    if (n % 10 === 9) {
      await openColumnFor(page, name);
      const now = await controls();
      if (name.startsWith("sections_") && now.outliner && !now.outliner_tree) {
        await page.mouse.click(now.outliner.x, now.outliner.y);
        await page.waitForTimeout(1500);
      }
    }
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
async function click(at, options = {}) {
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await wait(250);
  await page.mouse.click(at.x, at.y, { clickCount: options.count || 1 });
  await wait(700);
}
async function key(name, ms = 800) {
  await page.keyboard.press(name);
  await wait(ms);
}
let failed = 0;
let shots = 0;
const results = [];
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  results.push({ what, ok });
  if (!ok) failed += 1;
}
async function shot(name) {
  shots += 1;
  const path = `${out}/${String(shots).padStart(2, "0")}_${name}.png`;
  await page.screenshot({ path, timeout: 120000 }).catch(() => {});
  console.log(`    picture: ${path}`);
}
const sections = async () => (await state()).sections || {};
const suggested = async () => (await sections()).suggested || [];
// A row of the model tree, by suggestion number or sub-assembly path.
async function rowAt(id, seconds = 30) {
  for (let n = 0; n < seconds * 2; n++) {
    const rows = (await sections()).rows || {};
    if (rows[id]) return rows[id];
    await wait(500);
  }
  throw new Error(`the model tree never showed row ${id}`);
}
// File, Open's own button, then its "from this computer" row, as a person.
async function openFile(path) {
  const at = await controlAt("open");
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await wait(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let w = 0; w < 60 && page.choosers.length === 0; w++) await wait(500);
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(path);
      return true;
    }
    await key("Escape", 3000);
  }
  return false;
}

await controlAt("model_name");
await wait(8000);
check(`opened ${set}`, await openFile(set));
const opened = await until((s) => /^opened \d+ parts/.test(s.said || ""), 300);
console.log(`    "${opened.said}"`);
// Parts fetched on demand still on their way (ModelStore.awaited): none left.
await until((s) => (s.awaited || 0) === 0 && s.bricks > 0, 300);
await wait(4000);
const bricks = (await state()).bricks;
check(`the set is on the baseplate (${bricks} parts)`, bricks > 300);

console.log("  suggested");
await click(await controlAt("sections_suggest"));
let s = await until((now) => ((now.sections || {}).suggested || []).length >= 2, 240);
const list = (s.sections || {}).suggested || [];
console.log(`    ${list.map((one) => `${one.number}. ${one.name} (${one.parts}, ${one.studs} studs, ${one.comes_off})`).join("; ")}`);
check(`Suggest sections lists ${list.length} sections in the model tree`, list.length >= 2);
const total = list.reduce((sum, one) => sum + one.parts, 0);
check(`...covering all ${bricks} parts (${total})`, total === bricks);
await shot("suggested");

// A suggestion's row selects its parts.
await click(await rowAt("1"));
s = await until((now) => now.selected === list[0].parts, 10);
check(`clicking suggestion 1 selects its ${list[0].parts} parts (${s.selected})`, s.selected === list[0].parts);

// Renamed by a double-click, typed over.
await click(await rowAt("2"), { count: 2 });
await key("Control+a", 300);
await page.keyboard.type("Gate roof", { delay: 30 });
await key("Enter", 1200);
let now = await suggested();
check(`a double-click renames suggestion 2 (${now[1] && now[1].name})`, now[1] && now[1].name === "Gate roof");

// Split, then merged back: one more, then one fewer.
const before = now.length;
await click(await rowAt("1"));
await click(await controlAt("sections_split"));
now = await suggested();
check(`Split parts suggestion 1 in two (${before} -> ${now.length})`, now.length === before + 1);
await click(await rowAt("2"));
await click(await controlAt("sections_merge"));
now = await suggested();
check(`Merge puts it back in with the one it is joined to most (${now.length})`, now.length === before);
const named = now.map((one) => one.name);

console.log("  accepted");
await click(await controlAt("sections_accept_all"));
s = await until((st) => ((st.sections || {}).suggested || []).length === 0 && Object.keys(st.tree || {}).length >= 2, 30);
const paths = Object.keys(s.tree || {});
console.log(`    tree: ${paths.join(", ")}`);
check(`Accept all makes each a sub-assembly (${paths.length}), named as they were`,
  paths.length >= 2 && named.every((name) => paths.some((p) => p.startsWith(name + "#"))));
await shot("accepted");

console.log("  evaluated");
const section = paths.find((p) => p.startsWith("Gate roof#")) || paths[paths.length - 1];
await click(await rowAt(section));
await click(await controlAt("sections_evaluate"));
s = await until((st) => ((st.sections || {}).evaluated || {}).parts > 0 && (st.sections || {}).report_open, 120);
const evaluated = (s.sections || {}).evaluated || {};
console.log(`    ${JSON.stringify(evaluated)}`);
check(`Evaluate… shows ${section} on its own: ${evaluated.parts} parts, ${Math.round(evaluated.grams)} g, `
  + `${evaluated.check_pieces ?? evaluated.pieces} piece, ${evaluated.steps} steps`,
  evaluated.parts > 0 && (evaluated.check_pieces ?? evaluated.pieces) === 1 && evaluated.steps > 0);
await shot("evaluated");
await key("Escape", 1000);

console.log("  broken out and put back");
await click(await rowAt(section));
const home = (await sections()).pose;
await key("y", 2500);
s = await until((st) => Object.keys((st.sections || {}).out || {}).length === 1, 30);
const offset = Object.values((s.sections || {}).out || {})[0];
check(`Y breaks ${section} out (by ${JSON.stringify(offset)} LDU), no part added or lost`,
  !!offset && s.bricks === bricks && (s.sections || {}).pose !== home);
await shot("broken_out");
await key("y", 2500);
s = await until((st) => Object.keys((st.sections || {}).out || {}).length === 0, 30);
check(`Y again puts it back, every part where it was`, (s.sections || {}).pose === home && s.bricks === bricks);
await key("Control+z", 2000);
s = await until((st) => Object.keys((st.sections || {}).out || {}).length === 1, 20);
const outAgain = Object.keys((s.sections || {}).out || {}).length === 1;
await key("Control+z", 2000);
s = await until((st) => Object.keys((st.sections || {}).out || {}).length === 0, 20);
const homeAgain = (s.sections || {}).pose === home;
await key("Control+Shift+z", 2000);
await key("Control+Shift+z", 2000);
s = await until((st) => (st.sections || {}).pose === home, 20);
check(`each way is one undo (out again ${outAgain}, home ${homeAgain}) and redoes`,
  outAgain && homeAgain && (s.sections || {}).pose === home);

console.log("  exploded");
await key("Shift+y", 2500);
s = await until((st) => (st.sections || {}).exploded >= 1, 30);
check(`Shift+Y draws ${(s.sections || {}).apart} sections apart, the model unchanged`,
  (s.sections || {}).exploded >= 1 && (s.sections || {}).apart >= 2 && (s.sections || {}).pose === home);
await shot("exploded");
await key("Shift+y", 2500);
s = await until((st) => (st.sections || {}).exploded === 0, 30);
check("Shift+Y again puts them back together", (s.sections || {}).exploded === 0);

await key("Control+z", 2000);
s = await until((st) => Object.keys(st.tree || {}).length === 0, 20);
check("one undo takes all the sections away again", Object.keys(s.tree || {}).length === 0);

writeFileSync(`${out}/results.json`, JSON.stringify({ set, bricks, results }, null, 2));
await browser.close();
console.log(failed === 0 ? "sections in a browser: suggested, renamed, split, merged, accepted, evaluated, "
  + "broken out and put back exactly, exploded" : `sections in a browser: ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
