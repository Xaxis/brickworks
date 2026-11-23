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
//     [--widths=1280,390] [--themes=light,dark] [--versions=FILE]
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
    cards: [...(versions?.querySelectorAll(".model") || [])].map((card) => ({
      href: card.querySelector("a")?.getAttribute("href") || "", said: said(card.querySelector(".version-said")),
      changed: card.querySelector(".version-said")?.dataset.changed || "" })),
    empty: said(versions?.querySelector(".built-empty p")),
    emptyGo: versions?.querySelector("[data-version-empty]")?.getAttribute("href") || null,
    before: Boolean(versions && built && versions.compareDocumentPosition(built) & Node.DOCUMENT_POSITION_FOLLOWING),
    picture: rect ? [Math.round(rect.top), Math.round(rect.height)] : null,
  };
};

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
            check(`${label}: each version's card says whether it was changed (${JSON.stringify(seen.cards)})`,
              seen.cards.length === Number(seen.count) && seen.cards.every((card) => /^\/m\/[A-Za-z0-9]{10}$/.test(card.href)
                && (card.changed === "true" ? card.said === "Their own version: changed from LDraw's model"
                  : card.said === "LDraw's model, as it is")));
          } else {
            check(`${label}: none yet, said, with Make your own version (${seen.empty}, ${seen.emptyGo})`,
              seen.empty === "Nobody has published their own version of this set yet." && seen.emptyGo === seen.version);
          }
          check(`${label}: nothing on the first screen moved for them (picture ${JSON.stringify(first.picture)} then `
            + `${JSON.stringify(seen.picture)})`, JSON.stringify(first.picture) === JSON.stringify(seen.picture));
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
  const house = readFileSync(new URL("../../tests/fixtures/omr_credit/346-2.published.ldr", import.meta.url), "utf8");
  const lines = house.split("\n");
  const parts = lines.map((line, at) => (/^1 .*\.dat\s*$/i.test(line) ? at : -1)).filter((at) => at >= 0);
  const cut = new Set(parts.slice(0, Math.floor(parts.length / 10)));
  const began = Date.now();
  const reply = await fetch(`${site}/api/share`, { method: "POST", headers: { ...headers, "content-type": "application/json",
    authorization: `Bearer ${token}` }, body: JSON.stringify({ name: "Sethub House with Car, my version",
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
    const row = await page.$("#versions");
    if (row) {
      await row.scrollIntoViewIfNeeded();
      await page.screenshot({ path: path.join(out, "published_version.png") });
    }
  } finally {
    await context.close();
  }
  writeFileSync(path.join(out, "published.json"), `${JSON.stringify({ id, seconds: at / 1000 }, null, 1)}\n`);
}

const browser = await launch({ signedOut: true });
try {
  await modelled(browser);
  await plain(browser);
  await languages(browser);
  if (args.publish) await published(browser);
} finally {
  await browser.close();
  if (args.publish) await endOwnAccount();
}
check(`no script error on any page (${errors.length}${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""})`, !errors.length);
console.log(failed ? `sethub_flow: ${failed} FAIL` : "sethub_flow: all passed");
process.exit(failed ? 1 : 0);
