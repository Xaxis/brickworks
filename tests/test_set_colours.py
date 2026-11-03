"""tools/set_colours.py: a set's colours as shares of its parts, and the file
ColoursSeen (src/ai/colours_seen.gd) reads them from."""

import gzip
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import set_colours  # noqa: E402


def test_colours_are_shares_of_the_parts_most_first():
    # 100 parts: red 80%, white 15%, black 4%, blue 1%.
    parts = [["3001", 4, 60], ["3002", 4, 20], ["3003", 15, 15], ["3004", 0, 4], ["3005", 1, 1]]
    assert set_colours.colours(parts) == [[4, 800], [15, 150], [0, 40], [1, 10]]


def test_a_colour_under_the_floor_is_left_out():
    assert set_colours.colours([["3001", 4, 999], ["3005", 1, 1]]) == [[4, 999]]


def test_the_shipped_file_is_the_sets_as_the_app_reads_them():
    document = json.loads(gzip.decompress(set_colours.OUT.read_bytes()))
    city = document["themes"].index("City")
    row = next(r for r in document["sets"] if r[0] == "7992-1")
    assert row[1:4] == ["Container Stacker", city, 219]
    assert row[4] and all(mille >= set_colours.SHARE for _code, mille in row[4])
    assert all(r[3] >= 20 for r in document["sets"])
