// Does the card read what the app writes? Its two readers, run in Node on
// the app's own files:
//
//   node tools/viewer/scene_check.mjs [--scene=FILE]
//
// lbm.js, on every part a small model uses, from assets/generated/parts:
// every surface, its triangles as many as the catalogue counts, each turned
// to three.js's winding, every normal a unit. And with --scene (written by
// src/dev/viewer_tools_probe.gd: the scene the tab packed, and the bricks
// it packed from), scene.js unpacks the very bytes the tab sent into those
// bricks: number, part, colour and place.
import { readFileSync } from "node:fs";
import { parseLbm } from "./lbm.js";
import { sceneShape, unpack } from "./scene.js";

const root = new URL("../../", import.meta.url);
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

const catalogue = JSON.parse(readFileSync(new URL("assets/generated/catalogue.json", root), "utf8"));
const parts = new Map(catalogue.parts.map((p) => [p.id, p]));
console.log("lbm.js, on the app's own geometry");
for (const id of ["3001", "3022", "3062b", "3040b", "4070", "3034", "2357", "6141"]) {
  const info = parts.get(id);
  if (!info) { check(false, `${id} is in the catalogue`); continue; }
  const bytes = readFileSync(new URL(`assets/generated/parts/${info.mesh}.lbm`, root));
  const shape = parseLbm(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
  const triangles = shape.surfaces.reduce((n, s) => n + s.index.length / 3, 0);
  let unit = true;
  let inside = true;
  for (const s of shape.surfaces) {
    for (let k = 0; k < s.normal.length; k += 3) unit = unit && Math.abs(Math.hypot(s.normal[k], s.normal[k + 1], s.normal[k + 2]) - 1) < 1e-3;
    for (let k = 0; k < s.position.length; k += 3) {
      for (let a = 0; a < 3; a++) inside = inside && s.position[k + a] >= shape.bounds[a] - 0.05 && s.position[k + a] <= shape.bounds[a + 3] + 0.05;
    }
  }
  // Wound counter-clockwise from outside: a face's normal, by its winding,
  // points the way its vertices' normals do, for most of its faces.
  let agree = 0;
  let faces = 0;
  for (const s of shape.surfaces) {
    for (let i = 0; i < s.index.length; i += 3) {
      const [a, b, c] = [s.index[i], s.index[i + 1], s.index[i + 2]];
      const p = (v) => [s.position[v * 3], s.position[v * 3 + 1], s.position[v * 3 + 2]];
      const [pa, pb, pc] = [p(a), p(b), p(c)];
      const u = [pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2]];
      const v = [pc[0] - pa[0], pc[1] - pa[1], pc[2] - pa[2]];
      const n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
      const m = [0, 1, 2].map((k) => s.normal[a * 3 + k] + s.normal[b * 3 + k] + s.normal[c * 3 + k]);
      if (Math.hypot(...n) < 1e-6) continue;
      faces += 1;
      if (n[0] * m[0] + n[1] * m[1] + n[2] * m[2] > 0) agree += 1;
    }
  }
  check(triangles === info.triangles && unit && inside && agree / faces > 0.9,
    `${id}: ${shape.surfaces.length} surface(s), ${triangles} triangles as the catalogue counts (${info.triangles}), `
    + `normals unit, inside its bounds, ${Math.round((agree / faces) * 100)}% wound to face out`);
}

if (args.scene) {
  console.log("\nscene.js, on the scene the tab packed");
  const given = JSON.parse(readFileSync(String(args.scene), "utf8"));
  const scene = sceneShape(given.scene);
  check(Boolean(scene), "it is a scene the card draws");
  const d = await unpack(scene);
  const want = given.bricks;
  let same = d.n === want.length;
  let worst = 0;
  for (let i = 0; i < Math.min(d.n, want.length); i++) {
    const [id, part, code, x, y, z] = want[i];
    same = same && d.ids[i] === id && d.meshes[d.mesh[i]].part === part && d.colours[d.colour[i]].code === code;
    worst = Math.max(worst, Math.hypot(d.position[i * 3] - x, d.position[i * 3 + 1] - y, d.position[i * 3 + 2] - z));
  }
  check(same, `${d.n} bricks unpacked as the tab packed them: number, part, colour`);
  check(same && worst < 0.2, `...each where it is, to ${worst.toFixed(3)} LDU`);
  check(d.meshes.every((m) => m.hash === "" || parts.get(m.part)?.mesh === m.hash),
    "...each part named by its geometry's hash, the file the app loads");
}
console.log(failures ? `\n${failures} failure(s)` : "\nthe card reads what the app writes");
process.exit(failures ? 1 : 0);
