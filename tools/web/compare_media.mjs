// The pictures and clips of /compare, taken from a real deployment in a real
// browser window: its tabs and its address bar are in the pictures.
//
//   ~/.claude/claude-core/bin/heavy xvfb-run -a --server-args="-screen 0 1600x1000x24" \
//     node --env-file=.env tools/web/compare_media.mjs [--url=https://brickworks.diy/app] \
//     [--out=shots/compare] [--only=browser,tabs,simulate,stability,io,export3d,booklet]
//   node tools/web/compare_media.mjs --encode [--out=shots/compare]   # the WebP, WebM and MP4 in web/img/
//
// Headed Chromium on SwiftShader (browser.mjs's flags), signed in as the
// test account (session.mjs), one window of 1600 x 1000 at the top left of
// the X display, so ffmpeg's x11grab can take the window as a person sees
// it. Three tabs, each on an example opened by the address the home page's
// "Open it" links use:
//
//   browser    the castle's tab, the whole window: the app in a browser tab.
//   tabs       a clip going through the three tabs, each its own model.
//   simulate   the orrery's tab: Tools, Simulate mechanism…, Play; a still
//              of the panel's readout and a long clip of the planets turning.
//   stability  a fourth tab, on the tree (STABILITY): Tools, Check stability;
//              a clip from the menu to the marks on the floor.
//   io         the tree: File, Export, with BrickLink Studio model (.io) lit.
//   export3d   the kart: File, Export, 3D model…, its list of formats open.
//   booklet    the kart: the toolbar's Instructions, the booklet's own tab at
//              its last page of steps.
//
// What each scene did is read off the page (window.brickworksState,
// brickworksSimulate) and printed, so a picture of the wrong thing fails
// the run rather than reaching the site. Pictures and clips go to --out as
// PNG and lossless MKV; --encode crops and encodes them (CROPS).
import { chromium } from "playwright";
import { spawn, execFileSync } from "node:child_process";
import { mkdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { SOFTWARE, START_MS } from "./browser.mjs";
import { canSignIn, signInContext } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = resolve(args.out || "shots/compare");
const only = args.only ? String(args.only).split(",") : null;
const wanted = (scene) => !only || only.includes(scene);
const W = 1600;
const H = 1000;
// The example Check stability is shown on: its title, and its file in
// models/. On 2026-10-13 every shipped example stood, the tree nearest to
// tipping (2 studs inside its back edge, a 15° tilt), and it fills the view:
// the boat was 1.4 studs inside but low and wide, the castle 31.8.
const STABILITY = "Tree:tree";

// -- encoding: --encode -------------------------------------------------------
//
// What goes on the page, from what a run left in --out: each picture or
// clip cropped to 16:10 (x, y and width in the 1600 x 1000 window), scaled
// to 1200 x 750, and 640 x 400 too for a picture. A clip is cut to the part
// worth watching (from, to, in seconds), sped up where a person would only
// wait (speed), and written as a VP9 WebM and an H.264 MP4, muted, under
// 1.5 MB each, with its poster from the still the scene took (poster). A
// clip of the app's own slow frames (distinct) keeps only the frames that
// differ from the one before, played at fps. The crops and cuts were chosen
// by looking at what a run took.
const CROPS = {
  tabs: { clip: true, x: 0, y: 0, w: 1600, poster: "browser" },
  stability: { clip: true, x: 228, y: 87, w: 1100, from: 12.8, to: 20.6, speed: 1.15, poster: "stability" },
  simulate: { clip: true, x: 20, y: 145, w: 1160, poster: "simulate", distinct: true, fps: 8 },
  io: { x: 90, y: 86, w: 1100 },
  export3d: { x: 362, y: 170, w: 1060 },
  booklet: { x: 0, y: 0, w: 1600 },
};
if (args.encode) {
  const img = resolve(args.img || "web/img");
  const ff = (...a) => execFileSync("ffmpeg", ["-y", "-loglevel", "error", ...a]);
  const kb = (file) => Math.round(statSync(file).size / 1024);
  for (const [name, c] of Object.entries(CROPS)) {
    if (only && !only.includes(name)) continue;
    const h = Math.round((c.w * 10) / 16);
    const crop = `crop=${c.w}:${h}:${c.x}:${c.y}`;
    const scale = (w) => `scale=${w}:${Math.round((w * 10) / 16)}:flags=lanczos`;
    if (c.clip) {
      const cut = [...(c.from ? ["-ss", String(c.from)] : []), ...(c.to ? ["-to", String(c.to)] : [])];
      const src = ["-i", `${out}/${name}.mkv`];
      const fps = Number(c.fps || 12);
      let vf = `${crop},${scale(1200)},setpts=PTS/${c.speed || 1},fps=${fps},format=yuv420p`;
      if (c.distinct) {
        // Small grey copies of every frame, each compared with the last one
        // kept: a frame is new when more than 0.2% of it changed visibly.
        const [tw, th] = [320, 200];
        const raw = execFileSync("ffmpeg", ["-loglevel", "error", ...cut, ...src, "-vf",
          `${crop},scale=${tw}:${th},format=gray`, "-f", "rawvideo", "-"], { maxBuffer: 1 << 30 });
        const size = tw * th;
        const kept = [0];
        for (let n = 1; (n + 1) * size <= raw.length; n++) {
          const a = raw.subarray(kept.at(-1) * size, (kept.at(-1) + 1) * size);
          const b = raw.subarray(n * size, (n + 1) * size);
          let changed = 0;
          for (let i = 0; i < size; i++) if (Math.abs(a[i] - b[i]) > 12) changed++;
          if (changed > size * 0.002) kept.push(n);
        }
        console.log(`  ${name}: ${kept.length} distinct frames of ${raw.length / size}`);
        const picks = kept.map((n) => `eq(n\\,${n})`).join("+");
        vf = `select=${picks},setpts=N/(${fps}*TB),${crop},${scale(1200)},format=yuv420p`;
      }
      ff("-i", `${out}/${c.poster || name}.png`, "-vf", `${crop},${scale(1200)}`, "-c:v", "libwebp",
        "-quality", "80", `${img}/compare-${name}.webp`);
      const rate = c.distinct ? ["-r", String(fps)] : [];
      ff(...cut, ...src, "-an", "-vf", vf, ...rate, "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", String(c.crf || 32),
        "-row-mt", "1", "-deadline", "good", "-cpu-used", "2", `${img}/compare-${name}.webm`);
      ff(...cut, ...src, "-an", "-vf", vf, ...rate, "-c:v", "libx264", "-profile:v", "high", "-crf", String(c.crf264 || 23),
        "-preset", "slow", "-movflags", "+faststart", `${img}/compare-${name}.mp4`);
      console.log(`  ${name}: poster ${kb(`${img}/compare-${name}.webp`)} KB, webm ${kb(`${img}/compare-${name}.webm`)} KB, mp4 ${kb(`${img}/compare-${name}.mp4`)} KB`);
    } else {
      for (const w of [1200, 640]) {
        ff("-i", `${out}/${name}.png`, "-vf", `${crop},${scale(w)}`, "-c:v", "libwebp", "-quality", "82",
          `${img}/compare-${name}-${w}.webp`);
      }
      console.log(`  ${name}: ${kb(`${img}/compare-${name}-1200.webp`)} KB and ${kb(`${img}/compare-${name}-640.webp`)} KB`);
    }
  }
  process.exit(0);
}

const display = process.env.DISPLAY;
if (!display) {
  console.error("compare_media: no DISPLAY; run it under xvfb-run with a 1600x1000 screen");
  process.exit(2);
}
mkdirSync(out, { recursive: true });

const t0 = Date.now();
const problems = [];
const say = (passed, line) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) problems.push(line);
  return passed;
};

// -- the window, grabbed ------------------------------------------------------

const where = { page: { x: 0, y: 0, w: W, h: H } };

/// The whole window as it is now, the pointer left out.
function grab(name) {
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-f", "x11grab", "-draw_mouse", "0",
    "-video_size", `${W}x${H}`, "-i", `${display}+0,0`, "-frames:v", "1", `${out}/${name}.png`]);
  console.log(`        picture: ${out}/${name}.png`);
}

/// A clip of the window, lossless, while [during] runs; it goes on for
/// [tail] ms after.
async function record(name, during, { fps = 12, tail = 0 } = {}) {
  const file = `${out}/${name}.mkv`;
  const ffmpeg = spawn("ffmpeg", ["-y", "-loglevel", "error", "-f", "x11grab", "-draw_mouse", "0",
    "-framerate", String(fps), "-video_size", `${W}x${H}`, "-i", `${display}+0,0`,
    "-c:v", "libx264rgb", "-crf", "0", "-preset", "ultrafast", file], { stdio: ["pipe", "inherit", "inherit"] });
  await new Promise((done) => setTimeout(done, 400));
  try {
    await during();
    if (tail) await new Promise((done) => setTimeout(done, tail));
  } finally {
    ffmpeg.stdin.write("q");
    await new Promise((done) => ffmpeg.on("close", done));
  }
  console.log(`        clip: ${file}`);
}

// -- the app ------------------------------------------------------------------

const profile = resolve(out, ".profile");
rmSync(profile, { recursive: true, force: true });
const context = await chromium.launchPersistentContext(profile, {
  headless: false,
  viewport: null,
  acceptDownloads: true,
  args: [...SOFTWARE, "--window-position=0,0", `--window-size=${W},${H}`,
    "--no-first-run", "--no-default-browser-check", "--hide-crash-restore-bubble"],
  // Not "controlled by automated test software" across the top.
  ignoreDefaultArgs: ["--enable-automation"],
});
if (canSignIn()) await signInContext(context);
else console.log("  (not signed in: run with node --env-file=.env; the app will show its sign-in screen)");

const errors = [];
function watch(page) {
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|USER ERROR|Parse Error/i.test(m.text())) errors.push(m.text().slice(0, 300));
  });
}

const state = (page) => page.evaluate(() => window.brickworksState || {});
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
async function control(page, name, seconds = 120) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls(page))[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}
async function until(page, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    const now = await state(page);
    if (test(now)) return now;
    await page.waitForTimeout(500);
  }
  return null;
}
async function press(page, name, pause = 2500) {
  const at = await control(page, name);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(pause);
}
/// Tools, and one of its items by the pointer: hovered (lit, in a clip),
/// then clicked. Its rows, under the bar's Tools: Check stability 253 px
/// down, Simulate mechanism… 275. Not typed, as app_shot picks items: when
/// the menu came up later than the typing, the letters went to the app as
/// keys (H, the Hide tool, from "Check"). Tried again until [done] says
/// it happened.
const TOOLS = { stability: 253, simulate: 275 };
async function tools(page, item, done) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const at = await control(page, "menu_tools");
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(3000);
    await page.mouse.move(at.x + 50, at.y + TOOLS[item], { steps: 8 });
    await page.waitForTimeout(1500);
    await page.mouse.click(at.x + 50, at.y + TOOLS[item]);
    for (let n = 0; n < 20; n++) {
      await page.waitForTimeout(500);
      if (await done()) return true;
    }
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1500);
  }
  return false;
}

/// A tab with an example open in it, by the address the home page's "Open
/// it" links use (/app?model=res://models/<file>.ldr), and the tab's title
/// then naming it. Not Open… with the name typed into its list: in software
/// the list can take longer to come up than the typing, and the letters that
/// came first went to the app as keys (K, the cut-away, was on in the kart).
async function tab(page, name, file) {
  watch(page);
  await page.goto(`${url}${url.includes("?") ? "&" : "?"}model=res://models/${file}.ldr`,
    { waitUntil: "domcontentloaded", timeout: 180000 });
  await control(page, "open", START_MS / 1000);
  // Open, and every part of it in: the count the same for five seconds.
  let last = -1;
  let same = 0;
  for (let n = 0; n < 480 && same < 10; n++) {
    await page.waitForTimeout(500);
    const now = await state(page);
    const named = (await page.title()).startsWith(name);
    same = named && now.bricks > 0 && now.bricks === last && !/arriving/i.test(now.said || "") ? same + 1 : 0;
    last = now.bricks;
  }
  const opened = same >= 10;
  const now = await state(page);
  say(opened, `${name}: ${now.bricks} parts open, the tab titled "${await page.title()}"`);
  // A first visit shows the assistant's column; folded, as a builder who
  // builds by hand keeps it, so the model has the room.
  if ((now.columns || {}).assistant) await press(page, "assistant_rail", 3000);
  await page.mouse.move(W - 4, H - 4);
  await page.waitForTimeout(Number(args.settle || 15000));
  return page;
}

// The window's own first tab, then two more: each a page of this context,
// which a headed browser shows as tabs of one window.
const castle = await tab(context.pages()[0] || await context.newPage(), "Castle", "castle");
where.page = await castle.evaluate(() => ({ x: 0, y: window.outerHeight - window.innerHeight,
  w: window.innerWidth, h: window.innerHeight }));
const kart = (wanted("tabs") || wanted("export3d") || wanted("booklet"))
  ? await tab(await context.newPage(), "Technic Go-Kart", "kart") : null;
const orrery = (wanted("tabs") || wanted("simulate"))
  ? await tab(await context.newPage(), "Orrery", "orrery") : null;
console.log(`  the page is at ${JSON.stringify(where.page)} in the window`);

// -- the scenes ---------------------------------------------------------------

/// A tab to the front, as a click on it does, and given time to draw: a
/// hidden tab draws nothing, and its first frames back are slow in software.
async function front(page, settle = 6000) {
  await page.bringToFront();
  await page.mouse.move(W - 4, H - 4);
  await page.waitForTimeout(settle);
}

if (wanted("browser")) {
  await front(castle);
  grab("browser");
}

if (wanted("tabs") && kart && orrery) {
  // Each tab has drawn once at the front before the clip, so the clip
  // shows each model as it is, not a tab catching up.
  for (const page of [kart, orrery, castle]) await front(page, 8000);
  await record("tabs", async () => {
    for (const page of [castle, kart, orrery]) {
      await page.bringToFront();
      await page.waitForTimeout(2600);
    }
  });
}

if (wanted("simulate") && orrery) {
  await front(orrery);
  const sim = () => orrery.evaluate(() => window.brickworksSimulate || {});
  await tools(orrery, "simulate", async () => Boolean((await sim()).open));
  let read = {};
  for (let n = 0; n < 240; n++) {
    read = await sim();
    if (read.open && /Mars/.test(read.readout || "")) break;
    await orrery.waitForTimeout(500);
  }
  say(/Mars/.test(read.readout || ""), `Simulate mechanism reads the orrery: ${String(read.readout || "").replace(/\n/g, " | ").slice(0, 400)}`);
  // Closer, so the planets fill the view beside the panel: the wheel over
  // the orrery zooms to the pointer, as a person would. At this window size
  // its middle is drawn at 960, 473 on the page.
  await orrery.mouse.move(960, 473);
  for (let n = 0; n < Number(args.zoom || 2); n++) {
    await orrery.mouse.wheel(0, -240);
    await orrery.waitForTimeout(3000);
  }
  await orrery.mouse.move(W - 4, H - 4);
  await orrery.waitForTimeout(5000);
  grab("simulate");
  // Play is held while the panel weighs the balance over the cycle.
  let playing = false;
  for (let n = 0; n < 4 && !playing; n++) {
    await press(orrery, "simulate_play", 500);
    for (let wait = 0; wait < 10 && !playing; wait++) {
      await orrery.waitForTimeout(500);
      playing = Boolean((await sim()).playing);
    }
  }
  await orrery.mouse.move(W - 4, H - 4);
  say(playing, "Play: the train is turning");
  // In software the page draws the playing orrery a frame every three
  // seconds or so (0.35 a second on 2026-10-13), each a fixed step of the
  // crank on, so a clip in real time is a slide show. Instead the clip is
  // long and slow, and --encode keeps only the frames that differ, at an
  // even rate: the app's own frames, in order. Where the crank was at each
  // is kept beside it (simulate.json), to see the steps are even.
  const turns = [];
  const t1 = Date.now();
  await record("simulate", async () => {
    let last = null;
    while (Date.now() - t1 < Number(args.seconds || 150) * 1000) {
      const now = (await sim()).turns;
      if (now !== last) turns.push({ at: Date.now() - t1, turns: now });
      last = now;
      await orrery.waitForTimeout(250);
    }
  }, { fps: 4 });
  writeFileSync(`${out}/simulate.json`, JSON.stringify(turns));
  const steps = turns.slice(1).map((t, n) => +(t.turns - turns[n].turns).toFixed(3));
  say(turns.length > 10, `while recorded the crank went from ${turns[0]?.turns} to ${turns.at(-1)?.turns} in ${turns.length} drawn steps: ${steps.join(" ")}`);
  await press(orrery, "simulate_play", 1500);
}

let tree = null;
if (wanted("stability")) {
  // Its own tab, on the example --stability names: Tools, Check stability,
  // from the menu opening to the marks on the floor and the margin said.
  const [name, file] = String(args.stability || STABILITY).split(":");
  const page = tree = await tab(await context.newPage(), name, file);
  // The parts column folded too, so the tree has the window's middle and
  // the Tools menu opens over the view rather than beside a cut-off column.
  if (((await state(page)).columns || {}).parts) await press(page, "parts_rail", 3000);
  await front(page, 8000);
  let said = "";
  await record("stability", async () => {
    await page.waitForTimeout(1200);
    // Done once it is weighing (Working has words) or has said something.
    await tools(page, "stability", async () => {
      const now = await state(page);
      return Boolean((now.working || {}).words) || /studs|stands|joint/.test(now.said || "");
    });
    for (let n = 0; n < 120 && !/studs/.test(said); n++) {
      await page.waitForTimeout(500);
      said = (await state(page)).said || "";
    }
    await page.mouse.move(W - 4, H - 4);
    await page.waitForTimeout(4500);
  });
  say(/studs/.test(said), `Check stability on the ${name}: "${said}"`);
  grab("stability");
}

if (wanted("io") && (tree || kart)) {
  // File, Export, with its second line, BrickLink Studio model (.io), lit:
  // E opens Export, Right goes in, Down moves from LDraw to Studio
  // (io_flow's keys). On the tree's tab, or the kart's: on the castle's,
  // which draws a frame a second or so in software, the keys and then the
  // pointer were lost three times and left the File menu with nothing lit.
  const page = tree || kart;
  await front(page);
  await press(page, "menu_file", 2500);
  await page.keyboard.press("E");
  await page.waitForTimeout(1200);
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(2000);
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(3000);
  grab("io");
  await page.keyboard.press("Escape");
  await page.waitForTimeout(1000);
  await page.keyboard.press("Escape");
  await page.waitForTimeout(1500);
}

if (wanted("export3d") && kart) {
  // File, Export, 3D model…: two lines down from LDraw (model3d_flow's
  // keys, which this menu takes on the kart), then the format's list opened
  // by a click, so GLB, glTF, OBJ and STL are all in the picture. At this
  // window size the dialog is in the middle of the view, its list at 798, 441.
  await front(kart);
  await press(kart, "menu_file", 2000);
  await kart.keyboard.press("E");
  await kart.waitForTimeout(800);
  await kart.keyboard.press("ArrowRight");
  await kart.waitForTimeout(1500);
  for (let down = 0; down < 2; down++) {
    await kart.keyboard.press("ArrowDown");
    await kart.waitForTimeout(800);
  }
  await kart.keyboard.press("Enter");
  await kart.waitForTimeout(5000);
  await kart.mouse.click(798, 441);
  await kart.waitForTimeout(3000);
  grab("export3d");
  await kart.keyboard.press("Escape");
  await kart.waitForTimeout(1000);
  await kart.keyboard.press("Escape");
  await kart.waitForTimeout(1500);
}

if (wanted("booklet") && kart) {
  // The toolbar's Instructions opens the booklet in a tab of its own
  // (booklet_flow); the picture is that tab, at its first page of steps.
  await front(kart);
  const opened = context.waitForEvent("page", { timeout: 60000 }).catch(() => null);
  await press(kart, "instructions", 500);
  const booklet = await opened;
  let pages = 0;
  for (let n = 0; booklet && n < 300 && pages === 0; n++) {
    await kart.waitForTimeout(2000);
    pages = await booklet.evaluate(() => document.querySelectorAll("section.page").length).catch(() => 0);
  }
  say(pages > 0, `Instructions opened the kart's booklet in a tab: ${pages} pages`);
  if (booklet && pages > 0) {
    await booklet.bringToFront();
    await booklet.waitForLoadState("load").catch(() => {});
    // The last page of steps, where the kart is nearly whole, its top just
    // under the booklet's own bar (which a plain scrollIntoView put it under).
    const page = await booklet.evaluate(() => {
      const all = document.querySelectorAll("section.page.steps");
      const last = all[all.length - 1];
      if (!last) return 0;
      const bar = document.querySelector(".bar");
      window.scrollTo(0, last.getBoundingClientRect().top + window.scrollY
        - (bar ? bar.getBoundingClientRect().height : 0) - 12);
      return all.length;
    });
    await booklet.waitForTimeout(3000);
    say(page > 0, `the booklet shows its last of ${page} pages of steps`);
    grab("booklet");
    await booklet.close();
  }
}

say(errors.length === 0, `no script errors (${errors.length})`);
for (const e of errors.slice(0, 6)) console.log(`        ${e}`);
writeFileSync(`${out}/page.json`, JSON.stringify(where.page));
await context.close();
rmSync(profile, { recursive: true, force: true });
console.log(problems.length ? `compare_media: ${problems.length} failed` : "compare_media: every scene taken");
process.exit(problems.length ? 1 : 0);

