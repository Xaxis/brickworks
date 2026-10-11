// Make a part in the browser, place it, and find it still there after a reload.
//
//   node tools/web/element_flow.mjs --url=http://localhost:8147/ --out=shots/element_web
//
// The element maker needs nothing a browser lacks — no Python, no network:
// the part is written and built in GDScript from primitives the build ships,
// and kept in IndexedDB. This is the check that that is so, the way a person
// would find out: press "Make a part…" in the parts bin, make the 2 x 4 in
// hand a 2 x 7, add it, click it onto the baseplate, then press the Technic
// family and make a 1 x 6 Technic brick — drawn with peghole.dat and
// 4-4ndis.dat, which a browser has only because the build ships them — and
// click that down too; then type 32000 into "Start from a part", a Technic
// brick the build does not carry, so its geometry is fetched first, and make
// it four long from its own geometry, and click that down; reload the page,
// and see all three come back in the bin and on the baseplate.
//
// The fetch needs the server to say where geometry lives, as a deployment
// does: serve with --parts (tools/web/serve.py build/web PORT --parts
// assets/generated/parts).
//
// Driven by position, as assistant_flow.mjs is: the app publishes where its
// controls are (window.brickworksControls) and what is going on
// (window.brickworksState: bricks, the part in hand, the parts made here).
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://localhost:8147/";
const out = args.out || "shots/element_web";
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
});

const state = () => page.evaluate(() => window.brickworksState || null);
const showing = (n) => page.evaluate((n) => Boolean((window.brickworksControls || {})[n]), n);
const said = [];
const t0 = Date.now();
// Said as it happens, so a run that dies part way still says how far it got.
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};
// A frame can be slow to come under software rendering on a busy machine;
// a picture that never arrives is said, not fatal.
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
  await page.screenshot({ path: `${out}/never_${what.replace(/\W+/g, "_")}.png` }).catch(() => {});
  return false;
}

async function click(name) {
  if (!(await until(() => showing(name), 300, name))) {
    throw new Error(`the app never showed "${name}"`);
  }
  const where = await page.evaluate((n) => window.brickworksControls[n], name);
  await page.mouse.click(where.x, where.y);
}

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
const up = await until(() => showing("make part"), 400, "make part");
ok(up, "the app came up with a Make a part… button");
await page.waitForTimeout(8000);   // the opening model assembling itself
const before = await state();

await click("make part");
ok(await until(() => showing("element add"), 60, "element add"), "it opened the dialog");
await click("element length");
await page.keyboard.press("Control+A");
await page.keyboard.type("7", { delay: 40 });
await page.keyboard.press("Enter");
await page.waitForTimeout(3000);
await shot("1_dialog.png");
await click("element add");
const made = await until(async () => /^bw-/.test((await state())?.held || ""), 60, "made");
const after = await state();
ok(made, `Add to parts put ${after?.held} in hand, and it is one of [${after?.custom}]`);

// Onto the baseplate, in front of whatever the opening model was.
await page.waitForTimeout(1500);
await page.mouse.move(700, 760);
await page.waitForTimeout(800);
await page.mouse.click(700, 760);
await page.waitForTimeout(2500);
const placed = await state();
ok(placed && placed.bricks === before.bricks + 1,
  `clicking the baseplate placed it: ${before?.bricks} bricks, then ${placed?.bricks}`);
await shot("2_placed.png");

// A family the first version did not have, from the primitives it ships.
await click("make part");
ok(await until(() => showing("element family technic"), 60, "element family technic"),
  "the dialog shows its families, Technic among them");
await click("element family technic");
await page.waitForTimeout(1500);
await click("element length");
await page.keyboard.press("Control+A");
await page.keyboard.type("6", { delay: 40 });
await page.keyboard.press("Enter");
await page.waitForTimeout(3000);
await shot("3_technic.png");
await click("element add");
const technic = await until(async () => /^bw-h1x6/.test((await state())?.held || ""), 60,
  "technic made");
const madeTechnic = await state();
ok(technic, `Add to parts put ${madeTechnic?.held} in hand, a Technic brick with holes`);
await page.waitForTimeout(1500);
await page.mouse.move(520, 790);
await page.waitForTimeout(800);
await page.mouse.click(520, 790);
await page.waitForTimeout(2500);
const placedTechnic = await state();
ok(placedTechnic && placedTechnic.bricks === placed.bricks + 1,
  `clicking the baseplate placed it: ${placed?.bricks} bricks, then ${placedTechnic?.bricks}`);
await shot("4_technic_placed.png");

// A part that exists, changed as itself rather than redrawn: 32000 is not in
// the build, so the dialog fetches its geometry before it can change it.
await click("make part");
await click("element from");
await page.keyboard.press("Control+A");
await page.keyboard.type("32000", { delay: 40 });
await click("element start");
ok(await until(() => showing("element studs keep"), 180, "change controls"),
  "32000's geometry came, and the dialog changes it as itself");
await click("element length");
await page.keyboard.press("Control+A");
await page.keyboard.type("4", { delay: 40 });
await page.keyboard.press("Enter");
await page.waitForTimeout(3000);
await shot("5_changed.png");
await click("element add");
const changedOk = await until(async () => /^bw-32000-l4/.test((await state())?.held || ""), 60,
  "changed made");
const madeChanged = await state();
ok(changedOk, `Add to parts put ${madeChanged?.held} in hand, 32000 made four long`);
await page.waitForTimeout(1500);
await page.mouse.move(880, 800);
await page.waitForTimeout(800);
await page.mouse.click(880, 800);
await page.waitForTimeout(2500);
const placedChanged = await state();
ok(placedChanged && placedChanged.bricks === placedTechnic.bricks + 1,
  `clicking placed it: ${placedTechnic?.bricks} bricks, then ${placedChanged?.bricks}`);
await shot("6_changed_placed.png");

// The autosave runs a few seconds after a change; then the page goes.
await page.waitForTimeout(6000);
await page.reload({ waitUntil: "domcontentloaded" });
ok(await until(() => showing("make part"), 400, "make part again"), "the app came back after a reload");
await page.waitForTimeout(8000);
const again = await state();
const kept = again?.custom || [];
ok(kept.includes(after.held) && kept.includes(madeTechnic?.held) && kept.includes(madeChanged?.held),
  `${after.held}, ${madeTechnic?.held} and ${madeChanged?.held} are still among the parts made here: [${kept}]`);
ok(again && again.bricks === placedChanged.bricks,
  `and the model came back with them, ${again?.bricks} bricks`);
await shot("7_reloaded.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `${failed} problem(s); screenshots in ${out}`
  : `parts made in the browser are placed, kept and back after a reload; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
