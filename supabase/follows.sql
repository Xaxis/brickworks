-- Follows, a feed, and what is new in it, 2026-10-18.
--
-- brickworks.diy has profiles, a gallery, likes, remixes, versions,
-- comments, the Tested mark and photos of real builds, and nothing brought
-- a person back when something happened. Now a person may follow another
-- (Follow on /u/<handle>, and beside a model's designer on its page), and
-- /feed shows, newest first, what happened that concerns them:
--
--   model     a model listed in the gallery by somebody they follow, and
--             credited to them (a model shared without a name is tied to
--             nobody, so following somebody never shows one)
--   version   a newer version of one of those, published after it was
--             listed
--   photo     a photo of a real build on one of their own models, or by
--             somebody they follow of a model in the gallery
--   comment   a comment on one of their own models
--   remix     a remix of one of their own models, listed in the gallery
--
-- Each row of the feed is read from the tables that already hold it
-- (shared_models, share_versions, build_photos, model_comments) with what
-- each of their pages already shows and hides: nothing hidden by a model's
-- owner, removed, taken out of the gallery, or by an account taken out or
-- under 13; a test account's models only in a test account's feed. Nothing
-- is copied into a feed table. The feed is of the last 90 days.
--
-- What is new: the Account count (the site's header and the app's
-- Account) is how many of those rows came since the account last opened
-- its feed (feed_marks.seen_at), at most 99. Opening the feed sets it.
--
-- The daily email (comments.sql's, at most one a day, from the sign-in
-- codes' sender) can tell of these too, one choice for each kind, each off
-- until the person turns it on (/profile): new models, new versions,
-- photos, remixes, beside comments as before. What it told is everything
-- of the kinds chosen since the last one that went (or since they chose).
--
-- The rules, whatever asks:
--
--   Who may follow   a signed-in account that said it is 13 or over
--                    (trust_may_go_public), not taken out of the gallery
--                    (is_barred). A follow is counted in public, so an
--                    account under 13, or one not asked yet, may not.
--   Who may be       somebody with a profile shown in public: 13 or over,
--   followed         not taken out, not themselves. Following somebody
--                    tells them nothing and opens no way to write to them:
--                    there is no message, and no feed row says who
--                    followed whom.
--   How often        60 follows an hour and 300 a day (may_act). Letting
--                    one go is not counted.
--   Who sees whom    only counts: N followers, following N, on a profile.
--                    Never a list of followers. The people somebody
--                    follows are listed on their profile only when they
--                    chose to show them (feed_marks.shows_follows, off
--                    until they say), and then only those who are
--                    themselves shown in public.
--
--   follows       who follows whom, and since when
--   feed_marks    one row an account: when it last opened its feed, and
--                 whether its profile shows whom it follows
--   mail_choices  (comments.sql) four more choices, all off: models,
--                 versions, photos, remixes
--   comment_digests.feed   how many feed rows a daily email told of
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, may read or write the new tables
-- directly: who follows whom is answered only as the functions answer it.
--
-- Only additions, applied after trust.sql, comments.sql, builds.sql and
-- versions.sql (it reads their tables): two new tables, four columns on
-- mail_choices and one on comment_digests, each false or zero on every
-- row, a trigger that refuses, new functions, and one function replaced:
--
--   claim_comment_digest   supersedes comments.sql's (the live one: no
--                          later file replaces it). The same comments,
--                          marked as before, and the feed rows of the
--                          kinds chosen; claimed when either waits. And
--                          one thing mended: it took the first 50 accounts
--                          that chose an email, in the order of their ids,
--                          whether or not one was due, so the 51st never
--                          got one; now every account that chose and has
--                          had none today is looked at, until 50 emails
--                          are made.
--
-- No existing row is changed, nothing dropped or renamed. Until code that
-- asks for the new kinds is deployed nobody can choose them, so the
-- replaced function claims exactly what it did.

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.follows (
    follower  uuid not null references auth.users (id) on delete cascade,
    followed  uuid not null references auth.users (id) on delete cascade,
    at        timestamptz not null default now(),
    primary key (follower, followed),
    check (follower <> followed)
);
create index if not exists follows_followed on public.follows (followed, at desc);

create table if not exists public.feed_marks (
    account        uuid primary key references auth.users (id) on delete cascade,
    seen_at        timestamptz,
    shows_follows  boolean not null default false,
    at             timestamptz not null default now()
);

alter table public.follows enable row level security;
alter table public.feed_marks enable row level security;
revoke all on public.follows from public, anon, authenticated, service_role;
revoke all on public.feed_marks from public, anon, authenticated, service_role;

alter table public.mail_choices add column if not exists models boolean not null default false;
alter table public.mail_choices add column if not exists versions boolean not null default false;
alter table public.mail_choices add column if not exists photos boolean not null default false;
alter table public.mail_choices add column if not exists remixes boolean not null default false;
alter table public.comment_digests
    add column if not exists feed integer not null default 0 check (feed >= 0);

-- ---------------------------------------------------------------------------
-- Following.

-- Whether [account] may be followed: a profile shown in public, by an
-- account that said it is 13 or over and was not taken out.
create or replace function public.follow_may_be_followed(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (select 1 from public.people p where p.account = follow_may_be_followed.account)
       and public.trust_may_go_public(account)
       and public.shown_publicly(account)
$$;

-- Why [account] may not follow [whom], or null when it may: sign_in,
-- nobody, yourself, barred, ask_first, under_13. The API says each in
-- words (api/_follows.js).
create or replace function public.follow_trouble(account uuid, whom uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
    select case
        when account is null then 'sign_in'
        when whom is null or not public.follow_may_be_followed(whom) then 'nobody'
        when account = whom then 'yourself'
        when public.is_barred(account) then 'barred'
        when (select p.over_13 from public.profiles p where p.id = account) is null then 'ask_first'
        when not public.trust_may_go_public(account) then 'under_13'
        end
$$;

-- The refusals, whatever writes.
create or replace function public.follows_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.follow_trouble(new.follower, new.followed);
begin
    if trouble in ('ask_first', 'under_13') then
        raise exception 'brickworks: following is for accounts 13 or over'
            using errcode = 'P0001', hint = 'follows:age';
    elsif trouble = 'barred' then
        raise exception 'brickworks: this account was taken out of the gallery'
            using errcode = 'P0001', hint = 'follows:barred';
    elsif trouble is not null then
        raise exception 'brickworks: only a profile shown in public can be followed'
            using errcode = 'P0001', hint = 'follows:nobody';
    end if;
    return new;
end;
$$;
create or replace trigger follows_guard
    before insert or update on public.follows
    for each row execute function public.follows_guard();
revoke all on function public.follows_guard() from public, anon, authenticated;

-- A person's follows as anybody may see them, by handle, and as [asker]
-- sees them: {handle, followers, following, shows, you_follow, mine,
-- trouble}. Counted only between accounts shown in public. Null for a
-- handle with no profile shown.
create or replace function public.follow_state(asker uuid, wanted text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'handle', p.handle,
        'followers', (select count(*) from public.follows f
                       where f.followed = p.account
                         and public.trust_may_go_public(f.follower) and public.shown_publicly(f.follower)),
        'following', (select count(*) from public.follows f
                       where f.follower = p.account and public.follow_may_be_followed(f.followed)),
        'shows', coalesce((select k.shows_follows from public.feed_marks k where k.account = p.account), false),
        'you_follow', asker is not null and exists (select 1 from public.follows f
                                                     where f.follower = asker and f.followed = p.account),
        'mine', asker is not null and asker = p.account,
        'trouble', public.follow_trouble(asker, p.account))
      from public.people p
     where p.handle = lower(wanted) and public.follow_may_be_followed(p.account)
$$;

-- [account] follows the person with [wanted]'s handle (on), or lets them
-- go (off): follow_state as it is then, or {refused} with follow_trouble's
-- reasons and limit (60 an hour, 300 a day).
create or replace function public.follow_person(account uuid, wanted text, following boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    whom uuid;
    trouble text;
begin
    if following is null then
        raise exception 'brickworks: say whether to follow' using errcode = '22023';
    end if;
    select p.account into whom from public.people p where p.handle = lower(wanted);
    if following then
        trouble := public.follow_trouble(account, whom);
        if trouble is not null then
            return jsonb_build_object('refused', trouble);
        end if;
        if not exists (select 1 from public.follows f where f.follower = account and f.followed = whom) then
            if not public.may_act(account::text, 'follow', 60, 300) then
                return jsonb_build_object('refused', 'limit');
            end if;
            insert into public.follows (follower, followed) values (account, whom)
            on conflict on constraint follows_pkey do nothing;
        end if;
    else
        if account is null then
            return jsonb_build_object('refused', 'sign_in');
        end if;
        delete from public.follows f where f.follower = account and f.followed = whom;
    end if;
    return coalesce(public.follow_state(account, wanted), jsonb_build_object('refused', 'nobody'));
end;
$$;

-- Whom the person with [wanted]'s handle follows, when they chose to show
-- it: {shows, people: [{handle, name}]}, newest first, at most 200, only
-- people shown in public. Nobody's followers are ever listed.
create or replace function public.follow_list(wanted text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'shows', coalesce(k.shows_follows, false),
        'people', case when coalesce(k.shows_follows, false) then coalesce((
            select jsonb_agg(jsonb_build_object('handle', q.handle, 'name', q.name) order by f.at desc)
              from (select * from public.follows g where g.follower = p.account
                     order by g.at desc limit 200) f
              join public.people q on q.account = f.followed
             where public.follow_may_be_followed(f.followed)), '[]'::jsonb)
            else '[]'::jsonb end)
      from public.people p
      left join public.feed_marks k on k.account = p.account
     where p.handle = lower(wanted) and public.follow_may_be_followed(p.account)
$$;

-- What [account] chose: {shows_follows}. With [shows] given, that is kept
-- first. Off until they say.
create or replace function public.follow_choice(account uuid, shows boolean default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if shows is not null then
        insert into public.feed_marks (account, shows_follows, at)
        values (follow_choice.account, shows, now())
        on conflict on constraint feed_marks_pkey do update set shows_follows = excluded.shows_follows, at = excluded.at;
    end if;
    return jsonb_build_object('shows_follows', coalesce(
        (select k.shows_follows from public.feed_marks k where k.account = follow_choice.account), false));
end;
$$;

-- ---------------------------------------------------------------------------
-- The feed.

-- Who someone is on a feed row: their profile's handle and name, or null.
create or replace function public.feed_who(account uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('handle', p.handle, 'name', p.name)
      from public.people p
     where p.account = feed_who.account and public.shown_publicly(account)
$$;

-- Everything in [viewer]'s feed from after [since] up to [until], as
-- (kind, at, item): read from the tables that hold it, with what their
-- pages hide hidden here too.
--
-- REPLACED LATER: challenges.sql replaces this function with the same rows
-- and one kind more (an entry in a challenge). Applying this file again
-- alone takes that kind out of every feed, so apply challenges.sql again
-- right after it: tools/apply_sql.mjs refuses this file while the live
-- feed_rows is challenges.sql's, unless --again=supabase/challenges.sql.
create or replace function public.feed_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with followed as (
        select f.followed as account from public.follows f
         where f.follower = viewer and public.follow_may_be_followed(f.followed)),
    tests as (
        select public.trust_is_test_account(viewer) as ok),
    mine as (
        select m.id, m.name from public.shared_models m
         where m.owner = viewer and m.published and not m.barred)
    -- A model listed by somebody followed, and credited to them; a remix
    -- of the viewer's own is said once, as a remix, below.
    select 'model'::text, m.listed_at,
           jsonb_build_object('model', m.id, 'name', m.name, 'parts', m.parts, 'by', public.feed_who(m.owner))
      from public.shared_models m
      join followed w on w.account = m.owner
     cross join tests t
     where m.published and m.listed and not m.barred and m.author is not null
       and (not m.test or t.ok)
       and (m.remixed_from is null or m.remixed_from not in (select id from mine))
       and m.listed_at > since and m.listed_at <= until
    union all
    -- A newer version of one of those, published after it was listed.
    select 'version'::text, v.at,
           jsonb_build_object('model', m.id, 'name', m.name, 'version', v.n, 'note', v.note,
                              'by', public.feed_who(m.owner))
      from public.shared_models m
      join followed w on w.account = m.owner
      join public.share_versions v on v.model = m.id and v.n > 1 and v.at > m.listed_at
     cross join tests t
     where m.published and m.listed and not m.barred and m.author is not null
       and (not m.test or t.ok)
       and v.at > since and v.at <= until
    union all
    -- A photo of a build: on the viewer's own model, or by somebody
    -- followed of a model in the gallery.
    select 'photo'::text, b.at,
           jsonb_build_object('photo', b.id, 'model', b.model, 'name', m.name, 'words', b.words,
                              'yours', m.owner = viewer, 'by', public.feed_who(b.account))
      from public.build_photos b
      join public.shared_models m on m.id = b.model
     cross join tests t
     where b.removed_at is null and b.hidden_at is null and b.account <> viewer
       and m.published and not m.barred
       and public.shown_publicly(b.account)
       and (m.owner = viewer
            or (b.account in (select account from followed) and m.listed and (not m.test or t.ok)))
       and b.at > since and b.at <= until
    union all
    -- A comment on the viewer's own model, in this life of its link
    -- (comments_on's rule).
    select 'comment'::text, k.at,
           jsonb_build_object('comment', k.id, 'model', k.model, 'name', m.name, 'version', k.version,
                              'step', k.step, 'said', left(k.body, 240), 'by', public.feed_who(k.author))
      from public.model_comments k
      join mine m on m.id = k.model
     where k.removed_at is null and k.hidden_at is null and k.author <> viewer
       and public.shown_publicly(k.author)
       and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = k.model), '-infinity')
       and k.at > since and k.at <= until
    union all
    -- A remix of the viewer's own model, listed in the gallery; whose, only
    -- when it is credited.
    select 'remix'::text, r.listed_at,
           jsonb_build_object('model', r.id, 'name', r.name, 'of', o.id, 'of_name', o.name,
                              'by', case when r.author is not null then public.feed_who(r.owner) end)
      from public.shared_models r
      join mine o on o.id = r.remixed_from
     cross join tests t
     where r.published and r.listed and not r.barred and r.owner <> viewer
       and public.shown_publicly(r.owner) and (not r.test or t.ok)
       and r.listed_at > since and r.listed_at <= until
$$;

-- A page of [viewer]'s feed, newest first: {rows: [{kind, at, ...}], more,
-- seen_at}, [size] rows (1 to 50) from before [before] (or now), of the
-- last 90 days. With [mark], the feed counts as opened now, and seen_at
-- says when it was opened before (null: never), so the page can say which
-- rows are new.
create or replace function public.feed_of(viewer uuid, before timestamptz default null,
                                          size integer default 30, mark boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    wanted integer := least(greatest(coalesce(size, 30), 1), 50);
    seen timestamptz;
    listed jsonb;
    more boolean;
begin
    if viewer is null then
        return null;
    end if;
    select k.seen_at into seen from public.feed_marks k where k.account = viewer;
    select coalesce(jsonb_agg(r.item || jsonb_build_object('kind', r.kind, 'at', r.at)
                              order by r.at desc, r.kind), '[]'::jsonb),
           count(*) > wanted
      into listed, more
      from (select * from public.feed_rows(viewer, now() - interval '90 days', coalesce(before, now())) f
             where before is null or f.at < before
             order by f.at desc, f.kind limit wanted + 1) r;
    if jsonb_array_length(listed) > wanted then
        listed := listed - wanted;
    end if;
    if mark then
        insert into public.feed_marks (account, seen_at) values (viewer, now())
        on conflict on constraint feed_marks_pkey do update set seen_at = excluded.seen_at;
    end if;
    return jsonb_build_object('rows', listed, 'more', more, 'seen_at', seen);
end;
$$;

-- How many rows came into [viewer]'s feed since it was last opened (or
-- in the last 90 days, never opened), at most 99: the Account count.
create or replace function public.feed_count(viewer uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer
      from (select 1 from public.feed_rows(viewer,
                greatest(coalesce((select k.seen_at from public.feed_marks k where k.account = viewer),
                                  '-infinity'), now() - interval '90 days'), now())
             limit 99) r
$$;

-- ---------------------------------------------------------------------------
-- The daily email, with the feed in it.

-- What [account] wants emailed: {comments, models, versions, photos,
-- remixes}. Each named in [chosen] (true or false) is kept first; the
-- others stay as they were. All off until they say.
create or replace function public.mail_kinds(account uuid, chosen jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.mail_choices;
begin
    if chosen is not null and chosen <> '{}'::jsonb then
        if jsonb_typeof(chosen) <> 'object'
           or exists (select 1 from jsonb_each(chosen) e
                       where e.key not in ('comments', 'models', 'versions', 'photos', 'remixes')
                          or jsonb_typeof(e.value) <> 'boolean') then
            raise exception 'brickworks: say comments, models, versions, photos or remixes, each true or false'
                using errcode = '22023';
        end if;
        insert into public.mail_choices (account, at) values (mail_kinds.account, now())
        on conflict on constraint mail_choices_pkey do nothing;
        update public.mail_choices m
           set comments = coalesce((chosen->>'comments')::boolean, m.comments),
               models = coalesce((chosen->>'models')::boolean, m.models),
               versions = coalesce((chosen->>'versions')::boolean, m.versions),
               photos = coalesce((chosen->>'photos')::boolean, m.photos),
               remixes = coalesce((chosen->>'remixes')::boolean, m.remixes),
               at = now()
         where m.account = mail_kinds.account;
    end if;
    select * into c from public.mail_choices m where m.account = mail_kinds.account;
    return jsonb_build_object('comments', coalesce(c.comments, false), 'models', coalesce(c.models, false),
        'versions', coalesce(c.versions, false), 'photos', coalesce(c.photos, false),
        'remixes', coalesce(c.remixes, false));
end;
$$;

-- Start the emails that are due: to [for_owner], or to every account that
-- chose one. At most one a day for each; of the comments on their
-- published models since they chose, not their own, not hidden or removed,
-- that no email has told them of (or one that failed, or never finished),
-- as comments.sql's; and now of their feed's rows of the kinds they chose,
-- since the last email that went (or since they chose), at most 90 days.
-- [{digest, owner, email, test, more, comments: [{id, model, name,
-- version, step, body, at, by}], feed: [{kind, at, ...}], feed_more}], up
-- to 50 emails, 50 comments and 50 feed rows each; empty when none is due.
create or replace function public.claim_comment_digest(for_owner uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    who record;
    ids bigint[];
    waiting integer;
    told timestamptz;
    rows_told jsonb;
    rows_waiting integer;
    made bigint;
    due jsonb := '[]'::jsonb;
begin
    for who in
        select c.account, c.at as since, c.comments, c.models, c.versions, c.photos, c.remixes
          from public.mail_choices c
         where (c.comments or c.models or c.versions or c.photos or c.remixes)
           and (for_owner is null or c.account = for_owner)
           and not exists (select 1 from public.comment_digests d
                            where d.owner = c.account and d.state <> 'failed'
                              and d.at > now() - interval '1 day')
         order by c.account
    loop
        exit when jsonb_array_length(due) >= 50;
        perform pg_advisory_xact_lock(hashtext('comment_digest:' || who.account::text));
        if exists (select 1 from public.comment_digests d
                    where d.owner = who.account and d.state <> 'failed'
                      and d.at > now() - interval '1 day') then
            continue;
        end if;
        ids := null;
        waiting := 0;
        if who.comments then
            select array_agg(w.id order by w.at), count(*)::integer into ids, waiting
              from (select k.id, k.at from public.model_comments k
                      join public.shared_models m on m.id = k.model and m.published and m.owner = who.account
                      left join public.comment_digests d on d.id = k.digest
                     where k.removed_at is null and k.hidden_at is null and k.author <> who.account
                       and k.at >= who.since
                       and (k.digest is null or d.state = 'failed'
                            or (d.state = 'sending' and d.at < now() - interval '15 minutes'))
                       and public.shown_publicly(k.author)) w;
        end if;
        select max(d.at) into told from public.comment_digests d
         where d.owner = who.account and d.state in ('sent', 'dry');
        select coalesce(jsonb_agg(r.item || jsonb_build_object('kind', r.kind, 'at', r.at)
                                  order by r.at, r.kind) filter (where r.n <= 50), '[]'::jsonb),
               coalesce(max(r.total), 0)::integer
          into rows_told, rows_waiting
          from (select f.*, row_number() over (order by f.at, f.kind) as n, count(*) over () as total
                  from public.feed_rows(who.account,
                           greatest(coalesce(told, '-infinity'), who.since, now() - interval '90 days'), now()) f
                 where (f.kind = 'model' and who.models) or (f.kind = 'version' and who.versions)
                    or (f.kind = 'photo' and who.photos) or (f.kind = 'remix' and who.remixes)) r;
        if ids is null and jsonb_array_length(rows_told) = 0 then
            continue;
        end if;
        ids := ids[1:50];
        insert into public.comment_digests (owner, comments, feed)
        values (who.account, coalesce(array_length(ids, 1), 0), jsonb_array_length(rows_told))
        returning id into made;
        if ids is not null then
            update public.model_comments set digest = made where id = any (ids);
        end if;
        due := due || jsonb_build_array(jsonb_build_object(
            'digest', made, 'owner', who.account,
            'email', (select u.email from auth.users u where u.id = who.account),
            'test', public.trust_is_test_account(who.account),
            'more', coalesce(waiting, 0) - coalesce(array_length(ids, 1), 0),
            'comments', coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'model', k.model, 'name', m.name, 'version', k.version, 'step', k.step,
                    'body', k.body, 'at', k.at, 'by', p.name) order by k.at)
                  from public.model_comments k
                  join public.shared_models m on m.id = k.model
                  left join public.people p on p.account = k.author
                 where k.id = any (ids)), '[]'::jsonb),
            'feed', rows_told,
            'feed_more', rows_waiting - jsonb_array_length(rows_told)));
    end loop;
    return due;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.follow_may_be_followed(uuid) from public, anon, authenticated;
grant execute on function public.follow_may_be_followed(uuid) to service_role;
revoke all on function public.follow_trouble(uuid, uuid) from public, anon, authenticated;
grant execute on function public.follow_trouble(uuid, uuid) to service_role;
revoke all on function public.follow_state(uuid, text) from public, anon, authenticated;
grant execute on function public.follow_state(uuid, text) to service_role;
revoke all on function public.follow_person(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.follow_person(uuid, text, boolean) to service_role;
revoke all on function public.follow_list(text) from public, anon, authenticated;
grant execute on function public.follow_list(text) to service_role;
revoke all on function public.follow_choice(uuid, boolean) from public, anon, authenticated;
grant execute on function public.follow_choice(uuid, boolean) to service_role;
revoke all on function public.feed_who(uuid) from public, anon, authenticated;
grant execute on function public.feed_who(uuid) to service_role;
revoke all on function public.feed_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.feed_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.feed_of(uuid, timestamptz, integer, boolean) from public, anon, authenticated;
grant execute on function public.feed_of(uuid, timestamptz, integer, boolean) to service_role;
revoke all on function public.feed_count(uuid) from public, anon, authenticated;
grant execute on function public.feed_count(uuid) to service_role;
revoke all on function public.mail_kinds(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.mail_kinds(uuid, jsonb) to service_role;
revoke all on function public.claim_comment_digest(uuid) from public, anon, authenticated;
grant execute on function public.claim_comment_digest(uuid) to service_role;
