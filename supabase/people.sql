-- People in the directory, and what they like, 2026-10-13.
--
-- The directory (directory.sql) is of models. This is of the people who
-- share them, and what the people who look at them do there: a profile at
-- https://brickworks.diy/u/<handle>, with a name its owner chooses — never
-- one made from their email address — listing the models they listed and
-- chose to be credited for; likes, counted on each model; favourites,
-- private to whoever keeps them; and collections, named lists of models,
-- public or private (api/people.js).
--
-- Only additions, applied after directory.sql: new tables, a trigger on
-- one of them, and functions. No existing row is changed. The profile is
-- people, not profiles: schema.sql's profiles is one row per account with
-- its address in it, readable by its owner, and is left exactly as it is. Every table is
-- the server's alone (row security on, no policies, nothing granted to the
-- publishable key), as the relay's and the connector's are: what a visitor
-- may see of them they see through api/people.js, which asks these
-- functions, each of which says for itself what is public.
--
--   people                   one per account that wants a profile: a handle (3 to
--                            24 of a-z, 0-9 and single hyphens, not at an
--                            end), a name (1 to 40 printable characters)
--                            and a few words about them (up to 300)
--   model_likes              who liked which model; model_stats.likes
--                            counts them, kept by a trigger
--   model_favourites         who keeps which model to come back to
--   model_collections        a named list of models (10-character id as a
--                            link's, a name, a description, public or not)
--   model_collection_items   which models are in which list, and since when

create table if not exists public.people (
    account     uuid primary key references auth.users (id) on delete cascade,
    handle      text not null unique
                check (handle ~ '^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$' and handle !~ '--'),
    name        text not null check (char_length(name) between 1 and 40),
    bio         text check (bio is null or char_length(bio) between 1 and 300),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);
alter table public.people enable row level security;
revoke all on public.people from anon, authenticated;

create table if not exists public.model_likes (
    model    text not null references public.shared_models (id) on delete cascade,
    account  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (model, account)
);
create index if not exists model_likes_account on public.model_likes (account, at desc);
alter table public.model_likes enable row level security;
revoke all on public.model_likes from anon, authenticated;

create table if not exists public.model_favourites (
    model    text not null references public.shared_models (id) on delete cascade,
    account  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (model, account)
);
create index if not exists model_favourites_account on public.model_favourites (account, at desc);
alter table public.model_favourites enable row level security;
revoke all on public.model_favourites from anon, authenticated;

create table if not exists public.model_collections (
    id           text primary key check (id ~ '^[A-Za-z0-9]{10}$'),
    owner        uuid not null references auth.users (id) on delete cascade,
    name         text not null check (char_length(name) between 1 and 80),
    description  text check (description is null or char_length(description) between 1 and 500),
    public       boolean not null default false,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);
create index if not exists model_collections_owner on public.model_collections (owner, updated_at desc);
alter table public.model_collections enable row level security;
revoke all on public.model_collections from anon, authenticated;

create table if not exists public.model_collection_items (
    collection  text not null references public.model_collections (id) on delete cascade,
    model       text not null references public.shared_models (id) on delete cascade,
    at          timestamptz not null default now(),
    primary key (collection, model)
);
create index if not exists model_collection_items_model on public.model_collection_items (model);
alter table public.model_collection_items enable row level security;
revoke all on public.model_collection_items from anon, authenticated;

-- A like counted on its model as it is made and unmade, and when an
-- account goes with its likes. One row of model_stats per model, never the
-- model's own row.
create or replace function public.model_likes_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.model_stats (model, likes) values (new.model, 1)
            on conflict (model) do update set likes = public.model_stats.likes + 1;
    elsif tg_op = 'DELETE' then
        update public.model_stats set likes = greatest(likes - 1, 0) where model = old.model;
    end if;
    return null;
end;
$$;
revoke all on function public.model_likes_count() from public, anon, authenticated;
create or replace trigger model_likes_count
    after insert or delete on public.model_likes
    for each row execute function public.model_likes_count();

-- A card, as directory.sql made it, and who shared it: their profile's
-- handle and name, but only for a model they chose to be credited for —
-- one shared without a name stays without one.
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
                where p.account = m.owner and m.author is not null))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- The list, as directory.sql made it, asked more of: besides its words,
-- kind, tag, size, steps, Technic and sort,
--
--   owner        a person's models, for their profile: listed, and only
--                those they chose to be credited for
--   collection   the models in a list, in the order they were put there
--                (sort "added")
--   favourites   the models an account keeps
--   private      true when the account asking is the list's own (the API
--                says so, never the caller): then a model shared by link
--                only, which they had, is in it too; otherwise only listed
--
-- And never a model that is not published, or that was barred.
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
       and (m.listed or a.private)
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

-- How many models a list shows: the listed ones, or with private, every
-- published one in it (its owner's view).
create or replace function public.collection_count(list text, private boolean)
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
$$;

-- A person's profile as anyone may see it, by its handle: their name,
-- what they said, since when, how many models they are credited for in
-- the gallery and how many likes those have, and their public lists.
-- Null for a handle nobody has.
create or replace function public.profile_page(wanted text)
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
                      and not m.barred and m.author is not null),
        'likes', (select coalesce(sum(s.likes), 0) from public.shared_models m
                    join public.model_stats s on s.model = m.id
                   where m.owner = p.account and m.published and m.listed
                     and not m.barred and m.author is not null),
        'collections', coalesce((
            select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name,
                       'description', c.description, 'count', public.collection_count(c.id, false))
                       order by c.updated_at desc)
              from public.model_collections c
             where c.owner = p.account and c.public), '[]'::jsonb))
      from public.people p
     where p.handle = lower(wanted)
$$;

-- A list as its page shows it: its name, what it is, whose (by their
-- profile, if they have one), how many models, whether public. The API
-- shows a private one only to its owner.
create or replace function public.collection_page(list text)
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
        'count', public.collection_count(c.id, false),
        'all', public.collection_count(c.id, true))
      from public.model_collections c
     where c.id = list
$$;

revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;
revoke all on function public.profile_page(text) from public, anon, authenticated;
grant execute on function public.profile_page(text) to service_role;
revoke all on function public.collection_count(text, boolean) from public, anon, authenticated;
grant execute on function public.collection_count(text, boolean) to service_role;
revoke all on function public.collection_page(text) from public, anon, authenticated;
grant execute on function public.collection_page(text) to service_role;
