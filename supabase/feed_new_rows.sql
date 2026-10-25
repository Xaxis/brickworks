-- When each of the follows that fill a feed began, so the feed marks New
-- only what came after it, 2026-10-25 (walk256's W7).
--
-- follow_counts.sql and list_follow_counts.sql made the count on the
-- avatar count only what came after the follow that brought each row: a
-- new follow's backlog is in the feed to read, and none of it is new. The
-- feed itself still marked a row New when it came after the feed was last
-- opened (follow_page's seen_at), or every row of a feed never opened: a
-- new account followed the house in First steps, and its feed marked the
-- house's day-old versions New.
--
--   feed_followed_at(viewer)   when [viewer] followed each person and each
--                              collection they follow: {people: {handle:
--                              at}, collections: {id: at}}
--
-- api/_follows.js reads it beside follow_page and marks a row New only
-- when it came after the feed was last opened and after the follow that
-- brought it, the way feed_new_count counts it: a person's row by when
-- the viewer followed whoever made it (its item's 'by'), a collection's by
-- when the viewer followed the collection. While this file is not applied
-- the feed marks rows as before.
--
-- Only an addition, applied after follows.sql, account.sql and
-- collection_follows.sql (it reads follows, people and collection_follows):
-- one new function, security definer and granted to the service role
-- alone, as the tables it reads are. No table, row or function of before is
-- changed, nothing dropped or renamed.

create or replace function public.feed_followed_at(viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'people', coalesce((select jsonb_object_agg(p.handle, f.at)
                              from public.follows f
                              join public.people p on p.account = f.followed
                             where f.follower = viewer), '{}'::jsonb),
        'collections', coalesce((select jsonb_object_agg(c.collection, c.at)
                                   from public.collection_follows c
                                  where c.follower = viewer), '{}'::jsonb))
     where viewer is not null
$$;

revoke all on function public.feed_followed_at(uuid) from public, anon, authenticated;
grant execute on function public.feed_followed_at(uuid) to service_role;
