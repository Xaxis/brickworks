// A set's page as the place search sends people (sethub, 2026-11-23;
// docs/PLAN.md row 2): /library/set/<number> of a set LDraw modelled has
// Build it (the studio at its first step), Make your own version (LDraw's
// model opened in the studio as a credited copy), Versions of this set (the
// copies people published), Built from this set (altbuilds) and You own
// (ownedparts), in real browsers against a site (a deployment, or
// tools/web/relay_server.mjs).
//
//   set -a; . ./.env; set +a
//   node tools/web/sethub_flow.mjs --url=<site> --out=DIR [--sets=N,N] [--publish]
//     [--widths=1280,390] [--themes=light,dark] [--versions=FILE] [--open-time[=N] [--pages] [--trace]]
//
//   1. Each modelled set, at each width and theme, signed out: Build it
//      opens LDraw's model at its first step (&build) and Make your own
//      version opens it as it is, under the set's name; Versions of this set
//      comes before Built from this set, its cards each saying whether the
//      version was changed from LDraw's model, or, with none, saying so with
//      Make your own version (the same link); nothing on the page moved for
//      them (the picture's place is where it was). Pictures: the first
//      screen, and the rows. --versions=FILE answers set_based's versions
//      from FILE (a set_versions answer, as a dry run of
//      supabase/set_versions.sql printed it), to see the row as it will be.
//   2. A set with no model (10497-1): neither button, no Versions row.
//   3. In German, French and Spanish: Make your own version in the page's
//      language.
//   4. --publish (once supabase/set_versions.sql is applied): this run's own
//      account publishes a version of 346-2 (its LDraw model's file with
//      the credit the studio writes, a tenth of its parts taken out, as a
//      test model), and set_based is asked as the page asks it, through the
//      CDN, until the version is there: within 60 s (the bar). Then the
//      set's page (?tests=1) shows its card, said changed. The account and
//      its model are deleted at the end.
//   5. --open-time[=ROUNDS] (3), against a deployment with the app: Make
//      your own version's address and the studio's own (/app?new=1), each
//      in a browser of its own at the same moment, signed in, warmed by one
//      round not counted: the set (346-2) on the baseplate, every part down,
//      no later than the plain studio is up + 2 s (the bar), at the median.
//      With the app that takes --build (sethub), Build it's address too:
//      its timeline up at step 1.
//
// Fails too when a script error reaches the console. Exits 1 on any FAIL.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { launch } from "./browser.mjs";
import { endOwnAccount, mintSession, ownAccount } from "./session.mjs";
import { cardOf } from "../../api/_directory.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("sethub_flow: --url=<site>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/sethub"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
// --viewport=WxH (1400x900): 390 wide or less is a phone's, touch and all.
const [viewWidth, viewHeight] = String(args.viewport || "1400x900").split("x").map(Number);
const viewport = { width: viewWidth || 1400, height: viewHeight || 900 };
// --chrome-trace=DIR: each open-time page traced whole, as DIR/<plain|version><round>.json.
const chromeTrace = args["chrome-trace"] && args["chrome-trace"] !== true ? path.resolve(String(args["chrome-trace"])) : "";
if (chromeTrace) mkdirSync(chromeTrace, { recursive: true });
// --open=ADDRESS: what is opened beside the plain studio (Make your own
// version's, /app?new=1&library=omr-346-2), e.g. a shared model's Open in the app.
const openAt = String(args.open && args.open !== true ? args.open : "/app?new=1&library=omr-346-2");
// --bricks=N: the parts down that say it is open (346-2's 165: 150).
const wantBricks = Number(args.bricks) > 0 ? Number(args.bricks) : 150;
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const list = (given, fallback) => String(given || fallback).split(",").map((one) => one.trim()).filter((one) => one && one !== "none");
/// Modelled: House with Car (the house published its LDraw model, so it has
/// a version), and the Millennium Falcon (none yet).
const SETS = list(args.sets, "346-2,10179-1");
const PLAIN = "10497-1";
const WIDTHS = list(args.widths, "1280,390").map(Number);
const THEMES = list(args.themes, "light,dark");
const LANGS = list(args.langs, "de,fr,es");
const MAKE = { de: "Deine eigene Version bauen", fr: "Créer votre propre version", es: "Haz tu propia versión" };
/// The versions a dry run of supabase/set_versions.sql read, as cards.
const stubbed = args.versions ? Object.values(JSON.parse(readFileSync(String(args.versions), "utf8")))[0]
  .map((row) => ({ ...cardOf(site, row), changed: row.changed === true, pieces: Number(row.pieces) || 0 })) : null;

let failed = 0;
const check = (said, ok) => {
  if (!ok) failed += 1;
  console.log(`${ok ? "ok  " : "FAIL"} ${said}`);
  return ok;
};
const errors = [];

async function open(browser, url, width, theme) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 860 }, isMobile: phone, hasTouch: phone,
    colorScheme: theme, extraHTTPHeaders: headers });
  const page = await context.newPage();
  page.on("pageerror", (error) => errors.push(`${url}: ${error.message}`));
  if (stubbed) {
    await page.route(/\/api\/share\?op=set_based&set=346-2/, async (route) => {
      const real = await route.fetch();
      const body = await real.json();
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ...body, versions: stubbed }) });
    });
  }
  const answer = await page.goto(url, { waitUntil: "load", timeout: 120000 });
  return { context, page, answer };
}

/// Where the rows are and what they say, and where the picture is.
const look = () => {
  const said = (one) => one?.textContent.replace(/\s+/g, " ").trim() || "";
  const versions = document.getElementById("versions");
  const built = document.getElementById("built-from");
  const rect = document.querySelector(".picture")?.getBoundingClientRect();
  return {
    build: document.querySelector("[data-build3d]")?.getAttribute("href") || null,
    buildWords: said(document.querySelector("[data-build3d]")),
    version: document.querySelector("[data-version]")?.getAttribute("href") || null,
    versionWords: said(document.querySelector("[data-version]")),
    count: document.documentElement.dataset.versions ?? null,
    heading: said(versions?.querySelector("h2")),
    cards: [...(versions?.querySelectorAll(".model") || [])].map((card) => {
      const who = card.querySelector(".who");
      return { href: card.querySelector("a")?.getAttribute("href") || "", said: said(card.querySelector(".version-said")),
        changed: card.dataset.changed || "", who: said(who?.querySelector("span:not(.avatar)") || who), whoLink: who?.getAttribute("href") || "",
        avatar: Boolean(who?.querySelector(".avatar")), modelledBy: who?.hasAttribute("data-modelled-by") === true,
        from: said(card.querySelector("[data-changed-from]")) };
    }),
    empty: said(versions?.querySelector(".built-empty p")),
    emptyGo: versions?.querySelector("[data-version-empty]")?.getAttribute("href") || null,
    before: Boolean(versions && built && versions.compareDocumentPosition(built) & Node.DOCUMENT_POSITION_FOLLOWING),
    picture: rect ? [Math.round(rect.top), Math.round(rect.height)] : null,
  };
};

/// Whether a version's card ([look]'s) credits it rightly: LDraw's model as
/// it is says "Modelled by" whoever modelled it, and that it is as it is; a
/// changed one names whoever published it (never "Modelled by") and, under
/// it, "Changed from LDraw's model by" whoever modelled LDraw's.
const credited = (card) => (card.changed === "true"
  ? !card.modelledBy && Boolean(card.who) && !card.said && /^Changed from LDraw's model by \S/.test(card.from)
  : card.modelledBy && /^Modelled by \S/.test(card.who) && card.said === "LDraw's model, as it is" && !card.from);

/// The versions' row scrolled to, its pictures given 30 s to come: each
/// card's picture, whether it came, and whether its tile said "No picture".
async function pictured(page) {
  const row = await page.$("#versions");
  if (!row) return [];
  await row.scrollIntoViewIfNeeded();
  await page.waitForFunction(() => [...document.querySelectorAll("#versions .model img")]
    .every((one) => one.complete && one.naturalWidth > 0), null, { timeout: 30000, polling: 250 }).catch(() => null);
  const tiles = await page.evaluate(() => [...document.querySelectorAll("#versions .model")].map((card) => {
    const picture = card.querySelector(".frame img");
    return { id: card.dataset.id, src: picture ? new URL(picture.src).pathname : "", came: Boolean(picture?.naturalWidth),
      none: card.querySelector(".frame")?.classList.contains("none") === true };
  }));
  await page.evaluate(() => window.scrollTo(0, 0));
  return tiles;
}

/// Whether every version's tile shows its model: LDraw's as it is by the
/// library's picture of [model]; a changed one by its own card picture or
/// cut-out, else LDraw's; none blank, none "No picture".
const shownWell = (tiles, model) => tiles.length > 0 && tiles.every((tile) => tile.came && !tile.none
  && (tile.src === `/library/${model}.webp` || new RegExp(`^/m/${tile.id}(\\.webp|\\.cutout\\.png)$`).test(tile.src)));

async function modelled(browser) {
  for (const set of SETS) {
    for (const width of WIDTHS) {
      for (const theme of THEMES) {
        const label = `${set} at ${width} px ${theme}`;
        const { context, page, answer } = await open(browser, `${site}/library/set/${set}`, width, theme);
        try {
          const first = await page.evaluate(look);
          await page.waitForFunction(() => document.documentElement.dataset.versions !== undefined, null, { timeout: 60000 })
            .catch(() => null);
          const seen = await page.evaluate(look);
          const model = (seen.version || "").replace(/^\/app\?new=1&library=/, "");
          check(`${label}: its page answers (${answer?.status()})`, answer?.status() === 200);
          check(`${label}: Build it opens LDraw's model at its first step (${seen.build}, "${seen.buildWords}")`,
            seen.build === `/app?new=1&library=${model}&build` && seen.buildWords === "Build it" && /^omr-/.test(model));
          check(`${label}: Make your own version opens it as it is, a copy to change (${seen.version}, "${seen.versionWords}")`,
            seen.version === `/app?new=1&library=${model}` && seen.versionWords === "Make your own version");
          check(`${label}: Versions of this set, before Built from this set (${seen.count}, "${seen.heading}", before: ${seen.before})`,
            seen.heading === "Versions of this set" && seen.before && seen.count !== "broken" && seen.count !== null);
          if (Number(seen.count) > 0) {
            check(`${label}: each version's card credits it rightly: LDraw's as it is by who modelled it, a changed one `
              + `by who published it, changed from LDraw's model by who modelled that (${JSON.stringify(seen.cards)})`,
              seen.cards.length === Number(seen.count) && seen.cards.every((card) => /^\/m\/[A-Za-z0-9]{10}$/.test(card.href)
                && credited(card)));
            const tiles = await pictured(page);
            check(`${label}: each version's tile shows its model (${JSON.stringify(tiles)})`, shownWell(tiles, model));
          } else {
            check(`${label}: none yet, said, with Make your own version (${seen.empty}, ${seen.emptyGo})`,
              seen.empty === "Nobody has published their own version of this set yet." && seen.emptyGo === seen.version);
          }
          check(`${label}: nothing on the first screen moved for them (picture ${JSON.stringify(first.picture)} then `
            + `${JSON.stringify(seen.picture)})`, JSON.stringify(first.picture) === JSON.stringify(seen.picture));
          if (Number(seen.count) > 0 && width === WIDTHS[0] && theme === THEMES[0]) {
            // The version's own page says which set it is a version of, and links back to the row.
            const card = seen.cards[0].href;
            const back = await page.context().newPage();
            back.on("pageerror", (error) => errors.push(`${card}: ${error.message}`));
            await back.goto(`${site}${card}`, { waitUntil: "load", timeout: 120000 });
            const line = await back.evaluate(() => {
              const one = document.querySelector('#alt-build[data-alt="version"]');
              return { said: one?.textContent.replace(/\s+/g, " ").trim() || "", href: one?.querySelector("a")?.getAttribute("href") || "" };
            });
            check(`${label}: its version's page says so and links back ("${line.said}", ${line.href})`,
              line.said.startsWith("A version of LEGO® set ") && line.href === `/library/set/${set}#versions`);
            await back.screenshot({ path: path.join(out, `${set}_version_page.png`) });
            await back.click('#alt-build[data-alt="version"] a');
            await back.waitForFunction(() => document.documentElement.dataset.versions !== undefined, null, { timeout: 60000 })
              .catch(() => null);
            await back.waitForTimeout(400);
            const there = await back.evaluate(() => {
              const row = document.getElementById("versions")?.getBoundingClientRect();
              return row ? Math.round(row.top) : null;
            });
            check(`${label}: and the link lands on Versions of this set (its top at ${there} px)`,
              there !== null && there >= 0 && there < 200);
            await back.close();
          }
          const name = `${set}_${width}_${theme}`;
          await page.screenshot({ path: path.join(out, `${name}.png`) });
          const row = await page.$("#versions");
          if (row) {
            await row.scrollIntoViewIfNeeded();
            await page.waitForTimeout(400);
            await page.screenshot({ path: path.join(out, `${name}_rows.png`) });
          }
        } finally {
          await context.close();
        }
      }
    }
  }
}

async function plain(browser) {
  const { context, page, answer } = await open(browser, `${site}/library/set/${PLAIN}`, 1280, "light");
  try {
    await page.waitForFunction(() => document.documentElement.dataset.based !== undefined, null, { timeout: 60000 }).catch(() => null);
    const seen = await page.evaluate(look);
    check(`${PLAIN}, no 3D model (${answer?.status()}): no Build it, no Make your own version, no Versions row `
      + `(${seen.build}, ${seen.version}, ${seen.count}, "${seen.heading}")`,
      answer?.status() === 200 && !seen.build && !seen.version && seen.count === null && !seen.heading);
  } finally {
    await context.close();
  }
}

async function languages(browser) {
  for (const lang of LANGS) {
    const { context, page } = await open(browser, `${site}/${lang}/library/set/${SETS[0]}`, 1280, "light");
    try {
      await page.waitForFunction(() => document.documentElement.dataset.versions !== undefined, null, { timeout: 60000 }).catch(() => null);
      const seen = await page.evaluate(look);
      check(`/${lang}: Make your own version in its words ("${seen.versionWords}"), its row named in them ("${seen.heading}")`,
        seen.versionWords === MAKE[lang] && Boolean(seen.heading) && seen.heading !== "Versions of this set");
    } finally {
      await context.close();
    }
  }
}

/// --publish: a version of 346-2 published, and on its page within 60 s.
async function published(browser) {
  const email = await ownAccount();
  const { access_token: token } = await mintSession(email);
  // Its publisher, with a profile in public: what its card and page credit.
  const handle = `sethub-${Date.now().toString(36)}`;
  const named = "Sethub Builder";
  const profile = await fetch(`${site}/api/people?op=profile`, { method: "POST", headers: { ...headers,
    "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify({ handle, name: named }) });
  check(`its publisher has a profile in public (@${handle}: ${profile.status})`, profile.status === 200);
  const house = readFileSync(new URL("../../tests/fixtures/omr_credit/346-2.published.ldr", import.meta.url), "utf8");
  const lines = house.split("\n");
  const parts = lines.map((line, at) => (/^1 .*\.dat\s*$/i.test(line) ? at : -1)).filter((at) => at >= 0);
  const cut = new Set(parts.slice(0, Math.floor(parts.length / 10)));
  const began = Date.now();
  const reply = await fetch(`${site}/api/share`, { method: "POST", headers: { ...headers, "content-type": "application/json",
    authorization: `Bearer ${token}` }, body: JSON.stringify({ name: "Sethub House with Car, my version", author: named, listed: true,
    model: lines.filter((_, at) => !cut.has(at)).join("\n"), licence: "cc-by-4.0" }) });
  const body = await reply.json().catch(() => ({}));
  const id = body.id || "";
  check(`a version of 346-2 published (${reply.status}, ${id}), credited and changed (${JSON.stringify(body.modelled_by)})`,
    reply.status === 201 && body.modelled_by?.changed === true);
  if (!id) return;
  // As the page asks it: the same address, through the CDN.
  let at = 0;
  for (;;) {
    const asked = await fetch(`${site}/api/share?op=set_based&set=346-2&tests=1`, { headers }).then((r) => r.json()).catch(() => null);
    if (asked?.versions?.some((one) => one.id === id)) {
      at = Date.now() - began;
      break;
    }
    if (Date.now() - began > 180000) break;
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  check(`it is among 346-2's versions ${at ? `${(at / 1000).toFixed(1)} s` : "never, in 180 s,"} after its publish (the bar: 60 s)`,
    at > 0 && at <= 60000);
  const { context, page } = await open(browser, `${site}/library/set/346-2?tests=1`, 1280, "light");
  try {
    await page.waitForFunction(() => document.documentElement.dataset.versions !== undefined, null, { timeout: 60000 }).catch(() => null);
    const seen = await page.evaluate(look);
    const card = seen.cards.find((one) => one.href === `/m/${id}`);
    check(`the set's page shows its card first, said changed (${JSON.stringify(card)}, first ${seen.cards[0]?.href})`,
      Boolean(card) && card.changed === "true" && seen.cards[0]?.href === `/m/${id}`);
    check(`its card credits who published it, their picture and name linking their profile, and under it "Changed from `
      + `LDraw's model by Marc Giraudet", never "Modelled by" (${JSON.stringify(card)})`,
      Boolean(card) && card.whoLink === `/u/${handle}` && card.avatar && card.who === named && !card.modelledBy
      && card.from === "Changed from LDraw's model by Marc Giraudet");
    check(`every version's card credits it rightly (${JSON.stringify(seen.cards)})`, seen.cards.length > 0 && seen.cards.every(credited));
    const plainVersion = seen.cards.find((one) => one.changed !== "true");
    // Published with no picture of its own: shown by LDraw's model it was made from.
    const tiles = await pictured(page);
    check(`every version's tile shows its model, this one with no picture of its own LDraw's (${JSON.stringify(tiles)})`,
      shownWell(tiles, "omr-346-2") && tiles.find((tile) => tile.id === id)?.src === "/library/omr-346-2.webp");
    await (await page.$("#versions"))?.scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(out, "published_version.png") });
    // Its own page: headed by who published it, "Changed from LDraw's model
    // by" its modeller under them; LDraw's model as it is, "Modelled by".
    const credit = async (href) => {
      await page.goto(`${site}${href}`, { waitUntil: "domcontentloaded" });
      return page.evaluate(() => {
        const side = document.querySelector(".model-page .side");
        const who = side?.querySelector(".shared-by .who");
        const line = side?.querySelector(".modelled-by");
        return { who: who?.getAttribute("href") || "", handle: who?.querySelector("small")?.textContent || "",
          avatar: Boolean(who?.querySelector(".avatar")), line: line?.textContent.replace(/\s+/g, " ").trim() || "",
          from: line?.hasAttribute("data-changed-from") === true, ldraw: line?.querySelector("a")?.getAttribute("href") || "",
          modelled: /Modelled by/.test(side?.textContent || "") };
      });
    };
    const own = await credit(`/m/${id}`);
    check(`its own page is headed by who published it (@${handle}, their picture, linking their profile), "Changed from `
      + `LDraw's model by Marc Giraudet" under it linking LDraw's page, and no "Modelled by" (${JSON.stringify(own)})`,
      own.who === `/u/${handle}` && own.handle === `@${handle}` && own.avatar && own.from
      && own.line === "Changed from LDraw's model by Marc Giraudet" && own.ldraw.startsWith("https://library.ldraw.org/") && !own.modelled);
    await page.screenshot({ path: path.join(out, "version_page.png") });
    if (plainVersion) {
      const plain = await credit(plainVersion.href);
      check(`LDraw's model as it is, on its own page: "Modelled by Marc Giraudet for LDraw's Official Model Repository" `
        + `(${JSON.stringify(plain)})`, !plain.from && plain.line === "Modelled by Marc Giraudet for LDraw's Official Model Repository");
    }
  } finally {
    await context.close();
  }
  writeFileSync(path.join(out, "published.json"), `${JSON.stringify({ id, seconds: at / 1000 }, null, 1)}\n`);
}

/// --open-time: ms from the address asked until [ready] holds in a fresh
/// context of [browser]; null when it never did in [most] ms. And the tab's
/// own record of each change in what the app told the page (its state:
/// what it is working on, its status bar, parts down and on their way), by
/// the page's clock from its navigation, so the time between the studio up
/// and the set down can be put where it went.
async function timed(browser, address, ready, most = 240000, label = "", readyArg = null) {
  const context = await browser.newContext({ viewport, isMobile: viewport.width < 600, hasTouch: viewport.width < 600,
    extraHTTPHeaders: headers });
  await context.addInitScript(({ trace, least }) => {
    const log = [];
    window.sethubLog = log;
    // The page's clock at a mark a Chrome trace holds too (--chrome-trace):
    // how the trace's times are read on the page's clock.
    window.sethubZero = performance.mark("sethub-zero").startTime;
    // The page's frames (requestAnimationFrame, the engine's own pace): each
    // gap over 250 ms, [when, how long], to tell the app's work from frames
    // the browser did not give.
    const gaps = [];
    window.sethubGaps = gaps;
    let lastFrame = 0;
    // When what the app told the page was on the screen: the first frame
    // drawn after it (a WebGL draw call), up to a fence put in after that
    // frame, which passes once the browser drawing in software has drawn
    // it (memory brickworks-swiftshader-timing). "up": the studio up;
    // "set": its parts down. {at, drew, seen} by the page's clock.
    const drawn = { last: 0, gl: null };
    for (const name of ["drawElements", "drawArrays", "drawElementsInstanced", "drawArraysInstanced", "drawRangeElements"]) {
      const kind = window.WebGL2RenderingContext;
      const real = kind && kind.prototype[name];
      if (typeof real !== "function") continue;
      kind.prototype[name] = function (...given) {
        drawn.last = performance.now();
        drawn.gl = this;
        return real.apply(this, given);
      };
    }
    const seen = window.sethubSeen = {};
    const look = () => {
      for (const one of Object.values(seen)) {
        if (one.seen) continue;
        if (!one.fence && drawn.gl && drawn.last > one.at) {
          one.drew = Math.round(drawn.last);
          one.gl = drawn.gl;
          one.fence = one.gl.fenceSync(one.gl.SYNC_GPU_COMMANDS_COMPLETE, 0);
          one.gl.flush();
        } else if (one.fence && one.gl.getSyncParameter(one.fence, one.gl.SYNC_STATUS) === one.gl.SIGNALED) {
          one.seen = Math.round(performance.now());
          one.gl.deleteSync(one.fence);
          one.fence = null;
        }
      }
    };
    const frame = (at) => {
      if (lastFrame && at - lastFrame > 250) gaps.push([Math.round(lastFrame), Math.round(at - lastFrame)]);
      lastFrame = at;
      look();
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
    // Every WebGL call timed: their time in all, and each over 50 ms [when,
    // how long, which]. And each of the page's frames (a requestAnimationFrame
    // callback: the engine's frame) over 200 ms [when, how long, of it in
    // WebGL calls]. A gap between frames with no long frame in it is the
    // browser giving none; a long frame mostly in WebGL is the engine
    // waiting on a browser drawing in software.
    const waits = { ms: 0, n: 0, long: [] };
    window.sethubGl = waits;
    // Only with --trace: it costs every WebGL call a little.
    for (const kind of trace ? [window.WebGL2RenderingContext, window.WebGLRenderingContext] : []) {
      if (!kind) continue;
      for (const name of Object.getOwnPropertyNames(kind.prototype)) {
        const held = Object.getOwnPropertyDescriptor(kind.prototype, name);
        if (!held || typeof held.value !== "function" || name === "constructor") continue;
        const real = held.value;
        kind.prototype[name] = function (...given) {
          const at = performance.now();
          try {
            return real.apply(this, given);
          } finally {
            const took = performance.now() - at;
            waits.ms += took;
            waits.n += 1;
            if (took > 50 && waits.long.length < 400) waits.long.push([Math.round(at), Math.round(took), name]);
          }
        };
      }
    }
    const engineFrames = [];
    window.sethubFrames = engineFrames;
    const askFrame = window.requestAnimationFrame.bind(window);
    if (trace) window.requestAnimationFrame = (callback) => askFrame((at) => {
      const began = performance.now();
      const inGl = waits.ms;
      try {
        callback(at);
      } finally {
        const took = performance.now() - began;
        if (took > 200 && engineFrames.length < 400) engineFrames.push([Math.round(began), Math.round(took), Math.round(waits.ms - inGl)]);
      }
    });
    let last = null;
    setInterval(() => {
      const state = window.brickworksState;
      if (!state || state === last) return;
      last = state;
      const row = { t: Math.round(performance.now()), now: state.now, working: JSON.stringify(state.working ?? null),
        said: state.said || "", bricks: state.bricks, awaited: state.awaited, slow: state.slow, busy: state.busy };
      const before = log[log.length - 1];
      if (!before || ["working", "said", "bricks", "awaited"].some((key) => before[key] !== row[key])) log.push(row);
      if (!seen.up && row.awaited === 0) seen.up = { at: row.t, drew: 0, seen: 0, fence: null };
      if (!seen.set && row.bricks >= least && row.awaited === 0) seen.set = { at: row.t, drew: 0, seen: 0, fence: null };
    }, 25);
  }, { trace: Boolean(args.trace), least: wantBricks });
  const page = await context.newPage();
  page.on("pageerror", (error) => errors.push(`${address}: ${error.message}`));
  // --chrome-trace=DIR: the whole browser traced (the page's thread, the
  // GPU process drawing in software), DIR/<label>.json.
  const tracing = chromeTrace && label ? path.join(chromeTrace, `${label}.json`) : "";
  if (tracing) {
    // Few kinds: with cc, viz and the timeline's own, SwiftShader drew a
    // frame in half a second and the studio never came up in 240 s.
    await browser.startTracing(page, { path: tracing, categories: ["toplevel", "devtools.timeline", "blink.user_timing",
      "gpu"] });
  }
  try {
    const began = Date.now();
    await page.goto(`${site}${address}`, { waitUntil: "commit", timeout: 120000 });
    const done = await page.waitForFunction(ready, readyArg, { timeout: most, polling: 100 }).then(() => true, () => false);
    const ms = done ? Date.now() - began : null;
    // And drawn: the plain studio up, the version's set down (sethubSeen).
    const shown = readyArg === null ? "up" : "set";
    if (done) {
      await page.waitForFunction((what) => window.sethubSeen?.[what]?.seen > 0, shown, { timeout: 60000, polling: 100 })
        .catch(() => {});
    }
    await page.waitForTimeout(200);
    const drawnAt = await page.evaluate((what) => {
      const one = window.sethubSeen?.[what];
      return one ? { at: one.at, drew: one.drew, seen: one.seen || null } : null;
    }, shown).catch(() => null);
    const log = await page.evaluate(() => window.sethubLog || []).catch(() => []);
    const at = (test) => log.find(test)?.t ?? null;
    const state = await page.evaluate(() => {
      const one = window.brickworksState || {};
      const shared = window.brickworksShare || {};
      return { title: shared.title, bricks: one.bricks, awaited: one.awaited, steps: shared.steps, phases: one.open_phases,
        threads: window.brickworksEngine?.threads ?? null };
    }).catch(() => ({}));
    // What it fetched, by the same clock: the library's index and file, the API.
    const fetched = await page.evaluate(() => performance.getEntriesByType("resource")
      .filter((one) => /\/library\/|\/api\//.test(one.name))
      .map((one) => `${one.name.replace(/^https?:\/\/[^/]+/, "").slice(0, 60)} ${Math.round(one.startTime)}-${Math.round(one.responseEnd)}`))
      .catch(() => []);
    const slow = await page.evaluate(() => JSON.stringify(window.brickworksState?.slow ?? null)).catch(() => "");
    const gaps = await page.evaluate(() => window.sethubGaps || []).catch(() => []);
    const gl = await page.evaluate(() => window.sethubGl || null).catch(() => null);
    const engineFrames = await page.evaluate(() => window.sethubFrames || []).catch(() => []);
    // When the page wrote the packs that came after the start into the
    // engine's files, a task of its own on the page's thread.
    const packs = await page.evaluate(() => {
      const when = (one) => (one ? [Math.round(one.came), Math.round(one.began), Math.round(one.written), one.files] : null);
      const all = { later: when(window.brickworksLater) };
      for (const [name, one] of Object.entries(window.brickworksPacks || {})) all[name] = when(one);
      return { zero: window.sethubZero ?? null, ...all };
    }).catch(() => ({}));
    if (tracing) await browser.stopTracing().catch(() => {});
    return { ms, first: at(() => true), up: at((row) => row.awaited === 0), placed: at((row) => row.bricks >= wantBricks),
      whole: at((row) => row.bricks >= wantBricks && row.awaited === 0), log, fetched, slow, gaps, gl, engineFrames, packs, state,
      drawnAt, seen: drawnAt?.seen ?? null, page, context };
  } catch (trouble) {
    if (tracing) await browser.stopTracing().catch(() => {});
    await context.close();
    return { ms: null, log: [], state: { trouble: String(trouble.message || trouble).slice(0, 200) } };
  }
}

async function openTime(rounds) {
  const up = () => Boolean(window.brickworksState) && window.brickworksState.awaited === 0;
  // Its parts all down (an app before brickworksState.title says no name).
  const set = (least) => window.brickworksState?.bricks >= least && window.brickworksState.awaited === 0;
  // Signed in as this run's own throwaway account, deleted at the end.
  const browsers = [await launch({ ownAccount: true }), await launch({ ownAccount: true })];
  const got = [];
  try {
    for (let round = 0; round <= rounds; round += 1) {
      const [plainOne, version] = await Promise.all([timed(browsers[round % 2], "/app?new=1", up, 240000, `plain${round}`),
        timed(browsers[(round + 1) % 2], openAt, set, 240000, `version${round}`, wantBricks)]);
      if (round === rounds) await version.page?.screenshot({ path: path.join(out, "make_your_own_version_app.png") });
      await Promise.all([plainOne.context?.close(), version.context?.close()]);
      console.log(`  round ${round}${round ? "" : " (warming, not counted)"}: the studio up at ${plainOne.up} ms `
        + `(its page's clock; ${plainOne.ms} ms by the flow's); Make your own version's app first told the page at `
        + `${version.first} ms, its set down at ${version.placed} ms, whole at ${version.whole} ms (${version.ms} by the flow's) `
        + `(${JSON.stringify(version.state)})`);
      // Where the version's time went, from its app's first word to the set whole.
      for (const row of version.log.filter((one) => one.t <= (version.whole ?? Infinity))) {
        console.log(`    ${String(row.t).padStart(6)} ms  engine ${row.now}  slow ${row.slow} busy ${row.busy}  `
          + `bricks ${row.bricks} awaited ${row.awaited}  working ${row.working}  said "${row.said}"`);
      }
      console.log(`    its fetches: ${version.fetched?.join("; ")}`);
      console.log(`    the packs after the start, [came, writing began, written, files] by its page's clock: `
        + `${JSON.stringify(version.packs)}; the plain studio's: ${JSON.stringify(plainOne.packs)}`);
      console.log(`    the plain studio's slow frames: ${plainOne.slow}`);
      const within = (one) => (version.gaps || []).filter(([at]) => at >= (one ?? 0) - 1000 && at <= (version.whole ?? Infinity));
      const stalled = within(version.first);
      console.log(`    the version's page frames over 250 ms apart from its app's first word to the set whole: `
        + `${stalled.length}, ${stalled.reduce((sum, [, ms]) => sum + ms, 0)} ms in all: ${JSON.stringify(stalled)}`);
      const waited = (version.gl?.long || []).filter(([at]) => at >= (version.first ?? 0) - 1000 && at <= (version.whole ?? Infinity));
      console.log(`    the version's WebGL waits over 50 ms in that time: ${waited.length}, `
        + `${waited.reduce((sum, [, ms]) => sum + ms, 0)} ms in all (${Math.round(version.gl?.ms || 0)} ms in ${version.gl?.n || 0} `
        + `calls over the whole page): ${JSON.stringify(waited.slice(0, 40))}`);
      const long = (version.engineFrames || []).filter(([at]) => at >= (version.first ?? 0) - 1000 && at <= (version.whole ?? Infinity));
      console.log(`    the version's engine frames over 200 ms in that time: ${long.length}, `
        + `${long.reduce((sum, [, ms]) => sum + ms, 0)} ms in all, ${long.reduce((sum, [, , gl]) => sum + gl, 0)} ms of it in WebGL: `
        + `${JSON.stringify(long.slice(0, 40))}`);
      const plainWaited = (plainOne.gl?.long || []).filter(([at]) => at <= (plainOne.up ?? Infinity));
      console.log(`    the plain studio's WebGL waits over 50 ms before it was up: ${plainWaited.length}, `
        + `${plainWaited.reduce((sum, [, ms]) => sum + ms, 0)} ms in all`);
      console.log(`    drawn and on the screen (the first frame drawn after it, fenced): the plain studio up `
        + `${JSON.stringify(plainOne.drawnAt)}, the version's set down ${JSON.stringify(version.drawnAt)}; `
        + `${version.seen !== null && plainOne.seen !== null ? version.seen - plainOne.seen : null} ms apart`);
      if (round) {
        got.push({ plain: plainOne.up, placed: version.placed, version: version.whole, plainSeen: plainOne.seen,
          versionSeen: version.seen, log: version.log });
      }
    }
    // Build it's address: its timeline at step 1, with an app that takes --build.
    const built = await timed(browsers[0], "/app?new=1&library=omr-346-2&build",
      () => Array.isArray(window.brickworksShare?.steps) && window.brickworksShare.steps.length === 2, 240000);
    await built.page?.screenshot({ path: path.join(out, "build_it_app.png") });
    const timeline = await built.page?.evaluate(() => window.brickworksShare?.steps || null).catch(() => null);
    await built.context?.close();
    console.log(`  Build it: ${built.ms === null ? "no timeline in 240 s" : `its timeline up in ${built.ms} ms`} `
      + `(${JSON.stringify({ ...built.state, phases: undefined })}; at step ${JSON.stringify(timeline)})`);
    writeFileSync(path.join(out, "open_time.json"), `${JSON.stringify({ rounds: got, build: built.ms }, null, 1)}\n`);
  } finally {
    await Promise.all(browsers.map((one) => one.close()));
  }
  const median = (list) => {
    const sorted = list.filter((one) => one !== null).sort((a, b) => a - b);
    return sorted.length ? sorted[(sorted.length - 1) >> 1] : null;
  };
  const plainMs = median(got.map((one) => one.plain));
  const placedMs = median(got.map((one) => one.placed));
  const versionMs = median(got.map((one) => one.version));
  // Each round's two at the same moment: the difference a round, its median.
  const over = median(got.map((one) => (one.placed !== null && one.plain !== null ? one.placed - one.plain : null)));
  console.log(`  every part's shape in ${versionMs} ms at the median; ${median(got.map((one) => (one.version !== null
    && one.plain !== null ? one.version - one.plain : null)))} ms after the studio, a round's median`);
  const seenOver = median(got.map((one) => (one.versionSeen !== null && one.plainSeen !== null
    ? one.versionSeen - one.plainSeen : null)));
  console.log(`  drawn: the set on the screen ${seenOver} ms after the plain studio was, a round's median `
    + `(${JSON.stringify(got.map((one) => (one.versionSeen !== null && one.plainSeen !== null ? one.versionSeen - one.plainSeen : null)))})`);
  check(`Make your own version puts the set on the baseplate in ${placedMs} ms, the studio up in ${plainMs} ms `
    + `(medians of ${got.length}; ${over} ms later, a round's median): within the studio's open time + 2 s`,
  got.every((one) => one.placed !== null && one.plain !== null) && over !== null && over <= 2000);
}

const browser = await launch({ signedOut: true });
try {
  if (!args["open-time"] || args.pages) {
    await modelled(browser);
    await plain(browser);
    await languages(browser);
  }
  if (args.publish) await published(browser);
  if (args["open-time"]) await openTime(Number(args["open-time"]) > 0 ? Number(args["open-time"]) : 3);
} finally {
  await browser.close();
  if (args.publish) await endOwnAccount();
}
check(`no script error on any page (${errors.length}${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""})`, !errors.length);
console.log(failed ? `sethub_flow: ${failed} FAIL` : "sethub_flow: all passed");
process.exit(failed ? 1 : 0);
