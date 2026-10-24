-- Build together, 2026-10-24: two people build one model at once, live,
-- each in their own browser or desktop app (api/together.js,
-- src/net/together.gd, docs/TOGETHER.md).
--
-- The owner of a model starts a session and is given a link; a signed-in
-- person who opens it joins. Every change either of them makes is a row
-- here, numbered in the one order the server gave it, and every side puts
-- the rows down in that order: so a part moved by two people at once ends
-- where the later of the two put it, on both sides, and the model is the
-- same part for part everywhere.
--
--   together_sessions  one per session: its owner, the model as it was
--                      when it started (snapshot: the file's text, the
--                      lift it stands at, and each part with the id the
--                      session calls it by), the last number given, and
--                      when the owner ended it. Its id is the SHA-256 of
--                      the link's secret, which is never stored, as a
--                      relay channel is the SHA-256 of a tab's token
--                      (relay.sql).
--   together_ops       each change, by its number: which parts it set and
--                      to what (a part's state, or null for taken off),
--                      who made it and from which open copy (client, and
--                      its own count, cid, so each side knows its own).
--   together_people    who has joined, the name the others are shown (their
--                      profile's, when a visitor may be shown it, else none:
--                      never an email, never an under-13's), when each was
--                      last heard from, and whether the owner took them out
--                      of it (removed_at: refused from then on, by the same
--                      link too).
--
-- Numbers are given by together_append under the session row's lock, so
-- two people sending at once are numbered one after the other and each
-- commit lands before the next number is given: a side reading the rows
-- after the last number it has never skips one that commits late.
--
-- Only the server reaches these: row level security on with no policies,
-- and nothing granted to the publishable key's roles (no_client_access.sql).
-- An ended session goes a day after it ended, and one nobody has changed
-- in a week goes too (together_sweep, called now and then by the API).
-- Additions only: three new tables and two new functions; no existing
-- row, table or function is changed.

create table if not exists public.together_sessions (
  id         text        primary key check (id ~ '^[0-9a-f]{64}$'),
  owner      uuid        not null references auth.users (id) on delete cascade,
  title      text        not null default '' check (char_length(title) <= 120),
  snapshot   jsonb       not null,
  last_seq   bigint      not null default 0 check (last_seq >= 0),
  created_at timestamptz not null default now(),
  changed_at timestamptz not null default now(),
  ended_at   timestamptz
);
create index if not exists together_sessions_owner on public.together_sessions (owner);

create table if not exists public.together_ops (
  session text        not null references public.together_sessions (id) on delete cascade,
  seq     bigint      not null check (seq >= 1),
  author  uuid        not null references auth.users (id) on delete cascade,
  client  text        not null check (client ~ '^[a-z0-9]{6,16}$'),
  cid     integer     not null check (cid >= 0),
  changes jsonb       not null check (jsonb_typeof(changes) = 'object'),
  at      timestamptz not null default now(),
  primary key (session, seq)
);

create table if not exists public.together_people (
  session    text        not null references public.together_sessions (id) on delete cascade,
  account    uuid        not null references auth.users (id) on delete cascade,
  name       text        not null default '' check (char_length(name) <= 40),
  joined_at  timestamptz not null default now(),
  seen_at    timestamptz not null default now(),
  left_at    timestamptz,
  removed_at timestamptz,
  primary key (session, account)
);

-- So applying this again over a first draft of it, which had no name, adds it.
alter table public.together_people add column if not exists name text not null default ''
  check (char_length(name) <= 40);

alter table public.together_sessions enable row level security;
alter table public.together_ops      enable row level security;
alter table public.together_people   enable row level security;
revoke all on public.together_sessions, public.together_ops, public.together_people
  from anon, authenticated;

-- Changes from one open copy, numbered after every change before them, and
-- the numbers they were given, in order. Refused when the session has ended
-- or the author is not in it (never joined, or taken out by the owner).
create or replace function public.together_append(p_session text, p_author uuid, p_client text,
                                                  p_ops jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer := jsonb_array_length(p_ops);
    first bigint;
    owned uuid;
begin
    if n < 1 or n > 500 then
        raise exception 'brickworks: send between 1 and 500 changes' using errcode = '22023';
    end if;
    select s.owner into owned from public.together_sessions s
     where s.id = p_session and s.ended_at is null
       for update;
    if not found then
        raise exception 'brickworks: that session has ended' using errcode = 'P0001',
            hint = 'together:ended';
    end if;
    if owned <> p_author and not exists (
        select 1 from public.together_people p
         where p.session = p_session and p.account = p_author and p.removed_at is null) then
        raise exception 'brickworks: not in this session' using errcode = 'P0001',
            hint = 'together:refused';
    end if;
    update public.together_sessions
       set last_seq = last_seq + n, changed_at = now()
     where id = p_session
    returning last_seq - n into first;
    insert into public.together_ops (session, seq, author, client, cid, changes)
    select p_session, first + o.ord, p_author, p_client, (o.value->>'cid')::integer, o.value->'changes'
      from jsonb_array_elements(p_ops) with ordinality as o(value, ord);
    return (select jsonb_agg(first + k order by k) from generate_series(1, n) as k);
end;
$$;

-- Ended sessions a day on, and sessions nobody has changed in a week.
create or replace function public.together_sweep()
returns integer
language sql
security definer
set search_path = public
as $$
    with gone as (
        delete from public.together_sessions
         where (ended_at is not null and ended_at < now() - interval '1 day')
            or changed_at < now() - interval '7 days'
        returning 1)
    select count(*)::integer from gone
$$;

revoke all on function public.together_append(text, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.together_sweep() from public, anon, authenticated;
