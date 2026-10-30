// File, Render… in a real browser: Quick and Good pictures, a short
// turntable and an animation of a motion, each downloaded, with the page
// answering throughout.
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
// Good at 720p, a 24-frame turntable at 720p, and a Best it cancels. Then
// opens a small crane from a file whose main model carries a motion (its
// turret turned a quarter round in 1 s, docs/MOTIONS.md) and renders it
// from Render's Animation, framed on what moves: a WebP of the motion's 25
// frames named after the model and the motion. Fails
// if a control never appears, a render downloads nothing, a PNG is not the
// size chosen, the WebP is not an animation of 24 frames that the browser
// decodes, Cancel leaves a render running, the page stops answering for
// longer than --stall seconds (default 2) or twice what the app alone makes
// it wait while turning the view on the same machine, whichever is longer,
// or a script error reaches the console. Each render also says which of
// its frames was longest and what it was doing then (StudioRender's
// worst_step). Leaves OUT/*.png, the downloads and a summary.
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

// The crane flex_pose_flow builds on, with a motion of its own in the main
// model's head, where the app writes them.
const crane = path.resolve(out, "crane_motion.mpd");
writeFileSync(crane, [
  "0 FILE crane_motion.ldr",
  "0 Crane motion",
  "0 Name: crane_motion.ldr",
  '0 !BRICKWORKS MOTION "Turn the turret" AFTER "" SECONDS 1',
  '0 !BRICKWORKS MOTION_TRACK "Turn the turret" 1 TURN AT 0 JOINT PART 3680 7 0 -8 -80',
  '0 !BRICKWORKS MOTION_KEY "Turn the turret" 1 0 0 EASE',
  '0 !BRICKWORKS MOTION_KEY "Turn the turret" 1 1 90 EASE',
  "1 7 -60 -24 60 1 0 0 0 1 0 0 0 1 3700.dat",
  "1 7 20 -24 60 1 0 0 0 1 0 0 0 1 3700.dat",
  "1 7 0 -8 -80 1 0 0 0 1 0 0 0 1 3680.dat",
  "1 16 0 -8 -80 1 0 0 0 1 0 0 0 1 turret.ldr",
  "0",
  "0 FILE turret.ldr",
  "0 Turret",
  "0 Name: turret.ldr",
  "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3679.dat",
  "1 7 0 -24 0 1 0 0 0 1 0 0 0 1 3937.dat",
  "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 arm.ldr",
  "0",
  "0 FILE arm.ldr",
  "0 Arm",
  "0 Name: arm.ldr",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3938.dat",
  "1 4 0 -8 -50 0 0 1 0 1 0 -1 0 0 3795.dat",
  "0",
  "",
].join("\n"));

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
page.on("console", (m) => {
  if (/SCRIPT ERROR|Parse Error|ERROR:/.test(m.text())) errors.push(m.text().slice(0, 200));
  if (/^render: /.test(m.text())) console.log(`      (${m.text()})`);
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

// The dialog's choices scroll, and the app tells where a control is even
// when it is scrolled out of sight: a click there lands on whatever is
// drawn instead. Turntable's frames went out of sight at 1400x900 when the
// choices grew (Product, Light, Lens, focus), and the 24 the check pressed
// never took (rel-m226). A person scrolls the choices until it shows.
const CHOICE = /^render_(quick|good|best|size_|bg_|look_|frames_|camera_|motion|light|view)/;

async function inView(name) {
  let at = await where(name);
  const box = CHOICE.test(name) ? await where("render_choices", 5) : null;
  for (let n = 0; at && box && n < 12; n++) {
    const top = box.y - box.h / 2;
    const bottom = box.y + box.h / 2;
    if (at.y - at.h / 2 >= top && at.y + at.h / 2 <= bottom) break;
    await page.mouse.move(box.x, box.y);
    await page.mouse.wheel(0, at.y > bottom - at.h / 2 ? 240 : -240);
    await page.waitForTimeout(1100);
    at = await where(name);
  }
  return at;
}

async function press(name) {
  const at = await inView(name);
  if (!at) throw new Error(`no ${name} on the page`);
  await page.mouse.click(at.x, at.y);
  // The app tells the page where its controls are twice a second, and a
  // press can move the ones under it.
  await page.waitForTimeout(1100);
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
  const download = page.waitForEvent("download", { timeout: minutes * 60000 }).catch(() => null);
  const started = Date.now();
  await press(button);
  const kind = { render_turntable: "turntable", render_animation: "animation" }[button] || "picture";
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
    file = path.join(out, `${label}_${got.suggestedFilename()}`);
    await got.saveAs(file);
  }
  const stall = await worstStall();
  await page.screenshot({ path: path.join(out, `${label}.png`), timeout: 120000 });
  console.log(`      (${label}: ${seconds} s, ${seen && seen.status}, the page's longest wait so far ${stall} ms;`
    + ` the render's longest frame ${seen && seen.worst_frame_ms} ms, ${seen && seen.worst_step})`);
  facts[label] = { seconds, stall, status: seen && seen.status, file };
  return { file, seen, stall, seconds };
}

// Open, From a file, and the file given to the page's chooser.
async function openFile(file) {
  const at = await where("open", 120);
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
      await page.waitForTimeout(500);
    }
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
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
  // What the app alone holds the page for, turning the view: the yardstick
  // for the render's own waits, on a machine drawing in software.
  const view = await where("view", 10);
  if (view) {
    await page.mouse.move(view.x, view.y);
    await page.mouse.down({ button: "right" });
    for (let n = 0; n < 10; n++) {
      await page.mouse.move(view.x + 20 * n, view.y, { steps: 2 });
      await page.waitForTimeout(300);
    }
    await page.mouse.up({ button: "right" });
  }
  await page.waitForTimeout(3000);
  facts.app_stall = await worstStall();
  console.log(`      (the app alone, turning the view: the page's longest wait ${facts.app_stall} ms)`);
  await resetStall();
  await page.screenshot({ path: path.join(out, "0_app.png"), timeout: 120000 });

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
  await page.screenshot({ path: path.join(out, "1_dialog.png"), timeout: 120000 });
  check("it draws a draft of the render", drafted);
  facts.draft_stall = await worstStall();
  // From here every wait counts: the drafts each choice draws as well as
  // the renders. The heartbeat keeps the longest so far.
  await resetStall();

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

  // Animation: the crane's own motion, framed on what moves.
  await press("render_close");
  await openFile(crane);
  let opened = null;
  for (let n = 0; n < 480 && !opened; n++) {
    const now = await page.evaluate(() => window.brickworksState || {});
    if (now.bricks === 7 && !/arriving/.test(now.said || "")) opened = now;
    else await page.waitForTimeout(500);
  }
  check(`the crane with a motion of its own opened (${opened ? opened.bricks : "no"} parts)`, Boolean(opened));
  await page.waitForTimeout(3000);
  await press("tool_render");
  await where("render_animation", 30);
  // Quick and 720p at the top of the choices, before they scroll away.
  await press("render_quick");
  await press("render_size_720p");
  // Animation sits under Turntable in the choices: press scrolls to it.
  await press("render_camera_moves");
  const animation = await renderAndKeep("render_animation", "5_animation", 30);
  const animationFrames = animation.file ? webpFrames(animation.file) : -1;
  const animationName = animation.file ? path.basename(animation.file).replace(/^5_animation_/, "") : "";
  check(`Animation downloads "${animationName}", an animated WebP of the motion's 25 frames (${animationFrames})`,
    animationFrames === 25 && / Turn the turret\.webp$/.test(animationName)
    && animation.seen && animation.seen.kind === "animation");
  if (animation.file) {
    const data = readFileSync(animation.file).toString("base64");
    const decoded = await page.evaluate(async (b64) => {
      const image = new Image();
      image.src = `data:image/webp;base64,${b64}`;
      try { await image.decode(); } catch { return null; }
      return { width: image.naturalWidth, height: image.naturalHeight };
    }, data);
    check(`and the browser decodes it (${decoded ? `${decoded.width}x${decoded.height}` : "no"})`,
      decoded && decoded.width === 1280 && decoded.height === 720);
  }

  const worst = await worstStall();
  // Measured against the app itself on the same machine: in a browser
  // drawing in software one frame of the app turning its view is seconds,
  // and no render can draw faster than the engine draws a frame.
  const limit = Math.max(stallLimit, 2 * (facts.app_stall || 0));
  facts.limit = limit;
  check(`the page answered while rendering (longest wait ${worst} ms; limit ${limit}, twice the app's own ${facts.app_stall} ms or ${stallLimit})`,
    worst <= limit);
  // Opening the panel the first time builds its viewports, and their
  // shaders are compiled then, once a session: in software that is seconds
  // whatever is done with it, so it has a limit of its own.
  const openLimit = Math.max(15000, 4 * (facts.app_stall || 0));
  check(`opening it the first time (building its shaders once) waited ${facts.draft_stall} ms, limit ${openLimit}`,
    facts.draft_stall <= openLimit);
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
