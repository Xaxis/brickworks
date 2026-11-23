-- What supabase/challenge_prompts.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/challenge_prompts.sql --dry --try=tools/challenge_prompts_try.sql --table=challenges
--
-- Made-up accounts, made and gone with the transaction: Ada builds (13 or
-- over, a profile), Cy is under 13, Ed has been here a month (13 or over, no test account).
-- The house is the live one (talk_house). Every model a test model, so the
-- prompts here are test prompts, which no visitor's page shows. Each
-- statement is on one line: the dry run splits at a semicolon that ends a
-- line. Inside one transaction now() never moves, so a prompt is ended by
-- ending it (ended_at).
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- The month's answers to a visitor (a row's four new columns aside), with the house's four prompts in the table: md5s the same as the live project's answers to the same select before the file (both in bench/results/prompts-2026-11-23/sql_dry.txt), and never a prompt.
select md5(coalesce((to_jsonb(public.challenge_shown(false)) - array['kind', 'template', 'stack', 'seed'])::text, '')) as shown, md5(coalesce((to_jsonb(public.challenge_next(false)) - array['kind', 'template', 'stack', 'seed'])::text, '')) as "next", md5(coalesce((select string_agg(x::text, '|') from public.challenge_past(false) x), '')) as past, md5(coalesce((select string_agg(x::text, '|') from public.challenge_list(false) x), '')) as list, md5(coalesce((to_jsonb(public.challenge_open(false)) - array['kind', 'template', 'stack', 'seed'])::text, '')) as "open";
select coalesce((public.challenge_shown(false)).kind, 'none') as "shown is", coalesce((public.challenge_open(false)).kind, 'none') as "open is", (select count(*) from public.challenge_list(false) x where x->>'kind' = 'prompt') as "prompts in the month's list";
-- The house's four, each once, a week each from Monday 23 November.
select seed, title, starts_on, ends_on, ends_on - starts_on as days, kind, template is null as "no template yet" from public.challenges where seed is not null and not test order by starts_on;
-- Any test prompt a flow left open is ended first: one at a time.
update public.challenges set ended_at = now() where test and kind = 'prompt' and ended_at is null;
insert into auth.users (id, instance_id, aud, role, email, created_at) values ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prompts-ada@resend.dev', now() - interval '30 days'), ('00000000-0000-4000-8000-0000000000d3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prompts-cy@resend.dev', now() - interval '30 days'), ('00000000-0000-4000-8000-0000000000d5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prompts-ed@example.org', now() - interval '30 days');
select public.answer_age('00000000-0000-4000-8000-0000000000d1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000000d3', false)->>'over_13' as cy, public.answer_age('00000000-0000-4000-8000-0000000000d5', true)->>'over_13' as ed;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000d1', 'prompts-try-ada', 'Ada Try');
-- The house's templates (link only), Ada's copies of the first (one listed, one by link, one listed with no credit), a model of hers that is no copy, Cy's copy, and the stack.
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published, remixed_from, licence) values ('PromptTr0A', public.talk_house(), 'Try plate', 'Brickworks', 1, 100, false, null, true, true, null, 'cc-by-4.0'), ('PromptTr0B', public.talk_house(), 'Try plate two', 'Brickworks', 1, 100, false, null, true, true, null, 'cc-by-4.0'), ('PromptTr1A', '00000000-0000-4000-8000-0000000000d1', 'Try habitat', 'Ada Try', 40, 100, true, now(), true, true, 'PromptTr0A', null), ('PromptTr1B', '00000000-0000-4000-8000-0000000000d1', 'Try secret habitat', 'Ada Try', 40, 100, false, null, true, true, 'PromptTr0A', null), ('PromptTr1C', '00000000-0000-4000-8000-0000000000d1', 'Try nameless habitat', null, 40, 100, true, now(), true, true, 'PromptTr0A', null), ('PromptTr1D', '00000000-0000-4000-8000-0000000000d1', 'Try house', 'Ada Try', 40, 100, true, now(), true, true, null, null), ('PromptTr3A', '00000000-0000-4000-8000-0000000000d3', 'Try by Cy', null, 30, 100, false, null, true, true, 'PromptTr0A', null), ('PromptTr2A', '00000000-0000-4000-8000-0000000000d1', 'Try second habitat', 'Ada Try', 40, 100, true, now(), true, true, 'PromptTr0B', null), ('PromptTrSt', public.talk_house(), 'Try stack', 'Brickworks', 80, 100, true, now(), true, true, null, null);
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, now(), parts, 100 from public.shared_models where id like 'PromptTr%';
-- Setting one: refused when it ends before today, runs more than two weeks, names no published model, or shares a day with another prompt.
select public.prompt_set('Try past', 'Brief', current_date - 10, current_date - 4, test => true)->>'refused' as "ends before today", public.prompt_set('Try long', 'Brief', current_date, current_date + 20, test => true)->>'refused' as "three weeks", public.prompt_set('Try nothing', 'Brief', current_date, template => 'NoSuchOne1', test => true)->>'refused' as "no template";
select public.prompt_set('Try week one', 'A home for one minifigure.', current_date, template => 'PromptTr0A', test => true) ?| array['challenge'] as "set", public.prompt_set('Try overlap', 'Brief', current_date + 3, test => true)->>'refused' as "a day shared", public.prompt_set('Try overlap', 'Brief', current_date + 3, test => true)->'with'->>'title' as "with";
select title, kind, ends_on - starts_on as days, template, test, seed is null as "no seed" from public.challenges where title = 'Try week one';
-- A prompt is no month's challenge: not open, shown, listed or voted in as one; a month's own setter does not see it in its days.
select coalesce((public.challenge_open(true)).title, 'none') as "month open for tests", coalesce((public.challenge_shown(true)).kind, 'none') as "a tests page shows", (select count(*) from public.challenge_list(true) x where x->>'title' = 'Try week one') as "in the month's list", (select count(*) from public.prompt_list(true) x where x->>'title' = 'Try week one') as "in the prompts' list";
select public.prompt_of('PromptTr0A')->>'title' as "the template's prompt", public.prompt_of('PromptTr1D') is null as "another model's", public.prompt_of('PromptTr0B') is null as "a template of none open";
-- Entering: a listed, credited copy enters; again it is there already; one by link, one with no credit, one by somebody under 13, a model that is no copy and somebody else's each say why.
select public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr1A') as listed, public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr1A')->>'already' as again;
select public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr1B')->>'refused' as "by link", public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr1C')->>'refused' as "no credit", public.prompt_enter('00000000-0000-4000-8000-0000000000d3', 'PromptTr3A')->>'refused' as "under 13", public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr1D')->>'refused' as "no copy", public.prompt_enter('00000000-0000-4000-8000-0000000000d5', 'PromptTr1A')->>'refused' as "not hers";
select e.way, e.owner = '00000000-0000-4000-8000-0000000000d1' as "ada's", c.title from public.challenge_entries e join public.challenges c on c.id = e.challenge where e.model = 'PromptTr1A';
-- No vote: refused as a month's would be once closed.
select public.challenge_vote('00000000-0000-4000-8000-0000000000d5', (select id from public.challenges where title = 'Try week one'), 'PromptTr1A', true)->>'refused' as "a vote", public.challenge_vote_round('00000000-0000-4000-8000-0000000000d5', (select id from public.challenges where title = 'Try week one'), 'PromptTr1A', true)->>'refused' as "a vote by round";
-- Its page: the template's card at the top, the entry's card, one maker.
select x->>'kind' as kind, x->>'state' as state, x->'template'->>'id' as template, jsonb_array_length(x->'entries') as entries, x->'entries'->0->>'model' as newest, x->>'makers' as makers, x->'stack' = 'null'::jsonb as "no stack yet" from (select public.prompt_page_at((select id from public.challenges where title = 'Try week one'), true) as x) p;
select public.prompt_page_at((select id from public.challenges where title = 'Try week one'), false) is null as "a visitor's page of a test one", public.prompt_page_at((select id from public.challenges where kind = 'month' order by id desc limit 1), true) is null as "a month's id";
-- Kept out, one tap: out of the prompt, a month's entry left; entered again.
select public.prompt_withdraw('00000000-0000-4000-8000-0000000000d1', 'PromptTr1A') as "taken out";
select (select count(*) from public.challenge_entries e where e.model = 'PromptTr1A') as "entries left", public.prompt_withdraw('00000000-0000-4000-8000-0000000000d1', 'PromptTr1A') as "taken out again";
select public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr1A')->>'entered' as "entered again";
-- The house's part: nothing due for a prompt with a template, no seed and open.
select count(*) as "due now" from public.prompt_house_due(true) x where x->>'title' = 'Try week one';
-- Week one ends; nothing of it settled; week two opens, Ada enters it too: two weeks running.
update public.challenges set ended_at = now() where title = 'Try week one';
select public.challenge_settle_due(true) >= 0 as settled, (select settled_at is null from public.challenges where title = 'Try week one') as "week one never settled";
select public.prompt_set('Try week two', 'A winter scene.', current_date, template => 'PromptTr0B', test => true) ?| array['challenge'] as "set";
-- One still to come has a page of its own, as a prompt, never as a month's.
select public.prompt_set('Try week three', 'A workshop.', current_date + 7, test => true) ?| array['challenge'] as "set ahead";
select x->>'kind' as kind, x->>'state' as state, jsonb_array_length(x->'entries') as entries from (select public.prompt_page_at((select id from public.challenges where title = 'Try week three'), true) as x) p;
select public.prompt_enter('00000000-0000-4000-8000-0000000000d1', 'PromptTr2A')->>'entered' as "week two";
select public.prompt_streak('00000000-0000-4000-8000-0000000000d1', true) as streak, (select n from public.achievement_numbers('00000000-0000-4000-8000-0000000000d1', true) where track = 'streak') as "its number", (select n from public.achievement_numbers('00000000-0000-4000-8000-0000000000d1', true) where track = 'challenger') as "months entered";
select public.achievement_mark('00000000-0000-4000-8000-0000000000d1') >= 1 as marked;
select (select max(level) from public.achievement_marks where account = '00000000-0000-4000-8000-0000000000d1' and track = 'streak') as "streak level";
select public.achievement_levels('00000000-0000-4000-8000-0000000000d1', true) as levels;
-- Its stack is due once it ended: the entries, the foot first; kept once.
select x->>'title' as title, x->>'state' as state, jsonb_array_length(x->'entries') as entries, x->'entries'->0->>'handle' as foot from public.prompt_house_due(true) x where x->>'title' = 'Try week one';
select public.prompt_stack_set((select id from public.challenges where title = 'Try week one'), 'PromptTrSt')->>'kept' as kept, public.prompt_stack_set((select id from public.challenges where title = 'Try week one'), 'PromptTrSt')->>'kept' as "kept again", public.prompt_stack_set((select id from public.challenges where title = 'Try week two'), 'PromptTrSt')->>'kept' as "an open one's";
select (public.prompt_page_at((select id from public.challenges where title = 'Try week one'), true))->'stack'->>'id' as "its page's stack", (select count(*) from public.prompt_house_due(true) x where x->>'title' = 'Try week one') as "due after";
-- A month's column is never a prompt's: the checks hold it.
select pg_temp.tries($q$insert into public.challenges (title, brief, starts_on, ends_on, test, template) values ('Try month', 'B', current_date, current_date + 20, true, 'PromptTr0A')$q$) as "a month with a template", pg_temp.tries($q$insert into public.challenges (kind, title, brief, starts_on, ends_on, test) values ('prompt', 'Try long', 'B', current_date, current_date + 20, true)$q$) as "a prompt of three weeks", pg_temp.tries($q$insert into public.challenges (kind, title, brief, starts_on, ends_on, test) values ('weekly', 'Try kind', 'B', current_date, current_date + 2, true)$q$) as "another kind";
-- Told as a month's is: Ed, here a month, hears the house's Habitat open today; Ada, a test account, hears of week two.
select count(*) filter (where n.kind = 'challenge_open' and n.item->>'title' = 'Habitat') as "ed hears habitat" from public.notification_rows('00000000-0000-4000-8000-0000000000d5', now() - interval '2 days', now()) n;
select count(*) filter (where n.kind = 'challenge_open' and n.item->>'title' = 'Try week two') as "ada hears week two" from public.notification_rows('00000000-0000-4000-8000-0000000000d1', now() - interval '2 days', now()) n;
-- Grants: the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authed, has_function_privilege('service_role', p.oid, 'execute') as server from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public' and p.proname like 'prompt\_%' order by 1;
