// Copied in one tab, pasted in another (appwalk).
//
//   node --env-file=.env tools/web/relay_server.mjs 11803 --static=build/web &
//   node --env-file=.env tools/web/tabpaste_flow.mjs --url=http://127.0.0.1:11803/app [--out=shots/tabpaste]
//
// Each tab of the studio is an app of its own, with its own copy. On a
// desktop a copy goes on the system clipboard too, which every window reads;
// a browser lets a page write that only inside its own handling of a key, and
// Godot answers a key a frame later, so a copy there never left its tab:
// copied in one and pasted in another, the second said "nothing copied yet"
// (appwalk's returning builder, 2026-11-24). EditVerbs keeps the newest copy
// in the site's localStorage for every tab (brickworks.clipboard). In one
// window at 1280 x 800, signed in as this run's own account, two tabs on the
// example car:
//
//   1. tab A: a part clicked and Ctrl+C;
//   2. tab B, which copied nothing: Ctrl+V holds A's part, and a click puts
//      it down: one part more in B, selected, in A's part's colour;
//   3. tab B: a part of another colour copied; tab A: Ctrl+V holds B's, the
//      newer copy, not A's own: one part more in A, in B's part's colour;
//   4. tab A: a part copied again and pasted in A: its own copy, as before.
//
// Exits non-zero when a check fails.
import { askApp, framesDrawn, launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "");
if (!url) {
  console.log("tabpaste_flow: --url=<the app's address> is needed");
  process.exit(2);
}
const out = String(args.out || "shots/tabpaste");
mkdirSync(out, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}

const state = async (page) => (await page.evaluate(() => window.brickworksState || {}).catch(() => ({}))) || {};
const controls = async (page) => (await page.evaluate(() => window.brickworksControls || {}).catch(() => ({}))) || {};
const until = async (page, test, seconds = 20) => {
  for (let n = 0; n < seconds * 4; n++) {
    const s = await state(page);
    if (test(s)) return s;
    await page.waitForTimeout(250);
  }
  return state(page);
};
/// The app up in [page]: its header told and nothing still being read.
async function up(page) {
  for (let n = 0; n < 1200 && !(await controls(page)).app_header; n++) await page.waitForTimeout(250);
  await until(page, (s) => (s.awaited || 0) === 0 && s.mode === "select" && (s.bricks || 0) > 0, 180);
  await page.waitForFunction(() => document.getElementById("boot")?.classList.contains("done"), null,
    { timeout: 120000 }).catch(() => {});
  await framesDrawn(page, 3).catch(() => {});
}
/// The colour of the one part selected, -1 when not one.
const colour = (s) => (s.selected === 1 && (s.selected_colours || []).length ? s.selected_colours[0] : -1);
/// A part of the model on the screen in another colour than [not] clicked, alone: [part, colour].
async function select(page, not = -2) {
  await page.bringToFront();
  let laid = null;
  for (let n = 0; n < 3 && !(laid?.targets || []).length; n++) {
    laid = await askApp(page, "Layout", { seconds: 20, tellings: 8 }).catch(() => null);
  }
  const targets = laid?.targets || [];
  if (!targets.length) console.log("        (the app named no parts on the screen)");
  for (const t of targets.slice(0, 12)) {
    await page.keyboard.press("Escape");
    await framesDrawn(page, 2).catch(() => {});
    await page.mouse.click(t.x, t.y);
    const s = await until(page, (now) => now.selected === 1 && colour(now) >= 0, 12);
    if (colour(s) >= 0 && colour(s) !== not) return [String(t.part), colour(s)];
    console.log(`        (a ${t.part} at ${Math.round(t.x)},${Math.round(t.y)}: ${s.selected} selected, colour ${colour(s)})`);
  }
  return ["", -1];
}
/// The copy in hand put down on the floor in front of the model: the state after.
async function putDown(page) {
  const laid = await askApp(page, "Layout", { seconds: 6, tellings: 8 }).catch(() => null);
  const [x, y, w, h] = laid?.view || [480, 96, 780, 680];
  const before = (await state(page)).bricks || 0;
  for (const [fx, fy] of [[0.2, 0.85], [0.8, 0.85], [0.15, 0.6], [0.85, 0.6], [0.5, 0.92]]) {
    await page.mouse.click(x + w * fx, y + h * fy);
    const s = await until(page, (now) => (now.bricks || 0) > before && !now.carrying, 10);
    if ((s.bricks || 0) > before) return s;
  }
  return state(page);
}
async function paste(page) {
  await page.keyboard.press("Control+v");
  return until(page, (s) => s.carrying, 15);
}

const browser = await launch({ ownAccount: true });
try {
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
  const a = await context.newPage();
  await a.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(a);
  const b = await context.newPage();
  await b.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(b);
  await a.bringToFront();

  console.log("\n1. tab A copies a part");
  const [partA, colourA] = await select(a);
  await a.keyboard.press("Control+c");
  const copied = await until(a, (s) => /^copied/.test(String(s.said || "")), 6);
  check(`a part clicked in A (${partA || "none"}, colour ${colourA}) and copied: "${copied.said}"`,
    partA && /^copied 1 part/.test(String(copied.said)));
  await a.screenshot({ path: `${out}/1_a_copied.png` });

  console.log("\n2. tab B, which copied nothing, pastes it");
  await b.bringToFront();
  await b.keyboard.press("Escape");
  // A click on the sky above the model: the canvas has the keys, nothing selected.
  const sky = (await askApp(b, "Layout", { seconds: 6, tellings: 8 }).catch(() => null))?.view || [480, 96, 780, 680];
  await b.mouse.click(sky[0] + sky[2] * 0.1, sky[1] + sky[3] * 0.1);
  const beforeB = await state(b);
  const heldB = await paste(b);
  await b.screenshot({ path: `${out}/2_b_holding.png` });
  check(`Ctrl+V in B holds a copy: carrying ${heldB.carrying}, "${heldB.said}"`, heldB.carrying && /^holding 1 part/.test(String(heldB.said)));
  const putB = await putDown(b);
  await b.screenshot({ path: `${out}/3_b_put.png` });
  check(`...put down: ${beforeB.bricks} parts to ${putB.bricks}, the one put selected in colour ${colour(putB)} (A's ${colourA})`,
    putB.bricks === beforeB.bricks + 1 && colour(putB) === colourA);

  console.log("\n3. tab B copies another part; tab A pastes the newer copy");
  const [partB, colourB] = await select(b, colourA);
  await b.keyboard.press("Control+c");
  const copiedB = await until(b, (s) => /^copied/.test(String(s.said || "")), 6);
  check(`a ${partB || "part"} in colour ${colourB} copied in B: "${copiedB.said}"`,
    partB && /^copied 1 part/.test(String(copiedB.said)));
  await a.bringToFront();
  await a.keyboard.press("Escape");
  const beforeA = await state(a);
  const heldA = await paste(a);
  const putA = await putDown(a);
  await a.screenshot({ path: `${out}/4_a_put.png` });
  check(`Ctrl+V in A holds B's copy, not its own: ${beforeA.bricks} parts to ${putA.bricks}, the one put in colour `
    + `${colour(putA)} (B's ${colourB}, A's ${colourA})`,
    heldA.carrying && putA.bricks === beforeA.bricks + 1 && colour(putA) === colourB);

  console.log("\n4. tab A copies its own part again and pastes it");
  const [again, colourOwn] = await select(a, colourB);
  await a.keyboard.press("Control+c");
  await until(a, (s) => /^copied/.test(String(s.said || "")), 6);
  const beforeOwn = await state(a);
  const heldOwn = await paste(a);
  const putOwn = await putDown(a);
  await a.screenshot({ path: `${out}/5_a_own.png` });
  check(`its own copy of a ${again}: ${beforeOwn.bricks} parts to ${putOwn.bricks}, in colour ${colour(putOwn)} (${colourOwn})`,
    heldOwn.carrying && putOwn.bricks === beforeOwn.bricks + 1 && colour(putOwn) === colourOwn);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  the flow stopped: ${trouble.stack || trouble}`);
} finally {
  await browser.close();
}
console.log(`\ntabpaste_flow: ${failed ? `${failed} failed` : "all passed"}`);
process.exit(failed ? 1 : 0);
