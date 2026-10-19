-- What supabase/versions.sql would make, asked inside its dry run. Never
-- applied: tools/apply_sql.mjs runs these after the file, in the same
-- transaction, and rolls the whole of it back.
--
--   PG_MODULE=<pg>/lib/index.js node tools/apply_sql.mjs supabase/versions.sql \
--     --dry --try=tools/versions_try.sql --table=share_versions
--
-- One statement to a paragraph, as apply_sql splits them.

-- Every published model, and every version 1 the file made for them.
select count(*) filter (where published) as published_models, count(*) as rows_of_models
  from public.shared_models;

select count(*) as versions, count(*) filter (where n = 1) as version_ones,
       count(distinct model) as models_with_versions
  from public.share_versions;

-- None published without its version 1, and none taken down with one.
select count(*) filter (where m.published and v.model is null) as published_without_version_1,
       count(*) filter (where not m.published and v.model is not null) as taken_down_with_versions
  from public.shared_models m
  left join public.share_versions v on v.model = m.id and v.n = 1;

-- A version 1 is the model as it is: its counts, its picture, its date.
select count(*) as compared,
       count(*) filter (where v.parts = m.parts and v.bytes = m.bytes and v.has_image = m.has_image
         and v.steps is not distinct from m.steps and v.at = m.updated_at) as as_the_model_is,
       count(*) filter (where v.note is null and v.changes is null and v.first_changed is null) as saying_nothing
  from public.share_versions v join public.shared_models m on m.id = v.model;

-- A second version, as api/share.js writes one.
insert into public.share_versions (model, n, parts, steps, bytes, has_image, note, changes, first_changed)
select model, 2, parts, steps, bytes, has_image, 'Fixed the roof',
       '{"added":[{"part":"3001","colour":1,"count":2}],"removed":[{"part":"3001","colour":4,"count":2}],"first":3,"compared":true}'::jsonb, 3
  from public.share_versions where n = 1 order by model limit 1
returning n, note, first_changed, changes ->> 'first' as first_in_changes;

-- What it refuses: written here as one line, as apply_sql splits on a
-- line's end.
create function pg_temp.refused(statement text) returns text language plpgsql as $f$ begin execute statement; return 'TAKEN'; exception when others then return 'refused: ' || sqlerrm; end $f$;

select pg_temp.refused($$insert into public.share_versions (model, n, parts, bytes) values ('Nope000000', 1, 1, 1)$$) as a_version_of_no_model,
       pg_temp.refused($$insert into public.share_versions (model, n, parts, bytes) select model, 1, parts, bytes from public.share_versions where n = 1 limit 1$$) as the_same_version_twice,
       pg_temp.refused($$insert into public.share_versions (model, n, parts, bytes, note) select model, 9, parts, bytes, repeat('x', 281) from public.share_versions where n = 1 limit 1$$) as a_note_too_long,
       pg_temp.refused($$insert into public.share_versions (model, n, parts, bytes) select model, 0, parts, bytes from public.share_versions where n = 1 limit 1$$) as a_version_0,
       pg_temp.refused($$insert into public.share_versions (model, n, parts, bytes, changes) select model, 9, parts, bytes, '[1]'::jsonb from public.share_versions where n = 1 limit 1$$) as changes_not_an_object;

-- Nobody but the server: no key a page has may read or write it.
select has_table_privilege('anon', 'public.share_versions', 'select') as anon_reads,
       has_table_privilege('authenticated', 'public.share_versions', 'select') as signed_in_reads,
       has_table_privilege('authenticated', 'public.share_versions', 'insert') as signed_in_writes,
       has_table_privilege('service_role', 'public.share_versions', 'insert') as server_writes;

-- And running the file again changes nothing: every statement in it is
-- "if not exists" or "on conflict do nothing".
insert into public.share_versions (model, n, at, parts, steps, bytes, has_image)
select id, 1, updated_at, parts, steps, bytes, has_image from public.shared_models where published
on conflict (model, n) do nothing
returning model;
