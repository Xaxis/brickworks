// Laying a hose and a chain, posing a hinge and exporting a short animation,
// in a real browser, as a person does it.
//
//   set -a; . ./.env; set +a
//   node tools/web/flex_pose_flow.mjs --url=https://<preview>.vercel.app/app --bypass=$VERCEL_BYPASS --out=shots/flex_pose_web
//
// The web build draws with the Compatibility renderer on one thread shared
// with everything else, which no desktop probe vouches for. This opens a
// small model through Open… > From a file (two Technic bricks with holes,
// two gears, and a crane: a turret on a turntable and an arm on a hinge,
// each a sub-model), then: Build, Hose, tube or chain… by the menu and the
// keys a person uses there; a click on one pin hole and another, which lays
// a pneumatic tube; Technic chain and a click on each gear, which lays a
// chain round them; Done. Build, Motions…, New motion: a click on the
// arm's slider and the turret's (Grab's joints), each a key at 2 s, Render
// animation — downloaded as an animated WebP the browser decodes, with as
// many frames as the motion's 2 s make. Fails if a control never appears, nothing is laid, a
// slider does not move its joint, the download is not an animation of the
// right number of frames, the page stops answering for longer than --stall
// seconds (default 3) during the render, or a script error reaches the
// console. Pictures of each step in OUT, and the WebP.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/flex_pose_web";
const stallLimit = Number(args.stall || 3) * 1000;
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

// The model: in LDraw's own coordinates (-Y up). Two Technic bricks with
// their holes to the front, two 24-tooth gears above, and the crane. Its
// hinge (3937 and 3938, turned about up) faces the way the arm rises: the
// base's top edge is square on one side and rounded on the other, so the
// top tips one way only. Faced the other way, the arm rose 6° before the
// top met its base, and swung down 17° onto the baseplate (pose_probe's
// crane had the same, docs/MECHANISMS.md sections 34 and 35).
const model = path.resolve(out, "flex_pose.mpd");
writeFileSync(model, [
  "0 FILE flex_pose.ldr",
  "0 Flex and pose",
  "0 Name: flex_pose.ldr",
  "1 7 -60 -24 60 1 0 0 0 1 0 0 0 1 3700.dat",
  "1 7 20 -24 60 1 0 0 0 1 0 0 0 1 3700.dat",
  "1 7 -80 -110 60 1 0 0 0 1 0 0 0 1 3648b.dat",
  "1 7 50 -110 60 1 0 0 0 1 0 0 0 1 3648b.dat",
  "1 7 0 -8 -80 1 0 0 0 1 0 0 0 1 3680.dat",
  "1 16 0 -8 -80 1 0 0 0 1 0 0 0 1 turret.ldr",
  "0",
  "0 FILE turret.ldr",
  "0 Turret",
  "0 Name: turret.ldr",
  "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3679.dat",
  "1 7 0 -24 0 -1 0 0 0 1 0 0 0 -1 3937.dat",
  "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 arm.ldr",
  "0",
  "0 FILE arm.ldr",
  "0 Arm",
  "0 Name: arm.ldr",
  "1 4 0 0 0 -1 0 0 0 1 0 0 0 -1 3938.dat",
  "1 4 0 -8 -50 0 0 1 0 1 0 -1 0 0 3795.dat",
  "0",
  "",
].join("\n"));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  if (/^render: /.test(m.text())) console.log(`      (${m.text()})`);
});
let failed = 0;
const t0 = Date.now();
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};

const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const flex = async () => (await page.evaluate(() => window.brickworksFlex || {})) || {};
const motions = async () => (await page.evaluate(() => window.brickworksMotions || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: path.join(out, name), timeout: 180000 });
    console.log(`        picture: ${path.join(out, name)}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function where(name, seconds = 120) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name}.png`);
  throw new Error(`the app never showed "${name}"`);
}
async function click(x, y) {
  await page.mouse.move(x, y, { steps: 4 });
  await page.waitForTimeout(400);
  await page.mouse.click(x, y);
  await page.waitForTimeout(1500);
}
async function press(name) {
  const at = await where(name);
  await click(at.x, at.y);
}
async function until(read, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    const now = await read();
    if (test(now)) return now;
    await page.waitForTimeout(500);
  }
  return null;
}
// A menu by its title, then the item a person would reach by typing its
// first letters, as every menu here lets them, and Enter.
async function menu(title, typed) {
  for (let attempt = 0; attempt < 3; attempt++) {
    await press(`menu_${title}`);
    await page.waitForTimeout(800);
    await page.keyboard.type(typed, { delay: 120 });
    await page.waitForTimeout(400);
    await page.keyboard.press("Enter");
    await page.waitForTimeout(2500);
    return;
  }
}
async function open(file) {
  const at = await where("open", 400);
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
// How long the page went without answering, from a timer every 50 ms.
async function heartbeat() {
  await page.evaluate(() => {
    window.__beat = { last: performance.now(), worst: 0 };
    setInterval(() => {
      const now = performance.now();
      window.__beat.worst = Math.max(window.__beat.worst, now - window.__beat.last - 50);
      window.__beat.last = now;
    }, 50);
  });
}
function webpFrames(file) {
  const bytes = readFileSync(file);
  if (bytes.slice(0, 4).toString() !== "RIFF" || bytes.slice(8, 12).toString() !== "WEBP") return -1;
  let at = 12;
  let frames = 0;
  while (at + 8 <= bytes.length) {
    const tag = bytes.slice(at, at + 4).toString();
    const length = bytes.readUInt32LE(at + 4);
    if (tag === "ANMF") frames += 1;
    at += 8 + length + (length & 1);
  }
  return frames;
}

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  check(Boolean(await where("open", 400)), "the app came up, signed in");
  await page.waitForTimeout(Number(args.load || 15000));

  // The model, opened; its parts are fetched as they are needed.
  let opened = null;
  for (let attempt = 0; attempt < 3 && !opened; attempt++) {
    await open(model);
    opened = await until(state, (s) => s.bricks === 9 && !/arriving/.test(s.said || ""), 240);
    if (!opened) await page.waitForTimeout(15000);
  }
  check(Boolean(opened), `the model opened: ${(await state()).bricks} parts`);
  await page.keyboard.press("Shift+F");
  await page.waitForTimeout(4000);
  await shot("1_model.png");

  // A pneumatic tube from one pin hole to the other.
  await menu("build", "Hose");
  const asking = await until(flex, (f) => f.active && f.stage === "start", 30);
  check(Boolean(asking), `Build, Hose, tube or chain… opens the tool (${asking && asking.told})`);
  const holes = ((await flex()).targets || []).filter((t) => t.kind === "pin_hole" && t.part === "3700");
  check(holes.length >= 2, `the two bricks' holes are there to click (${holes.length})`);
  holes.sort((a, b) => a.x - b.x);
  await click(holes[0].x, holes[0].y);
  const ending = await until(flex, (f) => f.stage === "end", 20);
  check(Boolean(ending), `a click on the first hole picks it (${ending && ending.told})`);
  const second = ((await flex()).targets || []).filter((t) => t.kind === "pin_hole"
    && t.brick === holes[holes.length - 1].brick)[0] || holes[holes.length - 1];
  await click(second.x, second.y);
  const tube = await until(flex, (f) => f.stage === "shaping" && f.pieces > 10, 120);
  check(Boolean(tube), `a click on the second lays a tube: ${tube && tube.item}, ${tube && tube.pieces} pieces, `
    + `${tube && tube.length} LDU (${tube && tube.status})`);
  await shot("2_tube.png");

  // A chain round the two gears. Said and carried on from if it fails, so
  // the posing below is tried either way.
  try {
    await press("flex_kind_chain");
    const sprockets = await until(flex, (f) => f.stage === "sprockets" && (f.targets || []).length >= 2, 30);
    check(Boolean(sprockets), `Technic chain asks for the sprockets (${sprockets && sprockets.told})`);
    for (const gear of ((await flex()).targets || []).filter((t) => t.part === "3648b")) {
      await click(gear.x, gear.y);
    }
    const chain = await until(flex, (f) => (f.links || 0) > 10, 120);
    check(Boolean(chain), `two clicks lay a chain round them: ${chain && chain.item}, ${chain && chain.links} links`);
    await shot("3_chain.png");
  } catch (trouble) {
    check(false, `the chain: ${trouble.message}`);
  }
  await press("flex_done");
  await page.waitForTimeout(2000);
  check(!(await flex()).active, "Done puts the tool away");

  // A motion for the crane, in Build, Motions….
  await menu("build", "Motions");
  const shown = await until(motions, (p) => p.open, 30);
  check(Boolean(shown), `Build, Motions… opens (${shown && shown.status})`);
  await shot("4_motions_panel.png");
  await press("motions_new");
  const editing = await until(motions, (p) => p.view === "edit" && (p.joints || []).length >= 2 && p.joints[0].x0, 30);
  check(Boolean(editing), `New motion offers a slider for each of Grab's joints: `
    + `${editing && editing.joints.map((j) => `${j.name} (${j.mode})`).join(", ")}`);
  const sliderAt = (joint, value) => ({
    x: Math.round(joint.x0 + 8 + (joint.x1 - joint.x0 - 16) * (value - joint.min) / (joint.max - joint.min)), y: joint.y,
  });
  const joints = (await motions()).joints;
  const arm = joints.find((j) => /Arm/.test(j.name)) || joints[1];
  const turret = joints.find((j) => /Turret/.test(j.name) && j !== arm) || joints.find((j) => j !== arm);
  const now = (p, joint) => p.joints.find((j) => j.name === joint.name) || {};
  // Up is whichever way the arm has room for: try one, and the other if it stopped short.
  let at = sliderAt(arm, -45);
  await click(at.x, at.y);
  let raised = await until(motions, (p) => Math.abs(now(p, arm).place) > 30, 20);
  if (!raised) {
    at = sliderAt(now(await motions(), arm).x0 ? now(await motions(), arm) : arm, 45);
    await click(at.x, at.y);
    raised = await until(motions, (p) => Math.abs(now(p, arm).place) > 30, 20);
  }
  check(Boolean(raised), `a click on the arm's slider puts a key, the arm swung on its hinge: `
    + `${raised && now(raised, arm).place}° at ${raised && raised.at} s (${raised && raised.status})`);
  const turretNow = now(await motions(), turret);
  at = sliderAt(turretNow.x0 ? turretNow : turret, 90);
  await click(at.x, at.y);
  const turned = await until(motions, (p) => Math.abs(now(p, turret).place - 90) <= 6, 20);
  check(Boolean(turned), `and the turret's turns it round: ${turned && now(turned, turret).place}°`);
  await shot("5_posed.png");
  const keyed = await until(motions, (p) => (p.motions || []).length === 1 && p.motions[0].tracks === 2, 10);
  check(Boolean(keyed), `one motion of two joints, kept with the model: `
    + `${keyed && keyed.motions.map((m) => `${m.name}, ${m.seconds} s`).join("; ")}; `
    + `${keyed && keyed.frames_planned} frames to draw`);

  // Render it.
  await heartbeat();
  const download = page.waitForEvent("download", { timeout: 15 * 60000 }).catch(() => null);
  await press("motions_render");
  let seen = null;
  for (let n = 0; n < 15 * 120; n++) {
    seen = await motions();
    if (n > 20 && !seen.working) break;
    if (n % 20 === 0) console.log(`      rendering: ${seen.status || ""}`);
    await page.waitForTimeout(500);
  }
  const got = await download;
  const stall = await page.evaluate(() => Math.round(window.__beat.worst));
  let file = null;
  if (got) {
    file = path.join(out, got.suggestedFilename());
    await got.saveAs(file);
  }
  const frames = file ? webpFrames(file) : -1;
  check(Boolean(file) && frames === (keyed && keyed.frames_planned),
    `Render animation downloads ${file && path.basename(file)}, an animated WebP of ${frames} frames`);
  check(stall <= stallLimit, `the page answered throughout: its longest wait ${stall} ms `
    + `(the render's longest frame ${seen && seen.worst_frame_ms} ms, ${seen && seen.worst_step})`);
  await shot("6_rendered.png");
  // The browser decodes it: the first and the middle frame drawn on a page.
  if (file) {
    const data = readFileSync(file).toString("base64");
    // From its bytes, not fetch(data:): the app's security policy lets the
    // page fetch from its own site only.
    const decoded = await page.evaluate(async (b64) => {
      const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
      const blob = new Blob([bytes], { type: "image/webp" });
      const bitmap = await createImageBitmap(blob);
      return [bitmap.width, bitmap.height];
    }, data);
    check(decoded[0] > 0 && decoded[1] > 0, `and the browser decodes it (${decoded.join(" x ")})`);
  }
} catch (trouble) {
  check(false, `stopped: ${trouble.message}`);
  await shot("stopped.png");
}

check(errors.length === 0, `no script errors (${errors.slice(0, 3).join(" | ")})`);
console.log(failed === 0 ? "flex and pose in a browser: all passed" : `flex and pose in a browser: ${failed} FAILED`);
await browser.close();
process.exit(failed === 0 ? 0 : 1);
