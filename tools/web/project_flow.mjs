// A model keeps its name across a reload, and New begins another, in a real browser.
//
//   node tools/web/project_flow.mjs --url=https://brickworks.diy/app --out=shots/project
//
// The owner, in the web app: "there literally isnt a way to start a new
// project file. And when the app loads it loads the last project (which is
// fine) but it still says "Untitled" even though the project was saved and
// has a name!" So this names the model on the baseplate by typing, saves it,
// reloads the page, and reads the name back from the tab's title, which the
// app sets from the name field; then presses New and reads it again.
//
// The bar is drawn inside the canvas, so it is driven by position, the way
// assistant_flow.mjs is: the app publishes where its controls are
// (window.brickworksControls).
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
// A preview is behind Vercel's protection: the bypass, and a cookie for
// what the page fetches after.
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/project";
const NAME = "Flow Tower";
mkdirSync(out, { recursive: true });

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
const page = await context.newPage();
const problems = [];
page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}

async function controlAt(name) {
  for (let tries = 0; tries < 600; tries++) {
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` });
  throw new Error(`the app never showed its ${name} control`);
}

// The page's user:// is IndexedDB, written behind the engine's back after
// each change: a reload before that has happened opens what was there
// before the save. Measured at 44 s on a machine at a load of eighty,
// drawing in software, which is why this waits for it rather than for a
// fixed time.
async function storedModels() {
  return page.evaluate(() => new Promise((resolve) => {
    const req = indexedDB.open("/userfs");
    req.onerror = () => resolve([]);
    req.onsuccess = () => {
      const names = [];
      const db = req.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { resolve(names); return; }
      db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").openCursor().onsuccess = (e) => {
        const c = e.target.result;
        if (!c) { resolve(names); return; }
        if (String(c.key).includes("/models/")) names.push(String(c.key));
        c.continue();
      };
    };
  }));
}

// The first line of the autosave as the browser holds it: the title the
// app will reopen under.
async function storedAutosaveTitle() {
  return page.evaluate(() => new Promise((resolve) => {
    const req = indexedDB.open("/userfs");
    req.onerror = () => resolve("");
    req.onsuccess = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { resolve(""); return; }
      db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").openCursor().onsuccess = (e) => {
        const c = e.target.result;
        if (!c) { resolve(""); return; }
        if (String(c.key).endsWith("/autosave.ldr") && c.value && c.value.contents) {
          resolve(new TextDecoder().decode(c.value.contents).split("\n")[0]);
          return;
        }
        c.continue();
      };
    };
  }));
}

async function titleBecomes(wanted, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    if ((await page.title()) === wanted) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
await controlAt("model_name");
// The example on the baseplate is something to save; give the parts a
// moment to arrive so the save is of the whole of it.
await page.waitForTimeout(8000);

// Name it by typing, as a person does.
const field = await controlAt("model_name");
await page.mouse.click(field.x, field.y);
await page.keyboard.press("Control+A");
await page.keyboard.type(NAME);
await page.keyboard.press("Enter");
check(`typing a name puts it in the tab: "${await page.title()}"`,
  await titleBecomes(`${NAME} — Brickworks`, 10));
const save = await controlAt("save");
const savedAt = Date.now();
await page.mouse.click(save.x, save.y);
let kept = -1;
for (let n = 0; n < 240; n++) {
  if ((await storedModels()).some((k) => k.includes(NAME))) { kept = (Date.now() - savedAt) / 1000; break; }
  await page.waitForTimeout(500);
}
check(`the saved model reaches the browser's storage${kept >= 0 ? ` after ${kept.toFixed(1)} s` : " — not within two minutes"}`,
  kept >= 0);
// And the page knew it was on its way, and knows it has landed: the app
// says "saved" by asking it (the shell's brickworksStored).
let settled = false;
for (let n = 0; n < 60 && !settled; n++) {
  settled = (await page.evaluate(() => window.brickworksUnstored ? window.brickworksUnstored() : -1)) === 0;
  if (!settled) await page.waitForTimeout(500);
}
check("...and the page sees it land, with nothing left on its way", settled);
// And the autosave, which is what a reload opens.
let named = false;
for (let n = 0; n < 240 && !named; n++) {
  named = (await storedAutosaveTitle()) === `0 ${NAME}`;
  if (!named) await page.waitForTimeout(500);
}
check("...and so does the autosave, under its name", named);
await page.screenshot({ path: `${out}/1_saved.png` });

await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
await controlAt("model_name");
check(`reloaded, the model is still called ${NAME}: "${await page.title()}"`,
  await titleBecomes(`${NAME} — Brickworks`, 120));
await page.screenshot({ path: `${out}/2_reloaded.png` });

// Saved and unchanged, so New begins at once.
const fresh = await controlAt("new");
await page.mouse.click(fresh.x, fresh.y);
check(`New begins an Untitled model: "${await page.title()}"`,
  await titleBecomes("Untitled — Brickworks", 20));
await page.waitForTimeout(1500);
await page.screenshot({ path: `${out}/3_new.png` });

check(`the page raised no errors${problems.length ? ": " + problems[0] : ""}`,
  problems.length === 0);

// Closing the tab while a save is still on its way asks first.
const field2 = await controlAt("model_name");
await page.mouse.click(field2.x, field2.y);
await page.keyboard.press("Control+A");
await page.keyboard.type("Flow Tower Two");
await page.keyboard.press("Enter");
const again = await controlAt("save");
await page.mouse.click(again.x, again.y);
const pending = await page.evaluate(() => window.brickworksUnstored ? window.brickworksUnstored() : 0);
let asked = "";
page.on("dialog", async (dialog) => { asked = dialog.type(); await dialog.dismiss(); });
if (pending > 0) {
  await page.close({ runBeforeUnload: true });
  await new Promise((resolve) => setTimeout(resolve, 2000));
}
check(`closing the tab with a save on its way asks first (${pending} on its way, asked: ${asked || "no"})`,
  pending > 0 && asked === "beforeunload");
await browser.close();
console.log(failed ? `${failed} failed` : "a model keeps its name across a reload, and New begins another");
process.exit(failed ? 1 : 0);
