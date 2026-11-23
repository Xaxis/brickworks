// The home hero's posters (hero3d, 2026-11-23): the mark in bricks finished,
// drawn by the hero's own code (web/viewer3d.js hero3d) at its stage's shape
// (web/index.html .hero-stage, 460 / 414), 222, 444 and 888 px across (SHAPES),
// each a WebP with its ground clear, so one picture sits on the light page and the dark. They are
// the first screen's first paint, and the 3D takes their place without a jump
// since it is the same drawing.
//
//   node tools/web/hero_poster.mjs [--out=web/img/hero]
//
// Run it after tools/web/hero_mark.mjs and tools/viewer/build.mjs whenever
// the mark or the hero's look changes. The browser draws in software
// (SwiftShader), as every check's does; the picture is the same drawing a
// graphics card makes.
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || "web/img/hero"));
mkdirSync(out, { recursive: true });
// [CSS px across, CSS px down, pixels a CSS px]: the stage, 460 / 414 at
// every width (400 down from 900 px, 45% of the width under it): a phone's
// size, a laptop's, and twice that for a sharp screen.
const SHAPES = [[222, 200, 1], [444, 400, 1], [444, 400, 2]];
const QUALITY = 0.86;

const site = await serveDir(resolve("web"));
const browser = await launch({ signedOut: true });
let failed = 0;
try {
  for (const [w, h, scale] of SHAPES) {
    {
      const name = "mark";
      const context = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: scale });
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (e) => errors.push(e.message));
      await page.route(`${site.url}/__hero_poster.html`, (route) => route.fulfill({ contentType: "text/html", body:
        `<!DOCTYPE html><html><body style="margin:0;background:transparent"><div id="stage" style="position:relative;width:${w}px;height:${h}px"></div>`
        + `<script type="module">import { hero3d } from "/viewer3d.js";
          const made = await hero3d(document.getElementById("stage"), { assemble: false, keep: true });
          window.poster = made.picture("image/webp", ${QUALITY});</script></body></html>` }));
      await page.goto(`${site.url}/__hero_poster.html`);
      const shot = await page.waitForFunction(() => window.poster, null, { timeout: 180000 }).then((h) => h.jsonValue()).catch(() => "");
      if (!shot.startsWith("data:image/webp")) {
        console.error(`hero_poster: no picture for ${name} at ${scale}x (${errors.join("; ") || "none drawn"})`);
        failed += 1;
      } else {
        const file = join(out, `${name}-${w * scale}.webp`);
        const bytes = Buffer.from(shot.split(",")[1], "base64");
        writeFileSync(file, bytes);
        console.log(`hero_poster: ${file} ${w * scale} x ${h * scale}, ${Math.round(bytes.length / 1024)} KB`);
      }
      await context.close();
    }
  }
} finally {
  await browser.close();
  site.close?.();
}
process.exit(failed ? 1 : 0);
