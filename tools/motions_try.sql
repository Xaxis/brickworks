-- What supabase/motions.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/motions.sql --dry --try=tools/motions_try.sql --table=shared_models
--
-- After the live files, play.sql last among those that make the card. One
-- made-up account, made and gone with the transaction, 13 or over at a
-- Resend test address, so every model here is a test model, which only a
-- list asked with tests shows. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
--
--   House        its own motions: Open the gates, Open the mailbox
--   Observatory  its own motions, and its app's words for what moves
--   Racer        no motions of its own, its steering moves (play.sql's words)
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'motions-ada@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000e2', true)->>'over_13' as ada;
-- Every row there was gets an empty list: no motions said until its next publish.
select count(*) as "models", count(*) filter (where motions = '{}') as "with no motions said", count(*) filter (where motions is null) as "with no list" from public.shared_models;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, technic, moves, motions) values ('MotionTr01', '00000000-0000-4000-8000-0000000000e2', 'Motions Try House', 'Ada Try', 211, 100, true, now() - interval '1 day', true, false, '{doors}', '{"Open the gates","Open the mailbox"}'), ('MotionTr02', '00000000-0000-4000-8000-0000000000e2', 'Motions Try Observatory', 'Ada Try', 900, 100, true, now() - interval '2 days', true, true, '{turntable,gears}', '{"Open the dome","Extend the telescope","Open the back wall panels"}'), ('MotionTr03', '00000000-0000-4000-8000-0000000000e2', 'Motions Try Racer', 'Ada Try', 93, 100, true, now() - interval '3 days', true, false, '{steering}', '{}');
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, listed_at, parts, 100 from public.shared_models where id like 'MotionTr%';
-- Only names the server keeps: twelve at most, each 1 to 60 printing characters, no spaces at its ends.
select pg_temp.tries($q$update public.shared_models set motions = array_fill('Open it'::text, array[13]) where id = 'MotionTr03'$q$) as "thirteen", pg_temp.tries($q$update public.shared_models set motions = array_fill('Open it'::text, array[12]) where id = 'MotionTr03'$q$) as "twelve", pg_temp.tries($q$update public.shared_models set motions = array[repeat('a', 61)] where id = 'MotionTr03'$q$) as "61 characters", pg_temp.tries($q$update public.shared_models set motions = array[E'Open\nthe door'] where id = 'MotionTr03'$q$) as "a line break", pg_temp.tries($q$update public.shared_models set motions = array[' Open'] where id = 'MotionTr03'$q$) as "a space first", pg_temp.tries($q$update public.shared_models set motions = array[''] where id = 'MotionTr03'$q$) as "empty", pg_temp.tries($q$update public.shared_models set motions = null where id = 'MotionTr03'$q$) as "no list";
update public.shared_models set motions = '{}' where id = 'MotionTr03';
-- The card says them, beside what moves.
select c->>'id' as id, c->'motions' as motions, c->'moves' as moves from (select public.directory_card(m) as c from public.shared_models m where m.id like 'MotionTr%' order by m.id) x;
-- The gallery's list, asked with tests: each card with its motions.
select c->>'id' as id, c->'motions' as motions from public.directory_models('{"tests": true, "words": "motions:* & try:*", "size": 10}'::jsonb) c;
-- Technic or mechanism as play.sql made it: the Observatory and the Racer, not the House.
select string_agg(c->>'id', ', ' order by c->>'id') as "Technic or mechanism" from public.directory_models('{"tests": true, "technic": true, "words": "motions:* & try:*", "size": 10}'::jsonb) c;
-- A model's page reads the card: the House's page says its motions.
select public.directory_model('MotionTr01')->'motions' as "the House's page";
-- Without tests, a visitor's list: none of them.
select count(*) as "a visitor's list of test models" from public.directory_models('{"words": "motions:* & try:*", "size": 10}'::jsonb) c;
-- The week's pick and the shelves read the same card: the motions are on it.
select coalesce(w->'card' ? 'motions', false) as "the week's cards say the motions" from public.gallery_week(true, 1) w;
-- Nobody but the server: the functions the service role's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('motion_names_ok', 'directory_card') order by p.proname;
-- How long the card takes on the real tables: a visitor's first page.
create function pg_temp.timed() returns text language plpgsql as $$ declare t0 timestamptz; t1 timestamptz; begin t0 := clock_timestamp(); perform count(*) from public.directory_models('{"size": 24}'::jsonb); t1 := clock_timestamp(); return format('%s ms', round(extract(epoch from t1 - t0) * 1000, 1)); end $$;
select pg_temp.timed() as "a visitor's first page"
