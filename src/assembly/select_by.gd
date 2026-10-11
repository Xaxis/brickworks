## Ways to pick out many bricks at once from one.
##
## Studio's select tool has the same five under its small arrow: by colour,
## by part, by part and colour, everything connected, and the inverse.
## Here only part-and-colour existed, on a shift-double-click nothing on
## screen mentioned. Recolouring a wall that mixes 1 x 2s and 2 x 4s, or
## lifting a finished roof off a house, wants the others.
##
## Each returns brick ids and leaves the scenery — the baseplate — out:
## everything stands on it, so "connected" through it is the whole model.
class_name SelectBy
extends RefCounted


## One of colour, part or alike, by name.
static func matching(kind: String, world: BrickWorld, seed_id: int,
		scenery: Dictionary) -> Array:
	match kind:
		"colour":
			return colour(world, seed_id, scenery)
		"part":
			return part(world, seed_id, scenery)
		"alike":
			return alike(world, seed_id, scenery)
	return []


## Every brick of this colour.
static func colour(world: BrickWorld, seed_id: int, scenery: Dictionary) -> Array:
	var seed: BrickWorld.Brick = world.get_brick(seed_id)
	if seed == null:
		return []
	return _where(world, scenery, func(brick: BrickWorld.Brick) -> bool:
		return brick.color_code == seed.color_code)


## Every brick of this part, in any colour.
static func part(world: BrickWorld, seed_id: int, scenery: Dictionary) -> Array:
	var seed: BrickWorld.Brick = world.get_brick(seed_id)
	if seed == null:
		return []
	return _where(world, scenery, func(brick: BrickWorld.Brick) -> bool:
		return brick.part_id == seed.part_id)


## Every brick of this part in this colour.
static func alike(world: BrickWorld, seed_id: int, scenery: Dictionary) -> Array:
	var seed: BrickWorld.Brick = world.get_brick(seed_id)
	if seed == null:
		return []
	return _where(world, scenery, func(brick: BrickWorld.Brick) -> bool:
		return brick.part_id == seed.part_id and brick.color_code == seed.color_code)


## Everything not in this selection.
static func inverse(world: BrickWorld, selection: Dictionary,
		scenery: Dictionary) -> Array:
	return _where(world, scenery, func(brick: BrickWorld.Brick) -> bool:
		return not selection.has(brick.id))


## Everything held to these bricks by studs, however far: the roof and
## all that is on it, a wing and its flaps.
##
## Read off the lattice, where a stud joint is one box resting on another
## with some of their footprints in common. Two bricks side by side touch
## and are not joined, which is what makes this different from "touching"
## — a wall bay set beside another comes away on its own. A part lying on
## its side is joined across the face its studs point through, so a
## sideways panel on a SNOT brick comes with it.
static func connected(world: BrickWorld, lattice: BrickLattice,
		seeds: Array, scenery: Dictionary) -> Array:
	var found: Dictionary = {}
	var queue: Array = []
	for seed_id: int in seeds:
		if world.get_brick(seed_id) != null and not scenery.has(seed_id):
			found[seed_id] = true
			queue.append(seed_id)
	while not queue.is_empty():
		var here: int = queue.pop_back()
		for other: int in _joined_to(world, lattice, here):
			if found.has(other) or scenery.has(other):
				continue
			found[other] = true
			queue.append(other)
	return found.keys()


## The bricks one brick is held to: anything resting on its top or
## carrying its bottom, and, for a part whose studs do not point up or
## down, anything against the faces along its stud axis.
static func _joined_to(world: BrickWorld, lattice: BrickLattice,
		brick_id: int) -> Array:
	var mine: PackedInt32Array = lattice.boxes_of(brick_id)
	if mine.is_empty():
		return []
	var out: Dictionary = {}
	# Above and below: always a joint.
	for other: int in lattice.blockers_boxes(_shell(mine, 1), brick_id):
		out[other] = true
	# Across the sides: a joint when either part's studs point that way.
	# Asked from both ends, so the panel finds the SNOT brick and the SNOT
	# brick finds the panel.
	var own: int = _stud_axis(world, brick_id)
	for axis: int in [0, 2]:
		for other: int in lattice.blockers_boxes(_shell(mine, axis), brick_id):
			if own == axis or _stud_axis(world, other) == axis:
				out[other] = true
	return out.keys()


## Which ground axis a part's studs point along: 0 for x, 2 for z, or -1
## when they point up or down, as most do.
static func _stud_axis(world: BrickWorld, brick_id: int) -> int:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return -1
	var face: String = BrickLattice.face_of(brick.transform.basis)
	if face == "+x" or face == "-x":
		return 0
	if face == "+z" or face == "-z":
		return 2
	return -1


## The slabs against every box's two faces across an axis.
static func _shell(boxes: PackedInt32Array, axis: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n: int = 0
	while n < boxes.size():
		_slab(out, Vector3i(boxes[n], boxes[n + 1], boxes[n + 2]),
			Vector3i(boxes[n + 3], boxes[n + 4], boxes[n + 5]), axis)
		n += 6
	return out


## The two one-cell slabs against a box's faces across an axis, inset by a
## cell along the others so that bricks meeting only at an edge or a
## corner are not taken for joined.
static func _slab(into: PackedInt32Array, lo: Vector3i, hi: Vector3i, axis: int) -> void:
	for side: int in [0, 1]:
		var a: Vector3i = lo
		var b: Vector3i = hi
		for other: int in 3:
			if other == axis:
				continue
			if b[other] - a[other] > 2:
				a[other] += 1
				b[other] -= 1
		if side == 0:
			b[axis] = lo[axis]
			a[axis] = lo[axis] - 1
		else:
			a[axis] = hi[axis]
			b[axis] = hi[axis] + 1
		into.append_array(PackedInt32Array([a.x, a.y, a.z, b.x, b.y, b.z]))


static func _where(world: BrickWorld, scenery: Dictionary, keep: Callable) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id) or brick.hidden:
			continue
		if keep.call(brick):
			out.append(brick.id)
	return out
