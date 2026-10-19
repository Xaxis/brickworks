// File > New tab, in real Chromium: a second tab on a new model of its own.
//
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8890 --static=build/web &
//   node tools/web/newtab_flow.mjs --url=http://127.0.0.1:8890/app --out=shots/newtab
//   BW_BYPASS=… node tools/web/newtab_flow.mjs --url=<a preview>/app --out=…
//
// The owner (2026-10-19) asked how a person even starts a new model in
// another tab. There was no way from the app: they had to open the site
// again themselves, and that tab came up on the newest model no open tab
// held, never a new one (src/parts/tab_session.gd). One browser context, as
// a person's browser is:
//
//   1. An older model nobody holds: a tab renamed "Newtab Older", then
//      closed. Tab A, opened while it was open, has a model of its own.
//   2. File > New tab, clicked in A, opens tab B (?new=1, from the click
//      itself, so no pop-up blocker stops it): an id of its own, not A's
//      and not the older one's; ?new gone from its address; an empty
//      baseplate, Untitled, its empty working model in the browser's
//      storage under its own session. A is as it was.
//   3. B reloaded is B, still empty (not the example car a first visit
//      gets); a part put down in B and B reloaded again keeps it.
//   4. A third tab opened by hand, as before, takes the newest session no
//      tab holds: the older model's.
//   5. The File menu, as a person sees it, at 1280 and 390 px wide.
//
// Pictures: 1_file_menu.png, 2_new_tab.png, 3_reloaded_empty.png,
// 4_reloaded_part.png, 5_by_hand.png, 6_file_menu_390.png.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8890/app");
const out = args.out || "shots/newtab";
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;
// Where the engine keeps user:// in the browser's storage.
const USER = "/userfs/godot/app_userdata/Brickworks";
// The File menu's second row, New tab, below the File button: measured on
// the menu at 13 px (Shell._fill), 1_file_menu.png.
const SECOND_ROW = { dx: 30, dy: 50 };

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const problems = [];

async function state(page) {
  return page.evaluate(() => window.brickworksState || {});
}
async function controlAt(page, name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate((c) => (window.brickworksControls || {})[c], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed its ${name} control`);
}
async function titleBecomes(page, wanted, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    if ((await page.title()) === wanted) return true;
    await page.waitForTimeout(500);
  }
  return false;
}
// Up, with its model whole: its parts arrive over the network.
async function settle(page) {
  await controlAt(page, "model_name");
  for (let n = 0; n < 120; n++) {
    const s = await state(page);
    if (s.bricks !== undefined && !s.awaited) break;
    await page.waitForTimeout(500);
  }
  await page.waitForTimeout(3000);
}
async function opened(page, address) {
  page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  await page.goto(address, { waitUntil: "domcontentloaded", timeout: 180000 });
  await settle(page);
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
// What the browser has stored under a session: its working model's text.
async function autosaveOf(page, id) {
  return page.evaluate((path) => new Promise((resolve) => {
    const req = indexedDB.open("/userfs");
    req.onerror = () => resolve(null);
    req.onsuccess = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); resolve(null); return; }
      const get = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").get(path);
      get.onsuccess = () => {
        db.close();
        const v = get.result;
        resolve(v && v.contents ? new TextDecoder().decode(v.contents) : null);
      };
      get.onerror = () => { db.close(); resolve(null); };
    };
  }), `${USER}/sessions/${id}/autosave.ldr`);
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await new Promise((done) => setTimeout(done, 500));
  }
  return false;
}
const hasParts = (text) => /(^|\n)1 /.test(text || "");
const tabOf = (page) => page.evaluate(() => window.brickworksTab || "");
async function reload(page) {
  await page.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await settle(page);
}
// A 2 x 4 brick taken by the bin's search and put down in the middle of
// the view, as placing_flow.mjs does.
async function putABrick(page) {
  const search = await controlAt(page, "part search");
  await page.mouse.click(search.x, search.y);
  await page.keyboard.press("Control+a");
  await page.keyboard.type("3001", { delay: 30 });
  await page.waitForTimeout(1600);
  const first = await controlAt(page, "first part", 30);
  await page.mouse.click(first.x, first.y);
  if (!(await until(async () => String((await state(page)).held || "") === "3001", 15))) return false;
  await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  let layout = null;
  await until(async () => (layout = await page.evaluate(() => window.brickworksLayout || null)) !== null, 15);
  const view = layout && layout.view;
  if (!view) return false;
  for (let n = 0; n < 6; n++) {
    const x = view[0] + view[2] / 2 + n * 3;
    const y = view[1] + view[3] / 2;
    await page.mouse.move(x, y, { steps: 2 });
    await page.waitForTimeout(1200);
    if (!(await state(page)).can_place) continue;
    await page.mouse.click(x, y);
    if (await until(async () => (await state(page)).bricks === 1, 8)) {
      await page.keyboard.press("Escape");
      return true;
    }
  }
  return false;
}

try {
  console.log("\nan older model nobody holds, and tab A");
  const older = await context.newPage();
  if (bypass) {
    await older.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
  }
  await opened(older, url);
  check("the older tab renamed \"Newtab Older\"", await rename(older, "Newtab Older"));
  const olderId = await tabOf(older);
  const a = await context.newPage();
  await opened(a, url);
  check("tab A renamed \"Newtab A\"", await rename(a, "Newtab A"));
  const aId = await tabOf(a);
  const aBricks = (await state(a)).bricks;
  check(`tab A has an id of its own (${aId}) and a model (${aBricks} parts)`,
    aId && aId !== olderId && aBricks > 0);
  await older.close();
  // Read from A: the tabs share the browser's storage. A model kept as
  // its file was carries its name on a line of its own (ModelStore.TITLE_META).
  check(`the older tab closed, its model stays stored under its session ${olderId}, named`,
    await until(async () => (await autosaveOf(a, olderId) || "")
      .includes("0 !BRICKWORKS TITLE Newtab Older"), 120));

  console.log("\nFile > New tab, in A");
  const file = await controlAt(a, "menu_file");
  await a.mouse.click(file.x, file.y);
  await a.waitForTimeout(2500);
  const row = { x: file.x + SECOND_ROW.dx, y: file.y + SECOND_ROW.dy };
  await a.mouse.move(row.x, row.y, { steps: 3 });
  await a.waitForTimeout(1200);
  await a.screenshot({ path: `${out}/1_file_menu.png` });
  // What the new tab was opened at: its first address, before the page
  // takes ?new out of it.
  const asked = [];
  context.on("request", (r) => { if (r.isNavigationRequest()) asked.push(r.url()); });
  const coming = context.waitForEvent("page", { timeout: 60000 }).catch(() => null);
  await a.mouse.click(row.x, row.y);
  const b = await coming;
  if (!check("clicking New tab opens a tab", Boolean(b))) throw new Error("no new tab");
  b.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  await b.waitForLoadState("domcontentloaded", { timeout: 180000 });
  // The path A is at: /app on a deployment, / on the local server.
  const at = asked.map((u) => new URL(u)).find((u) => u.searchParams.has("new"));
  check(`...at ?new=1 on the path A is at: ${at ? at.pathname + at.search : asked.join(" ")}`,
    Boolean(at) && at.pathname === new URL(a.url()).pathname && at.search === "?new=1");
  await settle(b);
  const bId = await tabOf(b);
  check(`B has an id of its own: ${bId} (A ${aId}, the older ${olderId})`,
    bId && bId !== aId && bId !== olderId);
  check(`...and ?new is gone from its address: ${b.url()}`, !new URL(b.url()).searchParams.has("new"));
  const bState = await state(b);
  check(`B is an empty baseplate, Untitled: ${bState.bricks} parts, "${await b.title()}"`,
    bState.bricks === 0 && (await b.title()) === "Untitled — Brickworks");
  const bSaved = await until(async () => {
    const text = await autosaveOf(b, bId);
    return text !== null && !hasParts(text);
  }, 60);
  check("...its empty working model stored under its own session", bSaved);
  await b.screenshot({ path: `${out}/2_new_tab.png` });
  const aNow = await state(a);
  check(`A is as it was: ${aId}, "${await a.title()}", ${aNow.bricks} parts`,
    (await tabOf(a)) === aId && (await a.title()) === "Newtab A — Brickworks" && aNow.bricks === aBricks);

  console.log("\nB reloaded, empty and then with a part");
  await reload(b);
  check(`B reloaded is B (${await tabOf(b)}), still empty: ${(await state(b)).bricks} parts, "${await b.title()}"`,
    (await tabOf(b)) === bId && (await state(b)).bricks === 0 && (await b.title()) === "Untitled — Brickworks");
  await b.screenshot({ path: `${out}/3_reloaded_empty.png` });
  check("a 2 x 4 brick put down in B", await putABrick(b));
  check("...and B's working model stored with it",
    await until(async () => hasParts(await autosaveOf(b, bId)), 120));
  await reload(b);
  check(`B reloaded again is B (${await tabOf(b)}) with its part: ${(await state(b)).bricks}`,
    (await tabOf(b)) === bId && (await state(b)).bricks === 1);
  await b.screenshot({ path: `${out}/4_reloaded_part.png` });
  check(`A is still as it was: "${await a.title()}", ${(await state(a)).bricks} parts`,
    (await a.title()) === "Newtab A — Brickworks" && (await state(a)).bricks === aBricks);

  console.log("\na third tab, opened by hand");
  const c = await context.newPage();
  await opened(c, url);
  const cId = await tabOf(c);
  check(`it takes the newest session no tab holds, the older model's: ${cId}, "${await c.title()}"`,
    cId === olderId && (await c.title()) === "Newtab Older — Brickworks");
  await c.screenshot({ path: `${out}/5_by_hand.png` });
  await c.close();

  console.log("\nthe File menu at 390 px");
  await a.setViewportSize({ width: 390, height: 844 });
  await a.waitForTimeout(4000);
  const narrow = await controlAt(a, "menu_file", 30);
  await a.mouse.click(narrow.x, narrow.y);
  await a.waitForTimeout(2500);
  await a.screenshot({ path: `${out}/6_file_menu_390.png` });
  await a.keyboard.press("Escape");
} catch (trouble) {
  check(`the flow ran to its end: ${trouble.message}`, false);
} finally {
  if (problems.length) console.log(`  page errors: ${problems.slice(0, 5).join(" | ")}`);
  await browser.close();
}
console.log(failed ? `\n${failed} FAILURE(S)` : `\nnew tab flow: a tab of its own on a new model; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
