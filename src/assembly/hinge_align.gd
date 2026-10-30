## Hinge align: the joints between two parts swing so the two meet.
##
## Curved walls, rings, wings and domes on hinges were worked out by hand,
## one hinge at a time. LDD had a Hinge Align, "notoriously buggy", and it
## went with LDD; Studio has none, and its forum's answer is the angles
## worked out by hand (docs/APP_UX.md, B4). Here a person selects a part and
## the part it should meet, and Meet swings every joint between them.
##
## The joints are Bodies' tree: from each part's body back towards the
## anchor, to the body both hang from. Each turns everything beyond it
## about its line where it stands, the outer ones carrying the inner, as
## Poser.transforms_for and GrabChain have it, so what is built on a
## segment comes along. What meets is a free hinge end of the one and a free
## end of the other that takes it: a click hinge's finger in a fork, a
## hinge's pin in its eye, a clip on a bar; their middles one point, their
## lines one line.
##
## The turns are the least turning that closes the gap. Levenberg-Marquardt
## on the gap and on each joint's turn, the gap weighed a hundred times more
## each round until it is shut (a penalty method). The joint the meeting
## makes counts too, as its bend from straight, so eight hinges in a line
## close into a regular octagon, 45° each, and not a shape with one sharp
## corner: with every bend counted as 2 sin(bend / 2), equal bends are the
## least for a closed ring. A chain laid straight is where no small turn
## closes the gap (each joint moves the end across the line, none along it),
## so it is started from bends both ways as well as from where it stands.
##
## A click hinge stops on its clicks (Bodies.CLICK_STEP): the joint nearest a
## click is set on it, the rest solved again, until all are; and the joint
## the meeting makes must be on a click too. Kept only when every part has
## room where it ends up, pressing only on what it is joined to, and as one
## step to undo. Otherwise nothing moves, and the words say why.
class_name HingeAlign
extends RefCounted

## Shut when the two ends' middles are no further apart than this, LDU, and
## their lines no more than this many radians apart: well inside what the
## build check takes for one line (Joints.ROUND_OFF_AXIS, Joints.COAXIAL).
const CLOSE_TO := 0.05
const LINE_TO := 0.002
## A line turned a radian weighs as an end moved this far, LDU, as Linkage.
const AXIS_SCALE := 20.0
## A round a hinge turns in, as Joints.hinge_line_of reads one: a clip's, a
## bar's, a hinge's pin and its eye, LDU.
const ROUND_LEAST := 3.5
const ROUND_MOST := 6.5
## Two ends on one line: this far apart across it, LDU, and to this
## cosine.
const ON_LINE := 1.5
const COAXIAL := 0.999
## At most this many joints between the two.
const MOST_JOINTS := 24
## The gap's weight, round by round, and Levenberg-Marquardt's steps in each.
const WEIGHTS: Array[float] = [0.01, 1.0, 100.0, 1.0e4, 1.0e6]
const STEPS := 40
## A step turns no joint further than this, radians.
const MOST_STEP := 0.5
## Every joint bent this far the same way to start from, degrees, besides
## where it stands and a few bends at random.
const BENDS: Array[float] = [15.0, -15.0, 45.0, -45.0, 90.0, -90.0]
const SHAKES := 6
## On a click: within this of one, degrees.
const ON_A_CLICK := 0.25
## How long the search may take, ms, before it keeps the best found.
const MOST_MS := 2500.0
## Turned by a numerical slope: this far each way, radians.
const NUDGE := 1.0e-4
## A part may reach this far below the model's lowest point, LDU, as Grab.
const BELOW_FLOOR := 4.0

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var bodies: Bodies

## Why it cannot, or "" when it can.
var why: String = ""
## What it did, when it did.
var said: String = ""
## How far apart the nearest swing leaves the two, LDU, when none shuts the gap.
var gap: float = INF
## Every part that moves: brick id -> where it stood, and where it goes.
var rest: Dictionary = {}
var placed: Dictionary = {}
## Each joint's turn, degrees, and its line where it stood.
var turns := PackedFloat64Array()
var lines: Array = []   ## [point, axis]
## What the meeting is between: the two parts and their ends' kinds.
var met: Array = []
var took_ms: float = 0.0
var tries: int = 0

## The joints, in order: each side's from the body both hang from out.
var _point: Array[Vector3] = []
var _axis: Array[Vector3] = []
var _parent := PackedInt32Array()   ## the joint carrying it on its side, -1 none
var _detent := PackedFloat64Array()
var _links: Array[Bodies.Link] = []
var _child := PackedInt64Array()
## Moving part -> the innermost joint that carries it.
var _deepest: Dictionary = {}
## Moving part -> the joints carrying it, as a key: parts carried alike keep
## their places to each other.
var _carried: Dictionary = {}
## The meeting being solved: [part, End] each side.
var _one: Array = []
var _other: Array = []
## Click joints' turns: [index, its square turn at rest, its sign].
var _clicks: Array = []
var _meet_detent: float = 0.0
var _began: int = 0


## One end a hinge turns on, in its part's frame.
class End extends RefCounted:
	## "hinge" (a click hinge's finger or fork) or "round" (a pin, an eye, a
	## clip, a bar).
	var family: String = ""
	var male: bool = false
	var middle := Vector3.ZERO
	var way := Vector3.UP
	var radii := PackedFloat64Array()
	## Half its length along its line, LDU.
	var half: float = 0.0
	var words: String = ""

	func takes(other: End) -> bool:
		if family != other.family or male == other.male:
			return false
		if family == "hinge":
			return true
		for mine: float in radii:
			for theirs: float in other.radii:
				if absf(mine - theirs) <= Joints.ROUND_FIT:
					return true
		return false


## The ends a part turns on: each click hinge finger and fork, and the
## rounds of a hinge's size on one line, shafts apart from bores, as one end
## spanning them all.
static func ends_of(mesh: Lbm.PartMesh) -> Array[End]:
	var out: Array[End] = []
	if mesh == null:
		return out
	var groups: Array = []   ## [male, point, way, from, to, radii]
	for connector: Lbm.Connector in mesh.connectors:
		var way: Vector3 = connector.axis.normalized()
		if way == Vector3.ZERO:
			continue
		if connector.kind == "finger" or connector.kind == "fork":
			var end := End.new()
			end.family = "hinge"
			end.male = connector.kind == "finger"
			end.middle = connector.position + way * (connector.length * 0.5)
			end.way = way
			end.radii = PackedFloat64Array([connector.radius])
			end.half = connector.length * 0.5
			end.words = "click hinge"
			out.append(end)
			continue
		if connector.kind != "shaft" and connector.kind != "bore":
			continue
		if connector.radius < ROUND_LEAST or connector.radius > ROUND_MOST or connector.length <= 0.0:
			continue
		var male: bool = connector.kind == "shaft"
		var from: float = 0.0
		var to: float = connector.length
		var found: bool = false
		for group: Array in groups:
			if group[0] != male or absf((group[2] as Vector3).dot(way)) < COAXIAL:
				continue
			var apart: Vector3 = connector.position - (group[1] as Vector3)
			var along: float = apart.dot(group[2])
			if (apart - (group[2] as Vector3) * along).length() > ON_LINE:
				continue
			var sign: float = signf((group[2] as Vector3).dot(way))
			group[3] = minf(float(group[3]), minf(along, along + connector.length * sign))
			group[4] = maxf(float(group[4]), maxf(along, along + connector.length * sign))
			(group[5] as PackedFloat64Array).append(connector.radius)
			found = true
			break
		if not found:
			groups.append([male, connector.position, way, from, to,
				PackedFloat64Array([connector.radius])])
	for group: Array in groups:
		var end := End.new()
		end.family = "round"
		end.male = group[0]
		end.way = group[2]
		end.middle = (group[1] as Vector3) + end.way * ((float(group[3]) + float(group[4])) * 0.5)
		end.half = (float(group[4]) - float(group[3])) * 0.5
		end.radii = group[5]
		end.words = "hinge"
		out.append(end)
	return out


## Swing the joints between [param one] and [param other] (brick ids) so the
## two meet. True with [member placed] and [member said] when they can;
## false with [member why] otherwise. Changes nothing: [method commit] keeps it.
func solve(one: int, other: int) -> bool:
	_began = Time.get_ticks_usec()
	var done: bool = _solve(one, other)
	took_ms = float(Time.get_ticks_usec() - _began) / 1000.0
	return done


func _solve(one: int, other: int) -> bool:
	if world.get_brick(one) == null or world.get_brick(other) == null or one == other:
		return _no("select the two parts that should meet")
	if not bodies.body_of.has(one) or not bodies.body_of.has(other):
		return _no("one of them is not part of the model")
	var body_one: int = int(bodies.body_of[one])
	var body_other: int = int(bodies.body_of[other])
	if body_one == body_other:
		return _no("they are held as one already: no joint between them turns")
	if not _chain_between(body_one, body_other):
		return false
	# What may meet: a free end of either part's body that takes a free end
	# of the other's, the two parts' own first.
	var pairs: Array = []
	for mine: Array in _free_ends(body_one, one):
		for theirs: Array in _free_ends(body_other, other):
			if (mine[1] as End).takes(theirs[1]):
				pairs.append([mine, theirs])
	if pairs.is_empty():
		return _no("they have no free ends that take each other: a click hinge's finger and fork, a hinge's pin and its eye, or a clip and a bar")
	pairs.sort_custom(func(a: Array, b: Array) -> bool:
		return _start_gap(a) < _start_gap(b))
	var found: Array = []   ## [cost, turns, pair]
	var nearest: float = INF
	for pair: Array in pairs.slice(0, 8):
		_meet_on(pair)
		for start: PackedFloat64Array in _starts():
			if _late():
				break
			var turned: PackedFloat64Array = _settle(start, _all_free())
			tries += 1
			var shut: Vector2 = _shut(turned)
			if shut.x > CLOSE_TO or shut.y > LINE_TO:
				nearest = minf(nearest, shut.x)
				continue
			var known: bool = false
			for kept: Array in found:
				if kept[2] == pair and _same_turns(kept[1], turned):
					known = true
					break
			if not known:
				found.append([_cost(turned), turned, pair])
	if found.is_empty():
		gap = nearest
		return _no("no swing of the %s between them makes them meet: the nearest leaves them %s apart"
			% [_joints_words(), _plates_words(nearest)])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var refused: String = ""
	for kept: Array in found:
		_meet_on(kept[2])
		var turned: PackedFloat64Array = _on_clicks(kept[1])
		if turned.is_empty():
			if refused.is_empty():
				refused = "they meet only between the hinges' clicks: no setting of the clicks closes the gap"
			continue
		var pose: Dictionary = _pose(turned)
		var blocked: Array = _blocked(pose)
		if not blocked.is_empty():
			if refused.is_empty() or refused.begins_with("they meet only"):
				refused = "they could meet, but %s would %s" % [_named(int(blocked[0])),
					"go through the floor" if int(blocked[1]) < 0 else "run into %s" % _named(int(blocked[1]))]
			continue
		placed = pose
		turns = PackedFloat64Array()
		lines.clear()
		for n: int in turned.size():
			turns.append(rad_to_deg(turned[n]))
			lines.append([_point[n], _axis[n]])
		met = [int(_one[0]), int(_other[0]), (_one[1] as End).words]
		said = "met: %s" % _turned_words(turns)
		return true
	return _no(refused)


func _no(words: String) -> bool:
	why = words
	return false


func _late() -> bool:
	return float(Time.get_ticks_usec() - _began) / 1000.0 > MOST_MS


# -- the chain ---------------------------------------------------------------------


## The joints from each body back to the body both hang from, each side's
## from that body out; every part beyond each, and which joints carry it.
func _chain_between(body_one: int, body_other: int) -> bool:
	var ups_one: Array = _ups(body_one)
	var ups_other: Array = _ups(body_other)
	var on_one: Dictionary = {}
	for body: int in ups_one:
		on_one[body] = true
	var common: int = -1
	for body: int in ups_other:
		if on_one.has(body):
			common = body
			break
	if common < 0:
		return _no("they are not joined: Meet swings the joints between two parts of one model")
	for ups: Array in [ups_one, ups_other]:
		var side: Array = []
		for body: int in ups:
			if body == common:
				break
			side.push_front(body)
		var parent: int = -1
		for child: int in side:
			var link: Bodies.Link = bodies.parent_link[child]
			if link.axis == Vector3.ZERO or not link.turns:
				continue
			if _links.size() >= MOST_JOINTS:
				return _no("there are more than %d joints between them" % MOST_JOINTS)
			var inside: Dictionary = {}
			for body: int in bodies.beyond(child):
				inside[body] = true
			if not bodies.loops_out(inside, link).is_empty():
				return _no("a joint between them is held at both ends by a loop elsewhere in the model")
			var axis: Vector3 = link.axis.normalized()
			# Each line one way round, the first's: every joint turned the same
			# way bends a chain of parallel hinges into a curve, not a zigzag.
			if not _axis.is_empty() and axis.dot(_axis[0]) < 0.0:
				axis = -axis
			_links.append(link)
			_point.append(link.point)
			_axis.append(axis)
			_parent.append(parent)
			_detent.append(link.detent)
			_child.append(child)
			parent = _links.size() - 1
			for brick_id: int in bodies.parts_of(bodies.beyond(child)):
				_deepest[brick_id] = parent
				_carried[brick_id] = str(_carried.get(brick_id, "")) + ",%d" % parent
				if not rest.has(brick_id):
					rest[brick_id] = world.get_brick(brick_id).transform
	if _links.is_empty():
		return _no("no hinge, clip or turntable between them turns")
	for n: int in _links.size():
		if _detent[n] > 0.0:
			var square: Array = _square_of_joint(n)
			if not square.is_empty():
				_clicks.append([n, square[0], square[1]])
	return true


## A body and every body it hangs from, out to the anchor.
func _ups(body: int) -> Array:
	var out: Array = [body]
	var at: int = body
	while bodies.parent_of.has(at):
		at = int(bodies.parent_of[at])
		out.append(at)
	return out


## The free ends of [param body]'s parts, [part, End] each, [param first]'s
## own first.
func _free_ends(body: int, first: int) -> Array:
	var out: Array = []
	var parts: Array = Array(bodies.members[body] as PackedInt64Array)
	parts.erase(first)
	parts.push_front(first)
	for brick_id: int in parts:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		for end: End in HingeAlign.ends_of(library.mesh_for(brick.part_id)):
			if not _taken(brick_id, end):
				out.append([brick_id, end])
	return out


## Whether another part has an end that takes [param end] on its line,
## overlapping it: a fork with a finger in it.
func _taken(brick_id: int, end: End) -> bool:
	var at: Transform3D = world.get_brick(brick_id).transform
	var middle: Vector3 = at * end.middle
	var way: Vector3 = (at.basis * end.way).normalized()
	var reach := Vector3.ONE * (end.half + ROUND_MOST + 2.0)
	var low: Vector3i = BrickLattice.to_cell(middle - reach)
	var high: Vector3i = BrickLattice.to_cell(middle + reach)
	for other: int in builder.lattice.near_bounds(PackedInt32Array([low.x, low.y, low.z,
			high.x + 1, high.y + 1, high.z + 1]), brick_id):
		var brick: BrickWorld.Brick = world.get_brick(other)
		if brick == null:
			continue
		for theirs: End in HingeAlign.ends_of(library.mesh_for(brick.part_id)):
			if not end.takes(theirs):
				continue
			var their_way: Vector3 = (brick.transform.basis * theirs.way).normalized()
			if absf(their_way.dot(way)) < COAXIAL:
				continue
			var apart: Vector3 = brick.transform * theirs.middle - middle
			var along: float = apart.dot(way)
			if (apart - way * along).length() <= ON_LINE and absf(along) < end.half + theirs.half:
				return true
	return false


# -- where everything stands -----------------------------------------------------------


func _all_free() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(_links.size())
	out.fill(1)
	return out


## Each joint's frame at [param at]: its turn about its line where it stood,
## carried by the joints outside it.
func _frames(at: PackedFloat64Array) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for n: int in _links.size():
		var turn := Basis(_axis[n], at[n])
		var about := Transform3D(turn, _point[n] - turn * _point[n])
		out.append(out[_parent[n]] * about if _parent[n] >= 0 else about)
	return out


func _place(brick_id: int, frames: Array[Transform3D]) -> Transform3D:
	var stood: Transform3D = rest.get(brick_id, world.get_brick(brick_id).transform)
	if not _deepest.has(brick_id):
		return stood
	return frames[int(_deepest[brick_id])] * stood


## Every part that moves, where [param at] puts it.
func _pose(at: PackedFloat64Array) -> Dictionary:
	var frames: Array[Transform3D] = _frames(at)
	var out: Dictionary = {}
	for brick_id: int in rest:
		var placed_at: Transform3D = _place(brick_id, frames)
		out[brick_id] = Transform3D(placed_at.basis.orthonormalized(), placed_at.origin)
	return out


func _meet_on(pair: Array) -> void:
	_one = pair[0]
	_other = pair[1]
	var clicks: bool = (_one[1] as End).family == "hinge" or (_other[1] as End).family == "hinge"
	_meet_detent = Bodies.CLICK_STEP if clicks else 0.0


## The two ends where [param frames] put them: [middle, way, arm] each, the
## arm the way from the end's middle to its part's middle, square to its line.
func _ends_at(frames: Array[Transform3D]) -> Array:
	var out: Array = []
	for side: Array in [_one, _other]:
		var at: Transform3D = _place(int(side[0]), frames)
		var end: End = side[1]
		var middle: Vector3 = at * end.middle
		var way: Vector3 = (at.basis * end.way).normalized()
		var mesh: Lbm.PartMesh = library.mesh_for(world.get_brick(int(side[0])).part_id)
		var arm: Vector3 = at * mesh.bounds.get_center() - middle
		arm -= way * arm.dot(way)
		out.append([middle, way, arm.normalized() if arm.length() > 0.01 else Vector3.ZERO])
	return out


## How far apart the two ends are at [param at]: Vector2(LDU, radians).
func _shut(at: PackedFloat64Array) -> Vector2:
	var ends: Array = _ends_at(_frames(at))
	return Vector2((ends[0][0] as Vector3).distance_to(ends[1][0]),
		(ends[0][1] as Vector3).cross(ends[1][1]).length())


func _start_gap(pair: Array) -> float:
	_meet_on(pair)
	return _shut(_zero()).x


func _zero() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(_links.size())
	return out


## What is weighed: the gap times the root of [param weight], the gap
## between the lines, each free joint's bend (2 sin(turn / 2)), and the bend
## of the joint the meeting makes (the sum of its two arms, 2 sin(bend / 2)).
func _residual(at: PackedFloat64Array, loose: PackedByteArray, weight: float) -> PackedFloat64Array:
	var ends: Array = _ends_at(_frames(at))
	var out := PackedFloat64Array()
	var root: float = sqrt(weight)
	var off: Vector3 = (ends[0][0] as Vector3) - (ends[1][0] as Vector3)
	var lean: Vector3 = (ends[0][1] as Vector3).cross(ends[1][1]) * AXIS_SCALE
	for n: int in 3:
		out.append(off[n] * root)
	for n: int in 3:
		out.append(lean[n] * root)
	for n: int in at.size():
		if loose[n] == 1:
			out.append(2.0 * sin(at[n] * 0.5))
	var bend: Vector3 = (ends[0][2] as Vector3) + (ends[1][2] as Vector3)
	for n: int in 3:
		out.append(bend[n])
	return out


## The bends weighed: every joint's and the meeting's, squared.
func _cost(at: PackedFloat64Array) -> float:
	var r: PackedFloat64Array = _residual(at, _all_free(), 0.0)
	var total: float = 0.0
	for n: int in range(6, r.size()):
		total += r[n] * r[n]
	return total


static func _square(r: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value: float in r:
		total += value * value
	return total


## From [param start], the turns of the [param free] joints that shut the
## gap with the least bending: Levenberg-Marquardt, the gap weighed more
## each round.
func _settle(start: PackedFloat64Array, loose: PackedByteArray) -> PackedFloat64Array:
	var at := PackedFloat64Array(start)
	var cols := PackedInt32Array()
	for n: int in loose.size():
		if loose[n] == 1:
			cols.append(n)
	if cols.is_empty():
		return at
	for weight: float in WEIGHTS:
		var damping: float = 1.0e-3
		var r: PackedFloat64Array = _residual(at, loose, weight)
		var cost: float = HingeAlign._square(r)
		for _step: int in STEPS:
			# The slope, column by column, each joint nudged both ways.
			var slope: Array = []
			for col: int in cols:
				var up := PackedFloat64Array(at)
				var down := PackedFloat64Array(at)
				up[col] += NUDGE
				down[col] -= NUDGE
				var ru: PackedFloat64Array = _residual(up, loose, weight)
				var rd: PackedFloat64Array = _residual(down, loose, weight)
				var column := PackedFloat64Array()
				column.resize(r.size())
				for i: int in r.size():
					column[i] = (ru[i] - rd[i]) / (2.0 * NUDGE)
				slope.append(column)
			var k: int = cols.size()
			var normal := PackedFloat64Array()
			normal.resize(k * k)
			var pull := PackedFloat64Array()
			pull.resize(k)
			for a: int in k:
				var ca: PackedFloat64Array = slope[a]
				var g: float = 0.0
				for i: int in r.size():
					g += ca[i] * r[i]
				pull[a] = -g
				for b: int in range(a, k):
					var cb: PackedFloat64Array = slope[b]
					var dot: float = 0.0
					for i: int in r.size():
						dot += ca[i] * cb[i]
					normal[a * k + b] = dot
					normal[b * k + a] = dot
			var moved: bool = false
			for _try: int in 10:
				var damped := PackedFloat64Array(normal)
				for a: int in k:
					damped[a * k + a] += damping * maxf(normal[a * k + a], 1.0e-9) + 1.0e-12
				var step: PackedFloat64Array = Swing.solve(damped, pull)
				var most: float = 0.0
				for value: float in step:
					most = maxf(most, absf(value))
				if most > MOST_STEP:
					for a: int in k:
						step[a] *= MOST_STEP / most
				var tried := PackedFloat64Array(at)
				for a: int in k:
					tried[cols[a]] += step[a]
				var rt: PackedFloat64Array = _residual(tried, loose, weight)
				var tried_cost: float = HingeAlign._square(rt)
				if tried_cost < cost:
					var gain: float = cost - tried_cost
					at = tried
					r = rt
					cost = tried_cost
					damping = maxf(damping * 0.3, 1.0e-9)
					moved = gain > cost * 1.0e-10 + 1.0e-14
					break
				damping *= 10.0
			if not moved:
				break
	for col: int in cols:
		at[col] = wrapf(at[col], -PI, PI)
	return at


## Where each search starts: where it stands, every joint bent alike both
## ways, and a few bends at random.
func _starts() -> Array:
	var out: Array = [_zero()]
	for bend: float in BENDS:
		var at: PackedFloat64Array = _zero()
		at.fill(deg_to_rad(bend))
		out.append(at)
	var dice := RandomNumberGenerator.new()
	dice.seed = 4
	for _n: int in SHAKES:
		var at: PackedFloat64Array = _zero()
		for n: int in at.size():
			at[n] = dice.randf_range(-PI * 0.5, PI * 0.5)
		out.append(at)
	return out


static func _same_turns(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	for n: int in a.size():
		if absf(wrapf(a[n] - b[n], -PI, PI)) > 0.01:
			return false
	return true


# -- clicks ----------------------------------------------------------------------------


## How far a joint's two parts stand turned about its line from square, at
## rest, degrees, and which way a turn of the joint moves that: [degrees,
## +1 or -1], or [] when its line is not square to its parts.
func _square_of_joint(n: int) -> Array:
	var link: Bodies.Link = _links[n]
	if link.pairs.is_empty():
		return []
	var pair: Array = link.pairs[0]
	var near_child: Dictionary = {}
	for body: int in bodies.beyond(int(_child[n])):
		near_child[body] = true
	var child_part: int = int(pair[1]) if near_child.has(int(bodies.body_of.get(int(pair[1]), -1))) \
		else int(pair[0])
	var parent_part: int = int(pair[0]) if child_part == int(pair[1]) else int(pair[1])
	var parent_at: Transform3D = rest.get(parent_part, world.get_brick(parent_part).transform)
	var child_at: Transform3D = rest.get(child_part, world.get_brick(child_part).transform)
	var now: float = HingeAlign.from_square(parent_at.basis, child_at.basis, _axis[n])
	if is_nan(now):
		return []
	var nudge: float = 0.1
	var turned: float = HingeAlign.from_square(parent_at.basis,
		Basis(_axis[n], nudge) * child_at.basis, _axis[n])
	var moved: float = wrapf(turned - now, -45.0, 45.0)
	return [now, 1.0 if moved > 0.0 else -1.0]


## How far [param other] stands turned about [param way] from square to
## [param one], degrees, 0 up to 90; NAN when [param way] is not along one of
## [param one]'s own axes, nor one of [param other]'s.
static func from_square(one: Basis, other: Basis, way: Vector3) -> float:
	var a: Basis = one.orthonormalized()
	var b: Basis = other.orthonormalized()
	var line: Vector3 = (a.inverse() * way).normalized()
	var across := Vector3.ZERO
	var theirs := Vector3.ZERO
	for n: int in 3:
		var axis := Vector3.ZERO
		axis[n] = 1.0
		if absf(line.dot(axis)) < 0.01 and across == Vector3.ZERO:
			across = axis
		var mapped: Vector3 = a.inverse() * (b * axis)
		if absf(line.dot(mapped)) < 0.01 and theirs == Vector3.ZERO:
			theirs = mapped
	if across == Vector3.ZERO or theirs == Vector3.ZERO:
		return NAN
	var turned: float = rad_to_deg(atan2(line.dot(across.cross(theirs)), across.dot(theirs)))
	return fposmod(turned, 90.0)


static func _off_click(degrees: float, step: float) -> float:
	var off: float = fposmod(degrees, step)
	return minf(off, step - off)


## [param at] with every click joint on a click, the rest solved again each
## time one is set; and the joint the meeting makes on a click too. Empty
## when no setting of the clicks shuts the gap.
func _on_clicks(at: PackedFloat64Array) -> PackedFloat64Array:
	var loose: PackedByteArray = _all_free()
	var now := PackedFloat64Array(at)
	var left: Array = _clicks.duplicate()
	while not left.is_empty():
		# The one nearest a click goes first.
		var best: int = 0
		var best_off: float = INF
		for n: int in left.size():
			var click: Array = left[n]
			var off: float = _off_click(float(click[1]) + float(click[2]) * rad_to_deg(now[int(click[0])]),
				_detent[int(click[0])])
			if off < best_off:
				best_off = off
				best = n
		var click: Array = left[best]
		left.remove_at(best)
		var joint: int = int(click[0])
		var step: float = _detent[joint]
		var stands: float = float(click[1]) + float(click[2]) * rad_to_deg(now[joint])
		var nearest: float = roundf(stands / step) * step
		var kept: bool = false
		for to: float in [nearest, nearest + step * signf(stands - nearest), nearest - step * signf(stands - nearest)]:
			var tried := PackedFloat64Array(now)
			tried[joint] = deg_to_rad((to - float(click[1])) * float(click[2]))
			loose[joint] = 0
			var settled: PackedFloat64Array = _settle(tried, loose)
			var shut: Vector2 = _shut(settled)
			if shut.x <= CLOSE_TO and shut.y <= LINE_TO:
				now = settled
				kept = true
				break
		if not kept:
			return PackedFloat64Array()
	if _meet_detent > 0.0:
		var frames: Array[Transform3D] = _frames(now)
		var one: Transform3D = _place(int(_one[0]), frames)
		var other: Transform3D = _place(int(_other[0]), frames)
		var square: float = HingeAlign.from_square(one.basis, other.basis,
			(one.basis * (_one[1] as End).way).normalized())
		if not is_nan(square) and _off_click(square, _meet_detent) > ON_A_CLICK:
			return PackedFloat64Array()
	return now


# -- room ------------------------------------------------------------------------------


## The first two parts that would overlap at [param pose], [moving, other],
## or [] for room; [moving, -1] for one that would go below the model's
## lowest point, through the floor. A part may press on what it is joined to
## (a joint's pair, the two that meet) and on what it moves with; anything
## else in its way is in the way.
func _blocked(pose: Dictionary) -> Array:
	var lattice: BrickLattice = builder.lattice
	var lowest: float = INF
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			lowest = minf(lowest, mesh.lowest_at(brick.transform))
	for brick_id: int in pose:
		var mesh: Lbm.PartMesh = library.mesh_for(world.get_brick(brick_id).part_id)
		if mesh != null and mesh.lowest_at(pose[brick_id]) < lowest - BELOW_FLOOR:
			return [brick_id, -1]
	var joined: Dictionary = {}
	for link: Bodies.Link in bodies.links:
		for pair: Array in link.pairs:
			joined["%d|%d" % [pair[0], pair[1]]] = true
			joined["%d|%d" % [pair[1], pair[0]]] = true
	joined["%d|%d" % [_one[0], _other[0]]] = true
	joined["%d|%d" % [_other[0], _one[0]]] = true
	var was: Dictionary = {}
	for brick_id: int in pose:
		was[brick_id] = lattice.boxes_of(brick_id)
		lattice.release(brick_id)
	var out: Array = []
	var put: Array = []
	for brick_id: int in pose:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var packed: PackedInt32Array = builder.boxes_for(library.mesh_for(brick.part_id), pose[brick_id])
		for other: int in lattice.blockers_boxes(packed, brick_id):
			if joined.has("%d|%d" % [brick_id, other]):
				continue
			if str(_carried.get(other, "")) == str(_carried.get(brick_id, "")):
				continue
			if bodies.body_of.get(other, -1) == bodies.body_of.get(brick_id, -2):
				continue
			out = [brick_id, other]
			break
		if not out.is_empty():
			break
		lattice.occupy_boxes(brick_id, packed)
		put.append(brick_id)
	for brick_id: int in put:
		lattice.release(brick_id)
	for brick_id: int in was:
		lattice.occupy_boxes(brick_id, was[brick_id])
	return out


# -- keeping it --------------------------------------------------------------------------


## Stand every part where [member placed] says, as one step to undo. Returns
## how many moved.
func commit() -> int:
	var steps: Array = []
	for brick_id: int in placed:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var to: Transform3D = placed[brick_id]
		if Grab._same(to, rest[brick_id]):
			continue
		steps.append({"undo": "move", "brick": brick_id, "transform": rest[brick_id]})
		world.move_brick(brick_id, to)
		builder.lattice.release(brick_id)
		builder.lattice.occupy_boxes(brick_id, builder.boxes_for(library.mesh_for(brick.part_id), to))
	builder.record(steps, "swung %s so two parts meet" % _joints_words())
	return steps.size()


# -- words -------------------------------------------------------------------------------


func _named(brick_id: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
	return "the %s" % (Inventory._tidy(info.name) if info != null else "part")


## "the 7 joints", "the hinge".
func _joints_words() -> String:
	var kinds: Dictionary = {}
	for link: Bodies.Link in _links:
		kinds[link.kind] = true
	var noun: String = "hinge" if kinds.size() == 1 and (kinds.has("hinge") or kinds.has("click")) \
		else "joint"
	if _links.size() == 1:
		return "the %s" % noun
	return "%d %ss" % [_links.size(), noun]


## "1.5 plates", "a third of a plate".
static func _plates_words(ldu: float) -> String:
	if is_inf(ldu):
		return "as far apart as they are"
	var plates: float = ldu / 8.0
	if plates < 0.95:
		return "%s LDU" % Balance.tidy(ldu)
	return "%s plate%s" % [Balance.studs(plates), "" if is_equal_approx(snappedf(plates, 0.1), 1.0) else "s"]


## "7 hinges swung 45° each", "2 joints swung 31° and -12°".
func _turned_words(degrees: PackedFloat64Array) -> String:
	var shown := PackedStringArray()
	var alike: bool = true
	for value: float in degrees:
		shown.append("%d°" % roundi(value))
		if absf(value - degrees[0]) > 0.5:
			alike = false
	if degrees.size() > 1 and alike:
		return "%s swung %s each" % [_joints_words(), shown[0]]
	if shown.size() > 6:
		return "%s swung %s and %d more" % [_joints_words(), ", ".join(shown.slice(0, 6)),
			shown.size() - 6]
	var listed: String = shown[0] if shown.size() == 1 else "%s and %s" % [
		", ".join(shown.slice(0, shown.size() - 1)), shown[shown.size() - 1]]
	return "%s swung %s" % [_joints_words(), listed]
