"""Tests for the BrickBench export: a design read, squared up and written as their build.py wants.

verify.py rebuilds a submission from its build.py, with brickagent's Pose,
which refuses a rotation off orthonormal by more than 1e-8. These pin that
an LDraw placement comes out of build.py where it went in: sub-models
followed, colour 16 taken from the line that placed them, quarter turns
kept exact and rounded rotations squared up without moving them, a mirror
refused; that a part off BrickNet's list is said; that verify.py's report
is read right; and that the two systems' ELO across prompts comes out of
the verdicts the right way round.
"""

from __future__ import annotations

import ast
import json
import sys
import tempfile
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import brickbench as bb  # noqa: E402
from bench import pairwise  # noqa: E402

QUARTER = (0.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 0.0)       # a quarter turn about y
# LDraw's own minifig hand, as every model writes it: three places, not a rotation.
HAND = (0.98500001, -0.12, 0.12, 0.17, 0.69600004, -0.69600004, 0.0, 0.70700002, 0.70700002)

# A model whose parts land where this file says. The arm, a sub-model, is put
# at (10, -24, 20) turned a quarter about y, in red (4): its brick, at (20, 0, 0)
# in colour 16, ends up at (10, -24, 0), red, turned the same way. The hand is
# placed directly, at its rounded rotation.
MODEL = """0 FILE main.ldr
0 test
1 4 10 -24 20 0 0 1 0 1 0 -1 0 0 arm.ldr
1 14 -23.69 -45.226 -8.648 0.98500001 -0.12 0.12 0.17 0.69600004 -0.69600004 0 0.70700002 0.70700002 3820.dat
1 2 0 0 0 1 0 0 0 1 0 0 0 1 60602.dat

0 FILE arm.ldr
0 arm
1 16 20 0 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 0 -8 0 1 0 0 0 1 0 0 0 1 3023b.dat
"""


def _built(source: str) -> list[tuple]:
    """build.py run against a brickagent that only records what is added."""
    added: list[tuple] = []

    class Pose:
        def __init__(self, rot, t):
            self.rot, self.t = tuple(rot), tuple(t)

    class Assembly:
        def __init__(self, name):
            self.name = name

        def add(self, what, *, pose, color):
            added.append((what, color, pose.rot, pose.t))

    stub = types.ModuleType("brickagent")
    setattr(stub, "Assembly", Assembly)
    setattr(stub, "Pose", Pose)
    was = sys.modules.get("brickagent")
    sys.modules["brickagent"] = stub
    try:
        scope: dict = {"__name__": "build"}
        exec(compile(source, "build.py", "exec"), scope)
        scope["build"]()
    finally:
        if was is None:
            del sys.modules["brickagent"]
        else:
            sys.modules["brickagent"] = was
    return added


def _export(text: str, allowed: set[str]) -> tuple[dict, str]:
    with tempfile.TemporaryDirectory() as folder:
        ldr = Path(folder) / "design.ldr"
        ldr.write_text(text)
        found = bb.export_one("model-001", "A test model.", ldr, Path(folder) / "out", allowed, "a test")
        return found, (Path(folder) / "out" / "build.py").read_text()


def test_a_known_placement_comes_out_of_build_py_where_it_went_in():
    found, source = _export(MODEL, {"3001", "3023b", "3820"})
    added = {what: (colour, rot, at) for what, colour, rot, at in _built(source)}
    assert found["parts"] == 4 and found["written"] == 4
    colour, rot, at = added["3001"]
    assert at == (10.0, -24.0, 0.0)          # the arm's turn and move, applied to (20, 0, 0)
    assert rot == QUARTER                    # a quarter turn stays exactly that
    assert colour == 4                       # 16 inside the arm is the arm's red
    colour, rot, at = added["3023b"]
    assert at == (10.0, -32.0, 20.0) and colour == 1
    colour, rot, at = added["3820"]
    assert at == (-23.69, -45.226, -8.648) and colour == 14
    assert bb.orthonormality(rot) <= 1e-12
    assert max(abs(a - b) for a, b in zip(rot, HAND)) < 2e-3    # squared up, not turned
    assert added["60602"][1] == (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)


def test_build_py_is_what_check_submission_accepts():
    _, source = _export(MODEL, {"3001"})
    tree = ast.parse(source)
    assert any(isinstance(node, ast.FunctionDef) and node.name == "build" for node in tree.body)
    assert 'build().write("model.mpd")' in source and 'if __name__ == "__main__":' in source


def test_a_part_off_the_list_and_a_model_over_the_limit_are_said():
    found, _ = _export(MODEL, {"3001", "3023b", "3820"})
    assert found["off_list"] == ["60602"] and not found["over_limit"]
    many = "0 FILE main.ldr\n" + "".join(
        f"1 4 {20 * n} 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" for n in range(bb.MOST_PARTS + 1))
    found, _ = _export(many, {"3001"})
    assert found["over_limit"] and found["parts"] == bb.MOST_PARTS + 1


def test_quarter_turns_stay_exact_and_rounded_turns_are_squared_up():
    assert bb.orthonormal(QUARTER) == QUARTER
    assert bb.orthonormal((1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)) == (
        1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    # 45 degrees about y, to six places as an LDraw line has it.
    c = 0.707107
    rounded = (c, 0.0, c, 0.0, 1.0, 0.0, -c, 0.0, c)
    assert bb.orthonormality(rounded) > 1e-8              # what Pose would refuse
    squared = bb.orthonormal(rounded)
    assert bb.orthonormality(squared) <= 1e-12
    assert max(abs(a - b) for a, b in zip(squared, rounded)) < 1e-6
    assert squared[4] == 1.0 and squared[1] == 0.0        # the exact entries kept exact


def test_a_mirror_is_refused():
    for mirrored in ((-1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0),
                     (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)):
        try:
            bb.orthonormal(mirrored)
        except ValueError:
            continue
        raise AssertionError(f"accepted {mirrored}")
    found, _ = _export("1 4 0 0 0 -1 0 0 0 1 0 0 0 1 3001.dat\n", {"3001"})
    assert found["written"] == 0 and "3001" in found["refused"][0]


def test_the_ten_prompts_are_the_first_ten_and_each_brief_carries_the_limit():
    tasks = json.dumps([{"id": f"model-{n:03d}", "prompt": f"Prompt {n}.", "questions": []}
                        for n in range(1, 13)])
    chosen = bb.first_tasks(tasks)
    assert [t["id"] for t in chosen] == [f"model-{n:03d}" for n in range(1, 11)]
    assert chosen[0]["brief"] == "Prompt 1. Use at most 400 pieces."
    assert bb.title_of("A knight sits. He waits.") == "A knight sits"


def test_the_parts_list_is_what_parts_only_reads():
    text = bb.parts_text(["3023b", "3001", "3001"])
    assert text.splitlines()[0].startswith("# BrickNet's 14,441 parts")
    assert text.splitlines()[1:] == ["3001", "3023b"]
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "parts.txt"
        path.write_text(text)
        assert bb.read_allowed(path) == {"3001", "3023b"}


VALID = {"valid": True, "errors": [], "parts": 125, "distinct_parts": 40, "connected_components": 1,
         "full_default_check": "passed", "mpd_geometry_reproduced": True}
INVALID = {"valid": False, "parts": 367, "connected_components": 10, "full_default_check": "failed",
           "errors": ["ValueError: 367 parts; 10 collision pairs; 10 connected components; stability "
                      "not simulated until the collisions are resolved\ncollision: #16 18976c01 <> #21 3705"]}
FALLS = {"valid": False, "parts": 50, "connected_components": 3, "full_default_check": "failed",
         "errors": ["ValueError: 50 parts; 0 collision pairs; 3 connected components\nunstable component "
                    "a: moved more than 3 LDU\nunstable component b: moved more than 3 LDU"]}


def test_verify_reports_are_read_as_the_table_and_the_judge_say_them():
    row = bb.verify_row(VALID)
    assert row["valid"] and row["collisions"] == 0 and row["components"] == 1
    assert bb.verify_words(VALID).startswith("BrickBench's verify.py: valid. 125 parts in 1")
    row = bb.verify_row(INVALID)
    assert not row["valid"] and row["collisions"] == 10 and not row["stability_run"]
    assert "10 colliding pairs" in bb.verify_words(INVALID)
    row = bb.verify_row(FALLS)
    assert row["unstable"] == 2 and row["stability_run"] and row["collisions"] == 0
    assert "2 piece(s) fall or slide" in bb.verify_words(FALLS)


def _verdicts(ours_wins: dict[str, int]) -> list[pairwise.Verdict]:
    """Each task's two orders: ours wins `n` of them (0, 1 or 2)."""
    out = []
    for task, n in ours_wins.items():
        a, b = f"{bb.OURS}/{task}", f"{bb.THEIRS}/{task}"
        for k, (first, second) in enumerate(((a, b), (b, a))):
            winner = a if k < n else b
            out.append(pairwise.Verdict(first, second, {d: winner for d in pairwise.DIMENSIONS}, {}))
    return out


def test_the_two_systems_stand_the_right_way_round():
    ahead = bb.standing(_verdicts({f"model-{n:03d}": 2 if n <= 8 else 0 for n in range(1, 11)}),
                        "overall", draws=300)
    assert ahead.elo[bb.OURS] > ahead.elo[bb.THEIRS]
    assert ahead.won == 16 and ahead.of == 20
    assert ahead.pairs == {"won": 8, "split": 0, "lost": 2}
    assert ahead.low[bb.OURS] > 1000 > ahead.high[bb.THEIRS]
    level = bb.standing(_verdicts({f"model-{n:03d}": 1 for n in range(1, 11)}), "overall", draws=300)
    assert abs(level.elo[bb.OURS] - 1000) < 1e-6 and level.pairs["split"] == 10
