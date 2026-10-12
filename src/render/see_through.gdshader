// A part seen through: x-ray's ghosts, and what a cut-away takes off when
// it is asked to leave a ghost of it (SeeInside).
//
// Faint, so a tower of them still shows what is inside it: a fill a few
// percent strong, and an edge where the surface turns away from the eye,
// which is what keeps a ghost reading as the part it is. Unlit, and casting
// no shadow, so what is inside is lit as if the ghosts were not there. It
// writes no depth, so it hides nothing behind it from the eye, and the
// pointer passes through it (BrickLattice.see_through, and the cut).

shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// As plastic_body's: whether the instance colour is sRGB to be made linear.
uniform bool linearise = true;
// The cut-away's plane (plastic_body's cut_plane), and which side of it
// this draws: the near side for x-ray, the far side for the ghost of what
// the cut takes away.
uniform bool cut_on = false;
uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);
uniform bool beyond = false;

varying vec3 tint;

void vertex() {
	vec3 c = COLOR.rgb;
	if (linearise) {
		bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
		c = mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, vec3(cutoff));
	}
	tint = c;
}

void fragment() {
	if (cut_on) {
		vec3 world_at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		bool past = dot(cut_plane.xyz, world_at) > cut_plane.w;
		if (past != beyond) {
			discard;
		}
	}
	vec3 normal = normalize(NORMAL);
	float facing = abs(dot(normal, normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	ALBEDO = mix(tint, vec3(linearise ? 0.7 : 0.85), 0.12 + 0.3 * rim);
	ALPHA = 0.04 + 0.28 * rim;
}
