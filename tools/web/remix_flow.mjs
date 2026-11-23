// What a remix changed, on its page, in a real browser (remixdiff,
// 2026-11-23): the line under its credit, What changed in its 3D view, and
// the Remixes tab's tree both ways.
//
//   node tools/web/remix_flow.mjs [--out=DIR] [--widths=390,1280]
//
// Nothing leaves this machine: the pages are made by this checkout's api/
// and every call is answered by design_stand_in.mjs, as model_page_flow.mjs
// does. Four models of its own are added to the stand-in, a chain of three
// remixes: Stone Cottage (Robin's, tests/fixtures/remix_pairs 09's
// original), Cottage with a Garden (Mika's, that pair's remix: one part
// added, one taken away, one recoloured and two moved, one of them turned),
// Cottage at Dusk (Jo's, five bricks more) and Winter Cottage (Priya's, a
// brick fewer). Each remix is counted by the same countRemix a publish runs
// (api/_remix.js), and kept in the stand-in's remix_changes.
//
// At 390 x 844 and 430 x 932 (phones, touch) and 1280 x 900:
//
//   1. The garden's page says its credit as before (Remixed from Stone
//      Cottage, by Robin Castell), and under it "What it changed
//      from version 1: 1 part added, 1 taken away, 1 recoloured, 2 moved",
//      the version a link to the original's, and See what changed in 3D.
//   2. View in 3D opens with What changed off: a toggle on the view's bar,
//      not pressed, every part in its own colour, no ghosts.
//   3. What changed on: exactly the parts the remix changed in their own
//      colours, on every surface (the lines of its file not in the
//      original's, by their place in its packing), every other part faded,
//      and the one taken away drawn as a ghost; the legend says the counts.
//      Off again: every part its own colour and no ghost; on again, the same.
//   4. See what changed in 3D, on a page fresh, opens the view with it on.
//   5. Cottage at Dusk's Remixes tab draws the line both ways: Stone
//      Cottage, then the garden, then itself (marked, no link), then Winter
//      Cottage under it; each card its line, a remix of a remix naming both.
//      Stone Cottage's draws its three levels down; Winter Cottage's its
//      three up.
//   6. The original's page counts its remixes as before (Remixes 1); the
//      stand-in's watchtower still lists its three.
//
// Pictures: DIR/line_<width>.png (the line with What changed on),
// DIR/tree_<width>.png (Cottage at Dusk's tree), DIR/off_<width>.png.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { fromRuns } from "../../api/_remix_changes.js";
import { PAIR, PAIRS, cottageWorld } from "./remix_world.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const out = path.resolve(String(args.out || "shots/remix"));
mkdirSync(out, { recursive: true });
// 430 x 932 as briefs/self_attack.md asks of a phone: what a press shows comes into view.
const widths = String(args.widths || "390,430,1280").split(",").map(Number);

let passed = 0;
let failed = 0;
const said = [];
const check = (what, ok) => {
  if (ok) passed += 1;
  else failed += 1;
  const line = `  ${ok ? "ok  " : "FAIL"}  ${what}`;
  said.push(line);
  console.log(line);
};
const until = (page, test, arg, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);

// ---------------------------------------------------------------------------
// The four models (remix_world.mjs), each remix counted.

const api = path.join(root, "api");
const { was, garden } = await cottageWorld(stand, api);
const kept = stand.remixChangesOf("CottageB01");
const want = JSON.parse(readFileSync(path.join(PAIRS, "expected.json"), "utf8"))[PAIR];
check(`counted as the app's Compare counts the pair: ${JSON.stringify(kept && { added: kept.added, removed: kept.removed, moved: kept.moved, recoloured: kept.recoloured, turned: kept.turned })}`,
  Boolean(kept) && Object.entries(want).every(([key, value]) => kept[key] === value));
check(`the two remixes of remixes counted too: ${["CottageC01", "CottageD01"].map((id) => {
  const r = stand.remixChangesOf(id);
  return r ? `${id} +${r.added} -${r.removed}` : `${id} none`;
}).join(", ")}`, stand.remixChangesOf("CottageC01")?.added === 5 && stand.remixChangesOf("CottageD01")?.removed === 1);

// Which parts the garden changed, from the two files alone: each part line
// of its main model not in the original's, by its place among the parts
// (the windows, the only sub-model, come after every line that changed).
const partLines = (text) => text.split("\n0 NOFILE")[0].split("\n").filter((line) => /^1 /.test(line));
const before = new Set(partLines(was));
const changedAt = partLines(garden).map((line, k) => (before.has(line) ? -1 : k)).filter((k) => k >= 0);
const lit = fromRuns([...kept.shown.added, ...kept.shown.recoloured, ...kept.shown.moved]).sort((a, b) => a - b);
check(`the lit parts kept are the lines the remix changed: ${JSON.stringify(lit)} = ${JSON.stringify(changedAt)}`,
  JSON.stringify(lit) === JSON.stringify(changedAt));

// ---------------------------------------------------------------------------
// In the browser.

const browser = await launch({ signedOut: true });
const errors = [];
async function pageAt(width) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: width === 430 ? 932 : phone ? 844 : 900 }, colorScheme: "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await stand.serveSite(context, { web: path.join(root, "web"), api });
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${width}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => { if (m.type() === "error" && !/Failed to load resource/.test(m.text())) errors.push(`${width}: ${m.text().slice(0, 200)}`); });
  return { page, context, phone };
}
const press = (page, phone, selector) => (phone ? page.tap(selector) : page.click(selector));
const changesNow = (page) => page.evaluate(() => (window.brickworks3d?.changes ? window.brickworks3d.changes() : null));
const ready = (page) => until(page, () => window.brickworks3d && (window.brickworks3d.state === "ready" || window.brickworks3d.state === "failed"), null, 240000);
const lineOf = (page) => page.evaluate(() => {
  const from = document.querySelector(".model-page .from");
  const line = document.querySelector(".model-page .remix-changes");
  return { credit: from?.textContent.replace(/\s+/g, " ").trim() || "", line: line?.textContent.replace(/\s+/g, " ").trim() || "",
    next: from?.nextElementSibling === line, version: line?.querySelector("a")?.getAttribute("href") || "",
    button: line?.querySelector(".what-changed") ? !line.querySelector(".what-changed").hidden : false };
});
const legendOf = (page) => page.evaluate(() => {
  const l = document.querySelector(".view3d-legend");
  return l && !l.hidden ? l.textContent : "";
});

for (const width of widths) {
  console.log(`width ${width}`);
  // 1-3: the garden's page, View in 3D, then What changed on and off.
  {
    const { page, context, phone } = await pageAt(width);
    await page.goto(`${stand.ORIGIN}/m/CottageB01`, { waitUntil: "load" });
    const line = await lineOf(page);
    check(`${width}: the credit as it was ("${line.credit}")`, line.credit === "Remixed from Stone Cottage, by Robin Castell");
    check(`${width}: under it "${line.line}"`, line.next
      && line.line === "What it changed from version 1: 1 part added, 1 taken away, 1 recoloured, 2 moved See what changed in 3D"
      && line.version === "/m/CottageA01/v/1" && line.button);
    await press(page, phone, ".model-page .picture .go");
    const came = await ready(page);
    const offFirst = await changesNow(page);
    const bar = await page.evaluate(() => {
      const b = document.querySelector('.view3d-tools [data-act="changes"]');
      const tools = document.querySelector(".view3d-tools")?.getBoundingClientRect();
      return { pressed: b?.getAttribute("aria-pressed"), name: b?.getAttribute("aria-label") || b?.textContent.trim(),
        inside: tools ? tools.left >= 0 && tools.right <= innerWidth + 0.5 : false, parts: window.brickworks3d.parts };
    });
    check(`${width}: View in 3D opens with What changed off (${bar.name}, pressed ${bar.pressed}): `
      + `${offFirst ? `${offFirst.lit.length} of ${bar.parts} in their own colours, ${offFirst.ghosts} ghosts` : "no view"}`,
    came && offFirst && !offFirst.on && bar.pressed === "false" && bar.name === "What changed"
      && offFirst.lit.length === bar.parts && offFirst.faded === 0 && offFirst.ghosts === 0);
    check(`${width}: the view's bar fits the screen with the toggle on it`, bar.inside);
    if (came) await page.screenshot({ path: path.join(out, `off_${width}.png`) });
    await press(page, phone, '.view3d-tools [data-act="changes"]');
    await until(page, () => window.brickworks3d.changes()?.ghosts > 0 || /could not/.test(document.querySelector(".view3d-legend")?.textContent || ""), null, 60000);
    await page.waitForTimeout(800);
    const on = await changesNow(page);
    const legend = await legendOf(page);
    check(`${width}: What changed on lights exactly the parts it changed (${JSON.stringify(on?.lit)}), fades the other ${on?.faded}, `
      + `and draws ${on?.ghosts} ghost`, on && on.on && JSON.stringify(on.lit) === JSON.stringify(changedAt)
      && on.faded === bar.parts - changedAt.length && on.ghosts === want.removed);
    check(`${width}: its legend says "${legend}"`, legend === "In colour: 1 added, 1 recoloured, 2 moved · faint red: 1 taken away");
    await page.evaluate(() => document.querySelector(".model-page .remix-changes")?.scrollIntoView({ block: "center" }));
    if (!phone) await page.evaluate(() => scrollTo(0, 0));
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(out, `line_${width}.png`) });
    console.log(`        picture: ${path.join(out, `line_${width}.png`)}`);
    await press(page, phone, '.view3d-tools [data-act="changes"]');
    await page.waitForTimeout(500);
    const off = await changesNow(page);
    check(`${width}: off again: every part its own colour, no ghost, the legend gone`,
      off && !off.on && off.lit.length === bar.parts && off.ghosts === 0 && (await legendOf(page)) === "");
    await press(page, phone, '.view3d-tools [data-act="changes"]');
    await page.waitForTimeout(800);
    const again = await changesNow(page);
    check(`${width}: on again, the same parts lit and the ghost back (asked of the site once: `
      + `${await page.evaluate(() => performance.getEntriesByType("resource").filter((r) => /changes\.json/.test(r.name)).length)} ask)`,
    again && JSON.stringify(again.lit) === JSON.stringify(changedAt) && again.ghosts === want.removed
      && (await page.evaluate(() => performance.getEntriesByType("resource").filter((r) => /changes\.json/.test(r.name)).length)) === 1);
    await context.close();
  }
  // 4: See what changed in 3D on a fresh page opens the view with it on.
  {
    const { page, context, phone } = await pageAt(width);
    await page.goto(`${stand.ORIGIN}/m/CottageB01`, { waitUntil: "load" });
    await press(page, phone, ".model-page .remix-changes .what-changed");
    const came = await ready(page);
    await until(page, () => window.brickworks3d.changes()?.ghosts > 0, null, 60000);
    const on = await changesNow(page);
    const pressed = await page.evaluate(() => document.querySelector('.view3d-tools [data-act="changes"]')?.getAttribute("aria-pressed"));
    check(`${width}: See what changed in 3D opens the view with it on (pressed ${pressed}, ${on?.lit.length} lit, ${on?.ghosts} ghost)`,
      came && on && on.on && pressed === "true" && JSON.stringify(on.lit) === JSON.stringify(changedAt) && on.ghosts === want.removed);
    // What the press shows is on the screen: the view, and its legend.
    const seen = await page.evaluate(() => {
      const box = (el) => { const r = el?.getBoundingClientRect(); return r ? [Math.round(r.top), Math.round(r.bottom)] : null; };
      return { view: box(document.querySelector(".model-page .view3d")), legend: box(document.querySelector(".view3d-legend")), height: innerHeight };
    });
    check(`${width}: the view it opens is on the screen (${JSON.stringify(seen.view)}, its legend ${JSON.stringify(seen.legend)}, of ${seen.height})`,
      seen.view && seen.legend && seen.legend[0] >= 0 && seen.legend[1] <= seen.height && seen.view[0] < seen.height && seen.view[1] > 0);
    await context.close();
  }
  // 5-6: the trees, and the counts as they were.
  {
    const { page, context } = await pageAt(width);
    const treeOf = () => page.evaluate(() => {
      const tree = document.querySelector("#remixes .remix-tree");
      if (!tree) return null;
      const depthOf = (el) => { let d = 0; for (let at = el.parentElement; at && at !== tree; at = at.parentElement) if (at.tagName === "OL") d += 1; return d; };
      return [...tree.querySelectorAll(".node-card")].map((card) => ({ name: card.querySelector(".name")?.textContent || "",
        change: card.querySelector(".change")?.textContent || "", self: card.classList.contains("self"),
        href: card.getAttribute("href") || "", depth: depthOf(card) }));
    });
    await page.goto(`${stand.ORIGIN}/m/CottageC01#remixes`, { waitUntil: "load" });
    const dusk = await treeOf();
    const names = (dusk || []).map((n) => `${n.depth}:${n.name}${n.self ? "*" : ""}`);
    check(`${width}: Cottage at Dusk's tree, both ways: ${names.join(" > ")}`,
      JSON.stringify(names) === JSON.stringify(["0:Stone Cottage", "1:Cottage with a Garden", "2:Cottage at Dusk*", "3:Winter Cottage"]));
    const card = (name) => (dusk || []).find((n) => n.name === name) || {};
    check(`${width}: each card its line, a remix of a remix naming both: "${card("Cottage at Dusk").change}"`,
      card("Cottage with a Garden").change === "A remix of Stone Cottage by Robin Castell: 1 part added, 1 taken away, 1 recoloured, 2 moved"
      && card("Cottage at Dusk").change === "A remix of Cottage with a Garden by Mika Tanaka, itself a remix of Stone Cottage: 5 parts added"
      && card("Winter Cottage").change === "A remix of Cottage at Dusk by Jo Lindqvist, itself a remix of Cottage with a Garden: 1 part taken away"
      && card("Cottage at Dusk").self && card("Cottage at Dusk").href === "" && card("Stone Cottage").href === "/m/CottageA01");
    await page.evaluate(() => document.querySelector("#remixes")?.scrollIntoView({ block: "start" }));
    await page.waitForTimeout(400);
    await page.locator("#remixes").screenshot({ path: path.join(out, `tree_${width}.png`) });
    console.log(`        picture: ${path.join(out, `tree_${width}.png`)}`);
    await page.goto(`${stand.ORIGIN}/m/CottageA01#remixes`, { waitUntil: "load" });
    const first = ((await treeOf()) || []).map((n) => `${n.depth}:${n.name}${n.self ? "*" : ""}`);
    check(`${width}: Stone Cottage's, three levels down: ${first.join(" > ")}`,
      JSON.stringify(first) === JSON.stringify(["0:Stone Cottage*", "1:Cottage with a Garden", "2:Cottage at Dusk", "3:Winter Cottage"]));
    const tabs = await page.evaluate(() => [...document.querySelectorAll(".model-page [role=tab], .model-page .tabs a")].map((t) => t.textContent.replace(/\s+/g, " ").trim()));
    check(`${width}: the original counts its remixes as before (${tabs.filter((t) => /^Remixes/.test(t)).join(", ")})`,
      tabs.some((t) => t === "Remixes 1"));
    await page.goto(`${stand.ORIGIN}/m/CottageD01#remixes`, { waitUntil: "load" });
    const last = ((await treeOf()) || []).map((n) => `${n.depth}:${n.name}${n.self ? "*" : ""}`);
    check(`${width}: Winter Cottage's, three levels up: ${last.join(" > ")}`,
      JSON.stringify(last) === JSON.stringify(["0:Stone Cottage", "1:Cottage with a Garden", "2:Cottage at Dusk", "3:Winter Cottage*"]));
    await page.goto(`${stand.ORIGIN}/m/${stand.MODEL_ID}#remixes`, { waitUntil: "load" });
    const watch = await page.evaluate(() => ({ tabs: [...document.querySelectorAll(".model-page [role=tab], .model-page .tabs a")].map((t) => t.textContent.replace(/\s+/g, " ").trim()),
      cards: [...document.querySelectorAll("#remixes .remix-tree .node-card")].map((c) => c.querySelector(".name")?.textContent || "") }));
    check(`${width}: the watchtower still counts its three (${watch.tabs.filter((t) => /^Remixes/.test(t)).join(", ")}) and draws its line: ${watch.cards.join(" > ")}`,
      watch.tabs.some((t) => t === "Remixes 3") && watch.cards.includes("Watchtower at Dusk") && watch.cards.includes("Riverside Watchtower"));
    await context.close();
  }
}
await browser.close();
for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
check(`no script error on any page (${errors.length})`, errors.length === 0);
writeFileSync(path.join(out, "result.txt"), `${said.join("\n")}\n`);
console.log(failed ? `remix flow: ${failed} of ${passed + failed} failed; pictures in ${out}`
  : `remix flow: all ${passed} passed; pictures in ${out}`);
process.exit(failed ? 1 : 0);
