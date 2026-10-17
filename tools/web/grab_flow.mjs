// Grabbing a part in the view and moving it on its joint, in a real browser,
// by mouse, as a person does it with the Select tool.
//
//   set -a; . ./.env; set +a
//   node tools/web/grab_flow.mjs --url=https://<preview>.vercel.app/app --bypass=$VERCEL_BYPASS --out=shots/grab_web
//   node tools/web/grab_flow.mjs --url=http://127.0.0.1:8820/ --out=shots/grab_web
//
// The web build draws with the Compatibility renderer on one thread shared
// with everything else, which no desktop probe vouches for. This opens a
// small crane through Open… > From a file (a turret on a turntable, an arm on
// a hinge on it, no sub-models: the joints are read off the parts), then
// takes hold of the arm with the mouse (window.brickworksGrab says where it
// is on the page) and drags it up: the arm turns on its hinge while the
// button is down, the status bar says what moves and how the model stands,
// and letting go keeps it as one step. Ctrl+Z puts it back where it was. Then
// the turret is dragged round on its turntable, carrying the arm. Fails if
// nothing turns, the arm does not come back on undo, the page stops answering
// for longer than --stall ms (default 250) during a drag, or a script error
// reaches the console. Pictures of each step in OUT, and the app's own frame
// costs for a drag.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/grab_web";
const stallLimit = Number(args.stall || 250);
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

// LDraw's own coordinates (-Y up): a 2x2 turntable on a 4x4 plate, a hinge
// brick on the turntable's top and a long arm on the hinge's top.
const model = path.resolve(out, "grab_crane.ldr");
writeFileSync(model, [
  "0 Grab crane",
  "0 Name: grab_crane.ldr",
  "1 71 0 0 0 1 0 0 0 1 0 0 0 1 3031.dat",
  "1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat",
  "1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat",
  "1 15 0 -32 0 1 0 0 0 1 0 0 0 1 3937.dat",
  "1 4 0 -32 0 1 0 0 0 1 0 0 0 1 3938.dat",
  "1 4 0 -40 -50 0 0 1 0 1 0 -1 0 0 3795.dat",
  "",
].join("\n"));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
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
const grab = async () => (await page.evaluate(() => window.brickworksGrab || {})) || {};
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
async function until(read, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    const now = await read();
    if (test(now)) return now;
    await page.waitForTimeout(500);
  }
  return null;
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
async function heartbeat() {
  await page.evaluate(() => {
    window.__beat = { last: performance.now(), worst: 0 };
    clearInterval(window.__beatTimer);
    window.__beatTimer = setInterval(() => {
      const now = performance.now();
      window.__beat.worst = Math.max(window.__beat.worst, now - window.__beat.last - 50);
      window.__beat.last = now;
    }, 50);
  });
}
// A drag by mouse from a handle: down, along a line in steps, a picture
// half way, up. Returns the app's state mid-drag.
async function drag(from, by, steps, picture) {
  await page.mouse.move(from.x, from.y, { steps: 3 });
  await page.waitForTimeout(600);
  await heartbeat();
  await page.mouse.down();
  let mid = null;
  for (let n = 1; n <= steps; n++) {
    await page.mouse.move(from.x + by.x * n / steps, from.y + by.y * n / steps);
    await page.waitForTimeout(60);
    if (n === Math.round(steps / 2)) {
      await page.waitForTimeout(700);
      mid = await grab();
      await shot(picture);
    }
  }
  await page.waitForTimeout(500);
  const stall = await page.evaluate(() => Math.round(window.__beat.worst));
  await page.mouse.up();
  await page.waitForTimeout(1500);
  return { mid, stall };
}

const timings = {};
try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  check(Boolean(await where("open", 400)), "the app came up");
  await page.waitForTimeout(Number(args.load || 15000));
  let opened = null;
  for (let attempt = 0; attempt < 3 && !opened; attempt++) {
    await open(model);
    opened = await until(state, (s) => s.bricks === 6 && !/arriving/.test(s.said || ""), 240);
    if (!opened) await page.waitForTimeout(15000);
  }
  check(Boolean(opened), `the crane opened: ${(await state()).bricks} parts`);
  await page.keyboard.press("Shift+F");
  await page.waitForTimeout(4000);
  const ready = await until(grab, (g) => (g.handles || []).length >= 2, 60);
  check(Boolean(ready), `the arm and the turret are there to take hold of: `
    + `${ready ? ready.handles.map((h) => `${h.part} on its ${h.kind}`).join(", ")
      : JSON.stringify(await grab())}`);
  if (!ready) throw new Error("no handles to take hold of");
  await shot("1_before.png");
  const arm = ready.handles.find((h) => h.part === "3795") || ready.handles.find((h) => h.kind === "hinge");
  const revision = (await grab()).revision;

  // The arm, up on its hinge.
  const up = await drag(arm, { x: 0, y: -160 }, 24, "2_arm_mid_drag.png");
  check(Boolean(up.mid && up.mid.grabbing && Math.abs(up.mid.angle || 0) > 5),
    `while the button is down the arm turns on its hinge: ${up.mid && up.mid.angle}° (${up.mid && up.mid.what})`);
  const after = await until(grab, (g) => !g.grabbing && g.revision !== revision, 10);
  check(Boolean(after) && /hinge/.test(after.said || ""),
    `let go, it is kept and said: "${after && after.said}"`);
  check(up.stall <= stallLimit, `the page answered throughout the drag: its longest wait ${up.stall} ms`);
  timings.arm = { frames: after && after.frames, mean_ms: after && after.mean_ms,
    worst_ms: after && after.worst_ms, stall_ms: up.stall };
  console.log(`      the app's own cost of a drag frame: mean ${after && after.mean_ms} ms, worst `
    + `${after && after.worst_ms} ms over ${after && after.frames} frames`);
  await shot("3_arm_after.png");
  const moved = (await until(grab, (g) => (g.handles || []).length >= 2, 10)).handles
    .find((h) => h.id === arm.id);
  // A 30 degree turn on the hinge moves the arm's middle a dozen or so
  // pixels at this distance: well past the 2 the undo is held to below.
  check(Boolean(moved) && Math.hypot(moved.x - arm.x, moved.y - arm.y) > 8,
    `the arm stands somewhere else now (${moved && moved.x},${moved && moved.y} from ${arm.x},${arm.y})`);

  // Undo: back where it was.
  await page.keyboard.press("Control+z");
  await page.waitForTimeout(2500);
  const back = (await until(grab, (g) => (g.handles || []).some((h) => h.id === arm.id), 10)).handles
    .find((h) => h.id === arm.id);
  check(Boolean(back) && Math.hypot(back.x - arm.x, back.y - arm.y) <= 2,
    `Ctrl+Z puts the arm back as one step (${back && back.x},${back && back.y})`);

  // The turret round on its turntable, carrying the arm.
  const turret = (await grab()).handles.find((h) => h.kind === "turntable");
  if (check(Boolean(turret), "the turret is there to take hold of")) {
    const round = await drag(turret, { x: 140, y: 30 }, 20, "4_turret_mid_drag.png");
    check(Boolean(round.mid && round.mid.grabbing && Math.abs(round.mid.angle || 0) > 5),
      `the turret turns on its turntable: ${round.mid && round.mid.angle}° (${round.mid && round.mid.what})`);
    const kept = await until(grab, (g) => !g.grabbing && /turntable/.test(g.said || ""), 10);
    check(Boolean(kept), `and is kept: "${kept && kept.said}"`);
    timings.turret = { frames: kept && kept.frames, mean_ms: kept && kept.mean_ms,
      worst_ms: kept && kept.worst_ms, stall_ms: round.stall };
    await shot("5_turret_after.png");
  }
} catch (trouble) {
  check(false, `stopped: ${trouble.message}`);
  await shot("stopped.png");
}
writeFileSync(path.join(out, "timings.json"), JSON.stringify(timings, null, 2));
check(errors.length === 0, `no script errors (${errors.slice(0, 3).join(" | ")})`);
console.log(failed === 0 ? "grab in a browser: all passed" : `grab in a browser: ${failed} FAILED`);
await browser.close();
process.exit(failed === 0 ? 0 : 1);
