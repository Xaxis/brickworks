-- Play, 2026-10-19: what a model has to play with, on its gallery card.
--
-- A shared model's link lets anybody take hold of what moves in it and move
-- it as it was built (src/ui/share_view.gd): steer the wheels, swing the
-- boom, open the doors, turn the gearbox by its input. Nobody can do that
-- with a model on Rebrickable. The app works out what moves as the model is
-- published, from the joints it finds (src/assembly/playable.gd), and sends
-- the words with it; api/share.js checks them and keeps them here:
--
--   steering, turntable, boom, doors, gears, pneumatics, actuator, rack
--
-- The gallery's card says them ("Moves: steering, boom"), and its
-- "Technic or mechanism" filter takes a model whose moves name a mechanism
-- (any of them but doors) as one, whatever its parts are.
--
-- Only additions, applied after discovery.sql, whose directory_models this
-- supersedes, and builds.sql, whose directory_card it supersedes:
--
--   shared_models.moves   what moves, as the app said when the model was
--                         last published: the words above, each at most
--                         once; empty for nothing, and for every model
--                         published before this (each row gets an empty
--                         list, and its next publish says).
--   moves_mechanism       whether a list of them names a mechanism.
--   directory_card        builds.sql's, and moves.
--   directory_models      discovery.sql's, every filter and sort as it was;
--                         technic is also a model whose moves name a
--                         mechanism.
--
-- Who may touch what is as it was: the server, through the functions, each
-- granted to the service role alone; api/share.js writes moves with the
-- model's row. No existing value is changed, nothing dropped or renamed.

-- Not to wait on a busy table: the column is added under a lock on it.
set local lock_timeout = '5s';

-- Only the words the app says, eight at most (api/share.js says each once).
alter table public.shared_models add column if not exists moves text[] not null default '{}'
    constraint shared_models_moves_words
    check (cardinality(moves) <= 8
           and moves <@ array['steering', 'turntable', 'boom', 'doors', 'gears', 'pneumatics', 'actuator',
                              'rack']::text[]);

-- Whether [moves] names a mechanism: any word but doors.
create or replace function public.moves_mechanism(moves text[])
returns boolean
language sql
immutable
set search_path = public
as $$
    select coalesce(moves && array['steering', 'turntable', 'boom', 'gears', 'pneumatics', 'actuator',
                                   'rack']::text[], false)
$$;

-- ---------------------------------------------------------------------------
-- The card, as builds.sql made it, and what moves.

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
        'moves', to_jsonb(m.moves))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- ---------------------------------------------------------------------------
-- The list, as discovery.sql made it: technic is also a model whose moves
-- name a mechanism.

create or replace function public.directory_models(query jsonb)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (
        select nullif(query->>'words', '') as words,
               nullif(query->>'kind', '') as kind,
               nullif(query->>'tag', '') as tag,
               (query->>'least')::integer as least_parts,
               (query->>'most')::integer as most_parts,
               coalesce((query->>'own_steps')::boolean, false) as own_steps,
               coalesce((query->>'technic')::boolean, false) as technic,
               coalesce((query->>'tested')::boolean, false) as tested,
               (query->>'owner')::uuid as owner,
               nullif(query->>'collection', '') as collection,
               (query->>'favourites')::uuid as favourites,
               coalesce((query->>'private')::boolean, false) as private,
               coalesce((query->>'tests')::boolean, false) as tests,
               coalesce(nullif(query->>'sort', ''), 'newest') as sort,
               least(greatest(coalesce((query->>'size')::integer, 25), 1), 49) as size,
               least(greatest(coalesce((query->>'skip')::integer, 0), 0), 20000) as skip,
               (query->>'pool')::uuid as pool,
               coalesce((query->>'buildable')::boolean, false) as buildable
    ),
    -- How many of each model's pieces the pool holds, part and colour by
    -- part and colour, across the gallery: only to sort or filter by it.
    -- A page's cards are told theirs after the page is cut.
    owned as materialized (
        select n.model, sum(least(n.qty, p.qty)) as have
          from public.collection_pools p
          join public.model_needs n on n.part = p.part and n.colour = p.colour
         where p.owner = (select a.pool from asked a)
           and (select a.sort = 'owned' or a.buildable from asked a)
         group by n.model),
    page as (
        select m,
               case when a.sort = 'added' then added.at end as k_added,
               case when a.sort = 'views' then coalesce(s.views, 0) end as k_views,
               case when a.sort = 'likes' then coalesce(s.likes, 0) end as k_likes,
               case when a.sort = 'remixes' then rx.n end as k_remixes,
               case when a.sort = 'builds' then coalesce(s.builds, 0) end as k_builds,
               case when a.sort = 'top' then public.gallery_score(coalesce(s.builds, 0), rx.n,
                                                                  public.model_tested(m.id)) end as k_top,
               case when a.sort = 'top' then coalesce(s.builds, 0) end as k_top_builds,
               case when a.sort = 'owned' then coalesce(o.have, 0)::numeric / nullif(k.pieces, 0) end as k_owned,
               case when a.sort = 'owned' then coalesce(o.have, 0) end as k_owned_pieces
          from asked a
         cross join public.shared_models m
          left join public.model_stats s on s.model = m.id
          left join public.model_needs_kept k
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and k.model = m.id
          left join owned o
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and o.model = m.id
          left join lateral (
              select count(*) as n from public.shared_models r
               where r.remixed_from = m.id and r.published) rx on true
          left join lateral (
              select coalesce(
                  (select i.at from public.model_collection_items i
                    where i.collection = a.collection and i.model = m.id),
                  (select f.at from public.model_favourites f
                    where f.account = a.favourites and f.model = m.id)) as at) added on true
         where m.published and not m.barred
           and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
           and (m.listed or a.private)
           and (not m.test or a.tests or a.private)
           and (a.words is null or m.search @@ to_tsquery('simple'::regconfig, a.words))
           and (a.kind is null or m.kind = a.kind)
           and (a.tag is null or m.tags @> array[a.tag])
           and (a.least_parts is null or m.parts >= a.least_parts)
           and (a.most_parts is null or m.parts <= a.most_parts)
           and (not a.own_steps or m.own_steps)
           and (not a.technic or m.technic or public.moves_mechanism(m.moves))
           and (not a.tested or public.model_tested(m.id))
           and (a.owner is null or (m.owner = a.owner and m.author is not null and m.listed))
           and (a.collection is null or exists (select 1 from public.model_collection_items i
                                                 where i.collection = a.collection and i.model = m.id))
           and (a.favourites is null or exists (select 1 from public.model_favourites f
                                                 where f.account = a.favourites and f.model = m.id))
           and (not a.buildable or (k.pieces > 0 and coalesce(o.have, 0) >= k.pieces))
         order by k_added desc nulls last, k_views desc nulls last, k_likes desc nulls last,
                  k_remixes desc nulls last, k_builds desc nulls last, k_top desc nulls last,
                  k_top_builds desc nulls last, k_owned desc nulls last, k_owned_pieces desc nulls last,
                  m.listed_at desc nulls last, m.updated_at desc, m.id desc
         limit (select size from asked) offset (select skip from asked)
    )
    select public.directory_card(p.m)
           || case when a.pool is null then '{}'::jsonb
                   else jsonb_build_object('owned', jsonb_build_object('pieces', k.pieces,
                        'have', case when k.pieces is null then null else least(coalesce(h.have, 0), k.pieces) end))
              end
      from page p
     cross join asked a
      left join public.model_needs_kept k on a.pool is not null and k.model = (p.m).id
      left join lateral (
          select sum(least(n.qty, x.qty)) as have
            from public.model_needs n
            join public.collection_pools x on x.owner = a.pool and x.part = n.part and x.colour = n.colour
           where a.pool is not null and n.model = (p.m).id) h on true
     order by p.k_added desc nulls last, p.k_views desc nulls last, p.k_likes desc nulls last,
              p.k_remixes desc nulls last, p.k_builds desc nulls last, p.k_top desc nulls last,
              p.k_top_builds desc nulls last, p.k_owned desc nulls last, p.k_owned_pieces desc nulls last,
              (p.m).listed_at desc nulls last, (p.m).updated_at desc, (p.m).id desc
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.moves_mechanism(text[]) from public, anon, authenticated;
grant execute on function public.moves_mechanism(text[]) to service_role;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;
