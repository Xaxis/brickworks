"""The desktop's path tracer as WebGL2 shaders, for Best in a browser (photoreal28).

  python3 tools/web/tracer_port.py --js OUT.js     src/render/page_tracer.js with the shaders in it
  python3 tools/web/tracer_port.py --glsl DIR      each shader as its own file (the bench's GPU runner)

The desktop traces with Vulkan's ray tracing pipeline (src/render/path_tracer.glsl: a raygen,
a miss and a closest-hit shader) and resolves with a compute shader (path_tracer_resolve.glsl).
A browser has neither, so this writes the same code as two fragment shaders of GLSL ES 3.00:

- the raygen's main draws one band of the picture's pixels, reading the running sums it adds to
  from textures and writing them to two targets (accum and guide);
- its trace() walks a tree of boxes (page_tracer.js builds it: one tree for each shape, and one
  over the instances, as the card's BLAS and TLAS are), and calls the closest-hit shader's main
  as a function, given what the ray tracing pipeline gives it (the instance, the triangle, its
  barycentrics, the ray in the part's own space);
- the storage buffers are textures read a texel at a time, and the uniform buffers keep their
  layout: the Scene and the passes' numbers are vec4s, uints and floats, as std140 lays them out
  as std430 does.

Every other line is the desktop's own, so the browser's Best draws the same plastic, the same
stage and the same exposure. Each replacement is checked to have found its text: a change to the
desktop's shader that moves one fails here, at the export, rather than as a blank picture.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TRACER = ROOT / "src/render/path_tracer.glsl"
RESOLVE = ROOT / "src/render/path_tracer_resolve.glsl"
RUNTIME = ROOT / "src/render/page_tracer.js"
VERSIONS = {"plain": "", "marks": "#define MARKS\n", "photo": "#define PHOTO\n"}

# How wide every data texture is; page_tracer.js packs them so (its WIDE).
WIDE = 2048

PRELUDE = """#version 300 es
precision highp float;
precision highp int;
precision highp sampler2D;
precision highp usampler2D;
"""

# What the raygen reads where the desktop reads its storage buffers, and the closest hit's
# built-ins. Placed where the Instances buffer was, after struct Instance.
DATA = """
// -- the set, as textures (page_tracer.js packs them; photoreal28) -------------
uniform highp sampler2D u_records;
uniform highp usampler2D u_info;
uniform highp usampler2D u_meshes;
uniform highp sampler2D u_points;
uniform highp sampler2D u_normals;
uniform highp usampler2D u_indices;
uniform highp sampler2D u_nodes;
uniform highp sampler2D u_tris;
uniform highp sampler2D u_places;
uniform int u_top;

ivec2 rt_texel(int i) {
	return ivec2(i & %(mask)d, i >> %(shift)d);
}

Instance instance_at(uint i) {
	int at = int(i) * 4;
	Instance s;
	s.colour = texelFetch(u_records, rt_texel(at), 0);
	s.custom = texelFetch(u_records, rt_texel(at + 1), 0);
	s.box_min = texelFetch(u_records, rt_texel(at + 2), 0);
	s.box_max = texelFetch(u_records, rt_texel(at + 3), 0);
	s.info = texelFetch(u_info, rt_texel(int(i)), 0);
	return s;
}

uvec4 mesh_at(uint i) {
	return texelFetch(u_meshes, rt_texel(int(i)), 0);
}

uint index_at(uint i) {
	return texelFetch(u_indices, rt_texel(int(i)), 0).r;
}

vec3 ch_at(uint v) {
	return texelFetch(u_points, rt_texel(int(v)), 0).xyz;
}

vec3 ch_normal_at(uint v) {
	return texelFetch(u_normals, rt_texel(int(v)), 0).xyz;
}

// What the ray tracing pipeline gives a closest-hit shader, set by trace().
uvec2 rt_launch;
uint rt_instance;
int rt_primitive;
mat4x3 rt_w2o;
vec3 rt_obj_origin;
vec3 rt_obj_dir;
float rt_t;
vec2 weights;
const uint RT_OPAQUE = 1u;
const uint RT_FIRST = 4u;
void closest_hit();
""" % {"mask": WIDE - 1, "shift": WIDE.bit_length() - 1}

TABLE = """uniform highp sampler2D u_table;

float table_at(int i) {
	return texelFetch(u_table, rt_texel(i), 0).r;
}
"""

# trace(): the tree of instances, each instance's own tree of triangles in its own space, nearest
# child first; a ray that wants only to know whether anything is there (a shadow) stops at the first.
TRACE = """bool trace(vec3 from, vec3 way, float far, uint mask, uint flags) {
	hit.t = -1.0;
	if (u_top < 0) {
		return false;
	}
	bool first = (flags & RT_FIRST) != 0u;
	float best = far;
	int found = -1;
	int found_prim = 0;
	vec2 found_uv = vec2(0.0);
	vec3 inv = rt_inverse(way);
	int stack[32];
	int sp = 0;
	int node = u_top;
	for (int guard = 0; guard < 65536; guard++) {
		vec4 a = texelFetch(u_nodes, rt_texel(2 * node), 0);
		vec4 b = texelFetch(u_nodes, rt_texel(2 * node + 1), 0);
		vec3 t0 = (a.xyz - from) * inv;
		vec3 t1 = (b.xyz - from) * inv;
		vec3 lo = min(t0, t1);
		vec3 hi = max(t0, t1);
		bool go = max(max(lo.x, lo.y), max(lo.z, 0.0)) <= min(min(hi.x, hi.y), min(hi.z, best));
		if (go && b.w > 0.0) {
			int which = int(a.w);
			vec4 r0 = texelFetch(u_places, rt_texel(4 * which), 0);
			vec4 r1 = texelFetch(u_places, rt_texel(4 * which + 1), 0);
			vec4 r2 = texelFetch(u_places, rt_texel(4 * which + 2), 0);
			vec4 r3 = texelFetch(u_places, rt_texel(4 * which + 3), 0);
			if ((uint(r3.y) & mask) != 0u) {
				vec4 o4 = vec4(from, 1.0);
				vec3 o = vec3(dot(r0, o4), dot(r1, o4), dot(r2, o4));
				vec3 d = vec3(dot(r0.xyz, way), dot(r1.xyz, way), dot(r2.xyz, way));
				vec3 dinv = rt_inverse(d);
				int inner[32];
				int isp = 0;
				int at = int(r3.x);
				for (int steps = 0; steps < 65536; steps++) {
					vec4 c = texelFetch(u_nodes, rt_texel(2 * at), 0);
					vec4 e = texelFetch(u_nodes, rt_texel(2 * at + 1), 0);
					vec3 s0 = (c.xyz - o) * dinv;
					vec3 s1 = (e.xyz - o) * dinv;
					vec3 slo = min(s0, s1);
					vec3 shi = max(s0, s1);
					bool inside = max(max(slo.x, slo.y), max(slo.z, 0.0)) <= min(min(shi.x, shi.y), min(shi.z, best));
					if (inside && e.w > 0.0) {
						int start = int(c.w);
						int count = int(e.w);
						for (int k = 0; k < count; k++) {
							int tri = 3 * (start + k);
							vec4 v0 = texelFetch(u_tris, rt_texel(tri), 0);
							vec3 e1 = texelFetch(u_tris, rt_texel(tri + 1), 0).xyz;
							vec3 e2 = texelFetch(u_tris, rt_texel(tri + 2), 0).xyz;
							vec3 p = cross(d, e2);
							float det = dot(e1, p);
							if (det == 0.0) {
								continue;
							}
							float inv_det = 1.0 / det;
							vec3 sv = o - v0.xyz;
							float u = dot(sv, p) * inv_det;
							if (u < 0.0 || u > 1.0) {
								continue;
							}
							vec3 q = cross(sv, e1);
							float v = dot(d, q) * inv_det;
							if (v < 0.0 || u + v > 1.0) {
								continue;
							}
							float t = dot(e2, q) * inv_det;
							if (t > 0.0 && t < best) {
								best = t;
								found = which;
								found_prim = int(v0.w);
								found_uv = vec2(u, v);
							}
						}
						if (first && found >= 0) {
							break;
						}
					} else if (inside) {
						int near = int(c.w);
						int other = near + 1;
						int axis = int(-e.w) - 1;
						if (d[axis] < 0.0) {
							near = other;
							other = int(c.w);
						}
						inner[isp] = other;
						isp++;
						at = near;
						continue;
					}
					if (isp == 0) {
						break;
					}
					isp--;
					at = inner[isp];
				}
				if (first && found >= 0) {
					break;
				}
			}
		} else if (go) {
			int near = int(a.w);
			int other = near + 1;
			int axis = int(-b.w) - 1;
			if (way[axis] < 0.0) {
				near = other;
				other = int(a.w);
			}
			stack[sp] = other;
			sp++;
			node = near;
			continue;
		}
		if (sp == 0) {
			break;
		}
		sp--;
		node = stack[sp];
	}
	if (found < 0) {
		return false;
	}
	if (first) {
		hit.t = best;
		return true;
	}
	vec4 w0 = texelFetch(u_places, rt_texel(4 * found), 0);
	vec4 w1 = texelFetch(u_places, rt_texel(4 * found + 1), 0);
	vec4 w2 = texelFetch(u_places, rt_texel(4 * found + 2), 0);
	rt_w2o = mat4x3(vec3(w0.x, w1.x, w2.x), vec3(w0.y, w1.y, w2.y), vec3(w0.z, w1.z, w2.z),
		vec3(w0.w, w1.w, w2.w));
	rt_obj_origin = rt_w2o * vec4(from, 1.0);
	rt_obj_dir = mat3(rt_w2o) * way;
	rt_instance = uint(found);
	rt_primitive = found_prim;
	weights = found_uv;
	rt_t = best;
	closest_hit();
	return hit.t >= 0.0;
}"""

INVERSE = """vec3 rt_inverse(vec3 d) {
	return vec3(abs(d.x) > 1e-20 ? 1.0 / d.x : 1e20, abs(d.y) > 1e-20 ? 1.0 / d.y : 1e20,
		abs(d.z) > 1e-20 ? 1.0 / d.z : 1e20);
}

"""

OLD_TRACE = """bool trace(vec3 from, vec3 way, float far, uint mask, uint flags) {
	hit.t = -1.0;
	traceRayEXT(tlas, flags, mask, 0, 0, 0, from, 0.0, way, far, 0);
	return hit.t >= 0.0;
}"""


class PortError(Exception):
    pass


def swap(text: str, old: str, new: str, what: str, count: int = 1) -> str:
    """[old] replaced by [new], which must be there [count] times (0: at least once)."""
    found = text.count(old)
    if (count and found != count) or found == 0:
        raise PortError(f"{what}: found {found} times, wanted {count or 'some'}: {old[:80]!r}")
    return text.replace(old, new)


def swap_re(text: str, pattern: str, new: str, what: str) -> str:
    out, n = re.subn(pattern, new, text, flags=re.S)
    if n == 0:
        raise PortError(f"{what}: {pattern[:80]!r} not found")
    return out


def calls(text: str, name: str, func: str, cast: str) -> str:
    """Every name[E] as func(cast(E)), brackets inside E kept."""
    out = []
    at = 0
    pattern = re.compile(r"\b%s\[" % re.escape(name))
    while True:
        m = pattern.search(text, at)
        if not m:
            out.append(text[at:])
            return "".join(out)
        out.append(text[at:m.start()])
        depth = 1
        i = m.end()
        while depth:
            if text[i] == "[":
                depth += 1
            elif text[i] == "]":
                depth -= 1
            i += 1
        inner = text[m.end():i - 1]
        out.append(f"{func}({cast}({inner}))" if cast else f"{func}({inner})")
        at = i


def sections(text: str) -> dict[str, str]:
    parts = re.split(r"^#\[(\w+)\]\s*$", text, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def tracer_glsl(version: str) -> str:
    """The raygen and closest hit as one fragment shader of GLSL ES 3.00, for [version]."""
    parts = sections(TRACER.read_text())
    ray = parts["raygen"]
    ray = swap(ray, "#version 460\nVERSION_DEFINES\n", "", "the version line")
    ray = swap(ray, "#extension GL_EXT_ray_tracing : require\n", "", "the extension")
    ray = swap(ray, "layout(location = 0) rayPayloadEXT Hit hit;", "Hit hit;", "the payload")
    ray = swap(ray, "layout(set = 0, binding = 0) uniform accelerationStructureEXT tlas;\n", "", "the TLAS")
    ray = swap(ray, "layout(set = 0, binding = 1, rgba32f) uniform image2D accum;",
               "uniform highp sampler2D u_accum;\nlayout(location = 0) out vec4 out_accum;\n"
               "layout(location = 1) out vec4 out_guide;", "accum")
    ray = swap(ray, "layout(set = 0, binding = 2, std430) readonly buffer Scene {",
               "layout(std140) uniform Scene {", "the scene")
    ray = swap_re(ray, r"layout\(set = 0, binding = 3, std430\) readonly buffer Instances \{\s*Instance instances\[\];\s*\};",
                  DATA.replace("\\", "\\\\"), "the instances")
    ray = swap(ray, "layout(set = 0, binding = 8) uniform sampler2D place_map;",
               "uniform highp sampler2D place_map;", "the place")
    ray = swap_re(ray, r"layout\(set = 0, binding = 9, std430\) readonly buffer PlaceTable \{\s*float table\[\];\s*\};",
                  TABLE, "the place's table")
    ray = swap(ray, "layout(set = 0, binding = 10, rgba32f) uniform image2D guide;",
               "uniform highp sampler2D u_guide;", "the guide")
    ray = swap(ray, "layout(set = 0, binding = 11) uniform sampler2D surface_map;",
               "uniform highp sampler2D surface_map;", "the surface")
    ray = swap(ray, "layout(push_constant, std430) uniform Pass {", "layout(std140) uniform Pass {", "the pass")
    ray = swap(ray, OLD_TRACE, INVERSE + TRACE, "trace()")
    ray = swap(ray, "imageLoad(accum, pixel)", "texelFetch(u_accum, pixel, 0)", "the sum read")
    ray = swap(ray, "imageLoad(guide, pixel)", "texelFetch(u_guide, pixel, 0)", "the guide read")
    ray = swap(ray, "imageStore(accum, pixel, total);", "out_accum = total;", "the sum written")
    ray = swap(ray, "imageStore(guide, pixel, guided);", "out_guide = guided;", "the guide written")
    ray = swap(ray, "gl_LaunchIDEXT", "rt_launch", "the launch", 0)
    ray = swap(ray, "void main() {\n", "void main() {\n\trt_launch = uvec2(gl_FragCoord.xy);\n", "main")
    ray = swap(ray, "gl_RayFlagsOpaqueEXT", "RT_OPAQUE", "the flags", 0)
    ray = swap(ray, "gl_RayFlagsTerminateOnFirstHitEXT", "RT_FIRST", "the flags", 0)
    ray = calls(ray, "table", "table_at", "int")
    ray = calls(ray, "instances", "instance_at", "uint")

    hit = parts["closest_hit"]
    start = hit.find("// -- the product look's moulding")
    if start < 0:
        raise PortError("the closest hit's moulding not found")
    hit = hit[start:]
    hit = swap(hit, "void main() {", "void closest_hit() {", "the closest hit's main")
    for old, new in [("gl_InstanceCustomIndexEXT", "rt_instance"), ("gl_PrimitiveID", "rt_primitive"),
                     ("gl_WorldToObjectEXT", "rt_w2o"), ("gl_ObjectRayOriginEXT", "rt_obj_origin"),
                     ("gl_ObjectRayDirectionEXT", "rt_obj_dir"), ("gl_HitTEXT", "rt_t")]:
        hit = swap(hit, old, new, old, 0)
    hit = re.sub(r"\bat\((a|b|c)\)", r"ch_at(\1)", hit)
    hit = swap(hit, "normal_at(", "ch_normal_at(", "the normals", 0)
    hit = calls(hit, "instances", "instance_at", "uint")
    hit = calls(hit, "meshes", "mesh_at", "uint")
    hit = calls(hit, "indices", "index_at", "uint")
    left_over = re.search(r"\bgl_(?!FragCoord)\w+", ray + hit)
    if left_over:
        raise PortError("a built-in left: " + left_over.group(0))
    for left in ["traceRayEXT", "imageLoad", "imageStore", "std430", "buffer "]:
        if left in ray + hit:
            raise PortError(f"{left} left in the port")
    return PRELUDE + VERSIONS[version] + ray + "\n" + hit


def resolve_glsl() -> str:
    """The resolve as a fragment shader of GLSL ES 3.00."""
    text = sections(RESOLVE.read_text())["compute"]
    text = swap(text, "#version 460\n", "", "the version line")
    text = swap(text, "layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;\n", "", "the group size")
    text = swap(text, "layout(set = 0, binding = 0, rgba32f) uniform readonly image2D accum;",
                "uniform highp sampler2D u_accum;", "accum")
    text = swap(text, "layout(set = 0, binding = 1, rgba8) uniform writeonly image2D picture;",
                "uniform ivec2 u_size;\nlayout(location = 0) out vec4 out_picture;", "the picture")
    text = swap(text, "layout(set = 0, binding = 2, rgba32f) uniform readonly image2D guide;",
                "uniform highp sampler2D u_guide;", "the guide")
    text = swap(text, "layout(push_constant, std430) uniform Resolve {", "layout(std140) uniform Resolve {",
                "the numbers")
    text = re.sub(r"imageLoad\(accum, ", "texelFetch(u_accum, ", text)
    text = re.sub(r"imageLoad\(guide, ", "texelFetch(u_guide, ", text)
    # texelFetch takes a level after the place: each read's closing bracket gets ", 0".
    text = re.sub(r"texelFetch\((u_accum|u_guide), (clamp\([^;]*?size - ivec2\(1\)\))\)",
                  r"texelFetch(\1, \2, 0)", text)
    text = swap(text, "ivec2(gl_GlobalInvocationID.xy)", "ivec2(gl_FragCoord.xy)", "the pixel")
    text = swap(text, "imageSize(picture)", "u_size", "the size")
    text = swap_re(text, r"imageStore\(picture, pixel, (.*?)\);\n}\s*$", r"out_picture = \1;\n}\n", "the store")
    for left in ["imageLoad", "imageStore", "gl_GlobalInvocationID", "std430"]:
        if left in text:
            raise PortError(f"{left} left in the resolve")
    return PRELUDE + text


VERTEX = PRELUDE + """
// One triangle over the whole target; the fragment shaders work from gl_FragCoord.
void main() {
	vec2 at = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
	gl_Position = vec4(at * 2.0 - 1.0, 0.0, 1.0);
}
"""


def shaders() -> dict[str, str]:
    out = {version: tracer_glsl(version) for version in VERSIONS}
    out["resolve"] = resolve_glsl()
    out["vertex"] = VERTEX
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[0] not in ("--js", "--glsl"):
        print(__doc__.split("\n\n")[1])
        return 2
    try:
        made = shaders()
    except PortError as e:
        print(f"tracer_port: {e}", file=sys.stderr)
        return 1
    out = Path(argv[1])
    if argv[0] == "--glsl":
        out.mkdir(parents=True, exist_ok=True)
        for name, text in made.items():
            (out / f"{name}.glsl").write_text(text)
        print(f"tracer_port: {len(made)} shaders in {out}")
        return 0
    runtime = RUNTIME.read_text()
    marker = "const SHADERS = null; // tracer_port.py puts the shaders here"
    if marker not in runtime:
        print("tracer_port: page_tracer.js has no place for the shaders", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(runtime.replace(marker, "const SHADERS = " + json.dumps(made) + ";"))
    print(f"tracer_port: {out} ({out.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
