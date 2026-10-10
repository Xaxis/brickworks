"""The parts the element maker makes, measured as the library's own are.

The files are tests/fixtures/elements/*.dat, written by the maker in the app
(src/parts/element_maker.gd) and held to its current output by
src/dev/element_files_probe.gd, so what is measured here is what a designer
gets. Each test reads a file through the same parser, flattener and
connector walk the mesh build uses — nothing here knows how the maker works.

Three kinds of claim:

- It is an LDraw part: the header the LDraw spec asks of an unofficial
  part, every line parsed, every reference resolved, every face wound so
  a vertical line through the part goes in and comes out.
- It is the size it says, in the system's units: 20 LDU a stud, 8 a plate,
  studs on the 20 LDU grid pointing up, tubes between them pointing down,
  walls and top 4 LDU thick — read off the geometry by stabbing it.
- A standard size is the standard part: the maker's 2 x 4 brick is 3001
  triangle for triangle, and its 45 degree slope's face is where 3039's is.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.connectivity import extract  # noqa: E402
from ldraw.geometry import Mesh, flatten  # noqa: E402
from ldraw.library import Library  # noqa: E402
from ldraw.parser import parse_text  # noqa: E402

LDRAW_ROOT = ROOT / "vendor" / "ldraw"
FIXTURES = ROOT / "tests" / "fixtures" / "elements"
FILES = sorted(p.name for p in FIXTURES.glob("*.dat"))

pytestmark = pytest.mark.skipif(
    not (LDRAW_ROOT / "parts").is_dir(),
    reason="LDraw library not present; run tools/fetch_data.sh",
)

try:
    from ldraw import occupancy as occ
except ImportError:  # numpy and scipy
    occ = None
needs_numpy = pytest.mark.skipif(
    occ is None, reason="numpy/scipy not installed; apt install python3-numpy python3-scipy")


@pytest.fixture(scope="session")
def library() -> Library:
    return Library(LDRAW_ROOT, extra=[FIXTURES])


def spec_of(name: str) -> dict:
    """The words the maker wrote into the header, as a dict."""
    for line in (FIXTURES / name).read_text().splitlines():
        if line.startswith("0 // Made by Brickworks:"):
            words = line.split(":", 1)[1].split()
            spec: dict = {}
            for word in words:
                key, value = word.split("=")
                spec[key] = value if key in ("family", "studs", "from") else int(value)
            return spec
    raise AssertionError(f"{name} does not say what made it")


def footprint(spec: dict) -> tuple[float, float]:
    """The body's width on X and depth on Z, in LDU, as the library lays a
    part out: the long side along X for a brick."""
    if spec["family"] == "round":
        return spec["diameter"] * 20.0, spec["diameter"] * 20.0
    if spec["family"] == "brick":
        return (max(spec["across"], spec["deep"]) * 20.0,
                min(spec["across"], spec["deep"]) * 20.0)
    return spec["across"] * 20.0, spec["deep"] * 20.0


def stab(mesh: Mesh, x: float, z: float) -> list[tuple[float, float]]:
    """Where a vertical line through (x, z) is inside the plastic, as the
    mesh build's voxeliser decides it: each face crossed counts +1 if it
    faces down (a way in, going up) and -1 if it faces up, and the line is
    inside wherever the count is above zero.

    That rule rather than "goes in, comes out", because LDraw parts are
    not closed solids: a stud is an open cylinder stood on the top face,
    and a brick's cavity ceiling runs straight across the tops of its
    tubes. 3001 draws itself that way and the voxeliser fills it right.

    Returns the solid spans as (top, bottom) in LDraw y, which grows
    downward, touching spans joined.
    """
    hits: list[tuple[float, int]] = []
    for t in mesh.triangles:
        d = (t.b.x - t.a.x) * (t.c.z - t.a.z) - (t.b.z - t.a.z) * (t.c.x - t.a.x)
        if abs(d) < 1e-9:
            continue
        w0 = ((t.b.x - x) * (t.c.z - z) - (t.b.z - z) * (t.c.x - x)) / d
        w1 = ((t.c.x - x) * (t.a.z - z) - (t.c.z - z) * (t.a.x - x)) / d
        w2 = 1.0 - w0 - w1
        if min(w0, w1, w2) < 0.0:
            continue
        y = w0 * t.a.y + w1 * t.b.y + w2 * t.c.y
        hits.append((y, 1 if t.normal().y > 0 else -1))
    hits.sort(key=lambda h: -h[0])
    spans: list[tuple[float, float]] = []
    winding = 0
    previous = None
    for y, direction in hits:
        if winding > 0 and previous is not None and previous - y > 1e-9:
            if spans and abs(spans[-1][0] - previous) < 1e-6:
                spans[-1] = (y, spans[-1][1])
            else:
                spans.append((y, previous))
        winding += direction
        previous = y
    return [(round(top, 3), round(bottom, 3)) for top, bottom in spans]


def crossings(mesh: Mesh, x: float, z: float) -> list[tuple[float, int]]:
    """Every face a vertical line through (x, z) crosses, top first, as
    (y, +1 facing down or -1 facing up)."""
    hits: list[tuple[float, int]] = []
    for t in mesh.triangles:
        d = (t.b.x - t.a.x) * (t.c.z - t.a.z) - (t.b.z - t.a.z) * (t.c.x - t.a.x)
        if abs(d) < 1e-9:
            continue
        w0 = ((t.b.x - x) * (t.c.z - z) - (t.b.z - z) * (t.c.x - x)) / d
        w1 = ((t.c.x - x) * (t.a.z - z) - (t.c.z - z) * (t.a.x - x)) / d
        if min(w0, w1, 1.0 - w0 - w1) < 0.0:
            continue
        y = w0 * t.a.y + w1 * t.b.y + (1.0 - w0 - w1) * t.c.y
        hits.append((round(y, 3), 1 if t.normal().y > 0 else -1))
    return sorted(hits)


def top_at(spec: dict, x: float, z: float) -> float | None:
    """Where the part's top should be over (x, z), or None off the part."""
    width, depth = footprint(spec)
    if spec["family"] == "round":
        r = width / 2
        return 0.0 if (x * x + z * z) ** 0.5 < r - 1.0 else None
    if abs(x) > width / 2 - 0.5 or abs(z) > depth / 2 - 0.5:
        return None
    if spec["family"] == "slope":
        h = spec["plates"] * 8.0
        front, edge = -depth / 2, depth / 2 - (spec["deep"] - spec["run"]) * 20.0
        if z < edge:
            return (h - 4.0) * (edge - z) / (edge - front)
    return 0.0


# -- it is an LDraw part ---------------------------------------------------


def test_there_are_fixtures() -> None:
    assert len(FILES) >= 10, "run src/dev/element_files_probe.gd -- --write"


@pytest.mark.parametrize("name", FILES)
def test_header_is_an_unofficial_part(library: Library, name: str) -> None:
    """The header lines ldraw.org/article/398 asks for, in its order."""
    lines = [l for l in (FIXTURES / name).read_text().splitlines() if l.strip()]
    assert lines[1] == f"0 Name: {name}"
    assert lines[2].startswith("0 Author: ")
    assert lines[3] == "0 !LDRAW_ORG Unofficial_Part"
    assert lines[4] == "0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt"
    assert lines[5] == "0 BFC CERTIFY CCW"
    part = library.get(name)
    assert part is not None
    assert part.description == lines[0][2:]
    assert part.part_type == "Unofficial_Part"
    assert part.bfc_certified and part.bfc_ccw
    assert part.category in ("Brick", "Plate", "Tile", "Slope")
    assert part.path.parent == FIXTURES


@pytest.mark.parametrize("name", FILES)
def test_every_line_parses(name: str) -> None:
    """Strictly: the parser raises on a line it cannot read."""
    text = (FIXTURES / name).read_text()
    commands = list(parse_text(text, strict=True))
    drawn = [line for line in text.splitlines() if line[:1] in "12345"]
    assert len(drawn) > 0
    assert len(commands) >= len(drawn)


@pytest.mark.parametrize("name", FILES)
def test_everything_it_references_resolves(library: Library, name: str) -> None:
    mesh = flatten(library, name)
    assert not mesh.missing, f"{name} references {sorted(mesh.missing)}"
    assert len(mesh.triangles) > 50
    for t in mesh.triangles:
        assert t.area() > 1e-9


@pytest.mark.parametrize("name", FILES)
def test_the_top_is_closed_and_where_it_should_be(library: Library, name: str) -> None:
    """Stabbed on a grid of lines, every one finds plastic, and its top
    where the part's top is: 0 on a flat top, the face on a slope. A face
    wound inside out makes the line miss the top, or start inside."""
    spec = spec_of(name)
    mesh = flatten(library, name)
    width, depth = footprint(spec)
    for i in range(-5, 6):
        for k in range(-5, 6):
            x = i * width / 11.0 + 0.37
            z = k * depth / 11.0 + 0.71
            expected = top_at(spec, x, z)
            if expected is None:
                continue
            spans = stab(mesh, x, z)
            assert spans, f"{name}: nothing at x={x:.2f} z={z:.2f}"
            assert spans[0][0] == pytest.approx(expected, abs=0.01), (name, x, z, spans)


# -- it is the size it says -------------------------------------------------


@pytest.mark.parametrize("name", FILES)
def test_bounds_are_the_named_size(library: Library, name: str) -> None:
    spec = spec_of(name)
    lo, hi = flatten(library, name).bounds()
    width, depth = footprint(spec)
    assert hi.x - lo.x == pytest.approx(width, abs=0.01)
    assert hi.z - lo.z == pytest.approx(depth, abs=0.01)
    # Centred, as the app's stud snapping assumes a part's origin is.
    assert (hi.x + lo.x) == pytest.approx(0.0, abs=0.01)
    assert (hi.z + lo.z) == pytest.approx(0.0, abs=0.01)
    # The body's bottom is the height in plates; the studs stand 4 above
    # its top, which is y = 0.
    assert hi.y == pytest.approx(spec["plates"] * 8.0)
    assert lo.y == pytest.approx(-4.0 if spec["studs"] == "yes" else 0.0)


def _studs(library: Library, name: str):
    return [c for c in extract(library, name) if c.kind.value == "stud"]


def _gripping(library: Library, name: str):
    """Tubes, and the pins of a part one stud wide: both are TUBE."""
    return [c for c in extract(library, name) if c.kind.value == "tube"]


@pytest.mark.parametrize("name", FILES)
def test_studs_sit_on_the_grid_and_point_up(library: Library, name: str) -> None:
    spec = spec_of(name)
    width, depth = footprint(spec)
    studs = _studs(library, name)
    for stud in studs:
        assert stud.position.y == pytest.approx(0.0)
        assert (stud.axis.x, stud.axis.y, stud.axis.z) == pytest.approx((0.0, -1.0, 0.0))
        # Half a pitch in from an edge, then whole pitches.
        assert ((stud.position.x + width / 2 - 10.0) / 20.0) % 1 == pytest.approx(0.0, abs=1e-6)
        assert ((stud.position.z + depth / 2 - 10.0) / 20.0) % 1 == pytest.approx(0.0, abs=1e-6)
        assert abs(stud.position.x) < width / 2 and abs(stud.position.z) < depth / 2
    if spec["studs"] == "no":
        assert not studs
    elif spec["family"] == "brick" or spec["family"] == "inverted":
        assert len(studs) == spec["across"] * spec["deep"]
    elif spec["family"] == "slope":
        # Only the flat rows: the face falls over `run` of them.
        assert len(studs) == spec["across"] * (spec["deep"] - spec["run"])
        flat_from = depth / 2 - (spec["deep"] - spec["run"]) * 20.0
        assert all(s.position.z > flat_from for s in studs)


@pytest.mark.parametrize("name,expected", [
    ("bw-r2x3.dat", 4), ("bw-r4x1.dat", 12), ("bw-r3x6.dat", 5), ("bw-r1x1t.dat", 0),
])
def test_round_parts_carry_the_studs_that_fit(
    library: Library, name: str, expected: int
) -> None:
    """A stud is drawn where a whole one fits on the top: the 2 x 2 round's
    four, as 3941 has, and the 4 x 4 round plate's twelve."""
    assert len(_studs(library, name)) == expected


@pytest.mark.parametrize("name", FILES)
def test_tubes_sit_between_studs_and_point_down(library: Library, name: str) -> None:
    """On the stud grid's corners, between four studs, never under one —
    or on a part one stud wide, a pin between two studs in the row."""
    spec = spec_of(name)
    width, depth = footprint(spec)
    tubes = _gripping(library, name)
    # What stands on the bottom: an inverted slope's flat rows only.
    deep = spec.get("deep", 9) - (spec["run"] if spec["family"] == "inverted" else 0)
    one_wide = spec["family"] != "round" and min(spec.get("across", 9), deep) == 1
    for tube in tubes:
        assert (tube.axis.x, tube.axis.y, tube.axis.z) == pytest.approx((0.0, 1.0, 0.0))
        gx = ((tube.position.x + width / 2) / 20.0) % 1
        gz = ((tube.position.z + depth / 2) / 20.0) % 1
        if one_wide:
            # The short side is one stud: the pin is in its middle.
            short_g = gz if deep * 20.0 < width else gx
            long_g = gx if deep * 20.0 < width else gz
            assert short_g == pytest.approx(0.5, abs=1e-6)
            assert long_g == pytest.approx(0.0, abs=1e-6)
        else:
            assert (gx, gz) == pytest.approx((0.0, 0.0), abs=1e-6)
        # From the ceiling or below it, never above the top.
        assert tube.position.y >= 4.0 - 1e-6
    if spec["family"] == "brick":
        along, over = max(spec["across"], spec["deep"]), min(spec["across"], spec["deep"])
        if over >= 2:
            expected = {(-width / 2 + 20.0 * i, -depth / 2 + 20.0 * j)
                        for i in range(1, along) for j in range(1, over)}
        else:
            expected = {(-width / 2 + 20.0 * i, 0.0) for i in range(1, along)}
        assert {(round(t.position.x, 3), round(t.position.z, 3)) for t in tubes} == expected


@pytest.mark.parametrize("name", [n for n in FILES if spec_of(n)["family"] == "brick"])
def test_walls_and_top_are_four_ldu(library: Library, name: str) -> None:
    """Stabbed through any of the four walls the part is solid top to
    bottom up to four LDU in, and past that, inside, solid only for the
    four LDU of its top."""
    spec = spec_of(name)
    mesh = flatten(library, name)
    width, depth = footprint(spec)
    h = spec["plates"] * 8.0
    hx, hz = width / 2, depth / 2
    # Each wall, stabbed 5.37 from a corner along it, where nothing else
    # is: studs stop 4 short of a wall, tubes 12, pins 16. (Not 5.3: on a
    # 1 x 3 that lands exactly on the ceiling quad's diagonal, which both
    # its triangles then claim.)
    for x, z, into in (
        (-hx + 5.37, hz, (0, -1)), (hx - 5.37, -hz, (0, 1)),
        (hx, hz - 5.37, (-1, 0)), (-hx, -hz + 5.37, (1, 0)),
    ):
        # Through the wall: the top, then the bottom, and nothing between.
        inside = crossings(mesh, x + into[0] * 3.7, z + into[1] * 3.7)
        assert inside == [(0.0, -1), (h, 1)], (name, "in the wall", x, z, inside)
        # Past it: the top, then the cavity's ceiling four LDU down.
        past = crossings(mesh, x + into[0] * 4.3, z + into[1] * 4.3)
        assert past == [(0.0, -1), (4.0, 1)], (name, "past the wall", x, z, past)


@pytest.mark.parametrize("name", FILES)
def test_every_surface_faces_out(library: Library, name: str) -> None:
    """The highest face a vertical line crosses faces up and the lowest
    faces down, wherever the line crosses the part. A face wound inside
    out is culled from view and the part shows a hole; the voxeliser
    cannot tell, so this is what does."""
    mesh = flatten(library, name)
    width, depth = footprint(spec_of(name))
    for i in range(-6, 7):
        for k in range(-6, 7):
            x = i * width / 13.0 + 0.37
            z = k * depth / 13.0 + 0.71
            hits = crossings(mesh, x, z)
            if len(hits) < 2:
                # Missed, or only the top of a stud: a round part's
                # studs stand a fifth of an LDU over its sixteen-sided
                # rim, as 3941's do.
                continue
            assert hits[0][1] == -1, f"{name}: the top at x={x:.2f} z={z:.2f} faces in"
            assert hits[-1][1] == 1, f"{name}: the bottom at x={x:.2f} z={z:.2f} faces in"


@pytest.mark.parametrize("name", [n for n in FILES if spec_of(n)["family"] == "slope"])
def test_a_slope_is_four_ldu_thick_under_its_face(library: Library, name: str) -> None:
    """Under the face the plastic is the four LDU between the face and the
    cavity's ceiling, which follows it down; the foot is a 4 LDU lip."""
    spec = spec_of(name)
    mesh = flatten(library, name)
    width, depth = footprint(spec)
    h = spec["plates"] * 8.0
    front, edge = -depth / 2, depth / 2 - (spec["deep"] - spec["run"]) * 20.0
    face = lambda z: (h - 4.0) * (edge - z) / (edge - front)  # noqa: E731
    x = -width / 2 + 5.3 if spec["across"] >= 1 else 0.0
    # Between the edge of the flat rows and the front wall's inside,
    # clear of tubes (which stand on grid corners).
    z = front + 8.7
    spans = stab(mesh, x, z)
    assert spans[0][0] == pytest.approx(face(z), abs=0.01)
    assert spans[0][1] - spans[0][0] == pytest.approx(4.0, abs=0.01)
    # And through the lip, 2 in from the front, the solid wall.
    spans = stab(mesh, x, front + 1.3)
    assert spans[0][0] == pytest.approx(face(front + 1.3), abs=0.01)
    assert spans[-1][1] == pytest.approx(h)


# -- a standard size is the standard part ------------------------------------


def _faces(mesh: Mesh, shift_z: float = 0.0) -> list[tuple]:
    """Every triangle as an oriented loop of rounded points, starting from
    its smallest, so the same face wound the same way compares equal."""
    out = []
    for t in mesh.triangles:
        loop = [(round(p.x, 2), round(p.y, 2), round(p.z + shift_z, 2))
                for p in (t.a, t.b, t.c)]
        start = loop.index(min(loop))
        out.append(tuple(loop[start:] + loop[:start]))
    return sorted(out)


def test_a_standard_brick_is_the_library_part(library: Library) -> None:
    """Triangle for triangle, wound the same way: the maker builds a 2 x 4
    the way James Jessiman's 3001 is built."""
    assert _faces(flatten(library, "bw-b2x4x3.dat")) == _faces(flatten(library, "3001.dat"))


@pytest.mark.parametrize("made,real,shift,surface", [
    ("bw-b1x1x3.dat", "3005.dat", 0.0, "top"),       # Brick 1 x 1
    ("bw-b1x2x1.dat", "3023b.dat", 0.0, "top"),      # Plate 1 x 2
    ("bw-b2x2x1t.dat", "3068b.dat", 0.0, "top"),     # Tile 2 x 2 with Groove
    ("bw-s2x2x3r1.dat", "3039.dat", -10.0, "top"),   # Slope 45 2 x 2
    ("bw-s3x2x3r2.dat", "3298.dat", -20.0, "top"),   # Slope 33 3 x 2
    ("bw-i2x2x3r1.dat", "3660a.dat", -10.0, "bottom"),  # Slope 45 2 x 2 Inverted
    ("bw-r2x3.dat", "3941.dat", 0.0, "top"),         # Brick 2 x 2 Round
])
def test_a_standard_size_has_the_library_parts_shape(
    library: Library, made: str, real: str, shift: float, surface: str
) -> None:
    """The same outside wherever it is stabbed, the same studs, and the
    same tubes in the same places.

    The library's slopes put their origin on the back row of studs; the
    maker centres every part, as the app's placement assumes, so the
    comparison moves the made one by that much.
    """
    ours, theirs = flatten(library, made), flatten(library, real)
    lo, hi = ours.bounds()
    rlo, rhi = theirs.bounds()
    assert (lo.x, lo.y, lo.z + shift, hi.x, hi.y, hi.z + shift) == pytest.approx(
        (rlo.x, rlo.y, rlo.z, rhi.x, rhi.y, rhi.z), abs=0.01)
    for i in range(1, 8):
        for k in range(1, 8):
            x = rlo.x + (rhi.x - rlo.x) * i / 8.0 + 0.31
            z = rlo.z + (rhi.z - rlo.z) * k / 8.0 + 0.67
            mine = stab(ours, x, z - shift)
            real_spans = stab(theirs, x, z)
            if not real_spans:
                continue
            # The outside: the top, or for an inverted slope the face
            # underneath, since 3660a is cored out from above under its
            # front studs where the maker draws it solid.
            if surface == "top":
                assert mine[0][0] == pytest.approx(real_spans[0][0], abs=0.02), (x, z)
            else:
                assert mine[-1][1] == pytest.approx(real_spans[-1][1], abs=0.02), (x, z)
    # Where on the top, not how high: 3660a's front studs stand in its
    # coring, their bases 4 LDU down.
    def top_studs(name: str, dz: float = 0.0) -> list[tuple[float, float]]:
        return sorted((round(c.position.x, 2), round(c.position.z + dz, 2))
                      for c in _studs(library, name) if c.axis.y < -0.99)
    assert top_studs(made, shift) == top_studs(real)

    def tubes(name: str, dz: float = 0.0) -> set[tuple[float, float]]:
        return {(round(c.position.x, 2), round(c.position.z + dz, 2))
                for c in _gripping(library, name)}
    assert tubes(made, shift) == tubes(real)


# -- the build path --------------------------------------------------------


def test_parts_are_taken_out_of_a_model_file() -> None:
    """A model saved with a made part carries it as a `0 FILE x.dat`
    section, and build_custom finds it there and not the sub-models."""
    import build_custom
    part = (FIXTURES / "bw-b2x7x3.dat").read_text()
    # The sub-model is called wall.dat, as older model files call theirs:
    # a name is not what makes a section a part, its header is.
    mpd = ("0 FILE model.ldr\n0 Model\n0 Name: model.ldr\n"
           "1 4 0 0 0 1 0 0 0 1 0 0 0 1 bw-b2x7x3.dat\n"
           "1 16 0 0 0 1 0 0 0 1 0 0 0 1 wall.dat\n0\n0 NOFILE\n"
           "0 FILE wall.dat\n0 Wall\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n"
           "0 FILE bw-b2x7x3.dat\n" + part + "0 NOFILE\n")
    found = build_custom.embedded_parts(mpd)
    assert list(found) == ["bw-b2x7x3.dat"]
    assert found["bw-b2x7x3.dat"].strip() == part.strip()


def test_check_says_whether_a_file_carries_its_parts_whole() -> None:
    """--check, which needs no numpy: a file with a made part in it reads
    strictly and builds whole; one whose part names a primitive nobody has
    is refused, by name."""
    import build_custom
    part = (FIXTURES / "bw-b1x5x1.dat").read_text()
    whole = ("0 FILE model.ldr\n0 Model\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 bw-b1x5x1.dat\n"
             "0 NOFILE\n0 FILE bw-b1x5x1.dat\n" + part + "0 NOFILE\n")
    import tempfile
    with tempfile.TemporaryDirectory() as scratch:
        good = Path(scratch) / "good.mpd"
        good.write_text(whole)
        assert build_custom.check([good]) == 0
        bad = Path(scratch) / "bad.mpd"
        bad.write_text(whole.replace("stud3.dat", "no-such-primitive.dat"))
        assert build_custom.check([bad]) == 1


@needs_numpy
def test_pipeline_json_is_what_the_pipeline_makes_now() -> None:
    """pipeline.json is what the app's own build is held against. If the
    files or the pipeline moved and it did not, that comparison is stale."""
    import build_custom
    kept = json.loads((FIXTURES / "pipeline.json").read_text())["parts"]
    built = build_custom.build([FIXTURES / name for name in FILES])
    for part_id, blob, _record, _source in built:
        assert build_custom.summary(part_id, blob) == kept[part_id], part_id


@needs_numpy
def test_the_made_brick_occupies_its_size_and_takes_studs_where_it_has_them() -> None:
    """2 x 7 is 14 studs, 14 places a stud goes in underneath, under them,
    and one box of 70 x 12 x 20 cells: the size it says, with nothing
    hollow left for a part to be dropped into."""
    kept = json.loads((FIXTURES / "pipeline.json").read_text())["parts"]
    brick = kept["bw-b2x7x3"]
    assert brick["boxes"] == [[-35, -12, -10, 70, 12, 20]]
    assert brick["cells"] == 70 * 12 * 20
    studs = sorted((c[2][0], c[2][2]) for c in brick["connectors"] if c[0] == "stud")
    assert sorted(tuple(s) for s in brick["sockets"]) == studs
    plate = kept["bw-b1x5x1"]
    assert plate["boxes"] == [[-25, -4, -5, 50, 4, 10]]
    assert len(plate["sockets"]) == 5


@needs_numpy
def test_into_adds_made_parts_to_a_catalogue_and_leaves_the_rest() -> None:
    """--into: the parts join the catalogue under Custom with their meshes
    and sources beside it, an older entry of the same id is replaced, and
    every other entry is left exactly as it was."""
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        other = {"id": "3001", "name": "Brick  2 x  4", "category": "Brick", "mesh": "abc"}
        stale = {"id": "bw-b2x7x3", "name": "old", "category": "Custom", "mesh": "old"}
        (root / "catalogue.json").write_text(json.dumps(
            {"format": 1, "counts": {"parts": 2}, "parts": [other, stale]}))
        done = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "build_custom.py"),
             str(FIXTURES / "bw-b2x7x3.dat"), str(FIXTURES / "bw-s3x3x2r2.dat"),
             "--into", str(root)], capture_output=True, text=True)
        assert done.returncode == 0, done.stdout + done.stderr
        merged = json.loads((root / "catalogue.json").read_text())
        by_id = {e["id"]: e for e in merged["parts"]}
        assert by_id["3001"] == other
        assert merged["counts"]["parts"] == 3
        for part_id in ("bw-b2x7x3", "bw-s3x3x2r2"):
            entry = by_id[part_id]
            assert entry["category"] == "Custom" and entry["custom"] is True
            assert entry["source"] == f"custom/{part_id}.dat"
            assert (root / "parts" / f"{entry['mesh']}.lbm").exists()
            assert (root / entry["source"]).read_text() == (FIXTURES / f"{part_id}.dat").read_text()
        assert by_id["bw-b2x7x3"]["name"] == "Brick  2 x  7"
        assert by_id["bw-b2x7x3"]["ldraw_category"] == "Brick"
        assert by_id["bw-s3x3x2r2"]["ldraw_category"] == "Slope"
