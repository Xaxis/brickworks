-- What is new in the feed counts only what came after the follow,
-- 2026-10-24 (walk180, W7).
--
-- The count on your avatar is notification_counts' two together, and its
-- feed is every row of follow_rows since you last opened the feed (or in
-- the last 90 days, never opened). Following somebody brought their last 90
-- days into the feed, and every one of those rows into the count: a
-- brand-new account that followed the house in First steps had 7 on its
-- avatar at once, one for each of the house's old models, and "Your feed 7"
-- beside Notifications. A new follow's backlog is in the feed to read; it
-- is not new.
--
--   feed_new_count(viewer)   notification_counts' feed, but only the rows
--                            that came after [viewer] followed whoever made
--                            them (follows.at), at most 99
--
-- api/_notifications.js reads it for the feed's count, and the count of
-- before while this file is not applied.
--
-- Only an addition, applied after notifications.sql (it reads follow_rows,
-- feed_marks, follows and people): one new function, security definer and
-- granted to the service role alone. No table, row or function of before is
-- changed, nothing dropped or renamed.

-- Each row's maker is its item's 'by' (feed_who of the model's owner, or of
-- whoever took the photo): the person followed, by their handle.
-- REPLACED LATER: list_follow_counts.sql replaces this function (a
-- collection's rows by when they were put in it after it was followed).
-- Apply list_follow_counts.sql again right after this file:
-- tools/apply_sql.mjs refuses it alone, unless
-- --again=supabase/list_follow_counts.sql.
create or replace function public.feed_new_count(viewer uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer from (
        select 1
          from public.follow_rows(viewer,
                   greatest(coalesce((select k.seen_at from public.feed_marks k where k.account = viewer), '-infinity'),
                            now() - interval '90 days'), now()) r
          join public.people p on p.handle = r.item->'by'->>'handle'
          join public.follows f on f.follower = viewer and f.followed = p.account
         where r.at > f.at
         limit 99) n
     where viewer is not null
$$;

revoke all on function public.feed_new_count(uuid) from public, anon, authenticated;
grant execute on function public.feed_new_count(uuid) to service_role;
