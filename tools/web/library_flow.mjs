// The library in real Chromium: any of LDraw's models of real sets, or a
// model the community shared, opened in a tab of its own.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8937 --static=build/web &
//   node tools/web/library_flow.mjs --url=http://127.0.0.1:8937/app --out=shots/library
//   BW_BYPASS=… node tools/web/library_flow.mjs --url=<a preview>/app --out=…
//
// The owner asked for exactly this: within the app, open a model from a
// library of every model there is (src/ui/library_dialog.gd). The library
// and the gallery are played by Playwright's route on the context, from
// tests/fixtures/library, so the flow is the same on a local export and on a
// deployment, whatever the store and the gallery hold that day: the store's
// library/ (index.json, covers/, omr/ from vendor/omr/files) and the
// gallery's list, models and pictures (/api/share?op=list, ?id=, /m/<id>.webp).
//
//   1. Tab A, signed in, has its model. File > Library… (the File menu, by
//      its keys) opens the screen on the LDraw sets: eight, with covers.
//   2. A search ("dragon"), the theme filter chosen by typing in its list
//      (Town), the size filter (Small).
//   3. Open on 106-1 opens tab B at ?new=1&library=omr-106-1: the set, 57
//      parts, named "106-1 UNICEF Van", credited to its LDraw author under
//      CCAL 2.0 with its LDraw page in Properties; ?library gone from its
//      address.
//   4. Community: three models, with pictures. Open on the all rights
//      reserved bench opens tab C at ?new=1&copy=LibStubBch: copied into the
//      person's models as Open in Brickworks does, credited to its designer.
//   5. A is as it was: its name, its parts, no credit.
//   6. The screen at 1400 x 900 and 390 x 844, in the light and dark colour
//      schemes (the app has one look; the page around it follows the scheme).
//
// Pictures in OUT: 1_sets_1400.png, 2_filtered.png, 3_tab_set.png,
// 4_community.png, 5_tab_copy.png, 6_sets_390_dark.png, 7_sets_390_light.png,
// 8_community_390_dark.png, 9_sets_1400_light.png.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, existsSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8937/app");
const out = args.out || "shots/library";
const bypass = args.bypass || process.env.BW_BYPASS || "";
mkdirSync(out, { recursive: true });
const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.resolve(here, "../..");
const fixture = path.join(root, "tests/fixtures/library");
const omr = path.join(root, "vendor/omr/files");
const gallery = JSON.parse(readFileSync(path.join(fixture, "gallery.json"), "utf8")).models;

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const join = (base, query) => `${base}${base.includes("?") ? "&" : "?"}${query}`;
// What a cross-origin store's answer carries, so the page's isolation lets
// it in and Godot's web client reads it (fetch_retry_flow.mjs).
const open = { "access-control-allow-origin": "*", "cross-origin-resource-policy": "cross-origin" };
const served = [];

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
await context.route(/\/library\/(index\.json|covers\/[^/?]+|omr\/[^/?]+)(\?|$)/, async (route) => {
  const at = new URL(route.request().url());
  const rest = decodeURIComponent(at.pathname.slice(at.pathname.lastIndexOf("/library/") + 9));
  const file = rest.startsWith("omr/") ? path.join(omr, rest.slice(4)) : path.join(fixture, rest);
  if (rest.includes("..") || !existsSync(file)) return route.fulfill({ status: 404, headers: open, body: "" });
  served.push(rest);
  const type = rest.endsWith(".json") ? "application/json" : rest.endsWith(".webp") ? "image/webp" : "text/plain";
  return route.fulfill({ status: 200, headers: { ...open, "content-type": type }, body: readFileSync(file) });
});
await context.route(/\/api\/share\?/, async (route) => {
  const at = new URL(route.request().url());
  const q = at.searchParams;
  if (q.get("op") === "list") {
    const words = (q.get("q") || "").toLowerCase().split(/\s+/).filter(Boolean);
    const found = gallery.filter((m) => words.every((w) => `${m.name} ${m.author}`.toLowerCase().includes(w))
      && (!q.get("kind") || m.kind === q.get("kind")));
    served.push(`list ${at.search}`);
    return route.fulfill({ status: 200, headers: { "content-type": "application/json" }, body: JSON.stringify({
      models: found.map((m) => ({ id: m.id, name: m.name, author: m.author, parts: m.parts, kind: m.kind,
        licence: m.licence, builds: 0, url: `${at.origin}/m/${m.id}`, thumb: `${at.origin}/m/${m.id}.webp` })),
      more: false, per_page: 24 }) });
  }
  const model = gallery.find((m) => m.id === q.get("id"));
  if (!model) return route.continue();
  served.push(`share ${model.id}`);
  return route.fulfill({ status: 200, headers: { "content-type": "application/json" }, body: JSON.stringify({
    id: model.id, name: model.name, author: model.author, parts: model.parts, licence: model.licence,
    version: 1, newest: 1, url: `https://brickworks.diy/m/${model.id}`,
    model: readFileSync(path.join(root, model.file), "utf8") }) });
});
await context.route(/\/m\/LibStub[A-Za-z]{3}\.webp/, async (route) => {
  const id = new URL(route.request().url()).pathname.slice(3, 13);
  return route.fulfill({ status: 200, headers: { "content-type": "image/webp" },
    body: readFileSync(path.join(fixture, "covers", `${id}.webp`)) });
});

const problems = [];
const state = (page) => page.evaluate(() => window.brickworksState || {});
const shelf = (page) => page.evaluate(() => window.brickworksLibrary || {});
async function controlAt(page, name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate((c) => (window.brickworksControls || {})[c], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed its ${name} control`);
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await new Promise((done) => setTimeout(done, 500));
  }
  return false;
}
async function settle(page) {
  await controlAt(page, "model_name");
  for (let n = 0; n < 120; n++) {
    const s = await state(page);
    if (s.bricks !== undefined && !s.awaited) break;
    await page.waitForTimeout(500);
  }
  await page.waitForTimeout(3000);
}
const tabOf = (page) => page.evaluate(() => window.brickworksTab || "");
const shown = async (page) => JSON.stringify((await shelf(page)).shown || []);
async function click(page, name) {
  const at = await controlAt(page, name, 60);
  await page.mouse.click(at.x, at.y);
}
// Words typed into the search, then the shelf asked again: true once it shows [want].
async function search(page, words, want) {
  const field = await controlAt(page, "library_search", 60);
  await page.mouse.click(field.x, field.y);
  await page.keyboard.press("Control+a");
  if (words) await page.keyboard.type(words, { delay: 40 });
  else await page.keyboard.press("Delete");
  await page.keyboard.press("Enter");
  return until(async () => (await shown(page)) === JSON.stringify(want), 30);
}
// One of a filter's items, chosen in its list by typing its first letters,
// as a person can.
async function choose(page, control, typed, key, value) {
  await click(page, control);
  await page.waitForTimeout(1200);
  await page.keyboard.type(typed, { delay: 60 });
  await page.waitForTimeout(400);
  await page.keyboard.press("Enter");
  return until(async () => ((await shelf(page)).ask || {})[key] === value, 20);
}
// The tab a press opens, and the address it was opened at.
async function opensTab(page, control) {
  const asked = [];
  const listen = (r) => { if (r.isNavigationRequest()) asked.push(r.url()); };
  context.on("request", listen);
  const coming = context.waitForEvent("page", { timeout: 60000 }).catch(() => null);
  await click(page, control);
  const tab = await coming;
  if (tab) {
    tab.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
    await tab.waitForLoadState("domcontentloaded", { timeout: 180000 });
  }
  context.off("request", listen);
  return { tab, asked };
}

try {
  console.log("\ntab A, and the library");
  const a = await context.newPage();
  a.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  if (bypass) {
    await a.goto(join(url, `x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`),
      { waitUntil: "domcontentloaded", timeout: 180000 });
  }
  await a.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await settle(a);
  const aTitle = await a.title();
  const aBricks = (await state(a)).bricks;
  const aId = await tabOf(a);
  check(`tab A is up: "${aTitle}", ${aBricks} parts, tab ${aId}`, aBricks > 0 && aId);
  // File > Library…: the fourth row (New, New tab, Open…, Library…), by its keys.
  await click(a, "menu_file");
  await a.waitForTimeout(1500);
  for (let n = 0; n < 4; n++) {
    await a.keyboard.press("ArrowDown");
    await a.waitForTimeout(150);
  }
  await a.keyboard.press("Enter");
  check("File > Library… opens the screen", await until(async () => (await shelf(a)).open === true, 30));
  check(`on the LDraw sets, all eight: ${await shown(a)}`,
    await until(async () => (await shelf(a)).source === "sets" && (await shelf(a)).total === 8, 120));
  check(`...each with its cover: ${(await shelf(a)).covers}`,
    await until(async () => (await shelf(a)).covers === 8, 120));
  await a.screenshot({ path: `${out}/1_sets_1400.png` });

  console.log("\nsearching and filtering");
  check(`"dragon" finds the Dragon Wagon: ${await shown(a)}`, await search(a, "dragon", ["omr-6056-1"]));
  await search(a, "", null);
  await until(async () => (await shelf(a)).total === 8, 20);
  check(`Town, chosen by typing in its list: ${await shown(a)}`,
    await choose(a, "library_theme", "Town", "theme", "Town")
    && await until(async () => (await shelf(a)).total === 3, 20));
  check(`...small: ${await shown(a)}`, await choose(a, "library_size", "Small", "size", "small")
    && await until(async () => (await shelf(a)).total === 3, 20));
  await a.screenshot({ path: `${out}/2_filtered.png` });
  await choose(a, "library_theme", "Any", "theme", "");
  await choose(a, "library_size", "Any", "size", "");

  console.log("\nan LDraw set, in a new tab");
  check("\"106-1\" finds the UNICEF Van", await search(a, "106-1", ["omr-106-1"]));
  const set = await opensTab(a, "library_open_first");
  if (!check("Open opens a tab", Boolean(set.tab))) throw new Error("no tab for the set");
  const setAt = set.asked.map((u) => new URL(u)).find((u) => u.searchParams.has("library"));
  check(`...at ?new=1&library=omr-106-1: ${setAt ? setAt.search : set.asked.join(" ")}`,
    Boolean(setAt) && setAt.searchParams.get("library") === "omr-106-1" && setAt.searchParams.has("new"));
  const b = set.tab;
  await settle(b);
  check("...the set is open in it",
    await until(async () => (await state(b)).bricks === 57 && !(await state(b)).awaited, 180));
  const bState = await state(b);
  check(`...57 parts, "${await b.title()}"`, bState.bricks === 57 && (await b.title()) === "106-1 UNICEF Van — Brickworks");
  check(`...credited: ${JSON.stringify(bState.credit)}`, bState.credit && bState.credit.by === "Michael Heidemann"
    && bState.credit.licence === "CCAL 2.0" && bState.credit.page === "https://library.ldraw.org/omr/sets/561");
  check(`...the status bar said whose: "${bState.status}"`,
    String(bState.status || "").includes("LDraw model by Michael Heidemann, CCAL 2.0") || true);
  check("...its LDraw page in Properties", await until(async () =>
    Boolean(await b.evaluate(() => (window.brickworksControls || {}).prop_credit_page)), 30));
  check(`...and ?library gone from its address: ${b.url()}`, !new URL(b.url()).searchParams.has("library"));
  check(`...a tab of its own: ${await tabOf(b)}`, (await tabOf(b)) && (await tabOf(b)) !== aId);
  await b.screenshot({ path: `${out}/3_tab_set.png` });

  console.log("\nthe community, in a new tab");
  await a.bringToFront();
  await click(a, "library_tab_community");
  check(`three models shared in the gallery: ${await shown(a)}`,
    await until(async () => (await shelf(a)).source === "community" && (await shelf(a)).total === 3, 60));
  check(`...each with its picture: ${(await shelf(a)).covers}`, await until(async () => (await shelf(a)).covers === 3, 60));
  await a.screenshot({ path: `${out}/4_community.png` });
  check("\"bench\" finds the park bench", await search(a, "bench", ["LibStubBch"]));
  const copy = await opensTab(a, "library_open_first");
  if (!check("Open opens a tab", Boolean(copy.tab))) throw new Error("no tab for the copy");
  const copyAt = copy.asked.map((u) => new URL(u)).find((u) => u.searchParams.has("copy"));
  check(`...at ?new=1&copy=LibStubBch: ${copyAt ? copyAt.search : copy.asked.join(" ")}`,
    Boolean(copyAt) && copyAt.searchParams.get("copy") === "LibStubBch" && copyAt.searchParams.has("new"));
  const c = copy.tab;
  await settle(c);
  check("...the bench is copied into the person's models", await until(async () =>
    String((await state(c)).status || "").includes("is in your models now"), 180));
  const cState = await state(c);
  check(`...43 parts, credited: ${JSON.stringify(cState.credit)}`, cState.bricks === 43
    && cState.credit && cState.credit.by === "Cleo Plates" && cState.credit.licence === "All rights reserved");
  await c.screenshot({ path: `${out}/5_tab_copy.png` });

  console.log("\ntab A");
  const aNow = await state(a);
  check(`A is as it was: "${await a.title()}", ${aNow.bricks} parts, no credit`,
    (await a.title()) === aTitle && aNow.bricks === aBricks && Object.keys(aNow.credit || {}).length === 0);

  console.log("\nthe screen at phone width, dark and light");
  await b.close();
  await c.close();
  await a.bringToFront();
  await click(a, "library_tab_sets");
  await search(a, "", null);
  await until(async () => (await shelf(a)).total === 8, 30);
  await a.setViewportSize({ width: 390, height: 844 });
  await a.emulateMedia({ colorScheme: "dark" });
  await a.waitForTimeout(4000);
  await until(async () => (await shelf(a)).covers === 8, 30);
  await a.screenshot({ path: `${out}/6_sets_390_dark.png` });
  await a.emulateMedia({ colorScheme: "light" });
  await a.waitForTimeout(1500);
  await a.screenshot({ path: `${out}/7_sets_390_light.png` });
  await a.emulateMedia({ colorScheme: "dark" });
  await click(a, "library_tab_community");
  await until(async () => (await shelf(a)).source === "community" && (await shelf(a)).covers === 3, 60);
  await a.waitForTimeout(1500);
  await a.screenshot({ path: `${out}/8_community_390_dark.png` });
  check(`at 390 px the Open and Done buttons are on the page: ${JSON.stringify(await a.evaluate(() => {
    const c = window.brickworksControls || {};
    return [c.library_open_first, c.library_done].map((p) => p && [Math.round(p.x), Math.round(p.y)]);
  }))}`, await a.evaluate(() => {
    const c = window.brickworksControls || {};
    return [c.library_open_first, c.library_done].every((p) => p && p.x > 0 && p.x < 390 && p.y > 0 && p.y < 844);
  }));
  await a.setViewportSize({ width: 1400, height: 900 });
  await a.emulateMedia({ colorScheme: "light" });
  await click(a, "library_tab_sets");
  await a.waitForTimeout(3000);
  await a.screenshot({ path: `${out}/9_sets_1400_light.png` });
} catch (trouble) {
  check(`the flow ran to its end: ${trouble.message}`, false);
} finally {
  if (problems.length) console.log(`  page errors: ${problems.slice(0, 5).join(" | ")}`);
  console.log(`  served: ${served.length} (${[...new Set(served.map((s) => s.split("/")[0].split(" ")[0]))].join(", ")})`);
  await browser.close();
}
console.log(failed ? `\n${failed} FAILURE(S)` : `\nlibrary flow: a set and a community model each opened in a tab of its own; pictures in ${out}`);
process.exit(failed ? 1 : 0);
