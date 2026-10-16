// A real set built from its instructions in the browser, as a person builds
// it: only the UI a person has, every action counted, the result checked
// part by part against the set's own file.
//
//   python3 tools/web/serve.py build/web 8847 --parts assets/generated/parts --delay 0 &
//   node --env-file=.env tools/web/cad_task_flow.mjs --url=http://127.0.0.1:8847/ \
//       --out=bench/results/cadtask-<date>/build [--sets=5762-1_Plane.mpd,...] [--most=N]
//
// (tools/bench/cadtask.py build starts the server, runs this through heavy
// and writes the report; --sets defaults to its three, chosen in hash order.)
//
// For each set: New, then for each author step in the file's order, each of
// its parts, lowest first:
//
//   take      the parts search: a click in it, Ctrl+A, the number typed,
//             a click on the first tile; skipped when that part is still in
//             hand from the part before, as it stays after a click
//   colour    the bin's swatch of that colour, found on screen by its look
//             (LDConfig's colour, as the swatch draws it), scrolling the
//             palette and showing all colours when it is not in sight
//   turn      R, Shift-R, T, Shift-T: the fewest presses from the turn in
//             hand to the file's, of the 24 a part can have on the grid
//   aim       the pointer onto the place, corrected by watching the ghost
//             (brickworksState.ghost), as a person watches it; each move is
//             a pointing action
//   put       a click, when the ghost stands where the file has the part
//             and the app says it may go there
//
// A part that cannot be got there through the UI within its tries is a gap,
// with why, and nothing is put there. The view is never changed by anything
// but keys a person has (F, -, the number keys).
//
// At the end the model is exported by File > Export > LDraw (a download)
// and compared with the set file part by part: id, colour, place (up to the
// one shift a model built on a baseplate has from its file) and turn. Then
// the set's own file is opened by Open > From a file, and both are drawn
// from the same view, side by side, in --out/<set>_side_by_side.png.
//
// What this measures is this box: SwiftShader, a shared machine. Times are
// said, not judged; the counts are the finding.
import { launch } from "./browser.mjs";
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8847/");
const out = resolve(String(args.out || "shots/cad_task"));
const SETS_DIR = resolve(String(args["sets-dir"] || "vendor/omr/files"));
const SETS = String(args.sets || "5762-1_Plane.mpd,8643-1_Combination-with-8644.mpd,8841-1_Balance.mpd")
  .split(",").filter(Boolean);
// The most parts to try of each set, in --sets' order (0 for all of it).
const MOSTS = String(args.most || "0").split(",").map(Number);
// The building each set gets, in minutes from its start: a shared box can
// make a part a minute, and the run has to end. What is not reached is
// said as not tried. 0 for no limit.
const MINUTES = Number(args.minutes ?? 22);
const AIMS = Number(args.aims || 8);
const W = 1600;
const H = 900;
const FOV = 45;
mkdirSync(out, { recursive: true });

// -- the file -------------------------------------------------------------------

function ldconfig() {
  const colours = {};
  for (const line of readFileSync(resolve("vendor/ldraw/LDConfig.ldr"), "utf8").split("\n")) {
    const m = line.match(/^0 !COLOUR\s+(\S+)\s+CODE\s+(\d+)\s+VALUE\s+#([0-9A-Fa-f]{6})(.*)$/);
    if (!m) continue;
    const hex = m[3];
    const rest = m[4];
    colours[Number(m[2])] = {
      name: m[1], rgb: [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16)),
      transparent: /ALPHA/.test(rest),
      finish: /CHROME/.test(rest) ? "chrome" : /METAL/.test(rest) ? "metal" : /RUBBER/.test(rest) ? "rubber" : "",
    };
  }
  return colours;
}

// The parts of a one-model file in their author's steps.
export function readSet(text) {
  const steps = [[]];
  const subs = [];
  let files = 0;
  for (const raw of text.split(/\r?\n/)) {
    const w = raw.trim().split(/\s+/);
    if (w[0] === "0" && /^FILE$/i.test(w[1] || "")) {
      files += 1;
      if (files > 1) break;
    }
    if (w[0] === "0" && /^(STEP|ROTSTEP)$/i.test(w[1] || "")) {
      if (steps[steps.length - 1].length) steps.push([]);
      continue;
    }
    if (w[0] !== "1" || w.length < 15) continue;
    const id = w.slice(14).join(" ").toLowerCase().replace(/\.dat$/, "");
    const n = w.slice(2, 14).map(Number);
    if (/\.(ldr|mpd)$/i.test(id)) { subs.push(id); continue; }
    steps[steps.length - 1].push({ id, colour: Number(w[1]), at: n.slice(0, 3), m: n.slice(3, 12) });
  }
  if (!steps[steps.length - 1].length) steps.pop();
  return { steps, subs };
}

// LDraw's space to the app's: y and z negated, the matrix conjugated
// (LdrModel.to_transform). Rows of the app's matrix.
const toApp = (p) => [p[0], -p[1], -p[2]];
function appMatrix(m) {
  const [a, b, c, d, e, f, g, h, i] = m;
  return [[a, -b, -c], [-d, e, f], [-g, h, i]];
}

// -- the 24 turns in hand (BrickLattice.basis_for) ------------------------------

const FACES = ["up", "+z", "down", "-z", "+x", "-x"];
const AXIS = { up: [0, 1, 0], down: [0, -1, 0], "+x": [1, 0, 0], "-x": [-1, 0, 0], "+z": [0, 0, 1], "-z": [0, 0, -1] };
function rot(axis, angle) {
  const [x, y, z] = axis;
  const c = Math.cos(angle), s = Math.sin(angle), t = 1 - c;
  return [[t * x * x + c, t * x * y - s * z, t * x * z + s * y],
    [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
    [t * x * z - s * y, t * y * z + s * x, t * z * z + c]];
}
const mul = (A, B) => A.map((row) => [0, 1, 2].map((j) => row.reduce((sum, v, k) => sum + v * B[k][j], 0)));
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
export function basisFor(face, quarter) {
  const up = AXIS[face];
  let tip;
  if (face === "up") tip = rot([1, 0, 0], 0);
  else if (face === "down") tip = rot([1, 0, 0], Math.PI);
  else {
    const k = cross([0, 1, 0], up);
    const len = Math.hypot(...k);
    tip = rot(k.map((v) => v / len), Math.PI / 2);
  }
  return mul(rot(up, quarter * Math.PI / 2), tip).map((row) => row.map((v) => Math.round(v)));
}
export function turnFor(matrix) {
  for (const face of FACES) {
    for (let q = 0; q < 4; q++) {
      const b = basisFor(face, q);
      if (b.every((row, r) => row.every((v, c) => Math.abs(v - matrix[r][c]) < 0.01))) return { face, q };
    }
  }
  return null;
}
// The fewest presses from one turn in hand to another: T rolls onto the
// next face in FACES (Shift-T back), R a quarter about the part's up.
export function keysFor(from, to) {
  const keys = [];
  const df = (FACES.indexOf(to.face) - FACES.indexOf(from.face) + 6) % 6;
  for (let n = 0; n < (df <= 3 ? df : 6 - df); n++) keys.push(df <= 3 ? "t" : "Shift+T");
  const dq = (to.q - from.q + 4) % 4;
  for (let n = 0; n < (dq <= 2 ? dq : 1); n++) keys.push(dq <= 2 ? "r" : "Shift+R");
  return keys;
}

// -- the view, as CadCamera draws it ------------------------------------------

export function project(p, view, shift = [0, 0]) {
  const { yaw, pitch, distance, focus } = view;
  const offset = [Math.cos(pitch) * Math.sin(yaw), Math.sin(pitch), Math.cos(pitch) * Math.cos(yaw)]
    .map((v) => v * distance);
  const eye = focus.map((v, i) => v + offset[i]);
  const f = offset.map((v) => -v / distance);
  let right = cross(f, [0, 1, 0]);
  const len = Math.hypot(...right);
  right = right.map((v) => v / len);
  const up = cross(right, f);
  const d = p.map((v, i) => v - eye[i]);
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const s = (H / 2) / Math.tan((FOV * Math.PI / 180) / 2);
  const zc = dot(d, f);
  return [W / 2 + shift[0] + dot(d, right) / zc * s, H / 2 + shift[1] - dot(d, up) / zc * s];
}

// -- the page ---------------------------------------------------------------------

let colours = {};
const errors = [];

export function sameId(file, held) {
  return held === file || held.replace(/[a-z]$/, "") === file.replace(/[a-z]$/, "");
}

// One page building one set, with its own pointer, hand and counts; main()
// builds the sets one after another, a page each.
function session(browser, label) {
let page = null;
let shift = [0, 0];
const log = (line) => console.log(`[${label}] ${line}`);
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
// A state told after now: the page is told twice a second at most.
async function fresh(ms = 450) {
  const before = (await state()).now || 0;
  for (let n = 0; n < 40; n++) {
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

// What the person did, by kind. A pointing action is a move of the pointer
// to somewhere new; a click, key or typed character is one each.
let count = null;
function fresh_counts() {
  return { point: 0, click: 0, key: 0, typed: 0, scroll: 0, search: 0, colour: 0, turn: 0, aim_fix: 0 };
}
async function pointTo(x, y) {
  count.point += 1;
  await page.mouse.move(x, y, { steps: 3 });
}
async function clickAt(x, y) {
  await pointTo(x, y);
  await page.waitForTimeout(150);
  count.click += 1;
  await page.mouse.click(x, y);
}
async function key(name, ms = 350) {
  count.key += 1;
  await page.keyboard.press(name);
  await page.waitForTimeout(ms);
}
async function typeText(text) {
  count.typed += text.length;
  await page.keyboard.type(text, { delay: 40 });
}

// -- colour, by the swatch's look ---------------------------------------------

// What a swatch of [code] looks like at three points, top left, top right
// and bottom left (the bottom right has the dot for a colour the part in
// hand comes in), as PartsBin.Swatch._draw draws it; and dimmed, as it is
// for a colour the part in hand was never made in.
function swatchLooks(code) {
  const c = colours[code];
  if (!c) return [];
  const mix = (a, b, t) => a.map((v, i) => v * (1 - t) + b[i] * t);
  const body = c.rgb;
  let look = [body, body, body];
  if (c.transparent) {
    const l = mix([209, 212, 217], body, 0.62);
    const d = mix([115, 117, 128], body, 0.62);
    look = [l, d, d];
  } else if (c.finish === "chrome" || c.finish === "metal") {
    const s = c.finish === "chrome" ? 0.75 : 0.4;
    look = [mix(body, [255, 255, 255], s), mix(body, [255, 255, 255], s), mix(body, [0, 0, 0], s * 0.6)];
  } else if (c.finish === "rubber") {
    look = [body, body, mix(body, [0, 0, 0], 0.3)];
  }
  return [look, look.map((p) => mix(p, [28, 31, 36], 0.6))];
}
// Where on the palette each of [codes] is, from one picture of it: the
// middle of the swatch that looks most like it, and how unlike (the sum of
// three distances in RGB).
async function findSwatches(codes, clip) {
  const looks = codes.map((code) => [code, swatchLooks(code)]);
  const shot = await page.screenshot({ clip });
  return page.evaluate(async ([b64, looks, clip]) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const canvas = new OffscreenCanvas(img.width, img.height);
    const g = canvas.getContext("2d");
    g.drawImage(img, 0, 0);
    const px = g.getImageData(0, 0, img.width, img.height).data;
    const mean = (x, y) => {
      let r = 0, gg = 0, b = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const i = ((y + dy) * img.width + x + dx) * 4;
        r += px[i]; gg += px[i + 1]; b += px[i + 2];
      }
      return [r / 9, gg / 9, b / 9];
    };
    const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
    const best = {};
    for (let y = 6; y < img.height - 6; y++) {
      for (let x = 6; x < img.width - 6; x++) {
        const three = [mean(x - 4, y - 4), mean(x + 4, y - 4), mean(x - 4, y + 4)];
        for (const [code, ways] of looks) {
          for (const look of ways) {
            const score = three.reduce((sum, p, k) => sum + dist(p, look[k]), 0);
            if (!best[code] || score < best[code].score) best[code] = { x: x + clip.x, y: y + clip.y, score };
          }
        }
      }
    }
    return best;
  }, [shot.toString("base64"), looks, clip]);
}
// Near enough to be that colour: about 18 apart in RGB at each point. Light
// Grey (7) and Light Bluish Grey (71) are 40 apart, so one is not taken for
// the other.
const LIKE = 54;
let swatchAt = null;
let setColours = [];
let colourInHand = 4;
let allColours = false;
async function chooseColour(code) {
  if (code === colourInHand) return true;
  // The palette: under the bin's Colour heading, to the foot of the column.
  const clip = { x: 4, y: 712, width: 316, height: 118 };
  let scrolled = 0;
  for (let tries = 0; tries < 9; tries++) {
    if (!swatchAt) swatchAt = await findSwatches(setColours, clip);
    const found = swatchAt[code];
    if (found && found.score < LIKE) {
      count.colour += 1;
      await clickAt(found.x, found.y);
      await page.waitForTimeout(300);
      colourInHand = code;
      if (scrolled) {
        // Back to the top of the palette, for the next one.
        count.scroll += 1;
        await page.mouse.wheel(0, -4000);
        await page.waitForTimeout(400);
        swatchAt = null;
      }
      return Math.round(found.score);
    }
    swatchAt = null;
    if (!allColours) {
      // Every colour, not only today's: "All 320" beside the heading.
      allColours = true;
      await clickAt(302, 693);
      await page.waitForTimeout(900);
      continue;
    }
    // Further down the palette.
    count.scroll += 1;
    scrolled += 1;
    await pointTo(160, 770);
    await page.mouse.wheel(0, 90);
    await page.waitForTimeout(500);
  }
  count.scroll += 1;
  await page.mouse.wheel(0, -4000);
  swatchAt = null;
  return false;
}

// -- one part ---------------------------------------------------------------------

let inHand = "";
let turnInHand = { face: "up", q: 0 };
async function take(id) {
  if (inHand && (inHand === id || foundAs[id] === inHand)) return { ok: true, held: inHand };
  count.search += 1;
  const box = await where("part search");
  await clickAt(box.x, box.y);
  await key("Control+a", 150);
  await typeText(id);
  await page.waitForTimeout(1600);
  const first = await where("first part", 30);
  await clickAt(first.x, first.y);
  const s = await until((now) => now.mode === "place" && String(now.held || "").length > 0
    && String(now.held) !== inHand, 15);
  inHand = String(s.held || "");
  if (sameId(id, inHand)) foundAs[id] = inHand;
  return { ok: sameId(id, inHand), held: inHand };
}

let shiftToApp = null;
let viewRect = [362, 106, 1238, 710];
async function put(part, view) {
  const want = toApp(part.at);
  if (shiftToApp) {
    const target = want.map((v, i) => v + shiftToApp[i]);
    let pointer = project(target, view, shift);
    let last = null;
    let outs = 0;
    for (let n = 0; n < AIMS; n++) {
      // Off the model's part of the window, a click would land on a panel:
      // out a little, as a person zooms out to see where it goes.
      const [vx, vy, vw, vh] = viewRect;
      if (pointer[0] < vx + 8 || pointer[0] > vx + vw - 8 || pointer[1] < vy + 8 || pointer[1] > vy + vh - 8) {
        if (outs++ >= 2) return { ok: false, why: "its place stays off the view" };
        await pointTo(vx + vw / 2, vy + vh / 2);
        await key("Minus", 300);
        await key("Minus", 600);
        view = (await fresh()).view;
        pointer = project(target, view, shift);
        continue;
      }
      if (n > 0) count.aim_fix += 1;
      await pointTo(pointer[0], pointer[1]);
      let s = await fresh();
      // On the web a part is fetched when it is taken; its ghost comes
      // when it has arrived.
      if (n === 0 && !s.ghost) s = await until((now) => Boolean(now.ghost), 12);
      last = s.ghost;
      if (s.ghost && s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1) && s.can_place) {
        const before = s.bricks;
        count.click += 1;
        await page.mouse.click(pointer[0], pointer[1]);
        const after = await until((now) => now.bricks > before, 8);
        return after.bricks > before ? { ok: true, at: s.ghost }
          : { ok: false, why: "the click put nothing down" };
      }
      if (s.ghost && s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1) && !s.can_place) {
        return { ok: false, why: "the ghost stands in the file's place but the app says it may not go there" };
      }
      if (!s.ghost) {
        pointer = [pointer[0] + (n % 2 ? -7 : 7), pointer[1] + 5];
        continue;
      }
      const a = project(s.ghost, view, shift);
      const b = project(target, view, shift);
      const step = [b[0] - a[0], b[1] - a[1]];
      // The ghost on the wrong level and nothing to move across: the
      // pointer is over another part's face; edge it inwards.
      if (Math.hypot(...step) < 1.5) pointer = [pointer[0] + (n % 2 ? 4 : -4), pointer[1] + 6];
      else pointer = [pointer[0] + step[0], pointer[1] + step[1]];
    }
    return { ok: false, why: `the ghost would not stand there (last at ${JSON.stringify(last)}, wanted ${JSON.stringify(target)})` };
  }
  // The first part: anywhere on the baseplate, in the middle of the view.
  const middle = await where("view");
  await pointTo(middle.x, middle.y);
  let s = await fresh();
  if (!s.ghost) s = await until((now) => Boolean(now.ghost), 12);
  // The view still easing in after New moves the ghost under a still
  // pointer: wait for it to stay put, as a person waits for the view.
  for (let n = 0; n < 30; n++) {
    const again = await fresh();
    if (JSON.stringify(again.ghost) === JSON.stringify(s.ghost)) break;
    s = again;
  }
  if (!s.ghost || !s.can_place) return { ok: false, why: "no ghost over the baseplate" };
  const before = s.bricks;
  count.click += 1;
  await page.mouse.click(middle.x, middle.y);
  const after = await until((now) => now.bricks > before, 8);
  if (after.bricks <= before) return { ok: false, why: "the click put nothing down" };
  shiftToApp = s.ghost.map((v, i) => v - want[i]);
  // Where it really went, from the app's own LDraw: on a loaded box the
  // page's ghost can be a frame or two behind the pointer, and an anchor
  // read from it put every later part 20 LDU or more from its place (the
  // plane, 2026-10-16). Not a person's action, so not counted.
  const text = await exportLdraw(`${label}_first.ldr`);
  const line = (text || "").split("\n").map((l) => l.trim().split(/\s+/))
    .find((w) => w[0] === "1" && w.length >= 15);
  if (line) {
    const placed = toApp([Number(line[2]), Number(line[3]), Number(line[4])]);
    log(`first part: the ghost said ${JSON.stringify(s.ghost)}, the file says ${JSON.stringify(placed)}`);
    shiftToApp = placed.map((v, i) => Math.round(v - want[i]));
  }
  // The menu may have let go of the part in hand.
  if (String((await fresh()).held || "") !== inHand) inHand = "";
  return { ok: true, at: s.ghost };
}

// -- reading the model back -----------------------------------------------------------

async function exportLdraw(name) {
  const file = await where("menu_file");
  for (let n = 0; n < 3; n++) {
    const download = page.waitForEvent("download", { timeout: 90000 }).catch(() => null);
    await page.mouse.click(file.x, file.y);
    await page.waitForTimeout(2500 + 2500 * n);
    await page.keyboard.press("E");
    await page.waitForTimeout(800);
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(1500);
    await page.keyboard.press("Enter");
    const got = await download;
    if (got) {
      const path = `${out}/${name}`;
      await got.saveAs(path);
      return readFileSync(path, "utf8");
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return null;
}
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

// Every part of the file against the model read back: the same id, colour
// and turn, and the place less the one shift between them (the commonest).
function compareParts(file, built, aliases = {}) {
  const flat = (steps) => steps.flat().map((p) => ({ ...p, id: p.id.toLowerCase() }));
  const a = flat(file.steps).map((p) => ({ ...p, id: aliases[p.id] || p.id }));
  const b = flat(built.steps);
  const shifts = new Map();
  for (const p of a) for (const q of b) {
    if (p.id !== q.id) continue;
    const k = q.at.map((v, i) => Math.round(v - p.at[i])).join(",");
    shifts.set(k, (shifts.get(k) || 0) + 1);
  }
  const best = [...shifts.entries()].sort((x, y) => y[1] - x[1])[0];
  const by = best ? best[0].split(",").map(Number) : [0, 0, 0];
  const left = [...b];
  const why = { exact: 0, recoloured: 0, turned: 0, moved: 0, missing: 0 };
  const near = (p, q) => p.at.every((v, i) => Math.abs(v + by[i] - q.at[i]) <= 1);
  const same = (p, q) => p.m.every((v, i) => Math.abs(v - q.m[i]) < 0.01);
  const takeOne = (test) => { const n = left.findIndex(test); if (n < 0) return false; left.splice(n, 1); return true; };
  for (const p of a) {
    if (takeOne((q) => q.id === p.id && q.colour === p.colour && near(p, q) && same(p, q))) why.exact += 1;
    else if (takeOne((q) => q.id === p.id && near(p, q) && same(p, q))) why.recoloured += 1;
    else if (takeOne((q) => q.id === p.id && near(p, q))) why.turned += 1;
    else if (takeOne((q) => q.id === p.id && q.colour === p.colour)) why.moved += 1;
    else why.missing += 1;
  }
  return { shift: by, ...why, extra: left.length, file: a.length, built: b.length };
}

async function frameAndShoot(path) {
  await key("0", 600);
  await key("f", 2500);
  await page.waitForTimeout(2500);
  const [x, y, width, height] = viewRect;
  await page.screenshot({ path, clip: { x, y, width, height } });
}

async function sideBySide(left, right, path, title) {
  const view = await browser.newPage({ viewport: { width: 1600, height: 520 } });
  const img = (p) => `data:image/png;base64,${readFileSync(p).toString("base64")}`;
  await view.setContent(`<body style="margin:0;background:#222;color:#eee;font:14px sans-serif">
    <div style="padding:6px 10px">${title}</div>
    <div style="display:flex;gap:8px;padding:0 8px">
      <figure style="margin:0;flex:1"><img src="${img(left)}" style="width:100%;object-fit:cover;object-position:60% 50%;height:440px">
        <figcaption>built through the UI</figcaption></figure>
      <figure style="margin:0;flex:1"><img src="${img(right)}" style="width:100%;object-fit:cover;object-position:60% 50%;height:440px">
        <figcaption>the set's file, opened</figcaption></figure></div></body>`);
  await view.screenshot({ path });
  await view.close();
}

// -- the run ------------------------------------------------------------------------------

// The id the search put in hand for each of the file's: a retired number
// comes up as the part it became (3023 as 3023b), as the catalogue has it.
const foundAs = {};

async function runSet(name, MOST = 0) {
page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1, acceptDownloads: true });
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
await where("model_name", 400);
await page.waitForTimeout(8000);
{
  const text = readFileSync(`${SETS_DIR}/${name}`, "utf8");
  const set = readSet(text);
  const stem = basename(name).replace(/\.(mpd|ldr)$/i, "");
  log(`${stem}: ${set.steps.flat().length} parts in ${set.steps.length} steps`);
  setColours = [...new Set(set.steps.flat().map((p) => p.colour))];
  count = fresh_counts();
  shiftToApp = null;
  const began = Date.now();
  const fresh_ = await where("new");
  await clickAt(fresh_.x, fresh_.y);
  await page.waitForTimeout(1500);
  for (let n = 0; n < 10 && (await state()).bricks > 0; n++) await key("Enter", 1500);
  // Where the model is seen: the view's middle is the lens's (CadCamera).
  await page.evaluate(() => { window.brickworksAskLayout = true; });
  await page.waitForTimeout(1500);
  const layout = await page.evaluate(() => window.brickworksLayout);
  const rect = layout.view;
  viewRect = rect;
  shift = [rect[0] + rect[2] / 2 - W / 2, rect[1] + rect[3] / 2 - H / 2];
  const gaps = [];
  const placed = [];
  let done = 0;
  let framed = false;
  for (let k = 0; k < set.steps.length; k++) {
    // Lowest first, as a hand puts them on: what holds a part before it.
    const step = [...set.steps[k]].sort((p, q) => q.at[1] - p.at[1]);
    for (const part of step) {
      if (MOST && done >= MOST) break;
      // Out of time, or told to stop (a file named stop in --out): what is
      // built is still read back, compared and pictured.
      if ((MINUTES && Date.now() - began > MINUTES * 60000) || existsSync(`${out}/stop`)) {
        MOST = done;
        log(`out of time after ${done} parts (--minutes=${MINUTES})`);
        break;
      }
      done += 1;
      const t0 = Date.now();
      const counted = { ...count };
      const turn = turnFor(appMatrix(part.m));
      const skip = (why) => {
        gaps.push({ step: k + 1, part: part.id, colour: part.colour, why });
        appendFileSync(`${out}/${stem}_parts.jsonl`, JSON.stringify({ step: k + 1, id: part.id,
          colour: part.colour, put: false, why, seconds: (Date.now() - t0) / 1000 }) + "\n");
        log(`step ${k + 1} ${part.id}/${part.colour}: GAP ${why}`);
      };
      if (!turn) {
        skip("turned off the grid's 24 turns (a hinge or an angle): no key turns a part in hand to it");
        continue;
      }
      if (part.at.some((v) => Math.abs(v - Math.round(v)) > 0.01)) {
        skip(`a place off the whole LDU (${part.at.join(" ")})`);
        continue;
      }
      const got = await take(part.id);
      if (!got.held) {
        skip("the search could not put it in hand");
        continue;
      }
      if (!got.ok) {
        skip(`the search's first tile is ${got.held}, not ${part.id}`);
        await key("Escape");
        inHand = "";
        continue;
      }
      const chose = await chooseColour(part.colour);
      if (chose === false) {
        gaps.push({ step: k + 1, part: part.id, colour: part.colour, why: `no swatch of colour ${part.colour} (${(colours[part.colour] || {}).name}) found in the palette` });
      }
      const keys = keysFor(turnInHand, turn);
      for (const name of keys) { count.turn += 1; await key(name, 250); }
      turnInHand = turn;
      const view = (await fresh()).view;
      const put_ = await put(part, view);
      if (!put_.ok) {
        gaps.push({ step: k + 1, part: part.id, colour: part.colour, why: put_.why });
      } else {
        // The view stays where New left it, the whole baseplate in sight: a
        // stud is a dozen pixels, near enough to aim at, and a view that
        // moves while a slow frame catches up puts a part somewhere else.
        placed.push(part);
      }
      const spent = Object.fromEntries(Object.entries(count).map(([k2, v]) => [k2, v - counted[k2]]));
      // Kept as it goes, so a run stopped part way still says what it did.
      appendFileSync(`${out}/${stem}_parts.jsonl`, JSON.stringify({ step: k + 1, id: part.id,
        colour: part.colour, put: put_.ok, why: put_.why || "", colour_score: chose,
        seconds: (Date.now() - t0) / 1000, spent }) + "\n");
      log(`step ${k + 1} ${part.id}/${part.colour}: ${put_.ok ? "put" : "GAP " + put_.why} `
        + `(${((Date.now() - t0) / 1000).toFixed(1)} s, colour ${chose}, ${JSON.stringify(spent)})`);
    }
    if (MOST && done >= MOST) break;
  }
  const seconds = (Date.now() - began) / 1000;
  gaps.push({ step: 0, part: "", colour: -1, why: `no control marks an author step while building: `
    + `${set.steps.length} steps would each be their parts selected, Shift held, and Edit > New step from selection (Shift+N), after` });
  await key("Escape", 400);
  inHand = "";
  const shotBuilt = `${out}/${stem}_built.png`;
  await frameAndShoot(shotBuilt);
  const exported = await exportLdraw(`${stem}_built.ldr`);
  const compared = exported ? compareParts(set, readSet(exported), foundAs) : null;
  // The set as its file has it, from the same view.
  await openFile(`${SETS_DIR}/${name}`);
  await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
  await page.waitForTimeout(6000);
  const shotFile = `${out}/${stem}_file.png`;
  await frameAndShoot(shotFile);
  await sideBySide(shotBuilt, shotFile, `${out}/${stem}_side_by_side.png`,
    `${stem}: ${placed.length} of ${set.steps.flat().length} parts put down through the UI; left built, right the file`);
  const parts = MOST ? Math.min(MOST, set.steps.flat().length) : set.steps.flat().length;
  const actions = count.point + count.click + count.key + count.typed + count.scroll;
  const row = {
    set: name, parts_in_file: set.steps.flat().length, steps: set.steps.length, tried: parts,
    sub_models: set.subs, placed: placed.length, compared, counts: count, actions,
    actions_per_part: +(actions / parts).toFixed(2), seconds: +seconds.toFixed(1),
    seconds_per_part: +(seconds / parts).toFixed(2), gaps,
    // The author's steps: no control marks one while building. Each would
    // be its parts selected (a click each, Shift held) and Edit > New step
    // from selection, Shift+N; counted here, not done.
    step_marking: { steps: set.steps.length, clicks_it_would_take: set.steps.flat().length,
      keys_it_would_take: 3 * set.steps.length },
    pictures: { built: shotBuilt, file: shotFile, side_by_side: `${out}/${stem}_side_by_side.png` },
    // In the order they were tried: each step's lowest first.
    parts_list: set.steps.map((s, k) => [...s].sort((p, q) => q.at[1] - p.at[1]).map((p) => ({ step: k + 1, id: p.id, colour: p.colour,
      turn: turnFor(appMatrix(p.m)) }))).flat(),
  };
  log(`${stem}: ${placed.length}/${parts} put down, ${compared ? compared.exact : "?"} exact; `
    + `${actions} actions (${row.actions_per_part}/part), ${row.seconds_per_part} s/part; ${gaps.length} gaps`);
  await page.close();
  return row;
}
}
return { runSet };
}

async function main() {
  colours = ldconfig();
  const browser = await launch();
  const results = [];
  // What a report prints: per set, what was put down and how exactly, the
  // person's actions, and every gap with why. tools/bench/cadtask_klm.py
  // --merge adds both apps' keystroke-level models under summary.klm.
  const summary = () => ({
    measured: "on this box: SwiftShader, a shared machine, the sets built one after another",
    sets: results.map((r) => (r.error ? { set: r.set, error: r.error } : {
      set: r.set, parts_in_file: r.parts_in_file, tried: r.tried, placed: r.placed,
      exact: r.compared ? r.compared.exact : null,
      recoloured: r.compared ? r.compared.recoloured : null,
      turned: r.compared ? r.compared.turned : null, moved: r.compared ? r.compared.moved : null,
      actions: r.actions, actions_per_part: r.actions_per_part, seconds_per_part: r.seconds_per_part,
      counts: r.counts, gaps: r.gaps.map((g) => (g.part ? `${g.part}/${g.colour} (step ${g.step}): ${g.why}` : g.why)),
      side_by_side: r.pictures.side_by_side,
    })),
  });
  const write = () => writeFileSync(`${out}/build.json`,
    JSON.stringify({ when: new Date().toISOString(), url, summary: summary(), results, errors }, null, 1));
  // One at a time, each its own page: three side by side on a loaded box
  // read the ghost of one page while another held the machine, and put the
  // first part of the plane 560 LDU from where it was recorded.
  for (const [n, name] of SETS.entries()) {
    try {
      results.push(await session(browser, name.split("_")[0]).runSet(name, MOSTS[n] ?? MOSTS[0]));
    } catch (e) {
      results.push({ set: name, error: String(e).slice(0, 300) });
      console.log(`[${name}] FAILED ${String(e).slice(0, 300)}`);
    }
    write();
  }
  await browser.close();
  console.log(`  wrote ${out}/build.json`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
