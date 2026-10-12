// File, Render… in a real browser: Quick and Good pictures and a short
// turntable, each downloaded, with the page answering throughout.
//
//   set -a; . ./.env; set +a
//   node tools/web/render_flow.mjs --url=https://<preview>.vercel.app/app --bypass=$VERCEL_BYPASS --out=shots/render_web
//   node tools/web/render_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=…   (a local export)
//
// The web build draws with the Compatibility renderer, in a browser that
// shares the page's one thread with everything else, so this is the path
// the desktop probe (src/dev/render_probe.gd) cannot vouch for: a render
// that works there and freezes a tab, or downloads nothing, would pass it.
// The dialog is drawn inside the canvas, so it is driven by position (the
// app publishes where its controls are, window.brickworksControls) and its
// state is read from window.brickworksRender.
//
// Presses the toolbar's Render, waits for the draft, then: Quick at 1080p,
// Good at 720p, a 24-frame turntable at 720p, and a Best it cancels. Fails
// if a control never appears, a render downloads nothing, a PNG is not the
// size chosen, the WebP is not an animation of 24 frames that the browser
// decodes, Cancel leaves a render running, the page stops answering for
// longer than --stall seconds (default 2) at any point, or a script error
// reaches the console. Leaves OUT/*.png, the downloads and a summary.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/render_web";
const stallLimit = Number(args.stall || 2) * 1000;
// A preview is behind Vercel's protection: the bypass, once, as a cookie.
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
});
let failed = 0;
const facts = {};
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};

async function where(name, seconds = 60) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = await page.evaluate((k) => (window.brickworksControls || {})[k], name);
    if (at) return at;
    await page.waitForTimeout(500);
  }
  return null;
}

async function press(name) {
  const at = await where(name);
  if (!at) throw new Error(`no ${name} on the page`);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(600);
}

const state = () => page.evaluate(() => window.brickworksRender || {});

// How long the page went without answering: a timer every 50 ms that
// notes how late it ran. A frame that holds the page's thread holds this.
async function startHeartbeat() {
  await page.evaluate(() => {
    window.__beat = { last: performance.now(), worst: 0 };
    setInterval(() => {
      const now = performance.now();
      window.__beat.worst = Math.max(window.__beat.worst, now - window.__beat.last - 50);
      window.__beat.last = now;
    }, 50);
  });
}
const worstStall = () => page.evaluate(() => Math.round(window.__beat.worst));
const resetStall = () => page.evaluate(() => { window.__beat.worst = 0; });

// Render, wait for the download, keep it, and wait for the dialog to settle.
async function renderAndKeep(button, label, minutes) {
  await resetStall();
  const download = page.waitForEvent("download", { timeout: minutes * 60000 }).catch(() => null);
  const started = Date.now();
  await press(button);
  const kind = button === "render_turntable" ? "turntable" : "picture";
  let seen = null;
  let began = false;
  for (let n = 0; n < minutes * 120; n++) {
    seen = await state();
    began = began || seen.working === kind;
    if (!began && n > 60) break;
    if (began && seen.working === "") break;
    if (n % 20 === 0 && seen.working) {
      console.log(`      ${label}: ${seen.words || ""} ${Math.round((seen.fraction || 0) * 100)}%`);
    }
    await page.waitForTimeout(500);
  }
  const got = await download;
  const seconds = Math.round((Date.now() - started) / 1000);
  let file = null;
  if (got) {
    file = path.join(out, got.suggestedFilename());
    await got.saveAs(file);
  }
  const stall = await worstStall();
  await page.screenshot({ path: path.join(out, `${label}.png`) });
  console.log(`      (${label}: ${seconds} s, ${seen && seen.status}, the page's longest wait ${stall} ms)`);
  facts[label] = { seconds, stall, status: seen && seen.status, file };
  return { file, seen, stall, seconds };
}

function pngSize(file) {
  const bytes = readFileSync(file);
  if (bytes.slice(1, 4).toString() !== "PNG") return null;
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

function webpFrames(file) {
  const bytes = readFileSync(file);
  if (bytes.slice(0, 4).toString() !== "RIFF" || bytes.slice(8, 12).toString() !== "WEBP") return -1;
  let at = 12;
  let frames = 0;
  while (at + 8 <= bytes.length) {
    const tag = bytes.slice(at, at + 4).toString();
    const length = bytes.readUInt32LE(at + 4);
    if (tag === "ANMF") frames += 1;
    at += 8 + length + (length & 1);
  }
  return frames;
}

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  const until = Date.now() + 300000;
  while (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).tool_render)))) {
    if (Date.now() > until) throw new Error("the toolbar's Render never appeared");
    await page.waitForTimeout(1000);
  }
  // The example car's parts arrive over the network after the toolbar does.
  await page.waitForTimeout(Number(args.load || 20000));
  await startHeartbeat();
  await page.screenshot({ path: path.join(out, "0_app.png") });

  await press("tool_render");
  const picture = await where("render_picture", 30);
  check("the toolbar's Render opens the dialog", Boolean(picture));
  // The draft is drawn without asking.
  let drafted = false;
  for (let n = 0; n < 240 && !drafted; n++) {
    const seen = await state();
    drafted = seen.open && seen.working === "" && /draft|Render draws/.test(seen.status || "");
    if (!drafted) await page.waitForTimeout(500);
  }
  await page.screenshot({ path: path.join(out, "1_dialog.png") });
  check("it draws a draft of the render", drafted);
  facts.draft_stall = await worstStall();

  // Quick, 1080p.
  await press("render_quick");
  await press("render_size_1080p");
  const quick = await renderAndKeep("render_picture", "2_quick", 10);
  const quickSize = quick.file ? pngSize(quick.file) : null;
  check(`Quick downloads a PNG at 1920x1080 (${quickSize ? `${quickSize.width}x${quickSize.height}` : "none"})`,
    quickSize && quickSize.width === 1920 && quickSize.height === 1080);

  // Good, 720p.
  await press("render_good");
  await press("render_size_720p");
  const good = await renderAndKeep("render_picture", "3_good", 20);
  const goodSize = good.file ? pngSize(good.file) : null;
  check(`Good downloads a PNG at 1280x720 (${goodSize ? `${goodSize.width}x${goodSize.height}` : "none"})`,
    goodSize && goodSize.width === 1280 && goodSize.height === 720);

  // A short turntable: 24 frames at 720p, Quick.
  await press("render_quick");
  await press("render_frames_24");
  const turn = await renderAndKeep("render_turntable", "4_turntable", 30);
  const frames = turn.file ? webpFrames(turn.file) : -1;
  check(`the turntable downloads an animated WebP of 24 frames (${frames})`, frames === 24);
  if (turn.file) {
    const data = readFileSync(turn.file).toString("base64");
    const decoded = await page.evaluate(async (b64) => {
      const image = new Image();
      image.src = `data:image/webp;base64,${b64}`;
      try { await image.decode(); } catch { return null; }
      return { width: image.naturalWidth, height: image.naturalHeight };
    }, data);
    check(`and the browser decodes it (${decoded ? `${decoded.width}x${decoded.height}` : "no"})`,
      decoded && decoded.width === 1280 && decoded.height === 720);
  }

  // Best, cancelled: nothing downloaded, nothing left running.
  await press("render_best");
  await resetStall();
  let downloadedAnyway = false;
  const stray = (d) => { downloadedAnyway = true; d.cancel().catch(() => {}); };
  page.on("download", stray);
  await press("render_picture");
  await page.waitForTimeout(Number(args.cancel_after || 5000));
  const running = await state();
  await press("render_cancel");
  let stopped = null;
  for (let n = 0; n < 120; n++) {
    stopped = await state();
    if (stopped.working === "") break;
    await page.waitForTimeout(500);
  }
  page.off("download", stray);
  check(`Cancel stops Best (was ${running.working} at ${Math.round((running.fraction || 0) * 100)}%, then "${stopped.status}")`,
    running.working === "picture" && stopped.working === "" && /Cancel/.test(stopped.status || "")
    && !downloadedAnyway);

  const worst = Math.max(facts.draft_stall || 0, ...["2_quick", "3_good", "4_turntable"]
    .map((k) => (facts[k] || {}).stall || 0), await worstStall());
  check(`the page answered throughout (longest wait ${worst} ms, limit ${stallLimit})`, worst <= stallLimit);
  await press("render_close");
} catch (error) {
  check(String(error), false);
} finally {
  check(`no script errors (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 5)) console.log(`      ${e}`);
  writeFileSync(path.join(out, "summary.json"), JSON.stringify(facts, null, 2));
  await browser.close();
  console.log(failed ? `${failed} failed` : "rendered, downloaded and answered throughout");
  process.exit(failed ? 1 : 0);
}
