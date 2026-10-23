-- What supabase/avatars.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/avatars.sql --dry --try=tools/avatars_try.sql --table=profile_avatars
--
-- Made-up accounts, made and gone with the transaction: Ada is 13 or over
-- with a profile, Cy is under 13, Di was never asked. Each statement is on
-- one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000006a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'avatars-ada@resend.dev'), ('00000000-0000-4000-8000-0000000006a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'avatars-cy@resend.dev'), ('00000000-0000-4000-8000-0000000006a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'avatars-di@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000006a1', true)->>'over_13' as ada, public.answer_age('00000000-0000-4000-8000-0000000006a2', false)->>'over_13' as cy;
insert into public.people (account, handle, name) values ('00000000-0000-4000-8000-0000000006a1', 'avatars-try-ada', 'Ada Try');
-- Ada's picture, and what avatars_of says of her and of a handle nobody has.
select pg_temp.tries($q$insert into public.profile_avatars (account, id, side, bytes, was) values ('00000000-0000-4000-8000-0000000006a1', 'AvatarTry1', 400, 52000, 'png')$q$) as "Ada's picture";
select handle, avatar from public.avatars_of(array['avatars-try-ada', 'nobody-has-this']);
-- What the table refuses, whatever writes it.
select pg_temp.tries($q$update public.profile_avatars set id = 'short' where account = '00000000-0000-4000-8000-0000000006a1'$q$) as "an id not one", pg_temp.tries($q$update public.profile_avatars set side = 401 where account = '00000000-0000-4000-8000-0000000006a1'$q$) as "401 a side", pg_temp.tries($q$update public.profile_avatars set side = 119 where account = '00000000-0000-4000-8000-0000000006a1'$q$) as "119 a side", pg_temp.tries($q$update public.profile_avatars set bytes = 1048577 where account = '00000000-0000-4000-8000-0000000006a1'$q$) as "over 1 MB", pg_temp.tries($q$update public.profile_avatars set was = 'gif' where account = '00000000-0000-4000-8000-0000000006a1'$q$) as "a gif";
-- 13 or over, as a profile: Cy (under 13) and Di (never asked) are refused, a picture and a choice alike.
select pg_temp.tries($q$insert into public.profile_avatars (account, id, side, bytes, was) values ('00000000-0000-4000-8000-0000000006a2', 'AvatarTry2', 400, 1000, 'jpeg')$q$) as "Cy's picture", pg_temp.tries($q$insert into public.profile_avatars (account, id, side, bytes, was) values ('00000000-0000-4000-8000-0000000006a3', 'AvatarTry3', 400, 1000, 'jpeg')$q$) as "Di's picture", pg_temp.tries($q$insert into public.profile_choices (account, shows_likes) values ('00000000-0000-4000-8000-0000000006a2', true)$q$) as "Cy's choice";
-- Taken out by the site's owner: avatars_of says nothing of her.
update public.profile_avatars set removed_at = now(), removed_why = 'Taken out by Brickworks' where account = '00000000-0000-4000-8000-0000000006a1';
select count(*) as "avatars_of after it is taken out" from public.avatars_of(array['avatars-try-ada']);
-- Her likes: off until she chooses; the models the gallery shows, as cards.
select pg_temp.tries($q$insert into public.profile_choices (account) values ('00000000-0000-4000-8000-0000000006a1')$q$) as "her choice";
select shows_likes as "shown at first" from public.profile_choices where account = '00000000-0000-4000-8000-0000000006a1';
insert into public.model_likes (model, account) select id, '00000000-0000-4000-8000-0000000006a1' from public.shared_models where published and listed and not barred order by listed_at desc limit 2;
select public.profile_likes_count('00000000-0000-4000-8000-0000000006a1', true) as "liked, with tests", (select count(*) from public.profile_likes('00000000-0000-4000-8000-0000000006a1', 25, 0, true)) as "cards", (select string_agg(c->>'id', ',') from public.profile_likes('00000000-0000-4000-8000-0000000006a1', 1, 0, true) c) as "the first card", (select count(*) from public.profile_likes('00000000-0000-4000-8000-0000000006a1', 25, 1, true)) as "cards after the first";
-- Nobody but the server: the publishable key's roles have no way in.
select has_table_privilege('anon', 'public.profile_avatars', 'select') as "anon may read pictures", has_table_privilege('authenticated', 'public.profile_choices', 'select') as "authenticated may read choices", has_function_privilege('anon', 'public.avatars_of(text[])', 'execute') as "anon may ask avatars_of", has_table_privilege('service_role', 'public.profile_avatars', 'insert') as "the server may write";
select id, public, file_size_limit, allowed_mime_types from storage.buckets where id = 'avatars';
-- Deleting the account deletes both rows.
delete from auth.users where id = '00000000-0000-4000-8000-0000000006a1';
select (select count(*) from public.profile_avatars where account = '00000000-0000-4000-8000-0000000006a1') as "her pictures after her account is deleted", (select count(*) from public.profile_choices where account = '00000000-0000-4000-8000-0000000006a1') as "her choices after"
