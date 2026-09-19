// The part about to be placed, before it is placed.
//
// A ghost has one job: say where the brick will land and whether it can.
// So it is translucent enough to see what is underneath, tinted with the
// colour it will actually be, and it reads green or red at a glance
// without depending on the tint — someone placing a red brick still needs
// to be able to tell a refusal from the plastic.
//
// It draws without depth testing against the model so it is never buried
// inside the brick it is resting on, and never writes depth itself.

shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform vec3 tint : source_color = vec3(0.7, 0.1, 0.1);
uniform bool valid = true;

// How far the verdict pulls the colour away from the part's own. Enough
// to be unmistakable, not so much that the part's colour is lost.
uniform float verdict_mix : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 verdict = valid ? vec3(0.25, 1.0, 0.45) : vec3(1.0, 0.25, 0.25);
	vec3 base = mix(tint, verdict, verdict_mix);

	// Brighter towards the silhouette, so the shape reads as a solid
	// object rather than a flat wash.
	float facing = abs(dot(normalize(NORMAL), vec3(0.0, 0.0, 1.0)));
	float rim = pow(1.0 - facing, 2.0);

	ALBEDO = base + rim * 0.5;
	ALPHA = (valid ? 0.42 : 0.55) + rim * 0.3;
}
