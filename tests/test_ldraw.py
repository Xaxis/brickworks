"""Tests that pin down the LDraw facts everything else is built on.

These assert measurements taken from the real library rather than numbers
copied out of a wiki, because the whole promise of this project is that a
brick here is the size of a brick in your hand.  If LDraw ever changes a
part under us, these fail loudly instead of the model quietly drifting.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.colors import Finish, Palette  # noqa: E402
from ldraw.geometry import compute_normals, flatten  # noqa: E402
from ldraw.library import Library  # noqa: E402
from ldraw.parser import Matrix, Vec3, parse_line  # noqa: E402
from ldraw.parser import EdgeLine, Polygon, SubfileRef  # noqa: E402

LDRAW_ROOT = ROOT / "vendor" / "ldraw"

pytestmark = pytest.mark.skipif(
    not (LDRAW_ROOT / "parts").is_dir(),
    reason="LDraw library not present; run tools/fetch_data.sh",
)


@pytest.fixture(scope="session")
def library() -> Library:
    return Library(LDRAW_ROOT)


@pytest.fixture(scope="session")
def palette() -> Palette:
    return Palette.from_file(LDRAW_ROOT / "LDConfig.ldr")


# -- the unit system -----------------------------------------------------

# 1 LDU is 0.4 mm.  Everything below is stated in LDU and converted here,
# so a failure says which physical dimension moved.
LDU_MM = 0.4


def test_stud_pitch_is_8mm(library: Library) -> None:
    """Adjacent studs sit 20 LDU apart, which is 8.0 mm on real bricks."""
    mesh = flatten(library, "3001.dat")
    lo, hi = mesh.bounds()
    # A 2x4 brick spans 4 studs on its long axis and 2 on its short one.
    assert (hi.x - lo.x) == pytest.approx(80.0)  # 4 * 20 LDU
    assert (hi.z - lo.z) == pytest.approx(40.0)  # 2 * 20 LDU
    assert (80.0 / 4) * LDU_MM == pytest.approx(8.0)


def test_brick_height_is_9_6mm(library: Library) -> None:
    """A brick body is 24 LDU; the studs add 4 LDU on top."""
    mesh = flatten(library, "3001.dat")
    lo, hi = mesh.bounds()
    assert (hi.y - lo.y) == pytest.approx(28.0)  # 24 body + 4 stud
    assert 24.0 * LDU_MM == pytest.approx(9.6)


def test_plate_is_one_third_of_a_brick(library: Library) -> None:
    """Three plates stack to exactly one brick: 3 * 8 LDU == 24 LDU."""
    mesh = flatten(library, "3024.dat")
    lo, hi = mesh.bounds()
    assert (hi.y - lo.y) == pytest.approx(12.0)  # 8 body + 4 stud
    assert 3 * 8.0 == 24.0


def test_stud_diameter_is_4_8mm(library: Library) -> None:
    """The stud primitive is a radius-6 LDU cylinder."""
    mesh = flatten(library, "stud.dat")
    lo, hi = mesh.bounds()
    assert (hi.x - lo.x) == pytest.approx(12.0, abs=0.01)
    assert 12.0 * LDU_MM == pytest.approx(4.8)


def test_minus_y_is_up(library: Library) -> None:
    """LDraw puts -Y up, so a brick's studs are at its *lowest* Y.

    This is the single most common source of upside-down imports, so it
    gets an explicit test rather than a comment.
    """
    mesh = flatten(library, "3001.dat")
    lo, hi = mesh.bounds()
    # The body occupies y 0..24 and the studs stick out to y = -4.
    assert lo.y == pytest.approx(-4.0)
    assert hi.y == pytest.approx(24.0)


# -- parsing -------------------------------------------------------------


def test_subfile_matrix_layout() -> None:
    """The 12 numbers are x y z then a row-major 3x3."""
    ref = parse_line("1 16 10 20 30 1 2 3 4 5 6 7 8 9 foo.dat")
    assert isinstance(ref, SubfileRef)
    assert (ref.matrix.x, ref.matrix.y, ref.matrix.z) == (10, 20, 30)
    assert (ref.matrix.a, ref.matrix.b, ref.matrix.c) == (1, 2, 3)
    assert (ref.matrix.d, ref.matrix.e, ref.matrix.f) == (4, 5, 6)
    assert (ref.matrix.g, ref.matrix.h, ref.matrix.i) == (7, 8, 9)


def test_backslash_paths_are_normalised() -> None:
    ref = parse_line("1 16 0 0 0 1 0 0 0 1 0 0 0 1 S\\3001S01.DAT")
    assert isinstance(ref, SubfileRef)
    assert ref.filename == "s/3001s01.dat"


def test_filenames_may_contain_spaces() -> None:
    ref = parse_line("1 16 0 0 0 1 0 0 0 1 0 0 0 1 some part.dat")
    assert isinstance(ref, SubfileRef)
    assert ref.filename == "some part.dat"


def test_quad_and_triangle_arity() -> None:
    tri = parse_line("3 16 0 0 0 1 0 0 0 1 0")
    quad = parse_line("4 16 0 0 0 1 0 0 1 1 0 0 1 0")
    assert isinstance(tri, Polygon) and len(tri.points) == 3
    assert isinstance(quad, Polygon) and len(quad.points) == 4


def test_edge_line_parses() -> None:
    edge = parse_line("2 24 0 0 0 10 0 0")
    assert isinstance(edge, EdgeLine)
    assert edge.points[1] == Vec3(10.0, 0.0, 0.0)


def test_mirror_transform_has_negative_determinant() -> None:
    assert Matrix(-1, 0, 0, 0, 1, 0, 0, 0, 1).determinant() < 0
    assert Matrix.identity().determinant() > 0


def test_matrix_composition_applies_right_first() -> None:
    translate = Matrix(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0)
    scale = Matrix(2, 0, 0, 0, 2, 0, 0, 0, 2)
    # scale @ translate: translate by 5 then scale -> 10
    assert (scale @ translate).transform_point(Vec3(0, 0, 0)).x == pytest.approx(10.0)
    # translate @ scale: scale then translate by 5 -> 5
    assert (translate @ scale).transform_point(Vec3(0, 0, 0)).x == pytest.approx(5.0)


# -- winding and shading -------------------------------------------------


def test_flat_faces_keep_a_hard_crease(library: Library) -> None:
    """No smoothing may bleed across the square corner of a brick.

    Every triangle whose face normal is axis-aligned belongs to a flat
    wall, so each of its corner normals must equal that face normal
    exactly.  A single deviation means the smoothing groups merged across
    an edge the author explicitly drew.
    """
    mesh = flatten(library, "3001.dat")
    normals = compute_normals(mesh)

    checked = 0
    for ti, tri in enumerate(mesh.triangles):
        face = tri.normal()
        axes = sorted(round(abs(v), 4) for v in (face.x, face.y, face.z))
        if axes != [0.0, 0.0, 1.0]:
            continue
        checked += 1
        for ci in range(3):
            assert normals[ti * 3 + ci].dot(face) == pytest.approx(1.0, abs=1e-4)

    assert checked > 100, "expected many flat faces on a 2x4 brick"


def test_curved_surfaces_are_smoothed(library: Library) -> None:
    """A round part must have corner normals that differ from face ones."""
    mesh = flatten(library, "4-4cyli.dat")
    normals = compute_normals(mesh)
    smoothed = sum(
        1
        for ti, tri in enumerate(mesh.triangles)
        for ci in range(3)
        if normals[ti * 3 + ci].dot(tri.normal()) < 0.9999
    )
    assert smoothed > 0, "a cylinder should be smooth-shaded"


def test_all_normals_are_unit_length(library: Library) -> None:
    for name in ("3001.dat", "6141.dat", "3626bp01.dat", "32523.dat"):
        mesh = flatten(library, name)
        for normal in compute_normals(mesh):
            assert normal.length() == pytest.approx(1.0, abs=1e-6)


def test_no_degenerate_triangles(library: Library) -> None:
    for name in ("3001.dat", "3024.dat", "3941.dat"):
        mesh = flatten(library, name)
        for tri in mesh.triangles:
            assert tri.area() > 0.0


def test_common_parts_resolve_completely(library: Library) -> None:
    """Every subfile of a common part must be found.

    A missing subfile is a silently incomplete brick, which is far worse
    than a loud failure.
    """
    for name in ("3001.dat", "3003.dat", "3020.dat", "3068b.dat", "32523.dat"):
        mesh = flatten(library, name)
        assert mesh.missing == set(), f"{name} references missing files"


# -- colours -------------------------------------------------------------


def test_palette_has_the_official_colours(palette: Palette) -> None:
    assert len(palette) > 300
    assert palette.get(0).name == "Black"
    assert palette.get(4).name == "Red"
    assert palette.get(15).name == "White"


def test_finishes_are_classified(palette: Palette) -> None:
    assert palette.get(47).finish is Finish.TRANSPARENT   # Trans_Clear
    assert palette.get(383).finish is Finish.CHROME       # Chrome_Silver
    assert palette.get(297).finish is Finish.PEARLESCENT  # Pearl_Gold
    assert palette.get(21).finish is Finish.GLOW          # Glow_In_Dark
    assert palette.get(0).finish is Finish.SOLID


def test_glitter_carries_its_fleck_colour(palette: Palette) -> None:
    glitter = palette.get(114)
    assert glitter.material is not None
    assert glitter.material.kind == "GLITTER"
    assert glitter.material.fraction > 0
    assert glitter.is_transparent


def test_unknown_code_is_loud_not_silent(palette: Palette) -> None:
    unknown = palette.get(99999)
    assert unknown.value == (255, 0, 255)


def test_srgb_is_converted_to_linear(palette: Palette) -> None:
    """Mid grey must darken when linearised; skipping this washes out renders."""
    grey = palette.get(7)
    linear = grey.as_linear()
    for channel, raw in zip(linear, grey.value):
        assert channel < raw / 255.0


# -- connectivity --------------------------------------------------------

from ldraw.connectivity import (  # noqa: E402
    ConnectorKind,
    Gender,
    extract,
    studs,
    tubes,
)


@pytest.mark.parametrize(
    "part,expected_studs",
    [
        ("3005.dat", 1),      # Brick 1 x 1
        ("3004.dat", 2),      # Brick 1 x 2
        ("3003.dat", 4),      # Brick 2 x 2
        ("3001.dat", 8),      # Brick 2 x 4
        ("3024.dat", 1),      # Plate 1 x 1
        ("3020.dat", 8),      # Plate 2 x 4
        ("3832.dat", 20),     # Plate 2 x 10
        ("3068b.dat", 0),     # Tile 2 x 2 — tiles have no studs
        ("3867.dat", 256),    # Baseplate 16 x 16
        ("3811.dat", 1024),   # Baseplate 32 x 32
    ],
)
def test_stud_counts_match_the_real_part(
    library: Library, part: str, expected_studs: int
) -> None:
    """Stud counts are checkable against the brick in your hand."""
    assert len(studs(extract(library, part))) == expected_studs


def test_studs_sit_on_the_20_ldu_lattice(library: Library) -> None:
    """Every stud of a baseplate lands exactly on the stud pitch."""
    found = studs(extract(library, "3867.dat"))
    xs = sorted({round(c.position.x, 3) for c in found})
    zs = sorted({round(c.position.z, 3) for c in found})
    assert len(xs) == 16 and len(zs) == 16
    for axis in (xs, zs):
        spacing = {round(b - a, 3) for a, b in zip(axis, axis[1:])}
        assert spacing == {20.0}


def test_studs_point_up(library: Library) -> None:
    """A top stud's outward axis is -Y, which is up in LDraw."""
    for connection in studs(extract(library, "3001.dat")):
        assert connection.axis.y == pytest.approx(-1.0)
        assert connection.gender is Gender.MALE


def test_tubes_point_down_and_sit_between_studs(library: Library) -> None:
    """The underside tubes of a 2x4 brick grip studs from outside.

    Three tubes, on the half-lattice between the stud columns, opening
    downward — the geometry that makes a stud grip rather than rattle.
    """
    found = tubes(extract(library, "3001.dat"))
    assert len(found) == 3
    assert sorted(round(c.position.x) for c in found) == [-20, 0, 20]
    for connection in found:
        assert connection.axis.y == pytest.approx(1.0)  # +Y is down
        assert connection.gender is Gender.FEMALE


def test_sideways_parts_get_rotated_axes(library: Library) -> None:
    """A headlight brick has studs on more than one face.

    This is the test that catches forgetting to rotate the connector
    axis: with a hard-coded 'up' every SNOT part silently claims its side
    studs point at the sky.
    """
    found = studs(extract(library, "4070.dat"))  # Brick 1x1 with Headlight
    axes = {
        (round(c.axis.x), round(c.axis.y), round(c.axis.z)) for c in found
    }
    assert len(axes) > 1, "expected studs facing more than one direction"


def test_technic_beam_has_pin_holes(library: Library) -> None:
    found = extract(library, "32523.dat")  # Technic Beam 3
    holes = [c for c in found if c.kind is ConnectorKind.PIN_HOLE]
    assert len(holes) == 3
    for hole in holes:
        assert hole.gender is Gender.NEUTRAL


def test_stickers_have_no_connectors(library: Library) -> None:
    assert extract(library, "003238a.dat") == []
