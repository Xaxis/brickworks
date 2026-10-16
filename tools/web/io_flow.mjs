// BrickLink Studio's .io in a real browser, as a Studio builder uses it:
// bring a model in, take it back out, and bring that in again.
//
//   set -a; . ./.env; set +a
//   node tools/web/io_flow.mjs --url=http://127.0.0.1:8147/index.html --out=shots/io_web   (a local export)
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/io_flow.mjs --url=https://<a preview>/app
//
// Opens tests/fixtures/studio/bay_2025.io (made in the shape Studio 2.25
// saves one, by tests/fixtures/studio/make_fixtures.py) through Open… > From
// a file, the page's own file picker answered by Playwright, and checks its
// five parts came in and that the status bar names the one only Studio has.
// Then File > Export > BrickLink Studio model (.io), by the keys a person
// would use in the menu (exportStudio says which, and why not its name
// typed), catches the download and reads it with Python's
// zipfile: model.ldr, .info, errorPartList.err and a thumbnail. Opens that
// file again through the picker and checks the same five parts. Last, a
// picture renamed .io: the status bar has to say it is not a Studio file.
// Every result is read off window.brickworksState; pictures in --out. It
// fails if a step does not happen or a script error reaches the console.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync, copyFileSync } from "node:fs";
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
const out = resolve(args.out || "shots/io_web");
mkdirSync(out, { recursive: true });
const bay = resolve("tests/fixtures/studio/bay_2025.io");
const notStudio = `${out}/holiday.io`;
copyFileSync(resolve("web/favicon-32.png"), notStudio);

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
// Open… > From a file, answered with a file. The app reads a click a frame
// or more after the page does, so a press that brought no picker is tried
// again (studio_flow.mjs has the same reason at length).
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
// File > Export > BrickLink Studio model (.io), by the menu's own keys: the
// File menu, E for its one line that starts so, the arrow into Export, down
// one from the LDraw model to the Studio one, Enter. Tried again if no
// download came, as a click is.
//
// Not by typing "BrickLink Studio". A menu's search moves to the next line
// that starts with what has been typed, so letter by letter it swings
// between "BrickLink Studio model" and "BrickLink wanted list", and the
// space chooses wherever it is. It also starts again when two keys reach the
// app more than two seconds apart, which one slow software frame does. So
// the line chosen depended on the frame times: on a busy machine the
// download was the wanted list, bay_2025_bricklink.xml.
async function exportStudio() {
  const file = await where("menu_file");
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
    if (n === 0) await shot("2_export_menu.png");
    await page.keyboard.press("Enter");
    const got = await download;
    if (got) return got;
    await shot(`no_download_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return null;
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(Boolean(await where("open", 400)), "the app came up, signed in");
await page.waitForTimeout(Number(args.load || 15000));

// A Studio model in. In a browser a part not yet fetched is said to be
// arriving, and the model is opened again once it has, as the status bar
// tells a person to.
let note = null;
for (let attempt = 0; attempt < 3; attempt++) {
  await open(bay);
  note = await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
  console.log(`        the status bar: "${note ? note.said : (await state()).said}"`);
  if (note && !/arriving/.test(note.said)) break;
  await page.waitForTimeout(20000);
}
ok((await state()).bricks === 5, `bay_2025.io opened through Open… > From a file: ${(await state()).bricks} parts`);
ok(Boolean(note) && /opened 5 parts/.test(note.said)
  && /1 not shown, kept in the file \(m1a2b3c4_2025408_163200\)/.test(note.said),
  `and the status bar names the part only Studio has: "${note ? note.said : ""}"`);
await page.waitForTimeout(6000);
await shot("1_bay.png");

// ...and out again, as a Studio file.
const download = await exportStudio();
ok(Boolean(download), `File > Export > BrickLink Studio model downloads ${download ? download.suggestedFilename() : "nothing"}`);
const exported = `${out}/exported.io`;
let members = {};
if (download) {
  await download.saveAs(exported);
  try {
    members = JSON.parse(execFileSync("python3", ["-I", "-c", `
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
assert z.testzip() is None
ldr = z.read("model.ldr").decode("utf-8")
print(json.dumps({"names": z.namelist(), "parts": sum(1 for l in ldr.splitlines() if l.startswith("1 ")),
                  "crlf": "\\r\\n" in ldr, "info": json.loads(z.read(".info")),
                  "thumbnail": z.read("thumbnail.png")[:8].hex() if "thumbnail.png" in z.namelist() else ""}))
`, exported], { encoding: "utf8" }));
  } catch (e) {
    members = { error: String(e.stderr || e).slice(0, 300) };
  }
}
ok(download && /\.io$/.test(download.suggestedFilename())
  && JSON.stringify(members.names) === JSON.stringify(["model.ldr", ".info", "errorPartList.err", "thumbnail.png"]),
  `a zip Python's zipfile tests clean, holding ${JSON.stringify(members.names || members.error)}`);
// Six: the five shown and the one only Studio has, kept in the file
// (SourceFile) where it was left out before 2026-10-16.
ok(members.info && members.info.total_parts === 6 && members.crlf && members.thumbnail === "89504e470d0a1a0a",
  `its model.ldr in Studio's line ends, .info counting ${members.info ? members.info.total_parts : "?"} parts, `
  + `and a PNG thumbnail drawn in the browser (${members.thumbnail ? "PNG" : "none"})`);

// ...and that file in again.
if (download) {
  await open(exported);
  const again = await until((s) => /^opened \d+ parts/.test(s.said || "") && s.bricks === 5, 240);
  ok(Boolean(again), `the exported .io opens again: ${(await state()).bricks} parts, "${(await state()).said}"`);
  await page.waitForTimeout(4000);
  await shot("3_reopened.png");
}

// A picture called .io is not a Studio model, and is said not to be.
await open(notStudio);
const refused = await until((s) => /not a Studio \.io file/.test(s.said || ""), 60);
ok(Boolean(refused) && (await state()).bricks === 5,
  `a picture renamed .io is refused, the model left as it was: "${(await state()).said}"`);
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
writeFileSync(`${out}/result.txt`, said.join("\n") + "\n");
console.log(failed
  ? `io flow: ${failed} problem(s); screenshots in ${out}`
  : `io flow: a Studio model opened, exported as .io, opened again, and a non-Studio file refused; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
