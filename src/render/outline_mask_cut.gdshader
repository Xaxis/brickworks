// outline_mask.gdshader while a cut-away is on: what is past its plane
// (plastic_body's cut_plane) is taken off, and the outline goes round what
// is left.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);

void fragment() {
	vec3 world_at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (dot(cut_plane.xyz, world_at) > cut_plane.w) {
		discard;
	}
	ALBEDO = vec3(1.0);
}
