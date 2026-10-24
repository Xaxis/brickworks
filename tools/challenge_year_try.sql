-- What supabase/challenge_year.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/challenge_year.sql --dry --try=tools/challenge_year_try.sql --table=challenges
--
-- After challenges.sql and the files before it, which the project has. Made-up accounts, made and gone with the
-- transaction: Ada designs (13 or over, a profile), Ed votes. Every model a test model, so every challenge here is a
-- test one, which no visitor's page shows. Each statement is on one line: the dry run splits at a semicolon that
-- ends a line. Inside one transaction now() never moves, so a challenge is ended by moving its days.
-- First, the answers the replaced functions gave for the challenges there are, asked the way challenges.sql asked them: compared with the new ones below.
create temp table old_shown as select t.tests, (select c.id from public.challenges c where (not c.test or t.tests) and (public.challenge_state(c) <> 'ended' or exists (select 1 from public.challenge_entries e where e.challenge = c.id)) order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end, c.test desc, case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc, c.ends_on desc, c.id desc limit 1) as id from (values (false), (true)) t(tests);
select t.tests, (public.challenge_shown(t.tests)).id is not distinct from o.id as "challenge_shown the same", md5(coalesce(public.challenge_page(t.tests)::text, '')) = md5(coalesce(public.challenge_page_at(o.id, t.tests)::text, '')) as "challenge_page the same", (select count(*) from public.challenges where announced_at is not null) as "told later" from (values (false), (true)) t(tests) join old_shown o on o.tests = t.tests;
select (select count(*) from public.challenge_list(true)) as "listed", (select bool_and(x ? 'announced_at') from public.challenge_list(true) x) as "each with announced_at";
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- Any test challenge a flow left open is ended first: one at a time.
update public.challenges set ended_at = now() where test and ended_at is null;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'year-ada@resend.dev'), ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'year-ed@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000d1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000000d2', true)->>'over_13' as ed;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000d1', 'year-try-ada', 'Ada Year');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, published) values ('YearTry001', '00000000-0000-4000-8000-0000000000d1', 'Year house', 'Ada Year', 40, 100, true, now() - interval '3 days', true, now() - interval '3 days', true), ('YearTry002', '00000000-0000-4000-8000-0000000000d1', 'Year shed', 'Ada Year', 30, 100, true, now() - interval '3 days', true, now() - interval '3 days', true);
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, created_at, parts, 100 from public.shared_models where id like 'YearTry%';
-- This month's: open from yesterday for a week. Ada enters her house by hand; Ed votes for it.
select public.challenge_set('Year this month', 'Build a small house.', current_date - 1, current_date + 6, test => true) ?| array['challenge'] as "set";
select public.challenge_enter('00000000-0000-4000-8000-0000000000d1', 'YearTry001', 'hand')->>'way' as "the house", public.challenge_vote('00000000-0000-4000-8000-0000000000d2', (select id from public.challenges where title = 'Year this month'), 'YearTry001', true)->>'voted' as "Ed's vote";
-- A year of themes: refused whole for each reason, the offending theme named.
select public.challenge_plan('[]', test => true)->>'refused' as "none", public.challenge_plan('[{"title": "", "brief": "b", "starts_on": "2099-01-01", "ends_on": "2099-01-31"}]', test => true) as "no title", public.challenge_plan(jsonb_build_array(jsonb_build_object('title', 'Long', 'brief', 'b', 'starts_on', current_date + 30, 'ends_on', current_date + 100)), test => true)->>'refused' as "64 days", public.challenge_plan(jsonb_build_array(jsonb_build_object('title', 'Gone', 'brief', 'b', 'starts_on', current_date - 40, 'ends_on', current_date - 10)), test => true)->>'refused' as "past";
select public.challenge_plan(jsonb_build_array(jsonb_build_object('title', 'A', 'brief', 'b', 'starts_on', current_date + 30, 'ends_on', current_date + 40), jsonb_build_object('title', 'B', 'brief', 'b', 'starts_on', current_date + 35, 'ends_on', current_date + 50)), test => true) as "two share a day", public.challenge_plan(jsonb_build_array(jsonb_build_object('title', 'C', 'brief', 'b', 'starts_on', current_date + 3, 'ends_on', current_date + 20)), test => true) as "a day of this month's";
select pg_temp.tries($q$select public.challenge_plan(jsonb_build_array(jsonb_build_object('title', 'D', 'brief', 'b', 'starts_on', current_date + 300, 'ends_on', current_date + 310)), lead_days => 500, test => true)$q$) as "told 500 days ahead", (select count(*) from public.challenges where title in ('A', 'B', 'C', 'Long', 'Gone')) as "none made";
-- Twelve, each a month from the month after this one's last day, given out of order: set in order of their days.
create temp table months as select n, (date_trunc('month', current_date + 7) + make_interval(months => n))::date as starts_on, (date_trunc('month', current_date + 7) + make_interval(months => n + 1) - interval '1 day')::date as ends_on from generate_series(1, 12) n;
select jsonb_array_length(public.challenge_plan((select jsonb_agg(jsonb_build_object('title', 'Year theme ' || n, 'brief', 'The brief of month ' || n, 'starts_on', starts_on, 'ends_on', ends_on) order by n desc) from months), test => true)->'planned') as "planned";
select c.title, c.starts_on, c.ends_on, c.announced_at = greatest(now(), (c.starts_on - 31)::timestamp at time zone 'utc') as "told 31 days before", public.challenge_announced(c) as "told now", public.challenge_state(c) as state from public.challenges c where c.title like 'Year theme %' order by c.starts_on;
-- What a tests page is told: the open one, then the first theme as the next; never a theme not yet told.
select (public.challenge_shown(true)).title as "shown", (public.challenge_next(true, (public.challenge_shown(true)).id)).title as "next", (select count(*) from public.challenges c where c.title like 'Year theme %' and not public.challenge_announced(c)) as "not yet told", public.challenge_page_at((select id from public.challenges where title = 'Year theme 1'), true)->>'title' as "the next's own page", public.challenge_page_at((select id from public.challenges where title = 'Year theme 6'), true) as "a theme not told", public.challenge_page_at((select id from public.challenges where title = 'Year theme 1'), false) as "a visitor asking for a test one";
-- The admin reads the year back: each with its announced_at.
select x->>'title' as title, x->>'state' as state, (x->>'announced_at') is not null as told from public.challenge_list(true) x where x->>'title' like 'Year%' order by x->>'starts_on' limit 4;
-- This month's ends: settled, it is the past's first, its winner the house with Ed's one vote, as a gallery card; the next is still the first theme.
update public.challenges set starts_on = current_date - 8, ends_on = current_date - 1 where title = 'Year this month';
select public.challenge_settle((select id from public.challenges where title = 'Year this month')) as settled;
select p->>'title' as "past", p->>'entries' as entries, p->'winners'->0->>'model' as winner, p->'winners'->0->>'votes' as votes, p->'winners'->0->'card'->>'name' as "its card", (p->>'ended_on')::date = current_date - 1 as "ended yesterday" from public.challenge_past(true) p limit 1;
select (public.challenge_shown(true)).title as "shown now", (public.challenge_next(true, (public.challenge_shown(true)).id)).title as "next", public.challenge_page_at((select id from public.challenges where title = 'Year this month'), true)->'winners' as "its page's winners";
-- The owner ends a theme before it opens: it never ran, so it is in no list of the past and has no page.
select public.challenge_end((select id from public.challenges where title = 'Year theme 12')) as "ended", public.challenge_opened((select c from public.challenges c where c.title = 'Year theme 12')) as "opened", exists (select 1 from public.challenge_past(true) p where p->>'title' = 'Year theme 12') as "in the past", public.challenge_page_at((select id from public.challenges where title = 'Year theme 12'), true) as "its page";
-- A visitor's page is told of none of it, and a winner whose designer is taken out is not shown.
select (select count(*) from public.challenge_past(false) p where (p->>'test')::boolean) as "test ones a visitor sees", (public.challenge_next(false)).test as "a visitor's next is a test one";
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000d1', 'year try');
select jsonb_array_length(p->'winners') as "winners once Ada is taken out" from public.challenge_past(true) p where p->>'title' = 'Year this month';
delete from public.barred_accounts where account = '00000000-0000-4000-8000-0000000000d1';
-- Ada's account deleted: her entry goes, and with it a test challenge's place in the past.
delete from auth.users where id = '00000000-0000-4000-8000-0000000000d1';
select exists (select 1 from public.challenge_past(true) p where p->>'title' = 'Year this month') as "in the past after";
-- Nobody but the server runs any of it.
select r.rolname, p.proname, has_function_privilege(r.rolname, p.oid, 'execute') as runs from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname in ('challenge_announced', 'challenge_opened', 'challenge_next', 'challenge_page_at', 'challenge_past', 'challenge_plan', 'challenge_shown', 'challenge_page', 'challenge_list') and has_function_privilege(r.rolname, p.oid, 'execute');
select count(*) as "the service role runs" from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('challenge_announced', 'challenge_opened', 'challenge_next', 'challenge_page_at', 'challenge_past', 'challenge_plan', 'challenge_shown', 'challenge_page', 'challenge_list') and has_function_privilege('service_role', p.oid, 'execute')
