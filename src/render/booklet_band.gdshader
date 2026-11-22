// The first of the two passes that find the band round a step's new parts
// when its designer made it wider than the booklet's own (BookletSheet
// outline_width, StudWorx's Highlight Width, 1 to 72 px): for each pixel,
// how far along its row the nearest new part is, in pixels, within [most].
// booklet_ink then takes the nearest down each column of these, which is
// the true distance, so the band is round however thin the part, where the
// ink's own rings, 36 rays at three distances, left gaps at 72 px.
//
// Red is the distance / 255, 255 for none within reach. The codes' token is
// copied into the corner, so the ink's corner proves this pass was drawn
// from the codes of the picture asked for (BookletStudio._drawn); the token
// itself, a light code whose blue reads as new, is not taken for a part.

shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D code_tex : filter_nearest, repeat_disable;
// One pixel, as a distance in UV.
uniform vec2 pixel = vec2(0.001);
// How far along the row to look, in pixels.
uniform int most = 8;

// See booklet_ink and booklet_codes: a brick when every channel is 40 or
// more, new when blue's level bit is odd.
bool is_new(vec3 code) {
	return all(greaterThan(code, vec3(40.0 / 255.0)))
		&& mod(floor((code.b * 255.0 - 64.0) / 8.0 + 0.5), 2.0) > 0.5;
}

// A new part at [x] pixels along this row, the token's corner aside.
bool new_at(vec2 uv, float x) {
	vec2 at = uv / pixel + vec2(x, 0.0);
	if (at.x < 4.0 && at.y < 4.0) {
		return false;
	}
	return is_new(texture(code_tex, uv + vec2(x, 0.0) * pixel).rgb);
}

void fragment() {
	vec2 at = UV / pixel;
	if (at.y < 3.0 && at.x < 3.0) {
		COLOR = vec4(texture(code_tex, UV).rgb, 1.0);
	} else {
		float found = 255.0;
		for (int x = 0; x <= most; x++) {
			if (new_at(UV, float(x)) || new_at(UV, -float(x))) {
				found = float(x);
				break;
			}
		}
		COLOR = vec4(found / 255.0, 0.0, 0.0, 1.0);
	}
}
