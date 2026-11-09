## A weak joint made to hold in one action, with the fewest parts a builder
## would add (docs/APP_UX8.md, unit 8).
##
## View, Stress names each joint that alone holds what is past it, levered
## about the edge it would turn on, and how near its studs' working load it
## is (StressView, Balance). Studio's check colours parts and stops there; a
## builder told "the deck is on one stud" adds a part. This finds the part,
## of three kinds, each the way a builder does it:
## - a plate across the seam ("tie"): a plate laid over the part past the
##   joint and a part of the side that holds, clutching both, so the load
##   has two ways down. Where the two tops differ, on a plate or a brick
##   standing on the lower first; or under the two, its studs up in them;
## - a brick under it ("prop"): up to three bricks and plates, from the
##   ground, the baseplate or a part below, up into the part past the joint;
## - a pin ("pin"): a friction pin through the next two holes in line beside
##   a joint that pins hold on one line, which then cannot turn.
##
## Each is checked for room as a part put down is (Builder.room_for), weighed
## as one with the joint by Balance's rule (M = Σ F·dᵢ about the edge it
## would turn on, each stud F = 1 N working), worst of every way the load
## could come off; and then the model is weighed with it as View, Stress
## weighs it (Balance.measure). It is offered only when its joint is then
## above its working load and no joint that held before is past its own.
##
## In the person's own parts when asked ([member owned]): each part in a
## colour they own, with one left after what the model already uses.
class_name Strengthen
extends RefCounted

## What a fix aims for: twice its working load, out of View, Stress's amber.
const TARGET := 2.0
## At most this many parts.
const MOST := 3
## How far beside the parts past a joint the side that holds is looked
## for, LDU: two studs.
const STUD_REACH := 40.0
## How far along a tie its two ends may be, LDU: a 1 x 6's.
const TIE_REACH := 100.0
## Of the parts past a joint, how many are looked under for a prop.
const PROP_PARTS := 120
## How many of the best are weighed with the model before giving up.
const TRIES := 4
## A part placed above the model's own: numbers no brick has, for the
## weighing with a fix in it.
const SPARE_FROM := 1 << 30

## The plates a tie is laid with, and the bricks a tie over the seam is.
const TIES := ["3023b", "3623", "3710", "3666", "3022", "3021", "3020", "3795"]
const OVERS := ["3004", "3010", "3003", "3001"]
## Each footprint's parts by how tall they stand, LDU: what a filler or a
## prop is made of. A footprint is "across x deep", in studs.
const STACKS := {
	"1x1": {8: "3024", 24: "3005", 72: "14716", 120: "2453b"},
	"1x2": {8: "3023b", 24: "3004", 48: "3245c", 72: "22886"},
	"1x3": {8: "3623", 24: "3622"},
	"1x4": {8: "3710", 24: "3010"},
	"2x2": {8: "3022", 24: "3003"},
	"2x3": {8: "3021", 24: "3002"},
	"2x4": {8: "3020", 24: "3001"},
}
## A friction pin, as Technic builders brace a beam with a second.
const PIN := "2780"
const PIN_COLOUR := 0
const GHOST_THROUGH := preload("res://src/render/ghost_through.gdshader")

var world: BrickWorld
var library: PartLibrary
var builder: Builder
## The floor's parts (ModelStore.scenery): the baseplate a prop may stand on.
var scenery: Dictionary = {}
## What the person owns, "part/colour" -> count (CollectionStore.on_hand),
## when a fix is to be made of it; empty for any part.
var owned: Dictionary = {}

## The tree of what holds what, read once a revision of the model.
var _tree: Balance = null
var _tree_revision: int = -1


## One fix: its parts, where they go, and what it does.
class Fix extends RefCounted:
	## "tie", "prop" or "pin".
	var kind: String = ""
	## {part, color, at: Transform3D} each, in the order they go down.
	var parts: Array = []
	## The part past the joint it fixes (StressView.Weak.id).
	var weak: int = 0
	## The joint's margin before, and as one with the fix after (INF: nothing
	## levers it, or held square).
	var before: float = 0.0
	var held: float = INF
	## Every part one the person owns, with one left over the model's own.
	var mine: bool = true
	## What it is, for the panel and a session: "a Plate 1 x 4 across the
	## seam, over the Brick 1 x 4 beside it".
	var what: String = ""
	## The model's revision it was found for.
	var revision: int = 0


## The fix for the weak place [param weak] (StressView.Weak) in the model as
## [param weighed] has it, or null when no part of up to three makes it hold.
## A coroutine: a big model's tree and weighing are read on a worker.
func find(weighed: Stability.Report, weak: StressView.Weak) -> Fix:
	if weighed == null or weak == null or world.get_brick(weak.id) == null:
		return null
	var revision: int = world.revision
	var side: Dictionary = {}
	if weak.joint == null:
		for id: Variant in weak.ids:
			side[int(id)] = true
	else:
		if _tree == null or _tree_revision != revision:
			_tree = await _read_tree()
			_tree_revision = revision
		if world.revision != revision or _tree == null:
			return null
		for id: int in _tree.past(weak.joint.beyond):
			side[id] = true
	if side.is_empty():
		return null
	var found: Array = _candidates(weak, side)
	var reds: int = _past(weighed.margins, weighed.tipping)
	var tried: int = 0
	for one: Dictionary in found:
		if tried >= TRIES:
			break
		tried += 1
		var after: Balance.Report = await _weigh_with(one["parts"])
		if world.revision != revision:
			return null
		if after == null or not _holds(after, weak, reds):
			continue
		var fix := Fix.new()
		fix.kind = one["kind"]
		fix.parts = one["parts"]
		fix.weak = weak.id
		fix.before = weak.margin
		fix.held = one["held"]
		fix.mine = one["mine"]
		fix.what = one["what"]
		fix.revision = revision
		return fix
	return null


## Put [param fix] down: one step to undo, called what it is, into the
## sub-assembly being edited as a part put down by hand goes. The new
## parts' ids; none when the model has changed since it was found or a part
## has no room now.
func place(fix: Fix) -> PackedInt64Array:
	var made := PackedInt64Array()
	if fix == null or fix.revision != world.revision or not _room(fix.parts):
		return made
	var path: String = builder.place_group
	var step: int = int(builder.place_step.call(path)) if builder.place_step.is_valid() else -1
	var adds: Array = []
	for item: Dictionary in fix.parts:
		adds.append({"part": item["part"], "color": item["color"], "at": item["at"],
			"path": path, "step": step})
	var steps: Array = builder.swap_bricks(PackedInt64Array(), adds)
	for one: Dictionary in steps:
		made.append(int(one["brick"]))
	builder.record(steps, "Strengthen: " + fix.what)
	return made


## The fix's parts as one ghost, a surface per colour (ghost.gdshader), as
## Edit, Pattern shows its copies; and drawn faint where the model hides it
## (ghost_through.gdshader), since a pin's ghost is inside two holes.
static func ghost_mesh(parts: Array, from: PartLibrary) -> ArrayMesh:
	var by_colour: Dictionary = {}
	for item: Dictionary in parts:
		var part: Lbm.PartMesh = from.mesh_for(str(item["part"]))
		if part == null:
			continue
		for s: int in part.surface_count():
			var code: int = part.surface_colors[s] if s < part.surface_colors.size() \
				else Lbm.COLOR_INHERIT
			if code == Lbm.COLOR_INHERIT:
				code = int(item["color"])
			var tool: SurfaceTool = by_colour.get(code)
			if tool == null:
				tool = SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_colour[code] = tool
			tool.append_from(part.surfaces[s], 0, item["at"])
	var mesh := ArrayMesh.new()
	for code: int in by_colour:
		(by_colour[code] as SurfaceTool).commit(mesh)
		var material := ShaderMaterial.new()
		material.shader = Pattern.GHOST_SHADER
		material.set_shader_parameter("tint", from.color(code).shown)
		material.set_shader_parameter("valid", true)
		var through := ShaderMaterial.new()
		through.shader = GHOST_THROUGH
		through.set_shader_parameter("tint", from.color(code).shown)
		material.next_pass = through
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## What the fix leaves the joint holding, a sentence: "Then it holds about
## 3.1 times its working load", "Then it is held square, on pins on two
## lines", "Then nothing levers it".
static func held_words(fix: Fix) -> String:
	if fix.kind == "pin":
		return "Then it is held square, on pins on two lines"
	if fix.held >= 100.0:
		return "Then nothing levers it"
	return "Then it holds about %s times its working load" % Balance.studs(fix.held)


# -- the side that comes off ------------------------------------------------------


## The tree of what holds what (Balance.prepare), on a worker for a big
## model, on copies of the model and the lattice nothing changes.
func _read_tree() -> Balance:
	var tree := Balance.new()
	tree.library = library
	tree.floor_ids = scenery.duplicate()
	if world.brick_count() < Stability.ON_A_WORKER_FROM or OS.has_feature("nothreads"):
		tree.lattice = builder.lattice
		return tree if tree.prepare(world.bricks()) else null
	tree.lattice = builder.lattice.copy_for_reading()
	var still: BrickWorld = world.copy_for_reading()
	var ready: bool = await WorkerTasks.awaited(func() -> Variant:
		return tree.prepare(still.bricks()), "find what a joint holds", library)
	still.free()
	return tree if ready else null


# -- the candidates -----------------------------------------------------------------


## Every fix with room, best first: those that bring the joint to twice its
## working load as one with it (TARGET) first, a pin before a tie and a tie
## before a prop, then the fewest parts and the smallest; then the rest that
## at least bring it to its working load, the most hold first. Each {kind, parts, held, mine,
## what}.
func _candidates(weak: StressView.Weak, side: Dictionary) -> Array:
	var near: Array = _near(weak, side)
	var found: Array = []
	if weak.joint != null and weak.joint.kind in ["friction pin", "free pin"]:
		found.append_array(_pins(weak, near))
	found.append_array(_ties(weak, side, near))
	found.append_array(_props(weak, side))
	var mass: Array = _mass_of(side)
	var kept: Array = []
	var seen: Dictionary = {}
	for one: Dictionary in found:
		var key: String = _key_of(one["parts"])
		if seen.has(key):
			continue
		seen[key] = true
		one["held"] = INF if one["kind"] == "pin" else _held(weak, one, mass)
		if float(one["held"]) < StressView.WEAK:
			continue
		kept.append(one)
	var order: Dictionary = {"pin": 0, "tie": 1, "prop": 2}
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_ok: bool = float(a["held"]) >= TARGET
		var b_ok: bool = float(b["held"]) >= TARGET
		if a_ok != b_ok:
			return a_ok
		if not a_ok and absf(float(a["held"]) - float(b["held"])) > 0.05:
			# Short of the aim, the one that holds most.
			return float(a["held"]) > float(b["held"])
		if order[a["kind"]] != order[b["kind"]]:
			return order[a["kind"]] < order[b["kind"]]
		if (a["parts"] as Array).size() != (b["parts"] as Array).size():
			return (a["parts"] as Array).size() < (b["parts"] as Array).size()
		# At the aim, the smallest part that does it, as a builder reaches.
		if absf(float(a["cost"]) - float(b["cost"])) > 0.01:
			return float(a["cost"]) < float(b["cost"])
		return minf(float(a["held"]), 100.0) > minf(float(b["held"]), 100.0))
	# Room asked of the best only: it is the costliest test here.
	var out: Array = []
	for one: Dictionary in kept:
		if out.size() >= TRIES * 3:
			break
		if not _room(one["parts"]):
			continue
		if not _colour(one):
			continue
		out.append(one)
	# What the person owns first, when that was asked; the rest after.
	if not owned.is_empty():
		var theirs: Array = out.filter(func(one: Dictionary) -> bool: return bool(one["mine"]))
		out = theirs + out.filter(func(one: Dictionary) -> bool: return not bool(one["mine"]))
	return out


## The parts round the joint, either side: the nearest of those past it,
## and of the rest those beside them ([constant STUD_REACH]), nearest first.
## A one-wide wall's half on one stud is tied at its top, eight courses
## from its joint: the seam is wherever the two sides meet.
func _near(weak: StressView.Weak, side: Dictionary) -> Array:
	var middle: Vector3 = weak.joint.at if weak.joint != null else _box(weak.id).get_center()
	var by_distance := func(a: int, b: int) -> bool:
		return _box(a).get_center().distance_to(middle) < _box(b).get_center().distance_to(middle)
	var ours: Array = []
	for id: Variant in side:
		var brick: BrickWorld.Brick = world.get_brick(int(id))
		if brick != null and not brick.hidden:
			ours.append(int(id))
	ours.sort_custom(by_distance)
	ours = ours.slice(0, PROP_PARTS)
	var reach := AABB()
	for n: int in ours.size():
		reach = _box(ours[n]) if n == 0 else reach.merge(_box(ours[n]))
	reach = reach.grow(STUD_REACH)
	var theirs: Array = []
	for id: int in builder.lattice.blockers_boxes(_cells_of(reach), 0, side):
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick == null or brick.hidden or side.has(id) or scenery.has(id):
			continue
		theirs.append(id)
	theirs.sort_custom(by_distance)
	return [ours, theirs.slice(0, PROP_PARTS)]


# -- a plate across the seam ---------------------------------------------------------


## Plates laid across a part past the joint and one of the side that holds:
## over their tops where they stand level, or a plate or a brick under the
## lower first; or under their bottoms where those are level and open.
func _ties(weak: StressView.Weak, side: Dictionary, near: Array) -> Array:
	var out: Array = []
	var ours: Dictionary = _studs_by_level(near[0], true)
	var theirs: Dictionary = _studs_by_level(near[1], true)
	for high: Variant in ours:
		for low: Variant in theirs:
			var rise: int = int(high) - int(low)
			if absi(rise) > 48 or posmod(absi(rise), 8) != 0:
				continue
			if rise >= 0:
				out.append_array(_over(ours[high], theirs[low], rise, true, int(high)))
			else:
				out.append_array(_over(theirs[low], ours[high], -rise, false, int(low)))
	var under_ours: Dictionary = _studs_by_level(near[0], false)
	var under_theirs: Dictionary = _studs_by_level(near[1], false)
	for level: Variant in under_ours:
		if under_theirs.has(level):
			out.append_array(_under(under_ours[level], under_theirs[level], int(level)))
	for one: Dictionary in out:
		one["kind"] = "tie"
	return out


## Free studs facing up (or free sockets facing down, [param up] false) of
## [param ids], by the height of the face they are on, LDU: level ->
## [[position, brick id], ...].
func _studs_by_level(ids: Array, up: bool) -> Dictionary:
	var out: Dictionary = {}
	# A socket on the ground or the baseplate is not open.
	var ground: float = _floor_top()
	for id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if part == null or (brick.transform.basis * Vector3.UP).normalized().y < 0.99:
			continue
		var points: Array = []
		if up:
			for connector: Lbm.Connector in part.connectors:
				if connector.kind == "stud" \
						and (brick.transform.basis * connector.axis).normalized().y > 0.99:
					points.append(brick.transform * connector.position)
		else:
			var bottom: float = _cover_span(part).x
			for socket: Vector2 in part.sockets:
				points.append(brick.transform * Vector3(socket.x, bottom, socket.y))
		for point: Vector3 in points:
			var at := Vector3(roundf(point.x), roundf(point.y), roundf(point.z))
			if (not up and at.y <= ground + 0.5) or not _free(at, up, id):
				continue
			var level: int = int(at.y)
			if not out.has(level):
				out[level] = []
			(out[level] as Array).append([at, id])
	return out


## Plates over [param high_studs] (one side's, at [param level]) and
## [param low_studs] (the other's, [param rise] LDU lower, under a filler):
## [param ours_high] says whether the high side is the part's past the joint.
func _over(high_studs: Array, low_studs: Array, rise: int, ours_high: bool,
		level: int) -> Array:
	var out: Array = []
	if high_studs.is_empty() or low_studs.is_empty():
		return out
	var phase: Vector3 = high_studs[0][0]
	var lows: Dictionary = {}
	for one: Array in low_studs:
		var at: Vector3 = one[0]
		if not _in_phase(at, phase):
			return out
		lows[_cell_key(at)] = one
	var highs: Dictionary = {}
	for one: Array in high_studs:
		highs[_cell_key(one[0])] = one
	# A tie starts from a stud no further from the other side than it is long.
	var anchors: Array = high_studs.filter(func(one: Array) -> bool:
		return _within(one[0], low_studs, TIE_REACH))
	var tried: Dictionary = {}
	for part_id: String in TIES + OVERS:
		var size: Vector2i = _footprint(part_id)
		if size == Vector2i.ZERO:
			continue
		for turned: bool in [false, true]:
			var across: int = size.y if turned else size.x
			var deep: int = size.x if turned else size.y
			if turned and across == deep:
				continue
			for anchor: Array in anchors:
				var stud: Vector3 = anchor[0]
				for i: int in across:
					for k: int in deep:
						var start := Vector3(stud.x - i * 20.0, level, stud.z - k * 20.0)
						var key: String = "%s|%d|%s" % [part_id, int(turned), _cell_key(start)]
						if tried.has(key):
							continue
						tried[key] = true
						var made: Variant = _tie_over(part_id, turned, start, across, deep, highs,
							lows, rise, ours_high, level)
						if made != null:
							out.append(made)
	return out


## One tie over the seam, its first stud at [param start]: null unless it
## covers a stud of each side, and under it a filler that stands on the
## lower side's studs it covers, every one of them.
func _tie_over(part_id: String, turned: bool, start: Vector3, across: int, deep: int,
		highs: Dictionary, lows: Dictionary, rise: int, ours_high: bool, level: int) -> Variant:
	var on_high: Array = []
	var on_low: Array = []
	var bare: int = 0
	for i: int in across:
		for k: int in deep:
			var at := Vector3(start.x + i * 20.0, level, start.z + k * 20.0)
			var low_at := Vector3(at.x, level - rise, at.z)
			if highs.has(_cell_key(at)):
				on_high.append(highs[_cell_key(at)])
			elif lows.has(_cell_key(low_at)):
				on_low.append(lows[_cell_key(low_at)])
			else:
				bare += 1
	if on_high.is_empty() or on_low.is_empty():
		return null
	var parts: Array = []
	var chain_low: Array = []
	if rise > 0:
		# The filler: the lower side's studs the tie covers, all of them,
		# raised to the high side's level.
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for one: Array in on_low:
			var at: Vector3 = one[0]
			lo = lo.min(Vector2(at.x, at.z))
			hi = hi.max(Vector2(at.x, at.z))
		var wide: int = roundi((hi.x - lo.x) / 20.0) + 1
		var long: int = roundi((hi.y - lo.y) / 20.0) + 1
		if wide * long != on_low.size():
			return null
		var stack: Array = _stack_for(wide, long, rise, MOST - 1)
		if stack.is_empty():
			return null
		var bottom: float = level - rise
		for filler: String in stack:
			var placed: Variant = _laid(filler, Vector3(lo.x, bottom, lo.y), wide, long)
			if placed == null:
				return null
			parts.append({"part": filler, "at": placed, "role": "filler"})
			chain_low.append(parts.size() - 1)
			bottom += _height_of(filler)
	var tie: Variant = _laid(part_id, start, across, deep)
	if tie == null:
		return null
	parts.append({"part": part_id, "at": tie, "role": "tie"})
	var tie_index: int = parts.size() - 1
	# The chain from the side that holds to the side past the joint: each
	# part on the one before it.
	var high_id: int = int(on_high[0][1])
	var low_id: int = int(on_low[0][1])
	var chain: Array
	if ours_high:
		chain = [low_id] + chain_low.map(func(n: int) -> String: return "#%d" % n) \
			+ ["#%d" % tie_index, high_id]
	else:
		chain = [high_id, "#%d" % tie_index] + _reversed(chain_low.map(func(n: int) -> String:
			return "#%d" % n)) + [low_id]
	var over: bool = OVERS.has(part_id)
	return {"parts": parts, "chain": chain, "joined": [high_id, low_id],
		"cost": parts.size() * 10.0 + bare + (4.0 if over else 0.0) + across * deep * 0.1,
		"how": "over" if over else "across", "tie": part_id}


## Plates under the seam: their studs up in the open sockets of a part past
## the joint and one of the side that holds, both at [param level].
func _under(ours: Array, theirs: Array, level: int) -> Array:
	var out: Array = []
	if ours.is_empty() or theirs.is_empty():
		return out
	var phase: Vector3 = ours[0][0]
	var mine: Dictionary = {}
	for one: Array in ours:
		mine[_cell_key(one[0])] = one
	var other: Dictionary = {}
	for one: Array in theirs:
		if not _in_phase(one[0], phase):
			return out
		other[_cell_key(one[0])] = one
	var anchors: Array = ours.filter(func(one: Array) -> bool:
		return _within(one[0], theirs, TIE_REACH))
	var tried: Dictionary = {}
	for part_id: String in TIES:
		var size: Vector2i = _footprint(part_id)
		for turned: bool in [false, true]:
			var across: int = size.y if turned else size.x
			var deep: int = size.x if turned else size.y
			if turned and across == deep:
				continue
			for anchor: Array in anchors:
				var socket: Vector3 = anchor[0]
				for i: int in across:
					for k: int in deep:
						var start := Vector3(socket.x - i * 20.0, level, socket.z - k * 20.0)
						var key: String = "%s|%d|%s" % [part_id, int(turned), _cell_key(start)]
						if tried.has(key):
							continue
						tried[key] = true
						var in_ours: Array = []
						var in_theirs: Array = []
						var bare: int = 0
						for a: int in across:
							for b: int in deep:
								var cell: String = _cell_key(Vector3(start.x + a * 20.0, level,
									start.z + b * 20.0))
								if mine.has(cell):
									in_ours.append(mine[cell])
								elif other.has(cell):
									in_theirs.append(other[cell])
								else:
									bare += 1
						if in_ours.is_empty() or in_theirs.is_empty():
							continue
						var height: float = _height_of(part_id)
						var at: Variant = _laid(part_id, Vector3(start.x, level - height, start.z),
							across, deep)
						if at == null:
							continue
						out.append({"parts": [{"part": part_id, "at": at, "role": "tie"}],
							"chain": [int(in_theirs[0][1]), "#0", int(in_ours[0][1])],
							"joined": [int(in_ours[0][1]), int(in_theirs[0][1])],
							"cost": 10.0 + bare + 2.0 + across * deep * 0.1, "how": "under",
							"tie": part_id})
	return out


# -- a brick under it ---------------------------------------------------------------


## Columns of up to three parts from what is under a part past the joint up
## into its open sockets: one stud, two or four.
func _props(weak: StressView.Weak, side: Dictionary) -> Array:
	var out: Array = []
	var middle: Vector3 = weak.joint.at if weak.joint != null else _box(weak.id).get_center()
	var ids: Array = side.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return _box(a).get_center().distance_to(middle) > _box(b).get_center().distance_to(middle))
	var sockets: Dictionary = _studs_by_level(ids.slice(0, PROP_PARTS), false)
	for level: Variant in sockets:
		var free: Dictionary = {}
		for one: Array in sockets[level]:
			free[_cell_key(one[0])] = one
		for one: Array in sockets[level]:
			var at: Vector3 = one[0]
			for size: Vector2i in [Vector2i(1, 2), Vector2i(2, 1), Vector2i(1, 1), Vector2i(2, 2)]:
				var under: Array = []
				for i: int in size.x:
					for k: int in size.y:
						var cell: String = _cell_key(Vector3(at.x + i * 20.0, at.y, at.z + k * 20.0))
						if free.has(cell):
							under.append(free[cell])
				if under.size() != size.x * size.y:
					continue
				var made: Variant = _prop(at, size, int(level), under, side)
				if made != null:
					out.append(made)
	for one: Dictionary in out:
		one["kind"] = "prop"
	return out


## One column under the sockets from [param at], [param size] studs: down to
## what stands below it, which must not come off with the joint.
func _prop(at: Vector3, size: Vector2i, level: int, under: Array, side: Dictionary) -> Variant:
	# The column's footprint, a cell inside its edges, from the ground up.
	var x0: float = at.x - 10.0 + BrickLattice.CELL
	var z0: float = at.z - 10.0 + BrickLattice.CELL
	var x1: float = at.x - 10.0 + size.x * 20.0 - BrickLattice.CELL
	var z1: float = at.z - 10.0 + size.y * 20.0 - BrickLattice.CELL
	var lowest: float = _floor_top()
	var column := PackedInt32Array([int(floor(x0 / BrickLattice.CELL)),
		int(floor((lowest - 400.0) / BrickLattice.CELL)), int(floor(z0 / BrickLattice.CELL)),
		int(ceil(x1 / BrickLattice.CELL)), int(floor(level / BrickLattice.CELL)),
		int(ceil(z1 / BrickLattice.CELL))])
	var top: float = lowest
	var on: int = 0
	for id: int in builder.lattice.blockers_boxes(column):
		var box: AABB = _box(id)
		var face: float = _cover_top(id)
		if face > top + 0.5 and face <= level + 0.5:
			if side.has(id):
				# What it would stand on comes off with the joint.
				top = face
				on = -1
			else:
				top = face
				on = id
		elif box.end.y > level + 0.5 and box.position.y < level - 0.5:
			return null
	if on < 0:
		return null
	var gap: int = roundi(level - top)
	if gap <= 0:
		return null
	var stack: Array = _stack_for(size.x, size.y, gap, MOST)
	if stack.is_empty():
		return null
	# Tallest at the foot, plates at the head.
	var parts: Array = []
	var bottom: float = top
	for part_id: String in stack:
		var placed: Variant = _laid(part_id, Vector3(at.x, bottom, at.z), size.x, size.y)
		if placed == null:
			return null
		parts.append({"part": part_id, "at": placed, "role": "prop"})
		bottom += _height_of(part_id)
	var chain: Array = ["floor" if on == 0 else on]
	for n: int in parts.size():
		chain.append("#%d" % n)
	chain.append(int(under[0][1]))
	return {"parts": parts, "chain": chain, "joined": [int(under[0][1]), on],
		"cost": parts.size() * 10.0 + gap / 24.0, "standing": on}


## The parts, tallest first, that make a column [param across] by
## [param deep] studs exactly [param rise] LDU tall, in at most [param most]
## parts; [] when none does.
func _stack_for(across: int, deep: int, rise: int, most: int) -> Array:
	var key: String = "%dx%d" % [mini(across, deep), maxi(across, deep)]
	var tall: Dictionary = STACKS.get(key, {})
	if tall.is_empty():
		return []
	var heights: Array = tall.keys()
	heights.sort()
	heights.reverse()
	# Filled in place: a lambda's own copy of a variable is not the caller's.
	var best: Array = []
	var search := func(left: int, from: int, so_far: Array, again: Callable) -> void:
		if left == 0:
			if best.is_empty() or so_far.size() < best.size():
				best.clear()
				best.append_array(so_far)
			return
		if so_far.size() >= most or (not best.is_empty() and so_far.size() + 1 >= best.size()):
			return
		for n: int in range(from, heights.size()):
			if int(heights[n]) <= left:
				so_far.append(tall[heights[n]])
				again.call(left - int(heights[n]), n, so_far, again)
				so_far.pop_back()
	search.call(rise, 0, [], search)
	return best


# -- a pin --------------------------------------------------------------------------


## A friction pin through two holes in line, one in a part past a joint
## pins hold on one line and one in a part of the side that holds, off that
## line: the two sides are then pinned on two lines, and cannot turn.
func _pins(weak: StressView.Weak, near: Array) -> Array:
	var out: Array = []
	var one: Balance.JointLoad = weak.joint
	if library.mesh_for(PIN) == null:
		return out
	var ours: Array = _holes_of(near[0])
	var theirs: Array = _holes_of(near[1])
	for ha: Array in ours:
		for hb: Array in theirs:
			var way: Vector3 = ha[1]
			if absf(way.dot(hb[1] as Vector3)) < 0.99:
				continue
			var gap: Vector3 = (hb[0] as Vector3) - (ha[0] as Vector3)
			var along: float = gap.dot(way)
			if absf(absf(along) - 20.0) > 1.0 or (gap - way * along).length() > 1.0:
				continue
			var middle: Vector3 = ((ha[0] as Vector3) + (hb[0] as Vector3)) * 0.5
			# Not on the line the joint already turns on.
			var off: Vector3 = middle - one.at
			if (off - way * off.dot(way)).length() < 4.0:
				continue
			var at: Variant = _pin_at(way, middle)
			if at == null:
				continue
			out.append({"kind": "pin", "parts": [{"part": PIN, "at": at, "role": "pin",
				"color": PIN_COLOUR}], "chain": [], "joined": [int(ha[2]), int(hb[2])],
				"cost": 10.0 + off.length() * 0.01})
	return out


## The pin holes of [param ids]' parts, where they are in the model:
## [middle, way, id] each, as Joints reads them.
func _holes_of(ids: Array) -> Array:
	var out: Array = []
	for id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if part == null:
			continue
		for hole: Array in Joints._lines_of(part)[1]:
			if str(hole[0]) == "axle":
				continue
			out.append([brick.transform * (hole[1] as Vector3),
				(brick.transform.basis * (hole[2] as Vector3)).normalized(), id])
	return out


## The pin's place along [param way] with its middle at [param middle], square
## to the grid; null for a line off it.
func _pin_at(way: Vector3, middle: Vector3) -> Variant:
	# The pin runs along its own x.
	for face: String in ["up", "down", "+x", "-x", "+z", "-z"]:
		for rot: int in 4:
			var basis: Basis = BrickLattice.basis_for(face, rot)
			if absf((basis * Vector3.RIGHT).dot(way)) > 0.99:
				var at := Transform3D(basis, middle)
				return at if _on_lattice(at.origin) else null
	return null


# -- weighing a fix ------------------------------------------------------------------


## The joint and the fix weighed as one (Balance's rule, M = Σ F·dᵢ), the
## worst of every way the load could come off: through the joint and each
## of the fix's own joints in turn. Times its working load.
func _held(weak: StressView.Weak, one: Dictionary, mass: Array) -> float:
	var parts: Array = one["parts"]
	var chain: Array = one["chain"]
	var joint: Array = _joint_contact(weak)
	var worst: float = INF
	for k: int in range(chain.size() - 1):
		var contact: Variant = _contact(chain[k], chain[k + 1], parts)
		if contact == null:
			return 0.0
		# What comes off this way: the side past the joint, and the fix's
		# parts past this link of it.
		var grams: float = mass[0]
		var moment: Vector3 = mass[1]
		for n: int in range(k + 1, chain.size() - 1):
			var item: Dictionary = parts[int(str(chain[n]).trim_prefix("#"))]
			var info: PartLibrary.PartInfo = library.parts.get(str(item["part"]))
			var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
			if info == null or part == null:
				continue
			var g: float = Stability.grams(info)
			grams += g
			moment += ((item["at"] as Transform3D) * part.bounds.get_center()) * g
		var contacts: Array = joint + [contact]
		worst = minf(worst, held_as_one(contacts, grams, moment / maxf(grams, 0.000001)))
	return worst


## The joint itself as a contact: its studs (Balance's bridge, from the two
## parts' boxes), standing or hanging; a piece on a touch, the touch it
## stands on, which bears and holds nothing up. [] for pins.
func _joint_contact(weak: StressView.Weak) -> Array:
	if weak.joint == null:
		var under: BrickWorld.Brick = world.get_brick(weak.around)
		if under == null:
			return []
		var touch: Variant = _contact(weak.around, weak.id, [])
		if touch == null:
			return []
		(touch as Dictionary)["hold"] = 0.0
		return [touch]
	if weak.joint.kind != "studs":
		return []
	var met: Variant = _contact(weak.joint.held_by, weak.joint.beyond, [])
	return [] if met == null else [met]


## The studs between [param holding], the side that holds in a fix's chain
## (a brick id, "#n" for the fix's nth part, or "floor"), and [param past],
## the side past the joint: {studs, corners, up: the side past it stands on
## the other, hold: N a stud}. Null when they do not meet.
func _contact(holding: Variant, past: Variant, parts: Array) -> Variant:
	if str(holding) == "floor":
		# The ground, which bears what stands on it and holds nothing down.
		var foot: Array = _boxes_of(past, parts)
		if foot.is_empty():
			return null
		var box: AABB = _span_of(foot[0])
		var y: float = box.position.y
		return {"studs": PackedVector3Array(), "hold": 0.0, "up": true,
			"corners": PackedVector3Array([Vector3(box.position.x, y, box.position.z),
				Vector3(box.end.x, y, box.position.z), Vector3(box.end.x, y, box.end.z),
				Vector3(box.position.x, y, box.end.z)])}
	var a: Array = _boxes_of(holding, parts)
	var b: Array = _boxes_of(past, parts)
	if a.is_empty() or b.is_empty():
		return null
	# The one with the studs is the lower.
	var a_low: bool = _span_of(a[0]).get_center().y < _span_of(b[0]).get_center().y
	var lower: PackedInt32Array = a[0] if a_low else b[0]
	var upper: PackedInt32Array = b[0] if a_low else a[0]
	var met: Array = Balance._overlap(lower, upper)
	var lo: Vector3i = met[0]
	var hi: Vector3i = met[1]
	if lo.x == 0x7FFFFFFF:
		return null
	var y: float = lo.y * BrickLattice.CELL
	var x_from: float = lo.x * BrickLattice.CELL
	var z_from: float = lo.z * BrickLattice.CELL
	var wide: float = (hi.x - lo.x) * BrickLattice.CELL
	var deep: float = (hi.z - lo.z) * BrickLattice.CELL
	var across: int = maxi(1, roundi(wide / BrickLattice.STUD))
	var along: int = maxi(1, roundi(deep / BrickLattice.STUD))
	var studs := PackedVector3Array()
	for i: int in across:
		for k: int in along:
			studs.append(Vector3(x_from + (i + 0.5) * wide / across, y,
				z_from + (k + 0.5) * deep / along))
	return {"studs": studs, "hold": Balance.ALLOWABLE_N, "up": a_low,
		"corners": PackedVector3Array([Vector3(x_from, y, z_from),
			Vector3(x_from + wide, y, z_from), Vector3(x_from + wide, y, z_from + deep),
			Vector3(x_from, y, z_from + deep)])}


## How many times over [param contacts] together hold [param grams] whose
## middle is [param carried], by the rigid-plastic bound Balance weighs one
## joint by: about each edge it could turn on, in each of eight ways and
## toward its middle, a stud holds F at its distance from that edge. A
## contact the side past the joint stands on bears whatever presses it, so
## the edge is past the last of them; one it hangs from bears what pushes up
## into it, so the edge is short of the first. INF: nothing levers it.
static func held_as_one(contacts: Array, grams: float, carried: Vector3) -> float:
	if contacts.is_empty():
		return 0.0
	var weight: float = grams / 1000.0 * Balance.GRAVITY
	var middle := Vector2.ZERO
	var count: int = 0
	for contact: Dictionary in contacts:
		for corner: Vector3 in contact["corners"]:
			middle += Vector2(corner.x, corner.z)
			count += 1
	middle /= maxf(count, 1)
	var ways: Array[Vector2] = []
	for n: int in 8:
		ways.append(Vector2.RIGHT.rotated(n * PI / 4.0))
	var toward := Vector2(carried.x, carried.z) - middle
	if toward.length() > 0.01:
		ways.append(toward.normalized())
	var worst: float = 0.0
	for way: Vector2 in ways:
		worst = maxf(worst, _ratio_along(contacts, weight, Vector2(carried.x, carried.z), way))
	return INF if worst <= 0.000001 else 1.0 / worst


## The worst ratio of moment to hold turning about an edge square to
## [param way], the far side going down.
static func _ratio_along(contacts: Array, weight: float, carried: Vector2, way: Vector2) -> float:
	var c: float = carried.dot(way)
	var lo: float = -INF
	var hi: float = INF
	var standing: int = 0
	var hanging: int = 0
	for contact: Dictionary in contacts:
		for corner: Vector3 in contact["corners"]:
			var s: float = Vector2(corner.x, corner.z).dot(way)
			if bool(contact["up"]):
				lo = maxf(lo, s)
			else:
				hi = minf(hi, s)
		if bool(contact["up"]):
			standing += 1
		else:
			hanging += 1
	if lo > hi + 0.001:
		# Borne both ways round: it cannot turn about any edge this way.
		return 0.0
	var edges: Array[float] = []
	if lo > -INF:
		edges.append(lo)
	if hi < INF:
		edges.append(hi)
	var worst: float = 0.0
	for t: float in edges:
		if t >= c:
			continue
		var hold: float = 0.0
		for contact: Dictionary in contacts:
			var f: float = float(contact["hold"])
			for stud: Vector3 in contact["studs"]:
				var s: float = Vector2(stud.x, stud.z).dot(way)
				hold += f * (t - s if bool(contact["up"]) else s - t)
		worst = maxf(worst, weight * (c - t) / maxf(hold, 0.000001))
	if standing == 0:
		# Pulled straight off.
		var pulled: float = 0.0
		for contact: Dictionary in contacts:
			pulled += float(contact["hold"]) * (contact["studs"] as PackedVector3Array).size()
		worst = maxf(worst, weight / maxf(pulled, 0.000001))
	return worst


## The side past the joint's weight and the moment of it: [grams, Σ g·middle].
func _mass_of(side: Dictionary) -> Array:
	var grams: float = 0.0
	var moment := Vector3.ZERO
	for id: int in side:
		var brick: BrickWorld.Brick = world.get_brick(id)
		if brick == null:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if info == null or part == null:
			continue
		var g: float = Stability.grams(info)
		grams += g
		moment += (brick.transform * part.bounds.get_center()) * g
	return [grams, moment]


## The model weighed as View, Stress weighs it with [param parts] in it
## (Balance.measure): on a worker for a big model, on copies.
func _weigh_with(parts: Array) -> Balance.Report:
	var bricks: Array = world.bricks()
	var spare: int = SPARE_FROM
	for item: Variant in bricks:
		spare = maxi(spare, (item as BrickWorld.Brick).id + 1)
	var added: Array = []
	for item: Dictionary in parts:
		var twin := BrickWorld.Brick.new(spare + added.size(), str(item["part"]),
			int(item.get("color", 71)), item["at"])
		added.append(twin)
	var weigher := Balance.new()
	weigher.library = library
	weigher.floor_ids = scenery.duplicate()
	if world.brick_count() < Stability.ON_A_WORKER_FROM or OS.has_feature("nothreads"):
		weigher.lattice = builder.lattice
		for twin: BrickWorld.Brick in added:
			builder.lattice.occupy_boxes(twin.id, builder.boxes_for(
				library.mesh_for(twin.part_id), twin.transform))
		var weighed: Balance.Report = weigher.measure(bricks + added)
		for twin: BrickWorld.Brick in added:
			builder.lattice.release(twin.id)
		return weighed
	var lattice: BrickLattice = builder.lattice.copy_for_reading()
	for twin: BrickWorld.Brick in added:
		lattice.occupy_boxes(twin.id, builder.boxes_for(library.mesh_for(twin.part_id),
			twin.transform))
	weigher.lattice = lattice
	var still: BrickWorld = world.copy_for_reading()
	var weighed: Variant = await WorkerTasks.awaited(func() -> Variant:
		return weigher.measure(still.bricks() + added), "weigh a fix", library)
	still.free()
	return weighed


## Whether [param after] has [param weak]'s joint above its working load
## (no longer the one thing holding what is past it, or holding it twice
## over), and fewer joints past their own than [param reds] before.
func _holds(after: Balance.Report, weak: StressView.Weak, reds: int) -> bool:
	var margins: Dictionary = {}
	for one: Balance.JointLoad in after.joints:
		margins[one.beyond] = one
	if weak.joint != null:
		var now: Balance.JointLoad = margins.get(weak.joint.beyond)
		if now != null and now.held_by == weak.joint.held_by \
				and 1.0 / maxf(now.ratio, 0.000001) < StressView.CLOSE:
			return false
	else:
		for piece: Dictionary in after.tipping:
			if (piece["ids"] as Array).has(weak.id):
				return false
	var was_red: bool = weak.margin < StressView.WEAK
	return _past(margins, after.tipping) <= reds - (1 if was_red else 0)


## How many joints of [param margins] are past their working load, and
## pieces of [param tipping] fall, as View, Stress counts them.
func _past(margins: Dictionary, tipping: Array) -> int:
	var count: int = 0
	for id: Variant in margins:
		if not scenery.has(int(id)) and (margins[id] as Balance.JointLoad).ratio > 1.0:
			count += 1
	return count + tipping.size()


## Whether every part of [param parts] has room, each against the model and
## those before it (Builder.room_for, as Edit, Pattern asks of its copies).
func _room(parts: Array) -> bool:
	var standing: Array[int] = []
	var number: int = -1
	var fits: bool = true
	for item: Dictionary in parts:
		var at: Transform3D = item["at"]
		if not builder.room_for(str(item["part"]), at, true):
			fits = false
			break
		builder.lattice.occupy_boxes(number, builder.boxes_for(
			library.mesh_for(str(item["part"])), at))
		standing.append(number)
		number -= 1
	for id: int in standing:
		builder.lattice.release(id)
	return fits


# -- colour, and what the person owns -----------------------------------------------


## Each part's colour, as a builder picks it: a tie and a prop the colour
## of the part past the joint they hold, a filler that of the part it stands
## on, a pin black. With [member owned], a colour they own with one to spare;
## [param one]'s "mine" says whether every part is theirs. Sets its "what".
## False when a part has no colour at all.
func _colour(one: Dictionary) -> bool:
	var joined: Array = one["joined"]
	var high: BrickWorld.Brick = world.get_brick(int(joined[0]))
	var low: BrickWorld.Brick = world.get_brick(int(joined[1])) if int(joined[1]) > 0 else null
	var mine: bool = true
	var left: Dictionary = _left()
	for item: Dictionary in one["parts"]:
		var wanted: int = int(item.get("color", -1))
		if wanted < 0:
			var by: BrickWorld.Brick = low if str(item["role"]) == "filler" and low != null else high
			wanted = by.color_code if by != null else 71
		var code: int = wanted
		if not owned.is_empty():
			code = _owned_colour(str(item["part"]), wanted, left)
			if code < 0:
				code = wanted
				mine = false
			else:
				var key: String = Collection.key_of(str(item["part"]), code, library)
				left[key] = int(left.get(key, 0)) - 1
		item["color"] = code
	one["mine"] = mine and not owned.is_empty()
	one["what"] = _what(one)
	return true


## What the person has of each part left to use: owned less what the model
## already uses, "part/colour" -> count.
func _left() -> Dictionary:
	var left: Dictionary = owned.duplicate()
	if left.is_empty():
		return left
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if scenery.has(brick.id):
			continue
		var key: String = Collection.key_of(brick.part_id, brick.color_code, library)
		if left.has(key):
			left[key] = int(left[key]) - 1
	return left


## [param wanted] when the person has one of [param part_id] left in it, or
## the colour they have most of it left in; -1 for none.
func _owned_colour(part_id: String, wanted: int, left: Dictionary) -> int:
	if int(left.get(Collection.key_of(part_id, wanted, library), 0)) > 0:
		return wanted
	var best: int = -1
	var most: int = 0
	for key: Variant in left:
		if Collection.part_of(str(key)) == library.resolve(part_id) and int(left[key]) > most:
			most = int(left[key])
			best = Collection.colour_of(str(key))
	return best


## The fix in words, each way of it one sentence the language tables have
## whole (Language): "a Plate 1 x 4 across the seam, onto the Brick 1 x 4
## beside it", "a Brick 1 x 1 x 5 under it, down to the baseplate".
func _what(one: Dictionary) -> String:
	var parts: Array = one["parts"]
	var joined: Array = one["joined"]
	match str(one["kind"]):
		"pin":
			return "a %s through the next two holes in line" % _named(PIN)
		"prop":
			var names: Array = parts.map(func(item: Dictionary) -> String:
				return _named(str(item["part"])))
			names.reverse()
			var on: int = int(one.get("standing", 0))
			var down_to: String = "the ground" if on == 0 and scenery.is_empty() \
				else ("the baseplate" if on == 0 or scenery.has(on) else "the %s under it")
			var listed: String = ["a %s", "a %s and a %s", "a %s, a %s and a %s"][names.size() - 1]
			var words: String = "%s under it, down to %s" % [listed, down_to]
			if down_to.contains("%s"):
				names.append(_brick_name(on))
			return words % names
	var tie: String = _named(str(one["tie"]))
	var other: String = _brick_name(int(joined[1]))
	var fillers: Array = parts.filter(func(item: Dictionary) -> bool:
		return str(item["role"]) == "filler").map(func(item: Dictionary) -> String:
			return _named(str(item["part"])))
	if str(one["how"]) == "under":
		return "a %s under the seam, into the %s beside it" % [tie, other]
	var words: String = "a %s over the seam, onto the %s beside it" if str(one["how"]) == "over" \
		else "a %s across the seam, onto the %s beside it"
	words += ["", ", on a %s", ", on a %s and a %s"][fillers.size()]
	return words % ([tie, other] + fillers)


func _named(part_id: String) -> String:
	return StressView._named(library, library.resolve(part_id))


func _brick_name(id: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(id)
	return _named(brick.part_id) if brick != null else "part"


# -- geometry ---------------------------------------------------------------------


## Where [param part_id] goes with its footprint's first stud at
## [param start] ([param start].y the face it stands on), [param across] by
## [param deep] studs: turned a quarter when its own footprint runs the other
## way. Null when that is off the lattice or the part has no such footprint.
func _laid(part_id: String, start: Vector3, across: int, deep: int) -> Variant:
	var size: Vector2i = _footprint(part_id)
	if size == Vector2i.ZERO:
		return null
	var basis := Basis.IDENTITY
	if size != Vector2i(across, deep):
		if size != Vector2i(deep, across):
			return null
		basis = BrickLattice.basis_for("up", 1)
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	var span: Vector2 = _cover_span(part)
	var middle := Vector3(start.x - 10.0 + across * 10.0, 0.0, start.z - 10.0 + deep * 10.0)
	var own: Vector3 = basis * part.bounds.get_center()
	var origin := Vector3(middle.x - own.x, start.y - span.x, middle.z - own.z)
	var at := Transform3D(basis, origin)
	return at if _on_lattice(origin) else null


## [param part_id]'s footprint in studs as it lies unturned: x across, y
## deep; zero for a part with none.
func _footprint(part_id: String) -> Vector2i:
	var info: PartLibrary.PartInfo = library.parts.get(library.resolve(part_id))
	if info == null or library.mesh_for(part_id) == null:
		return Vector2i.ZERO
	return Vector2i(roundi(info.size.x / 20.0), roundi(info.size.z / 20.0))


## How tall [param part_id]'s body stands, LDU, studs left out.
func _height_of(part_id: String) -> float:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return 0.0
	var span: Vector2 = _cover_span(part)
	return span.y - span.x


## The bottom and top of a part's cover in its own frame, LDU: its body,
## which the studs stand on.
static func _cover_span(part: Lbm.PartMesh) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for box: AABB in part.boxes:
		lo = minf(lo, box.position.y * BrickLattice.CELL)
		hi = maxf(hi, box.end.y * BrickLattice.CELL)
	if lo == INF:
		return Vector2(part.bounds.position.y, part.bounds.end.y)
	return Vector2(lo, hi)


## The top of [param id]'s body where it stands, LDU.
func _cover_top(id: int) -> float:
	var packed: PackedInt32Array = builder.lattice.boxes_of(id)
	if packed.is_empty():
		return _box(id).end.y
	var top: int = -0x7FFFFFFF
	for n: int in range(0, packed.size(), 6):
		top = maxi(top, packed[n + 4])
	return top * BrickLattice.CELL


## Whether nothing stands on the stud at [param at] (or under the socket,
## [param up] false), but [param own] itself.
func _free(at: Vector3, up: bool, own: int) -> bool:
	var y0: int = int(floor(at.y / BrickLattice.CELL))
	var probe := PackedInt32Array([int(floor((at.x - 4.0) / BrickLattice.CELL)),
		y0 if up else y0 - 2, int(floor((at.z - 4.0) / BrickLattice.CELL)),
		int(ceil((at.x + 4.0) / BrickLattice.CELL)), y0 + 2 if up else y0,
		int(ceil((at.z + 4.0) / BrickLattice.CELL))])
	for id: int in builder.lattice.blockers_boxes(probe):
		if id != own:
			return false
	return true


## The top of the floor a prop stands on: the baseplate's, or the ground.
func _floor_top() -> float:
	var top: float = 0.0
	var found: bool = false
	for id: Variant in scenery:
		if world.get_brick(int(id)) != null:
			top = maxf(top, _cover_top(int(id))) if found else _cover_top(int(id))
			found = true
	return top


## [param id]'s boxes in the lattice, or the fix's [param parts]' nth for
## "#n": [PackedInt32Array], or [] for none.
func _boxes_of(id: Variant, parts: Array) -> Array:
	if str(id).begins_with("#"):
		var item: Dictionary = parts[int(str(id).trim_prefix("#"))]
		return [builder.boxes_for(library.mesh_for(str(item["part"])), item["at"])]
	var packed: PackedInt32Array = builder.lattice.boxes_of(int(id))
	return [] if packed.is_empty() else [packed]


## The lattice's cells round [param box], LDU, as one box.
static func _cells_of(box: AABB) -> PackedInt32Array:
	return PackedInt32Array([int(floor(box.position.x / BrickLattice.CELL)),
		int(floor(box.position.y / BrickLattice.CELL)), int(floor(box.position.z / BrickLattice.CELL)),
		int(ceil(box.end.x / BrickLattice.CELL)), int(ceil(box.end.y / BrickLattice.CELL)),
		int(ceil(box.end.z / BrickLattice.CELL))])


## The box round [param packed] (cells, six a box), LDU.
static func _span_of(packed: PackedInt32Array) -> AABB:
	var lo := Vector3i(packed[0], packed[1], packed[2])
	var hi := Vector3i(packed[3], packed[4], packed[5])
	for n: int in range(6, packed.size(), 6):
		lo = Vector3i(mini(lo.x, packed[n]), mini(lo.y, packed[n + 1]), mini(lo.z, packed[n + 2]))
		hi = Vector3i(maxi(hi.x, packed[n + 3]), maxi(hi.y, packed[n + 4]),
			maxi(hi.z, packed[n + 5]))
	return AABB(Vector3(lo) * BrickLattice.CELL, Vector3(hi - lo) * BrickLattice.CELL)


func _box(id: int) -> AABB:
	var brick: BrickWorld.Brick = world.get_brick(id)
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if part == null:
		return AABB()
	return (brick.transform * part.bounds).abs()


## Whether a stud of [param studs] ([position, id] each) is within
## [param reach] of [param at] across and along.
static func _within(at: Vector3, studs: Array, reach: float) -> bool:
	for one: Array in studs:
		var other: Vector3 = one[0]
		if absf(other.x - at.x) <= reach + 0.5 and absf(other.z - at.z) <= reach + 0.5:
			return true
	return false


static func _in_phase(a: Vector3, b: Vector3) -> bool:
	return absf(fposmod(a.x - b.x + 1.0, 20.0) - 1.0) < 1.01 \
		and absf(fposmod(a.z - b.z + 1.0, 20.0) - 1.0) < 1.01


static func _on_lattice(at: Vector3) -> bool:
	return is_equal_approx(fposmod(at.x, BrickLattice.CELL), 0.0) \
		and is_equal_approx(fposmod(at.y, BrickLattice.CELL), 0.0) \
		and is_equal_approx(fposmod(at.z, BrickLattice.CELL), 0.0)


static func _cell_key(at: Vector3) -> String:
	return "%d,%d,%d" % [roundi(at.x), roundi(at.y), roundi(at.z)]


static func _key_of(parts: Array) -> String:
	var keys := PackedStringArray()
	for item: Dictionary in parts:
		var at: Transform3D = item["at"]
		keys.append("%s@%s" % [item["part"], _cell_key(at.origin)])
	keys.sort()
	return ";".join(keys)


static func _reversed(items: Array) -> Array:
	var out: Array = items.duplicate()
	out.reverse()
	return out
