// The site on a home screen, offline, and this device's notifications
// (homescreen, 2026-11-22: web/sw.js, web/push.js, api/_push.js,
// supabase/push.sql), in real browsers:
//
//   fresh     two deploys on one address (a server here, switched under a
//             page the worker controls): the next load is the new deploy's
//             page and stylesheet, never a kept one; a worker changed
//             takes over and drops the old one's copies; an error the
//             server sends is shown as sent, and only a server that cannot
//             be reached gets the offline page; a deploy that changes the
//             offline page alone (the worker's file the same) has it kept
//             new once a page is opened, by its own content (hsfix N7).
//   install   Chromium finds the site installable (no installability
//             errors, the manifest read without one) at 390 and 1280.
//   offline   with the network cut, a page not seen before is the offline
//             page in its address's language, and so is the app (/app,
//             where the installed app opens: hsfix S4); it opens the page
//             asked for by itself once the network is back.
//   requests  the app's build (/b/) and the engine (/e/) never answered by
//             the worker, /app only passed through from the network (each
//             response's fromServiceWorker, logged to requests.txt), and
//             nothing of them in its cache.
//   offer     the offer to install: none on a first visit; on a second the
//             card, No thanks kept (and Undo), a toast pointing at
//             Settings; on an iPhone (WebKit), how to add it.
//   time      a first visit waits on nothing of it: push.js and the worker
//             asked for only after the page's load, in each of three
//             first visits; their load and first paint beside the same
//             visit with workers blocked, at the same moment.
//   push      Ada turns this device on in Settings (the browser's prompt
//             only then), Bob comments on her model, and the push is shown
//             on her device within 60 s, measured; turned off, his next
//             comment shows nothing in 60 s. Each comment is followed by a
//             knock signed in as Ada (a throwaway): off brickworks.diy only a
//             check's own account is taken, and brickworks.diy's own knock
//             leaves those alone (api/_push.js, hsfix S1), so this deploy's
//             code is what sends. Then each way it stops: the header's Sign
//             out (the device forgotten, hsfix F2), Turn off on every device
//             (S2), her sign-in ended at Supabase (the device goes with it),
//             her account deleted (push_subscribed, after each), and Bob
//             signed in on the same browser.
//   look      Settings › Notifications, the offline page and the offer at
//             390, 768 and 1280, light and dark, nothing sideways.
//
//   node --env-file=.env tools/web/relay_server.mjs 8840 &   (VAPID_PRIVATE_KEY in its env)
//   node --env-file=.env tools/web/homescreen_flow.mjs --url=http://127.0.0.1:8840 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/homescreen_flow.mjs --url=<preview> --out=DIR
//
// --parts=fresh,install,... runs those alone. A push needs a browser with a
// profile of its own (push is off in a private context), so the push part
// opens one in a folder of its own: headless Chromium, Chromium in a window
// (an Xvfb of its own) and Firefox in turn, until one reaches a push service
// (DEVICES), or --device=headless|window|firefox. Throwaway accounts at
// Resend's test addresses, deleted at the end with their models. Pictures
// and the request log in --out.
import { bypassCookie, instantScroll, launch, quietCounter, SOFTWARE } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { chromium, firefox } from "playwright";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:8840").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/homescreen"));
mkdirSync(out, { recursive: true });
const ALL = ["fresh", "install", "offline", "requests", "offer", "time", "push", "look"];
const parts = new Set(args.parts ? String(args.parts).split(",") : ALL);
const bypass = process.env.BW_BYPASS || "";
// The bypass header alone. The worker's own requests carry the bypass
// cookie, which browser.mjs's bypassCookie asks for once in each context,
// before its first page. Asked for in this header instead, on every request,
// a preview answers each request without the cookie by a 307 back to
// itself that sets it: node's fetch keeps no cookies and went round to
// "redirect count exceeded" (push's "fetch failed"), and so did Chromium's
// fetch of the manifest, which is sent without cookies, so Chromium read no
// manifest while it found the site installable (rel-m319, twice each).
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-home-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-home-bob-${rand}@resend.dev`;
const ADA = `bwh-ada-${rand}`;
const BOB = `bwh-bob-${rand}`;
const FRESH_PORT = Number(args["fresh-port"] || 11004);

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const note = (what) => console.log(`  --    ${what}`);
/// What went wrong, with what it came from: node's fetch says only "fetch
/// failed", its cause (a refused connection, a timeout, a name not found)
/// is the error (rel-m319's push, twice).
const why = (trouble) => {
  const said = [String(trouble?.message || trouble)];
  for (let cause = trouble?.cause; cause && said.length < 4; cause = cause.cause) {
    said.push([cause.code, cause.message || String(cause)].filter(Boolean).join(" "));
  }
  return said.join(": ");
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
const shot = (page, name, { full = false, clip = null } = {}) => page.screenshot({ path: path.join(out, name), fullPage: full,
  ...(clip ? { clip } : {}), timeout: 90000 }).catch((trouble) => note(`no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) })
    .catch((trouble) => {
      throw new Error(`${method} ${pathname.split("?")[0]}${pathname.includes("?op=") ? `?op=${new URL(pathname, "http://x").searchParams.get("op")}` : ""}: ${why(trouble)}`);
    });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

/// supabase/push.sql's push_subscribed, asked of the project itself.
async function subscribed(account, endpoint) {
  const url = process.env.SUPABASE_URL;
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!url || !secret) return null;
  const reply = await fetch(`${url}/rest/v1/rpc/push_subscribed`, { method: "POST",
    headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" },
    body: JSON.stringify({ p_account: account, p_endpoint: endpoint }) }).catch(() => null);
  return reply?.ok ? reply.json() : { status: reply?.status ?? 0 };
}

/// The worker in control of [page]'s window, waited for.
const controlled = (page, seconds = 45) => until(page, () => Boolean(navigator.serviceWorker?.controller), "the worker in control", seconds);
/// What the worker keeps: {caches: [names], kept: [paths]}.
const kept = (page) => page.evaluate(async () => {
  const names = await caches.keys();
  const paths = [];
  for (const name of names) for (const request of await (await caches.open(name)).keys()) paths.push(new URL(request.url).pathname);
  return { caches: names, kept: paths.sort() };
});
const offlineShown = (page) => page.evaluate(() => ({ offline: document.documentElement.hasAttribute("data-offline"),
  lang: document.documentElement.lang, h1: document.querySelector("h1")?.textContent.trim() || "", at: location.pathname }));

const browser = await launch({ signedOut: true });
async function context({ as = null, width = 1280, height = 900, phone = false, theme = "dark", workers = "allow", extra = {} } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, colorScheme: theme,
    serviceWorkers: workers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}), ...extra });
  if (as) await seed(made, as);
  return made;
}
/// Signed in as [as] in [made], once a tab, as the site keeps a session.
async function seed(made, as) {
  await made.addInitScript(([name, value]) => {
    try {
      if (!sessionStorage.getItem("flow.seeded") && !localStorage.getItem(name)) localStorage.setItem(name, value);
      sessionStorage.setItem("flow.seeded", "1");
    } catch {}
  }, [STORAGE_KEY, JSON.stringify(as.kept)]);
}

// ---------------------------------------------------------------------------
// fresh: two deploys on one address, here.

async function fresh() {
  console.log("fresh: two deploys on one address (a server here)");
  const web = path.join(root, "web");
  let deploy = "A";
  let down = false;
  const seen = [];
  const typeOf = { html: "text/html; charset=utf-8", js: "text/javascript", css: "text/css", png: "image/png",
    svg: "image/svg+xml", json: "application/json", webmanifest: "application/manifest+json", webp: "image/webp" };
  const changed = (file, text) => {
    if (deploy === "A") return text;
    if (file === "gallery.html") return text.replace("</head>", `<meta name="deploy" content="${deploy}">\n</head>`);
    if (file === "site.css") return `${text}\n:root { --deploy: "${deploy}"; }\n`;
    // A file the worker never touches: the browser's own caching, as ever.
    if (file === "gallery.js") return `window.brickworksDeploy = "${deploy}";\n${text}`;
    if (file === "sw.js" && deploy >= "C") return text.replace(/const VERSION = "([^"]+)";/, 'const VERSION = "$1-c";');
    if (file === "offline.html" && deploy === "E") return text.replace("</head>", `<meta name="deploy" content="E">\n</head>`);
    return text;
  };
  const sockets = new Set();
  const server = createServer((request, response) => {
    const url = new URL(request.url, "http://here");
    seen.push(`${deploy} ${url.pathname}`);
    if (url.pathname.startsWith("/api/")) {
      response.writeHead(404, { "content-type": "application/json" });
      return response.end("{}");
    }
    if (deploy === "D" && url.pathname === "/gallery") {
      response.writeHead(503, { "content-type": "text/html" });
      return response.end("<!doctype html><title>down</title><h1>deploy D answers 503</h1>");
    }
    const lang = /^\/(de|fr|es)(\/.*)?$/.exec(url.pathname);
    let file = lang ? `${lang[1]}/${(lang[2] || "/index").replace(/^\//, "") || "index"}` : url.pathname.slice(1) || "index";
    if (!/\.[a-z]+$/.test(file)) file += ".html";
    const full = path.join(web, file);
    if (!full.startsWith(web) || !existsSync(full)) {
      response.writeHead(404, { "content-type": "text/html" });
      return response.end(readFileSync(path.join(web, "404.html")));
    }
    const ext = file.split(".").pop();
    const body = ["html", "css", "js"].includes(ext) ? changed(file, readFileSync(full, "utf8")) : readFileSync(full);
    response.writeHead(200, { "content-type": typeOf[ext] || "application/octet-stream", "cache-control": "public, max-age=0, must-revalidate" });
    response.end(body);
  });
  server.on("connection", (socket) => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
    if (down) socket.destroy();
  });
  await new Promise((resolve) => server.listen(FRESH_PORT, "127.0.0.1", resolve));
  const L = `http://127.0.0.1:${FRESH_PORT}`;
  const made = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await made.newPage();
  listen(page, "fresh");
  const deployed = () => page.evaluate(() => ({ page: document.querySelector('meta[name="deploy"]')?.content || "A",
    css: getComputedStyle(document.documentElement).getPropertyValue("--deploy").trim().replace(/"/g, "") || "A",
    script: window.brickworksDeploy || "A" }));
  try {
    await page.goto(`${L}/gallery`, { waitUntil: "load" });
    await controlled(page);
    let first = await kept(page);
    check(`deploy A: the worker in control, keeping only the offline pages and what they are drawn with: ${first.caches.join(",")}: ${first.kept.join(" ")}`,
      first.caches.length === 1 && first.kept.includes("/offline") && first.kept.includes("/site.css")
      && first.kept.every((one) => /^\/(?:(?:de|fr|es)\/)?offline$|^\/(?:site\.css|theme\.js|push\.js|favicon-32\.png|icon\.svg)$/.test(one)));
    deploy = "B";
    const response = await page.goto(`${L}/gallery`, { waitUntil: "load" });
    let now = await deployed();
    check(`deploy B, its first load: page ${now.page}, stylesheet ${now.css}, a script it never touches ${now.script} `
      + `(the page through the worker: ${response.fromServiceWorker()})`, now.page === "B" && now.css === "B" && now.script === "B");
    await page.goto(`${L}/library`, { waitUntil: "load" });
    now = await deployed();
    check(`deploy B, another page: stylesheet ${now.css}`, now.css === "B");
    deploy = "C";
    await page.goto(`${L}/gallery`, { waitUntil: "load" });
    now = await deployed();
    check(`deploy C (the worker changed), its first load: page ${now.page}, stylesheet ${now.css}`, now.page === "C" && now.css === "C");
    const after = await until(page, async () => {
      const names = await caches.keys();
      return names.length === 1 && names[0].endsWith("-c") ? names : null;
    }, "the new worker's copies alone", 45).catch(() => null);
    check(`deploy C's worker took over and dropped the old copies: ${after ? after.join(",") : (await kept(page)).caches.join(",")}`, Boolean(after));
    deploy = "D";
    await page.goto(`${L}/gallery`, { waitUntil: "load" });
    const shown = await page.evaluate(() => ({ h1: document.querySelector("h1")?.textContent || "", offline: document.documentElement.hasAttribute("data-offline") }));
    check(`a 503 from the server is shown as sent, not the offline page: "${shown.h1}"`, shown.h1.includes("503") && !shown.offline);
    deploy = "C";
    down = true;
    for (const socket of sockets) socket.destroy();
    await page.goto(`${L}/compare`, { waitUntil: "load" }).catch(() => null);
    const gone = await offlineShown(page);
    check(`the server unreachable: the offline page at ${gone.at}, "${gone.h1}"`, gone.offline && gone.at === "/compare" && gone.h1 === "You’re offline.");
    await shot(page, "fresh_offline-1280-dark.png");
    // Deploy E changes the offline page and the stylesheet, not the worker:
    // once a page is opened (by a worker started afresh, as the browser
    // starts one after it idles), the kept copies are E's.
    down = false;
    deploy = "E";
    const cdp = await made.newCDPSession(page);
    await cdp.send("ServiceWorker.enable").catch(() => null);
    await cdp.send("ServiceWorker.stopAllWorkers").catch((trouble) => note(`workers not stopped: ${String(trouble).split("\n")[0]}`));
    await page.goto(`${L}/gallery`, { waitUntil: "load" });
    const keptE = await until(page, async () => {
      const kept = await caches.open((await caches.keys())[0]);
      const offline = await (await kept.match("/offline"))?.text();
      const css = await (await kept.match("/site.css"))?.text();
      return offline?.includes('content="E"') && css?.includes('--deploy: "E"') ? "E" : null;
    }, "the kept offline page and stylesheet E's", 45).catch(() => null);
    down = true;
    for (const socket of sockets) socket.destroy();
    await page.goto(`${L}/compare`, { waitUntil: "load" }).catch(() => null);
    const shownE = await page.evaluate(() => ({ offline: document.documentElement.hasAttribute("data-offline"),
      page: document.querySelector('meta[name="deploy"]')?.content || "", css: getComputedStyle(document.documentElement)
        .getPropertyValue("--deploy").trim().replace(/"/g, "") }));
    check(`deploy E (the offline page changed, the worker not): kept ${keptE || "not E's"}; with the server unreachable the `
      + `offline page is E's (${shownE.page || "?"}), drawn with E's stylesheet (${shownE.css || "?"})`,
      keptE === "E" && shownE.offline && shownE.page === "E" && shownE.css === "E");
  } catch (trouble) {
    check(`fresh: ${trouble.message}`, false);
  } finally {
    writeFileSync(path.join(out, "fresh_requests.txt"), `${seen.join("\n")}\n`);
    await made.close();
    for (const socket of sockets) socket.destroy();
    server.close();
  }
}

// ---------------------------------------------------------------------------
// install: Chromium's own installability.

async function install() {
  console.log("install: Chromium finds the site installable");
  for (const [width, height, phone] of [[390, 844, true], [1280, 900, false]]) {
    const made = await context({ width, height, phone });
    const page = await made.newPage();
    listen(page, `install ${width}`);
    try {
      await page.goto(`${site}/`, { waitUntil: "load" });
      await controlled(page);
      const cdp = await made.newCDPSession(page);
      // Chromium's own reading of the manifest. On rel-m319 it said nothing
      // at all (no address, no data) while the same step found the site
      // installable, and what went wrong was dropped unsaid: so it is asked
      // again while it says no address (three times at most, each said),
      // and a refusal is printed.
      let manifest = {};
      let tries = 0;
      while (tries < 3 && !manifest.url) {
        if (tries) await page.waitForTimeout(1000);
        tries += 1;
        manifest = await cdp.send("Page.getAppManifest").catch((trouble) => ({ trouble: String(trouble).split("\n")[0] }));
      }
      if (!manifest.url) {
        // What Chromium had to read: the page's link, and the file as the
        // page itself is answered it.
        const seen = await page.evaluate(async () => {
          const links = [...document.querySelectorAll("link[rel=manifest]")].map((one) => `${one.getAttribute("href")} ${one.crossOrigin || "-"}`);
          const answer = await fetch("/site.webmanifest", { credentials: "omit" }).catch((trouble) => ({ status: String(trouble) }));
          return { links, at: location.href, status: answer.status, redirected: answer.redirected, type: answer.type,
            url: answer.url, ctype: answer.headers?.get?.("content-type") };
        }).catch((trouble) => ({ trouble: String(trouble).split("\n")[0] }));
        note(`${width} px: Chromium's manifest said ${JSON.stringify({ ...manifest, data: manifest.data ? `${manifest.data.length} chars` : manifest.data }).slice(0, 600)}`);
        note(`${width} px: the page ${JSON.stringify(seen).slice(0, 600)}`);
      }
      const said = await cdp.send("Page.getInstallabilityErrors").catch((trouble) => ({ trouble: String(trouble).split("\n")[0] }));
      const errs = (said.installabilityErrors || []).map((one) => one.errorId);
      // Its text as served (data), else Chromium's structured reading of it.
      let parsed = {};
      try {
        parsed = manifest.data ? JSON.parse(manifest.data) : manifest.manifest || {};
      } catch (trouble) {
        parsed = { name: `(not JSON: ${String(trouble).slice(0, 80)})` };
      }
      check(`${width} px: the manifest at ${manifest.url ? new URL(manifest.url).pathname : "?"}, ${(manifest.errors || []).length} errors, `
        + `"${parsed.name}" ${parsed.display}, ${parsed.icons?.length} icons (asked ${tries} times`
        + `${manifest.trouble ? `; ${manifest.trouble}` : ""})`,
        Boolean(manifest.url) && !(manifest.errors || []).length && parsed.name === "Brickworks" && parsed.icons?.length >= 3);
      check(`${width} px: installable, no installability errors${said.trouble ? ` (${said.trouble})` : `: [${errs.join(", ")}]`}`,
        !said.trouble && errs.length === 0);
      for (const icon of parsed.icons || []) {
        const got = await page.evaluate(async (src) => {
          const image = new Image();
          image.src = src;
          await image.decode().catch(() => null);
          return `${image.naturalWidth}x${image.naturalHeight}`;
        }, icon.src);
        check(`${width} px: icon ${icon.src} ${icon.purpose} is ${got}, as said (${icon.sizes})`, got === icon.sizes);
      }
    } catch (trouble) {
      check(`install ${width}: ${trouble.message}`, false);
    }
    await made.close();
  }
}

// ---------------------------------------------------------------------------
// offline: the network cut, for the page and its worker alike.

async function offline() {
  console.log("offline: the network cut");
  const made = await context({ width: 1280, height: 900 });
  let page = await made.newPage();
  listen(page, "offline");
  // The network cut as a device's is, for its pages and its worker alike.
  // Playwright's setOffline cuts the requests of both, but says it to the
  // pages by a DevTools call Chromium has deprecated: a page that loaded
  // after the cut read navigator.onLine true (browser.mjs's own DevTools
  // session on each page undoes it), so it never heard the network come
  // back; and each navigation flickered online and offline again in the page
  // being left, whose offline page (web/push.js) reloaded itself on the
  // flicker and took the tab back from the next address (/de/library showed
  // /library's offline page, /library /app's: m319home, 2026-11-23). So the
  // pages are told it by Chromium's own call for it (overrideNetworkState),
  // each address is opened in a tab of its own, as a page not seen before,
  // and the network comes back for the worker before the page hears it.
  const sayOffline = async (tab, offline) => {
    tab.devtools ||= await made.newCDPSession(tab);
    await tab.devtools.send("Network.overrideNetworkState", { offline, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
  };
  const openOffline = async (address) => {
    await page.close();
    page = await made.newPage();
    listen(page, "offline");
    await sayOffline(page, true);
    const gone = await page.goto(`${site}${address}`, { waitUntil: "load" }).then(() => "",
      (trouble) => ` (the goto: ${String(trouble.message || trouble).split("\n")[0].slice(0, 120)})`);
    return { ...(await offlineShown(page)), gone };
  };
  try {
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await controlled(page);
    // The worker keeps English's offline page and the browser's language's,
    // and another's once a page in it is opened online (web/sw.js, hsfix N7,
    // a6167673b): a German page first, as a German reader comes, and its
    // offline page kept before the network is cut.
    await page.goto(`${site}/de/gallery`, { waitUntil: "load" });
    await until(page, async () => Boolean(await caches.match("/de/offline")), "the German offline page kept", 30);
    await made.setOffline(true);
    const en = await openOffline("/library");
    check(`/library, offline: the offline page in ${en.lang}: "${en.h1}"${en.gone}`, en.offline && en.at === "/library" && en.lang === "en" && en.h1 === "You’re offline.");
    await shot(page, "offline_cut-1280-dark.png");
    const de = await openOffline("/de/library");
    check(`/de/library, offline: the offline page in ${de.lang}: "${de.h1}" at ${de.at}${de.gone}`,
      de.offline && de.at === "/de/library" && de.lang === "de" && de.h1 === "Du bist offline.");
    // Where the installed app opens: the site's offline page, not the browser's.
    const app = await openOffline("/app");
    check(`/app, offline (the installed app's start): the offline page: "${app.h1}" at ${app.at}${app.gone}`,
      app.offline && app.at === "/app" && app.h1 === "You’re offline.");
    await shot(page, "offline_app-1280-dark.png");
    // The offline page hears the network come back through web/push.js,
    // which theme.js asks for only after the load: the network came back
    // the moment the page had loaded, before it listened, and nothing
    // reloaded it (here and on hsfix's local run). So the network comes
    // back once push.js has run, which writes this visit first thing.
    await page.evaluate(() => localStorage.removeItem("brickworks.visits"));
    await openOffline("/library");
    await until(page, () => document.documentElement.hasAttribute("data-offline") && Boolean(localStorage.getItem("brickworks.visits")),
      "the offline page listening (push.js run)", 30);
    // What happens once it is back, said if it fails: whether the page heard
    // the network return (online, kept in sessionStorage across a reload),
    // and each page the tab then showed.
    await page.evaluate(() => addEventListener("online", () => sessionStorage.setItem("flow.online", String(Date.now()))));
    const shown = [];
    page.on("response", (response) => {
      if (response.request().isNavigationRequest() && response.frame() === page.mainFrame()) {
        shown.push(`${response.status()} ${response.url().replace(site, "")}${response.fromServiceWorker() ? " (worker)" : ""}`);
      }
    });
    page.on("requestfailed", (request) => {
      if (request.isNavigationRequest()) shown.push(`failed ${request.url().replace(site, "")}: ${request.failure()?.errorText}`);
    });
    await made.setOffline(false);
    await sayOffline(page, false);
    await until(page, () => !document.documentElement.hasAttribute("data-offline") && location.pathname === "/library"
      && document.readyState === "complete", "the page asked for, once the network is back", 30).catch(async (trouble) => {
      const state = await page.evaluate(() => ({ at: location.href, offline: document.documentElement.hasAttribute("data-offline"),
        ready: document.readyState, onLine: navigator.onLine, heard: sessionStorage.getItem("flow.online"),
        h1: document.querySelector("h1")?.textContent.trim() || "" })).catch((e) => ({ trouble: String(e).split("\n")[0] }));
      note(`the network back: ${JSON.stringify(state).replace(site, "")}; the tab showed ${shown.join(", ") || "nothing new"}`);
      throw trouble;
    });
    check(`the network back: /library itself, by itself (${shown.join(", ")})`, true);
  } catch (trouble) {
    check(`offline: ${trouble.message}`, false);
  }
  await made.close();
}

// ---------------------------------------------------------------------------
// requests: what the worker answers, logged.

async function requests() {
  console.log("requests: /b/ and /e/ never the worker's, /app only the network's");
  const made = await context({ width: 1280, height: 900 });
  const log = [];
  made.on("response", (response) => {
    const url = new URL(response.url());
    if (url.origin === new URL(site).origin) log.push({ path: url.pathname, status: response.status(), worker: response.fromServiceWorker() });
  });
  const page = await made.newPage();
  listen(page, "requests");
  try {
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await controlled(page);
    await page.goto(`${site}/download`, { waitUntil: "load" });
    const through = log.find((one) => one.path === "/download");
    note(`a page of the site goes through the worker (from the network): /download fromServiceWorker ${through?.worker}`);
    const app = await made.newPage();
    await app.goto(`${site}/app`, { waitUntil: "commit" });
    const end = Date.now() + 120000;
    while (Date.now() < end && !(log.some((one) => one.path.startsWith("/e/")) && log.some((one) => one.path.startsWith("/b/")))) {
      await app.waitForTimeout(500);
    }
    const appCount = await app.evaluate(() => Boolean(navigator.serviceWorker?.controller)).catch(() => null);
    await app.close();
    const theirs = log.filter((one) => /^\/(?:app$|b\/|e\/)/.test(one.path));
    // /app itself is passed through (the network's answer, never kept), so
    // the offline page can stand in for it; its files are not even seen.
    const byWorker = theirs.filter((one) => one.worker && one.path !== "/app");
    const others = log.filter((one) => one.worker && !/^\/(?:app|gallery|download|site\.css|theme\.js|push\.js|favicon-32\.png|icon\.svg)$/.test(one.path));
    check(`/app and its files: ${theirs.length} responses (/app ${theirs.filter((one) => one.path === "/app").length}, `
      + `/b/ ${theirs.filter((one) => one.path.startsWith("/b/")).length}, /e/ ${theirs.filter((one) => one.path.startsWith("/e/")).length}), `
      + `none of its files from the worker: ${byWorker.length} (the app's window controlled: ${appCount})`,
      theirs.some((one) => one.path === "/app") && theirs.some((one) => one.path.startsWith("/e/")) && byWorker.length === 0);
    note(`what else went through the worker (the browser's routing lets only pages and the offline page's five by): ${others.length ? others.map((one) => one.path).slice(0, 8).join(" ") : "nothing"}`);
    const cache = await kept(page);
    check(`nothing of /app, /b/, /e/ or /api/ in the worker's cache: ${cache.kept.join(" ")}`,
      !cache.kept.some((one) => /^\/(?:app|b\/|e\/|api\/)/.test(one)));
  } catch (trouble) {
    check(`requests: ${trouble.message}`, false);
  }
  writeFileSync(path.join(out, "requests.txt"), `${log.map((one) => `${one.worker ? "worker " : "network"} ${one.status} ${one.path}`).join("\n")}\n`);
  await made.close();
}

// ---------------------------------------------------------------------------
// offer: from a second visit, No thanks kept.

/// The browser's offer to install, as Chrome makes it when the site is
/// installable, where a headless one has not: the event push.js holds.
const offerNow = (page) => page.evaluate(() => {
  if (window.brickworksInstall) return "the browser's";
  const event = new Event("beforeinstallprompt", { cancelable: true });
  event.prompt = async () => {};
  event.userChoice = Promise.resolve({ outcome: "dismissed", platform: "" });
  dispatchEvent(event);
  return "a stand-in for the browser's";
});
const card = (page) => page.evaluate(() => {
  const one = document.querySelector(".install-offer");
  return one ? { words: one.querySelector(".words")?.textContent || "", buttons: [...one.querySelectorAll("button")].map((b) => b.textContent),
    // Not offsetParent: the offer is a .site-notice, position: fixed
    // (site.css), whose offsetParent is always null.
    shown: one.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) && one.getBoundingClientRect().height > 0 } : null;
});
const visits = (n) => ({ n, last: Date.now() - 2 * 3600e3 });
/// The owner's notice, if one is up, hidden in this browser as its × hides
/// it: the offer never shows over it (web/push.js), so the next page.
const hideNotice = async (page) => {
  await page.waitForTimeout(1500);
  const id = await page.evaluate(() => {
    const shown = document.querySelector("aside.site-notice:not(.install-offer)");
    const raw = shown?.dataset.id;
    if (raw) localStorage.setItem("brickworks.notice.hidden", JSON.stringify(/^\d+$/.test(raw) ? Number(raw) : raw));
    return raw || null;
  });
  if (id) note(`the owner's notice ${id} was up: hidden in this browser, as its × does`);
};

async function offer({ width = 1280, height = 900, phone = false, theme = "dark", pictures = true } = {}) {
  const made = await context({ width, height, phone, theme });
  const page = await made.newPage();
  listen(page, `offer ${width}`);
  try {
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await hideNotice(page);
    const whose = await offerNow(page);
    await page.waitForTimeout(2500);
    check(`${width} ${theme}: a first visit, no offer (${whose} offer held)`, (await card(page)) === null);
    await page.evaluate((v) => localStorage.setItem("brickworks.visits", JSON.stringify(v)), visits(1));
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await offerNow(page);
    await until(page, () => {
      const one = document.querySelector(".install-offer");
      return Boolean(one?.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) && one.getBoundingClientRect().height > 0);
    }, "the offer on a second visit", 15);
    const drawn = await card(page);
    check(`${width} ${theme}: a second visit, the offer: "${drawn.words.slice(0, 60)}…" [${drawn.buttons.join(", ")}], nothing sideways`,
      drawn.buttons.join(",") === "No thanks,Install" && !(await sideways(page)));
    if (pictures) await shot(page, `offer-${width}-${theme}.png`);
    if (!pictures) return;
    await page.click(".install-offer button:has-text('No thanks')");
    await until(page, () => !document.querySelector(".install-offer"), "the offer gone", 5);
    const toast = await until(page, () => document.querySelector(".toast.shown")?.textContent || null, "the toast", 5)
      .catch(() => "");
    check(`No thanks: kept ("${await page.evaluate(() => localStorage.getItem("brickworks.install"))}"), told: "${String(toast).trim().slice(0, 90)}"`,
      (await page.evaluate(() => localStorage.getItem("brickworks.install"))) === '"no"' && /Settings/.test(String(toast)));
    await shot(page, `offer_no-${width}-${theme}.png`);
    await page.evaluate((v) => localStorage.setItem("brickworks.visits", JSON.stringify(v)), visits(5));
    await page.goto(`${site}/library`, { waitUntil: "load" });
    await offerNow(page);
    await page.waitForTimeout(3000);
    check(`${width} ${theme}: the visit after No thanks, no offer`, (await card(page)) === null);
  } catch (trouble) {
    check(`offer ${width}: ${trouble.message}`, false);
  } finally {
    await made.close();
  }
}

async function offerApple() {
  const webkit = await launch({ signedOut: true, engine: "webkit" }).catch((trouble) => {
    note(`no WebKit here: ${String(trouble).split("\n")[0]}`);
    return null;
  });
  if (!webkit) return;
  try {
    const made = await webkit.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
      extraHTTPHeaders: headers, colorScheme: "light",
      userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1" });
    const page = await made.newPage();
    listen(page, "offer iphone");
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await hideNotice(page);
    await page.evaluate((v) => localStorage.setItem("brickworks.visits", JSON.stringify(v)), visits(1));
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await until(page, () => {
      const one = document.querySelector(".install-offer");
      return Boolean(one?.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) && one.getBoundingClientRect().height > 0);
    }, "the iPhone's offer", 15);
    const drawn = await card(page);
    check(`iPhone (WebKit): how to add it: "${drawn.words.slice(0, 70)}…" [${drawn.buttons.join(", ")}]`,
      /Share/.test(drawn.words) && /Add to Home Screen/.test(drawn.words) && drawn.buttons.join(",") === "OK");
    await shot(page, "offer_iphone-390-light.png");
    await made.close();
  } catch (trouble) {
    check(`offer on an iPhone: ${trouble.message}`, false);
  } finally {
    await webkit.close();
  }
}

// ---------------------------------------------------------------------------
// time: a first visit waits on nothing of it.

async function time() {
  console.log("time: a first visit, with the worker and with workers blocked, at the same moment");
  const one = async (workers) => {
    const made = await context({ width: 1280, height: 900, workers });
    let swAsked = null;
    made.on("request", (request) => {
      if (new URL(request.url()).pathname === "/sw.js" && swAsked === null) swAsked = Date.now();
    });
    const page = await made.newPage();
    const started = Date.now();
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    const loadedAt = Date.now();
    await page.waitForTimeout(6000);
    const timing = await page.evaluate(() => {
      const nav = performance.getEntriesByType("navigation")[0];
      const paint = performance.getEntriesByName("first-contentful-paint")[0];
      const push = performance.getEntriesByType("resource").find((entry) => new URL(entry.name).pathname === "/push.js");
      return { load: Math.round(nav.loadEventEnd), fcp: Math.round(paint?.startTime || 0), loadStart: Math.round(nav.loadEventStart),
        push: push ? Math.round(push.startTime) : null, controlled: Boolean(navigator.serviceWorker?.controller) };
    });
    await made.close();
    return { ...timing, sw: swAsked === null ? null : swAsked - started, loadedWall: loadedAt - started };
  };
  const pairs = [];
  for (let n = 0; n < 3; n += 1) pairs.push(await Promise.all([one("allow"), one("block")]));
  for (const [withIt, without] of pairs) {
    note(`with: load ${withIt.load} ms, first paint ${withIt.fcp}, push.js at ${withIt.push}, sw.js at ${withIt.sw} (wall, load at ${withIt.loadedWall}) | `
      + `workers blocked: load ${without.load} ms, first paint ${without.fcp}`);
  }
  check("in each first visit push.js was asked for only after the load event, and the worker after the page loaded",
    pairs.every(([w]) => w.push !== null && w.push >= w.loadStart && w.sw !== null && w.sw >= w.loadedWall - 50));
  const median = (list) => list.sort((a, b) => a - b)[Math.floor(list.length / 2)];
  const withLoad = median(pairs.map(([w]) => w.load));
  const withoutLoad = median(pairs.map(([, b]) => b.load));
  const withPaint = median(pairs.map(([w]) => w.fcp));
  const withoutPaint = median(pairs.map(([, b]) => b.fcp));
  note(`medians of 3 pairs: load ${withLoad} vs ${withoutLoad} ms, first paint ${withPaint} vs ${withoutPaint} ms`);
  writeFileSync(path.join(out, "time.json"), `${JSON.stringify(pairs, null, 1)}\n`);
}

// ---------------------------------------------------------------------------
// push: a comment reaches her device within the minute.

let ada = null;
let bob = null;
const made = [];
const model = (name) => `0 ${name}\r\n0 Name: home.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // homescreen flow ${rand} ${name}\r\n`;

async function accounts() {
  if (ada) return;
  const minted = (email) => mintSession(email).catch((trouble) => {
    throw new Error(`signing ${email.split("@")[0]} in at Supabase: ${why(trouble)}`);
  });
  ada = await minted(adaEmail);
  bob = await minted(bobEmail);
  const a = await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: ADA, name: "Ada Home" } });
  const b = await api("/api/people?op=profile", { method: "POST", token: bob.access_token, body: { handle: BOB, name: "Bob Home" } });
  check(`throwaway profiles: ${a.status}, ${b.status}`, a.status === 200 && b.status === 200);
}

/// The notifications shown on [page]'s device: [{title, body, tag, url}].
const shownOn = (page) => page.evaluate(async () => {
  const registration = await navigator.serviceWorker.getRegistration("/");
  return registration ? (await registration.getNotifications()).map((one) => ({ title: one.title, body: one.body, tag: one.tag,
    url: one.data?.url || "" })) : [];
});
const clearShown = (page) => page.evaluate(async () => {
  const registration = await navigator.serviceWorker.getRegistration("/");
  for (const one of registration ? await registration.getNotifications() : []) one.close();
});
const pushPart = (page) => page.evaluate(() => ({ checked: document.getElementById("push-on")?.checked,
  disabled: document.getElementById("push-on")?.disabled, said: document.getElementById("push-said")?.textContent || "" }));

async function push() {
  console.log("push: a comment on Ada's model, on her device within the minute");
  await accounts();
  const state = await api("/api/people?op=push");
  if (!check(`push open on ${site}: ready ${state.body.ready}, key ${state.body.key ? "given" : "none"}`, state.status === 200 && state.body.ready === true)) {
    note("needs VAPID_PRIVATE_KEY in the deployment's env and supabase/push.sql applied");
    return;
  }
  const tower = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: "Home Flow Tower", author: "Ada Home", model: model("Home Flow Tower"), image: readFileSync(path.join(root, "web/share.png")).toString("base64"), listed: true } });
  made.push([tower.body.id, ada]);
  check(`her model: ${tower.status} /m/${tower.body.id}`, tower.status === 201 && Boolean(tower.body.id));

  // The browser's prompt only once it is turned on: a page of Settings,
  // nothing granted, asks nothing by itself. Counted where it would ask (the
  // browser's prompt, its push service): headless Chromium says "denied"
  // before anything is asked, so the permission alone could not tell
  // (hsfix's local run).
  const plain = await context({ as: ada, width: 1280, height: 900 });
  await plain.addInitScript(() => {
    const said = (what) => {
      try {
        sessionStorage.setItem("flow.asked", `${sessionStorage.getItem("flow.asked") || ""} ${what}`.trim());
      } catch {}
    };
    if (typeof Notification === "function") {
      const ask = Notification.requestPermission.bind(Notification);
      Notification.requestPermission = (...how) => { said("prompt"); return ask(...how); };
    }
    if (typeof PushManager === "function") {
      const subscribe = PushManager.prototype.subscribe;
      PushManager.prototype.subscribe = function (...how) { said("subscribe"); return subscribe.apply(this, how); };
    }
  });
  const look = await plain.newPage();
  listen(look, "settings, nothing granted");
  await look.goto(`${site}/settings#email-part`, { waitUntil: "load" });
  await until(look, () => document.getElementById("push-said") && (document.getElementById("push-on")?.disabled === false
    || document.getElementById("push-said").textContent), "the device's part drawn", 30);
  await look.waitForTimeout(2000);
  const { permission, asked } = await look.evaluate(() => ({ permission: Notification.permission,
    asked: sessionStorage.getItem("flow.asked") || "" }));
  const drawn = await pushPart(look);
  check(`Settings › Notifications, before anything: the browser not asked (${asked || "nothing"}; its permission ${permission}), `
    + `the box ${drawn.checked ? "on" : "off"}, ${drawn.disabled ? "disabled" : "enabled"} "${drawn.said}"`,
  !asked && permission !== "granted" && drawn.checked === false);
  await plain.close();

  // Each of DEVICES in turn until one is turned on, and said which, with
  // what each before it said.
  let opened = null;
  for (const kind of args.device ? [String(args.device)] : Object.keys(DEVICES)) {
    opened = await openDevice(kind).catch((trouble) => ({ on: String(trouble.message || trouble), close: async () => {} }));
    if (/On for this device/.test(opened.on)) {
      note(`her device: ${DEVICES[kind]}, its push service reached`);
      break;
    }
    note(`${DEVICES[kind]} could not be turned on: "${opened.on}"`);
    await opened.close();
    opened = null;
  }
  if (!check("a device of hers turned on in Settings", Boolean(opened))) return;
  const { page } = opened;
  try {
    const on = opened.on;
    const endpoint = await page.evaluate(async () => (await (await navigator.serviceWorker.ready).pushManager.getSubscription())?.endpoint || "");
    const told = await api(`/api/people?op=push&endpoint=${encodeURIComponent(endpoint)}`, { token: ada.access_token });
    if (!check(`turned on: "${on}", the account knows this device (${told.body.on}, ${told.body.devices} device), at ${endpoint ? new URL(endpoint).host : "no push service"}`,
      /On for this device/.test(on) && told.body.on === true && told.body.devices === 1)) return;
    await shot(page, "settings_push_on-1280-dark.png", { clip: await page.evaluate(() => {
      const box = document.getElementById("email-part").getBoundingClientRect();
      return { x: 0, y: Math.max(0, box.top + scrollY - 20), width: innerWidth, height: Math.min(900, box.height + 40) };
    }) });
    await clearShown(page);

    // Each comment is followed by a knock signed in as Ada, as the
    // database's knock would reach brickworks.diy: anywhere else only a
    // check's own account is taken (api/_push.js live), and brickworks.diy's
    // take leaves a check's account alone, so this deploy's code sends.
    const knock = () => api("/api/people?op=push_send", { method: "POST", token: ada.access_token });
    // What is pushed is chosen a kind at a time, once the file is applied
    // (supabase/notification_prefs.sql; inbox, 2026-11-23): a device turned
    // on hears replies and mentions, and a comment on her model only once
    // she ticks it in Settings' grid, on this page.
    const chosen = (await api("/api/people?op=notification_prefs", { token: ada.access_token })).body || {};
    note(`supabase/notification_prefs.sql ${chosen.ready === true ? "applied: pushed as chosen" : "not applied: everything pushed"}`);
    if (chosen.ready === true) {
      await until(page, () => document.querySelector('#kinds input[data-channel="push"]')?.disabled === false, "the grid enabled", 30);
      const ticked = await page.evaluate(() => [...document.querySelectorAll('#kinds input[data-channel="push"]')]
        .filter((box) => box.checked).map((box) => box.closest("tr").dataset.notice).join(","));
      check(`pushed by default: ${ticked}`, ticked === "reply,mention");
      const tb = Date.now();
      const early = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
        body: { model: tower.body.id, version: 1, body: `Before comments are pushed ${rand}` } });
      await knock();
      await page.waitForTimeout(Math.max(0, 20000 - (Date.now() - tb)));
      const none = await shownOn(page).catch(() => []);
      check(`a comment (${early.status}) before comments are pushed: nothing shown in 20 s (${none.length})`,
        early.status === 201 && none.length === 0);
      await page.click('#kinds tr[data-notice="comment"] input[data-channel="push"]');
      const said = await until(page, () => /^On:/.test(document.getElementById("mail-said")?.textContent || "")
        && document.getElementById("mail-said").textContent, "comments pushed, said", 15).catch(() => "");
      const pushedNow = (await api("/api/people?op=notification_prefs", { token: ada.access_token })).body?.push || [];
      check(`ticked in the grid: "${said}", pushed now ${pushedNow.join(",")}`, Boolean(said) && pushedNow.includes("comment"));
      await clearShown(page);
    }
    const t0 = Date.now();
    const comment = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: tower.body.id, version: 1, body: `Lovely stairs ${rand}` } });
    check(`Bob's comment: ${comment.status}`, comment.status === 201);
    const knocked = await knock();
    check(`the knock, signed in as Ada: ${knocked.status}, saying nothing (${JSON.stringify(knocked.body)})`,
      knocked.status === 204 && Object.keys(knocked.body || {}).length === 0);
    let arrived = null;
    while (Date.now() - t0 < 60000 && !arrived) {
      arrived = (await shownOn(page).catch(() => [])).find((one) => one.tag === `model-${tower.body.id}`) || null;
      if (!arrived) await page.waitForTimeout(250);
    }
    const took = Date.now() - t0;
    check(`the push on her device in ${arrived ? `${(took / 1000).toFixed(1)} s` : "NOT within 60 s"}: `
      + `${arrived ? `"${arrived.title}" "${arrived.body.replace(/\n/g, " / ")}" → ${arrived.url.replace(site, "")}` : ""}`,
      Boolean(arrived) && took < 60000 && arrived.title === "Home Flow Tower" && arrived.body.includes(`Lovely stairs ${rand}`)
      && arrived.body.includes("Bob Home") && arrived.url.startsWith(`${site}/m/${tower.body.id}`));
    writeFileSync(path.join(out, "push_measure.json"), `${JSON.stringify({ seconds: took / 1000, arrived, endpointHost: new URL(endpoint).host }, null, 1)}\n`);

    // Off: nothing more.
    await clearShown(page);
    await page.click("#push-on");
    const off = await until(page, () => /Off for this device/.test(document.getElementById("push-said")?.textContent || "")
      && document.getElementById("push-said").textContent, "off for this device", 30);
    const gone = await api(`/api/people?op=push&endpoint=${encodeURIComponent(endpoint)}`, { token: ada.access_token });
    check(`turned off: "${off}", the account has ${gone.body.devices} devices`, gone.body.on === false && gone.body.devices === 0);
    const t1 = Date.now();
    const second = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: tower.body.id, version: 1, body: `Still lovely ${rand}` } });
    await knock();
    await page.waitForTimeout(Math.max(0, 60000 - (Date.now() - t1)));
    const after = await shownOn(page).catch(() => []);
    check(`his next comment (${second.status}) with push off: nothing shown in 60 s (${after.length})`, second.status === 201 && after.length === 0);

    // On again (Settings, this device), as many times as it is stopped below.
    const devicesOf = async (want, seconds = 15) => {
      const end = Date.now() + seconds * 1000;
      let said = null;
      do {
        said = await subscribed(ada.kept.user_id, "-");
        if (said?.devices === want) return said;
        await page.waitForTimeout(500);
      } while (Date.now() < end);
      return said;
    };
    // What the device asks of the API about itself, said when the account
    // does not have it: each op=push the page sends, and its answer.
    const asks = [];
    page.on("response", (response) => {
      const url = new URL(response.url());
      if (url.origin !== new URL(site).origin || url.searchParams.get("op") !== "push") return;
      const sent = response.request().postData() || "";
      asks.push(`${response.request().method()} ${/"on":(true|false)/.exec(sent)?.[0] || ""}${/"all":true/.test(sent) ? " all" : ""} `
        + `${response.status()}`);
    });
    // Settings opened afresh, by way of a blank page. A goto to the address
    // the tab is at (#email-part and all) only moves to the part, and a
    // reload in Firefox gives the box back as it was, checked and enabled,
    // before the page has asked the account: either way the box said "on"
    // with her sign-in ended and the account knowing no device, and was never
    // pressed (m319home's runs, 2026-11-23).
    const settingsAfresh = async () => {
      if (page.url().startsWith(`${site}/settings`)) await page.goto("about:blank");
      await page.goto(`${site}/settings#email-part`, { waitUntil: "load" });
    };
    const onAgain = async (what) => {
      asks.length = 0;
      await settingsAfresh();
      await until(page, () => document.getElementById("push-on")?.disabled === false, `the box enabled (${what})`, 30);
      const was = await page.evaluate(() => document.getElementById("push-on").checked);
      if (!was) await page.click("#push-on");
      await until(page, () => /On for this device/.test(document.getElementById("push-said")?.textContent || "")
        || (document.getElementById("push-on").checked && !document.getElementById("push-on").disabled), `on again (${what})`, 60);
      const said = await devicesOf(1);
      if (said?.devices !== 1) {
        const drawn = await pushPart(page);
        note(`on again (${what}): the box was ${was ? "on" : "off"} and is ${drawn.checked ? "on" : "off"}, "${drawn.said}"; `
          + `the page asked ${asks.join(", ") || "nothing"}; the account has ${JSON.stringify(said)}`);
      }
      return said;
    };
    const signedInAs = (kept) => page.evaluate(([name, value]) => {
      sessionStorage.clear();
      localStorage.setItem(name, value);
    }, [STORAGE_KEY, JSON.stringify(kept)]);

    // The header's Sign out (the menu's, any page's): the device forgotten
    // at once, and the browser's subscription ended (hsfix F2).
    let now = await onAgain("before the header's Sign out");
    const keptNow = await page.evaluate((name) => JSON.parse(localStorage.getItem(name) || "null"), STORAGE_KEY);
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    await page.click(".site-head .account-menu summary");
    await Promise.all([page.waitForEvent("load", { timeout: 30000 }), page.click(".site-head .account-menu .sign-out")]);
    const forgotten = await devicesOf(0);
    const ended = await until(page, async () => !(await (await navigator.serviceWorker.ready).pushManager.getSubscription()),
      "the browser's subscription ended", 20).catch(() => false);
    check(`the header's Sign out: her devices ${now?.devices} before, ${forgotten?.devices} after; this browser's subscription ended (${Boolean(ended)})`,
      now?.devices === 1 && forgotten?.devices === 0 && Boolean(ended));

    // Turn off on every device (S2), signed in again here.
    await signedInAs(keptNow);
    now = await onAgain("before Turn off on every device");
    await settingsAfresh();
    const every = await until(page, () => !document.getElementById("push-every-part")?.hidden
      && document.getElementById("push-every").textContent, "Turn off on every device shown", 30).catch(() => "");
    await page.click("#push-every");
    const everyOff = await until(page, () => /Off on every device/.test(document.getElementById("push-said")?.textContent || "")
      && document.getElementById("push-said").textContent, "off on every device", 30).catch(() => "");
    const noneLeft = await devicesOf(0);
    check(`"${every}" pressed: "${everyOff}", her devices ${now?.devices} before, ${noneLeft?.devices} after, the box `
      + `${(await page.evaluate(() => document.getElementById("push-on").checked)) ? "on" : "off"}`,
      every === "Turn off on every device (1)" && Boolean(everyOff) && now?.devices === 1 && noneLeft?.devices === 0);

    // Her sign-in ended at Supabase (as Sign out everywhere ends it): the
    // device it was turned on with goes with it (push_2.sql).
    now = await onAgain("before her sign-in ends");
    const logout = await fetch(`${process.env.SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST",
      headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY || "", authorization: `Bearer ${ada.access_token}` } }).catch(() => null);
    const withSession = await devicesOf(0);
    check(`her sign-in ended (logout ${logout?.status}): her devices ${now?.devices} before, ${withSession?.devices} after`,
      logout?.ok && now?.devices === 1 && withSession?.devices === 0);

    // Signed in afresh, on again, then the account deleted: its devices with it.
    ada = { ...(await mintSession(adaEmail)) };
    await signedInAs(ada.kept);
    const before = await onAgain("before her account is deleted");
    const deleted = await api("/api/account?op=delete", { method: "POST", token: ada.access_token, body: { confirm: adaEmail } });
    const left = await devicesOf(0, 5);
    check(`her account deleted (${deleted.status}): her devices ${JSON.stringify(before)} before, ${JSON.stringify(left)} after`,
      deleted.status === 200 && before?.devices === 1 && left?.on === false && left?.devices === 0);
    if (deleted.status === 200) made.length = 0;

    // The same browser, Bob signed in on it: her device stops there, so
    // nothing of hers shows to him.
    await page.evaluate(([name, value]) => {
      sessionStorage.clear();
      localStorage.setItem(name, value);
    }, [STORAGE_KEY, JSON.stringify(bob.kept)]);
    await page.goto(`${site}/gallery`, { waitUntil: "load" });
    const stopped = await until(page, async () => !(await (await navigator.serviceWorker.ready).pushManager.getSubscription())
      && !localStorage.getItem("brickworks.push"), "her device stopped", 20).catch(() => false);
    check(`the same browser with Bob signed in: her device's subscription ended (${Boolean(stopped)})`, Boolean(stopped));
  } catch (trouble) {
    check(`push: ${trouble.message}`, false);
  } finally {
    await opened.close();
  }
}

/// The browsers her device can be, tried in this order (--device=KIND for
/// one). Playwright's Chromium reaches no push service the site can send to:
/// headless, it refuses ("push service not available"); in a window it
/// subscribes, at jmt17.google.com, which is not the service any Chrome or
/// Edge a person runs subscribes at (fcm.googleapis.com: PUSH_HOSTS in
/// api/_push.js), so the API rightly refuses it. Firefox subscribes at
/// Mozilla's, as every Firefox does, once the two settings by which
/// Playwright turns push off are put back (m319home, 2026-11-23: on rel-m319's
/// preview no push had ever reached a device, nor any device been turned on).
const DEVICES = { headless: "headless Chromium", window: "Chromium in a window (Xvfb)", firefox: "Firefox (headless)" };
const FIREFOX_PUSH = { "dom.push.serverURL": "wss://push.services.mozilla.com/", "dom.push.connection.enabled": true };

/// Ada's device: a browser with a profile of its own (push is off in a
/// private context), Settings opened, Notify me on this device pressed.
/// {page, on: what Settings then said, close}.
async function openDevice(kind) {
  if (!DEVICES[kind]) throw new Error(`no device "${kind}": ${Object.keys(DEVICES).join(", ")}`);
  const headed = kind === "window";
  const dir = mkdtempSync(path.join(tmpdir(), "homescreen-device-"));
  const display = headed ? await screen() : null;
  const options = { viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers, colorScheme: "dark" };
  const device = kind === "firefox"
    ? await firefox.launchPersistentContext(dir, { ...options, headless: true, firefoxUserPrefs: FIREFOX_PUSH })
    : await chromium.launchPersistentContext(dir, { ...options, headless: !headed, args: SOFTWARE,
      ...(display ? { env: { ...process.env, DISPLAY: display } } : {}) });
  const close = async () => {
    await device.close().catch(() => null);
    rmSync(dir, { recursive: true, force: true });
    if (headed) xvfb?.kill();
  };
  try {
    // As launch() gives its contexts: the bypass cookie, scrolls that land
    // at once, and the visit counter answered here.
    await quietCounter(await instantScroll(bypassCookie(device, headers)));
    await device.grantPermissions(["notifications"], { origin: site });
    await seed(device, ada);
    const page = device.pages()[0] || await device.newPage();
    listen(page, `Ada's device (${DEVICES[kind]})`);
    await page.goto(`${site}/settings#email-part`, { waitUntil: "load" });
    await until(page, () => document.getElementById("push-on")?.disabled === false, "the box enabled", 30);
    await page.click("#push-on");
    const on = await until(page, () => /On for this device|push service|did not work/.test(document.getElementById("push-said")?.textContent || "")
      && document.getElementById("push-said").textContent, "on for this device", 60);
    return { page, on, close };
  } catch (trouble) {
    await close();
    throw trouble;
  }
}

// A screen of its own for a headed browser: Xvfb on the first free display
// from :140, its process ended with the part. Never the DISPLAY the run was
// started with, which in an agent's shell is the owner's own desktop.
let xvfb = null;
async function screen() {
  for (let n = 140; n < 180; n += 1) {
    if (existsSync(`/tmp/.X11-unix/X${n}`) || existsSync(`/tmp/.X${n}-lock`)) continue;
    xvfb = spawn("Xvfb", [`:${n}`, "-screen", "0", "1280x1024x24", "-nolisten", "tcp"], { stdio: "ignore" });
    for (let waited = 0; waited < 50 && !existsSync(`/tmp/.X11-unix/X${n}`); waited += 1) await new Promise((r) => setTimeout(r, 100));
    if (existsSync(`/tmp/.X11-unix/X${n}`)) return `:${n}`;
    xvfb.kill();
  }
  throw new Error("no screen for a headed browser (Xvfb)");
}

// ---------------------------------------------------------------------------
// look: the pages at three widths, in both themes.

async function lookAt() {
  console.log("look: Settings › Notifications, the offline page and the offer");
  await accounts();
  for (const [width, height] of [[390, 844], [768, 1024], [1280, 900]]) {
    for (const theme of ["light", "dark"]) {
      const made = await context({ as: bob, width, height, phone: width < 500, theme });
      const page = await made.newPage();
      listen(page, `look ${width} ${theme}`);
      try {
        await page.goto(`${site}/settings#email-part`, { waitUntil: "load" });
        // Drawn is "ready" alone: this device's notifications (drawPush) are
        // said before the rest is drawn and #signed-in shown, so a wait that
        // took push-said's words read every heading still [hidden] (nightly
        // 2026-11-24, 768 and 1280 dark: Notifications []).
        await until(page, () => document.documentElement.dataset.settings === "ready", "Settings drawn", 45);
        await page.evaluate(() => document.getElementById("email-part").scrollIntoView());
        const parts = await page.evaluate(() => ({ h2: document.querySelector("#email-part h2")?.textContent,
          h3: [...document.querySelectorAll("#email-part h3")].filter((one) => !one.closest("[hidden]")).map((one) => one.textContent),
          toc: [...document.querySelectorAll("a[href='#email-part']")].map((one) => one.textContent.trim()) }));
        check(`${width} ${theme}: Settings › ${parts.h2} [${parts.h3.join(", ")}], its contents entry "${parts.toc.join("/")}", nothing sideways`,
          parts.h2 === "Notifications" && /^On this device,What you hear of, and where,(Your feed by email,)?Muted models$/.test(parts.h3.join(","))
          && !(await sideways(page)));
        await shot(page, `settings-${width}-${theme}.png`);
        await page.goto(`${site}/offline`, { waitUntil: "load" });
        check(`${width} ${theme}: the offline page, nothing sideways`, !(await sideways(page)));
        await shot(page, `offline-${width}-${theme}.png`);
      } catch (trouble) {
        check(`look ${width} ${theme}: ${trouble.message}`, false);
      }
      await made.close();
    }
  }
}

try {
  if (parts.has("fresh")) await fresh();
  if (parts.has("install")) await install();
  if (parts.has("offline")) await offline();
  if (parts.has("requests")) await requests();
  if (parts.has("offer")) {
    console.log("offer: from a second visit, No thanks kept");
    await offer({ width: 1280, height: 900, theme: "dark" });
    await offer({ width: 390, height: 844, phone: true, theme: "light" });
    for (const [width, height, theme] of [[390, 844, "dark"], [768, 1024, "light"], [768, 1024, "dark"], [1280, 900, "light"]]) {
      await offer({ width, height, phone: width < 500, theme, pictures: false });
    }
    await offerApple();
  }
  if (parts.has("time")) await time();
  if (parts.has("push")) await push();
  if (parts.has("look")) await lookAt();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${why(trouble)}`);
  console.log(`        ${String(trouble?.stack || "").split("\n").slice(1, 4).map((line) => line.trim()).join(" | ")}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const one of errors.slice(0, 5)) console.log(`        ${one}`);
  for (const [id, who] of made) {
    if (id && who) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who.access_token }).catch(() => {});
  }
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
  await browser.close();
}
console.log(failed ? `homescreen: ${failed} FAILED` : "homescreen: installable, offline, fresh, push within the minute: ok");
process.exit(failed ? 1 : 0);
