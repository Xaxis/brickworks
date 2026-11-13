-- Lists of sets as well as models, the wishlist, and the sets you own on
-- your profile, 2026-11-13 (lists1, docs/LISTS.md).
--
-- A collection (people.sql's model_collections) held models from the
-- gallery. Now it holds LEGO® sets of the library too, mixed or not, as
-- Letterboxd's lists hold any film and Discogs' folders any record:
--
--   collection_sets       which sets are in which list, and since when;
--                         a set (set_num) by Rebrickable's number, "10497-1", as
--                         My collection keeps one (api/collection.js)
--
-- And a list says more of itself:
--
--   kind            null for a list of the person's own; 'want' for their
--                   wishlist (I want, docs/LISTS.md), one an account, made
--                   the first time they want something. A wishlist is a
--                   list like any other in every other way: private until
--                   they make it public, then a page with a link to send
--                   (for gifts), on their profile; never in the directory.
--   sort            'added', the last put in first (as every list was), or
--                   'manual', the order its owner dragged it into
--                   (position)
--   cover           the item its card and page lead with: 'set:<number>'
--                   or 'model:<id>', one in it; null for the mosaic of its
--                   first four, as before
--   taken_down_at   when the site's owner took it down from /admin's
--                   Gallery (a name or words a stranger reported): private
--                   from then on, and never public again; its owner still
--                   has it and what is in it
--   position        on both kinds of item: where its owner put it, for a
--                   list in their own order; null until they first do
--
-- And what a profile shows besides its name (profile_shows.sql):
--
--   owned           the sets they own (My collection's, api/collection.js)
--                   shown on their profile, its Sets tab: false until they
--                   choose it, as Brickset's collection is opt-in
--
-- And four functions, each security definer and the service role's alone:
--
--   list_items(list, private, tests)
--       every item a list shows, in its order: [{kind, key, at, position}],
--       a model only while the gallery shows it (published, not taken out,
--       listed or [private]: its owner's view; a test model only with
--       [tests] or [private]), and every set
--   list_model_cards(list, models, private, tests)
--       the gallery's card (directory_card) of each of [models] that is in
--       [list] and shown by list_items' rule
--   list_place(list, keys)
--       the list in its owner's order: each of [keys] at its place, the
--       rest after them; never adds or takes out anything
--   list_directory(q, sort, page, size, tests)
--       collection_directory_search's page, of lists with sets as well:
--       a public list (not a wishlist, not taken down) whose owner may be
--       followed and is not taken out, with at least one model the gallery
--       shows or one set; counted as models + sets; [q] '' lists every one
--
-- Only additions, applied after people.sql, trust.sql, moderation.sql,
-- test_models.sql, collection_follows.sql, collection_directory.sql and
-- profile_shows.sql (it reads their tables and functions): columns with
-- constant defaults or none (no row is rewritten), one check and one
-- unique index that every row meets (nothing has a kind or was taken down),
-- a new table, deleted with its list, and new functions. Nothing existing
-- is dropped, renamed or replaced: collection_directory and every other
-- function answers as it did, and the api live before this reads none of
-- what is new.
--
--   node --env-file=.env tools/apply_sql.mjs supabase/lists.sql --dry --try=tools/lists_try.sql --table=collection_sets
--   node --env-file=.env tools/apply_sql.mjs supabase/lists.sql --table=collection_sets

-- ---------------------------------------------------------------------------
-- A list's new columns.

alter table public.model_collections add column if not exists kind text;
alter table public.model_collections add column if not exists sort text not null default 'added';
alter table public.model_collections add column if not exists cover text;
alter table public.model_collections add column if not exists taken_down_at timestamptz;

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'model_collections_kind_check') then
        alter table public.model_collections add constraint model_collections_kind_check
            check (kind is null or kind = 'want');
    end if;
    if not exists (select 1 from pg_constraint where conname = 'model_collections_sort_check') then
        alter table public.model_collections add constraint model_collections_sort_check
            check (sort in ('added', 'manual'));
    end if;
    if not exists (select 1 from pg_constraint where conname = 'model_collections_cover_check') then
        alter table public.model_collections add constraint model_collections_cover_check
            check (cover is null or cover ~ '^(set:[a-z0-9][a-z0-9._]{0,24}-[0-9]{1,3}|model:[A-Za-z0-9]{10})$');
    end if;
    -- Taken down is never public, whatever writes: the database's own lock
    -- under api/people.js saveList's refusal.
    if not exists (select 1 from pg_constraint where conname = 'model_collections_down_private') then
        alter table public.model_collections add constraint model_collections_down_private
            check (taken_down_at is null or not public);
    end if;
end;
$$;

-- One wishlist an account.
create unique index if not exists model_collections_one_want
    on public.model_collections (owner) where kind = 'want';

comment on column public.model_collections.kind is
    'null: a list of the person''s own; ''want'': their wishlist, one an account (lists.sql).';
comment on column public.model_collections.sort is
    '''added'': the last put in first; ''manual'': the order its owner put it in (position).';
comment on column public.model_collections.cover is
    'The item its card leads with, ''set:<number>'' or ''model:<id>''; null: its first four.';
comment on column public.model_collections.taken_down_at is
    'Taken down by the site''s owner (/admin Gallery): private from then on, and never public again.';

alter table public.model_collection_items add column if not exists position integer;
comment on column public.model_collection_items.position is
    'Where its list''s owner put it, for a list in their own order (sort ''manual'').';

-- ---------------------------------------------------------------------------
-- The sets in a list.

create table if not exists public.collection_sets (
    collection  text not null references public.model_collections (id) on delete cascade,
    set_num     text not null check (set_num ~ '^[a-z0-9][a-z0-9._]{0,24}-[0-9]{1,3}$'),
    at          timestamptz not null default now(),
    position    integer,
    primary key (collection, set_num)
);
create index if not exists collection_sets_set on public.collection_sets (set_num);

comment on table public.collection_sets is
    'Which LEGO sets are in which list (model_collections), by Rebrickable''s number. Written only by api/people.js.';

-- The server's alone, as model_collection_items is: what a visitor may see
-- of it they see through api/people.js.
alter table public.collection_sets enable row level security;
revoke all on public.collection_sets from anon, authenticated, public;
grant all on public.collection_sets to service_role;

-- ---------------------------------------------------------------------------
-- The sets you own, on your profile.

alter table public.profile_shows add column if not exists owned boolean not null default false;
comment on column public.profile_shows.owned is
    'The sets they own (My collection) shown on their profile''s Sets tab: their choice, off until made (lists.sql).';

-- ---------------------------------------------------------------------------
-- What a list shows, in its order.

create or replace function public.list_items(list text, private boolean, tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with mine as (
        select c.sort from public.model_collections c where c.id = list_items.list),
    items as (
        select 'model'::text as kind, i.model as key, i.at, i.position
          from public.model_collection_items i
          join public.shared_models m on m.id = i.model
         where i.collection = list_items.list
           and m.published and not m.barred and (m.listed or list_items.private)
           and (not m.test or list_items.tests or list_items.private)
        union all
        select 'set'::text, s.set_num, s.at, s.position
          from public.collection_sets s
         where s.collection = list_items.list)
    select coalesce(jsonb_agg(jsonb_build_object('kind', t.kind, 'key', t.key, 'at', t.at, 'position', t.position)
                    order by case when (select sort from mine) = 'manual' then t.position end asc nulls last,
                             t.at desc, t.kind, t.key), '[]'::jsonb)
      from items t
$$;

revoke all on function public.list_items(text, boolean, boolean) from public, anon, authenticated;
grant execute on function public.list_items(text, boolean, boolean) to service_role;

create or replace function public.list_model_cards(list text, models text[], private boolean, tests boolean)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select public.directory_card(m)
      from public.shared_models m
      join public.model_collection_items i on i.model = m.id and i.collection = list_model_cards.list
     where m.id = any(list_model_cards.models)
       and m.published and not m.barred and (m.listed or list_model_cards.private)
       and (not m.test or list_model_cards.tests or list_model_cards.private)
$$;

revoke all on function public.list_model_cards(text, text[], boolean, boolean) from public, anon, authenticated;
grant execute on function public.list_model_cards(text, text[], boolean, boolean) to service_role;

-- A list put in its owner's order: each of [keys] ('set:<number>' or
-- 'model:<id>') at its place, 0 first; what is in it and not named after
-- them (position null); the list then in its own order (sort 'manual').
-- Only ever moves what is in it: nothing named is added, nothing is taken
-- out. The number of items placed.
create or replace function public.list_place(list text, keys text[])
returns integer
language sql
volatile
security definer
set search_path = public
as $$
    with ordered as (
        select u.k, u.n - 1 as at from unnest(list_place.keys) with ordinality as u(k, n)),
    sets as (
        update public.collection_sets s
           set position = (select o.at from ordered o where o.k = 'set:' || s.set_num limit 1)
         where s.collection = list_place.list
     returning s.position),
    models as (
        update public.model_collection_items i
           set position = (select o.at from ordered o where o.k = 'model:' || i.model limit 1)
         where i.collection = list_place.list
     returning i.position),
    marked as (
        update public.model_collections c set sort = 'manual', updated_at = now()
         where c.id = list_place.list
     returning c.id)
    select ((select count(*) from sets where position is not null)
          + (select count(*) from models where position is not null)
          + 0 * (select count(*) from marked))::integer
$$;

revoke all on function public.list_place(text, text[]) from public, anon, authenticated;
grant execute on function public.list_place(text, text[]) to service_role;

-- ---------------------------------------------------------------------------
-- The directory of lists, sets' and models' alike (/collections).

create or replace function public.list_directory(q text default '', sort text default 'recent', page integer default 1,
                                                 size integer default 24, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (
        select least(greatest(coalesce(list_directory.size, 24), 1), 48) as size,
               greatest(coalesce(list_directory.page, 1), 1) as page,
               coalesce(list_directory.tests, false) as tests,
               case when list_directory.sort = 'followed' then 'followed' else 'recent' end as sort,
               coalesce((select array_agg(w) from (
                   select w from regexp_split_to_table(lower(left(coalesce(list_directory.q, ''), 100)), '\s+') as w
                    where w <> '' limit 8) as words), '{}'::text[]) as words),
    open as (
        select c.id, c.name, c.description, c.owner
          from public.model_collections c
         cross join asked a
         where c.public and c.kind is null and c.taken_down_at is null
           and public.list_may_be_followed(c.id)
           and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
           and (a.tests or not public.trust_is_test_account(c.owner))),
    shown as (
        select o.*, mm.models, ss.sets, greatest(mm.added, ss.added) as added
          from open o
         cross join asked a
         cross join lateral (
             select count(*) as models, max(i.at) as added
               from public.model_collection_items i
               join public.shared_models m on m.id = i.model
              where i.collection = o.id
                and m.published and m.listed and not m.barred and (not m.test or a.tests)) mm
         cross join lateral (
             select count(*) as sets, max(s.at) as added
               from public.collection_sets s where s.collection = o.id) ss
         where mm.models + ss.sets > 0),
    found as (
        select s.*
          from shown s
         cross join asked a
          left join public.people p on p.account = s.owner
         where not exists (
                   select 1 from unnest(a.words) as w
                    where strpos(lower(coalesce(s.name, '') || ' ' || coalesce(s.description, '') || ' '
                                       || coalesce(p.handle, '') || ' ' || coalesce(p.name, '')), w) = 0)),
    counted as (
        select s.*, (select count(*) from public.collection_follows f
                      where f.collection = s.id
                        and public.trust_may_go_public(f.follower) and public.shown_publicly(f.follower)) as followers
          from found s),
    ordered as (
        select k.*, row_number() over (order by
                   case when (select a.sort from asked a) = 'followed' then k.followers end desc nulls last,
                   k.added desc nulls last, k.id) as n,
               count(*) over () as total
          from counted k)
    select jsonb_build_object(
        'sort', a.sort, 'page', a.page, 'size', a.size,
        'total', coalesce((select max(o.total) from ordered o), 0),
        'rows', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', o.id, 'name', o.name, 'description', o.description,
                       'count', o.models + o.sets, 'models', o.models, 'sets', o.sets,
                       'followers', o.followers, 'added', o.added,
                       'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                                from public.people p where p.account = o.owner))
                   order by o.n)
              from ordered o
             where o.n > (a.page - 1) * a.size and o.n <= a.page * a.size), '[]'::jsonb))
      from asked a
$$;

revoke all on function public.list_directory(text, text, integer, integer, boolean) from public, anon, authenticated;
grant execute on function public.list_directory(text, text, integer, integer, boolean) to service_role;

notify pgrst, 'reload schema';
