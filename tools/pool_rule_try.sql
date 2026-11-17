-- What supabase/pool_rule.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/pool_rule.sql --dry --try=tools/pool_rule_try.sql --table=collection_pools_kept
--
-- One made-up account, made and gone with the transaction. Each statement is
-- on one line: the dry run splits at a semicolon that ends a line.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'poolrule-ada@resend.dev');
select count(*) filter (where rule = 1) as "pools kept before, rule 1", count(*) filter (where rule <> 1) as "any other rule" from public.collection_pools_kept;
select public.owned_keep_pool('00000000-0000-4000-8000-0000000000e1', '[{"part": "3001", "colour": 4, "qty": 2}]', '{"9999-1"}') as "an older site's keep (3 arguments)";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000e1') - 'at' as "kept by it: rule 1";
select public.owned_keep_pool('00000000-0000-4000-8000-0000000000e1', '[{"part": "3001", "colour": 4, "qty": 7}]', '{}', 2) as "a newer site's keep (rule 2)";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000e1') - 'at' as "kept by it: rule 2";
select public.owned_keep_pool('00000000-0000-4000-8000-0000000000e1', '[{"part": "3001", "colour": 4, "qty": 2}]') as "an older site's keep again (2 arguments)";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000e1') - 'at' as "back to rule 1";
select pg_temp.tries($q$select public.owned_keep_pool('00000000-0000-4000-8000-0000000000e1', '[]', '{}', null)$q$) as "no rule";
select pg_temp.tries($q$select public.owned_keep_pool('00000000-0000-4000-8000-0000000000e1', '[]', '{}', 0)$q$) as "rule 0";
select p.proname, pg_get_function_identity_arguments(p.oid) as arguments, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('owned_keep_pool', 'owned_pool_of') order by p.proname, arguments;
