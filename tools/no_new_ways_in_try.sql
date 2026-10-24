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
-- Deleting an account: allowed.
select pg_temp.tries($q$delete from auth.users where id in ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000f2')$q$) as deleted;
