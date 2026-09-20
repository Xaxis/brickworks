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


class Step extends RefCounted:
	var index: int = 0
	var brick_ids: PackedInt64Array = PackedInt64Array()
	## part id -> how many of it this step adds.
	var parts: Dictionary = {}
	## True when this step had to be taken out of order because nothing
	## remaining was supported.
	var unsupported: bool = false

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
	## Bricks that must be placed before this one.
	var needs: PackedInt64Array = PackedInt64Array()


## Work out the steps for everything currently in the world.
##
## [param skip] names bricks that are not part of the build — the
## baseplate. It is the surface the model is built on, so it belongs on
## screen from the first step rather than being placed in one, and
## planning around it would also make every brick above it "supported"
## and flatten the order.
static func plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}) -> Array[Step]:
	var nodes: Array[Node2] = _survey(world, library, skip)
	if nodes.is_empty():
		return []
	_find_supports(nodes)
	return _sequence(nodes)


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
		nodes.append(node)
	return nodes


## Who rests on whom.
##
## A brick needs another when it sits directly on top of it and their
## footprints overlap. "Directly" has to have some slack in it: a stud is
## 4 LDU proud of the brick below, so a part resting on studs has its
## underside a little into the part beneath rather than exactly on it.
static func _find_supports(nodes: Array[Node2]) -> void:
	# −Y is up in LDraw, which this model keeps: a brick's top is its
	# box.position.y and its bottom is box.end.y. Getting this the wrong
	# way round produces a booklet that builds downwards from the roof —
	# every step legal, the whole thing useless.
	const SLACK := 5.0
	for node: Node2 in nodes:
		for other: Node2 in nodes:
			if other.id == node.id:
				continue
			# other is below node when other's top is at or under node's
			# bottom, allowing for the stud that reaches up into it.
			var sits_on: bool = (other.box.position.y >= node.box.end.y - SLACK
				and other.box.position.y <= node.box.end.y + SLACK)
			if sits_on and _overlaps_flat(node.box, other.box):
				node.needs.append(other.id)


static func _overlaps_flat(a: AABB, b: AABB) -> bool:
	# A shared edge is not support, so the comparison is strict by a hair.
	const EDGE := 0.5
	return (a.position.x < b.end.x - EDGE and b.position.x < a.end.x - EDGE
		and a.position.z < b.end.z - EDGE and b.position.z < a.end.z - EDGE)


static func _sequence(nodes: Array[Node2]) -> Array[Step]:
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node

	var remaining: Array[Node2] = nodes.duplicate()
	var placed: Dictionary = {}
	var steps: Array[Step] = []
	var last_at: Vector3 = Vector3.ZERO
	var have_last: bool = false

	while not remaining.is_empty():
		var step := Step.new()
		step.index = steps.size() + 1

		while step.brick_ids.size() < MAX_PER_STEP:
			var pick: int = _next(remaining, placed, last_at, have_last,
				not step.brick_ids.is_empty())
			if pick < 0:
				break

			var node: Node2 = remaining[pick]
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
static func _next(remaining: Array[Node2], placed: Dictionary,
		last_at: Vector3, have_last: bool, same_step: bool) -> int:
	var best: int = -1
	var best_score: float = INF
	var fallback: int = -1
	var fallback_height: float = -INF

	for index: int in remaining.size():
		var node: Node2 = remaining[index]
		# Lowest first: box.end.y is the underside with −Y up, so a
		# larger value is further down.
		if node.box.end.y > fallback_height:
			fallback_height = node.box.end.y
			fallback = index
		if not _ready(node, placed):
			continue

		var distance: float = (node.box.get_center().distance_to(last_at)
			if have_last else 0.0)
		if same_step and distance > NEAR:
			continue
		# Height dominates; distance only breaks ties within a layer, so
		# a nearby brick two layers up never jumps the queue.
		var score: float = -node.box.end.y * 1000.0 + distance
		if score < best_score:
			best_score = score
			best = index

	if best >= 0:
		return best
	# Nothing legal is near enough: end the step rather than reaching
	# across the model for the sake of filling it.
	if same_step:
		return -1
	return fallback


static func _ready(node: Node2, placed: Dictionary) -> bool:
	for need: int in node.needs:
		if not placed.has(need):
			return false
	return true
