import { chromium } from "playwright";
import { resolve } from "node:path";
const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1280, height: 900 }, colorScheme: "dark" });
await p.goto("file://" + resolve("web/index.html"), { waitUntil: "load" });
await p.waitForTimeout(700);
await p.screenshot({ path: "shots/landing_dark.png", fullPage: true });
await b.close();
console.log("ok");
