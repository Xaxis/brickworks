-- What supabase/drop_no_public_sign_up.sql does, tried inside the
-- rolled-back transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/apply_sql.mjs \
--     supabase/drop_no_public_sign_up.sql --dry --try=tools/drop_no_public_sign_up_try.sql --table=canary_runs
--
-- Made-up accounts, made and gone with the transaction. Each statement is
-- on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
-- The triggers left, and the function gone.
select string_agg(t.tgname || ' on ' || t.tgrelid::regclass::text, ', ' order by t.tgname) as triggers_left from pg_trigger t where t.tgname in ('no_new_ways_in', 'no_password_sign_in', 'no_second_factor', 'no_public_sign_up');
select count(*) as no_public_sign_up_functions from pg_proc where proname = 'auth_users_no_public_sign_up';
-- An account as public sign-up made one is no longer refused as it commits (Supabase's disable_signup refuses the sign-up itself).
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_user_meta_data) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dnps-signup@example.invalid', 'chosen', '{"sub": "x", "email": "dnps-signup@example.invalid", "email_verified": true, "phone_verified": false}'), ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dnps-person@example.invalid', 'made-random', '{"email_verified": true}');
select pg_temp.tries('set constraints all immediate') as public_sign_up_shaped_account;
-- What stays refused: a person's password set, their address changed, a sign-in by password, a second factor.
select pg_temp.tries($q$update auth.users set encrypted_password = 'chosen' where id = '00000000-0000-4000-8000-0000000000e2'$q$) as person_password, pg_temp.tries($q$update auth.users set email = 'elsewhere@example.invalid' where id = '00000000-0000-4000-8000-0000000000e2'$q$) as person_address;
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-0000000000b1', '00000000-0000-4000-8000-0000000000e2', now(), now());
select pg_temp.tries($q$insert into auth.mfa_amr_claims (id, session_id, created_at, updated_at, authentication_method) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000b1', now(), now(), 'otp')$q$) as person_by_code, pg_temp.tries($q$insert into auth.mfa_amr_claims (id, session_id, created_at, updated_at, authentication_method) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000b1', now(), now(), 'password')$q$) as person_by_password;
select pg_temp.tries($q$insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000e2', 'try', 'totp', 'unverified', now(), now())$q$) as second_factor;
