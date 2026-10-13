// The ground under a model with no baseplate (FloorLayer): not drawn, but
// the sun's shadow falls on it.
//
// Lit by the sun alone and its own ambient, in a grey that matches the
// view's background where the sun reaches it, so only the shadow shows;
// and faded out round the model, so it never has an edge, wherever the
// background the eye sees through it is lighter or darker.
//
// Godot's shadow to opacity would be the obvious way. It reads the least
// light any light leaves, and in the Compatibility renderer, which the web
// build runs on, it left the plane clear everywhere: measured, not a pixel
// changed.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;

// Measured against the view's background (main.tscn's sky below the
// horizon, 0.563 grey): 0.52 left the ground 0.007 darker and 0.56 0.016
// lighter. At 0.9 the shadow is about 0.09 darker than what is round it.
uniform vec3 tint : source_color = vec3(0.53, 0.53, 0.54);
uniform float strength = 0.9;
uniform vec2 middle = vec2(0.0);
uniform float near_radius = 100.0;
uniform float far_radius = 300.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = tint;
	float away = distance(world.xz, middle);
	ALPHA = strength * (1.0 - smoothstep(near_radius, far_radius, away));
}
