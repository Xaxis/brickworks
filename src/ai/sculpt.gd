## A rounded body said as a simple solid, and laid by Brickify.
##
## Three levers changed how the designer worked on a round body (a better
## search, the outline guide, a measure of its side) and none changed what it
## made: laid course by course by hand, a pig, a potato or a rabbit came out a
## can, a column or a stack of drums, and the judge said so in most of the
## verdicts lost to BrickAgent (docs/BRICKBENCH.md, 2026-10-22 to 10-23).
## Brickify already lays a sculpted surface from a shape: slopes and curved
## slopes fitted to how the surface falls, inverted ones under it, its steep
## sides on their sides on side studs, mended into one piece. So a design says
## the body as solids, and this makes their surface and has Brickify lay it:
##
##   ellipsoid       a ball stretched to its size
##   egg             an ellipsoid narrower at one end ("point")
##   capsule         a round-ended cylinder along its axis
##   superellipsoid  between an ellipsoid and a box ("power" 2 to 6): a plump
##                   loaf, a pig's barrel of a body, a block-headed character
##
## any number joined (a body and its head, a pear's two lobes, a snowman's
## balls), each with its own colour if it wants one. Studs across and deep and
## plates up, a solid's centre and its whole size. What comes back is plain
## bricks for the design, which it details with its own tools after.
class_name Sculpt
extends RefCounted

const KINDS: PackedStringArray = ["ellipsoid", "egg", "capsule", "superellipsoid"]
## Rings along a solid's axis and segments round it: a 32-stud body is a
## stud a segment, finer than the third of a stud Brickify samples a curve at
## only where it already turns slowly.
const ALONG := 40
const AROUND := 64
## How much narrower an egg's point is than its other end, unless said.
const EGG_TAPER := 0.3
## A superellipsoid's power unless said: a loaf, rounder than a box.
const POWER := 3.0
## Brickify's bounds: a body smaller than this along its longest side is a
## few round parts, not a sculpt.
const LEAST := Brickify.LEAST_STUDS
const MOST := 40
## Studs along its longest side from which its steep sides are laid on their
## sides on side studs (Brickify.Options.snot).
const SNOT_FROM := 20


## The solids [param raw] says, each {"kind", "centre" (studs, plates,
## studs), "half" (half its size, the same units), "axis" (0 x, 1 y, 2 z),
## "point" (+1 or -1 along it: an egg's narrow end), "taper", "power",
## "color"}; why one could not be read goes in [param trouble].
static func solids_of(raw: Dictionary, trouble: Array) -> Array:
	var out: Array = []
	var listed: Variant = raw.get("solids", [])
	if not listed is Array or (listed as Array).is_empty():
		trouble.append("a sculpt wants its \"solids\": [{\"egg\": {\"centre\": [x, y, z], "
			+ "\"size\": [studs across, plates tall, studs deep]}}, ...], each an ellipsoid, an "
			+ "egg, a capsule or a superellipsoid")
		return out
	for item: Variant in listed:
		if not item is Dictionary:
			trouble.append("each of a sculpt's solids is an object, as {\"ellipsoid\": {...}}")
			continue
		var one: Dictionary = item
		var kind: String = str(one.get("kind", "")).to_lower()
		var spec: Dictionary = one
		if kind.is_empty():
			for key: Variant in one:
				if str(key).to_lower() in KINDS and one[key] is Dictionary:
					kind = str(key).to_lower()
					spec = (one[key] as Dictionary).duplicate()
					# A colour said beside the kind rather than in it.
					if one.has("color") and not spec.has("color"):
						spec["color"] = one["color"]
		if not kind in KINDS:
			trouble.append("a sculpt's solid is one of %s, not %s" % [", ".join(KINDS),
				JSON.stringify(one).left(80)])
			continue
		var centre: Variant = _vector(spec.get("centre", spec.get("center")))
		var size: Variant = _vector(spec.get("size"))
		if size == null and _vector(spec.get("radii")) != null:
			size = (_vector(spec.get("radii")) as Vector3) * 2.0
		if centre == null or size == null:
			trouble.append("a sculpt's %s wants \"centre\": [x, y, z] and \"size\": [studs "
				% kind + "across, plates tall, studs deep]")
			continue
		var whole: Vector3 = size
		if whole.x < 1.0 or whole.y < 2.5 or whole.z < 1.0:
			trouble.append("a sculpt's %s of %s is too small: at least a stud across and "
				% [kind, _said_size(whole)] + "deep and 3 plates tall")
			continue
		var axis_said: String = str(spec.get("axis", "")).to_lower().trim_prefix("+")
		var axis: int = {"x": 0, "y": 1, "z": 2}.get(axis_said, -1)
		var point: int = 1
		var point_said: String = str(spec.get("point", "")).to_lower()
		if point_said.length() == 2 and point_said[1] in ["x", "y", "z"]:
			axis = {"x": 0, "y": 1, "z": 2}[point_said[1]]
			point = -1 if point_said[0] == "-" else 1
		if axis < 0:
			# Along its longest, counting plates as studs.
			var studs := Vector3(whole.x, whole.y / Shapes.PLATES_PER_STUD, whole.z)
			axis = 1 if kind == "egg" else (0 if studs.x >= studs.y and studs.x >= studs.z
				else (1 if studs.y >= studs.z else 2))
		out.append({"kind": kind, "centre": centre, "half": whole / 2.0, "axis": axis,
			"point": point,
			"taper": clampf(float(spec.get("taper", EGG_TAPER)), 0.0, 0.6),
			"power": clampf(float(spec.get("power", POWER)), 2.0, 8.0),
			"color": int(spec.get("color", spec.get("colour", -1)))})
	return out


static func _vector(value: Variant) -> Variant:
	if value is Array and (value as Array).size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary and (value as Dictionary).has_all(["x", "y", "z"]):
		return Vector3(float(value["x"]), float(value["y"]), float(value["z"]))
	return null


static func _said_size(size: Vector3) -> String:
	return "%s x %s plates x %s" % [Shapes._num(size.x), Shapes._num(size.y),
		Shapes._num(size.z)]


## How far out a solid reaches at [param t] along its axis (-1 to 1), as a
## share of its half size across: the profile its surface is turned on.
static func _profile(solid: Dictionary, t: float) -> float:
	t = clampf(t, -1.0, 1.0)
	match str(solid["kind"]):
		"egg":
			# Widest a little toward the blunt end; scaled so its widest is 1.
			var k: float = float(solid["taper"]) * int(solid["point"])
			var r: float = sqrt(1.0 - t * t) * (1.0 - k * t * 0.5)
			return r / _egg_widest(float(solid["taper"]))
		"capsule":
			# Its caps as long as it is half wide, or half its length if shorter.
			var half: Vector3 = solid["half"]
			var axis: int = solid["axis"]
			var across: float = 0.0
			var along: float = _studs(half)[axis]
			for n: int in 3:
				if n != axis:
					across = maxf(across, _studs(half)[n])
			var cap: float = clampf(across / maxf(along, 0.001), 0.0, 1.0)
			var into: float = absf(t) - (1.0 - cap)
			return 1.0 if into <= 0.0 else sqrt(maxf(0.0, 1.0 - (into / cap) * (into / cap)))
		"superellipsoid":
			var e: float = float(solid["power"])
			return pow(maxf(0.0, 1.0 - pow(absf(t), e)), 1.0 / e)
	return sqrt(maxf(0.0, 1.0 - t * t))


static func _egg_widest(taper: float) -> float:
	var best: float = 0.0
	for n: int in 201:
		var t: float = -1.0 + n / 100.0
		best = maxf(best, sqrt(1.0 - t * t) * (1.0 + taper * t * 0.5))
	return maxf(best, 0.001)


## A half size in studs every way: plates up counted as studs.
static func _studs(half: Vector3) -> Vector3:
	return Vector3(half.x, half.y / Shapes.PLATES_PER_STUD, half.z)


## The solids' surfaces as one mesh, in studs every way (y up), each corner
## coloured as its solid by [param rgb] (LDraw code -> Color). Joined solids
## overlap: Brickify keeps what is inside any of them.
static func mesh_of(solids: Array, rgb: Callable) -> MeshFile:
	var mesh := MeshFile.new()
	mesh.name = "sculpt"
	mesh.up = "+Y"
	for solid: Dictionary in solids:
		var axis: int = solid["axis"]
		var half: Vector3 = _studs(solid["half"])
		var centre: Vector3 = solid["centre"] * Vector3(1.0, 1.0 / Shapes.PLATES_PER_STUD, 1.0)
		var colour: Color = rgb.call(int(solid["color"]))
		var cross: float = float(solid["power"]) if str(solid["kind"]) == "superellipsoid" else 2.0
		# The two axes across this one, in turn.
		var a: int = (axis + 1) % 3
		var b: int = (axis + 2) % 3
		var rings: Array = []
		for i: int in ALONG + 1:
			# Closer together toward the ends, where the surface turns fastest.
			var t: float = -cos(PI * i / ALONG)
			var r: float = _profile(solid, t)
			var ring := PackedVector3Array()
			for k: int in AROUND:
				var angle: float = TAU * k / AROUND
				var c: float = cos(angle)
				var s: float = sin(angle)
				var p := Vector3.ZERO
				p[axis] = t * half[axis]
				p[a] = signf(c) * pow(absf(c), 2.0 / cross) * r * half[a]
				p[b] = signf(s) * pow(absf(s), 2.0 / cross) * r * half[b]
				ring.append(centre + p)
			rings.append(ring)
		for i: int in ALONG:
			var low: PackedVector3Array = rings[i]
			var high: PackedVector3Array = rings[i + 1]
			for k: int in AROUND:
				var k2: int = (k + 1) % AROUND
				_triangle(mesh, low[k], high[k], high[k2], colour, centre)
				_triangle(mesh, low[k], high[k2], low[k2], colour, centre)
	mesh.coloured = true
	return mesh


## One triangle, wound to face out from [param inside], its normals the
## surface's own round it (each corner's from its centre is near enough for
## Brickify, which asks only whether a facet is flat).
static func _triangle(mesh: MeshFile, p: Vector3, q: Vector3, r: Vector3, colour: Color,
		inside: Vector3) -> void:
	var face: Vector3 = (q - p).cross(r - p)
	if face.length_squared() < 0.00000001:
		return
	if face.dot((p + q + r) / 3.0 - inside) < 0.0:
		var swap: Vector3 = q
		q = r
		r = swap
	for corner: Vector3 in [p, q, r]:
		mesh.positions.append(corner)
		mesh.normals.append((corner - inside).normalized())
		mesh.colours.append(colour)
		mesh.uvs.append(Vector2.ZERO)
	mesh.texture_of.append(-1)


## The sculpt [param raw] laid: {"bricks" (placements as a design says them,
## where the solids are), "said" (what it came to, for the reply), "box"
## (AABB, studs and plates, of what was laid), "parts"}; {} with why in
## [param trouble] when it cannot be. [param checker] checks and mends it as
## Brickify checks a scan: one with the library and no world of its own.
## [param feet] are where the rest of the design stands (Patterns.feet_of:
## stud Vector2i(x, z) -> the plates its feet are at): where that is on the
## sculpt's top, its studs are left showing to take them.
static func lay(raw: Dictionary, checker: Assistant, trouble: Array,
		feet: Dictionary = {}) -> Dictionary:
	var solids: Array = solids_of(raw, trouble)
	if solids.is_empty() or not trouble.is_empty():
		return {}
	var library: PartLibrary = checker.library
	var colour: int = int(raw.get("color", raw.get("colour", -1)))
	var colours: Array[int] = []
	for solid: Dictionary in solids:
		if int(solid["color"]) < 0:
			solid["color"] = colour
		if int(solid["color"]) < 0:
			trouble.append("a sculpt wants a \"color\", for all of it or for each solid")
			return {}
		if not colours.has(int(solid["color"])):
			colours.append(int(solid["color"]))
	var mesh: MeshFile = mesh_of(solids, func(code: int) -> Color:
		var known: PartLibrary.BrickColor = library.color(code)
		return known.rgb if known != null else Color.MAGENTA)
	var box: AABB = mesh.bounds()
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var studs: int = roundi(longest)
	if studs < LEAST or studs > MOST:
		trouble.append(("a sculpt is %d to %d studs along its longest side (its height counted "
			% [LEAST, MOST]) + "in studs, 2.5 plates a stud), and this one is %s: %s" % [
			Shapes._num(snappedf(longest, 0.1)), "lay a body that small with round parts by hand "
			+ "(read_guide \"outline\")" if studs < LEAST else "say it in parts"])
		return {}
	# Scaled about its middle so its longest side is whole studs, and Brickify
	# lays it a stud to a stud.
	var middle: Vector3 = box.get_center()
	var grow: float = float(studs) / longest
	for n: int in mesh.positions.size():
		mesh.positions[n] = middle + (mesh.positions[n] - middle) * grow
	box = mesh.bounds()
	# Where the grid's corner will be in the design: the solids' box, its
	# middle kept where Brickify centres it in whole studs.
	var size: Vector3i = Brickify.size_in(box, studs)
	var shift := Vector3((size.x - box.size.x) / 2.0, 0.0, (size.z - box.size.z) / 2.0)
	var offset := Vector3(roundf(box.position.x - shift.x),
		roundf(box.position.y * Shapes.PLATES_PER_STUD), roundf(box.position.z - shift.z))
	var options := Brickify.Options.new()
	options.studs = studs
	options.stand = false
	# Its steep sides on their sides only on a body big enough for them: under
	# SNOT_FROM a turned side is a few side studs and tiles that stand out of
	# the curve, and a tenth to a third more parts than the same body upright.
	options.snot = studs >= SNOT_FROM
	for key: Variant in feet:
		var stud: Vector2i = key
		var cell := Vector2i(stud.x - roundi(offset.x), stud.y - roundi(offset.z))
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.z:
			continue
		var heights: Array = []
		for height: Variant in (feet[key] if feet[key] is Array else [feet[key]]):
			heights.append(int(height) - roundi(offset.y))
		options.carried[cell] = heights
	if colours.size() == 1:
		options.colours = "one"
		options.colour = colours[0]
	else:
		options.colours = "model"
		var palette: Array[int] = colours.duplicate()
		for code: int in Brickify.PALETTE:
			if not palette.has(code):
				palette.append(code)
		options.palette = PackedInt32Array(palette)
	# What the design's own shapes said is kept apart from what Brickify's
	# laying says to itself.
	var said_before: Array = Shapes.said.duplicate()
	var turned_before: int = Shapes.turned
	var result: Dictionary = Brickify.build(mesh, options, checker, null, false)
	Shapes.said = said_before
	Shapes.turned = turned_before
	if result.has("error") or not result.has("model"):
		trouble.append("the sculpt could not be laid: %s" % str(result.get("error", "nothing came of it")))
		return {}
	var model: Assistant.Model = result["model"]
	var grid: Brickify.Grid = result["grid"]
	var report: Dictionary = result["report"]
	var bricks: Array = []
	for placement: Assistant.Placement in model.placements:
		var one: Dictionary = {"part": placement.part, "color": placement.color,
			"x": placement.x + offset.x, "y": placement.y + offset.y,
			"z": placement.z + offset.z, "rot": placement.rot}
		if placement.face != "up":
			one["face"] = placement.face
		if placement.turn != Vector3.ZERO:
			one["yaw"] = placement.turn.x
			one["pitch"] = placement.turn.y
			one["roll"] = placement.turn.z
		bricks.append(one)
	var laid := AABB(offset, Vector3(grid.across, grid.tall, grid.deep))
	var pieces: int = int(report.get("pieces", 1))
	var said: String = ("The sculpt is %d parts laid by Brickify, x %s to %s, y %s to %s "
		% [bricks.size(), Shapes._num(laid.position.x), Shapes._num(laid.end.x),
			Shapes._num(laid.position.y), Shapes._num(laid.end.y)]
		+ "(plates), z %s to %s%s." % [Shapes._num(laid.position.z), Shapes._num(laid.end.z),
			", one piece" if pieces <= 1 else ", in %d pieces" % pieces])
	var coverage: float = float(report.get("coverage", 1.0))
	if coverage < 0.9:
		said += " It keeps %d%% of the solids: a part of it thinner than a stud is left out." \
			% roundi(coverage * 100.0)
	return {"bricks": bricks, "said": said, "box": laid, "parts": bricks.size(),
		"pieces": pieces, "coverage": coverage, "studs": studs}
