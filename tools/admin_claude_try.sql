-- What supabase/admin_claude.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept. Only counts, names and the dry run's own
-- rows are printed.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/admin_claude.sql --dry --try=tools/admin_claude_try.sql
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- The three tables are new and empty.
select (select count(*) from public.admin_claude_settings) as settings, (select count(*) from public.admin_claude_holds) as holds, (select count(*) from public.admin_claude_drafts) as drafts;
-- Row security, no policy; a page's and a visitor's roles reach none; the server's does.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads from pg_class c where c.relname in ('admin_claude_settings', 'admin_claude_holds', 'admin_claude_drafts') and c.relnamespace = 'public'::regnamespace order by 1;
-- The functions: the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'admin_claude_%' order by p.proname;
-- A key kept only sealed, with its last four characters.
select pg_temp.tries($q$insert into public.admin_claude_settings (test, key_sealed, key_last4) values (true, 'sk-ant-api03-not-sealed-at-all-0000000000000000000000', 'AAAA')$q$) as plain_key;
select pg_temp.tries($q$insert into public.admin_claude_settings (test, key_sealed) values (true, 'v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')$q$) as sealed_without_last4;
insert into public.admin_claude_settings (test, key_sealed, key_last4, cap_usd, changed_by) values (true, 'v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'AAAA', 1, 'dry-run');
select model, effort, cap_usd, key_last4 from public.admin_claude_settings where test;
-- Holds against the checks' pool's cap of $1.00: the second does not fit; settled, the next does.
create temporary table dry_holds on commit drop as select public.admin_claude_hold(true, 'claude-opus-5-5', 0.6, 1) as first, public.admin_claude_hold(true, 'claude-opus-5-5', 0.6, 1) as second;
select first -> 'ok' as first_ok, second -> 'ok' as second_ok, second -> 'held' as held_then from dry_holds;
select public.admin_claude_settle((select (first ->> 'id')::uuid from dry_holds), 0.2) as after_settle;
select public.admin_claude_hold(true, 'claude-opus-5-5', 0.6, 1) -> 'ok' as fits_after;
select public.admin_claude_month(true) as checks_month, public.admin_claude_month(false) ->> 'calls' as owner_calls;
select pg_temp.tries($q$select public.admin_claude_hold(true, 'claude-opus-5-5', -1, 1)$q$) as negative_amount;
