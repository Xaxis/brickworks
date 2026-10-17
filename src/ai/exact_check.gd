## The build check as strict as BrickBench's: exact shapes, exact seats, and
## every piece held by a connection.
##
## Measured on BrickBench's Model setting (docs/BRICKBENCH.md, 2026-10-14):
## our check passed every part of ten designs and verify.py refused eight of
## them, on 46 colliding pairs our 2 LDU lattice forgives and on decorations
## resting with nothing holding them. This is what the check does about it,
## with Exact for the geometry:
##
## - Where both parts have an exact shape, the shape decides whether they
##   overlap, not the lattice: more than 1 LDU through BrickNet's convex
##   pieces is a collision, a side stud in a brick's side and a hinge through
##   its other half included; a cover the lattice rounds into the next part,
##   which real sets showed it does, is not. The lattice still finds every
##   pair worth asking about, and decides for parts without a shape.
## - A part of this design no BrickNet connection joins, through other parts,
##   to the ground or to what was standing before is not held: it is a
##   fault, said with what it rests on and how to fix it.
## - Before any of that, a part of this design that misses a stud, a hole, a
##   hinge or a bar by a few LDU is moved onto it exactly (seat), as
##   BrickAgent's attach places a part by its connector.
##
## Kept out of assistant.gd, which builds one of these per check and asks it.
class_name ExactCheck
extends RefCounted

## How far a seat may move a part, in LDU. A placement written in whole
## studs misses a part drawn off its box by a few LDU (a crystal 4 each way
## off its stud, docs/BRICKBENCH.md), and a tile stood on a side stud a plate
## (8) off it; a jumper's half stud (10) is a placement on purpose.
const SEAT_REACH := 8.0
## How near the ground counts as on it, in LDU: as near as a part counts as
## touching another (TOUCH), since a piece that much above the floor drops
## onto it, which BrickBench's simulation lets pass. A skeleton's feet are
## drawn an LDU or two above where its cover meets the floor.
const ON_GROUND := 2.5
## How near the ground a part stands on it, which a seat never moves it off.
const STANDS := 0.5
## A mate this far off is said as the fix for a collision, in LDU.
const FIX_REACH := 24.0

var shapes: Dictionary = {}    ## part id -> Exact.Shape
var items: Array = []          ## placement index, then standing: Exact.Item or null
var parts: PackedStringArray = PackedStringArray()
## Lattice key of a brick standing (negative) -> its index in items.
var standing_at: Dictionary = {}
var placements: int = 0
## Pairs the exact shapes cleared or found colliding, "a,b" -> found or {}.
var _asked: Dictionary = {}
## What asking it has cost this check, in microseconds: the report says it.
var spent_usec: int = 0
## And by what it was spent on: seat, collisions, pieces, cleared, place.
var spent_on: Dictionary = {}


func _spent(on: String, began: int) -> void:
	var took: int = Time.get_ticks_usec() - began
	spent_usec += took
	spent_on[on] = int(spent_on.get(on, 0)) + took


func _init(of: Dictionary, placement_count: int) -> void:
	shapes = of
	placements = placement_count
	items.resize(placement_count)
	parts.resize(placement_count)


## Whether any part of the model has an exact shape at all: a build without
## the exact/ folder checks as it did.
func any() -> bool:
	return not shapes.is_empty()


func place(index: int, part_id: String, at: Transform3D) -> void:
	var began: int = Time.get_ticks_usec()
	parts[index] = part_id
	var shape: Exact.Shape = shapes.get(part_id)
	items[index] = Exact.Item.new(shape, at) if shape != null else null
	_spent("place", began)


func stand(key: int, part_id: String, at: Transform3D) -> void:
	standing_at[key] = items.size()
	parts.append(part_id)
	var shape: Exact.Shape = shapes.get(part_id)
	items.append(Exact.Item.new(shape, at) if shape != null else null)


## The item a lattice key names: a placement (index and one) or a brick
## standing (negative); -1 for none.
func item_of(key: int) -> int:
	if key > 0 and key - 1 < placements:
		return key - 1
	return int(standing_at.get(key, -1))


func _shaped(i: int) -> bool:
	return i >= 0 and i < items.size() and items[i] != null \
		and (items[i] as Exact.Item).shape.has_pieces()


## Whether items [param i] and [param j], which collide, are a part and the
## axle it is turned on: joined by an axle along one line, and clear once one
## turns about that line by up to 45 degrees. A Technic set draws its wheels
## spun on their axles (8281's sidecar, 16 degrees): the cross of the axle
## and of the hub no longer line up, and their real shapes meet, but in
## plastic the axle turns with the wheel. A wheel that runs into a ring the
## axle cannot pass is not cleared by any turn.
func turned_on_axle(i: int, j: int) -> bool:
	if not _shaped(i) or not _shaped(j):
		return false
	var a: Exact.Item = items[i]
	var b: Exact.Item = items[j]
	for edge: Array in Exact.connections(items, PackedInt32Array([i, j])):
		if int(edge[0]) != i and int(edge[2]) != i:
			continue
		var mine: int = int(edge[1]) if int(edge[0]) == i else int(edge[3])
		var theirs: int = int(edge[3]) if int(edge[0]) == i else int(edge[1])
		# A cross axle in a cross hole only: they turn together. A hinge or a
		# clip on a bar turned is a different pose, and one folded into its
		# base stays refused.
		var subs: Array = [a.shape.sub[mine], b.shape.sub[theirs]]
		if a.shape.kind[mine] != Exact.AXLE or not (subs.has(Exact.S_AXLE) and subs.has(Exact.S_CROSS)):
			continue
		var frame: Transform3D = a.at * a.shape.frames[mine]
		var axis: Vector3 = (-frame.basis.y).normalized()
		var point: Vector3 = frame.origin
		for degrees: int in range(1, 46):
			for sign: float in [1.0, -1.0]:
				var turn := Transform3D(Basis(axis, deg_to_rad(degrees * sign)), Vector3.ZERO)
				var about: Transform3D = Transform3D(Basis.IDENTITY, point) * turn \
					* Transform3D(Basis.IDENTITY, -point)
				if Exact.clash(a, Exact.Item.new(b.shape, about * b.at)).is_empty():
					return true
	return false


## The joints BrickNet's labels join items [param i] and [param j] by:
## [kind, connector of i, connector of j] each, the kind "ball", "hinge"
## (a turntable's too), "clip" (a bar in a clip), "pin" (a pin in its hole),
## "axle" (an axle in a cross hole or a round one), "fixed" or "stud".
func joints_between(i: int, j: int) -> Array:
	var out: Array = []
	if not _shaped(i) or not _shaped(j):
		return out
	for edge: Array in Exact.connections(items, PackedInt32Array([mini(i, j), maxi(i, j)])):
		var mine: int = int(edge[1]) if int(edge[0]) == i else int(edge[3])
		var theirs: int = int(edge[3]) if int(edge[0]) == i else int(edge[1])
		out.append([_joint_kind((items[i] as Exact.Item).shape, mine,
			(items[j] as Exact.Item).shape, theirs), mine, theirs])
	return out


## The round a joint's two parts are made to meet inside, by its kind: how
## far from a ball's middle, or from the line a part turns on, an overlap of
## the two is the joint, in LDU. Each is the part's own round with 1.5 LDU
## over, as a cover's slack is (Joints.ROUND_SLACK): a Joint-8 ball or a
## towball is 16 across; a bar 8, gripped by its clip (not its stop or a
## sword's guard, 12 across, which rest against the clip and must not be in
## it: model-010's sword through the hand, which verify.py refused); the mouth
## of a Technic hole 16, which a pin's collar and an axle's stop sit in; a
## hinge's knuckles and a lever's pivot 16.
const JOINT_ROUND: Dictionary = {"ball": 9.5, "clip": 5.5, "pin": 9.5, "axle": 9.5,
	"hinge": 9.5}

## Whether items [param i] and [param j], which collide, collide only where
## a joint joins them: the ball inside its socket, the bar inside its clip, a
## pin in its hole, an axle in its hole, a hinge's knuckles in each other.
## Every pair of their pieces that overlap must meet inside the round of one
## of the joints BrickNet's labels join them by ([constant JOINT_ROUND]); an
## overlap anywhere else (a socket's rim into the next plate's neck, a hinge
## folded into its base) keeps the pair a collision. The joint's kind, or "".
##
## Real sets are built this way: their ball joints, clips, hinges and pins
## meet by more than 1 LDU in BrickNet's convex pieces, which fill a socket's
## mouth and a clip's jaws where the plastic is hollow (docs/DESIGN_SCORES.md,
## "Technique: joints held by their real shapes"). BrickBench's verify.py
## forgives none of it, so a run kept to its parts (PartsOnly) keeps every one
## a collision.
func at_joint(i: int, j: int) -> String:
	if PartsOnly.active():
		return ""
	var reaches: Array = joint_reaches(i, j)
	if reaches.is_empty():
		return ""
	var kind: String = ""
	for hit: Array in reaches:
		var inside: String = ""
		for joint: Array in hit[1]:
			if float(joint[1]) <= float(JOINT_ROUND[joint[0]]):
				inside = joint[0]
				break
		if inside.is_empty():
			return ""
		kind = inside
	return kind


## For each pair of pieces of items [param i] and [param j] that overlap:
## [depth, [[joint kind, how far the overlap can reach from that joint's
## ball or line], ...]], over the joints of [constant JOINT_ROUND]'s kinds
## that join the two; [] when none does.
func joint_reaches(i: int, j: int) -> Array:
	var loci: Array = []
	for joint: Array in joints_between(i, j):
		if JOINT_ROUND.has(joint[0]):
			loci.append(_locus(i, j, joint))
	if loci.is_empty():
		return []
	var a: Exact.Item = items[i]
	var b: Exact.Item = items[j]
	var out: Array = []
	for hit: Array in Exact.overlaps(a, b):
		var reaches: Array = []
		for locus: Array in loci:
			reaches.append([locus[0], Exact.overlap_reach(a, int(hit[1]), b, int(hit[2]),
				locus[1], locus[2])])
		out.append([float(hit[0]), reaches])
	return out


## Where a joint is: [kind, its point, its line or zero]. A ball's point is
## the middle of the ball and its socket; anything else turns on the line of
## the part that goes in (the bar, the pin, the axle), through its connector.
## Seated as BrickNet joins them, within 3 LDU: real sets draw a towball 2.8
## LDU off its socket's middle (10283's steering) and a handle 2.3 off its
## clip's line (10315), and are built.
func _locus(i: int, j: int, joint: Array) -> Array:
	var a: Exact.Item = items[i]
	var b: Exact.Item = items[j]
	var fa: Transform3D = a.at * a.shape.frames[int(joint[1])]
	var fb: Transform3D = b.at * b.shape.frames[int(joint[2])]
	if joint[0] == "ball":
		return [joint[0], (fa.origin + fb.origin) * 0.5, Vector3.ZERO]
	var inner: Transform3D = fb if Exact.A_SIDE.has(a.shape.sub[int(joint[1])]) \
		and a.shape.kind[int(joint[1])] == Exact.AXLE else fa
	return [joint[0], inner.origin, (-inner.basis.y).normalized()]


static func _joint_kind(a: Exact.Shape, ka: int, b: Exact.Shape, kb: int) -> String:
	match a.kind[ka]:
		Exact.BALL:
			return "ball"
		Exact.HINGE:
			return "hinge"
		Exact.FIXED:
			return "fixed"
		Exact.AXLE:
			var subs: Array = [a.sub[ka], b.sub[kb]]
			if subs.has(Exact.S_CLIP):
				return "clip"
			if subs.has(Exact.S_PIN):
				return "pin"
			return "axle"
	return "stud"


## How two items meet: {} when their exact shapes are clear or meet only
## where a joint joins them ([method at_joint]), the collision otherwise, null
## when either has no shape to ask.
func between(i: int, j: int) -> Variant:
	if not _shaped(i) or not _shaped(j):
		return null
	var a: int = mini(i, j)
	var b: int = maxi(i, j)
	var key := Vector2i(a, b)
	if _asked.has(key):
		return _asked[key]
	var found: Dictionary = Exact.clash(items[a], items[b])
	# A ball in its socket, a bar in its clip: the joint, not a collision.
	if not found.is_empty() and not at_joint(a, b).is_empty():
		found = {}
	if not found.is_empty():
		found["a"] = a
		found["b"] = b
	_asked[key] = found
	return found


## [param blockers] without the ones the exact shapes clear of placement
## [param index]: the lattice rounds a cover out to whole cells, and two
## parts it calls overlapping can be clear by their shapes.
func drop_cleared(blockers: PackedInt64Array, index: int) -> PackedInt64Array:
	if blockers.is_empty() or not _shaped(index):
		return blockers
	var began: int = Time.get_ticks_usec()
	var kept := PackedInt64Array()
	for key: int in blockers:
		var found: Variant = between(index, item_of(key))
		if found is Dictionary and (found as Dictionary).is_empty():
			continue
		kept.append(key)
	_spent("cleared", began)
	return kept


## Pairs [i, j] (i < j) of items whose boxes overlap by more than [param by]
## on every axis (a negative one reaches that far apart), at least one of
## them in [param of]; every such pair when [param of] is empty. A few parts
## against a big model are set against each item directly: building the grid
## for 9,000 parts to ask about one would cost more than the asking.
func pairs_near(of: Dictionary, by: float) -> Array:
	if of.is_empty():
		return Exact.candidates(items, by)
	if of.size() * items.size() > 400000:
		return Exact.candidates(items, by, func(a: int, b: int) -> bool:
			return of.has(a) or of.has(b))
	var out: Array = []
	for i: Variant in of:
		var a: Exact.Item = items[int(i)]
		if a == null:
			continue
		for j: int in items.size():
			var b: Exact.Item = items[j]
			if j == int(i) or b == null or (of.has(j) and j < int(i)):
				continue
			if minf(a.hi.x, b.hi.x) - maxf(a.lo.x, b.lo.x) <= by \
					or minf(a.hi.y, b.hi.y) - maxf(a.lo.y, b.lo.y) <= by \
					or minf(a.hi.z, b.hi.z) - maxf(a.lo.z, b.lo.z) <= by:
				continue
			out.append(Vector2i(mini(int(i), j), maxi(int(i), j)))
	return out


## Every colliding pair the shapes find with at least one of the pair in
## [param of] (every pair when it is empty), i < j, items numbered as here.
func collisions(of: Dictionary) -> Array:
	var began: int = Time.get_ticks_usec()
	var out: Array = []
	for pair: Vector2i in pairs_near(of, Exact.TAU):
		var found: Variant = between(pair.x, pair.y)
		if found is Dictionary and not (found as Dictionary).is_empty():
			out.append(found)
	_spent("collisions", began)
	return out


## BrickNet's pieces over everything with a shape (only the items in [param
## among], when given), joined as well by [param extra] ([a, b] item pairs:
## what holds a part with no shape).
func pieces(extra: Array, among: Dictionary = {}) -> PackedInt32Array:
	var began: int = Time.get_ticks_usec()
	var these: Array = items
	if not among.is_empty():
		these = []
		these.resize(items.size())
		for i: Variant in among:
			these[int(i)] = items[int(i)]
	var edges: Array = Exact.connections(these)
	for pair: Array in extra:
		if among.is_empty() or (among.has(int(pair[0])) and among.has(int(pair[1]))):
			edges.append([int(pair[0]), 0, int(pair[1]), 0])
	var root: PackedInt32Array = Exact.pieces(items.size(), edges)
	_spent("pieces", began)
	return root


## The ground: y = 0, the floor every model stands on here. Within ON_GROUND
## a piece is held by it; [param within] 0.5 asks whether a part stands on
## it, which a seat never moves off it.
func on_ground(i: int, within: float = ON_GROUND) -> bool:
	return items[i] != null and (items[i] as Exact.Item).lo.y <= within


## Whether a piece of [param members] that nothing joins stands where it is,
## as BrickBench's simulation would leave it (two seconds of gravity, every
## piece a rigid body, friction high): clear of everything by its real shape,
## and its centre of mass over where it touches what is under and beside it,
## read off the parts' own convex pieces rather than their boxes. A dish lying
## on a round brick stands, and a log in the groove of two below it; a tile
## half off a round plate's edge, one flat against a wall and a gem on a
## slope do not.
func rests(members: Array) -> bool:
	var mine: Dictionary = {}
	for i: Variant in members:
		mine[int(i)] = true
	var mass: float = 0.0
	var middle := Vector3.ZERO
	var touching := PackedVector3Array()
	for i: Variant in members:
		var item: Exact.Item = items[int(i)]
		if item == null or not item.shape.has_pieces():
			return false
		for p: Exact.Piece in item.shape.pieces:
			var box: Array = Exact.box_in(p.lo, p.hi, item.at)
			var size: Vector3 = (box[1] as Vector3) - (box[0] as Vector3)
			var weight: float = maxf(size.x * size.y * size.z, 0.001)
			mass += weight
			middle += ((box[0] as Vector3) + (box[1] as Vector3)) * 0.5 * weight
		for j: int in Exact._near(items, int(i), PackedInt32Array(), TOUCH + Exact.TAU):
			if mine.has(j) or items[j] == null:
				continue
			var found: Variant = between(int(i), j)
			if found is Dictionary and not (found as Dictionary).is_empty():
				return false
			_touching(item, items[j], touching)
	if touching.size() < 3 or mass <= 0.0:
		return false
	# Square to gravity: a part tilted off it, nothing joining it, rolls or
	# slides off what it leans on (a flower at 35 degrees on a round plate,
	# held-out model-017, fell in BrickBench's simulation).
	for i: Variant in members:
		var b: Basis = (items[int(i)] as Exact.Item).at.basis
		if maxf(absf(b.x.normalized().y), maxf(absf(b.y.normalized().y),
				absf(b.z.normalized().y))) < SQUARE:
			return false
	var centre: Vector3 = middle / mass
	var under := PackedVector2Array()
	for point: Vector3 in touching:
		under.append(Vector2(point.x, point.z))
	if under.size() < 3:
		return false
	var hull: PackedVector2Array = Geometry2D.convex_hull(under)
	var over := Vector2(centre.x, centre.z)
	if not Geometry2D.is_point_in_polygon(over, hull):
		return false
	# And not on the edge of it, where the least push tips it.
	for k: int in hull.size() - 1:
		if Geometry2D.get_closest_point_to_segment(over, hull[k], hull[k + 1]).distance_to(over) < STEADY:
			return false
	return true


## Whether a piece of [param members] that only the floor holds stands on a
## bare floor, as BrickBench's simulation stands it: one rigid body on a plane
## through its lowest point, which fails a build when any of it moves more than
## 3 LDU in two seconds. So it is let settle, as a body does: from the points
## it touches the floor by it tips about the edge of them its centre of mass is
## past (or rolls, its centre over a line) until another point comes down, and
## again, until its centre is over where it touches. It stands when that moved
## its furthest point less than [constant BUDGET]. {} when it stands; else
## {"moved": LDU, "past": LDU its centre was past where it first touched,
## "line": true when that was a line or a point it rolls on, "way": the way it
## tips, "feet": the items it first touched the floor by, "high": its height}.
## Held-out model-042's potato (2026-10-15) stood on its shoes with its centre
## 16 LDU behind their heels, and model-047's trash can lay on its side on one
## line of its facets: our check held both by the floor, and verify.py's
## simulation tipped the one and rolled the other. A ball plate (22890) lying on
## its ball, 4 LDU under its plate, tilts onto its far edge and stands, as
## verify.py passes it.
func tips(members: Array) -> Dictionary:
	var mass: float = 0.0
	var middle := Vector3.ZERO
	var floor_at: float = INF
	for i: Variant in members:
		var item: Exact.Item = items[int(i)]
		if item != null and item.shape.has_pieces():
			floor_at = minf(floor_at, item.lo.y)
	if floor_at == INF:
		return {}
	# What can catch it within the budget: no point higher than the budget over
	# the floor comes down to it before the piece has moved further than that.
	var low := PackedVector3Array()
	var owner := PackedInt32Array()
	var far := PackedVector3Array()     ## each item's box corners: how far it moves
	var lowest: float = INF
	var highest: float = -INF
	for i: Variant in members:
		var item: Exact.Item = items[int(i)]
		if item == null or not item.shape.has_pieces():
			continue
		highest = maxf(highest, item.hi.y)
		for corner: int in 8:
			far.append(Vector3(item.hi.x if corner & 1 else item.lo.x,
				item.hi.y if corner & 2 else item.lo.y, item.hi.z if corner & 4 else item.lo.z))
		var near_floor: bool = item.lo.y <= floor_at + BUDGET + 1.0
		for p: Exact.Piece in item.shape.pieces:
			var size: Vector3 = p.hi - p.lo
			var weight: float = maxf(size.x * size.y * size.z, 0.001)
			mass += weight
			middle += (item.at * ((p.lo + p.hi) * 0.5)) * weight
			if near_floor:
				for v: Vector3 in p.verts:
					var w: Vector3 = item.at * v
					low.append(w)
					owner.append(int(i))
					lowest = minf(lowest, w.y)
	if mass <= 0.0 or low.is_empty():
		return {}
	var centre: Vector3 = middle / mass
	var keep := PackedVector3Array()
	var kept_owner := PackedInt32Array()
	for k: int in low.size():
		if low[k].y <= lowest + BUDGET + 1.0:
			keep.append(low[k])
			kept_owner.append(owner[k])
	low = keep
	var first: Dictionary = {}
	var moved: float = 0.0
	for step: int in MOST_TIPS:
		var bottom: float = INF
		for w: Vector3 in low:
			bottom = minf(bottom, w.y)
		var touching := PackedVector2Array()
		var feet: Dictionary = {}
		for k: int in low.size():
			if low[k].y <= bottom + RESTS_WITHIN:
				touching.append(Vector2(low[k].x, low[k].z))
				feet[kept_owner[k]] = true
		var over := Vector2(centre.x, centre.z)
		var pivot: Dictionary = _pivot(touching, over)
		if step == 0:
			first = {"past": float(pivot.get("past", 0.0)), "line": bool(pivot.get("line", false)),
				"way": pivot.get("way", Vector2.ZERO), "feet": feet.keys()}
		if pivot.is_empty():
			break
		# The least turn about the pivot that brings another point to the floor.
		var axis_at := Vector3((pivot["at"] as Vector2).x, bottom, (pivot["at"] as Vector2).y)
		var turn: float = INF
		var turned_way: Vector2 = pivot["way"]
		for way: Vector2 in pivot["ways"]:
			var t := Vector3(way.x, 0.0, way.y)
			var angle: float = INF
			for w: Vector3 in low:
				var s: float = (w - axis_at).dot(t)
				var h: float = w.y - bottom
				if s > 0.01 and h > RESTS_WITHIN:
					angle = minf(angle, atan2(h, s))
			if angle < turn:
				turn = angle
				turned_way = way
		if turn == INF:
			moved = INF
			break
		var t3 := Vector3(turned_way.x, 0.0, turned_way.y)
		var u: Vector3 = Vector3.UP.cross(t3).normalized()
		var spin := Basis(u, turn)
		var reach: float = 0.0
		for w: Vector3 in far:
			var off: Vector3 = w - axis_at
			reach = maxf(reach, (off - u * off.dot(u)).length())
		moved += 2.0 * reach * sin(turn * 0.5)
		if moved > BUDGET:
			break
		for k: int in low.size():
			low[k] = axis_at + spin * (low[k] - axis_at)
		for k: int in far.size():
			far[k] = axis_at + spin * (far[k] - axis_at)
		centre = axis_at + spin * (centre - axis_at)
	if moved <= BUDGET:
		return {}
	first["moved"] = moved
	first["high"] = highest - floor_at
	return first


## Where a body standing on [param touching] (its points on the floor, seen
## from above) with its centre of mass over [param over] tips: {} when the
## centre is inside them; else {"at": a point on the edge it turns about, "way":
## the way it falls, "ways": the ways to try (both, for a centre over a line it
## rolls off either side of), "past": how far the centre is past them, "line":
## whether they are a line or a point}.
static func _pivot(touching: PackedVector2Array, over: Vector2) -> Dictionary:
	var hull: PackedVector2Array = Geometry2D.convex_hull(touching) if touching.size() >= 3 \
		else touching
	var area: float = 0.0
	for k: int in maxi(hull.size() - 1, 0):
		area += hull[k].cross(hull[k + 1])
	var flat: bool = hull.size() < 4 or absf(area) * 0.5 < 1.0
	if not flat and Geometry2D.is_point_in_polygon(over, hull):
		var gap: float = INF
		for k: int in hull.size() - 1:
			gap = minf(gap, Geometry2D.get_closest_point_to_segment(over, hull[k], hull[k + 1]).distance_to(over))
		if gap >= CENTRE_INSIDE:
			return {}
	# The nearest point of where it touches, and the way out over it.
	var nearest: Vector2 = hull[0] if not hull.is_empty() else over
	var gap: float = INF
	var ends: int = maxi(hull.size() - 1, 1) if hull.size() > 1 else 1
	for k: int in ends:
		var a: Vector2 = hull[k]
		var b: Vector2 = hull[mini(k + 1, hull.size() - 1)]
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(over, a, b)
		if on.distance_to(over) < gap:
			gap = on.distance_to(over)
			nearest = on
	if gap >= 0.05:
		var way: Vector2 = (over - nearest).normalized()
		if not flat and Geometry2D.is_point_in_polygon(over, hull):
			way = -way
		return {"at": nearest, "way": way, "ways": [way], "past": gap, "line": flat}
	# Its centre right over a line or a point: it rolls off whichever side
	# turns it least.
	var along := Vector2.RIGHT
	var longest: float = 0.01
	for p: Vector2 in touching:
		if p.distance_to(touching[0]) > longest:
			longest = p.distance_to(touching[0])
			along = (p - touching[0]).normalized()
	var across := Vector2(-along.y, along.x)
	return {"at": nearest, "way": across, "ways": [across, -across, along, -along],
		"past": 0.0, "line": true}


## How far a piece may move as it settles on a bare floor, LDU: BrickBench
## fails a build for 3 in two seconds, and a body that settles also rocks.
const BUDGET := 2.5
## What of a piece this near its lowest point touches the floor, LDU: parts
## placed here stand exactly level, and a round part on its side touches by one
## line of its facets.
const RESTS_WITHIN := 0.05
## How far inside where it touches its centre must be to stand, LDU.
const CENTRE_INSIDE := 0.25
## How many times a piece is let tip before it is called fallen.
const MOST_TIPS := 12


## How square to gravity a resting part must stand: the cosine of the most
## it may lean, 8 degrees.
const SQUARE := 0.99
## How far inside where it touches its centre of mass must be, in LDU.
const STEADY := 1.0


## How near two parts' surfaces count as touching, LDU: a piece this far
## above what it would rest on drops onto it, which BrickBench's simulation
## lets pass as long as nothing moves more than 3 LDU.
const TOUCH := 2.5


## The points where items [param a] and [param b] touch, into [param out]:
## each corner of a piece of one within TOUCH of a piece of the other and
## over or under it. Past its edge holds nothing up: a steering wheel with
## its centre right on a brick's edge was called standing on corners of its
## own 2 LDU past that edge (held-out model-011; it tipped off).
static func _touching(a: Exact.Item, b: Exact.Item, out: PackedVector3Array) -> void:
	var to_a: Transform3D = a.at.affine_inverse()
	var to_b: Transform3D = b.at.affine_inverse()
	for pa: Exact.Piece in a.shape.pieces:
		var box_a: Array = Exact.box_in(pa.lo, pa.hi, a.at)
		for pb: Exact.Piece in b.shape.pieces:
			var box_b: Array = Exact.box_in(pb.lo, pb.hi, b.at)
			var lo: Vector3 = (box_a[0] as Vector3).max(box_b[0])
			var hi: Vector3 = (box_a[1] as Vector3).min(box_b[1])
			if hi.x - lo.x < -TOUCH or hi.y - lo.y < -TOUCH or hi.z - lo.z < -TOUCH:
				continue
			for v: Vector3 in pb.verts:
				var w: Vector3 = b.at * v
				if _over(box_a, w) and _outside(pa, to_a * w) <= TOUCH:
					out.append(w)
			for v: Vector3 in pa.verts:
				var w: Vector3 = a.at * v
				if _over(box_b, w) and _outside(pb, to_b * w) <= TOUCH:
					out.append(w)


## Whether point [param w] is over or under the box [lo, hi], seen from above.
static func _over(box: Array, w: Vector3) -> bool:
	var lo: Vector3 = box[0]
	var hi: Vector3 = box[1]
	return w.x >= lo.x - 0.01 and w.x <= hi.x + 0.01 and w.z >= lo.z - 0.01 and w.z <= hi.z + 0.01


## How far point [param x] (in the piece's own frame) is outside convex piece
## [param p], by its faces; its box for a piece with none.
static func _outside(p: Exact.Piece, x: Vector3) -> float:
	if p.normals.is_empty():
		var past: Vector3 = (p.lo - x).max(x - p.hi)
		return maxf(past.x, maxf(past.y, past.z))
	# Each normal is an axis the piece spans from low to high: past either end
	# is outside it.
	var worst: float = -INF
	for k: int in p.normals.size():
		var d: float = p.normals[k].dot(x)
		worst = maxf(worst, maxf(d - p.spans[2 * k + 1], p.spans[2 * k] - d))
	return worst


## What item [param i] rests on, the highest thing under it: an item index
## or -1.
func under(i: int) -> int:
	var item: Exact.Item = items[i]
	if item == null:
		return -1
	var best: int = -1
	var top: float = -INF
	for j: int in items.size():
		var other: Exact.Item = items[j]
		if j == i or other == null:
			continue
		if minf(item.hi.x, other.hi.x) - maxf(item.lo.x, other.lo.x) <= 0.5 \
				or minf(item.hi.z, other.hi.z) - maxf(item.lo.z, other.lo.z) <= 0.5:
			continue
		if other.hi.y > item.lo.y + 4.5 or other.hi.y < item.lo.y - 2.0:
			continue
		if other.hi.y > top:
			top = other.hi.y
			best = j
	return best


# -- the words ------------------------------------------------------------


## A collision said with its fix. [param name] (item index) -> "brick 3
## (3001 at 1,0,2)" names either side.
func said(found: Dictionary, name: Callable) -> String:
	var a: int = found["a"]
	var b: int = found["b"]
	var depth: float = snappedf(float(found["depth"]), 0.1)
	var head: String = "%s and %s: their real shapes overlap by %s LDU, more than the 1 LDU a build allows" % [
		name.call(a), name.call(b), _n(depth)]
	var ia: Exact.Item = items[a]
	var ib: Exact.Item = items[b]
	if ia.at.origin.distance_to(ib.at.origin) < 1.0 and ia.shape.has_pieces() \
			and ib.shape.has_pieces():
		var shared: String = _shared_line(a, b)
		if not shared.is_empty():
			return "%s. They stand at one point, one inside the other; %s" % [head, shared]
	for pair: Array in [[a, b, int(found["piece_a"])], [b, a, int(found["piece_b"])]]:
		var stud: int = _stud_in_piece(pair[0], pair[2])
		if stud < 0:
			continue
		var item: Exact.Item = items[pair[0]]
		var way: Vector3 = -(item.at.basis * (item.shape.frames[stud].basis.y))
		if absf(way.normalized().y) < 0.5:
			return ("%s: a side stud of %s is pushed into %s, which has nothing there to take it. "
				% [head, name.call(pair[0]), name.call(pair[1])]
				+ "A side stud needs clear space or a part that takes it (a tile, a plate, a "
				+ "bracket's underside); turn %s so its studs face out, or move %s clear of them."
				% [name.call(pair[0]), name.call(pair[1])])
		return ("%s: a stud of %s is pushed into %s's solid, not into a hole of it. "
			% [head, name.call(pair[0]), name.call(pair[1])]
			+ "Stand it where its holes meet the studs, or put a plate between.")
	var mate: Dictionary = mate_move(a, b)
	if not mate.is_empty() and float(mate["residual"]) >= 0.5:
		var mover: int = int(mate["mover"])
		return ("%s. %s is %s LDU off %s's %s, where it would seat: move it %s." % [head,
			name.call(mover), _n(snappedf(float(mate["residual"]), 0.1)),
			name.call(int(mate["onto"])), mate["connector"], _direction(mate["move"])])
	var turned: Dictionary = _ball_turned(a, b)
	if not turned.is_empty():
		return ("%s: %s is bent %d degrees in its ball joint with %s, and past about %d "
			% [head, name.call(b), int(turned["degrees"]), name.call(a), int(turned["clear"])]
			+ "degrees that way its socket's rim meets the ball's neck. Keep the joint, and bend "
			+ "it %d degrees or less that way, or another way: a socket of two jaws (a Joint-8 "
			% int(turned["clear"]) + "plate's) bends far between its jaws and little against them.")
	if _kind_in(a, Exact.HINGE) and _kind_in(b, Exact.HINGE):
		return ("%s: the two halves of a hinge pass through each other. Its top turns about "
			% head + "its base's hinge line, and one way only: hang the top on that line (a "
			+ "section with hinge: \"tilting\" lays both halves), and at this angle's other "
			+ "sign or a smaller one.")
	for pair: Array in [[a, b], [b, a]]:
		if _only_kind(pair[0], Exact.AXLE):
			return ("%s: %s runs through %s, which has no hole on its line. Put it through "
				% [head, name.call(pair[0]), name.call(pair[1])]
				+ "a hole (attachment_points lists them, with the line each runs), or move it clear.")
	var axis: Vector3 = found["axis"]
	if absf(axis.y) > 0.9:
		var upper: int = b if (axis.y > 0.0) == true else a
		var lower: int = a if upper == b else b
		return ("%s: %s sits %s LDU into %s under it. Raise it to stand on its studs, "
			% [head, name.call(upper), _n(depth), name.call(lower)]
			+ "or lower what is under it.")
	return "%s. Move one clear of the other by %s LDU %s." % [head, _n(ceilf(depth)),
		_direction(axis * depth)]


## For items [param a] and [param b] joined by a ball, which collide away from
## it: how far [param b] is bent in the joint (the line from the ball to its
## middle, against where that line runs straight: its socket's frame on the
## ball's, as attach lays it; a turn about its own line is not a bend), and how
## far it may bend that way clear of [param a]: {degrees, clear}; {} when they
## are not joined by a ball, or not bent, or collide at every bend back to
## straight.
func _ball_turned(a: int, b: int) -> Dictionary:
	var ia: Exact.Item = items[a]
	var ib: Exact.Item = items[b]
	for joint: Array in joints_between(a, b):
		if joint[0] != "ball":
			continue
		var fa: Transform3D = ia.at * ia.shape.frames[int(joint[1])]
		var fb: Transform3D = ib.at * ib.shape.frames[int(joint[2])]
		var pivot: Vector3 = (fa.origin + fb.origin) * 0.5
		var now: Vector3 = ib.at * ((ib.shape.lo + ib.shape.hi) * 0.5) - pivot
		var straight: Vector3 = (fa.basis.orthonormalized() * fb.basis.orthonormalized().inverse()) * now
		var axis: Vector3 = now.cross(straight)
		var bend: float = now.angle_to(straight)
		if now.length() < 1.0 or axis.length() < 0.000001 or rad_to_deg(bend) < 2.0:
			continue
		axis = axis.normalized()
		# Bent back towards straight by [param angle], about the ball.
		var back: Callable = func(angle: float) -> Exact.Item:
			return Exact.Item.new(ib.shape, Transform3D(Basis.IDENTITY, pivot)
				* Transform3D(Basis(axis, angle), Vector3.ZERO)
				* Transform3D(Basis.IDENTITY, -pivot) * ib.at)
		# Straight is not always clear (a Joint-8 ball on a plate's side, its
		# socket plate laid square on it), so back by 2 degrees at a time to
		# the first bend that is.
		var degrees: float = rad_to_deg(bend)
		var clear: float = degrees - 2.0
		while clear > 0.0 and not Exact.clash(ia, back.call(deg_to_rad(degrees - clear))).is_empty():
			clear -= 2.0
		if clear <= 0.0:
			continue
		return {"degrees": roundf(degrees), "clear": floorf(clear)}
	return {}


## Where two parts at one point should be, or "".
func _shared_line(a: int, b: int) -> String:
	var mate: Dictionary = mate_move(a, b)
	if not mate.is_empty() and float(mate["residual"]) >= 0.5:
		return "%s belongs %s, on the other's %s." % ["the second" if int(mate["mover"]) == b
			else "the first", _direction(mate["move"]), mate["connector"]]
	return "move one of them to where it joins something by a stud, a hole or a clip."


## The connector of item [param i] in its piece [param piece], when that
## piece is a stud: the stud's index, or -1.
func _stud_in_piece(i: int, piece: int) -> int:
	var item: Exact.Item = items[i]
	if item == null or piece < 0 or piece >= item.shape.pieces.size():
		return -1
	var p: Exact.Piece = item.shape.pieces[piece]
	var middle: Vector3 = (p.lo + p.hi) * 0.5
	# A stud is drawn as a ring of slivers, its middle empty when it is
	# hollow: a piece of it lies within a stud's reach of its base (6 across,
	# 4 out) and outside the face it stands on.
	for k: int in item.shape.kind.size():
		if item.shape.kind[k] != Exact.STUD:
			continue
		var frame: Transform3D = item.shape.frames[k]
		var way: Vector3 = (-frame.basis.y).normalized()
		var nearest: Vector3 = frame.origin.clamp(p.lo, p.hi)
		if nearest.distance_to(frame.origin) <= 7.5 and (middle - frame.origin).dot(way) >= -0.5:
			return k
	return -1


func _kind_in(i: int, kind: int) -> bool:
	var item: Exact.Item = items[i]
	return item != null and item.shape.kind.has(kind)


## Whether every connector of item [param i] is of [param kind]: an axle, a
## bar, a pin.
func _only_kind(i: int, kind: int) -> bool:
	var item: Exact.Item = items[i]
	if item == null or item.shape.kind.is_empty():
		return false
	for k: int in item.shape.kind:
		if k != kind:
			return false
	return true


## Whether item [param i] is the one to move onto [param onto] by its
## connector [param mine], when both are this design's to move: the part with
## the hole goes onto the part with the stud (a hat onto a head, a crystal onto
## its plate, never the plate onto the crystal); otherwise the smaller goes.
func _moves_onto(i: int, mine: int, onto: int, movable: Dictionary, moved: Dictionary) -> bool:
	if not movable.has(onto) or moved.has(onto) or on_ground(onto, STANDS):
		return true
	var kind: int = (items[i] as Exact.Item).shape.kind[mine]
	if kind == Exact.STUD:
		return false
	if kind == Exact.HOLE:
		return true
	return _volume(i) <= _volume(onto)


## The move that would seat one of [param a] and [param b] on a connector of
## the other within FIX_REACH: {mover, onto, move, residual, connector}, or {}.
## Which of the two moves is as a seat decides it ([method _moves_onto]).
func mate_move(a: int, b: int) -> Dictionary:
	var found_for: Dictionary = {}
	for pair: Array in [[a, b], [b, a]]:
		var two: Array = []
		two.resize(items.size())
		two[pair[0]] = items[pair[0]]
		two[pair[1]] = items[pair[1]]
		var found: Dictionary = Exact.seat_move(two, pair[0], FIX_REACH, 0.0)
		if not found.is_empty():
			found_for[pair[0]] = found
	if found_for.is_empty():
		return {}
	var both := {a: true, b: true}
	var mover: int = a if found_for.has(a) else b
	if found_for.has(a) and found_for.has(b) \
			and not _moves_onto(a, int(found_for[a]["mine"]), b, both, {}):
		mover = b
	var found: Dictionary = found_for[mover]
	var onto: int = b if mover == a else a
	return {"mover": mover, "onto": onto, "move": found["move"], "residual": found["residual"],
		"connector": (items[onto] as Exact.Item).shape.named(int(found["other"]))}


## The size of an item's box, LDU cubed: which of two is the smaller.
func _volume(i: int) -> float:
	var item: Exact.Item = items[i] if i >= 0 and i < items.size() else null
	if item == null:
		return INF
	var size: Vector3 = item.hi - item.lo
	return size.x * size.y * size.z


static func _direction(move: Vector3) -> String:
	var said := PackedStringArray()
	for axis: Array in [[move.x, "+x", "-x"], [move.y, "up", "down"], [move.z, "+z", "-z"]]:
		var amount: float = axis[0]
		if absf(amount) >= 0.05:
			said.append("%s LDU %s" % [_n(snappedf(absf(amount), 0.1)),
				axis[1] if amount > 0.0 else axis[2]])
	return ", ".join(said) if not said.is_empty() else "a fraction of an LDU"


static func _n(value: float) -> String:
	return str(value).trim_suffix(".0")


## The pieces of [param wanted] that no connection joins to anything outside
## them, each moved whole where a move of up to SEAT_REACH seats one of its
## connectors on a part outside it, joins it there and runs it into nothing
## it was not in already: into [param moved], as the seat does a part.
func _seat_pieces(wanted: Dictionary, near: Dictionary, moved: Dictionary) -> void:
	var among := PackedInt32Array()
	var around: Dictionary = wanted.duplicate()
	for i: Variant in near:
		for j: int in (near[i] as PackedInt32Array):
			around[j] = true
	for i: Variant in around:
		among.append(int(i))
	among.sort()
	var edges: Array = Exact.connections(items, among)
	var root: PackedInt32Array = Exact.pieces(items.size(), edges)
	var groups: Dictionary = {}       ## root -> its members, if every one may move
	var fixed: Dictionary = {}        ## roots with a member that may not move
	for i: int in among:
		if items[i] == null:
			continue
		if not wanted.has(i) or on_ground(i, STANDS):
			fixed[root[i]] = true
			continue
		var members: Array = groups.get(root[i], [])
		members.append(i)
		groups[root[i]] = members
	for key: Variant in groups:
		var members: Array = groups[key]
		if fixed.has(key) or members.size() < 2:
			continue
		var mine: Dictionary = {}
		for i: Variant in members:
			mine[int(i)] = true
		var best: Dictionary = {}
		for i: Variant in members:
			var outside := PackedInt32Array()
			for j: int in (near.get(int(i), PackedInt32Array()) as PackedInt32Array):
				if not mine.has(j):
					outside.append(j)
			if outside.is_empty():
				continue
			var found: Dictionary = Exact.seat_move(items, int(i), SEAT_REACH, 0.0, outside)
			if not found.is_empty() and (best.is_empty()
					or float(found["residual"]) < float(best["residual"])):
				best = found
				best["at"] = int(i)
		if best.is_empty() or float(best["residual"]) < 0.05:
			continue
		var move: Vector3 = best["move"]
		var was: Dictionary = {}
		for i: Variant in members:
			was[int(i)] = items[int(i)]
			items[int(i)] = Exact.Item.new((items[int(i)] as Exact.Item).shape,
				(items[int(i)] as Exact.Item).at.translated(move))
		# Into nothing it was not in already, and joined outside itself once there.
		var good: bool = true
		for i: Variant in members:
			for j: int in Exact._near(items, int(i), among, Exact.TAU):
				if mine.has(j) or items[j] == null:
					continue
				if not Exact.clash(items[int(i)], items[j], true).is_empty() \
						and Exact.clash(was[int(i)], items[j], true).is_empty():
					good = false
					break
			if not good:
				break
		var joined: bool = false
		if good:
			var these := PackedInt32Array(among)
			for edge: Array in Exact.connections(items, these):
				if mine.has(int(edge[0])) != mine.has(int(edge[2])):
					joined = true
					break
		if not good or not joined:
			for i: Variant in members:
				items[int(i)] = was[int(i)]
			continue
		_asked.clear()
		for i: Variant in members:
			moved[int(i)] = move


## Whether a connector of item [param i] meets another part's exactly, by
## [param points] (the connectors of every item by their point to the LDU).
func _meets_exactly(i: int, points: Dictionary) -> bool:
	for one: Array in (items[i] as Exact.Item).world():
		var mine: Array = [i, one[0], one[1], one[2], one[3]]
		for other: Variant in points.get(Vector3i((one[1] as Vector3).round()), []):
			if int((other as Array)[0]) == i:
				continue
			var move: Variant = Exact._move_to_meet(items, mine, other, 1.0)
			if move is Vector3 and (move as Vector3).length() <= 0.05:
				return true
	return false


## A piece of this design nothing holds, said: its first part, what it rests
## on, and how to fix it. [param members] are item indices.
func unheld_said(members: Array, name: Callable) -> String:
	var first: int = members[0]
	var rest: int = members.size() - 1
	var on: int = -1
	for i: int in members:
		on = under(i)
		if on >= 0 and not members.has(on):
			first = i
			break
		on = -1
	var who: String = name.call(first)
	if rest > 0:
		who += " and %d part%s joined to it" % [rest, "" if rest == 1 else "s"]
	var where: String = "rests on %s without a connection" % name.call(on) if on >= 0 \
		else "touches nothing that holds it"
	return ("%s %s: no stud, clip, hinge or axle joins it to the rest, and it does not "
		% [who, where] + "stand square where it is (its weight is past what is under it, it "
		+ "leans on a slope or a side, or it runs into something), so it falls — BrickBench's "
		+ "check lets it fall. Put it on a stud or in a clip, or under something that "
		+ "clutches it; attachment_points lists where a part joins.")


## A piece that tips or rolls on a bare floor ([method tips]), said: what it
## stands on, how far its weight is from standing, and what to do.
func tips_said(found: Dictionary, members: Array, name: Callable) -> String:
	var feet: Array = found.get("feet", [])
	var on: String = ", ".join(PackedStringArray(feet.slice(0, 3).map(
		func(i: Variant) -> String: return str(name.call(int(i))))))
	if feet.size() > 3:
		on += " and %d more" % (feet.size() - 3)
	var who: String = "The piece of %d part%s" % [members.size(), "" if members.size() == 1 else "s"]
	var moved: float = float(found.get("moved", INF))
	var settles: String = ("nothing of it comes down to catch it" if moved == INF
		else "it moves %s LDU before it comes to rest" % _n(snappedf(moved, 0.1)))
	if bool(found.get("line", false)) and float(found.get("past", 0.0)) < 0.05:
		return ("%s on the floor by %s touches it along a line or at a point with its weight "
			% [who, on] + "over that, so on a bare floor it rolls: %s, past the 3 LDU " % settles
			+ "BrickBench's simulation allows. Lay it on something flat (a plate under it, a "
			+ "round part's flat end down), join it to what stands beside it, or stand the "
			+ "model on a baseplate.")
	var way: Vector2 = found.get("way", Vector2.ZERO)
	return ("%s standing on %s tips over: its centre of mass is %s LDU past the edge of what "
		% [who, on, _n(snappedf(float(found.get("past", 0.0)), 0.1))]
		+ "it stands on, so it tips %s and %s, past the 3 LDU BrickBench's simulation " % [
			_tip_way(way), settles]
		+ "allows. Widen its footing under its weight (a plate under the feet reaching %s), "
		% _tip_way(way) + "move weight back over its feet, or stand it on a base or a "
		+ "baseplate that is part of the build.")


## A way across the floor said in words: "towards +z", "towards -x and +z".
static func _tip_way(way: Vector2) -> String:
	var said := PackedStringArray()
	if absf(way.x) >= 0.38:
		said.append("+x" if way.x > 0.0 else "-x")
	if absf(way.y) >= 0.38:
		said.append("+z" if way.y > 0.0 else "-z")
	return "towards " + " and ".join(said) if not said.is_empty() else "over its edge"


# -- seating --------------------------------------------------------------


## Each of [param movable]'s items that misses a connector by up to SEAT_REACH
## and meets none exactly, moved onto it where that makes it collide with
## nothing: index -> the move, in the world. Items are moved here as well.
func seat(movable: Array) -> Dictionary:
	var began: int = Time.get_ticks_usec()
	var moved: Dictionary = _seat(movable)
	_spent("seat", began)
	return moved


func _seat(movable: Array) -> Dictionary:
	var moved: Dictionary = {}
	var wanted: Dictionary = {}
	for i: int in movable:
		if _shaped(i):
			wanted[i] = true
	if wanted.is_empty():
		return moved
	# Who is near whom, once: reach for the seat, and the connector's own.
	var near: Dictionary = {}
	var reach: float = SEAT_REACH + Exact.POS_THR + 1.0
	for pair: Vector2i in pairs_near(wanted, -reach):
		for ends: Array in [[pair.x, pair.y], [pair.y, pair.x]]:
			if wanted.has(ends[0]):
				var list: PackedInt32Array = near.get(ends[0], PackedInt32Array())
				list.append(ends[1])
				near[ends[0]] = list
	# Every connector by its point, to the LDU, once: a part with one that
	# meets another's exactly is seated already, and that is most of them.
	var points: Dictionary = {}
	var around: Dictionary = wanted.duplicate()
	for i: Variant in near:
		for j: int in (near[i] as PackedInt32Array):
			around[j] = true
	for j: int in around:
		if items[j] == null:
			continue
		for one: Array in (items[j] as Exact.Item).world():
			var key := Vector3i(((one[1] as Vector3)).round())
			var list: Array = points.get(key, [])
			list.append([j, one[0], one[1], one[2], one[3]])
			points[key] = list
	# The smaller first, and never onto a smaller part that may move itself: a
	# crystal goes onto its plate, not the plate onto the crystal.
	var order: Array = wanted.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return _volume(a) < _volume(b))
	for i: int in order:
		if not near.has(i) or _meets_exactly(i, points):
			continue
		var others: PackedInt32Array = near[i]
		var found: Dictionary = Exact.seat_move(items, i, SEAT_REACH, 0.05, others)
		if found.is_empty():
			continue
		var onto: int = int(found["item"])
		if on_ground(i, STANDS) or not _moves_onto(i, int(found["mine"]), onto, wanted, moved):
			continue
		var was: Exact.Item = items[i]
		var move: Vector3 = found["move"]
		var there := Exact.Item.new(was.shape, was.at.translated(move))
		# Into nothing it was not in already, and joined once there.
		var clear: bool = true
		for j: int in others:
			if items[j] == null:
				continue
			if not Exact.clash(there, items[j], true).is_empty() and Exact.clash(was, items[j], true).is_empty():
				clear = false
				break
		items[i] = there
		if not clear or not Exact.connected(items, i, others):
			items[i] = was
			continue
		_asked.clear()
		moved[i] = move
	# A piece of them joined to each other and to nothing else, the whole of
	# it off by a few LDU (a log pile built on its own and set down a fifth of
	# a stud off its base): moved together, by the move that seats the nearest
	# of its connectors on another part's.
	_seat_pieces(wanted, near, moved)
	# A pin through the middle of a hole, its collar inside it (a pin's middle
	# put at the hole's middle, as a placement by its line does): slid along
	# its line, a whole cell at a time, until a half of it is in the hole and
	# the collar at the mouth. Only a pin: an axle runs on through a gear, and
	# a gear slid along it would leave its mesh.
	for i: int in order:
		if moved.has(i) or not near.has(i):
			continue
		var others: PackedInt32Array = near[i]
		var clashing: bool = false
		for j: int in others:
			var found: Variant = between(i, j)
			if found is Dictionary and not (found as Dictionary).is_empty():
				clashing = true
				break
		if not clashing:
			continue
		var slide: Variant = Exact.slide_clear(items, i, others, BrickLattice.CELL, [Exact.S_PIN])
		if slide is Vector3:
			var was: Exact.Item = items[i]
			items[i] = Exact.Item.new(was.shape, was.at.translated(slide))
			_asked.clear()
			moved[i] = slide
	return moved
