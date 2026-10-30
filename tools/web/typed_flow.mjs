// A number typed while a part is in hand, in a browser: the keys as the page
// gives them to the web build, which must open the field, read it and put the
// part down where it says, as the desktop does (src/ui/typed_entry.gd, hand371;
// the desktop's own check is src/dev/typed_moves_probe.gd).
//
//   python3 tools/web/serve.py build/web 8871 --parts assets/generated/parts --delay 0 &
//   node tools/web/typed_flow.mjs --url=http://127.0.0.1:8871/ --out=DIR
//
// Q takes a part into hand over the baseplate; "3x" opens the field, which
// says what it will do; Enter puts the part down, one part more; one Ctrl-Z
// takes it away again. Then "-1py" (a minus first, which is a zoom with
// nothing in hand) and Esc, which closes the field with nothing put down.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8871/";
const out = args.out || "shots/typed_web";
mkdirSync(out, { recursive: true });

let failed = 0;
const ok = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}`);
  if (!passed) failed += 1;
  return passed;
};

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
// The engine's own errors; a missing file the local server has not (an
// /api route) is not the app's.
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER SCRIPT ERROR|Uncaught/.test(m.text())) errors.push(m.text());
});
page.on("pageerror", (e) => errors.push(String(e)));
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });

const wait = (ms) => page.waitForTimeout(ms);
const state = () => page.evaluate(() => window.brickworksState || {});
async function controlAt(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate(() => window.brickworksControls || {});
    if (where && where[name]) return where[name];
    await wait(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
// Every word the window shows (main.gd words_shown): the canvas has none a
// page can read.
async function words() {
  await page.evaluate(() => { window.brickworksWords = null; window.brickworksAskWords = true; });
  for (let n = 0; n < 40; n++) {
    const said = await page.evaluate(() => window.brickworksWords);
    if (said) return said;
    await wait(250);
  }
  return [];
}
async function until(test, seconds = 20) {
  for (let n = 0; n < seconds * 4; n++) {
    const now = await state();
    if (test(now)) return now;
    await wait(250);
  }
  return state();
}

await controlAt("model_name");
await wait(6000);
const fresh = await controlAt("new");
await page.mouse.click(fresh.x, fresh.y);
await wait(1500);
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) {
  await page.keyboard.press("Enter");
  await wait(1500);
}
const view = await controlAt("view");
const spot = { x: view.x - 120, y: view.y + 80 };
await page.mouse.move(spot.x, spot.y, { steps: 4 });
await page.keyboard.press("KeyQ");
const holding = await until((s) => s.mode === "place" && s.held);
ok(holding.mode === "place", `Q takes a part into hand (${holding.held})`);
await page.mouse.move(spot.x + 2, spot.y, { steps: 2 });
await wait(800);
const before = (await state()).bricks;

await page.keyboard.type("3x", { delay: 60 });
await wait(800);
let said = await words();
ok(said.some((w) => w.startsWith("x +3 studs")),
  `"3x" opens the field, saying ${JSON.stringify(said.find((w) => w.startsWith("x +")) || "nothing")}`);
ok(said.includes("3x"), "...and shows what was typed");
await page.screenshot({ path: `${out}/typed_3x.png` });
await page.keyboard.press("Enter");
let now = await until((s) => s.bricks === before + 1);
ok(now.bricks === before + 1, `Enter puts it down (${before} -> ${now.bricks} parts), still in hand: ${now.mode}`);
said = await words();
ok(!said.includes("3x"), "...and the field is gone");
await page.keyboard.press("Control+KeyZ");
now = await until((s) => s.bricks === before);
ok(now.bricks === before, `one Ctrl-Z takes it away (${now.bricks} parts)`);

await page.mouse.move(spot.x, spot.y + 30, { steps: 3 });
await page.mouse.move(spot.x + 1, spot.y + 30, { steps: 1 });
await wait(800);
await page.keyboard.type("-1py", { delay: 60 });
await wait(800);
said = await words();
ok(said.some((w) => w.startsWith("y -1 plate")),
  `"-1py" opens it on the minus, not a zoom: ${JSON.stringify(said.find((w) => w.startsWith("y ")) || "nothing")}`);
await page.screenshot({ path: `${out}/typed_minus.png` });
await page.keyboard.press("Escape");
await wait(800);
said = await words();
now = await state();
ok(!said.includes("-1py") && now.bricks === before && now.mode === "place",
  `Esc closes it, nothing put down, the part still in hand (${now.mode})`);
ok(errors.length === 0, `no script error in the console${errors.length ? `: ${errors[0]}` : ""}`);

await browser.close();
console.log(`\ntyped (web): ${failed === 0 ? "every check passed" : `${failed} FAILED`}`);
process.exit(failed === 0 ? 0 : 1);
