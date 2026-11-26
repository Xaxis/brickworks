-- A Claude connection approved from a Google or GitHub sign-in ends with that
-- way's Unlink (signin5, 2026-11-25: signreview2 SR1), beside
-- supabase/way_links.sql, which this needs.
--
-- SR1. Unlinking Google or GitHub ended every session the way started
-- (way_set), but a connection (oauth_grants) approved while signed in with
-- it lived on: its tokens still listed the tools, renewed, and reached the
-- person's own tab. A sign-in by orangecheck carries its id over to the codes
-- and connections it approves (oc_did, supabase/orangecheck.sql), and
-- oc_unlink deletes them. Now a way's does the same:
--
--   oauth_codes.way     the way that started the session approving
--   oauth_grants.way    (api/oauth.js codeFor, from way_sessions), carried
--                       from the code to the connection; null for a code's
--                       sign-in and orangecheck's.
--   way_set             unlinked (on false): as before, and in the same
--                       locked step every connection and code that way
--                       approved for the account deleted (their tokens go
--                       with the connection, oauth_tokens on delete cascade).
--   way_on              true when the way signs the account in ('on'), read
--                       under way_set's lock, so an Unlink under way is
--                       waited for: asked by /oauth/token after it writes a
--                       connection from a way's code, for an Unlink that came
--                       between the code's read and that write.
--
-- Only additions: two columns, null for every row already there, and one new
-- function, security definer and granted to the service role alone as the
-- others are. way_set is replaced from production's body as it was on
-- 2026-11-25 (read with pg_get_functiondef: the same as way_links.sql's), its
-- two deletes added and nothing else changed. Applying it again changes
-- nothing.

alter table public.oauth_codes add column if not exists way text
    constraint oauth_codes_way check (way in ('google', 'github'));
alter table public.oauth_grants add column if not exists way text
    constraint oauth_grants_way check (way in ('google', 'github'));

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
    delete from public.oauth_grants g where g.owner = way_set.account and g.way = way_set.way;
    delete from public.oauth_codes c where c.owner = way_set.account and c.way = way_set.way;
    return ended;
end;
$$;

create or replace function public.way_on(account uuid, way text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    perform pg_advisory_xact_lock(hashtextextended('way_links ' || way_on.account::text || ' ' || way_on.way, 0));
    return exists (select 1 from public.way_links l
                    where l.account = way_on.account and l.way = way_on.way and l.state = 'on');
end;
$$;

revoke all on function public.way_set(uuid, text, boolean) from public, anon, authenticated;
revoke all on function public.way_on(uuid, text) from public, anon, authenticated;
grant execute on function public.way_set(uuid, text, boolean) to service_role;
grant execute on function public.way_on(uuid, text) to service_role;
