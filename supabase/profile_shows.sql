-- What a profile shows besides its name and its words, 2026-10-22
-- (docs/SOCIAL.md U5, D11; the owner: "the users account/profile page
-- needs to be drastically improved").
--
-- A person's page at /u/<handle> (api/people.js profilePage) leads with
-- their avatar, name, handle, bio and numbers, then the models they pinned,
-- then tabs: Models, Builds, Collections. Three things on it are chosen by
-- its owner and kept here, one row an account:
--
--   links    one or two addresses of theirs elsewhere (a portfolio, a
--            Flickr), each https and at most 200 characters; shown as
--            its domain and path, rel="ugc nofollow"
--   banner   one of their own models, whose picture is the band across
--            the top of the page: chosen, never an upload. Shown only
--            while that model is theirs, published, listed, credited to
--            them, not taken out, and has a picture
--   pins     up to three of their own models, in the order they chose,
--            shown above the tabs. Shown only while each is as the banner
--            must be (a picture or not)
--
-- The avatar is made from the handle (web/card.js avatarHtml: a coloured
-- tile and the initial, never a figure's likeness), so nothing of it is
-- kept. An uploaded picture is for later (U6), through the build photos'
-- pipeline.
--
-- The trust rules (docs/COMMUNITY.md): the row is public only as the
-- profile is (api/people.js asks shown_publicly, as for the profile), and
-- the same trigger as the profile's (trust.sql trust_guard_person) refuses
-- a row for an account that has not said it is 13 or over. Writes come
-- only from api/people.js ?op=showcase, counted by may_act.
--
-- Only an addition, applied after trust.sql: a table, a check function
-- and a trigger. Nothing is changed, dropped or renamed. The table is the
-- server's alone, as people is (row security on, no policy, nothing
-- granted to the publishable key): a visitor sees it only through the
-- profile's page and ?op=profile, which say for themselves what is
-- public. Deleting the account deletes the row (on delete cascade). A
-- model deleted leaves its id here, which nothing shows; the next save
-- drops it.
--
-- Until this is applied the page shows no links, banner or pins, and
-- ?op=showcase says they are not open yet (503). Everything else works
-- as before.

-- One or two links, each https, printable, at most 200 characters.
create or replace function public.profile_links_ok(links text[])
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
    select links is not null
       and coalesce(array_length(links, 1), 0) <= 2
       and not exists (
           select 1 from unnest(links) as link
            where link is null
               or char_length(link) not between 12 and 200
               or link !~ '^https://[^/?#@[:space:]]+\.[^/?#@[:space:]]+([/?#][^[:space:][:cntrl:]]*)?$')
$$;

-- Up to three model ids, none twice.
create or replace function public.profile_pins_ok(pins text[])
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
    select pins is not null
       and coalesce(array_length(pins, 1), 0) <= 3
       and not exists (select 1 from unnest(pins) as pin where pin is null or pin !~ '^[A-Za-z0-9]{10}$')
       and (select count(distinct pin) from unnest(pins) as pin) = coalesce(array_length(pins, 1), 0)
$$;

create table if not exists public.profile_shows (
    account     uuid primary key references auth.users (id) on delete cascade,
    links       text[] not null default '{}' check (public.profile_links_ok(links)),
    banner      text check (banner is null or banner ~ '^[A-Za-z0-9]{10}$'),
    pins        text[] not null default '{}' check (public.profile_pins_ok(pins)),
    updated_at  timestamptz not null default now()
);
alter table public.profile_shows enable row level security;
revoke all on public.profile_shows from anon, authenticated;

comment on table public.profile_shows is
    'What a profile shows besides its name and words: links, a banner (one of the '
    'owner''s models) and pinned models (supabase/profile_shows.sql, api/people.js).';

-- 13 or over, as the profile itself (trust.sql).
create or replace trigger profile_shows_guard
    before insert or update on public.profile_shows
    for each row execute function public.trust_guard_person();

revoke all on function public.profile_links_ok(text[]) from public, anon, authenticated;
grant execute on function public.profile_links_ok(text[]) to service_role;
revoke all on function public.profile_pins_ok(text[]) from public, anon, authenticated;
grant execute on function public.profile_pins_ok(text[]) to service_role;
