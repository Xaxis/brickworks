// Transparent plastic under a cut-away. Clear, so it has no cut face to
// draw: what is past the plane is simply not there.
//
// One of the cut variants BrickWorld.set_cut swaps in while a cut is on;
// the shading is plastic_body.gdshaderinc's, as for every other variant.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#define PLASTIC_TRANSPARENT
#define PLASTIC_CUT

#include "res://src/render/plastic_body.gdshaderinc"
