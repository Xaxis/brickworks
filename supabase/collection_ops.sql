-- My collection, changed one op at a time (mybricks2, 2026-11-06).
--
-- api/collection.js makes every change on the row as it is kept and writes
-- it only over that same row: a PATCH held to the row's rev. When another
-- write came first, its PATCH changes nothing, and it reads the row again
-- and makes the change again on what that one left. So two changes at once
-- both land, and a change never brings back what another took out (the
-- mbreview findings: a person's Add and a session's at once kept one;
-- Start over during a change brought the collection back).
--
--   rev     a number no write of this table has had before: given by the
--           trigger below on every insert and update, by whoever writes,
--           the live api's upsert as well, so a write held to a rev never
--           lands over one it did not see. From a sequence, so a row taken
--           out and made again never has a rev an older read held.
--   recent  the ids of the last changes made (the app's, one per action,
--           sent again as they were when the network failed), so one sent
--           twice is made once.
--
-- Additive only: a sequence, two columns with constant defaults (no row is
-- rewritten: rows kept before have rev 0 until their next write), and a
-- trigger function with its trigger. Nothing existing is dropped, retyped
-- or changed. The api live before this (rel-m266) reads and upserts sets,
-- parts and updated_at only: it goes on working, and each of its writes
-- moves rev on. The api after it reads rev and recent, so this is applied
-- before that is deployed.
--
--   node tools/apply_sql.mjs supabase/collection_ops.sql --dry --try=tools/collection_ops_try.sql
--   node tools/apply_sql.mjs supabase/collection_ops.sql

create sequence if not exists public.collections_rev;

alter table public.collections add column if not exists rev bigint not null default 0;
alter table public.collections add column if not exists recent jsonb not null default '[]'::jsonb;

comment on column public.collections.rev is
    'Moves on at every write (collections_next_rev): api/collection.js writes only over the rev it read.';
comment on column public.collections.recent is
    'The ids of the last changes made, so a change sent again is not made twice (api/collection.js).';

-- As the table's owner: whoever writes a row (the server's key, or one
-- that reaches it some other way) moves its rev on, and needs nothing of
-- the sequence's.
create or replace function public.collections_next_rev()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    new.rev := nextval('public.collections_rev');
    return new;
end;
$$;

revoke all on function public.collections_next_rev() from public, anon, authenticated;
revoke all on sequence public.collections_rev from public, anon, authenticated;

drop trigger if exists collections_next_rev on public.collections;
create trigger collections_next_rev
    before insert or update on public.collections
    for each row execute function public.collections_next_rev();
