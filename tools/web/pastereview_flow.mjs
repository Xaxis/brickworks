// pastereview: attacks on appwalk's paste across tabs (099695588), run on a
// local relay serving a web export (branch or base). Not for the suite.
//
//   node tools/web/pastereview_flow.mjs --url=http://127.0.0.1:PORT/app --out=DIR
//        --model=vendor/omr/files/7140-1.mpd --unpacked=756,30365,... [--width=1280|390]
//
// One window, signed in as this run's own account. Tab A opens the X-wing
// (7140-1), tab B keeps the example car: two tabs with different models.
//   1. A copies one part the web pack lacks (fetched over the network in A
//      only); B pastes it and puts it down; the parts B gains, its autosave,
//      a reload; then undo.
//   2. A copies a packed part and an unpacked one together; B pastes.
//   3. B copies a car part; A pastes: which copy comes.
//   4. A copy made "yesterday" (localStorage set by hand) pasted in a fresh tab.
//   5. Signed out and in as a second throwaway account in the same browser
//      (the session swapped as web/account.js signOut + a sign-in do): paste.
//   6. A context whose storage refuses the clipboard key: copy and paste in
//      one tab, then in another.
//   7. The browser's localStorage quota, measured.
//
// appfix (the review's fixes judged on it): a paste that says it is fetching
// its parts' shapes is waited on until it holds them; case 5 signs out with
// the site's own signOut, and then puts the first account's copy back by hand
// to show the second account reads none of it. In 7140-1 each unpacked part
// is in a minifig a click takes whole (appwalk), so cases 1 and 1b copy that
// minifig: B gains all its parts as one sub-assembly, as A has it.
import { askApp, framesDrawn, launch, openFromFile } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "");
const out = String(args.out || "shots/pastereview");
const width = Number(args.width || 1280);
const height = width < 600 ? 844 : 800;
const model = String(args.model || "");
const unpacked = new Set(String(args.unpacked || "").split(",").filter(Boolean));
mkdirSync(out, { recursive: true });
const KEY = "brickworks.clipboard";
const record = {};

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}
const note = (what) => console.log(`  NOTE  ${what}`);

const state = async (page) => (await page.evaluate(() => window.brickworksState || {}).catch(() => ({}))) || {};
const controls = async (page) => (await page.evaluate(() => window.brickworksControls || {}).catch(() => ({}))) || {};
const account = async (page) => (await page.evaluate(() => window.brickworksAccount || {}).catch(() => ({}))) || {};
const until = async (page, test, seconds = 20) => {
  for (let n = 0; n < seconds * 4; n++) {
    const s = await state(page);
    if (test(s)) return s;
    await page.waitForTimeout(250);
  }
  return state(page);
};
async function up(page) {
  for (let n = 0; n < 1200 && !(await controls(page)).app_header; n++) await page.waitForTimeout(250);
  await until(page, (s) => (s.awaited || 0) === 0 && s.mode === "select" && (s.bricks || 0) > 0, 240);
  await page.waitForFunction(() => document.getElementById("boot")?.classList.contains("done"), null,
    { timeout: 120000 }).catch(() => {});
  await framesDrawn(page, 3).catch(() => {});
}
const colour = (s) => ((s.selected_colours || []).length ? s.selected_colours[0] : -1);
const shot = (page, name) => page.screenshot({ path: `${out}/${name}.png`, timeout: 90000 }).catch(() => {});
const clip = (page) => page.evaluate((k) => { try { return localStorage.getItem(k); } catch (e) { return `(threw ${e.name})`; } }, KEY);

/// Layout targets on the screen: [{x, y, part}].
async function targets(page) {
  let laid = null;
  for (let n = 0; n < 3 && !(laid?.targets || []).length; n++) {
    laid = await askApp(page, "Layout", { seconds: 20, tellings: 8 }).catch(() => null);
  }
  return { targets: laid?.targets || [], view: laid?.view || [480, 96, 780, 680] };
}
/// One part clicked alone whose part id passes [want]: {part, colour, x, y} or null.
/// A part clicked alone: {part, colour, x, y, count: 1}. With [whole], where
/// every such part is in a sub-assembly a click takes whole (each of 7140-1's
/// unpacked parts is in a minifig: appwalk), the first such sub-assembly
/// instead: {part, colour: null, count: its parts, whole: true}.
async function pick(page, want, tried = new Set(), whole = false) {
  await page.bringToFront();
  const { targets: all } = await targets(page);
  const wholes = [];
  for (const t of all) {
    const part = String(t.part);
    if (!want(part) || tried.has(`${Math.round(t.x)},${Math.round(t.y)}`)) continue;
    tried.add(`${Math.round(t.x)},${Math.round(t.y)}`);
    await page.keyboard.press("Escape");
    await framesDrawn(page, 2).catch(() => {});
    await page.mouse.click(t.x, t.y);
    const s = await until(page, (now) => now.selected >= 1, 10);
    if (s.selected === 1) return { part, colour: colour(s), x: t.x, y: t.y, count: 1 };
    console.log(`        (a ${part} at ${Math.round(t.x)},${Math.round(t.y)} selected ${s.selected})`);
    if (s.selected > 1 && s.selected < 40) wholes.push({ part, x: t.x, y: t.y });
  }
  if (whole && wholes.length) {
    const t = wholes[0];
    await page.keyboard.press("Escape");
    await framesDrawn(page, 2).catch(() => {});
    await page.mouse.click(t.x, t.y);
    const s = await until(page, (now) => now.selected > 1, 10);
    console.log(`        (no ${[...new Set(wholes.map((w) => w.part))].join(" ")} alone: the sub-assembly a click on one takes, ${s.selected} parts)`);
    return { part: t.part, colour: null, x: t.x, y: t.y, count: s.selected, whole: true };
  }
  console.log(`        (no target among ${all.length} passed: ${[...new Set(all.map((t) => t.part))].slice(0, 30).join(" ")})`);
  return null;
}
/// A put-down's words for a sub-assembly put down whole (Main's status:
/// "<name> selected, N parts — double-click edits inside a sub-assembly").
const wholeSaid = (s) => /selected, \d+ parts — double-click edits inside/.test(String(s.said || ""));
async function sky(page) {
  const { view } = await targets(page);
  await page.keyboard.press("Escape");
  await page.mouse.click(view[0] + view[2] * 0.08, view[1] + view[3] * 0.08);
  await framesDrawn(page, 2).catch(() => {});
}
async function copy(page) {
  await page.keyboard.press("Control+c");
  return until(page, (s) => /^copied/.test(String(s.said || "")), 10);
}
async function paste(page) {
  await page.keyboard.press("Control+v");
  const s = await until(page, (s) => s.carrying || /nothing copied|clipboard|could not paste/.test(String(s.said || "")), 20);
  // appfix: a paste waits for its parts' shapes, said ("fetching 3 parts to
  // paste"), and holds them once they are here: waited on while it says so.
  if (!s.carrying && /^fetching .* to paste/.test(String(s.said || ""))) {
    console.log(`        (waiting: "${s.said}")`);
    return until(page, (now) => now.carrying || !/^fetching .* to paste/.test(String(now.said || "")), 180);
  }
  return s;
}
/// The copy in hand put down in front of the model: the state after.
async function putDown(page, count = 1) {
  const { view } = await targets(page);
  const [x, y, w, h] = view;
  const before = (await state(page)).bricks || 0;
  for (const [fx, fy] of [[0.2, 0.85], [0.8, 0.85], [0.15, 0.6], [0.85, 0.6], [0.5, 0.92]]) {
    await page.mouse.move(x + w * fx, y + h * fy, { steps: 4 });
    await framesDrawn(page, 3).catch(() => {});
    await page.mouse.click(x + w * fx, y + h * fy);
    const s = await until(page, (now) => (now.bricks || 0) >= before + count && !now.carrying, 10);
    if ((s.bricks || 0) > before || !s.carrying) return s;
  }
  return state(page);
}
/// Every user:// file in this origin's IndexedDB whose path ends [suffix]: {path: text}.
const files = (page, suffix) => page.evaluate((end) => new Promise((done) => {
  const asked = indexedDB.open("/userfs");
  asked.onerror = () => done({});
  asked.onsuccess = () => {
    const out = {};
    try {
      const cursor = asked.result.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").openCursor();
      cursor.onsuccess = (e) => {
        const c = e.target.result;
        if (!c) { done(out); return; }
        const key = String(c.key);
        const v = c.value && c.value.contents;
        if (key.endsWith(end) && v && ArrayBuffer.isView(v)) {
          out[key] = new TextDecoder().decode(new Uint8Array(v.buffer, v.byteOffset, v.byteLength));
        }
        c.continue();
      };
      cursor.onerror = () => done(out);
    } catch { done(out); }
  };
}), suffix);
const tabId = (page) => page.evaluate(() => window.brickworksTab || sessionStorage.getItem("brickworks.tab") || "").catch(() => "");
/// How many lines of this tab's autosave place [part] (in [colourCode] when given), and the file's part lines.
async function inAutosave(page, part, colourCode = null) {
  await page.waitForTimeout(7000);
  const all = await files(page, "autosave.ldr");
  const id = await tabId(page);
  const mine = Object.entries(all).filter(([k]) => !id || k.includes(id));
  const text = mine.length ? mine[0][1] : "";
  const lines = text.split("\n").filter((l) => /^\s*1\s/.test(l));
  const hits = lines.filter((l) => l.trim().toLowerCase().endsWith(` ${part.toLowerCase()}.dat`)
    && (colourCode === null || l.trim().split(/\s+/)[1] === String(colourCode)));
  return { files: Object.keys(all).length, mine: mine.map(([k]) => k), parts: lines.length, hits: hits.length };
}

const browser = await launch({ ownAccount: true });
const second = `delivered+bw-pastereview-b-${process.pid}-${Date.now().toString(36)}@resend.dev`;
let secondMade = false;
try {
  // A, which opens a file through File, at 1280 always; every other tab at --width.
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
  let pages = 0;
  context.on("page", (page) => {
    pages += 1;
    if (pages > 1 && width !== 1280) page.setViewportSize({ width, height }).catch(() => {});
  });
  const choosers = [];
  const a = await context.newPage();
  await a.setViewportSize({ width: 1280, height: 800 });
  a.on("filechooser", (c) => choosers.push(c));
  a.choosers = choosers;
  await a.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(a);
  const b = await context.newPage();
  await b.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(b);
  const carParts = (await state(b)).bricks;
  console.log(`  (A and B up at ${width}x${height}; B holds the car, ${carParts} parts; base or branch: `
    + `localStorage ${KEY} ${JSON.stringify(await clip(a))})`);

  console.log("\n0. A opens a different model");
  await a.bringToFront();
  const chooser = await openFromFile(a, null, { choosers, shots: out, optional: true });
  if (chooser) await chooser.setFiles(model, { timeout: 300000 });
  const opened = await until(a, (s) => s.bricks !== carParts && (s.awaited || 0) === 0, 300);
  // Its parts come over the network: drawn, then the whole model fitted (F).
  await a.waitForTimeout(12000);
  await a.keyboard.press("Escape");
  await a.keyboard.press("f");
  await a.waitForTimeout(4000);
  check(`A opened ${model.split("/").pop()}: ${opened.bricks} parts; B still the car`,
    opened.bricks !== carParts && (await state(b)).bricks === carParts);
  await shot(a, `0_a_opened_${width}`);

  console.log("\n1. A copies a part the web pack lacks; B pastes it");
  const tried = new Set();
  const one = await pick(a, (p) => unpacked.has(p), tried, true);
  const count1 = one?.count || 1;
  const what1 = one?.whole ? `the sub-assembly holding a ${one.part} (${count1} parts)` : `a ${one?.part}`;
  const copied1 = await copy(a);
  const text1 = await clip(a);
  check(`A copied ${what1} (colour ${one?.colour}), unpacked in the web build: "${copied1.said}"; `
    + `localStorage holds ${text1 === null ? "nothing" : JSON.stringify(String(text1).slice(0, 80))}`,
    one && new RegExp(`^copied ${count1} parts?`).test(String(copied1.said)));
  await b.bringToFront();
  await sky(b);
  const before1 = await state(b);
  const held1 = await paste(b);
  await b.waitForTimeout(1500);
  await shot(b, `1_b_holding_${width}`);
  const put1 = await putDown(b);
  await shot(b, `1_b_put_${width}`);
  const gained1 = (put1.bricks || 0) - (before1.bricks || 0);
  record.case1 = { part: one?.part, said_held: held1.said, carrying: held1.carrying, said_put: put1.said, gained: gained1 };
  check(`B: Ctrl+V "${held1.said}" (carrying ${held1.carrying}); put down: "${put1.said}"; B ${before1.bricks} -> ${put1.bricks} parts `
    + (one?.whole ? `(want +${count1}, one sub-assembly as in A)` : `(want +1), selected colour ${colour(put1)} (A's ${one?.colour})`),
    gained1 === count1 && (one?.whole ? wholeSaid(put1) : colour(put1) === one?.colour));
  const saved1 = await inAutosave(b, one?.part || "", one?.colour);
  check(`B's autosave places the ${one?.part} in colour ${one?.colour} ${saved1.hits} time(s) (want 1; ${saved1.parts} part lines, `
    + `${saved1.mine.join(" ")})`, saved1.hits === 1);
  // Undo the paste.
  await b.keyboard.press("Control+z");
  const undone1 = await until(b, (s) => s.bricks === before1.bricks, 10);
  check(`undo after the paste: B back to ${undone1.bricks} parts (want ${before1.bricks}): "${undone1.said}"`,
    undone1.bricks === before1.bricks);
  // The same paste again, a few seconds on: the part's shape may have come by now.
  await sky(b);
  const again1 = await paste(b);
  await b.waitForTimeout(1500);
  const putAgain1 = await putDown(b);
  const gainedAgain = (putAgain1.bricks || 0) - (undone1.bricks || 0);
  record.case1_again = { said_held: again1.said, said_put: putAgain1.said, gained: gainedAgain };
  note(`B pastes it again ${Math.round(3)} s on: "${again1.said}", put down "${putAgain1.said}", +${gainedAgain} part(s)`);
  await shot(b, `1_b_again_${width}`);
  // Reopened: B reloaded restores its tab's model.
  const beforeReload = (await state(b)).bricks;
  await b.waitForTimeout(4000);
  await b.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await up(b);
  const reloaded = await state(b);
  check(`B reloaded: ${reloaded.bricks} parts (had ${beforeReload})`, reloaded.bricks === beforeReload);

  // From here B's network is slow for part shapes (a phone on a poor line):
  // each .lbm answered 6 s late. A's is not.
  const SLOW_MS = 6000;
  await b.route("**/*.lbm", async (route) => {
    await new Promise((done) => setTimeout(done, SLOW_MS));
    await route.continue().catch(() => {});
  });
  console.log(`\n1b. B's part shapes ${SLOW_MS / 1000} s slow: A copies another unpacked part; B pastes it and puts it down 1.5 s on`);
  const oneB = await pick(a, (p) => unpacked.has(p) && (p !== one?.part || one?.whole), tried, true);
  const count1b = oneB?.count || 1;
  const copied1b = await copy(a);
  await b.bringToFront();
  await sky(b);
  const had1b = oneB?.whole ? (await inAutosave(b, oneB.part, oneB.colour)).hits : 0;
  const before1b = await state(b);
  const held1b = await paste(b);
  await b.waitForTimeout(1500);
  await shot(b, `1b_b_holding_${width}`);
  const put1b = await putDown(b);
  await shot(b, `1b_b_put_${width}`);
  await b.waitForTimeout(SLOW_MS + 4000);
  const later1b = await state(b);
  const saved1b = await inAutosave(b, oneB?.part || "", oneB?.colour);
  record.case1b = { part: oneB?.part, said_held: held1b.said, said_put: put1b.said,
    gained: (put1b.bricks || 0) - (before1b.bricks || 0), later: (later1b.bricks || 0) - (before1b.bricks || 0), saved: saved1b.hits };
  // B's file had case 1's sub-assembly already: its part written in a
  // definition another copy may share, so at least as often as before.
  check(`A copied ${oneB?.whole ? `the sub-assembly holding a ${oneB.part} (${count1b} parts)` : `a ${oneB?.part}`} "${copied1b.said}"; `
    + `B: "${held1b.said}", put down "${put1b.said}": `
    + `+${(put1b.bricks || 0) - (before1b.bricks || 0)} at once, +${(later1b.bricks || 0) - (before1b.bricks || 0)} ${(SLOW_MS + 4000) / 1000} s later, `
    + `in B's autosave ${saved1b.hits} time(s) (want +${count1b} and ${oneB?.whole ? `at least ${Math.max(1, had1b)}, one sub-assembly` : "1"})`,
    oneB && later1b.bricks === before1b.bricks + count1b
      && (oneB.whole ? saved1b.hits >= Math.max(1, had1b) && wholeSaid(put1b) : saved1b.hits === 1));
  await shot(b, `1b_b_later_${width}`);

  console.log("\n2. B still slow: A copies all its parts (a packed 2 x 4, and unpacked parts B has never had); B pastes");
  // Whatever B still holds from 1b put away first.
  await b.bringToFront();
  await b.keyboard.press("Escape");
  await b.keyboard.press("Escape");
  await a.bringToFront();
  await a.keyboard.press("Escape");
  await a.keyboard.press("Control+a");
  const sel2 = await until(a, (s) => s.selected >= 2, 8);
  const copied2 = await copy(a);
  const text2 = String(await clip(a) || "");
  const lines2 = text2.split("\n").filter((l) => /^1 /.test(l));
  const two = { part: lines2.map((l) => l.split(/\s+/).pop().replace(/\.dat$/, ""))
    .find((p) => unpacked.has(p) && p !== one?.part && p !== oneB?.part) };
  check(`A copied all (${sel2.selected} selected): "${copied2.said}"; the kept copy places `
    + `${lines2.map((l) => l.split(/\s+/).pop()).join(" ")}`, lines2.length >= 2);
  const wanted2 = lines2.length;
  await b.bringToFront();
  await sky(b);
  // How often B's file wrote that part before: 7140-1's is in the minifigs
  // cases 1 and 1b put down.
  const had2 = two?.part ? (await inAutosave(b, two.part)).hits : 0;
  const before2 = await state(b);
  const held2 = await paste(b);
  await b.waitForTimeout(1500);
  await shot(b, `2_b_holding_${width}`);
  const put2 = await putDown(b, wanted2);
  await shot(b, `2_b_put_${width}`);
  const gained2 = (put2.bricks || 0) - (before2.bricks || 0);
  record.case2 = { parts: lines2.map((l) => l.split(/\s+/).pop()), said_held: held2.said, said_put: put2.said, gained: gained2 };
  check(`B: "${held2.said}"; put down "${put2.said}"; B ${before2.bricks} -> ${put2.bricks} (want +${wanted2})`,
    gained2 === wanted2);
  await b.waitForTimeout(SLOW_MS);
  const later2 = await state(b);
  const saved2 = await inAutosave(b, two?.part || "");
  record.case2.later = (later2.bricks || 0) - (before2.bricks || 0);
  check(`B's autosave places the unpacked ${two?.part} ${saved2.hits} time(s) (want ${had2 ? `at least the ${had2} it had` : "1"}); `
    + `+${record.case2.later} parts ${SLOW_MS / 1000} s after the put-down (want +${wanted2})`,
    (had2 ? saved2.hits >= had2 : saved2.hits === 1) && record.case2.later === wanted2);
  await b.unroute("**/*.lbm");

  console.log("\n3. B copies a car part; A pastes: the newest copy");
  const carPart = await pick(b, () => true);
  const copied3 = await copy(b);
  await a.bringToFront();
  await sky(a);
  const before3 = await state(a);
  const held3 = await paste(a);
  const put3 = await putDown(a);
  check(`B copied a ${carPart?.part} (colour ${carPart?.colour}) "${copied3.said}"; A pastes "${held3.said}" and puts down `
    + `"${put3.said}": +${(put3.bricks || 0) - (before3.bricks || 0)}, colour ${colour(put3)}`,
    (put3.bricks || 0) - (before3.bricks || 0) === 1 && colour(put3) === carPart?.colour);

  console.log("\n5. signed out, and in as another account, in the same browser (B's car part is the copy kept)");
  const c = await context.newPage();
  await c.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(c);
  const other = await mintSession(second, { age: true });
  secondMade = true;
  // appfix: the site's own signOut (web/account.js), not a copy of what it
  // removed before: the copy's key is one of what it removes now.
  const firstCopy = await clip(c);
  const signedOut = await c.evaluate(async () => {
    try {
      (await import("/account.js")).signOut();
      return "web/account.js signOut";
    } catch (e) {
      return `(no signOut: ${e.message})`;
    }
  });
  console.log(`        (signed out by ${signedOut})`);
  record.firstCopy = firstCopy;
  const leftBehind = await c.evaluate(([session, value]) => {
    // A sign-in's keep().
    const kept = localStorage.getItem("brickworks.clipboard");
    localStorage.setItem(session, value);
    return kept;
  }, [STORAGE_KEY, JSON.stringify(other.kept)]);
  await c.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
  await up(c);
  for (let n = 0; n < 120 && (await account(c)).email !== second; n++) await c.waitForTimeout(500);
  const who = await account(c);
  await sky(c);
  const before5 = await state(c);
  const held5 = await paste(c);
  const put5 = await putDown(c, 2);
  record.case5 = { signed_in_as: who.email, left_behind: leftBehind, said_held: held5.said,
    gained: (put5.bricks || 0) - (before5.bricks || 0) };
  check(`after sign-out the first account's copy is gone from the browser: ${leftBehind === null ? "gone" : `still there (${String(leftBehind).length} chars)`}`,
    leftBehind === null);
  check(`signed in as ${who.email === second ? "the second account" : who.email}: Ctrl+V "${held5.said}", put down +${(put5.bricks || 0) - (before5.bricks || 0)} `
    + `(want nothing of the first account's copy)`, !held5.carrying);
  await shot(c, `5_c_other_account_${width}`);
  // appfix: the first account's copy put back by hand, as a browser that
  // kept it would have it: the second account still reads none of it.
  if (firstCopy) {
    await c.keyboard.press("Escape");
    await c.evaluate(([k, v]) => localStorage.setItem(k, v), [KEY, firstCopy]);
    const before5c = await state(c);
    const held5c = await paste(c);
    const put5c = await putDown(c, 1);
    check(`the first account's copy kept by hand (${String(firstCopy).slice(0, 60)}…): the second account's Ctrl+V `
      + `"${held5c.said}", +${(put5c.bricks || 0) - (before5c.bricks || 0)} (want nothing)`,
      !held5c.carrying && (put5c.bricks || 0) === (before5c.bricks || 0));
  }

  console.log("\n4. a copy from yesterday pasted in a fresh tab");
  const yesterday = "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n";
  await c.evaluate(([k, v]) => localStorage.setItem(k, v), [KEY, yesterday]);
  const e = await context.newPage();
  await e.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(e);
  await sky(e);
  const before4 = await state(e);
  const held4 = await paste(e);
  const put4 = await putDown(e, 2);
  record.case4 = { said_held: held4.said, gained: (put4.bricks || 0) - (before4.bricks || 0) };
  note(`a fresh tab E, nothing copied in it, Ctrl+V: "${held4.said}"; put down +${(put4.bricks || 0) - (before4.bricks || 0)} `
    + `(the two red/blue 2 x 4s of a copy kept from any earlier day: localStorage keeps it until the next copy)`);
  await shot(e, `4_e_stale_${width}`);

  console.log("\n6. storage that refuses the clipboard key");
  const refusing = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  await refusing.addInitScript((k) => {
    const set = Storage.prototype.setItem;
    const get = Storage.prototype.getItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === k) throw new DOMException("refused", "QuotaExceededError");
      return set.call(this, key, value);
    };
    Storage.prototype.getItem = function (key) {
      if (key === k) throw new DOMException("refused", "SecurityError");
      return get.call(this, key);
    };
  }, KEY);
  const d1 = await refusing.newPage();
  await d1.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(d1);
  const mineD = await pick(d1, () => true);
  const copiedD = await copy(d1);
  await sky(d1);
  const beforeD = await state(d1);
  const heldD = await paste(d1);
  const putD = await putDown(d1);
  check(`D1 copies a ${mineD?.part} "${copiedD.said}" and pastes its own copy: "${heldD.said}", +${(putD.bricks || 0) - (beforeD.bricks || 0)}, `
    + `colour ${colour(putD)} (${mineD?.colour})`, (putD.bricks || 0) - (beforeD.bricks || 0) === 1 && colour(putD) === mineD?.colour);
  const d2 = await refusing.newPage();
  await d2.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await up(d2);
  await sky(d2);
  const heldD2 = await paste(d2);
  note(`D2 (same refusing storage) Ctrl+V: "${heldD2.said}", carrying ${heldD2.carrying}`);
  await refusing.close();

  console.log("\n7. the localStorage quota");
  const quota = await a.evaluate(() => {
    const k = "brickworks.pastereview.quota";
    let lo = 0;
    let hi = 64 * 1024 * 1024;
    while (hi - lo > 1024) {
      const mid = Math.floor((lo + hi) / 2);
      try { localStorage.setItem(k, "x".repeat(mid)); lo = mid; } catch { hi = mid; }
      localStorage.removeItem(k);
    }
    let used = 0;
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      used += key.length + (localStorage.getItem(key) || "").length;
    }
    return { most: lo, used };
  });
  record.quota = quota;
  note(`one more key could hold ${quota.most} characters; the site's keys already hold ${quota.used}`);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  the flow stopped: ${trouble.stack || trouble}`);
} finally {
  writeFileSync(`${out}/record.json`, JSON.stringify(record, null, 2));
  if (secondMade) console.log(`  (second account deleted: ${await deleteAccount(second).catch((e) => e.message)})`);
  await browser.close();
}
console.log(`\npastereview_flow: ${failed ? `${failed} failed` : "all passed"}`);
process.exit(failed ? 1 : 0);
