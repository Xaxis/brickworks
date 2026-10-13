"""Deriving where parts can join, from the primitives they are built of.

LDraw stores no connectivity data.  It does not need to: it is a format
for *drawing* bricks, and a renderer never has to know that a stud fits a
tube.  An assembly tool does, so it has to be recovered.

The recovery is more reliable than it sounds, because LDraw part authors
do not model a stud as an anonymous cylinder — they reference the shared
primitive ``stud.dat``.  Walking a part's reference tree and noting every
transform that lands on a known connector primitive therefore recovers the
author's own intent, at full precision, for the whole library at once.
``s/3001s01.dat`` says so directly:

    1 16 30 0 10 1 0 0 0 1 0 0 0 1 stud.dat     <- a stud, at x=30 z=10
    1 16 20 4 0 1 0 0 0 -5 0 0 0 1 stud4.dat    <- a tube, stretched 5x

Two things this deliberately does *not* try to do:

Sockets are not tubes.  The underside tube of a brick sits *between* four
studs and grips them on their outside faces, so a tube's position is not
a place a stud goes.  Where a stud can go is decided by which lattice
cells the part's underside leaves open, which is an occupancy question —
see ``occupancy.py``.  What is recorded here is the mechanism and its
position, which is what tells us an underside exists at all.

Gender is not symmetry.  A stud is male and a tube is female, but a
Technic pin hole accepts a pin from either side and an axle hole accepts
an axle that passes straight through.  Those are recorded as NEUTRAL with
an axis, and the mating rules live with the assembly engine.
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from enum import Enum

from .library import Detail, Library
from .parser import MetaLine, Matrix, SubfileRef, Vec3

# In LDraw, -Y is up.  A stud primitive is modelled pointing that way, so
# transforming this direction by the accumulated matrix gives the real
# outward axis of the connector, including on parts mounted sideways.
_LOCAL_AXIS = Vec3(0.0, -1.0, 0.0)


class ConnectorKind(Enum):
    STUD = "stud"            # the 4.8 mm round boss on top of a brick
    TUBE = "tube"            # the underside receptacle that grips studs
    RIDGE = "ridge"          # underside gripping rib on one-wide parts
    AXLE = "axle"            # Technic cross-section shaft
    AXLE_HOLE = "axle_hole"  # cross-section hole an axle keys into
    PIN = "pin"              # Technic round pin
    PIN_HOLE = "pin_hole"    # round hole a pin rotates in
    CLIP = "clip"
    BAR = "bar"              # the 3.2 mm rod a clip grips
    BALL = "ball"
    SOCKET = "socket"
    SHAFT = "shaft"          # round and solid: a bar, a pin, a turntable's disc
    BORE = "bore"            # round and empty: a clip, a hollow stud, a hinge's eye


class Gender(Enum):
    MALE = "male"
    FEMALE = "female"
    NEUTRAL = "neutral"      # accepts a mate from either side


# Primitive name (without .dat) -> what it means.
#
# Built by reading every primitive description in the library and checking
# the result against parts whose stud count is known by inspection; see
# tests/test_connectivity.py.  Names not listed here are not connectors,
# and the walk recurses through them normally.
_CONNECTORS: dict[str, tuple[ConnectorKind, Gender]] = {}


def _register(names: str, kind: ConnectorKind, gender: Gender) -> None:
    for name in names.split():
        _CONNECTORS[name] = (kind, gender)


# -- studs: the protruding boss ------------------------------------------
# stud-logo* are self-contained (they do not reference stud.dat), so each
# has to be listed or every logo-bearing part loses its studs.
_register(
    """
    stud stud2 stud2a studa stud26 studx studxa studp01 studel studh
    stud-logo stud-logo2 stud-logo3 stud-logo4 stud-logo5
    stud2-logo stud2-logo2 stud2-logo3 stud2-logo4 stud2-logo5
    stud5 stud6 stud6a stud9 stud10 stud13 stud15 stud17 stud17a
    stud2s stud2s2 stud2s2e
    hipstud hipstuda hipstudh clikitsstud
    stud14 stud19 stud20 stud24 primotop
    """,
    ConnectorKind.STUD,
    Gender.MALE,
)

# -- tubes: the underside receptacle -------------------------------------
_register(
    """
    stud3 stud3a stud4 stud4a stud4h stud4o stud4od stud4oda stud4s stud4s2
    stud12 stud16 stud16a stud16od stud18a stud21a stud22a stud23 stud23d
    stud25 stud7 stud7a stud8 stud8a stud8s2 stud11 stud27 stud27a
    stud28 stud28a primobot
    """,
    ConnectorKind.TUBE,
    Gender.FEMALE,
)

_register("ridge ridgea ridgee ridges ridgesu", ConnectorKind.RIDGE, Gender.FEMALE)

# -- Technic -------------------------------------------------------------
# A pin hole takes a pin from either end; an axle hole keys an axle that
# may pass straight through.  Both are NEUTRAL.
#
# Every name below is one that exists in vendor/ldraw/p, classified from
# the primitive's own description line rather than from its filename,
# because the filenames mislead: "axlehol8" is "Technic Axle Perimeter",
# part of a solid axle, and registering it as a hole made every Technic
# axle in the library report an axle_hole it does not have — part 3705,
# a plain Axle 4, came out as {axle: 2, axle_hole: 1}.
#
# The deliberate exclusions are the pieces that are not a place another
# part attaches: a pin's ribs and stop rings (confricrib*, connectring),
# the middles of long pins (confric8, confric9, connectslit*,
# connectcollar*), axle endcaps (axlecap*), and the many "... Side
# Edges" / "... Tooth Outer Edges" / "... Perimeter" sub-primitives that
# draw one hole's detail and would each count as another hole.
_register(
    """
    peghole peghole2 peghole3 peghole4 peghole5 peghole6
    connhole connhol2 connhol3
    beamhole beamhol2
    """,
    ConnectorKind.PIN_HOLE,
    Gender.NEUTRAL,
)
# Pins, friction and plain.  The friction family was represented by two
# of its eleven members, which is why 2780 — the Technic pin with
# friction, one of the most used parts there is — had no connectors at
# all: it is drawn as two mirrored confric5 halves and nothing else.
_register(
    """
    connect connect2 connect3 connect4 connect5 connect6 connect7
    connect8 connect10
    confric confric2 confric3 confric4 confric5 confric6
    confric10 confric11 confric12
    """,
    ConnectorKind.PIN,
    Gender.MALE,
)
# Every primitive whose own description begins "Technic Axle Hole",
# including the tooth, edge and perimeter pieces.  Listing only the
# "closed" ones missed holes outright: part 5686, a crystal with an axle
# hole, draws it from axl3hol3 and axl3hol6 and nothing else, and 83497
# from five such pieces.  One hole's pieces are all coaxial and within a
# brick of each other, so _merge_half_holes collapses them back into the
# one hole they describe.
_register(
    """
    axlehole axlehol0 axlehol2 axlehol3 axlehol4 axlehol5 axlehol6 axlehol7
    axl2hole axl2end axl2ho10 axl2hol2 axl2hol3 axl2hol8 axl2hol9
    axl3hole axl3end axl3ho10 axl3hol2 axl3hol3 axl3hol6 axl3hol8 axl3hol9
    axl4hole axl4hol2 axl4hol3
    axl5end axl5ho10 axl5hol8 axl5hol9
    """,
    ConnectorKind.AXLE_HOLE,
    Gender.NEUTRAL,
)
# And the ones that begin "Technic Axle" without "Hole", which are the
# shaft's own surfaces.  The two families are a letter apart and mean
# opposite things: axlehol8 is "Technic Axle Perimeter" and belongs
# here, axl2hol8 is "Technic Axle Hole Reduced Perimeter" and belongs
# above.  Endcaps are in neither, because axlecaph is "Endcap with Hole"
# and would invent whichever it was filed under.
_register(
    """
    axle axles axlesphe axlebeam axleend axleend2 axleend20
    axlehalfedge axleho10 axleho12 axlehol8 axlehol9
    """,
    ConnectorKind.AXLE,
    Gender.MALE,
)

# -- clips, balls and the bar problem ------------------------------------
_register(
    """
    clip1 clip2 clip3 clip4 clip5 clip6 clip7 clip8 clip9
    clip10 clip11 clip12 clip13 clip14 clip15 clip16
    """,
    ConnectorKind.CLIP,
    Gender.FEMALE,
)
_register("joint8ball", ConnectorKind.BALL, Gender.MALE)
_register("joint8socket1 joint8socket2 joint8socket3", ConnectorKind.SOCKET,
          Gender.FEMALE)

# BAR has no entry, and cannot have one.  There is no bar primitive in
# the library: a bar is a plain 3.2 mm cylinder drawn from 4-4cyli and
# friends, indistinguishable by name from any other cylinder, so finding
# one means measuring a radius rather than reading a filename.  Until
# that is written, a clip has nothing to grip and BAR is never produced.
#
# This was previously registered as "bar bar2 barhole", none of which
# exist, along with "ball balljnt socket socket2" and "axle2" and
# "npeghol1" — nine dead names, so BAR, BALL and SOCKET had never once
# been detected anywhere in the library.
#
# The npeghol* family is gone from PIN_HOLE for a different reason: a
# "Technic Peg Hole Negative" is subtracted geometry, the material a
# hole removes, and it is placed wherever material is missing — not only
# where a pin can go.  Technic Beam 2 draws one at its waist, midway
# between its two real holes, so the beam reported three holes and the
# middle one took no pin.


@dataclass(slots=True)
class Connection:
    """One place on a part where another part can attach."""

    kind: ConnectorKind
    gender: Gender
    position: Vec3   # part-local, LDU
    axis: Vec3       # unit vector pointing out of the part
    source: str      # the primitive that produced it, for debugging
    # A shaft or a bore is a length of round, not a point: position is
    # one end of its axis, axis points along it, and these say how far it
    # runs and how wide it is. Zero for every other kind.
    length: float = 0.0
    radius: float = 0.0
    # How much of a circle a shaft or bore goes round, to at most 1. A
    # curved top's underside is half a bore; a hole is all of one.
    arc: float = 0.0

    def key(self) -> tuple:
        """A rounded identity, for de-duplicating coincident connectors."""
        return (
            self.kind,
            round(self.position.x, 2),
            round(self.position.y, 2),
            round(self.position.z, 2),
            round(self.axis.x, 3),
            round(self.axis.y, 3),
            round(self.axis.z, 3),
            round(self.length, 2),
            round(self.radius, 2),
        )


def extract(
    library: Library,
    name: str,
    *,
    max_depth: int = 64,
) -> list[Connection]:
    """Find every connector on a part, in part-local LDU coordinates.

    Walks the reference tree without building geometry, so it is cheap
    enough to run over the whole library.
    """
    found: list[Connection] = []
    _walk(library, name, Matrix.identity(), found, 0, max_depth, set())
    # A part made from another's mesh in the app (src/parts/part_editor.gd)
    # states its connectors in meta lines of its own, after whatever its
    # primitives give; PartForge reads them the same way, in the same place.
    said = said_connectors(library, name)
    found.extend(c for c in said if c.kind not in _ROUND_KINDS)

    # Coincident duplicates happen where a part references both a stud and
    # a decorated version of it at the same spot.
    seen: set[tuple] = set()
    unique: list[Connection] = []
    for connection in found:
        k = connection.key()
        if k not in seen:
            seen.add(k)
            unique.append(connection)

    round_ones = rounds(library, name, max_depth=max_depth)
    holes = _merge_half_holes(_without_axle_edges(unique, round_ones))
    stem = name.rsplit("/", 1)[-1]
    if stem.endswith(".dat"):
        stem = stem[:-4]
    return (holes + _plain_holes(stem, round_ones, holes) + round_ones
            + [c for c in said if c.kind in _ROUND_KINDS])


# -- what the primitives get wrong ------------------------------------------
#
# Three ways the walk above misreads a Technic hole, found by reading gear
# trains off real sets (docs/MECHANISMS.md, section 2): a hole drawn without
# any hole primitive, an axle's own edges taken for a hole, and a hole that
# is a plain cylinder.

## Holes a file draws without a hole primitive, in that file's own frame:
## file -> [(kind, position, axis)]. The walk adds them wherever the file
## is used, so a subpart's hole appears in every part that draws with it.
##
##   3648s02  an eighth of the centre axle hole of the 24 tooth gear,
##            3648a and 3648b (and 24505, an alias of 3648b). Drawn eight
##            times, mirrored, from rectangles and partial cylinders, so
##            the gear read as having no centre at all and floated free of
##            its axle. The eight come out at one point, two ways along z,
##            and _merge_half_holes makes them the one hole they are.
_UNDRAWN: dict[str, list[tuple[ConnectorKind, Vec3, Vec3]]] = {
    "3648s02": [(ConnectorKind.AXLE_HOLE, Vec3(0.0, 0.0, 0.0), Vec3(0.0, 0.0, 1.0))],
}

## The axle-hole primitives that draw only edges: a face's outline where
## an axle meets something. An axle draws them too, where it meets its
## own stop or notch: 32062, the notched axle 2, draws four axlehol2 at
## the ends of its notch, and they merged into a hole at its middle. So
## did 153 more parts: axles with a stop, a stud or a towball, axle pins,
## CV joints, shock absorbers and pneumatic cylinders.
_EDGE_PIECES = frozenset("""
    axlehol2 axlehol3 axl2hol2 axl2hol3 axl2hol9 axl3hol2 axl3hol3 axl3hol9
    axl4hol2 axl4hol3 axl5hol9
""".split())


def _without_axle_edges(connections: list[Connection],
                        round_ones: list[Connection]) -> list[Connection]:
    """Drop the edge pieces of an axle hole that lie on the part's own axle.

    An edge piece on the line of a solid axle the part has, at or between
    its ends, is that axle meeting a face of the part. A real hole there
    would be drawn with more than its edges, and the closed and open hole
    primitives are kept whatever they lie on.
    """
    axles = [c for c in round_ones
             if c.kind is ConnectorKind.SHAFT and c.source in _AXLE_SIDE]
    if not axles:
        return connections
    out: list[Connection] = []
    for connection in connections:
        if connection.kind is ConnectorKind.AXLE_HOLE \
                and connection.source in _EDGE_PIECES \
                and any(_on_round(connection.position, connection.axis, axle, 0.5)
                        for axle in axles):
            continue
        out.append(connection)
    return out


def _on_round(point: Vec3, axis: Vec3, round_one: Connection, slack: float) -> bool:
    """Whether a point lies on a round's line within its length, and the
    axis runs along it."""
    if abs(abs(axis.dot(round_one.axis)) - 1.0) > 0.01:
        return False
    gap = point - round_one.position
    along = gap.dot(round_one.axis)
    across = gap - round_one.axis * along
    return across.length() <= 0.1 and -slack <= along <= round_one.length + slack


## Parts whose Technic holes are plain cylinders: every whole bore they
## have of a Technic hole's size is a pin hole. Without this they had bores
## and no pin hole, and a pin went through them as through nothing in
## particular.
##
##   3709b, 3738, 32001  the Technic plates 2 x 4, 2 x 8 and 2 x 6 with
##                       holes, each hole a cylinder down into the tube
##                       beneath it.
##   6542a               the 16 tooth gear with clutch, its hub a cylinder
##                       from z -8 to 10, where 6542b, the same gear
##                       redrawn, has a peg hole.
##   6573, 4141, 73071   the old differentials, a hub at each end: 6573
##                       with its 16 and 24, 4141 the casing alone, and
##                       73071 the casing with its crown wheel.
##
## A rule for every such bore would not do: 4,970 parts have a whole bore
## of that size with no hole on it, most of them minifigure hands, hair
## and slopes' undersides, and a pin goes in none of them.
_PLAIN_HOLES = frozenset({"3709b", "3738", "32001", "6542a", "6573", "4141", "73071"})
PLAIN_HOLE_RADIUS = 6.0


def _plain_holes(stem: str, round_ones: list[Connection],
                 holes: list[Connection]) -> list[Connection]:
    """A pin hole at the middle of each whole bore of a Technic hole's size,
    for a part in _PLAIN_HOLES, where it has no hole on that line already."""
    if stem not in _PLAIN_HOLES:
        return []
    out: list[Connection] = []
    for bore in round_ones:
        if bore.kind is not ConnectorKind.BORE \
                or abs(bore.radius - PLAIN_HOLE_RADIUS) > 0.1 or bore.arc < 0.99:
            continue
        if any(h.kind in (ConnectorKind.PIN_HOLE, ConnectorKind.AXLE_HOLE)
               and _on_round(h.position, h.axis, bore, 2.0) for h in holes):
            continue
        out.append(Connection(kind=ConnectorKind.PIN_HOLE, gender=Gender.NEUTRAL,
                              position=bore.position + bore.axis * (bore.length * 0.5),
                              axis=bore.axis, source="bore"))
    return out


## The meta line a part carries its own connectors in:
##   0 !BRICKWORKS CONNECTOR kind gender x y z ax ay az [length radius]
## in the part's LDraw axes, a round (shaft or bore) with its length and
## radius. Written by the app for a part changed from another's mesh,
## whose triangles no longer say where its studs and holes are.
CONNECTOR_META = "!BRICKWORKS"
_ROUND_KINDS = (ConnectorKind.SHAFT, ConnectorKind.BORE)


def said_connectors(library: Library, name: str) -> list[Connection]:
    """The connectors a part file states for itself, in file order."""
    ldfile = library.get(name, Detail.STANDARD)
    out: list[Connection] = []
    if ldfile is None:
        return out
    for command in ldfile.commands:
        if not isinstance(command, MetaLine) or command.keyword != CONNECTOR_META:
            continue
        words = command.text.split()
        if len(words) < 9 or words[0].upper() != "CONNECTOR":
            continue
        kind = ConnectorKind(words[1])
        numbers = [float(w) for w in words[3:9]]
        length = radius = 0.0
        if kind in _ROUND_KINDS:
            if len(words) < 11:
                continue
            length, radius = float(words[9]), float(words[10])
        out.append(Connection(
            kind=kind, gender=Gender(words[2]),
            position=Vec3(numbers[0], numbers[1], numbers[2]),
            axis=Vec3(numbers[3], numbers[4], numbers[5]),
            source="meta", length=length, radius=radius))
    return out


def _merge_half_holes(connections: list[Connection]) -> list[Connection]:
    """Collapse the two faces of a Technic hole into the one hole it is.

    A hole through a beam is sometimes drawn as a single ``beamhole`` and
    sometimes as two ``peghole`` halves, one recessed into each face,
    pointing opposite ways.  Both describe one hole, so counting the
    primitives counts the second kind twice — a Technic beam 3 comes out
    with four holes instead of three.

    Two halves belong together when they lie on the same infinite axis
    line, which is identified by the direction (taken to a canonical sign)
    and the foot of the perpendicular from the origin.  Holes spaced along
    a beam sit on parallel but distinct lines, so they are never merged.

    Being on one line is not enough, though, and assuming it was lost
    holes.  Two holes facing each other across a gap — opposite sides of
    a round brick, or of a ring — are exactly coaxial, so "Ring 7 x 7
    with 2 Axle Holes" came out with one hole and a swashplate with four
    pin holes came out with two.  So the faces also have to be close
    enough together to be the same hole: within MERGE_WITHIN along the
    line, which is one brick, where a gap is several.
    """
    mergeable = (ConnectorKind.PIN_HOLE, ConnectorKind.AXLE_HOLE)

    lines: dict[tuple, list[Connection]] = {}
    passthrough: list[Connection] = []
    for connection in connections:
        if connection.kind not in mergeable:
            passthrough.append(connection)
            continue
        lines.setdefault(_axis_line_key(connection), []).append(connection)

    merged: list[Connection] = []
    for group in lines.values():
        for cluster in _clusters_along(group):
            count = float(len(cluster))
            # The hole's centre is the midpoint of the faces describing it.
            centre = Vec3(
                sum(c.position.x for c in cluster) / count,
                sum(c.position.y for c in cluster) / count,
                sum(c.position.z for c in cluster) / count,
            )
            first = cluster[0]
            merged.append(
                Connection(
                    kind=first.kind,
                    gender=first.gender,
                    position=centre,
                    axis=first.axis,
                    source=first.source,
                )
            )

    return passthrough + merged


## How far apart two faces of one hole can be, in LDU.
##
## Measured rather than reasoned, because the physical cases overlap: a
## hole through a Technic beam is 20 LDU deep but one through a thick
## panel is more, while the gap across a 2x2 round brick is only 40.  So
## no threshold is exactly right.  Swept against the 67 parts whose own
## name states how many holes they have, 44 is the peak: 42 exact, where
## merging every coaxial face regardless of distance scores 40 and a
## 24 LDU limit scores 38.  It is the low end of a plateau that runs to
## 60, taken low because merging two distinct holes loses a connection
## while splitting one invents a duplicate of a real one.  16 is much
## worse (22).
MERGE_WITHIN = 44.0


def _clusters_along(group: list[Connection]) -> list[list[Connection]]:
    """Split connectors on one axis line into the holes they describe."""
    if len(group) == 1:
        return [group]
    axis = group[0].axis
    ordered = sorted(
        group,
        key=lambda c: c.position.x * axis.x + c.position.y * axis.y
        + c.position.z * axis.z,
    )
    def along(c: Connection) -> float:
        return c.position.x * axis.x + c.position.y * axis.y + c.position.z * axis.z

    clusters: list[list[Connection]] = [[ordered[0]]]
    for connection in ordered[1:]:
        if along(connection) - along(clusters[-1][-1]) <= MERGE_WITHIN:
            clusters[-1].append(connection)
        else:
            clusters.append([connection])
    return clusters


def _axis_line_key(connection: Connection) -> tuple:
    """Identify the infinite line a connector's axis runs along."""
    axis = connection.axis
    # Canonical sign, so a hole's two opposite faces agree on a direction.
    for component in (axis.x, axis.y, axis.z):
        if abs(component) > 1e-6:
            if component < 0:
                axis = axis * -1.0
            break

    position = connection.position
    along = position.dot(axis)
    foot = position - axis * along  # perpendicular from the origin
    return (
        connection.kind,
        round(axis.x, 3), round(axis.y, 3), round(axis.z, 3),
        round(foot.x, 2), round(foot.y, 2), round(foot.z, 2),
    )


def _walk(
    library: Library,
    name: str,
    transform: Matrix,
    found: list[Connection],
    depth: int,
    max_depth: int,
    stack: set[str],
) -> None:
    if depth > max_depth or name in stack:
        return

    ldfile = library.get(name, Detail.STANDARD)
    if ldfile is None:
        return

    stack = stack | {name}

    own = name.rsplit("/", 1)[-1]
    for kind, at, way in _UNDRAWN.get(own[:-4] if own.endswith(".dat") else own, []):
        axis = transform.transform_direction(way)
        found.append(Connection(
            kind=kind, gender=Gender.NEUTRAL, position=transform.transform_point(at),
            axis=axis * (1.0 / max(axis.length(), 1e-9)), source=own))

    for command in ldfile.commands:
        if not isinstance(command, SubfileRef):
            continue

        stem = command.filename.rsplit("/", 1)[-1]
        if stem.endswith(".dat"):
            stem = stem[:-4]

        entry = _CONNECTORS.get(stem)
        if entry is not None:
            kind, gender = entry
            child = transform @ command.matrix
            axis = child.transform_direction(_LOCAL_AXIS)
            length = axis.length()
            if length > 1e-9:
                axis = axis * (1.0 / length)
            found.append(
                Connection(
                    kind=kind,
                    gender=gender,
                    position=child.transform_point(Vec3(0.0, 0.0, 0.0)),
                    axis=axis,
                    source=stem,
                )
            )
            # A connector primitive is a leaf: recursing into stud-logo3
                # would find the cylinder it is drawn from, not a second stud.
            continue

        _walk(
            library,
            command.filename,
            transform @ command.matrix,
            found,
            depth + 1,
            max_depth,
            stack,
        )


# -- round shafts and bores ----------------------------------------------
#
# A clip on a bar, a bar in a hollow stud, a hinge's pin in its eye and a
# turntable's top in its base are one joint: something round turning in
# something round that fits it. None of them has a primitive of its own,
# which is why BAR above is never produced, but every one is drawn from
# the same few cylinder primitives — and LDraw's winding says which side
# of a cylinder is plastic. A bar is a 4 LDU cylinder facing out; a clip's
# eye, a hollow stud's bore and a hinge's eye are cylinders facing in,
# drawn after BFC INVERTNEXT. Measured on the parts the checker refused:
# a clip's eye is radius 4 in every clip primitive (clip1, 3, 9, 13), a
# hollow stud's is 4, a hinge brick's pin and eye are 6 (3830, 3831) and
# a 2x2 turntable's disc and recess 17.5 (3679, 3680).
#
# The cover cannot hold these. It is filled layer by layer, so the eye of
# a clip or a hinge closes like any other ring and the part that goes in
# reads as a collision. What is recorded here is the round itself, so the
# checker can forgive an overlap that lies inside a bore where a shaft
# that fits it actually runs, and nothing else.

## The primitives a cylinder's side is drawn with: n-dcyli and n-dcyli2,
## at 16 or 48 segments. Every other cylinder primitive (cylo, cylc,
## cylc2, cylc3) is one of these with edges or a disc added, so walking
## through those reaches the side once.
_SURFACE = re.compile(r"^(\d+)-(\d+)cyli2?$")

## The side of a Technic axle, one LDU long and 6 across the cross at
## unit scale. An axle is round where it meets a round hole.
_AXLE_SIDE = frozenset({"axle", "axlehol8"})

## Connector primitives whose round surfaces are walked into, and which
## of them are kept. A pin's barrel and the bore inside it (a bar fits a
## pin's end), a clip's eye, which is all a clip is, and a pin hole's
## bore. The rest stop the walk as they do above.
_WALKED_INTO: dict[ConnectorKind, tuple[bool, bool]] = {
    # kind: (shafts kept, bores kept)
    ConnectorKind.PIN: (True, True),
    ConnectorKind.CLIP: (False, True),
    ConnectorKind.PIN_HOLE: (False, True),
}

## And the ones whose bores count only where they carry on a bore of the
## part itself. Every brick has tubes and studs, and on their own their
## insides are where studs go, not a hole through anything; but a bar
## pushed into a hollow-stud brick (3062b) runs on down through the tube
## beneath its stud, and an axle through a Technic plate (3709b) through
## the tube under each hole, and without the tube the bore stops short of
## where the bar does.
_CONTINUES = frozenset({ConnectorKind.STUD, ConnectorKind.TUBE, ConnectorKind.RIDGE})

## How much of a circle a round must go round to count. A clip's eye is
## five eighths of one, and the quarter rounds that soften a brick's
## edges are not a shaft or a bore of anything.
ROUND_ARC = 0.5
## And how long. Shorter is a chamfer or a lip.
ROUND_LENGTH = 1.0
## The widest round recorded, in LDU: the part file keeps a round's radius
## in a byte of quarter LDU (see meshfile.py). A 4x4 turntable's disc is
## well inside it; a dish's rim is not a joint.
ROUND_WIDEST = 63.75


@dataclass(slots=True)
class _Piece:
    kind: ConnectorKind
    radius: float
    start: Vec3
    end: Vec3
    arc: float       # the share of a full circle this primitive draws
    source: str
    continues: bool  # from inside a stud or tube: see _CONTINUES


@dataclass(slots=True)
class _Walk:
    """What a branch of the walk keeps, decided by the primitive above it."""

    shafts: bool = True
    bores: bool = True
    continues: bool = False


def rounds(library: Library, name: str, *, max_depth: int = 64) -> list[Connection]:
    """Every shaft and bore of a part, merged along their axes.

    Pieces drawn end to end along one axis at one radius — a lance is
    three cylinders, a bar with a stop is two — are one shaft, so each is
    recorded as a single length of round with the radius it has.
    """
    pieces: list[_Piece] = []
    _round_walk(library, name, Matrix.identity(), False, True, _Walk(), pieces,
                0, max_depth, set())
    return _merge_rounds(pieces)


def _round_walk(
    library: Library,
    name: str,
    transform: Matrix,
    invert: bool,
    certified: bool,
    keep: _Walk,
    found: list[_Piece],
    depth: int,
    max_depth: int,
    stack: set[str],
) -> None:
    if depth > max_depth or name in stack:
        return
    ldfile = library.get(name, Detail.STANDARD)
    if ldfile is None:
        return
    stack = stack | {name}
    # Which way a surface faces is only known where every file down to it
    # declares its winding. Below one that does not, a hole and a bar are
    # the same cylinder, so neither is claimed.
    certified = certified and ldfile.bfc_certified
    invert_next = False

    for command in ldfile.commands:
        if isinstance(command, MetaLine):
            if command.keyword == "BFC" and "INVERTNEXT" in command.text.upper().split():
                invert_next = True
            continue
        if not isinstance(command, SubfileRef):
            continue
        child = transform @ command.matrix
        # Which way a surface faces is the INVERTNEXTs above it and nothing
        # else. geometry.flatten also reverses the winding under a mirrored
        # matrix, but only because mirroring reversed it first: the two
        # cancel, and the surface faces where it did. Counting the mirror
        # here made every bar of the lance, 3849, a bore, because its
        # cylinders are laid along z by a matrix with a negative
        # determinant, and every clip's eye a shaft.
        child_invert = invert ^ invert_next
        invert_next = False

        stem = command.filename.rsplit("/", 1)[-1]
        if stem.endswith(".dat"):
            stem = stem[:-4]

        surface = _SURFACE.match(stem)
        if surface is not None:
            if certified and (keep.bores if child_invert else keep.shafts):
                arc = float(surface.group(1)) / float(surface.group(2))
                _add_piece(found, child, child_invert, arc, stem, 1.0,
                           keep.continues)
            continue
        if stem in _AXLE_SIDE:
            # Always solid: an axle is never drawn as a hole.
            if keep.shafts:
                _add_piece(found, child, False, 1.0, stem, 6.0, keep.continues)
            continue
        entry = _CONNECTORS.get(stem)
        below = keep
        if entry is not None:
            if entry[0] in _WALKED_INTO:
                shafts, bores = _WALKED_INTO[entry[0]]
                below = _Walk(keep.shafts and shafts, keep.bores and bores,
                              keep.continues)
            elif entry[0] in _CONTINUES:
                below = _Walk(False, keep.bores, True)
            else:
                continue

        _round_walk(library, command.filename, child, child_invert, certified,
                    below, found, depth + 1, max_depth, stack)


def _add_piece(found: list[_Piece], at: Matrix, inward: bool, arc: float,
               source: str, scale: float, continues: bool) -> None:
    """One cylinder side, if it is a circle and not an ellipse."""
    across = at.transform_direction(Vec3(1.0, 0.0, 0.0))
    along = at.transform_direction(Vec3(0.0, 1.0, 0.0))
    deep = at.transform_direction(Vec3(0.0, 0.0, 1.0))
    r1, r2, length = across.length(), deep.length(), along.length()
    if length < 1e-6 or r1 < 1e-6 or r2 < 1e-6:
        return
    # Round, and square to its own axis. A cylinder squashed into an oval
    # or sheared into a slope fits nothing round.
    if abs(r1 - r2) > 0.02 * max(r1, r2):
        return
    if (abs(across.dot(deep)) > 0.01 * r1 * r2
            or abs(across.dot(along)) > 0.01 * r1 * length
            or abs(deep.dot(along)) > 0.01 * r2 * length):
        return
    start = at.transform_point(Vec3(0.0, 0.0, 0.0))
    found.append(_Piece(
        kind=ConnectorKind.BORE if inward else ConnectorKind.SHAFT,
        radius=scale * 0.5 * (r1 + r2),
        start=start,
        end=start + along,
        arc=arc,
        source=source,
        continues=continues,
    ))


def _merge_rounds(pieces: list[_Piece]) -> list[Connection]:
    """Pieces on one axis line, at one radius, touching end to end, as one."""
    lines: list[tuple[ConnectorKind, float, Vec3, Vec3, list]] = []
    for piece in pieces:
        span = piece.end - piece.start
        length = span.length()
        way = span * (1.0 / length)
        start, end = piece.start, piece.end
        # Canonical sign, so a cylinder drawn top-down and one drawn
        # bottom-up along the same line agree.
        for component in (way.x, way.y, way.z):
            if abs(component) > 1e-6:
                if component < 0:
                    way = way * -1.0
                    start, end = end, start
                break
        along = start.dot(way)
        foot = start - way * along
        for kind, radius, line_way, line_foot, members in lines:
            if (kind is piece.kind and abs(radius - piece.radius) <= 0.1
                    and way.dot(line_way) >= 0.9999
                    and (foot - line_foot).length() <= 0.1):
                members.append((along, along + length, piece))
                break
        else:
            lines.append((piece.kind, piece.radius, way, foot,
                          [(along, along + length, piece)]))

    # Each line's clusters: [kind, radius, way, foot, low, high, arc,
    # continues only, source].
    found: list[list] = []
    for kind, radius, way, foot, members in lines:
        members.sort(key=lambda m: m[0])
        clusters: list[list] = [[members[0]]]
        reach = members[0][1]
        for member in members[1:]:
            if member[0] <= reach + 0.5:
                clusters[-1].append(member)
                reach = max(reach, member[1])
            else:
                clusters.append([member])
                reach = member[1]
        for cluster in clusters:
            low = min(m[0] for m in cluster)
            high = max(m[1] for m in cluster)
            # How far round it goes: two half cylinders over the same span
            # are a whole one, two quarter rounds at either end of an edge
            # are still a quarter.
            arc = max(
                sum(q[2].arc for q in cluster
                    if min(p[1], q[1]) - max(p[0], q[0]) > 0.01)
                for p in cluster)
            if min(arc, 1.0) < ROUND_ARC or high - low < ROUND_LENGTH:
                continue
            found.append([kind, sum(m[2].radius for m in cluster) / len(cluster),
                          way, foot, low, high,
                          all(m[2].continues for m in cluster), cluster[0][2].source,
                          min(arc, 1.0)])

    out: list[Connection] = []
    for kind, radius, way, foot, low, high, continues, source, arc in found:
        # A tube's or a stud's bore is kept where it carries on one of the
        # part's own, at whatever radius: 3062b's bore is 4 under its stud
        # and 6 through the tube below it.
        if continues and not any(
                not other[6] and other[0] is ConnectorKind.BORE
                and abs(way.dot(other[2])) >= 0.9999
                and (foot - other[3]).length() <= 0.1
                and other[4] <= high + 0.5 and low <= other[5] + 0.5
                for other in found):
            continue
        if radius > ROUND_WIDEST:
            continue
        out.append(Connection(
            kind=kind,
            gender=Gender.MALE if kind is ConnectorKind.SHAFT else Gender.FEMALE,
            position=foot + way * low,
            axis=way,
            source=source,
            length=high - low,
            radius=radius,
            arc=arc,
        ))
    return out


def summarise(connections: list[Connection]) -> dict[str, int]:
    """Count connectors by kind, for reporting and tests."""
    counts: dict[str, int] = {}
    for connection in connections:
        counts[connection.kind.value] = counts.get(connection.kind.value, 0) + 1
    return counts


def studs(connections: list[Connection]) -> list[Connection]:
    return [c for c in connections if c.kind is ConnectorKind.STUD]


def tubes(connections: list[Connection]) -> list[Connection]:
    return [c for c in connections if c.kind is ConnectorKind.TUBE]
