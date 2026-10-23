-- The house's profile, 2026-10-22 (docs/SOCIAL.md U10, D12).
--
-- Every model in the live gallery was shared by one account, the studio's
-- own (an address at brickworks.diy), and credited "Brickworks"; each was
-- designed with the assistant, and its description says so ("Designed by
-- Claude"). The account had no profile, so no card linked anywhere, the
-- feed had no designer to suggest and a first visit met nobody. This gives
-- it one, at https://brickworks.diy/u/brickworks: the studio's name, words
-- that say plainly whose account it is and that its models were made with
-- the assistant, the castle's picture across the top and three models
-- pinned. Nothing about it pretends to be a person: its name is the
-- studio's, its words say whose account it is, and its avatar is the
-- letter made from the handle (web/card.js avatarHtml). Its page is drawn
-- as every person's is (tests/test_profile.py holds that).
--
-- The handle is kept for Brickworks itself: the API refuses it to anybody
-- (api/_names.js RESERVED), so only this file gives it, and only to the
-- account whose listed models are credited "Brickworks".
--
-- What it writes, each only when it is not there already, so it can be
-- run again and changes nothing the second time:
--
--   profiles      the age question answered for the account, 13 or over
--                 (trust.sql answer_age): the studio's account is run by
--                 the site's owner, and no profile may be made without
--                 that answer. An answer already given stands.
--   people        the profile: handle brickworks, name Brickworks, the bio
--   profile_shows the banner and the pins: only models of the house's,
--                 published and listed
--
-- No model is changed: not a name, a credit, a tag, a word. No row of
-- anybody else's is read or written. Nothing is dropped or replaced. To
-- take it back: delete the house's rows from profile_shows and people
-- (its models are untouched either way, and go back to a credit with no
-- link).
--
-- Applied after trust.sql, people.sql and profile_shows.sql, by the lead:
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/house.sql --table=people
--
-- and tried first, run twice and rolled back:
--
--   ... node tools/apply_sql.mjs supabase/house.sql --dry --again=supabase/house.sql \
--         --try=tools/house_try.sql --table=people

do $$
declare
    house uuid;
    owners integer;
    -- The castle's picture is wide: it fills the band across the top. The
    -- tower, the orrery and the shop are what the studio's work is.
    wanted_banner constant text := 'kfpYMjke5U';
    wanted_pins constant text[] := array['EzEXhtXE2C', '8eb6GRvnSV', 'cGHqpHnEFZ'];
    pins text[];
    banner text;
begin
    -- The house: the one account whose listed models are credited
    -- "Brickworks", at the studio's own address.
    select count(distinct m.owner), (array_agg(distinct m.owner))[1]
      into owners, house
      from public.shared_models m
     where m.author = 'Brickworks' and m.listed and m.published and not m.barred and not m.test;
    if owners is distinct from 1 then
        raise exception 'brickworks: the house is the one account whose listed models are credited "Brickworks"; there are %', owners;
    end if;
    if not exists (select 1 from auth.users u where u.id = house and lower(u.email) like '%@brickworks.diy') then
        raise exception 'brickworks: the account credited "Brickworks" is not at brickworks.diy: not the house';
    end if;
    if exists (select 1 from public.people p where p.handle = 'brickworks' and p.account <> house) then
        raise exception 'brickworks: another account has the handle brickworks';
    end if;

    -- 13 or over, as every public profile must say first. A standing
    -- answer is kept as it is (answer_age asks only an account never asked).
    perform public.answer_age(house, true);

    insert into public.people (account, handle, name, bio)
    values (house, 'brickworks', 'Brickworks',
            'The Brickworks studio''s own account. Every model here was designed with the assistant, '
            || 'Claude working in the app, and each one''s description says how. Open one to build it '
            || 'step by step, or remix it as your own.')
    on conflict (account) do nothing;

    -- Only the house's own models, published and listed, in the order above.
    select array_agg(m.id order by array_position(wanted_pins, m.id))
      into pins
      from public.shared_models m
     where m.id = any(wanted_pins) and m.owner = house and m.published and m.listed and not m.barred;
    select m.id into banner
      from public.shared_models m
     where m.id = wanted_banner and m.owner = house and m.published and m.listed and not m.barred and m.has_image;
    insert into public.profile_shows (account, banner, pins)
    values (house, banner, coalesce(pins, '{}'))
    on conflict (account) do nothing;
end
$$;
