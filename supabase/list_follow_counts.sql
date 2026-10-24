-- What is new from a collection you follow is what was put in it after you
-- followed it, 2026-10-24 (U11 meets walk180's W7).
--
-- follow_counts.sql's feed_new_count counts a feed row as new only when it
-- came after the viewer followed whoever made it: the row's maker (its
-- item's 'by') joined to follows. A row of a collection followed
-- (collection_follows.sql list_rows) is by the collection's owner, whom the
-- follower seldom follows as a person, so it was never counted: Bob
-- followed Ada's collection, Ada put a model in, and his avatar said 0
-- (list_follows_flow, fixes243 twice). And when he did follow Ada too, a
-- model she put in before he followed the collection was counted, by when
-- he followed her.
--
-- Now each row by its own follow, at its own time:
--
--   a collection's row   new when it was put in the collection (its at,
--                        model_collection_items.at) after the viewer
--                        followed that collection (collection_follows.at),
--                        however long before the model was published
--   every other row      as follow_counts.sql had it: new when it came
--                        (published, listed, posted) after the viewer
--                        followed whoever made it (follows.at)
--
-- W7's rule holds for both: a new follow's backlog is in the feed to read,
-- and none of it is new.
--
-- Only a function replaced, applied after follow_counts.sql and
-- collection_follows.sql (it reads follow_rows, feed_marks, follows,
-- people and collection_follows): feed_new_count, the same name and
-- arguments, so api/_notifications.js reads it as before. Security definer
-- and granted to the service role alone. No table or row is changed,
-- nothing dropped or renamed. Applying follow_counts.sql again alone would
-- take the collections out of the count: tools/apply_sql.mjs refuses it
-- (supabase/later.tsv), unless --again=supabase/list_follow_counts.sql.

create or replace function public.feed_new_count(viewer uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    with fed as (
        select r.kind, r.at, r.item
          from public.follow_rows(viewer,
                   greatest(coalesce((select k.seen_at from public.feed_marks k where k.account = viewer), '-infinity'),
                            now() - interval '90 days'), now()) r)
    select count(*)::integer from (
        -- A person's: after the viewer followed them.
        select 1
          from fed r
          join public.people p on p.handle = r.item->'by'->>'handle'
          join public.follows f on f.follower = viewer and f.followed = p.account
         where r.kind <> 'collection' and r.at > f.at
        union all
        -- A collection's: put in it after the viewer followed it.
        select 1
          from fed r
          join public.collection_follows c on c.follower = viewer and c.collection = r.item->>'collection'
         where r.kind = 'collection' and r.at > c.at
         limit 99) n
     where viewer is not null
$$;

revoke all on function public.feed_new_count(uuid) from public, anon, authenticated;
grant execute on function public.feed_new_count(uuid) to service_role;
