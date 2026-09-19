"""Parsing of individual LDraw source lines.

The LDraw file format is a line-based list of drawing commands.  Every line
starts with an integer line type that decides how the rest of it is read:

    0  meta / comment          0 BFC CERTIFY CCW
    1  subfile reference       1 <colour> x y z a b c d e f g h i <file>
    2  line (edge)             1 colour, 2 points
    3  triangle                1 colour, 3 points
    4  quadrilateral           1 colour, 4 points
    5  optional (conditional)  1 colour, 2 points + 2 control points

The 12 numbers on a type-1 line are a 3x4 affine transform laid out
row-major as a b c / d e f / g h i with x y z as the translation:

        | a b c x |
        | d e f y |
        | g h i z |
        | 0 0 0 1 |

Two colour codes are special and must be resolved against the *referring*
file rather than looked up in the palette:

    16  take the surface colour of whoever referenced this file
    24  take the contrasting edge colour of whoever referenced this file

Reference: the official spec at https://www.ldraw.org/article/218.html
(verified against the 2025-05 library release).
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Iterator

# Colour codes that inherit from the referencing file rather than the palette.
COLOR_INHERIT = 16
COLOR_EDGE_INHERIT = 24


class LineType(IntEnum):
    META = 0
    SUBFILE = 1
    LINE = 2
    TRIANGLE = 3
    QUAD = 4
    OPTIONAL_LINE = 5


@dataclass(frozen=True, slots=True)
class Vec3:
    """A point in LDraw space: X right, Y *down*, Z away from the viewer.

    A dataclass rather than a NamedTuple on purpose: arithmetic operators on
    a tuple subclass would silently shadow tuple concatenation, so ``a + b``
    would mean two different things depending on the static type.
    """

    x: float
    y: float
    z: float

    def __iter__(self):
        yield self.x
        yield self.y
        yield self.z

    def __add__(self, o: "Vec3") -> "Vec3":
        return Vec3(self.x + o.x, self.y + o.y, self.z + o.z)

    def __sub__(self, o: "Vec3") -> "Vec3":
        return Vec3(self.x - o.x, self.y - o.y, self.z - o.z)

    def __mul__(self, s: float) -> "Vec3":
        return Vec3(self.x * s, self.y * s, self.z * s)

    def cross(self, o: "Vec3") -> "Vec3":
        return Vec3(
            self.y * o.z - self.z * o.y,
            self.z * o.x - self.x * o.z,
            self.x * o.y - self.y * o.x,
        )

    def dot(self, o: "Vec3") -> float:
        return self.x * o.x + self.y * o.y + self.z * o.z

    def length(self) -> float:
        return (self.x * self.x + self.y * self.y + self.z * self.z) ** 0.5


class Matrix:
    """A 3x4 affine transform, stored row-major with a separate translation.

    Kept as plain floats rather than numpy: these are multiplied millions of
    times during subfile recursion and the per-call overhead of numpy for a
    3x3 dominates by a wide margin.
    """

    __slots__ = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "x", "y", "z")

    def __init__(
        self,
        a: float = 1.0, b: float = 0.0, c: float = 0.0,
        d: float = 0.0, e: float = 1.0, f: float = 0.0,
        g: float = 0.0, h: float = 0.0, i: float = 1.0,
        x: float = 0.0, y: float = 0.0, z: float = 0.0,
    ) -> None:
        self.a, self.b, self.c = a, b, c
        self.d, self.e, self.f = d, e, f
        self.g, self.h, self.i = g, h, i
        self.x, self.y, self.z = x, y, z

    @classmethod
    def identity(cls) -> "Matrix":
        return cls()

    def determinant(self) -> float:
        """Determinant of the 3x3 rotation/scale part.

        A negative value means the transform mirrors space, which reverses
        the apparent winding of every polygon underneath it.  BFC-aware
        renderers must flip winding to compensate; see geometry.py.
        """
        return (
            self.a * (self.e * self.i - self.f * self.h)
            - self.b * (self.d * self.i - self.f * self.g)
            + self.c * (self.d * self.h - self.e * self.g)
        )

    def transform_point(self, p: Vec3) -> Vec3:
        return Vec3(
            self.a * p.x + self.b * p.y + self.c * p.z + self.x,
            self.d * p.x + self.e * p.y + self.f * p.z + self.y,
            self.g * p.x + self.h * p.y + self.i * p.z + self.z,
        )

    def transform_direction(self, p: Vec3) -> Vec3:
        """Transform ignoring translation, for normals and axes."""
        return Vec3(
            self.a * p.x + self.b * p.y + self.c * p.z,
            self.d * p.x + self.e * p.y + self.f * p.z,
            self.g * p.x + self.h * p.y + self.i * p.z,
        )

    def __matmul__(self, o: "Matrix") -> "Matrix":
        """Compose: ``self @ o`` applies o first, then self."""
        return Matrix(
            self.a * o.a + self.b * o.d + self.c * o.g,
            self.a * o.b + self.b * o.e + self.c * o.h,
            self.a * o.c + self.b * o.f + self.c * o.i,
            self.d * o.a + self.e * o.d + self.f * o.g,
            self.d * o.b + self.e * o.e + self.f * o.h,
            self.d * o.c + self.e * o.f + self.f * o.i,
            self.g * o.a + self.h * o.d + self.i * o.g,
            self.g * o.b + self.h * o.e + self.i * o.h,
            self.g * o.c + self.h * o.f + self.i * o.i,
            self.a * o.x + self.b * o.y + self.c * o.z + self.x,
            self.d * o.x + self.e * o.y + self.f * o.z + self.y,
            self.g * o.x + self.h * o.y + self.i * o.z + self.z,
        )

    def __repr__(self) -> str:
        return (
            f"Matrix({self.a:g} {self.b:g} {self.c:g} / {self.d:g} {self.e:g} "
            f"{self.f:g} / {self.g:g} {self.h:g} {self.i:g} @ "
            f"{self.x:g} {self.y:g} {self.z:g})"
        )


@dataclass(slots=True)
class MetaLine:
    """A type-0 line: either a comment or a ``!``-prefixed meta command."""

    keyword: str  # first token after the 0, upper-cased ("BFC", "!COLOUR", "")
    text: str     # the rest of the line, verbatim


@dataclass(slots=True)
class SubfileRef:
    color: int
    matrix: Matrix
    filename: str  # normalised: lower-case, forward slashes


@dataclass(slots=True)
class Polygon:
    """A triangle (3 points) or quad (4 points)."""

    color: int
    points: tuple[Vec3, ...]


@dataclass(slots=True)
class EdgeLine:
    color: int
    points: tuple[Vec3, Vec3]


@dataclass(slots=True)
class OptionalLine:
    """A type-5 conditional edge.

    Drawn only when the two control points fall on the same side of the
    line in screen space — this is how LDraw renders the silhouette of a
    curved surface without outlining every facet of it.
    """

    color: int
    points: tuple[Vec3, Vec3]
    controls: tuple[Vec3, Vec3]


Command = MetaLine | SubfileRef | Polygon | EdgeLine | OptionalLine


def normalise_filename(name: str) -> str:
    """LDraw files reference subfiles with Windows-style backslashes.

    ``1 16 0 0 0 1 0 0 0 1 0 0 0 1 s\\3001s01.dat`` has to find
    ``parts/s/3001s01.dat`` on a case-sensitive filesystem, so paths are
    lower-cased and separators normalised everywhere they are compared.
    """
    return name.replace("\\", "/").strip().lower()


def _points(tokens: list[str], start: int, count: int) -> tuple[Vec3, ...]:
    out = []
    for n in range(count):
        base = start + n * 3
        out.append(
            Vec3(float(tokens[base]), float(tokens[base + 1]), float(tokens[base + 2]))
        )
    return tuple(out)


def parse_line(raw: str) -> Command | None:
    """Parse one source line.  Returns None for blank lines.

    Malformed lines raise ValueError; callers decide whether to skip the
    line or reject the file.  The official library is clean, but the
    unofficial Parts Tracker and user-authored .ldr files are not.
    """
    line = raw.strip()
    if not line:
        return None

    tokens = line.split()
    try:
        line_type = int(tokens[0])
    except ValueError:
        raise ValueError(f"line does not start with a line type: {raw!r}")

    if line_type == LineType.META:
        if len(tokens) == 1:
            return MetaLine("", "")
        keyword = tokens[1].upper()
        return MetaLine(keyword, " ".join(tokens[2:]))

    if line_type == LineType.SUBFILE:
        if len(tokens) < 15:
            raise ValueError(f"type-1 line needs 15 tokens, got {len(tokens)}: {raw!r}")
        color = int(tokens[1])
        v = [float(t) for t in tokens[2:14]]
        # Tokens 2..4 are the translation, 5..13 the row-major 3x3.
        matrix = Matrix(
            v[3], v[4], v[5],
            v[6], v[7], v[8],
            v[9], v[10], v[11],
            v[0], v[1], v[2],
        )
        # The filename may contain spaces, so it is everything that is left.
        filename = normalise_filename(" ".join(tokens[14:]))
        return SubfileRef(color, matrix, filename)

    if line_type == LineType.LINE:
        if len(tokens) < 8:
            raise ValueError(f"type-2 line needs 8 tokens: {raw!r}")
        pts = _points(tokens, 2, 2)
        return EdgeLine(int(tokens[1]), (pts[0], pts[1]))

    if line_type == LineType.TRIANGLE:
        if len(tokens) < 11:
            raise ValueError(f"type-3 line needs 11 tokens: {raw!r}")
        return Polygon(int(tokens[1]), _points(tokens, 2, 3))

    if line_type == LineType.QUAD:
        if len(tokens) < 14:
            raise ValueError(f"type-4 line needs 14 tokens: {raw!r}")
        return Polygon(int(tokens[1]), _points(tokens, 2, 4))

    if line_type == LineType.OPTIONAL_LINE:
        if len(tokens) < 14:
            raise ValueError(f"type-5 line needs 14 tokens: {raw!r}")
        pts = _points(tokens, 2, 4)
        return OptionalLine(int(tokens[1]), (pts[0], pts[1]), (pts[2], pts[3]))

    raise ValueError(f"unknown line type {line_type}: {raw!r}")


def parse_text(text: str, *, strict: bool = False) -> Iterator[tuple[int, Command]]:
    """Parse a whole file, yielding ``(line_number, command)``.

    With ``strict=False`` (the default) unparseable lines are skipped, which
    is what every real renderer does: a single bad line in an unofficial
    part should not lose the other 4,000 good ones.
    """
    for number, raw in enumerate(text.splitlines(), start=1):
        try:
            command = parse_line(raw)
        except ValueError:
            if strict:
                raise
            continue
        if command is not None:
            yield number, command
