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
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
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
// A whole page's picture leaves the bar out: a fixed part is drawn once,
// where the first screen had it, over whatever is there in the long picture
// (the window's pictures show it where it is).
const shot = async (page, name, full = false) => {
  // Once what opens or fades in has (a dialog, the toast, the bar).
  await page.waitForFunction(() => document.getAnimations().every((one) => one.playState !== "running"), null, { timeout: 3000 }).catch(() => null);
  if (full) await page.evaluate(() => document.getElementById("beta-bar")?.style.setProperty("visibility", "hidden")).catch(() => null);
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
  if (full) await page.evaluate(() => document.getElementById("beta-bar")?.style.removeProperty("visibility")).catch(() => null);
};

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
// The bar's label in each language: "Open beta", and on a phone "Beta".
const wordsOf = (english) => ({ en: english, ...Object.fromEntries(["de", "fr", "es"].map((code) =>
  [code, JSON.parse(readFileSync(path.join(root, `web/_lang/${code}.json`), "utf8")).scripts?.[english] || "?"])) });
const OPEN_BETA = wordsOf("Open beta");
const BETA = wordsOf("Beta");
// The stand-in's months left; with --url, the deployment's, as its pages
// read them (GET ?op=beta_spots): the real pool, 100 left before anyone was
// approved, never the stand-in's 63 (betaopen, 2026-11-10).
let SPOTS = { cap: 100, left: 63 };
const JOINED = "2026-11-02T10:00:00Z";
// A line said exactly [text], as a pattern.
const exactly = (text) => new RegExp(`^${text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`);

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
// A page, loaded and quiet: the bar risen, or the beta kept as off, or
// (a site with no bar, such as pre261's) nothing more asked for a moment.
async function go(page, where) {
  await page.goto(base + where, { waitUntil: "load", timeout: 60000 });
  await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => null);
  await until(page, () => document.querySelector("#beta-bar.shown")
    || (localStorage.getItem("brickworks.beta") || "").includes('"off"'), null, 1500);
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
    badge: badge?.innerText.trim() || "", badgeTo: badge ? new URL(badge.href).pathname : "",
    report: Boolean(bar.querySelector("button[data-beta-report]")),
    join: Boolean(bar.querySelector("a[data-beta-join]")), tester: Boolean(bar.querySelector("a.tester")),
    hide: Boolean(bar.querySelector("button[data-beta-hide][aria-label]")),
    // Every part on one line, none cut off.
    oneLine: [...bar.children].every((one) => {
      const at = one.getBoundingClientRect();
      return one.classList.contains("third") || (at.top >= box.top - 0.5 && at.bottom <= box.bottom + 0.5
        && at.left >= box.left - 0.5 && at.right <= box.right + 0.5 && one.scrollWidth <= at.width + 1);
    }) && [...bar.querySelectorAll(".third > *")].every((one) => {
      const at = one.getBoundingClientRect();
      return at.left >= box.left - 0.5 && at.right <= box.right + 0.5 && one.scrollWidth <= at.width + 1;
    }),
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


// Each part runs on whatever the one before it did: a part that throws
// (pre261 has no bar to press) fails as itself, and the rest still run.
async function section(name, body) {
  try {
    await body();
  } catch (trouble) {
    check(`${name} ran: ${String(trouble?.message || trouble).split("\n")[0].slice(0, 300)}`, false);
  }
}

try {
  const spots = remote ? await (await fetch(`${remote}/api/plans?op=beta_spots`, { headers })).json().catch(() => ({})) : null;
  const open = remote ? spots.beta === "open" : true;
  if (open && remote) SPOTS = { cap: spots.cap, left: spots.left };
  console.log(`betahome flow: ${base}${remote ? ` (the beta ${open ? "open" : "off"} there)` : ` (stand-in, ${root})`}`);

  // --- bar ----------------------------------------------------------------
  if (open && asked("bar")) await section("bar", async () => {
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
        const want = (width < 600 ? BETA : OPEN_BETA)[lang] || "?";
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
        ? `: ${wrong.slice(0, 4).join("; ")}${wrong.length > 4 ? ` and ${wrong.length - 4} more` : ""}` : ""}`,
        !wrong.length && missing.length < PAGES.length);
      await context.close();
    }
  });

  // --- hide ---------------------------------------------------------------
  if (open && asked("hide")) await section("hide", async () => {
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
  });

  // --- press --------------------------------------------------------------
  if (open && asked("press")) await section("press", async () => {
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
        && (which.bugreport || (/\bfeedback\b/.test(which.dialog) && which.bug === true)));
      await shot(page, `report-${width}-${theme}-${who}.png`);
      await page.keyboard.press("Escape");
      await until(page, () => !document.querySelector("dialog[open]"), null, 5000);
      await page.keyboard.press("Escape");
      // Join: to the hub's way in, its button ready, what joining agrees
      // to said under it; one press there joins (signed out, signs in first).
      await go(page, "/gallery");
      await page.click("#beta-bar [data-beta-join]");
      // web/beta.js focuses the way in once the page has loaded and drawn,
      // in the frame after: read then, as a person meets it. Read as soon
      // as it was drawn, the focus was still on the page (betaopen,
      // 2026-11-10), and Enter pressed there opened nothing.
      await until(page, () => location.pathname === "/beta" && document.documentElement.dataset.betaPage
        && document.readyState === "complete");
      await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
      const landed = await page.evaluate(() => {
        const focus = document.activeElement;
        const terms = document.querySelector(".beta-head .terms");
        const box = terms?.getBoundingClientRect();
        return { path: location.pathname + location.hash, row: document.documentElement.dataset.betaPage,
          focused: focus?.matches("#beta-acts [data-beta-join]") ? focus.textContent.trim() : focus?.tagName || "",
          terms: terms?.textContent.trim() || "", termsTo: terms?.querySelector("a")?.getAttribute("href") || "",
          termsSeen: Boolean(box) && box.bottom <= innerHeight && getComputedStyle(terms).visibility === "visible" };
      });
      check(`${label}: Join opens ${landed.path}, the way in for ${landed.row}, "${landed.focused}" focused, and under it "${landed.terms}"`,
        landed.path === "/beta#beta-acts" && landed.row === who && /join/i.test(landed.focused)
        && /^Joining agrees to the beta’s terms and to emails about the beta\./.test(landed.terms) && landed.termsTo === "/terms#beta" && landed.termsSeen);
      await page.keyboard.press("Enter");
      if (who === "out") {
        check(`${label}: its Sign up and join opens the sign-in`, await until(page, () => document.querySelector("dialog.sign-in[open]")));
        await shot(page, `join-${width}-${theme}-${who}.png`);
      } else {
        const joined = await until(page, () => document.querySelector("#beta-bar a.tester")
          && /tester/i.test(document.querySelector(".toast")?.textContent || ""));
        check(`${label}: its Join the beta makes a tester at once (${JSON.stringify(told.joins)}) and says so`, joined
          && told.joins.length === 1 && told.joins[0]?.via === "hub");
        await shot(page, `joined-${width}-${theme}-${who}.png`);
        await go(page, "/");
        check(`${label}: the next page has it kept: You're a tester`, (await barOf(page)).tester);
      }
      await context.close();
    }
  });

  // --- home ---------------------------------------------------------------
  if (open && asked("home")) await section("home", async () => {
    console.log("home: the way in for each visitor");
    // web/landing.js drawBeta: no line once every month is given.
    const line = SPOTS.left > 0
      ? `The first ${SPOTS.cap} testers we approve get a month of Pro, free: ${SPOTS.left} spot${SPOTS.left === 1 ? "" : "s"} left.` : "";
    const WANT = {
      out: { row: "out", first: /^Sign up and join/, said: exactly(line) },
      in: { row: "in", first: /^Join the beta/, said: exactly(line) },
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
            terms: document.getElementById("beta-terms")?.checkVisibility() ? document.getElementById("beta-terms").textContent.trim() : "",
            termsTo: document.querySelector("#beta-terms a")?.getAttribute("href") || "",
            afterHero: hero !== band && band.previousElementSibling === hero,
            heroBottom: Math.round(hero.getBoundingClientRect().bottom + scrollY), top: Math.round(band.getBoundingClientRect().top + scrollY),
            points: band.querySelectorAll(".beta-points li").length };
        });
        const want = WANT[who];
        check(`${label}: #beta under the first screen's hero, ${said.points} points, ${said.row}: "${said.first}" / "${said.second}"`,
          drawn && said.afterHero && said.top >= said.heroBottom && said.points === 3 && said.row === want.row && want.first.test(said.first));
        check(`${label}: its line: "${said.said}"${said.terms ? `, and "${said.terms}"` : ", no terms line"}`, want.said.test(said.said)
          && (who === "tester" ? !said.terms : /^Joining agrees to the beta’s terms and to emails about the beta\./.test(said.terms) && said.termsTo === "/terms#beta"));
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
  });

  // --- hub ----------------------------------------------------------------
  if (open && asked("hub")) await section("hub", async () => {
    console.log("hub: /beta for each visitor");
    // web/beta.js lineOf.
    const left = SPOTS.left > 0 ? `${SPOTS.left} of ${SPOTS.cap} free months of Pro left`
      : `All ${SPOTS.cap} months of Pro are given. Joining stays open.`;
    const LINE = { out: exactly(left), in: exactly(left),
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
          // What joining agrees to, for whoever can join; a tester has joined.
          terms: [document.querySelector(".beta-head .terms")].filter((one) => one && getComputedStyle(one).visibility === "visible")
            .map((one) => one.textContent.trim()).join(""),
        }));
        const testers = who === "tester";
        check(`${label}: ${said.eyebrow}, the way in for ${said.visitor}, "${said.line}", ${said.terms ? `under it "${said.terms.slice(0, 40)}…"` : "no terms line"}`,
          said.visitor === who && said.eyebrow === "Open beta" && LINE[who].test(said.line) && !said.sideways
          && (testers ? !said.terms : /^Joining agrees to the beta’s terms/.test(said.terms)));
        check(`${label}: ${said.sections.join(", ")}; this week's releases ${said.news.join(", ")} (${said.heads} heads)`
          + `${testers ? `; to try, known, early: ${said.lists.join(", ")}` : ""}`,
          said.sections.join() === (testers ? "get,report,new,testers,questions" : "get,report,new,questions")
          && said.news.length >= 1 && said.heads >= 1 && (!testers || said.lists.every((n) => n > 0)));
        check(`${label}: nothing moved as it loaded: ${moved}`, moved < 0.02);
        await shot(page, `hub-${width}-${theme}-${who}.png`, true);
        await context.close();
      }
    }
  });

  // --- off ----------------------------------------------------------------
  if ((!open || !remote) && asked("off")) await section("off", async () => {
    console.log("off: nothing drawn");
    for (const [width, theme, who] of remote ? [[1280, "light", "out"], [390, "dark", "out"]] : [[1280, "light", "in"], [390, "dark", "out"]]) {
      const { context, page, told, label } = await visitor({ width, theme, who, beta: "off" });
      const drawn = [];
      let scriptsAfterFirst = -1;
      // /beta, the beta's own page, asks the server each time, as it must.
      let hubAsked = 0;
      for (const where of PAGES) {
        const was = told.scripts.length;
        await go(page, where);
        if (scriptsAfterFirst < 0) scriptsAfterFirst = told.scripts.length;
        if (where === "/beta") hubAsked += told.scripts.length - was;
        const said = await page.evaluate(() => ({ bar: Boolean(document.getElementById("beta-bar")),
          marked: ["beta", "betabar"].filter((name) => document.documentElement.hasAttribute(`data-${name}`)),
          // The homepage's (privacy's and the terms' #beta are their own).
          band: document.querySelector(".beta-panel") ? getComputedStyle(document.querySelector(".beta-panel").closest("section")).display : "none" }));
        if (said.bar || said.marked.length || said.band !== "none") drawn.push(`${where}: ${JSON.stringify(said)}`);
      }
      check(`${label}: no bar, no Open beta, on all ${PAGES.length} pages${drawn.length ? `: ${drawn.slice(0, 3).join("; ")}` : ""}`, !drawn.length);
      const later = told.scripts.length - scriptsAfterFirst - hubAsked;
      check(`${label}: the bar's script asked for once (${scriptsAfterFirst}), then by no page but /beta for ten minutes (${later})`,
        scriptsAfterFirst <= 1 && later === 0);
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
  });

  // --- same ---------------------------------------------------------------
  // Both sites side by side, page by page, settled (network quiet), at the
  // same moment: what each says, how tall it is and its first screen. The
  // words must be the same. A page whose height or first screen differs is
  // taken again, each side in a browser of its own: it passes if ours then
  // matches one of pre261's, or if pre261's own two differ as much (this
  // browser draws some pages a little differently each time: a gallery
  // picture, a gradient, a font's hinting; pre261 against itself showed it
  // on 14 of 80, run2/control). Else it keeps both pictures and where they
  // differ (red), and fails.
  if (!remote && before && asked("same")) await section("same", async () => {
    console.log(`same: the beta off, each page as ${before} shows it`);
    const compare = await browser.newPage();
    const settle = async (page, where, again) => {
      if (again) await page.reload({ waitUntil: "load", timeout: 60000 });
      else await page.goto(base + where, { waitUntil: "load", timeout: 60000 });
      await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => null);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(again ? 1500 : 600);
      const words = await page.evaluate(() => ({ text: document.body.innerText, height: document.documentElement.scrollHeight }));
      return { ...words, picture: await page.screenshot({ timeout: 60000 }).catch(() => null) };
    };
    const differ = async (a, b) => compare.evaluate(async ([one, two]) => {
      const load = (src) => new Promise((done) => { const img = new Image(); img.onload = () => done(img); img.src = src; });
      const [x, y] = await Promise.all([load(one), load(two)]);
      if (x.width !== y.width || x.height !== y.height) return { n: -1 };
      const canvas = new OffscreenCanvas(x.width, x.height);
      const draw = canvas.getContext("2d", { willReadFrequently: true });
      draw.drawImage(x, 0, 0);
      const first = draw.getImageData(0, 0, x.width, x.height);
      draw.drawImage(y, 0, 0);
      const second = draw.getImageData(0, 0, x.width, x.height);
      let n = 0;
      const seen = first.data;
      for (let i = 0; i < seen.length; i += 4) {
        // A colour off by a few levels (a corner's antialiasing, a
        // gradient's dither) is not a difference anyone sees.
        const same = Math.abs(seen[i] - second.data[i]) <= 8 && Math.abs(seen[i + 1] - second.data[i + 1]) <= 8
          && Math.abs(seen[i + 2] - second.data[i + 2]) <= 8;
        if (!same) n += 1;
        // Where they differ in red, over the before picture faded.
        if (same) { seen[i] = 128 + seen[i] / 2; seen[i + 1] = 128 + seen[i + 1] / 2; seen[i + 2] = 128 + seen[i + 2] / 2; }
        else { seen[i] = 230; seen[i + 1] = 0; seen[i + 2] = 0; }
      }
      if (!n) return { n };
      draw.putImageData(first, 0, 0);
      const blob = await canvas.convertToBlob({ type: "image/png" });
      const bytes = new Uint8Array(await blob.arrayBuffer());
      let text = "";
      for (let i = 0; i < bytes.length; i += 32768) text += String.fromCharCode(...bytes.subarray(i, i + 32768));
      return { n, diff: btoa(text) };
    }, [`data:image/png;base64,${a.picture.toString("base64")}`, `data:image/png;base64,${b.picture.toString("base64")}`]);
    for (const [width, theme] of [[1280, "light"], [390, "dark"]]) {
      const sides = {};
      for (const [side, tree] of [["before", before], ["now", root]]) {
        sides[side] = await visitor({ width, theme, who: "out", beta: "off", tree, motion: "reduce" });
      }
      const differs = [];
      const unsteady = [];
      const exact = async (x, y) => x.text === y.text && x.height === y.height && x.picture && y.picture && (await differ(x, y)).n === 0;
      const alone = async (tree, where) => {
        const one = await visitor({ width, theme, who: "out", beta: "off", tree, motion: "reduce" });
        try {
          return await settle(one.page, where, false);
        } finally {
          await one.context.close();
        }
      };
      // /beta is the beta's hub now, and says Coming soon its own way (off).
      for (const where of PAGES.filter((one) => one !== "/beta")) {
        const [a, b] = await Promise.all([settle(sides.before.page, where, false), settle(sides.now.page, where, false)]);
        if (await exact(a, b)) continue;
        const pixels = a.picture && b.picture ? await differ(a, b) : { n: -2 };
        const sameText = a.text === b.text;
        if (sameText) {
          const [a2, b2] = [await alone(before, where), await alone(root, where)];
          if ((await exact(a, b2)) || (await exact(a2, b2)) || (await exact(a2, b))) continue;
          // Unsteady in pre261 too, and ours as tall as one of its own.
          if (!(await exact(a, a2)) && a2.text === a.text && [b.height, b2.height].some((h) => h === a.height || h === a2.height)) {
            const own = a.picture && a2.picture ? (await differ(a, a2)).n : -2;
            unsteady.push(`${where} (pre261 ${a.height}/${a2.height} px, ${own} pixels apart; ours ${b.height}/${b2.height} px, ${pixels.n})`);
            continue;
          }
        }
        differs.push(`${where}: ${sameText ? "same words" : "other words"}, ${a.height} -> ${b.height} px, ${pixels.n} pixels`);
        const name = `same-${width}-${theme}-${where.replace(/[^a-z0-9]+/gi, "_") || "home"}`;
        if (a.picture) writeFileSync(path.join(out, `${name}-before.png`), a.picture);
        if (b.picture) writeFileSync(path.join(out, `${name}-now.png`), b.picture);
        if (pixels.diff) writeFileSync(path.join(out, `${name}-diff.png`), Buffer.from(pixels.diff, "base64"));
        if (!sameText) writeFileSync(path.join(out, `${name}-words.txt`), `${a.text}\n\n----- now -----\n\n${b.text}`);
      }
      if (unsteady.length) console.log(`  --    ${width} ${theme}: drawn differently by pre261 itself, ours within it: ${unsteady.join("; ")}`);
      for (const side of Object.values(sides)) await side.context.close();
      check(`${width} ${theme}: all ${PAGES.length - 1} pages but /beta show what before showed (words, height, first screen)${differs.length
        ? `, not: ${differs.slice(0, 8).join("; ")}` : ""}`, !differs.length);
    }
    await compare.close();
  });

  // --- weight -------------------------------------------------------------
  if (!remote && before && asked("weight")) await section("weight", async () => {
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
  });
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  await browser.close();
}
check(`no page errors: ${errors.slice(0, 4).join(" | ") || "none"}`, errors.length === 0);
console.log(`betahome: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "betahome: all ok" : "betahome: FAILED");
process.exit(failed === 0 ? 0 : 1);
