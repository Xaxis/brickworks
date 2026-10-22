// The library in real Chromium: any of LDraw's models of real sets, or a
// model the community shared, opened in a tab of its own.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8902 --static=build/web &
//   node tools/web/library_flow.mjs --url=http://127.0.0.1:8902/app --out=shots/library
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
//      (Town: three), the size filter (Under 200 parts: two of them).
//   3. Open on 106-1 opens tab B at ?new=1&library=omr-106-1: the set, 65
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
//
// --live plays nothing: the deployment's own parts store, its whole library
// (1,575 models), and its biggest model, 8466-1 (36 MB), found and opened in
// a new tab. That tab's longest stall is measured from the page itself (an
// interval timer's longest gap: the engine's frame and the page share one
// thread), with what its status bar said while the file came and was read,
// and how long it all took; and held to --open-ms (500) as the app's own
// work, its longest frame less its WebGL from the tab's controls showing
// until the model is whole and drawn (an interval's gap on a browser drawing
// in software is the page waiting on frames drawn before). Then the real
// gallery on the Community shelf. Run against a local export with
// serve.py --parts-url "$PARTS_URL", the deployment's store.
// Pictures live_1_sets.png, live_2_8466.png, live_3_community.png.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, existsSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8902/app");
const out = args.out || "shots/library";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const live = Boolean(args.live);
mkdirSync(out, { recursive: true });
const here = path.dirname(new URL(import.meta.url).pathname);
const root = path.resolve(here, "../..");
const fixture = path.join(root, "tests/fixtures/library");
const omr = path.join(root, "vendor/omr/files");
const gallery = JSON.parse(readFileSync(path.join(fixture, "gallery.json"), "utf8")).models;

let failed = 0;
// Waits on [ok] first (a promise), then words the line: [what] may be a
// function, read once the wait is over.
async function checkAfter(what, ok) {
  const passed = await ok;
  return check(typeof what === "function" ? await what() : what, passed);
}
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
if (!live) await context.route(/\/library\/(index\.json|covers\/[^/?]+|omr\/[^/?]+)(\?|$)/, async (route) => {
  const at = new URL(route.request().url());
  const rest = decodeURIComponent(at.pathname.slice(at.pathname.lastIndexOf("/library/") + 9));
  const file = rest.startsWith("omr/") ? path.join(omr, rest.slice(4)) : path.join(fixture, rest);
  if (rest.includes("..") || !existsSync(file)) return route.fulfill({ status: 404, headers: open, body: "" });
  served.push(rest);
  const type = rest.endsWith(".json") ? "application/json" : rest.endsWith(".webp") ? "image/webp" : "text/plain";
  return route.fulfill({ status: 200, headers: { ...open, "content-type": type }, body: readFileSync(file) });
});
if (!live) await context.route(/\/api\/share\?/, async (route) => {
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
// Where the engine keeps user:// in the browser's storage.
const USER = "/userfs/godot/app_userdata/Brickworks";
// A file the app keeps in the browser's storage, as text, or null.
async function stored(page, file) {
  return page.evaluate((at) => new Promise((resolve) => {
    const req = indexedDB.open("/userfs");
    req.onerror = () => resolve(null);
    req.onsuccess = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); resolve(null); return; }
      const get = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").get(at);
      get.onsuccess = () => {
        db.close();
        const v = get.result;
        resolve(v && v.contents ? new TextDecoder().decode(v.contents) : null);
      };
      get.onerror = () => { db.close(); resolve(null); };
    };
  }), `${USER}/${file}`);
}
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
  if (want === null) return until(async () => ((await shelf(page)).ask || {}).q === "", 30);
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

// The longest the page's own thread went without running an interval timer
// set at 50 ms, in every page from its start: window.__stall.
// And each gap over 250 ms, with when it ended: window.__gaps.
await context.addInitScript(() => {
  let last = performance.now();
  window.__stall = { longest: 0, at: 0 };
  window.__gaps = [];
  setInterval(() => {
    const now = performance.now();
    if (now - last > window.__stall.longest) window.__stall = { longest: now - last, at: now };
    if (now - last > 250) window.__gaps.push({ gap: now - last, at: now });
    last = now;
  }, 50);
});
// --live: every engine frame timed too, whole and inside WebGL, as
// cad_frames.mjs times them: window.__frames, [start, ms, ms in WebGL]. A
// frame less its WebGL is the app's own work, which an interval's gap is
// not on a browser drawing in software: there the page waits on the drawing
// of frames handed over before, whatever the frame it is in costs.
if (live) await context.addInitScript(() => {
  const frames = [];
  window.__frames = frames;
  const real = window.requestAnimationFrame.bind(window);
  let inside = false;
  let gl = 0;
  const timed = (callback) => (time) => {
    if (inside) { callback(time); return; }
    inside = true;
    gl = 0;
    const t0 = performance.now();
    try { callback(time); } finally {
      inside = false;
      frames.push([t0, performance.now() - t0, gl]);
      if (frames.length > 40000) frames.splice(0, 20000);
    }
  };
  const context = WebGL2RenderingContext.prototype;
  for (const name of Object.getOwnPropertyNames(context)) {
    const d = Object.getOwnPropertyDescriptor(context, name);
    if (!d || typeof d.value !== "function" || name === "constructor") continue;
    const was = d.value;
    context[name] = function (...a) {
      const t0 = performance.now();
      try { return was.apply(this, a); } finally { gl += performance.now() - t0; }
    };
  }
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
});

// The live library: every model, and the biggest opened in a tab of its own.
async function liveFlow(a, aTitle, aBricks) {
  await checkAfter(async () => `the live library, every model: ${(await shelf(a)).total} (${(await shelf(a)).status})`,
    until(async () => (await shelf(a)).source === "sets" && (await shelf(a)).total >= 1500, 180));
  await checkAfter(async () => `...the first page's covers: ${(await shelf(a)).covers}`,
    until(async () => (await shelf(a)).covers >= 24, 180));
  await a.screenshot({ path: `${out}/live_1_sets.png` });
  check("\"8466-1\" finds the biggest, 36 MB", await search(a, "8466-1", ["omr-8466-1"]));
  const began = Date.now();
  const set = await opensTab(a, "library_open_first");
  if (!check("Open opens a tab", Boolean(set.tab))) throw new Error("no tab for 8466-1");
  const b = set.tab;
  await controlAt(b, "model_name");
  // The stall of the page's start (the engine's own) is not the open's.
  await b.evaluate(() => { window.__stall = { longest: 0, at: 0 }; window.__gaps = []; });
  const from = await b.evaluate(() => performance.now());
  const opened = await until(async () => (await state(b)).bricks >= 1200 && !(await state(b)).awaited, 900);
  const took = Math.round((Date.now() - began) / 1000);
  // Until the model is drawn: 3 s of frames each under 100 ms of the app's
  // own work, two minutes at most.
  await until(() => b.evaluate(() => {
    const t = performance.now();
    const recent = window.__frames.filter(([t0]) => t0 >= t - 3000);
    return recent.length > 0 && recent.every(([, d, g]) => d - g < 100);
  }), 120);
  const bState = await state(b);
  check(`8466-1 open in ${took} s: ${bState.bricks} parts, "${await b.title()}"`,
    opened && (await b.title()).startsWith("8466-1 "));
  const said = await b.evaluate(() => (window.brickworksWork || []).map((w) => `${w.what} (${Math.round(w.ms)} ms)`));
  check(`...its status bar said the file coming and being read: ${said.filter((w) => /8466/.test(w)).join(" | ")}`,
    said.some((w) => /^Fetching 8466-1 .* \d+ MB/.test(w)) && said.some((w) => /^Reading 8466-1 /.test(w)));
  const stall = await b.evaluate(() => window.__stall);
  console.log(`  the page's longest stall while it opened: ${Math.round(stall.longest)} ms`);
  // Each stall over 250 ms, and what the status bar was saying as it ended;
  // and the longest while it said "Opening": the open's own, apart from the
  // frames that draw the model as its parts arrive, which on a browser
  // drawing in software are each about a second at 8466-1 on any build.
  const stalls = await b.evaluate(() => {
    const work = (window.brickworksWork || []).filter((w) => w.ended);
    const opening = work.filter((w) => /^Opening /.test(w.what));
    const from = opening.length ? Math.min(...opening.map((w) => w.at - w.ms)) : 0;
    const to = opening.length ? Math.max(...opening.map((w) => w.at)) : 0;
    let longest = 0;
    const list = (window.__gaps || []).map((g) => {
      if (opening.length && g.at - g.gap < to && g.at > from) longest = Math.max(longest, g.gap);
      const doing = work.filter((w) => w.at - w.ms <= g.at && w.at >= g.at - g.gap).map((w) => w.what);
      return `${Math.round(g.gap)} ms (${doing.join(", ") || "after the bar"})`;
    });
    return { list, opening: Math.round(longest), laid: Math.round(to - from) };
  });
  console.log(`  ...its stalls over 250 ms: ${stalls.list.length ? stalls.list.join(" | ") : "none"}`);
  console.log(`  the longest while it said Opening: ${stalls.opening ? `${stalls.opening} ms` : "under 250 ms"}, over ${stalls.laid} ms`);
  console.log(`  ...the open's phases: ${JSON.stringify(bState.open_phases || {})}`);
  // The open's own stall: its longest frame less its WebGL, from the tab
  // showing its controls until the model is whole and drawn (--open-ms, 500).
  const openMs = Number(args["open-ms"] && args["open-ms"] !== true ? args["open-ms"] : 500);
  const own = await b.evaluate((since) => {
    const work = (window.brickworksWork || []).filter((w) => w.ended);
    const doing = (t0, t1) => work.filter((w) => w.at - w.ms <= t1 && w.at >= t0).map((w) => w.what)
      .join(", ") || "after the bar";
    const frames = window.__frames.filter(([t0]) => t0 >= since)
      .map(([t0, d, g]) => ({ t0, d, g, own: d - g })).sort((x, y) => y.own - x.own);
    return { frames: frames.length, longest: frames.length ? frames[0].own : 0,
      over: frames.filter((f) => f.own > 100).length,
      top: frames.slice(0, 6).map((f) => `${Math.round(f.own)} ms (whole ${Math.round(f.d)}, WebGL `
        + `${Math.round(f.g)}; ${doing(f.t0, f.t0 + f.d)})`) };
  }, from);
  console.log(`  ...its frames' own work, the longest six of ${own.frames}: ${own.top.join(" | ")}`);
  check(`...the open's longest frame of the app's own work ${Math.round(own.longest)} ms of ${openMs} `
    + `(${own.over} frames over 100 ms)`, own.frames > 0 && own.longest < openMs);
  check(`...credited: ${JSON.stringify(bState.credit)}`, bState.credit && String(bState.credit.page || "")
    .startsWith("https://library.ldraw.org/omr/sets/"));
  await b.screenshot({ path: `${out}/live_2_8466.png` });
  const aNow = await state(a);
  check(`A is as it was: "${await a.title()}", ${aNow.bricks} parts`,
    (await a.title()) === aTitle && aNow.bricks === aBricks);
  await a.bringToFront();
  await search(a, "", null);
  await click(a, "library_tab_community");
  await checkAfter(async () => `the real gallery: ${(await shelf(a)).total} models, ${(await shelf(a)).covers} pictures`,
    until(async () => (await shelf(a)).source === "community" && (await shelf(a)).total > 0
      && (await shelf(a)).covers > 0, 120));
  await a.waitForTimeout(5000);
  await a.screenshot({ path: `${out}/live_3_community.png` });
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
  if (live) {
    await liveFlow(a, aTitle, aBricks);
    throw new Error("done");
  }
  await checkAfter(async () => `on the LDraw sets, all eight: ${await shown(a)}`,
    until(async () => (await shelf(a)).source === "sets" && (await shelf(a)).total === 8, 120));
  await checkAfter(async () => `...each with its cover: ${(await shelf(a)).covers}`,
    until(async () => (await shelf(a)).covers === 8, 120));
  await a.screenshot({ path: `${out}/1_sets_1400.png` });

  console.log("\nsearching and filtering");
  await checkAfter(async () => `"dragon" finds the Dragon Wagon: ${await shown(a)}`, search(a, "dragon", ["omr-6056-1"]));
  await search(a, "", null);
  await until(async () => (await shelf(a)).total === 8, 20);
  await checkAfter(async () => `Town, chosen by typing in its list: ${await shown(a)}`,
    (async () => await choose(a, "library_theme", "Town", "theme", "Town")
      && await until(async () => (await shelf(a)).total === 3, 20))());
  await checkAfter(async () => `...small: ${await shown(a)}`,
    (async () => await choose(a, "library_size", "Under", "size", "small")
      && await until(async () => (await shelf(a)).total === 2, 20))());
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
    await until(async () => (await state(b)).bricks === 65 && !(await state(b)).awaited, 180));
  const bState = await state(b);
  check(`...65 parts, "${await b.title()}"`, bState.bricks === 65 && (await b.title()) === "106-1 UNICEF Van — Brickworks");
  check(`...credited: ${JSON.stringify(bState.credit)}`, bState.credit && bState.credit.by === "Michael Heidemann"
    && bState.credit.licence === "CCAL 2.0" && bState.credit.page === "https://library.ldraw.org/omr/sets/561");
  check("...its LDraw page in Properties", await until(async () =>
    Boolean(await b.evaluate(() => (window.brickworksControls || {}).prop_credit_page)), 30));
  check(`...and ?library gone from its address: ${b.url()}`, !new URL(b.url()).searchParams.has("library"));
  check(`...a tab of its own: ${await tabOf(b)}`, (await tabOf(b)) && (await tabOf(b)) !== aId);
  await b.screenshot({ path: `${out}/3_tab_set.png` });

  console.log("\nthe community, in a new tab");
  await a.bringToFront();
  await click(a, "library_tab_community");
  await checkAfter(async () => `the search went with it to the other shelf: "${((await shelf(a)).ask || {}).q}"`,
    until(async () => (await shelf(a)).source === "community" && ((await shelf(a)).ask || {}).q === "106-1", 60));
  await search(a, "", null);
  await checkAfter(async () => `three models shared in the gallery: ${await shown(a)}`,
    until(async () => (await shelf(a)).source === "community" && (await shelf(a)).total === 3, 60));
  await checkAfter(async () => `...each with its picture: ${(await shelf(a)).covers}`,
    until(async () => (await shelf(a)).covers === 3, 60));
  await a.screenshot({ path: `${out}/4_community.png` });
  check("\"bench\" finds the park bench", await search(a, "bench", ["LibStubBch"]));
  const copy = await opensTab(a, "library_open_first");
  if (!check("Open opens a tab", Boolean(copy.tab))) throw new Error("no tab for the copy");
  const copyAt = copy.asked.map((u) => new URL(u)).find((u) => u.searchParams.has("copy"));
  check(`...at ?new=1&copy=LibStubBch: ${copyAt ? copyAt.search : copy.asked.join(" ")}`,
    Boolean(copyAt) && copyAt.searchParams.get("copy") === "LibStubBch" && copyAt.searchParams.has("new"));
  const c = copy.tab;
  await settle(c);
  // Saved under its own name, saying which link it is a copy of
  // (ModelStore.REMIX_META), as Open in Brickworks on its page saves it.
  check("...the bench is copied into the person's models, a remix of its link", await until(async () =>
    String(await stored(c, "models/Stub Park Bench.ldr") || "").includes("0 !BRICKWORKS REMIX LibStubBch"), 180));
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
  if (trouble.message !== "done") check(`the flow ran to its end: ${trouble.message}`, false);
} finally {
  if (problems.length) console.log(`  page errors: ${problems.slice(0, 5).join(" | ")}`);
  console.log(`  served: ${served.length} (${[...new Set(served.map((s) => s.split("/")[0].split(" ")[0]))].join(", ")})`);
  await browser.close();
}
console.log(failed ? `\n${failed} FAILURE(S)` : `\nlibrary flow: a set and a community model each opened in a tab of its own; pictures in ${out}`);
process.exit(failed ? 1 : 0);
