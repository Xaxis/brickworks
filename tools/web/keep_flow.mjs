// Models that cannot vanish from a browser, in real Chromium.
//
//   set -a; . ./.env; set +a
//   node tools/web/keep_flow.mjs --url=<a preview>/app --bypass=… --out=shots/keep
//
// On the web a person's models are in the site's storage in the browser and
// nowhere else, and a browser may clear that storage unless the site asks
// to keep it (navigator.storage.persist) and is let; Safari deletes it after
// seven days without a visit. Until 2026-10-14 the app never asked, and a
// save wrote over the last with no copy kept. The browser's answer is
// played here (the page's persist and persisted, stubbed before it loads),
// once refused and once granted; everything else is the real page.
//
//   refused
//     1. A first visit, nothing saved: the browser is not asked.
//     2. Save: it is asked, once, and the answer is kept in localStorage.
//     3. The warning shows above the model: the browser may clear the
//        models, the account keeps no copy, Download my models. That
//        downloads a .zip holding the saved model; Got it puts it away.
//     4. Account says the models may be cleared by the browser.
//     5. Two more saves, a part fewer each: File, Versions… lists three,
//        and Open on the second puts that save on the baseplate.
//     6. Reloaded with a saved model: asked again as the page starts, and
//        the warning, seen once, is not shown again.
//   granted
//     7. Save: asked, and kept; Account says the models are kept on this
//        device, and nothing is warned.
//
// On a build from before 2026-10-14 the browser is never asked, nothing is
// warned, and there is no Versions…: steps 2, 3, 5 and 7 fail.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8790/app");
const out = args.out || "shots/keep";
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const USER = "/userfs/godot/app_userdata/Brickworks";
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;
const problems = [];

// The browser's answer, played: persist() says [granted] and counts its
// asking (window.keepAsked, this page's; sessionStorage keeps every page's),
// and persisted() says whether it has been granted.
function playBrowser(granted) {
  return ([yes]) => {
    window.keepAsked = 0;
    if (!window.StorageManager) return;
    let kept = false;
    StorageManager.prototype.persist = function () {
      window.keepAsked += 1;
      try { sessionStorage.setItem("keepAsked", String(Number(sessionStorage.getItem("keepAsked") || 0) + 1)); } catch {}
      kept = yes;
      return Promise.resolve(yes);
    };
    StorageManager.prototype.persisted = function () { return Promise.resolve(kept); };
  };
}

const browser = await launch();

async function state(page) {
  return page.evaluate(() => window.brickworksState || {});
}
async function controlAt(page, name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate((c) => (window.brickworksControls || {})[c], name).catch(() => null);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` }).catch(() => {});
  return null;
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test().catch(() => false)) return true;
    await wait(500);
  }
  return false;
}
async function press(page, name, seconds = 30) {
  const at = await controlAt(page, name, seconds);
  if (!at) return false;
  await page.mouse.click(at.x, at.y);
  return true;
}
async function rename(page, name) {
  const field = await controlAt(page, "model_name");
  await page.mouse.click(field.x, field.y);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(name);
  await page.keyboard.press("Enter");
  await page.waitForTimeout(500);
  await page.keyboard.press("Escape");
  return until(async () => (await page.title()) === `${name} — Brickworks`, 20);
}
// Click a part as a person does, and delete it (brickworksLayout.targets
// says where the parts are on the page), as reload_flow does.
async function deleteAPart(page) {
  const was = (await state(page)).bricks;
  await page.keyboard.press("KeyF");
  await page.waitForTimeout(1500);
  await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  let layout = null;
  for (let n = 0; n < 60 && !layout; n++) {
    layout = await page.evaluate(() => window.brickworksLayout || null);
    if (!layout) await page.waitForTimeout(250);
  }
  for (const target of (layout && layout.targets) || []) {
    await page.mouse.move(target.x, target.y, { steps: 3 });
    await page.waitForTimeout(300);
    await page.mouse.click(target.x, target.y);
    await page.waitForTimeout(700);
    if (((await state(page)).selected || 0) !== 1) continue;
    await page.keyboard.press("Delete");
    for (let n = 0; n < 20; n++) {
      await page.waitForTimeout(300);
      if ((await state(page)).bricks === was - 1) {
        await page.keyboard.press("Escape");
        return true;
      }
    }
  }
  return false;
}
// The text of one stored file, or "".
async function stored(page, key) {
  return page.evaluate((wanted) => new Promise((resolve) => {
    const opened = indexedDB.open("/userfs");
    opened.onerror = () => resolve("");
    opened.onsuccess = () => {
      const db = opened.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); resolve(""); return; }
      const read = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").get(wanted);
      read.onsuccess = () => {
        db.close();
        const entry = read.result;
        resolve(entry && entry.contents ? new TextDecoder().decode(entry.contents) : "");
      };
      read.onerror = () => { db.close(); resolve(""); };
    };
  }), key);
}
// Save, by the toolbar's button, and wait for the browser to have stored
// the model under [name], other than it was.
async function save(page, name) {
  const key = `${USER}/models/${name}.ldr`;
  const was = await stored(page, key);
  if (!(await press(page, "save"))) return false;
  return until(async () => {
    const text = await stored(page, key);
    return text.startsWith(`0 ${name}`) && text !== was;
  }, 120);
}
async function kept(page) {
  return page.evaluate(() => { try { return JSON.parse(localStorage.getItem("brickworks.storage") || "null"); } catch { return null; } });
}
async function open(context, name) {
  const page = await context.newPage();
  page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  page.on("dialog", (dialog) => dialog.accept().catch(() => {}));
  if (bypass) {
    await page.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
  }
  await page.goto(join(url, "model=res://models/house.ldr"), { waitUntil: "domcontentloaded", timeout: 180000 });
  if (!(await controlAt(page, "model_name"))) {
    console.log(`  FAIL  the app never came up (${name})`);
    await browser.close();
    process.exit(1);
  }
  await page.waitForTimeout(8000);
  return page;
}

// -- refused ---------------------------------------------------------------
console.log("\nthe browser refuses to keep the storage");
const refusing = await browser.newContext({ viewport: { width: 1280, height: 800 }, acceptDownloads: true });
await refusing.addInitScript(playBrowser(false), [false]);
const page = await open(refusing, "refused");
const NAME = "Keep Flow House";

// 1.
check("a first visit with nothing saved: the browser is not asked",
  (await page.evaluate(() => window.keepAsked)) === 0 && !(await state(page)).storage?.state?.asked);

// 2.
check(`renamed by typing to "${NAME}"`, await rename(page, NAME));
const b1 = (await state(page)).bricks;
check(`saved: "${NAME}", ${b1} parts, in the browser's storage`, await save(page, NAME));
check("the first save asks the browser to keep the storage, once",
  await until(async () => (await page.evaluate(() => window.keepAsked)) === 1, 20));
const answer = await kept(page);
check(`...and its answer is kept: ${JSON.stringify(answer)}`, answer && answer.granted === false);

// 3.
const download = await controlAt(page, "storage_download_all", 30);
await page.screenshot({ path: `${out}/1_warning.png` }).catch(() => {});
const warning = (await state(page)).storage?.warning || "";
check(`the warning shows above the model: "${warning}"`, Boolean(download)
  && warning.includes("may clear them") && warning.includes("Your account keeps no copy"));
if (download) {
  const coming = page.waitForEvent("download", { timeout: 60000 }).catch(() => null);
  await page.mouse.click(download.x, download.y);
  const got = await coming;
  let inside = "";
  if (got) {
    const path = `${out}/${got.suggestedFilename()}`;
    await got.saveAs(path).catch(() => {});
    try { inside = readFileSync(path).toString("latin1"); } catch {}
  }
  check(`Download my models downloads a .zip holding "${NAME}.ldr": ${got ? got.suggestedFilename() : "nothing"}`,
    Boolean(got) && /^brickworks_models_.*\.zip$/.test(got.suggestedFilename())
      && inside.startsWith("PK") && inside.includes(`${NAME}.ldr`));
}
check("Got it puts the warning away", await press(page, "storage_got_it", 10)
  && await until(async () => !(await page.evaluate(() => (window.brickworksControls || {}).storage_download_all)), 10));

// 4.
// Read until it says so, not after a fixed wait: the panel follows the
// browser's answer as it comes (AccountPanel._process), and the page hears
// it at the next telling. At load 50 on SwiftShader that took over the 1.5 s
// this once waited, and the check read the panel's first line while the
// screen already showed the right one (2026-10-16).
const clearedSaid = (a) => a.includes("may be cleared by the browser") && a.includes("Your account keeps no copy");
check("Account is open", await press(page, "account", 10));
await until(async () => clearedSaid((await state(page)).storage?.account || ""), 20);
const account = (await state(page)).storage?.account || "";
check(`Account says the models may be cleared by the browser: "${account}"`, clearedSaid(account));
await page.screenshot({ path: `${out}/2_account.png` }).catch(() => {});
await press(page, "account_done", 10);
await page.waitForTimeout(800);

// 5.
check("a part deleted", await deleteAPart(page));
const b2 = (await state(page)).bricks;
check(`saved again, ${b2} parts`, await save(page, NAME));
check("another part deleted", await deleteAPart(page));
const b3 = (await state(page)).bricks;
check(`saved a third time, ${b3} parts`, await save(page, NAME));
const file = await controlAt(page, "menu_file", 10);
let listed = null;
for (let n = 0; n < 3 && !listed; n++) {
  await page.mouse.click(file.x, file.y);
  await page.waitForTimeout(1500 + 1500 * n);
  await page.keyboard.press("V");
  await page.waitForTimeout(600);
  await page.keyboard.press("Enter");
  listed = await controlAt(page, "version_open_2", 10);
}
await page.screenshot({ path: `${out}/3_versions.png` }).catch(() => {});
const rows = (await state(page)).storage?.versions?.rows || [];
check(`File, Versions… lists the three saves, newest first: ${rows.map((r) => r.parts).join(", ")} parts`,
  Boolean(listed) && rows.length === 3 && rows[0].parts === b3 && rows[1].parts === b2 && rows[2].parts === b1);
if (listed) await page.mouse.click(listed.x, listed.y);
check(`Open on the second puts that save on the baseplate: ${b2} parts`,
  await until(async () => (await state(page)).bricks === b2, 60));
check(`...as "${NAME}"`, (await state(page)).storage?.title === NAME);
await page.screenshot({ path: `${out}/4_opened.png` }).catch(() => {});

// 6.
await until(async () => (await page.evaluate(() => window.brickworksUnstored ? window.brickworksUnstored() : 0)) === 0, 60);
await page.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
check("reloaded", Boolean(await controlAt(page, "model_name")));
check("somebody with saved models arriving: the browser is asked as the page starts",
  await until(async () => (await page.evaluate(() => window.keepAsked)) === 1, 60));
await page.waitForTimeout(6000);
check("...and the warning, seen once, is not shown again",
  !(await page.evaluate(() => (window.brickworksControls || {}).storage_download_all)));

// -- granted ---------------------------------------------------------------
console.log("\nthe browser agrees to keep the storage");
const granting = await browser.newContext({ viewport: { width: 1280, height: 800 } });
await granting.addInitScript(playBrowser(true), [true]);
const other = await open(granting, "granted");
const KEPT = "Keep Flow Kept";
check(`renamed to "${KEPT}"`, await rename(other, KEPT));
check("saved", await save(other, KEPT));
check("the save asks the browser, once",
  await until(async () => (await other.evaluate(() => window.keepAsked)) === 1, 20));
const yes = await kept(other);
check(`...and its answer is kept: ${JSON.stringify(yes)}`, yes && yes.granted === true);
check("Account is open", await press(other, "account", 10));
await until(async () => ((await state(other)).storage?.account || "")
  .startsWith("Your models are kept on this device: this browser has agreed"), 20);
const says = (await state(other)).storage?.account || "";
check(`Account says the models are kept on this device: "${says}"`,
  says.startsWith("Your models are kept on this device: this browser has agreed"));
await press(other, "account_done", 10);
await other.waitForTimeout(6000);
check("...and nothing is warned",
  !(await other.evaluate(() => (window.brickworksControls || {}).storage_download_all)));

check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);
await browser.close();
console.log(failed ? `\n${failed} failed`
  : "\nthe browser is asked to keep the models, a refusal is warned of once, and every save is kept to open again");
process.exit(failed ? 1 : 0);
