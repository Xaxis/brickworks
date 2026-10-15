// Every part a flat colour that is its own number, culled to its outside as
// plastic.gdshader is: see seen_codes.gdshaderinc.

shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix, fog_disabled;

#include "res://src/render/seen_codes.gdshaderinc"
