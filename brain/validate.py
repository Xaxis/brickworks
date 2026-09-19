"""Checking that a design is a thing that could be built.

This is the component that makes a language model's output trustworthy,
and it works by not trusting it at all.  Nothing the model says about
geometry is taken on faith: every placement is resolved against the real
catalogue, rasterised onto the same 2 LDU lattice the application uses,
and checked for overlap, support and connection.

The checks, and why each earns its place:

Unknown part
    A hallucinated part number is the single most common failure, and
    the cheapest to catch.

Collision
    Two bricks cannot occupy the same space.  Integer boxes on the
    lattice, so the answer has no tolerance in it.

Support
    A brick with nothing under it floats.  Real bricks fall.

Connection
    A model must be one connected thing, not several.  Two towers that
    never touch are two models, however good each looks.

What is deliberately *not* checked is whether the result looks like what
was asked for.  No validator can tell a dragon from a pile; that is the
model's job, and the reason the loop is generate-check-repair rather than
generate-and-hope.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from enum import Enum

from .catalogue import CELL, CELLS_PER_PLATE, CELLS_PER_STUD, Catalogue, Part
from .model import Model, Placement, footprint_after_rotation


class Severity(Enum):
    ERROR = "error"      # cannot be built
    WARNING = "warning"  # can be built, probably not intended


@dataclass(slots=True)
class Issue:
    severity: Severity
    kind: str
    message: str
    index: int = -1          # which placement, when it is about one
    others: list[int] = field(default_factory=list)

    def __str__(self) -> str:
        where = f" [brick {self.index}]" if self.index >= 0 else ""
        return f"{self.severity.value}: {self.message}{where}"


@dataclass(slots=True)
class Report:
    issues: list[Issue] = field(default_factory=list)
    brick_count: int = 0
    part_count: int = 0
    size_studs: tuple[int, int, int] = (0, 0, 0)
    connected_groups: int = 0

    @property
    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.severity is Severity.ERROR]

    @property
    def warnings(self) -> list[Issue]:
        return [i for i in self.issues if i.severity is Severity.WARNING]

    @property
    def ok(self) -> bool:
        return not self.errors

    def summary(self) -> str:
        if self.ok and not self.warnings:
            return (
                f"buildable: {self.brick_count} bricks, {self.part_count} "
                f"distinct parts, {self.size_studs[0]}x{self.size_studs[2]} "
                f"studs and {self.size_studs[1]} plates tall")
        parts = [f"{len(self.errors)} error(s)", f"{len(self.warnings)} warning(s)"]
        return ", ".join(parts)

    def as_feedback(self, limit: int = 25) -> str:
        """What to hand back to the model so it can fix the design.

        Grouped by kind and capped: a hundred instances of the same
        mistake teaches no more than three do, and crowds out the others.
        """
        if self.ok and not self.warnings:
            return self.summary()

        by_kind: dict[str, list[Issue]] = {}
        for issue in self.issues:
            by_kind.setdefault(issue.kind, []).append(issue)

        lines: list[str] = []
        for kind, issues in by_kind.items():
            head = issues[0].severity.value.upper()
            lines.append(f"{head} — {kind} ({len(issues)}):")
            for issue in issues[:3]:
                lines.append(f"  - {issue.message}")
            if len(issues) > 3:
                lines.append(f"  - ... and {len(issues) - 3} more like it")
            if len(lines) > limit:
                break
        return "\n".join(lines)


def _cells(part: Part, placement: Placement) -> list[tuple[int, int, int]]:
    """Which lattice cells a placement fills.

    The part's collision cover is stored in cells about its own origin,
    which sits at the top of its body with -Y up in the source data; the
    conversion to the application's axes already happened when the cover
    was written.  What remains is to rotate it, move it to where the
    placement says, and round nothing.
    """
    across, deep = footprint_after_rotation(part.width, part.depth, placement.rot)

    # The part's origin in lattice cells: the low corner of the footprint
    # plus half the footprint, and the top of the plates it occupies.
    origin_x = placement.x * CELLS_PER_STUD + (across * CELLS_PER_STUD) // 2
    origin_y = (placement.y + part.height_plates) * CELLS_PER_PLATE
    origin_z = placement.z * CELLS_PER_STUD + (deep * CELLS_PER_STUD) // 2

    boxes = part.boxes
    if not boxes:
        # No cover was generated; fall back to the bounding box, which
        # over-reports rather than under-reports.
        lo = part.bounds_min
        hi = part.bounds_max
        boxes = [(
            int(lo[0] // CELL), int(lo[1] // CELL), int(lo[2] // CELL),
            max(1, int((hi[0] - lo[0]) / CELL)),
            max(1, int((hi[1] - lo[1]) / CELL)),
            max(1, int((hi[2] - lo[2]) / CELL)),
        )]

    out: list[tuple[int, int, int]] = []
    for bx, by, bz, bw, bh, bd in boxes:
        for x in range(bx, bx + bw):
            for y in range(by, by + bh):
                for z in range(bz, bz + bd):
                    rx, rz = _rotate(x, z, placement.rot)
                    out.append((origin_x + rx, origin_y + y, origin_z + rz))
    return out


def _rotate(x: int, z: int, rot: int) -> tuple[int, int]:
    """A quarter turn about the vertical axis, in the lattice."""
    turns = rot % 4
    if turns == 0:
        return (x, z)
    if turns == 1:
        return (-z, x)
    if turns == 2:
        return (-x, -z)
    return (z, -x)


def check(model: Model, catalogue: Catalogue) -> Report:
    """Validate a design. Never raises; everything wrong becomes an issue."""
    report = Report(brick_count=len(model.placements))
    report.part_count = len(model.part_counts())

    occupied: dict[tuple[int, int, int], int] = {}
    cells_of: dict[int, list[tuple[int, int, int]]] = {}
    resolved: dict[int, Part] = {}

    for index, placement in enumerate(model.placements):
        part = catalogue.get(placement.part)
        if part is None:
            report.issues.append(Issue(
                Severity.ERROR, "unknown part",
                f"no part '{placement.part}' exists in the catalogue",
                index))
            continue
        resolved[index] = part

        if placement.y < 0:
            report.issues.append(Issue(
                Severity.ERROR, "below ground",
                f"brick {index} ({placement.part}) is at y={placement.y}, "
                "below the ground plane; y counts plates upward from 0",
                index))
            continue

        cells = _cells(part, placement)
        cells_of[index] = cells

        hit: set[int] = set()
        for cell in cells:
            other = occupied.get(cell)
            if other is not None and other != index:
                hit.add(other)
            else:
                occupied[cell] = index
        if hit:
            names = ", ".join(
                f"{o} ({model.placements[o].part})" for o in sorted(hit)[:3])
            report.issues.append(Issue(
                Severity.ERROR, "overlap",
                f"brick {index} ({placement.part} at "
                f"{placement.x},{placement.y},{placement.z}) overlaps {names}",
                index, sorted(hit)))

    _check_support(model, resolved, cells_of, occupied, report)
    _check_connected(model, cells_of, occupied, report)
    _measure(model, resolved, report)
    return report


def _check_support(
    model: Model,
    resolved: dict[int, Part],
    cells_of: dict[int, list[tuple[int, int, int]]],
    occupied: dict[tuple[int, int, int], int],
    report: Report,
) -> None:
    """A brick needs the ground or another brick under it.

    Only downward support counts. A brick held only from the side is
    stuck on by friction in the model and by nothing at all in reality.
    """
    for index, cells in cells_of.items():
        placement = model.placements[index]
        if placement.y == 0:
            continue  # on the ground

        floor = min(c[1] for c in cells)
        supported = False
        for cell in cells:
            if cell[1] != floor:
                continue
            below = (cell[0], cell[1] - 1, cell[2])
            other = occupied.get(below)
            if other is not None and other != index:
                supported = True
                break
        if not supported:
            report.issues.append(Issue(
                Severity.ERROR, "floating",
                f"brick {index} ({placement.part} at "
                f"{placement.x},{placement.y},{placement.z}) has nothing "
                "beneath it — it would fall",
                index))


def _check_connected(
    model: Model,
    cells_of: dict[int, list[tuple[int, int, int]]],
    occupied: dict[tuple[int, int, int], int],
    report: Report,
) -> None:
    """The model has to be one object.

    Two bricks are joined when one sits directly on the other. Side by
    side is not joined: two bricks pushed together on a table come apart
    when you lift them.
    """
    if not cells_of:
        report.connected_groups = 0
        return

    neighbours: dict[int, set[int]] = {i: set() for i in cells_of}
    for index, cells in cells_of.items():
        for cell in cells:
            for step in (-1, 1):
                other = occupied.get((cell[0], cell[1] + step, cell[2]))
                if other is not None and other != index:
                    neighbours[index].add(other)
                    neighbours.setdefault(other, set()).add(index)

    seen: set[int] = set()
    groups = 0
    largest = 0
    stray: list[int] = []
    for start in cells_of:
        if start in seen:
            continue
        groups += 1
        members: list[int] = []
        queue = deque([start])
        seen.add(start)
        while queue:
            current = queue.popleft()
            members.append(current)
            for nxt in neighbours.get(current, ()):  # noqa: SIM118
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        if len(members) > largest:
            largest = len(members)
            stray = []
        elif len(members) <= 3:
            stray.extend(members)

    report.connected_groups = groups
    if groups > 1:
        detail = ""
        if stray:
            names = ", ".join(
                f"{i} ({model.placements[i].part})" for i in stray[:4])
            detail = f"; loose pieces include {names}"
        report.issues.append(Issue(
            Severity.ERROR, "not one piece",
            f"the model is {groups} separate pieces that never touch; "
            f"the largest has {largest} bricks{detail}"))


def _measure(
    model: Model, resolved: dict[int, Part], report: Report
) -> None:
    if not resolved:
        return
    lo = [10**9, 10**9, 10**9]
    hi = [-10**9, -10**9, -10**9]
    for index, part in resolved.items():
        placement = model.placements[index]
        across, deep = footprint_after_rotation(
            part.width, part.depth, placement.rot)
        lo[0] = min(lo[0], placement.x)
        lo[1] = min(lo[1], placement.y)
        lo[2] = min(lo[2], placement.z)
        hi[0] = max(hi[0], placement.x + across)
        hi[1] = max(hi[1], placement.y + part.height_plates)
        hi[2] = max(hi[2], placement.z + deep)
    report.size_studs = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
