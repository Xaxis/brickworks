-- Who modelled a model somebody else made, and its own licence, 2026-10-25
-- (gallery261; walk256 W6, the gallery all the house's).
--
-- The gallery's shelf from the LDraw library: real builders' models of
-- real sets, from LDraw's Official Model Repository, which the app already
-- opens as its Library. The house shares them, so a card and a page would
-- say "Brickworks", since a credit is the sharer's profile (api/share.js,
-- walk180), and its licence words would ask to credit the house for
-- somebody else's work. And almost all of them are CCAL 2.0, which LDraw's
-- CAreadme.txt says is CC BY 2.0, a licence the site did not know: calling
-- them CC BY 4.0 would relicense another person's work.
--
--   shared_models.licence      may also be 'cc-by-2.0' (CC BY 2.0, LDraw's
--                              CCAL 2.0), beside the three it had
--   shared_models.modelled_by  {name, page}: whom the model's own file
--                              credits as the library does (the app's
--                              "0 !BRICKWORKS CREDIT" line, from LDraw's
--                              Official Model Repository, its page on
--                              library.ldraw.org), written by api/share.js
--                              from the file it is sent; null for a model
--                              its sharer made, which every model has now
--   directory_card             made_with.sql's, and modelled_by: the card
--                              and the page (directory_model reads it)
--                              say "Modelled by" that person, and the
--                              licence words credit them
--
-- Only additions. The licence's check is put back wider, the three it
-- allowed still allowed, so no row is changed by it. No row is written:
-- every model keeps null until a file crediting somebody is published.
-- Applied after made_with.sql, whose directory_card this supersedes
-- (supabase/later.tsv). To take it back: made_with.sql's directory_card
-- again, and the column dropped once nothing reads it.
--
-- Who may touch it: the server alone (supabase/client_exposure.sql). The
-- column is granted to nobody, written by api/share.js as the service
-- role, and read only through directory_card, a security definer granted
-- to the service role alone.
--
-- Applied by the lead:
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/modelled_by.sql --table=shared_models
--
-- tried first, rolled back, with what tools/modelled_by_try.sql asks:
--
--   ... node tools/apply_sql.mjs supabase/modelled_by.sql --dry \
--         --try=tools/modelled_by_try.sql --table=shared_models
--   node tools/sql_compare.mjs supabase/modelled_by.sql modelled_by

-- ---------------------------------------------------------------------------
-- The licence: CC BY 2.0 too. Whatever the check was named, each check on
-- the column goes and one wider comes back, in the one transaction.

do $$
declare
    named text;
begin
    for named in
        select c.conname from pg_constraint c
         where c.conrelid = 'public.shared_models'::regclass and c.contype = 'c'
           and pg_get_constraintdef(c.oid) like '%licence%'
           and pg_get_constraintdef(c.oid) like '%all-rights-reserved%'
    loop
        execute format('alter table public.shared_models drop constraint %I', named);
    end loop;
end
$$;

alter table public.shared_models
    add constraint shared_models_licence_check
    check (licence is null or licence in ('cc-by-4.0', 'cc-by-sa-4.0', 'all-rights-reserved', 'cc-by-2.0'));

-- ---------------------------------------------------------------------------
-- Whom the file credits: a name, and its page in LDraw's library.

create or replace function public.modelled_by_ok(said jsonb)
returns boolean
language sql
immutable
set search_path = public
as $$
    select said is null or (
        jsonb_typeof(said) = 'object'
        and (select count(*) from jsonb_object_keys(said)) = 2
        and jsonb_typeof(said->'name') = 'string'
        and char_length(said->>'name') between 1 and 80
        and jsonb_typeof(said->'page') = 'string'
        and char_length(said->>'page') <= 200
        and (said->>'page') like 'https://library.ldraw.org/%')
$$;

alter table public.shared_models
    add column if not exists modelled_by jsonb
    check (public.modelled_by_ok(modelled_by));

-- Granted to no client, should a grant on the table ever be made again.
revoke select (modelled_by), insert (modelled_by), update (modelled_by), references (modelled_by)
    on public.shared_models from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The card, as made_with.sql made it, and modelled_by.

create or replace function public.directory_card(m public.shared_models)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', m.id, 'name', m.name, 'author', m.author, 'parts', m.parts,
        'has_image', m.has_image, 'has_thumb', m.has_thumb,
        'listed_at', m.listed_at, 'updated_at', m.updated_at,
        'kind', m.kind, 'tags', to_jsonb(m.tags), 'licence', m.licence,
        'steps', m.steps, 'own_steps', m.own_steps, 'technic', m.technic,
        'views', coalesce(s.views, 0), 'likes', coalesce(s.likes, 0),
        'builds', coalesce(s.builds, 0),
        'remixes', (select count(*) from public.shared_models r
                     where r.remixed_from = m.id and r.published),
        'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                 from public.people p
                where p.account = m.owner and m.author is not null
                  and not public.trust_kept_private(m.owner)),
        'tested', public.model_tested(m.id),
        -- Who laid its parts, as its app said (null: it did not, and the
        -- card reads its tags).
        'made_with', m.made_with,
        -- Who modelled it, when that is somebody else: its file's credit,
        -- from LDraw's library (null: its sharer made it).
        'modelled_by', m.modelled_by,
        'moves', to_jsonb(m.moves),
        'motions', to_jsonb(m.motions),
        -- What a visitor may read on its page (comments_on, asked by nobody).
        'comments', (select count(*) from public.model_comments k
                      where k.model = m.id and k.removed_at is null and k.hidden_at is null
                        and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = m.id),
                                             '-infinity'::timestamptz)
                        and public.shown_publicly(k.author)
                        and public.comment_parent_shown(k.parent)))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.modelled_by_ok(jsonb) from public, anon, authenticated;
grant execute on function public.modelled_by_ok(jsonb) to service_role;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
