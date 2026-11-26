-- What supabase/approving_session.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/approving_session.sql --dry --try=tools/approving_session_try.sql --table=oauth_codes
--
-- Made-up accounts A and B, a client, sessions of each kind (a code's, Google's, GitHub's,
-- orangecheck's, and B's), codes and connections, made and gone with the transaction. Each
-- statement is on one line: the dry run splits at a semicolon that ends a line. A change and
-- the look at it are separate statements, since a statement sees the database as it began.
-- Production's rows: none names a session yet.
select (select count(*) from public.oauth_codes where session_id is not null) as codes_with_session, (select count(*) from public.oauth_grants where session_id is not null) as grants_with_session;
create temp table try_said (step text, said text);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data) values ('00000000-0000-4000-8000-0000000006a0', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'as-one@example.invalid', 'made-random', '{}'), ('00000000-0000-4000-8000-0000000006b0', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'as-two@example.invalid', 'made-random', '{}');
insert into public.oauth_clients (client_id, client_name, redirect_uris) values ('approving-session-try-0001', 'a try', array['https://claude.ai/api/mcp/auth_callback']);
-- Sessions 1 code, 2 Google, 3 GitHub, 4 orangecheck, 6 GitHub again (A's); 5 B's.
insert into auth.sessions (id, user_id, created_at, updated_at) select ('00000000-0000-4000-8000-00000000060' || n)::uuid, case when n = 5 then '00000000-0000-4000-8000-0000000006b0' else '00000000-0000-4000-8000-0000000006a0' end::uuid, now(), now() from generate_series(1, 6) n;
select public.way_signed_in('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-0000000006a0', 'google', null, false) as google_in, public.way_signed_in('00000000-0000-4000-8000-000000000603', '00000000-0000-4000-8000-0000000006a0', 'github', '77', true) as github_in;
select public.way_signed_in('00000000-0000-4000-8000-000000000606', '00000000-0000-4000-8000-0000000006a0', 'github', '77', false) as github_again;
insert into public.oc_identities (did_oc, account) values ('did:oc:000000000000000000000000000006a0', '00000000-0000-4000-8000-0000000006a0');
select public.oc_bind_session('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-0000000006a0', 'did:oc:000000000000000000000000000006a0', 'rh-try', 'https://brickworks.diy', 1764000000) as oc_bound;
-- How each session stands, in one read: exists, way, bound.
select n, (public.session_standing(('00000000-0000-4000-8000-00000000060' || n)::uuid) - 'account' - 'rh' - 'aud' - 'iat')::text as standing from generate_series(1, 7) n;
-- A code for a session that is not there is refused by its key; one for a live session is written.
do $$ begin insert into public.oauth_codes (hash, client_id, owner, redirect_uri, code_challenge, resource, expires_at, session_id) values (md5('as-gone') || md5('gone-as'), 'approving-session-try-0001', '00000000-0000-4000-8000-0000000006a0', 'https://claude.ai/api/mcp/auth_callback', repeat('a', 43), 'https://brickworks.diy/api/mcp', now() + interval '2 minutes', '00000000-0000-4000-8000-000000000609'); insert into try_said values ('code for a session not there', 'written'); exception when foreign_key_violation then insert into try_said values ('code for a session not there', 'refused by its key'); end $$;
insert into public.oauth_codes (hash, client_id, owner, redirect_uri, code_challenge, resource, expires_at, session_id) select md5('as-code' || n) || md5(n || 'as-code'), 'approving-session-try-0001', '00000000-0000-4000-8000-0000000006a0', 'https://claude.ai/api/mcp/auth_callback', repeat('a', 43), 'https://brickworks.diy/api/mcp', now() + interval '2 minutes', ('00000000-0000-4000-8000-00000000060' || n)::uuid from generate_series(1, 4) n;
select * from try_said;
-- The exchange, for each kind of session: a connection, with its way or its orangecheck id, and its two tokens.
insert into try_said select 'grant ' || n, (public.oauth_code_grant(('00000000-0000-4000-8000-00000000060' || n)::uuid, '00000000-0000-4000-8000-0000000006a0', 'approving-session-try-0001', 'a try', 'https://claude.ai/api/mcp/auth_callback', 'https://brickworks.diy/api/mcp', 'build', md5('a' || n) || md5(n || 'a'), now() + interval '1 hour', md5('r' || n) || md5(n || 'r'), now() + interval '90 days') - 'grant')::text from generate_series(1, 5) n;
insert into try_said select 'grant with no session', (public.oauth_code_grant(null, '00000000-0000-4000-8000-0000000006a0', 'approving-session-try-0001', 'a try', 'https://claude.ai/api/mcp/auth_callback', 'https://brickworks.diy/api/mcp', 'build', md5('an') || md5('na'), now() + interval '1 hour', md5('rn') || md5('nr'), now() + interval '90 days'))::text;
select * from try_said where step like 'grant%' order by step;
select coalesce(g.way, case when g.oc_did is not null then 'orangecheck' else 'code' end) as kind, right(g.session_id::text, 1) as session, (select count(*) from public.oauth_tokens t where t.grant_id = g.id) as tokens from public.oauth_grants g where g.owner = '00000000-0000-4000-8000-0000000006a0' order by 2;
-- Google unlinked: its session, connection and tokens go; its code goes with its session; the exchange for it is refused.
select public.way_set('00000000-0000-4000-8000-0000000006a0', 'google', false) as google_ended;
select (select array_agg(coalesce(way, case when oc_did is not null then 'orangecheck' else 'code' end) order by session_id) from public.oauth_grants where owner = '00000000-0000-4000-8000-0000000006a0') as grants_left, (select array_agg(right(session_id::text, 1) order by session_id) from public.oauth_codes where owner = '00000000-0000-4000-8000-0000000006a0') as codes_left, (select count(*) from public.oauth_tokens t join public.oauth_grants g on g.id = t.grant_id where g.owner = '00000000-0000-4000-8000-0000000006a0') as tokens_left;
select public.oauth_code_grant('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-0000000006a0', 'approving-session-try-0001', 'a try', 'https://claude.ai/api/mcp/auth_callback', 'https://brickworks.diy/api/mcp', 'build', md5('a2b') || md5('b2a'), now() + interval '1 hour', md5('r2b') || md5('b2r'), now() + interval '90 days') as google_after_unlink;
-- A GitHub session whose way reads off (as if an Unlink had marked it and not yet ended it): unlinked.
update public.way_links set state = 'off' where account = '00000000-0000-4000-8000-0000000006a0' and way = 'github';
select public.oauth_code_grant('00000000-0000-4000-8000-000000000606', '00000000-0000-4000-8000-0000000006a0', 'approving-session-try-0001', 'a try', 'https://claude.ai/api/mcp/auth_callback', 'https://brickworks.diy/api/mcp', 'build', md5('a6') || md5('6a'), now() + interval '1 hour', md5('r6') || md5('6r'), now() + interval '90 days') as github_off;
update public.way_links set state = 'on' where account = '00000000-0000-4000-8000-0000000006a0' and way = 'github';
-- An orangecheck binding whose id is not the account's (no unlink leaves one, and oc_bind_session makes none): unlinked.
update public.oc_sessions set did_oc = 'did:oc:000000000000000000000000000006ff' where session_id = '00000000-0000-4000-8000-000000000604';
select public.oauth_code_grant('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-0000000006a0', 'approving-session-try-0001', 'a try', 'https://claude.ai/api/mcp/auth_callback', 'https://brickworks.diy/api/mcp', 'build', md5('o4') || md5('4o'), now() + interval '1 hour', md5('q4') || md5('4q'), now() + interval '90 days') as oc_not_the_accounts;
update public.oc_sessions set did_oc = 'did:oc:000000000000000000000000000006a0' where session_id = '00000000-0000-4000-8000-000000000604';
-- orangecheck unlinked: its sessions, connection and codes go; the exchange for it is refused.
select (public.oc_unlink('00000000-0000-4000-8000-0000000006a0') - 'did')::text as oc_unlinked;
select public.oauth_code_grant('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-0000000006a0', 'approving-session-try-0001', 'a try', 'https://claude.ai/api/mcp/auth_callback', 'https://brickworks.diy/api/mcp', 'build', md5('a4b') || md5('b4a'), now() + interval '1 hour', md5('r4b') || md5('b4r'), now() + interval '90 days') as oc_after_unlink;
-- The code's own session signed out: its code goes with it; its connection stays (a connection outlives a browser's sign out).
delete from auth.sessions where id = '00000000-0000-4000-8000-000000000601';
select (select array_agg(coalesce(way, case when oc_did is not null then 'orangecheck' else 'code' end) order by session_id) from public.oauth_grants where owner = '00000000-0000-4000-8000-0000000006a0') as grants_left, (select array_agg(right(session_id::text, 1) order by session_id) from public.oauth_codes where owner = '00000000-0000-4000-8000-0000000006a0') as codes_left;
-- Nobody but the server.
select has_function_privilege('anon', 'public.session_standing(uuid)', 'execute') as anon_standing, has_function_privilege('authenticated', 'public.session_standing(uuid)', 'execute') as authed_standing, has_function_privilege('anon', 'public.oauth_code_grant(uuid, uuid, text, text, text, text, text, text, timestamptz, text, timestamptz)', 'execute') as anon_grant, has_function_privilege('authenticated', 'public.oauth_code_grant(uuid, uuid, text, text, text, text, text, text, timestamptz, text, timestamptz)', 'execute') as authed_grant, has_function_privilege('service_role', 'public.session_standing(uuid)', 'execute') as server_standing, has_function_privilege('service_role', 'public.oauth_code_grant(uuid, uuid, text, text, text, text, text, text, timestamptz, text, timestamptz)', 'execute') as server_grant;
