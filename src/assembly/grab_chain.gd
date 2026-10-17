## A part taken hold of at the end of a chain of joints and moved to where
## the pointer is, every joint between it and the anchor turning as far as
## it may: a minifigure's hand drawn to a point and its arm following, a
## crane's hook and its boom and turntable. What the press held still for
## 0.4 s before the drag gets (GrabDrag); a plain drag turns the one joint.
##
## The joints are the ones Bodies grows from the anchor (Bodies.chain): each
## turns everything beyond it, so a part's place is each joint's turn about
## its line where it stood, innermost first and the outer ones carrying it,
## as Poser.transforms_for has it. Each joint's free range is read once when
## the drag begins, by turning it alone through the lattice (Grab.has_room)
## both ways to what stops it; the search for the turns that put the end
## under the pointer then uses only those ranges (cyclic coordinate descent:
## from the end inwards, each joint turned so the end comes nearest the
## target, a dozen rounds), which costs nothing a frame. Let go, the pose is
## tested properly, every part that moved against the rest of the model; if
## anything is in the way the turns are all eased back together to the
## furthest that has room. One step to undo.
class_name GrabChain
extends RefCounted

## At most this many joints back from the end.
const MOST := 6
## A joint's range is read in steps of this, degrees, then bisected.
const RANGE_STEP := 10.0
const ROUNDS := 12
## Close enough, LDU.
const NEAR := 0.5
## Further off than this after the search, LDU, it starts again elsewhere.
const RESTART_PAST := 2.0
const RESTARTS := 8

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var bodies: Bodies

var state: String = ""
var why: String = ""
## Nearest the anchor first: each joint's grab (its line, what it moves).
var joints: Array[Grab] = []
## Degrees each is turned from where it was, and what it may turn to.
var angles := PackedFloat64Array()
var ranges: Array[Vector2] = []
## Where the end was taken hold of, where it stood.
var hold := Vector3.ZERO
## Every part that moves: brick id -> where it stood, and where it stands now.
var rest: Dictionary = {}
var placed: Dictionary = {}
## The joint of each part: the innermost index whose turn moves it.
var _deepest: Dictionary = {}
var said: String = ""
var range_ms: float = 0.0


## Take hold of [param brick_id] at [param at] by the chain of joints back to
## its anchor. "moves" or "rigid" (no joint), with [member why].
func begin(brick_id: int, at: Vector3) -> String:
	hold = at
	if not bodies.body_of.has(brick_id):
		return _refuse("that part is not part of the model")
	var end: int = int(bodies.body_of[brick_id])
	var links: Array[Bodies.Link] = bodies.chain(end)
	var children: Array = []
	var at_body: int = end
	for link: Bodies.Link in links:
		children.append(at_body)
		at_body = int(bodies.parent_of[at_body])
	if links.is_empty():
		return _refuse("that part is held to what stays: there is no chain of joints back from it")
	# Nearest the anchor first, turning joints only (a ball or a slide
	# stays as it is).
	var started: int = Time.get_ticks_usec()
	for n: int in range(links.size() - 1, -1, -1):
		var link: Bodies.Link = links[n]
		if link.axis == Vector3.ZERO or joints.size() >= MOST:
			continue
		var grab := Grab.new()
		grab.world = world
		grab.builder = builder
		grab.library = library
		grab.bodies = bodies
		if grab.begin_link(link, int(children[n]), at) != "moves":
			continue
		joints.append(grab)
	if joints.is_empty():
		return _refuse("no joint back from it turns")
	angles.resize(joints.size())
	angles.fill(0.0)
	for n: int in joints.size():
		ranges.append(_range_of(joints[n]))
		for key: int in joints[n].moving:
			_deepest[key] = n
			if not rest.has(key):
				rest[key] = world.get_brick(key).transform
	range_ms = float(Time.get_ticks_usec() - started) / 1000.0
	placed = rest.duplicate()
	var anchor: int = int(bodies.parent_of[joints[0].body])
	said = "chain: %s along %d joint%s back to %s" % [bodies.named([end]), joints.size(),
		"" if joints.size() == 1 else "s", bodies.named([anchor]).get_slice(",", 0)]
	state = "moves"
	return state


func _refuse(words: String) -> String:
	state = "rigid"
	why = words
	return state


## How far [param joint] turns alone each way before what it carries meets
## the model, degrees: whole steps, then the last one halved a few times.
func _range_of(joint: Grab) -> Vector2:
	var out := Vector2(-180.0, 180.0)
	for way: int in [1, -1]:
		var free: float = 0.0
		var turned: float = RANGE_STEP
		while turned <= 180.0:
			if not joint.has_room(joint.transforms_at(way * turned)):
				var low: float = free
				var high: float = turned
				for _round: int in 4:
					var middle: float = (low + high) * 0.5
					if joint.has_room(joint.transforms_at(way * middle)):
						low = middle
					else:
						high = middle
				free = low
				break
			free = turned
			turned += RANGE_STEP
		if way > 0:
			out.y = free
		else:
			out.x = -free
	return out


# -- where everything stands -----------------------------------------------------


## Each joint's turn about its line where it stood, as a transform of the
## model: the outer ones carrying the inner.
func _turns() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var carried := Transform3D.IDENTITY
	for n: int in joints.size():
		var joint: Grab = joints[n]
		var turn: Transform3D = Transform3D(Basis.IDENTITY, joint.pivot) \
			* Transform3D(Basis(joint.axis, deg_to_rad(angles[n])), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -joint.pivot)
		carried = carried * turn
		out.append(carried)
	return out


## Where every part that moves stands at [member angles].
func transforms() -> Dictionary:
	var turns: Array[Transform3D] = _turns()
	var out: Dictionary = {}
	for key: int in rest:
		out[key] = turns[int(_deepest[key])] * (rest[key] as Transform3D)
	return out


## Where the held point is now.
func end_point() -> Vector3:
	var turns: Array[Transform3D] = _turns()
	return turns[joints.size() - 1] * hold


## Turn the joints so the held point comes as near the pointer's ray
## (from [param origin] along [param direction]) as their ranges let it: at
## each joint, towards the ray's point nearest the end, so a chain whose
## reach is a surface finds where on it the pointer is, not a point at a
## depth the pointer never said. Returns how far off the ray it is, LDU.
func reach_ray(origin: Vector3, direction: Vector3) -> float:
	var off: float = _descend(origin, direction)
	if off < RESTART_PAST:
		return off
	# Stuck short of it where the reach curves away (a hand on its wrist and
	# shoulder): started again from a few other turns within the ranges, the
	# nearest kept.
	var best := PackedFloat64Array(angles)
	var best_off: float = off
	var dice := RandomNumberGenerator.new()
	dice.seed = 17
	for _try: int in RESTARTS:
		for n: int in angles.size():
			angles[n] = dice.randf_range(ranges[n].x, ranges[n].y)
		var tried: float = _descend(origin, direction)
		if tried < best_off - 0.01:
			best_off = tried
			best = PackedFloat64Array(angles)
		if best_off < NEAR:
			break
	angles = best
	placed = transforms()
	return best_off


func _descend(origin: Vector3, direction: Vector3) -> float:
	var way: Vector3 = direction.normalized()
	var off := func(point: Vector3) -> Vector3:
		return origin + way * maxf((point - origin).dot(way), 0.0)
	for _round: int in ROUNDS:
		var end_now: Vector3 = end_point()
		if end_now.distance_to(off.call(end_now)) < NEAR:
			break
		for n: int in range(joints.size() - 1, -1, -1):
			var turns: Array[Transform3D] = _turns()
			var outer: Transform3D = turns[n - 1] if n > 0 else Transform3D.IDENTITY
			var pivot: Vector3 = outer * joints[n].pivot
			var axis: Vector3 = (outer.basis * joints[n].axis).normalized()
			var end: Vector3 = turns[joints.size() - 1] * hold
			var target: Vector3 = off.call(end)
			var from: Vector3 = end - pivot
			var to: Vector3 = target - pivot
			from -= axis * from.dot(axis)
			to -= axis * to.dot(axis)
			if from.length() < 0.5 or to.length() < 0.5:
				continue
			var turn: float = rad_to_deg(atan2(axis.dot(from.cross(to)), from.dot(to)))
			angles[n] = clampf(angles[n] + turn, ranges[n].x, ranges[n].y)
	placed = transforms()
	var end_then: Vector3 = end_point()
	return end_then.distance_to(off.call(end_then))


## Turn the joints so the held point comes as near [param target] as their
## ranges let it. Returns how far off it is, LDU.
func reach(target: Vector3) -> float:
	for _round: int in ROUNDS:
		if end_point().distance_to(target) < NEAR:
			break
		for n: int in range(joints.size() - 1, -1, -1):
			var turns: Array[Transform3D] = _turns()
			var outer: Transform3D = turns[n - 1] if n > 0 else Transform3D.IDENTITY
			var pivot: Vector3 = outer * joints[n].pivot
			var axis: Vector3 = (outer.basis * joints[n].axis).normalized()
			var end: Vector3 = turns[joints.size() - 1] * hold
			var from: Vector3 = end - pivot
			var to: Vector3 = target - pivot
			from -= axis * from.dot(axis)
			to -= axis * to.dot(axis)
			if from.length() < 0.5 or to.length() < 0.5:
				continue
			var turn: float = rad_to_deg(atan2(axis.dot(from.cross(to)), from.dot(to)))
			angles[n] = clampf(angles[n] + turn, ranges[n].x, ranges[n].y)
	placed = transforms()
	return end_point().distance_to(target)


# -- letting go ----------------------------------------------------------------------


## Test the pose properly and keep as much of it as has room, as one step.
## Returns words.
func finish() -> String:
	var outer: Grab = joints[0]
	var want := PackedFloat64Array(angles)
	var free: bool = outer.has_room(transforms())
	var eased: float = 1.0
	if not free:
		var low: float = 0.0
		var high: float = 1.0
		for _round: int in 8:
			var middle: float = (low + high) * 0.5
			for n: int in angles.size():
				angles[n] = want[n] * middle
			if outer.has_room(transforms()):
				low = middle
			else:
				high = middle
		eased = low
		for n: int in angles.size():
			angles[n] = want[n] * low
	placed = transforms()
	outer.placed = placed
	for key: int in rest:
		outer.rest[key] = rest[key]
	var turned := PackedStringArray()
	for n: int in joints.size():
		turned.append("%d°" % roundi(angles[n]))
	var moved: int = outer.commit("moved %s along its chain (%s)" % [said.trim_prefix("chain: "),
		", ".join(turned)])
	if moved == 0:
		return "not moved: the chain has no room from where it stood"
	return "%s, the joints at %s%s" % [said.substr(0, 1).to_upper() + said.substr(1),
		", ".join(turned), "" if free else
		"; eased back to %d%% of the way, where it has room" % roundi(eased * 100.0)]
