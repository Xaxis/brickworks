#!/usr/bin/env python3
"""A blind test against real LEGO® sets: our designer and the set's, given the same brief.

    python3 tools/bench/realset.py sample [--which tune|proof] [--first N] [--show]
    python3 tools/bench/realset.py run --which tune --arm m32 [--checkout DIR]
                                   [--first N | --subjects N,N] [--jobs 2] [--date D]
                                   [--timeout S] [--software] [--audit-later]
    heavy python3 tools/bench/realset.py audit --which tune --arm m32 [--date D]
    python3 tools/bench/realset.py calibrate [--which tune] [--jobs 2] [--software]
    python3 tools/bench/realset.py report --which proof --arm m32 [--date D] [--first N]
    python3 tools/bench/realset.py compare --which proof --arms m32,mine [--dates D1,D2]
                                       [--first N] [--jobs 2]
    heavy python3 tools/bench/realset.py reach --which proof --arm m32 [--date D]
    python3 tools/bench/realset.py run ... --via relay [--instructions none]

A half is 44 subjects; `--first 10` is the ten it had before 2026-10-19. On
two workers a subject took nine minutes (main, 2026-10-19), a half about 6.5
hours, when each design held a GPU slot for its whole session. A design's app
now runs headless and takes the lease only for a drawer while it draws (37% of
a session, 2026-10-20), so three or four workers fit where the GPU is shared
with short jobs; beside a run that holds a slot a session (an older
`--checkout`), pictures wait (DESIGN_SCORES.md, "What a round costs now"). Set
BENCH_PORTS=LO-HI to keep each design's app to an agent's ports.

Every round so far was steered by subjects we tuned on, and our own judge
once preferred an outside designer 40 of 40 after calling our rounds gains.
Real sets are the ground truth this measures against, on subjects nobody
tuned on, judged blind.

- **Subjects** are sets of LDraw's model repository (vendor/omr), the main
  model of each, 80 to 1,500 parts, from 2000 on. A set is left out when its
  name or theme names a kind of subject any round touched or was steered by
  (`TOUCHED`: every subject of tools/bench/suite.py, every BrickBench prompt
  run, the docs' runs and probes), and when it is not one model to design
  (`NOT_A_MODEL`). Left out by kind, not by number: no car, not only the
  Porsche.
- **Sampling** is fixed: sets in the order of a hash of their number, one
  animal, one person and one creature first in each half, then the rest
  across four sizes, the theme least used so far first. Two halves of
  `PER_HALF`: `tune`, which the tool was built looking at, and `proof`, run
  only at the end. 44 a half takes every set but the characters past one of
  each kind a half (BrickHeadz, all but three): the fewest that give a paired
  95% interval of about 10 points either way on overall and technique
  (docs/DESIGN_SCORES.md, "Enough subjects"). A half's first `FIRST` are the
  ten it had before 2026-10-19, so results of then read on (`--first 10`).
  Tune's first ten have been looked at and tuned on; tune's other 34 may be.
  Proof is never tuned on: no `--show`, no reading its designs to steer.
- **The brief** is what a person would ask for, from the set's name and
  theme, with the set's footprint in studs and a band round its piece
  count, so the two are like for like. The designer never gets the set's
  file, picture or parts: the subject id it is started with holds the set's
  own pieces out of the real-set index (src/ai/real_snippets.gd) as well as
  out of design memory, and a design's record says whether the log showed it.
- **The designer** is run.py's design stage, the real loop on the
  subscription, the app headless with its pictures drawn on the GPU's lease
  by a drawer that holds it only while it draws (src/ai/leased_shots.gd).
  Each of `--jobs` workers takes its share of the subjects. Run it bare: each
  drawer and each drawing takes the lease for itself (run.py's `gpu`), so
  other jobs get the GPU between them. Under one `gpu` the whole run held
  it, and two such runs kept a probe off the GPU for 40 minutes while the
  CPU stood idle (2026-10-19). The workers
  wait for no CPU slot: in software under `heavy` at load 50 a worker
  waited 30 minutes for one. Only
  the build check's reading of a model is CPU work, under `heavy`, and
  `--audit-later` leaves it to `audit`, one heavy job after the run, so a
  run holding the GPU never waits on the CPU queue. `--software` draws on
  lavapipe and runs each worker as one `heavy` job instead. `--checkout`
  runs another checkout's app as the arm; the renderer, the check and the
  judge are always this one's.
- **The comparison** draws the design and the set with the same renderer
  and cameras, copies both under names that say nothing (bench/results/
  blind/), and asks the pairwise judge, both orders, which is better on
  likeness, surface, colour, technique, creativity and overall. The judge is
  not told one is a real set. A win rate per dimension has a 95% Wilson
  interval over subjects, a subject counting the share of its verdicts won.
- **Calibration** first: on the tune half the judge must prefer each set
  over a naive stack of itself (calibrate.naive_stack) or the test means
  nothing.
- **Measures**, ours against the set's, from tools/style.py and the build
  check's reading (src/dev/connection_audit.gd): parts, shapes per 100
  parts, shaped share, 1 x 1 share, colours, tiles, SNOT, joints, parts
  turned off the grid, and parts the check calls floating.
- **The owner's path**, `--via relay`: the owner designs with their own Claude
  through the connector, not with Claude Code on the app's port. So each design's
  app is started as a connector tab of a throwaway account (a Resend test address,
  deleted after) on tools/web/relay_server.mjs, with `--mcp` only: no brief heard,
  no world cleared. Claude Code is signed in to the account with OAuth, as
  `claude mcp login` leaves it, and given the brief as the person types it, with
  the relay its only server. `--instructions none` withholds the server's
  instructions at initialize, the bound on a client that shows none: whether
  claude.ai shows them was never measured, and Claude Code shows about 4,096
  characters. Without `--via` the path is the bench's, as before. Ports come
  from BENCH_PORTS, two a design (the relay's and the app's), and the app's data
  from a folder of its own under XDG_DATA_HOME.
- **Reach**, `reach`: whether a lever reached the sessions at all, from
  each design's Claude Code transcript (the guide sections read, sections
  turned or hinged and refused, techniques placed, features settled) beside
  the share of parts turned, ours and the set's. Words that reach no
  session move no verdict, and the pictures do not say which happened.

Everything lands in the main checkout's bench/results/ (git-ignored):
realset-<date>-<arm>/<set>/ for an arm's designs, realset-sets/<set>/ for
the set's own pictures, measures and calibration, blind/ for what the judge
sees, and realset-<date>-<a>-vs-<b>/ for two arms judged head to head.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import os
import random
import re
import shutil
import signal
import socket
import statistics
import subprocess
import sys
import threading
import time
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import steps_score  # noqa: E402
import style  # noqa: E402
from bench import calibrate, judge, pairwise, suite  # noqa: E402
from bench import run as bench  # noqa: E402

FILES = ROOT / "vendor" / "omr" / "files"
INDEX = ROOT / "vendor" / "omr" / "index.json"
RESULTS = bench.RESULTS
SETS_DIR = RESULTS / "realset-sets"
BLIND = RESULTS / "blind"

SALT = "brickworks realset 1"
FEWEST, MOST = 80, 1500
SINCE = 2000
PER_HALF = 44
FIRST = 10          # a half's size before 2026-10-19, and the start of each half since
CHARACTERS = ("animal", "person", "creature")
SIZES = ((80, 200), (200, 400), (400, 800), (800, MOST + 1))
HALVES = ("tune", "proof")
DIMS = calibrate.VISUAL      # likeness, surface, colour, technique, creativity, overall
VIEWS = bench.VIEWS
PROMPT_VERSION = 1
CANNED_PAIR = bench.CANNED_PAIR
_LOCK = threading.Lock()


# -- what was touched ---------------------------------------------------------

# Every kind of subject a design round touched or was steered by: the words
# that name it in a set's name, and where it was touched. A set is out when
# any of these is a whole word of its name (a plural too).
TOUCHED: dict[str, tuple[str, tuple[str, ...]]] = {
    "bird": ("suite: barn owl; ROADMAP: the parrot of the snippet checks; BrickBench: duck, "
             "penguin",
             ("owl", "owlet", "hedwig", "bird", "parrot", "eagle", "hawk", "falcon", "pelican",
              "chick", "chicken", "hen", "rooster", "turkey", "duck", "penguin", "swan",
              "flamingo", "toucan", "macaw")),
    "car": ("suite: Speed Champions Porsche; ROADMAP: the car; BrickBench: burger car, duck car, "
            "dragster",
            ("car", "racer", "race", "racing", "roadster", "coupe", "convertible", "sedan",
             "porsche", "ferrari", "lamborghini", "mclaren", "mini cooper", "cooper", "beetle",
             "mustang", "fiat", "aston", "caterham", "bugatti", "batmobile", "tumbler",
             "dragster", "kart", "go-kart", "hot rod", "jeep", "buggy", "speedster", "f1",
             "formula", "limousine", "taxi", "4 x 4", "4x4", "off-road", "off road", "off-roader",
             "offroad", "offroader", "rally", "gto", "berlinetta", "f40", "f138",
             "f12berlinetta", "512 s", "wheels")),
    "truck or van": ("suite: fire truck, mobile crane truck; BrickBench: van",
                     ("truck", "lorry", "van", "camper", "pickup", "pick-up", "tow", "tanker",
                      "hook loader", "cement mixer",
                      "rig", "dumper", "dump", "garbage", "transporter", "transport", "hauler",
                      "trailer", "ambulance")),
    "fire": ("suite: fire truck; ROADMAP: fire station",
             ("fire", "firefighter", "fireman", "firehouse")),
    "rocket": ("suite: Falcon Heavy", ("rocket", "saturn", "launch", "launcher", "launchpad")),
    "shop or modular building": ("suite: corner shop; BrickBench: doughnut shop",
                                 ("modular", "corner", "shop", "store", "cafe", "café", "bakery",
                                  "pizzeria", "pizza", "grocer", "grocery", "market",
                                  "boutique", "salon", "diner", "restaurant", "deli",
                                  "parlour", "parlor", "doughnut", "donut", "coffee",
                                  "central perk")),
    "castle or tower": ("suite: castle gatehouse; ROADMAP: castle, Orthanc; BrickBench: knights",
                        ("castle", "gatehouse", "gate", "fort", "fortress", "citadel", "tower",
                         "turret", "orthanc", "knight", "knight's", "kingdom", "dragon")),
    "spaceship": ("suite: starfighter; ROADMAP: Voyager, the space cruiser; BrickBench: "
                  "delivery spaceship",
                  ("starfighter", "fighter", "x-wing", "wing", "tie", "interceptor", "bomber",
                   "cruiser", "starship", "spaceship", "spacecraft", "shuttle", "voyager",
                   "enterprise", "destroyer", "gunship", "freighter", "space", "ufo")),
    "bust or astronaut": ("suite: Apollo astronaut bust",
                          ("bust", "astronaut", "spaceman", "apollo", "cosmonaut")),
    "plant": ("suite: bonsai",
              ("bonsai", "tree", "plant", "flower", "bouquet", "blossom", "garden", "botanical",
               "succulent", "orchid", "rose", "wreath", "cactus", "fern", "sunflower", "tulip",
               "willow")),
    "crane": ("suite: mobile crane", ("crane",)),
    "cabin or vignette": ("suite: mountain lake vignette",
                          ("cabin", "hut", "lodge", "chalet", "lake", "lakeside", "jetty",
                           "vignette", "diorama", "landscape", "mountain")),
    "train": ("suite: steam locomotive; BrickBench: eleven locomotives, a minecart, a trolley",
              ("train", "locomotive", "loco", "steam", "railway", "railroad", "rail", "tram",
               "trolley", "caboose", "express", "metroliner", "freight", "minecart",
               "monorail", "engine", "junction")),
    "ship or boat": ("suite: sailing ship; ROADMAP: pirate ship; BrickBench: submarine, sailboat",
                     ("ship", "schooner", "galleon", "boat", "sailboat", "sailing", "yacht",
                      "catamaran", "submarine", "ferry", "barge", "canoe", "kayak", "raft",
                      "speedboat", "tug", "tugboat", "trawler", "hovercraft", "pirate",
                      "harbour", "harbor", "marina", "triple-e", "titanic")),
    "aircraft": ("suite: passenger aircraft",
                 ("plane", "airplane", "aeroplane", "aircraft", "airliner", "jet", "jetport",
                  "airport", "airline", "flyer", "biplane", "seaplane", "glider", "soarer",
                  "camel", "helicopter", "copter", "rotor", "heli", "flying", "helicarrier")),
    "lighthouse": ("ROADMAP: the lighthouse", ("lighthouse",)),
    "bunny": ("ROADMAP: the brickify bench's bunny", ("bunny", "rabbit")),
    "cat": ("ROADMAP: face_probe's cat head", ("cat", "kitten", "kitty")),
    "bear": ("ROADMAP: face_probe's bear; BrickBench: purple bear", ("bear", "teddy", "panda")),
    "dog": ("BrickBench: armoured dog, balloon dog",
            ("dog", "puppy", "pug", "shepherd", "poodle", "hound", "pluto", "goofy")),
    "frog, crab, turtle": ("BrickBench: frog mech, crab mech, turtle wizard",
                           ("frog", "toad", "crab", "turtle", "tortoise")),
    "robot or mech": ("BrickBench: robots, frog and crab mechs",
                      ("robot", "mech", "mecha", "walker", "exo-suit", "droid", "android",
                       "cyborg", "wall-e", "wall•e", "voltron", "construct-o-mech")),
    "two wheels": ("BrickBench: cruiser bicycle",
                   ("bicycle", "bike", "cycle", "motorbike", "motorcycle", "scooter", "vespa",
                    "harley-davidson", "chopper")),
    "ghost, alien, demon": ("BrickBench: spirit, aliens, demon",
                            ("spirit", "ghost", "phantom", "alien", "martian", "demon",
                             "devil")),
    "wizard or witch": ("BrickBench: wizard, turtle wizard",
                        ("wizard", "witch", "sorcerer", "mage", "warlock")),
    "statue": ("BrickBench: the seated statue, the rooftop mascot",
               ("statue", "sculpture", "thinker", "liberty", "mascot")),
    "furniture and things": ("BrickBench: throne, armchair, toilet, lava lamp, dumpster, "
                             "paperclip, puzzle cube, potato toy, pinball",
                             ("throne", "armchair", "chair", "sofa", "toilet", "lamp",
                              "dumpster", "paperclip", "cube", "potato", "pinball", "arcade",
                              "balloon")),
    "house or building": ("BrickBench: hobbit home, farmhouse and windmill, skyscraper, office, "
                          "mailroom, spy vault, school; suite: the flat over the shop",
                          ("house", "home", "cottage", "villa", "bungalow", "mansion",
                           "townhouse", "apartment", "burrow", "hobbit", "farm", "farmhouse",
                           "barn", "windmill", "skyscraper", "laboratory", "office",
                           "mailroom", "post office", "vault", "bank", "school", "spy",
                           "agent")),
}

# Whole themes that are one touched kind: every set in them is that subject.
TOUCHED_THEMES: dict[str, str] = {
    "Train": "train", "Racers": "car", "Speed Champions": "car", "Speed Racer": "car",
    "Boat": "ship or boat", "Pirates": "ship or boat", "Castle": "castle or tower",
    "Star Wars": "spaceship", "Space": "spaceship", "Botanicals": "plant",
    "Modular Buildings": "shop or modular building", "Mindstorms": "robot or mech",
}

# Not one model a person would ask for: pictures, buckets of parts, other systems.
NOT_A_MODEL_THEMES = ("LEGO Art", "DOTS", "Brick Sketches", "Duplo", "Universal Building Set",
                      "Educational and Dacta", "Dimensions", "Znap", "Factory", "Other")
NOT_A_MODEL_WORDS = ("advent", "calendar", "bucket", "starter", "supplementary", "collection",
                     "pack", "kit", "bonanza", "toolbox", "designer set", "building set",
                     "creative", "parts", "puzzle", "map", "mosaic", "minifigure", "value",
                     "promotional set", "celebrating")


def _words(text: str) -> str:
    """A name as matched: lower case, quotes and dashes plain, '&' as 'and'."""
    text = text.lower().replace("’", "'").replace("–", "-").replace("&", " and ")
    return " " + re.sub(r"\s+", " ", text) + " "


def _names(name: str, word: str) -> bool:
    """Whether a name has the word whole, or its plural."""
    pattern = r"(?<![a-z0-9])" + re.escape(word) + r"(s|es)?(?![a-z0-9])"
    return re.search(pattern, _words(name)) is not None


def top_theme(theme: str) -> str:
    return theme.split(" > ")[0].strip()


# A name can hide its kind (10194 Emerald Night is a locomotive), so the
# modeller's names for the sub-models count too: a set is out when at least
# this share of them, and two or more, name a touched kind.
SUBMODEL_SHARE = 0.25


def _touches(text: str) -> str | None:
    for kind, (_source, words) in TOUCHED.items():
        for word in words:
            if _names(text, word):
                return f"{kind} ({word})"
    return None


def submodels(text: str) -> list[str]:
    """The names a model's author gave its sub-models, without the main one, figures,
    parts carried in the file, and names that are only numbers."""
    names = [line.split(None, 2)[2].strip() for line in text.splitlines()
             if re.match(r"\s*0\s+FILE\s", line, re.I) and len(line.split(None, 2)) > 2]
    out = []
    for raw in names[1:]:
        if re.search(r"\.dat$", raw, re.I):
            continue
        said = re.sub(r"\.(ldr|mpd)$", "", raw, flags=re.I)
        said = re.sub(r"^\d+(-\d+)?\s*-\s*", "", said)
        if re.search(r"minifig|figure", said, re.I) or re.fullmatch(r"[\d\s_.-]*", said):
            continue
        out.append(said)
    return out


def looked_at() -> set[str]:
    """Every set a round showed a judge or a designer: the suite's references, its anchor,
    and calibrate.py's known pairs."""
    numbers = {suite.ANCHOR_HIGH.number}
    for subject in suite.SUITE:
        numbers |= {r.number for r in subject.references if isinstance(r, suite.OmrSet)}
    numbers |= {number for number, _subject in calibrate._SETS}
    return numbers


def excluded(name: str, theme: str, parts: tuple[str, ...] | list[str] = (),
             number: str = "") -> str | None:
    """Why a set is not a subject here (the kind it touches, or why it is no model), or None.
    `parts` are its sub-models' names."""
    top = top_theme(theme)
    if number and number in looked_at():
        return "touched: a reference or anchor of the suite"
    if top in TOUCHED_THEMES:
        return f"touched: {TOUCHED_THEMES[top]} (the {top} theme)"
    if top in NOT_A_MODEL_THEMES:
        return f"not a model to design (the {top} theme)"
    for word in NOT_A_MODEL_WORDS:
        if _names(name, word):
            return f"not a model to design ({word})"
    said = _touches(name)
    if said:
        return f"touched: {said}"
    hits = [h for h in (_touches(p) for p in parts) if h]
    if len(hits) >= 2 and len(hits) >= SUBMODEL_SHARE * len(parts):
        return f"touched: {Counter(hits).most_common(1)[0][0]}, by {len(hits)} of its " \
               f"{len(parts)} sub-models"
    return None


# -- characters -----------------------------------------------------------------

ANIMALS = ("lion", "tiger", "elephant", "giraffe", "zebra", "rhino", "hippo", "monkey",
           "gorilla", "koala", "kangaroo", "fox", "wolf", "deer", "reindeer", "moose", "sheep",
           "lamb", "goat", "pig", "cow", "bull", "horse", "pony", "donkey", "squirrel",
           "hedgehog", "mouse", "bee", "butterfly", "ladybird", "ladybug", "spider",
           "scorpion", "snail", "ant", "fish", "shark", "whale", "dolphin", "octopus", "squid",
           "seahorse", "jellyfish", "starfish", "crocodile", "alligator", "snake", "lizard",
           "chameleon", "gecko", "iguana", "bat", "sloth", "otter", "seal", "walrus", "animal")
CREATURES = ("dinosaur", "dino", "apatosaurus", "pteranodon", "tyrannosaurus", "t-rex",
             "triceratops", "raptor", "velociraptor", "stegosaurus", "brachiosaurus", "monster",
             "beast", "creature", "yeti", "troll", "goblin", "ogre", "gremlin", "unicorn",
             "griffin", "gryphon", "phoenix", "kraken", "hydra", "cyclops", "mummy", "zombie",
             "vampire", "werewolf", "skeleton", "snowman", "olaf", "creeper", "venom", "groot",
             "chewbacca", "yoda", "thanos", "hulk")
CREATURE_THEMES = ("Mixels", "Legends of Chima")
# Named cartoon animals are characters played as people.
PEOPLE = ("mickey", "minnie")
PERSON_THEMES = ("Brickheadz",)


def _heads(name: str) -> list[str]:
    """The last word of each subject a name names: "Steve & Creeper" -> steve, creeper.
    A set is a character only when the character is what the name is of: "Dino
    Explorer" is an explorer's playset with a dinosaur in it."""
    parts = re.split(r"\s+(?:&|and)\s+", clean_name(name).lower())
    return [p.split()[-1] for p in parts if p.split()]


def character(name: str, theme: str) -> str | None:
    """"creature", "animal" or "person" when the set is a character built big, else None."""
    top = top_theme(theme)
    heads = _heads(name)
    if top in CREATURE_THEMES or any(_names(h, w) for h in heads for w in CREATURES):
        return "creature"
    if any(_names(name, w) for w in PEOPLE):
        return "person"
    if any(_names(h, w) for h in heads for w in ANIMALS):
        return "animal"
    if top in PERSON_THEMES:
        return "person"
    return None


# -- the sets -------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Candidate:
    number: str     # "4903-1"
    file: str       # "4903-1.mpd"
    name: str
    theme: str
    year: int
    parts: int      # every part placed, figures too, as a box counts pieces
    submodels: tuple[str, ...] = ()
    models: int = 1     # the repository's models of the set: a 3-in-1 has three

    @property
    def kind(self) -> str | None:
        return character(self.name, self.theme)


def _year(value: object) -> int:
    try:
        return int(str(value))
    except ValueError:
        return 0


def candidates(files: Path = FILES, index: Path = INDEX) -> list[Candidate]:
    """Every set's main model in the repository with its size, before any is left out."""
    rows = {r["number"]: r for r in json.loads(index.read_text())} if index.exists() else {}
    found = []
    for path in sorted(files.iterdir()) if files.is_dir() else []:
        if path.suffix.lower() not in (".mpd", ".ldr") or path.stem not in rows:
            continue        # an alternate model (10183-1_Caboose.mpd) is not the set
        row = rows[path.stem]
        text = path.read_text(errors="replace")
        parts, _steps = steps_score.survey(text)
        found.append(Candidate(path.stem, path.name, str(row.get("name", "")).strip(),
                               str(row.get("theme", "")), _year(row.get("year")), parts,
                               tuple(submodels(text)), _year(row.get("models")) or 1))
    return found


def eligible(found: list[Candidate]) -> list[Candidate]:
    """The sets a subject may be drawn from. A set with other models in its box (a 3-in-1,
    a designer set) is named for the box, not for what its main model is, so is left out."""
    return [c for c in found if FEWEST <= c.parts <= MOST and c.year >= SINCE
            and c.models == 1 and excluded(c.name, c.theme, c.submodels, c.number) is None]


def _rank(number: str) -> str:
    return hashlib.sha256(f"{SALT}:{number}".encode()).hexdigest()


def _size(c: Candidate) -> int:
    return next(i for i, (low, high) in enumerate(SIZES) if low <= c.parts < high)


def choose(pool: list[Candidate], per_half: int = PER_HALF) -> dict[str, list[Candidate]]:
    """The two halves: in each, an animal, a person and a creature, then the rest
    across the sizes in turn, each taken in hash order with the theme that half
    has used least first. Tune and proof take turns, so neither gets the better
    pick of a kind or a size; a set is in one half at most."""
    ordered = sorted(pool, key=lambda c: _rank(c.number))
    halves: dict[str, list[Candidate]] = {h: [] for h in HALVES}
    used: set[str] = set()

    def take(which: str, fits) -> bool:
        themes = Counter(top_theme(c.theme) for c in halves[which])
        best = None
        for c in ordered:
            if c.number in used or not fits(c):
                continue
            if best is None or themes[top_theme(c.theme)] < themes[top_theme(best.theme)]:
                best = c
                if themes[top_theme(c.theme)] == 0:
                    break
        if best is None:
            return False
        halves[which].append(best)
        used.add(best.number)
        return True

    for kind in CHARACTERS:
        for which in HALVES:
            take(which, lambda c, k=kind: c.kind == k)
    band = 0
    stalled = 0
    while any(len(halves[h]) < per_half for h in HALVES) and stalled < len(SIZES):
        took = False
        for which in HALVES:
            if len(halves[which]) < per_half:
                took |= take(which, lambda c, b=band: c.kind is None and _size(c) == b)
        stalled = 0 if took else stalled + 1
        band = (band + 1) % len(SIZES)
    return halves


def sample(which: str, first: int = 0) -> list[Candidate]:
    """A half, or its first `first` subjects (`FIRST`: the half as it was before
    2026-10-19)."""
    half = choose(eligible(candidates()))[which]
    return half[:first] if first else half


# -- the brief ------------------------------------------------------------------

STUD = 20.0      # LDU
_SPELLED = {"brickheadz": "BrickHeadz", "lego ideas and cuusoo": "Ideas"}


def clean_name(name: str) -> str:
    """The set's name as a person would say the subject: no bag, edition or promotion."""
    text = re.sub(r"\s*[\(\[][^)\]]*[\)\]]", "", name)
    text = re.sub(r"\s+-\s+.*(promotion|promotional|edition|exclusive).*$", "", text, flags=re.I)
    text = re.sub(r"\b(polybag|promotional|limited edition)\b", "", text, flags=re.I)
    return re.sub(r"\s+", " ", text).strip(" -,")


def theme_words(theme: str) -> str:
    top = top_theme(theme)
    return _SPELLED.get(top.lower(), top)


def footprint(text: str, parts: style.Parts) -> tuple[int, int]:
    """The set's plan, studs across by studs deep (the smaller first), figures left out."""
    model = style.read(text)
    placed = [(p, info) for p in model.placed
              for info in [parts.get(p.part, model.embedded)] if style.building(info)]
    placed, _turned = style._square_up(placed)  # type: ignore[arg-type]
    boxes = style._boxes(placed, parts)
    if not boxes:
        return (0, 0)
    span = [max(b.centre[k] + b.half[k] for b in boxes) - min(b.centre[k] - b.half[k]
                                                                for b in boxes)
            for k in (0, 2)]
    studs = sorted(max(1, round(s / STUD)) for s in span)
    return (studs[0], studs[1])


def band(parts: int) -> tuple[int, int]:
    """A quarter either side of the set's count, to the nearest ten."""
    low = max(10, int(round(parts * 0.75 / 10.0)) * 10)
    high = max(low + 10, int(round(parts * 1.25 / 10.0)) * 10)
    return (low, high)


def brief(c: Candidate, plan: tuple[int, int]) -> str:
    """What the designer is asked: the subject in plain words, its style and its scale."""
    low, high = band(c.parts)
    scale = (f"fitting in about {plan[0]} x {plan[1]} studs" if plan[0] else "")
    return (f"{clean_name(c.name)}, in the style of LEGO® {theme_words(c.theme)} sets: "
            + (f"{scale}, " if scale else "") + f"{low} to {high} pieces.")


def subject_of(c: Candidate, plan: tuple[int, int]) -> suite.Subject:
    """The bench's subject for a set: its id is the set's number, which holds the set's
    own pieces out of the designer's real-set index and memory (--held-out)."""
    return suite.Subject(c.number, clean_name(c.name), brief(c, plan),
                         f"about {plan[0]} x {plan[1]} studs, {band(c.parts)[0]} to "
                         f"{band(c.parts)[1]} pieces", "other", ())


# -- measures -------------------------------------------------------------------

ONE_BY_ONE = re.compile(r"\b1 x 1\b")
MEASURES = ("parts", "shapes_per_100", "shaped", "one_by_one", "colours", "tile", "snot",
            "angle_parts", "angled", "floating_share")


def measures(text: str, parts: style.Parts) -> dict:
    """tools/style.py's reading of a model, and its 1 x 1 share and shapes per 100 parts."""
    model = style.read(text)
    found = style.measure(model, parts)
    total = int(found.get("parts", 0))
    small = 0
    for placed in model.placed:
        info = parts.get(placed.part, model.embedded)
        if style.building(info) and ONE_BY_ONE.search(info.name):  # type: ignore[union-attr]
            small += 1
    # angle_parts counts parts that let a part turn (hinges, clips, bars); angled, the
    # parts that are turned: main's Flatiron, two thirds turned, read 0% the first way.
    out = {k: found.get(k) for k in ("parts", "shapes", "shaped", "colours", "tile", "snot",
                                    "angle_parts", "angled", "symmetry", "plain")}
    out["shapes_per_100"] = round(100.0 * found.get("shapes", 0) / total, 1) if total else 0.0
    out["one_by_one"] = round(small / total, 3) if total else 0.0
    return out


def audit(models: list[Path], out: Path, log: Path) -> dict[str, dict]:
    """The build check's reading of each model (src/dev/connection_audit.gd), by file name."""
    out.parent.mkdir(parents=True, exist_ok=True)
    rows = _audit_rows(out)
    if not all(m.name in rows for m in models):
        command = [bench.HEAVY, "timeout", "--kill-after=30", "2400", "godot", "--headless",
                   "--path", str(ROOT), "--log-file", str(log),
                   "--script", "src/dev/connection_audit.gd", "--", f"--out={out}",
                   *[str(m) for m in models]]
        subprocess.run(command, cwd=ROOT, env=bench._billing_free_env(), capture_output=True,
                       text=True)
        rows = _audit_rows(out)
    return rows


def _audit_rows(out: Path) -> dict[str, dict]:
    rows: dict[str, dict] = {}
    if out.exists():
        for line in out.read_text().splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(row, dict) and not row.get("begin") and "file" in row:
                rows[str(row["file"])] = row
    return rows


def _with_floating(found: dict, row: dict | None) -> dict:
    if row and "floating" in row:
        found = {**found, "floating": int(row["floating"]), "checked_parts": int(row["parts"])}
        found["floating_share"] = round(row["floating"] / row["parts"], 3) if row["parts"] else 0.0
    return found


# -- the judge ------------------------------------------------------------------

LIKENESS = ("Likeness, silhouette and proportion: which reads at a glance as the subject of the "
            "brief, with its proportions, from every view?")
RUBRIC = {**{d: pairwise.RUBRIC[d] for d in DIMS}, "likeness": LIKENESS}


@dataclass(frozen=True, slots=True)
class Question:
    """What the judge is asked of a pair: its dimensions, each one's words, and the
    prompt's version, kept with every verdict. tools/bench/ideas.py asks its own."""

    dims: tuple[str, ...]
    rubric: dict[str, str]
    version: int

    def schema(self) -> dict:
        return {
            "type": "object",
            "properties": {
                "looked_at": {"type": "array", "items": {"type": "string"},
                              "description": "the file name of every picture you opened"},
                **{dim: {"type": "object",
                         "properties": {"better": {"type": "string", "enum": list(pairwise.PICK)},
                                        "reason": {"type": "string"}},
                         "required": ["better", "reason"]} for dim in self.dims},
            },
            "required": ["looked_at", *self.dims],
        }


SETS = Question(DIMS, RUBRIC, PROMPT_VERSION)


def prompt(brief_text: str, a: tuple[judge.Picture, ...], b: tuple[judge.Picture, ...],
           question: Question = SETS) -> str:
    """The question, the same for every pair but the pictures: nothing says which is a set."""
    lines = [
        "You are comparing two LEGO® models built to the same brief, A and B, as a LEGO® set "
        "designer would judge them. Be strict and be consistent: the same two models must get "
        "the same answers every time.",
        "",
        f"The brief both were built to: \"{brief_text}\"",
        "",
        "Open every picture below with the Read tool before you answer anything.",
    ]
    for name, side in (("A", a), ("B", b)):
        lines += ["", f"MODEL {name}:", *[f"  {p.path}: {p.what}" for p in side]]
    lines += [
        "",
        "Both were drawn by the same renderer from the same views, so picture quality says "
        "nothing. A model is not better for being bigger or for having more parts. The order "
        "means nothing either: you are shown the same two the other way round as well.",
        "",
        "For each dimension say which model is better, A or B, and give one sentence naming "
        "what you see in the two that decides it. You must choose one even when they are "
        "close: pick the one that is better on that dimension, however slightly.",
        *[f"  {dim}: {question.rubric[dim]}" for dim in question.dims],
        "",
        "Reply with only the JSON object the schema asks for, with looked_at listing the file "
        "name of every picture you opened.",
    ]
    return "\n".join(lines)


def parse(reply: dict | str, first: str, second: str,
          dims: tuple[str, ...] = DIMS) -> pairwise.Verdict:
    """A reply read into a winner per dimension of `dims`, or ValueError saying what is wrong."""
    if isinstance(reply, dict) and reply.get("type") == "result":
        if reply.get("is_error"):
            raise ValueError(f"the judge's call failed: {str(reply.get('result'))[:200]}")
        found = reply.get("structured_output")
        if not isinstance(found, dict):
            found = judge._object(str(reply.get("result", "")))
    elif isinstance(reply, dict):
        found = reply
    else:
        found = judge._object(reply)
    winners: dict[str, str] = {}
    reasons: dict[str, str] = {}
    for dim in dims:
        said = found.get(dim)
        pick, reason = ((said.get("better"), said.get("reason", "")) if isinstance(said, dict)
                        else (said, ""))
        side = pairwise._side(pick)
        if side is None:
            raise ValueError(f"no A or B for {dim}: {str(pick)[:40]!r}")
        winners[dim] = first if side == "A" else second
        reasons[dim] = " ".join(str(reason).split())
    looked = found.get("looked_at", [])
    return pairwise.Verdict(first, second, winners, reasons,
                            tuple(str(x) for x in looked if isinstance(x, str)))


def shown(key: str, views: list[Path], number: str) -> tuple[judge.Picture, ...]:
    """A model's views copied into the blind folder under a name that says nothing."""
    where = BLIND / pairwise.opaque(f"realset:{number}")
    where.mkdir(parents=True, exist_ok=True)
    code = pairwise.opaque(key)
    out = []
    for view, source in zip(VIEWS, views):
        target = where / f"{code}_{view}.png"
        if not target.exists() or target.stat().st_size != source.stat().st_size:
            shutil.copyfile(source, target)
        out.append(judge.Picture(target, f"{view} view" + (
            " (a nearer look at one quarter)" if view == "close" else "")))
    return tuple(out)


def ask(brief_text: str, number: str, first: tuple[str, tuple[judge.Picture, ...]],
        second: tuple[str, tuple[judge.Picture, ...]], into: Path, model: str,
        canned: Path | None = None, question: Question = SETS) -> pairwise.Verdict | None:
    """One ordered pair asked once, or read back from into/."""
    (a_key, a), (b_key, b) = first, second
    done = into / f"{pairwise.opaque(a_key)}-{pairwise.opaque(b_key)}.json"
    if done.exists():
        return pairwise.Verdict.from_dict(json.loads(done.read_text()))
    text = prompt(brief_text, a, b, question)
    where = BLIND / pairwise.opaque(f"realset:{number}")
    error = ""
    for attempt in (1, 2):
        if canned is not None:
            reply, seconds = json.loads(canned.read_text()), 0.0
        else:
            bench.say(f"judge {number}: {pairwise.opaque(a_key)} v {pairwise.opaque(b_key)} "
                      f"(attempt {attempt})")
            try:
                reply, seconds = judge.call(text, where, [where], model=model,
                                            schema=question.schema())
            except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as failed:
                error = str(failed)
                continue
        try:
            verdict = parse(reply, a_key, b_key, question.dims)
        except ValueError as failed:
            error = str(failed)
            continue
        used = sorted((reply.get("modelUsage") or {}).keys()) if isinstance(reply, dict) else []
        into.mkdir(parents=True, exist_ok=True)
        (into / "prompt_example.txt").write_text(text)
        bench._write_json(done, {**verdict.as_dict(), "prompt": question.version,
                                 "model": ", ".join(used) or ("canned" if canned else model),
                                 "seconds": round(seconds, 1)})
        return verdict
    bench.say(f"judge {number}: no readable reply ({error[:160]})")
    return None


def both_orders(brief_text: str, number: str, x: tuple[str, tuple[judge.Picture, ...]],
                y: tuple[str, tuple[judge.Picture, ...]], into: Path, model: str,
                canned: Path | None = None, question: Question = SETS) -> list[pairwise.Verdict]:
    found = [ask(brief_text, number, x, y, into, model, canned, question),
             ask(brief_text, number, y, x, into, model, canned, question)]
    return [v for v in found if v is not None]


# -- the set's side -------------------------------------------------------------


def set_side(c: Candidate, parts: style.Parts, software: bool, measure: bool = True,
             later: bool = False) -> dict:
    """The set's footprint, pictures, measures and check, made once for every arm.
    Calibration needs only its pictures (`measure` False: nothing under heavy);
    `later` measures it now and leaves the check's reading to `audit`."""
    where = SETS_DIR / c.number
    where.mkdir(parents=True, exist_ok=True)
    done = where / "set.json"
    record = json.loads(done.read_text()) if done.exists() else {}
    source = FILES / c.file
    text = source.read_text(errors="replace")
    if "plan" not in record:
        record.update({"number": c.number, "name": c.name, "theme": c.theme, "year": c.year,
                       "parts": c.parts, "kind": c.kind, "plan": list(footprint(text, parts))})
        bench._write_json(done, record)
    views = bench.render(source, where / "set", where / "set_render.log", software)
    record["views"] = [str(v) for v in views]
    if measure and later and "measures" not in record:
        record["measures"] = measures(text, parts)
    elif measure and not later and ("measures" not in record
                                    or "floating" not in record["measures"]):
        rows = audit([source], where / "audit.jsonl", where / "audit_godot.log")
        record["measures"] = _with_floating(measures(text, parts), rows.get(source.name))
    bench._write_json(done, record)
    return record


# -- an arm's run ---------------------------------------------------------------


def arm_dir(date: str, arm: str) -> Path:
    return RESULTS / f"realset-{date}-{arm}"


def _held_out_said(log: str, number: str) -> bool:
    return f"real sets: holding out {number}" in log


# -- the owner's path: the app as a connector tab -----------------------------

# The relay's account helper and server, of this checkout: the relay is the
# deployment's code, never an arm's.
RELAY_ACCOUNT = ROOT / "tools" / "web" / "relay_account.mjs"
RELAY_SERVER = ROOT / "tools" / "web" / "relay_server.mjs"
# Claude Code waits this long for a tool, as the app's own session does
# (src/ai/claude_code.gd TOOL_TIMEOUT_MS); the relay makes a long call a job.
TOOL_TIMEOUT_MS = 600000
# How long a tab may take to sign in and switch its connector on.
TAB_WAIT_S = 300
# Who may see what the session is given: Claude Code, never the project's keys.
SECRETS = re.compile(r"^(SUPABASE_|RESEND_|VERCEL_|BW_)|SECRET")


def _node(*args: str, timeout: int = 120) -> subprocess.CompletedProcess:
    return subprocess.run(["node", f"--env-file={ROOT / '.env'}", *args], cwd=ROOT,
                          capture_output=True, text=True, timeout=timeout)


def _until(test, seconds: float, every: float = 2.0) -> bool:
    end = time.time() + seconds
    while time.time() < end:
        if test():
            return True
        time.sleep(every)
    return False


def _as_claude(origin: str, token: str, method: str, params: dict) -> dict:
    """One MCP request to the relay as the account's Claude, or {} when it failed."""
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    asked = urllib.request.Request(f"{origin}/api/mcp", data=body, method="POST", headers={
        "content-type": "application/json", "accept": "application/json",
        "authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(asked, timeout=60) as answer:
            return json.loads(answer.read().decode())
    except (OSError, ValueError):
        return {}


def _tab_open(origin: str, token: str) -> bool:
    """Whether the account has a tab listening, as the relay's tabs tool says."""
    said = _as_claude(origin, token, "tools/call", {"name": "tabs", "arguments": {}})
    result = said.get("result") or {}
    text = " ".join(b.get("text", "") for b in result.get("content", []) if isinstance(b, dict))
    return not result.get("isError") and ("tab is open" in text or "tabs are open" in text)


def _ask_app(port: int, tool: str, arguments: dict) -> dict:
    """One call on the app's own port (src/net/command_socket.gd), as tools/brick.py makes one."""
    with socket.create_connection(("127.0.0.1", port), timeout=180) as sock:
        sock.sendall(json.dumps({"id": 1, "tool": tool, "input": arguments}).encode() + b"\n")
        got = b""
        while b"\n" not in got:
            chunk = sock.recv(1 << 16)
            if not chunk:
                break
            got += chunk
    return json.loads(got.split(b"\n", 1)[0] or b"{}")


def _stop(process: subprocess.Popen | None) -> None:
    """A process started in a session of its own, and everything it started."""
    if process is None or process.poll() is not None:
        return
    for sig, wait in ((signal.SIGTERM, 30), (signal.SIGKILL, 10)):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            return
        try:
            process.wait(wait)
            return
        except subprocess.TimeoutExpired:
            continue


def _parts_of(model: Path) -> list[str]:
    """A saved model's part lines, sorted: what it is, whatever the file's header says."""
    if not model.exists():
        return []
    return sorted(line.strip() for line in model.read_text(errors="replace").splitlines()
                  if re.match(r"^1 .*\.dat\s*$", line.strip(), re.I))


def _changed_anything(stream: Path) -> bool:
    """Whether a session called any tool that changes the model (none read-only by its
    annotations, tools/mcp_tools.json), from its stream."""
    tools = json.loads((ROOT / "tools" / "mcp_tools.json").read_text())
    looks = {t["name"] for t in tools if (t.get("annotations") or {}).get("readOnlyHint")}
    for line in stream.read_text(errors="replace").splitlines() if stream.exists() else []:
        try:
            content = (json.loads(line).get("message") or {}).get("content")
        except (ValueError, AttributeError):
            continue
        for block in content if isinstance(content, list) else []:
            if block.get("type") == "tool_use":
                name = str(block.get("name", "")).rsplit("__", 1)[-1]
                if name not in looks and name not in ("tabs", "select_tab", "job"):
                    return True
    return False


def _two_ports() -> tuple[int, int]:
    """The relay's port and the app's. A worker's ports from its last design are its own
    again, but the servers there closed connections, and a port waits out TIME_WAIT for a
    minute before bench's check will bind it: 7630's second design found no free port in
    four (2026-10-26). So it waits for them, up to three minutes."""
    end = time.time() + 180
    while True:
        taken: list[int] = []
        try:
            taken.append(bench._free_port())
            taken.append(bench._free_port())
            return taken[0], taken[1]
        except SystemExit:
            for port in taken:
                bench._port_back(port)
            if time.time() > end:
                raise
            time.sleep(10)


def _session_end(stream: Path) -> dict:
    """The end of a Claude Code session, from its stream-json: the result event."""
    if not stream.exists():
        return {}
    for line in reversed(stream.read_text(errors="replace").splitlines()):
        try:
            said = json.loads(line)
        except ValueError:
            continue
        if said.get("type") == "result":
            return said
    return {}


# What a session's tool call answers when the relay itself could not reach
# Supabase (tools/web/relay_server.mjs), as Claude Code words it.
RELAY_LOST = '{"error":"fetch failed"}'


def relay_lost(stream: Path) -> bool:
    """Whether a session ended on the relay's lost connection: its last tool answer is the
    relay failing to reach Supabase. critic315's excavator stopped so after 8 minutes, said
    "the Brickworks app stopped answering" and was recorded as a design with no model
    (2026-10-28), while this box could reach no Cloudflare address, the Supabase hosts
    among them, on and off from about 08:21Z to 10:31Z, for every arm at once."""
    last = ""
    for line in stream.read_text(errors="replace").splitlines() if stream.exists() else []:
        try:
            content = (json.loads(line).get("message") or {}).get("content")
        except (ValueError, AttributeError):
            continue
        for block in content if isinstance(content, list) else []:
            if isinstance(block, dict) and block.get("type") == "tool_result":
                said = block.get("content")
                last = (" ".join(b.get("text", "") for b in said if isinstance(b, dict))
                        if isinstance(said, list) else str(said))
    return RELAY_LOST in last


def design_via_relay(subject: suite.Subject, run_dir: Path, timeout: int, app: Path,
                     instructions: str = "all") -> dict:
    """One brief designed as the owner designs: Claude through the connector relay, the
    app a signed-in tab of a throwaway account. Recorded in design.json as bench.design
    records one, with the session's own stream beside it (session.jsonl)."""
    done = run_dir / "design.json"
    if done.exists():
        return json.loads(done.read_text())
    relay_port, app_port = _two_ports()
    origin = f"http://127.0.0.1:{relay_port}"
    tab_home = Path(os.environ["XDG_DATA_HOME"]) / f"relay-{subject.id}-{app_port}"
    user_dir = tab_home / "godot" / "app_userdata" / "Brickworks"
    log, stream, relay_log = run_dir / "design.log", run_dir / "session.jsonl", run_dir / "relay.log"
    relay = tab = None
    account: dict = {}
    result: dict = {}
    sha = bench.commit(app)
    bench.say(f"design {subject.id} via the relay: ports {relay_port} and {app_port}, "
              f"instructions {instructions}, up to {timeout // 60} min")
    try:
        with relay_log.open("w") as out:
            relay = subprocess.Popen(
                ["node", f"--env-file={ROOT / '.env'}", str(RELAY_SERVER), str(relay_port),
                 *(["--instructions=none"] if instructions == "none" else [])],
                cwd=ROOT, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
        if not _until(lambda: "functions on" in relay_log.read_text(errors="replace"), 30, 0.5):
            raise SystemExit(f"design {subject.id}: the relay never listened; see {relay_log}")
        opened = _node(str(RELAY_ACCOUNT), "open", f"--origin={origin}")
        if opened.returncode != 0:
            raise SystemExit(f"design {subject.id}: no throwaway account: {opened.stderr[-400:]}")
        account = json.loads(opened.stdout.strip().splitlines()[-1])
        # Signed in as a returning visitor's app is (src/account/account.gd).
        user_dir.mkdir(parents=True, exist_ok=True)
        (user_dir / "session.json").write_text(json.dumps(account["kept"]))
        with log.open("w") as out:
            tab = subprocess.Popen(
                ["godot", "--headless", "--path", str(app), "--log-file",
                 str(run_dir / "godot_design.log"), "--", f"--mcp={app_port}", "--assistant=on",
                 "--signed-in", f"--held-out={subject.id}", "--draw-by=" + json.dumps(bench.DRAWER)],
                cwd=app, stdout=out, stderr=subprocess.STDOUT, start_new_session=True,
                env=bench._billing_free_env(XDG_DATA_HOME=str(tab_home),
                                            BRICKWORKS_API=origin, MESA_VK_WSI_DEBUG="sw"))
        if not _until(lambda: tab.poll() is None and _tab_open(origin, account["token"]),
                      TAB_WAIT_S, 3.0):
            raise SystemExit(f"design {subject.id}: the tab never switched its connector on; "
                             f"see {log}")
        config = run_dir / "relay-mcp.json"
        config.write_text(json.dumps({"mcpServers": {"brickworks": {
            "type": "http", "url": f"{origin}/api/mcp", "timeout": TOOL_TIMEOUT_MS,
            "headers": {"Authorization": f"Bearer {account['token']}"}}}}))
        env = {k: v for k, v in bench._billing_free_env().items() if not SECRETS.search(k)}
        env.update(MCP_TOOL_TIMEOUT=str(TOOL_TIMEOUT_MS), MCP_TIMEOUT="120000")
        started = time.time()
        # As the app starts its own session (src/ai/claude_code.gd arguments), the
        # relay its only server and its tools all it may use; in the arm's checkout,
        # as the bench's session is.
        with stream.open("w") as said:
            status = subprocess.run(
                ["timeout", "--kill-after=30", str(timeout), "claude", "-p", subject.brief,
                 "--mcp-config", str(config), "--strict-mcp-config", "--tools", "",
                 "--restricted", "--allowedTools", "mcp__brickworks",
                 "--output-format", "stream-json", "--verbose"],
                cwd=app, env=env, stdout=said, stderr=subprocess.STDOUT).returncode
        seconds = time.time() - started
        ended = _session_end(stream)
        if ended.get("is_error") and "API Error" in str(ended.get("result", "")):
            # Claude's service failed (529 Overloaded), not the design: not recorded,
            # so the same command tries it again.
            raise SystemExit(f"design {subject.id}: {str(ended.get('result'))[:160]}")
        if relay_lost(stream):
            # Nor did the design end itself: the relay lost Supabase under it.
            raise SystemExit(f"design {subject.id}: the relay lost Supabase and the session "
                             "ended on it; not recorded")
        ldr = run_dir / "design.ldr"
        name = f"realset-{subject.id}-{app_port}.ldr"
        saved: dict = {}
        try:
            saved = _ask_app(app_port, "save_model", {"name": name})
        except (OSError, ValueError) as trouble:
            bench.say(f"design {subject.id}: the tab would not save: {trouble}")
        kept = user_dir / "models" / name
        # The tab opens on a first visit's example, which is no design: a session
        # that changed nothing leaves it there, and has made no model.
        if kept.exists() and _parts_of(kept) and _changed_anything(stream):
            shutil.copy(kept, ldr)
        result = {
            "status": status, "seconds": round(seconds, 1), "timed_out": status in (124, 137),
            "design_seconds": int(ended["duration_ms"] / 1000) if ended.get("duration_ms") else None,
            "commit": sha, "port": app_port, "relay_port": relay_port, "via": "relay",
            "instructions": instructions, "model": ldr.exists() and ldr.stat().st_size > 0,
            **({} if app == ROOT else {"app": str(app)}),
            "finished": (f"claude code ok={not ended.get('is_error', True)} "
                         f"turns={ended.get('num_turns')} {ended.get('subtype', '')}: "
                         f"{str(ended.get('result', ''))[:240]}") if ended else "",
            "saved": json.dumps(saved.get("content") or saved.get("error") or "")[:200],
            "transcript": str(stream),
        }
    finally:
        _stop(tab)
        if account.get("user"):
            closed = _node(str(RELAY_ACCOUNT), "close", f"--user={account['user']}")
            result["account_deleted"] = closed.returncode == 0
            if closed.returncode != 0:
                bench.say(f"design {subject.id}: the throwaway account {account.get('email')} "
                          f"was NOT deleted: {closed.stdout} {closed.stderr[-300:]}")
        _stop(relay)
        bench._port_back(relay_port)
        bench._port_back(app_port)
    result["pictures_given_up"] = bench.pictures_given_up(run_dir / "godot_design.log")
    bench._write_json(done, result)
    shutil.rmtree(tab_home, ignore_errors=True)
    bench.say(f"design {subject.id} via the relay: status {result['status']} in "
              f"{result['seconds'] / 60:.1f} min, {'a model' if result['model'] else 'NO MODEL'}")
    return result


def one(c: Candidate, args: argparse.Namespace, parts: style.Parts) -> dict:
    """A subject end to end on one arm: the set's side, the design, its pictures, its
    measures, and the judge both orders. Each stage is skipped when its output is there."""
    out = arm_dir(args.date, args.arm) / c.number
    out.mkdir(parents=True, exist_ok=True)
    record_path = out / "record.json"
    if record_path.exists() and not args.rejudge:
        return json.loads(record_path.read_text())
    the_set = set_side(c, parts, args.software, later=args.audit_later)
    plan = (int(the_set["plan"][0]), int(the_set["plan"][1]))
    subject = subject_of(c, plan)
    bench._write_json(out / "brief.json", {"number": c.number, "brief": subject.brief,
                                           "title": subject.title, "kind": c.kind,
                                           "theme": c.theme, "year": c.year})
    canned = bench.CANNED / "design.ldr" if args.dry_run else None
    try:
        made = (design_via_relay(subject, out, args.timeout, args.checkout, args.instructions)
                if args.via == "relay" and canned is None else
                bench.design(subject, out, args.timeout, canned, app=args.checkout))
    except SystemExit as failed:      # the machine failed, not the design: tried again next time
        bench.say(f"{c.number}: {failed}")
        return {}
    log = (out / "design.log").read_text(errors="replace") if (out / "design.log").exists() else ""
    record = {"number": c.number, "name": c.name, "theme": c.theme, "year": c.year,
              "kind": c.kind, "brief": subject.brief, "arm": args.arm, "date": args.date,
              "design": made, "held_out_said": _held_out_said(log, c.number),
              "set": {"parts": c.parts, "plan": the_set["plan"],
                      "measures": the_set.get("measures", {})}}
    if not made.get("model"):
        record["verdicts"] = []
        record["note"] = "no model was produced: every verdict goes to the set"
        bench._write_json(record_path, record)
        return record
    design = out / "design.ldr"
    views = bench.render(design, out / "views", out / "views_render.log", args.software)
    if len(views) < len(VIEWS) or len(the_set["views"]) < len(VIEWS):
        bench.say(f"{c.number}: missing pictures; see {out}/views_render.log and "
                  f"{SETS_DIR / c.number}/set_render.log")
        return {}
    rows = {} if args.audit_later else audit([design], out / "audit.jsonl",
                                             out / "audit_godot.log")
    record["measures"] = _with_floating(measures(design.read_text(errors="replace"), parts),
                                        rows.get(design.name))
    if args.no_judge:
        bench._write_json(record_path.with_name("unjudged.json"), record)
        return record
    ours_key, set_key = f"{args.arm}:{args.date}:{c.number}", f"set:{c.number}"
    ours = (ours_key, shown(ours_key, views, c.number))
    real = (set_key, shown(set_key, [Path(v) for v in the_set["views"]], c.number))
    found = both_orders(subject.brief, c.number, ours, real, out / "judged", args.judge_model,
                        CANNED_PAIR if args.dry_run else None)
    record["keys"] = {"ours": ours_key, "set": set_key}
    record["verdicts"] = [v.as_dict() for v in found]
    if len(found) < 2:
        bench.say(f"{c.number}: {len(found)} of 2 verdicts; run the same command again")
        return record
    bench._write_json(record_path, record)
    won = {d: sum(v.winners[d] == ours_key for v in found) for d in DIMS}
    bench.say(f"{c.number} {c.name}: ours won " + ", ".join(f"{d} {won[d]}/2" for d in DIMS))
    return record


def _imported(checkout: Path) -> None:
    """The arm's checkout with its class list up to date before any design starts. A
    snapshot worktree is never imported by being made, and every design of one that
    wasn't hit a parse error and timed out with nothing made: main292t and design300t,
    2.5 hours each (2026-10-27). fresh_import.sh imports only when the list is behind."""
    script = checkout / "tools" / "fresh_import.sh"
    if not script.exists():
        bench.say(f"{checkout} has no tools/fresh_import.sh: its class list is not checked")
        return
    if subprocess.run(["bash", str(script)], cwd=checkout).returncode:
        raise SystemExit(f"{checkout}: its class list could not be brought up to date")


def run(args: argparse.Namespace) -> int:
    if not args.software and subprocess.run([bench.GPU, "--held"]).returncode == 0:
        bench.say("realset: this run is inside a GPU lease and holds it to the end; run it bare "
                  "and each design and drawing takes the lease for itself")
    if not args.dry_run and not os.environ.get("XDG_DATA_HOME"):
        raise SystemExit("set XDG_DATA_HOME to a folder of this run's: a design must never "
                         "write into the owner's app folder")
    wanted = _wanted(args.which, args.subjects, args.first)
    if args.share:          # "K/N": every Nth subject from the Kth, so a half splits unseen
        k, n = (int(x) for x in args.share.split("/"))
        wanted = wanted[k::n]
    parts = style.Parts()
    out = arm_dir(args.date, args.arm)
    out.mkdir(parents=True, exist_ok=True)
    if args.what == "one":
        if not (out / "arm.json").exists():
            bench._write_json(out / "arm.json", {"arm": args.arm, "checkout": str(args.checkout),
                                                 "commit": bench.commit(args.checkout),
                                                 "date": args.date, "via": args.via,
                                                 "instructions": args.instructions})
        for c in wanted:
            bench.say(f"{c.number} {c.name}: starting")
            try:
                one(c, args, parts)
            except Exception as failed:  # noqa: BLE001 - one subject's fault stops only it
                bench.say(f"{c.number}: failed: {failed!r}")
        return 0
    bench._write_json(out / "arm.json", {"arm": args.arm, "checkout": str(args.checkout),
                                         "commit": bench.commit(args.checkout),
                                         "which": args.which, "date": args.date,
                                         "via": args.via, "instructions": args.instructions})
    bench.say(f"realset {args.which}: {len(wanted)} subjects on {args.arm} "
              f"({bench.commit(args.checkout)}), {args.jobs} at a time, into {out}")
    jobs = max(1, min(args.jobs, len(wanted)))
    with ThreadPoolExecutor(max_workers=jobs) as workers:
        list(workers.map(lambda share: _in_a_slot(share, args),
                         [wanted[k::jobs] for k in range(jobs)]))
    done = sum(1 for c in wanted if (out / c.number / "record.json").exists())
    bench.say(f"realset {args.which}: {done} of {len(wanted)} recorded")
    text = report_arm(args.which, args.date, args.arm, args.first)
    (out / _report_name(args)).write_text(text)
    print(text)
    return 0


def _in_a_slot(share: list[Candidate], args: argparse.Namespace) -> int:
    """A worker's subjects end to end, one after another. On the GPU each design and
    each drawing takes the lease for itself and it holds no CPU slot;
    in software it is one `heavy` job, each design, check and drawing taking the slot it
    holds, so it queues for the machine once and --jobs is the slots held."""
    out = arm_dir(args.date, args.arm)
    for c in share:
        (out / c.number).mkdir(parents=True, exist_ok=True)
    command = [*([bench.HEAVY] if args.software else []), sys.executable,
               str(Path(__file__).resolve()), "one",
               "--which", args.which, "--arm", args.arm, "--date", args.date,
               "--judge-model", args.judge_model,
               "--subjects", ",".join(c.number for c in share),
               "--checkout", str(args.checkout), "--timeout", str(args.timeout),
               *(["--software"] if args.software else []),
               *(["--audit-later"] if args.audit_later else []),
               *(["--dry-run"] if args.dry_run else []),
               *(["--no-judge"] if args.no_judge else []),
               *(["--rejudge"] if args.rejudge else []),
               "--via", args.via, "--instructions", args.instructions]
    named = ", ".join(c.number for c in share)
    bench.say(f"{named}: queued")
    log_path = out / f"worker-{share[0].number}.log"
    with log_path.open("a") as log:
        status = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
    left = [c.number for c in share if not (out / c.number / "record.json").exists()]
    bench.say(f"{named}: ended {status}"
              + (f"; not recorded: {', '.join(left)} (see {log_path})" if left else ""))
    return status


def _report_name(args: argparse.Namespace) -> str:
    return f"report-{args.which}" + (f"-first{args.first}" if args.first else "") + ".md"


def _wanted(which: str, subjects: str, first: int = 0) -> list[Candidate]:
    half = sample(which, first)
    if not subjects:
        return half
    named = [s.strip() for s in subjects.split(",") if s.strip()]
    by = {c.number: c for c in half}
    missing = [n for n in named if n not in by]
    if missing:
        raise SystemExit(f"not in the {which} half: {', '.join(missing)}")
    return [by[n] for n in named]


def audit_later(args: argparse.Namespace) -> int:
    """The build check's reading of every recorded design of an arm, and of each set,
    that a run left for later (--audit-later): run under one `heavy`, each model's
    check takes the slot it holds. The records' measures gain their floating parts."""
    parts = style.Parts()
    done = 0
    for c in _wanted(args.which, args.subjects, args.first):
        where = SETS_DIR / c.number / "set.json"
        if where.exists():
            record = json.loads(where.read_text())
            if "floating" not in record.get("measures", {}):
                source = FILES / c.file
                rows = audit([source], SETS_DIR / c.number / "audit.jsonl",
                             SETS_DIR / c.number / "audit_godot.log")
                record["measures"] = _with_floating(
                    measures(source.read_text(errors="replace"), parts), rows.get(source.name))
                bench._write_json(where, record)
        out = arm_dir(args.date, args.arm) / c.number
        path = out / "record.json"
        if not path.exists():
            continue
        record = json.loads(path.read_text())
        theirs = json.loads(where.read_text()).get("measures", {}) if where.exists() else {}
        record["set"]["measures"] = theirs or record["set"].get("measures", {})
        design = out / "design.ldr"
        if design.exists() and "floating" not in record.get("measures", {}):
            rows = audit([design], out / "audit.jsonl", out / "audit_godot.log")
            record["measures"] = _with_floating(
                measures(design.read_text(errors="replace"), parts), rows.get(design.name))
        bench._write_json(path, record)
        done += 1
    bench.say(f"audit: {done} records read again")
    text = report_arm(args.which, args.date, args.arm, args.first)
    (arm_dir(args.date, args.arm) / _report_name(args)).write_text(text)
    print(text)
    return 0


# -- calibration ----------------------------------------------------------------


def calibrate_half(args: argparse.Namespace) -> int:
    """Each set of the half against a naive stack of itself, both orders: the judge must
    name the set on every dimension, or a win rate against sets means nothing."""
    wanted = _wanted(args.which, args.subjects, args.first)
    parts = style.Parts()
    colours = calibrate.palette()

    def pair(c: Candidate) -> list[pairwise.Verdict]:
        the_set = set_side(c, parts, args.software, measure=False)
        where = SETS_DIR / c.number
        naive = where / "naive.ldr"
        if not naive.exists():
            made, said = calibrate.naive_stack((FILES / c.file).read_text(errors="replace"),
                                               parts, colours)
            naive.write_text(made)
            bench._write_json(where / "naive.json", {"made": said})
        views = bench.render(naive, where / "naive", where / "naive_render.log", args.software)
        if len(views) < len(VIEWS):
            bench.say(f"{c.number}: no pictures of the naive stack")
            return []
        plan = (int(the_set["plan"][0]), int(the_set["plan"][1]))
        real = (f"set:{c.number}", shown(f"set:{c.number}", [Path(v) for v in the_set["views"]],
                                         c.number))
        stack = (f"naive:{c.number}", shown(f"naive:{c.number}", views, c.number))
        return both_orders(brief(c, plan), c.number, real, stack, where / "calibration",
                           args.judge_model, CANNED_PAIR if args.dry_run else None)

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as workers:
        found = [v for got in workers.map(pair, wanted) for v in got]
    text = calibration_report(wanted, found)
    SETS_DIR.mkdir(parents=True, exist_ok=True)
    (SETS_DIR / f"calibration-{args.which}.md").write_text(text)
    print(text)
    return 0


def calibration_report(wanted: list[Candidate], found: list[pairwise.Verdict]) -> str:
    right = {d: sum(v.winners[d].startswith("set:") for v in found) for d in DIMS}
    every = sum(right.values())
    of = len(found) * len(DIMS)
    low, high = pairwise.wilson(every, of)
    out = [f"# The judge on real sets against naive stacks of themselves ({len(wanted)} sets)", "",
           f"Verdicts naming the set: {pairwise.share(every, of)}, 95% {100 * low:.0f}-"
           f"{100 * high:.0f}%.", "", "| dimension | verdicts naming the set |", "|---|---|"]
    out += [f"| {d} | {pairwise.share(right[d], len(found))} |" for d in DIMS]
    out += ["", "| set | name | verdicts | overall to the set |", "|---|---|---|---|"]
    for c in wanted:
        mine = [v for v in found if v.first.endswith(f":{c.number}")]
        out.append(f"| {c.number} | {c.name} | {len(mine)} | "
                   f"{sum(v.winners['overall'].startswith('set:') for v in mine)} |")
    return "\n".join(out) + "\n"


# -- reading an arm -------------------------------------------------------------


def records(which: str, date: str, arm: str, first: int = 0) -> list[dict]:
    out = []
    for c in sample(which, first):
        path = arm_dir(date, arm) / c.number / "record.json"
        if path.exists():
            out.append(json.loads(path.read_text()))
    return out


def shares(found: list[dict], dim: str) -> list[float]:
    """Per subject, the share of its verdicts our design won on one dimension; a subject
    with no model counts 0, as the person got nothing."""
    out = []
    for r in found:
        said = r.get("verdicts", [])
        ours = r.get("keys", {}).get("ours")
        if not said:
            out.append(0.0)
            continue
        out.append(sum(v["winners"][dim] == ours for v in said) / len(said))
    return out


def win_rate(values: list[float]) -> tuple[float, float, float]:
    """The mean share and its 95% Wilson interval over subjects."""
    if not values:
        return (float("nan"), 0.0, 1.0)
    n, z = len(values), 1.96
    p = sum(values) / n         # pairwise.wilson's formula, for a share that need not be whole
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return (p, max(0.0, centre - half), min(1.0, centre + half))


def _median(values: list[float]) -> float | None:
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def _cell(value: float | None, share: bool) -> str:
    if value is None:
        return ""
    return f"{100 * value:.0f}%" if share else f"{value:.1f}" if value % 1 else f"{value:.0f}"


SHARE_MEASURES = {"shaped", "one_by_one", "tile", "snot", "angle_parts", "angled",
                  "floating_share"}


def report_arm(which: str, date: str, arm: str, first: int = 0) -> str:
    found = records(which, date, arm, first)
    meta = arm_dir(date, arm) / "arm.json"
    commit = json.loads(meta.read_text()).get("commit", "?") if meta.exists() else "?"
    said = f"{which} half" + (f", its first {first}" if first else "")
    out = [f"# Real sets, {said}: {arm} ({commit}), {date}", "",
           f"{len(found)} of {len(sample(which, first))} subjects recorded; the judge saw each design "
           "and the set both ways round, not told which was which.", "",
           "| dimension | our design preferred | 95% |", "|---|---|---|"]
    for dim in DIMS:
        rate, low, high = win_rate(shares(found, dim))
        out.append(f"| {dim} | {100 * rate:.0f}% | {100 * low:.0f}-{100 * high:.0f}% |")
    orders = [r for r in found if len(r.get("verdicts", [])) == 2]
    same = sum(r["verdicts"][0]["winners"][d] == r["verdicts"][1]["winners"][d]
               for r in orders for d in DIMS)
    first = sum(v["winners"][d] == v["first"] for r in found for v in r.get("verdicts", [])
                for d in DIMS)
    every = sum(len(r.get("verdicts", [])) for r in found) * len(DIMS)
    out += ["", f"The two orders named the same model in {pairwise.share(same, len(orders) * len(DIMS))}"
            f" of dimensions; the model shown first won {pairwise.share(first, every)}."]
    out += ["", "Each subject: building parts (figures left out, as tools/style.py counts), the "
            "design's minutes, and the verdicts our design won of those asked.", "",
            "| set | subject | kind | set's parts | ours | minutes | " + " | ".join(DIMS) + " |",
            "|" + "---|" * (6 + len(DIMS))]
    for r in found:
        ours = r.get("keys", {}).get("ours")
        made = r.get("design", {})
        cells = [f"{sum(v['winners'][d] == ours for v in r.get('verdicts', []))}/"
                 f"{len(r.get('verdicts', []))}" for d in DIMS]
        mins = made.get("design_seconds") or made.get("seconds") or 0
        theirs = r["set"].get("measures", {}).get("parts", r["set"]["parts"])
        out.append(f"| {r['number']} | {r['name']} | {r.get('kind') or ''} | {theirs} | "
                   f"{r.get('measures', {}).get('parts', 0)} | {mins / 60:.0f} | "
                   + " | ".join(cells) + " |")
    out += ["", "What they are made of, the median over subjects: ours, the set's, and the "
            "median of ours minus the set's, subject by subject.", "",
            "| measure | ours | sets | difference |", "|---|---|---|---|"]
    for key in MEASURES:
        ours = [r.get("measures", {}).get(key) for r in found if r.get("measures")]
        theirs = [r["set"]["measures"].get(key) for r in found if r.get("measures")]
        gaps = [a - b for a, b in zip(ours, theirs) if a is not None and b is not None]
        share = key in SHARE_MEASURES
        gap = _median(gaps)
        out.append(f"| {key} | {_cell(_median(ours), share)} | {_cell(_median(theirs), share)} | "
                   + (f"{'+' if gap >= 0 else ''}{_cell(gap, share)}" if gap is not None else "")
                   + " |")
    out += ["", gave_up_said(found)]
    held = [r["number"] for r in found if r.get("design", {}).get("model")
            and not r.get("held_out_said")]
    if held:
        out += ["", f"No hold-out line in the design log of {', '.join(held)}: either the "
                "session never searched the real-set index, or its checkout cannot hold a set "
                "out (src/ai/real_snippets.gd)."]
    return "\n".join(out) + "\n"


def gave_up_said(found: list[dict]) -> str:
    """How many pictures the arm's designs were shown as letters because none came in
    time (run.py's pictures_given_up): a design shown letters judges worse, so a lever
    compared on an arm that had them is compared with that against it."""
    counted = [r for r in found if "pictures_given_up" in r.get("design", {})]
    had = [(r["number"], int(r["design"]["pictures_given_up"])) for r in counted
           if r["design"]["pictures_given_up"]]
    said = (f"Pictures given up for the letters (no drawer in time): "
            f"{sum(n for _, n in had)} over {len(counted)} designs counted")
    said += (", in " + ", ".join(f"{number} ({n})" for number, n in had) if had else ", none")
    if len(counted) < len(found):
        said += f"; {len(found) - len(counted)} recorded before the count was kept"
    return said + "."


# -- what the sessions reached --------------------------------------------------

# A lever is a tool, a pattern or a line of guidance; whether a session ever used it
# is in its transcript, not its pictures. On main's and main2's 88 proof designs
# (design281, 2026-10-26) "angle" was read twice and "round" never, 9 of 300
# features took the app's piece, and 82 designs turned under 5% of their parts off
# the grid where the sets turn a median 11%.
PROJECTS = Path.home() / ".claude" / "projects"


def _turned(sections: object) -> bool:
    """Whether a build's sections turn any of them off the grid: an angle that is not a
    whole number of right angles (a section folded 90 degrees on a hinge is square)."""
    found = list(sections.values()) if isinstance(sections, dict) else sections
    for one in found if isinstance(found, list) else []:
        for key in ("yaw", "pitch", "roll", "degrees"):
            angle = one.get(key, 0) if isinstance(one, dict) else 0
            if isinstance(angle, (int, float)) and abs(angle / 90.0 - round(angle / 90.0)) > 0.01:
                return True
    return False


# The words the connector's working method begins with (src/ai/assistant.gd METHOD).
METHOD_SAID = "How to work here, said once"
BUILDS = ("submit_design", "edit_model")


def session_reach(lines: list[str]) -> dict:
    """What one Claude Code session called, from its transcript's lines: the guide
    sections it read, the builds that turned a section and how many were refused, the
    technique calls, how it settled features, and the floor of its first build. And
    whether it worked by the method (HOW TO WORK): how_real_sets_build_this before its
    first build, review_model, settle_feature, a part count given; and whether a tool's
    answer told it the method. A transcript writes each call more than once; each is
    counted once."""
    calls: dict[str, tuple[str, dict]] = {}
    refused: set[str] = set()
    told = False
    laid: set[str] = set()
    for line in lines:
        message = json.loads(line).get("message", {})
        content = message.get("content") if isinstance(message, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if block.get("type") == "tool_use" and block["id"] not in calls:
                calls[block["id"]] = (block["name"].rsplit("__", 1)[-1], block.get("input", {}))
            elif block.get("type") == "tool_result":
                said = block.get("content")
                if isinstance(said, list):
                    said = " ".join(b.get("text", "") for b in said if isinstance(b, dict))
                if str(said).startswith("Not applied"):
                    refused.add(block.get("tool_use_id"))
                told = told or METHOD_SAID in str(said)
                # A real piece laid: its bricks "as laid", and no refusal of the edit.
                if "as laid" in str(said).lower() and "Not applied" not in str(said):
                    laid.add(block.get("tool_use_id"))
    named = Counter(name for name, _ in calls.values())
    turned = [i for i, (name, given) in calls.items()
              if name in ("submit_design", "edit_model")
              and _turned(given.get("sections", []))]
    first = next((given for name, given in calls.values() if name == "submit_design"), {})
    order = [name for name, _ in calls.values()]
    built = next((i for i, name in enumerate(order) if name in BUILDS), len(order))
    # Each feature by the verdict it ended on (a feature accepted in three calls, adjusting
    # it, is one), over the features the last build listed.
    listed = next((given.get("features") for name, given in reversed(list(calls.values()))
                   if name == "submit_design" and given.get("features")), []) or []
    ended: dict[str, str] = {}
    for name, given in calls.values():
        if name == "settle_feature":
            for one in str(given.get("feature", "")).split(","):
                ended[one.strip().lower()] = str(given.get("verdict"))
    return {"calls": len(calls),
            "method": {"real_first": "how_real_sets_build_this" in order[:built],
                       "reviews": named["review_model"], "settled": named["settle_feature"],
                       "passes": sorted({k for n, g in calls.values() if n == "review_model"
                                         for k in ("assembly", "surface", "creative") if g.get(k)}),
                       "parts": any("parts" in g for n, g in calls.values() if n == "submit_design"),
                       "told": told},
            "guide": sorted({str(g.get("section", "")) for n, g in calls.values()
                             if n == "read_guide"}),
            "turned_builds": len(turned), "turned_refused": len(refused & set(turned)),
            "techniques": {k: named[k] for k in ("find_techniques", "show_technique",
                                                 "place_technique")},
            "placed": sum(1 for i, (name, _) in calls.items()
                          if name == "place_technique" and i in laid),
            "features_listed": len(listed),
            "features_accepted": sum(1 for v in ended.values() if v == "accept"),
            "features": dict(Counter(str(g.get("verdict")) for n, g in calls.values()
                                     if n == "settle_feature")),
            "floor": str(first.get("floor", ""))}


def transcript_of(record: dict) -> Path | None:
    """The session that made a recorded design: its own stream, kept beside it by a run
    --via relay (design.json's `transcript`), or else as Claude Code keeps it under its working
    directory, the checkout whose app designed (design.json's `app`, else the arm's own,
    read from the arm the record names: proof's first ten in main's are t2base's), as
    the transcript whose first message is the brief, the last begun before the design
    was written."""
    kept = record.get("design", {}).get("transcript")
    if kept and Path(kept).exists():
        return Path(kept)
    relayed = _relayed_sessions()
    where = arm_dir(record["date"], record["arm"])
    meta = where / "arm.json"
    checkout = (record.get("design", {}).get("app")
                or (json.loads(meta.read_text()).get("checkout") if meta.exists() else None)
                or str(ROOT))
    design = where / record["number"] / "design.json"
    until = design.stat().st_mtime + 60 if design.exists() else float("inf")
    best: tuple[float, Path] | None = None
    for path in (PROJECTS / re.sub(r"[/.]", "-", str(checkout))).glob("*.jsonl"):
        if path.stem in relayed:
            continue
        with path.open(errors="replace") as lines:
            for line in lines:
                said = json.loads(line)
                if said.get("type") != "user":
                    continue
                if said.get("message", {}).get("content") == record["brief"]:
                    began = datetime.datetime.fromisoformat(
                        said["timestamp"].replace("Z", "+00:00")).timestamp()
                    if began <= until and (best is None or began > best[0]):
                        best = (began, path)
                break
    return best[1] if best else None


def _relayed_sessions() -> set[str]:
    """The Claude Code sessions of runs --via relay, by id: each is kept with its design,
    and runs in the arm's checkout too, where a bench session of the same brief at the
    same time would otherwise be taken for it."""
    found = set()
    for stream in RESULTS.glob("realset-*/*/session.jsonl"):
        with stream.open(errors="replace") as lines:
            first = lines.readline()
        try:
            found.add(str(json.loads(first).get("session_id", "")))
        except ValueError:
            continue
    return found


def turned_share(text: str, parts: style.Parts) -> float:
    """The share of a model's parts turned off its grid (tools/style.py's `angled`)."""
    return float(style.measure(style.read(text), parts).get("angled") or 0.0)


def reach_report(which: str, date: str, arm: str, first: int = 0) -> str:
    found = records(which, date, arm, first)
    parts = style.Parts()
    by = {c.number: c for c in sample(which, first)}
    out = [f"# What {arm}'s sessions reached, {which} half, {date}", "",
           "Each subject: overall verdicts won; the share of parts turned off the grid, "
           "ours and the set's; and from its session's transcript the guide sections read, "
           "builds with a turned or hinged section (refused of them), find/show/place "
           "technique calls, features settled, and the first build's floor. Method: "
           "how_real_sets_build_this before the first build (real), review_model calls, "
           "settle_feature calls, a part count given to submit_design, and whether an answer "
           "told the session the method.", "",
           "| set | overall | turned | set's turned | guide | turned builds | techniques "
           "| features | floor | method |", "|" + "---|" * 10]
    ours_turned, sets_turned, guides, turned_any, placed_any, sessions = [], [], Counter(), 0, 0, 0
    method = Counter()
    real_any, listed, accepted = 0, 0, 0
    for r in found:
        design = arm_dir(date, arm) / r["number"] / "design.ldr"
        mine = turned_share(design.read_text(errors="replace"), parts) if design.exists() else None
        theirs = turned_share((FILES / by[r["number"]].file).read_text(errors="replace"),
                              parts) if r["number"] in by else None
        ours_turned.append(mine)
        sets_turned.append(theirs)
        path = transcript_of(r)
        reach = session_reach(path.read_text(errors="replace").splitlines()) if path else None
        ours = r.get("keys", {}).get("ours")
        won = f"{sum(v['winners']['overall'] == ours for v in r.get('verdicts', []))}/" \
              f"{len(r.get('verdicts', []))}"
        if reach is None:
            out.append(f"| {r['number']} | {won} | {_cell(mine, True)} | {_cell(theirs, True)} "
                       "| no transcript found | | | | | |")
            continue
        sessions += 1
        guides.update(reach["guide"])
        turned_any += reach["turned_builds"] > 0
        placed_any += reach["techniques"]["place_technique"] > 0
        # A real piece in the design: one place_technique laid, or a feature's piece accepted.
        real_any += reach["placed"] > 0 or reach["features_accepted"] > 0
        listed += reach["features_listed"]
        accepted += reach["features_accepted"]
        tech = "/".join(str(reach["techniques"][k]) for k in ("find_techniques", "show_technique",
                                                              "place_technique"))
        feats = ", ".join(f"{k} {v}" for k, v in sorted(reach["features"].items()))
        how = reach["method"]
        method.update({k: int(v) for k, v in {
            "real": how["real_first"], "review": how["reviews"] > 0, "settle": how["settled"] > 0,
            "parts": how["parts"], "told": how["told"], **{p: True for p in how["passes"]}}.items()})
        did = (f"real {'yes' if how['real_first'] else 'no'}, review {how['reviews']}"
               + (f" ({', '.join(how['passes'])})" if how["passes"] else "") + ", "
               f"settle {how['settled']}, parts {'yes' if how['parts'] else 'no'}"
               + (", told" if how["told"] else ""))
        out.append(f"| {r['number']} | {won} | {_cell(mine, True)} | {_cell(theirs, True)} | "
                   f"{', '.join(reach['guide'])} | {reach['turned_builds']} "
                   f"({reach['turned_refused']}) | {tech} | {feats} | {reach['floor']} | {did} |")
    out += ["", f"Turned off the grid, the median: ours {_cell(_median(ours_turned), True)}, the "
            f"sets' {_cell(_median(sets_turned), True)}; ours 5% or more in "
            f"{sum(1 for v in ours_turned if v is not None and v >= 0.05)} of {len(found)}.",
            f"Of {sessions} sessions read: {turned_any} built a turned or hinged section, "
            f"{placed_any} placed a real set's technique; guide sections read by how many: "
            + (", ".join(f"{k} {v}" for k, v in guides.most_common()) or "none") + ".",
            f"The method, of {sessions} sessions: how_real_sets_build_this before the first "
            f"build in {method['real']}, review_model in {method['review']} (an assembly's in "
            f"{method['assembly']}, the surface pass in {method['surface']}, the creative pass in "
            f"{method['creative']}), settle_feature in {method['settle']}, a part count given in "
            f"{method['parts']}; told the method by an answer in {method['told']}.",
            f"A real piece in the design (a place_technique laid, or a feature's piece "
            f"accepted): {real_any} of {sessions} sessions. Features accepted: "
            f"{accepted} of the {listed} the last builds listed"
            + (f" ({100 * accepted / listed:.0f}%)" if listed else "") + "."]
    return "\n".join(out) + "\n"


# -- two arms -------------------------------------------------------------------


def compare(args: argparse.Namespace) -> int:
    arms = [a.strip() for a in args.arms.split(",") if a.strip()]
    if len(arms) != 2:
        raise SystemExit("--arms takes two arms: a,b")
    dates = ([d.strip() for d in args.dates.split(",")] if args.dates else [args.date] * 2)
    a_dir, b_dir = arm_dir(dates[0], arms[0]), arm_dir(dates[1], arms[1])
    out = RESULTS / f"realset-{dates[1]}-{arms[0]}-vs-{arms[1]}"
    tasks = []
    for c in sample(args.which, args.first):
        ra, rb = a_dir / c.number / "record.json", b_dir / c.number / "record.json"
        if not (ra.exists() and rb.exists()):
            continue
        x, y = json.loads(ra.read_text()), json.loads(rb.read_text())
        if not (x.get("keys") and y.get("keys")):
            continue
        xa = (x["keys"]["ours"], shown(x["keys"]["ours"],
                                       [a_dir / c.number / f"views_{v}.png" for v in VIEWS],
                                       c.number))
        yb = (y["keys"]["ours"], shown(y["keys"]["ours"],
                                       [b_dir / c.number / f"views_{v}.png" for v in VIEWS],
                                       c.number))
        tasks.append((c, x, y, xa, yb))

    def judged(task) -> tuple:
        c, x, y, xa, yb = task
        return (c, x, y, both_orders(x["brief"], c.number, xa, yb, out / c.number,
                                     args.judge_model, CANNED_PAIR if args.dry_run else None))

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as workers:
        results = list(workers.map(judged, tasks))
    text = compare_report(arms, dates, results, args.which)
    out.mkdir(parents=True, exist_ok=True)
    (out / _report_name(args)).write_text(text)
    print(text)
    return 0


def paired_gap(a: list[float], b: list[float], draws: int = 2000,
               seed: int = 0) -> tuple[float, float, float]:
    """Mean of a minus b over subjects, with a 95% interval from resampling subjects."""
    gaps = [x - y for x, y in zip(a, b)]
    if not gaps:
        return (float("nan"), float("nan"), float("nan"))
    rng = random.Random(seed)
    means = sorted(sum(rng.choice(gaps) for _ in gaps) / len(gaps) for _ in range(draws))
    return (sum(gaps) / len(gaps), means[int(0.025 * (draws - 1))], means[int(0.975 * (draws - 1))])


def compare_report(arms: list[str], dates: list[str], results: list[tuple], which: str) -> str:
    a, b = arms
    xs = [x for _c, x, _y, _v in results]
    ys = [y for _c, _x, y, _v in results]
    out = [f"# Real sets, {which} half: {a} against {b}", "",
           f"{len(results)} subjects with a design of each arm.", "",
           f"Each arm's designs against the set, and the gap, subjects paired:", "",
           f"| dimension | {a} preferred to the set | {b} preferred to the set | {a} minus {b} "
           "(95%) |", "|---|---|---|---|"]
    for dim in DIMS:
        sa, sb = shares(xs, dim), shares(ys, dim)
        ra, rb = win_rate(sa), win_rate(sb)
        gap, low, high = paired_gap(sa, sb)
        out.append(f"| {dim} | {100 * ra[0]:.0f}% ({100 * ra[1]:.0f}-{100 * ra[2]:.0f}) | "
                   f"{100 * rb[0]:.0f}% ({100 * rb[1]:.0f}-{100 * rb[2]:.0f}) | "
                   f"{100 * gap:+.0f} ({100 * low:+.0f}, {100 * high:+.0f}) |")
    out += ["", f"Head to head, both orders: {a}'s design preferred to {b}'s.", "",
            "| dimension | preferred | 95% |", "|---|---|---|"]
    for dim in DIMS:
        per = []
        for _c, x, _y, verdicts in results:
            if verdicts:
                per.append(sum(v.winners[dim] == x["keys"]["ours"] for v in verdicts)
                           / len(verdicts))
        rate, low, high = win_rate(per)
        out.append(f"| {dim} | {100 * rate:.0f}% | {100 * low:.0f}-{100 * high:.0f}% |")
    return "\n".join(out) + "\n"


# -- the command line -----------------------------------------------------------


def _show(which: str, show: bool, first: int = 0) -> int:
    chosen = sample(which, first)
    parts = style.Parts() if show else None
    for c in chosen:
        line = f"{c.number:10} {c.parts:5} {c.kind or '':9} {top_theme(c.theme)}"
        if show and parts is not None:
            plan = footprint((FILES / c.file).read_text(errors="replace"), parts)
            line += f"\n{'':10} {c.name}: {brief(c, plan)}"
        print(line)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    one_ = sub.add_parser("sample", help="the half's sets; --show adds names and briefs")
    one_.add_argument("--which", choices=HALVES, default="tune")
    one_.add_argument("--first", type=int, default=0)
    one_.add_argument("--show", action="store_true",
                      help="names and briefs (never for proof while building the tool)")
    for name in ("run", "one", "calibrate", "report", "compare", "audit", "reach"):
        p = sub.add_parser(name)
        p.add_argument("--which", choices=HALVES, default="tune")
        p.add_argument("--date", default=f"{datetime.date.today():%Y-%m-%d}")
        p.add_argument("--judge-model", default="opus")
        p.add_argument("--jobs", type=int, default=2)
        p.add_argument("--subjects", default="", help="set numbers of the half, comma-separated")
        p.add_argument("--first", type=int, default=0,
                       help=f"only the half's first N ({FIRST}: the half before 2026-10-19)")
        p.add_argument("--software", action="store_true",
                       help="draw on lavapipe under heavy, not on the GPU (both sides alike)")
        p.add_argument("--dry-run", action="store_true",
                       help="a canned design and canned replies: nothing designed or asked")
        if name in ("run", "one", "report", "audit", "reach"):
            p.add_argument("--arm", required=True, help="this arm's name: m32, a branch's")
        if name in ("run", "one"):
            p.add_argument("--checkout", type=Path, default=ROOT,
                           help="the checkout whose app designs (this one)")
            p.add_argument("--timeout", type=int, default=2700)
            p.add_argument("--no-judge", action="store_true")
            p.add_argument("--rejudge", action="store_true",
                           help="read recorded subjects through again (a verdict asked is kept)")
            p.add_argument("--share", default="",
                           help="K/N: only every Nth subject of the half from the Kth")
            p.add_argument("--via", choices=("port", "relay"), default="port",
                           help="relay: as the owner designs, Claude through the connector "
                           "relay to the app as a throwaway account's tab")
            p.add_argument("--instructions", choices=("all", "none"), default="all",
                           help="none: the server's instructions withheld (with --via relay)")
            p.add_argument("--audit-later", action="store_true",
                           help="leave the build check's reading to `audit`, so no worker "
                           "holding the GPU waits for a CPU slot")
        if name == "compare":
            p.add_argument("--arms", required=True)
            p.add_argument("--dates", default="", help="each arm's date, when they differ")
    args = parser.parse_args(argv)
    if args.what == "sample":
        return _show(args.which, args.show, args.first)
    if args.what in ("run", "one"):      # one: a single subject, as run starts it under heavy
        args.checkout = args.checkout.resolve()
        if args.instructions == "none" and args.via != "relay":
            raise SystemExit("--instructions none withholds what the relay serves: with --via relay")
        if args.what == "run" and not args.dry_run:
            _imported(args.checkout)
        return run(args)
    if args.what == "calibrate":
        return calibrate_half(args)
    if args.what == "audit":
        return audit_later(args)
    if args.what == "report":
        text = report_arm(args.which, args.date, args.arm, args.first)
        (arm_dir(args.date, args.arm) / _report_name(args)).write_text(text)
        print(text)
        return 0
    if args.what == "reach":
        text = reach_report(args.which, args.date, args.arm, args.first)
        name = _report_name(args).replace("report-", "reach-")
        (arm_dir(args.date, args.arm) / name).write_text(text)
        print(text)
        return 0
    return compare(args)


if __name__ == "__main__":
    raise SystemExit(main())
