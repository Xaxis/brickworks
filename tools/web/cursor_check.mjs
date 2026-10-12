// Does the pointer say what the mouse will do, in a real browser?
//
//   node tools/web/cursor_check.mjs [--url=https://brickworks.diy/app] [--bypass=…]
//        [--scales=1,2] [--out=shots/cursors] [--no-wheel]
//
// The owner, on the live site: "we're not seeing the cursor change based on
// the mode and context, as you obviously need to do." So each row of the
// table in .claude/skills/verify/features/view.md (`pointer cursors`) is
// reached with the real mouse and keyboard — every tool, Space and Alt held,
// a part in hand, a part dragged, the view tools, and the interface — and the
// canvas's computed CSS cursor is read back. Not the app's word for it:
// Godot shows a cursor in a browser as CSS on the canvas, and a browser can
// refuse a picture (too big, a URL it will not load, a syntax it does not
// know) without a word to the page.
//
// A picture is identified by its pixels: the 1x picture the CSS carries is
// decoded in the page and compared with every SVG in assets/ui/cursors, drawn
// by the browser, and the nearest is the one shown. Its two resolutions must
// decode to 32 and 64 pixels; on a screen with two device pixels to the CSS
// pixel the 64 is the one shown, so a 2x screen gets a sharp pointer.
//
// Playwright's screenshots do not draw the pointer, so each state's picture
// is drawn into the page where the pointer is, from the CSS the browser
// computed, and the area around it saved: shots/cursors/web_<state>_<n>x.png.
// The pictures themselves, decoded from that CSS, are laid out on dark and
// light in web_pictures_<n>x.png, and every reading goes in
// cursors_<n>x.json.
//
// Then, unless --no-wheel: the wheel over the interface is the interface's,
// measured in the view's pixels (see `camera controls`).
//
// Needs .env sourced (browser.mjs signs the test account in). On a preview,
// --bypass or VERCEL_BYPASS for its protection.
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { launch, openColumnFor } from "./browser.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const bypass = args.bypass || (/vercel\.app/.test(url) ? process.env.VERCEL_BYPASS : "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/cursors";
const scales = String(args.scales || args.scale || "1,2").split(",").map(Number);
const wheelToo = !args["no-wheel"];
mkdirSync(out, { recursive: true });

// The pictures as the checkout draws them, by state.
const here = dirname(fileURLToPath(import.meta.url));
const svgDir = join(here, "../../assets/ui/cursors");
const PICTURES = Object.fromEntries(readdirSync(svgDir).filter((f) => f.endsWith(".svg"))
  .map((f) => [f.slice(0, -4), readFileSync(join(svgDir, f), "utf8")]));
// The states the system draws, as the CSS keyword Godot gives each.
const SYSTEM = { arrow: "default", select: "pointer", blocked: "not-allowed",
  busy: "progress", move: "move" };

const failures = [];
const browser = await launch();
for (const scale of scales) await run(scale);
await browser.close();
if (failures.length) {
  console.log(`${failures.length} FAILED: ${failures.join("; ")}`);
  process.exit(1);
}
console.log(`every context shows its cursor in the browser, at ${scales.join("x and ")}x`);


async function run(scale) {
  console.log(`at ${scale}x`);
  // Drawn in software, a frame at a device ratio of two is four times the
  // pixels, and on a busy machine took 10-15 s.
  const slow = Math.max(1, scale * scale);
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: scale });
  page.on("pageerror", (e) => console.log(`  page error: ${String(e).slice(0, 160)}`));
  const seen = [];
  const pictures = {};
  const shotOnce = new Set();
  // A picture of each context at 1x. At 2x a screenshot of the WebGL page
  // drawn in software took up to a minute and a half each, so only a few,
  // the pictures sheet below shows every 64 px picture anyway.
  const shootAt2x = new Set(["select_nothing", "tool_paint", "place", "grabbing_part"]);
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  const until = Date.now() + 400000;
  while (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).view)))) {
    if (Date.now() > until) throw new Error("the app never came up (signed in? .env sourced?)");
    await page.waitForTimeout(1000);
  }
  // The car that greets a first visit assembles itself; let it, then frame it.
  await page.waitForTimeout(15000);
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
  async function where(name) {
    for (let n = 0; n < 8; n += 1) {
      const found = (await controls())[name];
      if (found) return found;
      await page.waitForTimeout(500);
    }
    return null;
  }
  const view = await where("view");
  await page.mouse.move(view.x, view.y);
  await page.mouse.click(view.x, view.y); // ends the animation if it is still going
  await page.keyboard.press("Escape");
  await page.keyboard.press("Escape");
  await page.keyboard.press("Digit0");
  await page.keyboard.press("KeyF");
  await page.waitForTimeout(2500 * slow);

  async function read() {
    return page.evaluate(() => ({
      state: window.brickworksCursor || "",
      css: getComputedStyle(document.getElementById("canvas")).cursor,
    }));
  }

  /// The nearest of the checkout's pictures to the 1x picture a style
  /// shows, and how near: the mean difference per pixel, 0 to 1.
  async function identify(css) {
    return page.evaluate(async ({ style, refs }) => {
      const src = (style.match(/url\("?([^")]+)"?\)/) || [])[1];
      if (!src) return null;
      const load = async (from) => {
        const img = new Image();
        img.src = from;
        await img.decode();
        return img;
      };
      const pixels = (img) => {
        const c = document.createElement("canvas");
        c.width = 32;
        c.height = 32;
        const ctx = c.getContext("2d");
        ctx.drawImage(img, 0, 0, 32, 32);
        return ctx.getImageData(0, 0, 32, 32).data;
      };
      if (!window.__cursorRefs) {
        window.__cursorRefs = {};
        for (const [name, svg] of Object.entries(refs)) {
          window.__cursorRefs[name] = pixels(await load(
            `data:image/svg+xml;base64,${btoa(unescape(encodeURIComponent(svg)))}`));
        }
      }
      const shown = pixels(await load(src));
      let best = "";
      let score = Infinity;
      for (const [name, ref] of Object.entries(window.__cursorRefs)) {
        let diff = 0;
        for (let i = 0; i < shown.length; i += 4) {
          const a = shown[i + 3] / 255;
          const b = ref[i + 3] / 255;
          diff += Math.abs(a - b);
          for (let k = 0; k < 3; k += 1) diff += Math.abs(shown[i + k] * a - ref[i + k] * b) / 255 / 3;
        }
        diff /= shown.length / 4;
        if (diff < score) { score = diff; best = name; }
      }
      return { name: best, score };
    }, { style: css, refs: PICTURES });
  }

  /// The sizes the pictures in a style decode to.
  async function sizes(css) {
    return page.evaluate(async (style) => {
      const urls = [...style.matchAll(/url\("?([^")]+)"?\)/g)].map((m) => m[1]);
      const found = [];
      for (const u of urls) {
        const img = new Image();
        img.src = u;
        await img.decode();
        found.push(`${img.naturalWidth}x${img.naturalHeight}`);
      }
      return found;
    }, css);
  }

  /// Whether a style shows a state: its keyword, or its picture at 1x and
  /// 2x through image-set().
  async function shows(css, wanted) {
    if (SYSTEM[wanted]) return { ok: css.trim() === SYSTEM[wanted], what: css.trim() };
    if (!/url\(/.test(css)) return { ok: false, what: css.trim() || "(none)" };
    const seenAs = await identify(css);
    const what = seenAs ? `the ${seenAs.name} picture (${seenAs.score.toFixed(3)})` : "no picture";
    if (!seenAs || seenAs.name !== wanted || seenAs.score > 0.045) return { ok: false, what };
    if (!/image-set\(/.test(css)) return { ok: false, what: `${what}, 1x only (no image-set)` };
    const both = await sizes(css);
    if (both.join(" ") !== "32x32 64x64") return { ok: false, what: `${what}, sized ${both.join(" ")}` };
    return { ok: true, what: `${what}, 32 and 64 px` };
  }

  /// Poll until the canvas shows a state, for up to ms. `app` is the state
  /// the app should say it is in, or null where a control is under the
  /// pointer and the control's own shape wins.
  async function expect(name, what, wanted, at, app = wanted, ms = 8000 * slow) {
    const end = Date.now() + ms;
    let last = { state: "", css: "" };
    let verdict = { ok: false, what: "" };
    while (Date.now() < end) {
      last = await read();
      if (app === null || last.state === app) {
        verdict = await shows(last.css, wanted);
        if (verdict.ok) break;
      }
      await page.waitForTimeout(60);
    }
    if (!verdict.ok) verdict = await shows(last.css, wanted);
    const said = app === null ? "" : ` (the app says ${last.state || "nothing"})`;
    console.log(`  ${verdict.ok ? "ok  " : "FAIL"}  ${what}: wanted ${wanted}, shows ${verdict.what}${said}`);
    if (!verdict.ok) failures.push(`${scale}x ${what}`);
    seen.push({ name, what, wanted, ok: verdict.ok, state: last.state, shows: verdict.what });
    if (/url\(/.test(last.css)) {
      const urls = [...last.css.matchAll(/url\("?(data:image\/png;base64,[^")]+)"?\)/g)].map((m) => m[1]);
      if (urls.length && !pictures[wanted]) pictures[wanted] = urls;
    }
    if (!shotOnce.has(name) && (scale === 1 || shootAt2x.has(name))) {
      shotOnce.add(name);
      await shot(name, at, last.css);
    }
    return verdict.ok;
  }

  /// Draw the cursor the browser computed where the pointer is, and save
  /// the area around it.
  async function shot(name, at, css) {
    await page.evaluate(({ x, y, style }) => {
      document.getElementById("cursor-shown")?.remove();
      const urls = [...style.matchAll(/url\("?([^")]+)"?\)/g)].map((m) => m[1]);
      const hot = style.match(/\)\s+(\d+)\s+(\d+)\s*(,|$)/);
      let shown;
      if (urls.length) {
        shown = document.createElement("img");
        shown.src = urls[urls.length - 1];
        Object.assign(shown.style, { width: "32px", height: "32px",
          left: `${x - (hot ? Number(hot[1]) : 0)}px`, top: `${y - (hot ? Number(hot[2]) : 0)}px` });
      } else {
        // A cursor the system draws: say which, where it is.
        shown = document.createElement("div");
        shown.textContent = `system cursor: ${style}`;
        Object.assign(shown.style, { left: `${x + 6}px`, top: `${y + 10}px`, padding: "2px 6px",
          font: "12px sans-serif", color: "#fff", background: "rgba(0,0,0,0.75)", borderRadius: "4px" });
        const dot = document.createElement("div");
        Object.assign(dot.style, { position: "absolute", left: "-10px", top: "-14px", width: "6px",
          height: "6px", borderRadius: "3px", background: "#ff3b3b" });
        shown.appendChild(dot);
      }
      shown.id = "cursor-shown";
      Object.assign(shown.style, { position: "fixed", zIndex: 99999, pointerEvents: "none" });
      document.body.appendChild(shown);
    }, { x: at.x, y: at.y, style: css });
    try {
      await page.screenshot({ path: `${out}/web_${name}_${scale}x.png`, timeout: 90000,
        clip: { x: Math.max(at.x - 120, 0), y: Math.max(at.y - 80, 0), width: 240, height: 160 } });
    } catch {
      console.log(`        (no picture of ${name}: the page would not hold still)`);
    }
    await page.evaluate(() => document.getElementById("cursor-shown")?.remove());
  }

  async function moveTo(at) {
    await page.mouse.move(at.x + 2, at.y + 1);
    await page.mouse.move(at.x, at.y);
    await page.waitForTimeout(300 * slow);
  }

  /// Whether a part is under a point, by what the app says a click there
  /// would do: the status line in Select, or the pointing hand of a build
  /// that has no status line.
  async function overPart(at) {
    await moveTo(at);
    const end = Date.now() + 2500 * slow;
    let hint = "";
    while (Date.now() < end) {
      hint = String((await state()).hint || "");
      const now = await read();
      if (hint.includes("click selects it") || (!hint && now.state === "select")) return true;
      if (hint) return false;
      await page.waitForTimeout(150);
    }
    return false;
  }
  const spot = (dx, dy) => ({ x: view.x + dx, y: view.y + dy });
  let part = null;
  for (const at of [spot(0, 0), spot(0, 30), spot(-40, 20), spot(40, 20), spot(0, -30), spot(-80, 40), spot(80, 40)]) {
    if (await overPart(at)) { part = at; break; }
  }
  let nothing = null;
  for (const at of [spot(-300, 230), spot(300, 230), spot(-320, -60), spot(320, -60), spot(0, 300), spot(0, -260)]) {
    if (!(await overPart(at))) { nothing = at; break; }
  }
  if (!part || !nothing) {
    console.log(`  FAIL  found ${part ? "" : "no part to point at"}${!part && !nothing ? " and " : ""}${nothing ? "" : "nowhere without one"}`);
    failures.push(`${scale}x finding a part and nothing`);
    await page.close();
    return;
  }

  console.log("  Select");
  await moveTo(part);
  await expect("select_part", "Select, over a part: a click picks it", "select", part);
  await moveTo(nothing);
  await expect("select_nothing", "Select, over nothing: a drag turns the view", "orbit", nothing);
  await page.keyboard.down("Shift");
  await moveTo(nothing);
  await expect("select_shift", "...Shift held: a drag slides it", "hand", nothing);
  await page.keyboard.up("Shift");

  console.log("  the tools, over a part");
  for (const [tool, wanted] of [["paint", "paint"], ["delete", "delete"], ["hide", "hide"],
    ["clone", "copy"], ["rotate", "rotate"], ["hinge", "hinge"], ["move", "move"]]) {
    const button = await where(`tool_mode_${tool}`);
    if (!button) {
      console.log(`  FAIL  there is no ${tool} tool on the toolbar`);
      failures.push(`${scale}x no ${tool} tool`);
      continue;
    }
    if (tool === "paint") {
      await moveTo(button);
      await expect("button", "over a tool's button", "select", button, null);
    }
    // The tool on, by the app's word, before its pointer is judged: a
    // click that missed would otherwise read as a wrong pointer.
    let on = false;
    for (let attempt = 0; attempt < 2 && !on; attempt += 1) {
      const at = attempt === 0 ? button : await where(`tool_mode_${tool}`);
      await moveTo(at);
      await page.mouse.click(at.x, at.y);
      const end = Date.now() + 3000 * slow;
      while (Date.now() < end && !on) {
        on = (await state()).mode === tool;
        if (!on) await page.waitForTimeout(150);
      }
      if (!on) {
        console.log(`        (a click at ${at.x},${at.y} left the tool at ${(await state()).mode}; `
          + `the button is now said to be at ${JSON.stringify(await where(`tool_mode_${tool}`))})`);
      }
    }
    await moveTo(part);
    await expect(`tool_${tool}`, `${tool[0].toUpperCase()}${tool.slice(1)}`, wanted, part);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(300 * slow);
  }

  console.log("  the view tools");
  for (const [key, tool, wanted] of [["KeyO", "Orbit", "orbit"], ["KeyH", "Pan", "hand"], ["KeyZ", "Zoom", "zoom_in"]]) {
    await moveTo(part);
    await page.keyboard.press(key);
    await expect(`view_${wanted}`, `the ${tool} tool`, wanted, part);
    if (tool === "Orbit") {
      await page.mouse.down();
      for (let n = 1; n <= 6; n += 1) await page.mouse.move(part.x + n * 8, part.y);
      await expect("grabbing_view", "...dragging the view", "grabbing", { x: part.x + 48, y: part.y });
      await page.mouse.up();
      await expect(`view_${wanted}_after`, "...and let go of", wanted, { x: part.x + 48, y: part.y });
    }
  }
  await page.keyboard.press("Escape");
  await page.keyboard.press("Digit0");
  await page.keyboard.press("KeyF");
  await page.waitForTimeout(1500 * slow);

  console.log("  keys held");
  await moveTo(part);
  await page.keyboard.down("Space");
  await expect("space", "Space held: a drag slides the view", "hand", part);
  await page.keyboard.up("Space");
  await page.keyboard.down("Alt");
  await expect("alt", "Alt held: a drag turns it", "orbit", part);
  await page.keyboard.up("Alt");
  await expect("select_again", "...and let go of", "select", part);

  console.log("  a part in hand");
  await page.keyboard.press("KeyQ");
  // Where it goes: on the model, or on the baseplate round it.
  let fits = part;
  for (const at of [part, spot(0, 40), spot(-60, 60), spot(60, 60), nothing]) {
    await moveTo(at);
    await page.waitForTimeout(300 * slow);
    if ((await read()).state === "place") { fits = at; break; }
  }
  await expect("place", "a part in hand, where it would go", "place", fits);
  // Up from the model into the sky, where there is nothing to put it on —
  // looking from the front, level: from above every ray down reaches the
  // ground, which a part can go on.
  await page.keyboard.press("Digit1");
  await page.waitForTimeout(1500 * slow);
  let sky = null;
  for (let y = view.y - 40; y > 60; y -= 40) {
    const at = { x: view.x, y };
    await moveTo(at);
    await page.waitForTimeout(300 * slow);
    const now = await read();
    if (!["place", "blocked", "busy"].includes(now.state)) { sky = at; break; }
  }
  if (sky) await expect("in_hand_nothing", "...over nothing it could go on: a drag turns the view", "orbit", sky);
  else {
    console.log("  FAIL  nowhere above the model without a ghost");
    failures.push(`${scale}x no sky`);
  }
  await page.keyboard.press("Digit0");
  await page.keyboard.press("KeyF");
  await page.waitForTimeout(1500 * slow);
  // A spot the part is refused, if the greeting model has one: the
  // builder settles a part on whatever is under it, so it is rare by
  // design. The rule and its shape are cursor_probe's on the desktop.
  let refused = null;
  for (let dx = -160; dx <= 160 && !refused; dx += 40) {
    for (let dy = -60; dy <= 120 && !refused; dy += 30) {
      const at = spot(dx, dy);
      await page.mouse.move(at.x, at.y);
      await page.waitForTimeout(120 * slow);
      if ((await read()).state === "blocked") refused = at;
    }
  }
  if (refused) await expect("blocked", "...where it is refused", "blocked", refused);
  else console.log("        (no refused spot on this model under the pointer; cursor_probe shows that one)");
  await page.keyboard.press("Escape");
  await page.keyboard.press("Escape");

  console.log("  a part dragged");
  await moveTo(part);
  await expect("select_before_drag", "Select, over a part", "select", part);
  const bricks = (await state()).bricks;
  await page.mouse.down();
  for (let n = 1; n <= 6; n += 1) await page.mouse.move(part.x + n * 7, part.y + n * 2);
  const dragged = { x: part.x + 42, y: part.y + 12 };
  await expect("grabbing_part", "dragging a part", "grabbing", dragged);
  await page.mouse.up();
  await page.waitForTimeout(600 * slow);
  await page.keyboard.press(process.platform === "darwin" ? "Meta+KeyZ" : "Control+KeyZ");
  await page.waitForTimeout(600 * slow);
  const after = (await state()).bricks;
  if (after !== bricks) {
    console.log(`  FAIL  the drag and its undo changed the count, ${bricks} -> ${after}`);
    failures.push(`${scale}x drag changed the model`);
  }

  console.log("  the interface");
  const save = await where("save");
  if (save) {
    await moveTo(save);
    await expect("ui_button", "over Save", "select", save, null);
  }
  const name = await where("model_name");
  if (name) {
    await moveTo(name);
    await page.waitForTimeout(300);
    const css = (await read()).css.trim();
    const ok = css === "text";
    console.log(`  ${ok ? "ok  " : "FAIL"}  over the model's name: wanted text, shows ${css}`);
    if (!ok) failures.push(`${scale}x text field`);
    seen.push({ name: "ui_text", what: "over the model's name", wanted: "text", ok, shows: css });
  }
  const cube = (await controls()).cube_top || (await controls()).cube_front || (await where("cube_turn_right"));
  if (cube) {
    await moveTo(cube);
    await expect("ui_cube", "over the view cube", "select", cube, null);
  } else {
    console.log("  FAIL  there is no view cube on the page");
    failures.push(`${scale}x no view cube`);
  }

  if (wheelToo) await wheelOverTheInterface(page, view, slow, where, overPart, scale);

  writeFileSync(`${out}/cursors_${scale}x.json`, JSON.stringify({ url, scale, seen }, null, 2));
  // Closed first: at 2x the app's page, drawn in software, kept the
  // browser too busy to take even this static picture in 30 s.
  await page.close();
  // The pictures themselves, as the browser decoded them from the CSS, on
  // dark and on light, 1x then 2x: what a person would see. A picture to
  // look at, not a gate.
  const sheet = await browser.newPage({ viewport: { width: 760, height: 120 + 90 * Object.keys(pictures).length } });
  await sheet.setContent(`<body style="margin:0;font:12px sans-serif;background:#6b7078;color:#fff">${
    Object.entries(pictures).map(([state, urls]) => `<div style="display:flex;align-items:center;gap:12px;padding:8px">
      <div style="width:90px">${state}</div>
      ${["#1a1c21", "#d9dbe0"].map((ground) => urls.map((u, n) => `<div style="background:${ground};padding:6px">
        <img src="${u}" style="width:${32 * (n + 1)}px;height:${32 * (n + 1)}px;image-rendering:pixelated"></div>`).join("")).join("")}
    </div>`).join("")}</body>`);
  await sheet.screenshot({ path: `${out}/web_pictures_${scale}x.png`, fullPage: true, timeout: 120000 })
    .catch(() => console.log("        (no picture of the pictures: the browser would not hold still)"));
  await sheet.close();
}


// -- the wheel over the interface ---------------------------------------------
//
// Asked for by the owner: scrolling in a dialog or a panel went on to zoom the
// model behind it. Measured in the pixels of the view, around whatever is
// open, against the same wheel over the model moving them — so a view that
// ignored every wheel would fail here too.
async function wheelOverTheInterface(page, at, slow, where, overPart, scale) {
  console.log("  the wheel over the interface");
  async function viewPrint(x, y, w, h) {
    return page.evaluate(({ x, y, w, h }) => {
      const canvas = document.getElementById("canvas");
      const k = canvas.width / canvas.clientWidth;
      const probe = document.createElement("canvas");
      probe.width = 24;
      probe.height = 24;
      const ctx = probe.getContext("2d");
      ctx.drawImage(canvas, x * k, y * k, w * k, h * k, 0, 0, 24, 24);
      const { data } = ctx.getImageData(0, 0, 24, 24);
      const values = [];
      for (let i = 0; i < data.length; i += 4) values.push((data[i] + data[i + 1] + data[i + 2]) / 3);
      return values;
    }, { x, y, w, h });
  }
  const differ = (a, b) => a.reduce((t, v, i) => t + Math.abs(v - b[i]), 0) / a.length;
  async function scrolled(what, point, regions, shouldMove, around = null) {
    await page.mouse.move(point.x, point.y);
    // As long before as after: the ghost goes when the pointer leaves the
    // model, and at a device ratio of two in software that is a frame or
    // two of 10-15 s. Its going, caught between the two pictures, read as
    // the view moving.
    await page.waitForTimeout(8000 * slow);
    const before = [];
    for (const r of regions) before.push(await viewPrint(...r));
    if (around) await around.open();
    for (let n = 0; n < 4; n += 1) { await page.mouse.wheel(0, 240); await page.waitForTimeout(400); }
    for (let n = 0; n < 8; n += 1) { await page.mouse.wheel(0, -240); await page.waitForTimeout(400); }
    await page.keyboard.down("Shift");
    for (let n = 0; n < 3; n += 1) { await page.mouse.wheel(0, 240); await page.waitForTimeout(400); }
    await page.keyboard.up("Shift");
    if (around) await around.close();
    await page.waitForTimeout(8000 * slow);
    let moved = 0;
    let cells = 0;
    let total = 0;
    for (let i = 0; i < regions.length; i += 1) {
      const after = await viewPrint(...regions[i]);
      moved = Math.max(moved, differ(before[i], after));
      cells += after.filter((v, n) => Math.abs(v - before[i][n]) > 8).length;
      total += after.length;
    }
    const share = `${Math.round((100 * cells) / total)}% of it`;
    const ok = shouldMove ? moved > 2.0 : moved < 1.0;
    console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}: the view ${moved > 1.0 ? "moved" : "stayed"} (${moved.toFixed(2)}, ${share})`);
    if (!ok) failures.push(`${scale}x wheel ${what}`);
  }
  await page.keyboard.press("Escape");
  await page.keyboard.press("Digit0");
  await page.keyboard.press("KeyF");
  const size = await page.evaluate(() => {
    const c = document.getElementById("canvas");
    return { w: c.clientWidth, h: c.clientHeight };
  });
  // The model's part of the window as it is now. On a laptop the columns
  // take turns, and opening the parts bin moves the model over: measured
  // around where the view was before, the region took in the bin, and the
  // list scrolling under the wheel read as the view moving.
  async function wholeView() {
    const c = (await where("view")) || at;
    const half = { w: Math.min(c.x - 20, size.w - c.x - 20, 360), h: Math.min(c.y - 60, 300) };
    return [[c.x - half.w, c.y - half.h, half.w * 2, half.h * 2]];
  }
  // The assistant shows the brief once there is a key, and the key form
  // before; whichever is up.
  for (const [what, keys] of [["over the parts bin", ["parts list"]],
    ["over the assistant panel", ["brief", "key_field"]], ["over the toolbar", ["save"]]]) {
    let point = null;
    // On a laptop the columns take turns: open this one's first.
    await openColumnFor(page, keys[0]);
    for (const key of keys) {
      point = await page.evaluate((k) => (window.brickworksControls || {})[k], key);
      if (point) break;
    }
    if (point) await scrolled(what, point, await wholeView(), false);
    else console.log(`        (no ${keys.join(" or ")} on screen at ${scale}x, so not checked there)`);
  }
  const here = (await where("view")) || at;
  await overPart(here);
  await scrolled("over the controls panel", here, await wholeView(), false, {
    open: async () => { await page.keyboard.press("Comma"); await page.waitForTimeout(3000 * slow); },
    close: async () => { await page.keyboard.press("Escape"); },
  });
  await overPart(here);
  await scrolled("over the model, which it should move", here, await wholeView(), true);
}
