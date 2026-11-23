// The live site looked at in a browser that only looks: the browser half of
// tools/release/live_smoke.sh check, run under heavy right after a release
// goes live (fastship, 2026-11-23). Its GETs ran first and chose the model.
//
//   node tools/web/live_smoke.mjs --origin=URL --model=ID --name=NAME [--talk] [--out=DIR]
//
// Each part, in this order, a person's way through the site:
//   home    the home page at 1280 and at 390 wide: a header, a main with a
//           heading shown, a footer, a stylesheet of the site's own applied,
//           nothing wider than the window
//   model   /m/ID: its title is NAME and its picture is drawn
//   talk    (--talk) /talk, the forum: its list and its heading
//   app     /app: the engine draws and the app puts its first screen up (a
//           browser signed out meets the sign-in screen, which the app draws
//           itself, so the app has started), with no fault of the engine's
// and on every page: no error the page did not catch, and nothing of this
// site's answering 404 or 5xx (a signed-out visitor is refused some things,
// so 401 and 403 are not faults here).
//
// Read only. Signed out (launch({ signedOut: true })): no session is minted
// or used. Every request but GET, HEAD and OPTIONS, a beacon's too, is
// answered here with a 204 and never sent: the model page's count of a view
// (api/share.js seen), a counter's beacon. Each is said at the end as held
// back. A driven browser is never counted by the site anyway (web/counting.js).
//
// BW_BYPASS: the deployment's protection bypass, for a *.vercel.app origin
// (live_smoke.sh sets it only there). Exit 0 when every part holds, 1 when one
// does not (each said, with what was seen), 4 when no browser could start.
import { mkdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { launch } from "./browser.mjs";
import { pageRoute } from "./page_routes.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const origin = String(args.origin || "").replace(/\/+$/, "");
if (!/^https?:\/\/[^/]+$/.test(origin) || !/^[A-Za-z0-9]{10}$/.test(String(args.model || ""))) {
  console.error("live_smoke.mjs: --origin=https://HOST and --model=ID (ten characters) are required");
  process.exit(2);
}
const out = args.out ? resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const nonce = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
const busted = (path) => `${origin}${path}${path.includes("?") ? "&" : "?"}_smoke=${nonce}`;
const APP_MS = Number(process.env.LIVE_SMOKE_APP_MS || 180000);
const PAGE_MS = Number(process.env.LIVE_SMOKE_PAGE_MS || 45000);
// The engine naming its own C++ file and line: the app asked it for what this build cannot do (tools/web/check.mjs).
const ENGINE_FAULT = /\bat: .+\.(cpp|h):\d+|^ERROR:/;

let browser;
try {
  browser = await launch({ signedOut: true });
} catch (trouble) {
  console.log(`live_smoke.mjs: no browser: ${String(trouble?.message || trouble).split("\n")[0].slice(0, 200)}`);
  process.exit(4);
}
const bypass = process.env.BW_BYPASS || "";
const context = await browser.newContext({ viewport: { width: 1280, height: 800 },
  extraHTTPHeaders: bypass ? { "x-vercel-protection-bypass": bypass } : {} });
const held = new Map();
await pageRoute(context, ["*"], ({ url, method }) => {
  if (["GET", "HEAD", "OPTIONS"].includes(method)) return null;
  let where = url;
  try {
    const parsed = new URL(url);
    where = `${parsed.host === new URL(origin).host ? "" : parsed.host}${parsed.pathname}${parsed.search.replace(/_smoke=[^&]*&?/, "")}`;
  } catch {}
  const key = `${method} ${where.slice(0, 120)}`;
  held.set(key, (held.get(key) || 0) + 1);
  return { status: 204, headers: { "x-live-smoke": "held back: read only" }, body: "" };
});

const host = new URL(origin).host;
const results = [];
let page = null;
// What went wrong on the page the current part looks at.
let seen = { errors: [], broken: [], engine: [] };
function watch(one) {
  one.on("pageerror", (error) => seen.errors.push(String(error?.message || error).split("\n")[0].slice(0, 160)));
  one.on("console", (message) => {
    if (message.type() === "error" && ENGINE_FAULT.test(message.text())) seen.engine.push(message.text().slice(0, 160));
  });
  one.on("response", (response) => {
    const status = response.status();
    let mine = false;
    try {
      mine = new URL(response.url()).host === host;
    } catch {}
    if (mine && (status === 404 || status >= 500) && response.headers()["x-live-smoke"] === undefined) {
      seen.broken.push(`${status} ${new URL(response.url()).pathname}`);
    }
  });
}

/// One part looked at: [look] throws what is wrong, or returns what was seen.
async function part(name, look) {
  const at = Date.now();
  seen = { errors: [], broken: [], engine: [] };
  try {
    if (!page || page.isClosed()) {
      page = await context.newPage();
      watch(page);
    }
    const said = await look(page);
    const faults = [
      ...seen.errors.map((one) => `an error the page did not catch: ${one}`),
      ...[...new Set(seen.broken)].map((one) => `this site answered ${one}`),
      ...seen.engine.map((one) => `the engine: ${one}`),
    ];
    if (faults.length) throw new Error(faults.slice(0, 3).join("; ") + (faults.length > 3 ? ` (and ${faults.length - 3} more)` : ""));
    results.push({ name, ok: true });
    console.log(`  ok    ${name}: ${said}  [${((Date.now() - at) / 1000).toFixed(1)}s]`);
  } catch (trouble) {
    results.push({ name, ok: false });
    console.log(`  FAIL  ${name}: ${String(trouble?.message || trouble).split("\n")[0].slice(0, 400)}  [${((Date.now() - at) / 1000).toFixed(1)}s]`);
    if (out && page && !page.isClosed()) await page.screenshot({ path: join(out, `${name.split(" ")[0]}.png`), timeout: 15000 }).catch(() => {});
  }
}

/// [path] opened, answering 200, or why not.
async function open(one, path) {
  const response = await one.goto(busted(path), { waitUntil: "domcontentloaded", timeout: PAGE_MS });
  if (!response) throw new Error(`${path} gave no answer`);
  if (response.status() !== 200) throw new Error(`${path} answers ${response.status()}`);
  return response;
}

/// The page laid out as it should be at its width: what is missing, or "".
const layout = (one) => one.evaluate(() => {
  const shown = (el) => !!el && el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden";
  const wrong = [];
  if (!document.querySelector("header")) wrong.push("no header");
  if (!document.querySelector("main")) wrong.push("no main");
  if (!document.querySelector("footer")) wrong.push("no footer");
  if (![...document.querySelectorAll("h1")].some(shown)) wrong.push("no heading shown");
  // A stylesheet of this site's own, read with its rules (site.css today, whatever it is called later).
  const rules = [...document.styleSheets].filter((one) => (one.href || "").startsWith(location.origin)).reduce((n, one) => {
    try {
      return n + one.cssRules.length;
    } catch {
      return n;
    }
  }, 0);
  if (rules < 20) wrong.push(`the site's stylesheet not applied (${rules} rules)`);
  const wide = document.documentElement.scrollWidth;
  if (wide > window.innerWidth + 2) wrong.push(`${wide} px wide in a ${window.innerWidth} px window`);
  return wrong.join(", ");
});

await part("home", async (one) => {
  const widths = [];
  for (const [width, height] of [[1280, 800], [390, 844]]) {
    await one.setViewportSize({ width, height });
    await open(one, "/");
    await one.waitForLoadState("load", { timeout: 20000 }).catch(() => {});
    await one.waitForTimeout(1500);
    const wrong = await layout(one);
    if (wrong) throw new Error(`at ${width} wide: ${wrong}`);
    widths.push(width);
    if (out) await one.screenshot({ path: join(out, `home_${width}.png`), timeout: 15000 }).catch(() => {});
  }
  await one.setViewportSize({ width: 1280, height: 800 });
  return `holds together at ${widths.join(" and ")} wide ("${(await one.title()).slice(0, 60)}")`;
});

await part("model page", async (one) => {
  await open(one, `/m/${args.model}`);
  const want = String(args.name || "").replace(/\s+/g, " ").trim();
  const title = await one.locator("main h1").first().textContent({ timeout: 15000 }).catch(() => null);
  const got = String(title || "").replace(/\s+/g, " ").trim();
  if (!got) throw new Error(`/m/${args.model} shows no title`);
  if (want && got !== want) throw new Error(`/m/${args.model} is titled "${got.slice(0, 80)}", where the gallery calls it "${want.slice(0, 80)}"`);
  const picture = await one.evaluate(async (ms) => {
    const img = document.querySelector(".model-page .picture img") || document.querySelector("main .media img");
    if (!img) return { none: true };
    img.loading = "eager";
    await Promise.race([img.decode().catch(() => {}), new Promise((done) => setTimeout(done, ms))]);
    return { src: img.getAttribute("src"), width: img.naturalWidth, height: img.naturalHeight };
  }, 30000);
  if (picture.none) throw new Error(`/m/${args.model} has no picture on its page`);
  if (!picture.width) throw new Error(`/m/${args.model}'s picture (${picture.src}) is not drawn`);
  if (out) await one.screenshot({ path: join(out, "model.png"), timeout: 15000 }).catch(() => {});
  return `"${got.slice(0, 60)}", its picture drawn (${picture.width}x${picture.height})`;
});

if (args.talk) {
  await part("talk", async (one) => {
    await open(one, "/talk");
    const page = await one.evaluate(() => ({
      list: !!document.querySelector("[data-talk]"),
      heading: (document.querySelector("main h1")?.textContent || "").trim(),
      threads: document.querySelectorAll(".talk-row").length,
    }));
    if (!page.list) throw new Error("/talk is not Talk's page (no [data-talk])");
    if (!page.heading) throw new Error("/talk shows no heading");
    if (out) await one.screenshot({ path: join(out, "talk.png"), timeout: 15000 }).catch(() => {});
    return `"${page.heading.slice(0, 40)}", ${page.threads} thread(s) listed`;
  });
}

await part("app", async (one) => {
  await open(one, "/app");
  await one.waitForSelector("canvas", { timeout: APP_MS });
  // The engine drawing (more than its loading colour) and the app's first
  // screen up: the controls it tells the page of (window.brickworksControls).
  const up = await one.waitForFunction(() => {
    const canvas = document.querySelector("canvas");
    const controls = Object.keys(window.brickworksControls || {});
    if (!canvas || !canvas.width || !controls.length) return false;
    const probe = document.createElement("canvas");
    probe.width = 64;
    probe.height = 36;
    const ctx = probe.getContext("2d");
    try {
      ctx.drawImage(canvas, 0, 0, 64, 36);
      const { data } = ctx.getImageData(0, 0, 64, 36);
      let min = 255;
      let max = 0;
      for (let i = 0; i < data.length; i += 4) {
        const v = (data[i] + data[i + 1] + data[i + 2]) / 3;
        min = Math.min(min, v);
        max = Math.max(max, v);
      }
      return max - min > 18 ? { controls: controls.length, account: window.brickworksAccount?.state || "" } : false;
    } catch {
      return false;
    }
  }, undefined, { timeout: APP_MS, polling: 1000 }).then((handle) => handle.jsonValue()).catch(() => null);
  if (!up) {
    const state = await one.evaluate(() => ({ canvas: !!document.querySelector("canvas"),
      controls: Object.keys(window.brickworksControls || {}).length })).catch(() => ({}));
    throw new Error(`the app did not come up within ${Math.round(APP_MS / 1000)} s (canvas ${state.canvas ? "there" : "missing"}, `
      + `${state.controls || 0} controls told)`);
  }
  await one.waitForTimeout(2000);
  if (out) await one.screenshot({ path: join(out, "app.png"), timeout: 15000 }).catch(() => {});
  return `the engine draws and the app's first screen is up (${up.controls} controls${up.account ? `, ${up.account}` : ""})`;
});

await browser.close().catch(() => {});
const failed = results.filter((one) => !one.ok).length;
if (held.size) console.log(`  (held back, never sent: ${[...held].map(([what, n]) => `${what}${n > 1 ? ` x${n}` : ""}`).join(", ")})`);
console.log(failed ? `browser: ${failed} of ${results.length} parts FAILED` : `browser: all ${results.length} parts hold`);
process.exit(failed ? 1 : 0);
