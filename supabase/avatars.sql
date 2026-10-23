-- Your own picture as your avatar, and your likes on your profile,
-- 2026-10-22 (docs/SOCIAL.md D11, U5, U6: the two pieces U6 left out).
--
-- An avatar is made from the handle (web/card.js avatarHtml: a coloured
-- tile and the initial), and nothing of it is kept. A person 13 or over
-- with a profile may put a picture of their own in its place, from Edit
-- profile, cropped to a circle in the page:
--
--   profile_avatars  one row an account: the picture it shows now. The
--                    picture is never the file that was sent:
--                    api/_avatars.js decodes it to its pixels and makes a
--                    new JPEG of them (api/_photo.js, as a build photo is
--                    made: no metadata survives, and what is not a JPEG, a
--                    PNG or a WebP does not decode), square, at most 400
--                    pixels a side, kept as avatars/<id>.jpg. A new picture
--                    is a new id, so a page's address for it is never
--                    stale; the old file is deleted once the new one is
--                    kept.
--     removed_at     taken out by the site's owner (api/admin.js, from a
--                    report about the profile): its file deleted from
--                    storage, the row kept to say so, and the avatar made
--                    from the handle shown again. A new picture of their
--                    own puts it back.
--
--   avatars_of(handles)  which of those people show a picture now, for
--                    the server to put on the cards, comments, feed rows
--                    and pages that show them: only of a profile that may
--                    be shown (shown_publicly: not taken out, not under 13)
--                    and a picture not taken out.
--
-- And whether a profile shows the models its owner liked:
--
--   profile_choices  one row an account: shows_likes, off until its owner
--                    turns it on in /settings (Privacy). Likes are told as
--                    counts on a model (docs/SOCIAL.md D1); a person may
--                    choose to show which they liked, as a tab on their
--                    profile, and nobody else may.
--   profile_likes(whose, size, skip, tests)  the models [whose] liked, newest
--                    like first, each as the gallery's card
--                    (directory_card, not changed here): only models the
--                    gallery shows, a test model only when asked for.
--   profile_likes_count(whose, tests)  how many of them, for the tab.
--   The API asks these only of a profile whose owner chose to show them.
--
-- The trust rules (docs/COMMUNITY.md): both rows need an account that said
-- it is 13 or over (trust.sql trust_guard_person, the profile's own
-- trigger); writes come only from api/people.js, counted by may_act.
--
-- Only additions: two tables, one private bucket, three functions. Nothing
-- that exists is changed, dropped or renamed; no function of another file
-- is replaced. Deleting the account deletes both rows (on delete cascade);
-- the picture's file is deleted by name first (api/account.js), since
-- storage keeps no link to the account. The tables and the bucket are the
-- server's alone: row security on, no policy, nothing granted to a page's
-- key.
--
-- Until this is applied, every avatar is the one made from the handle, no
-- profile has a Likes tab, and asking to add a picture or to show your
-- likes says it is not open yet (503). Everything else works as before.

create table if not exists public.profile_avatars (
    account     uuid primary key references auth.users (id) on delete cascade,
    id          text not null unique check (id ~ '^[A-Za-z0-9]{10}$'),
    side        integer not null check (side between 120 and 400),
    bytes       integer not null check (bytes between 1 and 1048576),
    was         text not null check (was in ('jpeg', 'png', 'webp')),
    at          timestamptz not null default now(),
    removed_at  timestamptz,
    removed_why text check (removed_why is null or char_length(removed_why) between 1 and 200)
);
alter table public.profile_avatars enable row level security;
revoke all on public.profile_avatars from anon, authenticated;

comment on table public.profile_avatars is
    'A person''s own picture as their avatar, made safe (supabase/avatars.sql, api/_avatars.js).';

create or replace trigger profile_avatars_guard
    before insert or update on public.profile_avatars
    for each row execute function public.trust_guard_person();

create table if not exists public.profile_choices (
    account     uuid primary key references auth.users (id) on delete cascade,
    shows_likes boolean not null default false,
    updated_at  timestamptz not null default now()
);
alter table public.profile_choices enable row level security;
revoke all on public.profile_choices from anon, authenticated;

comment on table public.profile_choices is
    'What a person chose their profile shows: the models they liked (supabase/avatars.sql).';

create or replace trigger profile_choices_guard
    before insert or update on public.profile_choices
    for each row execute function public.trust_guard_person();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg'])
on conflict (id) do nothing;

-- Which of [handles] show a picture of their own now: {handle, avatar}.
create or replace function public.avatars_of(handles text[])
returns table (handle text, avatar text)
language sql
stable
security definer
set search_path = public
as $$
    select p.handle, a.id
      from public.people p
      join public.profile_avatars a on a.account = p.account
     where p.handle = any (handles)
       and a.removed_at is null
       and public.shown_publicly(p.account)
$$;
revoke all on function public.avatars_of(text[]) from public, anon, authenticated;
grant execute on function public.avatars_of(text[]) to service_role;

-- The models [whose] liked that the gallery shows, newest like first.
create or replace function public.profile_likes(whose uuid, size integer default 25, skip integer default 0,
                                                tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select public.directory_card(m)
      from public.model_likes l
      join public.shared_models m on m.id = l.model
     where l.account = whose
       and m.published and m.listed and not m.barred
       and (tests or not m.test)
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
     order by l.at desc, m.id
     limit least(greatest(coalesce(size, 25), 1), 49)
    offset least(greatest(coalesce(skip, 0), 0), 20000)
$$;
revoke all on function public.profile_likes(uuid, integer, integer, boolean) from public, anon, authenticated;
grant execute on function public.profile_likes(uuid, integer, integer, boolean) to service_role;

create or replace function public.profile_likes_count(whose uuid, tests boolean default false)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer
      from public.model_likes l
      join public.shared_models m on m.id = l.model
     where l.account = whose
       and m.published and m.listed and not m.barred
       and (tests or not m.test)
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
$$;
revoke all on function public.profile_likes_count(uuid, boolean) from public, anon, authenticated;
grant execute on function public.profile_likes_count(uuid, boolean) to service_role;
