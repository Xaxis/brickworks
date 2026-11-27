// The traced picture cleaned of its grain, in a browser (photoreal29): the
// spatial half of SVGF (Schied et al. 2017), an a-trous wavelet filter of five
// passes, each a 5 x 5 B3-spline whose holes double (1, 2, 4, 8, 16 pixels),
// so a few samples of a pixel are averaged with those of its own surface
// across some sixty pixels while an edge, a shadow's border or a logo's flank
// is kept. tools/web/tracer_port.py puts it in SHADERS; page_tracer.js draws
// it in bands before the resolve, and the bench (gpu29.py) runs the very same.
//
// Two neighbours are averaged only as far as they are alike in the light (in
// units of the noise the pixel carries), in their albedo (the eye's first
// hit's, which the tracer sums in u_more: a print, a part of another colour, a
// logo's flank keep their edge however noisy the light is), in which way they
// face (u_guide's normals), how far they are (u_more's depth, against the
// slope the pixel's own surface has), and in what they are (plastic, clear
// plastic, the sweep, nothing; and how much of the pixel the model covers).
// The light is not divided by the albedo, as SVGF does: the plastic's clear
// coat reflects white over its colour, and divided by a saturated blue's red
// that reflection came back fifty times over and turned a white print beside
// it pink.
//
// The noise is measured, never assumed: the tracer sums the even samples apart
// (u_even), so each pixel has two halves of its samples, and how far their
// means differ says how much grain its mean carries. Each pass carries that
// variance on as SVGF does (the weights squared), so the last says how much
// grain is left; stage 3 sums it, with the raw halves', over the picture for
// the page to read (PageTracer.noise): Render shows the traced picture only once
// what is left is under what the judge prefers to the raster's.
//
// u_stage: 0 the light and its variance from the sums; 1 one a-trous pass
// (u_step apart); 2 the light times the albedo again, and the coverage;
// 3 the measure, a texel for each 16 x 16 pixels.

uniform highp sampler2D u_accum;
uniform highp sampler2D u_guide;
uniform highp sampler2D u_more;
uniform highp sampler2D u_even;
uniform highp sampler2D u_in;
uniform int u_stage;
uniform int u_step;
uniform ivec2 u_size;
// The samples: x in every row, y more in the rows below z (a block of samples
// part way down the picture, page_tracer.js's row).
uniform vec4 u_counts;
// How hard each edge stops the filter: the light (in its noise's standard
// deviations), the normals' power, the depth (in its slope), and the albedo
// (the linear distance between two that halves the weight's log by one).
uniform vec4 u_tune;
layout(location = 0) out vec4 out_value;

const float KERNEL[3] = float[3](0.375, 0.25, 0.0625);

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

ivec2 inside(ivec2 p) {
	return clamp(p, ivec2(0), u_size - ivec2(1));
}

float count_at(ivec2 p) {
	return max(u_counts.x + (float(p.y) < u_counts.z ? u_counts.y : 0.0), 1.0);
}

vec4 mean_at(ivec2 p) {
	return texelFetch(u_accum, inside(p), 0) / count_at(p);
}

// The albedo of what the eye met: the plastic's own; white where it met clear
// plastic, the sweep or nothing (the tracer writes 1 there).
vec3 albedo_at(ivec2 p) {
	return texelFetch(u_more, inside(p), 0).rgb / count_at(p);
}

float depth_at(ivec2 p) {
	return texelFetch(u_more, inside(p), 0).a / count_at(p);
}

vec3 normal_at(ivec2 p) {
	return normalize(texelFetch(u_guide, inside(p), 0).xyz + vec3(1e-6));
}

// The guide's w: the plastic's albedo's lightness (0 to 1), 2 clear plastic,
// 3 the sweep, 4 nothing; a mean of them where a pixel holds several.
float kind_at(ivec2 p) {
	return texelFetch(u_guide, inside(p), 0).w / count_at(p);
}

// 1 where the pixel's two halves met different things (their mean kinds a
// tenth or more apart), 0 where they met the same; 0 with one sample.
float halves_apart(ivec2 p) {
	float n = count_at(p);
	float even_n = floor((n + 1.0) * 0.5);
	float odd_n = n - even_n;
	if (odd_n < 1.0) {
		return 0.0;
	}
	float even = texelFetch(u_even, inside(p), 0).a;
	float all = texelFetch(u_guide, inside(p), 0).w;
	return min(abs(even / even_n - (all - even) / odd_n) / 0.1, 1.0);
}

// The variance of the pixel's mean light (its luminance) from its two halves:
// the even samples' mean and the odd ones'. With one sample there are no
// halves, and the spread of its 3 x 3 neighbours stands in.
float variance_at(ivec2 p) {
	float n = count_at(p);
	float even_n = floor((n + 1.0) * 0.5);
	float odd_n = n - even_n;
	vec4 sum = texelFetch(u_accum, inside(p), 0);
	if (odd_n >= 1.0) {
		vec4 even = texelFetch(u_even, inside(p), 0);
		float d = lum(even.rgb / even_n - (sum.rgb - even.rgb) / odd_n);
		// The difference of the halves' means carries sigma^2 (1/a + 1/b); the
		// whole mean sigma^2 / n.
		return d * d / (1.0 / even_n + 1.0 / odd_n) / n;
	}
	float s = 0.0;
	float s2 = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float l = lum(mean_at(p + ivec2(x, y)).rgb);
			s += l;
			s2 += l * l;
		}
	}
	s /= 9.0;
	return max(s2 / 9.0 - s * s, 0.0);
}

vec4 prepare(ivec2 p) {
	vec4 centre = mean_at(p);
	// A firefly, far brighter than all eight round it, is taken as their mean
	// (as the desktop's resolve does).
	float brightest = 0.0;
	vec3 round_it = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x != 0 || y != 0) {
				vec3 m = mean_at(p + ivec2(x, y)).rgb;
				brightest = max(brightest, lum(m));
				round_it += m;
			}
		}
	}
	if (lum(centre.rgb) > brightest * 2.0 + 0.05) {
		centre.rgb = round_it / 8.0;
	}
	return vec4(centre.rgb, variance_at(p));
}

vec4 atrous(ivec2 p) {
	vec4 own = texelFetch(u_in, p, 0);
	// The pixel's variance, a 3 x 3 Gaussian of it: one pixel's halves say
	// too little alone.
	float spread = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float k = (x == 0 ? 0.5 : 0.25) * (y == 0 ? 0.5 : 0.25);
			spread += k * texelFetch(u_in, inside(p + ivec2(x, y)), 0).a;
		}
	}
	// How surely the pixels round it are each one surface: the halves of each
	// met the same kind of thing (the guide's w, which tells plastic by its
	// lightness from clear plastic, the sweep and nothing). An edge out of
	// focus is a band of pixels each a mean of the part and what lies behind
	// it from a few samples: some all one, some all the other, by luck. Its
	// guide is as noisy as its light, so there the filter is stopped by the
	// light alone, in units of how the band's light varies, or each pixel
	// kept its own few samples and the blurred edge stayed torn. A sharp
	// edge's band is a pixel wide, a print's line two: a third of these at most.
	float mixed = 0.0;
	float band = 0.0;
	float band2 = 0.0;
	for (int y = -2; y <= 2; y += 2) {
		for (int x = -2; x <= 2; x += 2) {
			mixed += halves_apart(p + ivec2(x, y)) / 9.0;
			float l = lum(texelFetch(u_in, inside(p + ivec2(x, y)), 0).rgb);
			band += l / 9.0;
			band2 += l * l / 9.0;
		}
	}
	float guided = 1.0 - smoothstep(0.3, 0.6, mixed);
	float level = lum(own.rgb);
	float light_stop = u_tune.x * sqrt(max(spread, (1.0 - guided) * max(band2 - band * band, 0.0))) + 1e-4;
	vec3 normal = normal_at(p);
	vec3 albedo = albedo_at(p);
	float depth = depth_at(p);
	float kind = kind_at(p);
	float covered = mean_at(p).a;
	// The depth's slope across the pixel, so a surface seen at a slant is one.
	vec2 slope = vec2(abs(depth_at(p + ivec2(1, 0)) - depth_at(p - ivec2(1, 0))),
		abs(depth_at(p + ivec2(0, 1)) - depth_at(p - ivec2(0, 1)))) * 0.5;
	vec3 total = vec3(0.0);
	float weights = 0.0;
	float carried = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			ivec2 q = p + ivec2(x, y) * u_step;
			if (q.x < 0 || q.y < 0 || q.x >= u_size.x || q.y >= u_size.y) {
				continue;
			}
			vec4 there = texelFetch(u_in, q, 0);
			float h = KERNEL[abs(x)] * KERNEL[abs(y)];
			float w = h;
			if (x != 0 || y != 0) {
				float apart = abs(lum(there.rgb) - level) / light_stop;
				float far = abs(depth_at(q) - depth) / (u_tune.z * dot(slope, abs(vec2(x, y))) * float(u_step)
					+ 0.002 * depth + 1e-3);
				float facing = pow(max(dot(normal, normal_at(q)), 0.0), u_tune.y);
				vec3 tint = (albedo_at(q) - albedo) / u_tune.w;
				// Clear plastic, the sweep and nothing (the guide's 2, 3 and 4) only
				// with their own kind, and the model with what covers as much of
				// the pixel: softly, so an edge out of focus (a mean of both, from
				// a few samples) can still be smoothed along itself.
				float kinds = (kind_at(q) - kind) / 0.5;
				float cover = (mean_at(q).a - covered) / 0.3;
				w *= exp(-apart - guided * (far + dot(tint, tint) + kinds * kinds + cover * cover))
					* mix(1.0, facing, guided);
			}
			total += there.rgb * w;
			weights += w;
			carried += w * w * there.a;
		}
	}
	return vec4(total / weights, carried / (weights * weights));
}

vec4 measure(ivec2 cell) {
	// x: the raw halves' noise, relative to the light, over the model's
	// plastic; y: the same left after the filter; z: the plastic's pixels
	// sampled; w: what is left, summed over every pixel sampled (the page
	// counts those itself: 4 x 4 a cell, inside the picture).
	vec4 out_sum = vec4(0.0);
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			ivec2 p = cell * 16 + ivec2(2 + 4 * x, 2 + 4 * y);
			if (p.x >= u_size.x || p.y >= u_size.y) {
				continue;
			}
			vec4 left = texelFetch(u_in, p, 0);
			float kept = sqrt(max(left.a, 0.0)) / (lum(left.rgb) + 0.02);
			out_sum.w += kept;
			if (kind_at(p) < 1.0) {
				float raw = sqrt(variance_at(p)) / (lum(mean_at(p).rgb) + 0.02);
				out_sum.xyz += vec3(raw, kept, 1.0);
			}
		}
	}
	return out_sum;
}

void main() {
	ivec2 p = ivec2(gl_FragCoord.xy);
	if (u_stage == 3) {
		out_value = measure(p);
		return;
	}
	if (p.x >= u_size.x || p.y >= u_size.y) {
		out_value = vec4(0.0);
		return;
	}
	if (u_stage == 0) {
		out_value = prepare(p);
	} else if (u_stage == 1) {
		out_value = atrous(p);
	} else {
		out_value = vec4(texelFetch(u_in, p, 0).rgb, mean_at(p).a);
	}
}
