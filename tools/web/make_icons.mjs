// Render web/icon.svg to the sizes everything wants, and copy it for the app.
//
//   node tools/web/make_icons.mjs
//   node tools/web/make_icons.mjs assets/splash.png     only the ones named
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
import { readFileSync, mkdirSync, copyFileSync } from "node:fs";
import { resolve, dirname } from "node:path";

const root = resolve(dirname(new URL(import.meta.url).pathname), "../..");
const svg = readFileSync(resolve(root, "web/icon.svg"), "utf8");
const TILE = "#14181e";

// Where, how big, and on what: none (the mark alone), bleed (a square
// tile, the mark inside the maskable safe zone), tile (rounded) or splash
// (a window's shape, the mark alone in its middle). A size is a square's
// side, or [width, height].
const WANTED = [
  ["web/favicon-32.png", 32, "none"],
  ["web/favicon-180.png", 180, "bleed"],
  ["web/favicon-192.png", 192, "tile"],
  ["web/favicon-512.png", 512, "bleed"],
  // The window, the dock and the web build's own favicon: Godot makes the
  // macOS .icns and the Windows .exe icon from this, so it is drawn big.
  ["assets/icon.png", 512, "tile"],
  // The desktop app's boot splash (project.godot application/boot_splash):
  // laid on the app's dark face, the window's own shape scaled to fit it,
  // the mark a fifth of its height whatever the window's size. Godot's own
  // was the engine's logo (walk256 DS1, 2026-10-25).
  ["assets/splash.png", [2560, 1440], "splash"],
];
const ONLY = process.argv.slice(2);

// And the mark itself for the app, which reads no file under web/ (its
// .gdignore): the menu bar's mark (ModelBar.mark) draws this copy at the
// screen's density, as the toolbar draws its icons. A copy, byte for byte:
// tests/test_mark.py fails when it is not.
const COPY = "assets/ui/mark.svg";
if (!ONLY.length || ONLY.includes(COPY)) {
  copyFileSync(resolve(root, "web/icon.svg"), resolve(root, COPY));
  console.log(`  ${COPY}  a copy of web/icon.svg`);
}
if (ONLY.length && ONLY.every((one) => one === COPY)) process.exit(0);

const browser = await launch({ signedOut: true });  // a page of the site, not the app
for (const [where, size, ground] of WANTED) {
  if (ONLY.length && !ONLY.includes(where)) continue;
  const [width, height] = Array.isArray(size) ? size : [size, size];
  const page = await browser.newPage({
    viewport: { width, height },
    deviceScaleFactor: 1,
  });
  const inset = { none: 0, bleed: 0.2, tile: 0.17, splash: 0.4 }[ground];
  const radius = ground === "tile" ? width * 0.225 : 0;
  await page.setContent(
    `<!doctype html><style>
       html,body{margin:0;padding:0;background:transparent}
       div{width:${width}px;height:${height}px;box-sizing:border-box;
           padding:${height * inset}px ${(width - height * (1 - 2 * inset)) / 2}px;
           border-radius:${radius}px;
           background:${ground === "none" || ground === "splash" ? "transparent" : TILE}}
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
  console.log(`  ${where}  ${width}x${height}, ${ground}`);
}
await browser.close();
