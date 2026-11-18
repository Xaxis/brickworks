// infix (2026-11-18): the review's attacks on /admin › Analytics (inreview's db_attacks.mjs, kept in
// bench/results/inreview-2026-11-18/), what tests/test_insights.py asks of them. It also applies
// supabase/analytics2.sql, and each case adds the honest path beside the attack (a real sign-in's bearer, a
// real control's name), since the fixed beacon takes neither a "who" nor a made-up name. Changes from the
// reviewer's are marked "infix:". Cases P, L1 and M3 are infix's own.
//
//   TREE=<checkout> PG_MODULE=... PG_BIN=... node tests/fixtures/insights/attacks_check.mjs [--big]
//
// inreview (2026-11-18): the database and API half of the review of insights
// (supabase/analytics.sql, api/_analytics.js). Each attack is shown with
// numbers, through the real handlers where a visitor would come in.
//
//   TREE=<checkout> PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
//   PG_BIN=~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/@embedded-postgres/linux-x64/native/bin \
//   node bench/results/inreview-2026-11-18/db_attacks.mjs [--big]
//
// Prints one JSON object. --big also times the read and the rollup at a
// flooded day's 200,000 rows (minutes).
import { createRequire } from "node:module";
import { randomUUID } from "node:crypto";
import path from "node:path";

const TREE = process.env.TREE || path.resolve(new URL("../../..", import.meta.url).pathname);
const BIG = process.argv.includes("--big");
const at = (file) => path.join(TREE, file);
createRequire(at("tests/fixtures/beta/pg.mjs"))(process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js")
  .types.setTypeParser(1082, (v) => v);
const { startPostgres } = await import(at("tests/fixtures/beta/pg.mjs"));
const { NEEDS } = await import(at("tests/fixtures/console/needs2.mjs"));
const { SUPABASE_URL, askAdmin, askPlans, world } = await import(at("tests/fixtures/billing/world.mjs"));

const pg = await startPostgres({ also: [...NEEDS, "supabase/console2.sql", "supabase/social.sql", "supabase/analytics.sql",
  "supabase/analytics2.sql"] }); // infix: and analytics2.sql
const rpc = async (name, args = {}) => {
  const names = Object.keys(args);
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
  const rows = await pg.q(`select public.${name}(${names.map((key, n) => `${key} => $${n + 1}`).join(", ")}) as answer`, values);
  return rows[0].answer;
};
const logged = [];
for (const level of ["log", "error", "warn", "info"]) console[level] = (...said) => logged.push(said.map(String).join(" "));
const out = {};
const OWNER = "11111111-1111-4111-8111-111111111111";
const TESTER = "33333333-3333-4333-8333-333333333333"; // a shared test account (@resend.dev)
const REAL = Array.from({ length: 20 }, (_, n) => `44444444-4444-4444-8444-${String(n).padStart(12, "0")}`);
let rpcBytes = 0;
let takeBodies = [];
try {
  await pg.q("alter table public.shared_models add column if not exists published boolean not null default true, "
    + "add column if not exists created_at timestamptz not null default now()");
  const w = await world({ master: "owner@example.com" });
  process.env.CRON_SECRET = "cron-check-secret";
  process.env.VIEW_SECRET = "view-check-secret";
  const old = new Date(Date.now() - 90 * 86400000).toISOString();
  const USERS = [{ id: OWNER, email: "owner@example.com", created_at: old },
    { id: TESTER, email: "bw-check@resend.dev", created_at: old, email_confirmed_at: old },
    ...REAL.map((id, n) => ({ id, email: `person${n}@example.org`, created_at: new Date(Date.now() - n * 86400000).toISOString() }))];
  const worldFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    // infix: names with an underscore (insights_forget_account), and a set-returning one (insights_unrolled) as
    // PostgREST answers it, an array.
    const fn = /^\/rest\/v1\/rpc\/(insights_[a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && fn) {
      const body = JSON.parse(String(init.body || "{}"));
      if (fn[1] === "insights_take") takeBodies.push(String(init.body || "").length);
      try {
        const text = JSON.stringify(fn[1] === "insights_unrolled"
          ? (await pg.q("select public.insights_unrolled(p_from => $1) as d", [body.p_from])).map((r) => r.d)
          : await rpc(fn[1], body));
        rpcBytes += text.length;
        return new Response(text, { status: 200 });
      } catch (trouble) {
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: 400 });
      }
    }
    if (url.origin === SUPABASE_URL && url.pathname === "/auth/v1/admin/users") {
      return new Response(JSON.stringify({ users: USERS }), { status: 200 });
    }
    // infix: one account by its id (api/_analytics.js emailOf, whether a tool call is a test account's).
    const one = /^\/auth\/v1\/admin\/users\/([0-9a-f-]{36})$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && one) {
      const user = USERS.find((u) => u.id === one[1]);
      return new Response(JSON.stringify(user || {}), { status: user ? 200 : 404 });
    }
    return worldFetch(input, init);
  };
  const owner = await w.signIn({ sub: OWNER, email: "owner@example.com" });
  const { accountHash, tallyCall, forgetAccount } = await import(at("api/_analytics.js"));
  // infix: each real account's own sign-in, as its page would send it.
  const tokens = {};
  for (const user of USERS) tokens[user.id] = await w.signIn({ sub: user.id, email: user.email });
  let n = 0;
  const visit = () => `atk${String((n += 1)).padStart(13, "0")}`;
  const post = (body, headers = {}) => askPlans({ method: "POST", query: { op: "tally" }, headers: { host: "brickworks.diy", ...headers }, body });
  const read = async (tests = false, query = {}) => {
    rpcBytes = 0;
    const t0 = Date.now();
    const got = await askAdmin({ method: "GET", query: { op: "analytics", ...(tests ? { tests: "1" } : {}), ...query },
      headers: { host: "brickworks.diy", authorization: `Bearer ${owner}` } });
    return { status: got.status, json: got.json, ms: Date.now() - t0, rpc_bytes: rpcBytes, bytes: JSON.stringify(got.json || {}).length };
  };

  // A. Every deployment is a production one (tools/deploy.sh --prod --skip-domain), so VERCEL_ENV is
  // "production" on previews too: a check's tool call on a preview, by a shared test account, is a real row.
  process.env.VERCEL_ENV = "production";
  await tallyCall(TESTER, "look_at_model", true, 120);
  await tallyCall(TESTER, "place_part", true, 80);
  // infix: the same on the live host (a test account's still a test row), a person's on the live host and on a preview.
  await tallyCall(TESTER, "look_at_model", true, 120, "brickworks.diy");
  await tallyCall(REAL[0], "look_at_model", true, 90, "brickworks.diy");
  await tallyCall(REAL[0], "place_part", true, 90, "brickworks-abc123-xaxis-projects.vercel.app");
  const callRows = await pg.q("select account, test, name from public.insights_events where surface = 'mcp' order by id");
  const real = await read(false);
  out.A_preview_mcp_real = {
    rows: callRows.map((r) => ({ test: r.test, name: r.name, tester: r.account === accountHash(TESTER), account_kept: r.account !== null })),
    said: ["tester, no host", "tester, no host", "tester, brickworks.diy", "person, brickworks.diy", "person, a preview"],
    owners_real_view_calls: (real.json.used || []).filter((u) => u.kind === "call").map((u) => ({ name: u.name, n: Number(u.n), people: Number(u.people) })),
    owners_real_view_today_calls: real.json.days?.at(-1)?.calls,
  };
  await pg.q("delete from public.insights_events where surface = 'mcp'");

  // B. Forged numbers: one beacon, any visit id, n up to 10000 an event, 80 events.
  const forged = visit();
  await post({ v: forged, about: { landing: "/gallery" }, e: Array.from({ length: 80 }, () => ["site", "act", "people.like", 10000, null, true]) });
  const r1 = await read(false);
  out.B_one_beacon_inflates = { likes_counted: Number((r1.json.used || []).find((u) => u.name === "people.like")?.n || 0) };

  // C. Anyone's account: the beacon's "who" is taken as said, no session asked.
  const victim = REAL[3];
  const posed = visit();
  await post({ v: posed, about: { landing: "/app", studio: true }, who: victim, e: [["studio", "part", "placed", 50], ["studio", "save", "model", 9]] });
  const vrow = (await pg.q("select account from public.insights_visits where visit = $1", [posed]))[0];
  // infix: and with a forged bearer, and with the victim's own sign-in (the honest path).
  const posed2 = visit();
  await post({ v: posed2, about: { landing: "/app" }, who: victim, bearer: "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ4In0.c2ln", e: [["studio", "part", "placed", 1]] });
  const own = visit();
  await post({ v: own, about: { landing: "/app" }, bearer: tokens[victim], e: [["studio", "part", "placed", 1]] });
  const accountOf = async (v) => (await pg.q("select account from public.insights_visits where visit = $1", [v]))[0]?.account ?? null;
  out.C_who_unverified = { kept_as_victims_hash: vrow?.account === accountHash(victim), forged_bearer_kept_as_victim: (await accountOf(posed2)) === accountHash(victim),
    own_sign_in_kept_as_victim: (await accountOf(own)) === accountHash(victim) };

  // D. insights_seen is outside every cap: once the day's cap is reached, an old visit still adds 400 names a beacon.
  const d0 = Number((await pg.q("select count(*) n from public.insights_seen"))[0].n);
  await pg.q("insert into public.insights_day_rows (day, rows) values ((now() at time zone 'utc')::date, 200000) "
    + "on conflict (day) do update set rows = 200000");
  for (let b = 0; b < 25; b += 1) {
    await post({ v: forged, about: {}, e: [], seen: Array.from({ length: 400 }, (_, k) => `junk_${String.fromCharCode(97 + (b % 26))}${"x".repeat(k % 40)}_${b}_${k}`.replace(/[0-9]/g, (d) => "abcdefghij"[d]).slice(0, 60)) });
  }
  const d1 = Number((await pg.q("select count(*) n from public.insights_seen"))[0].n);
  // infix: real control names (the studio's own), at the cap: none kept either.
  const { NAMES } = await import(at("api/_insights_names.js"));
  await post({ v: forged, about: {}, e: [], seen: NAMES.exact.studio.press.slice(0, 400) });
  const d1real = Number((await pg.q("select count(*) n from public.insights_seen"))[0].n) - d1;
  const r2 = await read(false);
  out.D_seen_uncapped = { day_rows_at_cap: 200000, beacons: 25, seen_rows_added: d1 - d0, real_names_added_at_cap: d1real, read_seen_entries: (r2.json.seen || []).length,
    read_bytes: r2.bytes, read_rpc_bytes: r2.rpc_bytes };

  // E. The day's cap blinds the day: once a script has posted 200,000 rows, a real new visit keeps nothing.
  const realVisit = visit();
  await post({ v: realVisit, about: { landing: "/" }, e: [["site", "view", "/", 1]] });
  out.E_flood_blinds_day = { real_visit_kept: Number((await pg.q("select count(*) n from public.insights_visits where visit = $1", [realVisit]))[0].n),
    mcp_call_kept: await rpc("insights_call", { p_account: null, p_tool: "look_at_model", p_ok: true, p_ms: 10, p_test: false }),
    beacons_to_reach_cap: Math.ceil(200000 / 81),
    // infix: what the day says of it.
    turned_away: Number((await pg.q("select turned_away from public.insights_day_rows where day = (now() at time zone 'utc')::date"))[0]?.turned_away) };
  // infix: past the soft budget (150,000), new visits are sampled, one in 8, and counted 8 times.
  await pg.q("update public.insights_day_rows set rows = 150000, turned_away = 0 where day = (now() at time zone 'utc')::date");
  const sampled = [];
  for (let k = 0; k < 64; k += 1) {
    const v = visit();
    sampled.push(v);
    await post({ v, about: { landing: "/" }, e: [["site", "view", "/", 1]] });
  }
  const keptW = await pg.q("select count(*) n, min(weight) w from public.insights_visits where visit = any($1)", [sampled]);
  const r2s = await read(false);
  out.E_flood_blinds_day.past_soft = { new_visits: 64, kept: Number(keptW[0].n), weight: Number(keptW[0].w),
    today_visits_said: r2s.json.days?.at(-1)?.visits, today_said: r2s.json.days?.at(-1) };
  await pg.q("delete from public.insights_day_rows");
  await pg.q("delete from public.insights_seen");

  // F. Names are free: 80 a beacon, any that fit the pattern, each its own line in the read's "used" (no limit).
  for (let b = 0; b < 50; b += 1) {
    await post({ v: visit(), about: {}, e: Array.from({ length: 80 }, (_, k) => ["studio", "press", `zz_${"abcdefghij"[b % 10]}${"abcdefghij"[Math.floor(b / 10)]}_${"abcdefghij"[k % 10]}${"abcdefghij"[Math.floor(k / 10)]}_${"q".repeat(40)}`, 1]) });
  }
  const r3 = await read(false);
  const usedN = (r3.json.used || []).length;
  out.F_used_unbounded = { distinct_names_posted: 4000, read_used_entries: usedN, read_bytes: r3.bytes, bytes_per_entry: Math.round(r3.bytes / usedN),
    at_day_cap_200k_names_bytes_one_day: Math.round(r3.bytes / usedN) * 200000, at_30_days_bytes: Math.round(r3.bytes / usedN) * 200000 * 30 };
  // infix: the most the read can be: every list at its bound, with the longest known names, a flooded day.
  {
    const longest = (list, k) => [...list].sort((a, b) => b.length - a.length).slice(0, k);
    const S = NAMES.exact.studio;
    const site = NAMES.exact.site;
    const kinds = [["site", "view", site.view], ["site", "act", site.act], ["studio", "tool", S.tool], ["studio", "panel", S.panel],
      ["studio", "press", S.press], ["studio", "command", S.command], ["studio", "run", S.run], ["studio", "milestone", S.milestone],
      ["studio", "part", S.part], ["studio", "save", S.save]];
    for (const [surface, kind, list] of kinds) {
      const names = longest(list, 40);
      for (let at = 0; at < names.length; at += 20) {
        await post({ v: visit(), about: { landing: "/app", studio: surface === "studio", source: "x".repeat(60), campaign: `c${at}${kind}`.replace(/[0-9]/g, "a").padEnd(60, "q") },
          e: names.slice(at, at + 20).map((name) => [surface, kind, name, 1, 1234.5, true]) });
      }
    }
    const errs = longest(NAMES.errors.gd, 40).map((f) => `gd:${f}:1234567`);
    await post({ v: visit(), about: { landing: "/app", studio: true }, e: errs.map((name) => ["studio", "error", name, 1]) });
    for (const device of ["desktop", "phone", "tablet"]) for (const browser of ["chrome", "edge", "firefox", "safari", "samsung", "opera", "other"]) {
      await post({ v: visit(), about: { landing: "/app", studio: true, device, browser }, e: [...S.load, ...S.frames, ...site.load].map((name) => [name.startsWith("site_") ? "site" : "studio", name.startsWith("frame") ? "frames" : "load", name, 1, 1234.5]) });
    }
    const tag = (b) => `${"abcdefghij"[b % 10]}${"abcdefghij"[Math.floor(b / 10) % 10]}`;
    const longPress = longest(S.press, 40);
    for (let b = 0; b < 70; b += 1) {
      await post({ v: visit(), about: { landing: "/", source: `s${tag(b)}`.padEnd(60, "z"), campaign: `bw-${tag(b)}qqqqqqqq`,
        last: `press:${longPress[b % 40]}`, studio: true }, e: [["site", "view", "/", 1]] });
      await post({ v: visit(), about: { landing: "/", campaign: `c${tag(b)}`.padEnd(60, "y") }, e: [["site", "view", "/", 1]] });
    }
    for (const name of longest(NAMES.mcp, 40)) await tallyCall(REAL[1], name, true, 10, "brickworks.diy");
    await post({ v: visit(), about: {}, e: [], seen: S.press.slice(0, 400) });
    const most = await read(false, { from: new Date(Date.now() - 400 * 86400000).toISOString().slice(0, 10) });
    out.F_used_unbounded.most = { status: most.status, read_bytes: most.bytes, days: most.json.days?.length, used: most.json.used?.length, seen: most.json.seen?.length,
      speed: most.json.speed?.length, sources: most.json.sources?.sources?.length, campaigns: most.json.sources?.campaigns?.length,
      retention_weeks: most.json.retention?.length, names: most.json.names,
      bytes_by_list: Object.fromEntries(Object.entries(most.json).map(([k, v]) => [k, JSON.stringify(v).length])) };
  }
  await pg.q("delete from public.insights_events; delete from public.insights_visits; delete from public.insights_day_rows; delete from public.insights_seen");

  // G. Deleting accounts stops for good: forged "who"s (any UUID) become kept hashes; once more than a fifth
  // of the kept hashes (and more than 5) are not accounts, no deleted account's rows are ever removed again.
  for (const id of REAL) {
    // infix: each signed in with its own bearer (a "who" is no longer read).
    await post({ v: visit(), about: { landing: "/app", studio: true }, who: id, bearer: tokens[id], e: [["studio", "part", "placed", 1]] });
  }
  for (let k = 0; k < 6; k += 1) await post({ v: visit(), about: { landing: "/" }, who: randomUUID(), e: [["site", "view", "/", 1]] });
  // infix: and 8 forged hashes kept as the old code would have kept them, so the guard is tried against them too.
  for (let k = 0; k < 8; k += 1) {
    await pg.q("insert into public.insights_account_days (account, day, test) values ($1, (now() at time zone 'utc')::date - 1, false)", [accountHash(randomUUID())]);
  }
  await pg.q("update public.insights_events set day = day - 1, at = at - interval '1 day'");
  await pg.q("update public.insights_visits set day = day - 1, first_at = first_at - interval '1 day', last_at = last_at - interval '1 day'");
  const cron = async () => (await askPlans({ method: "GET", query: { op: "tally_daily" }, headers: { authorization: "Bearer cron-check-secret" } })).json;
  const c1 = await cron();
  const gone = REAL[5];
  USERS.splice(USERS.findIndex((u) => u.id === gone), 1); // the person deletes their account
  const c2 = await cron();
  const left = async () => Number((await pg.q("select count(*) n from public.insights_account_days where account = $1", [accountHash(gone)]))[0].n)
    + Number((await pg.q("select count(*) n from public.insights_account_firsts where account = $1", [accountHash(gone)]))[0].n)
    + Number((await pg.q("select count(*) n from public.insights_visits where account = $1", [accountHash(gone)]))[0].n);
  const after2 = await left();
  const c3 = await cron();
  // infix: a real account's rows before its deletion, so "0 left" means they were there.
  out.G_deletion_blocked = { first_cron_gone: c1?.accounts_gone, after_delete_gone: c2?.accounts_gone, deleted_accounts_rows_left: after2,
    next_day_gone: c3?.accounts_gone, rows_left_next_day: await left(), forged_whos: 6, forged_hashes_kept_before: 8, real_accounts: REAL.length,
    first_cron: c1, second_cron: c2 };
  // infix: deleting an account forgets it at once (api/_erase.js calls forgetAccount), no cron needed.
  const other = REAL[7];
  const before = async (id) => Number((await pg.q("select count(*) n from public.insights_account_days where account = $1", [accountHash(id)]))[0].n)
    + Number((await pg.q("select count(*) n from public.insights_visits where account = $1", [accountHash(id)]))[0].n);
  const had = await before(other);
  const touched = await forgetAccount(other);
  out.G_deletion_blocked.erase_at_once = { rows_before: had, touched, rows_after: await before(other) };
  // infix: a listing that failed (a third of the accounts listed) deletes nothing.
  const kept = USERS.splice(3, 14);
  const c4 = await cron();
  USERS.splice(3, 0, ...kept);
  out.G_deletion_blocked.short_listing = { listed: c4?.listed, listed_before: c4?.listed_before, listing_failed: c4?.listing_failed, gone: c4?.accounts_gone };
  await pg.q("delete from public.insights_events; delete from public.insights_visits; delete from public.insights_account_days; "
    + "delete from public.insights_account_firsts; delete from public.insights_rollups; delete from public.insights_days; delete from public.insights_day_rows");

  // infix P: one account on a phone and a desktop in one day is one visitor, and one person on a page
  // (inreview M7, people_twice.mjs).
  {
    const id = REAL[2];
    for (const device of ["phone", "desktop"]) {
      await post({ v: visit(), about: { landing: "/gallery", device }, bearer: tokens[id], e: [["site", "view", "/gallery", 1]] });
    }
    const got = await read(false);
    const phone = await read(false, { device: "phone" });
    out.P_people_twice = { visits: got.json.days?.at(-1)?.visits, visitors: got.json.days?.at(-1)?.visitors,
      gallery_people: Number((got.json.used || []).find((u) => u.name === "/gallery")?.people),
      phone_visitors: phone.json.days?.at(-1)?.visitors };
    await pg.q("delete from public.insights_events; delete from public.insights_visits; delete from public.insights_day_rows");
  }

  // infix L1: a 3 MB "about" goes no further than the route (inreview body_size.mjs).
  {
    takeBodies = [];
    const v = visit();
    await post({ v, about: { landing: "/", pad: "x".repeat(3_000_000) }, e: [["site", "view", "/", 1]] });
    const big = await post({ v: visit(), about: {} }, { "content-length": "3000200" });
    out.L1_body = { rpc_body_bytes: takeBodies[0] ?? 0, kept: Number((await pg.q("select count(*) n from public.insights_visits where visit = $1", [v]))[0].n),
      said_large_status: big.status, rpc_calls: takeBodies.length };
  }

  // infix M3: one address's beacons, as fast as a script sends them: a token bucket in memory.
  {
    const before = Number((await pg.q("select count(*) n from public.insights_visits"))[0].n);
    for (let k = 0; k < 120; k += 1) {
      await post({ v: visit(), first: true, about: { landing: "/" }, e: [["site", "view", "/", 1]] }, { "x-real-ip": "203.0.113.9" });
    }
    const other = visit();
    await post({ v: other, first: true, about: { landing: "/" }, e: [["site", "view", "/", 1]] }, { "x-real-ip": "198.51.100.7" });
    out.M3_bucket = { sent: 120, kept: Number((await pg.q("select count(*) n from public.insights_visits"))[0].n) - before - 1,
      another_address_kept: Number((await pg.q("select count(*) n from public.insights_visits where visit = $1", [other]))[0].n) };
    await pg.q("delete from public.insights_events; delete from public.insights_visits; delete from public.insights_day_rows");
  }

  // H. Load: a flooded day (200,000 rows today) read through insights_agg on every page load, and rolled up.
  if (BIG) {
    const ACC = 2000;
    await pg.q(`insert into public.insights_visits (visit, account, landing, device, lang)
      select 'v' || lpad(g::text, 15, '0'), case when g % 3 = 0 then substr(md5(g::text), 1, 24) end, '/gallery', 'desktop', 'en'
        from generate_series(1, 20000) g`);
    await pg.q(`insert into public.insights_events (visit, surface, kind, name, n)
      select 'v' || lpad((1 + g % 20000)::text, 15, '0'), 'site', 'view', '/p' || (g % 500), 1 from generate_series(1, 200000) g`);
    await pg.q("analyze");
    const many = Array.from({ length: ACC }, (_, g) => ({ id: randomUUID(), email: `p${g}@example.org`,
      created_at: new Date(Date.now() - (g % 56) * 86400000).toISOString() }));
    USERS.push(...many);
    const big = await read(false);
    out.H_read_today_200k = { status: big.status, ms: big.ms, accounts: ACC, bytes: big.bytes, error: big.json?.error };
    await pg.q("update public.insights_events set day = day - 1, at = at - interval '1 day'");
    await pg.q("update public.insights_visits set day = day - 1, first_at = first_at - interval '1 day', last_at = last_at - interval '1 day'");
    const t0 = Date.now();
    const rolled = await cron();
    out.H_rollup_200k = { ms: Date.now() - t0, rolled: rolled?.rolled, error: rolled?.error };
  }
  out.logged = logged.filter((line) => /tally/.test(line)).slice(0, 5);
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 1500);
} finally {
  await pg.stop();
}
process.stdout.write(`${JSON.stringify(out)}\n`);
process.exit(0);
