-- Trust first, 2026-10-18.
--
-- brickworks.diy is about to grow comments and pictures of real builds, so
-- the ground rules a public community stands on come first: terms and
-- guidelines (web/terms.html, web/guidelines.html), an age question, and
-- reports that reach the site's owner within the hour. What the database
-- keeps for the last two is here; docs/COMMUNITY.md says where each rule is
-- enforced.
--
-- The age question. Everyone is asked once, at their first sign-in after
-- this (web/account.js, src/ui/sign_in_gate.gd): the month and year they
-- were born, with nothing before the answer to say what the right one is.
-- The server works out from them whether the account is 13 or over
-- (api/_trust.js) and keeps only that and when it was asked, never the
-- date: the date goes no further than that one request.
--
--   profiles.over_13       true: 13 or over; false: under 13; null: not
--                          asked yet (every account until it signs in)
--   profiles.age_asked_at  when it was answered
--
-- An account under 13 builds, keeps its models and shares them by link
-- like anyone. What is public it may not have: a model in the gallery, a
-- profile (a handle, a name, a bio), a public collection, a name credited
-- on a link, and later comments and photos. Each is refused here, by a
-- trigger on its table, whatever asks; api/share.js and api/people.js say
-- so first, politely, and the app and the site say it before anyone tries.
-- A new public thing needs a yes: an account not asked yet is asked before
-- it can list or make a profile, and what it listed before this stays as
-- it is until it answers. Answered under 13, what it had in public goes
-- private (answer_age), nothing deleted, and nothing of it is shown in
-- public again. A year after an under-13 answer the account is asked
-- again, so a builder who has turned 13 can say so; an answer of 13 or
-- over stands.
--
-- Reports that reach the owner. A report (moderation.sql) waited on the
-- admin page until the owner happened to look. Now each is in an email
-- to the owner (MASTER_EMAIL, the address api/admin.js lets in) within
-- the hour, and at most one email an hour: a digest of what arrived since
-- the last, each with a link to its row on the admin page (api/_trust.js).
-- The first report in a quiet hour goes at once; the rest of that hour's
-- wait for the next hour's knock (the cron job at the end of this file).
--
--   report_digests   each digest: whose stream, when, how it went, how
--                    many reports; for a test's, the email as rendered
--   reports.digest   which digest a report went out in
--
-- A report about something of a test account's (one at resend.dev, which
-- only a probe signs in at: api/_auth.js isTestAccount), or made by one,
-- is never emailed to anybody. It goes in a digest of its own stream,
-- "test:<account>", which is rendered and recorded and never sent: the
-- dry run the browser flows read back (tools/web/trust_flow.mjs).
--
-- Only additions, applied after moderation.sql and test_models.sql: two
-- columns on profiles and one on reports, all empty; a table; functions;
-- triggers that refuse; two functions replaced, the same but for the
-- under-13 rule; and an hourly job. No existing row is changed, nothing
-- is dropped or renamed. Every new table is the server's alone.

-- ---------------------------------------------------------------------------
-- The age question.

alter table public.profiles add column if not exists over_13 boolean;
alter table public.profiles add column if not exists age_asked_at timestamptz;

-- Both or neither: an answer always says when it was given.
do $$
begin
    if not exists (select 1 from pg_constraint
                    where conname = 'profiles_age_whole' and conrelid = 'public.profiles'::regclass) then
        alter table public.profiles
            add constraint profiles_age_whole check ((over_13 is null) = (age_asked_at is null));
    end if;
end
$$;

comment on column public.profiles.over_13 is
    'Whether the account said it is 13 or over (supabase/trust.sql). Null: '
    'not asked yet. The birth date it was worked out from is never kept.';

-- Whether an account may do a new public thing: it said it is 13 or over.
create or replace function public.trust_may_go_public(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce((select p.over_13 from public.profiles p where p.id = account), false)
$$;

-- Whether an account said it is under 13: then nothing of it is public.
create or replace function public.trust_kept_private(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce((select not p.over_13 from public.profiles p where p.id = account), false)
$$;

-- What the app and the site need to know: the answer, when, and whether
-- to ask (never asked, or under 13 a year ago).
create or replace function public.age_of(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'over_13', p.over_13,
        'asked_at', p.age_asked_at,
        'ask', p.over_13 is null
            or (not p.over_13 and p.age_asked_at < now() - interval '1 year'))
      from (select 1) as one
      left join public.profiles p on p.id = account
$$;

-- The answer, once. Asked again only when age_of says ask; otherwise the
-- answer given stands and is what comes back, so a second try with
-- another date changes nothing. Under 13: its listed models leave the
-- gallery and its public collections go private. Nothing is deleted.
create or replace function public.answer_age(account uuid, at_least_13 boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if at_least_13 is null then
        raise exception 'brickworks: say whether the account is 13 or over' using errcode = '22023';
    end if;
    perform pg_advisory_xact_lock(hashtext('answer_age:' || account::text));
    -- The row schema.sql's trigger makes, for an account older than it.
    insert into public.profiles (id, email)
    select u.id, u.email from auth.users u where u.id = account
    on conflict (id) do nothing;
    if not exists (select 1 from public.profiles p where p.id = account) then
        raise exception 'brickworks: no such account' using errcode = '22023';
    end if;
    if not (public.age_of(account)->>'ask')::boolean then
        return public.age_of(account);
    end if;
    update public.profiles
       set over_13 = at_least_13, age_asked_at = now()
     where id = account;
    if not at_least_13 then
        update public.shared_models set listed = false, listed_at = null
         where owner = account and listed;
        update public.model_collections set public = false, updated_at = now()
         where owner = account and public;
    end if;
    return public.age_of(account);
end;
$$;

-- What a visitor may be shown of an account: not taken out of the
-- gallery (moderation.sql), not under 13. api/people.js asks it of a
-- profile before showing it.
create or replace function public.shown_publicly(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select not public.is_barred(account) and not public.trust_kept_private(account)
$$;

-- The refusals, whatever asks. Each raises with a hint naming the rule, so
-- the API can tell it from any other failure.

-- A model into the gallery needs a yes; one under 13 is never in it, nor
-- credited to a name it did not have before.
create or replace function public.trust_guard_model()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    newly_listed boolean := new.listed;
    newly_credited boolean := new.author is not null;
begin
    if tg_op = 'UPDATE' then
        newly_listed := new.listed and not old.listed;
        newly_credited := new.author is not null and new.author is distinct from old.author;
    end if;
    if (newly_listed and not public.trust_may_go_public(new.owner))
       or (new.listed and public.trust_kept_private(new.owner)) then
        raise exception 'brickworks: the gallery is for accounts 13 or over'
            using errcode = 'P0001', hint = 'trust:listing';
    end if;
    if newly_credited and public.trust_kept_private(new.owner) then
        raise exception 'brickworks: a name on a link is for accounts 13 or over'
            using errcode = 'P0001', hint = 'trust:credit';
    end if;
    return new;
end;
$$;
create or replace trigger trust_guard_model
    before insert or update on public.shared_models
    for each row execute function public.trust_guard_model();

-- A profile, made or changed, needs a yes.
create or replace function public.trust_guard_person()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not public.trust_may_go_public(new.account) then
        raise exception 'brickworks: a public profile is for accounts 13 or over'
            using errcode = 'P0001', hint = 'trust:profile';
    end if;
    return new;
end;
$$;
create or replace trigger trust_guard_person
    before insert or update on public.people
    for each row execute function public.trust_guard_person();

-- A collection made public needs a yes; one under 13 is never public.
create or replace function public.trust_guard_collection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    newly_public boolean := new.public;
begin
    if tg_op = 'UPDATE' then
        newly_public := new.public and not old.public;
    end if;
    if (newly_public and not public.trust_may_go_public(new.owner))
       or (new.public and public.trust_kept_private(new.owner)) then
        raise exception 'brickworks: a public collection is for accounts 13 or over'
            using errcode = 'P0001', hint = 'trust:collection';
    end if;
    return new;
end;
$$;
create or replace trigger trust_guard_collection
    before insert or update on public.model_collections
    for each row execute function public.trust_guard_collection();

revoke all on function public.trust_guard_model() from public, anon, authenticated;
revoke all on function public.trust_guard_person() from public, anon, authenticated;
revoke all on function public.trust_guard_collection() from public, anon, authenticated;

-- A card, as people.sql made it, and nobody's handle on it for an account
-- under 13: a profile it had before it answered is not shown.
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
                where p.account = m.owner and m.author is not null
                  and not public.trust_kept_private(m.owner)))
      from (select 1) as one
      left join public.model_stats s on s.model = m.id
$$;

-- A profile, as test_models.sql made it, and none for an account under 13.
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
       and not public.trust_kept_private(p.account)
$$;

-- ---------------------------------------------------------------------------
-- Reports that reach the owner.

create table if not exists public.report_digests (
    id       bigserial primary key,
    stream   text not null check (stream = 'owner' or stream ~ '^test:[0-9a-f-]{36}$'),
    at       timestamptz not null default now(),
    state    text not null default 'sending' check (state in ('sending', 'sent', 'failed', 'dry')),
    reports  integer not null default 0 check (reports >= 0),
    -- The email as rendered, kept for a test's dry run only: what went to
    -- the owner is in their inbox, and is not kept twice.
    subject  text check (subject is null or char_length(subject) <= 300),
    body     text check (body is null or char_length(body) <= 100000),
    html     text check (html is null or char_length(html) <= 200000)
);
create index if not exists report_digests_stream on public.report_digests (stream, at desc);
alter table public.report_digests enable row level security;
revoke all on public.report_digests from anon, authenticated;

alter table public.reports
    add column if not exists digest bigint references public.report_digests (id) on delete set null;
create index if not exists reports_waiting on public.reports (at) where resolved_at is null;

-- An account a test signed in at: a Resend test address, as
-- api/_auth.js isTestAccount says.
create or replace function public.trust_is_test_account(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select coalesce((select u.email ~* '@resend\.dev$' from auth.users u where u.id = account), false)
$$;

-- Which digest a report belongs in: "owner", or "test:<account>" for one
-- about a test account's model, profile or collection, or made by one.
-- Null for a report about a profile that is no longer there: nothing to
-- act on.
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
            (select p.account from public.people p where p.handle = r.handle)) as owner)
    select case
        when w.owner is null and r.handle is not null then null
        when w.owner is not null and public.trust_is_test_account(w.owner) then 'test:' || w.owner::text
        when r.reporter is not null and public.trust_is_test_account(r.reporter) then 'test:' || r.reporter::text
        else 'owner' end
      from whose w
$$;

-- Start a digest, and say what is in it: {digest, stream, reports: [...],
-- more}, or null when there is nothing to send or this hour has had its
-- one. A stream named, or the stream of one report (the one just made).
-- At most one an hour of the clock, so a report that has to wait is in
-- the next hour's, within the hour; a digest that failed does not count,
-- and its reports go in the next. Up to 100 reports, oldest first; more
-- says how many wait behind them.
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
                       'name', coalesce(m.name, c.name, p.name))
                       order by r.at)
              from public.reports r
              left join public.shared_models m on m.id = r.model
              left join public.model_collections c on c.id = r.collection
              left join public.people p on p.handle = r.handle
             where r.id = any (ids)));
end;
$$;

-- How a digest went: sent, failed (its reports go in the next one), or dry
-- (a test's, rendered and never sent, kept with what it would have said).
create or replace function public.finish_report_digest(
    one bigint, outcome text, said_subject text default null,
    said_body text default null, said_html text default null)
returns boolean
language sql
security definer
set search_path = public
as $$
    with done as (
        update public.report_digests
           set state = outcome,
               subject = case when outcome = 'dry' then left(said_subject, 300) end,
               body = case when outcome = 'dry' then left(said_body, 100000) end,
               html = case when outcome = 'dry' then left(said_html, 200000) end
         where id = one and state = 'sending' and outcome in ('sent', 'failed', 'dry')
        returning 1)
    select exists (select 1 from done)
$$;

revoke all on function public.trust_may_go_public(uuid) from public, anon, authenticated;
grant execute on function public.trust_may_go_public(uuid) to service_role;
revoke all on function public.trust_kept_private(uuid) from public, anon, authenticated;
grant execute on function public.trust_kept_private(uuid) to service_role;
revoke all on function public.age_of(uuid) from public, anon, authenticated;
grant execute on function public.age_of(uuid) to service_role;
revoke all on function public.answer_age(uuid, boolean) from public, anon, authenticated;
grant execute on function public.answer_age(uuid, boolean) to service_role;
revoke all on function public.shown_publicly(uuid) from public, anon, authenticated;
grant execute on function public.shown_publicly(uuid) to service_role;
revoke all on function public.directory_card(public.shared_models) from public, anon, authenticated;
grant execute on function public.directory_card(public.shared_models) to service_role;
revoke all on function public.profile_page(text, boolean) from public, anon, authenticated;
grant execute on function public.profile_page(text, boolean) to service_role;
revoke all on function public.trust_is_test_account(uuid) from public, anon, authenticated;
grant execute on function public.trust_is_test_account(uuid) to service_role;
revoke all on function public.report_stream(public.reports) from public, anon, authenticated;
grant execute on function public.report_stream(public.reports) to service_role;
revoke all on function public.claim_report_digest(text, bigint) from public, anon, authenticated;
grant execute on function public.claim_report_digest(text, bigint) to service_role;
revoke all on function public.finish_report_digest(bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function public.finish_report_digest(bigint, text, text, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- The hourly knock.
--
-- The site's only cron is Vercel's daily sweep, so the database knocks
-- instead: a minute past every hour it asks the live site to send what
-- waits (POST /api/people?op=digest). The endpoint needs no secret: it can
-- send nothing but this hour's one digest, to the owner, of reports that
-- are really there. pg_cron and pg_net are Supabase's own extensions;
-- where they are not offered, this does nothing, and a digest goes when
-- the next report arrives in a later hour.
do $knock$
begin
    if exists (select 1 from pg_available_extensions where name = 'pg_cron')
       and exists (select 1 from pg_available_extensions where name = 'pg_net') then
        create extension if not exists pg_net with schema extensions;
        create extension if not exists pg_cron with schema pg_catalog;
        perform cron.schedule('brickworks-report-digest', '1 * * * *',
            $job$select net.http_post(url := 'https://brickworks.diy/api/people?op=digest',
                                      body := '{}'::jsonb)$job$);
    end if;
end
$knock$;
