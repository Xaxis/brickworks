// A tab left open across a deploy, in real Chromium.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 --static=build/web &        # a local export
//   node tools/web/reload_flow.mjs --url=http://127.0.0.1:8790/app --out=shots/reload
//   BW_BYPASS=… node tools/web/reload_flow.mjs --url=<a preview>/app --out=…
//   BW_BYPASS=… node tools/web/reload_flow.mjs --url=<an alias>/app --next-deploy
//
// People keep a Brickworks tab open for hours, and after a deploy an open
// tab goes on running the build it loaded. The page asks now and then
// which build is live (/version.json, which deploy.sh writes at the root,
// never cached) and, once it is not this tab's, the app says so above the
// model and offers to reload — and from then on this tab stores nothing
// the others share (src/boot/shell.html).
//
// By default the newer build is simulated: the browser is handed another
// commit for /version.json, the live build's one file, while the page and
// the build stay as they are. With --next-deploy nothing is simulated: the
// flow waits for /version.json at --url to change, which is a second
// deploy put at the same alias (vercel alias set <url> <alias>).
//
//   1. A model is opened, renamed and changed; its autosave reaches this
//      tab's own session in the browser's storage.
//   2. The newer build goes live, the person comes back to the tab
//      (focus), and the banner shows: "Brickworks has been updated", with
//      Reload.
//   3. After that the tab is used as before: Save is pressed and a part is
//      deleted. Its own autosave still reaches the browser's storage, and
//      nothing outside its own session is written, deleted or added — read
//      by another page of the site, which watches the storage throughout.
//   4. Another part is deleted and Reload pressed at once, before the
//      autosave would have written it: the page reloads (asking nothing),
//      in the same session, with the model as it was left, part for part,
//      under its name, and the banner gone.
//
// On a build from before 2026-10-13 the page never asks, so step 2 fails:
// no banner; and step 3 fails too, because Save stores the model in the
// saved models every tab shares.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8790/app");
const out = args.out || "shots/reload";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const nextDeploy = Boolean(args["next-deploy"]);
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
const origin = new URL(url).origin;
const NAME = "Reload Flow House";

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const problems = [];

// The live build's file, as the browser is handed it.
let live = null;
async function realLive() {
  try {
    const answer = await fetch(`${origin}/version.json`, {
      cache: "no-store", headers: bypass ? { "x-vercel-protection-bypass": bypass } : {} });
    if (!answer.ok) return null;
    const body = await answer.json();
    return typeof body.commit === "string" ? body.commit : null;
  } catch {
    return null;
  }
}
const before = (await realLive()) || "flow-before";
if (!nextDeploy) {
  live = before;
  await context.route((at) => at.origin === origin && at.pathname === "/version.json", (route) =>
    route.fulfill({ status: 200, contentType: "application/json",
      headers: { "cache-control": "no-store" },
      body: JSON.stringify({ commit: live, deployed: new Date().toISOString() }) }));
}
console.log(`  (the live build says ${before}${nextDeploy ? "; waiting for the next deploy to change it" : ", simulated"})`);

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
async function titleBecomes(page, wanted, seconds = 60) {
  return until(async () => (await page.title()) === wanted, seconds);
}
async function rename(page, name) {
  const field = await controlAt(page, "model_name");
  await page.mouse.click(field.x, field.y);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(name);
  await page.keyboard.press("Enter");
  await page.waitForTimeout(500);
  await page.keyboard.press("Escape");
  return titleBecomes(page, `${name} — Brickworks`, 20);
}
// Click a part as a person does, and delete it (brickworksLayout.targets
// says where the parts are on the page).
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
      if ((await state(page)).bricks === was - 1) return true;
    }
  }
  return false;
}
// The text of one stored file.
async function storedText(page, key) {
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

// -- 1. a model, changed -------------------------------------------------
const page = await context.newPage();
page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
const dialogs = [];
page.on("dialog", (dialog) => { dialogs.push(dialog.type()); dialog.accept().catch(() => {}); });
if (bypass) {
  await page.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
    { waitUntil: "domcontentloaded", timeout: 180000 });
}
await page.goto(join(url, "model=res://models/house.ldr"), { waitUntil: "domcontentloaded", timeout: 180000 });
if (!(await controlAt(page, "model_name"))) {
  console.log("  FAIL  the app never came up");
  await browser.close();
  process.exit(1);
}
await page.waitForTimeout(8000);
console.log("\na model, changed");
check(`renamed by typing to "${NAME}"`, await rename(page, NAME));
check("a part clicked and deleted", await deleteAPart(page));
const tab = await page.evaluate(() => window.brickworksTab || "");
const own = `${USER}/sessions/${tab}/autosave.ldr`;
check(`its autosave reaches its own session in the browser's storage (tab ${tab || "none"})`,
  await until(async () => (await storedText(page, own)).startsWith(`0 ${NAME}`), 120));
// Whatever the app wrote as it started has landed before the newer build
// goes live: what follows is only what this tab does after.
await until(async () => (await page.evaluate(() => window.brickworksUnstored ? window.brickworksUnstored() : 0)) === 0, 120);
await page.waitForTimeout(5000);

// Another page of the site, watching what is stored outside this tab's
// own session: each key and its time, every half second.
const watcher = await context.newPage();
await watcher.goto(`${origin}/faq.html`, { waitUntil: "domcontentloaded", timeout: 60000 });
await watcher.evaluate(([prefix, mine]) => {
  window.changes = [];
  window.watching = true;
  let last = null;
  function look() {
    if (!window.watching) return;
    const opened = indexedDB.open("/userfs");
    opened.onsuccess = () => {
      const db = opened.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); setTimeout(look, 500); return; }
      const now = new Map();
      const cursor = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").index("timestamp").openKeyCursor();
      cursor.onsuccess = (event) => {
        const c = event.target.result;
        if (c) {
          const key = String(c.primaryKey);
          if (key.startsWith(prefix) && !key.startsWith(mine)) now.set(key, Number(c.key instanceof Date ? c.key.getTime() : c.key));
          c.continue();
          return;
        }
        db.close();
        if (last) {
          for (const [key, at] of now) {
            if (!last.has(key)) window.changes.push({ key, what: "added", at: Date.now() });
            else if (last.get(key) !== at) window.changes.push({ key, what: "changed", at: Date.now() });
          }
          for (const key of last.keys()) if (!now.has(key)) window.changes.push({ key, what: "deleted", at: Date.now() });
        }
        last = now;
        setTimeout(look, 500);
      };
    };
    opened.onerror = () => setTimeout(look, 500);
  }
  look();
}, ["/userfs", `${USER}/sessions/${tab}`]);
await watcher.waitForTimeout(1500);
const unrelated = await watcher.evaluate(() => window.changes.length);
if (unrelated) console.log(`  (${unrelated} changes before the newer build: ${JSON.stringify(await watcher.evaluate(() => window.changes))})`);

// -- 2. the newer build ---------------------------------------------------
console.log("\na newer build goes live");
let after = "";
if (nextDeploy) {
  console.log(`  (deploy the next build to ${origin} now)`);
  const changed = await until(async () => {
    const said = await realLive();
    if (said && said !== before) after = said;
    return Boolean(after);
  }, 40 * 60);
  check(`${origin}/version.json says ${after || before} now`, changed);
} else {
  after = `${before}-next`;
  live = after;
}
await watcher.evaluate(() => { window.changes = []; });
const seenFrom = Date.now();
await page.bringToFront();
// The person coming back to the tab.
await page.evaluate(() => window.dispatchEvent(new Event("focus")));
const reload = await controlAt(page, "update_reload", 90);
await page.screenshot({ path: `${out}/1_banner.png` }).catch(() => {});
check(`the banner shows, with Reload, within ${Math.round((Date.now() - seenFrom) / 1000)} s of the tab being looked at`,
  Boolean(reload));
const said = await page.evaluate(() => window.brickworksNewer ? window.brickworksNewer() : "");
check(`...and the page knows which build is live: ${said || "nothing"}`, said === after);

// -- 3. used as before --------------------------------------------------
console.log("\nthe tab used as before");
const save = await controlAt(page, "save", 30);
if (save) await page.mouse.click(save.x, save.y);
await page.waitForTimeout(1500);
const ownBefore = await storedText(page, own);
check("a part clicked and deleted", await deleteAPart(page));
const bricks = (await state(page)).bricks;
check(`its own autosave still reaches the browser's storage (${bricks} parts)`,
  await until(async () => {
    const text = await storedText(page, own);
    return text.startsWith(`0 ${NAME}`) && text !== ownBefore;
  }, 120));
await page.waitForTimeout(3000);
const wrote = await watcher.evaluate(() => window.changes.slice());
check(`nothing outside its own session was written since it saw the newer build${
  wrote.length ? ": " + wrote.slice(0, 4).map((c) => `${c.what} ${c.key.replace(USER, "user:/")}`).join(", ") : ""}`,
  wrote.length === 0);
const savedKey = `${USER}/models/${NAME}.ldr`;
check(`...Save among it: "${NAME}" is not in the saved models every tab shares`,
  (await storedText(watcher, savedKey)) === "");

// -- 4. reload ------------------------------------------------------------
console.log("\nreload");
check("another part clicked and deleted", await deleteAPart(page));
const left = (await state(page)).bricks;
if (!reload) {
  console.log("  FAIL  no Reload to press");
  failed += 1;
} else {
  if (!nextDeploy) live = before;
  const navigated = page.waitForEvent("framenavigated", { timeout: 120000 }).then(() => Date.now()).catch(() => 0);
  const pressedAt = Date.now();
  const at = await controlAt(page, "update_reload", 10);
  await page.mouse.click(at.x, at.y);
  const went = await navigated;
  check(`Reload reloads the page${went ? ` in ${((went - pressedAt) / 1000).toFixed(1)} s` : ""}, asking nothing${
    dialogs.length ? ` (asked: ${dialogs.join(", ")})` : ""}`, went > 0 && dialogs.length === 0);
  await page.waitForTimeout(1500);
  const last = (await watcher.evaluate(() => window.changes.slice())).filter((c) => !went || c.at <= went + 1500);
  check(`...and up to the reload it wrote nothing outside its own session${
    last.length ? ": " + last.slice(0, 4).map((c) => `${c.what} ${c.key.replace(USER, "user:/")}`).join(", ") : ""}`,
    last.length === 0);
  await watcher.evaluate(() => { window.watching = false; });
  const back = await controlAt(page, "model_name", 400);
  check(`the app comes back${back ? "" : ": never"}`, Boolean(back));
  const named = await titleBecomes(page, `${NAME} — Brickworks`, 120);
  await until(async () => (await state(page)).bricks === left, 60);
  check(`...with the model as it was left: "${await page.title()}", ${(await state(page)).bricks} parts (was ${left})`,
    named && (await state(page)).bricks === left);
  check(`...in the same session: ${await page.evaluate(() => window.brickworksTab || "none")}`,
    (await page.evaluate(() => window.brickworksTab || "")) === tab);
  await page.waitForTimeout(3000);
  await page.evaluate(() => window.dispatchEvent(new Event("focus")));
  await page.waitForTimeout(4000);
  const still = await page.evaluate(() => Boolean((window.brickworksControls || {}).update_reload));
  check(`...and the banner gone, the tab on the live build: ${await page.evaluate(() => window.brickworksNewer ? window.brickworksNewer() || "it is" : "no check")}`,
    !still);
  await page.screenshot({ path: `${out}/2_reloaded.png` }).catch(() => {});
}
check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);
await browser.close();
console.log(failed ? `\n${failed} failed`
  : "\na tab left open across a deploy: told, kept from the shared storage, and reloaded with nothing lost");
process.exit(failed ? 1 : 0);
