// The Brickworks mark built in real LEGO® parts (hero3d, 2026-11-23): the
// cube with one corner cut away of web/icon.svg, 12 studs a side and 240 LDU
// tall (ten bricks: a true cube), the cut 6 studs a side and half its height,
// built studs up from bricks and plates, its cut's floor three tiles, so the
// section reads smooth. Each outer face is the colour of the mark's face
// that looks that way (the top yellow, the faces across x blue, those across
// z red) and each face of the cut a shade darker (Dark Blue, Dark Red,
// Pearl Gold); what no face shows is Light Bluish Gray, as a
// builder's inside is. A corner both faces share goes to each in turn, a
// course at a time, as a brick wall's corner is bonded.
//
//   node tools/web/hero_mark.mjs            write it: models/brickworks_mark.ldr (the app's
//                                           example), web/hero/mark.ldr (the site's, the same
//                                           file) and web/hero/mark.json (packed for the home's
//                                           3D: api/_parts.js sceneOf, with its shapes)
//   node tools/web/hero_mark.mjs --check    fail if any of them is not what it writes
//
// mark.json carries the parts' geometry itself, the app's own .lbm less what
// the home never shows (each part's inside and underneath, its joints), and
// the studs apart from the parts they are on, with the brick that covers
// each: one answer the CDN compresses (the store's 19 files were 629 KB, sent
// as they are), and the 94% of the studs a course hides are never drawn
// (177,000 triangles were, 85,000 of them studs under bricks). The plates are
// never wider than two studs, so a piece lifted under the pointer is a
// brick's size, never the roof's.
//
// Each course is one step (0 STEP), bottom up, so the app's steps build it as
// the home's assembly does. Every part is checked here against the
// catalogue's colours (made in that colour, PartInfo.never_made_in) and
// every piece against the one below it (held by its studs), and the whole
// against itself (one piece); the app's Tested says the rest
// (src/dev/hero_mark_probe.gd).
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { sceneOf } from "../../api/_parts.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const N = 12; // studs a side
const CUT = 6; // the cut's side, in studs
const CUT_FROM = 15; // the cut's floor, in plates from the ground (120 LDU: half of 240)
// The courses, bottom up: [first plate, height in plates]. Bricks but where
// the cut's floor and the top need a plate's step: three plates under the
// floor (the last of them the floor's tiles), three on top (the last the
// yellow top, so a side shows a plate's line of it, not a brick's).
const COURSES = [[0, 3], [3, 3], [6, 3], [9, 3], [12, 1], [13, 1], [14, 1],
  [15, 3], [18, 3], [21, 3], [24, 3], [27, 1], [28, 1], [29, 1]];
const COLOURS = { top: 14, cutTop: 297, x: 1, cutX: 272, z: 4, cutZ: 320, inside: 71 };
// Each kind's parts by [across, along] in studs, along its own x.
const PARTS = {
  brick: { "1x1": "3005", "1x2": "3004", "1x3": "3622", "1x4": "3010", "1x6": "3009", "1x8": "3008",
    "2x2": "3003", "2x3": "3002", "2x4": "3001", "2x6": "2456", "2x8": "3007" },
  plate: { "1x1": "3024", "1x2": "3023b", "1x3": "3623", "1x4": "3710", "1x6": "3666", "1x8": "3460", "1x10": "4477",
    "2x2": "3022", "2x3": "3021", "2x4": "3020", "2x6": "3795", "2x8": "3034" },
  tile: { "1x1": "3070b", "1x2": "3069b", "2x2": "3068b" },
};
const catalogue = JSON.parse(readFileSync(join(ROOT, "assets/generated/catalogue.json"), "utf8"));
const info = new Map(catalogue.parts.map((p) => [p.id, p]));
const madeIn = (part, colour) => {
  const p = info.get(part);
  if (!p) throw new Error(`hero_mark: ${part} is not in the catalogue`);
  return !(p.colors || []).length || p.colors_partial || p.colors.includes(colour);
};

const solid = (i, j, plate) => i >= 0 && j >= 0 && i < N && j < N && !(i >= N - CUT && j >= N - CUT && plate >= CUT_FROM);
const inCut = (i, j) => i >= N - CUT && j >= N - CUT;

/// What [cell] of course [k] must be: a colour, or null where no face shows
/// it; and whether it is a tile.
function need(i, j, k) {
  const [from, tall] = COURSES[k];
  const top = from + tall;
  const covered = solid(i, j, top) && top < 30;
  if (!covered) return { colour: inCut(i, j) ? COLOURS.cutTop : COLOURS.top, tile: inCut(i, j) && top < 30 };
  // A side shows where the cell beside it is outside the cube or in the cut.
  const across = [[i - 1, j], [i + 1, j]].filter(([a, b]) => !solid(a, b, from));
  const along = [[i, j - 1], [i, j + 1]].filter(([a, b]) => !solid(a, b, from));
  const into = ([a, b]) => a >= 0 && b >= 0 && a < N && b < N;
  const xColour = across.length ? (across.some(into) ? COLOURS.cutX : COLOURS.x) : null;
  const zColour = along.length ? (along.some(into) ? COLOURS.cutZ : COLOURS.z) : null;
  // A corner of the cut's: the outside's, a skin round the section, so the
  // cut's walls end clean. A corner of the outside's that the mark's own
  // view sees one face of (+x and +z are seen, and its sway never turns the
  // others to it): that face's, so the outline is clean. The front corner,
  // whose two faces are both seen: the red face's all the way up, one
  // straight edge where the colours meet, as the logo's is (bonded red and
  // blue in turn, it read as a zip; the lead, 11-23).
  if (xColour !== null && zColour !== null) {
    if (xColour === COLOURS.cutX) return { colour: zColour, tile: false };
    if (zColour === COLOURS.cutZ) return { colour: xColour, tile: false };
    const xSeen = !solid(i + 1, j, from);
    const zSeen = !solid(i, j + 1, from);
    if (xSeen !== zSeen) return { colour: xSeen ? xColour : zColour, tile: false };
    return { colour: zColour, tile: false };
  }
  return { colour: xColour ?? zColour, tile: false };
}

/// Course [k] laid: each piece {part, colour, i, j, across, along, turned}.
/// Long along x on even courses and along z on odd, so each course crosses
/// the one under it; each cell's piece the biggest that fits from it in
/// the order the course is laid, all one colour where a face shows.
function lay(k) {
  const [from] = COURSES[k];
  const turned = k % 2 === 1;
  const taken = new Set();
  const key = (i, j) => `${i},${j}`;
  const pieces = [];
  const cells = [];
  for (let a = 0; a < N; a++) for (let b = 0; b < N; b++) cells.push(turned ? [a, b] : [b, a]);
  // A course laid the same way as the one two below starts each row a
  // piece short, so its joints fall over that one's bricks.
  const short = Math.floor(k / 2) % 2 === 1;
  for (const [i, j] of cells) {
    if (!solid(i, j, from) || taken.has(key(i, j))) continue;
    const here = need(i, j, k);
    const kind = here.tile ? "tile" : COURSES[k][1] === 3 ? "brick" : "plate";
    const sizes = Object.keys(PARTS[kind]).map((s) => s.split("x").map(Number))
      .sort((p, q) => q[0] * q[1] - p[0] * p[1] || q[1] - p[1]);
    let placed = null;
    for (const [w, l] of sizes) {
      // Along the course's way first, then across it.
      for (const [dx, dz] of turned ? [[w, l], [l, w]] : [[l, w], [w, l]]) {
        const startOfRow = turned ? j === 0 : i === 0;
        if (short && startOfRow && kind === "brick" && Math.max(dx, dz) > 2 && (turned ? dz : dx) > 2) continue;
        let colour = null;
        let fits = true;
        for (let a = i; a < i + dx && fits; a++) {
          for (let b = j; b < j + dz && fits; b++) {
            if (!solid(a, b, from) || taken.has(key(a, b))) { fits = false; break; }
            const there = need(a, b, k);
            if (there.tile !== here.tile) { fits = false; break; }
            if (there.colour !== null) {
              if (colour !== null && colour !== there.colour) fits = false;
              colour = there.colour;
            }
          }
        }
        if (!fits) continue;
        colour = colour ?? COLOURS.inside;
        const part = PARTS[kind][`${w}x${l}`];
        if (!madeIn(part, colour)) continue;
        placed = { part, colour, i, j, dx, dz, turned: dx < dz, kind };
        break;
      }
      if (placed) break;
    }
    if (!placed) throw new Error(`hero_mark: nothing fits course ${k} at ${i},${j}`);
    for (let a = i; a < i + placed.dx; a++) for (let b = j; b < j + placed.dz; b++) taken.add(key(a, b));
    pieces.push({ ...placed, from, tall: COURSES[k][1] });
  }
  return pieces;
}

const courses = COURSES.map((_, k) => lay(k));
const all = courses.flat();

// Each piece over the course under it is held by its studs, and the whole is
// one piece: pieces joined where one stands on another's studs.
const cellsOf = (p) => {
  const out = [];
  for (let a = p.i; a < p.i + p.dx; a++) for (let b = p.j; b < p.j + p.dz; b++) out.push(`${a},${b}`);
  return out;
};
const parent = all.map((_, n) => n);
const find = (n) => (parent[n] === n ? n : (parent[n] = find(parent[n])));
const index = new Map(all.map((p, n) => [p, n]));
for (let k = 1; k < courses.length; k++) {
  const below = new Map();
  for (const p of courses[k - 1]) for (const c of cellsOf(p)) below.set(c, p);
  for (const p of courses[k]) {
    const under = new Set(cellsOf(p).map((c) => below.get(c)).filter(Boolean));
    if (!under.size) throw new Error(`hero_mark: ${p.part} in course ${k} stands on nothing`);
    for (const q of under) {
      if (q.kind === "tile") throw new Error(`hero_mark: ${p.part} in course ${k} stands on a tile`);
      parent[find(index.get(p))] = find(index.get(q));
    }
  }
}
const groups = new Set(all.map((_, n) => find(n)));
if (groups.size !== 1) throw new Error(`hero_mark: the mark comes apart in ${groups.size} pieces`);

// LDraw: -y up, and the app's +z is LDraw's -z (api/_parts.js placeOf).
const line = (p) => {
  const x = (p.i + p.dx / 2) * 20 - (N * 20) / 2;
  const z = (p.j + p.dz / 2) * 20 - (N * 20) / 2;
  const top = (p.from + p.tall) * 8;
  const turn = p.turned ? "0 0 1 0 1 0 -1 0 0" : "1 0 0 0 1 0 0 0 1";
  return `1 ${p.colour} ${x} ${-top} ${-z} ${turn} ${p.part}.dat`;
};
// Its steps are its own, a course each (AUTHORED_STEPS: the app keeps them
// rather than working steps out), as the app's other examples' are.
const text = [
  "0 The Brickworks mark",
  "0 Name: brickworks_mark.ldr",
  "0 Author: Brickworks",
  "0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt",
  "0 !BRICKWORKS AUTHORED_STEPS",
  "0 // The Brickworks mark in bricks: a cube with one corner cut away, as a CAD section shows the inside",
  "0 // of a solid. Written by tools/web/hero_mark.mjs; the home page's hero turns it in 3D.",
  "",
  ...courses.flatMap((course, k) => [...course.map(line), ...(k < courses.length - 1 ? ["0 STEP"] : [])]),
  "",
].join("\n");

const scene = sceneOf(text, "https://parts.invalid/", "hero:mark");
if (!scene || scene.count !== all.length) throw new Error(`hero_mark: the scene packs ${scene?.count} of ${all.length}`);
const store = join(ROOT, "assets/generated/parts");
const hashes = [...new Set(scene.meshes.map((m) => m[1]))].sort();
// Each part's shape in the answer itself, its studs apart (web/viewer3d.js
// hero3d reads them there), and the stud itself, a 1 x 1 plate's.
scene.root = "/hero/";
scene.shapes = {};
const bodyOf = new Map();
for (const hash of hashes) {
  const trimmed = outside(readFileSync(join(store, `${hash}.lbm`)), "body");
  scene.shapes[hash] = trimmed.bytes.toString("base64");
  bodyOf.set(hash, trimmed.count);
}
const plate = catalogue.parts.find((p) => p.id === "3024");
const stud = outside(readFileSync(join(store, `${plate.mesh}.lbm`)), "stud");
scene.stud = stud.bytes.toString("base64");
// The course each brick is in (the file's order is the scene's), and each
// stud: the brick it is on, where it is (LDU, the app's axes) and the brick
// over it (-1: none, it shows).
scene.course = courses.flatMap((course, k) => course.map(() => k));
const at = new Map();
all.forEach((p, n) => { for (const c of cellsOf(p)) at.set(`${COURSES.indexOf(COURSES.find(([f, t]) => p.from === f && p.tall === t))}:${c}`, n); });
const studs = [];
all.forEach((p, n) => {
  if (p.kind === "tile") return;
  const k = scene.course[n];
  for (const c of cellsOf(p)) {
    const [i, j] = c.split(",").map(Number);
    const over = k + 1 < COURSES.length ? at.get(`${k + 1}:${c}`) : undefined;
    studs.push(n, (i + 0.5) * 20 - (N * 20) / 2, (p.from + p.tall) * 8, (j + 0.5) * 20 - (N * 20) / 2, over ?? -1);
  }
});
scene.studs = studs;
const studCount = studs.length / 5;
const shownStuds = studs.filter((_, k) => k % 5 === 4).filter((v) => v === -1).length;
scene.triangles = all.reduce((sum, p) => sum + bodyOf.get(scene.meshes.find((m) => m[0] === p.part)[1]), 0)
  + shownStuds * stud.count;
const json = `${JSON.stringify(scene)}\n`;

// The home says how many pieces it is (web/index.html #hero-pieces), and so
// does each language's word for its line (web/_lang/*.json, the English as
// its key and the language's own); the pages in each language are
// tools/site_lang.py's to write from them.
const home = join(ROOT, "web/index.html");
const homeNow = readFileSync(home, "utf8");
const homeMade = homeNow.replace(/(<span id="hero-pieces">)\d+ pieces(<\/span>)/, `$1${all.length} pieces$2`);
if (homeMade === homeNow && !homeNow.includes(`<span id="hero-pieces">${all.length} pieces</span>`)) {
  throw new Error("hero_mark: web/index.html has no #hero-pieces to say the count in");
}
const outputs = [[join(ROOT, "models/brickworks_mark.ldr"), text], [join(ROOT, "web/hero/mark.ldr"), text],
  [join(ROOT, "web/hero/mark.json"), json], [home, homeMade]];
for (const lang of ["de", "fr", "es"]) {
  const file = join(ROOT, `web/_lang/${lang}.json`);
  const now = readFileSync(file, "utf8");
  if (!now.includes('id=\\"hero-pieces\\">')) throw new Error(`hero_mark: ${file} has no #hero-pieces line`);
  outputs.push([file, now.replace(/(id=\\"hero-pieces\\">)\d+/g, `$1${all.length}`)]);
}
const pieces = {};
for (const p of all) pieces[p.kind] = (pieces[p.kind] || 0) + 1;
const said = `${all.length} pieces (${Object.entries(pieces).map(([k, n]) => `${n} ${k}s`).join(", ")}), `
  + `${COURSES.length} steps, ${studCount} studs (${shownStuds} uncovered), ${scene.triangles.toLocaleString("en-US")} `
  + `triangles drawn finished, ${hashes.length} shapes, mark.json ${Math.round(json.length / 1024)} KB`;
if (process.argv.includes("--check")) {
  let stale = 0;
  for (const [file, made] of outputs) {
    if (!existsSync(file) || readFileSync(file, "utf8") !== made) {
      console.error(`hero_mark: ${file} is not what it writes`);
      stale += 1;
    }
  }
  if (stale) process.exit(1);
  console.log(`hero_mark: the mark is what it writes: ${said}`);
} else {
  mkdirSync(join(ROOT, "web/hero"), { recursive: true });
  for (const [file, made] of outputs) writeFileSync(file, made);
  console.log(`hero_mark: wrote the mark: ${said}`);
}

/// A part's .lbm (tools/ldraw/meshfile.py) less what is never seen from
/// outside it, with no joints, boxes or sockets: [which] "body", each
/// triangle whose middle is on its top (y 0) or within EDGE of a side (its
/// walls, a tile's groove); "stud", those over its top (y > 0.5), for a
/// 1 x 1 plate its one stud. {bytes, count}: the file and its triangles.
function outside(file, which) {
  const EDGE = 1.5;
  const v = new DataView(file.buffer, file.byteOffset, file.byteLength);
  const surfaces = v.getUint16(6, true);
  const scale = v.getFloat32(8, true);
  const b = [0, 1, 2, 3, 4, 5].map((k) => v.getFloat32(12 + k * 4, true));
  const header = Buffer.from(file.subarray(0, 44));
  header.writeUInt16LE(0, 36);
  header.writeUInt16LE(0, 38);
  header.writeUInt16LE(0, 40);
  const out = [];
  let at = 44;
  let count = 0;
  for (let s = 0; s < surfaces; s++) {
    const colour = v.getInt16(at, true);
    const flags = v.getUint16(at + 2, true);
    const vertices = v.getUint32(at + 4, true);
    const indices = v.getUint32(at + 8, true);
    const wide = vertices > 0xffff;
    const base = at + 12;
    const ix = base + vertices * 10;
    const pos = (n, k) => v.getInt16(base + n * 10 + k * 2, true) / scale;
    const idx = (i) => (wide ? v.getUint32(ix + i * 4, true) : v.getUint16(ix + i * 2, true));
    const kept = [];
    for (let i = 0; i + 2 < indices; i += 3) {
      const t = [idx(i), idx(i + 1), idx(i + 2)];
      const c = [0, 1, 2].map((k) => (pos(t[0], k) + pos(t[1], k) + pos(t[2], k)) / 3);
      const over = c[1] > 0.5;
      const top = !over && c[1] > -0.5;
      const side = Math.min(Math.abs(c[0] - b[0]), Math.abs(c[0] - b[3]), Math.abs(c[2] - b[2]), Math.abs(c[2] - b[5])) <= EDGE;
      if (which === "stud" ? over : !over && (top || side)) kept.push(t);
    }
    at = ix + indices * (wide ? 4 : 2);
    if (!kept.length) continue;
    const renumber = new Map();
    const order = [];
    for (const t of kept) for (const n of t) if (!renumber.has(n)) { renumber.set(n, order.length); order.push(n); }
    const wideNow = order.length > 0xffff;
    const head = Buffer.alloc(12);
    head.writeInt16LE(colour, 0);
    head.writeUInt16LE(flags, 2);
    head.writeUInt32LE(order.length, 4);
    head.writeUInt32LE(kept.length * 3, 8);
    const verts = Buffer.concat(order.map((n) => Buffer.from(file.subarray(base + n * 10, base + n * 10 + 10))));
    const list = Buffer.alloc(kept.length * 3 * (wideNow ? 4 : 2));
    kept.flat().forEach((n, i) => (wideNow ? list.writeUInt32LE(renumber.get(n), i * 4) : list.writeUInt16LE(renumber.get(n), i * 2)));
    out.push(Buffer.concat([head, verts, list]));
    count += kept.length;
  }
  // The surfaces left: a part may lose one whole (its underside's).
  header.writeUInt16LE(out.length, 6);
  return { bytes: Buffer.concat([header, ...out]), count };
}
