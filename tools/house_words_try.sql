-- What supabase/house_words.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/house_words.sql --dry --again=supabase/house_words.sql \
--     --try=tools/house_words_try.sql --table=people
--
-- --again runs the file a second time in the same transaction: its notices then say 0, as a
-- second run changes nothing.
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
-- No house model's words say who or what designed it (saying 0, of models 56):
select count(*) filter (where m.description ~* '(claude|assistant)') as saying, count(*) as models from public.shared_models m join public.people p on p.account = m.owner where p.handle = 'brickworks';
-- Nor its profile (saying false), and what it says:
select bio ~* '(claude|assistant)' as saying, bio from public.people where handle = 'brickworks';
-- Its search words follow (searchable_claude 0):
select count(*) filter (where m.search::text ~* 'claude') as searchable_claude from public.shared_models m join public.people p on p.account = m.owner where p.handle = 'brickworks';
-- No model moved up New (moved_up_new 0):
select count(*) as house_models, count(*) filter (where m.updated_at > now() - interval '1 minute') as moved_up_new from public.shared_models m join public.people p on p.account = m.owner where p.handle = 'brickworks';
