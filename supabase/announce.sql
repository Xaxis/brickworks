-- Announcements from the owner to the site's people, 2026-11-18 (announce;
-- docs/ANNOUNCE.md, docs/ADMIN.md, /admin › Announcements).
--
-- The owner (11-18): "users have a notifications page; me in my admin panel
-- should be able to send or trigger notifications". An announcement is
-- written once, a row of its own, and shown to each person it was sent to
-- in their Notifications page, through notification_rows, so the avatar's
-- count, the account menu's and the page show it and Mark all read reads it,
-- the way everything else there is shown:
--
--   announcements        one row an announcement: its title, its plain
--                        words, an optional link (this site's path, or
--                        https), who it is for (audience: everyone, a plan,
--                        the beta's testers, signed up since a day, those
--                        who published, one person by handle), whether it
--                        is mailed too, and how far it went (draft,
--                        scheduled, sent, withdrawn). Nothing past a draft
--                        without the owner's press on its exact words
--                        (announcements_pressed). As it is sent, who it is
--                        for is counted and kept on the row (recipients), so
--                        its reach is exactly the people it was sent to,
--                        never one copy a person.
--   announcement_reads   one row a person an announcement, made as they
--                        open it (read_at) or follow its link (clicked_at)
--   announcement_mails   one row a person an announcement mailed: those who
--                        opted in to news, each sent once
--   news_mail            whether a person wants Brickworks' news by email,
--                        off until they say (Settings › Email), and off at
--                        once by a mail's unsubscribe
--   site_notice_hides    the site's notice (console3.sql) hidden by a person
--                        signed in, so it stays hidden in each of their
--                        browsers; and site_notices gains ends_at, the time
--                        it goes by itself
--
-- A test announcement (the checks' own, ?tests=1, and every one written on
-- a preview) reaches only test accounts (an address at resend.dev); any
-- other, only the others. A test one is never mailed.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the new tables.
--
-- Only additions, applied after comment_mentions.sql and console3.sql:
-- five new tables, one new column (site_notices.ends_at, empty for every
-- row there), and functions. comment_mentions.sql's notification_rows is
-- replaced with every row it gave and the announcements' (the guard in
-- tools/apply_sql.mjs refuses an earlier file of it applied again alone),
-- and console3.sql's site_notice and site_notices_list with the same rows
-- and their end. No row is changed, nothing dropped or renamed.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/announce.sql --table=announcements
--
-- Dry run, made-up accounts in a rolled-back transaction:
--
--   ... node tools/apply_sql.mjs supabase/announce.sql --dry --try=tools/announce_try.sql --table=announcements

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.announcements (
    id            bigint      generated always as identity primary key,
    test          boolean     not null default false,
    -- A test one's deployment (api/_settings.js scopeOf): each preview's
    -- checks count against its own day's most, and see their own.
    scope         text        constraint announcements_scope check (scope is null or (test and char_length(scope) between 1 and 200)),
    title         text        not null constraint announcements_title check (char_length(title) between 1 and 120),
    body          text        not null default '' constraint announcements_body check (char_length(body) <= 1000),
    link          text        constraint announcements_link check (link is null or (char_length(link) <= 500
                                  and (link ~ '^/([^/\\]|$)' or link ~ '^https://[^\s/]+')
                                  and link !~ '[\s<>"]')),
    audience      jsonb       not null constraint announcements_audience check (jsonb_typeof(audience) = 'object'
                                  and audience->>'kind' in ('everyone', 'plan', 'beta', 'since', 'published', 'person')
                                  and octet_length(audience::text) <= 500),
    email         boolean     not null default false,
    status        text        not null default 'draft'
        constraint announcements_status check (status in ('draft', 'scheduled', 'sent', 'withdrawn')),
    pressed_at    timestamptz,
    pressed_by    text        constraint announcements_pressed_by check (char_length(pressed_by) <= 320),
    pressed_hash  text        constraint announcements_pressed_hash check (pressed_hash ~ '^[0-9a-f]{64}$'),
    send_at       timestamptz,
    sent_at       timestamptz,
    recipients    uuid[],
    reach         integer,
    edited_at     timestamptz,
    withdrawn_at  timestamptz,
    withdrawn_by  text        constraint announcements_withdrawn_by check (char_length(withdrawn_by) <= 320),
    said          text        constraint announcements_said check (char_length(said) <= 300),
    made_by       text        not null constraint announcements_made_by check (char_length(made_by) between 1 and 320),
    made_at       timestamptz not null default now(),
    changed_at    timestamptz not null default now(),
    -- Past a draft only by the owner's press on its words.
    constraint announcements_pressed check (status = 'draft'
        or (pressed_at is not null and pressed_by is not null and pressed_hash is not null)),
    constraint announcements_scheduled check ((status = 'scheduled') = (send_at is not null)),
    constraint announcements_sent check ((status in ('sent', 'withdrawn')) = (sent_at is not null)
        and (sent_at is null) = (recipients is null) and (recipients is null) = (reach is null)),
    constraint announcements_withdrawn check ((status = 'withdrawn') = (withdrawn_at is not null))
);
create index if not exists announcements_newest on public.announcements (test, id desc);
create index if not exists announcements_due on public.announcements (send_at) where status = 'scheduled';
create index if not exists announcements_to on public.announcements using gin (recipients) where status = 'sent';

create table if not exists public.announcement_reads (
    announcement  bigint      not null references public.announcements (id) on delete cascade,
    account       uuid        not null references auth.users (id) on delete cascade,
    read_at       timestamptz,
    clicked_at    timestamptz,
    primary key (announcement, account)
);
create index if not exists announcement_reads_account on public.announcement_reads (account);

create table if not exists public.announcement_mails (
    announcement  bigint      not null references public.announcements (id) on delete cascade,
    account       uuid        not null references auth.users (id) on delete cascade,
    state         text        not null default 'sending'
        constraint announcement_mails_state check (state in ('sending', 'sent', 'failed', 'dry')),
    sent_id       text        constraint announcement_mails_sent_id check (sent_id ~ '^[A-Za-z0-9_-]{1,100}$'),
    at            timestamptz not null default now(),
    primary key (announcement, account)
);
create index if not exists announcement_mails_account on public.announcement_mails (account);

create table if not exists public.news_mail (
    account  uuid        primary key references auth.users (id) on delete cascade,
    news     boolean     not null default false,
    via      text        not null default 'settings' constraint news_mail_via check (via in ('settings', 'unsubscribe')),
    at       timestamptz not null default now()
);

create table if not exists public.site_notice_hides (
    account  uuid        not null references auth.users (id) on delete cascade,
    notice   bigint      not null references public.site_notices (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (account, notice)
);

alter table public.site_notices add column if not exists ends_at timestamptz;

alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.announcement_mails enable row level security;
alter table public.news_mail enable row level security;
alter table public.site_notice_hides enable row level security;
revoke all on public.announcements from public, anon, authenticated, service_role;
revoke all on public.announcement_reads from public, anon, authenticated, service_role;
revoke all on public.announcement_mails from public, anon, authenticated, service_role;
revoke all on public.news_mail from public, anon, authenticated, service_role;
revoke all on public.site_notice_hides from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Who an announcement is for.

-- The accounts [p_audience] names, of the test accounts when [p_test] or of
-- the others, made by [p_at]: {kind: everyone}; {kind: plan, plan, mode,
-- default} (those whose plan Admission last said is [plan] in billing's
-- [mode], and, when it is the default plan, those it never answered for);
-- {kind: beta} (the beta's testers now); {kind: since, since} (signed up at
-- or after it); {kind: published} (a model of theirs shared: published now,
-- or taken down by them since); {kind: person, handle} (whoever has it).
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

-- How many [p_audience] reaches now, and how many of them asked for news by
-- email (a test announcement mails nobody): {count, mail}.
create or replace function public.announce_count(p_audience jsonb, p_test boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('count', count(*),
           'mail', case when coalesce(p_test, false) then 0 else count(*) filter (where n.news) end)
      from public.announce_audience(p_audience, p_test) a(account)
      left join public.news_mail n on n.account = a.account
$$;

-- ---------------------------------------------------------------------------
-- Writing one, and the owner's press.

-- The owner's draft kept: a new one ([p_id] null), or [p_id]'s words
-- changed. A scheduled one changed is a draft again, its press forgotten:
-- it goes only on a fresh press. {announcement, was} ([was] the status it
-- had), or {refused: nobody | gone} for one not there or sent already.
create or replace function public.announce_keep(p_id bigint, p_test boolean, p_title text, p_body text, p_link text,
                                                p_audience jsonb, p_email boolean, p_by text, p_scope text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    a public.announcements;
    was text;
begin
    if p_id is null then
        insert into public.announcements (test, scope, title, body, link, audience, email, made_by)
        values (coalesce(p_test, false), case when p_test then p_scope end, p_title, coalesce(p_body, ''), nullif(p_link, ''), p_audience,
                coalesce(p_email, false), p_by)
        returning * into a;
        return jsonb_build_object('announcement', to_jsonb(a) - 'recipients', 'was', null);
    end if;
    select x.status into was from public.announcements x where x.id = p_id and x.test = coalesce(p_test, false) for update;
    if not found then
        return jsonb_build_object('refused', 'nobody');
    end if;
    if was not in ('draft', 'scheduled') then
        return jsonb_build_object('refused', 'gone');
    end if;
    update public.announcements x
       set title = p_title, body = coalesce(p_body, ''), link = nullif(p_link, ''), audience = p_audience,
           email = coalesce(p_email, false), status = 'draft', pressed_at = null, pressed_by = null,
           pressed_hash = null, send_at = null, said = null, changed_at = clock_timestamp()
     where x.id = p_id
    returning * into a;
    return jsonb_build_object('announcement', to_jsonb(a) - 'recipients', 'was', was);
end;
$$;

-- How many of [p_test]'s announcements are sent on the UTC day of [p_day],
-- and how many wait for it; a test one's, of its deployment [p_scope].
create or replace function public.announce_day(p_test boolean, p_day timestamptz, p_scope text default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'sent', count(*) filter (where a.sent_at is not null
                                   and a.sent_at >= d.starts and a.sent_at < d.starts + interval '1 day'),
        'scheduled', count(*) filter (where a.status = 'scheduled'
                                        and a.send_at >= d.starts and a.send_at < d.starts + interval '1 day'))
      from (select date_trunc('day', coalesce(p_day, now()) at time zone 'utc') at time zone 'utc' as starts) d
      left join public.announcements a on a.test = coalesce(p_test, false)
                                      and (a.test is false or a.scope is not distinct from p_scope)
$$;

-- The owner's press on [p_id] as it was at [p_changed], its words' hash
-- [p_hash]: sent now ([p_at] null), or scheduled for [p_at]. Sent, who it is
-- for is counted at once and kept on the row: its reach. A scheduled one
-- pressed again by the cron goes only with the hash it was pressed with. At
-- most [p_most] go on one UTC day, counting those scheduled for it; one at
-- a time, so two presses at once make one send. {announcement} or
-- {refused: nobody | gone | changed | pressed | limit, sent, scheduled}.
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
    update public.announcements x
       set status = 'sent', send_at = null, sent_at = now(),
           pressed_at = case when a.status = 'draft' then now() else x.pressed_at end,
           pressed_by = case when a.status = 'draft' then p_by else x.pressed_by end,
           pressed_hash = case when a.status = 'draft' then p_hash else x.pressed_hash end,
           recipients = r.who, reach = cardinality(r.who), said = null, changed_at = clock_timestamp()
      from (select coalesce(array_agg(t.account order by t.account), '{}'::uuid[]) as who
              from public.announce_audience(a.audience, a.test, now()) t(account)) r
     where x.id = p_id
    returning x.* into a;
    return jsonb_build_object('announcement', to_jsonb(a) - 'recipients');
end;
$$;

-- A scheduled one back to the drafts, its press forgotten, with [p_said]
-- (why, when the cron could not send it). {announcement} or {refused:
-- nobody | gone} (not waiting to go).
create or replace function public.announce_unschedule(p_id bigint, p_test boolean, p_said text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    a public.announcements;
begin
    update public.announcements x
       set status = 'draft', send_at = null, pressed_at = null, pressed_by = null, pressed_hash = null,
           said = left(p_said, 300), changed_at = clock_timestamp()
     where x.id = p_id and x.test = coalesce(p_test, false) and x.status = 'scheduled'
    returning * into a;
    if not found then
        return jsonb_build_object('refused', case when exists (select 1 from public.announcements x
            where x.id = p_id and x.test = coalesce(p_test, false)) then 'gone' else 'nobody' end);
    end if;
    return jsonb_build_object('announcement', to_jsonb(a) - 'recipients');
end;
$$;

-- A sent one's words changed, as [p_changed] still holds: each person sees
-- the new words, marked edited. Who it went to and its mail are as they
-- were. {announcement} or {refused: nobody | gone | changed}.
create or replace function public.announce_edit(p_id bigint, p_test boolean, p_changed timestamptz, p_title text,
                                                p_body text, p_link text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    a public.announcements;
begin
    select * into a from public.announcements x where x.id = p_id and x.test = coalesce(p_test, false) for update;
    if not found then
        return jsonb_build_object('refused', 'nobody');
    end if;
    if a.status <> 'sent' then
        return jsonb_build_object('refused', 'gone');
    end if;
    if a.changed_at is distinct from p_changed then
        return jsonb_build_object('refused', 'changed');
    end if;
    update public.announcements x
       set title = p_title, body = coalesce(p_body, ''), link = nullif(p_link, ''), edited_at = now(),
           changed_at = clock_timestamp()
     where x.id = p_id
    returning * into a;
    return jsonb_build_object('announcement', to_jsonb(a) - 'recipients');
end;
$$;

-- A sent one withdrawn by [p_by]: it goes from every person's
-- Notifications, and what of its mail had not gone stays unsent.
-- {announcement} or {refused: nobody | gone}.
create or replace function public.announce_withdraw(p_id bigint, p_test boolean, p_by text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    a public.announcements;
begin
    update public.announcements x
       set status = 'withdrawn', withdrawn_at = now(), withdrawn_by = p_by, changed_at = clock_timestamp()
     where x.id = p_id and x.test = coalesce(p_test, false) and x.status = 'sent'
    returning * into a;
    if not found then
        return jsonb_build_object('refused', case when exists (select 1 from public.announcements x
            where x.id = p_id and x.test = coalesce(p_test, false)) then 'gone' else 'nobody' end);
    end if;
    return jsonb_build_object('announcement', to_jsonb(a) - 'recipients');
end;
$$;

-- A draft thrown away. {dropped: true} or {refused: nobody | gone}.
create or replace function public.announce_drop(p_id bigint, p_test boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.announcements x where x.id = p_id and x.test = coalesce(p_test, false) and x.status = 'draft';
    if found then
        return jsonb_build_object('dropped', true);
    end if;
    return jsonb_build_object('refused', case when exists (select 1 from public.announcements x
        where x.id = p_id and x.test = coalesce(p_test, false)) then 'gone' else 'nobody' end);
end;
$$;

-- [p_test]'s announcement [p_id] as it is now, or null: what a press and its
-- mail are checked on and written from.
create or replace function public.announce_one(p_id bigint, p_test boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select to_jsonb(a) - 'recipients' from public.announcements a where a.id = p_id and a.test = coalesce(p_test, false)
$$;

-- [p_test]'s announcements (a test one's, of deployment [p_scope] when it
-- is given), the newest first, at most [p_limit]: each with
-- its reach, how many have opened Notifications since it came (seen), opened
-- it (read) and followed its link (clicked), and its mail by state.
create or replace function public.announce_list(p_test boolean, p_limit integer, p_scope text default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(to_jsonb(a) - 'recipients' || jsonb_build_object(
               'seen', case when a.sent_at is null then null else
                   -- notification_marks_of's rule: their own mark once they have
                   -- one, else their feed's.
                   (select count(*) from unnest(a.recipients) t(account)
                      left join public.notification_marks n on n.account = t.account
                      left join public.feed_marks k on k.account = t.account
                     where case when n.account is null then k.seen_at else n.seen_at end >= a.sent_at) end,
               'read', (select count(*) from public.announcement_reads r where r.announcement = a.id and r.read_at is not null),
               'clicked', (select count(*) from public.announcement_reads r where r.announcement = a.id and r.clicked_at is not null),
               'mails', (select coalesce(jsonb_object_agg(m.state, m.n), '{}'::jsonb)
                           from (select m.state, count(*) as n from public.announcement_mails m
                                  where m.announcement = a.id group by m.state) m))
               order by a.id desc), '[]'::jsonb)
      from (select * from public.announcements x where x.test = coalesce(p_test, false)
                and (x.test is false or p_scope is null or x.scope is not distinct from p_scope)
             order by x.id desc limit greatest(1, least(coalesce(p_limit, 50), 200))) a
$$;

-- What is due: every scheduled one whose time came, test or not, the
-- oldest first, at most 20, with the words their press is checked on.
create or replace function public.announce_due()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(to_jsonb(a) - 'recipients' order by a.send_at), '[]'::jsonb)
      from (select * from public.announcements x where x.status = 'scheduled' and x.send_at <= now()
             order by x.send_at limit 20) a
$$;

-- ---------------------------------------------------------------------------
-- What each person is told, and what they did with it.

-- [viewer]'s announcements sent from after [since] up to [until], as
-- notification_rows gives its rows: kind 'announcement', no model, [item]
-- its words, its link, whether it was edited, and [read] once opened. Not
-- once it is withdrawn.
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
      from public.announcements a
      left join public.announcement_reads r on r.announcement = a.id and r.account = viewer
     where a.status = 'sent' and a.recipients @> array[viewer]
       and a.sent_at > since and a.sent_at <= until
$$;

-- [viewer] opened announcement [p_id] (and, with [p_clicked], followed its
-- link): kept once each. {read: true} or {refused: nobody} for one not sent
-- to them, or withdrawn.
create or replace function public.announcement_read(viewer uuid, p_id bigint, p_clicked boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if viewer is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    if not exists (select 1 from public.announcements a where a.id = p_id and a.status = 'sent'
                                                         and a.recipients @> array[viewer]) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.announcement_reads as r (announcement, account, read_at, clicked_at)
    values (p_id, viewer, now(), case when p_clicked then now() end)
    on conflict on constraint announcement_reads_pkey do update
       set read_at = coalesce(r.read_at, excluded.read_at),
           clicked_at = coalesce(r.clicked_at, excluded.clicked_at);
    return jsonb_build_object('read', true);
end;
$$;

-- What happened to [viewer]'s models, the replies to them, the levels
-- they reached, the challenges and the mentions, as comment_mentions.sql's;
-- and the owner's announcements to them (kind 'announcement').
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
    union all
    -- A challenge opened (or, told later, was told), and the start of its
    -- last two days, unless the viewer entered it: for an account that may
    -- enter, made before then, until the challenge ended. A test account
    -- hears of the test challenges, every other account of the others.
    select k.kind, k.at, null::text,
           jsonb_build_object('challenge', c.id, 'title', c.title, 'ends_on', c.ends_on, 'test', c.test,
                              'read', coalesce(r.at >= k.at, false))
      from public.challenges c
     cross join lateral (
            select greatest(c.starts_on::timestamp at time zone 'utc', coalesce(c.announced_at, '-infinity')) as opened,
                   (c.ends_on - 1)::timestamp at time zone 'utc' as closing) d
     cross join lateral (values ('challenge_open'::text, d.opened), ('challenge_closing'::text, d.closing)) k(kind, at)
      left join public.challenge_reads r on r.account = viewer and r.challenge = c.id
     where c.test = public.trust_is_test_account(viewer)
       and public.trust_may_go_public(viewer) and not public.is_barred(viewer)
       and k.at > since and k.at <= until and k.at <= now()
       and (c.ended_at is null or c.ended_at > k.at)
       and k.at > (select u.created_at from auth.users u where u.id = viewer)
       and (k.kind = 'challenge_open'
            or (d.closing > d.opened
                and not exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.owner = viewer)))
    union all
    -- Who won, for whoever voted in it and entered nothing (an entrant
    -- hears as 'result', under their model); [picked] when a model they
    -- voted for won.
    select 'challenge_won'::text, c.settled_at, null::text,
           jsonb_build_object('challenge', c.id, 'title', c.title, 'ends_on', c.ends_on, 'test', c.test,
                              'picked', exists (select 1 from public.challenge_votes v
                                                  join public.challenge_winners w
                                                    on w.challenge = v.challenge and w.way = v.way and w.model = v.model
                                                 where v.challenge = c.id and v.voter = viewer),
                              'read', coalesce(r.at >= c.settled_at, false))
      from public.challenges c
      left join public.challenge_reads r on r.account = viewer and r.challenge = c.id
     where c.settled_at is not null and c.settled_at > since and c.settled_at <= until
       and exists (select 1 from public.challenge_votes v where v.challenge = c.id and v.voter = viewer)
       and not exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.owner = viewer)
    union all
    -- A comment or a reply that names the viewer (@handle), by somebody
    -- else, as a reply is told: unless the viewer hears it already, as a
    -- comment on their own model or a reply in their own conversation.
    select 'mention'::text, k.at, k.model,
           jsonb_build_object('comment', k.id, 'parent', k.parent, 'model', k.model, 'name', m.name,
                              'version', k.version, 'step', k.step, 'said', left(k.body, 240),
                              'by', public.feed_who(k.author))
      from public.comment_mentions n
      join public.model_comments k on k.id = n.comment
      join public.shared_models m on m.id = k.model
     where n.account = viewer and k.author <> viewer and m.owner <> viewer and m.published and not m.barred
       and k.removed_at is null and k.hidden_at is null and public.shown_publicly(k.author)
       and public.comment_parent_shown(k.parent)
       and not exists (select 1 from threads t where t.root = k.parent and k.at > t.joined)
       and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = k.model), '-infinity')
       and k.at > since and k.at <= until
    union all
    -- An announcement from the owner, to each account it was sent to.
    select * from public.announcement_rows(viewer, since, until)
$$;

-- ---------------------------------------------------------------------------
-- Their news by email.

-- Whether [p_account] wants Brickworks' news by email, [p_news] kept first
-- when it is given (by [p_via]: settings, or a mail's unsubscribe).
-- {news}: off until they say.
create or replace function public.news_choice(p_account uuid, p_news boolean default null, p_via text default 'settings')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_account is null or not exists (select 1 from auth.users u where u.id = p_account) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    if p_news is not null then
        insert into public.news_mail as n (account, news, via, at) values (p_account, p_news, coalesce(p_via, 'settings'), now())
        on conflict on constraint news_mail_pkey do update set news = excluded.news, via = excluded.via, at = excluded.at;
    end if;
    return jsonb_build_object('news', coalesce((select n.news from public.news_mail n where n.account = p_account), false));
end;
$$;

-- The next [p_limit] people announcement [p_id] is mailed to, each taken
-- once and written down as being sent: those it was sent to who ask for
-- news by email now, with an address that takes mail, not mailed it yet.
-- Nobody while it is a test one, withdrawn or not mailed. [{account, email}].
create or replace function public.announce_mail_take(p_id bigint, p_limit integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    taken jsonb;
begin
    with next as (
        select u.id as account, u.email
          from public.announcements a
         cross join lateral unnest(a.recipients) t(account)
          join auth.users u on u.id = t.account
          -- Who had chosen news by the time it went: one who chooses it
          -- later is not sent what came before.
          join public.news_mail n on n.account = u.id and n.news and n.at <= a.sent_at
         where a.id = p_id and a.status = 'sent' and a.email and not a.test
           and u.email is not null and u.email_confirmed_at is not null
           and u.email !~* '@(oc\.brickworks\.diy|resend\.dev)$'
           and not exists (select 1 from public.announcement_mails m where m.announcement = a.id and m.account = u.id)
         order by u.id
         limit greatest(1, least(coalesce(p_limit, 100), 1000))
         for update of n skip locked),
    kept as (
        insert into public.announcement_mails (announcement, account, state)
        select p_id, x.account, 'sending' from next x
        on conflict on constraint announcement_mails_pkey do nothing
        returning account)
    select coalesce(jsonb_agg(jsonb_build_object('account', x.account, 'email', x.email) order by x.account), '[]'::jsonb)
      into taken
      from next x join kept k on k.account = x.account;
    return taken;
end;
$$;

-- What became of each mail taken: [{account, state, sent_id}], state sent,
-- failed or dry; or again, when Resend refused the batch before taking any
-- of it (too many at once, or down): taken again by a later round.
create or replace function public.announce_mail_done(p_id bigint, p_results jsonb)
returns integer
language sql
security definer
set search_path = public
as $$
    with given as (
        select r.account, r.state, r.sent_id
          from jsonb_to_recordset(coalesce(p_results, '[]'::jsonb)) r(account uuid, state text, sent_id text)),
    again as (
        delete from public.announcement_mails m using given g
         where m.announcement = p_id and m.account = g.account and m.state = 'sending' and g.state = 'again'
        returning 1),
    done as (
        update public.announcement_mails m
           set state = g.state, sent_id = g.sent_id, at = now()
          from given g
         where m.announcement = p_id and m.account = g.account and m.state = 'sending'
           and g.state in ('sent', 'failed', 'dry')
        returning 1)
    select ((select count(*) from done) + (select count(*) from again))::integer
$$;

-- The announcements still being mailed: sent, mailed, not a test one, with
-- somebody who asks for news not taken yet. [id].
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
       and exists (select 1 from unnest(a.recipients) t(account)
                     join public.news_mail n on n.account = t.account and n.news and n.at <= a.sent_at
                    where not exists (select 1 from public.announcement_mails m
                                       where m.announcement = a.id and m.account = t.account))
$$;

-- ---------------------------------------------------------------------------
-- The site's notice: its end, and hidden by a person.

-- The notice showing in [p_scope], until its end: {id, words, tone, set_by,
-- set_at, ends_at}, or null.
create or replace function public.site_notice(p_scope text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object('id', n.id, 'words', n.words, 'tone', n.tone, 'set_by', n.set_by, 'set_at', n.set_at,
                              'ends_at', n.ends_at)
      from public.site_notices n
     where n.scope = p_scope and n.cleared_at is null and (n.ends_at is null or n.ends_at > now())
$$;

-- The notices of [p_scope], the newest first: what was said, when and by
-- whom, and when it ended by itself.
create or replace function public.site_notices_list(p_scope text, p_limit integer)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'words', n.words, 'tone', n.tone, 'set_by', n.set_by,
               'set_at', n.set_at, 'cleared_by', n.cleared_by, 'cleared_at', n.cleared_at, 'ends_at', n.ends_at)
               order by n.id desc), '[]'::jsonb)
      from (select * from public.site_notices where scope = p_scope order by id desc
             limit greatest(1, least(coalesce(p_limit, 10), 50))) n
$$;

-- The notice [p_id] showing in [p_scope] goes by itself at [p_ends] (null:
-- until it is cleared). {ends_at} or {refused: nobody | past}.
create or replace function public.site_notice_ends(p_scope text, p_id bigint, p_ends timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    ends timestamptz;
begin
    if p_ends is not null and p_ends <= now() then
        return jsonb_build_object('refused', 'past');
    end if;
    update public.site_notices n set ends_at = p_ends
     where n.id = p_id and n.scope = p_scope and n.cleared_at is null
    returning n.ends_at into ends;
    if not found then
        return jsonb_build_object('refused', 'nobody');
    end if;
    return jsonb_build_object('ends_at', ends);
end;
$$;

-- [p_account] hid notice [p_id]: kept, so each of their browsers hides it.
create or replace function public.site_notice_hide(p_account uuid, p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_account is null or not exists (select 1 from public.site_notices n where n.id = p_id) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.site_notice_hides (account, notice) values (p_account, p_id)
    on conflict on constraint site_notice_hides_pkey do nothing;
    return jsonb_build_object('hidden', true);
end;
$$;

-- Whether [p_account] hid notice [p_id].
create or replace function public.site_notice_hidden(p_account uuid, p_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (select 1 from public.site_notice_hides h where h.account = p_account and h.notice = p_id)
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.announce_audience(jsonb, boolean, timestamptz) from public, anon, authenticated;
grant execute on function public.announce_audience(jsonb, boolean, timestamptz) to service_role;
revoke all on function public.announce_count(jsonb, boolean) from public, anon, authenticated;
grant execute on function public.announce_count(jsonb, boolean) to service_role;
revoke all on function public.announce_keep(bigint, boolean, text, text, text, jsonb, boolean, text, text) from public, anon, authenticated;
grant execute on function public.announce_keep(bigint, boolean, text, text, text, jsonb, boolean, text, text) to service_role;
revoke all on function public.announce_day(boolean, timestamptz, text) from public, anon, authenticated;
grant execute on function public.announce_day(boolean, timestamptz, text) to service_role;
revoke all on function public.announce_press(bigint, boolean, timestamptz, text, text, timestamptz, integer) from public, anon, authenticated;
grant execute on function public.announce_press(bigint, boolean, timestamptz, text, text, timestamptz, integer) to service_role;
revoke all on function public.announce_unschedule(bigint, boolean, text) from public, anon, authenticated;
grant execute on function public.announce_unschedule(bigint, boolean, text) to service_role;
revoke all on function public.announce_edit(bigint, boolean, timestamptz, text, text, text) from public, anon, authenticated;
grant execute on function public.announce_edit(bigint, boolean, timestamptz, text, text, text) to service_role;
revoke all on function public.announce_withdraw(bigint, boolean, text) from public, anon, authenticated;
grant execute on function public.announce_withdraw(bigint, boolean, text) to service_role;
revoke all on function public.announce_drop(bigint, boolean) from public, anon, authenticated;
grant execute on function public.announce_drop(bigint, boolean) to service_role;
revoke all on function public.announce_one(bigint, boolean) from public, anon, authenticated;
grant execute on function public.announce_one(bigint, boolean) to service_role;
revoke all on function public.announce_list(boolean, integer, text) from public, anon, authenticated;
grant execute on function public.announce_list(boolean, integer, text) to service_role;
revoke all on function public.announce_due() from public, anon, authenticated;
grant execute on function public.announce_due() to service_role;
revoke all on function public.announcement_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.announcement_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.announcement_read(uuid, bigint, boolean) from public, anon, authenticated;
grant execute on function public.announcement_read(uuid, bigint, boolean) to service_role;
revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.news_choice(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.news_choice(uuid, boolean, text) to service_role;
revoke all on function public.announce_mail_take(bigint, integer) from public, anon, authenticated;
grant execute on function public.announce_mail_take(bigint, integer) to service_role;
revoke all on function public.announce_mail_done(bigint, jsonb) from public, anon, authenticated;
grant execute on function public.announce_mail_done(bigint, jsonb) to service_role;
revoke all on function public.announce_mail_due() from public, anon, authenticated;
grant execute on function public.announce_mail_due() to service_role;
revoke all on function public.site_notice(text) from public, anon, authenticated;
grant execute on function public.site_notice(text) to service_role;
revoke all on function public.site_notices_list(text, integer) from public, anon, authenticated;
grant execute on function public.site_notices_list(text, integer) to service_role;
revoke all on function public.site_notice_ends(text, bigint, timestamptz) from public, anon, authenticated;
grant execute on function public.site_notice_ends(text, bigint, timestamptz) to service_role;
revoke all on function public.site_notice_hide(uuid, bigint) from public, anon, authenticated;
grant execute on function public.site_notice_hide(uuid, bigint) to service_role;
revoke all on function public.site_notice_hidden(uuid, bigint) from public, anon, authenticated;
grant execute on function public.site_notice_hidden(uuid, bigint) to service_role;

notify pgrst, 'reload schema';
