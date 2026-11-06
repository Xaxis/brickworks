"""The train track ends src/assembly/track_snap.gd joins tracks by, measured
from the parts' own geometry (tools/track_ends.py).

Each test fails on the measure it guards: an end found on a face the track
reaches past, a face wound the other way taken for one facing in, a point's
frog rails taken for its ends, a rail's tapered tip left off, a direction
drawn a few thousandths of a degree off that sixteen curves carry to a gap.
The places a test expects are LeoCAD's (its library's traintrack.json),
which was made by hand and agrees with the measure.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import track_ends  # noqa: E402

needs_ldraw = pytest.mark.skipif(not (track_ends.LDRAW / "parts").is_dir(),
                                 reason="LDraw library not present; run tools/fetch_data.sh")


def _ends(part: str, joins: str, gauge: float | None = None) -> list[dict]:
    ends, _placed, why = track_ends.measure(part, joins, gauge)
    assert not why, why
    return [{"at": track_ends._app(e.at), "out": track_ends._app(e.out, 7), "kind": e.kind}
            for e in ends]


def _places(ends: list[dict]) -> set[tuple[float, float, float]]:
    return {tuple(round(v, 1) + 0.0 for v in e["at"]) for e in ends}


@needs_ldraw
def test_a_9v_straight_and_curve_have_leocads_ends() -> None:
    straight = _ends("74746", "clip")
    assert _places(straight) == {(160.0, -8.0, 0.0), (-160.0, -8.0, 0.0)}
    curve = _ends("74747", "clip")
    assert _places(curve) == {(156.1, -8.0, 15.4), (-156.1, -8.0, 15.4)}
    for end in curve:
        turn = math.degrees(math.atan2(end["out"][2], end["out"][0]))
        assert min(abs(turn - 11.25), abs(turn - 168.75)) < 1e-4
    assert {e["kind"] for e in straight + curve} == {"clip 110"}


@needs_ldraw
def test_sixteen_curves_close_a_circle() -> None:
    for part, joins, gauge in (("74747", "clip", None), ("3241ac01", "rails", 100.0)):
        assert track_ends.circle_gap(_ends(part, joins, gauge), 16) < 0.01, part


@needs_ldraw
def test_a_face_wound_the_other_way_still_faces_out() -> None:
    # 25061's second end is drawn mirrored: its faces are wound inwards.
    curve = _ends("25061", "face")
    assert _places(curve) == {(240.0, -8.0, 0.0), (0.0, -8.0, -240.0)}
    assert track_ends.circle_gap(curve, 4) < 0.01


@needs_ldraw
def test_a_points_ends_are_its_running_rails_not_its_frog() -> None:
    # Without the family's gauge its frog and check rails pair up as ends.
    assert len(_ends("73696c01", "rails")) > 3
    point = _ends("73696c01", "rails", 100.0)
    assert _places(point) == {(320.0, -16.0, 0.0), (320.0, -16.0, -160.0), (-320.0, -16.0, 0.0)}


@needs_ldraw
def test_a_tapered_rail_ends_at_its_tip() -> None:
    # 3231a's rails end in a face at 156 and taper on to 160, where the next
    # track's rails begin (LeoCAD's crossing has its ends at 160).
    crossing = _ends("3231a", "rails", 100.0)
    assert {round(math.hypot(e["at"][0], e["at"][2]), 1) for e in crossing} == {160.0}
    assert len(crossing) == 4


@needs_ldraw
def test_a_rails_end_knows_its_own_sleeper() -> None:
    ends, _placed, _why = track_ends.measure("3240ac01", "rails", 100.0)
    by_x = {round(track_ends._app(e.at)[0]): e.sleeper for e in ends}
    assert by_x == {-160: True, 160: False}


def test_check_fails_on_a_table_that_differs() -> None:
    table = json.loads(track_ends.TABLE.read_text())
    moved = json.loads(json.dumps(table))
    moved["tracks"]["74746"]["ends"][0]["at"][0] += 0.5
    assert any("not what the parts measure" in p for p in track_ends.check(moved, table))
    assert not [p for p in track_ends.check(table, table) if "not what" in p]
