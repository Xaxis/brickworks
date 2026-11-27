// Every submenu of the menu bar, as a person's pointer meets it, in a
// browser: rested on its row, the submenu is drawn at once; it stays open
// while the pointer goes straight across and down into it, and while the
// pointer goes there on a slant over the rows below; and its third row is
// lit under the pointer. The owner, 2026-11-27: "the submenus like 'Import'
// or 'Open recent' are almost completely unresponsive ... they take forever
// to load and then flash away" (menufix).
//
//   node tools/web/submenu_flow.mjs --url=<preview>/app [--out=shots/submenu_web]
//        [--saves=50] [--only=Import,Open recent] [--bar-ms=0] [--label=live]
//
// At 1280 x 800, signed in as the checks' account (browser.mjs). --saves=N
// puts N saved models in the browser's storage before the app starts
// (IndexedDB /userfs, FILE_DATA: godot-web-idbfs-int8array), so Open recent
// has a person's full shelf to list. Everything is judged by what is drawn:
// the page's frames as Chromium hands them to the screen (a CDP screencast,
// each frame stamped when it was drawn: in software the page's own frame
// times say when a frame was handed over, not drawn), and pictures decoded
// in a page of their own so the app's thread does none of it. The main
// thread's long tasks (PerformanceObserver "longtask") say the longest
// frame while the submenu opened. --bar-ms=N fails a submenu drawn later
// than N ms after the pointer rested (0: measure only, as against a build
// from before). Writes a table (results.json, results.txt) and pictures in
// --out. It fails if a submenu never opens, closes on the way into it, or
// its third row is not lit when the pointer is on it.
import { caughtUp, controlsWith, launch, START_MS } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
// Always a preview's: it saves 50 models into the browser it drives.
if (!args.url || /\/\/(www\.)?brickworks\.diy\b/.test(String(args.url))) {
  console.log("submenu_flow: --url=<a preview>/app, never the live site");
  process.exit(2);
}
const url = String(args.url);
const out = args.out || "shots/submenu_web";
const saves = Number(args.saves || 0);
const barMs = Number(args["bar-ms"] || 0);
const label = args.label || "";
mkdirSync(out, { recursive: true });
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

// Each menu's rows in the order drawn (src/ui/shell.gd MENUS: separators
// left out, the submenus' rows by their words), and the submenus to try.
// File, Edit and View hold the same rows on the desktop and in a browser.
const MENUS = {
  File: ["new", "new_window", "open", "library", "collection", "collection_build", "Open recent",
    "Import", "save", "save_as", "versions", "Compare", "share", "together", "together_point",
    "comments", "Export", "render", "render_queue", "clear", "quit"],
  Edit: ["undo", "redo", "History", "cut_parts", "copy", "paste", "duplicate", "pattern", "delete",
    "select_all", "select_none", "Select by", "Show and hide", "lock", "unlock", "paint", "replace",
    "find_replace", "finish_surfaces", "mirror"],
  View: ["Viewpoint", "mode_orbit", "mode_pan", "mode_zoom", "fit", "fit_model", "fit_selection",
    "ortho", "grid", "Floor", "Edges and studs", "cut", "Cut away by", "xray", "stress", "stud_map",
    "joint_marks", "Panels", "split_view", "full_screen"],
};
const SUBMENUS = [["File", "Open recent"], ["File", "Import"], ["File", "Compare"], ["File", "Export"],
  ["Edit", "History"], ["Edit", "Select by"], ["Edit", "Show and hide"], ["View", "Viewpoint"],
  ["View", "Floor"], ["View", "Edges and studs"], ["View", "Cut away by"], ["View", "Panels"]];
const only = args.only ? String(args.only).split(",").map((s) => s.trim()) : null;
const tried = SUBMENUS.filter(([, row]) => !only || only.includes(row));

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}

async function until(page, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

// A person's shelf of saved models, cycled from the models that ship.
function shelf(count) {
  const kinds = ["sports_car", "three_core_rocket", "station", "orrery", "corner_shop", "barn_owl"];
  const texts = kinds.map((name) => readFileSync(join(ROOT, "models", `${name}.ldr`), "utf8"));
  return Array.from({ length: count }, (_, n) => ({
    name: `Shelf model ${String(n + 1).padStart(2, "0")}`, text: texts[n % texts.length], ago: n * 60,
  }));
}

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const thrown = [];
page.on("pageerror", (error) => thrown.push(String(error)));
// The main thread's long tasks, by the clock the screencast stamps frames with.
await page.addInitScript(() => {
  window.menuLong = [];
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) window.menuLong.push([performance.timeOrigin + e.startTime, e.duration]);
    }).observe({ type: "longtask", buffered: true });
  } catch { /* no long tasks in this browser */ }
});
if (saves > 0) {
  await page.addInitScript((models) => {
    if (!location.pathname.startsWith("/app") || sessionStorage.getItem("menufixShelf")) return;
    sessionStorage.setItem("menufixShelf", "1");
    const base = "/userfs/godot/app_userdata/Brickworks";
    const request = indexedDB.open("/userfs", 21);
    request.onupgradeneeded = () => {
      const store = request.result.createObjectStore("FILE_DATA");
      store.createIndex("timestamp", "timestamp", { unique: false });
    };
    request.onsuccess = () => {
      const tx = request.result.transaction(["FILE_DATA"], "readwrite");
      const store = tx.objectStore("FILE_DATA");
      const now = Date.now();
      for (const dir of ["/userfs/godot", "/userfs/godot/app_userdata", base, `${base}/models`]) {
        store.put({ timestamp: new Date(now - 86400000), mode: 16895 }, dir);
      }
      for (const model of models) {
        const bytes = new TextEncoder().encode(model.text);
        store.put({ timestamp: new Date(now - model.ago * 1000), mode: 33206,
          contents: new Int8Array(bytes.buffer) }, `${base}/models/${model.name}.ldr`);
      }
      tx.oncomplete = () => { window.menufixShelved = models.length; };
    };
  }, shelf(saves));
}

// A page of its own, in a context of its own, where pictures are decoded and
// compared: none of it on the app's thread.
const labBrowser = await launch({ signedOut: true });
const lab = await labBrowser.newPage();
await lab.goto("about:blank");
await lab.evaluate(() => {
  const decode = async (b64, type) => {
    const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    const picture = await createImageBitmap(new Blob([bytes], { type }));
    const canvas = new OffscreenCanvas(picture.width, picture.height);
    const ctx = canvas.getContext("2d");
    ctx.drawImage(picture, 0, 0);
    return { w: picture.width, h: picture.height, data: ctx.getImageData(0, 0, picture.width, picture.height).data };
  };
  const at = (img, x, y) => (Math.round(y) * img.w + Math.round(x)) * 4;
  const gap = (a, b, i) => Math.abs(a.data[i] - b.data[i]) + Math.abs(a.data[i + 1] - b.data[i + 1])
    + Math.abs(a.data[i + 2] - b.data[i + 2]);
  const bright = (b, i) => 0.3 * b.data[i] + 0.59 * b.data[i + 1] + 0.11 * b.data[i + 2];
  // The panel a menu put on screen: the box of the lines and columns where
  // much changed between two pictures inside [area] (a tooltip or a lit row
  // beside it changes a few pixels a line, a panel a whole line).
  const panel = (a, b, area, limit = 24) => {
    const x0 = Math.max(0, area.x); const x1 = Math.min(a.w, area.x + area.w);
    const y0 = Math.max(0, area.y); const y1 = Math.min(a.h, area.y + area.h);
    const lines = [];
    let count = 0;
    for (let y = y0; y < y1; y++) {
      let line = 0;
      for (let x = x0; x < x1; x++) if (gap(a, b, at(a, x, y)) > limit) line += 1;
      lines.push(line);
      count += line;
    }
    // The first run of such lines, unbroken but for a line or two: whatever
    // else changed further down (the view, a banner) is not the panel.
    let top = -1; let bottom = -1; let quiet = 0;
    for (const [n, line] of lines.entries()) {
      if (line >= 30) {
        if (top < 0) top = n;
        bottom = n;
        quiet = 0;
      } else if (top >= 0 && ++quiet > 3) {
        break;
      }
    }
    if (top < 0) return { count };
    // Its columns, read in its lines alone.
    const columns = new Array(x1 - x0).fill(0);
    for (let y = y0 + top; y <= y0 + bottom; y++) {
      for (let x = x0; x < x1; x++) if (gap(a, b, at(a, x, y)) > limit) columns[x - x0] += 1;
    }
    let left = -1; let right = -1;
    columns.forEach((column, n) => { if (column >= 12) { if (left < 0) left = n; right = n; } });
    return { x: x0 + left, y: y0 + top, w: right - left + 1, h: bottom - top + 1, count };
  };
  // The rows of words in a panel, each with whether it may be pressed (its
  // words in the menu's own colour, look.gd ROW_WORDS, not GREYED), and the
  // lit row: the lines filled with ROW_LIT, the look's lit row.
  const rowsOf = (b, box) => {
    const rows = [];
    let start = -1; let most = 0;
    for (let y = box.y; y <= box.y + box.h; y++) {
      let words = 0;
      for (let x = box.x + 8; x < box.x + Math.min(box.w * 0.6, 240); x++) {
        const value = bright(b, at(b, x, y));
        if (value > 130) { words += 1; most = Math.max(most, value); }
      }
      if (words > 0 && start < 0) { start = y; }
      if (words === 0 && start >= 0) {
        if (y - start >= 4) rows.push({ y0: start, y1: y - 1, enabled: most > 225 });
        start = -1; most = 0;
      }
    }
    let ly0 = -1; let ly1 = -1;
    for (let y = box.y; y <= box.y + box.h; y++) {
      let lit = 0;
      for (let x = box.x; x < box.x + box.w; x++) {
        const i = at(b, x, y);
        if (Math.abs(b.data[i] - 33) <= 5 && Math.abs(b.data[i + 1] - 41) <= 5 && Math.abs(b.data[i + 2] - 56) <= 5) lit += 1;
      }
      if (lit >= 40) { if (ly0 < 0) ly0 = y; ly1 = y; }
    }
    return { rows, lit: ly0 >= 0 ? { y: ly0, h: ly1 - ly0 + 1 } : null };
  };
  window.lab = {
    // The open menu: what its picture has that the closed one has not,
    // below its button, and its rows.
    async menu(closed, open, button) {
      const a = await decode(closed, "image/png");
      const b = await decode(open, "image/png");
      const box = panel(a, b, { x: button.x0 - 6, y: button.y1 + 1, w: 520, h: 800 });
      if (box.w === undefined) return { box };
      return { box, ...rowsOf(b, box) };
    },
    // The submenu: the panel the picture with it has, right of the menu,
    // that the menu's own picture has not; its rows and its lit row.
    async submenu(base, now, menuBox) {
      const a = await decode(base, "image/png");
      const b = await decode(now, "image/png");
      const box = panel(a, b, { x: menuBox.x + menuBox.w + 1, y: 40, w: 460, h: 760 });
      if (box.w === undefined || box.w < 60 || box.h < 14) return { open: false, count: box.count };
      return { open: true, box, ...rowsOf(b, box) };
    },
    // The first screencast frame in which the submenu's place is drawn as
    // it ends up (the last frame), when the frame before the pointer came to
    // rest was not.
    async firstDrawn(before, frames, last, place) {
      const a = await decode(before, "image/jpeg");
      const z = await decode(last, "image/jpeg");
      const apart = (p, q) => {
        let count = 0;
        for (let y = place.y; y < place.y + place.h; y++) {
          for (let x = place.x; x < place.x + place.w; x++) if (gap(p, q, at(p, x, y)) > 60) count += 1;
        }
        return count / (place.w * place.h);
      };
      if (apart(a, z) < 0.05) return { n: -1, why: "the place looked the same before" };
      for (const [n, frame] of frames.entries()) {
        if (apart(await decode(frame, "image/jpeg"), z) < 0.03) return { n };
      }
      return { n: -1, why: "never drawn as it ended" };
    },
  };
});

// The page's frames as drawn, kept while a submenu is being timed.
const cdp = await page.context().newCDPSession(page);
let keeping = null;
let lastFrame = null;
cdp.on("Page.screencastFrame", async ({ data, metadata, sessionId }) => {
  const frame = { at: metadata.timestamp * 1000, data };
  lastFrame = frame;
  if (keeping) keeping.push(frame);
  cdp.send("Page.screencastFrameAck", { sessionId }).catch(() => {});
});

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
const controls = () => page.evaluate(() => window.brickworksControls || {});
const state = () => page.evaluate(() => window.brickworksState || {});
const results = [];
if (check("the app comes up", await until(page, async () => Boolean((await controls()).menu_file), START_MS / 1000))) {
  await until(page, async () => { const now = await state(); return now.bricks > 0 && now.awaited === 0; }, 120);
  if (saves > 0) check(`${saves} saved models on the shelf before the app started`,
    (await page.evaluate(() => window.menufixShelved || 0)) === saves);
  await page.waitForTimeout(3000);
  await cdp.send("Page.startScreencast", { format: "jpeg", quality: 80, maxWidth: 1280, maxHeight: 800, everyNthFrame: 1 });
  const where = await controlsWith(page, ["menu_file", "menu_edit", "menu_view"], 30000);
  const shut = async () => {
    for (let n = 0; n < 3; n++) {
      await page.keyboard.press("Escape");
      await page.waitForTimeout(150);
    }
    await page.mouse.move(640, 22);
    await caughtUp(page);
  };
  const shot = async () => (await page.screenshot()).toString("base64");
  const geometry = {};
  // Each menu opened by a click on its title, and its rows found.
  const openMenu = async (title) => {
    const button = where[`menu_${title.toLowerCase()}`];
    const edges = { x0: button.x - button.w / 2, y1: button.y + button.h / 2 };
    if (!geometry[title]) {
      // Found by what changes as it opens: a notice the app shows at the
      // same moment (its storage warning, with 50 models saved) changes
      // more, so a count that is not the menu's is looked at again.
      let found = {};
      let open = null;
      for (let attempt = 0; attempt < 3; attempt++) {
        await shut();
        await page.waitForTimeout(attempt ? 1500 : 0);
        const closed = await shot();
        await page.mouse.move(button.x, button.y);
        await page.mouse.click(button.x, button.y);
        await page.waitForTimeout(800);
        await caughtUp(page);
        open = await shot();
        found = await lab.evaluate(([a, b, e]) => window.lab.menu(a, b, e), [closed, open, edges]);
        if ((found.rows || []).length === MENUS[title].length) break;
      }
      writeFileSync(`${out}/${title}_menu.png`, Buffer.from(open, "base64"));
      check(`${title}: its menu has ${MENUS[title].length} rows (${(found.rows || []).length} found)`,
        (found.rows || []).length === MENUS[title].length);
      geometry[title] = { ...found, open };
    } else {
      await page.mouse.move(button.x, button.y);
      await page.mouse.click(button.x, button.y);
      await page.waitForTimeout(800);
      await caughtUp(page);
    }
    return { button, ...geometry[title] };
  };
  // Rest the pointer on a row (moved there from the menu's title, as a
  // person's hand comes down the menu) and time the submenu from then.
  const rest = async (title, row, menu) => {
    const index = MENUS[title].indexOf(row);
    const band = menu.rows[index];
    const at = { x: menu.box.x + 40, y: (band.y0 + band.y1) / 2 };
    keeping = [];
    await page.waitForTimeout(600);
    const before = lastFrame;
    const longFrom = Date.now();
    await page.mouse.move(at.x, at.y, { steps: 6 });
    const rested = Date.now();
    await page.waitForTimeout(6000);
    await caughtUp(page);
    const frames = keeping;
    keeping = null;
    const now = await shot();
    const sub = await lab.evaluate(([a, b, box]) => window.lab.submenu(a, b, box), [menu.open, now, menu.box]);
    let drawnMs = -1;
    if (sub.open && before && frames.length) {
      const place = { x: sub.box.x + 2, y: sub.box.y + 2, w: Math.min(160, sub.box.w - 4), h: Math.min(60, sub.box.h - 4) };
      const found = await lab.evaluate(([a, list, z, p]) => window.lab.firstDrawn(a, list, z, p),
        [before.data, frames.map((f) => f.data), frames[frames.length - 1].data, place]);
      if (found.n >= 0) drawnMs = Math.round(frames[found.n].at - rested);
      else console.log(`        (no frame timed: ${found.why}; ${frames.length} frames)`);
    }
    console.log(`        (menu ${JSON.stringify(menu.box)}; submenu ${JSON.stringify(sub.box || sub.count)}, `
      + `${(sub.rows || []).length} rows, enabled ${(sub.rows || []).filter((r) => r.enabled).length})`);
    const long = (await page.evaluate(() => window.menuLong || []))
      .filter(([start, ms]) => start + ms >= longFrom && start <= rested + Math.max(drawnMs, 0) + 50);
    const longest = long.reduce((most, [, ms]) => Math.max(most, ms), 0);
    return { at, sub, now, drawnMs, longest: Math.round(longest), frames: frames.length };
  };
  for (const [title, row] of tried) {
    console.log(`\n${title} › ${row}`);
    const result = { menu: title, row };
    results.push(result);
    let menu = await openMenu(title);
    if (!menu.rows || menu.rows.length !== MENUS[title].length) continue;
    // Straight: across the row into the submenu, then down to its third row.
    let rested = await rest(title, row, menu);
    result.drawnMs = rested.drawnMs;
    result.longestMs = rested.longest;
    writeFileSync(`${out}/${title}_${row.replace(/ /g, "_")}_open.png`, Buffer.from(rested.now, "base64"));
    if (!check(`${row}: opens with the pointer rested on it (${rested.drawnMs} ms to drawn, longest task `
      + `${rested.longest} ms)`, rested.sub.open && (!barMs || (rested.drawnMs >= 0 && rested.drawnMs <= barMs)))) {
      result.open = false;
      await shut();
      continue;
    }
    result.open = true;
    const sub = rested.sub;
    // Its third row that may be pressed (a greyed row is never lit), or the
    // last of fewer; with none, the pointer only has to keep it open.
    const pressable = sub.rows.filter((r) => r.enabled);
    const third = pressable.length ? pressable[Math.min(2, pressable.length - 1)] : sub.rows[0];
    const target = { x: sub.box.x + 40, y: (third.y0 + third.y1) / 2 };
    for (let n = 1; n <= 8; n++) {
      await page.mouse.move(rested.at.x + (sub.box.x + 30 - rested.at.x) * n / 8, rested.at.y);
      await page.waitForTimeout(30);
    }
    for (let n = 1; n <= 4; n++) {
      await page.mouse.move(sub.box.x + 30 + (target.x - sub.box.x - 30) * n / 4,
        rested.at.y + (target.y - rested.at.y) * n / 4);
      await page.waitForTimeout(30);
    }
    await page.waitForTimeout(1500);
    await caughtUp(page);
    let now = await shot();
    let after = await lab.evaluate(([a, b, box]) => window.lab.submenu(a, b, box), [menu.open, now, menu.box]);
    writeFileSync(`${out}/${title}_${row.replace(/ /g, "_")}_straight.png`, Buffer.from(now, "base64"));
    const litThird = (found) => {
      console.log(`        (pointer at ${Math.round(target.x)}, ${Math.round(target.y)}; submenu `
        + `${found.open ? "open" : "shut"}, lit ${JSON.stringify(found.lit || null)})`);
      return Boolean(found.open && (!pressable.length || (found.lit
        && Math.abs(found.lit.y + found.lit.h / 2 - target.y) < found.lit.h / 2 + 2)));
    };
    result.straight = check(`${row}: stays open as the pointer goes straight across and down to its third row, `
      + "which is lit", litThird(after));
    // Slanted: from the row to the third row in one line, over the rows below.
    await shut();
    menu = await openMenu(title);
    rested = await rest(title, row, menu);
    if (rested.sub.open) {
      for (let n = 1; n <= 8; n++) {
        await page.mouse.move(rested.at.x + (target.x - rested.at.x) * n / 8, rested.at.y + (target.y - rested.at.y) * n / 8);
        await page.waitForTimeout(30);
      }
      await page.waitForTimeout(1500);
      await caughtUp(page);
      now = await shot();
      after = await lab.evaluate(([a, b, box]) => window.lab.submenu(a, b, box), [menu.open, now, menu.box]);
      writeFileSync(`${out}/${title}_${row.replace(/ /g, "_")}_slant.png`, Buffer.from(now, "base64"));
    }
    result.slant = check(`${row}: stays open as the pointer goes on a slant to its third row, which is lit`,
      rested.sub.open && litThird(after));
    result.drawnMs2 = rested.drawnMs;
    result.longestMs2 = rested.longest;
    await shut();
  }
  // Open recent's row, pressed, opens its model.
  if (tried.some(([, row]) => row === "Open recent") && saves > 0) {
    const menu = await openMenu("File");
    const rested = menu.rows && menu.rows.length === MENUS.File.length
      ? await rest("File", "Open recent", menu) : { sub: { open: false } };
    // Its second row: the first is the model the app opened at the start.
    const before = await page.evaluate(() => document.title);
    if (rested.sub.open && rested.sub.rows.length > 1) {
      const first = rested.sub.rows[1];
      const target = { x: rested.sub.box.x + 40, y: (first.y0 + first.y1) / 2 };
      await page.mouse.move(target.x, rested.at.y, { steps: 6 });
      await page.mouse.move(target.x, target.y, { steps: 3 });
      await page.waitForTimeout(500);
      await page.mouse.click(target.x, target.y);
      const asked = await controlsWith(page, ["replace_discard"], 20000);
      if (asked.replace_discard) await page.mouse.click(asked.replace_discard.x, asked.replace_discard.y);
      // The page's title is the open model's name (Main._page_title).
      const named = await until(page, async () => (await page.evaluate(() => document.title)) !== before
        && (await state()).awaited === 0, 120);
      await caughtUp(page);
      writeFileSync(`${out}/open_recent_opened.png`, await page.screenshot());
      check(`Open recent's second row, clicked, opens its model ("${before}" then `
        + `"${await page.evaluate(() => document.title)}")`, named);
    } else {
      check("Open recent's second row, clicked, opens its model", false);
    }
  }
}
await cdp.send("Page.stopScreencast").catch(() => {});
const table = results.map((r) => `${label ? label + "  " : ""}${r.menu} › ${r.row}: drawn ${r.drawnMs ?? "-"} ms`
  + ` (again ${r.drawnMs2 ?? "-"}), longest task ${r.longestMs ?? "-"}/${r.longestMs2 ?? "-"} ms,`
  + ` straight ${r.straight ? "stays" : "CLOSED"}, slant ${r.slant ? "stays" : "CLOSED"}`).join("\n");
console.log(`\n${table}`);
writeFileSync(`${out}/results.json`, JSON.stringify({ url: url.split("?")[0], saves, label, results }, null, 2));
writeFileSync(`${out}/results.txt`, `${table}\n`);
check(`no script error thrown${thrown.length ? ": " + thrown.slice(0, 3).join(" | ") : ""}`, thrown.length === 0);
await labBrowser.close();
await browser.close();
console.log(failed ? `\nsubmenu flow: ${failed} checks failed` : "\nsubmenu flow: all checks passed");
process.exit(failed ? 1 : 0);
