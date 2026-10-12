// Opaque plastic with no dependable outside, under a cut-away. Its back
// faces are surfaces of the part, so none is taken for a cut face.
//
// One of the cut variants BrickWorld.set_cut swaps in while a cut is on;
// the shading is plastic_body.gdshaderinc's, as for every other variant.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define PLASTIC_CUT

#include "res://src/render/plastic_body.gdshaderinc"
