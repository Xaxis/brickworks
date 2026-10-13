// Brickworks with the assistant off, in a real browser: a complete CAD with
// nothing of AI anywhere in the window, and the assistant back whole in one
// step for whoever came for it.
//
//   set -a; . ./.env; set +a
//   tools/export.sh web
//   node tools/web/relay_server.mjs 8790 --static=build/web &
//   node tools/web/noai_flow.mjs --url=http://127.0.0.1:8790/index.html --relay --out=shots/noai_web
//
// (Against tools/web/serve.py, which has no /api/mcp, leave out --relay.)
//
// Why: a builder on Reddit, 2026-10-13, of the assistant: "looks worryingly
// AI… a LOT of us… building freely and building things that are not AI
// designed". Someone who never wants AI must never have to see it.
//
// A first visit, at 1280 x 800: the parts bin open, the model in view, no
// control of the assistant's on the page (its rail, its key field, its
// brief, Sketch first, the connector's switch, Brick Art's Design with
// Claude), and one button offering it, "Show the assistant". Then every word the
// window shows (window.brickworksWords: each control on screen, every row of
// every menu and of the menu on a part) searched for Claude, assistant, AI,
// Sketch first and Anthropic: on the first screen, with the menu on
// a part open, and with Brick Art open. Ctrl+K on a selection opens nothing.
// Then the button, pressed once: its rail, its column, Ask Claude in the
// menus and on a part, and Design with Claude, all back. Then Settings (the
// comma key), "Build by hand only", Settings saying Claude connections are
// off with it, and the connector off. Then a short build with it off: three
// bricks taken from the bin by number and put down by clicks, one made a step
// of its own (Shift+N), the booklet opened in its tab and the LDraw model
// downloaded, neither with a word of AI in it. Last, the page opened again:
// still off, and the button not offered twice. Then a fresh visitor at
// /app?assistant=on, the address the site and the connector's words give:
// the assistant on, its column open, no button, the parameter gone from the
// address, and still on when the page is opened again. With --relay, Claude
// at a connector whose tab is not open is told how to turn the assistant on:
// "Settings, Assistant, or open brickworks.diy/app?assistant=on". Pictures
// in --out; it fails if a step does not happen or a script error reaches
// the console.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { randomBytes } from "node:crypto";
import { deflateSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8761/index.html";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/noai_web";
mkdirSync(out, { recursive: true });

// What AI is called anywhere a person reads it, and the controls that are
// the assistant's.
const AI = /Claude|[Aa]ssistant|\bAI\b|Sketch first|Anthropic/;
const ITS_OWN = /^(assistant_rail|key_field|use_key|change_key|brief|build|stop|connect_claude|claude_|connector_|sketch_|mosaic_claude|mosaic_brief|account_connect_claude|account_disconnect_claude)/;
// The first visit's one button, which may name it.
const OFFER = "Show the assistant";

const t0 = Date.now();
const errors = [];
let failed = 0;
const ok = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failed += 1;
  return passed;
};

// A small picture for Brick Art: a yellow square on blue, as a PNG.
function png(w, h) {
  const crc = (bytes) => {
    let c = ~0;
    for (const b of bytes) {
      c ^= b;
      for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
    }
    return ~c >>> 0;
  };
  const chunk = (type, data) => {
    const head = Buffer.alloc(8);
    head.writeUInt32BE(data.length, 0);
    head.write(type, 4, "ascii");
    const tail = Buffer.alloc(4);
    tail.writeUInt32BE(crc(Buffer.concat([head.subarray(4), data])), 0);
    return Buffer.concat([head, data, tail]);
  };
  const rows = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const inside = x > w / 4 && x < (3 * w) / 4 && y > h / 4 && y < (3 * h) / 4;
      rows.set(inside ? [240, 200, 30] : [20, 70, 200], y * (w * 3 + 1) + 1 + x * 3);
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(w, 0);
  header.writeUInt32BE(h, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header), chunk("IDAT", deflateSync(rows)), chunk("IEND", Buffer.alloc(0))]);
}
const picture = resolve(out, "square.png");
writeFileSync(picture, png(48, 32));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, acceptDownloads: true });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error/i.test(m.text())) errors.push(m.text().slice(0, 300));
});

const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
const wait = (ms) => page.waitForTimeout(ms);
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await wait(500);
  }
  return false;
}
async function where(name, seconds = 120) {
  await until(async () => Boolean((await controls())[name]), seconds);
  return (await controls())[name] || null;
}
async function click(name, options = {}) {
  const at = typeof name === "string" ? await where(name) : name;
  if (!at) return false;
  await page.mouse.move(at.x, at.y, { steps: 3 });
  await wait(250);
  await page.mouse.click(at.x, at.y, options);
  await wait(900);
  return true;
}
async function key(name, ms = 700) {
  await page.keyboard.press(name);
  await wait(ms);
}
let shots = 0;
async function shot(name) {
  shots += 1;
  const path = `${out}/${String(shots).padStart(2, "0")}_${name}.png`;
  await page.screenshot({ path, timeout: 120000 }).catch(() => {});
  console.log(`    picture: ${path}`);
}
// Every word the window shows, read by the app (Main.words_shown).
async function words() {
  await page.evaluate(() => { window.brickworksWords = null; window.brickworksAskWords = true; });
  await until(async () => Boolean(await page.evaluate(() => window.brickworksWords)), 20);
  return (await page.evaluate(() => window.brickworksWords)) || null;
}
// The words that name AI, but the first visit's one button offering it.
async function aiWords() {
  const all = await words();
  if (!all) return null;
  return all.filter((w) => w !== OFFER && AI.test(w));
}
const listed = (found) => (found && found.length ? ` — ${found.slice(0, 5).map((w) => `"${w.slice(0, 50)}"`).join("; ")}` : "");
const assistantControls = async () => Object.keys(await controls()).filter((n) => ITS_OWN.test(n));
async function noAi(when) {
  const found = await aiWords();
  ok(found !== null && found.length === 0, `${when}: not a word of AI in the window (${found ? "searched" : "no words"})${listed(found)}`);
  const named = await assistantControls();
  ok(named.length === 0, `${when}: none of the assistant's controls on the page${named.length ? ` — ${named.join(", ")}` : ""}`);
}
// A part on the page a click will find (Main._parts_to_click).
async function aPart() {
  await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
  await until(async () => Boolean(await page.evaluate(() => window.brickworksLayout)), 20);
  const layout = await page.evaluate(() => window.brickworksLayout);
  return layout && layout.targets && layout.targets[0] ? layout.targets[0] : null;
}
// Build > Mosaic from a picture…, and the picture into the chooser it opens.
async function brickArt() {
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await click("menu_build");
    await page.keyboard.type("Mosaic", { delay: 120 });
    await wait(800);
    await key("Enter", 500);
    await until(async () => page.choosers.length > 0, 30);
    const chooser = page.choosers.shift();
    if (chooser) {
      await chooser.setFiles(picture);
      return until(async () => Boolean((await controls()).mosaic_build), 60);
    }
    await key("Escape");
  }
  return false;
}
// The menu on a part, opened by a right click on one.
async function rightClick() {
  const part = await aPart();
  if (!part) return false;
  await click(part, { button: "right" });
  await wait(1500);
  return true;
}

await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
ok(Boolean(await where("save", 400)), "the app came up, signed in");
await wait(Number(args.load || 15000));

console.log("\nthe first visit");
let s = await state();
ok(s.assistant === false, `it builds by hand: the assistant is off (assistant ${s.assistant})`);
ok(s.columns && s.columns.parts === true, `it opens on the parts bin (columns ${JSON.stringify(s.columns)})`);
ok(Boolean((await controls())["part search"]), "...its search on the page");
ok(s.bricks > 0, `...and the model in view, ${s.bricks} parts`);
ok(s.offer === true && Boolean((await controls()).offer_show) && (await words() || []).includes(OFFER),
  `one button offers it: "${OFFER}"`);
await noAi("the first screen");
await shot("first_visit");

console.log("\nnothing of AI, with it off");
ok(await rightClick(), "a right click on a part opens its menu");
await noAi("the menu on a part");
await shot("right_click_off");
await key("Escape");
const part = await aPart();
if (part) await click(part);
await key("Control+k", 2000);
s = await state();
ok(s.assistant === false && s.columns.assistant === false, "Ctrl+K on a selection opens nothing");
await key("Escape");
ok(await brickArt(), "Build, Mosaic from a picture… opens Brick Art on the picture");
const art = await controls();
ok(!art.mosaic_claude && !art.mosaic_brief, "Brick Art has no brief for Claude and no Design with Claude");
await noAi("Brick Art");
await shot("brick_art_off");
await key("Escape", 1500);

console.log("\nthe first visit's button, pressed");
ok(await click("offer_show"), "Show the assistant, clicked once");
await wait(2500);
s = await state();
ok(s.assistant === true && s.offer === false, `the assistant is on and the button gone (offer ${s.offer})`);
ok(s.columns.assistant === true, `its column is open (columns ${JSON.stringify(s.columns)})`);
const back = await assistantControls();
ok(back.includes("assistant_rail"), `...with its controls: ${back.join(", ")}`);
let all = await words() || [];
ok(all.includes("Ask Claude about this…") && all.includes("Claude connector…"),
  "Edit has Ask Claude about this… and Tools has Claude connector… again");
await shot("assistant_on");
ok(await rightClick(), "a right click on a part");
all = await words() || [];
ok(all.includes("Ask Claude about this…"), "...asks Claude again");
await key("Escape");
ok(await brickArt(), "Brick Art again");
ok(Boolean((await controls()).mosaic_claude), "...with Design with Claude");
await key("Escape", 1500);

console.log("\nSettings, Assistant (AI): off again");
await key("Comma", 2000);
ok(await click("assistant_off"), "Build by hand only, clicked");
await wait(1500);
all = await words() || [];
ok(all.some((w) => w.includes("Claude connections are off while the assistant is off")),
  "Settings says Claude connections are off while the assistant is off");
await shot("settings_off");
await click("settings_done");
await wait(1500);
s = await state();
const claude = await page.evaluate(() => window.brickworksClaude || {});
ok(s.assistant === false && !claude.on, `off, and the connector with it (on ${claude.on})`);
await noAi("off again");

console.log("\na short build, by hand");
await click("new");
for (let n = 0; n < 10 && (await state()).bricks > 0; n++) await key("Enter", 1500);
ok((await state()).bricks === 0, "New: an empty baseplate");
await click("part search");
await key("Control+a", 200);
await page.keyboard.type("3001", { delay: 30 });
await wait(1500);
await click("first part");
ok(await until(async () => (await state()).mode === "place", 30), `a 2 x 4 brick in hand (${(await state()).held})`);
const view = await where("view");
for (const [dx, dy] of [[-60, 40], [60, 40], [0, 120]]) {
  const at = { x: view.x + dx, y: view.y + dy };
  await page.mouse.move(at.x - 2, at.y, { steps: 3 });
  await wait(400);
  await page.mouse.move(at.x, at.y, { steps: 2 });
  await wait(400);
  const before = (await state()).bricks;
  await page.mouse.click(at.x, at.y);
  await until(async () => (await state()).bricks > before, 10);
}
ok((await state()).bricks === 3, `three bricks put down by clicks (${(await state()).bricks})`);
await key("Escape");
await click({ x: view.x, y: view.y + 120 });
await key("Shift+N", 2500);
ok(/new step/.test((await state()).said || ""), `Shift+N makes a step of the selection: "${(await state()).said}"`);
await key("Escape");
await shot("built_by_hand");
const opened = context.waitForEvent("page", { timeout: 60000 }).catch(() => null);
await click("instructions");
const tab = await opened;
let booklet = "";
if (tab) {
  await until(async () => (await tab.evaluate(() => document.querySelectorAll("section.page").length).catch(() => 0)) > 0, 600);
  booklet = await tab.evaluate(() => document.body.innerText).catch(() => "");
}
ok(booklet.length > 0, `Instructions opens the booklet in its tab (${booklet.length} characters)`);
ok(booklet.length > 0 && !AI.test(booklet), "...with no word of AI in it");
const downloaded = page.waitForEvent("download", { timeout: 90000 }).catch(() => null);
await click("menu_file");
await wait(2500);
await key("E", 800);
await key("ArrowRight", 1500);
await key("Enter", 500);
const download = await downloaded;
let ldraw = "";
if (download) {
  const kept = resolve(out, download.suggestedFilename());
  await download.saveAs(kept);
  ldraw = readFileSync(kept, "utf8");
}
ok((ldraw.match(/3001\.dat/g) || []).length === 3, `File, Export, LDraw model downloads the three bricks (${download ? download.suggestedFilename() : "nothing"})`);
ok(ldraw.length > 0 && !AI.test(ldraw), "...with no word of AI in it");
await noAi("after the build");

console.log("\nthe next visit");
await page.reload({ waitUntil: "domcontentloaded" });
await where("save", 400);
await wait(Number(args.load || 15000));
s = await state();
ok(s.assistant === false && s.offer === false, `still off, kept on this device, and not offered again (offer ${s.offer})`);
await shot("next_visit");

console.log("\na fresh visitor at /app?assistant=on");
const fresh = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const other = await fresh.newPage();
other.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
const asked = `${url}${url.includes("?") ? "&" : "?"}assistant=on`;
await other.goto(bypass ? `${asked}&x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true` : asked,
  { waitUntil: "domcontentloaded", timeout: 180000 });
const otherState = async () => (await other.evaluate(() => window.brickworksState || {})) || {};
for (let n = 0; n < 800 && !(await other.evaluate(() => (window.brickworksControls || {}).save)); n++) {
  await other.waitForTimeout(500);
}
await other.waitForTimeout(Number(args.load || 15000));
let o = await otherState();
ok(o.assistant === true, `the assistant is on from the address (assistant ${o.assistant})`);
ok(o.columns && o.columns.assistant === true, `...its column open (columns ${JSON.stringify(o.columns)})`);
ok(o.offer === false, "...and no button offering it");
ok(!other.url().includes("assistant="), `the parameter is gone from the address: ${other.url()}`);
await other.screenshot({ path: `${out}/${String(++shots).padStart(2, "0")}_from_the_address.png`, timeout: 120000 }).catch(() => {});
await other.reload({ waitUntil: "domcontentloaded" });
for (let n = 0; n < 800 && !(await other.evaluate(() => (window.brickworksControls || {}).save)); n++) {
  await other.waitForTimeout(500);
}
await other.waitForTimeout(Number(args.load || 15000));
o = await otherState();
ok(o.assistant === true, "...and still on when the page is opened again: remembered");
await fresh.close();

if (args.relay) {
  console.log("\nClaude at a connector whose tab is not open");
  const origin = new URL(url).origin;
  const token = randomBytes(36).toString("base64url");
  const asking = await fetch(`${origin}/api/mcp?t=${token}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call",
      params: { name: "search_parts", arguments: { query: "brick" } } }),
  }).catch((e) => ({ status: 0, json: async () => ({ error: String(e) }) }));
  const answer = await asking.json().catch(() => ({}));
  const told = (answer?.result?.content || []).map((c) => c.text).join(" ");
  ok(asking.status === 200 && answer?.result?.isError
    && told.includes("Settings, Assistant, or open brickworks.diy/app?assistant=on"),
    `the relay says how to turn the assistant on: "${told.slice(0, 160)}"`);
}

ok(errors.length === 0, `no script error reached the console${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`);
await browser.close();
console.log(failed
  ? `\nno AI in a browser: ${failed} FAILED; pictures in ${out}`
  : `\nno AI in a browser: off, nothing of it anywhere; one press or the address and all of it back; a build by hand to the booklet and the file; pictures in ${out}`);
process.exit(failed ? 1 : 0);
