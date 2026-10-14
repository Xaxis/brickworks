// Decorated parts in a real browser, as a person adds them by hand: a picture
// from a file printed on a 2 x 2 tile, a sticker stuck across two 1 x 4
// tiles, one of those tiles swapped for a printed version the LEGO Group
// made of it (Properties > Printed versions…), the model taken out as a
// BrickLink Studio .io and brought back in a browser that has never seen it,
// and a Studio file's own print, sticker and Part Designer decal opened.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/decor_flow.mjs --url=https://<a preview>/app --out=shots/decor_web
//   node tools/web/decor_flow.mjs --url=http://127.0.0.1:8147/index.html --out=…   (a local export)
//
// Opens tests/fixtures/prints/scene.ldr through Open… > From a file; Print…
// with "or print on" 3068b and a photograph through Add a picture… (the
// page's own file input), covered, saved and clicked down; Stickers… > New
// sticker…, a click on the two tiles, filled and saved; a click on a tile,
// Properties' Printed versions…, the first print chosen; File > Export >
// BrickLink Studio model (.io), read with Python's zipfile (CustomParts/
// holds the sticker and the print with PE_TEX lines, model.ldr the same as
// TEXMAP); then in a second, empty browser that .io and
// tests/fixtures/studio/decor_2025.io opened. It fails if a control never
// appears, a part is not made or swapped, the .io does not carry ours in
// Studio's form, a model does not come back with its decorated parts
// (window.brickworksState.custom and .parts), or a script error reaches the
// console.
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(args.out || "shots/decor_web");
mkdirSync(out, { recursive: true });
const photo = args.photo || "/usr/share/backgrounds/Monument_valley_by_orbitelambda.jpg";
const scene = resolve("tests/fixtures/prints/scene.ldr");
const studioFile = resolve("tests/fixtures/studio/decor_2025.io");

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

async function pageFor(name) {
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
  // One listener from the start: Playwright catches a file picker only while
  // something listens (studio_flow.mjs says why at length).
  page.choosers = [];
  page.on("filechooser", (chooser) => page.choosers.push(chooser));
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
  const state = () => page.evaluate(() => window.brickworksState || {});
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
      if (n % 10 === 9) await openColumnFor(page, what);
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
  // A press that opens a file picker, answered with a file; pressed again
  // when no picker came, since the app reads a click a frame or more late.
  async function picked(press, file, what) {
    for (let n = 0; n < 3; n++) {
      page.choosers.length = 0;
      await press(n);
      for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
        await page.waitForTimeout(500);
      }
      const picker = page.choosers.shift();
      if (picker) {
        await picker.setFiles(file);
        return;
      }
      await shot(`no_picker_${what}_${n}.png`);
      if (what === "open") await page.keyboard.press("Escape");
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
      await page.waitForTimeout(4000 + 4000 * n);
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
  const custom = async () => (await state()).custom || [];
  const parts = async () => (await state()).parts || [];
  return { controls, state, shot, until, where, click, choose, open, type, custom, parts };
}

// File > Export > BrickLink Studio model (.io), by the menu's keys, as
// io_flow.mjs does it (and says why not by typing its name).
async function exportStudio(page, $) {
  const file = await $.where("menu_file");
  for (let n = 0; n < 3; n++) {
    const download = page.waitForEvent("download", { timeout: 90000 }).catch(() => null);
    await page.mouse.click(file.x, file.y);
    await page.waitForTimeout(2500 + 2500 * n);
    await page.keyboard.press("E");
    await page.waitForTimeout(800);
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(1500);
    await page.keyboard.press("ArrowDown");
    await page.waitForTimeout(800);
    await page.keyboard.press("Enter");
    const got = await download;
    if (got) return got;
    await $.shot(`no_download_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return null;
}

const page = await pageFor("first");
const $ = tools(page);
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(await $.until(async () => Boolean((await $.controls()).open), 400, "app"), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));

await $.open(scene);
ok(await $.until(async () => (await $.state()).bricks >= 4, 120, "scene"),
  `the scene opened through Open… > From a file: ${(await $.state()).bricks} parts`);
await page.waitForTimeout(8000);

// 1. A picture from a file, printed on a 2 x 2 tile and clicked down.
await $.click("print part");
await $.type("print_other", "3068b");
await $.click("print_on_it");
await $.until(async () => Boolean((await $.controls()).print_area_top), 120, "tile top");
await $.choose("print_add_picture", photo);
ok(await $.until(async () => Boolean((await $.controls()).print_fill), 60, "picture panel"),
  "a photograph from a file on the computer, through Add a picture…");
await $.click("print_fill");
await $.type("print_name", "Valley");
let before = await $.custom();
await $.click("print_save");
ok(await $.until(async () => (await $.custom()).some((id) => /^bw-3068b-p/.test(id) && !before.includes(id)),
  120, "print saved"), `printed and saved: ${(await $.custom()).filter((id) => /^bw-3068b-p/.test(id))}`);
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
ok((await count()) > bricks, `the printed tile clicked down in the model: ${bricks} parts, then ${await count()}`);
await page.keyboard.press("Escape");
await page.waitForTimeout(2000);
await $.shot("1_printed.png");

// 2. A sticker across the two 1 x 4 tiles in the middle of the view.
await $.click("stickers");
await $.click("sheet_new");
const view = await $.where("view");
await page.mouse.click(view.x, view.y);
await page.waitForTimeout(2000);
const canvas = await $.where("print_canvas");
await $.click("print_tool_fill");
await $.click("print_ink_1");
await page.mouse.click(canvas.x, canvas.y);
await page.waitForTimeout(1000);
await $.type("print_name", "Blue Street");
before = await $.custom();
await $.click("print_save");
ok(await $.until(async () => (await $.custom()).some((id) => /^bw-st-/.test(id) && !before.includes(id)),
  120, "sticker saved"), "a sticker drawn, saved and stuck on the two tiles");
await page.waitForTimeout(4000);
await $.shot("2_sticker.png");

// 3. One of the tiles swapped for a printed version: click it (the film has
// no cover, so the click finds the tile under it), then Printed versions…
await page.keyboard.press("Escape");
await page.waitForTimeout(1500);
let picked = false;
for (const [dx, dy] of [[0, 0], [0, 14], [0, -14], [24, 0]]) {
  await page.mouse.click(view.x + dx, view.y + dy);
  await page.waitForTimeout(2500);
  if ((await $.state()).selected === 1 && (await $.controls()).prop_versions) {
    picked = true;
    break;
  }
}
ok(picked, "a click on a tile picks it, and Properties offers its printed versions");
const versionsBefore = new Set(await $.parts());
await $.click("prop_versions");
ok(await $.until(async () => Boolean((await $.controls()).version_1), 120, "versions"),
  "Printed versions… shows the prints the LEGO Group made of it");
await page.waitForTimeout(6000);
await $.shot("3_versions.png");
await $.click("version_1");
ok(await $.until(async () => (await $.parts()).some((id) => /^2431[pd]/.test(id) && !versionsBefore.has(id)),
  120, "swapped"), `swapped where it stands for ${(await $.parts()).filter((id) => /^2431[pd]/.test(id))}`);
await page.waitForTimeout(4000);
await $.shot("4_swapped.png");

// 4. Out as a Studio file, ours carried in Studio's form.
const download = await exportStudio(page, $);
ok(Boolean(download), `File > Export > BrickLink Studio model downloads ${download ? download.suggestedFilename() : "nothing"}`);
const exported = `${out}/decorated.io`;
let members = {};
if (download) {
  await download.saveAs(exported);
  try {
    members = JSON.parse(execFileSync("python3", ["-I", "-c", `
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
assert z.testzip() is None
ldr = z.read("model.ldr").decode("utf-8")
custom = {n: z.read(n).decode("utf-8") for n in z.namelist() if n.startswith("CustomParts/")}
print(json.dumps({"names": z.namelist(), "texmap": ldr.count("!TEXMAP START"),
                  "data": ldr.count("0 !DATA "),
                  "custom": {n: [t.count("PE_TEX_INFO"), t.count("PE_TEX_PATH"), "!TEXMAP" in t]
                             for n, t in custom.items()}}))
`, exported], { encoding: "utf8" }));
  } catch (e) {
    members = { error: String(e.stderr || e).slice(0, 300) };
  }
}
const carried = members.custom || {};
const studioForm = Object.entries(carried).filter(([, c]) => c[0] >= 1 && c[1] >= 1 && !c[2]).map(([n]) => n);
ok(studioForm.some((n) => /bw-st-/.test(n)) && studioForm.some((n) => /bw-3068b-p/.test(n)),
  `its CustomParts/ carry the sticker and the print with Studio's PE_TEX lines: ${JSON.stringify(carried)}`);
ok(members.texmap >= 2 && members.data >= 2,
  `and its model.ldr the same as LDraw has them: ${members.texmap} TEXMAP blocks, ${members.data} pictures as !DATA`);
await page.close();

// 5. Brought back in a browser that has never seen any of it, and a Studio
// file's own print, sticker and Part Designer decal opened.
const fresh = await pageFor("second");
const $$ = tools(fresh);
await fresh.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(await $$.until(async () => Boolean((await $$.controls()).open), 400, "app again"),
  "a second browser, with nothing kept, came up");
await fresh.waitForTimeout(Number(args.load || 15000));
if (download) {
  await $$.open(exported);
  ok(await $$.until(async () => {
    const made = await $$.custom();
    const now = await $$.parts();
    return made.some((id) => /^bw-st-/.test(id)) && made.some((id) => /^bw-3068b-p/.test(id))
      && now.some((id) => /^2431[pd]/.test(id));
  }, 240, "io reopened"), `the .io opens with its print, its sticker and the printed version: [${await $$.custom()}]`);
  await fresh.waitForTimeout(8000);
  await $$.shot("5_reopened.png");
}
await $$.open(studioFile);
ok(await $$.until(async () => {
  const made = await $$.custom();
  return ["bl_3068pb9001", "bl_2431pb9002", "m1a2b3c4_2025408_170000"].every((id) => made.includes(id));
}, 240, "studio file"), `a Studio file's print, sticker and Part Designer decal open: [${(await $$.custom()).filter((id) => !/^bw-/.test(id))}]`);
await fresh.waitForTimeout(8000);
await $$.shot("6_studio_file.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
writeFileSync(`${out}/result.txt`, said.join("\n") + "\n");
console.log(failed
  ? `decor flow: ${failed} problem(s); screenshots in ${out}`
  : `decor flow: a picture printed from a file, a sticker stuck on, a tile swapped for a printed version, a .io out and in, and a Studio file's decorations, in the browser; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
