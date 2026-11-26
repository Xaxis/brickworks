-- signin7's trial of supabase/way_try_back.sql, run inside the dry run's transaction (rolled back).
-- One key, a limit of 2: two tries counted, the third refused; one given back, a third counted; a give-back
-- of a try already given back finds nothing; way_may_try counts the same rows.
create temporary table trial_keys (k text, one timestamptz) on commit drop;
insert into trial_keys select 'signin7 trial ' || md5(random()::text), null;
update trial_keys set one = public.way_try(k, 2, 15);
select '1 first try' as step, coalesce(one::text, 'null') as said from trial_keys;
select '2 second try' as step, coalesce(public.way_try(k, 2, 15)::text, 'null') as said from trial_keys;
select '3 third try, over 2' as step, coalesce(public.way_try(k, 2, 15)::text, 'null') as said from trial_keys;
select '4 way_may_try now' as step, public.way_may_try(k, 2, 15)::text as said from trial_keys;
select '5 first given back' as step, public.way_try_back(k, one)::text as said from trial_keys;
select '6 given back again' as step, public.way_try_back(k, one)::text as said from trial_keys;
select '7 rows of the key' as step, (select count(*) from public.way_attempts a where a.try_key = t.k)::text as said from trial_keys t;
select '8 a try once one is given back' as step, coalesce(public.way_try(k, 2, 15)::text, 'null') as said from trial_keys;
select '9 and over again' as step, coalesce(public.way_try(k, 2, 15)::text, 'null') as said from trial_keys;
select p.proname, p.prosecdef as definer, has_function_privilege('anon', p.oid, 'execute') as anon_exec,
       has_function_privilege('authenticated', p.oid, 'execute') as authed_exec,
       has_function_privilege('service_role', p.oid, 'execute') as service_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('way_try', 'way_try_back', 'way_may_try') order by 1;
