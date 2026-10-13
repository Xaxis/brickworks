// Render web/icon.svg to the sizes everything wants.
//
//   node tools/web/make_icons.mjs
//
// One source, many sizes, because a favicon set assembled by hand goes
// out of step the first time the mark changes — and the one that goes
// stale is always the one nobody looks at.
//
// The mark has no background of its own. A browser tab shows it as it is,
// at the most pixels a 16 px tab has; an icon that sits on someone else's
// background (a phone's home screen, a dock, an app list) gets a dark tile
// behind it, drawn here. Full bleed where the platform rounds the corners
// itself (iOS, a maskable icon), a rounded tile where it does not (the
// desktop app, which Godot makes the macOS and Windows icons from).
//
// Playwright rather than a rasteriser, because it is already here for
// the deploy check and it renders the SVG with the same engine the tab
// will.
import { launch } from "./browser.mjs";
import { readFileSync, mkdirSync } from "node:fs";
import { resolve, dirname } from "node:path";

const root = resolve(dirname(new URL(import.meta.url).pathname), "../..");
const svg = readFileSync(resolve(root, "web/icon.svg"), "utf8");
const TILE = "#14181e";

// Where, how big, and on what: none (the mark alone), bleed (a square
// tile, the mark inside the maskable safe zone) or tile (rounded).
const WANTED = [
  ["web/favicon-32.png", 32, "none"],
  ["web/favicon-180.png", 180, "bleed"],
  ["web/favicon-192.png", 192, "tile"],
  ["web/favicon-512.png", 512, "bleed"],
  // The window, the dock and the web build's own favicon: Godot makes the
  // macOS .icns and the Windows .exe icon from this, so it is drawn big.
  ["assets/icon.png", 512, "tile"],
];

const browser = await launch({ signedOut: true });  // a page of the site, not the app
for (const [where, size, ground] of WANTED) {
  const page = await browser.newPage({
    viewport: { width: size, height: size },
    deviceScaleFactor: 1,
  });
  const inset = { none: 0, bleed: 0.2, tile: 0.17 }[ground];
  const radius = ground === "tile" ? size * 0.225 : 0;
  await page.setContent(
    `<!doctype html><style>
       html,body{margin:0;padding:0;background:transparent}
       div{width:${size}px;height:${size}px;box-sizing:border-box;
           padding:${size * inset}px;border-radius:${radius}px;
           background:${ground === "none" ? "transparent" : TILE}}
       svg{display:block;width:100%;height:100%}
     </style><div>${svg}</div>`,
    { waitUntil: "load" },
  );
  const out = resolve(root, where);
  mkdirSync(dirname(out), { recursive: true });
  // Chromium on a loaded machine sometimes answers "Unable to capture
  // screenshot" once; the page is fine, so ask again.
  for (let attempt = 1; ; attempt++) {
    try {
      await page.screenshot({ path: out, omitBackground: true, timeout: 60000 });
      break;
    } catch (trouble) {
      if (attempt >= 4) throw trouble;
      await page.waitForTimeout(1500);
    }
  }
  await page.close();
  console.log(`  ${where}  ${size}x${size}, ${ground}`);
}
await browser.close();
