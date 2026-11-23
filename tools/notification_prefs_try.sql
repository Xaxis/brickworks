-- What supabase/notification_prefs.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/notification_prefs.sql --dry \
--       --try=tools/notification_prefs_try.sql --table=notification_prefs
--
-- Made-up accounts, made and gone with the transaction: Ada (a1) designs a
-- tower and a shed, with a device turned on ten minutes ago; Bob (b2)
-- comments on the tower and likes both. Inside one transaction now() never
-- moves, so what Bob does is at now() and the device older. Each statement
-- is on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000017a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'inbox-ada@resend.dev'), ('00000000-0000-4000-8000-0000000017b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'inbox-bob@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000017a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000017b2', true)->>'over_13' as bob;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000017a1', 'inbox-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000017b2', 'inbox-try-bob', 'Bob Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('InboxTry01', '00000000-0000-4000-8000-0000000017a1', 'Try tower', 'Ada Try', 12, 100, true, now() - interval '3 days', true, now() - interval '3 days', true), ('InboxTry02', '00000000-0000-4000-8000-0000000017a1', 'Try shed', 'Ada Try', 8, 100, true, now() - interval '2 days', true, now() - interval '2 days', true);
insert into public.share_versions (model, n, at, parts, bytes, steps) values ('InboxTry01', 1, now() - interval '3 days', 12, 100, 6), ('InboxTry02', 1, now() - interval '2 days', 8, 100, 4);
insert into auth.sessions (id, user_id) values ('00000000-0000-4000-8000-0000000017e1', '00000000-0000-4000-8000-0000000017a1');
insert into public.push_subscriptions (endpoint, account, p256dh, auth, origin, lang, made_at, session) values ('https://updates.push.services.mozilla.com/wpush/v2/inbox-try', '00000000-0000-4000-8000-0000000017a1', 'BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', 'AAAAAAAAAAAAAAAAAAAAAA', 'https://brickworks.diy', 'en', now() - interval '10 minutes', '00000000-0000-4000-8000-0000000017e1');
-- Before any choice: no row, the defaults; and the count as before (null).
select public.notification_prefs_of('00000000-0000-4000-8000-0000000017a1') as "Ada, never chose", public.notification_count_kept('00000000-0000-4000-8000-0000000017a1') as "her count kept (null: as before)";
-- Bob comments on the tower, likes the tower and the shed.
select public.add_comment('00000000-0000-4000-8000-0000000017b2', 'InboxTry01', 1, null, 'Try: Bob on the tower')->'comment'->>'id' is not null as "Bob comments";
insert into public.model_likes (model, account) values ('InboxTry01', '00000000-0000-4000-8000-0000000017b2'), ('InboxTry02', '00000000-0000-4000-8000-0000000017b2');
select r.kind, r.model, public.notification_kind(r.kind) as chosen_as, public.notification_group(r.kind, r.model, r.item) as grp from public.notification_rows('00000000-0000-4000-8000-0000000017a1', now() - interval '1 day', now()) r order by r.kind, r.model;
-- By default a device is pushed replies and mentions only: Bob's comment and likes are not pushed.
select public.push_collect('00000000-0000-4000-8000-0000000017a1', 0) as "pushed by default (null: nothing)";
-- The refusals: a kind that is not one, a channel that is not one, the email of comments (chosen with the day's email), no on.
select pg_temp.tries($q$select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'follows', 'here', true)$q$) as "a kind that is not one", pg_temp.tries($q$select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'likes', 'sms', true)$q$) as "a channel", pg_temp.tries($q$select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'comment', 'email', true)$q$) as "comments by email here", pg_temp.tries($q$select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'likes', 'here', null)$q$) as "no on";
-- Ada: comments and likes pushed, likes off here, likes by email.
select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'comment', 'push', true)->'push' as "push: comments on";
select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'likes', 'push', true)->'push' as "push: likes on";
select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'likes', 'here', false)->'here' as "here: likes off";
select public.notification_choose('00000000-0000-4000-8000-0000000017a1', 'likes', 'email', true)->'email' as "email: likes on";
select (select count(*) from public.notification_prefs where account = '00000000-0000-4000-8000-0000000017a1') as "her rows (one)", (select email_since is not null from public.notification_prefs where account = '00000000-0000-4000-8000-0000000017a1') as "email since set";
-- Counted here: the comment, not the likes.
select public.notification_count_kept('00000000-0000-4000-8000-0000000017a1') as "count: the comment alone (1)";
-- The shed muted: its like goes from the push too. Refusals: a model nobody has, a made-up id.
select public.notification_mute('00000000-0000-4000-8000-0000000017a1', 'InboxTry02', true) as "the shed muted";
select public.notification_mute('00000000-0000-4000-8000-0000000017a1', 'InboxTry02', true) as "again: one", public.notification_mute('00000000-0000-4000-8000-0000000017a1', 'NoSuchMdl0', true) as "nobody's model", public.notification_mute('00000000-0000-4000-8000-0000000017a1', 'bad id', true) as "not an id";
select d->>'endpoint' as device, r->>'kind' as kind, r->>'on' as model, r->>'key' as key from jsonb_array_elements(public.push_collect('00000000-0000-4000-8000-0000000017a1', 0)->'devices') d, jsonb_array_elements(d->'rows') r order by 2, 3;
select public.push_collect('00000000-0000-4000-8000-0000000017a1', 0) as "taken again: nothing (each once)";
-- The day's email: Ada chose likes (kept here), and no mail_choices: claimed, the tower's like in it, not the muted shed's.
-- (now() never moves here, so her choice is set an hour back, before Bob's likes.)
update public.notification_prefs set email_since = now() - interval '1 hour' where account = '00000000-0000-4000-8000-0000000017a1';
select x->>'owner' = '00000000-0000-4000-8000-0000000017a1' as "Ada's", x->>'test' as test, jsonb_array_length(x->'comments') as comments, jsonb_array_length(x->'feed') as feed, (select string_agg((n->>'kind') || ' ' || (n->>'on'), ', ') from jsonb_array_elements(x->'notices') n) as notices, x->>'notices_more' as more from jsonb_array_elements(public.claim_comment_digest('00000000-0000-4000-8000-0000000017a1')) x;
select jsonb_array_length(public.claim_comment_digest('00000000-0000-4000-8000-0000000017a1')) as "a second the same day (0)";
-- Done: the tower's group done up to now leaves the count; an older Done never moves it back; an undo brings it back; everything done. (A function's write is seen by the next statement, not its own.)
select public.notification_done('00000000-0000-4000-8000-0000000017a1', 'InboxTry01', now(), false) - 'at' as "the tower done";
select public.notification_count_kept('00000000-0000-4000-8000-0000000017a1') as "count (0)";
select (public.notification_done('00000000-0000-4000-8000-0000000017a1', 'InboxTry01', now() - interval '1 hour', false)->>'at')::timestamptz = now() as "an older Done never moves it back";
select public.notification_done('00000000-0000-4000-8000-0000000017a1', 'InboxTry01', null, true) - 'before' as "undone";
select public.notification_count_kept('00000000-0000-4000-8000-0000000017a1') as "count again (1)";
select public.notification_done('00000000-0000-4000-8000-0000000017a1', null, now(), false)->>'group' is null as "all done";
select public.notification_count_kept('00000000-0000-4000-8000-0000000017a1') as "count (0)", (public.notification_prefs_of('00000000-0000-4000-8000-0000000017a1')->>'done_all') is not null as "done_all kept";
select pg_temp.tries($q$select public.notification_done('00000000-0000-4000-8000-0000000017a1', 'drop table', now(), false)$q$) as "a group that is not one", pg_temp.tries($q$select public.notification_done('00000000-0000-4000-8000-0000000017a1', 'talk-12', now() + interval '1 day', false)$q$) as "a time to come", pg_temp.tries($q$select public.notification_done('00000000-0000-4000-8000-0000000017a1', 'challenge-3', null, false)$q$) as "no time";
-- The cron job's marker: Ada chose likes by push, so she is marked due once.
delete from public.push_marks where account = '00000000-0000-4000-8000-0000000017a1';
select public.push_mark_chosen() >= 1 as "marked";
select (select count(*) from public.push_marks where account = '00000000-0000-4000-8000-0000000017a1') as "her marks (1)";
select public.push_mark_chosen() >= 0 as "again";
select (select count(*) from public.push_marks where account = '00000000-0000-4000-8000-0000000017a1') as "still 1";
select jobname, schedule, command from cron.job where jobname = 'brickworks-push-chosen';
-- Nobody but the server: no key a page has may call or read.
select has_function_privilege('anon', 'public.notification_choose(uuid, text, text, boolean)', 'execute') as anon_choose, has_function_privilege('authenticated', 'public.notification_prefs_of(uuid)', 'execute') as auth_read, has_function_privilege('service_role', 'public.notification_done(uuid, text, timestamptz, boolean)', 'execute') as server_done, has_table_privilege('service_role', 'public.notification_prefs', 'select') as server_reads_table, has_table_privilege('anon', 'public.notification_prefs', 'select') as anon_reads_table;
-- Her account deleted: her row goes with it.
delete from auth.users where id = '00000000-0000-4000-8000-0000000017a1';
select (select count(*) from public.notification_prefs where account = '00000000-0000-4000-8000-0000000017a1') as "her rows after (0)", public.notification_prefs_of('00000000-0000-4000-8000-0000000017a1')->'kept' as "kept after";
