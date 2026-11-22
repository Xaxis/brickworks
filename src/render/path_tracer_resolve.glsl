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

#[compute]

#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D accum;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D picture;

layout(push_constant, std430) uniform Resolve {
	float samples;
	float exposure;
	float white;
	// 2 Filmic, 3 ACES.
	float tonemapper;
	float contrast;
	float saturation;
	// 1 for a picture with nothing behind the model.
	float transparent;
	float dither;
	// How much grain a sample carries, relative to its level; 0 for none
	// taken out (the window look, whose Best is as it was).
	float denoise;
	float unused_a;
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

vec4 cleaned(ivec2 pixel, ivec2 size) {
	vec4 centre = mean_at(pixel, size);
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
			total += m * w;
			weights += w;
		}
	}
	return total / weights;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(picture);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	vec4 sum = params.denoise > 0.0 ? cleaned(pixel, size)
		: imageLoad(accum, pixel) / max(params.samples, 1.0);
	vec3 color = max(sum.rgb * params.exposure, vec3(0.0));
	if (params.tonemapper > 2.5) {
		color = aces_curve(color) / aces_white(params.white);
	} else {
		color = filmic_curve(color) / filmic_curve(vec3(params.white)).x;
	}
	color = linear_to_srgb(clamp(color, vec3(0.0), vec3(1.0)));
	color = mix(vec3(0.5), color, params.contrast);
	color = mix(vec3(dot(vec3(1.0), color) * (1.0 / 3.0)), color, params.saturation);
	float n = noise(vec2(pixel)) + noise(vec2(pixel) + 41.7) - 1.0;
	color += vec3(n * params.dither / 255.0);
	float alpha = params.transparent > 0.5 ? clamp(sum.a, 0.0, 1.0) : 1.0;
	imageStore(picture, pixel, vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha));
}
