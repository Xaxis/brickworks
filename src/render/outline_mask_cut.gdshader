// outline_mask.gdshader while a cut-away is on: what it takes off (its
// plane, box, sphere or cylinder: cut_shape.gdshaderinc) is taken off here
// too, and the outline goes round what is left.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://src/render/cut_shape.gdshaderinc"

void fragment() {
	vec3 world_at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (cut_away_at(world_at)) {
		discard;
	}
	ALBEDO = vec3(1.0);
}
