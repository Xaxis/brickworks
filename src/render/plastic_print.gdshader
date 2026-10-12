// Opaque plastic with a print on it: a picture drawn in the print designer
// (PartPrints), laid on by the surface's texture coordinates. Only the
// faces under a print are drawn with this; the rest of the part is plain
// plastic.gdshader.
//
// The shading itself lives in plastic_body.gdshaderinc so these
// variants cannot drift apart; a shader's render_mode is fixed at
// compile time, which is the only reason there is more than one file.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#define PLASTIC_PRINT

#include "res://src/render/plastic_body.gdshaderinc"
