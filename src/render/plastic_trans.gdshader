// Transparent plastic: windscreens, windows, light covers, the whole
// trans- palette. A depth prepass is what stops a part's own back face
// sorting over its front and making it look inside-out.
//
// The shading itself lives in plastic_body.gdshaderinc so these
// variants cannot drift apart; a shader's render_mode is fixed at
// compile time, which is the only reason there is more than one file.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#define PLASTIC_TRANSPARENT

#include "res://src/render/plastic_body.gdshaderinc"
