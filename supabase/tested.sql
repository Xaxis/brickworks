-- The "Tested" mark on a shared model, 2026-10-18.
--
-- Paid fan instructions elsewhere are often untested virtual models, and a
-- builder finds out when the build falls apart. Brickworks tests a model as
-- it is published, in the app, where the model and the part library are
-- (src/assembly/tested.gd): it stands at every one of the steps the share
-- carries; no part of a step is put down in the air or hidden behind what is
-- already built; every part is made in its colour; nothing is loose. The
-- server cannot run any of that, so it keeps what the app found, as the
-- app's own finding with the app's version, once it has checked the finding
-- is of the very file published and of the steps that file carries
-- (api/_tested.js). A pass is shown on the model's page, its gallery card
-- and the viewer; a failure only to the model's owner, as a note; and the
-- site's owner can clear a mark (api/admin.js ?op=untest).
--
-- Only additions, applied after versions.sql and test_models.sql: a new
-- table, a new function, and two functions replaced with one thing more
-- each. No existing row or column is changed, and nothing is dropped. A
-- model shared before this has no mark, as an untested model has none.
--
--   share_tests   one row per tested version of a link:
--     model, n    the version (share_versions), and gone with it: a link
--                 taken down loses its versions, and with them their marks
--     at          when the version was published
--     by          whose finding: always 'app', the Brickworks app's
--     app         that app's version, as it said it ("0.3.0")
--     file_hash   the file's fingerprint (api/_directory.js modelHash) the
--                 finding is of
--     parts, steps  how many parts it tested, by how many steps
--     tests       {stands, steps, parts, whole: {ok, why}}: each test's yes
--                 or no, and the app's reason, at most 300 characters
--     passed      all four said yes, as worked out by the server from them
--     cleared_at, cleared_why
--                 the site's owner cleared the mark: shown nowhere after
--
-- Who may do what: only the server, as with share_versions. No grant and no
-- policy for any key a page has.

create table if not exists public.share_tests (
    model       text not null,
    n           integer not null check (n between 1 and 100000),
    at          timestamptz not null default now(),
    by          text not null default 'app' check (by = 'app'),
    app         text not null
        check (app ~ '^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,6}([-+.][0-9A-Za-z.-]{1,40})?$'),
    file_hash   text not null check (file_hash ~ '^[0-9a-f]{64}$'),
    parts       integer not null check (parts between 1 and 200000),
    steps       integer not null check (steps between 1 and 200000),
    tests       jsonb not null check (jsonb_typeof(tests) = 'object'
                    and pg_column_size(tests) <= 8192
                    and tests ?& array['stands', 'steps', 'parts', 'whole']),
    passed      boolean not null,
    cleared_at  timestamptz,
    cleared_why text check (cleared_why is null or char_length(cleared_why) between 1 and 280),
    primary key (model, n),
    foreign key (model, n) references public.share_versions (model, n) on delete cascade,
    -- What passed is what the four said, and nothing a caller says beside.
    check (passed = coalesce((tests->'stands'->>'ok')::boolean and (tests->'steps'->>'ok')::boolean
                    and (tests->'parts'->>'ok')::boolean and (tests->'whole'->>'ok')::boolean, false))
);

alter table public.share_tests enable row level security;
revoke all on public.share_tests from anon, authenticated;

-- Whether a model's newest version is marked Tested: it passed, and the
-- mark was not cleared. A newest version with no mark is untested, whatever
-- an older one passed.
create or replace function public.model_tested(model_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.share_tests t
         where t.model = model_id and t.passed and t.cleared_at is null
           and t.n = (select max(v.n) from public.share_versions v where v.model = model_id))
$$;
revoke all on function public.model_tested(text) from public, anon, authenticated;
grant execute on function public.model_tested(text) to service_role;

-- A card, as people.sql made it, and whether it is marked Tested.
create or replace function public.directory_card(m public.shared_models)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', m.id, 'name', m.name, 'author', m.author, 'parts', m.parts,
        'has_image', m.has_image, 'has_thumb', m.has_thumb,
        'listed_at', m.listed_at, 'updated_at', m.updated_at,
        'kind', m.kind, 'tags', to_jsonb(m.tags), 'licence', m.licence,
        'steps', m.steps, 'own_steps', m.own_steps, 'technic', m.technic,
        'views', coalesce(s.views, 0), 'likes', coalesce(s.likes, 0),
        'remixes', (select count(*) from public.shared_models r
                     where r.remixed_from = m.id and r.published),
        'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                 from public.people p
                where p.account = m.owner and m.author is not null),
        'tested', public.model_tested(m.id))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;

-- The list, as test_models.sql made it, and one thing more: tested, true
-- for only the models marked Tested ("Tested only" in the gallery).
create or replace function public.directory_models(query jsonb)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    with asked as (
        select nullif(query->>'words', '') as words,
               nullif(query->>'kind', '') as kind,
               nullif(query->>'tag', '') as tag,
               (query->>'least')::integer as least_parts,
               (query->>'most')::integer as most_parts,
               coalesce((query->>'own_steps')::boolean, false) as own_steps,
               coalesce((query->>'technic')::boolean, false) as technic,
               coalesce((query->>'tested')::boolean, false) as tested,
               (query->>'owner')::uuid as owner,
               nullif(query->>'collection', '') as collection,
               (query->>'favourites')::uuid as favourites,
               coalesce((query->>'private')::boolean, false) as private,
               coalesce((query->>'tests')::boolean, false) as tests,
               coalesce(nullif(query->>'sort', ''), 'newest') as sort,
               least(greatest(coalesce((query->>'size')::integer, 25), 1), 49) as size,
               least(greatest(coalesce((query->>'skip')::integer, 0), 0), 20000) as skip
    )
    select public.directory_card(m)
      from asked a
     cross join public.shared_models m
      left join public.model_stats s on s.model = m.id
      left join lateral (
          select count(*) as n from public.shared_models r
           where r.remixed_from = m.id and r.published) rx on true
      left join lateral (
          select coalesce(
              (select i.at from public.model_collection_items i
                where i.collection = a.collection and i.model = m.id),
              (select f.at from public.model_favourites f
                where f.account = a.favourites and f.model = m.id)) as at) added on true
     where m.published and not m.barred
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
       and (m.listed or a.private)
       and (not m.test or a.tests or a.private)
       and (a.words is null or m.search @@ to_tsquery('simple'::regconfig, a.words))
       and (a.kind is null or m.kind = a.kind)
       and (a.tag is null or m.tags @> array[a.tag])
       and (a.least_parts is null or m.parts >= a.least_parts)
       and (a.most_parts is null or m.parts <= a.most_parts)
       and (not a.own_steps or m.own_steps)
       and (not a.technic or m.technic)
       and (not a.tested or public.model_tested(m.id))
       and (a.owner is null or (m.owner = a.owner and m.author is not null and m.listed))
       and (a.collection is null or exists (select 1 from public.model_collection_items i
                                             where i.collection = a.collection and i.model = m.id))
       and (a.favourites is null or exists (select 1 from public.model_favourites f
                                             where f.account = a.favourites and f.model = m.id))
     order by
        case when a.sort = 'added' then added.at end desc nulls last,
        case when a.sort = 'views' then coalesce(s.views, 0) end desc nulls last,
        case when a.sort = 'likes' then coalesce(s.likes, 0) end desc nulls last,
        case when a.sort = 'remixes' then rx.n end desc nulls last,
        m.listed_at desc nulls last, m.updated_at desc, m.id desc
     limit (select size from asked) offset (select skip from asked)
$$;
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;
