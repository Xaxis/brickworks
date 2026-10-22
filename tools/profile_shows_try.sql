-- What supabase/profile_shows.sql does, tried inside the rolled-back
-- transaction of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/profile_shows.sql --dry --try=tools/profile_shows_try.sql --table=profile_shows
--
-- Made-up accounts, made and gone with the transaction: Ada is 13 or over
-- with a profile, Cy is under 13, Di was never asked. Each statement is on
-- one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000005a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'shows-ada@resend.dev'), ('00000000-0000-4000-8000-0000000005a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'shows-cy@resend.dev'), ('00000000-0000-4000-8000-0000000005a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'shows-di@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000005a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000005a2', false)->>'over_13' as cy;
-- Ada's row: two https links, a banner and three pins.
select pg_temp.tries($q$insert into public.profile_shows (account, links, banner, pins) values ('00000000-0000-4000-8000-0000000005a1', array['https://robin.example/castles', 'https://www.flickr.com/photos/robin'], 'ShowsTry01', array['ShowsTry01', 'ShowsTry02', 'ShowsTry03'])$q$) as "Ada's links, banner and pins";
select links, banner, pins from public.profile_shows where account = '00000000-0000-4000-8000-0000000005a1';
-- What the table refuses, whatever writes it.
select pg_temp.tries($q$update public.profile_shows set links = array['http://robin.example'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "a link not https", pg_temp.tries($q$update public.profile_shows set links = array['https://a.example', 'https://b.example', 'https://c.example'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "three links", pg_temp.tries($q$update public.profile_shows set links = array['https://user:pw@robin.example'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "a link with a password", pg_temp.tries($q$update public.profile_shows set links = array['https://localhost/x'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "a host with no dot", pg_temp.tries($q$update public.profile_shows set links = array['javascript:alert(1)'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "javascript:";
select pg_temp.tries($q$update public.profile_shows set pins = array['ShowsTry01', 'ShowsTry02', 'ShowsTry03', 'ShowsTry04'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "four pins", pg_temp.tries($q$update public.profile_shows set pins = array['ShowsTry01', 'ShowsTry01'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "a pin twice", pg_temp.tries($q$update public.profile_shows set pins = array['short'] where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "a pin not an id", pg_temp.tries($q$update public.profile_shows set banner = 'not an id!' where account = '00000000-0000-4000-8000-0000000005a1'$q$) as "a banner not an id";
-- 13 or over, as a profile: Cy (under 13) and Di (never asked) are refused.
select pg_temp.tries($q$insert into public.profile_shows (account, links) values ('00000000-0000-4000-8000-0000000005a2', array['https://cy.example'])$q$) as "Cy, under 13", pg_temp.tries($q$insert into public.profile_shows (account, links) values ('00000000-0000-4000-8000-0000000005a3', array['https://di.example'])$q$) as "Di, never asked";
-- Nobody but the server: the publishable key's roles have no way in.
select has_table_privilege('anon', 'public.profile_shows', 'select') as "anon may read", has_table_privilege('authenticated', 'public.profile_shows', 'select') as "authenticated may read", has_table_privilege('service_role', 'public.profile_shows', 'insert') as "the server may write";
-- Deleting the account deletes the row.
delete from auth.users where id = '00000000-0000-4000-8000-0000000005a1';
select count(*) as "Ada's rows after her account is deleted" from public.profile_shows where account = '00000000-0000-4000-8000-0000000005a1';
