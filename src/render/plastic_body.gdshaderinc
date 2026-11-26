// Shared body of the plastic shaders. Included by plastic.gdshader and
// its variants, which differ only in cull mode and whether they write
// ALPHA — a shader fixes both at compile time, which is the only reason
// there is more than one file.
//
// ABS plastic, as bricks are actually moulded. Three things separate
// plastic that reads as plastic from plastic that reads as painted
// cardboard, and all three are cheap:
//
//   Sheen at grazing angles. ABS is a dielectric, so its reflectance
//   climbs sharply towards the silhouette. Without it a brick looks flat
//   however the roughness is tuned.
//
//   Roughness that varies. A moulded surface is not uniformly glossy:
//   the top of a stud is polished by the tool, the walls carry faint
//   draw marks. A touch of variation stops the highlight reading as a
//   sticker.
//
//   Colour in linear space. LDConfig values are sRGB; feeding them
//   straight to a physically based renderer washes every part out.
//
// The angles all come from the fragment stage. An earlier version took
// NORMAL in vertex() and compared it against a fixed axis, which is a
// model-space vector measured against a view-space direction: the
// shading then turned with the brick instead of with the camera, and
// every part came out flat and muddy with its studs barely readable.
//
// Not every brick is ABS. Chrome, metallic, pearl, glitter, speckle,
// opal, glow-in-the-dark, fluorescent, milky, rubber and fabric are each
// their own plastic, and each is drawn as itself: see FINISHES below.
// The finish rides in per brick, beside the colour, so a chrome brick
// and a red one of the same part share one batch and one draw.

// Not mirror-smooth: at 0.22 a flat face at the mirror angle to the sun
// went white from edge to edge, and a dark grey rock read as banded in
// white (src/dev/highlight_probe.gd).
uniform float base_roughness : hint_range(0.0, 1.0) = 0.28;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.10;
uniform float specular_level : hint_range(0.0, 1.0) = 0.5;

// Light colours scatter a little under the surface, which is why a white
// brick never reads as pure white in shadow.
uniform float subsurface : hint_range(0.0, 1.0) = 0.10;

// A render's own copy of the model in its Dark light (StudioRender, lights):
// how much of the window's studio the mirror-like finishes show (their
// reflection is drawn as light given off, studio()), 1 everywhere else; and
// how much light the plastics that glow give off, glow-in-the-dark and the
// neons, as Studio's Eyesight draws them, 0 everywhere else. The window's own
// plastic never sets either.
uniform float room : hint_range(0.0, 1.0) = 1.0;
uniform float glow : hint_range(0.0, 16.0) = 0.0;

// Whether the instance colour needs converting from sRGB to linear here.
// The two renderers disagree about what they are handed: under Forward+
// the conversion belongs in the shader, and doing it again under
// Compatibility darkens every part.
uniform bool linearise = true;

// A colour supplied directly, for when a part is drawn as a single
// MeshInstance rather than through a MultiMesh — the parts bin previews.
// There is no instance colour on that path and COLOR would fall back to
// the vertex colour attribute, which these meshes do not carry, so the
// part would render black. A negative red means "not set, use COLOR".
uniform vec4 tint_override = vec4(-1.0, 0.0, 0.0, 1.0);
// The finish to go with it, packed as BrickColor.instance_custom is.
// Zero is plain plastic.
uniform vec4 finish_override = vec4(0.0);

varying vec3 instance_color;
// The fleck colour (linear) and, in w, the finish number plus the fleck
// fraction. Per brick, from MultiMesh custom data.
varying flat vec4 instance_finish;
// Where the brick is, so two bricks of one part in one glitter colour
// do not carry the same glitter.
varying flat vec3 instance_seed;

// The part's own box, in its own coordinates (LDU), set per batch by
// BrickWorld. A real brick is 0.2 mm short of its pitch, so where two
// meet there is a seam, and a wall of them reads as courses of bricks.
// Drawn without it, a wall of forty bricks and a wall of four looked the
// same: one grey slab, and the texture a real set is made of was there in
// the model and invisible in every picture of it. A fragment near two of
// the box's faces at once is on an edge of the part, and is darkened.
// A zero box, the default, draws no seam — a parts-bin preview has none.
uniform vec3 part_box_min = vec3(0.0);
uniform vec3 part_box_max = vec3(0.0);
// How far in from an edge the seam reaches, in LDU, and at least this
// many pixels so it survives a model drawn small.
uniform float seam_ldu : hint_range(0.0, 4.0) = 0.5;
uniform float seam_pixels : hint_range(0.0, 3.0) = 1.0;
uniform float seam_depth : hint_range(0.0, 1.0) = 0.45;
// Whether the seam is drawn at all: View › Edges and studs › Edges, in the
// window (BrickWorld.edges_shown). Off, not a pixel of it: a model read by
// its colours alone, a mosaic or a sculpture, has no lines across it.
uniform bool seam_shown = true;
varying vec3 local_position;

#ifdef PLASTIC_PRINT
// A print drawn here (PartPrints): its picture, laid on by the mesh's own
// texture coordinates. Clear pixels, and anywhere off the picture, show the
// plastic, as LDView draws a TEXMAP with a clear border. The picture is
// sampled as it is stored, sRGB, and turned linear here exactly as the
// plastic's own colour is, so the two match on both renderers.
uniform sampler2D print_texture : filter_linear_mipmap, repeat_disable;
#endif

#ifdef PLASTIC_CUT
// The cut-away (SeeInside), in the world: a plane, or a box, a sphere or a
// cylinder (cut_shape.gdshaderinc). What it takes off is not drawn, so the
// inside of a model can be seen and worked in. Set per batch by
// BrickWorld.set_cut and set_cut_shape; only the _cut variants of these
// shaders read it, so a model with no cut draws with no discard and keeps
// its early depth test.
#include "res://src/render/cut_shape.gdshaderinc"
#endif

#ifdef PLASTIC_PRODUCT
// The product look (StudioRender, RenderSettings.look "product"): the
// _product variants of these shaders, used only on the copy of the model
// a render draws, never in the window. Three things a product shot has
// that the window's plastic does not:
//
//   Edges that catch the light. A moulded brick's edges are rounded a
//   little, and that round is where every highlight runs along a wall of
//   bricks. Drawn here by bending the normal near the part's box edges as
//   a rounded box's would bend: a face lying on the box, within a bevel's
//   width of another of its faces, turns towards it. No geometry: only
//   edges on the part's box are rounded, which is the outline of most
//   bricks, plates and tiles, and never wrongly (a slope's own edge is
//   left sharp, not given a round it does not have).
//
//   A clear coat of gloss over the plastic: a broad soft highlight under a
//   sharp one, which is how polished ABS reads in a photograph, and
//   chrome, metal and pearl as metals reflecting the studio itself (its
//   sky), not the window's drawn one.
//
//   Clear parts that tint what is behind them, rather than veiling it,
//   through every wall and tube of them (plastic_product_glass).
//
// The body's top, in the part's own coordinates: a brick's studs stand
// above its box's body, so the box's top is the studs' and the brick's own
// top edge is lower. BrickWorld sets it from the part's studs.
uniform float part_body_top = 1.0e9;
uniform float bevel_ldu : hint_range(0.0, 4.0) = 0.6;
// At least this many pixels across, or the round's highlight, a line a
// pixel wide, came out as dashes along every edge at Good's six frames.
uniform float bevel_pixels : hint_range(0.0, 4.0) = 2.2;
#ifdef PLASTIC_TRANSPARENT
// A picture with no backdrop (StudioRender): with nothing behind clear
// plastic to tint, it is blended as the window's is, its colour carried in
// the picture's alpha, and plastic_product_glass lets everything through.
uniform bool over_nothing = false;
#endif
varying vec3 local_normal;
// The part's own axes in view space, for the bent normal.
varying flat vec3 axis_x;
varying flat vec3 axis_y;
varying flat vec3 axis_z;
// Played with (photoreal27, RenderSettings.plastic "played") where nothing
// path traces: the path tracer's wear (path_tracer.glsl's surface_of) on this
// plastic, set by StudioRender at Best in the Product look. How old the set
// is (its whites and greys yellowed, each part its own amount, every colour a
// little dulled, its gloss worn in broad patches and scratched), the dust on
// its tops, and how much more than that each part has been handled (its
// polish its own, its edges scuffed, a fingertip's print on the most
// handled). 0, as everywhere but Played with, draws none of it. The parts'
// seating is the stage's own (StudioRender._stage_model).
uniform float wear_age : hint_range(0.0, 2.0) = 0.0;
uniform float wear_dust : hint_range(0.0, 1.0) = 0.0;
uniform float wear_handling : hint_range(0.0, 2.0) = 0.0;
// From the window to the stage's own space: each part's own numbers are
// keyed to where it stands on the stage, so they are the same in every frame
// of a turntable, and a printed part's print and body (two batches, one
// place) are worn as one part.
uniform mat4 wear_stage = mat4(1.0);
varying flat vec4 part_own;

// Three numbers from 0 to 1 for a point (hash3's, which comes after vertex()).
vec3 wear_hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Smooth noise from -1 to 1, as path_tracer.glsl's gloss_noise.
float wear_corner(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z)) * 2.0 - 1.0;
}

float wear_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(wear_corner(i), wear_corner(i + vec3(1, 0, 0)), f.x),
			mix(wear_corner(i + vec3(0, 1, 0)), wear_corner(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(wear_corner(i + vec3(0, 0, 1)), wear_corner(i + vec3(1, 0, 1)), f.x),
			mix(wear_corner(i + vec3(0, 1, 1)), wear_corner(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Whether a point of the part is on a hairline scratch across its gloss, the
// part's own [param own] from 0 to 1: path_tracer.glsl's worn(), fine straight
// scratches a few LDU long, each part's its own way, in patches, more and
// over more of it the older ([param age]) it is.
bool wear_scratched(vec3 q, float own, float age) {
	float angle = own * 6.2832;
	vec3 along = normalize(vec3(cos(angle), 0.4 * sin(angle * 1.7), sin(angle)));
	vec3 across = normalize(cross(along, vec3(0.3, 1.0, 0.2)));
	vec3 third = cross(along, across);
	float fine = mix(2.2, 1.3, age);
	float lines = wear_noise(vec3(dot(q, along) * 0.15, dot(q, across) * fine,
		dot(q, third) * fine) + vec3(own * 13.0));
	float patches = wear_noise(q / 9.0 + vec3(own * 29.0, 5.0, 2.0));
	return lines > 0.72 - 0.08 * age && patches > 0.1 - 0.45 * age;
}

// A fingertip's print where a hand pressed the part on, 0 to 1: a patch
// about 12 by 15 mm on one of its sides, its oil in ridges half a millimetre
// apart (path_tracer.glsl's print_of), placed by the part's own [param at]
// and [param side].
float wear_print(vec3 local, vec3 lo, vec3 hi, vec3 at_own, float side, float own) {
	vec3 at = mix(lo, hi, at_own);
	if (side < 0.5) {
		at.z = side < 0.25 ? lo.z : hi.z;
	} else {
		at.x = side < 0.75 ? lo.x : hi.x;
	}
	vec3 d = local - at;
	float r = length(d / vec3(15.0, 18.0, 15.0));
	float pressed = 1.0 - smoothstep(0.45, 1.0, r + 0.25 * wear_noise(local * 0.15 + vec3(own * 255.0)));
	float ridge = 0.5 + 0.5 * sin(length(d * vec3(1.0, 0.8, 1.0)) * 5.0 + 2.5 * wear_noise(local * 0.25));
	return pressed * (0.35 + 0.65 * ridge);
}
#endif

// FINISHES. Numbered as PartLibrary.BrickColor.Finish numbers them.
const int FINISH_PLASTIC = 0;
const int FINISH_CHROME = 1;
const int FINISH_METAL = 2;
const int FINISH_PEARL = 3;
const int FINISH_SPECKLE = 4;
const int FINISH_GLITTER = 5;
const int FINISH_OPAL = 6;
const int FINISH_GLOW = 7;
const int FINISH_FLUORESCENT = 8;
const int FINISH_RUBBER = 9;
const int FINISH_FABRIC = 10;
const int FINISH_MILKY = 11;

vec3 srgb_to_linear(vec3 c) {
	// The exact piecewise transfer function, not a 2.2 power: the
	// approximation visibly lifts dark greys, and bricks use a lot of
	// dark grey.
	bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
	vec3 low = c / 12.92;
	vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, vec3(cutoff));
}

vec3 linear_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	bvec3 cutoff = lessThanEqual(c, vec3(0.0031308));
	vec3 low = c * 12.92;
	vec3 high = 1.055 * pow(c, vec3(1.0 / 2.4)) - vec3(0.055);
	return mix(high, low, vec3(cutoff));
}

void vertex() {
	bool single = tint_override.r >= 0.0;
	vec3 source = single ? tint_override.rgb : COLOR.rgb;
	instance_color = linearise ? srgb_to_linear(source) : source;
	vec4 custom = single ? finish_override : INSTANCE_CUSTOM;
	instance_finish = vec4(linearise ? srgb_to_linear(custom.rgb) : custom.rgb, custom.a);
	// MODEL_MATRIX carries the instance's own transform here, on both
	// renderers, so its origin is where this brick stands.
	instance_seed = MODEL_MATRIX[3].xyz;
	local_position = VERTEX;
#ifdef PLASTIC_PRODUCT
	local_normal = NORMAL;
	axis_x = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	axis_y = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	axis_z = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 placed = (wear_stage * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	part_own = vec4(wear_hash3(placed * 0.731 + wear_hash3(placed.zxy * 0.173) * 37.0),
		wear_hash3(placed.yzx * 0.419 + 11.3).x);
#endif
}

// How much of a seam this fragment is in, from 0 to 1. `per_pixel` is
// fwidth(at), taken by the caller outside any branch.
float seam_at(vec3 at, vec3 per_pixel) {
	vec3 size = part_box_max - part_box_min;
	if (!seam_shown || size.x <= 0.0 || size.y <= 0.0 || size.z <= 0.0) {
		return 0.0;
	}
	vec3 d = min(at - part_box_min, part_box_max - at);
	// Near one face is anywhere on that face; near two is an edge. So it
	// is the second nearest that decides.
	float nearest = min(d.x, min(d.y, d.z));
	float furthest = max(d.x, max(d.y, d.z));
	float second = d.x + d.y + d.z - nearest - furthest;
	float width = max(seam_ldu, seam_pixels * max(per_pixel.x, max(per_pixel.y, per_pixel.z)));
	return 1.0 - smoothstep(width * 0.5, width, second);
}

// Three cheap random numbers from a point. Not a texture: the web build
// has no texture to spare for this, and a hash is the same on both
// renderers.
vec3 hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Flecks in the plastic, the way glitter and speckle are mixed into it:
// a few per cell of a lattice in the part's own space, so they stay put
// as the part moves. A surface cuts each fleck at some depth, which is
// what makes them come out in different sizes.
//
// x is how much this fragment is a fleck, 0 to 1, already faded to the
// average when a fleck is too small on screen to draw (or it would
// crawl as the model turns), and `small` says how far it was faded. yzw
// is a random direction, for the facet a glitter fleck catches light
// with. `pixel` is how many LDU one pixel spans, measured by the caller
// outside any branch: a derivative taken inside one is undefined.
vec4 flecks(vec3 at, float pixel, float cell, float chance, vec3 seed, out float small) {
	vec3 q = at / cell + hash3(seed) * 17.0;
	vec3 id = floor(q);
	vec3 within = fract(q) - 0.5;
	vec3 h = hash3(id);
	float radius = 0.24 + 0.2 * h.y;
	vec3 centre = (hash3(id + 7.31) - 0.5) * (1.0 - 2.0 * radius);
	float d = length(within - centre);
	// Past about half a cell to a pixel a fleck is a pixel or two, and
	// the honest picture is the mixture.
	float span = pixel / cell;
	float soft = max(span * 0.75, 0.02);
	float here = step(h.x, chance) * (1.0 - smoothstep(radius - soft, radius + soft, d));
	small = smoothstep(0.35, 0.9, span);
	float average = chance * 0.27;
	return vec4(mix(here, average, small), hash3(id + 3.7) - 0.5);
}

// What a polished surface would see: a bright soft box overhead, a
// near-black band just under the horizon fading to a dim floor, and a
// tall soft box either side of the eye.
//
// Drawn, not taken from the sky. The critique renders and the parts-bin
// previews have no sky at all, and the sky in the main view is a soft
// grey gradient, so chrome that reflected only what the renderer has
// came out as flat grey plastic — measured, on both renderers. And held
// still relative to the eye, the way a CAD viewer's studio is, rather
// than in the world: a flat face reflects one direction, and a studio
// fixed in the world puts the same grey in it from most angles. Here
// the tops of bricks are bright, the faces turned to you are dark, and
// every stud carries a highlight down each side, from wherever it is
// looked at. `r` is in view space; `blur` is how rough the surface is,
// widening every edge and pulling the studio towards its average.
vec3 studio(vec3 r, float blur) {
	float up = r.y;
	float edge = 0.02 + blur * 0.5;
	vec3 above = mix(vec3(0.7, 0.73, 0.78), vec3(1.1), smoothstep(0.0, 0.9, up));
	vec3 below = mix(vec3(0.02), vec3(0.09), smoothstep(0.1, 0.9 + blur, -up));
	vec3 env = mix(below, above, smoothstep(-0.15 - edge, -0.15 + edge, up));
	// Narrow in height: a stud's side sees them at about the height of
	// the eye, a flat face turned 35 degrees away (the default view) sees
	// the floor below them, and catching them washed whole chrome faces
	// white.
	float side = smoothstep(0.55 - blur * 0.5, 0.75, abs(r.x))
		* (1.0 - smoothstep(0.35, 0.7 + blur, abs(up - 0.1)));
	env += vec3(0.8) * side;
	return mix(env, vec3(0.45), blur * 0.6);
}

#ifdef PLASTIC_PRODUCT
// The normal of a box with rounded edges, [param width] in radius, at a
// point of a face of the part's body box ([param n] the surface's own
// normal, part space); [param n] itself anywhere else.
vec3 bevelled(vec3 at, vec3 n, float width, float pixel, float small) {
	vec3 low = part_box_min;
	vec3 high = vec3(part_box_max.x, min(part_box_max.y, part_body_top), part_box_max.z);
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
	// On the box's face, facing out of it, and inside the body the other
	// two ways (a stud's side, above the body, is not). Allowing a pixel
	// past the body: under multisampling a pixel at the edge of a face is
	// shaded at its centre, which can be off the face and off the box, and
	// a test that refused those drew every edge as dashes.
	float slack = max(width * 0.3, 0.06) + pixel;
	if (abs(dot(out_of, axis)) > slack || dot(sign(p) * sign(n), axis) < 0.5
			|| any(greaterThan(out_of, vec3(slack)))) {
		return n;
	}
	vec3 q = max(min(abs(p), half_size) - (half_size - vec3(width)), vec3(0.0));
	// A round a pixel or two across is seen whole by each pixel on it: its
	// average turn, the same across it, rather than the full quarter turn
	// within two pixels, whose highlight each pixel caught or missed by
	// where its centre fell (dashes along every edge at Good).
	q = mix(q, step(vec3(0.0001), q) * width * 0.6, small);
	q = mix(q, vec3(width), axis);
	return normalize(sign(p) * q);
}

// The normal at a stud's top edge, rounded as a moulded stud's is: on the
// top or the side of a stud on the body's top (6 LDU round, standing to the
// top of the part's box, on the 20 LDU grid from its corner), within
// [param width] of the rim; [param n] itself anywhere else. The box's
// round leaves every stud with a knife edge, which caught no light.
vec3 stud_rim(vec3 at, vec3 n, float width, float small) {
	float top = part_box_max.y;
	if (part_box_max.x <= part_box_min.x || at.y < part_body_top + 0.5 || at.y > top + 0.3) {
		return n;
	}
	vec2 centre = part_box_min.xz + 10.0 + 20.0 * floor((at.xz - part_box_min.xz) / 20.0);
	vec2 d = at.xz - centre;
	float r = length(d);
	width = min(width, 2.0);
	if (r > 6.3 || r < 0.001) {
		return n;
	}
	vec2 out_from = d / r;
	// Out from the stud's axis and up, as bevelled()'s q: how far into the
	// round each way, seen whole when it is a pixel or two across.
	vec2 q;
	if (n.y > 0.97) {
		float into = max(r - (6.0 - width), 0.0);
		q = vec2(mix(into, width * 0.6, small * step(0.0001, into)), width);
	} else if (abs(n.y) < 0.2 && dot(n.xz, out_from) > 0.9 && r > 5.7) {
		float into = max(at.y - (top - width), 0.0);
		q = vec2(width, mix(into, width * 0.6, small * step(0.0001, into)));
	} else {
		return n;
	}
	if (min(q.x, q.y) <= 0.0) {
		return n;
	}
	return normalize(vec3(out_from.x * q.x, q.y, out_from.y * q.x));
}
#endif

void fragment() {
#ifdef PLASTIC_CUT
	vec3 world_at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (cut_away_at(world_at)) {
		discard;
	}
#endif
	// Derivatives first, outside any branch, where they are defined: how
	// many LDU one pixel spans here (the seams, and the finishes with detail
	// finer than that, fade by it), and the print's own sample.
	vec3 local_width = fwidth(local_position);
#ifdef PLASTIC_PRINT
	vec4 ink = texture(print_texture, UV);
#endif
#ifdef PLASTIC_CAP
	// Where the cut goes through plastic. A part's surfaces are closed, so
	// an eye looking past the plane, or through the box, sphere or
	// cylinder, meets a back face exactly where the cut's surface is inside
	// the plastic, and a front face where it is in air: the back faces are
	// the cut. Drawn as a flat face on the cut's surface, in the part's own
	// colour, hatched the way a section is drawn
	// on paper, so a wall cut through reads as a wall and not as a hole
	// into the back of the brick. And drawn first and alone: with a discard
	// in the shader nothing is rejected before it runs, and about half of
	// what a cut part draws is back faces hidden behind its front ones.
	if (!FRONT_FACING) {
		vec3 cap_linear = linearise ? instance_color : srgb_to_linear(instance_color);
		float cap_dark = dot(cap_linear, vec3(0.2126, 0.7152, 0.0722));
		float band = step(0.55, fract((FRAGCOORD.x + FRAGCOORD.y) / 9.0));
		vec3 line = cap_dark < 0.04 ? mix(instance_color, vec3(1.0), 0.3) : instance_color * 0.5;
		ALBEDO = mix(instance_color * 0.9, line, band);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		BACKLIGHT = vec3(0.0);
		EMISSION = vec3(0.0);
		// Square to the plane, or to the box's, sphere's or cylinder's face
		// where the eye's line came out of it.
		vec3 toward_eye = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
		NORMAL = normalize((VIEW_MATRIX * vec4(cut_face_normal(world_at, toward_eye), 0.0)).xyz);
		if (cut_marks == 1) {
			ALBEDO = vec3(0.0);
			EMISSION = vec3(4.0, 0.0, 4.0);
		}
	} else {
#endif
	int finish = int(floor(instance_finish.w + 0.001));
	float fraction = clamp(instance_finish.w - float(finish), 0.0, 1.0);
	vec3 fleck_color = instance_finish.rgb;

	// Darker into a seam, except on plastic already too dark to darken,
	// where an edge reads as a faint highlight the way it does on a black
	// brick in the hand. Black itself is 0.0214 here, so the line was at
	// 0.02 for a long time and black — the one it was written for — got
	// a dark seam it could not show.
	// Judged in linear light on both renderers, so the same plastics count
	// as dark under Compatibility, which is handed sRGB.
	float seam = seam_at(local_position, local_width);
	vec3 linear_color = linearise ? instance_color : srgb_to_linear(instance_color);
	float luminance_in = dot(linear_color, vec3(0.2126, 0.7152, 0.0722));
	vec3 seam_color = luminance_in < 0.025 ? instance_color + vec3(0.03)
		: instance_color * (1.0 - seam_depth);
	vec3 body = mix(instance_color, seam_color, seam);
#ifdef PLASTIC_PRINT
	float on_picture = step(0.0, UV.x) * step(UV.x, 1.0) * step(0.0, UV.y) * step(UV.y, 1.0);
	vec3 ink_color = linearise ? srgb_to_linear(ink.rgb) : ink.rgb;
	body = mix(body, ink_color, ink.a * on_picture);
#endif
#ifdef PLASTIC_PRODUCT
	// Played with (photoreal27): the path tracer's wear, its numbers, in
	// linear light. How worn its gloss is here (0 as new, 1 matt) and how
	// much dust covers it, for the gloss below.
	float wear_dull = 0.0;
	float wear_cover = 0.0;
#ifndef PLASTIC_TRANSPARENT
	if (finish == FINISH_PLASTIC && wear_age + wear_dust + wear_handling > 0.0) {
		vec3 lin = linearise ? body : srgb_to_linear(body);
		float own = part_own.x;
		vec3 more = wear_hash3(part_own.xyz * 91.7 + vec3(3.3, 7.1, 1.9));
		// Which way the face looks, up in the world: the dust settles on what
		// faces up, and the hands touch the sides and the top, never under.
		vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		float up = dot(normalize(NORMAL), up_view);
		// What the tracer's clear coat's roughness would be: a part's gloss
		// worn in broad patches, the more the older it is.
		float handled = wear_noise(local_position / 16.0 + vec3(own * 97.0, own * 31.0, 0.0));
		float coat_rough = mix(0.03, 0.085 + 0.25 * wear_age, smoothstep(-0.6, 0.8, handled)) + 0.02 * own;
		// How much more this part has been handled than the set's age says:
		// most hardly at all, a few a lot; its polish its own, dulled the
		// more it is handled, and a fingertip's print on the most handled.
		float rubbed = wear_handling * part_own.y * part_own.y * (1.0 - smoothstep(0.2, 0.7, -up));
		if (wear_handling > 0.0) {
			float bell = (more.x + more.y + more.z - 1.5) * (2.0 / 3.0);
			coat_rough = max(0.015, coat_rough * (1.0 + 0.6 * bell * wear_handling)) + 0.12 * rubbed;
			float printed = smoothstep(0.4, 0.9, rubbed);
			if (printed > 0.0) {
				float oil = wear_print(local_position, part_box_min, part_box_max,
					wear_hash3(part_own.wzy * 53.1 + 0.7), part_own.w, own) * printed;
				coat_rough = mix(coat_rough, 0.24, 0.85 * oil);
			}
		}
		if (wear_age > 0.0) {
			// A white or grey part yellows as ABS does in light and years,
			// each its own amount (a set's whites never match), and every
			// colour dulls a little.
			float own_age = part_own.z;
			float chroma = max(max(lin.r, lin.g), lin.b) - min(min(lin.r, lin.g), lin.b);
			float pale = smoothstep(0.12, 0.55, dot(lin, vec3(0.2126, 0.7152, 0.0722)))
				* (1.0 - smoothstep(0.04, 0.2, chroma));
			float yellowed = wear_age * (0.3 + 0.7 * own_age) * pale;
			lin *= mix(vec3(1.0), vec3(1.0, 0.9, 0.62), yellowed);
			float grey_of = dot(lin, vec3(0.2126, 0.7152, 0.0722));
			lin = mix(lin, vec3(grey_of), 0.08 * wear_age * own_age);
			coat_rough += 0.02 * wear_age;
		}
		float dust = wear_dust * smoothstep(0.55, 0.9, up);
		if (dust > 0.0) {
			// A faint film that greys a face and dulls its gloss, thicker in
			// patches. The tracer's motes a few tenths of a millimetre across
			// come out of its denoise as part of that film; drawn sharp here
			// they read as grit sprinkled on every top (photoreal27's first
			// look), so the film takes their share evenly (0.8 times the 8%
			// of a face they cover).
			float film = 0.5 + 0.5 * wear_noise(local_position / 6.0 + vec3(own * 17.0, 3.0, 1.0));
			wear_cover = clamp(dust * (0.25 * film + 0.065), 0.0, 0.8);
			lin = mix(lin, vec3(0.5, 0.48, 0.45), wear_cover);
		}
		// Hairline scratches, and the edges and corners knocked against
		// others, rubbed matt in patches and a shade paler.
		float scuff_age = wear_age + rubbed;
		if (wear_scratched(local_position, own, scuff_age)) {
			coat_rough = 0.6;
		}
		if (scuff_age > 0.0) {
			vec3 d = min(local_position - part_box_min, part_box_max - local_position);
			float nearest = min(d.x, min(d.y, d.z));
			float furthest = max(d.x, max(d.y, d.z));
			float second = d.x + d.y + d.z - nearest - furthest;
			float scuffed = (1.0 - smoothstep(0.7, 1.4, second))
				* smoothstep(0.15, 0.55, wear_noise(local_position * 0.7 + vec3(own * 41.0, 2.0, 9.0)));
			coat_rough = mix(coat_rough, 0.4, scuffed * scuff_age);
			lin = mix(lin, lin * 1.08 + vec3(0.015), clamp(scuffed * scuff_age, 0.0, 1.0));
		}
		// The tracer's coat, from a new part's 0.03 to 0.09, here as how far
		// from new the gloss is.
		wear_dull = smoothstep(0.09, 0.5, coat_rough);
		body = linearise ? lin : linear_to_srgb(lin);
	}
#endif
#endif
	// The finishes' own light — the studio a mirror reflects, a glow, a
	// glint — is worked out in linear light on both renderers and handed
	// over in whichever space this renderer writes. Compatibility writes
	// sRGB as it is, so a mirror's dark floor of 0.09 came out black
	// there and its bright sky white, where Forward+ shows them as the
	// greys they are.
	vec3 body_linear = linearise ? body : srgb_to_linear(body);
	vec3 fleck_linear = linearise ? fleck_color : srgb_to_linear(fleck_color);

	// How square-on this surface is to the eye. Both vectors are in view
	// space here, which is what makes the result mean anything.
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float pixel_ldu = max(local_width.x, max(local_width.y, local_width.z));
#ifdef PLASTIC_PRODUCT
	// How much of this pixel is on a round small on screen: its gloss is
	// spread, as a pixel's worth of a curved edge reflects a spread of the
	// studio, not one point of it.
	float on_round = 0.0;
	// How far it is round an edge, 0 on the flat: a face's own normal is
	// not exactly the box's axis, so a test of bent against unbent alone
	// counted whole faces.
	float rounded = 0.0;
	{
		vec3 n_local = normalize(local_normal);
		float width = max(bevel_ldu, bevel_pixels * pixel_ldu);
		float small = smoothstep(bevel_ldu, bevel_ldu * 3.0, width);
		vec3 bent = bevelled(local_position, n_local, width, pixel_ldu, small);
		if (bent == n_local) {
			bent = stud_rim(local_position, n_local, width, small);
		}
		if (bent != n_local) {
			normal = normalize(axis_x * bent.x + axis_y * bent.y + axis_z * bent.z);
			NORMAL = normal;
			on_round = small;
			rounded = smoothstep(0.02, 0.3, length(bent - n_local));
		}
	}
#endif
	float faded = 0.0;
	float facing = clamp(dot(normal, view), 0.0, 1.0);
	float grazing = 1.0 - facing;

	// Plastic, which every finish starts from.
	vec3 albedo = body;
	float metallic = 0.0;
	// Grazing light picks up the fine tooling texture a head-on view does
	// not resolve.
	float roughness = base_roughness + roughness_variation * grazing;
	// Dielectric sheen towards the silhouette. This is the edge light
	// that makes a stud read as a cylinder rather than a smudge.
	float specular = specular_level + 0.35 * pow(grazing, 4.0);
	// Pale plastics scatter, dark ones absorb; keying the amount to
	// luminance gets that without a per-colour flag.
	vec3 backlight = vec3(subsurface * luminance_in);
	vec3 emission = vec3(0.0);
	// Transparent ABS is glassy, not frosted: moulded in the same tool as
	// opaque plastic and polished the same way, so it keeps the roughness
	// and gains transmission. Edge-on it transmits less, the way real
	// glazing does, so a windscreen's silhouette reads instead of
	// vanishing.
	float base_alpha = tint_override.r >= 0.0 ? tint_override.a : COLOR.a;
	float alpha = clamp(base_alpha + pow(grazing, 3.0) * (1.0 - base_alpha) * 0.85, 0.0, 1.0);
	// About 0.09, as it was when opaque plastic was 0.22: glazing stays
	// glassy, and its glint is what tells it from trans rubber.
	float glass_roughness = base_roughness * 0.31;
	vec3 glass_backlight = instance_color * 0.4;

	if (finish != FINISH_PLASTIC) {
		// What a mirror-like surface here would show, as seen from the
		// eye: see studio().
		vec3 seen = reflect(-view, normal);

		if (finish == FINISH_CHROME) {
			// A mirror. The reflection is drawn and the highlights are
			// lit, and the body colour tints both: chrome gold is a gold
			// mirror, chrome black a dark one.
			vec3 tint = max(body, vec3(0.18));
			albedo = tint * 0.15;
			metallic = 1.0;
			roughness = 0.08;
			emission = max(body_linear, vec3(0.08)) * studio(seen, 0.0) * 1.3;
			backlight = vec3(0.0);
		} else if (finish == FINISH_METAL) {
			// Metallic paint: metal under a satin coat, with fine flake in
			// it that a mirror does not have.
			vec4 flake = flecks(local_position, pixel_ldu, 0.9, 0.6, instance_seed, faded);
			vec3 tint = max(body, vec3(0.06));
			albedo = tint * (0.4 + 0.15 * flake.x);
			metallic = 0.8;
			roughness = 0.36 - 0.1 * flake.x;
			emission = max(body_linear, vec3(0.02)) * studio(seen, 0.3) * 2.0;
			backlight = vec3(0.0);
		} else if (finish == FINISH_PEARL) {
			// Pearl: plastic with a soft metallic sheen that brightens
			// towards the edges, the way pearl gold does in the hand.
			albedo = body * (1.0 + 0.3 * pow(grazing, 2.0));
			metallic = 0.35;
			roughness = 0.3;
			emission = body_linear * studio(seen, 0.5) * 0.4;
			backlight = vec3(0.0);
		} else if (finish == FINISH_SPECKLE) {
			// Plastic with metal flecks through it — black with silver,
			// with gold, with copper.
			vec4 fleck = flecks(local_position, pixel_ldu, 2.4, min(fraction * 2.0, 1.0), instance_seed, faded);
			albedo = mix(body, fleck_color, fleck.x);
			metallic = 0.85 * fleck.x;
			roughness = mix(roughness, 0.25, fleck.x);
			emission = fleck_linear * studio(seen, 0.3) * 0.5 * fleck.x;
		} else if (finish == FINISH_GLITTER) {
			// Clear plastic with glitter in it. Each fleck is a little
			// facet turned its own way, so a different few flash as the
			// view turns, which is what glitter is.
			vec4 fleck = flecks(local_position, pixel_ldu, 1.5, min(fraction * 2.5, 1.0), instance_seed, faded);
			vec3 facet = normalize(normal + fleck.yzw * 1.4);
			float flash = pow(clamp(dot(facet, view), 0.0, 1.0), 24.0) * (1.0 - faded);
			vec3 glint = mix(fleck_linear, vec3(1.0), 0.5);
			albedo = mix(body, fleck_color, fleck.x);
			emission = glint * fleck.x * (0.15 + 2.5 * flash);
			alpha = mix(alpha, 0.95, fleck.x);
			glass_roughness = mix(glass_roughness, 0.15, fleck.x);
		} else if (finish == FINISH_OPAL) {
			// Satin, or opal: trans with a pearly milk through it that
			// shifts colour towards the edges, and a fine shimmer.
			vec4 grain = flecks(local_position, pixel_ldu, 0.45, 0.5, instance_seed, faded);
			float milk = 0.12 + 0.4 * pow(grazing, 1.5);
			vec3 sheen = 0.5 + 0.5 * cos(6.2832 * (grazing * 0.9 + vec3(0.0, 0.33, 0.67)));
			albedo = mix(body, vec3(1.0), milk) + sheen * 0.06;
			emission = (sheen * 0.05 + body_linear * 0.04) * (1.0 + grain.x * 2.0)
				+ fleck_linear * grain.x * 0.12;
			alpha = clamp(max(alpha, 0.72) + milk * 0.3, 0.0, 1.0);
			glass_roughness = 0.32;
			glass_backlight = mix(instance_color, vec3(1.0), 0.4) * 0.6;
			roughness = 0.32;
		} else if (finish == FINISH_GLOW) {
			// Glow-in-the-dark: waxy, pale, and a faint light of its own.
			albedo = body;
			roughness = 0.36;
			backlight = body * 0.5;
			emission = body_linear * 0.25;
			glass_roughness = 0.42;
			glass_backlight = body * 0.6;
		} else if (finish == FINISH_FLUORESCENT) {
			// Trans-neon: the plastic gathers light and gives it back,
			// strongest at its edges, so it looks lit from inside.
			emission = body_linear * (0.18 + 0.45 * pow(grazing, 1.5));
		} else if (finish == FINISH_RUBBER) {
			// Tyres and bands: no polish at all.
			roughness = 0.72 + 0.1 * grazing;
			specular = 0.22 + 0.1 * pow(grazing, 4.0);
			glass_roughness = 0.6;
		} else if (finish == FINISH_FABRIC) {
			// Capes and sails: a weave, and the soft sheen cloth has at
			// the edges rather than a highlight.
			vec3 w = local_position * 3.14159;
			float weave = sin(w.x) * sin(w.y) + sin(w.y) * sin(w.z) + sin(w.z) * sin(w.x);
			float near_enough = 1.0 - smoothstep(0.3, 0.8, pixel_ldu);
			albedo = body * (0.93 + 0.07 * weave * near_enough) * (1.0 + 0.2 * pow(grazing, 2.0));
			roughness = 0.95;
			specular = 0.08;
		} else if (finish == FINISH_MILKY) {
			// Milky white: light goes in and spreads, like a lampshade.
			albedo = mix(body, vec3(1.0), 0.1);
			alpha = clamp(0.7 + 0.25 * pow(grazing, 2.0), 0.0, 1.0);
			glass_roughness = 0.4;
			glass_backlight = body * 0.9;
			emission = body_linear * 0.03;
		}
	}

#ifdef PLASTIC_PRODUCT
	// Gloss over the plastic, and metals that are metals. The studio drawn
	// for the window's mirrors (studio()) gives way to the render's own
	// sky, which a product shot's chrome reflects.
	float coat = 0.0;
	float coat_roughness = 0.1;
	if (finish == FINISH_PLASTIC) {
		roughness = 0.3 + 0.08 * grazing;
		// ABS has one surface, which reflects about 4.5% head-on. The coat's
		// sharp lobe and the plastic's broad one share it: 0.35 is 2% here,
		// the coat's 0.55 another 2%. At 0.5 under the coat the plastic
		// reflected half as much again as it does, which on black is more
		// than its own colour.
		specular = 0.35;
		coat = 0.55;
		coat_roughness = 0.07;
		// Pale plastics glow a little through: a white brick's shadow side
		// is never grey.
		backlight = vec3(0.16 * luminance_in) * (body_linear / max(luminance_in, 0.001)) * 0.5;
		if (wear_dull > 0.0 || wear_cover > 0.0) {
			// Played with: the gloss worn where the tracer's coat is rough,
			// blurred rather than taken away (a worn coat still reflects as
			// much, spread wider), and the dust dulling it.
			coat *= (1.0 - 0.15 * wear_dull) * (1.0 - wear_cover);
			coat_roughness = mix(coat_roughness, 0.8, wear_dull);
			roughness = mix(mix(roughness, 0.42, wear_dull), 0.9, wear_cover);
			specular *= 1.0 - 0.6 * wear_cover;
		}
	} else if (finish == FINISH_CHROME) {
		albedo = max(body, vec3(0.12));
		metallic = 1.0;
		roughness = 0.06;
		emission *= 0.25;
	} else if (finish == FINISH_METAL) {
		albedo = max(body, vec3(0.06)) * 0.9;
		metallic = 1.0;
		roughness = 0.34;
		coat = 1.0;
		coat_roughness = 0.05;
		emission *= 0.2;
	} else if (finish == FINISH_PEARL) {
		albedo = body * (1.0 + 0.25 * pow(grazing, 2.0));
		metallic = 0.65;
		roughness = 0.3;
		coat = 0.8;
		coat_roughness = 0.08;
		emission *= 0.3;
	} else if (finish == FINISH_RUBBER) {
		roughness = 0.8;
		specular = 0.25;
	} else if (finish == FINISH_SPECKLE || finish == FINISH_GLITTER) {
		coat = 0.6;
		coat_roughness = 0.06;
	}
	roughness = mix(roughness, max(roughness, 0.5), on_round);
	CLEARCOAT = coat * (1.0 - 0.6 * on_round);
	CLEARCOAT_ROUGHNESS = mix(coat_roughness, 0.35, on_round);
#endif
	// In a render's Dark light: no studio to reflect, and the glowing
	// plastics lit from within.
	emission *= room;
	if (finish == FINISH_GLOW || finish == FINISH_FLUORESCENT) {
		emission += body_linear * glow;
	}
	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	BACKLIGHT = backlight;
	EMISSION = linearise ? emission : linear_to_srgb(emission);

#ifdef PLASTIC_TRANSPARENT
	ALPHA = alpha;
	ROUGHNESS = glass_roughness;
	BACKLIGHT = glass_backlight;
#endif
#if defined(PLASTIC_PRODUCT) && defined(PLASTIC_TRANSPARENT)
	// Clear plastic as glass. What comes through it is the picture behind,
	// already tinted by plastic_product_glass, the pass drawn before this
	// one; this pass only adds what glass gives back: the sky and the lights
	// reflected off every surface of it, the inner ones too, which is what
	// outlines a clear brick's tubes and far walls. Added, as reflected
	// light is, so the surfaces need no order. Opal and milky plastic
	// scatter rather than let light through, and are blended over what is
	// behind as before.
	if (!over_nothing
			&& (finish == FINISH_PLASTIC || finish == FINISH_FLUORESCENT || finish == FINISH_GLITTER)) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
		ROUGHNESS = 0.04;
		// Low face on: at Good and Best the engine lights a clear part's
		// reflection from its global illumination, where the white sweep
		// is at full strength, and at glass's own 0.5 that laid a white veil
		// over the whole part (trans red #c91a09 came out #d74e47). Its
		// edges still reflect, as Fresnel has them, and its rounded edges
		// catch the key and the rim as lines of light.
		SPECULAR = mix(0.15, 0.7, rounded);
		BACKLIGHT = vec3(0.0);
		METALLIC = 0.0;
		CLEARCOAT = 0.0;
		EMISSION = linearise ? emission : linear_to_srgb(emission);
	} else {
		// Premultiplied by hand (Compatibility has no PREMUL_ALPHA_FACTOR):
		// the plastic's own colour by how much of it there is, its
		// reflection whole, as a reflection is.
		ALBEDO *= ALPHA;
		BACKLIGHT *= ALPHA;
		EMISSION *= ALPHA;
	}
#endif

#if defined(PLASTIC_CUT) && !defined(PLASTIC_CAP) && !defined(PLASTIC_TRANSPARENT)
	// For a probe: the inside of a part drawn as a surface where the cut
	// goes through it. A surface with no dependable outside draws its back
	// faces as surfaces, so a cut through one shows them (cutshapes_probe
	// counts them).
	if (cut_marks == 1 && !FRONT_FACING) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0, 4.0, 0.0);
	}
#endif
#ifdef PLASTIC_CAP
	}
#endif
}
