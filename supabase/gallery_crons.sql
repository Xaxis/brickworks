-- The gallery keeps itself fresh, 2026-10-29 (gallery362).
--
-- The gallery changed only when somebody posted. Now Vercel's crons
-- (tools/deploy.sh) choose what its front leads with, from what people did,
-- once a day, and look once a week for what LDraw's Official Model
-- Repository has added, and every run is written down:
--
--   gallery_features   what the front shows, one row a slot a day:
--                      featured   today's featured model, of the gallery
--                      pick       this week's pick (day: the week's Monday),
--                                 unless the site's owner chose one
--                                 (discovery.sql's gallery_picks, which wins)
--                      library    today's set from the LDraw library (item:
--                                 its id in the store's index, as
--                                 api/_library.js reads it)
--                      Chosen by api/_featured.js from the signals here (the
--                      rules are there, with their tests); kept once, so a
--                      second run on the same day changes nothing, and the
--                      page reads the choice: nothing is drawn at random.
--   cron_runs          every run of a cron: which, when, how it ended
--                      (done, unchanged, locked, failed) and what it said
--   cron_locks         one row a cron while a run of it holds it, until
--                      the run ends or its lease runs out: a second run
--                      that starts meanwhile is written down as locked and
--                      does nothing
--   library_arrivals   what the weekly look at the OMR found that the
--                      library has not got: a set's page, its number, name,
--                      main file and that file's stamp. found until
--                      tools/library_import.py draws and stages it (staged,
--                      shown only to a list asked with tests=1), live once
--                      the lead lets it out, refused (and why) when it fails
--                      our own checks.
--
-- Who may touch what: only the server, through the functions here, each
-- granted to the service role alone; no key a page has reaches a table.
--
-- Only additions: four tables and new functions. Nothing it replaces.

-- ---------------------------------------------------------------------------
-- The runs, and the lock against two at once.

create table if not exists public.cron_runs (
    id           bigint generated always as identity primary key,
    job          text not null check (job ~ '^[a-z][a-z_]{0,39}$'),
    holder       text not null check (char_length(holder) between 1 and 80),
    started_at   timestamptz not null default now(),
    finished_at  timestamptz,
    outcome      text check (outcome is null or outcome in ('done', 'unchanged', 'locked', 'failed')),
    said         jsonb not null default '{}'::jsonb check (pg_column_size(said) <= 16000),
    check ((finished_at is null) = (outcome is null))
);
create index if not exists cron_runs_job on public.cron_runs (job, started_at desc);
alter table public.cron_runs enable row level security;
revoke all on public.cron_runs from public, anon, authenticated, service_role;

create table if not exists public.cron_locks (
    job     text primary key check (job ~ '^[a-z][a-z_]{0,39}$'),
    holder  text not null check (char_length(holder) between 1 and 80),
    until   timestamptz not null
);
alter table public.cron_locks enable row level security;
revoke all on public.cron_locks from public, anon, authenticated, service_role;

-- A run of [job] by [holder] begins: {run, locked}. The lock is taken for
-- [seconds] (10 to 3600) unless another run holds it still, and the run is
-- written down either way; a locked one is written down as ended.
create or replace function public.cron_begin(job text, holder text, seconds integer default 300)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    took boolean;
    run bigint;
begin
    insert into public.cron_locks as l (job, holder, until)
    values (cron_begin.job, cron_begin.holder,
            now() + make_interval(secs => least(greatest(coalesce(seconds, 300), 10), 3600)))
    on conflict on constraint cron_locks_pkey do update
       set holder = excluded.holder, until = excluded.until
     where l.until < now()
    returning true into took;
    took := coalesce(took, false);
    insert into public.cron_runs (job, holder, finished_at, outcome)
    values (cron_begin.job, cron_begin.holder, case when took then null else now() end,
            case when took then null else 'locked' end)
    returning id into run;
    return jsonb_build_object('run', run, 'locked', not took);
end;
$$;

-- Run [run] of [holder] ended with [outcome], having [said] that: true
-- when it was open. Its lock goes, if it is still the run's own.
create or replace function public.cron_end(run bigint, holder text, outcome text, said jsonb default '{}'::jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    which text;
begin
    if outcome not in ('done', 'unchanged', 'failed') then
        raise exception 'brickworks: a run ends done, unchanged or failed' using errcode = '22023';
    end if;
    update public.cron_runs r
       set finished_at = now(), outcome = cron_end.outcome, said = coalesce(cron_end.said, '{}'::jsonb)
     where r.id = cron_end.run and r.holder = cron_end.holder and r.finished_at is null
    returning r.job into which;
    if which is null then
        return false;
    end if;
    delete from public.cron_locks l where l.job = which and l.holder = cron_end.holder;
    return true;
end;
$$;

-- The newest [most] (1 to 50) runs of [job]: {run, job, started_at,
-- finished_at, outcome, said}.
create or replace function public.cron_runs_of(job text, most integer default 10)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('run', r.id, 'job', r.job, 'holder', r.holder, 'started_at', r.started_at,
                              'finished_at', r.finished_at, 'outcome', r.outcome, 'said', r.said)
      from public.cron_runs r
     where r.job = cron_runs_of.job
     order by r.started_at desc, r.id desc
     limit least(greatest(coalesce(most, 10), 1), 50)
$$;

-- ---------------------------------------------------------------------------
-- What the front leads with.

create table if not exists public.gallery_features (
    slot     text not null check (slot in ('featured', 'pick', 'library')),
    day      date not null,
    item     text not null check (char_length(item) between 1 and 160),
    why      jsonb not null default '{}'::jsonb check (pg_column_size(why) <= 4000),
    made_at  timestamptz not null default now(),
    primary key (slot, day),
    check (slot <> 'pick' or extract(isodow from day) = 1),
    check (slot = 'library' or item ~ '^[A-Za-z0-9]{10}$')
);
create index if not exists gallery_features_item on public.gallery_features (slot, item, day desc);
alter table public.gallery_features enable row level security;
revoke all on public.gallery_features from public, anon, authenticated, service_role;

-- What people did with each model the gallery shows a visitor, in the past
-- [days] (1 to 365): {id, likes, builds, comments, remixes, tested,
-- listed_at, has_image}. Of every model with any of those in the window,
-- and of the [most] (1 to 1000) listed last whatever they had, so a quiet
-- month still has candidates. Comments hidden or removed are not counted.
create or replace function public.gallery_feature_signals(days integer default 30, most integer default 300)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    with since as (
        select now() - make_interval(days => least(greatest(coalesce(gallery_feature_signals.days, 30), 1), 365)) as at),
    liked as (
        select l.model, count(*) as n from public.model_likes l, since where l.at > since.at group by l.model),
    built as (
        select b.model, count(*) as n from public.model_builds b, since where b.at > since.at group by b.model),
    said as (
        select c.model, count(*) as n from public.model_comments c, since
         where c.at > since.at and c.removed_at is null and c.hidden_at is null group by c.model),
    remixed as (
        select r.remixed_from as model, count(*) as n from public.shared_models r, since
         where r.remixed_from is not null and r.listed_at > since.at and public.gallery_shows(r, false)
         group by r.remixed_from),
    newest as (
        select n.id as model from public.shared_models n
         where n.listed and n.published and not n.test
         order by n.listed_at desc nulls last, n.id desc
         limit least(greatest(coalesce(gallery_feature_signals.most, 300), 1), 1000)),
    pool as (
        select model from liked union select model from built union select model from said
        union select model from remixed union select model from newest)
    select jsonb_build_object('id', m.id, 'likes', coalesce(l.n, 0), 'builds', coalesce(b.n, 0),
                              'comments', coalesce(c.n, 0), 'remixes', coalesce(x.n, 0),
                              'tested', public.model_tested(m.id), 'listed_at', m.listed_at,
                              'has_image', m.has_image or coalesce(m.has_thumb, false))
      from pool p
      join public.shared_models m on m.id = p.model
      left join liked l on l.model = m.id
      left join built b on b.model = m.id
      left join said c on c.model = m.id
      left join remixed x on x.model = m.id
     where public.gallery_shows(m, false)
$$;

-- What [slot] featured from [since] on, newest first: {day, item, why}.
create or replace function public.gallery_features_since(slot text, since date)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('day', f.day, 'item', f.item, 'why', f.why)
      from public.gallery_features f
     where f.slot = gallery_features_since.slot and f.day >= gallery_features_since.since
     order by f.day desc
$$;

-- [item] is [slot]'s for [day], unless that day has one already, which is
-- kept: {slot, day, item, why, made} (made: whether this call put it
-- there). A model must be one the gallery shows a visitor; anything else is
-- refused, with a reason.
create or replace function public.gallery_feature_keep(slot text, day date, item text, why jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    kept public.gallery_features;
    made boolean := false;
begin
    if slot in ('featured', 'pick') then
        select * into m from public.shared_models where id = item;
        if not found or not public.gallery_shows(m, false) then
            return jsonb_build_object('refused', 'not_in_gallery');
        end if;
    end if;
    insert into public.gallery_features (slot, day, item, why)
    values (gallery_feature_keep.slot, gallery_feature_keep.day, gallery_feature_keep.item,
            coalesce(gallery_feature_keep.why, '{}'::jsonb))
    on conflict on constraint gallery_features_pkey do nothing
    returning * into kept;
    made := found;
    if not made then
        select * into kept from public.gallery_features f
         where f.slot = gallery_feature_keep.slot and f.day = gallery_feature_keep.day;
    end if;
    return jsonb_build_object('slot', kept.slot, 'day', kept.day, 'item', kept.item, 'why', kept.why,
                              'made', made);
end;
$$;

-- What the front shows now, as a list asked with [tests] shows it:
-- {featured: {day, card, why}, pick: {day, card, week}, library: {day,
-- item, why}}, each null when there is none. The newest of each slot, no
-- older than two days (the pick: its week), and of a model only while the
-- gallery still shows it.
create or replace function public.gallery_features_now(tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'featured', (select jsonb_build_object('day', f.day, 'card', public.directory_card(m), 'why', f.why)
                       from public.gallery_features f
                       join public.shared_models m on m.id = f.item
                      where f.slot = 'featured' and f.day between current_date - 2 and current_date
                        and public.gallery_shows(m, gallery_features_now.tests)
                      order by f.day desc limit 1),
        'pick', (select jsonb_build_object('day', f.day, 'card', public.directory_card(m), 'why', f.why,
                                           'week', public.gallery_week_of(m.id, gallery_features_now.tests))
                   from public.gallery_features f
                   join public.shared_models m on m.id = f.item
                  where f.slot = 'pick' and f.day between current_date - 6 and current_date
                    and public.gallery_shows(m, gallery_features_now.tests)
                  order by f.day desc limit 1),
        'library', (select jsonb_build_object('day', f.day, 'item', f.item, 'why', f.why)
                      from public.gallery_features f
                     where f.slot = 'library' and f.day between current_date - 2 and current_date
                     order by f.day desc limit 1))
$$;

-- ---------------------------------------------------------------------------
-- What the OMR has that the library has not.

create table if not exists public.library_arrivals (
    page        integer primary key check (page between 1 and 10000000),
    set_number  text not null check (set_number ~ '^[A-Za-z0-9._-]{1,40}$'),
    name        text not null check (char_length(name) between 1 and 200),
    file        text not null check (file ~ '^https://library[.]ldraw[.]org/media/omr_models/[0-9]+/[A-Za-z0-9._''-]+[.](mpd|ldr)$'),
    stamp       bigint not null default 0 check (stamp >= 0),
    author      text check (author is null or char_length(author) <= 200),
    state       text not null default 'found' check (state in ('found', 'staged', 'live', 'refused')),
    why         text check (why is null or char_length(why) <= 500),
    entries     jsonb not null default '[]'::jsonb check (jsonb_typeof(entries) = 'array' and pg_column_size(entries) <= 20000),
    found_at    timestamptz not null default now(),
    changed_at  timestamptz not null default now(),
    check ((state = 'refused') = (why is not null))
);
alter table public.library_arrivals enable row level security;
revoke all on public.library_arrivals from public, anon, authenticated, service_role;

-- What the weekly look found, [found] ([{page, set_number, name, file,
-- stamp, author}]): a page not seen before is found; one seen before whose
-- file has a newer stamp is found again (an update), whatever it was; one
-- seen with the same stamp is left as it is. Returns the pages it wrote.
create or replace function public.library_arrivals_found(found jsonb)
returns setof integer
language sql
security definer
set search_path = public
as $$
    insert into public.library_arrivals as a (page, set_number, name, file, stamp, author)
    select (f->>'page')::integer, f->>'set_number', left(f->>'name', 200), f->>'file',
           coalesce((f->>'stamp')::bigint, 0), nullif(left(coalesce(f->>'author', ''), 200), '')
      from jsonb_array_elements(case when jsonb_typeof(found) = 'array' then found else '[]'::jsonb end) f
    on conflict (page) do update
       set set_number = excluded.set_number, name = excluded.name, file = excluded.file,
           stamp = excluded.stamp, author = excluded.author, state = 'found', why = null,
           entries = '[]'::jsonb, changed_at = now()
     where excluded.stamp > a.stamp
    returning page
$$;

-- The arrivals in [state] (or every one, for null), oldest first: {page,
-- set_number, name, file, stamp, author, state, why, entries, found_at,
-- changed_at}.
create or replace function public.library_arrivals_in(state text default null)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select to_jsonb(a) from public.library_arrivals a
     where library_arrivals_in.state is null or a.state = library_arrivals_in.state
     order by a.found_at, a.page
$$;

-- Arrival [page] is now [state]: staged with its index [entries], refused
-- with [why], or live. True when it was there to change.
create or replace function public.library_arrival_set(page integer, state text, entries jsonb default null,
                                                      why text default null)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    changed integer;
begin
    update public.library_arrivals a
       set state = library_arrival_set.state,
           entries = coalesce(library_arrival_set.entries, a.entries),
           why = case when library_arrival_set.state = 'refused' then coalesce(library_arrival_set.why, 'refused') end,
           changed_at = now()
     where a.page = library_arrival_set.page;
    get diagnostics changed = row_count;
    return changed > 0;
end;
$$;

-- What the site's library adds to the store's index, as a list asked with
-- [tests] shows it: the live arrivals' entries, and the staged ones' too
-- for tests.
create or replace function public.library_arrival_entries(tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select e from public.library_arrivals a, jsonb_array_elements(a.entries) e
     where a.state = 'live' or (a.state = 'staged' and coalesce(library_arrival_entries.tests, false))
     order by a.found_at, a.page
$$;

revoke all on function public.cron_begin(text, text, integer) from public, anon, authenticated;
grant execute on function public.cron_begin(text, text, integer) to service_role;
revoke all on function public.cron_end(bigint, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.cron_end(bigint, text, text, jsonb) to service_role;
revoke all on function public.cron_runs_of(text, integer) from public, anon, authenticated;
grant execute on function public.cron_runs_of(text, integer) to service_role;
revoke all on function public.gallery_feature_signals(integer, integer) from public, anon, authenticated;
grant execute on function public.gallery_feature_signals(integer, integer) to service_role;
revoke all on function public.gallery_features_since(text, date) from public, anon, authenticated;
grant execute on function public.gallery_features_since(text, date) to service_role;
revoke all on function public.gallery_feature_keep(text, date, text, jsonb) from public, anon, authenticated;
grant execute on function public.gallery_feature_keep(text, date, text, jsonb) to service_role;
revoke all on function public.gallery_features_now(boolean) from public, anon, authenticated;
grant execute on function public.gallery_features_now(boolean) to service_role;
revoke all on function public.library_arrivals_found(jsonb) from public, anon, authenticated;
grant execute on function public.library_arrivals_found(jsonb) to service_role;
revoke all on function public.library_arrivals_in(text) from public, anon, authenticated;
grant execute on function public.library_arrivals_in(text) to service_role;
revoke all on function public.library_arrival_set(integer, text, jsonb, text) from public, anon, authenticated;
grant execute on function public.library_arrival_set(integer, text, jsonb, text) to service_role;
revoke all on function public.library_arrival_entries(boolean) from public, anon, authenticated;
grant execute on function public.library_arrival_entries(boolean) to service_role;
