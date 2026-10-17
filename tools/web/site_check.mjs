// Does the website around the app answer at the right addresses, and hold
// together on a phone and a laptop?
//
//   node tools/web/site_check.mjs --url=https://<deployment> [--out=shots/site] [--no-app]
//   (VERCEL_BYPASS in the environment for a protected preview)
//
// What it asks of a deployment, every answer read off the wire:
//
//   the pages answer 200 at their bare names (/, /gallery, /download, /changelog,
//     /compare, /faq, /privacy, /admin, /profile), each with its own title, description and canonical link and
//     an Open Graph card whose picture is really there; and so does the page
//     of the gallery's newest model, /m/<id>, made by api/share.js;
//   each old .html address answers 308 to its bare one, query and all, and
//     /authorize.html to /oauth/authorize; /download/ and /app/ lose the slash;
//   /app is the app itself — 200, no redirect — naming its build under
//     /b/<sha>/, with the isolation headers and the security policy the
//     build gets, and not cached; the build's files under /b/<sha>/ are;
//   an address with nothing at it answers 404 with the 404 page, at any
//     depth, inside /b/<sha>/ too; /parts/ and /sets/ keep their plain 404s;
//   sitemap.xml lists only pages that answer 200, and robots.txt keeps
//     /admin out;
//   every link, picture, clip, poster and script on every page resolves,
//     and every #fragment is an id on its page;
//   in a browser: no page logs an error, none scrolls sideways at 390 px,
//     and /app boots with the address bar still saying /app and its Help
//     panel's version.json found beside the build.
//
// Screenshots of every page at phone and laptop size go to --out.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("site_check: --url is required");
  process.exit(2);
}
const base = String(args.url).replace(/\/+$/, "");
const out = args.out || "shots/site";
mkdirSync(out, { recursive: true });
const bypass = args.bypass || process.env.VERCEL_BYPASS || "";
// The preview toolbar is Vercel's, never on the real site, and its script is
// refused by the site's own policy; skipped, so an error logged is the site's.
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SITE = "https://brickworks.diy";

const problems = [];
const fail = (text) => { problems.push(text); console.log(`  FAIL  ${text}`); };
const ok = (text) => console.log(`  ok    ${text}`);

async function get(path, method = "GET") {
  const url = path.startsWith("http") ? path : base + path;
  for (let attempt = 0; ; attempt += 1) {
    try {
      const response = await fetch(url, { method, headers, redirect: "manual" });
      const body = method === "GET" ? await response.text() : "";
      return { status: response.status, headers: response.headers, body };
    } catch (trouble) {
      if (attempt >= 2) return { status: 0, headers: new Headers(), body: String(trouble) };
      await new Promise((done) => setTimeout(done, 1500));
    }
  }
}

function meta(html, attr, name) {
  const tag = html.match(new RegExp(`<meta[^>]*${attr}="${name}"[^>]*>`, "i"));
  const content = tag && tag[0].match(/content="([^"]*)"/i);
  return content ? content[1] : "";
}

// -- the pages --------------------------------------------------------------

const PAGES = [
  { path: "/", canonical: `${SITE}/` },
  { path: "/download", canonical: `${SITE}/download` },
  { path: "/gallery", canonical: `${SITE}/gallery` },
  { path: "/changelog", canonical: `${SITE}/changelog` },
  { path: "/compare", canonical: `${SITE}/compare` },
  { path: "/faq", canonical: `${SITE}/faq` },
  { path: "/privacy", canonical: `${SITE}/privacy` },
  { path: "/takedown", canonical: `${SITE}/takedown` },
  { path: "/admin", private: true },
  { path: "/profile", private: true },
];
// The newest model in the gallery, whose page is the site's too.
// Asked past the CDN, which keeps the list for up to a minute: a model a
// probe has just taken down could still be first in a kept answer.
const newest = await get(`/api/share?op=list&page=1&fresh=${Date.now()}`);
let modelId = "";
try {
  modelId = (JSON.parse(newest.body).models || [])[0]?.id || "";
} catch {
  modelId = "";
}
if (newest.status !== 200) fail(`/api/share?op=list answered ${newest.status}`);
if (/^[A-Za-z0-9]{10}$/.test(modelId)) {
  // Its canonical address is the deployment's own: a preview's on a preview.
  PAGES.push({ path: `/m/${modelId}`, canonical: `${base}/m/${modelId}`, model: true });
} else {
  console.log("  note  nothing is listed, so no model's page is checked");
}
const pageHtml = {};
console.log("pages");
for (const page of PAGES) {
  const r = await get(page.path);
  pageHtml[page.path] = r.body;
  const type = r.headers.get("content-type") || "";
  if (r.status !== 200 || !type.startsWith("text/html")) {
    fail(`${page.path} answered ${r.status} ${type}`);
    continue;
  }
  const title = (r.body.match(/<title>([^<]*)<\/title>/i) || [])[1] || "";
  if (!title.trim()) fail(`${page.path} has no title`);
  if (page.private) {
    if (!/<meta[^>]*name="robots"[^>]*noindex/i.test(r.body)) fail(`${page.path} is not marked noindex`);
    ok(`${page.path} 200, "${title}", noindex`);
    continue;
  }
  const canonical = (r.body.match(/<link[^>]*rel="canonical"[^>]*href="([^"]*)"/i) || [])[1];
  if (canonical !== page.canonical && !(page.model && canonical === `${SITE}${page.path}`)) {
    fail(`${page.path} canonical is ${canonical}, not ${page.canonical}`);
  }
  const description = meta(r.body, "name", "description");
  if (description.length < 50) fail(`${page.path} has no real description`);
  const card = {};
  for (const name of ["og:title", "og:description", "og:url", "og:image", "og:type"]) {
    card[name] = meta(r.body, "property", name);
    if (!card[name]) fail(`${page.path} has no ${name}`);
  }
  for (const name of ["twitter:card", "twitter:image"]) {
    if (!meta(r.body, "name", name)) fail(`${page.path} has no ${name}`);
  }
  if (card["og:url"] && card["og:url"] !== canonical) fail(`${page.path} og:url ${card["og:url"]} is not its canonical`);
  if (card["og:image"]) {
    const home = page.model ? new URL(page.canonical).origin : SITE;
    if (!card["og:image"].startsWith(`${home}/`) && !card["og:image"].startsWith(`${SITE}/`)) {
      fail(`${page.path} og:image is not absolute: ${card["og:image"]}`);
    }
    const picture = await get(card["og:image"].replace(SITE, "").replace(base, ""));
    const kind = picture.headers.get("content-type") || "";
    if (picture.status !== 200 || !kind.startsWith("image/")) fail(`${page.path} og:image answers ${picture.status} ${kind}`);
  }
  ok(`${page.path} 200, "${title}", canonical, description, card with its picture`);
}

// A model's page's structured data, which has to parse too.
if (modelId) {
  const block = (pageHtml[`/m/${modelId}`] || "").match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
  try {
    const data = JSON.parse(block ? block[1] : "");
    if (data["@type"] !== "CreativeWork" || !data.name || !data.url) fail(`/m/${modelId} JSON-LD is not a CreativeWork with a name and a url`);
    else ok(`/m/${modelId} JSON-LD: CreativeWork "${data.name}"`);
  } catch (trouble) {
    fail(`/m/${modelId} JSON-LD does not parse: ${trouble.message}`);
  }
}

// The landing page's structured data, which is data and so has to parse.
{
  const block = (pageHtml["/"] || "").match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
  try {
    const data = JSON.parse(block ? block[1] : "");
    const types = (data["@graph"] || [data]).map((d) => d["@type"]);
    if (!types.includes("SoftwareApplication")) fail(`/ JSON-LD has no SoftwareApplication (${types})`);
    else ok(`/ JSON-LD: ${types.join(", ")}`);
  } catch (trouble) {
    fail(`/ JSON-LD does not parse: ${trouble.message}`);
  }
}

// -- old addresses ----------------------------------------------------------

console.log("redirects");
for (const [from, to] of [
  ["/index.html", "/"],
  ["/download.html", "/download"],
  ["/gallery.html", "/gallery"],
  ["/changelog.html", "/changelog"],
  ["/compare.html", "/compare"],
  ["/faq.html", "/faq"],
  ["/takedown.html", "/takedown"],
  ["/admin.html", "/admin"],
  ["/profile.html", "/profile"],
  ["/download.html?os=macos", "/download?os=macos"],
  ["/authorize.html", "/oauth/authorize"],
  ["/download/", "/download"],
  ["/app/", "/app"],
  ["/app/?view=AAAAAAAAAA", "/app?view=AAAAAAAAAA"],
]) {
  const r = await get(from);
  const where = (r.headers.get("location") || "").replace(base, "").replace(SITE, "");
  if (r.status !== 308 || where !== to) fail(`${from} answered ${r.status} -> ${where || "nowhere"}, not 308 -> ${to}`);
  else ok(`${from} 308 -> ${to}`);
}

// -- the app ----------------------------------------------------------------

console.log("the app");
const app = await get("/app");
const sha = ((app.body || "").match(/src="\/b\/([^/"]+)\/index\.js"/) || [])[1] || "";
let appCsp = "";
if (app.status !== 200) {
  fail(`/app answered ${app.status}${app.headers.get("location") ? " -> " + app.headers.get("location") : ""}, not the app`);
} else if (!sha) {
  fail("/app does not name its build's engine under /b/<sha>/");
} else {
  appCsp = app.headers.get("content-security-policy") || "";
  const want = { "cross-origin-opener-policy": "same-origin", "cross-origin-embedder-policy": "require-corp" };
  for (const [name, value] of Object.entries(want)) {
    if (app.headers.get(name) !== value) fail(`/app sends ${name}: ${app.headers.get(name)}`);
  }
  if (!/base-uri 'none'/.test(appCsp) || !/script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval' 'sha256-/.test(appCsp)) {
    fail(`/app's security policy is not the app's: ${appCsp.slice(0, 120)}`);
  }
  if (!/no-cache|no-store|max-age=0/.test(app.headers.get("cache-control") || "")) {
    fail(`/app is cached: ${app.headers.get("cache-control")}`);
  }
  const config = (app.body.match(/const GODOT_CONFIG = (\{.*?\});/) || [])[1] || "{}";
  const executable = JSON.parse(config).executable;
  if (executable !== `/b/${sha}/index`) fail(`/app's engine is ${executable}, not /b/${sha}/index`);
  ok(`/app 200, build ${sha}, isolated, its own policy, not cached`);

  // Visits counted by Overlook: on the public pages and the app, with the
  // per-person and secret paths left out, and never on admin or a model's
  // page. The policy must let it load and report, or it counts nothing
  // without a word.
  const counter = /<script defer src="https:\/\/overlook\.technology\/s\.js" data-site="ws_3frcuzvdsh" data-exclude="\/m\/\*\*,\/u\/\*\*,\/c\/\*\*,\/oauth\/\*\*,\/admin"><\/script>/;
  const counted = PAGES.filter((p) => !p.model && p.path !== "/admin").map((p) => p.path);
  for (const path of counted) {
    if (!counter.test(pageHtml[path] || "")) fail(`${path} does not count visits, or counts paths it must not`);
  }
  for (const path of PAGES.filter((p) => p.model || p.path === "/admin").map((p) => p.path)) {
    if (/overlook\.technology/.test(pageHtml[path] || "")) fail(`${path} loads the visit counter`);
  }
  if (!counter.test(app.body || "")) fail("/app does not count visits");
  if (!/script-src [^;]*https:\/\/overlook\.technology/.test(appCsp)
      || !/connect-src [^;]*https:\/\/overlook\.technology/.test(appCsp)) {
    fail("the policy does not let the visit counter load and report");
  }
  ok(`visits counted on ${counted.length} pages and the app, not on admin or a model's page`);

  const built = await get(`/b/${sha}/`);
  if (built.status !== 200 || built.headers.get("content-security-policy") !== appCsp) {
    fail(`/b/${sha}/ answered ${built.status}, or with another policy`);
  }
  for (const file of ["index.js", "index.wasm", "index.pck", "version.json"]) {
    const r = await get(`/b/${sha}/${file}`, "HEAD");
    const cache = r.headers.get("cache-control") || "";
    if (r.status !== 200) fail(`/b/${sha}/${file} answered ${r.status}`);
    else if (!cache.includes("immutable")) fail(`/b/${sha}/${file} is not cached for good: ${cache}`);
  }
  ok(`/b/${sha}/ and its files 200, cached for good`);
}

// -- nothing there ----------------------------------------------------------

console.log("not found");
for (const path of ["/no-such-page", "/deep/no/such/page", "/download/extra",
    `/b/${sha || "x"}/no-such-file.js`, "/img/none.webp"]) {
  const r = await get(path);
  if (r.status !== 404 || !r.body.includes("This brick is missing")) {
    fail(`${path} answered ${r.status}${r.headers.get("location") ? " -> " + r.headers.get("location") : ""}, not the 404 page`);
  } else ok(`${path} 404, the 404 page`);
}
for (const path of ["/parts/no-such-part.lbm", "/sets/no-such-shard.json"]) {
  const r = await get(path);
  if (r.status !== 404 || !(r.headers.get("content-type") || "").startsWith("text/plain")) {
    fail(`${path} answered ${r.status} ${r.headers.get("content-type")}, not a plain 404`);
  } else ok(`${path} 404, plain`);
}

// -- sitemap and robots -----------------------------------------------------

console.log("sitemap and robots");
const sitemap = await get("/sitemap.xml");
const listed = [...sitemap.body.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
if (sitemap.status !== 200 || !listed.length) fail(`sitemap.xml answered ${sitemap.status} with ${listed.length} pages`);
// Every model in the gallery is in it, the newest among them.
if (modelId && !listed.some((loc) => loc.endsWith(`/m/${modelId}`))) fail(`sitemap.xml does not list the newest model, /m/${modelId}`);
for (const loc of listed) {
  const r = await get(loc.replace(SITE, "") || "/");
  if (r.status !== 200) fail(`sitemap lists ${loc}, which answers ${r.status}`);
}
const robots = await get("/robots.txt");
if (robots.status !== 200 || !/Disallow: \/admin/.test(robots.body) || !/Sitemap: https:\/\/brickworks\.diy\/sitemap\.xml/.test(robots.body)) {
  fail(`robots.txt answered ${robots.status} without Disallow: /admin and the sitemap`);
}
if (!problems.some((p) => /sitemap|robots/.test(p))) ok(`sitemap.xml lists ${listed.length} pages, all 200; robots.txt keeps /admin out`);

// -- links and pictures -----------------------------------------------------

console.log("links and pictures");
const checked = new Map();
async function resolves(href, from) {
  const url = new URL(href, base + from);
  const local = url.origin === new URL(base).origin || url.origin === SITE;
  if (!local) {
    if (!checked.has(url.href)) {
      let status = 0;
      try {
        const r = await fetch(url.href, { method: "GET", redirect: "follow", headers: { "user-agent": "Mozilla/5.0 brickworks-site-check" } });
        status = r.status;
      } catch { status = 0; }
      checked.set(url.href, status);
    }
    const status = checked.get(url.href);
    // Somebody else's site: only a page that is gone is ours to fix. A
    // 403 or 429 is a bot wall, and a timeout is the network.
    if (status === 404 || status === 410) fail(`${from} links to ${url.href}, which is gone (${status})`);
    else if (status === 0 || status >= 400) console.log(`  note  ${from} links to ${url.href}: ${status || "no answer"}`);
    return;
  }
  const key = url.pathname + url.search;
  if (!checked.has(key)) checked.set(key, (await get(key)).status);
  if (checked.get(key) !== 200) fail(`${from} links to ${key}, which answers ${checked.get(key)}`);
  if (url.hash && url.hash.length > 1) {
    const target = url.pathname === "/" ? pageHtml["/"] : (pageHtml[url.pathname] || (await get(url.pathname)).body);
    if (!new RegExp(`id="${url.hash.slice(1)}"`).test(target || "")) fail(`${from} links to ${url.pathname}${url.hash}, and there is no such id`);
  }
}
for (const page of [...PAGES.map((p) => p.path), "/no-such-page"]) {
  const html = pageHtml[page] || (await get(page)).body;
  const hrefs = [...html.matchAll(/<a\b[^>]*href="([^"]+)"/g)].map((m) => m[1]);
  const pictures = [...html.matchAll(/<img\b[^>]*\ssrc="([^"]+)"/g)].map((m) => m[1]);
  for (const set of html.matchAll(/srcset="([^"]+)"/g)) {
    for (const item of set[1].split(",")) pictures.push(item.trim().split(/\s+/)[0]);
  }
  // The clips too (/compare's), their posters, and every script a page names:
  // a clip that is not there shows only its poster, and nothing says so.
  for (const m of html.matchAll(/<(?:source|script|video)\b[^>]*\s(?:src|poster)="([^"]+)"/g)) pictures.push(m[1]);
  const styles = [...html.matchAll(/<link\b[^>]*href="([^"]+)"/g)].map((m) => m[1]);
  let count = 0;
  for (const href of new Set(hrefs)) {
    if (href.startsWith("mailto:")) continue;
    if (href.startsWith("#")) {
      if (href.length > 1 && !html.includes(`id="${href.slice(1)}"`)) fail(`${page} links to ${href}, and there is no such id`);
      continue;
    }
    await resolves(href, page);
    count += 1;
  }
  for (const src of new Set([...pictures, ...styles])) {
    const key = new URL(src, base + page);
    if (key.origin !== new URL(base).origin && key.origin !== SITE) continue;
    const r = await get(key.pathname, "HEAD");
    if (r.status !== 200) fail(`${page} loads ${key.pathname}, which answers ${r.status}`);
    count += 1;
  }
  ok(`${page}: ${count} links, pictures and files resolve`);
}

// -- in a browser -----------------------------------------------------------

console.log("in a browser");
const browser = await launch({ signedOut: true });
const SHOTS = [["/", "home"], ["/gallery", "gallery"], ["/download", "download"], ["/changelog", "changelog"],
  ["/compare", "compare"], ["/faq", "faq"], ["/privacy", "privacy"], ["/admin", "admin"], ["/profile", "profile"], ["/takedown", "takedown"], ["/no-such-page", "404"], ...(modelId ? [[`/m/${modelId}`, "model"]] : [])];
for (const [label, width, height] of [["phone", 390, 844], ["laptop", 1280, 900]]) {
  for (const [path, name] of SHOTS) {
    const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers });
    const page = await context.newPage();
    const said = [];
    page.on("console", (m) => { if (m.type() === "error") said.push(m.text().slice(0, 160)); });
    page.on("pageerror", (e) => said.push(String(e).slice(0, 160)));
    try {
      await page.goto(base + path, { waitUntil: "load", timeout: 60000 });
      // The gallery draws its cards after load, from /api/share?op=list.
      await page.waitForFunction(() => !document.getElementById("models")
        || document.documentElement.dataset.gallery, null, { timeout: 20000 }).catch(() => {});
      // Every lazy picture in, so the full-page shot shows the page as read.
      await page.evaluate(async () => {
        for (const img of document.querySelectorAll("img[loading=lazy]")) img.loading = "eager";
        await Promise.all([...document.images].map((img) => img.decode().catch(() => {})));
      });
      await page.waitForTimeout(400);
      const seen = await page.evaluate(() => ({
        scrollW: document.documentElement.scrollWidth,
        clientW: document.documentElement.clientWidth,
        broken: [...document.images].filter((i) => !i.naturalWidth).map((i) => i.currentSrc || i.src),
      }));
      // A page's clips (/compare's): none fetched before it is scrolled to,
      // and each, scrolled to, playing on its own, muted. Playwright's
      // Chromium has no H.264, so this is the WebM; the MP4 is checked
      // above as a file that answers.
      const clips = await page.evaluate(() => [...document.querySelectorAll("video[data-play]")]
        .map((v) => ({ below: v.getBoundingClientRect().top > innerHeight, loading: v.networkState === 2 })));
      if (clips.length) {
        const early = clips.filter((c) => c.below && c.loading).length;
        if (early) fail(`${path} at ${label} width fetches ${early} clips before they are scrolled to`);
        const played = [];
        for (let n = 0; n < clips.length; n++) {
          await page.evaluate((i) => document.querySelectorAll("video[data-play]")[i].scrollIntoView({ block: "center" }), n);
          await page.waitForTimeout(4000);
          played.push(await page.evaluate((i) => {
            const v = document.querySelectorAll("video[data-play]")[i];
            return { time: v.currentTime, paused: v.paused, muted: v.muted, src: v.currentSrc.split("/").pop() };
          }, n));
        }
        const still = played.filter((p) => p.paused || p.time < 0.5 || !p.muted);
        if (still.length) fail(`${path} at ${label} width: ${still.length} of ${clips.length} clips did not play, muted: ${JSON.stringify(still)}`);
        else ok(`${path} at ${label} width: ${clips.length} clips play muted when scrolled to (${played.map((p) => p.src).join(", ")})`);
        await page.evaluate(() => window.scrollTo(0, 0));
      }
      if (seen.scrollW > seen.clientW + 1) fail(`${path} at ${label} width scrolls sideways (${seen.scrollW}px in ${seen.clientW}px)`);
      if (seen.broken.length) fail(`${path} at ${label} width has broken pictures: ${seen.broken.slice(0, 3).join(", ")}`);
      // A 404 is the page's own answer here, not an error in it.
      const errors = said.filter((t) => !(name === "404" && /404/.test(t)));
      if (errors.length) fail(`${path} at ${label} width logged: ${errors.slice(0, 2).join(" | ")}`);
      await page.screenshot({ path: `${out}/${name}-${label}.png`, fullPage: true, timeout: 30000 });
    } catch (trouble) {
      fail(`${path} at ${label} width: ${trouble.message.split("\n")[0]}`);
    }
    await context.close();
  }
  ok(`${label}: ${SHOTS.length} pages, shots in ${out}/`);
}
await browser.close();

// The visit counter itself, loaded once from its own server as a visitor's
// browser loads it: the pages above had it answered here (browser.mjs,
// quietCounter), so a burst of checks never trips its server's limit.
// Under the site's isolation it must come with its own resource policy, or
// the browser blocks it and nothing is counted.
{
  const real = await launch({ signedOut: true, realCounter: true });
  const context = await real.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  const page = await context.newPage();
  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text().slice(0, 160)); });
  const counter = page.waitForResponse((r) => r.url() === "https://overlook.technology/s.js", { timeout: 30000 }).catch(() => null);
  await page.goto(base + "/", { waitUntil: "load", timeout: 60000 }).catch(() => {});
  const answer = await counter;
  if (!answer || answer.status() !== 200) fail(`the visit counter did not load: ${answer ? answer.status() : "no answer"}`);
  else if (answer.headers()["cross-origin-resource-policy"] !== "cross-origin") fail("the visit counter has no Cross-Origin-Resource-Policy, so isolation blocks it");
  else if (errors.length) fail(`the page with the real visit counter logged: ${errors[0]}`);
  else ok("the visit counter loads from its own server, past the page's isolation");
  await real.close();
}

// The app, signed in as anyone using it is, at its own address.
if (sha && args["no-app"] === undefined) {
  const appBrowser = await launch();
  const context = await appBrowser.newContext({ viewport: { width: 1280, height: 800 }, extraHTTPHeaders: headers });
  const page = await context.newPage();
  try {
    await page.goto(`${base}/app?view=AAAAAAAAAA`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.goto(`${base}/app`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.waitForSelector("#boot.done", { state: "attached", timeout: 240000 });
    const where = await page.evaluate(() => location.pathname + location.search);
    if (where !== "/app") fail(`after it booted the address bar says ${where}, not /app`);
    const version = await page.evaluate(async () => {
      const at = new URL("version.json", new URL(GODOT_CONFIG.executable, location.href)).href;
      const r = await fetch(at);
      return { at, status: r.status, body: r.ok ? await r.json() : null };
    });
    if (version.status !== 200 || !version.body || !String(sha).startsWith(String(version.body.commit).replace(/-dirty$/, ""))) {
      fail(`the Help panel's version.json (${version.at}) answered ${version.status}: ${JSON.stringify(version.body)}`);
    } else ok(`/app booted at /app; version.json ${new URL(version.at).pathname} says ${version.body.commit}`);
    await page.screenshot({ path: `${out}/app-laptop.png`, timeout: 20000 }).catch(() => {});
  } catch (trouble) {
    fail(`/app did not boot: ${trouble.message.split("\n")[0]}`);
  }
  await appBrowser.close();
}

if (problems.length) {
  console.log(`site_check: ${problems.length} problem(s)`);
  process.exit(1);
}
console.log(`site_check ok: ${base}`);
