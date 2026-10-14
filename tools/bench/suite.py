"""The held-out suite: what people ask for, each with a brief, a scale and references.

Ten subjects spanning the kinds of thing a person asks a LEGO designer
for: an animal, a car at Speed Champions scale, a rocket at display
scale, a modular building, a castle, a starfighter, a bust, a botanical,
a machine with Technic function and a landscape vignette; and two more
added for the sides round (2026-10-14), a steam locomotive and a sailing
ship, to check on bodies no round was tuned for, and two for the cabins
round, a fire truck and a passenger aircraft. None of them
is a brief any design round was tuned on (the castle, the fire station,
Orthanc); the barn owl and the Falcon Heavy were looked at in earlier
rounds and stay because the owner asked for them by name.

The suite is fixed. Change a brief and every score before it is a score
of something else: add a subject instead, under a new id.

A reference is a photograph on Wikimedia Commons, kept here as its URL,
author and licence and fetched at run time (none is committed), or a
real LEGO set from LDraw's Official Model Repository, rendered by the
same renderer as the design, which shows the judge how LEGO itself
built the subject or one like it.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class Photo:
    """A photograph on Wikimedia Commons."""

    page: str       # the file's page on Commons
    url: str        # the picture itself, about 1280 px wide
    licence: str    # as Commons states it
    author: str
    shows: str      # what it is a picture of, for the judge


@dataclass(frozen=True, slots=True)
class OmrSet:
    """A real LEGO set in LDraw's Official Model Repository, rendered as a reference."""

    number: str     # "10182-1"
    file: str       # its file in the repository: "10182-1.mpd"
    shows: str


Reference = Photo | OmrSet


@dataclass(frozen=True, slots=True)
class Subject:
    id: str
    title: str
    brief: str      # exactly what the design loop is asked, one line
    scale: str
    against: str    # tools/style.py's group of real sets for it
    references: tuple[Reference, ...] = field(default_factory=tuple)


COMMONS_LICENCES = ("Public domain", "CC0", "CC BY", "CC BY-SA")

SUITE: tuple[Subject, ...] = (
    Subject(
        "barn_owl", "a barn owl",
        "A barn owl perched on a weathered branch, as a detailed LEGO display model "
        "about 25 cm tall on a stand with a nameplate.",
        "display, about 25 cm tall", "other",
        (Photo("https://commons.wikimedia.org/wiki/File:%D0%A1%D0%B8%D0%BF%D1%83%D1%85%D0%B0_(Tyto_alba)_%D0%B2_%D0%A7%D0%BE%D1%80%D0%BD%D0%BE%D0%BC%D0%BE%D1%80%D1%81%D1%8C%D0%BA%D0%BE%D0%BC%D1%83_%D0%B1%D1%96%D0%BE%D1%81%D1%84%D0%B5%D1%80%D0%BD%D0%BE%D0%BC%D1%83_%D0%B7%D0%B0%D0%BF%D0%BE%D0%B2%D1%96%D0%B4%D0%BD%D0%B8%D0%BA%D1%83.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/e/e7/%D0%A1%D0%B8%D0%BF%D1%83%D1%85%D0%B0_%28Tyto_alba%29_%D0%B2_%D0%A7%D0%BE%D1%80%D0%BD%D0%BE%D0%BC%D0%BE%D1%80%D1%81%D1%8C%D0%BA%D0%BE%D0%BC%D1%83_%D0%B1%D1%96%D0%BE%D1%81%D1%84%D0%B5%D1%80%D0%BD%D0%BE%D0%BC%D1%83_%D0%B7%D0%B0%D0%BF%D0%BE%D0%B2%D1%96%D0%B4%D0%BD%D0%B8%D0%BA%D1%83.jpg/1280px-%D0%A1%D0%B8%D0%BF%D1%83%D1%85%D0%B0_%28Tyto_alba%29_%D0%B2_%D0%A7%D0%BE%D1%80%D0%BD%D0%BE%D0%BC%D0%BE%D1%80%D1%81%D1%8C%D0%BA%D0%BE%D0%BC%D1%83_%D0%B1%D1%96%D0%BE%D1%81%D1%84%D0%B5%D1%80%D0%BD%D0%BE%D0%BC%D1%83_%D0%B7%D0%B0%D0%BF%D0%BE%D0%B2%D1%96%D0%B4%D0%BD%D0%B8%D0%BA%D1%83.jpg",
               "CC BY-SA 4.0", "Yu Moskalenko",
               "a barn owl standing front-on: heart-shaped white face, white breast, tan and grey wings"),
         Photo("https://commons.wikimedia.org/wiki/File:Tyto_alba_tylluan_wen.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/4/4d/Tyto_alba_tylluan_wen.jpg/1280px-Tyto_alba_tylluan_wen.jpg",
               "CC BY-SA 4.0", "Alun Williams333",
               "a barn owl perched on a post, three-quarter view: golden-tan back, grey-flecked "
               "wings, white underparts")),
    ),
    Subject(
        "speed_champions", "a Porsche 911 Turbo at Speed Champions scale",
        "A 1975 Porsche 911 Turbo as a LEGO Speed Champions set: 8 studs wide, "
        "minifigure scale, with a driver.",
        "Speed Champions, 8 studs wide", "vehicles",
        (Photo("https://commons.wikimedia.org/wiki/File:1975_Porsche_Homologation_930_Coupe_(45687449482).jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/7/76/1975_Porsche_Homologation_930_Coupe_%2845687449482%29.jpg/1280px-1975_Porsche_Homologation_930_Coupe_%2845687449482%29.jpg",
               "CC BY 2.0", "Sicnag",
               "a silver 1975 Porsche 930 Turbo, front three-quarter view"),
         OmrSet("75895-1", "75895-1.mpd",
                "LEGO's own Speed Champions 75895 1974 Porsche 911 Turbo 3.0")),
    ),
    Subject(
        "falcon_heavy", "a SpaceX Falcon Heavy",
        "A SpaceX Falcon Heavy rocket as a detailed LEGO display model about 60 cm "
        "tall, on a launch stand.",
        "display, about 60 cm tall", "space",
        (Photo("https://commons.wikimedia.org/wiki/File:Falcon_Heavy_cropped.jpg",
               "https://upload.wikimedia.org/wikipedia/commons/2/2b/Falcon_Heavy_cropped.jpg",
               "CC0", "SpaceX",
               "the Falcon Heavy on pad 39A, front-on, the whole rocket with both side boosters "
               "and the fairing"),
         Photo("https://commons.wikimedia.org/wiki/File:Arabsat-6A_Mission_(40628435833).jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/2/26/Arabsat-6A_Mission_%2840628435833%29.jpg/1280px-Arabsat-6A_Mission_%2840628435833%29.jpg",
               "CC0", "Official SpaceX Photos",
               "a Block 5 Falcon Heavy in flight: white cores, black interstages and octawebs")),
    ),
    Subject(
        "corner_shop", "a small modular corner shop",
        "A small modular corner shop in the style of LEGO's Modular Buildings: two "
        "storeys on a 32 x 32 base at minifigure scale, a shop with a corner door and "
        "display windows below, a flat above, both furnished inside.",
        "minifigure, a 32 x 32 base", "buildings",
        (Photo("https://commons.wikimedia.org/wiki/File:Shop_on_the_corner_of_River_Street_and_Castle_Street,_Truro,_Cornwall_-_August_2022.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/5/53/Shop_on_the_corner_of_River_Street_and_Castle_Street%2C_Truro%2C_Cornwall_-_August_2022.jpg/1280px-Shop_on_the_corner_of_River_Street_and_Castle_Street%2C_Truro%2C_Cornwall_-_August_2022.jpg",
               "CC BY-SA 4.0", "Mutney",
               "a two-storey corner building in Truro: a shopfront on the cut corner, sash "
               "windows above"),
         OmrSet("10182-1", "10182-1.mpd",
                "LEGO's own Modular Buildings 10182 Cafe Corner, a corner building")),
    ),
    Subject(
        "castle_gatehouse", "a castle gatehouse",
        "A medieval castle gatehouse with two round towers either side of an arched "
        "gate, a portcullis and a drawbridge, at minifigure scale.",
        "minifigure", "castle",
        (Photo("https://commons.wikimedia.org/wiki/File:Carisbrooke_Castle_gatehouse.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9e/Carisbrooke_Castle_gatehouse.jpg/1280px-Carisbrooke_Castle_gatehouse.jpg",
               "CC BY-SA 4.0", "DeFacto",
               "Carisbrooke Castle's gatehouse front-on: two round crenellated towers with "
               "machicolations either side of an arched gate"),
         OmrSet("10176-1", "10176-1.mpd",
                "LEGO's own 10176 Royal King's Castle, for how a castle is built at this scale")),
    ),
    Subject(
        "starfighter", "a Star-Wars-like starfighter",
        "A single-seat starfighter in the style of Star Wars, an original design and not "
        "a licensed ship: four wings that open into an X, engines at the wing roots, "
        "cannons at the tips, at minifigure scale with a pilot.",
        "minifigure", "space",
        (OmrSet("75102-1", "75102-1.mpd",
                "LEGO's own Star Wars 75102 Poe's X-Wing Fighter, the ship this style is from"),),
    ),
    Subject(
        "astronaut_bust", "a bust of an Apollo astronaut",
        "A bust of an Apollo astronaut, head and shoulders in a white spacesuit with a "
        "helmet and a gold visor, as a LEGO display model about 20 cm tall on a stand "
        "with a nameplate.",
        "display, about 20 cm tall", "other",
        (Photo("https://commons.wikimedia.org/wiki/File:Buzz_Aldrin.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/d/dc/Buzz_Aldrin.jpg/1280px-Buzz_Aldrin.jpg",
               "Public domain", "NASA",
               "Buzz Aldrin's Apollo 11 portrait: the white A7L suit, red neck ring, patches, "
               "the helmet with its gold visor beside him"),
         Photo("https://commons.wikimedia.org/wiki/File:Jim_Lovell_during_suit-up_on_launch_day.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/2/2c/Jim_Lovell_during_suit-up_on_launch_day.jpg/1280px-Jim_Lovell_during_suit-up_on_launch_day.jpg",
               "Public domain", "NASA",
               "Jim Lovell in a white Apollo suit wearing its clear bubble helmet")),
    ),
    Subject(
        "bonsai", "a bonsai tree",
        "A bonsai tree in a shallow rectangular pot, as a LEGO display model about 20 cm "
        "tall in the style of LEGO's Botanicals.",
        "display, about 20 cm tall", "other",
        (Photo("https://commons.wikimedia.org/wiki/File:Chinesischer_Wacholder_Bonsai.png",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3a/Chinesischer_Wacholder_Bonsai.png/1280px-Chinesischer_Wacholder_Bonsai.png",
               "CC BY-SA 4.0", "Shisma",
               "a juniper bonsai: twisting red-brown trunk, green pads of foliage, a shallow "
               "brown pot on a stand"),
         OmrSet("10281-1", "10281-1.mpd", "LEGO's own Botanicals 10281 Bonsai Tree")),
    ),
    Subject(
        "mobile_crane", "a mobile crane with Technic functions",
        "A mobile crane truck with working Technic functions: the superstructure turns on "
        "the chassis, the boom raises and telescopes, and the hook winds up on a winch; "
        "a display model about 40 cm long.",
        "display, about 40 cm long", "vehicles",
        (Photo("https://commons.wikimedia.org/wiki/File:D%C3%BClmen,_Br%C3%BCckenbaustelle_der_Deutschen_Bahn_--_2016_--_2329.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/1/1b/D%C3%BClmen%2C_Br%C3%BCckenbaustelle_der_Deutschen_Bahn_--_2016_--_2329.jpg/1280px-D%C3%BClmen%2C_Br%C3%BCckenbaustelle_der_Deutschen_Bahn_--_2016_--_2329.jpg",
               "CC BY-SA 4.0", "Dietmar Rabich",
               "a five-axle all-terrain crane from the side, its telescopic boom extended, "
               "outriggers down"),
         Photo("https://commons.wikimedia.org/wiki/File:Brannay-FR-89-levage_sur_chantier-juillet_2019-a4.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c4/Brannay-FR-89-levage_sur_chantier-juillet_2019-a4.jpg/1280px-Brannay-FR-89-levage_sur_chantier-juillet_2019-a4.jpg",
               "CC BY-SA 4.0", "François GOGLINS",
               "an all-terrain crane from the rear three-quarter, boom raised, lifting a load"),
         OmrSet("42108-1", "42108-1.mpd",
                "LEGO's own Technic 42108 Mobile Crane, for how LEGO builds a crane's functions")),
    ),
    Subject(
        "mountain_cabin", "a mountain lake landscape vignette",
        "A landscape vignette on a 16 x 16 base: a small wooden cabin by a mountain lake, "
        "pine trees, rocks, and a jetty with a rowing boat, the water in layered "
        "translucent blue.",
        "a 16 x 16 vignette", "other",
        (Photo("https://commons.wikimedia.org/wiki/File:Boathouse_on_a_mountain_lake_(Unsplash).jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/9/93/Boathouse_on_a_mountain_lake_%28Unsplash%29.jpg/1280px-Boathouse_on_a_mountain_lake_%28Unsplash%29.jpg",
               "CC0", "Luca Bravo",
               "a wooden boathouse with a jetty and rowing boats on a mountain lake, pines and "
               "peaks behind"),
         Photo("https://commons.wikimedia.org/wiki/File:Dove_Lake_Boatshed.jpg",
               "https://thumb.wikimedia.org/wikipedia/commons/thumb/7/7e/Dove_Lake_Boatshed.jpg/1280px-Dove_Lake_Boatshed.jpg",
               "CC BY-SA 4.0", "Ttrevask",
               "a weathered wooden boatshed on a lake shore with jagged peaks behind")),
    ),
    # Added 2026-10-14, never in a round before the sides round: a gain on the
    # four subjects every round runs should hold on bodies nobody tuned for.
    # A locomotive's cab and tender and a ship's hull are bodies with long
    # sides, which is what that round changed.
    Subject(
        "steam_locomotive", "a steam locomotive",
        "A steam locomotive and its tender at minifigure scale, 6 studs wide, in the style "
        "of LEGO® train sets: boiler, smokebox, cab, driving wheels with side rods.",
        "minifigure, 6 studs wide", "vehicles",
        (OmrSet("10194-1", "10194-1.mpd",
                "the LEGO Group's own Creator Expert 10194 Emerald Night, a steam "
                "locomotive and tender"),),
    ),
    Subject(
        "sailing_ship", "a sailing ship",
        "A two-masted sailing ship at minifigure scale, about 40 studs long: a curved hull "
        "with a raised stern, masts with sails and rigging, and cannons.",
        "minifigure, about 40 studs long", "vehicles",
        (OmrSet("6286-1", "6286-1.mpd",
                "the LEGO Group's own Pirates 6286 Skull's Eye Schooner, a two-masted "
                "sailing ship"),),
    ),
    # Added 2026-10-14 for the cabins round, never run before it: a cab with a
    # windscreen on a truck, and a cockpit and a cabin on an aircraft, the two
    # other bodies a cabin's or a canopy's rake is part of.
    Subject(
        "fire_truck", "a fire truck",
        "A fire engine with an extending ladder at minifigure scale, in the style of "
        "LEGO® City fire sets, 6 studs wide: a crew cab, the ladder on a turntable, hose "
        "and lockers, with a firefighter.",
        "minifigure, 6 studs wide", "vehicles",
        (OmrSet("4208-1", "4208-1.mpd",
                "the LEGO Group's own City 4208 4 x 4 Fire Truck"),
         OmrSet("6480-1", "6480-1.mpd",
                "the LEGO Group's own Town 6480 Hook and Ladder Truck")),
    ),
    Subject(
        "passenger_aircraft", "a passenger aircraft",
        "A twin-engined passenger jet at minifigure scale, in the style of LEGO® City "
        "airport sets: a cockpit, a cabin with windows and seats, swept wings with an "
        "engine under each, a tail fin and landing gear, with a pilot.",
        "minifigure", "vehicles",
        (OmrSet("3181-1", "3181-1.mpd",
                "the LEGO Group's own City 3181 Passenger Plane"),
         OmrSet("7893-1", "7893-1.mpd",
                "the LEGO Group's own City 7893 Passenger Plane")),
    ),
)

# The two pictures in every judgement, so a score means the same thing in
# every run: LEGO's own MINI Cooper, a set whose curves, SNOT and detail
# are what a 9 looks like, and the same car as a stack of plain bricks,
# studs up, in three colours, which is what a 2 looks like.
ANCHOR_HIGH = OmrSet("10242-1", "10242-1.mpd", "LEGO's own Creator Expert 10242 MINI Cooper")
ANCHOR_HIGH_SCORE = 9
ANCHOR_LOW = "naive_car.ldr"        # beside this file
ANCHOR_LOW_SCORE = 2


def by_id(wanted: str) -> Subject:
    for subject in SUITE:
        if subject.id == wanted:
            return subject
    raise KeyError(f"no subject {wanted!r}: {', '.join(s.id for s in SUITE)}")
