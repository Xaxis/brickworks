-- What supabase/console3.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept. Only counts and names are printed,
-- never a person's rows.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/console3.sql --dry --try=tools/console3_try.sql
--
-- Each statement is on one line: the dry run splits at a semicolon that
-- ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
grant execute on function pg_temp.tries(text) to anon, authenticated;
-- Nothing that was there is touched: the two tables are new and empty.
select (select count(*) from public.site_notices) as notices, (select count(*) from public.site_env) as env_names;
-- Row security, no policy; no grant to any role, the server's included.
select c.relname, c.relrowsecurity as row_security, (select count(*) from pg_policies p where p.tablename = c.relname) as policies, has_table_privilege('anon', c.oid, 'select') as anon_reads, has_table_privilege('authenticated', c.oid, 'select') as signed_in_reads, has_table_privilege('service_role', c.oid, 'select') as server_reads_directly from pg_class c where c.relname in ('site_notices', 'site_env') and c.relnamespace = 'public'::regnamespace order by 1;
-- The functions: the server's alone, each security definer.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as signed_in, has_function_privilege('service_role', p.oid, 'execute') as server, p.prosecdef as security_definer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('site_notice', 'site_notice_set', 'site_notice_clear', 'site_notices_list', 'site_settings_list', 'site_env_note', 'site_env_list', 'admin_usage', 'admin_sign_out', 'admin_export', 'admin_find', 'admin_person_more', 'challenge_admin_entries') order by p.proname;
-- A notice set on a dry run's own scope, replaced, refused without English, cleared, listed. Each read is its
-- own statement: a stable function sees the rows as its statement began.
select public.site_notice_set('dry-run', '{"en":"Dry run notice."}'::jsonb, 'warn', 'dry-run') -> 'was' as was_first;
select public.site_notice_set('dry-run', '{"en":"Dry run again.","de":"Probelauf."}'::jsonb, 'info', 'dry-run') -> 'was' is not null as replaced;
select pg_temp.tries($q$select public.site_notice_set('dry-run', '{"de":"Nur Deutsch."}'::jsonb, 'info', 'dry-run')$q$) as without_english;
select public.site_notice('dry-run') -> 'words' as showing, public.site_notice('live') is null as live_has_none;
select public.site_notice_clear('dry-run', 'dry-run') ->> 'cleared' is not null as cleared;
select public.site_notice('dry-run') is null as after_clear, jsonb_array_length(public.site_notices_list('dry-run', 10)) as history, public.site_notice_clear('dry-run', 'dry-run') -> 'cleared' as cleared_again;
-- The settings, by key only.
select jsonb_agg((s ->> 'name') || '@' || (s ->> 'scope') order by s ->> 'name', s ->> 'scope') as settings from jsonb_array_elements(public.site_settings_list()) s;
-- The variables' names written down and read back.
select public.site_env_note('[{"name":"DRY_RUN_ONE","environments":["production"]},{"name":"DRY_RUN_ONE","environments":["production"]},{"name":"DRY_RUN_TWO","environments":["preview","production"]}]'::jsonb) as noted;
select public.site_env_list() -> 'vars' as written_down;
select pg_temp.tries($q$select public.site_env_note('[{"name":"lower","environments":[]}]'::jsonb)$q$) as bad_name;
-- What the project uses: the database's size, its biggest tables, storage by bucket.
select pg_size_pretty((u ->> 'database')::bigint) as database, jsonb_array_length(u -> 'tables') as tables_listed, (select jsonb_agg(b ->> 'bucket' order by b ->> 'bucket') from jsonb_array_elements(u -> 'buckets') b) as buckets from (select public.admin_usage() as u) x;
-- Sign-out of an account that is not there: nothing ended, on Supabase's own tables.
select public.admin_sign_out('00000000-0000-4000-8000-000000000000') as signed_out;
-- An export of the account with the most models, kept in a temporary table for the reads after: the tables it found,
-- how many rows, how big, never the rows themselves. Its connector tabs' tool lists are 110 KB each.
create temporary table dry_export on commit drop as select public.admin_export((select owner from public.shared_models group by owner order by count(*) desc limit 1)) as e;
select (select jsonb_agg(k order by k) from jsonb_object_keys(e -> 'tables') k) as tables_found, (select sum(jsonb_array_length(v)) from jsonb_each(e -> 'tables') t(k, v)) as rows, e -> 'more' as more, pg_size_pretty(octet_length(e::text)::bigint) as size from dry_export;
-- Nothing secret in any export: no column of those names in any table it found; and what was too big to give.
select count(*) filter (where col in ('hash', 'rh', 'code_challenge', 'channel', 'secret', 'token')) as secret_columns, count(*) filter (where r -> col ? 'not_exported') as values_not_exported from dry_export, jsonb_each(e -> 'tables') t(k, v), jsonb_array_elements(v) r, jsonb_object_keys(r) col;
-- Find: counts only.
select jsonb_array_length(f -> 'people') as people, jsonb_array_length(f -> 'models') as models, jsonb_array_length(f -> 'lists') as lists, jsonb_array_length(f -> 'reports') as reports from (select public.admin_find('castle', false) as f) x;
select public.admin_find('%', false) -> 'models' = '[]'::jsonb as wildcard_finds_nothing_by_itself, public.admin_find('a', false) as too_short;
-- A person's comments and entries (the account with the most comments): counts.
select jsonb_array_length(m -> 'comments') as comments, jsonb_array_length(m -> 'entries') as entries from (select public.admin_person_more((select author from public.model_comments group by author order by count(*) desc limit 1)) as m) x;
select jsonb_array_length(m -> 'entries') as entries from (select public.admin_person_more((select owner from public.challenge_entries group by owner order by count(*) desc limit 1)) as m) x;
-- A challenge's entries, with their votes and whether each keeps the rules (the newest with entries).
select c.id, c.test, jsonb_array_length(e) as entries, (select count(*) from jsonb_array_elements(e) x where x ->> 'keeps' = 'false') as failing, (select sum((x ->> 'votes')::int) from jsonb_array_elements(e) x) as votes from (select ch.id, ch.test, public.challenge_admin_entries(ch.id) as e from public.challenges ch where exists (select 1 from public.challenge_entries ce where ce.challenge = ch.id) order by ch.id desc limit 3) c;
select public.challenge_admin_entries(-1) as no_such;
-- A page's keys are refused, by the tables and by the functions.
set local role anon;
select pg_temp.tries($q$select count(*) from public.site_notices$q$) as anon_reads_notices, pg_temp.tries($q$select public.site_notice('live')$q$) as anon_calls_notice, pg_temp.tries($q$select public.admin_export('00000000-0000-4000-8000-000000000000')$q$) as anon_exports;
reset role;
set local role authenticated;
select pg_temp.tries($q$select count(*) from public.site_env$q$) as signed_in_reads_env, pg_temp.tries($q$select public.admin_sign_out('00000000-0000-4000-8000-000000000000')$q$) as signed_in_signs_out, pg_temp.tries($q$select public.site_notice_set('live', '{"en":"x"}'::jsonb, 'info', 'x')$q$) as signed_in_sets_notice;
reset role;
