// The selection's outline in a real browser, at one and two device pixels to
// the CSS pixel: a click on a part draws a line round it, and standing still
// with it outlined the page draws nothing.
//
//   set -a; . ./.env; set +a
//   tools/export.sh web
//   node tools/web/outline_check.mjs --dir=build/web        a local export, served here
//   BW_BYPASS=… node tools/web/outline_check.mjs --url=<preview>/app
//
// The outline is drawn by the window, over the model (SelectionOutline): a
// mask of the selected parts in a viewport of its own, through the view's own
// camera, and a line where the mask ends. Each of those is a thing WebGL2 in
// the browser could do differently from the desktop — a viewport's texture
// upside down, a render target's colours converted, a line half as wide at
// 2x — so this looks at the browser's own picture of it.
//
// Opens Orthanc, clicks the white wizard on its roof (window.brickworksState.places
// says where he is), watches the selection through --idle (6) seconds with no
// input, and counts the pixels in the selection's yellow round him against the
// same picture before the click; then counts the frames drawn over --seconds
// (5) standing still. Pictures in --out (shots/outline_web).
import { launch } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { inflateSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/outline_web";
mkdirSync(out, { recursive: true });
const seconds = Number(args.seconds || 5);
const idle = Number(args.idle || 6);
const model = args.model || "res://models/orthanc.ldr";
// The figures were renamed with the tower (docs/TRADEMARKS.md, decision 4).
const who = args.who || "white wizard";
const bypass = process.env.BW_BYPASS || "";

async function freePort() {
  return new Promise((done) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => { const { port } = s.address(); s.close(() => done(port)); });
  });
}

let server = null;
let url = args.url;
if (!url) {
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${args.dir || "build/web"}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}

let failures = 0;
const t0 = Date.now();
const ok = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failures += 1;
  return passed;
};

// A PNG as Playwright writes one: 8 bits a channel, RGB or RGBA, not
// interlaced. Returns { width, height, channels, data }.
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

// Pixels of the selection's yellow inside a box (device pixels), and how
// many of them were not that colour before.
function yellow(picture, box) {
  let count = 0;
  for (let y = Math.max(0, box.y0); y < Math.min(picture.height, box.y1); y++) {
    for (let x = Math.max(0, box.x0); x < Math.min(picture.width, box.x1); x++) {
      const i = (y * picture.width + x) * picture.channels;
      const [r, g, b] = [picture.data[i], picture.data[i + 1], picture.data[i + 2]];
      if (r > 215 && g > 185 && b < 120) count += 1;
    }
  }
  return count;
}

// In the page before anything else runs: each engine frame, and whether it
// asked WebGL to draw (idle_check.mjs has the long form).
function instrument() {
  const perf = { frames: [], cur: null };
  window.brickworksIdle = perf;
  const real = window.requestAnimationFrame.bind(window);
  const timed = (callback) => (time) => {
    if (perf.cur) { callback(time); return; }
    const frame = { t0: performance.now(), draws: 0 };
    perf.cur = frame;
    try { callback(time); } finally {
      perf.cur = null;
      perf.frames.push([frame.t0, frame.draws]);
      if (perf.frames.length > 20000) perf.frames.splice(0, 10000);
    }
  };
  let inner = real;
  Object.defineProperty(window, "requestAnimationFrame", {
    configurable: true,
    get() { const at = inner; return (callback) => at(timed(callback)); },
    set(f) { inner = f; },
  });
  const gl = WebGL2RenderingContext.prototype;
  for (const name of ["drawArrays", "drawElements", "drawArraysInstanced", "drawElementsInstanced"]) {
    const was = gl[name];
    gl[name] = function (...a) {
      if (perf.cur) perf.cur.draws += 1;
      return was.apply(this, a);
    };
  }
}

const browser = await launch();
const report = {};
try {
  for (const ratio of [1, 2]) {
    console.log(`\nat ${ratio}x`);
    const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: ratio });
    await page.addInitScript(instrument);
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|USER ERROR|Parse Error|shader compil|ERROR: .*shader/i.test(m.text())) {
        errors.push(m.text().slice(0, 300));
      }
    });
    const query = [`model=${model}`];
    if (bypass) query.push(`x-vercel-protection-bypass=${bypass}`, "x-vercel-set-bypass-cookie=true");
    await page.goto(`${url}${url.includes("?") ? "&" : "?"}${query.join("&")}`,
      { waitUntil: "domcontentloaded", timeout: 180000 });
    const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
    let now = {};
    for (let n = 0; n < 600; n++) {
      now = await state();
      if (now.bricks > 1000 && !now.playing && now.places && now.places[Object.keys(now.places)
        .find((p) => p.toLowerCase().replace(/_/g, " ").includes(who))]) break;
      await page.waitForTimeout(1000);
    }
    const path = Object.keys(now.places || {}).find((p) => p.toLowerCase().replace(/_/g, " ").includes(who));
    ok(Boolean(path), `${model} open (${now.bricks} parts), ${path || who} on the page`);
    if (!path) { await page.close(); continue; }
    await page.waitForTimeout(8000);
    now = await state();
    const top = now.places[path];
    // Just under the top of his bounds: his hat, or his head.
    const at = { x: top.x, y: top.y + 6 };
    const box = {
      x0: Math.round((at.x - 70) * ratio), x1: Math.round((at.x + 70) * ratio),
      y0: Math.round((at.y - 40) * ratio), y1: Math.round((at.y + 140) * ratio),
    };
    await page.mouse.move(at.x + 300, at.y + 200);
    await page.waitForTimeout(3000);
    const before = decodePng(await page.screenshot({ path: `${out}/${ratio}x_none.png`, timeout: 180000 }));
    await page.mouse.move(at.x, at.y, { steps: 4 });
    await page.waitForTimeout(1500);
    await page.mouse.click(at.x, at.y);
    let picked = 0;
    for (let n = 0; n < 60 && !picked; n++) {
      await page.waitForTimeout(500);
      picked = (await state()).selected || 0;
    }
    ok(picked > 1, `a click on ${path} selects him: ${picked} parts`);
    // Off him, so the hover's own line is not in the picture.
    await page.mouse.move(at.x + 300, at.y + 200);
    // Then nothing from the person for --idle seconds, the selection looked
    // at four times a second: nothing but input may take it away, and the
    // picture after is of it, not of a frame from before the click. Over
    // Orthanc the parts bin's read-backs held the drawing (GpuFence) for
    // 30 s and more, and the picture 4 s after the click was still the one
    // from before it (2026-10-14).
    const held = [];
    for (let n = 0; n < idle * 4; n++) {
      await page.waitForTimeout(250);
      held.push((await state()).selected || 0);
    }
    const lost = held.filter((count) => count !== picked);
    ok(lost.length === 0, `${idle} s with no input: still ${picked} selected in ${held.length - lost.length} `
      + `of ${held.length} looks${lost.length ? ` (${[...new Set(lost)].join(", ")} in the others)` : ""}`);
    const after = decodePng(await page.screenshot({ path: `${out}/${ratio}x_selected.png`, timeout: 180000 }));
    ok(after.width === 1400 * ratio, `the picture is ${after.width} device pixels across`);
    const was = yellow(before, box);
    const is = yellow(after, box);
    ok(is - was > 60 * ratio, `the outline round him: ${is} yellow pixels, ${was} before the click`);

    // Standing still, outlined.
    const from = await page.evaluate(() => performance.now());
    await page.waitForTimeout(seconds * 1000);
    const frames = await page.evaluate((since) => window.brickworksIdle.frames.filter((f) => f[0] >= since), from);
    const drawn = frames.filter((f) => f[1] > 0).length;
    ok(drawn <= seconds, `standing still with him outlined: ${drawn} frames drawn in ${seconds} s (${frames.length} engine frames)`);
    ok(errors.length === 0, `no script or shader errors${errors.length ? ": " + errors.join(" | ") : ""}`);
    report[`${ratio}x`] = { picked, idle_looks: held.length, idle_lost: lost.length, yellow_before: was, yellow_after: is, drawn, frames: frames.length, errors };
    await page.close();
  }
} finally {
  writeFileSync(`${out}/outline.json`, JSON.stringify(report, null, 2));
  await browser.close().catch(() => {});
  if (server) server.kill();
}
console.log(failures === 0
  ? "\noutline in the browser: a click's selection kept with no input and drawn round at 1x and 2x, and nothing drawn standing still"
  : `\noutline in the browser: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
