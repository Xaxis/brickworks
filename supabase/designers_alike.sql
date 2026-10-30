-- More like a designer, 2026-10-30 (docs/SOCIAL.md section 7, item 9).
--
-- A person's page shows up to six designers whose work is closest to
-- theirs, each with Follow in place (api/_alike.js). The API reads the
-- themes and the tags of their models itself. Two things it cannot,
-- because only this database's functions may read their tables:
--
--   parts    of the parts either of two designers uses (colours aside), in
--            every model each has in the gallery in their own name, the
--            share both use: how many both use over how many either uses
--            (model_needs, discovery.sql)
--   common   how many of the designer's followers follow the other one too
--            (follows, follows.sql), counted only for followers shown in
--            public, as follow_state counts them
--
--   designers_alike(wanted, tests)   for the designer [wanted], each other
--            designer with a part or a follower in common, as (account,
--            parts, common): the most parts in common first, at most 200.
--            A model counts while the gallery shows it: published, listed,
--            not taken out, in its owner's own name, its owner not taken
--            out, and a test model only with [tests].
--
-- Who follows whom is never answered here, only how many, and only to
-- order a list; nobody's followers are listed (docs/SOCIAL.md D1). The
-- API shows only designers that may be followed, never whoever asks nor
-- anybody they follow.
--
-- Only an addition, applied after discovery.sql and follows.sql: one new
-- function, security definer and granted to the service role alone, as the
-- tables it reads are. No table, row or function of before is changed,
-- nothing dropped or renamed.
--
--   node tools/apply_sql.mjs supabase/designers_alike.sql --dry --try=tools/designers_alike_try.sql

create or replace function public.designers_alike(wanted uuid, tests boolean default false)
returns table (account uuid, parts numeric, common integer)
language sql
stable
security definer
set search_path = public
as $$
    with shown as (
        select m.id, m.owner
          from public.shared_models m
         where m.published and m.listed and not m.barred and m.author is not null
           and (tests or not m.test)
           and not exists (select 1 from public.barred_accounts b where b.account = m.owner)),
    used as (
        select distinct s.owner, n.part
          from shown s
          join public.model_needs n on n.model = s.id),
    theirs as (
        select u.part from used u where u.owner = wanted),
    sizes as (
        select u.owner, count(*) as n from used u where u.owner <> wanted group by u.owner),
    both_use as (
        select u.owner, count(*) as n
          from used u
          join theirs t on t.part = u.part
         where u.owner <> wanted
         group by u.owner),
    fans as (
        select f.follower
          from public.follows f
         where f.followed = wanted and public.shown_publicly(f.follower)),
    followed_too as (
        select f.followed as owner, count(*)::integer as n
          from public.follows f
          join fans on fans.follower = f.follower
         where f.followed <> wanted
           and f.followed in (select s.owner from shown s)
         group by f.followed),
    alike as (
        select b.owner, b.n::numeric / nullif((select count(*) from theirs) + z.n - b.n, 0) as share
          from both_use b
          join sizes z on z.owner = b.owner)
    select coalesce(a.owner, f.owner), coalesce(a.share, 0), coalesce(f.n, 0)
      from alike a
      full join followed_too f on f.owner = a.owner
     order by 2 desc, 3 desc, 1
     limit 200
$$;

revoke all on function public.designers_alike(uuid, boolean) from public, anon, authenticated;
grant execute on function public.designers_alike(uuid, boolean) to service_role;
