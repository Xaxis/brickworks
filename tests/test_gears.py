"""The gear table src/assembly/mechanism.gd reads tooth counts from, checked
against the catalogue, the parts' own connectors and real sets (tools/gears.py).

Each test fails on the table it guards: a gear left out, a tooth count
that is not the name's, a hole the part does not have, a tooth size off
module 1 mm.
"""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import gears  # noqa: E402

needs_catalogue = pytest.mark.skipif(not gears.CATALOGUE.exists(),
                                     reason="no mesh cache; run tools/build_meshes.py")
needs_ldraw = pytest.mark.skipif(not (gears.LDRAW / "parts").is_dir(),
                                 reason="LDraw library not present; run tools/fetch_data.sh")
needs_sets = pytest.mark.skipif(not gears.OMR.is_dir(),
                                reason="no OMR sets; run tools/omr.py fetch")

_catalogue: dict = {}


def catalogue() -> dict:
    if not _catalogue:
        _catalogue.update(json.loads(gears.CATALOGUE.read_text()))
    return _catalogue


@needs_catalogue
def test_every_toothed_technic_part_is_in_the_table() -> None:
    table = gears.load_table()
    toothed = gears.toothed_parts(catalogue())
    # The name rule finds the gears there are: the 24 and the 60 turntable.
    assert "3648b" in toothed and toothed["3648b"][1] == 24
    assert "18938" in toothed and toothed["18938"][1] == 60
    assert gears.check_names(table, catalogue()) == []


@needs_catalogue
def test_a_gear_left_out_or_miscounted_is_caught() -> None:
    table = copy.deepcopy(gears.load_table())
    del table["gears"]["3649"]
    table["gears"]["4019"]["teeth"] = 15
    problems = gears.check_names(table, catalogue())
    assert any(p.startswith("3649 ") and "not in the gear table" in p for p in problems)
    assert any(p.startswith("4019 ") and "15 teeth" in p for p in problems)


@needs_catalogue
def test_spur_gears_are_module_one() -> None:
    table = gears.load_table()
    assert gears.check_sizes(table, catalogue()) == []
    wrong = copy.deepcopy(table)
    wrong["gears"]["3648a"]["teeth"] = 28
    assert any(p.startswith("3648a") for p in gears.check_sizes(wrong, catalogue()))


@needs_ldraw
def test_every_gear_has_the_hole_the_table_says() -> None:
    # 3648a's centre axle hole is drawn without a hole primitive, and 6542a's
    # is a plain cylinder: connectivity.py reads both now.
    assert gears.check_holes(gears.load_table()) == []
    wrong = copy.deepcopy(gears.load_table())
    wrong["gears"] = {"3647": dict(wrong["gears"]["3647"], hole="round")}
    assert gears.check_holes(wrong) != []


@needs_sets
def test_real_sets_stand_their_gears_one_and_a_quarter_ldu_a_tooth_apart() -> None:
    table = gears.load_table()
    files = [p for p in gears._set_files() if p.name.startswith(("42055", "42082", "8020"))]
    tally = gears.spacing(files, table)
    total = sum(tally.values())
    close = tally["0.1"] + tally["0.3"]
    assert total > 50
    assert close / total > 0.9, tally
    # At 1.3 LDU a tooth, the same sets mostly miss.
    wrong = copy.deepcopy(table)
    wrong["ldu_per_tooth"] = 1.3
    off = gears.spacing(files, wrong)
    assert (off["0.1"] + off["0.3"]) < close / 2
