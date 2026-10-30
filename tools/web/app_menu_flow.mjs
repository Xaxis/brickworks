// The app's own menu in a browser: the mark at the far left of the menu
// bar opens About Brickworks, Send feedback, Find a command, the website,
// the docs, Account and Back to brickworks.diy, and Back leaves the app for
// the site's home page in the same tab. The web app had no way back to the site but the browser's own
// Back (brand373, 2026-10-29).
//
//   node tools/web/app_menu_flow.mjs --url=<preview>/app --bypass=… [--out=shots/app_menu_web]
//   node tools/web/app_menu_flow.mjs --url=http://127.0.0.1:8761/index.html
//
// At 1280 x 800, and at a phone's width with a mouse (390 x 844, the
// desktop's layout at 720 units across): the mark is the left-most control
// of the bar's row (window.brickworksControls.app_menu), drawn in its
// yellow, red and blue; a click opens its menu with exactly its rows
// (window.brickworksState.app_menu); Down and Return on the first open
// About Brickworks; then Back to brickworks.diy, the last row, puts the
// page at the site's own address, its header's mark showing. Pictures in
// --out; it fails if a step does not happen or a script error is thrown.
import { launch, START_MS } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/app_menu_web";
const first = args.bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${args.bypass}&x-vercel-set-bypass-cookie=true`
  : url;
mkdirSync(out, { recursive: true });

const ROWS = ["About Brickworks", "Send feedback…", "-", "Find a command…", "-", "Brickworks website",
  "Documentation", "-", "Account…", "-", "Back to brickworks.diy"];

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}

async function until(page, test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await page.waitForTimeout(500);
  }
  return false;
}

const browser = await launch();
for (const [width, height] of [[1280, 800], [390, 844]]) {
  const size = `${width}x${height}`;
  console.log(`\nat ${size}`);
  const page = await browser.newPage({ viewport: { width, height } });
  const thrown = [];
  page.on("pageerror", (error) => thrown.push(String(error)));
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  const controls = () => page.evaluate(() => window.brickworksControls || {});
  const state = () => page.evaluate(() => window.brickworksState || {});
  if (!check("the app shows the mark", await until(page, async () => Boolean((await controls()).app_menu),
    START_MS / 1000))) {
    await page.screenshot({ path: `${out}/${size}_no_mark.png` }).catch(() => {});
    await page.close();
    continue;
  }
  await page.waitForTimeout(3000);
  const where = await controls();
  const mark = where.app_menu;
  const row = Object.entries(where).filter(([, at]) => Math.abs(at.y - mark.y) < 8);
  const leftMost = row.every(([name, at]) => name === "app_menu" || at.x > mark.x);
  check(`...at the top left (${mark.x - mark.w / 2}, ${mark.y - mark.h / 2}; ${mark.w} x ${mark.h}), `
    + `left of everything in its row: ${row.map(([name]) => name).join(", ")}`,
    mark.x - mark.w / 2 < 24 && mark.y - mark.h / 2 < 24 && leftMost);
  // Its colours, read off a picture of its left end, where the mark is: the
  // page's own picture, as a person sees it (the canvas read back between
  // frames can be blank, the app drawing only what changes).
  const square = { x: Math.max(0, mark.x - mark.w / 2), y: Math.max(0, mark.y - mark.h / 2), width: mark.h, height: mark.h };
  const shot = (await page.screenshot({ clip: square })).toString("base64");
  const colours = await page.evaluate(async (png) => {
    const bytes = Uint8Array.from(atob(png), (c) => c.charCodeAt(0));
    const picture = await createImageBitmap(new Blob([bytes], { type: "image/png" }));
    const canvas = new OffscreenCanvas(picture.width, picture.height);
    const ctx = canvas.getContext("2d");
    ctx.drawImage(picture, 0, 0);
    const { data } = ctx.getImageData(0, 0, picture.width, picture.height);
    const near = (i, [r, g, b]) => Math.abs(data[i] - r) + Math.abs(data[i + 1] - g) + Math.abs(data[i + 2] - b) < 60;
    const found = { yellow: 0, red: 0, blue: 0 };
    for (let i = 0; i < data.length; i += 4) {
      if (near(i, [0xf2, 0xcd, 0x37])) found.yellow += 1;
      if (near(i, [0xd0, 0x33, 0x2f])) found.red += 1;
      if (near(i, [0x2a, 0x6f, 0xc4])) found.blue += 1;
    }
    return found;
  }, shot);
  // Some of each: at a phone's width and one pixel to the point the mark is
  // a few pixels across, its edges blended.
  check(`...drawn in the mark's colours: ${JSON.stringify(colours)} pixels`,
    colours.yellow > 0 && colours.red > 0 && colours.blue > 0);
  await page.screenshot({ path: `${out}/${size}_bar.png`, clip: { x: 0, y: 0, width, height: Math.min(height, 90) } });

  await page.mouse.click(mark.x, mark.y);
  check("a click opens its menu", await until(page, async () => ((await state()).app_menu || []).length > 0, 20));
  const rows = (await state()).app_menu || [];
  check(`...its rows: ${rows.join(", ")}`, JSON.stringify(rows) === JSON.stringify(ROWS));
  await page.screenshot({ path: `${out}/${size}_menu.png` });
  await page.keyboard.press("ArrowDown");
  await page.waitForTimeout(400);
  await page.keyboard.press("Enter");
  check("Down and Return on its first row open About Brickworks",
    await until(page, async () => Boolean((await controls()).about_ok), 20));
  await page.screenshot({ path: `${out}/${size}_about.png` });
  const ok = (await controls()).about_ok;
  if (ok) await page.mouse.click(ok.x, ok.y);
  await until(page, async () => !(await controls()).about_ok, 10);

  // Nothing waiting to be written to the browser's storage, or the page
  // rightly asks before it is left (src/boot/shell.html).
  await until(page, async () => (await page.evaluate(() => (window.brickworksUnstored ? window.brickworksUnstored() : 0))) === 0, 60);
  await page.mouse.click(mark.x, mark.y);
  await until(page, async () => ((await state()).app_menu || []).length > 0, 20);
  const back = ROWS.filter((r) => r !== "-").indexOf("Back to brickworks.diy") + 1;
  for (let n = 0; n < back; n++) {
    await page.keyboard.press("ArrowDown");
    await page.waitForTimeout(250);
  }
  const app = new URL(page.url());
  await page.keyboard.press("Enter");
  const left = await page.waitForURL((at) => at.pathname === "/" && at.origin === app.origin, { timeout: 60000 })
    .then(() => true, () => false);
  check(`Back to brickworks.diy leaves the app for the site's home page, in this tab (${page.url().split("?")[0]})`, left);
  const header = left && await page.locator(".site-head .mark .chip").first().isVisible({ timeout: 30000 }).catch(() => false);
  check("...its header showing the mark", Boolean(header));
  await page.screenshot({ path: `${out}/${size}_site.png`, clip: { x: 0, y: 0, width, height: Math.min(height, 200) } });
  check(`no script error thrown${thrown.length ? ": " + thrown.slice(0, 3).join(" | ") : ""}`, thrown.length === 0);
  await page.close();
}
await browser.close();
console.log(failed ? `\napp menu flow: ${failed} checks failed` : "\napp menu flow: all checks passed");
process.exit(failed ? 1 : 0);
