-- What supabase/model_bases.sql does, tried inside the rolled-back transaction of a
-- dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/model_bases.sql --dry --try=tools/model_bases_try.sql --table=model_bases
--
-- Made-up accounts, made and gone with the transaction, at Resend test addresses: Ivy designs, Jon is
-- somebody else, Kit said she is under 13. Every model a test model. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mb-ivy@resend.dev'), ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mb-jon@resend.dev'), ('00000000-0000-4000-8000-0000000000b3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mb-kit@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000b1', true)->>'over_13' as ivy, public.answer_age('00000000-0000-4000-8000-0000000000b2', true)->>'over_13' as jon, public.answer_age('00000000-0000-4000-8000-0000000000b3', false)->>'over_13' as kit;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, published) values ('MbTry00001', '00000000-0000-4000-8000-0000000000b1', 'MB castle', 'Ivy Bases', 40, 100, true, now(), true, true), ('MbTry00002', '00000000-0000-4000-8000-0000000000b1', 'MB tower', 'Ivy Bases', 30, 100, false, null, true, true), ('MbTry00003', '00000000-0000-4000-8000-0000000000b3', 'MB hut', null, 30, 100, false, null, true, true);
-- Ivy's castle: an alternate build of 6080-1, and changed from a work elsewhere, with its author and licence.
select public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00001', '[{"how": "alternate", "set": "6080-1"}, {"how": "changed", "url": "https://example.org/castle", "title": "  A   castle ", "author": "Someone", "licence": "CC BY 4.0"}]') as "put";
select b.n, b.how, b.set_number, b.url, b.title, b.author, b.licence from public.model_bases_of(array['MbTry00001', 'MbTry00002']) b;
-- Its set's page lists it; a visitor's (no test models) does not; another set lists nothing.
select jsonb_array_length(public.set_based('6080-1', true)) as "6080-1, tests", public.set_based('6080-1', true)->0->>'id' as id, public.set_based('6080-1', true)->0->>'based' as based, jsonb_array_length(public.set_based('6080-1', false)) as "a visitor's", public.set_based('10497-1', true) as "another set";
-- The tower, not in the gallery, is based on the set too: its own page says so, the set's page does not list it.
select public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00002', '[{"how": "inspired", "set": "6080-1"}]') as "put";
select jsonb_array_length(public.set_based('6080-1', true)) as "still one listed", (select count(*) from public.model_bases where lower(set_number) = '6080-1') as "based on it";
-- The whole list each time: one now, then none.
-- (A statement reads what the one before it wrote, not what it writes itself.)
select public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00001', '[{"how": "inspired", "url": "https://example.org/other", "title": "Other"}]') as "one";
select count(*) as "rows" from public.model_bases where model = 'MbTry00001';
select public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00001', '[]') as "none";
select count(*) as "rows" from public.model_bases where model = 'MbTry00001';
-- Refused: not hers, under 13, too many, not a list, no such model.
select public.model_bases_put('00000000-0000-4000-8000-0000000000b2', 'MbTry00001', '[]') as "jon", public.model_bases_put('00000000-0000-4000-8000-0000000000b3', 'MbTry00003', '[]') as "kit", public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00001', '[{}, {}, {}, {}]') as "four", public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00001', '{}') as "object", public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'NoSuchOne1', '[]') as "nothing";
-- Kept back by the table: an alternate build of a work elsewhere, a link with no title, a link not https, both a set and a link.
do $$ declare said text := ''; one jsonb; begin foreach one in array array['{"how": "alternate", "url": "https://example.org/x", "title": "X"}', '{"how": "changed", "url": "https://example.org/x"}', '{"how": "changed", "url": "http://example.org/x", "title": "X"}', '{"how": "changed", "set": "6080-1", "url": "https://example.org/x", "title": "X"}', '{"how": "copied", "set": "6080-1"}']::jsonb[] loop begin perform public.model_bases_put('00000000-0000-4000-8000-0000000000b1', 'MbTry00001', jsonb_build_array(one)); said := said || ' kept'; exception when others then said := said || ' refused'; end; end loop; perform set_config('mb.said', said, true); end $$;
select current_setting('mb.said') as "each bad base";
-- The tower's list was never touched by a refused one.
select count(*) as "tower's" from public.model_bases where model = 'MbTry00002';
-- A model deleted takes its list with it.
delete from public.shared_models where id = 'MbTry00002';
select count(*) as "left" from public.model_bases where model = 'MbTry00002';
-- Nobody but the server runs any of it, or reads the table.
select r.rolname, p.proname from pg_proc p cross join (values ('anon'), ('authenticated')) r(rolname) where p.pronamespace = 'public'::regnamespace and p.proname in ('model_bases_put', 'model_bases_of', 'set_based') and has_function_privilege(r.rolname, p.oid, 'execute');
select count(*) as "the service role runs" from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('model_bases_put', 'model_bases_of', 'set_based') and has_function_privilege('service_role', p.oid, 'execute');
select has_table_privilege('anon', 'public.model_bases', 'select') as anon_reads, has_table_privilege('authenticated', 'public.model_bases', 'select') as signed_in_reads, has_table_privilege('service_role', 'public.model_bases', 'select') as service_reads, (select relrowsecurity from pg_class where oid = 'public.model_bases'::regclass) as row_security
