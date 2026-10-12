// Printed parts and stickers in a real browser: a photograph on a 2 x 2
// tile, a logo on a 2 x 4 slope, a sticker across two 1 x 4 tiles, the
// sticker sheet downloaded and measured, and the model downloaded and opened
// in a browser that has never seen any of them.
//
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/studio_flow.mjs --url=https://<a preview>/app --out=shots/studio_web
//   node tools/web/studio_flow.mjs --url=http://127.0.0.1:8147/index.html --out=…   (a local export)
//
// Opens tests/fixtures/prints/scene.ldr through Open… > From a file (the
// page's own file picker, answered by Playwright); presses the bin's
// Print…, types 3068b into "or print on", brings a photograph in through
// Add a picture…, covers the tile with it, saves it and clicks it down;
// prints web/icon.svg on 3037's slope with its background cleared in LEGO
// inks; presses Stickers… > New sticker…, clicks the two tiles in the middle
// of the view, draws a sign and saves it; saves the sheet as a PDF and
// measures it with tools/sticker_sheet_check.py; exports the model, and in
// a second, empty browser opens it and photographs it. It fails if a
// control never appears, a save adds no part made here
// (window.brickworksState.custom), the sticker is not stuck on, the sheet is
// not true to size within 0.1 mm, the model does not come back with all its
// printed parts, or a script error reaches the console.
import { launch } from "./browser.mjs";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
// A preview sits behind Vercel's login; with BW_BYPASS (the project's
// VERCEL_BYPASS) the first load carries the bypass and sets its cookie, so
// the pack, the parts and the API answer too.
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/studio_web";
mkdirSync(out, { recursive: true });
const photo = args.photo || "/usr/share/backgrounds/Monument_valley_by_orbitelambda.jpg";
const logo = resolve("web/icon.svg");
const scene = resolve("tests/fixtures/prints/scene.ldr");

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

async function page_for(name) {
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
  page.on("pageerror", (e) => errors.push(`${name}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) {
      errors.push(`${name}: ${m.text().slice(0, 300)}`);
    }
  });
  return page;
}

function tools(page) {
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
  async function click(name, seconds = 120) {
    const at = await where(name, seconds);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(1500);
  }
  // Whatever a press opens a file picker for, answered with a file. The app
  // reads the click a frame or more after the page does, and on SwiftShader
  // under load a frame can take seconds, so a press that brought no picker
  // is tried again rather than taken for a failure.
  async function picked(press, file, what) {
    for (let n = 0; n < 3; n++) {
      const waiting = page.waitForEvent("filechooser", { timeout: 30000 }).catch(() => null);
      await press(n);
      const picker = await waiting;
      if (picker) {
        await picker.setFiles(file);
        return;
      }
      await shot(`no_picker_${what}_${n}.png`);
      await page.keyboard.press("Escape");
      await page.waitForTimeout(3000);
    }
    throw new Error(`no file picker came up for ${what}`);
  }
  async function choose(name, file) {
    const at = await where(name);
    await picked(async () => page.mouse.click(at.x, at.y), file, name);
  }
  async function open(file) {
    const at = await where("open");
    await picked(async (n) => {
      await page.mouse.click(at.x, at.y);
      // The menu opens under the pointer; its first line is "From a file".
      await page.waitForTimeout(4000 + 4000 * n);
      if (n === 0) await shot("open_menu.png");
      await page.mouse.click(at.x + 40, at.y + 22);
    }, file, "open");
  }
  async function type(name, words) {
    await click(name);
    await page.keyboard.press("Control+A");
    await page.keyboard.type(words, { delay: 40 });
    await page.keyboard.press("Enter");
    await page.waitForTimeout(1000);
  }
  async function stroke(points) {
    await page.mouse.move(points[0][0], points[0][1]);
    await page.mouse.down();
    for (let n = 1; n < points.length; n++) {
      await page.mouse.move(points[n][0], points[n][1], { steps: 6 });
    }
    await page.mouse.up();
    await page.waitForTimeout(800);
  }
  const custom = async () => (await state())?.custom || [];
  return { controls, state, shot, until, where, click, choose, open, type, stroke, custom };
}

const page = await page_for("first");
const $ = tools(page);
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await $.until(async () => Boolean((await $.controls()).open), 400, "app"), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));

await $.open(scene);
const opened = await $.until(async () => (await $.state())?.bricks >= 4, 120, "scene");
ok(opened, `the scene opened through Open… > From a file: ${(await $.state())?.bricks} bricks`);
await page.waitForTimeout(8000);
await $.shot("1_scene.png");

// A photograph on a 2 x 2 tile.
await $.click("print part");
await $.type("print_other", "3068b");
await $.click("print_on_it");
await $.until(async () => Boolean((await $.controls()).print_area_top), 120, "tile top");
await $.choose("print_add_picture", photo);
ok(await $.until(async () => Boolean((await $.controls()).print_fill), 60, "picture panel"),
  "a photograph brought in through the page's file picker");
await $.click("print_fill");
const canvas = await $.where("print_canvas");
await $.stroke([[canvas.x, canvas.y], [canvas.x - 30, canvas.y], [canvas.x - 50, canvas.y + 4]]);
await page.waitForTimeout(3000);
await $.shot("2_photo_editor.png");
await $.type("print_name", "Monument Valley");
let before = await $.custom();
await $.click("print_save");
const photo_made = await $.until(async () => (await $.custom()).some((id) => /^bw-3068b-p/.test(id)
  && !before.includes(id)), 120, "photo saved");
ok(photo_made, `saved as a printed tile: ${(await $.custom()).filter((id) => /^bw-3068b-p/.test(id))}`);
const count = () => page.evaluate(() => window.brickworksBricks || 0);
let bricks = await count();
for (const [x, y] of [[480, 790], [620, 800], [360, 780], [760, 810]]) {
  await page.mouse.move(x - 20, y - 20);
  await page.waitForTimeout(1200);
  await page.mouse.move(x, y);
  await page.waitForTimeout(4000);
  await page.mouse.click(x, y);
  await page.waitForTimeout(3000);
  if ((await count()) > bricks) break;
}
ok((await count()) > bricks, `clicked down in the model: ${bricks} parts, then ${await count()}`);
await page.keyboard.press("Escape");

// A logo on a 2 x 4 slope.
await $.click("print part");
await $.type("print_other", "3037");
await $.click("print_on_it");
await $.click("print_area_slope");
await $.choose("print_add_picture", logo);
await $.until(async () => Boolean((await $.controls()).print_clear_back), 60, "picture panel");
await $.click("print_clear_back");
await $.click("print_lego");
await $.click("print_fit");
await page.waitForTimeout(3000);
await $.shot("3_slope_editor.png");
await $.type("print_name", "Brickworks Logo");
before = await $.custom();
await $.click("print_save");
ok(await $.until(async () => (await $.custom()).some((id) => /^bw-3037-p/.test(id)
  && !before.includes(id)), 120, "logo saved"), "saved as a printed slope");
bricks = await count();
for (const [x, y] of [[900, 800], [1000, 790], [820, 810]]) {
  await page.mouse.move(x - 20, y - 20);
  await page.waitForTimeout(1200);
  await page.mouse.move(x, y);
  await page.waitForTimeout(4000);
  await page.mouse.click(x, y);
  await page.waitForTimeout(3000);
  if ((await count()) > bricks) break;
}
ok((await count()) > bricks, `the printed slope clicked down too: ${await count()} parts`);
await page.keyboard.press("Escape");

// A sticker across the two tiles, which are in the middle of the view.
await $.click("stickers");
await $.click("sheet_new");
const view = await $.where("view");
await page.mouse.click(view.x, view.y);
await page.waitForTimeout(2000);
const sticker_canvas = await $.where("print_canvas");
ok(Boolean(sticker_canvas), "a click on the tiles opens a sticker for them");
await $.click("print_tool_fill");
await $.click("print_ink_1");
await page.mouse.click(sticker_canvas.x, sticker_canvas.y);
await page.waitForTimeout(1000);
await $.click("print_tool_box");
await $.click("print_ink_15");
await $.stroke([[sticker_canvas.x - 180, sticker_canvas.y - 70], [sticker_canvas.x + 180, sticker_canvas.y + 70]]);
await page.waitForTimeout(2000);
await $.shot("4_sticker_editor.png");
await $.type("print_name", "Brick Street");
before = await $.custom();
await $.click("print_save");
ok(await $.until(async () => (await $.custom()).some((id) => /^bw-st-/.test(id) && !before.includes(id)),
  120, "sticker saved"), "the sticker is made and stuck on");
await page.waitForTimeout(5000);
await $.shot("5_model.png");

// The sheet, downloaded and measured.
await $.click("stickers");
await page.waitForTimeout(3000);
await $.shot("6_sheet.png");
const pdf_at = await $.where("sheet_pdf");
const [download] = await Promise.all([
  page.waitForEvent("download", { timeout: 60000 }),
  page.mouse.click(pdf_at.x, pdf_at.y),
]);
const pdf = `${out}/stickers.pdf`;
await download.saveAs(pdf);
let measured = "";
try {
  measured = execFileSync("python3", ["tools/sticker_sheet_check.py", pdf, "--expect", args.expect || "31.4x15.4"],
    { encoding: "utf8" });
  ok(true, `the sheet's PDF, measured: ${measured.trim().split("\n").join(" / ")}`);
} catch (e) {
  ok(false, `the sheet's PDF, measured: ${String(e.stdout || e).trim()}`);
}
await $.click("sheet_close");

// The model, downloaded, and opened in a browser that has never seen it.
const export_at = await $.where("export");
const [exported] = await Promise.all([
  page.waitForEvent("download", { timeout: 60000 }),
  page.mouse.click(export_at.x, export_at.y),
]);
const model = resolve(`${out}/model.mpd`);
await exported.saveAs(model);
const text = await import("node:fs").then((fs) => fs.readFileSync(model, "utf8"));
const pictures = (text.match(/^0 !DATA /gm) || []).length;
ok(pictures >= 3 && /!TEXMAP START PLANAR/.test(text),
  `the exported model carries ${pictures} pictures as !DATA and its TEXMAP lines`);
await page.close();

const fresh = await page_for("second");
const $$ = tools(fresh);
await fresh.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await $$.until(async () => Boolean((await $$.controls()).open), 400, "app again"),
  "a second browser, with nothing kept, came up");
await fresh.waitForTimeout(Number(args.load || 15000));
ok((await $$.custom()).length === 0, "it has no parts made here");
await $$.open(model);
ok(await $$.until(async () => (await $$.custom()).length >= 3, 180, "model opened"),
  `opening the model builds its prints and sticker from the file: [${await $$.custom()}]`);
await fresh.waitForTimeout(10000);
await $$.shot("7_reopened.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `studio flow: ${failed} problem(s); screenshots in ${out}`
  : `studio flow: a photo, a logo and a sticker made in the browser, measured, carried and opened; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
