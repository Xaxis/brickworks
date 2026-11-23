// The minifigure avatars' layers (avatarkit, 2026-11-23; web/card.js MINIFIG):
// each choice a maker offers drawn once from real LDraw parts, by three.js as
// the site's own 3D draws a model (tools/viewer/view.js: the app's .lbm
// geometry, lit by a studio room and a soft key light, its shadows real), into
// web/minifig/<side>/ as WebP with a clear ground, at each of MINIFIG.sizes.
//
//   node tools/web/minifig_layers.mjs --deps=DIR [--only=face-3626cp01,...] [--out=web/minifig]
//
// DIR holds node_modules with three@0.186.1, as tools/viewer/build.mjs's does.
// Every layer is drawn from the one camera (head and shoulders, the figure
// turned a little, through a long lens, as a product photograph is), with the
// whole figure in place: the parts of other layers there in depth alone, so
// what they hide of this layer's is cut away and the layers laid over each
// other in the browser (legs, torso, print, head, hair) are the figure drawn
// whole. The other layers' parts cast their shadows too (the head's on the
// torso), save the hair's, which varies; and each layer is drawn
// at four times its size and halved down, so its edges are smooth.
//
// The browser draws in software (SwiftShader), as every check's does: run it
// under ~/.claude/claude-core/bin/heavy.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { serveDir, TYPES } from "./static_server.mjs";
// Software drawing (SOFTWARE), and browser.mjs brings in storage_mirror.mjs,
// as every script here that starts a browser does. Its launch() is not
// used: that signs pages in, and these are drawn signed out.
import { SOFTWARE } from "./browser.mjs";
import { MINIFIG } from "../../web/card.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.deps) {
  console.error("minifig_layers: --deps=DIR, a folder with node_modules/three 0.186.1 (tools/viewer/build.mjs)");
  process.exit(2);
}
const three = join(resolve(String(args.deps)), "node_modules/three");
const out = resolve(String(args.out || join(ROOT, "web/minifig")));
const only = args.only ? new Set(String(args.only).split(",")) : null;
const QUALITY = 0.9;

const catalogue = JSON.parse(readFileSync(join(ROOT, "assets/generated/catalogue.json"), "utf8"));
const meshOf = new Map(catalogue.parts.map((p) => [p.id, p.mesh]));
const colours = Object.fromEntries(JSON.parse(readFileSync(join(ROOT, "assets/generated/colors.json"), "utf8"))
  .map((c) => [c.code, { rgb: c.rgb, finish: c.finish }]));

// The classic figure's parts, where src/minifig/minifig.gd puts them (each
// twelve numbers as an LDraw type-1 line writes them, relative to the torso).
const I = [1, 0, 0, 0, 1, 0, 0, 0, 1];
const AT = {
  head: [0, -24, 0, ...I], hair: [0, -24, 0, ...I],
  armR: [-15.552, 9, 0, 0.985, -0.17, 0, 0.17, 0.985, 0, 0, 0, 1],
  armL: [15.552, 9, 0, 0.985, 0.17, 0, -0.17, 0.985, 0, 0, 0, 1],
  handR: [-23.69, 26.774, -9.898, 0.985, -0.12, 0.12, 0.17, 0.696, -0.696, 0, 0.707, 0.707],
  handL: [23.69, 26.774, -9.898, 0.985, 0.12, -0.12, -0.17, 0.696, -0.696, 0, 0.707, 0.707],
  torso: [0, 0, 0, ...I], hips: [0, 32, 0, ...I], legR: [0, 44, 0, ...I], legL: [0, 44, 0, ...I],
};
const YELLOW = 14;
// Each fixed part of the figure, as the layer jobs name them.
const legs = (c) => [["3815b", c, AT.hips], ["3816c", c, AT.legR], ["3817c", c, AT.legL]];
const body = (c) => [["973", c, AT.torso], ["3818", c, AT.armR], ["3819", c, AT.armL], ["3820", YELLOW, AT.handR],
  ["3820", YELLOW, AT.handL]];
const head = (id = "3626c") => [[id, YELLOW, AT.head]];

// Each layer: what it draws, and what is there in depth alone. A print draws
// its own colours alone, its torso's colour (16) there in depth.
const jobs = [];
for (const c of MINIFIG.colours) {
  jobs.push({ name: `legs-${c}`, draw: legs(c), hide: [...body(4), ...head()] });
  jobs.push({ name: `torso-${c}`, draw: body(c), hide: [...legs(1), ...head()] });
}
for (const p of MINIFIG.prints.filter(Boolean)) {
  jobs.push({ name: `print-${p}`, draw: [[p, 4, AT.torso]], printOnly: true,
    hide: [...legs(1), ...body(4).slice(1), ...head()] });
}
for (const f of MINIFIG.faces) jobs.push({ name: `face-${f}`, draw: head(f), hide: [...legs(1), ...body(4)] });
for (const h of MINIFIG.hair.filter(Boolean)) {
  const hat = MINIFIG.hats[h];
  for (const c of hat === undefined ? MINIFIG.hairColours : [hat]) {
    jobs.push({ name: `hair-${h}-${c}`, draw: [[h, c, AT.hair]], hide: [...legs(1), ...body(4), ...head()] });
  }
}
const wanted = jobs.filter((j) => !only || only.has(j.name));
const parts = {};
for (const job of wanted) {
  for (const [id] of [...job.draw, ...job.hide]) {
    if (!meshOf.get(id)) throw new Error(`minifig_layers: ${id} has no geometry in the catalogue`);
    parts[id] = meshOf.get(id);
  }
}

// The page that draws them: three.js from DIR, web/lbm.js from the site,
// each part's .lbm from assets/generated/parts.
const PAGE = `<!DOCTYPE html><html><head><script type="importmap">{"imports":{"three":"/__mf/three/build/three.module.js"}}</script></head>
<body style="margin:0"><script type="module">
import * as T from "three";
import { RoomEnvironment } from "/__mf/three/examples/jsm/environments/RoomEnvironment.js";
import { parseLbm, INHERIT } from "/lbm.js";
const BIG = 1024;
const renderer = new T.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setSize(BIG, BIG);
renderer.outputColorSpace = T.SRGBColorSpace;
renderer.toneMapping = T.NeutralToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.setClearColor(0x000000, 0);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = T.PCFSoftShadowMap;
const scene = new T.Scene();
const pmrem = new T.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.75;
scene.add(new T.HemisphereLight(0xffffff, 0x8d8a85, 0.6));
const key = new T.DirectionalLight(0xfff6ec, 2.2);
key.position.set(-60, 110, 120);
key.castShadow = true;
key.shadow.mapSize.set(2048, 2048);
key.shadow.camera.left = -60; key.shadow.camera.right = 60; key.shadow.camera.top = 60; key.shadow.camera.bottom = -60;
key.shadow.camera.near = 10; key.shadow.camera.far = 400;
key.shadow.bias = -0.0004; key.shadow.normalBias = 0.25; key.shadow.radius = 4;
scene.add(key);
const rim = new T.DirectionalLight(0xffffff, 0.8);
rim.position.set(80, 60, -120);
scene.add(rim);
// The camera: head and shoulders, the figure turned a little to its left,
// seen a little from above, through a long lens.
const camera = new T.PerspectiveCamera(11.4, 1, 50, 2000);
const target = new T.Vector3(0, 0, 0);
const round = -22 * Math.PI / 180, up = 9 * Math.PI / 180, far = 380;
camera.position.set(target.x + far * Math.sin(round) * Math.cos(up), target.y + far * Math.sin(up), target.z + far * Math.cos(round) * Math.cos(up));
camera.lookAt(target);
const geometry = new Map();
async function partOf(hash) {
  if (!geometry.has(hash)) geometry.set(hash, parseLbm(await (await fetch("/__mf/parts/" + hash + ".lbm")).arrayBuffer()));
  return geometry.get(hash);
}
const materials = new Map();
function material(code, colours, side) {
  const name = code + ":" + side;
  if (!materials.has(name)) {
    const c = colours[code] || colours[16] || { rgb: [200, 200, 200], finish: "solid" };
    const metal = /pearl|metal|chrome/.test(c.finish);
    materials.set(name, new T.MeshPhysicalMaterial({ side, color: new T.Color().setRGB(c.rgb[0] / 255, c.rgb[1] / 255, c.rgb[2] / 255, T.SRGBColorSpace),
      roughness: metal ? 0.3 : 0.26, metalness: metal ? 0.75 : 0, clearcoat: metal ? 0 : 0.35, clearcoatRoughness: 0.2 }));
  }
  return materials.get(name);
}
const depthOnly = { [T.FrontSide]: new T.MeshBasicMaterial({ colorWrite: false }),
  [T.DoubleSide]: new T.MeshBasicMaterial({ colorWrite: false, side: T.DoubleSide }) };
// LDraw's twelve numbers into the app's axes (+Y up, the figure facing +Z), as the .lbm is drawn in.
function placed(n) {
  const m = new T.Matrix4().set(n[3], n[4], n[5], n[0], n[6], n[7], n[8], n[1], n[9], n[10], n[11], n[2], 0, 0, 0, 1);
  const flip = new T.Matrix4().makeScale(1, -1, -1);
  return flip.clone().multiply(m).multiply(flip);
}
async function add(group, [id, colour, at], hashes, colours, how) {
  const lbm = await partOf(hashes[id]);
  for (const s of lbm.surfaces) {
    const g = new T.BufferGeometry();
    g.setAttribute("position", new T.BufferAttribute(s.position, 3));
    g.setAttribute("normal", new T.BufferAttribute(s.normal, 3));
    g.setIndex(new T.BufferAttribute(s.index, 1));
    const own = s.colour === INHERIT ? colour : s.colour;
    const hidden = how === "hide" || (how === "print" && s.colour === INHERIT);
    const side = s.twoSided ? T.DoubleSide : T.FrontSide;
    const mesh = new T.Mesh(g, hidden ? depthOnly[side] : material(own, colours, side));
    mesh.applyMatrix4(placed(at));
    mesh.castShadow = true;
    mesh.receiveShadow = !hidden;
    // What is there in depth alone is drawn first, so what it hides is never drawn.
    mesh.renderOrder = hidden ? 0 : 1;
    group.add(mesh);
  }
}
function halved(from, side) {
  let canvas = from;
  for (let at = from.width / 2; at >= side; at /= 2) {
    const next = document.createElement("canvas");
    next.width = next.height = Math.max(side, at);
    const c = next.getContext("2d");
    c.imageSmoothingQuality = "high";
    c.drawImage(canvas, 0, 0, next.width, next.height);
    canvas = next;
  }
  if (canvas.width !== side) {
    const next = document.createElement("canvas");
    next.width = next.height = side;
    const c = next.getContext("2d");
    c.imageSmoothingQuality = "high";
    c.drawImage(canvas, 0, 0, side, side);
    canvas = next;
  }
  return canvas;
}
window.drawLayer = async (job, hashes, colours, sides, quality) => {
  const group = new T.Group();
  for (const one of job.hide) await add(group, one, hashes, colours, "hide");
  for (const one of job.draw) await add(group, one, hashes, colours, job.printOnly ? "print" : "draw");
  scene.add(group);
  renderer.render(scene, camera);
  scene.remove(group);
  group.traverse((o) => o.geometry?.dispose());
  const made = {};
  for (const side of sides) made[side] = halved(renderer.domElement, side).toDataURL("image/webp", quality);
  return made;
};
window.ready = true;
</script></body></html>`;

const site = await serveDir(join(ROOT, "web"));
const browser = await chromium.launch({ args: SOFTWARE });
let failed = 0;
try {
  const page = await (await browser.newContext({ viewport: { width: 1024, height: 1024 } })).newPage();
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
  await page.route(`${site.url}/__minifig.html`, (route) => route.fulfill({ contentType: "text/html", body: PAGE }));
  await page.goto(`${site.url}/__minifig.html`);
  await page.waitForFunction(() => window.ready, null, { timeout: 120000 });
  for (const side of MINIFIG.sizes) mkdirSync(join(out, String(side)), { recursive: true });
  for (const job of wanted) {
    const made = await page.evaluate(([j, h, c, s, q]) => window.drawLayer(j, h, c, s, q),
      [job, parts, colours, MINIFIG.sizes, QUALITY]).catch((e) => ({ error: e.message }));
    if (made.error || !MINIFIG.sizes.every((s) => String(made[s] || "").startsWith("data:image/webp"))) {
      console.error(`minifig_layers: ${job.name} not drawn (${made.error || errors.join("; ") || "no picture"})`);
      failed += 1;
      continue;
    }
    const sizes = [];
    for (const side of MINIFIG.sizes) {
      const bytes = Buffer.from(made[side].split(",")[1], "base64");
      writeFileSync(join(out, String(side), `${job.name}.webp`), bytes);
      sizes.push(`${side}: ${(bytes.length / 1024).toFixed(1)} KB`);
    }
    console.log(`minifig_layers: ${job.name} (${sizes.join(", ")})`);
  }
} finally {
  await browser.close();
  site.close?.();
}
console.log(`minifig_layers: ${wanted.length - failed} of ${wanted.length} layers drawn into ${out}`);
process.exit(failed ? 1 : 0);
