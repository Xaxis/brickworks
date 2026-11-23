-- Link-only lists (lists2a, 2026-11-23, docs/LISTS.md section 5 item 3;
-- after people.sql and lists.sql).
--
-- A list was public (its page /c/X, on its owner's profile, in the
-- gallery's Lists, the search and the sitemap) or its owner's alone. Now
-- there is a third way, Steam's (docs/LISTS.md section 1): shared by a
-- link. Its page opens at /c/X?link=<the link's key> for anybody who has
-- the link, and nowhere else: it stays private, so every reader that lists
-- public lists (profile_page, list_directory, collection_search,
-- sitemap_pages, model_lists, set_lists) leaves it out as it always left a
-- private list out, with no change to any of them. Its owner stops sharing
-- by taking the key away (link null); sharing again makes a new key, so an
-- old link never opens it again. A wishlist shared is shared this way
-- unless its owner makes it public.
--
--   model_collections.link     the key: 22 letters, digits, - and _ (16
--                              random bytes, base64url, api/_mylists.js
--                              newLink), one list's alone; null when it is
--                              not shared by a link
--   model_collections.link_at  when that key was made
--
-- One way at a time, whatever writes: a list made public, or taken down by
-- Brickworks (/admin, lists.sql taken_down_at), loses its key at once
-- (model_collections_link_guard), so a public list has no second address
-- and a taken-down list opens for nobody but its owner. The trigger clears
-- rather than refuses, so api/admin.js's take-down and api/people.js's
-- saveList, which know nothing of links, go on working unchanged.
--
-- Only additions: two columns, one check, one index, one trigger and its
-- function. Nothing dropped, nothing rewritten, no row changed (every row's
-- link starts null). Account deletion is as it was: model_collections
-- cascades from auth.users (people.sql), and the key is a column of the
-- list, so it goes with it. Row security as before: the service role
-- alone (people.sql).

alter table public.model_collections add column if not exists link text;
alter table public.model_collections add column if not exists link_at timestamptz;

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'model_collections_link_check') then
        alter table public.model_collections add constraint model_collections_link_check
            check (link is null or link ~ '^[A-Za-z0-9_-]{22}$');
    end if;
end;
$$;

-- A key opens one list.
create unique index if not exists model_collections_link
    on public.model_collections (link) where link is not null;

comment on column public.model_collections.link is
    'Shared by a link (lists2a): the key its link carries, /c/<id>?link=<key>; null when it is not. Never on a public or taken-down list.';
comment on column public.model_collections.link_at is
    'When its link''s key was made.';

create or replace function public.model_collections_link_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if new.link is not null and (new.public or new.taken_down_at is not null) then
        new.link := null;
        new.link_at := null;
    end if;
    if new.link is null then
        new.link_at := null;
    end if;
    return new;
end;
$$;

revoke all on function public.model_collections_link_guard() from public, anon, authenticated;

drop trigger if exists model_collections_link_guard on public.model_collections;
create trigger model_collections_link_guard
    before insert or update of link, public, taken_down_at on public.model_collections
    for each row execute function public.model_collections_link_guard();
