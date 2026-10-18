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
//             (the app's palette, assets/generated/colors.json, as the
//             swatch draws it) and clicked when it is in sight and plainly
//             that colour; the note under the palette says which was taken
//             (brickworksState.colour). Otherwise, or when a look-alike was
//             taken, its name typed in the palette's own search (Shift-C,
//             the name, Enter takes the first)
//   turn      R, Shift-R, T, Shift-T: the fewest presses from the turn in
//             hand to the file's, of the 24 a part can have on the grid
//   aim       the pointer onto the place, corrected by watching the ghost
//             (brickworksState.ghost), as a person watches it; each move is
//             a pointing action
//   put       a click, when the ghost stands where the file has the part
//             and the app says it may go there
//   step      E, Next step, once a step's parts are down: what was put
//             down since the last step makes one, as the file has them
//
// A part that cannot be got there through the UI within its tries is a gap,
// with why, and nothing is put there. The view is never changed by anything
// but keys a person has (F, -, the number keys).
//
// At the end, Right is pressed on the timeline (B) after a part was taken
// by a click on its tile, which once kept the keys (focus). The model is
// exported by File > Export > LDraw (a download) and compared with the set
// file part by part: id, colour, place (up to the one shift a model built
// on a baseplate has from its file), turn, and whether each step of the
// file's came out one step of the model's. Then
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

// The palette as the app draws it: assets/generated/colors.json, not
// LDConfig, whose old greys are other values (7 is #9BA19D there and
// 138,146,141 here), so a swatch looked for by LDConfig's value was found
// in the wrong place: a brown for 8 (2026-10-16). Black-like colours are
// drawn with most of their tint taken out (PartLibrary.shown_for).
export function palette(text) {
  const colours = {};
  for (const c of JSON.parse(text)) {
    colours[c.code] = {
      name: c.name, rgb: shownFor(c.rgb), transparent: (c.alpha ?? 255) < 255,
      finish: /chrome/.test(c.finish) ? "chrome" : /metal/.test(c.finish) ? "metal"
        : /rubber/.test(c.finish) ? "rubber" : "",
    };
  }
  return colours;
}
const toLinear = (v) => { const c = v / 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; };
const toSrgb = (c) => Math.round(255 * Math.min(1, Math.max(0, c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055)));
export function shownFor(rgb) {
  const [r, g, b] = rgb.map(toLinear);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  if (L >= 0.35 || Math.hypot(A, B) >= 0.04) return rgb;
  A *= 0.25; B *= 0.25;
  const l2 = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3;
  const m2 = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3;
  const s2 = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3;
  return [4.0767416621 * l2 - 3.3077115913 * m2 + 0.2309699292 * s2,
    -1.2684380046 * l2 + 2.6097574011 * m2 - 0.3413193965 * s2,
    -0.0041960863 * l2 - 0.7034186147 * m2 + 1.7076147010 * s2].map(toSrgb);
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
    steps[steps.length - 1].push({ id, colour: Number(w[1]), at: n.slice(0, 3), m: n.slice(3, 12),
      step: steps.length - 1 });
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

// Each part's box in its own frame, in the app's axes, from the catalogue
// (assets/generated/catalogue.json): [min, max], or null for one it has not.
let boxes = null;
function boxOf(id) {
  if (!boxes) {
    boxes = {};
    try {
      const cat = JSON.parse(readFileSync(resolve("assets/generated/catalogue.json"), "utf8"));
      for (const e of cat.parts) boxes[String(e.id).toLowerCase()] = [e.bounds_min, e.bounds_max];
    } catch { /* no catalogue: the order is lowest first alone */ }
  }
  return boxes[id] || null;
}

// Whether box [b] (the app's space) touches a part turned off the square,
// asked in that part's own frame too ([turned]: its rows, place and own
// box): a 4262 swung 66 degrees has a box across the world's axes much
// bigger than it, and 8841-1's pan plates, 80 LDU under it, touched it.
function touchesTurned(b, turned) {
  const { m, o, lo, hi } = turned;
  const a = [Infinity, Infinity, Infinity];
  const z = [-Infinity, -Infinity, -Infinity];
  for (let c = 0; c < 8; c++) {
    const d = [b[c & 1][0], b[(c >> 1) & 1][1], b[(c >> 2) & 1][2]].map((v, i) => v - o[i]);
    for (let k = 0; k < 3; k++) {
      const v = m[0][k] * d[0] + m[1][k] * d[1] + m[2][k] * d[2];
      a[k] = Math.min(a[k], v);
      z[k] = Math.max(z[k], v);
    }
  }
  return [0, 1, 2].every((k) => a[k] <= hi[k] + 1 && lo[k] <= z[k] + 1);
}

// A part of a file where the file has it, as a box in the app's space.
function placedBox(part, own) {
  const b = own(part.id);
  if (!b) return null;
  const m = appMatrix(part.m);
  const o = toApp(part.at);
  const lo = [Infinity, Infinity, Infinity];
  const hi = [-Infinity, -Infinity, -Infinity];
  for (let c = 0; c < 8; c++) {
    const p = [b[c & 1][0], b[(c >> 1) & 1][1], b[(c >> 2) & 1][2]];
    for (let r = 0; r < 3; r++) {
      const v = m[r][0] * p[0] + m[r][1] * p[1] + m[r][2] * p[2] + o[r];
      lo[r] = Math.min(lo[r], v);
      hi[r] = Math.max(hi[r], v);
    }
  }
  const box = [lo, hi];
  if (m.some((row) => row.some((v) => Math.abs(v) > 0.01 && Math.abs(Math.abs(v) - 1) > 0.01))) {
    box.turned = { m, o, lo: b[0], hi: b[1] };
  }
  return box;
}

// The order a hand puts a step's parts in: lowest first, as what holds a
// part goes on before it, but a part whose middle is inside a bigger part
// of the step after that part (the smallest such: a post standing beside
// the brick a pin is in reaches round the pin too). A pin goes into a
// brick's hole once the brick is down, though the pin's middle is lower
// than the brick's top: 8841-1's step 1 tried its four pins before the
// bricks they go in, with no hole there for them (2026-10-17).
//
// And each on what is down already, where one is: of the parts left, the
// lowest that touches a part of an earlier step, one of this step's put
// before it, or the floor ([placed], the boxes of the parts before the
// step; [floor], the bottom of the model). 8841-1's balance hangs two pans
// from an axle at its top, and lowest first put each pan's plate first, in
// the air under it, and nothing of either pan could go on (2026-10-17). A
// person hangs the axle, the arms on it, and builds each pan down from them.
export function handOrder(step, own = boxOf, placed = [], floor = -Infinity) {
  const low = [...step].sort((p, q) => q.at[1] - p.at[1]);
  const box = low.map((p) => placedBox(p, own));
  const down = [...placed];
  // Held by it: into it (a pin in its hole), or on it or under it; a part
  // only beside another is not held by it (8841-1's top plates beside the
  // columns, put first, held by nothing).
  const holds = (b, o) => {
    const ov = [0, 1, 2].map((i) => Math.min(b[1][i], o[1][i]) - Math.max(b[0][i], o[0][i]));
    return ov[0] > 1 && ov[2] > 1 && ov[1] > -1;
  };
  const touches = (b) => !b || b[0][1] <= floor + 1 || down.some((o) => o && holds(b, o)
    && (!o.turned || touchesTurned(b, o.turned)));
  const size = (b) => (b ? (b[1][0] - b[0][0]) * (b[1][1] - b[0][1]) * (b[1][2] - b[0][2]) : 0);
  const holders = low.map((p, n) => {
    // The middle of its box, not its origin: a plate's origin is its top,
    // the underside of the brick on it, and as "inside" that brick the
    // plate went after it, the brick into the air a plate over the plate
    // under (8841-1's first 3701, 2026-10-17). A pin's middle is its own.
    const at = box[n] ? [0, 1, 2].map((i) => (box[n][0][i] + box[n][1][i]) / 2) : toApp(p.at);
    const round = low.filter((q, k) => k !== n && box[k] && size(box[k]) > size(box[n])
      && at.every((v, i) => v >= box[k][0][i] - 1 && v <= box[k][1][i] + 1));
    round.sort((a, b) => size(box[low.indexOf(a)]) - size(box[low.indexOf(b)]));
    return round.slice(0, 1);
  });
  // How much of what is down holds it: the area it is on, in or under.
  const heldArea = (b) => (!b ? 0 : down.reduce((t, o) => {
    if (!o || !holds(b, o)) return t;
    return t + (Math.min(b[1][0], o[1][0]) - Math.max(b[0][0], o[0][0]))
      * (Math.min(b[1][2], o[1][2]) - Math.max(b[0][2], o[0][2]));
  }, 0));
  // Of the parts that pass [test], the lowest; of several as low, the one
  // most held: the 1 x 2 under the middle of a 1 x 4 before the 1 x 12 under
  // one end stud of it, which then goes beside the 1 x 2 (8841-1's top
  // beam, 2026-10-18).
  // Only among parts that hang: of parts that stand on what is under them
  // the file's order is kept.
  const first = (test) => {
    const n0 = low.findIndex(test);
    if (n0 < 0) return null;
    let best = n0;
    for (let n = n0 + 1; n < low.length && hangs(n0); n++) {
      if (Math.abs(low[n].at[1] - low[n0].at[1]) >= 1) break;
      if (test(low[n], n) && hangs(n) && heldArea(box[n]) > heldArea(box[best]) + 1) best = n;
    }
    return low[best];
  };
  const out = [];
  const done = new Set();
  // A part that hangs (nothing down under it, something down over it) waits
  // for the parts of its step it also hangs from: a plate under the joint of
  // a 1 x 2 and a 1 x 12 goes under both once both are down, where hung
  // from the 1 x 2 alone its middle went where the pointer was, under the
  // 1 x 2 (8841-1's top beam, 2026-10-18).
  const over = (b, o) => holds(b, o) && o[0][1] >= b[1][1] - 4.5;
  const under = (b, o) => holds(b, o) && o[1][1] <= b[0][1] + 4.5;
  const hangs = (n) => {
    const b = box[n];
    return Boolean(b) && b[0][1] > floor + 1 && !down.some((o) => o && under(b, o))
      && down.some((o) => o && over(b, o));
  };
  const waits = (n) => hangs(n)
    && low.some((q, k) => k !== n && !done.has(q) && box[k] && over(box[n], box[k]));
  while (out.length < low.length) {
    const ready = (p, n) => !done.has(p) && holders[n].every((q) => done.has(q));
    // Touching what is down goes first even before the part its middle is
    // in: a pin hung from a swung plate takes the connector after it, not
    // the connector first in the air (8841-1's pans).
    const next = first((p, n) => ready(p, n) && touches(box[n]) && !waits(n))
      || first((p, n) => ready(p, n) && touches(box[n]))
      || first((p, n) => !done.has(p) && touches(box[n]))
      || low.find((p, n) => ready(p, n)) || low.find((p) => !done.has(p));
    out.push(next);
    done.add(next);
    down.push(box[low.indexOf(next)]);
  }
  return out;
}

// What each step of [set] is put down on: the boxes of every part of the
// steps before it, and the bottom of the first step's parts, the floor.
export function handOrders(set, own = boxOf) {
  const first = set.steps[0] || [];
  const bottoms = first.map((p) => placedBox(p, own)).filter(Boolean).map((b) => b[0][1]);
  const floor = bottoms.length ? Math.min(...bottoms) : -Infinity;
  const before = [];
  return set.steps.map((step) => {
    const order = handOrder(step, own, before, floor);
    for (const p of step) before.push(placedBox(p, own));
    return order;
  });
}

// Under a part's origin, at the bottom of it where the file has it: the
// spot on what it stands on that a person points at. A brick's or a
// plate's origin is the middle of its top; a corner plate's is its corner
// stud, on its body, where the middle of its box is the corner it has not
// (2420, whose box's middle is over the arm of the wheel holder beside it).
//
// Under it along its own down, not the world's: a part on its side goes
// against a face by its underside, and a person points at that face. A
// round plate in a clip plate's ring stands on its side, its underside on
// the ring, and aimed below its middle its ghost fell to the floor in
// front of the ring (5762-1's lights, 2026-10-18); a plate on a bracket's
// side studs the same (8643-1's step 4).
//
// On its side, a stud's height out from its underside: what it goes on can
// reach that far into it, as the ring goes 3 LDU into the round plate, and
// the line from the eye to a point inside the ring met the ring's side, not
// the face whose stud seats the plate.
export function footOf(part, own = boxOf) {
  const box = own(part.id);
  if (!box) return [0, 0, 0];
  const m = appMatrix(part.m);
  const side = Math.abs(m[1][1]) < 0.5;
  return [0, 1, 2].map((r) => m[r][1] * (box[0][1] + (side ? 4 : 0)));
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
// The one of the 24 turns nearest [matrix] (rows), for a part the file
// has turned off them.
export function nearestTurn(matrix) {
  let best = null;
  let off = Infinity;
  for (const face of FACES) {
    for (let q = 0; q < 4; q++) {
      const b = basisFor(face, q);
      const d = b.reduce((sum, row, r) => sum + row.reduce((t, v, c) => t + (v - matrix[r][c]) ** 2, 0), 0);
      if (d < off) { off = d; best = { face, q }; }
    }
  }
  return best;
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
// The view once it has stopped moving, as a person waits for a turned view
// to come to rest before pointing: on a loaded box a view key eases in over
// seconds, and a part aimed from the view half way there went somewhere
// else (8643-1's right bracket plate, from its side, 2026-10-18).
async function settledView(seconds = 12) {
  let last = JSON.stringify((await fresh()).view);
  for (let n = 0; n < seconds * 2; n++) {
    const now = (await fresh()).view;
    if (JSON.stringify(now) === last) return now;
    last = JSON.stringify(now);
  }
  return (await fresh()).view;
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
  return { point: 0, click: 0, key: 0, typed: 0, scroll: 0, search: 0, colour: 0, colour_named: 0,
    turn: 0, aim_fix: 0, step: 0 };
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
  // A frame can take seconds to draw on a loaded box: the default 30 s
  // ended the plane's run at its picture once (2026-10-16).
  const shot = await page.screenshot({ clip, timeout: 180000 });
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
// Plainly that colour: about 8 apart in RGB at each point. Light Grey (7)
// and Light Bluish Grey (71) are 15 apart at each point in the app's
// palette, so a swatch that is only near is not taken on its look.
const SURE = 24;
let colourInHand = 4;
async function chooseColour(code) {
  if (code === colourInHand) return true;
  const at = (await controls()).palette;
  if (at && at.w) {
    const clip = { x: Math.round(at.x - at.w / 2) + 2, y: Math.round(at.y - at.h / 2) + 2,
      width: at.w - 4, height: at.h - 4 };
    const found = (await findSwatches([code], clip))[code];
    if (found && found.score < SURE) {
      count.colour += 1;
      await clickAt(found.x, found.y);
      const s = await until((now) => now.colour === code, 3);
      if (s.colour === code) {
        colourInHand = code;
        return Math.round(found.score);
      }
      // The note under the palette names another colour: a look-alike.
      colourInHand = s.colour ?? colourInHand;
    }
  }
  // By its name, in the palette's own search: Shift-C, the name typed
  // until the line over the palette names it first, Enter.
  const name = ((colours[code] || {}).name || String(code)).toLowerCase();
  count.colour += 1;
  count.colour_named += 1;
  await key("Shift+C", 300);
  for (let n = 0; n < name.length; n++) {
    await typeText(name[n]);
    if (name[n] === " ") continue;
    const s = await until((now) => now.colour_first === code, 1.5);
    if (s.colour_first === code) break;
  }
  await key("Enter", 600);
  const s = await until((now) => now.colour === code, 5);
  colourInHand = s.colour ?? colourInHand;
  return s.colour === code ? "by name" : false;
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

// What each kind of end in hand goes on (JointSnap.TAKES).
const TAKES = { pin: ["pin_hole"], axle: ["axle_hole", "pin_hole"], pin_hole: ["pin", "axle"],
  axle_hole: ["axle"], shaft: ["bore"], bore: ["shaft"], tyre: ["rim"], rim: ["tyre"] };
// The ends of a part that goes into or round another's: a pin, an axle, a
// tyre, a rim.
const INTO = new Set(["pin", "axle", "tyre", "rim"]);
// How near on the page to where the part goes a joint is looked at, px.
const JOINT_PX = 40;
// T and R on a joint, as a person turns a pin over and round in its hole
// until it stands as the booklet shows it: each way onto it first (a pin
// has four: either end in, from either face), the part held as the file
// has it, then each again half a turn round, then a quarter either way.
const ON_JOINT_KEYS = ["t", "t", "t", "t", "r", "r", "r", "r", "t", "t", "t",
  "t", "r", "r", "t", "t", "t", "t", "r", "r", "r", "r", "t", "t", "t"];

// Whether the ghost stands at [target] turned as [turn] (the app's matrix,
// rows), to an LDU and a hundredth.
function standsAt(s, target, turn) {
  if (!s.ghost || !s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1)) return false;
  const pose = s.ghost_pose;
  if (!pose || !turn) return true;
  for (let c = 0; c < 3; c++) {
    for (let r = 0; r < 3; r++) if (Math.abs(pose[3 + c * 3 + r] - turn[r][c]) > 0.01) return false;
  }
  return true;
}

// Whether the ghost is turned as [turn] (the app's matrix, rows), wherever
// it stands.
function turnedAs(s, turn) {
  const pose = s.ghost_pose;
  if (!s.ghost || !pose || !turn) return false;
  for (let c = 0; c < 3; c++) {
    for (let r = 0; r < 3; r++) if (Math.abs(pose[3 + c * 3 + r] - turn[r][c]) > 0.01) return false;
  }
  return true;
}

// The part in hand onto the joint its place is on: the ends of the parts
// down that its own ends take, nearest on the page to where it goes, each
// pointed at in turn, and on one, R and T until the ghost stands where the
// file has it. A pin aimed about a brick goes on the studs; aimed at the
// hole it goes in (8841-1's pins, 2026-10-17). Null when none takes it.
async function onItsJoint(target, turn, view, here, any = false, part = null) {
  let s = await fresh();
  const kinds = new Set((s.held_ends || []).flatMap((k) => TAKES[k] || []));
  if (!kinds.size) return null;
  const aim = project(target, view, shift);
  // Looked for only for a part that goes into or round something: a Technic
  // brick has holes but goes on the studs, and hung on every pin near it
  // first it took 23 presses (8841-1's second 3702, 2026-10-17).
  // [any]: the last try for a part with holes and no pin of its own, which
  // goes onto pins when it does not go on the studs (a Technic brick on its
  // side); a pin's own were tried at its first aim.
  const into = (s.held_ends || []).some((k) => INTO.has(k));
  const goes = any ? !into : into;
  const near = (goes ? s.joints || [] : []).filter((j) => kinds.has(j.kind))
    .map((j) => ({ ...j, d: Math.hypot(j.x - aim[0], j.y - aim[1]) }))
    .filter((j) => j.d <= JOINT_PX || within(part, j, view)).sort((a, b) => a.d - b.d).slice(0, 3);
  // Already on a joint where the pointer is, in the file's place but turned
  // otherwise: turned there first. On one somewhere else it is not this
  // part's joint (8841-1's second brick hung on the first one's pin, and
  // turned there 77 presses, 2026-10-17).
  const placed = s.ghost && s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1);
  if (s.on_joint && placed) near.unshift({ x: here[0], y: here[1], here: true });
  for (const j of near) {
    if (!j.here) {
      count.aim_fix += 1;
      await pointTo(j.x, j.y);
      s = await fresh();
    }
    if (!s.on_joint) continue;
    let at = [j.x, j.y];
    for (let n = 0; n <= ON_JOINT_KEYS.length; n++) {
      if (n > 0) {
        await key(ON_JOINT_KEYS[n - 1], 300);
        s = await fresh();
      }
      // Turned as the file has it but along the joint from its place (a
      // wheel on its pin, a clip on its bar): slid there, the pointer moved
      // along it as a person moves a wheel along its pin (8643-1's wheels).
      for (let slide = 0; slide < 3 && s.on_joint && turnedAs(s, turn)
          && !standsAt(s, target, turn); slide++) {
        const a = project(s.ghost, view, shift);
        const b = project(target, view, shift);
        if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 1) break;
        at = [at[0] + b[0] - a[0], at[1] + b[1] - a[1]];
        count.aim_fix += 1;
        await pointTo(at[0], at[1]);
        s = await fresh();
      }
      if (!standsAt(s, target, turn) || !s.can_place) {
        if (at[0] !== j.x || at[1] !== j.y) {
          at = [j.x, j.y];
          await pointTo(at[0], at[1]);
          s = await fresh();
        }
        continue;
      }
      // Seen there twice, as below.
      const again = await fresh();
      if (!standsAt(again, target, turn) || !again.can_place) continue;
      const before = again.bricks;
      count.click += 1;
      await page.mouse.click(at[0], at[1]);
      const after = await until((now) => now.bricks > before, 8);
      if (after.bricks > before) followRise(after, again.ghost);
      return after.bricks > before ? { ok: true, at: again.ghost }
        : { ok: false, why: "the click put nothing down" };
    }
  }
  return null;
}

let shiftToApp = null;
// The parts put down so far, as the file has them.
let downParts = [];
let viewRect = [362, 106, 1238, 710];
// A part put down below the ground, held by the model, stands the model up
// on it (Builder._stand_on_the_ground): the part went down that much higher
// than its ghost, and everything built is that much higher than the file
// says from here on, as a person sees the model rise.
function followRise(now, ghost) {
  const put = now.put && now.put.pose;
  if (!put || !ghost || Math.abs(put[0] - ghost[0]) > 0.5 || Math.abs(put[2] - ghost[2]) > 0.5) return;
  const rose = Math.round(put[1] - ghost[1]);
  if (rose < 1) return;
  shiftToApp[1] += rose;
  log(`the model rose ${rose} LDU to stand on it`);
}
async function put(part, view) {
  const want = toApp(part.at);
  if (shiftToApp) {
    // Where a person points: the middle of the part's underside, on what it
    // stands on; then, if the ghost will not come there, its origin, as
    // the flow first aimed (a part that hangs under another is pointed at
    // by its top). A brick's origin is the top of it, a brick's height over
    // the plate it goes on: aimed there, a 1 x 4 Technic brick on a stack
    // one stud wide went past the stack, onto its side (8841-1's step 1,
    // 2026-10-17).
    const foot = footOf(part);
    const passes = Math.hypot(...foot) > 0.5
      ? [[foot, AIMS, true], [[0, 0, 0], Math.ceil(AIMS / 2), false]]
      : [[[0, 0, 0], AIMS, true]];
    let got = null;
    for (const [by, aims, tryJoint] of passes) {
      got = await putBy(part, view, by, aims, tryJoint);
      if (got.ok || got.final) return got;
      view = (await fresh()).view;
    }
    // Onto a joint at last, for a part with holes too: a brick on its side
    // goes onto pins, not studs (8841-1's 3703s).
    const target = want.map((v, i) => v + shiftToApp[i]);
    const onto = await onItsJoint(target, appMatrix(part.m), view, project(target, view, shift), true,
      part);
    if (onto) return onto;
    // At what it goes against: the face of a part down that it meets, as a
    // person points beside a brick or under a beam.
    const contacts = contactsOf(part);
    const against = await atContacts(part, target, appMatrix(part.m), view,
      contacts.filter((c) => !c.under));
    if (against) return against;
    // Under a part: from below, as a person turns the view up under a
    // beam to see its underside. The model framed first, so the eye stays
    // above the floor (8841-1's top beam hangs its middle under a 1 x 4).
    if (contacts.some((c) => c.under)) {
      await key("f", 1500);
      await key(sideKey(target) || "3", 1500);
      await key("ArrowDown", 1200);
      const below = await settledView();
      const hung = await atContacts(part, target, appMatrix(part.m), below,
        contacts.filter((c) => c.under));
      await key("0", 1500);
      if (hung) return hung;
      view = (await fresh()).view;
    }
    // From the side it is on, as a person turns the view to see the far
    // side of a car: a wheel on the far side's pin is behind the body, and
    // the line from the eye meets the body first (8643-1's right wheels).
    // A view key (1 to 4) tipped 20 degrees, the passes again, and the default
    // view (0) after.
    const side = sideKey(target);
    if (side) {
      // The key's view is level with the ground, and a line from it aimed
      // a little high meets nothing short of the horizon: Up twice, as a
      // person tips the view to see the side and the top together (an
      // arrow turns the view 10 degrees with nothing selected).
      await key(side, 1500);
      await key("ArrowUp", 400);
      await key("ArrowUp", 1200);
      let there = await settledView();
      for (const [by, aims, tryJoint] of passes) {
        got = await putBy(part, there, by, Math.ceil(aims / 2), tryJoint);
        if (got.ok || got.final) break;
        there = (await fresh()).view;
      }
      if (!got.ok && !got.final) {
        const again = await onItsJoint(target, appMatrix(part.m), there,
          project(target, there, shift), true, part);
        if (again) got = again;
      }
      if (!got.ok && !got.final) {
        const against = await atContacts(part, target, appMatrix(part.m), there,
          contactsOf(part).filter((c) => !c.under));
        if (against) got = against;
      }
      // Near, but where the pointer cannot say (below), from this side.
      if (!got.ok && !got.final) {
        const typed = await putNearAndType(part, target, appMatrix(part.m), there);
        if (typed) got = typed;
      }
      await key("0", 1500);
      return got;
    }
    // Near, but where the pointer cannot say: put down where it comes
    // nearest, on its joint or on the studs, and its swing and place typed
    // in Properties (Hinge, X, Y, Z), as Studio's hinge tool and a typed
    // move say it. 8841-1's pans hang at 66.4 degrees, half a stud off the
    // stud grid (offgrid_probe types the same numbers).
    const typed = await putNearAndType(part, target, appMatrix(part.m), view);
    return typed || got;
  }
  return putFirst(part, view, want);
}

// Whether a joint on the page ([j], CSS pixels) is over where [part] goes:
// inside its box at the file's place, drawn on the page. A part's middle
// can be far from the ends it goes on by: 8841-1's 1 x 16 Technic brick
// stands on end on two pins 100 LDU and more below its middle.
function within(part, j, view) {
  const box = part && placedBox(part, boxOf);
  if (!box || !shiftToApp) return false;
  let lo = [Infinity, Infinity];
  let hi = [-Infinity, -Infinity];
  for (let c = 0; c < 8; c++) {
    const p = project([box[c & 1][0], box[(c >> 1) & 1][1], box[(c >> 2) & 1][2]]
      .map((v, i) => v + shiftToApp[i]), view, shift);
    lo = [Math.min(lo[0], p[0]), Math.min(lo[1], p[1])];
    hi = [Math.max(hi[0], p[0]), Math.max(hi[1], p[1])];
  }
  return j.x >= lo[0] - 6 && j.x <= hi[0] + 6 && j.y >= lo[1] - 6 && j.y <= hi[1] + 6;
}

// Where [part] meets the parts down, where the file has it: for each part
// down its box touches, a point on that part's face where they meet, the
// middle of the meeting, a hair inside the part down so the line from the
// eye strikes its face. Most met first; [under] for a face it hangs under.
function contactsOf(part) {
  const pb = placedBox(part, boxOf);
  if (!pb || !shiftToApp) return [];
  const out = [];
  for (const q of downParts) {
    const qb = placedBox(q, boxOf);
    if (!qb) continue;
    const ov = [0, 1, 2].map((i) => Math.min(pb[1][i], qb[1][i]) - Math.max(pb[0][i], qb[0][i]));
    let a = 0;
    for (let i = 1; i < 3; i++) if (ov[i] < ov[a]) a = i;
    // Against it across one axis (a stud's height into it at most), and
    // sharing a face on the other two.
    if (ov[a] < -1 || ov[a] > 4.5 || [0, 1, 2].some((i) => i !== a && ov[i] < 2)) continue;
    const up = (pb[0][a] + pb[1][a]) > (qb[0][a] + qb[1][a]);
    const point = [0, 1, 2].map((i) => (i === a ? (up ? pb[0][i] - 0.5 : pb[1][i] + 0.5)
      : (Math.max(pb[0][i], qb[0][i]) + Math.min(pb[1][i], qb[1][i])) / 2) + shiftToApp[i]);
    const area = [0, 1, 2].filter((i) => i !== a).reduce((t, i) => t * ov[i], 1);
    out.push({ point, under: a === 1 && !up, area, id: q.id });
  }
  return out.sort((x, y) => y.area - x.area);
}

// The part in hand aimed at each of [contacts] (contactsOf) in turn, and
// nudged across that face by what its ghost is off, until the ghost stands
// at [target] turned as [turn]; then put. Null when none brings it there.
async function atContacts(part, target, turn, view, contacts) {
  for (const c of contacts.slice(0, 3)) {
    let pointer = project(c.point, view, shift);
    for (let n = 0; n < 4; n++) {
      const [vx, vy, vw, vh] = viewRect;
      if (pointer[0] < vx + 8 || pointer[0] > vx + vw - 8 || pointer[1] < vy + 8
          || pointer[1] > vy + vh - 8) break;
      count.aim_fix += 1;
      await pointTo(pointer[0], pointer[1]);
      const s = await fresh();
      if (!s.ghost) break;
      if (standsAt(s, target, turn) && s.can_place) {
        const again = await fresh();
        if (!standsAt(again, target, turn) || !again.can_place) continue;
        const before = again.bricks;
        count.click += 1;
        await page.mouse.click(pointer[0], pointer[1]);
        const after = await until((now) => now.bricks > before, 8);
        if (after.bricks <= before) return null;
        followRise(after, again.ghost);
        log(`put against the ${c.under ? "underside" : "face"} of ${c.id}`);
        return { ok: true, at: again.ghost };
      }
      const a = project(s.ghost, view, shift);
      const b = project(target, view, shift);
      if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 1) break;
      pointer = [pointer[0] + b[0] - a[0], pointer[1] + b[1] - a[1]];
    }
  }
  return null;
}

// How far a part may come down from its place and still be typed there.
const NEAR_LDU = 60;

// The part in hand pointed at its place's projection, then at the joints
// near it, and put down where its ghost may go nearest its place, within
// NEAR_LDU; then selected and typed to the file (typeTo). Null when it
// came nowhere near, or the typing did not bring it there (undone).
async function putNearAndType(part, target, turn, view) {
  const tries = [project(target, view, shift)];
  const s0 = await fresh();
  const kinds = new Set((s0.held_ends || []).flatMap((k) => TAKES[k] || []));
  for (const j of s0.joints || []) {
    if (kinds.has(j.kind) && (Math.hypot(j.x - tries[0][0], j.y - tries[0][1]) <= JOINT_PX
        || within(part, j, view))) tries.push([j.x, j.y]);
  }
  for (const at of tries.slice(0, 4)) {
    count.aim_fix += 1;
    await pointTo(at[0], at[1]);
    const s = await fresh();
    if (!s.ghost || !s.can_place) continue;
    if (Math.hypot(...s.ghost.map((v, i) => v - target[i])) > NEAR_LDU) continue;
    // Put down there, then typed.
    const before = s.bricks;
    count.click += 1;
    await page.mouse.click(at[0], at[1]);
    const after = await until((now) => now.bricks > before, 8);
    if (after.bricks <= before) return null;
    followRise(after, s.ghost);
    const done = await typeTo(part, target, turn, view);
    if (done.ok) return { ok: true, at: target, typed: done.typed };
    // Not brought there: taken back, as a person undoes a wrong part.
    for (let n = 0; n < done.steps + 1; n++) await key("Control+z", 500);
    log(`typed ${done.typed.join(", ") || "nothing"}, and it did not stand at its place: undone`);
    return null;
  }
  return null;
}

// Whether a pose (brickworksState.put.pose: origin, then the basis's
// columns) stands at [target] turned as [turn], to 0.05 LDU and 0.002.
function poseAt(pose, target, turn, place = 0.05) {
  if (!pose || !pose.slice(0, 3).every((v, i) => Math.abs(v - target[i]) <= place)) return false;
  for (let c = 0; c < 3; c++) {
    for (let r = 0; r < 3; r++) if (Math.abs(pose[3 + c * 3 + r] - turn[r][c]) > 0.002) return false;
  }
  return true;
}

// The Hinge (degrees off square about the joint, Builder.hinge_angle) of
// [turn], about the axis [from] turns about to come to it: of the 24 square
// turns, the one [turn] is the least swing from about that axis. Both
// signs are offered: which way round the joint's axis runs is the app's.
function hingeOf(from, turn) {
  const mulT = (A, B) => A.map((row) => [0, 1, 2].map((j) => row.reduce((t, v, k) => t + v * B[j][k], 0)));
  const axisAngle = (M) => {
    const angle = Math.acos(Math.max(-1, Math.min(1, (M[0][0] + M[1][1] + M[2][2] - 1) / 2)));
    const v = [M[2][1] - M[1][2], M[0][2] - M[2][0], M[1][0] - M[0][1]];
    const len = Math.hypot(...v);
    return { angle, axis: len > 1e-6 ? v.map((x) => x / len) : [0, 0, 0] };
  };
  const swing = axisAngle(mulT(turn, from));
  if (swing.angle < 1e-4) return [];
  let best = null;
  for (const face of FACES) {
    for (let q = 0; q < 4; q++) {
      const m = axisAngle(mulT(turn, basisFor(face, q)));
      const along = m.axis.reduce((t, v, i) => t + v * swing.axis[i], 0);
      if (m.angle > 1e-4 && Math.abs(along) < 0.999) continue;
      const degrees = m.angle * 180 / Math.PI * (along < 0 ? -1 : 1);
      if (Math.abs(degrees) <= 45.01 && (!best || Math.abs(degrees) < Math.abs(best))) best = degrees;
    }
  }
  return best === null ? [] : [best, -best];
}

// The part just put down selected by a click on it, and what the pointer
// could not say typed in Properties: its swing (Hinge), then X, Y and Z.
// Each typed number a click in its box, Ctrl+A, the number, Enter. Read
// back from where the app says that part now stands (brickworksState.put).
async function typeTo(part, target, turn, view) {
  const typed = [];
  let steps = 0;
  let s = await fresh();
  const put = s.put;
  if (!put) return { ok: false, typed, steps };
  await key("Escape", 500);
  inHand = "";
  // On its body: the middle of its box where it stands, then a little in.
  const own = boxOf(part.id);
  const middle = own ? [0, 1, 2].map((i) => (own[0][i] + own[1][i]) / 2) : [0, 0, 0];
  const P = [0, 1, 2].map((r) => [0, 1, 2].map((c) => put.pose[3 + c * 3 + r]));
  const at = [0, 1, 2].map((r) => put.pose[r] + P[r].reduce((t, v, c) => t + v * middle[c], 0));
  let selected = false;
  for (const nudge of [[0, 0], [0, -3], [3, 0], [-3, 0], [0, 3]]) {
    const p = project(at, view, shift);
    await clickAt(p[0] + nudge[0], p[1] + nudge[1]);
    s = await fresh();
    if ((s.selection || []).includes(put.id) && s.selected === 1) { selected = true; break; }
  }
  if (!selected) return { ok: false, typed: ["could not select it"], steps };
  // Each number that moved it is a step of the history, for the undo if
  // it never comes to its place; one refused ("no room there") is none.
  const typeIn = async (name, value) => {
    const box = (await controls())[name];
    if (!box) return false;
    const was = JSON.stringify(((await fresh()).put || {}).pose);
    await clickAt(box.x, box.y);
    await key("Control+a", 150);
    await typeText(String(value));
    await key("Enter", 900);
    typed.push(`${name.replace("prop_", "")} ${value}`);
    if (JSON.stringify(((await fresh()).put || {}).pose) !== was) steps += 1;
    return true;
  };
  s = await fresh();
  const pose = () => ((s.put || {}).id === put.id && s.put.pose) || put.pose;
  if (!poseAt(pose(), pose().slice(0, 3), turn)) {
    const from = [0, 1, 2].map((r) => [0, 1, 2].map((c) => pose()[3 + c * 3 + r]));
    for (const hinge of hingeOf(from, turn)) {
      if (!(await typeIn("prop_hinge", hinge.toFixed(2)))) break;
      s = await fresh();
      if (poseAt(pose(), pose().slice(0, 3), turn)) break;
    }
  }
  const names = ["prop_x", "prop_y", "prop_z"];
  for (let pass = 0; pass < 2 && !poseAt(pose(), target, turn); pass++) {
    for (let i = 0; i < 3; i++) {
      if (Math.abs(pose()[i] - target[i]) <= 0.02) continue;
      await typeIn(names[i], target[i].toFixed(2));
      s = await fresh();
    }
  }
  const ok = poseAt(pose(), target, turn);
  await key("Escape", 400);
  log(`typed ${typed.join(", ")}: ${ok ? "at its place" : "not at its place"}`);
  return { ok, typed, steps };
}

// The middle of the set's parts as the file has them, in the app's axes:
// which side of the model a part is on.
let setMiddle = [0, 0, 0];
// The view key that looks at [target] from its own side of the model (1
// front, 2 back, 3 left, 4 right; CadCamera.set_view). A part near the
// middle too, from the side it leans to: the plane's 1 x 2 behind its two
// slopes was hidden by them from the default view, and a person turns the
// view to see behind them (2026-10-18).
function sideKey(target) {
  if (!shiftToApp) return null;
  const d = target.map((v, i) => v - setMiddle[i] - shiftToApp[i]);
  if (Math.abs(d[0]) >= Math.abs(d[2])) return d[0] > 0 ? "4" : "3";
  return d[2] > 0 ? "1" : "2";
}

// The part in hand aimed with the pointer at the file's place moved [by]
// (the point aimed at, from the part's origin), corrected by where its
// ghost stands, [aims] times.
async function putBy(part, view, by, aims, tryJoint) {
  {
    const want = toApp(part.at);
    const target = want.map((v, i) => v + shiftToApp[i]);
    const turn = appMatrix(part.m);
    const off = (p) => p.map((v, i) => v + by[i]);
    let pointer = project(off(target), view, shift);
    let last = null;
    let outs = 0;
    let joint = false;
    for (let n = 0; n < aims; n++) {
      // Off the model's part of the window, a click would land on a panel:
      // out a little, as a person zooms out to see where it goes.
      const [vx, vy, vw, vh] = viewRect;
      if (pointer[0] < vx + 8 || pointer[0] > vx + vw - 8 || pointer[1] < vy + 8 || pointer[1] > vy + vh - 8) {
        if (outs++ >= 2) return { ok: false, final: true, why: "its place stays off the view" };
        await pointTo(vx + vw / 2, vy + vh / 2);
        await key("Minus", 300);
        await key("Minus", 600);
        view = (await fresh()).view;
        pointer = project(off(target), view, shift);
        continue;
      }
      if (n > 0) count.aim_fix += 1;
      await pointTo(pointer[0], pointer[1]);
      let s = await fresh();
      // On the web a part is fetched when it is taken; its ghost comes
      // when it has arrived.
      if (n === 0 && !s.ghost) s = await until((now) => Boolean(now.ghost), 12);
      last = s.ghost;
      // Seen there twice, as a person waits for the ghost to settle: the
      // page can be told a ghost a frame behind the pointer, and both clip
      // plates went down a stud from where one read said (2026-10-16).
      if (s.ghost && s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1) && s.can_place) {
        const again = await fresh();
        if (!again.ghost || !again.ghost.every((v, i) => Math.abs(v - target[i]) <= 1)) {
          last = again.ghost;
          continue;
        }
      }
      // On a joint, turned as the file has it too: a pin the other way round
      // in its hole stands in the same place (8841-1's second pin, 2026-10-17).
      const turnedRight = !s.on_joint || standsAt(s, target, turn);
      if (s.ghost && s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1) && s.can_place
          && turnedRight) {
        const before = s.bricks;
        count.click += 1;
        await page.mouse.click(pointer[0], pointer[1]);
        const after = await until((now) => now.bricks > before, 8);
        if (after.bricks > before) followRise(after, s.ghost);
        return after.bricks > before ? { ok: true, at: s.ghost }
          : { ok: false, final: true, why: "the click put nothing down" };
      }
      if (s.ghost && s.ghost.every((v, i) => Math.abs(v - target[i]) <= 1) && !s.can_place
          && turnedRight) {
        return { ok: false, final: true, why: "the ghost stands in the file's place but the app says it may not go there" };
      }
      // Not there: if it joins by something, onto the joint it goes on, once.
      if (!joint && tryJoint) {
        joint = true;
        const onto = await onItsJoint(target, turn, view, pointer, false, part);
        if (onto) return onto;
        await pointTo(pointer[0], pointer[1]);
        s = await fresh();
      }
      if (!s.ghost) {
        pointer = [pointer[0] + (n % 2 ? -7 : 7), pointer[1] + 5];
        continue;
      }
      // Fallen past what it goes on, onto something lower (the floor beyond
      // a wing it overhangs): moved across on the level it fell to, where
      // the pointer is, not towards its place in the air above that, which
      // the line from the eye passes over to the floor further on again
      // (5762-1's wedge plates, 2026-10-17).
      const across = s.ghost[1] < target[1] - 1
        && (Math.abs(s.ghost[0] - target[0]) > 1 || Math.abs(s.ghost[2] - target[2]) > 1);
      const a = project(off(s.ghost), view, shift);
      const b = project(off(across ? [target[0], s.ghost[1], target[2]] : target), view, shift);
      const step = [b[0] - a[0], b[1] - a[1]];
      // The ghost on the wrong level and nothing to move across: the
      // pointer is over another part's face; edge it inwards.
      if (Math.hypot(...step) < 1.5) pointer = [pointer[0] + (n % 2 ? 4 : -4), pointer[1] + 6];
      else pointer = [pointer[0] + step[0], pointer[1] + step[1]];
    }
    return { ok: false, why: `the ghost would not stand there (last at ${JSON.stringify(last)}, wanted ${JSON.stringify(target)})` };
  }
}

// The first part: anywhere on the baseplate, in the middle of the view.
async function putFirst(part, view, want) {
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
  // Each part put down exactly: the file's step it is in, and the model's.
  const pairs = [];
  const takeOne = (test, p = null) => {
    const n = left.findIndex(test);
    if (n < 0) return false;
    if (p) pairs.push([p.step, left[n].step]);
    left.splice(n, 1);
    return true;
  };
  // Each kind of match over every part of the file before the next, looser
  // one: one part at a time, a file part with nothing built in its place
  // took, as moved, another's that was exact (8841-1's first 8, whose file
  // lists a plate above before the plate beside it, 2026-10-17).
  let rest = [...a];
  const tests = [
    ["exact", (p, q) => q.id === p.id && q.colour === p.colour && near(p, q) && same(p, q)],
    ["recoloured", (p, q) => q.id === p.id && near(p, q) && same(p, q)],
    ["turned", (p, q) => q.id === p.id && near(p, q)],
    ["moved", (p, q) => q.id === p.id && q.colour === p.colour],
  ];
  for (const [kind, test] of tests) {
    rest = rest.filter((p) => {
      if (!takeOne((q) => test(p, q), kind === "exact" ? p : null)) return true;
      why[kind] += 1;
      return false;
    });
  }
  why.missing = rest.length;
  return { shift: by, ...why, extra: left.length, file: a.length, built: b.length,
    steps: sameSteps(pairs) };
}

// Of the file's steps with a part put down exactly, how many came out one
// step of the model's holding no other step's parts: the steps kept.
function sameSteps(pairs) {
  const toBuilt = new Map();
  const fromBuilt = new Map();
  for (const [file, built] of pairs) {
    if (!toBuilt.has(file)) toBuilt.set(file, new Set());
    if (!fromBuilt.has(built)) fromBuilt.set(built, new Set());
    toBuilt.get(file).add(built);
    fromBuilt.get(built).add(file);
  }
  let kept = 0;
  for (const [, built] of toBuilt) {
    if (built.size === 1 && fromBuilt.get([...built][0]).size === 1) kept += 1;
  }
  return { file_steps: toBuilt.size, kept, model_steps: fromBuilt.size };
}

async function frameAndShoot(path) {
  await key("0", 600);
  await key("f", 2500);
  await page.waitForTimeout(2500);
  const [x, y, width, height] = viewRect;
  await page.screenshot({ path, clip: { x, y, width, height }, timeout: 180000 });
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
  await view.screenshot({ path, timeout: 180000 });
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
  {
    const all = set.steps.flat().map((p) => toApp(p.at));
    setMiddle = [0, 1, 2].map((i) => all.reduce((t, p) => t + p[i], 0) / Math.max(all.length, 1));
  }
  const stem = basename(name).replace(/\.(mpd|ldr)$/i, "");
  log(`${stem}: ${set.steps.flat().length} parts in ${set.steps.length} steps`);
  count = fresh_counts();
  colourInHand = 4;
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
  downParts = placed;
  // The parts put down where the pointer could not say it, and what was
  // typed in Properties for each.
  const typedParts = [];
  let done = 0;
  let framed = false;
  let stepHas = 0;
  const orders = handOrders(set);
  for (let k = 0; k < set.steps.length; k++) {
    // Lowest first, as a hand puts them on: what holds a part before it.
    const step = orders[k];
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
      // Off the 24 turns (a pan's 4262 swung on its axle) or off the whole
      // LDU (a part on one off the lattice): held at the nearest of the 24
      // and tried all the same, since on a joint the app swings a part onto
      // a second one and puts a part on one off the lattice in its frame.
      const turn = turnFor(appMatrix(part.m)) || nearestTurn(appMatrix(part.m));
      const skip = (why) => {
        gaps.push({ step: k + 1, part: part.id, colour: part.colour, why });
        appendFileSync(`${out}/${stem}_parts.jsonl`, JSON.stringify({ step: k + 1, id: part.id,
          colour: part.colour, put: false, why, seconds: (Date.now() - t0) / 1000 }) + "\n");
        log(`step ${k + 1} ${part.id}/${part.colour}: GAP ${why}`);
      };
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
        typed: put_.typed || [], seconds: (Date.now() - t0) / 1000, spent }) + "\n");
      if (put_.ok && put_.typed) typedParts.push(`${part.id} (step ${k + 1}): ${put_.typed.join(", ")}`);
      log(`step ${k + 1} ${part.id}/${part.colour}: ${put_.ok ? "put" : "GAP " + put_.why} `
        + `(${((Date.now() - t0) / 1000).toFixed(1)} s, colour ${chose}, ${JSON.stringify(spent)})`);
      if (put_.ok) stepHas += 1;
    }
    // The step's parts are down: E, Next step, as the file ends it.
    if (stepHas > 0) {
      count.step += 1;
      await key("e", 900);
      const said = (await fresh()).said || "";
      log(`step ${k + 1} marked: "${said}"`);
      stepHas = 0;
    }
    if (MOST && done >= MOST) break;
  }
  const seconds = (Date.now() - began) / 1000;
  await key("Escape", 400);
  inHand = "";
  // Right on the timeline, the last part having been taken by a click on
  // its tile: a tile once kept the keys, and Right moved the focus round
  // the bin instead (2026-10-16). Not a person's building, so not counted.
  const focus = { tile_clicked: true };
  await page.keyboard.press("b");
  const open = await until((now) => Array.isArray((now.timeline || {}).at), 60);
  focus.before = (open.timeline || {}).at || null;
  await page.keyboard.press("Home");
  await page.waitForTimeout(800);
  const home = ((await fresh()).timeline || {}).at || null;
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(800);
  const after = ((await fresh()).timeline || {}).at || null;
  focus.home = home;
  focus.after_right = after;
  focus.right_steps = Boolean(home && after && after[0] > home[0]);
  log(`focus: the timeline at ${JSON.stringify(home)}, after Right ${JSON.stringify(after)}`);
  await page.keyboard.press("b");
  await page.waitForTimeout(1500);
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
  // Every part as it was asked for and as it came out, for the report.
  const builtParts = exported ? readSet(exported).steps.flat() : [];
  const row = {
    set: name, parts_in_file: set.steps.flat().length, steps: set.steps.length, tried: parts,
    sub_models: set.subs, placed: placed.length, compared, counts: count, actions,
    actions_per_part: +(actions / parts).toFixed(2), seconds: +seconds.toFixed(1),
    seconds_per_part: +(seconds / parts).toFixed(2), gaps, focus, typed: typedParts,
    // The author's steps, marked as they were built: E once a step.
    step_marking: { steps: set.steps.length, marked: count.step,
      kept: compared ? compared.steps : null },
    pictures: { built: shotBuilt, file: shotFile, side_by_side: `${out}/${stem}_side_by_side.png` },
    // In the order they were tried: each step's lowest first.
    parts_list: orders.map((s, k) => s.map((p) => ({ step: k + 1, id: p.id, colour: p.colour,
      turn: turnFor(appMatrix(p.m)) }))).flat(),
    built_parts: builtParts.map((p) => ({ id: p.id, colour: p.colour, at: p.at, m: p.m, step: p.step + 1 })),
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
  colours = palette(readFileSync(resolve("assets/generated/colors.json"), "utf8"));
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
      steps_kept: r.compared ? r.compared.steps : null, right_steps_timeline: r.focus ? r.focus.right_steps : null,
      recoloured: r.compared ? r.compared.recoloured : null,
      turned: r.compared ? r.compared.turned : null, moved: r.compared ? r.compared.moved : null,
      actions: r.actions, actions_per_part: r.actions_per_part, seconds_per_part: r.seconds_per_part,
      typed: r.typed || [], counts: r.counts, gaps: r.gaps.map((g) => (g.part ? `${g.part}/${g.colour} (step ${g.step}): ${g.why}` : g.why)),
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
