-- What supabase/no_new_ways_in.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/no_new_ways_in.sql --dry --try=tools/no_new_ways_in_try.sql --table=profiles
--
-- Made-up accounts, made and gone with the transaction: a person, and a
-- test account at a Resend test address, each made with a password hash as
-- Supabase makes every account. Each statement is on one line: the dry run
-- splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nnwi-person@example.invalid', 'made-random'), ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'delivered+nnwi-test@resend.dev', 'made-random');
-- An account is made with a hash, as before.
select (select count(*) from auth.users where id in ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000f2')) as made;
-- A person's password: refused; the same hash written again, or nothing about it: allowed.
select pg_temp.tries($q$update auth.users set encrypted_password = 'chosen' where id = '00000000-0000-4000-8000-0000000000f1'$q$) as person_password, pg_temp.tries($q$update auth.users set encrypted_password = 'made-random', last_sign_in_at = now() where id = '00000000-0000-4000-8000-0000000000f1'$q$) as person_same_hash, pg_temp.tries($q$update auth.users set last_sign_in_at = now(), raw_app_meta_data = '{"orangecheck": true}' where id = '00000000-0000-4000-8000-0000000000f1'$q$) as person_sign_in_and_mark;
-- A test account's password: allowed.
select pg_temp.tries($q$update auth.users set encrypted_password = 'test-password' where id = '00000000-0000-4000-8000-0000000000f2'$q$) as test_password;
-- An address changed, or a change asked for: refused, for both; a change asked for cleared: allowed.
select pg_temp.tries($q$update auth.users set email = 'elsewhere@example.invalid' where id = '00000000-0000-4000-8000-0000000000f1'$q$) as person_address, pg_temp.tries($q$update auth.users set email_change = 'elsewhere@example.invalid' where id = '00000000-0000-4000-8000-0000000000f1'$q$) as person_change_asked, pg_temp.tries($q$update auth.users set email = 'delivered+nnwi-other@resend.dev' where id = '00000000-0000-4000-8000-0000000000f2'$q$) as test_address, pg_temp.tries($q$update auth.users set email_change = '' where id = '00000000-0000-4000-8000-0000000000f1'$q$) as change_cleared;
select encrypted_password = 'made-random' as person_hash_kept, email = 'nnwi-person@example.invalid' as person_address_kept from auth.users where id = '00000000-0000-4000-8000-0000000000f1';
-- Signing in: by a code, allowed; by a password, refused, but for the test account; a second factor, refused.
insert into auth.sessions (id, user_id, created_at, updated_at) values ('00000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-8000-0000000000f1', now(), now()), ('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000f2', now(), now());
select pg_temp.tries($q$insert into auth.mfa_amr_claims (id, session_id, created_at, updated_at, authentication_method) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000a1', now(), now(), 'otp')$q$) as person_by_code, pg_temp.tries($q$insert into auth.mfa_amr_claims (id, session_id, created_at, updated_at, authentication_method) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000a1', now(), now(), 'password')$q$) as person_by_password, pg_temp.tries($q$insert into auth.mfa_amr_claims (id, session_id, created_at, updated_at, authentication_method) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000a2', now(), now(), 'password')$q$) as test_by_password;
select pg_temp.tries($q$update auth.mfa_amr_claims set authentication_method = 'password' where session_id = '00000000-0000-4000-8000-0000000000a1'$q$) as person_code_made_password;
select pg_temp.tries($q$insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at) values (gen_random_uuid(), '00000000-0000-4000-8000-0000000000f1', 'try', 'totp', 'unverified', now(), now())$q$) as second_factor;
-- An account as public sign-up makes one, refused when its making commits (checked here at once); as Brickworks makes one, allowed.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_user_meta_data) values ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nnwi-signup@example.invalid', 'chosen', '{"sub": "x", "email": "nnwi-signup@example.invalid", "email_verified": true, "phone_verified": false}'), ('00000000-0000-4000-8000-0000000000f4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nnwi-made@example.invalid', 'made-random', '{"email_verified": true}');
select pg_temp.tries('set constraints all immediate') as public_sign_up;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f3';
-- A public sign-up at a test address: refused as well.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, raw_user_meta_data) values ('00000000-0000-4000-8000-0000000000f5', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'delivered+nnwi-signup@resend.dev', 'chosen', '{"sub": "y", "email": "delivered+nnwi-signup@resend.dev", "email_verified": true, "phone_verified": false}');
select pg_temp.tries('set constraints all immediate') as public_sign_up_at_a_test_address;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000f5';
select pg_temp.tries('set constraints all immediate') as brickworks_made, (select count(*) from auth.users where id = '00000000-0000-4000-8000-0000000000f4') as made_kept;
-- Deleting an account: allowed.
select pg_temp.tries($q$delete from auth.users where id in ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000f2')$q$) as deleted;
