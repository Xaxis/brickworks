// The site header's mark, our mark built in bricks, turning once (herostudio,
// 2026-11-26; the owner: the 3D brick logo should live "somewhere else" than
// the hero). Drawn by the hero's own code (web/viewer3d.js hero3d, the model
// in web/hero/mark.json) at FRAMES angles of one turn, eased in and out, each
// cut to the square every angle of it fits, side by side in one WebP strip
// with a clear ground: web/img/hero/mark-turn.webp. site.css shows its first
// frame as the header's .chip, and steps through the rest once when a visit
// begins and again on a hover or a focus (no three.js on any page for it).
//
//   node tools/site/mark_turn.mjs [--out=web/img/hero] [--size=60]
//
// Run it again after tools/web/hero_mark.mjs or tools/viewer/build.mjs
// changes the mark or the hero's look. FRAMES and SIZE are what site.css's
// mark-turn steps through (30 frames, 900 px of 30 px ones), at twice that.
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { launch } from "../web/browser.mjs";
import { serveDir } from "../web/static_server.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || "web/img/hero"));
mkdirSync(out, { recursive: true });
export const FRAMES = 30;
// Pixels a frame: twice the header's 30 CSS px, for a sharp screen.
const SIZE = Number(args.size || 60);
// Drawn this big and made smaller, so its edges are smooth.
const STAGE = [460, 414];

const site = await serveDir(resolve("web"));
const browser = await launch({ signedOut: true });
let failed = 0;
try {
  const context = await browser.newContext({ viewport: { width: STAGE[0], height: STAGE[1] }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.route(`${site.url}/__mark_turn.html`, (route) => route.fulfill({ contentType: "text/html", body:
    `<!DOCTYPE html><html><body style="margin:0;background:transparent"><div id="stage" style="position:relative;width:${STAGE[0]}px;height:${STAGE[1]}px"></div>`
    + `<script type="module">import { hero3d } from "/viewer3d.js";
      const stage = document.getElementById("stage");
      const made = await hero3d(stage, { assemble: false, keep: true, still: true });
      const gl = stage.querySelector("canvas");
      // An angle a frame, eased: it starts slowly, turns, and slows to rest.
      const ease = (t) => t * t * (3 - 2 * t);
      const frames = [];
      for (let k = 0; k < ${FRAMES}; k++) {
        made.pose(-2 * Math.PI * ease(k / ${FRAMES}), 0);
        made.picture();
        const c = document.createElement("canvas");
        c.width = gl.width; c.height = gl.height;
        c.getContext("2d").drawImage(gl, 0, 0);
        frames.push(c);
      }
      // The square every frame's bricks fit, round their middle.
      let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
      for (const c of frames) {
        const d = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
        for (let y = 0; y < c.height; y++) for (let x = 0; x < c.width; x++) {
          if (d[(y * c.width + x) * 4 + 3] > 8) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
        }
      }
      const side = Math.max(x1 - x0, y1 - y0) + 4;
      const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
      const strip = document.createElement("canvas");
      strip.width = ${SIZE} * frames.length; strip.height = ${SIZE};
      const g = strip.getContext("2d");
      g.imageSmoothingQuality = "high";
      frames.forEach((c, k) => g.drawImage(c, cx - side / 2, cy - side / 2, side, side, k * ${SIZE}, 0, ${SIZE}, ${SIZE}));
      window.made = { strip: strip.toDataURL("image/webp", 0.8), side, box: [x0, y0, x1, y1] };</script></body></html>` }));
  await page.goto(`${site.url}/__mark_turn.html`);
  const made = await page.waitForFunction(() => window.made, null, { timeout: 240000 }).then((h) => h.jsonValue()).catch(() => null);
  if (!made || !String(made.strip).startsWith("data:image/webp")) {
    console.error(`mark_turn: no strip (${errors.join("; ") || "none drawn"})`);
    failed += 1;
  } else {
    const file = join(out, "mark-turn.webp");
    const bytes = Buffer.from(made.strip.split(",")[1], "base64");
    writeFileSync(file, bytes);
    console.log(`mark_turn: ${file} ${FRAMES} frames of ${SIZE} px (cut from ${made.side} px), ${Math.round(bytes.length / 1024)} KB`);
  }
  await context.close();
} finally {
  await browser.close();
  site.close?.();
}
process.exit(failed ? 1 : 0);
