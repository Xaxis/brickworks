"""The build plan: what a design is, before it is geometry.

A model here is a list of placements in *brick* coordinates — studs across,
plates up — not LDU and not matrices:

    {"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0}

That choice is the whole point.  Asking a language model for a transform
matrix, or for coordinates in 0.4 mm units, invites arithmetic it has no
reason to get right: a plate is 8 LDU, a brick 24, a stud pitch 20, and a
2x4 brick's centre sits at odd multiples of 10.  Every one of those is a
chance to be half a plate out, and being half a plate out is invisible in
text and obvious on screen.

In these coordinates the rules are ones anyone can hold: x and z count
studs, y counts plates, a brick is three plates tall, and a part occupies
the studs its name says it does.  The conversion to LDU happens here,
once, in code that is tested.

Origin and anchor
-----------------
A placement's ``x, y, z`` is the **low corner** of the part's footprint,
not its centre.  "A 2x4 brick at (0, 0, 0)" means it covers studs 0-3 in
x and 0-1 in z, resting on the ground.  Centres would be worse: the
centre of an even-width part falls between studs, so half the catalogue
would need half-integer coordinates.

``rot`` is quarter turns about the vertical axis, 0-3.  A part rotated
once still has its low corner at ``x, z`` — the footprint swaps, the
anchor does not move — so a wall can be laid without tracking which way
each brick faces.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Iterable

# The unit system, in LDU.  See docs/ARCHITECTURE.md.
STUD = 20.0
PLATE = 8.0
BRICK = 24.0
LDU_MM = 0.4


@dataclass(slots=True)
class Placement:
    """One part, positioned by the low corner of its footprint."""

    part: str
    color: int
    x: int          # studs
    y: int          # plates, from the ground
    z: int          # studs
    rot: int = 0    # quarter turns about the vertical axis

    def key(self) -> tuple:
        return (self.part, self.x, self.y, self.z, self.rot)

    def to_dict(self) -> dict[str, Any]:
        return {
            "part": self.part, "color": self.color,
            "x": self.x, "y": self.y, "z": self.z, "rot": self.rot,
        }

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "Placement":
        return cls(
            part=str(raw["part"]),
            color=int(raw.get("color", 7)),
            x=int(raw["x"]),
            y=int(raw["y"]),
            z=int(raw["z"]),
            rot=int(raw.get("rot", 0)) % 4,
        )


@dataclass(slots=True)
class Model:
    name: str = "Model"
    description: str = ""
    placements: list[Placement] = field(default_factory=list)

    def __len__(self) -> int:
        return len(self.placements)

    def add(self, *placements: Placement) -> None:
        self.placements.extend(placements)

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "bricks": [p.to_dict() for p in self.placements],
        }

    def to_json(self, indent: int | None = None) -> str:
        return json.dumps(self.to_dict(), indent=indent)

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "Model":
        return cls(
            name=str(raw.get("name", "Model")),
            description=str(raw.get("description", "")),
            placements=[
                Placement.from_dict(b) for b in raw.get("bricks", [])
            ],
        )

    @classmethod
    def from_json(cls, text: str) -> "Model":
        return cls.from_dict(json.loads(text))

    def bounds_studs(self) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
        """Rough extent in brick coordinates, ignoring part sizes."""
        if not self.placements:
            return (0, 0, 0), (0, 0, 0)
        lo = (
            min(p.x for p in self.placements),
            min(p.y for p in self.placements),
            min(p.z for p in self.placements),
        )
        hi = (
            max(p.x for p in self.placements),
            max(p.y for p in self.placements),
            max(p.z for p in self.placements),
        )
        return lo, hi

    def color_counts(self) -> dict[int, int]:
        counts: dict[int, int] = {}
        for placement in self.placements:
            counts[placement.color] = counts.get(placement.color, 0) + 1
        return counts

    def part_counts(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for placement in self.placements:
            counts[placement.part] = counts.get(placement.part, 0) + 1
        return counts


# -- conversion ----------------------------------------------------------


def rotation_matrix(rot: int) -> tuple[float, ...]:
    """A quarter turn about the vertical axis, as an LDraw 3x3.

    LDraw has -Y up, so a turn that looks clockwise from above is written
    with the signs below.  Returned row-major: a b c d e f g h i.
    """
    turns = rot % 4
    if turns == 0:
        return (1, 0, 0, 0, 1, 0, 0, 0, 1)
    if turns == 1:
        return (0, 0, -1, 0, 1, 0, 1, 0, 0)
    if turns == 2:
        return (-1, 0, 0, 0, 1, 0, 0, 0, -1)
    return (0, 0, 1, 0, 1, 0, -1, 0, 0)


def footprint_after_rotation(
    width: int, depth: int, rot: int
) -> tuple[int, int]:
    """A part's footprint in studs after a quarter turn."""
    return (depth, width) if rot % 2 == 1 else (width, depth)


def to_ldraw_position(
    placement: Placement, width: int, depth: int, height_plates: int
) -> tuple[float, float, float]:
    """Where the part's own origin goes, in LDraw coordinates.

    Three conversions happen at once, and all three are easy to get
    subtly wrong by hand, which is why nothing outside this function is
    allowed to do them:

    * The anchor moves from the footprint's low corner to the part's
      centre, which is half its footprint further along.
    * -Y is up in LDraw, so the height is negated.
    * A part's own origin sits at the *top* of its body — a brick spans
      y 0 to 24 with 0 being the top — so a part resting on layer ``y``
      has its origin at the top of the plates it occupies.
    """
    across, deep = footprint_after_rotation(width, depth, rot=placement.rot)

    x = (placement.x + across * 0.5) * STUD
    z = (placement.z + deep * 0.5) * STUD
    # Up is -Y: a part on layer y, occupying height_plates, has its top at
    # (y + height_plates) plates above the ground.
    y = -(placement.y + height_plates) * PLATE
    return (x, y, z)


def to_ldr(
    model: Model,
    sizes: dict[str, tuple[int, int, int]],
    *,
    author: str = "",
) -> str:
    """Write the model as LDraw text, the format every brick tool reads.

    ``sizes`` maps a part id to its ``(width, depth, height_plates)`` in
    brick units; the catalogue supplies it.  A part that is missing is
    skipped with a comment rather than placed wrongly — a model that is
    short one brick is repairable, one with a brick in the wrong place is
    misleading.
    """
    lines: list[str] = [
        f"0 {model.name}",
        f"0 Name: {_slug(model.name)}.ldr",
    ]
    if author:
        lines.append(f"0 Author: {author}")
    if model.description:
        lines.append(f"0 // {model.description}")
    lines.append("")

    for placement in model.placements:
        size = sizes.get(placement.part)
        if size is None:
            lines.append(f"0 // unknown part {placement.part}, skipped")
            continue
        width, depth, height = size
        x, y, z = to_ldraw_position(placement, width, depth, height)
        a, b, c, d, e, f, g, h, i = rotation_matrix(placement.rot)
        numbers = " ".join(
            _number(v) for v in (x, y, z, a, b, c, d, e, f, g, h, i)
        )
        lines.append(f"1 {placement.color} {numbers} {placement.part}.dat")

    lines.append("0")
    return "\n".join(lines) + "\n"


def _number(value: float) -> str:
    if value == int(value):
        return str(int(value))
    return f"{value:g}"


def _slug(text: str) -> str:
    kept = [c.lower() if c.isalnum() else "_" for c in text]
    return "".join(kept).strip("_") or "model"


def from_placements(raw: Iterable[dict[str, Any]], name: str = "Model") -> Model:
    return Model(name=name, placements=[Placement.from_dict(r) for r in raw])
