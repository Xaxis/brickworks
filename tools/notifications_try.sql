-- What supabase/notifications.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/notifications.sql --dry \
--       --try=tools/notifications_try.sql --table=notification_marks
--
-- After the live files (trust, people, comments, builds, versions, follows,
-- challenges), which the project has. Made-up accounts, made and gone with
-- the transaction: Ada designs (a tower and a mill), Bob comments on her
-- tower, posts a photo of his build of it and remixes her mill, and lists a
-- cart of his own; ten more like her tower today and three yesterday; Ada
-- follows Bob; Ed opened his old feed half an hour ago and never the
-- notifications. Times are set by hand: inside one transaction now() never
-- moves. Each statement is on one line: the dry run splits at a semicolon
-- that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000007a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'notify-ada@resend.dev'), ('00000000-0000-4000-8000-0000000007b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'notify-bob@resend.dev'), ('00000000-0000-4000-8000-0000000007e5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'notify-ed@resend.dev');
insert into auth.users (id, instance_id, aud, role, email) select ('00000000-0000-4000-8000-0000000071' || lpad(n::text, 2, '0'))::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'notify-liker-' || n || '@resend.dev' from generate_series(1, 13) n;
select public.answer_age('00000000-0000-4000-8000-0000000007a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000007b2', true)->>'over_13' as bob, public.answer_age('00000000-0000-4000-8000-0000000007e5', true)->>'over_13' as ed;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000007a1', 'notify-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000007b2', 'notify-try-bob', 'Bob Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('NotifyTr01', '00000000-0000-4000-8000-0000000007a1', 'Try tower', 'Ada Try', 3, 100, true, now() - interval '3 days', true, now() - interval '3 days', true), ('NotifyTr02', '00000000-0000-4000-8000-0000000007a1', 'Try mill', 'Ada Try', 3, 100, true, now() - interval '3 days', true, now() - interval '3 days', false), ('NotifyTr03', '00000000-0000-4000-8000-0000000007b2', 'Try cart', 'Bob Try', 3, 100, true, now() - interval '50 minutes', true, now() - interval '50 minutes', false);
insert into public.share_versions (model, n, at, parts, bytes) values ('NotifyTr01', 1, now() - interval '3 days', 3, 100), ('NotifyTr02', 1, now() - interval '3 days', 3, 100), ('NotifyTr03', 1, now() - interval '50 minutes', 3, 100);
select public.follow_person('00000000-0000-4000-8000-0000000007a1', 'notify-try-bob', true)->>'you_follow' as "Ada follows Bob";
-- On Ada's tower: Bob comments, and a second comment of his she hides; her own is not news. His photo of his build of it. His remix of her mill.
insert into public.model_comments (model, version, author, body, at) values ('NotifyTr01', 1, '00000000-0000-4000-8000-0000000007b2', 'Try: the tower is tall', now() - interval '40 minutes'), ('NotifyTr01', 1, '00000000-0000-4000-8000-0000000007b2', 'Try: hidden by Ada', now() - interval '39 minutes'), ('NotifyTr01', 1, '00000000-0000-4000-8000-0000000007a1', 'Try: Ada on her own', now() - interval '38 minutes');
update public.model_comments set hidden_at = now() where body = 'Try: hidden by Ada';
insert into public.build_photos (id, model, account, words, width, height, bytes, was, at) values ('NotifyPh01', 'NotifyTr01', '00000000-0000-4000-8000-0000000007b2', 'Built the tower', 1600, 1200, 200000, 'jpeg', now() - interval '30 minutes');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, remixed_from) values ('NotifyTr04', '00000000-0000-4000-8000-0000000007b2', 'Try mill, taller', 'Bob Try', 5, 140, true, now() - interval '20 minutes', true, 'NotifyTr02');
insert into public.share_versions (model, n, at, parts, bytes) values ('NotifyTr04', 1, now() - interval '20 minutes', 5, 140);
-- Likes on the tower: ten today, three yesterday, and Ada's own (not news).
insert into public.model_likes (model, account, at) select 'NotifyTr01', ('00000000-0000-4000-8000-0000000071' || lpad(n::text, 2, '0'))::uuid, case when n <= 10 then now() - (n || ' seconds')::interval else now() - interval '1 day' - (n || ' minutes')::interval end from generate_series(1, 13) n;
insert into public.model_likes (model, account, at) values ('NotifyTr01', '00000000-0000-4000-8000-0000000007a1', now() - interval '5 minutes');
-- A test challenge that ended and is settled: Ada's tower won among hand-built entries; her mill and Bob's cart were in the other group, which the cart won.
insert into public.challenges (title, brief, starts_on, ends_on, test, ended_at, settled_at) values ('Try castles', 'Build a castle', current_date - 20, current_date - 2, true, now() - interval '2 days', now() - interval '10 minutes');
insert into public.challenge_entries (challenge, model, owner, way, at) select c.id, x.model, x.owner, x.way, now() - interval '5 days' from public.challenges c, (values ('NotifyTr01', '00000000-0000-4000-8000-0000000007a1'::uuid, 'hand'), ('NotifyTr02', '00000000-0000-4000-8000-0000000007a1'::uuid, 'assistant'), ('NotifyTr03', '00000000-0000-4000-8000-0000000007b2'::uuid, 'assistant')) x(model, owner, way) where c.title = 'Try castles';
insert into public.challenge_winners (challenge, way, model, owner, votes) select c.id, x.way, x.model, x.owner, x.votes from public.challenges c, (values ('hand', 'NotifyTr01', '00000000-0000-4000-8000-0000000007a1'::uuid, 5), ('assistant', 'NotifyTr03', '00000000-0000-4000-8000-0000000007b2'::uuid, 3)) x(way, model, owner, votes) where c.title = 'Try castles';
-- Ada's notifications, newest first: the challenge's end twice (won, and not), the remix of her mill, the photo, the comment, then the likes a row a day (ten, then three). Not her own like or comment, not the hidden one.
select r->>'kind' as kind, r->>'on' as "on", coalesce(r->>'said', r->>'words', r->>'likes', r->>'title') as what, r->>'won' as won, r->>'votes' as votes, r->>'day' as day, r->'by'->>'name' as by from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000007a1')->'rows') r;
select (select count(*) from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000007a1')->'rows') r where r->>'kind' = 'likes' and r->>'on' = 'NotifyTr01' and r->>'day' = to_char(now() at time zone 'UTC', 'YYYY-MM-DD')) as "today's ten likes: rows", (select r->>'likes' from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000007a1')->'rows') r where r->>'kind' = 'likes' order by r->>'at' desc limit 1) as "...saying", (select bool_and(not (r ? 'by') or r->>'kind' <> 'likes') from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000007a1')->'rows') r) as "no like names who";
select public.notification_list('00000000-0000-4000-8000-0000000007a1')->'models' as "the models' pictures";
-- Ada's feed is what Bob made: his cart listed, and entered in the challenge; not his photo of her tower (a notification).
select r->>'kind' as kind, r->>'model' as model from jsonb_array_elements(public.follow_page('00000000-0000-4000-8000-0000000007a1')->'rows') r;
-- What is new for her, never opened: every notification and both feed rows; the old feed_count (the app of before) the whole old feed.
select public.notification_counts('00000000-0000-4000-8000-0000000007a1') as "new, never opened", public.feed_count('00000000-0000-4000-8000-0000000007a1') as "feed_count of before", public.notification_counts(null) as "nobody";
-- Opened: the count clears, the feed's does not; seen_at says she never had before.
-- (Each in a statement of its own: a statement sees the database as it was when it began.)
select public.notification_list('00000000-0000-4000-8000-0000000007a1', mark => true)->>'seen_at' as "opened: seen before";
select public.notification_counts('00000000-0000-4000-8000-0000000007a1') as "after opening";
-- Opened 25 minutes ago instead: what came since (the remix, the challenge's end twice, today's likes; not the photo, 30 minutes ago).
update public.notification_marks set seen_at = now() - interval '25 minutes' where account = '00000000-0000-4000-8000-0000000007a1';
select public.notification_counts('00000000-0000-4000-8000-0000000007a1')->>'notifications' as "opened 25 minutes ago";
-- Read: the tower, opened; not Bob's to read; then all.
select public.notification_read('00000000-0000-4000-8000-0000000007a1', 'NotifyTr01') as "Ada opens the tower's", public.notification_read('00000000-0000-4000-8000-0000000007b2', 'NotifyTr01') as "Bob, of her tower", public.notification_read('00000000-0000-4000-8000-0000000007a1', 'NoSuchMod1') as "a model nobody has", public.notification_read(null, 'NotifyTr01') as "nobody";
select (public.notification_list('00000000-0000-4000-8000-0000000007a1')->'reads') ? 'NotifyTr01' as "the tower read", public.notification_list('00000000-0000-4000-8000-0000000007a1')->>'read_at' as "all read at (never)";
select public.notification_read('00000000-0000-4000-8000-0000000007a1') as "Mark all read";
select public.notification_list('00000000-0000-4000-8000-0000000007a1')->>'read_at' is not null as "read_at set", public.notification_list('00000000-0000-4000-8000-0000000007a1')->'reads' as "reads", public.notification_counts('00000000-0000-4000-8000-0000000007a1')->>'notifications' as "count";
-- Ed opened the old feed half an hour ago: those are his marks until he has his own. Opening the new feed writes them down first, so it does not mark his notifications.
insert into public.feed_marks (account, seen_at) values ('00000000-0000-4000-8000-0000000007e5', now() - interval '30 minutes');
select s.seen_at = now() - interval '30 minutes' as "Ed seen, from his feed", s.read_at = now() - interval '30 minutes' as "Ed read, from his feed" from public.notification_marks_of('00000000-0000-4000-8000-0000000007e5') s;
select public.follow_page('00000000-0000-4000-8000-0000000007e5', mark => true)->>'seen_at' is not null as "Ed opens the new feed";
select s.seen_at = now() - interval '30 minutes' as "Ed's notifications still seen then", (select k.seen_at = now() from public.feed_marks k where k.account = '00000000-0000-4000-8000-0000000007e5') as "his feed seen now" from public.notification_marks_of('00000000-0000-4000-8000-0000000007e5') s;
-- The old functions, unchanged: the old feed still has Bob's comment and photo on her tower.
select string_agg(r->>'kind', ', ' order by r->>'at' desc) as "feed_of, as before" from jsonb_array_elements(public.feed_of('00000000-0000-4000-8000-0000000007a1')->'rows') r;
-- The server's alone: no key a page has may call these, and not even the service role may read the tables.
select has_function_privilege('anon', 'public.notification_list(uuid, boolean)', 'execute') as anon_list, has_function_privilege('authenticated', 'public.notification_read(uuid, text)', 'execute') as auth_read, has_function_privilege('service_role', 'public.notification_counts(uuid)', 'execute') as service_counts, has_table_privilege('service_role', 'public.notification_marks', 'select') as service_reads_marks, has_table_privilege('anon', 'public.notification_reads', 'select') as anon_reads_reads;
-- Deleting Ada's account takes her marks and reads with it.
select public.notification_read('00000000-0000-4000-8000-0000000007a1', 'NotifyTr02') as "reads the mill";
delete from auth.users where id = '00000000-0000-4000-8000-0000000007a1';
select (select count(*) from public.notification_marks where account = '00000000-0000-4000-8000-0000000007a1') as "her marks", (select count(*) from public.notification_reads where account = '00000000-0000-4000-8000-0000000007a1') as "her reads"
