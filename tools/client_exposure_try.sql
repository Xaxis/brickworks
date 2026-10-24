-- What supabase/client_exposure.sql reads, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/client_exposure.sql --dry --try=tools/client_exposure_try.sql --table=profiles
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
select jsonb_array_length(public.client_exposure()->'bad') as bad, jsonb_array_length(public.client_exposure()->'tables') as tables, jsonb_array_length(public.client_exposure()->'functions') as functions;
select jsonb_array_elements_text(public.client_exposure()->'bad') as line;
select x->>'name' as name, x->'args' as args, x->'named' as named from jsonb_array_elements(public.client_exposure()->'functions') x where x->>'name' in ('directory_words', 'oc_bind_session', 'client_exposure', 'on_auth_user_created');
set local role anon;
select pg_temp.tries('select public.client_exposure()') as anon_reads_it;
reset role;
set local role service_role;
select pg_temp.tries('select public.client_exposure()') as server_reads_it;
reset role;
