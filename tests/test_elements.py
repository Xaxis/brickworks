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
  triangle for triangle, and its 45 degree slope's face is where 3039's is;
  its brick with a stud on one side has 87087's studs, its bracket 99781's,
  its Technic brick 3700's holes.
"""

from __future__ import annotations

import json
import math
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
                spec[key] = value if key in ("family", "studs", "from", "sides", "way") \
                    else int(value)
            spec.setdefault("sides", "")
            return spec
    raise AssertionError(f"{name} does not say what made it")


def footprint(spec: dict) -> tuple[float, float]:
    """The stud grid's width on X and depth on Z, in LDU, centred, as the
    library lays a part out: the long side along X for a brick. A
    bracket's is its plate's; its upright stands in front of it."""
    if spec["family"] == "round":
        return spec["diameter"] * 20.0, spec["diameter"] * 20.0
    if spec["family"] == "brick":
        return (max(spec["across"], spec["deep"]) * 20.0,
                min(spec["across"], spec["deep"]) * 20.0)
    if spec["family"] == "technic":
        return spec["across"] * 20.0, 20.0
    return spec["across"] * 20.0, spec["deep"] * 20.0


def body(spec: dict) -> tuple[float, float, float, float]:
    """Where the plastic is, seen from above, without studs standing off
    it: x0, x1, z0, z1. A bracket's upright is 4 LDU thick in front of its
    plate (99781: the plate's studs at z = 0, its upright's face at -14)."""
    width, depth = footprint(spec)
    if spec["family"] == "bracket":
        return -width / 2, width / 2, -depth / 2 - 4.0, depth / 2
    return -width / 2, width / 2, -depth / 2, depth / 2


def extent(spec: dict) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    """The bounds the part should have: its body, the studs on its top 4
    LDU over it, and studs on a side or an upright 4 LDU out from it."""
    x0, x1, z0, z1 = body(spec)
    family = spec["family"]
    h = spec["plates"] * 8.0
    flat_rows = spec.get("deep", 0) - spec.get("run", 0)
    studded_top = spec["studs"] == "yes" and not (family == "curved" and flat_rows <= 0)
    y0, y1 = (-4.0 if studded_top else 0.0), h
    if "f" in spec["sides"]:
        z0 -= 4.0
    if "b" in spec["sides"]:
        z1 += 4.0
    if "l" in spec["sides"]:
        x0 -= 4.0
    if "r" in spec["sides"]:
        x1 += 4.0
    if family == "bracket":
        z0 -= 4.0
        rise = spec["rise"] * 20.0
        if spec["way"] == "down":
            y1 = rise
        else:
            y0 = min(y0, h - rise)
    return (x0, y0, z0), (x1, y1, z1)


def curve_y(spec: dict, z: float) -> float:
    """A curved slope's face under the top at z: an eighth of a circle seen
    in the part's own proportions, as 11477 is drawn — z = edge + Az (sin t
    - cos t), y = Ay (sqrt 2 - cos t - sin t) for t from 45 degrees at the
    top of the curve to 0 at its foot, Az the curve's run and Ay chosen so
    the foot is 4 LDU over the bottom. Found here by bisection on t."""
    depth = spec["deep"] * 20.0
    back, front = depth / 2, -depth / 2
    edge = back - (spec["deep"] - spec["run"]) * 20.0
    if z >= edge:
        return 0.0
    run = edge - front
    rise = (spec["plates"] * 8.0 - 4.0) / (math.sqrt(2.0) - 1.0)
    lo, hi = 0.0, math.pi / 4
    for _ in range(60):
        mid = (lo + hi) / 2
        if edge + run * (math.sin(mid) - math.cos(mid)) < z:
            lo = mid
        else:
            hi = mid
    t = (lo + hi) / 2
    return rise * (math.sqrt(2.0) - math.cos(t) - math.sin(t))


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
    x0, x1, z0, z1 = body(spec)
    if not (x0 + 0.5 < x < x1 - 0.5 and z0 + 0.5 < z < z1 - 0.5):
        return None
    if spec["family"] == "bracket" and spec["way"] == "up":
        # The upright stands over the strip in front of the plate.
        if z < -depth / 2 - 0.5:
            return 8.0 - spec["rise"] * 20.0
        if z < -depth / 2 + 0.5:
            return None
    if spec["family"] == "curved":
        return curve_y(spec, z)
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
    assert part.category in ("Brick", "Plate", "Tile", "Slope", "Bracket", "Technic")
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
    x0, x1, z0, z1 = body(spec)
    # A curve is drawn in straight strips between points on it, so its top
    # is the chord, up to an eighth of an LDU under the circle on the
    # tallest curve here.
    within = 0.2 if spec["family"] == "curved" else 0.01
    for i in range(-5, 6):
        for k in range(-5, 6):
            x = x0 + (x1 - x0) * (i + 5.5) / 11.0 + 0.37
            z = z0 + (z1 - z0) * (k + 5.5) / 11.0 + 0.71
            expected = top_at(spec, x, z)
            if expected is None:
                continue
            spans = stab(mesh, x, z)
            assert spans, f"{name}: nothing at x={x:.2f} z={z:.2f}"
            # The highest plastic: a line through a Technic hole's mouth
            # crosses plastic, the hole, and plastic again.
            top = min(span[0] for span in spans)
            assert top == pytest.approx(expected, abs=within), (name, x, z, spans)


# -- it is the size it says -------------------------------------------------


@pytest.mark.parametrize("name", FILES)
def test_bounds_are_the_named_size(library: Library, name: str) -> None:
    """The footprint centred on the origin, as the app's stud snapping
    assumes; the body's bottom the height in plates under a top at y = 0;
    studs 4 LDU off whatever face they stand on; a bracket's upright 4 LDU
    in front of its plate and 20 LDU a stud of it, down or up."""
    spec = spec_of(name)
    lo, hi = flatten(library, name).bounds()
    (ex0, ey0, ez0), (ex1, ey1, ez1) = extent(spec)
    assert (lo.x, lo.y, lo.z) == pytest.approx((ex0, ey0, ez0), abs=0.01)
    assert (hi.x, hi.y, hi.z) == pytest.approx((ex1, ey1, ez1), abs=0.01)


def _studs(library: Library, name: str):
    return [c for c in extract(library, name) if c.kind.value == "stud"]


def _gripping(library: Library, name: str):
    """Tubes, and the pins of a part one stud wide: both are TUBE."""
    return [c for c in extract(library, name) if c.kind.value == "tube"]


def _top_studs(library: Library, name: str):
    return [c for c in _studs(library, name) if c.axis.y < -0.99]


@pytest.mark.parametrize("name", FILES)
def test_studs_sit_on_the_grid_and_point_up(library: Library, name: str) -> None:
    spec = spec_of(name)
    width, depth = footprint(spec)
    studs = _top_studs(library, name)
    # Every other stud is on a side or an upright, and only where the
    # part has one.
    if not spec["sides"] and spec["family"] != "bracket":
        assert len(studs) == len(_studs(library, name))
    for stud in studs:
        assert stud.position.y == pytest.approx(0.0)
        assert (stud.axis.x, stud.axis.y, stud.axis.z) == pytest.approx((0.0, -1.0, 0.0))
        # Half a pitch in from an edge, then whole pitches.
        assert ((stud.position.x + width / 2 - 10.0) / 20.0) % 1 == pytest.approx(0.0, abs=1e-6)
        assert ((stud.position.z + depth / 2 - 10.0) / 20.0) % 1 == pytest.approx(0.0, abs=1e-6)
        assert abs(stud.position.x) < width / 2 and abs(stud.position.z) < depth / 2
    if spec["studs"] == "no":
        assert not studs
    elif spec["family"] in ("brick", "inverted", "bracket", "technic"):
        assert len(studs) == spec["across"] * spec["deep"]
    elif spec["family"] in ("slope", "curved"):
        # Only the flat rows: the face falls over `run` of them.
        assert len(studs) == spec["across"] * (spec["deep"] - spec["run"])
        flat_from = depth / 2 - (spec["deep"] - spec["run"]) * 20.0
        assert all(s.position.z > flat_from for s in studs)


def _side_rows(spec: dict) -> list[float]:
    """Side studs stand 10 LDU under the top, as 87087's does, so a plate
    on one lines up with the top; then every 20 down while a row fits."""
    h = spec["plates"] * 8.0
    return [10.0 + 20.0 * k for k in range(8) if 20.0 * k + 20.0 <= h]


@pytest.mark.parametrize("name", [n for n in FILES
                                  if spec_of(n)["sides"] or spec_of(n)["family"] == "bracket"])
def test_studs_on_a_side_point_out_of_it_on_the_grid(library: Library, name: str) -> None:
    """A brick's side studs stand on the face they are named for, pointing
    straight out of it, one per stud of the top along that face, in rows
    20 LDU apart starting 10 under the top. A bracket's stand on its
    upright's face, 4 LDU in front of the plate, 10 LDU from the plate's
    top hanging down or its bottom standing up (99781, 99780)."""
    spec = spec_of(name)
    width, depth = footprint(spec)
    found = sorted((round(c.position.x, 3) + 0.0, round(c.position.y, 3) + 0.0,
                    round(c.position.z, 3) + 0.0, round(c.axis.x, 3) + 0.0,
                    round(c.axis.y, 3) + 0.0, round(c.axis.z, 3) + 0.0)
                   for c in _studs(library, name) if c.axis.y > -0.99)
    columns_x = [-width / 2 + 10.0 + 20.0 * i for i in range(int(width / 20))]
    columns_z = [-depth / 2 + 10.0 + 20.0 * j for j in range(int(depth / 20))]
    expected = []
    if spec["family"] == "bracket":
        face = -depth / 2 - 4.0
        rows = [10.0 + 20.0 * k for k in range(spec["rise"])] if spec["way"] == "down" \
            else [8.0 - 10.0 - 20.0 * k for k in range(spec["rise"])]
        expected = [(x, y, face, 0.0, 0.0, -1.0) for x in columns_x for y in rows]
    else:
        for y in _side_rows(spec):
            if "f" in spec["sides"]:
                expected += [(x, y, -depth / 2, 0.0, 0.0, -1.0) for x in columns_x]
            if "b" in spec["sides"]:
                expected += [(x, y, depth / 2, 0.0, 0.0, 1.0) for x in columns_x]
            if "l" in spec["sides"]:
                expected += [(-width / 2, y, z, -1.0, 0.0, 0.0) for z in columns_z]
            if "r" in spec["sides"]:
                expected += [(width / 2, y, z, 1.0, 0.0, 0.0) for z in columns_z]
    assert found and found == sorted(tuple(round(v, 3) + 0.0 for v in e) for e in expected)


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
    if spec["family"] == "technic":
        deep = 1
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


@pytest.mark.parametrize("name", [n for n in FILES if spec_of(n)["family"] == "curved"])
def test_a_curved_slope_is_four_ldu_thick_under_its_curve(library: Library, name: str) -> None:
    """Under the curve the plastic is the four LDU between the face and the
    cavity's ceiling, which follows it down; the foot is a 4 LDU lip."""
    spec = spec_of(name)
    mesh = flatten(library, name)
    width, depth = footprint(spec)
    h = spec["plates"] * 8.0
    front = -depth / 2
    edge = depth / 2 - (spec["deep"] - spec["run"]) * 20.0
    x = -width / 2 + 5.3
    for z in (front + 8.7, (front + edge) / 2 + 0.3, edge - 4.6):
        if z <= front + 4.0 or z >= depth / 2 - 4.0:
            continue
        spans = stab(mesh, x, z)
        assert spans[0][0] == pytest.approx(curve_y(spec, z), abs=0.2), (name, z, spans)
        # Four LDU between the face's chords and the ceiling's.
        assert spans[0][1] - spans[0][0] == pytest.approx(4.0, abs=0.1), (name, z, spans)
    spans = stab(mesh, x, front + 1.3)
    assert spans[-1][1] == pytest.approx(h)


@pytest.mark.parametrize("name", [n for n in FILES if spec_of(n)["family"] == "bracket"])
def test_a_bracket_is_a_plate_and_a_four_ldu_upright(library: Library, name: str) -> None:
    """Through its plate, 8 LDU of plastic with a 4 LDU top over a cavity;
    through its upright, 4 LDU thick in front of the plate, solid for the
    whole of the upright: 20 LDU a stud of it, hanging from the plate's
    top or standing on its bottom."""
    spec = spec_of(name)
    mesh = flatten(library, name)
    width, depth = footprint(spec)
    rise = spec["rise"] * 20.0
    x = -width / 2 + 5.3
    for into in (0.43, 2.07, 3.61):
        upright = stab(mesh, x, -depth / 2 - into)
        assert upright == ([(0.0, rise)] if spec["way"] == "down" else [(8.0 - rise, 8.0)])
    # Inside the plate's back wall, and past it over the cavity.
    assert stab(mesh, x, depth / 2 - 2.07) == [(0.0, 8.0)]
    assert stab(mesh, x, depth / 2 - 4.31)[0] == (0.0, 4.0)


def pierce(mesh: Mesh, x: float, y: float) -> list[tuple[float, int]]:
    """Every face a line along Z through (x, y) crosses, as (z, +1 facing
    -Z or -1 facing +Z), nearest -Z first: stab() turned on its side."""
    hits: list[tuple[float, int]] = []
    for t in mesh.triangles:
        d = (t.b.x - t.a.x) * (t.c.y - t.a.y) - (t.b.y - t.a.y) * (t.c.x - t.a.x)
        if abs(d) < 1e-9:
            continue
        w0 = ((t.b.x - x) * (t.c.y - y) - (t.b.y - y) * (t.c.x - x)) / d
        w1 = ((t.c.x - x) * (t.a.y - y) - (t.c.y - y) * (t.a.x - x)) / d
        if min(w0, w1, 1.0 - w0 - w1) < 0.0:
            continue
        z = w0 * t.a.z + w1 * t.b.z + (1.0 - w0 - w1) * t.c.z
        hits.append((round(z, 3), 1 if t.normal().z < 0 else -1))
    return sorted(hits)


@pytest.mark.parametrize("name", [n for n in FILES if spec_of(n)["family"] == "technic"])
def test_a_technic_brick_has_a_hole_a_pin_goes_through(library: Library, name: str) -> None:
    """A hole between every two studs (under the stud of a 1 x 1), 10 LDU
    under the top, running through front to back: one pin hole where each
    face's peghole was, a 12 LDU bore nothing crosses, a 16 LDU mouth 2
    deep in each face, and plastic round it — as 3700 has."""
    spec = spec_of(name)
    mesh = flatten(library, name)
    n = spec["across"]
    holes = [0.0] if n == 1 else [-n * 10.0 + 20.0 * i for i in range(1, n)]
    found = sorted((round(c.position.x, 3) + 0.0, round(c.position.y, 3) + 0.0,
                    round(c.position.z, 3) + 0.0)
                   for c in extract(library, name) if c.kind.value == "pin_hole")
    assert found == [(c, 10.0, 0.0) for c in holes]
    for c in holes:
        # Down the middle of the hole: nothing at all.
        assert pierce(mesh, c + 0.31, 10.0 + 0.27) == []
        # Between the bore and the mouth: plastic from one mouth's floor
        # to the other's.
        between = pierce(mesh, c + 0.31, 10.0 + 6.9)
        assert between[0][0] == pytest.approx(-8.0, abs=0.01)
        assert between[-1][0] == pytest.approx(8.0, abs=0.01)
        # Past the mouth: the whole depth.
        past = pierce(mesh, c + 0.31, 10.0 + 8.6)
        assert (past[0][0], past[-1][0]) == (-10.0, 10.0)
        # From above, beside the pin under the hole (4.7 off its middle,
        # inside the bore's 6): the top down to the bore, the bore empty,
        # then plastic under it to the cavity at 18. Not down the middle:
        # a pin is an open tube stood on the cavity's ceiling, as a brick's
        # tubes are, so a line down its middle never comes out of it.
        spans = sorted(stab(mesh, c + 4.7, 0.29))
        assert len(spans) == 2, (name, spans)
        (top, over_bore), (under_bore, floor) = spans
        assert top == 0.0 and 5.5 < over_bore < 7.0, (name, spans)
        assert 13.0 < under_bore < 14.5 and floor == 18.0, (name, spans)


@needs_numpy
@pytest.mark.parametrize("name", [n for n in FILES if spec_of(n)["family"] == "technic"])
def test_a_technic_brick_cover_leaves_its_holes_open(name: str) -> None:
    """The collision cover the pipeline makes has no cell in a hole's bore,
    or a pin pushed into it would be refused as an overlap."""
    kept = json.loads((FIXTURES / "pipeline.json").read_text())["parts"]
    part = kept[name[:-4]]
    holes = [c for c in part["connectors"] if c[0] == "pin_hole"]
    assert holes
    for hole in holes:
        hx, hy, _hz = hole[2]
        for x0, y0, _z0, sx, sy, _sz in part["boxes"]:
            for cx in range(x0, x0 + sx):
                for cy in range(y0, y0 + sy):
                    px, py = (cx + 0.5) * 2.0, (cy + 0.5) * 2.0
                    assert (px - hx) ** 2 + (py - hy) ** 2 > 25.0, (name, hole)


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
    ("bw-b1x1x3-sf.dat", "87087.dat", 0.0, "top"),   # Brick 1 x 1 with Stud on 1 Side
    ("bw-b1x4x3-sf.dat", "30414.dat", 0.0, "top"),   # Brick 1 x 4 with Studs on Side
    ("bw-k1x2x1d.dat", "99781.dat", 0.0, "top"),     # Bracket 1 x 2 - 1 x 2 Down
    ("bw-k1x2x1u.dat", "99780.dat", 0.0, "top"),     # Bracket 1 x 2 - 1 x 2 Up
    ("bw-k1x2x2d.dat", "44728.dat", 0.0, "top"),     # Bracket 1 x 2 - 2 x 2 Down
    ("bw-h1x1.dat", "6541.dat", 0.0, "top"),         # Technic Brick 1 x 1 with Hole
    ("bw-h1x2.dat", "3700.dat", 0.0, "top"),         # Technic Brick 1 x 2 with Hole
    ("bw-h1x4.dat", "3701.dat", 0.0, "top"),         # Technic Brick 1 x 4 with Holes
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
            # The highest plastic, or the lowest: a library side stud is
            # hollow, so a line through it crosses it twice.
            if surface == "top":
                assert min(s[0] for s in mine) == pytest.approx(
                    min(s[0] for s in real_spans), abs=0.02), (x, z)
            else:
                assert max(s[1] for s in mine) == pytest.approx(
                    max(s[1] for s in real_spans), abs=0.02), (x, z)
    # Where on the top, not how high: 3660a's front studs stand in its
    # coring, their bases 4 LDU down.
    def top_studs(name: str, dz: float = 0.0) -> list[tuple[float, float]]:
        return sorted((round(c.position.x, 2), round(c.position.z + dz, 2))
                      for c in _studs(library, name) if c.axis.y < -0.99)
    assert top_studs(made, shift) == top_studs(real)

    # And those on a side or an upright: where, and which way.
    def side_studs(name: str, dz: float = 0.0) -> list[tuple]:
        return sorted((round(c.position.x, 2) + 0.0, round(c.position.y, 2) + 0.0,
                       round(c.position.z + dz, 2) + 0.0, round(c.axis.x, 3) + 0.0,
                       round(c.axis.y, 3) + 0.0, round(c.axis.z, 3) + 0.0)
                      for c in _studs(library, name) if c.axis.y > -0.99)
    assert side_studs(made, shift) == side_studs(real)

    def holes(name: str) -> list[tuple]:
        return sorted((round(c.position.x, 2) + 0.0, round(c.position.y, 2) + 0.0,
                       round(c.position.z, 2) + 0.0)
                      for c in extract(library, name) if c.kind.value == "pin_hole")
    assert holes(made) == holes(real)

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
