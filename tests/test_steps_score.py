"""The measures tools/steps_score.py scores the booklet's steps with.

Each is pinned to an answer worked out by hand, or published: a scorer
that is wrong makes every number in docs/INSTRUCTIONS.md wrong with it,
and nothing else would notice. The geometry half (hidden, blocked,
floating) is pinned by src/dev/steps_score.gd --selftest, which every run
does before it scores anything.
"""

from __future__ import annotations

import itertools
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import steps_score  # noqa: E402


def _brute_tau_b(x: list, y: list) -> float:
    """Kendall's tau-b by its definition, every pair looked at."""
    concordant = discordant = tied_x = tied_y = 0
    for i, j in itertools.combinations(range(len(x)), 2):
        dx = (x[i] > x[j]) - (x[i] < x[j])
        dy = (y[i] > y[j]) - (y[i] < y[j])
        if dx == 0 and dy == 0:
            continue
        if dx == 0:
            tied_x += 1
        elif dy == 0:
            tied_y += 1
        elif dx == dy:
            concordant += 1
        else:
            discordant += 1
    return (concordant - discordant) / math.sqrt(
        (concordant + discordant + tied_x) * (concordant + discordant + tied_y))


def test_the_same_order_is_one_and_the_reverse_minus_one():
    order = list(range(50))
    assert steps_score.kendall_tau_b(order, order) == 1.0
    assert steps_score.kendall_tau_b(order, order[::-1]) == -1.0


def test_two_swapped_pairs_of_ten():
    # Ten pairs, two of them the other way round: (8 - 2) / 10.
    assert abs(steps_score.kendall_tau_b([1, 2, 3, 4, 5], [1, 3, 2, 5, 4]) - 0.6) < 1e-12


def test_ties_as_scipy_counts_them():
    # scipy.stats.kendalltau's own example: tau-b -0.47140452079103173.
    tau = steps_score.kendall_tau_b([12, 2, 1, 12, 2], [1, 4, 7, 1, 0])
    assert abs(tau - (-0.47140452079103173)) < 1e-12


def test_steps_as_ties_against_every_pair():
    # Steps are ties: parts in one step are in no order. Random step
    # numbers against the definition, pair by pair.
    rng = random.Random(7)
    for _ in range(40):
        n = rng.randrange(2, 60)
        x = [rng.randrange(0, 8) for _ in range(n)]
        y = [rng.randrange(0, 8) for _ in range(n)]
        if len(set(x)) < 2 or len(set(y)) < 2:
            continue
        assert abs(steps_score.kendall_tau_b(x, y) - _brute_tau_b(x, y)) < 1e-9


def test_a_shuffled_order_is_near_zero():
    rng = random.Random(3)
    order = list(range(2000))
    shuffled = order[:]
    rng.shuffle(shuffled)
    assert abs(steps_score.kendall_tau_b(order, shuffled)) < 0.05


def test_pairs_kept_in_one_step():
    # The author's steps [a a b b], ours [a a a b]: the author has two
    # pairs together, we have three, and one of them is the same.
    assert steps_score.together([0, 0, 1, 1], [0, 0, 0, 1]) == (2, 3, 1)


def test_a_sub_assembly_is_matched_by_most_of_its_parts():
    units = [[1, 2, 3, 4, 5], [6, 7]]
    # Four of five is 0.8: matched. 8 and 9 are no one's.
    assert steps_score.matched_units(units, [[1, 2, 3, 4], [8, 9]]) == (1, 1)
    # Three of five is not.
    assert steps_score.matched_units(units, [[1, 2, 3]]) == (0, 0)
    # Two copies of one kind are two sub-assemblies.
    assert steps_score.matched_units([[1, 2], [3, 4]], [[1, 2], [3, 4]]) == (2, 2)


def test_an_interval_is_the_same_every_time_and_holds_the_value():
    values = [0.2, 0.4, 0.5, 0.9, 0.3, 0.7]
    first = steps_score.interval(values, steps_score.mean)
    assert first == steps_score.interval(values, steps_score.mean)
    assert first[0] <= steps_score.mean(values) <= first[1]
    assert steps_score.interval([0.5] * 5, steps_score.mean) == (0.5, 0.5)


def test_a_file_is_surveyed_through_its_sub_models():
    text = "\n".join([
        "0 FILE main.ldr",
        "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
        "0 STEP",
        "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr",
        "1 4 0 -48 0 1 0 0 0 1 0 0 0 1 wing.ldr",
        "0 STEP",
        "0 NOFILE",
        "0 FILE wing.ldr",
        "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat",
        "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat",
        "0 STEP",
        "0 NOFILE",
    ])
    # One brick and two wings of two plates; three STEP lines.
    assert steps_score.survey(text) == (5, 3)


def test_the_samples_are_the_same_every_time_and_share_no_set():
    rng = random.Random(11)
    info = {}
    theme_of = {}
    for n in range(400):
        name = f"{1000 + n}-1.mpd"
        info[name] = (rng.randrange(10, 2500), rng.randrange(0, 40))
        theme_of[f"{1000 + n}-1"] = ["Town", "Technic", "Castle", "Space"][n % 4]
    # A second file of one set: it goes with the first, wherever that is.
    info["1000-1_B-Model.mpd"] = (150, 9)
    one = steps_score.choose(info, theme_of, per_size=6)
    assert one == steps_score.choose(info, theme_of, per_size=6)
    tune = {steps_score.set_of(f) for f in one["tune"]}
    proof = {steps_score.set_of(f) for f in one["proof"]}
    assert not tune & proof
    for which in ("tune", "proof"):
        files = one[which]
        assert len(files) == 24
        for low, high in steps_score.SIZES:
            assert sum(1 for f in files if low <= info[f][0] < high) == 6
        assert all(info[f][1] >= steps_score.FEWEST_STEPS for f in files)
        # The themes taken in turn: each of the four 6 times, give or take.
        counts = [sum(1 for f in files if theme_of[steps_score.set_of(f)] == t)
                  for t in ("Town", "Technic", "Castle", "Space")]
        assert max(counts) - min(counts) <= 4


def test_a_file_scored_by_hand():
    # Four parts. The author: [0 1] then [2 3]. Ours: 0, 1, 2, 3 one at a
    # time, which keeps every pair in order (tau-b 0.82, the ties
    # counting against it) and none of the author's two pairs together.
    row = {"file": "x.mpd", "parts": 4, "units": [[2, 3]],
           "orders": {
               "author": {"rank": [0, 0, 1, 1], "sizes": [2, 2], "kinds": [1, 2],
                          "copies": [], "items": 4, "hidden": 0, "hidden_steps": 0,
                          "blocked": 0, "floating": 0, "floating_steps": 0,
                          "measured": 4},
               "ours": {"rank": [0, 1, 2, 3], "sizes": [1, 1, 1, 1], "kinds": [1, 1, 1, 1],
                        "copies": [[2, 3]], "items": 4, "hidden": 1, "hidden_steps": 1,
                        "blocked": 0, "floating": 1, "floating_steps": 1, "measured": 3},
           }}
    got = steps_score.per_file(row)
    assert got["author"]["tau"] == 1.0
    # Concordant 4, ties in the author's 2: 4 / sqrt(4 * 6).
    assert abs(got["ours"]["tau"] - 4 / math.sqrt(24)) < 1e-12
    assert got["ours"]["together"] == (0, 2)
    assert got["ours"]["units"] == (1, 1)
    assert got["ours"]["steps"] == 4
    assert got["ours"]["hidden"] == (1, 4)
    assert got["ours"]["floating"] == (1, 3)
    summary = steps_score.summarise([row])
    assert summary["ours"]["steps_ratio"]["value"] == 2.0
    assert summary["ours"]["units"]["value"] == 1.0
    assert summary["author"]["units"]["value"] == 0.0


def test_floating_read_without_side_studs_has_a_row_of_its_own():
    # One step of two things: one floats by the graph as it now is, two read
    # with no stud from the side holding (a tile on a side stud). A run made
    # before the probe kept both has only the second, which is then both.
    ours = {"rank": [0, 0], "sizes": [2], "kinds": [1], "copies": [], "items": 2,
            "hidden": 0, "hidden_steps": 0, "blocked": 0, "floating": 1, "floating_steps": 1,
            "measured": 2, "floating_pieces": 1, "floating_pieces_steps": 1,
            "measured_pieces": 2,
            "without_side": {"floating": 2, "floating_steps": 1, "measured": 2,
                             "floating_pieces": 2, "floating_pieces_steps": 1,
                             "measured_pieces": 2}}
    author = dict(ours, without_side={"floating": 0, "floating_steps": 0, "measured": 2,
                                      "floating_pieces": 0, "floating_pieces_steps": 0,
                                      "measured_pieces": 2})
    got = steps_score.per_file({"file": "x.mpd", "parts": 2, "orders": {"author": author,
                                                                         "ours": ours}})
    assert got["ours"]["floating_pieces"] == (1, 2)
    assert got["ours"]["floating_no_side"] == (2, 2)
    assert got["ours"]["floating_no_side_steps"] == (1, 1)
    old = {k: v for k, v in ours.items() if k != "without_side"}
    got = steps_score.per_file({"file": "x.mpd", "parts": 2, "orders": {"author": old, "ours": old}})
    assert got["ours"]["floating_no_side"] == got["ours"]["floating_pieces"] == (1, 2)


def test_the_table_and_the_floor_have_rows_of_their_own():
    # A car body before its wheels: on the table under the model as it
    # stands, held; on the floor under the finished car, floating. And the
    # build check asked both ways. A run from before has only the floor.
    ours = {"rank": [0, 1], "sizes": [1, 1], "kinds": [1, 1], "copies": [], "items": 2,
            "hidden": 0, "hidden_steps": 0, "blocked": 0, "floating": 1, "floating_steps": 1,
            "measured": 2, "floating_pieces": 1, "floating_pieces_steps": 1,
            "measured_pieces": 2, "floating_table": 0, "floating_table_steps": 0}
    row = {"file": "x.mpd", "parts": 2, "orders": {"author": ours, "ours": ours},
           "checked": {"ours": {"cuts": 1, "parts": 4, "floating": 0, "steps_floating": 0,
                                "floating_floor": 3, "steps_floating_floor": 1}}}
    got = steps_score.per_file(row)["ours"]
    assert got["floating_table"] == (0, 2)
    assert got["floating_table_steps"] == (0, 2)
    assert got["floating_pieces"] == (1, 2)
    assert got["checked"] == (0, 4)
    assert got["checked_floor"] == (3, 4)
    old = {k: v for k, v in ours.items() if not k.startswith("floating_table")}
    row = {"file": "x.mpd", "parts": 2, "orders": {"author": old, "ours": old},
           "checked": {"ours": {"cuts": 1, "parts": 4, "floating": 3, "steps_floating": 1}}}
    got = steps_score.per_file(row)["ours"]
    assert got["floating_table"] == got["floating_pieces"] == (1, 2)
    assert got["checked_floor"] == got["checked"] == (3, 4)
