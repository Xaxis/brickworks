-- The loop measured on real people (loopmetrics, 2026-11-23; docs/ANALYTICS.md
-- "The loop", docs/MASTERPLAN.md): /admin › Analytics › Funnels' third card,
-- GET /api/admin?op=loop (api/_loop.js).
--
-- Each step of discover, open, change, share, hear back, come back, this
-- range against the one before, in people as the console counts them (a
-- person a day: an account once, a signed-out visit once), and each
-- person-day placed at the furthest step it reached. Built (a model's steps
-- followed to the last one) has no account and is a number of its own.
--
-- Functions only: no table, no column, nothing new kept about anybody
-- (docs/SOCIAL.md D13). It reads what is kept already: the counted visits'
-- rows (insights_events and insights_visits, 30 days), the connector's days
-- (relay_call_days), and the social tables (share_publishes, build_photos,
-- model_comments, talk_threads, talk_posts, challenge_entries, model_likes,
-- follows, model_builds, shared_models). It writes only temporary tables of
-- its own, dropped at the end of its transaction. The server's alone:
-- security definer, granted to the service role.
--
-- Needs analytics.sql and analytics2.sql, console2.sql (relay_call_days),
-- shared_models.sql, people.sql, comments.sql, replies.sql, follows.sql,
-- builds.sql, talk.sql and challenges.sql: all applied on the live project.
-- Applied with tools/apply_sql.mjs (a dry run first: tools/loop_funnel_try.sql).

-- [p_steps] is api/_loop.js's LOOP: [[step, surface, kind, name], ...], what
-- counts as discovered, opened, changed and shared among the counter's
-- names, at most 63 (each is a bit of a bigint). [p_accounts] [{h, id, plan}]
-- every account of the read's kind (the checks' own for [p_tests]); h is
-- none where the server has no VIEW_SECRET. [p_filters] {device, lang, plan,
-- signed} as insights_read takes them.
create or replace function public.insights_loop(p_from date, p_to date, p_tests boolean, p_filters jsonb,
    p_accounts jsonb, p_steps jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    today date := (now() at time zone 'utc')::date;
    -- Raw rows are kept from this day on (insights_forget).
    first_kept date := (now() at time zone 'utc')::date - 30;
    f jsonb := coalesce(p_filters, '{}'::jsonb);
    b_from date;
    lo date;
    lo_at timestamptz;
    hi_at timestamptz;
    m_disc bigint;
    m_open bigint;
    m_change bigint;
    m_share bigint;
    r record;
    one jsonb;
    out jsonb;
begin
    if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 400 then
        raise exception 'a range of at most 400 days';
    end if;
    b_from := p_from - (p_to - p_from + 1);
    -- The first day read: the range before's first, or the first day kept.
    lo := greatest(b_from, first_kept);
    lo_at := lo::timestamp at time zone 'utc';
    -- Hearing back is looked for up to 7 days past a person-day.
    hi_at := (least(today, p_to + 7) + 1)::timestamp at time zone 'utc';

    -- Every account of the read's kind: its hash, id and plan.
    create temp table if not exists loop_a (h text, id uuid, plan text) on commit drop;
    truncate pg_temp.loop_a;
    insert into pg_temp.loop_a
    -- The server's own list (api/_loop.js, from the auth list): an id that
    -- is no uuid fails the read rather than being let go.
    select distinct on (a.id) case when length(a.h) = 24 then a.h end, a.id, coalesce(a.plan, 'free')
      from jsonb_to_recordset(case when jsonb_typeof(p_accounts) = 'array' then p_accounts else '[]'::jsonb end)
           as a(h text, id uuid, plan text)
     where a.id is not null;
    analyze pg_temp.loop_a;

    -- The steps' names in the table's order, each a bit.
    create temp table if not exists loop_s (at integer, bit bigint, step text, surface text, kind text, name text) on commit drop;
    truncate pg_temp.loop_s;
    insert into pg_temp.loop_s
    select row_number() over (order by min(x.at)), 0, x.step, x.surface, x.kind, x.name
      from (select s->>0 as step, s->>1 as surface, s->>2 as kind, s->>3 as name, at
              from jsonb_array_elements(case when jsonb_typeof(p_steps) = 'array' then p_steps else '[]'::jsonb end)
                   with ordinality as given(s, at)
             where jsonb_typeof(s) = 'array' and s->>0 in ('discovered', 'opened', 'changed', 'shared')
               and s->>1 in ('site', 'studio') and s->>2 ~ '^[a-z]{1,20}$' and s->>3 ~ '^[a-z0-9_:/#.-]{1,60}$') x
     group by x.step, x.surface, x.kind, x.name;
    if (select count(*) from pg_temp.loop_s) > 63 then
        raise exception 'the loop counts at most 63 names';
    end if;
    update pg_temp.loop_s set bit = (1::bigint << (at - 1));
    analyze pg_temp.loop_s;
    select coalesce(bit_or(bit) filter (where step = 'discovered'), 0), coalesce(bit_or(bit) filter (where step = 'opened'), 0),
           coalesce(bit_or(bit) filter (where step = 'changed'), 0), coalesce(bit_or(bit) filter (where step = 'shared'), 0)
      into m_disc, m_open, m_change, m_share
      from pg_temp.loop_s;

    -- One pass over the rows kept: each visit's day from the first day read
    -- to today, with the loop's names it did as bits.
    create temp table if not exists loop_vd (day date, visit text, bits bigint) on commit drop;
    truncate pg_temp.loop_vd;
    insert into pg_temp.loop_vd
    select e.day, e.visit, coalesce(bit_or(s.bit), 0)
      from public.insights_events e
      left join pg_temp.loop_s s on s.name = e.name and s.kind = e.kind and s.surface = e.surface
     where e.day between lo and today and e.test = p_tests and e.visit is not null
     group by e.day, e.visit;

    -- Each person-day of the two ranges, as Overview counts visitors: a
    -- signed-in account once, a signed-out visit once at its weight; its plan.
    -- The device and language filters keep the visits on them.
    create temp table if not exists loop_pd (day date, person text, who text, w integer, plan text, bits bigint) on commit drop;
    truncate pg_temp.loop_pd;
    insert into pg_temp.loop_pd
    select x.day, x.person, x.who, x.w, case when x.who is null then 'none' else coalesce(a.plan, 'free') end, x.bits
      from (select vd.day, coalesce(v.account, vd.visit) as person, max(v.account) as who, max(coalesce(v.weight, 1))::integer as w,
                   bit_or(vd.bits) as bits
              from pg_temp.loop_vd vd join public.insights_visits v on v.visit = vd.visit
             where vd.day <= p_to and (f->>'device' is null or v.device = f->>'device') and (f->>'lang' is null or v.lang = f->>'lang')
             group by vd.day, coalesce(v.account, vd.visit)) x
      left join (select distinct on (h) h, plan from pg_temp.loop_a where h is not null) a on a.h = x.who;
    delete from pg_temp.loop_pd p
     where (f->>'plan' = '!owner' and p.plan = 'owner')
        or (f->>'plan' is not null and f->>'plan' <> '!owner' and p.plan <> f->>'plan')
        or (f->>'signed' is not null and (p.who is not null) <> (f->>'signed')::boolean);
    analyze pg_temp.loop_pd;

    -- The accounts in it, with their ids where the hash is known.
    create temp table if not exists loop_w (h text primary key, id uuid) on commit drop;
    truncate pg_temp.loop_w;
    insert into pg_temp.loop_w
    select w.who, a.id
      from (select distinct who from pg_temp.loop_pd where who is not null) w
      left join (select distinct on (h) h, id from pg_temp.loop_a where h is not null) a on a.h = w.who;
    analyze pg_temp.loop_w;

    -- What each of them shared, a day, as the social tables keep it: a model
    -- published from the studio counts, which the page never sees. What the
    -- site's owner took down is not the loop's.
    create temp table if not exists loop_k (who text, day date, source text) on commit drop;
    truncate pg_temp.loop_k;
    insert into pg_temp.loop_k
    select distinct k.who, k.day, k.source from (
        select w.h as who, (x.at at time zone 'utc')::date as day, 'share_publishes' as source
          from public.share_publishes x join pg_temp.loop_w w on w.id = x.owner
         where x.at >= lo_at and x.at < hi_at
        union all
        select w.h, (x.at at time zone 'utc')::date, 'build_photos'
          from public.build_photos x join pg_temp.loop_w w on w.id = x.account
         where x.at >= lo_at and x.at < hi_at and x.removed_at is null
        union all
        select w.h, (x.at at time zone 'utc')::date, 'model_comments'
          from public.model_comments x join pg_temp.loop_w w on w.id = x.author
         where x.at >= lo_at and x.at < hi_at and x.removed_by is distinct from 'admin'
        union all
        select w.h, (x.at at time zone 'utc')::date, 'talk_posts'
          from public.talk_posts x join pg_temp.loop_w w on w.id = x.author
          join public.talk_threads t on t.id = x.thread
         where x.at >= lo_at and x.at < hi_at and x.removed_by is distinct from 'admin' and t.test = p_tests
        union all
        select w.h, (x.at at time zone 'utc')::date, 'challenge_entries'
          from public.challenge_entries x join pg_temp.loop_w w on w.id = x.owner
         where x.at >= lo_at and x.at < hi_at
    ) k;
    analyze pg_temp.loop_k;

    -- What each of them heard back, a day: from somebody else of the read's
    -- kind (never the checks' pool on people's read, nor themselves), on a
    -- model of theirs, a comment or post of theirs, or themselves; a build
    -- is a device's, with no account.
    create temp table if not exists loop_h (h text, day date, kind text) on commit drop;
    truncate pg_temp.loop_h;
    insert into pg_temp.loop_h
    select distinct h.h, h.day, h.kind from (
        select w.h, (x.at at time zone 'utc')::date as day, 'like' as kind
          from public.model_likes x join public.shared_models m on m.id = x.model join pg_temp.loop_w w on w.id = m.owner
         where x.at >= lo_at and x.at < hi_at and x.account <> m.owner
           and exists (select 1 from pg_temp.loop_a a where a.id = x.account)
        union all
        select w.h, (x.at at time zone 'utc')::date, 'comment'
          from public.model_comments x join public.shared_models m on m.id = x.model join pg_temp.loop_w w on w.id = m.owner
         where x.at >= lo_at and x.at < hi_at and x.author <> m.owner and x.removed_by is distinct from 'admin'
           and exists (select 1 from pg_temp.loop_a a where a.id = x.author)
        union all
        select w.h, (x.at at time zone 'utc')::date, 'follow'
          from public.follows x join pg_temp.loop_w w on w.id = x.followed
         where x.at >= lo_at and x.at < hi_at
           and exists (select 1 from pg_temp.loop_a a where a.id = x.follower)
        union all
        select w.h, (x.at at time zone 'utc')::date, 'build'
          from public.model_builds x join public.shared_models m on m.id = x.model join pg_temp.loop_w w on w.id = m.owner
         where x.at >= lo_at and x.at < hi_at
        union all
        select w.h, (x.at at time zone 'utc')::date, 'build'
          from public.build_photos x join public.shared_models m on m.id = x.model join pg_temp.loop_w w on w.id = m.owner
         where x.at >= lo_at and x.at < hi_at and x.account <> m.owner and x.removed_at is null
           and exists (select 1 from pg_temp.loop_a a where a.id = x.account)
        union all
        select w.h, (x.at at time zone 'utc')::date, 'reply'
          from public.model_comments x join public.model_comments p on p.id = x.parent join pg_temp.loop_w w on w.id = p.author
         where x.at >= lo_at and x.at < hi_at and x.author <> p.author and x.removed_by is distinct from 'admin'
           and exists (select 1 from pg_temp.loop_a a where a.id = x.author)
        union all
        select w.h, (x.at at time zone 'utc')::date, 'reply'
          from public.talk_posts x join public.talk_posts p on p.id = x.answers join pg_temp.loop_w w on w.id = p.author
          join public.talk_threads t on t.id = x.thread
         where x.at >= lo_at and x.at < hi_at and x.author <> p.author and x.removed_by is distinct from 'admin'
           and t.test = p_tests and exists (select 1 from pg_temp.loop_a a where a.id = x.author)
        union all
        select w.h, (x.at at time zone 'utc')::date, 'reply'
          from public.talk_posts x join public.talk_threads t on t.id = x.thread join pg_temp.loop_w w on w.id = t.author
         where x.at >= lo_at and x.at < hi_at and not x.first and x.author <> t.author
           and x.removed_by is distinct from 'admin' and t.test = p_tests
           and exists (select 1 from pg_temp.loop_a a where a.id = x.author)
    ) h;
    create index if not exists loop_h_at on pg_temp.loop_h (h, day);
    analyze pg_temp.loop_h;

    -- Each of them active, a day, after the first day read up to today: in
    -- the studio, or on the site signed in (on any device or language), or
    -- through Claude, as Retention counts it. Every such day is a kept row's,
    -- since the first day read is never before the rows kept.
    create temp table if not exists loop_act (h text, day date) on commit drop;
    truncate pg_temp.loop_act;
    insert into pg_temp.loop_act
    select x.h, x.day from (
        select v.account as h, vd.day from pg_temp.loop_vd vd join public.insights_visits v on v.visit = vd.visit
          join pg_temp.loop_w w on w.h = v.account
        union
        select w.h, c.day from public.relay_call_days c join pg_temp.loop_w w on w.id = c.owner
         where c.day > lo and c.day <= today and c.calls > 0
    ) x;
    create index if not exists loop_act_at on pg_temp.loop_act (h, day);
    analyze pg_temp.loop_act;

    -- Each signed-in person-day, as far as the account goes: heard back that
    -- day or in the 7 after, active again on a later day within 7 and 30.
    create temp table if not exists loop_far (day date, who text, heard text[], back7 boolean, back30 boolean) on commit drop;
    truncate pg_temp.loop_far;
    insert into pg_temp.loop_far
    select p.day, p.who,
           coalesce((select array_agg(distinct h.kind) from pg_temp.loop_h h
                      where h.h = p.who and h.day between p.day and p.day + 7), '{}'),
           exists (select 1 from pg_temp.loop_act a where a.h = p.who and a.day > p.day and a.day <= p.day + 7),
           exists (select 1 from pg_temp.loop_act a where a.h = p.who and a.day > p.day and a.day <= p.day + 30)
      from (select distinct day, who from pg_temp.loop_pd where who is not null) p;

    out := jsonb_build_object('range', jsonb_build_object('from', p_from, 'to', p_to, 'before_from', b_from,
        'before_to', p_from - 1, 'kept_from', first_kept, 'today', today));

    create temp table if not exists loop_p (day date, person text, who text, w integer, bits bigint, kept text[], heard text[],
        discovered boolean, opened boolean, changed boolean, shared boolean, back7 boolean, back30 boolean, furthest integer)
        on commit drop;
    for r in select * from (values ('this', p_from, p_to), ('before', b_from, p_from - 1)) as x(label, rf, rt) loop
        truncate pg_temp.loop_p;
        insert into pg_temp.loop_p
        select q.*, case when q.back7 then 6 when cardinality(q.heard) > 0 then 5 when q.shared then 4 when q.changed then 3
                         when q.opened then 2 when q.discovered then 1 else 0 end
          from (
            select p.day, p.person, p.who, p.w, p.bits, coalesce(k.sources, '{}') as kept, coalesce(far.heard, '{}') as heard,
                   p.bits & m_disc <> 0 as discovered, p.bits & m_open <> 0 as opened, p.bits & m_change <> 0 as changed,
                   p.bits & m_share <> 0 or k.sources is not null as shared,
                   coalesce(far.back7, false) as back7, coalesce(far.back30, false) as back30
              from pg_temp.loop_pd p
              left join (select who, day, array_agg(source) as sources from pg_temp.loop_k group by who, day) k
                     on k.who = p.who and k.day = p.day
              left join pg_temp.loop_far far on far.who = p.who and far.day = p.day
             where p.day between r.rf and r.rt
          ) q;

        select jsonb_build_object(
            'from', r.rf, 'to', r.rt, 'days', r.rt - r.rf + 1,
            'kept_days', greatest(0, r.rt - greatest(r.rf, first_kept) + 1),
            'people', coalesce(sum(w), 0),
            'signed_in', coalesce(sum(w) filter (where who is not null), 0),
            'steps', jsonb_build_object(
                'discovered', coalesce(sum(w) filter (where discovered), 0),
                'opened', coalesce(sum(w) filter (where opened), 0),
                'changed', coalesce(sum(w) filter (where changed), 0),
                'shared', coalesce(sum(w) filter (where shared), 0),
                'heard_back', coalesce(sum(w) filter (where cardinality(heard) > 0), 0),
                'came_back', coalesce(sum(w) filter (where back7), 0),
                'came_back_30', coalesce(sum(w) filter (where back30), 0)),
            'stopped', jsonb_build_object(
                'none', coalesce(sum(w) filter (where furthest = 0), 0),
                'discovered', coalesce(sum(w) filter (where furthest = 1), 0),
                'opened', coalesce(sum(w) filter (where furthest = 2), 0),
                'changed', coalesce(sum(w) filter (where furthest = 3), 0),
                'shared', coalesce(sum(w) filter (where furthest = 4), 0),
                'heard_back', coalesce(sum(w) filter (where furthest = 5), 0),
                'came_back', coalesce(sum(w) filter (where furthest = 6), 0)),
            'kept', jsonb_build_array(
                jsonb_build_object('step', 'shared', 'name', 'share_publishes', 'people',
                    coalesce(sum(w) filter (where 'share_publishes' = any(kept)), 0)),
                jsonb_build_object('step', 'shared', 'name', 'build_photos', 'people',
                    coalesce(sum(w) filter (where 'build_photos' = any(kept)), 0)),
                jsonb_build_object('step', 'shared', 'name', 'model_comments', 'people',
                    coalesce(sum(w) filter (where 'model_comments' = any(kept)), 0)),
                jsonb_build_object('step', 'shared', 'name', 'talk_posts', 'people',
                    coalesce(sum(w) filter (where 'talk_posts' = any(kept)), 0)),
                jsonb_build_object('step', 'shared', 'name', 'challenge_entries', 'people',
                    coalesce(sum(w) filter (where 'challenge_entries' = any(kept)), 0))),
            'heard', jsonb_build_object(
                'like', coalesce(sum(w) filter (where 'like' = any(heard)), 0),
                'comment', coalesce(sum(w) filter (where 'comment' = any(heard)), 0),
                'follow', coalesce(sum(w) filter (where 'follow' = any(heard)), 0),
                'build', coalesce(sum(w) filter (where 'build' = any(heard)), 0),
                'reply', coalesce(sum(w) filter (where 'reply' = any(heard)), 0)))
          into one
          from pg_temp.loop_p;

        -- Each step's names, with the people who did each, in the table's order.
        one := one || jsonb_build_object('acts', (
            select coalesce(jsonb_agg(jsonb_build_object('step', s.step, 'surface', s.surface, 'kind', s.kind, 'name', s.name,
                       'people', coalesce(c.people, 0)) order by s.at), '[]'::jsonb)
              from pg_temp.loop_s s
              left join lateral (select sum(p.w) as people from pg_temp.loop_p p where p.bits & s.bit <> 0) c on true),
            -- Built: each model followed to its last step, once a device, of
            -- a model by an account of the read's kind; no account, no filter.
            'built', (
            select count(*) from public.model_builds b join public.shared_models m on m.id = b.model
             where b.at >= r.rf::timestamp at time zone 'utc' and b.at < (r.rt + 1)::timestamp at time zone 'utc'
               and exists (select 1 from pg_temp.loop_a a where a.id = m.owner)));
        out := out || jsonb_build_object(r.label, one);
    end loop;
    return out;
end;
$$;

revoke all on function public.insights_loop(date, date, boolean, jsonb, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.insights_loop(date, date, boolean, jsonb, jsonb, jsonb) to service_role;
