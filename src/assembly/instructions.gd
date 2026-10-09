## Turning a finished model back into the order it was built in.
##
## A booklet is not a list of bricks sorted by height. The test of a step
## is whether a person can actually carry it out: every brick it adds has
## to rest on something that is already there, and the bricks in one step
## should be near enough each other to find without hunting.
##
## So the order is grown rather than sorted. At each point the candidates
## are the bricks whose supports are all placed; among those the one
## lowest down wins, and ties go to whichever is nearest the brick just
## placed, which keeps a step in one part of the model instead of
## scattered across it.
##
## Some models cannot be built strictly bottom-up — an arch placed before
## the wall beside it, a brick hung off a bracket. When nothing is
## supported the run would stall, so the lowest remaining brick is taken
## anyway and the step is marked. A booklet that says "this one is
## awkward" is more use than one that stops.
class_name Instructions
extends RefCounted

## Bricks added at once. Kept small: a step is what someone holds in
## their hand before looking back at the page.
const MAX_PER_STEP := 8

## How far apart two bricks can be and still belong in the same step, in
## LDU. Four studs — far enough to take a whole wall segment, close
## enough that a step never spans the model.
const NEAR := 80.0

## How wide a region of a big model is, in LDU: twenty-four studs. Built
## course by course across the whole of it, a 1,895-part castle came to
## 281 steps whose bricks jumped a median of 12.5 studs and up to 61
## from one step to the next, across a model 72 wide, and every picture
## of them was the whole castle. A real set finishes the gatehouse before
## it starts a tower. A model no wider than this is one region, built
## exactly as before.
const REGION := 480.0

## How [method _next] chose: in the region being built, a brick it was
## waiting for, or a move to another region.
const HERE := 0
const BORROWED := 1
const MOVED := 2


class Step extends RefCounted:
	var index: int = 0
	var brick_ids: PackedInt64Array = PackedInt64Array()
	## part id -> how many of it this step adds.
	var parts: Dictionary = {}
	## True when this step had to be taken out of order because nothing
	## remaining was supported.
	var unsupported: bool = false
	## The part of the model this step builds, when it is built a part at
	## a time: an assembly the design named, or "part 2". Empty for a
	## model built in one go.
	var section: String = ""

	## "2 × 3001, 1 × 3024", for the panel.
	func summary(library: PartLibrary) -> String:
		var pieces := PackedStringArray()
		for part_id: String in parts:
			var info: PartLibrary.PartInfo = library.parts.get(part_id)
			var name: String = info.name.strip_edges() if info != null else part_id
			# LDraw pads names into columns, so "Brick  2 x  4" arrives
			# with the padding still in it and reads as a typo here.
			while name.contains("  "):
				name = name.replace("  ", " ")
			pieces.append("%d × %s" % [int(parts[part_id]), name])
		return ", ".join(pieces)


## Where a brick sits and what it rests on.
class Node2 extends RefCounted:
	var id: int
	var box: AABB
	var part_id: String
	## Which part of the model it is built with. See [constant REGION].
	var region: String = ""
	## Bricks that must be placed before this one.
	var needs: PackedInt64Array = PackedInt64Array()


## Work out the steps for everything currently in the world.
##
## [param skip] names bricks that are not part of the build — the
## baseplate. It is the surface the model is built on, so it belongs on
## screen from the first step rather than being placed in one, and
## planning around it would also make every brick above it "supported"
## and flatten the order.
##
## [param regions] names the part of the model each brick belongs to.
## Without it a brick's own group is used — the assembly a design named,
## or the sub-model it was read from — and a big model with none is
## divided by area instead.
static func plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}, regions: Dictionary = {}) -> Array[Step]:
	var nodes: Array[Node2] = _survey(world, library, skip)
	if nodes.is_empty():
		return []
	_find_supports(nodes)
	_find_joints(nodes, world, library)
	return _sequence(nodes, _assign_regions(nodes, regions))


## Which region each brick is built with.
##
## By area, a big model is cut into equal tiles of the plan no wider than
## REGION. Equal rather than fixed, so a model 30 studs wide is two
## halves and not a 24-stud region and a 6-stud sliver.
##
## Returns whether the regions have names a person gave them, which the
## booklet uses as they are, rather than tiles it numbers.
static func _assign_regions(nodes: Array[Node2], given: Dictionary) -> bool:
	if not given.is_empty():
		for node: Node2 in nodes:
			node.region = str(given.get(node.id, ""))
	if nodes.any(func(node: Node2) -> bool: return not node.region.is_empty()):
		for node: Node2 in nodes:
			if node.region.is_empty():
				node.region = "the rest"
		return true
	var bounds: AABB = nodes[0].box
	for node: Node2 in nodes:
		bounds = bounds.merge(node.box)
	var across: int = maxi(1, int(ceil(bounds.size.x / REGION)))
	var deep: int = maxi(1, int(ceil(bounds.size.z / REGION)))
	if across * deep == 1:
		return false
	for node: Node2 in nodes:
		var centre: Vector3 = node.box.get_center() - bounds.position
		var column: int = clampi(int(centre.x / bounds.size.x * across),
			0, across - 1)
		var row: int = clampi(int(centre.z / bounds.size.z * deep),
			0, deep - 1)
		node.region = "%d,%d" % [column, row]
	return false


## A pin cannot go into a hole that is not on the table yet.
##
## _find_supports only knows what sits on what, which is the whole story
## for a stack of bricks and none of it for a mechanism: a pin goes in
## sideways, so nothing is under it and it was free to be step one. The
## go-kart came out with its pins at steps 4 and 5 and the beams they
## pin into at 7, 8 and 9 — and nothing flagged it, because a wheel
## happened to have its top near the pin's underside, so the vertical
## test found "support" that had nothing to do with it.
##
## The direction is not arbitrary. A joint is symmetric but inserting
## one is not: the hole has to exist, so the pin needs the part it goes
## into.
static func _find_joints(nodes: Array[Node2], world: BrickWorld,
		library: PartLibrary) -> void:
	var entries: Array = []
	for node: Node2 in nodes:
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		if brick == null:
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		entries.append([node.id, brick.transform, part])
	if entries.is_empty():
		return
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node
	for pair: Array in Joints.pairs(entries):
		var plug: Node2 = by_id.get(pair[0])
		if plug != null and not plug.needs.has(pair[1]):
			plug.needs.append(pair[1])


static func _survey(world: BrickWorld, library: PartLibrary,
		skip: Dictionary) -> Array[Node2]:
	var nodes: Array[Node2] = []
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var node := Node2.new()
		node.id = brick.id
		node.part_id = brick.part_id
		node.box = brick.transform * part.bounds
		node.region = brick.group
		nodes.append(node)
	return nodes


## Who rests on whom.
##
## A brick needs another when it sits directly on top of it and their
## footprints overlap. "Directly" has to have some slack in it: a stud is
## 4 LDU proud of the brick below, so a part resting on studs has its
## underside a little into the part beneath rather than exactly on it.
static func _find_supports(nodes: Array[Node2]) -> void:
	# +Y is up here. LDraw has −Y up, but the conversion to engine space
	# negated Y and Z, so by the time a brick reaches this its underside
	# is box.position.y and its top is box.end.y.
	#
	# This was the other way round and every check agreed with it,
	# because the probe had made the same assumption — so a stack of ten
	# passed "starts at the bottom" while building from the top. What
	# caught it was looking at a booklet: step one of the lighthouse was
	# the lamp, hanging in the air above an empty baseplate.
	const SLACK := 5.0
	for node: Node2 in nodes:
		for other: Node2 in nodes:
			if other.id == node.id:
				continue
			# other is under node when other's top meets node's underside,
			# allowing for the stud that reaches up into it.
			var sits_on: bool = (other.box.end.y >= node.box.position.y - SLACK
				and other.box.end.y <= node.box.position.y + SLACK)
			if sits_on and _overlaps_flat(node.box, other.box):
				node.needs.append(other.id)


static func _overlaps_flat(a: AABB, b: AABB) -> bool:
	# A shared edge is not support, so the comparison is strict by a hair.
	const EDGE := 0.5
	return (a.position.x < b.end.x - EDGE and b.position.x < a.end.x - EDGE
		and a.position.z < b.end.z - EDGE and b.position.z < a.end.z - EDGE)


static func _sequence(nodes: Array[Node2], named: bool = false) -> Array[Step]:
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node

	var remaining: Array[Node2] = nodes.duplicate()
	var placed: Dictionary = {}
	var steps: Array[Step] = []
	var last_at: Vector3 = Vector3.ZERO
	var have_last: bool = false
	## The region being built, and what each one is called in the
	## booklet: its own name, or "part n" in the order they are reached.
	var current: String = ""
	var called: Dictionary = {}

	while not remaining.is_empty():
		var step := Step.new()
		step.index = steps.size() + 1

		while step.brick_ids.size() < MAX_PER_STEP:
			var chosen: Array = _next(remaining, placed, last_at, have_last,
				not step.brick_ids.is_empty(), current)
			var pick: int = chosen[0]
			if pick < 0:
				break

			var node: Node2 = remaining[pick]
			# A brick from next door that this region was waiting for is
			# built as part of it; anything else is a move.
			if node.region != current and int(chosen[1]) == MOVED:
				current = node.region
				if not called.has(current) and not current.is_empty():
					called[current] = (current if named
						else "part %d" % (called.size() + 1))
			step.section = str(called.get(current, ""))
			# A step that had to break the support rule says so, and ends
			# there: whatever comes next is resting on a brick that is
			# only just in place, and running them together would hide
			# which one was the awkward part.
			var forced: bool = not _ready(node, placed)
			if forced and not step.brick_ids.is_empty():
				break

			remaining.remove_at(pick)
			placed[node.id] = true
			step.brick_ids.append(node.id)
			step.parts[node.part_id] = int(step.parts.get(node.part_id, 0)) + 1
			step.unsupported = step.unsupported or forced
			last_at = node.box.get_center()
			have_last = true
			if forced:
				break

		if step.brick_ids.is_empty():
			# Cannot happen — _next falls back to the lowest remaining
			# brick — but an empty step here would spin forever, and a
			# loop that cannot end is worse than a booklet that stops.
			push_warning("instructions: %d bricks could not be ordered"
				% remaining.size())
			break
		steps.append(step)

	return steps


## The next brick to place, or −1 when the step should end.
##
## [param same_step] tightens the choice to something near the last brick
## placed, so a step stays in one place. The first brick of a step is free
## to go anywhere, which is what lets the build move on to a new area.
##
## Within the region being built while anything in it can be placed. When
## nothing in it is ready, the bricks it is directly waiting for come
## next and are built as part of it — a wall brick across a region's edge
## rests on its neighbour's. Past that the build moves to the nearest
## region and comes back later: borrowing further than one brick deep
## measured as one section swallowing 1,175 of a castle's 1,483 steps.
##
## Returns [index, how]: how is [constant HERE], [constant BORROWED] or
## [constant MOVED], and index is −1 when the step should end.
static func _next(remaining: Array[Node2], placed: Dictionary,
		last_at: Vector3, have_last: bool, same_step: bool,
		current: String = "") -> Array:
	var fallback: int = -1
	var fallback_height: float = INF
	for index: int in remaining.size():
		# Lowest first. With +Y up the underside is box.position.y, so
		# the smallest value is the one nearest the table.
		if remaining[index].box.position.y < fallback_height:
			fallback_height = remaining[index].box.position.y
			fallback = index

	var here: int = _best(remaining, placed, last_at, have_last, same_step,
		func(node: Node2) -> bool: return node.region == current, false)
	if here >= 0:
		return [here, HERE]
	# Nothing legal is near enough: end the step rather than reaching
	# across the model, or into another region, for the sake of filling it.
	if same_step:
		return [-1, HERE]

	var wanted: Dictionary = {}
	for node: Node2 in remaining:
		if node.region != current:
			continue
		for need: int in node.needs:
			if not placed.has(need):
				wanted[need] = true
	var borrowed: int = _best(remaining, placed, last_at, have_last, false,
		func(node: Node2) -> bool: return wanted.has(node.id), false)
	if borrowed >= 0:
		return [borrowed, BORROWED]

	var moved: int = _best(remaining, placed, last_at, have_last, false,
		func(_node: Node2) -> bool: return true, true)
	return [moved if moved >= 0 else fallback, MOVED]


## The best ready brick among those [param allowed] admits, or −1.
##
## Height dominates; distance only breaks ties within a layer, so a
## nearby brick two layers up never jumps the queue. Moving to a new
## region it is the other way round: nothing is built there yet, so
## whatever is ready is near the table anyway, and the nearest one keeps
## the build moving to the region next door rather than across the model.
static func _best(remaining: Array[Node2], placed: Dictionary,
		last_at: Vector3, have_last: bool, same_step: bool,
		allowed: Callable, nearest_first: bool) -> int:
	var best: int = -1
	var best_score: float = INF
	for index: int in remaining.size():
		var node: Node2 = remaining[index]
		if not allowed.call(node) or not _ready(node, placed):
			continue
		var distance: float = (node.box.get_center().distance_to(last_at)
			if have_last else 0.0)
		if same_step and distance > NEAR:
			continue
		var score: float = (distance * 1000.0 + node.box.position.y
			if nearest_first
			else node.box.position.y * 1000.0 + distance)
		if score < best_score:
			best_score = score
			best = index
	return best


static func _ready(node: Node2, placed: Dictionary) -> bool:
	for need: int in node.needs:
		if not placed.has(need):
			return false
	return true
