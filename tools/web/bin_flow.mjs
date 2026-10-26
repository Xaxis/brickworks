// The parts bin's two additions in a real browser: the Techniques tab, and a
// part found from a photo by Brickognize.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 9063 --parts assets/generated/parts --delay 0 &
//   node tools/web/bin_flow.mjs --url=http://127.0.0.1:9063/ --out=shots/bin_web
//   node tools/web/bin_flow.mjs --url=<preview>/app --bypass=… --out=DIR
//
// At 1280 x 860, by the mouse:
//   1. Techniques, beside Recent and Favourites: its rows come, "window in a
//      wall" among them.
//   2. That row clicked: the construction in hand, whole (brickworksState
//      carrying); a click on the baseplate puts it down, 17 more parts; one
//      Ctrl-Z takes all 17 back.
//   3. The camera in the search field: first it says the photo goes to
//      Brickognize, a third party; "Choose a photo" brings up the page's own
//      file chooser; tests/fixtures/photos/3039.jpg, a blue slope (drawn by
//      the app's own renderer, src/dev/photo_search_probe.gd), goes to
//      Brickognize, live, and Slope 45 2 x 2, 3039, comes first in the bin,
//      in blue, the photo's colour, not the red in hand (walk256 S3).
//   4. 3008, 3001, 3039 and 3069b typed: the part itself is the first tile, its
//      prints and stickers folded under it behind a count (search242); the
//      count pressed opens them after it, and pressed again folds them.
// At 390 x 844, by a finger, as phone_flow.mjs has a phone: the parts sheet,
// Techniques there, the folding, and the camera again with the same photo.
//
// Brickognize answers from the internet, so this needs it up; its failures
// are proved with it stood in for (src/dev/photo_search_stub_probe.gd).
// Pictures of each step go to --out, at both sizes.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:9063/");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(String(args.out || "shots/bin_web"));
const photo = resolve("tests/fixtures/photos/3039.jpg");
mkdirSync(out, { recursive: true });

let failures = 0;
const t0 = Date.now();
const check = (line, passed) => {
  console.log(`  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!passed) failures += 1;
  return passed;
};

const browser = await launch();

for (const phone of [false, true]) {
  const width = phone ? 390 : 1280;
  const height = phone ? 844 : 860;
  console.log(`\n${width} x ${height}${phone ? " at 3x, by a finger" : ", by the mouse"}`);
  const context = await browser.newContext(phone
    ? { viewport: { width, height }, deviceScaleFactor: 3, isMobile: true, hasTouch: true }
    : { viewport: { width, height } });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  });
  const choosers = [];
  page.on("filechooser", (chooser) => choosers.push(chooser));
  const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
  const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
  const until = async (test, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const s = await state();
      if (test(s)) return s;
      await page.waitForTimeout(250);
    }
    return state();
  };
  const where = async (name, seconds = 30) => {
    for (let n = 0; n < seconds * 4; n++) {
      const at = (await controls())[name];
      if (at) return at;
      await page.waitForTimeout(250);
    }
    return null;
  };
  const hit = async (at) => {
    if (phone) await page.touchscreen.tap(at.x, at.y);
    else await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(600);
  };
  const press = async (name, seconds = 30) => {
    const at = await where(name, seconds);
    if (!check(`"${name}" is on the screen`, Boolean(at))) return false;
    await hit(at);
    return true;
  };
  const picture = (what) => page.screenshot({ path: `${out}/${width}_${what}.png`, timeout: 120000 })
    .catch((e) => console.log(`  --    no picture ${what}: ${String(e).split("\n")[0]}`));

  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  check("the app came up", Boolean(await where(phone ? "phone_parts" : "open", 400)));
  await page.waitForTimeout(Number(args.load || 8000));
  let centre = { x: width / 2, y: height / 2 };
  if (!phone) {
    // A new model, the sample's parts out of the way (placing_flow.mjs).
    await press("new");
    for (let n = 0; n < 10 && (await state()).bricks > 0; n++) {
      await page.keyboard.press("Enter");
      await page.waitForTimeout(1500);
    }
    await page.evaluate(() => { window.brickworksAskLayout = true; });
    await page.waitForTimeout(1500);
    const view = ((await page.evaluate(() => window.brickworksLayout)) || {}).view;
    if (view) centre = { x: view[0] + view[2] / 2, y: view[1] + view[3] / 2 };
  }
  if (phone) await press("phone_parts");

  // 1. Techniques.
  await press("techniques", 60);
  const row = await where("technique window in a wall", 60);
  check("Techniques lists its constructions, \"window in a wall\" among them", Boolean(row));
  // Their pictures are drawn in a frame or two each; a software renderer
  // takes a while over the first screenful.
  await page.waitForTimeout(phone ? 15000 : 10000);
  await picture("1_techniques");

  // 2. Held whole, put down, and undone: found by typing, as a person finds
  // one of ninety (the search narrows the Techniques), so its row is in sight.
  if (!phone && row) {
    const before = (await state()).bricks;
    await press("part search");
    await page.keyboard.type("window in a wall", { delay: 40 });
    await page.waitForTimeout(2500);
    const narrowed = await where("technique window in a wall", 30);
    check("typing narrows them to the window", Boolean(narrowed)
      && !(await controls())["technique round tower"]);
    await page.waitForTimeout(4000);
    await hit(narrowed || row);
    const held = await until((s) => s.carrying === true, 60);
    check("choosing it holds it whole", held.carrying === true);
    const spot = centre;
    for (let n = 0; n < 6; n++) {
      await page.mouse.move(spot.x + n * 3, spot.y, { steps: 2 });
      await page.waitForTimeout(400);
    }
    await page.waitForTimeout(2000);
    await picture("2_held");
    await page.mouse.click(spot.x + 15, spot.y);
    const down = await until((s) => s.bricks === before + 17, 60);
    check(`a click puts it down: ${down.bricks - before} parts more (17)`, down.bricks === before + 17);
    await page.waitForTimeout(3000);
    await picture("3_down");
    await page.keyboard.press("Control+z");
    const undone = await until((s) => s.bricks === before, 30);
    check(`one Ctrl-Z takes it all back (${undone.bricks} of ${before})`, undone.bricks === before);
  }

  // 4. Prints and stickers folded under their part, opened by its count.
  await press("all parts", 30);
  for (const number of ["3008", "3001", "3039", "3069b"]) {
    const box = await where("part search");
    if (!box) break;
    await hit(box);
    await page.keyboard.press("Control+a");
    await page.waitForTimeout(150);
    await page.keyboard.type(number, { delay: 40 });
    const s = await until((now) => (now.found || [])[0] === number, 30);
    const found = s.found || [];
    const fold = await where("first fold", 10);
    check(`${number}: the part itself leads, its prints folded behind a count (${found.slice(0, 4).join(", ")})`,
      found[0] === number && Boolean(fold) && !found.slice(1).some((id) => id.startsWith(number) && /[pd]/.test(id.slice(number.length))));
    await page.waitForTimeout(phone ? 6000 : 3000);
    await picture(`6_${number}_folded`);
    if (!fold) continue;
    await hit(fold);
    const opened = await until((now) => (now.found || []).slice(1).some((id) => id.startsWith(number) && /[pd]/.test(id.slice(number.length))), 20);
    check(`${number}: the count opens them after it (${(opened.found || []).slice(0, 4).join(", ")})`,
      (opened.found || [])[0] === number && (opened.found || []).slice(1).some((id) => id.startsWith(number)));
    await page.waitForTimeout(phone ? 6000 : 3000);
    await picture(`7_${number}_open`);
    const again = await where("first fold", 10);
    if (again) await hit(again);
    const closed = await until((now) => !(now.found || []).slice(1).some((id) => id.startsWith(number) && /[pd]/.test(id.slice(number.length))), 20);
    check(`${number}: and folds them again`, (closed.found || [])[0] === number);
  }

  // 3. A part from a photo.
  if (phone) {
    await press("phone_parts");
  }
  await press("photo search");
  const told = await where("photo choose", 30);
  check("the camera first says where the photo goes, and asks for one", Boolean(told));
  await page.waitForTimeout(1500);
  await picture("4_told");
  if (told) {
    choosers.length = 0;
    await hit(told);
    for (let n = 0; n < 40 && choosers.length === 0; n++) await page.waitForTimeout(250);
    if (check("\"Choose a photo\" brings up the page's file chooser", choosers.length > 0)) {
      const held = (await state()).colour;
      await choosers.shift().setFiles(photo);
      const s = await until((now) => (now.found || [])[0] === "3039", 90);
      check(`Brickognize names it, and Slope 45 2 x 2 comes first (${(s.found || []).slice(0, 3).join(", ")})`,
        (s.found || [])[0] === "3039");
      const blue = await until((now) => now.colour === 1, 10);
      check(`in the photo's colour, blue, not the colour in hand (${held} then ${blue.colour})`,
        blue.colour === 1 && held !== 1);
      await page.waitForTimeout(phone ? 8000 : 5000);
      await picture("5_found");
    }
  }
  check(`no script error reached the console${errors.length ? `: ${errors.slice(0, 2).join(" | ")}` : ""}`,
    errors.length === 0);
  await context.close();
}

await browser.close();
console.log(failures === 0
  ? "\nbin: Techniques held whole and put down, and a photo's part found, on a desktop and a phone"
  : `\nbin: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
