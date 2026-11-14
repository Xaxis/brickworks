-- What supabase/console2.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/console2.sql --dry --try=tools/console2_try.sql
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- Nothing that was there is touched: the three tables are new and empty, and every pick counts 0 calls.
select (select count(*) from public.mail_events) as mail_events, (select count(*) from public.site_releases) as releases, (select count(*) from public.relay_call_days) as call_days, (select count(*) from public.relay_picks) as picks, (select count(*) from public.relay_picks where calls <> 0) as picks_counted;
-- Row security, no policy; no grant to a page's keys.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads_directly from pg_class c where c.relname in ('mail_events', 'site_releases', 'relay_call_days') and c.relnamespace = 'public'::regnamespace order by 1;
-- The functions: the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('mail_event_keep', 'admin_mail', 'site_release_live', 'site_releases_list', 'relay_call_note', 'cron_noted', 'admission_customers') order by p.proname;
-- A mail's events kept once, and read back beside what was kept as sent.
select public.mail_event_keep('dry_1', 'dryrun-mail', 'sent', now(), 'delivered@resend.dev', 'Dry run', 'canary', null, true) as first, public.mail_event_keep('dry_1', 'dryrun-mail', 'sent', now(), 'delivered@resend.dev', 'Dry run', 'canary', null, true) as again;
select public.mail_event_keep('dry_2', 'dryrun-mail', 'delivered', now(), 'delivered@resend.dev', 'Dry run', 'canary', null, true) as delivered;
select jsonb_array_length(m->'mails') as test_mails, m->'mails'->0->'states' as states, jsonb_array_length(m->'kept') as kept_rows, m->'heard' is not null as heard from (select public.admin_mail(30, true, 50) as m) x;
select jsonb_array_length(m->'mails') as real_mails, jsonb_array_length(m->'kept') as real_kept_rows from (select public.admin_mail(30, false, 50) as m) x;
-- The live release kept, and listed.
select public.site_release_live('rel-dryrun', '9c1b25131', 'A dry run', array['console2'], now()) as kept;
select public.site_releases_list(5) as listed;
-- A call counted against a pick that is not there: nothing, and no day kept.
select public.relay_call_note('session:dry-run-none', 'look_at_model') as counted, (select count(*) from public.relay_call_days) as call_days;
-- A cron with no lock written down, and read by cron_runs_of.
select public.cron_noted('dry_run_job', 'dry run', now(), 'done', '{"said":"dry"}'::jsonb) > 0 as noted;
select public.cron_runs_of('dry_run_job', 3) as runs;
-- Admission's customers in test and live mode, from its snapshots (no address in them).
select jsonb_array_length(public.admission_customers('test', 2000)) as test_customers, jsonb_array_length(public.admission_customers('live', 2000)) as live_customers;
-- A page's keys are refused, by the tables and by the functions.
set local role anon;
select pg_temp.tries($q$select count(*) from public.mail_events$q$) as anon_reads_mail, pg_temp.tries($q$select public.admin_mail(30, false, 5)$q$) as anon_calls_admin_mail, pg_temp.tries($q$select public.relay_call_note('x', 'y')$q$) as anon_counts;
reset role;
set local role authenticated;
select pg_temp.tries($q$select count(*) from public.site_releases$q$) as signed_in_reads_releases, pg_temp.tries($q$select public.site_release_live('rel-x', 'abcdef1', null, '{}', now())$q$) as signed_in_ships;
reset role;
