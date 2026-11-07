#!/usr/bin/env python3
"""Train track ends, assets/ldraw/track_ends.json, measured from the parts.

    tools/track_ends.py write     measure every track in the catalogue, write the table
    tools/track_ends.py check     measure again: exit 1 if the table is not what the
                                  parts measure, or a check below fails
    tools/track_ends.py show ID   one part's ends as measured, and why

src/assembly/track_snap.gd joins a track in hand to a free end of a track
down by this table: where each end is, which way it faces, what kind of
joint it is, and for rails laid on sleepers, whether a sleeper is under it.
Nothing in it is typed by hand. Each family of track joins one way, and the
ends are read off the geometry that does the joining:

  clip     9V, the 6 studs wide plastic track (the RC trains' and every city
           train's since 2006) and the 4 studs wide: two tracks lock by a tab
           on each that goes into the other's slot. An end is the face the
           next track's face meets: the largest face square to the track at
           its end, with the tab reaching 6 to 12 LDU past it.
  rails    12V and 4.5V: two rails meet two rails end to end, on a sleeper
           plate that spans the joint. An end is the plane where both rails
           end: a face square to the track, at its end, cut into two rails'
           ends a gauge apart. A sleeper part of the piece's own under it is
           a sleeper at that end.
  face     the roller coaster: a track's end face meets the next one's
           flush. An end is the largest upright face at the track's end,
           nothing past it.

An end's place is the middle of that face across the track, at the face's
foot; its direction is the face's, out of the track. Two ends of one kind
join when their places meet and their directions oppose. The kind says the
joint by what was measured (the face's width, a tab's depth, the gauge), so
a 9V track and a 6 wide one, whose ends measure the same, join.

Axes are the app's (+Y up): LDraw's with y and z turned round, as
assets/ldraw/gears.json's are.
"""

from __future__ import annotations

import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.library import Library  # noqa: E402
from ldraw.parser import Matrix, Polygon, SubfileRef, Vec3  # noqa: E402

TABLE = ROOT / "assets" / "ldraw" / "track_ends.json"
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
LDRAW = ROOT / "vendor" / "ldraw"

## Each family: (its name, the part names it takes, how its ends join).
FAMILIES: list[tuple[str, re.Pattern, str]] = [
    ("9V", re.compile(r"^Train Track\s+9V\b"), "clip"),
    ("6 wide", re.compile(r"^Train Track 6 Studs Wide\b"), "clip"),
    ("4 wide", re.compile(r"^Train Track 4 Studs Wide\b"), "clip"),
    ("12V", re.compile(r"^Train Track 12V\b"), "rails"),
    ("4.5V", re.compile(r"^Train Track\s+4\.5V\b"), "rails"),
    ("roller coaster", re.compile(r"^Train Track Roller Coaster\b"), "face"),
]
## Parts a family's name takes that are not a length of track: what goes on
## one, between its rails, or under them.
NOT_TRACK = re.compile(r"Lever|Sleeper|Insert|Cable|Connector|Contact|Rail (?:Straight|Curved)"
                       r"|Rail Slotted|Rail Tapered|Tapered Rail|Slotted Rail")
## Train parts with "Track" in their names left to another time, and why.
OTHER_TRACK = re.compile(r"^(?:Duplo Train Track|Monorail Track|Train Track Flexible|"
                         r"Train Track Rail|Train Track Tapered Rail|Train Track Slotted Rail|"
                         r"Track with Gear Rack|Duplo Track)")
## How far a tab reaches past a clip end's face, LDU: the 9V's is 9, the
## crossing's 10.
TAB = (6.0, 12.0)
## A rail end's face may have the 12V's centre rail reach this far past it
## (its insert is 336 long between rails of 320).
RAIL_PAST = 12.0
## A face end has nothing past it but this, LDU.
FLUSH = 0.5
## Faces whose normals are within this of upright-square are one plane's.
ANGLE_STEP = 0.25
## A part is one of these when the measure finds its ends; a name that says
## crossing or point says how many.
SLEEPER_NAME = re.compile(r"Sleeper|^Plate\s+2 x\s+[68]$")
## A sleeper is under an end when its middle is this near the end, across.
SLEEPER_NEAR = 25.0


@dataclass
class Poly:
    points: tuple
    # The part files it is drawn under, outermost first, as (name,
    # description): the root itself is not in it.
    parts: tuple


@dataclass
class Placed:
    """A part file drawn inside another: a sleeper, a lever, a rail."""
    name: str
    description: str
    matrix: Matrix
    color: int = 16


@dataclass
class Shape:
    polys: list = field(default_factory=list)
    placed: list = field(default_factory=list)


_library: Library | None = None


def library() -> Library:
    global _library
    if _library is None:
        _library = Library(LDRAW)
    return _library


def _is_part_file(name: str) -> bool:
    """A part (or a part's shortcut), not a primitive or a subpart."""
    found = library().get(name)
    if found is None:
        return False
    kind = found.part_type.lower()
    return "part" in kind and "subpart" not in kind or "shortcut" in kind


def flatten(name: str) -> Shape:
    shape = Shape()
    _walk(name, Matrix.identity(), (), shape, 0)
    return shape


def _walk(name: str, m: Matrix, parts: tuple, shape: Shape, depth: int) -> None:
    found = library().get(name)
    if found is None or depth > 40:
        return
    for command in found.commands:
        if isinstance(command, SubfileRef):
            child = m @ command.matrix
            inner = parts
            if depth < 6 and _is_part_file(command.filename):
                sub = library().get(command.filename)
                description = sub.description if sub is not None else ""
                if sub is not None and sub.moved_to:
                    moved = library().get(sub.moved_to + ".dat")
                    description = moved.description if moved is not None else description
                inner = parts + ((command.filename, description),)
                if not parts:
                    shape.placed.append(Placed(command.filename, description, child,
                                               command.color))
            _walk(command.filename, child, inner, shape, depth + 1)
        elif isinstance(command, Polygon):
            shape.polys.append(Poly(tuple(m.transform_point(p) for p in command.points), parts))


def family_of(name: str) -> tuple[str, str] | None:
    for family, pattern, joins in FAMILIES:
        if pattern.search(name):
            return family, joins
    return None


def _normal_area(points: tuple) -> tuple[float, Vec3 | None]:
    a, b, c = points[0], points[1], points[2]
    n = (b - a).cross(c - a)
    area = n.length() / 2.0
    if len(points) == 4:
        area += (c - a).cross(points[3] - a).length() / 2.0
    if n.length() < 1e-9:
        return 0.0, None
    return area, n * (1.0 / n.length())


def _in_body(poly: Poly, joins: str) -> bool:
    """Whether a polygon is the track's own: not a lever, a signal, a gate,
    a sleeper or a centre rail drawn with it."""
    for _name, description in poly.parts:
        if "Track" not in description and "Rail" not in description:
            return False
        if re.search(r"Lever|Sleeper|Signal|Gate|Cable|Connector", description):
            return False
        if joins == "rails" and "Insert" in description:
            return False
    return True


@dataclass
class Plane:
    normal: Vec3
    offset: float
    area: float
    polys: list
    past: float = 0.0       # how far the body reaches past it


def _upright_planes(polys: list[Poly]) -> list[Plane]:
    """Every upright plane faces lie in, by the way they face (to a quarter
    degree) and where (to a tenth of an LDU), with the area on each. A
    face's winding does not say which way is out: a part drawn mirrored has
    its faces wound the other way (25061's second end), so a plane faces
    out on the side the track does not reach past it ([method _orient])."""
    groups: dict = {}
    for poly in polys:
        area, n = _normal_area(poly.points)
        if n is None or area < 1e-6 or abs(n.y) > 0.02:
            continue
        angle = round(math.degrees(math.atan2(n.z, n.x)) / ANGLE_STEP) * ANGLE_STEP
        if angle < -90.0 or angle >= 90.0:
            n = n * -1.0
            angle = round(math.degrees(math.atan2(n.z, n.x)) / ANGLE_STEP) * ANGLE_STEP
        offset = n.dot(poly.points[0])
        key = (angle, round(offset, 1))
        group = groups.setdefault(key, [0.0, Vec3(0.0, 0.0, 0.0), []])
        group[0] += area
        group[1] = group[1] + n * area
        group[2].append(poly)
    planes: list[Plane] = []
    for (angle, _offset), (area, summed, members) in groups.items():
        n = summed * (1.0 / summed.length())
        n = Vec3(n.x, 0.0, n.z)
        n = n * (1.0 / n.length())
        verts = [v for p in members for v in p.points]
        offset = sum(n.dot(v) for v in verts) / len(verts)
        planes.append(Plane(n, offset, area, members))
    return planes


def _orient(plane: Plane, flat: list[tuple[float, float]]) -> None:
    """Face [param plane] out of the track: the way it reaches less past it.
    [param flat] is the track's points seen from above, (x, z), each once."""
    ahead, behind = _past(plane, flat)
    if ahead <= behind:
        plane.past = ahead
    else:
        plane.normal = plane.normal * -1.0
        plane.offset = -plane.offset
        plane.past = behind


## A face drawn this near a whole quarter degree is drawn at it, degrees:
## the 12V curve's rail ends are 0.003 off its 11.25, which sixteen curves
## to a circle carry to a gap of 0.7 LDU.
SQUARE_WITHIN = 0.01


def _square(n: Vec3) -> Vec3:
    angle = math.degrees(math.atan2(n.z, n.x))
    nearest = round(angle / ANGLE_STEP) * ANGLE_STEP
    if abs(angle - nearest) > SQUARE_WITHIN:
        return n
    return Vec3(math.cos(math.radians(nearest)), 0.0, math.sin(math.radians(nearest)))


def _lateral(n: Vec3) -> Vec3:
    return Vec3(-n.z, 0.0, n.x)


def _clusters(values: list[float], gap: float) -> list[tuple[float, float]]:
    """Runs of [param values] with no gap wider than [param gap] in them."""
    out: list[tuple[float, float]] = []
    for v in sorted(values):
        if out and v - out[-1][1] <= gap:
            out[-1] = (out[-1][0], v)
        else:
            out.append((v, v))
    return out


@dataclass
class End:
    at: Vec3            # LDraw's axes
    out: Vec3
    kind: str
    sleeper: bool | None = None
    how: str = ""


def _middle_across(normal: Vec3, offset: float, face: list[Vec3], verts: list[Vec3]) -> float:
    """The middle of the track across, at an end: of what the track has
    within a tab's depth behind the end's face, as far across as the face
    and a little more. A face is often not the middle of its end (a clip's
    slot is on one side, its tab on the other); the track there is."""
    lat = _lateral(normal)
    across = [lat.dot(v) for v in face]
    lo, hi = min(across) - 20.0, max(across) + 20.0
    near = [lat.dot(v) for v in verts
            if offset - TAB[1] <= normal.dot(v) <= offset + 0.01 and lo <= lat.dot(v) <= hi]
    return (min(near) + max(near)) / 2.0


def _end_at(normal: Vec3, offset: float, face: list[Vec3], verts: list[Vec3],
            middle: float | None = None) -> Vec3:
    lat = _lateral(normal)
    if middle is None:
        middle = _middle_across(normal, offset, face, verts)
    foot = max(v.y for v in face)          # LDraw's y points down
    point = normal * offset + lat * middle
    return Vec3(point.x, foot, point.z)


def _past(plane: Plane, flat: list[tuple[float, float]]) -> tuple[float, float]:
    """How far the track reaches past a plane in front of its face, and
    past it behind, the plane turned round: a switch's straight end has its
    branch further on beside it. Both from one pass over the points: two
    passes over every corner of every face, each drawn three or four times,
    were 12 of the 16 s a points part took to measure (2026-11-07)."""
    lat = _lateral(plane.normal)
    across = [lat.dot(v) for p in plane.polys for v in p.points]
    lo, hi = min(across) - 10.0, max(across) + 10.0
    n = plane.normal
    reach = [n.x * x + n.z * z for x, z in flat if lo <= lat.x * x + lat.z * z <= hi]
    return max(reach) - plane.offset, plane.offset - min(reach)


def _width(plane: Plane) -> float:
    lat = _lateral(plane.normal)
    across = [lat.dot(v) for p in plane.polys for v in p.points]
    return max(across) - min(across)


def _tab(plane: Plane, verts: list[Vec3], middle: float) -> tuple[int, int]:
    """Where a clip end's tab is across the track, from its middle, LDU."""
    lat = _lateral(plane.normal)
    across = [lat.dot(v) for p in plane.polys for v in p.points]
    lo, hi = min(across) - 10.0, max(across) + 10.0
    beyond = [lat.dot(v) - middle for v in verts
              if plane.normal.dot(v) > plane.offset + 7.0 and lo <= lat.dot(v) <= hi]
    return round(min(beyond)), round(max(beyond))


@dataclass
class RailFace:
    angle: float
    normal: Vec3
    offset: float
    across: float          # its middle across
    face: list


## A rail's tapered tip reaches this far past the face its foot ends in, LDU
## (the 4.5V tapered crossing's, 156 to 160).
RAIL_TIP = 4.5


def _reach(rail: RailFace, verts: list[Vec3]) -> float:
    """How far a rail reaches at its end: its tip, past the face it ends in."""
    lat = _lateral(rail.normal)
    across = [lat.dot(v) for v in rail.face]
    lo, hi = min(across) - 0.01, max(across) + 0.01
    return max(rail.normal.dot(v) for v in verts
               if lo <= lat.dot(v) <= hi
               and rail.offset - 0.01 <= rail.normal.dot(v) <= rail.offset + RAIL_TIP)


def _rail_faces(planes: list[Plane]) -> list[RailFace]:
    """The ends of single rails: faces square to a rail at the track's end,
    no wider than a rail."""
    out: list[RailFace] = []
    for pl in planes:
        if pl.past > RAIL_PAST or pl.area < 20.0:
            continue
        lat = _lateral(pl.normal)
        verts = [v for p in pl.polys for v in p.points]
        for lo, hi in _clusters([lat.dot(v) for v in verts], 15.0):
            if hi - lo > 30.0 or hi - lo < 8.0:
                continue
            face = [v for v in verts if lo - 1e-6 <= lat.dot(v) <= hi + 1e-6]
            out.append(RailFace(math.degrees(math.atan2(pl.normal.z, pl.normal.x)), pl.normal,
                                pl.offset, (lo + hi) / 2.0, face))
    return out


def measure(part: str, joins: str, rail_gauge: float | None = None
            ) -> tuple[list[End], list[Placed], str]:
    """A part's ends by its family's joint, the parts drawn in it, and how
    they were found (or why none were)."""
    shape = flatten(part + ".dat")
    body = [p for p in shape.polys if _in_body(p, joins)]
    if not body:
        return [], shape.placed, "nothing of the track itself is drawn in it"
    verts = [v for p in body for v in p.points]
    planes = [pl for pl in _upright_planes(body) if pl.area >= 20.0]
    flat = list(dict.fromkeys((v.x, v.z) for v in verts))
    for plane in planes:
        _orient(plane, flat)
    ends: list[End] = []
    if joins in ("clip", "face"):
        if joins == "clip":
            near = [pl for pl in planes if TAB[0] <= pl.past <= TAB[1] and pl.area > 50.0]
        else:
            # The largest flush face each way the track faces.
            near = []
            for pl in sorted((pl for pl in planes if pl.past <= FLUSH and pl.area > 50.0),
                             key=lambda pl: -pl.area):
                if not any(pl.normal.dot(o.normal) > 0.9999 for o in near):
                    near.append(pl)
        found: list[Plane] = []
        if near:
            most = max(pl.area for pl in near)
            found = [pl for pl in near if pl.area >= (0.6 if joins == "clip" else 0.2) * most]
        for plane in found:
            face = [v for p in plane.polys for v in p.points]
            middle = _middle_across(plane.normal, plane.offset, face, verts)
            if joins == "clip":
                tab = _tab(plane, verts, middle)
                kind = "clip %d" % (round((tab[1] - tab[0]) / 10.0) * 10)
                how = "face %.0f wide, a tab %.1f past it from %d to %d across" % (
                    _width(plane), plane.past, tab[0], tab[1])
            else:
                kind = "face %d" % round(_width(plane))
                how = "face %.0f wide, flush" % _width(plane)
            ends.append(End(_end_at(plane.normal, plane.offset, face, verts, middle),
                            plane.normal, kind, None, how))
    else:
        rails = _rail_faces(planes)
        for i, one in enumerate(rails):
            for other in rails[i + 1:]:
                if one.normal.dot(other.normal) < 0.99999 or abs(one.offset - other.offset) > 5.0:
                    continue
                gauge = abs(one.across - other.across)
                if not 60.0 <= gauge <= 140.0 or rail_gauge is not None \
                        and abs(gauge - rail_gauge) > 1.0:
                    continue
                reach = (_reach(one, verts), _reach(other, verts))
                middle = (one.across + other.across) / 2.0
                at = _end_at(one.normal, max(reach), one.face + other.face, verts, middle)
                ends.append(End(at, one.normal, "rails %d" % round(gauge), None,
                                "two rails' ends %.1f apart%s" % (
                                    gauge, "" if abs(reach[0] - reach[1]) < 0.1 else
                                    ", one %.1f short" % abs(reach[0] - reach[1]))))
    # One end to a place: faces at an end a rail's tip apart are one end,
    # the furthest.
    ends.sort(key=lambda e: -e.out.dot(e.at))
    unique: list[End] = []
    for end in ends:
        if not any(end.out.dot(o.out) > 0.99 and abs(o.out.dot(o.at) - o.out.dot(end.at)) < 5.0
                   and abs(_lateral(o.out).dot(end.at - o.at)) < 2.0 for o in unique):
            unique.append(end)
    for end in unique:
        squared = _square(end.out)
        if squared is not end.out:
            end.how += ", drawn %.4f degrees off the quarter degree" % math.degrees(
                math.acos(max(-1.0, min(1.0, squared.dot(end.out)))))
            end.out = squared
    if joins == "rails":
        for end in unique:
            end.sleeper = any(_under(end, placed) for placed in shape.placed
                              if SLEEPER_NAME.search(placed.description))
    return unique, shape.placed, ""


def _under(end: End, placed: Placed) -> bool:
    m = placed.matrix
    middle = Vec3(m.transform_point(Vec3(0.0, 0.0, 0.0)).x, 0.0,
                  m.transform_point(Vec3(0.0, 0.0, 0.0)).z)
    return (middle - Vec3(end.at.x, 0.0, end.at.z)).length() <= SLEEPER_NEAR


def expected_ends(name: str) -> int:
    if "Crossing" in name:
        return 4
    if re.search(r"\bPoints?\b|\bSwitch\b", name) and "Lever" not in name:
        return 3
    return 2


def _app(v: Vec3, digits: int = 4) -> list[float]:
    """LDraw's axes to the app's: y and z turned round."""
    return [round(v.x, digits) + 0.0, round(-v.y, digits) + 0.0, round(-v.z, digits) + 0.0]


def _frame(end: End) -> list[list[float]]:
    """An end's frame in the app's axes: x out of the track, y up, z across."""
    out = _app(end.out, 7)
    return [out, [0.0, 1.0, 0.0], [-out[2], 0.0, out[0]]]


def _sleeper_entry(end: End, placed: Placed) -> dict:
    """A sleeper part's place in its end's frame (app axes), as 12 numbers:
    the basis' columns x, y, z and the origin."""
    m = placed.matrix
    c = [[1.0, 0.0, 0.0], [0.0, -1.0, 0.0], [0.0, 0.0, -1.0]]
    rows = [[m.a, m.b, m.c], [m.d, m.e, m.f], [m.g, m.h, m.i]]
    # The sleeper's basis in app axes: C R C.
    r = [[sum(c[i][k] * rows[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    r = [[sum(r[i][k] * c[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    origin = _app(m.transform_point(Vec3(0.0, 0.0, 0.0)))
    at = _app(end.at)
    f = _frame(end)               # columns x, y, z of the end's frame
    d = [origin[i] - at[i] for i in range(3)]
    local_origin = [sum(f[k][i] * d[i] for i in range(3)) for k in range(3)]
    columns = []
    for j in range(3):
        col = [r[i][j] for i in range(3)]
        columns.append([round(sum(f[k][i] * col[i] for i in range(3)), 5) + 0.0 for k in range(3)])
    return {"color": placed.color, "basis": columns,
            "origin": [round(v, 4) + 0.0 for v in local_origin]}


def build(catalogue: dict) -> dict:
    tracks: dict = {}
    left_out: dict = {}
    sleepers: dict = {}
    sleeper_votes: dict = {}
    candidates = candidates_of(catalogue, left_out)
    gauges = rail_gauges(candidates)
    for part, name, family_name, joins in candidates:
        ends, placed, why = measure(part, joins, gauges.get(family_name))
        wanted = expected_ends(name)
        if why or len(ends) != wanted:
            left_out[part] = why or (
                "measured %d ends where its name says %d: %s" % (
                    len(ends), wanted, "; ".join(e.how for e in ends) or "no end face found"))
            continue
        tracks[part] = {"family": family_name, "joins": joins, "ends": [
            dict({"at": _app(e.at), "out": _app(e.out, 7), "kind": e.kind},
                 **({"sleeper": e.sleeper} if e.sleeper is not None else {}))
            for e in ends]}
        if joins == "rails":
            for e in ends:
                for p in placed:
                    if SLEEPER_NAME.search(p.description) and _under(e, p):
                        # A sleeper moved to another number is that one's vote.
                        name = p.name.lower().removesuffix(".dat")
                        resolved = library().get(name + ".dat")
                        if resolved is not None and resolved.moved_to:
                            name = resolved.moved_to.lower().removesuffix(".dat")
                        sleeper_votes.setdefault((e.kind, name), []).append(
                            _sleeper_entry(e, p))
    # Each kind's sleeper: the one most of its tracks are drawn with.
    for (kind, part), entries in sorted(sleeper_votes.items(),
                                        key=lambda kv: (-len(kv[1]), kv[0])):
        if kind in sleepers:
            continue
        sleepers[kind] = dict({"part": part, "found": len(entries)}, **entries[0])
    return {"about": "Train track ends, measured from the parts by tools/track_ends.py. "
                     "App axes (+Y up). Do not edit by hand.",
            "tracks": dict(sorted(tracks.items())),
            "sleepers": sleepers,
            "left_out": dict(sorted(left_out.items()))}


def candidates_of(catalogue: dict, left_out: dict) -> list[tuple[str, str, str, str]]:
    """The catalogue's tracks of a family, as (part, name, family, joins);
    the rest of the track parts into [param left_out], each with why."""
    candidates: list[tuple[str, str, str, str]] = []
    for entry in catalogue["parts"]:
        name: str = entry["name"]
        part: str = entry["id"]
        if name.startswith("~") or entry.get("moved_to"):
            continue
        if OTHER_TRACK.search(name):
            left_out[part] = _other_reason(name)
            continue
        family = family_of(name)
        if family is None:
            continue
        if NOT_TRACK.search(name):
            left_out[part] = "not a length of track: " + _not_track_reason(name)
            continue
        candidates.append((part, name) + family)
    return candidates


def rail_gauges(candidates: list[tuple[str, str, str, str]]) -> dict[str, float]:
    """Each rails family's gauge, as its straights measure it: a point's
    frog and check rails pair up at other gauges, and are not its ends."""
    seen: dict[str, dict[str, int]] = {}
    for part, name, family_name, joins in candidates:
        if joins != "rails" or "Straight" not in name:
            continue
        ends, _placed, why = measure(part, joins)
        if why or len(ends) != 2 or ends[0].kind != ends[1].kind:
            continue
        counts = seen.setdefault(family_name, {})
        counts[ends[0].kind] = counts.get(ends[0].kind, 0) + 1
    return {family: float(max(counts, key=counts.get).split()[1])
            for family, counts in seen.items()}


def _other_reason(name: str) -> str:
    if name.startswith("Duplo"):
        return "Duplo track joins by its own peg, at its own scale: a family of its own, to come"
    if name.startswith("Monorail"):
        return "monorail track: a family of its own (1988-1994), to come"
    if "Flexible" in name:
        return "flexible track bends at each segment's joint, which one fixed end cannot say"
    if "Gear Rack" in name:
        return "a rack railway's track (2026, unofficial): a family of its own, to come"
    return "a single rail: rails are joined as the whole pieces that carry them"


def _not_track_reason(name: str) -> str:
    if "Lever" in name:
        return "a points lever"
    if "Sleeper" in name:
        return "a sleeper, which a rails joint takes"
    if "Insert" in name:
        return "a centre rail, laid between rails"
    return "it goes on a track"


def check(table: dict, fresh: dict) -> list[str]:
    problems: list[str] = []
    if json.dumps(table, sort_keys=True) != json.dumps(fresh, sort_keys=True):
        problems.append("the table is not what the parts measure: tools/track_ends.py write")
    tracks = fresh["tracks"]
    # A straight's ends a whole number of studs apart and opposed.
    for part, spec in tracks.items():
        ends = spec["ends"]
        for end in ends:
            if abs(math.hypot(end["out"][0], end["out"][2]) - 1.0) > 1e-3:
                problems.append(f"{part}: an end's direction is not level")
    for part in ("74746", "53401"):
        if part in tracks:
            a, b = tracks[part]["ends"][:2]
            gap = math.dist(a["at"], b["at"])
            if abs(gap - 320.0) > 0.01 or a["out"][0] * b["out"][0] > -0.999:
                problems.append(f"{part}: a straight's ends are {gap:.3f} apart, not 320")
    # Sixteen curves close a circle.
    for part in ("74747", "53400", "3241ac01", "3229bc01"):
        if part in tracks:
            off = circle_gap(tracks[part]["ends"], 16)
            if off > 0.01:
                problems.append(f"{part}: sixteen curves end {off:.3f} LDU from where they began")
    # Four roller coaster curves of 90 degrees close a circle.
    if "25061" in tracks:
        off = circle_gap(tracks["25061"]["ends"], 4)
        if off > 0.01:
            problems.append(f"25061: four curves end {off:.3f} LDU from where they began")
    return problems


def _turn(out: list[float]) -> float:
    return math.atan2(out[2], out[0])


def circle_gap(ends: list[dict], count: int) -> float:
    """Lay [param count] of a two-ended piece end to end, each by its first
    end on the last one's second, and how far the last one's second end is
    from where the first one's first end was, LDU (top view)."""
    a, b = ends[0], ends[1]
    # The piece's frame: place (x, z) and heading, the first piece at rest.
    x, z, heading = 0.0, 0.0, 0.0
    start = None
    for _ in range(count):
        c, s = math.cos(heading), math.sin(heading)

        def world(p: list[float]) -> tuple[float, float]:
            return x + c * p[0] - s * p[2], z + s * p[0] + c * p[2]
        if start is None:
            start = world(a["at"])
        free = world(b["at"])
        free_out = _turn(b["out"]) + heading
        # The next piece's first end on this one's second: facing it.
        next_heading = free_out + math.pi - _turn(a["out"])
        c2, s2 = math.cos(next_heading), math.sin(next_heading)
        x = free[0] - (c2 * a["at"][0] - s2 * a["at"][2])
        z = free[1] - (s2 * a["at"][0] + c2 * a["at"][2])
        heading = next_heading
    first_again = (x + math.cos(heading) * a["at"][0] - math.sin(heading) * a["at"][2],
                   z + math.sin(heading) * a["at"][0] + math.cos(heading) * a["at"][2])
    return math.dist(first_again, start)


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] not in ("write", "check", "show"):
        print(__doc__)
        return 2
    if argv[1] == "show":
        for part in argv[2:]:
            name = library().get(part + ".dat").description
            family = family_of(name)
            print(part, name, family)
            if family:
                gauge = None
                if family[1] == "rails":
                    gauge = rail_gauges([c for c in candidates_of(
                        json.loads(CATALOGUE.read_text()), {}) if c[2] == family[0]
                        and "Straight" in c[1]]).get(family[0])
                    print("   the family's gauge, as its straights measure it:", gauge)
                ends, placed, why = measure(part, family[1], gauge)
                print("  ", why or "")
                for e in ends:
                    print("   at", _app(e.at), "out", _app(e.out, 7), e.kind, "sleeper", e.sleeper,
                          "|", e.how)
                for p in placed:
                    print("   has", p.name, p.description)
        return 0
    catalogue = json.loads(CATALOGUE.read_text())
    fresh = build(catalogue)
    if argv[1] == "write":
        TABLE.write_text(json.dumps(fresh, indent=1, sort_keys=False) + "\n")
        print(f"track ends: {len(fresh['tracks'])} tracks, {len(fresh['left_out'])} left out, "
              f"sleepers {sorted(fresh['sleepers'])} -> {TABLE.relative_to(ROOT)}")
        problems = check(fresh, fresh)
    else:
        table = json.loads(TABLE.read_text())
        problems = check(table, fresh)
    for problem in problems:
        print("  " + problem)
    print(f"track ends: {len(fresh['tracks'])} tracks, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
