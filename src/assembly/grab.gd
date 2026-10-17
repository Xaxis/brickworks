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
const BALL_ROUNDS := 6
## How long the press may spend finding parts that can never meet anything.
const NEVER_MEET_MS := 30
## Where a turn stops, to within this, degrees.
const STOP_TO := 0.15
## A part all within this of the joint's line turns inside the holes it is
## in, LDU: an axle or a pin, radius 4, on its own line.
const ON_THE_LINE := 6.5
## A part may sink this far below the floor the model stands on, LDU, as
## Balance lets a pose: half a plate.
const BELOW_FLOOR := 4.0
## A drag along a joint's line this much more than across it slides.
const SLIDE_BIAS := 1.6
## Degrees a pixel when the joint's plane is edge on to the eye.
const EDGE_ON_RATE := 0.5
## Below this the pointer's ray meets the plane a turn is in too slantwise
## to read an angle off it, and the turn drawn nearest the pointer is taken.
const EDGE_ON := 0.12

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
## What the press spent, ms: reading what moves, the sweeps, the gears.
var begin_took: Dictionary = {}
## Why no gear turns with it, when none does: for a probe.
var gear_note: String = ""
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
## A frame's room test may run this long, ms (GrabDrag sets it); past it a
## turn is taken on trust and checked on a pause or at the release.
var budget_ms: float = INF
## Let go and settled under its weight (once), and what that said.
var settled: bool = false
var swung: String = ""
## The turn shown is not checked for room yet past [member _checked_angle].
var unchecked: bool = false
var _checked_angle: float = 0.0
var _verify_from: int = 0
var _verifying_lo: float = 0.0
var _verifying_hi: Variant = null
## Moving parts all within reach of the joint's line: not tested for room.
var _on_the_line: Dictionary = {}
## Parts met, and whether they overlapped the moving side where it stood.
var _rest_overlap: Dictionary = {}
## The last part that met something, and what it met: [moving, met].
var blocked_by: Array = []
## A ball's last turn that had no room, and where it stood then: not asked
## again while the pointer asks further the same way.
var _ball_wall := Quaternion.IDENTITY
var _ball_walled: bool = false
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
	var clock: int = Time.get_ticks_usec()
	begin_took.clear()
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
	# What it already overlaps where it stands is not in its way (covers are
	# 2 LDU cells, and a minifigure's hand sits closer to its leg than that):
	# asked of each part met, when it is met (has_room), not of all 131 parts
	# of a wing at the press.
	# A ball's socket sits flush against what the ball stands out of: within
	# a stud of the ball, a part touching the moving side by a cell is not
	# in its way, as the cells cannot tell a flush face from a collision
	# (30472's wing socket against its fuselage's 2x2 brick met it at once).
	if link.axis == Vector3.ZERO:
		var near_ball := AABB(link.point - Vector3.ONE * BrickLattice.STUD,
			Vector3.ONE * BrickLattice.STUD * 2.0)
		for key: int in moving:
			var boxes: PackedInt32Array = builder.lattice.boxes_of(key)
			if boxes.is_empty():
				continue
			# Its bounds a cell wider all round: flush is not overlapping.
			var wide: PackedInt32Array = BrickLattice._bound_of(boxes)
			wide = PackedInt32Array([wide[0] - 1, wide[1] - 1, wide[2] - 1, wide[3] + 1,
				wide[4] + 1, wide[5] + 1])
			for other: int in builder.lattice.near_bounds(wide, key):
				if skip.has(other):
					continue
				var them: BrickWorld.Brick = world.get_brick(other)
				var mesh: Lbm.PartMesh = library.mesh_for(them.part_id) if them != null else null
				if mesh != null and (them.transform * mesh.bounds).intersects(near_ball):
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
	# An axle or a pin on the joint's own line sweeps only the holes it is in,
	# and a part whose whole sweep round the line meets nothing but what it
	# may press on can never meet anything: neither is tested again.
	_on_the_line.clear()
	begin_took["reading"] = (Time.get_ticks_usec() - clock) / 1000
	clock = Time.get_ticks_usec()
	if mode == "turn":
		_never_meet()
	begin_took["sweeps"] = (Time.get_ticks_usec() - clock) / 1000
	clock = Time.get_ticks_usec()
	if mode == "turn":
		for key: int in moving:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh == null:
				continue
			var furthest: float = 0.0
			for corner: int in 8:
				var off: Vector3 = brick.transform * mesh.bounds.get_endpoint(corner) - pivot
				furthest = maxf(furthest, (off - axis * off.dot(axis)).length())
			if furthest <= ON_THE_LINE * 1.42:
				_on_the_line[key] = true
	var shaft_moves: bool = moving.has(link.shaft_part)
	_range = Vector2(-link.slide.y, link.slide.x) if shaft_moves else Vector2(-link.slide.x, link.slide.y)
	_gears()
	begin_took["gears"] = (Time.get_ticks_usec() - clock) / 1000
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
		gear_note = "no gear of it turns on this joint's line in the gear reading"
		mechanism = null
		return
	var solved: Dictionary = mechanism.solve({driven: 1.0})
	if not bool(solved["ok"]):
		# Gears that fight lock it, and are named. A lock no one mesh makes is
		# Mechanism's reading of a loop of pins elsewhere in a big model, not
		# of these gears: moved on its joint, its gears left where they are.
		gear_note = "the gear reading says: %s" % str(solved["said"])
		if bool(solved["locked"]) and not (solved["culprits"] as Array).is_empty():
			_refuse("locked", "%s will not turn: its gears lock (%s)." % [bodies.named(moving_bodies),
				", ".join(PackedStringArray(solved["culprits"]))])
		mechanism = null
		return
	_driver = driven
	_drive_sign = 1.0 if joint.way.dot(axis) > 0.0 else -1.0
	# What turns: every body the solve gives a spin, its parts; not the whole
	# model posed to find them (1,300 parts at the press).
	for one: int in mechanism.bodies:
		if one == mechanism.ground or mechanism.floating.has(one) \
				or mechanism.omega(one).length() <= 1e-6:
			continue
		for key: int in mechanism.bodies[one]:
			if moving.has(key) or not mechanism.rest.has(key):
				continue
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
	return _test(at, 0, INF).x == 1


## Test [param at] from the [param from]th moving part on, for at most
## [param budget] ms: Vector2i(1 room, 0 none, -1 out of time; the part to
## go on from).
func _test(at: Dictionary, from: int, budget: float) -> Vector2i:
	var started: int = Time.get_ticks_usec()
	tests += 1
	var keys: Array = moving.keys()
	var result: int = 1
	var n: int = from
	while n < keys.size():
		if budget < INF and float(Time.get_ticks_usec() - started) / 1000.0 > budget:
			result = -1
			break
		var key: int = keys[n]
		n += 1
		if _on_the_line.has(key):
			continue
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var to: Transform3D = at[key]
		var box: AABB = to * mesh.bounds
		if box.position.y < _floor_y - BELOW_FLOOR and mesh.lowest_at(to) < _floor_y - BELOW_FLOOR:
			result = 0
			break
		# Its box first: nothing but what it may press on anywhere near it,
		# and its turned cover is not worked out at all. A sail turning in
		# the air cost a windmill's drag 38 ms a frame that way.
		if not _near_anything(box):
			continue
		var packed: PackedInt32Array = builder.boxes_for(mesh, to)
		var hit: PackedInt64Array = builder.lattice.blockers_boxes(packed, 0, skip)
		# What it overlapped where it stood is not in its way: forgiven and
		# asked again.
		while not hit.is_empty() and _overlapped_at_rest(int(hit[0])):
			skip[int(hit[0])] = true
			hit = builder.lattice.blockers_boxes(packed, 0, skip)
		if not hit.is_empty():
			blocked_by = [key, int(hit[0])]
			result = 0
			break
	test_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return Vector2i(result, n if result == -1 else 0)


## Whether [param other] overlapped any part of the moving side where they
## stood when it was grabbed: the same answer, asked when first met, as
## asking every moving part at the press, so a turn tested later finds what
## one tested earlier found.
func _overlapped_at_rest(other: int) -> bool:
	if _rest_overlap.has(other):
		return _rest_overlap[other]
	var touching: bool = false
	var boxes: PackedInt32Array = builder.lattice.boxes_of(other)
	if not boxes.is_empty():
		for key: int in builder.lattice.blockers_boxes(boxes, other, {}):
			if moving.has(key):
				touching = true
				break
	_rest_overlap[other] = touching
	return touching


## Every moving part whose sweep all the way round the joint's line, a
## cylinder about it as far out as the part reaches, has nothing in it but
## what the moving side may press on: put with [member _on_the_line].
func _never_meet() -> void:
	var started: int = Time.get_ticks_msec()
	for key: int in moving:
		# An aid, not a rule: a big section's sweeps are many and wide, and
		# the press comes first. What is not looked at is tested as usual.
		if Time.get_ticks_msec() - started > NEVER_MEET_MS:
			return
		var brick: BrickWorld.Brick = world.get_brick(key)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var reach: float = 0.0
		var lo: float = INF
		var hi: float = -INF
		for corner: int in 8:
			var off: Vector3 = brick.transform * mesh.bounds.get_endpoint(corner) - pivot
			var along: float = off.dot(axis)
			reach = maxf(reach, (off - axis * along).length())
			lo = minf(lo, along)
			hi = maxf(hi, along)
		var sweep := AABB(pivot + axis * lo, Vector3.ZERO)
		for end: float in [lo, hi]:
			var middle: Vector3 = pivot + axis * end
			for n: int in 3:
				var way := Vector3.ZERO
				way[n] = 1.0
				var across: Vector3 = way - axis * way.dot(axis)
				var spread: float = across.length() * reach
				sweep = sweep.expand(middle + way * spread).expand(middle - way * spread)
		if not _near_anything(sweep):
			_on_the_line[key] = true


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
	var room: int = _test(at, 0, budget_ms).x
	if room != 0:
		# Room, or not all asked this frame: a big section is shown where the
		# pointer says and checked when it pauses or is let go
		# ([method verify_step]), rather than hold the frame.
		if room == 1 and not unchecked:
			_checked_angle = wanted
		else:
			unchecked = true
		angle = wanted
		placed = at
		stopped = false
		return angle
	if budget_ms < INF:
		# Met something, on a section too big to bisect in a frame: it stays
		# where it last had room and the stop is found a round a frame
		# (verify_step), on a pause or at the release.
		_wall = wanted
		if not unchecked:
			_checked_angle = angle
		unchecked = true
		_verifying_lo = _checked_angle
		_verifying_hi = wanted
		stopped = true
		return angle
	var low: float = angle
	var high: float = wanted
	# As many halvings as bring the step under STOP_TO: a frame's step is a
	# few degrees, and each round tests every part that may hit something.
	var rounds: int = clampi(ceili(log(maxf(absf(wanted - angle), STOP_TO) / STOP_TO) / log(2.0)),
		1, ROUNDS)
	for _round: int in rounds:
		var middle: float = (low + high) * 0.5
		if _test(transforms_at(middle), 0, budget_ms).x != 0:
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


## One frame's worth of checking a turn shown on trust: the whole section
## tested where it stands, a [member budget_ms] at a time; if something is in
## the way, bisected back towards the last turn checked, a round a frame.
## True once it stands where it has room.
func verify_step() -> bool:
	if not unchecked or mode != "turn":
		unchecked = false
		return true
	if _verifying_hi == null:
		var r: Vector2i = _test(transforms_at(angle), _verify_from, budget_ms)
		if r.x == -1:
			_verify_from = r.y
			return false
		_verify_from = 0
		if r.x == 1:
			unchecked = false
			_checked_angle = angle
			return true
		_verifying_hi = angle
		_verifying_lo = _checked_angle
	var hi: float = float(_verifying_hi)
	if absf(hi - _verifying_lo) < STOP_TO:
		angle = _verifying_lo
		placed = transforms_at(angle)
		_wall = hi
		_verifying_hi = null
		unchecked = false
		stopped = true
		_checked_angle = angle
		return true
	var middle: float = (_verifying_lo + hi) * 0.5
	var r2: Vector2i = _test(transforms_at(middle), _verify_from, budget_ms)
	if r2.x == -1:
		_verify_from = r2.y
		return false
	_verify_from = 0
	if r2.x == 1:
		_verifying_lo = middle
	else:
		_verifying_hi = middle
	angle = _verifying_lo
	placed = transforms_at(angle)
	stopped = true
	return false


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
	# Asked further than the turn that met something, about much the same
	# way: still met, and not tested again.
	if _ball_walled:
		var wall_step: Quaternion = _ball_wall * from.inverse()
		var step: Quaternion = to * from.inverse()
		if step.get_angle() >= wall_step.get_angle() - 0.001 and wall_step.get_angle() > 0.0001 \
				and step.get_axis().dot(wall_step.get_axis()) > 0.9:
			stopped = true
			return twist
	_ball_walled = false
	if has_room(transforms_at(0.0, 0.0, Basis(to))):
		twist = Basis(to)
		placed = transforms_at(0.0, 0.0, twist)
		stopped = false
		return twist
	var low: float = 0.0
	var high: float = 1.0
	# Fewer rounds than a turn: a ball's way changes every frame, so no wall
	# is kept, and 1/64 of a frame's step is under a degree.
	for _round: int in BALL_ROUNDS:
		var middle: float = (low + high) * 0.5
		if has_room(transforms_at(0.0, 0.0, Basis(from.slerp(to, middle)))):
			low = middle
		else:
			high = middle
	twist = Basis(from.slerp(to, low))
	placed = transforms_at(0.0, 0.0, twist)
	stopped = true
	_ball_wall = from.slerp(to, high)
	_ball_walled = true
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
			turn_to(_pointer_angle(origin, direction, screen, eye))
		"slide":
			slide_to(_pointer_along(origin, direction))
		"ball":
			ball_to(_pointer_twist(origin, direction))


## Where the pointer says the joint is turned, degrees, unwrapped so a turn
## past half way carries on round.
func _pointer_angle(origin: Vector3, direction: Vector3, screen: Vector2,
		eye: Camera3D = null) -> float:
	var held: Vector3 = _hold - pivot
	held -= axis * held.dot(axis)
	var facing: float = absf(direction.normalized().dot(axis))
	if held.length() < 1.0:
		# Held on the line itself: up and down the screen turn it.
		return -(screen.y - _hold_screen.y) * EDGE_ON_RATE
	if facing < EDGE_ON and eye != null:
		# Nearly edge on, the plane the held point turns in is a line on the
		# screen: the turn whose held point is drawn nearest the pointer,
		# within a half turn of where it is (4096's boom, seen from the side).
		var best: float = _unwrapped
		var nearest: float = INF
		for k: int in range(-36, 37):
			var trial: float = _unwrapped + float(k) * 2.5
			var at: Vector3 = Transform3D(Basis.IDENTITY, pivot) \
				* Transform3D(Basis(axis, deg_to_rad(trial)), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -pivot) * _hold
			if eye.is_position_behind(at):
				continue
			var gap: float = eye.unproject_position(at).distance_to(screen)
			if gap < nearest:
				nearest = gap
				best = trial
		for k: int in range(-10, 11):
			var trial: float = best + float(k) * 0.25
			var at: Vector3 = Transform3D(Basis.IDENTITY, pivot) \
				* Transform3D(Basis(axis, deg_to_rad(trial)), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -pivot) * _hold
			var gap: float = eye.unproject_position(at).distance_to(screen)
			if gap < nearest:
				nearest = gap
				best = trial
		_unwrapped = best
		_last_raw = wrapf(best, -180.0, 180.0)
		return best
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
