// The path tracer's running sum as a picture (PathTracer): the mean of the
// samples, exposed and tone-mapped exactly as the window's own picture is
// (Godot's tonemap.glsl: ACES, or Filmic with the product look's contrast
// and saturation after it), turned to sRGB with a step of noise so a
// sweep's fall from white to grey is grain rather than bands.
//
// The product look's picture is also cleaned of the samples' grain first
// (photoreal1): a photograph has none of a path tracer's sparkle, and a blind
// judge named it in nearly every render beside a photograph. Each pixel is
// the weighted mean of its neighbours within three pixels, each weighed by
// how far it is (two pixels' fall) and by how unlike the pixel it is in the
// units of the noise a mean of this many samples carries (proportional to its
// level, over the root of the samples), so an edge, a logo's flank or a
// shadow's border, unlike by many times the noise, is kept, and a flat face's
// grain is averaged out. A pixel far brighter than all eight round it (a
// firefly) is first taken as their mean. Nothing round the model and the
// model never mix (the coverage differs).
//
// Then the camera's own marks, for the product look on a backdrop
// (photoreal4): its lens's fall-off to the corners, its colour fringes, and
// its sensor's noise, each as much as the photograph it is matched to has.

#[compute]

#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D accum;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D picture;
// The eye's first hit in each pixel, summed (path_tracer.glsl's guide): its
// normal, and its albedo's lightness or what it is.
layout(set = 0, binding = 2, rgba32f) uniform readonly image2D guide;

layout(push_constant, std430) uniform Resolve {
	float samples;
	float exposure;
	float white;
	// 2 Filmic, 3 ACES, 4 a camera's (camera_curve, white the light drawn white).
	float tonemapper;
	float contrast;
	float saturation;
	// 1 for a picture with nothing behind the model.
	float transparent;
	float dither;
	// How much grain a sample carries, relative to its level; 0 for none
	// taken out (the window look, whose Best is as it was).
	float denoise;
	// The camera's saturation in linear light, before its curve (4 alone).
	float linear_saturation;
	// The product look's camera on a backdrop (photoreal4): its sensor's
	// noise in 8-bit levels at mid grey, the share of the light its lens loses
	// at a corner, and its colour fringes in pixels at a corner. 0 for none.
	float grain;
	float vignette;
	float aberration;
	// How soft its lens draws an edge (0 the picture's own pixels, 1 a third
	// of a pixel's light spread to its neighbours).
	float softness;
	float unused_b;
	float unused_c;
} params;

vec3 filmic_curve(vec3 x) {
	const float bias = 2.0;
	const float A = 0.22 * bias * bias;
	const float B = 0.30 * bias;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.01;
	const float F = 0.30;
	return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 aces_curve(vec3 color) {
	const float bias = 1.8;
	const float A = 0.0245786;
	const float B = 0.000090537;
	const float C = 0.983729;
	const float D = 0.432951;
	const float E = 0.238081;
	const mat3 rgb_to_rrt = mat3(
			vec3(0.59719 * bias, 0.35458 * bias, 0.04823 * bias),
			vec3(0.07600 * bias, 0.90834 * bias, 0.01566 * bias),
			vec3(0.02840 * bias, 0.13383 * bias, 0.83777 * bias));
	const mat3 odt_to_rgb = mat3(
			vec3(1.60475, -0.53108, -0.07367),
			vec3(-0.10208, 1.10813, -0.00605),
			vec3(-0.00327, -0.07276, 1.07602));
	color *= rgb_to_rrt;
	vec3 mapped = (color * (color + A) - B) / (color * (C * color + D) + E);
	return mapped * odt_to_rgb;
}

float aces_white(float white) {
	const float A = 0.0245786;
	const float B = 0.000090537;
	const float C = 0.983729;
	const float D = 0.432951;
	const float E = 0.238081;
	float w = white * 1.8;
	return (w * (w + A) - B) / (w * (C * w + D) + E);
}

// A camera's response (photoreal2), for the product look on a backdrop: the
// light in proportion up to its knee, as a photograph's JPEG has it, then a
// shoulder that reaches white at CAMERA_TOP times white, so a lit red face
// keeps its shading rather than clipping flat (as a phone's picture of one
// does). StudioRender._toned is the same curve; its CAMERA_KNEE and
// CAMERA_TOP are these. Filmic drew a 50% grey near white: its shoulder
// starts in the middle tones.
const float CAMERA_KNEE = 0.6;
const float CAMERA_TOP = 2.5;
vec3 camera_curve(vec3 color) {
	vec3 t = clamp((color - vec3(CAMERA_KNEE)) / (CAMERA_TOP - CAMERA_KNEE), vec3(0.0), vec3(1.0));
	vec3 rolled = vec3(CAMERA_KNEE) + (1.0 - CAMERA_KNEE) * (2.0 * t - t * t);
	return mix(color, rolled, step(vec3(CAMERA_KNEE), color));
}

vec3 linear_to_srgb(vec3 color) {
	const vec3 a = vec3(0.055);
	return mix((vec3(1.0) + a) * pow(color, vec3(1.0 / 2.4)) - a, 12.92 * color,
		lessThan(color, vec3(0.0031308)));
}

float noise(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 mean_at(ivec2 p, ivec2 size) {
	return imageLoad(accum, clamp(p, ivec2(0), size - ivec2(1))) / max(params.samples, 1.0);
}

vec4 guide_at(ivec2 p, ivec2 size) {
	vec4 g = imageLoad(guide, clamp(p, ivec2(0), size - ivec2(1))) / max(params.samples, 1.0);
	return vec4(normalize(g.xyz + vec3(1e-6)), g.w);
}

vec4 cleaned(ivec2 pixel, ivec2 size) {
	vec4 centre = mean_at(pixel, size);
	vec4 own = guide_at(pixel, size);
	float brightest = 0.0;
	vec4 round_it = vec4(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) {
				continue;
			}
			vec4 m = mean_at(pixel + ivec2(x, y), size);
			brightest = max(brightest, luma(m.rgb));
			round_it += m;
		}
	}
	if (luma(centre.rgb) > brightest * 2.0 + 0.05) {
		centre = round_it / 8.0;
	}
	float noise_here = params.denoise / sqrt(max(params.samples, 1.0));
	float level = luma(centre.rgb);
	vec4 total = centre;
	float weights = 1.0;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			if (x == 0 && y == 0) {
				continue;
			}
			vec4 m = mean_at(pixel + ivec2(x, y), size);
			float spread = noise_here * (max(level, luma(m.rgb)) + 0.03);
			vec3 unlike = (m.rgb - centre.rgb) / spread;
			float w = exp(-0.5 * dot(unlike, unlike) - float(x * x + y * y) / 8.0);
			w *= step(abs(m.a - centre.a), 0.25);
			// Guided (photoreal3): a neighbour on a surface turned another way
			// (a grain's bump, a logo's flank, a clear part's edge) or of another
			// albedo is not grain of the same light, and is kept apart.
			vec4 g = guide_at(pixel + ivec2(x, y), size);
			float turned = max(1.0 - dot(own.xyz, g.xyz), 0.0);
			float other = (g.w - own.w) / 0.03;
			w *= exp(-turned / 0.01 - 0.5 * other * other);
			total += m * w;
			weights += w;
		}
	}
	return total / weights;
}

// A sample of the picture's mean light at a pixel, cleaned as the look asks.
vec4 light_at(ivec2 pixel, ivec2 size) {
	return params.denoise > 0.0 ? cleaned(pixel, size)
		: imageLoad(accum, clamp(pixel, ivec2(0), size - ivec2(1))) / max(params.samples, 1.0);
}

// A normal deviate from two hashes of the pixel (Box-Muller), for a sensor's
// noise: each pixel and channel its own, the same for the same picture.
float gaussian(vec2 p, float salt) {
	float u = max(noise(p + vec2(salt, 3.1 * salt)), 1e-6);
	float v = noise(p * 1.37 + vec2(17.3 + salt, 5.7));
	return sqrt(-2.0 * log(u)) * cos(6.2831853 * v);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(picture);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	vec4 sum = light_at(pixel, size);
	if (params.softness > 0.0) {
		// A real lens and a camera's pipeline spread each point a little: an
		// edge is a pixel's soft step, never a render's exact one.
		vec4 round_it = vec4(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				if (x != 0 || y != 0) {
					round_it += light_at(pixel + ivec2(x, y), size) * (x == 0 || y == 0 ? 0.75 : 0.25);
				}
			}
		}
		sum = mix(sum, round_it / 4.0, params.softness / 3.0);
	}
	// Where the pixel is from the middle, 1 at a corner: a lens's fall-off and
	// its fringes grow towards the edge of the frame (photoreal4).
	vec2 from_middle = (vec2(pixel) + 0.5 - vec2(size) * 0.5) / (length(vec2(size)) * 0.5);
	if (params.aberration > 0.0) {
		// Lateral colour: red drawn a little larger than green, blue a little
		// smaller, so an edge near a corner has a fringe of each.
		ivec2 shift = ivec2(round(from_middle * params.aberration));
		if (shift != ivec2(0)) {
			sum.r = light_at(pixel - shift, size).r;
			sum.b = light_at(pixel + shift, size).b;
		}
	}
	vec3 color = max(sum.rgb * params.exposure, vec3(0.0));
	// A lens's fall-off towards the corners (cos^4, as a share at a corner).
	color *= 1.0 - params.vignette * dot(from_middle, from_middle);
	if (params.tonemapper > 3.5) {
		// A camera's colour, saturated in linear light as its colour matrix
		// does, round the light's own luminance.
		float level = luma(color);
		color = max(vec3(level) + (color - vec3(level)) * params.linear_saturation, vec3(0.0));
		color = camera_curve(color / params.white);
	} else if (params.tonemapper > 2.5) {
		color = aces_curve(color) / aces_white(params.white);
	} else {
		color = filmic_curve(color) / filmic_curve(vec3(params.white)).x;
	}
	color = linear_to_srgb(clamp(color, vec3(0.0), vec3(1.0)));
	color = mix(vec3(0.5), color, params.contrast);
	color = mix(vec3(dot(vec3(1.0), color) * (1.0 / 3.0)), color, params.saturation);
	float n = noise(vec2(pixel)) + noise(vec2(pixel) + 41.7) - 1.0;
	color += vec3(n * params.dither / 255.0);
	if (params.grain > 0.0) {
		// A sensor's noise after its pipeline: mostly in lightness, a little in
		// colour; largest in the middle tones, none on a white that is white
		// (a cut-out's paper stays paper) and less in the deepest black.
		float level = luma(color);
		float amount = params.grain / 255.0 * (1.0 - pow(level, 6.0)) * (0.35 + 0.65 * sqrt(level));
		vec2 at = vec2(pixel);
		float lightness = gaussian(at, 0.0);
		vec3 tint = vec3(gaussian(at, 7.0), gaussian(at, 13.0), gaussian(at, 29.0));
		color += amount * (vec3(lightness) + 0.35 * tint);
	}
	float alpha = params.transparent > 0.5 ? clamp(sum.a, 0.0, 1.0) : 1.0;
	imageStore(picture, pixel, vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha));
}
