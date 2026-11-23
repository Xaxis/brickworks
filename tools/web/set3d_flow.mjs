// A set's page turns the set in 3D in the page (set3d, 2026-11-23), as a
// gallery model's page does: /library/set/<number> of a set LDraw has a
// model of, the picture first and the 3D view (web/start3d.js,
// /viewer3d.js, tools/viewer/inline.js) only on View in 3D, in real
// browsers, against a site (a deployment, or tools/web/relay_server.mjs).
//
//   set -a; . ./.env; set +a
//   node tools/web/set3d_flow.mjs --url=<site> --out=DIR [--sets=N,N] [--widths=1280,390]
//     [--themes=light,dark] [--langs=de,fr,es] [--store-log=FILE]
//
//   1. Each modelled set (SETS: 30 to 9,000 parts, three of them Technic),
//      at each width and theme, signed out: the picture first and none of
//      the 3D view's code asked for; View in 3D a button named for the set;
//      on it, the model drawn in the picture's frame (Turn it anyway where
//      the device asks first), whole, nothing on the page moving; its tools
//      named and Open in the app beside them, the stage it is drawn on named
//      with the set's name; the keys (an arrow turns it, + nearer, 0 back),
//      or on a phone a swipe across turning it; Full screen and back once a
//      set; Back to the picture. Pictures: its first screen, and in 3D.
//   2. Sets with no model, catalogue only (10497-1, and a Duplo set, which
//      LDraw has none of): the picture, no View in 3D, none of the 3D code,
//      and the page saying it has no 3D model yet.
//   3. No WebGL (the page's canvases refuse it): View in 3D says the
//      browser cannot draw in 3D and leaves the picture, with no script
//      error.
//   4. The page in German, French and Spanish: View in 3D and the tools in
//      the page's language.
//   5. What a view costs: the 3D code, the scene and the geometry, each
//      said; a second view in the same browser asks for no geometry again;
//      each answer the site gave a view is one the CDN keeps (public,
//      s-maxage a day or more); and with --store-log (the relay run with
//      the store-counting preload) the bytes the site's functions read from
//      storage for each view, the second view of a set reading none.
//
// Fails too when a script error reaches the console. Exits 1 on any FAIL.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { launch } from "./browser.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("set3d_flow: --url=<site>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/set3d"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
// "--langs=none" (or --plain=none) leaves that part out.
const list = (given, fallback) => String(given || fallback).split(",").map((one) => one.trim()).filter((one) => one && one !== "none");
/// Sets of every size LDraw has a model of: 30, 101, 451 parts, a Technic
/// hovercraft (456), a Technic Porsche (1,578), the Saturn V (1,969), the
/// Boutique Hotel (3,066), the Technic Liebherr (4,106, 6.3 million
/// triangles), the Millennium Falcon (5,205) and the Titanic (9,092).
const SETS = list(args.sets, "30035-1,1499-1,6208-1,42120-1,42096-1,21309-1,10297-1,42100-1,10179-1,10294-1");
/// Catalogue only: Galaxy Explorer, and a Duplo train (LDraw models no Duplo).
const PLAIN = list(args.plain, "10497-1,10428-1");
const WIDTHS = list(args.widths, "1280,390").map(Number);
const THEMES = list(args.themes, "light,dark");
const LANGS = list(args.langs, "de,fr,es");
const storeLog = args["store-log"] ? path.resolve(String(args["store-log"])) : "";

const t0 = Date.now();
const said = [];
let failed = 0;
const check = (line, passed) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  if (!passed) failed += 1;
  return passed;
};
const until = (page, test, arg, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
const kb = (n) => `${Math.round((n || 0) / 1024).toLocaleString("en-US")} KB`;

/// The storage reads the relay's preload has logged so far: one {path, bytes} a line.
const storeReads = () => (storeLog && existsSync(storeLog)
  ? readFileSync(storeLog, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line)) : []);

/// A context of one width and theme, its page's errors kept, each answer
/// the site gave it noted (its address and Cache-Control).
async function opened(browser, width, theme, { webgl = true } = {}) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 800 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!webgl) {
    // A browser that cannot draw in 3D: every canvas refuses WebGL.
    await context.addInitScript(() => {
      const made = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function getContext(kind, ...rest) {
        return /webgl/i.test(String(kind)) ? null : made.call(this, kind, ...rest);
      };
    });
  }
  const page = await context.newPage();
  page.errors = [];
  page.answers = [];
  page.on("pageerror", (e) => page.errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      page.errors.push(m.text().slice(0, 200));
    }
  });
  page.on("response", (answer) => {
    const url = answer.url();
    if (url.startsWith(site)) page.answers.push({ url: url.slice(site.length), status: answer.status(), cache: answer.headers()["cache-control"] || "" });
  });
  return { context, page, phone };
}

/// The page's frame and the 3D view's state, as a check reads them.
const frameOf = () => {
  const box = (el) => {
    if (!el || el.hidden) return null;
    const r = el.getBoundingClientRect();
    return [r.left, r.top, r.width, r.height].map((n) => Math.round(n));
  };
  const b = window.brickworks3d;
  return { picture: box(document.querySelector(".set-page .picture")), shell: box(document.querySelector(".set-page .view3d")),
    height: document.documentElement.scrollHeight, y: scrollY,
    // Where the page below the picture begins: the parts list fills in after load and grows the page
    // downward from there (1499-1 at 1280 grew 362 px under the view), so its top is what must hold.
    below: (() => { const el = document.querySelector(".set-page #parts"); return el ? Math.round(el.getBoundingClientRect().top + scrollY) : -1; })(), state: b?.state || "", full: Boolean(b?.full),
    engaged: b?.engaged ? b.engaged() : null, touch: b?.touchAction ? b.touchAction() : "", angle: b?.angle ? b.angle() : null,
    viewport: [innerWidth, innerHeight] };
};
/// Until the page's height has held for a second (20 s at most): a section that fills in after
/// load (1499-1 at 1280 dark grew 362 px under the view, 11-23) is not the 3D view moving the page.
const settled = (page) => page.waitForFunction(() => {
  const h = document.documentElement.scrollHeight;
  const was = window.__set3dHeld;
  if (!was || was.h !== h) { window.__set3dHeld = { h, t: performance.now() }; return false; }
  return performance.now() - was.t > 1000;
}, null, { timeout: 20000, polling: 200 }).then(() => true, () => false);
/// Until the model has stopped turning (its angle the same a second apart), in ms; -1 past 120 s.
async function still(page) {
  const began = Date.now();
  let last = null;
  while (Date.now() - began < 120000) {
    const now = await page.evaluate(() => JSON.stringify(window.brickworks3d?.angle ? window.brickworks3d.angle() : null));
    if (now === last) return Date.now() - began;
    last = now;
    await page.waitForTimeout(1000);
  }
  return -1;
}
const near = (a, b) => a && b && Math.abs(a.round - b.round) < 1e-3 && Math.abs(a.up - b.up) < 1e-3
  && Math.abs(a.distance - b.distance) < b.distance * 1e-3;

/// What the page shows before View in 3D: the picture drawn, the way into
/// 3D and none of its code.
const before3d = () => {
  const frame = document.querySelector(".set-page .picture");
  const img = frame?.querySelector("img");
  return { asked: performance.getEntriesByType("resource").map((r) => r.name).filter((n) => /viewer3d|three/.test(n)),
    loaded: Boolean(window.brickworks3d), scene: frame?.dataset.scene || "", control: frame?.querySelector(".go")?.textContent || "",
    role: frame?.getAttribute("role") || "", name: frame?.getAttribute("aria-label") || "", drawn: Boolean(img && img.complete && img.naturalWidth),
    title: document.querySelector(".set-page h1")?.textContent || "",
    no3d: document.querySelector(".set-page .no3d")?.textContent.trim() || "",
    words: globalThis.brickworksLang ? ["View in 3D", "Zoom in", "Full screen", "Open in the app", "Back to the picture"]
      .map((one) => globalThis.brickworksLang.say(one)) : null };
};

/// View in 3D on [page], and the model drawn: what it got.
async function view3d(page, phone) {
  if (phone) await page.tap(".set-page .picture .go");
  else await page.click(".set-page .picture .go");
  // Ten minutes: the Liebherr's 6.3 million triangles took 313 s to draw whole in SwiftShader at a load
  // of 70 (flow2), and the line says how long each took.
  const drawn = () => until(page, () => {
    const b = window.brickworks3d;
    return b && (b.timings.complete3d || b.state === "failed" || b.state === "big");
  }, null, 600000);
  let came = await drawn();
  const asked = await page.evaluate(() => (window.brickworks3d.state === "big"
    ? document.querySelector(".view3d-said")?.textContent || "" : ""));
  if (asked) {
    await page.click(".view3d-said button");
    came = await drawn();
  }
  const got = await page.evaluate(() => {
    const b = window.brickworks3d;
    const code = performance.getEntriesByType("resource").find((r) => /\/viewer3d\.js/.test(r.name));
    const geometry = performance.getEntriesByType("resource").filter((r) => /\.lbm(\?|$)/.test(r.name));
    return { state: b.state, timings: b.timings, parts: b.parts, shapes: b.shapes, triangles: b.triangles, scene: b.sceneBytes,
      geometry: b.geometryBytes, errors: b.errors, sample: b.sample ? b.sample() : null, shown: b.shown ? b.shown() : 0,
      code: code ? { sent: code.transferSize, size: code.decodedBodySize } : null,
      fetched: geometry.filter((r) => r.transferSize > 0).length, geometryFiles: geometry.length,
      tools: [...document.querySelectorAll(".view3d-tools [data-act]")].map((t) => t.getAttribute("aria-label")),
      app: (() => { const a = document.querySelector(".view3d-app"); return a && !a.hidden ? `${a.textContent} ${a.getAttribute("href")}` : ""; })(),
      href: document.querySelector(".set-page .picture").getAttribute("href"),
      stage: document.querySelector(".set-page .view3d .stage")?.getAttribute("aria-label") || "",
      stageRole: document.querySelector(".set-page .view3d .stage")?.getAttribute("role") || "",
      said: document.querySelector(".view3d-said")?.textContent || "" };
  });
  return { came, asked, got };
}

const results = [];
const browser = await launch({ signedOut: true });
try {
  // 1. Each modelled set, at each width and theme.
  for (const set of SETS) {
    for (const width of WIDTHS) {
      for (const theme of THEMES) {
        const label = `${set} ${width} ${theme}`;
        const stem = `${set}_${width}_${theme}`;
        const { context, page, phone } = await opened(browser, width, theme);
        const firstOfSet = width === WIDTHS[0] && theme === THEMES[0];
        const reads = storeReads().length;
        try {
          await page.goto(`${site}/library/set/${set}`, { waitUntil: "load", timeout: 120000 });
          await until(page, () => {
            const img = document.querySelector(".set-page .picture img");
            return !img || (img.complete && img.naturalWidth > 0);
          }, null, 30000);
          await page.waitForTimeout(300);
          const was = await page.evaluate(before3d);
          await page.screenshot({ path: path.join(out, `${stem}_fold.png`) });
          check(`${label}: ${was.title}: its picture first (${was.drawn ? "drawn" : "not drawn"}), none of the 3D view's code asked for `
            + `(${was.asked.join(", ") || "none"})`, was.drawn && was.asked.length === 0 && !was.loaded);
          check(`${label}: the picture says ${was.control || "nothing"}, a button named "${was.name}", its scene ${was.scene}`,
            was.control === "View in 3D" && was.role === "button" && was.name === `View ${was.title} in 3D, here`
              && /^\/library\/omr-[^/]+\/scene\.json$/.test(was.scene) && !was.no3d);
          await settled(page);
          const frame = await page.evaluate(frameOf);
          const { came, asked, got } = await view3d(page, phone);
          const after = await page.evaluate(frameOf);
          const t = got.timings || {};
          const from = (k) => (t[k] && t.asked ? `${((t[k] - t.asked) / 1000).toFixed(2)} s` : "-");
          if (asked) check(`${label}: past what this device turns smoothly it asks first ("${asked}")`, /Turn it anyway/.test(asked));
          check(`${label}: View in 3D draws it here (${got.state}${got.said ? `, "${got.said}"` : ""}): ${got.parts} parts, ${got.shapes} shapes, `
            + `${((got.triangles || 0) / 1e6).toFixed(2)}M triangles; code ${got.code ? `${kb(got.code.sent)} sent` : "?"}, scene ${kb(got.scene)}, `
            + `geometry ${kb(got.geometry)} (${got.fetched} of ${got.geometryFiles} files over the network); first frame ${from("first3d")}, all ${from("complete3d")}`,
          came && got.state === "ready" && got.parts > 0 && got.shown === got.parts && !got.errors.length);
          check(`${label}: a frame with the model in it, whole (${got.sample ? `${(got.sample.drawn * 100).toFixed(1)}%, ${got.sample.colours} colours${got.sample.cut ? ", cut off at an edge" : ""}` : "none"})`,
            Boolean(got.sample && got.sample.drawn > 0.01 && !got.sample.cut));
          check(`${label}: in the picture's frame (${after.shell} over ${frame.picture}), nothing on the page moved (what follows it at ${frame.below} px, then ${after.below}; `
            + `the page ${frame.height} px tall, then ${after.height})`,
            JSON.stringify(after.shell) === JSON.stringify(frame.picture) && after.below === frame.below && after.y === frame.y);
          check(`${label}: its tools named (${got.tools.join(", ")}), ${got.app || "no way into the app"}, the stage ${got.stageRole} "${got.stage.slice(0, 60)}…"`,
            JSON.stringify(got.tools) === JSON.stringify(["Zoom out", "Zoom in", "Reset the view", "Full screen", "Back to the picture"])
              && got.app === `Open in the app ${got.href}` && got.stageRole === "application" && got.stage.startsWith(`${was.title} in 3D.`));
          await page.screenshot({ path: path.join(out, `${stem}_3d.png`) });
          const home = after.angle;
          if (got.state === "ready" && phone) {
            const cdp = await context.newCDPSession(page);
            const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
              touchPoints: points.map(([x, y], i) => ({ x, y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
            const middle = [after.shell[0] + after.shell[2] / 2, after.shell[1] + after.shell[3] / 2];
            const a = [middle[0] + 80, middle[1]];
            const b = [middle[0] - 80, middle[1]];
            await touch("touchStart", [a]);
            for (let n = 1; n <= 12; n++) {
              await touch("touchMove", [[a[0] + ((b[0] - a[0]) * n) / 12, a[1]]]);
              await page.waitForTimeout(30);
            }
            await touch("touchEnd", []);
            await page.waitForTimeout(300);
            const turned = await page.evaluate(frameOf);
            await cdp.detach();
            check(`${label}: a swipe across turns it (${home.round.toFixed(2)} to ${turned.angle?.round.toFixed(2)}), the page where it was (${turned.y} px)`,
              turned.angle && Math.abs(turned.angle.round - home.round) > 0.05 && turned.y === frame.y);
          } else if (got.state === "ready") {
            await page.focus(".set-page .view3d .stage");
            await page.keyboard.press("ArrowRight");
            const turned = await page.evaluate(frameOf);
            await page.keyboard.press("+");
            const nearer = await page.evaluate(frameOf);
            await page.keyboard.press("0");
            const back = await page.evaluate(frameOf);
            check(`${label}: the keys: an arrow turns it (${home.round.toFixed(2)} to ${turned.angle.round.toFixed(2)}), + nearer `
              + `(${Math.round(turned.angle.distance)} to ${Math.round(nearer.angle.distance)}), 0 back to the start`,
            Math.abs(turned.angle.round - home.round) > 0.2 && nearer.angle.distance < turned.angle.distance * 0.9 && near(back.angle, home));
          }
          if (got.state === "ready" && firstOfSet) {
            await page.click('.view3d-tools [data-act="full"]');
            await until(page, () => window.brickworks3d.full, null, 8000);
            await page.waitForTimeout(400);
            const full = await page.evaluate(() => {
              const r = document.querySelector(".set-page .view3d").getBoundingClientRect();
              return { box: [r.left, r.top, r.width, r.height].map(Math.round), viewport: [innerWidth, innerHeight],
                sample: window.brickworks3d.sample() };
            });
            await page.screenshot({ path: path.join(out, `${stem}_3d_full.png`) });
            check(`${label}: Full screen fills the screen (${full.box} in ${full.viewport}), the model whole in it`,
              full.box[0] === 0 && full.box[1] === 0 && full.box[2] >= full.viewport[0] - 1 && full.box[3] >= full.viewport[1] - 1
                && full.sample && full.sample.drawn > 0.01 && !full.sample.cut);
            await page.click('.view3d-tools [data-act="full"]');
            await until(page, () => !window.brickworks3d.full && !document.fullscreenElement, null, 8000);
            await page.waitForTimeout(300);
          }
          if (got.state === "ready") {
            // A swipe leaves the model turning on to a stop, and in SwiftShader each of those frames of
            // a 450-part set at a phone's pixels takes seconds: a press made then is answered only once
            // they are drawn (6208-1 at 390: 30 s, and the view closed after the click had timed out).
            // Even still, the Porsche's 2.5 million triangles at a phone's pixels took over 120 s to answer
            // a press (each of the frames a click waits on is many seconds), so it has five minutes.
            const stillAfter = await still(page);
            const pressed = Date.now();
            await page.click('.view3d-tools [data-act="close"]', { timeout: 300000 });
            await page.waitForTimeout(200);
            const closed = await page.evaluate(frameOf);
            check(`${label}: Back to the picture puts the picture back (${closed.state}; still after `
              + `${stillAfter < 0 ? "over 120 s" : `${(stillAfter / 1000).toFixed(1)} s`}, answered in `
              + `${((Date.now() - pressed) / 1000).toFixed(1)} s)`, closed.state === "closed" && closed.shell === null
              && JSON.stringify(closed.picture) === JSON.stringify(frame.picture));
          }
          // 5. What a view of it costs, a second time in the same browser.
          if (got.state === "ready" && firstOfSet) {
            const again = await context.newPage();
            again.errors = page.errors;
            await again.goto(`${site}/library/set/${set}`, { waitUntil: "load", timeout: 120000 });
            const second = await view3d(again, phone);
            check(`${label}: a second view in the same browser asks for none of its geometry again (${second.got.fetched} of `
              + `${second.got.geometryFiles} parts' files over the network), ${second.got.state}`,
            second.got.state === "ready" && second.got.geometryFiles > 0 && second.got.fetched === 0);
            await again.close();
          }
          const kept = page.answers.filter((one) => one.status === 200 && /\/library\//.test(one.url));
          const unkept = kept.filter((one) => !/public/.test(one.cache) || !(Number(/s-maxage=(\d+)/.exec(one.cache)?.[1]) >= 86400));
          check(`${label}: every answer of the library the view had is one the CDN keeps a day or more (${kept.length}: `
            + `${[...new Set(kept.map((one) => one.cache))].join(" | ")})`, kept.length > 0 && unkept.length === 0);
          const read = storeReads().slice(reads);
          const bytes = read.reduce((n, one) => n + one.bytes, 0);
          results.push({ set, width, theme, state: got.state, parts: got.parts, triangles: got.triangles, scene: got.scene,
            geometry: got.geometry, code: got.code, timings: t, storeRead: read, sample: got.sample });
          if (storeLog) {
            console.log(`        storage read for this view: ${kb(bytes)} (${read.map((one) => `${one.path} ${kb(one.bytes)}`).join(", ") || "none"})`);
            if (!firstOfSet) {
              // This set's file only: another run against the same relay reads its own sets' (flow4 counted
              // flow5's first read of 42100-1 against 42120-1).
              const mine = read.filter((one) => one.path.endsWith(`/${set}.mpd`));
              check(`${label}: a view after the set's first reads none of its file from storage (${mine.length} reads of it)`,
                mine.length === 0);
            }
          }
          check(`${label}: no script error (${page.errors.join(" | ") || "none"})`, page.errors.length === 0);
        } catch (trouble) {
          // What the view and the page were doing then: a closed view, its errors, a page since reloaded.
          const then = await page.evaluate(() => ({ state: window.brickworks3d?.state || "", errors: window.brickworks3d?.errors || [],
            said: document.querySelector(".view3d-said")?.textContent || "", since: Math.round(performance.now()) }))
            .catch((why) => ({ state: `unreadable: ${String(why).split("\n")[0]}` }));
          check(`${label}: ${String(trouble).split("\n")[0]} (the view ${then.state || "never opened"}`
            + `${then.errors?.length ? `, ${then.errors.join(" | ")}` : ""}${then.said ? `, "${then.said}"` : ""}, `
            + `the page ${then.since ?? "?"} ms old; ${page.errors.join(" | ") || "no script error"})`, false);
          await page.screenshot({ path: path.join(out, `${stem}_failed.png`) }).catch(() => {});
        } finally {
          await context.close();
        }
      }
    }
  }

  // 2. Sets with no model: the picture, and the page says so.
  for (const set of PLAIN) {
    for (const width of WIDTHS) {
      const theme = THEMES[0];
      const label = `${set} ${width} ${theme} (no model)`;
      const { context, page } = await opened(browser, width, theme);
      try {
        await page.goto(`${site}/library/set/${set}`, { waitUntil: "load", timeout: 120000 });
        await until(page, () => {
          const img = document.querySelector(".set-page .picture img");
          return !img || (img.complete && img.naturalWidth > 0);
        }, null, 30000);
        await page.waitForTimeout(800);
        const was = await page.evaluate(before3d);
        await page.screenshot({ path: path.join(out, `${set}_${width}_${theme}_fold.png`) });
        check(`${label}: ${was.title}: its picture (${was.drawn ? "drawn" : "not drawn"}), no View in 3D, none of the 3D code, and it says "${was.no3d}"`,
          was.drawn && !was.control && !was.scene && was.asked.length === 0 && /no 3D model/i.test(was.no3d));
        check(`${label}: no script error (${page.errors.join(" | ") || "none"})`, page.errors.length === 0);
      } catch (trouble) {
        check(`${label}: ${String(trouble).split("\n")[0]}`, false);
      } finally {
        await context.close();
      }
    }
  }

  // 3. No WebGL: it says so and leaves the picture.
  {
    const set = SETS.includes("6208-1") ? "6208-1" : SETS[0];
    const label = `${set} 1280 ${THEMES[0]} (no WebGL)`;
    const { context, page } = await opened(browser, 1280, THEMES[0], { webgl: false });
    try {
      await page.goto(`${site}/library/set/${set}`, { waitUntil: "load", timeout: 120000 });
      await page.click(".set-page .picture .go");
      await until(page, () => window.brickworks3d && window.brickworks3d.state === "failed", null, 60000);
      const got = await page.evaluate(() => ({ state: window.brickworks3d?.state, said: document.querySelector(".view3d-said")?.textContent || "",
        picture: Boolean(document.querySelector(".set-page .picture img")?.naturalWidth),
        canvas: document.querySelectorAll(".set-page .view3d canvas").length }));
      await page.screenshot({ path: path.join(out, `${set}_nowebgl.png`) });
      check(`${label}: View in 3D says "${got.said}", the picture still there (${got.picture}), no canvas`,
        got.state === "failed" && /cannot draw in 3D/.test(got.said) && got.picture && got.canvas === 0);
      check(`${label}: no script error (${page.errors.join(" | ") || "none"})`, page.errors.length === 0);
    } catch (trouble) {
      check(`${label}: ${String(trouble).split("\n")[0]}`, false);
    } finally {
      await context.close();
    }
  }

  // 4. In each language.
  for (const lang of LANGS) {
    const set = SETS.includes("6208-1") ? "6208-1" : SETS[0];
    const plain = PLAIN[0];
    const label = `/${lang} ${set} 1280 ${THEMES[0]}`;
    const { context, page } = await opened(browser, 1280, THEMES[0]);
    try {
      await page.goto(`${site}/${lang}/library/set/${plain}`, { waitUntil: "load", timeout: 120000 });
      const none = await page.evaluate(before3d);
      check(`/${lang} ${plain}: the page says it has no 3D model in its language ("${none.no3d}")`,
        Boolean(none.no3d) && !/no 3D model/i.test(none.no3d));
      await page.goto(`${site}/${lang}/library/set/${set}`, { waitUntil: "load", timeout: 120000 });
      const was = await page.evaluate(before3d);
      const [view, zoom, full, app, back] = was.words || [];
      check(`${label}: View in 3D in its language ("${was.control}"), its scene ${was.scene}`,
        Boolean(was.words) && was.control === view && view !== "View in 3D" && Boolean(was.scene));
      const { got } = await view3d(page, false);
      await page.screenshot({ path: path.join(out, `${lang}_${set}_3d.png`) });
      check(`${label}: drawn (${got.state}), its tools in its language (${got.tools.join(", ")}), ${got.app.split(" /")[0]}`,
        got.state === "ready" && got.tools.includes(zoom) && got.tools.includes(full) && got.tools.includes(back)
          && got.app.startsWith(app) && zoom !== "Zoom in");
      check(`${label}: no script error (${page.errors.join(" | ") || "none"})`, page.errors.length === 0);
    } catch (trouble) {
      check(`${label}: ${String(trouble).split("\n")[0]}`, false);
    } finally {
      await context.close();
    }
  }
} finally {
  await browser.close();
}

writeFileSync(path.join(out, "set3d.json"), JSON.stringify({ site, sets: SETS, plain: PLAIN, results, said }, null, 1));
console.log(`set3d_flow: ${said.length - failed} passed, ${failed} failed; pictures and set3d.json in ${out}`);
process.exit(failed ? 1 : 0);
