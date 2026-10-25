-- A library model its sharer changed keeps its credit, and says so,
-- 2026-10-25 (gallery261, the lead's review of modelled_by.sql).
--
-- modelled_by is now found in the app's own Library and never taken from
-- the file (api/_omr_credit.js): a model is a library model when it is
-- held to that model's own file, and one whose parts are not exactly the
-- library model's was changed by whoever shares it. Its card still says
-- who modelled it, and its page says "changed by" its sharer. So
-- modelled_by may also say changed: true.
--
--   modelled_by_ok   modelled_by.sql's, and an optional "changed", true;
--                    and false, not null, for anything not plainly so
--
-- Only that function, defined again: what it allowed it still allows, so
-- no row is changed by it, and the column's check goes on calling it.
-- Applied after modelled_by.sql (supabase/later.tsv). Until it is, a
-- changed library model is not credited (the server's write is refused
-- and the publish goes on), and an unchanged one is, as now.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/modelled_by_changed.sql --table=shared_models
--
-- tried first, rolled back:
--
--   ... --dry --try=tools/modelled_by_changed_try.sql --table=shared_models

create or replace function public.modelled_by_ok(said jsonb)
returns boolean
language sql
immutable
set search_path = public
as $$
    -- A missing key reads as null, and a check that comes to null passes:
    -- so anything not plainly so is false (modelled_by.sql's let
    -- {"page": ..., "x": 1} through with no name; nothing ever wrote one).
    select coalesce(said is null or (
        jsonb_typeof(said) = 'object'
        and not exists (select 1 from jsonb_object_keys(said) as k(key) where k.key not in ('name', 'page', 'changed'))
        and jsonb_typeof(said->'name') = 'string'
        and char_length(said->>'name') between 1 and 80
        and jsonb_typeof(said->'page') = 'string'
        and char_length(said->>'page') <= 200
        and (said->>'page') like 'https://library.ldraw.org/%'
        and (not (said ? 'changed') or said->'changed' = 'true'::jsonb)), false)
$$;

revoke all on function public.modelled_by_ok(jsonb) from public, anon, authenticated;
grant execute on function public.modelled_by_ok(jsonb) to service_role;
