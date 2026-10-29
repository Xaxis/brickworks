// What clear plastic takes out of the light that passes through it, in the
// product look (StudioRender): the first of a clear part's two passes
// (BrickWorld, a product world's transparent batches), drawn before the
// plastic_product_trans pass that lays its reflections on top.
//
// Every surface of the part multiplies what is behind it by what one
// surface of the plastic lets through, so a ray through a wall is tinted
// once, through a wall and a tube three times, through the brick and out of
// its far side twice: the walls, the tubes and the studs from inside show
// as they do in a real clear brick, deeper in colour where there is more
// plastic, and the floor and anything else behind show through, tinted.
// A multiply does not care what order the surfaces come in, so the part
// needs no sorting and nothing is drawn inside out.
//
// This is what the product glass did before (render342) one layer deep: it
// read the picture behind from the screen, which holds only what is opaque
// (the part's own far walls and tubes were never in it), and drew the
// nearest surface alone over a depth prepass. On a plain sweep that was one
// flat tint, a clear brick that read as solid. And under Compatibility the
// screen read came back as the wrong picture (a pale patch on the sports
// car's windscreen); a multiply reads nothing.

shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// As plastic_body's: whether the instance colour is sRGB to be made linear,
// which is also whether the picture this multiplies is linear (Forward+) or
// already sRGB (Compatibility).
uniform bool linearise = true;
// The part's box and its body's top, as plastic_body has them.
uniform vec3 part_box_min = vec3(0.0);
uniform vec3 part_box_max = vec3(0.0);
uniform float part_body_top = 1.0e9;
// A moulded wall's thickness, LDU: within this of an edge of the part's
// box a ray runs along a wall, through far more plastic than across one.
uniform float wall_ldu : hint_range(0.0, 8.0) = 4.0;
// How many walls' worth more that is, at the edge itself.
uniform float along_wall : hint_range(0.0, 4.0) = 1.5;

varying vec3 tint;
varying flat float finish;
varying vec3 local_position;

void vertex() {
	vec3 c = COLOR.rgb;
	bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
	tint = mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, vec3(cutoff));
	finish = INSTANCE_CUSTOM.a;
	local_position = VERTEX;
}

void fragment() {
	// Plain clear plastic, trans-neon and glitter are glass; opal, milky,
	// glow and the rest scatter, and plastic_product_trans blends them over
	// what is behind as it always did.
	int kind = int(floor(finish + 0.001));
	if (kind != 0 && kind != 5 && kind != 8) {
		ALBEDO = vec3(1.0);
	} else {
		// The light bends towards the surface's normal going in (ABS, about
		// 1.5), so even a wall seen edge-on is crossed at under 48 degrees:
		// its path is at most a third longer than straight through.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float inside = sqrt(1.0 - (1.0 - facing * facing) / 2.25);
		// LDConfig gives a clear colour as one wall of it looks against
		// white: two surfaces, each letting through its square root.
		float walls = 0.5 / inside;
		vec3 low = part_box_min;
		vec3 high = vec3(part_box_max.x, min(part_box_max.y, part_body_top), part_box_max.z);
		vec3 size = high - low;
		if (size.x > 0.0 && size.y > 0.0 && size.z > 0.0) {
			vec3 d = min(local_position - low, high - local_position);
			float nearest = min(d.x, min(d.y, d.z));
			float furthest = max(d.x, max(d.y, d.z));
			float second = d.x + d.y + d.z - nearest - furthest;
			walls *= 1.0 + along_wall * (1.0 - smoothstep(0.0, wall_ldu, second));
		}
		vec3 through = pow(max(tint, vec3(0.0005)), vec3(walls));
		// On sRGB, what multiplies a value is about its linear factor to
		// the 1/2.2.
		ALBEDO = linearise ? through : pow(through, vec3(1.0 / 2.2));
	}
}
