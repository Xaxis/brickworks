-- What supabase/search_shown.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/search_shown.sql --dry --try=tools/search_shown_try.sql --table=shared_models
--
-- One made-up account, made and gone with the transaction, 13 or over at a
-- Resend test address, so every model here is a test model. Each statement
-- is on one line: the dry run splits at a semicolon that ends a line. The
-- words are what api/_directory.js listQuery sends for a search:
-- "ai-designed" and "ai designed" are ai:* & designed:*, "brickify" is brickify:*.
--
--   SearchTry1   Search Try Tower Quiet     tagged ai-designed, not shown
--   SearchTry2   Search Try Tower Said      tagged ai-designed, its owner showed it
--   SearchTry3   Search Try Tower Three     tagged brickify, not shown (no way word in its own)
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000c3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'search-shown-try@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000c3', true)->>'over_13' as over_13;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, tags, made_with, made_with_shown) values ('SearchTry1', '00000000-0000-4000-8000-0000000000c3', 'Search Try Tower Quiet', 'Try', 10, 100, true, now(), true, '{tower,ai-designed}', 'assistant', false), ('SearchTry2', '00000000-0000-4000-8000-0000000000c3', 'Search Try Tower Said', 'Try', 10, 100, true, now(), true, '{tower,ai-designed}', 'assistant', true), ('SearchTry3', '00000000-0000-4000-8000-0000000000c3', 'Search Try Tower Three', 'Try', 10, 100, true, now(), true, '{tower,brickify}', 'brickify', false);
-- "ai-designed" finds the shown one alone, in the gallery and the directory (gallery: SearchTry2; directory: SearchTry2):
select coalesce(string_agg(c->>'id', ', ' order by c->>'id') filter (where c->>'id' like 'SearchTry%'), 'none') as gallery from public.gallery_models('{"tests": true, "sort": "newest", "size": 200, "skip": 0, "words": "ai:* & designed:*"}'::jsonb) c;
select coalesce(string_agg(c->>'id', ', ' order by c->>'id') filter (where c->>'id' like 'SearchTry%'), 'none') as directory from public.directory_models('{"tests": true, "sort": "newest", "size": 200, "skip": 0, "words": "ai:* & designed:*"}'::jsonb) c;
-- "brickify" finds none of them (none):
select coalesce(string_agg(c->>'id', ', ' order by c->>'id') filter (where c->>'id' like 'SearchTry%'), 'none') as brickify from public.gallery_models('{"tests": true, "sort": "newest", "size": 200, "skip": 0, "words": "brickify:*"}'::jsonb) c;
-- Their own words still find all three ("search try tower": SearchTry1, SearchTry2, SearchTry3), and a tag that is not a way does too ("tower"):
select coalesce(string_agg(c->>'id', ', ' order by c->>'id') filter (where c->>'id' like 'SearchTry%'), 'none') as own_words from public.gallery_models('{"tests": true, "sort": "newest", "size": 200, "skip": 0, "words": "search:* & try:* & tower:*"}'::jsonb) c;
-- On the live models (no test models): how many hidden models tagged ai-designed or brickify a visitor's "ai-designed" or "brickify" still finds (hidden_found 0), and of all found, how many:
select count(*) filter (where not coalesce((c->>'made_with_shown')::boolean, false) and (c->'tags') ?| array['ai-designed', 'brickify']) as hidden_found, count(*) as found from public.gallery_models('{"sort": "newest", "size": 500, "skip": 0, "words": "ai:* & designed:*"}'::jsonb) c;
select count(*) filter (where not coalesce((c->>'made_with_shown')::boolean, false) and (c->'tags') ?| array['ai-designed', 'brickify']) as hidden_found, count(*) as found from public.gallery_models('{"sort": "newest", "size": 500, "skip": 0, "words": "brickify:*"}'::jsonb) c;
-- Nobody but the server runs them:
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('directory_models', 'gallery_models') order by 1;
