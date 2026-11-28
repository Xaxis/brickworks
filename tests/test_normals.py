"""A part's corner normals: by angle, so the same however LDraw cut a surface.

geometry.compute_normals averaged a corner's faces by their area, and
LDraw draws a cylinder's wall as quads all cut corner to corner the same
way, so every normal round a 16-sided ring leaned 3.75 degrees along it.
These build the surfaces themselves, so they need no LDraw library.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.geometry import Mesh, Triangle, _key, compute_normals  # noqa: E402
from ldraw.parser import Vec3  # noqa: E402

SIDES = 16


def _degrees(u: Vec3, v: Vec3) -> float:
    return math.degrees(math.acos(max(-1.0, min(1.0, u.dot(v) / (u.length() * v.length())))))


def _ring(cut: str, radius: float = 10.0, height: float = 8.0) -> Mesh:
    """A 16-sided wall facing out, its quads cut corner to corner.

    cut: "one" every quad the same way (LDraw's cylinders), "other" every
    quad the other way, "both" alternately.
    """
    mesh = Mesh()
    top = [Vec3(radius * math.cos(2 * math.pi * i / SIDES), 0.0,
                radius * math.sin(2 * math.pi * i / SIDES)) for i in range(SIDES)]
    bottom = [Vec3(p.x, height, p.z) for p in top]
    for i in range(SIDES):
        a, b = top[i], top[(i + 1) % SIDES]
        c, d = bottom[(i + 1) % SIDES], bottom[i]
        # Wound so (b - a) x (c - a) faces out of the ring.
        if cut == "one" or (cut == "both" and i % 2 == 0):
            mesh.triangles += [Triangle(a, c, b, 16), Triangle(a, d, c, 16)]
        else:
            mesh.triangles += [Triangle(a, d, b, 16), Triangle(b, d, c, 16)]
    return mesh


def _lean(mesh: Mesh) -> float:
    """The most any corner's normal turns from straight out of the ring."""
    worst = 0.0
    for ti, normal in enumerate(compute_normals(mesh)):
        t = mesh.triangles[ti // 3]
        p = (t.a, t.b, t.c)[ti % 3]
        worst = max(worst, _degrees(normal, Vec3(p.x, 0.0, p.z)))
    return worst


@pytest.mark.parametrize("cut", ["one", "other", "both"])
def test_a_ring_s_normals_point_straight_out(cut: str) -> None:
    """Every corner of a 16-sided ring faces straight out of the circle.

    By area, the corner owning a whole quad on one side and half of one on
    the other leaned 3.75 degrees towards the whole one.
    """
    mesh = _ring(cut)
    # Faces out, not in: the ring is smooth, not inside out.
    assert all(t.normal().dot(Vec3(t.a.x, 0.0, t.a.z)) > 0 for t in mesh.triangles)
    assert _lean(mesh) < 0.1


def test_a_quad_cut_either_way_gives_the_same_normals() -> None:
    """The corner normals do not depend on which diagonal cut each quad."""
    def at(mesh: Mesh) -> dict:
        normals = compute_normals(mesh)
        out: dict = {}
        for ti, normal in enumerate(normals):
            t = mesh.triangles[ti // 3]
            out.setdefault(_key((t.a, t.b, t.c)[ti % 3]), []).append(normal)
        return out

    one, other, both = (at(_ring(cut)) for cut in ("one", "other", "both"))
    assert one.keys() == other.keys() == both.keys()
    for key, normals in one.items():
        for normal in normals + other[key] + both[key]:
            assert _degrees(normal, normals[0]) < 0.01


def _fan() -> tuple[Mesh, Vec3]:
    """A flat square around the origin facing +y, cut into four triangles."""
    mesh = Mesh()
    centre = Vec3(0.0, 0.0, 0.0)
    rim = [Vec3(10.0, 0.0, -10.0), Vec3(-10.0, 0.0, -10.0),
           Vec3(-10.0, 0.0, 10.0), Vec3(10.0, 0.0, 10.0)]
    for i in range(4):
        mesh.triangles.append(Triangle(centre, rim[i], rim[(i + 1) % 4], 16))
    assert all(t.normal().y == pytest.approx(1.0) for t in mesh.triangles)
    return mesh, centre


def test_a_sliver_cannot_turn_a_normal() -> None:
    """A triangle a few ten-thousandths of an LDU wide, tilted 30 degrees,
    joined to a flat face along one edge, leaves that face's normal.

    LDraw writes its primitives to four places, so three points meant to be
    in a line come out that far apart, and the sliver's direction is the
    rounding's. By angle alone it would count nearly 180 degrees at the
    corner in its middle, as much as the flat face's whole half there.
    """
    mesh, centre = _fan()
    along = Vec3(1.0, 0.0, 1.0) * (1.0 / math.sqrt(2.0))
    tilted = Vec3(0.0, 1.0, 0.0) * math.cos(math.radians(30)) \
        + Vec3(1.0, 0.0, -1.0) * (math.sin(math.radians(30)) / math.sqrt(2.0))
    across = tilted.cross(along)
    end = Vec3(10.0, 0.0, 10.0)
    far = along * -14.0 + across * 0.0006
    sliver = Triangle(centre, far, end, 16)
    if sliver.normal().dot(tilted) < 0:
        sliver = Triangle(centre, end, far, 16)
    assert _degrees(sliver.normal(), tilted) < 0.5
    angle_there = math.degrees(math.atan2(
        (far - centre).cross(end - centre).length(), (far - centre).dot(end - centre)))
    assert angle_there > 179.0
    mesh.triangles.append(sliver)

    normals = compute_normals(mesh)
    for ti in range(4):
        t = mesh.triangles[ti]
        assert t.a is centre
        assert _degrees(normals[ti * 3], Vec3(0.0, 1.0, 0.0)) < 0.1


def _box_corner(drawn: bool, bend: float = 90.0) -> tuple[Mesh, list[Vec3]]:
    """Three faces meeting at the origin like a brick's corner: the top and
    two sides, the sides bent [param bend] degrees from the top, each face a
    square cut in two. drawn: the author's edge lines along the three edges.
    """
    mesh = Mesh()
    o = Vec3(0.0, 0.0, 0.0)
    x, z = Vec3(10.0, 0.0, 0.0), Vec3(0.0, 0.0, 10.0)
    s, c = math.sin(math.radians(bend)), math.cos(math.radians(bend))
    down_x = Vec3(0.0, -10.0 * s, -10.0 * c)   # the side along x, bent down
    down_z = Vec3(-10.0 * c, -10.0 * s, 0.0)   # the side along z
    faces = [
        (o, z, x + z, x),                       # top, facing +y
        (o, x, x + down_x, down_x),             # front, facing about -z
        (o, down_z, z + down_z, z),             # left, facing about -x
    ]
    expected = []
    for a, b, cc, d in faces:
        tri = [Triangle(a, b, cc, 16), Triangle(a, cc, d, 16)]
        mesh.triangles += tri
        expected += [tri[0].normal(), tri[1].normal()]
    if drawn:
        for end in (x, z, Vec3(0.0, -10.0, 0.0)):
            pair = (_key(o), _key(end))
            mesh.edges.add(pair if pair[0] < pair[1] else (pair[1], pair[0]))
    return mesh, expected


@pytest.mark.parametrize("drawn", [True, False])
def test_a_brick_corner_stays_sharp(drawn: bool) -> None:
    """Each face of a square corner keeps its own flat normal at every
    corner, with the author's edge lines or without (past 45 degrees)."""
    mesh, expected = _box_corner(drawn)
    assert expected[0].y == pytest.approx(1.0)
    for ti, normal in enumerate(compute_normals(mesh)):
        assert _degrees(normal, expected[ti // 3]) < 1e-6


def test_the_crease_rule_is_kept() -> None:
    """A gentle bend with no edge line is smoothed across; the same bend
    with one drawn stays sharp."""
    smooth_mesh, flat = _box_corner(drawn=False, bend=30.0)
    smooth = compute_normals(smooth_mesh)
    # The corner at the origin is one group: every face's normal there agrees.
    at_origin = [smooth[ti * 3] for ti in range(len(smooth_mesh.triangles))]
    assert all(_degrees(n, at_origin[0]) < 1e-6 for n in at_origin)
    assert _degrees(at_origin[0], flat[0]) > 1.0

    sharp_mesh, flat = _box_corner(drawn=True, bend=30.0)
    for ti, normal in enumerate(compute_normals(sharp_mesh)):
        assert _degrees(normal, flat[ti // 3]) < 1e-6
