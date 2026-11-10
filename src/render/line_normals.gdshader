// Which way every face of the model looks, for the line looks (LineArt).
//
// A person inking a brick draws where it turns a corner — the rim of a
// stud, the edge of its top — as well as where it ends. The codes
// (booklet_codes) say where one part ends and the next begins; this says
// where a part's own surface turns: a line goes wherever two pixels of one
// part face ways more than a corner apart (line_art.gdshader). Read from
// the lightness of a lit picture instead, the booklet's crease is also
// drawn along every soft shadow's edge.
//
// The direction is the camera's, kept above 0.3 a channel. Under
// Compatibility every value written below 60 of 255 came back moved
// (booklet_codes), and black is the background: nothing there.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix, fog_disabled;

// Forward+ converts what is written from linear to sRGB on the way out,
// and Compatibility writes it as it is (see BrickWorld._linearise_colors).
uniform bool linearise = true;

vec3 to_linear(vec3 c) {
	vec3 low = c / 12.92;
	vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, vec3(lessThan(c, vec3(0.04045))));
}

void fragment() {
	// In view space, and turned round for a face seen from behind: the
	// engine flips it where faces of both sides are drawn.
	vec3 facing = normalize(NORMAL);
	vec3 shown = vec3(0.3) + 0.7 * (facing * 0.5 + vec3(0.5));
	ALBEDO = linearise ? to_linear(shown) : shown;
}
