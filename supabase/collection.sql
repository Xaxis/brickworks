-- My collection: the sets and parts a person owns, kept with their account.
--
-- One row per account. What is kept is what the person said they own,
-- already in LDraw's numbers (api/collection.js parses and maps every
-- import before it is written): the sets by number and how many of each,
-- and the loose parts by part, LDraw colour code and quantity. A set is
-- kept as a set and never expanded here; what is in it is the app's to
-- look up (tools/collection_data.py), so a better inventory reaches every
-- collection without rewriting one.
--
--   sets   [{"set": "10237-1", "qty": 1, "spares": false}, ...]
--   parts  [{"part": "3001", "colour": 4, "qty": 12}, ...]
--
-- Added 2026-10-12. Additive only: a new table, its policies and its
-- grants. Nothing existing is touched.
--
-- Read and written through api/collection.js with the secret key, which
-- only ever names the caller's own row. Row level security is the second
-- lock: the publishable key that the app holds, with a person's own
-- session, reaches that person's row and no other, and without a session
-- reaches nothing.

create table if not exists public.collections (
    owner       uuid primary key references auth.users (id) on delete cascade,
    sets        jsonb not null default '[]'::jsonb,
    parts       jsonb not null default '[]'::jsonb,
    updated_at  timestamptz not null default now(),
    constraint collections_sets_list check (jsonb_typeof(sets) = 'array'),
    constraint collections_parts_list check (jsonb_typeof(parts) = 'array'),
    -- The endpoint refuses anything over these first, with words; this
    -- is the ceiling a request that went round it still meets.
    constraint collections_sets_size check (jsonb_array_length(sets) <= 5000),
    constraint collections_parts_size check (jsonb_array_length(parts) <= 20000)
);

comment on table public.collections is
    'What one account owns: sets by number and loose parts by LDraw part, '
    'colour and quantity. Written only through api/collection.js.';

alter table public.collections enable row level security;

drop policy if exists collections_read_own on public.collections;
create policy collections_read_own on public.collections
    for select to authenticated using (auth.uid() = owner);

drop policy if exists collections_insert_own on public.collections;
create policy collections_insert_own on public.collections
    for insert to authenticated with check (auth.uid() = owner);

drop policy if exists collections_update_own on public.collections;
create policy collections_update_own on public.collections
    for update to authenticated using (auth.uid() = owner) with check (auth.uid() = owner);

drop policy if exists collections_delete_own on public.collections;
create policy collections_delete_own on public.collections
    for delete to authenticated using (auth.uid() = owner);

-- Nobody signed out has any business here, and saying so in the grants
-- as well as the policies means a policy dropped by mistake still leaves
-- the anonymous key with nothing. Supabase grants every role everything
-- on a new table, TRUNCATE among it, which row security does not cover;
-- so all of it goes, and a signed-in person gets back the four verbs the
-- policies govern.
revoke all on public.collections from anon, authenticated, public;
grant select, insert, update, delete on public.collections to authenticated;
grant all on public.collections to service_role;
