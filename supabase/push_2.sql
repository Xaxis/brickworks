-- Push, its second round (hsfix, 2026-11-22): what the review of push.sql
-- found (bench/results/hsreview-2026-11-22/FINDINGS.txt), at the root.
--
--   A device goes with the sign-in it was turned on in. push_subscriptions
--   gets the session (auth.sessions) it was turned on with, deleted with it:
--   signed out everywhere (admin_sign_out), the account deleted, a session
--   ended any other way, and its devices go at once. One whose session ran
--   out (not_after) goes at the next take or the minute's sweep. A device
--   turned on before this file has no session, and goes too.
--
--   A mark never waits. push_due's key (the account) made a comment's
--   insert wait on a take that had just deleted the same account's row
--   (N3). Marks are now rows of their own, push_marks, only ever inserted
--   by the triggers and deleted by a take: nothing a comment's insert does
--   can conflict with a take. push_mark's own lock wait is bounded too, and
--   it, and each trigger, gives up on any trouble, a cancel included, with
--   a warning: the comment is written whatever push does.
--
--   Each device hears each row once, and can hear it again when it was not
--   delivered: push_sent's keys are now a row's for one device, so a push
--   service that answers 5xx or 429 (or a block list that could not be read,
--   F1) puts back what was not sent (push_again), due again a minute later,
--   then two, then three, then never: at most three tries more. A function
--   cut off mid-send loses what it took: that is at most once.
--
--   One model, one push in three minutes. A device pushed about a model in
--   the last three minutes is not pushed about it again until they are up:
--   what came meanwhile waits, marked due for that moment, and then goes as
--   one push that says how many (N11).
--
--   Only brickworks.diy takes what is due (api/_push.js S1): the checks'
--   own accounts (Resend's test addresses, @resend.dev) are left out of
--   its take, and taken only by push_take_tester, one at a time, for a
--   check signed in as that account on a deployment of its own. So a
--   preview never takes a real person's due row, and a check's push goes
--   through its own deployment's code.
--
--   The minute's job (pg_cron) sweeps (push_sweep): marks and push.sql's
--   due rows older than half an hour (nothing older is pushed anyway, N4),
--   what was pushed two days ago, devices whose sign-in is gone, and its
--   own run log older than a day (N5); then knocks if anybody is due.
--
-- Only additions to push.sql's own: one column, one table, new functions,
-- push.sql's own functions made again (push_mark, the five triggers'
-- functions, push_take) and the cron job's command. No other row is
-- changed, nothing of anybody else's replaced, nothing dropped or renamed.
-- push_due stays, emptied by the sweep and no longer written.

-- ---------------------------------------------------------------------------
-- A device's sign-in.

alter table public.push_subscriptions add column if not exists session uuid references auth.sessions (id) on delete cascade;
create index if not exists push_subscriptions_session on public.push_subscriptions (session);

-- Whether the sign-in [p_session] is still there and has not run out.
create or replace function public.push_alive(p_session uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select p_session is not null
       and exists (select 1 from auth.sessions a where a.id = p_session and (a.not_after is null or a.not_after > now()))
$$;

-- Whether [p_account] is one of the checks' own (a Resend test address), as
-- api/_auth.js isTestAccount has it.
create or replace function public.push_tester(p_account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce((select u.email ilike '%@resend.dev' from auth.users u where u.id = p_account), false)
$$;

-- ---------------------------------------------------------------------------
-- Marks.

create table if not exists public.push_marks (
    id       bigint generated always as identity primary key,
    account  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    tries    integer not null default 0 check (tries between 0 and 9)
);
create index if not exists push_marks_account on public.push_marks (account);
create index if not exists push_marks_at on public.push_marks (at);
alter table public.push_marks enable row level security;
revoke all on public.push_marks from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Devices.

-- [p_endpoint] on for [p_account], signed in with [p_session]: {on,
-- devices}, or {refused: "session"} when that sign-in is not there. As
-- push.sql's push_subscribe otherwise: at most 20 devices an account, and a
-- device another account had moves to this one.
create or replace function public.push_subscribe(p_account uuid, p_endpoint text, p_p256dh text, p_auth text,
                                                 p_origin text, p_lang text, p_session uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if p_account is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    if p_session is null
       or not exists (select 1 from auth.sessions a where a.id = p_session and a.user_id = p_account
                         and (a.not_after is null or a.not_after > now())) then
        return jsonb_build_object('refused', 'session');
    end if;
    insert into public.push_subscriptions as s (endpoint, account, p256dh, auth, origin, lang, session)
    values (p_endpoint, p_account, p_p256dh, p_auth, p_origin, coalesce(p_lang, 'en'), p_session)
    on conflict (endpoint) do update
       set account = excluded.account, p256dh = excluded.p256dh, auth = excluded.auth, origin = excluded.origin,
           lang = excluded.lang, session = excluded.session,
           made_at = case when s.account = excluded.account then s.made_at else now() end;
    delete from public.push_subscriptions s
     where s.account = p_account
       and s.endpoint in (select x.endpoint from public.push_subscriptions x where x.account = p_account
                           order by x.made_at desc offset 20);
    return jsonb_build_object('on', true,
        'devices', (select count(*) from public.push_subscriptions s where s.account = p_account));
end;
$$;

-- Every device of [p_account] off: {on: false, devices: 0, gone}.
create or replace function public.push_unsubscribe_all(p_account uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with gone as (delete from public.push_subscriptions s where s.account = p_account returning 1)
    select jsonb_build_object('on', false, 'devices', 0, 'gone', (select count(*) from gone))
$$;

-- The device whose endpoint is [p_endpoint] and whose secret is [p_auth]
-- forgotten, whoever's it is: the browser signing out says both, and only
-- that browser (and this database) knows the secret. {gone}.
create or replace function public.push_forget(p_endpoint text, p_auth text)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with gone as (delete from public.push_subscriptions s
                   where s.endpoint = p_endpoint and s.auth = p_auth and p_auth is not null returning 1)
    select jsonb_build_object('gone', (select count(*) from gone))
$$;

-- ---------------------------------------------------------------------------
-- Marking who is due: a row a mark, never one that can be in a take's way.

-- Of [accounts], those with a device marked due, and a knock when one of
-- them (not a check's own) had nothing due already. Never waits long on a
-- lock, and never fails the write it is called from.
create or replace function public.push_mark(accounts uuid[])
returns void
language plpgsql
security definer
set search_path = public
set lock_timeout = '200ms'
as $$
declare
    knock boolean;
begin
    with marked as (
        insert into public.push_marks (account)
        select distinct s.account from public.push_subscriptions s where s.account = any (accounts)
        returning account)
    select exists (select 1 from marked m
                    where not public.push_tester(m.account)
                      and not exists (select 1 from public.push_marks o where o.account = m.account and o.at <= now()))
      into knock;
    if knock then
        perform public.push_knock();
    end if;
exception when query_canceled or others then
    raise warning 'push_mark: %', sqlerrm;
end;
$$;

create or replace function public.push_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.push_mark(array(
        select x.account from (
            select m.owner as account from public.shared_models m where m.id = new.model
            union
            select o.author from public.model_comments o
             where new.parent is not null and (o.id = new.parent or o.parent = new.parent)) x
         where x.account <> new.author));
    return null;
exception when query_canceled or others then
    raise warning 'push_on_comment: %', sqlerrm;
    return null;
end;
$$;

create or replace function public.push_on_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.push_mark(array[new.account]);
    return null;
exception when query_canceled or others then
    raise warning 'push_on_mention: %', sqlerrm;
    return null;
end;
$$;

create or replace function public.push_on_photo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.push_mark(array(
        select m.owner from public.shared_models m where m.id = new.model and m.owner <> new.account));
    return null;
exception when query_canceled or others then
    raise warning 'push_on_photo: %', sqlerrm;
    return null;
end;
$$;

create or replace function public.push_on_remix()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.remixed_from is not null and new.published and new.listed and new.listed_at is not null
       and (tg_op = 'INSERT' or old.listed_at is distinct from new.listed_at or old.listed is distinct from new.listed) then
        perform public.push_mark(array(
            select o.owner from public.shared_models o where o.id = new.remixed_from and o.owner <> new.owner));
    end if;
    return null;
exception when query_canceled or others then
    raise warning 'push_on_remix: %', sqlerrm;
    return null;
end;
$$;

create or replace function public.push_on_settled()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if old.settled_at is null and new.settled_at is not null then
        perform public.push_mark(array(select distinct e.owner from public.challenge_entries e where e.challenge = new.id));
    end if;
    return null;
exception when query_canceled or others then
    raise warning 'push_on_settled: %', sqlerrm;
    return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Taking what is due.

-- One account's new notifications for each of its devices, taken:
-- {account, tries, devices: [{endpoint, p256dh, auth, origin, lang, made_at,
-- rows}]}, or null when it has nothing to send now. A row is a row of
-- notification_rows as notification_list says one ({kind, at, on, ...item})
-- of the kinds pushed, newer than the device's turning on and than half an
-- hour ago, not sent to that device before, with its key (what push_again
-- puts back) and its model's key ("last"). A model the device was pushed
-- about in the last three minutes waits: the account is marked due when
-- they are up. Its devices whose sign-in has gone are deleted first.
create or replace function public.push_collect(p_account uuid, p_tries integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    since timestamptz;
    devices jsonb;
begin
    delete from public.push_subscriptions s where s.account = p_account and not public.push_alive(s.session);
    select min(s.made_at) into since from public.push_subscriptions s where s.account = p_account;
    if since is null then
        return null;
    end if;
    with fresh as (
        select distinct on (k.key) k.key, r.kind, r.at, coalesce(r.model, '') as model, r.item
          from public.notification_rows(p_account, greatest(since, now() - interval '30 minutes'), now()) r
         cross join lateral (select left(r.kind || ':' || coalesce(r.item->>'comment', r.item->>'photo',
                                 r.item->>'challenge', '') || ':' || coalesce(r.item->>'model', r.model, ''), 180) as key) k
         where r.kind in ('comment', 'reply', 'mention', 'photo', 'remix', 'result')
         order by k.key, r.at desc),
    pairs as (
        select w.key, w.kind, w.at, w.model, w.item, s.endpoint,
               w.key || '@' || left(md5(s.endpoint), 12) as sent_key,
               'last:' || coalesce(nullif(w.model, ''), w.kind) || '@' || left(md5(s.endpoint), 12) as last_key
          from fresh w
          join public.push_subscriptions s on s.account = p_account and w.at > s.made_at),
    unsent as (
        -- push.sql's take kept a key for the account, not the device.
        select p.* from pairs p
         where not exists (select 1 from public.push_sent x where x.account = p_account and x.key in (p.key, p.sent_key))),
    held as (
        select u.*, l.at + interval '3 minutes' as until
          from unsent u left join public.push_sent l on l.account = p_account and l.key = u.last_key),
    going as (
        select h.* from held h where h.until is null or h.until <= now()),
    kept as (
        insert into public.push_sent (account, key)
        select p_account, g.sent_key from going g
        on conflict (account, key) do nothing
        returning push_sent.key),
    stamped as (
        insert into public.push_sent (account, key, at)
        select distinct p_account, g.last_key, now() from going g join kept k on k.key = g.sent_key
        on conflict (account, key) do update set at = excluded.at
        returning 1),
    later as (
        insert into public.push_marks (account, at)
        select p_account, min(h.until) from held h where h.until > now() having count(*) > 0
        returning 1)
    select coalesce(jsonb_agg(d.device), '[]'::jsonb) into devices
      from (select jsonb_build_object('endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth, 'origin', s.origin,
                       'lang', s.lang, 'made_at', s.made_at,
                       'rows', (select jsonb_agg(jsonb_build_object('kind', g.kind, 'at', g.at, 'on', g.model) || g.item
                                                 || jsonb_build_object('key', g.sent_key, 'last', g.last_key)
                                                 order by g.at desc)
                                  from going g join kept k on k.key = g.sent_key where g.endpoint = s.endpoint)) as device
              from public.push_subscriptions s where s.account = p_account) d
     where jsonb_typeof(d.device->'rows') = 'array';
    if jsonb_array_length(devices) = 0 then
        return null;
    end if;
    return jsonb_build_object('account', p_account, 'tries', coalesce(p_tries, 0), 'devices', devices);
end;
$$;

-- Up to [p_most] due accounts, but the checks' own, taken (brickworks.diy's
-- knock): [push_collect's, ...]. Taken is pushed, unless push_again puts
-- it back.
create or replace function public.push_take(p_most integer default 25)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    taken uuid[];
    tries integer[];
    said jsonb;
    result jsonb := '[]'::jsonb;
begin
    with picked as (
        select m.id, m.account, m.tries from public.push_marks m
          join auth.users u on u.id = m.account
         where m.at <= now() and u.email not ilike '%@resend.dev'
         order by m.id
         limit 1000
           for update of m skip locked),
    accounts as (
        select p.account, max(p.tries) as tries, min(p.id) as first from picked p
         group by p.account order by min(p.id) limit least(greatest(coalesce(p_most, 25), 1), 100)),
    gone as (
        delete from public.push_marks m using picked p, accounts a
         where m.id = p.id and p.account = a.account returning m.id)
    select coalesce(array_agg(a.account order by a.first), '{}'), coalesce(array_agg(a.tries order by a.first), '{}')
      into taken, tries
      from accounts a;
    for i in 1 .. coalesce(array_length(taken, 1), 0) loop
        begin
            said := public.push_collect(taken[i], tries[i]);
            if said is not null then
                result := result || jsonb_build_array(said);
            end if;
        exception when others then
            raise warning 'push_take: %', sqlerrm;
        end;
    end loop;
    return result;
end;
$$;

-- A check's own account [p_account] (a Resend test address), its marks
-- alone taken, as push_take would: [push_collect's] or []. Anybody else's,
-- never.
create or replace function public.push_take_tester(p_account uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    tries integer;
    said jsonb;
begin
    if not public.push_tester(p_account) then
        return '[]'::jsonb;
    end if;
    with gone as (
        delete from public.push_marks m
         where m.id in (select x.id from public.push_marks x where x.account = p_account and x.at <= now()
                           for update skip locked)
        returning m.tries)
    select max(g.tries) into tries from gone g;
    if tries is null then
        return '[]'::jsonb;
    end if;
    said := public.push_collect(p_account, tries);
    return case when said is null then '[]'::jsonb else jsonb_build_array(said) end;
end;
$$;

-- What was taken for [p_account] but not delivered, put back: [p_keys], the
-- rows' keys (and their models' "last" keys) as push_collect gave them,
-- [p_tries] the take's tries. Due again in a minute more each try; after
-- the third, what failed stays taken (never sent). {again}.
create or replace function public.push_again(p_account uuid, p_keys text[], p_tries integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    tries integer := least(greatest(coalesce(p_tries, 0), 0), 8);
begin
    -- A model's three minutes start again from what was delivered, not
    -- from what failed.
    delete from public.push_sent s where s.account = p_account and s.key = any (p_keys) and s.key like 'last:%';
    if tries >= 3 then
        return jsonb_build_object('again', false);
    end if;
    delete from public.push_sent s where s.account = p_account and s.key = any (p_keys);
    insert into public.push_marks (account, at, tries)
    values (p_account, now() + make_interval(mins => tries + 1), tries + 1);
    return jsonb_build_object('again', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- The minute's job.

create or replace function public.push_sweep()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.push_marks m where m.at < now() - interval '30 minutes';
    delete from public.push_due d where d.at < now() - interval '30 minutes';
    delete from public.push_sent s where s.at < now() - interval '2 days';
    delete from public.push_subscriptions s where not public.push_alive(s.session);
    -- Its own run log: a day of it, cut once an hour.
    if extract(minute from now()) = 0 then
        begin
            delete from cron.job_run_details d using cron.job j
             where j.jobid = d.jobid and j.jobname = 'brickworks-push' and d.start_time < now() - interval '1 day';
        exception when others then
            raise warning 'push_sweep: the run log: %', sqlerrm;
        end;
    end if;
    if exists (select 1 from public.push_marks m join auth.users u on u.id = m.account
                where m.at <= now() and u.email not ilike '%@resend.dev') then
        perform public.push_knock();
    end if;
exception when others then
    raise warning 'push_sweep: %', sqlerrm;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone, and only what the server calls.

revoke all on function public.push_alive(uuid) from public, anon, authenticated, service_role;
revoke all on function public.push_tester(uuid) from public, anon, authenticated, service_role;
revoke all on function public.push_subscribe(uuid, text, text, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.push_subscribe(uuid, text, text, text, text, text, uuid) to service_role;
revoke all on function public.push_unsubscribe_all(uuid) from public, anon, authenticated;
grant execute on function public.push_unsubscribe_all(uuid) to service_role;
revoke all on function public.push_forget(text, text) from public, anon, authenticated;
grant execute on function public.push_forget(text, text) to service_role;
revoke all on function public.push_collect(uuid, integer) from public, anon, authenticated, service_role;
revoke all on function public.push_take_tester(uuid) from public, anon, authenticated;
grant execute on function public.push_take_tester(uuid) to service_role;
revoke all on function public.push_again(uuid, text[], integer) from public, anon, authenticated;
grant execute on function public.push_again(uuid, text[], integer) to service_role;
revoke all on function public.push_sweep() from public, anon, authenticated, service_role;

-- The minute's job: the sweep, which knocks while anybody is due.
do $knock$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron')
       and exists (select 1 from pg_extension where extname = 'pg_net') then
        perform cron.schedule('brickworks-push', '* * * * *', $job$select public.push_sweep()$job$);
    end if;
end
$knock$;

notify pgrst, 'reload schema';
