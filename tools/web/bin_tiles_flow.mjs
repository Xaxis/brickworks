// The parts bin's tiles in a real browser on a slow network: from the first
// frame they show in, every tile in sight is its picture or its part drawn
// from the catalogue, never a blank square, and each is named in words.
//
//   PARTS_URL=http://127.0.0.1:8893/parts/ tools/export.sh web
//   node tools/web/bin_tiles_flow.mjs --build=build/web --port=8893 \
//     --parts=assets/generated/parts --out=shots/bin_tiles
//
// On the live site, opening the castle, the tiles were grey squares eight
// seconds in, each saying only its number (appux371 A4, 2026-10-30): a
// picture is a fetch and then a render in a browser drawing in software.
// tools/web/serve.py --parts serves each part late (--delay ms), as
// placeholder_flow.mjs does. The flow opens the bin by its rail as a person
// does (or, out from the first frame, waits for the page to settle) and
// photographs it; then types a builder's words into its search and
// photographs the bin again and again for --series ms (6000). Once the page
// is told where the tiles are (the bin's "tile picture N", Main._page_places;
// they do not move) it reads each tile's square: a tile is drawn when a
// twentieth of its square is in the colour in hand (red, a first visit's),
// pulled from the tile's own grey. A blank placeholder is a faint grey
// square, and the light crossing it is white: neither is red. The first
// photograph in which the tiles changed is the new tiles' first frame; their
// parts have not been fetched, and each takes --delay ms to arrive, so a tile
// drawn then is its drawing from the catalogue. It fails on a blank tile in
// that frame or any after it, on a tile blank in the bin as it opens, on
// two tiles that read alike or one named by a number, on a script error, and
// if the page never told where the tiles are. In software a frame after
// typing came 2.5 to 3.4 s after the last key on a loaded machine
// (2026-10-30): a search a key, each answered in WebAssembly, and its frames
// drawn by the processor; the drawing was there in the first of them. Local
// only: it needs the late parts server.
import { controlsWith, launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { inflateSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const build = args.build || "build/web";
const port = Number(args.port || 8893);
const url = args.url || `http://127.0.0.1:${port}/index.html`;
const parts = args.parts || "assets/generated/parts";
const out = args.out || "shots/bin_tiles";
const delay = Number(args.delay || 2500);
const within = Number(args.within || 1000);
mkdirSync(out, { recursive: true });

// A tile is drawn when this share of its square is in the colour in hand. A
// blank one has none; a 1 x 1 brick's picture covered a tenth of it.
const DRAWN = 0.05;
// When each photograph is asked for: early enough that it is taken inside
// --within ms of the bin showing on a machine drawing in software.
const SHOOT_AT = Number(args.at || 300);
// How long after the last key it photographs the bin, again and again.
const SERIES = Number(args.series || 6000);
// What is typed: a builder's words for parts no tile above showed.
const WORDS = args.words || "slope 45 2x2";

let server = null;
if (!args.url) {
  server = spawn("python3", ["tools/web/serve.py", build, String(port), "--parts", parts,
    "--delay", String(delay)], { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((ready, failed) => {
    server.on("exit", (code) => failed(new Error(`serve.py exited ${code}`)));
    server.stdout.on("data", (chunk) => {
      if (String(chunk).includes("serving ")) ready();
    });
  });
  process.on("exit", () => server.kill());
}

const browser = await launch({ signedOut: true });
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|USER ERROR|Parse Error/.test(m.text())) errors.push(m.text().slice(0, 300));
});
let failed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
};

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
const until = Date.now() + 300000;
while (!(await page.evaluate(() => Boolean((window.brickworksControls || {})["make part"]
    || (window.brickworksControls || {}).parts_rail)))) {
  if (Date.now() > until) throw new Error("the app never came up");
  await page.waitForTimeout(500);
}
// 1. The bin as it shows: opened by its rail as a person opens it, or out
// from the first frame on a window wide enough. Photographed SHOOT_AT ms
// after it shows, and read by where its tiles are once the page is told.
const out1 = (await page.evaluate(() => window.brickworksState || {})).columns || {};
const named = await page.evaluate(() => window.brickworksControls || {});
if (out1.parts === false && named.parts_rail) {
  await page.mouse.click(named.parts_rail.x, named.parts_rail.y);
  await shootAt(Date.now(), "bin_first", "the bin showed", null);
} else {
  // Out from the first frame, which has no moment to time from: the app
  // fades in over its first seconds, so it is photographed after them.
  console.log("    the bin was out from the first frame");
  await page.waitForTimeout(5000);
  const settled = await controlsWith(page, ["parts list"], 30000);
  await shootAt(Date.now(), "bin_first", "the page settled", settled["parts list"], false);
}

// 2. A search typed: new parts, each picture held back by the late server
// (--delay ms), so a tile drawn a second in is its drawing from the catalogue.
// Photographed one after another from the last key until SERIES ms on: the
// first photograph in which the tiles changed is the new tiles' first frame,
// and every tile in it must already be drawn.
const where0 = await controlsWith(page, ["part search", "parts list"], 30000);
const before = ((await page.evaluate(() => window.brickworksState || {})).found || []).join(",");
const list0 = where0["parts list"];
const clip0 = { x: Math.max(0, list0.x - list0.w / 2), y: Math.max(0, list0.y - list0.h / 2),
  width: list0.w, height: list0.h };
const still = decodePng(await page.screenshot({ clip: clip0, timeout: 120000 }));
await page.mouse.click(where0["part search"].x, where0["part search"].y);
await page.keyboard.press("Control+a");
await page.keyboard.type(WORDS, { delay: 40 });
const typedAt = Date.now();
const series = [];
while (Date.now() - typedAt < SERIES) {
  const shot = await page.screenshot({ clip: clip0, timeout: 120000 });
  series.push({ shot, took: Date.now() - typedAt });
}
await page.waitForTimeout(1500);
const where2 = await controlsWith(page, ["tile picture 1", "parts list"], 30000);
const tiles2 = Object.keys(where2).filter((key) => key.startsWith("tile picture "))
  .map((key) => ({ key, ...where2[key] }))
  .filter((tile) => tile.y - tile.h / 2 >= list0.y - list0.h / 2 - 1
    && tile.y + tile.h / 2 <= list0.y + list0.h / 2 + 1);
let first = -1;
const read = series.map(({ shot, took }, n) => {
  const image = decodePng(shot);
  const changed = tiles2.filter((tile) => moved(still, image, tile, clip0) > 0.04).length;
  const shares = tiles2.map((tile) => redShare(image, tile, clip0));
  if (first < 0 && changed >= tiles2.length / 2) first = n;
  return { took, changed, drawn: shares.filter((share) => share >= DRAWN).length, shares };
});
console.log(`    ${series.length} photographs in ${SERIES} ms after "${WORDS}" was typed: `
  + read.map((r) => `${r.took} ms ${r.changed} changed ${r.drawn} drawn`).join("; "));
if (first >= 0) writeFileSync(`${out}/bin_typed_first.png`, series[first].shot);
writeFileSync(`${out}/bin_typed_last.png`, series[series.length - 1].shot);
const blank = read.slice(Math.max(first, 0)).filter((r) => r.drawn < tiles2.length).length;
check(`the new tiles' first frame, ${first >= 0 ? read[first].took : "?"} ms after the last key, `
  + `drew all ${tiles2.length}: ${first >= 0 ? read[first].drawn : 0} (`
  + `${first >= 0 ? read[first].shares.map((x) => Math.round(x * 100)).join("%, ") : ""}%), `
  + `and no later photograph had a blank tile (${blank})`,
  first >= 0 && tiles2.length >= 8 && read[first].drawn === tiles2.length && blank === 0);
const names2 = (await page.evaluate(() => window.brickworksState || {})).tile_names || [];
console.log(`    the tiles read: ${names2.join(" | ")}`);
check(`each tile in sight is named in words, not a number, no two alike (${names2.length} tiles, `
  + `${new Set(names2).size} names)`, names2.length >= 8 && new Set(names2).size === names2.length
  && names2.every((text) => /[A-Za-z]{3}/.test(text)));
writeFileSync(`${out}/bin_typed.json`, JSON.stringify({ first, names: names2,
  series: read.map((r) => ({ took: r.took, changed: r.changed, drawn: r.drawn })) }));
const found = ((await page.evaluate(() => window.brickworksState || {})).found || []);
check(`"${WORDS}" gave new tiles: ${found.slice(0, 4).join(", ")}`, found.length > 0
  && found.join(",") !== before);

check(`no script errors in the console${errors.length ? ": " + errors[0] : ""}`, errors.length === 0);
await browser.close();
console.log(failed ? `bin tiles flow: ${failed} FAILED`
  : `bin tiles flow: every tile drawn from its first frame and named, pictures in ${out}`);
process.exit(failed ? 1 : 0);


// Photograph the window SHOOT_AT ms after [since], then, once the page is told
// where the tiles are (half a second or more later; they do not move), read
// each tile's square in it. Every tile in sight must be drawn, the photograph
// taken by --within ms, and each tile named in words.
async function shootAt(since, name, what, list0, timed = true) {
  // Only the bin when where it is is known: a photograph of the whole window
  // takes half a second in software, of the bin less.
  const clip = list0 ? { x: Math.max(0, list0.x - list0.w / 2), y: Math.max(0, list0.y - list0.h / 2),
    width: list0.w, height: list0.h } : undefined;
  await page.waitForTimeout(Math.max(0, SHOOT_AT - (Date.now() - since)));
  const asked = Date.now();
  const shot = await page.screenshot({ path: `${out}/${name}.png`, clip, timeout: 120000 });
  const took = Date.now();
  await page.waitForTimeout(1500);
  const where = await controlsWith(page, ["tile picture 1", "parts list"], 30000);
  check(`the page was told where the bin's tiles are (${name})`, Boolean(where["tile picture 1"]));
  const image = decodePng(shot);
  const list = where["parts list"];
  const tiles = Object.keys(where).filter((key) => key.startsWith("tile picture "))
    .map((key) => ({ key, ...where[key] }))
    .filter((tile) => list && tile.y - tile.h / 2 >= list.y - list.h / 2 - 1
      && tile.y + tile.h / 2 <= list.y + list.h / 2 + 1);
  const shares = tiles.map((tile) => redShare(image, tile, clip));
  const drawn = shares.filter((share) => share >= DRAWN).length;
  console.log(`    ${name}: photographed ${asked - since} to ${took - since} ms after ${what}; `
    + `each tile's square in the colour in hand: ${shares.map((x) => Math.round(x * 100)).join("%, ")}%`);
  check(`every tile in sight drawn, a picture or its part drawn, none blank: ${drawn} of ${tiles.length}`,
    tiles.length >= 8 && drawn === tiles.length);
  if (timed) {
    check(`the photograph showing them was taken by ${took - since} ms after ${what} (${within} meant)`,
      took - since <= within);
  }
  const names = (await page.evaluate(() => window.brickworksState || {})).tile_names || [];
  console.log(`    the tiles read: ${names.join(" | ")}`);
  check(`each tile in sight is named in words, not a number, no two alike (${names.length} tiles, `
    + `${new Set(names).size} names)`, names.length >= 8 && new Set(names).size === names.length
    && names.every((text) => /[A-Za-z]{3}/.test(text)));
  writeFileSync(`${out}/${name}.json`, JSON.stringify({
    shares: shares.map((x) => Math.round(x * 100)), names, from: asked - since, to: took - since }));
}

// How far a tile's square moved between two photographs, 0 to 1 a channel.
function moved(a, b, tile, clip) {
  const side = Math.min(tile.w, tile.h);
  const left = Math.round(tile.x - side / 2 - clip.x), top = Math.round(tile.y - side / 2 - clip.y);
  let sum = 0, all = 0;
  for (let y = top; y < top + side; y += 2) {
    for (let x = left; x < left + side; x += 2) {
      if (x < 0 || y < 0 || x >= a.width || y >= a.height) continue;
      const i = (y * a.width + x) * a.channels, j = (y * b.width + x) * b.channels;
      sum += (Math.abs(a.data[i] - b.data[j]) + Math.abs(a.data[i + 1] - b.data[j + 1])
        + Math.abs(a.data[i + 2] - b.data[j + 2])) / 765;
      all += 1;
    }
  }
  return all ? sum / all : 0;
}

// The share of a tile's square pulled from its own grey towards red: the
// colour in hand on a first visit, which its picture and its stand-in are
// both drawn in.
function redShare(png, tile, clip) {
  const side = Math.min(tile.w, tile.h);
  const left = Math.round(tile.x - side / 2 - (clip ? clip.x : 0));
  const top = Math.round(tile.y - side / 2 - (clip ? clip.y : 0));
  const pixel = (x, y) => {
    const at = (y * png.width + x) * png.channels;
    return [png.data[at] / 255, png.data[at + 1] / 255, png.data[at + 2] / 255];
  };
  const ground = pixel(left + 1, top + Math.round(side) - 2);
  let red = 0, all = 0;
  for (let y = top; y < top + side; y++) {
    for (let x = left; x < left + side; x++) {
      if (x < 0 || y < 0 || x >= png.width || y >= png.height) continue;
      const [r, g, b] = pixel(x, y);
      all += 1;
      if (r - ground[0] > 0.12 && r - Math.max(g, b) > 0.12) red += 1;
    }
  }
  return all ? red / all : 0;
}


// A PNG as Playwright writes one: 8 bits a channel, RGB or RGBA, not
// interlaced (outline_check.mjs's).
function decodePng(buffer) {
  let at = 8;
  let width = 0, height = 0, channels = 0;
  const idat = [];
  while (at < buffer.length) {
    const length = buffer.readUInt32BE(at);
    const type = buffer.toString("ascii", at + 4, at + 8);
    const body = buffer.subarray(at + 8, at + 8 + length);
    if (type === "IHDR") {
      width = body.readUInt32BE(0);
      height = body.readUInt32BE(4);
      channels = { 2: 3, 6: 4 }[body[9]];
    } else if (type === "IDAT") {
      idat.push(body);
    }
    at += 12 + length;
  }
  const raw = inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  const data = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? data[y * stride + x - channels] : 0;
      const b = y > 0 ? data[(y - 1) * stride + x] : 0;
      const c = x >= channels && y > 0 ? data[(y - 1) * stride + x - channels] : 0;
      let v = line[x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : (pb <= pc ? b : c);
      }
      data[y * stride + x] = v & 255;
    }
  }
  return { width, height, channels, data };
}
