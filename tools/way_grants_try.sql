-- What supabase/way_grants.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/way_grants.sql --dry --try=tools/way_grants_try.sql --table=oauth_grants
--
-- A made-up account, client, sessions, codes and connections, made and gone
-- with the transaction. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line. A change and the look at it are separate
-- statements, since a statement sees the database as it was when it began.
-- What the new columns hold for production's rows: none of them a way's.
select (select count(*) from public.oauth_codes where way is not null) as codes_with_way, (select count(*) from public.oauth_grants where way is not null) as grants_with_way;
-- One account, one client, three sessions: Google's, GitHub's, and a code's.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data) values ('00000000-0000-4000-8000-0000000000e3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wg-one@example.invalid', 'made-random', '{}');
insert into public.oauth_clients (client_id, client_name, redirect_uris) values ('way-grants-try-client-0001', 'a try', array['https://claude.ai/api/mcp/auth_callback']);
insert into auth.sessions (id, user_id, created_at, updated_at) select ('00000000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, '00000000-0000-4000-8000-0000000000e3', now(), now() from generate_series(1, 3) n;
select public.way_signed_in('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-0000000000e3', 'google', null, false) as google_in, public.way_signed_in('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-0000000000e3', 'github', '42', true) as github_in;
-- Each session approves a connection and leaves a code not yet traded (api/oauth.js codeFor: way from way_sessions, none for the code's).
insert into public.oauth_grants (id, owner, client_id, resource, way) values ('00000000-0000-4000-8000-0000000002a1', '00000000-0000-4000-8000-0000000000e3', 'way-grants-try-client-0001', 'https://brickworks.diy/api/mcp', 'google'), ('00000000-0000-4000-8000-0000000002a2', '00000000-0000-4000-8000-0000000000e3', 'way-grants-try-client-0001', 'https://brickworks.diy/api/mcp', 'github'), ('00000000-0000-4000-8000-0000000002a3', '00000000-0000-4000-8000-0000000000e3', 'way-grants-try-client-0001', 'https://brickworks.diy/api/mcp', null);
insert into public.oauth_tokens (hash, grant_id, kind, expires_at) select md5(g.n::text || k.kind) || md5(k.kind || g.n::text), ('00000000-0000-4000-8000-0000000002a' || g.n)::uuid, k.kind, now() + interval '1 hour' from generate_series(1, 3) as g (n) cross join (values ('access'), ('refresh')) as k (kind);
insert into public.oauth_codes (hash, client_id, owner, redirect_uri, code_challenge, resource, expires_at, way) select md5('code' || w.n) || md5(w.n || 'code'), 'way-grants-try-client-0001', '00000000-0000-4000-8000-0000000000e3', 'https://claude.ai/api/mcp/auth_callback', repeat('a', 43), 'https://brickworks.diy/api/mcp', now() + interval '2 minutes', w.way from (values (1, 'google'), (2, 'github'), (3, null)) as w (n, way);
select public.way_on('00000000-0000-4000-8000-0000000000e3', 'github') as github_on_before, public.way_on('00000000-0000-4000-8000-0000000000e3', 'google') as google_on_before;
-- GitHub unlinked: its session ended (1), and the connection and code it approved deleted, their tokens with them.
select public.way_set('00000000-0000-4000-8000-0000000000e3', 'github', false) as ended;
select (select array_agg(coalesce(way, 'code') order by way) from public.oauth_grants where owner = '00000000-0000-4000-8000-0000000000e3') as grants_left, (select array_agg(coalesce(way, 'code') order by way) from public.oauth_codes where owner = '00000000-0000-4000-8000-0000000000e3') as codes_left, (select count(*) from public.oauth_tokens where grant_id = '00000000-0000-4000-8000-0000000002a2') as github_tokens_left, (select count(*) from public.oauth_tokens where grant_id in ('00000000-0000-4000-8000-0000000002a1', '00000000-0000-4000-8000-0000000002a3')) as other_tokens_left;
select array_agg(right(id::text, 2) order by id) as left_sessions from auth.sessions where user_id = '00000000-0000-4000-8000-0000000000e3';
select public.way_on('00000000-0000-4000-8000-0000000000e3', 'github') as github_on_after, public.way_on('00000000-0000-4000-8000-0000000000e3', 'google') as google_on_after;
-- Linked again: no row, so not on, until GitHub signs in again.
select public.way_set('00000000-0000-4000-8000-0000000000e3', 'github', true) as relinked;
select public.way_on('00000000-0000-4000-8000-0000000000e3', 'github') as github_on_relinked;
-- Google unlinked: its connection and code go; the code's stay.
select public.way_set('00000000-0000-4000-8000-0000000000e3', 'google', false) as ended;
select (select array_agg(coalesce(way, 'code')) from public.oauth_grants where owner = '00000000-0000-4000-8000-0000000000e3') as grants_left, (select array_agg(coalesce(way, 'code')) from public.oauth_codes where owner = '00000000-0000-4000-8000-0000000000e3') as codes_left;
-- Nobody but the server.
select has_function_privilege('anon', 'public.way_on(uuid, text)', 'execute') as anon_on, has_function_privilege('authenticated', 'public.way_on(uuid, text)', 'execute') as authed_on, has_function_privilege('authenticated', 'public.way_set(uuid, text, boolean)', 'execute') as authed_set, has_function_privilege('service_role', 'public.way_on(uuid, text)', 'execute') as server_on, has_function_privilege('service_role', 'public.way_set(uuid, text, boolean)', 'execute') as server_set;
