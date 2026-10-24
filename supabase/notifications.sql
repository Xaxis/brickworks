-- Notifications apart from the feed, 2026-10-22 (docs/SOCIAL.md U7, D10).
--
-- /feed showed two things in one list: what the people you follow made,
-- and what happened to your own work. Now the second is Notifications
-- (/notifications), and the feed is the first alone:
--
--   Notifications   what happened to your models: a comment, a photo of
--                   somebody's build, a remix listed in the gallery, likes
--                   (a number a model a day, never who), and the end of a
--                   challenge you entered (won, or see who did). Each is
--                   about one of your models, so the page groups them by
--                   model, the newest group first.
--   The feed        a model or a new version listed by somebody you
--                   follow, a photo they posted of a build of a model in
--                   the gallery (not yours: that is a notification), a
--                   model they entered in a challenge.
--
-- Both are read from the live feed_rows (challenges.sql's), split by kind,
-- so every rule of what is shown stays where it is: nothing hidden,
-- removed, taken out, or by an account under 13; a test account's only in
-- a test account's. Likes and a challenge's end are read here, from
-- model_likes and challenge_entries/challenge_winners. The last 90 days.
--
-- Seen and read, as social sites keep them:
--
--   seen   opening /notifications clears the count on your avatar (what
--          came since you last opened it); opening /feed clears the feed's
--   read   a notification stays marked until you open it (its model's
--          group, read up to then) or Mark all read
--
--   notification_marks   one row an account: when it last opened its
--                        notifications (seen_at), and when it last marked
--                        all read (read_at)
--   notification_reads   one row an account a model: read up to when
--
-- Before an account has a row of notification_marks, its marks are its
-- feed's (feed_marks.seen_at): what it saw in the feed of before, which
-- showed these too, is seen and read. The first time anything here marks
-- the feed or the notifications, that is written down as its own, so
-- opening the new /feed never marks a notification.
--
-- The feed's old functions stay as they are (feed_rows, feed_of,
-- feed_count): the app of before asks for feed_count, and the day's email
-- (claim_comment_digest) for feed_rows; its choices are unchanged.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the new tables.
--
-- Only additions, applied after follows.sql and challenges.sql (it reads
-- feed_rows, feed_marks, model_likes, challenge_entries, challenge_winners):
-- two new tables, each deleted with its account (and a read with its
-- model), and new functions. No existing row is changed, no function
-- replaced, nothing dropped or renamed.

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.notification_marks (
    account  uuid primary key references auth.users (id) on delete cascade,
    seen_at  timestamptz,
    read_at  timestamptz,
    at       timestamptz not null default now()
);

create table if not exists public.notification_reads (
    account  uuid not null references auth.users (id) on delete cascade,
    model    text not null references public.shared_models (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (account, model)
);

alter table public.notification_marks enable row level security;
alter table public.notification_reads enable row level security;
revoke all on public.notification_marks from public, anon, authenticated, service_role;
revoke all on public.notification_reads from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The rows.

-- What happened to [viewer]'s models from after [since] up to [until], as
-- (kind, at, model, item): [model] is the viewer's model it is about (for
-- a remix, the one remixed), [item] what the page says of it. Comments,
-- photos and remixes as feed_rows reads them; likes a row a model a day
-- (UTC), its time the newest like's, never who; a challenge's end a row
-- for each of their entries once it is settled.
-- REPLACED LATER: replies.sql replaces this function (replies to a comment,
-- shown only under it). Apply replies.sql again right after this file:
-- tools/apply_sql.mjs refuses it alone, unless --again=supabase/replies.sql.
create or replace function public.notification_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, model text, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with mine as (
        select m.id, m.name from public.shared_models m
         where m.owner = viewer and m.published and not m.barred)
    select f.kind, f.at, case when f.kind = 'remix' then f.item->>'of' else f.item->>'model' end, f.item
      from public.feed_rows(viewer, since, until) f
     where f.kind in ('comment', 'remix') or (f.kind = 'photo' and (f.item->>'yours')::boolean)
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
$$;

-- What the people [viewer] follows made, from after [since] up to [until]:
-- feed_rows without what notification_rows tells.
-- REPLACED LATER: collection_follows.sql replaces this function (the
-- collections followed, too). Apply collection_follows.sql again right after
-- this file: tools/apply_sql.mjs refuses it alone, unless
-- --again=supabase/collection_follows.sql.
create or replace function public.follow_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    select f.kind, f.at, f.item
      from public.feed_rows(viewer, since, until) f
     where f.kind in ('model', 'version', 'challenge')
        or (f.kind = 'photo' and not (f.item->>'yours')::boolean)
$$;

-- ---------------------------------------------------------------------------
-- Seen and read.

-- [viewer]'s marks: their own once they have a row, else their feed's.
create or replace function public.notification_marks_of(viewer uuid)
returns table (seen_at timestamptz, read_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
    select case when n.account is null then k.seen_at else n.seen_at end,
           case when n.account is null then k.seen_at else n.read_at end
      from (select viewer as account) v
      left join public.notification_marks n on n.account = v.account
      left join public.feed_marks k on k.account = v.account
$$;

-- The row of notification_marks for [viewer], made from the feed's marks
-- when there is none, so a later opening of the feed does not move it.
create or replace function public.notification_marks_kept(viewer uuid)
returns void
language sql
security definer
set search_path = public
as $$
    insert into public.notification_marks (account, seen_at, read_at)
    select viewer, k.seen_at, k.seen_at
      from (select viewer as account) v
      left join public.feed_marks k on k.account = v.account
    on conflict on constraint notification_marks_pkey do nothing
$$;

-- [viewer]'s notifications of the last 90 days, newest first, at most
-- 200: {rows: [{kind, at, on, ...item}], models: {id: {name, has_image,
-- has_thumb, updated_at}}, seen_at, read_at, reads: {model: at}}. [on] is
-- the model a row is about. With [mark], they count as opened now:
-- seen_at says when they were opened before, so the page can say which
-- are new. Null for nobody.
create or replace function public.notification_list(viewer uuid, mark boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    seen timestamptz;
    readall timestamptz;
    got jsonb;
begin
    if viewer is null then
        return null;
    end if;
    select s.seen_at, s.read_at into seen, readall from public.notification_marks_of(viewer) s;
    select coalesce(jsonb_agg(jsonb_build_object('kind', r.kind, 'at', r.at, 'on', r.model) || r.item
                              order by r.at desc, r.kind), '[]'::jsonb)
      into got
      from (select * from public.notification_rows(viewer, now() - interval '90 days', now()) f
             order by f.at desc, f.kind limit 200) r;
    if mark then
        perform public.notification_marks_kept(viewer);
        update public.notification_marks n set seen_at = now(), at = now() where n.account = viewer;
    end if;
    return jsonb_build_object(
        'rows', got,
        'models', coalesce((select jsonb_object_agg(m.id, jsonb_build_object('name', m.name,
                                'has_image', m.has_image, 'has_thumb', m.has_thumb, 'updated_at', m.updated_at))
                              from public.shared_models m
                             where m.id in (select x->>'on' from jsonb_array_elements(got) x)), '{}'::jsonb),
        'seen_at', seen,
        'read_at', readall,
        'reads', coalesce((select jsonb_object_agg(d.model, d.at) from public.notification_reads d
                            where d.account = viewer), '{}'::jsonb));
end;
$$;

-- [viewer] read what is about [model] (one of theirs), up to now; with no
-- model, everything (Mark all read), which also clears the count. {read}
-- true, or {refused: nobody} for a model not theirs.
-- REPLACED LATER: replies.sql replaces this function (replies to a comment,
-- shown only under it). Apply replies.sql again right after this file:
-- tools/apply_sql.mjs refuses it alone, unless --again=supabase/replies.sql.
create or replace function public.notification_read(viewer uuid, model text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if viewer is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    perform public.notification_marks_kept(viewer);
    if model is null then
        update public.notification_marks n set read_at = now(), seen_at = now(), at = now()
         where n.account = viewer;
        delete from public.notification_reads d where d.account = viewer;
        return jsonb_build_object('read', true);
    end if;
    if not exists (select 1 from public.shared_models m
                    where m.id = notification_read.model and m.owner = viewer) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.notification_reads (account, model, at) values (viewer, notification_read.model, now())
    on conflict on constraint notification_reads_pkey do update set at = excluded.at;
    return jsonb_build_object('read', true);
end;
$$;

-- What is new for [viewer]: {notifications, feed}, each how many rows came
-- since it was last opened (or in the last 90 days, never opened), at
-- most 99. The avatar's count is the two together.
create or replace function public.notification_counts(viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'notifications', (select count(*)::integer from (select 1 from public.notification_rows(viewer,
            greatest(coalesce((select s.seen_at from public.notification_marks_of(viewer) s), '-infinity'),
                     now() - interval '90 days'), now()) limit 99) r),
        'feed', (select count(*)::integer from (select 1 from public.follow_rows(viewer,
            greatest(coalesce((select k.seen_at from public.feed_marks k where k.account = viewer), '-infinity'),
                     now() - interval '90 days'), now()) limit 99) r))
     where viewer is not null
$$;

-- A page of [viewer]'s feed, as follows.sql's feed_of, of follow_rows:
-- {rows, more, seen_at}. With [mark], the feed counts as opened now; the
-- notifications' marks are written down as their own first.
create or replace function public.follow_page(viewer uuid, before timestamptz default null,
                                              size integer default 30, mark boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    wanted integer := least(greatest(coalesce(size, 30), 1), 50);
    seen timestamptz;
    listed jsonb;
    more boolean;
begin
    if viewer is null then
        return null;
    end if;
    select k.seen_at into seen from public.feed_marks k where k.account = viewer;
    select coalesce(jsonb_agg(r.item || jsonb_build_object('kind', r.kind, 'at', r.at)
                              order by r.at desc, r.kind), '[]'::jsonb),
           count(*) > wanted
      into listed, more
      from (select * from public.follow_rows(viewer, now() - interval '90 days', coalesce(before, now())) f
             where before is null or f.at < before
             order by f.at desc, f.kind limit wanted + 1) r;
    if jsonb_array_length(listed) > wanted then
        listed := listed - wanted;
    end if;
    if mark then
        perform public.notification_marks_kept(viewer);
        insert into public.feed_marks (account, seen_at) values (viewer, now())
        on conflict on constraint feed_marks_pkey do update set seen_at = excluded.seen_at;
    end if;
    return jsonb_build_object('rows', listed, 'more', more, 'seen_at', seen);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.follow_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.follow_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.notification_marks_of(uuid) from public, anon, authenticated;
grant execute on function public.notification_marks_of(uuid) to service_role;
revoke all on function public.notification_marks_kept(uuid) from public, anon, authenticated;
grant execute on function public.notification_marks_kept(uuid) to service_role;
revoke all on function public.notification_list(uuid, boolean) from public, anon, authenticated;
grant execute on function public.notification_list(uuid, boolean) to service_role;
revoke all on function public.notification_read(uuid, text) from public, anon, authenticated;
grant execute on function public.notification_read(uuid, text) to service_role;
revoke all on function public.notification_counts(uuid) from public, anon, authenticated;
grant execute on function public.notification_counts(uuid) to service_role;
revoke all on function public.follow_page(uuid, timestamptz, integer, boolean) from public, anon, authenticated;
grant execute on function public.follow_page(uuid, timestamptz, integer, boolean) to service_role;
