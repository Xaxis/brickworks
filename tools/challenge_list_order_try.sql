-- What supabase/challenge_list_order.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/challenge_list_order.sql --dry --try=tools/challenge_list_order_try.sql
--
-- After challenge_year.sql, which the project has, with the year the owner
-- planned (2026-10-25). Made-up challenges, made and gone with the
-- transaction, all of them test ones: thirty test challenges in coming
-- months that a run ended yesterday, as browser runs leave them, and one
-- open now, as a run sets it, then ended as End it now ends it.
-- Each statement is on one line: the dry run splits at a semicolon that ends
-- a line.
-- Any test challenge a flow left open is ended first: one at a time, as challenges_flow.mjs does.
update public.challenges set ended_at = now() where test and ended_at is null;
insert into public.challenges (title, brief, starts_on, ends_on, test, ended_at) select 'Order try ended ' || n, 'Ended by a run.', current_date + 30 * n, current_date + 30 * n + 6, true, now() - interval '1 day' from generate_series(1, 30) n;
insert into public.challenges (title, brief, starts_on, ends_on, test) values ('Order try open', 'Open now.', current_date, current_date + 6, true);
-- With the tests: the open ones first (this one and the real one open now, if there is one), then every upcoming one by its first day, then the ended, newest first; 24 rows.
select (select count(*) from public.challenge_list(true)) as "listed", (select x->>'title' from public.challenge_list(true) x where x->>'state' = 'open' and (x->>'test')::boolean) as "the test one open now", (select count(*) from public.challenges c where public.challenge_state(c) <> 'ended') as "not ended", (select count(*) from public.challenge_list(true) x where x->>'state' <> 'ended') as "not ended, listed";
select n, x->>'id' as id, x->>'state' as state, x->>'starts_on' as starts_on, (x->>'test')::boolean as test, x->>'title' as title from public.challenge_list(true) with ordinality as l(x, n) where n <= 16 or n >= 23;
-- In order: no upcoming before an open one, no ended before a not ended one, upcoming by their first day, ended by the day each ended, the last first.
create function pg_temp.ended_on(x jsonb) returns date language sql as $$ select least((x->>'ends_on')::date, coalesce(((x->>'ended_at')::timestamptz at time zone 'utc')::date, (x->>'ends_on')::date)) $$;
select bool_and(ok) as "in order" from (select (case a->>'state' when 'open' then 0 when 'upcoming' then 1 else 2 end < case b->>'state' when 'open' then 0 when 'upcoming' then 1 else 2 end) or (a->>'state' = b->>'state' and ((a->>'state' = 'upcoming' and a->>'starts_on' <= b->>'starts_on') or (a->>'state' <> 'upcoming' and pg_temp.ended_on(a) >= pg_temp.ended_on(b)))) as ok from (select x as a, lead(x) over (order by n) as b from public.challenge_list(true) with ordinality as l(x, n)) p where b is not null) q;
-- Ended now, as End it now ends it: still listed, the first of the ended ones, above the thirty a run ended yesterday in coming months.
update public.challenges set ended_at = now() where title = 'Order try open';
select n as "listed at", x->>'state' as state, (select count(*) from public.challenge_list(true) y where y->>'state' <> 'ended') as "not ended before it", (select min(m) from public.challenge_list(true) with ordinality as k(y, m) where y->>'state' = 'ended') as "the first ended at" from public.challenge_list(true) with ordinality as l(x, n) where x->>'title' = 'Order try open';
-- Without the tests: the real ones only, the open one first, then the year planned, in order.
select n, x->>'id' as id, x->>'state' as state, x->>'starts_on' as starts_on, x->>'title' as title from public.challenge_list(false) with ordinality as l(x, n) where n <= 4;
select bool_and(not (x->>'test')::boolean) as "no test one", count(*) as "listed" from public.challenge_list(false) x;
-- Each row as before: every key challenge_year.sql's list gave, for every row.
select bool_and(x ?& array['id', 'title', 'brief', 'starts_on', 'ends_on', 'announced_at', 'state', 'test', 'ended_at', 'settled', 'rules', 'entries', 'votes', 'winners']) as "every key", count(distinct jsonb_object_keys) as "keys" from public.challenge_list(true) x, jsonb_object_keys(x);
-- The server's alone.
select has_function_privilege('anon', 'public.challenge_list(boolean)', 'execute') as anon, has_function_privilege('authenticated', 'public.challenge_list(boolean)', 'execute') as authenticated, has_function_privilege('service_role', 'public.challenge_list(boolean)', 'execute') as service_role
