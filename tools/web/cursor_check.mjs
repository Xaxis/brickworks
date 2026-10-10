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
const at = { x: 700, y: 470 };
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
async function expect(what, state, looks, ms = 4000) {
  const end = Date.now() + ms;
  let last = { state: "", computed: "" };
  while (Date.now() < end) {
    last = await read();
    if ((state === null || last.state === state) && looks(last.computed)) {
      console.log(`  ok    ${what}: ${state ?? last.state} — ${describe(last.computed)}`);
      return last;
    }
    await page.waitForTimeout(40);
  }
  console.log(`  FAIL  ${what}: wanted ${state}, got ${last.state} — ${describe(last.computed)}`);
  failures.push(what);
  return last;
}

const picture = (css) => /image-set\(/.test(css);
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
  if (picture(got.computed)) entry.pictures = await sizes(got.computed);
  seen.push(entry);
  if (entry.pictures && entry.pictures.join(" ") !== "32x32 64x64") {
    console.log(`  FAIL  ${what}: pictures are ${entry.pictures.join(" ")}, wanted 32x32 64x64`);
    failures.push(`${what} sizes`);
  }
  await shot(name, where, got.computed);
}

console.log(`at ${scale}x`);
await page.mouse.move(at.x, at.y + 4);
await page.mouse.move(at.x, at.y);
await record("place", "a held part over the model", "place", picture, at);

await page.mouse.down({ button: "right" });
await record("remove", "the right button down over a brick", "remove", picture, at);
for (let n = 1; n <= 6; n += 1) await page.mouse.move(at.x + n * 10, at.y);
const turned = { x: at.x + 60, y: at.y };
await record("orbit", "a right drag", "orbit", picture, turned);
await page.mouse.move(1300, 450);
await record("orbit_over_panel", "...carried over the assistant panel", "orbit", picture, { x: 1300, y: 450 });
await page.mouse.move(turned.x, turned.y);
await page.mouse.up({ button: "right" });
await record("after_orbit", "...and let go of", "place", picture, turned);

await page.mouse.move(at.x, at.y);
await page.mouse.down({ button: "middle" });
for (let n = 1; n <= 6; n += 1) await page.mouse.move(at.x - n * 10, at.y);
await record("middle", "a middle drag", "orbit", picture, { x: at.x - 60, y: at.y });
await page.mouse.up({ button: "middle" });

await page.keyboard.down("Shift");
await page.mouse.move(at.x, at.y);
await page.mouse.down({ button: "middle" });
for (let n = 1; n <= 6; n += 1) await page.mouse.move(at.x + n * 10, at.y + n * 4);
await record("slide", "shift and a middle drag", "slide", picture, { x: at.x + 60, y: at.y + 24 });
await page.mouse.up({ button: "middle" });
await page.keyboard.up("Shift");

await page.keyboard.press("Digit0");
await page.keyboard.press("KeyF");
await page.waitForTimeout(1500);
await page.mouse.move(at.x, at.y);
// The wheel's moment is a third of a second, so the notches keep coming
// while it is read.
let wheeling = true;
const wheel = (async () => {
  while (wheeling) { await page.mouse.wheel(0, -60); await page.waitForTimeout(120); }
})();
await record("zoom_in", "the wheel", "zoom_in", picture, at, 6000);
wheeling = false;
await wheel;
await record("after_zoom", "...and once it stops", "place", picture, at);

const from = { x: at.x - 120, y: at.y - 80 };
await page.mouse.move(from.x, from.y);
await page.mouse.down();
for (let n = 1; n <= 8; n += 1) await page.mouse.move(from.x + n * 20, from.y + n * 12);
const boxed = { x: from.x + 160, y: from.y + 96 };
await record("box", "a left drag", "box", picture, boxed);
await page.keyboard.press("Escape");
await record("box_escaped", "...Escape, with the button still down", "place", picture, boxed);
await page.mouse.up();

await page.mouse.move(at.x, at.y);
await page.keyboard.down("KeyC");
await record("paint", "C held", "paint", picture, at);
await page.keyboard.up("KeyC");
await page.keyboard.press("Control+KeyZ"); // the paint, undone

await page.keyboard.down("Shift");
await page.mouse.move(at.x, at.y + 2);
await page.mouse.move(at.x, at.y);
await record("select", "shift over a brick", "select", keyword("pointer"), at);
await page.keyboard.up("Shift");
await page.mouse.move(at.x, at.y + 2);
await page.mouse.move(at.x, at.y);

const controls = await page.evaluate(() => window.brickworksControls);
if (controls.brief) {
  await page.mouse.move(controls.brief.x, controls.brief.y);
  await record("text", "over the brief", null, keyword("text"), controls.brief);
}
if (controls.build) {
  await page.mouse.move(controls.build.x, controls.build.y);
  await record("button", "over Build it", null, keyword("pointer"), controls.build);
}

await page.mouse.move(at.x, at.y);
await page.keyboard.press("Comma");
await record("help_open", "the controls panel open under the pointer", null, keyword("default"), at);
await page.waitForTimeout(800);
await page.screenshot({ path: `${out}/web_help_dialog.png`, timeout: 120000 }).catch(
  () => console.log("        (no picture of the controls panel)"));
await page.keyboard.press("Escape");
await record("help_closed", "...Escape closes it, pointer not moved", "place", picture, at);
await page.screenshot({ path: `${out}/web_strip.png`, timeout: 120000,
  clip: { x: 300, y: 840, width: 800, height: 60 } }).catch(
  () => console.log("        (no picture of the strip)"));

writeFileSync(`${out}/cursors.json`, JSON.stringify({ scale, seen }, null, 2));
await browser.close();
if (failures.length) {
  console.log(`${failures.length} FAILED`);
  process.exit(1);
}
console.log("every state shows its cursor in the browser");
