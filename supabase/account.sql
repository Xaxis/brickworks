-- Your account, 2026-10-20: whom you follow, for you alone.
--
-- The account page (/profile) is a person's home on the site, and it lists
-- the designers they follow. follow_list (follows.sql) answers that only
-- for a profile that chose to show it, since it is what a profile's page
-- shows anybody; the person themselves sees theirs whatever they chose.
-- The follows table is the server's through functions alone (follows.sql
-- revokes it from every role), so this is one more:
--
--   follow_list_mine   [account]'s follows, newest first, as
--                      [{handle, name}]: the people followed who may be
--                      followed still (follow_may_be_followed: shown in
--                      public, not taken out), at most 500.
--
-- Asked by api/_follows.js (GET /api/people?op=following with a sign-in
-- and no handle), with the secret key. Until this file is applied the page
-- says how many you follow and no more.
--
-- Additive: one function, nothing dropped or changed. Applying it again
-- changes nothing.

create or replace function public.follow_list_mine(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('handle', q.handle, 'name', q.name) order by f.at desc), '[]'::jsonb)
      from (select * from public.follows g where g.follower = follow_list_mine.account
             order by g.at desc limit 500) f
      join public.people q on q.account = f.followed
     where public.follow_may_be_followed(f.followed)
$$;
revoke all on function public.follow_list_mine(uuid) from public, anon, authenticated;
grant execute on function public.follow_list_mine(uuid) to service_role;
