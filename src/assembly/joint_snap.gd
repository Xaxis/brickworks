## Where the part in hand goes when it is aimed at a connector of a part
## already down: a pin into a pin hole, an axle into an axle hole or a
## round one, a beam's hole onto a pin or an axle, a clip onto a bar and a
## bar into a clip. BrickLink Studio does this. Until it was done here a
## part by hand went on studs or against a face, so a pin could not be put
## into a hole at all, and nothing Technic could be built by hand.
##
## Two halves. [method ends_of] reads a part's connectors as the ends it
## joins by, in its own frame: where each is, which way it points, how
## deep a hole is and how far a pin reaches. [method pose] puts one end of
## the part in hand on one end of a part already down: the axes made one,
## the end where the joint puts it, and turned about the shared axis by a
## roll. Whether the pose has room is not decided here: the builder asks
## that by the rule check_design uses (Builder.room_for).
class_name JointSnap
extends RefCounted

## How near the pointer's line a connector has to be to be aimed at, in
## LDU. Under a stud, so of two holes side by side the one pointed at wins.
const REACH := 12.0
## A pin or an axle whose part goes on past its connector by at least this
## much, in LDU, is held by its collar: the collar goes to a hole's mouth
## and the rest into it. One that does not is an axle's tip, which goes in
## first and comes to rest at the far mouth, through the hole.
const COLLAR := 8.0
## The radius of a bar, in LDU, and of the clip that takes one. Only these
## rounds are snapped to: a pin's and a hole's are matched by their own
## connectors, and a hinge or a turntable is put together on its studs.
const BAR := 4.0
## How far a clip slides along a bar per step, in LDU: half a plate.
const SLIDE := 4.0
## A cross turns only by quarters in a cross; anything round in anything
## round turns freely, by this much a step unless the turn step is finer.
const CROSS_STEP := 90.0
const ROUND_STEP := 45.0

## What each kind of end in hand goes into or onto.
const TAKES: Dictionary = {
	"pin": ["pin_hole"],
	"axle": ["axle_hole", "pin_hole"],
	"pin_hole": ["pin", "axle"],
	"axle_hole": ["axle"],
	"shaft": ["bore"],
	"bore": ["shaft"],
}

## What the words for each kind of end are, as a person says them.
const SAID: Dictionary = {
	"pin": "pin", "axle": "axle", "pin_hole": "pin hole",
	"axle_hole": "axle hole", "shaft": "bar", "bore": "clip",
}


## One end a part joins by.
class End extends RefCounted:
	## pin, axle, pin_hole, axle_hole, shaft (a bar) or bore (a clip).
	var kind: String
	## A pin or an axle: where its connector is, a collar or a tip. A
	## hole: its middle. A bar or a clip: where it starts.
	var at: Vector3
	## Unit. A pin or an axle: out of the part. A bar or a clip: the way
	## it runs from [member at].
	var axis: Vector3
	## A pin or an axle: how far the part goes on past [member at] along
	## [member axis]. A hole: half its depth. A bar or a clip: its length.
	var reach: float = 0.0
	var radius: float = 0.0
	## The brick it belongs to, for an end on a part already down.
	var brick: int = 0

	func is_male() -> bool:
		return kind == "pin" or kind == "axle"

	func is_hole() -> bool:
		return kind == "pin_hole" or kind == "axle_hole"

	func is_round() -> bool:
		return kind == "shaft" or kind == "bore"

	## The same end on a part placed at [param where].
	func placed(where: Transform3D, brick_id: int) -> End:
		var out := End.new()
		out.kind = kind
		out.at = where * at
		out.axis = (where.basis * axis).normalized()
		out.reach = reach
		out.radius = radius
		out.brick = brick_id
		return out

	## Where this end is to look at: a hole's middle, the middle of what
	## a pin or an axle has left to go into something, a bar's or a
	## clip's middle.
	func middle() -> Vector3:
		if is_round():
			return at + axis * (reach * 0.5)
		return aimed(Vector3.ZERO, Vector3.FORWARD)

	## The point a person points at to mean this end: a hole's middle,
	## the middle of what a pin or an axle has left to go into something,
	## or where along a bar the line [param from] → [param way] passes
	## nearest.
	func aimed(from: Vector3, way: Vector3) -> Vector3:
		if is_hole():
			return at
		if is_male():
			if reach >= COLLAR:
				return at + axis * minf(reach, BrickLattice.STUD) * 0.5
			return at - axis * 5.0
		return at + axis * clampf(along_nearest(from, way), 0.0, reach)

	## How far along this end's line from [member at] the line from
	## [param from] going [param way] passes nearest it.
	func along_nearest(from: Vector3, way: Vector3) -> float:
		var w0: Vector3 = at - from
		var b: float = axis.dot(way)
		var d: float = axis.dot(w0)
		var e: float = way.dot(w0)
		var denominator: float = 1.0 - b * b
		if denominator < 1e-6:
			return 0.0
		return (b * e - d) / denominator


## A part's ends in its own frame, worked out once per part.
static var _ends: Dictionary = {}


static func ends_of(part: Lbm.PartMesh) -> Array:
	if part == null:
		return []
	var key: int = part.get_instance_id()
	if _ends.has(key):
		return _ends[key]
	var out: Array = []
	for connector: Lbm.Connector in part.connectors:
		var end := End.new()
		end.kind = connector.kind
		end.axis = connector.axis.normalized()
		if end.axis.length_squared() < 0.5:
			continue
		match connector.kind:
			"pin", "axle":
				if connector.gender != "male":
					continue
				end.at = connector.position
				end.reach = maxf(_extent(part.bounds, end.at, end.axis).y, 0.0)
			"pin_hole", "axle_hole":
				var span: Vector2 = _hole_span(part, connector.position, end.axis)
				end.at = connector.position + end.axis * (span.x + span.y) * 0.5
				end.reach = (span.y - span.x) * 0.5
				if end.reach < 1.0:
					continue
			"shaft", "bore":
				if absf(connector.radius - BAR) > Joints.ROUND_FIT or connector.length < 1.0:
					continue
				end.at = connector.position
				end.reach = connector.length
				end.radius = connector.radius
			_:
				continue
		if not _repeats(out, end):
			out.append(end)
	# A round hole a pin's size that LDraw draws as a plain cylinder, not a
	# Technic hole: the steering ends of 4262 (8841-1 hangs its pan from
	# two), which a pin goes through as it goes through any hole. As deep
	# as the part is there, from the hole's mouth, no more than a stud: the
	# file has the plate's body against the pin's collar, past the end's
	# thinner hole. And with no counterbore for the collar to sit in, its
	# mouth is that much further out than a Technic hole's. Through a
	# plate's thickness at most: a round brick's hollow is that radius too,
	# and is no hole.
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "bore" or connector.length < 4.0 or connector.length > 8.0 \
				or absf(connector.radius - PIN_ROUND) > 0.5:
			continue
		var end := End.new()
		end.kind = "pin_hole"
		end.axis = connector.axis.normalized()
		if end.axis.length_squared() < 0.5 or _on_a_hole(out, connector.position, end.axis):
			continue
		var deep: float = clampf(_extent(part.bounds, connector.position, end.axis).y,
			connector.length, BrickLattice.STUD)
		end.at = connector.position + end.axis * deep * 0.5
		end.reach = deep * 0.5 + COUNTERBORE
		if not _repeats(out, end):
			out.append(end)
	_ends[key] = out
	return out


## The radius of a pin, and of a round hole one goes through, in LDU.
const PIN_ROUND := 6.0
## How deep a Technic hole's counterbore takes a pin's collar, in LDU: a
## pin's connector is the middle of its collar, which sits half in.
const COUNTERBORE := 2.0


## Whether a hole already found runs along the line through [param at]
## going [param axis]: a Technic hole's own bore is that hole.
static func _on_a_hole(ends: Array, at: Vector3, axis: Vector3) -> bool:
	for other: End in ends:
		if not other.is_hole() or absf(other.axis.dot(axis)) < 0.999:
			continue
		var gap: Vector3 = at - other.at
		if (gap - axis * gap.dot(axis)).length() <= Joints.ROUND_OFF_AXIS:
			return true
	return false


## Whether an end is already in the list: the same kind, the same way, at
## nearly the same place (3705 has two connectors at one tip).
static func _repeats(ends: Array, end: End) -> bool:
	for other: End in ends:
		if other.kind == end.kind and other.axis.dot(end.axis) > 0.999 \
				and other.at.distance_to(end.at) < 4.0 \
				and absf(other.reach - end.reach) < 4.0:
			return true
	return false


## How far a box reaches behind and ahead of a point along an axis.
static func _extent(box: AABB, from: Vector3, axis: Vector3) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for n: int in 8:
		var along: float = (box.get_endpoint(n) - from).dot(axis)
		low = minf(low, along)
		high = maxf(high, along)
	return Vector2(low, high)


## Where a hole runs, along its axis from its connector: from its own
## bores where it has them (a pin hole is a bore 6 across with a
## counterbore 8 across at each mouth), or the part's own thickness there,
## no more than a stud each way, where it has none (an axle hole is a
## cross, which is not round).
static func _hole_span(part: Lbm.PartMesh, at: Vector3, axis: Vector3) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "bore" or connector.radius < 5.0 or connector.radius > 9.0:
			continue
		if absf(connector.axis.dot(axis)) < 0.999:
			continue
		var gap: Vector3 = connector.position - at
		if (gap - axis * gap.dot(axis)).length() > Joints.ROUND_OFF_AXIS:
			continue
		var a: float = gap.dot(axis)
		var b: float = a + connector.length * connector.axis.dot(axis)
		if minf(a, b) > 12.0 or maxf(a, b) < -12.0:
			continue
		low = minf(low, minf(a, b))
		high = maxf(high, maxf(a, b))
	if low < high:
		return Vector2(low, high)
	var span: Vector2 = _extent(part.bounds, at, axis)
	return Vector2(maxf(span.x, -BrickLattice.STUD), minf(span.y, BrickLattice.STUD))


## Whether an end in hand goes onto or into an end already down.
static func mates(held: End, site: End) -> bool:
	if not (TAKES.get(held.kind, []) as Array).has(site.kind):
		return false
	if held.is_round():
		return absf(held.radius - site.radius) <= Joints.ROUND_FIT
	return true


## How far a turn about this joint goes per step, in degrees: a quarter
## for a cross in a cross, otherwise [param fine] if it is finer than
## [constant ROUND_STEP].
static func step_of(held: End, site: End, fine: float) -> float:
	if (held.kind == "axle" or held.kind == "axle_hole") \
			and (site.kind == "axle" or site.kind == "axle_hole"):
		return CROSS_STEP
	return minf(ROUND_STEP, fine) if fine > 0.0 else ROUND_STEP


## The ways one end in hand can go on one end already down, in the order
## they are offered: [side, slide] pairs. Side is which way along the
## joint's axis the part goes (a pin from the near or the far face of a
## beam, a beam the right way up or over); slide is, for a clip or a bar,
## where along the other the middle of this one goes, in LDU from the
## other's start. [param from] is where the pointer's line starts, which
## says which face is near.
static func ways(held: End, site: End, from: Vector3, way: Vector3) -> Array:
	var middle: Vector3 = site.at + site.axis * (site.reach * 0.5) if site.is_round() \
		else site.at
	var near: int = 1 if site.axis.dot(from - middle) >= 0.0 else -1
	if held.is_male():
		return [[near, 0.0], [-near, 0.0]]
	if held.is_hole():
		return [[1, 0.0], [-1, 0.0]]
	var length: float = held.reach
	var room: float = site.reach
	var out: Array = []
	if length <= room:
		# A clip on a bar: where the pointer is along the bar, on a step
		# from the bar's middle, so a clip as long as the bar but a step
		# can still sit square in the middle of it.
		var low: float = length * 0.5
		var high: float = room - length * 0.5
		var middle_of: float = room * 0.5
		var want: float = clampf(site.along_nearest(from, way), low, high)
		var slide: float = clampf(middle_of + roundf((want - middle_of) / SLIDE) * SLIDE,
			low, high)
		for side: int in [1, -1]:
			out.append([side, slide])
		return out
	# A bar through a clip: its end at the clip, running towards the
	# viewer, or away, or the clip at its middle.
	var toward: float = room - length * 0.5 if near < 0 else length * 0.5
	var away: float = length * 0.5 if near < 0 else room - length * 0.5
	for slide: float in [toward, away, room * 0.5]:
		for side: int in [1, -1]:
			out.append([side, slide])
	return out


## Where the part goes to put [param held] (in its own frame) on
## [param site] (in the world): the way it goes and where along it, from
## [method ways], and turned [param roll] degrees about the joint. Starts
## from [param basis], the way the part is held, turned as little as will
## line it up, so a part keeps the turn it was given.
static func pose(held: End, site: End, side: int, slide: float, roll: float,
		basis: Basis) -> Transform3D:
	var along: Vector3 = site.axis
	var facing: Vector3
	var target: Vector3
	var anchor: Vector3 = held.at
	if held.is_male():
		# Into a hole from one face: the part's end points into it.
		facing = along * -side
		var mouth: Vector3 = site.at + along * (site.reach * side)
		target = mouth if held.reach >= COLLAR else site.at - along * (site.reach * side)
	elif held.is_hole():
		# Over a pin, against its collar; over an axle's tip, flush with it.
		facing = along * side
		target = site.at + site.axis * held.reach if site.reach >= COLLAR \
			else site.at - site.axis * held.reach
	else:
		facing = along * side
		anchor = held.at + held.axis * (held.reach * 0.5)
		target = site.at + along * slide
	var turned: Basis = _turned_onto(basis, held.axis, facing)
	turned = Basis(along, deg_to_rad(roll)) * turned
	turned = _tidy(turned)
	var origin: Vector3 = target - turned * anchor
	return Transform3D(turned, Vector3(snappedf(origin.x, 0.001), snappedf(origin.y, 0.001),
		snappedf(origin.z, 0.001)))


## [param basis] turned as little as takes [param axis] (in the part's own
## frame) to point along [param facing].
static func _turned_onto(basis: Basis, axis: Vector3, facing: Vector3) -> Basis:
	var now: Vector3 = (basis * axis).normalized()
	var dot: float = now.dot(facing)
	if dot > 0.99999:
		return basis
	var arc: Quaternion
	if dot < -0.99999:
		# Half a turn, about the square axis least along the facing.
		var about: Vector3 = Vector3.UP if absf(facing.y) < 0.9 else Vector3.RIGHT
		about = (about - facing * about.dot(facing)).normalized()
		arc = Quaternion(about, PI)
	else:
		arc = Quaternion(now, facing)
	return (Basis(arc) * basis).orthonormalized()


## A basis within a whisker of one of the twenty-four square ones made
## exactly that one, so a part turned onto a square joint is square.
static func _tidy(basis: Basis) -> Basis:
	var square: Basis = BrickLattice.snap_basis(basis)
	for n: int in 3:
		if (square[n] - basis[n]).length() > 0.001:
			return basis.orthonormalized()
	return square


## The ends of every brick down, in the world, for the ends in hand to be
## put on.
static func sites_in(world: BrickWorld, library: PartLibrary) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		for end: End in ends_of(part):
			out.append(end.placed(brick.transform, brick.id))
	return out


## The end of all [param sites] the pointer's line is aimed at, that
## [param held] has an end for: nearest the line, within [constant REACH],
## no further along it than [param before] (where it met something), and
## the nearer of two as near, on no brick in [param unseen] (hidden, which
## the pointer passes through). Null when there is none.
static func aimed_at(sites: Array, held: Array, from: Vector3, way: Vector3,
		before: float, unseen: Dictionary = {}) -> End:
	var wanted: Dictionary = {}
	for end: End in held:
		for kind: String in TAKES.get(end.kind, []):
			wanted[kind] = true
	var best: End = null
	var best_off: float = REACH
	var best_along: float = INF
	for site: End in sites:
		if not wanted.has(site.kind) or unseen.has(site.brick):
			continue
		var usable: bool = false
		for end: End in held:
			if mates(end, site):
				usable = true
				break
		if not usable:
			continue
		var point: Vector3 = site.aimed(from, way)
		var along: float = (point - from).dot(way)
		if along <= 0.0 or along > before:
			continue
		var off: float = ((point - from) - way * along).length()
		if off < best_off - 0.5 or (off <= best_off + 0.5 and along < best_along):
			best = site
			best_off = minf(off, best_off)
			best_along = along
	return best


## Every way the part's ends go on [param site], in the order offered:
## [end, side, slide].
static func choices(held: Array, site: End, from: Vector3, way: Vector3) -> Array:
	var out: Array = []
	for end: End in held:
		if not mates(end, site):
			continue
		for pair: Array in ways(end, site, from, way):
			out.append([end, pair[0], pair[1]])
	return out


## In words: "the pin hole of Technic Brick 1 x 2 with Hole". A bore a
## bar's size is a clip on a part named for one, and otherwise a hollow:
## a hollow stud's, or a pin's middle.
static func describe(site: End, name: String) -> String:
	var said: String = SAID.get(site.kind, site.kind)
	if site.kind == "bore" and not name.to_lower().contains("clip"):
		said = "hollow"
	return "the %s of %s" % [said, name]
