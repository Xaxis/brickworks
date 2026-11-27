-- What supabase/talk2.sql does, tried inside the rolled-back transaction of
-- a dry run: nothing here is kept. Made-up accounts, made and gone with the
-- transaction: Ada, Bo and Cy at Resend's test addresses (the checks' pool)
-- and Eve at example.com (anybody else).
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/talk2.sql --dry --try=tools/talk2_try.sql --table=talk_threads
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated, service_role;
-- The columns start empty: no thread has views or an answer yet.
select count(*) as threads, count(*) filter (where views <> 0) as with_views, count(*) filter (where answer is not null) as answered from public.talk_threads;
-- The functions are the server's alone, each security definer.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('talk2_mark', 'talk2_item', 'talk2_list', 'talk2_page', 'talk_visit', 'talk_read_to', 'talk_view', 'talk_answer') order by p.proname;
-- The tables are closed to every key.
select c.relname, c.relrowsecurity as row_security, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'insert') as signed_in_writes from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname in ('talk_views', 'talk_visits') order by c.relname;
-- Production's own Talk, as a visitor: the first and the last page of Latest, Help's unanswered, a search, and how long each takes.
create temporary table a_clock on commit drop as select clock_timestamp() as t0;
select (public.talk2_list(null, false, null, 'latest', 1, 30))->>'total' as people_threads, jsonb_array_length((public.talk2_list(null, false, null, 'latest', 1, 30))->'threads') as on_page_one, (public.talk2_list(null, false, null, 'latest', 1, 30))->>'pages' as pages, round(extract(epoch from clock_timestamp() - (select t0 from a_clock)) * 1000) as ms_three_calls;
select (public.talk2_list('help', false, null, 'unanswered', 1, 30))->>'total' as help_unanswered, (public.talk2_list(null, false, null, 'top', 1, 30, null, 'month'))->>'total' as top_this_month, (public.talk2_list(null, false, null, 'latest', 1, 30, 'welcome'))->>'total' as say_welcome;
-- The made-up four.
insert into auth.users (id, instance_id, aud, role, email, created_at, email_confirmed_at) values ('00000000-0000-4000-8000-0000000fc001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk2-try-ada@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fc002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk2-try-bo@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fc003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk2-try-cy@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fc005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk2-try-eve@example.com', now() - interval '30 days', now());
select public.answer_age('00000000-0000-4000-8000-0000000fc001', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000fc002', true)->>'over_13' as bo, public.answer_age('00000000-0000-4000-8000-0000000fc003', true)->>'over_13' as cy, public.answer_age('00000000-0000-4000-8000-0000000fc005', true)->>'over_13' as eve;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000fc001', 'talk2-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000fc002', 'talk2-try-bo', 'Bo Try'), ('00000000-0000-4000-8000-0000000fc003', 'talk2-try-cy', 'Cy Try'), ('00000000-0000-4000-8000-0000000fc005', 'talk2-try-eve', 'Eve Try');
-- A page's keys are refused, signed out and signed in: reading, counting, answering, writing the tables.
set local role anon;
select pg_temp.tries($q$select public.talk2_list(null, true, '00000000-0000-4000-8000-0000000fc001')$q$) as anon_lists_as_ada, pg_temp.tries($q$select public.talk_view(1, '0123456789abcdef0123456789abcdef')$q$) as anon_counts_a_view, pg_temp.tries($q$insert into public.talk_views (thread, viewer) values (1, '0123456789abcdef0123456789abcdef')$q$) as anon_writes_views, pg_temp.tries($q$update public.talk_threads set views = 1000000$q$) as anon_sets_views;
reset role;
set local role authenticated;
select pg_temp.tries($q$select public.talk_answer('00000000-0000-4000-8000-0000000fc001', 1, null)$q$) as signed_in_answers_as_ada, pg_temp.tries($q$select public.talk2_page(1, false, '00000000-0000-4000-8000-0000000fc001')$q$) as signed_in_reads_as_ada, pg_temp.tries($q$select public.talk_visit('00000000-0000-4000-8000-0000000fc001')$q$) as signed_in_visits_as_ada, pg_temp.tries($q$select * from public.talk_visits$q$) as signed_in_reads_visits;
reset role;
-- Ada asks in Help (the checks' pool); Bo answers, then Cy; Ada asks again and nobody answers.
create temporary table a_ask on commit drop as select public.talk_start('00000000-0000-4000-8000-0000000fc001', 'help', 'Talk2 try: how do I brace a wing?', 'It droops at the hinge.') as r;
create temporary table a_bo on commit drop as select public.talk_reply('00000000-0000-4000-8000-0000000fc002', (select (r->'thread'->>'id')::bigint from a_ask), 'A plate under the hinge holds it.') as r;
create temporary table a_cy on commit drop as select public.talk_reply('00000000-0000-4000-8000-0000000fc003', (select (r->'thread'->>'id')::bigint from a_ask), 'Or two clips and a bar.') as r;
create temporary table a_lone on commit drop as select public.talk_start('00000000-0000-4000-8000-0000000fc001', 'help', 'Talk2 try: which grey is which?', 'Light or dark bluish grey?') as r;
select (select r->'thread'->>'id' from a_ask) is not null as asked, (select r->'post'->>'id' from a_bo) is not null as bo_answered, (select r->'post'->>'id' from a_cy) is not null as cy_answered;
-- In one transaction every post is written at the same now(): Ada's question put ten minutes back and Bo's answer five, so they come in the order people would write them.
update public.talk_posts set at = now() - interval '10 minutes' where id = (select (r->'post'->>'id')::bigint from a_ask);
update public.talk_threads set at = now() - interval '10 minutes' where id = (select (r->'thread'->>'id')::bigint from a_ask);
update public.talk_posts set at = now() - interval '5 minutes' where id = (select (r->'post'->>'id')::bigint from a_bo);
-- The checks' pool's Help: the lone one in Unanswered, the answered one not; the people's pool never sees either.
select exists (select 1 from jsonb_array_elements(public.talk2_list('help', true, null, 'unanswered', 1, 50)->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_lone)) as lone_unanswered, exists (select 1 from jsonb_array_elements(public.talk2_list('help', true, null, 'unanswered', 1, 50)->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_ask)) as asked_unanswered, exists (select 1 from jsonb_array_elements(public.talk2_list('help', false, null, 'latest', 1, 50)->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_ask)) as in_peoples_pool;
-- A search finds the thread by a reply's words, with the reply that says them.
select (select (e->'hit'->>'id')::bigint = (select (r->'post'->>'id')::bigint from a_cy) from jsonb_array_elements(public.talk2_list(null, true, null, 'latest', 1, 30, 'clips bar')->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_ask)) as hit_is_cys_reply;
-- Paged two posts a page (at least five: asked 2, given 5): three posts on one page, numbered 1 to 3; Cy's post found on page 1.
select (p->>'per')::int as per, (p->>'pages')::int as pages, (p->>'total')::int as total, (p->'posts'->0->>'n')::int as first_n, (p->'posts'->2->>'n')::int as third_n, (p->'last'->>'n')::int as last_n, jsonb_array_length(p->'people') as people, (p->>'people_n')::int as people_n from (select public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, null, 1, 2) as p) x;
-- Who may mark the answer: Bo is refused (not his question); Eve, in the other pool, cannot see it; the first post is no answer; a Show and tell thread takes none; Ada marks Bo's.
select public.talk_answer('00000000-0000-4000-8000-0000000fc002', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_bo))->>'refused' as bo_marks, public.talk_answer('00000000-0000-4000-8000-0000000fc005', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_bo))->>'refused' as eve_marks, public.talk_answer('00000000-0000-4000-8000-0000000fc001', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_ask))->>'refused' as first_post, public.talk_answer(null, (select (r->'thread'->>'id')::bigint from a_ask), null)->>'refused' as nobody;
create temporary table a_show on commit drop as select public.talk_start('00000000-0000-4000-8000-0000000fc001', 'show', 'Talk2 try: my wing', 'Here it is.') as r;
select public.talk_answer('00000000-0000-4000-8000-0000000fc001', (select (r->'thread'->>'id')::bigint from a_show), null)->>'refused' as show_and_tell, public.talk_answer('00000000-0000-4000-8000-0000000fc001', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_bo))->>'answer' is not null as ada_marks_bos;
select (p->'answer'->>'n')::int as answer_n, p->'answer'->>'by' as answer_by, (p->'thread'->>'answered')::boolean as answered, (p->'you'->>'may_answer')::boolean as ada_may_answer from (select public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, '00000000-0000-4000-8000-0000000fc001') as p) x;
select (public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, '00000000-0000-4000-8000-0000000fc002')->'you'->>'may_answer')::boolean as bo_may_answer;
-- The owner hides Bo's post: the answer is no longer shown, and the list says unanswered-by-mark no more.
update public.talk_posts set hidden_at = now(), hidden_by = 'admin' where id = (select (r->'post'->>'id')::bigint from a_bo);
select public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, null)->'answer' = 'null'::jsonb as answer_hidden, (public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, null)->'thread'->>'answered')::boolean as still_said_answered, (public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, null)->>'total')::int as posts_shown;
update public.talk_posts set hidden_at = null, hidden_by = null where id = (select (r->'post'->>'id')::bigint from a_bo);
-- Ada unmarks it, and marks it again.
select public.talk_answer('00000000-0000-4000-8000-0000000fc001', (select (r->'thread'->>'id')::bigint from a_ask), null)->'answer' = 'null'::jsonb as unmarked;
select answer is null and answered_at is null as cleared from public.talk_threads where id = (select (r->'thread'->>'id')::bigint from a_ask);
select public.talk_answer('00000000-0000-4000-8000-0000000fc001', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_bo))->>'answer' is not null as marked_again;
-- Views: counted once a day a person; a key that is not one, and a thread that is not there, count nothing.
select public.talk_view((select (r->'thread'->>'id')::bigint from a_ask), '0123456789abcdef0123456789abcdef')->>'counted' as first_look, public.talk_view((select (r->'thread'->>'id')::bigint from a_ask), '0123456789abcdef0123456789abcdef')->>'counted' as same_person_again, public.talk_view((select (r->'thread'->>'id')::bigint from a_ask), 'fedcba9876543210fedcba9876543210')->>'views' as after_two_people, public.talk_view((select (r->'thread'->>'id')::bigint from a_ask), 'Robert''); drop table x;--') is null as not_a_key, public.talk_view(999999999, '0123456789abcdef0123456789abcdef') is null as no_thread;
-- What is new for Bo: his visits, then Cy's post after where Bo read up to.
select public.talk_visit('00000000-0000-4000-8000-0000000fc002')->'before_at' = 'null'::jsonb as first_visit, public.talk_visit(null)->'before_at' = 'null'::jsonb as nobody;
update public.talk_reads set at = now() - interval '5 minutes' where account = '00000000-0000-4000-8000-0000000fc002' and thread = (select (r->'thread'->>'id')::bigint from a_ask);
update public.talk_follows set at = now() - interval '5 minutes' where account = '00000000-0000-4000-8000-0000000fc002' and thread = (select (r->'thread'->>'id')::bigint from a_ask);
select (p->'first_new'->>'id')::bigint = (select (r->'post'->>'id')::bigint from a_cy) as first_new_is_cys, (p->'first_new'->>'n')::int as first_new_n, (p->'thread'->>'new_posts')::int as new_posts from (select public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, '00000000-0000-4000-8000-0000000fc002') as p) x;
select exists (select 1 from jsonb_array_elements(public.talk2_list(null, true, '00000000-0000-4000-8000-0000000fc002', 'unread', 1, 50)->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_ask)) as unread_for_bo;
-- Her own question is unread to Ada while answers she has not read wait in it (starting it, she follows it from then).
update public.talk_follows set at = now() - interval '15 minutes' where account = '00000000-0000-4000-8000-0000000fc001' and thread = (select (r->'thread'->>'id')::bigint from a_ask);
delete from public.talk_reads where account = '00000000-0000-4000-8000-0000000fc001' and thread = (select (r->'thread'->>'id')::bigint from a_ask);
select exists (select 1 from jsonb_array_elements(public.talk2_list(null, true, '00000000-0000-4000-8000-0000000fc001', 'unread', 1, 50)->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_ask)) as own_question_unread_for_ada;
select public.talk_read_to('00000000-0000-4000-8000-0000000fc002', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_cy))->>'read' as read_to_cy;
select public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, '00000000-0000-4000-8000-0000000fc002')->'first_new' = 'null'::jsonb as nothing_new_after;
select public.talk_read_to('00000000-0000-4000-8000-0000000fc002', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_ask))->>'read' as read_back_to_first, public.talk_read_to('00000000-0000-4000-8000-0000000fc002', (select (r->'thread'->>'id')::bigint from a_ask), (select (r->'post'->>'id')::bigint from a_show))->>'read' as post_of_another_thread;
select public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, '00000000-0000-4000-8000-0000000fc002')->'first_new' = 'null'::jsonb as never_moves_back;
-- Blocks hold: Bo blocks Ada; her threads leave his lists and her posts his pages.
insert into public.blocks (blocker, blocked) values ('00000000-0000-4000-8000-0000000fc002', '00000000-0000-4000-8000-0000000fc001');
select exists (select 1 from jsonb_array_elements(public.talk2_list('help', true, '00000000-0000-4000-8000-0000000fc002', 'latest', 1, 50)->'threads') e where (e->>'id')::bigint = (select (r->'thread'->>'id')::bigint from a_lone)) as bo_sees_adas_thread, (public.talk2_page((select (r->'thread'->>'id')::bigint from a_ask), true, '00000000-0000-4000-8000-0000000fc002')->>'blocked_some')::boolean as bo_told_some_hidden;
-- Bo's account deleted: his posts go with him, the answer he gave left unmarked (never a delete refused), his visits gone.
select pg_temp.tries($q$delete from auth.users where id = '00000000-0000-4000-8000-0000000fc002'$q$) as bo_deleted;
select (select answer is null from public.talk_threads where id = (select (r->'thread'->>'id')::bigint from a_ask)) as answer_gone_with_bo, (select count(*) from public.talk_visits where account = '00000000-0000-4000-8000-0000000fc002') as bos_visits_left;
