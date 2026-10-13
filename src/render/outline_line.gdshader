// SelectionOutline's second pass, drawn over the view: down its column, the
// nearest of the rows' distances, so the true distance to the mask; and the
// line where that is under its width, outside the mask, its outer edge
// smoothed over a pixel.

shader_type canvas_item;
render_mode unshaded;

uniform vec4 colour : source_color = vec4(1.0, 0.86, 0.2, 1.0);
// In the window's pixels.
uniform float width = 2.0;
uniform int reach = 4;

float across(vec4 row) {
	return floor((1.0 - row.r) * float(reach + 1) + 0.5);
}

void fragment() {
	vec4 here = texture(TEXTURE, UV);
	if (here.g > 0.5) {
		COLOR = vec4(0.0);
	} else {
		float far = float(reach + 1);
		float nearest = across(here) < far ? across(here) : 1.0e3;
		float step = TEXTURE_PIXEL_SIZE.y;
		for (int y = 1; y <= reach; y++) {
			float dy = float(y);
			if (dy >= nearest) {
				break;
			}
			float dx = min(across(texture(TEXTURE, UV - vec2(0.0, dy * step))),
				across(texture(TEXTURE, UV + vec2(0.0, dy * step))));
			if (dx < far) {
				nearest = min(nearest, length(vec2(dx, dy)));
			}
		}
		COLOR = vec4(colour.rgb, colour.a * clamp(width + 0.5 - nearest, 0.0, 1.0));
	}
}
