// Every brick in a flat colour that is its own number, for the booklet.
//
// A printed booklet draws an ink line round every part. The renders here
// have no edges of their own, and a line found from depth or normals
// draws the studs and misses the seam between two bricks of one colour
// side by side, which is the line that matters most: it is how you count
// the bricks in a wall. So this draws which brick is where, and
// booklet_ink draws a line wherever that changes.
//
// The number comes in the instance colour, five bits a channel: each
// channel is (level * 8 + 4) / 255, and one level either way is still the
// same level. Red and green carry ten bits, blue four more, alpha the
// number past 16,384.
//
// It goes out differently, because the way out is not the way in. Under
// Compatibility what is written is stored in eight bits of linear light
// and read back as sRGB, and the dark end does not survive that: 4 came
// back as 0 or 6, 12 as 16, 20 as 25 — measured, every value below 60 was
// moved, every value above it exact. So the number goes out as 24 levels
// a channel from 64 up (64 + 8 * level), blue's lowest bit saying whether
// the brick is new: 6,912 numbers, taken modulo. Two bricks that touch
// and share a number lose the line between them; with numbers handed out
// in building order, those two are thousands of bricks apart.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix, fog_disabled;

// Forward+ converts what is written from linear to sRGB on the way out,
// and Compatibility writes it as it is (see BrickWorld._linearise_colors).
uniform bool linearise = true;
// Bricks numbered from here on are the ones this step adds.
uniform float new_from = 1.0e9;
// Draw only those: how much of them there would be to see if nothing
// were in front of them.
uniform bool only_new = false;
// Only whether each pixel is of a new brick: white where it is, black
// where it is not. The same pixels as the codes say are new, for the
// engine to count rather than a loop over them (BookletStudio.measure_all).
uniform bool mask = false;

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
	float red = level(code.r);
	float green = level(code.g);
	float blue = floor(level(code.b) / 2.0);
	float number = red + 32.0 * green + 1024.0 * blue + 16384.0 * level(code.a);
	bool fresh = number >= new_from;
	if (only_new && !fresh) {
		discard;
	}
	float wrapped = mod(number, 6912.0);
	float out_red = mod(wrapped, 24.0);
	float out_green = mod(floor(wrapped / 24.0), 24.0);
	float out_blue = floor(wrapped / 576.0) * 2.0 + (fresh ? 1.0 : 0.0);
	vec3 shown = (vec3(out_red, out_green, out_blue) * 8.0 + 64.0) / 255.0;
	if (mask) {
		shown = fresh ? vec3(1.0) : vec3(0.0);
	}
	ALBEDO = linearise ? to_linear(shown) : shown;
}
