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

uniform float base_roughness : hint_range(0.0, 1.0) = 0.22;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.10;
uniform float specular_level : hint_range(0.0, 1.0) = 0.5;

// Light colours scatter a little under the surface, which is why a white
// brick never reads as pure white in shadow.
uniform float subsurface : hint_range(0.0, 1.0) = 0.10;

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
varying vec3 local_position;

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
}

// How much of a seam this fragment is in, from 0 to 1.
float seam_at(vec3 at) {
	vec3 size = part_box_max - part_box_min;
	if (size.x <= 0.0 || size.y <= 0.0 || size.z <= 0.0) {
		return 0.0;
	}
	vec3 d = min(at - part_box_min, part_box_max - at);
	// Near one face is anywhere on that face; near two is an edge. So it
	// is the second nearest that decides.
	float nearest = min(d.x, min(d.y, d.z));
	float furthest = max(d.x, max(d.y, d.z));
	float second = d.x + d.y + d.z - nearest - furthest;
	vec3 per_pixel = fwidth(at);
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

void fragment() {
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
	float seam = seam_at(local_position);
	vec3 linear_color = linearise ? instance_color : srgb_to_linear(instance_color);
	float luminance_in = dot(linear_color, vec3(0.2126, 0.7152, 0.0722));
	vec3 seam_color = luminance_in < 0.025 ? instance_color + vec3(0.03)
		: instance_color * (1.0 - seam_depth);
	vec3 body = mix(instance_color, seam_color, seam);
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
	// How many LDU one pixel spans here, for the finishes with detail
	// finer than that to fade it out. Taken out here, where every
	// fragment takes it.
	vec3 local_width = fwidth(local_position);
	float pixel_ldu = max(local_width.x, max(local_width.y, local_width.z));
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
	float glass_roughness = base_roughness * 0.4;
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
}
