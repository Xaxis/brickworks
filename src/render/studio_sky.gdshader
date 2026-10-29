// The studio the product look's plastic reflects and is lit by
// (StudioRender, RenderSettings.look "product"): the softbox panorama with
// its room flagged down, as a product photographer hangs black flags round
// a glossy subject. Its softboxes stay whole, so every highlight is still
// there and crisp.
//
// Without the flags the room (a white cyclorama, a lit floor) is as bright
// as the key light, every glossy face mirrors 4 to 6% of it, and on black,
// whose own colour is 2%, that reflection was three times the plastic: black
// bricks read as mid-grey on the white sweep (docs/RENDERING.md).
shader_type sky;

uniform sampler2D panorama : filter_linear, repeat_enable;
// The panorama's average brought to one (StudioRender.HDRI_LEVEL).
uniform float energy = 1.0;
// How much of the room is left, and from what brightness (times the
// average) a light counts as a softbox and is left whole.
uniform float room = 1.0;
uniform vec2 sources = vec2(2.0, 6.0);

void sky() {
	vec3 light = texture(panorama, SKY_COORDS).rgb * energy;
	float level = dot(light, vec3(0.2126, 0.7152, 0.0722));
	COLOR = light * mix(room, 1.0, smoothstep(sources.x, sources.y, level));
}
