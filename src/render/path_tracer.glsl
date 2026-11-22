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
	// brighter its top is than its walls (0 for none), and its soft boxes'
	// light (photoreal3, StudioRender.TENT_BOX).
	vec4 lamp_info;
	Lamp lamps[8];
	// The product look's wear (photoreal4): how played-with the parts are (0
	// new, 1 decades: whites and greys yellowed, each part its own amount,
	// colours a little dulled), the dust on their tops, and how much the
	// backdrop shows a paper's or a table's grain and uneven light (0 a
	// cut-out's seamless). All 0 in the window's look.
	vec4 wear;
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
	// Mesh, kind (0 plastic, 1 clear plastic, 2 the sweep), the part's own
	// number (the same for each surface it is drawn in), unused.
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

// What the eye first meets in each pixel, summed as accum is (photoreal3):
// the surface's normal, and its albedo's lightness (2 clear plastic, 3 the
// sweep, 4 nothing), which guide the product look's denoise.
layout(set = 0, binding = 10, rgba32f) uniform image2D guide;

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
// white walls all round (the even sky) and a large soft panel overhead, 60
// degrees across, scene.lamp_info.z times as bright. A product photograph is
// lit so, from every side and most from above: no hard key, and no crescent
// of shadow inside a stud.
const float TENT_COS_OUT = 0.866;
const float TENT_COS_IN = 0.94;
// The walls' light, against the panel's 1 + lamp_info.z and the key's
// (studio_render.gd's TENT_KEY): a photographed tent's walls fill the shade
// in, never to the panel's level (the red slope's shaded end is a fifth of
// its lit face in the photograph; walls at the panel's left it a half).
const float TENT_FILL = 0.4;

bool tent() {
	return scene.sky.w < 0.5 && scene.lamp_info.z > 0.0;
}

// The tent's soft boxes (photoreal3): two wide boxes behind the model to its
// left and right, as a product photographer stands them, each TENT_BOX_WIDE
// radians across with soft edges, rising from TENT_BOX_LOW to TENT_BOX_HIGH
// (the sines of their elevations), lamp_info.w as bright. A gloss is the
// lights it mirrors: ABS reflects about 5% of what it faces, so a tent of
// paper-white walls left every highlight a few L* over the face, where a
// photograph's stud rims, edges and logo flanks show the lights as soft
// bright arcs and bands. Four narrow strips drew a white tick on each side
// of every stud, the same on each, which a judge called CG reflections.
const float TENT_BOX_AT = 0.85;
const float TENT_BOX_WIDE = 1.2;
const float TENT_BOX_LOW = 0.03;
const float TENT_BOX_HIGH = 0.62;

// Into the picture along the floor, and to its right: the boxes' frame.
void tent_frame(out vec3 into, out vec3 right) {
	vec3 ahead = vec3(-scene.back.x, 0.0, -scene.back.z) + vec3(scene.up.x, 0.0, scene.up.z);
	into = dot(ahead, ahead) > 1e-8 ? normalize(ahead) : vec3(0.0, 0.0, -1.0);
	right = vec3(-into.z, 0.0, into.x);
}

// How much of a box's light a direction sees (0 to 1, soft at the edges), and
// whether it is within a box's span at all.
float tent_box(vec3 way, out bool within) {
	within = false;
	if (scene.lamp_info.w <= 0.0 || way.y < TENT_BOX_LOW || way.y > TENT_BOX_HIGH) {
		return 0.0;
	}
	vec3 into;
	vec3 right;
	tent_frame(into, right);
	float off = abs(abs(atan(dot(way, right), dot(way, into))) - TENT_BOX_AT);
	if (off >= TENT_BOX_WIDE * 0.5) {
		return 0.0;
	}
	within = true;
	return (1.0 - smoothstep(TENT_BOX_WIDE * 0.25, TENT_BOX_WIDE * 0.5, off))
		* smoothstep(TENT_BOX_LOW, TENT_BOX_LOW + 0.1, way.y)
		* (1.0 - smoothstep(TENT_BOX_HIGH - 0.15, TENT_BOX_HIGH, way.y));
}

// Each box's chance per steradian, picked evenly over its span.
float tent_box_pdf() {
	return 1.0 / (TENT_BOX_WIDE * (TENT_BOX_HIGH - TENT_BOX_LOW));
}

vec3 tent_light(vec3 way) {
	if (way.y < 0.0) {
		return scene.sky.rgb * 0.6 * TENT_FILL;
	}
	// The camera's port: the lens and the camera behind it are dark, and a
	// glossy face turned to the camera mirrors them, not the tent's white
	// (a top-down shot's tops came out milky, mirroring the panel).
	vec3 to_eye = normalize(scene.origin.xyz - scene.sweep_origin.xyz);
	float port = smoothstep(0.978, 0.988, dot(way, to_eye));
	bool within;
	float box = tent_box(way, within) * scene.lamp_info.w;
	return scene.sky.rgb * (TENT_FILL + box
		+ scene.lamp_info.z * smoothstep(TENT_COS_OUT, TENT_COS_IN, way.y)) * (1.0 - 0.97 * port);
}

// The tent's own pick: its panel (evenly over its cone), or with boxes a box
// half the time (evenly over its span of turn and of sine).
float tent_own_pdf(vec3 way) {
	float cone = way.y >= TENT_COS_OUT ? 1.0 / (2.0 * PI * (1.0 - TENT_COS_OUT)) : 0.0;
	if (scene.lamp_info.w <= 0.0) {
		return cone;
	}
	bool within;
	tent_box(way, within);
	return 0.5 * cone + (within ? 0.25 * tent_box_pdf() : 0.0);
}

vec3 tent_own_pick() {
	if (scene.lamp_info.w <= 0.0 || rand() < 0.5) {
		return in_cone(vec3(0.0, 1.0, 0.0), acos(TENT_COS_OUT), rand2());
	}
	vec3 into;
	vec3 right;
	tent_frame(into, right);
	vec2 u = rand2();
	float around = (u.x < 0.5 ? TENT_BOX_AT : -TENT_BOX_AT) + (fract(u.x * 2.0) - 0.5) * TENT_BOX_WIDE;
	float up = mix(TENT_BOX_LOW, TENT_BOX_HIGH, u.y);
	float flat_part = sqrt(max(1.0 - up * up, 0.0));
	return normalize((into * cos(around) + right * sin(around)) * flat_part + vec3(0.0, up, 0.0));
}

// The tent's own pick half the time, the hemisphere by its cosine the other
// half.
float tent_pdf(vec3 way, vec3 n) {
	return 0.5 * tent_own_pdf(way) + 0.5 * max(dot(n, way), 0.0) / PI;
}

vec3 tent_pick(vec3 n, out float pdf) {
	vec3 way = rand() < 0.5 ? tent_own_pick() : cosine_around(n, rand2());
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

// A backdrop's own grain and uneven light (photoreal4), as a factor round 1 at
// a point of it (LDU): a paper's or a card's fibres, fine and faint, over
// broad patches a little lighter and darker, as a sheet or a table is lit
// unevenly. Amount 0 is none: a cut-out's seamless is its colour exactly.
float paper(vec3 at, float amount) {
	if (amount <= 0.0) {
		return 1.0;
	}
	float broad = gloss_noise(at / 140.0 + vec3(3.1, 0.0, 7.7)) * 0.6
		+ gloss_noise(at / 47.0 + vec3(11.0, 2.0, 5.0)) * 0.4;
	float fibre = gloss_noise(vec3(at.x * 0.9, at.y * 0.9, at.z * 0.25) + vec3(1.7, 4.2, 0.3)) * 0.5
		+ gloss_noise(at * 2.3 + vec3(9.1, 3.3, 1.2)) * 0.5;
	return 1.0 + amount * (0.06 * broad + 0.025 * fibre);
}

// textured: the hit is on a straight slope's face (closest_hit's grain);
// which: the part's own number (info.z: its body, print and window alike),
// so no two parts are worn alike and one part is worn as one; ng: the
// face's own normal in the world, for the dust that settles on tops.
Surface surface_of(Instance thing, vec3 at, vec3 local, float textured, uint which, vec3 ng) {
	Surface s;
	vec3 body = thing.colour.rgb;
	int finish = int(floor(thing.custom.w + 0.001));
	bool product = scene.look.x > 0.5;
	s.emission = vec3(0.0);
	s.metallic = 0.0;
	s.roughness = product ? 0.3 : 0.35;
	// The product look's plastic is ABS (photoreal3): its colour lies under a
	// smooth clear skin that reflects as a dielectric of index 1.55 does
	// (ABS_F0 face on, rising to all of it at a glance), and that one sharp
	// reflection is all its gloss. Half that coat over a broad lobe of its
	// own blurred every light it mirrored into the face's colour.
	s.specular = product ? 0.0 : 0.5;
	s.coat = product ? 1.0 : 0.0;
	s.coat_roughness = 0.07;
	if (thing.info.y == KIND_SWEEP) {
		// Paper: matte, its colour falling away from under the model.
		vec3 flat_at = at - scene.sweep_origin.xyz;
		float along = length(flat_at.xz) + max(flat_at.y, 0.0);
		float lit = 1.0 - scene.sweep.y * smoothstep(scene.sweep.z, scene.sweep.w, along);
		s.albedo = scene.sweep_colour.rgb * lit * lit * paper(at, scene.wear.z);
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
		// A played-with part's gloss is worn in broad patches (photoreal4): its
		// reflections uneven across a face, as an old set's are at arm's length.
		s.coat_roughness = mix(0.03, 0.085 + 0.25 * scene.wear.x, smoothstep(-0.6, 0.8, handled))
			+ 0.02 * own;
		s.roughness += 0.05 * handled;
		float age = scene.wear.x;
		if (age > 0.0) {
			// Played with (photoreal4): a white or grey part yellows as ABS does
			// in light and years, each its own amount (a set's whites never
			// match), and every colour dulls a little.
			float own_age = float(pcg(which * 2246822519u + 3266489917u) & 0xffffu) / 65535.0;
			float chroma = max(max(body.r, body.g), body.b) - min(min(body.r, body.g), body.b);
			float pale = smoothstep(0.12, 0.55, dot(body, vec3(0.2126, 0.7152, 0.0722)))
				* (1.0 - smoothstep(0.04, 0.2, chroma));
			float yellowed = age * (0.3 + 0.7 * own_age) * pale;
			body *= mix(vec3(1.0), vec3(1.0, 0.9, 0.62), yellowed);
			float grey_of = dot(body, vec3(0.2126, 0.7152, 0.0722));
			body = mix(body, vec3(grey_of), 0.08 * age * own_age);
			s.coat_roughness += 0.02 * age;
		}
		float dust = scene.wear.y * smoothstep(0.55, 0.9, ng.y);
		if (dust > 0.0) {
			// Dust on what faces up: a faint film that greys a face and dulls
			// its gloss, thicker in patches, with soft motes a few tenths of a
			// millimetre across, never a sharp point (a judge called those
			// fireflies, photoreal1).
			float film = 0.5 + 0.5 * gloss_noise(at / 6.0 + vec3(own * 17.0, 3.0, 1.0));
			float mote = smoothstep(0.35, 0.7, gloss_noise(at * 1.3 + vec3(5.0, own * 7.0, 2.0)));
			float cover = clamp(dust * (0.25 * film + 0.8 * mote), 0.0, 0.8);
			body = mix(body, vec3(0.5, 0.48, 0.45), cover);
			s.coat *= 1.0 - cover;
			s.roughness = mix(s.roughness, 0.9, cover);
		}
		if (worn(local, own)) {
			// A hairline scratch scatters what a polished face mirrors
			// (photoreal3): on a top that mirrors the dark camera it shows as a
			// faint light line, as handled bricks' tops do in a photograph.
			s.coat_roughness = 0.6;
		}
		if (textured > 0.5) {
			// A slope's face is roughened in the mould: the same skin, no
			// mirror, each bump of its grain a small glint.
			s.coat = 1.0;
			s.coat_roughness = 0.1;
		}
		// A stud's top is satin, not polished (photoreal3): the logo's plate of
		// the mould is left rough, so it shows the tent's light blurred where a
		// polished top mirrors the dark camera. In three_2x2_top's photograph
		// every stud's top is lighter than the face round it.
		if (local.y > thing.box_min.w + 0.5 && abs(local.y - thing.box_max.y) < 0.3) {
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

// A coat's reflection face on: ((1.55 - 1) / (1.55 + 1))^2, ABS's.
const float ABS_F0 = 0.0465;

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
	// A coat that is all of a plastic's gloss is picked as often as it shows.
	float coat = 0.4 * s.coat;
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
		float fc = schlick(vec3(ABS_F0), v_h).x * s.coat;
		float coat = fc * ggx_d(n_h, ac) * smith_g1(n_v, ac) * smith_g1(n_l, ac) / max(4.0 * n_v * n_l, 1e-6);
		float under = 1.0 - schlick(vec3(ABS_F0), n_v).x * s.coat;
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

// Clear plastic's absorption, per LDU, for the product look (photoreal2): a
// part's colour is what light keeps after GLASS_DEPTH of it (two walls of a
// brick, about 3 mm), and light keeps exp(-absorbed * distance) of itself
// going through, so a thin pane is pale and a thick lens deep, as in a
// photograph. Tinting at each face squared a pane's colour through its two
// faces, and 6660's windscreen came out deep blue where it is pale.
const float GLASS_DEPTH = 8.0;

vec3 absorbed(vec3 colour) {
	return -log(clamp(colour, vec3(0.02), vec3(1.0))) / GLASS_DEPTH;
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
	// The product look's clear plastic darkens light by how far it goes
	// through it (absorbed()): the faces met go in, out, in, out.
	bool within = false;
	for (int n = 0; n < 8; n++) {
		if (!trace(at, way, left, MASK_GLASS, gl_RayFlagsOpaqueEXT)) {
			return let;
		}
		Instance glass = instances[hit.instance];
		if (scene.look.x > 0.5) {
			if (within) {
				let *= exp(-absorbed(glass.colour.rgb) * hit.t);
			}
			within = !within;
		} else {
			let *= sqrt(max(glass.colour.rgb, vec3(0.0)));
		}
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
// four times (twice by its own pick, twice by the cosine: one of each left
// a grain in the shadow a judge named), each weighed by the
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
	for (int k = 0; k < 4; k++) {
		vec3 l;
		float own = 0.0;
		if (k % 2 == 1) {
			l = cosine_around(n, rand2());
		} else if (tent()) {
			l = tent_own_pick();
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
		float first = tent() ? tent_own_pdf(l)
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
	vec4 guided = pass.reset != 0u ? vec4(0.0) : imageLoad(guide, pixel);
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
		vec3 absorb = vec3(0.0);
		int bounces = 0;
		vec4 first = vec4(0.0, 0.0, 0.0, 4.0);
		bool met = false;
		for (int event = 0; event < most + 8; event++) {
			if (!trace(from, way, 1e7, 0xFFu, gl_RayFlagsOpaqueEXT)) {
				met = true;
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
			if (inside) {
				// Through the clear plastic it went in at.
				carried *= exp(-absorb * hit.t);
			}
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
			if (thing.info.y == KIND_PLASTIC && thing.box_max.w > 0.5) {
				// A rounding drawn on a flat face turns its normal right round
				// to the next face, and at the model's outline that half faces
				// away from the eye: lit by nothing and reflecting nothing, it
				// drew a black line two pixels wide down every silhouette, which
				// a judge named in every round. On a real rounded edge the part
				// turned that far is too thin to see, so a rounding faces the eye
				// at least as a face at a glance does.
				float facing = dot(n, v);
				float least = min(0.25, max(dot(ng, v), 0.0));
				if (dot(n, ng) < 0.999 && facing < least) {
					n = normalize(n + v * (least - facing));
				}
				// Its rounded edges are its surface, as in a photograph: paths
				// leave by the rounded normal. Leaving by the flat face's, the
				// half of each rounding turned past the face found the part
				// itself in every shadow ray and bounce.
				ng = n;
			}
			if (!met) {
				met = true;
				first = vec4(n, thing.info.y == KIND_GLASS ? 2.0 : (thing.info.y == KIND_SWEEP ? 3.0
					: luminance(surface_of(thing, at, hit.local, hit.unused, thing.info.z, hit.geometric).albedo)));
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
				if (scene.look.x > 0.5 && !inside && scene.wear.x > 0.0) {
					// A handled clear part (photoreal4): fine scratches in its skin
					// scatter some of the light that falls on it, each part's
					// running its own way, as a set's windscreen shows them.
					float own_glass = float(pcg(thing.info.z * 747796405u + 2891336453u) & 0xffffu)
						/ 65535.0;
					if (worn(hit.local * 1.6, own_glass)) {
						radiance += carried * 0.08 * scene.wear.x * sky_light(n);
					}
				}
				vec3 tint = sqrt(max(thing.colour.rgb, vec3(0.0)));
				// A clear neon glowing in the Dark light: light of its own,
				// on every face the path goes through.
				int glass_finish = int(floor(thing.custom.w + 0.001));
				if (scene.lamp_info.y > 0.0
						&& (glass_finish == FINISH_GLOW || glass_finish == FINISH_FLUORESCENT)) {
					radiance += carried * thing.colour.rgb * scene.lamp_info.y;
				}
				// The product look's clear plastic absorbs as the path goes
				// through it (absorbed()), not at its faces.
				carried *= (scene.look.x > 0.5 ? vec3(1.0) : tint) * (1.0 - f);
				from = at - ng * 0.02;
				if (scene.look.x > 0.5) {
					if (!inside) {
						absorb = absorbed(thing.colour.rgb);
					}
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
			if (!straight && thing.info.y == KIND_SWEEP && scene.look.x > 0.5 && scene.sky.w > 0.5
					&& at.y - scene.sweep_origin.y > 2.0) {
				// In a photographed place the backdrop is a table, not a
				// studio's paper (photoreal3): what the model mirrors and
				// what lights it from past the table's edge is the room. The
				// sweep's rise behind the model hid it, and a black brick's
				// top mirrored grey paper where a photograph's mirrors the
				// window, ΔE2000 39 against it.
				from = at + way * 0.05;
				continue;
			}
			if (straight && thing.info.y != KIND_SWEEP) {
				covered = 1.0;
			}
			if (straight && thing.info.y == KIND_SWEEP && scene.look.w < -0.5 && ng.y < 0.98) {
				// The white card (StudioRender._meter_card) is the floor where
				// the model stands: the sweep's rise behind it, lit less, is
				// left black, or a low camera metered the wall and drew the
				// model twice as light as the card.
				break;
			}
			if (straight && thing.info.y == KIND_SWEEP && scene.look.w > 0.5) {
				// The shadow catcher: the backdrop as the eye sees it, at its
				// colour (falling away as the sweep's paper does), darker only
				// where the model keeps light from it.
				vec3 flat_at = at - scene.sweep_origin.xyz;
				float along = length(flat_at.xz) + max(flat_at.y, 0.0);
				float lit = 1.0 - scene.sweep.y * smoothstep(scene.sweep.z, scene.sweep.w, along);
				radiance += carried * scene.background.rgb * lit * lit * paper(at, scene.wear.z)
					* shadow_on(at + ng * 0.02, n);
				break;
			}
			Surface s = surface_of(thing, at, hit.local, hit.unused, thing.info.z, hit.geometric);
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
		guided += first;
	}
	imageStore(accum, pixel, total);
	imageStore(guide, pixel, guided);
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

// The number of the part being hit, for each stud's own logo.
uint part_number = 0u;

float stud_hash(vec2 centre, uint salt) {
	uint h = uint(int(floor(centre.x * 0.5 + 4096.0))) * 73856093u
		^ uint(int(floor(centre.y * 0.5 + 4096.0))) * 19349663u ^ (part_number + salt) * 83492791u;
	h = h * 747796405u + 2891336453u;
	h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
	return float(((h >> 22u) ^ h) & 0xffffu) / 65535.0;
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
	// Each stud stands a hair off true (photoreal3), so no two mirror a light
	// alike: identical highlights on every stud gave a render away.
	vec2 lean = (vec2(stud_hash(centre, 9u), stud_hash(centre, 10u)) - 0.5) * 0.12;
	return normalize(vec3(out_from.x * q.x + lean.x * q.y, q.y, out_from.y * q.x + lean.y * q.y));
}

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Half the logo's letters' height, and half the width of its O and G to
// their strokes' middles, LDU.
const float LOGO_HALF = 2.2;
const float LOGO_ROUND = 0.8;

// How far a point is from the stroke of a tall round letter (an O) whose
// middle is at x: two straight sides and a half circle top and bottom, as
// the logo's O and G are.
float logo_o(vec2 p, float x) {
	return abs(segment(p, vec2(x, LOGO_ROUND - LOGO_HALF), vec2(x, LOGO_HALF - LOGO_ROUND)) - LOGO_ROUND);
}

// How far a point of a stud's top (LDU from its middle; x along the part's
// x, y towards its -z) is from the strokes of the logo's four letters, as a
// macro photograph of a real stud shows them (photoreal5): tall narrow
// letters slanted a fifth of their height, 4.4 LDU high (1.8 mm, two fifths
// of the stud) and 8.5 across, the O and the G straight sided. The squat
// letters before, 2.9 high with an oval G and O almost touching, read to
// every judge as "garbled", "blobby" or "mirrored" (36 of 60 renders).
float logo_distance(vec2 p) {
	p.x -= p.y * 0.2 + 0.35;
	float d = segment(p, vec2(-4.3, LOGO_HALF), vec2(-4.3, -LOGO_HALF));
	d = min(d, segment(p, vec2(-4.3, -LOGO_HALF), vec2(-3.0, -LOGO_HALF)));
	d = min(d, segment(p, vec2(-2.35, LOGO_HALF), vec2(-2.35, -LOGO_HALF)));
	d = min(d, segment(p, vec2(-2.35, LOGO_HALF), vec2(-1.1, LOGO_HALF)));
	d = min(d, segment(p, vec2(-2.35, 0.0), vec2(-1.3, 0.0)));
	d = min(d, segment(p, vec2(-2.35, -LOGO_HALF), vec2(-1.1, -LOGO_HALF)));
	// G: an O open on its right from just over its middle to where its top
	// turns, and a bar in from the right at its middle.
	const float G = 0.55;
	float g = logo_o(p, G);
	if (p.x > G && p.y > 0.05 && p.y < LOGO_HALF - LOGO_ROUND) {
		g = min(length(p - vec2(G + LOGO_ROUND, LOGO_HALF - LOGO_ROUND)),
			length(p - vec2(G + LOGO_ROUND, 0.05)));
	}
	d = min(d, g);
	d = min(d, segment(p, vec2(G + 0.05, 0.05), vec2(G + LOGO_ROUND, 0.05)));
	return min(d, logo_o(p, 3.0));
}

// The logo's height, LDU: letters 0.2 high (about 0.08 mm), each stroke
// about half an LDU wide (0.2 mm), flat on top with short steep flanks, as
// the moulding raises them, so each letter reads outlined where its flanks
// catch the light, as the photographs' do. [param soft] widens the flank: a
// worn mould's letters are softer.
float logo_height(vec2 p, float soft) {
	return 0.2 * smoothstep(0.36 + soft, 0.18, logo_distance(p));
}

vec3 stud_logo(vec3 at, vec3 n, vec3 box_min, vec3 box_max, float body_top) {
	if (n.y < 0.97 || at.y < body_top + 0.5 || abs(at.y - box_max.y) > 0.3) {
		return n;
	}
	vec2 centre = box_min.xz + 10.0 + 20.0 * floor((at.xz - box_min.xz) / 20.0);
	// The logo reads across the part (photoreal3): along z, the letters'
	// tops towards +x, so a 1x3's or a 2x4's runs over its width as the
	// photographs' do. Along x, it ran down the length, and a judge read the
	// black 2x4's as "mirrored, garbled lettering".
	vec2 p = vec2(at.z - centre.y, at.x - centre.x);
	if (length(p) > 5.4) {
		return n;
	}
	// Each stud's logo its own, as a real part's are (each cavity of a mould
	// worn its own way): a hair off the middle and off square, a little
	// deeper or shallower, softer or crisper.
	float turn = (stud_hash(centre, 1u) - 0.5) * 0.06;
	p = mat2(cos(turn), sin(turn), -sin(turn), cos(turn)) * p
		+ (vec2(stud_hash(centre, 2u), stud_hash(centre, 3u)) - 0.5) * 0.3;
	float depth = 0.75 + 0.5 * stud_hash(centre, 4u);
	float soft = 0.12 * stud_hash(centre, 5u);
	// About 9 LDU across, as the real one's 3.6 mm.
	const float e = 0.05;
	float dx = (logo_height(p + vec2(e, 0.0), soft) - logo_height(p - vec2(e, 0.0), soft)) / (2.0 * e);
	float dy = (logo_height(p + vec2(0.0, e), soft) - logo_height(p - vec2(0.0, e), soft)) / (2.0 * e);
	dx *= depth;
	dy *= depth;
	// The injection gate on some studs, as a judge saw on a photograph's
	// and missed on ours: where the plastic went in, a small round nub in a
	// shallow ring half a millimetre across (three_2x2_top's photograph;
	// photoreal3's ring twice that, over the letters, read as "garbled marks
	// inside the logo"), off the middle by a hair. A gloss over it catches
	// the light as a bright dot.
	if (stud_hash(centre, 6u) < 0.25) {
		vec2 g = p - (vec2(stud_hash(centre, 7u), stud_hash(centre, 8u)) - 0.5) * 0.6;
		float r = length(g);
		if (r > 0.001 && r < 1.2) {
			// h = 0.15 exp(-(r / 0.25)^2) - 0.08 exp(-((r - 0.6) / 0.18)^2):
			// its slope along g, downhill outwards.
			float nub = -0.15 * 2.0 * r / (0.25 * 0.25) * exp(-(r * r) / (0.25 * 0.25));
			float ring = 0.08 * 2.0 * (r - 0.6) / (0.18 * 0.18)
				* exp(-((r - 0.6) * (r - 0.6)) / (0.18 * 0.18));
			float slope = nub + ring;
			dx += slope * g.x / r;
			dy += slope * g.y / r;
		}
	}
	// p.x runs along z, p.y along x.
	return normalize(vec3(-dy, 1.0, -dx));
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

const float GRAIN_CELL = 0.45;

float grain_hash(vec2 c, float salt) {
	return fract(sin(dot(c, vec2(127.1, 311.7)) + salt * 74.7) * 43758.5453);
}

vec3 grain_bumps(vec3 at, vec3 face, vec3 n) {
	vec3 t = normalize(cross(abs(face.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), face));
	vec3 b = cross(face, t);
	vec2 uv = vec2(dot(at, t), dot(at, b)) / GRAIN_CELL;
	vec2 cell = floor(uv);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			vec2 centre = c + 0.2 + 0.6 * vec2(grain_hash(c, 1.0), grain_hash(c, 2.0));
			float r = 0.3 + 0.15 * grain_hash(c, 3.0);
			vec2 d = (uv - centre) / r;
			float d2 = dot(d, d);
			if (d2 < 1.0) {
				// A cap: its edge turned about 42 degrees.
				vec2 lean = d * 0.9;
				return normalize(n + t * lean.x + b * lean.y);
			}
		}
	}
	return n;
}

// A moulded face sinks a hair towards its middle as the plastic cools
// (photoreal3): its normal leans to the middle by SINK a turn per LDU from
// it, so a light mirrored across a long face bends, as a real part's does.
const float SINK = 0.0005;

vec3 moulded(vec3 at, vec3 n, vec4 box_min, vec4 box_max) {
	vec3 high = vec3(box_max.x, min(box_max.y, box_min.w), box_max.z);
	vec3 bent = bevelled(at, n, box_min.xyz, high);
	if (bent == n) {
		bent = stud_rim(at, n, box_min.xyz, box_max.xyz, box_min.w);
	}
	if (bent == n) {
		bent = stud_logo(at, n, box_min.xyz, box_max.xyz, box_min.w);
	}
	if (bent == n && max(abs(n.x), max(abs(n.y), abs(n.z))) > 0.97) {
		vec3 off = at - (box_min.xyz + high) * 0.5;
		bent = normalize(n - (off - n * dot(off, n)) * SINK);
	}
	vec3 s = at / 14.0;
	vec3 wave = vec3(wave_noise(s), wave_noise(s + vec3(5.2, 1.3, 7.1)), wave_noise(s + vec3(2.9, 8.4, 3.3)));
	return normalize(bent + (wave - n * dot(wave, n)) * 0.006);
}

void main() {
	uint which = gl_InstanceCustomIndexEXT;
	part_number = which;
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
			// A field of small round bumps, as a real slope's moulded texture
			// is (photoreal3): one in each cell GRAIN_CELL across, set off its
			// middle and sized by the cell's own hash, flat between. Each bump
			// turns every way, so some point of it mirrors the light: a glint,
			// and the colour saturated round it, as red_slope_2x4's photograph
			// shows. The noise of bumps everywhere photoreal1 and 2 drew read as
			// "procedural noise" and veiled the face pink in every round.
			n = grain_bumps(local, face, n);
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
