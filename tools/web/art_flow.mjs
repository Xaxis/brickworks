// A picture laid in LEGO Art in a real browser: chosen through the page's
// own file chooser from Build > Mosaic from a picture, built in LEGO Art, and
// checked — every part on the baseplate, each panel its own sub-assembly, one
// piece. Then Design with Claude, which hands the picture to the assistant.
//
//   set -a; . ./.env; set +a
//   node tools/web/art_flow.mjs --url=http://127.0.0.1:8147/index.html --out=shots/art_web   (a local export)
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/art_flow.mjs --url=https://<a preview>/app --out=shots/art_web
//
// The picture is made here, 96 x 64 pixels: a dark sky, a tilted pale disc,
// a bright core and a few stars, written as a PNG into --out. The Build menu
// is opened with a click and the item reached by typing its name and Enter,
// as a person at a keyboard does (a key press lets a page open its chooser).
// It fails if no chooser comes up, the dialog never shows, the Art does not
// land with window.brickworksState.art saying its parts, every one of them on
// the baseplate, in one piece, its panels in the model tree as Panel N#1, or
// a script error reaches the console. Design with Claude cannot design here —
// that is a network run on a key or a plan — so what is checked is that the
// brief takes what is typed into it, and that it goes to the assistant: its
// column opens, and with no key of its own the page says so rather than
// doing nothing.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { deflateSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
// A preview sits behind Vercel's login; with BW_BYPASS the first load
// carries the bypass and sets its cookie, so the pack and the parts answer.
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/art_web";
mkdirSync(out, { recursive: true });

// The picture, as a PNG: eight-bit RGB rows, each led by filter 0.
function crc32(bytes) {
  let c = ~0;
  for (const b of bytes) {
    c ^= b;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}
function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4, "ascii");
  const tail = Buffer.alloc(4);
  tail.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])), 0);
  return Buffer.concat([head, data, tail]);
}
function galaxy(w, h) {
  const rows = Buffer.alloc((w * 3 + 1) * h);
  const stars = [[8, 6], [85, 10], [14, 55], [70, 52], [40, 8]];
  for (let y = 0; y < h; y++) {
    rows[y * (w * 3 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const dx = x + 0.5 - w / 2;
      const dy = (y + 0.5 - h / 2) / 0.45;
      const r = Math.hypot(dx, dy) / (w * 0.42);
      let c = [8, 8, 20];
      if (r < 1) {
        const t = 1 - r;
        c = [8 + 107 * t, 8 + 120 * t, 20 + 170 * t];
        if (r < 0.25) {
          const u = 1 - r / 0.25;
          c = [c[0] + (255 - c[0]) * u, c[1] + (235 - c[1]) * u, c[2] + (180 - c[2]) * u];
        }
      }
      if (stars.some(([sx, sy]) => sx === x && sy === y)) c = [255, 255, 255];
      const at = y * (w * 3 + 1) + 1 + x * 3;
      rows[at] = Math.round(c[0]);
      rows[at + 1] = Math.round(c[1]);
      rows[at + 2] = Math.round(c[2]);
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(w, 0);
  header.writeUInt32BE(h, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header), chunk("IDAT", deflateSync(rows)), chunk("IEND", Buffer.alloc(0))]);
}
const picture = resolve(out, "galaxy.png");
writeFileSync(picture, galaxy(96, 64));

const browser = await launch();
const errors = [];
const said = [];
const t0 = Date.now();
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
// Choosers are caught by a listener there from the start (studio_flow.mjs
// says why).
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) errors.push(m.text().slice(0, 300));
});

const controls = () => page.evaluate(() => window.brickworksControls || {});
const state = () => page.evaluate(() => window.brickworksState || null);
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
  await shot(`never_${what.replace(/\W+/g, "_")}.png`);
  return false;
}
async function where(name, seconds = 120) {
  if (!(await until(async () => Boolean((await controls())[name]), seconds, name))) {
    throw new Error(`the app never showed "${name}"`);
  }
  return (await controls())[name];
}
async function click(name) {
  const at = await where(name);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}

// Build > Mosaic from a picture…, then the picture into the chooser it opens.
// Tried again if no chooser came, since the app reads a key at its next frame
// and a software frame can take seconds.
async function choosePicture() {
  let chooser = null;
  for (let n = 0; n < 3 && !chooser; n++) {
    page.choosers.length = 0;
    await click("menu_build");
    await page.keyboard.type("Mosaic", { delay: 120 });
    await page.waitForTimeout(800);
    await page.keyboard.press("Enter");
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
    chooser = page.choosers.shift() || null;
    if (!chooser) await page.keyboard.press("Escape");
  }
  if (chooser) await chooser.setFiles(picture);
  return Boolean(chooser);
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await until(async () => Boolean((await controls()).open), 400, "app"), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));

ok(await choosePicture(), "Build > Mosaic from a picture… brings up the page's file chooser");
ok(await until(async () => Boolean((await controls()).mosaic_build), 120, "dialog"),
  "the picture dialog comes up for galaxy.png, in Brick Art");
// Its picture of the result and what it comes to are worked out a moment
// after it opens.
await page.waitForTimeout(8000);
await shot("1_dialog.png");

await click("mosaic_build");
const landed = await until(async () => {
  const s = await state();
  return Boolean(s && s.art && s.art.parts > 0 && s.art.pieces > 0);
}, 600, "laid");
const s = await state();
const art = s?.art || {};
const panels = Object.keys(s?.tree || {}).filter((path) => /^Panel \d+#1$/.test(path));
ok(landed && art.parts > 300 && s.bricks === art.parts,
  `it lands: ${art.parts} parts on ${(art.panels || []).join(" x ")} panels, ${s?.bricks} on the baseplate`);
ok(art.pieces === 1 && art.ok === true, `in one piece, checked: ${art.pieces} piece(s), ok ${art.ok}`);
const across = (art.panels || [0, 0])[0] * (art.panels || [0, 0])[1];
ok(panels.length === across && Boolean(s?.tree?.["Frame#1"]),
  `each panel its own sub-assembly, and the frame: ${Object.keys(s?.tree || {}).join(", ")}`);
await page.waitForTimeout(6000);
await shot("2_laid.png");

// Design with Claude: the picture again, a brief, and the button.
ok(await choosePicture(), "and again, for Design with Claude");
const brief = await where("mosaic_brief");
const tool = (await state())?.mode;
await page.mouse.click(brief.x, brief.y);
await page.keyboard.type("raise the core, make the stars glow", { delay: 40 });
// Typed anywhere but the brief, those letters are shortcuts: O takes up
// the orbit tool, M opens the minifigure builder, the comma the controls.
await page.waitForTimeout(1500);
ok((await state())?.mode === tool, `the brief takes what is typed: the tool is still ${tool} (${(await state())?.mode})`);
await click("mosaic_claude");
// The status line clears itself after a few seconds, so it is read as it
// changes rather than once at the end.
let told = "";
const handed = await until(async () => {
  const now = await state();
  if (/key of your own|Still working/i.test(String(now?.said || ""))) told = now.said;
  return Boolean(now?.columns?.assistant) && !(await controls()).mosaic_build && told !== "";
}, 60, "handed");
const after = await state();
ok(Boolean(after?.columns?.assistant) && !(await controls()).mosaic_build,
  `Design with Claude closes the dialog and opens the assistant: ${JSON.stringify(after?.columns)}`);
ok(handed, `and with no key of its own, says what is needed rather than nothing: "${told}"`);
await page.waitForTimeout(4000);
await shot("3_claude.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `art flow: ${failed} problem(s); screenshots in ${out}`
  : `art flow: a picture chosen, laid in LEGO Art in one piece, and handed to Claude; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
