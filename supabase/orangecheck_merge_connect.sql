-- orangecheck, step 4 (2026-10-24, unit oc225), beside supabase/orangecheck.sql.
--
--   oc_handles    every rh a sign-in or a link brought (the token's handle
--                 for this site, which names nobody), with the orangecheck
--                 id it came with. When somebody merges two orangecheck
--                 accounts, the one they stop using no longer signs in, and
--                 a token of the one they keep carries merged_rh: our handle
--                 for each account merged into it. Looked up here
--                 (api/_oc.js merged, orangecheck's matchMergedUser), the id
--                 they keep follows to the Brickworks account they had. Gone
--                 with its id (on delete cascade): an id unlinked, or its
--                 account deleted, leaves no handle to walk back in by.
--                 Moved with it (on update cascade): a merge gives the
--                 account the new id, and its old handles go with it.
--   oc_connected  each account orangecheck Connect was asked to make an
--                 orangecheck account for, at the person's own tick of the
--                 box under Sign in with orangecheck (web/account.js), and
--                 the id it made. Written before orangecheck is asked, so
--                 deleting the account deletes that one too
--                 (api/account.js, connectDelete) even when the answer was
--                 lost.
--
-- Who may touch what, as in orangecheck.sql: only the server, through the
-- functions here, each security definer and granted to the service role
-- alone. Only additions: two tables and new functions. The handles of
-- sessions already bound are copied in once. Applying it again changes
-- nothing.

create table if not exists public.oc_handles (
    rh      text primary key,
    did_oc  text not null references public.oc_identities (did_oc) on delete cascade on update cascade,
    aud     text not null,
    seen_at timestamptz not null default now()
);
create index if not exists oc_handles_did on public.oc_handles (did_oc);

create table if not exists public.oc_connected (
    account  uuid primary key references auth.users (id) on delete cascade,
    did_oc   text constraint oc_connected_did check (did_oc is null or did_oc ~ '^did:oc:[0-9a-f]{32}$'),
    asked_at timestamptz not null default now(),
    made_at  timestamptz
);

alter table public.oc_handles enable row level security;
alter table public.oc_connected enable row level security;
revoke all on public.oc_handles from public, anon, authenticated, service_role;
revoke all on public.oc_connected from public, anon, authenticated, service_role;

-- Every session bound so far brought a handle: kept, for the ids still
-- linked to the account they started a session on.
insert into public.oc_handles (rh, did_oc, aud, seen_at)
select distinct on (b.rh) b.rh, b.did_oc, b.aud, b.started_at
  from public.oc_sessions b
  join public.oc_identities i on i.did_oc = b.did_oc and i.account = b.account
 order by b.rh, b.started_at
    on conflict (rh) do nothing;

-- [rh], a token for [aud]'s handle, kept with [did], the id it signed in
-- or linked with: true when it is kept, false when [did] is linked to no
-- account any more (unlinked since), and nothing is.
create or replace function public.oc_keep_handle(did text, rh text, aud text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.oc_handles (rh, did_oc, aud)
    values (oc_keep_handle.rh, oc_keep_handle.did, oc_keep_handle.aud)
        on conflict on constraint oc_handles_pkey do nothing;
    return true;
exception when foreign_key_violation then
    return false;
end;
$$;

-- The account each of [handles], for [aud], names, through the id it was
-- kept with: [{rh, account}], the handles that name nobody left out.
create or replace function public.oc_accounts_of_handles(handles text[], aud text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('rh', h.rh, 'account', i.account)), '[]'::jsonb)
      from public.oc_handles h
      join public.oc_identities i on i.did_oc = h.did_oc
     where h.rh = any(oc_accounts_of_handles.handles) and h.aud = oc_accounts_of_handles.aud
$$;

-- [did], an orangecheck id with no account here whose token names
-- [handles] as merged into it, given to [account], the one account those
-- handles name: {account, email, was, ended} (email, the account's, to be
-- told), or null when that no longer holds
-- (the caller asks the person to try again). In one transaction, under the
-- same rules as linking: [did] still has no account, and the handles still
-- name [account] alone, through the id it has now. That id is replaced by
-- [did] (its handles follow), and whatever the old id started there ends,
-- as unlinking ends it: its sessions, its Claude connections and their
-- codes. The account's row is held while it is written, so an unlink at
-- the same moment comes first or waits.
create or replace function public.oc_follow_merge(did text, account uuid, handles text[], aud text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    was text;
    named uuid[];
    ended integer;
begin
    select i.did_oc into was from public.oc_identities i where i.account = oc_follow_merge.account for update;
    if was is null or was = oc_follow_merge.did then
        return null;
    end if;
    if exists (select 1 from public.oc_identities i where i.did_oc = oc_follow_merge.did) then
        return null;
    end if;
    select array_agg(distinct i.account) into named
      from public.oc_handles h
      join public.oc_identities i on i.did_oc = h.did_oc
     where h.rh = any(oc_follow_merge.handles) and h.aud = oc_follow_merge.aud;
    if named is distinct from array[oc_follow_merge.account] then
        return null;
    end if;
    delete from auth.sessions s
     where s.id in (select b.session_id from public.oc_sessions b
                     where b.account = oc_follow_merge.account and b.did_oc = was);
    get diagnostics ended = row_count;
    delete from public.oauth_grants g where g.owner = oc_follow_merge.account and g.oc_did = was;
    delete from public.oauth_codes c where c.owner = oc_follow_merge.account and c.oc_did = was;
    update public.oc_identities i set did_oc = oc_follow_merge.did, linked_at = now()
     where i.account = oc_follow_merge.account;
    return jsonb_build_object('account', oc_follow_merge.account, 'was', was, 'ended', ended,
        'email', (select u.email from auth.users u where u.id = oc_follow_merge.account));
exception when unique_violation then
    return null;
end;
$$;

-- Connect asked for [account], at its tick, before orangecheck is asked.
create or replace function public.oc_connect_asked(account uuid)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.oc_connected (account) values (oc_connect_asked.account)
        on conflict (account) do update set asked_at = now()
$$;

-- What orangecheck made for [account]: [did].
create or replace function public.oc_connect_made(account uuid, did text)
returns void
language sql
security definer
set search_path = public
as $$
    update public.oc_connected c set did_oc = oc_connect_made.did, made_at = now()
     where c.account = oc_connect_made.account
$$;

-- Whether Connect was ever asked for [account]: {did, asked_at, made_at},
-- or null.
create or replace function public.oc_connected_of(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('did', c.did_oc, 'asked_at', c.asked_at, 'made_at', c.made_at)
      from public.oc_connected c where c.account = oc_connected_of.account
$$;

revoke all on function public.oc_keep_handle(text, text, text) from public, anon, authenticated;
revoke all on function public.oc_accounts_of_handles(text[], text) from public, anon, authenticated;
revoke all on function public.oc_follow_merge(text, uuid, text[], text) from public, anon, authenticated;
revoke all on function public.oc_connect_asked(uuid) from public, anon, authenticated;
revoke all on function public.oc_connect_made(uuid, text) from public, anon, authenticated;
revoke all on function public.oc_connected_of(uuid) from public, anon, authenticated;
grant execute on function public.oc_keep_handle(text, text, text) to service_role;
grant execute on function public.oc_accounts_of_handles(text[], text) to service_role;
grant execute on function public.oc_follow_merge(text, uuid, text[], text) to service_role;
grant execute on function public.oc_connect_asked(uuid) to service_role;
grant execute on function public.oc_connect_made(uuid, text) to service_role;
grant execute on function public.oc_connected_of(uuid) to service_role;
