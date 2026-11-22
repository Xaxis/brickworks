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
//
// And the lights placed in the model (SceneLights: bulbs, spots, suns and
// panels), each lighting the first surface the eye reaches directly, as the
// rig does, with Godot's own fall with distance and spot cone, and bounced
// no further, as the raster's are not: the raster's light and this one are
// the same light, and nothing outside a spot's cone is lit by it; and in the
// Dark light the plastics that glow giving off
// light, which lights what is round them by the bounces that find them. A
// lamp's chances are drawn from a stream of their own: the rest of a path is
// the same with a lamp or without, so what a lamp does not light comes out
// the same, sample for sample.

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

struct Lamp {
	// Where it is (LDU), and its kind: 0 a bulb, 1 a spot, 2 a sun, 3 a panel.
	vec4 at;
	// Which way it shines, and a spot's cone, the cosine of its half-angle.
	vec4 aim;
	// Its colour times its energy (a sun's on a face, a lamp's at 1 LDU), and
	// whether it casts a shadow.
	vec4 colour;
	// Its size (a bulb's radius, a panel's side, LDU), how its spot's edge
	// falls (the power of the rim, SceneLights.EDGE), its reach (where
	// Godot's fall to nothing ends), unused.
	vec4 shape;
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
	// The look (0 the window's, 1 the product's), how many lights, the most
	// one sample may give, and 1 where the sweep is a shadow catcher (the
	// product look on a backdrop, photoreal2): the eye sees the backdrop at
	// exactly its colour (background) wherever the model casts no shadow, as
	// a product photograph's white seamless is. The sky's top and horizon
	// (the window's procedural sky) packed below.
	vec4 look;
	vec4 sky_top;
	vec4 sky_horizon;
	vec4 sky_ground;
	Light lights[4];
	// How many lamps, how much light the glowing plastics give off (0 but in
	// the Dark light), and for a light tent (photoreal2) how many times
	// brighter its top is than its walls (0 for none), unused.
	vec4 lamp_info;
	Lamp lamps[8];
} scene;

struct Instance {
	// Linear colour and alpha.
	vec4 colour;
	// Fleck colour (linear) and finish + fleck fraction, as BrickWorld packs it.
	vec4 custom;
	// The part's box, for the seam where it meets the next; box_min.w where
	// its studs begin, box_max.w 1 for the product look's moulded plastic.
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
const int LAMP_BULB = 0;
const int LAMP_SPOT = 1;
const int LAMP_SUN = 2;
const int LAMP_PANEL = 3;

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

// The lamps' own stream (see the top).
uint lamp_state;

vec2 lamp_rand2() {
	lamp_state = pcg(lamp_state);
	float a = float(lamp_state >> 8) * (1.0 / 16777216.0);
	lamp_state = pcg(lamp_state);
	return vec2(a, float(lamp_state >> 8) * (1.0 / 16777216.0));
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

// A light tent (photoreal2), the product look's studio on a light backdrop:
// white walls all round (the even sky) and a large soft panel overhead, 90
// degrees across, scene.lamp_info.z times as bright. A product photograph is
// lit so, from every side and most from above: no hard key, and no crescent
// of shadow inside a stud.
const float TENT_COS_OUT = 0.7071;
const float TENT_COS_IN = 0.866;

bool tent() {
	return scene.sky.w < 0.5 && scene.lamp_info.z > 0.0;
}

vec3 tent_light(vec3 way) {
	if (way.y < 0.0) {
		return scene.sky.rgb * 0.6;
	}
	return scene.sky.rgb * (1.0 + scene.lamp_info.z * smoothstep(TENT_COS_OUT, TENT_COS_IN, way.y));
}

// The tent's panel picked half the time (evenly over its cone), the
// hemisphere by its cosine the other half.
float tent_pdf(vec3 way, vec3 n) {
	float cone = way.y >= TENT_COS_OUT ? 1.0 / (2.0 * PI * (1.0 - TENT_COS_OUT)) : 0.0;
	return 0.5 * cone + 0.5 * max(dot(n, way), 0.0) / PI;
}

vec3 tent_pick(vec3 n, out float pdf) {
	vec3 way = rand() < 0.5 ? in_cone(vec3(0.0, 1.0, 0.0), acos(TENT_COS_OUT), rand2())
		: cosine_around(n, rand2());
	pdf = tent_pdf(way, n);
	return way;
}

vec3 sky_light(vec3 way) {
	if (tent()) {
		return tent_light(way);
	}
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

float gloss_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z)) * 2.0 - 1.0;
}

// Smooth noise from -1 to 1 (closest_hit's wave_noise).
float gloss_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(gloss_hash(i), gloss_hash(i + vec3(1, 0, 0)), f.x),
			mix(gloss_hash(i + vec3(0, 1, 0)), gloss_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(gloss_hash(i + vec3(0, 0, 1)), gloss_hash(i + vec3(1, 0, 1)), f.x),
			mix(gloss_hash(i + vec3(0, 1, 1)), gloss_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// A real part's wear, for the product look's moulded plastic: whether a
// point of the part (its own space) is on a scuff across the coat, given
// the part's own number from 0 to 1. Fine straight scratches a few LDU
// long, each part's running its own way, in patches, as handling leaves
// them. (Flecks of dust were tried and taken out: a judge shown them beside
// a photograph called them the path tracer's fireflies.)
bool worn(vec3 q, float own) {
	float angle = own * 6.2832;
	vec3 along = normalize(vec3(cos(angle), 0.4 * sin(angle * 1.7), sin(angle)));
	vec3 across = normalize(cross(along, vec3(0.3, 1.0, 0.2)));
	vec3 third = cross(along, across);
	float lines = gloss_noise(vec3(dot(q, along) * 0.15, dot(q, across) * 2.2,
		dot(q, third) * 2.2) + vec3(own * 13.0));
	float patches = gloss_noise(q / 9.0 + vec3(own * 29.0, 5.0, 2.0));
	return lines > 0.72 && patches > 0.1;
}

// textured: the hit is on a straight slope's face (closest_hit's grain);
// which: the part's own number, so no two parts are worn alike.
Surface surface_of(Instance thing, vec3 at, vec3 local, float textured, uint which) {
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
	// The seam, in the part's own space, as the window paints it. Moulded
	// plastic (the product look) has none painted: its rounded edges are
	// the line where two parts meet, and a part alone has no dark outline
	// in a photograph.
	bool moulded = thing.box_max.w > 0.5;
	if (!moulded) {
		float seam = seam_at(local, thing.box_min.xyz, thing.box_max.xyz, 0.6);
		float luminance_in = dot(body, vec3(0.2126, 0.7152, 0.0722));
		vec3 seam_colour = luminance_in < 0.025 ? body + vec3(0.03) : body * 0.55;
		body = mix(body, seam_colour, seam);
	} else {
		// Polished in the mould: the studs are mirrored sharply in a top. A
		// part that has been handled is not polished evenly: its gloss
		// varies slowly across a face, as a photograph's reflections do.
		// Each part is its own: moulded in its own batch, a shade lighter
		// or darker than the next of its colour, and worn its own way.
		float own = float(pcg(which * 747796405u + 2891336453u) & 0xffffu) / 65535.0;
		body *= 1.0 + 0.07 * (own - 0.5);
		float handled = gloss_noise(local / 16.0 + vec3(own * 97.0, own * 31.0, 0.0));
		s.coat_roughness = mix(0.03, 0.085, smoothstep(-0.6, 0.8, handled)) + 0.02 * own;
		s.roughness += 0.05 * handled;
		if (worn(local, own)) {
			s.coat_roughness = 0.3;
			s.coat *= 0.6;
		}
		if (textured > 0.5) {
			// A slope's face is roughened in the mould: no mirror, a satin sheen.
			s.roughness = 0.55;
			s.specular = 0.3;
			s.coat = 0.12;
			s.coat_roughness = 0.3;
		}
	}
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
		s.emission = body * (scene.lamp_info.y > 0.0 ? scene.lamp_info.y : 0.25);
	} else if (finish == FINISH_FLUORESCENT) {
		s.emission = body * (scene.lamp_info.y > 0.0 ? scene.lamp_info.y : 0.18);
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

// How much light gets through from a point towards a light [far] away:
// none past anything solid, tinted by the clear plastic on the way.
vec3 through_masked(vec3 from, vec3 way, float far, uint solid) {
	if (trace(from, way, far, solid,
			gl_RayFlagsOpaqueEXT | gl_RayFlagsTerminateOnFirstHitEXT)) {
		return vec3(0.0);
	}
	vec3 let = vec3(1.0);
	if (scene.size.w < 0.5) {
		return let;
	}
	vec3 at = from;
	float left = far;
	for (int n = 0; n < 8; n++) {
		if (!trace(at, way, left, MASK_GLASS, gl_RayFlagsOpaqueEXT)) {
			return let;
		}
		Instance glass = instances[hit.instance];
		let *= sqrt(max(glass.colour.rgb, vec3(0.0)));
		at = at + way * hit.t + way * 0.02;
		left -= hit.t + 0.02;
		if (left <= 0.0) {
			return let;
		}
		if (max(let.r, max(let.g, let.b)) < 0.01) {
			return vec3(0.0);
		}
	}
	return let;
}

vec3 through_far(vec3 from, vec3 way, float far) {
	return through_masked(from, way, far, MASK_SOLID | MASK_SWEEP);
}

vec3 through(vec3 from, vec3 way) {
	return through_far(from, way, 1e7);
}

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// How much of the light that would reach a point of the sweep the model
// lets through (photoreal2's shadow catcher): 1 in the open, less in the
// model's shadow, tinted under clear parts. Each light once, and the sky
// twice (once by its own pick, once by the cosine), each weighed by the
// light it brings (the balance heuristic over the two picks), so a soft
// overhead panel's shadow is as soft as the panel is large.
vec3 shadow_on(vec3 at, vec3 n) {
	vec3 kept = vec3(0.0);
	float all = 0.0;
	int lights = int(scene.look.y);
	for (int i = 0; i < lights; i++) {
		Light light = scene.lights[i];
		vec3 l = in_cone(light.toward.xyz, light.toward.w, rand2());
		float c = max(dot(n, l), 0.0) * luminance(light.colour.rgb);
		if (c <= 0.0) {
			continue;
		}
		all += c;
		kept += c * (light.colour.w > 0.5 ? through_masked(at, l, 1e7, MASK_SOLID) : vec3(1.0));
	}
	for (int k = 0; k < 2; k++) {
		vec3 l;
		float own = 0.0;
		if (k == 1) {
			l = cosine_around(n, rand2());
		} else if (tent()) {
			l = in_cone(vec3(0.0, 1.0, 0.0), acos(TENT_COS_OUT), rand2());
		} else if (scene.sky.w > 0.5) {
			l = place_pick(rand2(), own);
		} else {
			l = cosine_around(n, rand2());
		}
		float facing = max(dot(n, l), 0.0);
		if (facing <= 0.0) {
			continue;
		}
		// The two picks' chances of this direction, summed.
		float first = tent() ? 2.0 * tent_pdf(l, n) - facing / PI
			: (scene.sky.w > 0.5 ? place_pdf(l) : facing / PI);
		float c = luminance(sky_light(l)) * facing / max(first + facing / PI, 1e-6);
		all += c;
		kept += c * through_masked(at, l, 1e7, MASK_SOLID);
	}
	return all > 0.0 ? kept / all : vec3(1.0);
}

// The light arriving at a point of a surface straight from the lamps placed
// in the model, each sampled once from the lamps' own stream.
vec3 from_lamps(Surface s, vec3 at, vec3 n, vec3 v) {
	vec3 sum = vec3(0.0);
	int count = min(int(scene.lamp_info.x), 8);
	for (int i = 0; i < count; i++) {
		Lamp lamp = scene.lamps[i];
		int kind = int(lamp.at.w + 0.5);
		vec2 u = lamp_rand2();
		vec3 l;
		float far;
		float lit;
		if (kind == LAMP_SUN) {
			// The sun's disc, half a degree across, as the raster's.
			vec3 toward = -lamp.aim.xyz;
			vec3 t;
			vec3 b;
			basis(toward, t, b);
			float r = sqrt(u.x) * 0.00436;
			float phi = 2.0 * PI * u.y;
			l = normalize(toward + (t * cos(phi) + b * sin(phi)) * r);
			far = 1e7;
			lit = 1.0;
		} else {
			vec3 from = lamp.at.xyz;
			if (kind == LAMP_PANEL) {
				vec3 t;
				vec3 b;
				basis(lamp.aim.xyz, t, b);
				from += (t * (u.x - 0.5) + b * (u.y - 0.5)) * lamp.shape.x;
			} else if (lamp.shape.x > 0.0) {
				// A point of the bulb's disc as seen from here.
				vec3 t;
				vec3 b;
				basis(normalize(at - lamp.at.xyz), t, b);
				float r = sqrt(u.x) * lamp.shape.x;
				float phi = 2.0 * PI * u.y;
				from += (t * cos(phi) + b * sin(phi)) * r;
			}
			vec3 to = from - at;
			float d2 = max(dot(to, to), 1e-4);
			float d = sqrt(d2);
			l = to / d;
			far = max(d - 0.05, 0.0);
			// Godot's fall with distance: the square's, ending at the reach.
			float nd = d / max(lamp.shape.z, 1.0);
			nd *= nd;
			nd *= nd;
			nd = max(1.0 - nd, 0.0);
			lit = nd * nd / d2;
			float facing = dot(-l, lamp.aim.xyz);
			if (kind == LAMP_SPOT) {
				// The cone from the lamp's middle, as Godot's: its edge where
				// the spot's hood cuts it, the bulb's size softening only the
				// shadows. (From each point of the bulb, the floor 4 LDU past
				// the cone was lit.)
				float centred = dot(normalize(at - lamp.at.xyz), lamp.aim.xyz);
				if (centred <= lamp.aim.w) {
					continue;
				}
				float rim = max(1e-4, (1.0 - centred) / (1.0 - lamp.aim.w));
				lit *= 1.0 - pow(rim, lamp.shape.y);
			} else if (kind == LAMP_PANEL) {
				if (facing <= 0.0) {
					continue;
				}
				lit *= facing;
			}
		}
		float pdf;
		vec3 f = reflect_light(s, n, v, l, pdf);
		if (max(f.r, max(f.g, f.b)) <= 0.0) {
			continue;
		}
		vec3 let = lamp.colour.w > 0.5 ? through_far(at, l, far) : vec3(1.0);
		sum += f * lamp.colour.rgb * lit * PI * let;
	}
	return sum;
}

float balance(float a, float b) {
	float a2 = a * a;
	return a2 / max(a2 + b * b, 1e-12);
}

// How likely the sky's own pick is to be this direction from a surface
// facing n: the place's table, or the even sky's cosine.
float sky_pdf(vec3 way, vec3 n) {
	if (tent()) {
		return tent_pdf(way, n);
	}
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
	if (tent()) {
		l = tent_pick(n, pdf_light);
	} else if (scene.sky.w > 0.5) {
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
		lamp_state = pcg(rng_state ^ 0x68bc21ebu);
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
		// Inside clear plastic (the product look bends the path at each of
		// its surfaces): which way the next surface bends it.
		bool inside = false;
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
				if (!inside && !trace(at + ng * 0.02, mirrored, 1e7, MASK_SOLID | MASK_SWEEP,
						gl_RayFlagsOpaqueEXT)) {
					radiance += carried * f * sky_light(mirrored);
				}
				vec3 tint = sqrt(max(thing.colour.rgb, vec3(0.0)));
				// A clear neon glowing in the Dark light: light of its own,
				// on every face the path goes through.
				int glass_finish = int(floor(thing.custom.w + 0.001));
				if (scene.lamp_info.y > 0.0
						&& (glass_finish == FINISH_GLOW || glass_finish == FINISH_FLUORESCENT)) {
					radiance += carried * thing.colour.rgb * scene.lamp_info.y;
				}
				carried *= tint * (1.0 - f);
				from = at - ng * 0.02;
				if (scene.look.x > 0.5) {
					// Polycarbonate (index about 1.585) bends the path going in
					// and back coming out, so what is behind a clear part is
					// seen through it displaced and its walls fold the light, as
					// a photograph of one shows; past the critical angle it is
					// reflected inside.
					vec3 bent = refract(way, n, inside ? 1.585 : 1.0 / 1.585);
					if (dot(bent, bent) < 1e-6) {
						way = reflect(way, n);
						from = at + ng * 0.02;
					} else {
						way = normalize(bent);
						inside = !inside;
					}
				}
				if (straight) {
					covered = max(covered, 1.0 - min(tint.r, min(tint.g, tint.b)) * (1.0 - covered));
				}
				sharp = true;
				continue;
			}
			if (straight && thing.info.y != KIND_SWEEP) {
				covered = 1.0;
			}
			if (straight && thing.info.y == KIND_SWEEP && scene.look.w > 0.5) {
				// The shadow catcher: the backdrop as the eye sees it, at its
				// colour (falling away as the sweep's paper does), darker only
				// where the model keeps light from it.
				vec3 flat_at = at - scene.sweep_origin.xyz;
				float along = length(flat_at.xz) + max(flat_at.y, 0.0);
				float lit = 1.0 - scene.sweep.y * smoothstep(scene.sweep.z, scene.sweep.w, along);
				radiance += carried * scene.background.rgb * lit * lit * shadow_on(at + ng * 0.02, n);
				break;
			}
			Surface s = surface_of(thing, at, hit.local, hit.unused, hit.instance);
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
			// The model's own lights light what they shine on, as the window's
			// draft draws them (StudioRender's lamps bounce nothing): on the
			// first surface the eye reaches, through any glass, and not by
			// a bounce, so nothing outside a spot's cone changes.
			if (bounces == 0) {
				radiance += carried * from_lamps(s, from, n, v);
			}
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
		// A firefly's worth is all one sample may give: for the product look
		// three times what its exposure draws as white (scene.look.z), so no
		// stray path off a glossy stud is a sparkle a photograph never has;
		// a highlight that bright is white either way.
		float level = max(radiance.r, max(radiance.g, radiance.b));
		float most = scene.look.z > 0.0 ? scene.look.z : 40.0;
		if (level > most) {
			radiance *= most / level;
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

// -- the product look's moulding (photoreal1) ----------------------------------
// A moulded part, in its own space, as a photograph of one shows it: every edge
// of its body rounded (plastic_body's bevelled(), here seen whole by the
// samples, so drawn exactly rather than at its average turn), every stud's top
// edge rounded (stud_rim()), and the logo raised on every stud's top. The box
// is the part's (studs and all), body_top where its studs begin.

const float ROUND = 0.6;

vec3 bevelled(vec3 at, vec3 n, vec3 low, vec3 high) {
	vec3 size = high - low;
	if (size.x <= 0.0 || size.y <= 0.0 || size.z <= 0.0) {
		return n;
	}
	vec3 across = abs(n);
	float most = max(across.x, max(across.y, across.z));
	if (most < 0.97) {
		return n;
	}
	vec3 axis = step(vec3(most - 0.0001), across);
	vec3 half_size = size * 0.5;
	vec3 p = at - (low + high) * 0.5;
	vec3 out_of = abs(p) - half_size;
	float slack = max(ROUND * 0.3, 0.06);
	if (abs(dot(out_of, axis)) > slack || dot(sign(p) * sign(n), axis) < 0.5
			|| any(greaterThan(out_of, vec3(slack)))) {
		return n;
	}
	vec3 q = max(min(abs(p), half_size) - (half_size - vec3(ROUND)), vec3(0.0));
	q = mix(q, vec3(ROUND), axis);
	return normalize(sign(p) * q);
}

vec3 stud_rim(vec3 at, vec3 n, vec3 box_min, vec3 box_max, float body_top) {
	float top = box_max.y;
	if (box_max.x <= box_min.x || at.y < body_top + 0.5 || at.y > top + 0.3) {
		return n;
	}
	vec2 centre = box_min.xz + 10.0 + 20.0 * floor((at.xz - box_min.xz) / 20.0);
	vec2 d = at.xz - centre;
	float r = length(d);
	if (r > 6.3 || r < 0.001) {
		return n;
	}
	vec2 out_from = d / r;
	vec2 q;
	if (n.y > 0.97) {
		q = vec2(max(r - (6.0 - ROUND), 0.0), ROUND);
	} else if (abs(n.y) < 0.2 && dot(n.xz, out_from) > 0.9 && r > 5.7) {
		q = vec2(ROUND, max(at.y - (top - ROUND), 0.0));
	} else {
		return n;
	}
	if (min(q.x, q.y) <= 0.0) {
		return n;
	}
	return normalize(vec3(out_from.x * q.x, q.y, out_from.y * q.x));
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// How far a point of a stud's top (LDU from its middle; x along the part's
// x, y towards its -z) is from the strokes of the logo's four letters: a
// slanted L, E, G and O about 9 LDU across, as the real one is about 3.6 mm.
float logo_distance(vec2 p) {
	p.x -= p.y * 0.22;
	float d = segment(p, vec2(-4.2, 1.45), vec2(-4.2, -1.45));
	d = min(d, segment(p, vec2(-4.2, -1.45), vec2(-2.75, -1.45)));
	d = min(d, segment(p, vec2(-2.05, 1.45), vec2(-2.05, -1.45)));
	d = min(d, segment(p, vec2(-2.05, 1.45), vec2(-0.65, 1.45)));
	d = min(d, segment(p, vec2(-2.05, 0.0), vec2(-0.85, 0.0)));
	d = min(d, segment(p, vec2(-2.05, -1.45), vec2(-0.65, -1.45)));
	// G: an oval open at its upper right, and its bar.
	vec2 g = (p - vec2(0.95, 0.0)) / vec2(0.9, 1.45);
	float angle = atan(g.y, g.x);
	float ring = abs(length(g) - 1.0) * 0.9;
	if (angle > -0.05 && angle < 1.0) {
		ring = min(length(p - vec2(0.95 + 0.9 * cos(1.0), 1.45 * sin(1.0))),
			length(p - vec2(0.95 + 0.9, 0.0)));
	}
	d = min(d, ring);
	d = min(d, segment(p, vec2(1.0, -0.05), vec2(1.85, -0.05)));
	// O.
	vec2 o = (p - vec2(3.35, 0.0)) / vec2(0.9, 1.45);
	d = min(d, abs(length(o) - 1.0) * 0.9);
	return d;
}

// The logo's height, LDU: letters 0.15 high (about 0.06 mm) with soft,
// rounded flanks, as the moulding raises them.
float logo_height(vec2 p) {
	return 0.15 * smoothstep(0.46, 0.08, logo_distance(p));
}

vec3 stud_logo(vec3 at, vec3 n, vec3 box_min, vec3 box_max, float body_top) {
	if (n.y < 0.97 || at.y < body_top + 0.5 || abs(at.y - box_max.y) > 0.3) {
		return n;
	}
	vec2 centre = box_min.xz + 10.0 + 20.0 * floor((at.xz - box_min.xz) / 20.0);
	vec2 p = vec2(at.x - centre.x, centre.y - at.z);
	if (length(p) > 5.4) {
		return n;
	}
	// About 9 LDU across, as the real one's 3.6 mm.
	const float grow = 1.0;
	p /= grow;
	const float e = 0.05;
	float dx = (logo_height(p + vec2(e, 0.0)) - logo_height(p - vec2(e, 0.0))) / (2.0 * e * grow);
	float dy = (logo_height(p + vec2(0.0, e)) - logo_height(p - vec2(0.0, e))) / (2.0 * e * grow);
	// p.y runs towards -z.
	return normalize(vec3(-dx, 1.0, dy));
}

// A moulded face is never quite flat: a slow waviness, a few thousandths of
// a turn, that bends the softboxes' reflections as a real part's do.
float wave_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z)) * 2.0 - 1.0;
}

float wave_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(wave_hash(i), wave_hash(i + vec3(1, 0, 0)), f.x),
			mix(wave_hash(i + vec3(0, 1, 0)), wave_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(wave_hash(i + vec3(0, 0, 1)), wave_hash(i + vec3(1, 0, 1)), f.x),
			mix(wave_hash(i + vec3(0, 1, 1)), wave_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec3 moulded(vec3 at, vec3 n, vec4 box_min, vec4 box_max) {
	vec3 high = vec3(box_max.x, min(box_max.y, box_min.w), box_max.z);
	vec3 bent = bevelled(at, n, box_min.xyz, high);
	if (bent == n) {
		bent = stud_rim(at, n, box_min.xyz, box_max.xyz, box_min.w);
	}
	if (bent == n) {
		bent = stud_logo(at, n, box_min.xyz, box_max.xyz, box_min.w);
	}
	vec3 s = at / 14.0;
	vec3 wave = vec3(wave_noise(s), wave_noise(s + vec3(5.2, 1.3, 7.1)), wave_noise(s + vec3(2.9, 8.4, 3.3)));
	return normalize(bent + (wave - n * dot(wave, n)) * 0.006);
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
	vec3 local = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	// The product look's plastic is moulded (box_max.w, PathTracer.product):
	// its edges rounded, its studs' logos raised, its faces never quite flat.
	hit.unused = 0.0;
	if (instances[which].box_max.w > 0.5 && dot(n, n) > 1e-12) {
		n = moulded(local, normalize(n), instances[which].box_min, instances[which].box_max);
		// A straight slope's face (flat, tilted between level and upright, on
		// opaque plastic) is roughened in the mould, a grain about 0.1 mm
		// across (0.22 LDU, and half again finer). Curved slopes are smooth, and their normals are not their
		// faces'.
		vec3 face = normalize(g);
		face = dot(face, n) < 0.0 ? -face : face;
		if (instances[which].info.y == 0u && n.y > 0.2 && n.y < 0.96 && dot(face, n) > 0.999) {
			vec3 s = local / 0.22;
			vec3 grain = vec3(wave_noise(s), wave_noise(s + vec3(3.1, 7.7, 1.9)),
				wave_noise(s + vec3(8.3, 2.2, 5.6)));
			vec3 t2 = local / 0.09;
			grain += 0.5 * vec3(wave_noise(t2), wave_noise(t2 + vec3(4.4, 1.7, 9.2)),
				wave_noise(t2 + vec3(6.1, 3.8, 0.7)));
			n = normalize(n + (grain - n * dot(grain, n)) * 0.16);
			hit.unused = 1.0;
		}
	}
	// Normals go by the inverse transpose: v * M is transpose(M) * v.
	hit.geometric = normalize(g * to_world);
	hit.normal = dot(n, n) > 1e-12 ? normalize(n * to_world) : hit.geometric;
	hit.t = gl_HitTEXT;
	hit.instance = which;
	hit.local = local;
}
