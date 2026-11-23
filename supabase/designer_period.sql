-- A designer's numbers against last month (insights2, 2026-11-22;
-- docs/SOCIAL.md, the units' insights2 row).
--
-- designer_mine (designers.sql) says how each of a designer's models did in
-- the last 30 days and in all. It does not say whether a model is gaining or
-- fading: nothing to set the last 30 days beside. Now, for the designer
-- alone (their profile's Insights and How your models are doing):
--
--   designer_period(designer)   each of [designer]'s published models (as
--                               designer_mine lists them: published, not
--                               taken out, in the gallery or by link): its
--                               views, builds finished, likes, saves,
--                               comments and remixes in the last 30 days,
--                               in the 30 before, in each of the last 8
--                               weeks, and in all. Null for no account.
--
-- The days are UTC days, everywhere: the last 30 days are today (so far) and
-- the 29 days before it; the 30 before are the 30 days before those; a week
-- is 7 days, the newest ending today. What each counts (nothing new is
-- counted, docs/SOCIAL.md D13: each is read from a row the database already
-- keeps, by the day it was made):
--
--   views     model_opens: visitors who opened its page, each once a day,
--             never a robot (count_view's own count), kept by the day since
--             designers.sql went in; in all, model_stats.views
--   builds    model_builds: a device that reached its last step, once per
--             device, on the day it first did; in all, model_stats.builds
--   likes     model_likes: people who like it now, on the day they liked
--             it; not the designer's own (a like taken back is no row)
--   saves     model_favourites and model_collection_items: people who keep
--             it, in Saved or in a list of theirs, each person once, on the
--             day of the oldest of those they still keep; not the designer
--   comments  model_comments, by designer_said's rule (replies.sql): shown
--             on its page, in this life of its link, not the designer's
--   remixes   shared_models: published remixes of it, on the day each was
--             shared
--
-- Who may ask: only the server, as for designer_mine: security definer,
-- granted to the service role alone, and the API passes only the account its
-- sign-in proves (api/_designers.js designs). No key a page has runs it.
--
-- Only an addition, applied after designers.sql and replies.sql (it reads
-- model_opens and comment_parent_shown): one new function. No table,
-- column, index or row is made, changed or dropped, and no function another
-- file defines is replaced (tools/designer_period_try.sql).

create or replace function public.designer_period(designer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with span as (
        select t.today, t.today - 29 as now_from, t.today - 59 as before_from
          from (select (now() at time zone 'UTC')::date as today) t),
    mine as materialized (
        select m.id, m.owner, coalesce(s.views, 0) as views_ever, coalesce(s.builds, 0) as builds_ever
          from public.shared_models m
          left join public.model_stats s on s.model = m.id
         where m.owner = designer_period.designer and m.published and not m.barred),
    -- designer_said's rule (replies.sql), by the day: each writer asked once
    -- whether they are shown, each model once when its link's life began.
    writers as materialized (
        select distinct k.author from public.model_comments k
         where k.model in (select m.id from mine m)),
    shown as materialized (
        select w.author from writers w where public.shown_publicly(w.author)),
    lives as materialized (
        select v.model, min(v.at) as at
          from public.share_versions v
         where v.model in (select m.id from mine m)
         group by v.model),
    -- Each person who keeps it, once: the oldest of their Saved and their
    -- lists that still hold it.
    kept as (
        select x.model, min(x.at) as at
          from (select f.model, f.account, f.at
                  from public.model_favourites f
                 where f.model in (select m.id from mine m)
                union all
                select i.model, c.owner, i.at
                  from public.model_collection_items i
                  join public.model_collections c on c.id = i.collection
                 where i.model in (select m.id from mine m)) x
          join mine m on m.id = x.model
         where x.account <> m.owner
         group by x.model, x.account),
    -- Everything counted, a row a model, kind and UTC day. Views and builds
    -- only as far back as the 60 days (their in all is model_stats'); the
    -- rest whole, for their in all.
    happened as (
        select o.model, 'views'::text as kind, o.day, o.opens::bigint as n
          from public.model_opens o, span s
         where o.model in (select m.id from mine m) and o.day between s.before_from and s.today
        union all
        select b.model, 'builds', (b.at at time zone 'UTC')::date, 1
          from public.model_builds b, span s
         where b.model in (select m.id from mine m)
           and b.at >= (s.before_from::timestamp at time zone 'UTC')
        union all
        select l.model, 'likes', (l.at at time zone 'UTC')::date, 1
          from public.model_likes l
          join mine m on m.id = l.model
         where l.account <> m.owner
        union all
        select k.model, 'saves', (k.at at time zone 'UTC')::date, 1
          from kept k
        union all
        select c.model, 'comments', (c.at at time zone 'UTC')::date, 1
          from public.model_comments c
          join mine m on m.id = c.model
          left join lives l on l.model = c.model
         where c.removed_at is null and c.hidden_at is null
           and c.author <> m.owner
           and c.at >= coalesce(l.at, '-infinity'::timestamptz)
           and c.author in (select s.author from shown s)
           and public.comment_parent_shown(c.parent)
        union all
        select r.remixed_from, 'remixes', (r.created_at at time zone 'UTC')::date, 1
          from public.shared_models r
         where r.remixed_from in (select m.id from mine m) and r.published),
    counted as (
        select h.model, h.kind,
               coalesce(sum(h.n) filter (where h.day between s.now_from and s.today), 0) as now,
               coalesce(sum(h.n) filter (where h.day between s.before_from and s.now_from - 1), 0) as before,
               sum(h.n) as ever,
               -- The 8 weeks, the oldest first, the newest ending today.
               jsonb_build_array(
                   coalesce(sum(h.n) filter (where h.day between s.today - 55 and s.today - 49), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 48 and s.today - 42), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 41 and s.today - 35), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 34 and s.today - 28), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 27 and s.today - 21), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 20 and s.today - 14), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 13 and s.today - 7), 0),
                   coalesce(sum(h.n) filter (where h.day between s.today - 6 and s.today), 0)) as weeks
          from happened h, span s
         group by h.model, h.kind),
    kinds (kind) as (
        values ('views'), ('builds'), ('likes'), ('saves'), ('comments'), ('remixes'))
    select case when designer_period.designer is null then null else jsonb_build_object(
        'today', s.today,
        'days', 30,
        'now_from', s.now_from,
        'before_from', s.before_from,
        'weeks_from', s.today - 55,
        -- Views are kept by the day only from here (designers.sql).
        'views_from', (select min(o.day) from public.model_opens o),
        'models', coalesce((
            select jsonb_object_agg(m.id, (
                select jsonb_object_agg(k.kind, jsonb_build_object(
                    'now', coalesce(c.now, 0),
                    'before', coalesce(c.before, 0),
                    'ever', case k.kind when 'views' then m.views_ever
                                        when 'builds' then m.builds_ever
                                        else coalesce(c.ever, 0) end,
                    'weeks', coalesce(c.weeks, '[0, 0, 0, 0, 0, 0, 0, 0]'::jsonb)))
                  from kinds k
                  left join counted c on c.model = m.id and c.kind = k.kind))
              from mine m), '{}'::jsonb))
    end
      from span s
$$;

revoke all on function public.designer_period(uuid) from public, anon, authenticated;
grant execute on function public.designer_period(uuid) to service_role;
