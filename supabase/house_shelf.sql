-- The house's words, once it shares the shelf from the LDraw library,
-- 2026-10-25 (gallery261).
--
-- house.sql gave the house's profile words that say "Every model here was
-- designed with the assistant". With the shelf from the LDraw library
-- (tools/web/gallery_seeds/ldraw_library.json: real sets as LDraw's
-- builders modelled them, each credited to its modeller, shared by the
-- house) that is no longer so. The API cannot change them: the handle is
-- the house's alone (api/_names.js RESERVED), so a profile save of it is
-- refused. This says them again, the same words for its own models and a
-- sentence for the shelf, 296 characters of the 300 a profile may say.
--
-- What it writes: people.bio of the profile @brickworks, and only while it
-- is still the words house.sql gave it, so words the owner has changed
-- since are kept, and running it again changes nothing. No other row is
-- read or written. To take it back: house.sql's words again.
--
-- Applied by the lead with the first slice of the shelf, not before (the
-- words name the collection):
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/house_shelf.sql --table=people
--
-- tried first, rolled back: ... --dry --again=supabase/house_shelf.sql

update public.people
   set bio = 'The Brickworks studio''s own account. Its own models were designed with the assistant, '
          || 'Claude working in the app, and each one''s description says how. The collection From the '
          || 'LDraw library holds real sets as LDraw''s builders modelled them, each credited to them. '
          || 'Open one to build it step by step.',
       updated_at = now()
 where handle = 'brickworks'
   and bio = 'The Brickworks studio''s own account. Every model here was designed with the assistant, '
          || 'Claude working in the app, and each one''s description says how. Open one to build it '
          || 'step by step, or remix it as your own.';
