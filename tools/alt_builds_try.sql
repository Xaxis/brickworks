-- What supabase/alt_builds.sql does, tried inside the rolled-back transaction of a
-- dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/alt_builds.sql --dry --try=tools/alt_builds_try.sql --table=model_alt_sets
--
-- A made-up account, made and gone with the transaction, at a Resend test address: Ada designs. Every model a
-- test model. Each statement is on one line: the dry run splits at a semicolon that ends a line.
--   AltTry0001  a cottage: every part from 31009-1, and its designer says changed from 6080-1
--   AltTry0002  a crane: from 42115-1 and 42054-1 together
--   AltTry0003  a cottage too: 97% from 31009-1, the best it has
--   AltTry0004  6080-1's own model, published: own, listed nowhere as built from it
--   AltTry0005  only declared an alternate of 31009-1, never counted
-- The gallery as it answers with the file, before any of ours: tools/web/alt_sql_compare.mjs holds each to the live answer.
select (select jsonb_agg(g) from public.gallery_models('{"sort": "newest", "size": 49}') g) as "newest", (select jsonb_agg(g) from public.gallery_models('{"sort": "top", "size": 49}') g) as "top", (select jsonb_agg(g) from public.gallery_models('{"sort": "likes", "size": 49, "technic": true}') g) as "likes technic", (select jsonb_agg(g) from public.gallery_models('{"sort": "newest", "size": 49, "made": "hand", "least": 200, "tests": true}') g) as "hand 200 up tests";
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alt-try-ada@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000c1', true)->>'over_13' as ada;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published) values ('AltTry0001', '00000000-0000-4000-8000-0000000000c1', 'Alt cottage', 'Ada Alt', 120, 100, true, now() - interval '5 days', true, true), ('AltTry0002', '00000000-0000-4000-8000-0000000000c1', 'Alt crane', 'Ada Alt', 900, 100, true, now() - interval '4 days', true, true), ('AltTry0003', '00000000-0000-4000-8000-0000000000c1', 'Alt cottage two', 'Ada Alt', 100, 100, true, now() - interval '3 days', true, true), ('AltTry0004', '00000000-0000-4000-8000-0000000000c1', '6080 King''s Castle', 'Ada Alt', 700, 100, true, now() - interval '2 days', true, true), ('AltTry0005', '00000000-0000-4000-8000-0000000000c1', 'Alt said only', 'Ada Alt', 50, 100, true, now() - interval '1 day', true, true);
insert into public.model_needs (model, part, colour, qty) values ('AltTry0001', '3001', 4, 100), ('AltTry0001', '3794', 15, 20), ('AltTry0002', '3001', 0, 900);
insert into public.model_needs_kept (model, pieces, at) values ('AltTry0001', 120, now() - interval '1 hour'), ('AltTry0002', 900, now() - interval '1 hour');
select public.model_bases_put('00000000-0000-4000-8000-0000000000c1', 'AltTry0001', '[{"how": "changed", "set": "6080-1"}]') as "put 1", public.model_bases_put('00000000-0000-4000-8000-0000000000c1', 'AltTry0005', '[{"how": "alternate", "set": "31009-1"}]') as "put 5";
-- Kept, each model's rows whole; a model that is not there refused.
select public.alt_keep('AltTry0001', 120, 1, false, '[{"set": "31009-1", "role": "whole", "n": 0, "have": 120}, {"set": "6080-1", "role": "declared", "n": 0, "have": 40}]') as "1", public.alt_keep('AltTry0002', 900, 1, false, '[{"set": "42115-1", "role": "group", "n": 1, "have": 700}, {"set": "42054-1", "role": "group", "n": 2, "have": 250}]') as "2", public.alt_keep('AltTry0003', 100, 1, false, '[{"set": "31009-1", "role": "best", "n": 0, "have": 97}]') as "3", public.alt_keep('AltTry0004', 700, 1, false, '[{"set": "6080-1", "role": "own", "n": 0, "have": 650}]') as "4", public.alt_keep('NoSuchOne1', 1, 1, false, '[]') as "none";
-- Kept again replaces: one row, not two.
select public.alt_keep('AltTry0003', 100, 1, true, '[{"set": "31009-1", "role": "best", "n": 0, "have": 97}]') as "3 again";
select model, set_number, role, n, have from public.model_alt_sets where model like 'AltTry%' order by model, n, set_number;
select model, pieces, rule, cut from public.model_alts where model like 'AltTry%' order by model;
-- The rows of two models; what one needs.
select public.alt_of(array['AltTry0001', 'AltTry0002']) as "alt_of";
select public.alt_needs_of(array['AltTry0001', 'AltTry0002', 'AltTry0005']) as "needs";
-- 31009-1's page: the whole one first, then the best at 97%, then the one only declared; never the visitor's test models.
select jsonb_array_length(public.set_built('31009-1', true)) as "31009-1, tests", (select jsonb_agg(jsonb_build_object('id', c->>'id', 'based', c->'based', 'alt', c->'alt')) from jsonb_array_elements(public.set_built('31009-1', true)) c) as "cards", jsonb_array_length(public.set_built('31009-1', false)) as "a visitor's";
-- 42054-1's page: the crane, with the group's other set; 6080-1's: the cottage, declared changed with its share, and never its own model.
select (select jsonb_agg(jsonb_build_object('id', c->>'id', 'based', c->'based', 'alt', c->'alt')) from jsonb_array_elements(public.set_built('42054-1', true)) c) as "42054-1", (select jsonb_agg(jsonb_build_object('id', c->>'id', 'based', c->'based', 'alt', c->'alt')) from jsonb_array_elements(public.set_built('6080-1', true)) c) as "6080-1";
-- The gallery: alt=31009-1 is the whole one; alt=42054-1 the crane; one_set the whole one alone; neither changes a list asked without them.
select (select array_agg(g->>'id') from public.gallery_models('{"alt": "31009-1", "tests": true}') g) as "alt 31009-1", (select array_agg(g->>'id') from public.gallery_models('{"alt": "42054-1", "tests": true}') g) as "alt 42054-1", (select array_agg(g->>'id') from public.gallery_models('{"one_set": true, "tests": true}') g) as "one set", (select count(*) from public.gallery_models('{"tests": true, "size": 49}') g where g->>'id' like 'AltTry%') as "plain list, ours";
-- To count: what has needs and no count by rule 1, or an older rule; then all with rule 2 asked.
select public.alt_uncounted(1, 500) && array['AltTry0001', 'AltTry0002'] as "rule 1: any of ours left (none)", public.alt_uncounted(2, 500) @> array['AltTry0001', 'AltTry0002'] as "rule 2: both again";
-- A model deleted takes its rows with it.
delete from public.shared_models where id = 'AltTry0002';
select count(*) as "left of the crane" from public.model_alt_sets where model = 'AltTry0002';
-- Nobody but the server runs any of it, or reads the tables.
select r.rolname, p.proname from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname in ('alt_keep', 'alt_of', 'alt_needs_of', 'alt_uncounted', 'set_built', 'gallery_models') and has_function_privilege(r.rolname, p.oid, 'execute');
select count(*) as "the service role runs" from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('alt_keep', 'alt_of', 'alt_needs_of', 'alt_uncounted', 'set_built', 'gallery_models') and has_function_privilege('service_role', p.oid, 'execute');
select has_table_privilege('service_role', 'public.model_alt_sets', 'select') as "service role reads the table", has_table_privilege('anon', 'public.model_alts', 'select') as "anon reads";
-- The set's page's read: by the set's index.
explain select s.model from public.model_alt_sets s where s.set_number = '31009-1' and s.role in ('whole', 'group', 'best', 'declared', 'library');
