"""Flattening an LDraw reference tree into a renderable mesh.

A part file is a tree of subfile references, each with its own transform,
bottoming out in triangles and quads.  Producing a mesh means walking that
tree, composing transforms, and resolving two things that are easy to get
subtly wrong:

Winding (BFC)
    LDraw's back-face culling extension declares which way round a file's
    polygons are wound.  Three things can reverse the winding a polygon
    *appears* to have: the file declaring ``BFC CW`` instead of ``CCW``, a
    ``BFC INVERTNEXT`` before a subfile reference, and a transform whose
    determinant is negative (a mirror).  These compose, and they compose by
    XOR, so a mirrored reference inside an inverted one cancels out.  Get
    this wrong and parts render inside-out in a way that is invisible with
    two-sided materials and glaring with one-sided ones.

Shading
    Naively smoothing every shared vertex normal turns the crisp corner of
    a brick into a soft blob; not smoothing at all turns a cylinder into a
    faceted drum.  LDraw resolves this for us: authors draw explicit type-2
    edge lines exactly where a hard crease belongs.  So the rule is smooth
    everywhere *except* across a segment that has an edge line on it, which
    is what LDView and Studio do and why their parts look right.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from .library import Detail, Library
from .parser import (
    COLOR_EDGE_INHERIT,
    COLOR_INHERIT,
    EdgeLine,
    Matrix,
    MetaLine,
    OptionalLine,
    Polygon,
    SubfileRef,
    Vec3,
)

# Positions are snapped to this many LDU when deciding whether two vertices
# are "the same" for smoothing.  1 LDU is 0.4 mm, so 1e-3 LDU is 0.4 micron:
# far below any real feature, far above float noise from composing a dozen
# transforms.
_WELD_TOLERANCE = 1e-3
_WELD_SCALE = 1.0 / _WELD_TOLERANCE


def _key(p: Vec3) -> tuple[int, int, int]:
    return (
        int(round(p.x * _WELD_SCALE)),
        int(round(p.y * _WELD_SCALE)),
        int(round(p.z * _WELD_SCALE)),
    )


@dataclass(slots=True)
class Triangle:
    a: Vec3
    b: Vec3
    c: Vec3
    color: int
    # False when the polygon came from a file that is not BFC certified, so
    # the renderer must not cull it.
    two_sided: bool = False

    def normal(self) -> Vec3:
        n = (self.b - self.a).cross(self.c - self.a)
        length = n.length()
        if length < 1e-12:
            return Vec3(0.0, 0.0, 0.0)
        return n * (1.0 / length)

    def area(self) -> float:
        return (self.b - self.a).cross(self.c - self.a).length() * 0.5


@dataclass(slots=True)
class Mesh:
    """Flattened geometry for one part, still in LDraw coordinates and LDU."""

    triangles: list[Triangle] = field(default_factory=list)
    # Hard-crease segments, as welded endpoint key pairs, from type-2 lines.
    edges: set[tuple[tuple[int, int, int], tuple[int, int, int]]] = field(
        default_factory=set
    )
    # Type-5 conditional edges, kept for outline rendering.
    optional_edges: list[tuple[Vec3, Vec3, Vec3, Vec3]] = field(default_factory=list)
    # Names that could not be resolved, so a build can report coverage.
    missing: set[str] = field(default_factory=set)

    def bounds(self) -> tuple[Vec3, Vec3]:
        if not self.triangles:
            return Vec3(0, 0, 0), Vec3(0, 0, 0)
        lo = [math.inf] * 3
        hi = [-math.inf] * 3
        for t in self.triangles:
            for p in (t.a, t.b, t.c):
                for i, v in enumerate((p.x, p.y, p.z)):
                    if v < lo[i]:
                        lo[i] = v
                    if v > hi[i]:
                        hi[i] = v
        return Vec3(*lo), Vec3(*hi)


def _resolve_color(child: int, inherited: int, inherited_edge: int) -> int:
    """Map a subfile's colour code through the inheritance rules."""
    if child == COLOR_INHERIT:
        return inherited
    if child == COLOR_EDGE_INHERIT:
        return inherited_edge
    return child


def _add_polygon(
    mesh: Mesh,
    points: tuple[Vec3, ...],
    color: int,
    reverse: bool,
    two_sided: bool,
) -> None:
    """Emit a triangle or quad as triangles, in the requested winding."""
    pts = tuple(reversed(points)) if reverse else points

    if len(pts) == 3:
        tri = Triangle(pts[0], pts[1], pts[2], color, two_sided)
        if tri.area() > 1e-9:
            mesh.triangles.append(tri)
        return

    # A quad.  LDraw quads are meant to be planar and convex but a few in
    # the library are neither, so split along the shorter diagonal: for a
    # bowed quad that is the fold that deviates least from the true surface.
    d02 = (pts[2] - pts[0]).length()
    d13 = (pts[3] - pts[1]).length()
    if d02 <= d13:
        parts = ((pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3]))
    else:
        parts = ((pts[1], pts[2], pts[3]), (pts[1], pts[3], pts[0]))

    for a, b, c in parts:
        tri = Triangle(a, b, c, color, two_sided)
        if tri.area() > 1e-9:
            mesh.triangles.append(tri)


def flatten(
    library: Library,
    name: str,
    *,
    detail: Detail = Detail.STANDARD,
    color: int = COLOR_INHERIT,
    max_depth: int = 64,
) -> Mesh:
    """Flatten a part into a single mesh in LDraw coordinates.

    ``color`` is the surface colour the part is being drawn in; leave it as
    16 to keep inherited colours symbolic so the mesh can be recoloured at
    runtime, which is what the catalogue build wants.
    """
    mesh = Mesh()
    _walk(
        library,
        name,
        Matrix.identity(),
        color,
        COLOR_EDGE_INHERIT,
        invert=False,
        culling=True,
        detail=detail,
        mesh=mesh,
        depth=0,
        max_depth=max_depth,
        stack=set(),
    )
    return mesh


def _walk(
    library: Library,
    name: str,
    transform: Matrix,
    color: int,
    edge_color: int,
    *,
    invert: bool,
    culling: bool,
    detail: Detail,
    mesh: Mesh,
    depth: int,
    max_depth: int,
    stack: set[str],
) -> None:
    if depth > max_depth or name in stack:
        # A cycle, or a pathologically deep tree.  The official library has
        # neither, but unofficial parts under review occasionally do.
        return

    ldfile = library.get(name, detail)
    if ldfile is None:
        mesh.missing.add(name)
        return

    # Culling stops at the first uncertified file and stays off below it.
    local_culling = culling and ldfile.bfc_certified
    winding_ccw = ldfile.bfc_ccw
    invert_next = False

    stack = stack | {name}

    for command in ldfile.commands:
        if isinstance(command, MetaLine):
            if command.keyword != "BFC":
                continue
            tokens = command.text.upper().split()
            if "INVERTNEXT" in tokens:
                invert_next = True
            if "CW" in tokens:
                winding_ccw = False
            elif "CCW" in tokens:
                winding_ccw = True
            if "NOCLIP" in tokens:
                local_culling = False
            elif "CLIP" in tokens:
                local_culling = culling and ldfile.bfc_certified
            continue

        if isinstance(command, SubfileRef):
            child_matrix = transform @ command.matrix
            # The three sources of winding reversal compose by XOR.
            child_invert = (
                invert
                ^ invert_next
                ^ (command.matrix.determinant() < 0.0)
            )
            _walk(
                library,
                command.filename,
                child_matrix,
                _resolve_color(command.color, color, edge_color),
                edge_color,
                invert=child_invert,
                culling=local_culling,
                detail=detail,
                mesh=mesh,
                depth=depth + 1,
                max_depth=max_depth,
                stack=stack,
            )
            invert_next = False
            continue

        if isinstance(command, Polygon):
            points = tuple(transform.transform_point(p) for p in command.points)
            _add_polygon(
                mesh,
                points,
                _resolve_color(command.color, color, edge_color),
                reverse=(not winding_ccw) ^ invert,
                two_sided=not local_culling,
            )
            continue

        if isinstance(command, EdgeLine):
            a = transform.transform_point(command.points[0])
            b = transform.transform_point(command.points[1])
            ka, kb = _key(a), _key(b)
            if ka != kb:
                mesh.edges.add((ka, kb) if ka < kb else (kb, ka))
            continue

        if isinstance(command, OptionalLine):
            mesh.optional_edges.append(
                (
                    transform.transform_point(command.points[0]),
                    transform.transform_point(command.points[1]),
                    transform.transform_point(command.controls[0]),
                    transform.transform_point(command.controls[1]),
                )
            )
            continue


# -- shading -------------------------------------------------------------


def compute_normals(mesh: Mesh, *, crease_degrees: float = 45.0) -> list[Vec3]:
    """Per-corner normals: smoothed across shared vertices, hard at creases.

    Returns one normal per triangle corner, in triangle order, so the
    caller can write a non-indexed vertex buffer directly.

    The algorithm is the standard smoothing-group partition.  Around each
    welded vertex position, the faces touching it are split into groups
    that are connected through *uncreased* shared edges; each group gets
    its own averaged normal.  A face on one side of a brick's corner
    therefore never blends into the face on the other side, while every
    facet around a cylinder blends into its neighbours all the way round.

    An edge counts as a crease when the part author drew a type-2 line
    along it, or when the two faces meet at more than ``crease_degrees``.
    The angle test is a backstop for the handful of parts that omit an
    edge line where one belongs.
    """
    cos_crease = math.cos(math.radians(crease_degrees))

    face_normals = [t.normal() for t in mesh.triangles]
    # Weight by area so a sliver triangle cannot drag a normal around.
    face_areas = [t.area() for t in mesh.triangles]

    # Corner keys once, not per comparison.
    corner_keys: list[tuple[tuple[int, int, int], ...]] = [
        (_key(t.a), _key(t.b), _key(t.c)) for t in mesh.triangles
    ]

    # Which triangles touch each undirected welded edge.  Two faces can
    # only smooth together across an edge they both own.
    by_edge: dict[tuple[tuple[int, int, int], tuple[int, int, int]], list[int]] = {}
    for ti, keys in enumerate(corner_keys):
        for n in range(3):
            ka, kb = keys[n], keys[(n + 1) % 3]
            if ka == kb:
                continue
            by_edge.setdefault((ka, kb) if ka < kb else (kb, ka), []).append(ti)

    # Which triangle corners sit at each welded position.
    at_position: dict[tuple[int, int, int], list[tuple[int, int]]] = {}
    for ti, keys in enumerate(corner_keys):
        for ci, key in enumerate(keys):
            at_position.setdefault(key, []).append((ti, ci))

    normals: list[Vec3] = [Vec3(0.0, 0.0, 0.0)] * (len(mesh.triangles) * 3)

    for position, corners in at_position.items():
        members = [ti for ti, _ in corners]
        index_of = {ti: n for n, ti in enumerate(members)}

        # Union-find over the faces meeting at this position.
        parent = list(range(len(members)))

        def find(n: int) -> int:
            while parent[n] != n:
                parent[n] = parent[parent[n]]
                n = parent[n]
            return n

        def union(a: int, b: int) -> None:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[rb] = ra

        # Join faces that share an uncreased edge running through here.
        for ti, ci in corners:
            keys = corner_keys[ti]
            for other in (keys[(ci + 1) % 3], keys[(ci + 2) % 3]):
                if other == position:
                    continue
                pair = (position, other) if position < other else (other, position)
                if pair in mesh.edges:
                    continue  # the author drew a crease here
                for tj in by_edge.get(pair, ()):
                    if tj == ti or tj not in index_of:
                        continue
                    if face_normals[ti].dot(face_normals[tj]) < cos_crease:
                        continue  # too sharp to be a smooth surface
                    union(index_of[ti], index_of[tj])

        # One averaged normal per connected group.
        group_sum: dict[int, Vec3] = {}
        for n, ti in enumerate(members):
            root = find(n)
            group_sum[root] = group_sum.get(root, Vec3(0.0, 0.0, 0.0)) + (
                face_normals[ti] * face_areas[ti]
            )

        for (ti, ci), n in zip(corners, range(len(members))):
            acc = group_sum[find(n)]
            length = acc.length()
            normals[ti * 3 + ci] = (
                acc * (1.0 / length) if length > 1e-12 else face_normals[ti]
            )

    return normals
