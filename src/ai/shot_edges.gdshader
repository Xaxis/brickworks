// A picture of the model with the parts a session asked to see edged in
// magenta (ModelShot.edged), each its own outline.
//
// The codes are booklet_codes': which part each pixel shows, the edged
// ones marked "new" (blue's lowest level bit). A pixel is on an edge when
// a neighbour within the reach shows another part, or nothing, and one of
// the two is edged: the line is centred on the boundary, round each edged
// part where it is in sight and along the seam between two of them.

shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D colour_tex : filter_nearest, repeat_disable;
uniform sampler2D code_tex : filter_nearest, repeat_disable;
// One pixel, as a distance in UV.
uniform vec2 pixel = vec2(0.001);
// Half the line's width, in pixels.
uniform float reach = 2.5;
uniform vec3 edge = vec3(1.0, 0.0, 1.0);

bool differs(vec3 a, vec3 b) {
	return any(greaterThan(abs(a - b), vec3(3.5 / 255.0)));
}

bool is_brick(vec3 code) {
	return all(greaterThan(code, vec3(40.0 / 255.0)));
}

// See booklet_codes: 64 + 8 * level, blue's lowest level bit the new one.
bool is_edged(vec3 code) {
	return is_brick(code) && mod(floor((code.b * 255.0 - 64.0) / 8.0 + 0.5), 2.0) > 0.5;
}

void fragment() {
	vec4 colour = texture(colour_tex, UV);
	vec3 mine = texture(code_tex, UV).rgb;
	bool mine_edged = is_edged(mine);
	bool on = false;
	for (int ring = 1; ring <= 2; ring++) {
		float r = reach * float(ring) * 0.5;
		for (int n = 0; n < 8; n++) {
			float a = float(n) * 0.7853982;
			vec3 other = texture(code_tex, UV + vec2(cos(a), sin(a)) * r * pixel).rgb;
			if (differs(other, mine) && (mine_edged || is_edged(other))) {
				on = true;
			}
		}
	}
	COLOR = vec4(on ? edge : colour.rgb, 1.0);
}
