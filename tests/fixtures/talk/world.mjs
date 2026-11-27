// supabase/talk.sql in a test's Postgres (tests/fixtures/beta/pg.mjs), for
// the local server's stand-in (tools/web/talk_stand_in.mjs): the file
// itself answers, as PostgREST calls it.
//
// Under it, the console's own files (console3.sql: the audit Talk's acts
// are written to), then what talk.sql reads of the project, each with the
// columns it reads and nothing more: the people and their age answer, the
// models, the challenges, the comments under models, the blocks, and the
// trust, moderation, block and feed functions it calls, as those files
// write them. The stand-in copies into them what the project holds.
// notification_rows, which talk.sql writes again with every kind the page
// has, reads tables this world does not hold: it is made unchecked and
// never run here; tools/talk_try.sql runs it on the project's own, rolled
// back.
import { readFileSync } from "node:fs";
import { startPostgres } from "../beta/pg.mjs";
import { NEEDS3, STAND_INS } from "../console/needs3.mjs";

export const NEEDS = `
  alter table public.shared_models drop constraint if exists shared_models_owner_fkey;
  alter table public.shared_models add column if not exists name text,
    add column if not exists published boolean not null default true,
    add column if not exists barred boolean not null default false,
    add column if not exists listed boolean not null default false,
    add column if not exists test boolean not null default false,
    add column if not exists has_image boolean not null default false,
    add column if not exists has_thumb boolean not null default false,
    add column if not exists updated_at timestamptz;
  create unique index if not exists shared_models_id on public.shared_models (id);
  create table if not exists public.profiles (id uuid primary key, over_13 boolean);
  create table if not exists public.barred_accounts (account uuid primary key, at timestamptz not null default now(), reason text);
  create table if not exists public.blocks (blocker uuid not null, blocked uuid not null, at timestamptz not null default now(),
    primary key (blocker, blocked));
  create table if not exists public.share_versions (model text not null, n integer not null default 1, at timestamptz not null default now());
  create table if not exists public.challenges (id bigint primary key, title text not null, brief text, starts_on date, ends_on date,
    test boolean not null default false, ended_at timestamptz, announced_at timestamptz);
  create table if not exists public.model_comments (id bigint primary key, model text, author uuid, parent bigint, version integer,
    step integer, body text, at timestamptz not null default now(), removed_at timestamptz, hidden_at timestamptz);
  create table if not exists public.acts_held (actor text not null, act text not null, at timestamptz not null default now());
  -- A set's versions (alt_builds.sql's model_alt_sets, set_versions.sql), for set_asks.sql: whose they are.
  alter table public.shared_models add column if not exists listed_at timestamptz,
    add column if not exists wip_at timestamptz,
    add column if not exists created_at timestamptz not null default now();
  alter table public.share_versions add column if not exists steps integer;
  create table if not exists public.model_alt_sets (model text not null, set_number text not null, role text not null,
    n smallint not null default 0, have integer not null default 0, primary key (model, set_number));
  -- wip.sql's, as production has it.
  create or replace function public.gallery_shows(m public.shared_models, tests boolean) returns boolean language sql stable as $$
    select m.published and m.listed and not m.barred and m.wip_at is null
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
       and (not m.test or coalesce(tests, false)) $$;

  -- moderation.sql's, trust.sql's, block.sql's and follows.sql's, as they write them.
  create or replace function public.is_barred(account uuid) returns boolean language sql stable as $$
    select exists (select 1 from public.barred_accounts b where b.account = is_barred.account) $$;
  create or replace function public.trust_kept_private(account uuid) returns boolean language sql stable as $$
    select coalesce((select not p.over_13 from public.profiles p where p.id = account), false) $$;
  create or replace function public.shown_publicly(account uuid) returns boolean language sql stable as $$
    select not public.is_barred(account) and not public.trust_kept_private(account) $$;
  create or replace function public.trust_is_test_account(account uuid) returns boolean language sql stable as $$
    select coalesce((select u.email ~* '@resend\\.dev$' from auth.users u where u.id = account), false) $$;
  create or replace function public.trust_may_go_public(account uuid) returns boolean language sql stable as $$
    select coalesce((select p.over_13 from public.profiles p where p.id = account), false) $$;
  create or replace function public.feed_who(account uuid) returns jsonb language sql stable as $$
    select jsonb_build_object('handle', p.handle, 'name', p.name) from public.people p
     where p.account = feed_who.account and public.shown_publicly(account) $$;
  create or replace function public.block_between(account uuid, other uuid) returns text language sql stable as $$
    select case
        when block_between.account is null or block_between.other is null or block_between.account = block_between.other then null
        when exists (select 1 from public.blocks k where k.blocker = block_between.account and k.blocked = block_between.other) then 'blocked'
        when exists (select 1 from public.blocks k where k.blocker = block_between.other and k.blocked = block_between.account) then 'blocked_by'
        end $$;
  -- moderation.sql's limit: [per_hour] in the last hour, [per_day] in the last day, counted as it is asked.
  create or replace function public.may_act(actor text, act text, per_hour integer, per_day integer) returns boolean
  language plpgsql as $$
  begin
    if (select count(*) from public.acts_held a where a.actor = may_act.actor and a.act = may_act.act
         and a.at > now() - interval '1 hour') >= per_hour
       or (select count(*) from public.acts_held a where a.actor = may_act.actor and a.act = may_act.act
         and a.at > now() - interval '1 day') >= per_day then
      return false;
    end if;
    insert into public.acts_held (actor, act) values (may_act.actor, may_act.act);
    return true;
  end $$;
`;

const file = (name) => readFileSync(new URL(`../../../${name}`, import.meta.url), "utf8");

/// The world: pg.mjs's, with db.call(name, args) answering any public
/// function as PostgREST does, each call on a connection of a small pool
/// so two at once run at once.
export async function talkWorld() {
  const db = await startPostgres({ also: NEEDS3 });
  await db.q(STAND_INS);
  await db.q(file("supabase/console3.sql"));
  await db.q(NEEDS);
  await db.q("set check_function_bodies = off");
  await db.q(file("supabase/talk.sql"));
  // Ask the builders: comment_pins.sql's pin_shaped, then the file itself.
  const pinShaped = /create or replace function public\.pin_shaped[\s\S]*?\n\$\$;\n/.exec(file("supabase/comment_pins.sql"))[0];
  await db.q(pinShaped);
  await db.q(file("supabase/talk_asks.sql"));
  // And on a set's page (hubask): its versions' builders told.
  await db.q(file("supabase/set_asks.sql"));
  // Round two (talk2): pages, what is new, views and answers.
  await db.q(file("supabase/talk2.sql"));
  await db.q("set check_function_bodies = on");
  const pool = [];
  for (let at = 0; at < 4; at += 1) pool.push(await db.connect());
  let next = 0;
  db.call = async (name, args = {}) => {
    const names = Object.keys(args || {});
    if (!/^[a-z][a-z0-9_]*$/.test(name) || names.some((key) => !/^[a-z_]+$/.test(key))) throw new Error(`rpc ${name}`);
    // An object, or an array of objects (an ask's parts), is jsonb as
    // PostgREST sends it; an array of numbers a Postgres array.
    const values = names.map((key) => (args[key] !== null && typeof args[key] === "object"
      && (!Array.isArray(args[key]) || args[key].some((one) => one !== null && typeof one === "object"))
      ? JSON.stringify(args[key]) : args[key]));
    const client = pool[next++ % pool.length];
    const rows = (await client.query(`select * from public.${name}(${names.map((key, at) => `${key} => $${at + 1}`).join(", ")}) as answer`,
      values)).rows;
    const [{ set }] = (await client.query("select bool_or(proretset) as set from pg_proc where proname = $1", [name])).rows;
    const plain = rows.every((row) => Object.keys(row).length === 1 && "answer" in row);
    if (!set && rows.length === 1 && plain) return JSON.parse(JSON.stringify(rows[0].answer));
    return JSON.parse(JSON.stringify(plain ? rows.map((row) => row.answer) : rows));
  };
  const stop = db.stop;
  db.stop = async () => {
    for (const client of pool) await client.end().catch(() => {});
    await stop();
  };
  return db;
}
