## A section let go on joints that do not hold swings under its weight, as
## the real one does: down, past the bottom and back, a little less each time
## as the joint's friction takes its share, until it hangs still. A chain of
## such joints (an arm on two free pins) swings as a double pendulum.
##
## The parts are rigid segments, one a free joint, on a tree of those joints
## (Bodies' tree), each joint a line it turns about. The equations of motion
## are Newton-Euler's, written in the joints' turns (Lagrange's form):
## M(q) q'' = Q(q, q'), the mass matrix M and the forces Q from each segment's
## mass, centre and moment of inertia, gravity and the velocity terms (a
## swinging outer arm pulls on the inner one). Integrated at a fixed step
## of 1 ms by semi-implicit Euler, which keeps a pendulum's energy from
## growing as an explicit step would: its period at this step is off by under
## one part in ten thousand for anything a person can build.
##
## What it is made of, and how sure each is (docs/MECHANISMS.md §14):
##   mass     Stability.grams: a part's walls, studs and tubes, within 6% of
##            BrickLink's weighings for common bricks; a mean figure, not
##            the part's own.
##   inertia  each part's mass spread evenly through its box. A brick's
##            mass is mostly in its walls, so its own share is low by up to
##            a third; for a section a few studs out from its joint that
##            share is a few per cent of the whole.
##   friction a pin or an axle turning in its hole is a journal bearing: a
##            torque of μ r N, against the turn. r is 2.4 mm (a Technic
##            hole's 4.8 mm, a stud's too); N the weight it carries; μ for
##            ABS on ABS is not published, and ABS against steel and
##            printed ABS on a pin-on-disc read 0.2 to 0.4 (Ramadan et al.
##            2023, tribology.rs), so μ is taken as 0.3 within that range.
##            The rub of a beam's face on the beam beside it is not counted
##            (nothing says how hard a pin's collar presses them), so a real
##            arm may stop sooner than this one.
##   stops    the room test (Grab's), each time the furthest moving point
##            has gone 4 LDU since the last, and bisected where it meets
##            something: there it stops dead. How much a section of bricks
##            bounces off another is not measured, so it does not bounce.
##   rest     when no joint has moved for 0.12 s (its furthest point under
##            0.2 mm/s): held by its friction
##            within asin(μ r / d) of hanging straight (d its centre of
##            mass's distance from the line), or pressed against what
##            stopped it.
##
## Let go while it moves (a fling, [method fling]), it starts at the rate the
## pointer gave it and coasts: a wheel on its axle or a turntable spins on,
## slowing against its bearing's friction. A gear train the grabbed joint
## drives is part of the motion as geared segments ([method add_geared]): each
## gear turns about its own line at the train's ratio, so its inertia counts
## as the ratio squared and its bearing's friction as the ratio, as a gear
## train's reflected inertia and losses do. Its own losses in the teeth are
## not counted (docs/MECHANISMS.md §16).
## Pure but for the room test it is handed.
class_name Swing
extends RefCounted

## Gravity, LDU/s²: 9.81 m/s² at 0.4 mm an LDU.
const GRAVITY := 24525.0
## The fixed step, s.
const STEP := 0.001
## μ for a pin or an axle in its hole, and the range it is taken from.
const MU := 0.3
const MU_LOW := 0.2
const MU_HIGH := 0.4
## A pin's, an axle's or a stud's radius where it bears in its hole, LDU
## (2.4 mm).
const BEARING := 6.0
## The furthest moving point goes at most this far between room tests, LDU.
const TEST_LDU := 4.0
## Bisection rounds where a step meets something.
const ROUNDS := 7
## No joint moving for this long, s: at rest.
const STILL_S := 0.12
## Moving: the furthest point of what a joint carries going faster than
## this, LDU/s (0.2 mm/s). Several joints' friction, solved together, leaves
## rates of 1e-17 rather than nought.
const STILL_SPEED := 0.5
## At most this long, s: past it, it is kept where it is.
const MOST_S := 40.0
## [method run] works it out for at most this long by the clock, ms: a
## session's move_part waits on it, and the window with it. Each room test
## of a 126-part motorcycle cost about 100 ms, so 40 s of its swing, tested
## at every step, would have taken an hour.
const RUN_MOST_MS := 8000.0
## Projected Gauss-Seidel rounds for the friction of several joints.
const FRICTION_ROUNDS := 16


class Joint extends RefCounted:
	var point := Vector3.ZERO
	var axis := Vector3.UP
	## The joint that carries this one's line, -1 for what stands.
	var parent: int = -1
	## Every joint from this one in to the root, this one first.
	var chain := PackedInt32Array()
	## Grams carried, everything beyond it.
	var grams: float = 0.0
	## What its friction acts on, reflected to its turn, g·LDU: the grams it
	## carries times its [member bearing], and each geared segment's grams
	## times a pin's bearing and its ratio (a gear's own axle carries it,
	## turning ratio times as fast).
	var load: float = 0.0
	## Where it bears, its radius, LDU: a pin's or an axle's [constant
	## BEARING]; a turntable's ring wider.
	var bearing: float = BEARING
	## The furthest any part beyond it reaches from its point, LDU (a geared
	## segment's times its ratio: how fast it goes a radian of this joint).
	var reach: float = 0.0
	## Its friction torque, g·LDU²/s².
	var friction: float = 0.0
	## Pressed against what stopped it: +1 or -1 the way it was going, 0 free.
	var pressed: int = 0
	## For the words.
	var name: String = ""


class Segment extends RefCounted:
	## The joint that turns it (the innermost free one it hangs from).
	var joint: int = 0
	var grams: float = 0.0
	## Its centre of mass and its moment of inertia about it, as let go.
	var centre := Vector3.ZERO
	var inertia := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	## Brick id -> Transform3D where it was let go.
	var start: Dictionary = {}
	## A gear the train turns, with what rides on it: it turns about its own
	## line ([member turn_point], [member turn_axis]) at [member ratio] times
	## its joint's rate, not with its joint's frame. Its joint is the train's
	## driver, a joint that nothing else carries.
	var geared: bool = false
	var turn_point := Vector3.ZERO
	var turn_axis := Vector3.UP
	var ratio: float = 1.0


var joints: Array[Joint] = []
var segments: Array[Segment] = []
## Each joint's turn from where it was let go, radians, and its rate.
var q := PackedFloat64Array()
var qd := PackedFloat64Array()
## Simulated seconds since it was let go.
var time: float = 0.0
var at_rest: bool = false
## The room test: func(pose: Dictionary) -> int, the moving part that met
## something, 0 for room. Unset: nothing stops it.
var room: Callable
## μ in use (the range's ends for a probe).
var mu: float = MU
## What it met, and how often: for the words.
var stops: int = 0
## Each turn of the first joint's way, [seconds, radians]: the ends of its
## swings, for the words and a probe's period.
var turns: Array = []
## The most the energy ever stood above where it was let go: a stable step
## never adds energy (semi-implicit Euler's wobbles by a part in a thousand
## about the true value; an explicit step's grows each swing).
var energy_rise: float = 0.0
## The first joint's rate as it was let go, rad/s: a fling, 0 from rest.
var flung: float = 0.0
## How far the first joint turned in all, radians, either way: a coast's
## turns.
var travel: float = 0.0
## Room tests run, and the costliest, ms.
var tests: int = 0
var worst_test_ms: float = 0.0
## [method run] ran out of its time and kept it where it was last tested.
var cut_short: bool = false
var _still_for: float = 0.0
var _tested := PackedFloat64Array()
var _last_way: int = 0
var _energy_start: float = NAN
var _energy_drop: float = 0.0


## Mass, centre of mass and moment of inertia about it of the parts
## [param keys] where [param at] puts them (else where they stand), each
## part's mass spread through its box: {grams, centre, inertia (Basis)}.
static func lump(world: BrickWorld, library: PartLibrary, keys: Array, at: Dictionary = {}) -> Dictionary:
	var weight: float = 0.0
	var sum := Vector3.ZERO
	var pieces: Array = []   ## [grams, centre, own inertia]
	for key: Variant in keys:
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var g: float = Stability.grams(info)
		var placed: Transform3D = at.get(int(key), brick.transform)
		var centre: Vector3 = placed * info.bounds.get_center()
		var size: Vector3 = info.bounds.size
		var own := Basis(Vector3(size.y * size.y + size.z * size.z, 0, 0),
			Vector3(0, size.x * size.x + size.z * size.z, 0),
			Vector3(0, 0, size.x * size.x + size.y * size.y)) * (g / 12.0)
		var turn: Basis = placed.basis.orthonormalized()
		pieces.append([g, centre, turn * own * turn.transposed()])
		weight += g
		sum += centre * g
	var middle: Vector3 = sum / weight if weight > 0.0 else Vector3.ZERO
	var inertia := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	for piece: Array in pieces:
		var d: Vector3 = (piece[1] as Vector3) - middle
		var g: float = piece[0]
		# Parallel axes: m (|d|² 1 - d dᵀ).
		var shift := Basis(Vector3(d.dot(d) - d.x * d.x, -d.y * d.x, -d.z * d.x),
			Vector3(-d.x * d.y, d.dot(d) - d.y * d.y, -d.z * d.y),
			Vector3(-d.x * d.z, -d.y * d.z, d.dot(d) - d.z * d.z)) * g
		inertia = Swing._add(inertia, Swing._add(piece[2], shift))
	return {"grams": weight, "centre": middle, "inertia": inertia}


static func _add(a: Basis, b: Basis) -> Basis:
	return Basis(a.x + b.x, a.y + b.y, a.z + b.z)


## A joint: its line where it was let go, the joint carrying it (-1 for
## none), its name. Returns its index.
func add_joint(point: Vector3, axis: Vector3, parent: int, name: String) -> int:
	var one := Joint.new()
	one.point = point
	one.axis = axis.normalized()
	one.parent = parent
	one.name = name
	var at: int = parent
	one.chain.append(joints.size())
	while at >= 0:
		one.chain.append(at)
		at = joints[at].parent
	joints.append(one)
	q.append(0.0)
	qd.append(0.0)
	_tested.append(0.0)
	return joints.size() - 1


## A segment turned by [param joint]: its parts where they were let go
## (brick id -> Transform3D) and their lump (Swing.lump).
func add_segment(joint: int, start: Dictionary, lumped: Dictionary) -> void:
	var one := Segment.new()
	one.joint = joint
	one.start = start
	one.grams = float(lumped["grams"])
	one.centre = lumped["centre"]
	one.inertia = lumped["inertia"]
	segments.append(one)


## A gear the train turns, and what rides on it, driven by [param joint] (a
## joint nothing carries): it turns about the line through [param point]
## along [param spin], at |spin| radians a radian of the joint.
func add_geared(joint: int, start: Dictionary, lumped: Dictionary, point: Vector3, spin: Vector3) -> void:
	add_segment(joint, start, lumped)
	var one: Segment = segments[segments.size() - 1]
	one.geared = true
	one.turn_point = point
	one.turn_axis = spin.normalized()
	one.ratio = spin.length()


## Once the joints and segments are in: what each joint carries, how far it
## reaches, its friction.
func ready_up(world: BrickWorld, library: PartLibrary) -> void:
	for one: Joint in joints:
		one.grams = 0.0
		one.load = 0.0
		one.reach = 0.0
	for segment: Segment in segments:
		var on: PackedInt32Array = joints[segment.joint].chain
		if segment.geared:
			on = PackedInt32Array([segment.joint])
		for j: int in on:
			if segment.geared:
				joints[j].load += segment.grams * segment.ratio * BEARING
			else:
				joints[j].grams += segment.grams
				joints[j].load += segment.grams * joints[j].bearing
			for key: Variant in segment.start:
				var brick: BrickWorld.Brick = world.get_brick(int(key))
				var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
				if mesh == null:
					continue
				var placed: Transform3D = segment.start[key]
				for corner: int in 8:
					var corner_at: Vector3 = placed * mesh.bounds.get_endpoint(corner)
					if segment.geared:
						# Off its own line, at its ratio.
						var off: Vector3 = corner_at - segment.turn_point
						off -= segment.turn_axis * off.dot(segment.turn_axis)
						joints[j].reach = maxf(joints[j].reach, off.length() * segment.ratio)
					else:
						joints[j].reach = maxf(joints[j].reach, corner_at.distance_to(joints[j].point))
	set_mu(mu)


## Friction from [param value] for μ.
func set_mu(value: float) -> void:
	mu = value
	for one: Joint in joints:
		one.friction = mu * one.load * GRAVITY


## Where [param joined] bears, its radius, LDU: a pin's, an axle's or a
## stud's [constant BEARING]; a turntable's top bears on its base over its
## disc, taken as a flat disc under even pressure, whose friction acts at two
## thirds of its radius (a ring at its rim would be half as much again).
static func bearing_of(joined: Bodies.Link) -> float:
	if joined != null and joined.kind == "turntable" and joined.radius * 2.0 / 3.0 > BEARING:
		return joined.radius * 2.0 / 3.0
	return BEARING


## Let go turning at [param rate] rad/s on its first joint, as the pointer
## had it moving: it carries on at that rate and coasts.
func fling(rate: float) -> void:
	if joints.is_empty():
		return
	qd[0] = rate
	flung = rate


## Where each joint's frame stands at [param turns]: Transform3D per joint,
## from where it was let go.
func frames_at(turns: PackedFloat64Array) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for j: int in joints.size():
		var one: Joint = joints[j]
		var carried: Transform3D = out[one.parent] if one.parent >= 0 else Transform3D.IDENTITY
		var about := Transform3D(Basis.IDENTITY, one.point) \
			* Transform3D(Basis(one.axis, turns[j]), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -one.point)
		out.append(carried * about)
	return out


## Where [param segment] stands at [param turns], its joints' frames
## [param frames]: its joint's frame, or a geared one turned about its own
## line.
func _frame_of(segment: Segment, frames: Array[Transform3D], turns: PackedFloat64Array) -> Transform3D:
	if not segment.geared:
		return frames[segment.joint]
	return Transform3D(Basis.IDENTITY, segment.turn_point) \
		* Transform3D(Basis(segment.turn_axis, segment.ratio * turns[segment.joint]), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -segment.turn_point)


## Every part that swings, where [param turns] puts it.
func pose_at(turns: PackedFloat64Array) -> Dictionary:
	var frames: Array[Transform3D] = frames_at(turns)
	var out: Dictionary = {}
	for segment: Segment in segments:
		var frame: Transform3D = _frame_of(segment, frames, turns)
		for key: Variant in segment.start:
			out[key] = frame * (segment.start[key] as Transform3D)
	return out


func pose() -> Dictionary:
	return pose_at(q)


## The mass matrix and the forces at (q, q'): [M (n x n, row by row), Q],
## and the energy, kinetic and potential.
func dynamics(turns: PackedFloat64Array, rates: PackedFloat64Array) -> Array:
	var n: int = joints.size()
	var frames: Array[Transform3D] = frames_at(turns)
	var p: Array[Vector3] = []
	var u: Array[Vector3] = []
	for j: int in n:
		var parent: int = joints[j].parent
		var carried: Transform3D = frames[parent] if parent >= 0 else Transform3D.IDENTITY
		p.append(carried * joints[j].point)
		u.append((carried.basis * joints[j].axis).normalized())
	# Each joint's frame's spin, and how its line and point move.
	var spin: Array[Vector3] = []
	var u_dot: Array[Vector3] = []
	var p_dot: Array[Vector3] = []
	for j: int in n:
		var parent: int = joints[j].parent
		var carried_spin: Vector3 = spin[parent] if parent >= 0 else Vector3.ZERO
		spin.append(carried_spin + u[j] * rates[j])
		u_dot.append(carried_spin.cross(u[j]))
		var moving := Vector3.ZERO
		if parent >= 0:
			for i: int in joints[parent].chain:
				moving += u[i].cross(p[j] - p[i]) * rates[i]
		p_dot.append(moving)
	# Row by row, n x n.
	var mass := PackedFloat64Array()
	mass.resize(n * n)
	var force := PackedFloat64Array()
	force.resize(n)
	var kinetic: float = 0.0
	var potential: float = 0.0
	var down := Vector3(0.0, -GRAVITY, 0.0)
	for segment: Segment in segments:
		var frame: Transform3D = _frame_of(segment, frames, turns)
		var c: Vector3 = frame * segment.centre
		var turn: Basis = frame.basis
		var inertia: Basis = turn * segment.inertia * turn.transposed()
		if segment.geared:
			# A gear on its own line at the train's ratio: one column, its
			# joint's. Its speed is the ratio's, so its inertia counts as the
			# ratio squared; on a fixed line no velocity term pushes it round
			# (the centripetal pull is square to its turn).
			var j: int = segment.joint
			var own: Vector3 = segment.turn_axis * segment.ratio
			var column: Vector3 = own.cross(c - segment.turn_point)
			var gv: Vector3 = column * rates[j]
			var gw: Vector3 = own * rates[j]
			var pull: Vector3 = (down - gw.cross(gv)) * segment.grams
			force[j] += column.dot(pull) - own.dot(gw.cross(inertia * gw))
			mass[j * n + j] += segment.grams * column.dot(column) + own.dot(inertia * own)
			kinetic += 0.5 * (segment.grams * gv.dot(gv) + gw.dot(inertia * gw))
			potential += segment.grams * GRAVITY * c.y
			continue
		var chain: PackedInt32Array = joints[segment.joint].chain
		var jv: Array[Vector3] = []
		var v := Vector3.ZERO
		for i: int in chain:
			var column: Vector3 = u[i].cross(c - p[i])
			jv.append(column)
			v += column * rates[i]
		var w: Vector3 = spin[segment.joint]
		# The accelerations the rates alone give (q'' = 0).
		var a0 := Vector3.ZERO
		var alpha0 := Vector3.ZERO
		for i: int in chain:
			a0 += (u_dot[i].cross(c - p[i]) + u[i].cross(v - p_dot[i])) * rates[i]
			alpha0 += u_dot[i] * rates[i]
		var lin: Vector3 = (down - a0) * segment.grams
		var rot: Vector3 = inertia * alpha0 + w.cross(inertia * w)
		for x: int in chain.size():
			var i: int = chain[x]
			force[i] += jv[x].dot(lin) - u[i].dot(rot)
			for y: int in chain.size():
				var l: int = chain[y]
				mass[i * n + l] += segment.grams * jv[x].dot(jv[y]) + u[i].dot(inertia * u[l])
		kinetic += 0.5 * (segment.grams * v.dot(v) + w.dot(inertia * w))
		potential += segment.grams * GRAVITY * c.y
	return [mass, force, kinetic + potential]


## Solve [param m] x = [param b], m n x n row by row (Gaussian elimination,
## partial pivots).
static func solve(m: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var n: int = b.size()
	if n == 1:
		return PackedFloat64Array([b[0] / m[0] if absf(m[0]) > 1e-12 else 0.0])
	var a: Array = []
	for i: int in n:
		var row: PackedFloat64Array = m.slice(i * n, i * n + n)
		row.append(b[i])
		a.append(row)
	for col: int in n:
		var best: int = col
		for r: int in range(col + 1, n):
			if absf((a[r] as PackedFloat64Array)[col]) > absf((a[best] as PackedFloat64Array)[col]):
				best = r
		var swap: PackedFloat64Array = a[col]
		a[col] = a[best]
		a[best] = swap
		var pivot: float = (a[col] as PackedFloat64Array)[col]
		if absf(pivot) < 1e-12:
			continue
		for r: int in range(col + 1, n):
			var row: PackedFloat64Array = a[r]
			var k: float = row[col] / pivot
			if k == 0.0:
				continue
			var top: PackedFloat64Array = a[col]
			for c: int in range(col, n + 1):
				row[c] -= k * top[c]
			a[r] = row
	var x := PackedFloat64Array()
	x.resize(n)
	for i: int in range(n - 1, -1, -1):
		var row: PackedFloat64Array = a[i]
		var total: float = row[n]
		for c: int in range(i + 1, n):
			total -= row[c] * x[c]
		x[i] = total / row[i] if absf(row[i]) > 1e-12 else 0.0
	return x


## One step of [constant STEP]: gravity and the velocity terms, the joints'
## friction (stick or slip, Coulomb's, solved at the velocity), the room test
## where it has gone far enough, and whether it is now at rest.
func step() -> void:
	if at_rest:
		return
	var n: int = joints.size()
	var got: Array = dynamics(q, qd)
	var mass: PackedFloat64Array = got[0]
	var force: PackedFloat64Array = got[1]
	var energy: float = got[2]
	if is_nan(_energy_start):
		_energy_start = energy
	energy_rise = maxf(energy_rise, energy - _energy_start)
	_energy_drop = maxf(_energy_drop, _energy_start - energy)
	var accel: PackedFloat64Array = Swing.solve(mass, force)
	var free := PackedFloat64Array()
	free.resize(n)
	for j: int in n:
		free[j] = qd[j] + STEP * accel[j]
	# Friction impulses, each within ±STEP·its torque, against the turn: the
	# inverse mass's columns say how a push on one joint moves them all.
	var inverse: Array = []
	for j: int in n:
		var unit := PackedFloat64Array()
		unit.resize(n)
		unit[j] = 1.0
		inverse.append(Swing.solve(mass, unit))
	var held := PackedFloat64Array()
	held.resize(n)
	# A joint pressed against what stopped it stays while it is pushed on:
	# what stopped it pushes back on that joint alone, never pulls, so it
	# moves the rest as its column says. Set to nought by itself, a stopped
	# frame's turn was taken from the frame and not from a wheel on a free
	# axle in it, which was left each step the turn the frame's fall gave it
	# and spun up for ever: a motorcycle's move_part ran for an hour.
	var stopped := PackedFloat64Array()
	stopped.resize(n)
	for _round: int in (1 if n == 1 else FRICTION_ROUNDS):
		for j: int in n:
			var column: PackedFloat64Array = inverse[j]
			if column[j] <= 0.0:
				continue
			var bound: float = STEP * joints[j].friction
			var wanted: float = clampf(held[j] - free[j] / column[j], -bound, bound)
			var change: float = wanted - held[j]
			held[j] = wanted
			var way: int = joints[j].pressed
			if way != 0:
				var push: float = stopped[j] - (free[j] + column[j] * change) / column[j]
				if push * way > 0.0:
					push = 0.0
				change += push - stopped[j]
				stopped[j] = push
			if change == 0.0:
				continue
			for i: int in n:
				free[i] += column[i] * change
	# What is left of a push into the stop after the rounds, and a joint
	# pulled away from what stopped it is free again.
	for j: int in n:
		var way: int = joints[j].pressed
		if way != 0:
			if free[j] * way > 0.0:
				free[j] = 0.0
			elif free[j] * way < 0.0:
				joints[j].pressed = 0
	var next := PackedFloat64Array()
	next.resize(n)
	var moved: bool = false
	for j: int in n:
		next[j] = q[j] + STEP * free[j]
		if absf(free[j]) * maxf(joints[j].reach, 1.0) > STILL_SPEED:
			moved = true
	var was: float = q[0]
	qd = free
	time += STEP
	# The room test, each time the furthest point has gone TEST_LDU.
	var gone: float = 0.0
	for j: int in n:
		gone += absf(next[j] - _tested[j]) * joints[j].reach
	if gone >= TEST_LDU and room.is_valid():
		var met: int = _test(next)
		if met != 0:
			_meet(next, met)
			moved = false
		else:
			_tested = next.duplicate()
			q = next
	else:
		q = next
	travel += absf(q[0] - was)
	# The ends of the first joint's swings.
	var way_now: int = signi(int(signf(qd[0])))
	if way_now != 0 and _last_way != 0 and way_now != _last_way:
		turns.append([time, q[0]])
	if way_now != 0:
		_last_way = way_now
	_still_for = 0.0 if moved else _still_for + STEP
	if _still_for >= STILL_S:
		at_rest = true
		if room.is_valid() and _tested != q:
			# Where it rests is tested, however little it went since.
			if _test(q) != 0:
				q = _tested.duplicate()
	if time >= MOST_S:
		at_rest = true


func _test(turns: PackedFloat64Array) -> int:
	var began: int = Time.get_ticks_usec()
	var met: int = int(room.call(pose_at(turns)))
	tests += 1
	worst_test_ms = maxf(worst_test_ms, float(Time.get_ticks_usec() - began) / 1000.0)
	return met


## The step to [param next] met [param met]: bisected back to the last turn
## with room, it stops dead there, and each joint that carries what met
## something is pressed against it while it is pushed that way.
func _meet(next: PackedFloat64Array, met: int) -> void:
	var low: PackedFloat64Array = _tested.duplicate()
	var high: PackedFloat64Array = next
	for _round: int in ROUNDS:
		var middle := PackedFloat64Array()
		for j: int in joints.size():
			middle.append((low[j] + high[j]) * 0.5)
		var hit: int = _test(middle)
		if hit == 0:
			low = middle
		else:
			high = middle
			met = hit
	var carrying: Dictionary = {}
	for segment: Segment in segments:
		if segment.start.has(met):
			for j: int in joints[segment.joint].chain:
				carrying[j] = true
	if carrying.is_empty():
		for j: int in joints.size():
			carrying[j] = true
	var halted: Dictionary = {}
	for j: int in carrying:
		var way: int = signi(int(signf(next[j] - _tested[j])))
		if way != 0:
			joints[j].pressed = way
			halted[j] = true
	q = low
	_tested = low.duplicate()
	_halt(halted)
	stops += 1


## Stop the joints [param halted] dead, as what they met stops them: it
## pushes on those joints alone, so each other joint keeps its momentum
## (its row of M q'), and what it carries turns on as it was turning. Set
## to nought by themselves, a wheel on a free axle in a frame that met
## something took the frame's turn into its own.
func _halt(halted: Dictionary) -> void:
	if halted.is_empty():
		return
	var n: int = joints.size()
	var rest: Array[int] = []
	for j: int in n:
		if not halted.has(j):
			rest.append(j)
	var momentum := PackedFloat64Array()
	var rows := PackedFloat64Array()
	if not rest.is_empty():
		var mass: PackedFloat64Array = dynamics(q, qd)[0]
		for i: int in rest:
			var p: float = 0.0
			for k: int in n:
				p += mass[i * n + k] * qd[k]
			momentum.append(p)
			for k: int in rest:
				rows.append(mass[i * n + k])
	var kept: PackedFloat64Array = Swing.solve(rows, momentum) if not rest.is_empty() \
		else PackedFloat64Array()
	for j: int in n:
		qd[j] = 0.0
	for x: int in rest.size():
		qd[rest[x]] = kept[x]


## Start it moving as the parts were when what carries them all stopped
## dead: they were turning at [param spin] (rad/s about its line) about
## [param about] (a model landing from a fall). The stop's push acts on what
## carries them, not on them, so their momentum in the joints' turns is kept:
## M q' = Σ Jᵀ (m v, I ω) of the motion they had.
func carry(spin: Vector3, about: Vector3) -> void:
	var n: int = joints.size()
	var got: Array = dynamics(q, qd)
	var momentum := PackedFloat64Array()
	momentum.resize(n)
	var frames: Array[Transform3D] = frames_at(q)
	for segment: Segment in segments:
		var frame: Transform3D = _frame_of(segment, frames, q)
		var c: Vector3 = frame * segment.centre
		var inertia: Basis = frame.basis * segment.inertia * frame.basis.transposed()
		var v: Vector3 = spin.cross(c - about)
		if segment.geared:
			var own: Vector3 = segment.turn_axis * segment.ratio
			momentum[segment.joint] += segment.grams * own.cross(c - segment.turn_point).dot(v) \
				+ own.dot(inertia * spin)
			continue
		for i: int in joints[segment.joint].chain:
			var parent: int = joints[i].parent
			var carried: Transform3D = frames[parent] if parent >= 0 else Transform3D.IDENTITY
			var p: Vector3 = carried * joints[i].point
			var u: Vector3 = (carried.basis * joints[i].axis).normalized()
			momentum[i] += segment.grams * u.cross(c - p).dot(v) + u.dot(inertia * spin)
	qd = Swing.solve(got[0], momentum)


## Run the steps [param seconds] of simulated time ask, for at most
## [param budget_ms] of the frame: past it the swing goes slower than the
## clock rather than hold the frame. Returns the simulated seconds run.
func advance(seconds: float, budget_ms: float = INF) -> float:
	var began: int = Time.get_ticks_usec()
	var ran: float = 0.0
	while ran < seconds and not at_rest:
		step()
		ran += STEP
		if budget_ms < INF and float(Time.get_ticks_usec() - began) / 1000.0 > budget_ms:
			break
	return ran


## Run to rest (a session's move_part, a probe), for at most [param
## budget_ms] by the clock: past it, it is kept where it was last tested
## and [member cut_short] says so. Returns the simulated seconds it swung.
func run(budget_ms: float = RUN_MOST_MS) -> float:
	var began: int = Time.get_ticks_usec()
	while not at_rest:
		step()
		if not at_rest and float(Time.get_ticks_usec() - began) / 1000.0 > budget_ms:
			cut_short = true
			at_rest = true
			if room.is_valid():
				q = _tested.duplicate()
	return time


## The most the energy stood above where it was let go, as a share of the
## most it fell below it: a stable integration keeps it near nought.
func energy_rise_share() -> float:
	return energy_rise / maxf(_energy_drop, 1e-9)


## Half periods: the times between the ends of the first joint's swings.
func half_periods() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for n: int in range(1, turns.size()):
		out.append(float(turns[n][0]) - float(turns[n - 1][0]))
	return out


## "swung back and forth 9 times in 3.2 s", or "" for none.
func words() -> String:
	var swings: int = turns.size()
	if time <= STILL_S + STEP * 2.0 and stops == 0 and not cut_short:
		return ""
	var out: String
	# How long it moved: the stillness that says it is at rest is not, and
	# one cut short had none.
	var lasted: float = time if cut_short else time - STILL_S
	if absf(flung) > 0.0:
		# Let go while it moved: how fast, how far it coasted, how long.
		out = "let go turning at %s turns a second, it coasted %s turns in %s s against its bearing's friction" % [
			Balance.tidy(absf(flung) / TAU), Balance.tidy(travel / TAU), Balance.tidy(lasted)]
		# A turn back is a swing when it goes a degree or more before the next:
		# a train's stop can rock it back by a hair.
		var back: int = 0
		for k: int in turns.size():
			var to: float = float(turns[k + 1][1]) if k + 1 < turns.size() else q[0]
			if absf(to - float(turns[k][1])) >= deg_to_rad(1.0):
				back += 1
		if back > 0:
			out += ", swinging back and forth %d time%s" % [back, "" if back == 1 else "s"]
		if stops > 0:
			out += ", stopping dead where it met the model %s" % ("once" if stops == 1 else "%d times" % stops)
		if time >= MOST_S:
			out += "; still turning after %d s, kept where it was" % roundi(MOST_S)
		return out + _cut_words()
	if swings == 0:
		out = "swung down under its own weight in %s s" % Balance.tidy(lasted)
	else:
		out = "swung down under its own weight and back and forth %d time%s in %s s" % [swings,
			"" if swings == 1 else "s", Balance.tidy(lasted)]
	if stops > 0:
		out += ", stopping dead where it met the model %s" % ("once" if stops == 1 else "%d times" % stops)
	if time >= MOST_S:
		out += "; still swinging after %d s, kept where it was" % roundi(MOST_S)
	return out + _cut_words()


## How [method run] ran out of time, or "".
func _cut_words() -> String:
	if not cut_short:
		return ""
	return ("; still moving then, kept where it was: the app works a swing out for at most %d s"
		% roundi(RUN_MOST_MS / 1000.0))
