// Shared body of the plastic shaders. Included by plastic.gdshader and
// its variants, which differ only in cull mode and whether they write
// ALPHA — a shader fixes both at compile time, which is the only reason
// there is more than one file.
//
// ABS plastic, as bricks are actually moulded. Three things separate
// plastic that reads as plastic from plastic that reads as painted
// cardboard, and all three are cheap:
//
//   Sheen at grazing angles. ABS is a dielectric, so its reflectance
//   climbs sharply towards the silhouette. Without it a brick looks flat
//   however the roughness is tuned.
//
//   Roughness that varies. A moulded surface is not uniformly glossy:
//   the top of a stud is polished by the tool, the walls carry faint
//   draw marks. A touch of variation stops the highlight reading as a
//   sticker.
//
//   Colour in linear space. LDConfig values are sRGB; feeding them
//   straight to a physically based renderer washes every part out.
//
// The angles all come from the fragment stage. An earlier version took
// NORMAL in vertex() and compared it against a fixed axis, which is a
// model-space vector measured against a view-space direction: the
// shading then turned with the brick instead of with the camera, and
// every part came out flat and muddy with its studs barely readable.

uniform float base_roughness : hint_range(0.0, 1.0) = 0.22;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.10;
uniform float specular_level : hint_range(0.0, 1.0) = 0.5;

// Light colours scatter a little under the surface, which is why a white
// brick never reads as pure white in shadow.
uniform float subsurface : hint_range(0.0, 1.0) = 0.10;

// Whether the instance colour needs converting from sRGB to linear here.
// The two renderers disagree about what they are handed: under Forward+
// the conversion belongs in the shader, and doing it again under
// Compatibility darkens every part.
uniform bool linearise = true;

// A colour supplied directly, for when a part is drawn as a single
// MeshInstance rather than through a MultiMesh — the parts bin previews.
// There is no instance colour on that path and COLOR would fall back to
// the vertex colour attribute, which these meshes do not carry, so the
// part would render black. A negative red means "not set, use COLOR".
uniform vec4 tint_override = vec4(-1.0, 0.0, 0.0, 1.0);

varying vec3 instance_color;

vec3 srgb_to_linear(vec3 c) {
	// The exact piecewise transfer function, not a 2.2 power: the
	// approximation visibly lifts dark greys, and bricks use a lot of
	// dark grey.
	bvec3 cutoff = lessThanEqual(c, vec3(0.04045));
	vec3 low = c / 12.92;
	vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, vec3(cutoff));
}

void vertex() {
	vec3 source = tint_override.r >= 0.0 ? tint_override.rgb : COLOR.rgb;
	instance_color = linearise ? srgb_to_linear(source) : source;
}

void fragment() {
	ALBEDO = instance_color;
	METALLIC = 0.0;

	// How square-on this surface is to the eye. Both vectors are in view
	// space here, which is what makes the result mean anything.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float grazing = 1.0 - facing;

	// Grazing light picks up the fine tooling texture a head-on view does
	// not resolve.
	ROUGHNESS = base_roughness + roughness_variation * grazing;

	// Dielectric sheen towards the silhouette. This is the edge light
	// that makes a stud read as a cylinder rather than a smudge.
	SPECULAR = specular_level + 0.35 * pow(grazing, 4.0);

	// Pale plastics scatter, dark ones absorb; keying the amount to
	// luminance gets that without a per-colour flag.
	float luminance = dot(instance_color, vec3(0.2126, 0.7152, 0.0722));
	BACKLIGHT = vec3(subsurface * luminance);

#ifdef PLASTIC_TRANSPARENT
	// Transparent ABS is glassy, not frosted: moulded in the same tool as
	// opaque plastic and polished the same way, so it keeps the roughness
	// and gains transmission. Edge-on it transmits less, the way real
	// glazing does, so a windscreen's silhouette reads instead of
	// vanishing.
	float base_alpha = tint_override.r >= 0.0 ? tint_override.a : COLOR.a;
	ALPHA = clamp(base_alpha + pow(grazing, 3.0) * (1.0 - base_alpha) * 0.85, 0.0, 1.0);
	ROUGHNESS = base_roughness * 0.4;
	BACKLIGHT = instance_color * 0.4;
#endif
}
