// What a real set's file carries, drawn in a browser: LDCad's flexible parts
// (CustomParts.begin_skins) and the parts the file carries
// (CustomParts.take_from), which the web build could build neither of.
//
//   python3 tools/web/serve.py build/web 8871 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/flex_skin_flow.mjs --url=http://127.0.0.1:8871/ --out=DIR MODEL.mpd ...
//
// Each file is handed to Open… > From a file, as a person opens one. Once
// its parts have arrived it must hold a piece of skin for each flexible part
// (window.brickworksState.skins, the pieces on the baseplate), the
// status bar must not name a flexible part among what it could not show, and
// every part the file carries that the page could build is counted (.custom).
// A picture of each, to look at beside the set's own. Fails if a file has no
// skin drawn, or says one is not shown, or a script error reaches the console.
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith("--")).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const models = process.argv.slice(2).filter((a) => !a.startsWith("--")).map((m) => resolve(m));
const url = args.url || "http://127.0.0.1:8871/";
const out = resolve(args.out || "shots/flex_skin_web");
mkdirSync(out, { recursive: true });

const t0 = Date.now();
let failed = 0;
const ok = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failed++;
  return passed;
};

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const choosers = [];
page.on("filechooser", (chooser) => choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error/i.test(m.text())) errors.push(m.text().slice(0, 300));
});
// A protected preview is opened once with its bypass, which sets a cookie
// for the rest (as assembly_flow does); preview_checks passes --bypass.
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });

const state = () => page.evaluate(() => window.brickworksState || {});
const controls = () => page.evaluate(() => window.brickworksControls || {});
async function where(name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function until(test, seconds = 60) {
  let s = await state();
  for (let n = 0; n < seconds * 2 && !test(s); n++) {
    await page.waitForTimeout(500);
    s = await state();
  }
  return s;
}
// The parts count still for [span] ms (--settle, 20 s: on SwiftShader a
// frame can take a second, and parts fetched arrive a few a frame), nothing
// working.
async function settled(span = 6000, longest = 600000) {
  const end = Date.now() + longest;
  let last = -1;
  let since = Date.now();
  while (Date.now() < end) {
    await page.waitForTimeout(1000);
    const s = await state();
    const busy = Object.keys(s.working || {}).length > 0;
    if (s.bricks !== last || busy) {
      last = s.bricks;
      since = Date.now();
    } else if (Date.now() - since >= span) {
      return s;
    }
  }
  return state();
}
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
    console.log(`        picture: ${out}/${name}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}

await where("open");
await page.waitForTimeout(Number(args.load || 15000));
const rows = [];
for (const model of models) {
  console.log(`flexskin web: ${basename(model)}`);
  const at = await where("open");
  let chooser = null;
  for (let n = 0; n < 3 && !chooser; n++) {
    choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(3000 + 3000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && choosers.length === 0; wait++) await page.waitForTimeout(500);
    chooser = choosers.shift() || null;
    if (!chooser) await page.keyboard.press("Escape");
  }
  if (!ok(Boolean(chooser), "Open… > From a file brought the file picker")) continue;
  const began = Date.now();
  await chooser.setFiles(model);
  const opened = await until((s) => /^opened \d+ parts/.test(String(s.said || "")), 600);
  const said = String(opened.said || "");
  const s = await settled(Number(args.settle || 20000));
  const skins = s.skins || [];
  const carried = (s.custom || []).filter((p) => !skins.includes(p));
  const row = { file: basename(model), bricks: s.bricks, skins, carried: carried.length,
    said: said.slice(0, 300), settled_ms: Date.now() - began };
  rows.push(row);
  console.log(`        the status bar: "${said.slice(0, 300)}"`);
  console.log(`        ${s.bricks} parts, ${skins.length} flexible parts drawn (${skins.slice(0, 6).join(", ")}), `
    + `${carried.length} carried parts built, settled in ${Math.round(row.settled_ms / 1000)} s`);
  ok(skins.length > 0, `${basename(model)}: its flexible parts drawn (${skins.length})`);
  ok(!/\(flexible\)/.test(said), `${basename(model)}: no flexible part said not shown`);
  // A build that keeps LDraw's primitives apart fetches them for this
  // (WebPacks, tools/web/pck_split.py): when, and how many.
  const primitives = await page.evaluate(() => (window.brickworksPacks || {}).primitives || null);
  if (primitives) {
    row.primitives = primitives;
    console.log(`        LDraw's primitives fetched for it: asked ${(primitives.asked / 1000).toFixed(1)} s, `
      + `written ${(primitives.written / 1000).toFixed(1)} s, ${primitives.files} files${primitives.failed ? ` (${primitives.failed})` : ""}`);
  }
  await page.keyboard.press("Escape");
  await page.waitForTimeout(4000);
  await shot(`${basename(model, ".mpd")}.png`);
}
ok(errors.length === 0, `no script errors${errors.length ? ": " + errors.slice(0, 3).join(" | ") : ""}`);
writeFileSync(`${out}/flex_skin_web.json`, JSON.stringify({ rows, errors }, null, 1));
console.log(`flexskin web: ${failed === 0 ? "PASS" : "FAIL"} (${failed} failures)`);
await browser.close();
process.exit(failed === 0 ? 0 : 1);
