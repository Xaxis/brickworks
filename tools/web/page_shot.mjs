// Screenshot a local HTML page, for looking at the landing page without
// deploying it first.
//
//   node tools/web/page_shot.mjs --file=web/index.html --out=shots/landing.png
import { chromium } from "playwright";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: Number(args.width || 1280), height: Number(args.height || 900) },
});
await page.goto("file://" + resolve(args.file), { waitUntil: "load" });
await page.waitForTimeout(700);
await page.screenshot({ path: args.out, fullPage: args.full !== undefined });
await browser.close();
console.log(`wrote ${args.out}`);
