-- Announcements, the review's fixes (anfix, 2026-11-18; docs/ANNOUNCE.md,
-- bench/results/anreview-2026-11-18), applied after announce.sql, which is
-- live.
--
--   announcement_to       one row a person an announcement was put before:
--                         (account, announcement, sent_at), written by the
--                         press in the statement that sends it. A person's
--                         Notifications read it by account, the mail walks it
--                         by announcement, and its reach is the rows' count.
--                         Before this, who it reached was a uuid[] on the
--                         announcement's row (recipients), scanned by every
--                         signed-in page: 23-33 ms a page with 50,000
--                         accounts and 30 sends (anreview, scale50k.json).
--                         recipients stays, and is no longer written: a send
--                         since this file keeps it empty ('{}', since its
--                         check asks for a value once sent). What was sent
--                         before is copied here once.
--   announcement_counts   each announcement's reads, clicks and mail by state,
--                         counted as they happen, so the console's list reads
--                         one row an announcement and never a person's
--
-- And:
--   - News mail has a most a day, the owner's (site_settings news_mail_most,
--     200 until set), counted inside the take from the mail kept today. It
--     stops until the next UTC day when Resend says the team's daily or
--     monthly quota is used (news_mail_stopped). That team also sends every
--     site's sign-in codes, job.rip's among them, so news always gives way:
--     a take comes at least 1.1 s after the one before, from any instance,
--     and never in the 1.5 s after this site's own code was asked for.
--   - A barred account is in no audience but "one person", and never mailed.
--   - The site notices a person hid, shown or not (site_notice_hidden_ids),
--     said with the avatar's count, so no browser of theirs shows one again.
--
-- Only additions: two new tables, two new indexes, functions, and the rows
-- copied once (announcement_to from recipients, the counts from the reads
-- and mails). announce.sql's announce_audience, announce_count,
-- announce_press, announce_list, announcement_rows, announcement_read,
-- announce_mail_take, announce_mail_done and announce_mail_due are
-- replaced, each with the same arguments and answer (supabase/later.tsv).
-- notification_rows is not touched: it reads announcement_rows. Nothing
-- is dropped or renamed.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node --env-file=.env tools/apply_sql.mjs supabase/announce2.sql --table=announcement_to
--
-- Dry run, made-up accounts in a rolled-back transaction:
--
--   ... node --env-file=.env tools/apply_sql.mjs supabase/announce2.sql --dry --try=tools/announce2_try.sql --table=announcement_to

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.announcement_to (
    account       uuid        not null references auth.users (id) on delete cascade,
    announcement  bigint      not null references public.announcements (id) on delete cascade,
    sent_at       timestamptz not null,
    primary key (account, announcement)
);
-- By announcement, in the order the mail takes them.
create index if not exists announcement_to_announcement on public.announcement_to (announcement, account);

create table if not exists public.announcement_counts (
    announcement  bigint  primary key references public.announcements (id) on delete cascade,
    reads         integer not null default 0 constraint announcement_counts_reads check (reads >= 0),
    clicks        integer not null default 0 constraint announcement_counts_clicks check (clicks >= 0),
    mails         jsonb   not null default '{}'::jsonb constraint announcement_counts_mails check (jsonb_typeof(mails) = 'object')
);

-- The day's mail counted, and the last take timed.
create index if not exists announcement_mails_at on public.announcement_mails (at);

alter table public.announcement_to enable row level security;
alter table public.announcement_counts enable row level security;
revoke all on public.announcement_to from public, anon, authenticated, service_role;
revoke all on public.announcement_counts from public, anon, authenticated, service_role;

-- What was sent before this file, copied once: who it reached, and its counts.
insert into public.announcement_to (account, announcement, sent_at)
select t.account, a.id, a.sent_at
  from public.announcements a
 cross join lateral unnest(a.recipients) t(account)
 where a.sent_at is not null and exists (select 1 from auth.users u where u.id = t.account)
on conflict on constraint announcement_to_pkey do nothing;

insert into public.announcement_counts (announcement, reads, clicks, mails)
select a.id,
       (select count(*) from public.announcement_reads r where r.announcement = a.id and r.read_at is not null),
       (select count(*) from public.announcement_reads r where r.announcement = a.id and r.clicked_at is not null),
       (select coalesce(jsonb_object_agg(m.state, m.n), '{}'::jsonb)
          from (select m.state, count(*) as n from public.announcement_mails m where m.announcement = a.id group by m.state) m)
  from public.announcements a
 where a.sent_at is not null
on conflict on constraint announcement_counts_pkey do nothing;

-- ---------------------------------------------------------------------------
-- The counts, as they happen.

-- [p_reads] and [p_clicks] more for announcement [p_id], and its mail by
-- state moved by [p_mails] ({state: n}, n below 0 for those that left it).
-- Called only by this file's functions: granted to nobody.
create or replace function public.announce_tally(p_id bigint, p_reads integer, p_clicks integer, p_mails jsonb)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.announcement_counts as c (announcement, reads, clicks, mails)
    values (p_id, greatest(coalesce(p_reads, 0), 0), greatest(coalesce(p_clicks, 0), 0),
            (select coalesce(jsonb_object_agg(e.key, e.value::integer), '{}'::jsonb)
               from jsonb_each_text(coalesce(p_mails, '{}'::jsonb)) e where e.value::integer > 0))
    on conflict on constraint announcement_counts_pkey do update
       set reads = c.reads + coalesce(p_reads, 0), clicks = c.clicks + coalesce(p_clicks, 0),
           mails = (select coalesce(jsonb_object_agg(s.key, s.n), '{}'::jsonb)
                      from (select e.key, sum(e.value::integer)::integer as n
                              from (select key, value from jsonb_each_text(c.mails)
                                    union all
                                    select key, value from jsonb_each_text(coalesce(p_mails, '{}'::jsonb))) e
                             group by e.key having sum(e.value::integer) > 0) s)
$$;

-- ---------------------------------------------------------------------------
-- Who an announcement is for: as announce.sql's, with a barred account
-- (moderation.sql's barred_accounts) only in "one person".
create or replace function public.announce_audience(p_audience jsonb, p_test boolean, p_at timestamptz default now())
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
    select u.id
      from auth.users u
     where (coalesce(u.email, '') ~* '@resend\.dev$') = coalesce(p_test, false)
       and u.created_at <= coalesce(p_at, now())
       -- Barred, an account hears only what is said to it alone.
       and (p_audience->>'kind' = 'person' or not exists (select 1 from public.barred_accounts b where b.account = u.id))
       and case p_audience->>'kind'
             when 'everyone' then true
             when 'beta' then exists (select 1 from public.beta_testers t where t.account = u.id and t.state = 'tester')
             when 'since' then pg_input_is_valid(p_audience->>'since', 'timestamptz')
                               and u.created_at >= (p_audience->>'since')::timestamptz
             when 'published' then exists (select 1 from public.shared_models m where m.owner = u.id)
             when 'person' then exists (select 1 from public.people p where p.account = u.id
                                                                   and p.handle = lower(p_audience->>'handle'))
             when 'plan' then p_audience->>'mode' in ('test', 'live') and coalesce((
                    select case when pg_input_is_valid(s.value, 'jsonb') then s.value::jsonb->'value'->'plan'->>'key' end
                      from public.admission_snapshots s
                     where s.key = 'admission:v2:brickworks:' || (p_audience->>'mode') || ':c:' || u.id::text
                       and s.value <> ''),
                    case when (p_audience->>'default') = 'true' then p_audience->>'plan' end) = p_audience->>'plan'
             else false
           end
$$;

-- How many [p_audience] reaches now, and how many of them would be mailed
-- (asked for news, an address that takes mail, not barred; a test
-- announcement mails nobody): {count, mail}.
create or replace function public.announce_count(p_audience jsonb, p_test boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('count', count(*),
           'mail', case when coalesce(p_test, false) then 0 else count(*) filter (where n.news
               and u.email is not null and u.email_confirmed_at is not null
               and u.email !~* '@(oc\.brickworks\.diy|resend\.dev)$'
               and not exists (select 1 from public.barred_accounts b where b.account = a.account)) end)
      from public.announce_audience(p_audience, p_test) a(account)
      join auth.users u on u.id = a.account
      left join public.news_mail n on n.account = a.account
$$;

-- ---------------------------------------------------------------------------
-- The owner's press: as announce.sql's, and sent, each person it is for is
-- a row of announcement_to, written in the statement that sends it; its
-- reach is how many rows that made. recipients is no longer written.
create or replace function public.announce_press(p_id bigint, p_test boolean, p_changed timestamptz, p_by text,
                                                 p_hash text, p_at timestamptz, p_most integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    a public.announcements;
    day jsonb;
    taken integer;
begin
    perform pg_advisory_xact_lock(hashtext('announce_press'));
    select * into a from public.announcements x where x.id = p_id and x.test = coalesce(p_test, false) for update;
    if not found then
        return jsonb_build_object('refused', 'nobody');
    end if;
    if a.status not in ('draft', 'scheduled') then
        return jsonb_build_object('refused', 'gone');
    end if;
    if a.changed_at is distinct from p_changed then
        return jsonb_build_object('refused', 'changed');
    end if;
    if a.status = 'scheduled' and a.pressed_hash is distinct from p_hash then
        return jsonb_build_object('refused', 'pressed');
    end if;
    day := public.announce_day(a.test, coalesce(p_at, now()), a.scope);
    -- This one, scheduled for that day, is counted once.
    taken := (day->>'sent')::integer + (day->>'scheduled')::integer
             - case when a.status = 'scheduled' and date_trunc('day', a.send_at at time zone 'utc')
                         = date_trunc('day', coalesce(p_at, now()) at time zone 'utc') then 1 else 0 end;
    if taken >= greatest(coalesce(p_most, 0), 0) then
        return jsonb_build_object('refused', 'limit', 'sent', (day->>'sent')::integer,
                                  'scheduled', (day->>'scheduled')::integer, 'most', p_most);
    end if;
    if p_at is not null then
        update public.announcements x
           set status = 'scheduled', send_at = p_at, pressed_at = now(), pressed_by = p_by,
               pressed_hash = p_hash, said = null, changed_at = clock_timestamp()
         where x.id = p_id
        returning * into a;
        return jsonb_build_object('announcement', to_jsonb(a) - 'recipients');
    end if;
    with who as (
        select t.account from public.announce_audience(a.audience, a.test, now()) t(account)),
    put as (
        insert into public.announcement_to (account, announcement, sent_at)
        select w.account, p_id, now() from who w
        on conflict on constraint announcement_to_pkey do nothing
        returning 1)
    update public.announcements x
       set status = 'sent', send_at = null, sent_at = now(),
           pressed_at = case when a.status = 'draft' then now() else x.pressed_at end,
           pressed_by = case when a.status = 'draft' then p_by else x.pressed_by end,
           pressed_hash = case when a.status = 'draft' then p_hash else x.pressed_hash end,
           recipients = '{}'::uuid[], reach = (select count(*) from put)::integer, said = null, changed_at = clock_timestamp()
     where x.id = p_id
    returning x.* into a;
    perform public.announce_tally(p_id, 0, 0, '{}'::jsonb);
    return jsonb_build_object('announcement', to_jsonb(a) - 'recipients');
end;
$$;

-- [p_test]'s announcements (a test one's, of deployment [p_scope] when it
-- is given), the newest first, at most [p_limit]: each with its reach and
-- its counts (announcement_counts): how many opened it (read), followed its
-- link (clicked), and its mail by state. One row an announcement is read,
-- never a person's.
create or replace function public.announce_list(p_test boolean, p_limit integer, p_scope text default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(to_jsonb(a) - 'recipients' || jsonb_build_object(
               'read', coalesce(c.reads, 0), 'clicked', coalesce(c.clicks, 0), 'mails', coalesce(c.mails, '{}'::jsonb))
               order by a.id desc), '[]'::jsonb)
      from (select * from public.announcements x where x.test = coalesce(p_test, false)
                and (x.test is false or p_scope is null or x.scope is not distinct from p_scope)
             order by x.id desc limit greatest(1, least(coalesce(p_limit, 50), 200))) a
      left join public.announcement_counts c on c.announcement = a.id
$$;

-- ---------------------------------------------------------------------------
-- What each person is told, and what they did with it.

-- [viewer]'s announcements sent from after [since] up to [until], as
-- notification_rows gives its rows (announce.sql's), read from their own
-- rows of announcement_to. Not once it is withdrawn.
create or replace function public.announcement_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, model text, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    select 'announcement'::text, a.sent_at, null::text,
           jsonb_build_object('announcement', a.id, 'title', a.title, 'said', a.body, 'link', a.link,
                              'edited', a.edited_at is not null, 'read', r.read_at is not null)
      from public.announcement_to t
      join public.announcements a on a.id = t.announcement
      left join public.announcement_reads r on r.announcement = a.id and r.account = viewer
     where t.account = viewer and t.sent_at > since and t.sent_at <= until and a.status = 'sent'
$$;

-- [viewer] opened announcement [p_id] (and, with [p_clicked], followed its
-- link): kept once each, and counted the first time. {read: true} or
-- {refused: nobody} for one not sent to them, or withdrawn.
create or replace function public.announcement_read(viewer uuid, p_id bigint, p_clicked boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    was public.announcement_reads;
begin
    if viewer is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    if not exists (select 1 from public.announcement_to t join public.announcements a on a.id = t.announcement
                    where t.account = viewer and t.announcement = p_id and a.status = 'sent') then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.announcement_reads (announcement, account) values (p_id, viewer)
    on conflict on constraint announcement_reads_pkey do nothing;
    select * into was from public.announcement_reads r where r.announcement = p_id and r.account = viewer for update;
    update public.announcement_reads r
       set read_at = coalesce(r.read_at, now()),
           clicked_at = case when coalesce(p_clicked, false) then coalesce(r.clicked_at, now()) else r.clicked_at end
     where r.announcement = p_id and r.account = viewer;
    if was.read_at is null or (coalesce(p_clicked, false) and was.clicked_at is null) then
        perform public.announce_tally(p_id, case when was.read_at is null then 1 else 0 end,
                                      case when coalesce(p_clicked, false) and was.clicked_at is null then 1 else 0 end, '{}'::jsonb);
    end if;
    return jsonb_build_object('read', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Their news by email: a most a day, a stop, and room for sign-in codes.

-- The most news mails a day in [p_scope] (the site's: 'live'): the owner's
-- (/admin › Announcements › Settings), 200 until set.
create or replace function public.news_mail_most(p_scope text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select coalesce((select s.value::integer from public.site_settings s
                      where s.name = 'news_mail_most' and s.scope = p_scope and s.value ~ '^[0-9]{1,5}$'), 200)
$$;

-- How many news mails went today (UTC) or are going: kept as sent, or taken
-- and not yet answered.
create or replace function public.news_mail_today()
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer from public.announcement_mails m
     where m.state in ('sending', 'sent') and m.at >= date_trunc('day', now() at time zone 'utc') at time zone 'utc'
$$;

-- Whether news mail is stopped, and why: {until, why}, or null. Kept in
-- site_settings as "<until>|<why>" by announce_mail_stop.
create or replace function public.news_mail_stopped()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('until', k.until, 'why', k.why)
      from (select case when pg_input_is_valid(split_part(s.value, '|', 1), 'timestamptz')
                        then split_part(s.value, '|', 1)::timestamptz end as until,
                   split_part(s.value, '|', 2) as why
              from public.site_settings s
             where s.name = 'news_mail_stopped' and s.scope = 'live') k
     where k.until > now()
$$;

-- News mail stopped until [p_until], Resend having said [p_why] (its
-- error's name: daily_quota_exceeded, monthly_quota_exceeded). {until, why}.
create or replace function public.announce_mail_stop(p_until timestamptz, p_why text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    why text := left(regexp_replace(coalesce(p_why, ''), '[^a-z_]', '', 'g'), 60);
begin
    if p_until is null or p_until <= now() or p_until > now() + interval '32 days' then
        return jsonb_build_object('refused', 'when');
    end if;
    insert into public.site_settings (name, scope, value, set_by)
    values ('news_mail_stopped', 'live', to_char(p_until at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '|' || why, 'Resend')
    on conflict (name, scope) do update set value = excluded.value, set_by = excluded.set_by, set_at = now();
    return jsonb_build_object('until', p_until, 'why', why);
end;
$$;

-- What the console says of news mail in [p_scope]: {most, most_by,
-- most_at, today, stopped}.
create or replace function public.news_mail_state(p_scope text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('most', public.news_mail_most(p_scope), 'today', public.news_mail_today(),
           'stopped', public.news_mail_stopped(),
           'most_by', (select s.set_by from public.site_settings s where s.name = 'news_mail_most' and s.scope = p_scope),
           'most_at', (select s.set_at from public.site_settings s where s.name = 'news_mail_most' and s.scope = p_scope))
$$;

-- The next [p_limit] people announcement [p_id] is mailed to, each taken
-- once and written down as being sent: those it was sent to who had asked
-- for news by email when it went and still do, with an address that takes
-- mail, not barred, not mailed it yet. Nobody while it is a test one,
-- withdrawn or not mailed; nobody while news mail is stopped; never past
-- the day's most. One take at a time, from any instance: one with somebody
-- to take comes at least 1.1 s after the mail taken or answered before, and
-- 1.5 s after this site's last sign-in code was asked for (otp_requests),
-- waiting up to 3 s for that. [{account, email}].
create or replace function public.announce_mail_take(p_id bigint, p_limit integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    taken jsonb;
    room integer;
    pause double precision;
    who uuid[];
    address text[];
begin
    perform pg_advisory_xact_lock(hashtext('announce_mail_take'));
    if public.news_mail_stopped() is not null then
        return '[]'::jsonb;
    end if;
    room := least(public.news_mail_most('live') - public.news_mail_today(), greatest(1, least(coalesce(p_limit, 100), 1000)));
    if room <= 0 then
        return '[]'::jsonb;
    end if;
    select array_agg(x.account order by x.account), array_agg(x.email order by x.account) into who, address
      from (select u.id as account, u.email
              from public.announcements a
              join public.announcement_to t on t.announcement = a.id
              join auth.users u on u.id = t.account
              -- Who had chosen news by the time it went: one who chooses it
              -- later is not sent what came before.
              join public.news_mail n on n.account = u.id and n.news and n.at <= a.sent_at
             where a.id = p_id and a.status = 'sent' and a.email and not a.test
               and u.email is not null and u.email_confirmed_at is not null
               and u.email !~* '@(oc\.brickworks\.diy|resend\.dev)$'
               and not exists (select 1 from public.barred_accounts b where b.account = u.id)
               and not exists (select 1 from public.announcement_mails m where m.announcement = a.id and m.account = u.id)
             order by t.account
             limit room
               for update of n skip locked) x;
    if who is null then
        return '[]'::jsonb;
    end if;
    -- Its turn: the team's sign-in codes first.
    pause := greatest(
        extract(epoch from (select max(m.at) from public.announcement_mails m) + interval '1.1 seconds' - clock_timestamp()),
        extract(epoch from (select max(o.asked_at) from public.otp_requests o) + interval '1.5 seconds' - clock_timestamp()),
        0);
    if pause > 0 then
        perform pg_sleep(least(pause, 3));
    end if;
    with kept as (
        insert into public.announcement_mails (announcement, account, state, at)
        select p_id, w.account, 'sending', clock_timestamp() from unnest(who) w(account)
        on conflict on constraint announcement_mails_pkey do nothing
        returning account)
    select coalesce(jsonb_agg(jsonb_build_object('account', k.account, 'email', e.email) order by k.account), '[]'::jsonb)
      into taken
      from kept k join unnest(who, address) e(account, email) on e.account = k.account;
    if jsonb_array_length(taken) > 0 then
        perform public.announce_tally(p_id, 0, 0, jsonb_build_object('sending', jsonb_array_length(taken)));
    end if;
    return taken;
end;
$$;

-- What became of each mail taken: [{account, state, sent_id}], state sent,
-- failed or dry; or again, when Resend refused the batch before taking any
-- of it (too many at once, a quota, or down): taken again by a later
-- round. Counted as it is kept. How many were kept.
create or replace function public.announce_mail_done(p_id bigint, p_results jsonb)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    again integer;
    sent integer;
    failed integer;
    dry integer;
begin
    with given as (
        select r.account, r.state from jsonb_to_recordset(coalesce(p_results, '[]'::jsonb)) r(account uuid, state text)),
    gone as (
        delete from public.announcement_mails m using given g
         where m.announcement = p_id and m.account = g.account and m.state = 'sending' and g.state = 'again'
        returning 1)
    select count(*) into again from gone;
    with given as (
        select r.account, r.state, r.sent_id
          from jsonb_to_recordset(coalesce(p_results, '[]'::jsonb)) r(account uuid, state text, sent_id text)),
    done as (
        update public.announcement_mails m
           set state = g.state, sent_id = g.sent_id, at = now()
          from given g
         where m.announcement = p_id and m.account = g.account and m.state = 'sending'
           and g.state in ('sent', 'failed', 'dry')
        returning m.state)
    select count(*) filter (where d.state = 'sent'), count(*) filter (where d.state = 'failed'), count(*) filter (where d.state = 'dry')
      into sent, failed, dry from done d;
    if again + sent + failed + dry > 0 then
        perform public.announce_tally(p_id, 0, 0, jsonb_build_object('sending', -(again + sent + failed + dry), 'sent', sent,
                                                                     'failed', failed, 'dry', dry));
    end if;
    return again + sent + failed + dry;
end;
$$;

-- The announcements still being mailed: sent in the last week, mailed, not
-- a test one, with somebody the take would take. [id].
create or replace function public.announce_mail_due()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(a.id order by a.id), '[]'::jsonb)
      from public.announcements a
     where a.status = 'sent' and a.email and not a.test and a.sent_at > now() - interval '7 days'
       and exists (select 1 from public.announcement_to t
                     join auth.users u on u.id = t.account
                     join public.news_mail n on n.account = t.account and n.news and n.at <= a.sent_at
                    where t.announcement = a.id
                      and u.email is not null and u.email_confirmed_at is not null
                      and u.email !~* '@(oc\.brickworks\.diy|resend\.dev)$'
                      and not exists (select 1 from public.barred_accounts b where b.account = t.account)
                      and not exists (select 1 from public.announcement_mails m
                                       where m.announcement = a.id and m.account = t.account))
$$;

-- ---------------------------------------------------------------------------
-- The site's notices [p_account] hid that show in [p_scope] now: [id], for
-- the avatar's count to carry to every page (api/_notifications.js
-- feedCount), so a browser that showed one before it was hidden elsewhere
-- shows it no more.
create or replace function public.site_notice_hidden_ids(p_account uuid, p_scope text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(h.notice order by h.notice), '[]'::jsonb)
      from public.site_notice_hides h
      join public.site_notices n on n.id = h.notice
     where h.account = p_account and n.scope = p_scope and n.cleared_at is null
       and (n.ends_at is null or n.ends_at > now())
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone; the counts' helper, nobody.

revoke all on function public.announce_tally(bigint, integer, integer, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.announce_audience(jsonb, boolean, timestamptz) from public, anon, authenticated;
grant execute on function public.announce_audience(jsonb, boolean, timestamptz) to service_role;
revoke all on function public.announce_count(jsonb, boolean) from public, anon, authenticated;
grant execute on function public.announce_count(jsonb, boolean) to service_role;
revoke all on function public.announce_press(bigint, boolean, timestamptz, text, text, timestamptz, integer) from public, anon, authenticated;
grant execute on function public.announce_press(bigint, boolean, timestamptz, text, text, timestamptz, integer) to service_role;
revoke all on function public.announce_list(boolean, integer, text) from public, anon, authenticated;
grant execute on function public.announce_list(boolean, integer, text) to service_role;
revoke all on function public.announcement_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.announcement_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.announcement_read(uuid, bigint, boolean) from public, anon, authenticated;
grant execute on function public.announcement_read(uuid, bigint, boolean) to service_role;
revoke all on function public.news_mail_most(text) from public, anon, authenticated;
grant execute on function public.news_mail_most(text) to service_role;
revoke all on function public.news_mail_today() from public, anon, authenticated;
grant execute on function public.news_mail_today() to service_role;
revoke all on function public.news_mail_stopped() from public, anon, authenticated;
grant execute on function public.news_mail_stopped() to service_role;
revoke all on function public.announce_mail_stop(timestamptz, text) from public, anon, authenticated;
grant execute on function public.announce_mail_stop(timestamptz, text) to service_role;
revoke all on function public.news_mail_state(text) from public, anon, authenticated;
grant execute on function public.news_mail_state(text) to service_role;
revoke all on function public.announce_mail_take(bigint, integer) from public, anon, authenticated;
grant execute on function public.announce_mail_take(bigint, integer) to service_role;
revoke all on function public.announce_mail_done(bigint, jsonb) from public, anon, authenticated;
grant execute on function public.announce_mail_done(bigint, jsonb) to service_role;
revoke all on function public.announce_mail_due() from public, anon, authenticated;
grant execute on function public.announce_mail_due() to service_role;
revoke all on function public.site_notice_hidden_ids(uuid, text) from public, anon, authenticated;
grant execute on function public.site_notice_hidden_ids(uuid, text) to service_role;

notify pgrst, 'reload schema';
