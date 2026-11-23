-- Ask the builders, from the studio, 2026-11-23 (unit askhelp; docs/PLAN.md
-- row 3, docs/SOCIAL.md section 12, api/_talk.js, src/ui/share_panel.gd).
--
-- r/LegoMocHelp is where builders ask how to build a step: a photo, some
-- words, and the answers say "the third plate from the left" in words. Here
-- the question is asked from the studio, about the step that is open there,
-- and the answer lands on the part:
--
--   An ask        a Help thread in Talk about one of its starter's shared
--                 models: the version it was asked at, the step that was
--                 open (null: the whole model), and the parts that were
--                 picked, each kept as a pin keeps its part (comment_pins.sql
--                 pin_shaped: {part, colour, at, turn, ...}), worked out by
--                 the server from that version's own file. Its page draws
--                 the model in 3D at that step with those parts lit.
--   An answer     a reply in an ask's thread may be on a part of the asked
--                 version, kept as a pin is (talk_posts.pin). The studio of
--                 the model's builder asks for its asks' answers on parts
--                 while the model is open (talk_asks_on) and lights each
--                 part; the thread's 3D numbers them on their parts.
--
-- Talk's rules hold for every post here, being Talk's own functions'
-- (talk.sql): who may write (signed in, the age question answered 13 or
-- over, not barred, not banned), how often, the pools, blocks and reports.
-- talk_ask is talk_start's thread in Help with the ask kept on it, and
-- talk_pin_reply talk_reply's post with its part, each in one transaction;
-- what is read back is through talk_thread_shown and talk_post_shown, so a
-- post hidden, removed, by somebody blocked or banned is never an answer
-- anybody is shown, the studio included.
--
--   talk_threads.ask_model    the model asked about (its starter's own,
--                             shared), null for no ask, or once the model
--                             is gone
--   talk_threads.ask_version  the version it was asked at; kept when the
--                             model goes, so the thread still says it was
--                             an ask
--   talk_threads.ask_step     the step that was open, from 1, or null for
--                             the whole model
--   talk_threads.ask_parts    the parts picked: at most 12 places, each
--                             pin_shaped, or null for none
--   talk_posts.pin            the part an answer is on: pin_shaped, only
--                             on a reply in an ask's thread
--
-- New functions, none replaced: talk_ask, talk_pin_reply, talk_asks_of
-- (the asks of some threads, for their pages), talk_pins_of (the parts of
-- some posts) and talk_asks_on (a model's asks and their answers on parts,
-- as [viewer] may see them, for the studio).
--
-- Only additions, applied after talk.sql and comment_pins.sql: five
-- nullable columns, their checks and an index, and functions. No existing
-- row is changed, nothing dropped or renamed. Who may touch it: the server,
-- through the functions, each security definer and granted to the service
-- role alone, as talk.sql's are. Until it is applied the API says asks:
-- false and the studio and the pages offer none.
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/talk_asks.sql --table=talk_threads
--
-- Dry run, made-up accounts in a rolled-back transaction, hostile callers
-- tried (anon, another account, a blocked one, a check's account in the
-- people's pool):
--
--   ... node tools/apply_sql.mjs supabase/talk_asks.sql --dry --try=tools/talk_asks_try.sql --table=talk_threads

-- ---------------------------------------------------------------------------
-- The columns.

-- The parts an ask picked: an array of at most 12 places, each as a pin
-- keeps one. False, never null, for anything else.
create or replace function public.talk_parts_shaped(parts jsonb)
returns boolean
language sql
immutable
set search_path = public
as $$
    select coalesce(case when jsonb_typeof(parts) = 'array' then
        jsonb_array_length(parts) between 1 and 12
        and octet_length(parts::text) <= 48000
        and not exists (select 1 from jsonb_array_elements(parts) one where not public.pin_shaped(one))
    end, false)
$$;

alter table public.talk_threads
    add column if not exists ask_model text references public.shared_models (id) on delete set null,
    add column if not exists ask_version integer,
    add column if not exists ask_step integer,
    add column if not exists ask_parts jsonb;
alter table public.talk_posts
    add column if not exists pin jsonb;
do $$
begin
    if not exists (select 1 from pg_constraint
                    where conname = 'talk_threads_ask_shape' and conrelid = 'public.talk_threads'::regclass) then
        alter table public.talk_threads
            add constraint talk_threads_ask_shape check (
                (ask_version is null or ask_version between 1 and 100000)
                and (ask_model is null or ask_version is not null)
                and (ask_step is null or (ask_version is not null and ask_step between 1 and 200000))
                and (ask_parts is null or (ask_version is not null and public.talk_parts_shaped(ask_parts))));
    end if;
    if not exists (select 1 from pg_constraint
                    where conname = 'talk_posts_pin_shape' and conrelid = 'public.talk_posts'::regclass) then
        alter table public.talk_posts
            add constraint talk_posts_pin_shape check (pin is null or (not first and public.pin_shaped(pin)));
    end if;
end
$$;
-- A model's asks, newest first: what the studio asks for.
create index if not exists talk_threads_asks on public.talk_threads (ask_model, at desc) where ask_model is not null;

-- ---------------------------------------------------------------------------
-- Writing.

-- A Help thread from [account] about [p_model], one of their shared models,
-- at version [p_version], step [p_step] (null: the whole model), with the
-- parts [p_parts] (places the server found in that version's file, or
-- null), titled [p_title], its first post [p_said] (and [p_photo]). As
-- talk_start answers ({thread, post}), with the thread's ask, or {refused}:
-- talk_start's, model (not theirs, not shared, taken out), no_version,
-- step, parts.
create or replace function public.talk_ask(account uuid, p_model text, p_version integer, p_step integer,
    p_parts jsonb, p_title text, p_said text, p_photo jsonb default null)
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
begin
    if trouble is not null then
        return jsonb_build_object('refused', trouble);
    end if;
    if p_model is null or not exists (select 1 from public.shared_models m where m.id = p_model and m.owner = account
                                          and m.published and not m.barred) then
        return jsonb_build_object('refused', 'model');
    end if;
    if p_version is null or not exists (select 1 from public.share_versions v where v.model = p_model and v.n = p_version) then
        return jsonb_build_object('refused', 'no_version');
    end if;
    if p_step is not null and (p_step < 1 or p_step > 200000) then
        return jsonb_build_object('refused', 'step');
    end if;
    if p_parts is not null and not public.talk_parts_shaped(p_parts) then
        return jsonb_build_object('refused', 'parts');
    end if;
    -- talk_start's every rule: the title, the words, the same words again,
    -- the limits, the pool. Its model is Show and tell's, never an ask's.
    started := public.talk_start(account, 'help', p_title, p_said, null, p_photo);
    if started ? 'refused' then
        return started;
    end if;
    made := (started -> 'thread' ->> 'id')::bigint;
    update public.talk_threads
       set ask_model = p_model, ask_version = p_version, ask_step = p_step, ask_parts = p_parts
     where id = made
    returning * into asked;
    return started || jsonb_build_object('ask', public.talk_ask_as(asked));
end;
$$;

-- A reply from [account] in [p_thread], an ask's thread, on the part
-- [p_pin] (a place the server found in the asked version's file), as
-- talk_reply answers ({post}, with its pin), or {refused}: talk_reply's,
-- not_ask (no ask, or its model gone), pin.
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
    if not exists (select 1 from public.talk_threads t where t.id = p_thread and t.ask_model is not null) then
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
-- newest}, model null once it is gone or taken out. Null for no ask.
create or replace function public.talk_ask_as(t public.talk_threads)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select case when t.ask_version is null then null else jsonb_build_object(
        'model', m.id, 'version', t.ask_version, 'step', t.ask_step, 'parts', coalesce(t.ask_parts, '[]'::jsonb),
        'name', m.name, 'has_image', m.has_image,
        'newest', (select max(v.n) from public.share_versions v where v.model = m.id)) end
      from (select 1) as one
      left join public.shared_models m on m.id = t.ask_model and m.published and not m.barred
$$;

-- The asks of threads [thread_ids]: [{thread, ask}], only those that are
-- asks. The page has the threads already, as their reader may see them.
create or replace function public.talk_asks_of(thread_ids bigint[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('thread', t.id, 'ask', public.talk_ask_as(t)) order by t.id), '[]'::jsonb)
      from public.talk_threads t
     where t.id = any((coalesce(thread_ids, '{}'::bigint[]))[1:200]) and t.ask_version is not null
$$;

-- The parts posts [post_ids] are on: [{post, pin}], only those on one. The
-- page has the posts already, as their reader may see them.
create or replace function public.talk_pins_of(post_ids bigint[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(jsonb_agg(jsonb_build_object('post', p.id, 'pin', p.pin) order by p.id), '[]'::jsonb)
      from public.talk_posts p
     where p.id = any((coalesce(post_ids, '{}'::bigint[]))[1:500]) and p.pin is not null
$$;

-- Model [p_model]'s asks in [viewer]'s pool (a check's account's are the
-- checks' threads), newest first (at most 20),
-- each with its answers on parts as [viewer] may see them (talk_post_shown:
-- never one hidden, removed, banned, by somebody [viewer] blocked or the
-- starter blocked), oldest first (at most 100 a thread):
-- [{thread, title, at, last_at, locked, ask, answers: [{id, body, at,
-- edited_at, pin, by, handle, mine, by_starter}]}]. Only for the model's
-- owner, as the studio asks: null for anybody else.
create or replace function public.talk_asks_on(p_model text, viewer uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select case when viewer is null or not exists (select 1 from public.shared_models m
                                                     where m.id = p_model and m.owner = viewer) then null
    else coalesce((
        select jsonb_agg(jsonb_build_object(
                   'thread', t.id, 'title', t.title, 'at', t.at, 'last_at', t.last_at,
                   'locked', t.locked_at is not null, 'ask', public.talk_ask_as(t),
                   'answers', coalesce((
                       select jsonb_agg(public.talk_post_as(p, t, viewer) || jsonb_build_object('pin', p.pin)
                                        order by p.at, p.id)
                         from (select * from public.talk_posts k
                                where k.thread = t.id and k.pin is not null and public.talk_post_shown(k, t, viewer)
                                order by k.at, k.id limit 100) p), '[]'::jsonb))
                 order by t.at desc, t.id desc)
          from (select * from public.talk_threads k
                 where k.ask_model = p_model and public.talk_thread_shown(k, viewer, public.trust_is_test_account(viewer))
                 order by k.at desc, k.id desc limit 20) t), '[]'::jsonb) end
$$;

-- ---------------------------------------------------------------------------
-- Who may call them: the server alone.

revoke all on function public.talk_parts_shaped(jsonb) from public, anon, authenticated;
revoke all on function public.talk_ask(uuid, text, integer, integer, jsonb, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.talk_pin_reply(uuid, bigint, text, jsonb, bigint, jsonb) from public, anon, authenticated;
revoke all on function public.talk_ask_as(public.talk_threads) from public, anon, authenticated;
revoke all on function public.talk_asks_of(bigint[]) from public, anon, authenticated;
revoke all on function public.talk_pins_of(bigint[]) from public, anon, authenticated;
revoke all on function public.talk_asks_on(text, uuid) from public, anon, authenticated;
grant execute on function public.talk_parts_shaped(jsonb) to service_role;
grant execute on function public.talk_ask(uuid, text, integer, integer, jsonb, text, text, jsonb) to service_role;
grant execute on function public.talk_pin_reply(uuid, bigint, text, jsonb, bigint, jsonb) to service_role;
grant execute on function public.talk_ask_as(public.talk_threads) to service_role;
grant execute on function public.talk_asks_of(bigint[]) to service_role;
grant execute on function public.talk_pins_of(bigint[]) to service_role;
grant execute on function public.talk_asks_on(text, uuid) to service_role;
