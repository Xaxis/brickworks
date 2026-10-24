-- What supabase/no_client_access_models.sql does, tried inside the
-- rolled-back transaction of a dry run, after no_client_access.sql is
-- applied: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/no_client_access_models.sql --dry --try=tools/no_client_access_models_try.sql --table=shared_models
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to public;
-- Nothing left for the keys a page holds.
select jsonb_array_length(public.client_exposure()->'bad') as bad_left;
set local role anon;
select pg_temp.tries('select id, name from public.shared_models where published limit 1') as anon_published_row;
reset role;
set local role service_role;
select pg_temp.tries('select id, name from public.shared_models where published limit 1') as server_published_row;
reset role;
