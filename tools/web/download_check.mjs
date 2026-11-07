// Does the download page say the desktop app is coming soon, to every system,
// under the site's rules?
//
//   node tools/web/download_check.mjs                     web/ as it is
//   node tools/web/download_check.mjs --url=https://brickworks.diy/download
//   VERCEL_BYPASS=… node tools/web/download_check.mjs --url=<a preview>/download
//   --shots=DIR                                           a screenshot per system
//   --port=N                                              serve web/ on N (default: any free)
//
// The owner, 2026-11-07: "make the downloadable access 'Coming soon' or
// something of that sort, since we can't properly support it yet." Linux,
// macOS, Windows and an Android phone each open /download and see the same
// page: its heading says the desktop app is coming soon, its one primary
// button is Open Brickworks, into the app (/app); no installer, no file
// name, no button for a system, nothing asked of /releases.json or GitHub,
// and no more than 150 words. Nothing past the edge at the system's width
// or at 390 px, no error in the console, and every link on the page
// answers. Until 2026-11-07 this checked that each system was offered its
// own build from /releases.json (git log -- tools/web/download_check.mjs);
// tools/web/coming_soon_check.mjs holds every other page, in every
// language, to offering none.
//
// Locally the page is served with a content security policy at least as
// strict as the one tools/deploy.sh sends: scripts and connections to the
// page's own origin only, no inline script. A page that works here works
// there.
//
// And the gallery, /gallery (web/gallery.html), under the same policy: its
// script draws the listed models from /api/share?op=list, a page at a time.
// Locally the list is a made-up one of 26 models — one with no picture, one
// whose name is markup — so the check sees two pages and a name that must
// be shown as the text it is; against a deployment, what it lists. The
// first page is drawn with Show more (web/pager.js), and the next only
// when it is pressed, never by itself. Brought into view, Show more asks
// for the next page ahead; pressed as a person does while that page is
// still on its way (locally a later page takes LATER_PAGE_MS to come), the
// press is kept and the page drawn as it comes, one press enough and the
// page asked for once (a press then was lost before 2026-10-29: Show more
// was disabled); locally Show more is then gone. A deployment that lists
// more than a page is paged the same way.
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

// The site's own policy (tools/deploy.sh): no script from elsewhere, the
// visit counter being the site's own copy (web/ov/s.js), which reports to
// Overlook, answered here (browser.mjs quietCounter).
const CSP = "default-src 'self'; script-src 'self'; "
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
let server = null;
let target = args.url;
// A protected preview lets this check in with the bypass; production ignores
// it. And without Vercel's preview toolbar, whose script the site's security
// policy rightly refuses: it is injected for a browser that does not say it is
// headless, as this one says it is Chrome on each system, and is never on the
// real site.
const bypass = process.env.VERCEL_BYPASS
  ? { "x-vercel-protection-bypass": process.env.VERCEL_BYPASS, "x-vercel-skip-toolbar": "1" } : {};
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
// How long the made-up list takes to give a page after the first, and how
// many such pages it has been asked for and not yet given.
const LATER_PAGE_MS = 1500;
let laterAsked = 0;
let laterOut = 0;
if (!target) {
  const root = resolve("web");
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
      if (page > 1) {
        laterAsked += 1;
        laterOut += 1;
        await new Promise((done) => setTimeout(done, LATER_PAGE_MS));
        laterOut -= 1;
      }
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
    if (/^\/m\/[A-Za-z0-9]{10}\.png$/.test(path)) {
      response.writeHead(200, { ...headers, "Content-Type": "image/png" });
      return response.end(picture);
    }
    // The host's clean addresses: /changelog is changelog.html.
    const clean = path === "/" ? "index.html" : extname(path) ? path.slice(1) : `${path.slice(1)}.html`;
    const file = join(root, clean);
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
}

const browser = await launch({ signedOut: true });  // a page of the site, not the app
const problems = [];
if (args.shots) await mkdir(args.shots, { recursive: true });
const links = new Set();
// What offers an installer: a file a system installs from, by its name's end,
// or the releases repository's releases (tools/web/coming_soon_check.mjs).
const INSTALLER = /\.(?:dmg|deb|msi|exe|appimage|pkg|rpm)(?:$|[?#])|-(?:linux|macos|windows)-[\w.-]*\.(?:zip|tar\.xz)(?:$|[?#])/i;
const RELEASES = /github\.com\/Xaxis\/brickworks(?:-releases)?\/releases(?:$|[/?#])|githubusercontent\.com|\/releases\.json(?:$|[?#])/i;

// What a person sees, read off the page as drawn.
const look = (page) => page.evaluate(() => {
  const shown = (e) => !!e && !e.hidden && e.getClientRects().length > 0;
  const main = document.querySelector("main");
  const ctas = [...main.querySelectorAll("a.cta, button.cta")].filter(shown);
  return {
    heading: main.querySelector("h1")?.textContent.replace(/\s+/g, " ").trim() || "",
    primary: ctas.filter((e) => !e.classList.contains("ghost"))
      .map((e) => ({ text: e.textContent.replace(/[→\s]+/g, " ").trim(), href: e.getAttribute("href") })),
    buttons: ctas.map((e) => e.textContent.replace(/\s+/g, " ").trim()),
    every: [...document.querySelectorAll("a[href], button")].map((e) => ({ href: e.href || "",
      text: e.textContent.replace(/\s+/g, " ").trim() })),
    text: main.innerText,
    words: main.innerText.split(/\s+/).filter(Boolean).length,
  };
});
// Everything in main inside the window: no box cut off at the edge, no page
// that scrolls sideways.
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
  const asked = [];
  page.on("console", (m) => { if (m.type() === "error") said.push(m.text()); });
  page.on("pageerror", (e) => said.push(String(e)));
  page.on("request", (r) => { if (RELEASES.test(r.url()) || /github\.com/.test(r.url())) asked.push(r.url()); });
  const fail = (text) => problems.push(`${system.label}: ${text}`);
  const response = await page.goto(target, { waitUntil: "load", timeout: 45000 });
  if (response && !response.ok()) {
    fail(`the page answered ${response.status()}`);
    await context.close();
    continue;
  }
  await page.waitForLoadState("networkidle", { timeout: 5000 }).catch(() => {});
  const seen = await look(page);
  if (seen.heading !== "The desktop app is coming soon") fail(`the heading says "${seen.heading}"`);
  if (seen.primary.length !== 1 || seen.primary[0].text !== "Open Brickworks" || seen.primary[0].href !== "/app") {
    fail(`the primary buttons are ${JSON.stringify(seen.primary)}, not one Open Brickworks to /app`);
  }
  for (const one of seen.every) {
    if (INSTALLER.test(one.href) || RELEASES.test(one.href)) fail(`"${one.text}" links ${one.href}`);
    if (/\bdownload\b/i.test(one.text) && /\/download\/?$|github/.test(one.href)) fail(`"${one.text}" offers a download (${one.href})`);
  }
  const file = /[\w-]+\.(?:dmg|deb|msi|exe|AppImage|zip|tar\.xz)\b/i.exec(seen.text);
  if (file) fail(`names a file, ${file[0]}`);
  const forSystem = seen.buttons.find((b) => /\b(?:linux|macos|mac|windows)\b/i.test(b));
  if (forSystem) fail(`a button for a system, "${forSystem}"`);
  if (asked.length) fail(`asked ${asked.slice(0, 2).join(", ")}`);
  if (seen.words > 150) fail(`${seen.words} words on the page (150 at most)`);
  for (const href of await hrefs(page)) links.add(href);
  if (said.length) fail(`the console said: ${said.slice(0, 3).join(" | ")}`);
  for (const width of [system.width, 390]) {
    await page.setViewportSize({ width, height: 900 });
    const fit = await fits(page);
    if (fit.scrollW > fit.width + 1) fail(`scrolls sideways at ${width} px, ${fit.scrollW}px in ${fit.width}px`);
    if (fit.out.length) fail(`${fit.out.join(", ")} past the edge at ${fit.width} px`);
  }
  await page.setViewportSize({ width: system.width, height: 900 });
  console.log(`  ${system.label.padEnd(8)} "${seen.heading}" · `
    + `${seen.primary.map((p) => `"${p.text}" ${p.href}`).join(", ") || "no primary button"} · ${seen.words} words`);
  if (args.shots) {
    const path = join(args.shots, `download-${system.label}.png`);
    await page.screenshot({ path, fullPage: true });
    console.log(`           ${path}`);
  }
  await context.close();
}

// -- the page's links ------------------------------------------------------------
// Every address the page links to answers: the site's own pages here (the app
// is the host's, so only on a deployment).
for (const href of [...links].sort()) {
  const url = new URL(href);
  const local = !args.url && url.origin === new URL(target).origin;
  if (local && url.pathname === "/app") continue;
  let status = 0;
  for (let attempt = 0; attempt < 2 && !(status >= 200 && status < 400); attempt++) {
    try {
      const answer = await fetch(url, { redirect: "follow", headers: url.origin === new URL(target).origin ? bypass : {} });
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
  // The list as first drawn, read as data-pages is first said.
  await page.addInitScript(() => {
    new MutationObserver((changes, watch) => {
      if (document.documentElement.dataset.pages !== "1") return;
      watch.disconnect();
      const more = document.querySelector(".pager-more");
      window.firstDrawn = { cards: document.querySelectorAll("#models .model").length, more: !more.hidden,
        top: Math.round(more.getBoundingClientRect().top), within: innerHeight * 2,
        where: location.pathname + location.search, state: document.documentElement.dataset.gallery };
    }).observe(document, { attributes: true, subtree: true, attributeFilter: ["data-pages"] });
  });
  laterAsked = 0;
  const response = await page.goto(galleryTarget, { waitUntil: "load", timeout: 45000 });
  if (!response || !response.ok()) {
    fail(`the page answered ${response && response.status()}`);
    await context.close();
    continue;
  }
  // Drawn once it says ready (or broken), not while it says asking.
  await page.waitForFunction(() => ["ready", "broken"].includes(document.documentElement.dataset.gallery), null, { timeout: 20000 })
    .catch(() => {});
  const look = () => page.evaluate(() => ({
    state: document.documentElement.dataset.gallery || "",
    // A card's size and its designer, said as one line ("86 parts, by Builder 2").
    cards: [...document.querySelectorAll("#models .model")].map((a) => ({
      href: a.querySelector("a.open").getAttribute("href"), name: a.querySelector("b").textContent,
      about: [a.querySelector(".parts")?.textContent, a.querySelector(".who")?.textContent].filter(Boolean).join(", by "),
      img: (a.querySelector("img") || {}).src || "" })),
    more: Boolean(document.querySelector(".pager-more")) && !document.querySelector(".pager-more").closest("[hidden]"),
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
  // The next page: only when Show more is pressed. Brought into view, it
  // is asked for ahead and not drawn; pressed while it is on its way, as a
  // person does, at the place on the screen, the press is kept and the
  // page drawn when it comes, never lost. A deployment's own list too,
  // when it lists more than a page: releases check only that, and this
  // half went stale for three days unseen (2026-10-29).
  if (drawn && drawn.more) {
    await page.evaluate(() => document.querySelector(".pager-more").scrollIntoView({ block: "center", behavior: "instant" }));
    if (!args.url) {
      const until = Date.now() + 5000;
      while (!laterOut && Date.now() < until) await page.waitForTimeout(20);
    }
    const out = laterOut;
    const before = await page.evaluate(() => document.querySelectorAll("#models .model").length);
    if (before !== drawn.cards) fail(`brought into view, the list is ${before} cards before Show more is pressed, not ${drawn.cards}`);
    const box = await page.locator(".pager-more").boundingBox();
    if (box) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    if (!args.url && out !== 1) fail(`Show more was pressed with ${out} later pages on their way, not while the one asked ahead was`);
    const came = await page.waitForFunction((had) => document.querySelectorAll("#models .model").length > had, drawn.cards, { timeout: 10000 }).catch(() => null);
    await page.waitForTimeout(300);
    seen = await look();
    if (!came || (!args.url && (seen.cards.length !== 26 || seen.more))) {
      fail(`after Show more, ${seen.cards.length} cards, Show more ${seen.more ? "still shown" : "gone"}`);
    }
    // One page asked for: ahead, and the press served by it.
    if (!args.url && laterAsked !== 1) fail(`the second page was asked for ${laterAsked} times`);
    paged = ` (${drawn.cards}, then ${seen.cards.length - drawn.cards} by Show more, pressed while it was on its way)`;
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
    // Its first page as drawn.
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
console.log("  the download page says the desktop app is coming soon, to every system");
