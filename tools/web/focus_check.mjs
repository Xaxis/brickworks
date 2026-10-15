// Does a text field give the keys back to the model?
//
//   node tools/web/focus_check.mjs --url=http://127.0.0.1:8761/index.html --out=shots/focus
//   node tools/web/focus_check.mjs --url=<preview>/app --bypass=… [--ratio=2]
//
// The owner: "When the user names a build (renames it), the text input
// never loses focus and can't control the CAD controls." This types a name
// into the model's name field and ends the typing each way a person does —
// Enter, a click on the model, Tab, Escape — and after each asks the model
// to move by its keys: three taps of an arrow turn the view and 1 looks
// from the front. Each must move the picture. Escape must also put the
// name back as it was, and not a name typed and entered before it, even
// when both come in one frame.
//
// The picture is read, not the app's word for it, so the same check runs
// against a build from before the fix and fails there.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/focus";
const ratio = Number(args.ratio || 1);
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: ratio });
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });

async function controlAt(name, seconds = 300) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate(() => window.brickworksControls || null);
    if (where && where[name]) return where[name];
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}

/// A small fingerprint of the canvas: did the view change?
async function frameOf() {
  return page.evaluate(() => {
    const canvas = document.querySelector("canvas");
    const probe = document.createElement("canvas");
    probe.width = 32;
    probe.height = 18;
    const ctx = probe.getContext("2d");
    ctx.drawImage(canvas, 0, 0, 32, 18);
    const { data } = ctx.getImageData(0, 0, 32, 18);
    const values = [];
    for (let i = 0; i < data.length; i += 4) values.push((data[i] + data[i + 1] + data[i + 2]) / 3);
    return values;
  });
}

function differ(a, b) {
  let total = 0;
  for (let i = 0; i < a.length; i += 1) total += Math.abs(a[i] - b[i]);
  return total / a.length;
}

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
}

await controlAt("model_name");
// The example on the baseplate, with its parts arrived, is what moves.
await page.waitForTimeout(8000);
const box = page.viewportSize();
// High in the view, above the baseplate: a click there lands on the model's
// part of the window and puts nothing down.
const sky = { x: Math.round(box.width / 2), y: Math.round(box.height * 0.16) };

const endings = [
  ["Enter", async () => page.keyboard.press("Enter")],
  ["a click on the model", async () => page.mouse.click(sky.x, sky.y)],
  ["Tab", async () => page.keyboard.press("Tab")],
  ["Escape", async () => page.keyboard.press("Escape")],
];

let n = 0;
for (const [how, end] of endings) {
  n += 1;
  const field = await controlAt("model_name");
  const titleBefore = await page.title();
  await page.mouse.click(field.x, field.y);
  await page.waitForTimeout(300);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(`Focus check ${n}`, { delay: 20 });
  await page.waitForTimeout(400);
  await end();
  await page.waitForTimeout(600);
  // From the usual view, so each case starts from the same picture.
  await page.keyboard.press("Digit0");
  await page.waitForTimeout(1500);
  const still = await frameOf();
  for (let tap = 0; tap < 3; tap += 1) {
    await page.keyboard.press("ArrowLeft");
    await page.waitForTimeout(150);
  }
  await page.waitForTimeout(1500);
  const turned = await frameOf();
  await page.keyboard.press("Digit1");
  await page.waitForTimeout(1500);
  const front = await frameOf();
  const byArrow = differ(still, turned);
  const byKey = differ(turned, front);
  await page.screenshot({ path: `${out}/${n}_${how.replace(/\W+/g, "_")}.png`, timeout: 120000 })
    .catch(() => {});
  check(`after ${how}, the arrows turn the view (moved ${byArrow.toFixed(1)})`, byArrow > 1.5);
  check(`after ${how}, 1 looks from the front (moved ${byKey.toFixed(1)})`, byKey > 1.5);
  if (how === "Escape") {
    const titleAfter = await page.title();
    check(`Escape puts the name back ("${titleAfter}")`, titleAfter === titleBefore);
  }
}

// A busy tab hands the app every key since its last frame in one: a name
// typed, Enter, and Escape a moment later to give the keys back came
// together, and the Escape put the old name back (tabs_flow's rename at a
// load of 40 to 60, 2026-10-14). Sent here in one task of the page, so the
// app has them in one frame however fast this machine is.
{
  const field = await controlAt("model_name");
  await page.mouse.click(field.x, field.y);
  await page.waitForTimeout(1500);
  const name = "Focus check busy";
  await page.evaluate((typed) => {
    const canvas = document.querySelector("canvas");
    const send = (type, key, code, extra) => canvas.dispatchEvent(
      new KeyboardEvent(type, { key, code, bubbles: true, cancelable: true, ...extra }));
    const press = (key, code, extra = {}) => { send("keydown", key, code, extra); send("keyup", key, code, extra); };
    press("a", "KeyA", { ctrlKey: true });
    for (const c of typed) {
      press(c, c === " " ? "Space" : `Key${c.toUpperCase()}`, { shiftKey: c !== c.toLowerCase() });
    }
    press("Enter", "Enter");
    press("Escape", "Escape");
  }, name);
  let title = "";
  for (let n = 0; n < 40 && title !== `${name} — Brickworks`; n += 1) {
    await page.waitForTimeout(500);
    title = await page.title();
  }
  check(`a name typed, Enter and Escape in one busy frame keep the name ("${title}")`,
    title === `${name} — Brickworks`);
}

await browser.close();
console.log(failed ? `focus check: ${failed} FAILED` : "focus check: every way out of the name field gives the keys back");
process.exit(failed ? 1 : 0);
