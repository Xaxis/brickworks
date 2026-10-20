// Every kind of 3D model file Brickify reads, brought in through the page's
// own file chooser in a real browser: PLY as text and binary of both byte
// orders, 3MF, two MagicaVoxel files, FBX, and an OBJ chosen with a picture
// and no .mtl (tests/fixtures/brickify/formats/, MeshFormatSamples).
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/mesh_formats_flow.mjs --url=https://<a preview>/app --out=shots/mesh_formats_web
//   node tools/web/mesh_formats_flow.mjs --url=http://127.0.0.1:9081/index.html --out=…   (a local export)
//
// For each, presses Control+I (a key is a press a browser lets open its file
// chooser), answers the chooser with the file, and waits for the Brickify
// panel to come up holding it (window.brickworksState.brickify_read: its
// name, triangles, whether it has colour, its pictures), as many triangles
// as the desktop reads from it (mesh_formats_probe) and in colour; then
// Cancel. An FBX the browser's build cannot read is said so on the status
// line, which passes only when the page's engine has no FBX reader at all.
// It fails if a chooser never comes, a panel never comes up, a file comes
// in with the wrong triangles or no colour, or a script error reaches the
// console. Nothing is laid: brickify_flow.mjs lays one.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:9081/index.html";
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/mesh_formats_web";
mkdirSync(out, { recursive: true });
const dir = resolve("tests/fixtures/brickify/formats");

// [files chosen together, its name in the panel, triangles, pictures].
const CASES = [
  [["bunny.ply"], "bunny", 1716, 0],
  [["bunny_binary.ply"], "bunny_binary", 1716, 0],
  [["prism.ply"], "prism", 20, 0],
  [["shapes.3mf"], "shapes", 46, 1],
  [["scene.vox"], "scene", 300, 0],
  [["plain.vox"], "plain", 44, 0],
  [["bunny.fbx"], "bunny", 1728, 0],
  [["spotty.obj", "spotty.png"], "spotty", 12, 1],
];

const browser = await launch();
const errors = [];
const said = [];
const t0 = Date.now();
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil/i.test(m.text())) errors.push(m.text().slice(0, 300));
});

const controls = () => page.evaluate(() => window.brickworksControls || {});
const state = () => page.evaluate(() => window.brickworksState || null);
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 120000 });
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
ok(await until(async () => Boolean((await controls()).open), 400), "the app came up");
await page.waitForTimeout(Number(args.load || 15000));
const view = (await controls()).view;

for (const [files, name, triangles, pictures] of CASES) {
  // The chooser, from a key pressed over the model; again if none came,
  // since the app reads a key at its next frame and a software frame can
  // take seconds.
  let chooser = null;
  for (let n = 0; n < 3 && !chooser; n++) {
    page.choosers.length = 0;
    await page.mouse.move(view.x, view.y);
    await page.keyboard.press("Control+i");
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
    chooser = page.choosers.shift() || null;
  }
  if (!ok(Boolean(chooser), `Control+I brings up the page's file chooser for ${files.join(" and ")}`)) continue;
  await chooser.setFiles(files.map((f) => resolve(dir, f)));
  let refused = "";
  const up = await until(async () => {
    if ((await controls()).brickify_go) return true;
    const s = String((await state())?.said || "");
    if (/cannot read|could not read|not a 3D model/.test(s)) refused = s;
    return Boolean(refused);
  }, 180);
  const read = (await state())?.brickify_read || {};
  if (refused) {
    // Only the FBX may be refused, and only by a build with no FBX reader.
    ok(files[0].endsWith(".fbx") && /this build cannot read/.test(refused),
      `${files[0]} refused, as a build without an FBX reader says: "${refused}"`);
    continue;
  }
  ok(up && read.name === name && read.triangles === triangles && read.coloured === true
    && read.textures === pictures,
    `${files.join(" and ")} comes up in the Brickify panel: "${read.name}", ${read.triangles} triangles `
    + `(${triangles} on the desktop), ${read.coloured ? "in colour" : "NO COLOUR"}, ${read.textures} `
    + `picture${read.textures === 1 ? "" : "s"}, ${read.up} up`);
  await shot(`${files[0].replace(/\W+/g, "_")}.png`);
  const cancel = (await controls()).brickify_cancel;
  if (cancel) {
    await page.mouse.click(cancel.x, cancel.y);
    await until(async () => !(await controls()).brickify_go, 60);
  }
}
await browser.close();

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `mesh formats flow: ${failed} problem(s); screenshots in ${out}`
  : `mesh formats flow: every kind of file read in the browser as on the desktop; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
