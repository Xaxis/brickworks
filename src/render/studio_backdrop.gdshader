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
// A studio's fall of light (RenderSettings.backdrop_gradient): how much
// darker the sweep is at the edge of the picture than under the model,
// and over what distance from the model, along the sweep, in LDU: full
// strength within pool.x, fallen away by pool.y. Zero is one even colour.
uniform float fall = 0.0;
uniform vec2 pool = vec2(100.0, 400.0);

// Where on the sweep, in its own space: the model stands at the origin.
varying vec3 at;

void vertex() {
	at = VERTEX;
}

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
	// Measured along the floor and on up the wall, which is how far the
	// light from over the model has to reach.
	float along = length(at.xz) + max(at.y, 0.0);
	float lit = 1.0 - fall * smoothstep(pool.x, pool.y, along);
	vec3 lin = to_linear(colour) * lit * lit;
	float reflects = min(level, 1.0);
	ALBEDO = (linearise ? lin : to_srgb(lin)) * reflects;
	ROUGHNESS = 0.9;
	// Paper, not plastic: a glossy sweep mirrored the bright windows of a
	// photographed place as a band across the floor.
	SPECULAR = 0.04;
	vec3 own = lin * max(level - 1.0, 0.0) * 0.5;
	EMISSION = linearise ? own : to_srgb(own);
}
