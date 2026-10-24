-- What the keys a page holds can reach in schema public, read from the
-- catalogue, 2026-10-24 (orangecheck's re-check of signing in with
-- orangecheck, N1).
--
-- Every page and the app hold the publishable key, and every signed-in
-- browser a session's token: with them PostgREST answers as anon or as
-- authenticated, straight at the database, past every check api/_auth.js
-- makes. Brickworks never asks the database that way (each route asks as
-- the server, api/_db.js), so the answer this asks for is: nothing.
--
--   public.client_exposure()  {bad, tables, functions}: bad, one line for
--                             each thing anon, authenticated or PUBLIC can
--                             reach (a table or view, a column, a sequence, a
--                             policy, a function), and each default that
--                             would grant one to the next made; tables and
--                             functions, every one in public, for
--                             tools/web/orangecheck_check.mjs to ask
--                             PostgREST about, as a session and as anon.
--
-- supabase/no_client_access.sql takes the reach away; this only reads.
-- Security definer, so it reads the catalogue as its owner, and granted to
-- the server alone. Only additions: one function. Applying it again
-- changes nothing.

create or replace function public.client_exposure()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with clients as (
        select oid, rolname from pg_catalog.pg_roles where rolname in ('anon', 'authenticated')
        union all select 0, 'PUBLIC'
    ),
    relations as (
        select c.oid, c.relname, c.relkind, c.relacl, c.relowner
          from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
    ),
    bad as (
        select format('%s %s: %s', case when r.relkind = 'S' then 'sequence' else 'table' end, r.relname,
                      string_agg(distinct w.rolname || ' ' || lower(a.privilege_type), ', ')) as line
          from relations r,
               aclexplode(coalesce(r.relacl, acldefault(case when r.relkind = 'S' then 'S' else 'r' end::"char", r.relowner))) a
          join clients w on w.oid = a.grantee
         group by r.relname, r.relkind
        union all
        select format('column %s.%s: %s', r.relname, t.attname, string_agg(distinct w.rolname || ' ' || lower(a.privilege_type), ', '))
          from relations r join pg_catalog.pg_attribute t on t.attrelid = r.oid and t.attnum > 0 and not t.attisdropped,
               aclexplode(t.attacl) a
          join clients w on w.oid = a.grantee
         group by r.relname, t.attname
        union all
        select format('policy %s on %s: %s', p.policyname, p.tablename, array_to_string(p.roles, ', '))
          from pg_catalog.pg_policies p
         where p.schemaname = 'public' and p.roles && array['public', 'anon', 'authenticated']::name[]
        union all
        select format('function %s(%s): %s', f.proname, pg_catalog.pg_get_function_identity_arguments(f.oid),
                      string_agg(distinct w.rolname, ', '))
          from pg_catalog.pg_proc f join pg_catalog.pg_namespace n on n.oid = f.pronamespace,
               aclexplode(coalesce(f.proacl, acldefault('f', f.proowner))) a
          join clients w on w.oid = a.grantee
         where n.nspname = 'public' and a.privilege_type = 'EXECUTE'
         group by f.oid, f.proname
        union all
        select format('default for %s made by postgres in public: %s',
                      case d.defaclobjtype when 'r' then 'tables' when 'S' then 'sequences' when 'f' then 'functions' else d.defaclobjtype::text end,
                      string_agg(distinct w.rolname, ', '))
          from pg_catalog.pg_default_acl d, aclexplode(d.defaclacl) a
          join clients w on w.oid = a.grantee
         where d.defaclrole = 'postgres'::regrole and d.defaclnamespace = 'public'::regnamespace
         group by d.defaclobjtype
        union all
        select 'default for functions made by postgres anywhere: PUBLIC may run them'
         where not exists (
             select 1 from pg_catalog.pg_default_acl d
              where d.defaclrole = 'postgres'::regrole and d.defaclnamespace = 0 and d.defaclobjtype = 'f'
                and not exists (select 1 from aclexplode(d.defaclacl) a where a.grantee = 0 and a.privilege_type = 'EXECUTE'))
    )
    select jsonb_build_object(
        'bad', coalesce((select jsonb_agg(line order by line) from bad), '[]'::jsonb),
        'tables', coalesce((select jsonb_agg(relname order by relname) from relations where relkind <> 'S'), '[]'::jsonb),
        'functions', coalesce((
            select jsonb_agg(jsonb_build_object('name', f.proname, 'args', coalesce(i.names, '[]'::jsonb),
                       'named', f.pronargs = 0 or coalesce(jsonb_array_length(i.names), 0) = f.pronargs,
                       'trigger', f.prorettype = 'trigger'::regtype) order by f.proname)
              from pg_catalog.pg_proc f join pg_catalog.pg_namespace n on n.oid = f.pronamespace
              left join lateral (
                  -- The names of its input arguments, which PostgREST calls it by.
                  select jsonb_agg(x.name order by x.at) as names
                    from unnest(f.proargnames, coalesce(f.proargmodes, array_fill('i'::"char", array[coalesce(cardinality(f.proargnames), 0)])))
                         with ordinality as x(name, mode, at)
                   where x.mode in ('i', 'b', 'v') and x.name <> '') i on true
             where n.nspname = 'public' and f.prokind = 'f'), '[]'::jsonb));
$$;

revoke all on function public.client_exposure() from public, anon, authenticated;
grant execute on function public.client_exposure() to service_role;
