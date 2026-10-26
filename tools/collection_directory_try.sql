-- What supabase/collection_directory.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/collection_directory.sql --dry --try=tools/collection_directory_try.sql
--
-- After the live files. Made-up accounts at Resend test addresses, so test
-- accounts, made and gone with the transaction: Ada and Bob, 13 or over with
-- profiles; Eve, taken out of the gallery. Ada's tower is in the gallery (a
-- test model). Collections: Ada's public one, her private one and an empty
-- public one; Bob's public one with Ada's tower in it, followed by Ada; Eve's
-- public one. Inside one transaction now() never moves, so the times are
-- set by hand. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000265a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dirtry-ada@resend.dev'), ('00000000-0000-4000-8000-0000000265b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dirtry-bob@resend.dev'), ('00000000-0000-4000-8000-0000000265e5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dirtry-eve@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000265a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000265b2', true)->>'over_13' as bob, public.answer_age('00000000-0000-4000-8000-0000000265e5', true)->>'over_13' as eve;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000265a1', 'dirtry-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000265b2', 'dirtry-bob', 'Bob Try'), ('00000000-0000-4000-8000-0000000265e5', 'dirtry-eve', 'Eve Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('DirTryM001', '00000000-0000-4000-8000-0000000265a1', 'Try tower', 'Ada Try', 3, 100, true, now() - interval '1 day', true, now() - interval '1 day', true);
insert into public.share_versions (model, n, at, parts, bytes) values ('DirTryM001', 1, now() - interval '1 day', 3, 100);
insert into public.model_collections (id, owner, name, public) values ('DirTryC001', '00000000-0000-4000-8000-0000000265a1', 'Ada public', true), ('DirTryC002', '00000000-0000-4000-8000-0000000265a1', 'Ada private', false), ('DirTryC003', '00000000-0000-4000-8000-0000000265a1', 'Ada empty', true), ('DirTryC004', '00000000-0000-4000-8000-0000000265b2', 'Bob public', true), ('DirTryC005', '00000000-0000-4000-8000-0000000265e5', 'Eve public', true);
insert into public.model_collection_items (collection, model, at) values ('DirTryC001', 'DirTryM001', now() - interval '1 hour'), ('DirTryC002', 'DirTryM001', now() - interval '10 minutes'), ('DirTryC004', 'DirTryM001', now() - interval '2 hours'), ('DirTryC005', 'DirTryM001', now() - interval '5 minutes');
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000265e5', 'collection directory try');
select public.list_follow('00000000-0000-4000-8000-0000000265a1', 'DirTryC004', true)->>'followers' as "Ada follows Bob's";
-- Ours, newest put in first: Ada's public (an hour ago), then Bob's (two hours ago). Never the private one, the empty one or the barred owner's.
select r->>'id' as id, r->>'name' as name, r->>'count' as count, r->>'followers' as followers, r->'by'->>'handle' as by from jsonb_array_elements(public.collection_directory('recent', 1, 48, true)->'rows') r where r->>'id' like 'DirTry%';
-- Most followed first: Bob's (1 follower) before Ada's.
select r->>'id' as id, r->>'followers' as followers from jsonb_array_elements(public.collection_directory('followed', 1, 48, true)->'rows') r where r->>'id' like 'DirTry%';
-- Never shown, with or without tests: the private, the empty and the barred owner's.
select (select count(*) from jsonb_array_elements(public.collection_directory('recent', 1, 48, true)->'rows') r where r->>'id' in ('DirTryC002', 'DirTryC003', 'DirTryC005')) as "never shown (with tests)", (select count(*) from jsonb_array_elements(public.collection_directory('recent', 1, 48, false)->'rows') r where r->>'id' like 'DirTry%') as "a test account's, without tests";
-- Pages: one a page, ours the first two in recent order among whatever else is there.
select public.collection_directory('recent', 1, 1, true)->>'total' as total, jsonb_array_length(public.collection_directory('recent', 1, 1, true)->'rows') as "a page of one", public.collection_directory('nonsense', 0, 500, true)->>'sort' as "an unknown sort is recent", public.collection_directory('nonsense', 0, 500, true)->>'size' as "size kept to 48", public.collection_directory('nonsense', 0, 500, true)->>'page' as "page at least 1";
-- Made private: gone.
update public.model_collections set public = false where id = 'DirTryC001';
select count(*) as "Ada's public, made private" from jsonb_array_elements(public.collection_directory('recent', 1, 48, true)->'rows') r where r->>'id' = 'DirTryC001';
-- The server's alone.
select has_function_privilege('anon', 'public.collection_directory(text, integer, integer, boolean)', 'execute') as anon, has_function_privilege('authenticated', 'public.collection_directory(text, integer, integer, boolean)', 'execute') as authenticated, has_function_privilege('service_role', 'public.collection_directory(text, integer, integer, boolean)', 'execute') as service_role
