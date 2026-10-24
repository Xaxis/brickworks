// Build it, on a phone and a tablet: a shared model's link opened as the
// step player, stepped through with a finger, and come back to after a
// reload, in real Chromium with touch.
//
//   python3 tools/web/serve.py build/web 8761 --parts assets/generated/parts --delay 0 \
//       --share models/house.ldr &
//   node tools/web/build_flow.mjs --url=http://127.0.0.1:8761 --out=shots/build_web
//   node tools/web/build_flow.mjs --url=<preview> --id=<a real link's id> --bypass=…
//
// serve.py --share plays the link (/api/share?id= and /m/<id>), so no account
// and no database row are needed; against a deployment, --id names a link
// that is published there. At each size (a phone, 390 x 844 at three device
// pixels to the point, and a tablet, 820 x 1180 at two, both touch screens):
//
//   1. /m/<id> goes on to the viewer, which opens the model with Build it on
//      its bar, inside the page.
//   2. Build it, tapped: the step player over the whole window, on the
//      finished model, "Ready to build", Start.
//   3. Next tapped three times: "Step 3 of N"; what steps 1 and 2 built is
//      drawn faded and step 3's parts are not; the parts are along the
//      bottom with their pictures drawn; Next and Back a fingertip tall
//      and every control inside the page. With the CPU slowed four times,
//      as a mid-range phone's is, the frames' own work while the pages turn
//      (brickworksState.slow, the app's own work and not the software
//      drawing) is said beside the viewer's own timeline stepped the same
//      way, and a page may cost no more than twice a timeline step. The aim
//      is 100 ms, which neither meets on this box yet.
//   4. A swipe across the parts to the left is Next, to the right Back; a
//      finger drawn across the model turns it.
//   5. The page is kept for the link in localStorage; after a reload the
//      link opens straight on step 3.
//
// Pictures in --out: <size>_1_viewer.png, _2_cover.png, _3_step3.png,
// _4_turned.png, _5_reloaded.png.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:8761").replace(/\/$/, "");
const id = String(args.id || "Bu1ldFl0w1");
const out = args.out || "shots/build_web";
const bypass = args.bypass || "";
const SIZES = {
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3 },
  tablet: { viewport: { width: 820, height: 1180 }, deviceScaleFactor: 2 },
};
const wanted = String(args.sizes || "phone,tablet").split(",");
mkdirSync(out, { recursive: true });

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const share = (page) => page.evaluate(() => window.brickworksShare || {});
const build = async (page) => (await share(page)).build || {};
const controls = (page) => page.evaluate(() => window.brickworksControls || {});

async function until(page, test, what, seconds = 300, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}

// A finger on a control, where the app says it is.
async function tap(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const at = (await controls(page))[name];
    if (at) {
      await page.touchscreen.tap(at.x, at.y);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

// A finger drawn from one point to another, as the browser sends it.
async function drag(cdp, from, to, steps = 10) {
  const point = (p) => [{ x: p.x, y: p.y, id: 1, radiusX: 4, radiusY: 4, force: 1 }];
  await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: point(from) });
  for (let n = 1; n <= steps; n += 1) {
    const at = { x: from.x + (to.x - from.x) * n / steps, y: from.y + (to.y - from.y) * n / steps };
    await cdp.send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: point(at) });
    await new Promise((done) => setTimeout(done, 30));
  }
  await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
}

async function pageIs(page, number, what, seconds = 60) {
  return until(page, (n) => ((window.brickworksShare || {}).build || {}).page === n, what, seconds, number)
    .then(() => true).catch(() => false);
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 120000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

const browser = await launch({ signedOut: true });
try {
  for (const size of wanted) {
    const shape = SIZES[size];
    if (!shape) throw new Error(`no size ${size}`);
    const { width, height } = shape.viewport;
    console.log(`\n${size}, ${width} x ${height} at ${shape.deviceScaleFactor}x, touch`);
    const context = await browser.newContext({ ...shape, isMobile: true, hasTouch: true,
      extraHTTPHeaders: bypass ? { "x-vercel-protection-bypass": bypass } : {} });
    const page = await context.newPage();
    page.on("pageerror", (e) => errors.push(`${size}: ${String(e).slice(0, 200)}`));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error/.test(m.text())) errors.push(`${size}: ${m.text().slice(0, 220)}`);
    });
    const cdp = await context.newCDPSession(page);

    // 1. The link, as somebody follows it.
    await page.goto(`${site}/m/${id}`, { waitUntil: "domcontentloaded", timeout: 120000 });
    // On a deployment the link is the model's own page, whose View in 3D (its
    // picture) opens the viewer, Build it the step player at step 1 (the
    // local relay goes straight on), as play found.
    const cta = await page.$('.model-page a.picture[href^="/app?view="]').catch(() => null);
    if (cta) {
      await Promise.all([page.waitForURL(/\/app\?view=/, { timeout: 180000 }), cta.tap()]);
    }
    await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready",
      "the shared model opened", 600);
    const bricks = (await page.evaluate(() => window.brickworksState)).bricks;
    check(`the link opens the viewer, ${bricks} parts standing`, bricks > 0);
    const bar = await controls(page);
    check("Build it is on its bar, inside the page", Boolean(bar.view_build)
      && bar.view_build.x >= 0 && bar.view_build.x <= width && bar.view_build.y <= height);
    await shot(page, `${size}_1_viewer.png`);

    // The viewer's own timeline stepped the same way first, on the same
    // slowed CPU: what a step already cost here before Build it, to read
    // the step player's frames against.
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
    const before = await page.evaluate(() => window.brickworksState.now);
    await tap(page, "steps_start");
    await page.waitForTimeout(1500);
    for (let n = 0; n < 3; n += 1) {
      await tap(page, "steps_next");
      await page.waitForTimeout(1500);
    }
    await page.waitForTimeout(1500);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    const timeline = (await page.evaluate(() => window.brickworksState.slow || []))
      .filter((frame) => frame[0] >= before);
    const timelineWorst = timeline.reduce((most, frame) => Math.max(most, frame[1]), 0);
    console.log(`  --    the timeline's Next, three times at a phone's speed: worst frame ${timelineWorst} ms `
      + `(over 50: ${timeline.map((frame) => frame[1]).join(", ") || "none"})`);
    await tap(page, "steps_end");
    await page.waitForTimeout(1000);

    // 2. Build it.
    await tap(page, "view_build");
    await until(page, () => ((window.brickworksShare || {}).build || {}).open === true, "the step player", 60);
    await page.waitForTimeout(1500);
    let now = await build(page);
    check(`Build it opens the step player on the finished model: "${now.caption}", ${now.next} (${now.shown} parts)`,
      now.page === 0 && now.caption === "Ready to build" && now.next === "Start" && now.shown === bricks);
    await shot(page, `${size}_2_cover.png`);

    // 3. Next three times, on a CPU slowed as a phone's is.
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
    const since = await page.evaluate(() => window.brickworksState.now);
    for (let n = 1; n <= 3; n += 1) {
      await tap(page, "build_next");
      await pageIs(page, n, `page ${n}`);
    }
    await page.waitForTimeout(2500);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    now = await build(page);
    check(`Next three times: "${now.caption}"`, now.page === 3 && /^Step 3 of \d+/.test(now.caption));
    check(`steps 1 and 2 drawn faded (${now.faded} parts), step 3's ${now.fresh} new parts not, nothing after (${now.shown} shown)`,
      now.faded > 0 && now.fresh > 0 && now.shown === now.faded + now.fresh);
    await until(page, () => {
      const b = (window.brickworksShare || {}).build || {};
      return b.lots > 0 && b.pictures === b.lots;
    }, "the parts' pictures", 120).catch(() => null);
    now = await build(page);
    check(`the step's parts are along the bottom, ${now.pictures} of ${now.lots} pictures drawn (${now.told})`,
      now.lots > 0 && now.pictures === now.lots);
    const sizes = now.points || {};
    check(`Next and Back a fingertip tall (${JSON.stringify(sizes)} points), "${now.caption}" at ${now.caption_points} points`,
      (sizes.build_next || [0, 0])[1] >= 46 && (sizes.build_back || [0, 0])[1] >= 46 && now.caption_points >= 20);
    const placed = await controls(page);
    const names = ["build_next", "build_back", "build_close", "build_parts"];
    const outside = names.filter((n) => !placed[n] || placed[n].x < 0 || placed[n].x > width
      || placed[n].y < 0 || placed[n].y > height);
    check(`every control of the step player is inside the page (${outside.join(", ") || "all in"})`,
      outside.length === 0);
    const slow = (await page.evaluate(() => window.brickworksState.slow || []))
      .filter((frame) => frame[0] >= since);
    const told = await page.evaluate(() => window.brickworksState.told_most_ms);
    // [when, ms of the app's own work, ms waiting on the graphics card for
    // a picture read back, what it was doing].
    //
    // The aim is no frame over 100 ms on a mid-range phone. On this shared
    // box, slowed four times, the viewer's own timeline already takes
    // 150-170 ms a step (2026-10-13), so the frames are said, against
    // that, and what is checked is that a page costs no more than twice a
    // timeline step: the target itself is not met yet, by either.
    const worst = slow.reduce((most, frame) => Math.max(most, frame[1]), 0);
    console.log(`  --    at a phone's speed, turning three pages: worst frame ${worst} ms (aim: 100); `
      + `over 50: ${slow.map((frame) => `${frame[1]}+${frame[2]} waiting`).join(", ") || "none"}; `
      + `a page turned in ${now.turn_most_ms} ms at most: ${JSON.stringify(now.turn_most)}; `
      + `telling the page what is on screen took up to ${told} ms`);
    check(`a page turns in no more than twice the time a timeline step takes (${worst} ms against ${timelineWorst} ms)`,
      worst <= Math.max(100, 2 * timelineWorst));
    await shot(page, `${size}_3_step3.png`);

    // 4. Swipes and a finger on the model.
    const strip = placed.build_parts;
    await drag(cdp, { x: strip.x + 90, y: strip.y }, { x: strip.x - 90, y: strip.y });
    check("a swipe to the left across the parts is Next", await pageIs(page, 4, "page 4", 20));
    await drag(cdp, { x: strip.x - 90, y: strip.y }, { x: strip.x + 90, y: strip.y });
    check("to the right is Back", await pageIs(page, 3, "page 3", 20));
    const yaw = (await page.evaluate(() => window.brickworksState.view)).yaw;
    const top = placed.build_close.y;
    const middle = { x: width / 2, y: (top + strip.y) / 2 };
    await drag(cdp, { x: middle.x - 80, y: middle.y }, { x: middle.x + 80, y: middle.y });
    await page.waitForTimeout(1500);
    const turned = (await page.evaluate(() => window.brickworksState.view)).yaw;
    now = await build(page);
    check(`a finger across the model turns it (${yaw.toFixed(2)} to ${turned.toFixed(2)}) and the page stays (${now.page})`,
      Math.abs(turned - yaw) > 0.1 && now.page === 3);
    await shot(page, `${size}_4_turned.png`);

    // 5. Kept, and come back to.
    const kept = await page.evaluate((key) => localStorage.getItem(key), `brickworks.build.${id}`);
    check(`the page is kept for the link (${kept})`, kept && JSON.parse(kept).page === 3
      && JSON.parse(kept).building === true);
    check(`the address is the link (${page.url()})`, page.url().endsWith(`/m/${id}`));
    await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
    await until(page, () => ((window.brickworksShare || {}).build || {}).open === true,
      "the step player after a reload", 600);
    await pageIs(page, 3, "page 3 after the reload", 60);
    await page.waitForTimeout(2000);
    now = await build(page);
    check(`after a reload it is still on step 3: "${now.caption}", ${now.faded} faded`,
      now.page === 3 && /^Step 3 of \d+/.test(now.caption) && now.faded > 0);
    await shot(page, `${size}_5_reloaded.png`);
    await context.close();
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble.message || trouble).split("\n")[0]}`, false);
} finally {
  await browser.close();
}
check(`no script errors (${errors.length})`, errors.length === 0);
for (const error of errors.slice(0, 8)) console.log(`        ${error}`);
console.log(failed ? `\n${failed} FAILED` : "\nbuild it works on a phone and a tablet, and comes back where it was left");
process.exit(failed ? 1 : 0);
