-- Where each part is kept (partplaces, APP_UX9 #14, 2026-11-17).
--
-- A builder with a sorted collection keeps each part in a drawer, a box or a
-- tray, and walks to the same ones again and again. My collection keeps
-- where, by part and colour, and the booklet's parts box and the parts list
-- say it ("from drawer 3").
--
--   places   {"3001/4": "drawer 3", "3023/71": "B3", ...}: a part and colour
--            as the app spells it (Collection.key_of: the number a part
--            means today, the colour a shop files it under) -> the place,
--            one line of at most 40 characters as the person typed it
--            (api/collection.js placeText). Apart from the lots and the
--            sets, since a drawer holds a part and colour whatever brought
--            it: a set's parts, a Rebrickable list, the person's own lots.
--
-- Additive only: one column with a constant default (no row is rewritten:
-- every row kept before reads {} until it is next written) and its checks.
-- Nothing existing is dropped, retyped or changed.
--
-- The api live before this (rel-m308) reads sets, parts, updated_at, rev
-- and recent by name and writes only those: it goes on working, and never
-- touches places. The api after it reads every column (select=*), so it
-- works before this is applied too: it reads no places, and refuses to set
-- one (503, with words) until the column is there.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/partplaces.sql --dry --try=tools/partplaces_try.sql --table=collections
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/partplaces.sql --table=collections

alter table public.collections add column if not exists places jsonb not null default '{}'::jsonb;

-- The endpoint refuses anything over these first, with words (MAX_PLACES
-- places of MOST_PLACE characters); this is the ceiling a request that went
-- round it still meets: an object, and no bigger than 20,000 places of 40
-- characters and their keys would be.
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'collections_places_object') then
        alter table public.collections add constraint collections_places_object
            check (jsonb_typeof(places) = 'object');
    end if;
    if not exists (select 1 from pg_constraint where conname = 'collections_places_size') then
        alter table public.collections add constraint collections_places_size
            check (octet_length(places::text) <= 4000000);
    end if;
end
$$;

comment on column public.collections.places is
    'Where each part and colour is kept: {"3001/4": "drawer 3"}, written only through api/collection.js op place.';
