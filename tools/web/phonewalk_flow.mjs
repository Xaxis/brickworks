// The walk by finger (APP_UX8, unit 6, phonewalk): the acts of the desktop
// walk (docs/app_ux8/appux_walk.gd), done on a phone at 390 x 844 (three
// device pixels to the point) and a tablet at 1024 x 768 (two), with touch
// events alone, in SwiftShader, each counted in taps beside the presses the
// desktop needs for it. A measure: what a finger cannot do is the finding,
// named with the file its touch belongs in. The table it writes is the brief
// for phonepanels (the page editor, Motions and Simulate) and fingertools
// (Measure and the handles).
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 8811 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/phonewalk_flow.mjs --url=http://127.0.0.1:8811/ --out=shots/phonewalk
//   BW_BYPASS=… node tools/web/phonewalk_flow.mjs --url=<preview>/app --out=DIR
//
// --sizes=390x844,1024x768 (the default); --only=wall,measure,… runs those
// acts alone; --bar fails unless every act run is done by finger in no more
// than twice the desktop's presses, touching no control under 44 points
// across (phonepanels' and fingertools' bar).
//
// The run signs in as an account of its own, made for it and deleted at its
// end or when it is stopped (launch's ownAccount, session.mjs), and each size
// walks four models:
//
//   the car     the first visit's model (models/car.ldr, 61 parts): a part
//               to the last step, Render, a booklet page, Like this, Check
//               stability, Cut away, My collection, Measure, and the page
//               editor (opened from the timeline, an item moved, resized,
//               words added, Done)
//   empty       New: a 2 x 4 plate split and merged, then turned 15°; New
//               again: the wall of eight 1 x 4s from the search, three of
//               them painted
//   1484-1      its doors (vendor/omr/files): Motions…, the suggested
//               motion kept and played, a motion recorded by dragging a part
//               in the view, a joint set by its slider
//   an orrery   two planets on a gear train (src/dev/fixtures): Simulate,
//               Play, the cycle scrubbed, another part made the driver
//
// What is counted is what a person who knows where a command is would do:
// a tap, a finger held, a drag and each key of the on-screen keyboard is
// one, as the walk counts a click and a key. A More row is More, its menu's
// name and the row, and each drag the list needed to bring the row into
// sight; the menus the flow opens to find which one a row is under are not
// counted. Opening a model and putting the screen back between acts are not
// counted either. Taps that missed (a part not put down, a drag that took
// nothing) are counted, and said.
//
// Every act's result is read from the app (window.brickworksState,
// brickworksMotions, brickworksSimulate, the downloads, the booklet's tab
// and, asked, what the screen shows: window.brickworksPhone), never from a
// picture. A picture of each act's end goes to --out, <size>_<nn>_<act>.png.
// The table goes to --out/phonewalk.md and phonewalk.json, and is printed.
//
// Exits 0 when every act ran at every size and the table was written; 1 when
// the app never came up, an act could not run at all (it threw or ran out of
// time), or, with --bar, an act was not done or took over twice the presses.
import { askApp, clickStill, launch, START_MS } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8811/");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(String(args.out || "shots/phonewalk"));
const SIZES = String(args.sizes || "390x844,1024x768").split(",");
const ONLY = args.only ? String(args.only).split(",") : null;
const BAR = Boolean(args.bar);
// The most one act may take, setup included: past it the act is said to
// have run out of time and the walk goes on to the next.
const ACT_MS = Number(args["act-ms"] || 10 * 60 * 1000);
const DOORS = resolve("vendor/omr/files/1484-1.mpd");
const ORRERY = resolve("src/dev/fixtures/orrery_two_planets.ldr");
const CAR = resolve("models/car.ldr");
mkdirSync(out, { recursive: true });

// The acts, in the order walked, with the desktop's presses for each: the
// walk's own count where it measured the act (APP_UX8's table), otherwise
// the desktop's keys (src/ui/keymap.gd) and menus (Shell.MENUS), counted as
// the walk counts. [file] is where the act's touch belongs: named in the
// table only when a finger cannot do it, or needs over twice the presses.
const ACTS = [
  { id: "step_to", model: "car", what: "a part to the last step", desktop: 5,
    how: "the part clicked, Alt+T, the step's 2 digits, Enter (walk `round3`: 4 after the click)",
    file: "src/ui/steps_bar.gd (ask_step_to's dialog)" },
  { id: "render", model: "car", what: "Render: a picture made", desktop: 2, how: "F9, Picture",
    file: "src/ui/render_dialog.gd" },
  { id: "booklet", model: "car", what: "a booklet page: Instructions, its pages in a tab", desktop: 1, how: "Alt+B",
    file: "src/net/booklet_tab.gd" },
  { id: "like_this", model: "car", what: "Like this: parts like the one selected", desktop: 2,
    how: "the part clicked, the bin's Like this (walk `round3`)", file: "src/ui/parts_bin.gd (the Like this chip)" },
  { id: "stability", model: "car", what: "Check stability", desktop: 1, how: "Alt+K",
    file: "src/ui/shell.gd (_check_stability)" },
  { id: "cut", model: "car", what: "Cut away, its plane moved", desktop: 2, how: "K, the strip's slider dragged",
    file: "src/ui/see_inside.gd" },
  { id: "collection", model: "car", what: "My collection", desktop: 2, how: "File, My collection…",
    file: "src/ui/collection_dialog.gd" },
  { id: "measure", model: "car", what: "Measure: two points of the car", desktop: 3, how: "U, two clicks",
    file: "src/ui/measure.gd (fingertools)" },
  { id: "page_open", model: "car", what: "the page editor opened on a step", desktop: 2,
    how: "B (the timeline), Lay out the page…", file: "src/ui/page_editor.gd, src/ui/steps_bar.gd (booklet_lay_out)" },
  { id: "page_move", model: "car", needs: "page_open", what: "the page editor: an item dragged", desktop: 1, how: "a drag",
    file: "src/ui/page_editor.gd (_gui_input of an item)" },
  { id: "page_resize", model: "car", needs: "page_open", what: "the page editor: an item resized by its corner", desktop: 1, how: "a drag",
    file: "src/ui/page_editor.gd (the corner handle)" },
  { id: "page_words", model: "car", needs: "page_open", what: "the page editor: words added", desktop: 3, how: "Add words, \"Hi\" typed",
    file: "src/ui/page_editor.gd (page_add_text, page_words)" },
  { id: "page_done", model: "car", needs: "page_open", what: "the page editor: Done", desktop: 1, how: "Done",
    file: "src/ui/page_editor.gd (page_done)" },
  { id: "split_merge", model: "empty", what: "a 2 x 4 plate split, and merged back", desktop: 4,
    how: "the plate clicked, Alt+S; Ctrl+A, Alt+M (walk `round2`: 1 key each)",
    file: "src/ui/phone_shell.gd (a part's actions)" },
  { id: "turn", model: "empty", what: "a turn of 15°", desktop: 5,
    how: "the toolbar's turn step, 15° (2 clicks); the part clicked, R, a click (walk `turns`: 2 after the click)",
    file: "src/ui/phone_shell.gd (Turn turns by the turn step, 90°; only src/ui/toolbar.gd's chooser sets it), src/ui/inspector.gd (Properties' Turn, in the drawer)" },
  { id: "wall", model: "wall", what: "a wall of eight 1 x 4s from the search", desktop: 20,
    how: "a click in the search, \"1x4 brick\" (9 keys), the tile, 8 clicks, Esc (walk `wall`)",
    file: "src/main.gd (a tap puts the part in hand down)" },
  { id: "paint", model: "wall", needs: "wall", what: "three of them painted", desktop: 4,
    how: "a click, two Shift-clicks, Shift+5 (walk `round2`: 1 key after the clicks)",
    file: "src/main.gd, src/ui/edit_verbs.gd (a tap in Select replaces the selection: no adding to it by finger)" },
  { id: "motions_play", model: "doors", what: "Motions: the suggested motion kept and played", desktop: 3,
    how: "Alt+O, Keep, Play", file: "src/ui/pose_panel.gd" },
  { id: "motions_record", model: "doors", needs: "motions_play", what: "Motions: a motion recorded by dragging a part", desktop: 4,
    how: "New motion, Record, a door dragged, Stop",
    file: "src/ui/pose_panel.gd (recording through Grab in the view), src/main.gd (_on_phone_hold: a finger held 480 ms is the part's actions)" },
  { id: "motions_slider", model: "doors", needs: "motions_play", what: "Motions: a joint set by its slider", desktop: 1, how: "a drag",
    file: "src/ui/pose_panel.gd (the joints' sliders)" },
  { id: "simulate_play", model: "orrery", what: "Simulate: played", desktop: 2, how: "Alt+U, Play",
    file: "src/ui/simulate_panel.gd" },
  { id: "simulate_scrub", model: "orrery", needs: "simulate_play", what: "Simulate: the cycle scrubbed", desktop: 1, how: "the slider dragged",
    file: "src/ui/simulate_panel.gd (simulate_scrub)" },
  { id: "simulate_drive", model: "orrery", needs: "simulate_play", what: "Simulate: another part made the driver", desktop: 1,
    how: "a click on it", file: "src/ui/simulate_panel.gd (_on_selection), src/main.gd (a tap's selection)" },
];
// An act that goes on from another (the page editor's, Motions' and
// Simulate's go on in the panel the first opened) brings it along.
const named = new Set(ONLY || ACTS.map((act) => act.id));
for (const act of ACTS) if (named.has(act.id) && act.needs) named.add(act.needs);
const wanted = ACTS.filter((act) => named.has(act.id));
// Where an act done in over twice the presses only for being three taps deep
// in More belongs: More's rows (a command on a part's actions, or a row of its own).
const MORE_FILE = "src/ui/phone_shell.gd (More: every command is More, its menu and its row)";
// The least a target a finger takes may be across, in points: the size the
// phone's own targets keep (src/ui/touch_sizing.gd), and phonepanels' bar.
const MIN_POINTS = 44;
// The panel an act leaves open for the next, which goes on in it: the screen
// is put back only after the last of them.
const goesOn = (act, next) => Boolean(next && (next.needs === act.id || (act.needs && next.needs === act.needs)));
if (!wanted.length) {
  console.log(`no act is named ${ONLY}; the acts are ${ACTS.map((a) => a.id).join(", ")}`);
  process.exit(1);
}

const t0 = Date.now();
// PHONEWALK_DEBUG=1 says where each panel's control was as it was brought
// into sight.
const DEBUG = Boolean(process.env.PHONEWALK_DEBUG);
const said = (line) => console.log(`  --    ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
const results = {};
let broken = 0;

// Signed in as an account of the run's own (session.mjs), deleted when the
// browser closes or the run is stopped: the walk saves, likes and adds to a
// collection, which the shared test account should not carry.
const browser = await launch({ ownAccount: true });
try {
  for (const size of SIZES) {
    const [width, height] = size.split("x").map(Number);
    const ratio = Math.min(width, height) < 600 ? 3 : 2;
    console.log(`\n${width} x ${height} at ${ratio}x, by a finger`);
    results[size] = { up: false, rows: {} };
    await walk(width, height, ratio, results[size]).catch((trouble) => {
      broken += 1;
      console.log(`  FAIL  the walk at ${size} stopped: ${trouble.stack || trouble}`);
    });
  }
} finally {
  await browser.close();
}

// The table, both sizes side by side.
const lines = [
  `# The walk by finger`,
  ``,
  `Written by tools/web/phonewalk_flow.mjs on ${new Date().toISOString().slice(0, 16)}Z against ${url}`,
  `(${SIZES.map((s) => `${s.replace("x", " x ")}`).join(" and ")}, touch alone, SwiftShader).`,
  `A tap, a finger held, a drag and a key of the on-screen keyboard each count one;`,
  `a More row is More, its menu and the row. ✓ done by finger, ✗ not; "small": a control it took`,
  `is under ${MIN_POINTS} points across (named, width x height).`,
  ``,
  `| act | desktop | ${SIZES.map((s) => `${s.replace("x", " x ")}`).join(" | ")} | what stops a finger, and its file |`,
  `|---|---|${SIZES.map(() => "---").join("|")}|---|`,
];
const verdicts = [];
for (const act of wanted) {
  const cells = [];
  const stops = [];
  for (const size of SIZES) {
    const row = results[size]?.rows?.[act.id];
    if (!row) {
      cells.push("not reached");
      stops.push(`${size}: not reached`);
      verdicts.push({ act: act.id, size, done: false, over: false, ran: false });
      continue;
    }
    const over = row.done && row.taps > act.desktop * 2;
    const small = row.small || [];
    cells.push(`${row.done ? "✓" : "✗"} ${row.taps}${over ? " (over 2x)" : ""}${small.length ? ` (${small.length} small)` : ""}`);
    const smallSaid = small.length ? `${row.done && !over ? "done, but " : ""}under ${MIN_POINTS} points: ${small.join(", ")}` : "";
    if (!row.done || over || small.length) stops.push(`${size}: ${[!row.done || over ? row.why : "", smallSaid].filter(Boolean).join("; ")}`);
    verdicts.push({ act: act.id, size, done: row.done, over, small: small.length > 0, ran: row.ran });
  }
  // Over twice only for More's three taps: the fix is More's, not the act's.
  const viaMore = SIZES.every((size) => {
    const row = results[size]?.rows?.[act.id];
    return !row || (row.done && row.more);
  });
  const file = stops.length ? `${stops.join("; ")} — **${viaMore ? MORE_FILE : act.file}**` : "";
  lines.push(`| ${act.what} | ${act.desktop}: ${act.how} | ${cells.join(" | ")} | ${file} |`);
}
lines.push("", "## What each act did", "");
for (const size of SIZES) {
  lines.push(`### ${size.replace("x", " x ")}`, "");
  for (const act of wanted) {
    const row = results[size]?.rows?.[act.id];
    if (row) lines.push(`- **${act.id}** (${row.taps} taps, ${row.seconds} s): ${row.said.join("; ")}`);
  }
  lines.push("");
}
const table = lines.join("\n");
writeFileSync(`${out}/phonewalk.md`, `${table}\n`);
writeFileSync(`${out}/phonewalk.json`, `${JSON.stringify({ url, sizes: SIZES, acts: wanted, results }, null, 1)}\n`);
console.log(`\n${table}`);

const ran = verdicts.filter((v) => v.ran).length;
const notRun = verdicts.filter((v) => !v.ran);
const short = verdicts.filter((v) => !v.done || v.over || v.small);
console.log(`\n${ran} of ${verdicts.length} acts ran; ${verdicts.filter((v) => v.done).length} done by finger, `
  + `${verdicts.filter((v) => v.over).length} of them in over twice the desktop's presses; `
  + `${verdicts.filter((v) => v.small).length} took a control under ${MIN_POINTS} points; `
  + `the table is ${out}/phonewalk.md`);
if (broken || notRun.length) {
  console.log(`FAIL  the walk did not run: ${notRun.map((v) => `${v.act} at ${v.size}`).join(", ")}`);
  process.exit(1);
}
if (BAR && short.length) {
  console.log(`FAIL  --bar: ${short.map((v) => `${v.act} at ${v.size} (${!v.done ? "not done" : v.over ? "over twice" : "small targets"})`).join(", ")}`);
  process.exit(1);
}
console.log("every act of the walk was tried by a finger at every size");
process.exit(0);

// -- one size ---------------------------------------------------------------------

async function walk(width, height, ratio, result) {
  const size = `${width}x${height}`;
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: ratio,
    isMobile: true, hasTouch: true, acceptDownloads: true });
  const rows = result.rows;
  try {
    if (!browser.testAccount) throw new Error("no account to sign in (source .env)");
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
    });
    // Caught from the start: Playwright holds a chooser only while something
    // listens for one (browser.mjs, openFromFile).
    const choosers = [];
    page.on("filechooser", (chooser) => choosers.push(chooser));
    const cdp = await context.newCDPSession(page);
    const P = person(page, cdp, width, height, size, choosers);

    await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
    if (!(await P.where("phone_parts", START_MS / 1000))) {
      await P.picture("never");
      throw new Error("the layout for a finger never came up (no phone_parts)");
    }
    await P.until((s) => (s.awaited || 0) === 0 && s.mode, 300);
    const wide = Boolean((await P.ask())?.phone?.wide);
    result.up = true;
    result.wide = wide;
    said(`laid out ${wide ? "wide, for a tablet" : "for a phone"}; ${(await P.state()).bricks} parts open`);
    await P.picture("ready");

    let model = "";
    for (const [n, act] of wanted.entries()) {
      if (act.model !== model) {
        await P.untimed(() => P.openModel(act.model));
        model = act.model;
      }
      const began = Date.now();
      P.begin(act.id);
      let result;
      try {
        result = await Promise.race([
          P.run(act.id),
          new Promise((done) => setTimeout(() => done({ done: false, timedOut: true }), ACT_MS)),
        ]);
      } catch (trouble) {
        result = { done: false, threw: String(trouble.stack || trouble).slice(0, 400) };
      }
      const tally = P.end();
      // Drags that brought a row or a panel's control into sight, when the
      // act says nothing else of its extra taps.
      if (result.done && !result.slow && tally.brought.length) {
        const by = {};
        for (const name of tally.brought) by[name] = (by[name] || 0) + 1;
        result.slow = `${Object.entries(by).map(([name, n]) => `${n} drag${n > 1 ? "s" : ""} to bring ${name} into sight`).join(", ")}`
          + ` (a phone's sheet or panel shows a few rows at a time)`;
      }
      const ranOk = !result.threw && !result.timedOut;
      const over = result.done && tally.n > act.desktop * 2;
      // [slow]: what an act done by finger spent its extra taps on, when it
      // was not only More's three.
      const why = result.threw ? `it could not run: ${result.threw.split("\n")[0]}`
        : result.timedOut ? `it ran out of time (${Math.round(ACT_MS / 1000)} s)`
          : over ? `${tally.n} taps for the desktop's ${act.desktop}${tally.more
            ? `, the command three taps deep in More (${tally.said.filter((l) => / the row$/.test(l)).join("; ")})` : ""}`
            + (result.slow ? `; ${result.slow}` : "")
            : result.done ? "" : (result.why || tally.said.at(-1) || "");
      const small = Object.entries(tally.small).map(([name, at]) => `${name} ${at.w} x ${at.h}`);
      rows[act.id] = { done: Boolean(result.done), taps: tally.n, ran: ranOk, why, small,
        more: Boolean(tally.more) && !result.slow && !small.length,
        said: tally.said, seconds: Math.round((Date.now() - began) / 1000) };
      console.log(`  ${result.done ? "done" : ranOk ? "NOT " : "FAIL"}  ${act.id}: ${act.what}: ${tally.n} taps `
        + `(the desktop ${act.desktop})${result.done ? "" : ` — ${why}`}`
        + `${small.length ? `; under ${MIN_POINTS} points: ${small.join(", ")}` : ""}  [${Math.round((Date.now() - t0) / 1000)}s]`);
      await P.picture(act.id).catch(() => {});
      if (!goesOn(act, wanted[n + 1])) {
        await P.untimed(() => P.tidy()).catch((trouble) => said(`tidying after ${act.id}: ${trouble.message}`));
      }
    }
    result.errors = errors;
    said(`script errors: ${errors.length}${errors.length ? ` (${errors[0]})` : ""}`);
  } finally {
    await context.close().catch(() => {});
  }
}

// -- a person at the screen ---------------------------------------------------------

function person(page, cdp, width, height, size, choosers) {
  let shot = 0;
  // The act being counted: its taps and what it said, or null between acts.
  let tally = null;
  const count = (n = 1) => { if (tally) tally.n += n; };
  const note = (line) => {
    if (tally) tally.said.push(line);
    said(line);
  };
  const picture = async (what) => {
    shot += 1;
    await page.screenshot({ path: `${out}/${size}_${String(shot).padStart(2, "0")}_${what}.png`, timeout: START_MS });
  };
  const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
  const read = async (key) => (await page.evaluate((k) => window[k] || {}, key)) || {};
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  const until = async (test, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const s = await state();
      if (test(s)) return s;
      await page.waitForTimeout(250);
    }
    return state();
  };
  const untilRead = async (key, test, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const s = await read(key);
      if (test(s)) return s;
      await page.waitForTimeout(250);
    }
    return read(key);
  };
  const where = async (name, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const at = (await controls())[name];
      if (at) return { ...at, name };
      await page.waitForTimeout(250);
    }
    return null;
  };
  const ask = () => askApp(page, "Phone");
  const layout = () => askApp(page, "Layout");
  const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
    touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
  // A named control a finger takes under 44 points across (the size the
  // phone's own targets keep, TouchSizing): said in the act's row, as a
  // target a person misses.
  const aim = (at) => {
    if (!tally || !at?.name || !at.w || !at.h || Math.min(at.w, at.h) >= MIN_POINTS) return;
    const was = tally.small[at.name];
    if (!was || Math.min(at.w, at.h) < Math.min(was.w, was.h)) tally.small[at.name] = { w: Math.round(at.w), h: Math.round(at.h) };
  };
  const tap = async (at) => {
    count();
    aim(at);
    await page.touchscreen.tap(at.x, at.y);
    await page.waitForTimeout(600);
  };
  const tapBox = (box) => tap({ x: box[0] + box[2] / 2, y: box[1] + box[3] / 2 });
  // A finger held still until something comes (a part's actions), as a
  // person holds: a frame drawn in software under load can take longer than
  // the hold itself (phone_flow).
  const hold = async (at, opens = true) => {
    count();
    await touch("touchStart", [at]);
    for (let n = 0; n < 10; n++) {
      await page.waitForTimeout(500);
      if (!opens || n >= 2 && ((await ask())?.phone?.sheets || []).some((t) => !["Parts", "Colour", "More"].includes(t))) break;
    }
    await touch("touchEnd", []);
    await page.waitForTimeout(700);
  };
  // One finger dragged from a to b, [still] ms held at its end before it
  // lifts, as a person stops a list or a slider where they want it.
  const drag = async (a, b, steps = 14, still = 300) => {
    count();
    await touch("touchStart", [a]);
    for (let n = 1; n <= steps; n++) {
      await touch("touchMove", [{ x: a.x + (b.x - a.x) * n / steps, y: a.y + (b.y - a.y) * n / steps }]);
      await page.waitForTimeout(40);
    }
    if (still) await page.waitForTimeout(still);
    await touch("touchEnd", []);
    await page.waitForTimeout(700);
  };
  // Keys of the on-screen keyboard: one each, as the walk counts a key.
  const keys = async (text) => {
    count(text.length);
    await page.keyboard.type(text, { delay: 40 });
    await page.waitForTimeout(400);
  };
  const key = async (name) => {
    count();
    await page.keyboard.press(name);
    await page.waitForTimeout(400);
  };
  // The words a field shows, as the app says it draws them.
  const fieldText = async (field) => (((await ask())?.texts || []).find((t) => field
    && Math.abs(t.box[0] + t.box[2] / 2 - field.x) < field.w / 2
    && Math.abs(t.box[1] + t.box[3] / 2 - field.y) < field.h / 2) || {}).text || "";
  // [text] typed over what a field holds, as a person does on a phone: the
  // field tapped first when no keyboard is up for it, and typed in. Its
  // words selected, as the app draws them, are typed over; when the typing
  // went on the end of them instead, the person sees it and takes the field's
  // words out with the delete key, a press a letter (a phone's keyboard has
  // no select-all key), and types again, every press counted.
  // {tapped, held, cleared, words}: what it held, the deletes, what it reads.
  const typeOver = async (field, text) => {
    const tapped = !((await ask())?.typing || []).length;
    if (tapped) await tap(field);
    const held = await fieldText(field);
    await keys(text);
    let words = await fieldText(field);
    let cleared = 0;
    if (words && words !== text) {
      // Emptied a letter at a time, then typed again (an empty field shows
      // its placeholder, which the app reads out as its words).
      for (let i = 0; i < words.length; i++) await key("Backspace");
      cleared = words.length;
      await keys(text);
      words = await fieldText(field);
    }
    return { tapped, held, cleared, words };
  };
  // A control pressed where it has come to rest (browser.mjs clickStill).
  // Brought into sight first when it is past the screen's edge (reach).
  const press = async (name, seconds = 30) => {
    const first = await where(name, seconds);
    if (first && (first.y + first.h / 2 > height || first.y - first.h / 2 < 0)) await reach(name, 2);
    const at = first && await clickStill(page, name, { find: (n) => where(n, 5), optional: true, act: tap });
    if (!at) note(`"${name}" is not on the screen`);
    return Boolean(at);
  };
  // A row of the sheet it is in brought into sight by a finger's drags, as
  // a person scrolls a part's actions to Move to step… under the screen's
  // foot, and read again once it stands still (Main._page_places). Each drag
  // is counted. Its place, or null when it is not there.
  const reach = async (name, seconds = 10) => {
    let at = await where(name, seconds);
    for (let n = 0; at && n < 8; n++) {
      const named = await controls();
      // The panel the row is in: the one over its x nearest it (a row past
      // the fold, above or below, is outside its panel's box).
      const off = ([, v]) => Math.max(0, (v.y - v.h / 2) - at.y, at.y - (v.y + v.h / 2));
      const panel = Object.entries(named).filter(([k, v]) => k.startsWith("phone_panel_")
        && Math.abs(v.x - at.x) <= v.w / 2).sort((a, b) => off(a) - off(b))[0];
      const head = panel ? named[panel[0].replace("phone_panel_", "phone_sheet_")] : null;
      const box = panel ? panel[1] : { x: width / 2, y: height / 2, w: width, h: height };
      const top = Math.max(0, head ? head.y + head.h / 2 : box.y - box.h / 2) + 4;
      const bottom = Math.min(height, box.y + box.h / 2) - 4;
      if (at.y - at.h / 2 >= top && at.y + at.h / 2 <= bottom) return at;
      const span = (bottom - top) * 0.6;
      const by = at.y + at.h / 2 > bottom ? -Math.min(at.y + at.h / 2 - bottom + 30, span)
        : Math.min(top - (at.y - at.h / 2) + 30, span);
      const from = by < 0 ? bottom - 12 : top + 12;
      await drag({ x: box.x, y: from }, { x: box.x, y: from + by }, 16, 400);
      if (tally) tally.brought.push(name);
      at = await where(name, 5);
    }
    return at;
  };
  // A row of a sheet tapped once it is in sight.
  const pressRow = async (name) => {
    const at = await reach(name);
    if (!at) {
      note(`"${name}" is not on the screen`);
      return false;
    }
    return press(name, 5);
  };
  // A control of a panel whose list scrolls under its title (Motions,
  // Simulate): on a phone the panel is short, and its list shows a row or
  // two between its title and its foot. Dragged a little at a time, from
  // just under the title, until the control is between the title and the
  // bar at the screen's foot; every drag counted. [top] names the panel's
  // Close, in its title. Its place, or null.
  const bringIn = async (name, top, tries = 6) => {
    // The list's foot: Motions' rows under it (Render animation) stand
    // still while it scrolls; else the bar at the screen's foot.
    const named = await controls();
    const under = top === "motions_close" ? named.motions_render : null;
    const bar = named.phone_parts;
    const floor = under ? under.y - under.h / 2 - 8 : bar ? bar.y - bar.h / 2 : height;
    const first = await where(top, 5);
    // The panel's top: under its title while the title stays (Motions'
    // list scrolls beneath it), or where the title was once the whole panel
    // scrolls (Simulate's goes up with its list).
    const was = first ? first.y - first.h / 2 : height * 0.4;
    let stuck = 0;
    for (let n = 0; ; n++) {
      const at = await where(name, n ? 4 : 15);
      const head = await where(top, 2);
      const ceiling = head && Math.abs(head.y - first.y) < 2 ? head.y + head.h / 2 : was;
      if (DEBUG) said(`bringIn ${name}: at ${at ? `${Math.round(at.x)},${Math.round(at.y)} ${at.w}x${at.h}` : "none"}; ceiling ${Math.round(ceiling)}, floor ${Math.round(floor)}`);
      if (at && at.y - at.h / 2 >= ceiling - 1 && at.y + at.h / 2 <= floor + 1) return at;
      if (n >= tries) return null;
      // From the middle of the shown part, up or down, as a person swipes a
      // list; across, a little further each time a drag moved nothing (it
      // began on a button, which keeps the finger). The panel runs from the
      // screen's left to its Close (on a tablet it is a column at the left).
      const up = !at || at.y > ceiling;
      const right = head ? Math.min(width, head.x + head.w / 2) : first ? Math.min(width, first.x + first.w / 2) : width;
      const from = { x: right * [0.5, 0.2, 0.8][stuck % 3], y: (ceiling + floor) / 2 };
      await drag(from, { x: from.x, y: from.y + (up ? -1 : 1) * height * 0.045 }, 14, 400);
      if (tally) tally.brought.push(name);
      const moved = await where(name, 2);
      if (at && moved && Math.abs(moved.y - at.y) < 2) {
        stuck += 1;
        note(`a drag from ${Math.round(from.x)}, ${Math.round(from.y)} moved ${name}'s list nothing`);
      }
      if (DEBUG) await picture(`bring_${name}_${n}`);
    }
  };
  // Such a control tapped once in sight, and again if [test] says the first
  // tap did not take. True once it took.
  const pressIn = async (name, top, test) => {
    for (let n = 0; n < 2; n++) {
      const at = await bringIn(name, top);
      if (!at) break;
      await tap(at);
      if (await test()) return true;
    }
    note(`"${name}" never took a tap in its panel`);
    return false;
  };
  const sheets = async () => (await ask())?.phone?.sheets || [];
  // What the screen shows, asked of the app: its targets and words.
  const shown = async () => (await ask()) || { targets: [], texts: [], dialogs: [] };
  // Not counted: setting up, and putting the screen back.
  const untimed = async (body) => {
    const was = tally;
    tally = null;
    try {
      return await body();
    } finally {
      tally = was;
    }
  };

  // A row of More: More opened, the row's menu opened (the menus the flow
  // looks under to find it are not counted, as a person knows where it is),
  // the list dragged until the row is in sight, and the row tapped. As
  // dialogs_flow.mjs's more(), which has been run at every size.
  const more = async (row) => {
    const counted = tally;
    let opened = false;
    tally = null;
    let drags = 0;
    let menuOpened = false;
    try {
      for (let n = 0; n < 3 && !(await sheets()).includes("More"); n++) {
        if (n === 2) {
          await page.keyboard.press("Escape");
          await page.waitForTimeout(800);
        }
        await press("phone_more");
        opened = true;
        await page.waitForTimeout(600);
      }
      const head = await where("phone_sheet_more", 5);
      const panel = await where("phone_panel_more", 5);
      if (!head || !panel) return false;
      const MENUS = [];
      const sectionsNow = async () => Object.entries(await controls())
        .filter(([k]) => k.startsWith("phone_section_"))
        .sort((a, b) => a[1].y - b[1].y).map(([k]) => k.slice("phone_section_".length));
      for (let n = 0, last = ""; n < 60; n++) {
        const names = await sectionsNow();
        if (names.length && names.join() === last) { MENUS.push(...names); break; }
        last = names.join();
        await page.waitForTimeout(250);
      }
      const rowsNow = async () => Object.entries(await controls()).filter(([k]) => k.startsWith("phone_row_"));
      const told = async (test) => {
        for (let n = 0; n < 60; n++) {
          if (await test()) return true;
          await page.waitForTimeout(250);
        }
        return false;
      };
      const openMenu = async () => {
        const named = await controls();
        const rows = Object.entries(named).filter(([k]) => k.startsWith("phone_row_"));
        if (!rows.length) return null;
        const top = Math.min(...rows.map(([, at]) => at.y));
        const above = MENUS.filter((m) => named[`phone_section_${m}`] && named[`phone_section_${m}`].y < top);
        return above.length ? above[above.length - 1] : null;
      };
      if (!(await controls())[`phone_row_${row}`]) {
        menuOpened = true;
        for (let n = 0; n < 6; n++) {
          const left = await openMenu();
          if (!left) break;
          const name = await where(`phone_section_${left}`, 15);
          if (!name) break;
          await tap(name);
          await told(async () => (await openMenu()) !== left);
        }
        for (const menu of MENUS) {
          if ((await controls())[`phone_row_${row}`]) break;
          const section = await where(`phone_section_${menu}`, 15);
          if (!section) continue;
          await tap(section);
          if (!(await told(async () => (await rowsNow()).length > 0))) {
            await tap((await where(`phone_section_${menu}`, 15)) || section);
            await told(async () => (await rowsNow()).length > 0);
          }
          if ((await controls())[`phone_row_${row}`]) break;
          await tap((await where(`phone_section_${menu}`, 15)) || section);
          await told(async () => (await rowsNow()).length === 0);
        }
      }
      const top = head.y + head.h / 2 + 6;
      const bottom = panel.y + panel.h / 2 - 6;
      for (let n = 0; n < 40; n++) {
        const at = await where(`phone_row_${row}`, 8);
        if (!at) return false;
        if (at.y - at.h / 2 >= top && at.y + at.h / 2 <= bottom) {
          tally = counted;
          count((opened ? 1 : 0) + (menuOpened ? 1 : 0));
          if (tally) {
            tally.more = true;
            const menu = await openMenu();
            note(`${row}: ${[opened ? "More" : "", menuOpened ? (menu ? `its menu (${menu})` : "its menu") : "",
              drags ? `${drags} drag${drags > 1 ? "s" : ""} to bring it into sight` : "", "the row"]
              .filter(Boolean).join(", ")}`);
          }
          await tap(at);
          await page.waitForTimeout(1200);
          return true;
        }
        const span = (bottom - top) * 0.6;
        const by = at.y < top ? Math.min(top - at.y + 40, span) : -Math.min(at.y - bottom + 40, span);
        const from = by > 0 ? top + 12 : bottom - 12;
        await drag({ x: panel.x, y: from }, { x: panel.x, y: from + by }, 16, 400);
        drags += 1;
      }
      return false;
    } finally {
      tally = counted;
      if (counted) count(drags);
    }
  };
  const moreRow = async (row) => {
    if (await more(row)) return true;
    note(`More has no ${row} a finger reaches`);
    return false;
  };

  // A dialog put away by its own way out, or by Escape.
  const closeDialogs = async () => {
    for (let n = 0; n < 4; n++) {
      const told = await ask();
      const open = (told?.dialogs || []).filter((d) => !/^PhoneShell|TouchSizing/.test(d));
      if (!open.length) return;
      const mine = (told?.targets || []).filter((t) => t.in && open.includes(t.in));
      const way = mine.find((t) => t.close) || mine.find((t) => /^(Done|Close|Cancel|OK)$/.test(t.text || ""));
      if (way) await tapBox(way.box);
      else await page.keyboard.press("Escape");
      await page.waitForTimeout(900);
    }
  };
  // Every sheet put away, every dialog closed, the ruler and the cut put
  // away, nothing in hand and nothing selected: as the next act begins.
  // The drawer of the model tree and the properties, open: the whole
  // screen beside its rail on a phone. Folded by a tap on the rail.
  const drawerOpen = async () => Boolean((await controls()).properties || (await controls()).outliner_tree);
  const foldDrawer = async () => {
    for (let n = 0; n < 2 && (await drawerOpen()); n++) {
      const rail = await where("parts_rail", 3);
      if (!rail) return false;
      await tap(rail);
      await page.waitForTimeout(1200);
    }
    return !(await drawerOpen());
  };
  const tidy = async () => {
    await closeDialogs();
    await foldDrawer();
    // The ruler, left out by Measure: its reading at the view's top. Put
    // away as its words say, Escape (a finger's way is More's Measure).
    const ruler = () => shown().then((told) => (told.texts || []).some((t) => /^[\d.,]+ mm — /.test(t.text || "")));
    if (await ruler()) {
      await page.keyboard.press("Escape");
      await page.waitForTimeout(600);
      if (await ruler()) await more("measure");
    }
    for (const name of ["render_close", "motions_close", "simulate_close", "page_done", "cut_close"]) {
      const at = (await controls())[name];
      if (at) await tap(at);
    }
    for (let n = 0; n < 4; n++) {
      const open = await sheets();
      if (!open.length) break;
      const title = open[open.length - 1];
      const done = await where(`phone_sheet_${title.toLowerCase().replace(/ /g, "_")}_done`, 3);
      if (done) await tap(done);
      else await page.keyboard.press("Escape");
      await page.waitForTimeout(500);
    }
    if ((await state()).cut?.on) await more("cut");
    // The timeline, which the page editor is opened from: over the foot, it
    // covers the model's lowest parts.
    if (Object.keys((await state()).timeline || {}).length) await more("timeline");
    // The ruler, what is in hand and what is selected let go, as Esc does.
    for (let n = 0; n < 3; n++) {
      const s = await state();
      if (s.mode === "select" && !s.carrying && !s.selected && !/measur/i.test(s.said || "")) break;
      await page.keyboard.press("Escape");
      await page.waitForTimeout(600);
    }
    if ((await state()).mode !== "select") {
      const at = await where("phone_select", 5);
      if (at) await tap(at);
    }
    await page.waitForTimeout(600);
  };

  // Parts searched for, and the first tile tapped: in hand.
  const take = async (query) => {
    if (!(await sheets()).includes("Parts")) await press("phone_parts");
    // Like this, left on by its act, narrows every search after it: put
    // off between acts as its act's own end (not counted).
    // Like this is a shelf of the bin's, as All is: All tapped leaves it.
    const told = await ask();
    const about = (told?.targets || []).some((t) => /^(Like this|Fits)$/.test(t.text || "") && t.on)
      || (told?.texts || []).some((t) => /then choose Like this|^Parts like /.test(t.text || ""));
    const all = (told?.targets || []).find((t) => t.text === "All");
    if (about && all) {
      await untimed(() => tapBox(all.box));
      await page.waitForTimeout(800);
    }
    const box = await where("part search", 20);
    if (!box) return "";
    await tap(box);
    await untimed(() => page.keyboard.press("Control+a"));
    await keys(query);
    // The bin answers as the words come: its first tiles settled (the same
    // twice, a second apart, the box reading the whole query) before a
    // tap, as a person waits for the list to stop changing.
    let found = [];
    for (let n = 0, same = 0; n < 30 && same < 2; n++) {
      await page.waitForTimeout(1000);
      const now = (await state()).found || [];
      const box = ((await ask())?.texts || []).find((t) => /part search/.test(t.name));
      same = now.length && JSON.stringify(now) === JSON.stringify(found) && (!box || box.text === query) ? same + 1 : 0;
      found = now;
    }
    const tile = await where("first part", 20);
    if (!tile) return "";
    await tap(tile);
    const s = await until((now) => now.mode === "place" && String(now.held || "") === String(found[0] || ""), 20);
    return s.mode === "place" ? String(s.held) : "";
  };
  // A tap that put the part in hand down, near a point: a step aside if the
  // spot takes nothing. Every tap is counted, the missed ones said.
  // Where each part was put down, for a person's next tap on it when the
  // app's own look finds no part (Layout picks parts whose top a line from
  // the eye meets first: a flat row seen low can have none).
  const laid = [];
  const putDown = async (at) => {
    const before = (await state()).bricks || 0;
    let missed = 0;
    for (const [dx, dy] of [[0, 0], [14, 0], [0, 14], [-14, 0], [0, -14], [28, 10]]) {
      const spot = { x: at.x + dx, y: at.y + dy };
      await tap(spot);
      const s = await until((now) => (now.bricks || 0) > before, 6);
      if ((s.bricks || 0) > before) {
        laid.push(spot);
        return { put: s.put, missed };
      }
      missed += 1;
    }
    return { put: null, missed };
  };
  const centre = async () => {
    const laid = await layout();
    if (laid?.centre) return { x: laid.centre.x, y: laid.centre.y };
    const view = (await controls()).view;
    return view ? { x: view.x, y: view.y } : { x: width / 2, y: height / 2 };
  };
  const partsOnScreen = async (most = 1) => {
    const found = ((await layout()) || {}).targets || [];
    if (found.length >= most || laid.length < most) return found;
    note(`the app's look found ${found.length} parts; tapped where they were put down`);
    return laid.slice(-Math.max(most, 4)).reverse();
  };
  // Parts that turn on a joint, where a person takes hold of them: the
  // app's own handles (window.brickworksGrab, asked for only here: finding
  // them costs a big model's frames), over the view and clear of the panel
  // whose Close is [panel]. [{x, y, pivot_x, pivot_y, id}]
  const turning = async (panel) => {
    await page.evaluate(() => { window.brickworksGrabAsk = true; });
    let handles = [];
    for (let n = 0; n < 20 && !handles.length; n++) {
      await page.waitForTimeout(500);
      handles = await page.evaluate(() => (window.brickworksGrab || {}).handles || []);
    }
    await page.evaluate(() => { window.brickworksGrabAsk = false; });
    const over = panel ? await where(panel, 3) : null;
    const bar = (await controls()).phone_parts;
    // The panel stands below and to the left of its Close (its title's
    // right end), down to the bar at the foot.
    const under = (h) => over && h.x <= over.x + over.w / 2 + 4 && h.y >= over.y - over.h / 2 - 4;
    return handles.filter((h) => h.x > 8 && h.x < width - 8 && h.y > 60
      && h.y < (bar ? bar.y - bar.h / 2 : height) - 8 && !under(h));
  };
  // A model opened as a person opens one from their computer (not counted):
  // More, Open…, From a file on this computer…, the file chosen.
  const openFile = async (file, count) => {
    for (let tries = 0; tries < 3; tries++) {
      choosers.length = 0;
      if (!(await more("open"))) continue;
      const menu = await ask();
      const row = (menu?.texts || []).find((t) => /^From a file/.test(t.text));
      if (!row) {
        await page.keyboard.press("Escape");
        continue;
      }
      await tapBox(row.box);
      for (let n = 0; n < 60 && !choosers.length; n++) await page.waitForTimeout(500);
      const chooser = choosers.shift();
      if (!chooser) continue;
      await chooser.setFiles(file);
      await page.waitForTimeout(1500);
      const asked = ((await ask())?.targets || []).find((t) => /^(Discard|Don.t save|Open)/.test(t.text || "") && t.in);
      if (asked) await tapBox(asked.box);
      const s = await until((now) => (now.bricks || 0) >= count && (now.awaited || 0) === 0, 240);
      if ((s.bricks || 0) >= count) return true;
    }
    return false;
  };
  const openModel = async (which) => {
    await tidy();
    laid.length = 0;
    if (which === "car") {
      const s = await state();
      if ((s.bricks || 0) !== 61 && !(await openFile(CAR, 61))) throw new Error("the car would not open");
    } else if (which === "empty" || which === "wall") {
      if (await more("new")) {
        const discard = await where("new_discard", 4);
        if (discard) await tap(discard);
      }
      const s = await until((now) => now.bricks === 0, 30);
      if (s.bricks !== 0) throw new Error(`New left ${s.bricks} parts`);
    } else if (which === "doors") {
      if (!(await openFile(DOORS, 30))) throw new Error("1484-1 would not open");
    } else if (which === "orrery") {
      if (!(await openFile(ORRERY, 10))) throw new Error("the orrery would not open");
    }
    await page.waitForTimeout(1500);
    said(`${which}: ${(await state()).bricks} parts`);
  };

  // -- the acts ---------------------------------------------------------------------

  const ACTED = {
    async step_to() {
      const parts = await partsOnScreen();
      if (!parts.length) return { why: "no part of the car on the screen to hold" };
      await hold(parts[Math.min(1, parts.length - 1)]);
      if (!(await pressRow("phone_row_step_to"))) return { why: "the part's actions have no Move to step…" };
      let told = await ask();
      for (let n = 0; n < 20 && !(told?.dialogs || []).some((d) => /Move to step/.test(d)); n++) {
        await page.waitForTimeout(500);
        told = await ask();
      }
      if (!(told?.dialogs || []).some((d) => /Move to step/.test(d))) return { why: "Move to step… opened no dialog" };
      const inIt = (t) => /Move to step/.test(t.in || "");
      const field = (told.texts || []).find((t) => inIt(t) && /LineEdit|SpinBox/.test(t.name));
      const move = (told.targets || []).find((t) => inIt(t) && /^Move$/.test(t.text || ""));
      if (!field || !move) return { why: `the dialog's field (${Boolean(field)}) or Move (${Boolean(move)}) is not there` };
      const from = Number(String(field.text).replace(/[^0-9]/g, "")) || 0;
      await tapBox(field.box);
      // The number chosen, as a finger chooses it: held, Select all.
      await key("Control+a");
      await keys("99");
      await tapBox(move.box);
      const s = await until((now) => /moved \d+ parts? to step/.test(now.said || ""), 15);
      const to = Number((/to step (\d+)/.exec(s.said || "") || [])[1] || 0);
      note(`from step ${from}: "${s.said}"`);
      return { done: to > from, why: to > from ? "" : `the part stayed (said "${s.said}")` };
    },

    async render() {
      if (!(await moreRow("render"))) return { why: "More has no Render" };
      const file = page.waitForEvent("download", { timeout: 600000 }).catch(() => null);
      if (!(await press("render_picture", 30))) return { why: "Render's Picture is not on the screen" };
      const got = await file;
      note(`downloaded ${got ? got.suggestedFilename() : "nothing"}`);
      return { done: Boolean(got && /\.png$/i.test(got.suggestedFilename())), why: got ? "" : "no picture came" };
    },

    async booklet() {
      const tabs = [];
      const heard = (tab) => tabs.push(tab);
      page.context().on("page", heard);
      const pressed = await moreRow("instructions");
      const tab = tabs[0] || (pressed ? await page.context().waitForEvent("page", { timeout: 90000 }).catch(() => null) : null);
      page.context().off("page", heard);
      if (!tab) return { why: pressed ? "Instructions opened no tab" : "More has no Instructions" };
      const pages = await tab.locator("section.page").first().waitFor({ state: "visible", timeout: 240000 })
        .then(() => tab.locator("section.page").count()).catch(() => 0);
      await tab.screenshot({ path: `${out}/${size}_${String(++shot).padStart(2, "0")}_booklet_tab.png` }).catch(() => {});
      note(`the booklet's tab: ${pages} pages`);
      await tab.close().catch(() => {});
      return { done: pages > 0, why: pages ? "" : "its tab showed no page" };
    },

    async like_this() {
      const parts = await partsOnScreen();
      if (!parts.length) return { why: "no part on the screen to tap" };
      await tap(parts[0]);
      let s = await until((now) => now.selected === 1, 8);
      if (s.selected !== 1) return { why: `a tap selected ${s.selected}` };
      const before = (s.found || []).slice(0, 6).join();
      if (!(await sheets()).includes("Parts")) await press("phone_parts");
      let chip = null;
      for (let n = 0; n < 20 && !chip; n++) {
        chip = ((await ask())?.targets || []).find((t) => /^Like this/.test(t.text || ""));
        if (!chip) await page.waitForTimeout(500);
      }
      if (!chip) return { why: "the Parts sheet shows no Like this" };
      if (chip.off) note(`Like this is off the screen at ${chip.box}`);
      await tapBox(chip.box);
      s = await until((now) => (now.found || []).slice(0, 6).join() !== before && (now.found || []).length > 0, 30);
      const words = ((await ask())?.texts || []).find((t) => /^Parts like/.test(t.text));
      note(`first tiles ${(s.found || []).slice(0, 4).join(", ")}; "${words ? words.text : ""}"`);
      return { done: Boolean(words) || (s.found || []).slice(0, 6).join() !== before,
        why: "the bin did not change" };
    },

    async stability() {
      if (!(await moreRow("stability"))) return { why: "More has no Check stability" };
      const s = await until((now) => /stands|weak|tip|fall|topple/i.test(now.said || ""), 30);
      note(`said "${s.said}"`);
      return { done: /stands|weak|tip|fall|topple/i.test(s.said || ""), why: "it said nothing of the car's standing" };
    },

    async cut() {
      if (!(await moreRow("cut"))) return { why: "More has no Cut away" };
      let s = await until((now) => now.cut?.on, 10);
      if (!s.cut?.on) return { why: "Cut away did not cut" };
      const at = s.cut.at;
      const slider = await where("cut_slider", 10);
      if (!slider) return { why: "the cut's slider is not on the screen" };
      const from = { x: slider.x - slider.w * 0.2, y: slider.y };
      aim(slider);
      await drag({ x: slider.x, y: slider.y }, { x: from.x + slider.w * 0.45, y: slider.y });
      s = await until((now) => now.cut?.at !== at, 6);
      note(`the plane from ${at} to ${s.cut?.at} on ${s.cut?.axis}`);
      return { done: s.cut?.at !== at, why: "the slider dragged by a finger moved no plane" };
    },

    async collection() {
      if (!(await moreRow("collection"))) return { why: "More has no My collection" };
      let told = null;
      for (let n = 0; n < 20; n++) {
        told = await ask();
        if ((told?.dialogs || []).some((d) => /Collection/.test(d))) break;
        await page.waitForTimeout(500);
      }
      const open = (told?.dialogs || []).some((d) => /Collection/.test(d));
      note(`open: ${JSON.stringify(told?.dialogs || [])}`);
      return { done: open, why: "My collection did not open" };
    },

    async measure() {
      if (!(await moreRow("measure"))) return { why: "More has no Measure" };
      const parts = await partsOnScreen();
      if (parts.length < 2) return { why: "fewer than two parts on the screen to measure between" };
      const before = (await state()).selected || 0;
      await tap(parts[0]);
      await tap(parts[parts.length - 1]);
      await page.waitForTimeout(800);
      const told = await ask();
      const reading = (told?.texts || []).find((t) => /\d.*(stud|plate|mm)/.test(t.text) && / — /.test(t.text));
      const s = await state();
      note(`read "${reading ? reading.text : ""}"; said "${s.said}"; ${s.selected} selected (was ${before}), mode ${s.mode}`);
      return { done: Boolean(reading),
        why: `two taps measured nothing: ${s.selected !== before ? `the tap selected (${s.selected} selected)` : `said "${s.said}"`}` };
    },

    async page_open() {
      if (!(await moreRow("timeline"))) return { why: "More has no Timeline" };
      await page.waitForTimeout(1500);
      // The timeline's own Lay out the page… where it shows one (its
      // Booklet row, for the author's steps), else More's.
      const own = await where("booklet_lay_out", 5);
      if (own) await press("booklet_lay_out", 5);
      else if (!(await moreRow("booklet_lay_out"))) return { why: "neither the timeline nor More has Lay out the page…" };
      const s = await until((now) => (now.page_editor?.page || 0) > 0, 30);
      note(`page ${s.page_editor?.page}: ${Object.keys(s.page_editor?.items || {}).join(", ")}`);
      return { done: (s.page_editor?.page || 0) > 0, why: "the page editor did not open" };
    },

    async page_move() {
      const s = await state();
      const items = s.page_editor?.items || {};
      const name = Object.keys(items).find((n) => /^page_(step|picture|shot)/.test(n)) || Object.keys(items)[0];
      if (!name) return { why: "the page editor is not open, or its page has nothing on it" };
      const at = await where(name, 10);
      if (!at) return { why: `${name} is not on the screen` };
      const was = JSON.stringify(items[name]);
      aim(at);
      await drag({ x: at.x, y: at.y }, { x: at.x + 30, y: at.y + 40 }, 14, 400);
      const after = await until((now) => JSON.stringify(now.page_editor?.items?.[name]) !== was, 8);
      note(`${name} from ${was} to ${JSON.stringify(after.page_editor?.items?.[name])}; said "${after.page_editor?.said || ""}"`);
      return { done: JSON.stringify(after.page_editor?.items?.[name]) !== was,
        why: `a finger's drag of ${name} moved nothing${after.view ? "" : ""}` };
    },

    async page_resize() {
      let s = await state();
      if (!s.page_editor?.page) return { why: "the page editor is not open" };
      // An item whose far corner is on the screen, as a person picks one
      // to size: the page is wider than a phone, and a corner past its
      // edge takes no finger.
      const inside = (at) => at && at.x > 4 && at.x < width - 4 && at.y > 4 && at.y < height - 4;
      let name = "";
      let corner = await where("page_resize", 3);
      if (s.page_editor.selected && inside(corner)) name = s.page_editor.selected;
      // Items tried whose corner turned out past the edge once selected are
      // not counted: a person sees where the corner will be.
      let tried = 0;
      for (const item of Object.keys(s.page_editor.items || {})) {
        if (name) break;
        const at = await where(item, 2);
        if (!at || !inside({ x: at.x + at.w / 2, y: at.y + at.h / 2 })) continue;
        await untimed(() => tap(at));
        s = await until((now) => now.page_editor?.selected === item, 4);
        corner = await where("page_resize", 4);
        if (s.page_editor?.selected === item && inside(corner)) {
          name = item;
          count(1);
        } else tried += 1;
      }
      if (tried) note(`${tried} items tried before one whose corner was on the screen`);
      if (!name) return { why: `no item's corner is on the screen (the selected one's at ${corner ? `${Math.round(corner.x)}, ${Math.round(corner.y)}` : "none"})` };
      const was = JSON.stringify(s.page_editor.items[name]);
      aim(corner);
      await drag({ x: corner.x, y: corner.y }, { x: corner.x + 30, y: corner.y + 30 }, 14, 400);
      const after = await until((now) => JSON.stringify(now.page_editor?.items?.[name]) !== was, 8);
      note(`${name} from ${was} to ${JSON.stringify(after.page_editor?.items?.[name])}`);
      return { done: JSON.stringify(after.page_editor?.items?.[name]) !== was, why: "its corner dragged by a finger resized nothing" };
    },

    async page_words() {
      const s = await state();
      if (!s.page_editor?.page) return { why: "the page editor is not open" };
      const before = Object.keys(s.page_editor.items || {}).length;
      if (!(await press("page_add_text", 10))) return { why: "Add words is not on the screen" };
      await page.waitForTimeout(800);
      // The new words come selected in their field, to type over; a phone's
      // keyboard comes up only for a tap in the field.
      const field = await where("page_words", 5);
      if (!field) return { why: "Add words' field is not on the screen" };
      const typed = await typeOver(field, "Hi");
      const after = await until((now) => Object.keys(now.page_editor?.items || {}).length > before, 8);
      const added = Object.keys(after.page_editor?.items || {}).length - before;
      note(`${added} item added; its field held "${typed.held}"${typed.tapped ? " after the tap that brings the keyboard up" : ""}`
        + `${typed.cleared ? `, ${typed.cleared} deletes to empty it` : ""}; it reads "${typed.words}"`);
      if (added < 1) return { why: "Add words put no words on the page" };
      return { done: typed.words === "Hi", why: `the words read "${typed.words}"`,
        slow: typed.cleared ? `"Hi" went on the end of "${typed.held}", drawn selected: the tap that brings a phone's `
          + `keyboard up drops the field's select-all, so ${typed.cleared} deletes, a letter each, and "Hi" again` : "" };
    },

    async page_done() {
      if (!(await press("page_done", 10))) return { why: "Done is not on the screen" };
      const s = await until((now) => !now.page_editor?.page, 10);
      return { done: !s.page_editor?.page, why: "Done left the page editor open" };
    },

    async split_merge() {
      // The plate, from the search and put down (not counted: the walk lays
      // it by code).
      const plate = await untimed(async () => {
        if ((await take("3020")) !== "3020") return false;
        const down = await putDown(await centre());
        await untimed(() => press("phone_select"));
        await until((now) => now.mode === "select" && !now.carrying, 5);
        return Boolean(down.put);
      });
      if (!plate) throw new Error("a 2 x 4 plate could not be put down to split");
      let parts = await partsOnScreen();
      if (!parts.length) return { why: "the plate is not on the screen" };
      await hold(parts[0]);
      if (!(await pressRow("phone_row_split_parts"))) return { why: "the plate's actions have no Split" };
      let s = await until((now) => (now.bricks || 0) > 1, 15);
      const split = s.bricks || 0;
      note(`split: ${split} parts (${(s.parts || []).join(", ")})`);
      if (split <= 1) return { why: `Split left ${split} part (said "${s.said}")` };
      if (!(await moreRow("select_all"))) return { why: "More has no Select all" };
      s = await until((now) => now.selected === split, 6);
      parts = await partsOnScreen();
      await hold(parts[0]);
      if (!(await pressRow("phone_row_merge_parts"))) return { why: "the pieces' actions have no Merge" };
      s = await until((now) => now.bricks === 1, 15);
      note(`merged: ${s.bricks} part (${(s.parts || []).join(", ")}); said "${s.said}"`);
      return { done: s.bricks === 1 && (s.parts || [])[0] === "3020", why: `Merge left ${s.bricks} parts` };
    },

    async turn() {
      // A 2 x 4 brick of its own (not counted: put down by code), so the
      // turn reads back from where the app says the brick now faces.
      const brick = await untimed(async () => {
        if ((await take("3001")) !== "3001") return null;
        const c = await centre();
        const down = await putDown({ x: c.x - width * 0.1, y: c.y - height * 0.06 });
        await press("phone_select");
        await until((now) => now.mode === "select" && !now.carrying, 5);
        return down.put;
      });
      if (!brick) throw new Error("a 2 x 4 brick could not be put down to turn");
      // Degrees about the vertical, from the brick's x axis (pose: origin,
      // then basis x, y, z).
      const facing = (pose) => Math.atan2(-pose[5], pose[3]) * 180 / Math.PI;
      const before = facing(brick.pose);
      const on = (((await layout()) || {}).targets || []).find((t) => t.brick === brick.id) || laid.at(-1);
      // The brick tapped alone (as the desktop clicks it), then held for its
      // actions. The row's Turn turns by the turn step, 90° out of the box,
      // with no way to choose another by finger: Properties' Turn is typed.
      await untimed(async () => {
        for (let n = 0; n < 3 && ((await state()).selected || 0) > 0; n++) await page.keyboard.press("Escape");
      });
      await tap(on);
      const alone = await until((now) => now.selected === 1, 6);
      if (alone.selected !== 1) note(`a tap on the brick left ${alone.selected} selected`);
      await hold(on);
      const held = (await state()).selected;
      if (held !== 1) note(`held, ${held} selected`);
      if (!(await pressRow("phone_row_show_properties"))) return { why: "the part's actions have no Properties" };
      const field = await where("prop_turn", 15);
      if (!field) return { why: "Properties shows no Turn field a finger reaches" };
      const want = String(Math.round(before + 15));
      const typed = await typeOver(field, want);
      await key("Enter");
      const entered = await until((now) => now.put && Math.abs(facing(now.put.pose) - before) > 1, 6);
      const turnedBy = (s) => (s.put ? ((facing(s.put.pose) - before + 540) % 360) - 180 : 0);
      // Back to the model, as a person must to see it: the drawer folded by
      // its rail (and the field let go with it).
      await foldDrawer();
      const s = await until((now) => now.put && Math.abs(facing(now.put.pose) - before) > 1, 6);
      const by = turnedBy(s);
      note(`Properties' Turn held "${typed.held}"${typed.cleared ? `, ${typed.cleared} deletes` : ""}, typed ${want}: `
        + `it read "${typed.words}"; Enter turned it ${turnedBy(entered).toFixed(1)}°, and with the drawer folded `
        + `${by.toFixed(1)}° (said "${s.said || ""}"); the row's Turn turns by the turn step (90°)`);
      return { done: Math.abs(Math.abs(by) - 15) < 0.5,
        why: `Properties' Turn typed ${want} (it read "${typed.words}"), and the brick turned by ${by.toFixed(1)}°`,
        slow: typed.cleared ? `${want} went on the end of "${typed.held}": the tap that brings a phone's keyboard up `
          + `drops the field's select-all, so ${typed.cleared} deletes, a letter each, and ${want} again` : "" };
    },

    async wall() {
      const held = await take("1x4 brick");
      if (!held) return { why: "\"1x4 brick\" put nothing in hand" };
      const c = await centre();
      const step = Math.max(36, Math.round(Math.min(width, height) * 0.11));
      let missed = 0;
      const heights = [];
      for (let n = 0; n < 4; n++) {
        const down = await putDown({ x: c.x + (n - 1.5) * step, y: c.y + step * 0.6 });
        missed += down.missed;
        if (down.put) heights.push(down.put.pose[1]);
      }
      // The second course on the first: a tap on each brick's top.
      const tops = (await partsOnScreen(4)).slice(0, 4);
      for (const top of tops) {
        const down = await putDown({ x: top.x, y: top.y });
        missed += down.missed;
        if (down.put) heights.push(down.put.pose[1]);
      }
      for (let n = heights.length; n < 8; n++) {
        const down = await putDown({ x: c.x + (n - 5) * step, y: c.y - step });
        missed += down.missed;
        if (down.put) heights.push(down.put.pose[1]);
      }
      await press("phone_select");
      const s = await until((now) => now.mode === "select" && !now.carrying, 5);
      const ground = Math.max(...heights);
      const above = heights.filter((y) => y < ground - 1).length;
      note(`${s.bricks} of 8 down (${held}), ${above} on the others; ${missed} taps put nothing down`);
      return { done: s.bricks === 8, why: `${s.bricks} of 8 put down` };
    },

    async paint() {
      const parts = (await partsOnScreen(3)).slice(0, 3);
      if (parts.length < 3) return { why: "fewer than three parts on the screen" };
      let code = 0;
      let painted = 0;
      for (const part of parts) {
        // The Colour sheet, open from the part before, over this one: put
        // away by its Done first, as a person must to reach the part.
        const sheet = (await controls()).phone_panel_colour;
        if (sheet && Math.abs(part.x - sheet.x) <= sheet.w / 2 && Math.abs(part.y - sheet.y) <= sheet.h / 2) {
          const done = await where("phone_sheet_colour_done", 3);
          if (done) await tap(done);
        }
        // Selected alone, and not one already painted: a tap that missed it
        // leaves the last one selected, in the new colour.
        await tap(part);
        const fresh = (now) => now.selected === 1 && !(code && (now.selected_colours || []).includes(code));
        let s = await until(fresh, 6);
        if (!fresh(s)) {
          note(`a tap on #${part.brick ?? "?"} left ${s.selected} selected (${JSON.stringify(s.selected_colours || [])})`);
          continue;
        }
        if (!code) code = (s.selected_colours || [])[0] === 4 ? 1 : 4;
        if (!(await sheets()).includes("Colour")) await press("phone_colour");
        let swatch = await where(`phone_swatch_${code}`, 8);
        for (let n = 0; n < 6 && swatch && swatch.y + swatch.h / 2 > height - 2; n++) {
          await drag({ x: width / 2, y: height * 0.7 }, { x: width / 2, y: height * 0.35 });
          swatch = await where(`phone_swatch_${code}`, 5);
        }
        if (!swatch) {
          note(`no swatch ${code}`);
          continue;
        }
        await tap(swatch);
        s = await until((now) => (now.selected_colours || []).includes(code), 6);
        if ((s.selected_colours || []).includes(code)) painted += 1;
      }
      // Read back, not counted: the same colour selected.
      const check = await untimed(async () => {
        await hold(parts[0]);
        if (!(await pressRow("phone_row_select_colour"))) return -1;
        return (await until((now) => now.selected > 1, 20)).selected;
      });
      note(`${painted} of 3 painted ${code === 4 ? "red" : "blue"}, one at a time (a tap in Select replaces the `
        + `selection, and nothing adds to it by finger); the same colour selects ${check}`);
      return { done: painted === 3 && check === 3, why: `${painted} of 3 painted; the same colour selected ${check}`,
        slow: "a tap in Select replaces the selection, and nothing adds to it by finger: each part tapped and painted on its own" };
    },

    async motions_play() {
      if (!(await moreRow("pose"))) return { why: "More has no Motions…" };
      let m = await untilRead("brickworksMotions", (now) => (now.suggested || []).length > 0 || (now.motions || []).length > 0, 90);
      note(`suggested ${JSON.stringify(m.suggested || []).slice(0, 80)}`);
      const kept = async () => ((await untilRead("brickworksMotions", (now) => (now.motions || []).length > 0, 6)).motions || []).length > 0;
      if (!(await pressIn("motion_keep_0", "motions_close", kept))) return { why: "the suggestion's Keep took no tap" };
      const played = async () => {
        const now = await untilRead("brickworksMotions", (one) => one.playing || /^Played/.test(one.status || ""), 20);
        return Boolean(now.playing || /^Played/.test(now.status || ""));
      };
      if (!(await pressIn("motion_play_0", "motions_close", played))) return { why: "the motion's Play took no tap" };
      m = await untilRead("brickworksMotions", (now) => !now.playing, 60);
      note(`"${String(m.status || "").slice(0, 100)}"`);
      return { done: true };
    },

    async motions_record() {
      const kept = ((await read("brickworksMotions")).motions || []).length;
      const editing = async () => (await untilRead("brickworksMotions", (now) => now.view === "edit", 6)).view === "edit";
      if (!(await pressIn("motions_new", "motions_close", editing))) return { why: "New motion took no tap" };
      // Its name is left as offered: no keyboard comes up untapped.
      const listening = async () => Boolean((await untilRead("brickworksMotions", (now) => now.recording, 6)).recording);
      if (!(await pressIn("motions_record", "motions_close", listening))) return { why: "Record took no tap" };
      let m = await read("brickworksMotions");
      // A door taken where the app says a part that turns shows, and swung
      // round its hinge: dragged across the line from the hinge to it.
      const doors = await untimed(() => turning("motions_close"));
      if (!doors.length) return { why: "no part that turns on a joint shows clear of the panel" };
      const side = [];
      for (const door of doors.slice(0, 2)) {
        const out = { x: door.x - (door.pivot_x ?? door.x), y: door.y - (door.pivot_y ?? door.y + 1) };
        const long = Math.hypot(out.x, out.y) || 1;
        const by = Math.min(70, width * 0.15);
        await drag({ x: door.x, y: door.y }, { x: door.x - (out.y / long) * by, y: door.y + (out.x / long) * by }, 10, 200);
        const after = await state();
        const open = (await sheets()).filter((t) => !["Parts", "Colour", "More"].includes(t));
        note(`swung #${door.id} (${door.part}) by a finger: ${after.selected || 0} selected${open.length ? `, "${open.join(", ")}" opened` : ""}; `
          + `"${String((await read("brickworksMotions")).status || "").slice(0, 80)}"`);
        if (open.length) side.push(`${after.selected || 0} parts selected and their actions opened over the panel`);
        const now = await read("brickworksMotions");
        if ((now.joints || []).some((j) => (Array.isArray(j.keys) ? j.keys.length : Number(j.keys || 0)) >= 2)) break;
      }
      // A sheet the drags opened over the panel, put away by its Done to
      // reach Stop.
      for (const title of (await sheets()).filter((t) => !["Parts", "Colour", "More"].includes(t))) {
        const done = await where(`phone_sheet_${title.toLowerCase().replace(/ /g, "_")}_done`, 3);
        if (done) await tap(done);
      }
      const stopped = async () => !(await untilRead("brickworksMotions", (now) => !now.recording, 6)).recording;
      await pressIn("motions_record", "motions_close", stopped);
      m = await read("brickworksMotions");
      const keys = (m.joints || []).reduce((n, j) => n + (Array.isArray(j.keys) ? j.keys.length : Number(j.keys || 0)), 0);
      note(`${(m.motions || []).length} motions (was ${kept}); ${keys} keys; "${String(m.status || "").slice(0, 100)}"`);
      return { done: keys >= 2, why: `a finger's drag in the view recorded ${keys} keys ("${String(m.status || "").slice(0, 80)}")`,
        slow: side.length ? `each drag of a door while recording also left ${side[0]}, put away by its Done to reach Stop` : "" };
    },

    async motions_slider() {
      // What the act before left (a sheet over the panel, Record still
      // listening) put back first, not counted.
      await untimed(async () => {
        for (const title of (await sheets()).filter((t) => !["Parts", "Colour", "More"].includes(t))) {
          const done = await where(`phone_sheet_${title.toLowerCase().replace(/ /g, "_")}_done`, 3);
          if (done) await tap(done);
        }
        if ((await read("brickworksMotions")).recording) {
          await pressIn("motions_record", "motions_close", async () => !(await untilRead("brickworksMotions", (now) => !now.recording, 6)).recording);
        }
      });
      let m = await read("brickworksMotions");
      if (m.view !== "edit" && (m.motions || []).length) await untimed(() => press("motion_edit_0", 8));
      m = await untilRead("brickworksMotions", (now) => (now.joints || []).length > 0, 10);
      const slider = await bringIn("motions_joint_0", "motions_close");
      if (!slider) return { why: "no joint's slider on the screen" };
      const was = JSON.stringify((m.joints || [])[0]?.place);
      aim(slider);
      await drag({ x: slider.x - slider.w * 0.3, y: slider.y }, { x: slider.x + slider.w * 0.3, y: slider.y });
      m = await untilRead("brickworksMotions", (now) => JSON.stringify((now.joints || [])[0]?.place) !== was, 8);
      note(`the joint from ${was} to ${JSON.stringify((m.joints || [])[0]?.place)}`);
      return { done: JSON.stringify((m.joints || [])[0]?.place) !== was, why: "a finger's drag of the slider moved no joint" };
    },

    async simulate_play() {
      if (!(await moreRow("simulate"))) return { why: "More has no Simulate mechanism…" };
      let s = await untilRead("brickworksSimulate", (now) => now.open, 30);
      if (!s.open) return { why: "Simulate did not open" };
      const playing = async () => Boolean((await untilRead("brickworksSimulate", (now) => now.playing, 6)).playing);
      if (!(await pressIn("simulate_play", "simulate_close", playing))) return { why: "Play took no tap" };
      s = await read("brickworksSimulate");
      note(`playing ${s.playing}; driver ${JSON.stringify(s.driver)}; "${String(s.status || s.readout || "").slice(0, 100)}"`);
      return { done: Boolean(s.playing), why: "Play did not play" };
    },

    async simulate_scrub() {
      let s = await read("brickworksSimulate");
      if (!s.open) return { why: "Simulate is not open" };
      if (s.playing) {
        await untimed(() => pressIn("simulate_play", "simulate_close", async () =>
          !(await untilRead("brickworksSimulate", (now) => !now.playing, 6)).playing));
      }
      const slider = await bringIn("simulate_scrub", "simulate_close");
      if (!slider) return { why: "the cycle's slider is not on the screen" };
      s = await read("brickworksSimulate");
      const was = JSON.stringify([s.turns, s.readout]);
      aim(slider);
      await drag({ x: slider.x - slider.w * 0.3, y: slider.y }, { x: slider.x + slider.w * 0.2, y: slider.y });
      s = await untilRead("brickworksSimulate", (now) => JSON.stringify([now.turns, now.readout]) !== was, 8);
      note(`from ${was.slice(0, 80)} to ${JSON.stringify([s.turns, s.readout]).slice(0, 80)}`);
      return { done: JSON.stringify([s.turns, s.readout]) !== was, why: "a finger's drag of the slider moved nothing" };
    },

    async simulate_drive() {
      let s = await read("brickworksSimulate");
      if (!s.open) return { why: "Simulate is not open" };
      const was = JSON.stringify(s.driver);
      // A part that turns, where the app says one shows, else any part.
      const parts = [...(await untimed(() => turning("simulate_close"))), ...(await partsOnScreen())];
      for (const part of parts.slice(0, 3)) {
        await tap(part);
        s = await untilRead("brickworksSimulate", (now) => JSON.stringify(now.driver) !== was, 5);
        if (JSON.stringify(s.driver) !== was) break;
      }
      note(`the driver from ${was} to ${JSON.stringify(s.driver)}`);
      return { done: JSON.stringify(s.driver) !== was, why: "a tap on a part made no other driver" };
    },
  };

  return {
    picture, state, until, where, ask, untimed, openModel, tidy,
    begin: (id) => { tally = { id, n: 0, said: [], small: {}, brought: [] }; },
    end: () => {
      const done = tally;
      tally = null;
      return done;
    },
    run: (id) => ACTED[id](),
  };
}
