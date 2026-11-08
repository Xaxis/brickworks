"""A strict reader of a 3MF, as print3mf_probe reads the app's (APP_UX6 #18).

    uvx --with lib3mf==2.5.0 --with xmlschema==4.3.2 --with numpy==2.5.4 \\
        python3 -I tools/print3mf/check_3mf.py FILE.3mf [--json=OUT.json]

Four readers, each strict in its own way, and every error any of them has:

- the package, as the core spec's chapter 2 and its Open Packaging rules
  have it: a zip whose members are stored or deflated, a content type for
  the model, one StartPart relationship to a model part that is there, and
  XML in UTF-8 with no DTD;
- the model part against the core's own XSD (3mf_core.xsd here, the spec's
  Appendix B.1.1), by xmlschema;
- the rules the spec states that no schema can: every id defined before it
  is named, a triangle's corners distinct and in range, a property in its
  group's range and the same at all three corners, an object with triangle
  properties naming its own, a build item naming an object that may be
  built, metadata names the core defines and each once, a model object of
  four triangles at least;
- lib3mf, the 3MF Consortium's own library, reading in strict mode, where
  a warning is an error.

Then what lib3mf read, each object at its build item's place: its name, its
colour (its base material's displaycolor), its triangles, its edges by
vertex index (how many are not shared by exactly two triangles, and how
many are shared by two going the same way round: the core's manifold rules,
4.1, beside lib3mf's own IsManifoldAndOriented), which way each triangle
faces, and the build's box. Three rays from a point just in front
of a triangle, each tilted from its normal a different way, count its
shell's crossings by the core's positive fill rule (4.1.1: one out for a
crossing from inside to out, one in for the other way); three more do the
same from just behind it. Two of three rays decide each side. A triangle
faces inward when it is empty behind and, in front, filled or below nought
(as in a shell turned inside out); it is internal when it is filled both
sides, as where LDraw's shapes overlap (a stud's foot in a brick's top),
which the positive fill rule makes one solid whichever way it faces. On
150 BFC-certified library parts, 258 of their 170,671 triangles (0.15%)
read as facing in, where a part is open or its shapes overlap so that
rays cannot tell; turned inside out, 92.5% of them do. A shell is the
triangles that share corners; each part is written as its own, so a
part's neighbours, touching it face to face, do not count.

Prints a JSON report (to OUT.json too when named) and exits 1 when any
reader found an error. The winding and the box are for the caller to judge.
"""

from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree

CORE = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
START_PART = "http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"
MODEL_TYPE = "application/vnd.ms-package.3dmanufacturing-3dmodel+xml"
RELS_TYPE = "application/vnd.openxmlformats-package.relationships+xml"
TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
# The metadata names the core defines (3.4.1, table 3-1).
WELL_KNOWN = {"Title", "Designer", "Description", "Copyright", "LicenseTerms", "Rating",
              "CreationDate", "ModificationDate", "Application"}
XSD = Path(__file__).with_name("3mf_core.xsd")


def package(path: Path, errors: list[str]) -> tuple[str, bytes]:
    """The package's rules; the model part's name and bytes."""
    try:
        archive = zipfile.ZipFile(path)
    except zipfile.BadZipFile as error:
        errors.append(f"package: not a zip ({error})")
        return "", b""
    names = {info.filename: info for info in archive.infolist()}
    for info in names.values():
        if info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
            errors.append(f"package: {info.filename} is compressed by method {info.compress_type}, "
                          "not stored or deflated")
    bad = archive.testzip()
    if bad is not None:
        errors.append(f"package: {bad} does not unpack to its CRC")
    if "[Content_Types].xml" not in names:
        errors.append("package: no [Content_Types].xml")
        return "", b""
    types = ElementTree.fromstring(archive.read("[Content_Types].xml"))
    defaults = {d.get("Extension", "").lower(): d.get("ContentType")
                for d in types.findall(f"{{{TYPES_NS}}}Default")}
    overrides = {o.get("PartName"): o.get("ContentType")
                 for o in types.findall(f"{{{TYPES_NS}}}Override")}
    if defaults.get("rels") != RELS_TYPE:
        errors.append("package: .rels parts have no relationships content type")
    if "_rels/.rels" not in names:
        errors.append("package: no _rels/.rels")
        return "", b""
    rels = ElementTree.fromstring(archive.read("_rels/.rels"))
    starts = [r for r in rels.findall(f"{{{RELS_NS}}}Relationship") if r.get("Type") == START_PART]
    if len(starts) != 1:
        errors.append(f"package: {len(starts)} StartPart relationships, not one")
        return "", b""
    target = starts[0].get("Target", "")
    if not target.startswith("/"):
        errors.append(f"package: the StartPart target {target!r} is not an absolute part name")
    part = target.lstrip("/")
    if part not in names:
        errors.append(f"package: the StartPart names {target}, which is not in it")
        return "", b""
    kind = overrides.get(target) or defaults.get(part.rsplit(".", 1)[-1].lower())
    if kind != MODEL_TYPE:
        errors.append(f"package: {target}'s content type is {kind!r}, not the 3D model's")
    data = archive.read(part)
    head = data[:200].decode("utf-8", "replace")
    if "<!DOCTYPE" in data.decode("utf-8", "replace"):
        errors.append("package: the model has a DTD")
    declared = re.search(r"encoding=[\"']([^\"']+)", head)
    if declared and declared.group(1).lower() not in ("utf-8", "utf8"):
        errors.append(f"package: the model says it is {declared.group(1)}, not UTF-8")
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        errors.append("package: the model is not UTF-8")
    return part, data


def schema(data: bytes, errors: list[str]) -> int:
    """The model against the core XSD; how many errors it has."""
    import xmlschema

    core = xmlschema.XMLSchema10(str(XSD))
    found = 0
    for error in core.iter_errors(data.decode("utf-8")):
        found += 1
        if found <= 20:
            errors.append(f"schema: {error.reason} at {error.path}")
    return found


def rules(data: bytes, errors: list[str]) -> None:
    """The core's rules a schema cannot state, read off the XML."""
    root = ElementTree.fromstring(data)
    q = lambda name: f"{{{CORE}}}{name}"
    seen: dict[int, str] = {}
    counts: dict[int, int] = {}
    types: dict[int, str] = {}
    names: list[str] = []
    for meta in root.findall(q("metadata")):
        name = meta.get("name", "")
        if ":" not in name and name not in WELL_KNOWN:
            errors.append(f"rules: metadata {name!r} has no namespace and is not a name the core defines")
        if name in names:
            errors.append(f"rules: metadata {name!r} twice")
        names.append(name)
    resources = root.find(q("resources"))
    for element in list(resources) if resources is not None else []:
        rid = int(element.get("id", "0"))
        if rid in seen:
            errors.append(f"rules: resource id {rid} twice")
        tag = element.tag.split("}")[-1]
        seen[rid] = tag
        if tag == "basematerials":
            counts[rid] = len(element.findall(q("base")))
            continue
        if tag != "object":
            continue
        types[rid] = element.get("type", "model")
        pid = element.get("pid")
        if pid is not None and (seen.get(int(pid)) != "basematerials"
                                or int(element.get("pindex", "-1")) >= counts.get(int(pid), 0)):
            errors.append(f"rules: object {rid}'s property {pid}/{element.get('pindex')} is not defined before it")
        mesh = element.find(q("mesh"))
        if mesh is None:
            for component in element.iter(q("component")):
                if seen.get(int(component.get("objectid", "0"))) != "object":
                    errors.append(f"rules: object {rid} names object {component.get('objectid')}, not before it")
            if pid is not None:
                errors.append(f"rules: object {rid} has components and a pid")
            continue
        vertices = len(mesh.find(q("vertices")).findall(q("vertex")))
        triangles = mesh.find(q("triangles")).findall(q("triangle"))
        if types[rid] == "model" and len(triangles) < 4:
            errors.append(f"rules: model object {rid} has {len(triangles)} triangles, fewer than a solid's 4")
        bad = 0
        for triangle in triangles:
            corners = [int(triangle.get(v)) for v in ("v1", "v2", "v3")]
            if len(set(corners)) < 3 or max(corners) >= vertices:
                bad += 1
            group = triangle.get("pid", pid)
            given = [triangle.get(p) for p in ("p1", "p2", "p3") if triangle.get(p) is not None]
            if given:
                if pid is None:
                    bad += 1
                elif group is None or seen.get(int(group)) != "basematerials" \
                        or any(int(p) >= counts[int(group)] for p in given) or len(set(given)) > 1:
                    bad += 1
        if bad:
            errors.append(f"rules: object {rid} has {bad} triangles with corners repeated or out of "
                          f"its {vertices} vertices, or properties out of their group")
    build = root.find(q("build"))
    for item in build.findall(q("item")) if build is not None else []:
        oid = int(item.get("objectid", "0"))
        if seen.get(oid) != "object":
            errors.append(f"rules: build item names {oid}, which is not an object")
        elif types.get(oid) == "other":
            errors.append(f"rules: build item names object {oid}, of type other")


def lib3mf_read(path: Path, errors: list[str]) -> dict:
    """lib3mf's strict reading, and what it read: objects, colours, shells."""
    import lib3mf
    import numpy as np

    wrapper = lib3mf.get_wrapper()
    model = wrapper.CreateModel()
    reader = model.QueryReader("3mf")
    reader.SetStrictModeActive(True)
    try:
        reader.ReadFromFile(str(path))
    except Exception as error:  # lib3mf raises its own ELib3MFException
        errors.append(f"lib3mf: {error}")
        return {}
    for n in range(reader.GetWarningCount()):
        code, warning = reader.GetWarning(n)
        errors.append(f"lib3mf: warning {code}: {warning}")
    version = wrapper.GetLibraryVersion()

    colours: dict[tuple[int, int], str] = {}
    groups = model.GetBaseMaterialGroups()
    while groups.MoveNext():
        group = groups.GetCurrentBaseMaterialGroup()
        for pid in group.GetAllPropertyIDs():
            c = group.GetDisplayColor(pid)
            text = f"#{c.Red:02X}{c.Green:02X}{c.Blue:02X}" + ("" if c.Alpha == 255 else f"{c.Alpha:02X}")
            colours[(group.GetUniqueResourceID(), pid)] = text

    places: dict[int, list] = {}
    items = model.GetBuildItems()
    while items.MoveNext():
        item = items.GetCurrent()
        t = item.GetObjectTransform()
        matrix = np.array([[t.Fields[r][c] for c in range(3)] for r in range(4)], dtype=float)
        places.setdefault(item.GetObjectResource().GetUniqueResourceID(), []).append(matrix)

    objects = []
    low = np.full(3, np.inf)
    high = np.full(3, -np.inf)
    meshes = model.GetMeshObjects()
    while meshes.MoveNext():
        mesh = meshes.GetCurrentMeshObject()
        uid = mesh.GetUniqueResourceID()
        points = np.array([[v.Coordinates[0], v.Coordinates[1], v.Coordinates[2]]
                           for v in mesh.GetVertices()], dtype=float)
        corners = np.array([list(t.Indices) for t in mesh.GetTriangleIndices()], dtype=np.int64)
        group, pid, has = mesh.GetObjectLevelProperty()
        painted: dict[str, int] = {}
        for props in mesh.GetAllTriangleProperties():
            if props.ResourceID and (props.ResourceID, props.PropertyIDs[0]) != (group, pid):
                key = colours.get((props.ResourceID, props.PropertyIDs[0]), "?")
                painted[key] = painted.get(key, 0) + 1
        for matrix in places.get(uid, []):
            placed = points @ matrix[:3] + matrix[3]
            if np.linalg.det(matrix[:3]) < 0:
                corners = corners[:, [0, 2, 1]]
            low = np.minimum(low, placed.min(axis=0))
            high = np.maximum(high, placed.max(axis=0))
            winding = facing(placed, corners)
            objects.append({
                "id": mesh.GetModelResourceID(), "name": mesh.GetName(), "type": str(mesh.GetType()),
                "colour": colours.get((group, pid), "") if has else "",
                "vertices": len(points), "triangles": len(corners), "painted": painted,
                "manifold_and_oriented": bool(mesh.IsManifoldAndOriented()), **winding,
                **edges(corners),
            })
    return {"version": ".".join(str(v) for v in version), "objects": objects,
            "unit": str(model.GetUnit()),
            "low": low.round(4).tolist(), "high": high.round(4).tolist(),
            "size": (high - low).round(4).tolist()}


def edges(corners) -> dict:
    """The core's manifold rules (4.1), counted by vertex index: edges not
    shared by exactly two triangles, and edges whose two triangles go the
    same way round along it."""
    import numpy as np

    if len(corners) == 0:
        return {"edges": 0, "edges_not_two": 0, "edges_one_way": 0}
    start = corners.reshape(-1)
    end = corners[:, [1, 2, 0]].reshape(-1)
    low = np.minimum(start, end)
    high = np.maximum(start, end)
    key = low.astype(np.int64) * (int(corners.max()) + 1) + high
    way = np.where(start < end, 1, -1)
    keys, inverse, uses = np.unique(key, return_inverse=True, return_counts=True)
    net = np.zeros(len(keys), dtype=np.int64)
    np.add.at(net, inverse, way)
    return {"edges": int(len(keys)), "edges_not_two": int((uses != 2).sum()),
            "edges_one_way": int(((uses == 2) & (net != 0)).sum())}


def facing(points, corners) -> dict:
    """How many triangles face outward, inward, inside the solid, or have no
    area to face with."""
    import numpy as np

    shell = shells(len(points), corners)
    a, b, c = points[corners[:, 0]], points[corners[:, 1]], points[corners[:, 2]]
    normal = np.cross(b - a, c - a)
    length = np.linalg.norm(normal, axis=1)
    flat = length < 1e-9
    unit = np.where(flat[:, None], 0.0, normal / np.where(flat, 1.0, length)[:, None])
    filled_front, below_front = fill(a, b, c, unit, shell)
    filled_back, _ = fill(a, b, c, -unit, shell)
    inward = (~flat) & (filled_front | below_front) & ~filled_back
    internal = (~flat) & filled_front & filled_back
    return {"outward": int(((~flat) & ~inward & ~internal).sum()), "inward": int(inward.sum()),
            "internal": int(internal.sum()), "flat": int(flat.sum()),
            "shells": int(len(set(shell.tolist())))}


def fill(a, b, c, unit, shell) -> tuple:
    """Whether the positive fill rule fills the point just off each triangle
    on UNIT's side, and whether its count there is below nought: two of
    three rays, each turned from UNIT near a fifth of a right angle a
    different way, none along an edge a box's faces share."""
    import numpy as np

    side = np.where(np.abs(unit[:, :1]) < 0.9, [[1.0, 0.0, 0.0]], [[0.0, 1.0, 0.0]])
    across = np.cross(unit, side)
    across /= np.maximum(np.linalg.norm(across, axis=1), 1e-12)[:, None]
    other = np.cross(unit, across)
    start = (a + b + c) / 3.0 + unit * 1e-3
    filled = np.zeros(len(a), dtype=int)
    below = np.zeros(len(a), dtype=int)
    for angle in (0.7, 2.8, 4.9):
        way = unit + 0.32 * (np.cos(angle) * across + np.sin(angle) * other)
        way /= np.maximum(np.linalg.norm(way, axis=1), 1e-12)[:, None]
        count = inside(start, way, a, b, c, shell)
        filled += count >= 1
        below += count <= -1
    return filled >= 2, below >= 2


def shells(vertices: int, corners) -> "np.ndarray":
    """Each triangle's shell: the triangles that share corners with it."""
    import numpy as np

    parent = list(range(vertices))

    def root(v: int) -> int:
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for x, y, z in corners.tolist():
        rx, ry, rz = root(x), root(y), root(z)
        parent[ry] = rx
        parent[root(rz)] = rx
    return np.array([root(x) for x in corners[:, 0].tolist()])


def inside(start, way, a, b, c, shell) -> "np.ndarray":
    """The positive fill rule's count at each start, along its ray, against
    its own shell's triangles (Möller and Trumbore's test)."""
    import numpy as np

    result = np.zeros(len(start), dtype=int)
    e1, e2 = b - a, c - a
    for label in np.unique(shell):
        mine = np.nonzero(shell == label)[0]
        # Rays a batch, each against every triangle of the shell, in some
        # tens of megabytes at a time.
        batch = max(1, 400_000 // len(mine))
        for at in range(0, len(mine), batch):
            rays = mine[at:at + batch]
            o, d = start[rays][:, None, :], way[rays][:, None, :]
            p = np.cross(d, e2[mine][None])
            det = np.einsum("rmk,mk->rm", p, e1[mine])
            usable = np.abs(det) > 1e-12
            inv = np.where(usable, 1.0 / np.where(usable, det, 1.0), 0.0)
            t_vec = o - a[mine][None]
            u = np.einsum("rmk,rmk->rm", t_vec, p) * inv
            q = np.cross(t_vec, e1[mine][None])
            v = np.einsum("rmk,rmk->rm", np.broadcast_to(d, q.shape), q) * inv
            t = np.einsum("mk,rmk->rm", e2[mine], q) * inv
            hit = usable & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-9)
            # det = -way . normal: below 0 the ray leaves through the
            # triangle's front, from inside to out.
            result[rays] = np.where(hit, np.where(det < 0, 1, -1), 0).sum(axis=1)
    return result


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--json")]
    out = next((a.split("=", 1)[1] for a in argv if a.startswith("--json=")), "")
    if len(args) != 1:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    path = Path(args[0])
    errors: list[str] = []
    part, data = package(path, errors)
    report: dict = {"file": str(path), "part": part, "errors": errors}
    if data:
        report["schema_errors"] = schema(data, errors)
        try:
            rules(data, errors)
        except (ElementTree.ParseError, ValueError, AttributeError) as error:
            errors.append(f"rules: {error}")
        report.update(lib3mf_read(path, errors))
    text = json.dumps(report, indent=1)
    if out:
        Path(out).write_text(text)
    print(text)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
