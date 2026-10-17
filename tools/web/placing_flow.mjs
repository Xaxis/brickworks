// What the ghost shows is where the part goes, in the browser: each part
// aimed by the pointer as a person aims it, the ghost read (its whole pose,
// brickworksState.ghost_pose), a click, and the part put down
// (brickworksState.put) compared with that ghost.
//
//   python3 tools/web/serve.py build/web 8931 --parts assets/generated/parts --delay 0 &
//   node --env-file=.env tools/web/placing_flow.mjs --url=http://127.0.0.1:8931/ \
//       --out=bench/results/placing-<date>/web [--only=edge,parts]
//
// edge   one 4081b clip plate over the front edge of a 2 x 2 plate, the
//        pointer stepped across the edge a third of a pixel at a time. The
//        browser tells Godot a move to the fraction of a pixel and a click
//        in whole pixels, and a click re-aimed there struck the face beside
//        the one the ghost was on: the plane's clip plates went down a stud
//        forward (2026-10-16).
// parts  awkward parts, each aimed at the plate and clicked: a clip, a bar,
//        hinges, a slope, a Technic plate swung on a pin by the Turn setting
//        (8841-1's 4262), each compared ghost against put-down.
//
// Pictures of each put-down go to --out for a person to look at.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { keysFor, project, turnFor } from "./cad_task_flow.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8931/");
const out = resolve(String(args.out || "shots/placing"));
const ONLY = String(args.only || "edge,parts,balance").split(",");
const RATIO = Number(args.ratio || 1);
const W = 1600;
const H = 900;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: RATIO });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
const said = [];
page.on("console", (m) => { said.push(m.text().slice(0, 200)); if (said.length > 40) said.shift(); });
const log = (line) => console.log(line);
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/never_${name.replace(/\W/g, "_")}.png` }).catch(() => {});
  log(`the page said, last:\n  ${said.join("\n  ")}`);
  throw new Error(`the app never showed "${name}"`);
}
// A state told after now: the page is told twice a second at most.
async function fresh(ms = 450) {
  const before = (await state()).now || 0;
  for (let n = 0; n < 60; n++) {
    await page.waitForTimeout(150);
    const s = await state();
    if ((s.now || 0) - before >= ms) return s;
  }
  return state();
}
async function until(test, seconds = 20) {
  let now = await state();
  for (let n = 0; n < seconds * 4 && !test(now); n++) {
    await page.waitForTimeout(250);
    now = await state();
  }
  return now;
}
async function key(name, ms = 350) {
  await page.keyboard.press(name);
  await page.waitForTimeout(ms);
}
async function take(id) {
  const box = await where("part search");
  await page.mouse.click(box.x, box.y);
  await key("Control+a", 150);
  await page.keyboard.type(id, { delay: 30 });
  await page.waitForTimeout(1600);
  const first = await where("first part", 30);
  await page.mouse.click(first.x, first.y);
  const s = await until((now) => now.mode === "place" && String(now.held || "") === id, 15);
  return String(s.held || "") === id;
}

// The ghost as it stands once it has stopped moving, as a person waits for
// it: told the same twice running. A ghost told on its way (a part's shape
// arriving, a slow frame) is not what a person clicks on.
async function settled() {
  let s = await fresh();
  for (let n = 0; n < 6; n++) {
    const again = await fresh();
    if (JSON.stringify(again.ghost_pose) === JSON.stringify(s.ghost_pose)
        && again.can_place === s.can_place) return again;
    s = again;
  }
  return s;
}

// Two poses the same: the place to a hundredth of an LDU, the turn to a
// thousandth.
function samePose(a, b) {
  if (!a || !b) return false;
  return a.every((v, i) => Math.abs(v - b[i]) <= (i < 3 ? 0.01 : 0.002));
}
const placeOf = (pose) => (pose ? pose.slice(0, 3) : null);

// Aim at [x, y] (fractions of a pixel, as a person's pointer on a
// high-density screen reports them), read the ghost, click there, and read
// what was put down. Undone after unless [keep].
async function aimAndPut(x, y, { keep = false } = {}) {
  await page.mouse.move(x, y, { steps: 2 });
  const s = await settled();
  if (!s.ghost_pose || !s.can_place) return { x, y, ghost: s.ghost_pose, can_place: s.can_place, put: null };
  const before = s.bricks;
  await page.mouse.click(x, y);
  const after = await until((now) => now.bricks > before && now.put, 8);
  const put = after.bricks > before && after.put ? after.put.pose : null;
  const row = { x, y, ghost: s.ghost_pose, can_place: true, put, id: after.put ? after.put.id : null,
    same: samePose(s.ghost_pose, put) };
  if (put && !keep) {
    await key("Control+z", 300);
    await until((now) => now.bricks === before, 8);
  }
  return row;
}

async function start() {
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await where("model_name", Number(args.wait || 400));
  await page.waitForTimeout(8000);
  const fresh_ = await where("new");
  await page.mouse.click(fresh_.x, fresh_.y);
  await page.waitForTimeout(1500);
  for (let n = 0; n < 10 && (await state()).bricks > 0; n++) await key("Enter", 1500);
  await page.evaluate(() => { window.brickworksAskLayout = true; });
  await page.waitForTimeout(1500);
  const layout = await page.evaluate(() => window.brickworksLayout);
  return layout.view;
}

// The first part, anywhere on the baseplate in the middle of the view.
async function base(id, rect) {
  if (!(await take(id))) throw new Error(`the search would not put ${id} in hand`);
  const x = rect[0] + rect[2] / 2;
  const y = rect[1] + rect[3] / 2;
  let s = null;
  for (let n = 0; n < 6; n++) {
    s = await aimAndPut(x + n * 3, y, { keep: true });
    if (s.put) return s.put;
  }
  throw new Error(`could not put ${id} down: ${JSON.stringify(s)}`);
}

const report = { when: new Date().toISOString(), url, ratio: RATIO, edge: null, parts: [], errors };
const save = () => writeFileSync(`${out}/placing.json`, JSON.stringify(report, null, 1));

const rect = await start();
const shift = [rect[0] + rect[2] / 2 - W / 2, rect[1] + rect[3] / 2 - H / 2];

if (ONLY.includes("edge")) {
  const plate = await base("3022", rect);
  log(`a 2 x 2 plate at ${JSON.stringify(placeOf(plate))}`);
  if (!(await take("4081b"))) throw new Error("the search would not put 4081b in hand");
  const view = (await fresh()).view;
  // The plate's front edge on screen: of its two edges along x, the one
  // lower on the screen faces the view.
  const [px, py, pz] = plate;
  const edges = [pz - 20, pz + 20].map((z) => project([px, py, z], view, shift));
  const edge = edges[0][1] > edges[1][1] ? edges[0] : edges[1];
  const rows = [];
  for (let d = -6; d <= 6; d += 0.35) {
    const row = await aimAndPut(edge[0] + 0.5, edge[1] + d);
    rows.push(row);
    if (row.put) {
      log(`  pointer ${row.x.toFixed(2)},${row.y.toFixed(2)}: ghost ${JSON.stringify(placeOf(row.ghost))} `
        + `put ${JSON.stringify(placeOf(row.put))} ${row.same ? "same" : "DIFFERENT"}`);
    }
  }
  const tried = rows.filter((r) => r.put);
  const differ = tried.filter((r) => !r.same);
  report.edge = { plate, edge, tried: tried.length, differ: differ.length, rows };
  log(`edge: ${tried.length} clicks put a clip plate down, ${differ.length} somewhere other than its ghost`);
  save();
  await page.screenshot({ path: `${out}/edge.png`, clip: { x: rect[0], y: rect[1], width: rect[2], height: rect[3] } });
}

// -- awkward parts --------------------------------------------------------------

// LDraw's place and matrix as the page tells a pose: the place with y and z
// negated, then the app's basis by columns (LdrModel.to_transform).
function filePose(at, m) {
  const [a, b, c, d, e, f, g, h, i] = m;
  const rows = [[a, -b, -c], [-d, e, f], [-g, h, i]];
  return [at[0], -at[1], -at[2], rows[0][0], rows[1][0], rows[2][0],
    rows[0][1], rows[1][1], rows[2][1], rows[0][2], rows[1][2], rows[2][2]];
}
function nearPose(a, b, place = 0.05, turn = 0.002) {
  if (!a || !b) return false;
  return a.every((v, i) => Math.abs(v - b[i]) <= (i < 3 ? place : turn));
}
let turnInHand = { face: "up", q: 0 };
async function turnTo(m) {
  const app = filePose([0, 0, 0], m);
  const rows = [[app[3], app[6], app[9]], [app[4], app[7], app[10]], [app[5], app[8], app[11]]];
  const want = turnFor(rows);
  if (!want) return false;
  for (const name of keysFor(turnInHand, want)) await key(name, 300);
  turnInHand = want;
  return true;
}

// The pointer onto [target] (a place, in the page's terms), corrected by
// watching the ghost as a person does; the pointer, or null.
async function aimAt(target, tries = 10) {
  const view = (await fresh()).view;
  let pointer = project(target, view, shift);
  for (let n = 0; n < tries; n++) {
    await page.mouse.move(pointer[0], pointer[1], { steps: 2 });
    const s = await settled();
    if (s.ghost_pose && placeOf(s.ghost_pose).every((v, i) => Math.abs(v - target[i]) <= 0.5)) return pointer;
    if (!s.ghost_pose) { pointer = [pointer[0] + (n % 2 ? -7 : 7), pointer[1] + 5]; continue; }
    const a = project(placeOf(s.ghost_pose), view, shift);
    const b = project(target, view, shift);
    const step = [b[0] - a[0], b[1] - a[1]];
    if (Math.hypot(...step) < 1.5) pointer = [pointer[0] + (n % 2 ? 4 : -4), pointer[1] + 6];
    else pointer = [pointer[0] + step[0], pointer[1] + step[1]];
  }
  return null;
}

// Where a part's connector of [kind] is on the page (brickworksState.joints).
async function jointsOf(test) {
  const s = await fresh();
  return (s.joints || []).filter(test);
}

let inHand = "";
async function hold(id) {
  if (inHand === id) return true;
  const ok = await take(id);
  inHand = ok ? id : "";
  return ok;
}

// One part put by its ghost: the row, logged.
function record(name, row, want = null) {
  const out_ = { case: name, ...row, want, as_file: want ? nearPose(row.put, want) : null };
  report.parts.push(out_);
  log(`${name}: ${row.put ? (row.same ? "put where its ghost stood" : "put SOMEWHERE ELSE")
    : "NOT PUT (" + (row.ghost ? "red" : "no ghost") + ")"}${want ? (out_.as_file ? ", as the file has it" : ", NOT as the file has it") : ""}`
    + ` (ghost ${JSON.stringify(row.ghost)}, put ${JSON.stringify(row.put)}${want ? ", file " + JSON.stringify(want) : ""})`);
  save();
  return out_;
}

if (ONLY.includes("parts")) {
  // New, a 2 x 2 plate in the middle, and the plane's step 4 on it: two
  // clip plates, each turned a quarter, the clip over the plate's edge.
  const fresh_ = await where("new");
  await page.mouse.click(fresh_.x, fresh_.y);
  await page.waitForTimeout(1500);
  for (let n = 0; n < 10 && (await state()).bricks > 0; n++) await key("Enter", 1500);
  inHand = "";
  const plate = await base("3022", rect);
  const [px, py, pz] = plate;
  log(`a 2 x 2 plate at ${JSON.stringify(placeOf(plate))}`);
  await hold("4081b");
  let clip = null;
  for (const [dx, m] of [[-10, [0, 0, 1, 0, 1, 0, -1, 0, 0]], [10, [0, 0, -1, 0, 1, 0, 1, 0, 0]]]) {
    await turnTo(m);
    const want = filePose([0, 0, 0], m);
    want[0] = px + dx; want[1] = py + 8; want[2] = pz - 10;
    const pointer = await aimAt(want.slice(0, 3));
    if (!pointer) { record("4081b clip plate", { put: null, ghost: (await fresh()).ghost_pose }, want); continue; }
    const row = record("4081b clip plate", await aimAndPut(pointer[0], pointer[1], { keep: true }), want);
    if (!clip && row.id) clip = row.id;
  }
  // A bar in the first clip, aimed at the clip as the page says it is.
  if (clip) {
    await hold("87994");
    const bores = await jointsOf((j) => j.brick === clip && j.kind === "bore");
    if (bores.length) {
      const row = await aimAndPut(bores[0].x + 0.37, bores[0].y + 0.61, { keep: true });
      row.on_joint = (await state()).on_joint;
      record("87994 bar in the clip", row);
    } else record("87994 bar in the clip", { put: null, ghost: null });
  }
  // A hinge's base on the baseplate and its top on it; slopes; a Technic
  // brick and a pin in its hole, each aimed beside the plate.
  turnInHand = { face: "up", q: 0 };
  await hold("3937");
  await turnTo([1, 0, 0, 0, 1, 0, 0, 0, 1]);
  const hinge = record("3937 hinge base",
    await aimAndPut(...project([px - 60, 0, pz + 40], (await fresh()).view, shift).map((v) => v + 0.43), { keep: true }));
  if (hinge.put) {
    await hold("3938");
    const top = [hinge.put[0], hinge.put[1] + 10, hinge.put[2]];
    record("3938 hinge top on its base",
      await aimAndPut(...project(top, (await fresh()).view, shift).map((v) => v + 0.43), { keep: true }));
  }
  await hold("3040b");
  record("3040b slope",
    await aimAndPut(...project([px + 60, 0, pz + 40], (await fresh()).view, shift).map((v) => v + 0.43), { keep: true }));
  await hold("3039");
  await turnTo([0, 0, -1, 0, 1, 0, 1, 0, 0]);
  record("3039 slope, turned",
    await aimAndPut(...project([px + 60, 0, pz - 60], (await fresh()).view, shift).map((v) => v + 0.43), { keep: true }));
  await hold("3700");
  await turnTo([1, 0, 0, 0, 1, 0, 0, 0, 1]);
  const beam = record("3700 Technic brick",
    await aimAndPut(...project([px - 60, 0, pz - 60], (await fresh()).view, shift).map((v) => v + 0.43), { keep: true }));
  if (beam.id) {
    await hold("3673");
    const holes = await jointsOf((j) => j.brick === beam.id && j.kind === "pin_hole");
    if (holes.length) {
      const row = await aimAndPut(holes[0].x + 0.37, holes[0].y + 0.61, { keep: true });
      row.on_joint = (await state()).on_joint;
      record("3673 Technic pin in its hole", row);
    } else record("3673 Technic pin in its hole", { put: null, ghost: null });
  }
  // F frames what was built, as a person looks at it.
  await key("Escape", 400);
  await key("f", 2500);
  await page.screenshot({ path: `${out}/parts.png`, clip: { x: rect[0], y: rect[1], width: rect[2], height: rect[3] } });
}

// 8841-1 Balance's step 4 as its file has it up to its Technic plates
// (4262), opened; then each plate taken, aimed at its pin as the page says
// the pin is, T for the other way on, and clicked: swung onto the axle at
// 66.4 degrees (Builder._closings), off the 24 turns and the whole LDU.
async function openFile(path) {
  const at = await where("open");
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(path);
      return true;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return false;
}

if (ONLY.includes("balance")) {
  const text = readFileSync(resolve(String(args["sets-dir"] || "vendor/omr/files"), "8841-1_Balance.mpd"), "utf8");
  const lines = text.split(/\r?\n/);
  const first = lines.findIndex((l) => /\s4262\.dat\s*$/i.test(l));
  const plates = lines.filter((l) => /\s4262\.dat\s*$/i.test(l)).slice(0, 2).map((l) => {
    const w = l.trim().split(/\s+/).map(Number);
    return filePose(w.slice(2, 5), w.slice(5, 14));
  });
  const path = `${out}/balance_before_its_plates.ldr`;
  writeFileSync(path, lines.slice(0, first).join("\n") + "\n");
  page.choosers = [];
  page.on("filechooser", (chooser) => page.choosers.push(chooser));
  await openFile(path);
  const opened = await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
  log(`balance: "${opened.said}"`);
  await page.waitForTimeout(4000);
  inHand = "";
  await hold("4262");
  turnInHand = { face: "up", q: 0 };
  await turnTo([1, 0, 0, 0, 1, 0, 0, 0, 1]);
  for (const [n, want] of plates.entries()) {
    const pins = await jointsOf((j) => j.part === "4459" && j.kind === "pin");
    let done = false;
    for (const pin of pins) {
      const x = pin.x + 0.37;
      const y = pin.y + 0.61;
      await page.mouse.move(x, y, { steps: 2 });
      let s = await settled();
      let presses = 0;
      while (!nearPose(s.ghost_pose, want) && presses < 6) {
        await key("t", 300);
        presses += 1;
        await page.mouse.move(x + 1, y, { steps: 1 });
        await page.mouse.move(x, y, { steps: 1 });
        s = await settled();
      }
      if (!nearPose(s.ghost_pose, want)) continue;
      const row = await aimAndPut(x, y, { keep: true });
      row.presses_t = presses;
      record(`4262 Technic plate #${n + 1}, swung on its pin onto the axle`, row, want);
      done = true;
      break;
    }
    if (!done) record(`4262 Technic plate #${n + 1}, swung on its pin onto the axle`,
      { put: null, ghost: (await fresh()).ghost_pose }, want);
  }
  await page.screenshot({ path: `${out}/balance.png`, clip: { x: rect[0], y: rect[1], width: rect[2], height: rect[3] } });
}

const parts = report.parts;
log(`parts: ${parts.filter((p) => p.put && p.same).length} of ${parts.length} put where their ghosts stood; `
  + `${parts.filter((p) => p.want && p.as_file).length} of ${parts.filter((p) => p.want).length} as the file has them`);
save();
await browser.close();
log(`  wrote ${out}/placing.json`);
