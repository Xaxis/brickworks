// Which engine each browser starts, and every request its page makes until
// the studio's window is up (nothreads, 2026-11-19; docs/PHONE.md).
//
//   node tools/web/engine_choice.mjs --url=URL --expect=on|off [--base=URL] --out=DIR
//
// URL is a page tools/web/place_build.py pointed at its engines, as /app is
// on a deployment, or /b/<sha>/index.html under tools/web/serve.py
// --phone-nothreads on|off. The browsers, each signed out in a fresh profile:
//   iphone      WebKit as an iPhone 13
//   ipad        WebKit as an iPad, its own user agent
//   ipad_mac    WebKit as an iPad that says it is a Mac, as iPadOS's Safari
//               does by default: a Mac's user agent, with the five touch
//               points an iPad's navigator.maxTouchPoints says
//   mac         WebKit as a Mac's Safari: no touch points
//   android     Chromium as a Pixel 7
//   computer    Chromium at 1280 x 800
// For each: the engine its page asked for (/e/<hash>/index.wasm), what
// window.brickworksEngine says it chose, and every request until
// window.brickworksBoot.ui (the window built), or --seconds.
//
// --expect=on: iPhone and both iPads start the engine GODOT_CONFIG.nothreads
// names, and never ask for a byte of the threaded one; the Mac and Chromium
// start the threaded one. --expect=off: every browser the threaded one.
// --base=URL: the same browsers at base's page too, and each browser's
// requests there and here, the build's /b/<sha>/ put as /b/SHA/, must be the
// same list, each as often. Writes DIR/choice.json; exits 1 on any failure.
import { chromium, devices, webkit } from "playwright";
import { SOFTWARE, WEBKIT_SOFTWARE } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...v] = a.replace(/^--/, "").split("=");
  return [k, v.length ? v.join("=") : true];
}));
if (!args.url || !["on", "off"].includes(args.expect)) {
  console.error("usage: engine_choice.mjs --url=URL --expect=on|off [--base=URL] [--only=iphone,ipad] [--seconds=300] --out=DIR");
  process.exit(2);
}
const out = resolve(String(args.out || "shots/engine_choice"));
mkdirSync(out, { recursive: true });
const seconds = Number(args.seconds || 300);
function without({ defaultBrowserType, ...rest }) { return rest; }
// An iPad's Safari asks for the desktop site by default: it says it is a
// Mac, and only its touch points tell it from one (navigator.maxTouchPoints
// is 5 on an iPad, 0 on a Mac).
const touchPoints = (n) => `Object.defineProperty(Navigator.prototype, "maxTouchPoints", { get: () => ${n}, configurable: true });`;
const BROWSERS = {
  iphone: { engine: "webkit", context: without(devices["iPhone 13"]), apple: true },
  ipad: { engine: "webkit", context: without(devices["iPad (gen 7)"]), apple: true },
  ipad_mac: { engine: "webkit", context: { ...without(devices["Desktop Safari"]), hasTouch: true }, init: touchPoints(5), apple: true },
  mac: { engine: "webkit", context: without(devices["Desktop Safari"]), init: touchPoints(0), apple: false },
  android: { engine: "chromium", context: without(devices["Pixel 7"]), apple: false },
  computer: { engine: "chromium", context: { viewport: { width: 1280, height: 800 } }, apple: false },
};
const only = args.only ? String(args.only).split(",") : Object.keys(BROWSERS);

let failed = 0;
function check(what, ok, said = "") {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${said ? `  (${said})` : ""}`);
  if (!ok) failed += 1;
}

// One browser at one page: its requests, the engine it asked for, its choice.
async function visit(name, url) {
  const how = BROWSERS[name];
  const browser = how.engine === "webkit"
    ? await webkit.launch({ env: { ...process.env, ...WEBKIT_SOFTWARE } })
    : await chromium.launch({ args: SOFTWARE });
  try {
    const context = await browser.newContext(how.context);
    if (how.init) await context.addInitScript(how.init);
    const page = await context.newPage();
    const asked = [];
    const origin = new URL(url).origin;
    page.on("request", (request) => {
      // A blob: the engine's own, a new address each visit.
      if (request.url().startsWith("blob:")) return void asked.push("blob:");
      const at = new URL(request.url());
      asked.push(at.origin === origin ? at.pathname + at.search : at.origin + at.pathname);
    });
    const errors = [];
    page.on("pageerror", (error) => errors.push(String(error).slice(0, 200)));
    const started = Date.now();
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
    let up = false;
    while (!up && Date.now() - started < seconds * 1000) {
      up = await page.evaluate(() => Boolean((window.brickworksBoot || {}).ui)).catch(() => false);
      if (!up) await page.waitForTimeout(500);
    }
    const seen = await page.evaluate(() => {
      const chosen = window.brickworksEngine || null;
      return {
        chosen: chosen && { at: chosen.at, threads: chosen.threads, apple: chosen.apple, asked: chosen.asked, on: chosen.on },
        isolated: window.crossOriginIsolated, touch: navigator.maxTouchPoints, agent: navigator.userAgent,
        // What GODOT_CONFIG named, read back from the page's own source.
        engines: (() => {
          const text = [...document.scripts].map((s) => s.textContent).join("\n");
          const at = (pattern) => (text.match(pattern) || [])[1] || "";
          return { threads: at(/"engine":"(\/e\/[0-9a-f]{16}\/index)"/), nothreads: at(/"nothreads":\{"engine":"(\/e\/[0-9a-f]{16}\/index)"/) };
        })(),
      };
    }).catch((error) => ({ error: String(error).slice(0, 200) }));
    return { name, url, up, seconds: Math.round((Date.now() - started) / 100) / 10, asked, errors, ...seen };
  } finally {
    await browser.close();
  }
}

// The requests, the build's own address put as /b/SHA/, counted.
function counted(asked) {
  const n = new Map();
  for (const one of asked) {
    const key = one.replace(/^\/b\/[0-9a-f]{7,40}(-dirty)?\//, "/b/SHA/");
    n.set(key, (n.get(key) || 0) + 1);
  }
  return n;
}

const rows = [];
for (const name of only) {
  console.log(`${name}:`);
  const here = await visit(name, String(args.url));
  const apple = BROWSERS[name].apple;
  const wantNoThreads = args.expect === "on" && apple;
  const engines = here.engines || {};
  const want = wantNoThreads ? engines.nothreads : engines.threads;
  const other = wantNoThreads ? engines.threads : engines.nothreads;
  const wasm = here.asked.filter((a) => /\/e\/[0-9a-f]{16}\/index\.wasm$/.test(a));
  const scripts = here.asked.filter((a) => /\/e\/[0-9a-f]{16}\/index\.js$/.test(a));
  check(`the page names both engines`, Boolean(engines.threads && engines.nothreads), `${engines.threads} and ${engines.nothreads}`);
  check(`it starts the ${wantNoThreads ? "engine without threads" : "threaded engine"}`,
    // Its preload and the engine's own fetch are both told as requests in
    // WebKit; how often each is asked is held to base's below.
    Boolean(want) && wasm.length >= 1 && wasm.every((a) => a === `${want}.wasm`)
      // ...and its script once a thread: the threaded engine's workers each
      // load it again.
      && scripts.length >= 1 && scripts.every((a) => a === `${want}.js`)
      && here.chosen && here.chosen.at === want && here.chosen.threads === !wantNoThreads,
    `asked ${[...new Set([...wasm, ...scripts])].join(", ") || "no engine"} (${wasm.length} + ${scripts.length}); chose ${JSON.stringify(here.chosen)}`);
  check(`...and nothing of the other`, Boolean(other) && !here.asked.some((a) => a.startsWith(other)));
  check(`its window comes up (${here.seconds} s)`, here.up);
  check(`no script errors (${here.errors.length})`, here.errors.length === 0, here.errors[0] || "");
  const row = { ...here, expect: args.expect, wanted: want };
  if (args.base) {
    const base = await visit(name, String(args.base));
    const a = counted(base.asked);
    const b = counted(here.asked);
    const differ = [...new Set([...a.keys(), ...b.keys()])].filter((k) => (a.get(k) || 0) !== (b.get(k) || 0))
      .map((k) => `${k}: base ${a.get(k) || 0}, here ${b.get(k) || 0}`);
    check(`the same requests as base's page (${here.asked.length} here, ${base.asked.length} there)`,
      base.up && differ.length === 0, differ.slice(0, 8).join("; "));
    row.base = { url: base.url, up: base.up, seconds: base.seconds, asked: base.asked, differ };
  }
  rows.push(row);
}
writeFileSync(join(out, "choice.json"), JSON.stringify(rows, null, 1));
console.log(failed ? `engine_choice: ${failed} FAILED` : `engine_choice: all ok (${rows.length} browsers, switch ${args.expect})`);
process.exit(failed ? 1 : 0);
