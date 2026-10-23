-- What supabase/replies.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/replies.sql --dry \
--       --try=tools/replies_try.sql --table=model_comments
--
-- After the live files, which the project has. Made-up accounts, made and
-- gone with the transaction: Ada designs a tower; Bob comments on its step
-- 4, Cy replies, Ada replies to Cy's reply (which joins Bob's thread); Kid
-- is under 13. Times are set by hand: inside one transaction now() never
-- moves. Each statement is on one line: the dry run splits at a semicolon
-- that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000008a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reply-ada@resend.dev'), ('00000000-0000-4000-8000-0000000008b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reply-bob@resend.dev'), ('00000000-0000-4000-8000-0000000008c3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reply-cy@resend.dev'), ('00000000-0000-4000-8000-0000000008d4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reply-kid@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000008a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000008b2', true)->>'over_13' as bob, public.answer_age('00000000-0000-4000-8000-0000000008c3', true)->>'over_13' as cy, public.answer_age('00000000-0000-4000-8000-0000000008d4', false)->>'over_13' as kid;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000008a1', 'reply-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000008b2', 'reply-try-bob', 'Bob Try'), ('00000000-0000-4000-8000-0000000008c3', 'reply-try-cy', 'Cy Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('ReplyTry01', '00000000-0000-4000-8000-0000000008a1', 'Try tower', 'Ada Try', 12, 100, true, now() - interval '3 days', true, now() - interval '3 days', true);
insert into public.share_versions (model, n, at, parts, bytes, steps) values ('ReplyTry01', 1, now() - interval '3 days', 12, 100, 6);
-- Bob on step 4, and on the whole model; Cy answers the first, Ada answers Cy's reply (it joins Bob's thread).
select public.add_comment('00000000-0000-4000-8000-0000000008b2', 'ReplyTry01', 1, 4, 'Try: step 4 goes under')->'comment'->>'step' as "Bob on step", public.add_comment('00000000-0000-4000-8000-0000000008b2', 'ReplyTry01', 1, null, 'Try: Bob on the whole')->'comment'->>'parent' as "and on the whole, parent";
update public.model_comments set at = now() - interval '50 minutes' where body = 'Try: step 4 goes under';
update public.model_comments set at = now() - interval '45 minutes' where body = 'Try: Bob on the whole';
select r->'comment'->>'version' as version, r->'comment'->>'step' as step, (r->'comment'->>'parent')::bigint = (select id from public.model_comments where body = 'Try: step 4 goes under') as "under Bob's", r->'comment'->>'by' as by from (select public.add_reply('00000000-0000-4000-8000-0000000008c3', (select id from public.model_comments where body = 'Try: step 4 goes under'), 'Try: Cy says thanks') as r) x;
update public.model_comments set at = now() - interval '40 minutes' where body = 'Try: Cy says thanks';
select (r->'comment'->>'parent')::bigint = (select id from public.model_comments where body = 'Try: step 4 goes under') as "Ada's reply to Cy's reply: in Bob's thread", r->'comment'->>'step' as step, r->'comment'->>'by_owner' as by_owner from (select public.add_reply('00000000-0000-4000-8000-0000000008a1', (select id from public.model_comments where body = 'Try: Cy says thanks'), 'Try: Ada answers') as r) x;
update public.model_comments set at = now() - interval '30 minutes' where body = 'Try: Ada answers';
select public.add_comment('00000000-0000-4000-8000-0000000008c3', 'ReplyTry01', 1, null, 'Try: Cy says lovely')->'comment'->>'id' is not null as "Cy on the whole";
update public.model_comments set at = now() - interval '20 minutes' where body = 'Try: Cy says lovely';
-- The rules, as for a comment: under 13, nobody, no such comment, words, a hidden comment.
select public.add_reply('00000000-0000-4000-8000-0000000008d4', (select id from public.model_comments where body = 'Try: step 4 goes under'), 'Try: kid') as kid, public.add_reply(null, (select id from public.model_comments where body = 'Try: step 4 goes under'), 'Try: nobody') as nobody, public.add_reply('00000000-0000-4000-8000-0000000008c3', 999999999999, 'Try: none') as "no such", public.add_reply('00000000-0000-4000-8000-0000000008c3', (select id from public.model_comments where body = 'Try: step 4 goes under'), '   ') as words;
select public.change_comment('00000000-0000-4000-8000-0000000008a1', (select id from public.model_comments where body = 'Try: Bob on the whole'), 'hide')->'comment'->>'hidden' as "Ada hides Bob's whole", public.add_reply('00000000-0000-4000-8000-0000000008c3', (select id from public.model_comments where body = 'Try: Bob on the whole'), 'Try: to a hidden one') as "a reply to it";
-- Comments off: refused as a comment is; and on again.
select public.set_comments('00000000-0000-4000-8000-0000000008a1', 'ReplyTry01', false) as "off", public.add_reply('00000000-0000-4000-8000-0000000008c3', (select id from public.model_comments where body = 'Try: step 4 goes under'), 'Try: when off') as "a reply then";
select public.set_comments('00000000-0000-4000-8000-0000000008a1', 'ReplyTry01', true) as "on again";
-- Whatever writes: the trigger keeps a reply one level deep, on its comment's step, and under it.
create temp table said (what text, how text);
do $$ begin insert into public.model_comments (model, version, step, author, body, parent) values ('ReplyTry01', 1, 4, '00000000-0000-4000-8000-0000000008c3', 'Try: a reply to a reply', (select id from public.model_comments where body = 'Try: Cy says thanks')); insert into said values ('a reply to a reply', 'kept'); exception when others then insert into said values ('a reply to a reply', sqlerrm); end $$;
do $$ begin insert into public.model_comments (model, version, step, author, body, parent) values ('ReplyTry01', 1, 2, '00000000-0000-4000-8000-0000000008c3', 'Try: another step', (select id from public.model_comments where body = 'Try: step 4 goes under')); insert into said values ('on another step', 'kept'); exception when others then insert into said values ('on another step', sqlerrm); end $$;
do $$ begin update public.model_comments set parent = null where body = 'Try: Cy says thanks'; insert into said values ('moved out', 'kept'); exception when others then insert into said values ('moved out', sqlerrm); end $$;
select * from said;
-- A visitor reads the page: Bob's thread and Cy's comment, oldest first, each reply saying its comment; not the hidden one.
select c->>'body' as body, c->>'step' as step, (c->>'parent' is not null) as reply, c->>'by_owner' as by_owner from jsonb_array_elements(public.comments_on('ReplyTry01')->'comments') c;
select public.comments_on('ReplyTry01')->>'threads' as threads;
-- Who is told: Bob of both replies to his comment; Cy of Ada's, after his; Ada of Bob's and Cy's comments and Cy's reply (not her own, not the hidden one).
select r->>'kind' as kind, r->>'on' as "on", r->>'said' as said, r->>'yours' as yours, r->'by'->>'name' as by, r->>'parent' is not null as "has parent" from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000008b2')->'rows') r;
select r->>'kind' as kind, r->>'said' as said, r->>'yours' as yours, r->'by'->>'name' as by from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000008c3')->'rows') r;
select r->>'kind' as kind, r->>'said' as said, r->'by'->>'name' as by, r->>'parent' is not null as "has parent" from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000008a1')->'rows') r;
select public.notification_counts('00000000-0000-4000-8000-0000000008b2') as "Bob's count", public.notification_read('00000000-0000-4000-8000-0000000008b2', 'ReplyTry01') as "Bob reads the tower's (he commented)", public.notification_read('00000000-0000-4000-8000-0000000008d4', 'ReplyTry01') as "Kid, who did not";
-- The counts: the card (a visitor's comments, replies too) and Ada's designer numbers (not her own).
select public.directory_card(m)->>'comments' as "card: comments", (select s.comments from public.designer_said(array['ReplyTry01']) s) as "designer: comments" from public.shared_models m where m.id = 'ReplyTry01';
-- Ada hides Bob's step comment: its replies go with it, for the visitor, Bob's notifications, the card and the numbers; Ada and Bob still see the thread.
select public.change_comment('00000000-0000-4000-8000-0000000008a1', (select id from public.model_comments where body = 'Try: step 4 goes under'), 'hide')->'comment'->>'hidden' as "hidden";
select string_agg(c->>'body', ' | ' order by c->>'at') as "the visitor reads" from jsonb_array_elements(public.comments_on('ReplyTry01')->'comments') c;
select string_agg(c->>'body', ' | ' order by c->>'at') as "Ada reads" from jsonb_array_elements(public.comments_on('ReplyTry01', '00000000-0000-4000-8000-0000000008a1')->'comments') c;
select string_agg(c->>'body', ' | ' order by c->>'at') as "Bob reads" from jsonb_array_elements(public.comments_on('ReplyTry01', '00000000-0000-4000-8000-0000000008b2')->'comments') c;
select string_agg(c->>'body', ' | ' order by c->>'at') as "Cy reads" from jsonb_array_elements(public.comments_on('ReplyTry01', '00000000-0000-4000-8000-0000000008c3')->'comments') c;
select (select count(*) from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000008b2')->'rows') r where r->>'kind' = 'reply') as "Bob's replies told", (select count(*) from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000008a1')->'rows') r where r->>'parent' is not null) as "Ada's told of replies";
select public.directory_card(m)->>'comments' as "card: comments", (select s.comments from public.designer_said(array['ReplyTry01']) s) as "designer: comments" from public.shared_models m where m.id = 'ReplyTry01';
-- Ada's day's email, with her choice a day old: Cy's comment on the whole model, nothing of the hidden thread.
insert into public.mail_choices (account, comments, at) values ('00000000-0000-4000-8000-0000000008a1', true, now() - interval '1 day') on conflict (account) do update set comments = true, at = excluded.at;
select string_agg(c->>'body', ' | ') as "emailed" from jsonb_array_elements((public.claim_comment_digest('00000000-0000-4000-8000-0000000008a1')->0)->'comments') c;
-- Shown again: the thread is back. Then the site's owner removes Bob's comment: its replies go with it.
select public.change_comment('00000000-0000-4000-8000-0000000008a1', (select id from public.model_comments where body = 'Try: step 4 goes under'), 'show')->'comment'->>'hidden' as "shown again";
select count(*) as "the visitor's, shown again" from jsonb_array_elements(public.comments_on('ReplyTry01')->'comments') c;
select public.admin_remove_comment((select id from public.model_comments where body = 'Try: step 4 goes under')) as "removed by the site's owner", (select count(*) from jsonb_array_elements(public.admin_comments((select array_agg(id) from public.model_comments where model = 'ReplyTry01'))) a where a->>'parent' is not null) as "admin: replies, marked";
select string_agg(c->>'body', ' | ' order by c->>'at') as "everybody reads, then" from jsonb_array_elements(public.comments_on('ReplyTry01', '00000000-0000-4000-8000-0000000008a1')->'comments') c;
-- The server's alone.
select has_function_privilege('anon', 'public.add_reply(uuid, bigint, text)', 'execute') as anon_reply, has_function_privilege('authenticated', 'public.add_reply(uuid, bigint, text)', 'execute') as auth_reply, has_function_privilege('service_role', 'public.add_reply(uuid, bigint, text)', 'execute') as service_reply, has_function_privilege('anon', 'public.comment_parent_shown(bigint)', 'execute') as anon_rule, has_table_privilege('service_role', 'public.model_comments', 'select') as service_reads_comments;
-- Deleting Bob's account takes his comments and the replies to them.
delete from auth.users where id = '00000000-0000-4000-8000-0000000008b2';
select (select count(*) from public.model_comments where body in ('Try: Cy says thanks', 'Try: Ada answers')) as "replies to Bob's, left", (select count(*) from public.model_comments where body = 'Try: Cy says lovely') as "Cy's own, left"
