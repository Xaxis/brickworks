-- What supabase/feed_self.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/feed_self.sql --dry --try=tools/feed_self_try.sql
--
-- After the live files. Made-up accounts, made and gone with the
-- transaction: Nia, new, follows nobody. She listed a castle with her name
-- on it two hours ago and its version 2 an hour ago, a boat listed without
-- her name, a tower shared by link only, a shed never published, and a
-- barge Brickworks took out. Robin listed a mill; Nia posted a photo of her
-- build of it. Times are set by hand: inside one transaction now() never
-- moves. Each statement is on one line: the dry run splits at a semicolon
-- that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-00000f5e1f01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'feedself-nia@resend.dev'), ('00000000-0000-4000-8000-00000f5e1f02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'feedself-robin@resend.dev');
select public.answer_age('00000000-0000-4000-8000-00000f5e1f01', true)->>'over_13' as nia, public.answer_age('00000000-0000-4000-8000-00000f5e1f02', true)->>'over_13' as robin;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-00000f5e1f01', 'feedself-try-nia', 'Nia Try'), ('00000000-0000-4000-8000-00000f5e1f02', 'feedself-try-robin', 'Robin Try');
insert into public.shared_models (id, owner, name, author, parts, bytes, published, listed, listed_at, barred, test, created_at, has_image) values ('FeedSelf01', '00000000-0000-4000-8000-00000f5e1f01', 'Try castle', 'Nia Try', 3, 100, true, true, now() - interval '2 hours', false, true, now() - interval '2 hours', false), ('FeedSelf02', '00000000-0000-4000-8000-00000f5e1f01', 'Try boat', null, 3, 100, true, true, now() - interval '30 minutes', false, true, now() - interval '30 minutes', false), ('FeedSelf03', '00000000-0000-4000-8000-00000f5e1f01', 'Try tower (link only)', 'Nia Try', 3, 100, true, false, null, false, true, now() - interval '20 minutes', false), ('FeedSelf04', '00000000-0000-4000-8000-00000f5e1f01', 'Try shed (never published)', 'Nia Try', 3, 100, false, false, null, false, true, now() - interval '10 minutes', false), ('FeedSelf05', '00000000-0000-4000-8000-00000f5e1f01', 'Try barge (taken out)', 'Nia Try', 3, 100, true, true, now() - interval '5 minutes', true, true, now() - interval '5 minutes', false), ('FeedSelf06', '00000000-0000-4000-8000-00000f5e1f02', 'Try mill (Robin)', 'Robin Try', 3, 100, true, true, now() - interval '3 hours', false, true, now() - interval '3 hours', false);
insert into public.share_versions (model, n, at, parts, bytes) values ('FeedSelf01', 1, now() - interval '2 hours', 3, 100), ('FeedSelf01', 2, now() - interval '1 hour', 4, 120), ('FeedSelf02', 1, now() - interval '30 minutes', 3, 100), ('FeedSelf06', 1, now() - interval '3 hours', 3, 100);
insert into public.build_photos (id, model, account, words, width, height, bytes, was, at) values ('FeedSelfP1', 'FeedSelf06', '00000000-0000-4000-8000-00000f5e1f01', 'Built it today', 4, 3, 100, 'webp', now() - interval '45 minutes');
-- Nia's own page: the castle, its version 2, her photo of Robin's mill and the boat (credited false), newest first. Not the tower (link only), the shed (never published), the barge (taken out), nor Robin's mill itself.
select r->>'kind' as kind, r->>'name' as name, r->>'version' as version, r->>'mine' as mine, r->>'credited' as credited, r->'by'->>'handle' as by from jsonb_array_elements(public.own_page('00000000-0000-4000-8000-00000f5e1f01')->'rows') r;
-- A page of one: the boat, with more after it; the next page, before the boat, starts at the photo.
select public.own_page('00000000-0000-4000-8000-00000f5e1f01', null, 1)->'rows'->0->>'name' as first, public.own_page('00000000-0000-4000-8000-00000f5e1f01', null, 1)->>'more' as more, public.own_page('00000000-0000-4000-8000-00000f5e1f01', (public.own_page('00000000-0000-4000-8000-00000f5e1f01', null, 1)->'rows'->0->>'at')::timestamptz, 1)->'rows'->0->>'kind' as next;
-- Robin's own page: his mill only, none of Nia's (her photo of his mill is hers).
select r->>'kind' as kind, r->>'name' as name, r->'by'->>'handle' as by from jsonb_array_elements(public.own_page('00000000-0000-4000-8000-00000f5e1f02')->'rows') r;
-- Nia's feed of others (follow_page) is empty, following nobody; her count stays 0: own rows are never counted.
select jsonb_array_length(public.follow_page('00000000-0000-4000-8000-00000f5e1f01')->'rows') as "Nia's follow rows", public.feed_new_count('00000000-0000-4000-8000-00000f5e1f01') as "Nia's count";
-- Nobody: nothing.
select public.own_page(null) as nobody;
-- The server's alone: no key a page has may call either.
select has_function_privilege('anon', 'public.own_page(uuid, timestamptz, integer)', 'execute') as anon, has_function_privilege('authenticated', 'public.own_page(uuid, timestamptz, integer)', 'execute') as authenticated, has_function_privilege('service_role', 'public.own_page(uuid, timestamptz, integer)', 'execute') as service_role, has_function_privilege('anon', 'public.own_rows(uuid, timestamptz, timestamptz)', 'execute') as rows_anon, has_function_privilege('authenticated', 'public.own_rows(uuid, timestamptz, timestamptz)', 'execute') as rows_authenticated
