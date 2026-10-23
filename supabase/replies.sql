-- Replies to a comment, 2026-10-22 (docs/SOCIAL.md U8, comments that talk).
--
-- A comment could only be answered by another comment under everybody
-- else's, oldest first, so a conversation was buried as soon as it began.
-- Now a comment can be answered: one level of replies, the newest thread
-- first on a model's page and its replies oldest first under it. A reply
-- is a comment like any other (comments.sql), kept in model_comments with
-- the comment it answers, so every rule of comments.sql holds for it as
-- written: who may write (13 or over, not barred, the model open, its owner
-- not under 13), how often (a reply counts as a comment: 10 an hour, 50 a
-- day), what (1 to 1,000 characters of plain text), and moderation (its
-- author edits or removes it, the model's owner hides it, anybody reports
-- it, the site's owner removes it).
--
--   model_comments.parent   the comment a reply answers, or null for a
--                           comment of its own. A reply is on its comment's
--                           model, version and step, and answers a comment,
--                           never a reply: a reply to a reply joins its
--                           thread (add_reply). Gone with its comment: an
--                           account deleted takes its comments, and the
--                           replies to them, with it.
--
-- A reply lives under its comment. It is shown only where its comment is:
-- a comment hidden by the model's owner, removed by its author or by the
-- site's owner, or by an account taken out of the gallery or under 13,
-- takes its replies with it, from the page, the cards' counts, a
-- designer's numbers, the day's email and the notifications. The model's
-- owner and the hidden comment's author still see the thread, marked, as
-- they see a hidden comment. Nothing is written to a reply when its
-- comment is hidden: showing the comment again shows its replies again.
--
-- And a reply reaches the person it answers: notification_rows tells the
-- author of a comment of each reply to it (kind 'reply'), and whoever
-- replied in that thread of each reply after theirs, on their own model or
-- anybody's, grouped under the model it is on.
--
-- Functions replaced with new versions, each as it was but for what is
-- said beside it:
--
--   comments_guard         a reply's comment is on the same model, version
--                          and step, and is not itself a reply; a reply
--                          stays under its comment
--   comment_as             says parent
--   comments_on            the newest 500 threads and their replies (was
--                          the newest 500 comments), a reply only under a
--                          comment the asker is shown; says threads: true,
--                          so the API knows replies can be written
--   admin_comments         says parent
--   notification_rows      (notifications.sql) the replies, and nothing
--                          under a comment no longer shown
--   notification_read      a group of a model the viewer commented on
--   claim_comment_digest   (follows.sql) nothing under a comment no
--                          longer shown
--   designer_said          (designers.sql) the same
--   directory_card         (gallery_tabs.sql) the same, in its comments
--
-- And new: add_reply, and comment_parent_shown, the one rule.
--
-- Who may touch what is as it was: the server, through the functions, each
-- security definer and granted to the service role alone. Only additions,
-- applied after comments.sql, follows.sql, challenges.sql, designers.sql,
-- gallery_tabs.sql and notifications.sql (it replaces their functions; the
-- guard in tools/apply_sql.mjs refuses any of them applied again alone): a
-- nullable column and its index, functions, the trigger's function. No row
-- is changed, nothing dropped or renamed. Apply it before the code that
-- writes replies is deployed; until then the API says replies are not
-- open yet, and the page shows none.

-- ---------------------------------------------------------------------------
-- The column.

alter table public.model_comments
    add column if not exists parent bigint references public.model_comments (id) on delete cascade;
create index if not exists model_comments_parent on public.model_comments (parent) where parent is not null;

-- ---------------------------------------------------------------------------
-- The rule: a reply is shown only where its comment is.

-- Whether a comment that [parent_id] names (a reply's) is shown to
-- anybody: not removed, not hidden, by an account shown in public. True
-- for none (a comment of its own).
create or replace function public.comment_parent_shown(parent_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select parent_id is null or exists (
        select 1 from public.model_comments p
         where p.id = parent_id and p.removed_at is null and p.hidden_at is null
           and public.shown_publicly(p.author))
$$;

-- The refusals, whatever writes, as comments.sql's, and a reply's place: on
-- its comment's model, version and step, under a comment that is not
-- itself a reply, and kept there.
create or replace function public.comments_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.model_comments;
begin
    if tg_op = 'UPDATE' and new.parent is distinct from old.parent then
        raise exception 'brickworks: a reply stays under its comment'
            using errcode = 'P0001', hint = 'comments:parent';
    end if;
    if tg_op = 'INSERT' and new.parent is not null then
        select * into p from public.model_comments k where k.id = new.parent;
        if not found or p.parent is not null or p.model <> new.model or p.version <> new.version
           or p.step is distinct from new.step then
            raise exception 'brickworks: a reply answers a comment on the same model and step, one level deep'
                using errcode = 'P0001', hint = 'comments:parent';
        end if;
    end if;
    if tg_op = 'INSERT' or new.body is distinct from old.body then
        if not public.trust_may_go_public(new.author) then
            raise exception 'brickworks: comments are for accounts 13 or over'
                using errcode = 'P0001', hint = 'comments:age';
        end if;
        if public.is_barred(new.author) then
            raise exception 'brickworks: this account was taken out of the gallery'
                using errcode = 'P0001', hint = 'comments:barred';
        end if;
        if not public.comments_open(new.model) then
            raise exception 'brickworks: comments are off on this model'
                using errcode = 'P0001', hint = 'comments:closed';
        end if;
    end if;
    return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- What a comment says, and to whom.

-- A comment as an answer gives it, as comments.sql's, and the comment it
-- answers (parent), or null.
create or replace function public.comment_as(c public.model_comments, asker uuid, owner uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', c.id, 'version', c.version, 'step', c.step, 'body', c.body,
        'at', c.at, 'edited_at', c.edited_at,
        'hidden', c.hidden_at is not null,
        'mine', asker is not null and c.author = asker,
        'by_owner', c.author = owner,
        'by', p.name, 'handle', p.handle,
        'parent', c.parent)
      from (select 1) as one
      left join public.people p on p.account = c.author
$$;

-- What a model's page and its viewer show: {open, owner, comments,
-- threads}, the comments oldest first (the viewer lists them so; the page
-- puts the newest thread first): the newest 500 threads, each a comment
-- and its replies. Hidden ones only to their author and the model's owner;
-- removed ones, and those of an account barred or under 13, to nobody; a
-- reply only to whom its comment is shown. threads: true says replies are
-- kept here. Null for a model not published.
create or replace function public.comments_on(model_id text, asker uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    since timestamptz;
    listed jsonb;
begin
    select * into m from public.shared_models s where s.id = model_id and s.published;
    if not found then
        return null;
    end if;
    -- This life of the link: from its first version, which a takedown and
    -- a share again begins anew.
    select min(v.at) into since from public.share_versions v where v.model = model_id;
    with seen as (
        select k.id, k.parent, k.at from public.model_comments k
         where k.model = model_id and k.removed_at is null
           and (since is null or k.at >= since)
           and (k.hidden_at is null or (asker is not null and (k.author = asker or m.owner = asker)))
           and public.shown_publicly(k.author)),
    threads as (
        select s.id from seen s where s.parent is null order by s.at desc, s.id desc limit 500)
    select coalesce(jsonb_agg(public.comment_as(c, asker, m.owner) order by c.at, c.id), '[]'::jsonb)
      into listed
      from public.model_comments c
     where c.id in (select s.id from seen s
                     where s.id in (select t.id from threads t) or s.parent in (select t.id from threads t));
    return jsonb_build_object('open', public.comments_open(model_id),
        'owner', asker is not null and asker = m.owner, 'comments', listed, 'threads', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing a reply.

-- A reply from [account] to comment [comment_id]: {comment} as comment_as
-- gives it, its model and the model's owner, or {refused}: comment_trouble's reasons
-- on its model, no_comment (none, removed, hidden, by an account not
-- shown, or of the link's life before), body and limit, as add_comment
-- says them. A reply to a reply answers its comment, in the same thread.
-- It is on its comment's version and step, wherever it was written from.
create or replace function public.add_reply(account uuid, comment_id bigint, said text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.model_comments;
    since timestamptz;
    trouble text;
    owner_of uuid;
    made public.model_comments;
begin
    if account is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    select * into p from public.model_comments k where k.id = comment_id and k.removed_at is null;
    if found and p.parent is not null then
        select * into p from public.model_comments k where k.id = p.parent and k.removed_at is null;
    end if;
    if not found then
        return jsonb_build_object('refused', 'no_comment');
    end if;
    trouble := public.comment_trouble(account, p.model);
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    -- Only to a comment its page shows everybody.
    select min(v.at) into since from public.share_versions v where v.model = p.model;
    if p.hidden_at is not null or not public.shown_publicly(p.author) or (since is not null and p.at < since) then
        return jsonb_build_object('refused', 'no_comment');
    end if;
    if said is null or char_length(said) not between 1 and 1000 or said !~ '[^[:space:]]'
       or said ~ '[\x01-\x09\x0b-\x1f\x7f]' then
        return jsonb_build_object('refused', 'body');
    end if;
    if not public.may_act(account::text, 'comment', 10, 50) then
        return jsonb_build_object('refused', 'limit');
    end if;
    insert into public.model_comments (model, version, step, author, body, parent)
    values (p.model, p.version, p.step, account, said, p.id)
    returning * into made;
    select s.owner into owner_of from public.shared_models s where s.id = p.model;
    return jsonb_build_object('comment', public.comment_as(made, account, owner_of), 'owner', owner_of,
        'model', p.model);
end;
$$;

-- ---------------------------------------------------------------------------
-- The site's owner.

-- Comments for the admin page, as comments.sql's, and the comment each
-- reply answers.
create or replace function public.admin_comments(wanted bigint[] default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
               'id', c.id, 'model', c.model, 'name', m.name, 'version', c.version, 'step', c.step,
               'body', c.body, 'at', c.at, 'edited_at', c.edited_at, 'hidden_at', c.hidden_at,
               'removed_at', c.removed_at, 'removed_by', c.removed_by, 'author', c.author,
               'handle', p.handle, 'parent', c.parent) order by c.at desc), '[]'::jsonb)
      from (select * from public.model_comments k
             where wanted is null or k.id = any (wanted)
             order by k.at desc limit 200) c
      join public.shared_models m on m.id = c.model
      left join public.people p on p.account = c.author
$$;

-- ---------------------------------------------------------------------------
-- Notifications (notifications.sql's), with the replies.

-- What happened to [viewer]'s models, as notifications.sql's, and the
-- replies in the conversations they are in: under their own comment, or
-- under one they replied to, from their first reply on (kind 'reply',
-- [yours] whether the comment answered is theirs), on their own model or
-- anybody's, [model] the model it is on. A comment row says the comment it
-- answers (parent), if any; one under a comment no longer shown is not
-- told.
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
$$;

-- [viewer] read what is about [model], as notifications.sql's: one of
-- theirs, or now one they commented on (where replies to them are).
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
                    where m.id = notification_read.model and m.owner = viewer)
       and not exists (select 1 from public.model_comments k
                        where k.model = notification_read.model and k.author = viewer) then
        return jsonb_build_object('refused', 'nobody');
    end if;
    insert into public.notification_reads (account, model, at) values (viewer, notification_read.model, now())
    on conflict on constraint notification_reads_pkey do update set at = excluded.at;
    return jsonb_build_object('read', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- The day's email (follows.sql's): nothing under a comment no longer shown.

create or replace function public.claim_comment_digest(for_owner uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    who record;
    ids bigint[];
    waiting integer;
    told timestamptz;
    rows_told jsonb;
    rows_waiting integer;
    made bigint;
    due jsonb := '[]'::jsonb;
begin
    for who in
        select c.account, c.at as since, c.comments, c.models, c.versions, c.photos, c.remixes
          from public.mail_choices c
         where (c.comments or c.models or c.versions or c.photos or c.remixes)
           and (for_owner is null or c.account = for_owner)
           and not exists (select 1 from public.comment_digests d
                            where d.owner = c.account and d.state <> 'failed'
                              and d.at > now() - interval '1 day')
         order by c.account
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
                 where (f.kind = 'model' and who.models) or (f.kind = 'version' and who.versions)
                    or (f.kind = 'photo' and who.photos) or (f.kind = 'remix' and who.remixes)) r;
        if ids is null and jsonb_array_length(rows_told) = 0 then
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
            'feed_more', rows_waiting - jsonb_array_length(rows_told)));
    end loop;
    return due;
end;
$$;

-- ---------------------------------------------------------------------------
-- The counts: a designer's numbers (designers.sql's) and a card's comments
-- (gallery_tabs.sql's directory_card), nothing under a comment no longer shown.

create or replace function public.designer_said(model_ids text[], since timestamptz default null)
returns table (model text, comments bigint, recent bigint)
language sql
stable
security definer
set search_path = public
as $$
    -- Each writer asked once whether they are shown, and each model once
    -- when its link's life began.
    -- (Kept apart, or the planner asks it of every comment before the
    -- distinct: 0.1 ms each.)
    with writers as materialized (
        select distinct k.author from public.model_comments k
         where k.model = any (designer_said.model_ids)),
    shown as materialized (
        select w.author from writers w where public.shown_publicly(w.author)),
    lives as materialized (
        select v.model, min(v.at) as at
          from public.share_versions v
         where v.model = any (designer_said.model_ids)
         group by v.model)
    select c.model, count(*), count(*) filter (where designer_said.since is not null and c.at >= designer_said.since)
      from public.model_comments c
      join public.shared_models m on m.id = c.model
      left join lives l on l.model = c.model
     where c.model = any (designer_said.model_ids)
       and c.removed_at is null and c.hidden_at is null
       and c.author <> m.owner
       and c.at >= coalesce(l.at, '-infinity'::timestamptz)
       and c.author in (select s.author from shown s)
       and public.comment_parent_shown(c.parent)
     group by c.model
$$;

create or replace function public.directory_card(m public.shared_models)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', m.id, 'name', m.name, 'author', m.author, 'parts', m.parts,
        'has_image', m.has_image, 'has_thumb', m.has_thumb,
        'listed_at', m.listed_at, 'updated_at', m.updated_at,
        'kind', m.kind, 'tags', to_jsonb(m.tags), 'licence', m.licence,
        'steps', m.steps, 'own_steps', m.own_steps, 'technic', m.technic,
        'views', coalesce(s.views, 0), 'likes', coalesce(s.likes, 0),
        'builds', coalesce(s.builds, 0),
        'remixes', (select count(*) from public.shared_models r
                     where r.remixed_from = m.id and r.published),
        'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                 from public.people p
                where p.account = m.owner and m.author is not null
                  and not public.trust_kept_private(m.owner)),
        'tested', public.model_tested(m.id),
        'moves', to_jsonb(m.moves),
        'motions', to_jsonb(m.motions),
        -- What a visitor may read on its page (comments_on, asked by nobody).
        'comments', (select count(*) from public.model_comments k
                      where k.model = m.id and k.removed_at is null and k.hidden_at is null
                        and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = m.id),
                                             '-infinity'::timestamptz)
                        and public.shown_publicly(k.author)
                        and public.comment_parent_shown(k.parent)))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.comment_parent_shown(bigint) from public, anon, authenticated;
grant execute on function public.comment_parent_shown(bigint) to service_role;
revoke all on function public.comments_guard() from public, anon, authenticated;
revoke all on function public.comment_as(public.model_comments, uuid, uuid) from public, anon, authenticated;
grant execute on function public.comment_as(public.model_comments, uuid, uuid) to service_role;
revoke all on function public.comments_on(text, uuid) from public, anon, authenticated;
grant execute on function public.comments_on(text, uuid) to service_role;
revoke all on function public.add_reply(uuid, bigint, text) from public, anon, authenticated;
grant execute on function public.add_reply(uuid, bigint, text) to service_role;
revoke all on function public.admin_comments(bigint[]) from public, anon, authenticated;
grant execute on function public.admin_comments(bigint[]) to service_role;
revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.notification_read(uuid, text) from public, anon, authenticated;
grant execute on function public.notification_read(uuid, text) to service_role;
revoke all on function public.claim_comment_digest(uuid) from public, anon, authenticated;
grant execute on function public.claim_comment_digest(uuid) to service_role;
revoke all on function public.designer_said(text[], timestamptz) from public, anon, authenticated;
grant execute on function public.designer_said(text[], timestamptz) to service_role;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
