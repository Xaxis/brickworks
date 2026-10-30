-- What supabase/gallery_crons.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/gallery_crons.sql --dry --try=tools/gallery_crons_try.sql --table=gallery_features
--
-- One made-up account at an address that is not a test's, made and gone
-- with the transaction, so its two models are a visitor's gallery's: Kiln,
-- liked twice, built once and commented on this week; Quay, listed and
-- nothing else. Inside one transaction now() never moves, so a lease is
-- ended by hand. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000003c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'crons-try-ada@example.org'), ('00000000-0000-4000-8000-0000000003c2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'crons-try-bob@example.org');
select public.answer_age('00000000-0000-4000-8000-0000000003c1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000003c2', true)->>'over_13' as bob;
insert into public.shared_models (id, owner, name, author, parts, bytes, has_image, listed, listed_at, test) values ('CronTry001', '00000000-0000-4000-8000-0000000003c1', 'Crons Try Kiln', 'Ada Try', 120, 100, true, true, now() - interval '3 days', false), ('CronTry002', '00000000-0000-4000-8000-0000000003c1', 'Crons Try Quay', 'Ada Try', 80, 100, true, true, now() - interval '1 day', false);
insert into public.model_likes (model, account) values ('CronTry001', '00000000-0000-4000-8000-0000000003c1'), ('CronTry001', '00000000-0000-4000-8000-0000000003c2');
insert into public.model_builds (model, device) values ('CronTry001', repeat('c', 32));
insert into public.model_comments (model, version, author, body) values ('CronTry001', 1, '00000000-0000-4000-8000-0000000003c2', 'Lovely kiln');
-- The signals: Kiln 2 likes, 1 build, 1 comment; Quay none, but listed.
select s->>'id' as id, s->>'likes' as likes, s->>'builds' as builds, s->>'comments' as comments, s->>'remixes' as remixes, s->>'has_image' as pictured from public.gallery_feature_signals(30, 300) s where s->>'id' like 'CronTry%' order by 1;
-- The lock: the first run takes it, a second meanwhile is locked and written down so.
select public.cron_begin('gallery_feature', 'try-a', 300) as first;
select public.cron_begin('gallery_feature', 'try-b', 300) as second;
select job, holder, outcome, finished_at is not null as ended from public.cron_runs where holder like 'try-%' order by id;
-- The first ends: its lock goes, and the next run takes it.
select public.cron_end((select id from public.cron_runs where holder = 'try-a'), 'try-a', 'done', '{"featured": "CronTry001"}') as ended;
select public.cron_end((select id from public.cron_runs where holder = 'try-a'), 'try-a', 'done', '{}') as ended_twice;
select public.cron_begin('gallery_feature', 'try-c', 300) as after;
-- A lease that ran out is taken by the next run, its holder never having ended.
update public.cron_locks set until = now() - interval '1 second' where job = 'gallery_feature';
select public.cron_begin('gallery_feature', 'try-d', 300) as after_lease;
select r->>'holder' as holder, r->>'outcome' as outcome from public.cron_runs_of('gallery_feature', 5) r;
-- A day's choice is kept once: the second call keeps the first.
select public.gallery_feature_keep('featured', current_date, 'CronTry001', '{"score": 9}') as first_keep;
select public.gallery_feature_keep('featured', current_date, 'CronTry002', '{"score": 1}') as second_keep;
select public.gallery_feature_keep('featured', current_date + 1, 'NotThere01', '{}') as unknown;
select public.gallery_feature_keep('library', current_date, 'omr-10179-1', '{"theme": "Star Wars", "decade": "2000s"}') as library;
select public.gallery_feature_keep('pick', date_trunc('week', current_date)::date, 'CronTry002', '{}') ->> 'made' as pick_made;
select pg_temp.tries($q$ insert into public.gallery_features (slot, day, item) values ('pick', date_trunc('week', current_date)::date + 2, 'CronTry001') $q$) as pick_on_a_wednesday;
-- What the front reads now.
select n->'featured'->'card'->>'id' as featured, n->'pick'->'card'->>'id' as pick, n->'pick'->'week' as pick_week, n->'library'->>'item' as library from public.gallery_features_now(false) n;
select f->>'item' as item from public.gallery_features_since('featured', current_date - 28) f;
-- Kiln leaves the gallery: the front stops showing it.
update public.shared_models set listed = false where id = 'CronTry001';
select n->'featured' as featured_after_unlisting from public.gallery_features_now(false) n;
-- The OMR's arrivals: found once, the same stamp again changes nothing, a newer stamp finds it again.
select public.library_arrivals_found('[{"page": 4515, "set_number": "31153-1", "name": "Modern House", "file": "https://library.ldraw.org/media/omr_models/1858/31153-1.mpd", "stamp": 1770147417, "author": "Johann Eisner [technicbasics]"}]') as found;
select public.library_arrivals_found('[{"page": 4515, "set_number": "31153-1", "name": "Modern House", "file": "https://library.ldraw.org/media/omr_models/1858/31153-1.mpd", "stamp": 1770147417, "author": "Johann Eisner [technicbasics]"}]') as same_stamp;
select public.library_arrival_set(4515, 'staged', '[{"id": "omr-31153-1"}]') as staged;
select (select count(*) from public.library_arrival_entries(false)) as visitors_see, (select count(*) from public.library_arrival_entries(true)) as tests_see;
select public.library_arrivals_found('[{"page": 4515, "set_number": "31153-1", "name": "Modern House", "file": "https://library.ldraw.org/media/omr_models/1858/31153-1.mpd", "stamp": 1780000000, "author": "Johann Eisner [technicbasics]"}]') as newer_stamp;
select a->>'state' as state, a->'entries' as entries from public.library_arrivals_in(null) a where (a->>'page')::int = 4515;
select pg_temp.tries($q$ select public.library_arrival_set(4515, 'refused', null, null) $q$) as refused_with_no_why_says_refused;
-- Nobody but the server.
select has_table_privilege('anon', 'public.gallery_features', 'select') as anon_reads_features, has_table_privilege('authenticated', 'public.cron_runs', 'select') as signed_in_reads_runs, has_table_privilege('service_role', 'public.library_arrivals', 'select') as service_reads_arrivals, has_function_privilege('anon', 'public.cron_begin(text, text, integer)', 'execute') as anon_locks, has_function_privilege('service_role', 'public.gallery_features_now(boolean)', 'execute') as server_reads_front;
