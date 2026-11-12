// The documentation's pictures of the website, taken as docs-site/pictures/<page>.json
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
//
// What a picture's page asks, said in its manifest:
//   "answers"   an address's start and what it gets: JSON, {"status", "body"},
//               or {"file": "docs-site/pictures/files/x.webp"} (a picture or a
//               model, from this checkout), the longest start first
//   "db"        for a page the server makes (/m/<id>, /u/<handle>, /c/<id>):
//               made here by the real api/share.js or api/people.js, its
//               database's answers by their start ("rest/v1/shares?id=eq.X",
//               "rpc/directory_model", "storage/v1/object/shared-models/X.mpd"
//               with {"file": ...}); anything else it asks is answered empty
//               and listed in DIR/<id>.json
//   "use"       ["test-account"]: docs-site/pictures/answers/<name>.json's
//               answers, db and storage first, the picture's own over them
//   "storage"   what localStorage holds (a session), "session" sessionStorage
//   "steps"     after the page is up, a person's: {"click": selector},
//               {"hover": selector}, {"press": "Escape"}, {"wait": selector},
//               {"scroll": selector}, {"pause": ms}
//   "crop"      a selector, a list of them (the box round them all), or
//               "viewport"; "pad" round it
//   "phone"     a phone's browser (touch, mobile), "scale" its pixels a point
import { launch } from "./browser.mjs";
import { serveDir } from "./static_server.mjs";
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.resolve(String(args.manifest || path.join(here, "../../docs-site/pictures")));
const out = path.resolve(String(args.out || "shots/docs_shots"));
const only = args.only ? String(args.only).split(",").filter(Boolean) : [];
mkdirSync(out, { recursive: true });

let served = null;
if (args.root) served = await serveDir(path.resolve(String(args.root)));
// A site served here is opened at the address a person sees, so a link the
// page shows (a share sheet's, an embed's) reads brickworks.diy, never this
// machine's port: its requests are fetched from the server here.
const site = served ? "https://brickworks.diy" : String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("docs_shots_flow: --url=<deployment> or --root=<a site from tools/site.py>");
  process.exit(2);
}
// The addresses a deployment serves from a page of another name. A
// picture is taken at the address a person is sent to, as its scripts see
// it: the connector's sign-in page is /oauth/authorize (api/oauth.js's
// authorization_endpoint), and web/theme.js leaves the beta's bar off it by
// that path; at /authorize, which no one is sent to, the bar's scripts came in.
const PAGES = { "/oauth/authorize": "authorize.html" };
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = bypass && !served ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

// A page's pictures are a file of their own (docs-site/pictures/<page>.json).
const files = statSync(manifestPath).isDirectory()
  ? readdirSync(manifestPath).filter((f) => f.endsWith(".json")).sort().map((f) => path.join(manifestPath, f))
  : [manifestPath];
const shots = files.flatMap((f) => JSON.parse(readFileSync(f, "utf8")).shots || [])
  .filter((s) => s.source === "site" && (!only.length || only.includes(s.id)));
const STILL = `*, *::before, *::after { animation: none !important; transition: none !important;
  caret-color: transparent !important; scroll-behavior: auto !important; }`;

// The answers a picture's page gets: the files it "use"s
// (docs-site/pictures/answers/<name>.json, one world shared by a page's
// pictures: the test account's own models), then its own over them.
const shared = path.join(statSync(manifestPath).isDirectory() ? manifestPath : path.dirname(manifestPath), "answers");
const ROOT = path.resolve(here, "../..");
function given(shot) {
  const out = { answers: {}, db: {}, storage: {}, session: {} };
  for (const name of shot.use || []) {
    const file = JSON.parse(readFileSync(path.join(shared, `${name}.json`), "utf8"));
    for (const key of Object.keys(out)) Object.assign(out[key], file[key] || {});
  }
  for (const key of Object.keys(out)) Object.assign(out[key], shot[key] || {});
  return out;
}

const TYPES = { ".webp": "image/webp", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml",
  ".json": "application/json", ".ldr": "text/plain", ".mpd": "text/plain", ".glb": "model/gltf-binary" };

/// What an answer is, to fulfil a request with: JSON, a status and JSON, or
/// a file of this checkout.
function fulfilment(given) {
  if (given && typeof given === "object" && !Array.isArray(given) && typeof given.file === "string") {
    const file = path.resolve(ROOT, given.file);
    if (!existsSync(file)) {
      asking.unanswered.push(`no file ${given.file}`);
      return { status: 404, contentType: "text/plain", body: "" };
    }
    return { status: 200, contentType: TYPES[path.extname(file)] || "application/octet-stream", body: readFileSync(file) };
  }
  const framed = given && typeof given === "object" && !Array.isArray(given) && "status" in given && "body" in given;
  return { status: framed ? given.status : 200, contentType: "application/json",
    body: JSON.stringify(framed ? given.body : given) };
}

/// The longest start of [answers] that [where] begins with.
function answerOf(answers, where) {
  let best = null;
  for (const [start, said] of Object.entries(answers)) {
    if (where.startsWith(start) && (!best || start.length > best[0].length)) best = [start, said];
  }
  return best;
}

// The pages the server makes, as tools/deploy.sh routes them, made here by
// this checkout's own handlers, called as tools/web/design_stand_in.mjs
// calls them; their database reached by fetch, answered from the picture's
// "db" and nothing else.
const SERVER = [
  [/^\/m\/([A-Za-z0-9]{10})\/?$/, "share", (m) => ({ op: "page", id: m[1] })],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})\/?$/, "share", (m) => ({ op: "page", id: m[1], v: m[2] })],
  [/^\/u\/([a-z0-9-]{3,24})\/?$/, "people", (m) => ({ op: "page", handle: m[1] })],
  [/^\/c\/([A-Za-z0-9]{10})\/?$/, "people", (m) => ({ op: "list_page", id: m[1] })],
];
const DB = "https://db.docs.example";
let asking = { db: {}, unanswered: [] };
let realFetch = null;
const handlers = {};
async function serverMade(name, query, host, proto) {
  process.env.SUPABASE_URL = DB;
  process.env.SUPABASE_SECRET_KEY = "docs";
  process.env.SUPABASE_PUBLISHABLE_KEY = "docs";
  if (!realFetch) {
    realFetch = globalThis.fetch;
    globalThis.fetch = async (input, init = {}) => {
      const asked = typeof input === "string" || input instanceof URL ? String(input) : input.url;
      if (!asked.startsWith(`${DB}/`)) return realFetch(input, init);
      const where = asked.slice(DB.length + 1);
      const said = answerOf(asking.db, where);
      if (said) {
        const { status, contentType, body } = fulfilment(said[1]);
        return new Response(body, { status, headers: { "content-type": contentType } });
      }
      const method = String(init.method || "GET").toUpperCase();
      asking.unanswered.push(`${method} ${decodeURIComponent(where)}${init.body && where.startsWith("rest/v1/rpc/")
        ? ` ${String(init.body).slice(0, 160)}` : ""}`);
      if (where.startsWith("storage/")) return new Response("", { status: 404 });
      if (where.startsWith("rest/v1/rpc/")) return new Response("null", { status: 200, headers: { "content-type": "application/json" } });
      return new Response(method === "GET" ? "[]" : "", { status: method === "GET" ? 200 : 204,
        headers: { "content-type": "application/json" } });
    };
  }
  handlers[name] ??= (await import(pathToFileURL(path.join(ROOT, "api", `${name}.js`)).href)).default;
  const request = { method: "GET", query, body: undefined, headers: { host, "x-forwarded-proto": proto,
    accept: "text/html", "user-agent": "Mozilla/5.0 (X11; Linux x86_64) Brickworks docs pictures" } };
  const response = {
    statusCode: 200, headers: {}, body: "",
    status(code) { this.statusCode = code; return this; },
    setHeader(key, value) { this.headers[String(key).toLowerCase()] = value; return this; },
    json(value) { this.headers["content-type"] = "application/json"; this.body = JSON.stringify(value); return this; },
    send(value) { this.body = value ?? ""; return this; },
    end(value) { this.body = value ?? ""; return this; },
  };
  await handlers[name](request, response);
  return { status: response.statusCode, contentType: String(response.headers["content-type"] || "text/html; charset=utf-8"),
    body: Buffer.isBuffer(response.body) ? response.body : String(response.body) };
}

/// The box round everything [crop] names on [page], [pad] round it, inside the window.
async function boxOf(page, crop, pad, width, height) {
  const boxes = [];
  for (const one of Array.isArray(crop) ? crop : [crop]) {
    const box = await page.locator(one).first().boundingBox();
    if (!box) throw new Error(`nothing to frame at ${one}`);
    boxes.push(box);
  }
  const left = Math.min(...boxes.map((b) => b.x)) - pad;
  const top = Math.min(...boxes.map((b) => b.y)) - pad;
  const right = Math.max(...boxes.map((b) => b.x + b.width)) + pad;
  const bottom = Math.max(...boxes.map((b) => b.y + b.height)) + pad;
  const x = Math.max(0, Math.floor(left));
  const y = Math.max(0, Math.floor(top));
  return { x, y, width: Math.min(width - x, Math.ceil(right - x)), height: Math.min(height - y, Math.ceil(bottom - y)) };
}

/// A person's step on the page.
async function act(page, step) {
  if (step.click) await page.locator(step.click).first().click();
  else if (step.hover) await page.locator(step.hover).first().hover();
  else if (step.press) await page.keyboard.press(step.press);
  else if (step.wait) await page.waitForSelector(step.wait, { state: "visible", timeout: 30000 });
  else if (step.scroll) await page.locator(step.scroll).first().scrollIntoViewIfNeeded();
  else if (!("pause" in step)) throw new Error(`a step this flow does not know: ${JSON.stringify(step)}`);
  await page.waitForTimeout(Number(step.pause ?? 300));
}

// Text in grey, never in a screen's red-green-blue stripes. Chrome picks
// one or the other for each layer as it draws, and not the same way each
// run: in two of six runs one theme's text came out striped, 400,000
// pixels a few levels off, though the page was the same (2026-11-09).
// Grey is what a picture should carry anyway: it is shown on screens whose
// stripes run otherwise, and scaled.
const browser = await launch({ signedOut: true, args: ["--disable-lcd-text"] });
let failed = 0;
let taken = 0;
for (const shot of shots) {
  for (const theme of shot.themes || ["dark"]) {
    const name = theme === "dark" ? shot.id : `${shot.id}-${theme}`;
    const [width, height] = shot.viewport || [1280, 800];
    const started = Date.now();
    const phone = Boolean(shot.phone);
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: Number(shot.scale || 1),
      isMobile: phone, hasTouch: phone,
      colorScheme: theme, reducedMotion: "reduce", extraHTTPHeaders: headers, locale: "en-GB",
      timezoneId: "UTC" });
    const said = given(shot);
    asking = { db: said.db, unanswered: [] };
    const unknown = [];
    try {
      // What the page asks the server, answered as the manifest says; a page
      // the server makes, made by its handler with the manifest's database;
      // the rest of the site's own addresses as they are, and nothing elsewhere.
      await context.route("**/*", (route) => answer(route).catch((trouble) => {
        asking.unanswered.push(`${route.request().url()}: ${trouble?.stack || trouble}`.slice(0, 400));
        return route.fulfill({ status: 500, contentType: "text/plain", body: "" }).catch(() => {});
      }));
      async function answer(route) {
        const asked = new URL(route.request().url());
        const local = asked.origin === new URL(site).origin;
        const where = local ? asked.pathname + asked.search : asked.href;
        const answer = answerOf(said.answers, where);
        if (answer) return route.fulfill(fulfilment(answer[1]));
        if (local && served && PAGES[asked.pathname]) {
          return route.fulfill({ path: path.join(path.resolve(String(args.root)), PAGES[asked.pathname]) });
        }
        const made = local && served && SERVER.map(([pattern, name, query]) => {
          const found = pattern.exec(asked.pathname);
          return found && { name, query: { ...Object.fromEntries(asked.searchParams), ...query(found) } };
        }).find(Boolean);
        if (made) return route.fulfill(await serverMade(made.name, made.query, asked.host, asked.protocol.replace(":", "")));
        if (local && asked.pathname.startsWith("/api/")) unknown.push(`${route.request().method()} ${where}`);
        if (local && served) return route.fulfill({ response: await route.fetch({ url: served.url + where }) });
        if (local) return route.continue();
        return route.fulfill({ status: 404, contentType: "text/plain", body: "" });
      }
      await context.addInitScript(([kept, held]) => {
        for (const [store, values] of [[localStorage, kept], [sessionStorage, held]]) {
          for (const [key, value] of Object.entries(values)) {
            try {
              store.setItem(key, typeof value === "string" ? value : JSON.stringify(value));
            } catch { /* a page that keeps nothing */ }
          }
        }
      }, [said.storage, said.session]);
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (error) => errors.push(String(error.message || error)));
      await page.goto(site + shot.route, { waitUntil: "load" });
      await page.addStyleTag({ content: STILL });
      if (shot.wait) await page.waitForSelector(shot.wait, { state: "visible", timeout: 30000 });
      await page.evaluate(() => document.fonts.ready);
      await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
      for (const step of shot.steps || []) await act(page, step);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
      if (!(shot.steps || []).some((step) => step.hover)) await page.mouse.move(width - 1, height - 1);
      await page.waitForTimeout(300);
      let clip = null;
      if (shot.crop && shot.crop !== "viewport") clip = await boxOf(page, shot.crop, Number(shot.pad || 0), width, height);
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
        sha256, clip, unanswered: { api: unknown, db: asking.unanswered } }, null, "\t") + "\n");
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
