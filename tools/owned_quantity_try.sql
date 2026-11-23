-- What supabase/owned_quantity.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/owned_quantity.sql --dry --try=tools/owned_quantity_try.sql --table=collection_pools
--
-- Two made-up accounts at Resend test addresses (test accounts: only an ask
-- with tests counts them), made and gone with the transaction. Each
-- statement is on one line: the dry run splits at a semicolon that ends a
-- line.
--
--   Ada's pool: 7 of 3001 in red, 2 in blue, 5 of 3794 in white, 1 of 3626bp01.
--   Ada's lists: Castles (public, 6020-1 and 7140-1), Mine (private, 6020-1),
--   her wishlist (public, 6020-1), Gone (taken down, 6020-1).
--   Bob's list Shelf (public, 6020-1), put in after Ada's.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owned-try-ada@resend.dev'), ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owned-try-bob@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000000a2', true)->>'over_13' as bob;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000a1', 'owned-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000000a2', 'owned-try-bob', 'Bob Try');
insert into public.collection_pools (owner, part, colour, qty) values ('00000000-0000-4000-8000-0000000000a1', '3001', 4, 7), ('00000000-0000-4000-8000-0000000000a1', '3001', 1, 2), ('00000000-0000-4000-8000-0000000000a1', '3794', 15, 5), ('00000000-0000-4000-8000-0000000000a1', '3626bp01', 14, 1), ('00000000-0000-4000-8000-0000000000a2', '3001', 4, 99);
-- What the pool holds of the parts a model has: only those parts, every colour; never Bob's.
select public.owned_pool_holds('00000000-0000-4000-8000-0000000000a1', array['3001', '3794', '3003']) as "Ada: 3001, 3794 and 3003";
select public.owned_pool_holds('00000000-0000-4000-8000-0000000000a1', array['3003']) as "Ada: 3003 only, none", public.owned_pool_holds('00000000-0000-4000-8000-0000000000a1', '{}') as "nothing asked", public.owned_pool_holds('00000000-0000-4000-8000-0000000000a9', array['3001']) as "nobody's pool";
select public.owned_pool_holds('00000000-0000-4000-8000-0000000000a1', (select array_agg('p' || n) from generate_series(1, 5001) n) || array['3001']) as "over 5,000 parts asked: none";
insert into public.model_collections (id, owner, name, public, kind, taken_down_at) values ('OwnTryLs01', '00000000-0000-4000-8000-0000000000a1', 'Castles', true, null, null), ('OwnTryLs02', '00000000-0000-4000-8000-0000000000a1', 'Mine', false, null, null), ('OwnTryLs03', '00000000-0000-4000-8000-0000000000a1', 'Wishlist', true, 'want', null), ('OwnTryLs04', '00000000-0000-4000-8000-0000000000a1', 'Gone', false, null, now()), ('OwnTryLs05', '00000000-0000-4000-8000-0000000000a2', 'Shelf', true, null, null);
insert into public.collection_sets (collection, set_num, at) values ('OwnTryLs01', '6020-1', now() - interval '2 days'), ('OwnTryLs01', '7140-1', now() - interval '2 days'), ('OwnTryLs02', '6020-1', now() - interval '2 days'), ('OwnTryLs03', '6020-1', now() - interval '2 days'), ('OwnTryLs04', '6020-1', now() - interval '2 days'), ('OwnTryLs05', '6020-1', now() - interval '1 day');
-- 6020-1 with tests: Shelf then Castles (newest put in first), each with its count and whose; never Mine, the wishlist or Gone.
select public.set_lists('6020-1', true) as "6020-1, tests";
select public.set_lists('6020-1', false) as "6020-1, no tests: none (test accounts)", public.set_lists('6020-1', true, 1) as "one asked", public.set_lists('9999-1', true) as "a set in none", public.set_lists('6020-1'::text) as "defaults";
-- Who may call them: the service role alone.
select p.proname, pg_get_function_identity_arguments(p.oid) as arguments, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('owned_pool_holds', 'set_lists') order by p.proname;
-- The plan of the pool's read: by its key, never the whole table.
explain select public.owned_pool_holds('00000000-0000-4000-8000-0000000000a1', array['3001']);
explain select p.part, p.colour, p.qty from public.collection_pools p where p.owner = '00000000-0000-4000-8000-0000000000a1' and p.part = any(array['3001', '3794']);
