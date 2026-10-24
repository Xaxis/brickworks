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
-- A session bound by the did that is the account's; never by a did that is not (Bob has none yet: an unlink since the sign-in looked). Deleting the Supabase session takes its row; deleting the account takes the rest.
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-0000000000e5', '00000000-0000-4000-8000-0000000000d1', now(), now());
select public.oc_bind_session('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d1', 'did:oc:' || repeat('a', 32), 'rh-ada', 'https://brickworks.diy', 1792780000) as ada_bound, public.oc_bind_session('00000000-0000-4000-8000-0000000000e5', '00000000-0000-4000-8000-0000000000d1', 'did:oc:' || repeat('a', 32), 'rh-ada2', 'https://brickworks.diy', 1792780000) as ada_second_bound;
select public.oc_bind_session('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000d2', 'did:oc:' || repeat('b', 32), 'rh-bob', 'https://brickworks.diy', 1792780000) as bob_not_his, public.oc_bind_session('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000d2', 'did:oc:' || repeat('a', 32), 'rh-bob', 'https://brickworks.diy', 1792780000) as bob_not_adas;
select (select count(*) from public.oc_sessions where account = '00000000-0000-4000-8000-0000000000d2') as bob_rows_none_bound;
delete from auth.sessions where id = '00000000-0000-4000-8000-0000000000e5';
select (select count(*) from public.oc_sessions where session_id = '00000000-0000-4000-8000-0000000000e5') as ada_row_after_signout;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000d1';
select (select count(*) from public.oc_identities where account = '00000000-0000-4000-8000-0000000000d1') as ada_ids_after_delete, (select count(*) from public.oc_sessions where account = '00000000-0000-4000-8000-0000000000d1') as ada_sessions_after_delete;
-- Linking: Carl, an email account with a session of his own and one orangecheck started; a did Bob has is refused; a second did for Carl too; the same did again changes nothing.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000d3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oc-try-carl@resend.dev');
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-4000-8000-0000000000d3', now(), now()), ('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000d3', now(), now());
select public.oc_claim('did:oc:' || repeat('b', 32), '00000000-0000-4000-8000-0000000000d2') is not null as bob_has_b;
select public.oc_link('did:oc:' || repeat('b', 32), '00000000-0000-4000-8000-0000000000d3') as bobs_did, public.oc_link('did:oc:' || repeat('c', 32), '00000000-0000-4000-8000-0000000000d3') as first_link;
select public.oc_link('did:oc:' || repeat('e', 32), '00000000-0000-4000-8000-0000000000d3') as second_did, public.oc_link('did:oc:' || repeat('c', 32), '00000000-0000-4000-8000-0000000000d3') as same_again, public.oc_did_of('00000000-0000-4000-8000-0000000000d3') = 'did:oc:' || repeat('c', 32) as did_of;
select public.oc_bind_session('00000000-0000-4000-8000-0000000000e4', '00000000-0000-4000-8000-0000000000d3', 'did:oc:' || repeat('c', 32), 'rh-carl', 'https://brickworks.diy', 1792780000) as carl_bound;
select public.oc_session_of('00000000-0000-4000-8000-0000000000e3') as email_session, public.oc_session_of('00000000-0000-4000-8000-0000000000e4') as oc_session, public.oc_session_of('00000000-0000-4000-8000-0000000000ff') as no_session;
-- A binding left from before oc_bind_session checked the did (one that is nobody's): oc_session_of says it is not linked.
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-0000000000e6', '00000000-0000-4000-8000-0000000000d3', now(), now());
insert into public.oc_sessions (session_id, account, did_oc, rh, aud, iat) values ('00000000-0000-4000-8000-0000000000e6', '00000000-0000-4000-8000-0000000000d3', 'did:oc:' || repeat('9', 32), 'rh-old', 'https://brickworks.diy', 1792780000);
select public.oc_session_of('00000000-0000-4000-8000-0000000000e6')->'linked' as old_binding_linked, public.oc_session_of('00000000-0000-4000-8000-0000000000e4')->'linked' as carl_binding_linked, public.oc_session_of('00000000-0000-4000-8000-0000000000e3')->'linked' as email_session_linked;
-- Two Claude connections of Carl's: one approved while signed in with orangecheck, one not; and two codes not yet exchanged, the same.
insert into public.oauth_clients (client_id, client_name, redirect_uris) select 'oc-try-client-0000000', 'Try', array['https://example.com/cb'] where not exists (select 1 from public.oauth_clients where client_id = 'oc-try-client-0000000');
insert into public.oauth_grants (owner, client_id, resource, oc_did, oc_rh, oc_aud, oc_iat) values ('00000000-0000-4000-8000-0000000000d3', 'oc-try-client-0000000', 'https://brickworks.diy/api/mcp', 'did:oc:' || repeat('c', 32), 'rh-carl', 'https://brickworks.diy', 1792780000), ('00000000-0000-4000-8000-0000000000d3', 'oc-try-client-0000000', 'https://brickworks.diy/api/mcp', null, null, null, null);
insert into public.oauth_codes (hash, client_id, owner, redirect_uri, code_challenge, resource, expires_at, oc_did, oc_rh, oc_aud, oc_iat) values (repeat('a', 64), 'oc-try-client-0000000', '00000000-0000-4000-8000-0000000000d3', 'https://example.com/cb', repeat('A', 43), 'https://brickworks.diy/api/mcp', now() + interval '1 minute', 'did:oc:' || repeat('c', 32), 'rh-carl', 'https://brickworks.diy', 1792780000), (repeat('b', 64), 'oc-try-client-0000000', '00000000-0000-4000-8000-0000000000d3', 'https://example.com/cb', repeat('A', 43), 'https://brickworks.diy/api/mcp', now() + interval '1 minute', null, null, null, null);
-- Unlinking ends the session orangecheck started, the connection it approved and the code it was given, never the email one's.
select public.oc_unlink('00000000-0000-4000-8000-0000000000d3') as unlinked;
select (select count(*) from public.oauth_grants where owner = '00000000-0000-4000-8000-0000000000d3') as connections_left, (select count(*) from public.oauth_codes where owner = '00000000-0000-4000-8000-0000000000d3') as codes_left, (select count(*) from public.oauth_codes where hash = repeat('b', 64)) as email_code_left;
select (select count(*) from auth.sessions where id = '00000000-0000-4000-8000-0000000000e3') as email_session_left, (select count(*) from auth.sessions where id = '00000000-0000-4000-8000-0000000000e4') as oc_session_left, public.oc_did_of('00000000-0000-4000-8000-0000000000d3') is null as no_did, public.oc_unlink('00000000-0000-4000-8000-0000000000d3') is null as nothing_to_unlink;
-- Ending one session.
select public.oc_end_session('00000000-0000-4000-8000-0000000000e3') as ended, public.oc_end_session('00000000-0000-4000-8000-0000000000e3') as again;
-- No key a page has reaches the tables or the functions.
set local role anon;
select pg_temp.tries('select * from public.oc_identities') as anon_reads_ids, pg_temp.tries($q$select public.oc_account_of('did:oc:' || repeat('a', 32))$q$) as anon_asks, pg_temp.tries($q$select public.oc_spend('x', now())$q$) as anon_spends, pg_temp.tries($q$select public.oc_end_session('00000000-0000-4000-8000-0000000000e1')$q$) as anon_ends, pg_temp.tries($q$select public.oc_unlink('00000000-0000-4000-8000-0000000000d3')$q$) as anon_unlinks;
reset role;
set local role authenticated;
select pg_temp.tries('select * from public.oc_sessions') as user_reads_sessions, pg_temp.tries($q$select public.oc_claim('did:oc:' || repeat('d', 32), '00000000-0000-4000-8000-0000000000d2')$q$) as user_claims;
reset role;
set local role service_role;
select pg_temp.tries('select * from public.oc_identities') as service_reads_table, pg_temp.tries($q$select public.oc_account_of('did:oc:' || repeat('a', 32))$q$) as service_asks;
reset role;
