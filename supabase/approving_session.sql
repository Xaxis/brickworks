-- Every Claude code and connection names the session that approved it, and its
-- use asks that session as it is (signin6, 2026-11-25: a root redesign after
-- signreview2 SR1 and signreview3 R1), beside supabase/way_grants.sql,
-- way_links.sql, sign_in_ways.sql and orangecheck.sql, which this needs.
--
-- R1. A code approved from a Google or GitHub session took its way from
-- way_sessions, which goes with the session that the way's Unlink deletes. So
-- a code approved in the seconds after an Unlink (the approving instance still
-- held "the session exists" for 5 s) read as no way, an emailed code's, and its
-- connection outlived the Unlink. orangecheck's mark had the same shape. Now
-- the code carries the session itself, and the token exchange asks it, in one
-- locked step that also writes the connection:
--
--   oauth_codes.session_id   the session that approved the code. A key of
--                            auth.sessions, on delete cascade: a code goes
--                            with its session, and one cannot be written for
--                            a session that is gone (the key is checked as it
--                            is inserted, and a delete at that moment waits).
--   oauth_grants.session_id  the same, carried to the connection, for the
--                            record (a connection outlives a browser's sign
--                            out; an Unlink ends it by its way).
--   oauth_code_grant         the exchange (api/oauth.js token): under the lock
--                            of the way that started the session (way_set's
--                            for Google and GitHub, oc_unlink's row for
--                            orangecheck), the session held so that nothing
--                            ends it in between, it asks whether the session
--                            is still there and the owner's, which way started
--                            it, and whether that way still signs the account
--                            in; then writes the connection, with that way,
--                            and its two tokens, or nothing. {grant, way,
--                            oc_did, oc_rh, oc_aud, oc_iat}, or {refused:
--                            gone | unlinked | unknown}.
--   session_standing         a session as it is, in one read: {exists,
--                            account, way, bound, did, rh, aud, iat, linked}.
--                            What every grant of authority from a session asks
--                            (api/_auth.js standingOf), never a cached answer.
--
-- Only additions: two columns, null for every row already there (production
-- holds no code at a time but the two minutes' of one being traded), an
-- index, and two new functions, security definer and granted to the service
-- role alone, as the others are. Nothing existing is replaced. way_on and
-- way_session_of stay, unused by this code. Applying it again changes nothing.

alter table public.oauth_codes add column if not exists session_id uuid
    constraint oauth_codes_session references auth.sessions (id) on delete cascade;
create index if not exists oauth_codes_session on public.oauth_codes (session_id);
alter table public.oauth_grants add column if not exists session_id uuid;

create or replace function public.session_standing(session uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'exists', s.id is not null, 'account', s.user_id, 'way', w.way,
        'bound', b.session_id is not null, 'did', b.did_oc, 'rh', b.rh, 'aud', b.aud, 'iat', b.iat,
        'linked', b.session_id is not null and exists (select 1 from public.oc_identities i
                                                        where i.did_oc = b.did_oc and i.account = b.account))
      from (select 1) one
      left join auth.sessions s on s.id = session_standing.session
      left join public.way_sessions w on w.session_id = s.id
      left join public.oc_sessions b on b.session_id = s.id
$$;

-- The locks are taken in the order way_set and oc_unlink take theirs (the
-- way's, then the session's rows), so none waits on another in a circle.
create or replace function public.oauth_code_grant(session uuid, owner uuid, client text, client_name text,
    redirect_uri text, resource text, scope text,
    access_hash text, access_until timestamptz, refresh_hash text, refresh_until timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    started text;
    bound public.oc_sessions;
    made uuid;
begin
    if oauth_code_grant.session is null or oauth_code_grant.owner is null then
        return jsonb_build_object('refused', 'unknown');
    end if;
    -- The way that started it, read first so that its lock can be taken: a
    -- session's way is written before the session is handed out, and never
    -- changes. Read again below, under the lock.
    select w.way into started from public.way_sessions w
     where w.session_id = oauth_code_grant.session and w.account = oauth_code_grant.owner;
    if started is not null then
        perform pg_advisory_xact_lock(hashtextextended('way_links ' || oauth_code_grant.owner::text || ' ' || started, 0));
    end if;
    select * into bound from public.oc_sessions b
     where b.session_id = oauth_code_grant.session and b.account = oauth_code_grant.owner;
    if bound.session_id is not null then
        perform 1 from public.oc_identities i
         where i.did_oc = bound.did_oc and i.account = oauth_code_grant.owner
           for key share;
        if not found then
            return jsonb_build_object('refused', 'unlinked');
        end if;
    end if;
    -- The session as it is now, held until this commits: an Unlink, an
    -- orangecheck unlink or Sign out everywhere deleting it waits, and then
    -- deletes this connection with the rest.
    perform 1 from auth.sessions s
     where s.id = oauth_code_grant.session and s.user_id = oauth_code_grant.owner
       for key share;
    if not found then
        return jsonb_build_object('refused', 'gone');
    end if;
    if (select w.way from public.way_sessions w where w.session_id = oauth_code_grant.session) is distinct from started
       or exists (select 1 from public.oc_sessions b where b.session_id = oauth_code_grant.session) <> (bound.session_id is not null) then
        return jsonb_build_object('refused', 'unknown');
    end if;
    if started is not null and not exists (select 1 from public.way_links l
            where l.account = oauth_code_grant.owner and l.way = started and l.state = 'on') then
        return jsonb_build_object('refused', 'unlinked');
    end if;
    insert into public.oauth_grants (owner, client_id, client_name, redirect_uri, resource, scope, used_at,
                                     way, oc_did, oc_rh, oc_aud, oc_iat, session_id)
        values (oauth_code_grant.owner, oauth_code_grant.client, oauth_code_grant.client_name,
                oauth_code_grant.redirect_uri, oauth_code_grant.resource, oauth_code_grant.scope, now(),
                started, bound.did_oc, bound.rh, bound.aud, bound.iat, oauth_code_grant.session)
        returning id into made;
    insert into public.oauth_tokens (hash, grant_id, kind, expires_at)
        values (oauth_code_grant.access_hash, made, 'access', oauth_code_grant.access_until),
               (oauth_code_grant.refresh_hash, made, 'refresh', oauth_code_grant.refresh_until);
    return jsonb_build_object('grant', made, 'way', started, 'oc_did', bound.did_oc, 'oc_rh', bound.rh,
                              'oc_aud', bound.aud, 'oc_iat', bound.iat);
end;
$$;

revoke all on function public.session_standing(uuid) from public, anon, authenticated;
revoke all on function public.oauth_code_grant(uuid, uuid, text, text, text, text, text, text, timestamptz, text, timestamptz)
    from public, anon, authenticated;
grant execute on function public.session_standing(uuid) to service_role;
grant execute on function public.oauth_code_grant(uuid, uuid, text, text, text, text, text, text, timestamptz, text, timestamptz)
    to service_role;
