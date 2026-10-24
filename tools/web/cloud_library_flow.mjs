// A signed-in person's models kept with their account, in real Chromium.
//
//   set -a; . ./.env; set +a
//   node tools/web/cloud_library_flow.mjs --url=<a preview>/app --bypass=… --out=shots/cloud
//
// On the web a saved model was in that browser's storage and nowhere else:
// another device or browser had none of them (walk180's A4, 2026-10-23).
// Now each save of a signed-in person is sent to their account too
// (api/models.js, supabase/account_models.sql, src/account/cloud_models.gd).
// As a throwaway test account of its own (a Resend test address; the
// shared one every other flow uses is kept out by api/models.js), deleted
// at the end the way a person deletes theirs:
//
//   1. Browser A signs in, opens a model, names it and saves it: it is in
//      this browser's storage, and the account lists it with its parts.
//   2. Browser B, a fresh one with nothing stored, signs in: the model is in
//      File › Open, and opens there with the same parts.
//   3. Both change it and save, A first, then B, offline (the account's
//      route unreachable), from the version it had: B's is kept in B's
//      browser, and sent once the account is back. Both are kept: the
//      account has A's under the name and B's beside it as "<name> 2",
//      which B's model is called now; B has A's under the name too, and A,
//      reloaded, has B's.
//   4. Renamed in A (File › Open, Rename or delete saved models…):
//      "<name> 2" is "Cloud Barn" in A, with the account, and in B, which
//      has it open: B's model is called "Cloud Barn" too.
//   5. Deleted in A, asked first, while B takes a part off it unsaved:
//      gone from A, the account and B's storage, B's model still on its
//      baseplate; B saves, and its change is a saved model again, with the
//      account and back in A. Then A deletes "Cloud House" and presses its
//      Undo: back in A and with the account.
//   6. A second throwaway account, near its limit (450 of its 500 models,
//      the fillers written straight to the database and not fetched into
//      the page): a save says plainly the account is nearly full, offering
//      to delete old models, which opens the saved models oldest first; at
//      500, a save of a new model says it is full and kept only in this
//      browser, and is.
//   7. Signed out (a deployment with no accounts, browser C): a save is
//      kept in the browser and nothing is sent. Save on a model nobody has
//      named asks its name, as "Save, then start new" did not.
//   8. The account deleted (Settings' route, api/account.js ?op=delete):
//      its models go with it.
//
// On a build from before 2026-10-23 nothing is sent: 1 fails, and 2 finds
// nothing in Open; 7's Save saves "Untitled" without asking. On one from
// before 2026-10-24 Open has no Rename or delete: 4, 5 and 6 fail.
import { launch } from "./browser.mjs";
import { canSignIn, deleteAccount, mintSession, signInContext } from "./session.mjs";
import { createHash } from "node:crypto";
import { mkdirSync } from "node:fs";
import { gzipSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8790/app");
const out = args.out || "shots/cloud";
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });
const origin = new URL(url).origin;

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const USER = "/userfs/godot/app_userdata/Brickworks";
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;
const NAME = "Cloud House";
const EMAIL = `delivered+cloud-${Date.now().toString(36)}@resend.dev`;
// The account near its limit, of its own.
const FULL_EMAIL = `delivered+cloudfull-${Date.now().toString(36)}@resend.dev`;
const sha = (text) => createHash("sha256").update(Buffer.from(text, "utf8")).digest("hex");

if (!canSignIn()) {
  console.log("  FAIL  no Supabase keys in the environment: `set -a; . ./.env; set +a`");
  process.exit(1);
}

// The account's own view, asked as it from here: the route the app asks,
// with a session minted again each half hour (an access token lasts one).
let viewer = await mintSession(EMAIL);
let mintedAt = Date.now();
const account = viewer.kept.user_id;
async function headers(more = {}) {
  if (Date.now() - mintedAt > 30 * 60 * 1000) {
    viewer = await mintSession(EMAIL);
    mintedAt = Date.now();
  }
  return { authorization: `Bearer ${viewer.access_token}`,
    ...(bypass ? { "x-vercel-protection-bypass": bypass } : {}), ...more };
}
async function listed() {
  const answer = await fetch(`${origin}/api/models`, { headers: await headers() }).catch(() => null);
  if (!answer || !answer.ok) return null;
  const body = await answer.json().catch(() => null);
  return Array.isArray(body?.models) ? body.models : null;
}
const named = (models, name) => (models || []).find((m) => m.name === name) || null;
// The rows, read with the secret key: what the database holds of the account.
async function rows() {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  const answer = await fetch(`${base}/rest/v1/account_models?owner=eq.${account}&select=name,version,parts`,
    { headers: { apikey: key, authorization: `Bearer ${key}` } });
  return answer.ok ? answer.json() : null;
}
// Models of [owner]'s written straight to the database with the secret key,
// as many saves before would have: "Filler <first>" to "Filler <last>", one
// part each, the oldest first.
async function fillers(owner, first, last) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  const made = [];
  for (let n = first; n <= last; n++) {
    const name = `Filler ${String(n).padStart(3, "0")}`;
    const text = `0 ${name}\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n`;
    made.push({ owner, name, version: 1, model: gzipSync(Buffer.from(text)).toString("base64"),
      raw_bytes: Buffer.byteLength(text), parts: 1, sum: sha(text),
      saved_at: new Date(Date.UTC(2026, 0, 1) + n * 60000).toISOString() });
  }
  const answer = await fetch(`${base}/rest/v1/account_models`, { method: "POST",
    headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json", prefer: "return=minimal" },
    body: JSON.stringify(made) });
  return answer.ok;
}

const browser = await launch({ signedOut: true });
const problems = [];

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
async function titleBecomes(page, wanted, seconds = 60) {
  return until(async () => (await page.title()) === wanted, seconds);
}
async function rename(page, name) {
  const field = await controlAt(page, "model_name");
  await page.mouse.click(field.x, field.y);
  await page.keyboard.press("Control+A");
  if (name) await page.keyboard.type(name);
  else await page.keyboard.press("Backspace");
  await page.keyboard.press("Enter");
  await page.waitForTimeout(500);
  await page.keyboard.press("Escape");
  return titleBecomes(page, `${name || "Untitled"} — Brickworks`, 20);
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
// The text of one stored file in this browser's storage.
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
const savedKey = (name) => `${USER}/models/${name}.ldr`;
async function cloud(page) {
  return (await state(page)).cloud || {};
}
async function opened(context, address) {
  const page = await context.newPage();
  page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  page.on("dialog", (dialog) => dialog.accept().catch(() => {}));
  if (bypass) {
    await page.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
  }
  await page.goto(address, { waitUntil: "domcontentloaded", timeout: 180000 });
  return page;
}
async function signedInContext(email = EMAIL) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  await signInContext(context, email);
  return context;
}
// The person coming back to the window, which looks at the account again
// (CloudModels): the page put in front, and its canvas given the focus it
// had lost.
async function comeBack(page) {
  await page.bringToFront();
  await page.evaluate(() => {
    const canvas = document.querySelector("canvas");
    if (canvas) { canvas.blur(); canvas.focus(); }
    window.dispatchEvent(new Event("focus"));
  });
}
// File › Open, Rename or delete saved models…, picked as a person picks it:
// its first word typed, Enter. Then the saved models dialog is open.
async function openSavedModels(page) {
  if (!(await openFromMenu(page, "Rename"))) return false;
  return until(async () => (await state(page)).saved_models?.open === true, 20);
}
// The dialog's row of [name], numbered from 1 as listed, or 0.
async function rowOf(page, name) {
  return ((await state(page)).saved_models?.rows || []).indexOf(name) + 1;
}
// Type into a field the page names, as a person does: click, select all, type.
async function typeInto(page, control, words) {
  const field = await controlAt(page, control, 20);
  if (!field) return false;
  await page.mouse.click(field.x, field.y);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(words);
  await page.keyboard.press("Enter");
  return true;
}
// File › Open, as a person picks a model from it: the toolbar's Open, the
// first word of its name typed (a menu jumps to what is typed), Enter.
async function openFromMenu(page, word) {
  if (!(await press(page, "open"))) return false;
  await page.waitForTimeout(1500);
  await page.keyboard.type(word, { delay: 120 });
  await page.waitForTimeout(600);
  await page.keyboard.press("Enter");
  return true;
}

let parts = 0;
try {
  // -- 1. saved in browser A -----------------------------------------------
  console.log(`\nbrowser A, signed in as a throwaway account (${EMAIL})`);
  const contextA = await signedInContext();
  const a = await opened(contextA, join(url, "model=res://models/house.ldr"));
  if (!(await controlAt(a, "model_name"))) throw new Error("the app never came up in browser A");
  await until(async () => (await state(a)).bricks > 0 && (await state(a)).awaited === 0, 120);
  await a.waitForTimeout(4000);
  check(`renamed by typing to "${NAME}"`, await rename(a, NAME));
  parts = (await state(a)).bricks;
  check(`Save, by the toolbar's button (${parts} parts)`, await press(a, "save"));
  check("...kept in this browser's storage",
    await until(async () => (await storedText(a, savedKey(NAME))).startsWith(`0 ${NAME}`), 120));
  const sent = await until(async () => named(await listed(), NAME)?.parts === parts, 120);
  const first = named(await listed(), NAME);
  check(`...and with the account: it lists "${NAME}", ${first?.parts ?? "no"} parts, version ${first?.version ?? "none"}`,
    sent && first?.version === 1);
  const told = await until(async () => ((await cloud(a)).last?.names || []).includes(NAME) && (await cloud(a)).state === "kept", 60);
  check(`...and the app says the account has it: ${JSON.stringify((await cloud(a)).last || {})}`, told);
  const words = (await state(a)).storage?.words || "";
  check(`...and Account says the account keeps the models: "${words.slice(0, 90)}…"`,
    /kept with your account/.test(words));
  await a.screenshot({ path: `${out}/1_saved_in_a.png` }).catch(() => {});

  // -- 2. a fresh browser ------------------------------------------------------
  console.log("\nbrowser B, nothing stored, signed in as the same account");
  const contextB = await signedInContext();
  const b = await opened(contextB, url);
  if (!(await controlAt(b, "model_name"))) throw new Error("the app never came up in browser B");
  const arrived = await until(async () => (await storedText(b, savedKey(NAME))).startsWith(`0 ${NAME}`), 180);
  check(`"${NAME}" comes to this browser from the account`, arrived);
  await b.waitForTimeout(3000);
  check(`...and opens from File › Open`, await openFromMenu(b, "Cloud"));
  const openedB = await titleBecomes(b, `${NAME} — Brickworks`, 180)
    && await until(async () => (await state(b)).bricks === parts && (await state(b)).awaited === 0, 180);
  check(`...with the same parts: "${await b.title()}", ${(await state(b)).bricks} parts (saved with ${parts})`, openedB);
  await b.screenshot({ path: `${out}/2_opened_in_b.png` }).catch(() => {});

  // -- 3. two saves of one version ---------------------------------------
  // B out of reach of the account while A saves, as a browser offline is:
  // its own save is kept in it, and sent once it is back, made from the
  // version it had. (Held so, B cannot fetch A's save first, which its
  // next look might: then B is asked which to keep, ReloadOffer.)
  console.log("\ntwo browsers, each changing the version it has; B offline");
  await b.route("**/api/models**", (route) => route.abort("internetdisconnected"));
  check("in A, a part deleted", await deleteAPart(a));
  const partsA = (await state(a)).bricks;
  await press(a, "save");
  check(`...and saved: the account has A's, ${partsA} parts, version 2`,
    await until(async () => { const m = named(await listed(), NAME); return m?.version === 2 && m?.parts === partsA; }, 120));
  check("in B, two parts deleted", (await deleteAPart(b)) && (await deleteAPart(b)));
  const partsB = (await state(b)).bricks;
  const beforeB = await storedText(b, savedKey(NAME));
  await press(b, "save");
  check(`...and saved, offline: kept in B's browser all the same (${partsB} parts)`, await until(async () => {
    const text = await storedText(b, savedKey(NAME));
    return text.startsWith(`0 ${NAME}`) && text !== beforeB;
  }, 120));
  const away = await until(async () => (await cloud(b)).state === "away", 60);
  check(`...the app knowing the account has not got it: ${(await cloud(b)).state}`, away);
  check("...nor has it", named(await listed(), NAME)?.parts === partsA && !named(await listed(), `${NAME} 2`));
  await b.unroute("**/api/models**");
  await press(b, "save");
  const besideName = `${NAME} 2`;
  const both = await until(async () => {
    const models = await listed();
    return named(models, NAME)?.parts === partsA && named(models, besideName)?.parts === partsB;
  }, 180);
  const models = await listed();
  check(`back online, B's save is sent, and both are kept: "${NAME}" with A's ${named(models, NAME)?.parts ?? "?"} parts`
    + ` and "${besideName}" with B's ${named(models, besideName)?.parts ?? "?"} (A ${partsA}, B ${partsB})`, both);
  const retitled = await titleBecomes(b, `${besideName} — Brickworks`, 60);
  check(`...B's model is called "${besideName}" now: "${await b.title()}"`, retitled);
  check(`...B has A's under "${NAME}", whole`, await until(async () =>
    sha(await storedText(b, savedKey(NAME))) === named(await listed(), NAME)?.sum, 120));
  check(`...and its own under "${besideName}"`, await until(async () =>
    sha(await storedText(b, savedKey(besideName))) === named(await listed(), besideName)?.sum, 60));
  await b.screenshot({ path: `${out}/3_both_kept_b.png` }).catch(() => {});
  await a.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await controlAt(a, "model_name");
  check(`A, reloaded, has B's "${besideName}" too`, await until(async () =>
    sha(await storedText(a, savedKey(besideName))) === named(await listed(), besideName)?.sum, 180));

  // -- 4. renamed in A -----------------------------------------------------------
  const BARN = "Cloud Barn";
  console.log(`\nrenamed in browser A: "${besideName}" is "${BARN}" everywhere`);
  check("A: File › Open, Rename or delete saved models…", await openSavedModels(a));
  const renaming = await rowOf(a, besideName);
  check(`...lists "${besideName}" (row ${renaming}), with Rename and Delete`,
    renaming > 0 && Boolean(await controlAt(a, `saved_rename_${renaming}`, 10)) && Boolean(await controlAt(a, `saved_delete_${renaming}`, 10)));
  await a.screenshot({ path: `${out}/4_saved_models_a.png` }).catch(() => {});
  await press(a, `saved_rename_${renaming}`);
  check(`...Rename asks the new name: typed "${BARN}"`, await typeInto(a, "saved_rename_name", BARN));
  check(`...renamed in A's storage, the name in the file too`, await until(async () =>
    (await storedText(a, savedKey(BARN))).startsWith(`0 ${BARN}`) && (await storedText(a, savedKey(besideName))) === "", 60));
  check(`...and with the account: "${BARN}", no "${besideName}"`, await until(async () => {
    const models = await listed();
    return Boolean(named(models, BARN)) && !named(models, besideName);
  }, 120));
  await comeBack(b);
  check(`B, back at its window, has "${BARN}" and no "${besideName}"`, await until(async () =>
    (await storedText(b, savedKey(BARN))).startsWith(`0 ${BARN}`) && (await storedText(b, savedKey(besideName))) === "", 120));
  check(`...and its model, which was "${besideName}", is called "${BARN}": "${await b.title()}"`,
    await titleBecomes(b, `${BARN} — Brickworks`, 30));

  // -- 5. deleted in A, while B changes it -----------------------------------------
  console.log(`\ndeleted in browser A while browser B takes a part off it`);
  check(`in B, a part taken off "${BARN}", not saved`, await deleteAPart(b));
  const partsEdited = (await state(b)).bricks;
  const deleting = await rowOf(a, BARN);
  await press(a, `saved_delete_${deleting}`);
  const sure = await controlAt(a, "saved_delete_ok", 20);
  await a.screenshot({ path: `${out}/5_delete_asks.png` }).catch(() => {});
  check(`A: Delete asks first`, Boolean(sure));
  if (sure) await a.mouse.click(sure.x, sure.y);
  check(`...deleted from A's storage, with Undo on its row`, await until(async () =>
    (await storedText(a, savedKey(BARN))) === "" && Boolean(await controlAt(a, "saved_undo_1", 5)), 60));
  check(`...and from the account`, await until(async () => !named(await listed(), BARN), 120));
  await comeBack(b);
  check(`B, back at its window: "${BARN}" gone from its storage, its model still on the baseplate (${partsEdited} parts)`,
    await until(async () => (await storedText(b, savedKey(BARN))) === "", 120)
    && (await state(b)).bricks === partsEdited && (await b.title()) === `${BARN} — Brickworks`);
  await press(b, "save");
  check(`B saves: its change is a saved model again, with the account (${partsEdited} parts)`,
    await until(async () => named(await listed(), BARN)?.parts === partsEdited, 120));
  await comeBack(a);
  check(`...and back in A, whole`, await until(async () =>
    sha(await storedText(a, savedKey(BARN))) === named(await listed(), BARN)?.sum, 120));
  await press(a, "saved_close");
  check(`A deletes "${NAME}"`, await openSavedModels(a) && await press(a, `saved_delete_${await rowOf(a, NAME)}`)
    && await press(a, "saved_delete_ok", 20));
  check(`...gone from A and the account`, await until(async () =>
    (await storedText(a, savedKey(NAME))) === "" && !named(await listed(), NAME), 120));
  await a.screenshot({ path: `${out}/5_deleted_undo.png` }).catch(() => {});
  check(`...and its Undo puts it back, in A and with the account`, await press(a, "saved_undo_1") && await until(async () =>
    (await storedText(a, savedKey(NAME))).startsWith(`0 ${NAME}`) && Boolean(named(await listed(), NAME)), 120));
  await press(a, "saved_close");

  // -- 6. an account near its limit ---------------------------------------------------
  console.log(`\nan account near its limit (${FULL_EMAIL})`);
  const fullSession = await mintSession(FULL_EMAIL);
  check("449 models in the account already", await fillers(fullSession.kept.user_id, 1, 449));
  const contextD = await signedInContext(FULL_EMAIL);
  // A browser that has them already would not fetch them: this one is kept
  // from fetching 449 models it does not need.
  await contextD.route(/\/api\/models\?name=Filler/, (route) => route.abort("internetdisconnected"));
  const d = await opened(contextD, join(url, "model=res://models/house.ldr"));
  if (!(await controlAt(d, "model_name"))) throw new Error("the app never came up in browser D");
  await until(async () => (await state(d)).bricks > 0 && (await state(d)).awaited === 0, 120);
  await d.waitForTimeout(4000);
  check(`renamed "Room House"`, await rename(d, "Room House"));
  await press(d, "save");
  const near = await until(async () => /nearly full/.test((await state(d)).room_offer || ""), 120);
  check(`Save says the account is nearly full: "${(await state(d)).room_offer}"`,
    near && /450 of the 500 models/.test((await state(d)).room_offer));
  await d.screenshot({ path: `${out}/6_nearly_full.png` }).catch(() => {});
  check("...offering to delete old models, which opens the saved models, the oldest first",
    await press(d, "room_delete_old") && await until(async () =>
      (await state(d)).saved_models?.open === true && /oldest first/.test((await state(d)).saved_models?.note || ""), 20));
  await press(d, "saved_close");
  check("50 more: 499", await fillers(fullSession.kept.user_id, 450, 499));
  check(`renamed "Room House Two", a model the account has not got`, await rename(d, "Room House Two"));
  await press(d, "save");
  const full = await until(async () => /is full/.test((await state(d)).room_offer || ""), 120);
  check(`...its save says the account is full: "${(await state(d)).room_offer}"`,
    full && /500 of the 500 models/.test((await state(d)).room_offer) && /only in this browser/.test((await state(d)).room_offer));
  check("...and it is kept in this browser", (await storedText(d, savedKey("Room House Two"))).startsWith("0 Room House Two"));
  await d.screenshot({ path: `${out}/6_full.png` }).catch(() => {});
  await contextD.close();

  // -- 7. signed out -------------------------------------------------------------
  console.log("\nbrowser C, signed out: a deployment with no accounts");
  const contextC = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const said = await (await fetch(`${origin}/api/account`, { headers: bypass ? { "x-vercel-protection-bypass": bypass } : {} })).json();
  await contextC.route("**/api/account*", (route) => route.fulfill({ status: 200, contentType: "application/json",
    body: JSON.stringify({ ...said, enabled: false, url: null, key: null, signed_in: false }) }));
  let asked = 0;
  contextC.on("request", (request) => { if (new URL(request.url()).pathname.startsWith("/api/models")) asked += 1; });
  const c = await opened(contextC, join(url, "model=res://models/house.ldr"));
  if (!(await controlAt(c, "model_name"))) throw new Error("the app never came up in browser C");
  await until(async () => (await state(c)).bricks > 0 && (await state(c)).awaited === 0, 120);
  await c.waitForTimeout(4000);
  check("its name cleared, so nobody has named it", await rename(c, ""));
  check("a part deleted", await deleteAPart(c));
  const partsC = (await state(c)).bricks;
  check("New asks first", await press(c, "new") && Boolean((await controlAt(c, "new_save", 20))));
  await press(c, "new_save");
  const asking = await controlAt(c, "save_name", 20);
  check("...and \"Save, then start new\" asks what to call it", Boolean(asking));
  await c.screenshot({ path: `${out}/5_asks_a_name.png` }).catch(() => {});
  if (asking) {
    await c.mouse.click(asking.x, asking.y);
    await c.keyboard.type("Asked House");
    await c.keyboard.press("Enter");
  }
  check(`...saved under that name, in this browser (${partsC} parts)`, await until(async () =>
    (await storedText(c, savedKey("Asked House"))).startsWith("0 Asked House"), 120));
  check("...and nothing saved as \"Untitled\"", (await storedText(c, savedKey("Untitled"))) === "");
  const fresh = await until(async () => (await state(c)).bricks === 0 && (await c.title()) === "Untitled — Brickworks", 60);
  check(`...then the new model: "${await c.title()}", ${(await state(c)).bricks} parts`, fresh);
  check(`...and nothing was sent anywhere: ${asked} requests to /api/models`, asked === 0);
  await contextC.close();

  // -- 8. the account deleted ----------------------------------------------------
  console.log("\nthe account deleted");
  const held = await rows();
  check(`the database holds its models: ${(held || []).map((m) => `${m.name} v${m.version}`).join(", ")}`,
    (held || []).length >= 2);
  const gone = await fetch(`${origin}/api/account?op=delete`, { method: "POST",
    headers: await headers({ "content-type": "application/json" }), body: JSON.stringify({ confirm: EMAIL }) });
  check(`deleted as a person deletes theirs (api/account.js ?op=delete): ${gone.status}`, gone.ok);
  const left = await rows();
  check(`...and its models with it: ${left ? left.length : "?"} rows left`, Array.isArray(left) && left.length === 0);
} catch (trouble) {
  console.log(`  FAIL  ${String(trouble?.message || trouble).slice(0, 200)}`);
  failed += 1;
} finally {
  // Whatever happened, the throwaway accounts go.
  await deleteAccount(EMAIL).catch(() => {});
  await deleteAccount(FULL_EMAIL).catch(() => {});
}
check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);
await browser.close();
console.log(failed ? `\n${failed} failed`
  : "\na signed-in person's models kept with their account: in Open in a fresh browser, both of two saves kept, renamed and deleted everywhere with a change kept, Undo, the limit said, saved offline and signed out, and gone with the account");
process.exit(failed ? 1 : 0);
