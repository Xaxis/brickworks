## A section of the model taken in hand and moved about its joint as the real
## thing moves: a wing on its hinge, a boom on its turntable, an arm on its
## shoulder with the hand and what it holds, a gear and the train it drives.
##
## The owner (2026-10-17): a person "should be able to manipulate and move any
## hinging, moving, otherwise interactive part with perfect physics/support/
## structure simulation". What moves is read by [Bodies]: the grabbed part's
## rigid body and everything beyond it, turned on the one joint between it
## and the anchor (what stays: a locked part, the baseplate, else the
## heaviest body). Grabbing a joint's anchored half moves its other half.
##
## How it moves is the joint's:
##   turn   a hinge, a clip, a turntable, a pin or an axle, a round stud:
##          about its line; a click hinge stops on its clicks.
##   slide  a clip on a bar, a hole on an axle or a pin: along its line, as
##          far as the shaft reaches.
##   ball   about its middle, every way.
## Where it stops is the parts' own: the lattice says whether anything but
## what it is joined to is in the way, and the angle is bisected back to the
## last one with room ([method turn_to]), as Poser.settle does. Nothing is
## made up: a hinge with room to go all the way round does.
##
## Gears turn their train: a grabbed gear's body drives [Mechanism], and
## every gear it meshes turns by the tooth counts, as Simulate turns them.
## A closed loop (a four-bar, a crank and its rod) is held at both ends:
## phase P2 of docs/MECHANISMS.md, said rather than moved.
##
## Let go, a joint that holds by friction stays where it was put; one that
## does not (a pin without friction ridges, an axle in a round hole, a
## turntable on its side) swings down under its own weight to where its
## centre of mass is lowest, or to what stops it ([method settle]). The
## pose is one step to undo ([method commit]).
##
## Pure but for the lattice it asks: it changes nothing until [method
## commit], and the caller draws [member placed] (BrickWorld.set_drawn).
class_name Grab
extends RefCounted

## Bisection rounds for where a turn stops: 180° / 2^10 is under 0.2°.
const ROUNDS := 10
## A part may sink this far below the floor the model stands on, LDU, as
## Balance lets a pose: half a plate.
const BELOW_FLOOR := 4.0
## A drag along a joint's line this much more than across it slides.
const SLIDE_BIAS := 1.6
## Degrees a pixel when the joint's plane is edge on to the eye.
const EDGE_ON_RATE := 0.5

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var bodies: Bodies

## What can be grabbed: "moves", "rigid" (nothing to turn on: carried as
## before), "loop" (held at both ends), "locked" (a geared train that
## locks). [member why] says it in words.
var state: String = ""
var why: String = ""
var part: int = 0
var body: int = 0
var link: Bodies.Link
var moving_bodies: Array = []
## Brick id -> true for every part that moves with it.
var moving: Dictionary = {}
## Brick id -> Transform3D where each stood when grabbed.
var rest: Dictionary = {}
## What the moving side may press against: across its joint.
var skip: Dictionary = {}
## turn, slide or ball.
var mode: String = ""
var pivot := Vector3.ZERO
var axis := Vector3.ZERO
## Degrees about [member axis] from where it was grabbed.
var angle: float = 0.0
## LDU along it.
var shift: float = 0.0
## A ball's turn from where it was grabbed.
var twist := Basis.IDENTITY
## Where everything that moves stands now: brick id -> Transform3D.
var placed: Dictionary = {}
## Gears the grabbed one turns, and what they turn on: brick id -> true.
var coupled: Dictionary = {}
var mechanism: Mechanism
## The model's gear trains read ahead (GrabDrag), the anchors their ground;
## read here for the piece grabbed when not.
var shared_mechanism: Mechanism = null
var _driver: int = -1
var _drive_sign: float = 1.0
## What moves, said: "the boom, 38 parts, on its turntable".
var said: String = ""
## Where it stopped short of where it was asked, degrees or LDU, and how
## often in this drag.
var stopped: bool = false
## Grams of what moves, and its centre of mass where it was grabbed.
var grams: float = 0.0
var _centre := Vector3.ZERO
var _floor_y: float = 0.0
var _range := Vector2.ZERO
## Where the pointer took hold, and the pointer's first way of moving.
var _hold := Vector3.ZERO
var _hold_screen := Vector2.ZERO
var _last_raw: float = 0.0
var _unwrapped: float = 0.0
var _decided: bool = false
## Where the last stop was met, degrees; NAN for none.
var _wall: float = NAN
## How long the last test for room took, ms, and how many tests a drag ran.
var test_ms: float = 0.0
var tests: int = 0


## Read what [param brick_id] would move, from where the pointer [param at]
## took hold of it. [param selection] (brick id -> true), when it holds the
## part and more, is moved as one about what joins it to the rest.
func begin(brick_id: int, at: Vector3, selection: Dictionary = {}) -> String:
	part = brick_id
	_hold = at
	if bodies == null or bodies.revision != world.revision:
		bodies = Bodies.read(world, library, builder.lattice, bodies.scenery if bodies != null else {},
			builder.locked)
	if not bodies.body_of.has(brick_id):
		return _refuse("rigid", "that part is not part of the model")
	if selection.size() > 1 and selection.has(brick_id):
		_from_selection(selection)
	else:
		_from_part(brick_id)
	if state != "moves":
		return state
	moving.clear()
	for key: int in bodies.parts_of(moving_bodies):
		moving[key] = true
	var ours: Dictionary = {}
	for one: int in moving_bodies:
		ours[one] = true
	var held: Array[Bodies.Link] = bodies.loops_out(ours, link)
	if not held.is_empty():
		var other: Bodies.Link = held[0]
		return _refuse("loop", ("%s is held at both ends: %s and %s (a closed loop). "
			+ "Moving a loop is not built yet (docs/MECHANISMS.md, phase P2).") % [
			bodies.named(moving_bodies), link.words().trim_prefix("on "),
			other.words().trim_prefix("on ")])
	skip = moving.duplicate()
	for one: int in moving_bodies:
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if ours.has(joined.other(one)):
				continue
			for pair: Array in joined.pairs:
				for key: int in pair:
					skip[key] = true
	# What it already overlaps where it stands is not in its way: covers are
	# 2 LDU cells, and a minifigure's hand sits closer to its leg than that.
	for key: int in moving:
		var boxes: PackedInt32Array = builder.lattice.boxes_of(key)
		if boxes.is_empty():
			continue
		for other: int in builder.lattice.blockers_boxes(boxes, 0, skip):
			skip[other] = true
	rest.clear()
	grams = 0.0
	var weighted := Vector3.ZERO
	_floor_y = INF
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		_floor_y = minf(_floor_y, (brick.transform * info.bounds).position.y)
		if moving.has(brick.id):
			rest[brick.id] = brick.transform
			var g: float = Stability.grams(info)
			grams += g
			weighted += (brick.transform * info.bounds.get_center()) * g
	_centre = weighted / maxf(grams, 0.000001)
	pivot = link.point
	axis = link.axis.normalized()
	mode = "ball" if axis == Vector3.ZERO else "turn"
	var shaft_moves: bool = moving.has(link.shaft_part)
	_range = Vector2(-link.slide.y, link.slide.x) if shaft_moves else Vector2(-link.slide.x, link.slide.y)
	_gears()
	placed = rest.duplicate()
	said = "%s %s" % [bodies.named(moving_bodies), link.words()]
	return state


func _refuse(kind: String, words: String) -> String:
	state = kind
	why = words
	return state


## The part's body and all beyond it, on the joint towards the anchor; or,
## for a joint's anchored half, the half across it.
func _from_part(brick_id: int) -> void:
	body = int(bodies.body_of[brick_id])
	if bodies.anchors.has(body) or not bodies.parent_link.has(body):
		# The anchored half of a joint moves the half across it.
		for joined: Bodies.Link in bodies.touching.get(body, []):
			var across: int = joined.other(body)
			if bodies.parent_link.get(across) != joined:
				continue
			for pair: Array in joined.pairs:
				if int(pair[0]) == brick_id or int(pair[1]) == brick_id:
					body = across
					link = joined
					moving_bodies = bodies.beyond(across)
					state = "moves"
					return
		_refuse("rigid", "that part is held rigidly to what it stands on")
		return
	link = bodies.parent_link[body]
	moving_bodies = bodies.beyond(body)
	state = "moves"


## A selection moved as one: whole bodies only, about the one joint (or the
## joints on one line) between it and the rest.
func _from_selection(selection: Dictionary) -> void:
	var ours: Dictionary = {}
	for key: Variant in selection:
		if bodies.body_of.has(int(key)):
			ours[int(bodies.body_of[int(key)])] = true
	for one: int in ours:
		for key: int in bodies.members[one]:
			if not selection.has(key):
				_refuse("rigid", ("the selection is held to the rest by studs: it would have to be "
					+ "pulled off them. Drag it with nothing selected to turn it on its joint, or "
					+ "move it off as a whole with the Move tool."))
				return
	var crossing: Array[Bodies.Link] = []
	for one: int in ours:
		for joined: Bodies.Link in bodies.touching.get(one, []):
			if not ours.has(joined.other(one)) and not crossing.has(joined):
				crossing.append(joined)
	if crossing.is_empty():
		_refuse("rigid", "the selection is joined to nothing that turns")
		return
	link = crossing[0]
	body = link.a if ours.has(link.a) else link.b
	moving_bodies = ours.keys()
	state = "moves"


## A gear in what moves drives its train, as Simulate drives it.
func _gears() -> void:
	coupled.clear()
	mechanism = null
	_driver = -1
	var any: bool = false
	for key: int in moving:
		if not Mechanism.spec_of(world.get_brick(key).part_id).is_empty():
			any = true
			break
	if not any or mode != "turn":
		return
	if shared_mechanism != null:
		mechanism = shared_mechanism
	else:
		var list: Array = []
		var held: Array = []
		var piece: Dictionary = _piece_of(body)
		for key: int in piece:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh == null:
				continue
			list.append({"key": key, "part": brick.part_id, "at": brick.transform, "mesh": mesh})
			if bodies.anchors.has(int(bodies.body_of[key])):
				held.append(key)
		mechanism = Mechanism.build(list, held)
	# The driver is what the gear that moves turns on, on the grabbed joint's
	# line: the part pressed may be a sail pinned to it, which Mechanism
	# reads as a body of its own.
	var driven: int = -1
	var joint: Mechanism.Joint = null
	for key: int in [part] + moving.keys():
		var body_here: int = mechanism.body_of(key)
		var turning_on: Mechanism.Joint = mechanism.joint_of(body_here)
		if turning_on != null and Bodies._same_line(turning_on.point, turning_on.way, pivot, axis) \
				and (key == part or not Mechanism.spec_of(world.get_brick(key).part_id).is_empty()):
			driven = body_here
			joint = turning_on
			break
	if joint == null:
		mechanism = null
		return
	var solved: Dictionary = mechanism.solve({driven: 1.0})
	if not bool(solved["ok"]):
		if bool(solved["locked"]):
			_refuse("locked", "%s will not turn: its gears lock (%s)." % [bodies.named(moving_bodies),
				", ".join(PackedStringArray(solved["culprits"]))])
		mechanism = null
		return
	_driver = driven
	_drive_sign = 1.0 if joint.way.dot(axis) > 0.0 else -1.0
	var turned: Dictionary = mechanism.pose(0.7)
	for key: int in turned:
		if moving.has(key) or not mechanism.rest.has(key):
			continue
		if not Grab._same(turned[key], mechanism.rest[key]):
			coupled[key] = true
			skip[key] = true
			rest[key] = mechanism.rest[key]


## Every part in the piece of the model [param from] is in.
func _piece_of(from: int) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {from: true}
	var frontier: Array = [from]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for key: int in bodies.members[at]:
			out[key] = true
		for joined: Bodies.Link in bodies.touching.get(at, []):
			var next: int = joined.other(at)
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return out


static func _same(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and a.basis.x.distance_to(b.basis.x) < 1e-5 \
		and a.basis.y.distance_to(b.basis.y) < 1e-5 and a.basis.z.distance_to(b.basis.z) < 1e-5


# -- where it stands ------------------------------------------------------------


## Where every part that moves stands with the joint at [param degrees]
## (turn), [param along] (slide) or [param turned] (ball).
func transforms_at(degrees: float, along: float = 0.0, turned: Basis = Basis.IDENTITY) -> Dictionary:
	var move := Transform3D.IDENTITY
	if mode == "ball":
		move = Transform3D(Basis.IDENTITY, pivot) * Transform3D(turned, Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -pivot)
	else:
		move = Transform3D(Basis.IDENTITY, pivot) \
			* Transform3D(Basis(axis, deg_to_rad(degrees)), axis * along) \
			* Transform3D(Basis.IDENTITY, -pivot)
	var out: Dictionary = {}
	for key: int in moving:
		# Not squared up: a file's own six-decimal turns would read as moved.
		out[key] = move * (rest[key] as Transform3D)
	if mechanism != null and not coupled.is_empty():
		var driven: Dictionary = mechanism.pose_of(deg_to_rad(degrees) * _drive_sign, coupled)
		for key: int in coupled:
			out[key] = driven[key]
	return out


## Whether every part that moves has room at [param at]: nothing in the
## way but what it is joined to, and nothing through the floor.
func has_room(at: Dictionary) -> bool:
	var started: int = Time.get_ticks_usec()
	tests += 1
	var free: bool = true
	for key: int in moving:
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var to: Transform3D = at[key]
		var box: AABB = to * mesh.bounds
		if box.position.y < _floor_y - BELOW_FLOOR and mesh.lowest_at(to) < _floor_y - BELOW_FLOOR:
			free = false
			break
		# Its box first: nothing but what it may press on anywhere near it,
		# and its turned cover is not worked out at all. A sail turning in
		# the air cost a windmill's drag 38 ms a frame that way.
		if not _near_anything(box):
			continue
		var packed: PackedInt32Array = builder.boxes_for(mesh, to)
		if not builder.lattice.blockers_boxes(packed, 0, skip).is_empty():
			free = false
			break
	test_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return free


## Whether anything but what the moving side may press on has its bounds
## within [param box].
func _near_anything(box: AABB) -> bool:
	var cell: float = BrickLattice.CELL
	var bound := PackedInt32Array([floori(box.position.x / cell), floori(box.position.y / cell),
		floori(box.position.z / cell), ceili(box.end.x / cell), ceili(box.end.y / cell),
		ceili(box.end.z / cell)])
	for other: int in builder.lattice.near_bounds(bound):
		if not skip.has(other):
			return true
	return false


## Turn to [param degrees] from where it was grabbed, as far as it has room
## for from where it is: a click hinge on its clicks. Returns the angle.
func turn_to(degrees: float) -> float:
	if state != "moves" or mode != "turn":
		return angle
	var wanted: float = degrees
	if link.detent > 0.0:
		wanted = roundf(wanted / link.detent) * link.detent
	if is_equal_approx(wanted, angle):
		return angle
	# Past the wall it met last, the same way: still there, and not asked
	# again, so a pointer pressed on past a stop costs nothing a frame.
	if not is_nan(_wall) and (wanted - _wall) * (_wall - angle) >= 0.0 \
			and absf(_wall - angle) < absf(wanted - angle) + 0.001:
		stopped = true
		return angle
	_wall = NAN
	var at: Dictionary = transforms_at(wanted)
	if has_room(at):
		angle = wanted
		placed = at
		stopped = false
		return angle
	var low: float = angle
	var high: float = wanted
	for _round: int in ROUNDS:
		var middle: float = (low + high) * 0.5
		if has_room(transforms_at(middle)):
			low = middle
		else:
			high = middle
	if link.detent > 0.0:
		# The last click short of what is in the way.
		var clicks: float = (low - angle) / link.detent
		low = angle + (floorf(clicks) if clicks >= 0.0 else ceilf(clicks)) * link.detent
	_wall = high
	angle = low
	placed = transforms_at(angle)
	stopped = true
	return angle


## Slide [param along] LDU from where it was grabbed, along the shaft as far
## as it reaches and there is room.
func slide_to(along: float) -> float:
	if state != "moves" or mode != "slide":
		return shift
	var wanted: float = clampf(along, _range.x, _range.y)
	stopped = not is_equal_approx(wanted, along)
	var at: Dictionary = transforms_at(angle, wanted)
	if has_room(at):
		shift = wanted
		placed = at
		return shift
	var low: float = shift
	var high: float = wanted
	for _round: int in ROUNDS:
		var middle: float = (low + high) * 0.5
		if has_room(transforms_at(angle, middle)):
			low = middle
		else:
			high = middle
	shift = low
	placed = transforms_at(angle, shift)
	stopped = true
	return shift


## Turn a ball to [param turned] from where it was grabbed, as far towards
## it as it has room for.
func ball_to(turned: Basis) -> Basis:
	if state != "moves" or mode != "ball":
		return twist
	var from := Quaternion(twist.orthonormalized())
	var to := Quaternion(turned.orthonormalized())
	if has_room(transforms_at(0.0, 0.0, Basis(to))):
		twist = Basis(to)
		placed = transforms_at(0.0, 0.0, twist)
		stopped = false
		return twist
	var low: float = 0.0
	var high: float = 1.0
	for _round: int in ROUNDS:
		var middle: float = (low + high) * 0.5
		if has_room(transforms_at(0.0, 0.0, Basis(from.slerp(to, middle)))):
			low = middle
		else:
			high = middle
	twist = Basis(from.slerp(to, low))
	placed = transforms_at(0.0, 0.0, twist)
	stopped = true
	return twist


## The range a slide has, LDU from where it was grabbed.
func slide_range() -> Vector2:
	return _range


func can_slide() -> bool:
	return mode != "ball" and _range.y - _range.x > 4.0


# -- following the pointer ----------------------------------------------------------


## The pointer at [param screen], its ray from [param origin] along [param
## direction], [param eye] the camera: move the joint as the pointer says.
## The first move decides between turning and sliding, for a joint that
## does both, by whether it goes along the line as the eye sees it.
func follow(origin: Vector3, direction: Vector3, screen: Vector2, eye: Camera3D) -> void:
	if state != "moves":
		return
	if not _decided:
		if _hold_screen == Vector2.ZERO:
			_hold_screen = screen
			return
		var moved: Vector2 = screen - _hold_screen
		if moved.length() < 3.0:
			return
		_decided = true
		if can_slide() and eye != null:
			var a: Vector2 = eye.unproject_position(pivot)
			var b: Vector2 = eye.unproject_position(pivot + axis * 20.0)
			var line: Vector2 = (b - a)
			if line.length() > 4.0:
				var along: float = absf(moved.dot(line.normalized()))
				var across: float = absf(moved.cross(line.normalized()))
				if along > across * SLIDE_BIAS:
					mode = "slide"
	match mode:
		"turn":
			turn_to(_pointer_angle(origin, direction, screen))
		"slide":
			slide_to(_pointer_along(origin, direction))
		"ball":
			ball_to(_pointer_twist(origin, direction))


## Where the pointer says the joint is turned, degrees, unwrapped so a turn
## past half way carries on round.
func _pointer_angle(origin: Vector3, direction: Vector3, screen: Vector2) -> float:
	var held: Vector3 = _hold - pivot
	held -= axis * held.dot(axis)
	var facing: float = absf(direction.normalized().dot(axis))
	if held.length() < 1.0 or facing < 0.12:
		# Edge on, or held on the line itself: up and down the screen turn it.
		return -(screen.y - _hold_screen.y) * EDGE_ON_RATE
	# The plane the held point turns in: through it, square to the line.
	var denom: float = direction.dot(axis)
	var t: float = (_hold - origin).dot(axis) / denom
	var on: Vector3 = origin + direction * t - pivot
	on -= axis * on.dot(axis)
	if on.length() < 0.5:
		return _unwrapped
	var raw: float = rad_to_deg(atan2(axis.dot(held.cross(on)), held.dot(on)))
	var step: float = wrapf(raw - _last_raw, -180.0, 180.0)
	_last_raw = raw
	_unwrapped += step
	return _unwrapped


## Where the pointer says a slide has gone: the point of the joint's line
## nearest the pointer's ray, against where it was held.
func _pointer_along(origin: Vector3, direction: Vector3) -> float:
	# The line the held point slides on, not the joint's own: the pointer
	# stays on the point it took hold of, whatever the eye's perspective.
	var d: Vector3 = direction.normalized()
	var w: Vector3 = _hold - origin
	var b: float = axis.dot(d)
	var denom: float = 1.0 - b * b
	if denom < 1e-4:
		return shift
	return (b * w.dot(d) - w.dot(axis)) / denom


## A ball turned so the point held goes towards the pointer: the turn that
## carries where it was held onto the pointer's ray at the same distance
## from the middle.
func _pointer_twist(origin: Vector3, direction: Vector3) -> Basis:
	var held: Vector3 = _hold - pivot
	var radius: float = maxf(held.length(), 4.0)
	var d: Vector3 = direction.normalized()
	var w: Vector3 = origin - pivot
	var b: float = w.dot(d)
	var c: float = w.dot(w) - radius * radius
	var disc: float = b * b - c
	var on: Vector3
	if disc >= 0.0:
		on = w + d * (-b - sqrt(disc))
	else:
		on = w + d * (-b)
	if on.length() < 0.5 or held.length() < 0.5:
		return twist
	var turn := Quaternion(held.normalized(), on.normalized())
	return Basis(turn)


# -- letting go ------------------------------------------------------------------------


## Where a joint that does not hold by friction comes to rest under its own
## weight: turned towards where the centre of mass of what it carries is
## lowest, as far as it has room for. Quasi-static: no swing past it and
## back. Returns words, or "" when it stays where it was put.
func settle() -> String:
	if state != "moves" or mode != "turn" or link.holds or grams <= 0.0:
		return ""
	var turned: Transform3D = Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(axis, deg_to_rad(angle)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var centre: Vector3 = turned * _centre
	var out: Vector3 = centre - pivot
	out -= axis * out.dot(axis)
	var down: Vector3 = Vector3.DOWN - axis * Vector3.DOWN.dot(axis)
	if out.length() < 0.5 or down.length() < 0.05:
		return ""
	var to_bottom: float = rad_to_deg(atan2(axis.dot(out.cross(down)), out.dot(down)))
	if absf(to_bottom) < 0.5:
		return ""
	var from: float = angle
	turn_to(angle + to_bottom)
	var swung: float = angle - from
	if absf(swung) < 0.5:
		return ""
	if stopped:
		return "swung %d° under its own weight until it met the model" % roundi(absf(swung))
	return "swung %d° down under its own weight: %s turns freely" % [roundi(absf(swung)),
		link.words().trim_prefix("on ")]


## Put every part that moved where it now stands, as one step to undo,
## called [param words]. Returns how many moved.
func commit(words: String) -> int:
	var steps: Array = []
	for key: int in placed:
		var brick: BrickWorld.Brick = world.get_brick(key)
		if brick == null:
			continue
		var to: Transform3D = placed[key]
		if Grab._same(to, rest[key]):
			continue
		steps.append({"undo": "move", "brick": key, "transform": rest[key]})
		world.move_brick(key, to)
		builder.lattice.release(key)
		builder.lattice.occupy_boxes(key, builder.boxes_for(library.mesh_for(brick.part_id), to))
	builder.record(steps, words)
	return steps.size()


## The joint now, in words: "45°", "3 LDU along", "turned 30°".
func position_words() -> String:
	match mode:
		"slide":
			return "%s studs along" % Balance.studs(shift / BrickLattice.STUD)
		"ball":
			var turned: float = rad_to_deg(Quaternion(twist.orthonormalized()).get_angle())
			return "turned %d°" % roundi(turned)
	return "%d°" % roundi(angle)


## The step's words: "turned the boom, 38 parts, on its turntable to 45°".
func step_words() -> String:
	var verb: String = {"slide": "slid", "ball": "turned"}.get(mode, "turned")
	return "%s %s %s %s" % [verb, bodies.named(moving_bodies), link.words(),
		"to " + position_words() if mode == "turn" else position_words()]
