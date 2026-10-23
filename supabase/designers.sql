-- Designers, 2026-10-19: what a designer's models earned.
--
-- A profile said how many models somebody had in the gallery and how many
-- likes they had, and nothing of what their models did: whether anybody
-- built them, remixed them or talked about them. And a designer had no way
-- to see how their own models were doing. Now:
--
--   designer_page   what a designer's page (/u/<handle>) shows anybody:
--                   their models in the gallery, the builds finished of
--                   them, the remixes of them, the comments on them, how
--                   many are Tested, and the photos other people posted of
--                   their builds of them; and each model's comments, for
--                   its card. The models are the ones their profile lists
--                   (directory_models with owner: published, listed,
--                   credited, not taken out), and each number is the sum of
--                   what each of those models' cards says:
--
--                     builds     model_stats.builds, as the card and Top
--                                builds count them (once per device)
--                     remixes    published remixes of it, as the card
--                     comments   on its page in this life of its link, not
--                                hidden, not removed, by an account shown
--                                in public, and not the designer's own
--                                (an answer to a comment is not one
--                                earned)
--                     tested     its newest version marked Tested
--
--   designer_mine   what only the designer sees, on their own profile and
--                   on Account (/profile), for each of their published
--                   models, listed or shared by link: the last 30 days'
--                   opens, builds finished, remixes and comments, and the
--                   same since it was shared; and who built it, from the
--                   photos people posted ("I built it"), not their own.
--                   Asked only with the designer's own account: the API
--                   passes the account its sign-in proves, and asks for
--                   no other; its answers are never kept by the CDN.
--
--   model_opens     how many visitors opened a model's page each day: the
--                   count count_view already makes (once per visitor per
--                   day, never a robot's), kept by the day. model_views
--                   keeps who looked for two days, to count each visitor
--                   once, and the daily sweep forgets them; this keeps
--                   only how many, a row a model a day, nothing about
--                   anybody. Kept by a trigger on model_views, so
--                   count_view is not replaced. What model_views still has
--                   (today's and yesterday's) is counted in once, here, so
--                   the opens begin from yesterday.
--
--   designer_said   the comments a model earned, the one rule both count
--                   by
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes model_opens
-- directly.
--
-- Only additions, applied after discovery.sql, follows.sql, builds.sql,
-- comments.sql, tested.sql and trust.sql (it reads their tables): one new
-- table and its index, a trigger on model_views that adds to it, and four
-- new functions (the trigger's, designer_said, designer_page, designer_mine). No function another file defines is replaced, so every
-- answer the live functions give is the same; count_view, whose insert the
-- trigger follows, answers exactly as before (tools/designers_try.sql). No
-- existing row is changed, nothing dropped or renamed.

-- ---------------------------------------------------------------------------
-- Opens, by the day.

create table if not exists public.model_opens (
    model  text not null references public.shared_models (id) on delete cascade,
    day    date not null,
    opens  integer not null default 0 check (opens >= 0),
    primary key (model, day)
);
-- When the counting began (designer_mine's counted_from), without reading
-- every row.
create index if not exists model_opens_day on public.model_opens (day);
alter table public.model_opens enable row level security;
revoke all on public.model_opens from public, anon, authenticated, service_role;

-- A visitor counted on a model's page (count_view's insert into
-- model_views) is one open that day. Nothing else writes model_views.
create or replace function public.model_opens_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.model_opens (model, day, opens) values (new.model, new.day, 1)
        on conflict (model, day) do update set opens = public.model_opens.opens + 1;
    return null;
end;
$$;
revoke all on function public.model_opens_count() from public, anon, authenticated;
create or replace trigger model_opens_count
    after insert on public.model_views
    for each row execute function public.model_opens_count();

-- What model_views has now, once: a day already counted is left alone, so
-- applying the file again counts nothing twice.
insert into public.model_opens (model, day, opens)
    select v.model, v.day, count(*)
      from public.model_views v
     group by v.model, v.day
    on conflict (model, day) do nothing;


-- ---------------------------------------------------------------------------
-- What a model earned.

-- The comments each of [model_ids] earned: on its page in this life of its
-- link (from its first version, which a takedown and a share again begin
-- anew), shown there to a visitor (not hidden, not removed, by an account
-- shown in public), and not by its owner. [recent] is those since [since].
-- One place for the rule, which both functions below count by.
-- REPLACED LATER: replies.sql replaces this function (replies to a comment,
-- shown only under it). Apply replies.sql again right after this file:
-- tools/apply_sql.mjs refuses it alone, unless --again=supabase/replies.sql.
create or replace function public.designer_said(model_ids text[], since timestamptz default null)
returns table (model text, comments bigint, recent bigint)
language sql
stable
security definer
set search_path = public
as $$
    -- Each writer asked once whether they are shown, and each model once
    -- when its link's life began.
    -- (Kept apart, or the planner asks it of every comment before the
    -- distinct: 0.1 ms each.)
    with writers as materialized (
        select distinct k.author from public.model_comments k
         where k.model = any (designer_said.model_ids)),
    shown as materialized (
        select w.author from writers w where public.shown_publicly(w.author)),
    lives as materialized (
        select v.model, min(v.at) as at
          from public.share_versions v
         where v.model = any (designer_said.model_ids)
         group by v.model)
    select c.model, count(*), count(*) filter (where designer_said.since is not null and c.at >= designer_said.since)
      from public.model_comments c
      join public.shared_models m on m.id = c.model
      left join lives l on l.model = c.model
     where c.model = any (designer_said.model_ids)
       and c.removed_at is null and c.hidden_at is null
       and c.author <> m.owner
       and c.at >= coalesce(l.at, '-infinity'::timestamptz)
       and c.author in (select s.author from shown s)
     group by c.model
$$;

-- ---------------------------------------------------------------------------
-- What anybody sees.

-- A designer's page: null for a handle nobody shown in public has.
create or replace function public.designer_page(wanted text, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with person as (
        select p.account
          from public.people p
         where p.handle = lower(designer_page.wanted)
           and not exists (select 1 from public.barred_accounts b where b.account = p.account)
           and not public.trust_kept_private(p.account)),
    -- The models their profile lists, each with what its card says.
    theirs as materialized (
        select m.id, m.owner, coalesce(s.builds, 0) as builds, coalesce(s.likes, 0) as likes,
               public.model_tested(m.id) as tested
          from person p
          join public.shared_models m on m.owner = p.account
          left join public.model_stats s on s.model = m.id
         where m.published and m.listed and not m.barred and m.author is not null
           and (not m.test or designer_page.tests)),
    remixed as (
        select r.remixed_from as id, count(*) as n
          from public.shared_models r
         where r.remixed_from in (select t.id from theirs t) and r.published
         group by r.remixed_from),
    said as (
        select * from public.designer_said((select coalesce(array_agg(t.id), '{}') from theirs t))),
    -- Photos other people posted of their builds of those models.
    posted as materialized (
        select ph.id, ph.model, ph.account, ph.words, ph.width, ph.height, ph.at
          from public.build_photos ph
          join theirs t on t.id = ph.model
         where ph.removed_at is null and ph.hidden_at is null and ph.account <> t.owner),
    builders as materialized (
        select distinct y.account from posted y),
    seen as materialized (
        select b.account from builders b where public.shown_publicly(b.account)),
    photos as materialized (
        select x.* from posted x where x.account in (select s.account from seen s)),
    newest as (
        select x.*, pp.handle, pp.name, sm.name as model_name
          from (select * from photos order by at desc, id limit 12) x
          join public.shared_models sm on sm.id = x.model
          left join public.people pp on pp.account = x.account)
    select case when not exists (select 1 from person) then null else jsonb_build_object(
        'models', (select count(*) from theirs),
        'builds', (select coalesce(sum(t.builds), 0) from theirs t),
        'remixes', (select coalesce(sum(r.n), 0) from remixed r),
        'comments', (select coalesce(sum(c.comments), 0) from said c),
        'tested', (select count(*) from theirs t where t.tested),
        'likes', (select coalesce(sum(t.likes), 0) from theirs t),
        'builders', (select count(distinct x.account) from photos x),
        'cards', coalesce((select jsonb_object_agg(c.model, jsonb_build_object('comments', c.comments))
                             from said c), '{}'::jsonb),
        'photos', coalesce((select jsonb_agg(jsonb_build_object(
                      'id', n.id, 'model', n.model, 'model_name', n.model_name,
                      'words', n.words, 'width', n.width, 'height', n.height,
                      'at', n.at, 'by', case when n.handle is null then null
                                             else jsonb_build_object('handle', n.handle, 'name', n.name) end)
                      order by n.at desc, n.id)
                              from newest n), '[]'::jsonb))
    end
$$;

-- ---------------------------------------------------------------------------
-- What only the designer sees.

-- [designer]'s published models, each with the last [days] days (1 to 90)
-- of opens, builds finished, remixes and comments, the same since it was
-- shared, and up to six of the newest photos other people posted of their
-- builds of it. Null for no account.
create or replace function public.designer_mine(designer uuid, days integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with span as (
        select least(greatest(coalesce(designer_mine.days, 30), 1), 90) as n),
    since as (
        select current_date - (s.n - 1) as day, now() - make_interval(days => s.n) as at from span s),
    mine as materialized (
        select m.id, m.name, m.owner, m.listed, m.author, m.test, m.parts, m.has_image, m.has_thumb,
               m.updated_at, m.listed_at, m.created_at,
               coalesce(s.views, 0) as opens_ever, coalesce(s.builds, 0) as builds_ever,
               public.model_tested(m.id) as tested
          from public.shared_models m
          left join public.model_stats s on s.model = m.id
         where m.owner = designer_mine.designer and m.published and not m.barred),
    opened as (
        select o.model, sum(o.opens) as n
          from public.model_opens o
         where o.model in (select m.id from mine m) and o.day >= (select w.day from since w)
         group by o.model),
    built as (
        select b.model, count(*) as n
          from public.model_builds b
         where b.model in (select m.id from mine m) and b.at >= (select w.at from since w)
         group by b.model),
    remixed as (
        select r.remixed_from as model, count(*) as n,
               count(*) filter (where r.created_at >= (select w.at from since w)) as recent
          from public.shared_models r
         where r.remixed_from in (select m.id from mine m) and r.published
         group by r.remixed_from),
    said as (
        select * from public.designer_said((select coalesce(array_agg(m.id), '{}') from mine m),
                                           (select w.at from since w))),
    posted as materialized (
        select ph.id, ph.model, ph.account, ph.words, ph.width, ph.height, ph.at
          from public.build_photos ph
          join mine m on m.id = ph.model
         where ph.removed_at is null and ph.hidden_at is null and ph.account <> m.owner),
    builders as materialized (
        select distinct y.account from posted y),
    seen as materialized (
        select b.account from builders b where public.shown_publicly(b.account)),
    photos as (
        select x.*, row_number() over (partition by x.model order by x.at desc, x.id) as k
          from posted x
         where x.account in (select s.account from seen s)),
    pictured as (
        select x.model, count(*) as n, count(distinct x.account) as builders,
               jsonb_agg(jsonb_build_object(
                   'id', x.id, 'words', x.words, 'width', x.width, 'height', x.height, 'at', x.at,
                   'by', case when pp.handle is null then null
                              else jsonb_build_object('handle', pp.handle, 'name', pp.name) end)
                   order by x.at desc, x.id) filter (where x.k <= 6) as shown
          from photos x
          left join public.people pp on pp.account = x.account
         group by x.model),
    counted as (
        select m.*, coalesce(o.n, 0) as opens, coalesce(b.n, 0) as builds,
               coalesce(r.recent, 0) as remixes, coalesce(r.n, 0) as remixes_ever,
               coalesce(c.recent, 0) as comments, coalesce(c.comments, 0) as comments_ever,
               coalesce(p.n, 0) as photos_count, coalesce(p.builders, 0) as builders,
               coalesce(p.shown, '[]'::jsonb) as photos
          from mine m
          left join opened o on o.model = m.id
          left join built b on b.model = m.id
          left join remixed r on r.model = m.id
          left join said c on c.model = m.id
          left join pictured p on p.model = m.id)
    select case when designer_mine.designer is null then null else jsonb_build_object(
        'days', (select s.n from span s),
        'since', (select w.day from since w),
        'counted_from', (select min(o.day) from public.model_opens o),
        'models', coalesce((select jsonb_agg(jsonb_build_object(
                'id', c.id, 'name', c.name, 'listed', c.listed, 'credited', c.author is not null,
                'test', c.test, 'parts', c.parts, 'has_image', c.has_image, 'has_thumb', c.has_thumb,
                'updated_at', c.updated_at, 'listed_at', c.listed_at, 'tested', c.tested,
                'opens', c.opens, 'opens_ever', c.opens_ever, 'builds', c.builds, 'builds_ever', c.builds_ever,
                'remixes', c.remixes, 'remixes_ever', c.remixes_ever,
                'comments', c.comments, 'comments_ever', c.comments_ever,
                'photos_count', c.photos_count, 'builders', c.builders, 'photos', c.photos)
              order by c.opens desc, c.builds desc, c.builds_ever desc, c.opens_ever desc,
                       c.listed_at desc nulls last, c.created_at desc, c.id)
            from counted c), '[]'::jsonb))
    end
$$;

revoke all on function public.designer_said(text[], timestamptz) from public, anon, authenticated;
grant execute on function public.designer_said(text[], timestamptz) to service_role;
revoke all on function public.designer_page(text, boolean) from public, anon, authenticated;
grant execute on function public.designer_page(text, boolean) to service_role;
revoke all on function public.designer_mine(uuid, integer) from public, anon, authenticated;
grant execute on function public.designer_mine(uuid, integer) to service_role;
