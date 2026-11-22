-- A publish that lists, counted as one of each or as neither (byfix,
-- 2026-11-21).
--
-- api/share.js counted a listed publish with two calls, may_list and then
-- may_publish, each of which records itself as it says yes. A person at the
-- hour's last publish who shared a model listed was refused by the second
-- after the first had already counted the listing: every refused try cost
-- them one of the hour's six listings. The site's Share from a file
-- (web/share-model.js) publishes listed as its one publish, so it met this
-- at every refusal. Both counts are read here under both locks, and both
-- recorded only when both allow it.
--
--   may_publish_listed(account) -> 'ok'         one publish and one listing
--                                               recorded
--                                  'listings'   the hour's or the day's
--                                               listings used up: nothing
--                                               recorded
--                                  'publishes'  the publishes used up:
--                                               nothing recorded
--
-- The same limits and the same tables as may_publish (shared_models.sql) and
-- may_list (gallery.sql), and their locks, taken in this order by this
-- function alone (each of those takes only its own), so no two callers wait
-- on each other the wrong way round. Additive: a new function, nothing else
-- changed. Before it is applied api/share.js counts the two as it did.

create or replace function public.may_publish_listed(
    account uuid,
    publish_hour integer default 20, publish_day integer default 60,
    list_hour integer default 6, list_day integer default 20)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    listed_hour integer;
    listed_day integer;
    published_hour integer;
    published_day integer;
begin
    perform pg_advisory_xact_lock(hashtext('may_list:' || account::text));
    perform pg_advisory_xact_lock(hashtext('may_publish:' || account::text));
    delete from public.share_listings where at < now() - interval '1 day';
    delete from public.share_publishes where at < now() - interval '1 day';

    select count(*) filter (where at >= now() - interval '1 hour'), count(*)
      into listed_hour, listed_day
      from public.share_listings
     where owner = account;
    if listed_hour >= list_hour or listed_day >= list_day then
        return 'listings';
    end if;

    select count(*) filter (where at >= now() - interval '1 hour'), count(*)
      into published_hour, published_day
      from public.share_publishes
     where owner = account;
    if published_hour >= publish_hour or published_day >= publish_day then
        return 'publishes';
    end if;

    insert into public.share_listings (owner) values (account);
    insert into public.share_publishes (owner) values (account);
    return 'ok';
end;
$$;

revoke all on function public.may_publish_listed(uuid, integer, integer, integer, integer)
    from public, anon, authenticated;
grant execute on function public.may_publish_listed(uuid, integer, integer, integer, integer) to service_role;
