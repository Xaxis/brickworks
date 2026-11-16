-- gallery_crons.sql's cron_runs, cron_runs_of and its lock (cron_locks, cron_begin, cron_end)
-- alone, as they are there, for the console's tests (tests/fixtures/console/db2_check.mjs,
-- api3_check.mjs's Run now): the rest of that file needs the gallery's tables.
create table if not exists public.cron_runs (
    id           bigint generated always as identity primary key,
    job          text not null check (job ~ '^[a-z][a-z_]{0,39}$'),
    holder       text not null check (char_length(holder) between 1 and 80),
    started_at   timestamptz not null default now(),
    finished_at  timestamptz,
    outcome      text check (outcome is null or outcome in ('done', 'unchanged', 'locked', 'failed')),
    said         jsonb not null default '{}'::jsonb check (pg_column_size(said) <= 16000),
    check ((finished_at is null) = (outcome is null))
);
create index if not exists cron_runs_job on public.cron_runs (job, started_at desc);
alter table public.cron_runs enable row level security;

create or replace function public.cron_runs_of(job text, most integer default 10)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('run', r.id, 'job', r.job, 'holder', r.holder, 'started_at', r.started_at,
                              'finished_at', r.finished_at, 'outcome', r.outcome, 'said', r.said)
      from public.cron_runs r
     where r.job = cron_runs_of.job
     order by r.started_at desc, r.id desc
     limit least(greatest(coalesce(most, 10), 1), 50)
$$;

create table if not exists public.cron_locks (
    job     text primary key check (job ~ '^[a-z][a-z_]{0,39}$'),
    holder  text not null check (char_length(holder) between 1 and 80),
    until   timestamptz not null
);
alter table public.cron_locks enable row level security;
revoke all on public.cron_locks from public, anon, authenticated, service_role;

-- A run of [job] by [holder] begins: {run, locked}. The lock is taken for
-- [seconds] (10 to 3600) unless another run holds it still, and the run is
-- written down either way; a locked one is written down as ended.
create or replace function public.cron_begin(job text, holder text, seconds integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    took boolean;
    run bigint;
begin
    insert into public.cron_locks as l (job, holder, until)
    values (cron_begin.job, cron_begin.holder,
            now() + make_interval(secs => least(greatest(coalesce(seconds, 300), 10), 3600)))
    on conflict on constraint cron_locks_pkey do update
       set holder = excluded.holder, until = excluded.until
     where l.until < now()
    returning true into took;
    took := coalesce(took, false);
    insert into public.cron_runs (job, holder, finished_at, outcome)
    values (cron_begin.job, cron_begin.holder, case when took then null else now() end,
            case when took then null else 'locked' end)
    returning id into run;
    return jsonb_build_object('run', run, 'locked', not took);
end;
$$;

-- Run [run] of [holder] ended with [outcome], having [said] that: true
-- when it was open. Its lock goes, if it is still the run's own.
create or replace function public.cron_end(run bigint, holder text, outcome text, said jsonb default '{}'::jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    which text;
begin
    if outcome not in ('done', 'unchanged', 'failed') then
        raise exception 'brickworks: a run ends done, unchanged or failed' using errcode = '22023';
    end if;
    update public.cron_runs r
       set finished_at = now(), outcome = cron_end.outcome, said = coalesce(cron_end.said, '{}'::jsonb)
     where r.id = cron_end.run and r.holder = cron_end.holder and r.finished_at is null
    returning r.job into which;
    if which is null then
        return false;
    end if;
    delete from public.cron_locks l where l.job = which and l.holder = cron_end.holder;
    return true;
end;
$$;
