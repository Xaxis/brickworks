// Make a minifigure and stand it in the model, in a real browser.
//
//   node tools/web/minifig_flow.mjs --url=https://brickworks.diy/app --out=shots/minifig_web
//   node tools/web/minifig_flow.mjs --url=<preview>/app --bypass=$VERCEL_BYPASS --out=…
//   node tools/web/minifig_flow.mjs --url=http://127.0.0.1:8137/index.html --out=…   (a local export)
//
// Presses M, photographs the builder, presses Place in model, clicks the
// baseplate, then opens it again, chooses the first part of the Cape slot
// (a part the pack does not ship) and places that figure too, then opens
// it again and presses Surprise me. The web build
// draws with the Compatibility renderer and fetches most parts as they are
// wanted, so this is the path the desktop probes cannot vouch for: a
// builder that works on the desktop and shows an empty preview here would
// pass every one of them. It fails if the builder's controls never appear,
// if Place does not close it, if the click does not add the figure's parts
// to the model (the app publishes its part count, window.brickworksBricks),
// or if a script error reaches the console.
//
// The builder is drawn inside the canvas, so it is driven by position: the
// app publishes where its controls are (window.brickworksControls, see
// main._tell_page) and this clicks there.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/minifig_web";
// A preview is behind Vercel's protection: the bypass, and a cookie for
// what the page fetches after.
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
});
let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
const until = Date.now() + 300000;
while (!(await page.evaluate(() => Boolean(window.brickworksControls)))) {
  if (Date.now() > until) throw new Error("the app never came up");
  await page.waitForTimeout(1000);
}
await page.waitForTimeout(Number(args.load || 20000));

async function where(name, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = await page.evaluate((k) => (window.brickworksControls || {})[k], name);
    if (at) return at;
    await page.waitForTimeout(500);
  }
  return null;
}

// Keys go to the canvas; nothing else on the page has focus.
await page.mouse.move(700, 120);
await page.keyboard.press("m");
const place = await where("minifig_place");
check("M opens the minifigure builder", Boolean(place));
await page.waitForTimeout(Number(args.draw || 60000));
await page.screenshot({ path: `${out}/1_builder.png`, timeout: 120000 });

// The figure it opens with, whose parts ship in the web pack
// (tools/web_pack.py ESSENTIAL), so placing it waits on nothing.
const placing = await where("minifig_place");
if (placing) await page.mouse.click(placing.x, placing.y);
let closed = false;
for (let n = 0; n < 120 && !closed; n++) {
  await page.waitForTimeout(500);
  closed = !(await page.evaluate(() => Boolean((window.brickworksControls || {}).minifig_place)));
}
check("Place in model closes the builder", closed);

// A clear stretch of baseplate, nearer the camera than the example model
// in the middle: the figure is refused (drawn red) where it would stand
// in something, and a click there puts nothing down.
const count = () => page.evaluate(() => window.brickworksBricks || 0);
const before = await count();
const spot = { x: Number(args.x || 480), y: Number(args.y || 790) };
await page.mouse.move(spot.x - 20, spot.y - 20);
await page.waitForTimeout(1500);
await page.mouse.move(spot.x, spot.y);
await page.waitForTimeout(8000);
await page.screenshot({ path: `${out}/2_holding.png`, timeout: 120000 });
await page.mouse.click(spot.x, spot.y);
let after = before;
for (let n = 0; n < 120 && after === before; n++) {
  await page.waitForTimeout(500);
  after = await count();
}
await page.keyboard.press("Escape");
await page.mouse.move(700, 12);
await page.waitForTimeout(3000);
await page.screenshot({ path: `${out}/3_placed.png`, timeout: 120000 });
check(`a click on the baseplate stands the figure there: ${before} parts, then ${after}`,
  after - before >= 7);

// A slot the builder did not use to have, with a part the pack does not
// ship: the cape slot, its first part (fetched over the wire), and the
// caped figure placed beside the first. The app publishes where the
// grid's first part is (minifig_choice) as it does its buttons.
await page.keyboard.press("m");
const capeSlot = await where("minifig_cape", 120);
check("the builder has a Cape slot", Boolean(capeSlot));
if (capeSlot) await page.mouse.click(capeSlot.x, capeSlot.y);
await page.waitForTimeout(3000);
const firstCape = await where("minifig_choice", 60);
check("the Cape slot offers capes to choose", Boolean(firstCape));
if (firstCape) await page.mouse.click(firstCape.x, firstCape.y);
await page.waitForTimeout(Number(args.draw || 60000));
await page.screenshot({ path: `${out}/4_cape.png`, timeout: 120000 });
const placeCaped = await where("minifig_place");
if (placeCaped) await page.mouse.click(placeCaped.x, placeCaped.y);
// Somewhere clear of the first figure, whose arms and cape-less shoulders
// fill a stud either side of it at this zoom: a figure is refused where it
// would stand in something, so try a few clear stretches of baseplate.
const beforeCape = await count();
let afterCape = beforeCape;
// The cape comes over the wire: the ghost stays red until it has.
await page.waitForTimeout(20000);
// Nearest first, so the photograph shows the cape whole rather than at the
// edge of the view.
let placedAt = null;
for (const [dx, dy] of [[170, 20], [320, 20], [440, 30], [-220, 40], [560, 10]]) {
  const caped = { x: spot.x + dx, y: spot.y + dy };
  placedAt = caped;
  await page.mouse.move(caped.x - 20, caped.y - 20);
  await page.waitForTimeout(1500);
  await page.mouse.move(caped.x, caped.y);
  await page.waitForTimeout(6000);
  await page.mouse.click(caped.x, caped.y);
  for (let n = 0; n < 40 && afterCape === beforeCape; n++) {
    await page.waitForTimeout(500);
    afterCape = await count();
  }
  if (afterCape !== beforeCape) break;
}
await page.keyboard.press("Escape");
await page.mouse.move(700, 12);
await page.waitForTimeout(3000);
await page.screenshot({ path: `${out}/5_caped.png`, timeout: 120000 });
// And close, for looking at how the cape hangs.
if (afterCape !== beforeCape && placedAt) {
  const view = page.viewportSize();
  const clip = { x: Math.max(0, placedAt.x - 170), y: Math.max(0, placedAt.y - 380),
    width: 340, height: 420 };
  clip.width = Math.min(clip.width, view.width - clip.x);
  clip.height = Math.min(clip.height, view.height - clip.y);
  await page.screenshot({ path: `${out}/5_caped_close.png`, clip, timeout: 120000 });
}
check(`the caped figure stands beside the first: ${beforeCape} parts, then ${afterCape}`,
  afterCape - beforeCape >= 8);

// A figure nobody chose, for looking at: its parts mostly come over the
// wire, and its thumbnails one a frame, so a browser drawing in software
// shows them late. On this machine, at a load of 65, SwiftShader drew one
// frame a second and fetched ten parts in two minutes.
await page.keyboard.press("m");
const surprise = await where("minifig_surprise", 120);
if (surprise) await page.mouse.click(surprise.x, surprise.y);
await page.waitForTimeout(Number(args.draw || 60000));
await page.screenshot({ path: `${out}/6_surprise.png`, timeout: 120000 });
check(`no script errors in the console${errors.length ? ": " + errors[0] : ""}`,
  errors.length === 0);

await browser.close();
console.log(failed ? `minifig flow: ${failed} FAILED` : `minifig flow: made, placed and photographed in ${out}`);
process.exit(failed ? 1 : 0);
