-- What supabase/lists.sql does, tried inside the rolled-back transaction of
-- a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/lists.sql --dry --try=tools/lists_try.sql --table=collection_sets
--
-- Made-up accounts, made and gone with the transaction: Ada is 13 or over
-- with a profile, Bo too. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000011a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lists-ada@resend.dev'), ('00000000-0000-4000-8000-0000000011a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lists-bo@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000011a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000011a2', true)->>'over_13' as bo;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000011a1', 'lists-try-ada', 'Ada Lists'), ('00000000-0000-4000-8000-0000000011a2', 'lists-try-bo', 'Bo Lists');
-- Ada's castles, public, holding two sets; her wishlist, private, one set.
insert into public.model_collections (id, owner, name, public) values ('ListsTry01', '00000000-0000-4000-8000-0000000011a1', 'Castles lists try zq', true);
insert into public.model_collections (id, owner, name, public, kind) values ('ListsTry02', '00000000-0000-4000-8000-0000000011a1', 'Wishlist', false, 'want');
insert into public.collection_sets (collection, set_num, at) values ('ListsTry01', '10305-1', now() - interval '2 days'), ('ListsTry01', '6080-1', now() - interval '1 day'), ('ListsTry02', '10497-1', now());
-- The rules, whatever writes.
select pg_temp.tries($q$insert into public.model_collections (id, owner, name, kind) values ('ListsTry03', '00000000-0000-4000-8000-0000000011a1', 'Second wishlist', 'want')$q$) as "a second wishlist", pg_temp.tries($q$insert into public.model_collections (id, owner, name, kind) values ('ListsTry04', '00000000-0000-4000-8000-0000000011a2', 'Bo wants', 'want')$q$) as "Bo's own wishlist", pg_temp.tries($q$insert into public.model_collections (id, owner, name, kind) values ('ListsTry05', '00000000-0000-4000-8000-0000000011a1', 'Odd', 'shelf')$q$) as "a kind not known";
select pg_temp.tries($q$update public.model_collections set sort = 'random' where id = 'ListsTry01'$q$) as "a sort not known", pg_temp.tries($q$update public.model_collections set cover = 'set:10305-1' where id = 'ListsTry01'$q$) as "a set as cover", pg_temp.tries($q$update public.model_collections set cover = 'javascript:x' where id = 'ListsTry01'$q$) as "a cover not an item";
select pg_temp.tries($q$insert into public.collection_sets (collection, set_num) values ('ListsTry01', 'NOT A SET')$q$) as "a set not a number", pg_temp.tries($q$insert into public.collection_sets (collection, set_num) values ('ListsTry01', '10305-1')$q$) as "a set twice";
-- In its order: the last put in first, then as Ada dragged it.
select public.list_items('ListsTry01', false, false) as "castles, newest first";
update public.model_collections set sort = 'manual' where id = 'ListsTry01';
update public.collection_sets set position = case set_num when '10305-1' then 0 else 1 end where collection = 'ListsTry01';
select public.list_items('ListsTry01', false, false) as "castles, in Ada's order";
-- The directory: her public castles with its two sets, never her wishlist.
select r->>'name' as name, r->>'count' as count, r->>'sets' as sets, r->>'models' as models from jsonb_array_elements((public.list_directory('lists try zq', 'recent', 1, 24, true))->'rows') as r;
select count(*) as "wishlists in the directory" from jsonb_array_elements((public.list_directory('', 'recent', 1, 48, true))->'rows') as r where r->>'id' = 'ListsTry02';
-- Taken down: private, and never public again.
select pg_temp.tries($q$update public.model_collections set taken_down_at = now() where id = 'ListsTry01'$q$) as "taken down while public", pg_temp.tries($q$update public.model_collections set taken_down_at = now(), public = false where id = 'ListsTry01'$q$) as "taken down and made private";
select pg_temp.tries($q$update public.model_collections set public = true where id = 'ListsTry01'$q$) as "public again after taken down";
select count(*) as "taken down in the directory" from jsonb_array_elements((public.list_directory('lists try zq', 'recent', 1, 24, true))->'rows') as r;
-- The sets you own on your profile: off until chosen.
insert into public.profile_shows (account) values ('00000000-0000-4000-8000-0000000011a1');
select owned as "Ada's sets shown, at first" from public.profile_shows where account = '00000000-0000-4000-8000-0000000011a1';
-- Nobody but the server.
select has_table_privilege('anon', 'public.collection_sets', 'select') as "anon may read", has_table_privilege('authenticated', 'public.collection_sets', 'select') as "authenticated may read", has_table_privilege('service_role', 'public.collection_sets', 'insert') as "the server may write", has_function_privilege('anon', 'public.list_directory(text, text, integer, integer, boolean)', 'execute') as "anon may list";
-- Deleting the list deletes its sets.
delete from public.model_collections where id = 'ListsTry02';
select count(*) as "the wishlist's sets after it is deleted" from public.collection_sets where collection = 'ListsTry02';
-- Put in Ada's order: 6080 first, then 10305; a set not in it is not added.
insert into public.collection_sets (collection, set_num) values ('ListsTry01', '10497-1');
select public.list_place('ListsTry01', array['set:6080-1', 'set:10305-1', 'set:75192-1']) as "placed";
select public.list_items('ListsTry01', true, false) as "castles, placed";
select count(*) as "75192 in the castles after placing" from public.collection_sets where collection = 'ListsTry01' and set_num = '75192-1';
