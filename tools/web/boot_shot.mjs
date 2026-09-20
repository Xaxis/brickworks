// Screenshot the loading screen itself, which the normal check skips past.
//
// The boot panel is only up while the build downloads, so this throttles
// the network hard enough to hold it there and takes the frame mid-load.
//
//   node tools/web/boot_shot.mjs --url=... --out=shots/boot.png [--at=2500]

import { chromium } from "playwright";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));

const browser = await chromium.launch({
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 860 } });

// Throttle so the wall is caught mid-build rather than fully laid.
const client = await page.context().newCDPSession(page);
await client.send("Network.emulateNetworkConditions", {
  offline: false,
  downloadThroughput: Number(args.kbps || 900) * 1024 / 8,
  uploadThroughput: 512 * 1024 / 8,
  latency: 40,
});

await page.goto(args.url, { waitUntil: "domcontentloaded", timeout: 60000 });
await page.waitForSelector("#boot .brick", { timeout: 30000 });
await page.waitForTimeout(Number(args.at || 2500));

const laid = await page.evaluate(() => ({
  laid: document.getElementById("laid")?.textContent,
  total: document.getElementById("total")?.textContent,
  note: document.getElementById("note")?.textContent,
}));
console.log(`boot: ${laid.laid}/${laid.total} bricks — "${laid.note}"`);

await page.screenshot({ path: args.out || "shots/boot.png" });
await browser.close();
