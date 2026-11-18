// supabase/analytics.sql itself, in pg.mjs's Postgres after the files it
// reads (console2.sql's relay_call_days, social.sql's sends): what
// tests/test_insights.py asks of it.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/insights/db_check.mjs
//
// Prints one JSON object, each finding by name.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS } from "../console/needs2.mjs";

// Dates as PostgREST sends them ("2026-11-13").
createRequire(import.meta.url)(process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js").types.setTypeParser(1082, (v) => v);
// analytics.sql, then the review's fixes over it (infix): as the live
// project has them once both are applied.
const SQLS = ["supabase/analytics.sql", "supabase/analytics2.sql"];
const db = await startPostgres({ also: [...NEEDS, "supabase/console2.sql", "supabase/social.sql", ...SQLS] });
const rpc = async (name, args = {}) => {
  const names = Object.keys(args);
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
  const rows = await db.q(`select public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`, values);
  return rows[0].answer;
};
/// [sql] as [role]: "ok", or the database's words.
async function as(role, sql) {
  const client = await db.connect();
  try {
    await client.query("begin");
    await client.query(`set local role ${role}`);
    await client.query(sql);
    await client.query("rollback");
    return "ok";
  } catch (trouble) {
    await client.query("rollback").catch(() => {});
    return String(trouble?.message || trouble).slice(0, 160);
  } finally {
    await client.end().catch(() => {});
  }
}
const out = {};
const H1 = "a1".repeat(12);
const H2 = "b2".repeat(12);
try {
  // Applied again, nothing changes and nothing fails.
  for (const SQL of SQLS) await db.q(readFileSync(new URL(`../../../${SQL}`, import.meta.url), "utf8"));
  out.again = "ok";
  // The shared_models the funnel reads, as the live table has them.
  await db.q("alter table public.shared_models add column if not exists published boolean not null default true, "
    + "add column if not exists created_at timestamptz not null default now()");

  // Nobody but the server's functions reaches a row.
  out.roles = {
    anon_reads: await as("anon", "select * from public.insights_events"),
    signed_in_reads: await as("authenticated", "select * from public.insights_visits"),
    server_reads_table: await as("service_role", "select * from public.insights_events"),
    anon_takes: await as("anon", "select public.insights_take('abcdefgh12345678', '{}', '[]', '[]', null, 0, false)"),
    server_takes: await as("service_role", "select public.insights_take('abcdefgh12345678', '{}', '[]', '[]', null, 0, false)"),
    server_reads: await as("service_role", "select public.insights_read(current_date - 1, current_date, false, '{}', '[]')"),
  };

  // A site visit from a social desk post (Reddit), on a phone, in German.
  const A = "aaaaaaaaaaaaaaa1";
  out.take_a = await rpc("insights_take", { p_visit: A, p_about: { landing: "/gallery", channel: "social", source: "reddit.com",
    medium: "social", campaign: "bw-abcdefghij", device: "phone", browser: "safari", os: "ios", lang: "de" },
  p_events: [["site", "view", "/gallery", 1], ["site", "view", "/m/:id", 2], ["site", "act", "people.like", 1, null, true],
    ["site", "act", "share.comment", 1, null, false], ["site", "load", "site_lcp", 1, 1800], ["site", "load", "site_lcp", 1, 2400]],
  p_seen: [], p_account: null, p_seconds: 40, p_test: false });
  // A studio visit, signed in (H1), on a desktop: everything the studio counts.
  const B = "bbbbbbbbbbbbbbb2";
  out.take_b = await rpc("insights_take", { p_visit: B, p_about: { landing: "/app", studio: true, channel: "search",
    source: "google.com", device: "desktop", browser: "chrome", os: "windows", lang: "en", last: "panel:simulate" },
  p_events: [["studio", "view", "/app", 1], ["studio", "milestone", "studio", 1, 9000], ["studio", "load", "studio_ui", 1, 9000],
    ["studio", "tool", "move", 3, 42000], ["studio", "panel", "simulate", 1], ["studio", "press", "render_go", 2],
    ["studio", "command", "open_model", 1], ["studio", "part", "placed", 5], ["studio", "milestone", "first_part", 1, 15000],
    ["studio", "save", "model", 1], ["studio", "milestone", "first_save", 1, 60000], ["studio", "run", "simulate", 1, 4000, true],
    ["studio", "run", "render", 1, 12000, false], ["studio", "frames", "raf", 1, 16.7], ["studio", "frames", "raf", 1, 33.4],
    ["studio", "error", "gd:src/main.gd:120", 1], ["studio", "leave", "press:render_go", 1]],
  p_seen: ["render_go", "render_close", "menu_file", "Bad Name", "ada@example.com"], p_account: H1, p_seconds: 300, p_test: false });
  // The same visit again: its counts add, its landing stays.
  out.take_b2 = await rpc("insights_take", { p_visit: B, p_about: { landing: "/elsewhere", device: "phone", last: "press:render_go" },
    p_events: [["studio", "part", "placed", 2]], p_seen: ["render_go"], p_account: null, p_seconds: 60, p_test: false });
  out.visit_b = (await db.q("select landing, device, account, seconds, beacons, rows, studio, last_act from public.insights_visits where visit = $1", [B]))[0];
  // What a row may not hold is let go, never an error, and nothing of it kept.
  out.take_bad = await rpc("insights_take", { p_visit: "aaaaaaaaaaaaaaa3", p_about: { landing: "/m/ada@example.com", source: "Ada Lovelace",
    channel: "spam", device: "toaster", lang: "xx" },
  p_events: [["site", "view", "ada@example.com", 1], ["site", "act", "typed words here", 1], ["mcp", "call", "x", 1],
    ["site", "nonsense", "x", 1], ["site", "view", "/x", 99999999], "not a row", ["site", "view", "/y", 1, -5]],
  p_seen: JSON.stringify("not a list"), p_account: "not-a-hash", p_seconds: 99999, p_test: false });
  out.bad_visit = (await db.q("select landing, source, channel, device, lang, account, seconds from public.insights_visits "
    + "where visit = 'aaaaaaaaaaaaaaa3'"))[0];
  out.bad_events = await db.q("select name, n, ms from public.insights_events where visit = 'aaaaaaaaaaaaaaa3' order by name");
  out.bad_id = await rpc("insights_take", { p_visit: "Not-An-Id", p_about: {}, p_events: [["site", "view", "/", 1]], p_seen: [],
    p_account: null, p_seconds: 0, p_test: false });
  // A studio that is neither yes nor no, and an about that is a list: let go
  // (the checks' own, so nothing below counts them).
  out.take_odd = [await rpc("insights_take", { p_visit: "fffffffffffffff7", p_about: { studio: "maybe", landing: "/app" },
    p_events: [], p_seen: [], p_account: null, p_seconds: 0, p_test: true }),
  await rpc("insights_take", { p_visit: "ggggggggggggggg8", p_about: ["landing", "/app"], p_events: [["site", "view", "/", 1]],
    p_seen: [], p_account: null, p_seconds: 0, p_test: true })];
  out.odd_visits = await db.q("select visit, studio, landing from public.insights_visits where visit in ('fffffffffffffff7', "
    + "'ggggggggggggggg8') order by visit");
  // A batch past 80 is cut at 80.
  out.take_many = await rpc("insights_take", { p_visit: "ccccccccccccccc4", p_about: {},
    p_events: Array.from({ length: 120 }, (x, n) => ["site", "view", `/p${n}`, 1]), p_seen: [], p_account: null, p_seconds: 0,
    p_test: false });
  // The checks' own: kept apart.
  out.take_test = await rpc("insights_take", { p_visit: "ddddddddddddddd5", p_about: { device: "tablet" },
    p_events: [["site", "view", "/", 1]], p_seen: [], p_account: H2, p_seconds: 5, p_test: true });
  // The connector's calls: H1's, one failed.
  out.calls = [await rpc("insights_call", { p_account: H1, p_tool: "look_at_model", p_ok: true, p_ms: 800, p_test: false }),
    await rpc("insights_call", { p_account: H1, p_tool: "place_part", p_ok: false, p_ms: 1600, p_test: false }),
    await rpc("insights_call", { p_account: H1, p_tool: "Bad Tool", p_ok: true, p_ms: 1, p_test: false })];

  // Every row, as text: no address, no IP, no typed words, no account id.
  const dump = JSON.stringify(await db.q("select (select json_agg(v) from public.insights_visits v) as v, "
    + "(select json_agg(e) from public.insights_events e) as e, (select json_agg(s) from public.insights_seen s) as s"));
  out.leaks = ["@", "ada", "Ada", "Lovelace", "typed", "Bad", "toaster", "00000000-0000"].filter((word) => dump.includes(word));

  // Today read live: through insights_agg, before any rollup.
  const ada = await db.user("ada@example.com", { made: new Date().toISOString() });
  const bob = await db.user("bob@example.com", { made: new Date(Date.now() - 20 * 86400000).toISOString() });
  await db.q("insert into public.shared_models (owner, id, published, created_at) values ($1, 'mdl1', true, now())", [ada]);
  await db.q("insert into public.relay_call_days (owner, day, calls) values ($1, current_date - 6, 3)", [bob]);
  const accounts = [{ h: H1, id: ada, joined: new Date().toISOString(), plan: "tester" },
    { h: "c3".repeat(12), id: bob, joined: new Date(Date.now() - 20 * 86400000).toISOString(), plan: "free" }];
  const today = (await db.q("select current_date::text as d"))[0].d;
  const from = (await db.q("select (current_date - 29)::text as d"))[0].d;
  const live = await rpc("insights_read", { p_from: from, p_to: today, p_tests: false, p_filters: {}, p_accounts: accounts });
  out.live = { day: live.days.at(-1), funnel: live.funnel, campaigns: live.sources.campaigns, channels: live.sources.channels,
    used: live.used.filter((one) => ["run", "call", "tool", "act"].includes(one.kind)), speed: live.speed, seen: live.seen.map((one) => one.name),
    retention: live.retention };
  out.phone = (await rpc("insights_read", { p_from: from, p_to: today, p_tests: false, p_filters: { device: "phone" },
    p_accounts: accounts })).days.at(-1);
  out.tests_read = (await rpc("insights_read", { p_from: from, p_to: today, p_tests: true, p_filters: {}, p_accounts: [] })).days.at(-1);

  // Yesterday: the rows moved a day back, rolled up, and the rollup held
  // against them, kind by kind.
  await db.q("update public.insights_events set day = day - 1, at = at - interval '1 day'");
  await db.q("update public.insights_visits set day = day - 1, first_at = first_at - interval '1 day', last_at = last_at - interval '1 day'");
  out.unrolled = (await db.q("select array_agg(d::text) as d from public.insights_unrolled(current_date - 30) d"))[0].d;
  // Read before the cron: the same numbers from the rows, and nothing written.
  const before = await rpc("insights_read", { p_from: from, p_to: today, p_tests: false, p_filters: {}, p_accounts: accounts });
  out.read_wrote = (await db.q("select (select count(*) from public.insights_rollups)::int as rollups, "
    + "(select count(*) from public.insights_days)::int as days"))[0];
  // The cron: each day over rolled up, one call a day (api/_analytics.js tallyDaily), then what deleted accounts left.
  out.rolled_days = [];
  for (const day of (await db.q("select d::text as d from public.insights_unrolled(current_date - 30) d")).map((r) => r.d)) {
    out.rolled_days.push({ day, rows: await rpc("insights_rollup", { p_day: day, p_plans: { [H1]: "tester" } }) });
  }
  out.daily = await rpc("insights_gone", { p_plans: { [H1]: "tester" }, p_listed: 40 });
  // Applied again once live, analytics2.sql keeps every row and the rollup.
  const kept = async () => (await db.q("select (select count(*) from public.insights_days)::int as days, "
    + "(select count(*) from public.insights_visits where not test)::int as visits"))[0];
  const keptBefore = await kept();
  await db.q(readFileSync(new URL("../../../supabase/analytics2.sql", import.meta.url), "utf8"));
  out.again_keeps = { before: keptBefore, after: await kept() };
  // H2 is in no account listed: an account deleted, its rows let go.
  out.h2_left = (await db.q("select (select count(*) from public.insights_account_days where account = $1)::int as days, "
    + "(select count(*) from public.insights_account_firsts where account = $1)::int as firsts, "
    + "(select count(*) from public.insights_visits where account = $1)::int as visits, "
    + "(select count(*) from public.insights_events where account = $1)::int as events", [H2]))[0];
  // A listing that came back empty deletes nothing.
  out.daily_empty = await rpc("insights_gone", { p_plans: {}, p_listed: 0 });
  // Nor one much shorter than the last that went through (40 then 3).
  out.daily_short = await rpc("insights_gone", { p_plans: {}, p_listed: 3 });
  out.h1_kept = (await db.q("select count(*)::int as n from public.insights_account_days where account = $1", [H1]))[0].n;
  out.unrolled_after = (await db.q("select count(*)::int as n from public.insights_unrolled(current_date - 30)"))[0].n;
  out.held = await db.q(`
    select r.kind, r.name, r.n as rolled, h.n as held, r.visits as rolled_visits, h.visits as held_visits,
           r.ms_p50 as rolled_p50, h.p50 as held_p50, r.ok as rolled_ok, h.ok as held_ok, r.failed as rolled_failed, h.failed as held_failed
      from (select kind, name, sum(n)::int as n, sum(visits)::int as visits, max(ms_p50) as ms_p50, sum(ok)::int as ok,
                   sum(failed)::int as failed
              from public.insights_days where day = current_date - 1 and test = false and device = '*' and lang = '*'
               and kind not in ('visit', 'campaign', 'reach', 'leave') group by kind, name) r
      full join (select kind, name, sum(n)::int as n, count(distinct visit)::int as visits,
                        (percentile_cont(0.5) within group (order by ms))::real as p50,
                        count(*) filter (where ok)::int as ok, count(*) filter (where ok is false)::int as failed
                   from public.insights_events where day = current_date - 1 and test = false group by kind, name) h
             on h.kind = r.kind and h.name = r.name
     order by 1, 2`);
  out.reach = await db.q("select name, sum(visits)::int as visits, sum(people)::int as people from public.insights_days "
    + "where day = current_date - 1 and test = false and kind = 'reach' and device = '*' and lang = '*' group by name order by name");
  out.visit_rows = await db.q("select name, channel, device, sum(visits)::int as visits from public.insights_days "
    + "where day = current_date - 1 and test = false and kind = 'visit' and device <> '*' and lang = '*' "
    + "group by name, channel, device order by name");
  // Each count is kept by device and language, and over all of each ('*').
  out.star_rows = (await db.q("select count(*) filter (where device = '*' and lang = '*')::int as both, "
    + "count(*) filter (where device = '*' and lang <> '*')::int as by_lang, count(*) filter (where device <> '*' and lang = '*')::int as by_device, "
    + "count(*) filter (where device <> '*' and lang <> '*')::int as neither from public.insights_days where day = current_date - 1"))[0];
  out.firsts = await db.q("select account, first_part_at is not null as part, first_save_at is not null as save, channel, source "
    + "from public.insights_account_firsts order by account");
  out.account_days = await db.q("select account, built, studio, test from public.insights_account_days order by account");
  out.plan_rows = await db.q("select distinct plan, signed_in from public.insights_days where day = current_date - 1 order by 1");
  // Read again from the rollup: the same answer as live.
  const rolled = await rpc("insights_read", { p_from: from, p_to: today, p_tests: false, p_filters: {}, p_accounts: accounts });
  out.rolled = { day: rolled.days.at(-2), funnel: rolled.funnel, used: rolled.used.filter((one) => ["run", "call", "tool", "act"].includes(one.kind)) };
  const same = (x) => JSON.stringify({ days: x.days, funnel: x.funnel, used: x.used, speed: x.speed, sources: x.sources, retention: x.retention });
  out.read_same_before_and_after = same(before) === same(rolled);
  out.leave = rolled.used.filter((one) => one.kind === "leave");

  // 31 days on, the raw rows go and the rollup stays.
  await db.q("update public.insights_events set day = day - 30, at = at - interval '30 days'");
  await db.q("update public.insights_visits set last_at = last_at - interval '31 days'");
  out.forgot = await rpc("insights_forget");
  out.after = (await db.q("select (select count(*) from public.insights_events)::int as events, "
    + "(select count(*) from public.insights_visits)::int as visits, (select count(*) from public.insights_days)::int as days, "
    + "(select count(*) from public.insights_account_firsts)::int as firsts"))[0];

  // A flood: past the day's cap, no new visit is kept, nor any event.
  await db.q("insert into public.insights_day_rows (day, rows) values (current_date, 200000) "
    + "on conflict (day) do update set rows = 200000");
  out.flood = await rpc("insights_take", { p_visit: "eeeeeeeeeeeeeee6", p_about: {}, p_events: [["site", "view", "/", 1]],
    p_seen: [], p_account: null, p_seconds: 0, p_test: false });
  out.flood_visit = (await db.q("select count(*)::int as n from public.insights_visits where visit = 'eeeeeeeeeeeeeee6'"))[0].n;
  out.flood_call = await rpc("insights_call", { p_account: null, p_tool: "look_at_model", p_ok: true, p_ms: 1, p_test: false });
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 1500);
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
