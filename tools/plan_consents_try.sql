-- What supabase/plan_consents.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/plan_consents.sql --dry --try=tools/plan_consents_try.sql --table=plan_consents
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line, and a statement sees the table as it was when it began, so
-- each look after a change is a statement of its own.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- The project gives no role execute on a new function by default: the page's two may run this one, to be refused inside it.
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- Nothing that was there is touched: the table is new, and empty.
select count(*) as consents from public.plan_consents;
-- Row security, no policy for anybody, and no grant to a page's keys or the server's.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads_directly from pg_class c where c.oid = 'public.plan_consents'::regclass;
-- The function: the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'plan_consent_note';
-- An agreement kept, then a second for the yearly price.
select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', 800, 'usd', 'Pro at $8.00 USD a month, renews until cancelled.');
select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'year', 8000, 'usd', 'Pro at $80.00 USD a year, renews until cancelled.');
select billing_interval, amount, currency, left(terms, 30) as terms from public.plan_consents where account = '00000000-0000-4000-8000-00000000d0d0' order by id;
-- The table's checks: no interval but month or year, no negative price, no currency but three letters, no empty terms.
select pg_temp.tries($q$select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'week', 800, 'usd', 'x')$q$) as a_week, pg_temp.tries($q$select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', -1, 'usd', 'x')$q$) as below_nothing, pg_temp.tries($q$select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', 800, 'dollars', 'x')$q$) as currency_word, pg_temp.tries($q$select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', 800, 'usd', '')$q$) as no_terms;
-- The last 50 of an account are kept, the oldest going first.
select count(*) from (select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', 800, 'usd', 'again ' || g) from generate_series(1, 60) g) made;
select count(*) as kept, min(terms) filter (where terms like 'again%') as oldest_left from public.plan_consents where account = '00000000-0000-4000-8000-00000000d0d0';
-- One four years old goes at the next agreement, anybody's.
update public.plan_consents set agreed_at = now() - interval '4 years 1 day' where account = '00000000-0000-4000-8000-00000000d0d0';
select public.plan_consent_note('00000000-0000-4000-8000-00000000e0e0', 'pro', 'year', 8000, 'usd', 'Pro at $80.00 USD a year.');
select (select count(*) from public.plan_consents where account = '00000000-0000-4000-8000-00000000d0d0') as old_left, (select count(*) from public.plan_consents) as rows;
-- A page's keys are refused, by the table and by the function.
set local role anon;
select pg_temp.tries('select count(*) from public.plan_consents') as anon_reads, pg_temp.tries($q$select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', 800, 'usd', 'x')$q$) as anon_notes;
reset role;
set local role authenticated;
select pg_temp.tries('select count(*) from public.plan_consents') as signed_in_reads, pg_temp.tries($q$select public.plan_consent_note('00000000-0000-4000-8000-00000000d0d0', 'pro', 'month', 800, 'usd', 'x')$q$) as signed_in_notes;
reset role
