-- What supabase/play.sql does, tried inside the rolled-back transaction of
-- a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/play.sql --dry --try=tools/play_try.sql --table=shared_models
--
-- After the live files (trust, tested, comments, builds, versions,
-- follows, discovery), which the project has: play.sql's directory_models
-- is discovery.sql's. One made-up account, made and gone with the
-- transaction, 13 or over at a Resend test address, so every model here is
-- a test model, which only a list asked with tests shows. Each statement is
-- on one line: the dry run splits at a semicolon that ends a line.
--
--   Racer   Technic parts too few to say so, its steering moves
--   Crane   Technic by its parts, and nothing said to move (published before)
--   House   its doors open
--   Hut     nothing moves
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'play-ada@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000e1', true)->>'over_13' as ada;
-- Every row there was gets an empty list: nothing is said to move until its next publish.
select count(*) as "models", count(*) filter (where moves = '{}') as "with nothing said to move", count(*) filter (where moves is null) as "with no list" from public.shared_models;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, technic, moves) values ('PlayTry001', '00000000-0000-4000-8000-0000000000e1', 'Play Try Racer', 'Ada Try', 93, 100, true, now() - interval '1 day', true, false, '{steering}'), ('PlayTry002', '00000000-0000-4000-8000-0000000000e1', 'Play Try Crane', 'Ada Try', 300, 100, true, now() - interval '2 days', true, true, '{}'), ('PlayTry003', '00000000-0000-4000-8000-0000000000e1', 'Play Try House', 'Ada Try', 200, 100, true, now() - interval '3 days', true, false, '{doors}'), ('PlayTry004', '00000000-0000-4000-8000-0000000000e1', 'Play Try Hut', 'Ada Try', 40, 100, true, now() - interval '4 days', true, false, '{}');
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, listed_at, parts, 100 from public.shared_models where id like 'PlayTry%';
-- Only the app's words, eight at most.
select pg_temp.tries($q$update public.shared_models set moves = '{wings}' where id = 'PlayTry004'$q$) as "a word the app does not say", pg_temp.tries($q$update public.shared_models set moves = '{steering,turntable,boom,doors,gears,pneumatics,actuator,rack,steering}' where id = 'PlayTry004'$q$) as "nine words", pg_temp.tries($q$update public.shared_models set moves = '{boom,gears}' where id = 'PlayTry004'$q$) as "a boom and gears";
update public.shared_models set moves = '{}' where id = 'PlayTry004';
-- A mechanism is any word but doors.
select public.moves_mechanism('{steering}') as steering, public.moves_mechanism('{doors}') as doors, public.moves_mechanism('{doors,gears}') as "doors and gears", public.moves_mechanism('{}') as nothing, public.moves_mechanism(null) as "no list";
-- The card says what moves.
select c->>'id' as id, c->'moves' as moves, c->>'technic' as technic from (select public.directory_card(m) as c from public.shared_models m where m.id like 'PlayTry%' order by m.id) x;
-- Technic or mechanism: the Racer by its steering, the Crane by its parts; not the House, nor the Hut.
select string_agg(c->>'id', ', ' order by c->>'id') as "Technic or mechanism" from public.directory_models('{"tests": true, "technic": true, "words": "play:* & try:*", "size": 10}'::jsonb) c;
select string_agg(c->>'id', ', ' order by c->>'id') as "everything" from public.directory_models('{"tests": true, "words": "play:* & try:*", "size": 10}'::jsonb) c;
select c->>'id' as id, c->'moves' as moves from public.directory_models('{"tests": true, "words": "play:* & try:*", "size": 10}'::jsonb) c;
-- Without tests, a visitor's list: none of them.
select count(*) as "a visitor's Technic or mechanism of test models" from public.directory_models('{"technic": true, "words": "play:* & try:*", "size": 10}'::jsonb) c;
-- The other sorts and filters as discovery.sql made them: Top builds, small, newest.
select string_agg(c->>'id', ', ') as "top, small" from public.directory_models('{"tests": true, "sort": "top", "most": 199, "words": "play:* & try:*", "size": 10}'::jsonb) c;
-- The week's pick and the shelves read the same card: what moves is on it.
select coalesce(w->'card' ? 'moves', false) as "the week's cards say what moves" from public.gallery_week(true, 1) w;
-- Nobody but the server: the functions the service role's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('moves_mechanism', 'directory_card', 'directory_models') order by p.proname;
-- How long the filter takes on the real tables: Technic or mechanism, a visitor's first page.
create function pg_temp.timed() returns text language plpgsql as $$ declare t0 timestamptz; t1 timestamptz; begin t0 := clock_timestamp(); perform count(*) from public.directory_models('{"technic": true, "size": 24}'::jsonb); t1 := clock_timestamp(); return format('%s ms', round(extract(epoch from t1 - t0) * 1000, 1)); end $$;
select pg_temp.timed() as "Technic or mechanism, a visitor's first page"
