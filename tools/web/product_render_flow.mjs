// File, Render…'s Product look in a real browser: the web build draws it
// with the Compatibility renderer, where the desktop's probe
// (src/dev/product_render_probe.gd) cannot vouch for it, and where the
// first Product glass read the wrong picture behind it and showed a pale
// patch on the sports car's windscreen (docs/RENDERING.md, section 6).
//
//   set -a; . ./.env; set +a
//   node tools/web/product_render_flow.mjs --url=https://<preview>.vercel.app/app --bypass=$VERCEL_BYPASS --out=shots/product_web
//   node tools/web/product_render_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=…   (a local export)
//
// Opens a small model made to show glass: a black wall behind a taller,
// longer wall of trans-clear bricks, which from the hero view is seen only
// through them, and a white wall behind one of trans dark blue. Presses
// Render, Product, Quick (--quality=good for Good) and 720p, and draws it
// on each backdrop, each downloaded. Fails if a picture is not 1280x720, is
// blank (the model under 2% of it on white, or one flat colour), if the
// blue glass does not show blue (it is white, or not drawn), if on white
// the black wall does not show dark through the clear glass (a pale patch,
// or the glass drawn opaque), or if a script error reaches the console.
// Says each render's longest frame and what it was doing then
// (StudioRender's worst_step). Leaves OUT/*.png, the downloads and a summary.
// --also=FILE,… draws those models too, for pictures, asking nothing.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/product_web";
const quality = args.quality || "quick";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

// Two walls of 2 x 4s, each behind a wall of glass a brick taller and
// twice as long, a stud's gap in front of it: from the hero view (from the
// left, in front and above; LDraw's -z is the front) the black wall is seen
// only through the clear glass.
const bricks = [];
const brick = (colour, x, level, z) => bricks.push(
  `1 ${colour} ${x} ${-24 * level} ${z} 1 0 0 0 1 0 0 0 1 3001.dat`);
for (const [x, behind, glass] of [[-140, 15, 33], [140, 0, 47]]) {
  for (let level = 0; level < 2; level++) brick(behind, x, level, 30);
  for (let level = 0; level < 3; level++) {
    brick(glass, x - 40, level, -30);
    brick(glass, x + 40, level, -30);
  }
}
const model = path.resolve(out, "glass_walls.ldr");
writeFileSync(model, ["0 Glass walls", "0 Name: glass_walls.ldr", ...bricks, ""].join("\n"));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
  if (/^render: /.test(m.text())) console.log(`      (${m.text()})`);
});
let failed = 0;
const facts = {};
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};

async function where(name, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = await page.evaluate((k) => (window.brickworksControls || {})[k], name);
    if (at) return at;
    await page.waitForTimeout(500);
  }
  return null;
}

async function press(name) {
  const at = await where(name);
  if (!at) throw new Error(`no ${name} on the page`);
  await page.mouse.click(at.x, at.y);
  // The app tells the page where its controls are twice a second, and a
  // press can move the ones under it.
  await page.waitForTimeout(1100);
}

const state = () => page.evaluate(() => window.brickworksRender || {});

// Open, From a file, and the file given to the page's chooser.
async function openFile(file) {
  const at = await where("open", 120);
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
      await page.waitForTimeout(500);
    }
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}

// Render, wait for the download and keep it.
async function renderAndKeep(label, minutes) {
  const download = page.waitForEvent("download", { timeout: minutes * 60000 }).catch(() => null);
  const started = Date.now();
  await press("render_picture");
  let seen = null;
  let began = false;
  for (let n = 0; n < minutes * 120; n++) {
    seen = await state();
    began = began || seen.working === "picture";
    if (!began && n > 60) break;
    if (began && seen.working === "") break;
    await page.waitForTimeout(500);
  }
  const got = await download;
  let file = null;
  if (got) {
    file = path.join(out, `${label}.png`);
    await got.saveAs(file);
  }
  const seconds = Math.round((Date.now() - started) / 1000);
  console.log(`      (${label}: ${seconds} s, ${seen && seen.status};`
    + ` the render's longest frame ${seen && seen.worst_frame_ms} ms, ${seen && seen.worst_step})`);
  facts[label] = { seconds, worst_frame_ms: seen && seen.worst_frame_ms, worst_step: seen && seen.worst_step };
  return file;
}

// What a picture holds, read by the page itself: its size; how much of it
// is the model (away from the backdrop's colour in its corners); how much
// is blue (bluer by 0.1 than it is red or green: white glass is not); how
// much is near black; and how far its lightness spreads, which a blank
// picture's does not.
function measure(file) {
  const data = readFileSync(file).toString("base64");
  return page.evaluate(async (b64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${b64}`;
    await image.decode();
    const canvas = document.createElement("canvas");
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const g = canvas.getContext("2d");
    g.drawImage(image, 0, 0);
    const { data } = g.getImageData(0, 0, canvas.width, canvas.height);
    const w = canvas.width;
    const h = canvas.height;
    const corner = [0, 0, 0];
    for (const [cx, cy] of [[4, 4], [w - 5, 4], [4, h - 5], [w - 5, h - 5]]) {
      const i = (cy * w + cx) * 4;
      for (let c = 0; c < 3; c++) corner[c] += data[i + c] / 255 / 4;
    }
    let model = 0; let blue = 0; let dark = 0; let sum = 0; let squares = 0;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i] / 255; const gr = data[i + 1] / 255; const b = data[i + 2] / 255;
      const lum = 0.2126 * r + 0.7152 * gr + 0.0722 * b;
      sum += lum;
      squares += lum * lum;
      if (Math.max(Math.abs(r - corner[0]), Math.abs(gr - corner[1]), Math.abs(b - corner[2])) > 0.1) model += 1;
      if (b - Math.max(r, gr) > 0.1) blue += 1;
      if (lum < 0.15) dark += 1;
    }
    const n = w * h;
    const mean = sum / n;
    return { width: w, height: h, model: model / n, blue: blue / n, dark: dark / n,
      spread: Math.sqrt(Math.max(squares / n - mean * mean, 0)) };
  }, data);
}

const pct = (x) => `${(100 * x).toFixed(1)}%`;

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  const until = Date.now() + 300000;
  while (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).tool_render)))) {
    if (Date.now() > until) throw new Error("the toolbar's Render never appeared");
    await page.waitForTimeout(1000);
  }
  // The example car's parts arrive over the network after the toolbar does.
  await page.waitForTimeout(Number(args.load || 20000));
  await openFile(model);
  let opened = null;
  for (let n = 0; n < 480 && !opened; n++) {
    const now = await page.evaluate(() => window.brickworksState || {});
    if (now.bricks === bricks.length && !now.awaited) opened = now;
    else await page.waitForTimeout(500);
  }
  check(`the glass walls opened (${opened ? opened.bricks : "no"} parts of ${bricks.length})`, Boolean(opened));
  await page.waitForTimeout(3000);

  await press("tool_render");
  check("the toolbar's Render opens the dialog", Boolean(await where("render_picture", 30)));
  await press("render_look_product");
  await press(`render_${quality}`);
  await press("render_size_720p");
  const shown = {};
  for (const backdrop of ["white", "gradient", "grey", "dark"]) {
    await press(`render_bg_${backdrop}`);
    const file = await renderAndKeep(`product_${backdrop}`, 20);
    const seen = file ? await measure(file) : null;
    shown[backdrop] = seen;
    if (!seen) {
      check(`Product on ${backdrop} downloads a picture`, false);
      continue;
    }
    check(`Product on ${backdrop}: a ${seen.width}x${seen.height} PNG, not blank (lightness spread ${seen.spread.toFixed(3)})`,
      seen.width === 1280 && seen.height === 720 && seen.spread > 0.03);
    check(`...its blue glass shows blue, not white: ${pct(seen.blue)} of it, at least 1%`, seen.blue >= 0.01);
  }
  const white = shown.white;
  if (white) {
    check(`on white the model is ${pct(white.model)} of the picture, at least 2%`, white.model >= 0.02);
    // The black wall is seen only through the clear glass: a pale patch, or
    // glass drawn opaque, leaves nothing near black.
    check(`...and the black wall shows through the clear glass: ${pct(white.dark)} of it near black, at least 0.5%`,
      white.dark >= 0.005);
  }
  facts.shown = shown;
  await page.screenshot({ path: path.join(out, "dialog.png"), timeout: 120000 });
  await press("render_close");

  // Pictures to put beside the desktop's, asking nothing of them:
  // --also=models/sports_car.ldr,… each opened and drawn in Product on
  // white at --also_quality (good).
  for (const file of (args.also ? String(args.also).split(",") : [])) {
    await openFile(path.resolve(file));
    let last = -1;
    for (let n = 0, still = 0; n < 480 && still < 6; n++) {
      const now = await page.evaluate(() => window.brickworksState || {});
      still = now.bricks > 0 && !now.awaited && now.bricks === last ? still + 1 : 0;
      last = now.bricks;
      await page.waitForTimeout(500);
    }
    await press("tool_render");
    await press("render_look_product");
    await press(`render_${args.also_quality || "good"}`);
    await press("render_size_720p");
    await press("render_bg_white");
    const name = path.basename(file).replace(/\.[^.]*$/, "");
    console.log(`      (${name}: ${last} parts)`);
    await renderAndKeep(name, 30);
    await press("render_close");
  }
} catch (error) {
  check(String(error), false);
} finally {
  check(`no script errors (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 5)) console.log(`      ${e}`);
  writeFileSync(path.join(out, "summary.json"), JSON.stringify(facts, null, 2));
  await browser.close();
  console.log(failed ? `${failed} failed` : "the Product look draws its glass in a browser, on every backdrop");
  process.exit(failed ? 1 : 0);
}
