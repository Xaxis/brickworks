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
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables
-- directly.
--
-- Only additions: four new tables and new functions. Applying it again
-- changes nothing.

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
-- rh, aud and iat.
create or replace function public.oc_bind_session(session uuid, account uuid, did text,
    rh text, aud text, iat bigint)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.oc_sessions (session_id, account, did_oc, rh, aud, iat)
    values (oc_bind_session.session, oc_bind_session.account, oc_bind_session.did,
            oc_bind_session.rh, oc_bind_session.aud, oc_bind_session.iat)
$$;

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
