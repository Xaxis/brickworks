// Does every page of the site say the desktop app is coming soon, and offer
// no installer anywhere?
//
//   node tools/web/coming_soon_check.mjs                 the site tools/site.py puts together from this checkout
//   node tools/web/coming_soon_check.mjs --root=DIR      a site already put together in DIR
//   node tools/web/coming_soon_check.mjs --static        the pages' and scripts' source only, no browser
//   VERCEL_BYPASS=… node tools/web/coming_soon_check.mjs --url=<deployment>
//   --shots=DIR     /download and / at 390 and 1280 px, light and dark
//
// flows_for: every page
//
// The owner, 2026-11-07: "make the downloadable access 'Coming soon' or
// something of that sort, since we can't properly support it yet." Every
// way a person could get the desktop app says it is coming soon and offers
// the app in the browser instead; the desktop app already installed keeps
// updating itself (src/net/updates.gd, the signed feed and the releases
// repository are untouched, and are no page's to offer).
//
// Every page the site is put together with (tools/site.py: each of web/'s,
// its German, French and Spanish copies, and the documentation), at the
// address the host serves it at, and every script each one loads and what
// those import, in two passes:
//
// - as sent: no link, button or form that fetches an installer (.deb, .dmg,
//   .exe, .msi, .AppImage, a system's .zip or .tar.xz), the releases
//   repository's releases or their files, or /releases.json; no search
//   engine told there is a download (JSON-LD downloadUrl); and no script
//   that reaches for any of those, as web/download.js did.
// - as drawn, in a browser, once the page's scripts have run: the same of
//   every link and button, and none of them saying Download beside a
//   system, or Download to /download (the page is "Desktop app" now).
//
// And /download in each language, at 390 and 1280 px: its heading says the
// desktop app is coming soon and its one primary button is Open Brickworks,
// into the app in the page's language; no file name, no button for a
// system, nothing asked of /releases.json or GitHub; nothing past the edge
// and no error in the console. The words are each language's own, from
// web/_lang/<code>.json.
import { launch } from "./browser.mjs";
import { createServer } from "node:http";
import { readFile, readdir, mkdir, mkdtemp, rm, stat } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, extname, resolve, relative } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const LANGS = ["en", "de", "fr", "es"];
const bypass = process.env.VERCEL_BYPASS
  ? { "x-vercel-protection-bypass": process.env.VERCEL_BYPASS, "x-vercel-skip-toolbar": "1" } : {};
// As tools/deploy.sh sends it: the page's own scripts only, none inline.
const CSP = "default-src 'self'; script-src 'self'; "
  + "connect-src 'self' https://overlook.technology; "
  + "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; object-src 'none'; "
  + "base-uri 'none'; form-action 'self'; frame-ancestors 'none'";
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript",
  ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml", ".css": "text/css",
  ".webp": "image/webp", ".xml": "application/xml", ".txt": "text/plain", ".webmanifest": "application/manifest+json" };

// -- what offers an installer ------------------------------------------------------
// A file a system installs from, by its name's end (the releases' own:
// tools/release.py artifacts), or the releases repository's releases.
const INSTALLER = /\.(?:dmg|deb|msi|exe|appimage|pkg|rpm|snap|flatpakref)(?:$|[?#])|-(?:linux|macos|windows)-[\w.-]*\.(?:zip|tar\.xz)(?:$|[?#])/i;
const RELEASES = /github\.com\/Xaxis\/brickworks(?:-releases)?\/releases(?:$|[/?#])|(?:objects|release-assets)\.githubusercontent\.com|\/releases\.json(?:$|[?#])/i;
// In a script: the same, wherever a string names it.
const REACHES = /github\.com\/Xaxis\/brickworks(?:-releases)?\/releases\b|releases\.json|["'`/][\w.-]*\.(?:dmg|AppImage|msi)["'`]|-setup\.exe/;
const DOWNLOAD = /\b(?:download|herunterladen|t[ée]l[ée]charger|descargar)\b/i;
const SYSTEM = /\b(?:linux|macos|mac|windows|desktop|bureau|escritorio|ordinateur|computer|ordenador)\b/i;
const OUR_DOWNLOAD = /^\/(?:(?:de|fr|es)\/)?download\/?$/;

/// What [href] and [text] offer, or "" for nothing.
function offers(href, text) {
  const words = text.replace(/\s+/g, " ").trim();
  let path = "";
  try { path = new URL(href, "https://brickworks.diy").pathname; } catch { /* not a link */ }
  if (href && INSTALLER.test(path || href)) return `an installer, ${href}`;
  if (href && RELEASES.test(href)) return `the releases, ${href}`;
  if (OUR_DOWNLOAD.test(path) && DOWNLOAD.test(words)) return `"${words}" to ${path}`;
  if (DOWNLOAD.test(words) && SYSTEM.test(words)) return `"${words}"`;
  return "";
}

// -- the site ----------------------------------------------------------------------
let root = args.root ? resolve(args.root) : "";
let made = "";
if (!args.url && !root) {
  made = await mkdtemp(join(tmpdir(), "coming-soon-"));
  root = join(made, "site");
  execFileSync("python3", ["tools/site.py", root], { stdio: ["ignore", "ignore", "inherit"] });
}
const words = Object.fromEntries(await Promise.all(LANGS.filter((c) => c !== "en").map(async (code) =>
  [code, JSON.parse(await readFile(join("web", "_lang", `${code}.json`), "utf8")).pages])));
/// [english] as [code]'s page says it.
const say = (code, english) => (code === "en" ? english : words[code][english] || `(no ${code} for "${english}")`);

/// Every page the site has, as the host serves it: [file, address, language].
async function pagesOf(dir) {
  const found = [];
  async function walk(at) {
    for (const entry of await readdir(at, { withFileTypes: true })) {
      const full = join(at, entry.name);
      if (entry.isDirectory()) await walk(full);
      else if (entry.name.endsWith(".html")) found.push(relative(dir, full).split("\\").join("/"));
    }
  }
  await walk(dir);
  return found.sort().map((file) => {
    const lang = /^(de|fr|es)\//.exec(file)?.[1] || "en";
    const rest = lang === "en" ? file : file.slice(3);
    const at = lang === "en" ? "" : `/${lang}`;
    const name = rest.replace(/\.html$/, "");
    const address = name === "index" ? at || "/" : name === "404" ? `${at}/no-such-page-coming-soon`
      : name === "authorize" ? `${at}/oauth/authorize` : `${at}/${name}`;
    return { file, address, lang };
  });
}
// A deployment's pages are this checkout's (tools/site.py), at the same addresses.
if (args.url && !root) {
  made = await mkdtemp(join(tmpdir(), "coming-soon-"));
  root = join(made, "site");
  execFileSync("python3", ["tools/site.py", root], { stdio: ["ignore", "ignore", "inherit"] });
}
const PAGES = await pagesOf(root);

let server = null;
let base = args.url ? String(args.url).replace(/\/$/, "") : "";
if (!base) {
  server = createServer(async (request, response) => {
    const url = new URL(request.url, "http://x");
    const path = decodeURIComponent(url.pathname);
    const headers = { "Content-Security-Policy": CSP, "X-Content-Type-Options": "nosniff",
      "Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp",
      "Cross-Origin-Resource-Policy": "same-origin" };
    if (path.startsWith("/api/")) {
      // Nothing behind the pages here: what they ask is answered, empty.
      response.writeHead(404, { ...headers, "Content-Type": "application/json" });
      return response.end(JSON.stringify({ error: "not here" }));
    }
    const lang = /^\/(de|fr|es)(?=\/|$)/.exec(path)?.[1] || "";
    const rest = lang ? path.slice(3) || "/" : path;
    const own = (name) => join(root, lang, name);
    const tries = rest === "/" ? ["index.html"] : rest === "/oauth/authorize" ? ["oauth/authorize.html", "authorize.html"]
      : extname(rest) ? [rest.slice(1)] : [`${rest.slice(1).replace(/\/$/, "")}.html`];
    for (const name of tries) {
      const file = own(name);
      if (!file.startsWith(root)) break;
      try {
        if (!(await stat(file)).isFile()) continue;
        const body = await readFile(file);
        response.writeHead(200, { ...headers, "Content-Type": TYPES[extname(file)] || "application/octet-stream" });
        return response.end(body);
      } catch { /* the next, or none */ }
    }
    try {
      const body = await readFile(own("404.html"));
      response.writeHead(404, { ...headers, "Content-Type": TYPES[".html"] });
      response.end(body);
    } catch {
      response.writeHead(404).end();
    }
  });
  await new Promise((done) => server.listen(Number(args.port || 0), "127.0.0.1", done));
  base = `http://127.0.0.1:${server.address().port}`;
}

const problems = [];
const fail = (where, text) => problems.push(`${where}: ${text}`);
const texts = new Map();
async function fetchText(url) {
  if (!texts.has(url)) {
    texts.set(url, fetch(url, { headers: bypass, redirect: "follow" })
      .then(async (r) => ({ status: r.status, text: await r.text() }), (e) => ({ status: 0, text: String(e) })));
  }
  return texts.get(url);
}
const strip = (html) => html.replace(/<[^>]+>/g, " ").replace(/&nbsp;|&#160;/g, " ").replace(/&amp;/g, "&")
  .replace(/&[a-z]+;|&#\d+;/g, " ").replace(/\s+/g, " ").trim();

// -- 1. as sent: the pages' and their scripts' source ------------------------------
const scripts = new Map();  // script address -> the first page that loads it
async function follow(scriptUrl, from) {
  const url = new URL(scriptUrl);
  if (url.origin !== new URL(base).origin) return;
  const key = url.pathname;
  if (scripts.has(key)) return;
  scripts.set(key, from);
  const { status, text } = await fetchText(url.href);
  if (status !== 200) return fail(key, `answered ${status} (loaded by ${from})`);
  const hit = REACHES.exec(text);
  if (hit) fail(key, `reaches for "${hit[0]}" (loaded by ${from})`);
  for (const m of text.matchAll(/(?:\bfrom\s*|\bimport\s*\(\s*|\bimport\s+)["'`]([^"'`]+\.m?js)["'`]/g)) {
    await follow(new URL(m[1], url).href, from);
  }
}
let sent = 0;
for (const page of PAGES) {
  const url = base + page.address;
  const { status, text } = await fetchText(url);
  const expected = page.address.includes("no-such-page") ? 404 : 200;
  if (status !== expected) { fail(page.address, `answered ${status}`); continue; }
  sent += 1;
  const head = `${page.address}`;
  for (const m of text.matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/gi)) {
    const href = /\bhref\s*=\s*"([^"]*)"/i.exec(m[1])?.[1] || "";
    const why = offers(href, strip(m[2])) || (/\sdownload(?:\s|=|$)/i.test(m[1]) && INSTALLER.test(href) ? href : "");
    if (why) fail(head, `links ${why}`);
  }
  for (const m of text.matchAll(/<button\b([^>]*)>([\s\S]*?)<\/button>/gi)) {
    const why = offers(/\bformaction\s*=\s*"([^"]*)"/i.exec(m[1])?.[1] || "", strip(m[2]));
    if (why) fail(head, `a button offers ${why}`);
  }
  for (const m of text.matchAll(/<form\b[^>]*\baction\s*=\s*"([^"]*)"/gi)) {
    const why = offers(m[1], "");
    if (why) fail(head, `a form sends to ${why}`);
  }
  if (/"downloadUrl"\s*:/.test(text)) fail(head, "tells search engines there is a download (JSON-LD downloadUrl)");
  for (const m of text.matchAll(/<script\b[^>]*\bsrc\s*=\s*"([^"]+)"/gi)) await follow(new URL(m[1], url).href, page.address);
}
console.log(`  as sent   ${sent} of ${PAGES.length} pages, ${scripts.size} scripts they load`
  + ` (${LANGS.map((c) => `${PAGES.filter((p) => p.lang === c).length} ${c}`).join(", ")})`);

// -- 2. as drawn ---------------------------------------------------------------------
if (!args.static) {
  const browser = await launch({ signedOut: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: bypass });
  // Pictures and the app are not what is judged here, and cost the most.
  await context.route(/\.(?:webp|png|jpe?g|avif|gif|glb|woff2?)(?:\?|$)/, (route) => route.abort());
  const tab = await context.newPage();
  let drawn = 0;
  for (const page of PAGES) {
    try {
      await tab.goto(base + page.address, { waitUntil: "load", timeout: 30000 });
      await tab.waitForLoadState("networkidle", { timeout: 3000 }).catch(() => {});
    } catch (trouble) {
      fail(page.address, `did not load in a browser: ${String(trouble.message).split("\n")[0]}`);
      continue;
    }
    drawn += 1;
    const seen = await tab.evaluate(() => [...document.querySelectorAll("a[href], button, [role=button], form[action]")]
      .map((e) => ({ href: e.getAttribute("href") || e.getAttribute("action") || e.getAttribute("formaction") || "",
        abs: e.href || "", text: (e.innerText || e.textContent || e.getAttribute("aria-label") || "").trim(),
        download: e.hasAttribute("download") })));
    for (const one of seen) {
      const why = offers(one.abs || one.href, one.text);
      if (why) fail(page.address, `shows ${why}`);
    }
  }
  console.log(`  as drawn  ${drawn} pages in a browser, their scripts run`);

  // -- 3. /download, in each language -------------------------------------------
  if (args.shots) await mkdir(args.shots, { recursive: true });
  for (const code of LANGS) {
    const at = code === "en" ? "" : `/${code}`;
    for (const width of [390, 1280]) {
      const where = `${at}/download at ${width}`;
      const page = await browser.newPage({ viewport: { width, height: 900 }, extraHTTPHeaders: bypass });
      const said = [];
      const asked = [];
      page.on("console", (m) => { if (m.type() === "error" && !/the server responded with a status of 404/.test(m.text())) said.push(m.text()); });
      page.on("pageerror", (e) => said.push(String(e)));
      page.on("request", (r) => { if (RELEASES.test(r.url()) || /github\.com/.test(r.url())) asked.push(r.url()); });
      await page.goto(`${base}${at}/download`, { waitUntil: "load", timeout: 30000 });
      await page.waitForLoadState("networkidle", { timeout: 3000 }).catch(() => {});
      const got = await page.evaluate(() => {
        const shown = (e) => !!e && !e.hidden && e.getClientRects().length > 0;
        const main = document.querySelector("main");
        const ctas = [...main.querySelectorAll("a.cta, button.cta")].filter(shown);
        const width = document.documentElement.clientWidth;
        const past = [...main.querySelectorAll("*")].filter((e) => e.getClientRects().length
          && (e.getBoundingClientRect().right > width + 0.5 || e.getBoundingClientRect().left < -0.5))
          .map((e) => e.tagName.toLowerCase() + (e.id ? "#" + e.id : ""));
        return {
          heading: document.querySelector("main h1")?.textContent.replace(/\s+/g, " ").trim() || "",
          primary: ctas.filter((e) => !e.classList.contains("ghost")).map((e) => ({
            text: e.textContent.replace(/\s+/g, " ").replace(/→/g, "").trim(), href: e.getAttribute("href") })),
          buttons: ctas.map((e) => e.textContent.replace(/\s+/g, " ").trim()),
          text: main.innerText,
          past: [...new Set(past)].slice(0, 4),
          scrollW: document.documentElement.scrollWidth, width,
          lang: document.documentElement.lang,
        };
      });
      const soon = say(code, "The desktop app is coming soon");
      const open = say(code, "Open Brickworks");
      const app = code === "en" ? "/app" : `/app?lang=${code}`;
      if (got.lang !== code) fail(where, `the page is in ${got.lang}`);
      if (got.heading !== soon) fail(where, `the heading says "${got.heading}", not "${soon}"`);
      if (got.primary.length !== 1 || got.primary[0].text !== open || got.primary[0].href !== app) {
        fail(where, `the primary buttons are ${JSON.stringify(got.primary)}, not one "${open}" to ${app}`);
      }
      const file = /[\w-]+\.(?:dmg|deb|msi|exe|AppImage|zip|tar\.xz)\b/i.exec(got.text);
      if (file) fail(where, `names a file, ${file[0]}`);
      const system = got.buttons.find((b) => /\b(?:linux|macos|mac|windows)\b/i.test(b));
      if (system) fail(where, `a button for a system, "${system}"`);
      if (asked.length) fail(where, `asked ${asked.slice(0, 2).join(", ")}`);
      if (said.length) fail(where, `the console said: ${said.slice(0, 2).join(" | ")}`);
      if (got.scrollW > got.width + 1) fail(where, `scrolls sideways, ${got.scrollW} in ${got.width}`);
      if (got.past.length) fail(where, `${got.past.join(", ")} past the edge`);
      console.log(`  ${(code + " " + width).padEnd(8)} "${got.heading}" · ${got.primary.map((p) => `"${p.text}" ${p.href}`).join(", ") || "no primary button"}`);
      await page.close();
    }
  }
  if (args.shots) {
    for (const scheme of ["light", "dark"]) {
      for (const width of [390, 1280]) {
        const page = await browser.newPage({ viewport: { width, height: 900 }, colorScheme: scheme, extraHTTPHeaders: bypass });
        for (const [name, path] of [["download", "/download"], ["home", "/"]]) {
          await page.goto(base + path, { waitUntil: "load", timeout: 30000 });
          await page.waitForLoadState("networkidle", { timeout: 5000 }).catch(() => {});
          const shot = join(args.shots, `${name}-${width}-${scheme}.png`);
          await page.screenshot({ path: shot, fullPage: true });
          console.log(`           ${shot}`);
        }
        await page.close();
      }
    }
  }
  await browser.close();
}

if (server) server.close();
if (made) await rm(made, { recursive: true, force: true });
for (const problem of problems) console.log(`  FAIL  ${problem}`);
console.log(problems.length ? `coming_soon: FAIL, ${problems.length} problem(s)`
  : "coming_soon: every page says the desktop app is coming soon, and none offers an installer");
process.exit(problems.length ? 1 : 0);
