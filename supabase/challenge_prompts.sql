-- A weekly quick build, 2026-11-23 (docs/MASTERPLAN.md, unit prompts): a
-- challenge of a new kind, kept in the challenges' own tables.
--
-- The month's challenge drew no entries in two runs. The community
-- challenges that draw the most people are small and frequent: Instagram's
-- habitats, one minifigure habitat on an 8x8 base, drew 2,605 from 330
-- builders in one run and end in a stack day. So a prompt is:
--
--   a week long, with a brief of a line or two and a template: a model the
--   house publishes (an 8x8 plate, the brief its description) that Start
--   opens in the studio as a copy (/app?copy=). No rules, no vote, no
--   judges, no winners.
--   entered by publishing that copy in the gallery during the week: an entry
--   is a published remix of the template (shared_models.remixed_from), so
--   the remix credit, the age rule and may_publish hold as they are.
--   api/share.js calls prompt_enter as a publish ends, and prompt_withdraw
--   when its owner kept it out (one tap in the publish dialog).
--   stacked when it ends: every entry's file put into one model, each its
--   own 0 FILE, credited, laid one on the next, published by the house
--   (api/_prompts.js) and kept as the prompt's stack.
--
-- A prompt is a row of challenges with kind 'prompt', beside the month's
-- ('month', every row there is now). The functions that pick the month's
-- challenge (open, shown, next, past, the list, the plan, the setter's one
-- at a time, the vote, the settling, Talk's thread) are replaced below,
-- each the live body with kind = 'month' added and nothing else, so a
-- month's challenge, its vote and its honours are what they were with a
-- prompt open beside it (tools/challenge_prompts_try.sql). The notices are
-- not replaced: a prompt opening, and its last two days, are told as a
-- month's are (challenge_notices.sql's rows read the table), and never a
-- result, since a prompt is never settled.
--
-- The streak: the most prompts in a row with an entry of the account's,
-- achievements' seventh track (2 4 8 13 26 52), so a level is first
-- reached at two weeks running. Challenger counts the months alone, as
-- it did.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables.
--
-- Only additions, applied after challenges.sql, challenge_year.sql,
-- challenge_list_order.sql, challenge_rounds.sql, talk.sql and
-- achievements.sql (the guard in tools/apply_sql.mjs, supabase/later.tsv,
-- refuses any of them applied again alone): four columns on challenges
-- (every row now 'month'), achievement_marks' track check widened by one
-- track, the four prompts the house wrote for the next four weeks, and
-- functions. No row is changed, nothing dropped but the one check that is
-- made again wider.

-- ---------------------------------------------------------------------------
-- The columns.

alter table public.challenges add column if not exists kind text not null default 'month';
alter table public.challenges add column if not exists template text references public.shared_models (id) on delete set null;
alter table public.challenges add column if not exists stack text references public.shared_models (id) on delete set null;
alter table public.challenges add column if not exists seed text;
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'challenges_kind_check'
                    and conrelid = 'public.challenges'::regclass) then
        alter table public.challenges add constraint challenges_kind_check check (kind in ('month', 'prompt'));
    end if;
    -- A prompt is at most two weeks; only a prompt has a template, a stack
    -- or a seed (the house's files for it, api/_prompts.js PROMPTS).
    if not exists (select 1 from pg_constraint where conname = 'challenges_prompt_check'
                    and conrelid = 'public.challenges'::regclass) then
        alter table public.challenges add constraint challenges_prompt_check
            check (kind = 'prompt' and ends_on <= starts_on + 13
                   or kind = 'month' and template is null and stack is null and seed is null);
    end if;
    if not exists (select 1 from pg_constraint where conname = 'challenges_seed_check'
                    and conrelid = 'public.challenges'::regclass) then
        alter table public.challenges add constraint challenges_seed_check
            check (seed is null or seed ~ '^[a-z0-9-]{2,40}$');
    end if;
end;
$$;
create unique index if not exists challenges_seed on public.challenges (seed, test) where seed is not null;
create index if not exists challenges_template on public.challenges (template) where template is not null;

-- The streak's track, beside the six achievements.sql made.
do $$
declare
    old text;
begin
    select c.conname into old from pg_constraint c
     where c.conrelid = 'public.achievement_marks'::regclass and c.contype = 'c'
       and pg_get_constraintdef(c.oid) like '%challenger%' and pg_get_constraintdef(c.oid) not like '%streak%';
    if old is not null then
        execute format('alter table public.achievement_marks drop constraint %I', old);
        alter table public.achievement_marks add constraint achievement_marks_track_check
            check (track in ('designer', 'built', 'builder', 'remixed', 'tested', 'challenger', 'streak'));
    end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Setting a prompt (the owner, /admin's Challenges, kind Weekly quick build).

-- A prompt from [starts_on] to [ends_on] (a week, starts_on + 6, unless
-- said), [template] a published model or none (the house publishes its
-- 8x8 plate the next time api/_prompts.js runs), [seed] the house's files
-- for it. {challenge, starts_on, ends_on}, or {refused}: past, days (more
-- than two weeks, or ending before it starts), overlap (another prompt in
-- those days: one a week, with {with}), no_template.
create or replace function public.prompt_set(title text, brief text, starts_on date, ends_on date default null,
                                             template text default null, seed text default null,
                                             test boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    last date := coalesce(prompt_set.ends_on, prompt_set.starts_on + 6);
    other public.challenges;
    made public.challenges;
begin
    if last < public.challenge_today() then
        return jsonb_build_object('refused', 'past');
    end if;
    if last < prompt_set.starts_on or last > prompt_set.starts_on + 13 then
        return jsonb_build_object('refused', 'days');
    end if;
    if prompt_set.template is not null
       and not exists (select 1 from public.shared_models m where m.id = prompt_set.template and m.published) then
        return jsonb_build_object('refused', 'no_template');
    end if;
    perform pg_advisory_xact_lock(hashtext('prompt_set:' || coalesce(prompt_set.test, false)::text));
    select * into other from public.challenges c
     where c.kind = 'prompt' and c.test = coalesce(prompt_set.test, false) and c.ended_at is null
       and c.starts_on <= last and c.ends_on >= prompt_set.starts_on
     order by c.starts_on limit 1;
    if found then
        return jsonb_build_object('refused', 'overlap', 'with', jsonb_build_object('id', other.id, 'title', other.title));
    end if;
    insert into public.challenges (kind, title, brief, starts_on, ends_on, template, seed, test)
    values ('prompt', prompt_set.title, prompt_set.brief, prompt_set.starts_on, last, prompt_set.template,
            prompt_set.seed, coalesce(prompt_set.test, false))
    returning * into made;
    return jsonb_build_object('challenge', made.id, 'starts_on', made.starts_on, 'ends_on', made.ends_on);
end;
$$;

-- The template the house published for prompt [challenge_id], kept where it
-- has none: {kept: true}, or {kept: false} (one there already, or no such
-- prompt, or not a published model).
create or replace function public.prompt_template_set(challenge_id bigint, model_id text)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with kept as (
        update public.challenges c set template = prompt_template_set.model_id
         where c.id = prompt_template_set.challenge_id and c.kind = 'prompt' and c.template is null
           and exists (select 1 from public.shared_models m where m.id = prompt_template_set.model_id and m.published)
        returning c.id)
    select jsonb_build_object('kept', exists (select 1 from kept))
$$;

-- The stack the house published of prompt [challenge_id], once it ended:
-- {kept: true}, or {kept: false} (one there already, not ended, no such
-- prompt, not a published model).
create or replace function public.prompt_stack_set(challenge_id bigint, model_id text)
returns jsonb
language sql
security definer
set search_path = public
as $$
    with kept as (
        update public.challenges c set stack = prompt_stack_set.model_id
         where c.id = prompt_stack_set.challenge_id and c.kind = 'prompt' and c.stack is null
           and public.challenge_state(c) = 'ended'
           and exists (select 1 from public.shared_models m where m.id = prompt_stack_set.model_id and m.published)
        returning c.id)
    select jsonb_build_object('kept', exists (select 1 from kept))
$$;

-- ---------------------------------------------------------------------------
-- What a page and the app are told.

-- The prompt open now whose template is [model_id]: what the studio says
-- under a copy of it, and the publish dialog asks (api/_prompts.js
-- prompt_of). Null for none. Any pool: a template is its prompt's alone.
create or replace function public.prompt_of(model_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', c.id, 'title', c.title, 'brief', c.brief, 'starts_on', c.starts_on,
                              'ends_on', c.ends_on, 'template', c.template, 'test', c.test, 'open', true)
      from public.challenges c
     where c.kind = 'prompt' and c.template = prompt_of.model_id and public.challenge_state(c) = 'open'
     order by c.starts_on desc, c.id desc
     limit 1
$$;

-- One prompt as a page shows it: its words and days, its template's card,
-- its stack's once made, and its entries' cards, newest first, each while
-- its model is in the gallery and its maker shown in public. One still to
-- come too, so its link never shows it as a month's. Null for no such
-- prompt (or a month's, or a test one unasked).
create or replace function public.prompt_page_at(challenge_id bigint, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', c.id, 'kind', c.kind, 'title', c.title, 'brief', c.brief,
               'starts_on', c.starts_on, 'ends_on', c.ends_on,
               'ended_on', least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)),
               'state', public.challenge_state(c), 'test', c.test, 'created_at', c.created_at,
               'template', (select public.directory_card(m) from public.shared_models m
                             where m.id = c.template and m.published and not m.barred),
               'stack', (select public.directory_card(m) from public.shared_models m
                          where m.id = c.stack and public.gallery_shows(m, prompt_page_at.tests)),
               'entries', coalesce((select jsonb_agg(jsonb_build_object('model', e.model, 'way', e.way, 'at', e.at,
                                                                        'card', public.directory_card(m))
                                                     order by e.at desc, e.model)
                                      from public.challenge_entries e
                                      join public.shared_models m on m.id = e.model
                                     where e.challenge = c.id and public.gallery_shows(m, prompt_page_at.tests)
                                       and public.shown_publicly(e.owner)), '[]'::jsonb),
               'makers', (select count(distinct e.owner) from public.challenge_entries e
                           join public.shared_models m on m.id = e.model
                          where e.challenge = c.id and public.gallery_shows(m, prompt_page_at.tests)
                            and public.shown_publicly(e.owner)))
      from public.challenges c
     where c.id = prompt_page_at.challenge_id and c.kind = 'prompt'
       and (not c.test or coalesce(prompt_page_at.tests, false))
$$;

-- The prompts, newest first, for the console, the hub and the notices: each
-- one's words, days, state, template, stack, seed and entries.
create or replace function public.prompt_list(tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', c.id, 'kind', c.kind, 'title', c.title, 'brief', c.brief,
               'starts_on', c.starts_on, 'ends_on', c.ends_on, 'state', public.challenge_state(c), 'test', c.test,
               'ended_at', c.ended_at, 'created_at', c.created_at, 'template', c.template, 'stack', c.stack,
               'seed', c.seed,
               'entries', (select count(*) from public.challenge_entries e where e.challenge = c.id),
               'makers', (select count(distinct e.owner) from public.challenge_entries e where e.challenge = c.id))
      from public.challenges c
     where c.kind = 'prompt' and (not c.test or coalesce(prompt_list.tests, false))
     order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end,
              case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc,
              c.starts_on desc, c.id desc
     limit 24
$$;

-- ---------------------------------------------------------------------------
-- Entering.

-- [model_id] entered in the prompt open now whose template it was copied
-- from, as its publish ends (api/share.js). {entered: true, challenge,
-- title, ends_on, already?}, or {refused}: no_model, not_yours, no_prompt
-- (not a copy of an open prompt's template: the publish says nothing),
-- and, for a copy of one, under_13, not_asked, barred, not_in_gallery,
-- three (each with {challenge, title}).
create or replace function public.prompt_enter(account uuid, model_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    c public.challenges;
    said jsonb;
begin
    select * into m from public.shared_models s where s.id = prompt_enter.model_id;
    if not found or not m.published then
        return jsonb_build_object('refused', 'no_model');
    end if;
    if m.owner <> prompt_enter.account then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    select x.* into c from public.challenges x
     where x.kind = 'prompt' and m.remixed_from is not null and x.template = m.remixed_from and x.test = m.test
       and public.challenge_state(x) = 'open'
     order by x.starts_on desc, x.id desc
     limit 1;
    if not found then
        return jsonb_build_object('refused', 'no_prompt');
    end if;
    said := jsonb_build_object('challenge', c.id, 'title', c.title, 'ends_on', c.ends_on);
    if public.trust_kept_private(prompt_enter.account) then
        return said || jsonb_build_object('refused', 'under_13');
    end if;
    if not public.trust_may_go_public(prompt_enter.account) then
        return said || jsonb_build_object('refused', 'not_asked');
    end if;
    if public.is_barred(prompt_enter.account) then
        return said || jsonb_build_object('refused', 'barred');
    end if;
    if not public.gallery_shows(m, true) or m.author is null then
        return said || jsonb_build_object('refused', 'not_in_gallery');
    end if;
    perform pg_advisory_xact_lock(hashtextextended('challenge_enter:' || prompt_enter.account::text, c.id));
    if exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.model = m.id) then
        return said || jsonb_build_object('entered', true, 'already', true);
    end if;
    if (select count(*) from public.challenge_entries e where e.challenge = c.id and e.owner = prompt_enter.account) >= 3 then
        return said || jsonb_build_object('refused', 'three');
    end if;
    insert into public.challenge_entries (challenge, model, owner, way)
    values (c.id, m.id, prompt_enter.account,
            case when m.made_with in ('assistant', 'brickify') then 'assistant' else 'hand' end);
    return said || jsonb_build_object('entered', true);
end;
$$;

-- [model_id] taken out of the prompt open now, by its owner (the publish
-- dialog's one tap): true when it was in one. A month's entry is left
-- where it is.
create or replace function public.prompt_withdraw(account uuid, model_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    gone integer;
begin
    delete from public.challenge_entries e
     using public.challenges c
     where e.challenge = c.id and c.kind = 'prompt' and e.model = prompt_withdraw.model_id
       and e.owner = prompt_withdraw.account and public.challenge_state(c) = 'open';
    get diagnostics gone = row_count;
    return gone > 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- The house's part (api/_prompts.js, the hourly /api/share/prompts).

-- What the house has to do in [tests]'s pool, a row a prompt: a template
-- to publish (none yet, opened or opening within a week); its two entries
-- to publish (open, with a seed, and fewer than two of the house's in it:
-- have); a stack to make (ended within the month, entries and none made):
-- entries, the foot of the tower first, each while its model is in the
-- gallery and its maker shown in public.
create or replace function public.prompt_house_due(tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', c.id, 'title', c.title, 'brief', c.brief, 'starts_on', c.starts_on,
               'ends_on', c.ends_on, 'state', public.challenge_state(c), 'seed', c.seed, 'test', c.test,
               'template', c.template,
               'have', (select count(*) from public.challenge_entries e
                         where e.challenge = c.id and e.owner = public.talk_house()),
               'entries', case when public.challenge_state(c) = 'ended' and c.stack is null then
                   coalesce((select jsonb_agg(jsonb_build_object('model', e.model, 'at', e.at, 'name', m.name,
                                                                 'author', m.author, 'handle', p.handle)
                                              order by e.at, e.model)
                               from public.challenge_entries e
                               join public.shared_models m on m.id = e.model
                               left join public.people p on p.account = e.owner
                              where e.challenge = c.id and public.gallery_shows(m, prompt_house_due.tests)
                                and public.shown_publicly(e.owner)), '[]'::jsonb) end)
      from public.challenges c
     where c.kind = 'prompt' and c.test = coalesce(prompt_house_due.tests, false)
       and ((c.template is null and c.ended_at is null and c.ends_on >= public.challenge_today()
             and c.starts_on <= public.challenge_today() + 7)
            or (public.challenge_state(c) = 'open' and c.seed is not null
                and (select count(*) from public.challenge_entries e
                      where e.challenge = c.id and e.owner = public.talk_house()) < 2)
            or (public.challenge_state(c) = 'ended' and c.stack is null and c.template is not null
                and c.ends_on >= public.challenge_today() - 30
                and exists (select 1 from public.challenge_entries e where e.challenge = c.id)))
     order by c.starts_on, c.id
     limit 8
$$;

-- The weeks in a row [account] entered: the most prompts, one after the
-- other as they ran in its pool, each with an entry of theirs.
create or replace function public.prompt_streak(account uuid, tests boolean default false)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
    with weeks as (
        select c.id, row_number() over (order by c.starts_on, c.id) as n
          from public.challenges c
         where c.kind = 'prompt' and c.test = coalesce(prompt_streak.tests, false)
           and c.starts_on <= public.challenge_today()),
    entered as (
        select w.n - row_number() over (order by w.n) as run
          from weeks w
         where exists (select 1 from public.challenge_entries e
                        where e.challenge = w.id and e.owner = prompt_streak.account))
    select coalesce(max(x.weeks), 0)::bigint from (select count(*) as weeks from entered group by run) x
$$;

-- ---------------------------------------------------------------------------
-- What picks the month's challenge, a prompt left out of each.

-- challenge_open: the live body, and the month's challenge open now: a prompt is never it.
create or replace function public.challenge_open(tests boolean)
 RETURNS challenges
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    select c.* from public.challenges c
     where c.kind = 'month' and c.test = coalesce(challenge_open.tests, false) and public.challenge_state(c) = 'open'
     order by c.starts_on desc, c.id desc
     limit 1
$$;

-- challenge_shown: the live body, and the month's challenge /challenge shows.
create or replace function public.challenge_shown(tests boolean)
 RETURNS challenges
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    select c.* from public.challenges c
     where c.kind = 'month' and (not c.test or coalesce(challenge_shown.tests, false))
       and (public.challenge_state(c) <> 'ended'
            or exists (select 1 from public.challenge_entries e where e.challenge = c.id))
       and (public.challenge_state(c) <> 'upcoming' or public.challenge_announced(c))
     order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end,
              c.test desc,
              case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc,
              c.ends_on desc, c.id desc
     limit 1
$$;

-- challenge_next: the live body, and the next month's challenge told.
create or replace function public.challenge_next(tests boolean, after bigint DEFAULT NULL::bigint)
 RETURNS challenges
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    select c.* from public.challenges c
     where c.kind = 'month' and (not c.test or coalesce(challenge_next.tests, false))
       and public.challenge_state(c) = 'upcoming' and public.challenge_announced(c)
       and c.id is distinct from challenge_next.after
     order by c.test desc, c.starts_on, c.id
     limit 1
$$;

-- challenge_past: the live body, and the months that ran.
create or replace function public.challenge_past(tests boolean DEFAULT false)
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    select jsonb_build_object('id', c.id, 'title', c.title, 'brief', c.brief, 'starts_on', c.starts_on,
               'ends_on', c.ends_on,
               'ended_on', least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)),
               'test', c.test, 'settled', c.settled_at is not null,
               'entries', (select count(*) from public.challenge_entries e
                             join public.shared_models m on m.id = e.model
                            where e.challenge = c.id and public.gallery_shows(m, challenge_past.tests)
                              and public.shown_publicly(e.owner)),
               'winners', coalesce((select jsonb_agg(jsonb_build_object('way', w.way, 'model', w.model, 'votes', w.votes,
                                                                        'card', public.directory_card(m))
                                                     order by w.way desc)
                                      from public.challenge_winners w
                                      join public.shared_models m on m.id = w.model
                                     where w.challenge = c.id and public.gallery_shows(m, challenge_past.tests)
                                       and public.shown_publicly(w.owner)), '[]'::jsonb))
      from public.challenges c
     where c.kind = 'month' and (not c.test or coalesce(challenge_past.tests, false))
       and public.challenge_state(c) = 'ended' and public.challenge_opened(c)
       and (not c.test or exists (select 1 from public.challenge_entries e where e.challenge = c.id))
     order by least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)) desc, c.id desc
     limit 24
$$;

-- challenge_settle_due: the live body, and a prompt has no vote, so nothing of it is settled.
create or replace function public.challenge_settle_due(tests boolean DEFAULT false)
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    select count(*)::integer from (
        select public.challenge_settle_rounds(c.id) as done
          from public.challenges c
         where c.kind = 'month' and c.test = coalesce(challenge_settle_due.tests, false) and c.settled_at is null
           and public.challenge_state(c) = 'ended'
         order by c.ends_on desc, c.id desc
         limit 5) x
     where x.done
$$;

-- challenge_set: the live body, and one month's challenge at a time; a prompt runs beside it.
create or replace function public.challenge_set(title text, brief text, starts_on date, ends_on date, most_parts integer DEFAULT NULL::integer, set_number text DEFAULT NULL::text, set_name text DEFAULT NULL::text, set_parts jsonb DEFAULT NULL::jsonb, tested boolean DEFAULT false, test boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare
    other public.challenges;
    made public.challenges;
begin
    if challenge_set.ends_on < public.challenge_today() then
        return jsonb_build_object('refused', 'past');
    end if;
    select * into other from public.challenges c
     where c.kind = 'month' and c.test = coalesce(challenge_set.test, false) and c.ended_at is null
       and c.starts_on <= challenge_set.ends_on and c.ends_on >= challenge_set.starts_on
     order by c.starts_on limit 1;
    if found then
        return jsonb_build_object('refused', 'overlap', 'with', jsonb_build_object('id', other.id, 'title', other.title));
    end if;
    if challenge_set.set_number is not null
       and (challenge_set.set_parts is null or jsonb_typeof(challenge_set.set_parts) <> 'array'
            or jsonb_array_length(challenge_set.set_parts) = 0) then
        return jsonb_build_object('refused', 'set_empty');
    end if;
    insert into public.challenges (title, brief, starts_on, ends_on, most_parts, set_number, set_name, tested, test)
    values (challenge_set.title, challenge_set.brief, challenge_set.starts_on, challenge_set.ends_on,
            challenge_set.most_parts, lower(challenge_set.set_number), challenge_set.set_name,
            coalesce(challenge_set.tested, false), coalesce(challenge_set.test, false))
    returning * into made;
    if made.set_number is not null then
        insert into public.challenge_set_parts (challenge, part, colour, qty)
        select made.id, x.part, x.colour, least(sum(x.qty), 200000)
          from jsonb_to_recordset(challenge_set.set_parts) as x(part text, colour integer, qty integer)
         group by x.part, x.colour;
    end if;
    return jsonb_build_object('challenge', made.id, 'starts_on', made.starts_on, 'ends_on', made.ends_on);
end;
$$;

-- challenge_plan: the live body, and the year's themes, months only.
create or replace function public.challenge_plan(themes jsonb, lead_days integer DEFAULT 31, test boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare
    one record;
    other public.challenges;
    made public.challenges;
    planned jsonb := '[]'::jsonb;
    last_day date;
begin
    if challenge_plan.themes is null or jsonb_typeof(challenge_plan.themes) <> 'array'
       or jsonb_array_length(challenge_plan.themes) not between 1 and 12 then
        return jsonb_build_object('refused', 'none');
    end if;
    if challenge_plan.lead_days is null or challenge_plan.lead_days not between 0 and 120 then
        raise exception 'brickworks: a theme is told 0 to 120 days before it opens' using errcode = '22023';
    end if;
    -- One plan at a time, so two cannot both find the same days free.
    perform pg_advisory_xact_lock(hashtext('challenge_plan:' || coalesce(challenge_plan.test, false)::text));
    for one in
        select t.n - 1 as at, t.item->>'title' as title, t.item->>'brief' as brief,
               (t.item->>'starts_on')::date as starts_on, (t.item->>'ends_on')::date as ends_on
          from jsonb_array_elements(challenge_plan.themes) with ordinality as t(item, n)
         order by (t.item->>'starts_on')::date, t.n
    loop
        if coalesce(char_length(one.title), 0) not between 1 and 80
           or coalesce(char_length(one.brief), 0) not between 1 and 600 then
            return jsonb_build_object('refused', 'words', 'at', one.at);
        end if;
        if one.starts_on is null or one.ends_on is null or one.ends_on < one.starts_on
           or one.ends_on > one.starts_on + 62 then
            return jsonb_build_object('refused', 'days', 'at', one.at);
        end if;
        if one.ends_on < public.challenge_today() then
            return jsonb_build_object('refused', 'past', 'at', one.at);
        end if;
        if last_day is not null and one.starts_on <= last_day then
            return jsonb_build_object('refused', 'overlap', 'at', one.at);
        end if;
        last_day := one.ends_on;
        select * into other from public.challenges c
         where c.kind = 'month' and c.test = coalesce(challenge_plan.test, false) and c.ended_at is null
           and c.starts_on <= one.ends_on and c.ends_on >= one.starts_on
         order by c.starts_on limit 1;
        if found then
            return jsonb_build_object('refused', 'overlap', 'at', one.at,
                                      'with', jsonb_build_object('id', other.id, 'title', other.title));
        end if;
    end loop;
    for one in
        select t.item->>'title' as title, t.item->>'brief' as brief,
               (t.item->>'starts_on')::date as starts_on, (t.item->>'ends_on')::date as ends_on
          from jsonb_array_elements(challenge_plan.themes) with ordinality as t(item, n)
         order by (t.item->>'starts_on')::date, t.n
    loop
        insert into public.challenges (title, brief, starts_on, ends_on, test, announced_at)
        values (one.title, one.brief, one.starts_on, one.ends_on, coalesce(challenge_plan.test, false),
                greatest(now(), (one.starts_on - challenge_plan.lead_days)::timestamp at time zone 'utc'))
        returning * into made;
        planned := planned || jsonb_build_object('challenge', made.id, 'title', made.title, 'starts_on', made.starts_on,
                                                 'ends_on', made.ends_on, 'announced_at', made.announced_at);
    end loop;
    return jsonb_build_object('planned', planned);
end;
$$;

-- challenge_vote: the live body, and a prompt has no vote.
create or replace function public.challenge_vote(account uuid, challenge_id bigint, model_id text, tests boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
declare
    c public.challenges;
    e public.challenge_entries;
    m public.shared_models;
    had text;
    made integer;
begin
    select * into c from public.challenges x where x.id = challenge_vote.challenge_id;
    if not found or c.kind <> 'month' or public.challenge_state(c) <> 'open' or c.test <> coalesce(challenge_vote.tests, false) then
        return jsonb_build_object('refused', 'not_open');
    end if;
    if public.trust_kept_private(challenge_vote.account) then
        return jsonb_build_object('refused', 'under_13');
    end if;
    if not public.trust_may_go_public(challenge_vote.account) then
        return jsonb_build_object('refused', 'not_asked');
    end if;
    if public.is_barred(challenge_vote.account) then
        return jsonb_build_object('refused', 'barred');
    end if;
    select * into e from public.challenge_entries x where x.challenge = c.id and x.model = challenge_vote.model_id;
    select * into m from public.shared_models s where s.id = challenge_vote.model_id;
    if e.model is null or m.id is null or not public.gallery_shows(m, true) or not public.shown_publicly(e.owner) then
        return jsonb_build_object('refused', 'no_entry');
    end if;
    if e.owner = challenge_vote.account then
        return jsonb_build_object('refused', 'own');
    end if;
    if not coalesce((public.challenge_check(c.id, e.model)->>'ok')::boolean, false) then
        return jsonb_build_object('refused', 'breaks');
    end if;
    insert into public.challenge_votes (challenge, way, voter, model)
    values (c.id, e.way, challenge_vote.account, e.model)
    on conflict (challenge, way, voter) do nothing;
    get diagnostics made = row_count;
    if made = 0 then
        select v.model into had from public.challenge_votes v
         where v.challenge = c.id and v.way = e.way and v.voter = challenge_vote.account;
        return jsonb_build_object('refused', 'voted', 'way', e.way, 'model', had);
    end if;
    return jsonb_build_object('voted', true, 'way', e.way, 'model', e.model);
end;
$$;

-- challenge_list: the live body, and the months, as Talk's cards and the console read them (prompt_list is the prompts').
create or replace function public.challenge_list(tests boolean DEFAULT false)
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    select jsonb_build_object('id', c.id, 'title', c.title, 'brief', c.brief, 'starts_on', c.starts_on,
               'ends_on', c.ends_on, 'announced_at', c.announced_at, 'state', public.challenge_state(c), 'test', c.test,
               'ended_at', c.ended_at, 'settled', c.settled_at is not null,
               'rules', jsonb_build_object('most_parts', c.most_parts, 'set_number', c.set_number,
                                           'set_name', c.set_name, 'tested', c.tested),
               'entries', jsonb_build_object(
                   'hand', (select count(*) from public.challenge_entries e where e.challenge = c.id and e.way = 'hand'),
                   'assistant', (select count(*) from public.challenge_entries e where e.challenge = c.id and e.way = 'assistant')),
               'votes', jsonb_build_object(
                   'hand', (select count(*) from public.challenge_votes v where v.challenge = c.id and v.way = 'hand'),
                   'assistant', (select count(*) from public.challenge_votes v where v.challenge = c.id and v.way = 'assistant')),
               'winners', coalesce((select jsonb_agg(jsonb_build_object('way', w.way, 'model', w.model, 'name', m.name,
                                                                        'votes', w.votes) order by w.way desc)
                                      from public.challenge_winners w join public.shared_models m on m.id = w.model
                                     where w.challenge = c.id), '[]'::jsonb))
      from public.challenges c
     where c.kind = 'month' and (not c.test or coalesce(challenge_list.tests, false))
     order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end,
              case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc,
              least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)) desc, c.id desc
     limit 24
$$;

-- talk_ensure: the live body, and a month's thread; a prompt's page is its own place.
create or replace function public.talk_ensure(p_tests boolean)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $$
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
         where k.kind = 'month' and k.test = coalesce(p_tests, false) and k.ended_at is null
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

-- achievement_ladders: the live body, and and the streak's levels.
create or replace function public.achievement_ladders()
 RETURNS TABLE(track text, place integer, steps integer[])
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $$
    values ('designer', 1, array[1, 3, 10, 25, 50, 100]),
           ('built', 2, array[1, 10, 50, 100, 500, 1000]),
           ('builder', 3, array[1, 5, 10, 25, 50]),
           ('remixed', 4, array[1, 5, 25, 100]),
           ('tested', 5, array[1, 5, 10, 25]),
           ('challenger', 6, array[1, 3, 6, 12]),
           ('streak', 7, array[2, 4, 8, 13, 26, 52])
$$;

-- achievement_numbers: the live body, and challenger counts the months; streak the weeks in a row.
create or replace function public.achievement_numbers(account uuid, tests boolean DEFAULT false)
 RETURNS TABLE(track text, n bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $$
    with who as (
        select achievement_numbers.account as id
         where achievement_numbers.account is not null and public.shown_publicly(achievement_numbers.account)),
    theirs as materialized (
        select m.id, coalesce(s.builds, 0) as builds, public.model_tested(m.id) as tested
          from who w
          join public.shared_models m on m.owner = w.id
          left join public.model_stats s on s.model = m.id
         where m.published and m.listed and not m.barred and m.author is not null
           and (not m.test or coalesce(achievement_numbers.tests, false)))
    select x.track, x.n
      from who w
     cross join lateral (values
        ('designer', (select count(*) from theirs)),
        ('built', (select coalesce(sum(t.builds), 0)::bigint from theirs t)),
        ('builder', (select count(*) from public.build_photos ph
                       join public.shared_models m on m.id = ph.model
                      where ph.account = w.id and ph.removed_at is null and ph.hidden_at is null
                        and m.published and m.listed and not m.barred
                        and (not m.test or coalesce(achievement_numbers.tests, false)))),
        ('remixed', (select count(*) from public.shared_models r
                      where r.remixed_from in (select t.id from theirs t) and r.published)),
        ('tested', (select count(*) from theirs t where t.tested)),
        ('challenger', (select count(distinct e.challenge) from public.challenge_entries e
                          join public.challenges c on c.id = e.challenge
                         where e.owner = w.id and c.kind = 'month'
                           and (not c.test or coalesce(achievement_numbers.tests, false)))),
        ('streak', public.prompt_streak(w.id, achievement_numbers.tests))
     ) x(track, n)
$$;

-- ---------------------------------------------------------------------------
-- The house's first four prompts, the next four weeks from Monday 23
-- November 2026, written 2026-11-23. Each once (its seed): applied again,
-- nothing is added. Their templates and the house's two entries a week are
-- published by api/_prompts.js as each comes due.

insert into public.challenges (kind, title, brief, starts_on, ends_on, seed)
select 'prompt', x.title, x.brief, x.starts_on, x.starts_on + 6, x.seed
  from (values
    ('habitat', 'Habitat',
     'A home for one minifigure on an 8×8 plate: a room, a nook, a nest, a lair. Keep it within 10 bricks tall, '
     || 'so every habitat of the week stacks into one tower.', date '2026-11-23'),
    ('snowed-in', 'Snowed in',
     'A winter scene on an 8×8 plate: a cabin porch, a frozen pond, a shop front under the snow. Keep it within '
     || '10 bricks tall: every entry goes into the week''s stack.', date '2026-11-30'),
    ('workshop', 'Tiny workshop',
     'Somebody''s workshop on an 8×8 plate: a toymaker''s bench, a bike stand, a robot lab. Keep it within 10 '
     || 'bricks tall: every entry goes into the week''s stack.', date '2026-12-07'),
    ('gift-box', 'What''s in the box',
     'A gift box on an 8×8 plate, opened to show what is inside. Keep it within 10 bricks tall: every entry goes '
     || 'into the week''s stack.', date '2026-12-14')
  ) as x(seed, title, brief, starts_on)
 where not exists (select 1 from public.challenges c where c.seed = x.seed and not c.test)
   and not exists (select 1 from public.challenges c
                    where c.kind = 'prompt' and not c.test and c.ended_at is null
                      and c.starts_on <= x.starts_on + 6 and c.ends_on >= x.starts_on);

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.prompt_set(text, text, date, date, text, text, boolean) from public, anon, authenticated;
grant execute on function public.prompt_set(text, text, date, date, text, text, boolean) to service_role;
revoke all on function public.prompt_template_set(bigint, text) from public, anon, authenticated;
grant execute on function public.prompt_template_set(bigint, text) to service_role;
revoke all on function public.prompt_stack_set(bigint, text) from public, anon, authenticated;
grant execute on function public.prompt_stack_set(bigint, text) to service_role;
revoke all on function public.prompt_of(text) from public, anon, authenticated;
grant execute on function public.prompt_of(text) to service_role;
revoke all on function public.prompt_page_at(bigint, boolean) from public, anon, authenticated;
grant execute on function public.prompt_page_at(bigint, boolean) to service_role;
revoke all on function public.prompt_list(boolean) from public, anon, authenticated;
grant execute on function public.prompt_list(boolean) to service_role;
revoke all on function public.prompt_enter(uuid, text) from public, anon, authenticated;
grant execute on function public.prompt_enter(uuid, text) to service_role;
revoke all on function public.prompt_withdraw(uuid, text) from public, anon, authenticated;
grant execute on function public.prompt_withdraw(uuid, text) to service_role;
revoke all on function public.prompt_house_due(boolean) from public, anon, authenticated;
grant execute on function public.prompt_house_due(boolean) to service_role;
revoke all on function public.prompt_streak(uuid, boolean) from public, anon, authenticated;
grant execute on function public.prompt_streak(uuid, boolean) to service_role;
