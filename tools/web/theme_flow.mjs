// Does the site keep the theme a person chose? (web/theme.js, web/site.css,
// docs/SOCIAL.md U1)
//
//   node tools/web/theme_flow.mjs [--out=DIR]               this checkout's web/ and api/, served here
//   node tools/web/theme_flow.mjs --url=<deployment>        a deployment's pages, as they are
//   ... --account   signed in on the deployment: needs supabase/theme.sql applied there and .env
//   [--only=home,model] [--widths=390,1280]
//
// The owner asked for a light theme people can choose. Every page of the
// site, the 16 static ones and a model's, a person's and a collection's,
// at 390 and 1280 px, in a browser whose computer is set to light:
//
//   chosen at once: Dark, System and Light pressed in the footer (Menu on
//     a phone; another tab of the site for /admin and the Claude sign-in,
//     which have neither) each change the page with no reload: its
//     background, <html data-theme>, the pressed button and the browser
//     bar's colour (theme-color); System follows the computer when it
//     changes, and a chosen theme does not;
//   kept: a reload and a new tab open in the chosen theme;
//   no flash: every frame drawn while the page loads, read from the first
//     (requestAnimationFrame runs before each paint), has the chosen
//     theme's background, never the other's. A control page whose theme
//     comes late must be caught, or the probe proves nothing.
//
// Signed in, Settings has the choice too, and the account keeps it: a new
// browser profile that signs in follows it on its first page, and an
// account with none takes the browser's. Locally the account is the
// stand-in's, kept in this process; with --account it is a throwaway
// account on the deployment (theme.sql applied there), deleted after, and
// its row with it.
//
// With no --url nothing leaves this machine: the pages are served by
// design_stand_in.mjs as design_flow.mjs serves them, and the API's own
// answers (api/account.js ?op=theme, before and after theme.sql) are
// checked in this process against a stand-in database.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { webcrypto } from "node:crypto";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const widths = String(args.widths || "390,1280").split(",").map(Number);
const only = args.only ? String(args.only).split(",") : null;
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

// The two backgrounds and bars (web/site.css --bg, web/theme.js).
const BG = { dark: "rgb(11, 12, 14)", light: "rgb(251, 251, 250)" };
const BAR = { dark: "#0b0c0e", light: "#fbfbfa" };

let passed = 0;
let failed = 0;
const check = (ok, what) => {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  return ok;
};

const AUTHORIZE = "/oauth/authorize?response_type=code&client_id=theme-flow&redirect_uri="
  + encodeURIComponent("https://claude.ai/api/mcp/auth_callback")
  + "&state=s1&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256";

// Every kind of page; bare: no header or footer, so chosen from another tab.
const PAGES = [
  { name: "home", path: "/" }, { name: "gallery", path: "/gallery" }, { name: "download", path: "/download" },
  { name: "account", path: "/profile" }, { name: "settings", path: "/settings" }, { name: "feed", path: "/feed" },
  { name: "challenge", path: "/challenge" },
  { name: "compare", path: "/compare" }, { name: "faq", path: "/faq" }, { name: "changelog", path: "/changelog" },
  { name: "privacy", path: "/privacy" }, { name: "terms", path: "/terms" }, { name: "guidelines", path: "/guidelines" },
  { name: "takedown", path: "/takedown" }, { name: "404", path: "/no-such-page-here" },
  { name: "admin", path: "/admin", bare: true }, { name: "authorize", path: AUTHORIZE, bare: true },
  { name: "model", path: `/m/${stand.MODEL_ID}` }, { name: "person", path: `/u/${stand.HANDLE}` },
  { name: "collection", path: `/c/${stand.LIST_ID}` },
];

// --- in the page ------------------------------------------------------------

/// Installed before any of the page's own scripts: the background of
/// <body> in every frame until the page has loaded and settled, read in
/// requestAnimationFrame, which runs before each paint.
function watchFrames() {
  const frames = [];
  window.__themeFrames = frames;
  let after = 0;
  const look = () => {
    if (document.body) frames.push(getComputedStyle(document.body).backgroundColor);
    if (document.readyState === "complete") after += 1;
    if (after < 5 && frames.length < 600) requestAnimationFrame(look);
  };
  requestAnimationFrame(look);
}

/// What the page shows now: its background, its theme, the pressed
/// buttons and the bar's colour the browser uses.
function shown() {
  const bar = [...document.querySelectorAll('meta[name="theme-color"]')]
    .find((meta) => !meta.media || matchMedia(meta.media).matches);
  const pressed = [...document.querySelectorAll('[data-theme-choice][aria-pressed="true"]')]
    .map((button) => button.dataset.themeChoice);
  return {
    bg: getComputedStyle(document.body).backgroundColor,
    theme: document.documentElement.getAttribute("data-theme"),
    bar: bar ? bar.content.toLowerCase() : null,
    pressed: [...new Set(pressed)],
    buttons: document.querySelectorAll("[data-theme-choice]").length,
    stayed: window.__stayed === true,
  };
}

// --- one page ---------------------------------------------------------------

async function newContext(browser, width, signedIn = null) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: "light",
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), state: {} });
  if (signedIn) {
    await context.addInitScript(([name, session, access]) => {
      try {
        if (!localStorage.getItem(name)) localStorage.setItem(name, session);
        if (access && !sessionStorage.getItem("brickworks.access")) sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, [STORAGE_KEY, JSON.stringify(signedIn.session), signedIn.access ? JSON.stringify(signedIn.access) : ""]);
  }
  await context.addInitScript(watchFrames);
  return context;
}

const settle = (page) => page.waitForTimeout(150);

/// Press [theme] on [page] as a person would there: the footer's at a
/// laptop's width, Menu's on a phone, Settings' when [where] says.
async function press(page, theme, where) {
  if (where === "settings") return page.click(`#theme-part [data-theme-choice="${theme}"]`);
  if (where === "menu") {
    if (!(await page.locator(".site-head details.menu").evaluate((menu) => menu.open))) await page.click(".site-head .menu summary");
    return page.click(`.menu-list [data-theme-choice="${theme}"]`);
  }
  return page.click(`.site-foot [data-theme-choice="${theme}"]`);
}

/// [page] shows [theme] (the page's look: dark or light) chosen as [chosen].
function looksRight(said, look, chosen, label) {
  const want = { bg: BG[look], theme: chosen === "system" ? null : chosen, bar: BAR[look] };
  const wrong = [];
  if (said.bg !== want.bg) wrong.push(`background ${said.bg}, not ${want.bg}`);
  if (said.theme !== want.theme) wrong.push(`data-theme ${said.theme}, not ${want.theme}`);
  if (said.bar !== want.bar) wrong.push(`bar ${said.bar}, not ${want.bar}`);
  if (said.buttons && (said.pressed.length !== 1 || said.pressed[0] !== chosen)) wrong.push(`pressed ${said.pressed.join(",") || "none"}, not ${chosen}`);
  return check(!wrong.length, `${label}: ${look}${wrong.length ? ` (${wrong.join("; ")})` : ""}`);
}

/// Every frame of a load in [look]'s background: none in the other's.
async function noFlash(page, look, label) {
  const frames = await page.evaluate(() => window.__themeFrames || []);
  const other = BG[look === "dark" ? "light" : "dark"];
  const wrong = frames.filter((bg) => bg === other).length;
  const right = frames.filter((bg) => bg === BG[look]).length;
  return check(frames.length > 0 && wrong === 0 && right > 0,
    `${label}: ${frames.length} frames, ${right} ${look}, ${wrong} the other${frames[0] ? `, first ${frames[0]}` : ""}`);
}

async function visit(page, address) {
  await page.goto(base + address, { waitUntil: "load", timeout: 60000 });
  await page.waitForFunction(() => (window.__themeFrames || []).length > 0 && document.readyState === "complete", null, { timeout: 15000 })
    .catch(() => null);
  await page.waitForTimeout(250);
}

async function onePage(browser, one, width) {
  const label = `${one.name} ${width}`;
  const where = width < 600 ? "menu" : "footer";
  const context = await newContext(browser, width);
  const errors = [];
  try {
    const page = await context.newPage();
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 160)));
    await visit(page, one.path);
    looksRight(await page.evaluate(shown), "light", "system", `${label} opens in the computer's theme`);
    // Bare pages are chosen for from another tab of the site.
    const other = one.bare ? await context.newPage() : null;
    if (other) await visit(other, "/privacy");
    const choose = async (theme) => {
      await page.evaluate(() => { window.__stayed = true; });
      if (other) await press(other, theme, where);
      else await press(page, theme, where);
      await settle(page);
      const said = await page.evaluate(shown);
      if (!said.stayed) check(false, `${label}: choosing ${theme} reloaded the page`);
      return said;
    };
    looksRight(await choose("dark"), "dark", "dark", `${label} Dark chosen${other ? " in another tab" : ""}, at once`);
    await page.reload({ waitUntil: "load" });
    await page.waitForTimeout(250);
    await noFlash(page, "dark", `${label} reloaded, every frame`);
    looksRight(await page.evaluate(shown), "dark", "dark", `${label} reloaded`);
    const tab = await context.newPage();
    await visit(tab, one.path);
    await noFlash(tab, "dark", `${label} a new tab, every frame`);
    looksRight(await tab.evaluate(shown), "dark", "dark", `${label} a new tab`);
    if (out) await tab.screenshot({ path: path.join(out, `${one.name}_${width}_dark_chosen.png`), timeout: 60000 }).catch(() => null);
    await tab.close();
    looksRight(await choose("system"), "light", "system", `${label} System chosen, at once`);
    await page.emulateMedia({ colorScheme: "dark" });
    await settle(page);
    looksRight(await page.evaluate(shown), "dark", "system", `${label} System follows the computer to dark`);
    looksRight(await choose("light"), "light", "light", `${label} Light chosen under a dark computer, at once`);
    await page.reload({ waitUntil: "load" });
    await page.waitForTimeout(250);
    await noFlash(page, "light", `${label} reloaded under a dark computer, every frame`);
    looksRight(await page.evaluate(shown), "light", "light", `${label} reloaded under a dark computer`);
    if (out) await page.screenshot({ path: path.join(out, `${one.name}_${width}_light_chosen.png`), timeout: 60000 }).catch(() => null);
  } catch (trouble) {
    check(false, `${label}: ${String(trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
  for (const error of errors) check(false, `${label}: the page threw: ${error}`);
}

/// The probe must see a flash where there is one: the privacy page with
/// its theme set late, after the page has loaded.
async function flashControl(browser) {
  const context = await newContext(browser, 1280);
  try {
    const page0 = remote ? await (await fetch(`${remote}/privacy`, { headers })).text()
      : readFileSync(path.join(root, "web/privacy.html"), "utf8");
    const late = page0.replace('<script src="/theme.js"></script>', "")
      .replace("</body>", '<script src="/theme-late.js"></script></body>');
    await context.route("**/privacy", (route) => route.fulfill({ contentType: "text/html; charset=utf-8", body: late }));
    await context.route("**/theme-late.js", (route) => route.fulfill({ contentType: "text/javascript",
      body: 'addEventListener("load", () => setTimeout(() => { const s = document.createElement("script"); s.src = "/theme.js"; document.head.append(s); }, 300));' }));
    await context.addInitScript(() => {
      try { localStorage.setItem("brickworks.theme", "dark"); } catch { /* none */ }
    });
    const page = await context.newPage();
    await visit(page, "/privacy");
    await page.waitForTimeout(500);
    const frames = await page.evaluate(() => window.__themeFrames || []);
    const light = frames.filter((bg) => bg === BG.light).length;
    check(light > 0 && (await page.evaluate(shown)).bg === BG.dark,
      `control: a theme set after load is caught as a flash (${light} light frames of ${frames.length}, then dark)`);
  } finally {
    await context.close();
  }
}

// --- signed in: Settings, and the account ------------------------------------

/// Locally: the account's theme kept in this process, as theme.sql's
/// column would keep it, answered for every context.
function accountMemory() {
  const memory = { theme: null, posts: [] };
  memory.route = (context) => context.route(/\/api\/account\?op=theme/, async (route) => {
    const request = route.request();
    if (!request.headers().authorization) return route.fulfill({ status: 401, contentType: "application/json", body: "{}" });
    if (request.method() === "POST") {
      const theme = JSON.parse(request.postData() || "{}").theme;
      memory.theme = theme;
      memory.posts.push(theme);
      return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ theme, kept: true }) });
    }
    return route.fulfill({ status: 200, contentType: "application/json",
      body: JSON.stringify({ theme: memory.theme || "system", chosen: Boolean(memory.theme), ready: true }) });
  });
  return memory;
}

async function signedIn(browser) {
  const width = 1280;
  let email = "";
  let session;
  let memory = null;
  if (remote) {
    email = `delivered+bwtheme${Date.now()}@resend.dev`;
    const made = await mintSession(email);
    session = { session: made.kept };
  } else {
    const kept = stand.signedInStorage();
    session = { session: kept.session, access: kept.access };
    memory = accountMemory();
  }
  const readAccount = async (page) => page.evaluate(async () => {
    const { call } = await import("/account.js");
    return (await call("/api/account?op=theme")).body;
  });
  try {
    // A first browser: Dark chosen in Settings goes to the account.
    const first = await newContext(browser, width, session);
    if (memory) await memory.route(first);
    const page = await first.newPage();
    await visit(page, "/settings");
    await page.waitForSelector("#theme-part [data-theme-choice]", { state: "visible", timeout: 20000 });
    const sent = page.waitForResponse((r) => r.url().includes("op=theme") && r.request().method() === "POST", { timeout: 15000 });
    await press(page, "dark", "settings");
    const reply = await sent.then((r) => r.json()).catch(() => ({}));
    await settle(page);
    looksRight(await page.evaluate(shown), "dark", "dark", "Settings: Dark chosen, at once");
    check(reply.kept === true, `the account keeps it (${JSON.stringify(reply)})`);
    const said = await readAccount(page);
    check(said.theme === "dark" && said.chosen === true, `the account says dark, chosen (${JSON.stringify(said)})`);
    await first.close();

    // A new browser profile, its computer light, signs in: its first page
    // follows the account.
    const second = await newContext(browser, width, remote ? { session: (await mintSession(email)).kept } : session);
    if (memory) await memory.route(second);
    const fresh = await second.newPage();
    await visit(fresh, "/gallery");
    const followed = await fresh.waitForFunction(() => document.documentElement.getAttribute("data-theme") === "dark", null, { timeout: 15000 })
      .then(() => true, () => false);
    check(followed, "a new browser profile, signed in: its first page follows the account to dark");
    looksRight(await fresh.evaluate(shown), "dark", "dark", "a new browser profile, signed in");
    await fresh.reload({ waitUntil: "load" });
    await fresh.waitForTimeout(250);
    await noFlash(fresh, "dark", "its next page, every frame");
    await second.close();

    // An account with no theme takes the one this browser chose.
    if (memory) {
      memory.theme = null;
      memory.posts.length = 0;
      const third = await newContext(browser, width, session);
      await memory.route(third);
      await third.addInitScript(() => {
        try { if (!localStorage.getItem("brickworks.theme")) localStorage.setItem("brickworks.theme", "light"); } catch { /* none */ }
      });
      const page3 = await third.newPage();
      await visit(page3, "/gallery");
      await page3.waitForTimeout(1500);
      check(memory.posts.includes("light") && memory.theme === "light",
        `an account with none takes this browser's Light (sent ${JSON.stringify(memory.posts)})`);
      await third.close();
    }
  } finally {
    if (remote && email) {
      const userId = session.session.user_id;
      const gone = await deleteAccount(email).catch(() => false);
      check(gone, `the throwaway account is deleted (${email})`);
      const url = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
      const secret = process.env.SUPABASE_SECRET_KEY || "";
      const rows = await (await fetch(`${url}/rest/v1/profiles?id=eq.${userId}&select=id,theme`, {
        headers: { apikey: secret, authorization: `Bearer ${secret}` } })).json().catch(() => null);
      check(Array.isArray(rows) && rows.length === 0, `its theme went with it (profiles rows left: ${JSON.stringify(rows)})`);
    }
  }
}

// --- the API's own answers, in this process -----------------------------------

/// api/account.js ?op=theme against a stand-in database: before theme.sql
/// (PostgREST does not know the column: 400) and after it.
async function apiAnswers() {
  const keys = await webcrypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const jwk = { ...(await webcrypto.subtle.exportKey("jwk", keys.publicKey)), kid: "theme-flow", alg: "ES256" };
  const DB = "https://theme-flow.supabase.test";
  const ME = "00000000-0000-4000-8000-00000000beef";
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const head = b64({ alg: "ES256", typ: "JWT", kid: "theme-flow" });
  const claims = b64({ sub: ME, email: "theme@example.com", aud: "authenticated", role: "authenticated",
    iss: `${DB}/auth/v1`, exp: Math.floor(Date.now() / 1000) + 3600 });
  const signature = Buffer.from(await webcrypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, keys.privateKey,
    Buffer.from(`${head}.${claims}`))).toString("base64url");
  const token = `${head}.${claims}.${signature}`;
  Object.assign(process.env, { SUPABASE_URL: DB, SUPABASE_SECRET_KEY: "secret", SUPABASE_PUBLISHABLE_KEY: "publishable" });
  const table = { applied: false, theme: undefined };
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (address, init = {}) => {
    const url = new URL(String(address));
    if (url.origin !== DB) return realFetch(address, init);
    if (url.pathname === "/auth/v1/.well-known/jwks.json") return Response.json({ keys: [jwk] });
    if (url.pathname === "/rest/v1/profiles") {
      const body = init.body ? JSON.parse(init.body) : {};
      const asksTheme = (url.searchParams.get("select") || "").includes("theme") || "theme" in body;
      if (asksTheme && !table.applied) return new Response('{"code":"42703"}', { status: 400 });
      if ((init.method || "GET") === "GET") return Response.json([{ theme: table.theme ?? null }]);
      table.theme = body.theme;
      return Response.json([{ id: ME, theme: body.theme }]);
    }
    return new Response("{}", { status: 404 });
  };
  const { default: handler } = await import(pathToFileURL(path.join(root, "api/account.js")).href);
  const ask = async (method, body, auth = true) => {
    const response = { statusCode: 0, body: null, setHeader() { return this; },
      status(code) { this.statusCode = code; return this; }, json(value) { this.body = value; return this; },
      end() { return this; } };
    await handler({ method, query: { op: "theme" }, body, headers: auth ? { authorization: `Bearer ${token}` } : {} }, response);
    return { status: response.statusCode, body: response.body };
  };
  const quiet = console.error;
  console.error = () => {};
  try {
    let said = await ask("GET");
    check(said.status === 200 && said.body.theme === "system" && said.body.ready === false,
      `api: before theme.sql, GET answers system, not ready (${said.status} ${JSON.stringify(said.body)})`);
    said = await ask("POST", { theme: "dark" });
    check(said.status === 200 && said.body.kept === false, `api: before theme.sql, POST keeps nothing, no error (${said.status} ${JSON.stringify(said.body)})`);
    table.applied = true;
    said = await ask("GET");
    check(said.status === 200 && said.body.theme === "system" && said.body.chosen === false && said.body.ready === true,
      `api: after, never chosen reads as System (${JSON.stringify(said.body)})`);
    said = await ask("POST", { theme: "dark" });
    check(said.status === 200 && said.body.kept === true && table.theme === "dark", `api: after, POST dark is kept (${JSON.stringify(said.body)})`);
    said = await ask("GET");
    check(said.body.theme === "dark" && said.body.chosen === true, `api: after, GET says dark, chosen (${JSON.stringify(said.body)})`);
    said = await ask("POST", { theme: "purple" });
    check(said.status === 422, `api: a theme that is not one is refused (${said.status})`);
    said = await ask("GET", undefined, false);
    check(said.status === 401, `api: nobody signed in is refused (${said.status})`);
  } finally {
    console.error = quiet;
    globalThis.fetch = realFetch;
  }
}

// --- run --------------------------------------------------------------------

console.log(`theme flow: ${remote || `${root} (its web/ and api/, served here)`}`);
if (remote) {
  // A deployment's own model, person and collection, found as a visitor
  // finds them: the gallery's newest, who shared it, a collection of theirs.
  const text = async (address) => {
    try {
      const reply = await fetch(remote + address, { headers });
      return reply.ok ? await reply.text() : "";
    } catch {
      return "";
    }
  };
  let listed = {};
  try {
    listed = JSON.parse(await text("/api/share?op=list&page=1")) || {};
  } catch { /* none */ }
  const id = (listed.models || [])[0]?.id || "";
  const handle = (/\/u\/([a-z0-9-]{3,24})"/.exec(id ? await text(`/m/${id}`) : "") || [])[1] || "";
  const list = (/\/c\/([A-Za-z0-9]{10})"/.exec(handle ? await text(`/u/${handle}`) : "") || [])[1] || "";
  const found = { model: id && `/m/${id}`, person: handle && `/u/${handle}`, collection: list && `/c/${list}` };
  for (const one of PAGES) {
    if (!(one.name in found)) continue;
    if (found[one.name]) one.path = found[one.name];
    else {
      one.skip = true;
      console.log(`  skip  ${one.name}: none on this deployment to visit`);
    }
  }
}

const browser = await launch({ signedOut: true });
try {
  if (!remote) await apiAnswers();
  await flashControl(browser);
  for (const one of PAGES) {
    if ((only && !only.includes(one.name)) || one.skip) continue;
    for (const width of widths) await onePage(browser, one, width);
  }
  if (!remote || args.account) await signedIn(browser);
  else console.log("  --    signed in: --account (needs supabase/theme.sql on the deployment, and .env)");
} finally {
  await browser.close();
}
console.log(`\ntheme flow: ${passed} checks passed, ${failed} failed`);
process.exit(failed || !passed ? 1 : 0);
