-- Signing in with Google and GitHub, its second review's last two findings
-- (signin4, 2026-11-24: signinreview F7 and F9), beside
-- supabase/sign_in_ways.sql, which this needs.
--
-- F7. Whether Google or GitHub signs an account in, or was unlinked from it,
-- was kept in the account's app_metadata (way_google, way_github,
-- way_github_id). GoTrue's admin update reads app_metadata and writes it
-- whole, so a way's first sign-in, writing that it now signs the account
-- in, and an Unlink in the same moment could lose the Unlink: the way went
-- on signing in. Now each account's ways are rows of their own, changed only
-- by the functions below, each holding a lock on the account and the way
-- while it reads and writes, so that one waits for the other and "off" is
-- always read as it is:
--
--   way_links           one row per account and way that has signed it in
--                       (on) or been unlinked (off); none, never used.
--                       GitHub's numeric id, the one GitHub account that
--                       signs it in. Gone with the account.
--   way_links_of        an account's ways: {google: {state, id}, github:
--                       {...}}, a way with no row left out.
--   way_signed_in       a session Google or GitHub minted, kept or ended in
--                       one step: 'on', written down as the way's (as
--                       way_session_keep writes it) and the way signing the
--                       account in; 'off', the way unlinked; 'confirm',
--                       GitHub's id not the one kept (or none kept, and none
--                       to bind). Ended at once, with its refresh tokens,
--                       but 'on'. Null when the session is not the account's.
--   way_bind            GitHub's id kept for an account after a code
--                       (api/_ways.js wayBind): 'on', or 'off' and nothing
--                       changed.
--   way_set             unlinked (on false: 'off', its id let go, and every
--                       session it started ended, how many) or linked again
--                       (on true: no row, as never used).
--
-- F9. Each Google or GitHub sign-in spends one /auth/v1/verify from the
-- server's own address, which Supabase allows 30 at once and then one each
-- 10 s, for everyone's Google, GitHub and orangecheck sign-ins together.
-- One account in a loop kept it at 429. api/_ways.js now counts each start
-- and each way back by network, and each way back by provider account,
-- before anything is spent:
--
--   way_attempts        one row per attempt: its key and when. Let go after
--                       a day.
--   way_may_try         true, and the attempt counted, when [try_key] has
--                       fewer than [per] in the last [window_minutes];
--                       false, and not counted, when it has that many. One
--                       key's attempts are counted one at a time (a lock on
--                       the key), so attempts sent at once cannot all pass.
--
-- Only additions: two tables and five functions, each security definer and
-- granted to the service role alone, the tables to nobody, as way_sessions
-- is. Nothing existing is replaced; way_session_keep and way_end_sessions
-- stay as they are, unused by this code. The ways already kept in
-- app_metadata are copied in once (the copy changes nothing there, and a
-- row already made is kept). Applying it again changes nothing.

create table if not exists public.way_links (
    account     uuid not null references auth.users (id) on delete cascade,
    way         text not null constraint way_links_way check (way in ('google', 'github')),
    state       text not null constraint way_links_state check (state in ('on', 'off')),
    provider_id text constraint way_links_provider_id check (provider_id is null or length(provider_id) between 1 and 200),
    changed_at  timestamptz not null default now(),
    constraint way_links_pkey primary key (account, way)
);

alter table public.way_links enable row level security;
revoke all on public.way_links from public, anon, authenticated, service_role;

insert into public.way_links (account, way, state, provider_id)
    select u.id, w.way,
           case when u.raw_app_meta_data ->> ('way_' || w.way) = 'off' then 'off' else 'on' end,
           case when w.way = 'github' and u.raw_app_meta_data ->> 'way_github' <> 'off'
                then nullif(u.raw_app_meta_data ->> 'way_github_id', '') end
      from auth.users u cross join (values ('google'), ('github')) as w (way)
     where coalesce(u.raw_app_meta_data ->> ('way_' || w.way), '') <> ''
    on conflict (account, way) do nothing;

create table if not exists public.way_attempts (
    try_key text not null,
    at      timestamptz not null default now()
);
create index if not exists way_attempts_key on public.way_attempts (try_key, at);
create index if not exists way_attempts_at on public.way_attempts (at);

alter table public.way_attempts enable row level security;
revoke all on public.way_attempts from public, anon, authenticated, service_role;

-- way_signed_in, way_bind and way_set each first take a lock on the
-- account's way (pg_advisory_xact_lock of 'way_links <account> <way>'),
-- held to the end of its transaction: one at a time per account and way,
-- whether or not its row is there yet.

create or replace function public.way_links_of(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_object_agg(l.way, jsonb_build_object('state', l.state, 'id', l.provider_id)), '{}'::jsonb)
      from public.way_links l where l.account = way_links_of.account
$$;

create or replace function public.way_signed_in(session uuid, account uuid, way text, provider_id text, bind boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    link public.way_links;
begin
    perform pg_advisory_xact_lock(hashtextextended('way_links ' || way_signed_in.account::text || ' ' || way_signed_in.way, 0));
    select * into link from public.way_links l
     where l.account = way_signed_in.account and l.way = way_signed_in.way;
    if found and link.state = 'off' then
        delete from auth.sessions s where s.id = way_signed_in.session and s.user_id = way_signed_in.account;
        return 'off';
    end if;
    if way_signed_in.way = 'github' and not coalesce(way_signed_in.bind, false)
       and (link.provider_id is null or link.provider_id is distinct from way_signed_in.provider_id) then
        delete from auth.sessions s where s.id = way_signed_in.session and s.user_id = way_signed_in.account;
        return 'confirm';
    end if;
    insert into public.way_sessions (session_id, account, way)
        select s.id, s.user_id, way_signed_in.way
          from auth.sessions s
         where s.id = way_signed_in.session and s.user_id = way_signed_in.account
        on conflict (session_id) do nothing;
    if not exists (select 1 from public.way_sessions w
                    where w.session_id = way_signed_in.session and w.account = way_signed_in.account
                      and w.way = way_signed_in.way) then
        return null;
    end if;
    if link.account is null then
        insert into public.way_links (account, way, state, provider_id)
            values (way_signed_in.account, way_signed_in.way, 'on',
                    case when way_signed_in.way = 'github' then way_signed_in.provider_id end);
    elsif way_signed_in.way = 'github' and link.provider_id is distinct from way_signed_in.provider_id then
        update public.way_links l set provider_id = way_signed_in.provider_id, changed_at = now()
         where l.account = way_signed_in.account and l.way = way_signed_in.way;
    end if;
    return 'on';
end;
$$;

create or replace function public.way_bind(account uuid, way text, provider_id text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    link public.way_links;
begin
    perform pg_advisory_xact_lock(hashtextextended('way_links ' || way_bind.account::text || ' ' || way_bind.way, 0));
    select * into link from public.way_links l where l.account = way_bind.account and l.way = way_bind.way;
    if found and link.state = 'off' then
        return 'off';
    end if;
    insert into public.way_links as l (account, way, state, provider_id)
        values (way_bind.account, way_bind.way, 'on', way_bind.provider_id)
        on conflict on constraint way_links_pkey do update set provider_id = excluded.provider_id, changed_at = now();
    return 'on';
end;
$$;

create or replace function public.way_set(account uuid, way text, turned_on boolean)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    ended integer := 0;
begin
    perform pg_advisory_xact_lock(hashtextextended('way_links ' || way_set.account::text || ' ' || way_set.way, 0));
    if turned_on then
        delete from public.way_links l where l.account = way_set.account and l.way = way_set.way;
        return 0;
    end if;
    insert into public.way_links as l (account, way, state, provider_id)
        values (way_set.account, way_set.way, 'off', null)
        on conflict on constraint way_links_pkey do update set state = 'off', provider_id = null, changed_at = now();
    with gone as (
        delete from auth.sessions s
         where s.id in (select w.session_id from public.way_sessions w
                         where w.account = way_set.account and w.way = way_set.way)
        returning 1)
    select count(*)::integer into ended from gone;
    return ended;
end;
$$;

create or replace function public.way_may_try(try_key text, per integer, window_minutes integer)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    tried integer;
begin
    if try_key is null or per is null or per < 1 or window_minutes is null or window_minutes not between 1 and 1440 then
        return false;
    end if;
    perform pg_advisory_xact_lock(hashtextextended('way_attempts ' || way_may_try.try_key, 0));
    delete from public.way_attempts a where a.at < now() - interval '1 day';
    select count(*) into tried from public.way_attempts a
     where a.try_key = way_may_try.try_key and a.at >= now() - make_interval(mins => window_minutes);
    if tried >= per then
        return false;
    end if;
    insert into public.way_attempts (try_key) values (way_may_try.try_key);
    return true;
end;
$$;

revoke all on function public.way_links_of(uuid) from public, anon, authenticated;
revoke all on function public.way_signed_in(uuid, uuid, text, text, boolean) from public, anon, authenticated;
revoke all on function public.way_bind(uuid, text, text) from public, anon, authenticated;
revoke all on function public.way_set(uuid, text, boolean) from public, anon, authenticated;
revoke all on function public.way_may_try(text, integer, integer) from public, anon, authenticated;
grant execute on function public.way_links_of(uuid) to service_role;
grant execute on function public.way_signed_in(uuid, uuid, text, text, boolean) to service_role;
grant execute on function public.way_bind(uuid, text, text) to service_role;
grant execute on function public.way_set(uuid, text, boolean) to service_role;
grant execute on function public.way_may_try(text, integer, integer) to service_role;
