-- What supabase/way_links.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/way_links.sql --dry --try=tools/way_links_try.sql --table=way_links
--
-- Made-up accounts and sessions, made and gone with the transaction. Each
-- statement is on one line: the dry run splits at a semicolon that ends a
-- line. A change and the look at it are separate statements, since a
-- statement sees the database as it was when it began. Run one at a time,
-- so the locks are not raced here (ways_check.mjs 11 races them on the
-- relay).
-- What the copy from app_metadata made of production's accounts.
select count(*) as copied, count(*) filter (where state = 'off') as copied_off from public.way_links;
-- Two accounts: one whose app_metadata has Google off and GitHub on with its id, one with nothing.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_app_meta_data) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wl-one@example.invalid', 'made-random', '{"way_google": "off", "way_github": "2026-11-24T00:00:00Z", "way_github_id": "77"}'), ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wl-two@example.invalid', 'made-random', '{}');
-- The copy again (the file's own statement): the first account's two ways, the second's none.
insert into public.way_links (account, way, state, provider_id) select u.id, w.way, case when u.raw_app_meta_data ->> ('way_' || w.way) = 'off' then 'off' else 'on' end, case when w.way = 'github' and u.raw_app_meta_data ->> 'way_github' <> 'off' then nullif(u.raw_app_meta_data ->> 'way_github_id', '') end from auth.users u cross join (values ('google'), ('github')) as w (way) where coalesce(u.raw_app_meta_data ->> ('way_' || w.way), '') <> '' on conflict (account, way) do nothing;
select public.way_links_of('00000000-0000-4000-8000-0000000000e1') as one_copied, public.way_links_of('00000000-0000-4000-8000-0000000000e2') as two_none;
insert into auth.sessions (id, user_id, created_at, updated_at) select ('00000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid, '00000000-0000-4000-8000-0000000000e2', now(), now() from generate_series(1, 9) n;
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-000000000099', '00000000-0000-4000-8000-0000000000e1', now(), now());
-- Google's first sign-in: on, written down as Google's.
select public.way_signed_in('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-0000000000e2', 'google', null, false) as google_first;
select public.way_session_of('00000000-0000-4000-8000-000000000001') as its_way, public.way_links_of('00000000-0000-4000-8000-0000000000e2') as links;
-- Unlinked: off, and the session it started ended (1).
select public.way_set('00000000-0000-4000-8000-0000000000e2', 'google', false) as ended;
select exists (select 1 from auth.sessions where id = '00000000-0000-4000-8000-000000000001') as still_there, public.way_links_of('00000000-0000-4000-8000-0000000000e2') as links;
-- A sign-in after: off, and its session ended at once.
select public.way_signed_in('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000e2', 'google', null, false) as after_unlink;
select exists (select 1 from auth.sessions where id = '00000000-0000-4000-8000-000000000002') as still_there, public.way_session_of('00000000-0000-4000-8000-000000000002') as its_way;
-- Linked again: no row, as never used; then Google signs in again.
select public.way_set('00000000-0000-4000-8000-0000000000e2', 'google', true) as relinked;
select public.way_links_of('00000000-0000-4000-8000-0000000000e2') as links;
select public.way_signed_in('00000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-0000000000e2', 'google', null, false) as google_again;
-- GitHub to an account it has no id for: confirm, the session ended; bound (a new account, or a code): on, its id kept.
select public.way_signed_in('00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-0000000000e2', 'github', '42', false) as github_unbound;
select exists (select 1 from auth.sessions where id = '00000000-0000-4000-8000-000000000004') as still_there, public.way_links_of('00000000-0000-4000-8000-0000000000e2') -> 'github' as github;
select public.way_signed_in('00000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-0000000000e2', 'github', '42', true) as github_bound;
select public.way_links_of('00000000-0000-4000-8000-0000000000e2') -> 'github' as github;
-- Another GitHub id: confirm; the kept one: on.
select public.way_signed_in('00000000-0000-4000-8000-000000000006', '00000000-0000-4000-8000-0000000000e2', 'github', '43', false) as other_id;
select public.way_signed_in('00000000-0000-4000-8000-000000000007', '00000000-0000-4000-8000-0000000000e2', 'github', '42', false) as kept_id;
-- Another account's session: null, nothing written down.
select public.way_signed_in('00000000-0000-4000-8000-000000000099', '00000000-0000-4000-8000-0000000000e2', 'google', null, false) as not_its_session;
select public.way_session_of('00000000-0000-4000-8000-000000000099') as its_way, exists (select 1 from auth.sessions where id = '00000000-0000-4000-8000-000000000099') as still_there;
-- way_bind: another id kept; unlinked, refused and nothing changed.
select public.way_bind('00000000-0000-4000-8000-0000000000e2', 'github', '44') as bind;
select public.way_links_of('00000000-0000-4000-8000-0000000000e2') -> 'github' as github;
select public.way_set('00000000-0000-4000-8000-0000000000e2', 'github', false) as ended;
select public.way_bind('00000000-0000-4000-8000-0000000000e2', 'github', '45') as bind_off;
select public.way_links_of('00000000-0000-4000-8000-0000000000e2') -> 'github' as github;
-- The first account, copied with Google off: Google refused.
select public.way_signed_in('00000000-0000-4000-8000-000000000099', '00000000-0000-4000-8000-0000000000e1', 'google', null, false) as copied_off;
-- Which sessions are left: 03 (Google again), 08 and 09 (never used); 05 and 07 ended with GitHub's Unlink.
select array_agg(right(id::text, 2) order by id) as left_sessions from auth.sessions where user_id = '00000000-0000-4000-8000-0000000000e2';
-- The throttle: two in the window pass, the third is refused and not counted; another key passes.
select public.way_may_try('try one', 2, 15) as a;
select public.way_may_try('try one', 2, 15) as b;
select public.way_may_try('try one', 2, 15) as c;
select public.way_may_try('try two', 2, 15) as other;
select (select count(*) from public.way_attempts where try_key = 'try one') as counted_one, (select count(*) from public.way_attempts where try_key = 'try two') as counted_two;
-- Nonsense limits: refused.
select public.way_may_try('try three', 0, 15) as none_allowed, public.way_may_try(null, 5, 15) as no_key, public.way_may_try('try four', 5, 0) as no_window;
-- An attempt older than the window is not counted, and one older than a day is let go.
insert into public.way_attempts (try_key, at) values ('try five', now() - interval '20 minutes'), ('try five', now() - interval '20 minutes'), ('try six', now() - interval '2 days');
select public.way_may_try('try five', 2, 15) as past_window;
select (select count(*) from public.way_attempts where try_key = 'try six') as day_old_left;
-- Nobody but the server: no grant to anon or authenticated, on the tables or the functions.
select has_table_privilege('anon', 'public.way_links', 'select') as anon_links, has_table_privilege('authenticated', 'public.way_links', 'select') as authed_links, has_table_privilege('authenticated', 'public.way_attempts', 'insert') as authed_attempts, has_function_privilege('anon', 'public.way_set(uuid, text, boolean)', 'execute') as anon_set, has_function_privilege('authenticated', 'public.way_signed_in(uuid, uuid, text, text, boolean)', 'execute') as authed_signed_in, has_function_privilege('authenticated', 'public.way_may_try(text, integer, integer)', 'execute') as authed_try, has_function_privilege('service_role', 'public.way_set(uuid, text, boolean)', 'execute') as server_set;
