-- @mentions in comments, 2026-10-30 (docs/SOCIAL.md section 7, item 6).
--
-- A comment could only reach the model's designer and the people in its
-- conversation. Now it can name somebody else, as @their-handle: they are
-- told in Notifications, and the page links the name to their profile.
--
--   comment_mentions  (comment, account, at): who [comment] named, at most
--                     three a comment however often it is changed; each a
--                     profile shown in public, 13 or over, not its writer.
--                     Deleted with the comment or the account.
--
--   comment_mention(account, comment_id, handles)   its writer's comment
--                     names [handles] (the API reads them from its words,
--                     as written or edited): {mentioned: [{handle, name}]},
--                     every one it names now, or {refused: no_comment |
--                     not_yours | under_13}
--   comment_mentions_of(comment_ids)                who each names, while
--                     they are shown in public: (comment, handle, name)
--   notification_rows  achievements.sql's and challenge_notices.sql's rows,
--                     and 'mention': a comment or reply naming the viewer,
--                     unless they hear it already (their own model's
--                     comment, a reply in their conversation), hidden as
--                     a reply is
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the new table.
--
-- Only additions, applied after challenge_notices.sql, whose
-- notification_rows it replaces with every row it gave and the mentions'
-- (the guard in tools/apply_sql.mjs refuses challenge_notices.sql,
-- achievements.sql, replies.sql or notifications.sql applied again alone):
-- one table and functions. No row of another table is changed, nothing
-- dropped or renamed.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/comment_mentions.sql --table=comment_mentions
--
-- Dry run, made-up accounts in a rolled-back transaction (with the files
-- before it while they are not applied):
--
--   ... node tools/apply_sql.mjs supabase/achievements.sql \
--     --again=supabase/challenge_notices.sql,supabase/comment_mentions.sql \
--     --dry --try=tools/comment_mentions_try.sql --table=comment_mentions

-- ---------------------------------------------------------------------------
-- The table.

create table if not exists public.comment_mentions (
    comment  bigint not null references public.model_comments (id) on delete cascade,
    account  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (comment, account)
);
create index if not exists comment_mentions_account on public.comment_mentions (account, at desc);

alter table public.comment_mentions enable row level security;
revoke all on public.comment_mentions from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Named, and said.

-- Who [comment_id] names, while each is shown in public: [{handle, name}],
-- in the order they were named.
create or replace function public.comment_mentions_said(comment_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('handle', p.handle, 'name', p.name) order by n.at, p.handle), '[]'::jsonb)
      from public.comment_mentions n
      join public.people p on p.account = n.account
     where n.comment = comment_mentions_said.comment_id and public.shown_publicly(n.account)
$$;

-- [account]'s comment [comment_id] names [handles]: each a profile shown
-- in public, 13 or over, not its writer, is kept, at most three a comment
-- however often it is edited, in the order named. A writer taken out of
-- the gallery names nobody. {mentioned}, or {refused}.
create or replace function public.comment_mention(account uuid, comment_id bigint, handles text[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.model_comments;
    room integer;
begin
    select * into c from public.model_comments k where k.id = comment_mention.comment_id and k.removed_at is null;
    if not found or account is null then
        return jsonb_build_object('refused', 'no_comment');
    end if;
    if c.author <> comment_mention.account then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    if not public.trust_may_go_public(comment_mention.account) then
        return jsonb_build_object('refused', 'under_13');
    end if;
    room := 3 - (select count(*) from public.comment_mentions n where n.comment = c.id);
    if room > 0 and not public.is_barred(comment_mention.account) then
        insert into public.comment_mentions (comment, account, at)
        select c.id, p.account, now() + make_interval(secs => h.at / 1000.0)
          from unnest((coalesce(handles, '{}'))[1:12]) with ordinality h(handle, at)
          join public.people p on p.handle = lower(h.handle)
         where p.account <> comment_mention.account
           and public.shown_publicly(p.account) and public.trust_may_go_public(p.account)
           and not exists (select 1 from public.comment_mentions n where n.comment = c.id and n.account = p.account)
         order by h.at
         limit room
        on conflict do nothing;
    end if;
    return jsonb_build_object('mentioned', public.comment_mentions_said(c.id));
end;
$$;

-- Who each of [comment_ids] names, while they are shown in public:
-- (comment, handle, name), in the order named.
create or replace function public.comment_mentions_of(comment_ids bigint[])
returns table (comment bigint, handle text, name text)
language sql
stable
security definer
set search_path = public
as $$
    select n.comment, p.handle, p.name
      from public.comment_mentions n
      join public.people p on p.account = n.account
     where n.comment = any (comment_ids) and public.shown_publicly(n.account)
     order by n.comment, n.at, p.handle
$$;

-- ---------------------------------------------------------------------------
-- Told.

-- What happened to [viewer]'s models, the replies to them, the levels
-- they reached and the challenges, as challenge_notices.sql's; and each
-- comment or reply that names them (kind 'mention').
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
$$;

-- ---------------------------------------------------------------------------
-- Who may run what.

revoke all on function public.comment_mentions_said(bigint) from public, anon, authenticated;
grant execute on function public.comment_mentions_said(bigint) to service_role;
revoke all on function public.comment_mention(uuid, bigint, text[]) from public, anon, authenticated;
grant execute on function public.comment_mention(uuid, bigint, text[]) to service_role;
revoke all on function public.comment_mentions_of(bigint[]) from public, anon, authenticated;
grant execute on function public.comment_mentions_of(bigint[]) to service_role;
revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
