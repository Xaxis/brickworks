-- Your own work in your own feed, 2026-11-26 (feedself, from sitewalk3's
-- walk of a newcomer's first day).
--
-- A new member listed their first build and went to their feed, and it
-- was not there: the feed (follow_page, of follow_rows) is what the people
-- you follow made, and nobody follows themselves. On every social site
-- your own post is in your feed at once; its absence reads as "it didn't
-- work".
--
--   own_rows(viewer, since, until)   [viewer]'s own work as feed rows,
--                                    each marked mine: a model they listed
--                                    in the gallery (credited or not:
--                                    'credited' says which), a newer
--                                    version of one, a version finished
--                                    later, a photo they posted of a build,
--                                    and a model they entered in a
--                                    challenge
--   own_page(viewer, before, size)   a page of those, newest first, as
--                                    follow_page gives its own: {rows, more}
--
-- api/_follows.js asks own_page beside follow_page and puts the two pages
-- together in time order. Nothing here is anybody else's: every row is the
-- viewer's own, and only what is in the gallery (listed, not taken out) or
-- a photo of theirs still up. Their unlisted and link-only models are not
-- in it either. A row of their own is never New and is never counted on
-- the avatar: feed_new_count is not changed, and api/_follows.js isNew
-- says no to a row marked mine. While this file is not applied the feed is
-- as before.
--
-- Only an addition, applied after follows.sql, notifications.sql, wip.sql
-- and challenges.sql (it reads their tables and wip_said, feed_who and
-- trust_is_test_account): two new functions, security definer and granted
-- to the service role alone, as the tables they read are. No table, row or
-- function of before is changed, nothing dropped or renamed.

create or replace function public.own_rows(viewer uuid, since timestamptz, until timestamptz)
returns table(kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with tests as (
        select public.trust_is_test_account(viewer) as ok)
    -- A model the viewer listed in the gallery, with their name on it or
    -- without (then nobody else's feed has it: feed_rows wants an author).
    select 'model'::text, m.listed_at,
           jsonb_build_object('model', m.id, 'name', m.name, 'parts', m.parts, 'by', public.feed_who(m.owner),
                              'mine', true, 'credited', m.author is not null)
             || public.wip_said(m.id, null, m.listed_at)
      from public.shared_models m
     cross join tests t
     where m.owner = viewer and m.published and m.listed and not m.barred
       and (not m.test or t.ok)
       and m.listed_at > since and m.listed_at <= until
    union all
    -- A newer version of one of those, published after it was listed.
    select 'version'::text, v.at,
           jsonb_build_object('model', m.id, 'name', m.name, 'version', v.n, 'note', v.note,
                              'by', public.feed_who(m.owner), 'mine', true)
             || public.wip_said(m.id, v.n, v.at)
      from public.shared_models m
      join public.share_versions v on v.model = m.id and v.n > 1 and v.at > m.listed_at
     cross join tests t
     where m.owner = viewer and m.published and m.listed and not m.barred
       and (not m.test or t.ok)
       and v.at > since and v.at <= until
    union all
    -- A version marked finished after it was shared (wip_rows' rule).
    select 'version'::text, v.finished_at,
           jsonb_build_object('model', m.id, 'name', m.name, 'version', v.n, 'note', v.note,
                              'wip', v.wip, 'finished', true, 'later', true, 'by', public.feed_who(m.owner),
                              'mine', true)
      from public.share_versions v
      join public.shared_models m on m.id = v.model
     cross join tests t
     where m.owner = viewer and v.finished_at is not null and v.finished_at > v.at
       and m.published and m.listed and not m.barred
       and (not m.test or t.ok)
       and v.finished_at > m.listed_at
       and v.finished_at > since and v.finished_at <= until
    union all
    -- A photo the viewer posted of a build: of their own model, or of a
    -- model in the gallery (feed_rows' rule for a photo by somebody
    -- followed). Not one hidden or taken down.
    select 'photo'::text, b.at,
           jsonb_build_object('photo', b.id, 'model', b.model, 'name', m.name, 'words', b.words,
                              'yours', false, 'by', public.feed_who(b.account), 'mine', true)
      from public.build_photos b
      join public.shared_models m on m.id = b.model
     cross join tests t
     where b.account = viewer and b.removed_at is null and b.hidden_at is null
       and m.published and not m.barred
       and (m.owner = viewer or (m.listed and (not m.test or t.ok)))
       and b.at > since and b.at <= until
    union all
    -- A model of theirs entered in a challenge (challenges.sql), listed;
    -- a test challenge's only in a test account's feed.
    select 'challenge'::text, e.at,
           jsonb_build_object('model', m.id, 'name', m.name, 'challenge', c.id, 'title', c.title,
                              'way', e.way, 'by', public.feed_who(m.owner), 'mine', true)
      from public.challenge_entries e
      join public.challenges c on c.id = e.challenge
      join public.shared_models m on m.id = e.model
     cross join tests t
     where e.owner = viewer and m.owner = viewer
       and m.published and m.listed and not m.barred
       and (not m.test or t.ok) and (not c.test or t.ok)
       and e.at > since and e.at <= until
$$;

-- A page of [viewer]'s own rows, the last 90 days as the feed's, newest
-- first: {rows, more}. Marks nothing (follow_page marks the feed opened).
create or replace function public.own_page(viewer uuid, before timestamptz default null, size integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with page as (
        select o.kind, o.at, o.item
          from public.own_rows(viewer, now() - interval '90 days', coalesce(before, now())) o
         where before is null or o.at < before
         order by o.at desc, o.kind
         limit least(greatest(coalesce(size, 30), 1), 50) + 1),
    numbered as (
        select p.*, row_number() over (order by p.at desc, p.kind) as n from page p)
    select jsonb_build_object(
        'rows', coalesce((select jsonb_agg(r.item || jsonb_build_object('kind', r.kind, 'at', r.at)
                                           order by r.at desc, r.kind)
                            from numbered r where r.n <= least(greatest(coalesce(size, 30), 1), 50)), '[]'::jsonb),
        'more', (select count(*) from page) > least(greatest(coalesce(size, 30), 1), 50))
     where viewer is not null
$$;

revoke all on function public.own_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.own_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.own_page(uuid, timestamptz, integer) from public, anon, authenticated;
grant execute on function public.own_page(uuid, timestamptz, integer) to service_role;
