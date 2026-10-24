-- shared_models' published rows, closed to the keys a page holds too,
-- 2026-10-24: the last of supabase/no_client_access.sql (orangecheck's N1).
--
-- Until this, the publishable key read a published row's public columns
-- (shared_models.sql's policy and column grants), and api/share.js read
-- them that way. From oc205's release it reads them as the server, so
-- this is applied once that release is live, never before: the release
-- before it would lose every link's page, picture and card.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/no_client_access_models.sql --table=shared_models
--
-- Only takings away. Applying it again changes nothing.

drop policy if exists shared_models_read_published on public.shared_models;
revoke all on table public.shared_models from anon, authenticated;

notify pgrst, 'reload schema';
