-- Keeping the directory fit to look at, 2026-10-13.
--
-- Strangers list models, name them, describe them and choose handles, so
-- somebody has to be able to say "this should not be here" and the site's
-- owner has to be able to act on it, for good. The gallery (gallery.sql)
-- could take one model out: barred, so its owner could not list it again —
-- at that link. Published again at a new link, or from another copy, it
-- was back. Now:
--
--   reports           what a visitor said should not be here, and why: a
--                     model, a profile or a collection, a reason, a note,
--                     a way to reach them if they are its rightful owner;
--                     open until the site's owner acts on it
--   barred_accounts   an account taken out of the gallery: none of its
--                     models listed, none listed again, no profile shown
--   barred_models     the files of models taken out, by their SHA-256, so
--                     the same model published again at another link
--                     cannot be listed either
--   act_log, may_act  how often an account or a visitor has done a thing
--                     — reported, liked, made a list — and whether they
--                     may again, counted in one call as may_publish is
--
-- And the directory's functions again (directory.sql, people.sql), the
-- same but for one thing: nothing of a barred account is shown.
--
-- Only additions: new tables and functions, and those functions replaced.
-- No existing row is changed. Every table is the server's alone.

create table if not exists public.reports (
    id          bigserial primary key,
    model       text references public.shared_models (id) on delete cascade,
    handle      text,
    collection  text references public.model_collections (id) on delete cascade,
    reason      text not null check (reason in ('spam', 'offensive', 'sexual', 'violent',
                    'copied', 'trademark', 'personal', 'other')),
    note        text check (note is null or char_length(note) between 1 and 1000),
    contact     text check (contact is null or char_length(contact) between 3 and 200),
    reporter    uuid references auth.users (id) on delete set null,
    visitor     text check (visitor is null or visitor ~ '^[0-9a-f]{32}$'),
    at          timestamptz not null default now(),
    resolved_at timestamptz,
    resolution  text check (resolution is null or resolution in ('dismissed', 'taken_out', 'account_barred')),
    check (num_nonnulls(model, handle, collection) = 1)
);
create index if not exists reports_open on public.reports (at desc) where resolved_at is null;
create index if not exists reports_model on public.reports (model) where model is not null;
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

create table if not exists public.barred_accounts (
    account  uuid primary key references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    reason   text check (reason is null or char_length(reason) <= 200)
);
alter table public.barred_accounts enable row level security;
revoke all on public.barred_accounts from anon, authenticated;

create table if not exists public.barred_models (
    hash   text primary key check (hash ~ '^[0-9a-f]{64}$'),
    model  text,
    at     timestamptz not null default now()
);
alter table public.barred_models enable row level security;
revoke all on public.barred_models from anon, authenticated;

create table if not exists public.act_log (
    id      bigserial primary key,
    who     text not null check (char_length(who) between 1 and 64),
    action  text not null check (action ~ '^[a-z_]{2,24}$'),
    at      timestamptz not null default now()
);
create index if not exists act_log_who on public.act_log (who, action, at desc);
alter table public.act_log enable row level security;
revoke all on public.act_log from anon, authenticated;

-- Do a thing once, and say whether that was allowed: so many an hour and
-- so many a day for one account or one visitor, counted and recorded in
-- one call under its own advisory lock, the day's older rows let go.
create or replace function public.may_act(
    actor text, act text, per_hour integer, per_day integer)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    last_hour integer;
    last_day integer;
begin
    perform pg_advisory_xact_lock(hashtext('may_act:' || actor || ':' || act));
    delete from public.act_log where who = actor and action = act and at < now() - interval '1 day';
    select count(*) filter (where at >= now() - interval '1 hour'), count(*)
      into last_hour, last_day
      from public.act_log
     where who = actor and action = act;
    if last_hour >= per_hour or last_day >= per_day then
        return false;
    end if;
    insert into public.act_log (who, action) values (actor, act);
    return true;
end;
$$;
revoke all on function public.may_act(text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.may_act(text, text, integer, integer) to service_role;

-- Whether an account is out of the gallery.
create or replace function public.is_barred(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (select 1 from public.barred_accounts b where b.account = is_barred.account)
$$;
revoke all on function public.is_barred(uuid) from public, anon, authenticated;
grant execute on function public.is_barred(uuid) to service_role;

-- The list, a profile and a collection, as people.sql made them, with
-- nothing of a barred account shown: its models are taken out of the
-- gallery when it is barred (api/admin.js), and these say so again, so no
-- model of it, profile or public list is in any answer while it is.
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
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
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
       and not exists (select 1 from public.barred_accounts b where b.account = p.account)
$$;


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
       and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
$$;


revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;
revoke all on function public.profile_page(text) from public, anon, authenticated;
grant execute on function public.profile_page(text) to service_role;
revoke all on function public.collection_page(text) from public, anon, authenticated;
grant execute on function public.collection_page(text) to service_role;

-- What /sitemap.xml lists of the directory (api/share.js): every listed
-- model, every profile with a model in the gallery, every public
-- collection with one; never anything of a barred account.
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
                     where s.listed and s.published and not s.barred
                       and not exists (select 1 from public.barred_accounts b where b.account = s.owner)
                     order by s.listed_at desc
                     limit 20000) m), '[]'::jsonb),
        'people', coalesce((
            select jsonb_agg(jsonb_build_object('handle', p.handle, 'updated_at', p.updated_at))
              from public.people p
             where not exists (select 1 from public.barred_accounts b where b.account = p.account)
               and exists (select 1 from public.shared_models m
                            where m.owner = p.account and m.listed and m.published
                              and not m.barred and m.author is not null)), '[]'::jsonb),
        'collections', coalesce((
            select jsonb_agg(jsonb_build_object('id', c.id, 'updated_at', c.updated_at))
              from public.model_collections c
             where c.public
               and not exists (select 1 from public.barred_accounts b where b.account = c.owner)
               and public.collection_count(c.id, false) > 0), '[]'::jsonb))
$$;
revoke all on function public.sitemap_pages() from public, anon, authenticated;
grant execute on function public.sitemap_pages() to service_role;
