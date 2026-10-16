"""Tests for tools/build_exact.py: BrickNet's colliders and connectors as the check reads them.

The build check judges overlaps by each part's convex pieces and connections by
BrickNet's labels, read from one file a shape. These pin that a piece's hull
comes out with every axis a separating-axis test needs and no false ones (the
diagonal of a flat face is no edge), that a flat piece keeps the axes a thin
polygon has, that a label row becomes the frame bricknet.data builds from it,
that everything lands in the app's frame (LDraw's x, -y, -z) with a connector's
axes still the directions they were, that an alias's matrix moves its shape, and
that a file reads back as it was written.
"""

from __future__ import annotations

import json
import lzma
import math
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_exact as be  # noqa: E402

try:
    import numpy  # noqa: F401
    import scipy  # noqa: F401
    HAVE_SCIPY = True
except ImportError:
    HAVE_SCIPY = False

needs_scipy = pytest.mark.skipif(
    not HAVE_SCIPY, reason="numpy/scipy not installed; apt install python3-numpy python3-scipy")

BOX = [(x, y, z) for x in (-10, 10) for y in (0, 8) for z in (-20, 20)]


def _close(a, b, within: float = 1e-6) -> bool:
    return all(abs(x - y) <= within for x, y in zip(a, b))


def test_a_label_row_is_bricknets_frame():
    # No angles: the identity, at the point.
    f = be.frame([10, 0, -10], "stud")
    assert _close([f[r][c] for r in range(3) for c in range(3)], [1, 0, 0, 0, 1, 0, 0, 0, 1])
    assert _close([f[0][3], f[1][3], f[2][3]], [10, 0, -10])
    # Pitch 90 tips the frame's y onto +z: a side stud, pointing (minus y) to -z.
    f = be.frame([0, 10, -10, 90.0, 0.0], "stud")
    assert _close([f[0][1], f[1][1], f[2][1]], [0, 0, 1])
    # A yaw counts for a fixed connector only, as bricknet.data reads column 5.
    assert _close(be.frame([0, 0, 0, 0, 0, 90], "fixed")[0][:3], [0, 0, 1])
    assert _close(be.frame([0, 0, 0, 0, 0, 90], "axle")[0][:3], [1, 0, 0])


def test_connectors_come_in_bricknets_order_with_an_axles_length():
    kinds = {"stud": {"stud": [[0, 0, 0, 0.0, 0.0]]},
             "axle": {"clip": [[0, -2, 0, 180.0, 0.0, 2]], "bar": [[0, 4, 0, 0.0, 0.0, 6]]},
             "hinge": {"12": {"on": [[0, 10, 0, 0.0, 90.0, 0]], "in": [[0, 9, 0, 0.0, 0.0, 0]]}}}
    found = be.connectors_of(kinds)
    assert [(k, s, p) for k, s, p, _, _ in found] == [
        ("axle", "bar", None), ("axle", "clip", None), ("hinge", "12", "in"),
        ("hinge", "12", "on"), ("stud", "stud", None)]
    assert [length for _, _, _, length, _ in found] == [6.0, 2.0, 0.0, 0.0, 0.0]
    assert be.sub_code("socket") == 10 and be.sub_code("12") == 112


@needs_scipy
def test_a_box_has_its_three_axes_and_no_diagonal():
    verts, normals, edges = be.hull(BOX + [(0, 4, 0)])   # a point inside is no vertex
    assert len(verts) == 8
    assert len(normals) == 6
    # Three edge directions: a triangulated face's diagonal is not one.
    assert len(edges) == 3
    assert sorted(tuple(abs(round(c)) for c in e) for e in edges) == [(0, 0, 1), (0, 1, 0), (1, 0, 0)]


@needs_scipy
def test_a_flat_piece_keeps_a_polygons_axes():
    square = [(0, 0, 0), (10, 0, 0), (10, 0, 10), (0, 0, 10)]
    verts, normals, edges = be.hull(square)
    assert len(verts) == 4
    # Its plane's normal and each side's, and its sides with the normal as an edge.
    assert any(abs(n[1]) > 0.999 for n in normals)
    assert len(normals) == 3 and len(edges) == 3
    _, _, segment = be.hull([(0, 0, 0), (0, 5, 0)])
    assert len(segment) == 1 and abs(segment[0][1]) > 0.999


@needs_scipy
def test_a_shape_reads_back_in_the_apps_frame():
    side_stud = ("stud", "open", None, 0.0, be.frame([0, 10, -10, 90.0, 0.0], "stud"))
    data = be.encode([side_stud], [BOX])
    shape = be.decode(data)
    assert len(shape["pieces"]) == 1 and len(shape["connectors"]) == 1
    verts = shape["pieces"][0][0]
    # LDraw's y 0..8 is the app's 0..-8; z flips too, x stays.
    assert min(v[1] for v in verts) == pytest.approx(-8) and max(v[1] for v in verts) == pytest.approx(0)
    assert shape["lo"] == pytest.approx((-10, -8, -20)) and shape["hi"] == pytest.approx((10, 0, 20))
    c = shape["connectors"][0]
    assert c["kind"] == be.KINDS["stud"] and c["sub"] == be.NAMED_SUBS["open"] and c["polarity"] == 255
    assert c["origin"] == pytest.approx((0, -10, 10))
    # It points along minus its y: LDraw's -z, which is the app's +z.
    assert tuple(-v for v in c["y"]) == pytest.approx((0, 0, 1))


@needs_scipy
def test_an_alias_takes_its_parts_shape_moved_by_its_matrix():
    with tempfile.TemporaryDirectory() as folder:
        data, cvx, out = Path(folder) / "v1", Path(folder) / "cvx", Path(folder) / "exact"
        for d in (data, cvx, out):
            d.mkdir()
        (data / "part_names.json").write_text(json.dumps({"1000": "Test Brick"}))
        (data / "labels.json.xz").write_bytes(lzma.compress(json.dumps(
            {"1000.dat": {"stud": {"stud": [[0, 0, 0, 0.0, 0.0]]}}}).encode()))
        # 1000a is 1000 turned a half turn about y and moved 20 along x.
        rows = [{"src": "1000a", "dst": "1000",
                 "final_matrix_3x4": [20, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1]}]
        (data / "part_aliases.json.xz").write_bytes(lzma.compress(json.dumps({"rows": rows}).encode()))
        # The box's six faces: a piece is the vertices its faces use.
        (cvx / "1000.cvx.obj").write_text("# aabb\no p\n" + "".join(
            f"v {x} {y} {z}\n" for x, y, z in BOX)
            + "f 1 2 4 3\nf 5 7 8 6\nf 1 5 6 2\nf 3 4 8 7\nf 1 3 7 5\nf 2 6 8 4\n")
        be._init(str(data), str(cvx))
        assert be.convert(("1000", "plain", str(out)))[1] == "written"
        assert be.convert(("1000a", "moved", str(out)))[1] == "written"
        assert be.convert(("9999", "absent", str(out)))[1] == "not in BrickNet"
        plain = be.decode((out / "plain.bwx").read_bytes())
        moved = be.decode((out / "moved.bwx").read_bytes())
        assert plain["connectors"][0]["origin"] == pytest.approx((0, 0, 0))
        assert moved["connectors"][0]["origin"] == pytest.approx((20, 0, 0))
        assert moved["lo"] == pytest.approx((10, -8, -20)) and moved["hi"] == pytest.approx((30, 0, 20))
        # The half turn about y turns the frame's x round, in either frame.
        assert moved["connectors"][0]["x"] == pytest.approx((-1, 0, 0))


def test_a_piece_is_the_vertices_its_faces_use_shared_or_not():
    # As BrickNet writes its colliders: a second piece's faces use two vertices
    # written under the first, which its own v lines do not repeat. Read by its
    # own lines it was a flat triangle (3033's piece 783, model-047 of
    # 2026-10-15); read as BrickBench reads it, the four corners of a tetrahedron.
    text = ("# shared\no first\nv 0 0 0\nv 10 0 0\nv 0 10 0\nf 1 2 3\n"
            "o second\nv 0 0 10\nf 1 2 4\nf -1 3 2\n"
            "o lines only\nv 50 0 0\nv 60 0 0\n")
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "shared.cvx.obj"
        path.write_text(text)
        pieces = be.read_obj(path)
    assert len(pieces) == 3
    assert sorted(pieces[0]) == [(0, 0, 0), (0, 10, 0), (10, 0, 0)]
    assert sorted(pieces[1]) == [(0, 0, 0), (0, 0, 10), (0, 10, 0), (10, 0, 0)]
    # A group with no faces is its own lines, as it was.
    assert sorted(pieces[2]) == [(50, 0, 0), (60, 0, 0)]


def test_a_file_that_is_not_one_is_refused():
    try:
        be.decode(b"LBM3" + bytes(60))
        refused = False
    except ValueError:
        refused = True
    assert refused
    assert math.isclose(be.MAGIC, int.from_bytes(b"BWX1", "little"))
