// Every part a flat colour that is its own number, read back exactly: what
// SeenParts counts to say which parts can be seen from outside a model.
//
// The number comes in as booklet_codes takes it (BookletStudio.code_colour:
// five bits a channel, alpha past 16,384). It goes out as booklet_codes
// found the way out survives under both renderers: 24 levels a channel
// from 64 up, every value above 60 exact. Unlike the booklet's lines, which
// only need two touching parts to differ, this needs every number told
// apart, so nothing is wrapped and no bit is spent on "new": 13,823
// numbers a picture, those after [first], and every other part drawn as 0.
// A model of more parts than that is drawn again from the same side with
// [first] moved on; every part is drawn every time, so what hides what is
// the same in each.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix, fog_disabled;

uniform bool linearise = true;
uniform float first = 0.0;

varying flat vec4 code;

void vertex() {
	code = COLOR;
}

float level(float value) {
	return floor(value * 255.0 / 8.0 + 0.01);
}

vec3 to_linear(vec3 c) {
	vec3 low = c / 12.92;
	vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, vec3(lessThan(c, vec3(0.04045))));
}

void fragment() {
	float number = level(code.r) + 32.0 * level(code.g) + 1024.0 * floor(level(code.b) / 2.0)
		+ 16384.0 * level(code.a);
	float value = number - first;
	if (value < 1.0 || value > 13823.0) {
		value = 0.0;
	}
	vec3 shown = (vec3(mod(value, 24.0), mod(floor(value / 24.0), 24.0), floor(value / 576.0))
		* 8.0 + 64.0) / 255.0;
	ALBEDO = linearise ? to_linear(shown) : shown;
}
