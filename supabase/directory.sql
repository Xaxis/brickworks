-- The directory: the gallery searched, filtered and sorted, and each
-- model's page with what its owner said about it, 2026-10-13.
--
-- The gallery (gallery.sql) listed what people chose to share, newest
-- first and nothing else. Now a listed model also carries what its owner
-- wrote in the Share panel — a description, tags, a kind and a licence —
-- and what the server worked out from the file itself: how many build
-- steps it has and whether they are its builder's own, and whether it is
-- Technic or a mechanism. https://brickworks.diy/gallery searches and
-- filters on those (api/share.js ?op=list, through directory_models), and
-- /m/<id> shows them with its counts and its remix tree (directory_model).
--
-- Only additions to shared_models.sql and gallery.sql, applied after
-- them: new columns (each null or empty on the rows already there, which
-- this file does not touch), indexes, two tables of counts, and functions.
--
--   description  what its owner wrote about it, up to 1000 characters,
--                kept as typed (api/share.js takes out control characters)
--                and escaped on every page that shows it.
--   tags         up to 8 words or short phrases, lower case.
--   licence      cc-by-4.0, cc-by-sa-4.0 or all-rights-reserved; null for
--                a model shared before there was a choice, which no page
--                presents as licensed.
--   kind         the kind of model, one of the directory's kinds
--                (api/_directory.js KINDS, src/net/model_kinds.gd): the
--                Share panel guesses it from the name and the tags with
--                the subject vocabulary and its owner can change it. The
--                database checks the shape; the server checks the list.
--   steps        how many build steps the file has, counted by the server.
--   own_steps    whether those steps are the builder's own rather than
--                ones Brickworks worked out (LdrModel.steps_are_authored):
--                "has instructions" in the gallery.
--   technic      whether it is Technic or a mechanism: two or more gears,
--                motors and the like, or a quarter of it Technic parts,
--                counted by the server against the catalogue.
--   has_thumb    whether it has a small picture for the gallery's cards,
--                <id>.webp in the shared-thumbs bucket.
--   search       its words, for the gallery's search box: the name and
--                the tags first, then the credit, then the description.

create or replace function public.directory_tags_ok(tags text[])
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
    select tags is not null
       and coalesce(array_length(tags, 1), 0) <= 8
       and not exists (
           select 1 from unnest(tags) as tag
            where tag is null
               or char_length(tag) not between 2 and 24
               or tag <> lower(tag)
               or tag ~ '[[:cntrl:],<>"&]')
$$;

-- The words of a model, as the search box looks for them. 'simple': no
-- stop words and no stemming, so a search for "the" or for an author's
-- name is not thrown away; api/share.js makes each word of a search a
-- prefix (castle:*), so "castles" and "cast" find a castle.
create or replace function public.directory_words(
    name text, author text, description text, tags text[])
returns tsvector
language sql
immutable
parallel safe
set search_path = ''
as $$
    select setweight(to_tsvector('simple'::regconfig, coalesce(name, '')), 'A')
        || setweight(to_tsvector('simple'::regconfig, coalesce(array_to_string(tags, ' '), '')), 'A')
        || setweight(to_tsvector('simple'::regconfig, coalesce(author, '')), 'B')
        || setweight(to_tsvector('simple'::regconfig, coalesce(description, '')), 'C')
$$;

alter table public.shared_models
    add column if not exists description text
        check (description is null or char_length(description) between 1 and 1000);
alter table public.shared_models
    add column if not exists tags text[] not null default '{}'
        check (public.directory_tags_ok(tags));
alter table public.shared_models
    add column if not exists licence text
        check (licence is null or licence in ('cc-by-4.0', 'cc-by-sa-4.0', 'all-rights-reserved'));
alter table public.shared_models
    add column if not exists kind text
        check (kind is null or kind ~ '^[a-z]{2,16}$');
alter table public.shared_models
    add column if not exists steps integer
        check (steps is null or steps between 1 and 200000);
alter table public.shared_models
    add column if not exists own_steps boolean;
alter table public.shared_models
    add column if not exists technic boolean;
alter table public.shared_models
    add column if not exists has_thumb boolean not null default false;
alter table public.shared_models
    add column if not exists search tsvector
        generated always as (public.directory_words(name, author, description, tags)) stored;

-- The small pictures, <id>.webp, in a private bucket of their own: the
-- shared-models bucket takes only its own two kinds of file and is left as
-- it is. No policy names it; the server reads it with the secret key after
-- a visitor's read has found the model published, as for the others.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shared-thumbs', 'shared-thumbs', false, 65536, array['image/webp'])
on conflict (id) do nothing;

-- What a visitor reads of a row, granted column by column as the rest are.
-- Never search, which is only the words again.
grant select (description, tags, licence, kind, steps, own_steps, technic, has_thumb)
    on public.shared_models to anon, authenticated;

-- The gallery's questions, all of them about the listed, published rows.
create index if not exists shared_models_search
    on public.shared_models using gin (search)
    where listed and published;
create index if not exists shared_models_tags
    on public.shared_models using gin (tags)
    where listed and published;
create index if not exists shared_models_kind
    on public.shared_models (kind, listed_at desc)
    where listed and published;
-- A model's remixes, counted and listed on its page.
create index if not exists shared_models_remixes
    on public.shared_models (remixed_from)
    where remixed_from is not null;

-- How many people looked at a model, and how many liked it: a row per
-- model, kept by count_view here and by the likes of a later file, so the
-- shared_models rows themselves are never written for a count. No policy:
-- only the server reads it, through the functions below.
create table if not exists public.model_stats (
    model  text primary key references public.shared_models (id) on delete cascade,
    views  integer not null default 0 check (views >= 0),
    likes  integer not null default 0 check (likes >= 0)
);
alter table public.model_stats enable row level security;
revoke all on public.model_stats from anon, authenticated;

-- Who looked, as a key that cannot be turned back into anybody: a hash of
-- the day, the address and the browser with a secret only the server has
-- (api/share.js), so a visitor is counted once a day and cannot be
-- followed from one day to the next. The day is in the key and in the row;
-- the daily sweep keeps only today's and yesterday's.
create table if not exists public.model_views (
    model    text not null references public.shared_models (id) on delete cascade,
    day      date not null default current_date,
    visitor  text not null check (visitor ~ '^[0-9a-f]{32}$'),
    primary key (model, day, visitor)
);
alter table public.model_views enable row level security;
revoke all on public.model_views from anon, authenticated;

-- A view, counted once per visitor per day, and only of a published
-- model: true when it was counted. One call, two short writes, and none
-- at all for a visitor already counted today.
create or replace function public.count_view(model_id text, visitor_key text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    added integer;
begin
    insert into public.model_views (model, visitor)
        select model_id, visitor_key
         where exists (select 1 from public.shared_models
                        where id = model_id and published)
        on conflict do nothing;
    get diagnostics added = row_count;
    if added = 0 then
        return false;
    end if;
    insert into public.model_stats (model, views) values (model_id, 1)
        on conflict (model) do update set views = public.model_stats.views + 1;
    return true;
end;
$$;
revoke all on function public.count_view(text, text) from public, anon, authenticated;
grant execute on function public.count_view(text, text) to service_role;

-- A model's card, as every list gives it: what a visitor may read of the
-- row, and its counts.
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
                     where r.remixed_from = m.id and r.published))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;

-- The gallery's list: the listed, published models a query asks for, a
-- page at a time, each as a card, in order. One jsonb argument, so that a
-- later file can ask more of it without a second function beside it:
--
--   words        a tsquery over search, made by api/share.js from what was
--                typed (each word a prefix, joined with &)
--   kind, tag    one kind; one tag
--   least, most  the part count's bounds
--   own_steps    true: only models with their builder's own steps
--   technic      true: only Technic models and mechanisms
--   sort         newest (when listed), views, likes or remixes
--   size, skip   the page: at most 49 (a page and one more, to know
--                whether there is another), and how many to skip
--
-- Security definer, so it says for itself what a visitor may see: listed,
-- published and not barred; and it gives only a card of each.
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
     where m.listed and m.published and not m.barred
       and (a.words is null or m.search @@ to_tsquery('simple'::regconfig, a.words))
       and (a.kind is null or m.kind = a.kind)
       and (a.tag is null or m.tags @> array[a.tag])
       and (a.least_parts is null or m.parts >= a.least_parts)
       and (a.most_parts is null or m.parts <= a.most_parts)
       and (not a.own_steps or m.own_steps)
       and (not a.technic or m.technic)
     order by
        case when a.sort = 'views' then coalesce(s.views, 0) end desc nulls last,
        case when a.sort = 'likes' then coalesce(s.likes, 0) end desc nulls last,
        case when a.sort = 'remixes' then rx.n end desc nulls last,
        m.listed_at desc, m.id desc
     limit (select size from asked) offset (select skip from asked)
$$;
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;

-- One model's page: its card and its description, and its remix tree —
-- what it came from, as far back as eight links, and what was remixed
-- from it. Null unless the model is published. A model it came from is
-- named only while it is listed: one shared by link alone is "a model
-- shared by link", so listing a remix does not make public a link its
-- owner only sent to some people; one taken down ends the line.
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
                  order by c.listed_at desc, c.id desc
                  limit 24)), '[]'::jsonb))
      from public.shared_models m
     where m.id = model_id and m.published
$$;
revoke all on function public.directory_model(text) from public, anon, authenticated;
grant execute on function public.directory_model(text) to service_role;
