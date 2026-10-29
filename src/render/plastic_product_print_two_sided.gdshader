// plastic_print_two_sided, in the product look (StudioRender): see PLASTIC_PRODUCT in
// plastic_body.gdshaderinc. Only a render's copy of the model draws with it.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

#define PLASTIC_PRINT
#define PLASTIC_PRODUCT

#include "res://src/render/plastic_body.gdshaderinc"
