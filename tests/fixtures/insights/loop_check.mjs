// supabase/loop_funnel.sql's insights_loop on a fixture of known rows, in
// pg.mjs's Postgres after the files it reads: what tests/test_loop.py asks
// of it (loopmetrics, 2026-11-23; docs/ANALYTICS.md "The loop").
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/insights/loop_check.mjs [--load=N] [--card=FILE]
//
// --card=FILE keeps the owner's whole ?op=loop answer in FILE, the card's
// numbers for tools/web/loop_card_check.mjs.
//
// The fixture: twelve people of this week, two stopped at each step of the
// loop, two of them back within the week (one through Claude), one of those
// on a second day; a visit that never reached the loop; three person-days
// of the week before; the owner; the checks' own rows, a check's account and
// the test pool's likes, follows and comments on people's models mixed in;
// a sampled visit. Then the same read at a load of 30 days of a busy site,
// timed over 90 days. The social tables stand in with the live columns the
// function reads (supabase/shared_models.sql, people.sql, comments.sql,
// replies.sql, follows.sql, builds.sql, talk.sql, challenges.sql).
//
// Prints one JSON object, each finding by name.
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS } from "../console/needs2.mjs";

createRequire(import.meta.url)(process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js").types.setTypeParser(1082, (v) => v);
const SQLS = ["supabase/analytics.sql", "supabase/analytics2.sql", "supabase/loop_funnel.sql"];
const db = await startPostgres({ also: [...NEEDS, "supabase/console2.sql", "supabase/social.sql", ...SQLS] });
const { LOOP } = await import("../../../api/_loop.js");
const rpc = async (name, args = {}) => {
  const names = Object.keys(args);
  const values = names.map((key) => (args[key] !== null && typeof args[key] === "object" ? JSON.stringify(args[key]) : args[key]));
  const rows = await db.q(`select public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`, values);
  return rows[0].answer;
};
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

const DAY = 86400000;
const iso = (ms) => new Date(ms).toISOString().slice(0, 10);
const TODAY = iso(Date.now());
/// The day [n] days before today, and a time on it.
const T = (n) => iso(Date.parse(`${TODAY}T00:00:00Z`) - n * DAY);
const at = (n, hour = 12) => `${T(n)}T${String(hour).padStart(2, "0")}:00:00Z`;

const out = {};
try {
  for (const SQL of SQLS) await db.q(readFileSync(new URL(`../../../${SQL}`, import.meta.url), "utf8"));
  out.again = "ok";
  // The social tables, with the live columns the loop reads.
  await db.q(`
    alter table public.shared_models add column if not exists published boolean not null default true,
      add column if not exists created_at timestamptz not null default now();
    create table public.share_publishes (id bigserial primary key, owner uuid not null references auth.users (id), at timestamptz not null default now());
    create table public.model_likes (model text not null, account uuid not null references auth.users (id), at timestamptz not null default now(),
      primary key (model, account));
    create table public.model_comments (id bigserial primary key, model text not null, version integer not null default 1,
      author uuid not null references auth.users (id), body text not null default 'words', at timestamptz not null default now(),
      removed_at timestamptz, removed_by text, parent bigint references public.model_comments (id));
    create table public.follows (follower uuid not null references auth.users (id), followed uuid not null references auth.users (id),
      at timestamptz not null default now(), primary key (follower, followed));
    create table public.model_builds (model text not null, device text not null, at timestamptz not null default now(),
      primary key (model, device));
    create table public.build_photos (id text primary key, model text not null, account uuid not null references auth.users (id),
      at timestamptz not null default now(), removed_at timestamptz);
    create table public.talk_threads (id bigserial primary key, board text not null default 'show', title text not null default 'A title',
      author uuid not null references auth.users (id), at timestamptz not null default now(), test boolean not null default false);
    create table public.talk_posts (id bigserial primary key, thread bigint not null references public.talk_threads (id),
      author uuid not null references auth.users (id), body text not null default 'words', first boolean not null default false,
      answers bigint references public.talk_posts (id), at timestamptz not null default now(), removed_at timestamptz, removed_by text);
    create table public.challenge_entries (challenge bigint not null, model text not null, owner uuid not null references auth.users (id),
      way text not null default 'hand', at timestamptz not null default now(), primary key (challenge, model));`);

  // Nobody but the server runs it.
  const call = "select public.insights_loop(current_date - 6, current_date, false, '{}', '[]', '[]')";
  out.roles = { anon: await as("anon", call), signed_in: await as("authenticated", call), server: await as("service_role", call) };

  // The accounts: twelve people's (a..), the owner, a check's account and
  // the test pool's (@resend.dev, listed only on the checks' read).
  const ids = {};
  const hash = {};
  const names = ["a2", "a4", "a5", "a7", "a8", "a9", "a10", "a11", "a12", "owner", "check", "pool"];
  for (const [n, name] of names.entries()) {
    ids[name] = await db.user(name === "check" || name === "pool" ? `${name}@resend.dev` : `${name}@example.org`);
    hash[name] = `${String(n + 1).padStart(2, "0")}${"c".repeat(22)}`;
  }
  const plan = { a4: "tester", owner: "owner" };
  const account = (name) => ({ h: hash[name], id: ids[name], plan: plan[name] || "free" });
  const PEOPLE = names.filter((name) => name !== "check" && name !== "pool").map(account);
  const CHECKS = ["check", "pool"].map(account);

  // A visit and its rows on a day: [surface, kind, name] each.
  let vn = 0;
  async function visit(day, who, rows, { test = false, device = "desktop", lang = "en", weight = 1 } = {}) {
    vn += 1;
    const v = `v${String(vn).padStart(15, "0")}`;
    await db.q(`insert into public.insights_visits (visit, day, first_at, last_at, test, account, device, lang, weight)
                values ($1, $2, $3, $3, $4, $5, $6, $7, $8)`, [v, T(day), at(day), test, who ? hash[who] : null, device, lang, weight]);
    for (const [surface, kind, name] of rows) {
      await db.q(`insert into public.insights_events (visit, at, day, test, surface, kind, name) values ($1, $2, $3, $4, $5, $6, $7)`,
        [v, at(day), T(day), test, surface, kind, name]);
    }
    return v;
  }
  const view = (name) => ["site", "view", name];
  const app = ["studio", "view", "/app"];
  const placed = ["studio", "part", "placed"];
  const model = async (id, owner) => db.q("insert into public.shared_models (id, owner) values ($1, $2)", [id, ids[owner]]);

  // This week (today - 6 to today), each person stopped at a known step.
  await visit(2, null, [view("/privacy")]); // N1: never reached the loop
  await visit(1, null, [view("/gallery")], { device: "phone" }); // S1: discovered
  await visit(3, "a2", [view("/"), view("/privacy")]); // S2: discovered
  await visit(2, null, [view("/library/set/:n"), view("/m/:id")]); // S3: opened
  await visit(1, "a4", [app]); // S4: opened (the studio, not a page that discovers)
  await visit(2, "a5", [app, placed, ["studio", "milestone", "first_part"]]); // S5: changed
  await visit(4, null, [view("/m/:id"), app, placed]); // S6: changed
  await visit(2, "a7", [view("/m/:id"), ["site", "act", "people.comment"]]); // S7: shared (a comment on a9's model)
  await visit(2, "a8", [app, placed]); // S8: shared (published from the studio: a kept row only)
  await visit(4, "a9", [view("/gallery")]); // S9: heard back (a comment, two builds)
  await visit(5, "a10", [view("/m/:id"), ["site", "act", "people.talk_start"]]); // S10: heard back (a reply in its thread)
  await visit(6, "a11", [view("/gallery"), placed]); // S11: came back three days later...
  await visit(3, "a11", [view("/")]); // ...and that day it went no further
  await visit(5, "a12", [view("/")]); // S12: came back through Claude
  await db.q("insert into public.relay_call_days (owner, day, calls) values ($1, $2, 3)", [ids.a12, T(1)]);
  await visit(2, "owner", [view("/gallery"), app, placed]); // the owner: left out unless asked

  // What they shared and heard back, as the social tables keep it.
  await model("M8aaaaaaaa", "a8");
  await model("M9aaaaaaaa", "a9");
  await model("MCaaaaaaaa", "check");
  await db.q("insert into public.share_publishes (owner, at) values ($1, $2)", [ids.a8, at(2)]);
  await db.q("insert into public.model_comments (model, author, at) values ('M9aaaaaaaa', $1, $2)", [ids.a7, at(2)]);
  await db.q("insert into public.model_builds (model, device, at) values ('M9aaaaaaaa', $1, $2), ('M9aaaaaaaa', $3, $4)",
    ["1".repeat(32), at(3), "2".repeat(32), at(1)]);
  const thread = await db.one("insert into public.talk_threads (author, at) values ($1, $2) returning id", [ids.a10, at(5)]);
  await db.q("insert into public.talk_posts (thread, author, first, at) values ($1, $2, true, $3)", [thread, ids.a10, at(5, 10)]);
  // a2 answers in a10's thread on a day a2 was not counted: a10 heard back; a2's post is no share of a counted day.
  await db.q("insert into public.talk_posts (thread, author, at) values ($1, $2, $3)", [thread, ids.a2, at(5, 14)]);
  // Never counted: a8 liking its own model; the test pool liking a8's model,
  // following a7, and commenting on a8's model; a reply in a10's thread by
  // the pool; a comment the owner took down.
  await db.q("insert into public.model_likes (model, account, at) values ('M8aaaaaaaa', $1, $2), ('M8aaaaaaaa', $3, $2)",
    [ids.a8, at(1), ids.pool]);
  await db.q("insert into public.follows (follower, followed, at) values ($1, $2, $3)", [ids.pool, ids.a7, at(1)]);
  await db.q("insert into public.model_comments (model, author, at) values ('M8aaaaaaaa', $1, $2)", [ids.check, at(2)]);
  await db.q("insert into public.model_comments (model, author, at, removed_at, removed_by) values ('M8aaaaaaaa', $1, $2, $2, 'admin')",
    [ids.a2, at(2)]);
  await db.q("insert into public.talk_posts (thread, author, at) values ($1, $2, $3)", [thread, ids.pool, at(4)]);
  // A check's build of its own account's model: not people's.
  await db.q("insert into public.model_builds (model, device, at) values ('MCaaaaaaaa', $1, $2)", ["3".repeat(32), at(2)]);

  // The checks' own rows: a check's account doing everything, a check's visit.
  await visit(2, "check", [view("/gallery"), app, placed, ["site", "act", "people.comment"]], { test: true });
  await visit(1, null, [view("/gallery")], { test: true });

  // The week before (today - 13 to today - 7).
  await visit(8, "a5", [view("/gallery"), view("/m/:id")]); // B1: back within 7 days (a5 on today - 2)
  await visit(10, null, [view("/")]); // B2: discovered
  await visit(13, "a4", [app]); // B3: back within 30 days, not 7 (a4 on today - 1)
  await db.q("insert into public.model_builds (model, device, at) values ('M9aaaaaaaa', $1, $2)", ["4".repeat(32), at(9)]);

  // A busy day's sampled visit, a weight of 8, on a tablet, long before.
  await visit(20, null, [view("/gallery")], { device: "tablet", weight: 8 });

  const read = (from, to, { tests = false, filters = { plan: "!owner" }, accounts = tests ? CHECKS : PEOPLE } = {}) =>
    rpc("insights_loop", { p_from: T(from), p_to: T(to), p_tests: tests, p_filters: filters, p_accounts: accounts, p_steps: LOOP });
  out.week = await read(6, 0);
  out.everyone = await read(6, 0, { filters: {} });
  out.owner_only = await read(6, 0, { filters: { plan: "owner" } });
  out.testers = await read(6, 0, { filters: { plan: "tester" } });
  out.signed_out = await read(6, 0, { filters: { plan: "!owner", signed: false } });
  out.phone = await read(6, 0, { filters: { plan: "!owner", device: "phone" } });
  out.checks = await read(6, 0, { tests: true, filters: {} });
  out.sampled = await read(20, 20);
  // With no VIEW_SECRET the server knows no account's hash, only its id.
  out.unhashed = await read(6, 0, { accounts: PEOPLE.map(({ id, plan: p }) => ({ h: null, id, plan: p })) });
  // A step named by nothing the table has is not a step; a made-up step is let go.
  out.made_up = await rpc("insights_loop", { p_from: T(6), p_to: T(0), p_tests: false, p_filters: {}, p_accounts: PEOPLE,
    p_steps: [["discovered", "site", "view", "/gallery"], ["teleported", "site", "view", "/"], ["shared", "site", "view", "Bad Name"]] });
  out.too_long = await rpc("insights_loop", { p_from: T(500), p_to: T(0), p_tests: false, p_filters: {}, p_accounts: [], p_steps: [] })
    .then(() => "answered", (trouble) => String(trouble.message));
  // It writes nothing that outlives its transaction.
  out.tables_after = Number(await db.one("select count(*) from pg_tables where tablename like 'loop\\_%'"));

  // The console's op (api/admin.js ?op=loop, api/_loop.js) over the same
  // rows: the owner's alone, the accounts hashed as the server hashes them,
  // and the same numbers as the function's own.
  {
    const { SUPABASE_URL, askAdmin, world } = await import("../billing/world.mjs");
    const { accountHash } = await import("../../../api/_analytics.js");
    const w = await world({ master: "owner@example.org" });
    process.env.VIEW_SECRET = "loop-check-secret";
    for (const name of names) {
      await db.q("update public.insights_visits set account = $1 where account = $2", [accountHash(ids[name]), hash[name]]);
    }
    const users = await db.q("select id::text as id, email, created_at from auth.users order by email");
    const sent = [];
    const worldFetch = globalThis.fetch;
    globalThis.fetch = async (input, init = {}) => {
      const url = new URL(String(input));
      if (url.origin === SUPABASE_URL && url.pathname === "/rest/v1/rpc/insights_loop") {
        const body = JSON.parse(String(init.body || "{}"));
        sent.push(body);
        try {
          return new Response(JSON.stringify(await rpc("insights_loop", body)), { status: 200 });
        } catch (trouble) {
          // PostgREST answers 404 for a function the database does not have.
          const status = /does not exist/.test(String(trouble.message)) ? 404 : 400;
          return new Response(JSON.stringify({ message: String(trouble.message) }), { status });
        }
      }
      if (url.origin === SUPABASE_URL && url.pathname === "/auth/v1/admin/users") {
        return new Response(JSON.stringify({ users }), { status: 200 });
      }
      return worldFetch(input, init);
    };
    const owner = await w.signIn({ sub: ids.owner, email: "owner@example.org" });
    const stranger = await w.signIn({ sub: ids.a7, email: "a7@example.org" });
    const ask = (token, query = {}) => askAdmin({ method: "GET", query: { op: "loop", from: T(6), to: T(0), ...query },
      headers: { host: "brickworks.diy", ...(token ? { authorization: `Bearer ${token}` } : {}) } });
    out.api_signed_out = (await ask(null)).status;
    out.api_stranger = (await ask(stranger)).status;
    const mine = await ask(owner);
    const cardFile = (process.argv.find((a) => a.startsWith("--card=")) || "").slice(7);
    if (cardFile) writeFileSync(cardFile, `${JSON.stringify(mine.json)}\n`);
    out.api = { status: mine.status, ready: mine.json?.ready, hashed: mine.json?.hashed, accounts: mine.json?.accounts,
      filters: mine.json?.filters, this: mine.json?.this, before: mine.json?.before };
    out.api_sent = { steps: sent.at(-1)?.p_steps?.length, accounts: sent.at(-1)?.p_accounts?.length,
      hashed: (sent.at(-1)?.p_accounts || []).every((a) => a.h === accountHash(a.id)),
      plans: Object.fromEntries((sent.at(-1)?.p_accounts || []).map((a) => [names.find((n) => ids[n] === a.id), a.plan])) };
    const checks = await ask(owner, { tests: "1", plan: "all" });
    out.api_checks = { status: checks.status, people: checks.json?.this?.people, accounts: checks.json?.accounts };
    out.api_backwards = (await ask(owner, { from: T(0), to: T(6) })).status;
    // Before supabase/loop_funnel.sql is applied the op says so.
    await db.q("alter function public.insights_loop(date, date, boolean, jsonb, jsonb, jsonb) rename to insights_loop_away");
    const away = await ask(owner);
    out.api_before_sql = { status: away.status, ready: away.json?.ready };
    await db.q("alter function public.insights_loop_away(date, date, boolean, jsonb, jsonb, jsonb) rename to insights_loop");
    globalThis.fetch = worldFetch;
  }

  // At a busy site's load (--load=500: docs/ANALYTICS.md's 500 visits a
  // day): 30 days of them, about 28 rows a visit, a third signed in, with
  // publishes; then the read over 90 days, timed three times.
  const LOAD = Number((process.argv.find((a) => a.startsWith("--load=")) || "--load=0").slice(7));
  if (LOAD > 0) {
  await db.q(`
    insert into auth.users (id, email) select ('00000000-0000-4000-9000-' || lpad(g::text, 12, '0'))::uuid, 'p' || g || '@example.org'
      from generate_series(1, 3000) g;
    insert into public.insights_visits (visit, day, first_at, last_at, test, account, device, lang)
    select 'z' || lpad((d * 1000 + n)::text, 15, '0'), current_date - d, now() - d * interval '1 day', now() - d * interval '1 day', false,
           case when n % 3 = 0 then lpad(to_hex((n * 7 + d) % 3000), 4, '0') || repeat('d', 20) end,
           (array['desktop', 'phone', 'tablet'])[1 + n % 3], 'en'
      from generate_series(0, 29) d, generate_series(1, ${LOAD}) n;
    insert into public.insights_events (visit, at, day, test, surface, kind, name)
    select v.visit, v.first_at, v.day, false, x.surface, x.kind, x.name
      from public.insights_visits v
      cross join lateral (select * from (values ('site', 'view', '/gallery'), ('site', 'view', '/m/:id'), ('site', 'view', '/'),
               ('studio', 'view', '/app'), ('studio', 'part', 'placed'), ('studio', 'tool', 'move'), ('studio', 'press', 'menu_file'),
               ('site', 'act', 'people.like'), ('site', 'load', 'site_lcp'), ('studio', 'panel', 'parts')) as e(surface, kind, name)
               , generate_series(1, 1 + (hashtext(v.visit) & 7)) r
              where (hashtext(v.visit || e.name) & 7) < 5) x
     where v.visit like 'z%';
    insert into public.share_publishes (owner, at)
    select ('00000000-0000-4000-9000-' || lpad((1 + g % 3000)::text, 12, '0'))::uuid, now() - (g % 30) * interval '1 day'
      from generate_series(1, 2000) g;
    analyze public.insights_events; analyze public.insights_visits; analyze public.share_publishes;`);
  out.load = {
    events: Number(await db.one("select count(*) from public.insights_events")),
    visits: Number(await db.one("select count(*) from public.insights_visits")),
  };
  const many = [];
  for (let n = 0; n < 3000; n += 1) {
    many.push({ h: `${n.toString(16).padStart(4, "0")}${"d".repeat(20)}`, id: `00000000-0000-4000-9000-${String(n + 1).padStart(12, "0")}`,
      plan: "free" });
  }
  const ms = [];
  for (let n = 0; n < 3; n += 1) {
    const began = performance.now();
    const got = await rpc("insights_loop", { p_from: T(89), p_to: T(0), p_tests: false, p_filters: { plan: "!owner" },
      p_accounts: [...PEOPLE, ...many], p_steps: LOOP });
    ms.push(Math.round(performance.now() - began));
    out.load.people = got.this.people;
  }
  out.load.ms = ms;
  }
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 2000);
} finally {
  await db.stop();
}
process.stdout.write(`${JSON.stringify(out)}\n`);
