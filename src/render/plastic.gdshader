// Opaque plastic, one sided. The default: LDraw certifies the winding
// of almost every part, so there is a dependable outside to cull to.
//
// The shading itself lives in plastic_body.gdshaderinc so these
// variants cannot drift apart; a shader's render_mode is fixed at
// compile time, which is the only reason there is more than one file.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://src/render/plastic_body.gdshaderinc"
