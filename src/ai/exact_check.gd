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
## How near a ground counts as on it, in LDU (verify.py: 0.01, after
## its own rounding; our parts stand on whole cells).
const ON_GROUND := 0.5
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


## How two items meet: {} when their exact shapes are clear, the collision
## otherwise, null when either has no shape to ask.
func between(i: int, j: int) -> Variant:
	if not _shaped(i) or not _shaped(j):
		return null
	var a: int = mini(i, j)
	var b: int = maxi(i, j)
	var key := Vector2i(a, b)
	if _asked.has(key):
		return _asked[key]
	var found: Dictionary = Exact.clash(items[a], items[b])
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


## The ground: y = 0, the floor every model stands on here.
func on_ground(i: int) -> bool:
	return items[i] != null and (items[i] as Exact.Item).lo.y <= ON_GROUND


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
	if not movable.has(onto) or moved.has(onto) or on_ground(onto):
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
	return ("%s %s: no stud, clip, hinge or axle joins it to the rest, so it falls off "
		% [who, where] + "when the model is picked up (and BrickBench's check lets it fall). "
		+ "Put it on a stud or in a clip, or under something that clutches it; "
		+ "attachment_points lists where a part joins.")


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
		if on_ground(i) or not _moves_onto(i, int(found["mine"]), onto, wanted, moved):
			continue
		var was: Exact.Item = items[i]
		var move: Vector3 = found["move"]
		var there := Exact.Item.new(was.shape, was.at.translated(move))
		# Into nothing it was not in already, and joined once there.
		var clear: bool = true
		for j: int in others:
			if items[j] == null:
				continue
			if not Exact.clash(there, items[j]).is_empty() and Exact.clash(was, items[j]).is_empty():
				clear = false
				break
		items[i] = there
		if not clear or not Exact.connected(items, i, others):
			items[i] = was
			continue
		_asked.clear()
		moved[i] = move
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
