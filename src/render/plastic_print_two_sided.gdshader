// A print on faces whose part is not back-face certified: see
// plastic_print.gdshader and plastic_two_sided.gdshader.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define PLASTIC_PRINT

#include "res://src/render/plastic_body.gdshaderinc"
