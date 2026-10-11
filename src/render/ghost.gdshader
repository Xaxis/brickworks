// The part about to be placed, before it is placed.
//
// A ghost has two jobs: show the part as it will be, and say whether it
// can go there. It used to do the second at the cost of the first: every
// ghost was 55% green, so the colour you were about to place was not the
// colour you saw, and a green brick's ghost and any other looked alike.
// Studio and Mecabricks both show the part in its own colour.
//
// So a ghost that fits is the part itself — its own colour, shaded so a
// white brick still has a top and sides — made translucent and edged in
// light. One that does not fit is unmistakable whatever its colour: red,
// and striped across the screen, which no plastic is.
//
// It draws without writing depth so it is never buried inside the brick
// it is resting on.

shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform vec3 tint : source_color = vec3(0.7, 0.1, 0.1);
uniform bool valid = true;

void fragment() {
	vec3 normal = normalize(NORMAL);
	// A light from above and to the left of the viewer, in view space,
	// and a floor of ambient so no face goes black.
	float lit = clamp(dot(normal, normalize(vec3(-0.35, 0.8, 0.5))), 0.0, 1.0);
	float shade = 0.62 + 0.38 * lit;
	float facing = abs(dot(normal, vec3(0.0, 0.0, 1.0)));
	float rim = pow(1.0 - facing, 2.0);

	if (valid) {
		ALBEDO = tint * shade + rim * 0.35;
		ALPHA = 0.62 + rim * 0.3;
	} else {
		// Stripes in screen space, so they read the same at any distance.
		float band = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / 14.0));
		vec3 refused = mix(vec3(0.95, 0.16, 0.14), vec3(0.55, 0.05, 0.05), band);
		ALBEDO = mix(tint * shade, refused, 0.72) + rim * 0.25;
		ALPHA = 0.72 + rim * 0.2;
	}
}
