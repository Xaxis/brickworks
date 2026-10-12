// Best's average of many frames, one frame at a time (StudioRender).
//
// Two buffers take turns: each frame is added to what the other holds.
// A viewport cleared once and then drawn over was the obvious way and is
// not one: every viewport is cleared whenever it is drawn, whatever its
// clear mode says, on both renderers (measured: after 64 frames it held
// the last frame's 1/64th).
//
// What is summed is each frame's difference from the first. The desktop's
// float buffers are half floats, and 64 sixty-fourths of a grey added up
// in half floats came out 0.502 where it should be 0.51, two steps of an
// 8-bit picture; the differences are mostly nothing, and nothing adds up
// exactly. Where the buffers are 8-bit (a browser without float targets)
// the frames are blended into a running mean instead, which loses at most
// a step or so.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D frame_tex : filter_nearest, repeat_disable;
uniform sampler2D base_tex : filter_nearest, repeat_disable;
uniform sampler2D sum_tex : filter_nearest, repeat_disable;
uniform bool floats = true;
uniform bool first = true;
// 1/N for a sum, 1/(k+1) for the running mean.
uniform float weight = 1.0;

void fragment() {
	vec4 f = texture(frame_tex, UV);
	if (floats) {
		vec4 s = first ? vec4(0.0) : texture(sum_tex, UV);
		COLOR = s + (f - texture(base_tex, UV)) * weight;
	} else {
		vec4 s = first ? f : texture(sum_tex, UV);
		COLOR = mix(s, f, weight);
	}
}
