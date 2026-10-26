-- The part count each published model keeps, as its page counts it
-- (web295, tools/web/parts_backfill.mjs): 39 published models, 46 files counted, 4 models' counts and 4 versions' to change, read 2026-10-26.
--
-- Data only: no table, function or grant is made or changed. Each update
-- is held to the row as it was read (its count, and the model's updated_at),
-- so a model published again since keeps what that publish kept.
--
--   node tools/apply_sql.mjs supabase/parts_counted.sql --dry
--   node tools/apply_sql.mjs supabase/parts_counted.sql

update public.shared_models set parts = 306 where id = 'TW4JVKYmPH' and parts = 324 and updated_at = '2026-10-26T14:38:12.319+00:00';
update public.share_versions set parts = 306 where model = 'TW4JVKYmPH' and n = 1 and parts = 324;
update public.shared_models set parts = 248 where id = 'L4opmXZWHs' and parts = 249 and updated_at = '2026-10-26T14:38:27.947+00:00';
update public.share_versions set parts = 248 where model = 'L4opmXZWHs' and n = 1 and parts = 249;
update public.shared_models set parts = 748 where id = 'dJikpZoSLM' and parts = 983 and updated_at = '2026-10-26T15:43:50.098+00:00';
update public.share_versions set parts = 748 where model = 'dJikpZoSLM' and n = 1 and parts = 983;
update public.shared_models set parts = 336 where id = '9PyDfjvaPV' and parts = 436 and updated_at = '2026-10-26T15:43:58.767+00:00';
update public.share_versions set parts = 336 where model = '9PyDfjvaPV' and n = 1 and parts = 436;
