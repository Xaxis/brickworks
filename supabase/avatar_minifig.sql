-- A minifigure you made as your avatar, 2026-11-23 (avatarkit; the owner:
-- "a brickworks avatar generator that is obviously lego minifig themed ...
-- they should still obviously have the option to upload their own image").
--
-- A minifigure made in Edit profile (web/minifig-maker.js) is kept as a
-- person's picture, the same row and file as a picture of their own
-- (supabase/avatars.sql, api/_avatars.js): the picture the maker drew of it,
-- made into a JPEG as any picture is. What it was made of is kept beside it
-- so the maker opens on it again:
--
--   profile_avatars.minifig   the recipe (web/card.js minifigShape: which
--                             face, hair or hat and its colour, print, torso
--                             and legs colours, background), held to the
--                             maker's lists by the API before it is kept;
--                             null for a picture of their own.
--
-- Additive: one column that may be null. Until it is applied a minifigure is
-- still kept as the picture, and the maker opens on the one made from the
-- handle (api/_avatars.js keepRecipe says nothing of a column not there).

alter table public.profile_avatars add column if not exists minifig jsonb
    check (minifig is null or (jsonb_typeof(minifig) = 'object' and octet_length(minifig::text) <= 400));

comment on column public.profile_avatars.minifig is
    'What the minifigure this picture is was made of (web/card.js minifigShape); null for a picture of their own.';
