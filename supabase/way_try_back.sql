-- signin7 (2026-11-26): a sign-in's try, given back when it spent nothing.
--
-- way_may_try (way_links.sql) counts one try of a key and says only true or
-- false, so a try cannot be uncounted. signreview4 R4-4: a Google, GitHub or
-- orangecheck sign-in is counted right before Supabase's verify, and when the
-- verify answers 429 or no answer comes, the try spent nothing of what the
-- count protects, yet stayed counted: during a rush each of a person's
-- retries counted, and once it ended they waited up to 15 minutes more. And
-- R4-3: the app's orangecheck codes are counted per network before each is
-- traded at orangecheck, and given back when orangecheck takes it, so only
-- the made-up ones stay counted.
--
--   way_try        as way_may_try, the same count under the same lock, but
--                  answers the try's own time (its row's at) when it is
--                  counted, and null when it is not.
--   way_try_back   that one try uncounted: the one row of [try_key] at
--                  [tried_at] deleted. true when there was one.
--
-- Only additions: two functions, each security definer and granted to the
-- service role alone, as way_may_try is. way_attempts and way_may_try are
-- not changed. Applying it again changes nothing. Until it is applied the
-- server counts with way_may_try, and gives nothing back (api/_minted.js
-- counted).

create or replace function public.way_try(try_key text, per integer, window_minutes integer)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
    tried integer;
    at_now timestamptz;
begin
    if per is null or per < 1 or window_minutes is null or window_minutes < 1 or window_minutes > 1440 then
        raise exception 'way_try: per and window_minutes are positive, the window a day at most';
    end if;
    perform pg_advisory_xact_lock(hashtextextended('way_attempts ' || way_try.try_key, 0));
    delete from public.way_attempts a where a.at < now() - interval '1 day';
    select count(*) into tried from public.way_attempts a
     where a.try_key = way_try.try_key and a.at >= now() - make_interval(mins => window_minutes);
    if tried >= per then
        return null;
    end if;
    -- The clock's time, not the transaction's: each try its own, to give back.
    insert into public.way_attempts (try_key, at) values (way_try.try_key, clock_timestamp())
        returning way_attempts.at into at_now;
    return at_now;
end;
$$;

create or replace function public.way_try_back(try_key text, tried_at timestamptz)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    gone integer;
begin
    perform pg_advisory_xact_lock(hashtextextended('way_attempts ' || way_try_back.try_key, 0));
    delete from public.way_attempts a
     where a.ctid = (select b.ctid from public.way_attempts b
                      where b.try_key = way_try_back.try_key and b.at = way_try_back.tried_at limit 1);
    get diagnostics gone = row_count;
    return gone > 0;
end;
$$;

revoke all on function public.way_try(text, integer, integer) from public, anon, authenticated;
revoke all on function public.way_try_back(text, timestamptz) from public, anon, authenticated;
grant execute on function public.way_try(text, integer, integer) to service_role;
grant execute on function public.way_try_back(text, timestamptz) to service_role;
