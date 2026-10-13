// The model as a 3D file, in a real browser: File > Export > 3D model…,
// GLB, and the download read back.
//
//   set -a; . ./.env; set +a
//   node tools/web/model3d_flow.mjs --url=http://127.0.0.1:8147/index.html --out=shots/model3d_web   (a local export)
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/model3d_flow.mjs --url=https://<a preview>/app
//
// Opens models/car.ldr through Open… > From a file (the page's own file
// picker, answered by Playwright), then File > Export > 3D model… by the keys
// a person would use in the menu, and Enter on the dialog, whose Export is
// GLB unless another was chosen. Catches the download and reads the GLB with
// Python: its header, a mesh node for each of the car's 61 parts, fewer
// meshes than parts (a shape in a colour each), and the see-through colours'
// alpha. While it is written the page's frames are timed: none may be held
// past a second (in software, where a frame of the model alone is hundreds
// of milliseconds). It fails if a step does not happen or a script error
// reaches the console.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(args.out || "shots/model3d_web");
mkdirSync(out, { recursive: true });
const car = resolve("models/car.ldr");

const t0 = Date.now();
const said = [];
const errors = [];
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) {
    errors.push(m.text().slice(0, 300));
  }
});

const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
    console.log(`        picture: ${out}/${name}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds) {
  let now = await state();
  for (let n = 0; n < seconds * 2; n++) {
    if (test(now)) return now;
    await page.waitForTimeout(500);
    now = await state();
  }
  return test(now) ? now : null;
}
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name}.png`);
  throw new Error(`the app never showed "${name}"`);
}
// Open… > From a file, answered with a file; tried again when no picker came
// (io_flow.mjs has the same).
async function open(file) {
  const at = await where("open");
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
    await shot(`no_picker_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}
// The page's frames, timed from now until stopFrames(): the longest gap.
async function startFrames() {
  await page.evaluate(() => {
    window.frameGaps = { last: performance.now(), most: 0, frames: 0, on: true };
    const tick = (now) => {
      const g = window.frameGaps;
      if (!g.on) return;
      g.most = Math.max(g.most, now - g.last);
      g.last = now;
      g.frames++;
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}
async function stopFrames() {
  return page.evaluate(() => {
    window.frameGaps.on = false;
    return { most: Math.round(window.frameGaps.most), frames: window.frameGaps.frames };
  });
}
// File > Export > 3D model…, by the menu's own keys, then Enter on the
// dialog. Tried again if no download came, as a click is.
async function export3d() {
  const file = await where("menu_file");
  for (let n = 0; n < 3; n++) {
    const download = page.waitForEvent("download", { timeout: 180000 }).catch(() => null);
    await page.mouse.click(file.x, file.y);
    await page.waitForTimeout(2500 + 2500 * n);
    await page.keyboard.type("Export", { delay: 120 });
    await page.waitForTimeout(800);
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(1500);
    // Down to its third line, as Shell.SUBMENUS orders Export. Not typed:
    // "3" is View, From the left, and the space in "3D model" pressed
    // whichever line was lit, so the first try downloaded the LDraw file.
    for (let down = 0; down < 2; down++) {
      await page.keyboard.press("ArrowDown");
      await page.waitForTimeout(800);
    }
    if (n === 0) await shot("2_export_menu.png");
    await page.keyboard.press("Enter");
    await page.waitForTimeout(4000 + 2000 * n);
    if (n === 0) await shot("3_dialog.png");
    await startFrames();
    await page.keyboard.press("Enter");
    const got = await download;
    const frames = await stopFrames();
    if (got) return { got, frames };
    await shot(`no_download_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return { got: null, frames: null };
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(Boolean(await where("open", 400)), "the app came up, signed in");
await page.waitForTimeout(Number(args.load || 15000));

let opened = null;
for (let attempt = 0; attempt < 3 && !opened; attempt++) {
  await open(car);
  opened = await until((s) => /^opened \d+ parts/.test(s.said || "") && !/arriving/.test(s.said || ""), 240);
  if (!opened) await page.waitForTimeout(20000);
}
ok((await state()).bricks === 61, `car.ldr opened through Open… > From a file: ${(await state()).bricks} parts`);
await page.waitForTimeout(6000);
await shot("1_car.png");

const { got: download, frames } = await export3d();
ok(Boolean(download) && /\.glb$/.test(download.suggestedFilename()),
  `File > Export > 3D model…, Export, downloads ${download ? download.suggestedFilename() : "nothing"}`);
const done = await until((s) => /^downloaded .*\.glb/.test(s.said || ""), 60);
ok(Boolean(done), `the status bar says so: "${(await state()).said}"`);
ok(frames && frames.most < 1000, `no frame held past a second while it was written: the longest ${frames ? frames.most : "?"} ms of ${frames ? frames.frames : "?"} frames`);
const exported = `${out}/car.glb`;
let read = {};
if (download) {
  await download.saveAs(exported);
  try {
    read = JSON.parse(execFileSync("python3", ["-I", "-c", `
import json, struct, sys
data = open(sys.argv[1], "rb").read()
magic, version, length = struct.unpack_from("<III", data, 0)
json_length, json_kind = struct.unpack_from("<II", data, 12)
doc = json.loads(data[20:20 + json_length])
bin_length, bin_kind = struct.unpack_from("<II", data, 20 + json_length)
alphas = sorted({round(m["pbrMetallicRoughness"]["baseColorFactor"][3], 3) for m in doc["materials"] if m.get("alphaMode") == "BLEND"})
print(json.dumps({"magic": magic == 0x46546C67, "version": version, "whole": length == len(data),
                  "json": json_kind == 0x4E4F534A, "bin": bin_kind == 0x004E4942 and bin_length == doc["buffers"][0]["byteLength"],
                  "parts": sum(1 for n in doc["nodes"] if "mesh" in n), "meshes": len(doc["meshes"]),
                  "materials": len(doc["materials"]), "alphas": alphas}))
`, exported], { encoding: "utf8" }));
  } catch (e) {
    read = { error: String(e.stderr || e).slice(0, 300) };
  }
}
ok(read.magic && read.version === 2 && read.whole && read.json && read.bin,
  `a GLB, version 2, its JSON and binary chunks whole: ${JSON.stringify(read.error || { bytes: download ? "saved" : 0 })}`);
ok(read.parts === 61 && read.meshes < 61,
  `a mesh node for each of the 61 parts (${read.parts}), sharing ${read.meshes} meshes in ${read.materials} colours`);
ok(Array.isArray(read.alphas) && read.alphas.length > 0 && read.alphas.every((a) => a > 0 && a < 1),
  `the see-through colours see-through: alpha ${JSON.stringify(read.alphas)}`);
await shot("4_done.png");
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
writeFileSync(`${out}/result.txt`, said.join("\n") + "\n");
console.log(failed
  ? `model3d flow: ${failed} problem(s); screenshots in ${out}`
  : `model3d flow: the car exported as a GLB from the menu and downloaded whole; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
