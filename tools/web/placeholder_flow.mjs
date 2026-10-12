// The parts bin and the minifigure builder filling in, in a real browser, on a
// slow network, photographed while they wait and again once they have.
//
//   node tools/web/placeholder_flow.mjs --build=build/web --port=8761 \
//     --parts=assets/generated/parts --out=shots/placeholders
//
// A cell whose picture had not been drawn yet was an empty square, the same as
// a part with no picture at all, and on the web most parts are a network fetch
// before they are a render. So the network is slow on purpose: this starts
// tools/web/serve.py with --parts, which answers /api/account as the deployment
// would, naming its own /parts/, and serves each part file from --parts after
// --delay milliseconds (and up to as much again), so a scroll lands on tiles
// that have to wait. It counts the parts served from the server's own output.
// Export the build with PARTS_URL set (tools/web_pack.py then marks every part
// reachable and copies none of them), or the bin shows only what was packed.
//
// It scrolls the bin a long way down and photographs it twice — at once, and
// after --settle ms — then opens the minifigure builder (M), scrolls its grid,
// and does the same. It fails if a script error reaches the console, if no part
// was fetched (then nothing waited and the pictures prove nothing), or if no
// fetch was answered. Whether the waiting looks right is for a person: look at
// the pictures.
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { spawn } from "node:child_process";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const build = args.build || "build/web";
const port = Number(args.port || 8761);
const url = `http://127.0.0.1:${port}/index.html`;
const parts = args.parts || "assets/generated/parts";
const out = args.out || "shots/placeholders";
const delay = Number(args.delay || 2500);
const settle = Number(args.settle || 90000);
mkdirSync(out, { recursive: true });

// The server, and how many parts it has served.
let asked = 0;
const server = spawn("python3", ["tools/web/serve.py", build, String(port),
  "--parts", parts, "--delay", String(delay)], { stdio: ["ignore", "pipe", "inherit"] });
await new Promise((ready, failed) => {
  server.on("exit", (code) => failed(new Error(`serve.py exited ${code}`)));
  server.stdout.on("data", (chunk) => {
    const text = String(chunk);
    if (text.includes("serving ")) ready();
    asked += (text.match(/^part /gm) || []).length;
  });
});
process.on("exit", () => server.kill());

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error/.test(m.text())) errors.push(m.text().slice(0, 300));
});
let failed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
};
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}.png`, timeout: 120000 });
    console.log(`    picture: ${out}/${name}.png`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
const until = Date.now() + 300000;
while (!(await page.evaluate(() => Boolean((window.brickworksControls || {})["make part"])))) {
  if (Date.now() > until) throw new Error("the app never came up");
  // In a laptop's window the parts bin starts folded to its rail.
  await openColumnFor(page, "make part");
  await page.waitForTimeout(1000);
}
await page.waitForTimeout(Number(args.load || 20000));
const where = (name) => page.evaluate((k) => (window.brickworksControls || {})[k], name);

// The bin's grid sits under its "Make a part…" button: the button is at the
// top right of the panel and the grid fills the middle of it.
const make = await where("make part");
const grid = { x: make.x - 100, y: make.y + 330 };
await shot("web_bin_open");
// Flung down in bursts until the scroll reaches parts the build did not pack:
// the bin opens on staples, and the web pack carries most of those, so the
// first few screens can be drawn without the network at all.
const before = asked;
await page.mouse.move(grid.x, grid.y);
let bursts = 0;
while (bursts < 16 && asked - before < 6) {
  for (let n = 0; n < 6; n++) {
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(120);
  }
  bursts += 1;
  await page.waitForTimeout(2500);
}
console.log(`    ${bursts} bursts of scrolling, ${asked - before} parts asked for`);
await page.waitForTimeout(Number(args.glance || 3000));
await shot("web_bin_loading");
await page.waitForTimeout(settle / 4);
await shot("web_bin_filling");
await page.waitForTimeout(settle);
await shot("web_bin_loaded");
check(`scrolling the bin fetched parts over the slow network: ${asked - before}`, asked > before);

// The minifigure builder: its heads are printed, and most are not packed.
await page.mouse.move(700, 120);
await page.keyboard.press("m");
let open = null;
for (let n = 0; n < 120 && !open; n++) {
  await page.waitForTimeout(500);
  open = await where("minifig_search");
}
check("M opens the minifigure builder", Boolean(open));
if (open) {
  await page.waitForTimeout(Number(args.glance || 4000));
  await shot("web_minifig_loading");
  const fetchedBefore = asked;
  await page.mouse.move(open.x, open.y + 200);
  for (let n = 0; n < 8; n++) {
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(150);
  }
  await page.waitForTimeout(Number(args.glance || 3000));
  await shot("web_minifig_scrolled_loading");
  await page.waitForTimeout(settle / 4);
  await shot("web_minifig_filling");
  await page.waitForTimeout(settle);
  await shot("web_minifig_loaded");
  check(`scrolling the builder's heads fetched more: ${asked - fetchedBefore}`, asked > fetchedBefore);
}

check(`no script errors in the console${errors.length ? ": " + errors[0] : ""}`, errors.length === 0);
await browser.close();
console.log(failed ? `placeholder flow: ${failed} FAILED`
  : `placeholder flow: ${asked} parts fetched slowly, pictures in ${out}`);
process.exit(failed ? 1 : 0);
