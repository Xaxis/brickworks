-- What supabase/house.sql does, read back inside the rolled-back
-- transaction of a dry run, after the file has run twice: nothing here is
-- kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/house.sql --dry --again=supabase/house.sql \
--       --try=tools/house_try.sql --table=people
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
-- Run twice, one profile, its words and its age answer.
select count(*) as "profiles with the handle", min(p.name) as name, min(char_length(p.bio)) as "bio length", min(p.bio) as bio, bool_and(r.over_13) as "13 or over", count(r.age_asked_at) as "answered" from public.people p join public.profiles r on r.id = p.account where p.handle = 'brickworks';
-- What its page shows besides: the banner and the pins, the house's own.
select s.banner, s.pins, (select count(*) from public.profile_shows x where x.account = s.account) as "rows" from public.profile_shows s join public.people p on p.account = s.account where p.handle = 'brickworks';
-- Every listed model of the house is now credited to the profile on its card, and no model row changed.
select m.id, m.name, m.author, public.directory_card(m)->'by' as card_by, m.updated_at from public.shared_models m join public.people p on p.account = m.owner where p.handle = 'brickworks' and m.listed order by m.listed_at;
-- It may be followed, and is shown in public.
select public.follow_may_be_followed(p.account) as "may be followed", public.shown_publicly(p.account) as "shown publicly" from public.people p where p.handle = 'brickworks';
-- Its profile, as /u/brickworks asks it.
select (public.profile_page('brickworks'))->>'models' as models, (public.profile_page('brickworks'))->>'name' as name;
-- The feed's designers to follow are read from Top builds' cards (api/_follows.js designersFrom): the house is on them.
select count(*) as "top cards", count(*) filter (where card->'by'->>'handle' = 'brickworks') as "credited to the house" from public.gallery_models('{"sort": "top", "size": 49, "skip": 0}'::jsonb) as card;
-- In the sitemap.
select count(*) as "the house's page in the sitemap" from public.sitemap_pages() as page where page::text like '%/u/brickworks%' or page::text like '%"brickworks"%';
