-- What supabase/achievements.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/achievements.sql --dry --try=tools/achievements_try.sql --table=achievement_marks
--
-- After replies.sql and the files before it, which the project has. Made-up accounts, made and gone with the
-- transaction: Ada designs (a test account, at a Resend test address, so her test models count on her own page),
-- Bob builds and remixes. Every model a test model, every challenge a test one. Each statement is on one line: the
-- dry run splits at a semicolon that ends a line. Inside one transaction now() never moves.
-- First: nobody has a level written down, so no account's notifications have changed.
select count(*) as "levels written down", (select count(*) from public.achievement_ladders()) as tracks from public.achievement_marks;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ach-ada@resend.dev'), ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ach-bob@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000e1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000000e2', true)->>'over_13' as bob;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000000e1', 'ach-try-ada', 'Ada Achieves'), ('00000000-0000-4000-8000-0000000000e2', 'ach-try-bob', 'Bob Achieves');
select x->>'track' as track, x->>'n' as n, x->>'level' as level, x->>'next' as next from jsonb_array_elements(public.achievement_levels('00000000-0000-4000-8000-0000000000e1', true)) x;
-- Ada lists three models, credited; one passed the app's tests; her house was built to its last step twelve times.
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published) values ('AchTry0001', '00000000-0000-4000-8000-0000000000e1', 'Ach house', 'Ada Achieves', 40, 100, true, now(), true, true), ('AchTry0002', '00000000-0000-4000-8000-0000000000e1', 'Ach shed', 'Ada Achieves', 30, 100, true, now(), true, true), ('AchTry0003', '00000000-0000-4000-8000-0000000000e1', 'Ach mill', 'Ada Achieves', 30, 100, true, now(), true, true);
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, now(), parts, 100 from public.shared_models where id like 'AchTry%';
insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) values ('AchTry0003', 1, '0.3.0', repeat('a', 64), 30, 6, '{"stands":{"ok":true},"steps":{"ok":true},"parts":{"ok":true},"whole":{"ok":true}}', true);
insert into public.model_stats (model, builds) values ('AchTry0001', 12) on conflict (model) do update set builds = excluded.builds;
-- Bob remixes the house (his remix not listed, so not a model of his in the gallery) and posts a photo of his build of it.
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, test, published, remixed_from) values ('AchTry0004', '00000000-0000-4000-8000-0000000000e2', 'Ach house remixed', 'Bob Achieves', 42, 100, false, true, true, 'AchTry0001');
insert into public.build_photos (id, model, account, width, height, bytes, was) values ('AchPhoto01', 'AchTry0001', '00000000-0000-4000-8000-0000000000e2', 1600, 1200, 200000, 'jpeg');
-- Ada entered a test challenge that has ended.
insert into public.challenges (title, brief, starts_on, ends_on, test) values ('Ach try challenge', 'Build a shed.', current_date - 40, current_date - 35, true);
insert into public.challenge_entries (challenge, model, owner, way) values ((select id from public.challenges where title = 'Ach try challenge'), 'AchTry0002', '00000000-0000-4000-8000-0000000000e1', 'hand');
-- Her levels, as her own page and a test page count them: Designer 2 (3 models), Built 2 (12), Remixed 1, Tested 1, Challenger 1, Builder none.
select x->>'track' as track, x->>'n' as n, x->>'level' as level, x->>'of' as "of", x->>'reached' as reached, x->>'next' as next from jsonb_array_elements(public.achievement_levels('00000000-0000-4000-8000-0000000000e1', true)) x;
-- A visitor's page counts no test model: none at all.
select string_agg(x->>'track' || ' ' || (x->>'level'), ', ') as "a visitor's levels of hers" from jsonb_array_elements(public.achievement_levels('00000000-0000-4000-8000-0000000000e1', false)) x;
-- Written down once: seven levels (2 + 2 + 1 + 1 + 1), then none again.
select public.achievement_mark('00000000-0000-4000-8000-0000000000e1') as "written", public.achievement_mark('00000000-0000-4000-8000-0000000000e1') as "again";
select track, level, read_at is null as unread from public.achievement_marks where account = '00000000-0000-4000-8000-0000000000e1' order by track, level;
-- Told as a row a track, its highest level, model null; counted as new; in her list beside what else happened.
select n.kind, n.model, n.item->>'track' as track, n.item->>'level' as level, n.item->>'reached' as reached, n.item->>'next' as next, n.item->>'read' as read from public.notification_rows('00000000-0000-4000-8000-0000000000e1', now() - interval '1 day', now()) n order by n.kind, n.item->>'track';
select public.notification_counts('00000000-0000-4000-8000-0000000000e1') as counts, (select count(*) from jsonb_array_elements(public.notification_list('00000000-0000-4000-8000-0000000000e1')->'rows') r where r->>'kind' = 'achievement' and r->>'on' is null) as "listed, on nothing";
-- Their group opened: each read (what a statement writes, the next one reads); Mark all read is notification_read's, unchanged.
select public.achievement_read('00000000-0000-4000-8000-0000000000e1') as "read", public.achievement_read('00000000-0000-4000-8000-0000000000e1') as "read again";
select bool_and((n.item->>'read')::boolean) as "all read" from public.notification_rows('00000000-0000-4000-8000-0000000000e1', now() - interval '1 day', now()) n where n.kind = 'achievement';
-- Bob: his photo of a build is Builder 1; his unlisted remix is no Designer level.
select public.achievement_mark('00000000-0000-4000-8000-0000000000e2') as "bob written";
select string_agg(track || ' ' || level, ', ') as "bob's" from public.achievement_marks where account = '00000000-0000-4000-8000-0000000000e2';
-- A number drops (a model unlisted): her level is lower on her page, the level written down is kept, and nothing is told again.
update public.shared_models set listed = false where id = 'AchTry0002';
select (select x->>'level' from jsonb_array_elements(public.achievement_levels('00000000-0000-4000-8000-0000000000e1', true)) x where x->>'track' = 'designer') as "designer now", public.achievement_mark('00000000-0000-4000-8000-0000000000e1') as "written";
select count(*) as "kept" from public.achievement_marks where account = '00000000-0000-4000-8000-0000000000e1';
-- Taken out of the gallery, or under 13: no levels, and none written down.
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000e1', 'achievements try');
select public.achievement_levels('00000000-0000-4000-8000-0000000000e1', true) as "taken out", public.achievement_mark('00000000-0000-4000-8000-0000000000e1') as "written";
update public.profiles set over_13 = false where id = '00000000-0000-4000-8000-0000000000e2';
select public.achievement_levels('00000000-0000-4000-8000-0000000000e2', true) as "under 13", public.achievement_levels(null) as "nobody", public.achievement_mark(null) as "nobody written";
-- Her account deleted: her levels go with it.
delete from auth.users where id = '00000000-0000-4000-8000-0000000000e1';
select count(*) as "hers left" from public.achievement_marks where account = '00000000-0000-4000-8000-0000000000e1';
-- Nobody but the server runs any of it, or reads the table.
select r.rolname, p.proname from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname in ('achievement_ladders', 'achievement_numbers', 'achievement_levels', 'achievement_mark', 'achievement_read', 'notification_rows') and has_function_privilege(r.rolname, p.oid, 'execute');
select count(*) as "the service role runs" from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('achievement_ladders', 'achievement_numbers', 'achievement_levels', 'achievement_mark', 'achievement_read', 'notification_rows') and has_function_privilege('service_role', p.oid, 'execute');
select has_table_privilege('anon', 'public.achievement_marks', 'select') as anon_reads, has_table_privilege('authenticated', 'public.achievement_marks', 'select') as signed_in_reads, has_table_privilege('service_role', 'public.achievement_marks', 'select') as service_reads, (select relrowsecurity from pg_class where oid = 'public.achievement_marks'::regclass) as row_security
