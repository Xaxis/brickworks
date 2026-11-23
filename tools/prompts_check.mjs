// The weekly quick build's house models and its stack, made and checked as
// the hourly run makes them (api/_prompts.js), from a checkout: no network.
//
//   node tools/prompts_check.mjs [OUT]
//
// For each of the house's four prompts: its template, and its two entries
// (every part the catalogue knows, none overlapping another, every one on
// the plate or on a part below, within 10 bricks of the plate's top). Then
// the eight entries stacked as one model: every entry its own sub-model,
// the stack's parts the sum of its entries' (counted as a card counts them,
// api/share.js piecesIn), each entry's foot on the studs of the one below.
// With OUT, each entry's picture and the stack's, drawn as the run draws
// them (api/_flatlay.js drawModel), written there as PNGs. Exits 1 on a
// failure, naming it.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { drawModel, pngOf } from "../api/_flatlay.js";
import { parseLbm } from "../api/_lbm.js";
import { inventoryOf, paletteOf, partsTable, placedOf } from "../api/_parts.js";
import { HOUSE, PLATE, heightOf, houseEntry, sectionsOf, stackText, templateText } from "../api/_prompts.js";

const out = process.argv[2] || "";
const parts = new URL("../assets/generated/parts/", import.meta.url);
const table = partsTable();
if (!table) {
  console.error("prompts_check: no catalogue in this checkout (assets/generated)");
  process.exit(2);
}
const palette = paletteOf(table);
let failed = 0;
const fail = (words) => {
  failed += 1;
  console.log(`FAIL ${words}`);
};
const meshes = new Map();
const bytesOf = (mesh) => {
  if (!meshes.has(mesh)) {
    const at = new URL(`${mesh}.lbm`, parts);
    const bytes = existsSync(at) ? readFileSync(at) : null;
    meshes.set(mesh, bytes ? bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length) : null);
  }
  return meshes.get(mesh);
};
const cornersOf = (bytes) => {
  const g = parseLbm(bytes);
  const low = [Infinity, Infinity, Infinity];
  const high = [-Infinity, -Infinity, -Infinity];
  for (const s of g.surfaces) {
    for (let v = 0; v < s.position.length; v += 3) {
      const p = [s.position[v], -s.position[v + 1], -s.position[v + 2]];
      for (let k = 0; k < 3; k += 1) { low[k] = Math.min(low[k], p[k]); high[k] = Math.max(high[k], p[k]); }
    }
  }
  const c = [];
  for (const x of [low[0], high[0]]) for (const y of [low[1], high[1]]) for (const z of [low[2], high[2]]) c.push([x, y, z]);
  return c;
};
const placed = (text) => placedOf(text, table).map((one) => ({ ...one, bytes: bytesOf(one.mesh) }));
const measure = (text) => heightOf(placed(text).map((one) => ({ m: one.m, corners: one.bytes ? cornersOf(one.bytes) : null })));
const pieces = (text) => inventoryOf(text, table).pieces;
const lines = (text) => text.split("\n").filter((line) => line.startsWith("1 "));
const picture = (name, text) => {
  if (!out) return;
  const png = pngOf(drawModel(placed(text), palette));
  writeFileSync(`${out}/${name}.png`, png);
  console.log(`  picture ${out}/${name}.png, ${(png.length / 1024).toFixed(0)} KB`);
  if (png.length > 600 * 1024) fail(`${name}'s picture is over the 600 KB a publish takes`);
};
if (out) mkdirSync(out, { recursive: true });

// Each stud-sized cell a part fills, by plate level, from its own line.
const filled = (line) => {
  const f = line.split(/\s+/);
  const [x, y, z] = [Number(f[2]), Number(f[3]), Number(f[4])];
  const part = f[14].replace(/\.dat$/, "");
  const turned = f[5] === "0";
  const size = { 3001: [4, 2, 3], 3003: [2, 2, 3], 3004: [2, 1, 3], 3005: [1, 1, 3], 3008: [8, 1, 3], 3009: [6, 1, 3],
    3010: [4, 1, 3], 3622: [3, 1, 3], "2453b": [1, 1, 15], "3062b": [1, 1, 3], 3941: [2, 2, 3], 4589: [1, 1, 3],
    3020: [4, 2, 1], 3022: [2, 2, 1], 3023: [2, 1, 1], 3024: [1, 1, 1], 3031: [4, 4, 1], 3034: [8, 2, 1], 3460: [8, 1, 1],
    3666: [6, 1, 1], 3710: [4, 1, 1], 6141: [1, 1, 1], "3068b": [2, 2, 1], "3069b": [2, 1, 1], "3070b": [1, 1, 1],
    98138: [1, 1, 1] }[part];
  if (!size) return null;
  const [w, d] = turned ? [size[1], size[0]] : [size[0], size[1]];
  const foot = Math.round((-y) / 8) - size[2];
  const x0 = Math.round((x + 80) / 20 - w / 2);
  const z0 = Math.round((z + 80) / 20 - d / 2);
  const cells = [];
  for (let level = foot; level < foot + size[2]; level += 1) {
    for (let i = 0; i < w; i += 1) for (let k = 0; k < d; k += 1) cells.push([x0 + i, z0 + k, level]);
  }
  return { part, foot, tall: size[2], cells, x0, z0, w, d };
};

const entries = [];
for (const [seed, house] of Object.entries(HOUSE)) {
  const template = templateText({ seed, title: seed, brief: "A brief." });
  if (lines(template).length !== 1 || !lines(template)[0].endsWith(PLATE)) fail(`${seed}: the template is not one 8x8 plate`);
  for (let k = 0; k < house.entries.length; k += 1) {
    const entry = houseEntry(seed, k);
    const own = lines(entry.text);
    const known = placedOf(entry.text, table).length;
    if (known !== own.length) fail(`${entry.name}: ${own.length - known} of its parts are not in the catalogue`);
    // Nothing in another's place, and nothing in the air.
    const taken = new Set();
    for (const line of own.slice(1)) {
      const one = filled(line);
      if (!one) {
        fail(`${entry.name}: ${line} is not a part the check knows the size of`);
        continue;
      }
      for (const [x, z, level] of one.cells) {
        const key = `${x},${z},${level}`;
        if (x < 0 || x > 7 || z < 0 || z > 7) fail(`${entry.name}: ${one.part} hangs off the plate at ${x},${z}`);
        if (taken.has(key)) fail(`${entry.name}: ${one.part} is where another part is (${key})`);
        taken.add(key);
      }
      if (one.foot + one.tall > 30) fail(`${entry.name}: ${one.part} is more than 10 bricks above the plate`);
    }
    for (const line of own.slice(1)) {
      const one = filled(line);
      if (!one || one.foot === 0) continue;
      const held = one.cells.filter(([, , level]) => level === one.foot)
        .some(([x, z]) => taken.has(`${x},${z},${one.foot - 1}`));
      if (!held) fail(`${entry.name}: ${one.part} at ${one.x0},${one.z0} level ${one.foot} stands on nothing`);
    }
    const { low, high } = measure(entry.text);
    console.log(`${seed}: ${entry.name}, ${pieces(entry.text)} parts, ${high - low} LDU tall`);
    picture(`${seed}-${k + 1}`, entry.text);
    entries.push({ model: `House${seed.replace(/[^a-z]/g, "").slice(0, 4)}${k}`.padEnd(10, "0").slice(0, 10), name: entry.name,
      author: "Brickworks", handle: "brickworks", text: entry.text, low, high });
  }
}

// The stack of all eight: one on the next.
const stack = stackText({ title: "Check", starts_on: "2026-11-23", ends_on: "2026-11-29" }, entries);
const sum = entries.reduce((total, one) => total + pieces(one.text), 0);
const stacked = pieces(stack.text);
console.log(`stack: ${entries.length} entries, ${stacked} parts, their sum ${sum}`);
if (stacked !== sum) fail(`the stack has ${stacked} parts, its entries ${sum}`);
const sections = sectionsOf(stack.text);
if (sections.length !== entries.length + 1) fail(`the stack has ${sections.length} files, not ${entries.length + 1}`);
for (let k = 1; k < stack.placed.length; k += 1) {
  const below = entries[k - 1].low + stack.placed[k - 1].dy;
  const foot = entries[k].high + stack.placed[k].dy;
  if (Math.abs(foot - (below + 4)) > 0.01) fail(`entry ${k + 1}'s foot is at ${foot}, not on the studs below (${below + 4})`);
}
const credited = entries.every((one) => stack.text.includes(`0 Author: Brickworks (@brickworks)`) && stack.text.includes(`/m/${one.model}`));
if (!credited) fail("an entry of the stack is not credited");
const { low, high } = measure(stack.text);
console.log(`stack: ${high - low} LDU tall`);
picture("stack", stack.text);
if (out) writeFileSync(`${out}/stack.mpd`, stack.text);
console.log(failed ? `${failed} FAILED` : "all held");
process.exit(failed ? 1 : 0);
