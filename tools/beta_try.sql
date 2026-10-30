-- What supabase/beta.sql does, tried inside the rolled-back transaction of
-- a dry run on the live project: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/beta.sql --dry --try=tools/beta_try.sql --table=beta_applications
--
-- The shared test account (delivered+brickworks-tests@resend.dev) applies,
-- into the checks' own pool, and is approved; the real pool's 100 are only
-- read. It was made on 2026-10-11, before 29 October, so it is approved
-- without a spot (early) and its month is never asked of Admission. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line. Two approvals at once cannot be shown in one
-- transaction: tests/fixtures/beta/db_check.mjs shows them on a Postgres of
-- its own (tests/test_beta.py).
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- The project gives no role execute on a new function by default: the page's two may run this one, to be refused inside it.
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- Nothing that was there is touched: the tables are new and empty, the pools as made.
select (select count(*) from public.beta_applications) as applications, (select count(*) from public.beta_decisions) as decisions, (select count(*) from public.beta_mail) as mail, (select json_agg(json_build_object('pool', pool, 'cap', cap, 'given', given) order by pool) from public.beta_pools) as pools;
-- Row security on, no policy, and no grant to a page's keys or the server's own.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads_directly from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname like 'beta\_%' and c.relkind = 'r' order by 1;
-- The functions: the server's alone, each security definer with an empty search path.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'beta\_%' order by 1;
-- The client_exposure check (supabase/client_exposure.sql) still finds nothing a page's key could reach.
select public.client_exposure() as exposure;
-- The real pool, as a visitor's page reads it.
select public.beta_status(null) as signed_out;
-- The test account applies, into the checks' pool, once.
select public.beta_apply((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'A working crane with a slewing ring and a two-speed winch', 'claude', 'lego', 'Ten years of Technic', 'https://rebrickable.com/', '2026-10-29', '{"disposable": false}'::jsonb) as applied;
select public.beta_apply((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'A working crane with a slewing ring and a two-speed winch', 'claude', 'lego', '', null, '2026-10-29', '{}'::jsonb) as again;
-- What the owner's queue reads of it: the live counts of models, its age and its inbox.
select jsonb_pretty(public.beta_queue(null, true, 5) -> 'applications' -> 0 -> 'facts') as facts, public.beta_queue(null, true, 5) -> 'counts' as counts;
-- Two spots from the end of the checks' pool; the account approved without one (early), and nothing given at Admission.
select public.beta_test_pool(98) as test_pool;
select public.beta_decide((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'approve', 'dry run', 'owner@brickworks.diy') -> 'application' as approved;
select public.beta_comp_note((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'granted', now(), now() + interval '30 days', null) as granted;
select public.beta_decide((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'decline', null, 'owner@brickworks.diy') ->> 'refused' as decline_approved;
select public.beta_mail_note((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'approved', 'dry', null, 'Spot 99 of the Brickworks beta');
select public.beta_mail_of((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev')) as mail;
-- The real pool is untouched by all of that.
select public.beta_status(null) -> 'pool' as real_pool, public.beta_reminders_due() as reminders, public.beta_sweep() as swept;
-- A page's keys are refused, by the tables and by the functions.
set local role anon;
select pg_temp.tries('select count(*) from public.beta_applications') as anon_reads, pg_temp.tries('select public.beta_status(null)') as anon_status, pg_temp.tries('select public.beta_test_pool(0)') as anon_test_pool;
reset role;
set local role authenticated;
select pg_temp.tries('select count(*) from public.beta_pools') as signed_in_reads, pg_temp.tries($q$select public.beta_decide('00000000-0000-4000-8000-000000000001', 'approve', null, 'x')$q$) as signed_in_decides;
reset role
