-- The gallery's tabs, 2026-10-22: Top over a time, Following, how a model
-- was made, and the comments on each card (docs/SOCIAL.md U3).
--
-- The owner asked for a gallery that feels like a social site. Its page
-- now has tabs, Top (builds finished, remixes and the Tested mark, as
-- discovery.sql weighs them; never views), New and, signed in, Following;
-- Top over all time, this month or this week; a filter for a model made by
-- hand or with the assistant (D7); and on every card its comments beside
-- its likes and builds. None of that is a new table. The list is asked of a
-- new function, so a database without it answers as before and the page
-- offers none of it (api/share.js gallery):
--
--   gallery_models   play.sql's directory_models, every filter and sort as
--                    it was (tests/test_gallery_tabs.py holds them), and
--                    three more words in its query:
--                      days       Top over the past N days (1 to 366): the
--                                 builds finished and the remixes listed in
--                                 them, and the Tested mark, as this week's
--                                 pick weighs its week (gallery_week); a
--                                 model is in it when something in those
--                                 days says it builds: a build finished, a
--                                 remix listed, or it was listed then and is
--                                 Tested. Ties to more builds in them, then
--                                 the newest.
--                      following  an account: only the models of the people
--                                 it follows, credited to them (the feed's
--                                 rule, follows.sql feed_rows), and only
--                                 people who may be followed.
--                      made       'assistant': tagged ai-designed or
--                                 brickify, as the guidelines ask; 'hand':
--                                 every other (web/card.js ASSISTANT_TAGS
--                                 marks the card by the same two).
--   directory_card   motions.sql's, and comments: how many a visitor may
--                    read on its page (comments.sql comments_on's rule: this
--                    life of its link, not removed, not hidden, by an
--                    account shown in public). Every list, shelf, pick and
--                    page that reads a card has it.
--
-- Only additions, applied after motions.sql (whose directory_card this
-- supersedes) and play.sql (whose directory_models gallery_models copies;
-- directory_models itself is not replaced: profiles, collections and the
-- shelves still read it). It reads follows.sql's follows and
-- follow_may_be_followed, discovery.sql's gallery_score and gallery_shows,
-- builds.sql's model_builds and comments.sql's model_comments.
--
-- Who may touch what is as it was: the server, through the functions, each
-- granted to the service role alone. Whom somebody follows is read only to
-- choose their own list, asked with their own sign-in, and never said: the
-- answer is the models, as the gallery shows them to anybody. No table, no
-- column and no row is changed; nothing dropped or renamed.

-- ---------------------------------------------------------------------------
-- The card, as motions.sql made it, and its comments.

-- REPLACED LATER: replies.sql replaces this function (replies to a comment,
-- shown only under it). Apply replies.sql again right after this file:
-- tools/apply_sql.mjs refuses it alone, unless --again=supabase/replies.sql.
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
        'motions', to_jsonb(m.motions),
        -- What a visitor may read on its page (comments_on, asked by nobody).
        'comments', (select count(*) from public.model_comments k
                      where k.model = m.id and k.removed_at is null and k.hidden_at is null
                        and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = m.id),
                                             '-infinity'::timestamptz)
                        and public.shown_publicly(k.author)))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- ---------------------------------------------------------------------------
-- The list, as play.sql made directory_models, and days, following and made.

-- REPLACED LATER: made_with.sql replaces this function (made read from who
-- laid the model's parts, as its app said, before its tags). Apply
-- made_with.sql again right after this file: tools/apply_sql.mjs refuses it
-- alone, unless --again=supabase/made_with.sql.
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
           and (a.made is null
                or (a.made = 'assistant' and m.tags && array['ai-designed', 'brickify']::text[])
                or (a.made = 'hand' and not (m.tags && array['ai-designed', 'brickify']::text[])))
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
