-- What a remix changed from the model it was copied from, 2026-11-23
-- (remixdiff; docs/MASTERPLAN.md unit 7).
--
-- A remix (shared_models.remixed_from) said "remixed from X" and the
-- original listed its remixes, as Printables does in words. Brickworks holds
-- both files, and the app's Compare already counts what changed between two
-- saves part by part (src/parts/model_diff.gd): added, taken away, moved or
-- turned, recoloured. api/_remix_changes.js counts a remix against the
-- version of the original it was copied from by the same rules, once, as
-- the remix is published (api/share.js, after its answer), and keeps it
-- here; its page says it under the remix's credit, its 3D view lights the
-- parts it changed and draws the ones it took away as ghosts, and the
-- original's Remixes tab draws its remixes as a tree with each one's line
-- (remix_tree). Nothing reads either file as a page is viewed.
--
-- Only additions, applied after directory.sql, versions.sql and
-- test_models.sql (remix_tree reads directory_card, shared_models and
-- share_versions): one table, one function, one index. No existing row,
-- column or function is changed by this file, and nothing is dropped.
--
--   remix_changes    one row per remix, of its newest version:
--     model          the remix (shared_models.id); it goes with its model
--     n              which version of the remix was counted
--     against        the model it was counted against (its remixed_from
--                    when it was counted)
--     against_n      which version of that model: the one its app said it
--                    was copied from (share_versions.remixed_from_version),
--                    or where it did not say, the newest when the remix
--                    was first shared (inferred)
--     inferred       whether against_n was worked out from the dates
--     added, removed, moved, recoloured
--                    the app's four counts; moved includes turned
--     turned         of the moved, how many were turned
--     parts_was, parts_now
--                    how many parts each side has, as the app reads them
--     shown          for the remix's 3D view (api/_remix_changes.js
--                    remixChanges): which of its parts changed, as runs of
--                    their indexes in its packing, and the parts taken away
--                    packed as a scene of their own
--     at             when it was counted
--
-- Who may do what: only the server. A row is written with the secret key by
-- api/share.js after the remix's owner has published it, and by
-- tools/web/remix_backfill.mjs for the remixes shared before this file. It
-- is read by api/share.js for pages it shows anybody, and only for a model
-- read as published. No key a page has may read or write it: no grant, no
-- policy.
--
-- Apply it before the code that writes it is deployed? Either order works:
-- the code before it never reads this table, and the code after it keeps
-- nothing and says nothing of what changed until it is here (a missing
-- table or function is caught, and the page is as it was). Then run
-- tools/web/remix_backfill.mjs once.

create table if not exists public.remix_changes (
    model       text primary key references public.shared_models (id) on delete cascade,
    n           integer not null check (n >= 1),
    against     text not null,
    against_n   integer not null check (against_n >= 1),
    inferred    boolean not null default false,
    added       integer not null check (added >= 0),
    removed     integer not null check (removed >= 0),
    moved       integer not null check (moved >= 0),
    recoloured  integer not null check (recoloured >= 0),
    turned      integer not null default 0 check (turned >= 0),
    parts_was   integer not null check (parts_was >= 0),
    parts_now   integer not null check (parts_now >= 0),
    shown       jsonb,
    at          timestamptz not null default now()
);

alter table public.remix_changes enable row level security;
revoke all on public.remix_changes from public, anon, authenticated;
grant select, insert, update, delete on public.remix_changes to service_role;

-- A model's remixes are found by what they were remixed from
-- (achievements.sql made the same index; kept here in case it was not run).
create index if not exists shared_models_remixed_from on public.shared_models (remixed_from);

-- A row's counts as a page says them: the four, turned, both sides' parts,
-- which version of which model, whether that version was inferred, and
-- whether its 3D view has what to light (drawn).
create or replace function public.remix_counts(r public.remix_changes)
returns jsonb
language sql
immutable
set search_path = public
as $$
    select jsonb_build_object('added', r.added, 'removed', r.removed, 'moved', r.moved,
        'recoloured', r.recoloured, 'turned', r.turned, 'parts_was', r.parts_was,
        'parts_now', r.parts_now, 'n', r.n, 'against', r.against, 'against_n', r.against_n,
        'inferred', r.inferred, 'drawn', r.shown is not null)
$$;

-- What a model's Remixes tab draws: {changes, up, down}.
--
--   changes  what the model itself changed from the one it was copied from,
--            as counted (remix_changes), or null
--   up       each model it came from, nearest first, back to the first
--            (or 8): {id, name, author, depth, its picture's has_image,
--            has_thumb and updated_at, changes, from} while it is
--            listed, else {id: null, by_link: true, depth}; a line goes back
--            past a model only while it is published, as directory_model's
--            'from' does. [from] names the one it was itself copied from,
--            for "a remix of a remix names both".
--   down     its remixes in the gallery, three levels down: each its card
--            (directory_card) with parent (the model it remixes), depth
--            (1 to 3) and changes; at most 24 at the first level, newest
--            first, and 12 under each below; never a test model unless the
--            model is one (test_models.sql), never one taken out.
create or replace function public.remix_tree(model_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with recursive root as (
        select m.id, m.test from public.shared_models m where m.id = model_id and m.published
    ),
    up (id, depth) as (
        select m.remixed_from, 1
          from public.shared_models m
         where m.id = model_id and m.published and m.remixed_from is not null
        union all
        select p.remixed_from, up.depth + 1
          from up
          join public.shared_models p on p.id = up.id
         where up.depth < 8 and p.published and p.remixed_from is not null
    ),
    level1 as (
        select c.id, c.remixed_from as parent, 1 as depth, c.listed_at
          from public.shared_models c, root
         where c.remixed_from = root.id and c.published and c.listed and not c.barred
           and (not c.test or root.test)
         order by c.listed_at desc, c.id desc
         limit 24
    ),
    level2 as (
        select k.id, k.parent, 2 as depth, k.listed_at
          from level1 l1
          cross join lateral (
              select c.id, c.remixed_from as parent, c.listed_at
                from public.shared_models c, root
               where c.remixed_from = l1.id and c.id <> root.id and c.published and c.listed
                 and not c.barred and (not c.test or root.test)
               order by c.listed_at desc, c.id desc
               limit 12) k
    ),
    level3 as (
        select k.id, k.parent, 3 as depth, k.listed_at
          from level2 l2
          cross join lateral (
              select c.id, c.remixed_from as parent, c.listed_at
                from public.shared_models c, root
               where c.remixed_from = l2.id and c.id <> root.id and c.published and c.listed
                 and not c.barred and (not c.test or root.test)
               order by c.listed_at desc, c.id desc
               limit 12) k
    ),
    down as (
        select * from level1 union all select * from level2 union all select * from level3
    )
    select jsonb_build_object(
        'changes', (select public.remix_counts(r) from public.remix_changes r where r.model = model_id),
        'up', coalesce((
            select jsonb_agg(
                case when p.published and p.listed and not p.barred
                     then jsonb_build_object('id', p.id, 'name', p.name, 'author', p.author, 'depth', up.depth,
                          'has_image', p.has_image, 'has_thumb', p.has_thumb, 'updated_at', p.updated_at,
                          'changes', (select public.remix_counts(r) from public.remix_changes r where r.model = p.id),
                          'from', (select case when g.published and g.listed and not g.barred
                                               then jsonb_build_object('id', g.id, 'name', g.name, 'author', g.author)
                                               else jsonb_build_object('id', null, 'by_link', true) end
                                     from public.shared_models g where g.id = p.remixed_from))
                     else jsonb_build_object('id', null, 'by_link', true, 'depth', up.depth) end
                order by up.depth)
              from up
              join public.shared_models p on p.id = up.id
             where p.published), '[]'::jsonb),
        'down', coalesce((
            select jsonb_agg(public.directory_card(c) || jsonb_build_object(
                       'parent', d.parent, 'depth', d.depth,
                       'changes', (select public.remix_counts(r) from public.remix_changes r where r.model = c.id))
                   order by d.depth, d.listed_at desc, c.id desc)
              from down d
              join public.shared_models c on c.id = d.id), '[]'::jsonb))
      from root
$$;

-- The server's alone, as every page's function is.
revoke all on function public.remix_counts(public.remix_changes) from public, anon, authenticated;
grant execute on function public.remix_counts(public.remix_changes) to service_role;
revoke all on function public.remix_tree(text) from public, anon, authenticated;
grant execute on function public.remix_tree(text) to service_role;
