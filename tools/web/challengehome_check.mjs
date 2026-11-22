// The challenge on the home page, and the challenge page as it loads
// (challengehonours, docs/SOCIAL.md the units in waves, rank 3), in real
// browsers, signed out:
//
//   node --env-file=.env tools/web/relay_server.mjs 10940
//   node --env-file=.env tools/web/challengehome_check.mjs --url=http://127.0.0.1:10940 --out=DIR [--admin]
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/challengehome_check.mjs --url=<preview> --out=DIR
//
// 1. The home page at 390 (a phone) and 1280, light and dark: while a
//    challenge is open, #challenge names it with its days left, and the
//    shelf's first card is This week's pick, marked so, its picture drawn
//    (landing, 2026-11-22: the pick leads the first tab, #shelf), both
//    whole within the first two screens (their foot at most twice the
//    window's height down), moving no more than 0.1 as they come; nothing
//    sideways.
// 2. /challenge at 390, 768 and 1280, light and dark: it moves no more
//    than 0.1 as it loads (the layout shifts no press made, summed as
//    Chrome's CLS sums them, read 3 s after it is drawn).
// 3. /challenge's head names /challenge.png as its picture, and
//    /challenge.png answers with the picture of the challenge shown now: a
//    model's (its cover, a winner or an entry) whenever it has one with a
//    picture, the site's own only when it has none.
// --admin: also the panel of the checks' own test challenge shown now
//    (/admin?tests=1#challenges/N, MASTER_EMAIL as the console flows sign
//    in), at 390, 768 and 1280, light and dark, with How it runs on it.
//
// Read only: nothing is entered, voted for or set. Pictures in --out.
import { launch } from "./browser.mjs";
import { mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:10940").replace(/\/+$/, "");
const out = path.resolve(String(args.out || "shots/challengehome"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const browser = await launch({ signedOut: true });

async function page({ width, height, phone = false, dark = false, as = null }) {
  const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await context.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  // Every layout shift no press made, as Chrome's CLS counts them: the
  // largest burst (shifts under 1 s apart, at most 5 s long).
  await context.addInitScript(() => {
    const shifts = [];
    window.__shifts = shifts;
    try {
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) shifts.push({ at: entry.startTime, value: entry.value,
            from: (entry.sources || []).map((s) => s.node?.id || s.node?.className || s.node?.nodeName || "?").join(" ") });
        }
      }).observe({ type: "layout-shift", buffered: true });
    } catch {}
  });
  const made = await context.newPage();
  const label = `${width}${dark ? " dark" : ""}`;
  made.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  made.on("console", (m) => {
    if (/Content Security Policy|Refused to/.test(m.text())) errors.push(`${label}: ${m.text().slice(0, 200)}`);
  });
  return { context, page: made };
}

const cls = (p) => p.evaluate(() => {
  let best = 0;
  let burst = 0;
  let first = 0;
  let last = -Infinity;
  for (const s of window.__shifts || []) {
    if (s.at - last > 1000 || s.at - first > 5000) {
      burst = 0;
      first = s.at;
    }
    burst += s.value;
    last = s.at;
    best = Math.max(best, burst);
  }
  return { cls: Math.round(best * 1000) / 1000, shifts: (window.__shifts || []).map((s) => `${s.value.toFixed(3)}@${Math.round(s.at)} ${s.from}`) };
});
const sideways = (p) => p.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
async function until(p, test, what, seconds = 30) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await p.evaluate(test).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await p.waitForTimeout(250);
  }
}

try {
  console.log(`against ${site}`);
  const hub = await (await fetch(`${site}/api/people?op=challenge`, { headers })).json().catch(() => ({}));
  const open = hub?.challenge?.state === "open" && !hub.challenge.test ? hub.challenge : null;
  // This week's pick, as the gallery's front has it: the home page's shelf leads with it.
  const front = await (await fetch(`${site}/api/share?op=shelves`, { headers })).json().catch(() => ({}));
  const pick = front?.pick?.model && (front.pick.model.thumb || front.pick.model.image) ? front.pick.model.id : "";
  console.log(`  --    the challenge shown: ${hub?.challenge ? `"${hub.challenge.title}", ${hub.challenge.state}` : "none"}`);

  // --- 1. The home page --------------------------------------------------
  for (const [width, height, phone] of [[390, 844, true], [1280, 900, false]]) {
    for (const dark of [false, true]) {
      const { context, page: p } = await page({ width, height, phone, dark });
      await p.goto(`${site}/`, { waitUntil: "load", timeout: 60000 });
      await until(p, () => document.documentElement.dataset.challenge && document.documentElement.dataset.shelfLive, "the home page's challenge and shelf");
      const seen = await p.evaluate(() => {
        const box = (el) => {
          const r = el?.getBoundingClientRect();
          return r ? { top: Math.round(r.top + scrollY), bottom: Math.round(r.bottom + scrollY) } : null;
        };
        const card = document.querySelector("#shelf [role=tabpanel]:not([hidden]) > .model[data-pick]");
        const img = card?.querySelector("img");
        return { said: document.documentElement.dataset.challenge, pick: card ? "shown" : "none",
          name: document.getElementById("challenge-h")?.textContent.trim() || "",
          left: document.getElementById("challenge-left")?.hidden ? "" : document.getElementById("challenge-left")?.textContent.trim() || "",
          pickName: card?.querySelector("a.open b")?.textContent.trim() || "",
          pictured: Boolean(img && img.complete && img.naturalWidth > 0),
          challenge: box(document.getElementById("challenge")), pickBox: box(card), screen: innerHeight };
      });
      const twoScreens = 2 * seen.screen;
      await p.waitForTimeout(1000);
      const moved = await cls(p);
      check(`home at ${width}${dark ? " dark" : ""} moves ${moved.cls} as the challenge and the pick come${moved.shifts.length ? ` (${moved.shifts.join("; ")})` : ""}`,
        moved.cls <= 0.1);
      check(`home at ${width}${dark ? " dark" : ""}: "${seen.name}" (${seen.said}, "${seen.left}") ends at ${seen.challenge?.bottom} px; `
        + `the pick "${seen.pickName}" (${seen.pick}${seen.pictured ? ", its picture" : ""}) ends at ${seen.pickBox?.bottom} px; two screens ${twoScreens}`,
        Boolean(seen.challenge) && seen.challenge.bottom <= twoScreens && (!pick || (seen.pickBox && seen.pickBox.bottom <= twoScreens))
        && (!open || (seen.said === "open" && seen.name === open.title && /days? left|Last day|Entries close|judges|Fan vote/i.test(seen.left)))
        && (!pick || (seen.pick === "shown" && seen.pictured)));
      check(`...nothing sideways at ${width}`, !(await sideways(p)));
      await p.screenshot({ path: path.join(out, `home-${width}${dark ? "-dark" : ""}.png`), clip: { x: 0, y: 0, width, height: twoScreens },
        fullPage: true, timeout: 90000 }).catch(() => null);
      await context.close();
    }
  }

  // --- 2. /challenge as it loads -------------------------------------------
  for (const [width, height, phone] of [[390, 844, true], [768, 1024, false], [1280, 900, false]]) {
    for (const dark of [false, true]) {
      const { context, page: p } = await page({ width, height, phone, dark });
      await p.goto(`${site}/challenge`, { waitUntil: "load", timeout: 60000 });
      await until(p, () => document.documentElement.dataset.challenge, "the challenge drawn");
      await p.waitForTimeout(3000);
      const moved = await cls(p);
      check(`/challenge at ${width}${dark ? " dark" : ""} moves ${moved.cls} as it loads${moved.shifts.length ? ` (${moved.shifts.join("; ")})` : ""}`,
        moved.cls <= 0.1);
      check(`...nothing sideways at ${width}`, !(await sideways(p)));
      await p.screenshot({ path: path.join(out, `challenge-${width}${dark ? "-dark" : ""}.png`), fullPage: true, timeout: 90000 }).catch(() => null);
      await context.close();
    }
  }

  // --- 3. Its own picture --------------------------------------------------
  const html = await (await fetch(`${site}/challenge`, { headers })).text();
  const tag = (name) => (html.match(new RegExp(`<meta (?:name|property)="${name}" content="([^"]*)">`)) || [])[1] || "";
  const pictured = await fetch(`${site}/challenge.png`, { headers, redirect: "manual" });
  const to = pictured.headers.get("location") || "";
  const shown = hub?.challenge || null;
  const entries = (shown?.groups || []).flatMap((g) => g.entries || []);
  const hasPicture = entries.some((one) => one.image);
  const fetched = to ? await fetch(to.startsWith("http") ? to : `${site}${to}`, { headers }) : null;
  check(`/challenge's head: og:image ${tag("og:image")}, twitter:image ${tag("twitter:image")}; /challenge.png ${pictured.status} to `
    + `${to.replace(site, "")} (${fetched?.status} ${fetched?.headers.get("content-type")})`,
    /\/challenge\.png$/.test(tag("og:image")) && tag("twitter:image") === tag("og:image") && pictured.status === 302
    && /\/(?:m\/[A-Za-z0-9]{10}\.png|share\.png)$/.test(to) && (!hasPicture || /\/m\/[A-Za-z0-9]{10}\.png$/.test(to))
    && fetched?.status === 200 && /^image\//.test(fetched.headers.get("content-type") || ""));

  // --- The owner's panel -----------------------------------------------------
  const tested = args.admin ? (await (await fetch(`${site}/api/people?op=challenge&tests=1`, { headers })).json().catch(() => ({})))?.challenge : null;
  if (args.admin && (!tested?.id || tested.state === "ended")) {
    console.log(`  --    the panel: no test challenge open or to come${tested?.title ? ` ("${tested.title}" has ended)` : ""}, and How it runs is set only before it ends`);
  } else if (args.admin) {
    const master = await mintSession(process.env.MASTER_EMAIL);
    for (const [width, height, phone] of [[390, 844, true], [768, 1024, false], [1280, 900, false]]) {
      for (const dark of [false, true]) {
        const { context, page: p } = await page({ width, height, phone, dark, as: master });
        await p.goto(`${site}/admin?tests=1#challenges/${tested.id}`, { waitUntil: "load", timeout: 60000 });
        const ready = await until(p, () => document.querySelector("#sheet[open] .rounds-part"), "the challenge's panel", 60).then(() => true, () => false);
        check(`the owner's panel at ${width}${dark ? " dark" : ""}: How it runs ${ready ? "on it" : "missing"}`, ready && !(await sideways(p)));
        await p.evaluate(() => document.querySelector(".rounds-part")?.scrollIntoView({ block: "start" }));
        await p.screenshot({ path: path.join(out, `admin-rounds-${width}${dark ? "-dark" : ""}.png`), timeout: 90000 }).catch(() => null);
        await context.close();
      }
    }
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await browser.close();
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED, ${passed} ok` : `challengehome: the challenge and the pick on the home page, the challenge page still as it loads (${passed} checks, all ok)`);
process.exit(failed ? 1 : 0);
