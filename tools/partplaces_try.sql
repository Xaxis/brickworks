-- What supabase/partplaces.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/partplaces.sql --dry --try=tools/partplaces_try.sql --table=collections
--
-- A made-up account at a Resend test address, made and gone with the
-- transaction. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'partplaces-try@resend.dev');
-- Rows kept before: every one reads {} places, none null, and nothing else of theirs moved.
select count(*) as "rows", count(*) filter (where places = '{}'::jsonb) as "with places {}", count(*) filter (where places is null) as "null places" from public.collections;
-- A row made as the live api (rel-m308) makes one: sets, parts and updated_at by name; places {}.
insert into public.collections (owner, sets, parts, updated_at) values ('00000000-0000-4000-8000-0000000000f1', '[{"set": "7140-1", "qty": 1, "spares": false, "src": "hand"}]', '[{"part": "3001", "colour": 4, "qty": 12, "src": "hand"}]', now()) returning places as "made by the live api: places", rev > 0 as "a rev";
-- The new api's op place, held to the rev it read: it lands, and the rev moves on.
update public.collections set places = '{"3001/4": "drawer 3", "3023/71": "B3"}' where owner = '00000000-0000-4000-8000-0000000000f1' and rev = (select rev from public.collections where owner = '00000000-0000-4000-8000-0000000000f1') returning places as "placed", sets as "sets unchanged", parts as "parts unchanged";
-- The live api's write after it (a lot changed, as its PATCH does: sets, parts, recent, updated_at): the places stay.
update public.collections set parts = '[{"part": "3001", "colour": 4, "qty": 13, "src": "hand"}]', recent = '[]', updated_at = now() where owner = '00000000-0000-4000-8000-0000000000f1' returning places as "after the live api's write: places", parts as parts;
-- An older app's Start over goes through the api: places {} with the rest.
select pg_temp.tries($q$update public.collections set places = '[]' where owner = '00000000-0000-4000-8000-0000000000f1'$q$) as "places as a list";
select pg_temp.tries($q$update public.collections set places = '"drawer 3"' where owner = '00000000-0000-4000-8000-0000000000f1'$q$) as "places as a string";
select pg_temp.tries($q$update public.collections set places = null where owner = '00000000-0000-4000-8000-0000000000f1'$q$) as "places null";
select pg_temp.tries($q$update public.collections set places = jsonb_build_object('3001/4', repeat('x', 4000001)) where owner = '00000000-0000-4000-8000-0000000000f1'$q$) as "places over 4 MB";
select pg_temp.tries($q$update public.collections set places = (select jsonb_object_agg('p' || n || '/4', 'drawer ' || n) from generate_series(1, 20000) n) where owner = '00000000-0000-4000-8000-0000000000f1'$q$) as "20,000 places";
-- Row security as before: the policies and the grants on the table are the same.
select count(*) as "policies on collections" from pg_policies where schemaname = 'public' and tablename = 'collections'
