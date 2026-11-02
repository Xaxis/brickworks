-- Searching the collections, 2026-11-02 (browse): the gallery's Collections tab.
--
-- The gallery, its sets, its builds and its collections became one page
-- whose tabs switch in place, with one search box that searches the tab it
-- is on (the owner, 2026-11-02: "one is just a tab in another"). The
-- directory (collection_directory.sql) could list the public collections
-- but not search them.
--
--   collection_directory_search(q, sort, page, size, tests)
--       collection_directory's page, of the collections whose name, words,
--       owner's handle or owner's name hold every word of [q] (up to eight
--       words of the first 100 characters, any case). The same rows, in
--       the same shape and order, as collection_directory gives, by the
--       same rules: a public collection whose owner may be followed and is
--       not taken out, with at least one model in the gallery; a private
--       one never.
--
-- Only an addition, applied after collection_directory.sql (and what it
-- reads): one new function, security definer and the service role's
-- alone. collection_directory is not changed; a new name, not an overload,
-- so a call that names collection_directory's four arguments still finds
-- the one function.

create or replace function public.collection_directory_search(q text, sort text default 'recent', page integer default 1,
                                                               size integer default 24, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (
        select least(greatest(coalesce(collection_directory_search.size, 24), 1), 48) as size,
               greatest(coalesce(collection_directory_search.page, 1), 1) as page,
               coalesce(collection_directory_search.tests, false) as tests,
               case when collection_directory_search.sort = 'followed' then 'followed' else 'recent' end as sort,
               coalesce((select array_agg(w) from (
                   select w from regexp_split_to_table(lower(left(coalesce(collection_directory_search.q, ''), 100)), '\s+') as w
                    where w <> '' limit 8) as words), '{}'::text[]) as words),
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

revoke all on function public.collection_directory_search(text, text, integer, integer, boolean) from public, anon, authenticated;
grant execute on function public.collection_directory_search(text, text, integer, integer, boolean) to service_role;

notify pgrst, 'reload schema';
