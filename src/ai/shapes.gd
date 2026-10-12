## A solid said as a shape, laid in the parts a set builder would choose.
##
## The car built for the held-out benchmark was told, every check, to use
## wedge plates, curved slopes and a hinged section, and used none of them:
## its body was plates stacked square. The roadmap's rule held a sixth time
## — words move nothing; one call shaped like the work does. A rocket had
## that call (the round pattern) and came out round. A car, a hull, a bird
## and a fuselage had nothing, so a design built them as boxes.
##
## So a design says the solid and this lays it:
##
##   loft      cross-sections along an axis, each a rounded box or an
##             ellipse that can narrow to a keel — a hull, a car's body, a
##             fuselage, an animal's body
##   extrude   a side profile pulled across a width — a car seen from the
##             side, a wing's section
##   revolve   a profile turned about an axis
##   box       with its plan corners rounded or cut and its top edges rounded
##   ellipsoid and dome
##
## any number of them together ("solids", each with its own colour if it
## wants one), less any number taken away ("cuts": a wheel arch, a cockpit).
## Coordinates are studs across and along and plates up, from "at".
##
## The parts are chosen the way a builder chooses them, by what each part of
## the surface is doing:
##
##   the core       bricks where a whole course is inside, plates where the
##                  surface passes through a course, in a bond
##   a step         where the top falls two plates or more from one stud to
##                  the next, a slope on the lower stud against the higher,
##                  as long as the flat beyond it: a cheese slope for one
##                  stud, a curved slope two plates tall for a step of two,
##                  and for a taller one 45, 33 or 18 degrees for two, three
##                  or four studs, on a plate or a brick to make up the step —
##                  curved for a rounded shape, straight for a chamfered one
##   an overhang    where the foot steps up as far, an inverted slope under it
##   a plan edge    on a diagonal, wedge plates in the plate layers
##   the top        tiles, so a body reads as a surface and not as studs
##   a flat side    every other course, bricks with studs on their side and a
##                  tile laid flat on them, as a set's flank is
##   two sides      a shape that is its own mirror is laid as one half and
##                  its mirror, tied across the middle by parts that span it,
##                  so a left wing is never a stud out from a right one
##
## Nothing here knows what a car is.
class_name Shapes
extends RefCounted

## The kinds of solid a shape is made of.
const KINDS: Array[String] = ["loft", "extrude", "revolve", "box", "ellipsoid", "dome"]

## Studs to plates: a stud is 20 LDU across, a plate 8 high.
const PLATES_PER_STUD := 2.5

## A shape that would sample more plate-cells than this is a mistake in the
## numbers (sixty studs by sixty by forty plates is 144,000).
const MOST_CELLS := 160000

## Which way is out, by quarter turn: a slope at rot 0 descends towards +z.
const OUT: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1),
	Vector2i(-1, 0)]

## The core's bricks and plates, largest first: hidden inside a body, where
## the fill's short bricks (kept short so a castle wall has texture) only
## multiply the parts. Laid with these the four held-out bodies came to a
## third fewer parts.
const CORE_BRICKS: Array = [
	[8, 2, "3007", 0], [2, 8, "3007", 1], [6, 2, "2456", 0], [2, 6, "2456", 1],
	[4, 2, "3001", 0], [2, 4, "3001", 1], [3, 2, "3002", 0], [2, 3, "3002", 1],
	[2, 2, "3003", 0], [8, 1, "3008", 0], [1, 8, "3008", 1], [6, 1, "3009", 0],
	[1, 6, "3009", 1], [4, 1, "3010", 0], [1, 4, "3010", 1], [3, 1, "3622", 0],
	[1, 3, "3622", 1], [2, 1, "3004", 0], [1, 2, "3004", 1], [1, 1, "3005", 0],
]
const CORE_PLATES: Array = [
	[8, 6, "3036", 0], [6, 8, "3036", 1], [8, 4, "3035", 0], [4, 8, "3035", 1],
	[6, 6, "3958", 0], [6, 4, "3032", 0], [4, 6, "3032", 1], [8, 2, "3034", 0],
	[2, 8, "3034", 1], [4, 4, "3031", 0], [6, 2, "3795", 0], [2, 6, "3795", 1],
	[4, 2, "3020", 0], [2, 4, "3020", 1], [3, 2, "3021", 0], [2, 3, "3021", 1],
	[2, 2, "3022", 0], [6, 1, "3666", 0], [1, 6, "3666", 1], [4, 1, "3710", 0],
	[1, 4, "3710", 1], [3, 1, "3623", 0], [1, 3, "3623", 1], [2, 1, "3023", 0],
	[1, 2, "3023", 1], [1, 1, "3024", 0],
]

## Tiles for a smooth top, largest first, as Patterns.TILES has plates.
const TOPS: Array = [
	[4, 2, "87079", 0], [2, 4, "87079", 1], [3, 2, "26603", 0], [2, 3, "26603", 1],
	[2, 2, "3068b", 0], [4, 1, "2431", 0], [1, 4, "2431", 1], [3, 1, "63864", 0],
	[1, 3, "63864", 1], [2, 1, "3069b", 0], [1, 2, "3069b", 1], [1, 1, "3070b", 0],
]

## What each surface part is, read once off its own mesh: "w" studs across
## its fall, "d" along it, "h" plates tall, and "turn", the quarter turns
## that make rot = facing + turn point its fall that way.
static var _parts: Dictionary = {}

## What the last shape laid came to, for a probe to read: its mirror axis
## and the sum a stud and its mirror add up to, its columns and plates.
static var last: Dictionary = {}


## Every brick of a shape, or a reason in [param trouble].
static func lay(pattern: Dictionary, trouble: Array, library: PartLibrary) -> Array:
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var origin := Vector3(float(at.get("x", 0.0)), float(at.get("y", 0.0)),
		float(at.get("z", 0.0)))
	var colour: int = int(pattern.get("color", pattern.get("colour", 15)))
	var solids: Array = _read(pattern, "solids", trouble, true)
	var cuts: Array = _read(pattern, "cuts", trouble, false)
	if not trouble.is_empty():
		return []
	if solids.is_empty():
		trouble.append("a shape wants a solid: \"loft\", \"extrude\", \"revolve\", "
			+ "\"box\", \"ellipsoid\" or \"dome\", or several in \"solids\"")
		return []
	var bands: Array = []
	for raw: Variant in pattern.get("bands", []):
		if raw is Dictionary:
			bands.append(raw)
	var smooth: bool = str(pattern.get("top", "smooth")).to_lower() != "studs"
	var surface: String = str(pattern.get("surface", "auto")).to_lower()
	if surface == "auto":
		surface = "straight"
		for solid: Dictionary in solids:
			if bool(solid["round"]):
				surface = "curved"

	# Sampled at the middle of every stud and plate the solids reach.
	var box: AABB = solids[0]["box"]
	for solid: Dictionary in solids:
		box = box.merge(solid["box"])
	var x0: int = floori(box.position.x)
	var x1: int = ceili(box.end.x)
	var z0: int = floori(box.position.z)
	var z1: int = ceili(box.end.z)
	var y0: int = floori(box.position.y)
	var y1: int = ceili(box.end.y)
	var tall: int = y1 - y0
	if (x1 - x0) * (z1 - z0) * tall > MOST_CELLS or tall < 1:
		trouble.append("that shape is %d by %d studs and %d plates, which is a "
			% [x1 - x0, z1 - z0, tall] + "mistake in the numbers rather than a model")
		return []
	var columns: Dictionary = {}    ## Vector2i -> PackedInt32Array, colour or -1
	for x: int in range(x0, x1):
		for z: int in range(z0, z1):
			var column := PackedInt32Array()
			column.resize(tall)
			var any: bool = false
			for j: int in tall:
				var point := Vector3(x + 0.5, y0 + j + 0.5, z + 0.5)
				var here: int = _colour_at(solids, cuts, point, colour, bands)
				column[j] = here
				any = any or here >= 0
			if any:
				columns[Vector2i(x, z)] = column
	# A plate of the shape with nothing of it above, below or beside is held
	# by nothing, and a 1 x 1 laid there was reported floating on three of
	# the four first bodies. Left out.
	for key: Variant in columns.keys():
		var cell: Vector2i = key
		var column: PackedInt32Array = columns[cell]
		for j: int in tall:
			if column[j] < 0 or (j > 0 and column[j - 1] >= 0) \
					or (j < tall - 1 and column[j + 1] >= 0) or j == 0:
				continue
			var beside: bool = false
			for step: Vector2i in OUT:
				var other: Variant = columns.get(cell + step)
				if other != null and (other as PackedInt32Array)[j] >= 0:
					beside = true
			if not beside:
				column[j] = -1
		columns[cell] = column
		if column.find(-1) >= 0 and _empty(column):
			columns.erase(cell)
	if columns.is_empty():
		trouble.append("that shape covers nothing: every solid is too small to "
			+ "hold the middle of a stud, or the cuts take all of it")
		return []

	var plan := Plan.new(columns, tall, smooth, library)
	plan.sides_smooth = bool(pattern.get("panels", true))
	plan.sample = func(x: float, j: float, z: float) -> bool:
		return _colour_at(solids, cuts, Vector3(x, y0 + j, z), colour, bands) >= 0
	# Studs left showing on the studs named, [x, z] from at, for something to
	# stand on: a tower on its plinth stands on bricks, not on tiles.
	for raw: Variant in pattern.get("studs_at", []):
		if raw is Array and (raw as Array).size() >= 2:
			var cell := Vector2i(int(raw[0]), int(raw[1]))
			if columns.has(cell):
				plan.studded[cell] = true
	# A cut marked "keep" is kept clear of everything: a wedge's cut side, a
	# slope, a panel's tile. A plinth's stair stands in its cut, and the
	# terraces' wedges reached into it.
	for cut: Dictionary in cuts:
		if not bool((cut["spec"] as Dictionary).get("keep", false)):
			continue
		var kept: AABB = cut["box"]
		for x: int in range(floori(kept.position.x), ceili(kept.end.x)):
			for z: int in range(floori(kept.position.z), ceili(kept.end.z)):
				for j: int in tall:
					if _inside(cut, Vector3(x + 0.5, y0 + j + 0.5, z + 0.5)):
						plan.taken[Vector3i(x, j, z)] = true
	plan.mirror_of()
	last = {"mirror": plan.axis, "sum": plan.sum, "columns": columns.size(), "plates": tall}
	if surface != "none":
		plan.surface(surface)
	plan.lay()
	plan.prune()
	plan.stitch()
	last["pieces"] = plan.pieces().size()
	var made: Array = plan.made
	var top_colour: int = int(pattern.get("top_color", pattern.get("top_colour", -1)))
	var placed: Array = []
	for one: Dictionary in made:
		if top_colour >= 0 and bool(one.get("_top", false)):
			one["color"] = top_colour
		var out := {"part": one["part"], "color": one["color"],
			"x": float(one["x"]) + origin.x, "y": float(one["y"]) + y0 + origin.y,
			"z": float(one["z"]) + origin.z, "rot": int(one["rot"])}
		if one.has("panel"):
			out["panel"] = one["panel"]
		placed.append(out)
	return placed


static func _empty(column: PackedInt32Array) -> bool:
	for value: int in column:
		if value >= 0:
			return false
	return true


## The solids or cuts a shape names: in a list under [param key], and for
## solids also the one kind given at the top level.
static func _read(pattern: Dictionary, key: String, trouble: Array,
		top_level: bool) -> Array:
	var raw: Array = []
	if pattern.get(key) is Array:
		raw = (pattern[key] as Array).duplicate()
	if top_level:
		for kind: String in KINDS:
			if pattern.get(kind) is Dictionary:
				raw.append({kind: pattern[kind]})
	var out: Array = []
	for entry: Variant in raw:
		if not entry is Dictionary:
			trouble.append("each of a shape's %s is an object naming one kind: " % key
				+ ", ".join(PackedStringArray(KINDS)))
			continue
		var given: Dictionary = entry
		var kind: String = str(given.get("kind", ""))
		var spec: Dictionary = given
		for one: String in KINDS:
			if given.get(one) is Dictionary:
				kind = one
				spec = (given[one] as Dictionary).duplicate()
				if given.has("color") and not spec.has("color"):
					spec["color"] = given["color"]
				break
		if not kind in KINDS:
			trouble.append("a shape's %s are %s" % [key, ", ".join(PackedStringArray(KINDS))])
			continue
		var solid: Dictionary = _solid(kind, spec, trouble)
		if not solid.is_empty():
			out.append(solid)
	return out


## One solid, checked and with what it needs worked out: its box (studs
## across and along, plates up), whether it is round, and its colour.
static func _solid(kind: String, spec: Dictionary, trouble: Array) -> Dictionary:
	var solid := {"kind": kind, "spec": spec, "round": false,
		"color": int(spec.get("color", spec.get("colour", -1)))}
	match kind:
		"box":
			var from: Vector3 = _vec(spec.get("from", [0, 0, 0]))
			var size: Vector3 = _vec(spec.get("size", [0, 0, 0]))
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				trouble.append("a box wants size [across, plates up, deep], each above nought")
				return {}
			solid["box"] = AABB(from, size)
			solid["round"] = float(spec.get("round", 0.0)) > 0.0 \
				or float(spec.get("edge", 0.0)) > 0.0
		"ellipsoid", "dome":
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var radii: Vector3 = _vec(spec.get("radii", [0, 0, 0]))
			if radii.x <= 0.0 or radii.y <= 0.0 or radii.z <= 0.0:
				trouble.append("an %s wants radii [studs across, plates up, studs deep]" % kind)
				return {}
			var low: Vector3 = centre - radii
			if kind == "dome":
				low.y = centre.y
			solid["box"] = AABB(low, centre + radii - low)
			solid["round"] = true
		"loft":
			var along: String = str(spec.get("along", "x")).to_lower()
			var sections: Array = []
			for raw: Variant in spec.get("sections", []):
				if raw is Dictionary:
					sections.append(raw)
			if sections.size() < 2 or not along in ["x", "z"]:
				trouble.append("a loft wants \"along\": \"x\" or \"z\" and two or more "
					+ "sections, each {\"at\", \"width\", \"height\", \"bottom\"}")
				return {}
			sections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("at", 0.0)) < float(b.get("at", 0.0)))
			var widest: float = 0.0
			for section: Dictionary in sections:
				widest = maxf(widest, float(section.get("width", 0.0)))
			var middle: float = float(spec.get("centre", spec.get("center", widest / 2.0)))
			var low := Vector3(INF, INF, INF)
			var high := Vector3(-INF, -INF, -INF)
			for section: Dictionary in sections:
				var a: float = float(section.get("at", 0.0))
				var w: float = float(section.get("width", 0.0))
				var c: float = middle + float(section.get("offset", 0.0))
				var b: float = float(section.get("bottom", 0.0))
				var h: float = float(section.get("height", 0.0))
				solid["round"] = solid["round"] or float(section.get("round", 0.5)) > 0.0
				var lat := Vector2(c - w / 2.0, c + w / 2.0)
				if along == "x":
					low = Vector3(minf(low.x, a), minf(low.y, b), minf(low.z, lat.x))
					high = Vector3(maxf(high.x, a), maxf(high.y, b + h), maxf(high.z, lat.y))
				else:
					low = Vector3(minf(low.x, lat.x), minf(low.y, b), minf(low.z, a))
					high = Vector3(maxf(high.x, lat.y), maxf(high.y, b + h), maxf(high.z, a))
			spec["_sections"] = sections
			spec["_middle"] = middle
			solid["box"] = AABB(low, high - low)
		"extrude":
			var along: String = str(spec.get("along", "x")).to_lower()
			var profile: Array = _points(spec.get("profile", []))
			var under: Array = _points(spec.get("under", []))
			var width: float = float(spec.get("width", 0.0))
			if profile.size() < 2 or width <= 0.0 or not along in ["x", "z"]:
				trouble.append("an extrude wants \"along\", a \"width\" and a \"profile\" "
					+ "of two or more [along, plates up] points along its top")
				return {}
			var from: float = float(spec.get("from", 0.0))
			var lo: float = INF
			var hi: float = -INF
			var top: float = -INF
			var bottom: float = INF
			for point: Vector2 in profile:
				lo = minf(lo, point.x)
				hi = maxf(hi, point.x)
				top = maxf(top, point.y)
			for point: Vector2 in under:
				bottom = minf(bottom, point.y)
			if under.is_empty():
				bottom = 0.0
			spec["_profile"] = profile
			spec["_under"] = under
			solid["round"] = float(spec.get("round", 0.0)) > 0.0
			if along == "x":
				solid["box"] = AABB(Vector3(lo, bottom, from), Vector3(hi - lo, top - bottom, width))
			else:
				solid["box"] = AABB(Vector3(from, bottom, lo), Vector3(width, top - bottom, hi - lo))
		"revolve":
			var axis: String = str(spec.get("axis", "y")).to_lower()
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var profile: Array = _points(spec.get("profile", []))
			if profile.size() < 2 or not axis in ["x", "y", "z"]:
				trouble.append("a revolve wants \"axis\" and a \"profile\" of two or more "
					+ "[along, radius in studs] points")
				return {}
			var lo: float = INF
			var hi: float = -INF
			var reach: float = 0.0
			for point: Vector2 in profile:
				lo = minf(lo, point.x)
				hi = maxf(hi, point.x)
				reach = maxf(reach, point.y)
			spec["_profile"] = profile
			solid["round"] = true
			match axis:
				"y":
					solid["box"] = AABB(Vector3(centre.x - reach, centre.y + lo, centre.z - reach),
						Vector3(2.0 * reach, hi - lo, 2.0 * reach))
				"x":
					solid["box"] = AABB(Vector3(centre.x + lo, centre.y - reach * PLATES_PER_STUD,
						centre.z - reach), Vector3(hi - lo, 2.0 * reach * PLATES_PER_STUD, 2.0 * reach))
				"z":
					solid["box"] = AABB(Vector3(centre.x - reach, centre.y - reach * PLATES_PER_STUD,
						centre.z + lo), Vector3(2.0 * reach, 2.0 * reach * PLATES_PER_STUD, hi - lo))
	return solid


static func _vec(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	if raw is Dictionary:
		return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))
	return Vector3.ZERO


## [[a, b], ...] as Vector2s, sorted by a.
static func _points(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for one: Variant in raw:
			if one is Array and (one as Array).size() >= 2:
				out.append(Vector2(float(one[0]), float(one[1])))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


## Linear between the points, nothing (NAN) outside them.
static func _along(points: Array, a: float) -> float:
	if points.is_empty() or a < (points[0] as Vector2).x or a > (points[-1] as Vector2).x:
		return NAN
	for n: int in range(1, points.size()):
		var one: Vector2 = points[n - 1]
		var two: Vector2 = points[n]
		if a <= two.x:
			if two.x - one.x < 0.0001:
				return maxf(one.y, two.y)
			return lerpf(one.y, two.y, (a - one.x) / (two.x - one.x))
	return (points[-1] as Vector2).y


## The colour of the shape at [param p] (studs, plates, studs), or -1 where
## it is not: the last solid that holds it, a band by height, and nothing
## where a cut takes it.
static func _colour_at(solids: Array, cuts: Array, p: Vector3, colour: int,
		bands: Array) -> int:
	var found: int = -2
	for solid: Dictionary in solids:
		if (solid["box"] as AABB).grow(0.001).has_point(p) and _inside(solid, p):
			found = int(solid["color"]) if int(solid["color"]) >= 0 else colour
	if found == -2:
		return -1
	for cut: Dictionary in cuts:
		if (cut["box"] as AABB).grow(0.001).has_point(p) and _inside(cut, p):
			return -1
	for band: Dictionary in bands:
		if p.y >= float(band.get("from", -INF)) and p.y < float(band.get("to", INF)):
			found = int(band.get("color", band.get("colour", found)))
	return found


## Is [param p] inside [param solid]?
static func _inside(solid: Dictionary, p: Vector3) -> bool:
	var spec: Dictionary = solid["spec"]
	match str(solid["kind"]):
		"box":
			var from: Vector3 = _vec(spec.get("from", [0, 0, 0]))
			var size: Vector3 = _vec(spec.get("size", [0, 0, 0]))
			var r: float = minf(float(spec.get("round", 0.0)), minf(size.x, size.z) / 2.0)
			var c: float = float(spec.get("chamfer", 0.0))
			var dx: float = maxf(maxf(from.x + r - p.x, 0.0), p.x - (from.x + size.x - r))
			var dz: float = maxf(maxf(from.z + r - p.z, 0.0), p.z - (from.z + size.z - r))
			if r > 0.0 and dx * dx + dz * dz > r * r:
				return false
			if c > 0.0:
				var ex: float = minf(p.x - from.x, from.x + size.x - p.x)
				var ez: float = minf(p.z - from.z, from.z + size.z - p.z)
				if ex + ez < c:
					return false
			var top: float = from.y + size.y
			var edge: float = float(spec.get("edge", 0.0))
			if edge > 0.0:
				var e: float = minf(minf(p.x - from.x, from.x + size.x - p.x),
					minf(p.z - from.z, from.z + size.z - p.z))
				top -= _round_off(e, edge)
			return p.y >= from.y and p.y <= top
		"ellipsoid", "dome":
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var radii: Vector3 = _vec(spec.get("radii", [1, 1, 1]))
			if str(solid["kind"]) == "dome" and p.y < centre.y:
				return false
			var d: Vector3 = (p - centre) / radii
			return d.length_squared() <= 1.0
		"loft":
			var along: String = str(spec.get("along", "x")).to_lower()
			var a: float = p.x if along == "x" else p.z
			var u: float = p.z if along == "x" else p.x
			return _in_loft(spec, a, u, p.y)
		"extrude":
			var along: String = str(spec.get("along", "x")).to_lower()
			var a: float = p.x if along == "x" else p.z
			var u: float = p.z if along == "x" else p.x
			var from: float = float(spec.get("from", 0.0))
			var width: float = float(spec.get("width", 0.0))
			if u < from or u > from + width:
				return false
			var top: float = _along(spec["_profile"], a)
			if is_nan(top):
				return false
			var bottom: float = 0.0
			if not (spec["_under"] as Array).is_empty():
				bottom = _along(spec["_under"], a)
				if is_nan(bottom):
					return false
			var r: float = float(spec.get("round", 0.0))
			if r > 0.0:
				top -= _round_off(minf(u - from, from + width - u), r)
			return p.y >= bottom and p.y <= top
		"revolve":
			var axis: String = str(spec.get("axis", "y")).to_lower()
			var centre: Vector3 = _vec(spec.get("centre", spec.get("center", [0, 0, 0])))
			var d: Vector3 = p - centre
			match axis:
				"y":
					var r: float = _along(spec["_profile"], d.y)
					return not is_nan(r) and Vector2(d.x, d.z).length() <= r
				"x":
					var r: float = _along(spec["_profile"], d.x)
					return not is_nan(r) and Vector2(d.y / PLATES_PER_STUD, d.z).length() <= r
				"z":
					var r: float = _along(spec["_profile"], d.z)
					return not is_nan(r) and Vector2(d.x, d.y / PLATES_PER_STUD).length() <= r
	return false


## How far a top edge rounded to [param radius] studs falls, in plates, at
## [param e] studs in from the edge.
static func _round_off(e: float, radius: float) -> float:
	if e >= radius:
		return 0.0
	var t: float = (radius - e) / radius
	return radius * PLATES_PER_STUD * (1.0 - sqrt(maxf(0.0, 1.0 - t * t)))


## Inside a loft at [param a] along it, [param u] across and [param v]
## plates up: between its sections, inside the section there — a
## superellipse from a box ("round": 0) to an ellipse (1), its lower half
## narrowing towards a keel by "keel" (0 to 1).
static func _in_loft(spec: Dictionary, a: float, u: float, v: float) -> bool:
	var sections: Array = spec["_sections"]
	var first: Dictionary = sections[0]
	var last: Dictionary = sections[-1]
	if a < float(first.get("at", 0.0)) or a > float(last.get("at", 0.0)):
		return false
	var one: Dictionary = first
	var two: Dictionary = last
	for n: int in range(1, sections.size()):
		if a <= float((sections[n] as Dictionary).get("at", 0.0)):
			one = sections[n - 1]
			two = sections[n]
			break
	var span: float = float(two.get("at", 0.0)) - float(one.get("at", 0.0))
	var t: float = 0.0 if span < 0.0001 else (a - float(one.get("at", 0.0))) / span
	var width: float = lerpf(float(one.get("width", 0.0)), float(two.get("width", 0.0)), t)
	var height: float = lerpf(float(one.get("height", 0.0)), float(two.get("height", 0.0)), t)
	var bottom: float = lerpf(float(one.get("bottom", 0.0)), float(two.get("bottom", 0.0)), t)
	var middle: float = float(spec["_middle"]) + lerpf(float(one.get("offset", 0.0)),
		float(two.get("offset", 0.0)), t)
	var rounded: float = lerpf(float(one.get("round", 0.5)), float(two.get("round", 0.5)), t)
	var keel: float = lerpf(float(one.get("keel", 0.0)), float(two.get("keel", 0.0)), t)
	if width <= 0.0 or height <= 0.0:
		return false
	var du: float = absf(u - middle) / (width / 2.0)
	var dv: float = (v - (bottom + height / 2.0)) / (height / 2.0)
	if du > 1.0 or absf(dv) > 1.0:
		return false
	if dv < 0.0 and keel > 0.0:
		du /= maxf(0.05, 1.0 - keel * -dv)
		if du > 1.0:
			return false
	var power: float = lerpf(16.0, 2.0, clampf(rounded, 0.0, 1.0))
	return pow(du, power) + pow(absf(dv), power) <= 1.0


## What a surface part is, read off its own mesh once: how wide across its
## fall, how long along it, how many plates tall, and the quarter turns that
## point its fall (from its high end, or for an inverted one from its deep
## end) along +z. {} when the part is not here.
static func part(library: PartLibrary, id: String, inverted: bool = false) -> Dictionary:
	var key: String = "%s %s" % [id, inverted]
	if _parts.has(key):
		return _parts[key]
	_parts[key] = {}
	if library == null or id.is_empty():
		return {}
	var info: PartLibrary.PartInfo = library.parts.get(id)
	var mesh: Lbm.PartMesh = library.mesh_for(id)
	if info == null or mesh == null or mesh.boxes.is_empty():
		return {}
	var b: AABB = mesh.bounds
	var studded: bool = false
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and connector.axis.normalized().dot(Vector3.UP) > 0.9:
			studded = true
	var foot: Vector2i = info.footprint_studs()
	# The highest top (or for an inverted part the lowest bottom) in each half
	# of the footprint, along z and along x. The fall runs along the axis where
	# the halves differ most, from the high half.
	var halves := func(along_z: bool) -> Vector2:
		var middle: float = (b.position.z + b.size.z / 2.0) if along_z \
			else (b.position.x + b.size.x / 2.0)
		var low_half: float = -INF if not inverted else INF
		var high_half: float = -INF if not inverted else INF
		for box: AABB in mesh.boxes:
			var from: float = box.position.z if along_z else box.position.x
			var to: float = box.end.z if along_z else box.end.x
			var value: float = box.end.y if not inverted else box.position.y
			if from < middle - 0.5:
				low_half = maxf(low_half, value) if not inverted else minf(low_half, value)
			if to > middle + 0.5:
				high_half = maxf(high_half, value) if not inverted else minf(high_half, value)
		return Vector2(low_half, high_half)
	var on_z: Vector2 = halves.call(true)
	var on_x: Vector2 = halves.call(false)
	var fall_z: float = absf(on_z.x - on_z.y)
	var fall_x: float = absf(on_x.x - on_x.y)
	if maxf(fall_z, fall_x) < 1.0:
		return {}
	var native: int
	if fall_z >= fall_x:
		var high_low: bool = on_z.x > on_z.y if not inverted else on_z.x < on_z.y
		native = 0 if high_low else 2
	else:
		var high_low: bool = on_x.x > on_x.y if not inverted else on_x.x < on_x.y
		native = 1 if high_low else 3
	var along_z: bool = native % 2 == 0
	var found := {"id": id, "w": foot.x if along_z else foot.y,
		"d": foot.y if along_z else foot.x,
		"h": int(round((b.size.y - (4.0 if studded else 0.0)) / 8.0)),
		"turn": posmod(-native, 4)}
	_parts[key] = found
	return found


## Wedge bricks, a brick tall, both hands: what a course's diagonal edge is
## laid in, as wedge plates are a plate layer's.
const BRICK_WEDGES: Array = ["41747", "41748", "43710", "43711", "6564", "6565",
	"41767", "41768"]

## "part rot" -> [across, deep, studs], as Patterns.wedge_shapes has plates.
static var _brick_wedges: Dictionary = {}


static func brick_wedges(library: PartLibrary) -> Dictionary:
	if not _brick_wedges.is_empty():
		return _brick_wedges
	for part: String in BRICK_WEDGES:
		var base: Array = Patterns._studs_of(library, part)
		if base.is_empty():
			continue
		for rot: int in 4:
			_brick_wedges["%s %d" % [part, rot]] = Patterns._turned(base, rot)
	return _brick_wedges


## What a wedge plate covers in plan at half a stud, placed as "part rot"
## names it, from its own mesh, as one comparable string — reflected across
## x or z first when [param mirror] says so. "" when the part is not here.
static var _plans: Dictionary = {}


static func wedge_plan(library: PartLibrary, named: String, mirror: String) -> String:
	var key: String = "%s %s" % [named, mirror]
	if _plans.has(key):
		return _plans[key]
	_plans[key] = ""
	var said: PackedStringArray = named.split(" ")
	var mesh: Lbm.PartMesh = library.mesh_for(said[0]) if library != null else null
	var info: PartLibrary.PartInfo = library.parts.get(said[0]) if library != null else null
	if mesh == null or info == null:
		return ""
	var foot: Vector2i = info.footprint_studs()
	var b: AABB = mesh.bounds
	var cells: Dictionary = {}
	for u: int in 2 * foot.x:
		for v: int in 2 * foot.y:
			var x: float = b.position.x + 10.0 * u + 5.0
			var z: float = b.position.z + 10.0 * v + 5.0
			for box: AABB in mesh.boxes:
				if box.position.x <= x and box.end.x >= x and box.position.z <= z \
						and box.end.z >= z:
					cells[Vector2i(u, v)] = true
					break
	# Turned as Patterns._turned turns studs, at twice the resolution.
	var across_: int = 2 * foot.x
	var deep: int = 2 * foot.y
	for _turn: int in posmod(said[1].to_int(), 4):
		var next: Dictionary = {}
		for cell: Variant in cells:
			var at: Vector2i = cell
			next[Vector2i(at.y, across_ - 1 - at.x)] = true
		cells = next
		var swap: int = across_
		across_ = deep
		deep = swap
	if mirror == "z" or mirror == "x":
		var flipped: Dictionary = {}
		for cell: Variant in cells:
			var at: Vector2i = cell
			flipped[Vector2i(at.x, deep - 1 - at.y) if mirror == "z"
				else Vector2i(across_ - 1 - at.x, at.y)] = true
		cells = flipped
	var said_cells := PackedStringArray()
	for cell: Variant in cells:
		said_cells.append("%d,%d" % [(cell as Vector2i).x, (cell as Vector2i).y])
	said_cells.sort()
	_plans[key] = "%dx%d %s" % [across_, deep, "|".join(said_cells)]
	return _plans[key]


## A shape laid out: which plate of which stud is what colour, which of them
## are the core, the ledges and the top, and the parts that cover them.
class Plan extends RefCounted:
	var columns: Dictionary          ## Vector2i -> PackedInt32Array
	var tall: int
	var smooth: bool
	## Straight sides as tiles on bricks with side studs.
	var sides_smooth: bool = true
	var library: PartLibrary
	## Plates taken by a surface part: Vector3i(x, j, z) -> true.
	var taken: Dictionary = {}
	var made: Array = []
	## Whether the shape holds a point, in studs across, plates up from the
	## plan's foot and studs along.
	var sample: Callable
	## The mirror: "" none, "x" about a plane across x, "z" across z, with
	## [member sum] the coordinate a cell and its mirror add up to.
	var axis: String = ""
	var sum: int = 0

	func _init(given: Dictionary, height: int, tiles: bool, parts: PartLibrary) -> void:
		columns = given
		tall = height
		smooth = tiles
		library = parts

	func at(cell: Vector2i, j: int) -> int:
		if j < 0 or j >= tall or not columns.has(cell):
			return -1
		return (columns[cell] as PackedInt32Array)[j]

	## The top plate of a run of plates that has another under it: a tile,
	## where the top is to be smooth.
	func is_top(cell: Vector2i, j: int) -> bool:
		if not smooth or at(cell, j) < 0 or at(cell, j + 1) >= 0 or at(cell, j - 1) < 0 \
				or studded.has(cell):
			return false
		# Beside a bridge one plate thick, a plate, so the bridge's plates can
		# reach across onto it: tiled, a car's nose was tied to the body over
		# its wheel arch by nothing, and came out a piece of its own.
		for step: Vector2i in Shapes.OUT:
			if at(cell + step, j) >= 0 and at(cell + step, j - 1) < 0 and at(cell + step, j + 1) < 0:
				return false
		return true

	## The core's plates: every plate of the shape but a top tile.
	func body(cell: Vector2i, j: int) -> bool:
		return at(cell, j) >= 0 and not is_top(cell, j)

	## Studs where course [param k] is whole, in one colour.
	func full(k: int) -> Dictionary:
		var out: Dictionary = {}
		for key: Variant in columns:
			var cell: Vector2i = key
			var j: int = 3 * k
			if body(cell, j) and body(cell, j + 1) and body(cell, j + 2) \
					and at(cell, j) == at(cell, j + 1) and at(cell, j + 1) == at(cell, j + 2):
				out[cell] = true
		return out

	## Whether the shape is its own mirror, about a plane across x or z: the
	## columns either side the same, plate for plate and colour for colour.
	func mirror_of() -> void:
		for try_axis: String in ["z", "x"]:
			var low: int = 1 << 30
			var high: int = -(1 << 30)
			for key: Variant in columns:
				var cell: Vector2i = key
				var c: int = cell.y if try_axis == "z" else cell.x
				low = mini(low, c)
				high = maxi(high, c)
			var total: int = low + high
			var same: bool = true
			for key: Variant in columns:
				var cell: Vector2i = key
				var twin: Vector2i = Vector2i(cell.x, total - cell.y) if try_axis == "z" \
					else Vector2i(total - cell.x, cell.y)
				if not columns.has(twin) or columns[twin] != columns[cell]:
					same = false
					break
			if same:
				axis = try_axis
				sum = total
				return

	func across(cell: Vector2i) -> int:
		return cell.y if axis == "z" else cell.x

	func reflect(cell: Vector2i) -> Vector2i:
		return Vector2i(cell.x, sum - cell.y) if axis == "z" else Vector2i(sum - cell.x, cell.y)

	## The cells of the middle strip at plate [param j]: across the mirror
	## plane, alternately two studs wide and four (a plane between studs),
	## or three and one (a plane through a row of studs), so the joints
	## either side of it move from layer to layer and every half is tied to
	## the strip by the layer over it. Two and none, a nose only a few plates
	## thick, all of them odd, had no strip and came out as two halves.
	func spine(j: int) -> Vector2i:
		if axis.is_empty():
			return Vector2i(1, 0)
		# posmod: a shape centred on its at has studs either side of nought,
		# and -1 % 2 is -1, which took a plane between studs for one through a
		# row of them and laid a three-wide strip off the middle of a plinth.
		if posmod(sum, 2) == 1:
			var a: int = (sum - 1) / 2
			return Vector2i(a, a + 1) if j % 2 == 0 else Vector2i(a - 1, a + 2)
		var m: int = sum / 2
		return Vector2i(m - 1, m + 1) if j % 2 == 0 else Vector2i(m, m)

	## The top of each column (one plate over its highest) and its foot.
	func tops() -> Dictionary:
		var out: Dictionary = {}
		for key: Variant in columns:
			var column: PackedInt32Array = columns[key]
			for j: int in range(tall - 1, -1, -1):
				if column[j] >= 0:
					out[key] = j + 1
					break
		return out

	func feet() -> Dictionary:
		var out: Dictionary = {}
		for key: Variant in columns:
			var column: PackedInt32Array = columns[key]
			for j: int in tall:
				if column[j] >= 0:
					out[key] = j
					break
		return out

	## Cells whose top plate carries a slope, so is laid with studs, not tiled.
	var studded: Dictionary = {}

	## The slopes there are, as [kind, length in studs, height in plates, one
	## wide, two wide, the height of the surface over the middle of each stud
	## of it, from its high end]. Straight ones have a flat stud at the top.
	const SLOPES: Array = [
		["curved", 4, 3, "61678", "93606", [2.8, 2.2, 1.4, 0.5]],
		["curved", 3, 3, "50950", "24309", [2.6, 1.6, 0.6]],
		["curved", 2, 2, "11477", "15068", [1.6, 0.6]],
		["straight", 4, 3, "60477", "30363", [3.0, 2.2, 1.4, 0.6]],
		["straight", 3, 3, "4286", "3298", [3.0, 1.8, 0.7]],
		["straight", 2, 3, "3040b", "3039", [3.0, 1.2]],
		["cheese", 1, 2, "54200", "85984", [1.0]],
	]
	## Under an overhang, the same by how high the underside is over the
	## inverted slope's bottom at each stud, from its deep end.
	## Each hung under a 2 x 2 plate in every turn and checked: the 1 x 2
	## (3665) runs into the plate over it, and the curved 2 x 1 and 2 x 2
	## (24201, 32803) are not read as slopes off their meshes, so neither is
	## here. A two-stud run under an overhang takes the 2 x 2 or nothing.
	const INVERTED: Array = [
		["under", 4, 3, "13547", "", [0.3, 1.0, 1.8, 2.6]],
		["under", 3, 3, "4287a", "3747b", [0.0, 1.2, 2.3]],
		["under", 2, 3, "", "3660a", [0.0, 1.8]],
	]

	## Surface parts wherever the top falls away from one stud to the next,
	## and wherever the foot rises: for each run of studs going down, the
	## slope whose own fall is the nearest to the shape's, standing on the
	## lowest of them with its high end flush with the stud above, and the
	## plates it stands in taken out of the shape for it.
	##
	## A first version sloped only where whole courses stepped in, and a
	## car's cabin and bonnet stayed stairs of plates; a second only where a
	## run of studs was flat, and a smooth body, which falls a plate or so
	## every stud, got cheese slopes and nothing else.
	func surface(kind: String) -> void:
		var picks: Array = []
		_fit(picks, kind, false)
		_fit(picks, kind, true)
		# A pick and its mirror together or neither: laid one at a time, a car's
		# inverted slope went in on one side and its mirror found its place
		# taken, and the check called the car lopsided.
		for group: Array in _symmetric(picks):
			var ready: Array = []
			var whole: bool = true
			for pick: Dictionary in group:
				var parts: Array = _ready(pick)
				if parts.is_empty():
					whole = false
				ready.append_array(parts)
			if not whole:
				continue
			var claimed: Dictionary = {}
			for one: Dictionary in ready:
				if not _fits(one, claimed):
					whole = false
			if not whole:
				continue
			for one: Dictionary in ready:
				_carve(one)
				_place(one)

	## The part a pick is laid as, or "".
	func _part_id(pick: Dictionary) -> String:
		var wide: int = int(pick.get("wide", 1))
		for entry: Array in (INVERTED if bool(pick["under"]) else SLOPES):
			if entry[0] == pick["kind"] and int(entry[1]) == int(pick["length"]) \
					and int(entry[2]) == int(pick["tall"]):
				var id: String = str(entry[2 + wide])
				if id.is_empty():
					return ""
				var shape: Dictionary = Shapes.part(library, id, bool(pick["under"]))
				if shape.is_empty() or int(shape["w"]) != wide \
						or int(shape["d"]) != int(pick["length"]):
					return ""
				return id
		return ""

	## A pick as it can be laid: itself, or a pair the two-wide part of
	## which is not here as two of the one-wide, or nothing.
	func _ready(pick: Dictionary) -> Array:
		if not _part_id(pick).is_empty():
			return [pick]
		if int(pick.get("wide", 1)) != 2:
			return []
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var out: Array = []
		for a: int in 2:
			var one: Dictionary = pick.duplicate()
			one.erase("wide")
			one["cell"] = (pick["cell"] as Vector2i) + perp * a
			if not _part_id(one).is_empty():
				out.append(one)
		return out

	## Nothing already laid in the plates a pick would stand in, nor claimed
	## by another of its group ([param claimed], which this adds to).
	func _fits(pick: Dictionary, claimed: Dictionary = {}) -> bool:
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		for a: int in int(pick.get("wide", 1)):
			for b: int in int(pick["length"]):
				var cell: Vector2i = (pick["cell"] as Vector2i) + perp * a + facing * b
				for n: int in int(pick["tall"]):
					var key := Vector3i(cell.x, int(pick["y"]) + n, cell.y)
					if taken.has(key) or claimed.has(key):
						return false
					claimed[key] = true
		return true

	## The runs going down from a higher stud, and the slope that fits each.
	func _fit(picks: Array, kind: String, under: bool) -> void:
		var height: Dictionary = feet() if under else tops()
		var used: Dictionary = {}
		# From the top of every fall down (from the foot up, under it), each
		# slope's own surface then the height of the studs it covers, so the
		# next one down carries on from it. Taken in order along x, a ramp
		# started every slope at its lowest stud and got a cheese slope a stud.
		var cells: Array = height.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var ha: int = height[a]
			var hb: int = height[b]
			if ha != hb:
				return ha < hb if under else ha > hb
			return a.x < b.x or a.x == b.x and a.y < b.y)
		var table: Array = []
		for entry: Array in (INVERTED if under else SLOPES):
			if under or entry[0] == "cheese" or entry[0] == kind:
				table.append(entry)
		for key: Variant in cells:
			var cell: Vector2i = key
			if used.has(cell):
				continue
			var best: Dictionary = {}
			for out: Vector2i in Shapes.OUT:
				var inner: Vector2i = cell - out
				if not height.has(inner):
					continue
				var top: int = height[inner]
				var drop: int = (int(height[cell]) - top) if under else (top - int(height[cell]))
				if drop < 1:
					continue
				for entry: Array in table:
					var length: int = entry[1]
					var tall_: int = entry[2]
					var profile: Array = entry[5]
					# Its high end flush with the stud above, or a plate or two
					# under it: the surface passes through the middle of that
					# stud, and a ramp falling a plate a stud, fitted flush, was
					# a plate too high all the way down and took cheese slopes.
					for drop_by: int in 3:
						var base: int = (top + drop_by) if under else (top - tall_ - drop_by)
						var error: float = 0.0
						var fits: bool = base >= 0
						for n: int in length:
							if not fits:
								break
							var at_: Vector2i = cell + out * n
							if not height.has(at_) or used.has(at_):
								fits = false
								break
							var here: int = height[at_]
							if under:
								# Hung from the shape's plates over it, so they have
								# to be there: under a wheel arch's thin bridge an
								# inverted slope took the bridge's place and hung
								# from nothing.
								if here < base or here > base + tall_ or at(at_, base + tall_) < 0:
									fits = false
									break
								error += absf(float(here - base) - float(profile[n]))
							else:
								# Standing on the shape's plates, so they have to be
								# there: over a wheel arch a slope took the place of
								# a bridge one plate thick and stood on nothing.
								if here < base or here > base + tall_ \
										or (base > 0 and at(at_, base - 1) < 0):
									fits = false
									break
								error += absf(float(here - base) - float(profile[n]))
						if not fits:
							continue
						error /= length
						# The longest slope whose fall is within a plate of the
						# shape's.
						var score: float = error - 0.2 * length
						if error <= 1.0 and (best.is_empty() or score < float(best["score"])):
							var colour: int = at(inner, (top if under else top - 1))
							if colour < 0:
								colour = at(cell, int(height[cell]) - (0 if under else 1))
							best = {"cell": cell, "facing": out, "length": length,
								"tall": tall_, "y": base, "kind": entry[0], "colour": colour,
								"under": under, "score": score, "inner": inner}
			if best.is_empty():
				continue
			for n: int in int(best["length"]):
				used[cell + (best["facing"] as Vector2i) * n] = true
			var profile_of: Array = []
			for entry: Array in table:
				if entry[0] == best["kind"] and int(entry[1]) == int(best["length"]) \
						and int(entry[2]) == int(best["tall"]):
					profile_of = entry[5]
			for n: int in int(best["length"]):
				var over: float = float(profile_of[n]) if n < profile_of.size() else 0.0
				height[cell + (best["facing"] as Vector2i) * n] = int(best["y"]) + roundi(over)
			picks.append(best)

	## Take the plates a slope stands in out of the shape — everything over
	## its foot in the studs it covers, or under an overhang everything under
	## its top — and keep the plate under it studded.
	func _carve(pick: Dictionary) -> void:
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var y: int = pick["y"]
		var under: bool = pick["under"]
		for a: int in int(pick.get("wide", 1)):
			for b: int in int(pick["length"]):
				var cell: Vector2i = (pick["cell"] as Vector2i) + perp * a + facing * b
				if not columns.has(cell):
					continue
				var column: PackedInt32Array = columns[cell]
				var span: Vector2i = Vector2i(0, mini(y + int(pick["tall"]), tall)) if under \
					else Vector2i(maxi(y, 0), tall)
				for j: int in range(span.x, span.y):
					column[j] = -1
				columns[cell] = column
				if not under:
					studded[cell] = true

	## The picks as a mirror would have them, in groups to be laid together:
	## those on one side of the plane and on it, each paired with the one
	## beside it into a part two studs wide where the two are the same, each
	## with its reflection on the other side.
	## A pick beside the plane falling along it pairs with its own mirror,
	## so the part over the middle is one part, symmetric by itself.
	func _symmetric(picks: Array) -> Array:
		var by_cell: Dictionary = {}
		for pick: Dictionary in picks:
			by_cell[_key(pick["cell"], pick)] = pick
		var paired: Dictionary = {}
		var out: Array = []
		for pick: Dictionary in picks:
			var cell: Vector2i = pick["cell"]
			if paired.has(_key(cell, pick)):
				continue
			if not axis.is_empty() and across(cell) * 2 > sum:
				continue
			var facing: Vector2i = pick["facing"]
			var perp := Vector2i(absi(facing.y), absi(facing.x))
			var twin: Dictionary = by_cell.get(_key(cell + perp, pick), {})
			if not twin.is_empty() and not axis.is_empty() \
					and across(twin["cell"]) * 2 > sum and reflect(cell) != Vector2i(twin["cell"]):
				twin = {}
			if not twin.is_empty() and twin["facing"] == facing \
					and twin["length"] == pick["length"] and twin["tall"] == pick["tall"] \
					and twin["kind"] == pick["kind"] and twin["colour"] == pick["colour"] \
					and not paired.has(_key(twin["cell"], twin)):
				var both: Dictionary = pick.duplicate()
				both["wide"] = 2
				paired[_key(cell, pick)] = true
				paired[_key(twin["cell"], twin)] = true
				out.append(both)
				continue
			paired[_key(cell, pick)] = true
			out.append(pick)
		var whole: Array = []
		if axis.is_empty():
			for pick: Dictionary in out:
				whole.append([pick])
			return whole
		for pick: Dictionary in out:
			whole.append([pick])
			var cell: Vector2i = pick["cell"]
			var facing: Vector2i = pick["facing"]
			var perp := Vector2i(absi(facing.y), absi(facing.x))
			var cells: Array[Vector2i] = [cell]
			if int(pick.get("wide", 1)) == 2:
				cells.append(cell + perp)
			var mirrored: Array[Vector2i] = []
			for one: Vector2i in cells:
				mirrored.append(reflect(one))
			if mirrored.has(cell):
				continue
			var start: Vector2i = mirrored[0]
			for one: Vector2i in mirrored:
				if one.x * perp.x + one.y * perp.y < start.x * perp.x + start.y * perp.y:
					start = one
			var twin: Dictionary = pick.duplicate()
			twin["cell"] = start
			twin["facing"] = Vector2i(facing.x, -facing.y) if axis == "z" \
				else Vector2i(-facing.x, facing.y)
			(whole[-1] as Array).append(twin)
		return whole

	func _key(cell: Vector2i, pick: Dictionary) -> String:
		return "%d %d %d %s" % [cell.x, cell.y, int(pick["y"]), str(pick["under"])]

	## Lay a pick: its slope, one or two studs wide, standing on the stud at
	## the foot of its run (or, under an overhang, hung from it).
	func _place(pick: Dictionary) -> void:
		var cell: Vector2i = pick["cell"]
		var facing: Vector2i = pick["facing"]
		var wide: int = int(pick.get("wide", 1))
		var under: bool = pick["under"]
		var length: int = pick["length"]
		var tall_: int = pick["tall"]
		var id: String = _part_id(pick)
		var shape: Dictionary = Shapes.part(library, id, under)
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var cells: Array[Vector2i] = []
		var high_row: Array[Vector2i] = []
		for a: int in wide:
			high_row.append(cell + perp * a)
			for b: int in length:
				cells.append(cell + perp * a + facing * b)
		var low := Vector2i(1 << 30, 1 << 30)
		for one: Vector2i in cells:
			low = Vector2i(mini(low.x, one.x), mini(low.y, one.y))
		var rot: int = posmod(Shapes.OUT.find(facing) + int(shape["turn"]), 4)
		var from: int = pick["y"]
		if under:
			# Hung from the studs over it, its deep row against the stud
			# beside that reaches lower.
			made.append({"part": id, "color": pick["colour"], "x": low.x, "y": from,
				"z": low.y, "rot": rot, "_cells": cells, "_h": tall_, "_studs": cells,
				"_base": high_row, "_slope": true})
		else:
			var studs: Array[Vector2i] = []
			if pick["kind"] == "straight":
				studs = high_row
			# Held where it is thick: a stud under the thin end of a slope
			# reaches into nothing, and the check called the plates under one
			# floating.
			made.append({"part": id, "color": pick["colour"], "x": low.x, "y": from,
				"z": low.y, "rot": rot, "_top": true, "_cells": cells, "_h": tall_,
				"_studs": studs, "_base": high_row, "_slope": true})
		_take(cells, from, tall_)

	## Mark the plates a surface part stands in, so nothing else is laid there
	## and no wedge's cut side reaches into it.
	func _take(cells: Array[Vector2i], from: int, plates: int) -> void:
		for one: Vector2i in cells:
			for n: int in plates:
				taken[Vector3i(one.x, from + n, one.y)] = true

	## The core and the top: plate by plate from the bottom, bricks where a
	## whole course is the shape's and nothing has taken it, plates where it
	## is not, tiles on top; each layer as one half, its mirror, and a strip
	## across the middle tying them.
	func lay() -> Array:
		var covered: Dictionary = {}
		for j: int in tall:
			if j % 3 == 0:
				var k: int = j / 3
				var bricks: Dictionary = {}
				for key: Variant in full(k):
					var cell: Vector2i = key
					if _free(covered, cell, j) and _free(covered, cell, j + 1) \
							and _free(covered, cell, j + 2):
						bricks[cell] = at(cell, j + 1)
				# Wedge bricks where a course's plan edge runs on the diagonal: a
				# hull's bow in bricks was a staircase where its plates had
				# wedges.
				var claimed: Dictionary = bricks.duplicate()
				for one: Dictionary in _wedged(bricks, j, 3):
					made.append(one)
				for key: Variant in claimed:
					if not bricks.has(key):
						for n: int in 3:
							covered[Vector3i((key as Vector2i).x, j + n, (key as Vector2i).y)] = true
				# Every other course, the outside of a straight side as bricks
				# with studs on it and a tile on them: the side smooth, as a
				# set's is, and not a face of plain bricks.
				if sides_smooth and k % 2 == 0:
					for one: Dictionary in _panels(bricks, j, k):
						made.append(one)
						for cell: Vector2i in one["_cells"]:
							for n: int in 3:
								covered[Vector3i(cell.x, j + n, cell.y)] = true
				for one: Dictionary in _layer(bricks, j, Shapes.CORE_BRICKS, k):
					made.append(_annotated(one, Shapes.CORE_BRICKS, 3, true))
				for key: Variant in bricks:
					var cell: Vector2i = key
					for n: int in 3:
						covered[Vector3i(cell.x, j + n, cell.y)] = true
			var plates: Dictionary = {}
			var tops: Dictionary = {}
			for key: Variant in columns:
				var cell: Vector2i = key
				if at(cell, j) < 0 or not _free(covered, cell, j):
					continue
				if is_top(cell, j):
					tops[cell] = at(cell, j)
				else:
					plates[cell] = at(cell, j)
			for one: Dictionary in _wedged(plates, j):
				made.append(one)
			for one: Dictionary in _layer(plates, j, Shapes.CORE_PLATES, -1):
				made.append(_annotated(one, Shapes.CORE_PLATES, 1, true))
			for one: Dictionary in _layer(tops, j, Shapes.TOPS, -1):
				one["_top"] = true
				made.append(_annotated(one, Shapes.TOPS, 1, false))
			for key: Variant in plates:
				covered[Vector3i((key as Vector2i).x, j, (key as Vector2i).y)] = true
			for key: Variant in tops:
				covered[Vector3i((key as Vector2i).x, j, (key as Vector2i).y)] = true
		return made

	## A core part with the studs it covers, how tall it is, and which of
	## them carry studs on top ([param studded]: plates and bricks do, tiles
	## do not).
	func _annotated(one: Dictionary, tiles: Array, height: int, studded: bool) -> Dictionary:
		var size := Vector2i(1, 1)
		for tile: Variant in tiles:
			var entry: Array = tile
			if str(entry[2]) == str(one["part"]) and int(entry[3]) == int(one["rot"]):
				size = Vector2i(int(entry[0]), int(entry[1]))
				break
		var cells: Array[Vector2i] = []
		for dx: int in size.x:
			for dz: int in size.y:
				cells.append(Vector2i(int(one["x"]) + dx, int(one["z"]) + dz))
		one["_cells"] = cells
		one["_h"] = height
		one["_studs"] = cells if studded else ([] as Array[Vector2i])
		one["_base"] = cells
		return one

	## Only the parts joined to the shape's foot by studs, each into a part
	## over it or under it: a plate a stud wide on the rim, its neighbours all
	## bricks, was laid as a 1 x 1 held by nothing, and a bird's tail tip came
	## out as a wedge with two tiles on it, joined to each other and nothing
	## else.
	func prune() -> void:
		var bottoms: Dictionary = {}    ## Vector3i(x, bottom, z) -> part
		for n: int in made.size():
			var one: Dictionary = made[n]
			var y: int = int(round(float(one["y"])))
			for cell: Vector2i in one.get("_base", []):
				bottoms[Vector3i(cell.x, y, cell.y)] = n
		var joined: Array = []
		for n: int in made.size():
			joined.append([])
		for n: int in made.size():
			var one: Dictionary = made[n]
			var y: int = int(round(float(one["y"])))
			var h: int = int(one.get("_h", 1))
			for cell: Vector2i in one.get("_studs", []):
				var above: int = int(bottoms.get(Vector3i(cell.x, y + h, cell.y), -1))
				if above >= 0 and above != n:
					(joined[n] as Array).append(above)
					(joined[above] as Array).append(n)
		var reached: Dictionary = {}
		var stack: Array = []
		var lowest: int = 1 << 30
		for one: Dictionary in made:
			lowest = mini(lowest, int(round(float(one["y"]))))
		for n: int in made.size():
			if int(round(float((made[n] as Dictionary)["y"]))) <= lowest:
				reached[n] = true
				stack.append(n)
		while not stack.is_empty():
			var n: int = stack.pop_back()
			for m: int in joined[n]:
				if not reached.has(m):
					reached[m] = true
					stack.append(m)
		var kept: Array = []
		for n: int in made.size():
			if reached.has(n):
				kept.append(made[n])
		made = kept

	## The parts in pieces, each an Array of indices into [member made], by
	## studs into the part over or under, largest first.
	func pieces() -> Array:
		var bottoms: Dictionary = {}
		for n: int in made.size():
			var one: Dictionary = made[n]
			for cell: Vector2i in one.get("_base", []):
				bottoms[Vector3i(cell.x, int(round(float(one["y"]))), cell.y)] = n
		var joined: Array = []
		for n: int in made.size():
			joined.append([])
		for n: int in made.size():
			var one: Dictionary = made[n]
			var top: int = int(round(float(one["y"]))) + int(one.get("_h", 1))
			for cell: Vector2i in one.get("_studs", []):
				var above: int = int(bottoms.get(Vector3i(cell.x, top, cell.y), -1))
				if above >= 0 and above != n:
					(joined[n] as Array).append(above)
					(joined[above] as Array).append(n)
		var seen: Dictionary = {}
		var out: Array = []
		for start: int in made.size():
			if seen.has(start):
				continue
			var piece: Array = []
			var queue: Array = [start]
			seen[start] = true
			while not queue.is_empty():
				var n: int = queue.pop_back()
				piece.append(n)
				for m: int in joined[n]:
					if not seen.has(m):
						seen[m] = true
						queue.append(m)
			out.append(piece)
		out.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		return out

	## Join a piece that stands apart to the rest: somewhere it has a plate or
	## a brick beside one of the rest's, at the same height, the two are laid
	## again as parts one of which reaches across — and the same at the
	## mirror. A car's nose stood on its own past the wheel arch, joined to
	## the body by nothing over the arch's thin bridge.
	func stitch() -> void:
		for _round: int in 48:
			var found: Array = pieces()
			if found.size() <= 1:
				break
			var main: Dictionary = {}
			for n: int in found[0]:
				main[n] = true
			var joined_one: bool = false
			for piece: Array in found.slice(1):
				var pair: Array = _pair(piece, main)
				if pair.is_empty():
					continue
				var twin: Array = _mirror_pair(pair)
				var gone: Dictionary = {pair[0]: true, pair[1]: true}
				var added: Array = _across(made[pair[0]], made[pair[1]])
				if added.is_empty():
					continue
				if not twin.is_empty() and not gone.has(twin[0]) and not gone.has(twin[1]):
					var mirrored: Array = _across(made[twin[0]], made[twin[1]])
					if not mirrored.is_empty():
						gone[twin[0]] = true
						gone[twin[1]] = true
						added.append_array(mirrored)
				var kept: Array = []
				for n: int in made.size():
					if not gone.has(n):
						kept.append(made[n])
				kept.append_array(added)
				made = kept
				joined_one = true
				break
			if not joined_one:
				break

	## A part of [param piece] and one of the rest side by side: the same
	## height, colour and kind (studded plates or bricks), touching along an
	## edge. [] when there is none.
	func _pair(piece: Array, main: Dictionary) -> Array:
		var by_cell: Dictionary = {}
		for n: Variant in main:
			var one: Dictionary = made[n]
			if not _plain(one):
				continue
			for cell: Vector2i in one["_cells"]:
				by_cell[Vector3i(cell.x, int(round(float(one["y"]))), cell.y)] = n
		for n: int in piece:
			var one: Dictionary = made[n]
			if not _plain(one):
				continue
			var y: int = int(round(float(one["y"])))
			for cell: Vector2i in one["_cells"]:
				for step: Vector2i in Shapes.OUT:
					var other: int = int(by_cell.get(Vector3i(cell.x + step.x, y, cell.y + step.y), -1))
					if other < 0:
						continue
					var two: Dictionary = made[other]
					if int(two["_h"]) == int(one["_h"]) and int(two["color"]) == int(one["color"]):
						return [n, other]
		return []

	## A plate, a brick or a top tile: what can be laid again over the same
	## studs as other plates, bricks or tiles. Not a slope or a wedge.
	func _plain(one: Dictionary) -> bool:
		if not one.has("_cells") or (one["_cells"] as Array).is_empty() or bool(one.get("_slope", false)):
			return false
		var studs: int = (one["_studs"] as Array).size()
		return studs == (one["_cells"] as Array).size() or (studs == 0 and bool(one.get("_top", false)))

	## The parts that are the mirror of a pair, or [].
	func _mirror_pair(pair: Array) -> Array:
		if axis.is_empty():
			return []
		var out: Array = []
		for n: int in pair:
			var one: Dictionary = made[n]
			var want: Dictionary = {}
			for cell: Vector2i in one["_cells"]:
				want[reflect(cell)] = true
			var hit: int = -1
			for m: int in made.size():
				var two: Dictionary = made[m]
				if two.get("part") != one.get("part") or float(two["y"]) != float(one["y"]) \
						or not two.has("_cells"):
					continue
				var cells: Array = two["_cells"]
				if cells.size() != want.size():
					continue
				var same: bool = true
				for cell: Vector2i in cells:
					if not want.has(cell):
						same = false
						break
				if same:
					hit = m
					break
			if hit < 0:
				return []
			out.append(hit)
		return out

	## Two side-by-side parts laid again over the same studs, the first part
	## laid the largest that covers a stud of each.
	func _across(one: Dictionary, two: Dictionary) -> Array:
		var height: int = int(one["_h"])
		var tiles: Array = Shapes.CORE_PLATES if height == 1 else Shapes.CORE_BRICKS
		# A top tile beside a plate nothing stands on: the two laid again as
		# tiles, one reaching across, so the top stays smooth. A tile holds
		# what is under both its ends as a plate does.
		var smooth_top: bool = height == 1 and (bool(one.get("_top", false)) \
			or bool(two.get("_top", false)))
		if smooth_top:
			var y_over: int = int(round(float(one["y"]))) + 1
			for other: Dictionary in made:
				if int(round(float(other["y"]))) != y_over:
					continue
				for cell: Vector2i in other.get("_base", []):
					if (one["_cells"] as Array).has(cell) or (two["_cells"] as Array).has(cell):
						smooth_top = false
			if smooth_top:
				tiles = Shapes.TOPS
		var cells: Dictionary = {}
		var first: Dictionary = {}
		for cell: Vector2i in one["_cells"]:
			cells[cell] = true
			first[cell] = true
		for cell: Vector2i in two["_cells"]:
			cells[cell] = true
		var y: int = int(round(float(one["y"])))
		var colour: int = int(one["color"])
		for tile: Variant in tiles:
			var entry: Array = tile
			var wide: int = entry[0]
			var deep: int = entry[1]
			for key: Variant in cells:
				var corner: Vector2i = key
				var fits: bool = true
				var mine: int = 0
				for i: int in wide:
					for k: int in deep:
						var at_: Vector2i = corner + Vector2i(i, k)
						if not cells.has(at_):
							fits = false
						elif first.has(at_):
							mine += 1
				if not fits or mine == 0 or mine == wide * deep:
					continue
				var rest: Dictionary = cells.duplicate()
				for i: int in wide:
					for k: int in deep:
						rest.erase(corner + Vector2i(i, k))
				var laid: Dictionary = {}
				var out: Array = [_annotated({"part": entry[2], "color": colour, "x": corner.x,
					"y": y, "z": corner.y, "rot": entry[3]}, tiles, height, not smooth_top)]
				for part: Dictionary in _tile(rest, y, colour, tiles, laid, -1):
					out.append(_annotated(part, tiles, height, not smooth_top))
				if smooth_top:
					for part: Dictionary in out:
						part["_top"] = true
				if rest.is_empty():
					return out
		return []

	func _free(covered: Dictionary, cell: Vector2i, j: int) -> bool:
		var key := Vector3i(cell.x, j, cell.y)
		return not covered.has(key) and not taken.has(key)

	## Wedge plates where a plate layer's plan edge is the shape of one, each
	## laid with its mirror; the studs they cover come out of [param cells].
	func _wedged(cells: Dictionary, j: int, height: int = 1) -> Array:
		if cells.size() < 4 or library == null:
			return []
		var shapes: Dictionary = Patterns.wedge_shapes(library) if height == 1 \
			else Shapes.brick_wedges(library)
		if shapes.is_empty():
			return []
		var by_colour: Dictionary = {}
		for key: Variant in cells:
			var c: int = cells[key]
			if not by_colour.has(c):
				by_colour[c] = {}
			(by_colour[c] as Dictionary)[key] = true
		var out: Array = []
		# Every stud of the shape at this plate, laid or not: a wedge's cut
		# side has to be outside the shape, not just outside the plates —
		# the first ones put their cut into the bricks beside them.
		var solid: Dictionary = {}
		for key: Variant in columns:
			for n: int in height:
				if at(key, j + n) >= 0:
					solid[key] = true
		# And every stud a slope stands over at this plate: an inverted slope
		# under an overhang reaches out past the shape, and a wedge cut into
		# it there overlapped it.
		for key: Variant in taken:
			var where: Vector3i = key
			if where.y >= j and where.y < j + height:
				solid[Vector2i(where.x, where.z)] = true
		var taken_here: Dictionary = {}
		for c: Variant in by_colour:
			var whole: Dictionary = by_colour[c]
			var wanted: Dictionary = whole.duplicate()
			var low := Vector2i(1 << 30, 1 << 30)
			var high := Vector2i(-(1 << 30), -(1 << 30))
			for key: Variant in whole:
				var cell: Vector2i = key
				low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
				high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
			var order: Array = shapes.keys()
			order.sort_custom(func(a: String, b: String) -> bool:
				var one: int = (shapes[a][2] as Dictionary).size()
				var two: int = (shapes[b][2] as Dictionary).size()
				return one > two if one != two else a < b)
			for named: String in order:
				var shape: Array = shapes[named]
				for cx: int in range(low.x - int(shape[0]) + 1, high.x + 1):
					for cz: int in range(low.y - int(shape[1]) + 1, high.y + 1):
						var corner := Vector2i(cx, cz)
						if not Patterns._wedge_fits(shape, corner, solid, wanted, taken_here) \
								or not _diagonal(shape, corner, solid, j, height):
							continue
						var family: Array = [[named, corner]]
						if not axis.is_empty():
							var twin: Array = _twin(shapes, named, corner)
							if twin.is_empty():
								continue
							if twin[0] != named or twin[1] != corner:
								if not Patterns._wedge_fits(shapes[twin[0]], twin[1], solid, wanted,
										taken_here) or Patterns._overlaps(shape, corner,
										shapes[twin[0]], twin[1]):
									continue
								family.append(twin)
						for member: Array in family:
							var laid: Dictionary = {}
							Patterns._claim(shapes[member[0]], member[1], wanted, laid, taken_here)
							for key: Variant in laid:
								cells.erase(key)
							var one: Dictionary = Patterns._placement(member[0], shapes[member[0]],
								member[1], j, int(c))
							var studs: Array[Vector2i] = []
							for key: Variant in laid:
								studs.append(key)
							one["_cells"] = studs
							one["_h"] = height
							one["_studs"] = studs
							one["_base"] = studs
							one["_slope"] = true
							out.append(one)
		return out

	## Whether a wedge's cut side follows the shape's own edge: every stud of
	## its box it does not cover is a fifth to four fifths inside the shape at
	## this plate, as a stud the edge cuts across on the diagonal is. Beside a
	## straight edge it is outside altogether, and the first wedges laid there
	## stood out from a car's flat side as fins.
	func _diagonal(shape: Array, corner: Vector2i, _solid: Dictionary, j: int,
			height: int = 1) -> bool:
		if not sample.is_valid():
			return true
		var cells: Dictionary = shape[2]
		for i: int in int(shape[0]):
			for k: int in int(shape[1]):
				if cells.has(Vector2i(i, k)):
					continue
				var at_: Vector2i = corner + Vector2i(i, k)
				var inside: int = 0
				for u: int in 3:
					for v: int in 3:
						if sample.call(at_.x + (u + 0.5) / 3.0, j + height / 2.0,
								at_.y + (v + 0.5) / 3.0):
							inside += 1
				if inside < 2 or inside > 7:
					return false
		return true

	## The wedge that is this one's mirror across the plane, as [name, corner]:
	## the same box reflected, its plan — what the part covers, at half a stud
	## — the reflection of this one's. By studs alone a 2 x 3 wing found
	## itself: its left hand turned half round has the same three studs as its
	## right hand, the cut running the other way, and the check called the
	## pair lopsided.
	func _twin(shapes: Dictionary, named: String, corner: Vector2i) -> Array:
		var shape: Array = shapes[named]
		var across_: int = int(shape[0])
		var deep: int = int(shape[1])
		var far: Vector2i = corner + Vector2i(across_ - 1, deep - 1)
		var one: Vector2i = reflect(corner)
		var two: Vector2i = reflect(far)
		var low := Vector2i(mini(one.x, two.x), mini(one.y, two.y))
		var mirrored: String = Shapes.wedge_plan(library, named, axis)
		if mirrored.is_empty():
			return []
		for candidate: Variant in shapes:
			var name: String = candidate
			var other: Array = shapes[name]
			if int(other[0]) != across_ or int(other[1]) != deep:
				continue
			if Shapes.wedge_plan(library, name, "") == mirrored:
				return [name, low]
		return []

	## One layer of the core: by colour, a strip across the middle tying the
	## two halves, one half laid and the other its mirror.
	func _layer(cells: Dictionary, j: int, tiles: Array, course: int) -> Array:
		var out: Array = []
		var by_colour: Dictionary = {}
		for key: Variant in cells:
			var c: int = cells[key]
			if not by_colour.has(c):
				by_colour[c] = {}
			(by_colour[c] as Dictionary)[key] = true
		# Plates in one layer turned the other way from the layer under them,
		# and tried from the other side: laid the same way every layer, the
		# outside row of a bird's body came out as strips along it, every
		# layer, tied to nothing inside and reported floating.
		if course < 0:
			tiles = _alternate(tiles, j)
		for c: Variant in by_colour:
			var wanted: Dictionary = _ordered(by_colour[c], j)
			var laid: Dictionary = {}
			if axis.is_empty():
				out.append_array(_tile(wanted, j, int(c), tiles, laid, course))
				continue
			var middle: Vector2i = spine(j)
			var strip: Dictionary = {}
			var half: Dictionary = {}
			for key: Variant in wanted:
				var cell: Vector2i = key
				var a: int = across(cell)
				if a >= middle.x and a <= middle.y:
					strip[cell] = true
				elif a * 2 < sum:
					half[cell] = true
			var width: int = middle.y - middle.x + 1
			var spanning: Array = []
			for tile: Variant in tiles:
				var one: Array = tile
				if (int(one[1]) if axis == "z" else int(one[0])) == width:
					spanning.append(one)
			if not strip.is_empty():
				out.append_array(_tile(strip, j, int(c), spanning, laid, course))
				# What the strip could not take, one stud at a time, in pairs.
				for key: Variant in strip.keys():
					var cell: Vector2i = key
					if not strip.has(cell) or across(cell) * 2 > sum:
						continue
					var single: Dictionary = {cell: true}
					var side: Array = _tile(single, j, int(c), tiles, laid, course)
					out.append_array(side)
					if reflect(cell) != cell:
						for one: Dictionary in side:
							out.append(_reflected(one, tiles))
					strip.erase(cell)
					strip.erase(reflect(cell))
			var left: Array = _tile(_ordered(half, j), j, int(c), tiles, laid, course)
			out.append_array(left)
			for one: Dictionary in left:
				out.append(_reflected(one, tiles))
		return out

	## A layer's studs laid in parts: bricks in a bond as a wall is
	## (Patterns._tile), plates and tiles stud by stud, the stud with the
	## fewest free neighbours first and the largest part that covers it with
	## them. Largest-first over the whole layer took the open ground and left
	## the hemmed-in studs to 1 x 1s, a column of them up the edge of every
	## body, tied to nothing.
	func _tile(wanted: Dictionary, j: int, colour: int, tiles: Array, laid: Dictionary,
			course: int) -> Array:
		if course >= 0:
			return Patterns._tile(wanted, j, colour, tiles, {}, laid, course)
		var made_here: Array = []
		var order: Array = wanted.keys()
		var free_beside := func(cell: Vector2i) -> int:
			var n: int = 0
			for step: Vector2i in Shapes.OUT:
				if wanted.has(cell + step):
					n += 1
			return n
		var counts: Dictionary = {}
		for key: Variant in order:
			counts[key] = free_beside.call(key)
		order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(counts[a]) < int(counts[b]))
		for key: Variant in order:
			var cell: Vector2i = key
			if not wanted.has(cell):
				continue
			var placed: bool = false
			for tile: Variant in tiles:
				var one: Array = tile
				var wide: int = one[0]
				var deep: int = one[1]
				for dx: int in wide:
					for dz: int in deep:
						var corner: Vector2i = cell - Vector2i(dx, dz)
						var fits: bool = true
						for i: int in wide:
							for k: int in deep:
								if not wanted.has(corner + Vector2i(i, k)):
									fits = false
									break
							if not fits:
								break
						if not fits:
							continue
						for i: int in wide:
							for k: int in deep:
								wanted.erase(corner + Vector2i(i, k))
								laid[corner + Vector2i(i, k)] = true
						made_here.append({"part": one[2], "color": colour, "x": corner.x,
							"y": j, "z": corner.y, "rot": one[3]})
						placed = true
						break
					if placed:
						break
				if placed:
					break
		return made_here

	## Bricks with studs on one side for the outside row of a straight side
	## in course [param k]: studs whose way out is clear for this course and
	## the next, and whose stud over them is part of the side too, so the
	## tile on them lies flat over both. In runs along the side, 1 x 4, 1 x 2
	## and 1 x 1 (30414, 11211, 87087); one side of a mirror and the other its
	## reflection. They come out of [param bricks]; the core's next course
	## ties them in.
	func _panels(bricks: Dictionary, j: int, k: int) -> Array:
		var above: Dictionary = full(k + 1)
		var facing_of: Dictionary = {}
		for key: Variant in bricks:
			var cell: Vector2i = key
			if not above.has(cell) or bricks[cell] != at(cell, j + 3):
				continue
			var found := Vector2i.ZERO
			var count: int = 0
			for step: Vector2i in Shapes.OUT:
				var clear: bool = true
				for n: int in 6:
					if at(cell + step, j + n) >= 0 or taken.has(Vector3i(cell.x + step.x,
							j + n, cell.y + step.y)):
						clear = false
						break
				if clear:
					found = step
					count += 1
			if count == 1:
				facing_of[cell] = found
		var out: Array = []
		var done: Dictionary = {}
		var cells: Array = facing_of.keys()
		cells.sort()
		for key: Variant in cells:
			var cell: Vector2i = key
			if done.has(cell):
				continue
			if not axis.is_empty() and across(cell) * 2 > sum:
				continue
			var facing: Vector2i = facing_of[cell]
			var along := Vector2i(absi(facing.y), absi(facing.x))
			# The run this stud starts, along the side, on this side of the
			# plane or across it.
			var run: Array[Vector2i] = []
			var at_: Vector2i = cell
			while facing_of.get(at_) == facing and not done.has(at_) \
					and bricks.get(at_) == bricks[cell] \
					and (axis.is_empty() or across(at_) * 2 <= sum):
				run.append(at_)
				at_ += along
			var placed: int = 0
			while placed < run.size():
				var left: int = run.size() - placed
				var long: int = 4 if left >= 4 else (2 if left >= 2 else 1)
				# A stud on the plane stands alone, its own mirror.
				if not axis.is_empty():
					for n: int in long:
						if across(run[placed + n]) * 2 == sum:
							long = n if n > 0 else 1
							break
				var part: String = {4: "30414", 2: "11211", 1: "87087"}[long]
				var piece: Array[Vector2i] = []
				for n: int in long:
					piece.append(run[placed + n])
				out.append(_panel_brick(part, piece, facing, j, int(bricks[cell])))
				var twin: Array[Vector2i] = []
				if not axis.is_empty():
					for one: Vector2i in piece:
						twin.append(reflect(one))
				if not twin.is_empty() and not twin.has(piece[0]):
					var flipped: Vector2i = Vector2i(facing.x, -facing.y) if axis == "z" \
						else Vector2i(-facing.x, facing.y)
					out.append(_panel_brick(part, twin, flipped, j, int(bricks[cell])))
					for one: Vector2i in twin:
						done[one] = true
				for one: Vector2i in piece:
					done[one] = true
				placed += long
		for one: Dictionary in out:
			for cell: Vector2i in one["_cells"]:
				bricks.erase(cell)
		return out

	func _panel_brick(part: String, cells: Array[Vector2i], facing: Vector2i, j: int,
			colour: int) -> Dictionary:
		var low := Vector2i(1 << 30, 1 << 30)
		for one: Vector2i in cells:
			low = Vector2i(mini(low.x, one.x), mini(low.y, one.y))
		var way: String = {Vector2i(0, 1): "+z", Vector2i(1, 0): "+x", Vector2i(0, -1): "-z",
			Vector2i(-1, 0): "-x"}[facing]
		return {"part": part, "color": colour, "x": low.x, "y": j, "z": low.y,
			"rot": 0 if facing.x == 0 else 1, "panel": way, "_cells": cells, "_h": 3,
			"_studs": cells, "_base": cells}

	## [param cells] in the order a layer's parts are tried at: along x on
	## even plates, along z on odd ones.
	func _ordered(cells: Dictionary, j: int) -> Dictionary:
		var keys: Array = cells.keys()
		if j % 2 == 0:
			keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return a.x < b.x or a.x == b.x and a.y < b.y)
		else:
			keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return a.y < b.y or a.y == b.y and a.x < b.x)
		var out: Dictionary = {}
		for key: Variant in keys:
			out[key] = cells[key]
		return out

	## The plates in the order to try them on plate [param j]: each part
	## turned across before along on odd plates, as a bonded course turns
	## its corners.
	func _alternate(tiles: Array, j: int) -> Array:
		if j % 2 == 0:
			return tiles
		return Patterns._corners_turn(tiles, 1)

	## A core part reflected across the plane: its far corner, mirrored.
	func _reflected(one: Dictionary, tiles: Array) -> Dictionary:
		var size := Vector2i(1, 1)
		for tile: Variant in tiles:
			var entry: Array = tile
			if str(entry[2]) == str(one["part"]) and int(entry[3]) == int(one["rot"]):
				size = Vector2i(int(entry[0]), int(entry[1]))
				break
		var twin: Dictionary = one.duplicate()
		if axis == "z":
			twin["z"] = sum - int(one["z"]) - size.y + 1
		else:
			twin["x"] = sum - int(one["x"]) - size.x + 1
		return twin
