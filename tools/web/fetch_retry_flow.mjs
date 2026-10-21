// A part whose fetch fails is asked again, in a real browser.
//
//   set -a; . ./.env; set +a
//   node tools/web/fetch_retry_flow.mjs --url=https://<preview>.vercel.app/app --bypass=$VERCEL_BYPASS --out=DIR
//   tools/web/serve.py build/web 9195 --parts assets/generated/parts --delay 0
//   node tools/web/fetch_retry_flow.mjs --url=http://127.0.0.1:9195/ --out=DIR
//
// Until 2026-10-20 a fetch that failed was never asked for again: a model
// opening with that part waited for it for ever, short of it, and nothing said
// so. The release's own browser check opened the grab flow's 29-part crane
// without its 3709b on a loaded box (m115's preview); a phone's connection
// drops the same way. So, once the app is up, every part's geometry asked for
// (a .lbm, wherever the deployment keeps it) fails twice, by Playwright's
// route on the context: the connection cut, then a 503. Then it is let
// through. The crane is opened through Open… > From a file, and must come up
// with all 29 parts, each part fetched asked three times, and the status bar
// never saying a part could not be loaded.
//
// Then a two-part model whose second part no pack carries (--part, 6020) is
// opened with every part's geometry answered 404: asked once, not again, and
// the status bar says once "1 brick — 1 part could not be loaded, and is kept
// in the file". The tab is reloaded once the autosave has had its time, the
// part still answered 404: the same model comes back, the part still awaited
// and said again. Until 2026-10-20 nothing of a model short of a part was
// autosaved, so the reload brought back the crane. Pictures of each in OUT.
import { launch, START_MS } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/fetch_retry_web";
const rare = args.part || "6020";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

// The grab flow's crane (tools/web/grab_flow.mjs), the same 29 parts.
const crane = path.resolve(out, "grab_crane.ldr");
writeFileSync(crane, [
  "0 Grab crane",
  "0 Name: grab_crane.ldr",
  "1 71 0 0 0 1 0 0 0 1 0 0 0 1 3031.dat",
  "1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3680.dat",
  "1 7 0 -8 0 1 0 0 0 1 0 0 0 1 3679.dat",
  "1 15 0 -32 0 1 0 0 0 1 0 0 0 1 3937.dat",
  "1 4 0 -32 0 1 0 0 0 1 0 0 0 1 3938.dat",
  "1 4 0 -40 -50 0 0 1 0 1 0 -1 0 0 3795.dat",
  "1 71 200 0 0 1 0 0 0 1 0 0 0 1 32278.dat",
  "1 14 240 -20 -60 0 0 1 0 1 0 -1 0 0 32316.dat",
  "1 14 240 -20 60 0 0 1 0 1 0 -1 0 0 32316.dat",
  "1 4 280 -40 0 1 0 0 0 1 0 0 0 1 32524.dat",
  "1 0 200 -10 -60 0 -1 0 1 0 0 0 0 1 3673.dat",
  "1 0 200 -10 60 0 -1 0 1 0 0 0 0 1 3673.dat",
  "1 0 280 -30 -60 0 -1 0 1 0 0 0 0 1 3673.dat",
  "1 0 280 -30 60 0 -1 0 1 0 0 0 0 1 3673.dat",
  ...Array.from({ length: 6 }, (_, k) => `1 4 -120 ${-24 * (k + 1)} 10 1 0 0 0 1 0 0 0 1 3001.dat`),
  "1 7 -120 -168 0 1 0 0 0 1 0 0 0 1 3701.dat",
  "1 0 -120 -158 -10 0 0 -1 0 1 0 1 0 0 3673.dat",
  "1 14 -120 -98 -20 -1 0 0 0 0 1 0 1 0 32524.dat",
  ...Array.from({ length: 3 }, (_, k) => `1 4 -300 ${-24 * (k + 1)} 0 1 0 0 0 1 0 0 0 1 3001.dat`),
  "1 7 -300 -80 0 1 0 0 0 1 0 0 0 1 3709b.dat",
  "1 0 -300 -102 0 0 -1 0 1 0 0 0 0 1 4519.dat",
  "1 7 -300 -112 0 1 0 0 0 0 1 0 -1 0 3649.dat",
  "",
].join("\n"));
const PARTS = 29;
const pair = path.resolve(out, "rare_part.ldr");
writeFileSync(pair, ["0 Rare part", "0 Name: rare_part.ldr",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
  `1 15 0 -24 0 1 0 0 0 1 0 0 0 1 ${rare}.dat`, ""].join("\n"));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
const t0 = Date.now();
const secs = () => ((Date.now() - t0) / 1000).toFixed(1);
const heard = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  heard.push(`${secs()} ${m.type()} ${m.text()}`);
  if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
});

// What each part's geometry is answered with: "pass" until the app is up, then
// "flaky" (cut, 503, through) for the crane, then "absent" (404), then "rare"
// (404 for the rare part's alone).
let mode = "pass";
let rareAt = "";
const asks = new Map();      // url -> times asked since failing began
const answered = new Map();  // url -> what each ask was given
// The headers a cross-origin bucket's answer carries, so a 503 or a 404 is
// read as one and not as a request the page's isolation refused. And a type
// and a body, as the bucket's own answers have: Godot's web client takes an
// answer whose headers the page cannot read for no answer at all (code 0),
// and across origins a page reads only a few, Content-Type and Content-Length
// among them. With these two headers alone, every 404 on a deployment was
// asked four times, as a fault that may pass (m125's preview, 2026-10-20).
const open = { "access-control-allow-origin": "*", "cross-origin-resource-policy": "cross-origin",
  "content-type": "application/json" };
// The body the parts bucket gives for an object it has not got. Its status is
// 400; the 404 here is read the same (PartLibrary.may_pass).
const missing = JSON.stringify({ statusCode: "404", error: "not_found", message: "Object not found",
  code: "NoSuchKey" });
await context.route(/\.lbm(\?|$)/, async (route) => {
  const at = route.request().url();
  if (mode === "pass" || mode === "rare" && at !== rareAt) return route.continue();
  const n = (asks.get(at) || 0) + 1;
  asks.set(at, n);
  const given = mode === "absent" || mode === "rare" ? "404"
    : n === 1 ? "cut" : n === 2 ? "503" : "part";
  answered.set(at, [...(answered.get(at) || []), given]);
  heard.push(`${secs()} ask ${path.basename(new URL(at).pathname)} -> ${given}`);
  if (given === "cut") return route.abort("connectionreset");
  if (given === "503") return route.fulfill({ status: 503, headers: open,
    body: JSON.stringify({ message: "Service Unavailable" }) });
  if (given === "404") return route.fulfill({ status: 404, headers: open, body: missing });
  return route.continue();
});

let failed = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};
const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: path.join(out, name), timeout: 180000 });
    console.log(`        picture: ${path.join(out, name)}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function where(name, seconds = 120) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name}.png`);
  throw new Error(`the app never showed "${name}"`);
}
// What the status bar says, read every quarter second while waiting: each
// time it comes to say something new. It clears itself after four seconds.
const said = [];
let last = "";
async function until(test, seconds) {
  for (let n = 0; n < seconds * 4; n++) {
    const now = await state();
    if ((now.said || "") !== last) {
      last = now.said || "";
      if (last) said.push(last);
    }
    if (test(now)) return now;
    await page.waitForTimeout(250);
  }
  return null;
}
// Open… > From a file, as grab_flow does.
async function openFile(file) {
  const at = await where("open", 400);
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
      await page.waitForTimeout(500);
    }
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}
const notLoaded = () => said.filter((line) => /could not be loaded/.test(line));

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: START_MS });
  check(Boolean(await where("open", 400)), "the app came up");
  await page.waitForTimeout(Number(args.load || 15000));

  // The crane, every part fetched failing twice first.
  mode = "flaky";
  said.length = 0;
  const opening = Date.now();
  await openFile(crane);
  // Two waits of 2 and 6 s before the third ask, and SwiftShader's drawing.
  const opened = await until((s) => s.bricks === PARTS && !/arriving|fetching/.test(s.said || ""), 240);
  const took = Math.round((Date.now() - opening) / 1000);
  const fetched = [...answered.entries()];
  const through = fetched.filter(([, given]) => given.join(",") === "cut,503,part");
  console.log(`        ${fetched.length} parts' geometry fetched, answered: `
    + fetched.map(([at, given]) => `${path.basename(new URL(at).pathname)} ${given.join(",")}`).join("; "));
  check(Boolean(opened), `the crane opened whole, every part fetched failing twice first: `
    + `${(await state()).bricks} of ${PARTS} parts in ${took} s`);
  check(fetched.length > 0 && through.length === fetched.length,
    `each part fetched was asked three times, cut, 503, then let through (${through.length} of ${fetched.length})`);
  check(notLoaded().length === 0, `nothing said not loaded (${JSON.stringify(notLoaded())})`);
  await shot("crane.png");

  // A part no pack carries, answered 404.
  mode = "absent";
  asks.clear();
  answered.clear();
  said.length = 0;
  await openFile(pair);
  const told = await until(() => notLoaded().length > 0, 120);
  if (told) await shot("rare_part_said.png");
  // And a while longer, for anything said again.
  await until(() => false, 12);
  const now = await state();
  const absent = [...answered.entries()];
  check(absent.length === 1 && absent[0][1].join(",") === "404",
    `${rare}'s geometry asked once, a 404 not asked again: `
    + absent.map(([at, given]) => `${path.basename(new URL(at).pathname)} ${given.join(",")}`).join("; "));
  check(Boolean(told) && now.bricks === 1 && notLoaded().length === 1
    && notLoaded()[0] === "1 brick — 1 part could not be loaded, and is kept in the file",
    `the bar said it once: ${JSON.stringify(notLoaded())}; ${now.bricks} brick(s) down`);
  await shot("rare_part.png");

  // Reloaded once the autosave has had its time (2.5 s after the change, then
  // stored): the same model, the rare part still awaited, asked again, said.
  mode = "rare";
  rareAt = absent.length > 0 ? absent[0][0] : "";
  await page.waitForTimeout(8000);
  asks.clear();
  answered.clear();
  said.length = 0;
  last = "";
  await page.reload({ waitUntil: "domcontentloaded", timeout: START_MS });
  check(Boolean(await where("open", 400)), "the tab reloaded");
  const again = await until(() => notLoaded().length > 0, 180);
  await until(() => false, 4);
  const back = await state();
  const asked = [...answered.entries()];
  check(Boolean(again) && back.bricks === 1 && back.awaited === 1 && notLoaded().length === 1
    && notLoaded()[0] === "1 brick — 1 part could not be loaded, and is kept in the file",
    `the reload brought back the model short of ${rare}: ${back.bricks} brick(s) down, `
    + `${back.awaited} awaited, the bar said ${JSON.stringify(notLoaded())}`);
  check(asked.length === 1 && asked[0][0] === rareAt && asked[0][1].join(",") === "404",
    `${rare}'s geometry asked again after the reload: `
    + asked.map(([at, given]) => `${path.basename(new URL(at).pathname)} ${given.join(",")}`).join("; "));
  await shot("rare_part_reloaded.png");
} catch (trouble) {
  check(false, `stopped: ${trouble.message}`);
  await shot("stopped.png");
}
check(errors.length === 0, `no script errors (${errors.slice(0, 3).join(" | ")})`);
writeFileSync(path.join(out, "console.txt"), heard.join("\n") + "\n");
console.log(`        the page's console and each ask: ${path.join(out, "console.txt")}`);
await browser.close();
console.log(failed ? `${failed} FAILED` : "a part that fails to fetch is asked again, and one that never comes is said");
process.exit(failed ? 1 : 0);
