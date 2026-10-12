// A frame copied exactly, alpha and all: the first of Best's frames, kept
// for the others to be measured against (studio_sum).
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D frame_tex : filter_nearest, repeat_disable;

void fragment() {
	COLOR = texture(frame_tex, UV);
}
