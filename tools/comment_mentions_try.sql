-- What supabase/comment_mentions.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/achievements.sql \
--       --again=supabase/challenge_notices.sql,supabase/comment_mentions.sql \
--       --dry --try=tools/comment_mentions_try.sql --table=comment_mentions
--
-- Made-up accounts, made and gone with the transaction, at Resend test
-- addresses: Pia designs a tower; Lia comments on it naming people; Max,
-- Quin and Rue have profiles; Ola said she is under 13, so has none; Nia
-- has none either.
-- Times are set by hand: inside one transaction now() never moves. Each
-- statement is on one line: the dry run splits at a semicolon that ends a
-- line.
insert into auth.users (id, instance_id, aud, role, email, created_at) values ('00000000-0000-4000-8000-0000000009a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-pia@resend.dev', now() - interval '10 days'), ('00000000-0000-4000-8000-0000000009a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-lia@resend.dev', now() - interval '10 days'), ('00000000-0000-4000-8000-0000000009a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-max@resend.dev', now() - interval '10 days'), ('00000000-0000-4000-8000-0000000009a4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-quin@resend.dev', now() - interval '10 days'), ('00000000-0000-4000-8000-0000000009a5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-rue@resend.dev', now() - interval '10 days'), ('00000000-0000-4000-8000-0000000009a6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-ola@resend.dev', now() - interval '10 days'), ('00000000-0000-4000-8000-0000000009a7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cm-nia@resend.dev', now() - interval '10 days');
select public.answer_age('00000000-0000-4000-8000-0000000009a1', true)->>'over_13' as pia, public.answer_age('00000000-0000-4000-8000-0000000009a2', true)->>'over_13' as lia, public.answer_age('00000000-0000-4000-8000-0000000009a3', true)->>'over_13' as max, public.answer_age('00000000-0000-4000-8000-0000000009a4', true)->>'over_13' as quin, public.answer_age('00000000-0000-4000-8000-0000000009a5', true)->>'over_13' as rue, public.answer_age('00000000-0000-4000-8000-0000000009a6', false)->>'over_13' as ola, public.answer_age('00000000-0000-4000-8000-0000000009a7', true)->>'over_13' as nia;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000009a1', 'cm-try-pia', 'Pia Try'), ('00000000-0000-4000-8000-0000000009a2', 'cm-try-lia', 'Lia Try'), ('00000000-0000-4000-8000-0000000009a3', 'cm-try-max', 'Max Try'), ('00000000-0000-4000-8000-0000000009a4', 'cm-try-quin', 'Quin Try'), ('00000000-0000-4000-8000-0000000009a5', 'cm-try-rue', 'Rue Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('CmTry00001', '00000000-0000-4000-8000-0000000009a1', 'Try tower', 'Pia Try', 12, 100, true, now() - interval '3 days', true, now() - interval '3 days', true);
insert into public.share_versions (model, n, at, parts, bytes, steps) values ('CmTry00001', 1, now() - interval '3 days', 12, 100, 6);
-- Lia's comment names Max, Pia (the designer), Ola (under 13, so no profile to name), a handle nobody has, and herself.
select public.add_comment('00000000-0000-4000-8000-0000000009a2', 'CmTry00001', 1, null, 'Try: ask @cm-try-max, @CM-TRY-PIA, @cm-try-ola, @cm-try-nobody and me')->'comment'->>'id' is not null as "Lia's comment";
update public.model_comments set at = now() - interval '2 days' where body like 'Try: ask @cm-try-max%';
select public.comment_mention('00000000-0000-4000-8000-0000000009a2', (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), array['cm-try-max', 'CM-TRY-PIA', 'cm-try-ola', 'cm-try-nobody', 'cm-try-lia']) as "named";
-- Max hears it as a mention; Pia hears it as a comment on her model, not twice; Ola, nobody, nothing. (A test account
-- hears of every test challenge too, which these leave out.)
select n.kind, n.item->>'said' as said, n.item->'by'->>'handle' as by, n.model from public.notification_rows('00000000-0000-4000-8000-0000000009a3', now() - interval '30 days', now()) n where n.kind not like 'challenge%';
select string_agg(n.kind, ', ' order by n.kind) as "Pia hears" from public.notification_rows('00000000-0000-4000-8000-0000000009a1', now() - interval '30 days', now()) n where n.kind not like 'challenge%';
select count(*) as "Ola hears" from public.notification_rows('00000000-0000-4000-8000-0000000009a6', now() - interval '30 days', now()) n where n.kind = 'mention';
-- Named again, by its writer's edit: those already named are kept once, and at most three a comment.
select public.comment_mention('00000000-0000-4000-8000-0000000009a2', (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), array['cm-try-max', 'cm-try-quin', 'cm-try-rue']) as "named again";
select count(*) as "kept" from public.comment_mentions where comment = (select id from public.model_comments where body like 'Try: ask @cm-try-max%');
-- Nobody else names people in her comment, nor in one that is not there. (Under 13, nobody writes one: comments_guard.)
select public.comment_mention('00000000-0000-4000-8000-0000000009a3', (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), array['cm-try-rue']) as "Max in Lia's", public.comment_mention('00000000-0000-4000-8000-0000000009a2', 999999999999, array['cm-try-rue']) as "no such", public.comment_mention(null, (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), array['cm-try-rue']) as "nobody";
-- What the page links: each comment's named, in the order named.
select m.comment = (select id from public.model_comments where body like 'Try: ask @cm-try-max%') as "Lia's", string_agg(m.handle, ', ') as handles from public.comment_mentions_of(array[(select id from public.model_comments where body like 'Try: ask @cm-try-max%')]) m group by m.comment;
-- Max answers Lia; her reply naming him is told to him once, as a reply, not a mention.
select public.add_reply('00000000-0000-4000-8000-0000000009a3', (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), 'Try: Max answers')->'comment'->>'parent' is not null as "Max's reply";
update public.model_comments set at = now() - interval '36 hours' where body = 'Try: Max answers';
select public.add_reply('00000000-0000-4000-8000-0000000009a2', (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), 'Try: thanks @cm-try-max')->'comment'->>'parent' is not null as "Lia's reply";
update public.model_comments set at = now() - interval '1 day' where body = 'Try: thanks @cm-try-max';
select public.comment_mention('00000000-0000-4000-8000-0000000009a2', (select id from public.model_comments where body = 'Try: thanks @cm-try-max'), array['cm-try-max'])->'mentioned' as "her reply names";
select n.kind, n.item->>'said' as said from public.notification_rows('00000000-0000-4000-8000-0000000009a3', now() - interval '30 days', now()) n where n.kind not like 'challenge%' order by n.at;
-- Pia hides Lia's comment: its mention goes from Max's notifications with it.
select public.change_comment('00000000-0000-4000-8000-0000000009a1', (select id from public.model_comments where body like 'Try: ask @cm-try-max%'), 'hide')->'comment'->>'hidden' as hidden;
select count(*) as "Max's mentions now" from public.notification_rows('00000000-0000-4000-8000-0000000009a3', now() - interval '30 days', now()) n where n.kind = 'mention';
-- Gone with its comment.
delete from public.model_comments where body like 'Try: ask @cm-try-max%';
select count(*) as "left" from public.comment_mentions where account = '00000000-0000-4000-8000-0000000009a3';
-- Nobody but the server runs any of it, or reads the table.
select r.rolname, p.proname from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname in ('comment_mention', 'comment_mentions_of', 'comment_mentions_said', 'notification_rows') and has_function_privilege(r.rolname, p.oid, 'execute');
select count(*) as "the service role runs" from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('comment_mention', 'comment_mentions_of', 'comment_mentions_said', 'notification_rows') and has_function_privilege('service_role', p.oid, 'execute');
select has_table_privilege('anon', 'public.comment_mentions', 'select') as anon_reads, has_table_privilege('authenticated', 'public.comment_mentions', 'select') as signed_in_reads, has_table_privilege('service_role', 'public.comment_mentions', 'select') as service_reads, (select relrowsecurity from pg_class where oid = 'public.comment_mentions'::regclass) as row_security
