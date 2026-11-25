-- Your own moulds on your account, 2026-11-25 (sitehair; owner ask #14,
-- "build custom 3D moulds for hair pieces").
--
-- The studio's minifig builder makes a mould of a person's own: a hair, a hat
-- or a helmet shaped from a real part (src/minifig/mould.gd, Headgear > Make a
-- mould…). It is a plain LDraw part file: triangles in LDU in LDraw's axes,
-- colour 16 the colour the figure wears it in, and a line
-- `0 // Moulded by Brickworks: from=<base>` naming the part it was shaped from,
-- whose placement it keeps. The app keeps it on the device
-- (user://custom_parts/<id>.dat) and inside each model that uses it. Signed
-- in, it now keeps a copy here too, the moment it is saved
-- (src/ui/minifig_dialog.gd, POST /api/people?op=mould), so Edit profile's
-- minifig maker on the site (web/minifig-maker.js) can list it beside the
-- catalogue's hair and put it on the figure their avatar is drawn of:
--
--   own_moulds   one row a mould an account saved: its id (the app's own,
--                bw-<base>-m-<20 hex digits of the SHA-256 of its text>, so
--                one text is one id; api/_moulds.js checks the digits against
--                the text before it is kept), the slot it was made for, the
--                part it was shaped from, its name, how many triangles and
--                bytes it is, and its text. At most 2 MB a mould (a mould is
--                at most 18,000 triangles, Mould.MOST_OPENED; 9,000 once
--                shaped finer, about half a megabyte), and at most 40 moulds
--                and 24 MB an account (own_moulds_cap, below).
--
-- Who reads it (api/_moulds.js; the table is the server's alone): its owner,
-- to list and wear it; and anybody, for a mould a shown avatar wears now
-- (profile_avatars.minifig->>'hd', not taken out, the profile shown in
-- public), as the picture drawn of it is anybody's to see. Nothing else of
-- anybody's moulds is read by anyone. The text is sent to a browser once and
-- kept there for good (Cache-Control: private, immutable: an id is its text),
-- never by the CDN, and never re-read per page view: an avatar is the
-- picture the maker drew (avatars.sql), not the mould.
--
-- Additive only: one table, one trigger function and its trigger, one index on
-- profile_avatars. Nothing that exists is changed, dropped or renamed; no
-- function of another file is replaced. Row security on, no policy, nothing
-- granted to a page's key: only api/_moulds.js reads or writes it, with the
-- secret key. Deleting the account deletes its moulds (on delete cascade).
--
-- Until this is applied, the app's save says nothing more than it does today
-- (the copy is not kept, and it is sent again next time), and the site's
-- maker shows the catalogue's hair alone (GET ?op=moulds answers ready:false).

create table if not exists public.own_moulds (
    account    uuid not null references auth.users (id) on delete cascade,
    id         text not null check (id ~ '^bw-[0-9a-z]{0,10}-m-[0-9a-f]{20}$'),
    slot       text not null check (slot in ('headwear', 'hat_extra', 'head', 'neck', 'back', 'cape', 'torso', 'arms',
                   'hands', 'hips', 'hipwear', 'legs', 'footwear', 'accessory', 'accessory_left')),
    base       text not null check (base ~ '^[0-9A-Za-z._-]{1,64}$'),
    name       text not null check (char_length(name) between 1 and 120),
    triangles  integer not null check (triangles between 1 and 18000),
    bytes      integer not null check (bytes between 1 and 2097152),
    text       text not null check (octet_length(text) = bytes),
    at         timestamptz not null default now(),
    primary key (account, id)
);
alter table public.own_moulds enable row level security;
revoke all on public.own_moulds from anon, authenticated;

comment on table public.own_moulds is
    'Moulds a person made in the studio, kept on their account for the site''s minifig maker '
    '(supabase/own_moulds.sql, api/_moulds.js).';

-- At most 40 moulds and 24 MB an account. A mould saved again (the same id)
-- replaces its row and is counted once. Saves to one account take turns: the
-- lock is held until the save's transaction ends, and the count after it
-- (a new statement, so a new snapshot) sees the save before it. Without it
-- two saves at the same moment both counted 39 and both were kept.
create or replace function public.own_moulds_cap() returns trigger
    language plpgsql
    set search_path = public
as $$
declare
    many   integer;
    weight bigint;
begin
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('own_moulds ' || new.account::text, 0));
    select count(*), coalesce(sum(bytes), 0) into many, weight
        from public.own_moulds where account = new.account and id <> new.id;
    if many >= 40 then
        raise exception 'own_moulds: at most 40 moulds an account' using errcode = 'check_violation';
    end if;
    if weight + new.bytes > 24 * 1024 * 1024 then
        raise exception 'own_moulds: at most 24 MB of moulds an account' using errcode = 'check_violation';
    end if;
    return new;
end;
$$;
revoke all on function public.own_moulds_cap() from public, anon, authenticated;

create or replace trigger own_moulds_cap
    before insert or update on public.own_moulds
    for each row execute function public.own_moulds_cap();

-- Which avatar wears a mould, for the one read anybody may make of it.
create index if not exists profile_avatars_worn_hair on public.profile_avatars ((minifig ->> 'hd'))
    where minifig is not null and removed_at is null;
