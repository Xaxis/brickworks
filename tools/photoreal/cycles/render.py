"""One photoreal shot drawn by Cycles, through Blender run headless (photoreal6).

The scene is the one our path tracer drew, read back from it by
src/dev/photoreal_probe.gd --cycles: <name>.cycles.ldr (the parts where they
stood, seated, in LDraw's space) and <name>.cycles.json (the camera, its lens,
the tent or the photographed place, the tent's key, the sweep and the exposure
the white card metered). Parts come in through ldr_tools_blender (MIT) with its
own LEGO materials (Cycles' subsurface, smudged gloss, a bevel, logo studs,
48-sided round parts, a hair of gap between parts). The tent is drawn as an
environment from the tracer's own formula, a place from its own HDRI turned as
the tracer turns it, the key as a sun of the same size and strength, and the
sweep as a shadow catcher, so only the renderer differs.

Blender and the add-on are tools on this box, never part of the app or its
build: docs/RENDERING.md 5j says where they are. Run:

    blender -b --factory-startup -t 8 --python tools/photoreal/cycles/render.py -- \
        SCENE.cycles.json OUT_DIR [--samples 1024] [--draw 1] [--size 1.0]
        [--sss 0] [--studs Logo4|Normal] [--resolution High|Normal] [--gap 1|0]
        [--colours tracer|ldr_tools] [--denoise 1|0] [--adaptive 0.005] [--check]

It writes OUT_DIR/<name>.exr: the picture's light before any exposure
(Combined, its alpha, the shadow catcher's pass and the paper's own pattern),
for finish.py to give it our camera's finish, and OUT_DIR/<name>.render.json
(what it was drawn with, how long it took).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time

import bpy
import mathutils
import numpy as np

ADDON = os.path.expanduser("~/.local/opt/ldr_tools_blender-0.5.3")
LDRAW = "/mnt/Projects/brickworks/vendor/ldraw"
# Blender's units per LDU (ldr_tools_blender's own scale: a 2x4 brick is 0.8 across).
K = 0.01
ENV_SIZE = (2048, 1024)


def args() -> argparse.Namespace:
    given = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("scene")
    p.add_argument("out")
    p.add_argument("--samples", type=int, default=1024)
    p.add_argument("--draw", type=int, default=1)
    p.add_argument("--size", type=float, default=1.0, help="picture size against the shot's")
    p.add_argument("--sss", type=float, default=1.0, help="subsurface weight, ldr_tools' 1")
    p.add_argument("--studs", default="Logo4")
    p.add_argument("--resolution", default="High")
    p.add_argument("--gap", type=int, default=1)
    p.add_argument("--colours", default="tracer", choices=["tracer", "ldr_tools"],
                   help="each colour's albedo: our tracer's (the same plastic, so only the renderer "
                   "differs) or ldr_tools' own table")
    p.add_argument("--denoise", type=int, default=1)
    p.add_argument("--adaptive", type=float, default=0.005, help="adaptive threshold, 0 off")
    p.add_argument("--name", default="", help="the picture's name, default the scene's")
    p.add_argument("--check", action="store_true", help="build the scene and draw nothing")
    return p.parse_args(given)


# -- the app's space to Blender's ------------------------------------------------------------
# The app: LDU, +y up (LDraw with y and z turned over). ldr_tools_blender: LDraw turned -90
# degrees about x and scaled by K, so Blender (x, y, z) = (X, -Z, Y) * K of the app's (X, Y, Z).

def way(v) -> mathutils.Vector:
    return mathutils.Vector((v[0], -v[2], v[1]))


def at(v) -> mathutils.Vector:
    return way(v) * K


def smoothstep(a: float, b: float, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def env_directions() -> np.ndarray:
    """Each pixel of an ENV_SIZE environment, as the app's directions (rows from the bottom,
    as Blender stores them), for the world's own mapping (_world_nodes): across is
    atan2(y, x) from -pi to pi, up is 1 - acos(z) / pi, in Blender's axes."""
    w, h = ENV_SIZE
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    phi = 2.0 * math.pi * (u - 0.5)
    theta = math.pi * (1.0 - v)
    st, ct = np.sin(theta)[:, None], np.cos(theta)[:, None]
    bx = st * np.cos(phi)[None, :]
    by = st * np.sin(phi)[None, :]
    bz = np.broadcast_to(ct, (h, w))
    return np.stack([bx, bz, -by], axis=-1)  # the app's (X, Y, Z)


def tent_env(scene: dict) -> np.ndarray:
    """The tracer's light tent (path_tracer.glsl tent_light), radiance per direction."""
    d = env_directions()
    x, y, z = d[..., 0], d[..., 1], d[..., 2]
    sky = np.array(scene["tint"], dtype=np.float64)
    cam = scene["camera"]
    back = np.array(cam["z"])
    up = np.array(cam["y"])
    ahead = np.array([-back[0], 0.0, -back[2]]) + np.array([up[0], 0.0, up[2]])
    into = ahead / np.linalg.norm(ahead) if ahead @ ahead > 1e-8 else np.array([0.0, 0.0, -1.0])
    right = np.array([-into[2], 0.0, into[0]])
    to_eye = np.array(cam["origin"]) - np.array(scene["sweep"]["origin"])
    to_eye = to_eye / np.linalg.norm(to_eye)
    port = smoothstep(0.978, 0.988, x * to_eye[0] + y * to_eye[1] + z * to_eye[2])
    off = np.abs(np.abs(np.arctan2(x * right[0] + z * right[2], x * into[0] + z * into[2])) - 0.85)
    box = np.where((y >= 0.03) & (y <= 0.62) & (off < 0.6),
                   (1.0 - smoothstep(0.3, 0.6, off)) * smoothstep(0.03, 0.13, y)
                   * (1.0 - smoothstep(0.47, 0.62, y)), 0.0) * float(scene["tent_box"])
    level = (0.4 + box + float(scene["tent_top"]) * smoothstep(0.866, 0.94, y)) * (1.0 - 0.97 * port)
    level = np.where(y < 0.0, 0.6 * 0.4, level)
    return level[..., None] * sky[None, None, :]


def read_hdr(path: str) -> np.ndarray:
    import OpenImageIO as oiio
    image = oiio.ImageInput.open(path)
    if image is None:
        raise RuntimeError(f"cannot read {path}: {oiio.geterror()}")
    pixels = image.read_image(format="float")
    image.close()
    return np.asarray(pixels, dtype=np.float32)[..., :3]  # rows from the top


def place_env(scene: dict) -> np.ndarray:
    """A photographed place as the tracer reads it (path_tracer.glsl place_uv), turned by its
    turn and scaled by its energy, bilinear."""
    place = scene["place"]
    hdr = read_hdr(place["path"])
    hh, ww = hdr.shape[:2]
    d = env_directions()
    turn = float(place["turn"])
    c, s = math.cos(-turn), math.sin(-turn)
    ox = c * d[..., 0] + s * d[..., 2]
    oy = d[..., 1]
    oz = -s * d[..., 0] + c * d[..., 2]
    around = np.arctan2(ox, -oz)
    around = np.where(around < 0.0, around + 2.0 * math.pi, around)
    u = around / (2.0 * math.pi) * ww - 0.5
    v = np.arccos(np.clip(oy, -1.0, 1.0)) / math.pi * hh - 0.5
    x0 = np.floor(u).astype(int)
    y0 = np.clip(np.floor(v).astype(int), 0, hh - 1)
    y1 = np.clip(y0 + 1, 0, hh - 1)
    fx = (u - np.floor(u))[..., None]
    fy = np.clip(v - np.floor(v), 0.0, 1.0)[..., None]
    x0w, x1w = x0 % ww, (x0 + 1) % ww
    top = hdr[y0, x0w] * (1 - fx) + hdr[y0, x1w] * fx
    bottom = hdr[y1, x0w] * (1 - fx) + hdr[y1, x1w] * fx
    return (top * (1 - fy) + bottom * fy) * float(place["energy"])


def write_exr(path: str, pixels: np.ndarray) -> None:
    import OpenImageIO as oiio
    h, w, c = pixels.shape
    spec = oiio.ImageSpec(w, h, c, "float")
    out = oiio.ImageOutput.create(path)
    out.open(path, spec)
    out.write_image(np.ascontiguousarray(pixels, dtype=np.float32))
    out.close()


def world(scene: dict, out: str) -> None:
    """The environment as an image in our own mapping, read through math nodes, so no
    convention of Blender's own mapping is assumed."""
    env = tent_env(scene) if scene["tent"] or not scene.get("place") else place_env(scene)
    # Rows from the bottom in Blender; written top row first to an EXR.
    path = os.path.join(out, f"{scene['name']}.env.exr")
    write_exr(path, env[::-1].astype(np.float32))
    image = bpy.data.images.load(path)
    image.colorspace_settings.name = "Non-Color"
    w = bpy.data.worlds.new("photoreal")
    bpy.context.scene.world = w
    w.use_nodes = True
    nodes, links = w.node_tree.nodes, w.node_tree.links
    nodes.clear()
    coord = nodes.new("ShaderNodeTexCoord")
    norm = nodes.new("ShaderNodeVectorMath")
    norm.operation = "NORMALIZE"
    links.new(coord.outputs["Generated"], norm.inputs[0])
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(norm.outputs["Vector"], xyz.inputs[0])
    atan = nodes.new("ShaderNodeMath")
    atan.operation = "ARCTAN2"
    links.new(xyz.outputs["Y"], atan.inputs[0])
    links.new(xyz.outputs["X"], atan.inputs[1])
    u = nodes.new("ShaderNodeMath")
    u.operation = "MULTIPLY_ADD"
    links.new(atan.outputs[0], u.inputs[0])
    u.inputs[1].default_value = 1.0 / (2.0 * math.pi)
    u.inputs[2].default_value = 0.5
    acos = nodes.new("ShaderNodeMath")
    acos.operation = "ARCCOSINE"
    links.new(xyz.outputs["Z"], acos.inputs[0])
    v = nodes.new("ShaderNodeMath")
    v.operation = "MULTIPLY_ADD"
    links.new(acos.outputs[0], v.inputs[0])
    v.inputs[1].default_value = -1.0 / math.pi
    v.inputs[2].default_value = 1.0
    uv = nodes.new("ShaderNodeCombineXYZ")
    links.new(u.outputs[0], uv.inputs["X"])
    links.new(v.outputs[0], uv.inputs["Y"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    links.new(uv.outputs["Vector"], tex.inputs["Vector"])
    bg = nodes.new("ShaderNodeBackground")
    links.new(tex.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    output = nodes.new("ShaderNodeOutputWorld")
    links.new(bg.outputs["Background"], output.inputs["Surface"])


def key_light(scene: dict) -> None:
    """The tent's key: a big soft light where the rig's key stands. The tracer's light of
    energy e lights a white diffuse face to radiance e; a Cycles sun of strength S to S/pi."""
    key = scene.get("key")
    if not key:
        return
    sun = bpy.data.lights.new("key", "SUN")
    sun.angle = 2.0 * float(key["spread"])
    sun.energy = float(key["energy"]) * math.pi
    sun.color = scene["tint"]
    obj = bpy.data.objects.new("key", sun)
    bpy.context.scene.collection.objects.link(obj)
    toward = way(key["toward"]).normalized()
    obj.rotation_euler = toward.to_track_quat("Z", "Y").to_euler()


def camera(scene: dict, size: tuple[int, int], draw: int) -> None:
    cam = scene["camera"]
    data = bpy.data.cameras.new("eye")
    data.sensor_fit = "VERTICAL"
    data.sensor_height = 24.0
    fov = math.radians(float(cam["fov"]))
    data.lens = 12.0 / math.tan(fov * 0.5)
    data.clip_start = max(float(cam["near"]) * K, 1e-4)
    data.clip_end = 1e6
    aperture = float(cam["aperture"])
    if aperture > 0.0:
        data.dof.use_dof = True
        data.dof.focus_distance = float(cam["focus_distance"]) * K
        # Cycles' lens radius is lens (mm) / 1000 / (2 f-stop) in Blender's units.
        data.dof.aperture_fstop = data.lens * 1e-3 / (2.0 * aperture * K)
        data.dof.aperture_blades = 0
    obj = bpy.data.objects.new("eye", data)
    bpy.context.scene.collection.objects.link(obj)
    m = mathutils.Matrix.Identity(4)
    for column, key in enumerate(("x", "y", "z")):
        axis = way(cam[key])
        for row in range(3):
            m[row][column] = axis[row]
    origin = at(cam["origin"])
    for row in range(3):
        m[row][3] = origin[row]
    obj.matrix_world = m
    bpy.context.scene.camera = obj
    r = bpy.context.scene.render
    r.resolution_x, r.resolution_y = size
    r.resolution_percentage = 100
    r.pixel_aspect_x = r.pixel_aspect_y = 1.0


def _noise(nodes, links, vector, scale: float, detail: float = 0.0):
    n = nodes.new("ShaderNodeTexNoise")
    n.noise_dimensions = "3D"
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = 0.5
    links.new(vector, n.inputs["Vector"])
    signed = nodes.new("ShaderNodeMath")
    signed.operation = "MULTIPLY_ADD"
    links.new(n.outputs["Fac"], signed.inputs[0])
    signed.inputs[1].default_value = 2.0
    signed.inputs[2].default_value = -1.0
    return signed.outputs[0]


def _sum(nodes, links, terms: list) -> object:
    """sum of (socket, weight) and plain numbers, through MULTIPLY_ADD nodes."""
    total = None
    constant = 0.0
    for term in terms:
        if isinstance(term, (int, float)):
            constant += term
            continue
        socket, weight = term
        node = nodes.new("ShaderNodeMath")
        node.operation = "MULTIPLY_ADD"
        links.new(socket, node.inputs[0])
        node.inputs[1].default_value = weight
        if total is None:
            node.inputs[2].default_value = constant
            constant = 0.0
        else:
            links.new(total, node.inputs[2])
        total = node.outputs[0]
    if constant:
        node = nodes.new("ShaderNodeMath")
        node.operation = "ADD"
        links.new(total, node.inputs[0])
        node.inputs[1].default_value = constant
        total = node.outputs[0]
    return total


def sweep(scene: dict) -> None:
    """The sweep: a shadow catcher, so the picture shows the backdrop at exactly its colour
    where nothing shadows it (as the tracer's does), lit and seen by everything else as
    paper of the backdrop's colour. Its paper's pattern (the tracer's paper(): broad
    unevenness and fibre, or a desk's mottle, smudges and specks), the same functions
    in kind if not in hash, goes to the AOV "paper" for finish.py."""
    said = scene["sweep"]
    if not said["visible"]:
        return
    basis = mathutils.Matrix((said["x"], said["y"], said["z"])).transposed()
    origin = mathutils.Vector(said["origin"])
    corners = [at(basis @ mathutils.Vector(c) + origin) for c in said["vertices"]]
    order = said["indices"] or list(range(len(corners)))
    # Godot's front is clockwise, Blender's anticlockwise: each triangle turned over.
    faces = [(order[i], order[i + 2], order[i + 1]) for i in range(0, len(order), 3)]
    mesh = bpy.data.meshes.new("sweep")
    mesh.from_pydata([tuple(c) for c in corners], [], faces)
    mesh.update()
    mesh.shade_smooth()
    obj = bpy.data.objects.new("sweep", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.is_shadow_catcher = True
    mat = bpy.data.materials.new("paper")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    geo = nodes.new("ShaderNodeNewGeometry")
    # The app's position in LDU: (X, Y, Z) = (x, z, -y) / K.
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], xyz.inputs[0])
    app = nodes.new("ShaderNodeCombineXYZ")
    for src, dst, w in (("X", "X", 1.0 / K), ("Z", "Y", 1.0 / K), ("Y", "Z", -1.0 / K)):
        m = nodes.new("ShaderNodeMath")
        m.operation = "MULTIPLY"
        links.new(xyz.outputs[src], m.inputs[0])
        m.inputs[1].default_value = w
        links.new(m.outputs[0], app.inputs[dst])
    pos = app.outputs["Vector"]
    amount = float(scene.get("paper", 0.0))
    paper = None
    if amount > 0.0:
        broad = _sum(nodes, links, [(_noise(nodes, links, pos, 1.0 / 140.0), 0.6),
                                    (_noise(nodes, links, pos, 1.0 / 47.0), 0.4)])
        if int(scene.get("surface", 0)) == 1:
            # flat_at = (X + 0.6 Y, Z + 0.8 Y), the floor's plane with its rise folded on.
            pxyz = nodes.new("ShaderNodeSeparateXYZ")
            links.new(pos, pxyz.inputs[0])
            fx = _sum(nodes, links, [(pxyz.outputs["X"], 1.0), (pxyz.outputs["Y"], 0.6)])
            fz = _sum(nodes, links, [(pxyz.outputs["Z"], 1.0), (pxyz.outputs["Y"], 0.8)])
            flat = nodes.new("ShaderNodeCombineXYZ")
            links.new(fx, flat.inputs["X"])
            links.new(fz, flat.inputs["Y"])
            smudge = _sum(nodes, links, [(_noise(nodes, links, flat.outputs["Vector"], 1.0 / 26.0), 0.6),
                                         (_noise(nodes, links, flat.outputs["Vector"], 1.0 / 9.0), 0.4)])
            mottle = _noise(nodes, links, flat.outputs["Vector"], 0.7)
            cells = nodes.new("ShaderNodeTexVoronoi")
            cells.voronoi_dimensions = "2D"
            cells.inputs["Scale"].default_value = 1.0 / 0.9
            links.new(flat.outputs["Vector"], cells.inputs["Vector"])
            pick = nodes.new("ShaderNodeSeparateColor")
            links.new(cells.outputs["Color"], pick.inputs[0])
            dark = nodes.new("ShaderNodeMath")
            dark.operation = "LESS_THAN"
            links.new(pick.outputs[0], dark.inputs[0])
            dark.inputs[1].default_value = 0.04
            light = nodes.new("ShaderNodeMath")
            light.operation = "GREATER_THAN"
            links.new(pick.outputs[0], light.inputs[0])
            light.inputs[1].default_value = 0.975
            near = nodes.new("ShaderNodeMapRange")
            near.interpolation_type = "SMOOTHSTEP"
            links.new(cells.outputs["Distance"], near.inputs["Value"])
            near.inputs["From Min"].default_value = 0.15
            near.inputs["From Max"].default_value = 0.3
            near.inputs["To Min"].default_value = 1.0
            near.inputs["To Max"].default_value = 0.0
            speck = _sum(nodes, links, [(dark.outputs[0], -0.25), (light.outputs[0], 0.1)])
            speck_m = nodes.new("ShaderNodeMath")
            speck_m.operation = "MULTIPLY"
            links.new(speck, speck_m.inputs[0])
            links.new(near.outputs["Result"], speck_m.inputs[1])
            paper = _sum(nodes, links, [(broad, 0.06 * amount), (smudge, 0.04 * amount),
                                        (mottle, 0.015 * amount), (speck_m.outputs[0], amount), 1.0])
        else:
            pxyz = nodes.new("ShaderNodeSeparateXYZ")
            links.new(pos, pxyz.inputs[0])
            sx = nodes.new("ShaderNodeCombineXYZ")
            for axis, w in (("X", 0.9), ("Y", 0.9), ("Z", 0.25)):
                m = nodes.new("ShaderNodeMath")
                m.operation = "MULTIPLY"
                links.new(pxyz.outputs[axis], m.inputs[0])
                m.inputs[1].default_value = w
                links.new(m.outputs[0], sx.inputs[axis])
            fibre = _sum(nodes, links, [(_noise(nodes, links, sx.outputs["Vector"], 1.0), 0.5),
                                        (_noise(nodes, links, pos, 2.3), 0.5)])
            paper = _sum(nodes, links, [(broad, 0.06 * amount), (fibre, 0.025 * amount), 1.0])
    hexed = scene["backdrop"].lstrip("#")
    srgb = [int(hexed[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["IOR"].default_value = 1.17  # F0 0.0064, as the tracer's sweep
    tint = nodes.new("ShaderNodeRGB")
    tint.outputs[0].default_value = (*linear, 1.0)
    if paper is not None:
        mul = nodes.new("ShaderNodeVectorMath")
        mul.operation = "SCALE"
        links.new(tint.outputs[0], mul.inputs[0])
        links.new(paper, mul.inputs["Scale"])
        links.new(mul.outputs["Vector"], bsdf.inputs["Base Color"])
        aov = nodes.new("ShaderNodeOutputAOV")
        aov.aov_name = "paper"
        links.new(paper, aov.inputs["Value"])
    else:
        links.new(tint.outputs[0], bsdf.inputs["Base Color"])
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    obj.data.materials.append(mat)


def parts(scene_path: str, opts: argparse.Namespace) -> int:
    sys.path.insert(0, ADDON)
    import ldr_tools_blender
    from ldr_tools_blender import operator as op
    from ldr_tools_blender.importldr import import_ldraw
    ldr_tools_blender.register()

    class Reports:
        said: list = []

        def report(self, kind, words):
            print("ldr_tools:", kind, words)
            Reports.said.append(words)

    py = op.ldr_tools_py
    settings = py.GeometrySettings()
    settings.triangulate = False
    settings.add_gap_between_parts = bool(opts.gap)
    settings.stud_type = getattr(py.StudType, opts.studs)
    settings.primitive_resolution = getattr(py.PrimitiveResolution, opts.resolution)
    settings.scene_scale = K
    settings.weld_vertices = True
    ldr = scene_path.replace(".cycles.json", ".cycles.ldr")
    import_ldraw(Reports(), ldr, LDRAW, [], "LinkedDuplicates", settings)
    placed = sum(1 for o in bpy.data.objects if o.type == "MESH" and o.name != "sweep")
    table = ldconfig() if opts.colours == "tracer" else {}
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.name == "paper":
            continue
        code = mat.name.split(" ")[0]
        for node in mat.node_tree.nodes:
            if node.bl_idname != "ShaderNodeBsdfPrincipled":
                continue
            node.inputs["Subsurface Weight"].default_value *= opts.sss
            base = node.inputs["Base Color"]
            # A print or a speckle feeds the colour from a texture: left as ldr_tools draws it.
            if code.isdigit() and int(code) in table and not base.is_linked:
                lin = tracer_albedo(table[int(code)])
                base.default_value = (*lin, 1.0)
                node.inputs["Subsurface Radius"].default_value = lin
    return placed


# -- our tracer's albedo for an LDraw colour ------------------------------------------------
# path_tracer.gd: a plastic's albedo is PRODUCT_ALBEDO's fit to the photographs where it has
# one, else the colour it is drawn in (PartLibrary.shown_for of LDConfig's VALUE) made linear.

FITTED = {
    (180, 0, 0): (0.60, 0.003, 0.003),
    (0, 133, 43): (0.004, 0.235, 0.031),
    (30, 90, 168): (0.019, 0.146, 0.564),
    (27, 42, 52): (0.009, 0.010, 0.012),
}


def ldconfig() -> dict[int, tuple[int, int, int]]:
    found = {}
    for line in open(os.path.join(LDRAW, "LDConfig.ldr"), encoding="utf-8", errors="replace"):
        w = line.split()
        if len(w) > 6 and w[0] == "0" and w[1] == "!COLOUR" and "CODE" in w and "VALUE" in w:
            hexed = w[w.index("VALUE") + 1].lstrip("#")
            found[int(w[w.index("CODE") + 1])] = tuple(int(hexed[i:i + 2], 16) for i in (0, 2, 4))
    return found


def _to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _to_srgb(c: float) -> float:
    return c * 12.92 if c < 0.0031308 else 1.055 * max(c, 0.0) ** (1.0 / 2.4) - 0.055


def _cbrt(x: float) -> float:
    return math.copysign(abs(x) ** (1.0 / 3.0), x)


def shown_for(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    """PartLibrary.shown_for: a dark colour with almost no hue drawn with a quarter of it."""
    r, g, b = (_to_linear(c) for c in rgb)
    l_ = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m_ = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s_ = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    big_l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    if big_l >= 0.35 or math.hypot(a, bb) >= 0.04:
        return rgb
    a, bb = a * 0.25, bb * 0.25
    l_ = big_l + 0.3963377774 * a + 0.2158037573 * bb
    m_ = big_l - 0.1055613458 * a - 0.0638541728 * bb
    s_ = big_l - 0.0894841775 * a - 1.2914855480 * bb
    l3, m3, s3 = l_ ** 3, m_ ** 3, s_ ** 3
    lin = (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
           -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
           -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
    return tuple(min(max(_to_srgb(c), 0.0), 1.0) for c in lin)


def tracer_albedo(rgb8: tuple[int, int, int]) -> tuple[float, float, float]:
    if rgb8 in FITTED:
        return FITTED[rgb8]
    return tuple(_to_linear(c) for c in shown_for(tuple(c / 255.0 for c in rgb8)))


def main() -> int:
    opts = args()
    scene = json.load(open(opts.scene))
    name = opts.name or scene["name"]
    os.makedirs(opts.out, exist_ok=True)
    started = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lines = sum(1 for line in open(opts.scene.replace(".cycles.json", ".cycles.ldr"))
                if line.startswith("1 "))
    placed = parts(opts.scene, opts)
    print(f"parts: {placed} objects for {lines} lines")
    world(scene, opts.out)
    key_light(scene)
    sweep(scene)
    w, h = scene["size"]
    size = (round(w * opts.size), round(h * opts.size))
    camera(scene, size, opts.draw)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    c = s.cycles
    c.device = "CPU"
    c.samples = opts.samples
    c.use_adaptive_sampling = opts.adaptive > 0.0
    if opts.adaptive > 0.0:
        c.adaptive_threshold = opts.adaptive
    c.seed = opts.draw
    c.use_denoising = bool(opts.denoise)
    c.denoiser = "OPENIMAGEDENOISE"
    c.denoising_input_passes = "RGB_ALBEDO_NORMAL"
    c.denoising_prefilter = "ACCURATE"
    try:
        c.denoising_quality = "HIGH"
    except (AttributeError, TypeError):
        pass
    c.max_bounces = 16
    c.diffuse_bounces = 6
    c.glossy_bounces = 6
    c.transmission_bounces = 16
    c.transparent_max_bounces = 16
    c.sample_clamp_indirect = 10.0
    c.blur_glossy = 0.5
    s.render.film_transparent = True
    s.render.use_persistent_data = False
    layer = s.view_layers[0]
    layer.cycles.use_pass_shadow_catcher = True
    aov = layer.aovs.add()
    aov.name = "paper"
    aov.type = "VALUE"
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    settings = s.render.image_settings
    # Blender 5 makes a multilayer EXR a kind of output (media_type), then its one format.
    if hasattr(settings, "media_type"):
        settings.media_type = "MULTI_LAYER_IMAGE"
    settings.file_format = "OPEN_EXR_MULTILAYER"
    # Every pass in one part of the file: Blender 5 writes a part for each by default, and
    # a reader that takes the first part sees the Combined pass alone.
    if hasattr(settings, "use_exr_interleave"):
        settings.use_exr_interleave = True
    settings.color_depth = "32"
    settings.exr_codec = "ZIP"
    path = os.path.join(opts.out, f"{name}.exr")
    s.render.filepath = path
    built = time.time()
    if opts.check:
        print("check: built", len(bpy.data.objects), "objects,", len(bpy.data.materials), "materials,",
              "camera lens %.1f mm" % s.camera.data.lens, "format", settings.file_format)
        return 0
    bpy.ops.render.render(write_still=True)
    done = time.time()
    said = {"name": name, "scene": opts.scene, "samples": opts.samples, "draw": opts.draw,
            "size": list(size), "sss": opts.sss, "studs": opts.studs, "resolution": opts.resolution,
            "gap": opts.gap, "colours": opts.colours, "denoise": opts.denoise,
            "adaptive": opts.adaptive, "parts": placed, "lines": lines,
            "threads": s.render.threads, "build_s": round(built - started, 1),
            "render_s": round(done - built, 1), "blender": bpy.app.version_string}
    json.dump(said, open(os.path.join(opts.out, f"{name}.render.json"), "w"), indent=1)
    print("rendered", json.dumps(said))
    return 0


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
