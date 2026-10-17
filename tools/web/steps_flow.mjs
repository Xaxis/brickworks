// The author's build steps in a real browser: a model made in another tool,
// opened with its steps, a part moved a step by hand, and the file saved
// out with the move in it.
//
//   set -a; . ./.env; set +a
//   node tools/web/steps_flow.mjs --url=http://127.0.0.1:8147/index.html --out=shots/steps_web   (a local export)
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/steps_flow.mjs --url=https://<a preview>/app
//
// Opens tests/fixtures/steps/gatehouse.mpd (five steps of its own, a base in
// two and a window in three) through Open… > From a file, the page's own file
// picker answered by Playwright. Presses the toolbar's Timeline: it has to
// come up in the author's steps, "Step 1 of 6". Next twice is step 3, the
// yellow brick; a click on that brick where the page says it is drawn
// (brickworksLayout.targets) selects it, and Shift-] moves it into the next
// step, the blue brick's: the caption reads "Step 3 of 5" and names both.
// Ctrl-Z puts it back ("of 6"); Shift-] again, then File > Export > LDraw
// model downloads the model, and Python reads its main model's steps: four,
// the yellow brick with the blue. Every result is read off
// window.brickworksState; pictures in --out. It fails if a step does not
// happen or a script error reaches the console.
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
const out = resolve(args.out || "shots/steps_web");
mkdirSync(out, { recursive: true });
const gatehouse = resolve("tests/fixtures/steps/gatehouse.mpd");

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
const layout = async () => (await page.evaluate(() => window.brickworksLayout || {})) || {};
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
async function press(name) {
  const at = await where(name);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}
const caption = async () => ((await state()).timeline || {}).caption || "";
// Open… > From a file, answered with a file: tried again when a press
// brought no picker, as io_flow.mjs does.
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
// File > Export > LDraw model, by the menu's own keys, as io_flow.mjs exports.
async function exportLdraw() {
  const file = await where("menu_file");
  for (let n = 0; n < 3; n++) {
    const download = page.waitForEvent("download", { timeout: 90000 }).catch(() => null);
    await page.mouse.click(file.x, file.y);
    await page.waitForTimeout(2500 + 2500 * n);
    await page.keyboard.type("Export", { delay: 120 });
    await page.waitForTimeout(800);
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(1500);
    await page.keyboard.type("LDraw", { delay: 120 });
    await page.waitForTimeout(800);
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

// The model in, every part of it: a part still arriving is fetched and the
// model opened again, as the status bar tells a person to.
let note = null;
for (let attempt = 0; attempt < 3; attempt++) {
  await open(gatehouse);
  note = await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
  console.log(`        the status bar: "${note ? note.said : (await state()).said}"`);
  if (note && !/arriving/.test(note.said)) break;
  await page.waitForTimeout(20000);
}
ok((await state()).bricks === 14, `gatehouse.mpd opened through Open… > From a file: ${(await state()).bricks} parts`);
await page.waitForTimeout(4000);

// The timeline, in the author's steps.
await press("tool_timeline");
const up = await until((s) => (s.timeline || {}).caption, 60);
ok(Boolean(up) && up.timeline.order === "Author's steps" && /^Step 1 of 6/.test(up.timeline.caption),
  `Timeline comes up in the author's steps: ${up ? `${up.timeline.order}, "${up.timeline.caption}"` : "nothing"}`);
await press("steps_next");
await press("steps_next");
const third = await until((s) => /^Step 3 of 6/.test((s.timeline || {}).caption || ""), 30);
ok(Boolean(third) && /Brick 2 x 2/.test(third.timeline.pieces),
  `Next twice is step 3, the yellow brick: "${await caption()}" — "${((await state()).timeline || {}).pieces}"`);
await shot("1_step_3.png");

// The yellow brick, clicked where it is drawn.
// The app publishes where parts are drawn when asked (centre_check.mjs).
let target = null;
for (let n = 0; n < 40 && !target; n++) {
  if (n % 8 === 0) {
    await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  }
  target = ((await layout()).targets || []).find((t) => t.part === "3003");
  if (!target) await page.waitForTimeout(500);
}
ok(Boolean(target), `the page says where the yellow brick is drawn (${target ? `${target.x}, ${target.y}` : "nowhere"})`);
if (target) {
  await page.mouse.click(target.x, target.y);
  await page.waitForTimeout(1500);
}
const picked = await until((s) => s.selected === 1 && target && s.selection[0] === target.brick, 20);
ok(Boolean(picked), `a click on it selects it (${(await state()).selected} selected)`);

await page.keyboard.press("Shift+BracketRight");
const moved = await until((s) => /^Step 3 of 5/.test((s.timeline || {}).caption || ""), 30);
ok(Boolean(moved) && /Brick 2 x 2/.test(moved.timeline.pieces) && /Brick 1 x 1/.test(moved.timeline.pieces),
  `Shift-] moves it into the next step, with the blue brick: "${await caption()}" — "${((await state()).timeline || {}).pieces}"`);
ok(/moved 1 part to the next step/.test((await state()).said || ""), `and the status bar says so: "${(await state()).said}"`);
await shot("2_moved.png");
await page.keyboard.press("Control+z");
const back = await until((s) => / of 6/.test((s.timeline || {}).caption || ""), 30);
ok(Boolean(back), `Ctrl-Z takes it back: "${await caption()}"`);
await page.keyboard.press("Shift+BracketRight");
ok(Boolean(await until((s) => / of 5/.test((s.timeline || {}).caption || ""), 30)),
  `moved again: "${await caption()}"`);

// ...and out as a file, the move in it.
await press("steps_done");
const download = await exportLdraw();
ok(Boolean(download), `File > Export > LDraw model downloads ${download ? download.suggestedFilename() : "nothing"}`);
let steps = {};
if (download) {
  const saved = `${out}/gatehouse.mpd`;
  await download.saveAs(saved);
  try {
    steps = JSON.parse(execFileSync("python3", ["-I", "-c", `
import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
main = text.split("0 NOFILE")[0]
steps, now = [], []
for line in main.splitlines():
    # A ROTSTEP ends a step as a STEP does (MLCad, LDraw's model
    # repository): counted only by STEP, the gatehouse's windows ran into
    # the blue brick's step once its ROTSTEP was kept on export (m65).
    if line.startswith("0 STEP") or line.startswith("0 ROTSTEP"):
        steps.append(sorted(now)); now = []
    elif line.startswith("1 "):
        f = line.split()
        now.append(f[-1].lower() + "/" + f[1])
if now:
    steps.append(sorted(now))
# The steps said to be the author's, as LdrModel.steps_are_authored reads
# it: the app's line, or the author's own name kept on a file that is
# theirs (the gatehouse, written back as it came with only the move in it).
author = next((l.split(":", 1)[1].strip() for l in text.splitlines() if l.startswith("0 Author:")), "")
marked = "0 !BRICKWORKS WORKED_STEPS" not in text and (
    "0 !BRICKWORKS AUTHORED_STEPS" in text or (author != "" and author != "Brickworks"))
print(json.dumps({"steps": [" ".join(s) for s in steps], "marked": marked}))
`, saved], { encoding: "utf8" }));
  } catch (e) {
    steps = { error: String(e.stderr || e).slice(0, 300) };
  }
}
ok(steps.steps && steps.steps.length === 4 && steps.steps[1] === "3003.dat/14 3005.dat/1" && steps.marked,
  `its model has four steps of its own, the yellow brick in the second with the blue: ${JSON.stringify(steps.steps || steps.error)}`);
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
writeFileSync(`${out}/result.txt`, said.join("\n") + "\n");
console.log(failed
  ? `steps flow: ${failed} problem(s); screenshots in ${out}`
  : `steps flow: the author's steps opened, a part moved a step by hand and undone, and the export keeps the move; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
