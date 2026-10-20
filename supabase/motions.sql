-- Motions, 2026-10-20: a model's own named movements, on its gallery card.
--
-- A model carries its motions in its file (docs/MOTIONS.md), as LDraw meta
-- lines the app writes into every text of it, the one a shared link
-- publishes included:
--
--   0 !BRICKWORKS MOTION "Open the dome" AFTER "" SECONDS 3
--
-- Its link plays each by a button over the 3D view (src/ui/share_view.gd).
-- api/share.js reads the names from the text published (api/_directory.js
-- motionsIn: each once, only a motion that moves something, twelve at most
-- of 60 characters) and keeps them here, so the gallery's card says what
-- the model does in its builder's words, "Moves: open the dome, extend the
-- telescope", where play.sql's words say only "Moves: steering, boom".
--
-- Only additions, applied after play.sql, whose directory_card this
-- supersedes:
--
--   shared_models.motions   the motions' names, as the text last published
--                           has them; empty for none, and for every model
--                           published before this (each row gets an empty
--                           list, and its next publish says).
--   motion_names_ok         whether a list of them is one the server keeps.
--   directory_card          play.sql's, and motions. directory_model, the
--                           shelves and the week's pick read it, so a
--                           model's page says them too.
--
-- Until this is applied the site works as before: api/share.js keeps the
-- words alone when there is no column for the names, and a card with no
-- motions says play.sql's words.
--
-- Who may touch what is as it was: the server, through the functions, each
-- granted to the service role alone; api/share.js writes motions with the
-- model's row. No existing value is changed, nothing dropped or renamed.

-- Not to wait on a busy table: the column is added under a lock on it.
set local lock_timeout = '5s';

-- Twelve names at most, each 1 to 60 printing characters.
create or replace function public.motion_names_ok(names text[])
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
    select names is not null
       and coalesce(array_length(names, 1), 0) <= 12
       and not exists (
           select 1 from unnest(names) as name
            where name is null
               or char_length(name) not between 1 and 60
               or name <> btrim(name)
               or name ~ '[[:cntrl:]]')
$$;

alter table public.shared_models add column if not exists motions text[] not null default '{}'
    constraint shared_models_motion_names check (public.motion_names_ok(motions));

-- ---------------------------------------------------------------------------
-- The card, as play.sql made it, and the motions' names.

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
        'moves', to_jsonb(m.moves),
        'motions', to_jsonb(m.motions))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.motion_names_ok(text[]) from public, anon, authenticated;
grant execute on function public.motion_names_ok(text[]) to service_role;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
