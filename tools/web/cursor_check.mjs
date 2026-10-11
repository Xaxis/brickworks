// Does the pointer say what the mouse will do, in a real browser?
//
//   node tools/web/cursor_check.mjs --url=http://127.0.0.1:8731/ [--out=shots/cursors] [--scale=2]
//
// Godot shows a cursor in a browser as CSS on the canvas, and a custom
// one as a picture in that CSS. Whether it got there is a question only a
// browser can answer: the desktop probe (src/dev/cursor_probe.gd) reads
// the shape the window was given, and a browser can refuse a cursor
// picture — too big, a URL it will not load, a syntax it does not know —
// without a word to the page.
//
// So each state is reached with the real mouse and keyboard, and the
// canvas's computed cursor is read back. A picture's two resolutions are
// decoded in the page to check they are 32 and 64 pixels: on a screen
// with two device pixels to the CSS pixel, the 64 is the one shown.
//
// Playwright's screenshots do not draw the pointer. Each state's picture
// is therefore drawn into the page where the pointer is, from the CSS the
// browser computed — not from anything the app claims — and the area
// around it saved, so what the cursor looked like can be seen as well as
// read. The summary is written beside them as cursors.json.
import { mkdirSync, writeFileSync } from "node:fs";
import { launch } from "./browser.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8731/";
const out = args.out || "shots/cursors";
const scale = Number(args.scale || 2);
// How much longer everything takes. Drawn in software, a frame at a device
// ratio of two is four times the pixels, and on a busy machine took 10-15 s
// (measured: the page said "place" a whole frame before the canvas did).
const slow = Math.max(1, scale * scale);
mkdirSync(out, { recursive: true });

const browser = await launch();
const context = await browser.newContext({
  viewport: { width: 1400, height: 900 }, deviceScaleFactor: scale,
});
const page = await context.newPage();
const failures = [];
const seen = [];
page.on("pageerror", (e) => console.log(`  page error: ${String(e).slice(0, 160)}`));

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
const until = Date.now() + 300000;
while (!(await page.evaluate(() => Boolean(window.brickworksControls)))) {
  if (Date.now() > until) throw new Error("the app never came up");
  await page.waitForTimeout(1000);
}
// The car that greets a first visit assembles itself, and a click stops
// that rather than placing anything; let it finish and frame it.
await page.waitForTimeout(15000);

/// Where the app says its parts are, in CSS pixels (main._tell_page).
/// Asked, not assumed: at a device ratio of two the panels take far more
/// of the page, and a point picked as "the middle of the model" at one
/// ratio was the parts bin at the other.
///
/// Null when it is not on screen: at a device ratio of two the window is
/// narrow in the interface's own units, and the side panels fold away.
async function where(name, required = false) {
  for (let n = 0; n < 6; n += 1) {
    const found = await page.evaluate((key) => (window.brickworksControls || {})[key], name);
    if (found) return found;
    await page.waitForTimeout(500);
  }
  if (required) throw new Error(`the app is not showing "${name}"`);
  console.log(`        (no ${name} on screen at ${scale}x, so not checked there)`);
  return null;
}
const at = await where("view", true);
await page.mouse.move(at.x, at.y);
await page.mouse.click(at.x, at.y); // ends the animation if it is still going
await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await page.waitForTimeout(2500);

/// What the page says the pointer is, and what the browser shows.
async function read() {
  return page.evaluate(() => {
    const canvas = document.getElementById("canvas");
    return {
      state: window.brickworksCursor || "",
      computed: getComputedStyle(canvas).cursor,
    };
  });
}

/// Poll until the app is in a state and the browser shows what that
/// state should look like, for up to `ms`. A null state is one where the
/// app's own choice does not matter, because a control is under the
/// pointer and the control's shape wins.
async function expect(what, state, looks, ms = 15000 * slow) {
  const end = Date.now() + ms;
  let last = { state: "", computed: "" };
  while (Date.now() < end) {
    last = await read();
    if ((state === null || last.state === state) && await looks(last.computed, state)) {
      console.log(`  ok    ${what}: ${state ?? last.state} — ${describe(last.computed)}`);
      return last;
    }
    await page.waitForTimeout(40);
  }
  const showing = /image-set\(/.test(last.computed)
    ? `, showing the ${await identify(last.computed)} picture` : "";
  console.log(`  FAIL  ${what}: wanted ${state}, got ${last.state} — ${describe(last.computed)}${showing}`);
  failures.push(what);
  return last;
}

/// Which of the app's pictures a cursor style is showing, read off the
/// 1x picture's pixels and its hotspot. Not "some picture": the page says
/// "place" a frame or two before the canvas shows it, and a check that
/// took any picture passed on the zoom glass left over from the wheel.
async function identify(css) {
  const hot = css.match(/\)\s+(\d+)\s+(\d+)/);
  const spot = hot ? `${hot[1]},${hot[2]}` : "";
  const px = await page.evaluate(async (style) => {
    const url = (style.match(/url\("?([^")]+)"?\)/) || [])[1];
    if (!url) return null;
    const img = new Image();
    img.src = url;
    await img.decode();
    const c = document.createElement("canvas");
    c.width = 32;
    c.height = 32;
    const ctx = c.getContext("2d");
    ctx.drawImage(img, 0, 0, 32, 32);
    const at = (x, y) => Array.from(ctx.getImageData(x, y, 1, 1).data);
    return { badge: at(20, 20), centre: at(16, 16), left: at(8, 16), lens: at(13, 10) };
  }, css);
  if (!px) return "none";
  const opaque = (p) => p[3] > 128;
  if (spot === "2,2") return px.badge[2] > px.badge[0] ? "place" : "remove";
  if (spot === "4,27") return "paint";
  if (spot === "13,13") {
    return (px.lens[0] + px.lens[1] + px.lens[2]) / 3 < 110 ? "zoom_in" : "zoom_out";
  }
  if (spot === "16,16") {
    if (!opaque(px.centre)) return "box";
    return opaque(px.left) ? "slide" : "orbit";
  }
  return `unknown (${spot})`;
}
const picture = async (css, state) => /image-set\(/.test(css) && (await identify(css)) === state;
const keyword = (word) => (css) => css.trim() === word;

function describe(css) {
  if (!css) return "(none)";
  const urls = css.match(/url\(/g) || [];
  if (urls.length) {
    const hot = css.match(/\)\s+(\d+)\s+(\d+)/);
    return `${css.startsWith("image-set") || css.includes("image-set") ? "image-set" : "url"} of ${urls.length} picture(s), hotspot ${hot ? `${hot[1]},${hot[2]}` : "?"}`;
  }
  return css;
}

/// The two resolutions of a picture cursor, decoded: their sizes.
async function sizes(css) {
  return page.evaluate(async (style) => {
    const urls = [...style.matchAll(/url\("?([^")]+)"?\)/g)].map((m) => m[1]);
    const out = [];
    for (const u of urls) {
      const img = new Image();
      img.src = u;
      await img.decode();
      out.push(`${img.naturalWidth}x${img.naturalHeight}`);
    }
    return out;
  }, css);
}

/// Draw the cursor the browser computed where the pointer is, and save
/// the area around it.
async function shot(name, where, css) {
  await page.evaluate(({ x, y, style }) => {
    const old = document.getElementById("cursor-shown");
    if (old) old.remove();
    const urls = [...style.matchAll(/url\("?([^")]+)"?\)/g)].map((m) => m[1]);
    const hot = style.match(/\)\s+(\d+)\s+(\d+)\s*(,|$)/);
    let shown;
    if (urls.length) {
      shown = document.createElement("img");
      shown.src = urls[urls.length - 1];
      shown.style.width = "32px";
      shown.style.height = "32px";
      shown.style.left = `${x - (hot ? Number(hot[1]) : 0)}px`;
      shown.style.top = `${y - (hot ? Number(hot[2]) : 0)}px`;
    } else {
      // A cursor the system draws: say which, where it is.
      shown = document.createElement("div");
      shown.textContent = `system cursor: ${style}`;
      Object.assign(shown.style, {
        left: `${x + 6}px`, top: `${y + 10}px`, padding: "2px 6px",
        font: "12px sans-serif", color: "#fff", background: "rgba(0,0,0,0.75)",
        borderRadius: "4px",
      });
      const dot = document.createElement("div");
      Object.assign(dot.style, {
        position: "absolute", left: "-10px", top: "-14px", width: "6px", height: "6px",
        borderRadius: "3px", background: "#ff3b3b",
      });
      shown.appendChild(dot);
    }
    shown.id = "cursor-shown";
    Object.assign(shown.style, { position: "fixed", zIndex: 99999, pointerEvents: "none" });
    document.body.appendChild(shown);
  }, { x: where.x, y: where.y, style: css });
  // A picture to look at, and not a gate: grabbing a WebGL canvas in
  // software can take longer than any sensible wait (see check.mjs), and
  // what the cursor is has already been read above.
  try {
    await page.screenshot({
      path: `${out}/web_${name}.png`, timeout: 120000,
      clip: { x: Math.max(where.x - 160, 0), y: Math.max(where.y - 110, 0), width: 320, height: 220 },
    });
  } catch {
    console.log(`        (no picture of ${name}: the page would not hold still)`);
  }
  await page.evaluate(() => document.getElementById("cursor-shown")?.remove());
}

async function record(name, what, state, looks, where, ms) {
  const got = await expect(what, state, looks, ms);
  const entry = { name, state: got.state, cursor: describe(got.computed) };
  if (/image-set\(/.test(got.computed)) entry.pictures = await sizes(got.computed);
  seen.push(entry);
  if (entry.pictures && entry.pictures.join(" ") !== "32x32 64x64") {
    console.log(`  FAIL  ${what}: pictures are ${entry.pictures.join(" ")}, wanted 32x32 64x64`);
    failures.push(`${what} sizes`);
  }
  await shot(name, where, got.computed);
}

/// Wait for the app to have caught up: the pointer over the model, and
/// the app saying "place" for a second running. Drawn in software at a
/// device ratio of two a frame is slow, and events sent faster than that
/// are handled seconds later — a gesture measured before the last one has
/// been drawn measures the last one.
async function settle(point = at) {
  await page.mouse.move(point.x + 3, point.y + 3);
  await page.mouse.move(point.x, point.y);
  let since = Date.now();
  const end = Date.now() + 30000 * slow;
  while (Date.now() < end) {
    const now = await read();
    if (now.state !== "place") since = Date.now();
    if (Date.now() - since > 1000) return;
    await page.waitForTimeout(100);
  }
}

console.log(`at ${scale}x`);
await settle();
await record("place", "a held part over the model", "place", picture, at);

await page.mouse.down({ button: "right" });
await record("remove", "the right button down over a brick", "remove", picture, at);
for (let n = 1; n <= 6; n += 1) await page.mouse.move(at.x + n * 10, at.y);
const turned = { x: at.x + 60, y: at.y };
await record("orbit", "a right drag", "orbit", picture, turned);
// Carried over the toolbar, which is always there.
const bar = await where("save", true);
await page.mouse.move(bar.x, bar.y);
await record("orbit_over_panel", "...carried over the toolbar", "orbit", picture, bar);
await page.mouse.move(turned.x, turned.y);
await page.mouse.up({ button: "right" });
await record("after_orbit", "...and let go of", "place", picture, turned);

await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await settle();
await page.mouse.down({ button: "middle" });
for (let n = 1; n <= 6; n += 1) await page.mouse.move(at.x - n * 10, at.y);
await record("middle", "a middle drag", "orbit", picture, { x: at.x - 60, y: at.y });
await page.mouse.up({ button: "middle" });

await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await settle();
await page.keyboard.down("Shift");
await page.mouse.down({ button: "middle" });
for (let n = 1; n <= 6; n += 1) await page.mouse.move(at.x + n * 10, at.y + n * 4);
await record("slide", "shift and a middle drag", "slide", picture, { x: at.x + 60, y: at.y + 24 });
await page.mouse.up({ button: "middle" });
await page.keyboard.up("Shift");

await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await settle();
// The wheel's moment is a third of a second, so the notches keep coming
// while it is read. Whole notches, well apart: a stream of small ones is
// how a browser tells a trackpad (src/net/wheel_kind.gd), which turns.
let wheeling = true;
const wheel = (async () => {
  while (wheeling) { await page.mouse.wheel(0, -240); await page.waitForTimeout(400); }
})();
await record("zoom_in", "the wheel", "zoom_in", picture, at, 20000 * slow);
wheeling = false;
await wheel;
await record("after_zoom", "...and once it stops", "place", picture, at, 20000 * slow);

await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await settle();
const from = { x: at.x - 90, y: at.y - 60 };
await settle(from);
await page.mouse.down();
for (let n = 1; n <= 8; n += 1) await page.mouse.move(from.x + n * 20, from.y + n * 12);
const boxed = { x: from.x + 160, y: from.y + 96 };
await record("box", "a left drag", "box", picture, boxed);
await page.keyboard.press("Escape");
await record("box_escaped", "...Escape, with the button still down", "place", picture, boxed);
await page.mouse.up();

await settle();
await page.keyboard.down("KeyC");
await record("paint", "C held", "paint", picture, at);
await page.keyboard.up("KeyC");
await page.keyboard.press("Control+KeyZ"); // the paint, undone

await settle();
await page.keyboard.down("Shift");
await page.mouse.move(at.x, at.y + 2);
await page.mouse.move(at.x, at.y);
await record("select", "shift over a brick", "select", keyword("pointer"), at);
await page.keyboard.up("Shift");

const name = await where("model_name", true);
await page.mouse.move(name.x, name.y);
await record("text", "over the model's name", null, keyword("text"), name);
const save = await where("save", true);
await page.mouse.move(save.x, save.y);
await record("button", "over Save", null, keyword("pointer"), save);

await settle();
await page.keyboard.press("Comma");
await record("help_open", "the controls panel open under the pointer", null, keyword("default"), at);
await page.waitForTimeout(800);
await page.screenshot({ path: `${out}/web_help_dialog.png`, timeout: 120000 }).catch(
  () => console.log("        (no picture of the controls panel)"));
await page.keyboard.press("Escape");
await record("help_closed", "...Escape closes it, pointer not moved", "place", picture, at);
await page.screenshot({ path: `${out}/web_page.png`, timeout: 120000 }).catch(
  () => console.log("        (no picture of the page)"));

// The wheel over the interface is the interface's.
//
// Asked for by the owner: scrolling in a dialog or a panel went on to zoom
// the model behind it. Measured in the pixels of the view, around whatever
// is open, against the same wheel over the model moving them — so a view
// that ignored every wheel would fail here too.
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
    const out = [];
    for (let i = 0; i < data.length; i += 4) out.push((data[i] + data[i + 1] + data[i + 2]) / 3);
    return out;
  }, { x, y, w, h });
}
const differ = (a, b) => a.reduce((t, v, i) => t + Math.abs(v - b[i]), 0) / a.length;
async function scrolled(what, point, regions, shouldMove) {
  await page.mouse.move(point.x, point.y);
  // As long before as after: the ghost brick goes when the pointer leaves
  // the model (Cursors._process), and at a device ratio of two in software
  // that is a frame or two of 10-15 s. Its going, caught between the two
  // pictures, read as the view moving.
  await page.waitForTimeout(8000 * slow);
  const before = [];
  for (const r of regions) before.push(await viewPrint(...r));
  for (let n = 0; n < 4; n += 1) { await page.mouse.wheel(0, 240); await page.waitForTimeout(400); }
  for (let n = 0; n < 8; n += 1) { await page.mouse.wheel(0, -240); await page.waitForTimeout(400); }
  await page.keyboard.down("Shift");
  for (let n = 0; n < 3; n += 1) { await page.mouse.wheel(0, 240); await page.waitForTimeout(400); }
  await page.keyboard.up("Shift");
  // Long enough for the slowest frame to have drawn what the last notch did.
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
  // How much of the view changed, as well as how far: a camera that moved
  // changes nearly all of it, a brick appearing or going a small patch.
  const share = `${Math.round((100 * cells) / total)}% of it`;
  const ok = shouldMove ? moved > 2.0 : moved < 1.0;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}: the view ${moved > 1.0 ? "moved" : "stayed"} (${moved.toFixed(2)}, ${share})`);
  if (!ok) failures.push(what);
  seen.push({ name: `wheel: ${what}`, moved: Number(moved.toFixed(2)), changed: share });
}
await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await settle();
// The model's part of the window, and two strips of it either side of a
// dialog in its middle, from where the app says the view is.
const page_size = await page.evaluate(() => {
  const c = document.getElementById("canvas");
  return { w: c.clientWidth, h: c.clientHeight };
});
const half = { w: Math.min(at.x - 20, page_size.w - at.x - 20, 360), h: Math.min(at.y - 60, 300) };
const wholeView = [[at.x - half.w, at.y - half.h, half.w * 2, half.h * 2]];
const besideDialog = [[at.x - half.w, at.y - half.h, 40, half.h * 2],
  [at.x + half.w - 40, at.y - half.h, 40, half.h * 2]];
// The assistant shows the brief once there is a key, and the key form
// before; whichever is up.
for (const [what, keys] of [["over the parts bin", ["parts list"]],
  ["over the assistant panel", ["brief", "key_field"]], ["over the toolbar", ["save"]]]) {
  let point = null;
  for (const key of keys) {
    point = await page.evaluate((k) => (window.brickworksControls || {})[k], key);
    if (point) break;
  }
  if (point) await scrolled(what, point, wholeView, false);
  else console.log(`        (no ${keys.join(" or ")} on screen at ${scale}x, so not checked there)`);
}
await settle();
await page.keyboard.press("Comma");
await page.waitForTimeout(1500);
await scrolled("over the controls panel", at, besideDialog, false);
await page.keyboard.press("Escape");
await settle();
await scrolled("over the model, which it should move", at, wholeView, true);

writeFileSync(`${out}/cursors.json`, JSON.stringify({ scale, seen }, null, 2));
await browser.close();
if (failures.length) {
  console.log(`${failures.length} FAILED`);
  process.exit(1);
}
console.log("every state shows its cursor in the browser");
