-- What supabase/analytics.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept. Only names, counts and refusals are
-- printed, never a row of anybody's (the tables are new: what is in them
-- here is what this file put in).
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/analytics.sql --dry --try=tools/analytics_try.sql --table=insights_visits
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
-- The tables: row security on, no policy, and no role reaching any, the server's neither (only the functions do).
select c.relname as table_name, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname like 'insights\_%' and c.relkind = 'r' order by c.relname;
-- The functions: the server's alone, each with an empty search path.
select p.proname as function_name, has_function_privilege('anon', p.oid, 'execute') as anon_runs, has_function_privilege('authenticated', p.oid, 'execute') as signed_in_runs, has_function_privilege('service_role', p.oid, 'execute') as server_runs, p.prosecdef as definer, p.proconfig as config from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'insights\_%' order by p.proname;
-- Nothing names an account of the site: an account is only its hash.
select count(*) as foreign_keys_to_accounts from pg_constraint c join pg_class r on r.oid = c.conrelid where r.relname like 'insights\_%' and c.contype = 'f' and c.confrelid = 'auth.users'::regclass;
-- A check's beacon kept (test), one with an address in a name refused whole, and one with a bad visit id.
select public.insights_take('trytrytrytrytry1', '{"landing": "/gallery", "device": "desktop"}', '[["site", "view", "/gallery", 1], ["studio", "tool", "paint", 2]]', '[]', null, 15, true) as kept_rows, public.insights_take('trytrytrytrytry2', '{"landing": "/m/ada@example.com"}', '[["site", "view", "/", 1]]', '[]', null, 0, true) as with_an_address, public.insights_take('Not-An-Id', '{}', '[["site", "view", "/", 1]]', '[]', null, 0, true) as bad_visit;
-- The address let go: the beacon's view kept, its landing none; no row anywhere holds an @.
select (select landing from public.insights_visits where visit = 'trytrytrytrytry2') as landing_kept, (select count(*) from public.insights_visits where landing like '%@%' or source like '%@%') + (select count(*) from public.insights_events where name like '%@%') as rows_with_an_at;
-- The read of the checks' own, only sums; and of production's, which this file left empty.
select r.read -> 'range' as checks_range, jsonb_array_length(coalesce(r.read -> 'days', '[]')) as checks_days, r.read -> 'funnel' as checks_funnel, jsonb_array_length(coalesce(p.read -> 'days', '[]')) as production_days from (select public.insights_read(current_date - 1, current_date, true, '{}', '[]') as read) r, (select public.insights_read(current_date - 1, current_date, false, '{}', '[]') as read) p;
-- The daily run: nothing to roll on a project with no day over yet, nothing past 30 days.
select public.insights_daily('{}') as daily;
-- What the console's read costs on the planner: today's raw rows by day.
explain (costs off) select count(*) from public.insights_events where day = current_date and test = false;
