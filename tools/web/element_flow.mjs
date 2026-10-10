// Make a part in the browser, place it, and find it still there after a reload.
//
//   node tools/web/element_flow.mjs --url=http://localhost:8147/ --out=shots/element_web
//
// The element maker needs nothing a browser lacks — no Python, no network:
// the part is written and built in GDScript from primitives the build ships,
// and kept in IndexedDB. This is the check that that is so, the way a person
// would find out: press "Make a part…" in the parts bin, make the 2 x 4 in
// hand a 2 x 7, add it, click it onto the baseplate, reload the page, and see
// the part come back in the bin and on the baseplate.
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

// The autosave runs a few seconds after a change; then the page goes.
await page.waitForTimeout(6000);
await page.reload({ waitUntil: "domcontentloaded" });
ok(await until(() => showing("make part"), 400, "make part again"), "the app came back after a reload");
await page.waitForTimeout(8000);
const again = await state();
ok(again && (again.custom || []).includes(after.held),
  `${after.held} is still among the parts made here: [${again?.custom}]`);
ok(again && again.bricks === placed.bricks,
  `and the model came back with it, ${again?.bricks} bricks`);
await shot("3_reloaded.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `${failed} problem(s); screenshots in ${out}`
  : `a part made in the browser is placed, kept and back after a reload; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
