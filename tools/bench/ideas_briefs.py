"""The ideas bench's briefs: complex original ideas, in the words a person types them.

The owner never asks for a set by its name. They bring an idea of their own,
a scene, a vehicle, a building or a creature with several things in it, a
setting and a size, and judge what comes back as a LEGO® set designer would.
tools/bench/realset.py briefs a real set's name ("Robin, in the style of
LEGO® BrickHeadz sets"), and its verdicts turned on how a name was read: one
session built a bird for a BrickHeadz figure, another spelled out a word on a
buggy's sign. These twenty are what tools/bench/ideas.py runs instead.

Written 2026-10-27 to the owner's own published titles on brickworks.diy ("A
treehouse in an old oak", "A little dragon asleep on its hoard", "Orrery of
the Sun and eight planets", "A moon rover and its crew", "Wizard's Tower"):
fantasy, nature, mechanisms and vehicles with people in them. No real set's
name and no licensed character; a real place only as what inspired an
original. The size is given where a person would give one, in studs, pieces
or centimetres, and left to the designer where they would not. The kinds
take turns, so `--first N` is a spread too.

**The briefs are fixed.** Change a brief's words and every score of it before
is a score of something else: add a brief under a new id instead. Each design
keeps the words it was given (record.json's `brief`), and `ideas.py compare`
leaves out a pair whose words are not the brief's today.
"""

from __future__ import annotations

from dataclasses import dataclass

KINDS = ("fantasy scene", "sci-fi scene", "vehicle with a story", "landmark-inspired original",
         "creature or mech", "interior", "diorama", "Technic machine")


@dataclass(frozen=True, slots=True)
class Idea:
    id: str
    kind: str       # one of KINDS
    title: str
    brief: str      # exactly what the session is asked, as a person would type it


IDEAS: tuple[Idea, ...] = (
    Idea("dragon_bridge", "fantasy scene", "a dragon asleep under a stone bridge",
         "An old stone bridge over a river gorge with a dragon sleeping curled up under the "
         "main arch. At the near end there's a little toll house with a lantern and a grumpy "
         "troll toll keeper, and on the far side a knight's horse is tied to a tree while the "
         "knight tiptoes across. Minifig scale, about 32 x 16 studs, 600-800 pieces."),
    Idea("taco_truck", "vehicle with a story", "a beat-up taco truck at the beach",
         "A taco truck that's seen better days, parked at the beach for the evening rush. "
         "Serving hatch open with a menu board and a striped awning, string lights running "
         "over to a palm tree, two folding tables with chairs, and the owner's surfboard "
         "strapped to the roof. Minifig scale, 8 studs wide, about 450 pieces."),
    Idea("salvage_mech", "creature or mech", "a deep-sea salvage mech",
         "A deep-sea salvage mech: two stubby legs, a round bubble cockpit with a pilot "
         "inside, a big crushing claw on one arm and a cutting torch on the other, floodlights "
         "on the shoulders and a winch with a cable on its back. Weathered yellow and grey. It "
         "should pose at the hips, knees and arms. About 20 cm tall, 400-600 pieces."),
    Idea("ramen_shop", "interior", "a back-street ramen shop at night",
         "A tiny ramen shop on a Tokyo back street at night: a counter with six stools, the "
         "cook behind it with steaming pots, a cloth curtain over the door, red paper "
         "lanterns, a drinks vending machine outside and a bike parked by the door. The cook's "
         "little flat upstairs with a balcony. Minifig scale on a 16 x 16 footprint, 500-700 "
         "pieces."),
    Idea("cliff_monastery", "landmark-inspired original", "a monastery on a rock pillar",
         "A monastery perched on top of a tall rock pillar, like the ones at Meteora in "
         "Greece but my own: whitewashed walls, terracotta roofs, a little bell tower, and a "
         "basket on a rope winch hanging down the cliff for hauling up supplies, with a "
         "winding stair cut into the rock on one side. A microscale display about 30 cm tall "
         "on a 16 x 16 base."),
    Idea("autumn_mill", "diorama", "a covered bridge and watermill in autumn",
         "An autumn diorama: a red covered bridge over a creek with an old watermill beside "
         "it whose wheel actually turns, orange, red and yellow trees, a fisherman on the "
         "bank, and a fox watching from the rocks. On a raised rocky base about 24 x 24 studs, "
         "around 700 pieces."),
    Idea("excavator", "Technic machine", "a tracked excavator with working functions",
         "A tracked excavator, Technic style, with real functions: the upper body turns on "
         "the tracks, the boom and arm move on linear actuators, and the bucket curls. "
         "Yellow with black and grey, a cab with a seat and levers, studless. About 35 cm "
         "long with the arm out, 700-900 pieces."),
    Idea("mars_outpost", "sci-fi scene", "a research outpost on Mars",
         "A small research base on Mars: a glass dome greenhouse with plants growing inside, "
         "a habitat module joined to it by an airlock, a row of solar panels, a comms dish, "
         "and a six-wheeled rover parked outside with two astronauts. Red-orange ground with "
         "rocks and a little crater. Minifig scale on a 32 x 32 base, around 800 pieces."),
    Idea("chameleon", "creature or mech", "a chameleon catching a fly",
         "A chameleon on a twisty branch, catching a fly with its tongue shot out. Curled "
         "tail, turret eyes, bright green with orange and blue stripes. A display piece about "
         "30 cm long on a stand with a little nameplate, 500-700 pieces."),
    Idea("sky_pirate_airship", "vehicle with a story", "a sky pirates' airship",
         "A sky pirates' airship: a wooden ship's hull hanging under a big patched-up "
         "striped balloon, brass propellers on both sides, a captain's wheel and a crow's "
         "nest, a cannon poking out the side and a rope ladder dangling below. Room for a "
         "crew of four minifigs. About 40 studs long, 900-1100 pieces."),
    Idea("wizard_library", "interior", "a wizard's round tower library",
         "The inside of a wizard's library in a round tower room: bookshelves curving up two "
         "floors, a spiral staircase, a reading desk with a glowing crystal ball, a telescope "
         "at the window, potions on a shelf and a cat asleep on a stack of books. Open at the "
         "back like a dollhouse so you can see in. Minifig scale, about 600 pieces."),
    Idea("ice_fishing", "diorama", "an ice-fishing shack on a frozen lake",
         "A frozen lake at dusk: a little ice-fishing shack with a stovepipe and a warm light "
         "in the window, a snowmobile parked outside, a hole in the ice with a line in it, a "
         "snowman, and a couple of snowy pine trees. Small, on a 16 x 16 base, 250-350 "
         "pieces."),
    Idea("grand_station", "landmark-inspired original", "a grand old railway station",
         "A grand old railway station inspired by the big European ones like Antwerp and "
         "Paris Gare du Nord, but my own design: a stone front with a huge arched window, a "
         "clock tower on one side, and an iron-and-glass arched train shed behind it over "
         "three platforms. Architecture-style microscale, about 32 x 16 studs, 500-700 "
         "pieces."),
    Idea("retro_robot", "creature or mech", "a 1950s toy robot",
         "A big friendly 1950s-style toy robot: a boxy body with a chest panel full of dials "
         "and lights, a dome head with an antenna and round eyes, pincer hands, and tank "
         "treads instead of feet. Silver and red. The head and arms should turn. About 25 cm "
         "tall."),
    Idea("ferris_wheel", "Technic machine", "a hand-cranked fairground Ferris wheel",
         "A fairground Ferris wheel you turn with a crank at the base: six gondolas that hang "
         "level as it goes round, coloured lights along the spokes, a ticket booth and a "
         "queue fence at the bottom, and a couple of minifigs riding. About 30 cm tall, "
         "600-800 pieces."),
    Idea("starship_bridge", "sci-fi scene", "the bridge of an exploration starship",
         "The command bridge of a big exploration starship: the captain's chair in the "
         "middle on a raised step, two pilot consoles up front facing a huge curved "
         "viewscreen full of stars, side stations with screens and buttons, and a sliding "
         "door at the back. Built as a room with the back and one side open for display. "
         "Minifig scale, about 32 x 24 studs."),
    Idea("sea_serpent", "creature or mech", "a sea serpent and a rowing boat",
         "A sea serpent bursting out of the waves next to a little rowing boat: long green "
         "and teal coils with fins going in and out of the water, its head reared up with "
         "its mouth open, and two terrified fishermen in the boat. Lots of splashing water in "
         "clear blue and white. A display piece on about a 16 x 32 base, 500-700 pieces."),
    Idea("scooter_sidecar", "vehicle with a story", "a vintage scooter with a sidecar and a dog",
         "A vintage Italian-style scooter with a sidecar, pastel mint green with lots of "
         "chrome, a wicker basket on the back with a baguette and flowers, and a little dog "
         "in goggles riding in the sidecar. A display model about 25 cm long, 400-500 "
         "pieces."),
    Idea("desert_gas_station", "diorama", "a scavenger's desert gas station",
         "An abandoned desert gas station a scavenger has made into a home: rusty pumps, a "
         "faded sign hanging off one hook, an old camper van turned into a workshop, a "
         "lookout built on top of the water tower, solar panels patched together from scrap, "
         "and a dog. Minifig scale on a 32 x 32 base, 700-900 pieces."),
    Idea("sky_island", "fantasy scene", "a floating island with a waterfall",
         "A floating island with a waterfall pouring off its edge into the clouds: a little "
         "cottage with a windmill on top, a vegetable garden, a rope bridge over to a smaller "
         "rock with a lookout, and roots and crystals hanging underneath. On a clear stand so "
         "it floats. About 30 cm tall, 600-800 pieces."),
)


def by_id(wanted: str) -> Idea:
    for idea in IDEAS:
        if idea.id == wanted:
            return idea
    raise KeyError(f"no idea {wanted!r}: {', '.join(i.id for i in IDEAS)}")
