-- What supabase/console3b.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept. Only counts, names and times are
-- printed, never a person's rows.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/console3b.sql --dry --try=tools/console3b_try.sql
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
-- The export: the server's alone, as its owner, with no search path to be steered by.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer, p.proconfig as config from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'admin_export';
-- The busiest test account (resend.dev): its tables, rows, and no hidden column in any row.
select u.id::text like '3d2df783%' as the_reviews_account, (select jsonb_object_agg(t.key, jsonb_array_length(t.value)) from jsonb_each(public.admin_export(u.id) -> 'tables') t) as rows_by_table, (select count(*) from jsonb_each(public.admin_export(u.id) -> 'tables') t, jsonb_array_elements(t.value) r where r ?| array['hash', 'rh', 'oc_rh', 'code_challenge', 'channel', 'secret', 'token', 'hello', 'list']) as rows_with_a_hidden_column from auth.users u where u.email ilike '%@resend.dev' order by (select count(*) from public.relay_tabs r where r.owner = u.id) desc limit 1;
-- How long that export takes in the database, three times (a function times it: a statement's clock is its start).
create function pg_temp.ms(who uuid) returns integer language plpgsql as $$ declare began timestamptz := clock_timestamp(); got jsonb; begin got := public.admin_export(who); return round(extract(epoch from (clock_timestamp() - began)) * 1000); end $$;
select pg_temp.ms(u.id) as ms_1, pg_temp.ms(u.id) as ms_2, pg_temp.ms(u.id) as ms_3 from auth.users u where u.email ilike '%@resend.dev' order by (select count(*) from public.relay_tabs r where r.owner = u.id) desc limit 1;
