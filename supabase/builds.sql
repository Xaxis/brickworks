-- Real builds, 2026-10-18: builds finished, and photos of them.
--
-- A designer never learned who built their model, and a visitor could not
-- tell a model people build from one people only look at. Now two things
-- are counted and kept:
--
--   model_builds    a model built to its last step, in the step player or
--                   the viewer, once per device: the app sends it when the
--                   last step is reached from the step before (src/main.gd),
--                   with a key the device made for itself, at random, and
--                   keeps; api/share.js ?op=built keeps an HMAC of the
--                   model and that key, never the key, and counts it only
--                   for what looks like a person, as views are counted. No
--                   account, nothing about anybody: a row says that some
--                   device finished this model, and when.
--   model_stats.builds   how many, beside views and likes: "12 built" on the
--                   model's page and its card, and the gallery's Most built.
--
--   build_photos    "I built it": a photo of the real build, with a line, by
--                   an account that said it is 13 or over (trust.sql). The
--                   picture is never the file that was sent: api/_photo.js
--                   decodes it to its pixels and makes a new JPEG of them,
--                   which carries no metadata at all (no place, no time, no
--                   phone), and refuses anything that does not decode as a
--                   JPEG, a PNG or a WebP. At most three an account on a
--                   model, refused here as in the API.
--     hidden_at     hidden by the model's owner, on their own model's page:
--                   no longer shown to anybody else
--     removed_at    taken out by the site's owner (api/admin.js, from a
--                   report): its file deleted from storage, the row kept to
--                   say so, and shown nowhere
--   report_photos   a report about a photo (api/people.js ?op=report with
--                   photo): the report is about the photo's model as far as
--                   reports' own check goes, and this says which photo, so
--                   the admin page shows the photo and removes it.
--
-- And the functions that show models, the same but for what this adds:
-- the card has its builds (directory_card, which also keeps trust.sql's
-- rule for the credited name and tested.sql's mark: whichever of those two
-- files went in last had dropped the other's), the gallery sorts by them
-- (directory_models, sort builds), and a report about a photo goes in the
-- digest of whoever posted it when that is a test account, and is named a
-- photo in the email (report_stream, claim_report_digest).
--
-- The files. Two new private buckets, and nothing that exists changes:
--
--   build-photo-uploads   what a phone sends, as it sent it, at most 8 MB,
--                         JPEG, PNG or WebP: written only through an upload
--                         URL the server signs for one path, <account>/<n>
--                         (api/_builds.js), read once by the server, and
--                         deleted at once, whatever came of it; the daily
--                         sweep takes any left an hour old
--   build-photos          the photo made from it, <photo id>.jpg, at most
--                         1,600 pixels on its long side: read only by the
--                         server, for a visitor, after the photo's row says
--                         it may be shown
--
-- Who may do what: only the server. No grant and no policy for any key a
-- page has, on the tables or the buckets.
--
-- Only additions, applied last of the release's four: tested.sql,
-- trust.sql, comments.sql, then this. New tables, one new column on
-- model_stats (zero on every row), two buckets, a trigger that refuses, new
-- functions, and four functions replaced, each with what the files before
-- it had added kept and one thing more:
--
--   directory_card      supersedes tested.sql's (the Tested mark) and
--                       trust.sql's (no credited name of an account under
--                       13), each of which dropped the other's; both kept,
--                       and builds added
--   directory_models    supersedes tested.sql's (Tested only, and the test
--                       models of test_models.sql); the same, and the
--                       builds sort added
--   report_stream       supersedes comments.sql's, itself trust.sql's with
--                       a comment's writer; the same, and a photo's poster
--                       beside the writer
--   claim_report_digest supersedes comments.sql's, itself trust.sql's with
--                       the comment and its first words; the same, and the
--                       photo
--
-- No existing row is changed, nothing dropped or renamed.

-- ---------------------------------------------------------------------------
-- Builds finished.

create table if not exists public.model_builds (
    model   text not null references public.shared_models (id) on delete cascade,
    device  text not null check (device ~ '^[0-9a-f]{32}$'),
    at      timestamptz not null default now(),
    primary key (model, device)
);
alter table public.model_builds enable row level security;
revoke all on public.model_builds from anon, authenticated;

alter table public.model_stats
    add column if not exists builds integer not null default 0 check (builds >= 0);

-- A build finished, counted once per device, and only of a published
-- model: true when it was counted, as count_view.
create or replace function public.count_build(model_id text, device_key text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    added integer;
begin
    insert into public.model_builds (model, device)
        select model_id, device_key
         where exists (select 1 from public.shared_models
                        where id = model_id and published)
        on conflict do nothing;
    get diagnostics added = row_count;
    if added = 0 then
        return false;
    end if;
    insert into public.model_stats (model, builds) values (model_id, 1)
        on conflict (model) do update set builds = public.model_stats.builds + 1;
    return true;
end;
$$;
revoke all on function public.count_build(text, text) from public, anon, authenticated;
grant execute on function public.count_build(text, text) to service_role;

-- ---------------------------------------------------------------------------
-- Photos of builds.

create table if not exists public.build_photos (
    id          text primary key check (id ~ '^[A-Za-z0-9]{10}$'),
    model       text not null references public.shared_models (id) on delete cascade,
    account     uuid not null references auth.users (id) on delete cascade,
    words       text check (words is null or char_length(words) between 1 and 140),
    width       integer not null check (width between 1 and 1600),
    height      integer not null check (height between 1 and 1600),
    bytes       integer not null check (bytes between 1 and 4194304),
    was         text not null check (was in ('jpeg', 'png', 'webp')),
    at          timestamptz not null default now(),
    hidden_at   timestamptz,
    removed_at  timestamptz,
    removed_why text check (removed_why is null or char_length(removed_why) between 1 and 200)
);
create index if not exists build_photos_model on public.build_photos (model, at desc) where removed_at is null;
create index if not exists build_photos_account on public.build_photos (account, at desc) where removed_at is null;
alter table public.build_photos enable row level security;
revoke all on public.build_photos from anon, authenticated;

-- A photo needs an account that said it is 13 or over, and an account has
-- at most three on a model (one taken out by the site's owner not counted).
create or replace function public.build_photos_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.trust_may_go_public(new.account) then
        raise exception 'brickworks: a photo of a build is for accounts 13 or over'
            using errcode = 'P0001', hint = 'trust:photo';
    end if;
    perform pg_advisory_xact_lock(hashtext('build_photos:' || new.account::text || ':' || new.model));
    if (select count(*) from public.build_photos p
         where p.account = new.account and p.model = new.model and p.removed_at is null) >= 3 then
        raise exception 'brickworks: three photos of a model at most'
            using errcode = 'P0001', hint = 'builds:three';
    end if;
    return new;
end;
$$;
create or replace trigger build_photos_guard
    before insert on public.build_photos
    for each row execute function public.build_photos_guard();
revoke all on function public.build_photos_guard() from public, anon, authenticated;

create table if not exists public.report_photos (
    report  bigint primary key references public.reports (id) on delete cascade,
    photo   text not null references public.build_photos (id) on delete cascade
);
create index if not exists report_photos_photo on public.report_photos (photo);
alter table public.report_photos enable row level security;
revoke all on public.report_photos from anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('build-photo-uploads', 'build-photo-uploads', false, 8388608,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('build-photos', 'build-photos', false, 4194304, array['image/jpeg'])
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- The functions that show models, with their builds.

-- A card, as tested.sql made it, with trust.sql's rule for whose name is
-- on it, and how many have built it.
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
        'builds', coalesce(s.builds, 0),
        'remixes', (select count(*) from public.shared_models r
                     where r.remixed_from = m.id and r.published),
        'by', (select jsonb_build_object('handle', p.handle, 'name', p.name)
                 from public.people p
                where p.account = m.owner and m.author is not null
                  and not public.trust_kept_private(m.owner)),
        'tested', public.model_tested(m.id))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;

-- The list, as tested.sql made it, and one sort more: builds, most first.
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
        case when a.sort = 'builds' then coalesce(s.builds, 0) end desc nulls last,
        m.listed_at desc nulls last, m.updated_at desc, m.id desc
     limit (select size from asked) offset (select skip from asked)
$$;
revoke all on function public.directory_models(jsonb) from public, anon, authenticated;
grant execute on function public.directory_models(jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Reports about photos.

-- Which digest a report belongs in, as comments.sql says (trust.sql's,
-- and a test's for a comment a test account wrote), and a test's too for a
-- photo a test account posted, wherever it was posted.
create or replace function public.report_stream(r public.reports)
returns text
language sql
stable
security definer
set search_path = public
as $$
    with whose as (
        select coalesce(
            (select m.owner from public.shared_models m where m.id = r.model),
            (select c.owner from public.model_collections c where c.id = r.collection),
            (select p.account from public.people p where p.handle = r.handle)) as owner,
            (select k.author from public.model_comments k where k.id = r.comment) as writer,
            (select b.account from public.report_photos rp
               join public.build_photos b on b.id = rp.photo
              where rp.report = r.id) as poster)
    select case
        when w.owner is null and r.handle is not null then null
        when w.owner is not null and public.trust_is_test_account(w.owner) then 'test:' || w.owner::text
        when w.writer is not null and public.trust_is_test_account(w.writer) then 'test:' || w.writer::text
        when w.poster is not null and public.trust_is_test_account(w.poster) then 'test:' || w.poster::text
        when r.reporter is not null and public.trust_is_test_account(r.reporter) then 'test:' || r.reporter::text
        else 'owner' end
      from whose w
$$;
revoke all on function public.report_stream(public.reports) from public, anon, authenticated;
grant execute on function public.report_stream(public.reports) to service_role;

-- A digest, as comments.sql makes it (trust.sql's, with the comment a
-- report is about and its first words), each report saying which photo it
-- is about when it is about one (api/_trust.js names each so in the email).
create or replace function public.claim_report_digest(wanted text default 'owner', report bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    stream_of text := wanted;
    ids bigint[];
    waiting integer;
    made bigint;
begin
    if report is not null then
        select public.report_stream(r) into stream_of from public.reports r where r.id = report;
    end if;
    if stream_of is null or not (stream_of = 'owner' or stream_of ~ '^test:[0-9a-f-]{36}$') then
        return null;
    end if;
    perform pg_advisory_xact_lock(hashtext('report_digest:' || stream_of));
    if exists (select 1 from public.report_digests d
                where d.stream = stream_of and d.state <> 'failed'
                  and d.at >= date_trunc('hour', now())) then
        return null;
    end if;
    select array_agg(id order by at), count(*)::integer into ids, waiting
      from (select r.id, r.at
              from public.reports r
              left join public.report_digests d on d.id = r.digest
             where r.resolved_at is null
               and (r.digest is null or d.state = 'failed'
                    or (d.state = 'sending' and d.at < now() - interval '15 minutes'))
               and public.report_stream(r) = stream_of) w;
    if ids is null then
        return null;
    end if;
    ids := ids[1:100];
    insert into public.report_digests (stream, reports)
    values (stream_of, coalesce(array_length(ids, 1), 0))
    returning id into made;
    update public.reports set digest = made where id = any (ids);
    return jsonb_build_object(
        'digest', made,
        'stream', stream_of,
        'more', waiting - coalesce(array_length(ids, 1), 0),
        'reports', (
            select jsonb_agg(jsonb_build_object(
                       'id', r.id, 'at', r.at, 'reason', r.reason, 'note', r.note,
                       'model', r.model, 'handle', r.handle, 'collection', r.collection,
                       'comment', r.comment, 'said', left(k.body, 240),
                       'photo', rp.photo,
                       'name', coalesce(m.name, c.name, p.name))
                       order by r.at)
              from public.reports r
              left join public.shared_models m on m.id = r.model
              left join public.model_collections c on c.id = r.collection
              left join public.people p on p.handle = r.handle
              left join public.model_comments k on k.id = r.comment
              left join public.report_photos rp on rp.report = r.id
             where r.id = any (ids)));
end;
$$;
revoke all on function public.claim_report_digest(text, bigint) from public, anon, authenticated;
grant execute on function public.claim_report_digest(text, bigint) to service_role;
