"""The CAD task test's sampler and its comparison (tools/bench/cadtask.py).

A sample that drifts between runs compares nothing with nothing, and a
comparison that calls a moved part kept says a format round-trips when it
does not. Each test pins a number the function has to produce.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import cadtask  # noqa: E402

TURN0 = "1 0 0 0 1 0 0 0 1"
TURN90 = "0 0 1 0 1 0 -1 0 0"


def line(part: str, colour: int, x: float, y: float, z: float, turn: str = TURN0,
         steps: str = "0", unit: str = "", group: str = "") -> str:
    return f"{part} {colour} {x} {y} {z} {turn}|{steps}|{unit}|{group}"


# -- the sample -------------------------------------------------------------------

INFO = {
    # file -> (parts, author's steps)
    "100-1.mpd": (10, 2), "100-1_B.mpd": (12, 0), "200-1.mpd": (20, 3),
    "300-1.mpd": (50, 5), "400-1.mpd": (60, 0), "500-1.mpd": (150, 9),
    "600-1.mpd": (40, 4), "700-1.mpd": (35, 6),
}
SIZES = [(1, 30), (30, 100), (100, 300)]


def test_choose_takes_per_size_and_one_file_a_set():
    taken = cadtask.choose(INFO, per_size=2, sizes=SIZES, salt="t")
    assert len(taken) == 5          # 2 small, 2 middling, the only big one
    assert "500-1.mpd" in taken
    sets = [cadtask.set_of(f) for f in taken]
    assert len(sets) == len(set(sets))
    small = [f for f in taken if INFO[f][0] < 30]
    assert len(small) == 2


def test_choose_is_the_same_every_time_and_moves_with_the_salt():
    first = cadtask.choose(INFO, per_size=1, sizes=SIZES, salt="t")
    assert first == cadtask.choose(dict(reversed(list(INFO.items()))), per_size=1,
                                   sizes=SIZES, salt="t")
    others = {tuple(cadtask.choose(INFO, per_size=1, sizes=SIZES, salt=s))
              for s in ("a", "b", "c", "d", "e", "f")}
    assert len(others) > 1


def test_choose_builds_wants_steps_size_and_no_submodels():
    subs = {f: 0 for f in INFO}
    subs["700-1.mpd"] = 3
    built = cadtask.choose_builds(INFO, subs, count=3, parts=(30, 80))
    # 300-1 (50 parts, 5 steps) and 600-1 (40, 4) qualify; 400-1 has no
    # steps, 700-1 has sub-models, 500-1 is too big.
    assert sorted(built) == ["300-1.mpd", "600-1.mpd"]


# -- the comparison ---------------------------------------------------------------

def test_part_reads_a_name_with_spaces():
    part = cadtask.Part(line("10283 - sticker", 15, 1, -2, 3))
    assert part.id == "10283 - sticker"
    assert part.colour == 15
    assert part.at == (1.0, -2.0, 3.0)


def test_identical_models_are_exact():
    model = [line("3001", 4, 0, -24, 0), line("3001", 4, 0, -48, 0, steps="1"),
             line("3023", 15, 20, -56, 10, TURN90, steps="2")]
    got = cadtask.compare(model, list(reversed(model)))
    assert got["paired"] == 3
    assert got["exact"] is True
    assert got["why"] == {}


def test_a_part_moved_two_ldu_is_moved_and_not_exact():
    before = [line("3001", 4, 0, -24, 0), line("3004", 1, 0, -48, 0)]
    after = [line("3001", 4, 0, -24, 0), line("3004", 1, 2, -48, 0)]
    got = cadtask.compare(before, after)
    assert got["exact"] is False
    assert got["why"] == {"moved": 1}
    assert got["paired"] == 1


def test_within_the_ldu_is_kept_but_not_within_a_hundredth():
    got = cadtask.compare([line("3001", 4, 0, -24, 0)], [line("3001", 4, 0.4, -24, 0)])
    assert got["exact"] is True
    assert got["within_0_01"] == 0


def test_recoloured_turned_renumbered_lost_added():
    before = [line("3001", 4, 0, -24, 0), line("3002", 4, 80, -24, 0),
              line("3023", 15, 0, -8, 80), line("3005", 1, 200, -24, 0)]
    after = [line("3001", 14, 0, -24, 0), line("3002", 4, 80, -24, 0, TURN90),
             line("3023b", 15, 0, -8, 80), line("3010", 2, -200, -24, 0)]
    got = cadtask.compare(before, after)
    assert got["why"] == {"recoloured": 1, "turned": 1, "renumbered": 1, "lost": 1,
                          "added": 1}
    assert got["same_shapes"] is False


def test_renumbered_only_is_the_same_shapes():
    got = cadtask.compare([line("3023", 15, 0, -8, 80)], [line("3023b", 15, 0, -8, 80, TURN90)])
    assert got["why"] == {"renumbered": 1}
    assert got["exact"] is False
    assert got["same_shapes"] is False   # nothing paired: no steps to keep
    got = cadtask.compare([line("3001", 4, 0, -24, 0), line("3023", 15, 0, -8, 80)],
                          [line("3001", 4, 0, -24, 0), line("3023b", 15, 0, -8, 80)])
    assert got["same_shapes"] is True and got["exact"] is False


def test_a_stub_moves_and_turns_the_part_it_became():
    import tempfile
    folder = Path(tempfile.mkdtemp())
    (folder / "90028.dat").write_text(
        "0 ~Moved to 90028b\n0 Name: 90028.dat\n1 16 5 0 0 0 0 -1 0 1 0 1 0 0 90028b.dat\n")
    (folder / "90001.dat").write_text("0 Brick 2 x 4\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 s/90001s01.dat\n")
    stub = cadtask.moved_to("90028", [folder])
    assert stub == ("90028b", (0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0), (5.0, 0.0, 0.0))
    assert cadtask.moved_to("90001", [folder]) is None
    # 7223-1's wheel: turned half round, so the stub's 5 LDU goes the other way.
    part = cadtask.Part(line("90028", 0, -29, -3, -40, "-1 0 0 0 1 0 0 0 -1"))
    moved = cadtask.as_moved(part, stub)
    assert moved.id == "90028b"
    assert moved.at == (-34.0, -3.0, -40.0)
    assert moved.turn == (0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0)


def test_the_lift_is_taken_off_up_the_y_axis():
    # Lifted 16 LDU in the app is 16 less in LDraw's y.
    before = [line("3001", 4, 0, 0, 0), line("3001", 4, 0, -24, 0, steps="1")]
    after = [line("3001", 4, 0, -16, 0), line("3001", 4, 0, -40, 0, steps="1")]
    assert cadtask.compare(before, after)["why"] == {"moved": 2}
    assert cadtask.compare(before, after, shift=16.0)["exact"] is True


def test_steps_merged_or_reordered_are_not_kept_but_renumbered_are():
    before = [line("3001", 4, 0, -24, 0, steps="0"), line("3001", 4, 0, -48, 0, steps="1")]
    merged = [line("3001", 4, 0, -24, 0, steps="0"), line("3001", 4, 0, -48, 0, steps="0")]
    swapped = [line("3001", 4, 0, -24, 0, steps="1"), line("3001", 4, 0, -48, 0, steps="0")]
    gapped = [line("3001", 4, 0, -24, 0, steps="2"), line("3001", 4, 0, -48, 0, steps="5")]
    assert cadtask.compare(before, merged)["steps_kept"] is False
    assert cadtask.compare(before, swapped)["steps_kept"] is False
    assert cadtask.compare(before, gapped)["steps_kept"] is True
    assert cadtask.compare(before, merged, steps=False)["exact"] is True


def test_submodels_by_membership_not_by_name():
    before = [line("3001", 4, 0, -24, 0, unit="Wing#1"), line("3001", 4, 0, -48, 0, unit="Wing#2")]
    renamed = [line("3001", 4, 0, -24, 0, unit="wing#1"), line("3001", 4, 0, -48, 0, unit="wing#2")]
    flat = [line("3001", 4, 0, -24, 0), line("3001", 4, 0, -48, 0)]
    assert cadtask.compare(before, renamed)["submodels_kept"] is True
    assert cadtask.compare(before, flat)["submodels_kept"] is False


def _row(lift: float, reopened: list[str], metas_after: dict, file_parts=None,
         author: str = "Brickworks", missing: dict | None = None, kept: bool = False,
         opened=None) -> dict:
    truth = [line("3001", 4, 0, 0, 0), line("3023", 15, 0, -24, 0, steps="1")]
    return {
        "file": "x.mpd", "in": "mpd",
        "truth": {"parts": truth, "authored": True, "author": "A. Builder",
                  "metas": {"!LICENSE": 1, "STEP": 2, "Author:": 1}},
        "open": {"lifted_by": lift, "missing_ids": missing or {}, "kept": kept},
        "opened": reopened if opened is None else opened,
        "out": {"ldr": {"bytes": 10, "save_ms": 1, "reopened": reopened,
                        "file": {"author": author, "metas": metas_after,
                                 "parts": reopened if file_parts is None else file_parts}}},
    }


def test_the_file_itself_exact_when_it_says_what_it_said():
    """A saved file read as the original was: the numbers as written (3023,
    not 3023b), the file's coordinates (not lifted), its meta lines and its
    author; the app's model the same when it opens again."""
    truth = [line("3001", 4, 0, 0, 0), line("3023", 15, 0, -24, 0, steps="1")]
    lifted = [line("3001", 4, 0, -8, 0), line("3023b", 15, 0, -32, 0, steps="1")]
    kept = cadtask.judge_file(_row(8.0, lifted, {"!LICENSE": 1, "STEP": 2, "Author:": 1},
                                   file_parts=truth, author="A. Builder"))
    ldr = kept["formats"]["ldr"]
    assert ldr["file"]["exact"] and ldr["metas_kept"] and ldr["exact_file"]
    # The same parts, but the licence gone: not exact.
    lost = cadtask.judge_file(_row(8.0, lifted, {"STEP": 2, "Author:": 1},
                                   file_parts=truth, author="A. Builder"))
    assert lost["formats"]["ldr"]["file"]["exact"] and not lost["formats"]["ldr"]["exact_file"]
    # Written as the part it became: not the file's number.
    renumbered = cadtask.judge_file(_row(8.0, lifted, {"!LICENSE": 1, "STEP": 2, "Author:": 1},
                                         file_parts=[truth[0], line("3023b", 15, 0, -24, 0,
                                                                    steps="1")],
                                         author="A. Builder"))
    assert not renumbered["formats"]["ldr"]["exact_file"]
    summary = cadtask.summarise([kept, lost, renumbered])["formats"]["ldr"]
    assert summary["exact_file"] == 1 and summary["file_parts_exact"] == 2
    assert summary["metas_kept"] == 2


def test_a_part_not_shown_is_lost_on_open_unless_kept():
    shown = [line("3001", 4, 0, -8, 0)]
    told = cadtask.judge_file(_row(8.0, shown, {}, missing={"3023": 1}, kept=True))
    assert told["open_lost"] == 0 and told["unshown_kept"] == 1
    dropped = cadtask.judge_file(_row(8.0, shown, {}, missing={"3023": 1}, kept=False))
    assert dropped["open_lost"] == 1 and dropped["unshown_kept"] == 0
    assert cadtask.summarise([told, dropped])["formats"]["ldr"]["open_lost_parts"] == 1


def test_judge_and_summarise_count_formats_and_losses():
    lifted = [line("3001", 4, 0, -8, 0), line("3023b", 15, 0, -32, 0, steps="1")]
    judged = [cadtask.judge_file(_row(8.0, lifted, {"STEP": 2, "Author:": 1},
                                      file_parts=lifted)),
              cadtask.judge_file({"file": "bad.mpd", "in": "mpd", "error": "could not read"})]
    one = judged[0]["formats"]["ldr"]
    assert one["strict"]["exact"] is False
    assert one["up_to_lift"]["why"] == {"renumbered": 1}
    assert one["metas_lost"] == {"!LICENSE": 1}
    assert one["author_kept"] is False
    summary = cadtask.summarise(judged)
    ldr = summary["formats"]["ldr"]
    assert summary["unreadable"] == ["bad.mpd"]
    assert ldr["files"] == 1 and ldr["exact"] == 0 and ldr["exact_up_to_lift"] == 0
    assert ldr["same_shapes_up_to_lift"] == 1
    assert dict(ldr["losses_by_files"])["lifted onto the ground"] == 1
    assert dict(ldr["losses_by_files"])["author line rewritten"] == 1
    assert ldr["metas_lost_by_files"] == [("!LICENSE", 1)]
    assert ldr["parts_back"] == 2 and ldr["parts_paired"] == 1


# -- the frames ---------------------------------------------------------------------

def test_choose_frames_one_near_each_size_in_order():
    info = {"a-1.mpd": (95, 3), "b-1.mpd": (104, 0), "c-1.mpd": (1050, 9),
            "d-1.mpd": (1200, 9), "e-1.mpd": (4600, 1)}
    got = cadtask.choose_frames(info, sizes=(100, 1000, 5000), near=0.1, salt="t")
    assert len(got) == 3
    assert got[0] in ("a-1.mpd", "b-1.mpd")
    assert got[1:] == ["c-1.mpd", "e-1.mpd"]
    assert cadtask.choose_frames(info, sizes=(100000,)) == []


def test_frame_table_marks_what_is_over_budget():
    desktop = {"models": [{"file": "m.mpd", "open": {"to_drawn_ms": 812.5, "placed": 92},
                           "orbit": {"frames": 60, "median_ms": 9.0, "p95_ms": 12.0,
                                     "max_ms": 15.0},
                           "undo": {"frames": 20, "median_ms": 12.0, "p95_ms": 16.0,
                                    "max_ms": 40.0},
                           "timeline_open_ms": 300.0}]}
    web = {"models": [{"file": "m.mpd", "open": {"to_quiet_ms": 9000},
                       "orbit": {"frames": 40, "median_ms": 1.0, "p95_ms": 34.0,
                                 "max_ms": 35.0},
                       "undo": {"frames": 0, "median_ms": 0, "max_ms": 0, "ms": 3010}}]}
    rows = cadtask.frame_table(desktop, web)
    by = {(r["platform"], r["act"]): r for r in rows}
    assert by[("desktop", "orbit")]["max_over"] is False
    assert by[("desktop", "undo")]["max_over"] is True
    assert by[("desktop", "undo")]["p95_over"] is False
    assert by[("web", "orbit")]["p95_over"] is True and by[("web", "orbit")]["median_over"] is False
    assert by[("desktop", "open")]["total_ms"] == 812.5
    assert by[("web", "open")]["total_ms"] == 9000
    assert by[("desktop", "timeline opens")]["total_ms"] == 300.0
    # No frame finished in the 3 s it was given: longer than that, a miss.
    assert by[("web", "undo")]["longer_than_ms"] == 3010 and by[("web", "undo")]["p95_over"]
    assert len(rows) == 7
