-- Work in progress, shared by version, 2026-11-23 (unit buildlog;
-- docs/MASTERPLAN.md row 10, docs/SOCIAL.md section 11, api/_wip.js,
-- api/share.js, src/ui/share_panel.gd).
--
-- A model was shared when it was finished, so the months it took to build
-- were seen by nobody. r/legomoc allows one or two WIP posts a model;
-- Rebrickable keeps a dated timeline by hand; Eurobricks' contests ask for
-- WIPs by a date. Brickworks already keeps every published version with
-- what changed and its designer's note (versions.sql), and has Talk
-- (talk.sql). This joins them:
--
--   Share progress  the studio's Publish has a second button that
--                   publishes the version as Publish does, marked work in
--                   progress. The model is WIP from then until its
--                   designer publishes a version as finished, or marks the
--                   newest one finished on its page.
--   While WIP       its page, its Log and its followers' feeds have it; the
--                   gallery's Newest shows it marked Work in progress. It
--                   is never in Top or any ranked sort, This week's pick,
--                   the week's candidates, a challenge, the featured model
--                   or a shelf (gallery_shows, gallery_models): a work in
--                   progress has not had its chance to be built.
--   Talk            the first WIP version opens the model's one Show and
--                   tell thread (or posts in the one its designer started
--                   from its page), as its designer; each later version,
--                   and the finish, is one post in it, never a new thread
--                   (wip_talk). Talk's own rules hold: talk_start's and
--                   talk_reply's limits, bans, age and blocks.
--   Followers       of the designer hear of each version through the feed
--                   as before ('model', 'version' rows, now saying wip and
--                   finished), and of a finish made on the page by a
--                   'version' row at that time (wip_rows); followers of the
--                   thread through talk_reply, as of any post.
--
--   shared_models.wip_at          when the model became work in progress,
--                                 null when it is not (finished, or never)
--   share_versions.wip            shared as work in progress
--   share_versions.finished_at    the version its designer called finished:
--                                 its own time when published as finished,
--                                 later when marked on the page
--   share_versions.talk_post      the post its publish made in Talk
--   share_versions.finished_post  the post a finish on the page made
--   share_versions.has_thumb      a small picture kept with it, the
--                                 gallery card's (<id>.webp, and
--                                 <id>.v<n>.webp once a newer one comes),
--                                 for the page's Log and Talk's cards
--
-- Only additions, applied after versions.sql, talk.sql, discovery.sql,
-- modelled_by.sql, made_with.sql and collection_follows.sql: six new
-- columns (nullable, or false), new functions, and four replaced with the
-- same rows and one rule more each (supabase/later.tsv):
--
--   gallery_shows   discovery.sql's, and not WIP: the pick, the week, the
--                   challenges, the featured model and set-based builds
--   directory_card  modelled_by.sql's, and 'wip' (the card's mark)
--   gallery_models  made_with.sql's, and a WIP model only in the gallery's
--                   time-ordered lists (newest, a collection's added),
--                   never Top or a ranked sort or Build with what I own
--   follow_rows     collection_follows.sql's, each model or version row
--                   saying wip and finished, and wip_rows' finishes
--
-- No existing row is changed, nothing dropped or renamed. To take it back:
-- the four files' own functions applied again (--again), and the columns
-- dropped once nothing reads them.
--
-- Who may touch it: the server alone. The columns are on tables no page's
-- key reads (client_exposure.sql revoked shared_models from anon and
-- authenticated; versions.sql granted share_versions to nobody); the
-- functions are security definer and granted to the service role alone.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/wip.sql --table=share_versions
--
-- Dry run, made-up accounts in a rolled-back transaction, each query that
-- ranks tried with a WIP model in it, hostile callers tried:
--
--   ... node tools/apply_sql.mjs supabase/wip.sql --dry --try=tools/wip_try.sql --table=share_versions
--   node tools/sql_compare.mjs supabase/wip.sql wip

-- ---------------------------------------------------------------------------
-- The columns.

alter table public.shared_models add column if not exists wip_at timestamptz;
alter table public.share_versions add column if not exists wip boolean not null default false;
alter table public.share_versions add column if not exists finished_at timestamptz;
alter table public.share_versions add column if not exists talk_post bigint references public.talk_posts (id) on delete set null;
alter table public.share_versions add column if not exists finished_post bigint references public.talk_posts (id) on delete set null;
alter table public.share_versions add column if not exists has_thumb boolean not null default false;
-- The WIP models, for the gallery's rules to find them at once.
create index if not exists shared_models_wip on public.shared_models (wip_at) where wip_at is not null;

-- ---------------------------------------------------------------------------
-- Where a WIP model is not: everything that ranks or chooses.

-- Whether [m] is in the gallery as a list asked with [tests] shows it, for
-- the pick, the week, the challenges and the featured model: discovery.sql's
-- rule, and not work in progress.
create or replace function public.gallery_shows(m public.shared_models, tests boolean)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select m.published and m.listed and not m.barred and m.wip_at is null
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
       and (not m.test or coalesce(tests, false))
$$;

-- A model's card: modelled_by.sql's, and whether it is work in progress.
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
        -- Work in progress (wip.sql): marked so on the card.
        'wip', m.wip_at is not null,
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

-- The gallery's list: made_with.sql's, and a WIP model only where the list
-- is in time order (newest, the order things were put in a collection or a
-- person's favourites), never where it ranks.
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
           -- Work in progress (wip.sql): only where the list is in time
           -- order, never where it ranks or is built from what you own.
           and (m.wip_at is null or (a.sort in ('newest', 'added') and not a.buildable))
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
-- The feed.

-- What a feed row of model [p_model] says of work in progress: version
-- [p_n]'s, or with none the newest at or before [p_at] (a 'model' row, at
-- the time it was listed). {wip, finished}, finished meaning that version's
-- publish finished it; {} for a model with no versions kept.
create or replace function public.wip_said(p_model text, p_n integer, p_at timestamptz)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select jsonb_build_object('wip', v.wip, 'finished', v.finished_at is not null and v.finished_at = v.at)
           from public.share_versions v
          where v.model = p_model and (case when p_n is not null then v.n = p_n else v.at <= p_at end)
          order by v.n desc
          limit 1), '{}'::jsonb)
$$;

-- A version called finished on its page after it was published, by
-- somebody [viewer] follows, from after [since] up to [until]: a 'version'
-- row at that time, on feed_rows' rules for a version (listed, credited,
-- shown, a test model only to a test account).
create or replace function public.wip_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with followed as (
        select f.followed as account from public.follows f
         where f.follower = viewer and public.follow_may_be_followed(f.followed)),
    tests as (
        select public.trust_is_test_account(viewer) as ok)
    select 'version'::text, v.finished_at,
           jsonb_build_object('model', m.id, 'name', m.name, 'version', v.n, 'note', v.note,
                              'wip', v.wip, 'finished', true, 'later', true, 'by', public.feed_who(m.owner))
      from public.share_versions v
      join public.shared_models m on m.id = v.model
      join followed w on w.account = m.owner
     cross join tests t
     where v.finished_at is not null and v.finished_at > v.at
       and m.published and m.listed and not m.barred and m.author is not null
       and (not m.test or t.ok)
       and v.finished_at > m.listed_at
       and v.finished_at > since and v.finished_at <= until
$$;

-- What the people and the collections [viewer] follows made:
-- collection_follows.sql's follow_rows, each model and version row saying
-- wip and finished (wip_said), and the finishes made on a page (wip_rows).
create or replace function public.follow_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    select f.kind, f.at,
           case when f.kind = 'version' then f.item || public.wip_said(f.item->>'model', (f.item->>'version')::integer, f.at)
                when f.kind = 'model' then f.item || public.wip_said(f.item->>'model', null, f.at)
                else f.item end
      from public.feed_rows(viewer, since, until) f
     where f.kind in ('model', 'version', 'challenge')
        or (f.kind = 'photo' and not (f.item->>'yours')::boolean)
    union all
    select l.kind, l.at, l.item
      from public.list_rows(viewer, since, until) l
    union all
    select w.kind, w.at, w.item
      from public.wip_rows(viewer, since, until) w
$$;

-- ---------------------------------------------------------------------------
-- Talk.

-- The post version [p_n] of [p_model] makes in the model's Show and tell
-- thread, written as [account], its designer: the thread's first post when
-- the model has no live thread (titled [p_title], the words [p_first], or
-- [p_said] without them), else a reply in it, the words [p_said]
-- (api/_wip.js says both: the first carries the model's card). [p_kind] 'version' is the post its
-- publish makes (kept as talk_post), 'finished' the one a finish on its
-- page makes (finished_post). Once each: asked again, it answers the post
-- it made, made false. {made, thread, post} or {refused}: model (not the
-- account's, or not up), no_version, kind, or talk_start's and talk_reply's
-- own (sign_in, barred, ask_first, under_13, banned, locked, again, limit,
-- body, title...).
create or replace function public.wip_talk(account uuid, p_model text, p_n integer, p_title text, p_said text,
    p_kind text default 'version', p_first text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    v public.share_versions;
    t public.talk_threads;
    made jsonb;
    post_id bigint;
    thread_id bigint;
begin
    if p_kind is null or p_kind not in ('version', 'finished') then
        return jsonb_build_object('refused', 'kind');
    end if;
    select * into m from public.shared_models k where k.id = p_model;
    if not found or m.owner is distinct from account or not m.published or m.barred then
        return jsonb_build_object('refused', 'model');
    end if;
    -- One at a time for a version, so two asks make one post.
    select * into v from public.share_versions k where k.model = p_model and k.n = p_n for update;
    if not found then
        return jsonb_build_object('refused', 'no_version');
    end if;
    post_id := case when p_kind = 'version' then v.talk_post else v.finished_post end;
    if post_id is not null then
        return jsonb_build_object('made', false, 'post', post_id,
            'thread', (select p.thread from public.talk_posts p where p.id = post_id));
    end if;
    select * into t from public.talk_threads k where k.model = p_model and k.removed_at is null limit 1;
    if found then
        made := public.talk_reply(account, t.id, p_said);
        thread_id := t.id;
    else
        made := public.talk_start(account, 'show', p_title, coalesce(p_first, p_said), p_model);
        thread_id := (made->'thread'->>'id')::bigint;
    end if;
    if made ? 'refused' then
        return made;
    end if;
    post_id := (made->'post'->>'id')::bigint;
    if p_kind = 'version' then
        update public.share_versions set talk_post = post_id where model = p_model and n = p_n;
    else
        update public.share_versions set finished_post = post_id where model = p_model and n = p_n;
    end if;
    return jsonb_build_object('made', true, 'post', post_id, 'thread', thread_id);
end;
$$;

-- [account]'s own work in progress [p_model] called finished now, from its
-- page: its newest version is the finished one, and the model ranks as any
-- other from now. {n, finished_at} or {refused}: model (not the account's,
-- or not up), not_wip.
create or replace function public.wip_finish(account uuid, p_model text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    found_model public.shared_models;
    newest integer;
begin
    select * into found_model from public.shared_models k
     where k.id = p_model and k.owner = account and k.published and not k.barred for update;
    if not found then
        return jsonb_build_object('refused', 'model');
    end if;
    if found_model.wip_at is null then
        return jsonb_build_object('refused', 'not_wip');
    end if;
    update public.shared_models set wip_at = null where id = p_model;
    select max(v.n) into newest from public.share_versions v where v.model = p_model;
    update public.share_versions set finished_at = now() where model = p_model and n = newest;
    return jsonb_build_object('n', newest, 'finished_at', now());
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.gallery_shows(public.shared_models, boolean) from public, anon, authenticated;
grant execute on function public.gallery_shows(public.shared_models, boolean) to service_role;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
revoke all on function public.gallery_models(jsonb) from public, anon, authenticated;
grant execute on function public.gallery_models(jsonb) to service_role;
revoke all on function public.wip_said(text, integer, timestamptz) from public, anon, authenticated;
grant execute on function public.wip_said(text, integer, timestamptz) to service_role;
revoke all on function public.wip_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.wip_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.follow_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.follow_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.wip_talk(uuid, text, integer, text, text, text, text) from public, anon, authenticated;
grant execute on function public.wip_talk(uuid, text, integer, text, text, text, text) to service_role;
revoke all on function public.wip_finish(uuid, text) from public, anon, authenticated;
grant execute on function public.wip_finish(uuid, text) to service_role;
