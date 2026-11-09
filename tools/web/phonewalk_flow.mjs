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
// than twice the desktop's presses (phonepanels' and fingertools' bar).
//
// Each size signs in as an account of its own, made for the run and deleted
// at its end (session.mjs), and walks four models:
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
import { deleteAccount, signInContext } from "./session.mjs";
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
  { id: "turn", model: "empty", needs: "split_merge", what: "a turn of 15°", desktop: 5,
    how: "the toolbar's turn step, 15° (2 clicks); the part clicked, R, a click (walk `turns`: 2 after the click)",
    file: "src/ui/phone_shell.gd (Turn turns by the turn step, 90°; only src/ui/toolbar.gd's chooser sets it)" },
  { id: "wall", model: "wall", what: "a wall of eight 1 x 4s from the search", desktop: 20,
    how: "a click in the search, \"1x4 brick\" (9 keys), the tile, 8 clicks, Esc (walk `wall`)",
    file: "src/main.gd (a tap puts the part in hand down)" },
  { id: "paint", model: "wall", needs: "wall", what: "three of them painted", desktop: 4,
    how: "a click, two Shift-clicks, Shift+5 (walk `round2`: 1 key after the clicks)",
    file: "src/main.gd, src/ui/edit_verbs.gd (a tap in Select replaces the selection: no adding to it by finger)" },
  { id: "motions_play", model: "doors", what: "Motions: the suggested motion kept and played", desktop: 3,
    how: "Alt+O, Keep, Play", file: "src/ui/pose_panel.gd" },
  { id: "motions_record", model: "doors", needs: "motions_play", what: "Motions: a motion recorded by dragging a part", desktop: 4,
    how: "New motion, Record, a door dragged, Stop", file: "src/ui/pose_panel.gd (recording through Grab in the view)" },
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
// The panel an act leaves open for the next, which goes on in it: the screen
// is put back only after the last of them.
const goesOn = (act, next) => Boolean(next && (next.needs === act.id || (act.needs && next.needs === act.needs)));
if (!wanted.length) {
  console.log(`no act is named ${ONLY}; the acts are ${ACTS.map((a) => a.id).join(", ")}`);
  process.exit(1);
}

const t0 = Date.now();
const said = (line) => console.log(`  --    ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
const results = {};
let broken = 0;

const browser = await launch({ signedOut: true });
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
  `a More row is More, its menu and the row. ✓ done by finger, ✗ not.`,
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
    cells.push(`${row.done ? "✓" : "✗"} ${row.taps}${over ? " (over 2x)" : ""}`);
    if (!row.done || over) stops.push(`${size}: ${row.why}`);
    verdicts.push({ act: act.id, size, done: row.done, over, ran: row.ran });
  }
  const file = stops.length ? `${stops.join("; ")} — **${act.file}**` : "";
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
const short = verdicts.filter((v) => !v.done || v.over);
console.log(`\n${ran} of ${verdicts.length} acts ran; ${verdicts.filter((v) => v.done).length} done by finger, `
  + `${verdicts.filter((v) => v.over).length} of them in over twice the desktop's presses; `
  + `the table is ${out}/phonewalk.md`);
if (broken || notRun.length) {
  console.log(`FAIL  the walk did not run: ${notRun.map((v) => `${v.act} at ${v.size}`).join(", ")}`);
  process.exit(1);
}
if (BAR && short.length) {
  console.log(`FAIL  --bar: ${short.map((v) => `${v.act} at ${v.size} (${v.done ? "over twice" : "not done"})`).join(", ")}`);
  process.exit(1);
}
console.log("every act of the walk was tried by a finger at every size");
process.exit(0);

// -- one size ---------------------------------------------------------------------

async function walk(width, height, ratio, result) {
  const size = `${width}x${height}`;
  const email = `delivered+phonewalk-${size}-${Date.now() % 1e9}@resend.dev`;
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: ratio,
    isMobile: true, hasTouch: true, acceptDownloads: true });
  const rows = result.rows;
  try {
    await signInContext(context, email);
    said(`signed in as ${email}, an account of its own`);
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
      const ranOk = !result.threw && !result.timedOut;
      const why = result.threw ? `it could not run: ${result.threw.split("\n")[0]}`
        : result.timedOut ? `it ran out of time (${Math.round(ACT_MS / 1000)} s)` : (result.why || tally.said.at(-1) || "");
      rows[act.id] = { done: Boolean(result.done), taps: tally.n, ran: ranOk, why,
        said: tally.said, seconds: Math.round((Date.now() - began) / 1000) };
      console.log(`  ${result.done ? "done" : ranOk ? "NOT " : "FAIL"}  ${act.id}: ${act.what}: ${tally.n} taps `
        + `(the desktop ${act.desktop})${result.done ? "" : ` — ${why}`}  [${Math.round((Date.now() - t0) / 1000)}s]`);
      await P.picture(act.id).catch(() => {});
      if (!goesOn(act, wanted[n + 1])) {
        await P.untimed(() => P.tidy()).catch((trouble) => said(`tidying after ${act.id}: ${trouble.message}`));
      }
    }
    result.errors = errors;
    said(`script errors: ${errors.length}${errors.length ? ` (${errors[0]})` : ""}`);
  } finally {
    await context.close().catch(() => {});
    const gone = await deleteAccount(email).catch(() => false);
    said(`${email} ${gone ? "deleted" : "NOT deleted"}`);
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
      if (at) return at;
      await page.waitForTimeout(250);
    }
    return null;
  };
  const ask = () => askApp(page, "Phone");
  const layout = () => askApp(page, "Layout");
  const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
    touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
  const tap = async (at) => {
    count();
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
  // A control pressed where it has come to rest (browser.mjs clickStill).
  const press = async (name, seconds = 30) => {
    const at = await clickStill(page, name, { find: (n) => where(n, seconds), optional: true, act: tap });
    if (!at) note(`"${name}" is not on the screen`);
    return Boolean(at);
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
  const tidy = async () => {
    await closeDialogs();
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
    const box = await where("part search", 20);
    if (!box) return "";
    await tap(box);
    await untimed(() => page.keyboard.press("Control+a"));
    await keys(query);
    await page.waitForTimeout(1800);
    const tile = await where("first part", 20);
    if (!tile) return "";
    const found = (await state()).found || [];
    await tap(tile);
    const s = await until((now) => now.mode === "place" && String(now.held || "") === String(found[0] || ""), 20);
    return s.mode === "place" ? String(s.held) : "";
  };
  // A tap that put the part in hand down, near a point: a step aside if the
  // spot takes nothing. Every tap is counted, the missed ones said.
  const putDown = async (at) => {
    const before = (await state()).bricks || 0;
    let missed = 0;
    for (const [dx, dy] of [[0, 0], [14, 0], [0, 14], [-14, 0], [0, -14], [28, 10]]) {
      await tap({ x: at.x + dx, y: at.y + dy });
      const s = await until((now) => (now.bricks || 0) > before, 6);
      if ((s.bricks || 0) > before) return { put: s.put, missed };
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
  const partsOnScreen = async () => ((await layout()) || {}).targets || [];
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
      if (!(await press("phone_row_step_to", 10))) return { why: "the part's actions have no Move to step…" };
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
      if (!(await press("booklet_lay_out", 15))) return { why: "the timeline has no Lay out the page… on the screen" };
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
      await drag({ x: at.x, y: at.y }, { x: at.x + 30, y: at.y + 40 }, 14, 400);
      const after = await until((now) => JSON.stringify(now.page_editor?.items?.[name]) !== was, 8);
      note(`${name} from ${was} to ${JSON.stringify(after.page_editor?.items?.[name])}; said "${after.page_editor?.said || ""}"`);
      return { done: JSON.stringify(after.page_editor?.items?.[name]) !== was,
        why: `a finger's drag of ${name} moved nothing${after.view ? "" : ""}` };
    },

    async page_resize() {
      let s = await state();
      if (!s.page_editor?.page) return { why: "the page editor is not open" };
      let name = s.page_editor.selected;
      if (!name) {
        const first = Object.keys(s.page_editor.items || {})[0];
        const at = first ? await where(first, 5) : null;
        if (at) await tap(at);
        s = await state();
        name = s.page_editor?.selected;
      }
      const corner = await where("page_resize", 8);
      if (!name || !corner) return { why: `nothing selected to resize (${name || "none"}), or no corner on the screen` };
      const was = JSON.stringify(s.page_editor.items[name]);
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
      const field = await where("page_words", 5);
      if (field && !((await ask())?.typing || []).length) await tap(field);
      await keys("Hi");
      const after = await until((now) => Object.keys(now.page_editor?.items || {}).length > before, 8);
      const notes = JSON.stringify(after.page_editor?.notes || {});
      note(`${Object.keys(after.page_editor?.items || {}).length - before} item added; notes ${notes.slice(0, 120)}`);
      return { done: Object.keys(after.page_editor?.items || {}).length > before && /Hi/.test(JSON.stringify(after.page_editor)),
        why: "Add words put no words on the page" };
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
      if (!(await press("phone_row_split_parts", 10))) return { why: "the plate's actions have no Split" };
      let s = await until((now) => (now.bricks || 0) > 1, 15);
      const split = s.bricks || 0;
      note(`split: ${split} parts (${(s.parts || []).join(", ")})`);
      if (split <= 1) return { why: `Split left ${split} part (said "${s.said}")` };
      if (!(await moreRow("select_all"))) return { why: "More has no Select all" };
      s = await until((now) => now.selected === split, 6);
      parts = await partsOnScreen();
      await hold(parts[0]);
      if (!(await press("phone_row_merge_parts", 10))) return { why: "the pieces' actions have no Merge" };
      s = await until((now) => now.bricks === 1, 15);
      note(`merged: ${s.bricks} part (${(s.parts || []).join(", ")}); said "${s.said}"`);
      return { done: s.bricks === 1 && (s.parts || [])[0] === "3020", why: `Merge left ${s.bricks} parts` };
    },

    async turn() {
      let parts = await partsOnScreen();
      if (!parts.length) return { why: "no part on the screen to turn" };
      // The row's Turn first, as a person tries it: it turns by the turn
      // step, 90° out of the box, with no way to choose another by finger.
      await hold(parts[0]);
      if (!(await press("phone_row_show_properties", 10))) return { why: "the part's actions have no Properties" };
      const field = await where("prop_turn", 15);
      if (!field) return { why: "Properties shows no Turn field a finger reaches" };
      await tap(field);
      await key("Control+a");
      await keys("15");
      await key("Enter");
      await page.waitForTimeout(1200);
      const now = await where("prop_turn", 5);
      const told = await ask();
      const text = (told?.texts || []).find((t) => now && t.box[0] <= now.x && now.x <= t.box[0] + t.box[2]
        && t.box[1] <= now.y && now.y <= t.box[1] + t.box[3] && /\d/.test(t.text));
      const degrees = text ? parseFloat(String(text.text).replace(/[^0-9.-]/g, "")) : NaN;
      note(`Properties' Turn reads "${text ? text.text : ""}"; the row's Turn turns by the turn step (90°)`);
      return { done: Math.abs(degrees - 15) < 0.5, why: `typed 15 in Properties' Turn, and it reads "${text ? text.text : "nothing"}"` };
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
      const tops = (await partsOnScreen()).slice(0, 4);
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
      const parts = (await partsOnScreen()).slice(0, 3);
      if (parts.length < 3) return { why: "fewer than three parts on the screen" };
      let code = 0;
      let painted = 0;
      for (const part of parts) {
        await tap(part);
        let s = await until((now) => now.selected === 1, 6);
        if (s.selected !== 1) {
          note(`a tap selected ${s.selected}`);
          continue;
        }
        if (!code) code = (s.selected_colours || [])[0] === 4 ? 1 : 4;
        await press("phone_colour");
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
        if (!(await press("phone_row_select_colour", 8))) return -1;
        return (await until((now) => now.selected > 1, 6)).selected;
      });
      note(`${painted} of 3 painted ${code === 4 ? "red" : "blue"}, one at a time (a tap in Select replaces the `
        + `selection, and nothing adds to it by finger); the same colour selects ${check}`);
      return { done: painted === 3 && check === 3, why: `${painted} of 3 painted; the same colour selected ${check}` };
    },

    async motions_play() {
      if (!(await moreRow("pose"))) return { why: "More has no Motions…" };
      let m = await untilRead("brickworksMotions", (now) => (now.suggested || []).length > 0 || (now.motions || []).length > 0, 90);
      note(`suggested ${JSON.stringify(m.suggested || []).slice(0, 80)}`);
      if (!(await press("motion_keep_0", 15))) return { why: "the panel's Keep is not on the screen" };
      m = await untilRead("brickworksMotions", (now) => (now.motions || []).length > 0, 15);
      if (!(m.motions || []).length) return { why: "Keep kept no motion" };
      if (!(await press("motion_play_0", 10))) return { why: "the motion's Play is not on the screen" };
      m = await untilRead("brickworksMotions", (now) => now.playing || /^Played/.test(now.status || ""), 60);
      note(`"${String(m.status || "").slice(0, 100)}"`);
      return { done: Boolean(m.playing || /^Played/.test(m.status || "")), why: "Play played nothing" };
    },

    async motions_record() {
      const kept = ((await read("brickworksMotions")).motions || []).length;
      if (!(await press("motions_new", 10))) return { why: "New motion is not on the screen" };
      if (!(await press("motions_record", 10))) return { why: "Record is not on the screen" };
      let m = await untilRead("brickworksMotions", (now) => now.recording, 10);
      if (!m.recording) return { why: "Record did not listen" };
      // A part of the model dragged across the view, as a door is swung: the
      // parts the app names on the screen, in turn, until one moves.
      const parts = await partsOnScreen();
      for (const part of parts.slice(0, 3)) {
        await drag({ x: part.x, y: part.y }, { x: part.x + 50, y: part.y + 20 }, 16, 300);
        note(`dragged ${part.part}: "${String((await read("brickworksMotions")).status || "").slice(0, 80)}"`);
      }
      await press("motions_record", 10);
      m = await untilRead("brickworksMotions", (now) => !now.recording, 10);
      const keys = (m.joints || []).reduce((n, j) => n + (Array.isArray(j.keys) ? j.keys.length : Number(j.keys || 0)), 0);
      note(`${(m.motions || []).length} motions (was ${kept}); ${keys} keys; "${String(m.status || "").slice(0, 100)}"`);
      return { done: keys >= 2, why: `a finger's drag in the view recorded ${keys} keys ("${String(m.status || "").slice(0, 80)}")` };
    },

    async motions_slider() {
      let m = await read("brickworksMotions");
      if (m.view !== "edit" && (m.motions || []).length) await untimed(() => press("motion_edit_0", 8));
      m = await untilRead("brickworksMotions", (now) => (now.joints || []).length > 0, 10);
      const slider = await where("motions_joint_0", 8);
      if (!slider) return { why: "no joint's slider on the screen" };
      const was = JSON.stringify((m.joints || [])[0]?.place);
      await drag({ x: slider.x - slider.w * 0.3, y: slider.y }, { x: slider.x + slider.w * 0.3, y: slider.y });
      m = await untilRead("brickworksMotions", (now) => JSON.stringify((now.joints || [])[0]?.place) !== was, 8);
      note(`the joint from ${was} to ${JSON.stringify((m.joints || [])[0]?.place)}`);
      return { done: JSON.stringify((m.joints || [])[0]?.place) !== was, why: "a finger's drag of the slider moved no joint" };
    },

    async simulate_play() {
      if (!(await moreRow("simulate"))) return { why: "More has no Simulate mechanism…" };
      let s = await untilRead("brickworksSimulate", (now) => now.open, 30);
      if (!s.open) return { why: "Simulate did not open" };
      if (!(await press("simulate_play", 15))) return { why: "Simulate's Play is not on the screen" };
      s = await untilRead("brickworksSimulate", (now) => now.playing, 15);
      note(`playing ${s.playing}; driver ${JSON.stringify(s.driver)}; "${String(s.status || s.readout || "").slice(0, 100)}"`);
      return { done: Boolean(s.playing), why: "Play did not play" };
    },

    async simulate_scrub() {
      let s = await read("brickworksSimulate");
      if (!s.open) return { why: "Simulate is not open" };
      if (s.playing) await untimed(() => press("simulate_play", 5));
      const slider = await where("simulate_scrub", 10);
      if (!slider) return { why: "the cycle's slider is not on the screen" };
      s = await read("brickworksSimulate");
      const was = JSON.stringify([s.turns, s.readout]);
      await drag({ x: slider.x - slider.w * 0.3, y: slider.y }, { x: slider.x + slider.w * 0.2, y: slider.y });
      s = await untilRead("brickworksSimulate", (now) => JSON.stringify([now.turns, now.readout]) !== was, 8);
      note(`from ${was.slice(0, 80)} to ${JSON.stringify([s.turns, s.readout]).slice(0, 80)}`);
      return { done: JSON.stringify([s.turns, s.readout]) !== was, why: "a finger's drag of the slider moved nothing" };
    },

    async simulate_drive() {
      let s = await read("brickworksSimulate");
      if (!s.open) return { why: "Simulate is not open" };
      const was = JSON.stringify(s.driver);
      const parts = await partsOnScreen();
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
    begin: (id) => { tally = { id, n: 0, said: [] }; },
    end: () => {
      const done = tally;
      tally = null;
      return done;
    },
    run: (id) => ACTED[id](),
  };
}
