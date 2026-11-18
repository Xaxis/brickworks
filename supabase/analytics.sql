-- How people use the site and the studio (insights, 2026-11-18;
-- docs/ANALYTICS.md): what /admin › Analytics reads.
--
--   insights_visits    a visit: one tab's time on brickworks.diy, ended by 30
--                      minutes away. Its id is random, made in the tab and
--                      forgotten with it; nothing ties two visits but an
--                      account, and an account only as a keyed hash
--                      (HMAC-SHA256 with a server secret, api/_analytics.js),
--                      never its id. What it came from (the referrer's host,
--                      utm_*), the kind of device, browser and system, the
--                      site's language, its engaged seconds. Never an
--                      address, a page's id, typed words, a model, an IP.
--   insights_events    what happened in it, counted: a page's template seen
--                      (/m/:id, never the id), a site act (an API op that
--                      wrote, by its name), a studio tool, panel, control or
--                      command used, a part put down, a save, a Simulate,
--                      Render, booklet or Together run with how long and
--                      whether it went, load times and frame rates, an
--                      error's place (a file and line, never its words),
--                      the last act before leaving; and each tool call the
--                      connector relayed (api/mcp.js). Kept 30 days.
--   insights_seen      every studio control shown at least once, by name:
--                      what is never pressed is told from it. A row a name.
--   insights_days      the daily rollup: every count above by day, surface,
--                      kind, name, device, language, signed in or not, plan
--                      (browser for load and frame rows, channel for visit
--                      rows), with visits, people, n, successes and
--                      failures, and timings' 50th, 75th and 95th
--                      percentiles. Kept for good.
--   insights_account_days, insights_account_firsts
--                      a hashed account's active days (and whether it
--                      built), and its first part, save and where it was
--                      first seen from: retention and the funnel past the
--                      30 days. Kept for good.
--   insights_day_rows  rows taken a day, so no flood can take more than
--                      DAY_CAP of them.
--   insights_rollups   which days are rolled up.
--
-- Only the server touches any of it, through functions that are security
-- definer and granted to the service role alone. Row security on, no
-- policy, every role's grants taken back. Only additions: new tables and
-- functions, nothing that was there changed.
--
-- Applied with tools/apply_sql.mjs (a dry run first: tools/analytics_try.sql).

create table if not exists public.insights_visits (
    visit     text        primary key constraint insights_visits_visit check (visit ~ '^[a-z0-9]{16}$'),
    day       date        not null default (now() at time zone 'utc')::date,
    first_at  timestamptz not null default now(),
    last_at   timestamptz not null default now(),
    test      boolean     not null default false,
    account   text        constraint insights_visits_account check (account ~ '^[a-z0-9]{24}$'),
    landing   text        constraint insights_visits_landing check (landing ~ '^/[a-z0-9_:/.-]{0,79}$'),
    studio    boolean     not null default false,
    channel   text        not null default 'direct' constraint insights_visits_channel
                  check (channel in ('direct', 'search', 'social', 'ai', 'email', 'paid', 'referral')),
    source    text        constraint insights_visits_source check (source ~ '^[a-z0-9_.-]{1,60}$'),
    medium    text        constraint insights_visits_medium check (medium ~ '^[a-z0-9_.-]{1,40}$'),
    campaign  text        constraint insights_visits_campaign check (campaign ~ '^[a-z0-9_.-]{1,60}$'),
    device    text        not null default 'desktop' constraint insights_visits_device check (device in ('desktop', 'phone', 'tablet')),
    browser   text        not null default 'other' constraint insights_visits_browser
                  check (browser in ('chrome', 'edge', 'firefox', 'safari', 'samsung', 'opera', 'other')),
    os        text        not null default 'other' constraint insights_visits_os
                  check (os in ('windows', 'macos', 'linux', 'android', 'ios', 'chromeos', 'other')),
    lang      text        not null default 'en' constraint insights_visits_lang check (lang in ('en', 'de', 'fr', 'es')),
    -- The visit's last act so far (tool:move, press:render_go, view:/gallery):
    -- where it stopped, once it has.
    last_act  text        constraint insights_visits_last_act check (last_act ~ '^[a-z0-9_:/#.-]{1,60}$'),
    seconds   integer     not null default 0 constraint insights_visits_seconds check (seconds between 0 and 86400),
    beacons   integer     not null default 0,
    rows      integer     not null default 0
);
create index if not exists insights_visits_last on public.insights_visits (last_at);
create index if not exists insights_visits_account on public.insights_visits (account) where account is not null;

create table if not exists public.insights_events (
    id       bigint      generated always as identity primary key,
    visit    text        references public.insights_visits (visit) on delete cascade,
    at       timestamptz not null default now(),
    day      date        not null default (now() at time zone 'utc')::date,
    test     boolean     not null default false,
    -- A relayed tool call's account (its visit is none); a visit's is the visit's.
    account  text        constraint insights_events_account check (account ~ '^[a-z0-9]{24}$'),
    surface  text        not null constraint insights_events_surface check (surface in ('site', 'studio', 'mcp')),
    kind     text        not null constraint insights_events_kind check (kind in ('view', 'act', 'tool', 'panel', 'press',
                 'command', 'run', 'milestone', 'part', 'save', 'load', 'frames', 'error', 'call')),
    name     text        not null constraint insights_events_name check (name ~ '^[a-z0-9_:/#.-]{1,60}$'),
    n        integer     not null default 1 constraint insights_events_n check (n between 1 and 10000),
    ms       real        constraint insights_events_ms check (ms >= 0 and ms <= 86400000),
    ok       boolean,
    constraint insights_events_whose check (visit is not null or surface = 'mcp')
);
create index if not exists insights_events_day on public.insights_events (day, test);
create index if not exists insights_events_visit on public.insights_events (visit);

create table if not exists public.insights_seen (
    surface   text    not null constraint insights_seen_surface check (surface in ('site', 'studio')),
    name      text    not null constraint insights_seen_name check (name ~ '^[a-z0-9_:/#.-]{1,60}$'),
    test      boolean not null default false,
    first_day date    not null default (now() at time zone 'utc')::date,
    last_day  date    not null default (now() at time zone 'utc')::date,
    visits    integer not null default 1,
    primary key (surface, name, test)
);

create table if not exists public.insights_days (
    day        date    not null,
    test       boolean not null,
    surface    text    not null,
    kind       text    not null,
    name       text    not null,
    device     text    not null default '',
    lang       text    not null default '',
    signed_in  boolean not null default false,
    plan       text    not null default 'none',
    browser    text    not null default '',
    channel    text    not null default '',
    visits     integer not null default 0,
    people     integer not null default 0,
    n          bigint  not null default 0,
    ok         integer not null default 0,
    failed     integer not null default 0,
    timed      integer not null default 0,
    ms_sum     double precision not null default 0,
    ms_p50     real,
    ms_p75     real,
    ms_p95     real,
    primary key (day, test, surface, kind, name, device, lang, signed_in, plan, browser, channel)
);
create index if not exists insights_days_kind on public.insights_days (kind, day);

create table if not exists public.insights_account_days (
    account text    not null constraint insights_account_days_account check (account ~ '^[a-z0-9]{24}$'),
    day     date    not null,
    test    boolean not null default false,
    built   boolean not null default false,
    studio  boolean not null default false,
    primary key (account, day)
);

create table if not exists public.insights_account_firsts (
    account        text        primary key constraint insights_account_firsts_account check (account ~ '^[a-z0-9]{24}$'),
    test           boolean     not null default false,
    first_seen_at  timestamptz not null,
    first_part_at  timestamptz,
    first_save_at  timestamptz,
    channel        text,
    source         text,
    campaign       text
);

create table if not exists public.insights_day_rows (
    day  date    primary key,
    rows integer not null default 0
);

create table if not exists public.insights_rollups (
    day       date        primary key,
    rolled_at timestamptz not null default now(),
    rows      integer     not null default 0
);

alter table public.insights_visits enable row level security;
alter table public.insights_events enable row level security;
alter table public.insights_seen enable row level security;
alter table public.insights_days enable row level security;
alter table public.insights_account_days enable row level security;
alter table public.insights_account_firsts enable row level security;
alter table public.insights_day_rows enable row level security;
alter table public.insights_rollups enable row level security;

revoke all on public.insights_visits from public, anon, authenticated, service_role;
revoke all on public.insights_events from public, anon, authenticated, service_role;
revoke all on public.insights_seen from public, anon, authenticated, service_role;
revoke all on public.insights_days from public, anon, authenticated, service_role;
revoke all on public.insights_account_days from public, anon, authenticated, service_role;
revoke all on public.insights_account_firsts from public, anon, authenticated, service_role;
revoke all on public.insights_day_rows from public, anon, authenticated, service_role;
revoke all on public.insights_rollups from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Taking a visit's counts (POST /api/plans?op=tally, api/_analytics.js).

-- The most rows a day may take, whoever sends them, and a visit.
create or replace function public.insights_caps()
returns jsonb
language sql
immutable
set search_path = ''
as $$ select '{"day": 200000, "visit": 1500, "batch": 80, "seen": 400}'::jsonb $$;

-- A visit's beacon: the visit as it is now, what happened since the last
-- beacon ([[surface, kind, name, n, ms, ok], ...]), the studio's controls
-- shown since, and the account's hash when signed in. Anything that is not
-- what a row may hold is let go, never an error: a beacon is never
-- answered with what was refused. Returns the rows taken.
create or replace function public.insights_take(p_visit text, p_about jsonb, p_events jsonb, p_seen jsonb,
    p_account text, p_seconds integer, p_test boolean)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    caps jsonb := public.insights_caps();
    today date := (now() at time zone 'utc')::date;
    had integer;
    fresh boolean;
    room integer;
    taken integer := 0;
    a jsonb := coalesce(p_about, '{}'::jsonb);
begin
    if p_visit is null or p_visit !~ '^[a-z0-9]{16}$' then
        return 0;
    end if;
    if p_account is not null and p_account !~ '^[a-z0-9]{24}$' then
        p_account := null;
    end if;
    -- A day's flood is let go whole: no new visit past the day's cap.
    if coalesce((select d.rows from public.insights_day_rows d where d.day = today), 0) >= (caps->>'day')::integer
       and not exists (select 1 from public.insights_visits v where v.visit = p_visit) then
        return 0;
    end if;
    insert into public.insights_visits as v (visit, test, account, landing, studio, channel, source, medium, campaign,
            device, browser, os, lang, last_act, seconds, beacons)
    values (p_visit, coalesce(p_test, false), p_account,
            case when a->>'landing' ~ '^/[a-z0-9_:/.-]{0,79}$' then a->>'landing' end,
            case when jsonb_typeof(a->'studio') = 'boolean' then (a->>'studio')::boolean else false end,
            case when a->>'channel' in ('direct', 'search', 'social', 'ai', 'email', 'paid', 'referral') then a->>'channel'
                 else 'direct' end,
            case when a->>'source' ~ '^[a-z0-9_.-]{1,60}$' then a->>'source' end,
            case when a->>'medium' ~ '^[a-z0-9_.-]{1,40}$' then a->>'medium' end,
            case when a->>'campaign' ~ '^[a-z0-9_.-]{1,60}$' then a->>'campaign' end,
            case when a->>'device' in ('desktop', 'phone', 'tablet') then a->>'device' else 'desktop' end,
            case when a->>'browser' in ('chrome', 'edge', 'firefox', 'safari', 'samsung', 'opera') then a->>'browser'
                 else 'other' end,
            case when a->>'os' in ('windows', 'macos', 'linux', 'android', 'ios', 'chromeos') then a->>'os' else 'other' end,
            case when a->>'lang' in ('en', 'de', 'fr', 'es') then a->>'lang' else 'en' end,
            case when a->>'last' ~ '^[a-z0-9_:/#.-]{1,60}$' then a->>'last' end,
            least(greatest(coalesce(p_seconds, 0), 0), 3600), 1)
    on conflict (visit) do update
       set last_at = now(),
           account = coalesce(excluded.account, v.account),
           studio = v.studio or excluded.studio,
           last_act = coalesce(excluded.last_act, v.last_act),
           seconds = least(v.seconds + excluded.seconds, 86400),
           beacons = v.beacons + 1
    returning v.rows, (v.xmax = 0) into had, fresh;

    -- The day's rows and the visit's, each up to its cap; a new visit is a row.
    insert into public.insights_day_rows as d (day, rows) values (today, case when fresh then 1 else 0 end)
    on conflict (day) do update set rows = d.rows + excluded.rows;
    select least((caps->>'visit')::integer - had, (caps->>'day')::integer - d.rows, (caps->>'batch')::integer)
      into room from public.insights_day_rows d where d.day = today;
    if room > 0 and jsonb_typeof(p_events) = 'array' then
        with given as (
            select e->>0 as surface, e->>1 as kind, e->>2 as name,
                   case when jsonb_typeof(e->3) = 'number' then (e->>3)::numeric end as n,
                   case when jsonb_typeof(e->4) = 'number' then (e->>4)::numeric end as ms,
                   case when jsonb_typeof(e->5) = 'boolean' then (e->>5)::boolean end as ok
              from jsonb_array_elements(p_events) as e
             where jsonb_typeof(e) = 'array'
             limit room
        ), kept as (
            insert into public.insights_events (visit, test, surface, kind, name, n, ms, ok)
            select p_visit, coalesce(p_test, false), g.surface, g.kind, g.name,
                   greatest(1, least(coalesce(round(g.n), 1), 10000))::integer,
                   case when g.ms between 0 and 86400000 then g.ms::real end, g.ok
              from given g
             where g.surface in ('site', 'studio')
               and g.kind in ('view', 'act', 'tool', 'panel', 'press', 'command', 'run', 'milestone', 'part', 'save',
                              'load', 'frames', 'error')
               and g.name ~ '^[a-z0-9_:/#.-]{1,60}$'
            returning 1
        )
        select count(*) into taken from kept;
        if taken > 0 then
            update public.insights_day_rows set rows = rows + taken where day = today;
            update public.insights_visits set rows = rows + taken where visit = p_visit;
        end if;
    end if;

    -- The studio's controls shown: a row a name, however many visits.
    if jsonb_typeof(p_seen) = 'array' then
        insert into public.insights_seen as s (surface, name, test)
        select distinct 'studio', x, coalesce(p_test, false)
          from (select jsonb_array_elements_text(p_seen) as x limit (caps->>'seen')::integer) given
         where x ~ '^[a-z0-9_:/#.-]{1,60}$'
        on conflict (surface, name, test) do update
           set last_day = excluded.last_day, visits = s.visits + 1;
    end if;
    return taken;
end;
$$;

-- A tool call the connector relayed (api/mcp.js): its name, whether it
-- went, how long it took, and whose (a hash). Returns whether it was kept.
create or replace function public.insights_call(p_account text, p_tool text, p_ok boolean, p_ms real, p_test boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    today date := (now() at time zone 'utc')::date;
    took integer;
begin
    if p_tool is null or p_tool !~ '^[a-z0-9_:/#.-]{1,60}$' then
        return false;
    end if;
    insert into public.insights_day_rows as d (day, rows) values (today, 1)
    on conflict (day) do update set rows = d.rows + 1
    returning rows into took;
    if took > (public.insights_caps()->>'day')::integer then
        return false;
    end if;
    insert into public.insights_events (visit, test, account, surface, kind, name, ms, ok)
    values (null, coalesce(p_test, false), case when p_account ~ '^[a-z0-9]{24}$' then p_account end, 'mcp', 'call',
            p_tool, case when p_ms between 0 and 86400000 then p_ms end, p_ok);
    return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- The daily rollup.

-- [p_plans] {hash: plan} as the server knows each account's plan now
-- (free, tester, pro); a hash not in it is free, no hash is 'none'.

-- A day's counts from its raw rows, as insights_days keeps them. Pure: the
-- rollup keeps what this gives, and the console reads today through it.
create or replace function public.insights_agg(p_day date, p_plans jsonb default '{}'::jsonb)
returns setof public.insights_days
language sql
stable
security definer
set search_path = ''
as $$
    with ev as (
        select e.*, coalesce(e.account, v.account) as who, v.device, v.lang, v.browser, v.channel, v.source,
               v.campaign, v.first_at, v.seconds, v.day as visit_day, v.last_act
          from public.insights_events e
          left join public.insights_visits v on v.visit = e.visit
         where e.day = p_day
    ), dims as (
        select ev.*,
               coalesce(ev.device, '') as d_device, coalesce(ev.lang, '') as d_lang, ev.who is not null as d_signed,
               case when ev.who is null then 'none' else coalesce(p_plans->>ev.who, 'free') end as d_plan,
               case when ev.kind in ('load', 'frames') then coalesce(ev.browser, '') else '' end as d_browser
          from ev
    ), counted as (
        select p_day as day, test, surface, kind, name, d_device as device, d_lang as lang, d_signed as signed_in,
               d_plan as plan, d_browser as browser, '' as channel,
               count(distinct visit)::integer as visits,
               count(distinct coalesce(who, visit))::integer as people,
               sum(n)::bigint as n,
               count(*) filter (where ok is true)::integer as ok,
               count(*) filter (where ok is false)::integer as failed,
               count(ms)::integer as timed,
               coalesce(sum(ms), 0)::double precision as ms_sum,
               (percentile_cont(0.5) within group (order by ms))::real as ms_p50,
               (percentile_cont(0.75) within group (order by ms))::real as ms_p75,
               (percentile_cont(0.95) within group (order by ms))::real as ms_p95
          from dims
         group by test, surface, kind, name, d_device, d_lang, d_signed, d_plan, d_browser
    ), visits as (
        -- Each visit active this day, once: where it came from, and how far it got.
        select dims.visit, bool_or(dims.test) as test, max(dims.who) as who, max(dims.d_device) as device,
               max(dims.d_lang) as lang, max(dims.d_plan) as plan, max(dims.channel) as channel,
               coalesce(max(dims.source), '(none)') as source, max(dims.campaign) as campaign,
               bool_or(dims.surface = 'studio') as studio, bool_or(dims.kind = 'part') as part,
               bool_or(dims.kind = 'save') as save, max(dims.last_act) as last_act,
               max(case when dims.visit_day = p_day then dims.seconds else 0 end) as seconds
          from dims
         where dims.visit is not null
         group by dims.visit
    ), reached as (
        select v.*, r.step
          from visits v
          cross join lateral (values ('visit', true), ('studio', v.studio), ('part', v.part), ('save', v.save),
                                     ('signed_in', v.who is not null)) as r(step, got)
         where r.got
    )
    select * from counted
    union all
    select p_day, test, 'site', 'visit', source, device, lang, who is not null, plan, '', channel,
           count(*)::integer, count(distinct coalesce(who, visit))::integer, count(*)::bigint, 0, 0,
           count(*)::integer, (sum(seconds) * 1000)::double precision, null, null, null
      from visits
     group by test, source, device, lang, who is not null, plan, channel
    union all
    select p_day, test, 'site', 'campaign', campaign, device, lang, who is not null, plan, '', channel,
           count(*)::integer, count(distinct coalesce(who, visit))::integer, count(*)::bigint, 0, 0, 0, 0, null, null, null
      from visits
     where campaign is not null
     group by test, campaign, device, lang, who is not null, plan, channel
    union all
    select p_day, test, 'site', 'reach', step, device, lang, who is not null, plan, '', '',
           count(*)::integer, count(distinct coalesce(who, visit))::integer, count(*)::bigint, 0, 0, 0, 0, null, null, null
      from reached
     group by test, step, device, lang, who is not null, plan
    union all
    -- Where visits stopped: each one's last act, by where it was.
    select p_day, test, case when studio then 'studio' else 'site' end, 'leave', last_act, device, lang, who is not null, plan,
           '', '', count(*)::integer, count(distinct coalesce(who, visit))::integer, count(*)::bigint, 0, 0, 0, 0, null, null, null
      from visits
     where last_act is not null
     group by test, studio, last_act, device, lang, who is not null, plan
$$;

-- A day rolled up: its counts kept (again, if it was), its accounts' days
-- and firsts kept, and the day marked. Returns the rows kept.
create or replace function public.insights_rollup(p_day date, p_plans jsonb default '{}'::jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    made integer;
begin
    if p_day >= (now() at time zone 'utc')::date then
        raise exception 'only a day that is over is rolled up';
    end if;
    delete from public.insights_days where day = p_day;
    insert into public.insights_days select * from public.insights_agg(p_day, coalesce(p_plans, '{}'::jsonb));
    get diagnostics made = row_count;

    insert into public.insights_account_days as d (account, day, test, built, studio)
    select coalesce(e.account, v.account), p_day, bool_or(e.test), bool_or(e.kind in ('part', 'save')),
           bool_or(e.surface = 'studio')
      from public.insights_events e
      left join public.insights_visits v on v.visit = e.visit
     where e.day = p_day and coalesce(e.account, v.account) is not null
     group by coalesce(e.account, v.account)
    on conflict (account, day) do update
       set built = d.built or excluded.built, studio = d.studio or excluded.studio;

    insert into public.insights_account_firsts as f (account, test, first_seen_at, first_part_at, first_save_at, channel,
            source, campaign)
    select w.who, w.test, w.seen, w.part, w.save, w.channel, w.source, w.campaign
      from (
        select coalesce(e.account, v.account) as who, bool_or(e.test) as test, min(coalesce(v.first_at, e.at)) as seen,
               min(e.at) filter (where e.kind = 'part') as part, min(e.at) filter (where e.kind = 'save') as save,
               (array_agg(v.channel order by v.first_at) filter (where v.visit is not null))[1] as channel,
               (array_agg(v.source order by v.first_at) filter (where v.visit is not null))[1] as source,
               (array_agg(v.campaign order by v.first_at) filter (where v.visit is not null))[1] as campaign
          from public.insights_events e
          left join public.insights_visits v on v.visit = e.visit
         where e.day = p_day and coalesce(e.account, v.account) is not null
         group by coalesce(e.account, v.account)
      ) w
    on conflict (account) do update
       set first_part_at = least(f.first_part_at, excluded.first_part_at),
           first_save_at = least(f.first_save_at, excluded.first_save_at),
           channel = case when excluded.first_seen_at < f.first_seen_at then excluded.channel else f.channel end,
           source = case when excluded.first_seen_at < f.first_seen_at then excluded.source else f.source end,
           campaign = case when excluded.first_seen_at < f.first_seen_at then excluded.campaign else f.campaign end,
           first_seen_at = least(f.first_seen_at, excluded.first_seen_at);

    insert into public.insights_rollups as r (day, rolled_at, rows) values (p_day, now(), made)
    on conflict (day) do update set rolled_at = excluded.rolled_at, rows = excluded.rows;
    return made;
end;
$$;

-- Raw rows past 30 days, and visits past 31, deleted; and the day counter's
-- old days. The rollups, the accounts' days and firsts stay. Returns what went.
create or replace function public.insights_forget()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    events integer;
    visits integer;
begin
    delete from public.insights_events where day < (now() at time zone 'utc')::date - 30;
    get diagnostics events = row_count;
    delete from public.insights_visits where last_at < now() - interval '31 days';
    get diagnostics visits = row_count;
    delete from public.insights_day_rows where day < (now() at time zone 'utc')::date - 30;
    return jsonb_build_object('events', events, 'visits', visits);
end;
$$;

-- The cron's day (api/_analytics.js tallyDaily): every day that is over and
-- not rolled up, then rows past their time forgotten, then what deleted
-- accounts left. [p_plans] is every account there is, by its hash: a hash
-- kept that is not in it is an account deleted, and its days, its firsts
-- and its hash on any row go. Not when the list looks short (a fifth of the
-- hashes kept, and more than five, gone at once): that is a listing that
-- failed, not deletions, and it waits for the next day's.
create or replace function public.insights_daily(p_plans jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    d date;
    rolled jsonb := '[]'::jsonb;
    made integer;
    plans jsonb := case when jsonb_typeof(p_plans) = 'object' then p_plans else '{}'::jsonb end;
    known integer;
    gone integer := 0;
begin
    for d in select * from public.insights_unrolled((now() at time zone 'utc')::date - 30) loop
        made := public.insights_rollup(d, plans);
        rolled := rolled || jsonb_build_object('day', d, 'rows', made);
    end loop;
    create temp table if not exists insights_gone (account text primary key) on commit drop;
    truncate pg_temp.insights_gone;
    insert into pg_temp.insights_gone
    select k.account from (select account from public.insights_account_firsts
                           union select account from public.insights_account_days
                           union select account from public.insights_visits where account is not null) k
     where not (plans ? k.account);
    select count(*) into gone from pg_temp.insights_gone;
    select count(*) into known from (select account from public.insights_account_firsts
                                     union select account from public.insights_account_days) k;
    if plans <> '{}'::jsonb and gone > 0 and (gone <= 5 or gone * 5 <= known) then
        delete from public.insights_account_days a using pg_temp.insights_gone g where a.account = g.account;
        delete from public.insights_account_firsts a using pg_temp.insights_gone g where a.account = g.account;
        update public.insights_visits v set account = null from pg_temp.insights_gone g where v.account = g.account;
        update public.insights_events e set account = null from pg_temp.insights_gone g where e.account = g.account;
    else
        gone := -gone;
    end if;
    return jsonb_build_object('rolled', rolled, 'forgot', public.insights_forget(), 'accounts_gone', gone);
end;
$$;

-- The days from [p_from] to yesterday, back as far as rows are kept, that
-- are not rolled up yet, oldest first.
create or replace function public.insights_unrolled(p_from date)
returns setof date
language sql
stable
security definer
set search_path = ''
as $$
    select d::date
      from generate_series(greatest(p_from, (now() at time zone 'utc')::date - 30),
                           (now() at time zone 'utc')::date - 1, interval '1 day') as d
     where not exists (select 1 from public.insights_rollups r where r.day = d::date)
       and exists (select 1 from public.insights_events e where e.day = d::date)
     order by 1
$$;

-- ---------------------------------------------------------------------------
-- The console's read (GET /api/admin?op=analytics).

-- [p_filters] {device, lang, plan, signed} (each optional); [p_accounts]
-- [{h, id, joined, plan}] every account of the kind asked (the checks' own
-- for [p_tests]), the hash made by the server. Days rolled up are read from
-- the rollup; today, and any day the cron has not rolled up yet, from their
-- rows through insights_agg. It writes nothing.
create or replace function public.insights_read(p_from date, p_to date, p_tests boolean, p_filters jsonb,
    p_accounts jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    today date := (now() at time zone 'utc')::date;
    f jsonb := coalesce(p_filters, '{}'::jsonb);
    plans jsonb;
    d date;
    pending date[];
    out jsonb := '{}'::jsonb;
begin
    if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 400 then
        raise exception 'a range of at most 400 days';
    end if;
    select coalesce(jsonb_object_agg(a->>'h', coalesce(a->>'plan', 'free')), '{}'::jsonb) into plans
      from jsonb_array_elements(coalesce(p_accounts, '[]'::jsonb)) a
     where a->>'h' ~ '^[a-z0-9]{24}$';
    pending := array(select * from public.insights_unrolled(today - 30)) || today;

    create temp table if not exists insights_r (like public.insights_days) on commit drop;
    truncate pg_temp.insights_r;
    insert into pg_temp.insights_r
    select * from public.insights_days
     where day between p_from and p_to and test = p_tests and not (day = any(pending));
    for d in select x from unnest(pending) x where x between p_from and p_to loop
        insert into pg_temp.insights_r select * from public.insights_agg(d, plans) where test = p_tests;
    end loop;
    -- The filters, on what each row knows: a relayed call has no device or language.
    delete from pg_temp.insights_r r
     where (f->>'device' is not null and r.device <> f->>'device')
        or (f->>'lang' is not null and r.lang <> f->>'lang')
        or (f->>'plan' = '!owner' and r.plan = 'owner')
        or (f->>'plan' is not null and f->>'plan' <> '!owner' and r.plan <> f->>'plan')
        or (f->>'signed' is not null and r.signed_in <> (f->>'signed')::boolean);

    create temp table if not exists insights_a (h text, id uuid, joined timestamptz, plan text) on commit drop;
    truncate pg_temp.insights_a;
    insert into pg_temp.insights_a
    select a->>'h', (a->>'id')::uuid, (a->>'joined')::timestamptz, coalesce(a->>'plan', 'free')
      from jsonb_array_elements(coalesce(p_accounts, '[]'::jsonb)) a
     where a->>'h' ~ '^[a-z0-9]{24}$' and a->>'id' ~ '^[0-9a-f-]{36}$'
       and (f->>'plan' is null or (f->>'plan' = '!owner' and coalesce(a->>'plan', 'free') <> 'owner')
            or coalesce(a->>'plan', 'free') = f->>'plan')
       and (f->>'signed' is null or (f->>'signed')::boolean);

    -- Each account's firsts: kept, and those of days not rolled up from their rows.
    create temp table if not exists insights_f (account text, part timestamptz, save timestamptz, channel text,
        source text, campaign text) on commit drop;
    truncate pg_temp.insights_f;
    insert into pg_temp.insights_f
    select coalesce(k.account, t.who), least(k.first_part_at, t.part), least(k.first_save_at, t.save),
           coalesce(k.channel, t.channel), coalesce(k.source, t.source), coalesce(k.campaign, t.campaign)
      from (select * from public.insights_account_firsts where test = p_tests) k
      full join (
        select coalesce(e.account, v.account) as who, min(e.at) filter (where e.kind = 'part') as part,
               min(e.at) filter (where e.kind = 'save') as save,
               (array_agg(v.channel order by v.first_at) filter (where v.visit is not null))[1] as channel,
               (array_agg(v.source order by v.first_at) filter (where v.visit is not null))[1] as source,
               (array_agg(v.campaign order by v.first_at) filter (where v.visit is not null))[1] as campaign
          from public.insights_events e left join public.insights_visits v on v.visit = e.visit
         where e.day = any(pending) and e.test = p_tests and coalesce(e.account, v.account) is not null
         group by 1
      ) t on t.who = k.account;

    out := out || jsonb_build_object('range', jsonb_build_object('from', p_from, 'to', p_to,
        'rolled', (select max(day) from public.insights_rollups), 'kept_from', today - 30));

    -- Overview: by day.
    out := out || jsonb_build_object('days', (
        select coalesce(jsonb_agg(jsonb_build_object('day', g.day, 'visits', coalesce(v.visits, 0),
                   'visitors', coalesce(v.people, 0), 'builders', coalesce(b.people, 0),
                   'signups', coalesce(s.n, 0), 'published', coalesce(p.n, 0), 'calls', coalesce(c.n, 0))
                   order by g.day), '[]'::jsonb)
          from (select x::date as day from generate_series(p_from, p_to, interval '1 day') x) g
          left join (select day, sum(visits) as visits, sum(people) as people from pg_temp.insights_r
                      where kind = 'reach' and name = 'visit' group by day) v on v.day = g.day
          left join (select day, sum(people) as people from pg_temp.insights_r
                      where kind = 'reach' and name = 'part' group by day) b on b.day = g.day
          left join (select (joined at time zone 'utc')::date as day, count(*) as n from pg_temp.insights_a group by 1) s
                 on s.day = g.day
          left join (select day, sum(n) as n from pg_temp.insights_r where kind = 'call' group by day) c on c.day = g.day
          left join lateral (
            select count(*) as n from public.shared_models m join pg_temp.insights_a a on a.id = m.owner
             where m.published and (m.created_at at time zone 'utc')::date = g.day
          ) p on true));

    -- Funnels: by account (sign-ups of the range, and what each has done
    -- since), and by visit (how far each visit got).
    out := out || jsonb_build_object('funnel', jsonb_build_object(
        'visits', (select coalesce(sum(visits), 0) from pg_temp.insights_r where kind = 'reach' and name = 'visit'),
        'signups', (select count(*) from pg_temp.insights_a where (joined at time zone 'utc')::date between p_from and p_to),
        'first_part', (select count(*) from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                        where (a.joined at time zone 'utc')::date between p_from and p_to and f.part is not null),
        'first_save', (select count(*) from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                        where (a.joined at time zone 'utc')::date between p_from and p_to and f.save is not null),
        'published', (select count(*) from pg_temp.insights_a a
                       where (a.joined at time zone 'utc')::date between p_from and p_to
                         and exists (select 1 from public.shared_models m where m.owner = a.id and m.published)),
        'reach', (select coalesce(jsonb_object_agg(name, visits), '{}'::jsonb)
                    from (select name, sum(visits) as visits from pg_temp.insights_r where kind = 'reach' group by name) x)));

    -- Retention: each week's sign-ups, and how many were back in each week since.
    out := out || jsonb_build_object('retention', (
        select coalesce(jsonb_agg(jsonb_build_object('week', c.week, 'size', c.size, 'back', c.back) order by c.week), '[]'::jsonb)
          from (
            select w.week, count(*) as size,
                   (select jsonb_agg(coalesce(k.n, 0) order by span.at)
                      from (select generate_series(0, ((today - w.week) / 7)::integer) as at) span
                      left join lateral (
                        select count(*) as n from pg_temp.insights_a a2
                         where date_trunc('week', a2.joined at time zone 'utc')::date = w.week
                           and (exists (select 1 from public.insights_account_days ad
                                         where ad.account = a2.h and ad.test = p_tests
                                           and ad.day >= w.week + 7 * span.at and ad.day < w.week + 7 * (span.at + 1))
                                or exists (select 1 from public.insights_events e
                                            left join public.insights_visits v on v.visit = e.visit
                                            where e.day = any(pending) and e.test = p_tests
                                              and coalesce(e.account, v.account) = a2.h
                                              and e.day >= w.week + 7 * span.at and e.day < w.week + 7 * (span.at + 1))
                                or (exists (select 1 from public.relay_call_days rc
                                                       where rc.owner = a2.id and rc.day >= w.week + 7 * span.at
                                                         and rc.day < w.week + 7 * (span.at + 1))))
                      ) k on true) as back
              from (select date_trunc('week', joined at time zone 'utc')::date as week from pg_temp.insights_a
                     where (joined at time zone 'utc')::date between date_trunc('week', p_from)::date and p_to) w
             group by w.week
          ) c));

    -- What was used, ranked: each kind by name.
    out := out || jsonb_build_object('used', (
        select coalesce(jsonb_agg(jsonb_build_object('surface', surface, 'kind', kind, 'name', name, 'visits', visits,
                   'people', people, 'n', n, 'ok', ok, 'failed', failed, 'timed', timed, 'ms_sum', round(ms_sum::numeric),
                   'p50', p50, 'p75', p75, 'p95', p95, 'first', first, 'last', last) order by kind, n desc, name), '[]'::jsonb)
          from (
            select surface, kind, name, sum(visits) as visits, sum(people) as people, sum(n) as n, sum(ok) as ok,
                   sum(failed) as failed, sum(timed) as timed, sum(ms_sum) as ms_sum,
                   round((sum(ms_p50 * timed) / nullif(sum(timed) filter (where ms_p50 is not null), 0))::numeric, 1) as p50,
                   round((sum(ms_p75 * timed) / nullif(sum(timed) filter (where ms_p75 is not null), 0))::numeric, 1) as p75,
                   round((sum(ms_p95 * timed) / nullif(sum(timed) filter (where ms_p95 is not null), 0))::numeric, 1) as p95,
                   min(day) as first, max(day) as last
              from pg_temp.insights_r
             where kind not in ('visit', 'campaign', 'reach', 'load', 'frames')
             group by surface, kind, name
          ) x));

    -- Speed: load times and frame rates by device and browser.
    out := out || jsonb_build_object('speed', (
        select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'name', name, 'device', device, 'browser', browser,
                   'n', timed, 'p50', p50, 'p75', p75, 'p95', p95) order by kind, name, device, browser), '[]'::jsonb)
          from (
            select kind, name, device, browser, sum(timed) as timed,
                   round((sum(ms_p50 * timed) / nullif(sum(timed), 0))::numeric, 1) as p50,
                   round((sum(ms_p75 * timed) / nullif(sum(timed), 0))::numeric, 1) as p75,
                   round((sum(ms_p95 * timed) / nullif(sum(timed), 0))::numeric, 1) as p95
              from pg_temp.insights_r
             where kind in ('load', 'frames') and timed > 0
             group by kind, name, device, browser
          ) x));

    -- Sources: channels, sources and campaigns, with the sign-ups each brought.
    out := out || jsonb_build_object('sources', jsonb_build_object(
        'channels', (select coalesce(jsonb_agg(jsonb_build_object('channel', c.channel, 'visits', c.visits, 'people', c.people,
                         'signups', coalesce(s.n, 0)) order by c.visits desc), '[]'::jsonb)
                       from (select channel, sum(visits) as visits, sum(people) as people from pg_temp.insights_r
                              where kind = 'visit' group by channel) c
                       left join (select f.channel, count(*) as n from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                                   where (a.joined at time zone 'utc')::date between p_from and p_to group by f.channel) s
                              on s.channel = c.channel),
        'sources', (select coalesce(jsonb_agg(jsonb_build_object('source', c.name, 'channel', c.channel, 'visits', c.visits,
                        'seconds', round(c.seconds), 'signups', coalesce(s.n, 0)) order by c.visits desc), '[]'::jsonb)
                      from (select name, channel, sum(visits) as visits, sum(ms_sum) / 1000 / nullif(sum(visits), 0) as seconds
                              from pg_temp.insights_r where kind = 'visit' group by name, channel order by 3 desc limit 100) c
                      left join (select f.source, count(*) as n from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                                  where (a.joined at time zone 'utc')::date between p_from and p_to group by f.source) s
                             on s.source = c.name),
        'campaigns', (select coalesce(jsonb_agg(jsonb_build_object('campaign', c.name, 'visits', c.visits,
                          'signups', coalesce(s.n, 0), 'post', p.post) order by c.visits desc), '[]'::jsonb)
                        from (select name, sum(visits) as visits from pg_temp.insights_r where kind = 'campaign'
                               group by name order by 2 desc limit 100) c
                        left join (select f.campaign, count(*) as n from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                                    where (a.joined at time zone 'utc')::date between p_from and p_to group by f.campaign) s
                               on s.campaign = c.name
                        left join lateral (
                          select jsonb_build_object('provider', ss.provider, 'community', ss.community, 'kind', ss.kind,
                                     'title', ss.title, 'sent_at', ss.sent_at) as post
                            from public.social_sends ss
                           where c.name ~ '^bw-[a-z0-9]{10}$' and ss.id = substr(c.name, 4)
                        ) p on true)));
    out := out || jsonb_build_object('seen', (
        select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'first', s.first_day, 'last', s.last_day,
                   'visits', s.visits) order by s.name), '[]'::jsonb)
          from public.insights_seen s
         where s.test = p_tests and s.last_day >= p_from));
    return out;
end;
$$;

revoke all on function public.insights_caps() from public, anon, authenticated;
revoke all on function public.insights_take(text, jsonb, jsonb, jsonb, text, integer, boolean) from public, anon, authenticated;
revoke all on function public.insights_call(text, text, boolean, real, boolean) from public, anon, authenticated;
revoke all on function public.insights_agg(date, jsonb) from public, anon, authenticated;
revoke all on function public.insights_rollup(date, jsonb) from public, anon, authenticated;
revoke all on function public.insights_forget() from public, anon, authenticated;
revoke all on function public.insights_daily(jsonb) from public, anon, authenticated;
revoke all on function public.insights_unrolled(date) from public, anon, authenticated;
revoke all on function public.insights_read(date, date, boolean, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.insights_take(text, jsonb, jsonb, jsonb, text, integer, boolean) to service_role;
grant execute on function public.insights_call(text, text, boolean, real, boolean) to service_role;
grant execute on function public.insights_rollup(date, jsonb) to service_role;
grant execute on function public.insights_forget() to service_role;
grant execute on function public.insights_daily(jsonb) to service_role;
grant execute on function public.insights_read(date, date, boolean, jsonb, jsonb) to service_role;
