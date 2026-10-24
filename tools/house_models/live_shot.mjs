// Signed-out screenshots of live pages, at 1280 and 390 wide, full length,
// every lazy card picture in.
//
//   ~/.claude/claude-core/bin/heavy node tools/house_models/live_shot.mjs OUTDIR URL=name ...
//
// Writes OUTDIR/<name>-1280.png and -390.png. The page is walked down half a
// screen at a time before the picture, since a full-page shot does not scroll
// and the gallery's cards below the first screen came out as empty frames.
// Used by seed211 (2026-10-24) for the gallery and the new models' pages.
import { launch, allPictures } from "../web/browser.mjs";

const [out, ...pages] = process.argv.slice(2);
if (!out || !pages.length) {
  console.error("live_shot: OUTDIR URL=name ...");
  process.exit(2);
}
const browser = await launch({ signedOut: true });
for (const spec of pages) {
  const at = spec.lastIndexOf("=");
  const [url, name] = [spec.slice(0, at), spec.slice(at + 1)];
  for (const [w, h] of [[1280, 900], [390, 844]]) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, colorScheme: "light" });
    await page.goto(url, { waitUntil: "load", timeout: 120000 });
    for (let y = 0; y < await page.evaluate(() => document.body.scrollHeight); y += h / 2) {
      await page.evaluate((to) => window.scrollTo(0, to), y);
      await page.waitForTimeout(250);
    }
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForFunction(() => [...document.images].every((i) => i.complete), null, { timeout: 60000 })
      .catch(() => {});
    await allPictures(page);
    await page.waitForTimeout(1500);
    const path = `${out}/${name}-${w}.png`;
    await page.screenshot({ path, fullPage: true, timeout: 120000 });
    await page.close();
    console.log(`wrote ${path}`);
  }
}
await browser.close();
