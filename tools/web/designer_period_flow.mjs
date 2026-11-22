// A designer's numbers against last month (insights2, 2026-11-22;
// supabase/designer_period.sql, api/_designers.js, web/designs.js), on a
// deployment through its API alone, and in real browsers:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/designer_period_flow.mjs --url=<preview> --out=DIR
//
//   1. Ada (a throwaway at a Resend test address) has 50 published test
//      models, shared 70 days ago, by link. Rows are written straight into
//      the project with the secret key, dated by hand: views (model_views,
//      which the trigger counts into model_opens by the day), builds, likes,
//      saves (Saved and lists), comments and remixes, by Bob and Cy (two more
//      throwaways) and by Ada herself (never counted), some at the edges: the
//      last 30 days' first instant, a second before it, the 30 before's
//      first instant and a second before that.
//   2. The bar: ?op=designs as Ada answers within 1 s, the middle and the
//      slowest of ten (after one to wake the function, which is said too).
//   3. Numbers right: every model's six kinds, the last 30 days, the 30
//      before, the 8 weeks and in all (3,300 numbers), each against a count
//      of the same rows read straight back from the tables here, over the
//      same UTC days (today and the 29 before; the 30 before those; weeks of
//      7 days, the newest ending today).
//   4. Insights (/profile?tab=insights) at 1280, 768 and 390 px, light and
//      dark: six tiles, each the API's total; the chart's 8 weeks and its
//      table the same numbers; sorted by the change, the most gained first;
//      another kind redraws the chart and the lines; the chart's keys; no
//      sideways scroll; and in German. Her own /u/ page the same.
//   5. Only Ada sees them: Bob asked plainly gets his own models, by her
//      handle {mine: false}; signed out 401; every answer private, no-store;
//      her /u/ page shows Bob and a visitor none of it.
//   6. The accounts deleted, their models and rows with them.
//
// Before supabase/designer_period.sql is applied the API sends no period:
// the page is drawn as before, and this says so and ends "(before the file)".
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("designer_period_flow: --url=<deployment>");
  process.exit(2);
}
if (/(^|\.)brickworks\.diy$/.test(new URL(site).hostname)) {
  console.error("designer_period_flow: never on brickworks.diy; give a preview");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/designer_period"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const REST = `${String(process.env.SUPABASE_URL || "").replace(/\/+$/, "")}/rest/v1`;
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SECRET) {
  console.error("designer_period_flow: no SUPABASE_SECRET_KEY: run with --env-file=.env");
  process.exit(2);
}
const rand = randomBytes(4).toString("hex");
const r6 = rand.slice(0, 6);
const email = (who) => `delivered+bw-period-${who}-${rand}@resend.dev`;
const ADA = `bwp-ada-${rand}`;
const KINDS = ["views", "builds", "likes", "saves", "comments", "remixes"];
const DAY = 86400000;
const MODELS = 50;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];

/// The project's tables, with the secret key: rows as JSON.
async function rest(pathname, { method = "GET", body, prefer = "" } = {}) {
  const reply = await fetch(`${REST}/${pathname}`, { method, headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`,
    ...(body === undefined ? {} : { "content-type": "application/json" }), ...(prefer ? { prefer } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  if (!reply.ok) throw new Error(`${method} ${pathname.split("?")[0]}: ${reply.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}
/// Every row [pathname] names, a thousand at a time.
async function restAll(pathname) {
  const all = [];
  for (let from = 0; ; from += 1000) {
    const page = await rest(`${pathname}&limit=1000&offset=${from}`);
    all.push(...page);
    if (page.length < 1000) return all;
  }
}
const insert = (table, rows) => rest(table, { method: "POST", body: rows, prefer: "return=minimal" });

/// One request to the deployment's API: {status, body, headers, ms}.
async function api(pathname, { token, again = true } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  const began = performance.now();
  const reply = await fetch(`${site}${pathname}`, { headers: sent });
  const body = await reply.json().catch(() => ({}));
  const said = { status: reply.status, headers: reply.headers, body, ms: performance.now() - began };
  if (said.status === 503 && again && /sign-in service/.test(String(body.error || ""))) {
    await new Promise((done) => setTimeout(done, 1500));
    return api(pathname, { token, again: false });
  }
  return said;
}

const hex = (words) => createHash("md5").update(words).digest("hex");
const id = (lead, n) => `${lead}${r6}${String(n).padStart(2, "0")}`;
const utcDay = (time) => new Date(time).toISOString().slice(0, 10);
const midnight = (day) => Date.parse(`${day}T00:00:00Z`);
const plusDays = (day, n) => utcDay(midnight(day) + n * DAY);

// --- The days: one rule, everywhere ------------------------------------------
// Today is the UTC day; the last 30 days today and the 29 before; the 30
// before the 30 before those; week w (0 the oldest) from today - 55 + 7w.
function windowsOf(today) {
  return { now: [plusDays(today, -29), today], before: [plusDays(today, -59), plusDays(today, -30)],
    weeks: Array.from({ length: 8 }, (_, w) => [plusDays(today, -55 + 7 * w), plusDays(today, -49 + 7 * w)]) };
}
/// [events] ({day, n}) added up on the days [from] to [til].
const within = (events, [from, til]) => events.reduce((sum, e) => sum + (e.day >= from && e.day <= til ? e.n : 0), 0);

const browser = await launch({ signedOut: true });
async function context({ as = null, width = 1280, height = 900, phone = false, dark = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, colorScheme: dark ? "dark" : "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
async function until(page, test, what, seconds = 45, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}
// A phone's whole page drawn as one picture loses its touch controls
// (fullpage-shot-drops-touch): the screen as it is, then the chart's.
const shot = (page, name, full) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

/// What Insights drew in [box]: the tiles, the chart, the rows.
const drawn = (page, box) => page.evaluate((boxId) => {
  const panel = document.getElementById(boxId);
  const counts = (el) => ({ now: Number(el.dataset.now), before: Number(el.dataset.before), ever: Number(el.dataset.ever),
    change: el.dataset.change, shown: el.querySelector("b")?.textContent || "", said: el.querySelector(".change")?.textContent || "" });
  const figure = panel?.querySelector(".period-chart");
  return {
    shown: Boolean(panel && !panel.hidden), state: document.documentElement.dataset.designs || "",
    period: document.documentElement.dataset.period || "",
    days: panel?.querySelector(".period-days")?.textContent || "",
    tiles: Object.fromEntries([...(panel?.querySelectorAll(".mine-totals li[data-earned]") || [])].map((li) => [li.dataset.earned, counts(li)])),
    chart: figure ? { kind: figure.dataset.kind, caption: figure.querySelector("figcaption")?.textContent || "",
      bars: figure.querySelectorAll(".hit").length,
      table: [...figure.querySelectorAll("tbody tr")].map((tr) => [...tr.cells].map((td) => td.textContent)) } : null,
    selects: [...(panel?.querySelectorAll(".period-controls select") || [])].map((s) => ({ id: s.id, value: s.value,
      label: s.closest("label")?.firstChild?.textContent || "", height: s.getBoundingClientRect().height })),
    means: panel?.querySelector("details.period-what dl")?.querySelectorAll("dt").length || 0,
    rows: [...(panel?.querySelectorAll(".design-row") || [])].map((li) => ({ id: li.dataset.id,
      kinds: Object.fromEntries([...li.querySelectorAll("dd[data-kind]")].map((dd) => [dd.dataset.kind, counts(dd)])),
      weeks: li.querySelector(".design-weeks")?.dataset.weeks || "", weeksKind: li.querySelector(".design-weeks")?.dataset.kind || "",
      weeksSaid: li.querySelector(".design-weeks svg")?.getAttribute("aria-label") || "" })),
  };
}, box);

let ada = null;
let bob = null;
let cy = null;
// No period in the answer: the file is not applied there yet.
let before = false;
const models = Array.from({ length: MODELS }, (_, n) => id("Pd", n));
try {
  console.log(`against ${site}`);
  // --- 1. Ada's models, and what came of them --------------------------------
  console.log("Ada's 50 models, and what Bob, Cy and Ada did with them, dated by hand");
  [ada, bob, cy] = [await mintSession(email("ada")), await mintSession(email("bob")), await mintSession(email("cy"))];
  const [adaId, bobId, cyId] = [ada.kept.user_id, bob.kept.user_id, cy.kept.user_id];
  await insert("people", [{ account: adaId, handle: ADA, name: "Ada Period" }]);
  const now = Date.now();
  const today = utcDay(now);
  const iso = (time) => new Date(time).toISOString();
  const shared = now - 70 * DAY;
  await insert("shared_models", models.map((model, n) => ({ id: model, owner: adaId, name: `Period ${n + 1} ${rand}`, author: "Ada Period",
    parts: 3, bytes: 100, listed: false, test: true, published: true, created_at: iso(shared), updated_at: iso(shared) })));
  // Bob's remixes: of the first ten days ago, of the first unpublished (not counted), of the second 45 days ago.
  const remixes = [[id("Rx", 0), 0, now - 10 * DAY, true], [id("Rx", 1), 0, now - 3 * DAY, false], [id("Rx", 2), 1, now - 45 * DAY, true]];
  await insert("shared_models", remixes.map(([model, of, at, published]) => ({ id: model, owner: bobId, name: `Period remix ${rand}`,
    author: "Bob Period", parts: 3, bytes: 100, listed: false, test: true, published, created_at: iso(at), updated_at: iso(at),
    remixed_from: models[of] })));
  await insert("share_versions", [...models.map((model) => ({ model, n: 1, at: iso(shared), parts: 3, bytes: 100 })),
    ...remixes.map(([model, , at]) => ({ model, n: 1, at: iso(at), parts: 3, bytes: 100 }))]);
  // Views: on the first 20 models, 66 days of visitors (some days none),
  // each a row of model_views; the trigger counts them into model_opens.
  const views = [];
  for (let n = 0; n < 20; n++) {
    for (let d = 0; d <= 65; d++) {
      for (let k = 0; k < (n * 7 + d * 3) % 4; k++) views.push({ model: models[n], day: plusDays(today, -d), visitor: hex(`${rand} ${n} ${d} ${k}`) });
    }
  }
  for (let at = 0; at < views.length; at += 1000) await insert("model_views", views.slice(at, at + 1000));
  // Builds: 300 devices over 62 days, and four at the edges on the first.
  const edgeNow = midnight(plusDays(today, -29));
  const edgeBefore = midnight(plusDays(today, -59));
  const builds = Array.from({ length: 300 }, (_, k) => ({ model: models[k % MODELS], device: hex(`${rand} build ${k}`),
    at: iso(now - ((k * 5) % 1490) * 3600000) }));
  builds.push(...[edgeNow, edgeNow - 1000, edgeBefore, edgeBefore - 1000].map((at, k) => ({ model: models[0], device: hex(`${rand} edge ${k}`), at: iso(at) })));
  await insert("model_builds", builds);
  // Likes: Bob's n days ago, Cy's 3n mod 70 days ago, Cy's on the second at
  // the last 30 days' first instant and Bob's on the third a second before
  // it; Ada's own on the first (not counted).
  const likes = [];
  for (let n = 0; n < MODELS; n++) {
    likes.push({ model: models[n], account: bobId, at: iso(n === 2 ? edgeNow - 1000 : now - (n + 1) * DAY) });
    likes.push({ model: models[n], account: cyId, at: iso(n === 1 ? edgeNow : now - ((n * 3) % 70) * DAY - n * 3600000) });
  }
  likes.push({ model: models[0], account: adaId, at: iso(now) });
  await insert("model_likes", likes);
  // Saves: Bob keeps the first 20 in Saved (2n days ago); his list holds the
  // first a day ago (once: his Saved is older) and the 30th five days ago;
  // Cy's list holds the first 40 days ago and the second now; Ada's own
  // Saved and list are never counted.
  await insert("model_favourites", [...Array.from({ length: 20 }, (_, n) => ({ model: models[n], account: bobId, at: iso(now - 2 * (n + 1) * DAY) })),
    { model: models[1], account: adaId, at: iso(now) }]);
  const lists = [[id("Ls", 0), bobId], [id("Ls", 1), cyId], [id("Ls", 2), adaId]];
  await insert("model_collections", lists.map(([list, owner]) => ({ id: list, owner, name: `Period keeps ${rand}` })));
  await insert("model_collection_items", [{ collection: lists[0][0], model: models[0], at: iso(now - DAY) },
    { collection: lists[0][0], model: models[29], at: iso(now - 5 * DAY) }, { collection: lists[1][0], model: models[0], at: iso(now - 40 * DAY) },
    { collection: lists[1][0], model: models[1], at: iso(now) }, { collection: lists[2][0], model: models[0], at: iso(now) }]);
  // Comments: Bob's on the first 30 (2n days ago); Ada's own; Cy's hidden and Cy's removed (none counted).
  await insert("model_comments", [...Array.from({ length: 30 }, (_, n) => ({ model: models[n], version: 1, author: bobId,
    body: `Period flow ${rand} ${n}`, at: iso(now - 2 * (n + 1) * DAY) })),
  { model: models[0], version: 1, author: adaId, body: `Period flow ${rand}: thank you`, at: iso(now - DAY) },
  { model: models[2], version: 1, author: cyId, body: `Period flow ${rand}: hidden`, at: iso(now - 3 * DAY) },
  { model: models[3], version: 1, author: cyId, body: `Period flow ${rand}: removed`, at: iso(now - 4 * DAY) }]);
  await rest(`model_comments?body=eq.${encodeURIComponent(`Period flow ${rand}: hidden`)}`, { method: "PATCH", body: { hidden_at: iso(now) } });
  await rest(`model_comments?body=eq.${encodeURIComponent(`Period flow ${rand}: removed`)}`, { method: "PATCH",
    body: { removed_at: iso(now), removed_by: "author" } });
  // In all: model_stats' views and builds, as count_view and count_build keep them.
  const byModel = (rows) => rows.reduce((map, row) => map.set(row.model, (map.get(row.model) || 0) + 1), new Map());
  const viewsOf = byModel(views);
  const buildsOf = byModel(builds);
  await rest("model_stats?on_conflict=model", { method: "POST", prefer: "resolution=merge-duplicates,return=minimal",
    body: models.map((model) => ({ model, views: (viewsOf.get(model) || 0) + 9, builds: buildsOf.get(model) || 0 })) });
  check(`made: 50 models, ${views.length} views, ${builds.length} builds, ${likes.length} likes, saves, 33 comments, 3 remixes`, true);

  // --- 2. The bar: within 1 s for 50 models ----------------------------------
  console.log("the bar: ?op=designs as Ada, 50 models");
  const first = await api("/api/people?op=designs", { token: ada.access_token });
  const times = [];
  let mine = first;
  for (let k = 0; k < 10; k++) {
    mine = await api("/api/people?op=designs", { token: ada.access_token });
    times.push(mine.ms);
  }
  const sorted = times.slice().sort((a, b) => a - b);
  const p50 = (sorted[4] + sorted[5]) / 2;
  before = mine.body.period === null || mine.body.period === undefined;
  if (before) console.log("  --    no period in the answer: supabase/designer_period.sql is not applied here");
  check(`${mine.body.models?.length} models; ten answers p50 ${Math.round(p50)} ms, the slowest ${Math.round(sorted[9])} ms `
    + `(the first, waking it, ${Math.round(first.ms)} ms), each within 1 s`, mine.status === 200 && mine.body.models?.length === MODELS
    && sorted[9] < 1000);

  // --- 3. Numbers right ------------------------------------------------------
  if (!before) {
    console.log("numbers right: each against the rows read straight back");
    const period = mine.body.period;
    const win = windowsOf(period.today);
    check(`the days, UTC: today ${period.today} (here ${today}), the last 30 from ${period.now_from}, the 30 before from `
      + `${period.before_from}, the weeks from ${period.weeks_from}`, period.today === today && period.now_from === win.now[0]
      && period.before_from === win.before[0] && period.weeks_from === win.weeks[0][0]);
    const inList = `in.(${models.join(",")})`;
    const owners = new Map(lists.map(([list, owner]) => [list, owner]));
    const [opened, built, liked, kept, held, said, remixed, stats, versions] = await Promise.all([
      restAll(`model_views?model=${inList}&select=model,day&order=model,day,visitor`),
      restAll(`model_builds?model=${inList}&select=model,at&order=model,device`),
      restAll(`model_likes?model=${inList}&select=model,account,at&order=model,account`),
      restAll(`model_favourites?model=${inList}&select=model,account,at&order=model,account`),
      restAll(`model_collection_items?model=${inList}&select=model,collection,at&order=model,collection`),
      restAll(`model_comments?model=${inList}&select=model,author,at,hidden_at,removed_at,parent&order=id`),
      restAll(`shared_models?remixed_from=${inList}&select=remixed_from,published,created_at&order=id`),
      restAll(`model_stats?model=${inList}&select=model,views,builds&order=model`),
      restAll(`share_versions?model=${inList}&select=model,at&order=model,n`),
    ]);
    const firstShared = new Map();
    for (const v of versions) if (!firstShared.has(v.model) || v.at < firstShared.get(v.model)) firstShared.set(v.model, v.at);
    const ownerOf = (model) => (models.includes(model) ? adaId : null);
    // Each person once, from the oldest of their Saved and their lists that hold it.
    const keepers = new Map();
    for (const row of [...kept.map((k) => ({ model: k.model, who: k.account, at: k.at })),
      ...held.map((h) => ({ model: h.model, who: owners.get(h.collection), at: h.at }))]) {
      if (!row.who || row.who === ownerOf(row.model)) continue;
      const key = `${row.model} ${row.who}`;
      if (!keepers.has(key) || Date.parse(row.at) < Date.parse(keepers.get(key).at)) keepers.set(key, row);
    }
    const day = (at) => utcDay(Date.parse(at));
    const events = {
      views: opened.map((v) => ({ model: v.model, day: v.day, n: 1 })),
      builds: built.map((b) => ({ model: b.model, day: day(b.at), n: 1 })),
      likes: liked.filter((l) => l.account !== ownerOf(l.model)).map((l) => ({ model: l.model, day: day(l.at), n: 1 })),
      saves: [...keepers.values()].map((k) => ({ model: k.model, day: day(k.at), n: 1 })),
      comments: said.filter((c) => !c.hidden_at && !c.removed_at && c.author !== ownerOf(c.model) && c.parent === null
        && Date.parse(c.at) >= Date.parse(firstShared.get(c.model))).map((c) => ({ model: c.model, day: day(c.at), n: 1 })),
      remixes: remixed.filter((r) => r.published).map((r) => ({ model: r.remixed_from, day: day(r.created_at), n: 1 })),
    };
    const statsOf = new Map(stats.map((s) => [s.model, s]));
    let held30 = 0;
    const wrong = [];
    const answered = new Map((mine.body.models || []).map((one) => [one.id, one.period]));
    const sums = Object.fromEntries(KINDS.map((kind) => [kind, { now: 0, before: 0, ever: 0, weeks: Array(8).fill(0) }]));
    for (const model of models) {
      for (const kind of KINDS) {
        const mineOf = events[kind].filter((e) => e.model === model);
        const plain = { now: within(mineOf, win.now), before: within(mineOf, win.before), weeks: win.weeks.map((w) => within(mineOf, w)),
          ever: kind === "views" ? statsOf.get(model)?.views ?? 0 : kind === "builds" ? statsOf.get(model)?.builds ?? 0
            : mineOf.reduce((s, e) => s + e.n, 0) };
        const got = answered.get(model)?.[kind] || {};
        held30 += 11;
        for (const key of ["now", "before", "ever"]) if (got[key] !== plain[key]) wrong.push(`${model} ${kind} ${key} ${got[key]} != ${plain[key]}`);
        if (JSON.stringify(got.weeks) !== JSON.stringify(plain.weeks)) wrong.push(`${model} ${kind} weeks ${got.weeks} != ${plain.weeks}`);
        sums[kind].now += plain.now;
        sums[kind].before += plain.before;
        sums[kind].ever += plain.ever;
        plain.weeks.forEach((v, w) => { sums[kind].weeks[w] += v; });
      }
    }
    check(`${held30} numbers against the rows: ${wrong.length} wrong${wrong.length ? ` (${wrong.slice(0, 4).join("; ")})` : ""}`,
      held30 === MODELS * 6 * 11 && wrong.length === 0);
    check(`and nothing passes by counting nothing: ${KINDS.map((kind) => `${kind} ${sums[kind].now}/${sums[kind].before}/${sums[kind].ever}`).join(", ")}`,
      KINDS.every((kind) => sums[kind].now > 0 && sums[kind].ever > 0));
    check("the totals are the models added up", KINDS.every((kind) => JSON.stringify(period.totals?.[kind]) === JSON.stringify(sums[kind])));
    const edge = answered.get(models[0])?.builds || {};
    const edges = { now: within(events.builds.filter((e) => e.model === models[0]), win.now) };
    check(`the edges: the first model's builds ${edge.now} in the last 30 and ${edge.before} before, Cy's like at the first instant `
      + `in the last 30 (${answered.get(models[1])?.likes?.now}), Bob's a second before it in the 30 before (${answered.get(models[2])?.likes?.before})`,
    edge.now === edges.now && answered.get(models[1])?.likes?.now >= 1 && answered.get(models[2])?.likes?.before >= 1);
  }

  // --- 4. Insights, as Ada ----------------------------------------------------
  console.log("Insights, as Ada, at 1280, 768 and 390 px, light and dark");
  const totals = mine.body.period?.totals || {};
  const shotsAt = [[1280, 900, false], [768, 1024, false], [390, 844, true]];
  for (const [width, height, phone] of shotsAt) {
    for (const dark of [false, true]) {
      const hers = await context({ as: ada, width, height, phone, dark });
      const page = await hers.newPage();
      listen(page, `Ada at ${width} px${dark ? " dark" : ""}`);
      await page.goto(`${site}/profile?tab=insights`, { waitUntil: "load" });
      await until(page, () => ["ready", "trouble", "empty", "not-yet"].includes(document.documentElement.dataset.designs), "her Insights");
      const seen = await drawn(page, "designs");
      const name = `${width}_${dark ? "dark" : "light"}`;
      if (before) {
        check(`${name}: drawn as before the file (${seen.state}, period ${seen.period}), ${seen.rows.length} rows`,
          seen.state === "ready" && seen.period === "none" && seen.rows.length === MODELS && !(await sideways(page)));
      } else {
        const tilesRight = KINDS.every((kind) => seen.tiles[kind]?.now === totals[kind].now && seen.tiles[kind]?.before === totals[kind].before
          && seen.tiles[kind]?.ever === totals[kind].ever);
        const chartRight = seen.chart?.kind === "views" && seen.chart.bars === 8 && seen.chart.table.length === 8
          && seen.chart.table.every((cells, w) => Number(cells[1].replace(/\D/g, "")) === totals.views.weeks[w]);
        check(`${name}: six tiles, each the API's total (${KINDS.map((kind) => `${kind} ${seen.tiles[kind]?.shown} ${seen.tiles[kind]?.said}`).join("; ")})`,
          seen.state === "ready" && seen.period === "ready" && tilesRight);
        check(`${name}: the chart, ${seen.chart?.bars} weeks of views, its table the same; "${seen.days}"; ${seen.means} meanings`,
          chartRight && /UTC/.test(seen.chart?.caption || "") && seen.means === 7);
        check(`${name}: ${seen.rows.length} rows, the most viewed first, each with its six and its weeks; two dropdowns `
          + `(${seen.selects.map((s) => `${s.label} ${Math.round(s.height)} px`).join(", ")}); nothing sideways`,
        seen.rows.length === MODELS && seen.rows.every((r, at) => Object.keys(r.kinds).length === 6 && r.weeks.split(",").length === 8
          && (at === 0 || seen.rows[at - 1].kinds.views.now >= r.kinds.views.now))
          && seen.selects.length === 2 && seen.selects.every((s) => s.height >= 44) && !(await sideways(page)));
      }
      await page.evaluate(() => window.scrollTo(0, 0));
      if (phone) {
        await shot(page, `${name}-top.png`, false);
        await page.evaluate(() => document.querySelector("#designs .period-chart, #designs .design-rows")?.scrollIntoView());
        await shot(page, `${name}-chart.png`, false);
      } else {
        await page.evaluate(() => document.getElementById("designs")?.scrollIntoView());
        await shot(page, `${name}.png`, false);
      }
      if (!before && width === 1280 && !dark) {
        // Sorted by the change: the most gained first.
        await page.selectOption("#designs-sort", "gaining");
        const gaining = await drawn(page, "designs");
        const gains = gaining.rows.map((r) => r.kinds.views.now - r.kinds.views.before);
        check(`sorted by the change in views: ${gains.slice(0, 5).join(", ")} … ${gains.slice(-3).join(", ")}, the most gained first`,
          gains.every((g, at) => at === 0 || gains[at - 1] >= g) && gains[0] > gains.at(-1));
        await page.selectOption("#designs-sort", "fading");
        const fading = (await drawn(page, "designs")).rows.map((r) => r.kinds.views.now - r.kinds.views.before);
        check(`fading the most first: ${fading.slice(0, 3).join(", ")}`, fading.every((g, at) => at === 0 || fading[at - 1] <= g));
        // Another kind: the chart, each line and the order follow it.
        await page.selectOption("#designs-kind", "likes");
        await page.selectOption("#designs-sort", "most");
        const likes = await drawn(page, "designs");
        check(`likes chosen: the chart "${likes.chart?.caption}", its table ${likes.chart?.table.map((c) => c[1]).join(" ")}; `
          + `every line of likes; the most liked first`, likes.chart?.kind === "likes" && likes.chart.table.every((cells, w) =>
          Number(cells[1].replace(/\D/g, "")) === totals.likes.weeks[w]) && likes.rows.every((r) => r.weeksKind === "likes"
          && r.weeks === mine.body.models.find((m) => m.id === r.id).period.likes.weeks.join(","))
          && likes.rows.every((r, at) => at === 0 || likes.rows[at - 1].kinds.likes.now >= r.kinds.likes.now));
        // The chart's keys: one Tab stop, the arrows move it, its tip says the week.
        await page.focus("#designs .period-chart .hit[tabindex='0']");
        await page.keyboard.press("ArrowLeft");
        const tip = await page.evaluate(() => ({ focused: document.activeElement?.getAttribute("aria-label") || "",
          tip: document.querySelector("#designs .period-chart .tip:not([hidden])")?.textContent || "" }));
        check(`the chart's keys: ← to "${tip.focused}", its tip "${tip.tip}"`, /\d/.test(tip.focused) && tip.tip.length > 0
          && tip.focused.startsWith(likes.chart.table[6][0]));
        await page.evaluate(() => document.querySelector("#designs .period-chart")?.scrollIntoView());
        await shot(page, `${name}-likes.png`, false);
      }
      await hers.close();
    }
  }
  if (!before) {
    // In German: the same page, its words said.
    const german = await context({ as: ada, width: 390, height: 844, phone: true });
    const page = await german.newPage();
    listen(page, "Ada in German");
    await page.goto(`${site}/de/profile?tab=insights`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.designs === "ready", "her Insights in German");
    const words = await page.evaluate(() => document.getElementById("designs")?.innerText || "");
    check(`in German: ${["Aufrufe", "Gespeichert", "pro Woche", "Sortieren"].filter((w) => words.includes(w)).join(", ")}; no English labels`,
      /Aufrufe/.test(words) && !/\bViews\b|\bSort models by\b|\bthe 30 days before\b/.test(words) && !(await sideways(page)));
    await page.evaluate(() => document.querySelector("#designs .period-chart")?.scrollIntoView());
    await shot(page, "390_de-chart.png", false);
    await german.close();
    // Her own /u/ page: How your models are doing, the same numbers.
    const own = await context({ as: ada, width: 1280, height: 900 });
    const ownPage = await own.newPage();
    listen(ownPage, "Ada's own page");
    await ownPage.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
    await until(ownPage, () => ["ready", "trouble", "not-mine"].includes(document.documentElement.dataset.designs), "her own page");
    const there = await drawn(ownPage, "designs-mine");
    check(`her own /u/ page: ${there.state}, the same tiles`, there.shown && there.state === "ready"
      && KINDS.every((kind) => there.tiles[kind]?.now === totals[kind].now));
    await own.close();
  }

  // --- 5. Only Ada sees them -----------------------------------------------------
  console.log("only Ada: Bob, a visitor, and no cache");
  const his = await api("/api/people?op=designs", { token: bob.access_token });
  const hisIds = (his.body.models || []).map((one) => one.id).sort();
  check(`Bob asked plainly: his own (${hisIds.join(", ")}), none of hers`, his.status === 200 && his.body.mine === true
    && hisIds.join(",") === [remixes[0][0], remixes[2][0]].sort().join(",") && !models.some((model) => JSON.stringify(his.body).includes(model)));
  const asHers = await api(`/api/people?op=designs&handle=${ADA}`, { token: bob.access_token });
  check(`Bob asks by her handle: ${asHers.status} ${JSON.stringify(asHers.body)}`, asHers.status === 200
    && JSON.stringify(asHers.body) === '{"mine":false}');
  const signedOut = await api("/api/people?op=designs");
  const forged = await api("/api/people?op=designs", { token: "not.a.token" });
  check(`signed out ${signedOut.status}, a forged sign-in ${forged.status}`, signedOut.status === 401 && forged.status === 401
    && !JSON.stringify(signedOut.body).includes(models[0]));
  const all = [first, mine, his, asHers, signedOut, forged];
  check(`every answer says ${[...new Set(all.map((one) => one.headers.get("cache-control")))].join(" | ")}`,
    all.every((one) => one.headers.get("cache-control") === "private, no-store"));
  for (const [who, as] of [["Bob", bob], ["a visitor", null]]) {
    const theirs = await context({ as, width: 1280, height: 900 });
    const page = await theirs.newPage();
    listen(page, `${who} on Ada's page`);
    await page.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
    await until(page, () => ["not-mine", "signed-out", "ready", "trouble"].includes(document.documentElement.dataset.designs)
      || document.readyState === "complete", `${who} on her page`);
    await page.waitForTimeout(1500);
    const there = await page.evaluate(() => ({ state: document.documentElement.dataset.designs || "",
      hidden: document.getElementById("designs-mine")?.hidden ?? true, tiles: document.querySelectorAll("#designs-mine li[data-earned]").length }));
    check(`${who} on her page: ${there.state || "nothing asked"}, her numbers hidden (${there.tiles} tiles)`,
      there.hidden && there.tiles === 0 && there.state !== "ready");
    await theirs.close();
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await browser.close();
  // --- 6. Gone with the accounts ------------------------------------------------
  for (const who of ["ada", "bob", "cy"]) await deleteAccount(email(who)).catch(() => {});
  const left = await rest(`shared_models?id=in.(${[...models, id("Rx", 0), id("Rx", 1), id("Rx", 2)].join(",")})&select=id`).catch(() => null);
  check(`the accounts deleted, their models with them (${left === null ? "unknown" : left.length} left)`, Array.isArray(left) && left.length === 0);
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `designer_period: ${failed} FAILED, ${passed} ok`
  : `designer_period: a designer's numbers against last month, for them alone (${passed} checks, all ok)${before ? " (before the file)" : ""}`);
process.exit(failed ? 1 : 0);
