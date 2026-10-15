// How big, and how soon: the card drawing a packed model, timed.
//
//   godot --headless --path . --script src/dev/viewer_tools_probe.gd -- --sizes
//   node tools/viewer/first_paint.mjs --scene=<user data>/viewer_tools_probe/scene_400.json \
//     --scene=<user data>/viewer_tools_probe/scene_4000.json
//
// The built page (api/_viewer_page.js) in a sandboxed frame under the policy
// it declares, handed a result carrying the scene in _meta as a host that
// passes it does, and left to fetch every part's geometry from where the
// app does (the storage the scene names), as it would in Claude. Each scene
// twice in one browser: cold, then with the geometry in its cache. Says,
// from the moment the result arrived: the model unpacked, the first frame
// in 3D, every part's geometry in, every part drawn; and the sizes: the
// scene as it rides in the answer, the shapes and their bytes. The browser
// draws in software (SwiftShader), so the frame times are a slow machine's;
// a graphics card draws the same frames in milliseconds.
import { readFileSync } from "node:fs";
import { launch } from "../web/browser.mjs";
import { VIEWER_HTML } from "../../api/_viewer_page.js";

const scenes = process.argv.slice(2).filter((a) => a.startsWith("--scene=")).map((a) => a.slice(8));
if (!scenes.length) { console.error("first_paint: --scene=FILE, written by viewer_tools_probe -- --sizes"); process.exit(2); }

const origin = (root) => new URL(root).origin;
const policy = (root) => `default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; `
  + `connect-src 'self' ${origin(root)}; img-src 'self' data:; media-src 'self' data:; frame-src 'none'; object-src 'none';`;

// The geometry's bytes, asked of the storage itself: a browser's own count
// of a cross-origin file is withheld without Timing-Allow-Origin.
async function bytesOf(scene) {
  let total = 0;
  const hashes = [...new Set(scene.meshes.map((m) => m[1]).filter(Boolean))];
  for (let k = 0; k < hashes.length; k += 16) {
    const sizes = await Promise.all(hashes.slice(k, k + 16).map(async (h) => {
      const answer = await fetch(`${scene.root}${h}.lbm`, { method: "HEAD" });
      return Number(answer.headers.get("content-length")) || 0;
    }));
    total += sizes.reduce((a, b) => a + b, 0);
  }
  return { shapes: hashes.length, bytes: total };
}

const browser = await launch();
let failures = 0;
try {
  for (const file of scenes) {
    const scene = JSON.parse(readFileSync(file, "utf8")).scene;
    const parts = scene.count;
    const chars = JSON.stringify(scene).length;
    const geometry = await bytesOf(scene);
    console.log(`${parts} bricks: the scene ${chars.toLocaleString()} characters in the answer (${scene.bricks.length.toLocaleString()} of them the bricks), `
      + `${geometry.shapes} shapes, ${Math.round(geometry.bytes / 1024)} KB of geometry`);
    const context = await browser.newContext({ viewport: { width: 760, height: 900 } });
    for (const run of ["cold", "warm"]) {
      const page = await context.newPage();
      await page.goto("about:blank");
      await page.setContent(`<!doctype html><body style="margin:0;padding:20px;background:#262624">
        <iframe id="app" sandbox="allow-scripts" style="display:block;width:100%;border:0;height:620px"></iframe>
        <script>
        window.start = (html, result, csp) => {
          const frame = document.getElementById("app");
          const toPage = (m) => frame.contentWindow.postMessage(m, "*");
          window.onmessage = (e) => {
            const m = e.data || {};
            if (m.method === "ui/initialize") toPage({ jsonrpc: "2.0", id: m.id, result: { protocolVersion: "2026-01-26",
              hostInfo: { name: "first-paint", version: "1" }, hostCapabilities: {}, hostContext: { theme: "dark" } } });
            else if (m.method === "ui/notifications/initialized") {
              toPage({ jsonrpc: "2.0", method: "ui/notifications/tool-input", params: { arguments: {} } });
              toPage({ jsonrpc: "2.0", method: "ui/notifications/tool-result", params: result });
            } else if (m.id !== undefined && m.method) toPage({ jsonrpc: "2.0", id: m.id, result: {} });
          };
          const meta = '<meta http-equiv="Content-Security-Policy" content="' + csp + '">';
          frame.srcdoc = html.replace(/<head>/i, "<head>" + meta);
        };
        </script></body>`);
      const result = { content: [{ type: "text", text: "The model." }],
        _meta: { "brickworks/view": { parts, scene, views: [] }, "brickworks/model": "First paint" } };
      await page.evaluate(([h, r, c]) => window.start(h, r, c), [VIEWER_HTML, result, policy(scene.root)]);
      let frame = null;
      for (let n = 0; n < 60 && !frame; n++) {
        await page.waitForTimeout(250);
        frame = page.frames().find((f) => f !== page.mainFrame()) || null;
      }
      let card = {};
      for (let n = 0; n < 1200; n++) {
        card = await frame.evaluate(() => ({ state: window.brickworksCard.state, t: window.brickworksCard.timings,
          shown: window.brickworksCard.shown(), errors: window.brickworksCard.errors })).catch(() => ({}));
        if (card.state === "ready" && card.t && card.t.complete3d) break;
        await page.waitForTimeout(500);
      }
      const t = card.t || {};
      const after = (k) => (t[k] && t.result ? `${((t[k] - t.result) / 1000).toFixed(2)} s` : "never");
      console.log(`  ${run}: unpacked ${after("unpacked")}, first 3D frame ${after("first3d")}, `
        + `all geometry in ${after("loaded")}, every part drawn ${after("complete3d")}; ${card.shown} parts drawn`
        + `${card.errors && card.errors.length ? `; ${card.errors[0]}` : ""}`);
      if (card.state !== "ready" || !t.complete3d || (card.errors && card.errors.length)) failures += 1;
      await page.close();
    }
    await context.close();
  }
} finally {
  await browser.close();
}
console.log(failures ? `${failures} run(s) did not finish drawing` : "every scene drawn whole, cold and warm");
process.exit(failures ? 1 : 0);
