-- The review's fixes to first-party analytics (infix, 2026-11-18;
-- bench/results/inreview-2026-11-18/report.md, docs/ANALYTICS.md), after
-- supabase/analytics.sql. Additive: new tables and columns, and
-- analytics.sql's own functions replaced. No live deployment wrote a row
-- before this, so every row kept so far is a preview's or a check's.
--
--   H2  insights_seen counts against the day's cap, and every list in the
--       owner's read is bounded (top N by count), so a flooded day cannot
--       make the read more than about 150 KB.
--   H3  the cron's deletion of a deleted account's rows is guarded only
--       against a listing that failed (the account listing much shorter
--       than the last one), never by how many hashes are kept; and an
--       account deleted is forgotten at once (insights_forget_account).
--   M3  past a soft budget a new visit is taken one in SAMPLE, recorded
--       with its weight, so the day goes on being counted; visits turned
--       away past the cap are counted; tool calls have a budget of their
--       own.
--   M7  the rollup keeps each count also over every device and language
--       ('*'), so a person on a phone and a desktop in one day is one
--       visitor, and the read takes the rows its filters ask for.
--   L5  the cron rolls up one day a call (api/_analytics.js).
--
-- Applied with tools/apply_sql.mjs after analytics.sql (a dry run first:
-- tools/analytics2_try.sql).

-- Once, the first time this file runs (insights_listings not yet made):
-- every row so far is a preview's or a check's, since none came from
-- brickworks.diy, and the rollup is made again from the raw rows, with the
-- '*' rows this file adds. Applied again, this file keeps every row.
do $$
begin
  if to_regclass('public.insights_listings') is null then
    delete from public.insights_seen s
     where not s.test and exists (select 1 from public.insights_seen t where t.surface = s.surface and t.name = s.name and t.test);
    update public.insights_seen set test = true where not test;
    update public.insights_visits set test = true where not test;
    update public.insights_events set test = true where not test;
    update public.insights_account_days set test = true where not test;
    update public.insights_account_firsts set test = true where not test;
    delete from public.insights_days;
    delete from public.insights_rollups;
  end if;
end $$;

alter table public.insights_visits add column if not exists weight smallint not null default 1;
alter table public.insights_day_rows add column if not exists turned_away integer not null default 0;
alter table public.insights_day_rows add column if not exists sampled integer not null default 0;

-- Tool calls counted a day, on their own budget (insights_caps 'calls').
create table if not exists public.insights_day_calls (
    day  date    primary key,
    rows integer not null default 0
);
-- How many accounts the cron listed each day: a listing much shorter than
-- the last one is one that failed, and deletes nothing.
create table if not exists public.insights_listings (
    day      date    primary key,
    accounts integer not null
);
alter table public.insights_day_calls enable row level security;
alter table public.insights_listings enable row level security;
revoke all on public.insights_day_calls from public, anon, authenticated, service_role;
revoke all on public.insights_listings from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Taking a visit's counts.

-- The most rows a day may take, whoever sends them, and a visit; past
-- 'soft', a new visit is taken one in 'sample'; tool calls up to 'calls'.
create or replace function public.insights_caps()
returns jsonb
language sql
immutable
set search_path = ''
as $$ select '{"day": 200000, "soft": 150000, "sample": 8, "visit": 1500, "batch": 80, "seen": 400, "calls": 50000}'::jsonb $$;

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
    rows_now integer;
    had integer;
    fresh boolean;
    known boolean;
    weight smallint := 1;
    room integer;
    taken integer := 0;
    shown integer := 0;
    a jsonb := coalesce(p_about, '{}'::jsonb);
begin
    if p_visit is null or p_visit !~ '^[a-z0-9]{16}$' then
        return 0;
    end if;
    if p_account is not null and p_account !~ '^[a-z0-9]{24}$' then
        p_account := null;
    end if;
    rows_now := coalesce((select d.rows from public.insights_day_rows d where d.day = today), 0);
    known := exists (select 1 from public.insights_visits v where v.visit = p_visit);
    if not known then
        -- Past the cap no new visit is taken, and it is counted as turned away.
        if rows_now >= (caps->>'day')::integer then
            insert into public.insights_day_rows as d (day, rows, turned_away) values (today, 0, 1)
            on conflict (day) do update set turned_away = d.turned_away + 1;
            return 0;
        end if;
        -- Past the soft budget, a visit nobody signed in to is taken one in
        -- SAMPLE (by its id), and kept with that weight: the day's counts
        -- go on, scaled, rather than stop.
        if rows_now >= (caps->>'soft')::integer and p_account is null then
            if get_byte(sha256(convert_to(p_visit, 'UTF8')), 0) % (caps->>'sample')::integer <> 0 then
                insert into public.insights_day_rows as d (day, rows, sampled) values (today, 0, 1)
                on conflict (day) do update set sampled = d.sampled + 1;
                return 0;
            end if;
            weight := (caps->>'sample')::smallint;
        end if;
    end if;
    insert into public.insights_visits as v (visit, test, account, landing, studio, channel, source, medium, campaign,
            device, browser, os, lang, last_act, seconds, beacons, weight)
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
            least(greatest(coalesce(p_seconds, 0), 0), 3600), 1, weight)
    on conflict (visit) do update
       set last_at = now(),
           account = coalesce(v.account, excluded.account),
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

    -- The studio's controls shown: a row a name, however many visits, each
    -- new one a row of the day's (inreview H2); none past the cap.
    select least((caps->>'day')::integer - d.rows, (caps->>'seen')::integer) into room
      from public.insights_day_rows d where d.day = today;
    if room > 0 and jsonb_typeof(p_seen) = 'array' then
        with given as (
            select distinct x from (select jsonb_array_elements_text(p_seen) as x limit (caps->>'seen')::integer) g
             where x ~ '^[a-z0-9_:/#.-]{1,60}$'
             limit room
        ), kept as (
            insert into public.insights_seen as s (surface, name, test)
            select 'studio', x, coalesce(p_test, false) from given
            on conflict (surface, name, test) do update
               set last_day = excluded.last_day, visits = s.visits + 1
            returning (s.xmax = 0) as made
        )
        select count(*) filter (where made) into shown from kept;
        if shown > 0 then
            update public.insights_day_rows set rows = rows + shown where day = today;
        end if;
    end if;
    return taken;
end;
$$;

-- A tool call the connector relayed: its name, whether it went, how long it
-- took. No account: the person's choice lives in their browser, which a
-- tool call does not come from. On a budget of its own.
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
    insert into public.insights_day_calls as d (day, rows) values (today, 1)
    on conflict (day) do update set rows = d.rows + 1
    returning rows into took;
    if took > (public.insights_caps()->>'calls')::integer then
        return false;
    end if;
    insert into public.insights_events (visit, test, account, surface, kind, name, ms, ok)
    values (null, coalesce(p_test, false), null, 'mcp', 'call', p_tool,
            case when p_ms between 0 and 86400000 then p_ms end, p_ok);
    return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- The daily rollup: each count by its dimensions, and again over every
-- device ('*'), every language ('*') and both, so a person counts once
-- whichever the read asks. A sampled visit (weight > 1) counts as that
-- many visits, and its counts that many times.
create or replace function public.insights_agg(p_day date, p_plans jsonb default '{}'::jsonb)
returns setof public.insights_days
language sql
stable
security definer
set search_path = ''
as $$
    with k as (
        select (public.insights_caps()->>'sample')::integer as k
    ), ev as (
        select e.*, coalesce(e.account, v.account) as who, v.device, v.lang, v.browser, v.channel, v.source,
               v.campaign, v.first_at, v.seconds, v.day as visit_day, v.last_act, coalesce(v.weight, 1)::integer as w
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
        select p_day as day, test, surface, kind, name,
               case when grouping(d_device) = 1 then '*' else d_device end as device,
               case when grouping(d_lang) = 1 then '*' else d_lang end as lang,
               d_signed as signed_in, d_plan as plan, d_browser as browser, '' as channel,
               (count(distinct visit) filter (where w = 1)
                + count(distinct visit) filter (where w > 1) * (select k from k))::integer as visits,
               (count(distinct coalesce(who, visit)) filter (where w = 1)
                + count(distinct coalesce(who, visit)) filter (where w > 1) * (select k from k))::integer as people,
               sum(n * w)::bigint as n,
               coalesce(sum(w) filter (where ok is true), 0)::integer as ok,
               coalesce(sum(w) filter (where ok is false), 0)::integer as failed,
               count(ms)::integer as timed,
               coalesce(sum(ms), 0)::double precision as ms_sum,
               (percentile_cont(0.5) within group (order by ms))::real as ms_p50,
               (percentile_cont(0.75) within group (order by ms))::real as ms_p75,
               (percentile_cont(0.95) within group (order by ms))::real as ms_p95
          from dims
         group by grouping sets ((test, surface, kind, name, d_signed, d_plan, d_browser, d_device, d_lang),
                                 (test, surface, kind, name, d_signed, d_plan, d_browser, d_device),
                                 (test, surface, kind, name, d_signed, d_plan, d_browser, d_lang),
                                 (test, surface, kind, name, d_signed, d_plan, d_browser))
    ), visits as (
        -- Each visit active this day, once: where it came from, and how far it got.
        select dims.visit, bool_or(dims.test) as test, max(dims.who) as who, max(dims.who) is not null as signed,
               max(dims.d_device) as device, max(dims.d_lang) as lang, max(dims.d_plan) as plan, max(dims.channel) as channel,
               coalesce(max(dims.source), '(none)') as source, max(dims.campaign) as campaign,
               bool_or(dims.surface = 'studio') as studio, bool_or(dims.kind = 'part') as part,
               bool_or(dims.kind = 'save') as save, max(dims.last_act) as last_act, max(dims.w) as w,
               max(case when dims.visit_day = p_day then dims.seconds else 0 end) as seconds
          from dims
         where dims.visit is not null
         group by dims.visit
    ), reached as (
        select v.*, r.step
          from visits v
          cross join lateral (values ('visit', true), ('studio', v.studio), ('part', v.part), ('save', v.save),
                                     ('signed_in', v.signed)) as r(step, got)
         where r.got
    )
    select * from counted
    union all
    select p_day, test, 'site', 'visit', source, case when grouping(device) = 1 then '*' else device end,
           case when grouping(lang) = 1 then '*' else lang end, signed, plan, '', channel,
           sum(w)::integer, (count(distinct who) + coalesce(sum(w) filter (where who is null), 0))::integer, sum(w)::bigint, 0, 0,
           count(*)::integer, (sum(seconds * w) * 1000)::double precision, null, null, null
      from visits
     group by grouping sets ((test, source, signed, plan, channel, device, lang), (test, source, signed, plan, channel, device),
                             (test, source, signed, plan, channel, lang), (test, source, signed, plan, channel))
    union all
    select p_day, test, 'site', 'campaign', campaign, case when grouping(device) = 1 then '*' else device end,
           case when grouping(lang) = 1 then '*' else lang end, signed, plan, '', channel,
           sum(w)::integer, (count(distinct who) + coalesce(sum(w) filter (where who is null), 0))::integer, sum(w)::bigint, 0, 0,
           0, 0, null, null, null
      from visits
     where campaign is not null
     group by grouping sets ((test, campaign, signed, plan, channel, device, lang), (test, campaign, signed, plan, channel, device),
                             (test, campaign, signed, plan, channel, lang), (test, campaign, signed, plan, channel))
    union all
    select p_day, test, 'site', 'reach', step, case when grouping(device) = 1 then '*' else device end,
           case when grouping(lang) = 1 then '*' else lang end, signed, plan, '', '',
           sum(w)::integer, (count(distinct who) + coalesce(sum(w) filter (where who is null), 0))::integer, sum(w)::bigint, 0, 0,
           0, 0, null, null, null
      from reached
     group by grouping sets ((test, step, signed, plan, device, lang), (test, step, signed, plan, device),
                             (test, step, signed, plan, lang), (test, step, signed, plan))
    union all
    -- Where visits stopped: each one's last act, by where it was.
    select p_day, test, case when studio then 'studio' else 'site' end, 'leave', last_act,
           case when grouping(device) = 1 then '*' else device end, case when grouping(lang) = 1 then '*' else lang end,
           signed, plan, '', '', sum(w)::integer, (count(distinct who) + coalesce(sum(w) filter (where who is null), 0))::integer,
           sum(w)::bigint, 0, 0, 0, 0, null, null, null
      from visits
     where last_act is not null
     group by grouping sets ((test, studio, last_act, signed, plan, device, lang), (test, studio, last_act, signed, plan, device),
                             (test, studio, last_act, signed, plan, lang), (test, studio, last_act, signed, plan))
$$;

-- An account deleted (api/_erase.js): its days and firsts gone, and its
-- hash taken off every visit and event, at once. Returns the rows it touched.
create or replace function public.insights_forget_account(p_account text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    touched integer := 0;
    more integer;
begin
    if p_account is null or p_account !~ '^[a-z0-9]{24}$' then
        return 0;
    end if;
    delete from public.insights_account_days where account = p_account;
    get diagnostics more = row_count;
    touched := touched + more;
    delete from public.insights_account_firsts where account = p_account;
    get diagnostics more = row_count;
    touched := touched + more;
    update public.insights_visits set account = null where account = p_account;
    get diagnostics more = row_count;
    touched := touched + more;
    update public.insights_events set account = null where account = p_account;
    get diagnostics more = row_count;
    return touched + more;
end;
$$;

-- What deleted accounts left, after the cron's rollups (api/_analytics.js
-- tallyDaily), then rows past their time forgotten. [p_plans] is every
-- account there is, by its hash, and [p_listed] how many the listing gave:
-- a hash kept that is not in it is an account deleted, and goes. Not when
-- the listing is much shorter than the last one that went through (the day
-- before's, or today's on a run again), by more than a fifth and more than
-- five: that is a listing that failed, not deletions, and it waits for the
-- next run. Kept hashes never hold it back, whoever
-- made them (inreview H3).
create or replace function public.insights_gone(p_plans jsonb, p_listed integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    today date := (now() at time zone 'utc')::date;
    plans jsonb := case when jsonb_typeof(p_plans) = 'object' then p_plans else '{}'::jsonb end;
    before integer;
    gone integer := 0;
    failed boolean;
begin
    -- The last listing that went through (today's, when the cron runs again).
    select l.accounts into before from public.insights_listings l order by l.day desc limit 1;
    failed := p_listed is null or p_listed <= 0
              or (before is not null and before - p_listed > 5 and (before - p_listed) * 5 > before);
    if not failed then
        create temp table if not exists insights_gone_now (account text primary key) on commit drop;
        truncate pg_temp.insights_gone_now;
        insert into pg_temp.insights_gone_now
        select k.account from (select account from public.insights_account_firsts
                               union select account from public.insights_account_days
                               union select account from public.insights_visits where account is not null
                               union select account from public.insights_events where account is not null) k
         where not (plans ? k.account);
        select count(*) into gone from pg_temp.insights_gone_now;
        delete from public.insights_account_days a using pg_temp.insights_gone_now g where a.account = g.account;
        delete from public.insights_account_firsts a using pg_temp.insights_gone_now g where a.account = g.account;
        update public.insights_visits v set account = null from pg_temp.insights_gone_now g where v.account = g.account;
        update public.insights_events e set account = null from pg_temp.insights_gone_now g where e.account = g.account;
        insert into public.insights_listings as l (day, accounts) values (today, p_listed)
        on conflict (day) do update set accounts = excluded.accounts;
    end if;
    delete from public.insights_listings where day < today - 30;
    delete from public.insights_day_calls where day < today - 30;
    return jsonb_build_object('forgot', public.insights_forget(), 'accounts_gone', gone, 'listed', p_listed,
        'listed_before', before, 'listing_failed', failed);
end;
$$;

drop function if exists public.insights_daily(jsonb);

-- ---------------------------------------------------------------------------
-- The console's read: every list bounded (top N by count), so a flooded
-- day or made-up names cannot make it large (inreview H2); the rows its
-- device and language filters ask for, '*' for none.
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
    -- The most names of each kind the read gives, by count, and the most
    -- of the other lists.
    top integer := 25;
    tops integer := 50;
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
    -- The filters, on what each row knows: a relayed call has no device or
    -- language. Device and language as asked, or over all of them ('*');
    -- load and frame rows by each device as well, for Speed.
    delete from pg_temp.insights_r r
     where r.lang <> coalesce(f->>'lang', '*')
        or not (r.device = coalesce(f->>'device', '*')
                or (r.kind in ('load', 'frames') and r.device <> '*' and r.device = coalesce(f->>'device', r.device)))
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
        'rolled', (select max(day) from public.insights_rollups), 'kept_from', today - 30, 'top', top));

    -- Overview: by day; and each day's cap, sampling and visits turned away.
    out := out || jsonb_build_object('days', (
        select coalesce(jsonb_agg(jsonb_build_object('day', g.day, 'visits', coalesce(v.visits, 0),
                   'visitors', coalesce(v.people, 0), 'builders', coalesce(b.people, 0),
                   'signups', coalesce(s.n, 0), 'published', coalesce(p.n, 0), 'calls', coalesce(c.n, 0))
                   || case when coalesce(dr.sampled, 0) + coalesce(dr.turned_away, 0) > 0
                           then jsonb_build_object('sampled', dr.sampled, 'turned_away', dr.turned_away) else '{}'::jsonb end
                   order by g.day), '[]'::jsonb)
          from (select x::date as day from generate_series(p_from, p_to, interval '1 day') x) g
          left join (select day, sum(visits) as visits, sum(people) as people from pg_temp.insights_r
                      where kind = 'reach' and name = 'visit' group by day) v on v.day = g.day
          left join (select day, sum(people) as people from pg_temp.insights_r
                      where kind = 'reach' and name = 'part' group by day) b on b.day = g.day
          left join (select (joined at time zone 'utc')::date as day, count(*) as n from pg_temp.insights_a group by 1) s
                 on s.day = g.day
          left join (select day, sum(n) as n from pg_temp.insights_r where kind = 'call' group by day) c on c.day = g.day
          left join public.insights_day_rows dr on dr.day = g.day and not p_tests
          left join lateral (
            select count(*) as n from public.shared_models m join pg_temp.insights_a a on a.id = m.owner
             where m.published and (m.created_at at time zone 'utc')::date = g.day
          ) p on true));

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

    -- What was used, ranked: each kind's top names by count, and how many
    -- names it had in all.
    out := out || jsonb_build_object('used', (
        select coalesce(jsonb_agg(jsonb_build_object('surface', surface, 'kind', kind, 'name', name, 'visits', visits,
                   'people', people, 'n', n, 'ok', ok, 'failed', failed, 'timed', timed, 'ms_sum', round(ms_sum::numeric),
                   'p50', p50, 'p75', p75, 'p95', p95, 'first', first, 'last', last) order by kind, n desc, name), '[]'::jsonb)
          from (
            select x.*, row_number() over (partition by kind order by n desc, name) as place
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
              ) x
          ) y
         where place <= top));
    out := out || jsonb_build_object('names', (
        select coalesce(jsonb_object_agg(kind, names), '{}'::jsonb)
          from (select kind, count(distinct name) as names from pg_temp.insights_r
                 where kind not in ('visit', 'campaign', 'reach', 'load', 'frames') group by kind) x));

    -- Speed: load times and frame rates by device and browser, the most timed first.
    out := out || jsonb_build_object('speed', (
        select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'name', name, 'device', device, 'browser', browser,
                   'n', timed, 'p50', p50, 'p75', p75, 'p95', p95) order by kind, name, device, browser), '[]'::jsonb)
          from (
            select kind, name, device, browser, sum(timed) as timed,
                   round((sum(ms_p50 * timed) / nullif(sum(timed), 0))::numeric, 1) as p50,
                   round((sum(ms_p75 * timed) / nullif(sum(timed), 0))::numeric, 1) as p75,
                   round((sum(ms_p95 * timed) / nullif(sum(timed), 0))::numeric, 1) as p95
              from pg_temp.insights_r
             where kind in ('load', 'frames') and timed > 0 and device <> '*'
             group by kind, name, device, browser
             order by sum(timed) desc
             limit tops * 2
          ) x));

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
                              from pg_temp.insights_r where kind = 'visit' group by name, channel order by 3 desc limit tops) c
                      left join (select f.source, count(*) as n from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                                  where (a.joined at time zone 'utc')::date between p_from and p_to group by f.source) s
                             on s.source = c.name),
        'campaigns', (select coalesce(jsonb_agg(jsonb_build_object('campaign', c.name, 'visits', c.visits,
                          'signups', coalesce(s.n, 0), 'post', p.post) order by c.visits desc), '[]'::jsonb)
                        from (select name, sum(visits) as visits from pg_temp.insights_r where kind = 'campaign'
                               group by name order by 2 desc limit tops) c
                        left join (select f.campaign, count(*) as n from pg_temp.insights_a a join pg_temp.insights_f f on f.account = a.h
                                    where (a.joined at time zone 'utc')::date between p_from and p_to group by f.campaign) s
                               on s.campaign = c.name
                        left join lateral (
                          select jsonb_build_object('provider', ss.provider, 'community', ss.community, 'kind', ss.kind,
                                     'title', left(ss.title, 120), 'sent_at', ss.sent_at) as post
                            from public.social_sends ss
                           where c.name ~ '^bw-[a-z0-9]{10}$' and ss.id = substr(c.name, 4)
                        ) p on true)));
    -- The controls shown and never pressed in the range, the most shown
    -- first (a control pressed is in "used"), and how many in all.
    out := out || jsonb_build_object('seen', (
        select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'first', s.first_day, 'last', s.last_day,
                   'visits', s.visits) order by s.visits desc, s.name), '[]'::jsonb)
          from (select * from public.insights_seen s
                 where s.test = p_tests and s.last_day >= p_from
                   and not exists (select 1 from pg_temp.insights_r r where r.kind = 'press' and r.name = s.name)
                 order by s.visits desc, s.name limit tops * 2) s),
        'seen_names', (select count(*) from public.insights_seen s where s.test = p_tests and s.last_day >= p_from));
    return out;
end;
$$;

revoke all on function public.insights_caps() from public, anon, authenticated;
revoke all on function public.insights_take(text, jsonb, jsonb, jsonb, text, integer, boolean) from public, anon, authenticated;
revoke all on function public.insights_call(text, text, boolean, real, boolean) from public, anon, authenticated;
revoke all on function public.insights_agg(date, jsonb) from public, anon, authenticated;
revoke all on function public.insights_forget_account(text) from public, anon, authenticated;
revoke all on function public.insights_gone(jsonb, integer) from public, anon, authenticated;
revoke all on function public.insights_unrolled(date) from public, anon, authenticated;
revoke all on function public.insights_read(date, date, boolean, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.insights_take(text, jsonb, jsonb, jsonb, text, integer, boolean) to service_role;
grant execute on function public.insights_call(text, text, boolean, real, boolean) to service_role;
grant execute on function public.insights_forget_account(text) to service_role;
grant execute on function public.insights_gone(jsonb, integer) to service_role;
grant execute on function public.insights_unrolled(date) to service_role;
grant execute on function public.insights_read(date, date, boolean, jsonb, jsonb) to service_role;
