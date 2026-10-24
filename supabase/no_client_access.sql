-- Nothing in schema public for the keys a page holds, 2026-10-24
-- (orangecheck's re-check of signing in with orangecheck, N1).
--
-- Every page and the app hold the publishable key, and every signed-in
-- browser a session's token. With them PostgREST answers as anon or as
-- authenticated, straight at the database, past every check api/_auth.js
-- makes: a session orangecheck ended, or one by a password, still read and
-- wrote whatever row security let it. Brickworks never asks the database
-- that way. Every route asks as the server (api/_db.js), and the site and
-- the app only ever reach Supabase to sign in (/auth/v1). So they lose
-- nothing, and none of them is left with a way in:
--
--   - every policy for anon, authenticated or everyone, on every table in
--     public, dropped. Row security stays on, so a table answers nobody
--     but the server;
--   - every privilege anon and authenticated had on a table, a view, a
--     column or a sequence, taken back, and the right of anon,
--     authenticated and PUBLIC to run any function;
--   - and what postgres makes from now on is granted to none of them:
--     tables, sequences and functions in public, and functions anywhere.
--
-- But shared_models' published rows, which the release before this one
-- reads through the publishable key (api/share.js publishedRow): they go
-- with supabase/no_client_access_models.sql, once a release that reads
-- them as the server is live.
--
-- supabase/client_exposure.sql reads what is left (orangecheck_check holds
-- it empty). Supabase's auth role keeps running the auth.users triggers:
-- it is granted them by name (here and in no_new_ways_in.sql).
--
-- Only takings away, which is the point; nothing a route or a page asks
-- for. Applying it again changes nothing.

do $$
declare
    one record;
begin
    for one in
        select p.tablename, p.policyname from pg_catalog.pg_policies p
         where p.schemaname = 'public' and p.roles && array['public', 'anon', 'authenticated']::name[]
           and not (p.tablename = 'shared_models' and p.policyname = 'shared_models_read_published')
    loop
        execute format('drop policy %I on public.%I', one.policyname, one.tablename);
    end loop;
    for one in
        select c.relname, c.relkind from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S') and c.relname <> 'shared_models'
    loop
        execute format('revoke all on %s public.%I from anon, authenticated',
                       case when one.relkind = 'S' then 'sequence' else 'table' end, one.relname);
    end loop;
end;
$$;

revoke all on all routines in schema public from public, anon, authenticated;
grant execute on function public.on_auth_user_created() to supabase_auth_admin;

alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated;
alter default privileges for role postgres revoke execute on functions from public;

notify pgrst, 'reload schema';
