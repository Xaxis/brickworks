// The app on a phone, built for a finger: a small house built by touch alone
// at 390 x 844 and 430 x 932, at three device pixels to the point, with
// touch events (Chromium's phone emulation), in SwiftShader.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 8811 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/phone_flow.mjs --url=http://127.0.0.1:8811/ --out=shots/phone
//   BW_BYPASS=… node tools/web/phone_flow.mjs --url=<preview>/app --out=DIR
//
// At each size (walk180's P1: the desktop shrunk, 14-point buttons, 9-point
// swatches, a drawer over half the model, "right-click" and "Shift-drag"):
//
//   1. The phone layout is on (window.brickworksControls names its row).
//   2. More, File, New: a model of its own.
//   3. Parts: the sheet comes up half the screen, the model above it; its
//      handle swiped up takes the whole screen, and down again half.
//   4. Searched for a 2 x 4 brick, its tile tapped: in hand, the sheet gone.
//   5. Six of them tapped down on the baseplate.
//   6. A door searched for and tapped down; a roof slope likewise.
//   7. Select, then a brick tapped: selected. Colour: big swatches; blue
//      tapped paints it (the part's colour read from the page).
//   8. Undo: the paint undone.
//   9. Two fingers dragged across the model turn the view; spread, they zoom.
//  10. A finger held on a part: its actions, the desktop's right-click menu.
//  11. More: every menu's commands.
//
// At every one of those the app is asked (window.brickworksAskPhone) for
// every target a finger has on the screen and every line of text, in points:
// no target under 44 on either side, no text under 12, nothing off the
// screen. Pictures of each go to --out, <size>_<n>_<what>.png, to look at.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8811/");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = String(args.out || "shots/phone");
const SIZES = String(args.sizes || "390x844,430x932").split(",");
mkdirSync(out, { recursive: true });

let failed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};
const say = (what) => console.log(`  --    ${what}`);

const browser = await launch();
try {
  for (const size of SIZES) {
    const [width, height] = size.split("x").map(Number);
    console.log(`\n${width} x ${height} at 3x, by a finger`);
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 3,
      isMobile: true, hasTouch: true });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
    });
    const cdp = await context.newCDPSession(page);
    let shot = 0;
    const picture = async (what) => {
      shot += 1;
      await page.screenshot({ path: `${out}/${width}_${String(shot).padStart(2, "0")}_${what}.png` });
    };
    const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
    const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
    const until = async (test, seconds = 30) => {
      for (let n = 0; n < seconds * 4; n++) {
        const s = await state();
        if (test(s)) return s;
        await page.waitForTimeout(250);
      }
      return state();
    };
    const where = async (name, seconds = 30) => {
      for (let n = 0; n < seconds * 4; n++) {
        const at = (await controls())[name];
        if (at) return at;
        await page.waitForTimeout(250);
      }
      return null;
    };
    const tap = async (at) => { await page.touchscreen.tap(at.x, at.y); await page.waitForTimeout(450); };
    const press = async (name) => {
      const at = await where(name);
      if (!at) { check(`"${name}" is on the screen`, false); return false; }
      await tap(at);
      return true;
    };
    const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
      touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
    // One finger dragged from a to b in steps.
    const drag = async (a, b, steps = 10) => {
      await touch("touchStart", [a]);
      for (let n = 1; n <= steps; n++) {
        await touch("touchMove", [{ x: a.x + (b.x - a.x) * n / steps, y: a.y + (b.y - a.y) * n / steps }]);
        await page.waitForTimeout(40);
      }
      await touch("touchEnd", []);
      await page.waitForTimeout(500);
    };
    // What a finger has and what is said, asked of the app, and judged.
    const audit = async (what) => {
      await page.waitForTimeout(700);
      await page.evaluate(() => { window.brickworksPhone = null; window.brickworksAskPhone = true; });
      let told = null;
      for (let n = 0; n < 40 && !told; n++) {
        await page.waitForTimeout(250);
        told = await page.evaluate(() => window.brickworksPhone);
      }
      await picture(what);
      if (!check(`${what}: the app said what is on the screen`, Boolean(told))) return null;
      const small = told.targets.filter((t) => t.box[2] < 44 || t.box[3] < 44);
      const tiny = told.texts.filter((t) => t.px < 12);
      const off = told.targets.concat(told.texts).filter((t) => t.off);
      check(`${what}: ${told.targets.length} targets, none under 44 points`
        + (small.length ? ` (${small.slice(0, 4).map((t) => `${t.name} ${t.box[2]}x${t.box[3]}`).join("; ")})` : ""),
        small.length === 0 && told.targets.length > 0);
      check(`${what}: ${told.texts.length} lines of text, none under 12 points`
        + (tiny.length ? ` (${tiny.slice(0, 4).map((t) => `"${t.text}" ${t.px}`).join("; ")})` : ""),
        tiny.length === 0);
      check(`${what}: nothing off the screen`
        + (off.length ? ` (${off.slice(0, 4).map((t) => `${t.name} at ${t.box}`).join("; ")})` : ""),
        off.length === 0);
      return told;
    };
    const sheet = async () => ((await page.evaluate(() => window.brickworksPhone)) || {}).phone || {};
    const sheetNow = async () => {
      await page.evaluate(() => { window.brickworksPhone = null; window.brickworksAskPhone = true; });
      for (let n = 0; n < 40; n++) {
        await page.waitForTimeout(250);
        const told = await page.evaluate(() => window.brickworksPhone);
        if (told) return told.phone || {};
      }
      return {};
    };
    const take = async (query) => {
      await press("phone_parts");
      const box = await where("part search");
      if (!box) return false;
      await tap(box);
      await page.keyboard.press("Control+a");
      await page.waitForTimeout(150);
      await page.keyboard.type(query, { delay: 40 });
      await page.waitForTimeout(1800);
      const tile = await where("first part", 20);
      if (!tile) return false;
      const found = (await state()).found || [];
      await tap(tile);
      const s = await until((now) => now.mode === "place" && String(now.held || "") === String(found[0] || ""), 20);
      return s.mode === "place" ? String(s.held) : "";
    };
    // A tap on the model that put a part down, near a point: a step aside
    // if the first spot takes nothing (a part already there).
    const putDown = async (at) => {
      const before = (await state()).bricks || 0;
      for (const [dx, dy] of [[0, 0], [14, 0], [0, 14], [-14, 0], [0, -14], [28, 10]]) {
        await tap({ x: at.x + dx, y: at.y + dy });
        const s = await until((now) => (now.bricks || 0) > before, 6);
        if ((s.bricks || 0) > before) return true;
      }
      return false;
    };

    // 1. The phone layout.
    await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
    const row = await where("phone_parts", 300);
    if (!check("the phone layout is on: its row along the foot", Boolean(row))) {
      await picture("never");
      await context.close();
      continue;
    }
    await until((s) => (s.awaited || 0) === 0 && s.mode, 120);
    await audit("ready");

    // 2. A model of its own.
    await press("phone_more");
    check("More: a sheet with every menu's commands", (await sheetNow()).sheet === "More");
    await audit("more");
    const newRow = await where("phone_row_new");
    if (check("More has File's New", Boolean(newRow))) {
      await tap(newRow);
      const discard = await where("new_discard", 3);
      if (discard) await tap(discard);
    }
    let s = await until((now) => now.bricks === 0, 20);
    check(`New: an empty model (${s.bricks} parts)`, s.bricks === 0);

    // 3. The parts sheet, and its handle.
    await press("phone_parts");
    let phone = await sheetNow();
    check(`Parts: a sheet half the screen high (${phone.sheet} ${phone.sheet_state})`,
      phone.sheet === "Parts" && phone.sheet_state === "half");
    const view = (await controls()).view;
    const handle = await where("phone_sheet_parts");
    if (handle) {
      check(`the model shows above it (sheet's top at ${handle.y - handle.h / 2} of ${height})`,
        handle.y - handle.h / 2 > height * 0.4);
      await audit("parts_half");
      await drag({ x: handle.x, y: handle.y }, { x: handle.x, y: 120 }, 8);
      phone = await sheetNow();
      check(`its handle swiped up: the whole screen (${phone.sheet_state})`, phone.sheet_state === "full");
      await audit("parts_full");
      const top = await where("phone_sheet_parts");
      await drag({ x: top.x, y: top.y }, { x: top.x, y: height * 0.5 }, 8);
      phone = await sheetNow();
      check(`and down: half again (${phone.sheet_state})`, phone.sheet_state === "half");
    }
    await press("phone_parts");

    // 4. A 2 x 4 brick, by searching.
    let held = await take("3001");
    check(`searched "3001" and tapped its tile: in hand (${held})`, held === "3001");
    phone = await sheetNow();
    check(`the sheet went with the pick (${phone.sheet || "none"})`, !phone.sheet);
    await audit("in_hand");

    // 5. Six bricks, on the baseplate's middle, framed by Fit.
    await press("phone_fit");
    await page.waitForTimeout(1500);
    await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
    let laid = null;
    for (let n = 0; n < 24 && !laid; n++) {
      await page.waitForTimeout(250);
      laid = await page.evaluate(() => window.brickworksLayout);
    }
    const middle = laid && laid.centre ? { x: laid.centre.x, y: laid.centre.y } : { x: width / 2, y: height / 2 };
    say(`the baseplate's middle at ${Math.round(middle.x)}, ${Math.round(middle.y)}`);
    const spots = [[-50, -20], [0, -20], [50, -20], [-50, 25], [0, 25], [50, 25]];
    let down = 0;
    for (const [dx, dy] of spots) {
      if (await putDown({ x: middle.x + dx, y: middle.y + dy })) down += 1;
    }
    s = await state();
    check(`six bricks tapped down (${down} of 6, ${s.bricks} on the baseplate)`, down === 6);
    await audit("six_bricks");

    // 6. A door and a roof.
    held = await take("60596");
    check(`a door frame tapped down (${held})`, held === "60596" && await putDown({ x: middle.x + 100, y: middle.y }));
    held = await take("3039");
    check(`a roof slope tapped down (${held})`, held === "3039" && await putDown({ x: middle.x, y: middle.y - 20 }));
    s = await state();
    check(`the house: ${s.bricks} parts (${(s.parts || []).join(", ")})`, s.bricks >= 8);
    await audit("house");

    // 7. Recolour one: Select, a tap on a brick, Colour, blue.
    await press("phone_select");
    s = await until((now) => now.mode === "select" && !now.carrying, 5);
    check(`Select: nothing in hand (${s.mode})`, s.mode === "select");
    await page.evaluate(() => { window.brickworksAskLayout = true; });
    await page.waitForTimeout(1200);
    const targets = ((await page.evaluate(() => window.brickworksLayout)) || {}).targets || [];
    const brick = targets.find((t) => t.part === "3001") || targets[0];
    if (check(`a part on the screen to tap (${targets.length} found)`, Boolean(brick))) {
      await tap({ x: brick.x, y: brick.y });
      s = await until((now) => now.selected === 1, 6);
      check(`tapped: it is selected (${s.selected})`, s.selected === 1);
      await press("phone_colour");
      phone = await sheetNow();
      check(`Colour: the swatch sheet (${phone.sheet})`, phone.sheet === "Colour");
      const blue = await where("phone_swatch_1", 5);
      await audit("colours");
      if (check("a blue swatch to tap", Boolean(blue))) {
        const was = await page.evaluate(() => window.brickworksPhone && window.brickworksPhone.phone);
        await tap(blue);
        const painted = await until((now) => (now.selected_colours || []).includes(1), 6);
        check(`blue tapped: the selected brick is blue (${JSON.stringify(painted.selected_colours)})`,
          (painted.selected_colours || []).includes(1));
        void was;
      }
      // 8. Undo.
      await press("phone_undo");
      s = await until((now) => !(now.selected_colours || []).includes(1), 6);
      check(`Undo: the paint undone (${JSON.stringify(s.selected_colours)})`,
        !(s.selected_colours || []).includes(1));
      await audit("undone");

      // 10. A finger held on it: its actions.
      // Held as a person holds: still, until something comes (a drawn frame
      // on SwiftShader under load can take longer than the hold itself).
      await touch("touchStart", [{ x: brick.x, y: brick.y }]);
      for (let n = 0; n < 8; n++) {
        await page.waitForTimeout(500);
        if ((await sheetNow()).sheet) break;
      }
      await touch("touchEnd", []);
      await page.waitForTimeout(600);
      phone = await sheetNow();
      check(`a finger held on a part: its actions (${phone.sheet})`, Boolean(phone.sheet)
        && !["Parts", "Colour", "More"].includes(phone.sheet));
      const actions = await audit("held");
      const rows = (actions ? actions.targets : []).filter((t) => /row_/.test(t.name)).length;
      check(`with the right-click menu's rows (${rows})`, rows >= 6);
      const done = await where(`phone_sheet_${String(phone.sheet || "").toLowerCase().replace(/ /g, "_")}_done`, 3);
      if (done) await tap(done);
      s = await state();
      check(`and nothing was taken off by the hold (${s.bricks} parts)`, s.bricks >= 8);
    }

    // 9. Two fingers turn the view and spread to zoom.
    const before = (await state()).view || {};
    const c = view ? { x: view.x, y: view.y } : { x: width / 2, y: height / 2 };
    await touch("touchStart", [{ x: c.x - 40, y: c.y }, { x: c.x + 40, y: c.y }]);
    for (let n = 1; n <= 10; n++) {
      await touch("touchMove", [{ x: c.x - 40 + n * 12, y: c.y }, { x: c.x + 40 + n * 12, y: c.y }]);
      await page.waitForTimeout(40);
    }
    await touch("touchEnd", []);
    await page.waitForTimeout(800);
    const turned = (await state()).view || {};
    check(`two fingers across: the view turned (yaw ${before.yaw?.toFixed?.(2)} to ${turned.yaw?.toFixed?.(2)})`,
      Math.abs((turned.yaw || 0) - (before.yaw || 0)) > 0.15);
    await touch("touchStart", [{ x: c.x - 30, y: c.y }, { x: c.x + 30, y: c.y }]);
    for (let n = 1; n <= 10; n++) {
      await touch("touchMove", [{ x: c.x - 30 - n * 8, y: c.y }, { x: c.x + 30 + n * 8, y: c.y }]);
      await page.waitForTimeout(40);
    }
    await touch("touchEnd", []);
    await page.waitForTimeout(800);
    const zoomed = (await state()).view || {};
    check(`spread: it zoomed in (distance ${Math.round(turned.distance)} to ${Math.round(zoomed.distance)})`,
      zoomed.distance < turned.distance * 0.9);
    s = await state();
    check(`and no part was put down or taken off by the fingers (${s.bricks})`, s.bricks >= 8);
    await audit("turned");

    check(`no script errors (${errors.length}${errors.length ? `: ${errors[0]}` : ""})`, errors.length === 0);
    await context.close();
  }
} finally {
  await browser.close();
}
console.log(failed ? `\n${failed} checks failed` : "\nthe app on a phone builds a house by a finger alone");
process.exit(failed ? 1 : 0);
