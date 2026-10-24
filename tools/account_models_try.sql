-- What supabase/account_models.sql does, read back inside the rolled-back
-- transaction of a dry run, after the file has run twice: nothing here is
-- kept. The saves are the shared test account's.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/account_models.sql --dry --again=supabase/account_models.sql \
--       --try=tools/account_models_try.sql --table=account_models
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
-- A first save: version 1.
select public.save_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Castle', 0, 'H4sIAAAA-one', 100, 3, repeat('a', 64)) as "first save";
-- The same model saved again: nothing new.
select public.save_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Castle', 1, 'H4sIAAAA-one', 100, 3, repeat('a', 64)) as "saved again as it was";
-- A save made from version 1: version 2.
select public.save_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Castle', 1, 'H4sIAAAA-two', 120, 4, repeat('b', 64)) as "a save of version 1";
-- Another save made from version 1, elsewhere: kept beside it, never over it.
select public.save_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Castle', 1, 'H4sIAAAA-three', 130, 5, repeat('c', 64)) as "a second save of version 1";
-- That one sent again: the copy kept already, not a third.
select public.save_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Castle', 1, 'H4sIAAAA-three', 130, 5, repeat('c', 64)) as "sent again";
-- Both versions are there, each whole.
select name, version, model, parts from public.account_models where owner = (select id from auth.users where email = 'delivered+brickworks-tests@resend.dev') and name like 'Try Castle%' order by name;
-- The table's checks: a name of one line and 1 to 60 characters, the sizes, the sum.
select (select count(*) from public.account_models) >= 0 as "table readable", (select pg_catalog.count(*) from pg_catalog.pg_constraint where conrelid = 'public.account_models'::regclass) as constraints;
-- Nothing for the keys a page holds: no table privilege, no function, no policy.
select has_table_privilege('anon', 'public.account_models', 'select') as anon_select, has_table_privilege('authenticated', 'public.account_models', 'select,insert,update,delete') as authenticated_any, has_function_privilege('anon', 'public.save_account_model(uuid, text, integer, text, integer, integer, text)', 'execute') as anon_run, has_function_privilege('authenticated', 'public.save_account_model(uuid, text, integer, text, integer, integer, text)', 'execute') as authenticated_run, has_function_privilege('service_role', 'public.save_account_model(uuid, text, integer, text, integer, integer, text)', 'execute') as server_runs, (select count(*) from pg_policies where tablename = 'account_models') as policies, (select relrowsecurity from pg_class where oid = 'public.account_models'::regclass) as row_security;
-- How much an account may keep, last because it ends the run: seventeen models of 4 MB are more than its 64 MB, and the dry run stops on "models: too big".
select g as saved, public.save_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Big ' || g, 0, repeat('x', 4194304), 4194304, 1, lpad(to_hex(g), 64, '0')) ->> 'name' as name from generate_series(1, 17) g;
