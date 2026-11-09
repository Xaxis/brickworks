// A ghost's next pass: the part drawn faint where the model hides it.
//
// Strengthen's pin goes into two holes, and its prop stands under a plate:
// drawn as ghost.gdshader alone, behind the parts round it, a person sees
// nothing of the fix that was offered. So the hidden part is drawn over
// them, faintly, in the part's own colour, as an X-ray shows a part inside.

shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_disabled, cull_back, unshaded;

uniform vec3 tint : source_color = vec3(0.7, 0.1, 0.1);

void fragment() {
	ALBEDO = tint;
	ALPHA = 0.32;
}
