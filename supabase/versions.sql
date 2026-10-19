-- Versions of a shared model, 2026-10-18.
--
-- Until now publishing a model again overwrote the files behind its link:
-- somebody halfway through building it lost their place when its designer
-- fixed something, and nobody could see what had changed. Now publishing
-- again makes the model's next version and keeps the one before. The link,
-- /m/<id>, shows the newest; /m/<id>/v/<n> shows an older one, marked as
-- older, with a way to the newest. Unpublishing takes every version away,
-- as it takes the model away.
--
-- Only additions, applied after directory.sql (it reads shared_models'
-- steps): a new table, and a row in it for every model already shared,
-- which is that model's version 1. No existing row or column is changed by
-- this file, and nothing is dropped.
--
--   share_versions   one row per version of a link:
--     model          the link (shared_models.id); a version goes with its
--                    model, and so with its account
--     n              which version, from 1
--     at             when it was published
--     note           what its owner said changed ("What changed?" in the
--                    share panel), or nothing
--     parts, steps   its counts, as api/share.js counts them; steps null
--                    for a model shared before they were counted
--     bytes          the size of its model
--     has_image      whether it has a picture of its own
--     changes        what changed from the version before, worked out by
--                    api/_versions.js from the two files and never typed:
--                    the parts added and removed by part and colour, the
--                    steps added, taken out and changed by number, and
--                    whether the steps could be compared. Null for a
--                    version 1.
--     first_changed  the first step that is not as it was in the version
--                    before, or null when no step changed: a builder who
--                    stopped before it is still where they were
--                    (src/assembly/build_steps.gd).
--     remixed_from_version
--                    which version of the model it was copied from
--                    (shared_models.remixed_from) the copy was made of,
--                    when it is a remix and its app said
--
-- The files: the newest is where it always was, <id>.mpd and <id>.png in
-- the shared-models bucket, so the gallery, its cards, the embed and every
-- link already sent read it as before. An older version's are
-- <id>.v<n>.mpd and <id>.v<n>.png beside them, written when a newer one
-- replaces it. The daily sweep keys a file by what is before its first
-- dot, so it keeps these while their model is published and takes them
-- when it is not, like the rest.
--
-- Who may do what: only the server. A version is read by api/share.js
-- after the model's row has been read as published through the publishable
-- key — the same row security a visitor gets — and written after the
-- session has been verified as the model's owner. No key a page has may
-- read or write it: no grant, no policy.
--
-- Apply it before the code that writes it is deployed: the code before it
-- never reads this table, and the code after it needs it to publish.

create table if not exists public.share_versions (
    model       text not null references public.shared_models (id) on delete cascade,
    n           integer not null check (n between 1 and 100000),
    at          timestamptz not null default now(),
    note        text check (note is null or char_length(note) between 1 and 280),
    parts       integer not null check (parts between 1 and 200000),
    steps       integer check (steps is null or steps between 1 and 200000),
    bytes       integer not null check (bytes between 1 and 2097152),
    has_image   boolean not null default false,
    changes     jsonb check (changes is null
                    or (jsonb_typeof(changes) = 'object' and pg_column_size(changes) <= 65536)),
    first_changed integer check (first_changed is null or first_changed >= 1),
    remixed_from_version integer
        check (remixed_from_version is null or remixed_from_version >= 1),
    primary key (model, n)
);

alter table public.share_versions enable row level security;
revoke all on public.share_versions from anon, authenticated;

-- Every model already shared is its version 1: as it is now, published
-- when it was last updated, with nothing said about what changed. A model
-- taken down has no versions; shared again, it starts at 1.
insert into public.share_versions (model, n, at, parts, steps, bytes, has_image)
select id, 1, updated_at, parts, steps, bytes, has_image
  from public.shared_models
 where published
on conflict (model, n) do nothing;
