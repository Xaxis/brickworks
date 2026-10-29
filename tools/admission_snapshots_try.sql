-- What supabase/admission_snapshots.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/admission_snapshots.sql --dry --try=tools/admission_snapshots_try.sql --table=admission_snapshots
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line, and a statement sees the table as it was when it began, so
-- each look after a change is a statement of its own.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- The project gives no role execute on a new function by default: the page's two may run this one, to be refused inside it.
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- Nothing that was there is touched: the table is new, and empty.
select count(*) as snapshots from public.admission_snapshots;
-- Row security, no policy for anybody, and no grant to a page's keys or the server's.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads_directly from pg_class c where c.oid = 'public.admission_snapshots'::regclass;
-- The functions: the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'admission_snapshot%' order by p.proname;
-- A snapshot written, then read back, then written over.
select public.admission_snapshot_put('admission:v2:brickworks:test:c:dry-run', '{"at":1,"value":{"plan":{"key":"free"}}}');
select public.admission_snapshot_get('admission:v2:brickworks:test:c:dry-run') as kept;
select public.admission_snapshot_put('admission:v2:brickworks:test:c:dry-run', '{"at":2,"value":{"plan":{"key":"pro"}}}');
select public.admission_snapshot_get('admission:v2:brickworks:test:c:dry-run') as kept_over, (select count(*) from public.admission_snapshots) as rows;
-- Nothing under a key that is not the client's, and none at all for a key never written.
select pg_temp.tries($q$select public.admission_snapshot_put('somebody else''s', 'x')$q$) as not_a_client_key, public.admission_snapshot_get('admission:v2:brickworks:test:c:never') as never_written;
-- A row not written for 90 days goes at the next write.
update public.admission_snapshots set updated_at = now() - interval '91 days' where key = 'admission:v2:brickworks:test:c:dry-run';
select public.admission_snapshot_put('admission:v2:brickworks:test:plans', '{"at":3}');
select (select count(*) from public.admission_snapshots where key like '%dry-run') as old_one_left, (select count(*) from public.admission_snapshots) as rows;
-- A page's keys are refused, by the table and by the functions.
set local role anon;
select pg_temp.tries('select count(*) from public.admission_snapshots') as anon_reads, pg_temp.tries($q$select public.admission_snapshot_get('admission:v2:brickworks:test:plans')$q$) as anon_gets;
reset role;
set local role authenticated;
select pg_temp.tries('select count(*) from public.admission_snapshots') as signed_in_reads, pg_temp.tries($q$select public.admission_snapshot_put('admission:v2:x', 'y')$q$) as signed_in_puts;
reset role
