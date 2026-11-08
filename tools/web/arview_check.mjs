// A model's room GLB against the app's Export (APP_UX5 #13, arview): for
// each file Export wrote a GLB of (src/dev/arview_probe.gd), the page's GLB
// of the same file (api/_parts.js roomOf, web/glb.js writeGlb, each part's
// geometry from assets/generated/parts read by web/lbm.js as the page reads
// it from the store), read back node by node: every part the same part in
// the same colour, the same place (the basis to 1e-5 of itself, the origin to 2
// micrometres) in the same assemblies, named the same; its mesh the same,
// each primitive's material the same (colour, alpha, metallic, roughness,
// blend, two-sided) and its geometry the same (positions to the bit,
// triangles index for index, normals to 2e-3, which Godot keeps
// octahedral); each shape written once; and the page's under MOST_BYTES,
// its size guessed near enough. A part the file carries as a copy of a
// catalogue part ("8880 - 168315i") the page draws as that part, from the
// store's geometry: the same part, colour and place, its mesh not compared.
// One with no geometry in the store is the page's to leave out, as its 3D
// view does, and what it says it left out must be exactly those.
//
//   node tools/web/arview_check.mjs --app=APP.json
//
// APP.json: {path: {glb, title, parts, left_out, custom: [part ids the file
// carries]}}. Prints a line a model and each difference, and exits 1 when
// any model differs.
import { existsSync, readFileSync } from "node:fs";
import { partsTable, roomOf } from "../../api/_parts.js";
import { parseLbm } from "../../web/lbm.js";
import { MOST_BYTES, glbSize, guessBytes, writeGlb } from "../../web/glb.js";

const appFile = (process.argv.find((a) => a.startsWith("--app=")) || "").slice(6);
if (!appFile) {
  console.error("arview_check: name the app's GLBs, --app=APP.json");
  process.exit(2);
}
if (!partsTable()) {
  console.error("arview_check: no parts table (assets/generated/catalogue.json)");
  process.exit(2);
}
const app = JSON.parse(readFileSync(appFile, "utf8"));

const shapes = new Map();
function shapeOf(hash) {
  if (!shapes.has(hash)) {
    const file = new URL(`../../assets/generated/parts/${hash}.lbm`, import.meta.url);
    let shape = null;
    if (existsSync(file)) {
      const bytes = readFileSync(file);
      shape = parseLbm(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
    }
    shapes.set(hash, shape);
  }
  return shapes.get(hash);
}

/// A GLB's document and its binary chunk.
function readGlb(bytes) {
  const data = Buffer.from(bytes);
  if (data.readUInt32LE(0) !== 0x46546c67 || data.readUInt32LE(4) !== 2 || data.readUInt32LE(8) !== data.length) {
    throw new Error("not a whole GLB 2");
  }
  const jsonLength = data.readUInt32LE(12);
  const doc = JSON.parse(data.subarray(20, 20 + jsonLength).toString("utf8"));
  const binLength = data.readUInt32LE(20 + jsonLength);
  const bin = data.subarray(28 + jsonLength, 28 + jsonLength + binLength);
  if (binLength !== doc.buffers[0].byteLength) throw new Error("its buffer is not the length it says");
  const parent = new Map();
  doc.nodes.forEach((node, at) => (node.children || []).forEach((child) => parent.set(child, at)));
  const pathOf = (at) => {
    const names = [];
    for (let up = parent.get(at); up !== undefined && up !== 0; up = parent.get(up)) names.unshift(doc.nodes[up].name);
    return names.join(" / ");
  };
  const parts = [];
  doc.nodes.forEach((node, at) => { if (node.mesh !== undefined) parts.push({ node, path: pathOf(at) }); });
  return { doc, bin, parts, bytes: data.length };
}

const TYPED = { 5126: Float32Array, 5125: Uint32Array };
function dataOf(glb, index) {
  const accessor = glb.doc.accessors[index];
  const view = glb.doc.bufferViews[accessor.bufferView];
  const width = accessor.type === "VEC3" ? 3 : 1;
  const Type = TYPED[accessor.componentType];
  const copy = glb.bin.subarray(view.byteOffset, view.byteOffset + view.byteLength);
  return { accessor, values: new Type(copy.buffer.slice(copy.byteOffset, copy.byteOffset + accessor.count * width * Type.BYTES_PER_ELEMENT)) };
}
const most = (a, b) => {
  if (a.length !== b.length) return Infinity;
  let worst = 0;
  for (let at = 0; at < a.length; at++) worst = Math.max(worst, Math.abs(a[at] - b[at]));
  return worst;
};
// The app keeps a part's place in single floats: a hose segment stretched
// 276 times along is to 3e-5 there, the same 1e-7 of itself as any turn.
const mostOfItself = (a, b) => {
  if (a.length !== b.length) return Infinity;
  let worst = 0;
  for (let at = 0; at < a.length; at++) worst = Math.max(worst, Math.abs(a[at] - b[at]) / Math.max(1, Math.abs(a[at])));
  return worst;
};
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

let failed = 0;
console.log("model               app parts  page parts  carried  app shapes  page shapes  page GLB    differing");
// carried: parts the file carries that the page leaves out, the store having no geometry for them.
for (const [path, theirs] of Object.entries(app)) {
  const plan = roomOf(readFileSync(path, "utf8"), "local", path);
  const mine = writeGlb(plan, shapeOf, { title: theirs.title });
  const wrong = [];
  const say = (line) => { if (wrong.length < 400) wrong.push(`    ${line}`); };
  let appGlb;
  let pageGlb;
  try {
    appGlb = readGlb(readFileSync(theirs.glb));
    pageGlb = readGlb(mine.glb);
  } catch (trouble) {
    console.log(`${path.split("/").pop()}: ${trouble.message}`);
    failed += 1;
    continue;
  }
  // The parts paired by what they are, their colour and where they stand,
  // in the file's order on both sides; a part the file carries (custom in
  // the app) the page draws from the store's geometry for the same number,
  // or leaves out where the store has none.
  const custom = new Set(theirs.custom || []);
  // A part the file carries as a copy of the catalogue's ("8880 - 168315i")
  // the page names by the catalogue's number it draws.
  const numberOf = (part) => (custom.has(part) && part.includes(" - ") ? part.slice(part.lastIndexOf(" - ") + 3).trim() : part);
  const keyOf = (node) => `${numberOf(node.extras?.ldraw_part)}|${node.extras?.ldraw_colour}|${node.matrix.slice(12, 15).map((v) => Math.round(v * 1e5)).join(",")}`;
  const waiting = new Map();
  pageGlb.parts.forEach((one, at) => {
    const key = keyOf(one.node);
    if (!waiting.has(key)) waiting.set(key, []);
    waiting.get(key).push(at);
  });
  const pairs = [];
  const carriedOnly = {};
  const appOnly = {};
  for (const one of appGlb.parts) {
    const queue = waiting.get(keyOf(one.node));
    if (queue && queue.length) {
      pairs.push([one, pageGlb.parts[queue.shift()], queue]);
      continue;
    }
    const part = one.node.extras?.ldraw_part;
    const into = custom.has(part) ? carriedOnly : appOnly;
    into[part] = (into[part] || 0) + 1;
  }
  const paired = new Set(pairs.map((pair) => pair[1]));
  const pageOnly = {};
  for (const one of pageGlb.parts) {
    if (!paired.has(one)) pageOnly[one.node.extras?.ldraw_part] = (pageOnly[one.node.extras?.ldraw_part] || 0) + 1;
  }
  const carried = Object.values(carriedOnly).reduce((a, b) => a + b, 0);
  // What the page leaves out is what it says it leaves out, part for part.
  if (!same(Object.entries(carriedOnly).sort(), Object.entries(plan.left_out).sort())) {
    say(`the app's own parts the page has not: ${JSON.stringify(carriedOnly)}; the page says it leaves out ${JSON.stringify(plan.left_out)}`);
  }
  if (Object.keys(appOnly).length) say(`in the app's GLB and not the page's: ${JSON.stringify(appOnly)}`);
  if (Object.keys(pageOnly).length) say(`in the page's GLB and not the app's: ${JSON.stringify(pageOnly)}`);
  const order = pairs.map((pair) => pageGlb.parts.indexOf(pair[1]));
  const outOfOrder = order.filter((at, k) => k > 0 && at < order[k - 1]).length;
  if (outOfOrder) say(`${outOfOrder} parts in another order than the app's`);
  if (appGlb.doc.nodes[0].name !== pageGlb.doc.nodes[0].name) say(`the model is "${appGlb.doc.nodes[0].name}" in the app's, "${pageGlb.doc.nodes[0].name}" in the page's`);
  const geometry = new Map();
  const compared = (a, b, kind) => {
    const key = `${a}:${b}`;
    if (geometry.has(key)) return geometry.get(key);
    const x = dataOf(appGlb, a);
    const y = dataOf(pageGlb, b);
    let why = "";
    if (x.accessor.count !== y.accessor.count) why = `${kind} ${x.accessor.count} in the app's, ${y.accessor.count} in the page's`;
    else if (kind === "positions" && (most(x.values, y.values) > 1e-9 || most(x.accessor.min, y.accessor.min) > 1e-9 || most(x.accessor.max, y.accessor.max) > 1e-9)) {
      why = `positions differ by up to ${most(x.values, y.values)} m`;
    } else if (kind === "normals" && most(x.values, y.values) > 2e-3) why = `normals differ by up to ${most(x.values, y.values).toFixed(4)}`;
    else if (kind === "triangles" && most(x.values, y.values) !== 0) why = "the triangles are not the same corners in the same order";
    geometry.set(key, why);
    return why;
  };
  const materialSaid = (m) => [m.name, m.alphaMode || "OPAQUE", Boolean(m.doubleSided)];
  const materialNumbers = (m) => [...m.pbrMetallicRoughness.baseColorFactor, m.pbrMetallicRoughness.metallicFactor, m.pbrMetallicRoughness.roughnessFactor];
  let worstBasis = 0;
  let worstOrigin = 0;
  let fromStore = 0;
  for (const [a, b] of pairs) {
    const label = `${a.node.name}, colour ${a.node.extras?.ldraw_colour}`;
    if (a.node.name !== b.node.name && !custom.has(a.node.extras?.ldraw_part)) say(`${label}: named ${b.node.name} in the page's`);
    if (a.path !== b.path) say(`${label}: in "${a.path}" in the app's, "${b.path}" in the page's`);
    const basis = mostOfItself([0, 1, 2, 4, 5, 6, 8, 9, 10].map((k) => a.node.matrix[k]), [0, 1, 2, 4, 5, 6, 8, 9, 10].map((k) => b.node.matrix[k]));
    const origin = most(a.node.matrix.slice(12, 15), b.node.matrix.slice(12, 15));
    worstBasis = Math.max(worstBasis, basis);
    worstOrigin = Math.max(worstOrigin, origin);
    if (basis > 1e-5 || origin > 2e-6) say(`${label}: placed ${JSON.stringify(a.node.matrix)} in the app's, ${JSON.stringify(b.node.matrix)} in the page's`);
    // The file's own copy of a part, which the app draws, and the store's,
    // which the page does: the same part and place, not the same mesh.
    if (custom.has(a.node.extras?.ldraw_part)) {
      fromStore += 1;
      continue;
    }
    const am = appGlb.doc.meshes[a.node.mesh];
    const bm = pageGlb.doc.meshes[b.node.mesh];
    if (am.name !== bm.name || am.primitives.length !== bm.primitives.length) {
      say(`${label}: its mesh "${am.name}" (${am.primitives.length} surfaces) in the app's, "${bm.name}" (${bm.primitives.length}) in the page's`);
      continue;
    }
    am.primitives.forEach((ap, n) => {
      const bp = bm.primitives[n];
      const ma = appGlb.doc.materials[ap.material];
      const mb = pageGlb.doc.materials[bp.material];
      if (!same(materialSaid(ma), materialSaid(mb)) || most(materialNumbers(ma), materialNumbers(mb)) > 1e-5) {
        say(`${label} surface ${n + 1}: material ${JSON.stringify(ma)} in the app's, ${JSON.stringify(mb)} in the page's`);
      }
      for (const [kind, x, y] of [["positions", ap.attributes.POSITION, bp.attributes.POSITION],
        ["normals", ap.attributes.NORMAL, bp.attributes.NORMAL], ["triangles", ap.indices, bp.indices]]) {
        const why = compared(x, y, kind);
        if (why) say(`${label} surface ${n + 1}: ${why}`);
      }
    });
  }
  // Each shape once: three accessors a shape, none twice.
  const once = pageGlb.doc.accessors.length === mine.shapes * 3;
  if (!once) say(`the page's GLB has ${pageGlb.doc.accessors.length} accessors for ${mine.shapes} shapes`);
  const under = pageGlb.bytes <= MOST_BYTES;
  if (!under) say(`the page's GLB is ${pageGlb.bytes} bytes, over the ${MOST_BYTES} a phone is given`);
  const guessed = glbSize(plan, shapeOf);
  if (Math.abs(guessed - pageGlb.bytes) > 0.1 * pageGlb.bytes) say(`its size was guessed as ${guessed} bytes and is ${pageGlb.bytes}`);
  // And before any shape has come, from the plan alone, as a phone is told
  // no before it fetches them.
  const before = guessBytes(plan);
  if (Math.abs(before - pageGlb.bytes) > 0.15 * pageGlb.bytes) say(`its size was guessed from the plan as ${before} bytes and is ${pageGlb.bytes}`);
  const name = path.split("/").pop();
  console.log(`${name.padEnd(19)} ${String(appGlb.parts.length).padStart(9)} ${String(pageGlb.parts.length).padStart(11)} `
    + `${String(carried).padStart(8)} ${String(appGlb.doc.accessors.length / 3).padStart(11)} ${String(mine.shapes).padStart(12)} `
    + `${(pageGlb.bytes / 1048576).toFixed(2).padStart(7)} MB ${String(wrong.length).padStart(10)}`
    + `   placed to ${worstBasis.toExponential(1)} (basis) and ${(worstOrigin * 1e6).toFixed(2)} µm; ${fromStore} of the file's own parts drawn from the store's geometry; app's GLB ${(appGlb.bytes / 1048576).toFixed(2)} MB`
    + `, the page's guessed at ${(guessed / 1048576).toFixed(2)} MB (${(before / 1048576).toFixed(2)} from the plan)${Object.keys(plan.left_out).length ? `; left out as the 3D view leaves them: ${JSON.stringify(plan.left_out)}` : ""}`);
  for (const line of wrong.slice(0, 10)) console.log(line);
  if (wrong.length) failed += 1;
}
console.log(failed ? `arview_check: ${failed} FAILED` : "arview_check: every model's room GLB is the one Export writes");
process.exit(failed ? 1 : 0);
