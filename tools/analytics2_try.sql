-- What supabase/analytics2.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept. Only names, counts, sizes and refusals
-- are printed, never a row of anybody's.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/analytics2.sql --dry --try=tools/analytics2_try.sql --table=insights_listings
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
-- The tables, the two new ones too: row security on, no policy, and no role reaching any (only the functions do).
select c.relname as table_name, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname like 'insights\_%' and c.relkind = 'r' order by c.relname;
-- The functions: the server's alone, each with an empty search path; insights_daily gone.
select p.proname as function_name, has_function_privilege('anon', p.oid, 'execute') as anon_runs, has_function_privilege('authenticated', p.oid, 'execute') as signed_in_runs, has_function_privilege('service_role', p.oid, 'execute') as server_runs, p.prosecdef as definer, p.proconfig as config from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'insights\_%' order by p.proname;
-- Every row kept so far is a test's now, and the rollup is to be made again.
select (select count(*) from public.insights_visits where not test) as people_visits, (select count(*) from public.insights_events where not test) as people_events, (select count(*) from public.insights_seen where not test) as people_seen, (select count(*) from public.insights_account_days where not test) as people_account_days, (select count(*) from public.insights_account_firsts where not test) as people_firsts, (select count(*) from public.insights_days) as days, (select count(*) from public.insights_rollups) as rollups, (select count(*) from public.insights_visits) as visits_kept;
-- A check's beacon: its view and a real control's name kept, a made-up control's too (the server's route drops it, not the database).
select public.insights_take('trytrytrytrytry1', '{"landing": "/gallery", "device": "desktop"}', '[["site", "view", "/gallery", 1]]', '["render_close"]', null, 15, true) as kept_rows;
-- That visit at its weight (1: not sampled); a listing that failed deletes nothing; a hash nobody has forgets nothing.
select (select weight from public.insights_visits where visit = 'trytrytrytrytry1') as weight, public.insights_gone('{}'::jsonb, 0) as gone_on_a_failed_listing, public.insights_forget_account('000000000000000000000000') as forgot_nobody;
-- The rows rolled up again, yesterday's, and what the owner's read weighs over 30 days, the checks' and everyone's.
select public.insights_rollup(current_date - 1, '{}'::jsonb) as rolled_yesterday, octet_length(public.insights_read(current_date - 29, current_date, true, '{}'::jsonb, '[]'::jsonb)::text) as checks_read_bytes, octet_length(public.insights_read(current_date - 29, current_date, false, '{}'::jsonb, '[]'::jsonb)::text) as peoples_read_bytes;
