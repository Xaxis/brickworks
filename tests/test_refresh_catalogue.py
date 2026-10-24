"""A catalogue refresh makes the knowledge files made from the same tables
again, and fails loudly when it cannot.

tools/minifig_sets.py and tools/set_sizes.py (figs217) read Rebrickable's
inventories, the OMR and the catalogue, and nothing ran them after a
refresh: the figure parts and the sizes a design reads would fall a
refresh behind. tools/refresh_catalogue.py runs both after it writes the
catalogue (knowledge). These run it over stand-in tools, so what is held
is the refresh's part: each run with the catalogue it was given, each
file replaced only when its tool succeeded with something in it, and a
failure named and raised, with the file there before kept.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import refresh_catalogue  # noqa: E402

# A stand-in for one of the two tools: writes {"format": 1, LISTED: [...]}
# to --out, with the --generated folder it was given in it, or fails.
STAND_IN = '''
import argparse, json, sys
from pathlib import Path
ask = argparse.ArgumentParser()
ask.add_argument("--generated", type=Path)
ask.add_argument("--out", type=Path)
args = ask.parse_args()
how = {how!r}
if how == "fails":
    print("no vendor/rebrickable/inventories.csv.gz", file=sys.stderr)
    sys.exit(1)
listed = [] if how == "empty" else [str(args.generated)]
args.out.write_text(json.dumps({{"format": 1, {listed!r}: listed}}))
print("made", args.out)
'''


def _tools(where: Path, minifig: str = "works", sizes: str = "works") -> Path:
    where.mkdir()
    (where / "minifig_sets.py").write_text(STAND_IN.format(how=minifig, listed="parts"))
    (where / "set_sizes.py").write_text(STAND_IN.format(how=sizes, listed="models"))
    return where


def _before(out: Path) -> None:
    out.mkdir()
    for _tool, name, listed in refresh_catalogue.KNOWLEDGE:
        (out / name).write_text(json.dumps({"format": 1, listed: ["before"]}))


def test_the_refresh_makes_both_from_the_catalogue_it_was_given(tmp_path: Path) -> None:
    tools = _tools(tmp_path / "tools")
    out = tmp_path / "knowledge"
    _before(out)
    said = refresh_catalogue.knowledge(tmp_path / "generated", out, tools)
    for _tool, name, listed in refresh_catalogue.KNOWLEDGE:
        made = json.loads((out / name).read_text())
        assert made[listed] == [str(tmp_path / "generated")], name
        assert not (out / (name + ".new")).exists()
    assert any("minifig_sets.json" in line for line in said)
    assert any("set_sizes.json" in line for line in said)


@pytest.mark.parametrize("minifig, sizes, behind", [
    ("fails", "works", ["minifig_sets.py"]),
    ("works", "empty", ["set_sizes.py"]),
    ("fails", "fails", ["minifig_sets.py", "set_sizes.py"]),
])
def test_one_that_fails_fails_the_refresh_and_keeps_the_old_file(
        tmp_path: Path, minifig: str, sizes: str, behind: list[str]) -> None:
    tools = _tools(tmp_path / "tools", minifig, sizes)
    out = tmp_path / "knowledge"
    _before(out)
    said = ""
    try:
        refresh_catalogue.knowledge(tmp_path / "generated", out, tools)
    except refresh_catalogue.Behind as behind_now:
        said = str(behind_now)
    assert said, "a failed tool was not raised"
    for tool, name, listed in refresh_catalogue.KNOWLEDGE:
        made = json.loads((out / name).read_text())
        if tool in behind:
            assert tool in said and name in said
            assert made[listed] == ["before"], name
        else:
            # The other is still made: one failing is no reason to leave both.
            assert tool not in said
            assert made[listed] == [str(tmp_path / "generated")], name
        assert not (out / (name + ".new")).exists()
    if minifig == "fails":
        assert "no vendor/rebrickable/inventories.csv.gz" in said
