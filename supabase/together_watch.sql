-- Building now, 2026-11-23 (buildlive; api/together.js and api/_watch.js,
-- src/net/together.gd, web/live.js, docs/TOGETHER.md "Watching"): a
-- designer opens their Build together session to watchers from the studio.
-- It is listed first in the home feed and on their profile; anyone may
-- watch its parts land in the site's light 3D viewer at /live/<watch>, and
-- an account 13 or over may chat there and ask to build. The designer gives
-- a seat to somebody who asked, who then builds in it as anyone who joined
-- by its link does. Watching never edits: a watcher has no secret of the
-- session, and the relay refuses an edit from one.
--
--   together_watch     one per session that was opened to watchers: the
--                      public name of its show (watch, in its address),
--                      its designer, its title as the listing shows it, the
--                      shared model it builds where it has one (model, so
--                      the listing and its end go to that model's page and
--                      log), when it opened and when it closed (closed_at:
--                      the designer closed it, or ended the session), and
--                      the most watchers it had at once (peak), and
--                      whether its designer is one of the checks' test
--                      accounts (tests: listed only where a check asks,
--                      ?tests=1, as the gallery keeps them).
--   together_watchers  who watches, a row a page: a hash of the session
--                      and the page's own random name (never an account),
--                      and when the page was last heard from, to count the
--                      watchers. Kept only while the session is.
--
--   together_watch_append(session, author, changes)  one line from a
--                      watcher or the designer's seat for one: a chat line
--                      ({"~chat", "~by"}), an ask to build ({"~ask",
--                      "~by"}) or a seat given ({"~seat", "~key"}), put in
--                      the session's own log of changes under the session
--                      row's lock, numbered as together_append numbers a
--                      builder's, from the client "watching" with its
--                      number as its count. So every builder's poll and
--                      every watcher's catch-up reads it where it reads the
--                      rest, at no cost more. Refused when the session has
--                      ended or is not open to watchers, and for anything
--                      but those keys: a watcher's line can never change a
--                      part.
--
-- Only the server reaches them: row level security on with no policies, and
-- nothing granted to the publishable key's roles (no_client_access.sql).
-- Each goes with its session (on delete cascade), so together_sweep takes
-- them a day after the session ends.
--
-- Additions only: two new tables and one new function; no existing row,
-- table or function is changed. Until it is applied the studio says that
-- watching is not open yet, and everything else works as it does now.

create table if not exists public.together_watch (
  session   text        primary key references public.together_sessions (id) on delete cascade,
  watch     text        not null unique check (watch ~ '^[A-Za-z0-9]{12}$'),
  owner     uuid        not null references auth.users (id) on delete cascade,
  title     text        not null default '' check (char_length(title) <= 120),
  model     text        check (model is null or model ~ '^[A-Za-z0-9]{10}$'),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  peak      integer     not null default 0 check (peak >= 0),
  tests     boolean     not null default false
);
create index if not exists together_watch_open on public.together_watch (opened_at desc)
  where closed_at is null;
create index if not exists together_watch_owner on public.together_watch (owner);

create table if not exists public.together_watchers (
  session text        not null references public.together_sessions (id) on delete cascade,
  viewer  text        not null check (viewer ~ '^[0-9a-f]{16}$'),
  seen_at timestamptz not null default now(),
  primary key (session, viewer)
);

alter table public.together_watch    enable row level security;
alter table public.together_watchers enable row level security;
revoke all on public.together_watch, public.together_watchers from anon, authenticated;

-- One line in session [p_session]'s log from [p_author], who need not be in
-- it: its number. The session must not have ended and must be open to
-- watchers. Its count (cid) is its number, so each side, which takes a
-- client's changes only in their count's order, takes every one.
create or replace function public.together_watch_append(p_session text, p_author uuid, p_changes jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
    seq_now bigint;
begin
    if jsonb_typeof(p_changes) <> 'object'
       or not (p_changes ?| array['~chat', '~ask', '~seat'])
       or exists (select 1 from jsonb_object_keys(p_changes) as k(key)
                   where k.key not in ('~chat', '~ask', '~seat', '~by', '~key'))
       or char_length(p_changes::text) > 2000 then
        raise exception 'brickworks: a watcher says a line, asks to build, or is given a seat'
            using errcode = '22023';
    end if;
    perform 1 from public.together_sessions s
     where s.id = p_session and s.ended_at is null
       for update;
    if not found then
        raise exception 'brickworks: that session has ended' using errcode = 'P0001',
            hint = 'together:ended';
    end if;
    if not exists (select 1 from public.together_watch w
                    where w.session = p_session and w.closed_at is null) then
        raise exception 'brickworks: that session is not open to watchers' using errcode = 'P0001',
            hint = 'together:closed';
    end if;
    update public.together_sessions
       set last_seq = last_seq + 1, changed_at = now()
     where id = p_session
    returning last_seq into seq_now;
    insert into public.together_ops (session, seq, author, client, cid, changes)
    values (p_session, seq_now, p_author, 'watching', seq_now::integer, p_changes);
    return seq_now;
end;
$$;

revoke all on function public.together_watch_append(text, uuid, jsonb) from public, anon, authenticated;
