-- Discovery, 2026-10-19: a gallery that rewards designs that build.
--
-- The gallery sorted by newest, views, likes, remixes and builds, and a
-- model that people had built to its last step looked no different from
-- one people only looked at, unless somebody chose Most built. Now three
-- things put the designs that build in front:
--
--   Top builds   a sort by a score, worked out here so the gallery pages
--                by it: a build finished counts 3, a remix 2, and the
--                Tested mark 5 (gallery_score). Views count for nothing:
--                a model nobody built is not lifted by being looked at.
--                Ties go to more builds, then the newest.
--   This week's pick   one model, worked out from the past seven days:
--                the best score of the week, counting the builds finished
--                and the remixes listed in those seven days, and the
--                Tested mark (gallery_week). A model is a candidate when
--                something in the week says it builds: a build finished,
--                a remix listed, or it was listed that week and is
--                Tested. The site's owner may choose one instead, for up
--                to 31 days, from the admin page (gallery_picks); the
--                newest choice still in the gallery wins, and ending it
--                goes back to the worked-out one.
--   Small builds   a shelf of the gallery's Small size, under 200 parts
--                (api/_directory.js SIZES, the Size filter's own line), by
--                Top builds. Nothing here: directory_models already
--                filters by parts.
--   Build with what I own   for a signed-in person with a collection,
--                each model's share of its parts they own, by part and
--                colour (owned, below): on every card, a sort by it, and a
--                shelf of what they can build now. Both sides are counted
--                once and kept, so the gallery asks one join and never
--                reads a file: a model's needs when it is published
--                (model_needs), a person's parts, their loose ones and
--                their sets through the sets' inventories, when the
--                collection is kept (collection_pools), each spelled the
--                way the app compares them (api/_owned.js).
--
-- What is shown, and to whom, is the gallery's own rule (directory_models):
-- published, listed, not taken out, not by an account taken out, and a
-- test account's models only to a list asked with tests. A pick the owner
-- chose that has since left the gallery is not shown; the worked-out one
-- is, instead.
--
--   gallery_picks   the owner's choices: which model, from when, until
--                   when, and when it was ended early
--   model_needs     what each published model needs, part, colour and how
--                   many, of the parts anybody can own; model_needs_kept
--                   says it was counted, and how many pieces in all
--   collection_pools   what each person has on hand, part, colour and how
--                   many; collection_pools_kept when, how many, and which
--                   of their sets no inventory knows
--
-- Who may touch what: only the server, through the functions here, each
-- granted to the service role alone. No key a page has, and not the
-- service role itself, may read or write the new tables directly: what a
-- person owns is answered only as a share of a model, to that person.
--
-- Only additions, applied after builds.sql (it reads model_builds and
-- model_stats.builds), tested.sql and collection.sql: five tables, one
-- index on model_builds, new functions, and one function replaced:
--
--   directory_models   supersedes builds.sql's (itself tested.sql's and
--                      test_models.sql's, with moderation.sql's barred
--                      accounts): the same filters and sorts, and one sort
--                      more, top; with a person's pool, each card's share
--                      of it, a sort by it (owned) and a filter for what
--                      they can build now (buildable); and the page is cut
--                      before its cards are made, where builds.sql's made a
--                      card for every model a deep page skipped.
--                      directory_card is not replaced.
--
-- No existing row is changed, nothing dropped or renamed.

-- ---------------------------------------------------------------------------
-- The score.

-- The week's builds are read by when: model_builds' key is (model, device).
create index if not exists model_builds_at on public.model_builds (at desc);

-- A build finished counts 3, a remix 2, the Tested mark 5. One place, so
-- the sort, the week and the page's words agree.
create or replace function public.gallery_score(builds bigint, remixes bigint, tested boolean)
returns bigint
language sql
immutable
set search_path = public
as $$
    select 3 * coalesce(builds, 0) + 2 * coalesce(remixes, 0) + case when tested then 5 else 0 end
$$;

-- ---------------------------------------------------------------------------
-- What models need and people own.

create table if not exists public.model_needs (
    model   text not null references public.shared_models (id) on delete cascade,
    part    text not null check (char_length(part) between 1 and 64),
    colour  integer not null check (colour >= 0),
    qty     integer not null check (qty between 1 and 200000),
    primary key (model, part, colour)
);
create index if not exists model_needs_lot on public.model_needs (part, colour);
create table if not exists public.model_needs_kept (
    model   text primary key references public.shared_models (id) on delete cascade,
    pieces  integer not null check (pieces between 0 and 200000),
    at      timestamptz not null default now()
);
create table if not exists public.collection_pools (
    owner   uuid not null references auth.users (id) on delete cascade,
    part    text not null check (char_length(part) between 1 and 64),
    colour  integer not null check (colour >= 0),
    qty     integer not null check (qty between 1 and 1000000000),
    primary key (owner, part, colour)
);
create table if not exists public.collection_pools_kept (
    owner    uuid primary key references auth.users (id) on delete cascade,
    lots     integer not null check (lots between 0 and 1000000),
    pieces   bigint not null check (pieces >= 0),
    unknown  text[] not null default '{}' check (cardinality(unknown) <= 5000),
    at       timestamptz not null default now()
);
alter table public.model_needs enable row level security;
alter table public.model_needs_kept enable row level security;
alter table public.collection_pools enable row level security;
alter table public.collection_pools_kept enable row level security;
revoke all on public.model_needs from public, anon, authenticated, service_role;
revoke all on public.model_needs_kept from public, anon, authenticated, service_role;
revoke all on public.collection_pools from public, anon, authenticated, service_role;
revoke all on public.collection_pools_kept from public, anon, authenticated, service_role;

-- What [model_id] needs, kept in place of what it needed: [needs] is
-- [{part, colour, qty}], counted by api/share.js from the file it was
-- published with. How many pieces in all.
create or replace function public.owned_keep_needs(model_id text, needs jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    pieces integer;
begin
    if jsonb_typeof(needs) <> 'array' then
        raise exception 'brickworks: needs are a list' using errcode = '22023';
    end if;
    delete from public.model_needs n where n.model = model_id;
    insert into public.model_needs (model, part, colour, qty)
    select model_id, x.part, x.colour, sum(x.qty)
      from jsonb_to_recordset(needs) as x(part text, colour integer, qty integer)
     group by x.part, x.colour;
    select coalesce(sum(n.qty), 0) into pieces from public.model_needs n where n.model = model_id;
    insert into public.model_needs_kept (model, pieces, at) values (model_id, pieces, now())
    on conflict on constraint model_needs_kept_pkey do update set pieces = excluded.pieces, at = excluded.at;
    return pieces;
end;
$$;

-- What [account] has on hand, kept in place of what it had: [lots] is
-- [{part, colour, qty}], counted by api/collection.js from the collection
-- it keeps; [unknown] its sets no inventory knows. {lots, pieces}.
create or replace function public.owned_keep_pool(account uuid, lots jsonb, unknown text[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    kept public.collection_pools_kept;
begin
    if account is null or jsonb_typeof(lots) <> 'array' then
        raise exception 'brickworks: a pool is an account and a list' using errcode = '22023';
    end if;
    delete from public.collection_pools p where p.owner = account;
    insert into public.collection_pools (owner, part, colour, qty)
    select account, x.part, x.colour, least(sum(x.qty), 1000000000)
      from jsonb_to_recordset(lots) as x(part text, colour integer, qty bigint)
     group by x.part, x.colour;
    insert into public.collection_pools_kept (owner, lots, pieces, unknown, at)
    select account, count(*), coalesce(sum(p.qty), 0), coalesce(unknown, '{}'), now()
      from public.collection_pools p where p.owner = account
    on conflict on constraint collection_pools_kept_pkey do update
       set lots = excluded.lots, pieces = excluded.pieces, unknown = excluded.unknown, at = excluded.at
    returning * into kept;
    return jsonb_build_object('lots', kept.lots, 'pieces', kept.pieces);
end;
$$;

-- [account]'s pool gone (their collection deleted): true when there was one.
create or replace function public.owned_forget_pool(account uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    gone integer;
begin
    delete from public.collection_pools p where p.owner = account;
    delete from public.collection_pools_kept k where k.owner = account;
    get diagnostics gone = row_count;
    return gone > 0;
end;
$$;

-- What [account]'s pool is: {lots, pieces, unknown, at}, or null.
create or replace function public.owned_pool_of(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('lots', k.lots, 'pieces', k.pieces, 'unknown', to_jsonb(k.unknown), 'at', k.at)
      from public.collection_pools_kept k where k.owner = account
$$;

-- Which published models have not been counted yet, oldest first, at
-- most [size] (1 to 200): for tools/web/needs_backfill.mjs.
create or replace function public.owned_uncounted(size integer default 50)
returns setof text
language sql
stable
security definer
set search_path = public
as $$
    select m.id from public.shared_models m
     where m.published and not exists (select 1 from public.model_needs_kept k where k.model = m.id)
     order by m.created_at, m.id
     limit least(greatest(coalesce(size, 50), 1), 200)
$$;

-- The list, as builds.sql made it, and one sort more: top, by
-- gallery_score, ties to more builds and then the newest. With a pool (an
-- account's, query.pool), each card says how many of its pieces anybody
-- can own the pool holds (owned: {pieces, have}; pieces null for a model
-- not counted yet), sort owned puts the largest share first (ties to more
-- pieces held), and buildable keeps only what it holds every piece of.
-- The page is cut
-- before its cards are made: builds.sql's made a card for every model it
-- skipped, so a deep page cost a card for each one before it.
create or replace function public.directory_models(query jsonb)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (
        select nullif(query->>'words', '') as words,
               nullif(query->>'kind', '') as kind,
               nullif(query->>'tag', '') as tag,
               (query->>'least')::integer as least_parts,
               (query->>'most')::integer as most_parts,
               coalesce((query->>'own_steps')::boolean, false) as own_steps,
               coalesce((query->>'technic')::boolean, false) as technic,
               coalesce((query->>'tested')::boolean, false) as tested,
               (query->>'owner')::uuid as owner,
               nullif(query->>'collection', '') as collection,
               (query->>'favourites')::uuid as favourites,
               coalesce((query->>'private')::boolean, false) as private,
               coalesce((query->>'tests')::boolean, false) as tests,
               coalesce(nullif(query->>'sort', ''), 'newest') as sort,
               least(greatest(coalesce((query->>'size')::integer, 25), 1), 49) as size,
               least(greatest(coalesce((query->>'skip')::integer, 0), 0), 20000) as skip,
               (query->>'pool')::uuid as pool,
               coalesce((query->>'buildable')::boolean, false) as buildable
    ),
    -- How many of each model's pieces the pool holds, part and colour by
    -- part and colour, across the gallery: only to sort or filter by it.
    -- A page's cards are told theirs after the page is cut.
    owned as materialized (
        select n.model, sum(least(n.qty, p.qty)) as have
          from public.collection_pools p
          join public.model_needs n on n.part = p.part and n.colour = p.colour
         where p.owner = (select a.pool from asked a)
           and (select a.sort = 'owned' or a.buildable from asked a)
         group by n.model),
    page as (
        select m,
               case when a.sort = 'added' then added.at end as k_added,
               case when a.sort = 'views' then coalesce(s.views, 0) end as k_views,
               case when a.sort = 'likes' then coalesce(s.likes, 0) end as k_likes,
               case when a.sort = 'remixes' then rx.n end as k_remixes,
               case when a.sort = 'builds' then coalesce(s.builds, 0) end as k_builds,
               case when a.sort = 'top' then public.gallery_score(coalesce(s.builds, 0), rx.n,
                                                                  public.model_tested(m.id)) end as k_top,
               case when a.sort = 'top' then coalesce(s.builds, 0) end as k_top_builds,
               case when a.sort = 'owned' then coalesce(o.have, 0)::numeric / nullif(k.pieces, 0) end as k_owned,
               case when a.sort = 'owned' then coalesce(o.have, 0) end as k_owned_pieces
          from asked a
         cross join public.shared_models m
          left join public.model_stats s on s.model = m.id
          left join public.model_needs_kept k
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and k.model = m.id
          left join owned o
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and o.model = m.id
          left join lateral (
              select count(*) as n from public.shared_models r
               where r.remixed_from = m.id and r.published) rx on true
          left join lateral (
              select coalesce(
                  (select i.at from public.model_collection_items i
                    where i.collection = a.collection and i.model = m.id),
                  (select f.at from public.model_favourites f
                    where f.account = a.favourites and f.model = m.id)) as at) added on true
         where m.published and not m.barred
           and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
           and (m.listed or a.private)
           and (not m.test or a.tests or a.private)
           and (a.words is null or m.search @@ to_tsquery('simple'::regconfig, a.words))
           and (a.kind is null or m.kind = a.kind)
           and (a.tag is null or m.tags @> array[a.tag])
           and (a.least_parts is null or m.parts >= a.least_parts)
           and (a.most_parts is null or m.parts <= a.most_parts)
           and (not a.own_steps or m.own_steps)
           and (not a.technic or m.technic)
           and (not a.tested or public.model_tested(m.id))
           and (a.owner is null or (m.owner = a.owner and m.author is not null and m.listed))
           and (a.collection is null or exists (select 1 from public.model_collection_items i
                                                 where i.collection = a.collection and i.model = m.id))
           and (a.favourites is null or exists (select 1 from public.model_favourites f
                                                 where f.account = a.favourites and f.model = m.id))
           and (not a.buildable or (k.pieces > 0 and coalesce(o.have, 0) >= k.pieces))
         order by k_added desc nulls last, k_views desc nulls last, k_likes desc nulls last,
                  k_remixes desc nulls last, k_builds desc nulls last, k_top desc nulls last,
                  k_top_builds desc nulls last, k_owned desc nulls last, k_owned_pieces desc nulls last,
                  m.listed_at desc nulls last, m.updated_at desc, m.id desc
         limit (select size from asked) offset (select skip from asked)
    )
    select public.directory_card(p.m)
           || case when a.pool is null then '{}'::jsonb
                   else jsonb_build_object('owned', jsonb_build_object('pieces', k.pieces,
                        'have', case when k.pieces is null then null else least(coalesce(h.have, 0), k.pieces) end))
              end
      from page p
     cross join asked a
      left join public.model_needs_kept k on a.pool is not null and k.model = (p.m).id
      left join lateral (
          select sum(least(n.qty, x.qty)) as have
            from public.model_needs n
            join public.collection_pools x on x.owner = a.pool and x.part = n.part and x.colour = n.colour
           where a.pool is not null and n.model = (p.m).id) h on true
     order by p.k_added desc nulls last, p.k_views desc nulls last, p.k_likes desc nulls last,
              p.k_remixes desc nulls last, p.k_builds desc nulls last, p.k_top desc nulls last,
              p.k_top_builds desc nulls last, p.k_owned desc nulls last, p.k_owned_pieces desc nulls last,
              (p.m).listed_at desc nulls last, (p.m).updated_at desc, (p.m).id desc
$$;

-- ---------------------------------------------------------------------------
-- This week's pick.

create table if not exists public.gallery_picks (
    id         bigint generated always as identity primary key,
    model      text not null references public.shared_models (id) on delete cascade,
    chosen_at  timestamptz not null default now(),
    until      timestamptz not null,
    ended_at   timestamptz,
    check (until > chosen_at and until <= chosen_at + interval '31 days'),
    check (ended_at is null or ended_at >= chosen_at)
);
create index if not exists gallery_picks_open on public.gallery_picks (chosen_at desc) where ended_at is null;
alter table public.gallery_picks enable row level security;
revoke all on public.gallery_picks from public, anon, authenticated, service_role;

-- Whether [m] is in the gallery as a list asked with [tests] shows it:
-- directory_models' own rule for a visitor.
create or replace function public.gallery_shows(m public.shared_models, tests boolean)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select m.published and m.listed and not m.barred
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
       and (not m.test or coalesce(tests, false))
$$;

-- What the past seven days say, model by model: (model, builds,
-- remixes). Builds finished in the week; remixes of it listed in the week
-- and shown in the gallery as [tests] asks. Of [one_model] alone when it is
-- given. Only models with one or the other.
create or replace function public.gallery_week_counts(tests boolean, one_model text default null)
returns table (model text, builds bigint, remixes bigint)
language sql
stable
security definer
set search_path = public
as $$
    with built as (
        select b.model, count(*) as n from public.model_builds b
         where b.at > now() - interval '7 days' and (one_model is null or b.model = one_model)
         group by b.model),
    remixed as (
        select r.remixed_from as model, count(*) as n from public.shared_models r
         where r.remixed_from is not null and (one_model is null or r.remixed_from = one_model)
           and r.listed_at > now() - interval '7 days' and public.gallery_shows(r, tests)
         group by r.remixed_from)
    select coalesce(b.model, x.model), coalesce(b.n, 0), coalesce(x.n, 0)
      from built b
      full join remixed x on x.model = b.model
$$;

-- The week's candidates, best first: {card, week: {builds, remixes,
-- tested, score}}, at most [size] (1 to 20). A model is one when something
-- in the past seven days says it builds: a build finished, a remix listed,
-- or it was listed in the week and is Tested. Its card is made only once
-- it is among the best.
create or replace function public.gallery_week(tests boolean default false, size integer default 5)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    with counted as (
        select * from public.gallery_week_counts(gallery_week.tests)),
    weighed as (
        select m, coalesce(c.builds, 0) as builds, coalesce(c.remixes, 0) as remixes,
               public.model_tested(m.id) as tested
          from (select model as id from counted
                union
                select n.id from public.shared_models n
                 where n.listed and n.published and n.listed_at > now() - interval '7 days') recent
          join public.shared_models m on m.id = recent.id
          left join counted c on c.model = m.id
         where public.gallery_shows(m, gallery_week.tests)),
    best as (
        select w.*, public.gallery_score(w.builds, w.remixes, w.tested) as score
          from weighed w
         where w.builds > 0 or w.remixes > 0 or (w.tested and (w.m).listed_at > now() - interval '7 days')
         order by score desc, w.builds desc, (w.m).listed_at desc nulls last, (w.m).id desc
         limit least(greatest(coalesce(gallery_week.size, 5), 1), 20))
    select jsonb_build_object('card', public.directory_card(b.m),
                              'week', jsonb_build_object('builds', b.builds, 'remixes', b.remixes,
                                                         'tested', b.tested, 'score', b.score))
      from best b
     order by b.score desc, b.builds desc, (b.m).listed_at desc nulls last, (b.m).id desc
$$;

-- What the past seven days say of [model_id], whatever they say:
-- {builds, remixes, tested, score}, for a pick the owner chose.
create or replace function public.gallery_week_of(model_id text, tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('builds', coalesce(c.builds, 0), 'remixes', coalesce(c.remixes, 0),
                              'tested', t.ok, 'score', public.gallery_score(c.builds, c.remixes, t.ok))
      from (select public.model_tested(model_id) as ok) t
      left join public.gallery_week_counts(tests, model_id) c on true
$$;

-- This week's pick, as a list asked with [tests] shows it: the owner's
-- newest choice still open and still in the gallery, or else the week's
-- best. {pick (the choice's id, null when worked out), chosen, until,
-- card, week}, or null when there is none.
create or replace function public.gallery_pick(tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select jsonb_build_object('pick', p.id, 'chosen', true, 'chosen_at', p.chosen_at, 'until', p.until,
                                   'card', public.directory_card(m),
                                   'week', public.gallery_week_of(m.id, gallery_pick.tests))
           from public.gallery_picks p
           join public.shared_models m on m.id = p.model
          where p.ended_at is null and p.chosen_at <= now() and p.until > now()
            and public.gallery_shows(m, gallery_pick.tests)
          order by p.chosen_at desc, p.id desc
          limit 1),
        (select w || jsonb_build_object('pick', null, 'chosen', false, 'chosen_at', null, 'until', null)
           from public.gallery_week(gallery_pick.tests, 1) w))
$$;

-- The owner chooses [model_id] as the pick for [days] (1 to 31) from now:
-- {pick, model, chosen_at, until}. Refused, with a reason, for a model the
-- gallery does not show (a test model is shown to a list asked with tests,
-- so it may be chosen, and only such a list sees it).
create or replace function public.gallery_choose_pick(model_id text, days integer default 7)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    made public.gallery_picks;
begin
    if days is null or days < 1 or days > 31 then
        raise exception 'brickworks: a pick is for 1 to 31 days' using errcode = '22023';
    end if;
    select * into m from public.shared_models where id = model_id;
    if not found or not public.gallery_shows(m, true) then
        return jsonb_build_object('refused', 'not_in_gallery');
    end if;
    insert into public.gallery_picks (model, until) values (model_id, now() + make_interval(days => days))
    returning * into made;
    return jsonb_build_object('pick', made.id, 'model', made.model, 'chosen_at', made.chosen_at,
                              'until', made.until);
end;
$$;

-- The owner's choice [pick] ended now: true when it was open.
create or replace function public.gallery_end_pick(pick bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    ended integer;
begin
    update public.gallery_picks p set ended_at = greatest(now(), p.chosen_at)
     where p.id = pick and p.ended_at is null;
    get diagnostics ended = row_count;
    return ended > 0;
end;
$$;

-- The owner's choices still open, newest first, for the admin page:
-- {pick, model, name, chosen_at, until, test, shown}. shown: whether a
-- visitor's gallery shows it now (a test model's is not).
create or replace function public.gallery_choices()
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('pick', p.id, 'model', p.model, 'name', m.name, 'chosen_at', p.chosen_at,
                              'until', p.until, 'test', m.test, 'shown', public.gallery_shows(m, false))
      from public.gallery_picks p
      join public.shared_models m on m.id = p.model
     where p.ended_at is null and p.until > now()
     order by p.chosen_at desc, p.id desc
     limit 50
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.owned_keep_needs(text, jsonb) from public, anon, authenticated;
grant execute on function public.owned_keep_needs(text, jsonb) to service_role;
revoke all on function public.owned_keep_pool(uuid, jsonb, text[]) from public, anon, authenticated;
grant execute on function public.owned_keep_pool(uuid, jsonb, text[]) to service_role;
revoke all on function public.owned_forget_pool(uuid) from public, anon, authenticated;
grant execute on function public.owned_forget_pool(uuid) to service_role;
revoke all on function public.owned_pool_of(uuid) from public, anon, authenticated;
grant execute on function public.owned_pool_of(uuid) to service_role;
revoke all on function public.owned_uncounted(integer) from public, anon, authenticated;
grant execute on function public.owned_uncounted(integer) to service_role;
revoke all on function public.gallery_score(bigint, bigint, boolean) from public, anon, authenticated;
grant execute on function public.gallery_score(bigint, bigint, boolean) to service_role;
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;
revoke all on function public.gallery_shows(public.shared_models, boolean) from public, anon, authenticated;
grant execute on function public.gallery_shows(public.shared_models, boolean) to service_role;
revoke all on function public.gallery_week_counts(boolean, text) from public, anon, authenticated;
grant execute on function public.gallery_week_counts(boolean, text) to service_role;
revoke all on function public.gallery_week_of(text, boolean) from public, anon, authenticated;
grant execute on function public.gallery_week_of(text, boolean) to service_role;
revoke all on function public.gallery_week(boolean, integer) from public, anon, authenticated;
grant execute on function public.gallery_week(boolean, integer) to service_role;
revoke all on function public.gallery_pick(boolean) from public, anon, authenticated;
grant execute on function public.gallery_pick(boolean) to service_role;
revoke all on function public.gallery_choose_pick(text, integer) from public, anon, authenticated;
grant execute on function public.gallery_choose_pick(text, integer) to service_role;
revoke all on function public.gallery_choices() from public, anon, authenticated;
grant execute on function public.gallery_choices() to service_role;
revoke all on function public.gallery_end_pick(bigint) from public, anon, authenticated;
grant execute on function public.gallery_end_pick(bigint) to service_role;
