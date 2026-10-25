-- What supabase/modelled_by.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/modelled_by.sql --dry --try=tools/modelled_by_try.sql --table=shared_models
--
-- One made-up account at a Resend test address (made and gone with the
-- transaction) sharing one test model. Each statement is on one line: the
-- dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000007b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'modelled-by-try@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000007b1', true)->>'over_13' as "13 or over";
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test) values ('ModelTry01', '00000000-0000-4000-8000-0000000007b1', 'Try castle', 'Try House', 3, 100, true, now(), true);
-- The licence's check, as it is now: one, the four licences.
select count(*) as "checks on the licence", string_agg(pg_get_constraintdef(c.oid), ' | ') as "the check" from pg_constraint c where c.conrelid = 'public.shared_models'::regclass and c.contype = 'c' and pg_get_constraintdef(c.oid) like '%licence%';
-- CC BY 2.0 allowed, the three before still allowed, anything else refused.
select pg_temp.tries($q$update public.shared_models set licence = 'cc-by-2.0' where id = 'ModelTry01'$q$) as "cc-by-2.0", pg_temp.tries($q$update public.shared_models set licence = 'cc-by-4.0' where id = 'ModelTry01'$q$) as "cc-by-4.0", pg_temp.tries($q$update public.shared_models set licence = 'all-rights-reserved' where id = 'ModelTry01'$q$) as "all rights reserved", pg_temp.tries($q$update public.shared_models set licence = 'cc-by-nc-4.0' where id = 'ModelTry01'$q$) as "cc-by-nc-4.0";
-- Whom the file credits: a name and an LDraw page, nothing else.
select pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034"}' where id = 'ModelTry01'$q$) as "a name and its page", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://example.com/x"}' where id = 'ModelTry01'$q$) as "a page elsewhere", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "", "page": "https://library.ldraw.org/omr/sets/1"}' where id = 'ModelTry01'$q$) as "no name", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "A", "page": "https://library.ldraw.org/omr/sets/1", "x": 1}' where id = 'ModelTry01'$q$) as "a key more", pg_temp.tries($q$update public.shared_models set modelled_by = '"Stefan Frenz"' where id = 'ModelTry01'$q$) as "a string";
update public.shared_models set licence = 'cc-by-2.0', modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034"}' where id = 'ModelTry01';
-- The card and the page say it.
select public.directory_card(m)->'modelled_by' as "the card's modelled_by", public.directory_card(m)->>'licence' as "the card's licence" from public.shared_models m where m.id = 'ModelTry01';
select public.directory_model('ModelTry01')->'modelled_by' as "the page's modelled_by";
-- A model nobody else made says null, as every model does now.
select count(*) filter (where public.directory_card(m)->'modelled_by' <> 'null'::jsonb) as "other cards with modelled_by", count(*) as "cards" from public.shared_models m where m.id <> 'ModelTry01';
-- Nobody but the server: the publishable key's roles have no way in.
select has_column_privilege('anon', 'public.shared_models', 'modelled_by', 'select') as "anon may read modelled_by", has_column_privilege('authenticated', 'public.shared_models', 'modelled_by', 'update') as "authenticated may write it", has_function_privilege('anon', 'public.modelled_by_ok(jsonb)', 'execute') as "anon may run the check", has_function_privilege('anon', 'public.directory_card(public.shared_models)', 'execute') as "anon may ask directory_card", has_column_privilege('service_role', 'public.shared_models', 'modelled_by', 'update') as "the server may write it"
