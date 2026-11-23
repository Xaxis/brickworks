// Post it elsewhere (unit postkit): a model's designer makes a kit for each
// place it is posted to, from Share's sheet on its page, in a real browser
// (Chromium on SwiftShader), and nothing is posted anywhere.
//
//   node tools/web/postkit_flow.mjs [--out=DIR] [--widths=1280,390]
//     [--places=legomoc,instagram] [--quick]   (just those kits; --quick
//     leaves out 1 and 4)
//
// Nothing leaves this machine: the pages are made by this checkout's api/,
// every API call is answered by design_stand_in.mjs (as model_page_flow.mjs
// does with no --url), and the model is LDraw's 10183-1 (558 pieces), its
// parts' geometry this checkout's own. Signed in as the stand-in's Sam, on
// their Harbour Tram's page:
//
//   1. Post it elsewhere shows in Share's sheet for its designer alone:
//      signed out, and signed in as somebody else, it stays hidden, and the
//      kit's code is never loaded.
//   2. At 1280 (and 390, a phone: touch, a coarse pointer), each place's
//      kit: r/legomoc, r/lego, Instagram, LEGO® Ideas, Rebrickable, Flickr,
//      made in 20 s or less at 1280 and 60 s or less at 390 for the
//      558-piece model (from the press to <html data-kit="made">); each
//      rule its place has checked, and only the rules this browser cannot
//      keep failing (Instagram's MP4, where Chromium records WebM); its
//      zip saved, under 50 MB, read back whole (every file, post.txt with
//      every rule's page), and every caption with the model's link.
//   3. Egress: making the kits asks for nothing the page's own View in 3D
//      does not: the scene and its parts' geometry, each once, then
//      nothing for every kit after the first; never the model's file, its
//      big picture, its parts CSV or its clip. The site's own drawing code
//      (/turntable-worker.js), once, as the page's clip has it.
//   4. With a picture on the page, it leads the Reddit and Ideas kits, and
//      LEGO® Ideas' main picture has nothing drawn on it but the model and
//      its ground (what the easel drew), Instagram's cover the wordmark.
//   5. The keyboard: Share, then Tab to a place, Enter makes its kit, its
//      heading takes the focus, Escape closes it and gives the focus back
//      to the place's button. Pictures at 1280 light and dark, and 390.
//
// Pictures in --out: sheet_<width>_<theme>.png, kit_<place>_<width>_<theme>.png,
// and each kit's zip; timings.json with each kit's time.
import { launch } from "./browser.mjs";
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
// The stand-in's site at a secure origin, as the site's own is: a turn is
// recorded with WebCodecs, which a page served over plain http has not.
// Routed by Playwright, so no certificate is asked for.
process.env.STAND_IN_ORIGIN = "https://design.test";
const stand = await import("./design_stand_in.mjs");
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const out = path.resolve(String(args.out || "shots/postkit"));
mkdirSync(out, { recursive: true });
const widths = String(args.widths || "1280,390").split(",").map(Number);
const MODEL = "SamModel01";
const ALL = ["legomoc", "lego", "instagram", "ideas", "rebrickable", "flickr"];
const PLACES = args.places ? String(args.places).split(",").filter((one) => ALL.includes(one)) : ALL;
const quick = Boolean(args.quick);
const BOUND = { 1280: 20000, 390: 60000 };
const ZIP_MOST = 50 * 1024 * 1024;

stand.useModelFile(readFileSync(path.join(root, "vendor/omr/files/10183-1.mpd"), "utf8"));

let passed = 0;
let failed = 0;
const check = (what, ok, detail = "") => {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`  ${ok ? "PASS" : "FAIL"} ${what}${detail ? `: ${detail}` : ""}`);
};
const until = (page, test, arg, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const errors = [];
const timings = [];

const browser = await launch({ signedOut: true });

/// A context at [width] in [theme], signed in as Sam where [who] is
/// "sam", the site served by the stand-in; [picture], where given, the
/// bytes the page's picture of the model answers with.
async function contextFor(width, theme, who, picture = null) {
  const phone = width < 600;
  // No service worker: at a secure origin the site installs one, whose own
  // requests no route answers (homescreen_flow.mjs drives it).
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    acceptDownloads: true, serviceWorkers: "block", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api") });
  if (picture) {
    await context.route((url) => url.origin === stand.ORIGIN && url.pathname === `/m/${MODEL}.cutout.png`,
      (route) => route.fulfill({ status: 200, contentType: "image/jpeg", body: picture }));
  }
  await context.addInitScript(() => {
    window.__copied = [];
    try {
      Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText: async (t) => { window.__copied.push(String(t)); } } });
    } catch { /* as it is */ }
  });
  if (who) {
    const kept = stand.signedInStorage();
    await context.addInitScript(([session, access]) => {
      try {
        localStorage.setItem("brickworks.session", session);
        sessionStorage.setItem("brickworks.access", access);
      } catch { /* keeps nothing */ }
    }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
  }
  const page = await context.newPage();
  const label = `${width} ${theme} ${who || "out"}`;
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 240)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 240)}`);
    }
  });
  return { context, page };
}

/// What the page asked for while [act] ran: each request's address.
async function asked(context, act) {
  const urls = [];
  const heard = (request) => urls.push(request.url());
  context.on("request", heard);
  try {
    await act();
  } finally {
    context.off("request", heard);
  }
  return urls;
}

/// The share sheet opened from Share, by the keyboard.
async function openSheet(page) {
  await page.focus("[data-share]");
  await page.keyboard.press("Enter");
  return until(page, () => document.getElementById("share-sheet")?.open === true, null, 5000);
}

/// [place]'s kit made by pressing its button: {ms (the page's), wall, kit}.
async function makeKit(page, place, { keyboard = false } = {}) {
  await page.evaluate(() => { delete document.documentElement.dataset.kit; window.brickworksKit = null; });
  const started = Date.now();
  if (keyboard) {
    let found = false;
    for (let k = 0; k < 40 && !found; k++) {
      await page.keyboard.press("Tab");
      found = await page.evaluate((p) => document.activeElement?.dataset?.kit === p, place);
    }
    check(`${place}: its button is reached with Tab`, found);
    await page.keyboard.press("Enter");
  } else {
    await page.click(`#share-sheet [data-kit="${place}"]`);
  }
  const made = await until(page, () => ["made", "failed"].includes(document.documentElement.dataset.kit), null, 240000);
  const wall = Date.now() - started;
  const kit = await page.evaluate(() => window.brickworksKit);
  const how = await page.evaluate(() => document.documentElement.dataset.kit);
  check(`${place}: the kit is made`, made && how === "made", how || "nothing said");
  return { wall, kit };
}

/// The kit's zip, saved by pressing Save the kit: its path and bytes.
async function saveZip(page, place, width, theme) {
  const coming = page.waitForEvent("download", { timeout: 30000 });
  await page.click('#post-kit [data-take="zip"]');
  const download = await coming.catch(() => null);
  if (!download) return null;
  const file = path.join(out, `${place}_${width}_${theme}.zip`);
  await download.saveAs(file);
  return file;
}

/// What a zip holds, read by Python's zipfile: {names, bad, post, sizes}.
function readZip(file) {
  const said = execFileSync("python3", ["-I", "-c", [
    "import json, sys, zipfile",
    "z = zipfile.ZipFile(sys.argv[1])",
    "print(json.dumps({'names': z.namelist(), 'bad': z.testzip(), 'post': z.read('post.txt').decode('utf-8'),",
    "  'sizes': {i.filename: i.file_size for i in z.infolist()}}))",
  ].join("\n"), file], { encoding: "utf8" });
  return JSON.parse(said);
}

/// The rules a kit fails, by id.
const failing = (kit) => kit.checks.filter((one) => one.how === "fails").map((one) => one.id);

// ---------------------------------------------------------------------------
// 1. Its designer's alone.

console.log("1. for its designer alone");
// Signed out on Sam's model, and Sam on Robin's (the stand-in's MODEL_ID).
for (const [who, model] of quick ? [] : [["", MODEL], ["sam", stand.MODEL_ID]]) {
  const { context, page } = await contextFor(1280, "light", who);
  const code = [];
  page.on("request", (request) => { if (/\/post-(kit|rules)\.js$/.test(request.url())) code.push(request.url()); });
  await page.goto(`${stand.ORIGIN}/m/${model}`, { waitUntil: "load", timeout: 60000 });
  await page.waitForTimeout(2500);
  const hidden = await page.evaluate(() => document.getElementById("post-kits")?.hidden);
  const label = who ? "somebody else's model, signed in" : "signed out";
  check(`${label}: Post it elsewhere stays hidden`, hidden === true);
  check(`${label}: the kit's code is never asked for`, code.length === 0, code.join(", "));
  await context.close();
}

// ---------------------------------------------------------------------------
// 2, 3 and 5. Each kit, timed, its rules, its zip; what it asked for.

let largest = null;
for (const width of widths) {
  const theme = "light";
  console.log(`2. each kit at ${width}`);
  const { context, page } = await contextFor(width, theme, "sam");
  await page.goto(`${stand.ORIGIN}/m/${MODEL}`, { waitUntil: "load", timeout: 60000 });
  check(`${width}: Post it elsewhere shows for its designer`,
    await until(page, () => document.documentElement.dataset.postKits === "shown", null, 20000));
  // What its own View in 3D asks for, to hold the kits to.
  let viewAsked = [];
  if (width === widths[0]) {
    viewAsked = await asked(context, async () => {
      await page.click(".model-page .picture");
      check("its View in 3D draws the model", await until(page, () => document.querySelector(".view3d")?.dataset.state === "ready", null, 180000));
    });
    await page.keyboard.press("Escape");
    await page.reload({ waitUntil: "load" });
    check(`${width}: the page again, Post it elsewhere shown`,
      await until(page, () => document.documentElement.dataset.postKits === "shown", null, 20000));
  }
  // Its parts list, as a visitor scrolling to it has the page load it.
  await page.evaluate(() => document.getElementById("parts")?.scrollIntoView({ block: "start" }));
  check(`${width}: the page's parts list is drawn`, await until(page, () => document.documentElement.dataset.parts === "drawn", null, 30000));
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(1500);
  check(`${width}: Share opens its sheet from the keyboard`, await openSheet(page));
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out, `sheet_${width}_${theme}.png`) });
  const lbm = new Map();
  for (const [k, place] of PLACES.entries()) {
    let made = null;
    const urls = await asked(context, async () => { made = await makeKit(page, place, { keyboard: k === 0 }); });
    const { kit, wall } = made;
    if (!kit) continue;
    const clipping = await page.evaluate(() => document.documentElement.dataset.clip || "");
    timings.push({ width, place, ms: kit.ms, wall, zipBytes: kit.zipBytes, parts: kit.timing, clip: kit.clip, clipWhy: kit.clipWhy,
      pageClip: clipping });
    check(`${place} at ${width}: made in ${(kit.ms / 1000).toFixed(1)} s`, kit.ms <= BOUND[width],
      `bound ${BOUND[width] / 1000} s; the scene ${kit.timing?.load ?? "-"} ms, stills ${JSON.stringify(kit.timing?.stills || [])} ms, `
      + `the turn ${kit.timing?.turn ?? "-"} ms${kit.clip ? ` (${kit.clip.kind} drawn at ${kit.clip.drawnAt})` : ""}`
      + `${kit.clipWhy ? `, no turn: ${kit.clipWhy}` : ""}; the page's own clip ${clipping || "not asked"}`);
    if (k === 0) {
      check(`${place}: its heading has the focus`, await page.evaluate(() => document.activeElement?.id === "post-kit-h"));
    }
    // Only Instagram's MP4 may fail, where this browser records WebM.
    const fails = failing(kit);
    const expected = place === "instagram" && kit.clip?.kind === "webm" ? ["turn"] : [];
    check(`${place}: it keeps its rules`, JSON.stringify(fails) === JSON.stringify(expected),
      `fails ${fails.join(", ") || "none"}${kit.clip ? `; turn ${kit.clip.kind} ${kit.clip.width}x${kit.clip.height} ${kit.clip.ms} ms` : ""}`);
    check(`${place}: its words carry the model's link`, String(kit.words.words).includes(`/m/${MODEL}`));
    if (place === "instagram") {
      check("instagram: a 1080 x 1350 cover and a 1080 x 1920 turn of 15 s or less",
        kit.images[0]?.width === 1080 && kit.images[0]?.height === 1350 && kit.clip?.width === 1080 && kit.clip?.height === 1920
          && kit.clip.ms <= 15000);
    }
    // What it asked for: nothing but the scene and its parts' geometry,
    // each once, and each something its View in 3D asked for too.
    const ours = urls.filter((url) => !url.startsWith("blob:") && !url.startsWith("data:")
      && new URL(url).pathname !== "/turntable-worker.js");
    const scene = ours.filter((url) => new URL(url).pathname === `/m/${MODEL}/scene.json`);
    const geometry = ours.filter((url) => /\/storage\/v1\/object\/public\/parts\/[0-9a-f]+\.lbm$/.test(url));
    const other = ours.filter((url) => !scene.includes(url) && !geometry.includes(url));
    check(`${place}: it asks for nothing beyond the scene and its geometry`, other.length === 0, other.slice(0, 4).join(", "));
    for (const url of geometry) lbm.set(url, (lbm.get(url) || 0) + 1);
    if (k === 0) check(`${place}: the scene once`, scene.length === 1, `${scene.length}`);
    else check(`${place}: nothing more of the scene, kept from the first kit`, scene.length === 0 && geometry.length === 0,
      `${scene.length} scenes, ${geometry.length} parts`);
    if (viewAsked.length) {
      const strange = geometry.filter((url) => !viewAsked.includes(url));
      check(`${place}: every part's geometry is one its View in 3D loads`, strange.length === 0, strange.slice(0, 3).join(", "));
    }
    if (width === widths[0] && (place === "legomoc" || place === "instagram")) {
      await page.waitForTimeout(400);
      await page.screenshot({ path: path.join(out, `kit_${place}_${width}_${theme}.png`) });
    }
    const zip = await saveZip(page, place, width, theme);
    check(`${place}: its zip is saved`, Boolean(zip));
    if (zip) {
      const held = readZip(zip);
      const bytes = readFileSync(zip).length;
      check(`${place}: the zip is whole and under 50 MB`, held.bad === null && bytes < ZIP_MOST && bytes === kit.zipBytes,
        `${(bytes / 1048576).toFixed(1)} MB, ${held.names.length} files`);
      check(`${place}: it holds every file the kit made`, kit.files.every((file) => held.sizes[file.name] === file.bytes));
      check(`${place}: post.txt names every rule's page`, kit.checks.every((one) => held.post.includes(`(${one.page})`)));
      check(`${place}: taken, and said so`, await page.evaluate((p) => document.documentElement.dataset.kitTaken === `${p}:zip`, place));
      if (place === "flickr" && width === widths[0]) {
        const name = held.names.find((one) => one.endsWith(".jpg"));
        largest = execFileSync("python3", ["-I", "-c", "import sys, zipfile; sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read(sys.argv[2]))",
          zip, name], { maxBuffer: 64 * 1024 * 1024 });
      }
      if (place === "rebrickable") check("rebrickable: its parts CSV is in the zip", held.names.some((one) => one.endsWith("-parts-rebrickable.csv")));
    }
    await page.keyboard.press("Escape");
    const back = await until(page, (p) => !document.getElementById("post-kit")?.open
      && document.activeElement?.dataset?.kit === p, place, 3000);
    check(`${place}: Escape closes it, the focus back on its button`, back);
  }
  check(`${width}: each part's geometry asked for once at most`, [...lbm.values()].every((n) => n === 1), `${lbm.size} parts`);
  await context.close();
}

// ---------------------------------------------------------------------------
// 4. With a picture on its page, in the dark.

console.log("4. with a picture, light and dark");
if (quick) {
  console.log("  (left out: --quick)");
} else if (largest) {
  for (const theme of ["light", "dark"]) {
    const { context, page } = await contextFor(1280, theme, "sam", largest);
    await page.goto(`${stand.ORIGIN}/m/${MODEL}`, { waitUntil: "load", timeout: 60000 });
    await until(page, () => document.documentElement.dataset.postKits === "shown", null, 20000);
    await until(page, () => (document.querySelector(".model-page .picture img")?.naturalWidth || 0) > 64, null, 20000);
    await openSheet(page);
    if (theme === "dark") await page.screenshot({ path: path.join(out, `sheet_1280_${theme}.png`) });
    for (const place of theme === "light" ? ["ideas", "legomoc", "instagram"] : ["legomoc"]) {
      const { kit } = await makeKit(page, place);
      if (!kit) continue;
      if (place !== "instagram") {
        check(`${place}: the page's picture leads`, kit.images[0]?.width === 2560 && kit.images.length === 7,
          `${kit.images.length} pictures, the first ${kit.images[0]?.width}`);
      }
      if (place === "ideas") {
        const main = kit.images[0]?.drawn;
        check("ideas: nothing but the model and its ground is drawn on its main picture",
          JSON.stringify(main) === JSON.stringify({ layers: ["backdrop", "model"], text: [] }), JSON.stringify(main));
        check("ideas: no rule fails", failing(kit).length === 0, failing(kit).join(", "));
      }
      if (place === "instagram") {
        check("instagram: its cover carries the wordmark", JSON.stringify(kit.images[0]?.drawn?.text) === '["brickworks.diy"]');
      }
      await page.waitForTimeout(400);
      await page.screenshot({ path: path.join(out, `kit_${place}_1280_${theme}.png`) });
      await page.keyboard.press("Escape");
    }
    await context.close();
  }
} else {
  check("the Flickr kit's picture, to put on the page", false);
}

await browser.close();
writeFileSync(path.join(out, "timings.json"), `${JSON.stringify(timings, null, 1)}\n`);
for (const one of timings) console.log(`  time ${one.place} at ${one.width}: ${(one.ms / 1000).toFixed(1)} s (${(one.wall / 1000).toFixed(1)} s to the flow), zip ${(one.zipBytes / 1048576).toFixed(1)} MB`);
check("no script errors and nothing refused by the page's policy", errors.length === 0, errors.slice(0, 4).join(" | "));
console.log(`postkit_flow: ${passed} passed, ${failed} failed; pictures in ${out}`);
process.exit(failed ? 1 : 0);
