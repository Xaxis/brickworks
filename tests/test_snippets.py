"""Tests for tools/snippets.py: finding real sets' pieces by what they are.

A tiny hand-made index, so the right answer is known before the search
runs: an owl set's eye before a car set's eye when the owl is asked for,
"eyes" and "EyeL" read as eye, a Y-wing is not a wing, a piece too big
for max_studs is not offered, and no set fills the answer on its own.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import snippets  # noqa: E402


def _entry(id: str, name: str, set_name: str, size=(2, 1, 2), kinds=(), text="",
           within=()) -> dict:
    entry = {"id": id, "kind": "named", "name": name, "in": list(within),
             "set": id.split("/")[0], "set_name": set_name, "theme": "Creator",
             "year": 2020, "by": "A. Modeller", "licence": "CC BY 2.0",
             "parts": 3, "size": list(size), "ldr": [], "square": True,
             "kinds": list(kinds), "bom": [], "text": text}
    entry["subject"] = snippets._subject_words(set_name, *within, name)
    entry["t"] = snippets._terms(entry)
    return entry


def _index(*given: dict) -> dict:
    entries = list(given)
    snippets._weigh(entries)
    return {"entries": entries, "idf": snippets._idf(entries),
            "average": snippets._average(entries)}


def _ids(found) -> list[str]:
    return [entry["id"] for _, entry in found]


def test_words_see_through_plurals_and_case() -> None:
    assert snippets.words("EyeL") == ["eye"]
    assert snippets.words("Eyes") == ["eye"]
    assert snippets.words("Leaves and Feet") == ["leaf", "foot"]
    assert snippets.words("10302 - step 12 sub 3") == []


def test_a_y_wing_is_not_a_wing() -> None:
    assert snippets.words("Y-Wing Starfighter") == ["ywing", "starfighter"]
    # but left and right stay apart from what they qualify
    assert snippets.words("L-Arm") == ["arm"]


def test_the_subject_set_comes_first() -> None:
    document = _index(
        _entry("1-1/eye", "Eye", "Sports Car", text="headlight eye"),
        _entry("2-1/eye", "Eye L", "Owl", within=["Head"]),
        _entry("3-1/wing", "Wing", "Owl"),
    )
    assert _ids(snippets.search(document, "owl eye")) == ["2-1/eye", "1-1/eye", "3-1/wing"]
    # and a car's eye when the car is asked for
    assert _ids(snippets.search(document, "car eye"))[0] == "1-1/eye"


def test_the_subject_before_its_kind() -> None:
    document = _index(
        _entry("1-1/wing", "Wing", "Parrot"),
        _entry("2-1/wing", "Wing", "Fighter Jet"),
        _entry("3-1/wing", "Wing L", "Dragon"),
    )
    # a dragon's wing, then a bird's (an animal's), then a jet's
    assert _ids(snippets.search(document, "dragon wing")) == ["3-1/wing", "1-1/wing", "2-1/wing"]


def test_a_synonym_finds_the_piece() -> None:
    document = _index(_entry("1-1/hood", "Hood", "Sports Car"),
                      _entry("2-1/roof", "Roof", "House"))
    assert _ids(snippets.search(document, "bonnet")) == ["1-1/hood"]


def test_two_words_run_together() -> None:
    document = _index(_entry("1-1/wheelarch", "Wheelarch", "Truck"),
                      _entry("2-1/arch", "Arch", "Castle"))
    assert _ids(snippets.search(document, "wheel arch"))[0] == "1-1/wheelarch"


def test_filters() -> None:
    document = _index(
        _entry("1-1/wing", "Wing", "Dragon", size=(12, 2, 8)),
        _entry("2-1/wing", "Wing", "Bird", size=(3, 1, 2), kinds=["sideways"]),
    )
    assert _ids(snippets.search(document, "wing", max_studs=4)) == ["2-1/wing"]
    assert _ids(snippets.search(document, "wing", kinds=["sideways"])) == ["2-1/wing"]
    assert _ids(snippets.search(document, "wing", kinds=["curved"])) == []


def test_no_set_fills_the_answer() -> None:
    document = _index(*[_entry(f"1-1/door-{n}", "Door", "House") for n in range(4)],
                      _entry("2-1/door", "Door", "Shop"))
    found = _ids(snippets.search(document, "door", per_set=2))
    assert len(found) == 3 and "2-1/door" in found


def test_credit_and_licence() -> None:
    assert snippets._licence("Redistributable under CCAL version 2.0 : see CAreadme.txt") \
        == "CC BY 2.0"
    assert snippets._licence("Licensed under CC BY 4.0 : see CAreadme.txt") == "CC BY 4.0"
    assert snippets._author("Robert Paciorek [bercik]") == "Robert Paciorek"
    assert snippets._author("[EdmanZA]") == "EdmanZA"


def test_a_mirror_image_is_not_square() -> None:
    assert snippets._square([0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0])
    assert not snippets._square([0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, 1])
    assert not snippets._square([0, 0, 0, 0.707, 0, 0.707, 0, 1, 0, -0.707, 0, 0.707])
