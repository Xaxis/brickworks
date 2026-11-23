-- What you own and what you lack (ownedparts, 2026-11-23; after lists.sql,
-- pool_rule.sql and collection_follows.sql).
--
-- The counts it needs were already kept: how many of a set a person owns is
-- each set entry's qty in their collection (collections.sets, op "own",
-- 1 to 99 by hand since this unit, api/collection.js MOST_OWNED), their
-- loose parts are collections.parts, and both are counted into one pool
-- (collection_pools, api/_owned.js poolOf: a set's parts times its copies,
-- less those kept built and the parts marked missing) that the gallery's
-- cards are measured against. So there is no new table and no new column.
-- Two functions read what is there:
--
--   owned_pool_holds(account, parts)  how many of each of [parts] (in the
--       pool's spelling: a mould's letter off) the pool holds, in every
--       colour: [[part, colour, qty]]. A model's Parts tab asks it for the
--       parts the model has, to say what the person is missing
--       (api/share.js op=parts_missing), reading a few hundred rows of the
--       pool, never all of it.
--   set_lists(set_num, tests, most)  the public lists a set is in, as
--       model_lists says a model's: {count, lists: [{id, name, count, by}]},
--       the one it was put in last first, [most] of them (1 to 48). A set's
--       page says "In N lists" from it. A list is public and its owner
--       shown publicly; a wishlist and a list taken down are never counted,
--       as the directory counts neither (lists.sql list_directory), and a
--       test account's only with [tests].
--
-- Only additions: two functions, the service role's alone, as every
-- function here. Nothing written, nothing dropped. Account deletion is as
-- it was: what these read cascades from auth.users already (collections,
-- collection_pools, model_collections, collection_sets).

create or replace function public.owned_pool_holds(account uuid, parts text[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_array(p.part, p.colour, p.qty) order by p.part, p.colour), '[]'::jsonb)
      from public.collection_pools p
     where p.owner = owned_pool_holds.account
       and cardinality(owned_pool_holds.parts) <= 5000
       and p.part = any(owned_pool_holds.parts)
$$;

create or replace function public.set_lists(set_num text, tests boolean default false, most integer default 12)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with shown as (
        select c.id, c.name, c.owner, s.at
          from public.collection_sets s
          join public.model_collections c on c.id = s.collection
         where s.set_num = lower(set_lists.set_num)
           and c.public and c.kind is null and c.taken_down_at is null
           and public.shown_publicly(c.owner)
           and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
           and (set_lists.tests or not public.trust_is_test_account(c.owner)))
    select jsonb_build_object(
        'count', (select count(*) from shown),
        'lists', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', l.id, 'name', l.name,
                       'count', public.collection_count(l.id, false, set_lists.tests)
                                + (select count(*) from public.collection_sets x where x.collection = l.id),
                       'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                                from public.people p where p.account = l.owner))
                   order by l.at desc, l.id)
              from (select * from shown order by shown.at desc, shown.id
                     limit least(greatest(coalesce(set_lists.most, 12), 1), 48)) l), '[]'::jsonb))
$$;

revoke all on function public.owned_pool_holds(uuid, text[]) from public, anon, authenticated;
grant execute on function public.owned_pool_holds(uuid, text[]) to service_role;
revoke all on function public.set_lists(text, boolean, integer) from public, anon, authenticated;
grant execute on function public.set_lists(text, boolean, integer) to service_role;

notify pgrst, 'reload schema';
