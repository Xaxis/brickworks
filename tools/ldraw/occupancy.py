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

from collections.abc import Iterator
from dataclasses import dataclass

import numpy as np
from scipy.ndimage import binary_fill_holes
from scipy.spatial import ConvexHull, QhullError

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


## How far a column's ray is moved off its cell's middle to tell which side
## of a face the middle is on, LDU: far below anything drawn. See [voxelise].
TIE = 1.3e-4
## How near an edge in plan a moved ray is still on it, LDU: a quarter of
## the move, so a ray moved off an edge is off it and one moved along it
## is not.
ON_EDGE = TIE / 4.0


def voxelise(mesh: Mesh, *, cell: float = CELL) -> Occupancy:
    """Solid-voxelise a mesh by stabbing a ray up each cell column.

    For every column of cells the triangles crossing it contribute a
    signed crossing — up-facing or down-facing — and the running sum of
    those crossings says whether a height is inside the surface.  Using
    the winding rather than a parity count is what lets it cope with the
    parts whose geometry is not perfectly closed: a missed triangle
    leaves a local error instead of inverting everything above it.

    A cell whose middle is on an upright face slanted in plan is inside
    neither side of it. Counted inside, as a cell on any face was, it was
    inside both parts meeting there: four 87375 quarter domes meet on
    seams at 45 degrees (x + z = 30 passes x = 15, z = 15, a cell's
    middle), and overlapped all along them. A face square to x or z keeps
    its cells, and so does a face slanted only in height, as a slope's is:
    60601's pane is drawn from one cell middle to another, and without
    those cells it was a third of itself and stood in its frame touching
    nothing.
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

    grid, touchy = _stab(tri, origin, shape, cell, 0.0, 0.0)
    if touchy.any():
        # Which side of an upright face a column on it is, by moving its ray
        # a hair off it each way along x and along z, in only the columns
        # whose middles are on an edge in plan. On a face square to z,
        # moving along x leaves the ray on it and the two moves agree; on a
        # face square to x, moving along z does. Slanted, neither does.
        moved, on = {}, {}
        for step in ((TIE, 0.0), (-TIE, 0.0), (0.0, TIE), (0.0, -TIE)):
            moved[step], on[step] = _stab(
                tri, origin, shape, cell, *step, touchy, band=ON_EDGE)
        xp, xm = moved[(TIE, 0.0)], moved[(-TIE, 0.0)]
        zp, zm = moved[(0.0, TIE)], moved[(0.0, -TIE)]
        agreed = (xp & xm) | (zp & zm)
        # But a move that leaves the ray on the edge leaves it on the seam
        # between two faces of one surface too, and there the ray crosses
        # both of them: twice in, or twice out. Through a hollow that made
        # the hollow inside: a tyre's tread meets its shoulder on a circle
        # at z = 7, a cell's middle, and the column on it was solid across
        # the tyre's hole, which closed it at both sidewalls and took the
        # wheel holder's pin in. Where the moves along one axis leave the
        # ray off every edge and agree, they are the answer.
        clean_x = ~(on[(TIE, 0.0)] | on[(-TIE, 0.0)])[:, None, :] & ~(xp ^ xm)
        clean_z = ~(on[(0.0, TIE)] | on[(0.0, -TIE)])[:, None, :] & ~(zp ^ zm)
        agreed = np.where(clean_x | clean_z,
                          (clean_x & xp) | (clean_z & zp), agreed)
        grid = np.where(touchy[:, None, :], agreed, grid)

    return Occupancy(
        origin=(int(origin[0]), int(origin[1]), int(origin[2])),
        shape=shape,
        bits=grid.reshape(-1).copy(),
    )


def _stab(
    tri: np.ndarray, origin: np.ndarray, shape: tuple[int, int, int], cell: float,
    dx: float, dz: float, columns: np.ndarray | None = None, *,
    band: float = 2.0 * TIE,
) -> tuple[np.ndarray, np.ndarray]:
    """The cells inside by a ray up each column, ``dx`` and ``dz`` LDU off
    its middle, and the columns whose rays are within ``band`` of an edge
    of a triangle in plan. With ``columns``, only those columns are
    stabbed."""
    xs = (np.arange(shape[0]) + origin[0] + 0.5) * cell + dx
    zs = (np.arange(shape[2]) + origin[2] + 0.5) * cell + dz
    y_base = (np.arange(shape[1]) + origin[1] + 0.5) * cell

    ax, ay, az = tri[:, 0, 0], tri[:, 0, 1], tri[:, 0, 2]
    bx, by, bz = tri[:, 1, 0], tri[:, 1, 1], tri[:, 1, 2]
    cx, cy, cz = tri[:, 2, 0], tri[:, 2, 1], tri[:, 2, 2]

    # Twice the signed area of the triangle projected onto XZ. Its sign is
    # the facing: positive means the triangle's normal has +Y in it.
    area2 = (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
    # How far each barycentric coordinate moves when the ray moves ``band``:
    # the opposite edge's length over the area. A band of twice TIE, to be
    # sure, finds the columns a move of TIE could take across an edge.
    reach = np.stack([np.hypot(bx - cx, bz - cz), np.hypot(cx - ax, cz - az),
                      np.hypot(ax - bx, az - bz)], axis=1)
    reach = band * reach / np.maximum(np.abs(area2), 1e-300)[:, None]

    touchy = np.zeros((shape[0], shape[2]), dtype=bool)
    # Crossings per column, gathered triangle by triangle.
    crossings: dict[tuple[int, int], list[tuple[float, int]]] = {}
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
        wanted = None
        if columns is not None:
            wanted = columns[i0 : i1 + 1, k0 : k1 + 1]
            if not wanted.any():
                continue

        px = xs[i0 : i1 + 1]
        pz = zs[k0 : k1 + 1]
        gx, gz = np.meshgrid(px, pz, indexing="ij")

        # Barycentric coordinates in the XZ projection.
        w0 = ((bx[n] - gx) * (cz[n] - gz) - (bz[n] - gz) * (cx[n] - gx)) / area2[n]
        w1 = ((cx[n] - gx) * (az[n] - gz) - (cz[n] - gz) * (ax[n] - gx)) / area2[n]
        w2 = 1.0 - w0 - w1

        e0, e1, e2 = reach[n]
        near = ((w0 >= -e0) & (w1 >= -e1) & (w2 >= -e2)
                & ((np.abs(w0) <= e0) | (np.abs(w1) <= e1) | (np.abs(w2) <= e2)))
        if wanted is not None:
            near &= wanted
        touchy[i0 : i1 + 1, k0 : k1 + 1] |= near

        inside = (w0 >= 0.0) & (w1 >= 0.0) & (w2 >= 0.0)
        if wanted is not None:
            inside &= wanted
        if not inside.any():
            continue

        y = w0 * ay[n] + w1 * by[n] + w2 * cy[n]
        direction = 1 if area2[n] > 0 else -1

        for local_i, local_k in zip(*np.nonzero(inside)):
            key = (i0 + int(local_i), k0 + int(local_k))
            crossings.setdefault(key, []).append(
                (float(y[local_i, local_k]), direction))

    # Up the column a face at a cell's middle counts on both sides: a part
    # resting on another there is held by the cell under it.
    grid = np.zeros(shape, dtype=bool)
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
    return grid, touchy


## The bore of a Technic pin or axle hole, in LDU.  peghole draws its
## mouth as a ring scaled to 8 with an inner edge at 6, and a pin is
## 4.8 mm across, which is 12 LDU of diameter.
HOLE_RADIUS = 6.0


def fill_cavities(
    occupancy: Occupancy, connections: list[Connection] | None = None
) -> Occupancy:
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

    It is not honest about a Technic hole that runs *vertically*, though,
    and that is what ``connections`` is for.  A horizontal hole reaches
    the edge of the part in its own layer and survives; a vertical one is
    a closed circle in every layer it passes through, so it filled, and
    every Technic liftarm in the library came out solid.  A pin pushed
    into one read as a collision — which is most of modern Technic
    refused outright, since the beam is what the rest bolts to.

    So where a connector says there is a hole, the hole's bore is cleared.

    Clearing only the *fill's* additions was the first attempt and is not
    enough.  A Technic brick's hole is drawn as two peghole mouths with a
    negative cylinder between them, and the negative is surface like any
    other to a voxeliser: part 3700 came out open at both mouths and
    solid through the middle, which is exactly as unusable as being solid
    throughout.  Its hole was never a cavity the fill closed, so there
    was nothing to put back.

    The cost of clearing outright is that a connector is now trusted
    against the geometry: a wrongly detected hole carves a 12 LDU channel
    through a part that has none.  That is why the connector table is
    classified from each primitive's own description rather than its
    filename, and why holes are counted against the parts whose names
    state how many they have.  The bore is also clamped to the part's own
    cells, so a hole on a surface cannot reach beyond the plastic.

    A hole drawn without a peghole is cleared too: see [holes].

    And a bar in a loop is given back the air round it: see [bars].
    """
    if occupancy.cell_count == 0:
        return occupancy

    before = occupancy.to_grid()
    found = holes(connections or [])
    bores = _bore(occupancy, found, whole_line=False) if found else None
    # The holes plugged while it fills: a hole through a wall into a cavity
    # opens the cavity to the outside in the layers it crosses, and they
    # stayed hollow. 18897, a 6 x 6 round brick with a hole in each side,
    # was hollow 12 LDU deep all round once its cover was exact. The bores
    # are cleared again below.
    grid = before.copy() if bores is None else before | bores
    for y in range(grid.shape[1]):
        filled = binary_fill_holes(grid[:, y, :])
        if filled is not None:
            grid[:, y, :] = filled

    # A hole right through the part, top to bottom, is a closed ring in
    # every layer too, and filled like a brick's underside — but nothing is
    # spoken for in it: a ring plate's middle, a round plate's opening, a
    # tyre lying flat. Where a column holds no plastic at any height, its
    # fill is taken back: a brick's cavity has the brick's top over it. Not
    # on a stud's line, though: a stud below is held by the plastic just
    # past its tip, and 3062b, a round brick bored through its open stud,
    # stood on nothing once its bore was open.
    through = ~before.any(axis=1) & ~_stud_lines(occupancy, connections or [])
    grid &= ~(through[:, None, :] & ~before)

    if bores is not None:
        grid = grid & ~bores

    for window, room in _clip_rooms(occupancy, bars(connections or []), before):
        grid[window] &= ~(room & ~before[window])

    return Occupancy(
        origin=occupancy.origin, shape=occupancy.shape, bits=grid.reshape(-1))


## How far from a stud's or a tube's upright line a through hole is kept
## filled, in LDU: a stud's radius and a cell.
STUD_CLEAR = 8.0


def _stud_lines(occupancy: Occupancy, connections: list[Connection]) -> np.ndarray:
    """The columns (x, z) within STUD_CLEAR of an upright stud, tube or ridge
    of the part's: where a stud goes, and is held by finding plastic."""
    shape = occupancy.shape
    near = np.zeros((shape[0], shape[2]), dtype=bool)
    xs = (np.arange(shape[0]) + occupancy.origin[0] + 0.5) * CELL
    zs = (np.arange(shape[2]) + occupancy.origin[2] + 0.5) * CELL
    gx, gz = np.meshgrid(xs, zs, indexing="ij")
    for c in connections:
        if c.kind not in (ConnectorKind.STUD, ConnectorKind.TUBE, ConnectorKind.RIDGE) \
                or abs(c.axis.y) < 0.99:
            continue
        # Connections are in LDraw's axes; the grid's z is LDraw's turned.
        near |= (gx - c.position.x) ** 2 + (gz + c.position.z) ** 2 <= STUD_CLEAR * STUD_CLEAR
    return near


## A bar's radius, in LDU: 3.2 mm across, within BAR_FIT.
BAR_RADIUS = 4.0
BAR_FIT = 0.5
## How far from a bar's axis a clip on it reaches, in LDU. A clip's ring is
## 4 inside, and the thick clips (clip7, clip12, clip13) are 7.6 at their
## widest, clip16 8.1.
CLIP_REACH = 8.0


@dataclass(slots=True)
class Bar:
    """A bar a clip goes on, in the application's axes."""

    point: np.ndarray
    axis: np.ndarray                 # unit
    length: float


def bars(connections: list[Connection]) -> list[Bar]:
    """Every bar a clip could be put on, across the stud axis.

    A handle is a bar held off a part at both ends: 2540's runs beside
    its plate, an arm at each end. In the plate's own layers the plate's
    edge, the arms and the bar close a ring of plastic round the gap a
    clip goes into, so the fill closed it, and the bar was buried in
    cover a clip could not go round. That is the same for every bar in a
    loop beside a part, under it or at its end.

    So where nothing but air and the fill is within CLIP_REACH of a bar
    along its length, which is room for a clip, the fill there is taken
    back out ([_clip_rooms]). Only the fill's: the bar, the arms and the
    part are plastic and stay, and a bar in the open has none to take.

    Not along the stud axis. An upright bar's layers are rounds across it,
    and a loop beside it is open in each one, so the fill never closed
    one (2921, a brick with an upright handle, was always open). What it
    does close round an upright round is a brick's underside: the post of
    a 1 x 2 is a bar's size, and the studs of what it stands on are held
    by the plastic round it (see [holes]).
    """
    out: list[Bar] = []
    for c in connections:
        if (c.kind is not ConnectorKind.SHAFT
                or abs(c.radius - BAR_RADIUS) > BAR_FIT
                or abs(c.axis.y) >= 0.99 or c.length <= 0.0):
            continue
        axis = np.array([c.axis.x, -c.axis.y, -c.axis.z])
        length = float(np.linalg.norm(axis))
        if length < 1e-9:
            continue
        out.append(Bar(
            point=np.array([c.position.x, -c.position.y, -c.position.z]),
            axis=axis / length, length=c.length))
    return out


def _clip_rooms(
    occupancy: Occupancy, gripped: list[Bar], plastic: np.ndarray,
) -> Iterator[tuple[tuple[slice, ...], np.ndarray]]:
    """Each bar with room round it for a clip, as the window of the grid it
    is in and the cells within CLIP_REACH of its axis, along it, there.

    Room is no ``plastic`` between the bar's own cells and CLIP_REACH. A
    shaft a bar's size with plastic that close round it is not a bar a
    clip goes on: the pin of a minifigure's hip inside its legs, a
    pneumatic pump's rod inside its cylinder. Their cavities stay filled,
    as every cavity does.
    """
    ox, oy, oz = occupancy.origin
    shape = occupancy.shape
    centres = [
        (np.arange(shape[n]) + (ox, oy, oz)[n] + 0.5) * CELL for n in range(3)
    ]
    for bar in gripped:
        far = bar.point + bar.axis * bar.length
        # Only the box the bar and its clip can reach: a handle's bar is a
        # few cells across a grid of hundreds.
        window = []
        for n in range(3):
            low = (min(bar.point[n], far[n]) - CLIP_REACH) / CELL - (ox, oy, oz)[n]
            high = (max(bar.point[n], far[n]) + CLIP_REACH) / CELL - (ox, oy, oz)[n]
            window.append(slice(max(0, int(np.floor(low))),
                                min(shape[n], int(np.ceil(high)) + 1)))
        if any(w.start >= w.stop for w in window):
            continue
        local = [centres[n][window[n]] for n in range(3)]
        gx, gy, gz = np.meshgrid(*local, indexing="ij")
        dx, dy, dz = gx - bar.point[0], gy - bar.point[1], gz - bar.point[2]
        along = dx * bar.axis[0] + dy * bar.axis[1] + dz * bar.axis[2]
        px = dx - along * bar.axis[0]
        py = dy - along * bar.axis[1]
        pz = dz - along * bar.axis[2]
        off = px * px + py * py + pz * pz
        room = (off <= CLIP_REACH * CLIP_REACH) & (along >= 0.0) & (along <= bar.length)
        # The bar's own cells are those whose middles are in it, and the
        # nearest middles outside it are a cell's half diagonal further.
        ring = room & (off > (BAR_RADIUS + CELL * 0.5) ** 2)
        held = tuple(window)
        if plastic[held][ring].any():
            continue
        yield held, room


## How far a drawn hole's radius may be from a pin's, in LDU. 6222's and
## 18897's holes are 6 exactly; a clip's eye, which a bar goes in, is 4.
DRAWN_HOLE_FIT = 0.5


@dataclass(slots=True)
class Hole:
    """A hole a pin or an axle goes into, in the application's axes."""

    point: np.ndarray
    axis: np.ndarray                 # unit
    # Where along the axis from point the hole runs, or None for the whole
    # line through the part (a peghole primitive says where its mouth is,
    # not how deep it goes).
    span: tuple[float, float] | None
    # How far from the axis it reaches: a pin's, or a tyre's ([wide_bores]).
    radius: float = HOLE_RADIUS


def holes(connections: list[Connection]) -> list[Hole]:
    """Every hole a pin or an axle goes into, however it was drawn.

    Most are drawn from Technic primitives, and a connector says so. Some
    are not: the four side holes of 6222, a 4x4 round brick, and of
    18897, a 6x6 one, are plain cylinders turned inside out, with nothing
    named peghole anywhere in the file. So their bores were never
    cleared, and where 6222's meets the tube inside the brick the
    voxeliser and the fill closed the inner 6 LDU of it: 48 of the 128
    cells within 5 LDU of its axis were solid.

    connectivity.rounds already finds such a hole as a bore, and the rule
    for one being a hole a pin goes into is its shape:

    - a pin's radius, within DRAWN_HOLE_FIT;
    - all the way round, where the underside of a curved top is half a
      bore of the same radius and is not a hole into anything;
    - not along the stud axis, because a round hole there is a tube or
      an anti-stud, which is where a *stud* goes, and a stud is held by
      finding plastic just past its tip. Clearing those would leave every
      round 1x1 brick floating on the stud it sits on;
    - and not filled by the part's own pin, as the eye of a hinge that
      comes complete with its pin is.

    It is cleared along its own length only, unlike a peghole's whole
    line: 6222's opposite holes share an axis, and the line between them
    crosses the tube in the middle of the brick.
    """
    out: list[Hole] = []
    shafts = [c for c in connections if c.kind is ConnectorKind.SHAFT]
    for c in connections:
        if c.kind in (ConnectorKind.PIN_HOLE, ConnectorKind.AXLE_HOLE):
            span = None
        elif (c.kind is ConnectorKind.BORE
              and abs(c.radius - HOLE_RADIUS) <= DRAWN_HOLE_FIT
              and c.arc >= 1.0 - 1e-6 and abs(c.axis.y) < 0.99
              and not any(_fills(s, c) for s in shafts)):
            span = (0.0, c.length)
        else:
            continue
        # extract() reports in LDraw's axes, where -Y is up, and the grid
        # is in the application's; remove_studs flips the same way.
        axis = np.array([c.axis.x, -c.axis.y, -c.axis.z])
        length = float(np.linalg.norm(axis))
        if length < 1e-9:
            continue
        out.append(Hole(
            point=np.array([c.position.x, -c.position.y, -c.position.z]),
            axis=axis / length, span=span))
    return out


## A bore wider than this, in LDU, is wider than any pin's hole: a tyre's,
## round the rim that fills it.
WIDE_BORE = 7.0
## How far inside a wide bore's round a cell's middle may lie and the bore
## still be the part's innermost there, in LDU: under a cell's half diagonal.
WIDE_SLACK = 1.5


def wide_bores(occupancy: Occupancy, connections: list[Connection]) -> list[Hole]:
    """Every tyre's hole: a bore wider than a pin's, all the way round,
    across the stud axis, with nothing of the part inside it along its
    length but a cell at either end, where the part's own faces meet it.

    Its cover keeps it open ([to_boxes]), as it keeps a Technic hole open.
    A tyre is a ring, so its convex hull is a disc, and a tyre past the box
    limit was covered at a coarser grain inside that hull: its hole was
    filled. 18450's, 41893's and 23798's held tens of thousands of cells, so
    no rim could go in. A round brick's hollow is along the stud axis and a
    hub's bore has the hub's axle in it, so neither is one.

    Each bore is one, and the bores on one line are one more, from the first
    one's start to the last one's end at the narrowest of them: a tyre's
    hole is often two bores at its shoulders and a narrower one between,
    joined by cones that are no bore (50951's: 14, 12 and 14 LDU).

    Only a hole through the part, square to it: the bores on its line reach
    from one face of the part to the other, to within WIDE_FACE. A shell's
    round hollow is a bore and nothing is inside it, but it is no hole a rim
    goes through: carved from 30117's cover, a quarter saucer, it was 1,256
    boxes where it had been one.
    """
    if occupancy.cell_count == 0:
        return []
    grid = occupancy.to_grid()
    out: list[Hole] = []
    for c in connections:
        if (c.kind is not ConnectorKind.BORE or c.radius <= WIDE_BORE
                or c.arc < 1.0 - 1e-6 or abs(c.axis.y) >= 0.99 or c.length <= 0.0):
            continue
        axis = np.array([c.axis.x, -c.axis.y, -c.axis.z])
        length = float(np.linalg.norm(axis))
        if length < 1e-9:
            continue
        hole = Hole(point=np.array([c.position.x, -c.position.y, -c.position.z]),
                    axis=axis / length, span=(0.0, c.length), radius=c.radius)
        if _filled_inside(occupancy, grid, hole):
            continue
        out.append(hole)
    # The bores on one line, as one at the narrowest of them.
    lines: list[Hole] = []
    for hole in out:
        for line in lines:
            if abs(float(line.axis @ hole.axis)) < 0.999:
                continue
            gap = hole.point - line.point
            if np.linalg.norm(gap - line.axis * float(gap @ line.axis)) > 1.5:
                continue
            a = float(gap @ line.axis)
            b = a + (hole.span[1] - hole.span[0]) * float(hole.axis @ line.axis)
            assert line.span is not None
            line.span = (min(line.span[0], a, b), max(line.span[1], a, b))
            line.radius = min(line.radius, hole.radius)
            break
        else:
            lines.append(Hole(point=hole.point.copy(), axis=hole.axis.copy(),
                              span=hole.span, radius=hole.radius))
    through = [line for line in lines if _through(occupancy, grid, line)]
    kept = [hole for hole in out if any(_on_line(hole, line) for line in through)]
    return kept + [line for line in through if not _filled_inside(occupancy, grid, line)]


## How far in from a face of the part a hole through it may start, in LDU:
## a tyre's sidewall is drawn as a ring at its face, its bores from there.
WIDE_FACE = 2.0 * CELL


def _through(occupancy: Occupancy, grid: np.ndarray, line: Hole) -> bool:
    """Whether the bores on a line reach through the part, square to it."""
    square = [n for n in range(3) if abs(line.axis[n]) > 0.999]
    if not square or line.span is None:
        return False
    n = square[0]
    filled = np.nonzero(grid.any(axis=tuple(a for a in range(3) if a != n)))[0]
    if filled.size == 0:
        return False
    low = (occupancy.origin[n] + int(filled[0])) * CELL
    high = (occupancy.origin[n] + int(filled[-1]) + 1) * CELL
    ends = [line.point[n] + line.axis[n] * s for s in line.span]
    return min(ends) <= low + WIDE_FACE and max(ends) >= high - WIDE_FACE


def _on_line(hole: Hole, line: Hole) -> bool:
    """Whether a bore is one of a line's."""
    if abs(float(line.axis @ hole.axis)) < 0.999:
        return False
    gap = hole.point - line.point
    return bool(np.linalg.norm(gap - line.axis * float(gap @ line.axis)) <= 1.5)


def _filled_inside(occupancy: Occupancy, grid: np.ndarray, hole: Hole) -> bool:
    """Whether any cell of the part is inside a wide bore, a cell in from
    either end of it and WIDE_SLACK in from its round."""
    assert hole.span is not None
    low, high = hole.span[0] + CELL, hole.span[1] - CELL
    if high <= low:
        return False
    inner = Hole(point=hole.point, axis=hole.axis, span=(low, high),
                 radius=hole.radius - WIDE_SLACK)
    return bool((_bore(occupancy, [inner], whole_line=False) & grid).any())


def _fills(shaft: Connection, bore: Connection) -> bool:
    """Whether a part's own shaft stands inside one of its bores."""
    if shaft.radius < bore.radius - 1.0 or shaft.radius > bore.radius + DRAWN_HOLE_FIT:
        return False
    if abs(shaft.axis.dot(bore.axis)) < 0.999:
        return False
    gap = shaft.position - bore.position
    if (gap - bore.axis * gap.dot(bore.axis)).length() > 1.0:
        return False
    a = gap.dot(bore.axis)
    b = a + shaft.length * shaft.axis.dot(bore.axis)
    return min(max(a, b), bore.length) - max(min(a, b), 0.0) > 1.0


def _bore(occupancy: Occupancy, found: list[Hole], *, whole_line: bool) -> np.ndarray:
    """The cells within a hole's radius of its axis, as a mask of the grid."""
    ox, oy, oz = occupancy.origin
    shape = occupancy.shape
    centres = [
        (np.arange(shape[n]) + (ox, oy, oz)[n] + 0.5) * CELL for n in range(3)
    ]
    bore = np.zeros(shape, dtype=bool)
    for hole in found:
        point, axis = hole.point, hole.axis
        # Only the slab the hole can possibly touch, which for an
        # axis-aligned hole is a few cells across.  Testing the whole
        # grid per hole made the 19x11 Technic baseplate — 209 holes
        # over a 110x12x190 grid — take 0.87s to fill where it took
        # 0.01s before, and it is the same answer either way.
        # A hole at an angle to the grid has no thin slab: its channel
        # runs diagonally, so the whole grid is the honest window.
        # Rare — a handful of parts in the library — and correctness
        # there is worth more than the speed, which is what the whole
        # fast path is guarding.
        square = max(abs(axis[0]), abs(axis[1]), abs(axis[2])) > 0.99
        window = []
        for n in range(3):
            if not square or abs(axis[n]) > 0.99:
                window.append(slice(0, shape[n]))
                continue
            middle = point[n] / CELL - (ox, oy, oz)[n]
            reach = (hole.radius / CELL) + 1.0
            window.append(slice(
                max(0, int(np.floor(middle - reach))),
                min(shape[n], int(np.ceil(middle + reach)) + 1)))
        if any(w.start >= w.stop for w in window):
            continue

        local = [centres[n][window[n]] for n in range(3)]
        gx, gy, gz = np.meshgrid(*local, indexing="ij")
        dx, dy, dz = gx - point[0], gy - point[1], gz - point[2]
        along = dx * axis[0] + dy * axis[1] + dz * axis[2]
        # Perpendicular distance to the hole's axis line.
        px = dx - along * axis[0]
        py = dy - along * axis[1]
        pz = dz - along * axis[2]
        inside = (px * px + py * py + pz * pz) <= hole.radius * hole.radius
        if hole.span is not None and not whole_line:
            inside &= (along >= hole.span[0]) & (along <= hole.span[1])
        bore[window[0], window[1], window[2]] |= inside
    return bore


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


def to_boxes(
    occupancy: Occupancy, connections: list[Connection] | None = None,
    *, limit: int = 64,
) -> list[tuple[int, ...]]:
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
    coordinates. Parts that will not reduce to ``limit`` boxes are covered
    at a coarser grain (COARSE_GRAINS), and past that by their bounding
    box, each of which over-reports rather than under-reports: it can
    refuse a legal placement but never allows an illegal one.

    Except in a hole. A refused placement there is not a rare one, it is
    the one the hole exists for. Of the 2,790 parts built before this with
    a pin or axle hole a Technic primitive declares, 2,104 had one filled
    solid this way, and none any other way: a beam takes about ten boxes a
    hole (beam 5 is 54, beam 7 72), so every Technic beam from 7 up and
    every Technic brick from 1 x 8 up was a solid bar, and 6222 and 18897,
    round bricks whose sides are four Technic holes, were solid drums.

    So a hole brings its own boxes: a part may take HOLE_BOXES more for
    each hole it has ([holes], from ``connections``). That keeps the
    cover exact for Technic beams 7 to 15 (72 to 144 boxes), Technic
    bricks 1 x 8 to 1 x 16 and 6222 (118). Past it the cover is the
    bounding box everywhere but on a hole's line, where it is the part's
    own cells: the hole, and the air a pin comes in through. 18897 is 330
    boxes exact and 42 so.

    A bar with room for a clip round it is the same ([bars]): BAR_BOXES
    more for each, and past that its room is carved like a hole's line.
    """
    if occupancy.cell_count == 0:
        return []

    grid = occupancy.to_grid()
    found = holes(connections or [])
    rooms = list(_clip_rooms(occupancy, bars(connections or []), grid))
    allowed = min(limit + HOLE_BOXES * len(found) + BAR_BOXES * len(rooms),
                  CARVED_LIMIT)
    boxes = _greedy(grid, occupancy.origin, allowed)
    if boxes is not None:
        return boxes

    xs, ys, zs = np.nonzero(grid)
    bounds = np.zeros(grid.shape, dtype=bool)
    bounds[xs.min():xs.max() + 1, ys.min():ys.max() + 1, zs.min():zs.max() + 1] = True
    # A curve whose bounding box is mostly air keeps its own cells, as many
    # boxes as that takes up to CARVED_LIMIT: its box would claim the room
    # the curve goes round. A quarter of a 140 tooth ring is 472 boxes
    # exact; as its box it was solid inside, and the pinion that drives it
    # from there, and everything else a ring goes round, overlapped it.
    if bounds.sum() > MOSTLY_AIR * grid.sum():
        exact = _greedy(grid, occupancy.origin, CARVED_LIMIT)
        if exact is not None:
            return exact
    whole = _greedy(bounds, occupancy.origin, 1)
    carved = None
    # And a tyre's hole, which a rim fills ([wide_bores]).
    wide = wide_bores(occupancy, connections or [])
    if found or rooms or wide:
        carved = _bore(occupancy, found, whole_line=True)
        if wide:
            carved |= _bore(occupancy, wide, whole_line=False)
        for window, room in rooms:
            carved[window] |= room

    # A shell — a dome, a dish, a windscreen, a cockpit — is thousands of
    # boxes at full grain, and its bounding box fills its inside: 87375, a
    # quarter dome, was one solid box, so the clips that hold its handles
    # and anything under the dome collided with it, and the dome the owner's
    # session asked for could not be built. Coarser grains keep the inside
    # open and over-report only near the surface: 87375 is 2,198 boxes at
    # 2 LDU, 630 at 4. The finest that fits COARSE_LIMIT is kept. Near a
    # bar or a hole it stays exact, because that is where another part
    # comes close: a 61252 holding 87375's handle stands 4 LDU from the
    # handle's knuckle, and at 8 LDU the dome's cover was in it.
    exact = _near_lines(occupancy, [(b.point, b.axis, 0.0, b.length) for b in bars(
        connections or [])] + [(h.point, h.axis, *(h.span or (-HOLE_LINE, HOLE_LINE)))
                               for h in found], JOINT_ROOM)
    # And never outside the part's convex hull: the blocks then over-report
    # only into the hollow of a shell, never across its outside or the flat
    # faces it meets its neighbours on. Four 87375s meet edge to edge on
    # planes at 45 degrees, and blocks reaching across those were each in
    # the next quarter.
    hull = _in_hull(grid)
    for grain in COARSE_GRAINS:
        blocky = (_blocky(grid, grain) & bounds & hull & ~exact) | (grid & exact)
        if carved is not None:
            blocky &= ~(carved & ~grid)
        boxes = _greedy(blocky, occupancy.origin, COARSE_LIMIT)
        if boxes is not None:
            return boxes

    if carved is None:
        return whole or []
    bounds &= ~(carved & ~grid)
    return _greedy(bounds, occupancy.origin, CARVED_LIMIT) or whole or []


## How many times its own cells a part's bounding box must be before it is
## too much air to stand for the part: past it the part keeps an exact
## cover however many boxes that takes (up to CARVED_LIMIT). 24121, a
## quarter of a ring of 140, is 7.6.
MOSTLY_AIR = 3.0
## The grains, in cells, a cover past its limit is tried at before its
## bounding box: 2 (exact, given more boxes), 4, 6, 8, 12 and 16 LDU.
COARSE_GRAINS = (1, 2, 3, 4, 6, 8)
## The most boxes a cover past its limit may take at a grain: past it, the
## next grain. 58846, the 10 x 10 tapered quarter ring, is exact at 712.
COARSE_LIMIT = 768
## How far from a bar's or a hole's line a coarse cover stays exact, LDU:
## the plate of a clip on the bar, 20 from its eye.
JOINT_ROOM = 24.0
## How far along a hole's line it does, either side of its middle, for a
## hole the connectors give no depth: through the part.
HOLE_LINE = 40.0


def _in_hull(grid: np.ndarray) -> np.ndarray:
    """The cells whose middles are inside the flat faces of the occupied
    cells' convex hull: every occupied cell, and none past a face the part
    is cut flat on (a quarter dome's seams and rim, a quarter ring's ends).
    Only the big flat faces: clipped to a curve as well, a shell's blocks
    come out a staircase of boxes (87375: 1,883 at 4 LDU, 693 without), and
    a curve meets no neighbour flush. All of them where the cells are too
    few or too flat for a hull."""
    points = np.argwhere(grid).astype(float) + 0.5
    whole = np.ones(grid.shape, dtype=bool)
    if len(points) < 4:
        return whole
    try:
        hull = ConvexHull(points)
    except (QhullError, ValueError):
        return whole
    # The hull's triangles, gathered by the plane they nearly lie in: a flat
    # face at 45 degrees is a staircase of cells, and its hull a fan of
    # facets a few degrees apart.
    planes: dict[tuple, list] = {}
    for simplex, equation in zip(hull.simplices, hull.equations):
        a, b, c = points[simplex]
        area = 0.5 * float(np.linalg.norm(np.cross(b - a, c - a)))
        key = tuple(np.round(equation[:3] * 10.0).astype(int))
        entry = planes.setdefault(key, [[], 0.0])
        entry[0].append(equation)
        entry[1] += area
    total = sum(entry[1] for entry in planes.values())
    centres = np.indices(grid.shape).reshape(3, -1).T.astype(float) + 0.5
    inside = np.ones(len(centres), dtype=bool)
    for equations, area in planes.values():
        if area < FLAT_FACE * total:
            continue
        # Each facet bounds every occupied cell, so cutting by all of them
        # loses none. A little slack, for a cell on the face.
        for equation in equations:
            inside &= centres @ equation[:3] + equation[3] <= 1e-6
    return inside.reshape(grid.shape) | grid


## The share of a hull's surface a flat face must be to cut a coarse cover.
FLAT_FACE = 0.02


def _near_lines(occupancy: Occupancy, lines: list, reach: float) -> np.ndarray:
    """The cells whose middles are within ``reach`` of any of ``lines``,
    each (point, unit axis, from, to) in LDU along it, application axes."""
    shape = occupancy.shape
    out = np.zeros(shape, dtype=bool)
    if not lines:
        return out
    centres = [(np.arange(shape[n]) + occupancy.origin[n] + 0.5) * CELL for n in range(3)]
    gx, gy, gz = np.meshgrid(*centres, indexing="ij")
    for point, axis, low, high in lines:
        dx, dy, dz = gx - point[0], gy - point[1], gz - point[2]
        along = np.clip(dx * axis[0] + dy * axis[1] + dz * axis[2], low, high)
        px, py, pz = dx - along * axis[0], dy - along * axis[1], dz - along * axis[2]
        out |= px * px + py * py + pz * pz <= reach * reach
    return out


def _blocky(grid: np.ndarray, grain: int) -> np.ndarray:
    """Every block of grain cells a side, from the grid's corner, that has a
    cell occupied, occupied whole."""
    sx, sy, sz = grid.shape
    padded = np.pad(grid, ((0, (-sx) % grain), (0, (-sy) % grain), (0, (-sz) % grain)))
    blocks = padded.reshape(padded.shape[0] // grain, grain, padded.shape[1] // grain,
                            grain, padded.shape[2] // grain, grain).any(axis=(1, 3, 5))
    return blocks.repeat(grain, 0).repeat(grain, 1).repeat(grain, 2)[:sx, :sy, :sz]


## The boxes a hole is allowed on top of the limit. Opening a hole costs
## a few — 54754, a train motor, went from 63 to 70 for its four — and
## without them a part a few over the limit lost its exact cover for
## having its holes opened. A Technic beam is about ten a hole.
HOLE_BOXES = 16
## And a bar with room round it. Opening the loops of a sprue's bars took
## 6246, six minifig tools on one, from 35 boxes to 229 for its nine bars,
## 21.6 a bar; no other part opened more than 14 a bar.
BAR_BOXES = 24


## The most boxes a bounding box with its holes carved may take. A hole
## square to the grid costs about four (median 4, 90th percentile 9, over
## all 2,427 parts that were bounding boxes, carved); a hole at an angle
## runs a staircase through the whole box. Past this, four parts — two palm
## trees and a dragon that come assembled, and a Y-branch of car track —
## keep their bounding box, holes and all, rather than carry 2,500 to
## 3,100 boxes into every collision test they are part of. The most any
## other part takes is 1,444.
CARVED_LIMIT = 2048


def _greedy(
    grid: np.ndarray, origin: tuple[int, int, int], limit: int | None,
) -> list[tuple[int, ...]] | None:
    """Boxes over a grid's cells, or None past ``limit`` of them."""
    ox, oy, oz = origin
    remaining = grid.copy()
    boxes: list[tuple[int, ...]] = []

    while remaining.any():
        if limit is not None and len(boxes) >= limit:
            return None

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
