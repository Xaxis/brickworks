-- The links of shared models whose rows were deleted, 2026-11-22.
--
-- A shared model's files are in storage by its link (api/share.js BUCKET and
-- THUMBS), and storage keeps no link to its row. When an account is deleted
-- its models' rows go with it (shared_models_owner_fkey, on delete cascade),
-- and every check's throwaway account is deleted so, directly, by a dozen
-- flows. The daily sweep (api/share.js sweep) then sees files no row owns,
-- and it cannot tell them from rows read back empty by a wrong key, so past
-- a quarter of what it looked at it takes none (api/_cron.js sweepHeld). On
-- 11-22 a night of checks left 121 such files and the sweep failed twice.
--
-- Now each deletion of a row says so here, whatever deleted it, and the
-- sweep takes those links' files as known gone, outside the quarter. The
-- quarter still holds for files it cannot account for.
--
-- Only additions: a new table, a function and a trigger on shared_models
-- after delete. No existing row or column is changed, nothing dropped.
--
--   shared_models_gone   one row per link whose row was deleted:
--     id                 the link (shared_models.id)
--     gone_at            when its row was deleted
--
-- Read and emptied only by the service role (the sweep, once a link's files
-- are gone); RLS on, no policy, nothing granted to anon or authenticated.

create table if not exists public.shared_models_gone (
  id text primary key,
  gone_at timestamptz not null default now()
);

alter table public.shared_models_gone enable row level security;
revoke all on public.shared_models_gone from anon, authenticated;
grant select, insert, delete on public.shared_models_gone to service_role;

create or replace function public.shared_models_gone_note()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.shared_models_gone (id) values (old.id)
    on conflict (id) do update set gone_at = excluded.gone_at;
  return old;
end;
$$;

revoke all on function public.shared_models_gone_note() from public, anon, authenticated;

drop trigger if exists shared_models_gone_note on public.shared_models;
create trigger shared_models_gone_note
  after delete on public.shared_models
  for each row execute function public.shared_models_gone_note();
