// The Line art and Comic looks (LineArt): the model as a person inks it.
//
// Five pictures of the same shot come in. The model in the set's light
// (lit_tex), for the shadow it casts on the floor (its alpha), and in its
// own colours with no light at all (flat_tex), both on nothing; every part
// a flat colour that is its number (code_tex, as booklet_codes draws it);
// which way each face looks (normal_tex, line_normals); and the model all
// white clay in the set's light (light_tex). Out of them:
//
//   lines   where the model meets the page, thickest; where one part meets
//           the next, which is how a wall's bricks are counted; and,
//           thinnest, where a part's own surface turns a corner more than
//           CREASE degrees: a stud's rim, a brick's top edge, a slope's
//           fold; and in Line art round a print (a face, a stripe), where
//           a part's own colour changes. Nothing else, so a shadow's edge
//           or a glint is no line;
//   shade   the light falling on each face, the clay's, so a red brick and
//           a white one in the same light are shaded the same: drawn as
//           halftone dots, a screen at 45° that grows from nothing on a
//           face turned to the light to dots that nearly touch in shadow,
//           and on the floor the darker heart of the model's shadow;
//   paper   Line art's model is the paper's white inside its lines, to ink
//           or colour over; Comic's is the plastic's own colour, flat, a
//           shade darker where the light leaves it, its dots a darker shade
//           of that colour. Round the model the backdrop's colour, or
//           nothing at all.
//
// Every distance is in pixels of the whole picture (origin), so a picture
// drawn in pieces has one screen and one weight of line across them.

shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D lit_tex : filter_nearest, repeat_disable;
uniform sampler2D flat_tex : filter_nearest, repeat_disable;
uniform sampler2D code_tex : filter_nearest, repeat_disable;
uniform sampler2D normal_tex : filter_nearest, repeat_disable;
uniform sampler2D light_tex : filter_nearest, repeat_disable;
// One pixel, as a distance in UV, and where this piece's first pixel is in
// the whole picture.
uniform vec2 pixel = vec2(0.001);
uniform vec2 origin = vec2(0.0);
// A part's line across, in pixels: the outline is half as wide again, a
// corner's line a third of it.
uniform float ink = 2.0;
// The halftone's cell, in pixels.
uniform float cell = 6.0;
uniform bool comic = false;
// Round the model; alpha 0 for nothing behind it.
uniform vec4 paper = vec4(1.0);
uniform vec3 ink_colour = vec3(0.06, 0.06, 0.07);
// Comic's line between two dark parts, as in print: a black line on black
// plastic is no line.
uniform vec3 ink_on_dark = vec3(0.46, 0.47, 0.50);
// A part's surface turned more than this between two pixels, as the cosine.
uniform float crease = 0.866;
// A print's edge: a part's own colour this far apart between two pixels.
uniform float print_edge = 0.2;
// The light on the clay (linear) at which the dots begin and where they
// are densest; and how much of the cell they cover there.
uniform float shade_from = 0.75;
uniform float shade_full = 0.35;
uniform float densest = 0.55;
// The floor's shadow (its alpha) drawn from here, darkest there: its faint
// outer reaches, which spread far round a model, left as paper.
uniform float floor_from = 0.18;
uniform float floor_full = 0.8;

const int MOST = 6;

bool differs(vec3 a, vec3 b) {
	return any(greaterThan(abs(a - b), vec3(3.5 / 255.0)));
}

bool is_brick(vec3 code) {
	return all(greaterThan(code, vec3(40.0 / 255.0)));
}

float lightness(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 to_linear(vec3 c) {
	vec3 low = c / 12.92;
	vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, vec3(lessThan(c, vec3(0.04045))));
}

vec3 facing(vec2 uv) {
	return normalize((texture(normal_tex, uv).rgb - vec3(0.3)) / 0.35 - vec3(1.0));
}

// How much of a line [side] pixels either side of a change [d] pixels away
// covers this pixel: the change lies half a pixel short of the pixel that
// differs.
float covered(float side, float d) {
	return clamp(side - d + 1.0, 0.0, 1.0);
}

// How much of this pixel the screen's dot covers, for a tone of 0 (none)
// to 1, at [at] in the picture.
float dot_at(vec2 at, float tone) {
	if (tone <= 0.001) {
		return 0.0;
	}
	const float turn = 0.7853982;
	vec2 p = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * at / cell;
	float d = length(fract(p) - vec2(0.5));
	float radius = sqrt(clamp(tone, 0.0, 1.0) / 3.14159);
	float soft = 0.7 / cell;
	return 1.0 - smoothstep(radius - soft, radius + soft, d);
}

// The tone for a face in [light], the clay's.
float tone_for(float light) {
	return densest * (1.0 - smoothstep(shade_full, shade_from, light));
}

// A pixel of the model: [line] of it inked, [light] on it.
vec3 on_the_model(vec2 at, vec4 flat_colour, float light, float line, float to_page, float between,
		bool light_other) {
	// Clear plastic drawn on nothing comes out see-through; drawn here as
	// the colour it is.
	vec3 own = flat_colour.a > 0.01 ? flat_colour.rgb / max(flat_colour.a, 0.01) : flat_colour.rgb;
	own = clamp(own, 0.0, 1.0);
	float tone = tone_for(light);
	vec3 shown;
	vec3 line_colour = ink_colour;
	if (comic) {
		// Black plastic as print draws it: a dark grey whose faces can be
		// told apart, and only the greys lifted (booklet_ink).
		float chroma = max(own.r, max(own.g, own.b)) - min(own.r, min(own.g, own.b));
		float dim = (1.0 - smoothstep(0.0, 0.24, lightness(own)))
			* (1.0 - smoothstep(0.03, 0.10, chroma));
		vec3 body = own * (1.0 + 0.8 * dim) + vec3(0.045) * dim;
		if (flat_colour.a < 0.95) {
			// Glass: its colour, paler, as a comic draws a window.
			body = mix(body, vec3(1.0), 0.45);
		}
		// Two flat shades, lit and turned from the light, and dots of a
		// darker shade over the second.
		float away = smoothstep(shade_full + 0.1, shade_from - 0.05, light);
		vec3 face = body * mix(0.82, 1.0, away);
		shown = mix(face, body * 0.42, dot_at(at, tone));
		if (lightness(body) < 0.16 && !light_other && to_page > between + 1.0) {
			line_colour = ink_on_dark;
		}
	} else {
		shown = mix(vec3(1.0), ink_colour, dot_at(at, tone));
	}
	return mix(shown, line_colour, line);
}

void fragment() {
	vec2 at = origin + UV / pixel;
	vec3 mine = texture(code_tex, UV).rgb;
	bool brick = is_brick(mine);
	vec3 n = brick ? facing(UV) : vec3(0.0, 0.0, 1.0);
	vec4 lit = texture(lit_tex, UV);
	vec4 flat_colour = texture(flat_tex, UV);
	bool printable = !comic && flat_colour.a > 0.95;

	// The nearest change of each kind within reach.
	float outline = ink * 0.75;
	float between = ink * 0.5;
	float corner = ink * 0.32;
	float reach = outline + 1.0;
	float to_page = 99.0;
	float to_part = 99.0;
	float to_corner = 99.0;
	float to_print = 99.0;
	bool light_other = false;
	for (int y = -MOST; y <= MOST; y++) {
		for (int x = -MOST; x <= MOST; x++) {
			vec2 o = vec2(float(x), float(y));
			float d = length(o);
			if (d < 0.5 || d > reach) {
				continue;
			}
			vec2 uv = UV + o * pixel;
			vec3 other = texture(code_tex, uv).rgb;
			bool other_brick = is_brick(other);
			if (brick != other_brick) {
				to_page = min(to_page, d);
			} else if (brick && differs(other, mine)) {
				if (d <= between + 1.0) {
					to_part = min(to_part, d);
					if (lightness(texture(flat_tex, uv).rgb) >= 0.16) {
						light_other = true;
					}
				}
			} else if (brick && d <= corner + 1.0) {
				if (dot(facing(uv), n) < crease) {
					to_corner = min(to_corner, d);
				} else if (printable) {
					vec4 there = texture(flat_tex, uv);
					if (there.a > 0.95 && distance(there.rgb, flat_colour.rgb) > print_edge) {
						to_print = min(to_print, d);
					}
				}
			}
		}
	}
	float line = max(max(covered(outline, to_page), covered(between, to_part)),
		max(covered(corner, to_corner), covered(corner, to_print)));

	if (!brick) {
		// The page, with the model's shadow on it in dots: the contact
		// shadow, which on nothing is drawn as alpha.
		float shadow = dot_at(at, densest * smoothstep(floor_from, floor_full, lit.a));
		float ink_here = max(line, shadow);
		if (paper.a > 0.5) {
			COLOR = vec4(mix(paper.rgb, ink_colour, ink_here), 1.0);
		} else {
			COLOR = vec4(ink_colour, ink_here);
		}
	} else {
		vec3 clay = to_linear(texture(light_tex, UV).rgb);
		float light = dot(clay, vec3(0.2126, 0.7152, 0.0722));
		COLOR = vec4(on_the_model(at, flat_colour, light, line, to_page, between, light_other), 1.0);
	}
}


