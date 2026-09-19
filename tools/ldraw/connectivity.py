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

from dataclasses import dataclass
from enum import Enum

from .library import Detail, Library
from .parser import Matrix, SubfileRef, Vec3

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
_register(
    """
    peghole peghole2 peghole3 npeghol1 npeghol2 npeghol3 npeghol4
    confric confric2 beamhole
    """,
    ConnectorKind.PIN_HOLE,
    Gender.NEUTRAL,
)
_register(
    "connect connect2 connect3 connect4 connect5 connect6 connect7 connect8 connect10",
    ConnectorKind.PIN,
    Gender.MALE,
)
_register("axlehole axlehol2 axlehol3 axlehol4 axlehol8 axl2hole", ConnectorKind.AXLE_HOLE, Gender.NEUTRAL)
_register("axle axle2 axlebeam axleend axleend2 axleend20", ConnectorKind.AXLE, Gender.MALE)

# -- bars, clips, balls --------------------------------------------------
_register("bar bar2 barhole", ConnectorKind.BAR, Gender.MALE)
_register("clip1 clip2 clip3 clip4 clip5 clip6 clip7 clip8 clip9", ConnectorKind.CLIP, Gender.FEMALE)
_register("ball balljnt", ConnectorKind.BALL, Gender.MALE)
_register("socket socket2", ConnectorKind.SOCKET, Gender.FEMALE)


@dataclass(slots=True)
class Connection:
    """One place on a part where another part can attach."""

    kind: ConnectorKind
    gender: Gender
    position: Vec3   # part-local, LDU
    axis: Vec3       # unit vector pointing out of the part
    source: str      # the primitive that produced it, for debugging

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

    # Coincident duplicates happen where a part references both a stud and
    # a decorated version of it at the same spot.
    seen: set[tuple] = set()
    unique: list[Connection] = []
    for connection in found:
        k = connection.key()
        if k not in seen:
            seen.add(k)
            unique.append(connection)

    return _merge_half_holes(unique)


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
        if len(group) == 1:
            merged.append(group[0])
            continue
        # The hole's centre is the midpoint of the faces that describe it.
        count = float(len(group))
        centre = Vec3(
            sum(c.position.x for c in group) / count,
            sum(c.position.y for c in group) / count,
            sum(c.position.z for c in group) / count,
        )
        first = group[0]
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
