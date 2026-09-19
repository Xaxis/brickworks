"""The on-disk mesh format the app loads parts from.

Why not glTF
------------
Godot imports glTF very well, but importing is the problem: ~19,000 parts
would mean ~19,000 trips through the editor's import pipeline and ~19,000
``.import`` sidecars plus re-encoded copies in ``.godot/imported``.  That
is slow to build, enormous in the repository, and impossible to stream —
and on the web build we want to fetch a part's geometry only when someone
actually places one.

So parts are written in a small binary format that maps straight onto the
arrays ``ArrayMesh`` wants, with no conversion at load time beyond a
memcpy.  It is versioned, it is little-endian, and it is boring.

Coordinates
-----------
Files are written in the *application's* convention, not LDraw's, so the
runtime never has to think about it:

    1 unit   = 1 LDU = 0.4 mm exactly
    +Y       = up          (LDraw has -Y up, so Y is negated)
    handed   = right       (Z is negated too, making it a 180 degree turn
                            about X — a proper rotation, so polygon
                            winding survives unchanged)

Keeping the unit at 1 LDU rather than converting to metres means every
stud pitch is exactly 20, every plate 8, every brick 24, and the assembly
lattice is integer arithmetic with no scale factor anywhere in it.

Quantisation
------------
Vertices are not floats.  A position is a signed 16-bit count of 1/64 LDU
steps, which is 6.25 microns — two orders of magnitude finer than any
feature on a brick, and far finer than the 0.1 mm the real mould is held
to.  Normals are octahedral-encoded into two signed 16-bit numbers,
accurate to about a hundredth of a degree.

That takes a vertex from 24 bytes to 10, and it matters: at 24 bytes the
whole library came to 1.5 GB, which is too much to ship and far too much
to fetch.

The scale is a property of the file rather than of each part *on purpose*.
Almost every part uses 1/64 LDU, so a vertex at exactly x = 20 LDU encodes
to exactly 1280 in every part that has one — surfaces that meet in the
real brick still meet exactly here, instead of missing each other by a
fraction of a micron and shimmering.  The 75 parts in the library too
large for a 16-bit count at 1/64 (long hoses and flex axles, out to 1060
LDU) fall back to a coarser step, and nothing touches them.

Layout
------
    magic     "LBM2"                    4 bytes
    flags     u16                       bit 0: has two-sided surfaces
    surfaces  u16
    scale     f32                       quantisation steps per LDU
    bounds    6 x f32                   min xyz, max xyz
    per surface:
        color     i16                   LDraw colour code; 16 means
                                        "the colour this part is placed
                                        in", i.e. recolourable at runtime
        flags     u16                   bit 0: two-sided (not BFC certified)
        vertices  u32
        indices   u32
        vertex[]  3 x i16 + 2 x i16     position (steps), normal (octahedral)
        index[]   u16 or u32            u16 when vertices <= 65535
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field

from .geometry import Mesh, compute_normals
from .parser import COLOR_INHERIT, Vec3

MAGIC = b"LBM2"

# Quantisation steps per LDU.  A power of two so the division is exact and
# a round number of steps lands on every lattice position.
DEFAULT_SCALE = 64.0
# The coarser fallback for the handful of parts that overflow at 64.
FALLBACK_SCALES = (16.0, 4.0, 1.0)
_I16_MAX = 32767

# 1 LDU in millimetres.  The one place this number lives.
LDU_MM = 0.4

SURFACE_TWO_SIDED = 1 << 0
FILE_HAS_TWO_SIDED = 1 << 0

# Vertices closer than this are the same vertex.  Matches the welding
# tolerance used for smoothing, so the two agree about what "same" means.
_WELD = 1e-3
_WELD_SCALE = 1.0 / _WELD
# Normals are compared coarsely: two normals within about half a degree
# are the same shading, and being stricter only inflates the buffer.
_NORMAL_SCALE = 4096.0


@dataclass(slots=True)
class Surface:
    color: int
    two_sided: bool
    positions: list[float] = field(default_factory=list)
    normals: list[float] = field(default_factory=list)
    indices: list[int] = field(default_factory=list)

    @property
    def vertex_count(self) -> int:
        return len(self.positions) // 3


@dataclass(slots=True)
class PartMesh:
    """A part, split into one surface per distinct colour role."""

    surfaces: list[Surface] = field(default_factory=list)
    bounds_min: tuple[float, float, float] = (0.0, 0.0, 0.0)
    bounds_max: tuple[float, float, float] = (0.0, 0.0, 0.0)

    @property
    def triangle_count(self) -> int:
        return sum(len(s.indices) for s in self.surfaces) // 3

    @property
    def vertex_count(self) -> int:
        return sum(s.vertex_count for s in self.surfaces)

    def size_ldu(self) -> tuple[float, float, float]:
        return tuple(
            self.bounds_max[i] - self.bounds_min[i] for i in range(3)
        )  # type: ignore[return-value]

    def size_mm(self) -> tuple[float, float, float]:
        return tuple(v * LDU_MM for v in self.size_ldu())  # type: ignore[return-value]


def build(mesh: Mesh, *, crease_degrees: float = 45.0) -> PartMesh:
    """Turn a flattened LDraw mesh into indexed, per-colour surfaces.

    Splitting by colour rather than baking a colour per vertex is what
    lets one mesh serve every colour the part was ever moulded in: the
    surface that LDraw marks as colour 16 is recoloured at draw time,
    while a printed pattern's own colours stay fixed.
    """
    normals = compute_normals(mesh, crease_degrees=crease_degrees)

    # Group by (colour, two-sidedness); those are the things that need a
    # separate draw call anyway.
    groups: dict[tuple[int, bool], Surface] = {}
    # Per surface, map a welded (position, normal) to its index.
    lookup: dict[tuple[int, bool], dict[tuple, int]] = {}

    for ti, triangle in enumerate(mesh.triangles):
        key = (triangle.color, triangle.two_sided)
        surface = groups.get(key)
        if surface is None:
            surface = Surface(color=triangle.color, two_sided=triangle.two_sided)
            groups[key] = surface
            lookup[key] = {}
        table = lookup[key]

        for ci, point in enumerate((triangle.a, triangle.b, triangle.c)):
            normal = normals[ti * 3 + ci]
            # Convert to the application's axes as we go: +Y up, and Z
            # negated with it so the handedness — and the winding — hold.
            px, py, pz = point.x, -point.y, -point.z
            nx, ny, nz = normal.x, -normal.y, -normal.z

            vkey = (
                int(round(px * _WELD_SCALE)),
                int(round(py * _WELD_SCALE)),
                int(round(pz * _WELD_SCALE)),
                int(round(nx * _NORMAL_SCALE)),
                int(round(ny * _NORMAL_SCALE)),
                int(round(nz * _NORMAL_SCALE)),
            )
            index = table.get(vkey)
            if index is None:
                index = surface.vertex_count
                table[vkey] = index
                surface.positions += [px, py, pz]
                surface.normals += [nx, ny, nz]
            surface.indices.append(index)

    part = PartMesh(surfaces=_ordered(groups))

    lo, hi = mesh.bounds()
    # Bounds follow the same axis change, so min and max swap on Y and Z.
    part.bounds_min = (lo.x, -hi.y, -hi.z)
    part.bounds_max = (hi.x, -lo.y, -lo.z)
    return part


def _ordered(groups: dict[tuple[int, bool], Surface]) -> list[Surface]:
    """Recolourable surface first, so the common case is surface 0."""
    return sorted(
        groups.values(),
        key=lambda s: (s.color != COLOR_INHERIT, s.color, s.two_sided),
    )


def choose_scale(part: PartMesh) -> float:
    """The finest quantisation step this part's extent fits in 16 bits."""
    extent = max(
        max(abs(v) for v in part.bounds_min),
        max(abs(v) for v in part.bounds_max),
        1e-6,
    )
    for scale in (DEFAULT_SCALE, *FALLBACK_SCALES):
        if extent * scale <= _I16_MAX:
            return scale
    return 1.0


def oct_encode(x: float, y: float, z: float) -> tuple[int, int]:
    """Fold a unit normal onto an octahedron and flatten it to two numbers.

    The unit sphere is projected onto an octahedron and its lower half
    folded outwards into the square [-1,1]^2.  It wastes no bits on
    impossible values the way three separate components do, so two 16-bit
    numbers carry a normal more accurately than three would.
    """
    total = abs(x) + abs(y) + abs(z)
    if total < 1e-12:
        return (0, 0)
    x, y, z = x / total, y / total, z / total
    if z < 0.0:
        x, y = (
            (1.0 - abs(y)) * (1.0 if x >= 0.0 else -1.0),
            (1.0 - abs(x)) * (1.0 if y >= 0.0 else -1.0),
        )
    return (
        max(-_I16_MAX, min(_I16_MAX, int(round(x * _I16_MAX)))),
        max(-_I16_MAX, min(_I16_MAX, int(round(y * _I16_MAX)))),
    )


def oct_decode(qx: int, qy: int) -> tuple[float, float, float]:
    """Inverse of :func:`oct_encode`, for checking the writer."""
    x = qx / _I16_MAX
    y = qy / _I16_MAX
    z = 1.0 - abs(x) - abs(y)
    if z < 0.0:
        x, y = (
            (1.0 - abs(y)) * (1.0 if x >= 0.0 else -1.0),
            (1.0 - abs(x)) * (1.0 if y >= 0.0 else -1.0),
        )
    length = (x * x + y * y + z * z) ** 0.5
    if length < 1e-12:
        return (0.0, 1.0, 0.0)
    return (x / length, y / length, z / length)


def write(part: PartMesh, *, scale: float | None = None) -> bytes:
    """Serialise to the binary format documented at the top of this file."""
    if scale is None:
        scale = choose_scale(part)

    flags = 0
    if any(s.two_sided for s in part.surfaces):
        flags |= FILE_HAS_TWO_SIDED

    out = bytearray()
    out += MAGIC
    out += struct.pack("<HHf", flags, len(part.surfaces), scale)
    out += struct.pack("<6f", *part.bounds_min, *part.bounds_max)

    for surface in part.surfaces:
        count = surface.vertex_count
        surface_flags = SURFACE_TWO_SIDED if surface.two_sided else 0
        out += struct.pack(
            "<hHII", surface.color, surface_flags, count, len(surface.indices)
        )

        vertices = bytearray()
        for n in range(count):
            px = surface.positions[n * 3]
            py = surface.positions[n * 3 + 1]
            pz = surface.positions[n * 3 + 2]
            nx, ny = oct_encode(
                surface.normals[n * 3],
                surface.normals[n * 3 + 1],
                surface.normals[n * 3 + 2],
            )
            vertices += struct.pack(
                "<5h",
                _quantise(px, scale),
                _quantise(py, scale),
                _quantise(pz, scale),
                nx,
                ny,
            )
        out += vertices

        if count <= 0xFFFF:
            out += struct.pack(f"<{len(surface.indices)}H", *surface.indices)
        else:
            out += struct.pack(f"<{len(surface.indices)}I", *surface.indices)

    return bytes(out)


def _quantise(value: float, scale: float) -> int:
    return max(-_I16_MAX, min(_I16_MAX, int(round(value * scale))))


def read(data: bytes) -> PartMesh:
    """Read the format back.  Used by the tests, and by any tooling.

    The runtime has its own reader in GDScript; this one exists so the
    writer can be checked against something that is not itself.
    """
    if data[:4] != MAGIC:
        raise ValueError("not a part mesh file")

    _flags, surface_count, scale = struct.unpack_from("<HHf", data, 4)
    bounds = struct.unpack_from("<6f", data, 12)
    part = PartMesh(bounds_min=bounds[:3], bounds_max=bounds[3:])

    offset = 36
    for _ in range(surface_count):
        color, surface_flags, vertices, indices = struct.unpack_from(
            "<hHII", data, offset
        )
        offset += 12

        surface = Surface(
            color=color, two_sided=bool(surface_flags & SURFACE_TWO_SIDED)
        )
        for _n in range(vertices):
            qx, qy, qz, nx, ny = struct.unpack_from("<5h", data, offset)
            offset += 10
            surface.positions += [qx / scale, qy / scale, qz / scale]
            surface.normals += list(oct_decode(nx, ny))

        if vertices <= 0xFFFF:
            surface.indices = list(struct.unpack_from(f"<{indices}H", data, offset))
            offset += indices * 2
        else:
            surface.indices = list(struct.unpack_from(f"<{indices}I", data, offset))
            offset += indices * 4

        part.surfaces.append(surface)

    return part


def to_ldraw_space(x: float, y: float, z: float) -> Vec3:
    """Invert the axis change, for talking back to LDraw files."""
    return Vec3(x, -y, -z)
