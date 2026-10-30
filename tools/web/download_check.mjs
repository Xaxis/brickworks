// Does the download page offer each system its own build, under the site's rules?
//
//   node tools/web/download_check.mjs                     web/ with its own releases.json
//   node tools/web/download_check.mjs --manifest=FILE     ...serving FILE as releases.json
//                                                         (tools/release.py manifest --local --out=FILE)
//   node tools/web/download_check.mjs --url=https://brickworks.diy/download
//   VERCEL_BYPASS=… node tools/web/download_check.mjs --url=<a preview>/download
//   --shots=DIR                                           a screenshot per system
//   --port=N                                              serve web/ on N (default: any free)
//
// Each computer is offered its own build as the page's one primary button,
// with the manifest's url, version and size; the first launch's steps and
// the checksums folded away until asked for, then right for that build
// (the Gatekeeper and SmartScreen steps only while it is unsigned); at most
// 150 words before anything is opened. A phone is told the desktop app is
// for a computer and offered the web app first, a desktop file only once it
// chooses a system. From every view each other system is one click away,
// and with everything opened nothing runs past the edge at 1280 or 390 px.
// What is new is three or four lines, this release's own, and the page's
// every link answers (the owner found the page broken and "way too
// verbose", 2026-10-20).
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
// whose name is markup — so the check sees two pages and a name that must
// be shown as the text it is; against a deployment, what it lists. The
// first page is drawn with Show more; the next comes by itself where Show
// more was within a screen under the window (locally at 1280), else when
// it is pressed (at 390), and locally Show more is then gone. A deployment
// that lists more than a page is paged the same way.
// No error in the console (a refused script or fetch is one), and no
// sideways scroll on a phone or a laptop. --shots gets gallery-phone.png and
// gallery-laptop.png. Locally the made-up list answers a search and a kind
// as the real one does, so the check also types in the search box, picks a
// kind, finds nothing and clears it, and opens an address asking for a kind
// there is not: the address says each question, and the page the answer.
//
// And downloads gated by the plan (docs/PLANS.md, unit U5), locally only: a
// deployment's billing is off until the owner turns it on, and then its
// files are the plan's to give. The page asks /api/plans?op=download
// whether downloads are gated; here it is answered "no" for every view
// above (the public links, as always), then "yes" for a Linux visitor whose
// plan has no desktop (a click is refused in the server's words, with the
// way to Pro, and goes nowhere) and for one whose plan has it (a click goes
// to the short-lived address the route gives).
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

// The visit counter's script is the one thing from elsewhere the site lets
// in (tools/deploy.sh); the browser answers it here (browser.mjs
// quietCounter). Refused, every page logged it and this check failed on all
// six views from the day it was added.
const CSP = "default-src 'self'; script-src 'self' https://overlook.technology; "
  + "connect-src 'self' https://overlook.technology; "
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
// As the page says a size.
const megabytes = (bytes) => (bytes >= 1e9 ? (bytes / 1e9).toFixed(1) + " GB"
  : (bytes / 1e6).toFixed(bytes >= 1e8 ? 0 : 1) + " MB");

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
// How the stand-in /api/plans answers a download: null, not gated; "free",
// refused; "pro", the short-lived address.
let gatedAs = null;
const SIGNED_PATH = "/signed-download-for-the-check";
const PRO_WORDS = "The desktop app comes with Pro. The web app is free, in any browser.";
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
    // The front's shelves (a pick, small builds) are the discovery flow's to
    // check: empty here, so the list below them is what is judged. Unanswered,
    // the gallery logged a 404 for them on every load.
    if (path === "/api/share" && url.searchParams.get("op") === "shelves") {
      response.writeHead(200, { ...headers, "Content-Type": "application/json" });
      return response.end(JSON.stringify({ pick: null,
        small: { size: "small", label: "Small, under 200 parts", most: 200, models: [], more: false } }));
    }
    if (path === "/api/plans" && url.searchParams.get("op") === "download") {
      const json = (status, body) => {
        response.writeHead(status, { ...headers, "Content-Type": "application/json" });
        return response.end(JSON.stringify(body));
      };
      if (!url.searchParams.get("file")) return json(200, { gated: gatedAs !== null });
      if (gatedAs === "pro") return json(200, { url: SIGNED_PATH });
      return json(403, { error: PRO_WORDS, pro: "/plans" });
    }
    if (path === SIGNED_PATH) {
      response.writeHead(200, { ...headers, "Content-Type": "application/octet-stream" });
      return response.end("the file");
    }
    if (/^\/m\/[A-Za-z0-9]{10}\.png$/.test(path)) {
      response.writeHead(200, { ...headers, "Content-Type": "image/png" });
      return response.end(picture);
    }
    // The host's clean addresses: /changelog is changelog.html.
    const clean = path === "/" ? "index.html" : extname(path) ? path.slice(1) : `${path.slice(1)}.html`;
    const file = path === "/releases.json" && replacement ? replacement : join(root, clean);
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
  await new Promise((done) => server.listen(Number(args.port || 0), "127.0.0.1", done));
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
const release = manifest ? (manifest.releases || []).find((r) => r.version === manifest.latest) : null;
const primary = (os) => (release ? release.files.find((f) => f.os === os && f.name.endsWith(ENDS[os])) : null);
const links = new Set();

// What a person sees of the offer, read off the page as drawn.
const look = (page) => page.evaluate(() => {
  const shown = (e) => !!e && !e.hidden && e.getClientRects().length > 0;
  const button = document.getElementById("offer-button");
  const web = document.getElementById("web-app");
  const pitch = [...document.querySelectorAll("[data-pitch]")].find(shown);
  const steps = document.getElementById("steps");
  const block = [...document.querySelectorAll("[data-steps]")].find((e) => !e.hidden);
  const lists = [...document.querySelectorAll("#notes ul")].filter((u) => !u.hidden);
  return {
    device: document.documentElement.dataset.device, os: document.documentElement.dataset.os,
    offer: shown(button), ghost: !!button && button.classList.contains("ghost"),
    button: button ? button.textContent : "", href: button ? button.getAttribute("href") : "",
    web: shown(web), webHref: web ? web.getAttribute("href") : "", webPrimary: !!web && !web.classList.contains("ghost"),
    pitch: pitch ? pitch.dataset.pitch : "", pitchText: pitch ? pitch.textContent : "",
    meta: (document.getElementById("offer-meta") || {}).textContent || "",
    others: [...document.querySelectorAll("#others a")].filter(shown).map((a) => a.dataset.os),
    more: shown(document.getElementById("more")),
    stepsOpen: !!steps && steps.open, verifyOpen: !!document.getElementById("verify")?.open,
    stepsLine: (document.getElementById("steps-line") || {}).textContent || "",
    stepsFor: block ? block.dataset.steps : "",
    unsigned: block ? [...block.querySelectorAll("[data-unsigned]")].some((e) => !e.hidden) : false,
    verify: (document.getElementById("sums") || {}).textContent || "",
    notes: lists.map((u) => ({ version: u.dataset.highlights || "", items: u.children.length })),
    notesLink: (document.getElementById("notes-link") || {}).getAttribute?.("href") || "",
    broken: shown(document.getElementById("broken")), noneYet: shown(document.getElementById("none-yet")),
    words: document.querySelector("main").innerText.split(/\s+/).filter(Boolean).length,
  };
});
// Everything in main inside the window, folded parts opened: no box cut off
// at the edge, no page that scrolls sideways.
const fits = (page) => page.evaluate(() => {
  const width = document.documentElement.clientWidth;
  const out = [...document.querySelectorAll("main *")].filter((e) => {
    if (!e.getClientRects().length) return false;
    const box = e.getBoundingClientRect();
    return box.right > width + 0.5 || box.left < -0.5 || e.scrollWidth > e.clientWidth + 1 && getComputedStyle(e).overflowX !== "visible";
  }).map((e) => `${e.tagName.toLowerCase()}${e.id ? "#" + e.id : ""}${e.className ? "." + String(e.className).split(" ")[0] : ""}`);
  return { out: [...new Set(out)].slice(0, 4), scrollW: document.documentElement.scrollWidth, width };
});
const hrefs = (page) => page.evaluate(() => [...document.querySelectorAll("main a[href]")].map((a) => a.href));

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
  const fail = (text) => problems.push(`${system.label}: ${text}`);
  // A press on what is not there is a failure said, not the check's end.
  const press = (selector) => page.click(selector, { timeout: 5000 }).then(() => true,
    () => { fail(`there is no ${selector} to press`); return false; });
  const response = await page.goto(target, { waitUntil: "load", timeout: 45000 });
  if (response && !response.ok()) {
    fail(`the page answered ${response.status()}`);
    await context.close();
    continue;
  }
  await page.waitForFunction(() => !document.getElementById("notes").hidden
    || !document.getElementById("broken").hidden || !document.getElementById("none-yet").hidden,
  null, { timeout: 15000 }).catch(() => {});

  let seen = await look(page);
  const words = seen.words;
  if (seen.broken) fail("the manifest did not load");
  if (manifest && !release) {
    if (!seen.noneYet) fail("no release in the manifest, and the page does not say so");
  } else if (release && system.want) {
    // A computer: its own build, one button, the rest folded away.
    const file = primary(system.want);
    if (seen.device !== system.want || seen.os !== system.want) fail(`took it for ${seen.device}, offers ${seen.os}`);
    if (!seen.offer || seen.ghost) fail("its download is not the page's one primary button");
    if (seen.web) fail("the web app is offered as well, on a computer with a build");
    if (seen.button !== `Download for ${NAMES[system.want]}`) fail(`the button says "${seen.button}"`);
    if (!file || seen.href !== file.url) fail(`the button fetches ${seen.href}, not the manifest's ${file && file.url}`);
    if (!seen.meta.includes(release.version) || !seen.meta.includes(megabytes(file.size))) {
      fail(`the small type under it says "${seen.meta}"`);
    }
    if (seen.stepsOpen || seen.verifyOpen) fail("the first launch's steps or the checksums are open before anyone asks");
    const unsigned = system.want === "macos" ? !file.notarized : system.want === "windows" ? file.signed !== true : false;
    const warns = system.want === "macos" ? /allow it once/ : system.want === "windows" ? /allow it once/ : null;
    if (warns && warns.test(seen.stepsLine) !== unsigned) fail(`the first-launch line "${seen.stepsLine}" does not match whether it is signed`);
    if (system.want === "linux" && !/AppImage/.test(seen.stepsLine)) fail(`the first-launch line says "${seen.stepsLine}"`);
    if (seen.words > 150) fail(`${seen.words} words in the page before anything is opened (150 at most)`);
    if (JSON.stringify(seen.others) !== JSON.stringify(Object.keys(NAMES).filter((o) => o !== system.want))) {
      fail(`Other systems offers ${seen.others.join(", ")}`);
    }
    await press("#steps summary");
    await press("#verify summary");
    seen = await look(page);
    if (seen.stepsFor !== system.want) fail(`its steps are ${seen.stepsFor}'s`);
    if (seen.unsigned !== unsigned) fail(`the ${unsigned ? "unsigned build's" : "signed build's"} steps are ${seen.unsigned ? "shown" : "missing"}`);
    for (const f of release.files.filter((f) => f.os === system.want)) {
      if (!seen.verify.includes(f.sha256) || !seen.verify.includes(f.name)) fail(`Verify does not check ${f.name}`);
    }
  } else if (release) {
    // A phone: the web app first; a desktop file only once a system is chosen.
    if (seen.device !== "mobile") fail(`took a phone for ${seen.device}`);
    if (seen.offer) fail(`a phone was offered "${seen.button}"`);
    if (!seen.web || !seen.webPrimary || seen.webHref !== "/app") fail("the web app is not the phone's primary button");
    if (!/for a computer/.test(seen.pitchText)) fail(`a phone is not told the desktop app is for a computer: "${seen.pitchText}"`);
    if (seen.more) fail("a phone is shown first-launch steps before choosing a system");
    if (seen.words > 150) fail(`${seen.words} words in the page before anything is opened (150 at most)`);
    if (seen.others.length !== 3) fail(`Other systems offers ${seen.others.join(", ")}`);
  }

  if (release) {
    // What is new: three or four lines, this release's, and its changelog.
    const notes = seen.notes;
    const written = notes.find((n) => n.version);
    if (notes.length !== 1 || notes[0].items < 1 || notes[0].items > 4) fail(`What is new shows ${JSON.stringify(notes)}`);
    if (written && written.version !== release.version) fail(`What is new shows ${written.version}'s lines under ${release.version}`);
    if (seen.notesLink !== `/changelog#v${release.version}`) fail(`the changelog link goes to ${seen.notesLink}`);

    // Each other system one click away, with its own steps and checksums.
    for (const os of Object.keys(NAMES).filter((o) => o !== system.want)) {
      if (!(await press(`#others a[data-os="${os}"]`))) continue;
      await page.evaluate(() => { for (const d of document.querySelectorAll("main details")) d.open = true; });
      const now = await look(page);
      const file = primary(os);
      if (!now.offer || now.href !== file.url || now.button !== `Download for ${NAMES[os]}`) {
        fail(`one click on ${NAMES[os]} offers "${now.button}" -> ${now.href}`);
      }
      if (!system.want && (!now.ghost || !now.web)) fail(`having chosen ${NAMES[os]}, the web app is no longer first`);
      if (now.stepsFor !== os || !now.verify.includes(file.sha256)) fail(`one click on ${NAMES[os]} leaves ${now.stepsFor}'s steps`);
      if (!(await page.evaluate(() => location.search)).includes(`os=${os}`)) fail(`the address does not say ?os=${os}`);
      for (const href of await hrefs(page)) links.add(href);
      // Opened, at a phone's width: nothing cut off.
      for (const width of [system.width, 390]) {
        await page.setViewportSize({ width, height: 900 });
        const fit = await fits(page);
        if (fit.out.length || fit.scrollW > fit.width + 1) {
          fail(`${NAMES[os]}'s steps opened at ${width} px: ${fit.out.join(", ") || "the page"} past the edge (${fit.scrollW} in ${fit.width})`);
        }
      }
      await page.setViewportSize({ width: system.width, height: 900 });
    }
  }
  for (const href of await hrefs(page)) links.add(href);
  if (said.length) fail(`the console said: ${said.slice(0, 3).join(" | ")}`);
  const fit = await fits(page);
  if (fit.scrollW > fit.width + 1) fail(`scrolls sideways, ${fit.scrollW}px in ${fit.width}px`);
  if (fit.out.length) fail(`${fit.out.join(", ")} past the edge at ${fit.width} px`);

  console.log(`  ${system.label.padEnd(8)} took it for ${seen.device || "?"}: `
    + (seen.offer ? `"${seen.button}" -> ${seen.href.split("/").pop()}` : seen.web ? "the web app first" : "no offer")
    + `, ${words} words before anything is opened` + (seen.offer ? `  (${seen.meta})` : ""));
  if (args.shots) {
    await page.goto(target, { waitUntil: "load" });
    await page.waitForFunction(() => !document.getElementById("notes").hidden, null, { timeout: 15000 }).catch(() => {});
    const path = join(args.shots, `download-${system.label}.png`);
    await page.screenshot({ path, fullPage: true });
    console.log(`           ${path}`);
  }
  await context.close();
}

// -- downloads gated by the plan (locally only) ------------------------------------
if (server && release) {
  for (const plan of ["free", "pro"]) {
    gatedAs = plan;
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    const fail = (text) => problems.push(`gated, ${plan}: ${text}`);
    await page.goto(`${target}?os=linux`, { waitUntil: "load", timeout: 45000 });
    await page.waitForFunction(() => !document.getElementById("notes").hidden, null, { timeout: 15000 })
      .catch(() => fail("the page did not draw its offer"));
    // The question answered before the click, as a person's would be.
    await page.waitForResponse((r) => r.url().includes("/api/plans?op=download"), { timeout: 5000 })
      .catch(() => {});
    const href = await page.getAttribute("#offer-button", "href");
    if (href !== primary("linux").url) fail(`the button's link is ${href}, not the manifest's`);
    const went = page.waitForRequest((r) => r.url().endsWith(SIGNED_PATH), { timeout: 8000 }).catch(() => null);
    await page.click("#offer-button");
    if (plan === "free") {
      const said = await page.waitForSelector("#gate-said", { timeout: 8000 }).then((e) => e.textContent(), () => "");
      const pro = await page.getAttribute("#gate-said a", "href").catch(() => null);
      if (!said.startsWith(PRO_WORDS) || pro !== "/plans") fail(`a click said "${said}", linking ${pro}`);
      if (!page.url().startsWith(target)) fail(`a refused click went to ${page.url()}`);
    } else if (!(await went)) {
      fail("a click did not go to the address the route gave");
    }
    console.log(`  gated    ${plan}: ${plan === "free" ? "refused with the way to Pro" : "sent to the route's address"}`);
    await context.close();
  }
  gatedAs = null;
}

// -- the page's links ------------------------------------------------------------
// Every address the page links to, on every system's view, answers: the site's
// own pages here (the app is the host's, so only on a deployment), GitHub's
// release pages and files there, asked for their headers only.
for (const href of [...links].sort()) {
  const url = new URL(href);
  const local = !args.url && url.origin === new URL(target).origin;
  if (local && url.pathname === "/app") continue;
  if (url.hash && url.pathname === "/changelog") {
    // The changelog's anchors are tools/site.py's: one per release in CHANGELOG.md.
    const text = local ? await readFile(resolve("CHANGELOG.md"), "utf8") : "";
    const there = local ? text.includes(`## [${url.hash.slice(2)}]`)
      : (await (await fetch(url, { headers: bypass })).text()).includes(`id="${url.hash.slice(1)}"`);
    if (!there) problems.push(`links: ${href} names no release on the changelog`);
  }
  let status = 0;
  for (let attempt = 0; attempt < 2 && !(status >= 200 && status < 400); attempt++) {
    try {
      const answer = await fetch(url, { method: url.hostname.endsWith("github.com") ? "HEAD" : "GET",
        redirect: "follow", headers: url.origin === new URL(target).origin ? bypass : {} });
      status = answer.status;
    } catch (trouble) {
      status = String(trouble.cause?.code || trouble.message);
    }
  }
  if (!(status >= 200 && status < 400)) problems.push(`links: ${href} answered ${status}`);
}
console.log(`  links    ${links.size} addresses on the page${args.url ? "" : " (/app is the host's: checked only on a deployment)"}`);

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
  // The list as first drawn, before the page can bring the next page by
  // itself (web/gallery.js nearEnd: once Show more is within a screen under
  // the window, as the made-up list's first page ends at 1280). Read as
  // data-pages is first said, which is before nearEnd runs.
  await page.addInitScript(() => {
    new MutationObserver((changes, watch) => {
      if (document.documentElement.dataset.pages !== "1") return;
      watch.disconnect();
      const more = document.getElementById("more");
      window.firstDrawn = { cards: document.querySelectorAll("#models .model").length, more: !more.hidden,
        top: Math.round(more.getBoundingClientRect().top), within: innerHeight * 2,
        where: location.pathname + location.search, state: document.documentElement.dataset.gallery };
    }).observe(document, { attributes: true, subtree: true, attributeFilter: ["data-pages"] });
  });
  const response = await page.goto(galleryTarget, { waitUntil: "load", timeout: 45000 });
  if (!response || !response.ok()) {
    fail(`the page answered ${response && response.status()}`);
    await context.close();
    continue;
  }
  await page.waitForFunction(() => document.documentElement.dataset.gallery, null, { timeout: 20000 }).catch(() => {});
  const look = () => page.evaluate(() => ({
    state: document.documentElement.dataset.gallery || "",
    // A card's size and its designer, said as one line ("86 parts, by Builder 2").
    cards: [...document.querySelectorAll("#models .model")].map((a) => ({
      href: a.querySelector("a.open").getAttribute("href"), name: a.querySelector("b").textContent,
      about: [a.querySelector(".parts")?.textContent, a.querySelector(".who")?.textContent].filter(Boolean).join(", by "),
      img: (a.querySelector("img") || {}).src || "" })),
    more: !document.getElementById("more").hidden,
    empty: !document.getElementById("empty").hidden,
    stray: document.querySelectorAll('#models img[src="x"], #models img:not([src*="/m/"])').length,
    title: document.title,
    scrollW: document.documentElement.scrollWidth, clientW: document.documentElement.clientWidth,
    broken: [...document.images].filter((i) => i.complete && !i.naturalWidth).map((i) => i.src),
  }));
  await allPictures(page);
  let seen = await look();
  let paged = "";
  if (seen.state !== "ready") fail(`the list did not load (${seen.state || "nothing said"})`);
  const drawn = await page.evaluate(() => window.firstDrawn || null);
  if (!args.url) {
    if (!drawn || drawn.cards !== 24 || !drawn.more) {
      fail(`the first page is ${drawn ? drawn.cards : "never drawn,"} cards, Show more ${drawn && drawn.more ? "shown" : "hidden"}`);
    }
    const first = seen.cards[0] || {};
    if (first.name !== HOSTILE || seen.stray || seen.title === "owned") fail("a name that is markup was not shown as text");
    if (first.href !== "/m/Gal0000000" || first.about !== "12 parts") fail(`the first card is ${JSON.stringify(first)}`);
    if ((seen.cards[1] || {}).img) fail("a model with no picture was given one");
    if ((seen.cards[2] || {}).about !== "86 parts, by Builder 2") fail(`a credit reads "${(seen.cards[2] || {}).about}"`);
  }
  // The next page: by itself where Show more was first drawn within a
  // screen under the window, else when it is pressed. A deployment's own
  // list too, when it lists more than a page: releases check only that,
  // and this half went stale for three days unseen (2026-10-29).
  if (drawn && drawn.more) {
    const near = drawn.top <= drawn.within;
    if (!near) {
      if (seen.cards.length !== drawn.cards || !seen.more) fail(`Show more ${drawn.top}px down, the list is ${seen.cards.length} cards before it is pressed, Show more ${seen.more ? "shown" : "hidden"}`);
      if (seen.more) {
        // Brought into view first, at once: that scroll may ask for the next
        // page by itself (nearEnd), and Show more is disabled until it
        // comes. Pressed in that moment, the press was lost.
        await page.evaluate(() => document.getElementById("more").scrollIntoView({ block: "center", behavior: "instant" }));
        await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
        await page.waitForFunction(() => !document.getElementById("more").disabled, null, { timeout: 10000 }).catch(() => {});
        await page.click("#more");
      }
    }
    const came = await page.waitForFunction((had) => document.querySelectorAll("#models .model").length > had, drawn.cards, { timeout: 10000 }).catch(() => null);
    await page.waitForTimeout(300);
    const auto = await page.evaluate(() => document.documentElement.dataset.auto || "0");
    seen = await look();
    // Pressed, the scroll to it may have asked for it by itself (auto 1):
    // either way it is drawn by the press.
    if (!came || (near && auto !== "1") || (!args.url && (seen.cards.length !== 26 || seen.more))) {
      fail(`${near ? `with Show more ${drawn.top}px down, by itself` : "after Show more"}, ${seen.cards.length} cards (auto ${auto}), Show more ${seen.more ? "still shown" : "gone"}`);
    }
    paged = ` (${drawn.cards}, then ${seen.cards.length - drawn.cards} ${near ? "by itself" : "by Show more"}, Show more first at ${drawn.top}px)`;
  }
  if (!args.url) {
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
    await page.click('#kinds [data-kind="space"]');
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
    // Its first page as drawn: at 1280 the second comes by itself after.
    await page.goto(`${galleryTarget}?kind=nope&q=x`, { waitUntil: "load" });
    await page.waitForFunction(() => window.firstDrawn, null, { timeout: 10000 }).catch(() => {});
    await page.waitForTimeout(500);
    const put = await page.evaluate(() => window.firstDrawn || {});
    const meanwhile = said.splice(before).filter((line) => !/status of 400/.test(line));
    said.push(...meanwhile);
    if (put.where !== "/gallery" || put.cards !== 24 || put.state !== "ready") {
      fail(`an address asking for a kind there is not: ${put.where}, ${put.cards} cards, ${put.state}`);
    }
    await page.goto(`${galleryTarget}?kind=castle`, { waitUntil: "load" });
    asked = await answered("/gallery?kind=castle");
    const picked = await page.evaluate(() => document.querySelector('#kinds [aria-pressed="true"]')?.dataset.kind);
    if (picked !== "castle" || asked.cards.length !== 13) fail(`?kind=castle: ${picked}, ${asked.cards.length} cards`);
  } else if (!seen.cards.length && !seen.empty) {
    fail("neither cards nor the empty gallery's words");
  }
  if (said.length) fail(`the console said: ${said.slice(0, 3).join(" | ")}`);
  if (seen.scrollW > seen.clientW + 1) fail(`scrolls sideways, ${seen.scrollW}px in ${seen.clientW}px`);
  if (seen.broken.length) fail(`broken pictures: ${seen.broken.slice(0, 3).join(", ")}`);
  console.log(`  gallery  ${label}: ${seen.cards.length} cards${paged}${seen.empty ? " (nothing listed)" : ""}`
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
