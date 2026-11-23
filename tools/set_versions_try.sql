-- What supabase/set_versions.sql does, tried inside the rolled-back transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/set_versions.sql --dry --try=tools/set_versions_try.sql --table=model_alt_sets
--
-- A made-up account, made and gone with the transaction, at a Resend test address. Every model a test model. Each
-- statement is on one line: the dry run splits at a semicolon that ends a line.
--   VerTry0001  346-2's own model, changed: a version of it
--   VerTry0002  346-2's own model as LDraw's: a version of it, after the changed one
--   VerTry0003  built from 346-2 (whole): an alternate, never a version
--   VerTry0004  346-2's own model, a work in progress: not shown
-- The live answer first: production's own versions of 346-2 (the house's copy) and of a set with none.
select public.set_versions('346-2') as "346-2 live", public.set_versions('346-2-NONE') as "none", public.set_versions('346-2', true) as "346-2 live tests";
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'set-versions-try@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000d1', true)->>'over_13' as ver;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published, modelled_by) values ('VerTry0001', '00000000-0000-4000-8000-0000000000d1', 'My House with Car', 'Ver Try', 150, 100, true, now() - interval '3 days', true, true, '{"name": "Marc Giraudet", "page": "https://library.ldraw.org/omr/sets/1024", "changed": true}'), ('VerTry0002', '00000000-0000-4000-8000-0000000000d1', '346-2 House with Car', 'Ver Try', 151, 100, true, now() - interval '1 day', true, true, '{"name": "Marc Giraudet", "page": "https://library.ldraw.org/omr/sets/1024"}'), ('VerTry0003', '00000000-0000-4000-8000-0000000000d1', 'A shed', 'Ver Try', 40, 100, true, now() - interval '2 days', true, true, null), ('VerTry0004', '00000000-0000-4000-8000-0000000000d1', 'House, going', 'Ver Try', 120, 100, true, now() - interval '2 days', true, true, '{"name": "Marc Giraudet", "page": "https://library.ldraw.org/omr/sets/1024", "changed": true}');
update public.shared_models set wip_at = now() where id = 'VerTry0004';
select public.alt_keep('VerTry0001', 150, 1, false, '[{"set": "346-2", "role": "own", "n": 0, "have": 140}]') as "1", public.alt_keep('VerTry0002', 151, 1, false, '[{"set": "346-2", "role": "own", "n": 0, "have": 151}]') as "2", public.alt_keep('VerTry0003', 40, 1, false, '[{"set": "346-2", "role": "whole", "n": 0, "have": 40}]') as "3", public.alt_keep('VerTry0004', 120, 1, false, '[{"set": "346-2", "role": "own", "n": 0, "have": 110}]') as "4";
-- Versions of 346-2 with tests: VerTry0001 (changed) first, then VerTry0002, then the house's; never VerTry0003 or VerTry0004.
select jsonb_path_query_array(public.set_versions('346-2', true), '$[*] ? (@.id like_regex "^VerTry").id') as "ours in order", jsonb_path_query_array(public.set_versions('346-2', true), '$[*].changed') as "changed", jsonb_path_query_array(public.set_versions('346-2', true), '$[*].pieces') as "pieces", jsonb_array_length(public.set_versions('346-2', true)) as "all";
-- Without tests, none of ours: they are test models.
select jsonb_path_query_array(public.set_versions('346-2'), '$[*] ? (@.id like_regex "^VerTry").id') as "ours without tests";
-- The alternate is still set_built's, and no version is.
select jsonb_path_query_array(public.set_built('346-2', true), '$[*] ? (@.id like_regex "^VerTry").id') as "built from it";
