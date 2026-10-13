-- Models shared by link, 2026-10-12.
--
-- Someone signed in publishes the model they have open (File › Share…)
-- and gets https://brickworks.diy/m/<id>. Anyone may open that link
-- without an account: a read-only viewer of the model, its booklet and
-- its parts list. Publishing again updates the same link; unpublishing
-- takes the model away and the link says so.
--
--   shared_models    one row per link: whose it is, what it is called,
--                    the name it is credited to (only if its owner chose
--                    to show one) and how many parts it has. The model
--                    itself and its picture are files in the
--                    shared-models bucket, <id>.mpd and <id>.png.
--   share_publishes  when each account published, so publishing can be
--                    limited (may_publish). Kept a day.
--
-- Who may do what:
--   read     anyone, a published row only, and never its owner: the
--            publishable key's roles are granted the columns a link
--            shows and nothing else, so a model credited to nobody
--            cannot be tied to the account that shared it.
--   write    nobody but the server. api/share.js checks the session and
--            the owner and writes with the secret key; there is no
--            insert, update or delete policy for any other key.
--   files    the bucket is private with no policies at all, so only the
--            server reads it, and it reads a file only after the row has
--            been read as published through the publishable key — the
--            same row security a visitor gets. Unpublishing deletes both
--            files, so an unpublished model is not anywhere to be read.
--
-- A person's builds are still files on their own disk or in their
-- browser (supabase/schema.sql); what is here is only what they chose to
-- publish. Gone with the account.
--
-- supabase/gallery.sql, applied after this, adds the public gallery: the
-- listed, listed_at, remixed_from and barred columns, and may_list.

create table if not exists public.shared_models (
    id          text primary key check (id ~ '^[A-Za-z0-9]{10}$'),
    owner       uuid not null references auth.users (id) on delete cascade,
    name        text not null check (char_length(name) between 1 and 80),
    author      text check (author is null or char_length(author) between 1 and 60),
    parts       integer not null check (parts between 1 and 200000),
    bytes       integer not null check (bytes between 1 and 2097152),
    has_image   boolean not null default false,
    published   boolean not null default true,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);
create index if not exists shared_models_owner
    on public.shared_models (owner, updated_at desc);

alter table public.shared_models enable row level security;

-- Granted column by column: a published row is public, its owner is not.
revoke all on public.shared_models from anon, authenticated;
grant select (id, name, author, parts, bytes, has_image, published, created_at, updated_at)
    on public.shared_models to anon, authenticated;

drop policy if exists shared_models_read_published on public.shared_models;
create policy shared_models_read_published on public.shared_models
    for select to anon, authenticated using (published);

-- Publishing, counted. No policy: only the server has any business here.
create table if not exists public.share_publishes (
    id     bigserial primary key,
    owner  uuid not null references auth.users (id) on delete cascade,
    at     timestamptz not null default now()
);
create index if not exists share_publishes_owner
    on public.share_publishes (owner, at desc);

alter table public.share_publishes enable row level security;
revoke all on public.share_publishes from anon, authenticated;

-- Publish once, and say whether that was allowed: so many an hour and so
-- many a day for one account. Counted and recorded in one call, so two
-- publishes at once cannot both read the same count; the advisory lock
-- serialises one account's calls. A republish counts like a first one —
-- each sends a model to store.
create or replace function public.may_publish(
    account uuid, per_hour integer default 20, per_day integer default 60)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    last_hour integer;
    last_day integer;
begin
    perform pg_advisory_xact_lock(hashtext('may_publish:' || account::text));
    delete from public.share_publishes where at < now() - interval '1 day';

    select count(*) filter (where at >= now() - interval '1 hour'), count(*)
      into last_hour, last_day
      from public.share_publishes
     where owner = account;

    if last_hour >= per_hour or last_day >= per_day then
        return false;
    end if;

    insert into public.share_publishes (owner) values (account);
    return true;
end;
$$;

revoke all on function public.may_publish(uuid, integer, integer)
    from public, anon, authenticated;
grant execute on function public.may_publish(uuid, integer, integer) to service_role;

-- The files. Private, a 2 MB ceiling (the model's own limit; the picture
-- is held to less by api/share.js) and only the two kinds of file a link
-- serves. No policy on storage.objects names this bucket.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shared-models', 'shared-models', false, 2097152,
        array['text/plain', 'image/png'])
on conflict (id) do nothing;
