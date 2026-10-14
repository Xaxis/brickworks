"""Tests for the pairwise judge: reading its answers, the Bradley-Terry fit, and calibration.

The fit is what turns a few hundred A-or-B answers into a claim that a
round gained. These tests give it pairs drawn from strengths we chose, and
check that it gives those strengths back, ranks them in their order, puts
its 95% interval round the truth about as often as it says, and cancels a
judge that leans to whichever model it is shown first.
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from bench import calibrate, pairwise  # noqa: E402
from bench.judge import Picture  # noqa: E402

DIMS = pairwise.DIMENSIONS
CANNED = ROOT / "tests" / "fixtures" / "bench" / "pair_reply.json"


def _refused(fn, *args) -> str:
    try:
        fn(*args)
    except ValueError as error:
        return str(error)
    raise AssertionError(f"{fn.__name__} accepted {args!r}")


def _games(truth: dict[str, float], per_order: int, rng: random.Random,
           lean: float = 0.0) -> list[pairwise.Verdict]:
    """Every two designs, both orders, `per_order` times each, won as Bradley-Terry says.

    `lean` is a judge's pull to the model shown first: with that chance it
    picks A whatever A is, and otherwise it answers as the strengths say.
    """
    keys = list(truth)
    out = []
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            for first, second in ((a, b), (b, a)):
                for _ in range(per_order):
                    if rng.random() < lean:
                        winner = first
                    else:
                        p = pairwise.chance(truth[first] - truth[second])
                        winner = first if rng.random() < p else second
                    out.append(pairwise.Verdict(first, second, {d: winner for d in DIMS}, {}))
    return out


def _centred(values: dict[str, float]) -> dict[str, float]:
    mean = sum(values.values()) / len(values)
    return {k: v - mean + pairwise.CENTRE for k, v in values.items()}


# -- the answers ------------------------------------------------------------


def test_a_reply_names_designs_by_the_order_they_were_shown():
    reply = json.loads(CANNED.read_text())
    one = pairwise.parse(reply, "old", "new")
    other = pairwise.parse(reply, "new", "old")
    assert one.winners["likeness"] == "old" and one.winners["surface"] == "new"
    # The same A-or-B answer, the other way round, names the other design.
    assert all(one.winners[d] != other.winners[d] for d in DIMS)
    assert one.reasons["surface"].startswith("B's bonnet is tiled")
    assert "aaaaaa_corner.png" in one.looked_at


def test_model_b_in_words_is_b_and_anything_else_is_refused_by_name():
    said = {d: {"better": "A", "reason": "r"} for d in DIMS}
    said["colour"] = {"better": " Model B. ", "reason": "r"}
    assert pairwise.parse(said, "x", "y").winners["colour"] == "y"
    said["colour"] = {"better": "both", "reason": "r"}
    assert "colour" in _refused(pairwise.parse, said, "x", "y")
    del said["colour"]
    assert "colour" in _refused(pairwise.parse, said, "x", "y")


def test_a_failed_call_is_refused_not_counted():
    reply = {"type": "result", "is_error": True, "result": "usage limit reached"}
    assert "failed" in _refused(pairwise.parse, reply, "x", "y")


def test_the_prompt_shows_both_models_and_their_checks_and_no_round():
    a = pairwise.Shown((Picture(Path("/p/abc123_corner.png"), "corner view"),), 120,
                       "    ok    it stands up: stable")
    b = pairwise.Shown((Picture(Path("/p/def456_corner.png"), "corner view"),), 340, "")
    text = pairwise.prompt("a barn owl", "An owl.", "display",
                           [Picture(Path("/r/photo1.jpg"), "an owl")], a, b)
    for said in ("/p/abc123_corner.png", "/p/def456_corner.png", "/r/photo1.jpg",
                 "MODEL A, 120 parts", "MODEL B, 340 parts", "it stands up: stable",
                 "No build check was run for B"):
        assert said in text
    assert all(f"  {d}: " in text for d in DIMS)
    assert "LEGO® set designer" in text and "LEGO model" not in text
    # A design's pictures are named for nothing but itself.
    code = pairwise.opaque("2026-10-13-surface/1")
    assert len(code) == 6 and "surface" not in code and code != pairwise.opaque("2026-10-12/1")


# -- the fit -----------------------------------------------------------------


def test_bradley_terry_gives_back_the_strengths_it_was_drawn_from():
    truth = {"a": 800.0, "b": 900.0, "c": 1000.0, "d": 1100.0, "e": 1200.0}
    verdicts = _games(truth, 150, random.Random(7))
    found = pairwise.rank(list(truth), verdicts, "overall", draws=0)
    assert found.order() == ["e", "d", "c", "b", "a"]
    for key, value in _centred(truth).items():
        assert abs(found.elo[key] - value) < 25, (key, found.elo[key], value)


def test_the_interval_holds_the_truth_about_as_often_as_it_says():
    # The bench's own case: seven designs, every pair asked once each way.
    truth = {"a": 850.0, "b": 920.0, "c": 980.0, "d": 1000.0, "e": 1040.0, "f": 1090.0,
             "g": 1130.0}
    centred = _centred(truth)
    rng = random.Random(11)
    inside = total = 0
    for _ in range(40):
        found = pairwise.rank(list(truth), _games(truth, 1, rng), "overall", draws=200,
                              seed=rng.randrange(1 << 30))
        for key, value in centred.items():
            inside += found.low[key] <= value <= found.high[key]
            total += 1
    # Half a virtual tie pulls the ends in, so the cover is checked loosely.
    assert 0.85 <= inside / total <= 1.0, inside / total


def test_a_judge_that_always_picks_the_first_model_ranks_nothing():
    truth = {"a": 800.0, "b": 1000.0, "c": 1200.0}
    verdicts = _games(truth, 3, random.Random(3), lean=1.0)
    found = pairwise.rank(list(truth), verdicts, "overall", draws=0)
    assert all(abs(v - pairwise.CENTRE) < 1e-6 for v in found.elo.values())


def test_a_judge_that_leans_to_the_first_model_still_ranks_in_order():
    truth = {"a": 800.0, "b": 1000.0, "c": 1200.0}
    leaning = pairwise.rank(list(truth), _games(truth, 60, random.Random(5), lean=0.3),
                            "overall", draws=0)
    assert leaning.order() == ["c", "b", "a"]
    fair = pairwise.rank(list(truth), _games(truth, 60, random.Random(5)), "overall", draws=0)
    # The lean is cancelled, not removed: the gaps shrink by about the share it took.
    gap = leaning.elo["c"] - leaning.elo["a"]
    assert 0.4 * (fair.elo["c"] - fair.elo["a"]) < gap < fair.elo["c"] - fair.elo["a"]


def test_a_design_that_wins_every_pair_has_a_finite_strength():
    verdicts = [pairwise.Verdict(a, b, {d: "x" for d in DIMS}, {})
                for a, b in (("x", "y"), ("y", "x"), ("x", "z"), ("z", "x"))]
    found = pairwise.rank(["x", "y", "z"], verdicts, "overall", draws=0)
    assert found.order()[0] == "x" and math.isfinite(found.elo["x"])
    assert abs(found.elo["y"] - found.elo["z"]) < 1e-6
    assert found.elo["x"] - found.elo["y"] < 600


def test_two_designs_and_one_pair_still_get_an_interval():
    # Resampling the one pair gives that pair every time; the verdicts are drawn again instead.
    swept = [pairwise.Verdict("x", "y", {d: "x" for d in DIMS}, {}),
             pairwise.Verdict("y", "x", {d: "x" for d in DIMS}, {})]
    found = pairwise.rank(["x", "y"], swept, "overall", draws=300)
    assert found.elo["x"] > found.elo["y"]
    assert found.low["x"] < found.elo["x"] and found.high["y"] > found.elo["y"]
    assert found.low["x"] <= pairwise.CENTRE      # one pair swept is no proof


def test_elo_is_four_hundred_over_ln_ten_a_unit_and_a_gap_is_a_chance():
    assert math.isclose(pairwise.elo(math.log(10)), 1400.0)
    assert math.isclose(pairwise.chance(0.0), 0.5)
    assert math.isclose(pairwise.chance(400.0), 10 / 11)


# -- a lever, and luck ---------------------------------------------------------


def test_a_lever_is_the_mean_over_subjects_of_after_minus_before():
    rankings = {}
    groups = {}
    rng = random.Random(13)
    for subject in ("owl", "car", "shop"):
        truth = {f"{subject}-before-1": 900.0, f"{subject}-before-2": 940.0,
                 f"{subject}-after": 1100.0, f"{subject}-other": 1000.0}
        rankings[subject] = pairwise.rank(list(truth), _games(truth, 40, rng), "surface",
                                          draws=200)
        groups[subject] = ([f"{subject}-before-1", f"{subject}-before-2"], [f"{subject}-after"])
    found = pairwise.effect("surface", "surface", rankings, groups, run_sd=0.0)
    assert found is not None and found.subjects == ("owl", "car", "shop")
    assert abs(found.mean - 180.0) < 40 and found.low > 0
    assert found.low <= found.mean <= found.high
    # The luck of one design a round widens the interval; it does not move the gain.
    lucky = pairwise.effect("surface", "surface", rankings, groups, run_sd=150.0)
    assert lucky is not None and math.isclose(lucky.mean, found.mean)
    assert lucky.high_runs - lucky.low_runs > found.high - found.low


def test_a_subject_without_a_design_on_both_sides_is_left_out():
    truth = {"a": 900.0, "b": 1100.0}
    rankings = {"owl": pairwise.rank(list(truth), _games(truth, 4, random.Random(1)), "colour",
                                     draws=20)}
    assert pairwise.effect("x", "colour", rankings, {"owl": ([], ["a"])}, 0.0) is None


def test_the_run_spread_is_pooled_within_designs_of_the_same_code():
    ranking = pairwise.Ranking("overall", {"a": 900.0, "b": 1100.0, "c": 1000.0, "d": 1000.0},
                               {}, {})
    found = pairwise.run_spread({"owl": ranking}, {"owl": [["a", "b"], ["c", "d"], ["c"]]})
    # (100^2 + 100^2 + 0 + 0) / (1 + 1) degrees of freedom.
    assert found is not None and math.isclose(found, 100.0)


# -- calibration ---------------------------------------------------------------


def test_agreement_counts_verdicts_pairs_orders_and_repeats():
    known = [pairwise.Known("p", "fault", "good", "bad", ("surface",))]

    def said(first: str, second: str, surface: str, colour: str) -> pairwise.Verdict:
        winners = {d: first for d in DIMS}
        winners.update(surface=surface, colour=colour)
        return pairwise.Verdict(first, second, winners, {})

    verdicts = [said("good", "bad", "good", "good"), said("bad", "good", "good", "bad"),
                said("good", "bad", "good", "good"), said("bad", "good", "bad", "good")]
    found = pairwise.agreement(known, verdicts)
    assert found["verdicts"] == {"agree": 3, "of": 4}
    assert found["pairs"] == {"agree": 0, "split": 1, "wrong": 0}
    assert found["kinds"]["fault"]["pairs"] == 1
    # The orders agree on surface in the first repeat and on colour in the second;
    # every other dimension follows the order shown, so it never agrees.
    assert found["orders"] == {"same": 2, "of": 2 * len(DIMS)}
    # Asked again in the same order: all seven the same, then all but surface and colour.
    assert found["repeats"] == {"same": len(DIMS) + len(DIMS) - 2, "of": 2 * len(DIMS)}
    # Shown first: every other dimension in all four, surface and colour in three each.
    assert found["first_pick"] == {"A": 5 * 4 + 3 + 3, "of": 4 * len(DIMS)}


def test_wilson_stays_inside_zero_and_one():
    low, high = pairwise.wilson(10, 10)
    assert 0.6 < low < 1.0 and high == 1.0
    assert pairwise.wilson(0, 0) == (0.0, 1.0)


def _parts() -> style.Parts:
    def info(name: str, category: str, x: float, y: float, z: float) -> style.PartInfo:
        return style.PartInfo(name, category, ((-x, -y, -z), (x, 0.0, z)))
    return style.Parts.of({
        "3001": info("Brick 2 x 4", "Brick", 40, 24, 20),
        "3068b": info("Tile 2 x 2 with Groove", "Tile", 20, 8, 20),
        "11203": info("Tile 2 x 2 Inverted", "Tile", 20, 8, 20),
        "3626c": info("Minifig Head", "Minifig", 13, 24, 13),
        "3039": info("Slope Brick 45 2 x 2", "Slope", 20, 24, 20),
    })


MODEL = """0 A test
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 15 -20 -48 0 1 0 0 0 1 0 0 0 1 3068b.dat
1 47 20 -48 0 1 0 0 0 1 0 0 0 1 3068b.dat
1 0 20 -32 0 1 0 0 0 1 0 0 0 1 11203.dat
1 14 0 -72 0 1 0 0 0 1 0 0 0 1 3626c.dat
1 1 0 -96 0 1 0 0 0 1 0 0 0 1 3039.dat
"""


def test_bare_studs_takes_off_tiles_but_not_an_inverted_one():
    made, said = calibrate.with_fault(MODEL, "bare studs", _parts(), {})
    assert said == "2 tiles taken off"
    assert "3068b" not in made and "11203.dat" in made and made.count("3001.dat") == 2


def test_some_studs_bare_takes_off_one_tile_in_four_in_file_order():
    tiles = "".join(f"1 15 {20 * n} -24 0 1 0 0 0 1 0 0 0 1 3068b.dat\n" for n in range(8))
    made, said = calibrate.with_fault(MODEL + tiles, "some studs bare", _parts(), {})
    # Ten tiles in all (two in MODEL): the 4th and the 8th go.
    assert said == "2 tiles of 10 taken off, one in four"
    assert made.count("3068b.dat") == 8 and "11203.dat" in made
    assert " 20 -24 0 " not in made and " 100 -24 0 " not in made and " 120 -24 0 " in made


def test_no_figures_takes_out_the_minifig_and_nothing_else():
    made, said = calibrate.with_fault(MODEL, "no figures", _parts(), {})
    assert said == "1 figure parts taken out" and "3626c" not in made and "3039.dat" in made


def test_one_colour_paints_all_but_glass_in_the_commonest():
    colours = {4: {"code": 4, "alpha": 255, "group": "solid"},
               47: {"code": 47, "alpha": 128, "group": "transparent"}}
    made, _said = calibrate.with_fault(MODEL, "one colour", _parts(), colours)
    lines = [line.split() for line in made.splitlines() if line.startswith("1 ")]
    assert {bits[1] for bits in lines} == {"4", "47"}
    assert any(bits[1] == "47" and bits[-1] == "3068b.dat" for bits in lines)


def test_a_naive_stack_is_plain_bricks_studs_up_in_three_colours_at_most():
    colours = {c: {"code": c, "rgb": rgb, "alpha": 255, "group": "solid"} for c, rgb in
               ((4, (200, 0, 0)), (1, (0, 0, 200)), (0, (0, 0, 0)), (14, (250, 200, 0)),
                (15, (255, 255, 255)))}
    made, said = calibrate.naive_stack(MODEL, _parts(), colours)
    placed = style.read(made).placed
    assert placed and {p.part for p in placed} <= {b[2] for b in calibrate.BRICKS}
    assert len({p.colour for p in placed}) <= 3
    for p in placed:            # never tipped: studs up, at most a quarter turn about up
        m = p.matrix
        assert (m.d, m.e, m.f, m.b, m.h) == (0, 1, 0, 0, 0)
    # The two red bricks are one 2 x 4 course each, the same footprint and colour.
    red = [p for p in placed if p.colour == 4]
    assert len(red) == 2 and all(p.part == "3001" for p in red)
    assert "plain bricks" in said


def test_every_known_pair_says_what_it_must_win():
    ids = [p.id for p in calibrate.PAIRS]
    assert len(ids) == len(set(ids))
    for pair in calibrate.PAIRS:
        assert pair.dims and set(pair.dims) <= set(DIMS)
        assert "buildability" not in pair.dims   # no build check runs on these
    assert {p.fault for p in calibrate.PAIRS} == set(calibrate.FAULTS)


def test_a_rounds_pool_never_takes_the_judges_own_pictures():
    # Calibration's models and every subject's copies live under "pairwise";
    # were they read as designs, a round would be ranked against its own copies.
    import tempfile
    from bench import run
    with tempfile.TemporaryDirectory() as where:
        results = Path(where)
        for batch in ("2026-10-13-surface", "pairwise", "dry-2026-10-12", "anchors"):
            run_dir = results / batch / "barn_owl" / "1"
            run_dir.mkdir(parents=True)
            for view in run.VIEWS:
                (run_dir / f"views_{view}.png").write_bytes(b"png")
        (results / "2026-10-13-surface" / "barn_owl" / "2").mkdir()   # no views: not a design
        found = run.pool("barn_owl", results)
    assert [e.key for e in found] == ["2026-10-13-surface/1"]
    assert run.round_of("2026-10-13-edges-b/1") == "edges"
    assert run.round_of("2026-10-15-next/1") == "2026-10-15-next"
