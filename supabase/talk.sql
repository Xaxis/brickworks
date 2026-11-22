-- Talk: a forum for builders on brickworks.diy, 2026-11-22 (unit talk;
-- docs/SOCIAL.md section 10, api/_talk.js, web/talk.html).
--
-- Until now people could talk only under one model or one step of it. Talk
-- is where they talk about anything else: show what they built, ask for
-- help, suggest, and talk about the month's challenge and the site's news.
-- A thread is a title and posts, in one of five boards:
--
--   show        Show and tell: a model, a photo of a build, work in progress.
--               A shared model's builder may start its thread from the
--               model's page (one live thread a model).
--   help        Help: how to build, the studio, parts.
--   ideas       Ideas: for models, and for Brickworks itself.
--   challenges  Challenges: each month's challenge opens its own thread
--               here, written by the house (talk_ensure).
--   news        News: the house's (Brickworks') news; anybody replies, only
--               the house starts a thread.
--
-- A post is plain text, 1 to 4,000 characters, as a comment is (no markup;
-- a line's end kept); a link to this site's model, step, set or challenge
-- is drawn as a card by the page (api/_talk.js embedsIn), any other link
-- is shown as the words it is, never as a link. A post may carry one photo
-- (api/_talk.js keeps it as a build photo is kept, nothing of the file but
-- its pixels), name people (@handle, three a post) and answer another post.
--
-- The ground rules, here whatever writes:
--
--   Who may write  a signed-in account that answered the age question 13
--                  or over, not taken out of the gallery, not banned from
--                  Talk; a test account (the checks') only in test threads,
--                  every other only in the others, so a check never writes
--                  where people read.
--   How often      a thread 3 an hour and 10 a day; a post 10 an hour and
--                  50 a day; an account made in the last day 3 threads and
--                  10 posts in that day (Discourse's first-day numbers); an
--                  edit 20 an hour and 100 a day; the same words twice in
--                  ten minutes refused; a report 20 a day.
--   Blocks         neither of two people one of whom blocked the other
--                  replies in a thread the other started, answers the
--                  other's post or names the other (talk_standing). The
--                  posts of somebody a thread's starter blocked are hidden
--                  in that thread from everybody but their writer, and a
--                  reader never sees the posts of anybody they blocked.
--   Moderation     the author edits or removes their own; anybody reports
--                  a post; three people's reports hide it until the site's
--                  owner looks; the owner, from /admin › Talk, hides, shows
--                  and removes posts and threads, locks, pins and moves a
--                  thread and bans an account from Talk (its posts hidden
--                  while it lasts), each act in the console's audit.
--                  Nothing is deleted by moderation: hidden and removed are
--                  times kept on the row.
--
--   talk_threads   one row a thread: its board, title, who started it,
--                  when, its last post's time, pinned, locked, hidden and
--                  removed, its model (Show and tell), its challenge, and
--                  the house's seed (each first thread once)
--   talk_posts     one row a post: its thread, author, words, the post it
--                  answers, its photo, and when it was written, edited,
--                  hidden (by reports or the owner) and removed
--   talk_follows   who follows which thread: told of each new post in it;
--                  starting a thread or posting in one follows it
--   talk_reads     how far each follower read a thread
--   talk_mentions  whom a post named
--   talk_reports   a report of a post, by whom, why; resolved by the owner
--   talk_bans      an account banned from Talk, until when (or for good)
--
-- Notifications: a new post in a thread you follow, and a post that names
-- you, are rows of notification_rows (kinds talk_reply and talk_mention),
-- so the avatar's count, Notifications and, where push_2.sql is applied, a
-- push tell them as they tell a comment. This file replaces announce.sql's
-- notification_rows with every row it gave and those, and push_2.sql's
-- push_collect with Talk's kinds (supabase/later.tsv).
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables. Every
-- row goes with its account (on delete cascade), a thread with its posts.
--
-- Only additions, applied after announce.sql, block.sql, challenges.sql,
-- challenge_year.sql and trust.sql (and push_2.sql for a push): seven new
-- tables, new functions, two triggers, notification_rows replaced with the
-- same rows and Talk's, and push_collect with Talk's kinds as well.
-- No existing row is changed, nothing dropped or renamed.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/talk.sql --table=talk_threads
--
-- Dry run, made-up accounts in a rolled-back transaction, hostile callers
-- tried (anon, another account, a banned one):
--
--   ... node tools/apply_sql.mjs supabase/talk.sql --dry --try=tools/talk_try.sql --table=talk_threads

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.talk_threads (
    id          bigserial primary key,
    board       text not null check (board in ('show', 'help', 'ideas', 'challenges', 'news')),
    title       text not null check (char_length(title) between 3 and 120 and title ~ '[^[:space:]]'
                    and title !~ '[\x01-\x1f\x7f]'),
    author      uuid not null references auth.users (id) on delete cascade,
    at          timestamptz not null default now(),
    last_at     timestamptz not null default now(),
    pinned_at   timestamptz,
    locked_at   timestamptz,
    hidden_at   timestamptz,
    removed_at  timestamptz,
    removed_by  text check (removed_by is null or removed_by in ('author', 'admin')),
    moved_from  text check (moved_from is null or moved_from in ('show', 'help', 'ideas', 'challenges', 'news')),
    model       text references public.shared_models (id) on delete set null,
    challenge   bigint references public.challenges (id) on delete set null,
    seed        text check (seed is null or seed ~ '^[a-z0-9-]{2,40}$'),
    test        boolean not null default false,
    check ((removed_at is null) = (removed_by is null))
);
create index if not exists talk_threads_board on public.talk_threads (test, board, last_at desc) where removed_at is null;
create index if not exists talk_threads_last on public.talk_threads (test, last_at desc) where removed_at is null;
create index if not exists talk_threads_author on public.talk_threads (author, at desc);
create index if not exists talk_threads_words on public.talk_threads using gin (to_tsvector('simple'::regconfig, title));
-- One live Show and tell thread a model, one thread a challenge, each seed once.
create unique index if not exists talk_threads_one_model on public.talk_threads (model) where model is not null and removed_at is null;
create unique index if not exists talk_threads_one_challenge on public.talk_threads (challenge) where challenge is not null;
create unique index if not exists talk_threads_one_seed on public.talk_threads (seed, test) where seed is not null;

create table if not exists public.talk_posts (
    id          bigserial primary key,
    thread      bigint not null references public.talk_threads (id) on delete cascade,
    author      uuid not null references auth.users (id) on delete cascade,
    body        text not null check (char_length(body) between 1 and 4000 and body ~ '[^[:space:]]'
                    and body !~ '[\x01-\x09\x0b-\x1f\x7f]'),
    first       boolean not null default false,
    answers     bigint references public.talk_posts (id) on delete set null,
    photo       text check (photo is null or photo ~ '^[A-Za-z0-9]{12}$'),
    photo_w     integer check (photo_w is null or photo_w between 1 and 4000),
    photo_h     integer check (photo_h is null or photo_h between 1 and 4000),
    at          timestamptz not null default now(),
    edited_at   timestamptz check (edited_at is null or edited_at >= at),
    hidden_at   timestamptz,
    hidden_by   text check (hidden_by is null or hidden_by in ('reports', 'admin')),
    removed_at  timestamptz,
    removed_by  text check (removed_by is null or removed_by in ('author', 'admin')),
    check ((removed_at is null) = (removed_by is null)),
    check ((hidden_at is null) = (hidden_by is null))
);
create index if not exists talk_posts_thread on public.talk_posts (thread, at, id);
create index if not exists talk_posts_author on public.talk_posts (author, at desc);
create index if not exists talk_posts_words on public.talk_posts using gin (to_tsvector('simple'::regconfig, body));
create unique index if not exists talk_posts_one_first on public.talk_posts (thread) where first;

create table if not exists public.talk_follows (
    account  uuid not null references auth.users (id) on delete cascade,
    thread   bigint not null references public.talk_threads (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (account, thread)
);
create index if not exists talk_follows_thread on public.talk_follows (thread);

create table if not exists public.talk_reads (
    account  uuid not null references auth.users (id) on delete cascade,
    thread   bigint not null references public.talk_threads (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (account, thread)
);

create table if not exists public.talk_mentions (
    post     bigint not null references public.talk_posts (id) on delete cascade,
    account  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (post, account)
);
create index if not exists talk_mentions_account on public.talk_mentions (account, at desc);

create table if not exists public.talk_reports (
    id          bigserial primary key,
    post        bigint not null references public.talk_posts (id) on delete cascade,
    reporter    uuid references auth.users (id) on delete set null,
    visitor     text check (visitor is null or visitor ~ '^[0-9a-f]{32}$'),
    reason      text not null check (reason in ('spam', 'offensive', 'sexual', 'violent',
                    'copied', 'trademark', 'personal', 'other')),
    note        text check (note is null or char_length(note) between 1 and 1000),
    at          timestamptz not null default now(),
    resolved_at timestamptz,
    resolution  text check (resolution is null or resolution in ('dismissed', 'hidden', 'removed', 'banned')),
    check (reporter is not null or visitor is not null)
);
create index if not exists talk_reports_open on public.talk_reports (at) where resolved_at is null;
create unique index if not exists talk_reports_once on public.talk_reports (post, reporter) where reporter is not null;

create table if not exists public.talk_bans (
    account  uuid primary key references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    until    timestamptz,
    reason   text check (reason is null or char_length(reason) <= 200)
);

alter table public.talk_threads enable row level security;
alter table public.talk_posts enable row level security;
alter table public.talk_follows enable row level security;
alter table public.talk_reads enable row level security;
alter table public.talk_mentions enable row level security;
alter table public.talk_reports enable row level security;
alter table public.talk_bans enable row level security;
revoke all on public.talk_threads from public, anon, authenticated, service_role;
revoke all on public.talk_posts from public, anon, authenticated, service_role;
revoke all on public.talk_follows from public, anon, authenticated, service_role;
revoke all on public.talk_reads from public, anon, authenticated, service_role;
revoke all on public.talk_mentions from public, anon, authenticated, service_role;
revoke all on public.talk_reports from public, anon, authenticated, service_role;
revoke all on public.talk_bans from public, anon, authenticated, service_role;
revoke all on sequence public.talk_threads_id_seq from public, anon, authenticated, service_role;
revoke all on sequence public.talk_posts_id_seq from public, anon, authenticated, service_role;
revoke all on sequence public.talk_reports_id_seq from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Who may write, and what is shown.

-- The house: the studio's own account (house.sql), handle brickworks.
create or replace function public.talk_house()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select p.account from public.people p where p.handle = 'brickworks'
$$;

-- Whether [account] is banned from Talk now; with [hiding], whether the ban
-- takes its posts out of Talk too (every ban does, while it lasts).
create or replace function public.talk_banned(account uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (select 1 from public.talk_bans b
                    where b.account = talk_banned.account and (b.until is null or b.until > now()))
$$;

-- Why [account] may not write in Talk now, or null when it may: sign_in,
-- barred, ask_first, under_13, banned. The API says each in words.
create or replace function public.talk_trouble(account uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    if account is null then
        return 'sign_in';
    end if;
    if public.is_barred(account) then
        return 'barred';
    end if;
    if (select p.over_13 from public.profiles p where p.id = account) is null then
        return 'ask_first';
    end if;
    if not public.trust_may_go_public(account) then
        return 'under_13';
    end if;
    if public.talk_banned(account) then
        return 'banned';
    end if;
    return null;
end;
$$;

-- Whether a post by [author] is shown at all: not barred, not kept private,
-- not banned from Talk.
create or replace function public.talk_shown(author uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select public.shown_publicly(author) and not public.talk_banned(author)
$$;

-- How [account] stands with whoever a post of theirs would reach in
-- [thread_id] (its starter) and as an answer to [answers_id] (that post's
-- author): 'blocked' when [account] blocked either, 'blocked_by' when
-- either blocked [account], else null.
create or replace function public.talk_standing(account uuid, thread_id bigint, answers_id bigint default null)
returns text
language sql
stable
security definer
set search_path = public
as $$
    with others as (
        select t.author as other from public.talk_threads t where t.id = thread_id
        union
        select p.author from public.talk_posts p where p.id = answers_id)
    select case
        when talk_standing.account is null then null
        when exists (select 1 from others o join public.blocks b on b.blocker = talk_standing.account and b.blocked = o.other
                      where o.other <> talk_standing.account) then 'blocked'
        when exists (select 1 from others o join public.blocks b on b.blocker = o.other and b.blocked = talk_standing.account
                      where o.other <> talk_standing.account) then 'blocked_by'
        end
$$;

-- Whether [viewer] may see post [p] of thread [t]: never once removed;
-- hidden ones (by reports or the owner) only to their author; the posts of
-- an account not shown, or banned, to nobody; those of somebody the
-- thread's starter blocked to nobody but their writer; and never those of
-- somebody [viewer] blocked.
create or replace function public.talk_post_shown(p public.talk_posts, t public.talk_threads, viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select p.removed_at is null
       and (p.hidden_at is null or (viewer is not null and p.author = viewer))
       and public.talk_shown(p.author)
       and (p.author = t.author or (viewer is not null and p.author = viewer)
            or not exists (select 1 from public.blocks b where b.blocker = t.author and b.blocked = p.author))
       and (viewer is null or p.author = viewer
            or not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = p.author))
$$;

-- Whether thread [t] is there for [viewer] in [tests]'s pool: not removed,
-- hidden only to its starter, a test one only asked with tests.
create or replace function public.talk_thread_shown(t public.talk_threads, viewer uuid, tests boolean)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select t.removed_at is null and t.test = coalesce(tests, false)
       and (t.hidden_at is null or (viewer is not null and t.author = viewer))
       and public.talk_shown(t.author)
$$;

-- A post as the page gets it.
create or replace function public.talk_post_as(p public.talk_posts, t public.talk_threads, viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', p.id, 'body', p.body, 'at', p.at, 'edited_at', p.edited_at, 'first', p.first,
        'answers', p.answers, 'hidden', p.hidden_at is not null, 'hidden_by', p.hidden_by,
        'photo', case when p.photo is null then null
                      else jsonb_build_object('id', p.photo, 'width', p.photo_w, 'height', p.photo_h) end,
        'mine', viewer is not null and p.author = viewer,
        'by_starter', p.author = t.author,
        'by_house', p.author = public.talk_house(),
        'by', w.name, 'handle', w.handle)
      from (select 1) as one
      left join public.people w on w.account = p.author and public.shown_publicly(p.author)
$$;

-- A thread as a list gets it: its words' start, who started it, how many
-- posts are shown, who wrote last, its model and its challenge.
create or replace function public.talk_thread_as(t public.talk_threads, viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'id', t.id, 'board', t.board, 'title', t.title, 'at', t.at, 'last_at', t.last_at,
        'pinned', t.pinned_at is not null, 'locked', t.locked_at is not null, 'hidden', t.hidden_at is not null,
        'mine', viewer is not null and t.author = viewer,
        'by_house', t.author = public.talk_house(),
        'by', public.feed_who(t.author),
        'said', (select left(p.body, 240) from public.talk_posts p where p.thread = t.id and p.first
                    and public.talk_post_shown(p, t, viewer)),
        'photo', (select jsonb_build_object('id', p.photo, 'width', p.photo_w, 'height', p.photo_h)
                    from public.talk_posts p where p.thread = t.id and p.photo is not null
                     and public.talk_post_shown(p, t, viewer) order by p.at, p.id limit 1),
        'replies', (select count(*) from public.talk_posts p where p.thread = t.id and not p.first
                       and public.talk_post_shown(p, t, viewer)),
        'last_by', (select public.feed_who(p.author) from public.talk_posts p where p.thread = t.id
                       and public.talk_post_shown(p, t, viewer) order by p.at desc, p.id desc limit 1),
        'model', (select jsonb_build_object('id', m.id, 'name', m.name, 'has_image', m.has_image,
                                            'has_thumb', m.has_thumb, 'updated_at', m.updated_at)
                    from public.shared_models m where m.id = t.model and m.published and not m.barred),
        'challenge', (select jsonb_build_object('id', c.id, 'title', c.title, 'starts_on', c.starts_on,
                                                'ends_on', c.ends_on, 'test', c.test)
                        from public.challenges c where c.id = t.challenge),
        'following', viewer is not null and exists (select 1 from public.talk_follows f
                                                     where f.account = viewer and f.thread = t.id),
        'unread', viewer is not null and exists (select 1 from public.talk_follows f where f.account = viewer and f.thread = t.id)
                  and t.last_at > coalesce((select r.at from public.talk_reads r where r.account = viewer and r.thread = t.id),
                                           (select f.at from public.talk_follows f where f.account = viewer and f.thread = t.id)))
$$;

-- ---------------------------------------------------------------------------
-- Reading.

-- What a search for [p_q] asks: each of its words (letters and digits, at
-- most eight) as the start of a word, all of them; null for no words.
create or replace function public.talk_query(p_q text)
returns tsquery
language sql
immutable
as $$
    select case when count(*) = 0 then null
                else to_tsquery('simple'::regconfig, string_agg(x.w || ':*', ' & ')) end
      from (select w from regexp_split_to_table(lower(left(coalesce(p_q, ''), 200)), '[^[:alnum:]]+') w
             where w <> '' limit 8) x
$$;

-- The threads of [p_board] (null: every board), newest talk first, pinned
-- first on the first page; [p_q] searches their titles and shown posts'
-- words (talk_query: each word as the start of one). Up to [p_limit] (at most 50) older than
-- [p_before] (a last_at), with [more]. Never a thread by somebody [viewer]
-- blocked.
create or replace function public.talk_threads_of(p_board text, p_tests boolean, viewer uuid default null,
    p_before timestamptz default null, p_limit integer default 30, p_q text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    most integer := greatest(1, least(coalesce(p_limit, 30), 50));
    q tsquery := public.talk_query(p_q);
    listed jsonb;
    n integer;
begin
    with found as (
        select t.* from public.talk_threads t
         where (p_board is null or t.board = p_board)
           and public.talk_thread_shown(t, viewer, p_tests)
           and (viewer is null or not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = t.author))
           and (p_before is null or t.last_at < p_before)
           and (q is null
                or to_tsvector('simple'::regconfig, t.title) @@ q
                or exists (select 1 from public.talk_posts p where p.thread = t.id
                            and to_tsvector('simple'::regconfig, p.body) @@ q and public.talk_post_shown(p, t, viewer)))
         order by case when p_before is null and q is null and t.pinned_at is not null then 0 else 1 end,
                  t.last_at desc, t.id desc
         limit most + 1)
    select coalesce(jsonb_agg(public.talk_thread_as(f, viewer)), '[]'::jsonb), count(*)::integer
      into listed, n
      from (select * from found limit most) f;
    return jsonb_build_object('threads', listed,
        'more', (select count(*) from (select 1 from public.talk_threads t
                  where (p_board is null or t.board = p_board) and public.talk_thread_shown(t, viewer, p_tests)
                    and (viewer is null or not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = t.author))
                    and (p_before is null or t.last_at < p_before)
                    and (q is null or to_tsvector('simple'::regconfig, t.title) @@ q
                         or exists (select 1 from public.talk_posts p where p.thread = t.id
                                     and to_tsvector('simple'::regconfig, p.body) @@ q))
                  limit most + 1) x) > most,
        'searched', q is not null);
end;
$$;

-- How many threads each board has now, in [p_tests]'s pool.
create or replace function public.talk_board_counts(p_tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_object_agg(b.board, b.n), '{}'::jsonb)
      from (select t.board, count(*) as n from public.talk_threads t
             where public.talk_thread_shown(t, null, p_tests) group by t.board) b
$$;

-- Thread [p_thread] for [viewer]: {thread, posts, you}, the posts oldest
-- first (at most 500), or null when it is not there for them.
create or replace function public.talk_thread_page(p_thread bigint, p_tests boolean, viewer uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    t public.talk_threads;
    listed jsonb;
    hidden_some boolean;
begin
    select * into t from public.talk_threads k where k.id = p_thread;
    if not found or not public.talk_thread_shown(t, viewer, p_tests) then
        return null;
    end if;
    select coalesce(jsonb_agg(public.talk_post_as(p, t, viewer) order by p.at, p.id), '[]'::jsonb)
      into listed
      from (select * from public.talk_posts k where k.thread = t.id and public.talk_post_shown(k, t, viewer)
             order by k.at, k.id limit 500) p;
    -- Whether some posts here are by somebody the viewer blocked, so the
    -- page can say why the talk skips.
    hidden_some := viewer is not null and exists (
        select 1 from public.talk_posts p join public.blocks b on b.blocker = viewer and b.blocked = p.author
         where p.thread = t.id and p.removed_at is null);
    return jsonb_build_object('thread', public.talk_thread_as(t, viewer), 'posts', listed,
        'blocked_some', hidden_some,
        'you', jsonb_build_object('trouble', public.talk_trouble(viewer),
                                  'standing', public.talk_standing(viewer, t.id),
                                  'pool', viewer is null or public.trust_is_test_account(viewer) = t.test,
                                  'starter', viewer is not null and viewer = t.author));
end;
$$;

-- The talk already happening on models: the newest comments and replies on
-- models listed in the gallery, as their pages show them (not hidden,
-- removed, by an account not shown, or by somebody the model's owner
-- blocked; this life of the link), never by somebody [viewer] blocked.
-- [{comment, parent, model, name, has_image, has_thumb, updated_at,
-- version, step, said, at, by}], at most [p_limit] (50).
create or replace function public.talk_talking(p_tests boolean, viewer uuid default null, p_limit integer default 12)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object(
               'comment', k.id, 'parent', k.parent, 'model', m.id, 'name', m.name, 'has_image', m.has_image,
               'has_thumb', m.has_thumb, 'updated_at', m.updated_at, 'version', k.version, 'step', k.step,
               'said', left(k.body, 240), 'at', k.at, 'by', public.feed_who(k.author)) order by k.at desc, k.id desc),
           '[]'::jsonb)
      from (select c.* from public.model_comments c
              join public.shared_models s on s.id = c.model
             where s.published and s.listed and not s.barred and s.test = coalesce(p_tests, false)
               and public.trust_is_test_account(c.author) = coalesce(p_tests, false)
               and c.removed_at is null and c.hidden_at is null
               and public.shown_publicly(c.author) and public.shown_publicly(s.owner)
               and not exists (select 1 from public.blocks b where b.blocker = s.owner and b.blocked = c.author)
               and (viewer is null or c.author = viewer
                    or not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = c.author))
               and (c.parent is null or exists (select 1 from public.model_comments r where r.id = c.parent
                                                 and r.removed_at is null and r.hidden_at is null))
               and c.at >= coalesce((select min(v.at) from public.share_versions v where v.model = c.model), '-infinity')
             order by c.at desc, c.id desc
             limit greatest(1, least(coalesce(p_limit, 12), 50))) k
      join public.shared_models m on m.id = k.model
$$;

-- Whether photo [p_photo] (its id) is on a post anybody may see now: its
-- file is served only then (api/_talk.js photoFile).
create or replace function public.talk_photo_shown(p_photo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (select 1 from public.talk_posts p join public.talk_threads t on t.id = p.thread
                    where p.photo = p_photo and public.talk_post_shown(p, t, null)
                      and t.removed_at is null and t.hidden_at is null and public.talk_shown(t.author))
$$;

-- The photos [account] posted in Talk, every one: deleted by name with the
-- account (api/_erase.js), as storage keeps no link to it.
create or replace function public.talk_photos_of(account uuid)
returns text[]
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(array_agg(p.photo), '{}'::text[]) from public.talk_posts p
     where p.author = talk_photos_of.account and p.photo is not null
$$;

-- Model [p_model]'s Show and tell thread, if it has one shown in
-- [p_tests]'s pool: {id, title, replies}, or null.
create or replace function public.talk_model_thread(p_model text, p_tests boolean)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', t.id, 'title', t.title,
               'replies', (select count(*) from public.talk_posts p where p.thread = t.id and not p.first
                             and public.talk_post_shown(p, t, null)))
      from public.talk_threads t
     where t.model = p_model and public.talk_thread_shown(t, null, p_tests)
     limit 1
$$;

-- ---------------------------------------------------------------------------
-- Writing.

-- Words a post or a title may hold: 1 to [most] characters of plain text.
create or replace function public.talk_words_ok(said text, most integer)
returns boolean
language sql
immutable
as $$
    select said is not null and char_length(said) between 1 and most and said ~ '[^[:space:]]'
       and said !~ '[\x01-\x09\x0b-\x1f\x7f]'
$$;

-- Whether [account] may write once more as [act] ('thread' or 'post'):
-- the hour's and the day's, fewer on an account's first day.
create or replace function public.talk_may(account uuid, act text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    young boolean := coalesce((select u.created_at > now() - interval '1 day' from auth.users u where u.id = account), true);
begin
    if act = 'thread' then
        return public.may_act(account::text, 'talk_thread', 3, case when young then 3 else 10 end);
    end if;
    return public.may_act(account::text, 'talk_post', 10, case when young then 10 else 50 end);
end;
$$;

-- The same words from [account] within ten minutes: refused, a flood.
create or replace function public.talk_again(account uuid, said text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (select 1 from public.talk_posts p
                    where p.author = account and p.body = said and p.at > now() - interval '10 minutes'
                      and p.removed_at is null)
$$;

-- Mark [accounts] due a push, where push.sql is applied; nothing otherwise.
-- Never fails a write.
create or replace function public.talk_push(accounts uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if accounts is null or cardinality(accounts) = 0 or to_regprocedure('public.push_mark(uuid[])') is null then
        return;
    end if;
    execute 'select public.push_mark($1)' using accounts;
exception when others then
    raise warning 'talk_push: %', sqlerrm;
end;
$$;

-- A new thread from [account] on [p_board]: its title and first post's
-- words, with [p_model] (Show and tell: one of the account's own published
-- models) and [p_photo] ({id, width, height}). {thread, post} as the page
-- gets them, or {refused}: talk_trouble's, board, news (only the house
-- starts one there), title, body, model, again, limit.
create or replace function public.talk_start(account uuid, p_board text, p_title text, p_said text,
    p_model text default null, p_photo jsonb default null, p_seed text default null, p_challenge bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.talk_trouble(account);
    house uuid := public.talk_house();
    made public.talk_threads;
    post public.talk_posts;
    test_pool boolean;
begin
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    if p_board is null or p_board not in ('show', 'help', 'ideas', 'challenges', 'news') then
        return jsonb_build_object('refused', 'board');
    end if;
    if p_board = 'news' and account is distinct from house then
        return jsonb_build_object('refused', 'news');
    end if;
    if not public.talk_words_ok(p_title, 120) or char_length(p_title) < 3 or p_title ~ '[\x01-\x1f\x7f]' then
        return jsonb_build_object('refused', 'title');
    end if;
    if not public.talk_words_ok(p_said, 4000) then
        return jsonb_build_object('refused', 'body');
    end if;
    if p_model is not null and not exists (select 1 from public.shared_models m where m.id = p_model and m.owner = account
                                                and m.published and not m.barred) then
        return jsonb_build_object('refused', 'model');
    end if;
    if p_model is not null and exists (select 1 from public.talk_threads t where t.model = p_model and t.removed_at is null) then
        return jsonb_build_object('refused', 'model_has', 'thread',
            (select t.id from public.talk_threads t where t.model = p_model and t.removed_at is null));
    end if;
    if public.talk_again(account, p_said) then
        return jsonb_build_object('refused', 'again');
    end if;
    if not public.talk_may(account, 'thread') then
        return jsonb_build_object('refused', 'limit');
    end if;
    test_pool := public.trust_is_test_account(account);
    insert into public.talk_threads (board, title, author, model, seed, challenge, test)
    values (p_board, p_title, account, p_model, p_seed, p_challenge,
            case when p_challenge is not null then (select c.test from public.challenges c where c.id = p_challenge)
                 else test_pool end)
    returning * into made;
    insert into public.talk_posts (thread, author, body, first, photo, photo_w, photo_h)
    values (made.id, account, p_said, true, p_photo->>'id', (p_photo->>'width')::integer, (p_photo->>'height')::integer)
    returning * into post;
    insert into public.talk_follows (account, thread) values (account, made.id) on conflict do nothing;
    return jsonb_build_object('thread', public.talk_thread_as(made, account), 'post', public.talk_post_as(post, made, account));
end;
$$;

-- A post from [account] in [p_thread], answering [p_answers] (a post of
-- that thread) or none, with [p_photo]. {post, followers: whom to tell},
-- or {refused}: talk_trouble's, no_thread, locked, pool, blocked,
-- blocked_by, body, no_post, again, limit.
create or replace function public.talk_reply(account uuid, p_thread bigint, p_said text,
    p_answers bigint default null, p_photo jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.talk_trouble(account);
    t public.talk_threads;
    made public.talk_posts;
    standing text;
begin
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    select * into t from public.talk_threads k where k.id = p_thread;
    if not found or t.removed_at is not null or (t.hidden_at is not null and t.author <> account)
       or not public.talk_shown(t.author) then
        return jsonb_build_object('refused', 'no_thread');
    end if;
    -- A check's account writes only in a check's thread, and nobody else does.
    if t.test <> public.trust_is_test_account(account) then
        return jsonb_build_object('refused', 'no_thread');
    end if;
    if t.locked_at is not null then
        return jsonb_build_object('refused', 'locked');
    end if;
    if p_answers is not null and not exists (select 1 from public.talk_posts p where p.id = p_answers and p.thread = t.id
                                                 and public.talk_post_shown(p, t, account)) then
        return jsonb_build_object('refused', 'no_post');
    end if;
    standing := public.talk_standing(account, t.id, p_answers);
    if standing is not null then
        return jsonb_build_object('refused', standing);
    end if;
    if not public.talk_words_ok(p_said, 4000) then
        return jsonb_build_object('refused', 'body');
    end if;
    if public.talk_again(account, p_said) then
        return jsonb_build_object('refused', 'again');
    end if;
    if not public.talk_may(account, 'post') then
        return jsonb_build_object('refused', 'limit');
    end if;
    insert into public.talk_posts (thread, author, body, answers, photo, photo_w, photo_h)
    values (t.id, account, p_said, p_answers, p_photo->>'id', (p_photo->>'width')::integer, (p_photo->>'height')::integer)
    returning * into made;
    update public.talk_threads set last_at = made.at where id = t.id;
    insert into public.talk_follows (account, thread) values (account, t.id) on conflict do nothing;
    insert into public.talk_reads (account, thread, at) values (account, t.id, made.at)
    on conflict on constraint talk_reads_pkey do update set at = greatest(public.talk_reads.at, excluded.at);
    return jsonb_build_object('post', public.talk_post_as(made, t, account));
end;
$$;

-- Its author edits post [p_post] ('edit', with [p_said]) or removes it
-- ('remove'; the first post removes its thread). {post, removed}, or
-- {refused}: no_post, not_yours, locked, body, again, limit, or
-- talk_trouble's for an edit.
create or replace function public.talk_change(account uuid, p_post bigint, p_what text, p_said text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.talk_posts;
    t public.talk_threads;
    trouble text;
begin
    select * into p from public.talk_posts k where k.id = p_post and k.removed_at is null;
    if not found or account is null then
        return jsonb_build_object('refused', 'no_post');
    end if;
    select * into t from public.talk_threads k where k.id = p.thread;
    if t.removed_at is not null then
        return jsonb_build_object('refused', 'no_post');
    end if;
    if p.author <> account then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    if p_what = 'edit' then
        trouble := public.talk_trouble(account);
        if trouble is not null then
            return jsonb_build_object('refused', trouble);
        end if;
        if t.locked_at is not null then
            return jsonb_build_object('refused', 'locked');
        end if;
        if not public.talk_words_ok(p_said, 4000) then
            return jsonb_build_object('refused', 'body');
        end if;
        if not public.may_act(account::text, 'talk_edit', 20, 100) then
            return jsonb_build_object('refused', 'limit');
        end if;
        update public.talk_posts set body = p_said, edited_at = now() where id = p.id returning * into p;
    elsif p_what = 'remove' then
        update public.talk_posts set removed_at = now(), removed_by = 'author' where id = p.id returning * into p;
        if p.first then
            update public.talk_threads set removed_at = now(), removed_by = 'author' where id = t.id returning * into t;
        end if;
    else
        raise exception 'brickworks: edit or remove' using errcode = '22023';
    end if;
    return jsonb_build_object('post', public.talk_post_as(p, t, account), 'removed', p.removed_at is not null,
        'thread_removed', t.removed_at is not null);
end;
$$;

-- [account] follows thread [p_thread] ([p_on] true) or stops. {following}
-- or {refused: no_thread | sign_in}.
create or replace function public.talk_follow(account uuid, p_thread bigint, p_on boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    t public.talk_threads;
begin
    if account is null then
        return jsonb_build_object('refused', 'sign_in');
    end if;
    select * into t from public.talk_threads k where k.id = p_thread;
    if not found or not public.talk_thread_shown(t, account, public.trust_is_test_account(account)) then
        return jsonb_build_object('refused', 'no_thread');
    end if;
    if p_on then
        if not public.may_act(account::text, 'talk_follow', 60, 300) then
            return jsonb_build_object('refused', 'limit');
        end if;
        insert into public.talk_follows (account, thread) values (account, t.id) on conflict do nothing;
        insert into public.talk_reads (account, thread, at) values (account, t.id, now())
        on conflict on constraint talk_reads_pkey do update set at = greatest(public.talk_reads.at, excluded.at);
    else
        delete from public.talk_follows f where f.account = talk_follow.account and f.thread = t.id;
    end if;
    return jsonb_build_object('following', exists (select 1 from public.talk_follows f
                                                    where f.account = talk_follow.account and f.thread = t.id));
end;
$$;

-- [account] read thread [p_thread] up to now: {read}.
create or replace function public.talk_read(account uuid, p_thread bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
    if account is null or not exists (select 1 from public.talk_threads t where t.id = p_thread) then
        return jsonb_build_object('read', false);
    end if;
    insert into public.talk_reads (account, thread, at) values (account, p_thread, now())
    on conflict on constraint talk_reads_pkey do update set at = excluded.at;
    return jsonb_build_object('read', true);
end;
$$;

-- Whom post [p_post] by [account] names, of [handles]: each with a profile
-- shown in public, 13 or over, not its writer, in the writer's pool,
-- neither blocking the other; three a post, ever. {mentioned: [{handle,
-- name}]}, every one it names now.
create or replace function public.talk_mention(account uuid, p_post bigint, handles text[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.talk_posts;
    pool boolean;
begin
    select * into p from public.talk_posts k where k.id = p_post and k.author = talk_mention.account and k.removed_at is null;
    if not found then
        return jsonb_build_object('mentioned', '[]'::jsonb);
    end if;
    pool := public.trust_is_test_account(talk_mention.account);
    insert into public.talk_mentions (post, account)
    select p.id, w.account
      from public.people w
     where w.handle = any (coalesce(handles, '{}'::text[])) and w.account <> talk_mention.account
       and public.shown_publicly(w.account) and public.trust_may_go_public(w.account)
       and public.trust_is_test_account(w.account) = pool
       and public.block_between(talk_mention.account, w.account) is null
       and (select count(*) from public.talk_mentions m where m.post = p.id) < 3
     order by array_position(handles, w.handle)
     limit greatest(0, 3 - (select count(*) from public.talk_mentions m where m.post = p.id))
    on conflict do nothing;
    return jsonb_build_object('mentioned', coalesce((
        select jsonb_agg(jsonb_build_object('handle', w.handle, 'name', w.name) order by w.handle)
          from public.talk_mentions m join public.people w on w.account = m.account
         where m.post = p.id), '[]'::jsonb));
end;
$$;

-- Whom each of [post_ids] named: [{post, handle, name}].
create or replace function public.talk_mentions_of(post_ids bigint[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('post', m.post, 'handle', w.handle, 'name', w.name)), '[]'::jsonb)
      from public.talk_mentions m join public.people w on w.account = m.account
     where m.post = any (coalesce(post_ids, '{}'::bigint[])) and public.shown_publicly(m.account)
$$;

-- A report of post [p_post] by [account] (or a visitor's key): {report,
-- hidden} or {refused: no_post | yours | limit}. One a person a post; three
-- signed-in people's hide it until the owner looks (Discourse's flags).
create or replace function public.talk_report(account uuid, p_visitor text, p_post bigint, p_reason text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    p public.talk_posts;
    t public.talk_threads;
    made bigint;
    reporters integer;
    hid boolean := false;
begin
    select * into p from public.talk_posts k where k.id = p_post and k.removed_at is null;
    if not found then
        return jsonb_build_object('refused', 'no_post');
    end if;
    select * into t from public.talk_threads k where k.id = p.thread;
    if t.removed_at is not null or not public.talk_post_shown(p, t, account) then
        return jsonb_build_object('refused', 'no_post');
    end if;
    if account is not null and p.author = account then
        return jsonb_build_object('refused', 'yours');
    end if;
    if not public.may_act(coalesce(account::text, 'visitor:' || coalesce(p_visitor, '')), 'talk_report', 10, 20) then
        return jsonb_build_object('refused', 'limit');
    end if;
    if account is not null and exists (select 1 from public.talk_reports r where r.post = p.id and r.reporter = account) then
        return jsonb_build_object('report', (select r.id from public.talk_reports r where r.post = p.id and r.reporter = account),
            'hidden', p.hidden_at is not null, 'again', true);
    end if;
    insert into public.talk_reports (post, reporter, visitor, reason, note)
    values (p.id, account, case when account is null then p_visitor end, p_reason, nullif(btrim(coalesce(p_note, '')), ''))
    returning id into made;
    -- Three different signed-in people of its pool: hidden until the owner looks.
    select count(distinct r.reporter) into reporters
      from public.talk_reports r
     where r.post = p.id and r.resolved_at is null and r.reporter is not null
       and public.trust_is_test_account(r.reporter) = t.test;
    if reporters >= 3 and p.hidden_at is null then
        update public.talk_posts set hidden_at = now(), hidden_by = 'reports' where id = p.id;
        hid := true;
    end if;
    return jsonb_build_object('report', made, 'hidden', hid or p.hidden_at is not null);
end;
$$;

-- ---------------------------------------------------------------------------
-- The house's threads.

-- Each challenge open now (or told, and not yet ended) in [p_tests]'s pool
-- has its thread in Challenges, started by the house with its brief and its
-- link; made the first time Talk is read after it opens. The number made.
create or replace function public.talk_ensure(p_tests boolean)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    house uuid := public.talk_house();
    c record;
    made integer := 0;
    t bigint;
begin
    if house is null then
        return 0;
    end if;
    for c in
        select k.id, k.title, k.brief, k.starts_on, k.ends_on, k.test from public.challenges k
         where k.test = coalesce(p_tests, false) and k.ended_at is null
           and k.ends_on >= (now() at time zone 'utc')::date
           and (k.starts_on <= (now() at time zone 'utc')::date or k.announced_at is not null)
           and not exists (select 1 from public.talk_threads x where x.challenge = k.id)
         order by k.starts_on
         limit 5
    loop
        perform pg_advisory_xact_lock(hashtext('talk_challenge:' || c.id::text));
        continue when exists (select 1 from public.talk_threads x where x.challenge = c.id);
        insert into public.talk_threads (board, title, author, challenge, test)
        values ('challenges', left(c.title, 120), house, c.id, c.test)
        returning id into t;
        insert into public.talk_posts (thread, author, body, first)
        values (t, house, left(c.brief || E'\n\n' || 'Enter, see the entries and vote: https://brickworks.diy/challenge?id='
                       || c.id::text || case when c.test then '&tests=1' else '' end
                       || E'\n\n' || 'Ask about the brief, show work in progress and cheer each other on here.', 4000), true);
        insert into public.talk_follows (account, thread) values (house, t) on conflict do nothing;
        made := made + 1;
    end loop;
    return made;
end;
$$;

-- The house's first thread [p_seed] (welcome, how to ask for help, the
-- news), written once in [p_test]'s pool, dated when it is first written:
-- {thread} its id, made now or before.
create or replace function public.talk_seed(p_seed text, p_board text, p_title text, p_said text, p_test boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    house uuid := public.talk_house();
    t bigint;
begin
    if house is null or p_seed !~ '^[a-z0-9-]{2,40}$' or p_board not in ('show', 'help', 'ideas', 'challenges', 'news')
       or not public.talk_words_ok(p_title, 120) or not public.talk_words_ok(p_said, 4000) then
        return jsonb_build_object('thread', null);
    end if;
    perform pg_advisory_xact_lock(hashtext('talk_seed:' || p_seed || ':' || coalesce(p_test, false)::text));
    select x.id into t from public.talk_threads x where x.seed = p_seed and x.test = coalesce(p_test, false);
    if t is not null then
        return jsonb_build_object('thread', t, 'made', false);
    end if;
    insert into public.talk_threads (board, title, author, seed, test)
    values (p_board, p_title, house, p_seed, coalesce(p_test, false))
    returning id into t;
    insert into public.talk_posts (thread, author, body, first) values (t, house, p_said, true);
    insert into public.talk_follows (account, thread) values (house, t) on conflict do nothing;
    return jsonb_build_object('thread', t, 'made', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Notifications.

-- [viewer]'s Talk rows from after [since] up to [until], as notification_rows
-- gives its rows (no model): a post by somebody else in a thread they
-- follow, after they followed it (talk_reply); a post that names them, in a
-- thread they do not follow (talk_mention). [item] says the thread, its
-- title, the post, its first words, who, and [read] once they opened the
-- thread after it.
create or replace function public.talk_notice_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, model text, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    select 'talk_reply'::text, p.at, null::text,
           jsonb_build_object('thread', t.id, 'title', t.title, 'board', t.board, 'post', p.id, 'said', left(p.body, 240),
                              'by', public.feed_who(p.author), 'yours', t.author = viewer, 'test', t.test,
                              'read', coalesce(r.at >= p.at, false))
      from public.talk_follows f
      join public.talk_threads t on t.id = f.thread
      join public.talk_posts p on p.thread = t.id and p.at > f.at
      left join public.talk_reads r on r.account = viewer and r.thread = t.id
     where f.account = viewer and p.author <> viewer and not p.first
       and t.removed_at is null and t.hidden_at is null
       and p.at > since and p.at <= until
       and public.talk_post_shown(p, t, null)
       and not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = p.author)
    union all
    select 'talk_mention'::text, p.at, null::text,
           jsonb_build_object('thread', t.id, 'title', t.title, 'board', t.board, 'post', p.id, 'said', left(p.body, 240),
                              'by', public.feed_who(p.author), 'test', t.test,
                              'read', coalesce(r.at >= p.at, false))
      from public.talk_mentions n
      join public.talk_posts p on p.id = n.post
      join public.talk_threads t on t.id = p.thread
      left join public.talk_reads r on r.account = viewer and r.thread = t.id
     where n.account = viewer and p.author <> viewer
       and t.removed_at is null and t.hidden_at is null
       and p.at > since and p.at <= until
       and public.talk_post_shown(p, t, null)
       and not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = p.author)
       and not exists (select 1 from public.talk_follows f where f.account = viewer and f.thread = t.id and p.at > f.at)
$$;

-- What happened to [viewer]'s models, the replies to them, the levels
-- they reached, the challenges, the mentions and the owner's announcements,
-- as announce.sql's; and Talk's (talk_notice_rows).
create or replace function public.notification_rows(viewer uuid, since timestamptz, until timestamptz)
returns table (kind text, at timestamptz, model text, item jsonb)
language sql
stable
security definer
set search_path = public
as $$
    with mine as (
        select m.id, m.name from public.shared_models m
         where m.owner = viewer and m.published and not m.barred),
    threads as (
        -- The conversations the viewer is in: each comment of theirs, or
        -- the one they replied to, from when they joined it.
        select coalesce(o.parent, o.id) as root, min(o.at) as joined, bool_or(o.parent is null) as theirs
          from public.model_comments o
         where o.author = viewer and o.removed_at is null
         group by coalesce(o.parent, o.id))
    select f.kind, f.at,
           case when f.kind = 'remix' then f.item->>'of' else f.item->>'model' end,
           f.item || case when k.parent is not null then jsonb_build_object('parent', k.parent) else '{}'::jsonb end
      from public.feed_rows(viewer, since, until) f
      left join public.model_comments k on f.kind = 'comment' and k.id = (f.item->>'comment')::bigint
     where (f.kind in ('comment', 'remix') or (f.kind = 'photo' and (f.item->>'yours')::boolean))
       and public.comment_parent_shown(k.parent)
       -- Told below, as a reply.
       and not exists (select 1 from threads t where t.root = k.parent and k.at > t.joined)
    union all
    -- A reply in one of those, by somebody else, in this life of its
    -- link (comments_on's rule).
    select 'reply'::text, k.at, k.model,
           jsonb_build_object('comment', k.id, 'parent', k.parent, 'yours', t.theirs, 'model', k.model,
                              'name', m.name, 'version', k.version, 'step', k.step, 'said', left(k.body, 240),
                              'by', public.feed_who(k.author))
      from threads t
      join public.model_comments k on k.parent = t.root and k.at > t.joined
      join public.shared_models m on m.id = k.model
     where k.author <> viewer and m.published and not m.barred
       and k.removed_at is null and k.hidden_at is null and public.shown_publicly(k.author)
       and public.comment_parent_shown(k.parent)
       and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = k.model), '-infinity')
       and k.at > since and k.at <= until
    union all
    select 'likes'::text, max(l.at), m.id,
           jsonb_build_object('model', m.id, 'name', m.name, 'likes', count(*),
                              'day', to_char(l.at at time zone 'UTC', 'YYYY-MM-DD'))
      from public.model_likes l
      join mine m on m.id = l.model
     where l.account <> viewer and l.at > since and l.at <= until
     group by m.id, m.name, to_char(l.at at time zone 'UTC', 'YYYY-MM-DD')
    union all
    select 'result'::text, c.settled_at, m.id,
           jsonb_build_object('model', m.id, 'name', m.name, 'challenge', c.id, 'title', c.title,
                              'way', e.way, 'won', w.model is not null, 'votes', w.votes)
      from public.challenge_entries e
      join public.challenges c on c.id = e.challenge
      join mine m on m.id = e.model
      left join public.challenge_winners w on w.challenge = c.id and w.way = e.way and w.model = e.model
     where e.owner = viewer and c.settled_at is not null
       and c.settled_at > since and c.settled_at <= until
    union all
    select 'achievement'::text, a.at, null::text,
           jsonb_build_object('track', a.track, 'level', max(a.level), 'of', cardinality(l.steps),
                              'reached', l.steps[max(a.level)], 'next', l.steps[max(a.level) + 1],
                              'read', bool_and(a.read_at is not null))
      from public.achievement_marks a
      join public.achievement_ladders() l on l.track = a.track
     where a.account = viewer and a.at > since and a.at <= until
     group by a.track, a.at, l.steps
    union all
    -- A challenge opened (or, told later, was told), and the start of its
    -- last two days, unless the viewer entered it: for an account that may
    -- enter, made before then, until the challenge ended. A test account
    -- hears of the test challenges, every other account of the others.
    select k.kind, k.at, null::text,
           jsonb_build_object('challenge', c.id, 'title', c.title, 'ends_on', c.ends_on, 'test', c.test,
                              'read', coalesce(r.at >= k.at, false))
      from public.challenges c
     cross join lateral (
            select greatest(c.starts_on::timestamp at time zone 'utc', coalesce(c.announced_at, '-infinity')) as opened,
                   (c.ends_on - 1)::timestamp at time zone 'utc' as closing) d
     cross join lateral (values ('challenge_open'::text, d.opened), ('challenge_closing'::text, d.closing)) k(kind, at)
      left join public.challenge_reads r on r.account = viewer and r.challenge = c.id
     where c.test = public.trust_is_test_account(viewer)
       and public.trust_may_go_public(viewer) and not public.is_barred(viewer)
       and k.at > since and k.at <= until and k.at <= now()
       and (c.ended_at is null or c.ended_at > k.at)
       and k.at > (select u.created_at from auth.users u where u.id = viewer)
       and (k.kind = 'challenge_open'
            or (d.closing > d.opened
                and not exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.owner = viewer)))
    union all
    -- Who won, for whoever voted in it and entered nothing (an entrant
    -- hears as 'result', under their model); [picked] when a model they
    -- voted for won.
    select 'challenge_won'::text, c.settled_at, null::text,
           jsonb_build_object('challenge', c.id, 'title', c.title, 'ends_on', c.ends_on, 'test', c.test,
                              'picked', exists (select 1 from public.challenge_votes v
                                                  join public.challenge_winners w
                                                    on w.challenge = v.challenge and w.way = v.way and w.model = v.model
                                                 where v.challenge = c.id and v.voter = viewer),
                              'read', coalesce(r.at >= c.settled_at, false))
      from public.challenges c
      left join public.challenge_reads r on r.account = viewer and r.challenge = c.id
     where c.settled_at is not null and c.settled_at > since and c.settled_at <= until
       and exists (select 1 from public.challenge_votes v where v.challenge = c.id and v.voter = viewer)
       and not exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.owner = viewer)
    union all
    -- A comment or a reply that names the viewer (@handle), by somebody
    -- else, as a reply is told: unless the viewer hears it already, as a
    -- comment on their own model or a reply in their own conversation.
    select 'mention'::text, k.at, k.model,
           jsonb_build_object('comment', k.id, 'parent', k.parent, 'model', k.model, 'name', m.name,
                              'version', k.version, 'step', k.step, 'said', left(k.body, 240),
                              'by', public.feed_who(k.author))
      from public.comment_mentions n
      join public.model_comments k on k.id = n.comment
      join public.shared_models m on m.id = k.model
     where n.account = viewer and k.author <> viewer and m.owner <> viewer and m.published and not m.barred
       and k.removed_at is null and k.hidden_at is null and public.shown_publicly(k.author)
       and public.comment_parent_shown(k.parent)
       and not exists (select 1 from threads t where t.root = k.parent and k.at > t.joined)
       and k.at >= coalesce((select min(v.at) from public.share_versions v where v.model = k.model), '-infinity')
       and k.at > since and k.at <= until
    union all
    -- An announcement from the owner, to each account it was sent to.
    select * from public.announcement_rows(viewer, since, until)
    union all
    -- Talk: a new post in a thread the viewer follows, and one naming them.
    select * from public.talk_notice_rows(viewer, since, until)
$$;

-- A post in a thread, or a name in one: whoever follows it (but its
-- writer), or was named, may hear of it on a device (push.sql).
create or replace function public.talk_push_on_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if not new.first then
        perform public.talk_push(array(select f.account from public.talk_follows f
                                         where f.thread = new.thread and f.account <> new.author));
    end if;
    return new;
exception when others then
    raise warning 'talk_push_on_post: %', sqlerrm;
    return new;
end;
$$;
create or replace function public.talk_push_on_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.talk_push(array[new.account]);
    return new;
exception when others then
    raise warning 'talk_push_on_mention: %', sqlerrm;
    return new;
end;
$$;
drop trigger if exists talk_push_on_post on public.talk_posts;
create trigger talk_push_on_post after insert on public.talk_posts
    for each row execute function public.talk_push_on_post();
drop trigger if exists talk_push_on_mention on public.talk_mentions;
create trigger talk_push_on_mention after insert on public.talk_mentions
    for each row execute function public.talk_push_on_mention();

-- A push for Talk's rows too: push_2.sql's push_collect with Talk's two
-- kinds, a post's key, and a thread's own "last" (one push a thread, its
-- newest post's words; three minutes apart, as a model's), only where
-- push_2.sql is applied: nothing to replace otherwise, and that file then
-- goes in whole (supabase/later.tsv refuses it alone once this is live).
do $do$
begin
    if to_regprocedure('public.push_collect(uuid, integer)') is null then
        raise notice 'talk.sql: push_2.sql is not applied, so Talk has no push yet: apply this again after it';
        return;
    end if;
    execute $fn$
create or replace function public.push_collect(p_account uuid, p_tries integer default 0)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    since timestamptz;
    devices jsonb;
begin
    delete from public.push_subscriptions s where s.account = p_account and not public.push_alive(s.session);
    select min(s.made_at) into since from public.push_subscriptions s where s.account = p_account;
    if since is null then
        return null;
    end if;
    with fresh as (
        select distinct on (k.key) k.key, r.kind, r.at, coalesce(r.model, '') as model, r.item
          from public.notification_rows(p_account, greatest(since, now() - interval '30 minutes'), now()) r
         cross join lateral (select left(r.kind || ':' || coalesce(r.item->>'comment', r.item->>'photo',
                                 r.item->>'challenge', r.item->>'post', '') || ':' || coalesce(r.item->>'model', r.model, ''), 180) as key) k
         where r.kind in ('comment', 'reply', 'mention', 'photo', 'remix', 'result', 'talk_reply', 'talk_mention')
         order by k.key, r.at desc),
    pairs as (
        select w.key, w.kind, w.at, w.model, w.item, s.endpoint,
               w.key || '@' || left(md5(s.endpoint), 12) as sent_key,
               'last:' || coalesce(nullif(w.model, ''),
                                    case when w.kind in ('talk_reply', 'talk_mention') then 'talk-' || (w.item->>'thread') end,
                                    w.kind) || '@' || left(md5(s.endpoint), 12) as last_key
          from fresh w
          join public.push_subscriptions s on s.account = p_account and w.at > s.made_at),
    unsent as (
        -- push.sql's take kept a key for the account, not the device.
        select p.* from pairs p
         where not exists (select 1 from public.push_sent x where x.account = p_account and x.key in (p.key, p.sent_key))),
    held as (
        select u.*, l.at + interval '3 minutes' as until
          from unsent u left join public.push_sent l on l.account = p_account and l.key = u.last_key),
    going as (
        select h.* from held h where h.until is null or h.until <= now()),
    kept as (
        insert into public.push_sent (account, key)
        select p_account, g.sent_key from going g
        on conflict (account, key) do nothing
        returning push_sent.key),
    stamped as (
        insert into public.push_sent (account, key, at)
        select distinct p_account, g.last_key, now() from going g join kept k on k.key = g.sent_key
        on conflict (account, key) do update set at = excluded.at
        returning 1),
    later as (
        insert into public.push_marks (account, at)
        select p_account, min(h.until) from held h where h.until > now() having count(*) > 0
        returning 1)
    select coalesce(jsonb_agg(d.device), '[]'::jsonb) into devices
      from (select jsonb_build_object('endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth, 'origin', s.origin,
                       'lang', s.lang, 'made_at', s.made_at,
                       'rows', (select jsonb_agg(jsonb_build_object('kind', g.kind, 'at', g.at, 'on', g.model) || g.item
                                                 || jsonb_build_object('key', g.sent_key, 'last', g.last_key)
                                                 order by g.at desc)
                                  from going g join kept k on k.key = g.sent_key where g.endpoint = s.endpoint)) as device
              from public.push_subscriptions s where s.account = p_account) d
     where jsonb_typeof(d.device->'rows') = 'array';
    if jsonb_array_length(devices) = 0 then
        return null;
    end if;
    return jsonb_build_object('account', p_account, 'tries', coalesce(p_tries, 0), 'devices', devices);
end;
$$;
$fn$;
    revoke all on function public.push_collect(uuid, integer) from public, anon, authenticated, service_role;
end;
$do$;

-- ---------------------------------------------------------------------------
-- The site's owner (/admin › Talk, api/_console_talk.js).

-- What the owner moderates, in [p_tests]'s pool: the open reports with
-- their posts, the newest 200 threads (hidden and removed ones too), and
-- who is banned.
create or replace function public.talk_admin(p_tests boolean, p_q text default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'reports', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', r.id, 'at', r.at, 'reason', r.reason, 'note', r.note, 'post', p.id, 'thread', t.id,
                       'title', t.title, 'body', left(p.body, 600), 'hidden', p.hidden_at is not null,
                       'hidden_by', p.hidden_by, 'removed', p.removed_at is not null, 'author', p.author,
                       'handle', w.handle, 'reports', (select count(*) from public.talk_reports x
                                                         where x.post = p.id and x.resolved_at is null),
                       'banned', public.talk_banned(p.author)) order by r.at)
              from public.talk_reports r
              join public.talk_posts p on p.id = r.post
              join public.talk_threads t on t.id = p.thread
              left join public.people w on w.account = p.author
             where r.resolved_at is null and t.test = coalesce(p_tests, false)), '[]'::jsonb),
        'threads', coalesce((
            select jsonb_agg(jsonb_build_object(
                       'id', t.id, 'board', t.board, 'title', t.title, 'at', t.at, 'last_at', t.last_at,
                       'pinned', t.pinned_at is not null, 'locked', t.locked_at is not null,
                       'hidden', t.hidden_at is not null, 'removed', t.removed_at is not null,
                       'removed_by', t.removed_by, 'moved_from', t.moved_from, 'author', t.author,
                       'handle', w.handle, 'by_house', t.author = public.talk_house(),
                       'posts', (select count(*) from public.talk_posts p where p.thread = t.id and p.removed_at is null))
                       order by t.last_at desc)
              from (select * from public.talk_threads k
                     where k.test = coalesce(p_tests, false)
                       and (coalesce(btrim(p_q), '') = '' or k.title ilike '%' || btrim(p_q) || '%')
                     order by k.last_at desc limit 200) t
              left join public.people w on w.account = t.author), '[]'::jsonb),
        'bans', coalesce((
            select jsonb_agg(jsonb_build_object('account', b.account, 'handle', w.handle, 'at', b.at, 'until', b.until,
                                                'reason', b.reason) order by b.at desc)
              from public.talk_bans b
              left join public.people w on w.account = b.account
             where (b.until is null or b.until > now())
               and public.trust_is_test_account(b.account) = coalesce(p_tests, false)), '[]'::jsonb))
$$;

-- One act of the owner's: pin, unpin, lock, unlock, move (to [p_board]),
-- hide, show, remove (a thread [p_thread] or a post [p_post]), ban (an
-- account [p_account], or the author of [p_post], until [p_until] or for
-- good, its open reports resolved 'banned'), unban, dismiss (a post's open
-- reports). Each resolves the post's open reports with what was done.
-- {done, ...} or {refused: what}.
create or replace function public.talk_admin_act(p_act text, p_thread bigint default null, p_post bigint default null,
    p_account uuid default null, p_board text default null, p_until timestamptz default null, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    t public.talk_threads;
    p public.talk_posts;
    who uuid;
begin
    if p_post is not null then
        select * into p from public.talk_posts k where k.id = p_post;
        if not found then
            return jsonb_build_object('refused', 'no_post');
        end if;
    end if;
    if p_thread is not null then
        select * into t from public.talk_threads k where k.id = p_thread;
        if not found then
            return jsonb_build_object('refused', 'no_thread');
        end if;
    end if;
    if p_act in ('pin', 'unpin', 'lock', 'unlock', 'move') and p_thread is null then
        return jsonb_build_object('refused', 'no_thread');
    end if;
    if p_act = 'pin' then
        update public.talk_threads set pinned_at = coalesce(pinned_at, now()) where id = t.id;
    elsif p_act = 'unpin' then
        update public.talk_threads set pinned_at = null where id = t.id;
    elsif p_act = 'lock' then
        update public.talk_threads set locked_at = coalesce(locked_at, now()) where id = t.id;
    elsif p_act = 'unlock' then
        update public.talk_threads set locked_at = null where id = t.id;
    elsif p_act = 'move' then
        if p_board is null or p_board not in ('show', 'help', 'ideas', 'challenges', 'news') then
            return jsonb_build_object('refused', 'board');
        end if;
        if p_board <> t.board then
            update public.talk_threads set moved_from = board, board = p_board where id = t.id;
        end if;
    elsif p_act in ('hide', 'show', 'remove') and p_post is not null then
        if p_act = 'hide' then
            update public.talk_posts set hidden_at = coalesce(hidden_at, now()), hidden_by = 'admin' where id = p.id;
            update public.talk_reports set resolved_at = now(), resolution = 'hidden' where post = p.id and resolved_at is null;
        elsif p_act = 'show' then
            update public.talk_posts set hidden_at = null, hidden_by = null where id = p.id;
            update public.talk_reports set resolved_at = now(), resolution = 'dismissed' where post = p.id and resolved_at is null;
        else
            update public.talk_posts set removed_at = coalesce(removed_at, now()), removed_by = coalesce(removed_by, 'admin')
             where id = p.id;
            update public.talk_reports set resolved_at = now(), resolution = 'removed' where post = p.id and resolved_at is null;
            if p.first then
                update public.talk_threads set removed_at = coalesce(removed_at, now()), removed_by = coalesce(removed_by, 'admin')
                 where id = p.thread;
            end if;
        end if;
    elsif p_act in ('hide', 'show', 'remove') and p_thread is not null then
        if p_act = 'hide' then
            update public.talk_threads set hidden_at = coalesce(hidden_at, now()) where id = t.id;
        elsif p_act = 'show' then
            update public.talk_threads set hidden_at = null where id = t.id;
        else
            update public.talk_threads set removed_at = coalesce(removed_at, now()), removed_by = coalesce(removed_by, 'admin')
             where id = t.id;
        end if;
        update public.talk_reports set resolved_at = now(), resolution = case p_act when 'show' then 'dismissed'
                                                                                    when 'hide' then 'hidden' else 'removed' end
         where resolved_at is null and post in (select k.id from public.talk_posts k where k.thread = t.id);
    elsif p_act = 'ban' then
        who := coalesce(p_account, p.author);
        if who is null or who = public.talk_house() then
            return jsonb_build_object('refused', 'no_account');
        end if;
        if p_until is not null and p_until <= now() then
            return jsonb_build_object('refused', 'until');
        end if;
        insert into public.talk_bans (account, at, until, reason) values (who, now(), p_until, left(p_reason, 200))
        on conflict on constraint talk_bans_pkey do update set at = excluded.at, until = excluded.until, reason = excluded.reason;
        update public.talk_reports set resolved_at = now(), resolution = 'banned'
         where resolved_at is null and post in (select k.id from public.talk_posts k where k.author = who);
        return jsonb_build_object('done', p_act, 'account', who, 'until', p_until);
    elsif p_act = 'unban' then
        who := coalesce(p_account, p.author);
        delete from public.talk_bans b where b.account = who;
        return jsonb_build_object('done', p_act, 'account', who);
    elsif p_act = 'dismiss' and p_post is not null then
        update public.talk_reports set resolved_at = now(), resolution = 'dismissed' where post = p.id and resolved_at is null;
    else
        return jsonb_build_object('refused', 'act');
    end if;
    return jsonb_build_object('done', p_act, 'thread', coalesce(p_thread, p.thread), 'post', p_post,
        'photos', case when p_act <> 'remove' then '[]'::jsonb
                       else coalesce((select jsonb_agg(k.photo) from public.talk_posts k
                                       where k.photo is not null
                                         and (k.id = p_post or (p_post is null and k.thread = p_thread)
                                              or (p_post is not null and p.first and k.thread = p.thread))), '[]'::jsonb) end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: the server's alone.

revoke all on function public.talk_house() from public, anon, authenticated;
grant execute on function public.talk_house() to service_role;
revoke all on function public.talk_banned(uuid) from public, anon, authenticated;
grant execute on function public.talk_banned(uuid) to service_role;
revoke all on function public.talk_trouble(uuid) from public, anon, authenticated;
grant execute on function public.talk_trouble(uuid) to service_role;
revoke all on function public.talk_shown(uuid) from public, anon, authenticated;
grant execute on function public.talk_shown(uuid) to service_role;
revoke all on function public.talk_standing(uuid, bigint, bigint) from public, anon, authenticated;
grant execute on function public.talk_standing(uuid, bigint, bigint) to service_role;
revoke all on function public.talk_post_shown(public.talk_posts, public.talk_threads, uuid) from public, anon, authenticated;
grant execute on function public.talk_post_shown(public.talk_posts, public.talk_threads, uuid) to service_role;
revoke all on function public.talk_thread_shown(public.talk_threads, uuid, boolean) from public, anon, authenticated;
grant execute on function public.talk_thread_shown(public.talk_threads, uuid, boolean) to service_role;
revoke all on function public.talk_post_as(public.talk_posts, public.talk_threads, uuid) from public, anon, authenticated;
grant execute on function public.talk_post_as(public.talk_posts, public.talk_threads, uuid) to service_role;
revoke all on function public.talk_thread_as(public.talk_threads, uuid) from public, anon, authenticated;
grant execute on function public.talk_thread_as(public.talk_threads, uuid) to service_role;
revoke all on function public.talk_query(text) from public, anon, authenticated;
grant execute on function public.talk_query(text) to service_role;
revoke all on function public.talk_threads_of(text, boolean, uuid, timestamptz, integer, text) from public, anon, authenticated;
grant execute on function public.talk_threads_of(text, boolean, uuid, timestamptz, integer, text) to service_role;
revoke all on function public.talk_board_counts(boolean) from public, anon, authenticated;
grant execute on function public.talk_board_counts(boolean) to service_role;
revoke all on function public.talk_thread_page(bigint, boolean, uuid) from public, anon, authenticated;
grant execute on function public.talk_thread_page(bigint, boolean, uuid) to service_role;
revoke all on function public.talk_talking(boolean, uuid, integer) from public, anon, authenticated;
grant execute on function public.talk_talking(boolean, uuid, integer) to service_role;
revoke all on function public.talk_photo_shown(text) from public, anon, authenticated;
grant execute on function public.talk_photo_shown(text) to service_role;
revoke all on function public.talk_photos_of(uuid) from public, anon, authenticated;
grant execute on function public.talk_photos_of(uuid) to service_role;
revoke all on function public.talk_model_thread(text, boolean) from public, anon, authenticated;
grant execute on function public.talk_model_thread(text, boolean) to service_role;
revoke all on function public.talk_words_ok(text, integer) from public, anon, authenticated;
grant execute on function public.talk_words_ok(text, integer) to service_role;
revoke all on function public.talk_may(uuid, text) from public, anon, authenticated;
grant execute on function public.talk_may(uuid, text) to service_role;
revoke all on function public.talk_again(uuid, text) from public, anon, authenticated;
grant execute on function public.talk_again(uuid, text) to service_role;
revoke all on function public.talk_push(uuid[]) from public, anon, authenticated, service_role;
revoke all on function public.talk_start(uuid, text, text, text, text, jsonb, text, bigint) from public, anon, authenticated;
grant execute on function public.talk_start(uuid, text, text, text, text, jsonb, text, bigint) to service_role;
revoke all on function public.talk_reply(uuid, bigint, text, bigint, jsonb) from public, anon, authenticated;
grant execute on function public.talk_reply(uuid, bigint, text, bigint, jsonb) to service_role;
revoke all on function public.talk_change(uuid, bigint, text, text) from public, anon, authenticated;
grant execute on function public.talk_change(uuid, bigint, text, text) to service_role;
revoke all on function public.talk_follow(uuid, bigint, boolean) from public, anon, authenticated;
grant execute on function public.talk_follow(uuid, bigint, boolean) to service_role;
revoke all on function public.talk_read(uuid, bigint) from public, anon, authenticated;
grant execute on function public.talk_read(uuid, bigint) to service_role;
revoke all on function public.talk_mention(uuid, bigint, text[]) from public, anon, authenticated;
grant execute on function public.talk_mention(uuid, bigint, text[]) to service_role;
revoke all on function public.talk_mentions_of(bigint[]) from public, anon, authenticated;
grant execute on function public.talk_mentions_of(bigint[]) to service_role;
revoke all on function public.talk_report(uuid, text, bigint, text, text) from public, anon, authenticated;
grant execute on function public.talk_report(uuid, text, bigint, text, text) to service_role;
revoke all on function public.talk_ensure(boolean) from public, anon, authenticated;
grant execute on function public.talk_ensure(boolean) to service_role;
revoke all on function public.talk_seed(text, text, text, text, boolean) from public, anon, authenticated;
grant execute on function public.talk_seed(text, text, text, text, boolean) to service_role;
revoke all on function public.talk_notice_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.talk_notice_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.notification_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.notification_rows(uuid, timestamptz, timestamptz) to service_role;
revoke all on function public.talk_push_on_post() from public, anon, authenticated, service_role;
revoke all on function public.talk_push_on_mention() from public, anon, authenticated, service_role;
revoke all on function public.talk_admin(boolean, text) from public, anon, authenticated;
grant execute on function public.talk_admin(boolean, text) to service_role;
revoke all on function public.talk_admin_act(text, bigint, bigint, uuid, text, timestamptz, text) from public, anon, authenticated;
grant execute on function public.talk_admin_act(text, bigint, bigint, uuid, text, timestamptz, text) to service_role;
