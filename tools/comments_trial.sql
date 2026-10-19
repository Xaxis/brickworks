-- What supabase/comments.sql does, tried inside the rolled-back transaction
-- of a dry run, after supabase/trust.sql (which it needs and which the
-- project does not have yet): nothing here is kept.
--
--   set -a; . ./.env; set +a
--   cat supabase/trust.sql supabase/comments.sql > /tmp/trust_comments.sql
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs \
--     /tmp/trust_comments.sql --dry --try=tools/comments_trial.sql --table=model_comments
--
-- Made-up accounts at Resend test addresses, made and gone with the
-- transaction: b1 under 13, b2 and b7 13 or over, b3 a model's owner, b4
-- 13 or over and taken out of the gallery, b5 never asked, b6 an owner
-- under 13. Each statement is on one line: the dry run splits at a
-- semicolon that ends a line. Everything happens at one now(), so the
-- limits count every row.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-young@resend.dev'), ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-grown@resend.dev'), ('00000000-0000-4000-8000-0000000000b3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-owner@resend.dev'), ('00000000-0000-4000-8000-0000000000b4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-barred@resend.dev'), ('00000000-0000-4000-8000-0000000000b5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-unasked@resend.dev'), ('00000000-0000-4000-8000-0000000000b6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-youngowner@resend.dev'), ('00000000-0000-4000-8000-0000000000b7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trial-c-other@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000b1', false) ->> 'over_13' as b1, public.answer_age('00000000-0000-4000-8000-0000000000b2', true) ->> 'over_13' as b2, public.answer_age('00000000-0000-4000-8000-0000000000b3', true) ->> 'over_13' as b3, public.answer_age('00000000-0000-4000-8000-0000000000b4', true) ->> 'over_13' as b4, public.answer_age('00000000-0000-4000-8000-0000000000b6', false) ->> 'over_13' as b6, public.answer_age('00000000-0000-4000-8000-0000000000b7', true) ->> 'over_13' as b7;
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000b4', 'Trial');
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000b2', 'trial-c-grown', 'Trial Grown'), ('00000000-0000-4000-8000-0000000000b3', 'trial-c-owner', 'Trial Owner');
insert into public.shared_models (id, owner, name, parts, bytes, steps) values ('TrialCom01', '00000000-0000-4000-8000-0000000000b3', 'Trial tower', 12, 100, 6), ('TrialCom02', '00000000-0000-4000-8000-0000000000b6', 'Trial hut', 4, 50, 2);
insert into public.share_versions (model, n, parts, steps, bytes) values ('TrialCom01', 1, 12, 6, 100), ('TrialCom02', 1, 4, 2, 50);
insert into public.share_versions (model, n, parts, steps, bytes, first_changed) values ('TrialCom01', 2, 12, 6, 100, 3);
-- Who may write: refused in words for each reason, before anything is counted.
select public.add_comment(null, 'TrialCom01', 2, null, 'Trial: hello') as "no account";
select public.add_comment('00000000-0000-4000-8000-0000000000b1', 'TrialCom01', 2, null, 'Trial: hello') as "under 13";
select public.add_comment('00000000-0000-4000-8000-0000000000b5', 'TrialCom01', 2, null, 'Trial: hello') as "never asked";
select public.add_comment('00000000-0000-4000-8000-0000000000b4', 'TrialCom01', 2, null, 'Trial: hello') as "taken out of the gallery";
select public.add_comment('00000000-0000-4000-8000-0000000000b7', 'TrialCom02', 1, null, 'Trial: hello') as "on a model of an owner under 13";
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'Nowhere001', 1, null, 'Trial: hello') as "on no model";
-- 13 or over: on the model, and on step 4 of version 2; not on a step or a version it does not have, nor nothing.
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 2, null, 'Trial: what a tower') -> 'comment' as "13 or over, on the model";
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 2, 4, E'Trial: this part goes under,\nnot over') -> 'comment' as "on step 4 of version 2";
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 2, 9, 'Trial: step 9?') as "on a step version 2 does not have";
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 3, 1, 'Trial: version 3?') as "on a version it does not have";
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 2, 1, E'  \n ') as "only space";
select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 2, 1, repeat('a', 1001)) as "1,001 characters";
-- Whatever writes: the table refuses under 13, barred and a closed model by its trigger.
select pg_temp.tries($q$insert into public.model_comments (model, version, author, body) values ('TrialCom01', 2, '00000000-0000-4000-8000-0000000000b1', 'Trial: written directly')$q$) as "under 13, written directly";
select pg_temp.tries($q$insert into public.model_comments (model, version, author, body) values ('TrialCom01', 2, '00000000-0000-4000-8000-0000000000b4', 'Trial: written directly')$q$) as "barred, written directly";
select pg_temp.tries($q$insert into public.model_comments (model, version, author, body) values ('TrialCom01', 2, '00000000-0000-4000-8000-0000000000b2', '<a href=x>x</a>' || chr(7))$q$) as "a control character";
-- The limit: 10 an hour. Two made above, so 8 more go and the rest are refused.
select count(*) filter (where r ? 'comment') as allowed, count(*) filter (where r ->> 'refused' = 'limit') as refused_for_the_limit from (select public.add_comment('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', 2, 1, 'Trial: again ' || g) as r from generate_series(1, 10) g) tried;
-- Comments off, by the model's owner only; then nobody may add one, whatever writes; then on again.
select public.set_comments('00000000-0000-4000-8000-0000000000b2', 'TrialCom01', false) as "off, by somebody else";
select public.set_comments('00000000-0000-4000-8000-0000000000b3', 'TrialCom01', false) as "off, by its owner";
select public.add_comment('00000000-0000-4000-8000-0000000000b7', 'TrialCom01', 2, null, 'Trial: anyone?') as "a comment while off";
select pg_temp.tries($q$insert into public.model_comments (model, version, author, body) values ('TrialCom01', 2, '00000000-0000-4000-8000-0000000000b7', 'Trial: written directly')$q$) as "written directly while off";
select public.set_comments('00000000-0000-4000-8000-0000000000b3', 'TrialCom01', true) as "on again";
select public.add_comment('00000000-0000-4000-8000-0000000000b7', 'TrialCom01', 1, 5, 'Trial: step 5 of the first') -> 'comment' ->> 'version' as "on step 5 of version 1, now";
-- The owner hides one on their model; nobody else may.
select public.change_comment('00000000-0000-4000-8000-0000000000b7', (select min(id) from public.model_comments where model = 'TrialCom01'), 'hide') as "hidden by somebody else";
select public.change_comment('00000000-0000-4000-8000-0000000000b3', (select min(id) from public.model_comments where model = 'TrialCom01'), 'hide') -> 'comment' ->> 'hidden' as "hidden by its owner";
select jsonb_array_length(public.comments_on('TrialCom01', null) -> 'comments') as "a visitor sees", jsonb_array_length(public.comments_on('TrialCom01', '00000000-0000-4000-8000-0000000000b3') -> 'comments') as "its owner sees", jsonb_array_length(public.comments_on('TrialCom01', '00000000-0000-4000-8000-0000000000b2') -> 'comments') as "its author sees";
select c ->> 'body' as body, c ->> 'version' as version, c ->> 'step' as step, c ->> 'by' as by, c ->> 'hidden' as hidden, c ->> 'mine' as mine, c ? 'author' as names_an_account from jsonb_array_elements(public.comments_on('TrialCom01', '00000000-0000-4000-8000-0000000000b3') -> 'comments') c where c ->> 'body' not like 'Trial: again%';
-- Its author edits it, and removes it; nobody else may.
select public.change_comment('00000000-0000-4000-8000-0000000000b2', (select max(id) from public.model_comments where author = '00000000-0000-4000-8000-0000000000b7'), 'edit', 'Trial: mine?') as "edited by somebody else";
select public.change_comment('00000000-0000-4000-8000-0000000000b7', (select max(id) from public.model_comments where author = '00000000-0000-4000-8000-0000000000b7'), 'edit', 'Trial: step 5, edited') -> 'comment' ->> 'edited_at' is not null as "edited by its author";
select public.change_comment('00000000-0000-4000-8000-0000000000b7', (select max(id) from public.model_comments where author = '00000000-0000-4000-8000-0000000000b7'), 'remove') ->> 'removed' as "removed by its author";
select id, removed_by, removed_at is not null as removed, edited_at is not null as edited, body from public.model_comments where author = '00000000-0000-4000-8000-0000000000b7';
-- A report about a comment: its model named with it; its stream the test's; the digest says it is a comment.
insert into public.reports (model, comment, reason, note) values ('TrialCom01', (select min(id) from public.model_comments where model = 'TrialCom01'), 'offensive', 'Trial: rude');
select pg_temp.tries($q$insert into public.reports (comment, reason) values ((select min(id) from public.model_comments), 'spam')$q$) as "a report naming the comment alone";
select public.report_stream(r) as stream from public.reports r where r.comment is not null and r.model = 'TrialCom01';
select public.claim_report_digest('owner', (select max(id) from public.reports where model = 'TrialCom01')) -> 'reports' -> 0 as "the report's digest";
-- The site's owner sees it, and removes it: shown to nobody, kept.
select jsonb_array_length(public.admin_comments(array[(select min(id) from public.model_comments where model = 'TrialCom01')])) as "on the admin page";
select public.admin_remove_comment((select min(id) from public.model_comments where model = 'TrialCom01')) as "removed by the site's owner";
select jsonb_array_length(public.comments_on('TrialCom01', '00000000-0000-4000-8000-0000000000b3') -> 'comments') as "its owner sees now", (select removed_by from public.model_comments where id = (select min(id) from public.model_comments where model = 'TrialCom01')) as removed_by;
-- Telling the owner: off until they choose it; then once a day, a test's dry.
select public.mail_choice('00000000-0000-4000-8000-0000000000b3') as "an owner who never chose";
select public.claim_comment_digest('00000000-0000-4000-8000-0000000000b3') as "nothing claimed while off";
select public.mail_choice('00000000-0000-4000-8000-0000000000b3', true) as "chosen";
select d ->> 'test' as test, d ->> 'email' as email, jsonb_array_length(d -> 'comments') as comments, d ->> 'more' as more from jsonb_array_elements(public.claim_comment_digest('00000000-0000-4000-8000-0000000000b3')) d;
select public.add_comment('00000000-0000-4000-8000-0000000000b7', 'TrialCom01', 2, 2, 'Trial: after the email') -> 'comment' ->> 'step' as "a comment after it";
select public.claim_comment_digest() as "the same day: nothing more";
select public.finish_comment_digest((select max(id) from public.comment_digests where owner = '00000000-0000-4000-8000-0000000000b3'), 'dry', 'Brickworks: comments', 'text', '<p>html</p>') as "recorded dry";
select state, comments, subject from public.comment_digests where owner = '00000000-0000-4000-8000-0000000000b3';
-- Nobody but the server, and the server only through the functions.
select grantee, string_agg(privilege_type, ', ') as what from information_schema.role_table_grants where table_schema = 'public' and table_name in ('model_comments', 'comment_settings', 'mail_choices', 'comment_digests') and grantee in ('anon', 'authenticated', 'service_role', 'PUBLIC') group by grantee;
select has_function_privilege('anon', 'public.add_comment(uuid, text, integer, integer, text)', 'execute') as anon_adds, has_function_privilege('authenticated', 'public.comments_on(text, uuid)', 'execute') as signed_in_reads, has_function_privilege('service_role', 'public.add_comment(uuid, text, integer, integer, text)', 'execute') as server_adds;
-- Nothing of anybody's is changed: the new column empty on every report already there.
select count(*) filter (where comment is not null) as about_a_comment, count(*) as reports from public.reports where model is distinct from 'TrialCom01'
