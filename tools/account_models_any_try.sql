-- What supabase/account_models_any.sql does, read back inside the
-- rolled-back transaction of a dry run: nothing here is kept. The saves
-- are the shared test account's, as a plan that keeps any number saves.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/account_models_any.sql --dry \
--       --try=tools/account_models_any_try.sql --table=account_models
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
-- A new model: version 1; a save over it: version 2; the same again: nothing new.
select public.save_account_model_any((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Any A', 0, 'H4sIAAAA-a', 100, 3, repeat('a', 64)) as "a new model";
select public.save_account_model_any((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Any A', 1, 'H4sIAAAA-a2', 110, 4, repeat('b', 64)) as "a save over it";
select public.save_account_model_any((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Any A', 2, 'H4sIAAAA-a2', 110, 4, repeat('b', 64)) as "the same again";
-- Made from an older version: kept beside it, as save_account_model does.
select public.save_account_model_any((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Any A', 1, 'H4sIAAAA-a3', 120, 5, repeat('c', 64)) as "from an older version";
-- Past save_account_model's 500 in all: 520 more, every one kept.
select count(*) filter (where (public.save_account_model_any(u.id, 'Try Any ' || g, 0, 'H4sIAAAA-' || g, 100, 3, encode(sha256(convert_to('try any ' || g, 'UTF8')), 'hex')) ->> 'version') = '1') as "of 520 new models, kept" from auth.users u, generate_series(1, 520) g where u.email = 'delivered+brickworks-tests@resend.dev';
select count(*) as "the account's models now" from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev';
-- Nothing for the keys a page holds.
select has_function_privilege('anon', 'public.save_account_model_any(uuid, text, integer, text, integer, integer, text)', 'execute') as anon_run, has_function_privilege('authenticated', 'public.save_account_model_any(uuid, text, integer, text, integer, integer, text)', 'execute') as authenticated_run, has_function_privilege('service_role', 'public.save_account_model_any(uuid, text, integer, text, integer, integer, text)', 'execute') as server_runs;
-- Last, because it ends the run: 500 more in the same hour go past the guard of 1,000, refused with "models: too fast" and taken back.
select count(*) from auth.users u, generate_series(521, 1020) g where u.email = 'delivered+brickworks-tests@resend.dev' and public.save_account_model_any(u.id, 'Try Any ' || g, 0, 'H4sIAAAA-' || g, 100, 3, encode(sha256(convert_to('try any ' || g, 'UTF8')), 'hex')) is not null;
