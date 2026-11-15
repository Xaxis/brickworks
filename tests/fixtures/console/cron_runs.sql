-- gallery_crons.sql's cron_runs and cron_runs_of alone, as they are there, for the console's
-- tests (tests/fixtures/console/db2_check.mjs): the rest of that file needs the gallery's tables.
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

