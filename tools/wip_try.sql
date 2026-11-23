-- What supabase/wip.sql does, tried inside the rolled-back transaction of a
-- dry run: nothing here is kept. Made-up accounts, made and gone with the
-- transaction, at Resend's test addresses (the checks' pool): Ada designs,
-- Bo and Cy follow her, and Cy blocks her halfway.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/wip.sql --dry --try=tools/wip_try.sql --table=share_versions
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line. Inside one transaction now() never moves, so the versions
-- are written at times of their own, hours apart, as publishing writes
-- them. Every query that ranks or chooses is asked with a WIP model of
-- Ada's beside a finished one, and asked again once the WIP one is
-- finished.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated, service_role;
-- The columns: new, empty or false on every row there is.
select c.table_name, c.column_name, c.data_type, c.is_nullable, c.column_default from information_schema.columns c where c.table_schema = 'public' and ((c.table_name = 'shared_models' and c.column_name = 'wip_at') or (c.table_name = 'share_versions' and c.column_name in ('wip', 'finished_at', 'talk_post', 'finished_post', 'has_thumb'))) order by c.table_name, c.column_name;
select (select count(*) from public.shared_models where wip_at is not null) as wip_models, (select count(*) from public.share_versions where wip or finished_at is not null or talk_post is not null or finished_post is not null or has_thumb) as marked_versions;
-- A page's keys reach none of it: the columns are on tables no client key reads, the functions the server's alone.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('gallery_shows', 'directory_card', 'gallery_models', 'wip_said', 'wip_rows', 'follow_rows', 'wip_talk', 'wip_finish') order by p.proname;
set local role anon;
select pg_temp.tries($q$select wip_at from public.shared_models limit 1$q$) as anon_reads_wip, pg_temp.tries($q$select talk_post from public.share_versions limit 1$q$) as anon_reads_posts, pg_temp.tries($q$select public.wip_finish('00000000-0000-4000-8000-0000000fb001', 'WipTry0001')$q$) as anon_finishes;
reset role;
set local role authenticated;
select pg_temp.tries($q$select public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 1, 'Forged', 'As Ada')$q$) as signed_in_posts_as_ada, pg_temp.tries($q$update public.shared_models set wip_at = null$q$) as signed_in_finishes_all;
reset role;
-- The made-up three, 13 or over, each with a profile shown in public.
insert into auth.users (id, instance_id, aud, role, email, created_at, email_confirmed_at) values ('00000000-0000-4000-8000-0000000fb001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wip-try-ada@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fb002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wip-try-bo@resend.dev', now() - interval '30 days', now()), ('00000000-0000-4000-8000-0000000fb003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'wip-try-cy@resend.dev', now() - interval '30 days', now());
select public.answer_age('00000000-0000-4000-8000-0000000fb001', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000fb002', true)->>'over_13' as bo, public.answer_age('00000000-0000-4000-8000-0000000fb003', true)->>'over_13' as cy;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000fb001', 'wip-try-ada', 'Ada Try'), ('00000000-0000-4000-8000-0000000fb002', 'wip-try-bo', 'Bo Try'), ('00000000-0000-4000-8000-0000000fb003', 'wip-try-cy', 'Cy Try');
-- Ada's two models, listed three hours ago and credited: Zqwip crane is work in progress (versions 1 and 2), Zqwip barn finished. Each built ten times this week.
insert into public.shared_models (id, owner, name, author, parts, bytes, published, listed, listed_at, test, created_at, updated_at, has_image, wip_at) values ('WipTry0001', '00000000-0000-4000-8000-0000000fb001', 'Zqwip crane', 'Ada Try', 120, 100, true, true, now() - interval '3 hours', true, now() - interval '3 hours', now() - interval '2 hours', true, now() - interval '3 hours'), ('WipTry0002', '00000000-0000-4000-8000-0000000fb001', 'Zqwip barn', 'Ada Try', 80, 100, true, true, now() - interval '3 hours', true, now() - interval '3 hours', now() - interval '3 hours', true, null);
insert into public.share_versions (model, n, at, note, parts, bytes, has_image, wip, has_thumb) values ('WipTry0001', 1, now() - interval '3 hours', 'The base and the tower', 60, 100, true, true, true), ('WipTry0001', 2, now() - interval '2 hours', 'The jib is on', 120, 100, true, true, true), ('WipTry0002', 1, now() - interval '3 hours', null, 80, 100, true, false, false);
select count(*) filter (where public.count_build('WipTry0001', md5('crane' || g))) as crane_builds, count(*) filter (where public.count_build('WipTry0002', md5('barn' || g))) as barn_builds from generate_series(1, 10) g;
-- Bo and Cy follow Ada.
select public.follow_person('00000000-0000-4000-8000-0000000fb002', 'wip-try-ada', true) as bo_follows, public.follow_person('00000000-0000-4000-8000-0000000fb003', 'wip-try-ada', true) as cy_follows;
select count(*) as follows_of_ada from public.follows f join public.people p on p.account = f.followed where p.handle = 'wip-try-ada';
-- The cards: the crane's says wip, the barn's not; every key the card had before is there (sql_compare checks the rest).
select m.id, public.directory_card(m)->>'wip' as wip, public.directory_card(m) ? 'modelled_by' as has_modelled_by, public.directory_card(m) ? 'motions' as has_motions from public.shared_models m where m.id in ('WipTry0001', 'WipTry0002') order by m.id;
-- The gallery's list, each sort: the crane only in Newest; Top, views, likes, remixes, builds and the shelves' small builds (Top of at most 400 parts) never.
select s.sort, s.most, (select string_agg(x->>'id' || case when (x->>'wip')::boolean then ' (wip)' else '' end, ', ' order by x->>'id') from public.gallery_models(jsonb_build_object('sort', s.sort, 'tests', true, 'words', 'zqwip:*', 'size', 49) || case when s.most is null then '{}'::jsonb else jsonb_build_object('most', s.most) end) x) as listed from (values ('newest', null::integer), ('top', null), ('top', 400), ('views', null), ('likes', null), ('remixes', null), ('builds', null)) s(sort, most);
-- Top over the week and the month, as the gallery's tabs ask it.
select d.days, (select string_agg(x->>'id', ', ' order by x->>'id') from public.gallery_models(jsonb_build_object('sort', 'top', 'days', d.days, 'tests', true, 'words', 'zqwip:*')) x) as listed from (values (7), (30)) d(days);
-- What chooses: shown in the gallery's sense, the week's candidates, the pick, the featured model.
select m.id, public.gallery_shows(m, true) as shown, exists (select 1 from public.gallery_week(true, 20) w where w->'card'->>'id' = m.id) as a_week_candidate from public.shared_models m where m.id in ('WipTry0001', 'WipTry0002') order by m.id;
select public.gallery_choose_pick('WipTry0001', 7)->>'refused' as pick_the_crane, public.gallery_feature_keep('featured', current_date, 'WipTry0001')->>'refused' as feature_the_crane;
-- A pick chosen before the crane went WIP is not shown while it is: the pick is worked out from the week instead.
insert into public.gallery_picks (model, until, chosen_at) values ('WipTry0001', now() + interval '6 days', now() - interval '4 hours');
select coalesce(public.gallery_pick(true)->'card'->>'id', 'none') <> 'WipTry0001' as pick_is_not_the_crane;
-- A challenge open now: the crane cannot be entered, the barn can; an entry made before it went WIP is not among the challenge's entries.
insert into public.challenges (title, brief, starts_on, ends_on, test) values ('Wip try: cranes', 'A crane that lifts.', current_date - 3, current_date + 10, true);
create temporary table t_challenge on commit drop as select id from public.challenges where title = 'Wip try: cranes' and test;
select public.challenge_enter('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 'hand')->>'refused' as enter_the_crane, coalesce(public.challenge_enter('00000000-0000-4000-8000-0000000fb001', 'WipTry0002', 'hand')->>'refused', 'entered') as enter_the_barn;
insert into public.challenge_entries (challenge, model, owner, way) values ((select id from t_challenge), 'WipTry0001', '00000000-0000-4000-8000-0000000fb001', 'hand');
select (select string_agg(e->>'model', ', ' order by e->>'model') from jsonb_array_elements(public.challenge_page_at((select id from t_challenge), true)->'entries') e where e->>'model' like 'WipTry%') as challenge_entries_shown;
-- Talk: version 1 opens the crane's one Show and tell thread, as Ada; asked again it is the same post; version 2 is one reply in it, never a thread.
create temporary table t_v1 on commit drop as select public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 1, 'Zqwip crane', 'Work in progress, version 1. The base and the tower. https://brickworks.diy/m/WipTry0001/v/1', 'version', 'Work in progress, version 1. The base and the tower. Each new version will be posted in this thread as it is shared. https://brickworks.diy/m/WipTry0001') as r;
select r->>'made' as made, r->>'refused' as refused, (select p.body like '%/m/WipTry0001' from public.talk_posts p where p.id = (r->>'post')::bigint) as opens_with_the_models_card from t_v1;
-- Bo and Cy follow the thread too (Discourse's Watching).
select public.talk_follow('00000000-0000-4000-8000-0000000fb002', (select (r->>'thread')::bigint from t_v1), true) ? 'refused' as bo_refused, public.talk_follow('00000000-0000-4000-8000-0000000fb003', (select (r->>'thread')::bigint from t_v1), true) ? 'refused' as cy_refused;
-- Inside one transaction every post is at the same now(): their follows are dated an hour back, so the posts come after them as they would.
update public.talk_follows set at = now() - interval '1 hour' where thread = (select (r->>'thread')::bigint from t_v1) and account in ('00000000-0000-4000-8000-0000000fb002', '00000000-0000-4000-8000-0000000fb003');
select (public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 1, 'Zqwip crane', 'Work in progress: version 1 again'))->>'made' as asked_again_made, (public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 1, 'Zqwip crane', 'x'))->>'post' = (select r->>'post' from t_v1) as same_post;
create temporary table t_v2 on commit drop as select public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 2, 'Zqwip crane', 'Work in progress, version 2. The jib is on. What changed: 60 parts added. https://brickworks.diy/m/WipTry0001/v/2') as r;
select (select p.body like '%/m/WipTry0001/v/2' from public.talk_posts p where p.id = (select (r->>'post')::bigint from t_v2)) as reply_has_the_versions_card, (select r->>'thread' from t_v2) = (select r->>'thread' from t_v1) as same_thread, (select count(*) from public.talk_threads t where t.model = 'WipTry0001') as threads_for_the_crane, (select count(*) from public.talk_posts p where p.thread = (select (r->>'thread')::bigint from t_v1)) as posts_in_it, (select t.board from public.talk_threads t where t.model = 'WipTry0001') as board, (select t.author = '00000000-0000-4000-8000-0000000fb001' from public.talk_threads t where t.model = 'WipTry0001') as by_ada;
select (select talk_post from public.share_versions where model = 'WipTry0001' and n = 1) = (select (r->>'post')::bigint from t_v1) as v1_kept, (select talk_post from public.share_versions where model = 'WipTry0001' and n = 2) = (select (r->>'post')::bigint from t_v2) as v2_kept;
-- Somebody else's model, a version not there, a kind not known: refused.
select public.wip_talk('00000000-0000-4000-8000-0000000fb002', 'WipTry0001', 2, 'x', 'As Bo')->>'refused' as bo_posts_adas, public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 9, 'x', 'y')->>'refused' as no_version, public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 2, 'x', 'y', 'other')->>'refused' as odd_kind;
-- Followers of the thread hear of version 2 as of any reply (talk_reply); the feed of each follower of Ada says wip on the crane's rows.
select v.who, (select string_agg(r.kind || ':' || coalesce(r.item->>'model', '-') || ':' || coalesce(r.item->>'version', '-') || ':wip=' || coalesce(r.item->>'wip', '-') || ':finished=' || coalesce(r.item->>'finished', '-'), ', ' order by r.at, r.kind, r.item->>'model') from public.follow_rows(v.id, now() - interval '1 day', now() + interval '1 hour') r where r.item->>'model' like 'WipTry%') as feed from (values ('bo', '00000000-0000-4000-8000-0000000fb002'::uuid), ('cy', '00000000-0000-4000-8000-0000000fb003'::uuid)) v(who, id);
select v.who, (select count(*) from jsonb_array_elements(public.follow_page(v.id, null, 30, false)->'rows') x where x->>'model' like 'WipTry%') as feed_page_rows, (select count(*) from public.notification_rows(v.id, now() - interval '1 day', now() + interval '1 hour') r where r.kind = 'talk_reply' and r.item->'by'->>'handle' = 'wip-try-ada') as thread_notices from (values ('bo', '00000000-0000-4000-8000-0000000fb002'::uuid), ('cy', '00000000-0000-4000-8000-0000000fb003'::uuid)) v(who, id);
-- Cy blocks Ada: from then on nothing of hers reaches Cy, in the feed, in Talk or in notifications.
select public.block_person('00000000-0000-4000-8000-0000000fb003', 'wip-try-ada', true) ? 'refused' as cy_block_refused;
insert into public.share_versions (model, n, at, note, parts, bytes, has_image, wip) values ('WipTry0001', 3, now() - interval '1 hour', 'The hook', 130, 100, true, true);
select public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 3, 'Zqwip crane', 'Work in progress, version 3. The hook. https://brickworks.diy/m/WipTry0001/v/3')->>'made' as v3_made;
select v.who, (select count(*) from public.follow_rows(v.id, now() - interval '1 day', now() + interval '1 hour') r where r.item->>'model' like 'WipTry%') as feed_rows_of_ada, (select count(*) from jsonb_array_elements(public.talk_thread_page((select (r->>'thread')::bigint from t_v1), true, v.id)->'posts') x where x->>'handle' = 'wip-try-ada') as adas_posts_seen, (select count(*) from public.notification_rows(v.id, now() - interval '1 day', now() + interval '1 hour') r where r.item->'by'->>'handle' = 'wip-try-ada') as notices_from_ada, (select count(*) from public.follows f where f.follower = v.id and f.followed = '00000000-0000-4000-8000-0000000fb001') as follows_ada from (values ('bo', '00000000-0000-4000-8000-0000000fb002'::uuid), ('cy', '00000000-0000-4000-8000-0000000fb003'::uuid)) v(who, id);
-- Finished on its page: the newest version is the finished one, once; then the crane ranks as any other.
select public.wip_finish('00000000-0000-4000-8000-0000000fb002', 'WipTry0001')->>'refused' as bo_finishes_adas, public.wip_finish('00000000-0000-4000-8000-0000000fb001', 'WipTry0002')->>'refused' as finish_the_finished;
select public.wip_finish('00000000-0000-4000-8000-0000000fb001', 'WipTry0001')->>'n' as finished_version, public.wip_finish('00000000-0000-4000-8000-0000000fb001', 'WipTry0001')->>'refused' as finished_again;
select (select wip_at is null from public.shared_models where id = 'WipTry0001') as no_longer_wip, (select string_agg(n || ':' || wip || ':' || (finished_at is not null), ', ' order by n) from public.share_versions where model = 'WipTry0001') as versions;
select public.wip_talk('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 3, 'Zqwip crane', 'Finished: version 3 is the finished model. https://brickworks.diy/m/WipTry0001/v/3', 'finished')->>'made' as finished_post_made;
select (select count(*) from public.talk_threads t where t.model = 'WipTry0001') as threads_still, (select count(*) from public.talk_posts p where p.thread = (select (r->>'thread')::bigint from t_v1)) as posts_now, (select finished_post is not null from public.share_versions where model = 'WipTry0001' and n = 3) as finish_kept;
select s.sort, (select string_agg(x->>'id', ', ' order by x->>'id') from public.gallery_models(jsonb_build_object('sort', s.sort, 'tests', true, 'words', 'zqwip:*')) x) as listed from (values ('newest'), ('top'), ('builds')) s(sort);
select m.id, public.gallery_shows(m, true) as shown, public.directory_card(m)->>'wip' as wip from public.shared_models m where m.id = 'WipTry0001';
select coalesce(public.challenge_enter('00000000-0000-4000-8000-0000000fb001', 'WipTry0001', 'hand')->>'refused', 'entered') as enter_the_crane_now;
-- Bo's feed has the finish made on the page, at its own time, said finished; Cy's nothing.
select v.who, (select string_agg(r.kind || ':' || coalesce(r.item->>'version', '-') || ':finished=' || coalesce(r.item->>'finished', '-') || ':later=' || coalesce(r.item->>'later', '-'), ', ' order by r.at) from public.follow_rows(v.id, now() - interval '1 day', now() + interval '1 hour') r where r.item->>'model' = 'WipTry0001') as feed from (values ('bo', '00000000-0000-4000-8000-0000000fb002'::uuid), ('cy', '00000000-0000-4000-8000-0000000fb003'::uuid)) v(who, id);
