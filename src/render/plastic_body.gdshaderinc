// Shared body of the plastic shaders. Included by plastic.gdshader and
// plastic_two_sided.gdshader, which differ only in their cull mode: a
// shader's render_mode is fixed at compile time, so a part whose source
// is not BFC certified — and therefore has no reliable outside — needs
// its own shader rather than a flag.

// Moulded ABS sits around here; tuned against photographs of real bricks
// under a softbox rather than picked for looks.
uniform float base_roughness : hint_range(0.0, 1.0) = 0.28;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.06;
uniform float specular_level : hint_range(0.0, 1.0) = 0.5;
uniform float sheen_strength : hint_range(0.0, 2.0) = 0.65;

// Light colours scatter a little light under the surface, which is why a
// white brick never reads as pure white in shadow.
uniform float subsurface : hint_range(0.0, 1.0) = 0.12;

// Crevice darkening. Stud roots and the gaps between bricks hold a little
// shadow that a direct light cannot reach.
uniform float cavity_strength : hint_range(0.0, 1.0) = 0.35;

// Whether the instance colour needs converting from sRGB to linear here.
// The two renderers disagree about what they are handed: under Forward+
// the conversion belongs in the shader, and doing it again under
// Compatibility darkens every part. Set from the renderer at startup, so
// a brick is the same colour on the desktop and on the web.
uniform bool linearise = true;

// A colour supplied directly, for the times a part is drawn as a single
// MeshInstance rather than through a MultiMesh — the parts bin previews.
// There is no instance colour on that path, and COLOR would fall back to
// the vertex colour attribute, which these meshes do not carry: the part
// would render black. A negative red means "not set, use COLOR".
uniform vec4 tint_override = vec4(-1.0, 0.0, 0.0, 1.0);

varying vec3 instance_color;
varying vec3 view_normal;

vec3 srgb_to_linear(vec3 c) {
	// The exact piecewise transfer function, not a 2.2 power approximation:
	// the approximation visibly lifts dark greys, and bricks use a lot of
	// dark grey.
	bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
	vec3 low = c / 12.92;
	vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, vec3(cutoff));
}

void vertex() {
	vec3 source = tint_override.r >= 0.0 ? tint_override.rgb : COLOR.rgb;
	instance_color = linearise ? srgb_to_linear(source) : source;
	view_normal = NORMAL;
}

void fragment() {
	ALBEDO = instance_color;

	// Roughness rises slightly towards the silhouette: grazing light picks
	// up the fine tooling texture that a head-on view does not resolve.
	float facing = abs(dot(normalize(view_normal), vec3(0.0, 0.0, 1.0)));
	ROUGHNESS = base_roughness + roughness_variation * (1.0 - facing);
	SPECULAR = specular_level;
	METALLIC = 0.0;

	// Dielectric sheen towards the edges.
	float fresnel = pow(1.0 - facing, 5.0);
	SPECULAR += sheen_strength * fresnel * 0.1;

	// A cheap stand-in for occlusion in the crevices: surfaces pointing
	// away from up catch less bounced light.
	float upness = dot(normalize(NORMAL), vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5;
	AO = mix(1.0 - cavity_strength, 1.0, upness);
	AO_LIGHT_AFFECT = 0.4;

	// Pale plastics scatter; dark ones absorb. Keying the amount to
	// luminance gets that for free instead of needing a per-colour flag.
	float luminance = dot(instance_color, vec3(0.2126, 0.7152, 0.0722));
	BACKLIGHT = vec3(subsurface * luminance);

#ifdef PLASTIC_TRANSPARENT
	// Transparent ABS is glassy, not frosted: it is moulded in the same
	// tool as opaque plastic and polished the same way, so it keeps the
	// roughness and gains transmission.
	//
	// The alpha rides in on the instance colour, which carries the
	// palette's own ALPHA value for the colour the part is placed in.
	// Edge-on the sheet transmits less, the way real glazing does, so the
	// silhouette of a windscreen reads instead of vanishing.
	float base_alpha = tint_override.r >= 0.0 ? tint_override.a : COLOR.a;
	float edge = pow(1.0 - facing, 3.0);
	ALPHA = clamp(base_alpha + edge * (1.0 - base_alpha) * 0.8, 0.0, 1.0);
	ROUGHNESS = base_roughness * 0.55;
	// Light that makes it through picks up the tint on the way.
	BACKLIGHT = instance_color * 0.35;
	AO = 1.0;
#endif
}
