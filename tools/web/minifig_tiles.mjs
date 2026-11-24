// The maker's tiles, drawn from the parts themselves (figmaker,
// 2026-11-24; web/minifig-parts.js, web/minifig-maker.js): every choice of
// a group drawn once by three.js, as the layers are (minifig_layers.mjs),
// into one picture a group, a cell a part, in its list's order. Each group
// is two pictures: its parts' own colour (16) drawn white, which the maker
// tints with the colour chosen (multiply, masked by the picture itself), and
// what is printed on them in the print's own colours, laid over it. So a
// tile shows its part in the colour the person chose, a face on their skin,
// and a print keeps its colours, from two files a group and no geometry at
// all. A picture's name holds its list's hash (tilesHash), so a list that
// changed asks for pictures that are not there yet rather than wrong ones.
//
// And web/minifig/figure.json: each part's geometry by its hash (the
// catalogue's), and every LDraw colour, which the live figure
// (tools/viewer/minifig.js) is drawn from.
//
//   node tools/web/minifig_tiles.mjs --deps=DIR [--only=faces,hair] [--out=web/minifig]
//
// DIR holds node_modules with three@0.186.1 (tools/viewer/build.mjs). The
// browser draws in software: run it under ~/.claude/claude-core/bin/heavy.
import { mkdirSync, readFileSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { serveDir, TYPES } from "./static_server.mjs";
import { SOFTWARE } from "./browser.mjs";
import { FACES, HAIR, HELD, LEGS, NECKS, TORSOS, tileGroups, tilesHash, TILE } from "../../web/minifig-parts.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.deps) {
  console.error("minifig_tiles: --deps=DIR, a folder with node_modules/three 0.186.1 (tools/viewer/build.mjs)");
  process.exit(2);
}
const three = join(resolve(String(args.deps)), "node_modules/three");
const out = resolve(String(args.out || join(ROOT, "web/minifig")));
const only = args.only ? new Set(String(args.only).split(",")) : null;

const catalogue = JSON.parse(readFileSync(join(ROOT, "assets/generated/catalogue.json"), "utf8"));
const meshOf = new Map(catalogue.parts.map((p) => [p.id, p.mesh]));
const colourList = JSON.parse(readFileSync(join(ROOT, "assets/generated/colors.json"), "utf8"));
const colours = Object.fromEntries(colourList.map((c) => [c.code, `${c.rgb.map((v) => v.toString(16).padStart(2, "0")).join("")}`
  + (/pearl|metal|chrome/.test(c.finish) ? "m" : c.alpha !== undefined && c.alpha < 255 ? "t" : "")]));

// Where each part of a tile goes (LDraw's twelve numbers): legs as a figure
// wears them, anything else at its own origin.
const I = [1, 0, 0, 0, 1, 0, 0, 0, 1];
const HIPS = [0, 32, 0, ...I];
const LEG = [0, 44, 0, ...I];

const groups = tileGroups();
const jobs = [];
for (const [group, items] of Object.entries(groups)) {
  if (only && !only.has(group)) continue;
  const cells = items.map((item) => {
    if (group === "legs") {
      const [, kind, pieces] = LEGS.find(([one]) => one === item);
      const at = kind === "one" ? [HIPS] : [HIPS, LEG, LEG, HIPS];
      return { name: item, parts: pieces.map((part, k) => [part, at[k]]) };
    }
    return { name: item, parts: [[item, [0, 0, 0, ...I]]] };
  });
  jobs.push({ group, cells, file: `${group}-${tilesHash(items)}` });
}
const meshes = {};
const every = new Set(["3626c", "28621", "3818", "3819", "3820", "973", "3815b", "3816c", "3817c"]);
for (const list of [FACES, HAIR, NECKS, TORSOS, HELD]) for (const [id] of list) every.add(id);
for (const [, , pieces] of LEGS) for (const id of pieces) every.add(id);
for (const id of every) {
  if (!meshOf.get(id)) throw new Error(`minifig_tiles: ${id} has no geometry in the catalogue`);
  meshes[id] = meshOf.get(id);
}

const PAGE = `<!DOCTYPE html><html><head><script type="importmap">{"imports":{"three":"/__mf/three/build/three.module.js"}}</script></head>
<body style="margin:0"><script type="module">
import * as T from "three";
import { RoomEnvironment } from "/__mf/three/examples/jsm/environments/RoomEnvironment.js";
import { parseLbm, INHERIT } from "/lbm.js";
const BIG = 384;
const renderer = new T.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setSize(BIG, BIG);
renderer.outputColorSpace = T.SRGBColorSpace;
renderer.toneMapping = T.NeutralToneMapping;
renderer.setClearColor(0x000000, 0);
const scene = new T.Scene();
const pmrem = new T.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.8;
scene.add(new T.HemisphereLight(0xffffff, 0x8d8a85, 0.7));
const key = new T.DirectionalLight(0xfff6ec, 2.0);
key.position.set(-60, 110, 120);
scene.add(key);
const rim = new T.DirectionalLight(0xffffff, 0.8);
rim.position.set(80, 60, -120);
scene.add(rim);
const camera = new T.PerspectiveCamera(20, 1, 1, 5000);
const geometry = new Map();
async function partOf(hash) {
  if (!geometry.has(hash)) geometry.set(hash, parseLbm(await (await fetch("/__mf/parts/" + hash + ".lbm")).arrayBuffer()));
  return geometry.get(hash);
}
const white = { [T.FrontSide]: new T.MeshPhysicalMaterial({ color: 0xffffff, roughness: 0.3, clearcoat: 0.3 }),
  [T.DoubleSide]: new T.MeshPhysicalMaterial({ color: 0xffffff, roughness: 0.3, clearcoat: 0.3, side: T.DoubleSide }) };
const hidden = { [T.FrontSide]: new T.MeshBasicMaterial({ colorWrite: false }),
  [T.DoubleSide]: new T.MeshBasicMaterial({ colorWrite: false, side: T.DoubleSide }) };
const own = new Map();
function coloured(code, colours, side) {
  const name = code + ":" + side;
  if (!own.has(name)) {
    const said = String(colours[code] || "969696");
    const metal = said.endsWith("m");
    own.set(name, new T.MeshPhysicalMaterial({ side, color: new T.Color("#" + said.slice(0, 6)), roughness: metal ? 0.3 : 0.26,
      metalness: metal ? 0.75 : 0, clearcoat: metal ? 0 : 0.35, transparent: said.endsWith("t"), opacity: said.endsWith("t") ? 0.55 : 1 }));
  }
  return own.get(name);
}
function placed(n) {
  const m = new T.Matrix4().set(n[3], n[4], n[5], n[0], n[6], n[7], n[8], n[1], n[9], n[10], n[11], n[2], 0, 0, 0, 1);
  const flip = new T.Matrix4().makeScale(1, -1, -1);
  return flip.clone().multiply(m).multiply(flip);
}
// One cell: the parts drawn white where they take a colour (layer "b") or
// in their print's colours (layer "p"), the other part of them there in
// depth alone, framed to their sphere from a little left and above.
async function cell(parts, hashes, colours, layer, view) {
  const group = new T.Group();
  for (const [id, at] of parts) {
    const lbm = await partOf(hashes[id]);
    for (const s of lbm.surfaces) {
      const g = new T.BufferGeometry();
      g.setAttribute("position", new T.BufferAttribute(s.position, 3));
      g.setAttribute("normal", new T.BufferAttribute(s.normal, 3));
      g.setIndex(new T.BufferAttribute(s.index, 1));
      const side = s.twoSided ? T.DoubleSide : T.FrontSide;
      const mine = s.colour === INHERIT;
      const mat = layer === "b" ? (mine ? white[side] : hidden[side]) : (mine ? hidden[side] : coloured(s.colour, colours, side));
      const mesh = new T.Mesh(g, mat);
      mesh.applyMatrix4(placed(at));
      mesh.renderOrder = mat === hidden[side] ? 0 : 1;
      group.add(mesh);
    }
  }
  const sphere = new T.Box3().setFromObject(group).getBoundingSphere(new T.Sphere());
  const round = view.round * Math.PI / 180, up = view.up * Math.PI / 180;
  const far = sphere.radius / Math.sin(camera.fov * Math.PI / 360) * (view.near || 1.04);
  camera.position.set(sphere.center.x + far * Math.sin(round) * Math.cos(up), sphere.center.y + far * Math.sin(up),
    sphere.center.z + far * Math.cos(round) * Math.cos(up));
  camera.near = far / 10; camera.far = far * 10;
  camera.lookAt(sphere.center);
  camera.updateProjectionMatrix();
  scene.add(group);
  renderer.render(scene, camera);
  scene.remove(group);
  group.traverse((o) => o.geometry?.dispose());
}
window.drawSheet = async (cells, hashes, colours, size, columns, view) => {
  const rows = Math.ceil(cells.length / columns);
  const made = {};
  for (const layer of ["b", "p"]) {
    const sheet = document.createElement("canvas");
    sheet.width = Math.min(columns, cells.length) * size;
    sheet.height = rows * size;
    const c = sheet.getContext("2d");
    c.imageSmoothingQuality = "high";
    for (const [k, one] of cells.entries()) {
      await cell(one.parts, hashes, colours, layer, view);
      c.drawImage(renderer.domElement, (k % columns) * size, Math.floor(k / columns) * size, size, size);
    }
    made[layer] = sheet.toDataURL("image/webp", 0.86);
  }
  return made;
};
window.ready = true;
</script></body></html>`;

// How each group is seen: a face nearly square on, anything else from the
// layers' corner.
// A head is closer: its face fills the tile, its stud and neck cut off.
const VIEWS = { faces: { round: -14, up: 4, near: 0.74 }, skin: { round: -14, up: 4, near: 0.74 }, torsos: { round: -12, up: 6 } };

const site = await serveDir(join(ROOT, "web"));
const browser = await chromium.launch({ args: SOFTWARE });
let failed = 0;
try {
  const page = await (await browser.newContext({ viewport: { width: 512, height: 512 } })).newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.route(`${site.url}/__mf/**`, async (route) => {
    const path = new URL(route.request().url()).pathname.replace(/^\/__mf\//, "");
    const file = path.startsWith("parts/") ? join(ROOT, "assets/generated", path) : join(three, path.replace(/^three\//, ""));
    try {
      route.fulfill({ body: readFileSync(file), contentType: TYPES[`.${file.split(".").pop()}`] || "application/octet-stream" });
    } catch {
      route.fulfill({ status: 404, body: "" });
    }
  });
  await page.route(`${site.url}/__tiles.html`, (route) => route.fulfill({ contentType: "text/html", body: PAGE }));
  await page.goto(`${site.url}/__tiles.html`);
  await page.waitForFunction(() => window.ready, null, { timeout: 120000 });
  const dir = join(out, "tiles");
  mkdirSync(dir, { recursive: true });
  for (const job of jobs) {
    const made = await page.evaluate(([cells, hashes, cols, size, columns, view]) => window.drawSheet(cells, hashes, cols, size, columns, view),
      [job.cells, meshes, colours, TILE.size, TILE.columns, VIEWS[job.group] || { round: -26, up: 14 }]).catch((e) => ({ error: e.message }));
    if (made.error || !String(made.b || "").startsWith("data:image/webp")) {
      console.error(`minifig_tiles: ${job.group} not drawn (${made.error || errors.join("; ") || "no picture"})`);
      failed += 1;
      continue;
    }
    // The group's pictures before this list are not wanted any more.
    for (const old of readdirSync(dir)) if (old.startsWith(`${job.group}-`) && !old.startsWith(job.file)) unlinkSync(join(dir, old));
    const sizes = [];
    for (const layer of ["b", "p"]) {
      const bytes = Buffer.from(made[layer].split(",")[1], "base64");
      writeFileSync(join(dir, `${job.file}-${layer}.webp`), bytes);
      sizes.push(`${layer} ${(bytes.length / 1024).toFixed(0)} KB`);
    }
    console.log(`minifig_tiles: ${job.group}, ${job.cells.length} tiles (${sizes.join(", ")})`);
  }
} finally {
  await browser.close();
  site.close?.();
}
writeFileSync(join(out, "figure.json"), `${JSON.stringify({ meshes, colours })}\n`);
console.log(`minifig_tiles: ${jobs.length - failed} of ${jobs.length} groups drawn into ${join(out, "tiles")}, and figure.json`);
process.exit(failed ? 1 : 0);
