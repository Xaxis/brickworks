// Printed plastic under a cut-away, its cut faces drawn as plastic_cut
// draws them.
//
// One of the cut variants BrickWorld.set_cut swaps in while a cut is on;
// the shading is plastic_body.gdshaderinc's, as for every other variant.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define PLASTIC_PRINT
#define PLASTIC_CUT
#define PLASTIC_CAP

#include "res://src/render/plastic_body.gdshaderinc"
