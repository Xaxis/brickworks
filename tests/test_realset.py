"""Tests for tools/bench/realset.py: what is left out, how the halves are drawn, the brief.

The test against real sets is worth something only if its subjects are ones
no round was tuned on, its two halves are the same every time and never
share a set, each half has its characters, and the brief says the subject
and its scale without the set's own file. Each of those is pinned here on
names and pools written by hand, so a rule that quietly stops working (or a
function that returns nothing) fails a test rather than a round.
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from bench import realset, suite  # noqa: E402
from style import PartInfo, Parts  # noqa: E402

CANNED = ROOT / "tests" / "fixtures" / "bench" / "pair_reply.json"
needs_sets = pytest.mark.skipif(not realset.FILES.is_dir() or not realset.INDEX.exists(),
                                reason="no vendor/omr (tools/omr.py fetch)")


# -- what is left out -----------------------------------------------------------


def test_every_suite_subject_is_left_out_by_its_kind():
    for subject in suite.SUITE:
        assert realset.excluded(subject.title, "") is not None, subject.title


def test_kinds_rounds_touched_are_left_out_whatever_the_set_is_called():
    touched = [("Fire Station", "Town"), ("Police Car", "Town"), ("Barn Owl", "Creator"),
               ("Medieval Knights", "Town"), ("Space Cruiser", "Creator"),
               ("Pirate Ship", "Creator"), ("Lighthouse Island", "Creator"),
               ("Steam Engine", "Creator"), ("Flower Bouquet", "Icons"),
               ("Dachshund Puppy", "Creator"), ("Robot Workshop", "City"),
               ("Wizard's Tower", "Harry Potter"), ("Off Road Command Center", "City"),
               ("Statue of Liberty", "Architecture"), ("Hook Loader", "Technic")]
    for name, theme in touched:
        said = realset.excluded(name, theme)
        assert said is not None and said.startswith("touched"), (name, said)


def test_a_theme_that_is_one_kind_is_left_out_whole():
    assert "train" in (realset.excluded("Emerald Night", "Train") or "")
    assert "spaceship" in (realset.excluded("Galaxy Explorer", "Space") or "")
    assert realset.excluded("Anything", "Castle > Lion Knights") is not None


def test_a_name_that_hides_its_kind_is_found_by_its_sub_models():
    # 5892 Sonic Boom is a jet; only its author's names for its parts say so.
    parts = ["Airplane", "Bottom section", "Nose gear", "Center support", "Switch arm",
             "Nose section", "Left wing", "Right wing", "Tail fin"]
    assert realset.excluded("Sonic Boom", "Creator", parts) is not None
    # One car among a vet clinic's rooms is not what the set is.
    clinic = ["Sophie", "Horse", "Puppy Cart", "Vet Clinic", "Signboard", "Fish Tank",
              "Examination Table", "Treatment Room", "Signboard Base"]
    assert realset.excluded("Heartlake Vet", "Friends", clinic) is None


def test_the_sets_rounds_showed_are_left_out_by_number_too():
    numbers = realset.looked_at()
    assert {"10242-1", "10194-1", "75895-1", "6286-1"} <= numbers
    assert realset.excluded("Emerald Night", "Creator > Creator Expert", (), "10194-1")


def test_untouched_subjects_stay_in():
    for name, theme in [("Lion", "Creator"), ("Telehandler", "Technic"),
                        ("Tokyo", "Architecture"), ("Robin", "Brickheadz"),
                        ("Cathedral", "Town"), ("Batman", "Brickheadz"),
                        ("Scatter Hall", "City")]:
        assert realset.excluded(name, theme) is None, name


def test_what_is_not_one_model_is_left_out():
    assert realset.excluded("Advent Calendar 2014", "Seasonal") is not None
    assert realset.excluded("World Map", "Creator") is not None
    assert realset.excluded("Marilyn Monroe", "LEGO Art") is not None


def test_sub_model_names_lose_figures_numbers_and_parts():
    text = "\n".join(["0 FILE 5892 - main.ldr", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 5892 - Airplane.ldr",
                      "0 FILE 5892 - Airplane.ldr", "0 FILE 5892 - Minifig - Pilot.ldr",
                      "0 FILE 5892 - 12.ldr", "0 FILE 3626bp01.dat", "0 FILE 5892 - Left wing.ldr"])
    assert realset.submodels(text) == ["Airplane", "Left wing"]


# -- characters -----------------------------------------------------------------


def test_characters_are_what_the_name_is_of():
    assert realset.character("Lion", "Creator > Designer Sets") == "animal"
    assert realset.character("Year Of The Sheep", "Seasonal") == "animal"
    assert realset.character("Wolf Legend Beast", "Legends of Chima") == "creature"
    assert realset.character("Steve & Creeper", "Brickheadz") == "creature"
    assert realset.character("Robin", "Brickheadz") == "person"
    assert realset.character("Mickey Mouse", "Brickheadz") == "person"
    # A playset with a dinosaur in it is not a dinosaur.
    assert realset.character("Dino Explorer", "Adventurers") is None
    assert realset.character("Telehandler", "Technic") is None


# -- the halves -----------------------------------------------------------------


def _pool() -> list[realset.Candidate]:
    rng = random.Random(7)
    pool = []
    themes = ["Technic", "City", "Architecture", "Friends", "Creator", "Ideas"]
    for n in range(120):
        pool.append(realset.Candidate(f"{9000 + n}-1", f"{9000 + n}-1.mpd", f"Thing {n}",
                                      themes[n % len(themes)], 2010, rng.randint(80, 1500)))
    for n, (name, theme) in enumerate([("Lion", "Creator"), ("Tiger", "Creator"),
                                       ("Giraffe", "Creator"), ("Robin", "Brickheadz"),
                                       ("Batgirl", "Brickheadz"), ("Belle", "Brickheadz"),
                                       ("Thanos", "Brickheadz"), ("Beast", "Brickheadz"),
                                       ("Flain", "Mixels")]):
        pool.append(realset.Candidate(f"{8000 + n}-1", f"{8000 + n}-1.mpd", name, theme, 2015,
                                      100 + n))
    return pool


def test_halves_are_full_disjoint_and_hold_their_characters():
    halves = realset.choose(_pool())
    tune, proof = halves["tune"], halves["proof"]
    assert len(tune) == len(proof) == realset.PER_HALF
    assert not {c.number for c in tune} & {c.number for c in proof}
    for half in (tune, proof):
        kinds = [c.kind for c in half]
        for kind in realset.CHARACTERS:
            assert kind in kinds, (kind, kinds)
        sizes = {realset._size(c) for c in half if c.kind is None}
        assert sizes == set(range(len(realset.SIZES))), sizes


def test_halves_are_the_same_whatever_order_the_sets_come_in():
    pool = _pool()
    first = realset.choose(pool)
    shuffled = list(pool)
    random.Random(3).shuffle(shuffled)
    again = realset.choose(shuffled)
    for which in realset.HALVES:
        assert [c.number for c in first[which]] == [c.number for c in again[which]]


def test_a_half_spreads_over_themes():
    for half in realset.choose(_pool()).values():
        others = [realset.top_theme(c.theme) for c in half if c.kind is None]
        assert len(set(others)) >= min(len(others), 6) - 1, others


@needs_sets
def test_the_real_halves_are_fixed_eligible_and_apart():
    pool = realset.eligible(realset.candidates())
    assert len(pool) > 2 * realset.PER_HALF
    halves = realset.choose(pool)
    for which, half in halves.items():
        assert len(half) == realset.PER_HALF, which
        assert {c.kind for c in half} >= set(realset.CHARACTERS), which
        for c in half:
            assert realset.FEWEST <= c.parts <= realset.MOST and c.year >= realset.SINCE
            assert realset.excluded(c.name, c.theme, c.submodels, c.number) is None
    assert not {c.number for c in halves["tune"]} & {c.number for c in halves["proof"]}


# The halves every result before 2026-10-19 was run on, ten a half.
FIRST_TEN = {
    "tune": ["40148-1", "41587-1", "70127-1", "3932-1", "42061-1", "21051-1", "7327-1",
             "7410-1", "9470-1", "21107-1"],
    "proof": ["40270-1", "41630-1", "41612-1", "3936-1", "7992-1", "42062-1", "21017-1",
              "5934-1", "41072-1", "7326-1"],
}


def test_a_grown_half_starts_with_the_half_it_was():
    pool = _pool()
    small, grown = realset.choose(pool, realset.FIRST), realset.choose(pool)
    for which in realset.HALVES:
        assert len(grown[which]) > len(small[which]) == realset.FIRST
        assert [c.number for c in grown[which][:realset.FIRST]] == \
            [c.number for c in small[which]], which


@needs_sets
def test_the_real_halves_start_with_the_ten_old_results_were_run_on():
    pool = realset.eligible(realset.candidates())
    halves = realset.choose(pool)
    for which, numbers in FIRST_TEN.items():
        assert [c.number for c in halves[which][:realset.FIRST]] == numbers, which
    # Every set but the characters past one of each kind a half is in a half.
    taken = {c.number for half in halves.values() for c in half}
    assert {c.number for c in pool if c.kind is None} <= taken


# -- the brief ------------------------------------------------------------------


def test_the_brief_says_subject_style_and_scale_and_nothing_of_the_set():
    c = realset.Candidate("4903-1", "4903-1.mpd", "Lion (Polybag)", "Creator > Designer Sets",
                          2005, 200)
    text = realset.brief(c, (12, 20))
    assert text.startswith("Lion, in the style of LEGO® Creator sets")
    assert "12 x 20 studs" in text and "150 to 250 pieces" in text
    assert "4903" not in text and "Polybag" not in text and ".mpd" not in text


def test_names_are_cleaned_of_bags_and_promotions():
    assert realset.clean_name("Small Red Helicopter (Polybag)") == "Small Red Helicopter"
    assert realset.clean_name("Apple - Suntory Promotional") == "Apple"
    assert realset.clean_name("WALL•E [Original Version]") == "WALL•E"
    assert realset.theme_words("Brickheadz") == "BrickHeadz"


def test_the_band_is_a_quarter_either_side_to_tens():
    assert realset.band(200) == (150, 250)
    assert realset.band(99) == (70, 120)
    low, high = realset.band(1189)
    assert low < 1189 < high and low % 10 == 0 and high % 10 == 0


def test_the_footprint_is_read_from_the_parts_boxes():
    brick = PartInfo("Brick 2 x 4", "Brick", ((-40.0, -4.0, -20.0), (40.0, 24.0, 20.0)))
    head = PartInfo("Minifig Head", "Minifig", ((-10.0, -4.0, -10.0), (10.0, 20.0, 10.0)))
    parts = Parts.of({"3001": brick, "3626": head})
    text = "\n".join(["1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
                      "1 4 0 -24 60 1 0 0 0 1 0 0 0 1 3001.dat",
                      "1 14 300 0 0 1 0 0 0 1 0 0 0 1 3626.dat"])     # a figure far off
    assert realset.footprint(text, parts) == (4, 5)


def test_the_subject_holds_out_the_set_by_its_number():
    c = realset.Candidate("40148-1", "40148-1.mpd", "Year Of The Sheep", "Seasonal", 2015, 99)
    subject = realset.subject_of(c, (9, 13))
    assert subject.id == "40148-1"
    assert subject.brief == realset.brief(c, (9, 13))


# -- the judge and the reading --------------------------------------------------


def test_a_reply_is_read_for_every_visual_dimension_and_nothing_says_set():
    verdict = realset.parse(json.loads(CANNED.read_text()), "ours", "set")
    assert set(verdict.winners) == set(realset.DIMS)
    assert verdict.winners["likeness"] == "ours" and verdict.winners["surface"] == "set"
    try:
        realset.parse({"likeness": {"better": "C"}}, "ours", "set")
        refused = ""
    except ValueError as error:
        refused = str(error)
    assert "likeness" in refused
    text = realset.prompt("Lion, in the style of LEGO® Creator sets.", (), ())
    assert "real set" not in text.lower() and "set designer" in text


def test_shares_and_win_rate_count_a_subject_with_no_model_as_lost():
    won = {"first": "ours", "second": "set", "winners": {d: "ours" for d in realset.DIMS}}
    lost = {"first": "set", "second": "ours", "winners": {d: "set" for d in realset.DIMS}}
    records = [{"keys": {"ours": "ours"}, "verdicts": [won, lost]},
               {"keys": {"ours": "ours"}, "verdicts": [won, won]},
               {"verdicts": []}]
    assert realset.shares(records, "overall") == [0.5, 1.0, 0.0]
    rate, low, high = realset.win_rate([0.5, 1.0, 0.0])
    assert rate == pytest.approx(0.5) and 0.0 < low < 0.5 < high < 1.0


def test_a_paired_gap_has_its_interval_round_it():
    gap, low, high = realset.paired_gap([1.0, 0.5, 1.0, 0.5], [0.0, 0.5, 0.0, 0.0])
    assert gap == pytest.approx(0.625) and low <= gap <= high
