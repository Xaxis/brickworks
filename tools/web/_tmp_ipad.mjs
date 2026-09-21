import { chromium } from "playwright";

const url = process.argv[2] || "https://brickworks.diy";
const W = Number(process.argv[3] || 1366);
const H = Number(process.argv[4] || 1024);
const out = process.argv[5] || "/private/tmp/claude-501/-Users-wilneeley-Projects-lego-emulator/74b3e6cf-d7f3-4f3b-a3f5-adf7aa464ba6/scratchpad/ipad.png";

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: W, height: H },
  deviceScaleFactor: 2,
});
await page.goto(url, { waitUntil: "load", timeout: 120000 });
await page.waitForTimeout(45000);
const info = await page.evaluate(() => {
  const c = document.querySelector("canvas");
  return {
    innerWidth: window.innerWidth,
    innerHeight: window.innerHeight,
    dpr: window.devicePixelRatio,
    canvasBackingW: c ? c.width : null,
    canvasBackingH: c ? c.height : null,
    canvasCssW: c ? c.getBoundingClientRect().width : null,
  };
});
console.log(JSON.stringify(info, null, 2));
await page.screenshot({ path: out });
console.log("shot ->", out);
await browser.close();
