-- What supabase/gallery_tabs.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/gallery_tabs.sql --dry --try=tools/gallery_tabs_try.sql --table=shared_models
--
-- Three made-up accounts, made and gone with the transaction, 13 or over at
-- Resend test addresses, so every model here is a test model, which only a
-- list asked with tests shows. Ada designs, Bob follows her, Cy follows
-- nobody. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line.
--
--   Tower  tagged ai-designed, built twice today, Tested, two comments (one hidden)
--   Wall   no tags, built once 20 days ago
--   Hut    tagged brickify, listed 40 days ago, nothing since
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gallery-tabs-ada@resend.dev'), ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gallery-tabs-bob@resend.dev'), ('00000000-0000-4000-8000-0000000000a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'gallery-tabs-cy@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000000a2', true)->>'over_13' as bob, public.answer_age('00000000-0000-4000-8000-0000000000a3', true)->>'over_13' as cy;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000a1', 'gallery-tabs-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000000a2', 'gallery-tabs-bob', 'Bob Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, tags) values ('GalTabs001', '00000000-0000-4000-8000-0000000000a1', 'Gallery Tabs Tower', 'Ada Try', 120, 100, true, now() - interval '2 days', true, '{tower,ai-designed}'), ('GalTabs002', '00000000-0000-4000-8000-0000000000a1', 'Gallery Tabs Wall', 'Ada Try', 180, 100, true, now() - interval '25 days', true, '{wall}'), ('GalTabs003', '00000000-0000-4000-8000-0000000000a1', 'Gallery Tabs Hut', 'Ada Try', 60, 100, true, now() - interval '40 days', true, '{hut,brickify}');
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, listed_at, parts, 100 from public.shared_models where id like 'GalTabs%';
insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) values ('GalTabs001', 1, '0.3.0', repeat('a', 64), 120, 3, '{"stands": {"ok": true, "why": "Try"}, "steps": {"ok": true, "why": "Try"}, "parts": {"ok": true, "why": "Try"}, "whole": {"ok": true, "why": "Try"}}', true);
select public.count_build('GalTabs001', repeat('1', 32)) and public.count_build('GalTabs001', repeat('2', 32)) as tower, public.count_build('GalTabs002', repeat('1', 32)) as wall;
update public.model_builds set at = now() - interval '20 days' where model = 'GalTabs002';
select public.follow_person('00000000-0000-4000-8000-0000000000a2', 'gallery-tabs-ada', true)->>'followers' as "Bob follows Ada";
insert into public.model_comments (model, version, author, body) values ('GalTabs001', 1, '00000000-0000-4000-8000-0000000000a2', 'Try: lovely tower'), ('GalTabs001', 1, '00000000-0000-4000-8000-0000000000a3', 'Try: hidden by its owner');
update public.model_comments set hidden_at = now() where body = 'Try: hidden by its owner';
-- The card says its comments, as a visitor reads them: the hidden one not.
select c->>'id' as id, c->>'comments' as comments, c->>'tested' as tested, c->'tags' as tags from (select public.directory_card(m) as c from public.shared_models m where m.id like 'GalTabs%' order by m.id) x;
-- Top over all time, this month and this week: Tower (2 builds, Tested), then Wall; the Hut is in all time alone.
select string_agg(c->>'name', ', ' order by o) as "Top, all time" from public.gallery_models('{"tests": true, "sort": "top", "words": "gallery:* & tabs:*"}'::jsonb) with ordinality as t(c, o);
select string_agg(c->>'name', ', ' order by o) as "Top, 30 days" from public.gallery_models('{"tests": true, "sort": "top", "days": 30, "words": "gallery:* & tabs:*"}'::jsonb) with ordinality as t(c, o);
select string_agg(c->>'name', ', ' order by o) as "Top, 7 days" from public.gallery_models('{"tests": true, "sort": "top", "days": 7, "words": "gallery:* & tabs:*"}'::jsonb) with ordinality as t(c, o);
-- How it was made, from the tags: the Tower (ai-designed) and the Hut (brickify) with the assistant; the Wall by hand.
select string_agg(c->>'name', ', ' order by c->>'name') as "with the assistant" from public.gallery_models('{"tests": true, "made": "assistant", "words": "gallery:* & tabs:*"}'::jsonb) c;
select string_agg(c->>'name', ', ' order by c->>'name') as "by hand" from public.gallery_models('{"tests": true, "made": "hand", "words": "gallery:* & tabs:*"}'::jsonb) c;
-- Following: Bob sees Ada's three, newest first; Cy follows nobody and sees none; nobody asked, all three.
select string_agg(c->>'name', ', ' order by o) as "Bob's Following" from public.gallery_models('{"tests": true, "following": "00000000-0000-4000-8000-0000000000a2", "words": "gallery:* & tabs:*"}'::jsonb) with ordinality as t(c, o);
select count(*) as "Cy's Following" from public.gallery_models('{"tests": true, "following": "00000000-0000-4000-8000-0000000000a3"}'::jsonb) c;
-- An uncredited model of Ada's is tied to nobody: never in a Following.
update public.shared_models set author = null where id = 'GalTabs003';
select string_agg(c->>'name', ', ' order by o) as "Bob's Following, the Hut uncredited" from public.gallery_models('{"tests": true, "following": "00000000-0000-4000-8000-0000000000a2", "words": "gallery:* & tabs:*"}'::jsonb) with ordinality as t(c, o);
update public.shared_models set author = 'Ada Try' where id = 'GalTabs003';
-- A visitor's list: none of the test models, Following or not.
select count(*) as "a visitor's list of test models" from public.gallery_models('{"words": "gallery:* & tabs:*"}'::jsonb) c;
-- With no new word, the list is directory_models' answer, card for card, on the real tables.
select q::text as asked, (select coalesce(jsonb_agg(c), '[]') from public.gallery_models(q) c) = (select coalesce(jsonb_agg(c), '[]') from public.directory_models(q) c) as "the same as directory_models" from (values ('{}'::jsonb), ('{"tests": true}'), ('{"sort": "top"}'), ('{"tests": true, "sort": "top", "size": 49}'), ('{"sort": "builds"}'), ('{"sort": "likes"}'), ('{"sort": "remixes"}'), ('{"sort": "views"}'), ('{"technic": true}'), ('{"tested": true, "tests": true}'), ('{"words": "castle:*"}'), ('{"kind": "vehicle"}'), ('{"tests": true, "skip": 2, "size": 3}'), ('{"most": 199, "sort": "top"}')) v(q);
-- Nobody but the server: the functions the service role's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('gallery_models', 'directory_card') order by p.proname;
-- How long a page takes on the real tables: a visitor's first page of Top, all time and this week.
create function pg_temp.timed(q jsonb) returns text language plpgsql as $$ declare t0 timestamptz; t1 timestamptz; begin t0 := clock_timestamp(); perform count(*) from public.gallery_models(q); t1 := clock_timestamp(); return format('%s ms', round(extract(epoch from t1 - t0) * 1000, 1)); end $$;
select pg_temp.timed('{"size": 25, "sort": "top"}') as "Top, all time", pg_temp.timed('{"size": 25, "sort": "top", "days": 7}') as "Top, this week", pg_temp.timed('{"size": 25, "sort": "newest"}') as "New"
