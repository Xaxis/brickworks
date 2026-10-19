-- What supabase/tested.sql would make, asked inside its dry run. Never
-- applied: tools/apply_sql.mjs runs these after the file, in the same
-- transaction, and rolls the whole of it back.
--
--   PG_MODULE=<pg>/lib/index.js node tools/apply_sql.mjs supabase/tested.sql \
--     --dry --try=tools/tested_try.sql --table=share_tests
--
-- One statement to a paragraph, as apply_sql splits them.

-- Nothing is tested until a model is published with a mark.
select count(*) as marks from public.share_tests;

-- Two listed models, their newest versions: one marked Tested, one that
-- failed. A third, listed and never tested, stays as it was.
create temporary table tried as select id, row_number() over (order by listed_at desc, id) as k from public.shared_models where published and listed and not barred and not test order by listed_at desc, id limit 3;

insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed)
select t.id, (select max(n) from public.share_versions v where v.model = t.id), '0.3.0', repeat('a', 64), 10, 4,
       case when t.k = 1 then '{"stands":{"ok":true,"why":"Stands at every one of its 4 steps"},"steps":{"ok":true,"why":"Every part goes onto what is already built, in sight"},"parts":{"ok":true,"why":"Every part is made in its colour"},"whole":{"ok":true,"why":"Every part is held by the model"}}'::jsonb
            else '{"stands":{"ok":true,"why":"Stands"},"steps":{"ok":false,"why":"Step 2: Brick 2 x 4 is put down in the air"},"parts":{"ok":true,"why":"ok"},"whole":{"ok":true,"why":"ok"}}'::jsonb end,
       t.k = 1
  from tried t where t.k <= 2
returning model, n, passed;

-- The card says it of the passed one only, and of nothing else.
select t.k, public.model_tested(t.id) as tested, (public.directory_card(m) ->> 'tested')::boolean as card_says
  from tried t join public.shared_models m on m.id = t.id order by t.k;

-- Tested only lists the passed one, and the gallery as it was lists all three.
select count(*) filter (where (c ->> 'id') in (select id from tried where k = 1)) as passed_listed,
       count(*) filter (where (c ->> 'id') in (select id from tried where k = 2)) as failed_listed,
       count(*) filter (where (c ->> 'id') in (select id from tried where k = 3)) as untested_listed,
       count(*) as listed_tested_only
  from public.directory_models('{"tested": true, "size": 49}'::jsonb) c;

select count(*) filter (where (c ->> 'id') in (select id from tried)) as of_the_three, count(*) as listed
  from public.directory_models('{"size": 49}'::jsonb) c;

-- Cleared by the site's owner, it is not Tested any more.
update public.share_tests set cleared_at = now(), cleared_why = 'tried' where model = (select id from tried where k = 1) returning model, cleared_why;

select public.model_tested(id) as tested_after_clearing from tried where k = 1;

-- What it refuses: written here as one line, as apply_sql splits on a
-- line's end.
create function pg_temp.refused(statement text) returns text language plpgsql as $f$ begin execute statement; return 'TAKEN'; exception when others then return 'refused: ' || sqlerrm; end $f$;

select pg_temp.refused($$insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) values ('Nope000000', 1, '0.3.0', repeat('a', 64), 1, 1, '{"stands":{"ok":true},"steps":{"ok":true},"parts":{"ok":true},"whole":{"ok":true}}', true)$$) as a_mark_of_no_version,
       pg_temp.refused($$insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) select model, n, '0.3.0', repeat('a', 64), 1, 1, '{"stands":{"ok":false},"steps":{"ok":true},"parts":{"ok":true},"whole":{"ok":true}}', true from public.share_versions where model = (select id from tried where k = 3) order by n desc limit 1$$) as passed_when_a_test_failed,
       pg_temp.refused($$insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) select model, n, '0.3.0', repeat('a', 64), 1, 1, '{"stands":{"ok":true}}', false from public.share_versions where model = (select id from tried where k = 3) order by n desc limit 1$$) as fewer_than_four_tests,
       pg_temp.refused($$insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) select model, n, 'any app', repeat('a', 64), 1, 1, '{"stands":{"ok":true},"steps":{"ok":true},"parts":{"ok":true},"whole":{"ok":true}}', true from public.share_versions where model = (select id from tried where k = 3) order by n desc limit 1$$) as an_app_not_a_version,
       pg_temp.refused($$insert into public.share_tests (model, n, by, app, file_hash, parts, steps, tests, passed) select model, n, 'server', '0.3.0', repeat('a', 64), 1, 1, '{"stands":{"ok":true},"steps":{"ok":true},"parts":{"ok":true},"whole":{"ok":true}}', true from public.share_versions where model = (select id from tried where k = 3) order by n desc limit 1$$) as anybody_but_the_app;

-- A version taken down takes its mark with it.
delete from public.share_versions where model = (select id from tried where k = 2) returning model, n;

select count(*) as marks_left_of_the_failed_one from public.share_tests where model = (select id from tried where k = 2);

-- Nobody but the server: no key a page has may read or write it.
select has_table_privilege('anon', 'public.share_tests', 'select') as anon_reads,
       has_table_privilege('authenticated', 'public.share_tests', 'select') as signed_in_reads,
       has_table_privilege('authenticated', 'public.share_tests', 'insert') as signed_in_writes,
       has_table_privilege('service_role', 'public.share_tests', 'insert') as server_writes,
       has_function_privilege('anon', 'public.model_tested(text)', 'execute') as anon_asks;
