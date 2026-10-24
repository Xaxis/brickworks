-- Signing in with orangecheck, 2026-10-23: beside the emailed code.
--
-- orangecheck's sign-in window hands the page a token for this site
-- (api/orangecheck.js); the server checks it, spends it, and signs the
-- person in to their Brickworks account with a Supabase session of its
-- own. The token is never kept. What is kept here:
--
--   oc_identities  which account an orangecheck id (did:oc:<32 hex>)
--                  signs in to. A did that has no row is a new person: a
--                  new account is made for it, never found. One did an
--                  account, one account a did, both by key, so two
--                  sign-ins at once cannot make two.
--   oc_spent       each token's id (jti), until the token expires: a token
--                  signs in once, on whichever server it reaches.
--   oc_sessions    the Supabase session each orangecheck sign-in started,
--                  with the token's rh, aud and iat, written before the
--                  session is handed out, so "Sign out everywhere" on
--                  orangecheck can end it.
--   oc_attempts    the rate of sign-ins from one address, as otp_requests
--                  is for codes (schema.sql may_ask_for_code).
--
-- An account made with an email address links orangecheck from /settings,
-- after a fresh emailed code (oc_link), and unlinks it the same way
-- (oc_unlink), which ends every session the orangecheck id started there.
-- Each authenticated request of an account that has orangecheck asks
-- oc_session_of about its session (api/_auth.js): whether it still exists,
-- and if orangecheck started it, its rh, aud and iat, so a session somebody
-- ended everywhere is ended here too (oc_end_session).
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables
-- directly.
--
-- Only additions: four new tables, four empty columns on each of
-- oauth_codes and oauth_grants, and new functions (oc_bind_session made
-- again, below, to answer whether it bound). Applying it again changes
-- nothing. Sessions are ended by deleting Supabase's own row
-- (auth.sessions), which takes its refresh tokens and its binding with it.

create table if not exists public.oc_identities (
    did_oc    text primary key constraint oc_identities_did check (did_oc ~ '^did:oc:[0-9a-f]{32}$'),
    account   uuid not null unique references auth.users (id) on delete cascade,
    linked_at timestamptz not null default now()
);

create table if not exists public.oc_spent (
    jti   text primary key,
    until timestamptz not null
);
create index if not exists oc_spent_until on public.oc_spent (until);

create table if not exists public.oc_sessions (
    session_id uuid primary key references auth.sessions (id) on delete cascade,
    account    uuid not null references auth.users (id) on delete cascade,
    did_oc     text not null,
    rh         text not null,
    aud        text not null,
    iat        bigint not null,
    started_at timestamptz not null default now()
);
create index if not exists oc_sessions_account on public.oc_sessions (account);

create table if not exists public.oc_attempts (
    id bigserial primary key,
    ip text not null,
    at timestamptz not null default now()
);
create index if not exists oc_attempts_recent on public.oc_attempts (ip, at desc);

-- A Claude connection approved while signed in with orangecheck (oauth.sql)
-- carries that sign-in's id, rh, aud and iat from its code to the
-- connection, so it ends when that sign-in is ended everywhere on
-- orangecheck, or the id is unlinked. Empty for every other connection.
alter table public.oauth_codes add column if not exists oc_did text;
alter table public.oauth_codes add column if not exists oc_rh text;
alter table public.oauth_codes add column if not exists oc_aud text;
alter table public.oauth_codes add column if not exists oc_iat bigint;
alter table public.oauth_grants add column if not exists oc_did text;
alter table public.oauth_grants add column if not exists oc_rh text;
alter table public.oauth_grants add column if not exists oc_aud text;
alter table public.oauth_grants add column if not exists oc_iat bigint;

alter table public.oc_identities enable row level security;
alter table public.oc_spent enable row level security;
alter table public.oc_sessions enable row level security;
alter table public.oc_attempts enable row level security;
revoke all on public.oc_identities from public, anon, authenticated, service_role;
revoke all on public.oc_spent from public, anon, authenticated, service_role;
revoke all on public.oc_sessions from public, anon, authenticated, service_role;
revoke all on public.oc_attempts from public, anon, authenticated, service_role;

-- A sign-in tried from [from_ip], and whether that was allowed: at most
-- [per_ip] in [window_minutes]. Generous enough that somebody closing the
-- window and trying again is never refused. An address that is not known
-- (a local server) is counted together.
create or replace function public.oc_may_try(from_ip text, per_ip integer default 20,
    window_minutes integer default 15)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    tried integer;
begin
    delete from public.oc_attempts where at < now() - interval '1 day';
    select count(*) into tried from public.oc_attempts
     where ip = coalesce(from_ip, '') and at >= now() - make_interval(mins => window_minutes);
    if tried >= per_ip then
        return false;
    end if;
    insert into public.oc_attempts (ip) values (coalesce(from_ip, ''));
    return true;
end;
$$;

-- Spend token [token_id] until [until]: true the first time, false ever
-- after while it lasts. Spent ids are let go once their token has expired,
-- when it could not sign anybody in anyway.
create or replace function public.oc_spend(token_id text, until timestamptz)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.oc_spent s where s.until < now();
    insert into public.oc_spent (jti, until) values (token_id, oc_spend.until)
        on conflict (jti) do nothing;
    return found;
end;
$$;

-- The account [did] signs in to, or null.
create or replace function public.oc_account_of(did text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select i.account from public.oc_identities i where i.did_oc = oc_account_of.did
$$;

-- [did] given to [account], made for it a moment ago: the account [did]
-- signs in to afterwards. When another sign-in of the same did got there
-- first, that one's account, and the caller deletes the one it made.
create or replace function public.oc_claim(did text, account uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.oc_identities (did_oc, account) values (oc_claim.did, oc_claim.account)
        on conflict (did_oc) do nothing;
    return (select i.account from public.oc_identities i where i.did_oc = oc_claim.did);
end;
$$;

-- The session [session] that [did] started on [account], with its token's
-- rh, aud and iat: true when it is bound, false when [did] is not
-- [account]'s (unlinked since the sign-in found it), and the caller ends
-- the session. The id's row is held while the binding is written, so an
-- unlink at the same moment either comes first (and this binds nothing) or
-- waits, and then ends this session with the rest (oc188's review, M1).
-- It returned nothing until 2026-10-24; the type of an answer cannot be
-- changed in place, so it is made again, in the same transaction.
drop function if exists public.oc_bind_session(uuid, uuid, text, text, text, bigint);
create function public.oc_bind_session(session uuid, account uuid, did text,
    rh text, aud text, iat bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    perform 1 from public.oc_identities i
     where i.did_oc = oc_bind_session.did and i.account = oc_bind_session.account
       for key share;
    if not found then
        return false;
    end if;
    insert into public.oc_sessions (session_id, account, did_oc, rh, aud, iat)
    values (oc_bind_session.session, oc_bind_session.account, oc_bind_session.did,
            oc_bind_session.rh, oc_bind_session.aud, oc_bind_session.iat);
    return true;
end;
$$;

-- What a request needs to know of session [session]: {exists, bound, did,
-- rh, aud, iat, linked}. exists is false once Supabase's session is gone
-- (signed out, unlinked, ended); bound, when orangecheck started it; linked,
-- whether the id that started it is still the account's (always, since
-- oc_bind_session checks it; a binding from before that is refused).
create or replace function public.oc_session_of(session uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'exists', exists (select 1 from auth.sessions s where s.id = oc_session_of.session),
        'bound', b.session_id is not null, 'did', b.did_oc, 'rh', b.rh, 'aud', b.aud, 'iat', b.iat,
        'linked', b.session_id is not null and exists (select 1 from public.oc_identities i
                                                        where i.did_oc = b.did_oc and i.account = b.account))
      from (select 1) one
      left join public.oc_sessions b on b.session_id = oc_session_of.session
$$;

-- Session [session] ended: Supabase's row deleted, and with it its refresh
-- tokens and its binding. True when there was one.
create or replace function public.oc_end_session(session uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from auth.sessions s where s.id = oc_end_session.session;
    return found;
end;
$$;

-- The orangecheck id [account] has, or null.
create or replace function public.oc_did_of(account uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select i.did_oc from public.oc_identities i where i.account = oc_did_of.account
$$;

-- [did] linked to [account], an account with its own sign-in: 'linked', or
-- why not: 'taken' (another account has that id) or 'has_one' (this account
-- has another). Linking the same id again changes nothing.
create or replace function public.oc_link(did text, account uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    whose uuid;
begin
    select i.account into whose from public.oc_identities i where i.did_oc = oc_link.did;
    if whose = oc_link.account then
        return 'linked';
    end if;
    if whose is not null then
        return 'taken';
    end if;
    if exists (select 1 from public.oc_identities i where i.account = oc_link.account) then
        return 'has_one';
    end if;
    insert into public.oc_identities (did_oc, account) values (oc_link.did, oc_link.account);
    return 'linked';
exception when unique_violation then
    return 'taken';
end;
$$;

-- The orangecheck id on [account] unlinked, and every session it started
-- there ended, and every Claude connection it approved, and every code for
-- one not yet exchanged (oc188's review, L2): {did, ended, connections,
-- codes}, or null when none was linked.
create or replace function public.oc_unlink(account uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    gone text;
    ended integer;
    connections integer;
    codes integer;
begin
    delete from public.oc_identities i where i.account = oc_unlink.account returning i.did_oc into gone;
    if gone is null then
        return null;
    end if;
    delete from auth.sessions s
     where s.id in (select b.session_id from public.oc_sessions b
                     where b.account = oc_unlink.account and b.did_oc = gone);
    get diagnostics ended = row_count;
    delete from public.oauth_grants g where g.owner = oc_unlink.account and g.oc_did = gone;
    get diagnostics connections = row_count;
    delete from public.oauth_codes c where c.owner = oc_unlink.account and c.oc_did = gone;
    get diagnostics codes = row_count;
    return jsonb_build_object('did', gone, 'ended', ended, 'connections', connections, 'codes', codes);
end;
$$;

revoke all on function public.oc_session_of(uuid) from public, anon, authenticated;
revoke all on function public.oc_end_session(uuid) from public, anon, authenticated;
revoke all on function public.oc_did_of(uuid) from public, anon, authenticated;
revoke all on function public.oc_link(text, uuid) from public, anon, authenticated;
revoke all on function public.oc_unlink(uuid) from public, anon, authenticated;
grant execute on function public.oc_session_of(uuid) to service_role;
grant execute on function public.oc_end_session(uuid) to service_role;
grant execute on function public.oc_did_of(uuid) to service_role;
grant execute on function public.oc_link(text, uuid) to service_role;
grant execute on function public.oc_unlink(uuid) to service_role;
revoke all on function public.oc_may_try(text, integer, integer) from public, anon, authenticated;
revoke all on function public.oc_spend(text, timestamptz) from public, anon, authenticated;
revoke all on function public.oc_account_of(text) from public, anon, authenticated;
revoke all on function public.oc_claim(text, uuid) from public, anon, authenticated;
revoke all on function public.oc_bind_session(uuid, uuid, text, text, text, bigint) from public, anon, authenticated;
grant execute on function public.oc_may_try(text, integer, integer) to service_role;
grant execute on function public.oc_spend(text, timestamptz) to service_role;
grant execute on function public.oc_account_of(text) to service_role;
grant execute on function public.oc_claim(text, uuid) to service_role;
grant execute on function public.oc_bind_session(uuid, uuid, text, text, text, bigint) to service_role;
