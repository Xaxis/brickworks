-- What supabase/follows.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/follows.sql --again=supabase/challenges.sql \
--       --dry --try=tools/follows_try.sql --table=follows
--
-- After the live files (trust, tested, comments, builds, versions), which
-- the project has. Made-up accounts, made and gone with the transaction:
-- Ada designs (13 or over, a profile), Bob follows her (13 or over, a
-- profile, a model of his own), Cy is under 13, Di was never asked, Ed is
-- 13 or over at an ordinary address (so a test model is not in his feed),
-- and Flo is 13 or over with no profile. Times are set by hand: inside one
-- transaction now() never moves. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'follows-ada@resend.dev'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'follows-bob@resend.dev'), ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'follows-cy@resend.dev'), ('00000000-0000-4000-8000-0000000000f4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'follows-di@resend.dev'), ('00000000-0000-4000-8000-0000000000f5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'follows-ed@example.com'), ('00000000-0000-4000-8000-0000000000f6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'follows-flo@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000f1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000000f2', true)->>'over_13' as bob, public.answer_age('00000000-0000-4000-8000-0000000000f3', false)->>'over_13' as cy, public.answer_age('00000000-0000-4000-8000-0000000000f5', true)->>'over_13' as ed, public.answer_age('00000000-0000-4000-8000-0000000000f6', true)->>'over_13' as flo;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000f1', 'follows-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000000f2', 'follows-try-bob', 'Bob Try'), ('00000000-0000-4000-8000-0000000000f5', 'follows-try-ed', 'Ed Try');
-- Ada's models: one listed and credited, one by link only, one listed without her name. Bob's, listed. All test models but Ed's.
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at) values ('FollowTr01', '00000000-0000-4000-8000-0000000000f1', 'Try castle', 'Ada Try', 3, 100, true, now() - interval '50 minutes', true, now() - interval '55 minutes'), ('FollowTr02', '00000000-0000-4000-8000-0000000000f1', 'Try secret', 'Ada Try', 3, 100, false, null, true, now() - interval '50 minutes'), ('FollowTr03', '00000000-0000-4000-8000-0000000000f1', 'Try nameless', null, 3, 100, true, now() - interval '50 minutes', true, now() - interval '50 minutes'), ('FollowTr04', '00000000-0000-4000-8000-0000000000f2', 'Try barn', 'Bob Try', 3, 100, true, now() - interval '2 hours', true, now() - interval '2 hours'), ('FollowTr05', '00000000-0000-4000-8000-0000000000f5', 'Try mill', 'Ed Try', 3, 100, true, now() - interval '2 hours', false, now() - interval '2 hours');
insert into public.share_versions (model, n, at, parts, bytes) values ('FollowTr01', 1, now() - interval '55 minutes', 3, 100), ('FollowTr01', 2, now() - interval '40 minutes', 4, 120), ('FollowTr02', 1, now() - interval '50 minutes', 3, 100), ('FollowTr02', 2, now() - interval '40 minutes', 3, 100), ('FollowTr03', 1, now() - interval '50 minutes', 3, 100), ('FollowTr04', 1, now() - interval '2 hours', 3, 100), ('FollowTr05', 1, now() - interval '2 hours', 3, 100);
update public.share_versions set note = 'The tower is taller' where model = 'FollowTr01' and n = 2;
-- Following: who may, and who may be followed.
select public.follow_person('00000000-0000-4000-8000-0000000000f2', 'follows-try-ada', true) as "Bob follows Ada";
select public.follow_person('00000000-0000-4000-8000-0000000000f2', 'follows-try-ada', true)->>'followers' as "again: still one follower";
select public.follow_person('00000000-0000-4000-8000-0000000000f2', 'follows-try-bob', true)->>'refused' as "Bob follows Bob", public.follow_person('00000000-0000-4000-8000-0000000000f3', 'follows-try-ada', true)->>'refused' as "Cy (under 13)", public.follow_person('00000000-0000-4000-8000-0000000000f4', 'follows-try-ada', true)->>'refused' as "Di (never asked)", public.follow_person(null, 'follows-try-ada', true)->>'refused' as "nobody signed in", public.follow_person('00000000-0000-4000-8000-0000000000f2', 'follows-try-nobody', true)->>'refused' as "a handle nobody has", public.follow_person('00000000-0000-4000-8000-0000000000f2', 'follows-try-flo', true)->>'refused' as "Flo has no profile";
select pg_temp.tries($q$insert into public.follows (follower, followed) values ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000f1')$q$) as "Cy written directly", pg_temp.tries($q$insert into public.follows (follower, followed) values ('00000000-0000-4000-8000-0000000000f4', '00000000-0000-4000-8000-0000000000f1')$q$) as "Di written directly", pg_temp.tries($q$insert into public.follows (follower, followed) values ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000f6')$q$) as "following Flo, written directly";
select public.follow_person('00000000-0000-4000-8000-0000000000f5', 'follows-try-ada', true)->>'followers' as "Ed follows Ada too: followers", public.follow_person('00000000-0000-4000-8000-0000000000f6', 'follows-try-ada', true)->>'followers' as "Flo too, with no profile";
-- Counts only, as anybody sees them, and as Bob and Ada do.
select public.follow_state(null, 'follows-try-ada') as "Ada, to a visitor";
select public.follow_state('00000000-0000-4000-8000-0000000000f2', 'follows-try-ada')->>'you_follow' as "Bob sees he follows her", public.follow_state('00000000-0000-4000-8000-0000000000f1', 'follows-try-ada')->>'mine' as "Ada sees her own", public.follow_state('00000000-0000-4000-8000-0000000000f2', 'follows-try-bob')->>'following' as "Bob follows how many", public.follow_state(null, 'follows-try-flo') is null as "Flo has no state";
-- Lists: whom Bob follows only once he shows it; nobody's followers, ever.
select public.follow_list('follows-try-bob') as "whom Bob follows, not shown";
select public.follow_choice('00000000-0000-4000-8000-0000000000f2', true) as "Bob shows it";
select public.follow_list('follows-try-bob') as "whom Bob follows, shown";
select public.follow_list('follows-try-ada') as "whom Ada follows (nobody, not shown)";
-- Bob's feed, before anything of his: Ada's listed, credited castle and its version 2; not her model by link only, nor the one without her name.
select r->>'kind' as kind, r->>'model' as model, r->>'version' as version, r->>'note' as note, r->'by'->>'handle' as by from jsonb_array_elements(public.feed_of('00000000-0000-4000-8000-0000000000f2')->'rows') r;
-- Ed (not a test account) follows her too, and her test models are not in his feed.
select jsonb_array_length(public.feed_of('00000000-0000-4000-8000-0000000000f5')->'rows') as "Ed's feed of a test account's models";
-- On Bob's barn: Ada comments, posts a photo, and remixes it; Ed comments too, and Bob hides that; a removed comment and Bob's own are not news.
insert into public.model_comments (model, version, author, body, at) values ('FollowTr04', 1, '00000000-0000-4000-8000-0000000000f1', 'Try: the barn door swings', now() - interval '30 minutes'), ('FollowTr04', 1, '00000000-0000-4000-8000-0000000000f5', 'Try: hidden by Bob', now() - interval '29 minutes'), ('FollowTr04', 1, '00000000-0000-4000-8000-0000000000f1', 'Try: removed by Ada', now() - interval '28 minutes'), ('FollowTr04', 1, '00000000-0000-4000-8000-0000000000f2', 'Try: Bob on his own', now() - interval '27 minutes');
update public.model_comments set hidden_at = now() where body = 'Try: hidden by Bob';
update public.model_comments set removed_at = now(), removed_by = 'author' where body = 'Try: removed by Ada';
insert into public.build_photos (id, model, account, words, width, height, bytes, was, at) values ('FollowPh01', 'FollowTr04', '00000000-0000-4000-8000-0000000000f1', 'Built the barn', 1600, 1200, 200000, 'jpeg', now() - interval '20 minutes'), ('FollowPh02', 'FollowTr05', '00000000-0000-4000-8000-0000000000f1', 'Built Ed''s mill', 1600, 1200, 200000, 'jpeg', now() - interval '15 minutes'), ('FollowPh03', 'FollowTr04', '00000000-0000-4000-8000-0000000000f5', 'Hidden by Bob', 1600, 1200, 200000, 'jpeg', now() - interval '14 minutes');
update public.build_photos set hidden_at = now() where id = 'FollowPh03';
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, remixed_from) values ('FollowTr06', '00000000-0000-4000-8000-0000000000f1', 'Try barn, bigger', 'Ada Try', 5, 140, true, now() - interval '10 minutes', true, 'FollowTr04');
insert into public.share_versions (model, n, at, parts, bytes) values ('FollowTr06', 1, now() - interval '10 minutes', 5, 140);
-- Bob's whole feed, newest first: the remix (once, not also as Ada's new model), Ada's photo of Ed's mill (somebody followed), her photo of his barn (his model), her comment, her castle's version 2 and the castle; and its link-worthy ids.
select r->>'kind' as kind, r->>'model' as model, coalesce(r->>'photo', r->>'comment', r->>'version', r->>'of') as which, r->>'yours' as yours, coalesce(r->>'said', r->>'words', r->>'note') as said, r->'by'->>'name' as by from jsonb_array_elements(public.feed_of('00000000-0000-4000-8000-0000000000f2')->'rows') r;
select public.feed_of('00000000-0000-4000-8000-0000000000f2', size => 2)->>'more' as "two at a time: more", jsonb_array_length(public.feed_of('00000000-0000-4000-8000-0000000000f2', size => 2)->'rows') as rows, (select string_agg(r->>'kind', ', ') from jsonb_array_elements(public.feed_of('00000000-0000-4000-8000-0000000000f2', before => now() - interval '25 minutes')->'rows') r) as "before 25 minutes ago";
-- The Account count: everything, never opened; opened now, nothing; opened 25 minutes ago, what came since.
select public.feed_count('00000000-0000-4000-8000-0000000000f2') as "never opened";
select public.feed_of('00000000-0000-4000-8000-0000000000f2', mark => true)->>'seen_at' as "opened: seen before", public.feed_count('00000000-0000-4000-8000-0000000000f2') as "count after opening";
update public.feed_marks set seen_at = now() - interval '25 minutes' where account = '00000000-0000-4000-8000-0000000000f2';
select public.feed_count('00000000-0000-4000-8000-0000000000f2') as "opened 25 minutes ago", public.feed_count(null) as "nobody";
-- Limits: sixty follows an hour, counted in may_act.
insert into public.act_log (who, action) select '00000000-0000-4000-8000-0000000000f6', 'follow' from generate_series(1, 60);
select public.follow_person('00000000-0000-4000-8000-0000000000f6', 'follows-try-bob', true)->>'refused' as "Flo's 61st follow this hour", public.follow_person('00000000-0000-4000-8000-0000000000f6', 'follows-try-ada', false)->>'followers' as "letting Ada go is not counted: her followers";
-- The daily email: four new choices, all off; Bob chooses photos and remixes only (not comments).
select public.mail_kinds('00000000-0000-4000-8000-0000000000f2') as "before choosing";
select pg_temp.tries($q$select public.mail_kinds('00000000-0000-4000-8000-0000000000f2', '{"photos": "yes"}')$q$) as "a choice that is not true or false", pg_temp.tries($q$select public.mail_kinds('00000000-0000-4000-8000-0000000000f2', '{"likes": true}')$q$) as "a kind that is not one";
select public.mail_kinds('00000000-0000-4000-8000-0000000000f2', '{"photos": true, "remixes": true}') as "photos and remixes", public.mail_choice('00000000-0000-4000-8000-0000000000f2') as "comments.sql's own answer, unchanged";
update public.mail_choices set at = now() - interval '45 minutes' where account = '00000000-0000-4000-8000-0000000000f2';
select d->>'test' as test, jsonb_array_length(d->'comments') as comments, d->>'more' as more, (select string_agg((r->>'kind') || ' ' || coalesce(r->>'photo', r->>'model'), ', ' order by r->>'at') from jsonb_array_elements(d->'feed') r) as feed, d->>'feed_more' as feed_more from jsonb_array_elements(public.claim_comment_digest('00000000-0000-4000-8000-0000000000f2')) d;
select owner = '00000000-0000-4000-8000-0000000000f2' as bob, state, comments, feed from public.comment_digests where owner = '00000000-0000-4000-8000-0000000000f2';
select public.finish_comment_digest(max(id), 'dry', 'Try subject', 'Try body', '<p>Try</p>') as "finished dry" from public.comment_digests where owner = '00000000-0000-4000-8000-0000000000f2';
select jsonb_array_length(public.claim_comment_digest('00000000-0000-4000-8000-0000000000f2')) as "again that day";
-- The next day: what the last email told is not told again. Moved back a day here (inside one transaction now() never moves): the email, the rows it told, and when Bob chose; then Bob turns comments on, and Ed posts a new photo of the barn.
update public.comment_digests set at = now() - interval '25 hours' where owner = '00000000-0000-4000-8000-0000000000f2';
update public.build_photos set at = at - interval '26 hours' where id in ('FollowPh01', 'FollowPh02');
update public.shared_models set listed_at = listed_at - interval '26 hours' where id = 'FollowTr06';
select public.mail_kinds('00000000-0000-4000-8000-0000000000f2', '{"comments": true}')->>'comments' as "comments on";
update public.mail_choices set at = now() - interval '30 hours' where account = '00000000-0000-4000-8000-0000000000f2';
insert into public.build_photos (id, model, account, words, width, height, bytes, was, at) values ('FollowPh04', 'FollowTr04', '00000000-0000-4000-8000-0000000000f5', 'Ed built it too', 1600, 1200, 200000, 'jpeg', now() - interval '5 minutes');
select (select string_agg(c->>'body', ', ') from jsonb_array_elements(d->'comments') c) as comments, (select string_agg((r->>'kind') || ' ' || coalesce(r->>'photo', r->>'model'), ', ') from jsonb_array_elements(d->'feed') r) as "feed: only what is new since" from jsonb_array_elements(public.claim_comment_digest('00000000-0000-4000-8000-0000000000f2')) d;
select count(*) filter (where digest is not null) as "comments marked told" from public.model_comments where model = 'FollowTr04';
-- An account taken out of the gallery: no state, nothing of it in the feed, and its follow not counted.
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000f1', 'Try');
select public.follow_state(null, 'follows-try-ada') is null as "Ada taken out: no state", (select count(*) from jsonb_array_elements(public.feed_of('00000000-0000-4000-8000-0000000000f2')->'rows') r where r->'by'->>'handle' = 'follows-try-ada') as "her rows in Bob's feed", public.follow_state(null, 'follows-try-bob')->>'following' as "whom Bob follows, counted";
delete from public.barred_accounts where account = '00000000-0000-4000-8000-0000000000f1';
-- Who may be followed: a profile shown in public; Cy (under 13) and Flo (no profile) not.
select public.follow_may_be_followed('00000000-0000-4000-8000-0000000000f1') as "Ada", public.follow_may_be_followed('00000000-0000-4000-8000-0000000000f3') as "Cy", public.follow_may_be_followed('00000000-0000-4000-8000-0000000000f6') as "Flo";
-- Nobody but the server: no grant on the two tables to any key, the service role's included; the functions the service role's alone.
select count(*) as "grants on follows and feed_marks to anon, authenticated or service_role" from information_schema.role_table_grants where table_schema = 'public' and table_name in ('follows', 'feed_marks') and grantee in ('anon', 'authenticated', 'service_role');
select relname, relrowsecurity from pg_class where relname in ('follows', 'feed_marks') and relkind = 'r' order by relname;
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('follow_may_be_followed', 'follow_trouble', 'follow_state', 'follow_person', 'follow_list', 'follow_choice', 'feed_who', 'feed_rows', 'feed_of', 'feed_count', 'mail_kinds', 'claim_comment_digest') order by p.proname;
-- How long reading a feed takes, on the real tables: the account with the most published models, its feed and its count.
select (select count(*) from public.shared_models where owner = b.owner and published) as models, (select count(*) from public.model_comments k join public.shared_models m on m.id = k.model where m.owner = b.owner) as comments_on_them from (select owner from public.shared_models where published group by owner order by count(*) desc limit 1) b;
create function pg_temp.timed(account uuid) returns text language plpgsql as $$ declare t0 timestamptz; t1 timestamptz; t2 timestamptz; begin t0 := clock_timestamp(); perform public.feed_of(account); t1 := clock_timestamp(); perform public.feed_count(account); t2 := clock_timestamp(); return format('feed_of %s ms, feed_count %s ms', round(extract(epoch from t1 - t0) * 1000, 1), round(extract(epoch from t2 - t1) * 1000, 1)); end $$;
select pg_temp.timed(owner) as "the busiest owner" from (select owner from public.shared_models where published group by owner order by count(*) desc limit 1) b;
select pg_temp.timed('00000000-0000-4000-8000-0000000000f2') as "Bob"
