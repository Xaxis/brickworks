// Best in a browser, path traced on the page's own graphics (photoreal28):
// File, Render…, Product, Best, the picture refining while it is watched,
// Finish now, and the picture downloaded; then the same Best where the
// browser has no graphics card, drawn as frames averaged and saying so.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs PORT --static=build/web &   (a local export; it asks for an account)
//   node tools/web/page_tracer_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=shots/page_tracer
//
// Checks run on SwiftShader, which the app keeps to frames averaged (a
// path traced picture there takes minutes): the first page asks for the
// tracer by its address (?tracer=on), at a small Custom size, so a few
// samples come in a minute. Fails if Best is not path traced there, its
// sample count does not climb while the dialog shows the picture, Finish
// now leaves it running or downloads nothing, the PNG is not the size
// asked or is one flat colour, the page's thread is held over --stall
// seconds (default 2) while it traces, Cancel once it traces leaves it
// running or downloads anything, the page without ?tracer=on does
// not say why its Best is frames averaged or downloads nothing, or a
// script error reaches the console. Says the longest wait for a frame
// while the tracer was readied (its shaders compiled) and while it traced.
// Signs in with the run's own account (it is deleted at the end).
import { clickStill, launch, openFromFile } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8790/index.html";
const out = args.out || "shots/page_tracer";
const stallLimit = Number(args.stall || 2) * 1000;
const [width, height] = String(args.size || "192x108").split("x").map(Number);
const enough = Number(args.samples || 6);
const withParam = (address, param) => `${address}${address.includes("?") ? "&" : "?"}${param}`;
mkdirSync(out, { recursive: true });

// A black 2 x 4 on a white 2 x 4 plate, a clear 1 x 2 beside it: gloss,
// a logo on every stud, and clear plastic the shadow rays go through.
const model = path.resolve(out, "page_tracer.ldr");
writeFileSync(model, [
  "0 Page tracer",
  "0 Name: page_tracer.ldr",
  "1 15 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat",
  "1 0 0 -8 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 47 50 -8 0 0 0 1 0 1 0 -1 0 0 3004.dat",
  "",
].join("\n"));
const PARTS = 3;

const browser = await launch({ ownAccount: true });
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const errors = [];
let failed = 0;
const facts = {};
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};

// The page's longest waits: its thread (a timer every 50 ms) and its frames
// (requestAnimationFrame), each since the last reset.
await context.addInitScript(() => {
  window.__wait = { beat: performance.now(), frame: performance.now(), worstBeat: 0, worstFrame: 0 };
  setInterval(() => {
    const now = performance.now();
    window.__wait.worstBeat = Math.max(window.__wait.worstBeat, now - window.__wait.beat - 50);
    window.__wait.beat = now;
  }, 50);
  const tick = (now) => {
    window.__wait.worstFrame = Math.max(window.__wait.worstFrame, now - window.__wait.frame);
    window.__wait.frame = now;
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
});

async function openPage(address) {
  const page = await context.newPage();
  page.choosers = [];
  page.on("filechooser", (chooser) => page.choosers.push(chooser));
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
  });
  await page.goto(address, { waitUntil: "domcontentloaded", timeout: 180000 });
  const until = Date.now() + 300000;
  while (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).tool_render)))) {
    if (Date.now() > until) throw new Error("the toolbar's Render never appeared");
    await page.waitForTimeout(1000);
  }
  await page.waitForTimeout(Number(args.load || 10000));
  await openFromFile(page, model, { shots: out });
  let opened = null;
  for (let n = 0; n < 480 && !opened; n++) {
    const now = await page.evaluate(() => window.brickworksState || {});
    if (now.bricks === PARTS && !now.awaited) opened = now;
    else await page.waitForTimeout(500);
  }
  check(`the model opened (${opened ? opened.bricks : "no"} parts of ${PARTS})`, Boolean(opened));
  await page.waitForTimeout(3000);
  return page;
}

const where = (page) => async (name, seconds = 60) => {
  for (let n = 0; n < seconds * 2; n++) {
    const at = await page.evaluate((k) => (window.brickworksControls || {})[k], name);
    if (at) return at;
    await page.waitForTimeout(500);
  }
  return null;
};
const press = (page, name) => clickStill(page, name, { find: where(page), after: 1100 });
const state = (page) => page.evaluate(() => window.brickworksRender || {});
const waits = (page) => page.evaluate(() => ({ beat: Math.round(window.__wait.worstBeat),
  frame: Math.round(window.__wait.worstFrame) }));
const resetWaits = (page) => page.evaluate(() => { window.__wait.worstBeat = 0; window.__wait.worstFrame = 0; });

// Product, Best, Custom at width x height: what a person presses.
async function chooseBest(page) {
  await press(page, "tool_render");
  check("the toolbar's Render opens the dialog", Boolean(await where(page)("render_picture", 30)));
  await press(page, "render_look_product");
  await press(page, "render_best");
  await press(page, "render_size_custom");
  for (const [name, value] of [["render_width", width], ["render_height", height]]) {
    await press(page, name);
    await page.keyboard.press("Control+A");
    await page.keyboard.type(String(value), { delay: 80 });
    await page.keyboard.press("Enter");
    await page.waitForTimeout(800);
  }
}

// What a picture holds: its size, and how far its lightness spreads.
function measure(page, file) {
  const data = readFileSync(file).toString("base64");
  return page.evaluate(async (b64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${b64}`;
    await image.decode();
    const canvas = document.createElement("canvas");
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const g = canvas.getContext("2d");
    g.drawImage(image, 0, 0);
    const { data } = g.getImageData(0, 0, canvas.width, canvas.height);
    let sum = 0; let squares = 0;
    for (let i = 0; i < data.length; i += 4) {
      const lum = (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) / 255;
      sum += lum;
      squares += lum * lum;
    }
    const n = data.length / 4;
    const mean = sum / n;
    return { width: canvas.width, height: canvas.height, spread: Math.sqrt(Math.max(squares / n - mean * mean, 0)) };
  }, data);
}

async function keep(download, label) {
  const got = await download;
  if (!got) return null;
  const file = path.join(out, `${label}.png`);
  await got.saveAs(file);
  return file;
}

try {
  // The tracer, asked for by the address.
  const page = await openPage(withParam(url, "tracer=on"));
  await chooseBest(page);
  const download = page.waitForEvent("download", { timeout: 20 * 60000 }).catch(() => null);
  const started = Date.now();
  await resetWaits(page);
  await press(page, "render_picture");
  let seen = {};
  let readied = null;
  let tracedAt = 0;
  const counts = new Set();
  let finished = false;
  let shot = 0;
  for (let n = 0; n < 20 * 120; n++) {
    seen = await state(page);
    if (seen.working === "picture" && seen.traced && seen.samples > 0) {
      if (!readied) {
        // The shaders compiled and the first samples in: the wait for a frame
        // until now was the readying's.
        readied = await waits(page);
        tracedAt = Date.now();
        await resetWaits(page);
      }
      counts.add(seen.samples);
      if (shot < 2 && counts.size >= 2 + shot * 2) {
        await page.screenshot({ path: path.join(out, `refining_${shot}.png`), timeout: 120000 });
        shot += 1;
      }
      if (!finished && seen.samples >= enough && seen.finish) {
        await press(page, "render_finish");
        finished = Date.now();
      }
    }
    if (n % 20 === 0 && seen.working) {
      console.log(`      ${seen.words || ""} ${Math.round((seen.fraction || 0) * 100)}%, ${seen.samples || 0} samples`);
    }
    if (seen.working === "" && n > 20) break;
    await page.waitForTimeout(500);
  }
  const tracing = await waits(page);
  const file = await keep(download, "best_traced");
  const seconds = Math.round((Date.now() - started) / 1000);
  await page.screenshot({ path: path.join(out, "best_traced_dialog.png"), timeout: 120000 });
  console.log(`      (Best: ${seconds} s, "${seen.status}"; readying: the page's thread waited at most`
    + ` ${readied ? readied.beat : "?"} ms, a frame ${readied ? readied.frame : "?"} ms; tracing: ${tracing.beat} ms,`
    + ` a frame ${tracing.frame} ms; first samples ${tracedAt ? Math.round((tracedAt - started) / 1000) : "?"} s in)`);
  facts.traced = { seconds, status: seen.status, readied, tracing, counts: [...counts], samples: seen.samples };
  check(`Best is path traced here (the page says traced: ${seen.traced})`, seen.traced === true);
  check(`its samples climb while the dialog shows it (${[...counts].slice(0, 12).join(", ")})`, counts.size >= 2);
  check(`Finish now ends it at ${seen.samples} samples (pressed at ${enough} or more)`,
    Boolean(finished) && seen.working === "" && seen.samples >= enough && seen.samples < 256);
  const shown = file ? await measure(page, file) : null;
  check(`it downloads a ${width}x${height} PNG, not flat (${shown ? `${shown.width}x${shown.height}, spread ${shown.spread.toFixed(3)}` : "none"})`,
    Boolean(shown) && shown.width === width && shown.height === height && shown.spread > 0.02);
  check(`the result does not say frames averaged ("${seen.status}")`, !/frames averaged/.test(seen.status || ""));
  check(`the page's thread is never held over ${stallLimit} ms while it traces (${tracing.beat} ms)`,
    tracing.beat <= stallLimit);

  // Cancel once it traces: nothing downloaded, nothing left running, and the
  // next Best traces again from its first sample.
  let downloadedAnyway = false;
  const stray = (d) => { downloadedAnyway = true; d.cancel().catch(() => {}); };
  page.on("download", stray);
  await press(page, "render_picture");
  let running = {};
  for (let n = 0; n < 10 * 120; n++) {
    running = await state(page);
    if (running.working === "picture" && running.traced && running.samples > 0) break;
    await page.waitForTimeout(500);
  }
  await press(page, "render_cancel");
  let stopped = {};
  for (let n = 0; n < 120; n++) {
    stopped = await state(page);
    if (stopped.working === "") break;
    await page.waitForTimeout(500);
  }
  page.off("download", stray);
  check(`Cancel stops a traced Best (was at ${running.samples || 0} samples, then "${stopped.status}")`,
    running.working === "picture" && running.traced === true && stopped.working === ""
    && /Cancel/.test(stopped.status || "") && !downloadedAnyway);
  await page.close();

  // No graphics card: Best as frames averaged, and the result says why.
  const plain = await openPage(url);
  await chooseBest(plain);
  const second = plain.waitForEvent("download", { timeout: 20 * 60000 }).catch(() => null);
  await press(plain, "render_picture");
  let after = {};
  for (let n = 0; n < 20 * 120; n++) {
    after = await state(plain);
    if (after.working === "" && n > 20) break;
    await plain.waitForTimeout(500);
  }
  const averaged = await keep(second, "best_averaged");
  await plain.screenshot({ path: path.join(out, "best_averaged_dialog.png"), timeout: 120000 });
  const why = "This browser draws without a graphics card, too slowly to path trace, so Best is frames averaged.";
  check(`without ?tracer=on Best is frames averaged and says why ("${after.status}")`,
    after.traced === false && (after.status || "").includes(why));
  const flat = averaged ? await measure(plain, averaged) : null;
  check(`and downloads its picture (${flat ? `${flat.width}x${flat.height}` : "none"})`,
    Boolean(flat) && flat.width === width && flat.height === height);
  await plain.close();
} catch (trouble) {
  check(`the flow ran to its end (${trouble.message})`, false);
}
check(`no script errors (${errors.length}: ${errors.slice(0, 3).join(" | ")})`, errors.length === 0);
writeFileSync(path.join(out, "summary.json"), JSON.stringify({ failed, facts, errors }, null, 2));
await browser.close();
console.log(failed ? `page_tracer_flow: ${failed} FAILED` : "page_tracer_flow: all passed");
process.exit(failed ? 1 : 0);
