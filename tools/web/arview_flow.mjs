// In your room on a model's page (APP_UX5 #13, arview; web/model-page.js
// offerRoom, web/room.js, web/glb.js): is it offered where a phone or a
// tablet can place a model in a room, and only there, and is what it
// places the GLB the app's Export writes, under the size a phone is given?
//
//   node tools/web/arview_flow.mjs [--out=DIR] [--model=FILE] [--root=DIR] [--before=DIR]
//   node tools/web/arview_flow.mjs --url=<deployment> [--out=DIR]
//
// With no --url nothing leaves this machine: the model page is made by
// --root's api/ (this checkout's by default) and served with its web/,
// every API call answered by design_stand_in.mjs, the model's file --model
// (the example car), each part's geometry from assets/generated/parts. With
// --url (a preview: BW_BYPASS=$VERCEL_BYPASS) the page is the gallery's
// first model's on the deployment.
//
//   1. A computer (1280 x 720 and 1400 x 900, Chromium as it is): not
//      offered, and nothing of it asked for.
//   2. An Android phone (412 x 915; WebXR's immersive AR, which a stub
//      stands in for: it says it has it, and records what asks for a
//      session, which it refuses, having no camera): In your room on the
//      picture's foot, opposite View in 3D, and before the tap none of
//      <model-viewer>, web/room.js, web/glb.js or the model's room.json
//      asked for. Tapped: the model shown, to turn; its GLB, fetched back
//      from the page, byte for byte the one web/glb.js writes of the file
//      (which src/dev/arview_probe.gd reads against Export's own, part by
//      part), every part and colour in it, under web/glb.js MOST_BYTES.
//      Place it in your room asks WebXR for an immersive-ar session, in
//      the tap; refused, the page says the phone could not open its camera
//      and keeps the model. Back to the picture puts the picture back, and
//      In your room again shows it at once, asking for nothing more.
//   3. An iPhone (390 x 844; AR Quick Look, which Safari has and a stub
//      says Chromium has): offered, tapped, shown; Place it in your room
//      hands Quick Look a USDZ, which <model-viewer> makes of the same GLB:
//      caught as it is handed over, opened, and its geometry and materials
//      counted against the GLB's.
//   4. An iPad (820 x 1180, which says it is a Mac with a touch screen):
//      offered, tapped, shown.
//   5. A model over the size (its room.json saying more triangles than a
//      phone is given): tapped, the page says it is too big, before a
//      single shape or <model-viewer> is asked for.
//   6. The page's first load, with --before (another checkout's web/ and
//      api/, the one before this): requests and bytes on the phone and on
//      the computer, before and after; the same requests, nothing of the
//      room's among them.
//
// Every visit: no script error and nothing the page's security policy
// refused. Pictures in --out: each device's first screen, the model shown,
// and the refusal.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { devices } from "playwright";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { gzipSync } from "node:zlib";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const checkout = path.resolve(here, "../..");
const root = args.root ? path.resolve(String(args.root)) : checkout;
const before = args.before ? path.resolve(String(args.before)) : "";
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const modelFile = path.resolve(String(args.model || path.join(checkout, "models/car.ldr")));
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
// The writer and the plan of this checkout, which the probe holds to Export's.
const { roomOf } = await import(pathToFileURL(path.join(checkout, "api/_parts.js")).href);
const { MOST_BYTES, writeGlb } = await import(pathToFileURL(path.join(checkout, "web/glb.js")).href);
const { parseLbm } = await import(pathToFileURL(path.join(checkout, "web/lbm.js")).href);

let passed = 0;
let failed = 0;
const check = (what, ok) => {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  return ok;
};
const until = (page, test, arg, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const shoot = (page, name) => (out ? page.screenshot({ path: path.join(out, `${name}.png`) }) : null);
const ROOM_ASKED = /\/room\.(js|css|json)(\?|$)|\/glb\.js(\?|$)|\/model-viewer-[0-9.]+\//;
// <model-viewer> compiles three.js's meshopt decoder as it loads (for a GLB
// squeezed with EXT_meshopt_compression, which the room's never is), and a
// page's policy lets no WebAssembly be compiled (script-src 'self', without
// 'wasm-unsafe-eval'): refused, as it is meant to be, and said once each.
const MESHOPT = { error: /^WebAssembly\.instantiate\(\): .*Content Security/, refused: /^script-src wasm-eval\b/ };
/// What went wrong on a page: its script errors and its policy's refusals,
/// less the meshopt decoder's, which are counted as meant.
function trouble(seen, refused) {
  const errors = seen.errors.filter((one) => !MESHOPT.error.test(one));
  const refusals = refused.filter((one) => !MESHOPT.refused.test(one));
  const meant = seen.errors.length - errors.length + refused.length - refusals.length;
  return { wrong: [...errors, ...refusals], meant };
}
const VIEWER_ASKED = /\/model-viewer-[0-9.]+\/model-viewer\.min\.js/;

let modelPath = `/m/${stand.MODEL_ID}`;
let modelText = readFileSync(modelFile, "utf8");
if (remote) {
  const listed = await (await fetch(`${remote}/api/share?op=list&page=1`, { headers })).json().catch(() => ({}));
  const first = (listed.models || [])[0];
  if (!check("the deployment's gallery has a model to visit", Boolean(first))) process.exit(1);
  modelPath = `/m/${first.id}`;
  modelText = await (await fetch(`${remote}${modelPath}.mpd`, { headers })).text();
} else {
  stand.useModelFile(modelText);
}

// What each device is, and what stands in for what its browser has.
const ANDROID = { ...devices["Pixel 7"], label: "android", way: "webxr" };
const IPHONE = { ...devices["iPhone 14"], label: "iphone", way: "quick-look" };
const IPAD = { viewport: { width: 820, height: 1180 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
  userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15",
  label: "ipad", way: "quick-look", mac: true };

/// The page's own record of what it was refused and what asked for WebXR.
function watch() {
  window.__refused = [];
  document.addEventListener("securitypolicyviolation", (event) => window.__refused.push(`${event.violatedDirective} ${event.blockedURI}`));
}
function webxr() {
  window.__xrAsked = [];
  if (!window.XRSession) window.XRSession = function XRSession() {};
  if (!window.XRSession.prototype.requestHitTestSource) window.XRSession.prototype.requestHitTestSource = function requestHitTestSource() {};
  const plain = (value) => JSON.parse(JSON.stringify(value || {}, (key, one) => (one instanceof Node ? `<${one.nodeName}>` : one)));
  const xr = {
    isSessionSupported: async (mode) => mode === "immersive-ar",
    requestSession: async (mode, options) => {
      window.__xrAsked.push({ mode, options: plain(options), activation: navigator.userActivation?.isActive ?? null });
      throw new DOMException("this check has no camera", "NotSupportedError");
    },
    addEventListener() {}, removeEventListener() {},
  };
  Object.defineProperty(navigator, "xr", { get: () => xr, configurable: true });
}
function quickLook(mac) {
  // Safari's: a link may be rel="ar", and there is no WebXR.
  const supports = DOMTokenList.prototype.supports;
  DOMTokenList.prototype.supports = function supportsAr(token) { return token === "ar" || supports.call(this, token); };
  Object.defineProperty(navigator, "xr", { get: () => undefined, configurable: true });
  if (mac) {
    Object.defineProperty(navigator, "platform", { get: () => "MacIntel", configurable: true });
    Object.defineProperty(navigator, "maxTouchPoints", { get: () => 5, configurable: true });
  }
}

/// A page of [device] on [site] (a checkout's web/ and api/), with what it
/// asks for, its script errors and the bytes it was given recorded.
async function visit(browser, device, site = root) {
  const { label, way, mac, ...options } = device;
  const context = await browser.newContext({ ...options, extraHTTPHeaders: headers, acceptDownloads: true });
  await context.addInitScript(watch);
  if (way === "webxr") await context.addInitScript(webxr);
  if (way === "quick-look") await context.addInitScript(quickLook, Boolean(mac));
  await stand.serveSite(context, { web: path.join(site, "web"), api: path.join(site, "api"), remote, headers });
  const page = await context.newPage();
  const seen = { asked: [], errors: [], bytes: 0, zipped: 0 };
  page.on("request", (request) => seen.asked.push(request.url()));
  page.on("pageerror", (error) => seen.errors.push(String(error.message || error)));
  page.on("response", async (response) => {
    try {
      const body = await response.body();
      seen.bytes += body.length;
      seen.zipped += gzipSync(body).length;
    } catch { /* a redirect, or gone with the page */ }
  });
  await page.goto(`${base}${modelPath}`, { waitUntil: "load" });
  await page.waitForLoadState("networkidle").catch(() => {});
  return { context, page, seen };
}
const refusedBy = (page) => page.evaluate(() => window.__refused || []);

/// The GLB the page placed, as bytes, fetched back from its blob: address.
async function placedGlb(page) {
  const b64 = await page.evaluate(async () => {
    const src = document.querySelector(".room model-viewer")?.getAttribute("src");
    if (!src) return "";
    const bytes = new Uint8Array(await (await fetch(src)).arrayBuffer());
    let text = "";
    for (let at = 0; at < bytes.length; at += 0x8000) text += String.fromCharCode(...bytes.subarray(at, at + 0x8000));
    return btoa(text);
  });
  return Buffer.from(b64, "base64");
}

/// A GLB's document.
function glbDoc(bytes) {
  if (bytes.length < 20 || bytes.readUInt32LE(0) !== 0x46546c67) return null;
  return JSON.parse(bytes.subarray(20, 20 + bytes.readUInt32LE(12)).toString("utf8"));
}

/// What web/glb.js writes of the model, given the plan the page was given
/// and each part's geometry: this checkout's, or the deployment's store.
async function expectedGlb(plan, title) {
  const shapes = new Map();
  for (const hash of new Set(plan.meshes.map((mesh) => mesh[1]))) {
    let bytes = null;
    if (remote) {
      const got = await fetch(`${plan.root}${hash}.lbm`).catch(() => null);
      bytes = got && got.ok ? Buffer.from(await got.arrayBuffer()) : null;
    } else {
      const file = path.join(checkout, "assets/generated/parts", `${hash}.lbm`);
      bytes = existsSync(file) ? readFileSync(file) : null;
    }
    shapes.set(hash, bytes ? parseLbm(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)) : null);
  }
  return writeGlb(plan, (hash) => shapes.get(hash) || null, { title, generator: "Brickworks (brickworks.diy)" });
}

/// The files a USDZ (a zip, stored) holds: name -> text.
function unzip(bytes) {
  const files = new Map();
  let at = 0;
  while (at + 30 <= bytes.length && bytes.readUInt32LE(at) === 0x04034b50) {
    const method = bytes.readUInt16LE(at + 8);
    const size = bytes.readUInt32LE(at + 18);
    const nameLength = bytes.readUInt16LE(at + 26);
    const extra = bytes.readUInt16LE(at + 28);
    const name = bytes.subarray(at + 30, at + 30 + nameLength).toString("utf8");
    const start = at + 30 + nameLength + extra;
    if (method === 0) files.set(name, bytes.subarray(start, start + size).toString("utf8"));
    at = start + size;
  }
  return files;
}

/// Where In your room and View in 3D are on the picture.
const offerOf = (page) => page.evaluate(() => {
  const box = (el) => {
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height, right: r.right, bottom: r.bottom };
  };
  const go = document.querySelector(".room-go");
  return { go: box(go), how: go?.dataset.how || "", label: go?.getAttribute("aria-label") || "", text: go?.textContent || "",
    picture: box(document.querySelector(".model-page .picture")), view3d: box(document.querySelector(".model-page .picture .go")),
    hit: go ? document.elementFromPoint(box(go).x + box(go).w / 2, box(go).y + box(go).h / 2)?.closest(".room-go") === go : false };
});

/// A phone or tablet: offered, tapped, shown, its GLB the writer's.
async function placed(browser, device) {
  const { label, way } = device;
  console.log(`\n${label} (${device.viewport.width} x ${device.viewport.height}, ${way})`);
  const { context, page, seen } = await visit(browser, device);
  const offered = await until(page, () => Boolean(document.querySelector(".room-go")), null, 6000);
  const at = await offerOf(page);
  check(`${label}: In your room is offered (${at.how || "not offered"})`, offered && at.how === way);
  if (!offered) {
    await shoot(page, `${label}-not-offered`);
    await context.close();
    return;
  }
  check(`${label}: it is on the picture's foot, on the left, opposite View in 3D, and a finger lands on it `
    + `(${Math.round(at.go.x - at.picture.x)} px in, ${Math.round(at.picture.bottom - at.go.bottom)} px up; ${Math.round(at.go.w)} x ${Math.round(at.go.h)})`,
    at.go.x >= at.picture.x && at.go.bottom <= at.picture.bottom && at.go.y > at.picture.y + at.picture.h / 2
      && at.go.x + at.go.w / 2 < at.picture.x + at.picture.w / 2 && (!at.view3d || at.go.right < at.view3d.x || at.go.bottom < at.view3d.y)
      && at.go.h >= 40 && at.hit);
  const early = seen.asked.filter((url) => ROOM_ASKED.test(url));
  check(`${label}: before the tap nothing of the room is asked for (${early.length}: ${early.map((u) => u.split("/").pop()).join(", ") || "none"})`, early.length === 0);
  await shoot(page, `${label}-offered`);
  const tapped = Date.now();
  await page.tap(".room-go");
  const shown = await until(page, () => ["ready", "failed", "refused"].includes(document.querySelector(".room")?.dataset.state), null, 180000);
  const room = await page.evaluate(() => ({ ...(document.querySelector(".room")?.dataset || {}),
    said: document.querySelector(".room-said")?.hidden ? "" : document.querySelector(".room-said")?.textContent || "" }));
  check(`${label}: tapped, the model is shown to turn (${room.state}, ${((Date.now() - tapped) / 1000).toFixed(1)} s${room.said ? `; "${room.said}"` : ""})`,
    shown && room.state === "ready");
  if (room.state !== "ready") {
    await shoot(page, `${label}-room`);
    await context.close();
    return;
  }
  // Drawn: <model-viewer> has its model and a frame or two of it.
  await until(page, () => document.querySelector(".room model-viewer")?.loaded === true, null, 30000);
  await page.waitForTimeout(1500);
  await shoot(page, `${label}-room`);
  const viewerAsked = seen.asked.filter((url) => VIEWER_ASKED.test(url));
  check(`${label}: <model-viewer> came on the tap, once, from this site (${viewerAsked.map((u) => new URL(u).pathname).join(", ")})`,
    viewerAsked.length === 1 && new URL(viewerAsked[0]).origin === new URL(base).origin);
  const glb = await placedGlb(page);
  const plan = await page.evaluate(async (scene) => (await fetch(scene.replace(/scene\.json$/, "room.json"))).json(),
    await page.evaluate(() => document.querySelector(".model-page .picture").dataset.scene));
  const title = await page.evaluate(() => document.querySelector(".model-page .picture img")?.getAttribute("alt") || "");
  const mine = await expectedGlb(plan, title);
  check(`${label}: its GLB is byte for byte what web/glb.js writes of the file (${glb.length} bytes; written here ${mine.glb.length})`,
    glb.length === mine.glb.length && Buffer.compare(glb, Buffer.from(mine.glb)) === 0);
  const doc = glbDoc(glb);
  const nodes = doc ? doc.nodes.filter((node) => node.extras?.ldraw_part) : [];
  const colours = new Set(nodes.map((node) => node.extras.ldraw_colour));
  const file = remote ? null : roomOf(modelText, "");
  check(`${label}: every part is in it, in its colour (${nodes.length} parts, ${colours.size} colours; the file's ${file ? file.parts.length : plan.parts.length} parts,`
    + ` ${file ? new Set(file.parts.map((p) => file.colours[p[1]][0])).size : "?"} colours)`,
    Boolean(doc) && nodes.length === (file ? file.parts.length : plan.parts.length)
      && (!file || colours.size === new Set(file.parts.map((p) => file.colours[p[1]][0])).size));
  check(`${label}: under the size a phone is given (${(glb.length / 1048576).toFixed(2)} MB of ${MOST_BYTES / 1048576} MB), `
    + `nothing in it a viewer must decode (${JSON.stringify(doc?.extensionsUsed || [])})`, glb.length <= MOST_BYTES && !(doc?.extensionsUsed || []).length);

  // Place it in your room.
  const placeShown = await until(page, () => {
    const button = document.querySelector(".room .room-place");
    return Boolean(button) && button.getBoundingClientRect().width > 0 && getComputedStyle(button).visibility !== "hidden";
  }, null, 10000);
  check(`${label}: Place it in your room is on the model's frame`, placeShown);
  if (way === "webxr" && placeShown) {
    await page.tap(".room .room-place");
    const asked = await until(page, () => (window.__xrAsked || []).length > 0, null, 15000);
    const sessions = await page.evaluate(() => window.__xrAsked || []);
    check(`${label}: it asks WebXR for an immersive-ar session, in the tap (${JSON.stringify(sessions[0] || {})})`,
      asked && sessions[0]?.mode === "immersive-ar" && sessions[0]?.activation !== false);
    const told = await until(page, () => /camera/.test(document.querySelector(".room-said")?.textContent || "")
      && !document.querySelector(".room-said").hidden, null, 10000);
    check(`${label}: refused (no camera here), the page says so and keeps the model ("${await page.evaluate(() => document.querySelector(".room-said")?.textContent || "")}")`,
      told && await page.evaluate(() => Boolean(document.querySelector(".room model-viewer")) && !document.querySelector(".room").hidden));
    await shoot(page, `${label}-refused-camera`);
  }
  if (way === "quick-look" && placeShown && label === "iphone") {
    const started = Date.now();
    const [download] = await Promise.all([page.waitForEvent("download", { timeout: 120000 }).catch(() => null), page.tap(".room .room-place")]);
    const usdzPath = out ? path.join(out, `${label}.usdz`) : "";
    let usdz = null;
    if (download) {
      const saved = usdzPath || path.join(path.dirname(modelFile), ".arview.usdz");
      await download.saveAs(saved);
      usdz = readFileSync(saved);
    }
    const files = usdz ? unzip(usdz) : new Map();
    const text = [...files.values()].join("\n");
    const geometries = [...files.keys()].filter((name) => name.startsWith("geometries/")).length;
    const meshes = (text.match(/\bdef Mesh\b/g) || []).length;
    const materials = (text.match(/\bdef Material\b/g) || []).length;
    const usedMaterials = new Set(doc.meshes.flatMap((mesh) => mesh.primitives.map((one) => one.material))).size;
    const drawn = nodes.reduce((sum, node) => sum + doc.meshes[node.mesh].primitives.length, 0);
    const placedPrims = (text.match(/prepend references = @\.\/geometries\//g) || []).length;
    console.log(`        USDZ: ${download?.suggestedFilename() || "none"}, ${usdz ? (usdz.length / 1048576).toFixed(2) : 0} MB in ${((Date.now() - started) / 1000).toFixed(1)} s;`
      + ` ${files.size} files, ${geometries} geometries, ${meshes} meshes, ${placedPrims} placed, ${materials} materials`);
    check(`${label}: Place it in your room hands Quick Look a USDZ made of the same model (${download?.suggestedFilename() || "nothing handed over"}; `
      + `${materials} materials for the GLB's ${usedMaterials}, ${placedPrims} surfaces placed for its ${drawn})`,
      Boolean(usdz) && /\.usdz$/.test(download.suggestedFilename()) && files.has("model.usda") && materials === usedMaterials
        && (placedPrims === drawn || meshes === drawn));
  }
  // Back to the picture, and again.
  await page.tap(".room [data-close]");
  const back = await until(page, () => document.querySelector(".room")?.hidden === true, null, 5000);
  const count = seen.asked.length;
  await page.tap(".room-go");
  const again = await until(page, () => document.querySelector(".room")?.hidden === false && document.querySelector(".room").dataset.state === "ready", null, 5000);
  await page.waitForTimeout(500);
  check(`${label}: Back to the picture puts it back, and In your room shows the model again at once, asking for nothing (${seen.asked.length - count} asked)`,
    back && again && seen.asked.length === count);
  const { wrong, meant } = trouble(seen, await refusedBy(page));
  check(`${label}: no script error, nothing the page's policy refused (${wrong.join("; ") || "none"}; `
    + `<model-viewer>'s meshopt decoder refused as meant: ${meant} of at most 2)`, wrong.length === 0 && meant <= 2);
  await context.close();
}

/// A computer: not offered, nothing asked.
async function notOffered(browser, viewport) {
  const label = `computer-${viewport.width}x${viewport.height}`;
  console.log(`\n${label}`);
  const { context, page, seen } = await visit(browser, { viewport, label });
  await page.waitForTimeout(2000);
  const xr = await page.evaluate(async () => ({ xr: Boolean(navigator.xr),
    ar: navigator.xr ? await navigator.xr.isSessionSupported("immersive-ar").catch(() => "refused") : null }));
  const at = await offerOf(page);
  const asked = seen.asked.filter((url) => ROOM_ASKED.test(url));
  check(`${label}: In your room is not offered (WebXR ${xr.xr ? `here, immersive AR ${xr.ar}` : "not here"}), and nothing of it asked (${asked.length})`,
    !at.go && asked.length === 0);
  const refused = await refusedBy(page);
  check(`${label}: no script error, nothing the page's policy refused (${[...seen.errors, ...refused].join("; ") || "none"})`,
    seen.errors.length === 0 && refused.length === 0);
  await shoot(page, label);
  await context.close();
}

/// A model over the size: said no before a shape or the viewer is asked.
async function tooBig(browser) {
  console.log("\nandroid, a model over the size");
  const { context, page, seen } = await visit(browser, ANDROID);
  await context.route(/\/room\.json(\?|$)/, async (route) => {
    // The plan the page would be given, made as the server makes it.
    const asked = new URL(route.request().url());
    const plan = remote ? await (await route.fetch()).json()
      : JSON.parse((await stand.serverPage(path.join(root, "api"), asked.pathname)).html);
    plan.shape_triangles = Math.ceil((MOST_BYTES * 1.25) / 40);
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(plan) });
  });
  if (!await until(page, () => Boolean(document.querySelector(".room-go")), null, 6000)) {
    check("too big: In your room is offered, to tap", false);
    await context.close();
    return;
  }
  await page.tap(".room-go");
  const said = await until(page, () => document.querySelector(".room")?.dataset.state === "refused", null, 30000);
  await page.waitForTimeout(800);
  const words = await page.evaluate(() => document.querySelector(".room-said")?.textContent || "");
  const shapes = seen.asked.filter((url) => /\.lbm(\?|$)/.test(url) && !/part-pictures/.test(url));
  const viewer = seen.asked.filter((url) => VIEWER_ASKED.test(url));
  check(`too big: the page says so ("${words}"), before any shape (${shapes.length}) or <model-viewer> (${viewer.length}) is asked for`,
    said && /too big/.test(words) && shapes.length === 0 && viewer.length === 0);
  await shoot(page, "android-too-big");
  await context.close();
}

/// The page's first load on [device]: requests and bytes, and none of the room's.
async function firstLoad(browser, device, site) {
  const { context, page, seen } = await visit(browser, device, site);
  await page.waitForTimeout(1500);
  const result = { requests: seen.asked.length, bytes: seen.bytes, zipped: seen.zipped, room: seen.asked.filter((url) => ROOM_ASKED.test(url)).length,
    names: seen.asked.map((url) => new URL(url).pathname).sort() };
  await context.close();
  return result;
}

const browser = await launch({ signedOut: true });
try {
  for (const viewport of [{ width: 1280, height: 720 }, { width: 1400, height: 900 }]) await notOffered(browser, viewport);
  for (const device of [ANDROID, IPHONE, IPAD]) await placed(browser, device);
  await tooBig(browser);
  if (before && !remote) {
    console.log("\nthe page's first load, before and after");
    for (const device of [ANDROID, { viewport: { width: 1280, height: 720 }, label: "computer" }]) {
      const was = await firstLoad(browser, device, before);
      const now = await firstLoad(browser, device, root);
      const added = now.names.filter((name, at) => name !== was.names[at]);
      console.log(`        ${device.label}: ${was.requests} requests, ${(was.bytes / 1024).toFixed(1)} KB (${(was.zipped / 1024).toFixed(1)} KB gzipped) before;`
        + ` ${now.requests}, ${(now.bytes / 1024).toFixed(1)} KB (${(now.zipped / 1024).toFixed(1)} KB gzipped) after: ${now.bytes - was.bytes >= 0 ? "+" : ""}${now.bytes - was.bytes} bytes,`
        + ` ${now.zipped - was.zipped >= 0 ? "+" : ""}${now.zipped - was.zipped} gzipped`);
      if (out) writeFileSync(path.join(out, `first-load-${device.label}.json`), JSON.stringify({ before: was, after: now }, null, 1));
      check(`first load, ${device.label}: the same ${now.requests} requests as before (${was.requests}), none of the room's (${now.room})${added.length ? `; differs: ${added.join(", ")}` : ""}`,
        now.requests === was.requests && now.room === 0 && added.length === 0);
    }
  }
} finally {
  await browser.close();
}
console.log(`\narview_flow: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
