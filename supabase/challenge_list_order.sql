-- The admin's challenges, the ones not yet ended first, 2026-10-25.
--
-- challenge_list (challenge_year.sql) listed every challenge newest first,
-- at most 24. Once a year of themes was planned (ids 107-119, each a month
-- ahead) and every browser run left an ended test challenge in a coming
-- month, those filled the 24 rows: the challenge open now, the next to open
-- and a test challenge a run had left open were in none of them. /admin
-- showed no End it now for the open one, and tools/web/challenges_flow.mjs
-- could neither end what a run had left open nor see the one it had just
-- set ("the challenge listed: not within 30 s").
--
--   challenge_list   the same rows, the same columns, at most 24, in this
--                    order: open, then upcoming by their first day, then
--                    ended, newest first
--
-- Only a function replaced, applied after challenge_year.sql: the same name
-- and arguments, so api/admin.js reads it as before. Security definer and
-- the service role's alone. No table or row is changed, nothing dropped or
-- renamed. Applying challenge_year.sql again alone would put the newest-first
-- order back: tools/apply_sql.mjs refuses it (supabase/later.tsv), unless
-- --again=supabase/challenge_list_order.sql.

-- REPLACES challenge_year.sql's: the same rows, the ones not yet ended first:
-- the open one, then the coming ones by their first day, so a year planned
-- ahead lists the next before the last, then the ended ones, newest first.
-- {id, title, brief, starts_on, ends_on, announced_at, state, rules, test,
-- entries: {hand, assistant}, votes: {hand, assistant}, winners}.
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
     order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end,
              case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc,
              c.starts_on desc, c.id desc
     limit 24
$$;

revoke all on function public.challenge_list(boolean) from public, anon, authenticated;
grant execute on function public.challenge_list(boolean) to service_role;
