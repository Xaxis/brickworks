// The booklet's picture: the model as rendered, with an ink line wherever
// one brick meets another or meets the page.
//
// That line is most of what makes a printed booklet readable. Without it
// a wall of light grey bricks is one light grey shape, and a reader
// counting "four bricks along" has nothing to count. The numbers come
// from booklet_codes; a pixel is on a line when a neighbour within half
// the ink's width belongs to a different brick, so the line is centred
// on the boundary and the same width everywhere.
//
// Black plastic gets a grey line where it meets more black plastic, as
// in print: a black line on black is no line.

shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D colour_tex : filter_linear, repeat_disable;
uniform sampler2D code_tex : filter_nearest, repeat_disable;
// One pixel, as a distance in UV.
uniform vec2 pixel = vec2(0.001);
// The line's width, in pixels.
uniform float ink = 3.0;
uniform vec3 ink_colour = vec3(0.09, 0.09, 0.10);
uniform vec3 ink_on_dark = vec3(0.46, 0.47, 0.50);
// How far in from the edge of the picture the model fades to the page,
// in pixels. A step of one part of a big model is framed on that part,
// and the rest of the model runs off the picture's edge; cut there, mid
// page, it read as the model sliced through.
uniform float fade = 0.0;
// Inside a part, a fainter line where its shading turns a corner — the
// rim of a stud, the edge of a brick's top — found from how sharply the
// lightness changes. 0 for none.
uniform float crease = 0.0;
// A band of its own colour round what this step adds, just outside the
// ink line round it, or nothing: the new parts outlined, as Studio's
// Instruction Maker and the LEGO app's steps outline them. The parts keep
// their colours and their ink, so the band reads as a mark, not plastic.
uniform bool mark_new = false;
uniform vec3 new_colour = vec3(1.0, 0.52, 0.06);
// How wide the band is, in pixels.
uniform float halo = 6.0;

bool differs(vec3 a, vec3 b) {
	return any(greaterThan(abs(a - b), vec3(3.5 / 255.0)));
}

// See booklet_codes: 64 + 8 * level, blue's lowest level bit the new one.
bool is_new(vec3 code) {
	return mod(floor((code.b * 255.0 - 64.0) / 8.0 + 0.5), 2.0) > 0.5;
}

bool is_brick(vec3 code) {
	return all(greaterThan(code, vec3(40.0 / 255.0)));
}

float lightness(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 at = UV / pixel;
	// The corner carries the two passes' tokens, so whoever reads this
	// can tell that both were drawn for the picture it asked for.
	if (at.y < 3.0 && at.x < 3.0) {
		COLOR = vec4(texture(code_tex, UV).rgb, 1.0);
	} else if (at.y < 3.0 && at.x < 6.0) {
		COLOR = vec4(texture(colour_tex, UV - vec2(3.0 * pixel.x, 0.0)).rgb, 1.0);
	} else if (at.y < 12.0 && at.x < 12.0) {
		// Round the tokens, where the line would ring them as if they were
		// a brick: a dot at the corner of every part in every parts box.
		COLOR = vec4(0.0);
	} else {
		vec4 colour = texture(colour_tex, UV);
		if (colour.a > 0.0 && colour.a < 1.0) {
			colour.rgb /= colour.a;
		}
		// Black plastic drawn as a booklet draws it: a dark grey whose
		// faces can be told apart, not a silhouette. Lifted by how dark
		// it is, so the lit top of a black brick stays lighter than its
		// side; and only the greys — lifted the same way, a red's shaded
		// side came out neon.
		float chroma = max(colour.r, max(colour.g, colour.b))
			- min(colour.r, min(colour.g, colour.b));
		float dim = (1.0 - smoothstep(0.0, 0.24, lightness(colour.rgb)))
			* (1.0 - smoothstep(0.03, 0.10, chroma));
		colour.rgb = colour.rgb * (1.0 + 0.8 * dim) + vec3(0.045) * dim;
		vec3 mine = texture(code_tex, UV).rgb;
		float edge = 0.0;
		bool dark = is_brick(mine) && lightness(colour.rgb) < 0.16;
		bool dark_other = true;
		bool met_page = false;
		float reach = ink * 0.5;
		for (int ring = 1; ring <= 2; ring++) {
			float r = reach * float(ring) * 0.5;
			for (int n = 0; n < 8; n++) {
				float a = float(n) * 0.7853982;
				vec2 offset = vec2(cos(a), sin(a)) * r * pixel;
				vec3 other = texture(code_tex, UV + offset).rgb;
				if (differs(other, mine)) {
					edge = 1.0;
					if (!is_brick(other)) {
						met_page = true;
					} else if (lightness(texture(colour_tex, UV + offset).rgb) >= 0.16) {
						dark_other = false;
					}
				}
			}
		}
		vec3 line = (dark && dark_other && !met_page) ? ink_on_dark : ink_colour;
		if (edge < 0.5 && crease > 0.0 && is_brick(mine)) {
			// Sobel on lightness, one pixel out, within this brick only.
			float l[9];
			int k = 0;
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					vec2 o = vec2(float(x), float(y)) * pixel * max(1.0, ink * 0.4);
					l[k] = lightness(texture(colour_tex, UV + o).rgb);
					k++;
				}
			}
			float gx = (l[2] + 2.0 * l[5] + l[8]) - (l[0] + 2.0 * l[3] + l[6]);
			float gy = (l[6] + 2.0 * l[7] + l[8]) - (l[0] + 2.0 * l[1] + l[2]);
			float g = sqrt(gx * gx + gy * gy);
			float faint = smoothstep(0.22, 0.45, g) * crease;
			colour.rgb = mix(colour.rgb, dark ? ink_on_dark : colour.rgb * 0.35, faint);
		}
		// Outside a new part, within the band of one: the band's colour.
		bool banded = false;
		if (mark_new && !(is_brick(mine) && is_new(mine)) && edge < 0.5) {
			for (int ring = 1; ring <= 3 && !banded; ring++) {
				float r = reach + halo * float(ring) / 3.0;
				for (int n = 0; n < 12; n++) {
					float a = float(n) * 0.5235988;
					vec3 other = texture(code_tex, UV + vec2(cos(a), sin(a)) * r * pixel).rgb;
					if (is_brick(other) && is_new(other)) {
						banded = true;
						break;
					}
				}
			}
		}
		float keep = 1.0;
		if (fade > 0.0) {
			vec2 size = 1.0 / pixel;
			vec2 near = min(at, size - at);
			keep = smoothstep(0.0, fade, min(near.x, near.y));
		}
		if (banded) {
			COLOR = vec4(new_colour, keep);
		} else if (!is_brick(mine)) {
			// The page round the model: only the outline is drawn on it.
			COLOR = vec4(line, edge * keep);
		} else {
			COLOR = vec4(mix(colour.rgb, line, edge), keep);
		}
	}
}
