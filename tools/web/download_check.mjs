// Does the download page offer each system its own build, under the site's rules?
//
//   node tools/web/download_check.mjs                     web/ with its own releases.json
//   node tools/web/download_check.mjs --manifest=FILE     ...serving FILE as releases.json
//                                                         (tools/release.py manifest --local --out=FILE)
//   node tools/web/download_check.mjs --url=https://brickworks.diy/download.html
//   --shots=DIR                                           a screenshot per system
//
// Locally the page is served with a content security policy at least as
// strict as the one tools/deploy.sh sends: scripts and connections to the
// page's own origin only, no inline script. A page that works here works
// there; one that reached for GitHub's API, or put its logic in an inline
// script, fails here the way it would fail live.
//
// Each system is a real browser told it is that system the way a browser
// says so: the user agent, navigator.platform and the client hints, through
// the DevTools protocol. Playwright's userAgent option changes only the
// first, and the page reads the other two first, so a "Mac" would have been
// offered the Linux build and the check would have been checking nothing.
import { launch } from "./browser.mjs";
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
  ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml" };

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
let manifest = null;
if (!target) {
  const root = resolve("web");
  const replacement = args.manifest ? resolve(args.manifest) : null;
  server = createServer(async (request, response) => {
    const path = new URL(request.url, "http://x").pathname;
    const file = path === "/releases.json" && replacement ? replacement
      : join(root, path === "/" ? "index.html" : path.slice(1));
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
  manifest = JSON.parse(await readFile(replacement || join(root, "releases.json"), "utf8"));
} else {
  // The manifest the live page reads, so its offers are checked against it.
  const response = await fetch(new URL("releases.json", target), { cache: "no-store" });
  if (!response.ok) {
    console.log(`  FAIL  releases.json beside the page answered ${response.status}`);
    process.exit(1);
  }
  manifest = await response.json();
}

const browser = await launch();
const problems = [];
if (args.shots) await mkdir(args.shots, { recursive: true });

for (const system of SYSTEMS) {
  const context = await browser.newContext({ viewport: { width: system.width, height: 900 } });
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

await browser.close();
if (server) server.close();
if (problems.length) {
  for (const p of problems) console.log(`  FAIL  ${p}`);
  process.exit(1);
}
console.log("  the download page offers each system its own build");
