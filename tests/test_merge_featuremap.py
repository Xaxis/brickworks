"""tools/merge_featuremap.py: two branches that each add a feature merge."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

DRIVER = Path(__file__).resolve().parent.parent / "tools" / "merge_featuremap.py"


def entry(label, reach="probe"):
    return {"kind": "ui", "label": label, "entry": f"src/{label}.gd",
            "reach": reach, "area": "x"}


def run(base, ours, theirs):
    with tempfile.TemporaryDirectory() as where:
        tmp = Path(where)
        for name, data in (("O", base), ("A", ours), ("B", theirs)):
            (tmp / name).write_text(json.dumps(data, indent=2) + "\n")
        done = subprocess.run([sys.executable, str(DRIVER), str(tmp / "O"),
                               str(tmp / "A"), str(tmp / "B")])
        return done.returncode, json.loads((tmp / "A").read_text())


def test_both_sides_adding_an_entry_keep_both_ours_first():
    base = {"ignore": ["vendor/**"], "manual": [entry("a")]}
    ours = {"ignore": ["vendor/**"], "manual": [entry("a"), entry("b")]}
    theirs = {"ignore": ["vendor/**", "shots/**"], "manual": [entry("a"), entry("c")]}
    code, merged = run(base, ours, theirs)
    assert code == 0
    assert [e["label"] for e in merged["manual"]] == ["a", "b", "c"]
    assert merged["ignore"] == ["vendor/**", "shots/**"]


def test_a_removal_on_one_side_holds():
    base = {"manual": [entry("a"), entry("b")]}
    ours = {"manual": [entry("a"), entry("b"), entry("c")]}
    theirs = {"manual": [entry("a")]}
    code, merged = run(base, ours, theirs)
    assert code == 0
    assert [e["label"] for e in merged["manual"]] == ["a", "c"]


def test_a_change_on_one_side_is_taken():
    base = {"manual": [entry("a")]}
    ours = {"manual": [entry("a"), entry("b")]}
    theirs = {"manual": [entry("a", reach="new probe")]}
    code, merged = run(base, ours, theirs)
    assert code == 0
    assert merged["manual"][0]["reach"] == "new probe"


def test_the_same_entry_changed_both_ways_is_left_to_a_person():
    base = {"manual": [entry("a")]}
    ours = {"manual": [entry("a", reach="mine")]}
    theirs = {"manual": [entry("a", reach="theirs")]}
    code, merged = run(base, ours, theirs)
    assert code == 1
    assert merged["manual"][0]["reach"] == "mine"  # untouched for git's markers
