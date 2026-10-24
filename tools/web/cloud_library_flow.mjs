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
//   4. Signed out (a deployment with no accounts, browser C): a save is
//      kept in the browser and nothing is sent. Save on a model nobody has
//      named asks its name, as "Save, then start new" did not.
//   5. The account deleted (Settings' route, api/account.js ?op=delete):
//      its models go with it.
//
// On a build from before 2026-10-23 nothing is sent: 1 fails, and 2 finds
// nothing in Open; 4's Save saves "Untitled" without asking.
import { launch } from "./browser.mjs";
import { canSignIn, deleteAccount, mintSession, signInContext } from "./session.mjs";
import { createHash } from "node:crypto";
import { mkdirSync } from "node:fs";

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
async function signedInContext() {
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  await signInContext(context, EMAIL);
  return context;
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
  check(`...and the app says the account has it: ${JSON.stringify((await cloud(a)).last || {})}`,
    await until(async () => ((await cloud(a)).last?.names || []).includes(NAME) && (await cloud(a)).state === "kept", 60));
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
  check(`...the app knowing the account has not got it: ${(await cloud(b)).state}`,
    await until(async () => (await cloud(b)).state === "away", 60));
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
  check(`...B's model is called "${besideName}" now: "${await b.title()}"`,
    await titleBecomes(b, `${besideName} — Brickworks`, 60));
  check(`...B has A's under "${NAME}", whole`, await until(async () =>
    sha(await storedText(b, savedKey(NAME))) === named(await listed(), NAME)?.sum, 120));
  check(`...and its own under "${besideName}"`, await until(async () =>
    sha(await storedText(b, savedKey(besideName))) === named(await listed(), besideName)?.sum, 60));
  await b.screenshot({ path: `${out}/3_both_kept_b.png` }).catch(() => {});
  await a.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await controlAt(a, "model_name");
  check(`A, reloaded, has B's "${besideName}" too`, await until(async () =>
    sha(await storedText(a, savedKey(besideName))) === named(await listed(), besideName)?.sum, 180));

  // -- 4. signed out -------------------------------------------------------------
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
  check(`...then the new model: "${await c.title()}", ${(await state(c)).bricks} parts`, await until(async () =>
    (await state(c)).bricks === 0 && (await c.title()) === "Untitled — Brickworks", 60));
  check(`...and nothing was sent anywhere: ${asked} requests to /api/models`, asked === 0);
  await contextC.close();

  // -- 5. the account deleted ----------------------------------------------------
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
  // Whatever happened, the throwaway account goes.
  await deleteAccount(EMAIL).catch(() => {});
}
check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);
await browser.close();
console.log(failed ? `\n${failed} failed`
  : "\na signed-in person's models kept with their account: in Open in a fresh browser, both of two saves kept, saved offline and signed out, and gone with the account");
process.exit(failed ? 1 : 0);
