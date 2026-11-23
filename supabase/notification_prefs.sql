-- What you hear of, and where (inbox, 2026-11-23; docs/SOCIAL.md, the
-- units' rank 7; api/_notifications.js reads and writes it).
--
--   notification_prefs   one row an account, made at its first choice:
--                        each kind of notification here (the bell and
--                        /notifications), by push, and by the day's email,
--                        on or off; the models it muted; and what it marked
--                        done. Deleted with the account.
--
-- The eleven kinds a person chooses (notification_kind maps the page's own
-- rows onto them): comment, reply, mention (in a comment or in Talk), photo
-- (of a build of your model), remix, likes, talk (a post in a thread you
-- follow), challenge (one opening, its last two days), result (who won one
-- you entered or voted in), achievement and news (the site's owner's
-- announcements). Until an account chooses, each is here, pushed only for
-- reply and mention (to a device turned on in Settings; one turned on
-- before this file keeps the kinds it was pushed then, below), and emailed as
-- before: comments, photos and remixes as mail_choices says (follows.sql),
-- news as the news choice says (announce.sql), the other seven not at all.
-- The email of those four is kept where it was; the other seven's here.
--
-- Mute: a model's comments, replies and mentions on it, photos, remixes,
-- likes and its challenge results stop being counted, listed, pushed and
-- emailed, until unmuted. Done: a group of the page (a model's, a
-- challenge's, a thread's, an announcement's, the achievements') is done up
-- to a time, everything with done_all: what came by then leaves the count
-- and the list for the Done view; what comes after is back in the list.
--
-- Replaced, from production's own bodies (read 2026-11-23 with
-- pg_get_functiondef): push_collect (talk.sql's: the kinds chosen, all
-- eleven, and nothing of a muted model) and claim_comment_digest
-- (replies.sql's: whoever chose one of the seven by email, those rows in
-- the day's one email, and nothing of a muted model). Every other line of
-- each is as it was. Added: the table, notification_kind,
-- notification_group, the functions below, and a pg_cron job that marks
-- due, every five minutes, an account with a device that chose to be pushed
-- a kind no trigger marks (likes, challenges, results of a challenge voted
-- in, achievements, news).
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone, as push.sql's.
-- Every write is counted by may_act. Nothing existing is altered, dropped
-- or renamed; no row is changed.

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.notification_prefs (
    account      uuid primary key references auth.users (id) on delete cascade,
    -- Each a whole set of the kinds on for it; null: the default.
    here         text[],
    push         text[],
    email        text[],
    -- When the email's set went from none to some: nothing older is mailed.
    email_since  timestamptz,
    muted        text[] not null default '{}' check (cardinality(muted) <= 500),
    -- A group's key -> done up to then (ISO time), and everything up to done_all.
    done         jsonb not null default '{}'::jsonb check (jsonb_typeof(done) = 'object'),
    done_all     timestamptz,
    at           timestamptz not null default now()
);

alter table public.notification_prefs enable row level security;
revoke all on public.notification_prefs from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The kinds.

-- The eleven kinds a person chooses, in the order Settings shows them.
create or replace function public.notification_kinds()
returns text[]
language sql
immutable
as $$
    select array['comment', 'reply', 'mention', 'photo', 'remix', 'likes', 'talk', 'challenge', 'result',
                 'achievement', 'news']::text[]
$$;

-- The seven whose email is kept here; comment, photo, remix and news are
-- mailed as mail_choices and the news choice say.
create or replace function public.notification_mailed_here()
returns text[]
language sql
immutable
as $$
    select array['reply', 'mention', 'likes', 'talk', 'challenge', 'result', 'achievement']::text[]
$$;

-- A row of notification_rows' kind as the kind a person chooses.
create or replace function public.notification_kind(raw text)
returns text
language sql
immutable
as $$
    select case raw
        when 'talk_mention' then 'mention'
        when 'talk_reply' then 'talk'
        when 'challenge_open' then 'challenge'
        when 'challenge_closing' then 'challenge'
        when 'challenge_won' then 'result'
        when 'announcement' then 'news'
        else raw
    end
$$;

-- The group of the page a row is in (api/_notifications.js noticeGroups):
-- its model, or the achievements', a challenge's, an announcement's or a
-- thread's.
create or replace function public.notification_group(raw text, model text, item jsonb)
returns text
language sql
immutable
as $$
    select case
        when raw = 'achievement' then 'achievements'
        when raw in ('challenge_open', 'challenge_closing', 'challenge_won') then 'challenge-' || coalesce(item->>'challenge', '0')
        when raw = 'announcement' then 'announcement-' || coalesce(item->>'announcement', '0')
        when raw in ('talk_reply', 'talk_mention') then 'talk-' || coalesce(item->>'thread', '0')
        else coalesce(model, '')
    end
$$;

-- ---------------------------------------------------------------------------
-- Reading and choosing.

-- What [viewer] chose, each set filled with its default: {kept, here, push,
-- email, muted, done, done_all}. [kept]: whether they ever chose.
create or replace function public.notification_prefs_of(viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'kept', p.account is not null,
        'here', to_jsonb(coalesce(p.here, public.notification_kinds())),
        'push', to_jsonb(coalesce(p.push, array['reply', 'mention']::text[])),
        'email', to_jsonb(coalesce(p.email, '{}'::text[])),
        'muted', to_jsonb(coalesce(p.muted, '{}'::text[])),
        'done', coalesce(p.done, '{}'::jsonb),
        'done_all', p.done_all)
      from (select 1) one
      left join public.notification_prefs p on p.account = viewer
     where viewer is not null
$$;

-- One choice: [p_kind] on [p_channel] ('here', 'push' or 'email') on or
-- off. A cell at a time, so two tabs choosing two cells keep both. The
-- email of comment, photo, remix and news is not chosen here.
create or replace function public.notification_choose(viewer uuid, p_kind text, p_channel text, p_on boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.notification_prefs;
    now_on text[];
begin
    if viewer is null then
        return null;
    end if;
    if p_kind is null or not (p_kind = any (public.notification_kinds())) then
        raise exception 'brickworks: say a kind: %', array_to_string(public.notification_kinds(), ', ') using errcode = '22023';
    end if;
    if p_channel is null or p_channel not in ('here', 'push', 'email') then
        raise exception 'brickworks: say here, push or email' using errcode = '22023';
    end if;
    if p_on is null then
        raise exception 'brickworks: say on: true or on: false' using errcode = '22023';
    end if;
    if p_channel = 'email' and not (p_kind = any (public.notification_mailed_here())) then
        raise exception 'brickworks: the email of % is chosen with the day''s email', p_kind using errcode = '22023';
    end if;
    if not public.may_act(viewer::text, 'notification_prefs', 240, 2000) then
        return jsonb_build_object('refused', 'busy');
    end if;
    perform pg_advisory_xact_lock(hashtext('notification_prefs:' || viewer::text));
    insert into public.notification_prefs (account) values (viewer) on conflict (account) do nothing;
    select * into p from public.notification_prefs n where n.account = viewer;
    now_on := case p_channel when 'here' then coalesce(p.here, public.notification_kinds())
                             when 'push' then coalesce(p.push, array['reply', 'mention']::text[])
                             else coalesce(p.email, '{}'::text[]) end;
    now_on := case when p_on then array(select distinct k from unnest(now_on || p_kind) k order by k)
                   else array_remove(now_on, p_kind) end;
    update public.notification_prefs n
       set here = case when p_channel = 'here' then now_on else n.here end,
           push = case when p_channel = 'push' then now_on else n.push end,
           email = case when p_channel = 'email' then now_on else n.email end,
           email_since = case when p_channel = 'email' and p_on and cardinality(coalesce(n.email, '{}'::text[])) = 0
                              then now() else n.email_since end,
           at = now()
     where n.account = viewer;
    return public.notification_prefs_of(viewer);
end;
$$;

-- [p_model] muted for [viewer] ([p_on]), or unmuted: {muted, count}, or
-- {refused: 'no_model' | 'most' | 'busy'}.
create or replace function public.notification_mute(viewer uuid, p_model text, p_on boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    now_muted text[];
begin
    if viewer is null then
        return null;
    end if;
    if p_on is null then
        raise exception 'brickworks: say on: true or on: false' using errcode = '22023';
    end if;
    if p_model is null or p_model !~ '^[A-Za-z0-9]{10}$' then
        return jsonb_build_object('refused', 'no_model');
    end if;
    if p_on and not exists (select 1 from public.shared_models m where m.id = p_model) then
        return jsonb_build_object('refused', 'no_model');
    end if;
    if not public.may_act(viewer::text, 'notification_mute', 120, 600) then
        return jsonb_build_object('refused', 'busy');
    end if;
    perform pg_advisory_xact_lock(hashtext('notification_prefs:' || viewer::text));
    insert into public.notification_prefs (account) values (viewer) on conflict (account) do nothing;
    select n.muted into now_muted from public.notification_prefs n where n.account = viewer;
    if p_on and not (p_model = any (now_muted)) then
        if cardinality(now_muted) >= 500 then
            return jsonb_build_object('refused', 'most');
        end if;
        now_muted := now_muted || p_model;
    elsif not p_on then
        now_muted := array_remove(now_muted, p_model);
    end if;
    update public.notification_prefs n set muted = now_muted, at = now() where n.account = viewer;
    return jsonb_build_object('muted', p_model = any (now_muted), 'count', cardinality(now_muted));
end;
$$;

-- A group ([p_group], a key of notification_group) done up to [p_at], or
-- everything (p_group null). Done moves a mark only later, so a tab that
-- read the list before another's Done never brings rows back; [p_undo]
-- sets it to [p_at] exactly (null: no mark), Undo's way. {group, at,
-- before}: [before] the mark it had, for that Undo.
create or replace function public.notification_done(viewer uuid, p_group text, p_at timestamptz, p_undo boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.notification_prefs;
    was timestamptz;
    mark timestamptz;
begin
    if viewer is null then
        return null;
    end if;
    if p_group is not null and p_group !~ '^(?:[A-Za-z0-9]{10}|achievements|(?:challenge|announcement|talk)-[0-9]{1,12})$' then
        raise exception 'brickworks: say which group: a model, achievements, or challenge-, announcement- or talk- and its number'
            using errcode = '22023';
    end if;
    if p_at is null and not coalesce(p_undo, false) then
        raise exception 'brickworks: say up to when: at' using errcode = '22023';
    end if;
    if p_at is not null and (p_at > now() + interval '5 minutes' or p_at < now() - interval '91 days') then
        raise exception 'brickworks: at is a time of the last 90 days' using errcode = '22023';
    end if;
    if not public.may_act(viewer::text, 'notification_done', 600, 5000) then
        return jsonb_build_object('refused', 'busy');
    end if;
    perform pg_advisory_xact_lock(hashtext('notification_prefs:' || viewer::text));
    insert into public.notification_prefs (account) values (viewer) on conflict (account) do nothing;
    select * into p from public.notification_prefs n where n.account = viewer;
    was := case when p_group is null then p.done_all else (p.done->>p_group)::timestamptz end;
    mark := case when coalesce(p_undo, false) then p_at
                 else greatest(coalesce(was, '-infinity'::timestamptz), p_at) end;
    if p_group is null then
        update public.notification_prefs n set done_all = mark, at = now() where n.account = viewer;
    else
        -- Kept 91 days, as long as anything is listed.
        update public.notification_prefs n
           set done = (select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb)
                         from jsonb_each(n.done) e
                        where e.key <> p_group and (e.value #>> '{}')::timestamptz > now() - interval '91 days')
                      || case when mark is null then '{}'::jsonb else jsonb_build_object(p_group, mark) end,
               at = now()
         where n.account = viewer;
    end if;
    return jsonb_build_object('group', p_group, 'at', mark, 'before', was);
end;
$$;

-- The avatar's count of notifications as [viewer] chose them: what came
-- since the list was last opened, of the kinds shown here, of no model
-- muted, not done, and nothing their blocks leave out (block_counts'
-- rule). Null for an account that never chose: counted as before.
create or replace function public.notification_count_kept(viewer uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select (select count(*)::integer from (
               select 1 from public.notification_rows(viewer,
                   greatest(coalesce((select s.seen_at from public.notification_marks_of(viewer) s), '-infinity'),
                            now() - interval '90 days'), now()) r
                where public.notification_kind(r.kind) = any (coalesce(p.here, public.notification_kinds()))
                  and not (coalesce(r.model, '') = any (p.muted))
                  and r.at > coalesce(greatest(p.done_all,
                                               (p.done->>public.notification_group(r.kind, r.model, r.item))::timestamptz),
                                      '-infinity'::timestamptz)
                  and (not exists (select 1 from public.blocks k where k.blocker = viewer)
                       or not public.block_row_barred(viewer, r.item))
                limit 99) n)
      from public.notification_prefs p
     where p.account = viewer and viewer is not null
$$;

-- ---------------------------------------------------------------------------
-- Push: the kinds chosen. push_collect as talk.sql left it, with two
-- changes: the rows are those of the kinds the account chose to be pushed
-- (by default reply and mention) and of no model it muted, where before
-- they were eight kinds always; and a row's key names a like's day, an
-- announcement and a level, so each of those goes once.

create or replace function public.push_collect(p_account uuid, p_tries integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    since timestamptz;
    devices jsonb;
begin
    delete from public.push_subscriptions s where s.account = p_account and not public.push_alive(s.session);
    select min(s.made_at) into since from public.push_subscriptions s where s.account = p_account;
    if since is null then
        return null;
    end if;
    with chosen as (
        -- What the account chose (notification_prefs.sql): the kinds pushed, the models muted.
        select coalesce(p.push, array['reply', 'mention']::text[]) as kinds, coalesce(p.muted, '{}'::text[]) as muted
          from (select 1) one left join public.notification_prefs p on p.account = p_account),
    fresh as (
        select distinct on (k.key) k.key, r.kind, r.at, coalesce(r.model, '') as model, r.item
          from public.notification_rows(p_account, greatest(since, now() - interval '30 minutes'), now()) r
         cross join chosen c
         cross join lateral (select left(r.kind || ':' || coalesce(r.item->>'comment', r.item->>'photo',
                                 r.item->>'challenge', r.item->>'post', r.item->>'announcement', r.item->>'day',
                                 (r.item->>'track') || '.' || (r.item->>'level'), '') || ':' || coalesce(r.item->>'model', r.model, ''), 180) as key) k
         where public.notification_kind(r.kind) = any (c.kinds)
           and not (coalesce(r.model, '') = any (c.muted))
         order by k.key, r.at desc),
    pairs as (
        select w.key, w.kind, w.at, w.model, w.item, s.endpoint,
               w.key || '@' || left(md5(s.endpoint), 12) as sent_key,
               'last:' || coalesce(nullif(w.model, ''),
                                    case when w.kind in ('talk_reply', 'talk_mention') then 'talk-' || (w.item->>'thread') end,
                                    w.kind) || '@' || left(md5(s.endpoint), 12) as last_key
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
$function$;

-- Every five minutes (pg_cron, below): due, each account with a device that
-- chose to be pushed a kind no trigger marks it due for: likes, a
-- challenge opening or closing, a result of a challenge it voted in, a
-- level reached, news. push_sweep knocks within the minute; push_collect
-- finds what is new of the last half hour, each once.
create or replace function public.push_mark_chosen()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    n integer;
begin
    with marked as (
        insert into public.push_marks (account)
        select distinct s.account
          from public.push_subscriptions s
          join public.notification_prefs p on p.account = s.account
         where p.push && array['likes', 'challenge', 'result', 'achievement', 'news']::text[]
           and not exists (select 1 from public.push_marks m where m.account = s.account)
        returning 1)
    select count(*)::integer into n from marked;
    return n;
exception when others then
    raise warning 'push_mark_chosen: %', sqlerrm;
    return 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- The day's email: the kinds chosen. claim_comment_digest as replies.sql
-- left it, with three changes: whoever chose one of the seven kinds kept
-- here by email is claimed too (mail_choices or not); the rows of those
-- kinds since the last email (or since they chose) go in it, as
-- [notices], the page's own rows (notification_rows), at most 50; and
-- nothing of a model they muted, comments, feed or notices.

create or replace function public.claim_comment_digest(for_owner uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    who record;
    ids bigint[];
    waiting integer;
    told timestamptz;
    rows_told jsonb;
    rows_waiting integer;
    notices_told jsonb;
    notices_waiting integer;
    made bigint;
    due jsonb := '[]'::jsonb;
begin
    for who in
        select a.account, coalesce(c.at, p.email_since, p.at) as since,
               coalesce(c.comments, false) as comments, coalesce(c.models, false) as models,
               coalesce(c.versions, false) as versions, coalesce(c.photos, false) as photos,
               coalesce(c.remixes, false) as remixes,
               coalesce(p.email, '{}'::text[]) as kinds, coalesce(p.email_since, p.at) as kinds_since,
               coalesce(p.muted, '{}'::text[]) as muted
          from (select m.account from public.mail_choices m
                 where (m.comments or m.models or m.versions or m.photos or m.remixes)
                union
                select n.account from public.notification_prefs n
                 where cardinality(coalesce(n.email, '{}'::text[])) > 0) a
          left join public.mail_choices c on c.account = a.account
          left join public.notification_prefs p on p.account = a.account
         where (for_owner is null or a.account = for_owner)
           and not exists (select 1 from public.comment_digests d
                            where d.owner = a.account and d.state <> 'failed'
                              and d.at > now() - interval '1 day')
         order by a.account
    loop
        exit when jsonb_array_length(due) >= 50;
        perform pg_advisory_xact_lock(hashtext('comment_digest:' || who.account::text));
        if exists (select 1 from public.comment_digests d
                    where d.owner = who.account and d.state <> 'failed'
                      and d.at > now() - interval '1 day') then
            continue;
        end if;
        ids := null;
        waiting := 0;
        if who.comments then
            select array_agg(w.id order by w.at), count(*)::integer into ids, waiting
              from (select k.id, k.at from public.model_comments k
                      join public.shared_models m on m.id = k.model and m.published and m.owner = who.account
                      left join public.comment_digests d on d.id = k.digest
                     where k.removed_at is null and k.hidden_at is null and k.author <> who.account
                       and k.at >= who.since
                       and not (k.model = any (who.muted))
                       and (k.digest is null or d.state = 'failed'
                            or (d.state = 'sending' and d.at < now() - interval '15 minutes'))
                       and public.shown_publicly(k.author)
                       and public.comment_parent_shown(k.parent)) w;
        end if;
        select max(d.at) into told from public.comment_digests d
         where d.owner = who.account and d.state in ('sent', 'dry');
        select coalesce(jsonb_agg(r.item || jsonb_build_object('kind', r.kind, 'at', r.at)
                                  order by r.at, r.kind) filter (where r.n <= 50), '[]'::jsonb),
               coalesce(max(r.total), 0)::integer
          into rows_told, rows_waiting
          from (select f.*, row_number() over (order by f.at, f.kind) as n, count(*) over () as total
                  from public.feed_rows(who.account,
                           greatest(coalesce(told, '-infinity'), who.since, now() - interval '90 days'), now()) f
                 where ((f.kind = 'model' and who.models) or (f.kind = 'version' and who.versions)
                    or (f.kind = 'photo' and who.photos) or (f.kind = 'remix' and who.remixes))
                   and not (coalesce(f.item->>'of', f.item->>'model', '') = any (who.muted))) r;
        notices_told := '[]'::jsonb;
        notices_waiting := 0;
        if cardinality(who.kinds) > 0 then
            select coalesce(jsonb_agg(jsonb_build_object('kind', r.kind, 'at', r.at, 'on', r.model) || r.item
                                      order by r.at, r.kind) filter (where r.n <= 50), '[]'::jsonb),
                   coalesce(max(r.total), 0)::integer
              into notices_told, notices_waiting
              from (select f.*, row_number() over (order by f.at, f.kind) as n, count(*) over () as total
                      from public.notification_rows(who.account,
                               greatest(coalesce(told, '-infinity'), coalesce(who.kinds_since, '-infinity'),
                                        now() - interval '7 days'), now()) f
                     where public.notification_kind(f.kind) = any (who.kinds)
                       and not (coalesce(f.model, '') = any (who.muted))) r;
        end if;
        if ids is null and jsonb_array_length(rows_told) = 0 and jsonb_array_length(notices_told) = 0 then
            continue;
        end if;
        ids := ids[1:50];
        insert into public.comment_digests (owner, comments, feed)
        values (who.account, coalesce(array_length(ids, 1), 0), jsonb_array_length(rows_told))
        returning id into made;
        if ids is not null then
            update public.model_comments set digest = made where id = any (ids);
        end if;
        due := due || jsonb_build_array(jsonb_build_object(
            'digest', made, 'owner', who.account,
            'email', (select u.email from auth.users u where u.id = who.account),
            'test', public.trust_is_test_account(who.account),
            'more', coalesce(waiting, 0) - coalesce(array_length(ids, 1), 0),
            'comments', coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'model', k.model, 'name', m.name, 'version', k.version, 'step', k.step,
                    'body', k.body, 'at', k.at, 'by', p.name) order by k.at)
                  from public.model_comments k
                  join public.shared_models m on m.id = k.model
                  left join public.people p on p.account = k.author
                 where k.id = any (ids)), '[]'::jsonb),
            'feed', rows_told,
            'feed_more', rows_waiting - jsonb_array_length(rows_told),
            'notices', notices_told,
            'notices_more', notices_waiting - jsonb_array_length(notices_told)));
    end loop;
    return due;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Who may call what: the server alone. push_collect and claim_comment_digest
-- keep the grants they had (create or replace leaves them).

revoke all on function public.notification_kinds() from public, anon, authenticated;
revoke all on function public.notification_mailed_here() from public, anon, authenticated;
revoke all on function public.notification_kind(text) from public, anon, authenticated;
revoke all on function public.notification_group(text, text, jsonb) from public, anon, authenticated;
revoke all on function public.notification_prefs_of(uuid) from public, anon, authenticated;
grant execute on function public.notification_prefs_of(uuid) to service_role;
revoke all on function public.notification_choose(uuid, text, text, boolean) from public, anon, authenticated;
grant execute on function public.notification_choose(uuid, text, text, boolean) to service_role;
revoke all on function public.notification_mute(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.notification_mute(uuid, text, boolean) to service_role;
revoke all on function public.notification_done(uuid, text, timestamptz, boolean) from public, anon, authenticated;
grant execute on function public.notification_done(uuid, text, timestamptz, boolean) to service_role;
revoke all on function public.notification_count_kept(uuid) from public, anon, authenticated;
grant execute on function public.notification_count_kept(uuid) to service_role;
revoke all on function public.push_mark_chosen() from public, anon, authenticated, service_role;

-- A device turned on before this file was pushed comments, replies,
-- mentions (in comments and in Talk), photos, remixes, results and Talk
-- posts (api/_push.js's kinds then), which its owner chose by turning it
-- on: each such account keeps those, as its first row. Only a device turned
-- on from now starts at replies and mentions. Once: a row already there,
-- a choice made, is left as it is.
-- (A function, so its dry run can try it on a device made there.)
create or replace function public.notification_prefs_keep_devices()
returns integer
language sql
security definer
set search_path = public
as $$
    with kept as (
        insert into public.notification_prefs (account, push)
        select distinct s.account, array['comment', 'reply', 'mention', 'photo', 'remix', 'result', 'talk']
          from public.push_subscriptions s
          join auth.users u on u.id = s.account
        on conflict (account) do nothing
        returning 1)
    select count(*)::integer from kept
$$;
revoke all on function public.notification_prefs_keep_devices() from public, anon, authenticated, service_role;
select public.notification_prefs_keep_devices() as "accounts with a device kept as they were pushed";

-- Every five minutes: due, whoever chose a kind no trigger marks.
do $chosen$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        perform cron.schedule('brickworks-push-chosen', '*/5 * * * *', $job$select public.push_mark_chosen()$job$);
    end if;
end
$chosen$;

notify pgrst, 'reload schema';
