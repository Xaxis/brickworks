// The average, as the 8-bit picture that is kept (StudioRender).
//
// The first frame plus the summed differences, or the running mean. An
// average of many frames is finer than 8 bits can hold, and a backdrop's
// sweep from white to grey cut to 8 bits is a staircase of bands; a
// step's worth of noise on the way out turns the staircase into grain too
// fine to see.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D base_tex : filter_nearest, repeat_disable;
uniform sampler2D sum_tex : filter_nearest, repeat_disable;
uniform bool floats = true;
uniform float dither = 1.0;

float noise(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec4 c = floats ? texture(base_tex, UV) + texture(sum_tex, UV) : texture(sum_tex, UV);
	// Triangular, a step either way at most.
	float n = noise(FRAGCOORD.xy) + noise(FRAGCOORD.xy + 41.7) - 1.0;
	c.rgb += vec3(n * dither / 255.0);
	COLOR = clamp(c, 0.0, 1.0);
}
