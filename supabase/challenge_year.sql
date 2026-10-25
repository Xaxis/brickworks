-- Challenges between months, 2026-10-24 (docs/SOCIAL.md U12).
--
-- Between two challenges /challenge was one sentence: no past challenge, no
-- winner, nothing to come. Now it says what ran before and who won it, and
-- the next one's theme and days; and the site's owner sets a year of themes
-- at once on /admin instead of one a month.
--
--   challenges.announced_at   when visitors are told of a challenge: its
--                             title, brief and days. Null for every one set
--                             before this file, and for one set alone on
--                             /admin (challenge_set): told at once, as now.
--                             A year's themes (challenge_plan) are each told
--                             a month before they open, so the next one is
--                             known while this one runs and the rest of the
--                             year stays the owner's.
--
-- New functions, each security definer and the service role's alone:
--
--   challenge_announced(c)    whether visitors may be told of it
--   challenge_opened(c)       whether it ever opened: one the owner ended
--                             before its first day never did, and is in no
--                             list of past challenges
--   challenge_next(tests, after)   the next to open that is told, not [after]
--   challenge_past(tests)     the challenges that ran, newest first, with
--                             their winners as gallery cards
--   challenge_page_at(id, tests)   challenge_page for one challenge: the
--                             open one, the next told, or one that ran
--   challenge_plan(themes, lead_days, test)   a year of themes, all or none
--
-- And three of challenges.sql's replaced, each with the same answers for
-- every challenge there is now (none has an announced_at):
--
--   challenge_shown   an upcoming one only once it is told
--   challenge_page    challenge_page_at of the one challenge_shown chooses:
--                     the same body, asked by id
--   challenge_list    the same rows, and each one's announced_at
--
-- Applying challenges.sql again after this would put the three back as they
-- were (tools/apply_sql.mjs refuses it alone). Only additions: one column,
-- empty on every row; no row changed, nothing dropped or renamed. Apply after
-- challenges.sql, trust.sql, discovery.sql and designers.sql.

alter table public.challenges add column if not exists announced_at timestamptz;

comment on column public.challenges.announced_at is
    'When visitors are told of the challenge (supabase/challenge_year.sql). '
    'Null: at once, as every challenge set alone on /admin.';

-- ---------------------------------------------------------------------------
-- When a challenge is told, and whether it ran.

-- Whether visitors may be told of [c]: its title, brief and days.
create or replace function public.challenge_announced(c public.challenges)
returns boolean
language sql
stable
set search_path = public
as $$
    select c.announced_at is null or c.announced_at <= now()
$$;

-- Whether [c] ever opened: its first day has come, and the owner did not
-- end it before then.
create or replace function public.challenge_opened(c public.challenges)
returns boolean
language sql
stable
set search_path = public
as $$
    select c.starts_on <= public.challenge_today()
       and (c.ended_at is null or (c.ended_at at time zone 'utc')::date >= c.starts_on)
$$;

-- REPLACES challenges.sql's: the same, and an upcoming one only once it is
-- told. Which challenge /challenge shows, as a page asked with [tests]
-- (whose own test ones come first): the one open, or else the next to open
-- that is told, or else the last that ended with somebody in it.
create or replace function public.challenge_shown(tests boolean)
returns public.challenges
language sql
stable
security definer
set search_path = public
as $$
    select c.* from public.challenges c
     where (not c.test or coalesce(challenge_shown.tests, false))
       and (public.challenge_state(c) <> 'ended'
            or exists (select 1 from public.challenge_entries e where e.challenge = c.id))
       and (public.challenge_state(c) <> 'upcoming' or public.challenge_announced(c))
     order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end,
              c.test desc,
              case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc,
              c.ends_on desc, c.id desc
     limit 1
$$;

-- The next challenge to open that visitors are told of, other than [after]
-- (the one /challenge shows): a page asked with [tests] has its own test
-- ones first.
create or replace function public.challenge_next(tests boolean, after bigint default null)
returns public.challenges
language sql
stable
security definer
set search_path = public
as $$
    select c.* from public.challenges c
     where (not c.test or coalesce(challenge_next.tests, false))
       and public.challenge_state(c) = 'upcoming' and public.challenge_announced(c)
       and c.id is distinct from challenge_next.after
     order by c.test desc, c.starts_on, c.id
     limit 1
$$;

-- ---------------------------------------------------------------------------
-- What anybody sees.

-- One challenge as /challenge shows it, as a page asked with [tests] sees
-- it: the one open, an upcoming one that is told, or one that ran; null for
-- any other (one to come not yet told, one ended before it opened, a test
-- one to a page not asked with tests). Its rules and days, and its entries
-- as gallery cards, each with its group, when it was entered, whether it
-- keeps the rules and, once it has ended, its votes; the winners once
-- settled. challenge_page's body, word for word, asked by id.
create or replace function public.challenge_page_at(challenge_id bigint, tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with c as (select x.* from public.challenges x
                where x.id = challenge_page_at.challenge_id
                  and (not x.test or coalesce(challenge_page_at.tests, false))
                  and case public.challenge_state(x) when 'open' then true
                           when 'upcoming' then public.challenge_announced(x)
                           else public.challenge_opened(x) end),
    shown as materialized (
        select e.*, m as sm
          from c
          join public.challenge_entries e on e.challenge = c.id
          join public.shared_models m on m.id = e.model
         where public.gallery_shows(m, challenge_page_at.tests) and public.shown_publicly(e.owner)),
    keeps as (
        select * from public.challenge_keeps((select c.id from c), array(select s.model from shown s))),
    counted as (
        select v.model, count(*) as n from public.challenge_votes v
         where v.challenge = (select c.id from c)
           and not public.is_barred(v.voter) and not public.trust_kept_private(v.voter)
         group by v.model)
    select case when not exists (select 1 from c) then null else (
        select jsonb_build_object(
            'id', c.id, 'title', c.title, 'brief', c.brief, 'starts_on', c.starts_on, 'ends_on', c.ends_on,
            'state', public.challenge_state(c), 'test', c.test, 'settled', c.settled_at is not null,
            'rules', jsonb_build_object('most_parts', c.most_parts, 'set_number', c.set_number,
                                        'set_name', c.set_name, 'tested', c.tested),
            'entries', coalesce((select jsonb_agg(jsonb_build_object(
                    'model', s.model, 'way', s.way, 'at', s.at, 'keeps', coalesce(k.keeps, false),
                    'votes', case when public.challenge_state(c) = 'ended' then coalesce(n.n, 0) end,
                    'card', public.directory_card(s.sm))
                  order by s.way desc,
                           case when public.challenge_state(c) = 'ended' then coalesce(n.n, 0) end desc nulls last,
                           s.at, s.model)
                from shown s
                left join keeps k on k.model = s.model
                left join counted n on n.model = s.model), '[]'::jsonb),
            'winners', coalesce((select jsonb_agg(jsonb_build_object('way', w.way, 'model', w.model, 'votes', w.votes)
                                                  order by w.way desc)
                                   from public.challenge_winners w where w.challenge = c.id), '[]'::jsonb))
          from c) end
$$;

-- REPLACES challenges.sql's: the same answer, asked of challenge_page_at.
-- /challenge, as a page asked with [tests] shows it: the challenge
-- challenge_shown chooses, or null when there is none.
create or replace function public.challenge_page(tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select public.challenge_page_at((public.challenge_shown(challenge_page.tests)).id, challenge_page.tests)
$$;

-- The challenges that ran, as a page asked with [tests] sees them, the
-- last to end first, at most 24: {id, title, brief, starts_on, ends_on,
-- ended_on, test, settled, entries (how many are shown), winners: [{way,
-- model, votes, card}]}. A winner only while its model is in the gallery and
-- its designer shown in public, as an entry is. A test challenge only while
-- an entry is left in it: the flows' accounts go when they end, and their
-- entries with them.
create or replace function public.challenge_past(tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
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
     where (not c.test or coalesce(challenge_past.tests, false))
       and public.challenge_state(c) = 'ended' and public.challenge_opened(c)
       and (not c.test or exists (select 1 from public.challenge_entries e where e.challenge = c.id))
     order by least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)) desc, c.id desc
     limit 24
$$;

-- ---------------------------------------------------------------------------
-- The owner's: a year of themes.

-- REPLACED LATER: challenge_list_order.sql replaces this function (the ones not
-- yet ended first). Apply challenge_list_order.sql again right after this file:
-- tools/apply_sql.mjs refuses this file alone, unless
-- --again=supabase/challenge_list_order.sql.
-- REPLACES challenges.sql's: the same rows, and each one's announced_at.
-- Every challenge, newest first, for the admin page: {id, title, brief,
-- starts_on, ends_on, announced_at, state, rules, test, entries: {hand,
-- assistant}, votes: {hand, assistant}, winners}.
create or replace function public.challenge_list(tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
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
     where not c.test or coalesce(challenge_list.tests, false)
     order by c.starts_on desc, c.id desc
     limit 24
$$;

-- A year of themes, set at once: [themes] up to twelve {title, brief,
-- starts_on, ends_on}, with no rules but the brief, each told [lead_days]
-- before its first day (at once, when that has passed). All or none:
-- {planned: [{challenge, title, starts_on, ends_on, announced_at}]}, or
-- {refused, at} (at: which theme, counted from 0, as given) with why:
--
--   none      no theme, or more than twelve
--   words     a title of 1 to 80 characters and a brief of 1 to 600, each
--   days      a last day before the first, or more than 63 days
--   past      one would end before today
--   overlap   a day shared with another theme, or with another challenge of
--             its kind (test or not) not ended ({with: {id, title}})
create or replace function public.challenge_plan(themes jsonb, lead_days integer default 31, test boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
         where c.test = coalesce(challenge_plan.test, false) and c.ended_at is null
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

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.challenge_announced(public.challenges) from public, anon, authenticated;
grant execute on function public.challenge_announced(public.challenges) to service_role;
revoke all on function public.challenge_opened(public.challenges) from public, anon, authenticated;
grant execute on function public.challenge_opened(public.challenges) to service_role;
revoke all on function public.challenge_shown(boolean) from public, anon, authenticated;
grant execute on function public.challenge_shown(boolean) to service_role;
revoke all on function public.challenge_next(boolean, bigint) from public, anon, authenticated;
grant execute on function public.challenge_next(boolean, bigint) to service_role;
revoke all on function public.challenge_page_at(bigint, boolean) from public, anon, authenticated;
grant execute on function public.challenge_page_at(bigint, boolean) to service_role;
revoke all on function public.challenge_page(boolean) from public, anon, authenticated;
grant execute on function public.challenge_page(boolean) to service_role;
revoke all on function public.challenge_past(boolean) from public, anon, authenticated;
grant execute on function public.challenge_past(boolean) to service_role;
revoke all on function public.challenge_list(boolean) from public, anon, authenticated;
grant execute on function public.challenge_list(boolean) to service_role;
revoke all on function public.challenge_plan(jsonb, integer, boolean) from public, anon, authenticated;
grant execute on function public.challenge_plan(jsonb, integer, boolean) to service_role;
