-- The collections directory, 2026-10-25 (walk256's W12): /collections.
--
-- A public collection had a page of its own (/c/<id>), a cover and Follow
-- (collection_follows.sql), but nothing listed them: a person could reach
-- one only from its owner's profile or a model in it, and /collections was
-- a 404. Rebrickable lists its MOC lists, Flickr its albums, Printables
-- its collections, each a card with a cover, a name, whose, how many, and
-- a way to follow; newest or most followed first.
--
--   collection_directory(sort, page, size, tests)
--       one page of the public collections anyone may see, as cards:
--       {sort, page, size, total, rows: [{id, name, description, count,
--       followers, added, by}]}. [sort] 'recent' (what was put in last,
--       the default) or 'followed' (most followers first, then recent);
--       [size] 1 to 48, 24 by default; [tests] a test account's and test
--       models too, as every other list has it.
--
-- Shown, a collection that is public; whose owner may be followed (13 or
-- over, shown in public: list_may_be_followed) and is not taken out;
-- with at least one model in the gallery, which is what its page shows,
-- counted as its page counts them (collection_count). A private one never;
-- nor an empty one, which a directory would show as a blank card. Its
-- followers counted as list_follow_state counts them, of accounts shown in
-- public; who they are is never said.
--
-- Only an addition, applied after people.sql, trust.sql, moderation.sql,
-- test_models.sql and collection_follows.sql (it reads model_collections,
-- model_collection_items, shared_models, people, barred_accounts and
-- collection_follows): one new function, security definer and the service
-- role's alone, as the tables it reads are. No table, row or function of
-- before is changed, nothing dropped or renamed.

create or replace function public.collection_directory(sort text default 'recent', page integer default 1,
                                                        size integer default 24, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (
        select least(greatest(coalesce(collection_directory.size, 24), 1), 48) as size,
               greatest(coalesce(collection_directory.page, 1), 1) as page,
               coalesce(collection_directory.tests, false) as tests,
               case when collection_directory.sort = 'followed' then 'followed' else 'recent' end as sort),
    shown as (
        select c.id, c.name, c.description, c.owner, count(*) as models, max(i.at) as added
          from public.model_collections c
          join public.model_collection_items i on i.collection = c.id
          join public.shared_models m on m.id = i.model
         cross join asked a
         where c.public
           and m.published and m.listed and not m.barred and (not m.test or a.tests)
           and public.list_may_be_followed(c.id)
           and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
           and (a.tests or not public.trust_is_test_account(c.owner))
         group by c.id, c.name, c.description, c.owner),
    counted as (
        select s.*, (select count(*) from public.collection_follows f
                      where f.collection = s.id
                        and public.trust_may_go_public(f.follower) and public.shown_publicly(f.follower)) as followers
          from shown s),
    ordered as (
        select k.*, row_number() over (order by
                   case when (select a.sort from asked a) = 'followed' then k.followers end desc nulls last,
                   k.added desc, k.id) as n,
               count(*) over () as total
          from counted k)
    select jsonb_build_object(
        'sort', a.sort, 'page', a.page, 'size', a.size,
        'total', coalesce((select max(o.total) from ordered o), 0),
        'rows', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', o.id, 'name', o.name, 'description', o.description,
                       'count', o.models, 'followers', o.followers, 'added', o.added,
                       'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                                from public.people p where p.account = o.owner))
                   order by o.n)
              from ordered o
             where o.n > (a.page - 1) * a.size and o.n <= a.page * a.size), '[]'::jsonb))
      from asked a
$$;

revoke all on function public.collection_directory(text, integer, integer, boolean) from public, anon, authenticated;
grant execute on function public.collection_directory(text, integer, integer, boolean) to service_role;

notify pgrst, 'reload schema';
