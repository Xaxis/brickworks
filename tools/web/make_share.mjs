// Draw the picture a shared brickworks.diy link shows.
//
//   node tools/web/make_share.mjs
//
// Built from HTML rather than drawn by hand, so the type is the type
// the site uses and changing the tagline is changing one string. 1200 by
// 630 is what every card reader crops to; anything else gets trimmed
// somewhere unpredictable.
import { chromium } from "playwright";
import { resolve, dirname } from "node:path";
import { unlinkSync } from "node:fs";

const root = resolve(dirname(new URL(import.meta.url).pathname), "../..");

const page_html = `<!doctype html>
<meta charset="utf-8">
<style>
  @import url("https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap");
  * { box-sizing: border-box; margin: 0; }
  body {
    width: 1200px; height: 630px; display: flex; overflow: hidden;
    background: #11151b; color: #eef1f5;
    font-family: Inter, ui-sans-serif, -apple-system, sans-serif;
  }
  .words { flex: 1; padding: 66px 0 66px 72px; display: flex;
           flex-direction: column; justify-content: center; }
  .mark { display: flex; align-items: center; gap: 15px; margin-bottom: 30px; }
  .mark img { width: 54px; height: 54px; border-radius: 12px; }
  .mark b { font-size: 34px; font-weight: 800; letter-spacing: -0.02em; }
  h1 { font-size: 56px; line-height: 1.08; font-weight: 800;
       letter-spacing: -0.033em; max-width: 13ch; }
  p { margin-top: 22px; font-size: 22px; line-height: 1.45;
      color: #a9b2bf; max-width: 26ch; }
  .url { margin-top: 34px; font-size: 20px; font-weight: 600; color: #f2cd37; }
  /* The render bleeds off the right edge rather than sitting in a box:
     a card is cropped differently everywhere, and an image that runs
     out of frame survives that where a centred one does not. */
  .shot { width: 560px; position: relative; overflow: hidden; }
  /* Covering, not contained. Sized to the width it would need to fill
     the height, so the render bleeds to every edge of its side —
     letterboxing it left dark bands above and below that read as a
     mistake rather than as a border. */
  .shot img { position: absolute; top: 50%; left: 50%;
              transform: translate(-50%, -50%);
              height: 630px; width: auto; max-width: none; }
  .fade { position: absolute; inset: 0;
          background: linear-gradient(90deg, #11151b 0%, rgba(17,21,27,0) 38%); }
</style>
<div class="words">
  <div class="mark"><img src="favicon-192.png"><b>Brickworks</b></div>
  <h1>Every brick, at the size it really is.</h1>
  <p>28,319 parts at true dimensions, real connection rules, and a design
     assistant that only hands you models which hold together.</p>
  <div class="url">brickworks.diy</div>
</div>
<div class="shot"><img src="_og_model.png"><div class="fade"></div></div>`;

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 1200, height: 630 },
  deviceScaleFactor: 1,
});
await page.goto("file://" + resolve(root, "web/index.html"));
await page.setContent(page_html, { waitUntil: "networkidle" });
await page.waitForTimeout(600);
await page.screenshot({ path: resolve(root, "web/share.png") });
await browser.close();
console.log("  web/share.png  1200x630");
