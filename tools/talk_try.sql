-- What supabase/talk.sql does, tried inside the rolled-back transaction of a
-- dry run: nothing here is kept. Made-up accounts, made and gone with the
-- transaction: Ada, Bo, Cy and Dee at Resend's test addresses (the checks'
-- pool), and Eve at example.com (anybody else). The house is the real one
-- (people.handle brickworks); its threads here are test ones, and go too.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/talk.sql --dry --try=tools/talk_try.sql --table=talk_threads
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line. Inside one transaction now() never moves, so the ten
-- minutes of "the same words again" and the first day's limits both hold
-- throughout; each read is its own statement.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated, service_role;
create function pg_temp.who(account uuid) returns text language sql as $$ select case account when '00000000-0000-4000-8000-0000000fa001' then 'ada' when '00000000-0000-4000-8000-0000000fa002' then 'bo' when '00000000-0000-4000-8000-0000000fa003' then 'cy' when '00000000-0000-4000-8000-0000000fa004' then 'dee' when '00000000-0000-4000-8000-0000000fa005' then 'eve' else 'someone else' end $$;
-- Nothing there before: the seven tables are new and empty.
select (select count(*) from public.talk_threads) as threads, (select count(*) from public.talk_posts) as posts, (select count(*) from public.talk_follows) as follows, (select count(*) from public.talk_reads) as reads, (select count(*) from public.talk_mentions) as mentions, (select count(*) from public.talk_reports) as reports, (select count(*) from public.talk_bans) as bans;
-- Row security on, no policy, no grant to any role, the server's included.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads, has_table_privilege('service_role', c.oid, 'insert') as server_writes from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname like 'talk\_%' and c.relkind = 'r' order by c.relname;
-- The functions: the server's alone (the triggers' and the push's nobody's), each security definer but the one pure check.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p where p.pronamespace = 'public'::regnamespace and (p.proname like 'talk\_%' or p.proname = 'notification_rows') order by p.proname;
-- The made-up five, and a test challenge open now.
insert into auth.users (id, instance_id, aud, role, email, created_at, email_confirmed_at) values ('00000000-0000-4000-8000-0000000fa001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk-try-ada@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fa002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk-try-bo@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fa003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk-try-cy@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fa004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk-try-dee@resend.dev', now(), now()), ('00000000-0000-4000-8000-0000000fa005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'talk-try-eve@example.com', now() - interval '30 days', now());
select public.answer_age('00000000-0000-4000-8000-0000000fa001', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000fa002', true)->>'over_13' as bo, public.answer_age('00000000-0000-4000-8000-0000000fa003', true)->>'over_13' as cy, public.answer_age('00000000-0000-4000-8000-0000000fa004', true)->>'over_13' as dee, public.answer_age('00000000-0000-4000-8000-0000000fa005', true)->>'over_13' as eve;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000fa001', 'talk-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000fa002', 'talk-try-bo', 'Bo Try'), ('00000000-0000-4000-8000-0000000fa003', 'talk-try-cy', 'Cy Try'), ('00000000-0000-4000-8000-0000000fa004', 'talk-try-dee', 'Dee Try'), ('00000000-0000-4000-8000-0000000fa005', 'talk-try-eve', 'Eve Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('TalkTry001', '00000000-0000-4000-8000-0000000fa001', 'Try lighthouse', 'Ada Try', 40, 100, true, now(), true, now(), false), ('TalkTry002', '00000000-0000-4000-8000-0000000fa002', 'Try barn', 'Bo Try', 30, 100, true, now(), true, now(), false);
insert into public.challenges (title, brief, starts_on, ends_on, test) values ('Talk try: tiny towns', 'Build a town that fits on a 16 by 16 plate.', current_date - 3, current_date + 10, true);
select public.talk_house() is not null as house_is_there;
-- A page's keys are refused, by the tables and by the functions: anybody signed out.
set local role anon;
select pg_temp.tries($q$select count(*) from public.talk_threads$q$) as anon_reads_threads, pg_temp.tries($q$select count(*) from public.talk_posts$q$) as anon_reads_posts, pg_temp.tries($q$select public.talk_threads_of(null, false)$q$) as anon_lists, pg_temp.tries($q$select public.talk_start('00000000-0000-4000-8000-0000000fa001', 'help', 'Forged', 'As Ada')$q$) as anon_writes_as_ada, pg_temp.tries($q$select public.talk_admin(false)$q$) as anon_moderates, pg_temp.tries($q$insert into public.talk_bans (account) values ('00000000-0000-4000-8000-0000000fa002')$q$) as anon_bans;
reset role;
-- ... and anybody signed in, writing as another account or as the owner.
set local role authenticated;
select pg_temp.tries($q$select count(*) from public.talk_reports$q$) as signed_in_reads_reports, pg_temp.tries($q$select public.talk_reply('00000000-0000-4000-8000-0000000fa002', 1, 'As Bo')$q$) as signed_in_writes_as_bo, pg_temp.tries($q$select public.talk_admin_act('ban', null, null, '00000000-0000-4000-8000-0000000fa002')$q$) as signed_in_bans, pg_temp.tries($q$update public.talk_posts set body = 'x'$q$) as signed_in_edits_posts;
reset role;
-- ... and the server's own key, straight at the tables: only through the functions.
set local role service_role;
select pg_temp.tries($q$select count(*) from public.talk_posts$q$) as server_reads_posts, pg_temp.tries($q$insert into public.talk_follows (account, thread) values ('00000000-0000-4000-8000-0000000fa001', 1)$q$) as server_writes_follows, pg_temp.tries($q$select public.talk_push(array['00000000-0000-4000-8000-0000000fa001'::uuid])$q$) as server_knocks_push;
reset role;
-- The house's first threads, in the test pool: written once, the second ask finds it.
select public.talk_seed('welcome', 'news', 'Welcome to Talk', 'Say hello: who you are and what you build.', true) as first, public.talk_seed('welcome', 'news', 'Welcome to Talk', 'Say hello: who you are and what you build.', true) as again, public.talk_seed('Bad Seed', 'news', 'x', 'y', true) as bad_key;
-- Each challenge open now has its thread in Challenges, by the house, made once.
select public.talk_ensure(true) as made_first, public.talk_ensure(true) as made_again;
select t.board, t.title, pg_temp.who(t.author) = 'someone else' as by_house, t.author = public.talk_house() as house, t.test, left(p.body, 60) as starts from public.talk_threads t join public.talk_posts p on p.thread = t.id and p.first where t.challenge is not null and t.test;
-- Ada starts threads: one with her model (Show and tell), one in Help; News is the house's; Bo may not start one with Ada's model.
create temporary table t_show on commit drop as select public.talk_start('00000000-0000-4000-8000-0000000fa001', 'show', 'My lighthouse, step by step', 'Here it is: https://brickworks.diy/m/TalkTry001 and step 4 https://brickworks.diy/app?view=TalkTry001&step=4 @talk-try-bo', 'TalkTry001') as r;
select r->'thread'->>'board' as board, r->'thread'->'model'->>'name' as model, r->'post'->>'first' as first_post, r->'post'->>'by_starter' as by_starter from t_show;
select public.talk_start('00000000-0000-4000-8000-0000000fa001', 'news', 'Not the house', 'Words') as news_by_ada, public.talk_start('00000000-0000-4000-8000-0000000fa002', 'show', 'Taking Ada''s model', 'Words', 'TalkTry001') as bo_with_adas_model, public.talk_start('00000000-0000-4000-8000-0000000fa001', 'show', 'Second thread on it', 'Other words', 'TalkTry001') as second_on_model, public.talk_start('00000000-0000-4000-8000-0000000fa001', 'kitchen', 'No such board', 'Words') as no_board, public.talk_start('00000000-0000-4000-8000-0000000fa001', 'help', 'Hi', 'Words') as short_title, public.talk_start('00000000-0000-4000-8000-0000000fa001', 'help', 'Tabs' || chr(9) || 'in a title', 'Words') as control_title, public.talk_start('00000000-0000-4000-8000-0000000fa001', 'help', 'Long words', repeat('x', 4001)) as long_body;
create temporary table t_help on commit drop as select public.talk_start('00000000-0000-4000-8000-0000000fa001', 'help', 'How do I join two plates at an angle?', 'I want a 30 degree roof on my lighthouse.') as r;
-- Five minutes pass: Ada's threads and her follows of them are dated back, as if written before the replies.
update public.talk_posts set at = now() - interval '5 minutes' where author = '00000000-0000-4000-8000-0000000fa001' and first;
update public.talk_threads set at = now() - interval '5 minutes', last_at = now() - interval '5 minutes' where author = '00000000-0000-4000-8000-0000000fa001';
update public.talk_follows set at = now() - interval '5 minutes' where account = '00000000-0000-4000-8000-0000000fa001';
-- Whom the first post names: Bo, once he is told (Ada's mention), three a post at most.
select public.talk_mention('00000000-0000-4000-8000-0000000fa001', (select (r->'post'->>'id')::bigint from t_show), array['talk-try-bo', 'talk-try-cy', 'talk-try-dee', 'talk-try-eve', 'talk-try-ada']) as named;
-- Eve is not in the checks' pool, Ada named herself: neither named. Bo, Cy and Dee are.
-- Bo replies in Ada's thread, answering her; Dee (an account made today) replies too.
create temporary table t_bo on commit drop as select public.talk_reply('00000000-0000-4000-8000-0000000fa002', (select (r->'thread'->>'id')::bigint from t_show), 'Lovely lamp. How did you light it?', (select (r->'post'->>'id')::bigint from t_show)) as r;
select r->'post'->>'by_starter' as bo_is_starter, r->'post'->>'answers' is not null as answers_ada from t_bo;
select public.talk_reply('00000000-0000-4000-8000-0000000fa004', (select (r->'thread'->>'id')::bigint from t_show), 'Welcome me: first day here.') as dee_first_day;
-- The same words again within ten minutes: a flood, refused. Eve (not a check's account) cannot write in a check's thread.
select public.talk_reply('00000000-0000-4000-8000-0000000fa002', (select (r->'thread'->>'id')::bigint from t_show), 'Lovely lamp. How did you light it?') as bo_again, public.talk_reply('00000000-0000-4000-8000-0000000fa005', (select (r->'thread'->>'id')::bigint from t_show), 'From outside the pool') as eve_in_test_thread;
-- Dee's first day: three threads, then refused for the day.
select public.talk_start('00000000-0000-4000-8000-0000000fa004', 'ideas', 'Idea one from Dee', 'One') ? 'thread' as one, public.talk_start('00000000-0000-4000-8000-0000000fa004', 'ideas', 'Idea two from Dee', 'Two') ? 'thread' as two, public.talk_start('00000000-0000-4000-8000-0000000fa004', 'ideas', 'Idea three from Dee', 'Three') ? 'thread' as three, public.talk_start('00000000-0000-4000-8000-0000000fa004', 'ideas', 'Idea four from Dee', 'Four') as four;
-- Another account: Bo may neither edit nor remove Ada's post; Ada edits her own.
select public.talk_change('00000000-0000-4000-8000-0000000fa002', (select (r->'post'->>'id')::bigint from t_help), 'edit', 'Bo''s words in Ada''s post') as bo_edits_ada, public.talk_change('00000000-0000-4000-8000-0000000fa002', (select (r->'post'->>'id')::bigint from t_help), 'remove') as bo_removes_ada, (public.talk_change('00000000-0000-4000-8000-0000000fa001', (select (r->'post'->>'id')::bigint from t_help), 'edit', 'I want a 30 degree roof. Hinges?')->'post'->>'edited_at') is not null as ada_edits_hers;
-- Notifications: Ada hears Bo's and Dee's replies (she follows what she started); Cy and Dee hear the mention; Bo hears neither his own nor the mention again, as he follows the thread now.
select pg_temp.who(a.id) as who, (select array_agg(r.kind || ':' || coalesce(r.item->'by'->>'handle', '-') order by r.at, r.kind) from public.notification_rows(a.id, now() - interval '1 hour', now() + interval '1 hour') r where r.kind like 'talk%') as talk_rows from (values ('00000000-0000-4000-8000-0000000fa001'::uuid), ('00000000-0000-4000-8000-0000000fa002'::uuid), ('00000000-0000-4000-8000-0000000fa003'::uuid), ('00000000-0000-4000-8000-0000000fa004'::uuid)) a(id);
-- Read: once Ada opens the thread, her rows say read.
select public.talk_read('00000000-0000-4000-8000-0000000fa001', (select (r->'thread'->>'id')::bigint from t_show)) as ada_reads;
select bool_and((r.item->>'read')::boolean) as all_read from public.talk_notice_rows('00000000-0000-4000-8000-0000000fa001', now() - interval '1 hour', now() + interval '1 hour') r;
-- A block: Ada blocks Bo. Bo's post in her thread leaves it for everybody but him; he cannot reply there or answer her anywhere; she cannot answer him.
create temporary table t_dee on commit drop as select public.talk_start('00000000-0000-4000-8000-0000000fa003', 'help', 'Cy asks: which hinge?', 'Which hinge brick do you use?') as r;
create temporary table t_ada2 on commit drop as select public.talk_reply('00000000-0000-4000-8000-0000000fa001', (select (r->'thread'->>'id')::bigint from t_dee), 'A click hinge, for angles that hold.') as r;
create temporary table t_bo2 on commit drop as select public.talk_reply('00000000-0000-4000-8000-0000000fa002', (select (r->'thread'->>'id')::bigint from t_dee), 'The 1x2 hinge, always.') as r;
insert into public.blocks (blocker, blocked) values ('00000000-0000-4000-8000-0000000fa001', '00000000-0000-4000-8000-0000000fa002');
select public.talk_reply('00000000-0000-4000-8000-0000000fa002', (select (r->'thread'->>'id')::bigint from t_show), 'Back again') as bo_in_adas_thread, public.talk_reply('00000000-0000-4000-8000-0000000fa001', (select (r->'thread'->>'id')::bigint from t_dee), 'I disagree', (select (r->'post'->>'id')::bigint from t_bo2)) as ada_answers_bo, public.talk_reply('00000000-0000-4000-8000-0000000fa002', (select (r->'thread'->>'id')::bigint from t_dee), 'Ada is wrong', (select (r->'post'->>'id')::bigint from t_ada2)) as bo_answers_ada_elsewhere;
select v.who, (select count(*) from jsonb_array_elements(public.talk_thread_page((select (r->'thread'->>'id')::bigint from t_show), true, v.id)->'posts') x where x->>'handle' = 'talk-try-bo') as bos_posts_seen_in_adas_thread from (values ('signed out', null::uuid), ('ada', '00000000-0000-4000-8000-0000000fa001'::uuid), ('bo', '00000000-0000-4000-8000-0000000fa002'::uuid), ('cy', '00000000-0000-4000-8000-0000000fa003'::uuid)) v(who, id);
select v.who, (select count(*) from jsonb_array_elements(public.talk_thread_page((select (r->'thread'->>'id')::bigint from t_dee), true, v.id)->'posts') x where x->>'handle' = 'talk-try-bo') as bos_posts_seen_in_cys_thread, public.talk_thread_page((select (r->'thread'->>'id')::bigint from t_dee), true, v.id)->>'blocked_some' as told_some_are_blocked from (values ('signed out', null::uuid), ('ada', '00000000-0000-4000-8000-0000000fa001'::uuid), ('cy', '00000000-0000-4000-8000-0000000fa003'::uuid)) v(who, id);
-- Ada hears nothing from Bo now; Bo cannot name Ada.
select (select count(*) from public.notification_rows('00000000-0000-4000-8000-0000000fa001', now() - interval '1 hour', now() + interval '1 hour') r where r.item->'by'->>'handle' = 'talk-try-bo') as ada_rows_by_bo;
select public.talk_mention('00000000-0000-4000-8000-0000000fa002', (select (r->'post'->>'id')::bigint from t_bo2), array['talk-try-ada']) as bo_names_ada;
-- Reports: Ada's own refused; three people's hide Dee's reply until the owner looks; one person twice counts once.
create temporary table t_target on commit drop as select (select p.id from public.talk_posts p where p.author = '00000000-0000-4000-8000-0000000fa004' and not p.first and p.body like 'Welcome me%') as post;
select public.talk_report('00000000-0000-4000-8000-0000000fa004', null, (select post from t_target), 'spam') as own_report, public.talk_report('00000000-0000-4000-8000-0000000fa001', null, (select post from t_target), 'spam') ? 'report' as one, public.talk_report('00000000-0000-4000-8000-0000000fa001', null, (select post from t_target), 'spam')->>'again' as one_again;
select (public.talk_report('00000000-0000-4000-8000-0000000fa003', null, (select post from t_target), 'offensive')->>'hidden')::boolean as hidden_after_two;
select (public.talk_report('00000000-0000-4000-8000-0000000fa002', null, (select post from t_target), 'spam', 'Note from Bo')->>'hidden')::boolean as hidden_after_three;
select v.who, (select count(*) from jsonb_array_elements(public.talk_thread_page((select (r->'thread'->>'id')::bigint from t_show), true, v.id)->'posts') x where x->>'id' = (select post from t_target)::text) as sees_hidden_reply from (values ('signed out', null::uuid), ('dee, its writer', '00000000-0000-4000-8000-0000000fa004'::uuid), ('ada', '00000000-0000-4000-8000-0000000fa001'::uuid)) v(who, id);
-- The owner's console: the open reports, then the post shown again (reports dismissed).
select jsonb_array_length(public.talk_admin(true)->'reports') as open_reports, (select count(*) from jsonb_array_elements(public.talk_admin(true)->'threads')) > 0 as threads_listed;
select public.talk_admin_act('show', null, (select post from t_target)) as shown_again;
select (select hidden_at is null from public.talk_posts where id = (select post from t_target)) as visible, jsonb_array_length(public.talk_admin(true)->'reports') as open_after;
-- Ban: Cy, for good; his posts leave Talk, he cannot write; the house cannot be banned; unban lets him back.
select public.talk_admin_act('ban', null, null, '00000000-0000-4000-8000-0000000fa003', null, null, 'Try ban') ->> 'done' as banned, public.talk_admin_act('ban', null, null, public.talk_house()) as ban_house, public.talk_admin_act('ban', null, null, '00000000-0000-4000-8000-0000000fa003', null, now() - interval '1 day') as ban_in_past;
select public.talk_reply('00000000-0000-4000-8000-0000000fa003', (select (r->'thread'->>'id')::bigint from t_help), 'Banned but trying') as banned_reply, public.talk_start('00000000-0000-4000-8000-0000000fa003', 'help', 'Banned thread', 'Words') as banned_start, public.talk_thread_page((select (r->'thread'->>'id')::bigint from t_dee), true, null) is null as banned_thread_gone, public.talk_trouble('00000000-0000-4000-8000-0000000fa003') as trouble;
select public.talk_admin_act('unban', null, null, '00000000-0000-4000-8000-0000000fa003')->>'done' as unbanned;
select public.talk_trouble('00000000-0000-4000-8000-0000000fa003') is null as may_write_again;
-- Lock, pin, move: a locked thread takes no reply; a pinned one lists first; a moved one says where it was.
select public.talk_admin_act('lock', (select (r->'thread'->>'id')::bigint from t_help))->>'done' as locked;
select public.talk_reply('00000000-0000-4000-8000-0000000fa004', (select (r->'thread'->>'id')::bigint from t_help), 'After the lock') as reply_when_locked;
select public.talk_admin_act('pin', (select (r->'thread'->>'id')::bigint from t_help))->>'done' as pinned;
select public.talk_threads_of('help', true)->'threads'->0->>'title' as first_in_help;
select public.talk_admin_act('move', (select (r->'thread'->>'id')::bigint from t_help), null, null, 'ideas')->>'done' as moved;
select (select board || ' from ' || moved_from from public.talk_threads where id = (select (r->'thread'->>'id')::bigint from t_help)) as now_in, public.talk_admin_act('move', (select (r->'thread'->>'id')::bigint from t_help), null, null, 'attic') as bad_board, public.talk_admin_act('explode', (select (r->'thread'->>'id')::bigint from t_help)) as bad_act;
-- Search: words in a title and in a post; a test pool's threads never in the other.
select jsonb_array_length(public.talk_threads_of(null, true, null, null, 30, 'hing')->'threads') as hinge_test, jsonb_array_length(public.talk_threads_of(null, false, null, null, 30, 'talk-try')->'threads') as in_real_pool, public.talk_threads_of(null, true, null, null, 30, 'lighthouse')->'threads'->0->>'title' as lighthouse;
-- The boards' counts, in the test pool.
select public.talk_board_counts(true) as boards;
-- The talk already happening on models (the real pool's newest five, counted only).
select jsonb_array_length(public.talk_talking(false, null, 5)) as real_comments_shown;
-- Follow and unfollow; signed out, nothing.
select public.talk_follow('00000000-0000-4000-8000-0000000fa003', (select (r->'thread'->>'id')::bigint from t_show), true) as cy_follows, public.talk_follow('00000000-0000-4000-8000-0000000fa003', (select (r->'thread'->>'id')::bigint from t_show), false) as cy_stops, public.talk_follow(null, 1, true) as nobody;
-- Removing the first post removes its thread; a removed thread is no page and no list's.
select public.talk_change('00000000-0000-4000-8000-0000000fa004', (select p.id from public.talk_posts p join public.talk_threads t on t.id = p.thread where p.first and t.title = 'Idea one from Dee'), 'remove')->>'thread_removed' as thread_removed;
select (select count(*) from jsonb_array_elements(public.talk_threads_of('ideas', true)->'threads') x where x->>'title' = 'Idea one from Dee') as still_listed;
-- What the notifications' count reads, Talk's rows among them, without an error, for each.
select pg_temp.who(a.id) as who, (select count(*) from public.notification_rows(a.id, now() - interval '1 day', now() + interval '1 day')) as rows from (values ('00000000-0000-4000-8000-0000000fa001'::uuid), ('00000000-0000-4000-8000-0000000fa004'::uuid)) a(id);
select public.notification_counts('00000000-0000-4000-8000-0000000fa004') as dee_counts;
-- A shared model's Show and tell thread, as its page asks: in its own pool only.
select public.talk_model_thread('TalkTry001', true)->>'title' as model_thread, public.talk_model_thread('TalkTry001', false) is null as none_in_real_pool, public.talk_model_thread('TalkTry002', true) is null as barn_has_none;
-- A photo on a post: its file served while the post may be seen; the account's photos listed for its deletion; the owner's removal says which files to delete.
create temporary table t_photo on commit drop as select public.talk_reply('00000000-0000-4000-8000-0000000fa001', (select (r->'thread'->>'id')::bigint from t_dee), 'My hinge build, photographed.', null, '{"id": "TalkTryPhot1", "width": 800, "height": 600}'::jsonb) as r;
select r->'post'->'photo' as photo, public.talk_photo_shown('TalkTryPhot1') as shown, public.talk_photo_shown('NoSuchPhoto1') as unknown_shown, 'TalkTryPhot1' = any (public.talk_photos_of('00000000-0000-4000-8000-0000000fa001')) as in_adas_photos from t_photo;
select public.talk_admin_act('remove', null, (select (r->'post'->>'id')::bigint from t_photo))->'photos' as removed_photos;
select public.talk_photo_shown('TalkTryPhot1') as shown_after_removal;
-- A push for Talk's rows: push_collect is Talk's where push_2.sql made one, and an account with no device is pushed nothing.
select case when to_regprocedure('public.push_collect(uuid, integer)') is null then 'push_2.sql not applied'
            else (select (position('talk_mention' in p.prosrc) > 0)::text from pg_proc p where p.oid = to_regprocedure('public.push_collect(uuid, integer)')) end as push_collect_talks,
       case when to_regprocedure('public.push_collect(uuid, integer)') is null then null
            else public.push_collect('00000000-0000-4000-8000-0000000fa004') is null end as dee_no_device_no_push;
select has_function_privilege('anon', 'public.push_collect(uuid, integer)', 'execute') as anon_collects,
       has_function_privilege('authenticated', 'public.push_collect(uuid, integer)', 'execute') as signed_in_collects,
       has_function_privilege('service_role', 'public.push_collect(uuid, integer)', 'execute') as server_collects
 where to_regprocedure('public.push_collect(uuid, integer)') is not null;
