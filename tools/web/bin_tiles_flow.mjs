// The parts bin's tiles in a real browser on a slow network: within a second of
// the bin showing, every tile in sight is its picture or its part drawn from
// the catalogue, never a blank square, and each is named in words.
//
//   PARTS_URL=http://127.0.0.1:8871/parts/ tools/export.sh web
//   node tools/web/bin_tiles_flow.mjs --build=build/web --port=8871 \
//     --parts=assets/generated/parts --out=shots/bin_tiles
//
// On the live site, opening the castle, the tiles were grey squares eight
// seconds in, each saying only its number (appux371 A4, 2026-10-30): a
// picture is a fetch and then a render in a browser drawing in software.
// tools/web/serve.py --parts serves each part late (--delay ms), as
// placeholder_flow.mjs does. The flow opens the bin by its rail as a person
// does, and the moment the page is told where its tiles are (the bin's
// "tile picture N", Main._page_places, about half a second after they are
// laid out) photographs the window and reads each tile's square: a tile is
// drawn when an eighth of its square is in the colour in hand (red, a first
// visit's), pulled from the tile's own grey. A blank placeholder is a faint
// grey square, and the light crossing it is white: neither is red. It fails
// on a tile in sight not drawn within --within ms of the bin showing (1000),
// on a tile named by a number, on a script error, and if the page never
// told where the tiles are. Local only: it needs the late parts server.
import { controlsWith, launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { inflateSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const build = args.build || "build/web";
const port = Number(args.port || 8871);
const url = args.url || `http://127.0.0.1:${port}/index.html`;
const parts = args.parts || "assets/generated/parts";
const out = args.out || "shots/bin_tiles";
const delay = Number(args.delay || 2500);
const within = Number(args.within || 1000);
mkdirSync(out, { recursive: true });

// A tile is drawn when this share of its square is in the colour in hand.
const DRAWN = 0.12;

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
// The bin opened by its rail, as a person opens it, and the moment it shows.
const opened = Date.now();
await openColumnFor(page, "make part");
const shownAt = Date.now();
const where = await controlsWith(page, ["tile picture 1", "parts list"], 30000);
const toldAt = Date.now();
const shot = await page.screenshot({ path: `${out}/bin_first.png`, timeout: 120000 });
const tookShot = Date.now();
console.log(`    the bin opened ${shownAt - opened} ms after its rail was clicked; its tiles told `
  + `${toldAt - shownAt} ms after, photographed ${tookShot - shownAt} ms after it showed`);
check("the page was told where the bin's tiles are", Boolean(where["tile picture 1"]));

const image = decodePng(shot);
const list = where["parts list"];
const tiles = Object.keys(where).filter((name) => name.startsWith("tile picture "))
  .map((name) => ({ name, ...where[name] }))
  .filter((tile) => list && tile.y - tile.h / 2 >= list.y - list.h / 2 - 1
    && tile.y + tile.h / 2 <= list.y + list.h / 2 + 1);
let drawn = 0;
const shares = [];
for (const tile of tiles) {
  const share = redShare(image, tile);
  shares.push(Math.round(share * 100));
  if (share >= DRAWN) drawn += 1;
}
console.log(`    each tile's square in the colour in hand: ${shares.join("%, ")}%`);
check(`every tile in sight drawn ${tookShot - shownAt} ms after the bin showed: ${drawn} of `
  + `${tiles.length}`, tiles.length >= 8 && drawn === tiles.length && tookShot - shownAt <= within + 1500);
const state = await page.evaluate(() => window.brickworksState || {});
const names = (state.tile_names || []);
console.log(`    the tiles read: ${names.join(" | ")}`);
check(`each tile in sight is named in words, not a number (${names.length})`,
  names.length >= 8 && names.every((name) => /[A-Za-z]{3}/.test(name)));
writeFileSync(`${out}/bin_first.json`, JSON.stringify({ shares, names, ms: tookShot - shownAt }));

check(`no script errors in the console${errors.length ? ": " + errors[0] : ""}`, errors.length === 0);
await browser.close();
console.log(failed ? `bin tiles flow: ${failed} FAILED`
  : `bin tiles flow: every tile drawn and named within a second, pictures in ${out}`);
process.exit(failed ? 1 : 0);


// The share of a tile's square pulled from its own grey towards red: the
// colour in hand on a first visit, which its picture and its stand-in are
// both drawn in.
function redShare(png, tile) {
  const side = Math.min(tile.w, tile.h);
  const left = Math.round(tile.x - side / 2), top = Math.round(tile.y - side / 2);
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
