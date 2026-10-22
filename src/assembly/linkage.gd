## A closed loop of joints moved as the loop allows: a four-bar, a crank with
## its rod and piston, a steering's two arms and the track rod between them.
## Phase P2 of docs/MECHANISMS.md, for a grab (Grab) and move_part.
##
## The joints are [Bodies]' tree, grown out from the anchor; each link the
## tree did not grow along closes a loop (Bodies.closing). Where a body
## stands is every joint's turn (and slide) on its way from the anchor, the
## outer ones carrying the inner, as GrabChain has it. A loop is closed when
## each of its closing joints still holds its two halves together: the
## joint's point where it is in one half is where it is in the other, and its
## line in one is its line in the other. A ball keeps only its middle; an
## axle in a round hole keeps only its line, since it slides along it.
##
## One joint is driven (the one the pointer turns); the others are found by
## damped Gauss-Newton (Levenberg-Marquardt) on those residuals, with exact
## derivatives, starting from where they last were and following the driver
## in steps of a few degrees, so a four-bar stays open or crossed as it was
## built. A real model holds a loop by more joints than it needs (an axle
## through two holes, a beam on two pins): more equations than freedoms,
## which least squares takes as they come, so a chassis does not read as
## jammed. Nothing is made up past that: a loop that cannot close where the
## pointer asks stops at the nearest turn that does (bisected), and a loop
## that closes neither a degree one way nor the other has no freedom and is
## said locked.
class_name Linkage
extends RefCounted

## A loop is closed when no closing joint's halves are further apart than
## this, LDU, nor their lines turned apart by more than this over
## [constant AXIS_SCALE] radians (0.15°).
const CLOSE_TO := 0.05
## A step on the way to where the driver is asked, not the last, closes to
## this, LDU: near enough the loop to start the next step from, which is all
## it is for.
const ON_THE_WAY := 0.5
## Turned back to where it was built, the last step closes on towards this
## while each round takes a tenth off what is left ([method _close_with]).
const CLOSE_FINE := 0.0005
## A step turns no coordinate further than this, radians (29°), as far as
## the last step's slope says: what a small actuator's screw drives turns 2
## radians for each LDU its rod goes.
const MOST_TURN_STEP := 0.5
## Nor are there more steps than this in one move.
const MOST_STEPS := 48
## A joint's line turned a radian weighs as its point moved this far, LDU:
## a stud, about the length a joint's line runs in its holes.
const AXIS_SCALE := 20.0
## The driver is followed in steps of no more than this, radians (5°), or
## LDU for a slide.
const STEP_TURN := 0.0873
const STEP_SLIDE := 4.0
const ITERATIONS := 24
## More joints than this in the loops round a part: too many to solve as a
## pointer moves.
const MOST_JOINTS := 40
## How far either way the driver is tried to see whether the loop moves at
## all, radians (1°) or LDU.
const FREEDOM_TURN := 0.0175
const FREEDOM_SLIDE := 0.5

var bodies: Bodies
## Why it cannot be solved, or "" when it can.
var why: String = ""
## The joints solved: tree links, the driver first.
var links: Array[Bodies.Link] = []
## Each joint's child body (the one it turns) and parent.
var child_of := PackedInt64Array()
var parent_of := PackedInt64Array()
## Each joint's line, normalized, and its point, where the model stands.
var _axis: Array[Vector3] = []
var _point: Array[Vector3] = []
## The column of each joint's turn, and of its slide (-1: it does not slide).
var turn_col := PackedInt32Array()
var slide_col := PackedInt32Array()
var cols: int = 0
## The closing joints the loops are held by.
var closing: Array[Bodies.Link] = []
## Pinions in racks the loops are held by too (Racks.Pinion): a steering's
## track rod pushed by the pinion on its column. Each is one more equation:
## the rack has gone along its line, against the pinion, a tooth for each
## tooth of the pinion's turn against it.
var racks: Array[Racks.Pinion] = []
## For each, its pinion's body and its rack's, the loop joints on the way to
## each, and the pinion's turn against the rack as a sum of coordinates.
var _rack_ends: Array = []    ## [pinion body, rack body]
var _rack_sides: Array = []   ## [PackedInt32Array, PackedInt32Array]
var _rack_turn: Array = []    ## PackedFloat64Array, a coefficient a column
## How far each pinion may go along its rack from where it stood and still be
## read in it (Racks.room_along): Vector2(back, on), LDU.
var _rack_room: Array = []
## Gears meshing gears the loops are held by too (Mechanism.Coupling): a
## steering wheel that turns its pinion through a pair of bevels. Each is one
## more equation, linear, as Mechanism has it: the two gears' teeth move
## together where they meet. Offered by the grab (the train it drives), not
## read off the whole model: a drivetrain is not a loop.
var gear_meshes: Array = []
## For each mesh, both gears where they stood: [body, centre, axis, the way
## to the other gear's axis square to its own, its lever (how far its teeth
## move at the mesh for a radian of its own turn), -1 or +1, the columns that
## move either gear].
var _gear_ends: Array = []
## Each mesh's two gears' turns as last kept, radians: a turn is read off
## where the gear stands, -pi to pi, and unwrapped against these.
var _gear_kept: Array = []
var _offered: Array = []
## A gear of [member gear_meshes] is carried by more than its own joint: a
## gear riding on a joint the loop moves (8062-1's column, in a cab of
## hinges). Each mesh is read in the frame the two gears stand in, so it is
## as exact there as on axles in what stands.
var gears_carried: bool = false
## For each closing joint, the joints on the way from the anchor to each of
## its halves: [PackedInt32Array for a, for b].
var _sides: Array = []
## Every coordinate: radians for a turn, LDU for a slide.
var q := PackedFloat64Array()
## The column the pointer drives.
var driver_col: int = 0
## The last pose kept, and the driver's value there.
var kept := PackedFloat64Array()
## Every body the loop moves, its own joint's index (-1: carried by its
## parent), and its parent: what is drawn.
var moved: Array = []
var _index_of: Dictionary = {}   ## Link -> joint index
## Grams and centre of mass of each moved body where it stands.
var _grams: Dictionary = {}
var _centre: Dictionary = {}
## The turn columns of joints that only slide (an actuator's rod in its
## body): held at nought, never solved for.
var _still: Dictionary = {}
## How far a slide may go, column -> Vector2(least, most) from where it
## stood: an actuator's or a cylinder's stroke, a clip's or a hole's slide.
var _limits: Dictionary = {}
## The columns of [member _limits] the solve keeps inside them (a joint
## that turns and slides); an actuator's stroke is only checked once
## solved ([method _within]).
var _bounded: Dictionary = {}
## How the last solve went: iterations and the residual left, LDU.
var iterations: int = 0
var residual: float = 0.0
var solves: int = 0
var last_residual := PackedFloat64Array()


## The loops round [param driver] (a tree link) and its [param child]:
## every closing joint whose loop runs through a joint that moves, and every
## joint of those loops, until nothing more is added. A ball driver turns
## about [param driver_line] through its middle where one is given: a
## steering arm on two balls turns on the line through both (its kingpin,
## Grab._kingpin).
static func read(from: Bodies, driver: Bodies.Link, child: int, couplings: Array = [],
		driver_line: Vector3 = Vector3.ZERO, built: Dictionary = {}) -> Linkage:
	var out := Linkage.new()
	out.bodies = from
	out._offered = couplings
	out._driver_line = driver_line
	out._read(driver, child)
	out._from_built(built)
	return out


## The line a ball driver turns on (read), or ZERO.
var _driver_line := Vector3.ZERO


## The joints on the way from the anchor to one end of a closing joint, or
## of a rack and its pinion, and not to the other: what that loop turns.
func _only(a: int, b: int) -> Array:
	var on_a: Array = _path(a)
	var on_b: Array = _path(b)
	var only: Array = []
	for one: Variant in on_a:
		if not on_b.has(one):
			only.append(one)
	for one: Variant in on_b:
		if not on_a.has(one):
			only.append(one)
	return only


func _path(body: int) -> Array:
	var out: Array = []
	var at: int = _lead(body)
	while bodies.parent_link.has(at):
		out.push_front(bodies.parent_link[at])
		at = _lead(int(bodies.parent_of[at]))
	return out


## The body that stands for [param body]'s group of bodies held as one
## (Bodies.held_together): where it stands, they stand.
func _lead(body: int) -> int:
	return int(_held.get(body, body))


## Bodies.held_together, or empty where the driver turns within a group (then
## every body is its own, as the tree has them).
var _held: Dictionary = {}


func _read(driver: Bodies.Link, child: int) -> void:
	# Joints only between bodies not held as one: a steering standing in a
	# chassis of pins does not take in every pin of it. Not where the driver
	# is a joint within a group: the tree as it is says it does not move.
	_held = bodies.held_together()
	var driven: int = driver.b if bodies.parent_link.get(driver.b) == driver else driver.a
	if _lead(driven) != driven or _lead(driver.other(driven)) == driven:
		_held = {}
	# What closes the loops: every joint between two groups but the one each
	# group's lead hangs from, which the tree solves for.
	var closers: Array[Bodies.Link] = []
	for loop: Bodies.Link in bodies.closing:
		if _lead(loop.a) != _lead(loop.b):
			closers.append(loop)
	if not _held.is_empty():
		for body: int in bodies.parent_link:
			if _lead(body) != body and _lead(int(bodies.parent_of[body])) != _lead(body):
				closers.append(bodies.parent_link[body])
	var inside: Dictionary = {driver: true}
	var used: Dictionary = {}
	var changed: bool = true
	var meshes: Array[Racks.Pinion] = bodies.racks()
	while changed:
		changed = false
		for coupling: Mechanism.Coupling in _offered:
			if used.has(coupling):
				continue
			var one: int = int(bodies.body_of.get(coupling.one.key, -1))
			var other: int = int(bodies.body_of.get(coupling.other.key, -1))
			if one < 0 or other < 0 or one == other:
				continue
			var only_gears: Array = _only(one, other)
			var meets: bool = false
			for joint: Variant in only_gears:
				if inside.has(joint):
					meets = true
					break
			if not meets:
				continue
			used[coupling] = true
			gear_meshes.append(coupling)
			for joint: Variant in only_gears:
				if not inside.has(joint):
					inside[joint] = true
			changed = true
		for mesh: Racks.Pinion in meshes:
			if used.has(mesh):
				continue
			var only_mesh: Array = _only(int(bodies.body_of[mesh.gear]), int(bodies.body_of[mesh.rack]))
			var reaches: bool = false
			for one: Variant in only_mesh:
				if inside.has(one):
					reaches = true
					break
			if not reaches:
				continue
			used[mesh] = true
			racks.append(mesh)
			for one: Variant in only_mesh:
				if not inside.has(one):
					inside[one] = true
			changed = true
		for loop: Bodies.Link in closers:
			if used.has(loop):
				continue
			var only: Array = _only(loop.a, loop.b)
			var touches: bool = false
			for one: Variant in only:
				if inside.has(one):
					touches = true
					break
			if not touches:
				continue
			used[loop] = true
			closing.append(loop)
			for one: Variant in only:
				if not inside.has(one):
					inside[one] = true
					changed = true
			changed = true
		if inside.size() > MOST_JOINTS:
			why = "its loops have %d joints, too many to solve as it moves" % inside.size()
			return
	# The driver first, then the rest in the order the tree has them.
	var order: Array = [driver]
	for one: Variant in inside:
		if one != driver:
			order.append(one)
	for one: Variant in order:
		var link: Bodies.Link = one
		var kid: int = link.b if bodies.parent_link.get(link.b) == link else link.a
		_index_of[link] = links.size()
		links.append(link)
		child_of.append(kid)
		parent_of.append(int(bodies.parent_of[kid]))
		var line: Vector3 = _driver_line if link == driver and _driver_line != Vector3.ZERO else link.axis
		_axis.append(line.normalized())
		_point.append(link.point)
		turn_col.append(cols)
		if not link.turns:
			_still[cols] = true
		cols += 1
		if line == Vector3.ZERO:
			# A ball: three turns, about x, then y, then z where it stood.
			cols += 2
			slide_col.append(-1)
		elif link.slide.x + link.slide.y > 0.0:
			# An actuator's stroke, its rod or its body the one that moves;
			# a clip on its bar, as far as the two parts let it
			# (Bodies.exact_room, else Bodies._rounds_room), the solve kept
			# inside it. Unbounded, a loop closed by sliding 21019-1's clip
			# 4.3 LDU into the plate its handle is on, and 4002020-1's into
			# its bar's ball. And an axle in its hole, as far as what is on
			# its line lets it (Bodies.line_room): unbounded, 5533-1's
			# steering closed by sliding its arm 1.75 LDU on into its brick.
			# Not an engine's piston: kept to its cylinder's rounds, 8218-1's
			# stroke was 19.35 LDU where its crank's throw makes it 20.
			var shaft_moves: bool = int(bodies.body_of.get(link.shaft_part, -1)) == kid
			if not link.turns or link.reach != Vector2.ZERO or link.kind == "axle":
				var room: Vector2 = link.slide
				if link.kind == "axle":
					room = bodies.line_room(link)
				elif link.turns:
					var exact: Vector2 = bodies.exact_room(link)
					if exact.x >= 0.0:
						room = exact
				_limits[cols] = Vector2(-room.y, room.x) if shaft_moves else Vector2(-room.x, room.y)
			if link.turns and _limits.has(cols):
				_bounded[cols] = true
			slide_col.append(cols)
			cols += 1
		elif not link.turns:
			# Drawn all the way out or in, with nowhere to go but back.
			_limits[cols] = Vector2.ZERO
			slide_col.append(cols)
			cols += 1
		else:
			slide_col.append(-1)
	for loop: Bodies.Link in closing:
		_sides.append([_joints_on(loop.a), _joints_on(loop.b)])
	for mesh: Racks.Pinion in racks:
		var pinion: int = int(bodies.body_of[mesh.gear])
		var rack: int = int(bodies.body_of[mesh.rack])
		_rack_ends.append([pinion, rack])
		var sides: Array = [_joints_on(pinion), _joints_on(rack)]
		_rack_sides.append(sides)
		# The pinion's turn against the rack about its axis, as the joints
		# turn it from where they stood: each joint's share is its line's
		# along the pinion's axis, the pinion's side less the rack's.
		var turn := PackedFloat64Array()
		turn.resize(cols)
		turn.fill(0.0)
		for s: int in 2:
			for n: int in (sides[s] as PackedInt32Array):
				if _axis[n] != Vector3.ZERO:
					turn[turn_col[n]] += _axis[n].dot(mesh.axis) * (1.0 if s == 0 else -1.0)
		_rack_turn.append(turn)
		var in_body: Array = []
		for key: int in bodies.members.get(rack, PackedInt64Array()):
			var brick: BrickWorld.Brick = bodies.world.get_brick(key)
			if brick != null and Racks.is_rack(brick.part_id):
				in_body.append([brick.transform, brick.part_id])
		_rack_room.append(Racks.room_along(mesh, in_body))
	for coupling: Mechanism.Coupling in gear_meshes:
		# Mechanism's equation, the teeth moving together where they meet, with
		# each gear's turn read against the line to the other gear's axis
		# rather than against the world: a pair carried round together turns
		# neither against the other, so a gear riding on a joint the loop moves
		# is read as exactly as one on an axle in what stands. Linear in the
		# joints' turns, as Mechanism's rows are, it turned 8062-1's column
		# 4.6° off its bevels.
		var ends: Array = []
		var columns := PackedInt32Array()
		for side: int in 2:
			var gear: Mechanism.Gear = coupling.one if side == 0 else coupling.other
			var mate: Mechanism.Gear = coupling.other if side == 0 else coupling.one
			var point: Vector3 = coupling.point if side == 0 else coupling.point_other
			var along: Vector3 = coupling.along if side == 0 else coupling.along_other
			var body: int = int(bodies.body_of[gear.key])
			if _joints_on(body).size() > 1:
				gears_carried = true
			for n: int in _joints_on(body):
				for c: int in [turn_col[n], slide_col[n]] + ([turn_col[n] + 1, turn_col[n] + 2]
						if _axis[n] == Vector3.ZERO else []):
					if c >= 0 and not columns.has(c):
						columns.append(c)
			var toward: Vector3 = mate.centre - gear.centre
			toward -= gear.axis * toward.dot(gear.axis)
			ends.append([body, gear.centre, gear.axis, toward.normalized(),
				gear.axis.cross(point - gear.centre).dot(along) + coupling.lead * gear.axis.dot(along),
				-1.0 if side == 0 else 1.0])
		ends.append(columns)
		_gear_ends.append(ends)
		_gear_kept.append(PackedFloat64Array([0.0, 0.0]))
	for n: int in links.size():
		for c: int in ([turn_col[n]] + ([turn_col[n] + 1, turn_col[n] + 2] if _axis[n] == Vector3.ZERO else [])):
			if not _still.has(c):
				_turning.append(c)
	# Which constraints each column moves one end of and not the other.
	for k: int in closing.size():
		_own_columns(k, _sides[k][0], _sides[k][1])
	for k: int in racks.size():
		_own_columns(RACK_ROWS + k, _rack_sides[k][0], _rack_sides[k][1])
	for k: int in _gear_ends.size():
		_own_columns(GEAR_ROWS + k, _joints_on(int(_gear_ends[k][0][0])), _joints_on(int(_gear_ends[k][1][0])))
	q.resize(cols)
	q.fill(0.0)
	kept = q.duplicate()
	_gear_at_keep = _gear_kept.duplicate(true)
	driver_col = turn_col[0]
	if not links[0].turns and slide_col[0] >= 0:
		# An actuator's rod: driven along it.
		driver_col = slide_col[0]
	var carrier: PackedInt32Array = _joints_on(parent_of[0])
	for n: int in range(1, links.size()):
		if carrier.has(n):
			for c: int in [turn_col[n], slide_col[n]] + ([turn_col[n] + 1, turn_col[n] + 2]
					if _axis[n] == Vector3.ZERO else []):
				if c >= 0:
					_carrying[c] = true
	# The bearings of the gear chains the loop is held by that hold by
	# friction: a gear's own joint, or its axle's.
	var geared: Dictionary = {}
	for coupling: Mechanism.Coupling in gear_meshes:
		for key: int in [coupling.one.key, coupling.other.key]:
			geared[_lead(int(bodies.body_of.get(key, -1)))] = true
	for n: int in range(1, links.size()):
		if links[n].holds and links[n].turns and geared.has(int(child_of[n])):
			for c: int in [turn_col[n], slide_col[n]] + ([turn_col[n] + 1, turn_col[n] + 2]
					if _axis[n] == Vector3.ZERO else []):
				if c >= 0 and c != driver_col:
					_friction[c] = true
	# An axle's slide along its hole, within what its line lets it: the
	# loop slides it only where turning will not close the loop. Least squares
	# over every coordinate alike slid 42125-1's suspension arms along their
	# axles as its knuckles turned, 0.5 LDU for 10°, until a bush met a shock
	# absorber at 25°; its knuckles turn on their kingpins without it. A
	# friction bearing holds harder still: damped alike, a telescope's tube
	# slid 7.08 LDU of 8 on its rod, its gear chain's friction pin taking the
	# rest.
	for n: int in range(1, links.size()):
		var c: int = slide_col[n]
		if c >= 0 and links[n].turns and (not _limits.has(c) or links[n].kind == "axle") and c != driver_col:
			_sliding[c] = true
	# An axle sliding in the holes of what carries it, with a part of the
	# loop sliding along it: the two slides are one between them, and where
	# the axle stands on its line is freedom the loop does not need. Damped
	# alike, each step slid it half the part's way: the observatory's
	# telescope tube, run 120 LDU out along its axle, took the axle 19.5 LDU
	# to the end of its room (Bodies.line_room), and run back, a fresh read
	# with its room from there, 19.5 past where it was built. Held as a
	# friction bearing is, it stays in what carries it, and goes only where
	# the part on it is at an end of its own room. Only where all the axle
	# carries of what holds the loop rides on a part sliding along it: a
	# pinion on the axle itself, or a joint on it that closes a loop, may
	# need it to slide.
	var ends: Array = _sides + _rack_sides
	for k: int in _gear_ends.size():
		ends.append([_joints_on(int(_gear_ends[k][0][0])), _joints_on(int(_gear_ends[k][1][0]))])
	for n: int in range(1, links.size()):
		var c: int = slide_col[n]
		var axle: int = child_of[n]
		if not _sliding.has(c) or _lead(int(bodies.body_of.get(links[n].shaft_part, -1))) != axle:
			continue
		var along: Array = []
		for m: int in links.size():
			if m != n and _lead(parent_of[m]) == axle and slide_col[m] >= 0 and slide_col[m] != driver_col \
					and absf(_axis[m].dot(_axis[n])) > 0.999:
				along.append(m)
		var spare: bool = not along.is_empty()
		for pair: Array in ends:
			for path: PackedInt32Array in pair:
				if path.has(n) and not along.any(func(m: int) -> bool: return path.has(m)):
					spare = false
		if spare:
			_carried[c] = true
	# What moves: every body a joint of the loops is on the way to.
	var moves: Dictionary = {}   ## lead -> whether it moves
	for body: int in bodies.members:
		var climb: Array = []
		var at: int = _lead(body)
		var goes: bool = false
		while true:
			if moves.has(at):
				goes = bool(moves[at])
				break
			if not bodies.parent_link.has(at):
				goes = false
				break
			if _index_of.has(bodies.parent_link[at]):
				goes = true
				break
			climb.append(at)
			at = _lead(int(bodies.parent_of[at]))
		moves[at] = goes
		for one: int in climb:
			moves[one] = goes
		if goes:
			moved.append(body)
	for body: int in moved:
		var weight: float = 0.0
		var sum := Vector3.ZERO
		for key: int in bodies.members.get(body, PackedInt64Array()):
			var brick: BrickWorld.Brick = bodies.world.get_brick(key)
			var info: PartLibrary.PartInfo = bodies.library.parts.get(brick.part_id) if brick != null else null
			if info == null:
				continue
			var g: float = Stability.grams(info)
			weight += g
			sum += (brick.transform * info.bounds.get_center()) * g
		_grams[body] = weight
		_centre[body] = sum / maxf(weight, 0.000001)


## Each closing joint's far half, and each rack's pinion, measured from where
## the two parts were built ([param built]: brick id -> Transform3D, where a
## grab first moved each; Grab._built_at). Read where the parts stand, a joint
## a move left open read as closed: 5533-1's first turn ended with a pin 0.24
## LDU out of its hole, the next took that for closed, and on the way back
## its left arm stayed turned 7.6° while a steering arm slid out 5.3 LDU. A
## gap as built is nought, so a model built with a pin a little off its hole
## starts no move with one to close. Where the two stand further from how
## they were built than [constant FROM_BUILT_MOST], they were rebuilt, not
## left open, and are read as they stand.
func _from_built(built: Dictionary) -> void:
	_far_half.clear()
	_rack_built.clear()
	for loop: Bodies.Link in closing:
		var far: Array = [loop.point, loop.axis]
		var change: Variant = _since_built(loop.pairs[0] as Array, loop.a, built)
		if change != null:
			var point: Vector3 = (change as Transform3D) * loop.point
			var axis: Vector3 = ((change as Transform3D).basis * loop.axis).normalized() \
				if loop.axis != Vector3.ZERO else Vector3.ZERO
			var gap: Vector3 = point - loop.point
			if _slides(loop):
				gap -= loop.axis.normalized() * gap.dot(loop.axis.normalized())
			if gap.length() <= FROM_BUILT_MOST and (loop.axis == Vector3.ZERO
					or loop.axis.normalized().cross(axis).length() * AXIS_SCALE <= FROM_BUILT_MOST):
				far = [point, axis]
		_far_half.append(far)
	for mesh: Racks.Pinion in racks:
		var off: float = 0.0
		var change: Variant = _since_built([mesh.gear, mesh.rack], int(bodies.body_of.get(mesh.gear, -1)), built)
		if change != null and mesh.rate != 0.0:
			# Along the rack since built, and the pinion's turn against it,
			# unwrapped to the turn that goes with that.
			var along: float = mesh.line.dot(mesh.centre - (change as Transform3D) * mesh.centre)
			var back: Quaternion = (change as Transform3D).affine_inverse().basis.orthonormalized().get_rotation_quaternion()
			var turn: float = 2.0 * atan2(Vector3(back.x, back.y, back.z).dot(mesh.axis), back.w)
			turn += TAU * roundf((-along / mesh.rate - turn) / TAU)
			off = along + mesh.rate * turn
			if absf(off) > FROM_BUILT_MOST:
				off = 0.0
		_rack_built.append(off)
	# Where each slide the loop has to spare stood as built, against where it
	# stands: the coordinate that puts it back.
	_slide_built.clear()
	for n: int in links.size():
		var c: int = slide_col[n]
		if c < 0 or not _sliding.has(c) or c == driver_col:
			continue
		var change: Variant = _since_built(links[n].pairs[0] as Array, child_of[n], built)
		var since: float = 0.0
		if change != null:
			since = _axis[n].dot(_point[n] - (change as Transform3D) * _point[n])
		if absf(since) <= FROM_BUILT_MOST * 10.0:
			_slide_built[c] = -since
	# And where the driver stood as built: its turn (or slide) back there.
	_driver_built = NAN
	var driven: Variant = _since_built(links[0].pairs[0] as Array, child_of[0], built) if not links.is_empty() else null
	if driven != null:
		var back: Transform3D = driven
		if driver_col == slide_col[0]:
			_driver_built = _axis[0].dot(back * _point[0] - _point[0])
		elif _axis[0] != Vector3.ZERO:
			var turn: Quaternion = back.basis.orthonormalized().get_rotation_quaternion()
			_driver_built = 2.0 * atan2(Vector3(turn.x, turn.y, turn.z).dot(_axis[0]), turn.w)
			_driver_built = wrapf(_driver_built, -PI, PI)


## Whether the loops close with the driver at [param at], where it was
## built, and each slide they have to spare back where it was built too
## ([member _slide_built]), from [param from_q]. A slide the loop took on the
## way out is kept by least change on the way back, where turning would close
## it as well: 5533-1's steering knuckle slid 2.9 LDU out along its axle, and
## came back with its arm turned to make up for it, its wheel 0.28 LDU off.
func _closes_built(at: float, from_q: PackedFloat64Array) -> bool:
	if _slide_built.is_empty() or is_nan(_driver_built) or absf(at - _driver_built) > BACK_AT_BUILT:
		return false
	var start: PackedFloat64Array = from_q.duplicate()
	start[driver_col] = at
	var apart: bool = false
	for c: int in _slide_built:
		var to: float = float(_slide_built[c])
		if _bounded.has(c):
			to = clampf(to, (_limits[c] as Vector2).x, (_limits[c] as Vector2).y)
		apart = apart or absf(start[c] - to) > CLOSE_FINE
		start[c] = to
	if not apart:
		return false
	q = start
	_fine = true
	var closed: bool = _close() and _within()
	_fine = false
	return closed


## Whether each move's last step closes on to [constant CLOSE_FINE]: a
## session's move, not a drag's frame (Grab sets it). Stopped at a fifth of
## CLOSE_TO, a turn back left 8466-1's rack 0.011 LDU off its driver, and its
## steering column, turning with a pinion in that rack, 0.2 LDU off at its top
## universal joint, 220 LDU from the pinion's line. Asked of every drag's
## frame, the round more it takes cost the wheel loader's arm 1 ms of its 95th
## frame in 14.
var fine: bool = false
## And back where the loop was built, a drag's too ([method _closes_built]).
var _fine: bool = false


## [param pair]'s two parts as they stand against each other, from how they
## stood as built: the move that takes the one in [param body_one] from where
## it stands to where it would stand had it kept to the other as built. Null
## where neither has moved since it was built.
func _since_built(pair: Array, body_one: int, built: Dictionary) -> Variant:
	var one: int = int(pair[0])
	var other: int = int(pair[1])
	if int(bodies.body_of.get(one, -1)) != body_one:
		one = int(pair[1])
		other = int(pair[0])
	if not built.has(one) and not built.has(other):
		return null
	var a: BrickWorld.Brick = bodies.world.get_brick(one)
	var b: BrickWorld.Brick = bodies.world.get_brick(other)
	if a == null or b == null:
		return null
	var a0: Transform3D = built.get(one, a.transform)
	var b0: Transform3D = built.get(other, b.transform)
	return b.transform * b0.affine_inverse() * a0 * a.transform.affine_inverse()


## A driver this near where it was built, radians or LDU, is back there.
const BACK_AT_BUILT := 0.001
## How far a joint's halves may stand from how they were built, LDU (and its
## lines, over [constant AXIS_SCALE]), and be read as a gap a move left: past
## [constant ON_THE_WAY], what a step along the way closes to.
const FROM_BUILT_MOST := 1.0
## Each closing joint's far half: [its point, its line] where they stand,
## to meet the near half's ([method _from_built]).
var _far_half: Array = []
## Each rack's teeth off its pinion's since built, LDU ([method _from_built]).
var _rack_built := PackedFloat64Array()
## Each spare slide's coordinate as built: column -> value ([method _from_built]).
var _slide_built: Dictionary = {}
## The driver's coordinate as built, or NAN where it has not moved since.
var _driver_built: float = NAN


## The loop joints on the way from the anchor to [param body].
func _joints_on(body: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for link: Variant in _path(body):
		if _index_of.has(link):
			out.append(int(_index_of[link]))
	return out


## A constraint's rows are numbered: a closing joint by its index, a rack
## and pinion from RACK_ROWS, a gear mesh from GEAR_ROWS.
const RACK_ROWS := 100000
const GEAR_ROWS := 200000
## Constraints left out of the residual and the derivatives, and columns
## held where they are besides those a close is asked to hold: while one part
## of the loops is solved apart from the rest ([method _reach_parted]).
var _rows_off: Dictionary = {}
var _hold_also: Dictionary = {}
## Column -> the constraints it moves one end of and not the other.
var _moves_rows: Dictionary = {}


## Note [param k]'s columns: those of the joints on the way to one end and
## not the other. A joint on the way to both moves both ends together.
func _own_columns(k: int, one: PackedInt32Array, other: PackedInt32Array) -> void:
	for side: int in 2:
		var mine: PackedInt32Array = one if side == 0 else other
		var theirs: PackedInt32Array = other if side == 0 else one
		for n: int in mine:
			if theirs.has(n):
				continue
			for c: int in [turn_col[n], slide_col[n]] + ([turn_col[n] + 1, turn_col[n] + 2]
					if _axis[n] == Vector3.ZERO else []):
				if c < 0 or _still.has(c):
					continue
				if not _moves_rows.has(c):
					_moves_rows[c] = {}
				(_moves_rows[c] as Dictionary)[k] = true


## Drive the slide of the driver's joint rather than its turn.
func drive_slide() -> bool:
	if slide_col[0] < 0:
		return false
	driver_col = slide_col[0]
	return true


func is_slide() -> bool:
	return driver_col != turn_col[0]


## Whether any joint of the loops holds by friction: then the loop holds
## where it is put, as one friction pin in a four-bar holds it.
func holds() -> bool:
	for link: Bodies.Link in links:
		if link.holds:
			return true
	return false


## Whether the driver's joint stands still while the loop moves: its parent
## is not carried by any joint of the loop (a crank on the frame), so a
## pointer turning about its line is right.
func driver_fixed() -> bool:
	for n: int in _joints_on(parent_of[0]):
		if n != 0:
			return false
	return true


# -- where everything stands --------------------------------------------------------


func _turn_of(n: int, at: PackedFloat64Array) -> Transform3D:
	var axis: Vector3 = _axis[n]
	if axis == Vector3.ZERO:
		var c: int = turn_col[n]
		return Transform3D(Basis.IDENTITY, _point[n]) \
			* Transform3D(_ball_basis(at[c], at[c + 1], at[c + 2]), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -_point[n])
	var slide: float = at[slide_col[n]] if slide_col[n] >= 0 else 0.0
	return Transform3D(Basis.IDENTITY, _point[n]) \
		* Transform3D(Basis(axis, at[turn_col[n]]), axis * slide) \
		* Transform3D(Basis.IDENTITY, -_point[n])


static func _ball_basis(x: float, y: float, z: float) -> Basis:
	return Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y) * Basis(Vector3.BACK, z)


## A ball's three lines where its parent carries it, with its turns at
## [param at]: x, then y as x has turned it, then z as both have.
func _ball_ways(n: int, at: PackedFloat64Array, up: Transform3D) -> Array[Vector3]:
	var c: int = turn_col[n]
	var first: Basis = Basis(Vector3.RIGHT, at[c])
	var second: Basis = first * Basis(Vector3.UP, at[c + 1])
	return [(up.basis * Vector3.RIGHT).normalized(), (up.basis * (first * Vector3.UP)).normalized(),
		(up.basis * (second * Vector3.BACK)).normalized()]


## Where [param body] stands against where it stood, with the joints at
## [param at]: every loop joint on its way from the anchor, outermost first.
func _place(body: int, at: PackedFloat64Array, cache: Dictionary) -> Transform3D:
	if cache.has(body):
		return cache[body]
	var climb: Array = []
	var here: int = _lead(body)
	var base := Transform3D.IDENTITY
	while true:
		if cache.has(here):
			base = cache[here]
			break
		if not bodies.parent_link.has(here):
			cache[here] = Transform3D.IDENTITY
			break
		climb.append(here)
		here = _lead(int(bodies.parent_of[here]))
	for k: int in range(climb.size() - 1, -1, -1):
		var one: int = climb[k]
		var joint: Variant = _index_of.get(bodies.parent_link[one])
		if joint != null:
			base = base * _turn_of(int(joint), at)
		cache[one] = base
	cache[body] = base
	return base


## Each closing joint's residual: 3 for where its halves meet, 3 for their
## lines (none for a ball).
func _residual(at: PackedFloat64Array, cache: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k: int in closing.size():
		if _rows_off.has(k):
			continue
		var loop: Bodies.Link = closing[k]
		var wa: Transform3D = _place(loop.a, at, cache)
		var wb: Transform3D = _place(loop.b, at, cache)
		var far: Array = _far_half[k]
		var gap: Vector3 = wa * loop.point - wb * (far[0] as Vector3)
		if loop.axis != Vector3.ZERO:
			var ua: Vector3 = (wa.basis * loop.axis).normalized()
			var ub: Vector3 = (wb.basis * (far[1] as Vector3)).normalized()
			if _slides(loop):
				gap -= ua * gap.dot(ua)
			out.append_array([gap.x, gap.y, gap.z])
			var turned: Vector3 = ua.cross(ub) * AXIS_SCALE
			out.append_array([turned.x, turned.y, turned.z])
		else:
			out.append_array([gap.x, gap.y, gap.z])
	for k: int in racks.size():
		if not _rows_off.has(RACK_ROWS + k):
			out.append(_rack_residual(k, at, cache))
	for k: int in _gear_ends.size():
		if not _rows_off.has(GEAR_ROWS + k):
			out.append(_gear_residual(k, at, cache))
	return out


## Gear mesh [param k]'s two gears' turns, radians, with the joints at
## [param at]: each gear's own turn about its axis, read against the line
## from it to the other gear's axis, unwrapped against the turn last kept.
func _gear_turns(k: int, at: PackedFloat64Array, cache: Dictionary) -> PackedFloat64Array:
	var ends: Array = _gear_ends[k]
	var out := PackedFloat64Array([0.0, 0.0])
	for side: int in 2:
		var end: Array = ends[side]
		var mate: Array = ends[1 - side]
		var mine: Transform3D = _place(int(end[0]), at, cache)
		var theirs: Transform3D = _place(int(mate[0]), at, cache)
		var u: Vector3 = (mine.basis * (end[2] as Vector3)).normalized()
		var centre: Vector3 = mine * (end[1] as Vector3)
		var toward: Vector3 = theirs * (mate[1] as Vector3) - centre
		var line: Vector3 = (toward - u * toward.dot(u)).normalized()
		var mark: Vector3 = (mine.basis * (end[3] as Vector3)).normalized()
		var turn: float = atan2(u.dot(line.cross(mark)), line.dot(mark))
		var was: float = (_gear_kept[k] as PackedFloat64Array)[side]
		out[side] = turn + TAU * roundf((was - turn) / TAU)
	return out


## How far gear mesh [param k]'s teeth stand apart where they meet, LDU:
## each gear's lever times its turn, the one's less the other's.
func _gear_residual(k: int, at: PackedFloat64Array, cache: Dictionary) -> float:
	var ends: Array = _gear_ends[k]
	var turns: PackedFloat64Array = _gear_turns(k, at, cache)
	return float(ends[0][5]) * float(ends[0][4]) * turns[0] + float(ends[1][5]) * float(ends[1][4]) * turns[1]


## Each gear's turn where [param at] stands, kept to unwrap the next against.
func _keep_gear_turns(at: PackedFloat64Array) -> void:
	for k: int in _gear_ends.size():
		_gear_kept[k] = _gear_turns(k, at, {})


## How far rack [param k] stands from where its pinion's teeth put it, LDU:
## where the pinion's centre now is in the rack's own frame, along the
## rack's teeth, from where it was; plus the teeth's share of the pinion's
## turn against the rack.
func _rack_residual(k: int, at: PackedFloat64Array, cache: Dictionary) -> float:
	var mesh: Racks.Pinion = racks[k]
	var ends: Array = _rack_ends[k]
	var wa: Transform3D = _place(int(ends[0]), at, cache)
	var wb: Transform3D = _place(int(ends[1]), at, cache)
	var seen: Vector3 = wb.affine_inverse() * (wa * mesh.centre)
	var turn: float = 0.0
	var coefficients: PackedFloat64Array = _rack_turn[k]
	for c: int in cols:
		if coefficients[c] != 0.0:
			turn += coefficients[c] * at[c]
	return mesh.line.dot(seen - mesh.centre) + mesh.rate * turn + float(_rack_built[k])


static func _slides(loop: Bodies.Link) -> bool:
	return loop.slide.x + loop.slide.y > 0.0


## d residual / d coordinate, exactly: a turn moves a point at x by its
## line's way crossed with (x − its point), a slide by its way; a line turns
## by its way crossed with it. Rows as [_residual] has them.
func _jacobian(at: PackedFloat64Array, cache: Dictionary) -> Array:
	var rows: Array = []
	# Each joint's line and point where its parent now carries them.
	var ways: Array[Vector3] = []
	var points: Array[Vector3] = []
	var ball_ways: Dictionary = {}   ## joint -> its three lines
	ways.resize(links.size())
	points.resize(links.size())
	# Only the joints the constraints asked are on the way to, while a part is
	# solved apart: where every joint stands is most of a small part's work.
	var wanted: Dictionary = _joints_wanted()
	for n: int in links.size():
		if not wanted.is_empty() and not wanted.has(n):
			continue
		var up: Transform3D = _place(parent_of[n], at, cache)
		ways[n] = (up.basis * _axis[n]).normalized() if _axis[n] != Vector3.ZERO else Vector3.ZERO
		points[n] = up * _point[n]
		if _axis[n] == Vector3.ZERO:
			ball_ways[n] = _ball_ways(n, at, up)
	for k: int in closing.size():
		if _rows_off.has(k):
			continue
		var loop: Bodies.Link = closing[k]
		var wa: Transform3D = _place(loop.a, at, cache)
		var wb: Transform3D = _place(loop.b, at, cache)
		var far: Array = _far_half[k]
		var pa: Vector3 = wa * loop.point
		var pb: Vector3 = wb * (far[0] as Vector3)
		var ua := Vector3.ZERO
		var ub := Vector3.ZERO
		if loop.axis != Vector3.ZERO:
			ua = (wa.basis * loop.axis).normalized()
			ub = (wb.basis * (far[1] as Vector3)).normalized()
		# Columns: d(gap) and d(ua × ub) for each coordinate.
		var gaps: Array[Vector3] = []
		var turns: Array[Vector3] = []
		gaps.resize(cols)
		turns.resize(cols)
		gaps.fill(Vector3.ZERO)
		turns.fill(Vector3.ZERO)
		# And d(ua), for a joint that slides: what is taken off its gap is
		# along ua, which turns too.
		var sliding: bool = loop.axis != Vector3.ZERO and _slides(loop)
		var duas: Array[Vector3] = []
		if sliding:
			duas.resize(cols)
			duas.fill(Vector3.ZERO)
		var sides: Array = _sides[k]
		for s: int in 2:
			var sign: float = 1.0 if s == 0 else -1.0
			var x: Vector3 = pa if s == 0 else pb
			var u: Vector3 = ua if s == 0 else ub
			for n: int in (sides[s] as PackedInt32Array):
				var lines: Array = ball_ways.get(n, [ways[n]])
				for line: int in lines.size():
					var w: Vector3 = lines[line]
					var c: int = turn_col[n] + line
					gaps[c] += w.cross(x - points[n]) * sign
					if loop.axis != Vector3.ZERO:
						var du: Vector3 = w.cross(u)
						# d(ua × ub) = dua × ub + ua × dub
						turns[c] += (du.cross(ub) if s == 0 else ua.cross(du)) * AXIS_SCALE
						if sliding and s == 0:
							duas[c] += du
				var w: Vector3 = ways[n]
				if slide_col[n] >= 0:
					gaps[slide_col[n]] += w * sign
		if sliding:
			# Along its own line the halves may part: that component is not
			# a residual. Its derivative is d(gap − ua (ua · gap)): the gap's
			# own change less its share along ua, and less what ua's turning
			# takes off. Without the last, the derivatives of an axle slid
			# some way through its hole were off by as much as the slide.
			var raw: Vector3 = pa - pb
			var along: float = ua.dot(raw)
			for c: int in cols:
				gaps[c] -= ua * gaps[c].dot(ua) + duas[c] * along + ua * duas[c].dot(raw)
		for r: int in 3:
			var row := PackedFloat64Array()
			row.resize(cols)
			for c: int in cols:
				row[c] = gaps[c][r]
			rows.append(row)
		if loop.axis != Vector3.ZERO:
			for r: int in 3:
				var row := PackedFloat64Array()
				row.resize(cols)
				for c: int in cols:
					row[c] = turns[c][r]
				rows.append(row)
	for k: int in racks.size():
		if _rows_off.has(RACK_ROWS + k):
			continue
		var mesh: Racks.Pinion = racks[k]
		var ends: Array = _rack_ends[k]
		var wa: Transform3D = _place(int(ends[0]), at, cache)
		var wb: Transform3D = _place(int(ends[1]), at, cache)
		var x: Vector3 = wa * mesh.centre
		var back: Basis = wb.basis.inverse()
		var row: PackedFloat64Array = (_rack_turn[k] as PackedFloat64Array).duplicate()
		for c: int in cols:
			row[c] *= mesh.rate
		# The pinion's centre moved by a joint on its side moves where it is
		# seen from the rack; a joint on the rack's side moves the rack under
		# it the other way.
		var sides: Array = _rack_sides[k]
		for s: int in 2:
			var sign: float = 1.0 if s == 0 else -1.0
			for n: int in (sides[s] as PackedInt32Array):
				var lines: Array = ball_ways.get(n, [ways[n]])
				for line: int in lines.size():
					var w: Vector3 = lines[line]
					row[turn_col[n] + line] += mesh.line.dot(back * w.cross(x - points[n])) * sign
				if slide_col[n] >= 0:
					row[slide_col[n]] += mesh.line.dot(back * ways[n]) * sign
		rows.append(row)
	# A gear mesh's row by central differences, over the columns that move
	# either gear: its turns are read off angles, and a step of 1e-3 keeps the
	# difference well above single precision's rounding.
	for k: int in _gear_ends.size():
		if _rows_off.has(GEAR_ROWS + k):
			continue
		var row := PackedFloat64Array()
		row.resize(cols)
		row.fill(0.0)
		for c: int in (_gear_ends[k][2] as PackedInt32Array):
			if _still.has(c):
				continue
			var up: PackedFloat64Array = at.duplicate()
			var down: PackedFloat64Array = at.duplicate()
			up[c] += 1e-3
			down[c] -= 1e-3
			row[c] = (_gear_residual(k, up, {}) - _gear_residual(k, down, {})) / 2e-3
		rows.append(row)
	return rows


## The joints on the way to either end of each constraint not left out
## (joint -> true), or empty when none is left out: all of them.
func _joints_wanted() -> Dictionary:
	if _rows_off.is_empty():
		return {}
	if _wanted_for == _rows_off:
		return _wanted
	_wanted = {}
	_wanted_for = _rows_off
	var lists: Array = []
	for k: int in closing.size():
		if not _rows_off.has(k):
			lists.append_array(_sides[k])
	for k: int in racks.size():
		if not _rows_off.has(RACK_ROWS + k):
			lists.append_array(_rack_sides[k])
	for k: int in _gear_ends.size():
		if not _rows_off.has(GEAR_ROWS + k):
			lists.append(_joints_on(int(_gear_ends[k][0][0])))
			lists.append(_joints_on(int(_gear_ends[k][1][0])))
	for one: PackedInt32Array in lists:
		for n: int in one:
			_wanted[n] = true
	if _wanted.is_empty():
		_wanted[-1] = true
	return _wanted


var _wanted: Dictionary = {}
var _wanted_for: Dictionary = {}


## The exact derivatives against finite differences at q: the largest
## difference, for a probe.
func jacobian_error() -> float:
	var exact: Array = _jacobian(q, {})
	var base: PackedFloat64Array = _residual(q, {})
	var worst: float = 0.0
	# Transforms are single precision: a step of 1e-3 keeps the difference
	# well above their rounding.
	for c: int in cols:
		var up: PackedFloat64Array = q.duplicate()
		var down: PackedFloat64Array = q.duplicate()
		up[c] += 1e-3
		down[c] -= 1e-3
		var r_up: PackedFloat64Array = _residual(up, {})
		var r_down: PackedFloat64Array = _residual(down, {})
		for k: int in base.size():
			var numeric: float = (r_up[k] - r_down[k]) / 2e-3
			var off: float = absf(numeric - (exact[k] as PackedFloat64Array)[c])
			if off > worst:
				worst = off
				_worst_said = "column %d row %d: exact %.4f, numeric %.4f" % [c, k,
					(exact[k] as PackedFloat64Array)[c], numeric]
	return worst


var _worst_said: String = ""


func jacobian_said() -> String:
	return _worst_said


static func _worst(r: PackedFloat64Array) -> float:
	var out: float = 0.0
	for value: float in r:
		out = maxf(out, absf(value))
	return out


## The joints of a loop's gear chains that hold by friction (a gear on a
## friction pin), each but the driver's: column -> true. Where the loop has
## more freedom than its driver takes up, they move least and the free ones
## take it, as the parts would: a telescope's cradle tilted on the axle of a
## pinion that a gear chain with a friction pin holds rolls its rack along
## the pinion, 8 LDU for 45° (docs/MECHANISMS.md, section 27). Least squares
## over every joint alike turned the chain half way and slid the rack half.
## Damped [constant FRICTION_WEIGHT] times as hard in each step ([method
## _close_with]): a loop with no freedom to spare closes where it did. Only a
## gear chain's: a steering's hinges held so, its column slid along its axle
## off its rack (8808-1, 8054-1).
var _friction: Dictionary = {}
const FRICTION_WEIGHT := 1000.0
## An axle's slide along its hole (column -> true), damped [constant
## SLIDE_WEIGHT] times as hard as a turn; a friction bearing then
## [constant FRICTION_WEIGHT] times as hard as that. A slide the loop does
## not need is its freedom to spare, and the least change of a step still
## moved some of it: at 30, 8448-1's column slid along its pinion's axle
## 0.13 LDU on a turn of 30° and came back 0.20 LDU off, and 42125-1's
## suspension arms slid 0.1 to 0.26 LDU, into the parts flush beside them.
## At 1000 neither moves (8448-1 back 0.008, 42125-1 0.007), and a slide the
## loop needs (8256-1's, 8880-1's) moves as before.
var _sliding: Dictionary = {}
const SLIDE_WEIGHT := 1000.0
## An axle's slide in what carries it, where a part of the loop slides along
## it too (column -> true): damped as a friction bearing is.
var _carried: Dictionary = {}


## How hard a step's solve and its least change damp column [param c],
## a turn's being 1.
func _weight(c: int) -> float:
	if _friction.has(c) or _carried.has(c):
		return FRICTION_WEIGHT * (SLIDE_WEIGHT if not _sliding.is_empty() else 1.0)
	return SLIDE_WEIGHT if _sliding.has(c) else 1.0


## Close the loops with the driver held at q[driver_col], from q as it is.
## True when every closing joint meets to CLOSE_TO.
func _close() -> bool:
	# What carries the driver held where it is first: a steering column
	# turned in a cab of hinges turns its gears, and the cab does not tilt
	# for it, as a hand on the wheel finds. Least squares over every joint
	# shared the column's turn between its pinion and the cab's hinges (8062-1:
	# 10.7° of 30). Where the loop cannot close so (a wheel turned on its
	# steering arm carries the arm's kingpin with it), every joint is free
	# again, for the rest of this grab.
	if _try_held and not _carrying.is_empty():
		var from: PackedFloat64Array = q.duplicate()
		if _close_with(_carrying):
			return true
		q = from
		# Freed, it closes: it needed what carries the driver to move. Not
		# even freed: the loop's own stop, and it is held again next time.
		if _close_with({}):
			_try_held = false
			return true
		return false
	return _close_with({})


## Whether the loop closes with the joints of columns [param held] kept
## where they are, as _close says.
var _try_held: bool = true
## The columns of the joints that carry the driver's joint: from the anchor
## to what the driver turns in.
var _carrying: Dictionary = {}


func _close_with(held: Dictionary) -> bool:
	solves += 1
	var cache: Dictionary = {}
	var r: PackedFloat64Array = _residual(q, cache)
	var now: float = _worst(r)
	var lam: float = 1e-3
	iterations = 0
	# The columns solved for, and where each is among them (-1: held).
	var free := PackedInt32Array()
	var where := PackedInt32Array()
	where.resize(cols)
	for c: int in cols:
		if c != driver_col and not _still.has(c) and not held.has(c) and not _hold_also.has(c):
			where[c] = free.size()
			free.append(c)
		else:
			where[c] = -1
	var n: int = free.size()
	# Closed to a fifth of the tolerance, so the last step stands well inside
	# it; a step on the way only to within it. A session's, or back where it
	# was built, on as long as each round takes a tenth off what is left, to
	# [constant CLOSE_FINE] ([member fine], [member _fine]).
	var aim: float = _tolerance * 0.2 if _tolerance == CLOSE_TO else _tolerance
	var fine_to: float = CLOSE_FINE if (fine or _fine) and _tolerance == CLOSE_TO else aim
	var gaining: bool = true
	var at_row := PackedInt32Array()
	var of_row := PackedFloat64Array()
	while (now > aim or now > fine_to and gaining) and iterations < ITERATIONS and n > 0:
		iterations += 1
		var jac: Array = _jacobian(q, cache)
		# Normal equations: (JᵀJ + λ diag) dq = −Jᵀr, from each row's few
		# columns that are not nought: a loop's row is moved only by the
		# joints on the way to its two ends.
		var a := PackedFloat64Array()
		a.resize(n * n)
		a.fill(0.0)
		var g := PackedFloat64Array()
		g.resize(n)
		g.fill(0.0)
		for k: int in jac.size():
			var line: PackedFloat64Array = jac[k]
			at_row.resize(0)
			of_row.resize(0)
			for c: int in cols:
				var v: float = line[c]
				if v != 0.0 and where[c] >= 0:
					at_row.append(where[c])
					of_row.append(v)
			var rk: float = r[k]
			var m: int = at_row.size()
			for u: int in m:
				var i: int = at_row[u]
				var vi: float = of_row[u]
				g[i] += vi * rk
				var base: int = i * n
				for w: int in m:
					a[base + at_row[w]] += vi * of_row[w]
		var stepped: bool = false
		# A bounded slide at its end that the step would take further out is
		# held there for the step, and the rest solved without it; one the
		# step takes past its end stops at it.
		var pinned: Dictionary = {}   ## index among the free -> true
		var tries: int = 0
		while tries < 6:
			var m2: PackedFloat64Array = a.duplicate()
			var g2: PackedFloat64Array = g
			for i: int in n:
				m2[i * n + i] += lam * maxf(a[i * n + i], 1.0) * _weight(free[i]) + 1e-9
			if not pinned.is_empty():
				g2 = g.duplicate()
				for i: int in pinned:
					for k: int in n:
						m2[i * n + k] = 0.0
						m2[k * n + i] = 0.0
					m2[i * n + i] = 1.0
					g2[i] = 0.0
			var factored: bool = Linkage._factor(m2, n)
			if not factored:
				lam *= 10.0
				tries += 1
				continue
			var dq: PackedFloat64Array = Linkage._solve_factored(m2, n, g2)
			var trial: PackedFloat64Array = q.duplicate()
			var held_more: bool = false
			for i: int in n:
				var c: int = free[i]
				trial[c] -= dq[i]
				if _bounded.has(c):
					var span: Vector2 = _limits[c]
					if trial[c] < span.x or trial[c] > span.y:
						if (trial[c] < span.x and q[c] <= span.x + 1e-9 or trial[c] > span.y and q[c] >= span.y - 1e-9) \
								and not pinned.has(i):
							pinned[i] = true
							held_more = true
						trial[c] = clampf(trial[c], span.x, span.y)
			if held_more:
				continue
			tries += 1
			var trial_cache: Dictionary = {}
			var tr: PackedFloat64Array = _residual(trial, trial_cache)
			var then: float = _worst(tr)
			if then < now:
				gaining = then < now * 0.9
				q = trial
				r = tr
				now = then
				cache = trial_cache
				lam = maxf(lam * 0.3, 1e-7)
				stepped = true
				break
			lam *= 10.0
		if not stepped:
			break
	residual = now
	last_residual = r
	return now <= _tolerance


## [param m] (n by n, row by row; symmetric and positive definite, as JᵀJ
## with λ on its diagonal is) factored in place by Cholesky's method, its
## lower triangle L with L Lᵀ = m. False where a pivot is not above 1e-12.
## Half the work of elimination with pivoting, on a flat array rather than
## rows copied.
static func _factor(m: PackedFloat64Array, n: int) -> bool:
	for j: int in n:
		var row_j: int = j * n
		var d: float = m[row_j + j]
		for k: int in j:
			d -= m[row_j + k] * m[row_j + k]
		if d <= 1e-12:
			return false
		d = sqrt(d)
		m[row_j + j] = d
		for i: int in range(j + 1, n):
			var row_i: int = i * n
			var sum: float = m[row_i + j]
			for k: int in j:
				sum -= m[row_i + k] * m[row_j + k]
			m[row_i + j] = sum / d
	return true


## x with L Lᵀ x = [param b], L as [method _factor] leaves it in [param l].
static func _solve_factored(l: PackedFloat64Array, n: int, b: PackedFloat64Array) -> PackedFloat64Array:
	var y := PackedFloat64Array()
	y.resize(n)
	for i: int in n:
		var sum: float = b[i]
		var row_i: int = i * n
		for k: int in i:
			sum -= l[row_i + k] * y[k]
		y[i] = sum / l[row_i + i]
	var x := PackedFloat64Array()
	x.resize(n)
	for i: int in range(n - 1, -1, -1):
		var sum: float = y[i]
		for k: int in range(i + 1, n):
			sum -= l[k * n + i] * x[k]
		x[i] = sum / l[i * n + i]
	return x


# -- driving it ------------------------------------------------------------------------


## The driver's value in the pose last kept.
func kept_value() -> float:
	return kept[driver_col]


## Solve for the driver at [param value], from the pose last kept, in steps;
## where it cannot close, q stays at the furthest value that does (bisected
## to a fiftieth of a step). Returns that value.
func reach(value: float) -> float:
	# Asked again from the same pose kept, for the same value or for where it
	# got to: a frame asks once for how far the loop goes and again for the
	# pose there (Grab.slide_to, then transforms_at), and solved it twice.
	# And asked further the same way than it got, where it got short: it stops
	# where it stopped (a rod drawn on past the end of its stroke).
	var further: bool = _memo_got != _memo_asked and signf(value - _memo_got) == signf(_memo_asked - _memo_got) \
		and absf(value - kept[driver_col]) >= absf(_memo_got - kept[driver_col])
	if _memo_keep == _keeps and _memo_col == driver_col and not _memo_q.is_empty() \
			and (value == _memo_asked or value == _memo_got or further):
		q = _memo_q.duplicate()
		_gear_kept = _memo_gears.duplicate(true)
		return _memo_got
	var got: float = _reach(value)
	_memo_keep = _keeps
	_memo_col = driver_col
	_memo_asked = value
	_memo_got = got
	_memo_q = q.duplicate()
	_memo_gears = _gear_kept.duplicate(true)
	return got


## The last [method reach]: from which pose kept ([member _keeps] then),
## driving which column, asked what, got where, and the pose and gears' turns
## it left.
var _keeps: int = 0
var _memo_keep: int = -1
var _memo_col: int = -1
var _memo_asked: float = NAN
var _memo_got: float = NAN
var _memo_q := PackedFloat64Array()
var _memo_gears: Array = []


func _reach(value: float) -> float:
	q = kept.duplicate()
	_gear_kept = _gear_at_keep.duplicate(true)
	var from: float = q[driver_col]
	var step: float = STEP_SLIDE if is_slide() else STEP_TURN
	var count: int = maxi(1, ceili(absf(value - from) / step))
	if _slope_col == driver_col and _slope.size() == cols:
		# As many steps as keep the fastest turning coordinate within a step.
		var fastest: float = 0.0
		for c: int in _turning:
			fastest = maxf(fastest, absf(_slope[c]))
		count = clampi(ceili(fastest * absf(value - from) / MOST_TURN_STEP), count, maxi(count, MOST_STEPS))
	var parted: Array = _spinning_part(absf(value - from))
	if not parted.is_empty():
		_part_found = parted
		_part_col = driver_col
	elif _part_col == driver_col and not _part_found.is_empty() and absf(value - from) > 1e-6:
		# Found once, the part stays the part: which joints spin on their own
		# is the loop's shape, and the slope read on the last step can be
		# read where they turn slowly.
		parted = _part_found
	if not parted.is_empty():
		var got: Variant = _reach_parted(value, parted)
		if got != null:
			return float(got)
		q = kept.duplicate()
		_gear_kept = _gear_at_keep.duplicate(true)
	var good: float = from
	var good_q: PackedFloat64Array = q.duplicate()
	# The furthest step closed all the way, to CLOSE_TO, where those on the
	# way closed only to ON_THE_WAY; and the gears' turns there.
	var sure: float = from
	var sure_q: PackedFloat64Array = q.duplicate()
	var sure_gears: Array = _gear_kept.duplicate(true)
	for n: int in range(1, count + 1):
		var at: float = lerpf(from, value, float(n) / float(count))
		_tolerance = CLOSE_TO if n == count else ON_THE_WAY
		var closed: bool = n == count and _closes_built(at, good_q) or _closes_at(at, good, good_q)
		_tolerance = CLOSE_TO
		if closed:
			_follow_slope(at, good, good_q)
			good = at
			good_q = q.duplicate()
			# The gears' turns unwrapped against this step's, not the first's:
			# a worm turns many times over in one drag.
			_keep_gear_turns(q)
			if residual <= CLOSE_TO:
				sure = at
				sure_q = good_q
				sure_gears = _gear_kept.duplicate(true)
			continue
		# Short of it: the furthest that closes between the last good and here.
		var low: float = good
		var high: float = at
		var closed_past: bool = false
		for _round: int in 7:
			var middle: float = (low + high) * 0.5
			if _closes_at(middle, low, good_q):
				_follow_slope(middle, low, good_q)
				low = middle
				good_q = q.duplicate()
				_keep_gear_turns(q)
				closed_past = true
			else:
				high = middle
		if not closed_past and low != sure:
			# Kept where a step on the way left it, the loop stays open there,
			# and the next move starts with the gap ([method _from_built]):
			# 5533-1's steering turned 25° with a pin 0.24 LDU out of its
			# rack's hole, and from there no turn closed. Closed all the way
			# there, or back to the furthest step that was (Grab 22's).
			if _closes_at(low, low, good_q):
				good_q = q.duplicate()
				_keep_gear_turns(q)
			else:
				low = sure
				good_q = sure_q
				_gear_kept = sure_gears.duplicate(true)
				high = good
				for _round: int in 7:
					var middle: float = (low + high) * 0.5
					if _closes_at(middle, low, good_q):
						_follow_slope(middle, low, good_q)
						low = middle
						good_q = q.duplicate()
						_keep_gear_turns(q)
					else:
						high = middle
		q = good_q
		return low
	q = good_q
	return good


## The part of the loops that spins on its own, as last found, and for which
## driving column ([method _spinning_part]); how many steps a unit of the
## driver its last solve took.
var _part_found: Array = []
var _part_col: int = -1
var _part_rate: float = 0.0
## How each coordinate goes with the driver where the last step closed, per
## unit of the driver's ([method _tangent]), and for which column: where the
## next step starts from. A small actuator's input turns 2 radians for each LDU its rod
## goes, and what it drives by a universal joint with it (42024-1): started
## where the last step left them, each 4 LDU step began 8 radians out, and
## one in five took 24 rounds and still did not close, stopping the drag
## there for a frame.
var _slope := PackedFloat64Array()
var _slope_col: int = -1
## The columns that turn: not slides, not held still.
var _turning := PackedInt32Array()
## What a close closes to: [constant CLOSE_TO], or on the way
## [constant ON_THE_WAY].
var _tolerance: float = CLOSE_TO


## Whether the loops close with the driver at [param at], from the pose
## [param from_q] that closed with it at [param from]: first from there moved
## on along [member _slope], then, failing that, from there as it is. Leaves
## q where it closed.
func _closes_at(at: float, from: float, from_q: PackedFloat64Array, but: Dictionary = {},
		only: Dictionary = {}) -> bool:
	if _slope_col == driver_col and _slope.size() == cols:
		q = from_q.duplicate()
		var by: float = at - from
		for c: int in cols:
			if c != driver_col and not _still.has(c) and not (_try_held and _carrying.has(c)) \
					and not but.has(c) and (only.is_empty() or only.has(c)):
				q[c] += _slope[c] * by
				if _bounded.has(c):
					q[c] = clampf(q[c], (_limits[c] as Vector2).x, (_limits[c] as Vector2).y)
		q[driver_col] = at
		if _close() and _within():
			return true
	q = from_q.duplicate()
	q[driver_col] = at
	return _close() and _within()


## A part of the loops that spins on its own: the columns that turn faster
## than a step should for a move of [param span], the constraints they move,
## and every column that moves only those. [rows (Dictionary), columns
## (Dictionary)], or empty when there is no such part, or it is all of it.
## A small actuator's input and what it drives by a universal joint turn 2 to
## 4 radians for each LDU its rod goes (42024-1): the rest of the loop could
## be solved in a step where they took twenty, and it does not move them.
func _spinning_part(span: float) -> Array:
	if _slope_col != driver_col or _slope.size() != cols or span <= 0.0:
		return []
	var rows: Dictionary = {}
	var fast: int = 0
	for c: int in _turning:
		if absf(_slope[c]) * span > MOST_TURN_STEP * 2.0 and not (_try_held and _carrying.has(c)):
			fast += 1
			for k: Variant in _moves_rows.get(c, {}):
				rows[k] = true
	if fast == 0 or rows.is_empty():
		return []
	var part: Dictionary = {}
	var rest: int = 0
	for c: int in cols:
		if c == driver_col or _still.has(c):
			continue
		var moves: Dictionary = _moves_rows.get(c, {})
		var inside: bool = not moves.is_empty()
		for k: Variant in moves:
			if not rows.has(k):
				inside = false
				break
		if inside:
			part[c] = true
		else:
			rest += 1
	# Every fast column in it, and something left to solve first.
	for c: int in _turning:
		if absf(_slope[c]) * span > MOST_TURN_STEP * 2.0 and not part.has(c) \
				and not (_try_held and _carrying.has(c)):
			return []
	if part.is_empty() or rest == 0:
		return []
	return [rows, part]


## [method _reach] in two: the loops but [param parted]'s part first, with
## its columns held and its constraints left out, in the steps the rest
## needs; then the part, the rest held, in the steps it needs, the rest drawn
## along between where it stood and where it now stands. Null where either
## does not close all the way (then the whole is solved together, as before).
func _reach_parted(value: float, parted: Array) -> Variant:
	var rows: Dictionary = parted[0]
	var part: Dictionary = parted[1]
	var from: float = q[driver_col]
	var span: float = absf(value - from)
	var step: float = STEP_SLIDE if is_slide() else STEP_TURN
	# The rest.
	var count: int = maxi(1, ceili(span / step))
	var fastest: float = 0.0
	for c: int in _turning:
		if not part.has(c):
			fastest = maxf(fastest, absf(_slope[c]))
	count = clampi(ceili(fastest * span / MOST_TURN_STEP), count, maxi(count, MOST_STEPS))
	_rows_off = rows
	_hold_also = part
	var good: float = from
	var good_q: PackedFloat64Array = q.duplicate()
	for n: int in range(1, count + 1):
		var at: float = lerpf(from, value, float(n) / float(count))
		_tolerance = CLOSE_TO if n == count else ON_THE_WAY
		var closed: bool = _closes_at(at, good, good_q, part)
		_tolerance = CLOSE_TO
		if closed:
			_follow_slope(at, good, good_q, part, false)
			good = at
			good_q = q.duplicate()
			_keep_gear_turns(q)
			continue
		# Short of it (a rod past the end of its stroke): the furthest that
		# closes between the last good and here, as _reach has it.
		var low: float = good
		var high: float = at
		for _round: int in 7:
			var middle: float = (low + high) * 0.5
			if _closes_at(middle, low, good_q, part):
				low = middle
				good_q = q.duplicate()
				_keep_gear_turns(q)
			else:
				high = middle
		good = low
		break
	_rows_off = {}
	_hold_also = {}
	if good == from:
		# The rest closes no further: nor does the whole, which asks more of
		# it. The part stays where it was kept.
		q = kept.duplicate()
		_gear_kept = _gear_at_keep.duplicate(true)
		return from
	value = good
	# The part, the rest drawn along.
	var rest_from: PackedFloat64Array = kept.duplicate()
	var rest_to: PackedFloat64Array = good_q.duplicate()
	fastest = 0.0
	for c: Variant in part:
		fastest = maxf(fastest, absf(_slope[int(c)]))
	# A slope read where a universal joint's cross turns fastest asked for
	# 168 steps; more than MOST_STEPS only where these do not close. Nor
	# fewer than half as many a unit as the last time it closed.
	count = clampi(maxi(ceili(fastest * span / MOST_TURN_STEP), ceili(_part_rate * span * 0.5)), 1, MOST_STEPS)
	var off: Dictionary = {}
	for k: int in closing.size():
		if not rows.has(k):
			off[k] = true
	for k: int in racks.size():
		if not rows.has(RACK_ROWS + k):
			off[RACK_ROWS + k] = true
	for k: int in _gear_ends.size():
		if not rows.has(GEAR_ROWS + k):
			off[GEAR_ROWS + k] = true
	var held: Dictionary = {}
	for c: int in cols:
		if not part.has(c):
			held[c] = true
	_rows_off = off
	_hold_also = held
	var gears_from: Array = _gear_kept.duplicate(true)
	var ok: bool = false
	# Where the steps were too few for how fast the part turned just then
	# (its slope read at a slow moment of a universal joint's turn), four
	# times as many, before the whole is solved together.
	for steps: int in [count, mini(count * 4, MOST_STEPS * 4)]:
		var was: float = from
		var was_q: PackedFloat64Array = kept.duplicate()
		_gear_kept = gears_from.duplicate(true)
		ok = true
		for n: int in range(1, steps + 1):
			var share: float = float(n) / float(steps)
			var at: float = lerpf(from, value, share)
			var start: PackedFloat64Array = was_q.duplicate()
			for c: int in cols:
				if not part.has(c):
					start[c] = lerpf(rest_from[c], rest_to[c], share)
			_tolerance = CLOSE_TO if n == steps else ON_THE_WAY
			var closed: bool = _closes_at(at, was, start, {}, part)
			_tolerance = CLOSE_TO
			if not closed:
				ok = false
				break
			_follow_slope(at, was, was_q, part, true)
			was = at
			was_q = q.duplicate()
			_keep_gear_turns(q)
		if ok:
			_part_rate = float(steps) / maxf(span, 1e-6)
			break
		if steps == MOST_STEPS * 4:
			break
	_rows_off = {}
	_hold_also = {}
	if not ok:
		return null
	# Both closed: the whole, to be sure.
	var whole: float = _worst(_residual(q, {}))
	if whole > CLOSE_TO or not _within():
		return null
	return value


## The slope of each coordinate over a step from [param from] (the pose
## [param from_q]) to [param at], where q now closes.
func _follow_slope(at: float, from: float, from_q: PackedFloat64Array, part: Dictionary = {},
		inside: bool = false) -> void:
	var by: float = at - from
	if absf(by) < 1e-6:
		return
	if _slope.size() != cols or _slope_col != driver_col:
		_slope.resize(cols)
		_slope.fill(0.0)
		_slope_col = driver_col
	var tangent: PackedFloat64Array = _tangent(signf(by)) if part.is_empty() else PackedFloat64Array()
	for c: int in cols:
		# A part solved apart keeps its own slope, and the rest theirs.
		if not part.is_empty() and part.has(c) != inside:
			continue
		_slope[c] = tangent[c] if not tangent.is_empty() else (q[c] - from_q[c]) / by


## How each coordinate goes with the driver where q stands, per unit of the
## driver's: the least change that keeps the loops closed, weighted as a step
## weighs it ([method _close_with]); empty where it cannot be read. Read off
## the step just taken, the slope carried whatever that step's solve moved
## in the loop's freedom to spare (a column's slide along its axle), and the
## next step moved it again: turned +30, -60 and +30 at its wheel, 8448-1's
## steering column came back slid 1.58 LDU along its pinion's axle (0.21
## so), and 8808-1's wheel turned 90, -180 and 90 came back 1.78 LDU off
## (0.003 so; docs/MECHANISMS.md, sections 28 and 30). Only the part solved
## apart ([method _reach_parted]) keeps the step's own.
func _tangent(way: float) -> PackedFloat64Array:
	var held: Dictionary = (_carrying if _try_held else {}).duplicate()
	var jac: Array = _jacobian(q, {})
	# A slide at its end that the change would take further out is held
	# there, as a step's solve holds it, and the rest found without it.
	for _round: int in 4:
		var out: PackedFloat64Array = _least_change(jac, held)
		if out.is_empty():
			return out
		var more: bool = false
		for c: int in _bounded:
			var span: Vector2 = _limits[c]
			if not held.has(c) and (q[c] <= span.x + 1e-9 and out[c] * way < 0.0
					or q[c] >= span.y - 1e-9 and out[c] * way > 0.0):
				held[c] = true
				more = true
		if not more:
			return out
	return PackedFloat64Array()


## The least change of [method _tangent] with the columns [param held] kept
## where they are, from the loop's derivatives [param jac] where q stands.
func _least_change(jac: Array, held: Dictionary) -> PackedFloat64Array:
	var free := PackedInt32Array()
	var where := PackedInt32Array()
	where.resize(cols)
	for c: int in cols:
		if c != driver_col and not _still.has(c) and not held.has(c) and not _hold_also.has(c):
			where[c] = free.size()
			free.append(c)
		else:
			where[c] = -1
	var n: int = free.size()
	if n == 0:
		return PackedFloat64Array()
	# (JᵀJ + μ W) v = −Jᵀ j, j the driver's column: as μ goes to nought, the
	# change of least weight that leaves every row where it is.
	var a := PackedFloat64Array()
	a.resize(n * n)
	a.fill(0.0)
	var g := PackedFloat64Array()
	g.resize(n)
	g.fill(0.0)
	var at_row := PackedInt32Array()
	var of_row := PackedFloat64Array()
	for line: PackedFloat64Array in jac:
		at_row.resize(0)
		of_row.resize(0)
		for c: int in cols:
			if line[c] != 0.0 and where[c] >= 0:
				at_row.append(where[c])
				of_row.append(line[c])
		var driven: float = line[driver_col]
		for u: int in at_row.size():
			var i: int = at_row[u]
			g[i] += of_row[u] * driven
			for w: int in at_row.size():
				a[i * n + at_row[w]] += of_row[u] * of_row[w]
	for i: int in n:
		a[i * n + i] += 1e-6 * maxf(a[i * n + i], 1.0) * _weight(free[i]) + 1e-12
	if not Linkage._factor(a, n):
		return PackedFloat64Array()
	var v: PackedFloat64Array = Linkage._solve_factored(a, n, g)
	var out := PackedFloat64Array()
	out.resize(cols)
	out.fill(0.0)
	for i: int in n:
		out[free[i]] = -v[i]
	out[driver_col] = 1.0
	return out


## Whether every actuator's and cylinder's rod is within its stroke as q
## stands: drawn out no further than the part goes, nor in.
func _within() -> bool:
	for c: int in _limits:
		var span: Vector2 = _limits[c]
		if q[c] < span.x - 0.01 or q[c] > span.y + 0.01:
			return false
	# Nor a pinion carried past its rack's last tooth, where the next move's
	# reading would find it out of the rack (Racks.find) and the loop no
	# longer held by it: 8466-1's steering, turned -23°, carried its end
	# pinion 4.09 LDU past the last tooth, and the turn back turned that
	# pinion alone on its pin, leaving the rest where it was.
	if not _rack_room.is_empty():
		var cache: Dictionary = {}
		for k: int in racks.size():
			var room: Vector2 = _rack_room[k]
			if is_inf(room.x) and is_inf(room.y):
				continue
			var ends: Array = _rack_ends[k]
			var mesh: Racks.Pinion = racks[k]
			var seen: Vector3 = _place(int(ends[1]), q, cache).affine_inverse() \
				* (_place(int(ends[0]), q, cache) * mesh.centre)
			var went: float = mesh.line.dot(seen - mesh.centre)
			if went < minf(room.x + 0.01, 0.0) or went > maxf(room.y - 0.01, 0.0):
				return false
	return true


## How far the slide in column [param c] may go, from where it stood:
## Vector2(least, most), or INF both ways where nothing but the loop limits
## it.
func limits_of(c: int) -> Vector2:
	return _limits.get(c, Vector2(-INF, INF))


## Keep the pose q stands in as where the next move starts.
func keep() -> void:
	_keeps += 1
	kept = q.duplicate()
	_keep_gear_turns(q)
	_gear_at_keep = _gear_kept.duplicate(true)


## The gears' turns in the pose last kept (_gear_kept, as keep() left it).
var _gear_at_keep: Array = []


## Everything a solve leaves behind, to come back to ([method restore_kept]):
## the pose kept, where q stands, the last solve remembered, the slope the
## next solve starts from and the part that spins on its own. A move tested a
## step at a time (Grab._walk) keeps each step to solve the next from it, and
## then puts all of it back, so where the move ends is solved as if there
## were no steps (G13b). Kept step by step, fourteen sets' steering, turned
## out and back, came back 0.03 to 0.19 LDU off; with the pose put back but
## the slope left as the steps had it, 0.5 LDU.
func kept_state() -> Array:
	return [kept.duplicate(), _gear_at_keep.duplicate(true), _keeps, q.duplicate(), _gear_kept.duplicate(true),
		_memo_keep, _memo_col, _memo_asked, _memo_got, _memo_q.duplicate(), _memo_gears.duplicate(true),
		_slope.duplicate(), _slope_col, _part_found.duplicate(true), _part_col, _part_rate]


## Put back [param state] ([method kept_state]), as if nothing since.
func restore_kept(state: Array) -> void:
	kept = (state[0] as PackedFloat64Array).duplicate()
	_gear_at_keep = (state[1] as Array).duplicate(true)
	_keeps = int(state[2])
	q = (state[3] as PackedFloat64Array).duplicate()
	_gear_kept = (state[4] as Array).duplicate(true)
	_memo_keep = int(state[5])
	_memo_col = int(state[6])
	_memo_asked = float(state[7])
	_memo_got = float(state[8])
	_memo_q = (state[9] as PackedFloat64Array).duplicate()
	_memo_gears = (state[10] as Array).duplicate(true)
	_slope = (state[11] as PackedFloat64Array).duplicate()
	_slope_col = int(state[12])
	_part_found = (state[13] as Array).duplicate(true)
	_part_col = int(state[14])
	_part_rate = float(state[15])


## Whether the driver can move at all: the loop closes a little way one way
## or the other. A loop held rigid (a triangle of beams, a four-bar with a
## friction-free joint pinned twice) closes neither way.
func can_move() -> bool:
	if _moves():
		return true
	# Held from turning, but free to slide: a scissor lift's foot on its rail
	# cannot turn about the rail, and slides along it. Driven by its slide.
	if not is_slide() and drive_slide():
		if _moves():
			return true
		driver_col = turn_col[0]
	return false


func _moves() -> bool:
	var step: float = FREEDOM_SLIDE if is_slide() else FREEDOM_TURN
	for way: float in [1.0, -1.0]:
		var got: float = reach(kept_value() + way * step)
		if absf(got - kept_value()) > step * 0.5:
			q = kept.duplicate()
			return true
	q = kept.duplicate()
	return false


## Each moved body's place as q stands: body -> Transform3D.
func places() -> Dictionary:
	var cache: Dictionary = {}
	var out: Dictionary = {}
	for body: int in moved:
		out[body] = _place(body, q, cache)
	return out


## Every part that moves where q puts it: brick id -> Transform3D, given
## where each stood ([param rest]).
func transforms(rest: Dictionary) -> Dictionary:
	var at: Dictionary = places()
	var out: Dictionary = {}
	for body: int in moved:
		var move: Transform3D = at[body]
		for key: int in bodies.members.get(body, PackedInt64Array()):
			if rest.has(key):
				out[key] = move * (rest[key] as Transform3D)
	return out


## How high the centre of mass of what the loop moves stands, LDU, LDraw's
## y down: larger is lower.
func centre_y() -> float:
	var at: Dictionary = places()
	var weight: float = 0.0
	var sum: float = 0.0
	for body: int in moved:
		var g: float = _grams[body]
		weight += g
		sum += ((at[body] as Transform3D) * (_centre[body] as Vector3)).y * g
	return sum / maxf(weight, 0.000001)


## Each joint's coordinate, in words, for a probe: "#12 turned 31.2°".
func coordinate(n: int) -> float:
	return q[turn_col[n]]


func slide_of(n: int) -> float:
	return q[slide_col[n]] if slide_col[n] >= 0 else 0.0


## "a four-bar's 4 joints" — what the loop is, said.
func said() -> String:
	var kinds: Dictionary = {}
	for link: Bodies.Link in links:
		kinds[link.kind] = int(kinds.get(link.kind, 0)) + 1
	for link: Bodies.Link in closing:
		kinds[link.kind] = int(kinds.get(link.kind, 0)) + 1
	var parts := PackedStringArray()
	for kind: String in kinds:
		parts.append("%d %s" % [int(kinds[kind]), kind])
	# "a loop of 1 joints (1 axle), closed by 0 and a 8 tooth pinion in rack
	# 3743" was a pinion's axle and its rack, said to a session.
	var count: int = links.size() + closing.size()
	var closers := PackedStringArray()
	if not closing.is_empty():
		closers.append("%d of them" % closing.size())
	if not gear_meshes.is_empty():
		closers.append("%d gear mesh%s" % [gear_meshes.size(), "" if gear_meshes.size() == 1 else "es"])
	for mesh: Racks.Pinion in racks:
		closers.append(mesh.said(bodies.world))
	return "a loop of %d joint%s (%s)%s" % [count, "" if count == 1 else "s", ", ".join(parts),
		(", closed by " + " and ".join(closers)) if not closers.is_empty() else ""]
