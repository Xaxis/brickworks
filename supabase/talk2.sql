-- Talk, round two: getting around, what is new, answers and views,
-- 2026-11-27 (unit talk2; docs/SOCIAL.md section 10, api/_talk.js,
-- web/talk.js).
--
-- The owner, 2026-11-27: Talk "doesnt have search or pagination or
-- anything and isnt elegant". A forum somebody comes back to every day
-- shows them at a glance what is new since they were last here, how big
-- each thread is, where they are in it and how to get anywhere in it. This
-- file adds what the pages need for that, beside talk.sql's own functions,
-- none of which it replaces:
--
--   talk2_list    a board's threads (or every board's) a numbered page at a
--                 time, sorted by latest talk, newest threads, the most
--                 replies (this week, month or year, or ever), only those
--                 nobody has answered, or (signed in) only those with
--                 something new for the reader; a search's threads each
--                 with the post that says the words; how many in all.
--   talk2_page    a thread a numbered page of posts at a time, each post
--                 its number in the thread; the page a post is on found
--                 from the post; its people (who posts most, how many
--                 people), its first and last post, its answer, and for a
--                 signed-in reader where they read up to and the first post
--                 after it.
--   talk_visit    a signed-in reader looked at Talk: when they were here
--                 before this visit (an hour apart is a new visit), which
--                 is what "new since you were here" counts from.
--   talk_read_to  a reader read a thread up to a post (the last of the
--                 page they saw), never back.
--   talk_view     a thread was opened by a person (a key the server makes
--                 from them each day, never who they are): counted once a
--                 day each.
--   talk_answer   a Help thread's starter marks the reply that answered
--                 them, or unmarks it; shown under the question.
--
--   talk_threads.views        how many times people opened it (talk_view)
--   talk_threads.answer       the reply its starter marked as the answer
--   talk_threads.answered_at  when they marked it (kept when the answer's
--                             post is deleted with its account and the
--                             answer goes null, so no pairing is checked:
--                             answered is "answer is not null")
--   talk_views                who opened which thread on which day, as
--                             the server's key for them (a hash of the
--                             day, the address and the browser, or of the
--                             day and the account): to count each once a
--                             day; two days kept
--   talk_visits               a signed-in reader's last time in Talk and
--                             the one before
--
-- Talk's rules hold: what is read goes through talk_thread_shown and
-- talk_post_shown (removed, hidden, banned, blocked never shown), the
-- pools stay apart, an answer is a reply its reader may see.
--
-- Only additions, applied after talk.sql (and talk_asks.sql, set_asks.sql:
-- their columns are on the rows these read): three nullable or defaulted
-- columns, two tables, an index, new functions. No existing row is changed,
-- nothing dropped or renamed, no function replaced. Who may touch it: the
-- server, through the functions, each security definer and granted to the
-- service role alone; the tables row-secured and closed to every key.
-- Until it is applied the pages say what talk.sql alone lets them (one
-- page of threads, a thread whole) and the reader's marks wait.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/talk2.sql --table=talk_threads
--
-- Dry run, made-up accounts in a rolled-back transaction, hostile callers
-- tried (anon, signed in, another account, somebody blocked):
--
--   ... node tools/apply_sql.mjs supabase/talk2.sql --dry --try=tools/talk2_try.sql --table=talk_threads

-- ---------------------------------------------------------------------------
-- The columns and tables.

alter table public.talk_threads
    add column if not exists views integer not null default 0,
    add column if not exists answer bigint references public.talk_posts (id) on delete set null,
    add column if not exists answered_at timestamptz;
do $$
begin
    if not exists (select 1 from pg_constraint
                    where conname = 'talk_threads_views_counted' and conrelid = 'public.talk_threads'::regclass) then
        alter table public.talk_threads
            add constraint talk_threads_views_counted check (views >= 0);
    end if;
end
$$;
-- Newest threads first, a sort of its own.
create index if not exists talk_threads_new on public.talk_threads (test, at desc) where removed_at is null;

create table if not exists public.talk_views (
    thread  bigint not null references public.talk_threads (id) on delete cascade,
    viewer  text not null check (viewer ~ '^[0-9a-f]{32}$'),
    day     date not null default ((now() at time zone 'utc')::date),
    primary key (thread, viewer, day)
);

create table if not exists public.talk_visits (
    account    uuid primary key references auth.users (id) on delete cascade,
    seen_at    timestamptz not null default now(),
    before_at  timestamptz
);

alter table public.talk_views enable row level security;
alter table public.talk_visits enable row level security;
revoke all on public.talk_views from public, anon, authenticated, service_role;
revoke all on public.talk_visits from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Reading.

-- Where [viewer] read thread [t] up to: their read mark, else when they
-- followed it (starting it follows it), else null (never opened).
create or replace function public.talk2_mark(t public.talk_threads, viewer uuid)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
    select case when viewer is null then null else coalesce(
        (select r.at from public.talk_reads r where r.account = viewer and r.thread = t.id),
        (select f.at from public.talk_follows f where f.account = viewer and f.thread = t.id)) end
$$;

-- A thread as a list of round two gets it: talk_thread_as's, and its views,
-- whether its answer is marked (and shown), the links of its first post
-- (the page draws the model or set a thread is about from them), and for
-- a signed-in [viewer] (read before [seen], their visit before this one):
-- read_at, new_posts (posts by others after it), first_new (the first of
-- them) and fresh (a thread begun since [seen] they never opened).
create or replace function public.talk2_item(t public.talk_threads, viewer uuid, seen timestamptz default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with m as (select public.talk2_mark(t, viewer) as mark)
    select public.talk_thread_as(t, viewer) || jsonb_build_object(
        'views', t.views,
        'answered', t.answer is not null and exists (select 1 from public.talk_posts p where p.id = t.answer and p.thread = t.id
                                                       and public.talk_post_shown(p, t, viewer)),
        'links', (select coalesce(jsonb_agg(x.u), '[]'::jsonb)
                    from (select g[1] as u
                            from public.talk_posts p, regexp_matches(p.body, '(https?://[^[:space:]<>"]+)', 'g') as g
                           where p.thread = t.id and p.first and public.talk_post_shown(p, t, viewer) limit 6) x))
      || case when viewer is null then '{}'::jsonb else jsonb_build_object(
        'read_at', m.mark,
        'new_posts', case when m.mark is null then 0 else
                         (select count(*) from public.talk_posts p where p.thread = t.id and p.at > m.mark and p.author <> viewer
                             and public.talk_post_shown(p, t, viewer)) end,
        'first_new', case when m.mark is null then null else
                         (select p.id from public.talk_posts p where p.thread = t.id and p.at > m.mark and p.author <> viewer
                             and public.talk_post_shown(p, t, viewer) order by p.at, p.id limit 1) end,
        'fresh', m.mark is null and t.author <> viewer and t.at > coalesce(seen, now() - interval '2 days')) end
      from m
$$;

-- The threads of [p_board] (null: every board) in [p_tests]'s pool as
-- [viewer] may see them, page [p_page] of [p_per] (at most 50), sorted by
-- [p_sort]:
--   latest      newest talk first, the pinned first (a search: those whose
--               title says it first)
--   new         newest threads first
--   top         the most replies first, then the most views, begun in
--               [p_in] (week, month, year; else ever)
--   unanswered  only those nobody has replied to, newest first
--   unread      (signed in) only those with posts after the reader's mark,
--               or begun since their last visit and never opened
-- [p_q] searches titles and shown posts (talk_query); each thread then
-- carries [hit], the first shown post that says it. Never a thread of
-- somebody [viewer] blocked. {threads, total, page, pages, per, sort}.
create or replace function public.talk2_list(p_board text, p_tests boolean, viewer uuid default null,
    p_sort text default 'latest', p_page integer default 1, p_per integer default 30, p_q text default null,
    p_in text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    per integer := greatest(1, least(coalesce(p_per, 30), 50));
    asked integer := greatest(1, least(coalesce(p_page, 1), 100000));
    q tsquery := public.talk_query(p_q);
    sort text := case when p_sort in ('latest', 'new', 'top', 'unanswered', 'unread') then p_sort else 'latest' end;
    since timestamptz := case when p_sort = 'top' and p_in = 'week' then now() - interval '7 days'
                              when p_sort = 'top' and p_in = 'month' then now() - interval '30 days'
                              when p_sort = 'top' and p_in = 'year' then now() - interval '365 days' end;
    seen timestamptz;
    total integer;
    listed jsonb;
begin
    if p_board is not null and p_board not in ('show', 'help', 'ideas', 'challenges', 'news') then
        return null;
    end if;
    if sort = 'unread' and viewer is null then
        return jsonb_build_object('threads', '[]'::jsonb, 'total', 0, 'page', 1, 'pages', 0, 'per', per, 'sort', sort);
    end if;
    if viewer is not null then
        seen := coalesce((select v.before_at from public.talk_visits v where v.account = viewer), now() - interval '2 days');
    end if;
    with base as (
        select t as r, t.id, t.at, t.last_at, t.views, t.pinned_at is not null as pinned,
               (q is not null and to_tsvector('simple'::regconfig, t.title) @@ q) as in_title,
               case when sort = 'top' then
                   (select count(*) from public.talk_posts p where p.thread = t.id and not p.first
                       and public.talk_post_shown(p, t, viewer)) end as replies
          from public.talk_threads t
         where (p_board is null or t.board = p_board)
           and public.talk_thread_shown(t, viewer, p_tests)
           and (viewer is null or not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = t.author))
           and (since is null or t.at >= since)
           and (q is null or to_tsvector('simple'::regconfig, t.title) @@ q
                or exists (select 1 from public.talk_posts p where p.thread = t.id
                            and to_tsvector('simple'::regconfig, p.body) @@ q and public.talk_post_shown(p, t, viewer)))
           and (sort <> 'unanswered' or not exists (select 1 from public.talk_posts p where p.thread = t.id and not p.first
                                                      and public.talk_post_shown(p, t, viewer)))
           and (sort <> 'unread' or (t.author <> viewer and (
                    exists (select 1 from public.talk_posts p where p.thread = t.id and p.author <> viewer
                             and p.at > public.talk2_mark(t, viewer) and public.talk_post_shown(p, t, viewer))
                    or (public.talk2_mark(t, viewer) is null and t.at > seen))))
    ), ordered as (
        select b.*, row_number() over (order by
                   case when sort = 'latest' and q is null and b.pinned then 0 else 1 end,
                   case when sort = 'latest' and b.in_title then 0 else 1 end,
                   case when sort = 'top' then b.replies end desc nulls last,
                   case when sort = 'top' then b.views end desc nulls last,
                   case when sort in ('new', 'unanswered') then b.at end desc nulls last,
                   b.last_at desc, b.id desc) as n,
               count(*) over () as all_of
          from base b
    )
    -- How many in all, and the asked page's drawn: only its rows are made
    -- into items (the CTE, read twice, is made once).
    select (select coalesce(max(a.all_of), 0)::integer from ordered a),
           (select coalesce(jsonb_agg(public.talk2_item(o.r, viewer, seen)
               || case when q is null then '{}'::jsonb else jsonb_build_object('hit', (
                      select jsonb_build_object('id', p.id, 'first', p.first, 'body', left(p.body, 1500))
                        from public.talk_posts p
                       where p.thread = o.id and to_tsvector('simple'::regconfig, p.body) @@ q
                         and public.talk_post_shown(p, o.r, viewer)
                       order by p.at, p.id limit 1)) end
               order by o.n), '[]'::jsonb)
              from ordered o where o.n > (asked - 1) * per and o.n <= asked * per)
      into total, listed;
    return jsonb_build_object('threads', listed, 'total', total, 'page', asked, 'per', per, 'sort', sort,
        'pages', greatest(1, ceil(total::numeric / per)::integer), 'searched', q is not null,
        'seen', seen);
end;
$$;

-- Thread [p_thread] for [viewer], page [p_page] of [p_per] posts (5 to 100),
-- or the page post [p_post] is on: {thread, posts (each with n, its number
-- among the posts shown), page, pages, per, total, first, last, answer
-- (with its n and page), people (who posts most, at most 12, each with how
-- many), people_n, read_at and first_new ({id, n, page}) for a signed-in
-- reader, blocked_some, you}, or null when it is not there for them.
create or replace function public.talk2_page(p_thread bigint, p_tests boolean, viewer uuid default null,
    p_page integer default 1, p_per integer default 20, p_post bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    t public.talk_threads;
    per integer := greatest(5, least(coalesce(p_per, 20), 100));
    total integer;
    pages integer;
    at_page integer;
    mark timestamptz;
    found_n integer;
    listed jsonb;
    numbered jsonb;
begin
    select * into t from public.talk_threads k where k.id = p_thread;
    if not found or not public.talk_thread_shown(t, viewer, p_tests) then
        return null;
    end if;
    mark := public.talk2_mark(t, viewer);
    -- Every post shown to the reader, numbered, oldest first: [{id, n, at,
    -- author}] once, read by what follows.
    select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'n', k.n, 'at', k.at, 'author', k.author) order by k.n), '[]'::jsonb),
           count(*)::integer
      into numbered, total
      from (select p.id, p.at, p.author, row_number() over (order by p.at, p.id) as n
              from public.talk_posts p where p.thread = t.id and public.talk_post_shown(p, t, viewer)) k;
    pages := greatest(1, ceil(total::numeric / per)::integer);
    if p_post is not null then
        select (e->>'n')::integer into found_n from jsonb_array_elements(numbered) e where (e->>'id')::bigint = p_post;
    end if;
    at_page := case when found_n is not null then ceil(found_n::numeric / per)::integer
                    else greatest(1, least(coalesce(p_page, 1), pages)) end;
    select coalesce(jsonb_agg(public.talk_post_as(p, t, viewer) || jsonb_build_object('n', (e->>'n')::integer)
                              order by (e->>'n')::integer), '[]'::jsonb)
      into listed
      from jsonb_array_elements(numbered) e
      join public.talk_posts p on p.id = (e->>'id')::bigint
     where (e->>'n')::integer > (at_page - 1) * per and (e->>'n')::integer <= at_page * per;
    return jsonb_build_object(
        'thread', public.talk2_item(t, viewer),
        'posts', listed, 'page', at_page, 'pages', pages, 'per', per, 'total', total,
        'first', (select public.talk_post_as(p, t, viewer) || jsonb_build_object('n', 1)
                    from public.talk_posts p where p.thread = t.id and p.first and public.talk_post_shown(p, t, viewer)),
        'last', (select jsonb_build_object('id', (e->>'id')::bigint, 'n', (e->>'n')::integer, 'at', e->'at',
                                           'by', public.feed_who((e->>'author')::uuid),
                                           'page', ceil((e->>'n')::numeric / per)::integer)
                   from jsonb_array_elements(numbered) e order by (e->>'n')::integer desc limit 1),
        'answer', (select public.talk_post_as(p, t, viewer) || jsonb_build_object('n', (e->>'n')::integer,
                                                                                 'page', ceil((e->>'n')::numeric / per)::integer)
                     from jsonb_array_elements(numbered) e join public.talk_posts p on p.id = (e->>'id')::bigint
                    where p.id = t.answer and not p.first),
        'people', (select coalesce(jsonb_agg(w.who || jsonb_build_object('posts', w.n) order by w.n desc, w.first_at), '[]'::jsonb)
                     from (select public.feed_who((e->>'author')::uuid) as who, count(*) as n, min((e->>'n')::integer) as first_at
                             from jsonb_array_elements(numbered) e group by e->>'author'
                            order by count(*) desc, min((e->>'n')::integer) limit 12) w
                    where w.who is not null),
        'people_n', (select count(distinct e->>'author') from jsonb_array_elements(numbered) e),
        'read_at', mark,
        'first_new', case when viewer is null or mark is null then null else
            (select jsonb_build_object('id', (e->>'id')::bigint, 'n', (e->>'n')::integer,
                                       'page', ceil((e->>'n')::numeric / per)::integer)
               from jsonb_array_elements(numbered) e
              where (e->>'at')::timestamptz > mark and (e->>'author')::uuid <> viewer
              order by (e->>'n')::integer limit 1) end,
        'blocked_some', viewer is not null and exists (
            select 1 from public.talk_posts p join public.blocks b on b.blocker = viewer and b.blocked = p.author
             where p.thread = t.id and p.removed_at is null),
        'you', jsonb_build_object('trouble', public.talk_trouble(viewer),
                                  'standing', public.talk_standing(viewer, t.id),
                                  'pool', viewer is null or public.trust_is_test_account(viewer) = t.test,
                                  'starter', viewer is not null and viewer = t.author,
                                  'may_answer', viewer is not null and t.board = 'help'
                                                and (viewer = t.author or viewer = public.talk_house())));
end;
$$;

-- ---------------------------------------------------------------------------
-- Writing.

-- [account] looked at Talk now: {before_at}, when they were here the visit
-- before this one (a look an hour or more after the last starts a new
-- visit), null the first time.
create or replace function public.talk_visit(account uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    was timestamptz;
begin
    if account is null or not exists (select 1 from auth.users u where u.id = talk_visit.account) then
        return jsonb_build_object('before_at', null);
    end if;
    insert into public.talk_visits as v (account, seen_at, before_at) values (talk_visit.account, now(), null)
    on conflict on constraint talk_visits_pkey do update
        set before_at = case when v.seen_at < now() - interval '1 hour' then v.seen_at else v.before_at end,
            seen_at = now()
    returning v.before_at into was;
    return jsonb_build_object('before_at', was);
end;
$$;

-- [account] read thread [p_thread] up to post [p_post] (the last of the
-- page they saw; null: up to now): its mark moved there, never back. {read}.
create or replace function public.talk_read_to(account uuid, p_thread bigint, p_post bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    t public.talk_threads;
    upto timestamptz;
begin
    select * into t from public.talk_threads k where k.id = p_thread;
    if account is null or not found or not public.talk_thread_shown(t, account, t.test) then
        return jsonb_build_object('read', false);
    end if;
    upto := case when p_post is null then now()
                 else (select p.at from public.talk_posts p where p.id = p_post and p.thread = t.id) end;
    if upto is null then
        return jsonb_build_object('read', false);
    end if;
    insert into public.talk_reads (account, thread, at) values (account, t.id, least(upto, now()))
    on conflict on constraint talk_reads_pkey do update set at = greatest(public.talk_reads.at, excluded.at);
    return jsonb_build_object('read', true);
end;
$$;

-- Thread [p_thread] opened by [p_viewer] (the server's key for a person
-- today, 32 hex): counted once a day each. {views, counted}, or null for a
-- thread that is not there or a key that is not one.
create or replace function public.talk_view(p_thread bigint, p_viewer text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    made integer;
    now_views integer;
begin
    if p_viewer is null or p_viewer !~ '^[0-9a-f]{32}$'
       or not exists (select 1 from public.talk_threads t where t.id = p_thread and t.removed_at is null) then
        return null;
    end if;
    insert into public.talk_views (thread, viewer) values (p_thread, p_viewer) on conflict do nothing;
    get diagnostics made = row_count;
    if made > 0 then
        update public.talk_threads set views = views + 1 where id = p_thread returning views into now_views;
        delete from public.talk_views v where v.thread = p_thread and v.day < (now() at time zone 'utc')::date - 1;
    else
        select t.views into now_views from public.talk_threads t where t.id = p_thread;
    end if;
    return jsonb_build_object('views', now_views, 'counted', made > 0);
end;
$$;

-- [account], who started Help thread [p_thread] (or the house), marks reply
-- [p_post] the answer, or none ([p_post] null). {answer} or {refused}:
-- talk_trouble's, no_thread, not_help, not_starter, no_post, limit.
create or replace function public.talk_answer(account uuid, p_thread bigint, p_post bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.talk_trouble(account);
    t public.talk_threads;
begin
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    select * into t from public.talk_threads k where k.id = p_thread;
    if not found or not public.talk_thread_shown(t, account, public.trust_is_test_account(account)) then
        return jsonb_build_object('refused', 'no_thread');
    end if;
    if t.board <> 'help' then
        return jsonb_build_object('refused', 'not_help');
    end if;
    if account <> t.author and account is distinct from public.talk_house() then
        return jsonb_build_object('refused', 'not_starter');
    end if;
    if p_post is not null and not exists (select 1 from public.talk_posts p where p.id = p_post and p.thread = t.id
                                              and not p.first and public.talk_post_shown(p, t, account)) then
        return jsonb_build_object('refused', 'no_post');
    end if;
    if not public.may_act(account::text, 'talk_answer', 30, 100) then
        return jsonb_build_object('refused', 'limit');
    end if;
    update public.talk_threads set answer = p_post, answered_at = case when p_post is null then null else now() end
     where id = t.id;
    return jsonb_build_object('answer', p_post);
end;
$$;

-- ---------------------------------------------------------------------------
-- Who may call them: the server alone.

revoke all on function public.talk2_mark(public.talk_threads, uuid) from public, anon, authenticated;
revoke all on function public.talk2_item(public.talk_threads, uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.talk2_list(text, boolean, uuid, text, integer, integer, text, text) from public, anon, authenticated;
revoke all on function public.talk2_page(bigint, boolean, uuid, integer, integer, bigint) from public, anon, authenticated;
revoke all on function public.talk_visit(uuid) from public, anon, authenticated;
revoke all on function public.talk_read_to(uuid, bigint, bigint) from public, anon, authenticated;
revoke all on function public.talk_view(bigint, text) from public, anon, authenticated;
revoke all on function public.talk_answer(uuid, bigint, bigint) from public, anon, authenticated;
grant execute on function public.talk2_mark(public.talk_threads, uuid) to service_role;
grant execute on function public.talk2_item(public.talk_threads, uuid, timestamptz) to service_role;
grant execute on function public.talk2_list(text, boolean, uuid, text, integer, integer, text, text) to service_role;
grant execute on function public.talk2_page(bigint, boolean, uuid, integer, integer, bigint) to service_role;
grant execute on function public.talk_visit(uuid) to service_role;
grant execute on function public.talk_read_to(uuid, bigint, bigint) to service_role;
grant execute on function public.talk_view(bigint, text) to service_role;
grant execute on function public.talk_answer(uuid, bigint, bigint) to service_role;
