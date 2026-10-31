// Best, path traced (PathTracer): light followed from the camera into the
// set, bounce by bounce, on the graphics card's own ray tracing.
//
// Every pass adds one sample to every pixel of a running sum (accum); the
// picture is that sum over the passes, tone-mapped by
// path_tracer_resolve.glsl. A sample is a path: from the eye through a
// point of the pixel and of the lens, off the plastic, the sweep and the
// glass, each bounce lit by the lights directly (a shadow ray to each, the
// key from anywhere on its area) and by the sky or a photographed place
// (picked in proportion to its light, weighed against the bounce that could
// have found it, multiple importance sampling). What a raster renderer
// fakes comes out of this whole: soft shadows that widen away from what
// casts them, light bounced off the floor and between the parts, glass that
// tints what is behind it.
//
// Units are the window's (Forward+): a directional light of energy e lights
// a white face turned to it e, and a sky of radiance a lights an open white
// face a. The resolve meters the exposure on top.

#[raygen]

#version 460
#extension GL_EXT_ray_tracing : require

struct Hit {
	vec3 normal;
	float t;
	vec3 geometric;
	uint instance;
	// Where, in the part's own space.
	vec3 local;
	float unused;
};

layout(location = 0) rayPayloadEXT Hit hit;

layout(set = 0, binding = 0) uniform accelerationStructureEXT tlas;
layout(set = 0, binding = 1, rgba32f) uniform image2D accum;

struct Light {
	// Towards the light, and the half-angle of its disc, radians.
	vec4 toward;
	// Its colour times its energy, and whether it casts a shadow.
	vec4 colour;
};

layout(set = 0, binding = 2, std430) readonly buffer Scene {
	// The eye, and the lens's radius (LDU, 0 a pinhole).
	vec4 origin;
	// Right, scaled to the picture's half width at depth 1.
	vec4 across;
	// Up, scaled to its half height at depth 1.
	vec4 up;
	// Back out of the picture; w the distance in focus.
	vec4 back;
	// Width, height, the most bounces, whether there is clear plastic.
	vec4 size;
	// The even sky (rgb, linear), and whether a panorama lights instead.
	vec4 sky;
	// The panorama's energy, its turn, how much of its room is kept (the
	// product look's flags; 1 keeps all), its cells across.
	vec4 place;
	// What the eye sees where nothing is: rgb, and 0 when that is nothing
	// at all (a picture with no backdrop).
	vec4 background;
	// The sweep: its level (StudioRender meters it), how far it falls
	// away, and over what distance from the model.
	vec4 sweep;
	// Its colour (linear) and whether there is one.
	vec4 sweep_colour;
	// Where the model stands on it, and the panorama's cells down.
	vec4 sweep_origin;
	// The look (0 the window's, 1 the product's), how many lights, the
	// sky's top and horizon (the window's procedural sky) packed below.
	vec4 look;
	vec4 sky_top;
	vec4 sky_horizon;
	vec4 sky_ground;
	Light lights[4];
} scene;

struct Instance {
	// Linear colour and alpha.
	vec4 colour;
	// Fleck colour (linear) and finish + fleck fraction, as BrickWorld packs it.
	vec4 custom;
	// The part's box, for the seam where it meets the next.
	vec4 box_min;
	vec4 box_max;
	// Mesh, kind (0 plastic, 1 clear plastic, 2 the sweep), unused, unused.
	uvec4 info;
};

layout(set = 0, binding = 3, std430) readonly buffer Instances {
	Instance instances[];
};

layout(set = 0, binding = 8) uniform sampler2D place_map;

// The panorama's table for picking a direction in proportion to its light:
// rows' cumulative shares, then each row's cells'.
layout(set = 0, binding = 9, std430) readonly buffer PlaceTable {
	float table[];
};

layout(push_constant, std430) uniform Pass {
	uint first;
	uint count;
	uint seed;
	uint reset;
	// The first of the rows this pass gives its samples.
	uint row;
	uint unused_a;
	uint unused_b;
	uint unused_c;
} pass;

const float PI = 3.14159265358979;
const uint KIND_PLASTIC = 0u;
const uint KIND_GLASS = 1u;
const uint KIND_SWEEP = 2u;
const uint MASK_SOLID = 0x01u;
const uint MASK_GLASS = 0x02u;
const uint MASK_SWEEP = 0x04u;

const int FINISH_PLASTIC = 0;
const int FINISH_CHROME = 1;
const int FINISH_METAL = 2;
const int FINISH_PEARL = 3;
const int FINISH_GLOW = 7;
const int FINISH_FLUORESCENT = 8;
const int FINISH_RUBBER = 9;
const int FINISH_FABRIC = 10;

// -- random numbers ----------------------------------------------------------

uint rng_state;

uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float rand() {
	rng_state = pcg(rng_state);
	return float(rng_state >> 8) * (1.0 / 16777216.0);
}

vec2 rand2() {
	return vec2(rand(), rand());
}

// -- geometry ----------------------------------------------------------------

void basis(vec3 n, out vec3 t, out vec3 b) {
	float s = n.z >= 0.0 ? 1.0 : -1.0;
	float a = -1.0 / (s + n.z);
	float c = n.x * n.y * a;
	t = vec3(1.0 + s * n.x * n.x * a, s * c, -s * n.x);
	b = vec3(c, s + n.y * n.y * a, -n.y);
}

vec3 cosine_around(vec3 n, vec2 u) {
	float r = sqrt(u.x);
	float phi = 2.0 * PI * u.y;
	vec3 t;
	vec3 b;
	basis(n, t, b);
	return normalize(t * (r * cos(phi)) + b * (r * sin(phi)) + n * sqrt(max(1.0 - u.x, 0.0)));
}

vec3 in_cone(vec3 axis, float half_angle, vec2 u) {
	if (half_angle <= 0.0) {
		return axis;
	}
	float cos_max = cos(half_angle);
	float z = mix(cos_max, 1.0, u.x);
	float r = sqrt(max(1.0 - z * z, 0.0));
	float phi = 2.0 * PI * u.y;
	vec3 t;
	vec3 b;
	basis(axis, t, b);
	return normalize(t * (r * cos(phi)) + b * (r * sin(phi)) + axis * z);
}

// -- the sky -----------------------------------------------------------------

// A panorama's point for a direction, as Godot's sky reads one (across is
// atan2(x, -z), down is acos(y)), the panorama turned about the vertical.
vec2 place_uv(vec3 way) {
	float turn = scene.place.y;
	float c = cos(-turn);
	float s = sin(-turn);
	vec3 own = vec3(c * way.x + s * way.z, way.y, -s * way.x + c * way.z);
	float around = atan(own.x, -own.z);
	if (around < 0.0) {
		around += 2.0 * PI;
	}
	return vec2(around / (2.0 * PI), acos(clamp(own.y, -1.0, 1.0)) / PI);
}

vec3 place_way(vec2 uv) {
	float around = uv.x * 2.0 * PI;
	float down = uv.y * PI;
	vec3 own = vec3(sin(around) * sin(down), cos(down), -cos(around) * sin(down));
	float turn = scene.place.y;
	float c = cos(turn);
	float s = sin(turn);
	return vec3(c * own.x + s * own.z, own.y, -s * own.x + c * own.z);
}

vec3 sky_light(vec3 way) {
	if (scene.sky.w > 0.5) {
		vec3 light = textureLod(place_map, place_uv(way), 0.0).rgb * scene.place.x;
		if (scene.place.z < 1.0) {
			float level = dot(light, vec3(0.2126, 0.7152, 0.0722));
			light *= mix(scene.place.z, 1.0, smoothstep(2.0, 6.0, level));
		}
		return light;
	}
	// The window's own sky: lighter towards the horizon, darker below.
	vec3 above = mix(scene.sky_horizon.rgb, scene.sky_top.rgb, pow(max(way.y, 0.0), 0.6));
	vec3 below = mix(scene.sky_horizon.rgb, scene.sky_ground.rgb, pow(max(-way.y, 0.0), 0.4));
	return scene.sky.rgb * (way.y >= 0.0 ? above : below);
}

// How likely the panorama's table is to pick this direction, per steradian.
float place_pdf(vec3 way) {
	if (scene.sky.w < 0.5) {
		return 0.0;
	}
	int wide = int(scene.place.w);
	int tall = int(scene.sweep_origin.w);
	vec2 uv = place_uv(way);
	int y = clamp(int(uv.y * float(tall)), 0, tall - 1);
	int x = clamp(int(uv.x * float(wide)), 0, wide - 1);
	float row = table[y] - (y > 0 ? table[y - 1] : 0.0);
	int base = tall + y * wide;
	float cell = table[base + x] - (x > 0 ? table[base + x - 1] : 0.0);
	float sine = sin((float(y) + 0.5) / float(tall) * PI);
	return row * cell * float(wide * tall) / max(2.0 * PI * PI * sine, 1e-6);
}

int search(int start, int count, float u) {
	int low = 0;
	int high = count - 1;
	while (low < high) {
		int middle = (low + high) / 2;
		if (table[start + middle] < u) {
			low = middle + 1;
		} else {
			high = middle;
		}
	}
	return low;
}

vec3 place_pick(vec2 u, out float pdf) {
	int wide = int(scene.place.w);
	int tall = int(scene.sweep_origin.w);
	int y = search(0, tall, u.x);
	int x = search(tall + y * wide, wide, u.y);
	vec2 uv = vec2((float(x) + rand()) / float(wide), (float(y) + rand()) / float(tall));
	vec3 way = place_way(uv);
	pdf = place_pdf(way);
	return way;
}

// -- the plastic -------------------------------------------------------------

struct Surface {
	vec3 albedo;
	vec3 emission;
	float metallic;
	float roughness;
	float specular;
	float coat;
	float coat_roughness;
};

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThanEqual(c, vec3(0.04045)));
}

// How much of a seam a point of a part is in (plastic_body's seam_at): a
// wall of bricks reads as courses of bricks.
float seam_at(vec3 at, vec3 low, vec3 high, float width) {
	vec3 size = high - low;
	if (size.x <= 0.0 || size.y <= 0.0 || size.z <= 0.0) {
		return 0.0;
	}
	vec3 d = min(at - low, high - at);
	float nearest = min(d.x, min(d.y, d.z));
	float furthest = max(d.x, max(d.y, d.z));
	float second = d.x + d.y + d.z - nearest - furthest;
	return 1.0 - smoothstep(width * 0.5, width, second);
}

Surface surface_of(Instance thing, vec3 at, vec3 local) {
	Surface s;
	vec3 body = thing.colour.rgb;
	int finish = int(floor(thing.custom.w + 0.001));
	bool product = scene.look.x > 0.5;
	s.emission = vec3(0.0);
	s.metallic = 0.0;
	s.roughness = product ? 0.3 : 0.35;
	s.specular = product ? 0.35 : 0.5;
	s.coat = product ? 0.55 : 0.0;
	s.coat_roughness = 0.07;
	if (thing.info.y == KIND_SWEEP) {
		// Paper: matte, its colour falling away from under the model.
		vec3 flat_at = at - scene.sweep_origin.xyz;
		float along = length(flat_at.xz) + max(flat_at.y, 0.0);
		float lit = 1.0 - scene.sweep.y * smoothstep(scene.sweep.z, scene.sweep.w, along);
		s.albedo = scene.sweep_colour.rgb * lit * lit;
		s.roughness = 0.9;
		s.specular = 0.08;
		s.coat = 0.0;
		return s;
	}
	// The seam, in the part's own space.
	float seam = seam_at(local, thing.box_min.xyz, thing.box_max.xyz, 0.6);
	float luminance_in = dot(body, vec3(0.2126, 0.7152, 0.0722));
	vec3 seam_colour = luminance_in < 0.025 ? body + vec3(0.03) : body * 0.55;
	body = mix(body, seam_colour, seam);
	s.albedo = body;
	if (finish == FINISH_CHROME) {
		s.albedo = max(body, vec3(0.12));
		s.metallic = 1.0;
		s.roughness = 0.06;
		s.coat = 0.0;
	} else if (finish == FINISH_METAL) {
		s.albedo = max(body, vec3(0.06)) * 0.9;
		s.metallic = 1.0;
		s.roughness = 0.34;
		s.coat = product ? 1.0 : 0.0;
		s.coat_roughness = 0.05;
	} else if (finish == FINISH_PEARL) {
		s.metallic = 0.65;
		s.roughness = 0.3;
		s.coat = product ? 0.8 : 0.0;
		s.coat_roughness = 0.08;
	} else if (finish == FINISH_RUBBER || finish == FINISH_FABRIC) {
		s.roughness = 0.8;
		s.specular = 0.25;
		s.coat = 0.0;
	} else if (finish == FINISH_GLOW) {
		s.emission = body * 0.25;
	} else if (finish == FINISH_FLUORESCENT) {
		s.emission = body * 0.18;
	}
	return s;
}

float ggx_d(float n_h, float a) {
	float a2 = a * a;
	float d = n_h * n_h * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d);
}

float smith_g1(float n_v, float a) {
	float a2 = a * a;
	return 2.0 * n_v / (n_v + sqrt(a2 + (1.0 - a2) * n_v * n_v));
}

vec3 schlick(vec3 f0, float c) {
	float m = 1.0 - c;
	float m2 = m * m;
	return f0 + (vec3(1.0) - f0) * (m2 * m2 * m);
}

// A visible normal of a GGX surface (Heitz 2018), in the frame of n.
vec3 ggx_normal(vec3 n, vec3 v, float a, vec2 u) {
	vec3 t;
	vec3 b;
	basis(n, t, b);
	vec3 ve = normalize(vec3(a * dot(v, t), a * dot(v, b), dot(v, n)));
	float len2 = ve.x * ve.x + ve.y * ve.y;
	vec3 t1 = len2 > 0.0 ? vec3(-ve.y, ve.x, 0.0) * inversesqrt(len2) : vec3(1.0, 0.0, 0.0);
	vec3 t2 = cross(ve, t1);
	float r = sqrt(u.x);
	float phi = 2.0 * PI * u.y;
	float p1 = r * cos(phi);
	float p2 = r * sin(phi);
	float s = 0.5 * (1.0 + ve.z);
	p2 = (1.0 - s) * sqrt(max(1.0 - p1 * p1, 0.0)) + s * p2;
	vec3 ne = p1 * t1 + p2 * t2 + sqrt(max(0.0, 1.0 - p1 * p1 - p2 * p2)) * ve;
	ne = normalize(vec3(a * ne.x, a * ne.y, max(ne.z, 1e-6)));
	return normalize(t * ne.x + b * ne.y + n * ne.z);
}

float ggx_pdf(vec3 n, vec3 v, vec3 l, float a) {
	vec3 h = normalize(v + l);
	float n_v = max(dot(n, v), 1e-4);
	float n_h = max(dot(n, h), 0.0);
	return ggx_d(n_h, a) * smith_g1(n_v, a) * max(dot(v, h), 0.0) / n_v / max(4.0 * dot(v, h), 1e-6);
}

// The lobes' shares when picking a bounce.
vec3 lobe_shares(Surface s) {
	float diffuse = (1.0 - s.metallic) * max(dot(s.albedo, vec3(0.333)), 0.05);
	float spec = mix(0.25 * s.specular, 1.0, s.metallic);
	float coat = 0.25 * s.coat;
	float total = diffuse + spec + coat;
	return vec3(diffuse, spec, coat) / total;
}

// What the surface sends towards v of the light arriving from l, times the
// cosine, and the chance the bounce would have picked l.
vec3 reflect_light(Surface s, vec3 n, vec3 v, vec3 l, out float pdf) {
	float n_l = dot(n, l);
	float n_v = dot(n, v);
	pdf = 0.0;
	if (n_l <= 0.0 || n_v <= 0.0) {
		return vec3(0.0);
	}
	vec3 h = normalize(v + l);
	float n_h = max(dot(n, h), 0.0);
	float v_h = max(dot(v, h), 0.0);
	float a = max(s.roughness * s.roughness, 0.002);
	vec3 f0 = mix(vec3(0.08 * s.specular), s.albedo, s.metallic);
	vec3 f = schlick(f0, v_h);
	vec3 spec = f * ggx_d(n_h, a) * smith_g1(n_v, a) * smith_g1(n_l, a) / max(4.0 * n_v * n_l, 1e-6);
	vec3 kd = (vec3(1.0) - schlick(f0, n_v)) * (1.0 - s.metallic);
	vec3 result = kd * s.albedo / PI + spec;
	vec3 shares = lobe_shares(s);
	pdf = shares.x * n_l / PI + shares.y * ggx_pdf(n, v, l, a);
	if (s.coat > 0.0) {
		float ac = max(s.coat_roughness * s.coat_roughness, 0.002);
		float fc = schlick(vec3(0.04), v_h).x * s.coat;
		float coat = fc * ggx_d(n_h, ac) * smith_g1(n_v, ac) * smith_g1(n_l, ac) / max(4.0 * n_v * n_l, 1e-6);
		float under = 1.0 - schlick(vec3(0.04), n_v).x * s.coat;
		result = result * under + vec3(coat);
		pdf += shares.z * ggx_pdf(n, v, l, ac);
	}
	return result * n_l;
}

vec3 pick_bounce(Surface s, vec3 n, vec3 v) {
	vec3 shares = lobe_shares(s);
	float u = rand();
	if (u < shares.x) {
		return cosine_around(n, rand2());
	}
	float a = u < shares.x + shares.y ? max(s.roughness * s.roughness, 0.002)
		: max(s.coat_roughness * s.coat_roughness, 0.002);
	vec3 h = ggx_normal(n, v, a, rand2());
	return reflect(-v, h);
}

// -- tracing -----------------------------------------------------------------

bool trace(vec3 from, vec3 way, float far, uint mask, uint flags) {
	hit.t = -1.0;
	traceRayEXT(tlas, flags, mask, 0, 0, 0, from, 0.0, way, far, 0);
	return hit.t >= 0.0;
}

// How much light gets through from a point towards a light: none past
// anything solid, tinted by the clear plastic on the way.
vec3 through(vec3 from, vec3 way) {
	if (trace(from, way, 1e7, MASK_SOLID | MASK_SWEEP,
			gl_RayFlagsOpaqueEXT | gl_RayFlagsTerminateOnFirstHitEXT)) {
		return vec3(0.0);
	}
	vec3 let = vec3(1.0);
	if (scene.size.w < 0.5) {
		return let;
	}
	vec3 at = from;
	for (int n = 0; n < 8; n++) {
		if (!trace(at, way, 1e7, MASK_GLASS, gl_RayFlagsOpaqueEXT)) {
			return let;
		}
		Instance glass = instances[hit.instance];
		let *= sqrt(max(glass.colour.rgb, vec3(0.0)));
		at = at + way * hit.t + way * 0.02;
		if (max(let.r, max(let.g, let.b)) < 0.01) {
			return vec3(0.0);
		}
	}
	return let;
}

float balance(float a, float b) {
	float a2 = a * a;
	return a2 / max(a2 + b * b, 1e-12);
}

// How likely the sky's own pick is to be this direction from a surface
// facing n: the place's table, or the even sky's cosine.
float sky_pdf(vec3 way, vec3 n) {
	return scene.sky.w > 0.5 ? place_pdf(way) : max(dot(n, way), 0.0) / PI;
}

// The light arriving at a point of a surface straight from the lights and
// the sky.
vec3 direct(Surface s, vec3 at, vec3 n, vec3 v) {
	vec3 sum = vec3(0.0);
	int lights = int(scene.look.y);
	for (int i = 0; i < lights; i++) {
		Light light = scene.lights[i];
		vec3 l = in_cone(light.toward.xyz, light.toward.w, rand2());
		float pdf;
		vec3 f = reflect_light(s, n, v, l, pdf);
		if (max(f.r, max(f.g, f.b)) <= 0.0) {
			continue;
		}
		vec3 let = light.colour.w > 0.5 ? through(at, l) : vec3(1.0);
		sum += f * light.colour.rgb * PI * let;
	}
	// The sky, or the place: picked by its light where there is a table,
	// over the hemisphere otherwise, and weighed against the bounce.
	float pdf_light;
	vec3 l;
	if (scene.sky.w > 0.5) {
		l = place_pick(rand2(), pdf_light);
	} else {
		l = cosine_around(n, rand2());
		pdf_light = max(dot(n, l), 0.0) / PI;
	}
	if (pdf_light > 0.0) {
		float pdf_bounce;
		vec3 f = reflect_light(s, n, v, l, pdf_bounce);
		if (max(f.r, max(f.g, f.b)) > 0.0) {
			vec3 let = through(at, l);
			sum += f * sky_light(l) * let * balance(pdf_light, pdf_bounce) / pdf_light;
		}
	}
	return sum;
}

void main() {
	ivec2 pixel = ivec2(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y + pass.row);
	vec2 size = scene.size.xy;
	if (float(pixel.y) >= size.y) {
		return;
	}
	vec4 total = pass.reset != 0u ? vec4(0.0) : imageLoad(accum, pixel);
	int most = int(scene.size.z);
	for (uint k = 0u; k < pass.count; k++) {
		uint sample_index = pass.first + k;
		rng_state = pcg(uint(pixel.x) * 9781u ^ pcg(uint(pixel.y) * 6271u ^ pcg(sample_index * 26699u + pass.seed)));
		// Through a point of the pixel (a tent a pixel and a half across)
		// and of the lens.
		vec2 r = rand2();
		vec2 jitter = vec2(r.x < 0.5 ? sqrt(2.0 * r.x) - 1.0 : 1.0 - sqrt(2.0 - 2.0 * r.x),
			r.y < 0.5 ? sqrt(2.0 * r.y) - 1.0 : 1.0 - sqrt(2.0 - 2.0 * r.y)) * 0.75;
		vec2 film = (vec2(pixel) + vec2(0.5) + jitter) / size * 2.0 - vec2(1.0);
		vec3 way = normalize(scene.across.xyz * film.x - scene.up.xyz * film.y - scene.back.xyz);
		vec3 from = scene.origin.xyz;
		if (scene.origin.w > 0.0) {
			vec3 focus = from + way * (scene.back.w / dot(way, -normalize(scene.back.xyz)));
			vec2 disc = rand2();
			float radius = sqrt(disc.x) * scene.origin.w;
			float angle = 2.0 * PI * disc.y;
			from += (normalize(scene.across.xyz) * cos(angle) + normalize(scene.up.xyz) * sin(angle)) * radius;
			way = normalize(focus - from);
		}
		vec3 radiance = vec3(0.0);
		vec3 carried = vec3(1.0);
		float covered = 0.0;
		// How the path left its last surface: the chance of that bounce,
		// and that surface's facing, for weighing the sky it finds; and
		// whether it has gone only straight on from the eye.
		float last_pdf = 0.0;
		vec3 last_n = vec3(0.0, 1.0, 0.0);
		bool sharp = true;
		bool straight = true;
		int bounces = 0;
		for (int event = 0; event < most + 8; event++) {
			if (!trace(from, way, 1e7, 0xFFu, gl_RayFlagsOpaqueEXT)) {
				if (straight) {
					// What is behind everything, as the eye sees it.
					radiance += carried * scene.background.rgb;
				} else {
					float weight = sharp ? 1.0 : balance(last_pdf, sky_pdf(way, last_n));
					radiance += carried * sky_light(way) * weight;
				}
				break;
			}
			Instance thing = instances[hit.instance];
			vec3 at = from + way * hit.t;
			vec3 v = -way;
			vec3 ng = hit.geometric;
			vec3 n = hit.normal;
			if (dot(ng, v) < 0.0) {
				ng = -ng;
			}
			if (dot(n, ng) < 0.0) {
				n = -n;
			}
			if (dot(n, v) < 0.01) {
				n = normalize(n + ng * (0.02 - dot(n, v)));
			}
			if (thing.info.y == KIND_GLASS) {
				// Thin glass: what it reflects of the sky added at once, by a
				// ray of its own, and the path goes on through it, tinted.
				// Picking one or the other at random left a grain of sky
				// over everything seen through a windscreen.
				float f = schlick(vec3(0.045), abs(dot(ng, v))).x;
				vec3 mirrored = reflect(way, n);
				if (!trace(at + ng * 0.02, mirrored, 1e7, MASK_SOLID | MASK_SWEEP, gl_RayFlagsOpaqueEXT)) {
					radiance += carried * f * sky_light(mirrored);
				}
				vec3 tint = sqrt(max(thing.colour.rgb, vec3(0.0)));
				carried *= tint * (1.0 - f);
				from = at - ng * 0.02;
				if (straight) {
					covered = max(covered, 1.0 - min(tint.r, min(tint.g, tint.b)) * (1.0 - covered));
				}
				sharp = true;
				continue;
			}
			if (straight && thing.info.y != KIND_SWEEP) {
				covered = 1.0;
			}
			Surface s = surface_of(thing, at, hit.local);
			// The sweep is brought to its colour for the eye alone, as the
			// window brings it (StudioRender meters its level), and by
			// scaling what it shows, so its shadows keep their depth. As
			// light added to it, it lit the model too: the model was metered
			// darker, the sweep lifted again, its white bounce washed the
			// plastic's colours out, and the shadows on it were lifted away.
			if (straight && thing.info.y == KIND_SWEEP) {
				carried *= scene.sweep.x;
			}
			straight = false;
			radiance += carried * s.emission;
			from = at + ng * 0.02;
			radiance += carried * direct(s, from, n, v);
			if (bounces >= most) {
				break;
			}
			vec3 l = pick_bounce(s, n, v);
			float pdf;
			vec3 f = reflect_light(s, n, v, l, pdf);
			if (pdf <= 0.0 || dot(l, ng) <= 0.0) {
				break;
			}
			carried *= f / pdf;
			last_pdf = pdf;
			last_n = n;
			sharp = false;
			bounces++;
			if (bounces > 2) {
				float keep = clamp(max(carried.r, max(carried.g, carried.b)), 0.05, 0.95);
				if (rand() > keep) {
					break;
				}
				carried /= keep;
			}
			way = l;
		}
		// A firefly's worth is all one sample may give.
		float level = max(radiance.r, max(radiance.g, radiance.b));
		if (level > 40.0) {
			radiance *= 40.0 / level;
		}
		total += vec4(radiance, covered);
	}
	imageStore(accum, pixel, total);
}

#[miss]

#version 460
#extension GL_EXT_ray_tracing : require

struct Hit {
	vec3 normal;
	float t;
	vec3 geometric;
	uint instance;
	// Where, in the part's own space.
	vec3 local;
	float unused;
};

layout(location = 0) rayPayloadInEXT Hit hit;

void main() {
	hit.t = -1.0;
}

#[closest_hit]

#version 460
#extension GL_EXT_ray_tracing : require

struct Hit {
	vec3 normal;
	float t;
	vec3 geometric;
	uint instance;
	// Where, in the part's own space.
	vec3 local;
	float unused;
};

layout(location = 0) rayPayloadInEXT Hit hit;
hitAttributeEXT vec2 weights;

layout(set = 0, binding = 4, std430) readonly buffer Meshes {
	uvec4 meshes[];
};
layout(set = 0, binding = 5, std430) readonly buffer Positions {
	float positions[];
};
layout(set = 0, binding = 6, std430) readonly buffer Normals {
	float normals[];
};
layout(set = 0, binding = 7, std430) readonly buffer Indices {
	uint indices[];
};

struct Instance {
	vec4 colour;
	vec4 custom;
	vec4 box_min;
	vec4 box_max;
	uvec4 info;
};

layout(set = 0, binding = 3, std430) readonly buffer Instances {
	Instance instances[];
};

vec3 at(uint v) {
	return vec3(positions[v * 3u], positions[v * 3u + 1u], positions[v * 3u + 2u]);
}

vec3 normal_at(uint v) {
	return vec3(normals[v * 3u], normals[v * 3u + 1u], normals[v * 3u + 2u]);
}

void main() {
	uint which = gl_InstanceCustomIndexEXT;
	uvec4 mesh = meshes[instances[which].info.x];
	uint first = mesh.y + uint(gl_PrimitiveID) * 3u;
	uint a = mesh.x + indices[first];
	uint b = mesh.x + indices[first + 1u];
	uint c = mesh.x + indices[first + 2u];
	vec3 pa = at(a);
	vec3 pb = at(b);
	vec3 pc = at(c);
	vec3 w = vec3(1.0 - weights.x - weights.y, weights.x, weights.y);
	vec3 n = normal_at(a) * w.x + normal_at(b) * w.y + normal_at(c) * w.z;
	vec3 g = cross(pb - pa, pc - pa);
	mat3 to_world = mat3(gl_WorldToObjectEXT);
	// Normals go by the inverse transpose: v * M is transpose(M) * v.
	hit.geometric = normalize(g * to_world);
	hit.normal = dot(n, n) > 1e-12 ? normalize(n * to_world) : hit.geometric;
	hit.t = gl_HitTEXT;
	hit.instance = which;
	hit.local = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
}
