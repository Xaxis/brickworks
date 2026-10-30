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


## Every brick of the colour, the part, or the part and colour ([param
## kind]) of any of [param seeds], in one look over the model. Asked seed by
## seed, with all of Orthanc selected, Same colour looked over its 9,429
## parts 9,429 times and held the window for over a minute (2026-10-13,
## command_probe).
static func matching_any(kind: String, world: BrickWorld, seeds: Array,
		scenery: Dictionary) -> Array:
	var wanted: Dictionary = {}
	for seed_id: int in seeds:
		var seed: BrickWorld.Brick = world.get_brick(seed_id)
		if seed != null:
			wanted[_trait(kind, seed)] = true
	if wanted.is_empty():
		return []
	return _where(world, scenery, func(brick: BrickWorld.Brick) -> bool:
		return wanted.has(_trait(kind, brick)))


## What a brick is matched by: its colour, its part, or both.
static func _trait(kind: String, brick: BrickWorld.Brick) -> Variant:
	match kind:
		"colour":
			return brick.color_code
		"part":
			return brick.part_id
	return "%s/%d" % [brick.part_id, brick.color_code]


## The parts and the colour a person asked for by name (Edit, Select by,
## Part number or name; the parts list's find; look_at_model's part=).
class Wanted extends RefCounted:
	## Part ids -> true; every part when [member any_part].
	var parts: Dictionary = {}
	var any_part: bool = false
	## An LDraw colour code, or -1 for any.
	var colour: int = -1

	func takes(part_id: String, colour_code: int) -> bool:
		return (any_part or parts.has(part_id)) and (colour < 0 or colour_code == colour)


## What [param said] asks for: a part's number ("3004", "3023" for 3023b
## too), its name in the catalogue's words or a builder's ("brick 1 x 2",
## "1x2 brick"), found as the parts bin finds them (PartLibrary.search) with
## every word; one of [param colours] (codes -> true: the model's own) by its
## name, LDraw's or LEGO's ("dark tan", "medium stone grey"); or both, "blue
## 1x2 brick". Nothing said is everything.
static func wanted(library: PartLibrary, said: String, colours: Dictionary) -> Wanted:
	var out := Wanted.new()
	var words: String = _plain(said)
	if words.is_empty():
		out.any_part = true
		return out
	var named: Array = _colour_in(library, words, colours)
	out.colour = int(named[0])
	var rest: String = str(named[1])
	if rest.is_empty():
		out.any_part = true
		return out
	out.parts = _parts_named(library, rest)
	# A colour's word in a part's own name: "black" in a print.
	if out.parts.is_empty() and out.colour >= 0:
		out.colour = -1
		out.parts = _parts_named(library, words)
	return out


## The parts with every word of [param words], by id.
static func _parts_named(library: PartLibrary, words: String) -> Dictionary:
	var out: Dictionary = {}
	for info: PartLibrary.PartInfo in library.search(words, library.parts.size(), true, false):
		out[info.id] = true
	return out


## The colour of [param colours] whose name is in [param words] whole, the
## longest such ("dark tan" before "tan"), and the words without it:
## [code, rest], or [-1, words] when none is.
static func _colour_in(library: PartLibrary, words: String, colours: Dictionary) -> Array:
	var padded: String = " %s " % words
	var best: int = -1
	var best_name: String = ""
	for code: int in colours:
		var color: PartLibrary.BrickColor = library.color(code)
		if color == null:
			continue
		for name: String in [color.name, color.lego_name]:
			var plain: String = _plain(name)
			if plain.length() > best_name.length() and padded.contains(" %s " % plain):
				best = code
				best_name = plain
	if best < 0:
		return [-1, words]
	return [best, padded.replace(" %s " % best_name, " ").strip_edges()]


## Lower case, words apart by one space, grey as LDraw spells it.
static func _plain(text: String) -> String:
	var words: String = text.to_lower().replace("_", " ").replace("-", " ").replace("gray", "grey")
	while words.contains("  "):
		words = words.replace("  ", " ")
	return words.strip_edges()


## Every brick in the same sub-model as any of these: the whole tower
## from one of its bricks. Nothing for a brick in none.
static func submodel(world: BrickWorld, seeds: Array, scenery: Dictionary) -> Array:
	var groups: Dictionary = {}
	for seed_id: int in seeds:
		var seed: BrickWorld.Brick = world.get_brick(seed_id)
		if seed != null and not seed.group.is_empty():
			groups[seed.group] = true
	if groups.is_empty():
		return []
	return _where(world, scenery, func(brick: BrickWorld.Brick) -> bool:
		return groups.has(brick.group))


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
##
## [param most] stops looking once that many are found: the properties
## panel says how many parts one is joined to, and on Orthanc counting all
## of them held the window for seconds at every click on a part. Looking
## stops too once every part is found: with all of Orthanc selected it
## went on asking each of its 10,101 parts what it was joined to, all of
## them found already (bigmodels, 2026-10-30).
static func connected(world: BrickWorld, lattice: BrickLattice,
		seeds: Array, scenery: Dictionary, most: int = 1 << 30) -> Array:
	var search := _Search.new(world, lattice, seeds, scenery)
	most = mini(most, search.everything)
	while not search.queue.is_empty() and search.found.size() < most:
		search.step()
	return search.found.keys()


## [method connected], a slice at a time (FramePace), [param job] counting
## what it has found; nothing when it was cancelled.
static func connected_paced(world: BrickWorld, lattice: BrickLattice,
		seeds: Array, scenery: Dictionary, job: Working.Job) -> Array:
	var search := _Search.new(world, lattice, seeds, scenery)
	while not search.queue.is_empty() and search.found.size() < search.everything:
		search.step()
		if job.due():
			job.count(search.found.size(), search.everything)
			await job.next()
			if job.cancelled:
				return []
	return search.found.keys()


## One look for everything joined to some bricks, a brick at a time.
class _Search extends RefCounted:
	var world: BrickWorld
	var lattice: BrickLattice
	var scenery: Dictionary
	## Brick id -> true: found so far, the seeds among them.
	var found: Dictionary = {}
	## Found and not yet asked what it is joined to.
	var queue: Array = []
	## How many there are to find: every brick but the scenery.
	var everything: int = 0
	## Per ground axis (x, then z), the bricks that can be joined across it
	## at all (SelectBy.sideways); empty until the look grows past
	## [constant SIDEWAYS_AFTER].
	var across: Array = []
	var asked: int = 0

	## Worked out once a look has gone this far: a click's count in the
	## properties panel stops long before, and pays nothing for it.
	const SIDEWAYS_AFTER := 256

	func _init(on: BrickWorld, cells: BrickLattice, seeds: Array, scene: Dictionary) -> void:
		world = on
		lattice = cells
		scenery = scene
		var standing: int = 0
		for brick_id: int in scenery:
			if world.get_brick(brick_id) != null:
				standing += 1
		everything = world.brick_count() - standing
		for seed_id: int in seeds:
			if world.get_brick(seed_id) != null and not scenery.has(seed_id) \
					and not found.has(seed_id):
				found[seed_id] = true
				queue.append(seed_id)

	## Ask the next brick what it is joined to.
	func step() -> void:
		if across.is_empty() and asked == SIDEWAYS_AFTER:
			across = SelectBy.sideways(world, lattice)
		asked += 1
		var here: int = queue.pop_back()
		for other: int in SelectBy._joined_to(world, lattice, here, across):
			if found.has(other) or scenery.has(other):
				continue
			found[other] = true
			queue.append(other)


## For each ground axis (x, then z), every brick that can be joined to
## another across it: those whose studs point along it, and every brick
## whose box comes within a cell of one of theirs along it. Any other brick
## is joined only above and below, and [method _joined_to] need not ask its
## sides: most of a model's parts, and two of every three of its questions.
static func sideways(world: BrickWorld, lattice: BrickLattice) -> Array:
	var out: Array = [{}, {}]
	for brick: BrickWorld.Brick in world.bricks():
		var axis: int = _axis_of(brick)
		if axis < 0:
			continue
		var bound: PackedInt32Array = BrickLattice._bound_of(lattice.boxes_of(brick.id))
		if bound.is_empty():
			continue
		var grown: PackedInt32Array = bound.duplicate()
		grown[axis] -= 1
		grown[axis + 3] += 1
		var these: Dictionary = out[axis / 2]
		these[brick.id] = true
		for other: int in lattice.near_bounds(grown, brick.id):
			these[other] = true
	return out


## The bricks one brick is held to: anything resting on its top or
## carrying its bottom, and, for a part whose studs do not point up or
## down, anything against the faces along its stud axis. With [param
## across] (see [method sideways]), a brick that cannot be joined across
## an axis is not asked about it.
static func _joined_to(world: BrickWorld, lattice: BrickLattice,
		brick_id: int, across: Array = []) -> Array:
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
		if not across.is_empty() and not (across[axis / 2] as Dictionary).has(brick_id):
			continue
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
	return _axis_of(brick)


static func _axis_of(brick: BrickWorld.Brick) -> int:
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
