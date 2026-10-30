-- Build together, 2026-10-30: a model over 4 MB starts a session
-- (api/together.js, src/net/together.gd, docs/TOGETHER.md).
--
-- A session keeps the model as it began in its row (together_sessions.
-- snapshot), and that row arrives in one request and leaves in one answer.
-- Vercel takes at most 4.5 MB either way, so a model bigger than that could
-- not start a session ("that model is too big to build together yet"). Now
-- a big model's snapshot goes up in parts of at most 3 MB, a request each, kept
-- here; the session's row says how many there are ({"stored": n, "bytes":
-- b}), and whoever joins reads them back a part a request.
--
--   together_snapshot_parts  one row a part: the session, its number from 0,
--                            and the part's text (a slice of the snapshot's
--                            JSON). Goes with its session (on delete cascade),
--                            so together_sweep takes it a day after the
--                            session ends, or a week after nobody changed it.
--
-- Only the server reaches it: row level security on with no policies, and
-- nothing granted to the publishable key's roles (no_client_access.sql).
--
-- Additions only: one new table; no existing row, table or function is
-- changed. Until it is applied, a model over 4 MB is refused as before and
-- everything else works as it does now: the API looks for the table before
-- it starts a session in parts.

create table if not exists public.together_snapshot_parts (
  session text        not null references public.together_sessions (id) on delete cascade,
  n       integer     not null check (n >= 0 and n < 64),
  text    text        not null check (char_length(text) <= 3000000),
  at      timestamptz not null default now(),
  primary key (session, n)
);

alter table public.together_snapshot_parts enable row level security;
revoke all on public.together_snapshot_parts from anon, authenticated;
