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
// A line of its own colour round what this step adds, or nothing.
uniform bool mark_new = false;
uniform vec3 new_colour = vec3(1.0, 0.78, 0.0);

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
	} else {
		vec4 colour = texture(colour_tex, UV);
		if (colour.a > 0.0 && colour.a < 1.0) {
			colour.rgb /= colour.a;
		}
		vec3 mine = texture(code_tex, UV).rgb;
		float edge = 0.0;
		bool fresh = is_brick(mine) && is_new(mine);
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
					if (is_brick(other) && is_new(other)) {
						fresh = true;
					}
					if (!is_brick(other)) {
						met_page = true;
					} else if (lightness(texture(colour_tex, UV + offset).rgb) >= 0.16) {
						dark_other = false;
					}
				}
			}
		}
		vec3 line = (dark && dark_other && !met_page) ? ink_on_dark : ink_colour;
		if (mark_new && fresh) {
			line = new_colour;
		}
		float keep = 1.0;
		if (fade > 0.0) {
			vec2 size = 1.0 / pixel;
			vec2 near = min(at, size - at);
			keep = smoothstep(0.0, fade, min(near.x, near.y));
		}
		if (!is_brick(mine)) {
			// The page round the model: only the outline is drawn on it.
			COLOR = vec4(line, edge * keep);
		} else {
			COLOR = vec4(mix(colour.rgb, line, edge), keep);
		}
	}
}
