-- Test models out of public lists, 2026-10-17.
--
-- Every release runs tools/web/share_probe.mjs against the live site, and
-- while it runs its models were in the real gallery, newest first, above
-- the showcase: "Probe Gallery", "Listed 0" to "Listed 5", and a name
-- that is markup. They also broke a desktop release: tools/mcp_check.py
-- opened the newest model and wanted its picture, and the newest was the
-- probe's, which has none.
--
-- A probe signs in at a Resend test address (tools/web/session.mjs), and
-- nobody else can: mail to resend.dev reaches nobody. So a model published
-- by such an account is marked a test when it is published (api/share.js),
-- and no public list shows it: the gallery, people's pages, collections,
-- the sitemap and a model's remixes. Asked for (?tests=1), the gallery, a
-- profile and a collection show them too, which is how the probe still
-- checks the real list (api/share.js, api/people.js). A test model's own
-- page stays at its link.
--
-- Only additions, applied after moderation.sql: a new column with a
-- default, and functions. Those that list models are replaced, the same
-- but for test models; the three whose signature cannot say "with tests"
-- get a form beside them that can, and the old forms are now that form
-- without tests. No existing row is changed: every row is false, as made
-- by a release before this one, so nothing shown today goes until the
-- release that marks them ships.
--
--   test   published by a test account (an address at resend.dev). Not
--          granted to the publishable key: a visitor has no business with
--          it, as with barred.

alter table public.shared_models
    add column if not exists test boolean not null default false;

-- The list, as moderation.sql made it, and one thing more: a test model
-- only when asked for (query.tests), or in its owner's own private view.
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

-- How many models a list shows: the listed ones, test models only when
-- asked for; or with private, every published one in it (its owner's).
create or replace function public.collection_count(list text, private boolean, tests boolean)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer
      from public.model_collection_items i
      join public.shared_models m on m.id = i.model
     where i.collection = list and m.published and not m.barred and (m.listed or private)
       and (not m.test or tests or private)
$$;

create or replace function public.collection_count(list text, private boolean)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select public.collection_count(list, private, false)
$$;

-- A profile, as moderation.sql made it, its counts without test models
-- unless asked for.
create or replace function public.profile_page(wanted text, tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'handle', p.handle, 'name', p.name, 'bio', p.bio, 'since', p.created_at,
        'models', (select count(*) from public.shared_models m
                    where m.owner = p.account and m.published and m.listed
                      and not m.barred and m.author is not null and (not m.test or tests)),
        'likes', (select coalesce(sum(s.likes), 0) from public.shared_models m
                    join public.model_stats s on s.model = m.id
                   where m.owner = p.account and m.published and m.listed
                     and not m.barred and m.author is not null and (not m.test or tests)),
        'collections', coalesce((
            select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name,
                       'description', c.description, 'count', public.collection_count(c.id, false, tests))
                       order by c.updated_at desc)
              from public.model_collections c
             where c.owner = p.account and c.public), '[]'::jsonb))
      from public.people p
     where p.handle = lower(wanted)
       and not exists (select 1 from public.barred_accounts b where b.account = p.account)
$$;

create or replace function public.profile_page(wanted text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select public.profile_page(wanted, false)
$$;

-- A list's page, as moderation.sql made it, counted the same way.
create or replace function public.collection_page(list text, tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', c.id, 'name', c.name, 'description', c.description, 'public', c.public,
        'owner', c.owner, 'updated_at', c.updated_at,
        'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                 from public.people p where p.account = c.owner),
        'count', public.collection_count(c.id, false, tests),
        'all', public.collection_count(c.id, true, tests))
      from public.model_collections c
     where c.id = list
       and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
$$;

create or replace function public.collection_page(list text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select public.collection_page(list, false)
$$;

-- A model's page, as directory.sql made it, its remixes in the gallery
-- without test models: a test model's own page, which only a probe has the
-- link to, shows its test remixes.
create or replace function public.directory_model(model_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    -- Each model it came from, by how far back: 1 is the one it was
    -- copied from. A line goes back past a model only while it is up.
    with recursive up (id, depth) as (
        select m.remixed_from, 1
          from public.shared_models m
         where m.id = model_id and m.published and m.remixed_from is not null
        union all
        select p.remixed_from, up.depth + 1
          from up
          join public.shared_models p on p.id = up.id
         where up.depth < 8 and p.published and p.remixed_from is not null
    )
    select public.directory_card(m) || jsonb_build_object(
        'description', m.description,
        'listed', m.listed,
        'from', coalesce((
            select jsonb_agg(
                case when p.published and p.listed and not p.barred
                     then jsonb_build_object('id', p.id, 'name', p.name, 'author', p.author)
                     else jsonb_build_object('id', null, 'by_link', true) end
                order by up.depth)
              from up
              join public.shared_models p on p.id = up.id
             where p.published), '[]'::jsonb),
        'remixes_listed', coalesce((
            select jsonb_agg(public.directory_card(r) order by r.listed_at desc, r.id desc)
              from public.shared_models r
             where r.id in (
                 select c.id from public.shared_models c
                  where c.remixed_from = m.id and c.published and c.listed and not c.barred
                    and (not c.test or m.test)
                  order by c.listed_at desc, c.id desc
                  limit 24)), '[]'::jsonb))
      from public.shared_models m
     where m.id = model_id and m.published
$$;

-- What /sitemap.xml lists, as moderation.sql made it, and never a test
-- model, nor a profile or a collection with nothing else in the gallery.
create or replace function public.sitemap_pages()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'models', coalesce((
            select jsonb_agg(jsonb_build_object('id', m.id, 'updated_at', m.updated_at)
                             order by m.listed_at desc)
              from (select id, updated_at, listed_at from public.shared_models s
                     where s.listed and s.published and not s.barred and not s.test
                       and not exists (select 1 from public.barred_accounts b where b.account = s.owner)
                     order by s.listed_at desc
                     limit 20000) m), '[]'::jsonb),
        'people', coalesce((
            select jsonb_agg(jsonb_build_object('handle', p.handle, 'updated_at', p.updated_at))
              from public.people p
             where not exists (select 1 from public.barred_accounts b where b.account = p.account)
               and exists (select 1 from public.shared_models m
                            where m.owner = p.account and m.listed and m.published
                              and not m.barred and not m.test and m.author is not null)), '[]'::jsonb),
        'collections', coalesce((
            select jsonb_agg(jsonb_build_object('id', c.id, 'updated_at', c.updated_at))
              from public.model_collections c
             where c.public
               and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
               and public.collection_count(c.id, false, false) > 0), '[]'::jsonb))
$$;

-- Every one the server's alone, as before.
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;
revoke all on function public.collection_count(text, boolean, boolean) from public, anon, authenticated;
grant execute on function public.collection_count(text, boolean, boolean) to service_role;
revoke all on function public.collection_count(text, boolean) from public, anon, authenticated;
grant execute on function public.collection_count(text, boolean) to service_role;
revoke all on function public.profile_page(text, boolean) from public, anon, authenticated;
grant execute on function public.profile_page(text, boolean) to service_role;
revoke all on function public.profile_page(text) from public, anon, authenticated;
grant execute on function public.profile_page(text) to service_role;
revoke all on function public.collection_page(text, boolean) from public, anon, authenticated;
grant execute on function public.collection_page(text, boolean) to service_role;
revoke all on function public.collection_page(text) from public, anon, authenticated;
grant execute on function public.collection_page(text) to service_role;
revoke all on function public.directory_model(text) from public, anon, authenticated;
grant execute on function public.directory_model(text) to service_role;
revoke all on function public.sitemap_pages() from public, anon, authenticated;
grant execute on function public.sitemap_pages() to service_role;
