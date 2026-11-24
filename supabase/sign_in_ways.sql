-- Signing in with Google and GitHub, the sessions each starts (signin3's
-- review, 2026-11-24: signinreview F2 and F6), beside supabase/orangecheck.sql.
--
-- A session Google or GitHub signs in (api/_ways.js) is minted from a
-- one-time link, as orangecheck's is (api/_minted.js), so Supabase calls it
-- "otp", the same as a code just emailed. Nothing told them apart: a GitHub
-- sign-in passed the step-up that linking orangecheck asks for, orangecheck
-- was told its address was verified by Brickworks, and unlinking GitHub left
-- the sessions GitHub had started signed in. Now each is written down as it
-- is handed out, and:
--
--   way_sessions        the session each Google or GitHub sign-in started:
--                       its id, account and way. Gone with the session or
--                       the account.
--   way_session_keep    one written down, for its own account only; false
--                       when the session is not that account's (or gone).
--                       api/_ways.js hands a session out only once it is.
--   way_session_of      the way that started [session], or null: a code's,
--                       orangecheck's, a test password's (api/_oc.js codeOf).
--   way_end_sessions    every session [way] started for [account] ended,
--                       with their refresh tokens: what Unlink does. How
--                       many.
--   oc_connect_claim    Connect's ask for [account] claimed, at once: true
--                       for the one request that may ask orangecheck now,
--                       none other within a minute (F6: six first requests
--                       of a sign-in at once each asked Connect, since the
--                       minute was read, then written). An account that
--                       already has its orangecheck account is never
--                       claimed. Writes the row oc_connect_asked writes.
--
-- Only additions: one table and five functions, each security definer and
-- granted to the service role alone, the table to nobody, as
-- oc_sessions and oc_connected are. Nothing existing is replaced. Applying
-- it again changes nothing.

create table if not exists public.way_sessions (
    session_id uuid primary key references auth.sessions (id) on delete cascade,
    account    uuid not null references auth.users (id) on delete cascade,
    way        text not null constraint way_sessions_way check (way in ('google', 'github')),
    started_at timestamptz not null default now()
);
create index if not exists way_sessions_account on public.way_sessions (account, way);

alter table public.way_sessions enable row level security;
revoke all on public.way_sessions from public, anon, authenticated, service_role;

create or replace function public.way_session_keep(session uuid, account uuid, way text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.way_sessions (session_id, account, way)
        select s.id, s.user_id, way_session_keep.way
          from auth.sessions s
         where s.id = way_session_keep.session and s.user_id = way_session_keep.account
        on conflict (session_id) do nothing;
    return exists (select 1 from public.way_sessions w
                    where w.session_id = way_session_keep.session and w.account = way_session_keep.account
                      and w.way = way_session_keep.way);
end;
$$;

create or replace function public.way_session_of(session uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select w.way from public.way_sessions w where w.session_id = way_session_of.session
$$;

create or replace function public.way_end_sessions(account uuid, way text)
returns integer
language sql
security definer
set search_path = public
as $$
    with gone as (
        delete from auth.sessions s
         where s.id in (select w.session_id from public.way_sessions w
                         where w.account = way_end_sessions.account and w.way = way_end_sessions.way)
        returning 1)
    select count(*)::integer from gone
$$;

create or replace function public.oc_connect_claim(account uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
    insert into public.oc_connected as c (account) values (oc_connect_claim.account)
        on conflict (account) do update set asked_at = now()
         where c.did_oc is null and c.asked_at < now() - interval '1 minute'
    returning true
$$;

revoke all on function public.way_session_keep(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.way_session_of(uuid) from public, anon, authenticated;
revoke all on function public.way_end_sessions(uuid, text) from public, anon, authenticated;
revoke all on function public.oc_connect_claim(uuid) from public, anon, authenticated;
grant execute on function public.way_session_keep(uuid, uuid, text) to service_role;
grant execute on function public.way_session_of(uuid) to service_role;
grant execute on function public.way_end_sessions(uuid, text) to service_role;
grant execute on function public.oc_connect_claim(uuid) to service_role;
