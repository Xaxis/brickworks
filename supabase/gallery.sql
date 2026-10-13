-- The public gallery, and remixing from it, 2026-10-13.
--
-- Until now every shared link was unlisted: nobody could find a model
-- they were not sent. Now whoever shares a model may tick "List it in the
-- gallery", and https://brickworks.diy/gallery shows the listed ones,
-- newest first (api/share.js ?op=list). A model copied with Open in
-- Brickworks and shared again says which one it was remixed from.
--
-- Only additions to supabase/shared_models.sql, applied after it: new
-- columns with defaults, an index, and a counted log with its limit like
-- share_publishes. No existing row or column is changed by this file.
--
--   listed        shown in the gallery. Off unless its owner ticks it.
--   listed_at     when it was last listed, which is what "newest" means
--                 in the gallery: a model shared a week ago and listed
--                 today is new there.
--   remixed_from  the link this model was copied from, if it was. Kept
--                 when that one goes; a page names it only while it is
--                 still published.
--   barred        taken out of the gallery by the site's owner
--                 (api/admin.js ?op=unlist). The link still works; a
--                 republish cannot list it again. Not granted to the
--                 publishable key: a visitor has no business with it.

alter table public.shared_models
    add column if not exists listed boolean not null default false;
alter table public.shared_models
    add column if not exists listed_at timestamptz;
alter table public.shared_models
    add column if not exists remixed_from text
        check (remixed_from is null or remixed_from ~ '^[A-Za-z0-9]{10}$')
        references public.shared_models (id) on delete set null;
alter table public.shared_models
    add column if not exists barred boolean not null default false;

-- What a visitor reads of a row, granted column by column as the rest
-- are (shared_models.sql): whether it is listed, since when, and what it
-- was remixed from. Never its owner, never barred.
grant select (listed, listed_at, remixed_from)
    on public.shared_models to anon, authenticated;

-- The gallery's one question: the listed, published rows, newest first.
create index if not exists shared_models_gallery
    on public.shared_models (listed_at desc, id desc)
    where listed and published;

-- Listing, counted, so the gallery cannot be flooded from one account:
-- each time a model goes into the gallery that was not in it. No policy:
-- only the server has any business here.
create table if not exists public.share_listings (
    id     bigserial primary key,
    owner  uuid not null references auth.users (id) on delete cascade,
    at     timestamptz not null default now()
);
create index if not exists share_listings_owner
    on public.share_listings (owner, at desc);

alter table public.share_listings enable row level security;
revoke all on public.share_listings from anon, authenticated;

-- List once, and say whether that was allowed: as may_publish does, so
-- many an hour and so many a day for one account, counted and recorded
-- in one call under the account's own advisory lock.
create or replace function public.may_list(
    account uuid, per_hour integer default 6, per_day integer default 20)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    last_hour integer;
    last_day integer;
begin
    perform pg_advisory_xact_lock(hashtext('may_list:' || account::text));
    delete from public.share_listings where at < now() - interval '1 day';

    select count(*) filter (where at >= now() - interval '1 hour'), count(*)
      into last_hour, last_day
      from public.share_listings
     where owner = account;

    if last_hour >= per_hour or last_day >= per_day then
        return false;
    end if;

    insert into public.share_listings (owner) values (account);
    return true;
end;
$$;

revoke all on function public.may_list(uuid, integer, integer)
    from public, anon, authenticated;
grant execute on function public.may_list(uuid, integer, integer) to service_role;
