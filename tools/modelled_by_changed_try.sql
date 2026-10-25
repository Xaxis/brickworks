-- What supabase/modelled_by_changed.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/modelled_by_changed.sql --dry --try=tools/modelled_by_changed_try.sql --table=shared_models
--
-- One made-up account at a Resend test address and one test model, made
-- and gone with the transaction. Each statement is on one line: the dry
-- run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000007c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'modelled-changed-try@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000007c1', true)->>'over_13' as "13 or over";
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test) values ('ChangeTry1', '00000000-0000-4000-8000-0000000007c1', 'Try castle', 'Try House', 3, 100, true, now(), true);
-- What it allowed before, and changed: true; never changed: false, a word, or another key.
select pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034"}' where id = 'ChangeTry1'$q$) as "name and page", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034", "changed": true}' where id = 'ChangeTry1'$q$) as "changed", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034", "changed": false}' where id = 'ChangeTry1'$q$) as "changed false", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034", "changed": "yes"}' where id = 'ChangeTry1'$q$) as "changed a word", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034", "x": 1}' where id = 'ChangeTry1'$q$) as "another key", pg_temp.tries($q$update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://example.com/1034"}' where id = 'ChangeTry1'$q$) as "a page elsewhere", pg_temp.tries($q$update public.shared_models set modelled_by = '{"page": "https://library.ldraw.org/omr/sets/1034"}' where id = 'ChangeTry1'$q$) as "no name", pg_temp.tries($q$update public.shared_models set modelled_by = '{"page": "https://library.ldraw.org/omr/sets/1034", "changed": true}' where id = 'ChangeTry1'$q$) as "no name, two keys";
update public.shared_models set modelled_by = '{"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034", "changed": true}' where id = 'ChangeTry1';
select public.directory_card(m)->'modelled_by' as "the card's modelled_by" from public.shared_models m where m.id = 'ChangeTry1';
-- Every row there was still passes the check, and nobody else may run it.
select count(*) filter (where not public.modelled_by_ok(modelled_by)) as "rows the check now refuses", count(*) as "rows" from public.shared_models;
select has_function_privilege('anon', 'public.modelled_by_ok(jsonb)', 'execute') as "anon may run the check", has_function_privilege('service_role', 'public.modelled_by_ok(jsonb)', 'execute') as "the server may"
