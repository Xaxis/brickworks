-- What the daily sign-in canary found, 2026-10-24 (api/_canary.js).
--
-- Once a day Vercel's cron asks /api/otp/canary to try a stranger's public
-- sign-up, an unconfirmed address's ways in and a new person's sign-in by
-- an emailed code, against production's Supabase. Each run is a row here,
-- passed or failed, so the lead can read what each day found:
--
--   select at, ok, host, mailed, stale, checks from public.canary_runs order by at desc limit 7;
--
-- checks is [{check, ok, what, said}], check being a, b, c or gone;
-- left_behind the canary's own accounts it could not delete; stale how
-- many an earlier, cut-off run had left, deleted at this one's start;
-- mailed "none", "sent", "failed: ..." or "skipped: ..." (a unit's
-- preview has no mail key). A row a day, so nothing is let go.
--
-- The server's alone: row security on with no policy, and nothing for the
-- keys a page holds. Only additions; applying it again changes nothing.

create table if not exists public.canary_runs (
    id           bigserial primary key,
    at           timestamptz not null default now(),
    ok           boolean not null,
    host         text not null default '' check (char_length(host) <= 200),
    checks       jsonb not null default '[]'::jsonb,
    left_behind  jsonb not null default '[]'::jsonb,
    stale        integer not null default 0,
    mailed       text not null default '' check (char_length(mailed) <= 200)
);
create index if not exists canary_runs_at on public.canary_runs (at desc);
alter table public.canary_runs enable row level security;
revoke all on public.canary_runs from anon, authenticated;
