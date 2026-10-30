-- Achievements with levels, and a notice when one is reached, 2026-10-30
-- (docs/SOCIAL.md section 7, item 2: U13 finished).
--
-- U13 gave a person's page five flat marks, read from their numbers as the
-- page was drawn, and told nobody. Now each is a track of levels, as
-- Printables' badges are (its Designer has nine), and reaching one is a
-- notification:
--
--   designer    models listed in the gallery with their name   1 3 10 25 50 100
--   built       times their models were built to the last step 1 10 50 100 500 1000
--   builder     photos of their own builds of gallery models   1 5 10 25 50
--   remixed     remixes of their models                        1 5 25 100
--   tested      their models marked Tested                     1 5 10 25
--   challenger  challenges they entered                        1 3 6 12
--
-- Each number is read as designers.sql's designer_page reads it: a model
-- listed, published, not taken out and credited, a test model only when
-- tests are asked for (a test account's own), so a level never disagrees
-- with the numbers its page shows. Nothing for an account taken out of the
-- gallery or under 13.
--
-- A level reached is written down once, the next time its account's
-- avatar count is asked for (every page it opens): achievement_marks. A
-- level written down is kept when a number drops. notification_rows tells
-- them, a row a track each time levels were written down, its highest;
-- read once their group is opened, or with Mark all read.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the new table.
--
-- Only additions, applied after replies.sql, whose notification_rows it
-- replaces with every row it gave and the achievements (the guard in
-- tools/apply_sql.mjs refuses replies.sql applied again alone): one table,
-- deleted with its account, an index for the remixes of a model, and
-- functions. No row is changed, nothing dropped or renamed.

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.achievement_marks (
    account  uuid not null references auth.users (id) on delete cascade,
    track    text not null check (track in ('designer', 'built', 'builder', 'remixed', 'tested', 'challenger')),
    level    integer not null check (level between 1 and 20),
    at       timestamptz not null default now(),
    read_at  timestamptz,
    primary key (account, track, level)
);

alter table public.achievement_marks enable row level security;
revoke all on public.achievement_marks from public, anon, authenticated, service_role;

-- Every page an account opens counts its models' remixes.
create index if not exists shared_models_remixed_from on public.shared_models (remixed_from)
    where remixed_from is not null;

-- ---------------------------------------------------------------------------
-- The levels.

-- Each track, in the order a page lists them, and the numbers its levels
-- need, the first level's first.
create or replace function public.achievement_ladders()
returns table (track text, place integer, steps integer[])
language sql
immutable
set search_path = public
as $$
    values ('designer', 1, array[1, 3, 10, 25, 50, 100]),
           ('built', 2, array[1, 10, 50, 100, 500, 1000]),
           ('builder', 3, array[1, 5, 10, 25, 50]),
           ('remixed', 4, array[1, 5, 25, 100]),
           ('tested', 5, array[1, 5, 10, 25]),
           ('challenger', 6, array[1, 3, 6, 12])
$$;

-- [account]'s number on each track; test models and test challenges too
-- with [tests]. No rows for nobody, an account taken out of the gallery,
-- or one under 13.
create or replace function public.achievement_numbers(account uuid, tests boolean default false)
returns table (track text, n bigint)
language sql
stable
security definer
set search_path = public
as $$
    with who as (
        select achievement_numbers.account as id
         where achievement_numbers.account is not null and public.shown_publicly(achievement_numbers.account)),
    theirs as materialized (
        select m.id, coalesce(s.builds, 0) as builds, public.model_tested(m.id) as tested
          from who w
          join public.shared_models m on m.owner = w.id
          left join public.model_stats s on s.model = m.id
         where m.published and m.listed and not m.barred and m.author is not null
           and (not m.test or coalesce(achievement_numbers.tests, false)))
    select x.track, x.n
      from who w
     cross join lateral (values
        ('designer', (select count(*) from theirs)),
        ('built', (select coalesce(sum(t.builds), 0)::bigint from theirs t)),
        ('builder', (select count(*) from public.build_photos ph
                       join public.shared_models m on m.id = ph.model
                      where ph.account = w.id and ph.removed_at is null and ph.hidden_at is null
                        and m.published and m.listed and not m.barred
                        and (not m.test or coalesce(achievement_numbers.tests, false)))),
        ('remixed', (select count(*) from public.shared_models r
                      where r.remixed_from in (select t.id from theirs t) and r.published)),
        ('tested', (select count(*) from theirs t where t.tested)),
        ('challenger', (select count(distinct e.challenge) from public.challenge_entries e
                          join public.challenges c on c.id = e.challenge
                         where e.owner = w.id and (not c.test or coalesce(achievement_numbers.tests, false))))
     ) x(track, n)
$$;

-- [account]'s level on each track, in the ladders' order: [{track, n,
-- level, of, reached, next}]. [level] 0 is none yet; [reached] is the
-- number its level needed, [next] the next level's (null at the last).
-- [] for nobody.
create or replace function public.achievement_levels(account uuid, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
               'track', l.track, 'n', x.n, 'level', r.level, 'of', cardinality(l.steps),
               'reached', l.steps[nullif(r.level, 0)], 'next', l.steps[r.level + 1])
             order by l.place), '[]'::jsonb)
      from public.achievement_ladders() l
      join public.achievement_numbers(achievement_levels.account, achievement_levels.tests) x on x.track = l.track
     cross join lateral (select count(*)::integer as level from unnest(l.steps) s where s <= x.n) r
$$;

-- ---------------------------------------------------------------------------
-- Reached, told and read.

-- Each level [viewer] reached that is not written down yet, written down
-- now: how many. A test account's test models count, as on its own page.
create or replace function public.achievement_mark(viewer uuid)
returns integer
language sql
security definer
set search_path = public
as $$
    with reached as (
        insert into public.achievement_marks (account, track, level)
        select viewer, l.track, s.level::integer
          from public.achievement_ladders() l
          join public.achievement_numbers(viewer, public.trust_is_test_account(viewer)) x on x.track = l.track
         cross join lateral unnest(l.steps) with ordinality s(at_least, level)
         where s.at_least <= x.n
        on conflict on constraint achievement_marks_pkey do nothing
        returning 1)
    select count(*)::integer from reached
$$;

-- [viewer] opened their achievements' notices: each read now. {read}: how
-- many were not before.
create or replace function public.achievement_read(viewer uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with done as (
        update public.achievement_marks a set read_at = now()
         where a.account = viewer and a.read_at is null
        returning 1)
    select jsonb_build_object('read', (select count(*) from done))
$$;

-- What happened to [viewer]'s models, and the replies to them, as
-- replies.sql's; and each level they reached (kind 'achievement', [model]
-- null): a row a track each time levels were written down, its highest,
-- [read] once its group was opened.
-- REPLACED LATER: challenge_notices.sql replaces this function (the
-- challenges). Apply challenge_notices.sql again right after this file:
-- tools/apply_sql.mjs refuses it alone, unless
-- --again=supabase/challenge_notices.sql.
create or replace function public.notification_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, model text, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with mine as (
        select m.id, m.name from public.shared_models m
         where m.owner = viewer and m.published and not m.barred),
    threads as (
        -- The conversations the viewer is in: each comment of theirs, or
        -- the one they replied to, from when they joined it.
        select coalesce(o.parent, o.id) as root, min(o.at) as joined, bool_or(o.parent is null) as theirs
          from public.model_comments o
         where o.author = viewer and o.removed_at is null
         group by coalesce(o.parent, o.id))
    select f.kind, f.at,
           case when f.kind = 'remix' then f.item->>'of' else f.item->>'model' end,
           f.item || case when k.parent is not null then jsonb_build_object('parent', k.parent) else '{}'::jsonb end
      from public.feed_rows(viewer, since, until) f
      left join public.model_comments k on f.kind = 'comment' and k.id = (f.item->>'comment')::bigint
     where (f.kind in ('comment', 'remix') or (f.kind = 'photo' and (f.item->>'yours')::boolean))
       and public.comment_parent_shown(k.parent)
       -- Told below, as a reply.
       and not exists (select 1 from threads t where t.root = k.parent and k.at > t.joined)
    union all
    -- A reply in one of those, by somebody else, in this life of its
    -- link (comments_on's rule).
    select 'reply'::text, k.at, k.model,
           jsonb_build_object('comment', k.id, 'parent', k.parent, 'yours', t.theirs, 'model', k.model,
                              'name', m.name, 'version', k.version, 'step', k.step, 'said', left(k.body, 240),
                              'by', public.feed_who(k.author))
      from threads t
      join public.model_comments k on k.parent = t.root and k.at > t.joined
      join public.shared_models m on m.id = k.model
     where k.author <> viewer and m.published and not m.barred
       and k.removed_at is null and k.hidden_at is null and public.shown_publicly(k.author)
       and public.comment_parent_shown(k.parent)
       and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = k.model), '-infinity')
       and k.at > since and k.at <= until
    union all
    select 'likes'::text, max(l.at), m.id,
           jsonb_build_object('model', m.id, 'name', m.name, 'likes', count(*),
                              'day', to_char(l.at at time zone 'UTC', 'YYYY-MM-DD'))
      from public.model_likes l
      join mine m on m.id = l.model
     where l.account <> viewer and l.at > since and l.at <= until
     group by m.id, m.name, to_char(l.at at time zone 'UTC', 'YYYY-MM-DD')
    union all
    select 'result'::text, c.settled_at, m.id,
           jsonb_build_object('model', m.id, 'name', m.name, 'challenge', c.id, 'title', c.title,
                              'way', e.way, 'won', w.model is not null, 'votes', w.votes)
      from public.challenge_entries e
      join public.challenges c on c.id = e.challenge
      join mine m on m.id = e.model
      left join public.challenge_winners w on w.challenge = c.id and w.way = e.way and w.model = e.model
     where e.owner = viewer and c.settled_at is not null
       and c.settled_at > since and c.settled_at <= until
    union all
    select 'achievement'::text, a.at, null::text,
           jsonb_build_object('track', a.track, 'level', max(a.level), 'of', cardinality(l.steps),
                              'reached', l.steps[max(a.level)], 'next', l.steps[max(a.level) + 1],
                              'read', bool_and(a.read_at is not null))
      from public.achievement_marks a
      join public.achievement_ladders() l on l.track = a.track
     where a.account = viewer and a.at > since and a.at <= until
     group by a.track, a.at, l.steps
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.achievement_ladders() from public, anon, authenticated;
grant execute on function public.achievement_ladders() to service_role;
revoke all on function public.achievement_numbers(uuid, boolean) from public, anon, authenticated;
grant execute on function public.achievement_numbers(uuid, boolean) to service_role;
revoke all on function public.achievement_levels(uuid, boolean) from public, anon, authenticated;
grant execute on function public.achievement_levels(uuid, boolean) to service_role;
revoke all on function public.achievement_mark(uuid) from public, anon, authenticated;
grant execute on function public.achievement_mark(uuid) to service_role;
revoke all on function public.achievement_read(uuid) from public, anon, authenticated;
grant execute on function public.achievement_read(uuid) to service_role;
revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
