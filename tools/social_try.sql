-- What supabase/social.sql does, tried inside the rolled-back transaction of
-- a dry run: nothing here is kept. Only names, counts and refusals are
-- printed, never a row of anybody's.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/social.sql --dry --try=tools/social_try.sql
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
-- The tables: row security on, no policy, and no role but the server's reaching any.
select c.relname as table_name, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select,insert,update,delete') as server_writes from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname like 'social\_%' and c.relkind = 'r' order by c.relname;
-- Nothing names an account of the site, so no account's export (admin_export) reaches the desk.
select count(*) as foreign_keys_to_accounts from pg_constraint c join pg_class r on r.oid = c.conrelid where r.relname like 'social\_%' and c.contype = 'f' and c.confrelid = 'auth.users'::regclass;
-- A refusal, caught: the constraint's name, or 'kept'.
create function pg_temp.tried(statement text) returns text language plpgsql as $$ begin execute statement; return 'kept'; exception when others then return coalesce(nullif((regexp_match(sqlerrm, 'constraint "([a-z_]+)"'))[1], ''), sqlerrm); end $$;
-- A draft is kept; a send past a draft without the owner's press is refused, scheduled or sent.
select pg_temp.tried($q$insert into public.social_sends (id, provider, test, kind, community, title, body) values ('trydraft01', 'reddit', true, 'post', 'lego', 'A title', 'Words')$q$) as draft, pg_temp.tried($q$insert into public.social_sends (id, provider, test, kind, community, title, status, send_at) values ('trysched01', 'reddit', true, 'post', 'lego', 't', 'scheduled', now())$q$) as scheduled_without_press, pg_temp.tried($q$update public.social_sends set status = 'sent', sent_at = now(), url = 'https://www.reddit.com/r/lego/' where id = 'trydraft01'$q$) as sent_without_press, pg_temp.tried($q$insert into public.social_sends (id, provider, test, kind, community, title, status, send_at, pressed_at, pressed_by, pressed_hash, route) values ('trysched02', 'reddit', true, 'post', 'lego', 't', 'scheduled', now() + interval '1 hour', now(), 'the owner', repeat('a', 64), 'api')$q$) as scheduled_pressed;
-- A visit counts once a landing, and only for a send that is there; a token goes with its account.
select pg_temp.tried($q$insert into public.social_visits (send, nonce, path, source) values ('trydraft01', 'abcdefgh1234', '/gallery', 'reddit')$q$) as visit, pg_temp.tried($q$insert into public.social_visits (send, nonce) values ('nosuchsend', 'abcdefgh1234')$q$) as visit_of_nothing, pg_temp.tried($q$insert into public.social_tokens (provider, test, access_token) values ('reddit', true, 'x')$q$) as token_without_account;
-- How the console's reads go on an empty desk: the section's three, timed by the planner.
explain (costs off) select provider, external_id, kind from public.social_items where test = false order by made_at desc limit 300;
explain (costs off) select id, status from public.social_sends where status = 'scheduled' and route = 'api' order by send_at limit 50;
