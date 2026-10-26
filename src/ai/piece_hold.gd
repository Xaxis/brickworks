## Where a real set's piece is held in the model it is laid into.
##
## A sub-model cut out of a real set is often held by the set around it: a
## roof by the walls under it, an opera house's shell by the deck its hinge
## bases sit on. Alone it comes apart (tools/snippets.py's `lays`), and
## place_technique answered "held from outside it, so hold it in your model
## or copy it": main2's Sydney session was shown 21012's own shell that way
## and built flat wedges (design281, 2026-10-26). The app knows where every
## free stud of the model is (OpenPoints) and which of the piece's parts
## hold each other, so it finds the hold itself: each part of the piece that
## no other part of it holds is a group of its own (a component), and a
## place holds the piece when every part fits and every component is held
## by the model. Places are tried by seating one of the piece's free
## hollows on one of the model's free studs, nearest where it was asked to
## go first.
class_name PieceHold
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## Places tried for one piece in one turn, nearest first, before giving up.
const TRIES := 500
## A hollow of the piece's own that one of its studs fills, in LDU.
const FILLED := 2.0

var assistant: Assistant
var read: OpenPoints
## Why the last search found nothing, for the answer.
var why: String = ""


func _init(of: Assistant, reading: OpenPoints = null) -> void:
	assistant = of
	read = reading if reading != null else OpenPoints.read(of)


## The piece's parts, laid as [param bricks] (placements as edit_model takes
## them), in groups that hold each other: a part joined to another by a stud,
## a pin or a clip is in its group. One group for a piece the index says
## lays whole alone ([param whole]: the whole check's verdict, which knows a
## door's hinge in its frame where one part asked at a time does not).
func components(bricks: Array, whole: bool = false) -> Array:
	if whole:
		return [range(bricks.size())]
	var skip: Dictionary = {}
	for brick: BrickWorld.Brick in assistant.world.bricks():
		skip[brick.id] = true
	var also: Array = _also(bricks)
	var group: Array[int] = []
	for n: int in bricks.size():
		group.append(n)
	for n: int in bricks.size():
		var others: Array = also.filter(func(one: Array) -> bool: return int(one[0]) != -(n + 1))
		var trial: Dictionary = read.test(Assistant.Placement.from_dict(bricks[n]), skip, others)
		for by: Variant in trial["held_by"]:
			if int(by) < 0:
				_join(group, n, -int(by) - 1)
	var out: Dictionary = {}
	for n: int in bricks.size():
		var root: int = _root(group, n)
		if not out.has(root):
			out[root] = []
		(out[root] as Array).append(n)
	return out.values()


static func _root(group: Array[int], n: int) -> int:
	while group[n] != n:
		group[n] = group[group[n]]
		n = group[n]
	return n


static func _join(group: Array[int], one: int, other: int) -> void:
	var a: int = _root(group, one)
	var b: int = _root(group, other)
	if a != b:
		group[maxi(a, b)] = mini(a, b)


func _also(bricks: Array) -> Array:
	var out: Array = []
	for n: int in bricks.size():
		var other: Assistant.Placement = Assistant.Placement.from_dict(bricks[n])
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(other.part)
		if mesh != null:
			out.append([-(n + 1), mesh, assistant._transform(other, mesh, null), other.part])
	return out


## The nearest place to [param corner] (the piece's low corner, in studs and
## plates) where the piece holds, turned each of [param turns] in order and
## laid with its studs to [param up]: {"bricks", "turn", "up", "corner",
## "held_by": the model's bricks that hold it, "parts", "groups"}, or {} with
## [member why] said. [param passed] are corners already tried and refused.
func find(entry: Dictionary, corner: Vector3, turns: Array, up: String = "up",
		passed: Dictionary = {}) -> Dictionary:
	why = ""
	var way: Vector3 = Assistant.FACES.get(up, Vector3.UP)
	var ids: Array = []
	for brick: BrickWorld.Brick in assistant.world.bricks():
		if not assistant.scenery.has(brick.id):
			ids.append(brick.id)
	var points: Array = read.points_of(ids)
	var free: Array = points.filter(func(point: OpenPoints.Point) -> bool:
		return point.kind == "stud" and point.by == 0 and point.section.is_empty() \
			and point.way.dot(way) > 0.99)
	# And the model's free hollows, for a piece that hangs under what holds
	# it: a fender under a car's deck, a canopy under a roof's edge.
	var under: Array = points.filter(func(point: OpenPoints.Point) -> bool:
		return point.kind == "anti-stud" and point.by == 0 and point.section.is_empty() \
			and point.way.dot(-way) > 0.99)
	var best: Dictionary = {}
	var best_far: float = INF
	for turn: Variant in turns:
		var base: Variant = await assistant._snippet_bricks(entry, Vector3.ZERO, int(turn), {}, up)
		if base is String:
			why = str(base)
			return {}
		var bricks: Array = base
		var groups: Array = components(bricks, bool(entry.get("lays", false)))
		var hollows: Array = _free_hollows(bricks, way)
		var studs: Array = _free_studs(bricks)
		var low: Vector3 = _low(bricks)
		# Each hollow on each free stud, as a move of the whole piece, nearest
		# where its low corner was asked to be first.
		var moves: Dictionary = {}
		# Where it was asked first: held there by the model, or standing on
		# the ground, it goes there.
		if not passed.has(str(corner)):
			moves[str(corner)] = [0.0, corner - low, corner]
		for pair: Array in [[free, hollows], [under, studs]]:
			for seat: OpenPoints.Point in pair[0]:
				for own: Vector3 in pair[1]:
					var by: Vector3 = seat.at - own
					var shift := Vector3(snappedf(by.x / STUD, 0.05), snappedf(by.y / PLATE, 0.25),
						snappedf(by.z / STUD, 0.05))
					var at: Vector3 = low + shift
					var key: String = str(at)
					if moves.has(key) or passed.has(key):
						continue
					moves[key] = [_far(at, corner), shift, at]
		var order: Array = moves.values()
		order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for row: Array in order.slice(0, TRIES):
			if float(row[0]) >= best_far:
				break
			var moved: Array = FeaturePass._shifted(bricks, row[1])
			var held: Array = holds(moved, groups)
			if held.is_empty():
				continue
			best_far = float(row[0])
			best = {"bricks": moved, "turn": int(turn), "up": up, "corner": row[2],
				"held_by": held, "parts": bricks.size(), "groups": groups.size(),
				"far": best_far}
			break
	if best.is_empty():
		why = ("the model has no free stud facing %s" % up if free.is_empty() and under.is_empty()
			else "no free stud or hollow of the model takes it without a part of it running "
				+ "into the model or left unheld")
	return best


## How far a corner is from the one asked, in LDU.
static func _far(at: Vector3, asked: Vector3) -> float:
	return Vector3((at.x - asked.x) * STUD, (at.y - asked.y) * PLATE,
		(at.z - asked.z) * STUD).length()


static func _low(bricks: Array) -> Vector3:
	return FeaturePass._low(bricks)


## The model's bricks that hold a piece laid as [param bricks], when every
## part of it fits and each of its [param groups] is held by the model or
## stands on the ground (0 for the ground); none otherwise.
func holds(bricks: Array, groups: Array) -> Array:
	var held_by: Dictionary = {}
	var group_of: Dictionary = {}
	for g: int in groups.size():
		for n: Variant in groups[g]:
			group_of[int(n)] = g
	var held: Dictionary = {}
	for n: int in bricks.size():
		var trial: Dictionary = read.test(Assistant.Placement.from_dict(bricks[n]))
		if not bool(trial["fits"]):
			return []
		for by: Variant in trial["held_by"]:
			if int(by) > 0:
				held[group_of.get(n, 0)] = true
				held_by[int(by)] = true
		if int(trial.get("rests_on", 0)) == -1:
			held[group_of.get(n, 0)] = true
			held_by[0] = true
	if held.size() < groups.size():
		return []
	return held_by.keys()


## The studs of a piece laid as [param bricks] that no part of it covers,
## in LDU: a piece seated by one of these into a free hollow of the model
## hangs under it.
func _free_studs(bricks: Array) -> Array:
	var all_hollows: Array = []
	var studs: Array = []
	for raw: Variant in bricks:
		var placement: Assistant.Placement = Assistant.Placement.from_dict(raw)
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(placement.part)
		if mesh == null:
			continue
		var at: Transform3D = assistant._transform(placement, mesh, null)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male":
				studs.append(at * connector.position)
		var bottom: float = mesh.bounds.position.y
		for socket: Vector2 in mesh.sockets:
			all_hollows.append(at * Vector3(socket.x, bottom, socket.y))
	var out: Array = []
	for stud: Vector3 in studs:
		var covered: bool = false
		for hollow: Vector3 in all_hollows:
			if hollow.distance_to(stud) <= FILLED:
				covered = true
				break
		if not covered:
			out.append(stud)
	return out


## The hollows under a piece laid as [param bricks] that none of its own
## studs fills, where under is against [param way], in LDU.
func _free_hollows(bricks: Array, way: Vector3) -> Array:
	var studs: Array = []
	var hollows: Array = []
	for raw: Variant in bricks:
		var placement: Assistant.Placement = Assistant.Placement.from_dict(raw)
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(placement.part)
		if mesh == null:
			continue
		var at: Transform3D = assistant._transform(placement, mesh, null)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male":
				studs.append(at * connector.position)
		if (at.basis * Vector3.DOWN).normalized().dot(-way) < 0.99:
			continue
		var bottom: float = mesh.bounds.position.y
		for socket: Vector2 in mesh.sockets:
			hollows.append(at * Vector3(socket.x, bottom, socket.y))
	var out: Array = []
	for hollow: Vector3 in hollows:
		var filled: bool = false
		for stud: Vector3 in studs:
			if stud.distance_to(hollow) <= FILLED:
				filled = true
				break
		if not filled:
			out.append(hollow)
	# The lowest first: most pieces sit on what is under them.
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.dot(way) < b.dot(way))
	return out
