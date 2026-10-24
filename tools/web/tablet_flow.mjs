// The app on a tablet, built for a finger: a small house built by touch alone
// at 768 x 1024, 1024 x 768 and 1024 x 1366, at two device pixels to the
// point, with touch events (Chromium's mobile emulation), in SwiftShader.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 8811 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/tablet_flow.mjs --url=http://127.0.0.1:8811/ --out=shots/tablet
//   BW_BYPASS=… node tools/web/tablet_flow.mjs --url=<preview>/app --out=DIR
//
// A tablet was given the desktop driven by fingers: targets sized for a
// mouse (24 to 37 points), tooltips that never come, and nothing for a
// right click. So it gets the phone's layout (phone_flow.mjs), laid out
// wider: the parts a panel down the left that stays open while you build,
// and the colours, More and a part's actions a panel down the right, the
// model framed beside them. At each size:
//
//   1. The layout for a finger is on, laid out wide (window.brickworksControls
//      names its row; the app's audit says wide).
//   2. More, File, New: a model of its own.
//   3. Parts: a panel down the left between the bars, the row below it.
//   4. Searched for a 2 x 4 brick, its tile tapped: in hand, the panel kept.
//   5. Fit: the model framed beside the panel; six bricks tapped down there.
//   6. A door searched for and tapped down; a roof slope likewise.
//   7. Select, then a brick tapped: selected. Colour: a panel of big
//      swatches; blue tapped paints it (the part's colour read from the page).
//   8. Undo: the paint undone.
//   9. A finger held on a part: its actions, the desktop's right-click menu.
//  10. Two fingers dragged across the model turn the view; spread, they zoom.
//  11. The tablet turned the other way round: laid out again.
//
// At every one of those the app is asked (window.brickworksAskPhone) for
// every target a finger has on the screen and every line of text, in points:
// no target under 44 on either side, no text under 12, nothing off the
// screen. Where the app has no layout for a finger (the desktop's), the
// controls it names (window.brickworksControls) are counted instead, and
// the flow fails with how many are under 44 points. Pictures of each go to
// --out, <size>_<n>_<what>.png, to look at.
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
const out = String(args.out || "shots/tablet");
const SIZES = String(args.sizes || "768x1024,1024x768,1024x1366").split(",");
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
    let [width, height] = size.split("x").map(Number);
    console.log(`\n${width} x ${height} at 2x, by a finger`);
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2,
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
      await page.screenshot({ path: `${out}/${size}_${String(shot).padStart(2, "0")}_${what}.png` });
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
    const sheetNow = async () => {
      await page.evaluate(() => { window.brickworksPhone = null; window.brickworksAskPhone = true; });
      for (let n = 0; n < 40; n++) {
        await page.waitForTimeout(250);
        const told = await page.evaluate(() => window.brickworksPhone);
        if (told) return told.phone || {};
      }
      return {};
    };
    const open = async () => (await sheetNow()).sheets || [];
    // A part searched for and picked: the panel opened first if it is not.
    const take = async (query) => {
      if (!(await open()).includes("Parts")) await press("phone_parts");
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
    const layout = async () => {
      await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
      for (let n = 0; n < 24; n++) {
        await page.waitForTimeout(250);
        const laid = await page.evaluate(() => window.brickworksLayout);
        if (laid) return laid;
      }
      return null;
    };
    const edges = (box) => ({ left: box.x - box.w / 2, right: box.x + box.w / 2,
      top: box.y - box.h / 2, bottom: box.y + box.h / 2 });

    // 1. The layout for a finger, laid out wide.
    await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
    await until((s) => (s.awaited || 0) === 0 && s.mode, 300);
    const row = await where("phone_parts", 20);
    if (!check("the layout for a finger is on: its row along the foot", Boolean(row))) {
      // The desktop's, driven by fingers: what it names, measured.
      await page.waitForTimeout(3000);
      const named = Object.entries(await controls()).filter(([, at]) => at.w > 0 && at.h > 0);
      const small = named.filter(([, at]) => at.w < 44 || at.h < 44);
      const sizes = small.map(([, at]) => Math.min(at.w, at.h)).sort((a, b) => a - b);
      check(`the desktop's ${named.length} named controls, ${small.length} under 44 points`
        + (small.length ? ` (the median's short side ${sizes[Math.floor(sizes.length / 2)]}; `
          + `${small.slice(0, 5).map(([name, at]) => `${name} ${at.w}x${at.h}`).join("; ")})` : ""),
        small.length === 0);
      await audit("desktop");
      await context.close();
      continue;
    }
    let told = await audit("ready");
    check(`laid out wide, for a tablet (${JSON.stringify(told && told.phone && told.phone.wide)})`,
      Boolean(told && told.phone && told.phone.wide));

    // 2. A model of its own.
    await press("phone_more");
    check("More: a panel with every menu's commands", (await sheetNow()).sheet === "More");
    await audit("more");
    const newRow = await where("phone_row_new");
    if (check("More has File's New", Boolean(newRow))) {
      await tap(newRow);
      const discard = await where("new_discard", 3);
      if (discard) await tap(discard);
    }
    let s = await until((now) => now.bricks === 0, 20);
    check(`New: an empty model (${s.bricks} parts)`, s.bricks === 0);

    // 3. The parts panel, down the left between the bars.
    await press("phone_parts");
    let phone = await sheetNow();
    check(`Parts: a panel (${phone.sheet} ${phone.sheet_state})`,
      phone.sheet === "Parts" && phone.sheet_state === "side");
    const panel = await where("phone_panel_parts", 5);
    const foot = await where("phone_parts", 5);
    if (check("the panel is on the screen", Boolean(panel && foot))) {
      const e = edges(panel);
      check(`down the left, the model beside it (${Math.round(e.left)} to ${Math.round(e.right)} of ${width})`,
        e.left <= 1 && e.right <= width * 0.56);
      check(`the row below it (panel's foot ${Math.round(e.bottom)}, the row's top ${Math.round(edges(foot).top)})`,
        e.bottom <= edges(foot).top + 1);
    }
    await audit("parts");

    // 4. A 2 x 4 brick, by searching.
    let held = await take("3001");
    check(`searched "3001" and tapped its tile: in hand (${held})`, held === "3001");
    check(`the panel stays for the next part (${(await open()).join(", ") || "none"})`,
      (await open()).includes("Parts"));
    await audit("in_hand");

    // 5. Six bricks, on the baseplate's middle, framed by Fit beside the panel.
    await press("phone_fit");
    await page.waitForTimeout(2500);
    let laid = await layout();
    const middle = laid && laid.centre ? { x: laid.centre.x, y: laid.centre.y } : { x: width / 2, y: height / 2 };
    const beside = await where("phone_panel_parts", 3);
    check(`the baseplate's middle at ${Math.round(middle.x)}, ${Math.round(middle.y)}: beside the panel`
      + (beside ? ` (its edge at ${Math.round(edges(beside).right)})` : ""),
      !beside || middle.x > edges(beside).right + 60);
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
    laid = await layout();
    const targets = (laid || {}).targets || [];
    const brick = targets.find((t) => t.part === "3001") || targets[0];
    if (check(`a part on the screen to tap (${targets.length} found)`, Boolean(brick))) {
      await tap({ x: brick.x, y: brick.y });
      s = await until((now) => now.selected === 1, 6);
      check(`tapped: it is selected (${s.selected})`, s.selected === 1);
      await press("phone_colour");
      phone = await sheetNow();
      check(`Colour: the swatch panel (${phone.sheet})`, phone.sheet === "Colour");
      const blue = await where("phone_swatch_1", 5);
      await audit("colours");
      if (check("a blue swatch to tap", Boolean(blue))) {
        await tap(blue);
        const painted = await until((now) => (now.selected_colours || []).includes(1), 6);
        check(`blue tapped: the selected brick is blue (${JSON.stringify(painted.selected_colours)})`,
          (painted.selected_colours || []).includes(1));
      }
      // 8. Undo.
      await press("phone_undo");
      s = await until((now) => !(now.selected_colours || []).includes(1), 6);
      check(`Undo: the paint undone (${JSON.stringify(s.selected_colours)})`,
        !(s.selected_colours || []).includes(1));
      await audit("undone");

      // 9. A finger held on it: its actions. Held as a person holds: still,
      // until something comes (a drawn frame on SwiftShader under load can
      // take longer than the hold itself). The part is found again first:
      // a panel opening or closing slides the model to the room beside it.
      await page.waitForTimeout(1500);
      laid = await layout();
      const again = ((laid || {}).targets || []).find((t) => t.brick === brick.brick) || brick;
      await touch("touchStart", [{ x: again.x, y: again.y }]);
      for (let n = 0; n < 8; n++) {
        await page.waitForTimeout(500);
        const now = await sheetNow();
        if (now.sheet && !["Parts", "Colour", "More"].includes(now.sheet)) break;
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

    // 10. Two fingers turn the view and spread to zoom.
    const view = (await controls()).view;
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

    // 11. The tablet turned round, the parts panel open: laid out again.
    if (!(await open()).includes("Parts")) await press("phone_parts");
    [width, height] = [height, width];
    await page.setViewportSize({ width, height });
    await page.waitForTimeout(3000);
    say(`turned round: ${width} x ${height}`);
    const rowNow = await where("phone_parts", 20);
    check(`the row along the foot again (at ${rowNow ? Math.round(rowNow.y) : "none"} of ${height})`,
      Boolean(rowNow) && rowNow.y > height * 0.85 && rowNow.y < height);
    const panelNow = await where("phone_panel_parts", 5);
    if (check("the parts panel still open", Boolean(panelNow))) {
      const e = edges(panelNow);
      check(`down the left again (${Math.round(e.left)} to ${Math.round(e.right)} of ${width},`
        + ` ${Math.round(e.top)} to ${Math.round(e.bottom)} of ${height})`,
        e.left <= 1 && e.right <= width * 0.56 && e.bottom <= height);
    }
    await audit("turned_round");
    s = await state();
    check(`the house kept (${s.bricks} parts)`, s.bricks >= 8);

    check(`no script errors (${errors.length}${errors.length ? `: ${errors[0]}` : ""})`, errors.length === 0);
    await context.close();
  }
} finally {
  await browser.close();
}
console.log(failed ? `\n${failed} checks failed` : "\nthe app on a tablet builds a house by a finger alone");
process.exit(failed ? 1 : 0);
