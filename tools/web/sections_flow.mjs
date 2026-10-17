// Sections in the browser, by clicks and keys: a real set opened (21016-1
// Sungnyemun, 325 parts built as one model), Suggest sections pressed, a
// suggestion chosen, renamed, merged and split in the model tree, all
// accepted as sub-assemblies, one evaluated, broken out with Y and put back
// with Y, each way undone and redone, and the exploded view with Shift+Y.
//
//   node tools/web/sections_flow.mjs --url=<preview>/app --bypass=… [--out=shots/sections_web]
//        [--set=vendor/omr/files/21016-1.mpd]
//   ... --timing --set=vendor/omr/files/10179-1.mpd   the app's own frames while a big
//        model is suggested, against its idle frames
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
// A control where it stays: the column shifts when what is selected changes,
// and a place read before the shift is no place to click.
async function settledAt(name) {
  let last = await controlAt(name);
  for (let n = 0; n < 20; n++) {
    await wait(700);
    const now = (await controls())[name];
    if (now && now.x === last.x && now.y === last.y) return now;
    if (now) last = now;
  }
  return last;
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
    // Out of view in the tree: scrolled to, as a person scrolls it.
    if (n % 4 === 3) {
      const tree = (await controls()).outliner_tree;
      if (tree) {
        await page.mouse.move(tree.x, tree.y);
        await page.mouse.wheel(0, n % 8 === 3 ? 120 : -120);
      }
    }
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

// --timing: a big model suggested, and the app's own frames read while it
// is worked out (brickworksState.busy: each frame whose own work passed
// 8 ms), against the same model's idle frames before.
if (args.timing) {
  const busySince = async (from) => ((await state()).busy || []).filter((f) => f[0] >= from);
  const idleFrom = (await state()).now;
  await wait(15000);
  const idle = await busySince(idleFrom);
  const idleLongest = idle.reduce((most, f) => Math.max(most, f[1]), 0);
  const from = (await state()).now;
  await click(await controlAt("sections_suggest"));
  const done = await until((now) => ((now.sections || {}).suggested || []).length >= 2, 900);
  const took = ((await state()).now - from) / 1000;
  const during = await busySince(from);
  const longest = during.reduce((most, f) => Math.max(most, f[1]), 0);
  const over = during.filter((f) => f[1] > 100).length;
  console.log(`    idle: ${idle.length} busy frames in 15 s, the longest ${idleLongest} ms`);
  console.log(`    suggesting: ${took.toFixed(1)} s, ${during.length} busy frames, the longest ${longest} ms, ${over} over 100 ms`);
  check(`${((done.sections || {}).suggested || []).length} sections suggested on ${bricks} parts in ${took.toFixed(1)} s`,
    ((done.sections || {}).suggested || []).length >= 2);
  check(`no frame of the app's own work over 100 ms while it is worked out, or over the idle page's ${idleLongest} ms (longest ${longest} ms)`,
    longest <= Math.max(100, idleLongest + 10));
  writeFileSync(`${out}/timing.json`, JSON.stringify({ set, bricks, took, idle, during }, null, 2));
  await shot("timing_suggested");
  await browser.close();
  console.log(failed === 0 ? "sections timing in a browser: ok" : `sections timing in a browser: ${failed} FAILED`);
  process.exit(failed === 0 ? 0 : 1);
}

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
await click(await settledAt("sections_split"));
s = await until((st) => ((st.sections || {}).suggested || []).length === before + 1, 20);
now = (s.sections || {}).suggested || [];
check(`Split parts suggestion 1 in two (${before} -> ${now.length}: "${s.said}")`, now.length === before + 1);
await click(await rowAt("2"));
await click(await settledAt("sections_merge"));
s = await until((st) => ((st.sections || {}).suggested || []).length === before, 20);
now = (s.sections || {}).suggested || [];
check(`Merge puts it back in with the one it is joined to most (${now.length}: "${s.said}")`,
  now.length === before);
const named = now.map((one) => one.name);

console.log("  accepted");
await click(await settledAt("sections_accept_all"));
s = await until((st) => ((st.sections || {}).suggested || []).length === 0 && Object.keys(st.tree || {}).length >= 2, 30);
const paths = Object.keys(s.tree || {});
console.log(`    tree: ${paths.join(", ")}`);
check(`Accept all makes each a sub-assembly (${paths.length}), named as they were`,
  paths.length >= 2 && named.every((name) => paths.some((p) => p.startsWith(name + "#"))));
await shot("accepted");

console.log("  evaluated");
const section = paths.find((p) => p.startsWith("Gate roof#")) || paths[paths.length - 1];
await click(await rowAt(section));
await click(await settledAt("sections_evaluate"));
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
// A click picks what is drawn: the section drawn highest on the page.
await wait(2500);
const drawn = (await sections()).drawn || {};
const highest = Object.entries(drawn).sort((a, b) => a[1].y - b[1].y)[0];
if (highest) {
  const [path, at] = highest;
  const own = (((await state()).tree || {})[path] || "").split(",").filter((p) => p).length;
  await click(at);
  s = await until((st) => st.selected === own, 10);
  check(`a click on ${path} where it is drawn apart chooses it (${s.selected} of its ${own} parts)`,
    own > 0 && s.selected === own);
  await shot("exploded_chosen");
} else {
  check("the page says where each section is drawn apart", false);
}
await key("Escape", 800);
await key("Shift+y", 2500);
s = await until((st) => (st.sections || {}).exploded === 0, 30);
check("Shift+Y again puts them back together", (s.sections || {}).exploded === 0);

// Back through the history: put back, broken out, then the sections made,
// each one step.
for (let n = 0; n < 3; n++) await key("Control+z", 2000);
s = await until((st) => Object.keys(st.tree || {}).length === 0, 20);
check("three undos take back the put-back, the break-out and every section made",
  Object.keys(s.tree || {}).length === 0 && Object.keys((s.sections || {}).out || {}).length === 0);

writeFileSync(`${out}/results.json`, JSON.stringify({ set, bricks, results }, null, 2));
await browser.close();
console.log(failed === 0 ? "sections in a browser: suggested, renamed, split, merged, accepted, evaluated, "
  + "broken out and put back exactly, exploded" : `sections in a browser: ${failed} FAILED`);
process.exit(failed === 0 ? 0 : 1);
