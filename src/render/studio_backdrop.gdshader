// The sweep a model is photographed on (StudioRender): a floor that curves
// up into a wall with no line between them, matte, in one colour.
//
// Lit and shadowed like everything else, and brought to the colour asked
// for the way a photographer lights a sweep apart from the subject:
// StudioRender meters the floor and sets [level]. Below 1 the sweep
// reflects less of the light; above, it has some of its own. Lit only by
// the model's lights, a white sweep came out a mid grey under the
// photographed places, and clipped to a flat white under the window's.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

// As a person picks it, sRGB.
uniform vec3 colour = vec3(1.0);
// See plastic_body: Forward+ wants linear values, Compatibility sRGB ones.
uniform bool linearise = true;
// How bright the sweep is made, set by metering it.
uniform float level = 1.0;

vec3 to_linear(vec3 c) {
	bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, vec3(cutoff));
}

vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	bvec3 cutoff = lessThanEqual(c, vec3(0.0031308));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - vec3(0.055), c * 12.92, vec3(cutoff));
}

void fragment() {
	vec3 lin = to_linear(colour);
	float reflects = min(level, 1.0);
	ALBEDO = (linearise ? lin : colour) * reflects;
	ROUGHNESS = 0.9;
	// Paper, not plastic: a glossy sweep mirrored the bright windows of a
	// photographed place as a band across the floor.
	SPECULAR = 0.04;
	vec3 own = lin * max(level - 1.0, 0.0) * 0.5;
	EMISSION = linearise ? own : to_srgb(own);
}
