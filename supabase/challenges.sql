-- Challenges, 2026-10-19: a monthly building challenge, with rules the site
-- can check.
--
-- The site's owner sets one challenge at a time on /admin: a title, a short
-- brief, the days it runs, and up to three rules:
--
--   most_parts   at most so many parts (shared_models.parts, what the card
--                says)
--   set          only parts of one official set's inventory, by part and
--                colour, as many as the set has (its spares too): the set's
--                parts kept with the challenge (challenge_set_parts) when it
--                is set, spelled the way model_needs is (api/_owned.js
--                keyed), so the check is one join with what the model needs
--                (discovery.sql model_needs)
--   tested       the model's newest version marked Tested (model_tested)
--
-- A designer enters one of their models in the gallery, credited to them,
-- from its page, and says whether it was built by hand or with the
-- assistant: the two are shown and judged apart. challenge_enter checks
-- every rule on the model as it is stored and says which it breaks. At most
-- three models a designer, each once. People signed in and 13 or over vote,
-- once in each group, never for their own. The votes are counted when it
-- ends: before, nobody is shown them. When it ends the entry with the most
-- votes in each group wins (a tie to the one entered first, and never with
-- no vote at all), kept in challenge_winners the first time it is asked
-- for after (challenge_settle), so a winner stays one.
--
-- While it runs an entry is shown while its model is in the gallery and its
-- designer is shown in public; an entry whose model no longer keeps the
-- rules (a newer version broke one) says so, and is not voted for, nor
-- counted. Nobody under 13 enters or votes, and nobody not asked yet
-- (trust_may_go_public), nor an account taken out (is_barred).
--
-- A test account's model enters only a test challenge, and a test
-- account votes only in one: a test challenge is the flows' own
-- (tools/web/challenges_flow.mjs), shown only to a page asked with tests=1,
-- with its own one at a time.
--
-- Who may touch what: only the server, through the functions here, each
-- security definer and granted to the service role alone. No key a page
-- has, and not the service role itself, reads or writes the tables
-- directly.
--
-- Only additions, applied after designers.sql, discovery.sql, follows.sql,
-- builds.sql, tested.sql and trust.sql (it reads model_needs, model_tested,
-- gallery_shows, directory_card, trust's and moderation's rules): five new
-- tables and new functions. No function another file defines is replaced,
-- so every answer the live functions give is the same
-- (tools/challenges_try.sql). No existing row is changed, nothing dropped or
-- renamed.

-- ---------------------------------------------------------------------------
-- The tables.

create table if not exists public.challenges (
    id          bigint generated always as identity primary key,
    title       text not null check (char_length(title) between 1 and 80),
    brief       text not null check (char_length(brief) between 1 and 600),
    starts_on   date not null,
    ends_on     date not null,
    most_parts  integer check (most_parts is null or most_parts between 1 and 200000),
    set_number  text check (set_number is null or set_number ~ '^[0-9a-z][0-9a-z.-]{0,30}$'),
    set_name    text check (set_name is null or char_length(set_name) between 1 and 200),
    tested      boolean not null default false,
    test        boolean not null default false,
    created_at  timestamptz not null default now(),
    ended_at    timestamptz,
    settled_at  timestamptz,
    check (ends_on >= starts_on and ends_on <= starts_on + 62),
    check ((set_number is null) = (set_name is null))
);
create index if not exists challenges_days on public.challenges (test, ends_on desc);

create table if not exists public.challenge_set_parts (
    challenge  bigint not null references public.challenges (id) on delete cascade,
    part       text not null check (char_length(part) between 1 and 64),
    colour     integer not null check (colour >= 0),
    qty        integer not null check (qty between 1 and 200000),
    primary key (challenge, part, colour)
);

create table if not exists public.challenge_entries (
    challenge  bigint not null references public.challenges (id) on delete cascade,
    model      text not null references public.shared_models (id) on delete cascade,
    owner      uuid not null references auth.users (id) on delete cascade,
    way        text not null check (way in ('hand', 'assistant')),
    at         timestamptz not null default now(),
    primary key (challenge, model)
);
create index if not exists challenge_entries_owner on public.challenge_entries (owner, challenge);
create index if not exists challenge_entries_model on public.challenge_entries (model);

create table if not exists public.challenge_votes (
    challenge  bigint not null,
    way        text not null check (way in ('hand', 'assistant')),
    voter      uuid not null references auth.users (id) on delete cascade,
    model      text not null,
    at         timestamptz not null default now(),
    primary key (challenge, way, voter),
    foreign key (challenge, model) references public.challenge_entries (challenge, model) on delete cascade
);
create index if not exists challenge_votes_model on public.challenge_votes (challenge, model);

create table if not exists public.challenge_winners (
    challenge  bigint not null references public.challenges (id) on delete cascade,
    way        text not null check (way in ('hand', 'assistant')),
    model      text not null references public.shared_models (id) on delete cascade,
    owner      uuid not null references auth.users (id) on delete cascade,
    votes      integer not null check (votes >= 1),
    at         timestamptz not null default now(),
    primary key (challenge, way)
);
create index if not exists challenge_winners_owner on public.challenge_winners (owner);
create index if not exists challenge_winners_model on public.challenge_winners (model);

alter table public.challenges enable row level security;
alter table public.challenge_set_parts enable row level security;
alter table public.challenge_entries enable row level security;
alter table public.challenge_votes enable row level security;
alter table public.challenge_winners enable row level security;
revoke all on public.challenges from public, anon, authenticated, service_role;
revoke all on public.challenge_set_parts from public, anon, authenticated, service_role;
revoke all on public.challenge_entries from public, anon, authenticated, service_role;
revoke all on public.challenge_votes from public, anon, authenticated, service_role;
revoke all on public.challenge_winners from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Where a challenge is.

-- The day, as the challenge's dates are: UTC.
create or replace function public.challenge_today()
returns date
language sql
stable
set search_path = public
as $$
    select (now() at time zone 'utc')::date
$$;

-- upcoming, open or ended: open from the first day to the last, both
-- whole days in UTC, unless the owner ended it early.
create or replace function public.challenge_state(c public.challenges)
returns text
language sql
stable
set search_path = public
as $$
    select case when c.ended_at is not null or c.ends_on < public.challenge_today() then 'ended'
                when c.starts_on > public.challenge_today() then 'upcoming'
                else 'open' end
$$;

-- The challenge open now among the test ones or the others: at most one.
create or replace function public.challenge_open(tests boolean)
returns public.challenges
language sql
stable
security definer
set search_path = public
as $$
    select c.* from public.challenges c
     where c.test = coalesce(challenge_open.tests, false) and public.challenge_state(c) = 'open'
     order by c.starts_on desc, c.id desc
     limit 1
$$;

-- Which challenge /challenge shows, as a page asked with [tests] (whose
-- own test ones come first): the one open, or else the next to open, or
-- else the last that ended with somebody in it.
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
     order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end,
              c.test desc,
              case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc,
              c.ends_on desc, c.id desc
     limit 1
$$;

-- ---------------------------------------------------------------------------
-- The rules, checked.

-- What [challenge_id]'s rules say of [model_id] as it is stored:
-- {ok, parts: {most, has, ok}, set: {number, name, counted, ok, short,
-- short_lots}, tested: {ok}}, a rule the challenge does not have left out.
-- short: up to twelve of the lots the set has too few of (or none), the
-- most missing first: {part, colour, need, have}. A model whose needs were
-- never counted (published before discovery.sql and not counted since)
-- does not keep the set's rule: counted false.
create or replace function public.challenge_check(challenge_id bigint, model_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with c as (select * from public.challenges where id = challenge_check.challenge_id),
    m as (select * from public.shared_models where id = challenge_check.model_id),
    counted as (select exists (select 1 from public.model_needs_kept k where k.model = challenge_check.model_id) as yes),
    short as materialized (
        select n.part, n.colour, n.qty as need, coalesce(s.qty, 0) as have
          from public.model_needs n
          left join public.challenge_set_parts s
                 on s.challenge = challenge_check.challenge_id and s.part = n.part and s.colour = n.colour
         where n.model = challenge_check.model_id
           and (select c.set_number is not null from c)
           and coalesce(s.qty, 0) < n.qty),
    said as (
        select case when c.most_parts is null then null
                    else jsonb_build_object('most', c.most_parts, 'has', m.parts, 'ok', m.parts <= c.most_parts) end as parts,
               case when c.set_number is null then null
                    else jsonb_build_object('number', c.set_number, 'name', c.set_name, 'counted', k.yes,
                        'ok', k.yes and not exists (select 1 from short),
                        'short_lots', (select count(*) from short),
                        'short', coalesce((select jsonb_agg(jsonb_build_object('part', x.part, 'colour', x.colour,
                                                              'need', x.need, 'have', x.have)
                                                    order by x.need - x.have desc, x.part, x.colour)
                                             from (select * from short order by need - have desc, part, colour limit 12) x),
                                          '[]'::jsonb)) end as set,
               case when c.tested then jsonb_build_object('ok', public.model_tested(m.id)) end as tested
          from c cross join m cross join counted k)
    select case when not exists (select 1 from c) or not exists (select 1 from m) then null else (
        select jsonb_strip_nulls(jsonb_build_object('parts', s.parts, 'set', s.set, 'tested', s.tested))
               || jsonb_build_object('ok', coalesce((s.parts->>'ok')::boolean, true)
                                         and coalesce((s.set->>'ok')::boolean, true)
                                         and coalesce((s.tested->>'ok')::boolean, true))
          from said s) end
$$;

-- Whether the [entries] of [challenge_id] keep its rules now, each: (model,
-- keeps). One query for a page of them, where challenge_check would be one
-- each: the parts and Tested read from the model, the set's from one join.
create or replace function public.challenge_keeps(challenge_id bigint, entries text[])
returns table (model text, keeps boolean)
language sql
stable
security definer
set search_path = public
as $$
    with c as (select * from public.challenges where id = challenge_keeps.challenge_id),
    short as (
        select distinct n.model
          from public.model_needs n
          left join public.challenge_set_parts s
                 on s.challenge = challenge_keeps.challenge_id and s.part = n.part and s.colour = n.colour
         where n.model = any (challenge_keeps.entries)
           and (select c.set_number is not null from c)
           and coalesce(s.qty, 0) < n.qty)
    select m.id,
           (c.most_parts is null or m.parts <= c.most_parts)
           and (c.set_number is null or (exists (select 1 from public.model_needs_kept k where k.model = m.id)
                                         and m.id not in (select x.model from short x)))
           and (not c.tested or public.model_tested(m.id))
      from public.shared_models m cross join c
     where m.id = any (challenge_keeps.entries)
$$;

-- ---------------------------------------------------------------------------
-- The owner's: setting one, and ending it.

-- A challenge set, from [starts_on] to [ends_on] (whole days, UTC, at most
-- 63 of them), with the rules given (null for a rule it does not have;
-- [set_parts] the set's parts, [{part, colour, qty}], counted by
-- api/admin.js from its inventory): {challenge}, or {refused} with why:
--
--   past       it would end before today
--   overlap    another of its kind (test or not) not ended has a day of
--              these: one at a time ({with: {id, title}})
--   set_empty  a set rule with no parts in it
create or replace function public.challenge_set(title text, brief text, starts_on date, ends_on date,
    most_parts integer default null, set_number text default null, set_name text default null,
    set_parts jsonb default null, tested boolean default false, test boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    other public.challenges;
    made public.challenges;
begin
    if challenge_set.ends_on < public.challenge_today() then
        return jsonb_build_object('refused', 'past');
    end if;
    select * into other from public.challenges c
     where c.test = coalesce(challenge_set.test, false) and c.ended_at is null
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

-- [challenge_id] ended now, by the owner: true when it had not ended.
create or replace function public.challenge_end(challenge_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    ended integer;
begin
    update public.challenges c set ended_at = now()
     where c.id = challenge_end.challenge_id and c.ended_at is null;
    get diagnostics ended = row_count;
    return ended > 0;
end;
$$;

-- Every challenge, newest first, for the admin page: {id, title, brief,
-- starts_on, ends_on, state, rules, test, entries: {hand, assistant},
-- votes: {hand, assistant}, winners}.
create or replace function public.challenge_list(tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('id', c.id, 'title', c.title, 'brief', c.brief, 'starts_on', c.starts_on,
               'ends_on', c.ends_on, 'state', public.challenge_state(c), 'test', c.test,
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

-- ---------------------------------------------------------------------------
-- A designer's: entering, and taking an entry back.

-- [account] enters [model_id], built by [way] ('hand' or 'assistant'), in
-- the challenge open now for its kind: {entered, challenge, way, check},
-- or {refused} with why, and the rules' check when it was those:
--
--   no_model      not a published model
--   not_yours     somebody else's
--   under_13, not_asked, barred   the age question, or taken out
--   not_in_gallery   not listed in the gallery, or not credited
--   no_challenge  none is open
--   entered       it is in already ({way})
--   three         three of theirs are in already
--   rules         it breaks a rule ({check}, as challenge_check)
create or replace function public.challenge_enter(account uuid, model_id text, way text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    c public.challenges;
    was public.challenge_entries;
    checked jsonb;
begin
    if challenge_enter.way is null or challenge_enter.way not in ('hand', 'assistant') then
        raise exception 'brickworks: an entry is built by hand or with the assistant' using errcode = '22023';
    end if;
    select * into m from public.shared_models s where s.id = challenge_enter.model_id;
    if not found or not m.published then
        return jsonb_build_object('refused', 'no_model');
    end if;
    if m.owner <> challenge_enter.account then
        return jsonb_build_object('refused', 'not_yours');
    end if;
    if public.trust_kept_private(challenge_enter.account) then
        return jsonb_build_object('refused', 'under_13');
    end if;
    if not public.trust_may_go_public(challenge_enter.account) then
        return jsonb_build_object('refused', 'not_asked');
    end if;
    if public.is_barred(challenge_enter.account) then
        return jsonb_build_object('refused', 'barred');
    end if;
    if not public.gallery_shows(m, true) or m.author is null then
        return jsonb_build_object('refused', 'not_in_gallery');
    end if;
    c := public.challenge_open(m.test);
    if c.id is null then
        return jsonb_build_object('refused', 'no_challenge');
    end if;
    -- One at a time per designer, so three are counted as three.
    perform pg_advisory_xact_lock(hashtextextended('challenge_enter:' || challenge_enter.account::text, c.id));
    select * into was from public.challenge_entries e where e.challenge = c.id and e.model = m.id;
    if found then
        return jsonb_build_object('refused', 'entered', 'way', was.way, 'challenge', c.id);
    end if;
    if (select count(*) from public.challenge_entries e where e.challenge = c.id and e.owner = challenge_enter.account) >= 3 then
        return jsonb_build_object('refused', 'three', 'challenge', c.id);
    end if;
    checked := public.challenge_check(c.id, m.id);
    if not coalesce((checked->>'ok')::boolean, false) then
        return jsonb_build_object('refused', 'rules', 'challenge', c.id, 'check', checked);
    end if;
    insert into public.challenge_entries (challenge, model, owner, way)
    values (c.id, m.id, challenge_enter.account, challenge_enter.way);
    return jsonb_build_object('entered', true, 'challenge', c.id, 'title', c.title, 'way', challenge_enter.way,
                              'check', checked);
end;
$$;

-- [account]'s entry of [model_id] taken back, while its challenge is open,
-- and the votes for it with it: true when there was one.
create or replace function public.challenge_withdraw(account uuid, model_id text)
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
     where e.challenge = c.id and e.model = challenge_withdraw.model_id and e.owner = challenge_withdraw.account
       and public.challenge_state(c) = 'open';
    get diagnostics gone = row_count;
    return gone > 0;
end;
$$;

-- What a model's page tells its owner: the challenge open now for its
-- kind, and its entry in it. {challenge: {id, title, ends_on, rules},
-- entry: {way, at} | null, check} or {challenge: null}.
create or replace function public.challenge_for_model(account uuid, model_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with m as (select * from public.shared_models s where s.id = challenge_for_model.model_id
                  and s.owner = challenge_for_model.account and s.published),
    c as (select o.* from m cross join lateral public.challenge_open(m.test) o where o.id is not null)
    select case when not exists (select 1 from c) then jsonb_build_object('challenge', null) else (
        select jsonb_build_object(
            'challenge', jsonb_build_object('id', c.id, 'title', c.title, 'starts_on', c.starts_on, 'ends_on', c.ends_on,
                'rules', jsonb_build_object('most_parts', c.most_parts, 'set_number', c.set_number,
                                            'set_name', c.set_name, 'tested', c.tested)),
            'entry', (select jsonb_build_object('way', e.way, 'at', e.at) from public.challenge_entries e
                       where e.challenge = c.id and e.model = challenge_for_model.model_id),
            'entries', (select count(*) from public.challenge_entries e
                         where e.challenge = c.id and e.owner = challenge_for_model.account),
            'check', public.challenge_check(c.id, challenge_for_model.model_id))
          from c) end
$$;

-- ---------------------------------------------------------------------------
-- Votes.

-- [account] votes for [model_id] in [challenge_id], once in its group; a
-- test account ([tests]) only in a test challenge, and anybody else only
-- in one that is not: {voted, way, model}, or {refused} with why:
--
--   not_open      not a challenge open now, or not one for this account
--   under_13, not_asked, barred
--   no_entry      not in it, or not shown in it now
--   own           their own entry
--   breaks        it no longer keeps the rules
--   voted         they voted in its group already ({model}: for which)
create or replace function public.challenge_vote(account uuid, challenge_id bigint, model_id text, tests boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.challenges;
    e public.challenge_entries;
    m public.shared_models;
    had text;
    made integer;
begin
    select * into c from public.challenges x where x.id = challenge_vote.challenge_id;
    if not found or public.challenge_state(c) <> 'open' or c.test <> coalesce(challenge_vote.tests, false) then
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

-- ---------------------------------------------------------------------------
-- When it ends.

-- [challenge_id]'s winners kept, once it has ended: in each group, the
-- entry with the most votes still counted (its model in the gallery, its
-- designer shown, keeping the rules; votes by accounts shown in public or
-- not asked yet, never one taken out or under 13), a tie to the one entered
-- first, none with no vote. True when it was settled now.
create or replace function public.challenge_settle(challenge_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.challenges;
begin
    select * into c from public.challenges x where x.id = challenge_settle.challenge_id for update;
    if not found or c.settled_at is not null or public.challenge_state(c) <> 'ended' then
        return false;
    end if;
    insert into public.challenge_winners (challenge, way, model, owner, votes)
    select distinct on (t.way) c.id, t.way, t.model, t.owner, t.votes
      from (select e.way, e.model, e.owner, e.at,
                   (select count(*) from public.challenge_votes v
                     where v.challenge = c.id and v.model = e.model
                       and not public.is_barred(v.voter) and not public.trust_kept_private(v.voter)) as votes
              from public.challenge_entries e
              join public.shared_models m on m.id = e.model
             where e.challenge = c.id and public.gallery_shows(m, true) and public.shown_publicly(e.owner)
               and e.model in (select k.model from public.challenge_keeps(c.id,
                     array(select x.model from public.challenge_entries x where x.challenge = c.id)) k where k.keeps)) t
     where t.votes > 0
     order by t.way, t.votes desc, t.at, t.model;
    update public.challenges x set settled_at = now() where x.id = c.id;
    return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- What anybody sees.

-- /challenge, as a page asked with [tests] shows it: the challenge
-- (challenge_shown), its rules and days, and its entries as gallery cards,
-- each with its group, when it was entered, whether it keeps the rules and,
-- once it has ended, its votes; the winners once settled. Null when there
-- is none. The same for everybody: who voted for what is challenge_mine's.
create or replace function public.challenge_page(tests boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    with c as (select s.* from public.challenge_shown(challenge_page.tests) s where s.id is not null),
    shown as materialized (
        select e.*, m as sm
          from c
          join public.challenge_entries e on e.challenge = c.id
          join public.shared_models m on m.id = e.model
         where public.gallery_shows(m, challenge_page.tests) and public.shown_publicly(e.owner)),
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

-- What [account] did in [challenge_id]: {voted: {hand, assistant} (the
-- model voted for in each, or null), entries: [models of theirs in it],
-- may_vote}. Only ever asked with the caller's own account.
create or replace function public.challenge_mine(account uuid, challenge_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'voted', jsonb_build_object(
            'hand', (select v.model from public.challenge_votes v
                      where v.challenge = challenge_mine.challenge_id and v.voter = challenge_mine.account and v.way = 'hand'),
            'assistant', (select v.model from public.challenge_votes v
                           where v.challenge = challenge_mine.challenge_id and v.voter = challenge_mine.account
                             and v.way = 'assistant')),
        'entries', coalesce((select jsonb_agg(e.model order by e.at) from public.challenge_entries e
                              where e.challenge = challenge_mine.challenge_id and e.owner = challenge_mine.account),
                            '[]'::jsonb),
        'may_vote', public.trust_may_go_public(challenge_mine.account) and not public.is_barred(challenge_mine.account),
        'under_13', public.trust_kept_private(challenge_mine.account))
$$;

-- The challenges won by [owner]'s models, or by any of [models]: {challenge,
-- title, ends_on, way, model, votes}, newest first; a test challenge's only
-- when [tests]. For a designer's page and the cards.
create or replace function public.challenge_wins(owner uuid default null, models text[] default null,
    tests boolean default false)
returns setof jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object('challenge', c.id, 'title', c.title, 'ends_on', c.ends_on, 'way', w.way,
                              'model', w.model, 'name', m.name, 'votes', w.votes)
      from public.challenge_winners w
      join public.challenges c on c.id = w.challenge
      join public.shared_models m on m.id = w.model
     where (w.owner = challenge_wins.owner or w.model = any (challenge_wins.models))
       and (not c.test or coalesce(challenge_wins.tests, false))
       and m.published and not m.barred
     order by c.ends_on desc, c.id desc, w.way desc
     limit 50
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.challenge_today() from public, anon, authenticated;
grant execute on function public.challenge_today() to service_role;
revoke all on function public.challenge_state(public.challenges) from public, anon, authenticated;
grant execute on function public.challenge_state(public.challenges) to service_role;
revoke all on function public.challenge_open(boolean) from public, anon, authenticated;
grant execute on function public.challenge_open(boolean) to service_role;
revoke all on function public.challenge_shown(boolean) from public, anon, authenticated;
grant execute on function public.challenge_shown(boolean) to service_role;
revoke all on function public.challenge_check(bigint, text) from public, anon, authenticated;
grant execute on function public.challenge_check(bigint, text) to service_role;
revoke all on function public.challenge_keeps(bigint, text[]) from public, anon, authenticated;
grant execute on function public.challenge_keeps(bigint, text[]) to service_role;
revoke all on function public.challenge_set(text, text, date, date, integer, text, text, jsonb, boolean, boolean) from public, anon, authenticated;
grant execute on function public.challenge_set(text, text, date, date, integer, text, text, jsonb, boolean, boolean) to service_role;
revoke all on function public.challenge_end(bigint) from public, anon, authenticated;
grant execute on function public.challenge_end(bigint) to service_role;
revoke all on function public.challenge_list(boolean) from public, anon, authenticated;
grant execute on function public.challenge_list(boolean) to service_role;
revoke all on function public.challenge_enter(uuid, text, text) from public, anon, authenticated;
grant execute on function public.challenge_enter(uuid, text, text) to service_role;
revoke all on function public.challenge_withdraw(uuid, text) from public, anon, authenticated;
grant execute on function public.challenge_withdraw(uuid, text) to service_role;
revoke all on function public.challenge_for_model(uuid, text) from public, anon, authenticated;
grant execute on function public.challenge_for_model(uuid, text) to service_role;
revoke all on function public.challenge_vote(uuid, bigint, text, boolean) from public, anon, authenticated;
grant execute on function public.challenge_vote(uuid, bigint, text, boolean) to service_role;
revoke all on function public.challenge_settle(bigint) from public, anon, authenticated;
grant execute on function public.challenge_settle(bigint) to service_role;
revoke all on function public.challenge_page(boolean) from public, anon, authenticated;
grant execute on function public.challenge_page(boolean) to service_role;
revoke all on function public.challenge_mine(uuid, bigint) from public, anon, authenticated;
grant execute on function public.challenge_mine(uuid, bigint) to service_role;
revoke all on function public.challenge_wins(uuid, text[], boolean) from public, anon, authenticated;
grant execute on function public.challenge_wins(uuid, text[], boolean) to service_role;
