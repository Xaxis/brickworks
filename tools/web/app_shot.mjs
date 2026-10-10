// The landing page's picture of the app, taken from a real deployment.
//
//   node tools/web/app_shot.mjs --url=https://brickworks.diy/app --out=web/shot-app.png
//   BW_BYPASS=… node tools/web/app_shot.mjs --url=<a preview>/app --out=…
//
// Opens the castle the landing page shows, on a clean browser, so the panel
// is what a first visit sees: the key form, and Connect Claude beneath it.
// --model picks another model; --click=connect_claude presses a control by
// name first (the app publishes where they are, see main._tell_page).
//
// Why it exists: the picture at the top of the landing page was taken once,
// by hand, on 19 September, and was still there three weeks later showing a
// toolbar, a panel and a "Sign out" that the app no longer had. A picture
// that can only be retaken by hand is retaken when someone notices.
import { launch } from "./browser.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/app.png";
const model = args.model || "res://models/castle.ldr";

const browser = await launch();
// 1600 by 900 is the size the landing page lays it out at.
const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
const query = [`model=${model}`];
if (process.env.BW_BYPASS) {
  query.push(`x-vercel-protection-bypass=${process.env.BW_BYPASS}`,
    "x-vercel-set-bypass-cookie=true");
}
await page.goto(`${url}${url.includes("?") ? "&" : "?"}${query.join("&")}`,
  { waitUntil: "domcontentloaded", timeout: 120000 });

// The app is up when it has said where its controls are.
const until = Date.now() + 240000;
while (!(await page.evaluate(() => Boolean(window.brickworksControls)))) {
  if (Date.now() > until) throw new Error("the app never came up");
  await page.waitForTimeout(1000);
}
for (const name of [].concat(args.click || [])) {
  const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
  if (!where) throw new Error(`the app is not showing "${name}"`);
  await page.mouse.click(where.x, where.y);
}
// Long enough for a big model to finish loading and the camera to settle
// on it, which nothing on the page announces.
await page.waitForTimeout(Number(args.settle || 30000));
await page.screenshot({ path: out, timeout: 60000 });
await browser.close();
console.log(`wrote ${out}`);
