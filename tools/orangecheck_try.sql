-- What supabase/orangecheck.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/orangecheck.sql --dry --try=tools/orangecheck_try.sql --table=oc_identities
--
-- Made-up accounts, made and gone with the transaction: Ada and Bob, each
-- with a session. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-ada@oc.brickworks.diy'), ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-bob@oc.brickworks.diy');
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d1', now(), now()), ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000d2', now(), now());
-- A did claimed by Ada; Bob's claim of the same did, as a race lost, gets Ada; a did not known is nobody's. (A function's own writes are seen by the next statement, not its own.)
select public.oc_claim('did:oc:' || repeat('a', 32), '00000000-0000-4000-8000-0000000000d1') = '00000000-0000-4000-8000-0000000000d1' as ada_claims, public.oc_claim('did:oc:' || repeat('a', 32), '00000000-0000-4000-8000-0000000000d2') = '00000000-0000-4000-8000-0000000000d1' as bob_gets_ada;
select public.oc_account_of('did:oc:' || repeat('a', 32)) = '00000000-0000-4000-8000-0000000000d1' as found, public.oc_account_of('did:oc:' || repeat('b', 32)) is null as unknown_is_nobody;
-- One did an account: a second did for Ada is refused by the key; a malformed did by the check.
select pg_temp.tries($q$select public.oc_claim('did:oc:' || repeat('c', 32), '00000000-0000-4000-8000-0000000000d1')$q$) as second_did_for_ada, pg_temp.tries($q$select public.oc_claim('did:oc:nothex', '00000000-0000-4000-8000-0000000000d2')$q$) as malformed;
-- A token spends once; an expired one's id is let go.
select public.oc_spend('jti-one', now() + interval '1 hour') as first, public.oc_spend('jti-one', now() + interval '1 hour') as again, public.oc_spend('jti-old', now() - interval '1 hour') as old_first;
select public.oc_spend('jti-new', now() + interval '1 hour') as another;
select (select count(*) from public.oc_spent where jti = 'jti-old') as old_kept;
-- Twenty tries from one address, the twenty-first refused; another address is let in.
select count(*) filter (where ok) as allowed, count(*) filter (where not ok) as refused from (select public.oc_may_try('203.0.113.9') as ok from generate_series(1, 21)) t;
select public.oc_may_try('203.0.113.10') as another_address;
-- A session bound; deleting the Supabase session takes its row; deleting the account takes the rest.
select public.oc_bind_session('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d1', 'did:oc:' || repeat('a', 32), 'rh-ada', 'https://brickworks.diy', 1792780000);
select public.oc_bind_session('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000d2', 'did:oc:' || repeat('b', 32), 'rh-bob', 'https://brickworks.diy', 1792780000);
delete from auth.sessions where id = '00000000-0000-4000-8000-0000000000e2';
select (select count(*) from public.oc_sessions where account = '00000000-0000-4000-8000-0000000000d2') as bob_session_rows_after_signout;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000d1';
select (select count(*) from public.oc_identities where account = '00000000-0000-4000-8000-0000000000d1') as ada_ids_after_delete, (select count(*) from public.oc_sessions where account = '00000000-0000-4000-8000-0000000000d1') as ada_sessions_after_delete;
-- No key a page has reaches the tables or the functions.
set local role anon;
select pg_temp.tries('select * from public.oc_identities') as anon_reads_ids, pg_temp.tries($q$select public.oc_account_of('did:oc:' || repeat('a', 32))$q$) as anon_asks, pg_temp.tries($q$select public.oc_spend('x', now())$q$) as anon_spends;
reset role;
set local role authenticated;
select pg_temp.tries('select * from public.oc_sessions') as user_reads_sessions, pg_temp.tries($q$select public.oc_claim('did:oc:' || repeat('d', 32), '00000000-0000-4000-8000-0000000000d2')$q$) as user_claims;
reset role;
set local role service_role;
select pg_temp.tries('select * from public.oc_identities') as service_reads_table, pg_temp.tries($q$select public.oc_account_of('did:oc:' || repeat('a', 32))$q$) as service_asks;
reset role;
