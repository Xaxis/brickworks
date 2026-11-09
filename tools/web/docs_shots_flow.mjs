// The documentation's pictures of the website, taken as docs-site/shots.json
// sets each one up, for tools/docs_shots.py to make docs-site/img/ of.
//
//   node tools/web/docs_shots_flow.mjs --root=DIR --out=DIR [--only=ID,ID] [--manifest=FILE]
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/docs_shots_flow.mjs --url=<deployment> --out=DIR
//
// --root is a site put together by tools/site.py DIR, served here; --url a
// deployment. Each picture is the real page, in a browser of its own at the
// picture's size, in each theme it names (the system's, as a person who
// never chose one sees it), with what the page asks the server answered
// from the manifest ("answers": an address's start and the JSON it gets),
// so a picture is the page's code and never the day's data: no clock, no
// counts, nobody's models. Signed out unless the manifest's "storage" puts
// a session where the page keeps one. Nothing moves: animations and
// transitions are stopped and the caret is hidden. Written as
// DIR/<id>.png (and DIR/<id>-light.png for the light theme), with
// DIR/<id>.json saying what was taken.
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.resolve(String(args.manifest || path.join(here, "../../docs-site/shots.json")));
const out = path.resolve(String(args.out || "shots/docs_shots"));
const only = args.only ? String(args.only).split(",").filter(Boolean) : [];
mkdirSync(out, { recursive: true });

let served = null;
if (args.root) served = await serveDir(path.resolve(String(args.root)));
const site = served ? served.url : String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("docs_shots_flow: --url=<deployment> or --root=<a site from tools/site.py>");
  process.exit(2);
}
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = bypass && !served ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const shots = (manifest.shots || []).filter((s) => s.source === "site" && (!only.length || only.includes(s.id)));
const STILL = `*, *::before, *::after { animation: none !important; transition: none !important;
  caret-color: transparent !important; scroll-behavior: auto !important; }`;

const browser = await launch({ signedOut: true });
let failed = 0;
let taken = 0;
for (const shot of shots) {
  for (const theme of shot.themes || ["dark"]) {
    const name = theme === "dark" ? shot.id : `${shot.id}-${theme}`;
    const [width, height] = shot.viewport || [1280, 800];
    const started = Date.now();
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1,
      colorScheme: theme, reducedMotion: "reduce", extraHTTPHeaders: headers, locale: "en-GB",
      timezoneId: "UTC" });
    try {
      // What the page asks the server, answered as the manifest says; the
      // rest of the site's own addresses as they are, and nothing elsewhere.
      const answers = Object.entries(shot.answers || {});
      await context.route("**/*", async (route) => {
        const asked = new URL(route.request().url());
        const local = asked.origin === new URL(site).origin;
        const where = local ? asked.pathname + asked.search : asked.href;
        const answer = answers.find(([start]) => where.startsWith(start));
        if (answer) {
          const given = answer[1];
          const status = given && typeof given === "object" && "status" in given && "body" in given ? given.status : 200;
          const body = given && typeof given === "object" && "status" in given && "body" in given ? given.body : given;
          return route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
        }
        if (local) return route.continue();
        return route.fulfill({ status: 404, contentType: "text/plain", body: "" });
      });
      const storage = shot.storage || {};
      await context.addInitScript((kept) => {
        for (const [key, value] of Object.entries(kept)) {
          try {
            localStorage.setItem(key, typeof value === "string" ? value : JSON.stringify(value));
          } catch { /* a page that keeps nothing */ }
        }
      }, storage);
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (error) => errors.push(String(error.message || error)));
      await page.goto(site + shot.route, { waitUntil: "load" });
      await page.addStyleTag({ content: STILL });
      if (shot.wait) await page.waitForSelector(shot.wait, { state: "visible", timeout: 30000 });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
      await page.mouse.move(width - 1, height - 1);
      await page.waitForTimeout(300);
      let clip = null;
      if (shot.crop && shot.crop !== "viewport") {
        const box = await page.locator(shot.crop).first().boundingBox();
        if (!box) throw new Error(`nothing to frame at ${shot.crop}`);
        const pad = Number(shot.pad || 0);
        const x = Math.max(0, Math.floor(box.x - pad));
        const y = Math.max(0, Math.floor(box.y - pad));
        clip = { x, y, width: Math.min(width - x, Math.ceil(box.width + 2 * pad)),
          height: Math.min(height - y, Math.ceil(box.height + 2 * pad)) };
      }
      // Two reads the same: nothing on the page still moving.
      let picture = await page.screenshot({ clip: clip || undefined, animations: "disabled", caret: "hide" });
      let settled = false;
      for (let n = 0; n < 8 && !settled; n++) {
        await page.waitForTimeout(250);
        const again = await page.screenshot({ clip: clip || undefined, animations: "disabled", caret: "hide" });
        settled = again.equals(picture);
        picture = again;
      }
      writeFileSync(path.join(out, `${name}.png`), picture);
      const sha256 = createHash("sha256").update(picture).digest("hex");
      writeFileSync(path.join(out, `${name}.json`), JSON.stringify({ id: name, ok: true, settled, errors,
        sha256, clip }, null, "\t") + "\n");
      taken += 1;
      console.log(`  ok    ${name}: ${theme}, ${clip ? `${clip.width}x${clip.height}` : `${width}x${height}`}, `
        + `${sha256.slice(0, 12)}, in ${((Date.now() - started) / 1000).toFixed(1)} s`
        + (settled ? "" : " (never read the same twice: it moves)")
        + (errors.length ? ` (the page logged: ${errors.join("; ")})` : ""));
    } catch (trouble) {
      failed += 1;
      writeFileSync(path.join(out, `${name}.json`), JSON.stringify({ id: name, ok: false,
        why: String(trouble.message || trouble) }, null, "\t") + "\n");
      console.log(`  FAIL  ${name}: ${trouble.message || trouble}`);
    } finally {
      await context.close();
    }
  }
}
await browser.close();
if (served) served.close();
console.log(`\ndocs_shots_flow: ${taken} picture(s) of the site${failed ? `, ${failed} FAILED` : ""}`);
process.exit(failed || !taken && shots.length ? 1 : 0);
