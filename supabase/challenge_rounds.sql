-- Judges, a fan vote, honours (challengehonours, 2026-11-22; docs/SOCIAL.md,
-- the units in waves, rank 3).
--
-- A challenge could only run one way: entries and votes together, the most
-- voted winning. LEGO Ideas and BrickLink run a judged round, then a fan
-- vote. Now a challenge may run in two rounds:
--
--   entries   from its first day to entries_until: models come in, as now
--   judging   entries closed: the owner, or a guest judge the owner names,
--             chooses a shortlist of up to five in each group, on /admin
--   fan vote  from votes_from, once the shortlist is out, to its last day:
--             one vote in each group, for a shortlisted entry only, hidden
--             until it ends, as every vote is
--
-- A challenge with no entries_until runs as it always did. The rules, the
-- blind vote and who may enter or vote are unchanged: the round is checked
-- first, then challenges.sql's own functions decide as they always have.
--
-- And for every challenge: its winners are This week's pick the week after
-- it ends (gallery_picks, discovery.sql), the most voted first, a week
-- each, and a cover the owner chooses (a model in the gallery) is its own
-- picture where it is shared.
--
-- Only additions, applied after challenges.sql, challenge_year.sql,
-- discovery.sql and trust.sql:
--
--   challenges.entries_until, .votes_from   the rounds' days (both or none)
--   challenges.judge_name, .judge_account   the guest judge named on the page
--   challenges.cover_model                  its picture where it is shared
--   challenges.shortlisted_at               when the shortlist came out
--   challenge_shortlist                     the shortlist, deleted with its
--                                           entry (and so with the account)
--
-- New functions, each the service role's alone and, but for the helper
-- challenge_round, security definer:
--
--   challenge_round(c)            entries, judging or vote; null for one round
--   challenge_rounds_set(...)     the owner's: rounds, judge and cover
--   challenge_shortlist_set(...)  the owner's: the shortlist, all at once
--   challenge_rounds_of(id)       what the page says of them
--   challenge_enter_round(...)    challenge_enter, once entries are open
--   challenge_vote_round(...)     challenge_vote, in the fan round, for the
--                                 shortlist alone
--   challenge_settle_rounds(id)   challenge_settle, counting the shortlist
--                                 alone, and the winners made the pick
--   challenge_settle_due(tests)   every challenge ended and not yet counted,
--                                 counted
--
-- No function replaced, no row changed, nothing dropped or renamed. The API
-- asks the new ones and, before this file, the old ones as it always did.

alter table public.challenges add column if not exists entries_until date;
alter table public.challenges add column if not exists votes_from date;
alter table public.challenges add column if not exists judge_name text;
alter table public.challenges add column if not exists judge_account uuid references auth.users (id) on delete set null;
alter table public.challenges add column if not exists cover_model text references public.shared_models (id) on delete set null;
alter table public.challenges add column if not exists shortlisted_at timestamptz;

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'challenges_rounds_days') then
        alter table public.challenges add constraint challenges_rounds_days check (
            (entries_until is null and votes_from is null)
            or (entries_until is not null and votes_from is not null and entries_until >= starts_on
                and votes_from > entries_until and votes_from <= ends_on));
    end if;
    if not exists (select 1 from pg_constraint where conname = 'challenges_judge_name') then
        alter table public.challenges add constraint challenges_judge_name check (
            judge_name is null or char_length(judge_name) between 1 and 60);
    end if;
    if not exists (select 1 from pg_constraint where conname = 'challenges_judge_named') then
        alter table public.challenges add constraint challenges_judge_named check (
            judge_account is null or judge_name is not null);
    end if;
end;
$$;

comment on column public.challenges.entries_until is
    'The last day entries come in, when it runs in rounds (supabase/challenge_rounds.sql); null: one round.';
comment on column public.challenges.votes_from is
    'The first day of the fan vote, once the shortlist is out (supabase/challenge_rounds.sql).';

create table if not exists public.challenge_shortlist (
    challenge  bigint not null,
    model      text not null,
    way        text not null check (way in ('hand', 'assistant')),
    at         timestamptz not null default now(),
    primary key (challenge, model),
    foreign key (challenge, model) references public.challenge_entries (challenge, model) on delete cascade
);
create index if not exists challenge_shortlist_way on public.challenge_shortlist (challenge, way);
alter table public.challenge_shortlist enable row level security;
revoke all on public.challenge_shortlist from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Where a challenge in rounds is.

-- [c]'s round while it is open: 'entries' to entries_until, 'vote' from
-- votes_from once the shortlist is out, 'judging' between; its state
-- (upcoming, ended) when it is not open; null for a challenge in one round.
create or replace function public.challenge_round(c public.challenges)
returns text
language sql
stable
set search_path = public
as $$
    select case when c.entries_until is null then null
                when public.challenge_state(c) <> 'open' then public.challenge_state(c)
                when public.challenge_today() <= c.entries_until then 'entries'
                when public.challenge_today() >= c.votes_from and c.shortlisted_at is not null then 'vote'
                else 'judging' end
$$;

-- ---------------------------------------------------------------------------
-- The owner's.

-- [challenge_id]'s rounds, guest judge and cover, all given each time (null:
-- none): {set, rounds}, or {refused} with why:
--
--   no_challenge   none by that number
--   ended          it has ended
--   days           the days are not both given, or not entries_until on
--                  or after its first day and votes_from after it and on or
--                  before its last
--   voting         the fan vote is open: its days stay as they are
--   shortlisted    rounds taken off with a shortlist out
--   no_judge       a judge's handle no profile shown in public has
--   judge_name     a judge's name over 60 characters, or a handle with none
--   cover          a cover that is not a model in the gallery
create or replace function public.challenge_rounds_set(challenge_id bigint, entries_until date default null,
    votes_from date default null, judge_name text default null, judge_handle text default null,
    cover_model text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.challenges;
    judge uuid;
    named text := nullif(btrim(coalesce(challenge_rounds_set.judge_name, '')), '');
    m public.shared_models;
begin
    select * into c from public.challenges x where x.id = challenge_rounds_set.challenge_id for update;
    if not found then
        return jsonb_build_object('refused', 'no_challenge');
    end if;
    if public.challenge_state(c) = 'ended' then
        return jsonb_build_object('refused', 'ended');
    end if;
    if (challenge_rounds_set.entries_until is null) <> (challenge_rounds_set.votes_from is null)
       or (challenge_rounds_set.entries_until is not null
           and (challenge_rounds_set.entries_until < c.starts_on
                or challenge_rounds_set.votes_from <= challenge_rounds_set.entries_until
                or challenge_rounds_set.votes_from > c.ends_on)) then
        return jsonb_build_object('refused', 'days');
    end if;
    if public.challenge_round(c) = 'vote'
       and (c.entries_until is distinct from challenge_rounds_set.entries_until
            or c.votes_from is distinct from challenge_rounds_set.votes_from) then
        return jsonb_build_object('refused', 'voting');
    end if;
    if challenge_rounds_set.entries_until is null
       and exists (select 1 from public.challenge_shortlist s where s.challenge = c.id) then
        return jsonb_build_object('refused', 'shortlisted');
    end if;
    if nullif(btrim(coalesce(challenge_rounds_set.judge_handle, '')), '') is not null then
        select p.account, coalesce(named, p.name) into judge, named
          from public.people p
         where p.handle = lower(btrim(challenge_rounds_set.judge_handle)) and public.shown_publicly(p.account);
        if judge is null then
            return jsonb_build_object('refused', 'no_judge');
        end if;
    end if;
    if named is not null and char_length(named) > 60 then
        return jsonb_build_object('refused', 'judge_name');
    end if;
    if challenge_rounds_set.cover_model is not null then
        select * into m from public.shared_models s where s.id = challenge_rounds_set.cover_model;
        if not found or not public.gallery_shows(m, c.test) then
            return jsonb_build_object('refused', 'cover');
        end if;
    end if;
    update public.challenges x
       set entries_until = challenge_rounds_set.entries_until, votes_from = challenge_rounds_set.votes_from,
           judge_name = named, judge_account = judge, cover_model = challenge_rounds_set.cover_model
     where x.id = c.id;
    return jsonb_build_object('set', true, 'rounds', public.challenge_rounds_of(c.id));
end;
$$;

-- [challenge_id]'s shortlist, all at once: [models] (none clears it), up to
-- five in each group, each an entry shown and keeping the rules. {shortlist:
-- [{model, way}], round}, or {refused} with why:
--
--   no_challenge   none by that number
--   not_rounds     it runs in one round
--   entries_open   entries are still coming in (or it has not opened)
--   voting         the fan vote is open: the shortlist stays as it is
--   ended          it has ended
--   too_many       more than five in a group ({way})
--   not_entry      not an entry shown in it ({model})
--   breaks         it no longer keeps the rules ({model})
create or replace function public.challenge_shortlist_set(challenge_id bigint, models text[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.challenges;
    wanted text[] := array(select distinct x from unnest(coalesce(challenge_shortlist_set.models, '{}'::text[])) x
                            where x is not null);
    one text;
    e public.challenge_entries;
    m public.shared_models;
    crowded text;
begin
    select * into c from public.challenges x where x.id = challenge_shortlist_set.challenge_id for update;
    if not found then
        return jsonb_build_object('refused', 'no_challenge');
    end if;
    if c.entries_until is null then
        return jsonb_build_object('refused', 'not_rounds');
    end if;
    if public.challenge_state(c) = 'ended' then
        return jsonb_build_object('refused', 'ended');
    end if;
    if public.challenge_round(c) in ('upcoming', 'entries') then
        return jsonb_build_object('refused', 'entries_open', 'entries_until', c.entries_until);
    end if;
    if public.challenge_round(c) = 'vote' then
        return jsonb_build_object('refused', 'voting');
    end if;
    foreach one in array wanted loop
        select * into e from public.challenge_entries x where x.challenge = c.id and x.model = one;
        select * into m from public.shared_models s where s.id = one;
        if e.model is null or m.id is null or not public.gallery_shows(m, true) or not public.shown_publicly(e.owner) then
            return jsonb_build_object('refused', 'not_entry', 'model', one);
        end if;
        if not coalesce((public.challenge_check(c.id, one)->>'ok')::boolean, false) then
            return jsonb_build_object('refused', 'breaks', 'model', one);
        end if;
    end loop;
    select x.way into crowded from public.challenge_entries x
     where x.challenge = c.id and x.model = any (wanted)
     group by x.way having count(*) > 5 limit 1;
    if crowded is not null then
        return jsonb_build_object('refused', 'too_many', 'way', crowded);
    end if;
    delete from public.challenge_shortlist s where s.challenge = c.id;
    insert into public.challenge_shortlist (challenge, model, way)
    select c.id, x.model, x.way from public.challenge_entries x where x.challenge = c.id and x.model = any (wanted);
    update public.challenges x set shortlisted_at = case when cardinality(wanted) > 0 then now() end where x.id = c.id;
    select * into c from public.challenges x where x.id = c.id;
    return jsonb_build_object('shortlist', coalesce((select jsonb_agg(jsonb_build_object('model', s.model, 'way', s.way)
                                                                       order by s.way desc, s.model)
                                                       from public.challenge_shortlist s where s.challenge = c.id), '[]'::jsonb),
                              'round', public.challenge_round(c));
end;
$$;

-- ---------------------------------------------------------------------------
-- What anybody sees.

-- What [challenge_id]'s page says of its rounds, judge and cover: {rounds,
-- entries_until, votes_from, round, shortlisted_at, shortlist: [{model,
-- way}] once it is out, judge: {name, handle} | null (the handle only while
-- the judge's profile is shown in public), cover: a gallery card | null}.
-- Null for none by that number. Asked only of a challenge its page may show
-- (challenge_page_at said so first).
create or replace function public.challenge_rounds_of(challenge_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select jsonb_build_object(
        'rounds', c.entries_until is not null,
        'entries_until', c.entries_until, 'votes_from', c.votes_from,
        'round', public.challenge_round(c), 'shortlisted_at', c.shortlisted_at,
        'shortlist', case when c.shortlisted_at is null then '[]'::jsonb else coalesce(
            (select jsonb_agg(jsonb_build_object('model', s.model, 'way', s.way) order by s.way desc, s.at, s.model)
               from public.challenge_shortlist s
               join public.challenge_entries e on e.challenge = s.challenge and e.model = s.model
               join public.shared_models m on m.id = s.model
              where s.challenge = c.id and public.gallery_shows(m, c.test) and public.shown_publicly(e.owner)),
            '[]'::jsonb) end,
        'judge', case when c.judge_name is null then null else jsonb_build_object('name', c.judge_name,
            'handle', (select p.handle from public.people p
                        where p.account = c.judge_account and public.shown_publicly(p.account))) end,
        'cover', (select public.directory_card(m) from public.shared_models m
                   where m.id = c.cover_model and public.gallery_shows(m, c.test)))
      from public.challenges c
     where c.id = challenge_rounds_of.challenge_id
$$;

-- ---------------------------------------------------------------------------
-- Entering and voting, by the round.

-- challenge_enter, refused 'closed' ({challenge, entries_until, votes_from})
-- once the entries of the challenge it would enter have closed.
create or replace function public.challenge_enter_round(account uuid, model_id text, way text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    m public.shared_models;
    c public.challenges;
begin
    select * into m from public.shared_models s where s.id = challenge_enter_round.model_id;
    if found then
        c := public.challenge_open(m.test);
        if c.id is not null and c.entries_until is not null and public.challenge_today() > c.entries_until then
            return jsonb_build_object('refused', 'closed', 'challenge', c.id, 'entries_until', c.entries_until,
                                      'votes_from', c.votes_from);
        end if;
    end if;
    return public.challenge_enter(challenge_enter_round.account, challenge_enter_round.model_id, challenge_enter_round.way);
end;
$$;

-- challenge_vote, in a challenge in rounds only in the fan round and only
-- for a shortlisted entry: refused 'not_yet' ({round, votes_from}) before
-- it, 'not_shortlisted' for an entry not on the shortlist.
create or replace function public.challenge_vote_round(account uuid, challenge_id bigint, model_id text,
    tests boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.challenges;
begin
    select * into c from public.challenges x where x.id = challenge_vote_round.challenge_id;
    if found and c.entries_until is not null and public.challenge_state(c) = 'open'
       and c.test = coalesce(challenge_vote_round.tests, false) then
        if public.challenge_round(c) <> 'vote' then
            return jsonb_build_object('refused', 'not_yet', 'round', public.challenge_round(c), 'votes_from', c.votes_from);
        end if;
        if not exists (select 1 from public.challenge_shortlist s
                        where s.challenge = c.id and s.model = challenge_vote_round.model_id) then
            return jsonb_build_object('refused', 'not_shortlisted');
        end if;
    end if;
    return public.challenge_vote(challenge_vote_round.account, challenge_vote_round.challenge_id,
                                 challenge_vote_round.model_id, challenge_vote_round.tests);
end;
$$;

-- ---------------------------------------------------------------------------
-- When it ends.

-- challenge_settle's count, word for word, with one rule more: in a
-- challenge in rounds only a shortlisted entry is counted. Then its
-- winners are This week's pick the week after it ended, the most voted
-- first (a tie to by hand), a week each from the moment it ended; a week
-- already gone by when it is counted is skipped. True when it was settled
-- now.
create or replace function public.challenge_settle_rounds(challenge_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    c public.challenges;
    w public.challenge_winners;
    ended timestamptz;
    week integer := 0;
    week_from timestamptz;
begin
    select * into c from public.challenges x where x.id = challenge_settle_rounds.challenge_id for update;
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
               and (c.entries_until is null
                    or exists (select 1 from public.challenge_shortlist s where s.challenge = c.id and s.model = e.model))
               and e.model in (select k.model from public.challenge_keeps(c.id,
                     array(select x.model from public.challenge_entries x where x.challenge = c.id)) k where k.keeps)) t
     where t.votes > 0
     order by t.way, t.votes desc, t.at, t.model;
    update public.challenges x set settled_at = now() where x.id = c.id;
    ended := least(coalesce(c.ended_at, 'infinity'::timestamptz), ((c.ends_on + 1)::timestamp at time zone 'utc'));
    for w in select * from public.challenge_winners x where x.challenge = c.id order by x.votes desc, x.way desc loop
        week_from := ended + make_interval(days => 7 * week);
        if week_from + interval '7 days' > now() + interval '1 hour' then
            insert into public.gallery_picks (model, chosen_at, until)
            values (w.model, greatest(now(), week_from), week_from + interval '7 days');
        end if;
        week := week + 1;
    end loop;
    return true;
end;
$$;

-- Every challenge of [tests]'s kind that ended and was never counted,
-- counted now (challenge_settle_rounds), at most five at once: how many.
-- The home page asks it, so the winners are the pick the week after even
-- when nobody opens the challenge's own page.
create or replace function public.challenge_settle_due(tests boolean default false)
returns integer
language sql
security definer
set search_path = public
as $$
    select count(*)::integer from (
        select public.challenge_settle_rounds(c.id) as done
          from public.challenges c
         where c.test = coalesce(challenge_settle_due.tests, false) and c.settled_at is null
           and public.challenge_state(c) = 'ended'
         order by c.ends_on desc, c.id desc
         limit 5) x
     where x.done
$$;

-- ---------------------------------------------------------------------------
-- Grants: the service role alone.

revoke all on function public.challenge_round(public.challenges) from public, anon, authenticated;
grant execute on function public.challenge_round(public.challenges) to service_role;
revoke all on function public.challenge_rounds_set(bigint, date, date, text, text, text) from public, anon, authenticated;
grant execute on function public.challenge_rounds_set(bigint, date, date, text, text, text) to service_role;
revoke all on function public.challenge_shortlist_set(bigint, text[]) from public, anon, authenticated;
grant execute on function public.challenge_shortlist_set(bigint, text[]) to service_role;
revoke all on function public.challenge_rounds_of(bigint) from public, anon, authenticated;
grant execute on function public.challenge_rounds_of(bigint) to service_role;
revoke all on function public.challenge_enter_round(uuid, text, text) from public, anon, authenticated;
grant execute on function public.challenge_enter_round(uuid, text, text) to service_role;
revoke all on function public.challenge_vote_round(uuid, bigint, text, boolean) from public, anon, authenticated;
grant execute on function public.challenge_vote_round(uuid, bigint, text, boolean) to service_role;
revoke all on function public.challenge_settle_rounds(bigint) from public, anon, authenticated;
grant execute on function public.challenge_settle_rounds(bigint) to service_role;
revoke all on function public.challenge_settle_due(boolean) from public, anon, authenticated;
grant execute on function public.challenge_settle_due(boolean) to service_role;
