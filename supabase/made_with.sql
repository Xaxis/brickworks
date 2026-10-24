-- Who laid a model's parts, said by the app as it publishes, 2026-10-24
-- (docs/SOCIAL.md D7, U16).
--
-- A card says Hand-built or With the assistant, and the gallery filters by
-- it. It was read from the tags the guidelines ask for (ai-designed,
-- brickify), so a model built by hand and tagged ai-designed was marked as
-- the assistant's, and a design of Claude's nobody tagged as hand-built.
-- The app knows: it says, as it publishes (src/parts/model_store.gd
-- made_with), hand for a model begun empty in it with every part laid by a
-- person, assistant once Claude laid any, brickify once Brickify did and
-- Claude never, and nothing for a model from a file that does not say.
--
--   shared_models.made_with   'hand', 'assistant' or 'brickify', as the app
--                             said; null where it did not, which a model
--                             published before this has, and the card and
--                             the filter then read its tags as before
--   directory_card            replies.sql's, and made_with
--   gallery_models            gallery_tabs.sql's, its made filter reading
--                             made_with first and the tags where it is null
--
-- Only additions, applied after replies.sql (whose directory_card this
-- supersedes) and gallery_tabs.sql (whose gallery_models). No row is
-- changed: every model keeps null until it is published again by an app
-- that says. Nothing dropped or renamed.
--
-- Who may touch it: the server alone (supabase/client_exposure.sql). The
-- column is granted to nobody, written by api/share.js as the service
-- role, and read only through directory_card, a security definer granted
-- to the service role alone.

alter table public.shared_models
    add column if not exists made_with text
    check (made_with in ('hand', 'assistant', 'brickify'));

-- Granted to no client, should a grant on the table ever be made again.
revoke select (made_with), insert (made_with), update (made_with), references (made_with)
    on public.shared_models from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The card, as replies.sql made it, and made_with.

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
-- The list, as gallery_tabs.sql made it, its made filter reading made_with.

create or replace function public.gallery_models(query jsonb)
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
               coalesce((query->>'buildable')::boolean, false) as buildable,
               -- Top over the past [days]: none is all time. (greatest()
               -- passes over a null, so a missing one is said so first.)
               case when query->>'days' is null then null
                    else least(greatest((query->>'days')::integer, 1), 366) end as days,
               (query->>'following')::uuid as following,
               nullif(query->>'made', '') as made
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
    -- Top over a time: the builds finished and the remixes listed in it,
    -- model by model (discovery.sql gallery_week_counts' rule, any span).
    built as materialized (
        select b.model, count(*) as n
          from public.model_builds b, asked a
         where a.days is not null and a.sort = 'top' and b.at > now() - make_interval(days => a.days)
         group by b.model),
    remixed as materialized (
        select r.remixed_from as model, count(*) as n
          from public.shared_models r, asked a
         where a.days is not null and a.sort = 'top' and r.remixed_from is not null
           and r.listed_at > now() - make_interval(days => a.days) and public.gallery_shows(r, a.tests)
         group by r.remixed_from),
    -- Whom the asker follows, who may be followed (follows.sql feed_rows).
    followed as materialized (
        select f.followed as account
          from public.follows f, asked a
         where a.following is not null and f.follower = a.following
           and public.follow_may_be_followed(f.followed)),
    page as (
        select m,
               case when a.sort = 'added' then added.at end as k_added,
               case when a.sort = 'views' then coalesce(s.views, 0) end as k_views,
               case when a.sort = 'likes' then coalesce(s.likes, 0) end as k_likes,
               case when a.sort = 'remixes' then rx.n end as k_remixes,
               case when a.sort = 'builds' then coalesce(s.builds, 0) end as k_builds,
               case when a.sort = 'top' then public.gallery_score(
                   case when a.days is null then coalesce(s.builds, 0) else coalesce(wb.n, 0) end,
                   case when a.days is null then rx.n else coalesce(wr.n, 0) end,
                   public.model_tested(m.id)) end as k_top,
               case when a.sort = 'top' then
                   case when a.days is null then coalesce(s.builds, 0) else coalesce(wb.n, 0) end end as k_top_builds,
               case when a.sort = 'owned' then coalesce(o.have, 0)::numeric / nullif(k.pieces, 0) end as k_owned,
               case when a.sort = 'owned' then coalesce(o.have, 0) end as k_owned_pieces
          from asked a
         cross join public.shared_models m
          left join public.model_stats s on s.model = m.id
          left join public.model_needs_kept k
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and k.model = m.id
          left join owned o
                 on (select a.pool is not null and (a.sort = 'owned' or a.buildable) from asked a) and o.model = m.id
          left join built wb on wb.model = m.id
          left join remixed wr on wr.model = m.id
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
           -- Top over a time: what something in it says builds.
           and (a.days is null or a.sort <> 'top' or coalesce(wb.n, 0) > 0 or coalesce(wr.n, 0) > 0
                or (m.listed_at > now() - make_interval(days => a.days) and public.model_tested(m.id)))
           and (a.following is null
                or (m.author is not null and m.owner in (select w.account from followed w)))
           -- How it was made: as its app said, else as its tags say.
           and (a.made is null
                or (a.made = 'assistant' and (m.made_with in ('assistant', 'brickify')
                    or (m.made_with is null and m.tags && array['ai-designed', 'brickify']::text[])))
                or (a.made = 'hand' and (m.made_with = 'hand'
                    or (m.made_with is null and not (m.tags && array['ai-designed', 'brickify']::text[])))))
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

revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
revoke all on function public.gallery_models(jsonb) from public, anon, authenticated;
grant execute on function public.gallery_models(jsonb) to service_role;
