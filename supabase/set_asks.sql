-- Ask the builders on a set's page (hubask, 2026-11-24; docs/SOCIAL.md
-- section 12, api/_asks.js, web/set-page.js). Applied after talk_asks.sql,
-- alt_builds.sql and set_versions.sql.
--
-- Somebody building a LEGO® set asks about a step of it today in a Flickr
-- discussion or a forum, away from the set. A set's page (/library/set/N)
-- holds the set and every version people published of it from Make your
-- own version (set_versions.sql), so the question is asked there: one of
-- askhelp's asks (talk_asks.sql), a Help thread in Talk, about the set at a
-- step, its page drawing that step in 3D, its answers on a part. And the
-- people who built a version of the set hear of it, once each, as a
-- mention: the kind a person chooses to hear of somebody asking them
-- (notification_prefs.sql), here, pushed and emailed as they chose.
--
--   talk_threads.ask_set       the set asked about (its number, as
--                              model_alt_sets has it), null for no set
--   talk_threads.ask_library   LDraw's model of it (the library's id, as
--                              the set's page opens it in the studio)
--   talk_threads.ask_drawn     the version whose steps draw the asked step:
--                              one published as LDraw's model is
--                              (modelled_by.changed false), whose steps the
--                              app carried in its file (api/_parts.js
--                              stepParts) as its step player plays them;
--                              null for none (the thread draws LDraw's file,
--                              whole where it cannot say the step), or once
--                              that version is gone
--   ask_version, ask_step      as talk_asks.sql has them: the drawn
--                              version's number (1 with none) and the step
--   talk_ask_heard             who was told of a set's ask: a builder of one
--                              of its versions, once a thread
--
-- Who is told (talk_set_ask): the owner of each version the set's page
-- lists (set_versions: the gallery shows it, in the asker's pool), the
-- newest 24, each once; not the asker, nobody under 13 or kept private
-- (trust.sql's trust_may_go_public, shown_publicly), nobody banned from
-- Talk, and nobody either of the two blocked. What they are told is a row
-- of talk_notice_rows, kind talk_mention with its [ask], so
-- notification_kind, notification_group, push_collect and
-- claim_comment_digest take it as they take a mention: a person who turned
-- mentions off here, for push or for email hears nothing there, and nothing
-- is mailed that their settings do not mail.
--
-- Talk's rules hold for the thread, being talk_start's (signed in, 13 or
-- over, not barred or banned, its limits and pools), and for every answer,
-- being talk_reply's.
--
-- New: the three columns, a check and an index, the table, talk_set_ask
-- and talk_set_asks (a set's asks for its page, newest first, each saying
-- whether a builder other than its asker answered it). Replaced, from
-- production's own bodies (read 2026-11-24 with pg_get_functiondef, the
-- same as talk.sql's and talk_asks.sql's): talk_ask_as (a set's ask said
-- too), talk_pin_reply (an answer on a part in a set's ask too) and
-- talk_notice_rows (the told builders' rows). Every other line of each is
-- as it was. Nothing is dropped or renamed; no row is changed. Who may
-- touch it: the server alone, through the functions, each security definer
-- and granted to the service role, as talk.sql's are.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/set_asks.sql --table=talk_threads
--
-- Dry run, made-up accounts in a rolled-back transaction, hostile callers
-- tried (anon, a signed-in key, an under-13 builder, a blocked one, the
-- other pool):
--
--   ... node tools/apply_sql.mjs supabase/set_asks.sql --dry --try=tools/set_asks_try.sql --table=talk_threads

-- ---------------------------------------------------------------------------
-- The columns and the table.

alter table public.talk_threads
    add column if not exists ask_set text,
    add column if not exists ask_library text,
    add column if not exists ask_drawn text references public.shared_models (id) on delete set null;
do $$
begin
    if not exists (select 1 from pg_constraint
                    where conname = 'talk_threads_set_ask_shape' and conrelid = 'public.talk_threads'::regclass) then
        alter table public.talk_threads
            add constraint talk_threads_set_ask_shape check (
                (ask_set is null and ask_library is null and ask_drawn is null)
                or (ask_set ~ '^[a-z0-9][a-z0-9.-]{0,29}$'
                    and ask_library ~ '^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$'
                    and ask_model is null and ask_parts is null and ask_version is not null));
    end if;
end
$$;
-- A set's asks, newest first: what its page lists.
create index if not exists talk_threads_set_asks on public.talk_threads (ask_set, at desc) where ask_set is not null;

create table if not exists public.talk_ask_heard (
    thread   bigint not null references public.talk_threads (id) on delete cascade,
    account  uuid not null references auth.users (id) on delete cascade,
    at       timestamptz not null default now(),
    primary key (thread, account)
);
create index if not exists talk_ask_heard_account on public.talk_ask_heard (account, at desc);
alter table public.talk_ask_heard enable row level security;
revoke all on public.talk_ask_heard from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Writing.

-- A Help thread from [account] about set [p_set] at step [p_step] (null:
-- the whole set), LDraw's model of it [p_library], the step drawn from
-- version [p_version] of [p_drawn] (a version of the set published as
-- LDraw's model is) or, with none, from LDraw's file (version 1); titled
-- [p_title], its first post [p_said] (and [p_photo]). As talk_start answers
-- ({thread, post}), with the thread's ask and how many builders were told
-- ({heard}), or {refused}: talk_start's, set, no_version, step.
create or replace function public.talk_set_ask(account uuid, p_set text, p_library text, p_drawn text, p_version integer,
    p_step integer, p_title text, p_said text, p_photo jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    trouble text := public.talk_trouble(account);
    started jsonb;
    made bigint;
    asked public.talk_threads;
    pool boolean;
    told uuid[];
begin
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    if p_set is null or p_set !~ '^[a-z0-9][a-z0-9.-]{0,29}$'
       or p_library is null or p_library !~ '^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$' then
        return jsonb_build_object('refused', 'set');
    end if;
    if p_drawn is null then
        if coalesce(p_version, 1) <> 1 then
            return jsonb_build_object('refused', 'no_version');
        end if;
    elsif p_version is null
       or not exists (select 1 from public.model_alt_sets s join public.shared_models m on m.id = s.model
                       where s.set_number = p_set and s.role = 'own' and s.model = p_drawn and m.published and not m.barred)
       or not exists (select 1 from public.share_versions v where v.model = p_drawn and v.n = p_version) then
        return jsonb_build_object('refused', 'no_version');
    end if;
    if p_step is not null and (p_step < 1 or p_step > 200000) then
        return jsonb_build_object('refused', 'step');
    end if;
    -- talk_start's every rule: the title, the words, the same words again,
    -- the limits, the pool.
    started := public.talk_start(account, 'help', p_title, p_said, null, p_photo);
    if started ? 'refused' then
        return started;
    end if;
    made := (started -> 'thread' ->> 'id')::bigint;
    update public.talk_threads
       set ask_set = p_set, ask_library = p_library, ask_drawn = p_drawn, ask_version = coalesce(p_version, 1),
           ask_step = p_step
     where id = made
    returning * into asked;
    -- The builders of its versions, as its page lists them, each once.
    pool := public.trust_is_test_account(account);
    with built as (
        select m.owner, max(coalesce(m.listed_at, m.created_at)) as newest
          from public.model_alt_sets s
          join public.shared_models m on m.id = s.model
         where s.set_number = p_set and s.role = 'own' and m.owner is not null
           and public.gallery_shows(m, asked.test)
         group by m.owner)
    insert into public.talk_ask_heard (thread, account)
    select made, b.owner
      from (select * from built order by newest desc limit 24) b
     where b.owner <> account
       and public.trust_may_go_public(b.owner) and public.shown_publicly(b.owner)
       and public.trust_is_test_account(b.owner) = pool
       and not public.talk_banned(b.owner)
       and public.block_between(account, b.owner) is null
    on conflict do nothing;
    told := array(select h.account from public.talk_ask_heard h where h.thread = made);
    perform public.talk_push(told);
    return started || jsonb_build_object('ask', public.talk_ask_as(asked), 'heard', cardinality(told));
end;
$$;

-- A reply from [account] in [p_thread], an ask's thread, on the part
-- [p_pin] (a place the server found in the asked version's file, or in
-- LDraw's file of an asked set), as talk_reply answers ({post}, with its
-- pin), or {refused}: talk_reply's, not_ask (no ask, or its model gone),
-- pin. talk_asks.sql's, an ask about a set taken too.
create or replace function public.talk_pin_reply(account uuid, p_thread bigint, p_said text, p_pin jsonb,
    p_answers bigint default null, p_photo jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    replied jsonb;
    made bigint;
begin
    if not exists (select 1 from public.talk_threads t where t.id = p_thread
                    and (t.ask_model is not null or t.ask_set is not null)) then
        -- Talk's own refusal first, for a thread not there or not theirs to see.
        if not exists (select 1 from public.talk_threads t where t.id = p_thread and t.removed_at is null) then
            return jsonb_build_object('refused', 'no_thread');
        end if;
        return jsonb_build_object('refused', 'not_ask');
    end if;
    if p_pin is null or not public.pin_shaped(p_pin) then
        return jsonb_build_object('refused', 'pin');
    end if;
    replied := public.talk_reply(account, p_thread, p_said, p_answers, p_photo);
    if replied ? 'refused' then
        return replied;
    end if;
    made := (replied -> 'post' ->> 'id')::bigint;
    update public.talk_posts set pin = p_pin where id = made;
    return jsonb_set(replied, '{post,pin}', p_pin);
end;
$$;

-- ---------------------------------------------------------------------------
-- Reading.

-- An ask as a page gets it: {model, version, step, parts, name, has_image,
-- newest}, model null once it is gone or taken out; a set's: {set, library,
-- drawn, version, step, parts, has_image, newest}, [drawn] null once that
-- version is gone or taken out, [has_image] and [newest] its. Null for no
-- ask. talk_asks.sql's, a set's ask said too.
create or replace function public.talk_ask_as(t public.talk_threads)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select case when t.ask_version is null then null
    when t.ask_set is not null then jsonb_build_object(
        'set', t.ask_set, 'library', t.ask_library, 'drawn', d.id, 'version', t.ask_version, 'step', t.ask_step,
        'parts', '[]'::jsonb, 'has_image', coalesce(d.has_image, false),
        'newest', (select max(v.n) from public.share_versions v where v.model = d.id))
    else jsonb_build_object(
        'model', m.id, 'version', t.ask_version, 'step', t.ask_step, 'parts', coalesce(t.ask_parts, '[]'::jsonb),
        'name', m.name, 'has_image', m.has_image,
        'newest', (select max(v.n) from public.share_versions v where v.model = m.id)) end
      from (select 1) as one
      left join public.shared_models m on m.id = t.ask_model and m.published and not m.barred
      left join public.shared_models d on d.id = t.ask_drawn and d.published and not d.barred
$$;

-- Set [p_set]'s asks in [p_tests]'s pool as [viewer] (null: signed out)
-- may see them, newest first, at most 30: each talk_thread_as's, with the
-- [step] asked about and [answered]: a reply [viewer] may see by somebody
-- other than its asker. None by somebody [viewer] blocked.
create or replace function public.talk_set_asks(p_set text, p_tests boolean, viewer uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(public.talk_thread_as(t, viewer) || jsonb_build_object(
               'step', t.ask_step,
               'answered', exists (select 1 from public.talk_posts p
                                    where p.thread = t.id and not p.first and p.author <> t.author
                                      and public.talk_post_shown(p, t, viewer)))
             order by t.at desc, t.id desc), '[]'::jsonb)
      from (select * from public.talk_threads k
             where k.ask_set = lower(p_set)
               and public.talk_thread_shown(k, viewer, p_tests)
               and (viewer is null or not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = k.author))
             order by k.at desc, k.id desc
             limit 30) t
$$;

-- [viewer]'s Talk rows from after [since] up to [until], as notification_rows
-- gives its rows (no model): a post by somebody else in a thread they
-- follow, after they followed it (talk_reply); a post that names them, in a
-- thread they do not follow (talk_mention); and a question asked of the
-- builders of a set they published a version of (talk_mention, with its
-- [ask]: the set and the step), unless its post names them too. [item]
-- says the thread, its title, the post, its first words, who, and [read]
-- once they opened the thread after it. talk.sql's, the third part added.
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
    union all
    select 'talk_mention'::text, h.at, null::text,
           jsonb_build_object('thread', t.id, 'title', t.title, 'board', t.board, 'post', p.id, 'said', left(p.body, 240),
                              'by', public.feed_who(p.author), 'test', t.test,
                              'read', coalesce(r.at >= p.at, false),
                              'ask', jsonb_build_object('set', t.ask_set, 'step', t.ask_step))
      from public.talk_ask_heard h
      join public.talk_threads t on t.id = h.thread
      join public.talk_posts p on p.thread = t.id and p.first
      left join public.talk_reads r on r.account = viewer and r.thread = t.id
     where h.account = viewer and p.author <> viewer
       and t.removed_at is null and t.hidden_at is null
       and h.at > since and h.at <= until
       and public.talk_post_shown(p, t, null)
       and not exists (select 1 from public.blocks b where b.blocker = viewer and b.blocked = p.author)
       and not exists (select 1 from public.talk_mentions n where n.post = p.id and n.account = viewer)
$$;

-- ---------------------------------------------------------------------------
-- Who may call them: the server alone.

revoke all on function public.talk_set_ask(uuid, text, text, text, integer, integer, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.talk_pin_reply(uuid, bigint, text, jsonb, bigint, jsonb) from public, anon, authenticated;
revoke all on function public.talk_ask_as(public.talk_threads) from public, anon, authenticated;
revoke all on function public.talk_set_asks(text, boolean, uuid) from public, anon, authenticated;
revoke all on function public.talk_notice_rows(uuid, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.talk_set_ask(uuid, text, text, text, integer, integer, text, text, jsonb) to service_role;
grant execute on function public.talk_pin_reply(uuid, bigint, text, jsonb, bigint, jsonb) to service_role;
grant execute on function public.talk_ask_as(public.talk_threads) to service_role;
grant execute on function public.talk_set_asks(text, boolean, uuid) to service_role;
grant execute on function public.talk_notice_rows(uuid, timestamptz, timestamptz) to service_role;
