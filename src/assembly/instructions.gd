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
##
## And some of a model is not built on the model at all. A minifigure, a
## window, a lamp: a real booklet builds those on the side in a framed
## callout — "4x" when there are four the same — and then puts them on
## in one step, with an arrow. A document that builds its window once
## and places it four times has said so (LdrModel.Placement.unit), and a
## figure is a figure wherever it came from; each becomes one piece of
## the main build here, and its own short build in the callout.
class_name Instructions
extends RefCounted

## Bricks added at once, at most. Kept small: a step is what someone holds
## in their hand before looking back at the page. Fewer still on a small
## model (see _per_step): a seventy-piece house in steps of eight is
## thirteen pictures, where a set that size has twenty-five.
const MAX_PER_STEP := 8

## A callout's steps are smaller again. LEGO's are one to three parts,
## because the callout's pictures are a third the size of the page's.
const CALLOUT_PER_STEP := 3

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

## The most parts a sub-model can have and still be built on the side.
## Past this it is a part of the model — a floor, a wing — built where it
## stands, a section rather than a callout.
const ASSEMBLY_MOST := 60

## How [method _next] chose: in the region being built, a brick it was
## waiting for, or a move to another region.
const HERE := 0
const BORROWED := 1
const MOVED := 2


class Step extends RefCounted:
	## Where it comes in the list, from 1.
	var index: int = 0
	## The number the booklet prints. A callout's steps carry the number
	## of the step its assembly is put on in, as in a real booklet: the
	## window built in a box beside step 44 is part of step 44.
	var number: int = 0
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

	## What a sub-assembly is called ("Window", "Gandalf the Grey"), on
	## the steps that build it and the step that puts it on. Empty on the
	## main build.
	var assembly: String = ""
	## Which callout, numbered from 1 through the booklet; 0 for a step
	## with none.
	var callout: int = 0
	## This step's place in its callout, from 1; 0 on the step that puts
	## the finished assembly on the model.
	var callout_step: int = 0
	var callout_steps: int = 0
	## How many copies the callout builds: the booklet's "4x".
	var times: int = 1
	## A minifigure, which is put together in one step.
	var figure: bool = false
	## A callout's step: what it adds to the first copy, which is the one
	## the picture shows. brick_ids has every copy's.
	var shown_ids: PackedInt64Array = PackedInt64Array()
	## The step that puts it on: each copy's bricks, the first copy first.
	var copies: Array[PackedInt64Array] = []

	## A step inside a callout box.
	func in_callout() -> bool:
		return callout_step > 0

	## The step a finished sub-assembly is put on the model in.
	func attaches() -> bool:
		return callout > 0 and callout_step == 0

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

	## What the timeline says this step is, numbered as the booklet is.
	func caption(main_steps: int) -> String:
		var said: String = "Step %d of %d" % [number, main_steps]
		if not assembly.is_empty():
			var what: String = assembly + (" (%dx)" % times if times > 1 else "")
			if in_callout():
				said += " · %s, %d of %d" % [what, callout_step, callout_steps]
			else:
				said += " · %s, put on" % what
		if not section.is_empty():
			said += " · %s" % section
		return said


## Where a brick sits and what it rests on.
class Node2 extends RefCounted:
	var id: int
	var box: AABB
	var part_id: String
	## The assembly a design named, or the sub-model it was read from.
	var group: String = ""
	## Which copy of which sub-model: see LdrModel.Placement.unit.
	var unit: String = ""
	## Which part of the model it is built with. See [constant REGION].
	var region: String = ""
	## Bricks that must be placed before this one.
	var needs: PackedInt64Array = PackedInt64Array()
	## What must be placed first in the build this node is sequenced in:
	## its needs, with every sub-assembly standing for its own parts.
	var after: PackedInt64Array = PackedInt64Array()
	## Set on the node that stands for a whole sub-assembly.
	var assembly: Assembly = null


## A part of the model built on the side and put on whole.
class Assembly extends RefCounted:
	var key: String = ""
	var name: String = ""
	## Two copies are the same kind when they have the same name and the
	## same parts in the same colours: what the booklet builds once, "2x".
	var kind: String = ""
	var members: Array[Node2] = []
	var figure: bool = false
	## The node standing for it in the main build.
	var node: Node2 = null


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
	_tidy_needs(nodes)
	_find_hangers(nodes)
	var assemblies: Array[Assembly] = _find_assemblies(nodes, world, library)
	var built: Array[Node2] = _contract(nodes, assemblies)
	var named: bool = _assign_regions(built, regions)
	var raw: Array = _sequence(built, named, _per_step(nodes.size()))
	var steps: Array[Step] = _expand(raw, world)
	# A node and its assembly point at each other, and two RefCounted
	# objects that do are never freed.
	for made: Assembly in assemblies:
		made.node = null
	return steps


## How many bricks a step takes, by the size of the model. A real
## seventy-piece set has about three to a step and a two-thousand-piece
## one about six; eight was every model's, which made a small one's
## booklet half as long as its set's.
static func _per_step(count: int) -> int:
	if count < 150:
		return 4
	if count < 500:
		return 6
	return MAX_PER_STEP


## Which region each brick is built with.
##
## By area, a big model is cut into equal tiles of the plan no wider than
## REGION. Equal rather than fixed, so a model 30 studs wide is two
## halves and not a 24-stud region and a 6-stud sliver.
##
## A sub-assembly is built with whatever it is put on: a figure is not a
## part of the castle of its own, it is part of the gatehouse it stands
## in. And one name across the whole model is no division at all.
##
## Returns whether the regions have names a person gave them, which the
## booklet uses as they are, rather than tiles it numbers.
static func _assign_regions(nodes: Array[Node2], given: Dictionary) -> bool:
	var names: Dictionary = {}
	for node: Node2 in nodes:
		if node.assembly != null:
			node.region = ""
			if not given.is_empty():
				node.region = _most_common(node.assembly.members.map(
					func(member: Node2) -> String: return str(given.get(member.id, ""))))
		elif not given.is_empty():
			node.region = str(given.get(node.id, ""))
		else:
			node.region = node.group
		if not node.region.is_empty():
			names[node.region] = true
	if names.size() >= 2:
		for node: Node2 in nodes:
			if node.region.is_empty() and node.assembly == null:
				node.region = "the rest"
		_place_assemblies(nodes)
		return true

	for node: Node2 in nodes:
		node.region = ""
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


## A sub-assembly with no region of its own takes the region of what it
## is put on, or failing that of the nearest brick that has one.
static func _place_assemblies(nodes: Array[Node2]) -> void:
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node
	for node: Node2 in nodes:
		if node.assembly == null or not node.region.is_empty():
			continue
		var under: Array = []
		for need: int in node.after:
			var other: Node2 = by_id.get(need)
			if other != null and not other.region.is_empty():
				under.append(other.region)
		if not under.is_empty():
			node.region = _most_common(under)
			continue
		var nearest: float = INF
		for other: Node2 in nodes:
			if other.region.is_empty():
				continue
			var gap: float = other.box.get_center().distance_to(node.box.get_center())
			if gap < nearest:
				nearest = gap
				node.region = other.region
		if node.region.is_empty():
			node.region = "the rest"


static func _most_common(values: Array) -> String:
	var counts: Dictionary = {}
	var best: String = ""
	for value: Variant in values:
		var key: String = str(value)
		if key.is_empty():
			continue
		counts[key] = int(counts.get(key, 0)) + 1
		if best.is_empty() or int(counts[key]) > int(counts[best]):
			best = key
	return best


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


## A part with nothing under it is held by what it touches.
##
## A tap clipped to the side of a brick, wheels on a skateboard's axle, a
## lamp under a bracket: nothing is beneath them and no pin goes into
## them, so they needed nothing and were free to be step one, hanging in
## the air beside an empty table. Off the table and resting on nothing,
## a part needs whatever it touches that does rest on something — unless
## that would make a loop: a part with nothing under it that something
## else stands on is the bottom of its own little stack, and waiting for
## the stack would wait for ever. Those 258 loops were Orthanc's first
## try at this, every one a step taken "out of order".
static func _find_hangers(nodes: Array[Node2]) -> void:
	if nodes.is_empty():
		return
	const CELL := 40.0
	var floor_y: float = INF
	for node: Node2 in nodes:
		floor_y = minf(floor_y, node.box.position.y)
	var hanging: Dictionary = {}
	for index: int in nodes.size():
		var node: Node2 = nodes[index]
		if node.needs.is_empty() and node.box.position.y > floor_y + 2.0:
			hanging[index] = true
	if hanging.is_empty():
		return
	var grid: Dictionary = {}
	for index: int in nodes.size():
		for cell: Vector2i in _cells(nodes[index].box.grow(1.0), CELL):
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(index)
	for index: int in hanging:
		var node: Node2 = nodes[index]
		var box: AABB = node.box.grow(1.0)
		var seen: Dictionary = {}
		for cell: Vector2i in _cells(box, CELL):
			for other_index: int in grid.get(cell, []):
				if other_index == index or seen.has(other_index) \
						or hanging.has(other_index):
					continue
				seen[other_index] = true
				if box.intersects(nodes[other_index].box) \
						and not nodes[other_index].needs.has(node.id):
					node.needs.append(nodes[other_index].id)
	var before: Dictionary = _in_loops(nodes)
	for node: Node2 in nodes:
		node.after = node.needs.duplicate()
	for _attempt: int in 3:
		var stuck: Dictionary = _in_loops(nodes)
		var undone: bool = false
		for index: int in hanging:
			var node: Node2 = nodes[index]
			if stuck.has(node.id) and not before.has(node.id) \
					and not node.needs.is_empty():
				node.needs = PackedInt64Array()
				node.after = PackedInt64Array()
				undone = true
		if not undone:
			break


## Needs only on bricks that are being built, once each. A joint into the
## baseplate is a need nothing will ever place, and a brick waiting on it
## was forced, as if it were hanging in the air.
static func _tidy_needs(nodes: Array[Node2]) -> void:
	var here: Dictionary = {}
	for node: Node2 in nodes:
		here[node.id] = true
	for node: Node2 in nodes:
		var kept := PackedInt64Array()
		for need: int in node.needs:
			if here.has(need) and not kept.has(need) and need != node.id:
				kept.append(need)
		node.needs = kept
		node.after = kept.duplicate()


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
		node.group = brick.group
		node.unit = brick.unit
		nodes.append(node)
	return nodes


## Who rests on whom.
##
## A brick needs another when it sits directly on top of it and their
## footprints overlap. "Directly" has to have some slack in it: a stud is
## 4 LDU proud of the brick below, so a part resting on studs has its
## underside a little into the part beneath rather than exactly on it.
##
## Each brick is compared with the bricks that share a two-stud square of
## the plan with it, not with every brick in the model: all against all
## was 74 million comparisons on an 8,600-part tower, and a minute and a
## half before its timeline could open.
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
	const CELL := 40.0
	var grid: Dictionary = {}
	for index: int in nodes.size():
		for cell: Vector2i in _cells(nodes[index].box, CELL):
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(index)
	for index: int in nodes.size():
		var node: Node2 = nodes[index]
		var seen: Dictionary = {}
		for cell: Vector2i in _cells(node.box, CELL):
			for other_index: int in grid.get(cell, []):
				if other_index == index or seen.has(other_index):
					continue
				seen[other_index] = true
				var other: Node2 = nodes[other_index]
				# other is under node when other's top meets node's
				# underside, allowing for the stud that reaches up into it.
				var sits_on: bool = (other.box.end.y >= node.box.position.y - SLACK
					and other.box.end.y <= node.box.position.y + SLACK)
				if sits_on and _overlaps_flat(node.box, other.box):
					node.needs.append(other.id)


static func _cells(box: AABB, size: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in range(floori(box.position.x / size), floori(box.end.x / size) + 1):
		for z: int in range(floori(box.position.z / size), floori(box.end.z / size) + 1):
			cells.append(Vector2i(x, z))
	return cells


static func _overlaps_flat(a: AABB, b: AABB) -> bool:
	# A shared edge is not support, so the comparison is strict by a hair.
	const EDGE := 0.5
	return (a.position.x < b.end.x - EDGE and b.position.x < a.end.x - EDGE
		and a.position.z < b.end.z - EDGE and b.position.z < a.end.z - EDGE)


# -- sub-assemblies --------------------------------------------------------


## The parts of the model to build on the side.
##
## A sub-model the document places at the top level is one candidate; if
## it is too big to be one — a floor of a house, the gatehouse of a
## castle — each sub-model it places is a candidate instead. A minifigure
## is always one, by its parts, whatever size the rest is. A candidate
## must hold together on its own (built on the side, it has to be one
## thing to pick up) and must not be most of the model.
static func _find_assemblies(nodes: Array[Node2], world: BrickWorld,
		library: PartLibrary) -> Array[Assembly]:
	var tops: Dictionary = {}
	var inner: Dictionary = {}
	for node: Node2 in nodes:
		var top: String = ""
		var sub: String = ""
		if not node.unit.is_empty():
			var path: PackedStringArray = node.unit.split("/")
			top = path[0]
			if path.size() > 1:
				sub = path[0] + "/" + path[1]
		elif not node.group.is_empty():
			top = "group:" + node.group
		if top.is_empty():
			continue
		if not tops.has(top):
			tops[top] = []
		(tops[top] as Array).append(node)
		if not sub.is_empty():
			if not inner.has(sub):
				inner[sub] = []
			(inner[sub] as Array).append(node)

	var found: Array[Assembly] = []
	for top: String in tops:
		var members: Array = tops[top]
		var figure: bool = _is_figure(members, world, library)
		if figure or _holds_together(members, nodes.size()):
			found.append(_assembly(top, members, figure, world))
			continue
		for sub: String in inner:
			if not sub.begins_with(top + "/"):
				continue
			var parts: Array = inner[sub]
			var sub_figure: bool = _is_figure(parts, world, library)
			if sub_figure or _holds_together(parts, nodes.size()):
				found.append(_assembly(sub, parts, sub_figure, world))
	return found


static func _is_figure(members: Array, world: BrickWorld,
		library: PartLibrary) -> bool:
	if members.size() < 3 or members.size() > 24:
		return false
	var bricks: Array = []
	for node: Node2 in members:
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		if brick != null:
			bricks.append(brick)
	return Minifig.is_figure(bricks, library)


## Small enough to be built on the side, and one piece when it is.
static func _holds_together(members: Array, total: int) -> bool:
	if members.size() < 2 or members.size() > ASSEMBLY_MOST:
		return false
	if members.size() * 10 > total * 3:
		return false
	# One piece: every part touches another, by their boxes grown by a
	# hair. Supports alone would split a window from the glass clipped
	# into its side.
	var reached: Dictionary = {0: true}
	var frontier: Array[int] = [0]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		var box: AABB = (members[at] as Node2).box.grow(1.0)
		for other: int in members.size():
			if reached.has(other):
				continue
			if box.intersects((members[other] as Node2).box):
				reached[other] = true
				frontier.append(other)
	return reached.size() == members.size()


static func _assembly(key: String, members: Array, figure: bool,
		world: BrickWorld) -> Assembly:
	var made := Assembly.new()
	made.key = key
	made.figure = figure
	made.name = _name_of(key)
	var colours := PackedStringArray()
	for node: Node2 in members:
		made.members.append(node)
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		colours.append("%s:%d" % [node.part_id, brick.color_code if brick else 0])
	colours.sort()
	made.kind = made.name + "|" + ",".join(colours)
	return made


## "31009 - Big Window#2" -> "big window"; "group:Gandalf the Grey" ->
## "Gandalf the Grey". The set number a published model puts in front of
## every sub-model's name says nothing on a page about that set.
static func _name_of(key: String) -> String:
	var name: String = key.trim_prefix("group:").get_slice("/", key.count("/"))
	if name.contains("#"):
		name = name.substr(0, name.rfind("#"))
	name = name.trim_suffix(".ldr").trim_suffix(".dat").replace("_", " ").strip_edges()
	var number := RegEx.create_from_string("^[0-9]+(-[0-9]+)?\\s*-\\s*")
	name = number.sub(name, "").strip_edges()
	if name.is_empty():
		return "sub-assembly"
	if name == name.to_lower():
		return name
	# A title as the document wrote it, unless it is all one case.
	return name if name != name.to_upper() else name.capitalize()


## Stand each sub-assembly in the main build as one node.
##
## Its node needs what its parts need from outside it, and whatever rests
## on one of its parts needs the whole of it. If that makes a loop — a
## brick of the wall sitting between two of the assembly's own parts —
## it cannot be built on the side after all, and is built in place.
static func _contract(nodes: Array[Node2], assemblies: Array[Assembly]) -> Array[Node2]:
	var loops: Dictionary = _in_loops(nodes)
	for _attempt: int in 6:
		var member_of: Dictionary = {}
		for index: int in assemblies.size():
			var made: Assembly = assemblies[index]
			made.node = Node2.new()
			made.node.id = -(index + 1)
			made.node.assembly = made
			made.node.part_id = ""
			made.node.box = made.members[0].box
			for member: Node2 in made.members:
				made.node.box = made.node.box.merge(member.box)
				member_of[member.id] = made
		var built: Array[Node2] = []
		for node: Node2 in nodes:
			if member_of.has(node.id):
				continue
			node.after = _mapped(node.needs, member_of, null)
			built.append(node)
		for made: Assembly in assemblies:
			var needs := PackedInt64Array()
			for member: Node2 in made.members:
				needs.append_array(member.needs)
			made.node.after = _mapped(needs, member_of, made)
			built.append(made.node)

		var stuck: Dictionary = _in_loops(built)
		var kept: Array[Assembly] = []
		for made: Assembly in assemblies:
			var already: bool = made.members.any(
				func(member: Node2) -> bool: return loops.has(member.id))
			if stuck.has(made.node.id) and not already:
				continue
			kept.append(made)
		if kept.size() == assemblies.size():
			return built
		assemblies.assign(kept)
	# Nothing settled: build everything in place.
	assemblies.clear()
	for node: Node2 in nodes:
		node.after = node.needs.duplicate()
	return nodes.duplicate()


static func _mapped(needs: PackedInt64Array, member_of: Dictionary,
		own: Assembly) -> PackedInt64Array:
	var out := PackedInt64Array()
	for need: int in needs:
		var target: int = need
		var made: Assembly = member_of.get(need)
		if made != null:
			if made == own:
				continue
			target = made.node.id
		if not out.has(target):
			out.append(target)
	return out


## The nodes that can never be placed in order: on a loop of needs, or
## waiting on one.
static func _in_loops(nodes: Array[Node2]) -> Dictionary:
	var waiting: Dictionary = {}
	var dependents: Dictionary = {}
	var here: Dictionary = {}
	for node: Node2 in nodes:
		here[node.id] = true
	for node: Node2 in nodes:
		var count: int = 0
		for need: int in node.after:
			if here.has(need):
				count += 1
				if not dependents.has(need):
					dependents[need] = []
				(dependents[need] as Array).append(node.id)
		waiting[node.id] = count
	var free: Array[int] = []
	for node: Node2 in nodes:
		if int(waiting[node.id]) == 0:
			free.append(node.id)
	while not free.is_empty():
		var id: int = free.pop_back()
		waiting.erase(id)
		for dependent: int in dependents.get(id, []):
			waiting[dependent] = int(waiting[dependent]) - 1
			if int(waiting[dependent]) == 0:
				free.append(dependent)
	return waiting


# -- the order ---------------------------------------------------------------


## The build order as steps of nodes: [{nodes, section, unsupported}].
##
## Bricks waiting on nothing are kept in a set as they become ready, so a
## pick looks at the few hundred that could go next rather than at every
## brick left: a pass over all of them per brick was the other half of
## the 8,600-part tower's minute and a half.
static func _sequence(nodes: Array[Node2], named: bool, per_step: int) -> Array:
	var by_id: Dictionary = {}
	var waiting: Dictionary = {}
	var dependents: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node
	for node: Node2 in nodes:
		var count: int = 0
		for need: int in node.after:
			if by_id.has(need):
				count += 1
				if not dependents.has(need):
					dependents[need] = []
				(dependents[need] as Array).append(node.id)
		waiting[node.id] = count
	var remaining: Dictionary = {}
	var ready: Dictionary = {}
	for node: Node2 in nodes:
		remaining[node.id] = node
		if int(waiting[node.id]) == 0:
			ready[node.id] = node

	var steps: Array = []
	var last_at: Vector3 = Vector3.ZERO
	var have_last: bool = false
	## The region being built, and what each one is called in the
	## booklet: its own name, or "part n" in the order they are reached.
	var current: String = ""
	var called: Dictionary = {}

	while not remaining.is_empty():
		var picked: Array[Node2] = []
		var section: String = ""
		var unsupported: bool = false
		while picked.size() < per_step:
			var first: Node2 = picked[0] if not picked.is_empty() else null
			var chosen: Array = _next(ready, remaining, last_at, have_last,
				first, current)
			var node: Node2 = chosen[0]
			if node == null:
				break
			# A brick from next door that this region was waiting for is
			# built as part of it; anything else is a move.
			if node.region != current and int(chosen[1]) == MOVED:
				current = node.region
				if not called.has(current) and not current.is_empty():
					called[current] = (current if named
						else "part %d" % (called.size() + 1))
			section = str(called.get(current, ""))
			# A step that had to break the support rule says so, and ends
			# there: whatever comes next is resting on a brick that is
			# only just in place, and running them together would hide
			# which one was the awkward part.
			var forced: bool = int(waiting[node.id]) > 0
			if forced and not picked.is_empty():
				break

			remaining.erase(node.id)
			ready.erase(node.id)
			for dependent: int in dependents.get(node.id, []):
				waiting[dependent] = int(waiting[dependent]) - 1
				if int(waiting[dependent]) == 0 and remaining.has(dependent):
					ready[dependent] = by_id[dependent]
			picked.append(node)
			unsupported = unsupported or forced
			last_at = node.box.get_center()
			have_last = true
			if forced:
				break

		if picked.is_empty():
			# Cannot happen — _next falls back to the lowest remaining
			# brick — but an empty step here would spin forever, and a
			# loop that cannot end is worse than a booklet that stops.
			push_warning("instructions: %d bricks could not be ordered"
				% remaining.size())
			break
		steps.append({"nodes": picked, "section": section,
			"unsupported": unsupported})
	return steps


## The next node to place, or null when the step should end.
##
## [param first] is the first node of the step being filled, or null at
## the start of one. A step already begun only takes something near the
## last brick placed, so it stays in one place; the first node of a step
## is free to go anywhere, which is what lets the build move on to a new
## area. A step that puts a sub-assembly on puts on only more of the same
## kind, wherever they go — "4x", with an arrow to each — and a step of
## bricks takes no sub-assembly: it is a step of its own, with its box.
##
## Within the region being built while anything in it can be placed. When
## nothing in it is ready, the bricks it is directly waiting for come
## next and are built as part of it — a wall brick across a region's edge
## rests on its neighbour's. Past that the build moves to the nearest
## region and comes back later: borrowing further than one brick deep
## measured as one section swallowing 1,175 of a castle's 1,483 steps.
##
## Returns [node, how]: how is [constant HERE], [constant BORROWED] or
## [constant MOVED].
static func _next(ready: Dictionary, remaining: Dictionary,
		last_at: Vector3, have_last: bool, first: Node2,
		current: String = "") -> Array:
	var same_step: bool = first != null
	var kind: String = (first.assembly.kind
		if same_step and first.assembly != null else "")
	var fits := func(node: Node2) -> bool:
		if not same_step:
			return true
		if kind.is_empty():
			return node.assembly == null
		return node.assembly != null and node.assembly.kind == kind

	var here: Node2 = _best(ready, last_at, have_last, same_step and kind.is_empty(),
		func(node: Node2) -> bool: return node.region == current and fits.call(node),
		false)
	if here != null:
		return [here, HERE]
	# Nothing legal is near enough: end the step rather than reaching
	# across the model, or into another region, for the sake of filling it.
	if same_step:
		return [null, HERE]

	var wanted: Dictionary = {}
	for node: Node2 in remaining.values():
		if node.region != current:
			continue
		for need: int in node.after:
			if remaining.has(need):
				wanted[need] = true
	var borrowed: Node2 = _best(ready, last_at, have_last, false,
		func(node: Node2) -> bool: return wanted.has(node.id), false)
	if borrowed != null:
		return [borrowed, BORROWED]

	var moved: Node2 = _best(ready, last_at, have_last, false,
		func(_node: Node2) -> bool: return true, true)
	if moved != null:
		return [moved, MOVED]
	# Nothing anywhere is ready: the lowest remaining goes in anyway, and
	# the step says so. With +Y up the underside is box.position.y, so the
	# smallest value is the one nearest the table.
	var lowest: Node2 = null
	for node: Node2 in remaining.values():
		if lowest == null or node.box.position.y < lowest.box.position.y:
			lowest = node
	return [lowest, MOVED]


## The best ready node among those [param allowed] admits, or null.
##
## Height dominates; distance only breaks ties within a layer, so a
## nearby brick two layers up never jumps the queue. Moving to a new
## region it is the other way round: nothing is built there yet, so
## whatever is ready is near the table anyway, and the nearest one keeps
## the build moving to the region next door rather than across the model.
static func _best(ready: Dictionary, last_at: Vector3, have_last: bool,
		same_step: bool, allowed: Callable, nearest_first: bool) -> Node2:
	var best: Node2 = null
	var best_score: float = INF
	for node: Node2 in ready.values():
		if not allowed.call(node):
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
			best = node
	return best


# -- steps -------------------------------------------------------------------


## Number the steps and open each sub-assembly into its callout: its own
## steps, then the step that puts it on.
static func _expand(raw: Array, world: BrickWorld) -> Array[Step]:
	var out: Array[Step] = []
	var number: int = 0
	var callouts: int = 0
	for entry: Dictionary in raw:
		number += 1
		var picked: Array = entry["nodes"]
		var first: Node2 = picked[0]
		if first.assembly == null:
			var step := Step.new()
			step.number = number
			step.section = str(entry["section"])
			step.unsupported = bool(entry["unsupported"])
			for node: Node2 in picked:
				_add(step, node)
			out.append(step)
			continue

		callouts += 1
		var made: Assembly = first.assembly
		var per: int = 99 if made.figure else CALLOUT_PER_STEP
		var plans: Array = []
		for node: Node2 in picked:
			plans.append(_on_the_side(node.assembly, per))
		var count: int = (plans[0] as Array).size()
		for at: int in count:
			var step := Step.new()
			step.number = number
			step.section = str(entry["section"])
			step.assembly = made.name
			step.figure = made.figure
			step.callout = callouts
			step.callout_step = at + 1
			step.callout_steps = count
			step.times = picked.size()
			for copy: int in plans.size():
				var plan: Array = plans[copy]
				# A copy that came out in more steps than the first puts
				# what is left over in the last one.
				var chunks: Array = [plan[at]] if at < plan.size() else []
				if at == count - 1 and plan.size() > count:
					chunks = plan.slice(at)
				for chunk: Dictionary in chunks:
					step.unsupported = step.unsupported or bool(chunk["unsupported"])
					for node: Node2 in chunk["nodes"]:
						_add(step, node)
						if copy == 0:
							step.shown_ids.append(node.id)
			out.append(step)
		var attach := Step.new()
		attach.number = number
		attach.section = str(entry["section"])
		attach.assembly = made.name
		attach.figure = made.figure
		attach.callout = callouts
		attach.callout_steps = count
		attach.times = picked.size()
		attach.unsupported = bool(entry["unsupported"])
		for node: Node2 in picked:
			var ids := PackedInt64Array()
			for chunk: Dictionary in plans[picked.find(node)]:
				for member: Node2 in chunk["nodes"]:
					ids.append(member.id)
			attach.copies.append(ids)
		out.append(attach)
	for index: int in out.size():
		out[index].index = index + 1
	return out


static func _add(step: Step, node: Node2) -> void:
	step.brick_ids.append(node.id)
	step.parts[node.part_id] = int(step.parts.get(node.part_id, 0)) + 1


## A sub-assembly's own steps, built on the table: what its parts rest
## on among themselves, the lowest first. A figure goes together in one.
static func _on_the_side(made: Assembly, per_step: int) -> Array:
	var own: Dictionary = {}
	for member: Node2 in made.members:
		own[member.id] = true
	var members: Array[Node2] = []
	for member: Node2 in made.members:
		member.after = PackedInt64Array()
		for need: int in member.needs:
			if own.has(need):
				member.after.append(need)
		member.region = ""
		members.append(member)
	return _sequence(members, false, per_step)
