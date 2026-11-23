-- Alternate builds, counted (altbuilds, 2026-11-23; docs/MASTERPLAN.md
-- unit 2, "What only Brickworks can do" 1).
--
-- Rebrickable's designers type in which set a MOC is built from. Here it is
-- counted: what a model needs (model_needs, discovery.sql) against what each
-- real set holds (the sets' inventories, beside the share function as an
-- index: api/_alts.js), by the app's own rules. What was counted is kept, so
-- a page reads a row and never a file:
--
--   model_alts      (model, pieces, rule, cut, at): the model was counted,
--                   [pieces] of it anybody can own, by rule [rule]
--                   (api/_alts.js ALT_RULE); [cut] when the search for a
--                   group of sets was given up before it ended
--   model_alt_sets  (model, set_number, role, n, have): a set and how much
--                   of the model it holds, [have] pieces of model_alts'
--                   [pieces], one row a set. [role]:
--                     whole     every part from this one set
--                     group     one of the fewest sets (two to five) that
--                               hold every part together, [n] its place
--                     best      the set holding the most of it, when none
--                               and no group holds all, from 80% on
--                     declared  a set its designer says it is based on
--                     library   the set the app's Library says it is
--                               another model of (an alternate's file)
--                     own       the set it is the build of (a library
--                               model of the set itself): never said as
--                               an alternate of it
--                   [set_number] lower case, as the sets' shards key it
--
--   alt_keep(model_id, pieces, rule, cut, sets)   a model's rows, whole:
--                   what was there is replaced. {kept: n}
--   alt_of(model_ids)            the rows of those models, for their pages
--   alt_needs_of(model_ids)      what those models need, from model_needs,
--                   for a count made again (a designer's list changed, the
--                   backfill): {model: [[part, colour, qty]]}
--   alt_uncounted(rule, size)    models with needs kept and no count by
--                   [rule], or one older than their needs: the backfill's
--   set_built(set_number, tests) the gallery's models built from a set,
--                   counted or declared, as gallery cards with what each
--                   holds of it: a set's page lists them
--   gallery_models               the live one's (made_with.sql, then wip.sql:
--                   a work in progress only in Newest), and two filters: alt (a
--                   set: the models built from it, whole or in a group) and
--                   one_set (every part from one set)
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables.
--
-- Only additions: two tables, each row deleted with its model, an index,
-- and functions; gallery_models is the live one's with two more filters
-- (supabase/later.tsv): its body read from production with
-- pg_get_functiondef on 2026-11-23, after wip.sql, and only alt and one_set
-- added, so a work in progress stays out of Top and the ranked sorts. No row of another table is changed, nothing dropped
-- or renamed. Applied after discovery.sql, model_bases.sql (model_bases),
-- made_with.sql (gallery_models, directory_card), test_models.sql and
-- wip.sql (gallery_models, directory_card's wip).
--
-- Applied by the lead:
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/alt_builds.sql --table=model_alt_sets
--
-- tried first, rolled back, with what tools/alt_builds_try.sql asks:
--
--   ... node tools/apply_sql.mjs supabase/alt_builds.sql --dry \
--         --try=tools/alt_builds_try.sql --table=model_alt_sets
--
-- then every model counted once (tools/web/alt_backfill.mjs).

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.model_alts (
    model   text primary key references public.shared_models (id) on delete cascade,
    pieces  integer not null check (pieces between 0 and 200000),
    rule    smallint not null check (rule between 1 and 1000),
    cut     boolean not null default false,
    at      timestamptz not null default now()
);

create table if not exists public.model_alt_sets (
    model       text not null references public.shared_models (id) on delete cascade,
    set_number  text not null check (set_number ~ '^[a-z0-9][a-z0-9.-]{0,29}$'),
    role        text not null check (role in ('whole', 'group', 'best', 'declared', 'library', 'own')),
    n           smallint not null default 0 check (n between 0 and 5),
    have        integer not null check (have between 0 and 200000),
    primary key (model, set_number)
);
create index if not exists model_alt_sets_set on public.model_alt_sets (set_number, role);

alter table public.model_alts enable row level security;
alter table public.model_alt_sets enable row level security;
revoke all on public.model_alts from public, anon, authenticated, service_role;
revoke all on public.model_alt_sets from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Keeping and reading a model's count.

create or replace function public.alt_keep(model_id text, pieces integer, rule integer, cut boolean, sets jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    kept integer;
begin
    if jsonb_typeof(sets) <> 'array' then
        raise exception 'brickworks: sets are a list' using errcode = '22023';
    end if;
    if not exists (select 1 from public.shared_models m where m.id = alt_keep.model_id) then
        return jsonb_build_object('refused', 'no_model');
    end if;
    delete from public.model_alt_sets s where s.model = alt_keep.model_id;
    insert into public.model_alt_sets (model, set_number, role, n, have)
    select distinct on (lower(x.set)) alt_keep.model_id, lower(x.set), x.role, coalesce(x.n, 0), x.have
      from jsonb_to_recordset(sets) as x("set" text, role text, n smallint, have integer)
     order by lower(x.set), x.n;
    get diagnostics kept = row_count;
    insert into public.model_alts (model, pieces, rule, cut, at)
    values (alt_keep.model_id, alt_keep.pieces, alt_keep.rule, coalesce(alt_keep.cut, false), now())
    on conflict on constraint model_alts_pkey do update
       set pieces = excluded.pieces, rule = excluded.rule, cut = excluded.cut, at = excluded.at;
    return jsonb_build_object('kept', kept);
end;
$$;

create or replace function public.alt_of(model_ids text[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
               'model', a.model, 'pieces', a.pieces, 'rule', a.rule, 'cut', a.cut,
               'sets', coalesce((select jsonb_agg(jsonb_build_object('set', s.set_number, 'role', s.role, 'n', s.n,
                                                                    'have', s.have) order by s.role, s.n, s.set_number)
                                   from public.model_alt_sets s where s.model = a.model), '[]'::jsonb))
           order by a.model), '[]'::jsonb)
      from public.model_alts a
     where a.model = any(alt_of.model_ids) and cardinality(alt_of.model_ids) <= 100
$$;

create or replace function public.alt_needs_of(model_ids text[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_object_agg(t.model, t.lots), '{}'::jsonb)
      from (select n.model, jsonb_agg(jsonb_build_array(n.part, n.colour, n.qty) order by n.part, n.colour) as lots
              from public.model_needs n
             where n.model = any(alt_needs_of.model_ids) and cardinality(alt_needs_of.model_ids) <= 100
             group by n.model) t
$$;

create or replace function public.alt_uncounted(rule integer, size integer default 50)
returns text[]
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(array_agg(t.model order by t.model), '{}'::text[])
      from (select k.model
              from public.model_needs_kept k
              join public.shared_models m on m.id = k.model and m.published
              left join public.model_alts a on a.model = k.model
             where a.model is null or a.rule < alt_uncounted.rule or a.at < k.at
             order by k.model
             limit least(greatest(coalesce(alt_uncounted.size, 50), 1), 500)) t
$$;

-- ---------------------------------------------------------------------------
-- A set's page: the gallery's models built from it.

-- Counted (whole, a group's, best from 80%, the Library's word) or declared
-- (model_bases), each once: whole first, then a group's, then the most of
-- it from the set, then the declared that were not counted, the newest
-- first; a set's own build (own) never. Each card says how it is built
-- from the set: {based (its designer's how, or null), alt: {role, have,
-- pieces, with (the group's other sets, in order)}}.
create or replace function public.set_built(set_number text, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (select lower(set_built.set_number) as set_num),
    counted as (
        select s.model, s.role, s.have, a.pieces,
               (select coalesce(jsonb_agg(o.set_number order by o.n), '[]'::jsonb)
                  from public.model_alt_sets o
                 where o.model = s.model and o.role = 'group' and o.set_number <> s.set_number) as others
          from public.model_alt_sets s
          join public.model_alts a on a.model = s.model
          join asked q on q.set_num = s.set_number
         where s.role in ('whole', 'group', 'best', 'declared', 'library')
           and (s.role <> 'best' or s.have * 10 >= a.pieces * 8)
           and not exists (select 1 from public.model_alt_sets x
                            where x.model = s.model and x.set_number = s.set_number and x.role = 'own')),
    declared as (
        select distinct on (x.model) x.model, x.how
          from public.model_bases x, asked q
         where lower(x.set_number) = q.set_num
         order by x.model, x.n),
    joined as (
        select coalesce(c.model, d.model) as model, d.how, c.role, c.have, c.pieces, c.others
          from counted c
          full join declared d on d.model = c.model)
    select coalesce(jsonb_agg(public.directory_card(t.m) || jsonb_build_object('based', t.how, 'alt',
               case when t.role is null then null
                    else jsonb_build_object('role', t.role, 'have', t.have, 'pieces', t.pieces, 'with', t.others) end)
             order by t.rank, t.share desc nulls last, t.listed_at desc nulls last, t.id), '[]'::jsonb)
      from (select m, m.id, m.listed_at, j.how, j.role, j.have, j.pieces, j.others,
                   case j.role when 'whole' then 0 when 'library' then 1 when 'group' then 2 when 'best' then 3
                               else 4 end as rank,
                   case when j.pieces > 0 then j.have::numeric / j.pieces end as share
              from joined j
              join public.shared_models m on m.id = j.model
             where public.gallery_shows(m, set_built.tests)
             order by 9, 10 desc nulls last, m.listed_at desc nulls last, m.id
             limit 24) t
$$;

-- ---------------------------------------------------------------------------
-- The gallery's list: the live one's (wip.sql's), and alt and one_set.

create or replace function public.gallery_models(query jsonb)
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
               coalesce((query->>'buildable')::boolean, false) as buildable,
               -- Top over the past [days]: none is all time. (greatest()
               -- passes over a null, so a missing one is said so first.)
               case when query->>'days' is null then null
                    else least(greatest((query->>'days')::integer, 1), 366) end as days,
               (query->>'following')::uuid as following,
               nullif(query->>'made', '') as made,
               -- Built from a set (alt_builds.sql): alt=N and one_set.
               lower(nullif(query->>'alt', '')) as alt,
               coalesce((query->>'one_set')::boolean, false) as one_set
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
    -- Top over a time: the builds finished and the remixes listed in it,
    -- model by model (discovery.sql gallery_week_counts' rule, any span).
    built as materialized (
        select b.model, count(*) as n
          from public.model_builds b, asked a
         where a.days is not null and a.sort = 'top' and b.at > now() - make_interval(days => a.days)
         group by b.model),
    remixed as materialized (
        select r.remixed_from as model, count(*) as n
          from public.shared_models r, asked a
         where a.days is not null and a.sort = 'top' and r.remixed_from is not null
           and r.listed_at > now() - make_interval(days => a.days) and public.gallery_shows(r, a.tests)
         group by r.remixed_from),
    -- Whom the asker follows, who may be followed (follows.sql feed_rows).
    followed as materialized (
        select f.followed as account
          from public.follows f, asked a
         where a.following is not null and f.follower = a.following
           and public.follow_may_be_followed(f.followed)),
    page as (
        select m,
               case when a.sort = 'added' then added.at end as k_added,
               case when a.sort = 'views' then coalesce(s.views, 0) end as k_views,
               case when a.sort = 'likes' then coalesce(s.likes, 0) end as k_likes,
               case when a.sort = 'remixes' then rx.n end as k_remixes,
               case when a.sort = 'builds' then coalesce(s.builds, 0) end as k_builds,
               case when a.sort = 'top' then public.gallery_score(
                   case when a.days is null then coalesce(s.builds, 0) else coalesce(wb.n, 0) end,
                   case when a.days is null then rx.n else coalesce(wr.n, 0) end,
                   public.model_tested(m.id)) end as k_top,
               case when a.sort = 'top' then
                   case when a.days is null then coalesce(s.builds, 0) else coalesce(wb.n, 0) end end as k_top_builds,
               case when a.sort = 'owned' then coalesce(o.have, 0)::numeric / nullif(k.pieces, 0) end as k_owned,
               case when a.sort = 'owned' then coalesce(o.have, 0) end as k_owned_pieces
          from asked a
         cross join public.shared_models m
          left join public.model_stats s on s.model = m.id
          left join public.model_needs_kept k
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and k.model = m.id
          left join owned o
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and o.model = m.id
          left join built wb on wb.model = m.id
          left join remixed wr on wr.model = m.id
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
           -- Work in progress (wip.sql): only where the list is in time
           -- order, never where it ranks or is built from what you own.
           and (m.wip_at is null or (a.sort in ('newest', 'added') and not a.buildable))
           and (not m.test or a.tests or a.private)
           and (a.words is null or m.search @@ to_tsquery('simple'::regconfig, a.words))
           and (a.kind is null or m.kind = a.kind)
           and (a.tag is null or m.tags @> array[a.tag])
           and (a.least_parts is null or m.parts >= a.least_parts)
           and (a.most_parts is null or m.parts <= a.most_parts)
           and (not a.own_steps or m.own_steps)
           and (not a.technic or m.technic or public.moves_mechanism(m.moves))
           and (not a.tested or public.model_tested(m.id))
           and (a.owner is null or (m.owner = a.owner and m.author is not null and m.listed))
           and (a.collection is null or exists (select 1 from public.model_collection_items i
                                                 where i.collection = a.collection and i.model = m.id))
           and (a.favourites is null or exists (select 1 from public.model_favourites f
                                                 where f.account = a.favourites and f.model = m.id))
           and (not a.buildable or (k.pieces > 0 and coalesce(o.have, 0) >= k.pieces))
           -- Top over a time: what something in it says builds.
           and (a.days is null or a.sort <> 'top' or coalesce(wb.n, 0) > 0 or coalesce(wr.n, 0) > 0
                or (m.listed_at > now() - make_interval(days => a.days) and public.model_tested(m.id)))
           and (a.following is null
                or (m.author is not null and m.owner in (select w.account from followed w)))
           -- How it was made: as its app said, else as its tags say.
           and (a.made is null
                or (a.made = 'assistant' and (m.made_with in ('assistant', 'brickify')
                    or (m.made_with is null and m.tags && array['ai-designed', 'brickify']::text[])))
                or (a.made = 'hand' and (m.made_with = 'hand'
                    or (m.made_with is null and not (m.tags && array['ai-designed', 'brickify']::text[])))))
           -- Built from a set: every part from it, or one of the fewest
           -- sets that hold every part (alt_builds.sql).
           and (a.alt is null or exists (select 1 from public.model_alt_sets x
                                          where x.model = m.id and x.set_number = a.alt and x.role in ('whole', 'group')))
           and (not a.one_set or exists (select 1 from public.model_alt_sets x
                                          where x.model = m.id and x.role = 'whole'))
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

revoke all on function public.alt_keep(text, integer, integer, boolean, jsonb) from public, anon, authenticated;
grant execute on function public.alt_keep(text, integer, integer, boolean, jsonb) to service_role;
revoke all on function public.alt_of(text[]) from public, anon, authenticated;
grant execute on function public.alt_of(text[]) to service_role;
revoke all on function public.alt_needs_of(text[]) from public, anon, authenticated;
grant execute on function public.alt_needs_of(text[]) to service_role;
revoke all on function public.alt_uncounted(integer, integer) from public, anon, authenticated;
grant execute on function public.alt_uncounted(integer, integer) to service_role;
revoke all on function public.set_built(text, boolean) from public, anon, authenticated;
grant execute on function public.set_built(text, boolean) to service_role;
revoke all on function public.gallery_models(jsonb) from public, anon, authenticated;
grant execute on function public.gallery_models(jsonb) to service_role;

notify pgrst, 'reload schema';
