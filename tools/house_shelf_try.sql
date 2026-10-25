-- What supabase/house_shelf.sql does, read inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/house_shelf.sql --dry --try=tools/house_shelf_try.sql --table=people
--
-- The house's words after it, how long they are, and that no other
-- profile was changed (updated in the last minute).
select handle, char_length(bio) as "characters", bio from public.people where handle = 'brickworks';
select count(*) as "other profiles changed just now" from public.people where handle <> 'brickworks' and updated_at > now() - interval '1 minute'
