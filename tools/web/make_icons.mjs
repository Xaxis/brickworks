// Render web/icon.svg to the sizes everything wants.
//
//   node tools/web/make_icons.mjs
//
// One source, many sizes, because a favicon set assembled by hand goes
// out of step the first time the mark changes — and the one that goes
// stale is always the one nobody looks at.
//
// Playwright rather than a rasteriser, because it is already here for
// the deploy check and it renders the SVG with the same engine the tab
// will.
import { chromium } from "playwright";
import { readFileSync, mkdirSync } from "node:fs";
import { resolve, dirname } from "node:path";

const root = resolve(dirname(new URL(import.meta.url).pathname), "../..");
const svg = readFileSync(resolve(root, "web/icon.svg"), "utf8");

const WANTED = [
  ["web/favicon-32.png", 32],
  ["web/favicon-180.png", 180],
  ["web/favicon-192.png", 192],
  ["web/favicon-512.png", 512],
  // Godot wants a square icon for the window and the web shell; 128 is
  // what its own default ships at.
  ["assets/icon.png", 128],
];

const browser = await chromium.launch();
for (const [where, size] of WANTED) {
  const page = await browser.newPage({
    viewport: { width: size, height: size },
    deviceScaleFactor: 1,
  });
  await page.setContent(
    `<!doctype html><style>
       html,body{margin:0;padding:0;background:transparent}
       svg{display:block;width:${size}px;height:${size}px}
     </style>${svg}`,
    { waitUntil: "load" },
  );
  const out = resolve(root, where);
  mkdirSync(dirname(out), { recursive: true });
  await page.screenshot({ path: out, omitBackground: true });
  await page.close();
  console.log(`  ${where}  ${size}x${size}`);
}
await browser.close();
