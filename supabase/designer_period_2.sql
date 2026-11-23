-- A designer's numbers against last month, counted honestly (i2fix,
-- 2026-11-22; the review of insights2, bench/results/i2review-2026-11-22).
--
-- designer_period.sql is live, and nothing live calls designer_period yet:
-- only the insights2 branch's API asks it, and that is not deployed. So
-- replacing it here is safe; this file is a create or replace of that one
-- function, with the same grants, and nothing else.
--
-- What the first one did wrong, and what this one does instead:
--
--   - It set the last 30 days beside "the 30 before" when the 30 before
--     held only a few counted days. Views are kept by the day only from
--     2026-10-19 (designers.sql), builds and comments only from the day
--     their files went in, and a model only from the day it was shared:
--     a steady model read +480%. Now each model and kind says from which
--     day it was counted (`from`) and how many whole days of each window
--     that is (`now_days`, `before_days`); a row before that day is not
--     counted in either window. The page shows a change only where both
--     are 30, and otherwise says "Counted since" that day.
--   - Its views_from was min(model_opens.day) over every model, so a test
--     model's row dated by hand moved it for everybody. Now it is read
--     from models that are not test models only.
--   - Its last 30 days ended with today so far, against 30 whole days.
--     Now both windows are whole UTC days ending yesterday.
--
--   designer_period(designer)   each of [designer]'s published models (as
--                               designer_mine lists them: published, not
--                               taken out, in the gallery or by link):
--                               for each kind, its count in the last 30
--                               days and in the 30 before, in each of the
--                               last 8 weeks (null for a week wholly
--                               before it was counted), in all, and the
--                               days counted. Null for no account.
--
-- The days are UTC days, everywhere. Today is not counted until it ends.
-- The last 30 days are the 30 ending yesterday (today - 30 to today - 1);
-- the 30 before are the 30 before those (today - 60 to today - 31); week w
-- (0 the oldest) is the 7 days from today - 56 + 7w, the newest ending
-- yesterday.
--
-- When each kind began to be kept (`starts`): views from the first day a
-- model that is not a test model has in model_opens (2026-10-22 live when
-- this was written: the rows of 10-19 to 10-21 are all test models'), so no
-- test row moves it; builds from 2026-10-19 (builds.sql went in then);
-- comments from 2026-10-19 (comments.sql); likes, saves and remixes from
-- 2026-10-13 (people.sql and gallery.sql, the day the first model was
-- shared). A model is counted from the latest of that and the UTC day it
-- was shared; its comments, as designer_said counts them, from the day its
-- link's life began too.
--
-- What each counts (nothing new is counted, docs/SOCIAL.md D13: each is a
-- row the database already keeps, by the day it was made):
--
--   views     model_opens: visitors who opened its page, each once a day,
--             never a robot (count_view's own count); in all,
--             model_stats.views
--   builds    model_builds: a device that reached its last step, once per
--             device, on the day it first did; in all, model_stats.builds
--   likes     model_likes: people who like it now, on the day they liked
--             it; not the designer's own (a like taken back is no row)
--   saves     model_favourites and model_collection_items: people who keep
--             it, in Saved or in a list of theirs, private ones included,
--             each person once, on the day of the oldest of those they
--             still keep; not the designer. Only how many: never who.
--   comments  model_comments, by designer_said's rule (replies.sql): shown
--             on its page, in this life of its link, not the designer's
--   remixes   shared_models: published remixes of it, on the day each was
--             shared (as every remix count on the site)
--
-- Who may ask: only the server, as for designer_mine: security definer,
-- granted to the service role alone, its search path set, and the API
-- passes only the account its sign-in proves (api/_designers.js designs).
--
-- Only a replacement of designer_period.sql's one function, applied after
-- it (supabase/later.tsv): no table, column, index or row is made, changed
-- or dropped (tools/designer_period_try.sql).

create or replace function public.designer_period(designer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with span as (
        select t.today, t.today - 1 as til, t.today - 30 as now_from, t.today - 60 as before_from,
               t.today - 31 as before_til, t.today - 56 as weeks_from
          from (select (now() at time zone 'UTC')::date as today) t),
    -- The day each kind began to be kept by the day, for everybody.
    starts as (
        select 'views'::text as kind,
               coalesce((select min(o.day)
                           from public.model_opens o
                           join public.shared_models x on x.id = o.model
                          where not x.test), s.today) as day
          from span s
        union all select 'builds', date '2026-10-19'
        union all select 'likes', date '2026-10-13'
        union all select 'saves', date '2026-10-13'
        union all select 'comments', date '2026-10-19'
        union all select 'remixes', date '2026-10-13'),
    mine as materialized (
        select m.id, m.owner, (m.created_at at time zone 'UTC')::date as shared_on,
               coalesce(s.views, 0) as views_ever, coalesce(s.builds, 0) as builds_ever
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
    -- Each model and kind: the first day it was counted.
    counting as materialized (
        select m.id as model, k.kind,
               greatest(k.day, m.shared_on,
                        case when k.kind = 'comments' then (l.at at time zone 'UTC')::date end) as from_day
          from mine m
          cross join starts k
          left join lives l on l.model = m.id),
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
    happened as materialized (
        select o.model, 'views'::text as kind, o.day, o.opens::bigint as n
          from public.model_opens o, span s
         where o.model in (select m.id from mine m) and o.day between s.before_from and s.til
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
    -- The two windows, each from the day counting began, and in all.
    counted as materialized (
        select h.model, h.kind,
               coalesce(sum(h.n) filter (where h.day between greatest(s.now_from, c.from_day) and s.til), 0) as now,
               coalesce(sum(h.n) filter (where h.day between greatest(s.before_from, c.from_day) and s.before_til), 0) as before,
               sum(h.n) as ever
          from happened h
          join counting c on c.model = h.model and c.kind = h.kind, span s
         group by h.model, h.kind),
    -- The 8 weeks, each from the day counting began.
    by_week as materialized (
        select h.model, h.kind, (h.day - s.weeks_from) / 7 as w, sum(h.n) as n
          from happened h
          join counting c on c.model = h.model and c.kind = h.kind, span s
         where h.day between greatest(s.weeks_from, c.from_day) and s.til
         group by h.model, h.kind, (h.day - s.weeks_from) / 7),
    -- The oldest first; a week that ended before counting began is null,
    -- not nought, so no chart begins with a run of zeros.
    weeks as materialized (
        select c.model, c.kind,
               jsonb_agg(case when s.weeks_from + 7 * w.w + 6 < c.from_day then null
                              else coalesce(b.n, 0) end order by w.w) as weeks
          from counting c
          cross join generate_series(0, 7) w(w)
          cross join span s
          left join by_week b on b.model = c.model and b.kind = c.kind and b.w = w.w
         group by c.model, c.kind),
    each_model as (
        select c.model, jsonb_object_agg(c.kind, jsonb_build_object(
                   'now', coalesce(x.now, 0),
                   'before', coalesce(x.before, 0),
                   'ever', case c.kind when 'views' then m.views_ever
                                       when 'builds' then m.builds_ever
                                       else coalesce(x.ever, 0) end,
                   'weeks', w.weeks,
                   'from', c.from_day,
                   -- The whole days of each window counted.
                   'now_days', greatest(0, s.til - greatest(s.now_from, c.from_day) + 1),
                   'before_days', greatest(0, s.before_til - greatest(s.before_from, c.from_day) + 1))) as kinds
          from counting c
          join mine m on m.id = c.model
          join weeks w on w.model = c.model and w.kind = c.kind
          left join counted x on x.model = c.model and x.kind = c.kind
          cross join span s
         group by c.model)
    select case when designer_period.designer is null then null else jsonb_build_object(
        'today', s.today,
        'days', 30,
        'til', s.til,
        'now_from', s.now_from,
        'before_from', s.before_from,
        'before_til', s.before_til,
        'weeks_from', s.weeks_from,
        'views_from', (select k.day from starts k where k.kind = 'views'),
        'starts', (select jsonb_object_agg(k.kind, k.day) from starts k),
        'models', coalesce((select jsonb_object_agg(e.model, e.kinds) from each_model e), '{}'::jsonb))
    end
      from span s
$$;

revoke all on function public.designer_period(uuid) from public, anon, authenticated;
grant execute on function public.designer_period(uuid) to service_role;
