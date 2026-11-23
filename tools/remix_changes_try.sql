-- What supabase/remix_changes.sql does, tried inside the rolled-back transaction of a
-- dry run on the live database: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/remix_changes.sql --dry --try=tools/remix_changes_try.sql --table=remix_changes
--
-- The remixes there are, one counted by hand (a row as api/_remix.js keeps it), and
-- remix_tree both ways: the original's (its remix under it, if listed) and the remix's
-- own (its changes, and the original above it, if listed).
select count(*) as remixes from public.shared_models where remixed_from is not null and published;
select id, remixed_from, listed, test from public.shared_models where remixed_from is not null and published order by created_at desc limit 5;
insert into public.remix_changes (model, n, against, against_n, added, removed, moved, recoloured, parts_was, parts_now) select id, 1, remixed_from, 1, 3, 1, 2, 0, 10, 12 from public.shared_models where remixed_from is not null and published order by created_at desc limit 1;
select public.remix_tree(remixed_from) as tree_of_parent from public.shared_models where remixed_from is not null and published order by created_at desc limit 1;
select public.remix_tree(id) as tree_of_remix from public.shared_models where remixed_from is not null and published order by created_at desc limit 1;
