// The selection's mask for SelectionOutline: its parts in plain white, in a
// world of their own, through the view's camera. Unlit and both sides.
//
// Depth-tested, though only where they are on screen matters: the mask's
// world holds the selection alone, so what is in front is only more of it,
// and a fragment behind is not drawn at all. Without the test every layer of
// a big selection was drawn over the last: all of Orthanc is hundreds deep
// through the tower, and drawn in software that was most of a frame.
//
// No discard either, which would cost the early depth test: what is past a
// cut is taken off by outline_mask_cut.gdshader, swapped in while there is one.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

void fragment() {
	ALBEDO = vec3(1.0);
}
