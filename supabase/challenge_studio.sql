-- The open challenge's rules for the studio, 2026-11-23 (docs/MASTERPLAN.md,
-- unit challengestudio): the studio ticks a challenge's rules on the model
-- as it is built, and says what to change before it is published.
--
-- The site checks a model on the stored file (challenge_check): its parts
-- against most_parts, what it needs (model_needs) against the set's parts
-- kept with the challenge (challenge_set_parts), and its Tested mark. The
-- studio checks the same three on the model open, by the same rules ported
-- exactly (src/net/challenge_rules.gd, proven equal on 30 models x 3 rule
-- kinds by tools/challenge_rules_check.mjs). It needs the set's parts as
-- they were kept when the challenge was set: a set's inventory changes as
-- Rebrickable's does (the castle tests' 6075-2 was kept as 73, 88, 105 and
-- 99 lots on four days), so counting it again would tick what the site
-- refuses. Nothing gives them out today; this does.
--
--   challenge_set_lots(challenge_id)   [{part, colour, qty}] of challenge
--                                      [challenge_id]'s set, as kept, in
--                                      part and colour order; [] for a
--                                      challenge with no set rule; null for
--                                      no such challenge, or one that is
--                                      not open (only an open challenge's
--                                      rules are a studio's to tick)
--
-- Who may touch what: only the server, through the function here, security
-- definer and granted to the service role alone. No key a page has reads
-- the tables.
--
-- Only an addition, applied after challenges.sql and challenge_prompts.sql
-- (it reads challenge_state and the kind column): one new function. No
-- table, no row and no other function is changed.

create or replace function public.challenge_set_lots(challenge_id bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select case when c.id is null or public.challenge_state(c) <> 'open' then null
                else coalesce((select jsonb_agg(jsonb_build_object('part', s.part, 'colour', s.colour, 'qty', s.qty)
                                                order by s.part, s.colour)
                                 from public.challenge_set_parts s
                                where s.challenge = c.id), '[]'::jsonb) end
      from (select 1) one
      left join public.challenges c on c.id = challenge_set_lots.challenge_id
$$;

revoke all on function public.challenge_set_lots(bigint) from public, anon, authenticated;
grant execute on function public.challenge_set_lots(bigint) to service_role;
