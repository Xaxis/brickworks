-- What supabase/plan_interest.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/plan_interest.sql --dry --try=tools/plan_interest_try.sql --table=plan_interest
--
-- Made-up addresses at Resend's test domain and one that looks like a
-- person's (counted apart), all gone with the transaction. Each statement
-- is on one line: the dry run splits at a semicolon that ends a line, and
-- a statement sees the tables as they were when it began, so each count
-- after a change is a statement of its own.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- The project gives no role execute on a new function by default: the page's two may run this one, to be refused inside it.
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- Nothing that was there is touched: the two tables are new, and empty.
select (select count(*) from public.plan_interest) as "entries", (select count(*) from public.plan_interest_tries) as "tries";
-- Row security on both, no policy for anybody, and no grant on either to a page's keys or the server's.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('anon', c.oid, 'insert') as anon_writes, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('authenticated', c.oid, 'insert') as signed_in_writes, has_table_privilege('service_role', c.oid, 'select') as server_reads_directly from pg_class c where c.oid in ('public.plan_interest'::regclass, 'public.plan_interest_tries'::regclass) order by c.relname;
-- The functions: the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'plan_interest%' order by p.proname;
-- A page's key, by PostgREST's own roles: reading and writing refused.
set local role anon;
select pg_temp.tries($q$select count(*) from public.plan_interest$q$) as "anon reads", pg_temp.tries($q$insert into public.plan_interest (email, plan, billing) values ('anon@resend.dev', 'plus', 'yearly')$q$) as "anon writes", pg_temp.tries($q$select public.plan_interest_note('anon@resend.dev', 'plus', 'yearly', '')$q$) as "anon notes", pg_temp.tries($q$select public.plan_interest_forget('anon@resend.dev')$q$) as "anon forgets";
reset role;
set local role authenticated;
select pg_temp.tries($q$select count(*) from public.plan_interest$q$) as "signed in reads", pg_temp.tries($q$select * from public.plan_interest_counts()$q$) as "signed in counts", pg_temp.tries($q$select * from public.plan_interest_of('anon@resend.dev')$q$) as "signed in reads one";
reset role;
-- An entry, then the same address and plan again: one row, changed.
select public.plan_interest_note('delivered+plantry@resend.dev', 'plus', 'monthly', 'first') as "first";
select public.plan_interest_note('delivered+plantry@resend.dev', 'plus', 'yearly', 'second') as "again";
select email, plan, billing, note from public.plan_interest where email = 'delivered+plantry@resend.dev';
-- The other plan is a row of its own.
select public.plan_interest_note('delivered+plantry@resend.dev', 'creator', 'yearly', '') as "creator";
select plan, billing, note from public.plan_interest_of('  Delivered+PlanTry@resend.dev ');
-- The table holds what the API checks: a plan off the list, a billing off it, a long line, an address in capitals or not an address.
select pg_temp.tries($q$select public.plan_interest_note('delivered+plantry@resend.dev', 'pro', 'yearly', '')$q$) as "plan pro", pg_temp.tries($q$select public.plan_interest_note('delivered+plantry@resend.dev', 'plus', 'weekly', '')$q$) as "weekly", pg_temp.tries($q$select public.plan_interest_note('delivered+plantry@resend.dev', 'plus', 'yearly', repeat('x', 201))$q$) as "201 characters", pg_temp.tries($q$select public.plan_interest_note('Delivered@resend.dev', 'plus', 'yearly', '')$q$) as "capitals", pg_temp.tries($q$select public.plan_interest_note('nobody', 'plus', 'yearly', '')$q$) as "no address";
-- Ten from one place in the hour, then refused; another place is not held up.
select string_agg(public.plan_interest_may('place-c')::text, ',' order by g) as "ten from place c" from generate_series(1, 10) g;
select public.plan_interest_may('place-c') as "eleventh from place c", public.plan_interest_may('place-d') as "first from place d";
-- A person's address counted as a person, the test addresses apart.
select public.plan_interest_note('ada.plantry@example.com', 'creator', 'monthly', 'I sell instructions') as "a person";
select * from public.plan_interest_counts();
-- Forgotten when asked: every entry of that address, and only that address's.
select public.plan_interest_forget('DELIVERED+plantry@resend.dev') as "forgotten";
select (select count(*) from public.plan_interest where email = 'delivered+plantry@resend.dev') as "left of it", (select count(*) from public.plan_interest) as "left in all";
select public.plan_interest_forget('delivered+plantry@resend.dev') as "forgotten again";
-- Tries older than a day go at the next one.
update public.plan_interest_tries set at = now() - interval '2 days' where who = 'place-c';
select public.plan_interest_may('place-f') as "next try";
select (select count(*) from public.plan_interest_tries where who = 'place-c') as "place c's tries left", (select count(*) from public.plan_interest_tries) as "tries left in all"
