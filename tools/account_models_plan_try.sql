-- What supabase/account_models_plan.sql does, read back inside the
-- rolled-back transaction of a dry run: nothing here is kept. The saves
-- are the shared test account's, under a plan that keeps two more models
-- than it has (the "most" each line works out).
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/account_models_plan.sql --dry \
--       --try=tools/account_models_plan_try.sql --table=account_models
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
-- Two new models, each within the plan: version 1.
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan A', 0, 'H4sIAAAA-a', 100, 3, repeat('a', 64), (select count(*)::integer + 2 from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name not like 'Try Plan %')) as "first new model";
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan B', 0, 'H4sIAAAA-b', 100, 3, repeat('b', 64), (select count(*)::integer + 2 from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name not like 'Try Plan %')) as "second new model, the plan full";
-- At the plan's limit, a save over a model it has: kept, version 2.
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan A', 1, 'H4sIAAAA-a2', 110, 4, repeat('c', 64), (select count(*)::integer + 2 from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name not like 'Try Plan %')) as "an update at the limit";
-- And the same model sent again: kept already, nothing new.
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan B', 1, 'H4sIAAAA-b', 100, 3, repeat('b', 64), (select count(*)::integer + 2 from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name not like 'Try Plan %')) as "the same again at the limit";
-- No limit (a plan without one is never asked this way, but null is no limit).
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan Free Of It', 0, 'H4sIAAAA-n', 100, 3, repeat('e', 64), null) as "no limit";
select public.delete_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan Free Of It', 1) as "deleted again";
-- A model deleted makes room at once: a new one is kept in its place.
select public.delete_account_model((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan A', 2) as "one deleted";
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan C', 0, 'H4sIAAAA-c', 100, 3, repeat('d', 64), (select count(*)::integer + 2 from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name not like 'Try Plan %')) as "a new one in its place";
select name, version from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name like 'Try Plan %' order by name;
-- Nothing for the keys a page holds.
select has_function_privilege('anon', 'public.save_account_model_within(uuid, text, integer, text, integer, integer, text, integer)', 'execute') as anon_run, has_function_privilege('authenticated', 'public.save_account_model_within(uuid, text, integer, text, integer, integer, text, integer)', 'execute') as authenticated_run, has_function_privilege('service_role', 'public.save_account_model_within(uuid, text, integer, text, integer, integer, text, integer)', 'execute') as server_runs;
-- Last, because it ends the run: a third new model past the plan's limit, refused with "models: plan" and taken back.
select public.save_account_model_within((select id from auth.users where email = 'delivered+brickworks-tests@resend.dev'), 'Try Plan D', 0, 'H4sIAAAA-d', 100, 3, repeat('f', 64), (select count(*)::integer + 2 from public.account_models m join auth.users u on u.id = m.owner where u.email = 'delivered+brickworks-tests@resend.dev' and m.name not like 'Try Plan %')) as "past the plan";
