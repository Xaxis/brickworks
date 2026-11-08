// The GLB the app's Export writes of a model (src/parts/mesh_export.gd,
// MeshExport._gltf), written here, in a visitor's browser, for In your room
// (web/room.js; APP_UX5 #13, arview): the model at real size, in metres with
// +Y up, each shape written once and every part a node pointing at the mesh
// of its shape in its colour, under a node for each assembly it is in; each
// colour a metallic-roughness material with its finish (material_for), as
// Export gives it. From the room's plan of the model (api/_parts.js roomOf,
// /m/<id>/room.json) and each part's geometry, read by web/lbm.js from the
// store the app reads it from. tools/web/arview_check.mjs reads one of these
// against Export's own of the same file, part by part.

import { INHERIT } from "./lbm.js";

/// One LDU in metres (Lbm.LDU_MM / 1000), as Export writes glTF.
export const METRES = 0.4 / 1000;

/// The most a GLB may be for a phone to be given it to place in a room
/// (web/room.js): above it the page says so, before it fetches a shape.
/// 32 MB: two and a half times the biggest set in the LDraw library's
/// (10294, 9,168 parts, 13 MB), and what an iPhone turns into its USDZ
/// (AR Quick Look's, written as text, about twice it) and still holds in
/// a tab with the page.
export const MOST_BYTES = 32 * 1024 * 1024;

/// A colour's finish as the app numbers it (BrickColor.Finish), and the
/// metallic and roughness Export gives each (MeshExport.material_for).
const GLOW = 7;
const FINISHES = { 1: [1.0, 0.08], 2: [0.8, 0.32], 3: [0.35, 0.3], 4: [0.3, 0.3], 5: [0.0, 0.15], 6: [0.0, 0.4],
  7: [0.0, 0.36], 9: [0.0, 0.75], 10: [0.0, 0.95], 11: [0.0, 0.4] };

const f32 = Math.fround;
const linear = (c) => f32(c < 0.04045 ? c * (1 / 12.92) : Math.pow((c + 0.055) * (1 / (1 + 0.055)), 2.4));

/// A colour of the plan ([code, name, "rrggbb", alpha, finish]) as Export's
/// glTF material: its colour turned linear, see-through with its alpha where
/// it is (not glow plastic, which is filed nearly opaque), and its finish.
function materialOf(colour, twoSided) {
  const [, name, hex, alpha, finish] = colour;
  const rgb = [0, 2, 4].map((at) => f32(Number.parseInt(hex.slice(at, at + 2), 16) / 255));
  const seeThrough = alpha < 255 && !(finish === GLOW && alpha >= 240);
  const [metallic, roughness] = FINISHES[finish] || (seeThrough ? [0.0, 0.1] : [0.0, 0.28]);
  const out = { name, pbrMetallicRoughness: {
    baseColorFactor: [...rgb.map(linear), seeThrough ? f32(alpha / 255) : 1],
    metallicFactor: f32(metallic), roughnessFactor: f32(roughness) } };
  if (seeThrough) out.alphaMode = "BLEND";
  if (twoSided) out.doubleSided = true;
  return out;
}

/// How big the GLB of [plan] will be, in bytes, given [shapeOf] (hash ->
/// its geometry from web/lbm.js parseLbm, or null): its buffer, each shape
/// once, and its document, near enough, so a page can say no before it is
/// written.
export function glbSize(plan, shapeOf) {
  let bytes = 2048 + plan.parts.length * 260 + plan.units.length * 60;
  for (const hash of new Set(plan.meshes.map((mesh) => mesh[1]))) {
    for (const surface of drawable(shapeOf(hash))) {
      bytes += surface.position.length * 8 + surface.index.length * 4 + 8 + 3 * 160;
    }
  }
  return bytes;
}

/// How big the GLB of [plan] will be before any shape has come: each
/// shape's triangles (the plan's shape_triangles) at the 37 to 45 bytes a
/// triangle the library's sets write, and each part's node.
export function guessBytes(plan) {
  return 2048 + plan.parts.length * 260 + plan.units.length * 60 + (Number(plan.shape_triangles) || 0) * 40;
}

// The ground the app stands a model on as it opens (ModelStore.lift_for):
// its lowest point, by the catalogue's boxes, the lowest first, and for a
// part turned off the grid by the boxes its geometry fills (Lbm.PartMesh
// lowest_at); a baseplate lying flat by its top, less a stud (FloorLayer);
// then up to the next whole cell (BrickLattice.CELL), or for a file another
// tool wrote, drawn up in the air, down by whole cells.
const CELL = 2;
const STUD_HIGH = 4;
// The lowest y the box [low, high] reaches placed by [b] (its basis by
// columns) at height [y], and the highest (Transform3D * AABB).
const reach = (b, y, low, high, most) => {
  let out = y;
  for (let k = 0; k < 3; k++) {
    const a = b[k * 3 + 1] * low[k];
    const c = b[k * 3 + 1] * high[k];
    out += most ? Math.max(a, c) : Math.min(a, c);
  }
  return out;
};
const unit = (v) => {
  const n = Math.hypot(v[0], v[1], v[2]) || 1;
  return v.map((x) => x / n);
};
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
// Whether [b] turned square (Basis.orthonormalized) is one of the
// lattice's twenty-four turns (BrickLattice.is_square_to_grid, snap_basis).
function squareToGrid(b) {
  const x = unit(b.slice(0, 3));
  const yy = b.slice(3, 6);
  const y = unit(yy.map((v, k) => v - x[k] * dot(x, yy)));
  const zz = b.slice(6, 9);
  const z = unit(zz.map((v, k) => v - x[k] * dot(x, zz) - y[k] * dot(y, zz)));
  const axes = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
  const snapped = [x, y, z].map((column) => axes.reduce((best, axis) => (dot(column, axis) > dot(column, best) ? axis : best), axes[0]));
  const [a, c, d] = snapped;
  const det = a[0] * (c[1] * d[2] - c[2] * d[1]) - c[0] * (a[1] * d[2] - a[2] * d[1]) + d[0] * (a[1] * c[2] - a[2] * c[1]);
  const target = Math.abs(det - 1) > 0.01 ? [[1, 0, 0], [0, 1, 0], [0, 0, 1]] : snapped;
  return [x, y, z].every((column, k) => column.every((v, i) => Math.abs(v - target[k][i]) <= 1e-5 * Math.max(1, Math.abs(v))));
}
// Whether every axis of [b] lies along one of the lattice's (PartMesh._square).
const alongGrid = (b) => [0, 1, 2].every((k) => Math.max(...unit(b.slice(k * 3, k * 3 + 3)).map(Math.abs)) >= 0.9999);

/// How far the app lifts [plan] to stand it on the ground as it opens
/// (ModelStore.lift_for and _lift_from), in LDU, from each part's box in
/// the plan and its geometry [shapeOf].
export function liftOf(plan, shapeOf) {
  const rows = [];
  for (const placed of plan.parts) {
    const mesh = plan.meshes[placed[0]];
    const b = placed.slice(3, 12);
    const y = placed[13];
    const low = mesh.slice(3, 6);
    const high = mesh.slice(6, 9);
    if (mesh[9] && unit(b.slice(3, 6))[1] > 0.999) rows.push([reach(b, y, low, high, true) - STUD_HIGH, null, true]);
    else rows.push([reach(b, y, low, high, false), placed, squareToGrid(b)]);
  }
  rows.sort((a, c) => a[0] - c[0]);
  let lowest = Infinity;
  for (const [by, placed, exact] of rows) {
    if (by >= lowest) break;
    if (exact) {
      lowest = by;
      continue;
    }
    const shape = shapeOf(plan.meshes[placed[0]][1]);
    if (!shape) {
      lowest = by;
      continue;
    }
    const b = placed.slice(3, 12);
    const y = placed[13];
    const byBox = reach(b, y, shape.bounds.slice(0, 3), shape.bounds.slice(3, 6), false);
    if (!shape.boxes.length || alongGrid(b)) {
      lowest = Math.min(lowest, byBox);
      continue;
    }
    const row = [b[1], b[4], b[7]];
    let least = Infinity;
    for (const box of shape.boxes) {
      let at = row[0] * box[0] + row[1] * box[1] + row[2] * box[2];
      for (let k = 0; k < 3; k++) at += Math.min(0, row[k] * box[3 + k]);
      least = Math.min(least, at);
    }
    lowest = Math.min(lowest, Math.max(y + least * shape.cell, byBox));
  }
  if (lowest === Infinity) return 0;
  if (lowest < -0.001) return Math.ceil(-lowest / CELL - 0.001) * CELL;
  if (plan.foreign && lowest >= CELL - 0.001) return -Math.floor((lowest + 0.001) / CELL) * CELL;
  return 0;
}

const drawable = (shape) => (shape ? shape.surfaces.filter((one) => one.index.length >= 3 && one.position.length) : []);

/// The GLB of [plan] (api/_parts.js roomOf), named [title], each part's
/// geometry [shapeOf] its hash: {glb: Uint8Array, parts, shapes, triangles,
/// left_out: {part: count}} where [left_out] counts the parts with no
/// geometry here, as Export's Made does.
export function writeGlb(plan, shapeOf, { title = "", generator = "Brickworks" } = {}) {
  const name = title || "Model";
  const nodes = [{ name, children: [] }];
  const nodeOfUnit = new Map([[0, 0]]);
  const meshes = [];
  const materials = [];
  const accessors = [];
  const views = [];
  const chunks = [];
  let binLength = 0;
  const accessorsOf = new Map();
  const meshOf = new Map();
  const materialOfKey = new Map();
  const leftOut = {};
  let parts = 0;
  let shapes = 0;
  let triangles = 0;
  const lift = liftOf(plan, shapeOf);

  // Into the one buffer, on four bytes as glTF wants (MeshExport._view).
  const view = (array, target) => {
    const pad = (4 - (binLength % 4)) % 4;
    if (pad) chunks.push(new Uint8Array(pad));
    binLength += pad;
    views.push({ buffer: 0, byteOffset: binLength, byteLength: array.byteLength, target });
    chunks.push(new Uint8Array(array.buffer, array.byteOffset, array.byteLength));
    binLength += array.byteLength;
    return views.length - 1;
  };
  // A shape's positions (in metres), normals and triangles, each turned
  // counter-clockwise from outside as Export turns them: its list read
  // backwards (web/lbm.js has each triangle turned already, a, c, b, which
  // is Export's c, b, a begun one corner on).
  const shapeAccessors = (surface) => {
    const count = surface.position.length / 3;
    const positions = new Float32Array(surface.position.length);
    const scale = f32(METRES);
    const low = [Infinity, Infinity, Infinity];
    const high = [-Infinity, -Infinity, -Infinity];
    for (let at = 0; at < positions.length; at++) {
      positions[at] = surface.position[at] * scale;
      const axis = at % 3;
      if (positions[at] < low[axis]) low[axis] = positions[at];
      if (positions[at] > high[axis]) high[axis] = positions[at];
    }
    const turned = surface.index;
    const n = turned.length / 3;
    const indices = new Uint32Array(n * 3);
    for (let k = 0; k < n; k++) {
      const t = (n - 1 - k) * 3;
      indices[k * 3] = turned[t + 1];
      indices[k * 3 + 1] = turned[t + 2];
      indices[k * 3 + 2] = turned[t];
    }
    const trio = [accessors.length, accessors.length + 1, accessors.length + 2];
    accessors.push({ bufferView: view(positions, 34962), componentType: 5126, count, type: "VEC3", min: low, max: high });
    accessors.push({ bufferView: view(new Float32Array(surface.normal), 34962), componentType: 5126, count, type: "VEC3" });
    accessors.push({ bufferView: view(indices, 34963), componentType: 5125, count: indices.length, type: "SCALAR" });
    return trio;
  };
  const colourByCode = new Map(plan.colours.map((colour) => [colour[0], colour]));
  const colourRow = (code) => colourByCode.get(code) || [code, `Unknown ${code}`, "ff00ff", 255, 0];
  // The node an assembly's parts go under, made with those above it
  // (MeshExport._path_node).
  const unitNode = (unit) => {
    if (nodeOfUnit.has(unit)) return nodeOfUnit.get(unit);
    const [label, parent] = plan.units[unit];
    const above = unitNode(parent);
    nodeOfUnit.set(unit, nodes.length);
    nodes[above].children.push(nodes.length);
    nodes.push({ name: label, children: [] });
    return nodeOfUnit.get(unit);
  };

  for (const placed of plan.parts) {
    const [meshAt, colourAt, unit] = placed;
    const [part, hash, partName] = plan.meshes[meshAt];
    const code = plan.colours[colourAt][0];
    const surfaces = drawable(shapeOf(hash));
    if (!surfaces.length) {
      leftOut[part] = (leftOut[part] || 0) + 1;
      continue;
    }
    const meshKey = `${hash}:${code}`;
    if (!meshOf.has(meshKey)) {
      const primitives = surfaces.map((surface, n) => {
        const shapeKey = `${hash}:${n}`;
        if (!accessorsOf.has(shapeKey)) {
          accessorsOf.set(shapeKey, shapeAccessors(surface));
          shapes += 1;
          triangles += surface.index.length / 3;
        }
        const trio = accessorsOf.get(shapeKey);
        const own = surface.colour === INHERIT ? code : surface.colour;
        const materialKey = `${own}:${surface.twoSided}`;
        if (!materialOfKey.has(materialKey)) {
          materialOfKey.set(materialKey, materials.length);
          materials.push(materialOf(colourRow(own), surface.twoSided));
        }
        return { attributes: { POSITION: trio[0], NORMAL: trio[1] }, indices: trio[2], material: materialOfKey.get(materialKey), mode: 4 };
      });
      meshOf.set(meshKey, meshes.length);
      meshes.push({ name: `${partName} ${colourRow(code)[1]}`, primitives });
    }
    const parent = unitNode(unit);
    nodes[parent].children.push(nodes.length);
    const b = placed.slice(3, 12);
    const o = [placed[12], placed[13] + lift, placed[14]].map((v) => v * METRES);
    nodes.push({ name: partName, mesh: meshOf.get(meshKey),
      matrix: [b[0], b[1], b[2], 0, b[3], b[4], b[5], 0, b[6], b[7], b[8], 0, o[0], o[1], o[2], 1],
      extras: { ldraw_part: part, ldraw_colour: code } });
    parts += 1;
  }
  if (!parts) return { glb: null, parts, shapes, triangles, lift, left_out: leftOut };
  for (const node of nodes) if (node.children && !node.children.length) delete node.children;
  const pad = (4 - (binLength % 4)) % 4;
  if (pad) chunks.push(new Uint8Array(pad));
  binLength += pad;
  const doc = { asset: { version: "2.0", generator }, scene: 0, scenes: [{ name, nodes: [0] }], nodes, meshes, materials,
    accessors, bufferViews: views, buffers: [{ byteLength: binLength }] };
  let json = new TextEncoder().encode(JSON.stringify(doc));
  const jsonLength = Math.ceil(json.length / 4) * 4;
  const glb = new Uint8Array(12 + 8 + jsonLength + 8 + binLength);
  const head = new DataView(glb.buffer);
  head.setUint32(0, 0x46546c67, true);
  head.setUint32(4, 2, true);
  head.setUint32(8, glb.length, true);
  head.setUint32(12, jsonLength, true);
  head.setUint32(16, 0x4e4f534a, true);
  glb.set(json, 20);
  glb.fill(0x20, 20 + json.length, 20 + jsonLength);
  json = null;
  let at = 20 + jsonLength;
  head.setUint32(at, binLength, true);
  head.setUint32(at + 4, 0x004e4942, true);
  at += 8;
  for (const chunk of chunks) {
    glb.set(chunk, at);
    at += chunk.length;
  }
  return { glb, parts, shapes, triangles, lift, left_out: leftOut };
}
