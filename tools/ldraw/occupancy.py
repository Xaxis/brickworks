"""What space a part takes up, on a lattice fine enough to rotate on.

Connection points say where parts *join*.  This says where they *are*,
which is the other half of an assembly engine: whether a placement is
legal, and — because a brick is hollow underneath by construction — where
a stud coming from below can enter.

Why a 2 LDU lattice
-------------------
The obvious grid is the stud pitch, 20 LDU across by 8 LDU per plate.  It
is also wrong, because the moment a part is turned on its side the brick
that was 24 LDU tall is 24 LDU *wide*, and 24 is not a multiple of 20.
Studs-not-on-top building is not an edge case — it is half of how modern
sets are designed — so the lattice has to hold under a quarter turn about
any axis.

That forces the cell to divide every dimension the system uses: 20 for a
stud pitch, 10 for the half-stud offset a jumper plate introduces, 24 for
a brick and 8 for a plate.  Their greatest common divisor is 2, and
nothing coarser works — at 4 LDU a 1x1 brick spans x from -10 to 10 and
straddles cells at both ends, coming out 1.4 studs wide.

2 LDU is 0.8 mm.  A 2x4 brick is 40 by 12 by 20 cells, which is 1.2 kB as
a bitmask.

Studs are not part of the volume
--------------------------------
A stud is meant to end up inside the part above it.  If studs counted
towards occupancy, every brick would be four plates tall instead of
three and nothing could be stacked at all.  So the part is voxelised
whole — which keeps the mesh watertight and the fill honest — and then
the cells that exist only because of a stud are taken away afterwards,
using the stud positions already recovered in connectivity.py.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.ndimage import binary_fill_holes

from .connectivity import ConnectorKind, Gender
from .connectivity import Connection
from .geometry import Mesh

# Lattice pitch in LDU.  See the module docstring for why this and not 20.
CELL = 2.0

# A stud is 12 LDU across and stands 4 LDU proud.  The radius is taken a
# little wide so a cell straddling the stud's edge is still recognised as
# belonging to it.
_STUD_RADIUS = 6.5
_STUD_HEIGHT = 4.0


@dataclass(slots=True)
class Occupancy:
    """Which lattice cells a part fills, and what its underside offers.

    Cells are stored as integer coordinates relative to ``origin``, which
    is itself in whole cells from the part's own origin.  Keeping it
    integral means a placement on the lattice is an integer offset and a
    collision test is an array intersection, with no rounding anywhere.
    """

    origin: tuple[int, int, int]
    shape: tuple[int, int, int]
    # Packed bits, one per cell, in x-fastest order.
    bits: np.ndarray

    @property
    def cell_count(self) -> int:
        return int(np.count_nonzero(self.bits))

    def to_grid(self) -> np.ndarray:
        return self.bits.reshape(self.shape)

    def cells(self) -> list[tuple[int, int, int]]:
        """Occupied cells, in absolute lattice coordinates."""
        grid = self.to_grid()
        xs, ys, zs = np.nonzero(grid)
        ox, oy, oz = self.origin
        return [
            (int(x) + ox, int(y) + oy, int(z) + oz)
            for x, y, z in zip(xs, ys, zs)
        ]

    def size_ldu(self) -> tuple[float, float, float]:
        return tuple(n * CELL for n in self.shape)  # type: ignore[return-value]

    def trim(self) -> "Occupancy":
        """Shrink the grid to the cells that are actually filled.

        Clearing bits — which is what taking the studs away does — leaves
        the allocated extent alone, so a trimmed copy is the only honest
        answer to "how big is this part". It also keeps the stored bitmask
        down to the part rather than its bounding box.
        """
        grid = self.to_grid()
        if not grid.any():
            return Occupancy((0, 0, 0), (0, 0, 0), np.zeros(0, dtype=bool))

        keep = [np.nonzero(grid.any(axis=tuple(a for a in range(3) if a != n)))[0]
                for n in range(3)]
        lo = [int(k[0]) for k in keep]
        hi = [int(k[-1]) + 1 for k in keep]

        cut = grid[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]
        return Occupancy(
            origin=(self.origin[0] + lo[0],
                    self.origin[1] + lo[1],
                    self.origin[2] + lo[2]),
            shape=(cut.shape[0], cut.shape[1], cut.shape[2]),
            bits=cut.reshape(-1).copy(),
        )


def voxelise(mesh: Mesh, *, cell: float = CELL) -> Occupancy:
    """Solid-voxelise a mesh by stabbing a ray up each cell column.

    For every column of cells the triangles crossing it contribute a
    signed crossing — up-facing or down-facing — and the running sum of
    those crossings says whether a height is inside the surface.  Using
    the winding rather than a parity count is what lets it cope with the
    parts whose geometry is not perfectly closed: a missed triangle
    leaves a local error instead of inverting everything above it.
    """
    if not mesh.triangles:
        return Occupancy((0, 0, 0), (0, 0, 0), np.zeros(0, dtype=bool))

    # Into the application's axes (+Y up) as an (N, 3, 3) array.
    tri = np.empty((len(mesh.triangles), 3, 3), dtype=np.float64)
    for n, triangle in enumerate(mesh.triangles):
        for c, point in enumerate((triangle.a, triangle.b, triangle.c)):
            tri[n, c, 0] = point.x
            tri[n, c, 1] = -point.y
            tri[n, c, 2] = -point.z

    lo = tri.reshape(-1, 3).min(axis=0)
    hi = tri.reshape(-1, 3).max(axis=0)

    origin = np.floor(lo / cell + 1e-9).astype(np.int64)
    # No +1: a part spanning x from -40 to 40 occupies cells -20 through 19,
    # which is exactly ceil(hi) - floor(lo). Adding one made every part a
    # cell too large in all three axes.
    extent = np.ceil(hi / cell - 1e-9).astype(np.int64) - origin
    shape = (
        int(max(1, extent[0])), int(max(1, extent[1])), int(max(1, extent[2])))

    grid = np.zeros(shape, dtype=bool)

    # Column centres, so a ray never runs exactly along a shared edge
    # where it could be counted twice or not at all.
    xs = (np.arange(shape[0]) + origin[0] + 0.5) * cell
    zs = (np.arange(shape[2]) + origin[2] + 0.5) * cell

    # Crossings per column, gathered triangle by triangle.
    crossings: dict[tuple[int, int], list[tuple[float, int]]] = {}

    ax, ay, az = tri[:, 0, 0], tri[:, 0, 1], tri[:, 0, 2]
    bx, by, bz = tri[:, 1, 0], tri[:, 1, 1], tri[:, 1, 2]
    cx, cy, cz = tri[:, 2, 0], tri[:, 2, 1], tri[:, 2, 2]

    # Twice the signed area of the triangle projected onto XZ. Its sign is
    # the facing: positive means the triangle's normal has +Y in it.
    area2 = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)

    for n in range(tri.shape[0]):
        if abs(area2[n]) < 1e-12:
            continue  # edge-on to the column direction; contributes nothing

        x0 = min(ax[n], bx[n], cx[n])
        x1 = max(ax[n], bx[n], cx[n])
        z0 = min(az[n], bz[n], cz[n])
        z1 = max(az[n], bz[n], cz[n])

        i0 = max(0, int(np.floor(x0 / cell)) - int(origin[0]))
        i1 = min(shape[0] - 1, int(np.ceil(x1 / cell)) - int(origin[0]))
        k0 = max(0, int(np.floor(z0 / cell)) - int(origin[2]))
        k1 = min(shape[2] - 1, int(np.ceil(z1 / cell)) - int(origin[2]))
        if i0 > i1 or k0 > k1:
            continue

        px = xs[i0 : i1 + 1]
        pz = zs[k0 : k1 + 1]
        gx, gz = np.meshgrid(px, pz, indexing="ij")

        # Barycentric coordinates in the XZ projection.
        w0 = ((bx[n] - gx) * (cz[n] - gz) - (bz[n] - gz) * (cx[n] - gx)) / area2[n]
        w1 = ((cx[n] - gx) * (az[n] - gz) - (cz[n] - gz) * (ax[n] - gx)) / area2[n]
        w2 = 1.0 - w0 - w1

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        if not inside.any():
            continue

        y = w0 * ay[n] + w1 * by[n] + w2 * cy[n]
        direction = 1 if area2[n] > 0 else -1

        for local_i, local_k in zip(*np.nonzero(inside)):
            key = (i0 + int(local_i), k0 + int(local_k))
            crossings.setdefault(key, []).append(
                (float(y[local_i, local_k]), direction))

    y_base = (np.arange(shape[1]) + origin[1] + 0.5) * cell

    for (i, k), hits in crossings.items():
        hits.sort()
        winding = 0
        previous = None
        for height, direction in hits:
            if winding > 0 and previous is not None:
                # Everything between the last entry and here is inside.
                first = np.searchsorted(y_base, previous, side="left")
                last = np.searchsorted(y_base, height, side="right")
                if last > first:
                    grid[i, first:last, k] = True
            winding += direction
            previous = height

    return Occupancy(
        origin=(int(origin[0]), int(origin[1]), int(origin[2])),
        shape=shape,
        bits=grid.reshape(-1).copy(),
    )


def fill_cavities(occupancy: Occupancy) -> Occupancy:
    """Close the voids inside a part, layer by layer.

    Voxelising a brick gives its walls and tubes, because that is what the
    plastic is: the inside is hollow. For collision that is wrong. Nothing
    can be placed inside a brick's cavity — the space is already spoken
    for by the studs of whatever it sits on — so an engine that sees the
    cavity as free will allow a 1x1 brick to be dropped inside a 2x4 one.

    Filling is done one horizontal layer at a time rather than over the
    whole volume, because the cavity is open at the bottom and a 3D fill
    from outside reaches straight into it. In any single layer the same
    cavity is a closed ring of wall, so it fills.

    Taking the layers separately is also what keeps an arch honest: under
    its span the gap runs out to the edge of the part in that layer, so it
    is open to the outside rather than enclosed, and stays open.
    """
    if occupancy.cell_count == 0:
        return occupancy

    grid = occupancy.to_grid().copy()
    for y in range(grid.shape[1]):
        filled = binary_fill_holes(grid[:, y, :])
        if filled is not None:
            grid[:, y, :] = filled

    return Occupancy(
        origin=occupancy.origin, shape=occupancy.shape, bits=grid.reshape(-1))


def remove_studs(
    occupancy: Occupancy, connections: list[Connection], *, cell: float = CELL
) -> Occupancy:
    """Take away the cells that exist only because a stud sticks out.

    A stud belongs to the part above it once they are joined, so it must
    not make this part any taller. Only cells past the stud's own base
    plane *and* inside its barrel are removed, so a stud sitting in a
    recess never erodes the plastic around it.
    """
    studs = [
        c for c in connections
        if c.kind is ConnectorKind.STUD and c.gender is Gender.MALE
    ]
    if not studs or occupancy.cell_count == 0:
        return occupancy

    grid = occupancy.to_grid().copy()
    ox, oy, oz = occupancy.origin
    shape = occupancy.shape

    centres = [
        (np.arange(shape[n]) + (ox, oy, oz)[n] + 0.5) * cell for n in range(3)
    ]
    gx, gy, gz = np.meshgrid(*centres, indexing="ij")

    for stud in studs:
        # connectivity.extract() reports in LDraw's axes, where -Y is up;
        # the grid is in the application's. Flipping Y and Z here keeps the
        # conversion in one place rather than making every caller do it.
        base = np.array([stud.position.x, -stud.position.y, -stud.position.z])
        axis = np.array([stud.axis.x, -stud.axis.y, -stud.axis.z])
        length = np.linalg.norm(axis)
        if length < 1e-9:
            continue
        axis = axis / length

        dx = gx - base[0]
        dy = gy - base[1]
        dz = gz - base[2]

        along = dx * axis[0] + dy * axis[1] + dz * axis[2]
        # Perpendicular distance from the stud's centre line.
        px = dx - along * axis[0]
        py = dy - along * axis[1]
        pz = dz - along * axis[2]
        radial = np.sqrt(px * px + py * py + pz * pz)

        # Past the base plane, inside the barrel, within the stud's height.
        # The bounds are the stud's own extent with no slack: at 2 LDU cells
        # a stud is exactly two rows deep, and half a cell of slack at the
        # base excluded the lower of them, leaving every brick half a plate
        # too tall.
        in_stud = (
            (along > 0.0)
            & (along < _STUD_HEIGHT)
            & (radial < _STUD_RADIUS)
        )
        grid &= ~in_stud

    return Occupancy(
        origin=occupancy.origin, shape=shape, bits=grid.reshape(-1)).trim()


def bottom_sockets(
    occupancy: Occupancy, *, cell: float = CELL, pitch: float = 20.0,
    coverage: float = 0.5,
) -> list[tuple[float, float]]:
    """Stud-lattice positions on the underside that can receive a stud.

    This is the piece the primitives cannot give us. A tube is not a
    socket — it sits *between* four studs and grips them from outside —
    and the smallest parts have no tube at all, just a cavity whose walls
    do the gripping. A 1x1 tile therefore declares no connector anywhere
    while plainly accepting a stud.

    The derivation is a projection with its holes filled. Take the lowest
    plate of the part, flatten it to a 2D mask, and fill the enclosed
    voids: the hollow underside of a brick is exactly such a void, so what
    comes back is the part's real footprint rather than the ring of walls
    that bounds it. Divide that footprint into stud squares and keep the
    ones it covers.

    Filling the holes is what makes this work on long parts. Measuring the
    ring directly, the middle square of a 2x4 brick is only about a third
    filled — two thin walls and a slice of tube — so it lands on whichever
    side of a coverage threshold you pick, and a 2x10 plate reports four
    sockets instead of twenty.

    It also keeps arches honest: under the span of an arch there is no
    material in the lowest plate at all, so that region is open to the
    outside rather than an enclosed void, and no socket is claimed there.
    """
    if occupancy.cell_count == 0:
        return []

    grid = occupancy.to_grid()
    ox, _oy, oz = occupancy.origin

    filled_rows = np.nonzero(grid.any(axis=(0, 2)))[0]
    if filled_rows.size == 0:
        return []

    # The lowest plate: a stud is 4 LDU tall and needs material around it
    # over roughly that depth to be held.
    bottom = int(filled_rows[0])
    plate_cells = max(1, int(round(8.0 / cell)))
    top = min(grid.shape[1], bottom + plate_cells)

    footprint = binary_fill_holes(grid[:, bottom:top, :].any(axis=1))
    if footprint is None or not footprint.any():
        return []

    step = max(1, int(round(pitch / cell)))
    xs, zs = np.nonzero(footprint)
    if xs.size == 0:
        return []

    # The stud grid's phase comes from the part's own footprint, not from a
    # global lattice, because there is no global phase to have: a 2x4 brick
    # puts its studs at odd multiples of 10 LDU and a 1x1 brick puts its one
    # stud at zero. Measuring squares from the part's own edge gets both
    # right, and is what "a brick two studs wide" actually means.
    base_x = int(xs.min())
    base_z = int(zs.min())

    counts: dict[tuple[int, int], int] = {}
    for x, z in zip(xs, zs):
        key = ((int(x) - base_x) // step, (int(z) - base_z) // step)
        counts[key] = counts.get(key, 0) + 1

    needed = coverage * step * step
    sockets: list[tuple[float, float]] = []
    for (kx, kz), filled in counts.items():
        if filled < needed:
            continue
        sockets.append((
            (ox + base_x + kx * step + step * 0.5) * cell,
            (oz + base_z + kz * step + step * 0.5) * cell,
        ))

    return sorted(sockets)


def collides(a: Occupancy, b: Occupancy, offset: tuple[int, int, int]) -> bool:
    """Do two parts overlap, with ``b`` shifted by whole cells?

    Both grids are integral, so this is an array intersection: no
    tolerance, no rounding, and the same answer every time.
    """
    if a.cell_count == 0 or b.cell_count == 0:
        return False

    ga, gb = a.to_grid(), b.to_grid()
    shift = tuple(b.origin[n] + offset[n] - a.origin[n] for n in range(3))

    # The overlapping window in a's coordinates.
    lo = [max(0, shift[n]) for n in range(3)]
    hi = [min(a.shape[n], shift[n] + b.shape[n]) for n in range(3)]
    if any(hi[n] <= lo[n] for n in range(3)):
        return False

    slice_a = ga[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]
    slice_b = gb[
        lo[0] - shift[0]:hi[0] - shift[0],
        lo[1] - shift[1]:hi[1] - shift[1],
        lo[2] - shift[2]:hi[2] - shift[2],
    ]
    return bool(np.any(slice_a & slice_b))


def to_boxes(occupancy: Occupancy, *, limit: int = 64) -> list[tuple[int, ...]]:
    """Cover the occupied cells with a few axis-aligned boxes.

    The grid itself is the honest answer to "does this overlap that", but
    it is also several kilobytes a part, which is a hundred megabytes over
    the library — too much to keep resident just to answer a question that
    a handful of boxes answers as well.

    Nearly every part is a box or a short stack of them: a brick is one, a
    slope is a staircase of four or five, an arch is three. Growing a box
    greedily from each uncovered cell finds those without needing to be
    clever, and the result is exact — every occupied cell is inside some
    box and no box contains an empty cell — so a test against the boxes
    gives the same answer as a test against the grid.

    Returns ``(x, y, z, width, height, depth)`` tuples in absolute lattice
    coordinates. Parts that will not reduce to ``limit`` boxes fall back
    to their bounding box, which over-reports rather than under-reports:
    it can refuse a legal placement but never allows an illegal one.
    """
    if occupancy.cell_count == 0:
        return []

    grid = occupancy.to_grid()
    ox, oy, oz = occupancy.origin
    remaining = grid.copy()
    boxes: list[tuple[int, ...]] = []

    while remaining.any():
        if len(boxes) >= limit:
            xs, ys, zs = np.nonzero(grid)
            return [(
                ox + int(xs.min()), oy + int(ys.min()), oz + int(zs.min()),
                int(xs.max() - xs.min()) + 1,
                int(ys.max() - ys.min()) + 1,
                int(zs.max() - zs.min()) + 1,
            )]

        start = np.argwhere(remaining)[0]
        x0, y0, z0 = (int(v) for v in start)
        x1, y1, z1 = x0 + 1, y0 + 1, z0 + 1

        # Grow along each axis in turn while the slab stays solid. The
        # order matters only for how the boxes come out, not whether the
        # cover is correct, and x-then-z-then-y suits parts that are wide
        # and flat, which most are.
        grown = True
        while grown:
            grown = False
            if x1 < grid.shape[0] and grid[x1, y0:y1, z0:z1].all():
                x1 += 1
                grown = True
            if z1 < grid.shape[2] and grid[x0:x1, y0:y1, z1].all():
                z1 += 1
                grown = True
            if y1 < grid.shape[1] and grid[x0:x1, y1, z0:z1].all():
                y1 += 1
                grown = True

        remaining[x0:x1, y0:y1, z0:z1] = False
        boxes.append((ox + x0, oy + y0, oz + z0, x1 - x0, y1 - y0, z1 - z0))

    return boxes


def boxes_collide(
    a: list[tuple[int, ...]],
    b: list[tuple[int, ...]],
    offset: tuple[int, int, int],
) -> bool:
    """Do two box covers overlap, with ``b`` shifted by whole cells?"""
    for bx, by, bz, bw, bh, bd in b:
        sx, sy, sz = bx + offset[0], by + offset[1], bz + offset[2]
        for ax, ay, az, aw, ah, ad in a:
            if (ax < sx + bw and sx < ax + aw
                    and ay < sy + bh and sy < ay + ah
                    and az < sz + bd and sz < az + ad):
                return True
    return False
