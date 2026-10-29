// plastic_trans_two_sided, in the product look (StudioRender): see PLASTIC_PRODUCT in
// plastic_body.gdshaderinc. Only a render's copy of the model draws with it.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#define PLASTIC_TRANSPARENT
#define PLASTIC_PRODUCT

#include "res://src/render/plastic_body.gdshaderinc"
