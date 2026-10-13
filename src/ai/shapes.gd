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
##   a round        where a layer is a disc 1, 2, 4, 6 or 8 studs across,
##                  the round parts the round pattern lays there (round
##                  plates and bricks, corner rounds round a ring), and a
##                  dish on a dome's crown
##   the top        tiles, so a body reads as a surface and not as studs
##   a flat side    every other course, bricks with studs on their side and a
##                  tile laid flat on them, as a set's flank is
##   a curved side  where it curves up and down, the bulge laid by this plan
##                  turned on its side, on studs out of the core
##   two sides      a shape that is its own mirror is laid as one half and
##                  its mirror, tied across the middle by parts that span it,
##                  so a left wing is never a stud out from a right one
##
## Nothing here knows what a car is.
class_name Shapes
extends RefCounted

## The kinds of solid a shape is made of.
const KINDS: Array[String] = ["loft", "extrude", "revolve", "box", "ellipsoid", "dome"]

## A solid given as a function instead of in numbers: a sculpt or a scan,
## voxelised by Brickify. {"grid": {"from", "size", "colour_at"}}, where
## colour_at(Vector3 studs, plates, studs) is the colour there or -1 outside.
## Not one of KINDS: a design says its solids, it has no function to give.
const GRID := "grid"

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
	var faces: Array = _read_faces(pattern, y0, trouble)
	if not trouble.is_empty():
		return []
	# A grid solid says how many cells it has, having been sized to them.
	var most: int = maxi(MOST_CELLS, int(pattern.get("most_cells", 0)))
	if (x1 - x0) * (z1 - z0) * tall > most or tall < 1:
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

	# A sculpt's grid has no sections said round: a scan's 2 x 2 is as likely
	# a square leg as a round one, and Brickify's own lay is left as it was.
	var gridded: bool = false
	for solid: Dictionary in solids:
		gridded = gridded or solid["kind"] == GRID
	var build := func(sideways: bool) -> Array:
		var plan := Plan.new(columns.duplicate(true), tall, smooth, library)
		plan.sides_smooth = bool(pattern.get("panels", true))
		plan.wedges = bool(pattern.get("wedges", true))
		if pattern.get("prefer") is Callable:
			plan.prefer = pattern["prefer"]
		plan.sample = func(x: float, j: float, z: float) -> bool:
			return _colour_at(solids, cuts, Vector3(x, y0 + j, z), colour, bands) >= 0
		# Studs left showing on the studs named, [x, z] from at, for something to
		# stand on: a tower on its plinth stands on bricks, not on tiles.
		for raw: Variant in pattern.get("studs_at", []):
			if raw is Array and (raw as Array).size() >= 2:
				var cell := Vector2i(int(raw[0]), int(raw[1]))
				if columns.has(cell):
					plan.studded[cell] = true
		# And where another shape of the same design stands on this one's
		# top: a car's cabin said as a shape on its body stood on the body's
		# tiles, gripping nothing, and the run threw the body away.
		var carried: Dictionary = pattern.get("_carried", {})
		for key: Variant in columns:
			var cell: Vector2i = key
			var world := Vector2i(cell.x + roundi(origin.x), cell.y + roundi(origin.z))
			if not carried.has(world):
				continue
			var column: PackedInt32Array = columns[cell]
			for j: int in range(tall - 1, -1, -1):
				if column[j] >= 0:
					if roundi(origin.y) + y0 + j + 1 == int(carried[world]):
						plan.studded[cell] = true
					break
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
		plan.colour_at = func(x: float, j: float, z: float) -> int:
			return _colour_at(solids, cuts, Vector3(x, y0 + j, z), colour, bands)
		plan.rounds = bool(pattern.get("rounds", not gridded))
		plan.bridges = bool(pattern.get("bridges", not gridded))
		plan.faces = faces
		plan.mirror_of()
		last = {"mirror": plan.axis, "sum": plan.sum, "columns": columns.size(), "plates": tall}
		plan.round_runs()
		last["rounds"] = plan.round_made.size()
		last["round_runs"] = plan.round_said
		var shells: Array = []
		if sideways:
			shells = plan.shells()
			# A shell whose side studs hold less than most of what it took out
			# of the core is laid upright instead: on a body three and a half
			# plates tall (a minifigure-scale car) the rows and the side studs
			# found little to hold, and the shells kept 5 of their 74 parts, the
			# body "eroded into a narrow strip".
			# A side and its mirror are kept or given back together, on what
			# the two cover between them: a hull kept one flank at 65% and gave
			# the other back at 59%, and came out lopsided.
			var covered: Dictionary = {}    ## facing -> share
			for shell: Dictionary in shells:
				plan.lay_shell(shell, "straight" if surface == "none" else surface, true)
				covered[shell["facing"]] = float(shell.get("covered", 0.0))
			var held: Array = []
			for shell: Dictionary in shells:
				var facing: Vector2i = shell["facing"]
				var share: float = covered[facing]
				var twin := Vector2i(facing.x, -facing.y) if plan.axis == "z" \
					else Vector2i(-facing.x, facing.y)
				if not plan.axis.is_empty() and twin != facing and covered.has(twin):
					share = (share + float(covered[twin])) / 2.0
				if share >= Plan.SHELL_KEEPS:
					held.append(shell)
				else:
					plan.drop_shell(shell)
					plan.kept.append("%s given back, %d%% of its plates held" % [str(facing),
						roundi(100.0 * float(covered[facing]))])
			shells = held
		if surface != "none":
			plan.surface(surface)
		plan.lay()
		# A model standing on legs is pieces at its foot that meet the body above
		# only side by side: pruned first from the foot, a bunny on its feet kept
		# its feet and lost the rest. Joined first, then pruned.
		if bool(pattern.get("stitch_first", false)):
			plan.stitch()
		plan.prune()
		plan.stitch()
		return [plan, shells]
	var built: Array = build.call(bool(pattern.get("sideways", not gridded)))
	var plan: Plan = built[0]
	var shells: Array = built[1]
	# Turning a side out must not cut the core in two: a car's arches left
	# a body six studs wide over them, and it came apart in ten pieces.
	# Laid upright again where it does.
	if not shells.is_empty() and plan.pieces().size() > 1:
		var upright: Array = build.call(false)
		if (upright[0] as Plan).pieces().size() < plan.pieces().size():
			plan = upright[0]
			shells = []
	var pieces: Array = plan.pieces()
	last["pieces"] = pieces.size()
	# Where each piece but the largest is, for a probe to say: parts, and
	# the low and high corner in studs and plates.
	var apart: Array = []
	for piece: Array in pieces.slice(1):
		var low := Vector3(INF, INF, INF)
		var high := -low
		for n: int in piece:
			var one: Dictionary = plan.made[n]
			var p := Vector3(float(one["x"]), float(one["y"]), float(one["z"]))
			low = low.min(p)
			high = high.max(p)
		apart.append([piece.size(), low + origin + Vector3(0, y0, 0), high + origin + Vector3(0, y0, 0)])
	last["apart"] = apart
	var made: Array = plan.made
	var turned_out: int = 0
	for shell: Dictionary in shells:
		var laid: Array = plan.lay_shell(shell, "straight" if surface == "none" else surface)
		turned_out += laid.size()
		made = made + laid
	last["shells"] = shells.size()
	last["sideways"] = turned_out
	last["shells_kept"] = plan.kept
	last["faces"] = plan.faces_laid
	# A face that found no curved side with side studs to sit on is said,
	# not dropped: a head laid without the face it was given reads as done.
	for asked: Dictionary in faces:
		if not plan.faces_laid.has(asked["said"]):
			trouble.append("the face %s has nothing to sit on: %s. A face goes on a "
				% [asked["said"], str(plan.faces_why.get(asked["said"],
					"no curved side faces that way, so no side studs are laid there"))]
				+ "side that curves out (an ellipsoid's front), its centre on that "
				+ "side's middle, at least a stud inside its edges all round")
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
		if one.has("face"):
			out["face"] = one["face"]
		placed.append(out)
	return placed


## Where a shape's foot is, stud by stud: world (x, z) -> the plate its
## lowest plate there stands on, for the shape under it to keep studs
## there. {} for a shape that cannot be read.
static func feet(pattern: Dictionary) -> Dictionary:
	var trouble: Array = []
	var solids: Array = _read(pattern, "solids", trouble, true)
	var cuts: Array = _read(pattern, "cuts", trouble, false)
	if not trouble.is_empty() or solids.is_empty():
		return {}
	var at: Dictionary = pattern.get("at", {}) as Dictionary
	var origin := Vector3(float(at.get("x", 0.0)), float(at.get("y", 0.0)), float(at.get("z", 0.0)))
	var box: AABB = solids[0]["box"]
	for solid: Dictionary in solids:
		box = box.merge(solid["box"])
	var size: Vector3 = box.size
	if size.x * size.y * size.z > MOST_CELLS:
		return {}
	var out: Dictionary = {}
	for x: int in range(floori(box.position.x), ceili(box.end.x)):
		for z: int in range(floori(box.position.z), ceili(box.end.z)):
			for y: int in range(floori(box.position.y), ceili(box.end.y)):
				if _colour_at(solids, cuts, Vector3(x + 0.5, y + 0.5, z + 0.5), 0, []) >= 0:
					out[Vector2i(x + roundi(origin.x), z + roundi(origin.z))] = y + roundi(origin.y)
					break
	return out


static func _empty(column: PackedInt32Array) -> bool:
	for value: int in column:
		if value >= 0:
			return false
	return true


## The ways a face can look out of a shape, by name.
const FACINGS: Dictionary = {"+x": Vector2i(1, 0), "-x": Vector2i(-1, 0),
	"+z": Vector2i(0, 1), "-z": Vector2i(0, -1)}
## A face's disc by how many studs across: a round plate, and the square
## plate that brings it out to the curve behind it.
const FACE_DISCS: Dictionary = {4: ["60474", "3031"], 6: ["11213", "3958"],
	8: ["74611", "41539"]}


## The faces a shape is given: {"facing": "+z", "x", "y", "z": its middle in
## the shape's studs and plates, "across": 4, 6 or 8, "color": the disc's,
## "rim": the plate behind it, "eyes": the iris, "beak": its colour or -1}.
## The plate of its middle is counted from the plan's foot ([param y0]).
static func _read_faces(pattern: Dictionary, y0: int, trouble: Array) -> Array:
	var asked: Variant = pattern.get("face", pattern.get("faces", []))
	if asked is Dictionary:
		asked = [asked]
	var out: Array = []
	if not asked is Array:
		return out
	for raw: Variant in asked:
		if not raw is Dictionary:
			trouble.append("a shape's face is an object: {\"facing\": \"+z\", \"x\", \"y\", "
				+ "\"z\", \"across\": 6}")
			continue
		var one: Dictionary = raw
		var facing: String = str(one.get("facing", "+z")).strip_edges().to_lower()
		var across: int = int(one.get("across", 4))
		if not FACINGS.has(facing):
			trouble.append("a face looks out +x, -x, +z or -z, not \"%s\"" % facing)
			continue
		if not FACE_DISCS.has(across):
			trouble.append("a face is 4, 6 or 8 studs across, the round plate that is its "
				+ "disc, not %d" % across)
			continue
		var centre: Vector3 = _vec(one.get("centre", [one.get("x", 0.0), one.get("y", 0.0),
			one.get("z", 0.0)]))
		out.append({"facing": FACINGS[facing], "x": centre.x, "j": centre.y - y0,
			"z": centre.z, "across": across, "color": int(one.get("color", -1)),
			"rim": int(one.get("rim", -1)), "eyes": int(one.get("eyes", 0)),
			"beak": int(one.get("beak", 19)),
			"said": "facing %s at %s, %s" % [facing, _num(centre.x), _num(centre.y)]
				if facing.ends_with("z") else "facing %s at %s, %s" % [facing,
					_num(centre.z), _num(centre.y)]})
	return out


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.1))


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
	var named: Array = KINDS + [GRID]
	for entry: Variant in raw:
		if not entry is Dictionary:
			trouble.append("each of a shape's %s is an object naming one kind: " % key
				+ ", ".join(PackedStringArray(KINDS)))
			continue
		var given: Dictionary = entry
		var kind: String = str(given.get("kind", ""))
		var spec: Dictionary = given
		for one: String in named:
			if given.get(one) is Dictionary:
				kind = one
				spec = (given[one] as Dictionary).duplicate()
				if given.has("color") and not spec.has("color"):
					spec["color"] = given["color"]
				break
		if not kind in named:
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
		GRID:
			var from: Vector3 = _vec(spec.get("from", [0, 0, 0]))
			var size: Vector3 = _vec(spec.get("size", [0, 0, 0]))
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0 \
					or not spec.get("colour_at") is Callable:
				trouble.append("a grid wants a size and a colour_at function")
				return {}
			solid["box"] = AABB(from, size)
			solid["round"] = bool(spec.get("round", true))
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
		if solid["kind"] == GRID:
			# Its own colour at every point, asked once.
			if (solid["box"] as AABB).grow(0.001).has_point(p):
				var here: int = int(((solid["spec"] as Dictionary)["colour_at"] as Callable).call(p))
				if here >= 0:
					found = here
			continue
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
		GRID:
			return int((spec["colour_at"] as Callable).call(p)) >= 0
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
	var d: int = foot.y if along_z else foot.x
	# The rows along its fall, from the high end, that a stud from below
	# reaches into, read as the check reads it: a little past the stud's tip.
	# A curved slope is hollow under its high end, so only its low rows grip;
	# upright it rests on its plates whatever they hold, but on its side it is
	# held by those rows or by nothing, and the owl's flanks were refused four
	# times for 11477s whose side stud stood under the hollow end.
	var grips: Array[int] = []
	for row: int in d:
		var n: int = row if native in [0, 1] else d - 1 - row
		var across: float = (b.position.z if along_z else b.position.x) + 10.0 + 20.0 * n
		var stud: float = (b.position.x if along_z else b.position.z) + 10.0
		var probe := Vector3(stud, b.position.y + 5.0, across) if along_z \
			else Vector3(across, b.position.y + 5.0, stud)
		# The cover is in the lattice's cells, the bounds in LDU.
		probe /= BrickLattice.CELL
		for box: AABB in mesh.boxes:
			if box.grow(0.01).has_point(probe):
				grips.append(row)
				break
	var found := {"id": id, "w": foot.x if along_z else foot.y, "d": d,
		"h": int(round((b.size.y - (4.0 if studded else 0.0)) / 8.0)),
		"turn": posmod(-native, 4), "grips": grips}
	_parts[key] = found
	return found


## What a plan's edge is laid in where it runs off the square, a plate tall
## and a brick tall. The round parts a set rounds a body with come first,
## where they fit: corner rounds 2 to 4 studs across. Then plates and bricks
## without a corner, cut at 45 degrees, and the wedges. Whole round plates
## and bricks (60474, 3941 and the rest), 30503 and the double wedges 41747
## and 43710 are not here: their collision cover is one square box, so the
## check would read each as a square, overlapping whatever follows the curve
## beside it.
const ROUND_PLATES: Array = ["30565", "30357", "79491"]
const EDGE_PLATES: Array = ["2450", "26601"]
const ROUND_BRICKS: Array = ["2577", "5152", "3063b"]
const EDGE_BRICKS: Array = ["30505", "6564", "6565", "41767", "41768"]

## How much of a stud each part and the shape cover, as 16 bits: a 4 x 4
## grid in the stud, bit v * 4 + u.
const FULL := 0xFFFF

## height -> "part rot" -> [across, deep, studs {cell: true}, covers
## {cell: bits}, the first stud it covers only in part, round].
static var _edge_parts: Dictionary = {}

## How many bits each 16-bit number has set.
static var _ones: PackedByteArray = PackedByteArray()


static func edge_parts(library: PartLibrary, height: int) -> Dictionary:
	if _edge_parts.has(height):
		return _edge_parts[height]
	var out: Dictionary = {}
	var round_ones: Array = ROUND_PLATES if height == 1 else ROUND_BRICKS
	var others: Array = (EDGE_PLATES + Patterns.WEDGES) if height == 1 else EDGE_BRICKS
	for part: Variant in round_ones + others:
		var base: Array = _covers(library, str(part))
		if base.is_empty():
			continue
		for rot: int in 4:
			var turned: Array = _cover_turned(base, rot)
			turned.append(round_ones.has(part))
			out["%s %d" % [str(part), rot]] = turned
	if library != null and not out.is_empty():
		_edge_parts[height] = out
	return out


## What a part covers in plan, read off its own mesh: [across, deep, the
## studs on its top, the bits of each stud of its box it covers, the first
## of them it covers only in part]. [] for a part that is not here, or that
## covers every stud it stands on whole, which a plate does as well.
static func _covers(library: PartLibrary, part: String) -> Array:
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	var mesh: Lbm.PartMesh = library.mesh_for(part) if info != null else null
	if mesh == null or mesh.boxes.is_empty():
		return []
	var foot: Vector2i = info.footprint_studs()
	var b: AABB = mesh.bounds
	var studs: Dictionary = {}
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male" \
				or connector.axis.normalized().dot(Vector3.UP) < 0.9:
			continue
		var at := Vector2i(int(floor((connector.position.x - b.position.x) / 20.0)),
			int(floor((connector.position.z - b.position.z) / 20.0)))
		if at.x >= 0 and at.y >= 0 and at.x < foot.x and at.y < foot.y:
			studs[at] = true
	var covers: Dictionary = {}
	for i: int in foot.x:
		for k: int in foot.y:
			var bits: int = 0
			for v: int in 4:
				for u: int in 4:
					var x: float = b.position.x + 20.0 * i + 5.0 * u + 2.5
					var z: float = b.position.z + 20.0 * k + 5.0 * v + 2.5
					for cells: AABB in mesh.boxes:
						if cells.position.x * mesh.cell_ldu <= x and cells.end.x * mesh.cell_ldu >= x \
								and cells.position.z * mesh.cell_ldu <= z \
								and cells.end.z * mesh.cell_ldu >= z:
							bits |= 1 << (v * 4 + u)
							break
			if bits != 0:
				covers[Vector2i(i, k)] = bits
	for at: Variant in studs:
		covers[at] = FULL
	var first := Vector2i(-1, -1)
	for k: int in foot.y:
		for i: int in foot.x:
			var bits: int = int(covers.get(Vector2i(i, k), 0))
			if first.x < 0 and bits != 0 and bits != FULL:
				first = Vector2i(i, k)
	if studs.is_empty() or first.x < 0:
		return []
	return [foot.x, foot.y, studs, covers, first]


## A part's cover turned [param rot] quarter turns, as Patterns._turned
## turns studs: (i, k) to (k, across - 1 - i), and inside a stud (u, v) to
## (v, 3 - u).
static func _cover_turned(base: Array, rot: int) -> Array:
	var across: int = base[0]
	var deep: int = base[1]
	var studs: Dictionary = base[2]
	var covers: Dictionary = base[3]
	for _turn: int in posmod(rot, 4):
		var next_studs: Dictionary = {}
		for key: Variant in studs:
			var at: Vector2i = key
			next_studs[Vector2i(at.y, across - 1 - at.x)] = true
		var next_covers: Dictionary = {}
		for key: Variant in covers:
			var at: Vector2i = key
			var bits: int = covers[key]
			var turned: int = 0
			for v: int in 4:
				for u: int in 4:
					if bits & (1 << (v * 4 + u)):
						turned |= 1 << ((3 - u) * 4 + v)
			next_covers[Vector2i(at.y, across - 1 - at.x)] = turned
		studs = next_studs
		covers = next_covers
		var swap: int = across
		across = deep
		deep = swap
	var first := Vector2i(-1, -1)
	for k: int in deep:
		for i: int in across:
			var bits: int = int(covers.get(Vector2i(i, k), 0))
			if first.x < 0 and bits != 0 and bits != FULL:
				first = Vector2i(i, k)
	return [across, deep, studs, covers, first]


## Whether what the shape covers of a stud is bounded square to it: the same
## in every row of the 4 x 4 grid, or in every column. A stud the edge
## crosses on a slant is neither.
static func square(bits: int) -> bool:
	var rows: bool = true
	var columns: bool = true
	var row: int = bits & 0xF
	var column: int = bits & 0x1111
	for n: int in range(1, 4):
		rows = rows and (bits >> (4 * n)) & 0xF == row
		columns = columns and (bits >> n) & 0x1111 == column
	return rows or columns


static func ones(bits: int) -> int:
	if _ones.is_empty():
		_ones.resize(65536)
		for n: int in 65536:
			_ones[n] = (_ones[n >> 1] if n > 0 else 0) + (n & 1)
	return _ones[bits & FULL]


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
			# The boxes are in lattice cells, not LDU: read as LDU, every plan
			# was the middle half of the part, and a twin was found by chance.
			for box: AABB in mesh.boxes:
				if box.position.x * mesh.cell_ldu <= x and box.end.x * mesh.cell_ldu >= x \
						and box.position.z * mesh.cell_ldu <= z and box.end.z * mesh.cell_ldu >= z:
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
	## Wedge plates and bricks on a diagonal plan edge. Off, the plan's edges
	## are left in plain plates and bricks.
	var wedges: bool = true
	## For a "mixed" surface, which kind of slope suits a stud, cell ->
	## "curved" or "straight": a sculpt says where it is round and where
	## it is a flat facet, and a chamfered cube is not a sphere.
	var prefer: Callable = Callable()
	## The shape's colour at a point, as [member sample] says whether it is
	## there: -1 outside.
	var colour_at: Callable = Callable()
	## Whether a section that is a disc of a size round parts come in is
	## laid in them (round_runs).
	var rounds: bool = true
	## Whether a course over nothing with nothing studded over it is laid in
	## plates (lay). A sculpt's grid keeps its bricks: Brickify's own lay
	## measures what it is, and a hollow sculpt lost 3% of itself.
	var bridges: bool = true
	## A curved side laid on its side (lay_shell): its outside is the flank
	## a person sees, and where it curves a curved slope fits as well as a
	## cheese slope, the curved one.
	var flank: bool = false
	## The round parts round_runs laid, put into [member made] by lay(), and
	## the runs said, for a probe.
	var round_made: Array = []
	var round_said: Array = []
	## Faces to lay onto the shells, as Shapes._read_faces reads them; the
	## ones laid, by what they were said as, and why each other one was not.
	var faces: Array = []
	var faces_laid: Array = []
	var faces_why: Dictionary = {}

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

	## Where a layer's section is a disc of a size round parts come in — a
	## cylinder, a dome's or an egg's narrowing sections, a post — the
	## round parts a set lays there, by the round pattern's own choice for
	## that diameter (Rounds._body: round plates and bricks, cylinder
	## halves, four corner rounds tied by a round plate), instead of plates
	## and corner pieces tiled stud by stud. A whole round part's collision
	## cover is its square box, so it is laid only where the box holds
	## nothing else of the layer; the plates it stands in are taken, so
	## nothing else is laid there, no slope stands on them and no wedge's
	## cut side reaches in. The edge fitter left them out for that reason:
	## beside parts that follow the curve, the check reads them as squares.
	func round_runs() -> void:
		if not rounds or library == null or not colour_at.is_valid():
			return
		# Every layer's discs, by where and how wide: "x z d colour" -> plates.
		var discs: Dictionary = {}
		for j: int in tall:
			var seen: Dictionary = {}
			for key: Variant in columns:
				var cell: Vector2i = key
				var c: int = at(cell, j)
				if c < 0 or seen.has(cell):
					continue
				var blob: Array[Vector2i] = [cell]
				seen[cell] = true
				var low: Vector2i = cell
				var high: Vector2i = cell
				var n: int = 0
				while n < blob.size():
					var here: Vector2i = blob[n]
					n += 1
					low = Vector2i(mini(low.x, here.x), mini(low.y, here.y))
					high = Vector2i(maxi(high.x, here.x), maxi(high.y, here.y))
					for step: Vector2i in Shapes.OUT:
						var next: Vector2i = here + step
						if not seen.has(next) and at(next, j) == c:
							seen[next] = true
							blob.append(next)
				var d: int = high.x - low.x + 1
				if d != high.y - low.y + 1 or not d in Rounds.DIAMETERS:
					continue
				# Its own mirror where the shape is one: a disc off the plane
				# has no twin, and the check would call the model lopsided.
				if not axis.is_empty() and across(low) + across(high) != sum:
					continue
				if _is_disc(low, d, j, blob.size()):
					var said: String = "%d %d %d %d" % [low.x, low.y, d, c]
					if not discs.has(said):
						discs[said] = []
					(discs[said] as Array).append(j)
		# Runs of plates one over the next, each to be laid as a length of
		# round body: [low, d, colour, from, to].
		var runs: Array = []
		for said: Variant in discs:
			var plates: Array = discs[said]
			var parts: PackedStringArray = str(said).split(" ")
			var from: int = 0
			while from < plates.size():
				var to: int = from + 1
				while to < plates.size() and int(plates[to]) == int(plates[to - 1]) + 1:
					to += 1
				runs.append([Vector2i(parts[0].to_int(), parts[1].to_int()), parts[2].to_int(),
					parts[3].to_int(), int(plates[from]), int(plates[to - 1]) + 1])
				from = to
		runs.sort_custom(func(a: Array, b: Array) -> bool: return int(a[3]) < int(b[3]))
		runs = _stacked(runs)
		_ease(runs)
		Rounds._parts = library
		var capped: Dictionary = {}    ## Vector2i cell -> the plate a dish caps it from
		for run: Array in runs:
			var low: Vector2i = run[0]
			var d: int = run[1]
			if capped.has(low + Vector2i(d / 2, d / 2)) \
					and int(run[3]) >= int(capped[low + Vector2i(d / 2, d / 2)]):
				continue
			# Taken whole by the eased rim under it.
			if int(run[3]) >= int(run[4]):
				continue
			var top: int = run[4]
			var highest: int = -1
			var studs_kept: bool = false
			for i: int in d:
				for k: int in d:
					var cell := Vector2i(low.x + i, low.y + k)
					studs_kept = studs_kept or studded.has(cell)
					for j: int in range(top, tall):
						if at(cell, j) >= 0:
							highest = maxi(highest, j)
			# The top of the shape, and smooth: its last plate round tiles, as
			# a set finishes a round it shows from above, not bare studs.
			if highest < 0 and smooth and not studs_kept:
				if top - int(run[3]) > 1:
					_round_run(low, d, run[2], run[3], top - 1, int(run[5]) if run.size() > 5 else 0)
				_round_tiles(low, d, run[2], top - 1)
				round_said.append("%d at %d,%d plates %d-%d, tiled" % [d, low.x, low.y, run[3], top - 1])
				continue
			_round_run(low, d, run[2], run[3], run[4], int(run[5]) if run.size() > 5 else 0)
			round_said.append("%d at %d,%d plates %d-%d" % [d, low.x, low.y, run[3], int(run[4]) - 1])
			# A dome's crown: where all the shape has left over the run, in its
			# box, is no taller than a dish, the dish — not a cake of rings.
			if not DISHES.has(d):
				continue
			var cap: int = highest + 1 - top
			var dish: Array = DISHES[d]
			if highest < 0 or cap > int(dish[1]) + 1 or not _cap_free(low, d, top, highest):
				continue
			var cells: Array[Vector2i] = []
			for i: int in d:
				for k: int in d:
					cells.append(Vector2i(low.x + i, low.y + k))
					for j: int in range(top, highest + 1):
						taken[Vector3i(low.x + i, j, low.y + k)] = true
			# The studs at its middle, under a round tile.
			var crown: Array = DISHES[d]
			var centre: Array[Vector2i] = []
			for i: int in 2:
				for k: int in 2:
					centre.append(low + Vector2i(d / 2 - 1 + i, d / 2 - 1 + k))
			round_made.append({"part": dish[0], "color": int(run[2]), "x": low.x, "y": top,
				"z": low.y, "rot": 0, "_cells": cells, "_h": int(dish[1]),
				"_studs": centre, "_base": cells, "_round": true})
			var middle: float = d / 2.0 - float(crown[3]) / 2.0
			round_made.append({"part": crown[2], "color": int(run[2]), "x": low.x + middle,
				"y": top + int(dish[1]), "z": low.y + middle, "rot": 0,
				"_cells": centre, "_h": 1, "_studs": [] as Array[Vector2i],
				"_base": centre, "_round": true, "_top": true})
			capped[low + Vector2i(d / 2, d / 2)] = top

	## The runs that are a round body's: two plates or more, or one plate on
	## or under another round about the same middle. A single plate that is
	## a disc where an oval body passes through one (an owl's head and body
	## are ovals, 13 studs by 11) was laid as a round plate with its studs
	## bare round the rim and, at the crown, a dish on it: the owl's head
	## wore it as a hat, and the run took it off and stacked round plates
	## there by hand, studs on every ring.
	static func _stacked(runs: Array) -> Array:
		var middles: Dictionary = {}    ## "2x 2z plate" -> true, at each plate a run has
		for run: Array in runs:
			var low: Vector2i = run[0]
			for j: int in range(int(run[3]), int(run[4])):
				middles["%d %d %d" % [2 * low.x + int(run[1]), 2 * low.y + int(run[1]), j]] = true
		var out: Array = []
		for run: Array in runs:
			var low: Vector2i = run[0]
			var middle: String = "%d %d" % [2 * low.x + int(run[1]), 2 * low.y + int(run[1])]
			if int(run[4]) - int(run[3]) >= 2 or middles.has("%s %d" % [middle, int(run[3]) - 1]) \
					or middles.has("%s %d" % [middle, int(run[4])]):
				out.append(run)
		return out

	## A dome's step eased, as a set eases one: where a round of 6 or 8 has a
	## round a stud narrower standing on it, the step between them was a
	## ledge of bare studs a stud wide, ring over ring — a wedding cake from
	## the side. A curved slope wants two studs of ledge to fall over, so the
	## round above stands inset for the slopes' two plates: on the rim of the
	## round below, 2 x 2 curved slopes falling out on each side and a round
	## plate with a quarter-round tile at each corner; inside them a round
	## four studs narrower (a core of round plates); and the round above goes
	## on from a round plate that bridges in over the slopes' tops. A round
	## above only one or two plates tall is the slopes, all of it. Only where
	## the round above is one colour with the one under it, and nothing else
	## of the shape is in the rim.
	const EASED: Array = [6, 8]
	## The slope on each side of an eased rim, and what stands on a corner's
	## one stud: a round plate and a quarter-round tile, two plates as the
	## slope is.
	const EASE_SLOPE := "15068"
	const EASE_CORNER: Array = ["6141", "25269"]

	func _ease(runs: Array) -> void:
		var at_bottom: Dictionary = {}    ## "x z d c from" -> the run
		for run: Array in runs:
			at_bottom["%d %d %d %d %d" % [(run[0] as Vector2i).x, (run[0] as Vector2i).y,
				int(run[1]), int(run[2]), int(run[3])]] = run
		for run: Array in runs:
			var low: Vector2i = run[0]
			var d: int = run[1]
			if not d in EASED or int(run[3]) >= int(run[4]):
				continue
			var key: String = "%d %d %d %d %d" % [low.x + 1, low.y + 1, d - 2, int(run[2]),
				int(run[4])]
			if not at_bottom.has(key):
				continue
			var step: int = int(run[4])
			if not _rim_free(low, d, step):
				continue
			_ease_rim(low, d, int(run[2]), step)
			_round_run(low + Vector2i(2, 2), d - 4, int(run[2]), step, step + 2)
			round_said.append("%d at %d,%d plates %d-%d eased" % [d, low.x, low.y, step,
				step + 1])
			# The round above goes on from over the slopes. One or two plates
			# tall, the slopes are all of it — a dome's rings a plate or two
			# each were left a stack of round plates with studs bare on every
			# ring, the owl's head among them — and a round on it within the
			# two plates goes on from over them too.
			var middle: Vector2i = 2 * low + Vector2i(d, d)
			for other: Array in runs:
				if other == run or 2 * (other[0] as Vector2i) + Vector2i(other[1], other[1]) != middle \
						or int(other[3]) < step or int(other[3]) >= step + 2:
					continue
				other[3] = step + 2
				if other.size() < 6:
					other.append(d - 4)
				if other[3] >= other[4]:
					round_said.append("%d at %d,%d is the slopes" % [int(other[1]),
						(other[0] as Vector2i).x, (other[0] as Vector2i).y])

	## Whether the rim of the round of [param d] at [param low], for the two
	## plates from [param from], has nothing of the shape but the round a
	## stud narrower, and nothing taken.
	func _rim_free(low: Vector2i, d: int, from: int) -> bool:
		for i: int in d:
			for k: int in d:
				if i >= 2 and i < d - 2 and k >= 2 and k < d - 2:
					continue
				var cell := Vector2i(low.x + i, low.y + k)
				var inner: bool = i >= 1 and i < d - 1 and k >= 1 and k < d - 1
				for j: int in range(from, from + 2):
					if taken.has(Vector3i(cell.x, j, cell.y)):
						return false
					if not inner and at(cell, j) >= 0:
						return false
		return true

	## The slopes and corners round the rim of a round of [param d], on its
	## top plate at [param j]: the two studs of each side between its
	## corners fall out, two by two.
	func _ease_rim(low: Vector2i, d: int, c: int, j: int) -> void:
		var slope: Dictionary = Shapes.part(library, EASE_SLOPE)
		if slope.is_empty():
			return
		for side: int in 4:
			var facing: Vector2i = Shapes.OUT[side]
			var perp := Vector2i(absi(facing.y), absi(facing.x))
			# The high row, a stud in from the edge on that side.
			var inner: Vector2i
			match side:
				0: inner = Vector2i(0, d - 2)
				1: inner = Vector2i(d - 2, 0)
				2: inner = Vector2i(0, 1)
				_: inner = Vector2i(1, 0)
			for a: int in range(2, d - 2, 2):
				var high_row: Array[Vector2i] = []
				var cells: Array[Vector2i] = []
				for n: int in 2:
					var cell: Vector2i = low + inner + perp * (a + n)
					high_row.append(cell)
					cells.append(cell)
					cells.append(cell + facing)
				var corner := Vector2i(1 << 30, 1 << 30)
				for one: Vector2i in cells:
					corner = Vector2i(mini(corner.x, one.x), mini(corner.y, one.y))
				round_made.append({"part": EASE_SLOPE, "color": c, "x": corner.x, "y": j,
					"z": corner.y, "rot": posmod(side + int(slope["turn"]), 4), "_top": true,
					"_cells": cells, "_h": 2, "_studs": [] as Array[Vector2i],
					"_base": high_row, "_slope": true, "_round": true})
				_take(cells, j, 2)
		# A corner's one stud: a round plate, and a quarter-round tile on it
		# with its curve to the outside.
		var tile: Lbm.PartMesh = library.mesh_for(EASE_CORNER[1])
		var corners: Array[Vector2i] = [Vector2i(1, 1), Vector2i(d - 2, 1),
			Vector2i(d - 2, d - 2), Vector2i(1, d - 2)]
		var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1),
			Vector2(1, -1)]
		for n: int in 4:
			var cell: Vector2i = low + corners[n]
			var one: Array[Vector2i] = [cell]
			round_made.append({"part": EASE_CORNER[0], "color": c, "x": cell.x, "y": j,
				"z": cell.y, "rot": 0, "_cells": one, "_h": 1, "_studs": one, "_base": one,
				"_round": true})
			var rot: int = Rounds.QUARTER_TURNS[n]
			if tile != null:
				for turn: int in 4:
					if Rounds.lean(tile, turn) == inward[n]:
						rot = turn
						break
			round_made.append({"part": EASE_CORNER[1], "color": c, "x": cell.x, "y": j + 1,
				"z": cell.y, "rot": rot, "_cells": one, "_h": 1,
				"_studs": [] as Array[Vector2i], "_base": one, "_round": true, "_top": true})
			_take(one, j, 2)

	## The dish that crowns a round of each diameter, how many plates of it
	## there are, as the round pattern's dome nose lays them, and the round
	## tile over the studs at its middle and how wide: a 4 x 4 dish has one
	## stud, the others a 2 x 2.
	const DISHES: Dictionary = {4: ["3960", 2, "98138", 1], 6: ["44375b", 2, "14769", 2],
		8: ["3961", 3, "14769", 2]}

	## The round tiles that finish a round's top, by diameter: one whole, or
	## rings of corner round tiles (TILE_RINGS). There is no round tile of 8.
	const ROUND_TILES: Dictionary = {1: "98138", 2: "14769", 4: "27925", 6: "7212", 8: "27507"}

	## A round's top plate in round tiles: one round tile, or four corner
	## round tiles each turned to lean on the middle, read off its mesh — and
	## a ring's middle in the round tiles of the round inside it. Before, the
	## middle of a round of 8 kept 12 bare studs.
	func _round_tiles(low: Vector2i, d: int, c: int, j: int) -> void:
		var part: String = ROUND_TILES[d]
		var cells: Array[Vector2i] = []
		for i: int in d:
			for k: int in d:
				cells.append(Vector2i(low.x + i, low.y + k))
				taken[Vector3i(low.x + i, j, low.y + k)] = true
		if d <= 2 or d == 6:
			round_made.append({"part": part, "color": c, "x": low.x, "y": j, "z": low.y,
				"rot": 0, "_cells": cells, "_h": 1, "_studs": [] as Array[Vector2i],
				"_base": cells, "_round": true, "_top": true})
			return
		# The corner round tiles of 4 and 8 are rings (macaroni): a set nests
		# them, 4 x 4 round 3 x 3 round 2 x 2, with a round tile in the middle.
		# Laid alone, a round of 8's top kept twenty bare studs inside its
		# ring and a round of 4's a hole a stud across. (A 6 x 6 round tile
		# would do the middle of 8, but its cover is its square box, and the
		# check reads it as overlapping the ring.)
		for ring: Array in TILE_RINGS:
			var across: int = ring[0]
			if across > d:
				continue
			var off: int = (d - across) / 2
			_quarter_tiles(low + Vector2i(off, off), across, str(ring[1]), c, j,
				_box(low + Vector2i(off + 1, off + 1), across - 2))
		var middle: Array[Vector2i] = []
		for one: Variant in _box(low + Vector2i(d / 2 - 1, d / 2 - 1), 2):
			middle.append(one)
		round_made.append({"part": ROUND_TILES[2], "color": c, "x": low.x + d / 2 - 1, "y": j,
			"z": low.y + d / 2 - 1, "rot": 0, "_cells": middle, "_h": 1,
			"_studs": [] as Array[Vector2i], "_base": middle, "_round": true, "_top": true})

	## The rings of corner round tiles, widest first: each a quarter ring a
	## stud wide, whose inside is the next.
	const TILE_RINGS: Array = [[8, "27507"], [6, "79393"], [4, "27925"]]

	static func _box(low: Vector2i, d: int) -> Dictionary:
		var out: Dictionary = {}
		for i: int in d:
			for k: int in d:
				out[low + Vector2i(i, k)] = true
		return out

	## Four corner round tiles of [param part] over the box of [param d] at
	## [param low], each turned to lean as a quarter of a round, studs in
	## [param skip] left to another part.
	func _quarter_tiles(low: Vector2i, d: int, part: String, c: int, j: int,
			skip: Dictionary) -> void:
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		var half: int = d / 2
		var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(half, 0), Vector2i(half, half),
			Vector2i(0, half)]
		# Which way each one's cover leans: a 2 x 2 corner round tile's to the
		# middle, as a corner round brick's does, the 4 x 4's and 3 x 3's
		# (quarter rings a stud wide) to their curve. Turned the other way,
		# four made a star of curves facing each other.
		var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
		if part == "27507" or part == "79393":
			inward = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		for n: int in 4:
			var rot: int = Rounds.QUARTER_TURNS[n]
			if mesh != null:
				for turn: int in 4:
					if Rounds.lean(mesh, turn) == inward[n]:
						rot = turn
						break
			var mine: Array[Vector2i] = []
			for i: int in half:
				for k: int in half:
					var cell: Vector2i = low + corners[n] + Vector2i(i, k)
					if not skip.has(cell):
						mine.append(cell)
			round_made.append({"part": part, "color": c, "x": low.x + corners[n].x, "y": j,
				"z": low.y + corners[n].y, "rot": rot, "_cells": mine, "_h": 1,
				"_studs": [] as Array[Vector2i], "_base": mine, "_round": true, "_top": true})

	## Whether nothing of the box at [param low], [param d] studs across,
	## from plate [param from] to [param to], is taken or another colour's.
	func _cap_free(low: Vector2i, d: int, from: int, to: int) -> bool:
		for i: int in d:
			for k: int in d:
				for j: int in range(from, to + 1):
					if taken.has(Vector3i(low.x + i, j, low.y + k)):
						return false
		return true

	## The heights of the round parts the round pattern lays, in plates.
	const ROUND_TALL: Dictionary = {"3062b": 3, "3941": 3, "87081": 3, "6222": 3, "5152": 3,
		"48092": 3, "85941": 15, "24593": 6, "30562": 18}

	## Lay plates [param from] to [param to] of a disc [param d] studs across
	## with its low corner at [param low], in colour [param c].
	## [param under]: the diameter of the round it stands on, where that is
	## narrower — its first plate is then a round plate, bridging in.
	func _round_run(low: Vector2i, d: int, c: int, from: int, to: int, under: int = 0) -> void:
		var parts: Array = []
		var state := {"d": d, "below": "", "last_d": under if under > 0 else d}
		var centre := Vector2(low.x + d / 2.0, low.y + d / 2.0)
		Rounds._body(parts, centre, float(from), d, to - from, c, state)
		for one: Dictionary in parts:
			var part: String = str(one["part"])
			var tall_: int = int(ROUND_TALL.get(part, 1))
			# A quarter covers its own corner of the box; a half its half; a
			# whole round part all of it.
			var size := Vector2i(d, d)
			if part in ["5152", "48092", "30562"]:
				size = Vector2i(d / 2, d / 2)
			elif part in ["85941", "24593"]:
				size = Vector2i(d, d / 2)
			var cells: Array[Vector2i] = []
			for i: int in size.x:
				for k: int in size.y:
					cells.append(Vector2i(roundi(float(one["x"])) + i, roundi(float(one["z"])) + k))
			one["_cells"] = cells
			one["_h"] = tall_
			one["_studs"] = cells
			one["_base"] = cells
			one["_round"] = true
			round_made.append(one)
		for i: int in d:
			for k: int in d:
				for j: int in range(from, to):
					taken[Vector3i(low.x + i, j, low.y + k)] = true

	## Whether the blob of [param count] studs at plate [param j] is, over
	## the box of [param d] studs at [param low] and a stud round it, nearer
	## a disc filling the box than the box itself, on a 4 x 4 grid in every
	## stud, and within a tenth of the disc; and the box holds nothing else.
	func _is_disc(low: Vector2i, d: int, j: int, count: int) -> bool:
		var c: int = -1
		var inside: int = 0
		for i: int in d:
			for k: int in d:
				var cell := Vector2i(low.x + i, low.y + k)
				if at(cell, j) >= 0:
					c = at(cell, j)
					inside += 1
				if taken.has(Vector3i(cell.x, j, cell.y)):
					return false
		if inside != count:
			return false
		# The section against a disc of its own area about the box's middle,
		# and against the box: a dome's section a third of a stud wider than
		# the disc of six is still a disc, and a square post is not.
		var centre := Vector2(low.x + d / 2.0, low.y + d / 2.0)
		var points: Array[Vector2] = []
		var here: Array[bool] = []
		var area: int = 0
		var y: float = j + 0.5
		for i: int in range(-1, d + 1):
			for k: int in range(-1, d + 1):
				for v: int in 4:
					for u: int in 4:
						var p := Vector2(low.x + i + (u + 0.5) / 4.0, low.y + k + (v + 0.5) / 4.0)
						var inside_: bool = int(colour_at.call(p.x, y, p.y)) == c
						points.append(p)
						here.append(inside_)
						area += 1 if inside_ else 0
		var r2: float = area / 16.0 / PI
		var off_disc: int = 0
		var off_box: int = 0
		for n: int in points.size():
			var p: Vector2 = points[n]
			var box: bool = p.x >= low.x and p.y >= low.y and p.x < low.x + d and p.y < low.y + d
			off_disc += 1 if here[n] != (p.distance_squared_to(centre) <= r2) else 0
			off_box += 1 if here[n] != box else 0
		return off_disc < off_box and off_disc <= 0.15 * area

	## How far out from its core a curved side is laid on its side, in studs:
	## five plates of a shell.
	const SHELL_DEPTH := 2
	## A side narrower than this behind its shell keeps no core to hold it.
	const SHELL_CORE := 2
	## The share of the plates a shell takes out of the core that its kept
	## parts must cover, or the side is laid upright.
	const SHELL_KEEPS := 0.4
	## The brick with a stud on one side that holds a shell.
	const ANCHOR := "87087"
	## And the longer ones, by how many lanes each holds: a run of lanes in a
	## course of the core's wall is held by 1 x 4s and 1 x 2s with studs on a
	## side, not a 1 x 1 a lane.
	const ANCHOR_RUNS: Dictionary = {4: "30414", 2: "11211", 1: ANCHOR}

	## Side studs a shell is held by, laid in the core: placements.
	var anchors: Array = []
	## What each shell laid came to (lay_shell), said.
	var kept: Array = []
	## For a shell's own plan, the cells of its foot a side stud reaches:
	## only parts joined to those are kept.
	var held: Dictionary = {}
	## Plates of the shape a shell has taken, Vector3i(x, j, z): a later
	## shell does not reach into them.
	var shelled: Dictionary = {}

	## A curved side laid on its side, as a set's flank is: where the shape
	## bulges out of a face of its core — an owl's breast, the shoulder of a
	## car, a hull's side — the bulge is not laid in courses that step out
	## a stud at a time, which is the staircase every round body here came
	## out as from the front, but as a shape of its own lying on that face:
	## plates, tiles, curved slopes and corner rounds whose up points out,
	## laid by this same plan turned on its side (lay_shell), so its outside
	## is the parts' smooth faces. It is held by bricks with a stud on one
	## side (87087) in the core's outer wall, every second row of the shell,
	## where the side stud meets the middle of a row (one and three quarter
	## plates up the brick; a row on its side is two and a half plates).
	## A side that does not curve is left to the side panels.
	##
	## Each shell is {facing, along, a0, a1, face, top, rows, held}: the way
	## out and the way along it, the lanes it spans, the plane of the core's
	## face in studs out, the plate its top row starts under, how many rows.
	func shells() -> Array:
		var out: Array = []
		if library == null or not colour_at.is_valid() or library.mesh_for(ANCHOR) == null:
			return out
		# Opposite sides together, so a mirrored shape's two flanks are cut
		# by the same corners.
		for facing: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var shell: Dictionary = _shell(facing)
			if not shell.is_empty():
				out.append(shell)
		return out

	## Which way runs along a side facing [param facing], so that along, out
	## and down are a turn of up, along and out: +z along +x, +x along -z.
	static func along_of(facing: Vector2i) -> Vector2i:
		return {Vector2i(0, 1): Vector2i(1, 0), Vector2i(1, 0): Vector2i(0, -1),
			Vector2i(0, -1): Vector2i(-1, 0), Vector2i(-1, 0): Vector2i(0, 1)}[facing]

	## A stud's cell as [lane, out]: how far along [param along] and out along
	## [param facing], each counted so the cell spans [n, n + 1).
	static func _lane(cell: Vector2i, facing: Vector2i, along: Vector2i) -> Vector2i:
		var a: int = cell.x * along.x + cell.y * along.y
		var t: int = cell.x * facing.x + cell.y * facing.y
		return Vector2i(a if along.x + along.y > 0 else a - 1, t if facing.x + facing.y > 0 else t - 1)

	## The world point, in studs, of a lane and out given as numbers.
	static func _point(a: float, t: float, facing: Vector2i, along: Vector2i) -> Vector2:
		var x: float = 0.0
		var z: float = 0.0
		var sa: float = a if along.x + along.y > 0 else -a
		var st: float = t if facing.x + facing.y > 0 else -t
		if along.x != 0:
			x = sa
		else:
			z = sa
		if facing.x != 0:
			x = st
		else:
			z = st
		return Vector2(x, z)

	func _shell(facing: Vector2i) -> Dictionary:
		var along: Vector2i = along_of(facing)
		# How far out the shape reaches in each lane at each plate, and how
		# far in its core starts; nothing over a round run.
		var reach: Dictionary = {}    ## Vector2i(lane, j) -> one past the outermost
		var inmost: Dictionary = {}   ## lane -> the least out of any stud in it
		var most: int = -(1 << 30)
		for key: Variant in columns:
			var cell: Vector2i = key
			var lt: Vector2i = _lane(cell, facing, along)
			for j: int in tall:
				if at(cell, j) < 0:
					continue
				if taken.has(Vector3i(cell.x, j, cell.y)) or shelled.has(Vector3i(cell.x, j, cell.y)):
					continue
				var here := Vector2i(lt.x, j)
				reach[here] = maxi(int(reach.get(here, -(1 << 30))), lt.y + 1)
				inmost[lt.x] = mini(int(inmost.get(lt.x, 1 << 30)), lt.y)
				most = maxi(most, lt.y + 1)
		if reach.is_empty():
			return {}
		var face: int = most - SHELL_DEPTH
		var patch: Array[Vector2i] = []
		var low := Vector2i(1 << 30, 1 << 30)
		var high := -low
		var curves: bool = false
		for key: Variant in reach:
			var at_: Vector2i = key
			if int(reach[at_]) <= face or int(inmost[at_.x]) > face - SHELL_CORE:
				continue
			# Steep: out no more than two studs in four plates up or down. A
			# gentler fall is a top, which the slopes lay (a ramp's low end
			# was turned on its side and lost its 18 degree slopes).
			var above: int = int(reach.get(at_ + Vector2i(0, 2), face))
			var below: int = int(reach.get(at_ - Vector2i(0, 2), face))
			if absi(above - below) > 2:
				continue
			patch.append(at_)
			low = Vector2i(mini(low.x, at_.x), mini(low.y, at_.y))
			high = Vector2i(maxi(high.x, at_.x), maxi(high.y, at_.y))
		# Curving up the side, not only round it: a cylinder's side is the
		# round parts', and a flat side the panels'.
		var in_patch: Dictionary = {}
		for at_: Vector2i in patch:
			in_patch[at_] = true
		for at_: Vector2i in patch:
			var up: Vector2i = at_ + Vector2i(0, 1)
			curves = curves or in_patch.has(up) and int(reach[up]) != int(reach[at_])
		# Two rows tall at least: a few plates at the foot of a ramp are its
		# slopes'.
		if patch.size() < 4 or not curves or high.y + 1 - low.y < 5:
			return {}
		# And all of those lanes past the face, up and down: a crown left to
		# the core above the shell stood on the shell's edge, held by nothing.
		for key: Variant in reach:
			var at_: Vector2i = key
			if at_.x >= low.x and at_.x <= high.x and int(reach[at_]) > face:
				low.y = mini(low.y, at_.y)
				high.y = maxi(high.y, at_.y)
		var top: int = high.y + 1
		var rows: int = 2 * ceili((top - low.y) / 5.0)
		var bottom: int = maxi(0, top - roundi(2.5 * rows))
		# Taken out of the core: every plate of the box, past the face, that
		# no shell before it has.
		# And the box's plates outside the shape too: a wedge's cut side
		# reached into one beside the shell and overlapped it.
		var mine: Dictionary = {}
		var outside: Array[Vector3i] = []
		for a: int in range(low.x, high.x + 1):
			for j: int in range(bottom, top):
				for t: int in range(face, most):
					var p: Vector2 = _point(a + 0.5, t + 0.5, facing, along)
					var key := Vector3i(floori(p.x), j, floori(p.y))
					if shelled.has(key) or taken.has(key):
						continue
					if at(Vector2i(key.x, key.z), j) >= 0:
						mine[key] = true
					else:
						outside.append(key)
		for key: Variant in mine:
			taken[key] = true
			shelled[key] = true
		for key: Vector3i in outside:
			taken[key] = true
		var shell := {"facing": facing, "along": along, "a0": low.x, "a1": high.x + 1,
			"face": face, "top": top, "rows": rows, "held": {}, "cells": mine,
			"outside": outside}
		# Its side studs: every second row, in the core's outer wall behind
		# each lane the shell's first row of plates covers there.
		if _anchor_turn(facing) < 0:
			drop_shell(shell)
			return {}
		for w: int in range(0, rows, 2):
			var jb: int = top - roundi(2.5 * w) - 3
			if jb < 0:
				break
			# Each lane the shell's row covers there, with the cell of the
			# core's outer wall behind it: [lane, cell, colour], or [] where
			# none can go.
			var lanes: Array = []
			for a: int in range(low.x, high.x + 1):
				# In every lane, a course of them as studs_out lays one: one
				# lane in two cut the core's outer wall into columns of 1 x 1s
				# between them, tied to nothing, and a bird's breast floated.
				var row_y: float = top - 2.5 * (w + 0.5)
				var p: Vector2 = _point(a + 0.5, face + 0.2, facing, along)
				if int(colour_at.call(p.x, row_y, p.y)) < 0 \
						or not mine.has(Vector3i(floori(p.x), floori(row_y), floori(p.y))):
					lanes.append([])
					continue
				var q: Vector2 = _point(a + 0.5, face - 0.5, facing, along)
				var cell := Vector2i(floori(q.x), floori(q.y))
				var free: bool = true
				for n: int in 3:
					free = free and at(cell, jb + n) >= 0 \
						and not taken.has(Vector3i(cell.x, jb + n, cell.y))
				lanes.append([a, cell, at(cell, jb + 1)] if free else [])
			# Runs of lanes side by side in one colour, each held by side-stud
			# bricks as long as fit, laid the same from either end so a side
			# that is its own mirror stays one: 84 of an egg's 450 parts were
			# 1 x 1s with a stud on a side.
			var run: Array = []
			for n: int in lanes.size() + 1:
				var lane: Array = lanes[n] if n < lanes.size() else []
				if not lane.is_empty() and (run.is_empty()
						or int((run[-1] as Array)[2]) == int(lane[2])):
					run.append(lane)
					continue
				var at_: int = 0
				for size: int in _split(run.size()):
					var cells: Array[Vector2i] = []
					var holds: Array = []
					for k: int in size:
						var one: Array = run[at_ + k]
						cells.append(one[1])
						holds.append(Vector2i(int(one[0]) - low.x, w))
						for m: int in 3:
							taken[Vector3i((one[1] as Vector2i).x, jb + m, (one[1] as Vector2i).y)] = true
					at_ += size
					var part: String = ANCHOR_RUNS[size]
					var turn: int = _anchor_turn(facing, part)
					if turn < 0:
						continue
					var corner: Vector2i = cells[0]
					for cell: Vector2i in cells:
						corner = Vector2i(mini(corner.x, cell.x), mini(corner.y, cell.y))
					anchors.append({"part": part, "color": int((run[0] as Array)[2]), "x": corner.x,
						"y": jb, "z": corner.y, "rot": turn, "_cells": cells, "_h": 3,
						"_studs": cells, "_base": cells, "_holds": [facing, holds]})
					for held: Vector2i in holds:
						(shell["held"] as Dictionary)[held] = true
				run = [lane] if not lane.is_empty() else []
		# Held by nothing, its plates go back to the core: taken and then
		# left, they were laid by nobody, and a body thinned to a strip.
		if (shell["held"] as Dictionary).is_empty():
			drop_shell(shell)
			return {}
		return shell

	## A shell given back to the core: its plates, the plates beside it it
	## kept clear, and its side studs.
	func drop_shell(shell: Dictionary) -> void:
		for key: Variant in shell["cells"]:
			taken.erase(key)
			shelled.erase(key)
		for key: Vector3i in shell["outside"]:
			taken.erase(key)
		var facing: Vector2i = shell["facing"]
		var left: Array = []
		for one: Dictionary in anchors:
			if one.has("_holds") and (one["_holds"] as Array)[0] == facing:
				for cell: Vector2i in one["_cells"]:
					for m: int in 3:
						taken.erase(Vector3i(cell.x, int(one["y"]) + m, cell.y))
			else:
				left.append(one)
		anchors = left

	## A run of [param n] lanes as side-stud bricks, longest first and the
	## same from either end: 6 is 2 2 2, 9 is 4 1 4.
	static func _split(n: int) -> Array:
		var ends: Array = []
		var left: int = n
		while not left in [0, 1, 2, 4]:
			var size: int = 4 if left >= 8 else (2 if left >= 4 else 1)
			ends.append(size)
			left -= 2 * size
		var out: Array = ends.duplicate()
		if left > 0:
			out.append(left)
		ends.reverse()
		return out + ends

	## The quarter turn that points [param part]'s side studs [param facing].
	func _anchor_turn(facing: Vector2i, part: String = ANCHOR) -> int:
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		if mesh == null:
			return -1
		var out := Vector3(facing.x, 0, facing.y)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != "stud" or connector.gender != "male" \
					or absf(connector.axis.y) > 0.1:
				continue
			for rot: int in 4:
				if (BrickLattice.basis_for("up", rot) * connector.axis).dot(out) > 0.9:
					return rot
		return -1

	## A shell's parts: its own plan, a stud along the side by a plate out
	## by a row down, laid as any shape is, and each part turned so its up
	## points out of the side.
	func lay_shell(shell: Dictionary, kind: String, trial: bool = false) -> Array:
		var facing: Vector2i = shell["facing"]
		var along: Vector2i = shell["along"]
		var a0: int = shell["a0"]
		var face: int = shell["face"]
		var top: int = shell["top"]
		var rows: int = shell["rows"]
		var depth: int = roundi(SHELL_DEPTH * Shapes.PLATES_PER_STUD)
		var to_world := func(x: float, j: float, z: float) -> Vector3:
			var p: Vector2 = _point(a0 + x, face + j / Shapes.PLATES_PER_STUD, facing, along)
			return Vector3(p.x, top - Shapes.PLATES_PER_STUD * z, p.y)
		var mine: Dictionary = shell["cells"]
		# The squares a face is laid in, left out of the shell's own plan.
		var masked: Dictionary = {}    ## Vector2i(lane, row) from a0 and top
		var local_colour := func(x: float, j: float, z: float) -> int:
			if masked.has(Vector2i(floori(x), floori(z))):
				return -1
			var p: Vector3 = to_world.call(x, j, z)
			if not mine.has(Vector3i(floori(p.x), floori(p.y), floori(p.z))):
				return -1
			# A row is two and a half plates: every plate it reaches into
			# is the shell's or nobody's, or a round part's box beside it is
			# overlapped.
			var row: float = p.y + Shapes.PLATES_PER_STUD * (z - floorf(z) - 1.0)
			for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
				if j_ < 0:
					return -1
				var key := Vector3i(floori(p.x), j_, floori(p.z))
				if (taken.has(key) or at(Vector2i(key.x, key.z), j_) >= 0) and not mine.has(key):
					return -1
			return int(colour_at.call(p.x, p.y, p.z))
		# Whether a point of the shell's frame is free for a face: every plate
		# its row reaches into the shell's or nobody's, as for its own parts.
		var beside: Dictionary = {}
		for key: Vector3i in shell["outside"]:
			beside[key] = true
		var room := func(x: float, j: float, z: float) -> bool:
			var p: Vector3 = to_world.call(x, j, z)
			var row: float = p.y + Shapes.PLATES_PER_STUD * (z - floorf(z) - 1.0)
			for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
				if j_ < 0:
					return false
				var key := Vector3i(floori(p.x), j_, floori(p.z))
				if (taken.has(key) or at(Vector2i(key.x, key.z), j_) >= 0) and not mine.has(key) \
						and not beside.has(key):
					return false
			return true
		# Held where an anchor the core kept reaches: one in a column the
		# core's own pruning let go holds nothing.
		# Tried before the core is laid, every side stud it was given.
		var held_here: Dictionary = {}
		for one: Dictionary in (anchors if trial else made):
			if one.has("_holds") and (one["_holds"] as Array)[0] == facing:
				for held: Vector2i in (one["_holds"] as Array)[1]:
					held_here[held] = true
		# A face asked for on this side: its square is the face's, laid on the
		# side studs behind it, and left out of the shell's own plan.
		var face_parts: Array = []
		for asked: Dictionary in faces:
			if asked["facing"] != facing:
				continue
			var laid_face: Variant = _face_on_shell(shell, asked, held_here, local_colour, room,
				depth)
			if laid_face is String:
				if not trial:
					faces_why[asked["said"]] = laid_face
				continue
			face_parts.append_array((laid_face as Dictionary)["parts"])
			masked.merge((laid_face as Dictionary)["cells"])
			if not trial:
				faces_laid.append(asked["said"])
				kept.append("a face %s: %s" % [asked["said"], (laid_face as Dictionary)["said"]])
		var local: Dictionary = {}
		for u: int in int(shell["a1"]) - a0:
			for w: int in rows:
				var column := PackedInt32Array()
				column.resize(depth)
				var any: bool = false
				for v: int in depth:
					column[v] = int(local_colour.call(u + 0.5, v + 0.5, w + 0.5))
					any = any or column[v] >= 0
				if any:
					local[Vector2i(u, w)] = column
		# A face may take the whole side: then it is all that is laid there.
		if local.is_empty() and face_parts.is_empty():
			return []
		var sub := Plan.new(local, depth, true, library)
		sub.flank = true
		sub.sides_smooth = false
		sub.rounds = false
		sub.wedges = wedges
		sub.colour_at = local_colour
		sub.sample = func(x: float, j: float, z: float) -> bool:
			return int(local_colour.call(x, j, z)) >= 0
		sub.held = held_here
		if sub.held.is_empty():
			shell["covered"] = 0.0
			return []
		if not local.is_empty():
			sub.mirror_of()
			sub.surface(kind)
			sub.lay()
		var laid: int = sub.made.size()
		# Pruned to what a side stud holds, and not stitched: a piece of a
		# shell on a stud of its own is held, and a stitch lays parts again
		# that no stud may reach.
		if not local.is_empty():
			sub.prune()
		sub.made.append_array(face_parts)
		# How much of what it took out of the core its kept parts cover.
		var covered: Dictionary = {}
		for one: Dictionary in sub.made:
			for cell: Vector2i in one.get("_cells", []):
				for v: int in int(one.get("_h", 1)):
					var p: Vector3 = to_world.call(cell.x + 0.5, float(one["y"]) + v + 0.5, cell.y + 0.5)
					var row: float = top - Shapes.PLATES_PER_STUD * (cell.y + 1)
					for j_: int in range(floori(row + 0.01), ceili(row + Shapes.PLATES_PER_STUD - 0.01)):
						var key := Vector3i(floori(p.x), j_, floori(p.z))
						if mine.has(key):
							covered[key] = true
		shell["covered"] = float(covered.size()) / float(maxi(1, mine.size()))
		if trial:
			return []
		# How much of each shell its side studs kept, for a probe to say.
		kept.append("%s %d of %d parts on %d side studs, %d%% of its plates" % [str(facing),
			sub.made.size(), laid, sub.held.size(), roundi(100.0 * float(shell["covered"]))])
		# Turned: up to out, x to along, z to down; the frame's foot where
		# the first lane meets the face at the top row.
		var c1 := Vector3(along.x, 0, along.y)
		var c2 := Vector3(facing.x, 0, facing.y)
		var turn := Basis(c1, c2, Vector3(0, -1, 0))
		var start: Vector2 = _point(a0, face, facing, along)
		var foot := Vector3(start.x * 20.0, top * 8.0, start.y * 20.0)
		var out: Array = []
		for one: Dictionary in sub.made:
			var part: String = str(one["part"])
			var cover: AABB = Rounds._cover(library, part)
			var basis: Basis = BrickLattice.basis_for(str(one.get("face", "up")), int(one["rot"]))
			var corner := Vector3(float(one["x"]) * 20.0, float(one["y"]) * 8.0,
				float(one["z"]) * 20.0)
			var origin: Vector3 = corner - Rounds._low(basis, cover)
			var named: Array = Rounds._named(turn * basis)
			if named.is_empty():
				continue
			var placed: Dictionary = Rounds._placed(cover, part, int(one["color"]), str(named[0]),
				int(named[1]), foot + turn * origin)
			placed["_shell"] = true
			out.append(placed)
		return out

	## A face laid onto a shell the way a set lays one onto a head: the
	## square it sits in is taken out of the shell, a square plate (or two)
	## on the core's side studs behind it brings it out to the curve, a round
	## plate on that is the disc, and on the disc's upper studs two eyes — a
	## 2 x 2 round plate with a centre stud in the iris's colour under a
	## printed eye tile — with a beak on a jumper between them and under, a
	## cheese slope falling down the face. Every part studs out, so the face
	## is features on a disc flush with the curve, not tiles on a panel.
	##
	## In the shell's own frame, as lay_shell lays it: x along the side, y out
	## in plates, z down in rows. {parts, cells, said}, or why not.
	func _face_on_shell(shell: Dictionary, asked: Dictionary, held_cells: Dictionary,
			colour: Callable, room: Callable, depth: int) -> Variant:
		var n: int = asked["across"]
		var along: Vector2i = shell["along"]
		var lanes: int = int(shell["a1"]) - int(shell["a0"])
		var rows: int = shell["rows"]
		var middle: float = float(asked["x"]) * along.x + float(asked["z"]) * along.y
		var u0: int = roundi(middle - n / 2.0) - int(shell["a0"])
		var w0: int = roundi((float(shell["top"]) - float(asked["j"])) / Shapes.PLATES_PER_STUD
			- n / 2.0)
		if n > lanes or n > rows:
			return ("the curved side there is %d studs along and %d rows (a row is a stud) "
				% [lanes, rows] + "from plate %d down, too small for a face %d across"
				% [int(shell["top"]), n])
		# A stud or two off the side is the side's: the middle a design reads
		# off a picture is a guess at where the curve's middle is.
		var u_in: int = clampi(u0, 0, lanes - n)
		var w_in: int = clampi(w0, 0, rows - n)
		if absi(u_in - u0) > 2 or absi(w_in - w0) > 2:
			return ("its %d x %d square is %d studs off the curved side, which is %d studs "
				% [n, n, maxi(absi(u_in - u0), absi(w_in - w0)), lanes]
				+ "along and %d rows (a row is a stud) from plate %d down"
				% [rows, int(shell["top"])])
		# Where it was said, or the nearest place a stud or two away where its
		# square is clear of the core and has side studs behind it.
		var tries: Array = []
		for du: int in range(-2, 3):
			for dw: int in range(-2, 3):
				tries.append(Vector2i(du, dw))
		tries.sort_custom(func(one: Vector2i, other: Vector2i) -> bool:
			return absi(one.x) + absi(one.y) < absi(other.x) + absi(other.y))
		var why: String = ""
		var studs: int = 0
		var backing: int = 0
		var cells: Dictionary = {}
		var square: Array[Vector2i] = []
		var found: bool = false
		for shift: Vector2i in tries:
			var u1: int = u_in + shift.x
			var w1: int = w_in + shift.y
			if u1 < 0 or w1 < 0 or u1 + n > lanes or w1 + n > rows \
					or absi(u1 - u0) > 2 or absi(w1 - w0) > 2:
				continue
			studs = 0
			var height: int = 0
			cells = {}
			square = []
			for u: int in range(u1, u1 + n):
				for w: int in range(w1, w1 + n):
					var cell := Vector2i(u, w)
					cells[cell] = true
					square.append(cell)
					if held_cells.has(cell):
						studs += 1
					for v: int in range(depth - 1, -1, -1):
						if int(colour.call(u + 0.5, v + 0.5, w + 0.5)) >= 0:
							height += v + 1
							break
			if studs < 2:
				why = "the core behind it has %d side stud%s there to hold a disc" % [
					studs, "" if studs == 1 else "s"]
				continue
			# Out to the curve: the disc's face where the shell's surface is
			# on average, the eyes standing a plate or two proud of it.
			backing = clampi(roundi(float(height) / square.size()) - 2, 0, depth - 2)
			var clear: bool = true
			for cell: Vector2i in square:
				for v: int in backing + 1:
					clear = clear and bool(room.call(cell.x + 0.5, v + 0.5, cell.y + 0.5))
			if not clear:
				why = "the core is in the way of its square"
				continue
			u0 = u1
			w0 = w1
			found = true
			break
		if not found:
			return why if not why.is_empty() else "it does not fit the curved side"
		var face_colour: int = int(asked["color"])
		if face_colour < 0:
			face_colour = int(colour.call(u0 + n / 2.0, backing + 0.5, w0 + n / 2.0))
		if face_colour < 0:
			face_colour = int(colour.call(u0 + n / 2.0, 0.5, w0 + n / 2.0))
		var rim: int = int(asked["rim"])
		if rim < 0:
			rim = int(colour.call(u0 + 0.5, 0.5, w0 + 0.5))
		if rim < 0:
			rim = face_colour
		var parts: Array = []
		var discs: Array = Shapes.FACE_DISCS[n]
		for v: int in backing:
			parts.append({"part": discs[1], "color": rim, "x": u0, "y": v, "z": w0, "rot": 0,
				"_cells": square, "_h": 1})
		parts.append({"part": discs[0], "color": face_colour, "x": u0, "y": backing, "z": w0,
			"rot": 0, "_cells": square, "_h": 1})
		var on: int = backing + 1
		# The eyes on the upper studs, touching, in the middle: a stud in from
		# the rim on a 6, two on an 8 (a stud apart, they read as a panda's);
		# the beak under their middle.
		var eye_row: int = 0 if n == 4 else 1
		var eye_at: Array = {4: [0, 2], 6: [1, 3], 8: [2, 4]}[n]
		for at_: int in eye_at:
			parts.append({"part": "18674", "color": int(asked["eyes"]), "x": u0 + at_, "y": on,
				"z": w0 + eye_row, "rot": 0})
			parts.append({"part": "98138p07", "color": 15, "x": u0 + at_ + 0.5, "y": on + 1,
				"z": w0 + eye_row + 0.5, "rot": 0})
		if int(asked["beak"]) >= 0:
			parts.append({"part": "3794b", "color": face_colour, "x": u0 + (n >> 1) - 1, "y": on,
				"z": w0 + eye_row + 2, "rot": 0})
			parts.append({"part": "54200", "color": int(asked["beak"]), "x": u0 + (n >> 1) - 0.5,
				"y": on + 1, "z": w0 + eye_row + 2, "rot": 0})
		# The disc's other studs tiled, so the face is smooth round its
		# features: the held-out owl's disc, studs bare, was judged "a round
		# plate with its studs showing". A 2 x 2 tile where four free studs
		# lie wholly inside the disc, a 1 x 1 where one does, and a round
		# 1 x 1 at the rim, where a square one's corner would stand off it.
		var used: Dictionary = {}
		for at_: int in eye_at:
			for di: int in 2:
				for dk: int in 2:
					used[Vector2i(at_ + di, eye_row + dk)] = true
		if int(asked["beak"]) >= 0:
			used[Vector2i((n >> 1) - 1, eye_row + 2)] = true
			used[Vector2i(n >> 1, eye_row + 2)] = true
		# Its studs as the part has them: the 6 x 6's ring is not every stud
		# whose middle is on the disc, and a tile there held by nothing.
		var read: Array = Patterns._studs_of(library, discs[0])
		var has_stud: Dictionary = read[2] if read.size() == 3 else {}
		var tiles: int = 0
		for k: int in n:
			for i: int in n:
				if used.has(Vector2i(i, k)) or not (has_stud.has(Vector2i(i, k))
						if not has_stud.is_empty() else _disc_stud(i, k, n)):
					continue
				var block: bool = i + 1 < n and k + 1 < n
				for di: int in 2:
					for dk: int in 2:
						block = block and not used.has(Vector2i(i + di, k + dk)) \
							and _disc_inside(i + di, k + dk, n) and (has_stud.is_empty()
								or has_stud.has(Vector2i(i + di, k + dk)))
				var part: String = "98138"
				if block:
					part = "3068b"
					for di: int in 2:
						for dk: int in 2:
							used[Vector2i(i + di, k + dk)] = true
				elif _disc_inside(i, k, n):
					part = "3070b"
				used[Vector2i(i, k)] = true
				parts.append({"part": part, "color": face_colour, "x": u0 + i, "y": on,
					"z": w0 + k, "rot": 0})
				tiles += 1
		return {"parts": parts, "cells": cells, "said": "a %d x %d disc %d plate%s out on %d side studs, %d tiles round its features"
			% [n, n, backing, "" if backing == 1 else "s", studs, tiles]}

	## Whether a round plate [param n] studs across has a stud at (i, k): its
	## middle inside the disc.
	static func _disc_stud(i: int, k: int, n: int) -> bool:
		var r: float = n / 2.0
		return Vector2(i + 0.5 - r, k + 0.5 - r).length() < r

	## Whether the whole of the stud's square (i, k) lies on the disc.
	static func _disc_inside(i: int, k: int, n: int) -> bool:
		var r: float = n / 2.0
		for corner: Vector2 in [Vector2(i, k), Vector2(i + 1, k), Vector2(i, k + 1),
				Vector2(i + 1, k + 1)]:
			if (corner - Vector2(r, r)).length() > r + 0.01:
				return false
		return true

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
			if under or entry[0] == "cheese" or entry[0] == kind or kind == "mixed":
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
										or (base > 0 and (at(at_, base - 1) < 0
											or taken.has(Vector3i(at_.x, base - 1, at_.y)))):
									fits = false
									break
								error += absf(float(here - base) - float(profile[n]))
						if not fits:
							continue
						# On its side a slope is held only by a stud reaching into
						# a row it grips by: against the core, a side stud there.
						if flank and not under:
							var gripped: bool = false
							for row: Variant in Shapes.part(library, str(entry[3])).get("grips", []):
								gripped = gripped or base > 0 or held.has(cell + out * int(row))
							if not gripped:
								continue
						error /= length
						# The longest slope whose fall is within a plate of the
						# shape's.
						var score: float = error - 0.2 * length
						# Mixed: the kind the surface is here, curved on a round
						# part and straight on a flat facet, unless the other
						# fits it by more than half a plate.
						if kind == "mixed" and not under and prefer.is_valid() \
								and entry[0] != "cheese" and str(prefer.call(cell)) != entry[0]:
							score += 0.5
						# A flank falling a plate a stud took a cheese slope a
						# stud, a staircase of little wedges: there a curved
						# 2 x 1 falls within half a plate of it, and reads as
						# the curve it is. An egg's flank was 2.6% curved. Not
						# where its colour changes: on a fuselage's canopy edge
						# a curved 2 x 1 laid there was held by nothing.
						if flank and kind == "curved" and entry[0] == "cheese" \
								and _one_colour(inner, top, cell, out):
							score += 0.3
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

	## Whether the two studs falling from [param inner] (its top at
	## [param top]) along [param out] from [param cell] are topped in its
	## colour.
	func _one_colour(inner: Vector2i, top: int, cell: Vector2i, out: Vector2i) -> bool:
		var tops_: Dictionary = tops()
		var colour: int = at(inner, top - 1)
		for n: int in 2:
			var here: Vector2i = cell + out * n
			if not tops_.has(here) or at(here, int(tops_[here]) - 1) != colour:
				return false
		return true

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
			# floating. On its side, held only where a stud reaches in at all:
			# a curved slope's high end is hollow (Shapes.part's "grips").
			var base: Array[Vector2i] = high_row
			if flank:
				base = _gripped(pick, shape)
			made.append({"part": id, "color": pick["colour"], "x": low.x, "y": from,
				"z": low.y, "rot": rot, "_top": true, "_cells": cells, "_h": tall_,
				"_studs": studs, "_base": base, "_slope": true})
		_take(cells, from, tall_)

	## The cells of a pick a stud from under it reaches into: its rows the
	## part grips by, every stud across.
	func _gripped(pick: Dictionary, shape: Dictionary) -> Array[Vector2i]:
		var facing: Vector2i = pick["facing"]
		var perp := Vector2i(absi(facing.y), absi(facing.x))
		var out: Array[Vector2i] = []
		for a: int in int(pick.get("wide", 1)):
			for row: Variant in shape.get("grips", []):
				out.append((pick["cell"] as Vector2i) + perp * a + facing * int(row))
		return out

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
		made.append_array(round_made)
		made.append_array(anchors)
		for j: int in tall:
			if j % 3 == 0:
				var k: int = j / 3
				var bricks: Dictionary = {}
				for key: Variant in full(k):
					var cell: Vector2i = key
					# A course with nothing under it and nothing studded over it
					# is a bridge, and bricks side by side in one course join
					# only through what is over and under them. A car's body
					# over its arches was a course of bricks with tiles on top
					# and a cut under, and its nose came away from it; laid in
					# plates, the layers cross the joints. (A ceiling with more
					# courses over it, as a hollow sculpt's is, keeps bricks.)
					if bridges and j > 0 and at(cell, j - 1) < 0 and not body(cell, j + 3):
						continue
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
				# Where a plate's edge part follows the edge and no brick's
				# does, the studs it would take are left to the plates, which
				# come in more cuts than bricks do: laid in bricks, a round
				# body's rim was a staircase up every course.
				var trial: Dictionary = bricks.duplicate()
				var cut_before: Dictionary = cut_in.duplicate()
				_wedged(trial, j + 1)
				cut_in = cut_before
				for key: Variant in bricks.keys():
					if not trial.has(key):
						bricks.erase(key)
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
			if int(round(float((made[n] as Dictionary)["y"]))) > lowest:
				continue
			# A shell on its side is held where a side stud reaches its foot,
			# not wherever its foot is.
			var seeded: bool = held.is_empty()
			for cell: Vector2i in (made[n] as Dictionary).get("_base", []):
				seeded = seeded or held.has(cell)
			if seeded:
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
		for _round: int in 96:
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
				for piece: Array in found.slice(1):
					if _unedge(piece, main):
						joined_one = true
						break
			# A sculpt's grid keeps its bricks, as it does over a bridge.
			if not joined_one and bridges:
				for piece: Array in found.slice(1):
					if _unbrick(piece, main):
						joined_one = true
						break
			if not joined_one:
				break

	## An edge part where [param piece] meets the rest, side by side at the
	## same height, laid again as the plates or bricks of its studs, and its
	## mirror with it, so the two can be stitched by plain parts. A wedge or a
	## round part at the joint left a twenty-stud bunny's feet apart from it.
	## Whether one was.
	func _unedge(piece: Array, main: Dictionary) -> bool:
		var by_cell: Dictionary = {}    ## Vector3i(x, y, z) -> index, its cells
		for n: int in made.size():
			var one: Dictionary = made[n]
			for cell: Vector2i in one.get("_covers", one.get("_cells", [])):
				for h: int in int(one.get("_h", 1)):
					by_cell[Vector3i(cell.x, int(round(float(one["y"]))) + h, cell.y)] = n
		var mine: Dictionary = {}
		for n: int in piece:
			mine[n] = true
		for n: int in made.size():
			var one: Dictionary = made[n]
			if not bool(one.get("_edge", false)):
				continue
			var y: int = int(round(float(one["y"])))
			var touches: bool = false
			for cell: Vector2i in one["_covers"]:
				for step: Vector2i in Shapes.OUT:
					for h: int in int(one["_h"]):
						var other: int = int(by_cell.get(Vector3i(cell.x + step.x, y + h,
							cell.y + step.y), -1))
						if other >= 0 and (mine.has(n) and main.has(other)
								or main.has(n) and mine.has(other)):
							touches = true
			if not touches:
				continue
			var gone: Dictionary = {n: true}
			if not axis.is_empty():
				var want: Dictionary = {}
				for cell: Vector2i in one["_cells"]:
					want[reflect(cell)] = true
				for m: int in made.size():
					var two: Dictionary = made[m]
					if m != n and bool(two.get("_edge", false)) and int(round(float(two["y"]))) == y \
							and (two["_cells"] as Array).size() == want.size():
						var same: bool = true
						for cell: Vector2i in two["_cells"]:
							same = same and want.has(cell)
						if same:
							gone[m] = true
							break
			var added: Array = []
			for m: Variant in gone:
				var edge_part: Dictionary = made[m]
				var height: int = int(edge_part["_h"])
				var tiles: Array = Shapes.CORE_PLATES if height == 1 else Shapes.CORE_BRICKS
				# Its studs, and the plan's studs it covered in part.
				var studs: Dictionary = {}
				for cell: Vector2i in edge_part["_covers"]:
					var free: bool = true
					for h: int in height:
						var other: int = int(by_cell.get(Vector3i(cell.x, y + h, cell.y), -1))
						free = free and at(cell, y + h) >= 0 and (other < 0 or gone.has(other))
					if free or (edge_part["_cells"] as Array).has(cell):
						studs[cell] = true
				for part: Dictionary in _tile(studs, y, int(edge_part["color"]), tiles, {}, -1):
					added.append(_annotated(part, tiles, height, true))
			var kept: Array = []
			for m: int in made.size():
				if not gone.has(m):
					kept.append(made[m])
			made = kept + added
			return true
		return false

	## A brick of the rest beside a plate of [param piece] within its course,
	## laid again as three plates, and its mirror with it, so the two can be
	## stitched by a plate reaching across. Whether one was. The held-out car's
	## nose, past its front arch, was plates beside the body's middle brick
	## course with tiles over it: 14 parts held by nothing, and the run threw
	## the shaped body away.
	func _unbrick(piece: Array, main: Dictionary) -> bool:
		var plates: Dictionary = {}    ## Vector3i(x, y, z) -> a plate of the piece there
		for n: int in piece:
			var one: Dictionary = made[n]
			if not _plain(one) or int(one["_h"]) != 1:
				continue
			for cell: Vector2i in one["_cells"]:
				plates[Vector3i(cell.x, int(round(float(one["y"]))), cell.y)] = n
		for m: Variant in main:
			var two: Dictionary = made[m]
			# Not a side-stud brick: what it holds is laid already.
			if not _plain(two) or int(two["_h"]) != 3 or two.has("_holds"):
				continue
			var y: int = int(round(float(two["y"])))
			var beside: bool = false
			for cell: Vector2i in two["_cells"]:
				for step: Vector2i in Shapes.OUT:
					for h: int in 3:
						var n: int = int(plates.get(Vector3i(cell.x + step.x, y + h, cell.y + step.y), -1))
						beside = beside or n >= 0 and int((made[n] as Dictionary)["color"]) == int(two["color"])
			if not beside:
				continue
			var gone: Dictionary = {int(m): true}
			if not axis.is_empty():
				var want: Dictionary = {}
				for cell: Vector2i in two["_cells"]:
					want[reflect(cell)] = true
				for k: int in made.size():
					var other: Dictionary = made[k]
					if k == int(m) or other.get("part") != two.get("part") \
							or int(round(float(other["y"]))) != y \
							or (other["_cells"] as Array).size() != want.size():
						continue
					var same: bool = true
					for cell: Vector2i in other["_cells"]:
						same = same and want.has(cell)
					if same:
						gone[k] = true
						break
			var added: Array = []
			for k: Variant in gone:
				var brick: Dictionary = made[k]
				var cells: Dictionary = {}
				for cell: Vector2i in brick["_cells"]:
					cells[cell] = true
				for h: int in 3:
					for part: Dictionary in _tile(cells.duplicate(), y + h, int(brick["color"]),
							Shapes.CORE_PLATES, {}, -1):
						added.append(_annotated(part, Shapes.CORE_PLATES, 1, true))
			var kept: Array = []
			for k: int in made.size():
				if not gone.has(k):
					kept.append(made[k])
			made = kept + added
			return true
		return false

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

	## Round parts and wedges where a layer's plan edge runs off the square,
	## each laid with its mirror; the studs they cover come out of [param
	## cells].
	##
	## A part goes where it brings the layer's outline nearer the shape's own
	## edge than the studs it replaces, measured stud by stud on a 4 x 4 grid
	## of what it covers against what the shape does (_gain). Its cut side
	## lies across a stud the edge cuts, inside the plan or out of it, and a
	## stud of the plan it covers only in part is its own. The first rule, a
	## wedge's cut side outside every stud of the plan and a fifth to four
	## fifths inside the shape, could not be met on a round plan, whose rim
	## studs are the ones the edge cuts: a cylinder of radius 5, a box with
	## 45 degree corners and an egg came out staircases with no wedge in them,
	## and four of five held-out designs looked stepped for it.
	##
	## Round parts first, then the rest, as a set rounds a body: in each pass
	## the part that brings the outline nearest first.
	func _wedged(cells: Dictionary, j: int, height: int = 1) -> Array:
		if cells.size() < 4 or library == null or not wedges or not sample.is_valid():
			return []
		var parts: Dictionary = Shapes.edge_parts(library, height)
		if parts.is_empty():
			return []
		var by_colour: Dictionary = {}
		for key: Variant in cells:
			var c: int = cells[key]
			if not by_colour.has(c):
				by_colour[c] = {}
			(by_colour[c] as Dictionary)[key] = true
		# Every stud of the shape at this plate, laid or not: a part's cut side
		# takes only studs still to be laid here, never one a brick or another
		# colour has.
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
		# The studs either side of the plan's edge: the only ones a part may
		# cover in part.
		var edge: Dictionary = {}
		for key: Variant in solid:
			for dx: int in range(-1, 2):
				for dz: int in range(-1, 2):
					var beside: Vector2i = (key as Vector2i) + Vector2i(dx, dz)
					if not solid.has(beside):
						edge[beside] = true
						edge[key] = true
		var state := {"solid": solid, "edge": edge, "built": {}, "claimed": {}, "truth": {},
			"j": j, "height": height}
		var out: Array = []
		var names: Array = parts.keys()
		names.sort()
		var spots: Array = edge.keys()
		spots.sort()
		for c: Variant in by_colour:
			var wanted: Dictionary = by_colour[c]
			for round_pass: bool in [true, false]:
				var tried: Array = []
				for named: String in names:
					var part: Array = parts[named]
					if bool(part[5]) != round_pass:
						continue
					for key: Variant in spots:
						var corner: Vector2i = (key as Vector2i) - (part[4] as Vector2i)
						var gain: int = _gain(part, corner, wanted, state)
						if gain >= MIN_GAIN:
							tried.append([gain, (part[2] as Dictionary).size(), named, corner])
				tried.sort_custom(func(a: Array, b: Array) -> bool:
					if a[0] != b[0]:
						return a[0] > b[0]
					if a[1] != b[1]:
						return a[1] > b[1]
					if a[2] != b[2]:
						return a[2] < b[2]
					return a[3].x < b[3].x or a[3].x == b[3].x and a[3].y < b[3].y)
				for one: Array in tried:
					var named: String = one[2]
					var corner: Vector2i = one[3]
					var part: Array = parts[named]
					if _gain(part, corner, wanted, state) < MIN_GAIN:
						continue
					var family: Array = [[named, corner]]
					if not axis.is_empty():
						var twin: Array = _twin(parts, named, corner)
						if twin.is_empty():
							continue
						if twin[0] != named or twin[1] != corner:
							if _gain(parts[twin[0]], twin[1], wanted, state) < MIN_GAIN \
									or _overlap(part, corner, parts[twin[0]], twin[1]):
								continue
							family.append(twin)
					for member: Array in family:
						var studs: Array[Vector2i] = _take_edge(parts[member[0]], member[1],
							wanted, cells, state)
						var placed: Dictionary = Patterns._placement(member[0], [], member[1], j,
							int(c))
						var whole: Array[Vector2i] = []
						var covers: Dictionary = (parts[member[0]] as Array)[3]
						for key: Variant in covers:
							if int(covers[key]) == Shapes.FULL:
								whole.append((member[1] as Vector2i) + (key as Vector2i))
						placed["_cells"] = studs
						placed["_h"] = height
						placed["_studs"] = studs
						placed["_base"] = whole
						placed["_slope"] = true
						placed["_edge"] = true
						var touched: Array[Vector2i] = []
						for key: Variant in covers:
							touched.append((member[1] as Vector2i) + (key as Vector2i))
						placed["_covers"] = touched
						out.append(placed)
		return out

	## Less than a quarter of a stud nearer the shape is no reason to lay a
	## part.
	const MIN_GAIN := 4

	## How much nearer the shape's edge the outline comes with [param part]
	## at [param corner] than without it, in sixteenths of a stud; -1 where it
	## cannot go: a stud of it not still to be laid here, a stud it covers in
	## part away from the edge or laid by something else, or anything it
	## covers covered already.
	func _gain(part: Array, corner: Vector2i, wanted: Dictionary, state: Dictionary) -> int:
		for key: Variant in part[2]:
			if not wanted.has(corner + (key as Vector2i)):
				return -1
		var solid: Dictionary = state["solid"]
		var edge: Dictionary = state["edge"]
		var built: Dictionary = state["built"]
		var claimed: Dictionary = state["claimed"]
		var covers: Dictionary = part[3]
		var gain: int = 0
		var slanted: bool = false
		for key: Variant in covers:
			var cell: Vector2i = key
			var here: int = covers[cell]
			var at_: Vector2i = corner + cell
			var mine: bool = wanted.has(at_)
			if mine:
				if here != Shapes.FULL and not edge.has(at_):
					return -1
				if not (part[2] as Dictionary).has(cell) and not _may_cut(at_, state):
					return -1
			elif solid.has(at_):
				if not claimed.has(at_):
					return -1
			elif not edge.has(at_):
				return -1
			var already: int = int(built.get(at_, 0))
			if already & here:
				return -1
			var truth: int = _truth(at_, state)
			slanted = slanted or not Shapes.square(truth)
			var before: int = Shapes.FULL if mine else already
			var after: int = here | already
			gain += Shapes.ones(before ^ truth) - Shapes.ones(after ^ truth)
		# An edge that runs square across every stud it covers is the studs'
		# own: a ramp's falls each cross a stud half way, and wedges laid there
		# sawed a straight edge into teeth.
		return gain if slanted else -1

	## What the shape covers of the stud at [param cell], in the middle of the
	## layer, as 16 bits.
	func _truth(cell: Vector2i, state: Dictionary) -> int:
		var known: Dictionary = state["truth"]
		if known.has(cell):
			return known[cell]
		var y: float = float(state["j"]) + float(state["height"]) / 2.0
		var bits: int = 0
		for v: int in 4:
			for u: int in 4:
				if sample.call(cell.x + (u + 0.5) / 4.0, y, cell.y + (v + 0.5) / 4.0):
					bits |= 1 << (v * 4 + u)
		known[cell] = bits
		return bits

	## Lay [param part]: what it covers is built, and every stud it covers,
	## whole or in part, is no longer to be laid. The studs on its top.
	func _take_edge(part: Array, corner: Vector2i, wanted: Dictionary, cells: Dictionary,
			state: Dictionary) -> Array[Vector2i]:
		var built: Dictionary = state["built"]
		var claimed: Dictionary = state["claimed"]
		var covers: Dictionary = part[3]
		var j: int = state["j"]
		for key: Variant in covers:
			var at_: Vector2i = corner + (key as Vector2i)
			built[at_] = int(built.get(at_, 0)) | int(covers[key])
			claimed[at_] = true
			if wanted.has(at_) and not (part[2] as Dictionary).has(key):
				for n: int in int(state["height"]):
					cut_in[Vector3i(at_.x, j + n, at_.y)] = true
			wanted.erase(at_)
			cells.erase(at_)
		var studs: Array[Vector2i] = []
		for key: Variant in part[2]:
			studs.append(corner + (key as Vector2i))
		return studs

	## Plates of the shape a part covers without a stud on them: what is over
	## or under one there is not held through it. Vector3i(x, j, z) -> true.
	var cut_in: Dictionary = {}

	## Whether a stud of the plan may be covered without a stud on it: where
	## the shape ends over it or under it, or the stud under it is not held
	## through either, so no column of the shape is cut through the middle.
	## Cut anywhere, a twenty-stud bunny's legs were wedges over wedges
	## that met at no stud, and it stood on its feet with its body beside them.
	func _may_cut(cell: Vector2i, state: Dictionary) -> bool:
		var j: int = state["j"]
		var below := Vector3i(cell.x, j - 1, cell.y)
		return at(cell, j - 1) < 0 or at(cell, j + int(state["height"])) < 0 \
			or cut_in.has(below) or taken.has(below)

	## Do two parts cover any of the same bits?
	func _overlap(one: Array, here: Vector2i, two: Array, there: Vector2i) -> bool:
		var covers: Dictionary = two[3]
		for key: Variant in one[3]:
			var other: Vector2i = here + (key as Vector2i) - there
			if covers.has(other) and int(covers[other]) & int((one[3] as Dictionary)[key]):
				return true
		return false

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
