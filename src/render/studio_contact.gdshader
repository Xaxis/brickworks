// The model's contact shadow on the floor (StudioRender).
//
// Where a model meets the ground it darkens it, most where it touches and
// less the higher above it a part is: what a photograph shows under
// anything standing on a sweep, and what a light's shadow cannot, since it
// falls to one side. Drawn from three silhouettes of the model seen from
// below: what is within a plate of the floor, within a brick or two, and
// within a few bricks, each blurred in proportion and laid on top of one
// another. The same on both renderers, and over a transparent background
// it is a shadow on nothing, which a page can put on any colour.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D near_tex : filter_linear, repeat_disable;
uniform sampler2D mid_tex : filter_linear, repeat_disable;
uniform sampler2D far_tex : filter_linear, repeat_disable;
uniform vec3 strength = vec3(0.55, 0.32, 0.22);
// The side of the square the silhouettes cover, in LDU, centred here.
uniform float span = 1000.0;

varying vec2 at;

void vertex() {
	// Seen from below, the picture's right is +x and its top is +z.
	at = vec2(VERTEX.x / span + 0.5, 0.5 - VERTEX.z / span);
}

// A tent of nine taps, a texel each way: a silhouette made small and
// stretched back over the floor is a staircase of bilinear diamonds
// otherwise.
float soft(sampler2D t, vec2 uv) {
	vec2 px = 1.0 / vec2(textureSize(t, 0));
	float s = texture(t, uv).a * 4.0;
	s += (texture(t, uv + vec2(px.x, 0.0)).a + texture(t, uv - vec2(px.x, 0.0)).a
		+ texture(t, uv + vec2(0.0, px.y)).a + texture(t, uv - vec2(0.0, px.y)).a) * 2.0;
	s += texture(t, uv + px).a + texture(t, uv - px).a
		+ texture(t, uv + vec2(px.x, -px.y)).a + texture(t, uv + vec2(-px.x, px.y)).a;
	return s / 16.0;
}

void fragment() {
	float inside = step(0.0, at.x) * step(at.x, 1.0) * step(0.0, at.y) * step(at.y, 1.0);
	float lit = (1.0 - strength.x * soft(near_tex, at))
		* (1.0 - strength.y * soft(mid_tex, at))
		* (1.0 - strength.z * soft(far_tex, at));
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - lit) * inside;
}
