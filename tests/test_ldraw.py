"""Tests that pin down the LDraw facts everything else is built on.

These assert measurements taken from the real library rather than numbers
copied out of a wiki, because the whole promise of this project is that a
brick here is the size of a brick in your hand.  If LDraw ever changes a
part under us, these fail loudly instead of the model quietly drifting.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import TYPE_CHECKING

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


def _volume_and_moment(part: object) -> tuple[float, float]:
    """Signed volume, and its first moment along x, from the winding alone.

    Each triangle and the origin make a tetrahedron; summed, they give the
    enclosed volume, positive when every face is wound to face out. A part
    drawn inside out comes out negative, and one with some faces flipped
    comes out short, which is what a check of normals against winding
    cannot see: there the normals and the winding agree, and both point
    in.
    """
    volume = moment = 0.0
    for surface in part.surfaces:  # type: ignore[attr-defined]
        p = surface.positions
        for i in range(0, len(surface.indices), 3):
            a, b, c = (p[k * 3:k * 3 + 3] for k in surface.indices[i:i + 3])
            # Stored in the engine's winding, the reverse of LDraw's.
            v = -(a[0] * (b[1] * c[2] - b[2] * c[1])
                  - a[1] * (b[0] * c[2] - b[2] * c[0])
                  + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
            volume += v
            moment += v * (a[0] + b[0] + c[0]) / 4.0
    return volume, moment


@pytest.mark.parametrize("right,left", [
    ("41769a", "41770a"),   # Wing 2 x 4: the right's body is the left's, x -1
    ("41769b", "41770b"),   # ...with its chamfer
    ("43722a", "43723a"),   # Wing 2 x 3
    ("3935", "3936"),       # Wing 4 x 4
])
def test_a_mirrored_twin_is_drawn_as_its_twins_reflection(
    library: Library, right: str, left: str
) -> None:
    """A handed part built from its twin's body reflected comes out as the
    reflection: the same solid, facing out, its x moment the twin's negated.

    41769a was reported drawing a near-white cut face, and it is made by
    referencing 41770a's subpart through a matrix of determinant -1. The
    mesh was right; the pale face was the sun's glint, and it followed
    where a part stood rather than which hand it was. Nothing else holds
    the determinant term of geometry.flatten's XOR: without it, 41769a's
    body is inside out, its volume negative, and only this fails.

    Through meshfile, written and read back, because the bytes are what is
    drawn: the axis change, the reversal on the way out, the quantising.
    """
    from ldraw import meshfile

    def built(name: str) -> object:
        part = meshfile.build(flatten(library, f"{name}.dat"))
        return meshfile.read(meshfile.write(part))

    r_volume, r_moment = _volume_and_moment(built(right))
    l_volume, l_moment = _volume_and_moment(built(left))
    assert l_volume > 0, f"{left} is drawn inside out"
    assert r_volume == pytest.approx(l_volume, rel=1e-3), \
        f"{right} encloses {r_volume:.0f} LDU^3 where {left} encloses {l_volume:.0f}"
    assert r_moment == pytest.approx(-l_moment, rel=1e-3, abs=1.0)

    # And every stored normal on the side its triangle faces.
    part = built(right)
    for surface in part.surfaces:  # type: ignore[attr-defined]
        p, n = surface.positions, surface.normals
        for i in range(0, len(surface.indices), 3):
            ids = surface.indices[i:i + 3]
            a, b, c = (Vec3(*p[k * 3:k * 3 + 3]) for k in ids)
            face = (c - a).cross(b - a)
            if face.length() < 1e-6:
                continue
            for k in ids:
                assert Vec3(*n[k * 3:k * 3 + 3]).dot(face) > 0, \
                    f"{right}: a normal faces away from its triangle at {a}"


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


def test_lego_numbers_and_groups_are_read(palette: Palette) -> None:
    """LDConfig says LEGO's own number and name only in a comment above
    each colour, and which colours are not plastic only by section."""
    grey = palette.get(71)
    assert grey.lego_ids == (194,)
    assert grey.lego_name == "Medium Stone Grey"
    assert palette.get(15).lego_ids == (1, 426)       # "1 / 426 - White"
    assert palette.get(85).lego_name == "Medium Lilac"
    assert palette.get(4).group == "solid"
    assert palette.get(4).is_plastic
    # 16 and 24 are declared, under "Internal Common Material".
    for code in (16, 24, 10047):
        assert palette.get(code).group == "internal common material"
        assert not palette.get(code).is_plastic
    # And a comment belongs only to the colour straight after it.
    assert palette.get(11015).lego_ids == ()          # Trans_White has none


def test_rubber_and_canvas_say_their_plain_colour(palette: Palette) -> None:
    """Rebrickable files a black tyre under Black, so the rubber variant
    has to be answerable as the colour it is."""
    plain = {e["code"]: e.get("plain_code") for e in palette.entries()}
    assert plain[256] == 0          # Rubber_Black
    assert plain[10002] == 2        # Rubber_Green
    assert plain[67] == 47          # Rubber_Trans_Clear
    assert plain[20004] == 4        # Canvas_Red
    assert plain[4] is None         # an ordinary colour carries none
    assert plain[20500] is None     # Canvas_Cream has no plain twin


REBRICKABLE = ROOT / "vendor" / "rebrickable" / "colors.csv.gz"


@pytest.mark.skipif(not REBRICKABLE.exists(),
                    reason="Rebrickable tables not present; run tools/fetch_data.sh")
def test_rebrickable_colours_join_on_evidence(palette: Palette) -> None:
    """Each pair here was wrong or missing before, and each is decided by
    something on disk: the id, LEGO's name, LDraw's name or exact RGB."""
    import rebrickable

    codes = rebrickable.colour_codes(palette.entries())
    # Renamed in LDraw since Rebrickable took the number: the id stands.
    assert codes[85] == 85          # Dark Purple is Medium_Lilac, 17k parts
    assert codes[89] == 89          # Royal Blue, not 2026's Blue Violet
    assert codes[69] == 69
    assert codes[137] == 137
    # Moved to a new code in LDraw: the name wins over a stale id.
    assert codes[41] == 43          # Trans-Light Blue
    assert codes[179] == 315        # Flat Silver
    # LEGO's own name, from LDConfig's comments.
    assert codes[1147] == 431       # Blue Violet, 2026
    assert codes[1062] == 368       # Vibrant Yellow
    assert codes[125] == 125        # Light Orange: id and LEGO name, not 121
    assert codes[1056] == 363       # Opal Trans-Brown
    # One RGB shared by three LDraw colours, narrowed by finish and name.
    assert codes[1103] == 316       # Pearl Titanium, not a metallic paint
    # Two Rebrickable entries for one LEGO colour share its code.
    assert codes[1051] == 313       # Pastel Blue, the 2005-11 Maersk blue
    # Never a code that is not plastic, and never HO.
    internal = {c.code for c in palette if not c.is_plastic}
    assert not internal & set(codes.values())
    assert 1143 not in codes        # Glitter Milky White was "Trans_Sticker"
    assert not [rb for rb in codes if 1104 <= rb <= 1134]


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


def _holes(library: Library, part: str, kind: ConnectorKind) -> list[tuple]:
    return sorted((round(c.position.x), round(c.position.y), round(c.position.z))
                  for c in extract(library, part) if c.kind is kind)


def test_the_24_tooth_gear_has_its_centre_axle_hole(library: Library) -> None:
    """3648a and 3648b draw their centre hole as eight mirrored eighths
    with no hole primitive, so they read as a gear with no centre and every
    one in a model floated off its axle (docs/MECHANISMS.md)."""
    for part in ("3648a.dat", "3648b.dat", "24505.dat"):
        assert _holes(library, part, ConnectorKind.AXLE_HOLE) == [(0, 0, 0)], part


def test_plain_cylinder_holes_are_pin_holes(library: Library) -> None:
    """A Technic plate's holes and 6542a's hub are plain cylinders."""
    assert _holes(library, "3709b.dat", ConnectorKind.PIN_HOLE) == [
        (-20, 4, 0), (0, 4, 0), (20, 4, 0)]
    assert len(_holes(library, "3738.dat", ConnectorKind.PIN_HOLE)) == 7
    assert _holes(library, "6542a.dat", ConnectorKind.PIN_HOLE) == [(0, 0, 1)]
    for part in ("6573.dat", "4141.dat", "73071.dat"):   # a differential's two hubs
        assert _holes(library, part, ConnectorKind.PIN_HOLE) == [(0, 0, -30), (0, 0, 30)], part
    # Only those: a 2 x 2 slope's underside has a whole bore that size, and
    # 4,970 parts like it, and a pin goes in none of them.
    assert _holes(library, "3039.dat", ConnectorKind.PIN_HOLE) == []


def test_an_axle_has_no_hole_where_it_meets_its_own_stop(library: Library) -> None:
    """32062's notch and an axle's stop draw axle-hole edges, which read
    as a hole in the middle of the axle."""
    for part in ("32062.dat", "15462.dat", "99008.dat", "2736.dat", "6587.dat"):
        assert _holes(library, part, ConnectorKind.AXLE_HOLE) == [], part
    # A real hole beside an axle stays: 6553's, across it.
    assert _holes(library, "6553.dat", ConnectorKind.AXLE_HOLE) == [(10, 0, 0)]
    # And so does every hole of a part with no axle of its own.
    assert len(_holes(library, "32523.dat", ConnectorKind.PIN_HOLE)) == 3
    assert _holes(library, "3647.dat", ConnectorKind.AXLE_HOLE) == [(0, 0, 0)]


# -- shafts and bores: what round things fit what ------------------------


def _rounds_of(library: Library, part: str, kind: ConnectorKind) -> list:
    return [c for c in extract(library, part) if c.kind is kind]


def _spans(found: list) -> list[tuple]:
    """Each round as radius, then its ends along its axis, rounded."""
    out = []
    for c in found:
        a = c.position
        b = c.position + c.axis * c.length
        out.append((round(c.radius, 2), round(a.x, 1), round(a.y, 1), round(a.z, 1),
                    round(b.x, 1), round(b.y, 1), round(b.z, 1)))
    return sorted(out)


def test_a_bar_is_a_shaft_four_across(library: Library) -> None:
    """Bar 4L: one shaft, radius 4 (3.2 mm), the bar's whole 80 LDU."""
    assert _spans(_rounds_of(library, "30374.dat", ConnectorKind.SHAFT)) == [
        (4.0, 0.0, 0.0, 0.0, 0.0, 80.0, 0.0)]
    assert _rounds_of(library, "30374.dat", ConnectorKind.BORE) == []


def test_a_mirrored_bar_is_still_a_shaft(library: Library) -> None:
    """The lance lays its bars along z with a mirroring matrix. Counting
    the mirror as a turn inside out made every one of them a bore."""
    shafts = _rounds_of(library, "3849.dat", ConnectorKind.SHAFT)
    assert {round(c.radius, 2) for c in shafts} == {4.0}
    assert max(c.length for c in shafts) == pytest.approx(132.0)
    assert _rounds_of(library, "3849.dat", ConnectorKind.BORE) == []


@pytest.mark.parametrize("part", ["4085c.dat", "63868.dat", "60470b.dat", "15712.dat"])
def test_a_clip_is_a_bore_four_across(library: Library, part: str) -> None:
    """Every clip's eye is a bore a bar fits, and a clip has no shaft."""
    bores = _rounds_of(library, part, ConnectorKind.BORE)
    assert bores and {round(c.radius, 2) for c in bores} == {4.0}
    assert all(c.gender is Gender.FEMALE for c in bores)
    assert _rounds_of(library, part, ConnectorKind.SHAFT) == []


def test_a_hollow_stud_brick_is_bored_right_through(library: Library) -> None:
    """3062b: radius 4 from the top of its open stud down to the tube, and
    the tube's 6 on to the bottom — where a lightsaber blade goes."""
    assert _spans(_rounds_of(library, "3062b.dat", ConnectorKind.BORE)) == [
        (4.0, 0.0, -4.0, 0.0, 0.0, 4.0, 0.0),
        (6.0, 0.0, 4.0, 0.0, 0.0, 24.0, 0.0)]


@pytest.mark.parametrize("part", ["3001.dat", "3003.dat", "3024.dat", "3068b.dat",
                                  "3005.dat", "3020.dat"])
def test_plain_parts_have_no_rounds(library: Library, part: str) -> None:
    """A tube's inside is where studs go, not a hole through anything, so
    it is not a bore unless it carries one on; plain bricks have none.
    Two things that look like exceptions are not: the solid post under a
    one-wide brick (3622) is radius 4 and a clip grips it as it grips a
    bar, and a tube drawn by hand rather than from stud4 (3039) is a
    bore, because the inside of a tube is a hole a pin fits."""
    found = extract(library, part)
    assert not [c for c in found
                if c.kind in (ConnectorKind.SHAFT, ConnectorKind.BORE)]


def test_a_hinge_brick_is_a_pin_in_an_eye(library: Library) -> None:
    """3830's pin and 3831's eye are the same round, radius 6, on the same
    axis through both origins: the two halves turn about it."""
    pins = _spans(_rounds_of(library, "3830.dat", ConnectorKind.SHAFT))
    eyes = _spans(_rounds_of(library, "3831.dat", ConnectorKind.BORE))
    assert (6.0, 0.0, 8.0, 0.0, 0.0, 22.4, 0.0) in pins
    assert (6.0, 0.0, 8.0, 0.0, 0.0, 24.0, 0.0) in eyes


def test_a_turntable_top_sits_in_its_base(library: Library) -> None:
    """3679's disc and 3680's recess: radius 17.5, 4 LDU, both at the
    origin they share when the turntable is assembled at any angle."""
    disc = _spans(_rounds_of(library, "3679.dat", ConnectorKind.SHAFT))
    recess = _spans(_rounds_of(library, "3680.dat", ConnectorKind.BORE))
    assert (17.5, 0.0, 0.0, 0.0, 0.0, 4.0, 0.0) in disc
    assert (17.5, 0.0, 0.0, 0.0, 0.0, 4.0, 0.0) in recess


def test_a_round_survives_the_part_file() -> None:
    """A shaft keeps its radius and length through the .lbm, where the
    gender byte carries the radius and the axis the length."""
    from ldraw import meshfile

    part = meshfile.PartMesh()
    part.connectors = [
        meshfile.ConnectorOut("bore", "female", (0.0, 4.0, 0.0), (0.0, -1.0, 0.0),
                              length=20.0, radius=6.0),
        meshfile.ConnectorOut("shaft", "male", (30.0, -2.0, 4.0), (0.0, 0.0, -1.0),
                              length=8.0, radius=17.5),
        meshfile.ConnectorOut("stud", "male", (10.0, 0.0, 10.0), (0.0, 1.0, 0.0)),
    ]
    back = meshfile.read(meshfile.write(part)).connectors
    assert [(c.kind, c.gender) for c in back] == [
        ("bore", "female"), ("shaft", "male"), ("stud", "male")]
    assert back[0].radius == 6.0 and back[0].length == pytest.approx(20.0)
    assert back[0].axis == pytest.approx((0.0, -1.0, 0.0))
    assert back[1].radius == 17.5 and back[1].length == pytest.approx(8.0)
    assert back[2].axis == pytest.approx((0.0, 1.0, 0.0)) and back[2].radius == 0.0


# -- occupancy and sockets -----------------------------------------------

if TYPE_CHECKING:
    from ldraw import occupancy as occ  # noqa: E402
else:
    try:
        from ldraw import occupancy as occ
    except ImportError:  # the one module that needs numpy and scipy
        occ = None

# Six tests below voxelise a part. Without numpy they used to take the
# whole file down at import, so thirty-three measurements that need
# nothing but LDraw went unchecked too.
needs_numpy = pytest.mark.skipif(
    occ is None, reason="numpy/scipy not installed; apt install python3-numpy python3-scipy")


def _occupancy(library: Library, part: str):
    mesh = flatten(library, part)
    return occ.remove_studs(occ.voxelise(mesh), extract(library, part))


@pytest.mark.parametrize(
    "part,studs_x,plates,studs_z",
    [
        ("3005.dat", 1, 3, 1),    # Brick 1 x 1
        ("3004.dat", 2, 3, 1),    # Brick 1 x 2
        ("3622.dat", 3, 3, 1),    # Brick 1 x 3
        ("3009.dat", 6, 3, 1),    # Brick 1 x 6
        ("3003.dat", 2, 3, 2),    # Brick 2 x 2
        ("3001.dat", 4, 3, 2),    # Brick 2 x 4
        ("3024.dat", 1, 1, 1),    # Plate 1 x 1
        ("3020.dat", 4, 1, 2),    # Plate 2 x 4
        ("3031.dat", 4, 1, 4),    # Plate 4 x 4
        ("3832.dat", 10, 1, 2),   # Plate 2 x 10
        ("3068b.dat", 2, 1, 2),   # Tile 2 x 2
    ],
)
@needs_numpy
def test_occupancy_matches_the_named_size(
    library: Library, part: str, studs_x: int, plates: int, studs_z: int
) -> None:
    """A part called "Brick 2 x 4" must occupy 4 x 3 x 2 on the lattice.

    This is the test that catches the studs being counted as volume: a
    brick whose studs count comes out three and a half plates tall, and
    nothing can then be stacked on it.
    """
    grid = _occupancy(library, part)
    assert grid.shape[0] * occ.CELL == pytest.approx(studs_x * 20.0)
    assert grid.shape[1] * occ.CELL == pytest.approx(plates * 8.0)
    assert grid.shape[2] * occ.CELL == pytest.approx(studs_z * 20.0)


@needs_numpy
def test_lattice_divides_every_lego_dimension() -> None:
    """The cell has to divide the stud pitch, half pitch, brick and plate.

    Anything coarser breaks under a quarter turn, which is how half of
    modern building works. 4 LDU fails: a 1x1 brick spans -10 to 10 and
    straddles a cell at each end.
    """
    for dimension in (20.0, 10.0, 24.0, 8.0, 4.0):
        assert dimension % occ.CELL == pytest.approx(0.0)


@pytest.mark.parametrize(
    "part,expected",
    [
        ("3005.dat", 1), ("3004.dat", 2), ("3009.dat", 6),
        ("3003.dat", 4), ("3001.dat", 8), ("3020.dat", 8),
        ("3031.dat", 16), ("3832.dat", 20),
        ("3068b.dat", 4),   # a tile has no studs but plainly takes them
        ("3070b.dat", 1),   # and the 1x1 tile declares no connector at all
    ],
)
@needs_numpy
def test_socket_counts(library: Library, part: str, expected: int) -> None:
    assert len(occ.bottom_sockets(_occupancy(library, part))) == expected


@needs_numpy
def test_sockets_agree_with_studs(library: Library) -> None:
    """Two independent derivations must land on the same lattice.

    Stud positions come from the primitives a part is drawn with; socket
    positions come from voxelising its underside. They share no code, so
    agreeing to the micron is real evidence both are right.
    """
    for part in ("3001.dat", "3003.dat", "3020.dat", "3031.dat", "3832.dat"):
        grid = _occupancy(library, part)
        sockets = sorted(
            (round(x, 3), round(z, 3))
            for x, z in occ.bottom_sockets(grid)
        )
        tops = sorted(
            (round(c.position.x, 3), round(-c.position.z, 3))
            for c in studs(extract(library, part))
        )
        assert sockets == tops, part


@needs_numpy
def test_an_arch_has_no_socket_under_its_span(library: Library) -> None:
    """Arch 1 x 4 stands on two legs; nothing attaches under the opening."""
    sockets = occ.bottom_sockets(_occupancy(library, "3659.dat"))
    assert len(sockets) == 2


@needs_numpy
def test_collision_is_exact_on_the_lattice(library: Library) -> None:
    """Two bricks side by side do not collide; overlapping ones do."""
    brick = _occupancy(library, "3001.dat")
    step = int(round(20.0 / occ.CELL))

    # Four studs along: exactly touching, not overlapping.
    assert not occ.collides(brick, brick, (4 * step, 0, 0))
    # Three studs along: one stud of overlap.
    assert occ.collides(brick, brick, (3 * step, 0, 0))
    # Directly on top, one brick up (3 plates).
    assert not occ.collides(brick, brick, (0, 3 * int(round(8.0 / occ.CELL)), 0))
    # In the same place as itself.
    assert occ.collides(brick, brick, (0, 0, 0))


def _built_cover(part: str) -> tuple[set, list]:
    """A part's cover and connectors as the mesh build writes them: its
    cells, from the boxes in the .lbm, and its connectors read back."""
    import build_meshes
    from ldraw import meshfile

    if build_meshes._LIBRARY is None:
        build_meshes._init(str(LDRAW_ROOT))
    _id, blob, record = build_meshes._convert(part)
    assert blob is not None, record
    built = meshfile.read(blob)
    cells = set()
    for x0, y0, z0, w, h, d in built.boxes:
        cells.update((x, y, z) for x in range(x0, x0 + w)
                     for y in range(y0, y0 + h) for z in range(z0, z0 + d))
    return cells, built.connectors


def _in_shaft(cells: set, at: tuple, way: tuple, depth: float,
              radius: float) -> list:
    """The cover cells whose middles lie inside a shaft of ``radius``
    running ``depth`` from ``at`` along ``way``, in the app's axes."""
    found = []
    lo = [min(at[n], at[n] + way[n] * depth) - radius for n in range(3)]
    hi = [max(at[n], at[n] + way[n] * depth) + radius for n in range(3)]
    span = [range(int(lo[n] // occ.CELL) - 1, int(hi[n] // occ.CELL) + 2) for n in range(3)]
    for x in span[0]:
        for y in span[1]:
            for z in span[2]:
                middle = [(v + 0.5) * occ.CELL for v in (x, y, z)]
                gap = [middle[n] - at[n] for n in range(3)]
                along = sum(gap[n] * way[n] for n in range(3))
                if not 0.0 < along < depth:
                    continue
                off = sum((gap[n] - along * way[n]) ** 2 for n in range(3))
                if off < radius * radius and (x, y, z) in cells:
                    found.append((x, y, z))
    return found


# Round bricks with a Technic pin hole in the middle of each side, read off
# the part files: 16 LDU of bore, 12 across, its middle 10 under the top
# and 30 (6222) or 50 (18897) out from the centre, running in from the face.
# They are drawn from plain cylinders, with no peghole primitive anywhere.
ROUND_BRICK_HOLES = {"6222.dat": 30.0, "18897.dat": 50.0}


@needs_numpy
@pytest.mark.parametrize("part", sorted(ROUND_BRICK_HOLES))
def test_a_round_brick_cover_leaves_its_side_holes_open(part: str) -> None:
    """A Technic pin's shaft, 12 LDU across, pushed into each side hole of
    a round brick with holes lies in none of the brick's cover. Both were
    their bounding boxes, solid through all four holes, so every pin put
    in one was refused as an overlap with the brick it was pinned to."""
    cells, _connectors = _built_cover(part)
    middle = ROUND_BRICK_HOLES[part]
    for way in ((1.0, 0.0, 0.0), (-1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 0.0, -1.0)):
        mouth = tuple(-(middle + 8.0) * w for w in way)
        inward = way
        at = (mouth[0], -10.0, mouth[2])
        blocked = _in_shaft(cells, at, inward, 16.0, 6.0)
        assert blocked == [], (part, way, len(blocked))
        # And the cover is not hollowed: the wall a plate beside the hole
        # is still there.
        beside = (at[0] + 6.0 * inward[0] + 10.0 * abs(inward[2]),
                  -10.0,
                  at[2] + 6.0 * inward[2] + 10.0 * abs(inward[0]))
        assert tuple(int(v // occ.CELL) for v in beside) in cells, (part, way)


# A sample of the parts whose covers had a hole filled solid, from a scan of
# every built part (.claude/skills/verify/features/geometry.md): holes drawn
# by hand, and holes a Technic primitive declares in parts that were past
# the box limit — long beams and bricks, a baseplate of 237, holes at an
# angle, a wheel's axle hole.
HOLED_PARTS = [
    "6222.dat",      # Brick 4 x 4 Round with Holes
    "18897.dat",     # Brick 6 x 6 Round with Holes
    "30361a.dat",    # Cylinder 2 x 2 x 2 Robot Body
    "7246.dat",      # Brick Round 2 x 2 x 2 Half Cylinder Extended Robot Body
    "2791a.dat",     # Technic Steering Gear Holder
    "32524.dat",     # Technic Beam 7
    "32278.dat",     # Technic Beam 15
    "3702.dat",      # Technic Brick 1 x 8 with Holes
    "39369.dat",     # Technic Beam 19 x 11 Baseplate
    "10288.dat",     # Technic Angle Connector (3 x 120 degree)
    "100942.dat",    # Wheel 37 x 45 Hard-Plastic with 6 Curved Spokes
]


@needs_numpy
@pytest.mark.parametrize("part", HOLED_PARTS)
def test_a_pin_in_any_hole_misses_the_cover(part: str) -> None:
    """Every pin and axle hole the part declares, and every hole drawn by
    hand that a pin fits, takes a pin's shaft without it touching the
    cover: 4 LDU either side of a declared hole's middle, which is all a
    connector says of where the hole is, and the whole length of a drawn
    one."""
    cells, connectors = _built_cover(part)
    checked = 0
    for c in connectors:
        if c.kind in ("pin_hole", "axle_hole"):
            way = c.axis
            at = tuple(c.pos[n] - 4.0 * way[n] for n in range(3))
            depth = 8.0
        elif c.kind == "bore" and abs(c.radius - 6.0) <= 0.5 and abs(c.axis[1]) < 0.01:
            way, at, depth = c.axis, c.pos, c.length
        else:
            continue
        checked += 1
        # A pin's core, 4 LDU out from its axis: an axle's cross is 6 at
        # its arms and 4 between them.
        assert _in_shaft(cells, at, way, depth, 4.0) == [], (part, c.kind, c.pos)
    assert checked > 0


# Parts whose handle is a bar in a loop: 2540's runs beside the plate
# between two arms, 60478's off its end, 48336's beside it the whole length,
# 30236's beside a brick, 78257's off both ends. 69934, a 10 x 16 plate with
# eight handles down one side, was past the box limit, so its cover was its
# bounding box and buried every one.
HANDLES = ["2540.dat", "60478.dat", "48336.dat", "30236.dat", "78257.dat", "69934.dat"]


def _clip_on(clip: set, bore: tuple, bar: tuple, out: tuple) -> set:
    """4085c's cover with its clip's middle on ``bar`` and its plate out
    along ``out``: its bore, upright in its own frame (y), along the bar,
    and the plate it stands off (-z) turned to ``out``. Square turns and
    even offsets, so a cell goes to a cell exactly."""
    along = bar[1]
    back = tuple(-v for v in out)
    side = (along[1] * back[2] - along[2] * back[1],
            along[2] * back[0] - along[0] * back[2],
            along[0] * back[1] - along[1] * back[0])

    def turn(q: tuple) -> tuple:
        return tuple(q[0] * side[n] + q[1] * along[n] + q[2] * back[n] for n in range(3))

    shift = tuple(bar[0][n] - turn(bore)[n] for n in range(3))
    moved = set()
    for cell in clip:
        middle = turn(tuple((v + 0.5) * occ.CELL for v in cell))
        moved.add(tuple(int((middle[n] + shift[n]) // occ.CELL) for n in range(3)))
    return moved


def _outside_the_clip(shared: set, bar: tuple) -> list:
    """The shared cells a clip on a bar has no business sharing: those not
    within the clip's bore, 4 LDU round and 4 either side of its middle,
    give or take the slack the checker gives a round (Joints.ROUND_SLACK)."""
    slack = 1.5
    (at, way) = bar
    out = []
    for cell in shared:
        gap = [(cell[n] + 0.5) * occ.CELL - at[n] for n in range(3)]
        along = sum(gap[n] * way[n] for n in range(3))
        off = sum((gap[n] - along * way[n]) ** 2 for n in range(3)) ** 0.5
        if abs(along) > 4.0 + slack or off > 4.0 + slack:
            out.append(cell)
    return out


@needs_numpy
@pytest.mark.parametrize("part", HANDLES)
def test_a_clip_on_a_handle_misses_the_cover(part: str) -> None:
    """A clip put on a plate's handle, its plate held out from the handle,
    up or down, shares no cell with the handle's part but inside its own
    bore, which is where the bar is. The fill closed the loop of every
    handle beside a plate, so the bar was buried in cover and a clip on it
    was refused as an overlap with the plate it was clipped to.

    And not by hollowing: the same clip two LDU off the bar's line, which
    is a clip pressed into the side of the bar, still shares cells."""
    cells, connectors = _built_cover(part)
    clip, clip_connectors = _built_cover("4085c.dat")
    eye = [c for c in clip_connectors if c.kind == "bore" and abs(c.radius - 4.0) < 0.1]
    assert len(eye) == 1 and abs(abs(eye[0].axis[1]) - 1.0) < 1e-6, eye
    bore = tuple(eye[0].pos[n] + eye[0].axis[n] * eye[0].length * 0.5 for n in range(3))

    handles = [c for c in connectors if c.kind == "shaft" and abs(c.radius - 4.0) < 0.1
               and abs(c.axis[1]) < 0.01 and c.length >= 8.0 - 1e-6]
    assert handles, part
    for c in handles:
        middle = tuple(c.pos[n] + c.axis[n] * c.length * 0.5 for n in range(3))
        # Out from the plate: across the bar, level, away from the middle.
        across = (-c.axis[2], 0.0, c.axis[0])
        if across[0] * middle[0] + across[2] * middle[2] < 0:
            across = tuple(-v for v in across)
        bar = (middle, tuple(c.axis))
        for out in (across, (0.0, 1.0, 0.0), (0.0, -1.0, 0.0)):
            on = _clip_on(clip, bore, bar, out)
            stray = _outside_the_clip(on & cells, bar)
            assert stray == [], (part, c.pos, out, len(stray))

            toward = tuple(middle[n] - 2.0 * across[n] for n in range(3))
            pressed = _clip_on(clip, bore, (toward, tuple(c.axis)), out)
            assert pressed & cells, (part, c.pos, out)


@needs_numpy
def test_a_quarter_ring_keeps_its_inside_open() -> None:
    """A quarter of a ring of 140 (24121) is 472 boxes exact, past the
    limit, and its cover was its bounding box: solid inside its teeth, so
    the pinion that turns a ring from inside, and everything else a ring
    goes round, overlapped it, and four quarters laid as LEGO set 42055
    lays them overlapped each other. A part whose box is mostly air keeps
    its own cells (occupancy.MOSTLY_AIR)."""
    cells, _connectors = _built_cover("24121.dat")
    # The teeth are on a circle of 175 LDU round the part's origin, on its
    # up axis; a 12 meshing them stands 160 out and reaches 177.5.
    inside = [c for c in cells
              if ((c[0] + 0.5) * occ.CELL) ** 2 + ((c[2] + 0.5) * occ.CELL) ** 2 < 165.0 ** 2]
    assert inside == [], len(inside)
    # And it still covers the plastic: the arc between the teeth and the rim.
    rim = [c for c in cells
           if 175.0 ** 2 < ((c[0] + 0.5) * occ.CELL) ** 2 + ((c[2] + 0.5) * occ.CELL) ** 2 < 195.0 ** 2]
    assert len(rim) > 5000, len(rim)


# -- things the library does not tell you plainly -----------------------


def test_fabric_is_not_speckle(palette: Palette) -> None:
    """MATERIAL has three kinds, not two.

    Treating everything that is not GLITTER as SPECKLE swept the twenty
    FABRIC colours in with the four real speckles. Fabric is not plastic:
    it is cloth — capes, sails, flags — and needs a different shader, so
    the miscount sized the wrong bucket.
    """
    counts: dict[str, int] = {}
    for color in palette:
        counts[color.finish.value] = counts.get(color.finish.value, 0) + 1

    assert counts.get("speckle") == 4
    assert counts.get("fabric") == 20
    assert sum(counts.values()) == len(palette)


def test_opalescent_is_split_from_glitter(palette: Palette) -> None:
    """LDraw writes opal colours as GLITTER, but they also glow.

    A milky opalescent sheen does not look like suspended flecks, and
    the eight Opal_* colours all carry LUMINANCE where true glitter does
    not.
    """
    counts: dict[str, int] = {}
    for color in palette:
        counts[color.finish.value] = counts.get(color.finish.value, 0) + 1
    assert counts.get("opalescent") == 8
    assert counts.get("glitter") == 7

    opal = palette.get(360)  # Opal_Trans_Clear
    assert opal.finish is Finish.OPALESCENT
    assert opal.luminance > 0


def test_moved_stubs_are_found_by_title_not_by_type(library: Library) -> None:
    """1,160 redirect stubs are tagged as ordinary Parts.

    This is the trap: they carry !LDRAW_ORG "Part UPDATE <year>", not
    Alias, and share no overlap with the 495 files that *are* tagged
    Alias. Filtering on the type misses every one of them, so a
    catalogue built that way offers a thousand entries that are not
    things. The only signal is the title.
    """
    moved = library.get("100.dat")
    assert moved is not None
    assert moved.is_redirect
    assert moved.moved_to == "3665"
    # The thing that makes it a trap:
    assert not moved.is_alias
    assert "alias" not in moved.part_type.lower()


def test_a_redirect_still_renders_its_target(library: Library) -> None:
    """A stub holds one identity reference, so it draws the real part."""
    stub = flatten(library, "100.dat")
    target = flatten(library, "3665.dat")
    assert len(stub.triangles) == len(target.triangles)
    assert stub.bounds() == target.bounds()


# -- click hinges, and covers that are the part --------------------------------


def _line(connection) -> tuple:
    """A round's line in a frame: its middle and its way."""
    p, a = connection.position, connection.axis
    middle = (p.x + a.x * connection.length / 2, p.y + a.y * connection.length / 2,
              p.z + a.z * connection.length / 2)
    return middle, (a.x, a.y, a.z)


def test_a_click_hinge_finger_and_fork_are_one_line_when_put_together(
        library: Library) -> None:
    """44302a's two fingers and 44301a's one are drawn from clh primitives and
    nothing else, so neither had a connector and a locking hinge held nothing
    (180 floating parts put down to it in the first 362 real sets). Each now
    has its turning line: a fork on 44302a, a finger on 44301a, and laid end
    to end as sets lay them (44301a turned half round, 60 along) the two lines
    are one."""
    fork = [c for c in extract(library, "44302a.dat") if c.kind is ConnectorKind.FORK]
    finger = [c for c in extract(library, "44301a.dat") if c.kind is ConnectorKind.FINGER]
    assert len(fork) == 1 and len(finger) == 1
    assert fork[0].gender is Gender.FEMALE and finger[0].gender is Gender.MALE
    (fx, fy, fz), fway = _line(fork[0])
    (gx, gy, gz), gway = _line(finger[0])
    # 44301a turned half round about y and moved 60 along x.
    gx, gz = 60.0 - gx, -gz
    assert abs(abs(fway[2]) - 1.0) < 1e-6 and abs(abs(gway[2]) - 1.0) < 1e-6
    assert (fx, fy, fz) == pytest.approx((gx, gy, gz), abs=0.01)


def test_a_part_without_click_hinges_has_no_finger(library: Library) -> None:
    """A finger or a fork comes only from a clh primitive: a brick, a plate
    with a clip and a hinge brick have none."""
    for part in ("3001.dat", "61252.dat", "3830.dat", "3831.dat"):
        kinds = {c.kind for c in extract(library, part)}
        assert ConnectorKind.FINGER not in kinds and ConnectorKind.FORK not in kinds, part


@needs_numpy
def test_a_quarter_dome_is_covered_as_a_shell_not_its_box() -> None:
    """87375, a quarter dome, is past the box limit at full grain, and its
    cover was its bounding box: everything under the dome and the clips on
    its handles collided with it. It is a coarser shell now: far fewer cells
    than its box, its handle still in it, its hollow open, and room round
    its bottom handle for a clip."""
    cells, _connectors = _built_cover("87375.dat")
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    zs = [c[2] for c in cells]
    box = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1) * (max(zs) - min(zs) + 1)
    assert len(cells) < box * 0.4, (len(cells), box)
    # App axes, cells of 2 LDU: the bottom handle runs along x at y -120,
    # z 120 LDU.
    assert (0, -60, 60) in cells
    # Under the crown, the hollow of the dome.
    assert (0, -40, 30) not in cells and (0, -30, 25) not in cells
    # A clip's ring round the handle, 6 LDU under it.
    assert (0, -63, 60) not in cells


@needs_numpy
def test_four_quarter_domes_meet_at_their_seams_without_sharing_a_cell() -> None:
    """The four quarters of a dome meet edge to edge on planes at 45 degrees
    through lattice points, so a face ran through cell middles, and a cell on
    it was inside both quarters: the dome overlapped itself along every seam.
    A quarter and the next, turned a quarter either way about the dome's
    axis (app x 0, z -30 LDU), share no cell."""
    cells, _connectors = _built_cover("87375.dat")
    # A cell's middle is at (2x + 1, 2z + 1) LDU; turned a quarter about
    # (0, -30) it is the middle of (-z - 16, x - 15), or of (z + 15, -x - 16)
    # the other way.
    one = {(-z - 16, y, x - 15) for x, y, z in cells}
    other = {(z + 15, y, -x - 16) for x, y, z in cells}
    assert not (cells & one) and not (cells & other)


@needs_numpy
def test_a_pane_keeps_the_cells_its_faces_run_through() -> None:
    """60601's glass is drawn between z 3 and z 7, both cell middles (cells
    1 and 3), and square to z. Its faces' cells are the pane's: a seam at 45
    degrees gives its cells to neither side, a face square to the grid does
    not, or the pane is its middle layer alone and stands in its frame
    touching nothing."""
    cells, _connectors = _built_cover("60601.dat")
    layers = {z: sum(1 for c in cells if c[2] == z) for z in (1, 2, 3)}
    assert layers[1] >= 150 and layers[3] >= 150 and layers[2] >= 250


@needs_numpy
@pytest.mark.parametrize("part", ["58846.dat", "95188.dat"])
def test_a_tapered_quarter_ring_is_covered_as_its_shape(part: str) -> None:
    """58846 and 95188, the 10 x 10 and 6 x 6 tapered quarter rings, were
    their bounding boxes, solid squares: nothing a real set nests in one
    fitted. Each is its shape now: well under its box, and open at the
    corners of its square that the quarter ring does not reach."""
    cells, _connectors = _built_cover(part)
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    zs = [c[2] for c in cells]
    box = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1) * (max(zs) - min(zs) + 1)
    assert len(cells) < box * 0.7, (len(cells), box)
    middle = (min(ys) + max(ys)) // 2
    corners = [(x, middle, z) for x in (min(xs), max(xs)) for z in (min(zs), max(zs))]
    assert sum(1 for c in corners if c not in cells) >= 2, part


@needs_numpy
def test_a_round_plate_with_an_opening_is_open_through_it() -> None:
    """11833, a 4 x 4 round plate with a 2 x 2 round opening, filled its
    opening layer by layer like a brick's underside, so a round brick put
    through it, as sets put one, collided with it. A column with no plastic
    at any height is open now, and the plate round it is still there."""
    cells, _connectors = _built_cover("11833.dat")
    assert not [c for c in cells if c[0] in (-1, 0) and c[2] in (-1, 0)]
    assert (15, -1, 0) in cells
