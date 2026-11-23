-- The house's words say what each model is, not who or what designed it,
-- 2026-11-23 (aiprivate; the owner: nothing says a model was made with the
-- assistant unless its owner chose to show it).
--
-- made_with_shown.sql keeps the way fact, the ai-designed tag and the
-- gallery's filter quiet until a model's owner shows them. The house is the
-- owner's own account, and its words still said it in prose: 21 of its
-- models' descriptions ("Designed by Claude.", "Claude designed it from a
-- single sentence", "Designed with the assistant (Claude, in Brickworks)
-- and finished by hand.") and its profile's bio. This says each again
-- without that sentence, and nothing else of it changes; the LDraw
-- library's sets, which name their modellers, are not touched.
--
-- What it writes: shared_models.description of the 21 named models, each
-- only while it is the house's and still has the words below, and
-- people.bio of @brickworks only while it is house_shelf.sql's. Words the
-- owner has changed since are kept, and running it again changes nothing.
-- updated_at is left as it was, so no model moves up New. The search words
-- (directory_words, a generated column) follow the description. The
-- ai-designed tags stay: they are how the site knows privately, and
-- made_with_shown.sql keeps them off every public page.
--
-- To take it back: the "before" texts below, by id, and house_shelf.sql's bio.
--
-- Applied by the lead:
--
--   set -a; . ./.env; set +a
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js \
--     node tools/apply_sql.mjs supabase/house_words.sql --table=people
--
-- tried first, rolled back:
--
--   ... node tools/apply_sql.mjs supabase/house_words.sql --dry --again=supabase/house_words.sql \
--         --try=tools/house_words_try.sql --table=people

do $$
declare
    house uuid := (select p.account from public.people p where p.handle = 'brickworks');
    said integer;
begin
    if house is null then
        raise exception 'brickworks: the house has no profile';
    end if;

    update public.shared_models m
       set description = w.after
      from (values
        ('o3dLMc5A3Z',
         'A red sports car with white racing stripes and a black rear wing, and beside it its driver with a trophy and a nameplate. Designed by Claude.',
         'A red sports car with white racing stripes and a black rear wing, and beside it its driver with a trophy and a nameplate.'),
        ('cGHqpHnEFZ',
         'A corner building with a shop under a striped awning, a flat above and a cornice round the roof, on its own stretch of pavement. Designed by Claude, with a shopkeeper, a customer, a tenant and a passer-by.',
         'A corner building with a shop under a striped awning, a flat above and a cornice round the roof, on its own stretch of pavement, with a shopkeeper, a customer, a tenant and a passer-by.'),
        ('B6FhDpMowd',
         'A heavy-lift rocket of three cores side by side on its launch mount, with the strongback tower beside it and a pad technician for scale. Designed by Claude.',
         'A heavy-lift rocket of three cores side by side on its launch mount, with the strongback tower beside it and a pad technician for scale.'),
        ('uoRqCfPWYJ',
         'A barn owl perched on a post, its white face and tan wings shaped in layers of bricks and slopes, on a small base with leaves, flowers and a mouse. Designed by Claude.',
         'A barn owl perched on a post, its white face and tan wings shaped in layers of bricks and slopes, on a small base with leaves, flowers and a mouse.'),
        ('kfpYMjke5U',
         'A stone castle with four corner towers, a gatehouse and a paved courtyard, ringed by a moat. Claude designed it from a single sentence, as ten sub-assemblies you can build one at a time.',
         'A stone castle with four corner towers, a gatehouse and a paved courtyard, ringed by a moat, as ten sub-assemblies you can build one at a time.'),
        ('EzEXhtXE2C',
         'A black tower of four clustered piers, banded in grey and crowned with curved horns, with furnished rooms inside. Claude designed it from one paragraph; the grey wizard and the white wizard stand at the top, and two tower guards keep the stair.',
         'A black tower of four clustered piers, banded in grey and crowned with curved horns, with furnished rooms inside. The grey wizard and the white wizard stand at the top, and two tower guards keep the stair.'),
        ('8eb6GRvnSV',
         'A working orrery: one crank turns all eight planets round the Sun, each through a gear train of its own, and every planet''s year comes within 0.35% of NASA''s. A Claude session built it in Brickworks, finding each train with the app''s gear ratio search.',
         'A working orrery: one crank turns all eight planets round the Sun, each through a gear train of its own, and every planet''s year comes within 0.35% of NASA''s. Each gear train was found with the app''s gear ratio search.'),
        ('4PX3GV47LW',
         'A first build of 37 pieces in 11 steps: a round green cactus with two arms, banded in dark green, a pink flower on top and white tufts, in a reddish brown pot on a dark orange saucer. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A first build of 37 pieces in 11 steps: a round green cactus with two arms, banded in dark green, a pink flower on top and white tufts, in a reddish brown pot on a dark orange saucer.'),
        ('mQ4mK2Yfhc',
         'A minifigure camping scene: a green dome tent with its door open, a campfire ringed with stones and a cooking pot, log seats, a canoe pulled up on the sandy shore of a little lake with a fish, a tall pine and a signpost, and three campers, one toasting a marshmallow and one fishing. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A minifigure camping scene: a green dome tent with its door open, a campfire ringed with stones and a cooking pot, log seats, a canoe pulled up on the sandy shore of a little lake with a fish, a tall pine and a signpost, and three campers, one toasting a marshmallow and one fishing.'),
        ('rEBYGwnXdu',
         'A small green dragon asleep on a heap of gold: its head rests at the front with one eye open and its teeth showing, its folded wings and spined back rise over the hoard, and its tail curls round to the front. A goblet, gems, coins and a treasure chest lie on a dark grey cave floor. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A small green dragon asleep on a heap of gold: its head rests at the front with one eye open and its teeth showing, its folded wings and spined back rise over the hoard, and its tail curls round to the front. A goblet, gems, coins and a treasure chest lie on a dark grey cave floor.'),
        ('AiBS96ET2M',
         'A three-tier pagoda in dark red and white with dark grey roofs that sweep up at the corners and a gold spire, on a stone base with steps, in a garden with a blossoming cherry tree, a stone lantern, a pond with lily pads and a little red bridge, and a monk. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A three-tier pagoda in dark red and white with dark grey roofs that sweep up at the corners and a gold spire, on a stone base with steps, in a garden with a blossoming cherry tree, a stone lantern, a pond with lily pads and a little red bridge, and a monk.'),
        ('5gTFrkEYSd',
         'A little steam tank engine in black and dark red, with a tall chimney, a gold dome, side tanks and red wheels on connecting rods, its driver in the cab; behind it an open green coach with bench seats and a passenger, on its own length of track. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A little steam tank engine in black and dark red, with a tall chimney, a gold dome, side tanks and red wheels on connecting rods, its driver in the cab; behind it an open green coach with bench seats and a passenger, on its own length of track.'),
        ('rtqf6Xtpb4',
         'A small robot in white and orange on two tank tracks, with a domed head and big round eyes on a neck that turns, an antenna, a chest panel of lights, arms on joints ending in a claw and a spanner, and a toolbox on its back. Its head looks around as a motion in the app. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A small robot in white and orange on two tank tracks, with a domed head and big round eyes on a neck that turns, an antenna, a chest panel of lights, arms on joints ending in a claw and a spanner, and a toolbox on its back. Its head looks around as a motion in the app.'),
        ('3TbLHphFky',
         'A two-storey village bakery: tan brick below with a big shop window, its shelves and counter inside, a timber-framed white floor above with a flower box, a dark red roof and a chimney; outside a bench, a lamp post, a bicycle and a customer. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A two-storey village bakery: tan brick below with a big shop window, its shelves and counter inside, a timber-framed white floor above with a flower box, a dark red roof and a chimney; outside a bench, a lamp post, a bicycle and a customer.'),
        ('ruNnGL5CWX',
         'An eight-sided smock mill in dark tan and reddish brown on a white base, with a cap and four lattice sails: turn the crank at the back and the sails turn through a gear train. The miller stands at the door with a sack of flour, beside his cart. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'An eight-sided smock mill in dark tan and reddish brown on a white base, with a cap and four lattice sails: turn the crank at the back and the sails turn through a gear train. The miller stands at the door with a sack of flour, beside his cart.'),
        ('JaU2WdrqFV',
         'A six-wheeled moon rover in white and grey on rocker suspension, with a pressurised cab, a dish antenna, a solar panel and a robot arm with a scoop; one astronaut drives and one plants a flag, among craters, rocks and ice crystals. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A six-wheeled moon rover in white and grey on rocker suspension, with a pressurised cab, a dish antenna, a solar panel and a robot arm with a scoop; one astronaut drives and one plants a flag, among craters, rocks and ice crystals.'),
        ('j7WaRpWsuL',
         'A red fox sitting up on a mossy log: its body sculpted in orange with a white chest and muzzle, black socks and a bushy white-tipped tail, on a grassy base with toadstools, fallen leaves and a stick. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A red fox sitting up on a mossy log: its body sculpted in orange with a white chest and muzzle, black socks and a bushy white-tipped tail, on a grassy base with toadstools, fallen leaves and a stick.'),
        ('57f5AAf5ax',
         'A green farm tractor with red wheels, a grille and headlamps, gauges and a tall exhaust, its farmer at the wheel, towing a two-wheeled trailer of hay bales with a pitchfork. Every axle turns and the trailer swings on a tow ball. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A green farm tractor with red wheels, a grille and headlamps, gauges and a tall exhaust, its farmer at the wheel, towing a two-wheeled trailer of hay bales with a pitchfork. Every axle turns and the trailer swings on a tow ball.'),
        ('r2UCzQ7Pz3',
         'A big old oak with a sculpted trunk and a leafy canopy, carrying two wooden huts at different heights joined by a rope bridge, with a ladder, a slide, a swing, a pulley and bucket and a lookout with a telescope and flag; a family of five plays among the roots and flowers. Designed with the assistant (Claude, in Brickworks) and finished by hand.',
         'A big old oak with a sculpted trunk and a leafy canopy, carrying two wooden huts at different heights joined by a rope bridge, with a ladder, a slide, a swing, a pulley and bucket and a lookout with a telescope and flag; a family of five plays among the roots and flowers.'),
        ('McbNR9ci77',
         'A corner to read in: a shelf of books, a lamp, a bed under the eaves.

The house''s entry for this week''s quick build, Habitat. Designed by Claude for Brickworks.',
         'A corner to read in: a shelf of books, a lamp, a bed under the eaves.

The house''s entry for this week''s quick build, Habitat.'),
        ('Vpb5yxr76A',
         'A red-roofed shed with a door left open, a path of stones, a tree and flowers.

The house''s entry for this week''s quick build, Habitat. Designed by Claude for Brickworks.',
         'A red-roofed shed with a door left open, a path of stones, a tree and flowers.

The house''s entry for this week''s quick build, Habitat.')
           ) as w(id, before, after)
     where m.id = w.id and m.owner = house and m.author = 'Brickworks' and m.description = w.before;
    get diagnostics said = row_count;
    raise notice 'house words: % model descriptions said again', said;

    update public.people
       set bio = 'The Brickworks studio''s own account: its own models, and the collection From the LDraw library, real sets as LDraw''s builders modelled them, each credited to them. Open one to build it step by step.',
           updated_at = now()
     where account = house
       and bio = 'The Brickworks studio''s own account. Its own models were designed with the assistant, Claude working in the app, and each one''s description says how. The collection From the LDraw library holds real sets as LDraw''s builders modelled them, each credited to them. Open one to build it step by step.';
    get diagnostics said = row_count;
    raise notice 'house words: % bio said again', said;
end
$$;
