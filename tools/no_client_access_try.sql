-- What supabase/no_client_access.sql does, tried inside the rolled-back
-- transaction of a dry run, after client_exposure.sql: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/client_exposure.sql --dry --again=supabase/no_client_access.sql \
--       --try=tools/no_client_access_try.sql --table=profiles
--
-- Each statement is on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- Made after the file's defaults, so nobody but postgres may run it unless told: the defaults at work.
grant execute on function pg_temp.tries(text) to public;
-- What is left for the keys a page holds: shared_models' published read alone, which no_client_access_models.sql takes.
select jsonb_array_elements_text(public.client_exposure()->'bad') as left_over;
-- As anon and as a session: no table, no column, no function.
set local role anon;
select pg_temp.tries('select 1 from public.profiles limit 1') as anon_profiles, pg_temp.tries('select 1 from public.otp_requests limit 1') as anon_otp_requests, pg_temp.tries($q$select public.directory_tags_ok(array['castle'])$q$) as anon_tags_ok, pg_temp.tries($q$select public.may_ask_for_code('x@example.invalid', '203.0.113.1')$q$) as anon_ask_for_code;
reset role;
set local role authenticated;
select pg_temp.tries('select 1 from public.collections limit 1') as session_collections, pg_temp.tries('select 1 from public.assistant_designs limit 1') as session_designs, pg_temp.tries($q$select public.directory_words('a', 'b', 'c', array['d'])$q$) as session_words;
reset role;
-- The server keeps all it had.
set local role service_role;
select pg_temp.tries('select 1 from public.profiles limit 1') as server_profiles, pg_temp.tries('select 1 from public.collections limit 1') as server_collections, pg_temp.tries($q$select public.directory_tags_ok(array['castle'])$q$) as server_tags_ok, pg_temp.tries($q$select public.oc_account_of('did:oc:' || repeat('a', 32))$q$) as server_rpc;
reset role;
-- Supabase's auth role still makes an account, and its profile with it.
select pg_temp.tries('set local role supabase_auth_admin') as can_be_auth;
select pg_temp.tries($q$insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nca-try@example.invalid', 'made-random')$q$) as account_made;
reset role;
select (select count(*) from public.profiles where id = '00000000-0000-4000-8000-0000000000c1') as its_profile;
