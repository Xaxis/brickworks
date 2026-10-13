// The selection's mask for SelectionOutline: its parts in plain white, in a
// world of their own, through the view's camera. Unlit, both sides, and no
// depth: only where they are on screen matters, not what is in front.
//
// The cut-away takes off what is past its plane (plastic_body's cut_plane),
// and the outline goes round what is left.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform bool cut_on = false;
uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);

void fragment() {
	if (cut_on) {
		vec3 world_at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (dot(cut_plane.xyz, world_at) > cut_plane.w) {
			discard;
		}
	}
	ALBEDO = vec3(1.0);
}
