-- A set's versions (sethub, 2026-11-23; docs/PLAN.md row 2): the models in
-- the gallery that are a copy of the set's own LDraw model, as people
-- published them from Make your own version on the set's page.
--
-- Make your own version opens LDraw's model of the set in the studio, which
-- writes its credit into the file (0 !BRICKWORKS CREDIT); a publish holds
-- the file to the Library's (api/_omr_credit.js libraryCredit), credits its
-- modeller, and counts it as the set's own model (api/_alts.js countRows:
-- model_alt_sets role 'own', supabase/alt_builds.sql). set_built leaves
-- those out, as they are no alternate of the set; this lists them:
--
--   set_versions(set_number, tests)   the gallery's models that are a
--                   version of the set, as gallery cards, each with
--                   [changed] (its parts are not exactly LDraw's model's:
--                   modelled_by.changed) and [pieces]; changed first, then
--                   the newest; at most 24. With [tests], test models too.
--
-- Read by api/_bases.js setBased (GET /api/share?op=set_based), which the
-- set's page asks for (web/set-page.js), kept by the CDN 20 s, so a version
-- published shows on the set's page within a minute.
--
-- Only an addition: one function, security definer, granted to the service
-- role alone, reading tables alt_builds.sql made. Nothing is changed,
-- dropped or renamed. Applied after alt_builds.sql (model_alt_sets,
-- model_alts), made_with.sql and wip.sql (directory_card, gallery_shows).
--
-- Dry run (rolled back), with what tools/set_versions_try.sql asks:
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/set_versions.sql --dry \
--       --try=tools/set_versions_try.sql --table=model_alt_sets
--
-- Applied by the lead: the same without --dry and --try.

create or replace function public.set_versions(set_number text, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(public.directory_card(t.m)
               || jsonb_build_object('changed', t.changed, 'pieces', t.have)
             order by t.changed desc, t.listed_at desc nulls last, t.id), '[]'::jsonb)
      from (select m, m.id, m.listed_at, s.have,
                   coalesce((m.modelled_by->>'changed')::boolean, false) as changed
              from public.model_alt_sets s
              join public.shared_models m on m.id = s.model
             where s.set_number = lower(set_versions.set_number)
               and s.role = 'own'
               and public.gallery_shows(m, set_versions.tests)
             order by 5 desc, m.listed_at desc nulls last, m.id
             limit 24) t
$$;

revoke all on function public.set_versions(text, boolean) from public, anon, authenticated;
grant execute on function public.set_versions(text, boolean) to service_role;
