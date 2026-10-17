// The parts a real set's file carries, built in a browser from the LDraw text
// the desktop builds them from: the library's own subparts and parts, which no
// build ships, fetched from beside the geometry as the file opens
// (CustomParts.fetch_sources, tools/storage_ldraw.py).
//
//   python3 tools/web/serve.py build/web 8840 --parts-url "$PARTS_URL" &
//   node tools/web/carried_flow.mjs --url=http://127.0.0.1:8840/ --out=DIR MODEL.mpd ...
//
// Each file is handed to Open… > From a file, as a person opens one. Once its
// parts have arrived, none of the parts it carries may be among what the status
// bar says is not shown, each must be on the baseplate, and no script error may
// reach the console. Says how long the open took (the file handed over to
// "opened N parts"), which LDraw files were fetched and how they answered, and
// takes a picture of each. --label names the run in the JSON (before, after).
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).filter((a) => a.startsWith("--")).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const models = process.argv.slice(2).filter((a) => !a.startsWith("--")).map((m) => resolve(m));
const url = args.url || "http://127.0.0.1:8840/";
const out = resolve(args.out || "shots/carried_web");
const label = args.label || "run";
mkdirSync(out, { recursive: true });

const t0 = Date.now();
let failed = 0;
const ok = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failed++;
  return passed;
};

// The parts a file carries: its FILE sections named .dat, by id as the app
// names them (lower case, no folder, no .dat).
function carriedIn(text) {
  const ids = new Set();
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^0\s+FILE\s+(.+?)\s*$/i);
    if (m && /\.dat$/i.test(m[1])) ids.add(m[1].replace(/\\/g, "/").split("/").pop().toLowerCase().replace(/\.dat$/, ""));
  }
  return [...ids];
}

// What the status bar names as not shown: "— 3 not shown, kept in the file
// (13971 ×3, …)" -> {count, ids}.
function notShown(said) {
  const m = said.match(/(\d+) not (?:shown|in the library)[^(]*\(([^)]*)\)/);
  if (!m) return { count: 0, ids: [] };
  return { count: Number(m[1]), ids: m[2].split(", ").map((s) => s.replace(/ ×\d+$/, "").trim()).filter((s) => s && s !== "…") };
}

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const choosers = [];
page.on("filechooser", (chooser) => choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error/i.test(m.text())) errors.push(m.text().slice(0, 300));
});
// Every LDraw file asked for, and how it answered.
const fetched = [];
page.on("requestfinished", async (request) => {
  if (!request.url().includes("/ldraw/parts/")) return;
  const response = await request.response();
  fetched.push({ url: request.url().split("/ldraw/parts/")[1], status: response ? response.status() : 0 });
});
page.on("requestfailed", (request) => {
  if (request.url().includes("/ldraw/parts/")) fetched.push({ url: request.url().split("/ldraw/parts/")[1], status: -1 });
});
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
// Watched closely, so the open is timed to half a second and the status
// bar's Working line is seen while the LDraw files are fetched.
async function until(test, seconds = 60) {
  const words = new Set();
  let s = await state();
  for (let n = 0; n < seconds * 4 && !test(s); n++) {
    if (s.working && s.working.words) words.add(s.working.words);
    await page.waitForTimeout(250);
    s = await state();
  }
  return { s, words: [...words] };
}
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
  const name = basename(model).replace(/\.(mpd|ldr)$/i, "");
  console.log(`carried web (${label}): ${basename(model)}`);
  const carried = carriedIn(readFileSync(model, "utf8"));
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
  fetched.length = 0;
  const began = Date.now();
  await chooser.setFiles(model);
  const { s: opened, words } = await until((s) => /^opened \d+ parts/.test(String(s.said || "")), 600);
  const openMs = Date.now() - began;
  const said = String(opened.said || "");
  const s = await settled(Number(args.settle || 20000));
  const unshown = notShown(said);
  const parts = new Set(s.parts || []);
  const carriedOut = carried.filter((id) => unshown.ids.includes(id));
  const carriedDown = carried.filter((id) => parts.has(id));
  const row = { label, file: basename(model), bricks: s.bricks, said: said.slice(0, 300), open_ms: openMs,
    settled_ms: Date.now() - began, not_shown: unshown.count, not_shown_ids: unshown.ids,
    carried: carried.length, carried_down: carriedDown.length, carried_not_shown: carriedOut,
    custom: (s.custom || []).length, fetched: [...fetched], working: words };
  rows.push(row);
  console.log(`        the status bar: "${said.slice(0, 300)}"`);
  console.log(`        ${s.bricks} parts; opened in ${(openMs / 1000).toFixed(1)} s, settled in ${Math.round(row.settled_ms / 1000)} s; `
    + `${carriedDown.length} of the ${carried.length} parts it carries on the baseplate; ${unshown.count} not shown`);
  console.log(`        LDraw files fetched: ${fetched.length} (${fetched.slice(0, 6).map((f) => `${f.url} ${f.status}`).join(", ")})`);
  if (words.length) console.log(`        working: ${words.join(" | ")}`);
  ok(carriedOut.length === 0, `${basename(model)}: no part it carries said not shown${carriedOut.length ? ": " + carriedOut.join(", ") : ""}`);
  ok(fetched.every((f) => f.status === 200), `${basename(model)}: every LDraw file asked for came (${fetched.length})`);
  await page.keyboard.press("Escape");
  await page.waitForTimeout(4000);
  await shot(`${label}_${name}.png`);
}
ok(errors.length === 0, `no script errors${errors.length ? ": " + errors.slice(0, 3).join(" | ") : ""}`);
writeFileSync(`${out}/carried_web_${label}.json`, JSON.stringify({ rows, errors }, null, 1));
console.log(`carried web (${label}): ${failed === 0 ? "PASS" : "FAIL"} (${failed} failures)`);
await browser.close();
process.exit(failed === 0 ? 0 : 1);
