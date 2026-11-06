// The cut-away (SeeInside) as a shader sees it: what it takes off, and the
// face it leaves where it goes through plastic. Included by the plastic's
// _cut variants (plastic_body.gdshaderinc), by the ghosts (see_through) and
// by the selection's outline (outline_mask_cut); set by CutShape.set_into.
//
//   cut_shape 0  the plane cut_plane: what is past it, where
//                dot(xyz, p) > w, is taken off.
//   cut_shape 1  a box, 2 a sphere, 3 a cylinder standing upright, each
//                filling cut_centre ± cut_half: what is inside is taken off.

uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);
uniform int cut_shape = 0;
uniform vec3 cut_centre = vec3(0.0);
uniform vec3 cut_half = vec3(1.0);
// For a probe: the cut's faces drawn magenta and any other inside face of
// a part drawn green, so a picture says which is which (cutshapes_probe).
uniform int cut_marks = 0;

bool cut_away_at(vec3 p) {
	if (cut_shape == 0) {
		return dot(cut_plane.xyz, p) > cut_plane.w;
	}
	vec3 d = (p - cut_centre) / max(cut_half, vec3(0.001));
	if (cut_shape == 2) {
		return dot(d, d) < 1.0;
	}
	if (cut_shape == 3) {
		return d.x * d.x + d.z * d.z < 1.0 && abs(d.y) < 1.0;
	}
	return abs(d.x) < 1.0 && abs(d.y) < 1.0 && abs(d.z) < 1.0;
}

// The face the cut leaves at the plastic the eye sees at p, looking along
// -toward_eye: the shape's surface where the eye's line comes out of what
// is taken off, its normal pointing back into it, towards the eye. A part's
// surfaces are closed, so the eye meets the inside of the plastic, a back
// face, exactly where that line came out of the shape inside it.
vec3 cut_face_normal(vec3 p, vec3 toward_eye) {
	if (cut_shape == 0) {
		return cut_plane.xyz;
	}
	vec3 half_size = max(cut_half, vec3(0.001));
	// In the shape's own measure, where it is a unit box, ball or drum: the
	// line from p back towards the eye, and where it first meets the shape.
	vec3 o = (p - cut_centre) / half_size;
	vec3 v = toward_eye / half_size;
	// The shape's outward normal where the line goes in: the gradient of
	// its measure there, so scaled back out of it.
	vec3 out_of = -toward_eye;
	if (cut_shape == 2) {
		float a = dot(v, v);
		float b = dot(o, v);
		float c = dot(o, o) - 1.0;
		float s = (-b - sqrt(max(b * b - a * c, 0.0))) / max(a, 1.0e-6);
		out_of = (o + v * s) / half_size;
	} else {
		// Where the line goes into each slab; for the drum, also into its
		// round side.
		vec3 safe = vec3(abs(v.x) < 1.0e-6 ? 1.0e-6 : v.x, abs(v.y) < 1.0e-6 ? 1.0e-6 : v.y,
			abs(v.z) < 1.0e-6 ? 1.0e-6 : v.z);
		vec3 enter = min((-1.0 - o) / safe, (1.0 - o) / safe);
		if (cut_shape == 3) {
			float a = v.x * v.x + v.z * v.z;
			float b = o.x * v.x + o.z * v.z;
			float c = o.x * o.x + o.z * o.z - 1.0;
			float side = (-b - sqrt(max(b * b - a * c, 0.0))) / max(a, 1.0e-6);
			if (enter.y >= side) {
				out_of = vec3(0.0, -sign(v.y), 0.0);
			} else {
				vec3 at = o + v * side;
				out_of = vec3(at.x, 0.0, at.z) / half_size;
			}
		} else if (enter.x >= enter.y && enter.x >= enter.z) {
			out_of = vec3(-sign(v.x), 0.0, 0.0);
		} else if (enter.y >= enter.z) {
			out_of = vec3(0.0, -sign(v.y), 0.0);
		} else {
			out_of = vec3(0.0, 0.0, -sign(v.z));
		}
	}
	// The face the cut leaves faces back into the hole, towards the eye.
	return length(out_of) > 0.0 ? -normalize(out_of) : toward_eye;
}
