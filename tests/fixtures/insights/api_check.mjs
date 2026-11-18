// The counting through the real handlers (insights; api/_analytics.js):
// api/plans.js's tally and its cron, api/admin.js's Analytics read, and
// api/mcp.js's count of a tool call, with supabase/analytics.sql in pg.mjs's
// Postgres answering the rpc calls as PostgREST would. What
// tests/test_insights.py asks of them.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/insights/api_check.mjs
//
// Prints one JSON object, each finding by name.
import { createRequire } from "node:module";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS } from "../console/needs2.mjs";
import { SUPABASE_URL, askAdmin, askPlans, world } from "../billing/world.mjs";

createRequire(import.meta.url)(process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js").types.setTypeParser(1082, (v) => v);
const pg = await startPostgres({ also: [...NEEDS, "supabase/console2.sql", "supabase/social.sql", "supabase/analytics.sql",
  "supabase/analytics2.sql"] });
const rpc = async (name, args = {}) => {
  const names = Object.keys(args);
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
  const rows = await pg.q(`select public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`, values);
  return rows[0].answer;
};

const logged = [];
for (const level of ["log", "error", "warn", "info"]) {
  console[level] = (...said) => logged.push(said.map(String).join(" "));
}
const print = (text) => process.stdout.write(`${text}\n`);

const out = {};
const OWNER = "11111111-1111-4111-8111-111111111111";
const ADA = "33333333-3333-4333-8333-333333333333";
// A person's account, not a check's (not @resend.dev).
const PERSON = "55555555-5555-4555-8555-555555555555";
try {
  await pg.q("alter table public.shared_models add column if not exists published boolean not null default true, "
    + "add column if not exists created_at timestamptz not null default now()");
  const w = await world({ master: "owner@example.com" });
  process.env.CRON_SECRET = "cron-check-secret";
  process.env.VIEW_SECRET = "view-check-secret";
  delete process.env.VERCEL_ENV;
  // The accounts Supabase's auth lists: the checks' own are @resend.dev.
  const USERS = [{ id: OWNER, email: "owner@example.com", created_at: new Date(Date.now() - 90 * 86400000).toISOString() },
    { id: ADA, email: "ada@resend.dev", created_at: new Date().toISOString(), email_confirmed_at: new Date().toISOString() },
    { id: PERSON, email: "grace@example.org", created_at: new Date(Date.now() - 400 * 86400000).toISOString() }];
  const sent = [];
  const worldFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const fn = /^\/rest\/v1\/rpc\/(insights_[a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && fn) {
      const body = JSON.parse(String(init.body || "{}"));
      sent.push({ fn: fn[1], body });
      try {
        // A set-returning function as PostgREST answers it: an array.
        if (fn[1] === "insights_unrolled") {
          const days = await pg.q("select d::text as d from public.insights_unrolled(p_from => $1) d", [body.p_from]);
          return new Response(JSON.stringify(days.map((one) => one.d)), { status: 200 });
        }
        return new Response(JSON.stringify(await rpc(fn[1], body)), { status: 200 });
      } catch (trouble) {
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: 400 });
      }
    }
    if (url.origin === SUPABASE_URL && url.pathname === "/auth/v1/admin/users") {
      return new Response(JSON.stringify({ users: USERS }), { status: 200 });
    }
    return worldFetch(input, init);
  };
  const owner = await w.signIn({ sub: OWNER, email: "owner@example.com" });
  const stranger = await w.signIn({ sub: ADA, email: "ada@resend.dev" });
  const person = await w.signIn({ sub: PERSON, email: "grace@example.org" });
  const kept = async (visit) => (await pg.q("select count(*)::int as n from public.insights_visits where visit = $1", [visit]))[0].n;
  let n = 0;
  const visit = () => `chk${String((n += 1)).padStart(13, "0")}`;
  const beacon = (v, more = {}) => ({ v, about: { landing: "/gallery", channel: "direct", device: "desktop", browser: "chrome",
    os: "linux", lang: "en" }, e: [["site", "view", "/gallery", 1]], seen: [], seconds: 5, ...more });
  /// One beacon to api/plans.js: its status, and whether its visit was kept.
  async function tally(more = {}, headers = {}, body) {
    const v = visit();
    const got = await askPlans({ method: "POST", query: { op: "tally" }, headers: { host: "brickworks.diy", ...headers },
      body: body === undefined ? beacon(v, more) : body });
    return { status: got.status, kept: await kept(v), v };
  }

  // 1. What is kept, and what is not.
  out.plain = await tally();
  out.as_text = await (async () => {
    const v = visit();
    const got = await askPlans({ method: "POST", query: { op: "tally" }, headers: { host: "brickworks.diy" },
      body: JSON.stringify(beacon(v)) });
    return { status: got.status, kept: await kept(v) };
  })();
  out.dnt = await tally({}, { dnt: "1" });
  out.gpc = await tally({}, { "sec-gpc": "1" });
  out.dnt_zero = await tally({}, { dnt: "0" });
  out.eu_no_yes = await tally({}, { "x-vercel-ip-country": "DE" });
  out.eu_yes = await tally({ consent: true }, { "x-vercel-ip-country": "de" });
  out.eu_false = await tally({ consent: false }, { "x-vercel-ip-country": "FR" });
  out.eu_string = await tally({ consent: "true" }, { "x-vercel-ip-country": "GB" });
  out.us = await tally({}, { "x-vercel-ip-country": "US" });
  out.not_json = await tally({}, {}, "not json at all");
  out.too_big = await (async () => {
    const v = visit();
    const body = JSON.stringify({ ...beacon(v), pad: "x".repeat(40000) });
    const got = await askPlans({ method: "POST", query: { op: "tally" }, headers: {}, body });
    return { status: got.status, kept: await kept(v) };
  })();
  out.bad_visit = await (async () => {
    const got = await askPlans({ method: "POST", query: { op: "tally" }, headers: {}, body: beacon("NOT-A-VISIT") });
    return { status: got.status, kept: await kept("NOT-A-VISIT") };
  })();
  out.get = (await askPlans({ method: "GET", query: { op: "tally" }, headers: {} })).status;

  // 2. Whose rows: anything but production is the checks' own; on
  // production, a beacon that says check is, one to any host but the live
  // site's (every deployment is a production one), and a test account's.
  const testOf = async (v) => (await pg.q("select test from public.insights_visits where visit = $1", [v]))[0]?.test ?? null;
  out.preview_test = await testOf(out.plain.v);
  process.env.VERCEL_ENV = "production";
  const prod = await tally();
  const prodCheck = await tally({ check: true });
  const prodCheckFalse = await tally({ check: false });
  const prodCheckString = await tally({ check: "true" });
  const prodPreview = await tally({}, { host: "brickworks-abc1234-xaxis-projects.vercel.app" });
  const prodWww = await tally({}, { host: "www.brickworks.diy" });
  const prodTester = await tally({ bearer: stranger });
  const prodPerson = await tally({ bearer: person });
  out.production = { plain: await testOf(prod.v), check: await testOf(prodCheck.v), check_false: await testOf(prodCheckFalse.v),
    check_string: await testOf(prodCheckString.v), preview_host: await testOf(prodPreview.v), www: await testOf(prodWww.v),
    test_account: await testOf(prodTester.v), person: await testOf(prodPerson.v) };
  delete process.env.VERCEL_ENV;

  // 3. An account: kept only as its hash, the same the console makes, and
  // only from its own sign-in (the bearer), never a beacon's word.
  const signed = await tally({ bearer: person });
  const { accountHash } = await import("../../../api/_analytics.js");
  const row = (await pg.q("select account from public.insights_visits where visit = $1", [signed.v]))[0];
  const accountOfVisit = async (t) => {
    const rows = await pg.q("select account from public.insights_visits where visit = $1", [t.v]);
    return rows.length ? rows[0].account : "no row";
  };
  out.account = { kept: row?.account || null, hash: accountHash(PERSON), length: String(row?.account || "").length,
    bad_who: await accountOfVisit(await tally({ who: "not-a-uuid" })),
    said_who: await accountOfVisit(await tally({ who: PERSON })),
    forged_bearer: await accountOfVisit(await tally({ bearer: `${person.split(".").slice(0, 2).join(".")}.c2lnbmVk` })),
    header_bearer: (await accountOfVisit(await tally({}, { authorization: `Bearer ${person}` }))) === accountHash(PERSON) };

  // 4. A studio visit: tools, a run, a first part and a save.
  const studio = await tally({ about: { landing: "/app", studio: true, device: "desktop", browser: "firefox", lang: "de", last: "tool:paint" },
    bearer: stranger, e: [["studio", "tool", "paint", 3, 4200], ["studio", "run", "simulate", 1, 900, true], ["studio", "part", "placed", 4],
      ["studio", "milestone", "first_part", 1, 15000], ["studio", "save", "model", 1], ["studio", "milestone", "first_save", 1, 42000],
      ["studio", "load", "studio_ui", 1, 6100], ["studio", "frames", "frame_ms", 1, 12.5]],
    seen: ["render_close", "parts_find", "made_up_control"] });
  out.studio_rows = await pg.q("select kind, name, n, ms, ok from public.insights_events where visit = $1 order by kind, name", [studio.v]);

  // 5. The owner's read, and nobody else's.
  out.read_signed_out = (await askAdmin({ method: "GET", query: { op: "analytics", tests: "1" }, headers: { host: "brickworks.diy" } })).status;
  out.read_stranger = (await askAdmin({ method: "GET", query: { op: "analytics", tests: "1" },
    headers: { host: "brickworks.diy", authorization: `Bearer ${stranger}` } })).status;
  const read = await askAdmin({ method: "GET", query: { op: "analytics", tests: "1" },
    headers: { host: "brickworks.diy", authorization: `Bearer ${owner}` } });
  const r = read.json || {};
  out.read = { status: read.status, ready: r.ready, tests: r.tests, hashed: r.hashed, accounts: r.accounts, filters: r.filters,
    today: r.days?.at(-1), funnel: r.funnel, tools: (r.used || []).filter((u) => u.kind === "tool"),
    runs: (r.used || []).filter((u) => u.kind === "run"), seen: (r.seen || []).map((s) => s.name), retention: r.retention,
    speed: r.speed };
  out.read_accounts_sent = sent.filter((one) => one.fn === "insights_read").at(-1)?.body?.p_accounts?.map((a) => ({ plan: a.plan,
    hashed: a.h === accountHash(a.id) }));
  const phone = await askAdmin({ method: "GET", query: { op: "analytics", tests: "1", device: "phone", plan: "all", signed: "yes" },
    headers: { host: "brickworks.diy", authorization: `Bearer ${owner}` } });
  out.read_phone = { status: phone.status, filters: phone.json?.filters, visits: phone.json?.days?.at(-1)?.visits };
  const bad = await askAdmin({ method: "GET", query: { op: "analytics", tests: "1", from: "2026-11-10", to: "2026-11-01" },
    headers: { host: "brickworks.diy", authorization: `Bearer ${owner}` } });
  out.read_backwards = { status: bad.status, error: bad.json?.error };
  const long = await askAdmin({ method: "GET", query: { op: "analytics", tests: "1", from: "2024-01-01", to: "2026-11-01" },
    headers: { host: "brickworks.diy", authorization: `Bearer ${owner}` } });
  out.read_too_long = long.status;

  // 6. The cron: Vercel's alone, and it rolls only days that are over.
  out.cron_anyone = (await askPlans({ method: "GET", query: { op: "tally_daily" }, headers: {} })).status;
  await pg.q("update public.insights_events set day = day - 1, at = at - interval '1 day'");
  await pg.q("update public.insights_visits set day = day - 1, first_at = first_at - interval '1 day', last_at = last_at - interval '1 day'");
  const cron = await askPlans({ method: "GET", query: { op: "tally_daily" }, headers: { authorization: "Bearer cron-check-secret" } });
  out.cron = { status: cron.status, rolled: cron.json?.rolled?.length, gone: cron.json?.accounts_gone };
  out.cron_plans_sent = Object.values(sent.filter((one) => one.fn === "insights_rollup").at(-1)?.body?.p_plans || {}).sort();
  out.cron_listed = sent.filter((one) => one.fn === "insights_gone").at(-1)?.body?.p_listed;
  const again = await askPlans({ method: "GET", query: { op: "tally_daily" }, headers: { authorization: "Bearer cron-check-secret" } });
  out.cron_again = { status: again.status, rolled: again.json?.rolled?.length };

  // After the read and the cron, so no count above moves. Every field sent as false (or null) is taken as absent (self_attack):
  // a false bearer is no account, a false seen no names, a false seconds 0,
  // a false first no first visit, and the row is the plain one's.
  out.false_fields = await (async () => {
    const t = await tally({ bearer: false, seen: false, seconds: false, first: false, check: false, consent: false,
      who: false, about: { landing: "/gallery", channel: "direct", device: "desktop", browser: "chrome", os: "linux",
        lang: "en", first: false } });
    const nulls = await tally({ bearer: null, seen: null, seconds: null, first: null, check: null });
    const rows = await pg.q("select visit, account, seconds, test from public.insights_visits where visit = any($1) order by visit",
      [[t.v, nulls.v]]);
    return { status: [t.status, nulls.status], rows: rows.map((r) => ({ account: r.account, seconds: r.seconds, test: r.test })) };
  })();

  // 7. Every row as text: no address, no IP, no account id, no email.
  const dump = JSON.stringify(await pg.q("select (select json_agg(v) from public.insights_visits v) as v, "
    + "(select json_agg(e) from public.insights_events e) as e, (select json_agg(d) from public.insights_days d) as d, "
    + "(select json_agg(a) from public.insights_account_days a) as a, (select json_agg(f) from public.insights_account_firsts f) as f"));
  out.leaks = [OWNER, ADA, PERSON, "@", "resend.dev", "example.org", "93.184", "brickworks.diy", person.slice(0, 40)]
    .filter((word) => dump.includes(word));
  out.answers_leak = [OWNER, ADA, PERSON, "ada@resend.dev", "grace@example.org"].filter((word) => JSON.stringify(read.json).includes(word));
  out.logged = logged.filter((line) => /tally/.test(line));
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 1500);
} finally {
  await pg.stop();
}

// 8. Tool calls through the connector (api/mcp.js), in the relay's own
// world: each counted once. The relay's own tool (tabs) by the account's
// hash, whether it went not told; a call the relay stopped on (this world
// keeps no relay row) as failed, its account not known there.
try {
  const { world: relayWorld } = await import("../relay/world.mjs");
  const w = relayWorld();
  const token = w.connect(ADA);
  w.tab({ owner: ADA, hello: { instructions: "", tools: [{ name: "look_at_model", inputSchema: { type: "object" } }] } });
  const answer = await w.ask(token, "tools/call", { name: "look_at_model", arguments: {} });
  const tabs = await w.ask(token, "tools/call", { name: "tabs", arguments: {} });
  const listed = await w.ask(token, "tools/list");
  const { accountHash } = await import("../../../api/_analytics.js");
  const counted = w.written.filter((one) => one.table === "rpc/insights_call");
  out.mcp = { stopped: Boolean(answer?.error), tabs: tabs?.result?.isError === false, counted: counted.map((one) => ({ tool: one.body.p_tool, ok: one.body.p_ok,
    timed: Number.isFinite(one.body.p_ms), mine: one.body.p_account === accountHash(ADA), none: one.body.p_account === null })),
    listed: Boolean(listed?.result) };
} catch (trouble) {
  out.mcp_error = String(trouble?.stack || trouble).slice(0, 1500);
}
print(JSON.stringify(out));
process.exit(0);
