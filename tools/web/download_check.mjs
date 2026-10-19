// Does the download page offer each system its own build, under the site's rules?
//
//   node tools/web/download_check.mjs                     web/ with its own releases.json
//   node tools/web/download_check.mjs --manifest=FILE     ...serving FILE as releases.json
//                                                         (tools/release.py manifest --local --out=FILE)
//   node tools/web/download_check.mjs --url=https://brickworks.diy/download
//   VERCEL_BYPASS=… node tools/web/download_check.mjs --url=<a preview>/download
//   --shots=DIR                                           a screenshot per system
//
// Locally the page is served with a content security policy at least as
// strict as the one tools/deploy.sh sends: scripts and connections to the
// page's own origin only, no inline script. A page that works here works
// there; one that reached for GitHub's API, or put its logic in an inline
// script, fails here the way it would fail live.
//
// And the gallery, /gallery (web/gallery.html), under the same policy: its
// script draws the listed models from /api/share?op=list, a page at a time.
// Locally the list is a made-up one of 26 models — one with no picture, one
// whose name is markup — so the check sees two pages, Show more, and a name
// that must be shown as the text it is; against a deployment, what it lists.
// No error in the console (a refused script or fetch is one), and no
// sideways scroll on a phone or a laptop. --shots gets gallery-phone.png and
// gallery-laptop.png. Locally the made-up list answers a search and a kind
// as the real one does, so the check also types in the search box, picks a
// kind, finds nothing and clears it, and opens an address asking for a kind
// there is not: the address says each question, and the page the answer.
//
// Each system is a real browser told it is that system the way a browser
// says so: the user agent, navigator.platform and the client hints, through
// the DevTools protocol. Playwright's userAgent option changes only the
// first, and the page reads the other two first, so a "Mac" would have been
// offered the Linux build and the check would have been checking nothing.
import { launch, allPictures } from "./browser.mjs";
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { resolve, join, extname } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));

const CSP = "default-src 'self'; script-src 'self'; connect-src 'self'; "
  + "style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; "
  + "base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript",
  ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml",
  ".css": "text/css", ".webp": "image/webp" };

const CHROME = "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0";
const brands = [{ brand: "Chromium", version: "130" }, { brand: "Not?A_Brand", version: "99" }];
const SYSTEMS = [
  { label: "linux", width: 1280, ua: `Mozilla/5.0 (X11; Linux x86_64) ${CHROME} Safari/537.36`,
    platform: "Linux x86_64", hints: { platform: "Linux", mobile: false }, want: "linux" },
  { label: "macos", width: 1280, ua: `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ${CHROME} Safari/537.36`,
    platform: "MacIntel", hints: { platform: "macOS", mobile: false }, want: "macos" },
  { label: "windows", width: 1280, ua: `Mozilla/5.0 (Windows NT 10.0; Win64; x64) ${CHROME} Safari/537.36`,
    platform: "Win32", hints: { platform: "Windows", mobile: false }, want: "windows" },
  { label: "phone", width: 390, ua: `Mozilla/5.0 (Linux; Android 14; Pixel 8) ${CHROME} Mobile Safari/537.36`,
    platform: "Linux armv8l", hints: { platform: "Android", mobile: true }, want: "" },
];
const NAMES = { linux: "Linux", macos: "macOS", windows: "Windows" };
const ENDS = { linux: "-linux-x86_64.AppImage", macos: "-macos-universal.zip",
  windows: "-windows-x86_64.zip" };

let server = null;
let target = args.url;
// A protected preview lets this check in with the bypass; production ignores
// it. And without Vercel's preview toolbar, whose script the site's security
// policy rightly refuses: it is injected for a browser that does not say it is
// headless, as this one says it is Chrome on each system, and is never on the
// real site.
const bypass = process.env.VERCEL_BYPASS
  ? { "x-vercel-protection-bypass": process.env.VERCEL_BYPASS, "x-vercel-skip-toolbar": "1" } : {};
let manifest = null;
// The gallery's made-up list, for a check with no deployment behind it.
const HOSTILE = `<img src=x onerror="document.title='owned'">Hostile & "named"`;
const LISTED = Array.from({ length: 26 }, (_, n) => ({
  id: `Gal${String(n).padStart(7, "0")}`,
  name: n === 0 ? HOSTILE : `Listed model ${n + 1}`,
  author: n % 3 === 0 ? null : `Builder ${n}`,
  parts: 12 + n * 37,
  image: n === 1 ? null : "yes",
  kind: n % 2 ? "space" : "castle",
  views: 26 - n,
}));
const KINDS = [{ id: "castle", label: "Castles and fantasy" }, { id: "space", label: "Space" }];
let galleryTarget = "";
if (!target) {
  const root = resolve("web");
  const replacement = args.manifest ? resolve(args.manifest) : null;
  const picture = await readFile(join(root, "share.png"));
  server = createServer(async (request, response) => {
    const url = new URL(request.url, "http://x");
    const path = url.pathname;
    const headers = { "Content-Security-Policy": CSP, "X-Content-Type-Options": "nosniff",
      "Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp",
      "Cross-Origin-Resource-Policy": "same-origin" };
    if (path === "/api/share" && url.searchParams.get("op") === "list") {
      const page = Number(url.searchParams.get("page") || 1);
      const words = (url.searchParams.get("q") || "").toLowerCase();
      const kind = url.searchParams.get("kind") || "";
      if (kind && !KINDS.some((k) => k.id === kind)) {
        response.writeHead(400, { ...headers, "Content-Type": "application/json" });
        return response.end(JSON.stringify({ error: "kind is one of castle, space" }));
      }
      const found = LISTED.filter((m) => (!words || m.name.toLowerCase().includes(words))
        && (!kind || m.kind === kind));
      const models = found.slice((page - 1) * 24, page * 24).map((m) => ({ ...m,
        url: `http://x/m/${m.id}`, image: m.image ? `http://x/m/${m.id}.png` : null }));
      response.writeHead(200, { ...headers, "Content-Type": "application/json" });
      return response.end(JSON.stringify({ page, per_page: 24, more: page * 24 < found.length, models,
        kinds: KINDS, sizes: [{ id: "small", label: "Small, under 200 parts" }],
        sorts: [{ id: "newest", label: "Newest" }, { id: "views", label: "Most viewed" }] }));
    }
    if (/^\/m\/[A-Za-z0-9]{10}\.png$/.test(path)) {
      response.writeHead(200, { ...headers, "Content-Type": "image/png" });
      return response.end(picture);
    }
    const file = path === "/releases.json" && replacement ? replacement
      : join(root, path === "/" ? "index.html" : path === "/gallery" ? "gallery.html" : path.slice(1));
    try {
      const body = await readFile(file);
      response.writeHead(200, { "Content-Type": TYPES[extname(file)] || "application/octet-stream",
        "Content-Security-Policy": CSP, "X-Content-Type-Options": "nosniff",
        "Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp",
        "Cross-Origin-Resource-Policy": "same-origin" });
      response.end(body);
    } catch {
      response.writeHead(404).end();
    }
  });
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  target = `http://127.0.0.1:${server.address().port}/download.html`;
  galleryTarget = `http://127.0.0.1:${server.address().port}/gallery`;
  manifest = JSON.parse(await readFile(replacement || join(root, "releases.json"), "utf8"));
} else {
  // The manifest the live page reads, so its offers are checked against it —
  // asked past the CDN's cache. Read seconds after a release's deploy, the
  // cache still handed this check 0.1.0 while the page had 0.2.0, and every
  // offer failed for being right.
  const response = await fetch(new URL(`releases.json?fresh=${Date.now()}`, target),
    { cache: "no-store", headers: bypass });
  if (!response.ok) {
    console.log(`  FAIL  releases.json beside the page answered ${response.status}`);
    process.exit(1);
  }
  manifest = await response.json();
}

const browser = await launch({ signedOut: true });  // a page of the site, not the app
const problems = [];
if (args.shots) await mkdir(args.shots, { recursive: true });

for (const system of SYSTEMS) {
  const context = await browser.newContext({ viewport: { width: system.width, height: 900 },
    extraHTTPHeaders: args.url ? bypass : {} });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send("Emulation.setUserAgentOverride", {
    userAgent: system.ua, platform: system.platform,
    userAgentMetadata: { brands, fullVersion: "130.0.0.0", platformVersion: "", architecture: "x86",
      model: "", ...system.hints } });
  const said = [];
  page.on("console", (m) => { if (m.type() === "error") said.push(m.text()); });
  page.on("pageerror", (e) => said.push(String(e)));
  const response = await page.goto(target, { waitUntil: "load", timeout: 45000 });
  if (response && !response.ok()) {
    problems.push(`${system.label}: the page answered ${response.status()}`);
    await context.close();
    continue;
  }
  await page.waitForFunction(() => document.documentElement.dataset.os !== undefined
    && [...document.querySelectorAll("#offer, #offer-none, #none-yet, #broken")].some((e) => !e.hidden),
    null, { timeout: 15000 }).catch(() => {});

  const seen = await page.evaluate(() => {
    const shown = (sel) => { const e = document.querySelector(sel); return !!e && !e.hidden; };
    const button = document.getElementById("offer-button");
    const selected = document.querySelector('.tabs button[aria-selected="true"]');
    const panel = [...document.querySelectorAll("[data-panel]")].find((p) => !p.hidden);
    return {
      detected: document.documentElement.dataset.os,
      offer: shown("#offer"), none: shown("#offer-none"), noneYet: shown("#none-yet"),
      broken: shown("#broken"),
      button: button ? button.textContent : "", href: button ? button.getAttribute("href") : "",
      meta: (document.getElementById("offer-meta") || {}).textContent || "",
      tab: selected ? selected.dataset.os : "",
      panelText: panel ? panel.innerText : "",
      macWarning: shown('[data-unsigned="macos"]'), winWarning: shown('[data-unsigned="windows"]'),
      scrollW: document.documentElement.scrollWidth, clientW: document.documentElement.clientWidth,
    };
  });

  const release = manifest ? (manifest.releases || []).find((r) => r.version === manifest.latest) : null;
  const fail = (text) => problems.push(`${system.label}: ${text}`);
  if (said.length) fail(`the console said: ${said.slice(0, 3).join(" | ")}`);
  if (seen.scrollW > seen.clientW + 1) fail(`scrolls sideways, ${seen.scrollW}px in ${seen.clientW}px`);
  if (seen.broken) fail("the manifest did not load");
  if (manifest && !release) {
    if (!seen.noneYet) fail("no release in the manifest, and the page does not say so");
  } else if (system.want) {
    const file = release ? release.files.find((f) => f.os === system.want && f.name.endsWith(ENDS[system.want])) : null;
    if (seen.detected !== system.want) fail(`took it for ${seen.detected}`);
    if (!seen.offer) fail("offers nothing");
    if (seen.button !== `Download for ${NAMES[system.want]}`) fail(`the button says "${seen.button}"`);
    if (!seen.href.endsWith(ENDS[system.want])) fail(`the button fetches ${seen.href}`);
    if (file && seen.href !== file.url) fail(`the button is not the manifest's url for ${file.name}`);
    if (release && !seen.meta.includes(release.version)) fail(`the offer does not say ${release.version}`);
    if (file && !seen.panelText.includes(file.sha256)) fail("its panel does not show the SHA-256");
    if (seen.tab !== system.want) fail(`the ${seen.tab} tab is the one selected`);
    if (file && file.os === "macos" && seen.macWarning === Boolean(file.notarized)) {
      fail("the Gatekeeper steps do not match whether the app is notarised");
    }
    if (file && file.os === "windows" && seen.winWarning === (file.signed === true)) {
      fail("the SmartScreen steps do not match whether the app is signed");
    }
  } else {
    if (seen.offer) fail(`a phone was offered ${seen.button}`);
    if (!seen.none) fail("a phone is not told the desktop builds are for a computer");
  }

  // The others one click away.
  if (release) {
    for (const os of Object.keys(NAMES).filter((o) => o !== system.want)) {
      await page.click(`#tab-${os}`);
      const text = await page.evaluate((o) => document.getElementById(`panel-${o}`).hidden
        ? "" : document.getElementById(`panel-${o}`).innerText, os);
      const file = release.files.find((f) => f.os === os);
      if (!file || !text.includes(file.name)) fail(`one click on ${NAMES[os]} does not show ${file && file.name}`);
    }
    if (system.want) await page.click(`#tab-${system.want}`);
  }

  console.log(`  ${system.label.padEnd(8)} took it for ${seen.detected || "no desktop"}: `
    + (seen.offer ? `"${seen.button}" -> ${seen.href.split("/").pop()}` : seen.noneYet
      ? "no release yet" : "no offer") + (seen.offer ? `  (${seen.meta})` : ""));
  if (args.shots) {
    const path = join(args.shots, `download-${system.label}.png`);
    await page.screenshot({ path, fullPage: true });
    console.log(`           ${path}`);
  }
  await context.close();
}

// -- the gallery -------------------------------------------------------------
if (!galleryTarget) galleryTarget = new URL("/gallery", target).href;
for (const [label, width] of [["phone", 390], ["laptop", 1280]]) {
  const context = await browser.newContext({ viewport: { width, height: 900 },
    extraHTTPHeaders: args.url ? bypass : {} });
  const page = await context.newPage();
  const said = [];
  page.on("console", (m) => { if (m.type() === "error") said.push(m.text()); });
  page.on("pageerror", (e) => said.push(String(e)));
  const fail = (text) => problems.push(`gallery at ${label} width: ${text}`);
  const response = await page.goto(galleryTarget, { waitUntil: "load", timeout: 45000 });
  if (!response || !response.ok()) {
    fail(`the page answered ${response && response.status()}`);
    await context.close();
    continue;
  }
  await page.waitForFunction(() => document.documentElement.dataset.gallery, null, { timeout: 20000 }).catch(() => {});
  const look = () => page.evaluate(() => ({
    state: document.documentElement.dataset.gallery || "",
    cards: [...document.querySelectorAll("#models a.model")].map((a) => ({
      href: a.getAttribute("href"), name: a.querySelector("b").textContent,
      about: a.querySelector("span").textContent, img: (a.querySelector("img") || {}).src || "" })),
    more: !document.getElementById("more").hidden,
    empty: !document.getElementById("empty").hidden,
    stray: document.querySelectorAll('#models img[src="x"], #models img:not([src*="/m/"])').length,
    title: document.title,
    scrollW: document.documentElement.scrollWidth, clientW: document.documentElement.clientWidth,
    broken: [...document.images].filter((i) => i.complete && !i.naturalWidth).map((i) => i.src),
  }));
  await allPictures(page);
  let seen = await look();
  if (seen.state !== "ready") fail(`the list did not load (${seen.state || "nothing said"})`);
  if (!args.url) {
    if (seen.cards.length !== 24 || !seen.more) fail(`the first page is ${seen.cards.length} cards, Show more ${seen.more ? "shown" : "hidden"}`);
    const first = seen.cards[0] || {};
    if (first.name !== HOSTILE || seen.stray || seen.title === "owned") fail("a name that is markup was not shown as text");
    if (first.href !== "/m/Gal0000000" || first.about !== "12 parts") fail(`the first card is ${JSON.stringify(first)}`);
    if ((seen.cards[1] || {}).img) fail("a model with no picture was given one");
    if ((seen.cards[2] || {}).about !== "86 parts, by Builder 2") fail(`a credit reads "${(seen.cards[2] || {}).about}"`);
    await page.click("#more");
    await page.waitForFunction(() => document.querySelectorAll("#models a.model").length > 24, null, { timeout: 10000 }).catch(() => {});
    await page.waitForTimeout(300);
    seen = await look();
    if (seen.cards.length !== 26 || seen.more) fail(`after Show more, ${seen.cards.length} cards, Show more ${seen.more ? "still shown" : "gone"}`);

    // The question: typed, picked, found nothing, cleared; each in the address.
    // Answered once the address says the question and the list is drawn.
    const answered = async (where) => {
      await page.waitForFunction((want) => location.pathname + location.search === want
        && (document.documentElement.dataset.gallery === "ready"
          || document.documentElement.dataset.gallery === "broken"), where, { timeout: 10000 }).catch(() => {});
      await page.waitForTimeout(200);
      return { ...(await look()), where: await page.evaluate(() => location.pathname + location.search),
        nothing: await page.evaluate(() => !document.getElementById("nothing").hidden) };
    };
    if (label === "phone") await page.click("#filters summary");
    await page.fill("#q", "model 2");
    let asked = await answered("/gallery?q=model+2");
    if (asked.where !== "/gallery?q=model+2" || asked.cards.length !== 8
        || !asked.cards.every((c) => c.name.includes("model 2"))) {
      fail(`typing "model 2": ${asked.where}, ${asked.cards.length} cards`);
    }
    await page.selectOption("#kind", "space");
    asked = await answered("/gallery?q=model+2&kind=space");
    if (asked.where !== "/gallery?q=model+2&kind=space" || asked.cards.length !== 5) {
      fail(`then Space: ${asked.where}, ${asked.cards.length} cards`);
    }
    await page.fill("#q", "no such model");
    asked = await answered("/gallery?q=no+such+model&kind=space");
    if (asked.cards.length !== 0 || !asked.nothing || asked.empty) fail("a search that finds nothing does not say so");
    await page.click("#clear");
    asked = await answered("/gallery");
    if (asked.where !== "/gallery" || asked.cards.length !== 24) fail(`cleared: ${asked.where}, ${asked.cards.length} cards`);
    if (args.shots) await page.screenshot({ path: join(args.shots, `gallery-${label}-cleared.png`) });
    // The one answer here that is meant to be refused, which the browser
    // logs as a failed load; anything else said meanwhile still counts.
    const before = said.length;
    await page.goto(`${galleryTarget}?kind=nope&q=x`, { waitUntil: "load" });
    asked = await answered("/gallery");
    const meanwhile = said.splice(before).filter((line) => !/status of 400/.test(line));
    said.push(...meanwhile);
    if (asked.where !== "/gallery" || asked.cards.length !== 24 || asked.state !== "ready") {
      fail(`an address asking for a kind there is not: ${asked.where}, ${asked.cards.length} cards, ${asked.state}`);
    }
    await page.goto(`${galleryTarget}?kind=castle`, { waitUntil: "load" });
    asked = await answered("/gallery?kind=castle");
    const picked = await page.evaluate(() => document.getElementById("kind").value);
    if (picked !== "castle" || asked.cards.length !== 13) fail(`?kind=castle: ${picked}, ${asked.cards.length} cards`);
  } else if (!seen.cards.length && !seen.empty) {
    fail("neither cards nor the empty gallery's words");
  }
  if (said.length) fail(`the console said: ${said.slice(0, 3).join(" | ")}`);
  if (seen.scrollW > seen.clientW + 1) fail(`scrolls sideways, ${seen.scrollW}px in ${seen.clientW}px`);
  if (seen.broken.length) fail(`broken pictures: ${seen.broken.slice(0, 3).join(", ")}`);
  console.log(`  gallery  ${label}: ${seen.cards.length} cards${seen.empty ? " (nothing listed)" : ""}`
    + (seen.cards[0] ? `, first "${seen.cards[0].name.slice(0, 40)}"` : ""));
  if (args.shots) {
    const path = join(args.shots, `gallery-${label}.png`);
    await page.screenshot({ path, fullPage: true });
    console.log(`           ${path}`);
  }
  await context.close();
}

await browser.close();
if (server) server.close();
if (problems.length) {
  for (const p of problems) console.log(`  FAIL  ${p}`);
  process.exit(1);
}
console.log("  the download page offers each system its own build");
