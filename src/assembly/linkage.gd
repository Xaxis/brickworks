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
## stood: an actuator's or a cylinder's stroke.
var _limits: Dictionary = {}
## How the last solve went: iterations and the residual left, LDU.
var iterations: int = 0
var residual: float = 0.0
var solves: int = 0
var last_residual := PackedFloat64Array()


## The loops round [param driver] (a tree link) and its [param child]:
## every closing joint whose loop runs through a joint that moves, and every
## joint of those loops, until nothing more is added.
static func read(from: Bodies, driver: Bodies.Link, child: int, couplings: Array = []) -> Linkage:
	var out := Linkage.new()
	out.bodies = from
	out._offered = couplings
	out._read(driver, child)
	return out


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
	var at: int = body
	while bodies.parent_link.has(at):
		out.push_front(bodies.parent_link[at])
		at = int(bodies.parent_of[at])
	return out


func _read(driver: Bodies.Link, child: int) -> void:
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
		for loop: Bodies.Link in bodies.closing:
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
		_axis.append(link.axis.normalized())
		_point.append(link.point)
		turn_col.append(cols)
		if not link.turns:
			_still[cols] = true
		cols += 1
		if link.axis == Vector3.ZERO:
			# A ball: three turns, about x, then y, then z where it stood.
			cols += 2
			slide_col.append(-1)
		elif link.slide.x + link.slide.y > 0.0:
			if not link.turns:
				# An actuator's stroke, its rod or its body the one that moves.
				var rod_moves: bool = int(bodies.body_of.get(link.shaft_part, -1)) == kid
				_limits[cols] = Vector2(-link.slide.y, link.slide.x) if rod_moves \
					else Vector2(-link.slide.x, link.slide.y)
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
	q.resize(cols)
	q.fill(0.0)
	kept = q.duplicate()
	_gear_at_keep = _gear_kept.duplicate(true)
	driver_col = turn_col[0]
	if not links[0].turns and slide_col[0] >= 0:
		# An actuator's rod: driven along it.
		driver_col = slide_col[0]
	for n: int in range(1, links.size()):
		if bodies.beyond(child_of[n]).has(parent_of[0]):
			for c: int in [turn_col[n], slide_col[n]] + ([turn_col[n] + 1, turn_col[n] + 2]
					if _axis[n] == Vector3.ZERO else []):
				if c >= 0:
					_carrying[c] = true
	# What moves: everything beyond each joint of the loops.
	var seen: Dictionary = {}
	for n: int in links.size():
		for body: int in bodies.beyond(child_of[n]):
			if seen.has(body):
				continue
			seen[body] = true
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


## The loop joints on the way from the anchor to [param body].
func _joints_on(body: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for link: Variant in _path(body):
		if _index_of.has(link):
			out.append(int(_index_of[link]))
	return out


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
	for n: int in range(1, links.size()):
		if bodies.beyond(child_of[n]).has(parent_of[0]):
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
	var here: int = body
	var base := Transform3D.IDENTITY
	while true:
		if cache.has(here):
			base = cache[here]
			break
		if not bodies.parent_link.has(here):
			cache[here] = Transform3D.IDENTITY
			break
		climb.append(here)
		here = int(bodies.parent_of[here])
	for k: int in range(climb.size() - 1, -1, -1):
		var one: int = climb[k]
		var joint: Variant = _index_of.get(bodies.parent_link[one])
		if joint != null:
			base = base * _turn_of(int(joint), at)
		cache[one] = base
	return base


## Each closing joint's residual: 3 for where its halves meet, 3 for their
## lines (none for a ball).
func _residual(at: PackedFloat64Array, cache: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k: int in closing.size():
		var loop: Bodies.Link = closing[k]
		var wa: Transform3D = _place(loop.a, at, cache)
		var wb: Transform3D = _place(loop.b, at, cache)
		var gap: Vector3 = wa * loop.point - wb * loop.point
		if loop.axis != Vector3.ZERO:
			var ua: Vector3 = (wa.basis * loop.axis).normalized()
			var ub: Vector3 = (wb.basis * loop.axis).normalized()
			if _slides(loop):
				gap -= ua * gap.dot(ua)
			out.append_array([gap.x, gap.y, gap.z])
			var turned: Vector3 = ua.cross(ub) * AXIS_SCALE
			out.append_array([turned.x, turned.y, turned.z])
		else:
			out.append_array([gap.x, gap.y, gap.z])
	for k: int in racks.size():
		out.append(_rack_residual(k, at, cache))
	for k: int in _gear_ends.size():
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
	return mesh.line.dot(seen - mesh.centre) + mesh.rate * turn


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
	for n: int in links.size():
		var up: Transform3D = _place(parent_of[n], at, cache)
		ways.append((up.basis * _axis[n]).normalized() if _axis[n] != Vector3.ZERO else Vector3.ZERO)
		points.append(up * _point[n])
		if _axis[n] == Vector3.ZERO:
			ball_ways[n] = _ball_ways(n, at, up)
	for k: int in closing.size():
		var loop: Bodies.Link = closing[k]
		var wa: Transform3D = _place(loop.a, at, cache)
		var wb: Transform3D = _place(loop.b, at, cache)
		var pa: Vector3 = wa * loop.point
		var pb: Vector3 = wb * loop.point
		var ua := Vector3.ZERO
		var ub := Vector3.ZERO
		if loop.axis != Vector3.ZERO:
			ua = (wa.basis * loop.axis).normalized()
			ub = (wb.basis * loop.axis).normalized()
		# Columns: d(gap) and d(ua × ub) for each coordinate.
		var gaps: Array[Vector3] = []
		var turns: Array[Vector3] = []
		gaps.resize(cols)
		turns.resize(cols)
		gaps.fill(Vector3.ZERO)
		turns.fill(Vector3.ZERO)
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
				var w: Vector3 = ways[n]
				if slide_col[n] >= 0:
					gaps[slide_col[n]] += w * sign
		if loop.axis != Vector3.ZERO and _slides(loop):
			# Along its own line the halves may part: that component is not
			# a residual, and neither is its derivative.
			for c: int in cols:
				gaps[c] -= ua * gaps[c].dot(ua)
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
	while now > CLOSE_TO * 0.2 and iterations < ITERATIONS:
		iterations += 1
		var jac: Array = _jacobian(q, cache)
		var free: Array = []
		for c: int in cols:
			if c != driver_col and not _still.has(c) and not held.has(c):
				free.append(c)
		var n: int = free.size()
		if n == 0:
			break
		# Normal equations: (JᵀJ + λ diag) dq = −Jᵀr.
		var a: Array = []
		var g := PackedFloat64Array()
		g.resize(n)
		for i: int in n:
			var row := PackedFloat64Array()
			row.resize(n)
			a.append(row)
		for k: int in jac.size():
			var line: PackedFloat64Array = jac[k]
			var rk: float = r[k]
			for i: int in n:
				var ji: float = line[free[i]]
				if ji == 0.0:
					continue
				g[i] += ji * rk
				var row_i: PackedFloat64Array = a[i]
				for j: int in n:
					row_i[j] += ji * line[free[j]]
				a[i] = row_i
		var stepped: bool = false
		for _try: int in 6:
			var m: Array = []
			for i: int in n:
				var row: PackedFloat64Array = (a[i] as PackedFloat64Array).duplicate()
				row[i] += lam * maxf(row[i], 1.0) + 1e-9
				m.append(row)
			var dq: PackedFloat64Array = Linkage._solve_linear(m, g)
			if dq.is_empty():
				lam *= 10.0
				continue
			var trial: PackedFloat64Array = q.duplicate()
			for i: int in n:
				trial[free[i]] -= dq[i]
			var trial_cache: Dictionary = {}
			var tr: PackedFloat64Array = _residual(trial, trial_cache)
			var then: float = _worst(tr)
			if then < now:
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
	return now <= CLOSE_TO


## Gaussian elimination with partial pivoting; empty when singular.
static func _solve_linear(m: Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var n: int = b.size()
	var rhs: PackedFloat64Array = b.duplicate()
	for col: int in n:
		var best: int = col
		for row: int in range(col + 1, n):
			if absf((m[row] as PackedFloat64Array)[col]) > absf((m[best] as PackedFloat64Array)[col]):
				best = row
		if absf((m[best] as PackedFloat64Array)[col]) < 1e-12:
			return PackedFloat64Array()
		if best != col:
			var swap: Variant = m[col]
			m[col] = m[best]
			m[best] = swap
			var t: float = rhs[col]
			rhs[col] = rhs[best]
			rhs[best] = t
		var pivot_row: PackedFloat64Array = m[col]
		for row: int in range(col + 1, n):
			var this_row: PackedFloat64Array = m[row]
			var f: float = this_row[col] / pivot_row[col]
			if f == 0.0:
				continue
			for k: int in range(col, n):
				this_row[k] -= f * pivot_row[k]
			rhs[row] -= f * rhs[col]
			m[row] = this_row
	var out := PackedFloat64Array()
	out.resize(n)
	for row: int in range(n - 1, -1, -1):
		var this_row: PackedFloat64Array = m[row]
		var sum: float = rhs[row]
		for k: int in range(row + 1, n):
			sum -= this_row[k] * out[k]
		out[row] = sum / this_row[row]
	return out


# -- driving it ------------------------------------------------------------------------


## The driver's value in the pose last kept.
func kept_value() -> float:
	return kept[driver_col]


## Solve for the driver at [param value], from the pose last kept, in steps;
## where it cannot close, q stays at the furthest value that does (bisected
## to a fiftieth of a step). Returns that value.
func reach(value: float) -> float:
	q = kept.duplicate()
	_gear_kept = _gear_at_keep.duplicate(true)
	var from: float = q[driver_col]
	var step: float = STEP_SLIDE if is_slide() else STEP_TURN
	var count: int = maxi(1, ceili(absf(value - from) / step))
	var good: float = from
	var good_q: PackedFloat64Array = q.duplicate()
	for n: int in range(1, count + 1):
		var at: float = lerpf(from, value, float(n) / float(count))
		q[driver_col] = at
		if _close() and _within():
			good = at
			good_q = q.duplicate()
			# The gears' turns unwrapped against this step's, not the first's:
			# a worm turns many times over in one drag.
			_keep_gear_turns(q)
			continue
		# Short of it: the furthest that closes between the last good and here.
		var low: float = good
		var high: float = at
		for _round: int in 7:
			var middle: float = (low + high) * 0.5
			q = good_q.duplicate()
			q[driver_col] = middle
			if _close() and _within():
				low = middle
				good_q = q.duplicate()
				_keep_gear_turns(q)
			else:
				high = middle
		q = good_q
		return low
	q = good_q
	return good


## Whether every actuator's and cylinder's rod is within its stroke as q
## stands: drawn out no further than the part goes, nor in.
func _within() -> bool:
	for c: int in _limits:
		var span: Vector2 = _limits[c]
		if q[c] < span.x - 0.01 or q[c] > span.y + 0.01:
			return false
	return true


## How far the slide in column [param c] may go, from where it stood:
## Vector2(least, most), or INF both ways where nothing but the loop limits
## it.
func limits_of(c: int) -> Vector2:
	return _limits.get(c, Vector2(-INF, INF))


## Keep the pose q stands in as where the next move starts.
func keep() -> void:
	kept = q.duplicate()
	_keep_gear_turns(q)
	_gear_at_keep = _gear_kept.duplicate(true)


## The gears' turns in the pose last kept (_gear_kept, as keep() left it).
var _gear_at_keep: Array = []


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
	var words: String = "a loop of %d joints (%s), closed by %d" % [links.size() + closing.size(),
		", ".join(parts), closing.size()]
	if not gear_meshes.is_empty():
		words += ", %d gear mesh%s" % [gear_meshes.size(), "" if gear_meshes.size() == 1 else "es"]
	if not racks.is_empty():
		var teeth := PackedStringArray()
		for mesh: Racks.Pinion in racks:
			teeth.append(mesh.said(bodies.world))
		words += " and %s" % ", ".join(teeth)
	return words
