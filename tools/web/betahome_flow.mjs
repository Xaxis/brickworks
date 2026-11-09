// The beta's bar, the homepage's Open beta and the beta's hub (betahome,
// 2026-11-09; web/betabar.js, web/landing.js, web/beta.js), as a person
// meets them, in a real browser:
//
//   node tools/web/betahome_flow.mjs [--root=DIR] [--before=DIR] [--out=DIR] [--only=bar,hide,press,home,hub,off,same,weight]
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/betahome_flow.mjs --url=<deployment> --out=DIR
//
// By default the design stand-in (tools/web/design_stand_in.mjs) serves
// DIR's web/ (this checkout's), and this flow answers the beta itself
// (GET /api/plans?op=beta, ?op=beta_spots, POST ?op=beta_join), open or
// off, for three visitors: signed out, signed in, a tester. Open:
//
//   bar    every page of site_check's list (and /beta, /terms, /feed, the
//          server's /m/, /u/, /c/, the page not found), at 390x844 and
//          1280x800, light and dark: the bar there, in the window, its
//          four parts, in the page's language, nothing sideways, and at the
//          page's end not over the footer's links;
//   hide   its x hides it, the focus kept on the page, for a day: not on
//          the next page or after a reload, back once the day is over;
//   press  Open beta opens /beta; Report a bug opens a dialog over the page
//          (web/bugreport.js's, or Send feedback's as a bug), the page not
//          left; Join signed in makes a tester (POST ?op=beta_join with
//          {via: "bar"}) and says so, signed out opens the sign-in;
//   home   the homepage's #beta right under the first screen for each
//          visitor: Sign up and join, Join the beta, or Report a bug and
//          What's new; the months left while any are; nothing moved as it
//          loaded (a first visit, and one that kept the answer);
//   hub    /beta for each visitor: the way in, the line under the title,
//          how to report and this week's releases (changelog.json); a
//          tester's what to try, known issues and early features.
//
// Off: no bar and no #beta on any page, /beta says Coming soon with no way
// in, and after the first page the bar's script is not asked for again
// (off). With --before=DIR (pre261's tree), each page, the beta off, shows
// what DIR's shows: the same words, the same height, the same first
// screen to the pixel (same). weight: the homepage's bytes as sent
// (gzip, as Vercel sends them) and its first paint, against --before's,
// ABAB, the median of six each.
//
// With --url, a deployment's pages and API, signed out: off (every
// release's preview) checks nothing is drawn; open (tools/deploy.sh --unit
// --beta-open) the bar, hide, Join's and Report a bug's dialogs, the
// homepage's Sign up and join and /beta's hub. Pictures in --out. It
// passes when it ends "betahome: all ok".
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { gzipSync } from "node:zlib";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const root = path.resolve(String(args.root || here));
const before = args.before ? path.resolve(String(args.before)) : "";
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = String(args.out || "shots/betahome");
mkdirSync(out, { recursive: true });
const only = args.only ? String(args.only).split(",") : null;
const asked = (part) => !only || only.includes(part);
const bypass = process.env.BW_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const until = (page, test, arg = null, timeout = 15000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

// The pages: site_check's list (tools/web/site_check.mjs PAGES), and the
// rest a person reaches from the header and footer.
const LANG_PAGES = ["", "/download", "/plans", "/faq", "/compare", "/gallery", "/library"];
const PAGES = [
  "/", "/download", "/gallery", "/changelog", "/compare", "/plans", "/library", "/faq", "/privacy", "/takedown",
  ...["de", "fr", "es"].flatMap((code) => LANG_PAGES.map((where) => `/${code}${where}`)),
  "/admin", "/profile", "/settings",
  ...(remote ? [] : [`/m/${stand.MODEL_ID}`, `/u/${stand.HANDLE}`, `/c/${stand.LIST_ID}`]),
  "/beta", "/terms", "/feed", "/no-such-brick",
];
// What the bar's badge says in each language (web/_lang/<code>.json).
const OPEN_BETA = { en: "Open beta", ...Object.fromEntries(["de", "fr", "es"].map((code) =>
  [code, JSON.parse(readFileSync(path.join(root, `web/_lang/${code}.json`), "utf8")).scripts?.["Open beta"] || "?"])) };
const SPOTS = { cap: 100, left: 63 };
const JOINED = "2026-11-02T10:00:00Z";

const browser = await launch({ signedOut: true });

/// A browser at [width] in [theme] as [who] ("out", "in", "tester"), the
/// beta [beta] ("open" or "off"), serving [tree]'s web/. Its told: what
/// the page asked of the beta, and the join's body.
async function visitor({ width, theme = "light", who = "out", beta = "open", tree = root, motion = "no-preference" }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 800 }, colorScheme: theme,
    reducedMotion: motion, extraHTTPHeaders: headers,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  const told = { asked: [], joins: [], scripts: [] };
  if (!remote) {
    await stand.serveSite(context, { web: path.join(tree, "web"), api: path.join(tree, "api"), state: {} });
    let tester = who === "tester";
    await context.route(/\/api\/plans\?op=beta(?:_spots|_join)?(?:&.*)?$/, async (route) => {
      const op = new URL(route.request().url()).searchParams.get("op");
      told.asked.push(op);
      let body;
      if (op === "beta_spots") body = beta === "open" ? { beta: "open", ...SPOTS } : { beta: "off" };
      else if (op === "beta_join") {
        told.joins.push(route.request().postDataJSON());
        tester = true;
        body = { beta: "open", signed_in: true, tester: true, state: "tester", joined_at: new Date().toISOString(), spots: SPOTS };
      } else if (beta !== "open") body = { beta: "off" };
      else if (who === "out") body = { beta: "open", signed_in: false, spots: SPOTS };
      else body = { beta: "open", signed_in: true, tester, state: tester ? "tester" : null, joined_at: tester ? JOINED : null, spots: SPOTS };
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(body) });
    });
    if (who !== "out") {
      const kept = stand.signedInStorage();
      await context.addInitScript(([session, access]) => {
        try {
          if (!localStorage.getItem("brickworks.session")) localStorage.setItem("brickworks.session", session);
          sessionStorage.setItem("brickworks.access", access);
        } catch { /* a browser that keeps nothing */ }
      }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
    }
  }
  context.on("request", (request) => {
    if (/\/betabar\.js$/.test(new URL(request.url()).pathname)) told.scripts.push(request.url());
  });
  const page = await context.newPage();
  const label = `${width} ${theme} ${who} ${beta}`;
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  return { context, page, told, label };
}

/// The page at [where], drawn as far as the beta goes: the bar there and
/// risen, or the beta heard and nothing to draw.
async function go(page, where) {
  await page.goto(base + where, { waitUntil: "load", timeout: 60000 });
  await until(page, () => document.querySelector("#beta-bar.shown")
    || (localStorage.getItem("brickworks.beta") || "").includes('"off"'), null, 10000);
  await page.waitForTimeout(400);
}

/// The bar as the page shows it.
const barOf = (page) => page.evaluate(() => {
  const bar = document.getElementById("beta-bar");
  const html = document.documentElement;
  const sideways = html.scrollWidth > html.clientWidth + 1;
  if (!bar) return { there: false, sideways, marked: html.hasAttribute("data-betabar"), lang: html.lang };
  const box = bar.getBoundingClientRect();
  const badge = bar.querySelector("a.badge");
  return {
    there: true, sideways, lang: html.lang, risen: bar.classList.contains("shown"),
    inside: box.left >= 0 && box.top >= 0 && box.right <= html.clientWidth + 0.5 && box.bottom <= innerHeight + 0.5,
    height: Math.round(box.height), width: Math.round(box.width),
    badge: badge?.textContent.trim() || "", badgeTo: badge ? new URL(badge.href).pathname : "",
    report: Boolean(bar.querySelector("button[data-beta-report]")),
    join: Boolean(bar.querySelector("button[data-beta-join]")), tester: Boolean(bar.querySelector("a.tester")),
    hide: Boolean(bar.querySelector("button[data-beta-hide][aria-label]")),
    // Every part on one line, none cut off.
    oneLine: [...bar.children].every((one) => {
      const at = one.getBoundingClientRect();
      return one.classList.contains("third") || (at.top >= box.top - 0.5 && at.bottom <= box.bottom + 0.5 && one.scrollWidth <= at.width + 1);
    }) && [...bar.querySelectorAll(".third > *")].every((one) => one.scrollWidth <= one.getBoundingClientRect().width + 1),
  };
});

/// At the page's end, a footer link or button under the bar.
const footCovered = (page) => page.evaluate(async () => {
  window.scrollTo(0, document.documentElement.scrollHeight);
  await new Promise((done) => setTimeout(done, 300));
  const bar = document.getElementById("beta-bar")?.getBoundingClientRect();
  if (!bar) return [];
  return [...document.querySelectorAll(".site-foot a, .site-foot button, .site-foot select")].filter((one) => {
    const at = one.getBoundingClientRect();
    return at.width && at.right > bar.left && at.left < bar.right && at.bottom > bar.top && at.top < bar.bottom;
  }).map((one) => one.textContent.trim() || one.getAttribute("aria-label") || one.tagName);
});

/// How far the page moved under the eyes as it loaded and drew the beta
/// (layout shifts with no input before them), before any scroll.
const shiftedSoFar = (page) => page.evaluate(async () => {
  let total = 0;
  new PerformanceObserver((list) => {
    for (const one of list.getEntries()) if (!one.hadRecentInput) total += one.value;
  }).observe({ type: "layout-shift", buffered: true });
  await new Promise((done) => setTimeout(done, 600));
  return Math.round(total * 10000) / 10000;
});

const fresh = (page) => page.evaluate(() => {
  try {
    localStorage.removeItem("brickworks.beta");
    localStorage.removeItem("brickworks.betabar.hidden");
  } catch { /* nothing kept */ }
});

try {
  const open = remote ? (await (await fetch(`${remote}/api/plans?op=beta_spots`, { headers })).json().catch(() => ({}))).beta === "open" : true;
  console.log(`betahome flow: ${base}${remote ? ` (the beta ${open ? "open" : "off"} there)` : ` (stand-in, ${root})`}`);

  // --- bar ----------------------------------------------------------------
  if (open && asked("bar")) {
    console.log("bar: on every page");
    const rounds = remote ? [[1280, "light", "out"], [390, "dark", "out"]]
      : [[1280, "light", "in"], [1280, "dark", "out"], [390, "light", "out"], [390, "dark", "in"]];
    for (const [width, theme, who] of rounds) {
      const { context, page, label } = await visitor({ width, theme, who });
      const missing = [];
      const wrong = [];
      for (const where of PAGES) {
        await go(page, where);
        const bar = await barOf(page);
        const lang = bar.lang || "en";
        if (!bar.there) {
          missing.push(where);
          continue;
        }
        const want = OPEN_BETA[lang] || OPEN_BETA.en;
        const to = lang === "en" ? "/beta" : `/${lang}/beta`;
        const bad = [!bar.risen && "not risen", !bar.inside && "outside the window", bar.sideways && "sideways",
          bar.badge !== want && `badge "${bar.badge}" not "${want}"`, bar.badgeTo !== to && `badge to ${bar.badgeTo}`,
          !bar.report && "no Report a bug", !(bar.join || bar.tester) && "no Join", !bar.hide && "no x",
          !bar.oneLine && "a part cut off or wrapped", bar.height > 52 && `${bar.height} px high`].filter(Boolean);
        const covered = await footCovered(page);
        if (covered.length) bad.push(`over the footer's ${covered.slice(0, 3).join(", ")}`);
        if (bad.length) wrong.push(`${where}: ${bad.join(", ")}`);
        if (["/", "/gallery", "/de", `/m/${stand.MODEL_ID}`].includes(where)) {
          await page.evaluate(() => window.scrollTo(0, 0));
          await page.waitForTimeout(200);
          await shot(page, `bar${where.replace(/\W+/g, "_")}-${width}-${theme}-${who}.png`);
        }
      }
      check(`${label}: the bar on all ${PAGES.length} pages${missing.length ? `, not on ${missing.join(" ")}` : ""}`, !missing.length);
      check(`${label}: in the window, its four parts in the page's language, nothing sideways or covered${wrong.length
        ? `: ${wrong.slice(0, 4).join("; ")}${wrong.length > 4 ? ` and ${wrong.length - 4} more` : ""}` : ""}`, !wrong.length);
      await context.close();
    }
  }

  // --- hide ---------------------------------------------------------------
  if (open && asked("hide")) {
    console.log("hide: for a day");
    const { context, page } = await visitor({ width: 1280, who: remote ? "out" : "in" });
    await go(page, "/gallery");
    await page.click("#beta-bar [data-beta-hide]");
    const gone = await until(page, () => !document.getElementById("beta-bar") && !document.documentElement.hasAttribute("data-betabar"));
    const focus = await page.evaluate(() => document.activeElement?.id || document.activeElement?.tagName);
    const until_ = await page.evaluate(() => Number(localStorage.getItem("brickworks.betabar.hidden")));
    const day = until_ - Date.now();
    check(`its x hides it, the focus on the page (${focus}), for ${Math.round(day / 60000)} minutes`, gone && focus === "main"
      && Math.abs(day - 86400000) < 120000);
    await go(page, "/");
    const next = await barOf(page);
    await page.reload({ waitUntil: "load" });
    await page.waitForTimeout(1500);
    const reloaded = await barOf(page);
    check("not on the next page, nor after a reload", !next.there && !reloaded.there);
    await page.evaluate(() => localStorage.setItem("brickworks.betabar.hidden", String(Date.now() - 1000)));
    await go(page, "/");
    check("back once the day is over", (await barOf(page)).there);
    await context.close();
  }

  // --- press --------------------------------------------------------------
  if (open && asked("press")) {
    console.log("press: Open beta, Report a bug, Join");
    for (const [width, theme, who] of remote ? [[1280, "light", "out"], [390, "dark", "out"]] : [[1280, "light", "in"], [390, "dark", "out"]]) {
      const { context, page, told, label } = await visitor({ width, theme, who });
      await go(page, "/gallery");
      await page.click("#beta-bar a.badge");
      check(`${label}: Open beta opens /beta`, await until(page, () => location.pathname === "/beta"));
      await go(page, "/gallery");
      const at = page.url();
      await page.click("#beta-bar [data-beta-report]");
      const opened = await until(page, () => document.querySelector("dialog[open]"), null, 20000);
      const which = await page.evaluate(() => ({ dialog: document.querySelector("dialog[open]")?.className || "",
        bugreport: typeof window.brickworksReportBug === "function",
        bug: document.querySelector('dialog[open] input[value="bug"]')?.checked ?? null }));
      check(`${label}: Report a bug opens ${which.bugreport ? "web/bugreport.js's" : "Send feedback's"} dialog (${which.dialog})`
        + ` over the page, which stays${which.bug === null ? "" : `, a bug chosen: ${which.bug}`}`, opened && page.url() === at
        && (which.bugreport || which.dialog.includes("sign-in") || which.bug === true));
      await shot(page, `report-${width}-${theme}-${who}.png`);
      await page.keyboard.press("Escape");
      await until(page, () => !document.querySelector("dialog[open]"), null, 5000);
      await page.keyboard.press("Escape");
      await go(page, "/gallery");
      await page.click("#beta-bar [data-beta-join]");
      if (who === "out") {
        check(`${label}: Join, signed out, opens the sign-in`, await until(page, () => document.querySelector("dialog.sign-in[open]")));
        await shot(page, `join-${width}-${theme}-${who}.png`);
      } else {
        const joined = await until(page, () => document.querySelector("#beta-bar a.tester")
          && /tester/i.test(document.querySelector(".toast")?.textContent || ""));
        check(`${label}: Join makes a tester (${JSON.stringify(told.joins)}) and says so`, joined
          && told.joins.length === 1 && told.joins[0]?.via === "bar");
        await shot(page, `joined-${width}-${theme}-${who}.png`);
        await go(page, "/");
        check(`${label}: the next page has it kept: You're a tester`, (await barOf(page)).tester);
      }
      await context.close();
    }
  }

  // --- home ---------------------------------------------------------------
  if (open && asked("home")) {
    console.log("home: the way in for each visitor");
    const WANT = {
      out: { row: "out", first: /^Sign up and join/, said: /^The first 100 testers we approve get a month of Pro, free: 63 spots left\.$/ },
      in: { row: "in", first: /^Join the beta/, said: /^The first 100 testers we approve get a month of Pro, free: 63 spots left\.$/ },
      tester: { row: "tester", first: /^Report a bug$/, said: /^You’re a tester\. Thank you/ },
    };
    const whos = remote ? ["out"] : ["out", "in", "tester"];
    for (const [width, theme] of [[1280, "light"], [390, "dark"]]) {
      for (const who of whos) {
        const { context, page, label } = await visitor({ width, theme, who });
        await page.goto(base + "/", { waitUntil: "load" });
        const firstMoved = await shiftedSoFar(page);
        const drawn = await until(page, () => getComputedStyle(document.getElementById("beta")).display !== "none"
          && document.documentElement.dataset.betaHome);
        const said = await page.evaluate(() => {
          const band = document.getElementById("beta");
          const row = [...band.querySelectorAll("#beta-acts > [data-visitor]")].find((one) => !one.hidden);
          const hero = document.querySelector("main > section");
          return { row: row?.dataset.visitor || "", first: row?.querySelector(".cta")?.textContent.trim() || "",
            second: row?.querySelectorAll(".cta")[1]?.textContent.trim() || "",
            said: document.getElementById("beta-said").textContent.trim(),
            afterHero: hero !== band && band.previousElementSibling === hero,
            heroBottom: Math.round(hero.getBoundingClientRect().bottom + scrollY), top: Math.round(band.getBoundingClientRect().top + scrollY),
            points: band.querySelectorAll(".beta-points li").length };
        });
        const want = WANT[who];
        check(`${label}: #beta under the first screen's hero, ${said.points} points, ${said.row}: "${said.first}" / "${said.second}"`,
          drawn && said.afterHero && said.top >= said.heroBottom && said.points === 3 && said.row === want.row && want.first.test(said.first));
        check(`${label}: its line: "${said.said}"`, want.said.test(said.said));
        // A second visit: the answer kept, the section there at the first frame.
        await page.goto(base + "/", { waitUntil: "load" });
        const keptMoved = await shiftedSoFar(page);
        check(`${label}: nothing moved as it loaded: ${firstMoved} first, ${keptMoved} with the answer kept`, firstMoved < 0.02 && keptMoved < 0.02);
        await page.evaluate(() => document.getElementById("beta").scrollIntoView({ block: "center" }));
        await page.waitForTimeout(300);
        await shot(page, `home-${width}-${theme}-${who}.png`);
        if (who === "out") {
          await page.click("#beta-acts [data-visitor=out] [data-beta-join]");
          check(`${label}: Sign up and join opens the sign-in`, await until(page, () => document.querySelector("dialog.sign-in[open]")));
        }
        await context.close();
      }
    }
  }

  // --- hub ----------------------------------------------------------------
  if (open && asked("hub")) {
    console.log("hub: /beta for each visitor");
    const LINE = { out: /^63 of 100 free months of Pro left$/, in: /^63 of 100 free months of Pro left$/,
      tester: /^You’ve been a tester since 2 November 2026\. Thank you!$/ };
    const whos = remote ? ["out"] : ["out", "in", "tester"];
    for (const [width, theme] of [[1280, "light"], [390, "dark"]]) {
      for (const who of whos) {
        const { context, page, label } = await visitor({ width, theme, who });
        await page.goto(base + "/beta", { waitUntil: "load" });
        const moved = await shiftedSoFar(page);
        await until(page, () => document.documentElement.dataset.betaPage && !document.querySelector("#news .skeleton")
          && (document.documentElement.dataset.betaPage !== "tester" || !document.getElementById("testers").hidden), null, 20000);
        const said = await page.evaluate(() => ({
          visitor: document.documentElement.dataset.betaPage,
          line: document.getElementById("spots").textContent.trim(),
          eyebrow: [...document.querySelectorAll(".beta-head .eyebrow span")].filter((s) => !s.hidden).map((s) => s.textContent).join(""),
          sections: ["get", "report", "new", "testers", "questions"].filter((id) => !document.getElementById(id).hidden),
          news: [...document.querySelectorAll("#news > li.card h3")].map((one) => one.textContent.trim()),
          heads: document.querySelectorAll("#news > li.card li").length,
          lists: ["try", "known", "early"].map((id) => document.querySelectorAll(`#${id} > li`).length),
          sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
        }));
        const testers = who === "tester";
        check(`${label}: ${said.eyebrow}, the way in for ${said.visitor}, "${said.line}"`, said.visitor === who && said.eyebrow === "Open beta"
          && LINE[who].test(said.line) && !said.sideways);
        check(`${label}: ${said.sections.join(", ")}; this week's releases ${said.news.join(", ")} (${said.heads} heads)`
          + `${testers ? `; to try, known, early: ${said.lists.join(", ")}` : ""}`,
          said.sections.join() === (testers ? "get,report,new,testers,questions" : "get,report,new,questions")
          && said.news.length >= 1 && said.heads >= 1 && (!testers || said.lists.every((n) => n > 0)));
        check(`${label}: nothing moved as it loaded: ${moved}`, moved < 0.02);
        await shot(page, `hub-${width}-${theme}-${who}.png`, true);
        await context.close();
      }
    }
  }

  // --- off ----------------------------------------------------------------
  if ((!open || !remote) && asked("off")) {
    console.log("off: nothing drawn");
    for (const [width, theme, who] of remote ? [[1280, "light", "out"], [390, "dark", "out"]] : [[1280, "light", "in"], [390, "dark", "out"]]) {
      const { context, page, told, label } = await visitor({ width, theme, who, beta: "off" });
      const drawn = [];
      let scriptsAfterFirst = -1;
      for (const where of PAGES) {
        await go(page, where);
        if (scriptsAfterFirst < 0) scriptsAfterFirst = told.scripts.length;
        const said = await page.evaluate(() => ({ bar: Boolean(document.getElementById("beta-bar")),
          marked: ["beta", "betabar"].filter((name) => document.documentElement.hasAttribute(`data-${name}`)),
          band: document.getElementById("beta") ? getComputedStyle(document.getElementById("beta")).display : "none" }));
        if (said.bar || said.marked.length || said.band !== "none") drawn.push(`${where}: ${JSON.stringify(said)}`);
      }
      check(`${label}: no bar, no Open beta, on all ${PAGES.length} pages${drawn.length ? `: ${drawn.slice(0, 3).join("; ")}` : ""}`, !drawn.length);
      check(`${label}: the bar's script asked for once (${scriptsAfterFirst}), then not again for ten minutes (${told.scripts.length - scriptsAfterFirst})`,
        scriptsAfterFirst <= 1 && told.scripts.length === scriptsAfterFirst);
      await page.goto(base + "/beta", { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.betaPage);
      const hub = await page.evaluate(() => ({
        eyebrow: [...document.querySelectorAll(".beta-head .eyebrow span")].filter((s) => !s.hidden).map((s) => s.textContent).join(""),
        line: document.getElementById("spots").textContent.trim(),
        ways: [...document.querySelectorAll("#beta-acts > [data-visitor]")].filter((one) => !one.hidden).length,
        sections: ["report", "new", "testers"].filter((id) => !document.getElementById(id).hidden) }));
      check(`${label}: /beta says "${hub.eyebrow}", "${hub.line}", no way in, none of the open beta's parts`,
        /Coming soon/.test(hub.eyebrow) && /^Coming soon/.test(hub.line) && hub.ways === 0 && !hub.sections.length);
      await shot(page, `hub-off-${width}-${theme}.png`, true);
      await context.close();
    }
  }

  // --- same ---------------------------------------------------------------
  if (!remote && before && asked("same")) {
    console.log(`same: the beta off, each page as ${before} shows it`);
    const compare = await browser.newPage();
    for (const [width, theme] of [[1280, "light"], [390, "dark"]]) {
      const sides = {};
      for (const [side, tree] of [["before", before], ["now", root]]) {
        const { context, page } = await visitor({ width, theme, who: "out", beta: "off", tree, motion: "reduce" });
        sides[side] = {};
        // /beta is the beta's hub now, and says Coming soon its own way (off).
        for (const where of PAGES.filter((one) => one !== "/beta")) {
          await go(page, where);
          await page.waitForTimeout(800);
          const words = await page.evaluate(() => ({ text: document.body.innerText, height: document.documentElement.scrollHeight }));
          const picture = await page.screenshot({ timeout: 60000 }).catch(() => null);
          sides[side][where] = { ...words, picture };
        }
        await context.close();
      }
      const differ = [];
      for (const where of PAGES.filter((one) => one !== "/beta")) {
        const [a, b] = [sides.before[where], sides.now[where]];
        const pixels = a.picture && b.picture ? await compare.evaluate(async ([one, two]) => {
          const load = (src) => new Promise((done) => { const img = new Image(); img.onload = () => done(img); img.src = src; });
          const [x, y] = await Promise.all([load(one), load(two)]);
          if (x.width !== y.width || x.height !== y.height) return -1;
          const canvas = new OffscreenCanvas(x.width, x.height);
          const draw = canvas.getContext("2d");
          draw.drawImage(x, 0, 0);
          const first = draw.getImageData(0, 0, x.width, x.height).data;
          draw.drawImage(y, 0, 0);
          const second = draw.getImageData(0, 0, x.width, x.height).data;
          let n = 0;
          for (let i = 0; i < first.length; i += 4) if (first[i] !== second[i] || first[i + 1] !== second[i + 1] || first[i + 2] !== second[i + 2]) n += 1;
          return n;
        }, [`data:image/png;base64,${a.picture.toString("base64")}`, `data:image/png;base64,${b.picture.toString("base64")}`]) : -2;
        const sameText = a.text === b.text;
        if (!sameText || a.height !== b.height || pixels !== 0) {
          differ.push(`${where}: ${sameText ? "same words" : "other words"}, ${a.height} -> ${b.height} px, ${pixels} pixels`);
        }
      }
      check(`${width} ${theme}: all ${PAGES.length - 1} pages but /beta show what before showed (words, height, first screen)${differ.length
        ? `, not: ${differ.slice(0, 5).join("; ")}` : ""}`, !differ.length);
    }
    await compare.close();
  }

  // --- weight -------------------------------------------------------------
  if (!remote && before && asked("weight")) {
    console.log("weight: the homepage, as sent, and its first paint");
    const loadOf = async (tree) => {
      const { context, page } = await visitor({ width: 1280, who: "out", beta: "open", tree });
      let bytes = 0;
      let zipped = 0;
      page.on("response", async (response) => {
        const at = new URL(response.url());
        if (at.origin !== stand.ORIGIN || /^\/(?:api|b)\//.test(at.pathname)) return;
        const body = await response.body().catch(() => null);
        if (!body) return;
        bytes += body.length;
        zipped += /\.(?:html|js|css|json|svg)$|\/$|^\/[a-z]{2}$/.test(at.pathname) || at.pathname === "/" ? gzipSync(body).length : body.length;
      });
      await page.goto(base + "/", { waitUntil: "load" });
      await page.waitForTimeout(1500);
      const paint = await page.evaluate(() => Math.round(performance.getEntriesByName("first-contentful-paint")[0]?.startTime || 0));
      await context.close();
      return { bytes, zipped, paint };
    };
    const runs = { before: [], now: [] };
    for (let round = 0; round < 6; round += 1) {
      for (const side of round % 2 ? ["now", "before"] : ["before", "now"]) runs[side].push(await loadOf(side === "now" ? root : before));
    }
    const median = (list) => [...list].sort((a, b) => a - b)[Math.floor(list.length / 2)];
    const of = (side, key) => median(runs[side].map((one) => one[key]));
    const more = of("now", "zipped") - of("before", "zipped");
    const later = of("now", "paint") - of("before", "paint");
    check(`the homepage's first load, gzip as sent: ${of("before", "zipped")} -> ${of("now", "zipped")} bytes (${more >= 0 ? "+" : ""}${more}`
      + `, raw ${of("before", "bytes")} -> ${of("now", "bytes")}), at most 10 KB more`, more <= 10240);
    check(`its first paint, median of 6 ABAB: ${of("before", "paint")} -> ${of("now", "paint")} ms (${later >= 0 ? "+" : ""}${later}), at most 50 ms more`,
      later <= 50);
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  await browser.close();
}
check(`no page errors: ${errors.slice(0, 4).join(" | ") || "none"}`, errors.length === 0);
console.log(`betahome: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "betahome: all ok" : "betahome: FAILED");
process.exit(failed === 0 ? 0 : 1);
