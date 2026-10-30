-- Challenges people hear of, 2026-10-30 (docs/SOCIAL.md section 7, item 3:
-- U12 finished).
--
-- A challenge opened and only somebody who opened /challenge knew; nobody
-- was reminded before it closed; a voter never heard who won. Now each is
-- a notification, read from the challenges as they are, nothing kept but
-- what was read:
--
--   challenge_open     the day it opens (or is told, if later), for every
--                      account that may enter (13 or over, asked, not
--                      taken out of the gallery), made before then; a
--                      test account hears only of a test challenge, the
--                      others only of the others
--   challenge_closing  the start of its last two days, for the same
--                      accounts, unless they entered it (none for a
--                      challenge of two days or fewer)
--   challenge_won      as it is settled, for whoever voted in it and
--                      entered nothing (an entrant hears already, as
--                      'result', under their model), saying whether a
--                      model they voted for won
--
-- Neither of the first two once the owner ended it early.
--
-- Each challenge's notices are a group of their own, read once opened:
-- challenge_reads, one row an account a challenge, and challenge_read.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the new table.
--
-- Only additions, applied after achievements.sql, whose notification_rows
-- it replaces with every row it gave and the challenges' (the guard in
-- tools/apply_sql.mjs refuses achievements.sql, replies.sql or
-- notifications.sql applied again alone): one table, deleted with its
-- account or its challenge, and functions. No row is changed, nothing
-- dropped or renamed.

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.challenge_reads (
    account    uuid not null references auth.users (id) on delete cascade,
    challenge  bigint not null references public.challenges (id) on delete cascade,
    at         timestamptz not null default now(),
    primary key (account, challenge)
);

alter table public.challenge_reads enable row level security;
revoke all on public.challenge_reads from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Told and read.

-- [viewer] opened [challenge]'s notices: read up to now. {read: true}, or
-- {refused: nobody} for no such challenge.
create or replace function public.challenge_read(viewer uuid, challenge bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if viewer is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    if not exists (select 1 from public.challenges c where c.id = challenge_read.challenge) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.challenge_reads (account, challenge, at) values (viewer, challenge_read.challenge, now())
    on conflict on constraint challenge_reads_pkey do update set at = excluded.at;
    return jsonb_build_object('read', true);
end;
$$;

-- What happened to [viewer]'s models, the replies to them and the levels
-- they reached, as achievements.sql's; and the challenges (kinds
-- challenge_open, challenge_closing and challenge_won, [model] null), each
-- [read] once its group was opened after it.
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
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.challenge_read(uuid, bigint) from public, anon, authenticated;
grant execute on function public.challenge_read(uuid, bigint) to service_role;
revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
