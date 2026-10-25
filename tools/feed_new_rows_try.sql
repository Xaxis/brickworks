-- What supabase/feed_new_rows.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/feed_new_rows.sql --dry --try=tools/feed_new_rows_try.sql
--
-- After the live files. Made-up accounts, made and gone with the
-- transaction: Ada designs a tower listed yesterday, its version 2 three
-- hours ago, and a mill an hour ago; Bob, new, has never opened his feed
-- and followed Ada two hours ago. Times are set by hand: inside one
-- transaction now() never moves. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000258a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'feednew-ada@resend.dev'), ('00000000-0000-4000-8000-0000000258b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'feednew-bob@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000258a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000258b2', true)->>'over_13' as bob;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000258a1', 'feednew-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000258b2', 'feednew-try-bob', 'Bob Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, created_at, has_image) values ('FeedNewT01', '00000000-0000-4000-8000-0000000258a1', 'Try tower', 'Ada Try', 3, 100, true, now() - interval '1 day', true, now() - interval '1 day', false), ('FeedNewT02', '00000000-0000-4000-8000-0000000258a1', 'Try mill', 'Ada Try', 3, 100, true, now() - interval '1 hour', true, now() - interval '1 hour', false);
insert into public.share_versions (model, n, at, parts, bytes) values ('FeedNewT01', 1, now() - interval '1 day', 3, 100), ('FeedNewT01', 2, now() - interval '3 hours', 4, 120), ('FeedNewT02', 1, now() - interval '1 hour', 3, 100);
select public.follow_person('00000000-0000-4000-8000-0000000258b2', 'feednew-try-ada', true)->>'you_follow' as "Bob follows Ada";
update public.follows set at = now() - interval '2 hours' where follower = '00000000-0000-4000-8000-0000000258b2';
-- When Bob's follows began: Ada two hours ago; no collection.
select public.feed_followed_at('00000000-0000-4000-8000-0000000258b2') as "Bob's follows", public.feed_followed_at('00000000-0000-4000-8000-0000000258a1') as "Ada's (none)", public.feed_followed_at(null) as "nobody";
-- Bob's feed, never opened: every row of Ada's last 90 days, and New as api/_follows.js isNew marks it, each by when he followed her. Before this file every row was New. Only the mill, after the follow, is; the tower and its version 2, before it, are not.
select r->>'kind' as kind, r->>'name' as name, r->>'version' as version, (r->>'at')::timestamptz < (public.feed_followed_at('00000000-0000-4000-8000-0000000258b2')->'people'->>(r->'by'->>'handle'))::timestamptz as "before the follow", (r->>'at')::timestamptz > (public.feed_followed_at('00000000-0000-4000-8000-0000000258b2')->'people'->>(r->'by'->>'handle'))::timestamptz as "New" from jsonb_array_elements(public.follow_page('00000000-0000-4000-8000-0000000258b2')->'rows') r;
-- And as the avatar counts it (list_follow_counts.sql): the same one.
select public.feed_new_count('00000000-0000-4000-8000-0000000258b2') as "Bob's count";
-- The server's alone: no key a page has may call it.
select has_function_privilege('anon', 'public.feed_followed_at(uuid)', 'execute') as anon, has_function_privilege('authenticated', 'public.feed_followed_at(uuid)', 'execute') as authenticated, has_function_privilege('service_role', 'public.feed_followed_at(uuid)', 'execute') as service_role
