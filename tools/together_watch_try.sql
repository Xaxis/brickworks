-- What supabase/together_watch.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept. Two made-up accounts at
-- Resend's test addresses: Ada designs and opens her session to watchers,
-- Bo watches.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/together_watch.sql --dry --try=tools/together_watch_try.sql --table=together_watch
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated, service_role;
-- A page's keys reach none of it: the tables no client key reads, the function the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'together_watch_append';
set local role anon;
select pg_temp.tries($q$select watch from public.together_watch limit 1$q$) as anon_reads_shows, pg_temp.tries($q$select viewer from public.together_watchers limit 1$q$) as anon_reads_watchers;
reset role;
set local role authenticated;
select pg_temp.tries($q$insert into public.together_watch (session, watch, owner) values (repeat('a', 64), 'AbcdefGhijkL', '00000000-0000-4000-8000-0000000fc001')$q$) as signed_in_opens_a_show;
reset role;
insert into auth.users (id, instance_id, aud, role, email, created_at, email_confirmed_at) values ('00000000-0000-4000-8000-0000000fc001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'watch-try-ada@resend.dev', now(), now()), ('00000000-0000-4000-8000-0000000fc002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'watch-try-bo@resend.dev', now(), now());
insert into public.together_sessions (id, owner, title, snapshot) values (repeat('b', 64), '00000000-0000-4000-8000-0000000fc001', 'Watch try', '{"text": "", "bricks": []}'::jsonb);
-- Not open to watchers yet: a line is refused.
select pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~chat": "hi", "~by": "Bo"}'::jsonb)$q$) as before_open;
insert into public.together_watch (session, watch, owner, title, tests) values (repeat('b', 64), 'WatchTry0001', '00000000-0000-4000-8000-0000000fc001', 'Watch try', true);
select pg_temp.tries($q$insert into public.together_watch (session, watch, owner) values (repeat('b', 64), 'bad name', '00000000-0000-4000-8000-0000000fc001')$q$) as bad_name;
-- Bo's line, his ask, and Ada's seat for him: numbered one after another, from the client "watching", each its own count.
select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~chat": "Nice wheels", "~by": "Bo"}'::jsonb) as chat_seq, public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~ask": "Bo", "~by": "Bo"}'::jsonb) as ask_seq, public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc001', '{"~seat": "0badc0de", "~key": "sealed"}'::jsonb) as seat_seq;
select seq, author, client, cid, changes from public.together_ops where session = repeat('b', 64) order by seq;
select last_seq from public.together_sessions where id = repeat('b', 64);
-- A watcher's line never changes a part: a part's key, a meta key, a line with nothing to say, all refused.
select pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~chat": "x", "evil0001.1": ["3001", 4, [1,0,0,0,1,0,0,0,1,0,0,0], "", "", 0]}'::jsonb)$q$) as with_a_part, pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~chat": "x", "~title": "Mine now"}'::jsonb)$q$) as with_a_title, pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~by": "Bo"}'::jsonb)$q$) as nothing_said, pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', jsonb_build_object('~chat', repeat('x', 3000)))$q$) as too_long;
-- The watchers counted, a row a page.
insert into public.together_watchers (session, viewer) values (repeat('b', 64), '0123456789abcdef'), (repeat('b', 64), 'fedcba9876543210');
select pg_temp.tries($q$insert into public.together_watchers (session, viewer) values (repeat('b', 64), 'not hex')$q$) as bad_viewer;
select count(*) as watching from public.together_watchers where session = repeat('b', 64) and seen_at > now() - interval '60 seconds';
-- Closed: refused again. Ended: refused.
update public.together_watch set closed_at = now() where session = repeat('b', 64);
select pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~chat": "hi", "~by": "Bo"}'::jsonb)$q$) as when_closed;
update public.together_watch set closed_at = null where session = repeat('b', 64);
update public.together_sessions set ended_at = now() where id = repeat('b', 64);
select pg_temp.tries($q$select public.together_watch_append(repeat('b', 64), '00000000-0000-4000-8000-0000000fc002', '{"~chat": "hi", "~by": "Bo"}'::jsonb)$q$) as when_ended;
-- The sweep takes the session, and its show and watchers with it.
update public.together_sessions set ended_at = now() - interval '2 days' where id = repeat('b', 64);
select public.together_sweep() >= 1 as swept;
-- Read in a statement of its own: one statement sees the rows as they were when it began.
select (select count(*) from public.together_watch where session = repeat('b', 64)) as shows_left, (select count(*) from public.together_watchers where session = repeat('b', 64)) as watchers_left;
