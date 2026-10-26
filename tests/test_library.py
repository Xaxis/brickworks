"""The model library's index, held to the format the app's library screen reads.

tools/library_build.py writes library/index.json from LDraw's official set
models, and the screen is built against its format by another hand, so the
format is pinned here: the fields and their order, their kinds, the paths
laid out as the store holds them, a licence the library may pass on and an
author for every model, and LEGO® with its mark. The checker is tested on
indexes broken one way at a time, so it is known to catch each, and then run
on the index built from the real files, and on the staged one when there is
one.
"""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import library_build as lb  # noqa: E402

needs_omr = pytest.mark.skipif(
    not (lb.OMR / "files").is_dir() or not lb.MODELS.is_file(),
    reason="no vendor/omr/files or models.json (tools/omr.py fetch)")
STAGED = lb.DEFAULT_OUT / "library" / "index.json"


def good() -> dict:
    return {"version": 1, "models": [{
        "id": "omr-10179-1", "kind": "set", "set": "10179-1",
        "name": "Ultimate Collector's Millennium Falcon", "theme": "Star Wars", "year": 2007,
        "parts": 5264, "box": 5205, "file": "library/omr/10179-1.mpd",
        "cover": "library/covers/omr-10179-1.webp", "author": "Roland Dahl",
        "licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/657",
        "alternate_of": None}]}


def test_a_good_index_has_no_problems() -> None:
    assert lb.problems(good()) == []


@pytest.mark.parametrize("break_it, said", [
    (lambda m: m.pop("author"), "fields"),
    (lambda m: m.update(extra=1), "fields"),
    (lambda m: m.update(licence="Free for non-commercial use."), "licence"),
    (lambda m: m.update(year="2007"), "year"),
    (lambda m: m.update(parts=0), "parts"),
    (lambda m: m.update(box=-1), "box"),
    (lambda m: m.update(file="omr/10179-1.mpd"), "file"),
    (lambda m: m.update(cover="library/covers/10179-1.webp"), "cover"),
    (lambda m: m.update(alternate_of="10180-1"), "alternate_of"),
    (lambda m: m.update(name="LEGO Truck"), "LEGO without its ®"),
    (lambda m: m.update(page="library.ldraw.org/omr/sets/657"), "page"),
    (lambda m: m.update(id="10179-1"), "id"),
])
def test_each_way_of_breaking_a_model_is_caught(break_it, said) -> None:
    index = good()
    break_it(index["models"][0])
    found = lb.problems(index)
    assert found and any(said in line for line in found), found


def test_a_model_twice_and_a_wrong_version_are_caught() -> None:
    index = good()
    index["models"].append(copy.deepcopy(index["models"][0]))
    assert any("id twice" in line for line in lb.problems(index))
    index = good()
    index["version"] = 2
    assert lb.problems(index)


def test_marks() -> None:
    assert lb.with_marks("LEGO Truck") == "LEGO® Truck"
    assert lb.with_marks("60 Years of the LEGO Brick") == "60 Years of the LEGO® Brick"
    assert lb.with_marks("LEGO® House") == "LEGO® House"
    assert lb.with_marks("as the LEGO Group made it") == "as the LEGO Group made it"
    assert lb.with_marks("Legoland > Space") == "LEGOLAND® > Space"
    assert lb.with_marks("Fort Legoredo") == "Fort Legoredo"


def test_licences_and_authors_as_headers_say_them() -> None:
    assert lb.licence_of("Redistributable under CCAL version 2.0 : see CAreadme.txt") == "CCAL 2.0"
    # One file runs its !HELP line into its licence line.
    assert lb.licence_of("Redistributable under CCAL version 2.0 : see CAreadme.txt0 !HELP "
                         "Copyright (c) 2002-2017, Robert Paciorek") == "CCAL 2.0"
    assert lb.licence_of("Licenced under CC BY 4.0 : see CAreadme.txt") == "CC BY 4.0"
    assert lb.licence_of("Redistributable under CCAL version 4.0 : see CAreadme.txt") == "CC BY 4.0"
    assert lb.licence_of("Free for non-commercial use.") == ""
    assert lb.author_name("Roland Dahl [RolandD]") == "Roland Dahl"
    assert lb.author_name("[bercik]") == "bercik"
    assert lb.safe_stem("10183-1_Pig's-nose-train") == "10183-1_Pigs-nose-train"


@needs_omr
def test_the_index_built_from_every_file_holds() -> None:
    models, left = lb.entries()
    index = lb.written(models)
    assert lb.problems(index) == []
    files = sorted((lb.OMR / "files").glob("*.mpd"))
    # Every file is in it or said to be left out, and why.
    assert len(models) + len(left) == len(files)
    assert len(models) >= 1500
    # Each file's own header read: an author for every one, and its licence.
    assert all(m["author"] != "unknown" for m in models)
    by = {lic: sum(1 for m in models if m["licence"] == lic) for lic in lb.LICENCES}
    assert sum(by.values()) == len(models) and by["CCAL 2.0"] > 1500 and by["CC BY 4.0"] >= 1
    # The B model of 10001-1 is the set's other build; the set's own is not.
    of = {m["id"]: m for m in models}
    assert of["omr-10001-1_B-Model-from-Instruction"]["alternate_of"] == "10001-1"
    assert of["omr-10001-1"]["alternate_of"] is None
    # Three cars of one set, with no model of the whole, are each its own.
    assert of["omr-10022-1_Dining-Car"]["alternate_of"] is None
    assert of["omr-3740-1_Model-B"]["alternate_of"] == "3740-1"


@pytest.mark.skipif(not STAGED.is_file(), reason="nothing staged (tools/library_build.py stage)")
def test_the_staged_index_and_its_files() -> None:
    index = json.loads(STAGED.read_text())
    assert lb.problems(index, lb.DEFAULT_OUT) == []
