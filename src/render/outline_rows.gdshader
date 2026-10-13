// SelectionOutline's first pass: for every pixel, how far along its row the
// nearest pixel of the mask is, up to the line's reach (red: one at the mask,
// none beyond the reach, so what is never drawn here reads as far); and
// whether it is in the mask itself (green). Written as it is, for the second
// pass to read: no blending.

shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform int reach = 4;

void fragment() {
	float inside = texture(TEXTURE, UV).r;
	float step = TEXTURE_PIXEL_SIZE.x;
	float nearest = float(reach + 1);
	if (inside > 0.5) {
		nearest = 0.0;
	} else {
		for (int x = 1; x <= reach; x++) {
			float left = texture(TEXTURE, UV - vec2(float(x) * step, 0.0)).r;
			float right = texture(TEXTURE, UV + vec2(float(x) * step, 0.0)).r;
			if (max(left, right) > 0.5) {
				nearest = float(x);
				break;
			}
		}
	}
	COLOR = vec4(1.0 - nearest / float(reach + 1), inside > 0.5 ? 1.0 : 0.0, 0.0, 1.0);
}
