// Building from a set's parts in a real browser (docs/APP_UX.md B10): a
// set's number typed into the parts bin's search, Build from it, and a part
// taken from the set's bin and put down, its count dropping by one.
//
//   tools/export.sh web
//   ln -sfn "$PWD/assets/generated/sets" build/web/sets   # what deploy.sh serves at /sets/
//   python3 tools/web/serve.py build/web 9271 --parts assets/generated/parts --delay 0 &
//   node tools/web/setbin_flow.mjs --url=http://127.0.0.1:9271/ --out=shots/setbin_web
//   node tools/web/setbin_flow.mjs --url=<preview>/app --bypass=… --out=DIR
//
// At 1280 x 860, by the mouse: a new model, then "10497-1" typed into the
// search; the line at the bin's top offers 10497-1 Galaxy Explorer, and Build
// from it makes the bin its parts (brickworksState.bin_set), timed from the
// press, with how long the set's inventory took to arrive (the web fetches the
// one shard it is in from /sets/: the app's "set bin: … looked up in N ms").
// The first tile taken puts its part in hand in the tile's colour; a click on
// the model puts it down, and the tile's count (brickworksState.bin_left)
// drops by one. Then Ctrl-Z gives it back. Pictures of each step go to --out.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:9271/");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(String(args.out || "shots/setbin_web"));
const SET = String(args.set || "10497-1");
const TITLE = String(args.title || "10497-1 Galaxy Explorer");
mkdirSync(out, { recursive: true });

let failures = 0;
const t0 = Date.now();
const check = (line, passed) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failures += 1;
  return passed;
};

const browser = await launch();
const width = 1280;
const height = 860;
const context = await browser.newContext({ viewport: { width, height } });
const page = await context.newPage();
const errors = [];
let looked = "";
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  if (/^set bin: /.test(m.text())) looked = m.text();
});
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const until = async (test, seconds = 30) => {
  for (let n = 0; n < seconds * 4; n++) {
    const s = await state();
    if (test(s)) return s;
    await page.waitForTimeout(250);
  }
  return state();
};
const where = async (name, seconds = 30) => {
  for (let n = 0; n < seconds * 4; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(250);
  }
  return null;
};
const press = async (name, seconds = 30) => {
  const at = await where(name, seconds);
  if (!check(`"${name}" is on the screen`, Boolean(at))) return false;
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(600);
  return true;
};
const picture = (what) => page.screenshot({ path: `${out}/${width}_${what}.png`, timeout: 120000 })
  .then(() => console.log(`  shot  ${out}/${width}_${what}.png`))
  .catch((e) => console.log(`  --    no picture ${what}: ${String(e).split("\n")[0]}`));

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
check("the app came up", Boolean(await where("open", 400)));
await page.waitForTimeout(Number(args.load || 8000));
// A new model, the sample's parts out of the way (placing_flow.mjs).
await press("new");
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) {
  await page.keyboard.press("Enter");
  await page.waitForTimeout(1500);
}
await page.evaluate(() => { window.brickworksAskLayout = true; });
await page.waitForTimeout(1500);
const view = ((await page.evaluate(() => window.brickworksLayout)) || {}).view;
const centre = view ? { x: view[0] + view[2] / 2, y: view[1] + view[3] / 2 } : { x: width * 0.65, y: height / 2 };

// The set's number typed, and offered.
await press("part search");
await page.keyboard.type(SET, { delay: 40 });
const offer = await where("set build", 60);
check(`its number typed, the bin's top line offers ${SET}`, Boolean(offer));
await page.waitForTimeout(2000);
await picture("1_offered");
const pressed = Date.now();
if (offer) await page.mouse.click(offer.x, offer.y);
const built = await until((s) => s.bin_set === TITLE, 60);
const shownIn = Date.now() - pressed;
check(`Build from it: the bin is "${built.bin_set}", in ${shownIn} ms from the press (state read every 250 ms)`,
  built.bin_set === TITLE);
console.log(`  --    ${looked || "no lookup line heard"}`);
await page.waitForTimeout(6000);
await picture("2_chosen");

// The first tile taken, and put down.
// [[part/colour, left], ...] in the tiles' order: the first is "first part".
const left = (s, k) => ((s.bin_left || []).find((pair) => pair[0] === k) || [k, undefined])[1];
const before = (await until((s) => (s.bin_left || []).length > 0, 30)).bin_left || [];
const key = (before[0] || [])[0];
const had = (before[0] || [])[1];
check(`the first tile is ${key}, with ${had} of it left`, Boolean(key) && had > 0);
await press("first part");
const held = await until((s) => s.colour === Number(String(key).split("/")[1]), 20);
check(`taking it puts its colour in hand (${held.colour}, the tile's ${String(key).split("/")[1]})`,
  held.colour === Number(String(key).split("/")[1]));
const bricks = held.bricks || 0;
for (let n = 0; n < 6; n++) {
  await page.mouse.move(centre.x + n * 3, centre.y, { steps: 2 });
  await page.waitForTimeout(500);
}
await page.waitForTimeout(2000);
await page.mouse.click(centre.x + 15, centre.y);
const down = await until((s) => s.bricks === bricks + 1 && left(s, key) === had - 1, 60);
check(`put down (${down.bricks - bricks} part), its count drops by one: ${had} to ${left(down, key)}`,
  down.bricks === bricks + 1 && left(down, key) === had - 1);
await page.mouse.move(centre.x, height - 40);
await page.waitForTimeout(3000);
await picture("3_placed");
await page.keyboard.press("Escape");
await page.waitForTimeout(500);
await page.keyboard.press("Control+z");
const undone = await until((s) => s.bricks === bricks && left(s, key) === had, 30);
check(`Ctrl-Z gives it back: ${left(undone, key)} of ${had}`, left(undone, key) === had);

check(`no script errors${errors.length ? `: ${errors[0]}` : ""}`, errors.length === 0);
await browser.close();
console.log(failures ? `setbin flow: ${failures} failed` : "setbin flow: a set's parts in the web build, counted down as one is put down");
process.exit(failures ? 1 : 0);
