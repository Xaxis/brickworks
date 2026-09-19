// Transparent plastic without a certified winding.
//
// The shading itself lives in plastic_body.gdshaderinc so these
// variants cannot drift apart; a shader's render_mode is fixed at
// compile time, which is the only reason there is more than one file.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#define PLASTIC_TRANSPARENT

#include "res://src/render/plastic_body.gdshaderinc"
