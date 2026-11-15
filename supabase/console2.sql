-- The owner's console, part B (console2, 2026-11-12; docs/ADMIN.md): what
-- /admin's Plans, Mail, Connector and Site sections read that nothing kept
-- before.
--
--   mail_events      every word Resend sends back about a mail Brickworks
--                    sent (its webhook, signed: api/_console_mail.js): sent,
--                    delivered, delayed, bounced, complained, failed. One
--                    row an event, kept once however often Resend retries
--                    it; the mail's id, its first address and its subject,
--                    what kind of mail it is (a sign-in code, the beta's, a
--                    feedback answer, a digest...), and a bounce's words.
--                    Only mail from brickworks.diy is kept: the webhook is
--                    the Resend team's, which other products share. Rows
--                    go after a year. A test's (a resend.dev address) is
--                    marked, and the console shows those only when asked.
--   site_releases    a row a release that went live, written by the release
--                    train as it ships (tools/release/release_live.sh): its
--                    tag, its commit, its title and units, and when it went
--                    live. No Vercel token on the site to ask Vercel's API.
--   relay_call_days  how many tool calls each account's Claude made through
--                    the connector, a row an account a day, with the last
--                    one's time and tool's name (never what was passed);
--                    and relay_picks.calls, the same for one conversation.
--                    api/mcp.js counts through relay_call_note.
--
-- And the functions the console reads them by: admin_mail (the mail of the
-- last days by kind and day, each mail with what Resend said of it, beside
-- what Brickworks kept as sent in beta_mail and feedback_replies),
-- site_release_live and site_releases_list, admission_customers (the
-- customers Admission has answered for, from its snapshots, for Plans),
-- and cron_noted (a cron that keeps no lock, the sweep and the beta's
-- daily round, written down as it ends, as the others are by cron_begin).
--
-- Only the server touches any of it (the secret key), through functions
-- that are security definer and granted to the service role alone. Row
-- security on the new tables, no policy; mail_events' and site_releases'
-- grants taken back from every role, the service role's too;
-- relay_call_days read by the server as the relay's tables are.
--
-- Only additions: three new tables, one new column on relay_picks (a count,
-- 0 for every row there), and new functions. Needs beta.sql, feedback.sql
-- (admin_mail), relay.sql (relay_picks), gallery_crons.sql (cron_runs) and
-- admission_snapshots.sql. Nothing that exists is changed or dropped.
-- Applying it again changes nothing.

create table if not exists public.mail_events (
    id          bigint      generated always as identity primary key,
    event_id    text        not null constraint mail_events_event_id check (event_id ~ '^[A-Za-z0-9_.:-]{1,120}$'),
    email_id    text        not null constraint mail_events_email_id check (email_id ~ '^[A-Za-z0-9_-]{1,100}$'),
    type        text        not null constraint mail_events_type check (type in ('sent', 'delivered', 'delivery_delayed',
                                'bounced', 'complained', 'failed', 'suppressed', 'opened', 'clicked', 'scheduled')),
    at          timestamptz not null,
    address     text        constraint mail_events_address check (char_length(address) <= 320),
    subject     text        constraint mail_events_subject check (char_length(subject) <= 300),
    kind        text        not null default 'other' constraint mail_events_kind check (kind ~ '^[a-z_]{1,40}$'),
    detail      text        constraint mail_events_detail check (char_length(detail) <= 500),
    test        boolean     not null default false,
    received_at timestamptz not null default now()
);
create unique index if not exists mail_events_once on public.mail_events (event_id);
create index if not exists mail_events_mail on public.mail_events (email_id, at);
create index if not exists mail_events_newest on public.mail_events (test, at desc);
create index if not exists mail_events_old on public.mail_events (received_at);

create table if not exists public.site_releases (
    tag      text        primary key constraint site_releases_tag check (tag ~ '^[a-z0-9][a-z0-9._-]{0,40}$'),
    sha      text        not null constraint site_releases_sha check (sha ~ '^[0-9a-f]{7,40}$'),
    title    text        constraint site_releases_title check (char_length(title) <= 2000),
    units    text[]      not null default '{}' constraint site_releases_units check (cardinality(units) <= 60),
    live_at  timestamptz not null,
    kept_at  timestamptz not null default now()
);
create index if not exists site_releases_newest on public.site_releases (live_at desc);

create table if not exists public.relay_call_days (
    owner     uuid        not null references auth.users (id) on delete cascade,
    day       date        not null,
    calls     integer     not null default 0 constraint relay_call_days_calls check (calls >= 0),
    last_at   timestamptz not null default now(),
    last_tool text        constraint relay_call_days_last_tool check (char_length(last_tool) <= 60),
    primary key (owner, day)
);
create index if not exists relay_call_days_day on public.relay_call_days (day);

-- One conversation's tool calls, beside its last (relay.sql's called_at, did).
alter table public.relay_picks add column if not exists calls integer not null default 0;

alter table public.mail_events enable row level security;
alter table public.site_releases enable row level security;
alter table public.relay_call_days enable row level security;
revoke all on public.mail_events from public, anon, authenticated, service_role;
revoke all on public.site_releases from public, anon, authenticated, service_role;
revoke all on public.relay_call_days from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Mail.

-- One event Resend sent about a mail, kept: true, or false when it was kept
-- already (Resend retries until it is answered). A year's are kept.
create or replace function public.mail_event_keep(p_event text, p_email text, p_type text, p_at timestamptz,
    p_address text, p_subject text, p_kind text, p_detail text, p_test boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    kept bigint;
begin
    delete from public.mail_events where received_at < now() - interval '365 days';
    insert into public.mail_events (event_id, email_id, type, at, address, subject, kind, detail, test)
    values (p_event, p_email, p_type, coalesce(p_at, now()), left(p_address, 320), left(p_subject, 300),
            coalesce(nullif(p_kind, ''), 'other'), left(p_detail, 500), coalesce(p_test, false))
    on conflict (event_id) do nothing
    returning id into kept;
    return kept is not null;
end;
$$;

-- The mail of the last [p_days] (1 to 365; 30 without), the checks' own for
-- [p_tests] and nobody else's:
--   mails   each mail Resend told of, newest first, at most [p_limit]: its
--           id, kind, address, subject, when it went, every state it was
--           in, and the last words of a bounce or a failure
--   by_day  a row a day and kind: sent, delivered, delayed, bounced,
--           complained, failed
--   kept    what Brickworks kept as sent itself (the beta's mail and the
--           feedback answers), newest first: sent with Resend's id, dry (a
--           test inbox on a deployment with no mail key) or failed
--   heard   when Resend last told of any mail at all, a test's too: null
--           while its webhook has never reached here
create or replace function public.admin_mail(p_days integer, p_tests boolean, p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    with span as (
        select greatest(1, least(coalesce(p_days, 30), 365)) as days
    ), since as (
        select now() - make_interval(days => span.days) as at from span
    ), ev as (
        select e.* from public.mail_events e, since where e.at >= since.at and e.test = coalesce(p_tests, false)
    ), mails as (
        select e.email_id,
               min(e.at) as first_at,
               max(e.at) as last_at,
               (array_agg(e.address order by e.at) filter (where e.address is not null))[1] as address,
               (array_agg(e.subject order by e.at) filter (where e.subject is not null))[1] as subject,
               coalesce((array_agg(e.kind order by e.at) filter (where e.kind <> 'other'))[1], 'other') as kind,
               array_agg(distinct e.type order by e.type) as states,
               (array_agg(e.detail order by e.at desc) filter (where e.detail is not null))[1] as detail
          from ev e
         group by e.email_id
    ), listed as (
        select * from mails order by first_at desc limit greatest(1, least(coalesce(p_limit, 300), 1000))
    ), days as (
        select to_char(date_trunc('day', e.at at time zone 'utc'), 'YYYY-MM-DD') as day, e.kind,
               count(*) filter (where e.type = 'sent') as sent,
               count(*) filter (where e.type = 'delivered') as delivered,
               count(*) filter (where e.type = 'delivery_delayed') as delayed,
               count(*) filter (where e.type = 'bounced') as bounced,
               count(*) filter (where e.type = 'complained') as complained,
               count(*) filter (where e.type in ('failed', 'suppressed')) as failed
          from ev e
         group by 1, 2
    ), kept as (
        select 'beta'::text as kind, m.kind as what, m.state, m.sent_id, m.subject, u.email as address, m.at
          from public.beta_mail m join auth.users u on u.id = m.account, since
         where m.at >= since.at and (lower(coalesce(u.email, '')) ~ '@resend\.dev$') = coalesce(p_tests, false)
        union all
        select 'feedback_answer', f.kind, r.mail, r.sent_id, null, coalesce(f.email, u.email), r.at
          from public.feedback_replies r
          join public.feedback f on f.id = r.feedback
          left join auth.users u on u.id = f.account, since
         where r.at >= since.at and f.test = coalesce(p_tests, false)
    )
    select jsonb_build_object(
        'days', (select days from span),
        'mails', coalesce((select jsonb_agg(jsonb_build_object('email_id', l.email_id, 'kind', l.kind,
                     'address', l.address, 'subject', l.subject, 'at', l.first_at, 'last_at', l.last_at,
                     'states', to_jsonb(l.states), 'detail', l.detail) order by l.first_at desc) from listed l), '[]'::jsonb),
        'more', (select count(*) from mails) > (select count(*) from listed),
        'by_day', coalesce((select jsonb_agg(to_jsonb(d) order by d.day desc, d.kind) from days d), '[]'::jsonb),
        'kept', coalesce((select jsonb_agg(to_jsonb(k) order by k.at desc)
                            from (select * from kept order by at desc limit 500) k), '[]'::jsonb),
        'heard', (select max(e.received_at) from public.mail_events e))
$$;

-- ---------------------------------------------------------------------------
-- Releases.

-- Release [p_tag] live at [p_live_at] (now without), from commit [p_sha]:
-- kept, or kept again (a release shipped again goes live again). The row.
create or replace function public.site_release_live(p_tag text, p_sha text, p_title text, p_units text[],
    p_live_at timestamptz)
returns jsonb
language sql
security definer
set search_path = ''
as $$
    insert into public.site_releases as r (tag, sha, title, units, live_at)
    values (lower(p_tag), lower(p_sha), left(p_title, 2000), coalesce(p_units[1:60], '{}'), coalesce(p_live_at, now()))
    on conflict (tag) do update
       set sha = excluded.sha, title = excluded.title, units = excluded.units, live_at = excluded.live_at,
           kept_at = now()
    returning jsonb_build_object('tag', r.tag, 'sha', r.sha, 'title', r.title, 'units', to_jsonb(r.units),
                                 'live_at', r.live_at)
$$;

-- The releases that went live, the latest first, at most [p_limit] (1 to 100).
create or replace function public.site_releases_list(p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('tag', r.tag, 'sha', r.sha, 'title', r.title,
               'units', to_jsonb(r.units), 'live_at', r.live_at) order by r.live_at desc), '[]'::jsonb)
      from (select * from public.site_releases order by live_at desc
             limit greatest(1, least(coalesce(p_limit, 20), 100))) r
$$;

-- ---------------------------------------------------------------------------
-- The connector's calls.

-- Conversation [p_key] (relay_picks.key) made a tool call to [p_did]: its
-- last call and its count, and its account's count for today (UTC). The
-- conversation's count, or null when it has no pick.
create or replace function public.relay_call_note(p_key text, p_did text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    who uuid;
    made integer;
begin
    update public.relay_picks
       set called_at = now(), did = left(p_did, 60), calls = calls + 1
     where key = p_key
    returning owner, calls into who, made;
    if who is not null then
        insert into public.relay_call_days as d (owner, day, calls, last_at, last_tool)
        values (who, (now() at time zone 'utc')::date, 1, now(), left(p_did, 60))
        on conflict (owner, day) do update
           set calls = d.calls + 1, last_at = excluded.last_at, last_tool = excluded.last_tool;
    end if;
    return made;
end;
$$;

-- ---------------------------------------------------------------------------
-- Crons and plans.

-- A cron that keeps no lock, written down as it ends: the run's number.
create or replace function public.cron_noted(job text, holder text, started_at timestamptz, outcome text,
    said jsonb default '{}'::jsonb)
returns bigint
language sql
security definer
set search_path = public
as $$
    insert into public.cron_runs (job, holder, started_at, finished_at, outcome, said)
    values (cron_noted.job, left(cron_noted.holder, 80), coalesce(cron_noted.started_at, now()), now(),
            cron_noted.outcome, coalesce(cron_noted.said, '{}'::jsonb))
    returning id
$$;

-- The customers Admission last answered for in [p_mode] (test or live), from
-- the client's snapshots (admission_snapshots.sql): the account, the answer
-- as kept, and when; the latest first, at most [p_limit] (1 to 2000).
create or replace function public.admission_customers(p_mode text, p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('customer', s.customer, 'value', s.value, 'at', s.updated_at)
               order by s.updated_at desc), '[]'::jsonb)
      from (select substr(a.key, char_length('admission:v2:brickworks:' || p_mode || ':c:') + 1) as customer,
                   a.value, a.updated_at
              from public.admission_snapshots a
             where p_mode in ('test', 'live')
               and a.key like 'admission:v2:brickworks:' || p_mode || ':c:%'
               and a.value <> ''
             order by a.updated_at desc
             limit greatest(1, least(coalesce(p_limit, 500), 2000))) s
$$;

revoke all on function public.mail_event_keep(text, text, text, timestamptz, text, text, text, text, boolean)
    from public, anon, authenticated;
revoke all on function public.admin_mail(integer, boolean, integer) from public, anon, authenticated;
revoke all on function public.site_release_live(text, text, text, text[], timestamptz) from public, anon, authenticated;
revoke all on function public.site_releases_list(integer) from public, anon, authenticated;
revoke all on function public.relay_call_note(text, text) from public, anon, authenticated;
revoke all on function public.cron_noted(text, text, timestamptz, text, jsonb) from public, anon, authenticated;
revoke all on function public.admission_customers(text, integer) from public, anon, authenticated;
grant execute on function public.mail_event_keep(text, text, text, timestamptz, text, text, text, text, boolean)
    to service_role;
grant execute on function public.admin_mail(integer, boolean, integer) to service_role;
grant execute on function public.site_release_live(text, text, text, text[], timestamptz) to service_role;
grant execute on function public.site_releases_list(integer) to service_role;
grant execute on function public.relay_call_note(text, text) to service_role;
grant execute on function public.cron_noted(text, text, timestamptz, text, jsonb) to service_role;
grant execute on function public.admission_customers(text, integer) to service_role;

notify pgrst, 'reload schema';
