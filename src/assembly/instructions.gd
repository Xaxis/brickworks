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

## A step that puts a sub-assembly on takes the parts ready beside it.
const ATTACH_TAKES_PARTS := true
## How much later a wheel goes in than what is as low, and a part that
## touches nothing built yet: see [method _best].
const WHEELS_LATER := 1.0e9
const UNJOINED_LATER := 3.0e8
## A wheel goes on with the holder its pin is in ([method _hung_under]):
## off, as the authors build.
const WHEELS_WITH_HOLDER := false
## A step begun with a part that touches nothing standing looks elsewhere
## first for one that does ([method _steadier]).
const STEADIER_FIRST := true
## ...in another region too, not only one this region waits on.
const STEADIER_MOVES := false

## How far apart two of one part at one height can be and still go in one
## step: twelve studs, a row of tiles or a ring of 1 x 1s round a rim, as a
## set's booklet puts them in together.
const LIKE_REACH := 240.0

## How wide a region of a big model is, in LDU: twenty-four studs. Built
## course by course across the whole of it, a 1,895-part castle came to
## 281 steps whose bricks jumped a median of 12.5 studs and up to 61
## from one step to the next, across a model 72 wide, and every picture
## of them was the whole castle. A real set finishes the gatehouse before
## it starts a tower. A model no wider than this is one region, built
## exactly as before.
const REGION := 480.0

## The fewest parts a model is cut into tiles of its plan at. A 92-part
## spaceship wider than a tile was two tiles: "Part 1" a stand and a plate,
## one step on a page of its own under a banner, and "Part 2" twice, when
## the build went back to it. A set that size has no parts; the castle the
## tiles were made for had 1,895.
const TILED_FROM := 400

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
	## Which of the author's steps it is, for an edit to find (AuthorSteps):
	## the sub-model's path, "" for the model, and its number there. -1 for
	## a step worked out.
	var authored_in: String = ""
	var authored_step: int = -1

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

	## What the timeline says this step is, numbered as the booklet is:
	## "Step 12 of 40 · Window (2x), 1 of 3".
	func caption(main_steps: int) -> String:
		var said: String = "Step %d of %d" % [number, main_steps]
		if not assembly.is_empty():
			var what: String = assembly + (" (%dx)" % times if times > 1 else "")
			if in_callout():
				said += " · %s, %d of %d" % [what, callout_step, callout_steps]
			else:
				said += " · %s, put on" % what
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
	## A wheel rim (1) or a tyre (2): see [method _find_joints].
	var wheel: int = 0
	## What holds it without its resting on it: a stud from the side. See
	## [method _supports_of].
	var held_by: PackedInt64Array = PackedInt64Array()
	## A stud of its own, or of another, holds it to something.
	var studded: bool = false
	## It rests on studs, or on a part turned over on its studs: what it
	## rests on is read off those, not off its box.
	var seated: bool = false
	## What rests on its studs.
	var carries: PackedInt64Array = PackedInt64Array()
	## What its box sits on, for a part not seated on studs.
	var boxed: PackedInt64Array = PackedInt64Array()
	## The parts it is pressed up under, by its own studs, with nothing
	## beneath it: it goes in in the same step as the last of them. See
	## [method _pressed_up].
	var under: PackedInt64Array = PackedInt64Array()
	## Needs guessed for a part nothing holds by what its box touches, or
	## by height ([method _find_hangers]): given up before a sub-assembly is
	## ([method _contract]).
	var weak: PackedInt64Array = PackedInt64Array()
	## Off the table and held, as far as the plan knows, only by guesses:
	## it goes in after what is held for certain ([method _best]).
	var guessed: bool = false
	## The parts a pin, an axle or a wheel joins it to, either way round
	## ([method _find_joints]): with what it rests on, carries, hangs from and
	## is held by, what it touches ([method _touching]).
	var joined: PackedInt64Array = PackedInt64Array()
	## What its cover rests on or carries, either way round
	## ([method _contacts_of]).
	var contacts: PackedInt64Array = PackedInt64Array()
	## What rests on it by the covers: their covers sit on its own.
	var over: PackedInt64Array = PackedInt64Array()
	## What it hangs from that rests on it: it goes in in their step, on the
	## model ([method _hung_under]).
	var hung: PackedInt64Array = PackedInt64Array()

	## Every field of [param other] taken: a copy of a node the plan keeps
	## of a model's shape (_shaped), to change. A field added above goes here
	## too, or the copy has it at its default.
	func take(other: Node2) -> void:
		id = other.id
		box = other.box
		part_id = other.part_id
		group = other.group
		unit = other.unit
		region = other.region
		needs = other.needs
		after = other.after
		assembly = other.assembly
		wheel = other.wheel
		held_by = other.held_by
		studded = other.studded
		seated = other.seated
		carries = other.carries
		boxed = other.boxed
		under = other.under
		weak = other.weak
		guessed = other.guessed
		joined = other.joined
		contacts = other.contacts
		over = other.over
		hung = other.hung


## What fills a point, by the parts' own collision covers: the cover the
## build check's lattice holds, read in each part's own frame. The booklet's
## callers hold a world of bricks and no lattice, and building one is most of
## what a check costs; a stud's tip is one point, and the few parts whose
## boxes hold it are asked whether their covers do.
class Covers extends RefCounted:
	const BUCKET := 40.0
	var _bucket: Dictionary = {}        ## Vector3i -> Array of slots
	var _keys: Array = []
	var _inverse: Array[Transform3D] = []
	var _boxes: Array = []              ## slot -> Array[AABB], the part's own LDU
	var _bounds: Array[AABB] = []

	func add(key: Variant, at: Transform3D, part: Lbm.PartMesh) -> void:
		var slot: int = _keys.size()
		_keys.append(key)
		_inverse.append(at.affine_inverse())
		var own: Array[AABB] = []
		if part.boxes.is_empty():
			own.append(part.bounds)
		else:
			for box: AABB in part.boxes:
				own.append(AABB(box.position * part.cell_ldu, box.size * part.cell_ldu))
		_boxes.append(own)
		# A cover is whole cells, and reaches up to a cell past the part.
		var world: AABB = (at * part.bounds).grow(part.cell_ldu)
		_bounds.append(world)
		for x: int in range(floori(world.position.x / BUCKET), floori(world.end.x / BUCKET) + 1):
			for y: int in range(floori(world.position.y / BUCKET), floori(world.end.y / BUCKET) + 1):
				for z: int in range(floori(world.position.z / BUCKET),
						floori(world.end.z / BUCKET) + 1):
					var bucket := Vector3i(x, y, z)
					if not _bucket.has(bucket):
						_bucket[bucket] = []
					(_bucket[bucket] as Array).append(slot)

	## The key of the part whose cover holds [param point], other than
	## [param not_key]'s, or null.
	func at(point: Vector3, not_key: Variant) -> Variant:
		var near: Variant = _bucket.get(Vector3i(floori(point.x / BUCKET),
			floori(point.y / BUCKET), floori(point.z / BUCKET)))
		if near == null:
			return null
		for slot: int in near:
			if _keys[slot] == not_key or not _bounds[slot].has_point(point):
				continue
			var local: Vector3 = _inverse[slot] * point
			for box: AABB in _boxes[slot]:
				if box.has_point(local):
					return _keys[slot]
		return null


## What a step's picture shows of its own parts, by their boxes, from the
## front and from the back, the two ways a booklet looks (BookletStudio.FRONT,
## BACK): the faces of each box that look towards the eye, as points a pixel
## apart, as the steps score draws covers (src/dev/steps_score.gd
## _pictures).
##
## A step filled with whatever was ready and near hid its own parts: in 100
## real sets, 1,128 of the 1,535 steps of ours with a new thing hidden front
## and back hid it behind a part of the same step, a brick put on the plate
## it went in with (docs/INSTRUCTIONS.md). A part that would hide one the
## step already holds waits for the next step, where the first is built.
##
## Only what lands on the part asked about is drawn: the step's own parts and
## the parts of earlier steps whose pictures meet it from both sides and come
## nearer the eye. Drawing the whole build so far, to know what each new part
## already showed, was half of the time the order took (Orthanc's 5.1 s of
## 8.2), and two parts that do not meet from one side cannot hide each other
## from both.
class Pictures extends RefCounted:
	## A booklet's picture is a few hundred pixels across; a stud is 20 LDU.
	const PIXEL := 10.0
	## A new part shows at least this much of itself, from one side or the
	## other: the steps score's SEEN.
	const SEEN := 0.1
	## The cells, in LDU, that the parts built so far are kept in by their
	## boxes. Kept by where they landed in the front view, every part of a big
	## model along a line of sight was looked at for each part asked about,
	## to find the few near it: most of what the step pictures cost. Four
	## studs: at two, a part was found again in every cell it reached into,
	## and looking up what is in front took an eighth longer.
	const CELL := 80.0
	## How far, in LDU, an earlier part may be from one and still count as
	## in front of it: a stud and a bit.
	const IN_FRONT := 24.0
	var _frames: Array = []          ## [view, right, up] per view
	## node id -> its pixels in each view, {pixel: depth}, each drawn when it
	## is first asked for (null till then).
	var _own: Dictionary = {}
	var _span: Dictionary = {}       ## node id -> [Rect2, Rect2, Vector2, Vector2]
	var _built: Dictionary = {}      ## Vector3i -> the parts of earlier steps there
	var _before: Dictionary = {}     ## node id -> earlier parts that may be in front of it
	var _step: Array = []            ## the parts of the step being filled
	## node id -> the pixels of it still in sight in each view, with their
	## depths, as the step stands (null for a view not asked about yet):
	## worked out once a step, and each part the step takes after takes its
	## own out of them. A view is worked out only when it is asked about: a
	## part that leaves another in sight from the front need not be drawn
	## from the back, and drawing both for every part asked about was most
	## of what the step pictures cost.
	var _open: Dictionary = {}

	func _init() -> void:
		for view: Vector3 in [BookletStudio.FRONT.normalized(), BookletStudio.BACK.normalized()]:
			var right: Vector3 = Vector3.UP.cross(view).normalized()
			_frames.append([view, right, view.cross(right).normalized()])

	## Where [param node]'s box lands in each picture, as a rectangle, and
	## then how near the eye it comes in each, nearest and furthest.
	func span_of(node: Node2) -> Array:
		var known: Variant = _span.get(node.id)
		if known != null:
			return known
		var out: Array = []
		var depths: Array = []
		for frame: Array in _frames:
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			var depth := Vector2(INF, -INF)
			for corner: int in 8:
				var point: Vector3 = node.box.get_endpoint(corner)
				var flat := Vector2(point.dot(frame[1]), point.dot(frame[2])) / PIXEL
				low = low.min(flat)
				high = high.max(flat)
				var d: float = point.dot(frame[0])
				depth = Vector2(minf(depth.x, d), maxf(depth.y, d))
			out.append(Rect2(low, high - low))
			depths.append(depth)
		out.append_array(depths)
		_span[node.id] = out
		return out

	## [param node] goes into the step being filled.
	func accept(node: Node2) -> void:
		var theirs: Array = []
		var mine: Array = span_of(node)
		for other: Node2 in _step:
			if _open.has(other.id) and _meets(mine, span_of(other)):
				theirs.append(other)
		_step.append(node)
		for other: Node2 in theirs:
			var open: Array = _open[other.id]
			for v: int in 2:
				if open[v] != null:
					_cover(open[v], pixels_of(node, v))

	## A step is done: its parts are built, and may stand in front of the
	## next steps'.
	func built(step: Array) -> void:
		_before.clear()
		_open.clear()
		_step.clear()
		for node: Node2 in step:
			for key: Vector3i in _cells_of(node.box):
				if not _built.has(key):
					_built[key] = []
				(_built[key] as Array).append(node)

	## The cells [param box] reaches into.
	static func _cells_of(box: AABB) -> Array[Vector3i]:
		var out: Array[Vector3i] = []
		for x: int in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
			for y: int in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
				for z: int in range(floori(box.position.z / CELL), floori(box.end.z / CELL) + 1):
					out.append(Vector3i(x, y, z))
		return out

	## The parts of earlier steps near [param node] that land on it in both
	## pictures and come nearer the eye than its furthest point in both.
	func in_front(node: Node2) -> Array:
		var known: Variant = _before.get(node.id)
		if known != null:
			return known
		var mine: Array = span_of(node)
		var seen: Dictionary = {}
		var out: Array = []
		# Near it: a tower across the model does not hide a plate from both
		# sides, and on a big model everything in front of it is hundreds.
		var near: AABB = node.box.grow(IN_FRONT)
		for key: Vector3i in _cells_of(near):
			var there: Variant = _built.get(key)
			if there == null:
				continue
			for other: Node2 in there:
				if seen.has(other.id):
					continue
				seen[other.id] = true
				if not near.intersects(other.box):
					continue
				var theirs: Array = span_of(other)
				if _meets(mine, theirs) \
						and (theirs[2] as Vector2).y > (mine[2] as Vector2).x \
						and (theirs[3] as Vector2).y > (mine[3] as Vector2).x:
					out.append(other)
		_before[node.id] = out
		return out

	## Whether [param one] and [param other] land on each other in both
	## pictures.
	func meet(one: Node2, other: Node2) -> bool:
		return _meets(span_of(one), span_of(other))

	## [method meet] of two parts' spans ([method span_of]).
	static func _meets(a: Array, b: Array) -> bool:
		return (a[0] as Rect2).intersects(b[0]) and (a[1] as Rect2).intersects(b[1])

	## The pixels [param node]'s box covers from view [param v], and how near.
	func pixels_of(node: Node2, v: int) -> Dictionary:
		var known: Variant = _own.get(node.id)
		if known == null:
			known = [null, null]
			_own[node.id] = known
		var drawn: Variant = (known as Array)[v]
		if drawn != null:
			return drawn
		var frame: Array = _frames[v]
		var view: Vector3 = frame[0]
		var right: Vector3 = frame[1]
		var up: Vector3 = frame[2]
		var nearest: Dictionary = {}
		var from: Vector3 = node.box.position
		var to: Vector3 = node.box.end
		for axis: int in 3:
			if absf(view[axis]) < 0.001:
				continue
			var a: int = (axis + 1) % 3
			var b: int = (axis + 2) % 3
			var count_a: int = maxi(1, int(ceil((to[a] - from[a]) / PIXEL)))
			var count_b: int = maxi(1, int(ceil((to[b] - from[b]) / PIXEL)))
			var point := Vector3()
			point[axis] = to[axis] if view[axis] > 0.0 else from[axis]
			for i: int in count_a:
				point[a] = from[a] + (i + 0.5) * (to[a] - from[a]) / count_a
				for j: int in count_b:
					point[b] = from[b] + (j + 0.5) * (to[b] - from[b]) / count_b
					var pixel: int = (floori(point.dot(right) / PIXEL) << 24) \
						+ floori(point.dot(up) / PIXEL)
					var depth: float = point.dot(view)
					if depth > float(nearest.get(pixel, -INF)):
						nearest[pixel] = depth
		(known as Array)[v] = nearest
		return nearest

	## The pixels of [param node] in sight from view [param v], as the step
	## being filled and the earlier parts near it leave them.
	func open_of(node: Node2, v: int) -> Dictionary:
		var known: Variant = _open.get(node.id)
		if known == null:
			known = [null, null]
			_open[node.id] = known
		var left: Variant = (known as Array)[v]
		if left != null:
			return left
		var near: Array = []
		var mine: Array = span_of(node)
		for one: Node2 in _step:
			if one != node and _meets(span_of(one), mine):
				near.append(one)
		near.append_array(in_front(node))
		var open: Dictionary = pixels_of(node, v).duplicate()
		for other: Node2 in near:
			if open.is_empty():
				break
			_cover(open, pixels_of(other, v))
		(known as Array)[v] = open
		return open

	## Takes out of [param left] the pixels [param over] covers, nearer the
	## eye. Walking the smaller of the two: a 1 x 1 plate in front of a
	## baseplate is a handful of pixels, not a thousand. Every part in front
	## of each pixel of the one asked about, in turn, was most of what the
	## step pictures cost (76161's 2,398 parts, 490 ms of 630).
	static func _cover(left: Dictionary, over: Dictionary) -> void:
		if over.size() < left.size():
			for pixel: int in over:
				if left.has(pixel) and float(over[pixel]) > float(left[pixel]):
					left.erase(pixel)
		else:
			for pixel: int in left.keys():
				if over.has(pixel) and float(over[pixel]) > float(left[pixel]):
					left.erase(pixel)

	## How many of [param left]'s pixels [param over] covers, nearer the eye.
	static func _covered(left: Dictionary, over: Dictionary) -> int:
		var count: int = 0
		if over.size() < left.size():
			for pixel: int in over:
				if left.has(pixel) and float(over[pixel]) > float(left[pixel]):
					count += 1
		else:
			for pixel: int in left:
				if over.has(pixel) and float(over[pixel]) > float(left[pixel]):
					count += 1
		return count

	## Whether [param node] would hide one of [param step], parts the step
	## being filled holds that show now: one that shows a tenth of itself
	## from either side, and would not from both. A view at a time, and the
	## back only when the front leaves too little of it in sight.
	func would_hide(node: Node2, step: Array) -> bool:
		var mine: Array = span_of(node)
		for other: Node2 in step:
			if not _meets(mine, span_of(other)):
				continue
			var before: float = 0.0
			var hides: bool = true
			for v: int in 2:
				var left: Dictionary = open_of(other, v)
				var whole: float = float(pixels_of(other, v).size())
				# A part with no pixels in a view is not one this could hide.
				if whole == 0.0:
					hides = false
					break
				var over: Dictionary = pixels_of(node, v)
				# At most all of [param over] is taken out of what shows.
				if float(left.size() - over.size()) / whole >= SEEN:
					hides = false
					break
				var shows: float = float(left.size()) / whole
				# Less than a tenth in sight stays so whatever is taken out.
				if shows >= SEEN and float(left.size() - _covered(left, over)) / whole >= SEEN:
					hides = false
					break
				before = maxf(before, shows)
			if hides and before >= SEEN:
				return true
		return false


## A part of the model built on the side and put on whole.
class Assembly extends RefCounted:
	var key: String = ""
	var name: String = ""
	## Two copies are the same kind when they have the same name and the
	## same parts in the same colours: what the booklet builds once, "2x".
	var kind: String = ""
	var members: Array[Node2] = []
	var figure: bool = false
	## A flexible thing drawn in pieces, put in as the one part it is, in a
	## step of the main build and not on the side: [method _find_bundles].
	var whole: bool = false
	## The node standing for it in the main build.
	var node: Node2 = null
	## Its parts again, read in the frame they stand square in, for one put
	## on turned: what rests on what in it there, and its order in the hand
	## ([method _frame_turned]). Empty for one square to the world.
	var framed: Array[Node2] = []
	## The flexible things in it, each its pieces' ids: each goes in as one
	## in its steps on the side ([method _find_bundles]).
	var bundles: Array[PackedInt64Array] = []


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
##
## [param authored] follows the steps the model's author gave it, when it
## has any (AuthorSteps): see [method _authored_plan].
static func plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary = {}, regions: Dictionary = {},
		authored: bool = false) -> Array[Step]:
	if authored and AuthorSteps.any(world, skip):
		return _authored_plan(world, library, skip)
	var nodes: Array[Node2] = _survey(world, library, skip)
	if nodes.is_empty():
		return []
	_find_supports(nodes, world, library)
	_find_joints(nodes, world, library)
	_tidy_needs(nodes)
	_find_hangers(nodes)
	var assemblies: Array[Assembly] = _find_assemblies(nodes, world, library)
	_find_bundles(nodes, world, library, assemblies)
	_frame_turned(assemblies, world, library, null)
	var built: Array[Node2] = _contract(nodes, assemblies)
	var named: bool = _assign_regions(built, regions, nodes.size())
	var raw: Array = _sequence(built, named, _per_step(nodes.size()))
	var steps: Array[Step] = _expand(raw, world)
	# Each part on what holds it, by the Tested mark's rules (HeldSteps).
	HeldSteps.mend_into(steps, world, library, skip)
	# A node and its assembly point at each other, and two RefCounted
	# objects that do are never freed.
	for made: Assembly in assemblies:
		made.node = null
	return steps


## How many steps [param steps] has, as a person building it is told:
## {"steps", "side", "builds", "pages"}. A step is what the booklet numbers,
## the timeline's "Step 12 of 87" and the booklet cover's "87 steps"; a
## sub-assembly built on the side, in a box beside the step it goes on in,
## is built in steps of its own inside that one ("Earth, 3 of 6"): "side"
## counts those, "builds" the sub-assemblies, and "pages" every step the
## step player turns to. api/_steps.js counts the steps a shared file
## carries by this same rule, so its page says what the app says (steps206:
## the castle's page said 65 steps of its 399, the orrery's 5 of its 87).
## Two sub-assemblies put on in one of an author's steps are two pages of
## one number ("Step 14 of 14 · minifig 2, put on"), so the steps are the
## numbers, not the pages outside a box.
static func count(steps: Array) -> Dictionary:
	var numbers: Dictionary = {}
	var boxes: Dictionary = {}
	var side: int = 0
	for step: Step in steps:
		if step.in_callout():
			side += 1
			boxes[step.callout] = true
		else:
			numbers[step.number] = true
	return {"steps": numbers.size(), "side": side, "builds": boxes.size(), "pages": steps.size()}


## [method count]'s words: "87 steps, and 12 sub-assemblies built on the
## side in 64 steps of their own"; "399 steps" with none built on the side.
## The same words as api/_steps.js countSaid.
static func count_words(counted: Dictionary) -> String:
	var steps: int = int(counted.get("steps", 0))
	var side: int = int(counted.get("side", 0))
	var builds: int = int(counted.get("builds", 0))
	var said: String = "%s step%s" % [Working.comma(steps), "" if steps == 1 else "s"]
	if side == 0:
		return said
	return "%s, and %s %s built on the side in %s step%s of %s own" % [said, Working.comma(builds),
		"sub-assembly" if builds == 1 else "sub-assemblies", Working.comma(side), "" if side == 1 else "s",
		"its" if builds == 1 else "their"]


## How long each part of the last [method plan_paced] took: [what, ms].
static var laps: Array = []


## [method plan], a slice at a time (FramePace): on a big model the page
## goes on drawing and answering while the steps are worked out, and
## [param job] says what is being done and how far it has got.
##
## Orthanc's 9,429 parts held a browser for seconds on one frame when
## Timeline was pressed, with nothing on screen to say anything was
## happening (2026-10-12). The same work as [method plan], in the same
## order; only where it gives the frame back differs. Returns no steps when
## the job was cancelled.
static func plan_paced(world: BrickWorld, library: PartLibrary, skip: Dictionary,
		regions: Dictionary, job: Working.Job, authored: bool = false) -> Array[Step]:
	laps.clear()
	# The author's steps are read, not worked out, from what holds what.
	if authored and AuthorSteps.any(world, skip):
		return await _authored_plan_paced(world, library, skip, job)
	var clock: Array[int] = [Time.get_ticks_msec()]
	var lap := func(what: String) -> void:
		var now: int = Time.get_ticks_msec()
		laps.append([what, now - clock[0]])
		clock[0] = now
	var nodes: Array[Node2] = []
	await _survey_into(nodes, world, library, skip, job)
	lap.call("survey")
	if nodes.is_empty() or job.cancelled:
		return []
	var count: String = Working.comma(nodes.size())
	job.say("Finding what %s parts rest on…" % count)
	job.count(0, nodes.size())
	await _supports_of(nodes, world, library, job)
	lap.call("supports")
	if job.cancelled:
		return []
	job.say("Finding the joints between %s parts…" % count)
	job.count(0, 0)
	await job.next()
	await _joints_of(nodes, world, library, job)
	if job.due():
		await job.next()
	_tidy_needs(nodes)
	lap.call("joints")
	await job.next()
	if job.cancelled:
		return []
	job.say("Finding what hangs off %s parts…" % count)
	await _hangers_of(nodes, job)
	lap.call("hangers")
	await job.next()
	if job.cancelled:
		return []
	job.say("Finding what is built on the side…")
	var assemblies: Array[Assembly] = []
	await _find_assemblies_into(assemblies, nodes, world, library, job)
	await job.next()
	if job.cancelled:
		return []
	await _find_bundles_into(nodes, world, library, assemblies, job)
	await _frame_turned(assemblies, world, library, job)
	lap.call("assemblies")
	await job.next()
	if job.cancelled:
		return []
	var built: Array[Node2] = []
	await _contract_into(built, nodes, assemblies, job)
	await job.next()
	var named: bool = _assign_regions(built, regions, nodes.size())
	lap.call("contract")
	await job.next()
	if job.cancelled:
		for made: Assembly in assemblies:
			made.node = null
		return []
	job.say("Laying out %s parts in steps…" % count)
	job.count(0, nodes.size())
	var raw: Array = []
	await _sequence_into(raw, built, named, _per_step(nodes.size()), job)
	lap.call("sequence")
	# Typed apart from the literal: as one expression an empty [] is an untyped
	# Array, and a Timeline stopped part way on Orthanc stopped on a script
	# error here instead (command_probe, 2026-10-15).
	var steps: Array[Step] = []
	if not job.cancelled:
		steps = _expand(raw, world)
	lap.call("expand")
	# Each part on what holds it, by the Tested mark's rules (HeldSteps).
	if not job.cancelled:
		await HeldSteps.mend_into(steps, world, library, skip, job)
	lap.call("held")
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
static func _assign_regions(nodes: Array[Node2], given: Dictionary, parts: int) -> bool:
	var names: Dictionary = {}
	for node: Node2 in nodes:
		if node.assembly != null:
			node.region = ""
			if not given.is_empty():
				node.region = _most_common(node.assembly.members.map(
					func(member: Node2) -> String: return str(given.get(member.id, ""))))
			elif node.assembly.members.size() > ASSEMBLY_MOST:
				# A section built on the side is still a section: built when
				# the build comes to it, as it was where it stands, and not as
				# soon as it could go on.
				node.region = _most_common(node.assembly.members.map(
					func(member: Node2) -> String: return member.group))
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
	if parts < TILED_FROM:
		return false
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
		library: PartLibrary, frame: Transform3D = Transform3D.IDENTITY) -> void:
	_joints_of(nodes, world, library, null, frame)


## [method _find_joints], a slice at a time with a [param job]. In one go it
## was Timeline's longest frame on Orthanc's 9,541 parts in a browser drawing
## in software: 151 to 262 ms of the app's own work, against the 250 the
## progress check holds Timeline to, and that check failed one run in three
## (2026-10-22).
static func _joints_of(nodes: Array[Node2], world: BrickWorld, library: PartLibrary,
		job: Working.Job, frame: Transform3D = Transform3D.IDENTITY) -> void:
	var entries: Array = []
	for node: Node2 in nodes:
		if job != null and job.due():
			await job.next()
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		if brick == null:
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		entries.append([node.id, frame * brick.transform, part])
	if entries.is_empty():
		return
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node
	if job != null and job.due():
		await job.next()
	var found: Array = Joints.pairs(entries)
	if job != null and job.due():
		await job.next()
	var sockets_of: Dictionary = {}   ## plug id -> the parts it goes into
	for pair: Array in found:
		var plug: Node2 = by_id.get(pair[0])
		var socket: Node2 = by_id.get(pair[1])
		if plug == null or socket == null:
			continue
		if not plug.joined.has(socket.id):
			plug.joined.append(socket.id)
		if not socket.joined.has(plug.id):
			socket.joined.append(plug.id)
		# Except a wheel, which is pushed on to its pin: the car's wheels
		# were step 1, four of them standing on the table, because the
		# hole is in the wheel.
		if socket.wheel > 0:
			if not socket.needs.has(plug.id):
				socket.needs.append(plug.id)
		else:
			if not sockets_of.has(plug.id):
				sockets_of[plug.id] = []
			if not (sockets_of[plug.id] as Array).has(socket):
				(sockets_of[plug.id] as Array).append(socket)
	# A pin that joins two parts goes into one and the other goes on it,
	# as a Technic booklet has it: into the one the build reaches first, and
	# the others after. Waiting for every part it goes into put it in last,
	# between two beams already there, where no picture can show it: 1,296
	# Technic parts the booklet's view could not see in 100 real sets,
	# against 431 in their authors' steps (docs/INSTRUCTIONS.md).
	if job != null and job.due():
		await job.next()
	var reach: Dictionary = _reach(nodes, by_id, sockets_of)
	if job != null and job.due():
		await job.next()
	var lowest := func(a: Node2, b: Node2) -> bool:
		if absf(a.box.position.y - b.box.position.y) > 0.5:
			return a.box.position.y < b.box.position.y
		return a.id < b.id
	var nearest := func(a: Node2, b: Node2) -> bool:
		var one: int = int(reach.get(a.id, 0x7FFFFFFF))
		var two: int = int(reach.get(b.id, 0x7FFFFFFF))
		if one != two:
			return one < two
		return lowest.call(a, b)
	# A joint found both ways round, an axle pin's axle gripped by the arm
	# its pin turns in, is one joint: the one the build reaches first holds
	# the other. Read as two, each part needed the other, and 8022's
	# steering arms were forced in on nothing.
	for plug_id: int in sockets_of.keys():
		var plug: Node2 = by_id[plug_id]
		var into: Array = sockets_of[plug_id]
		for socket: Node2 in into.duplicate():
			var back: Array = sockets_of.get(socket.id, [])
			if back.has(plug) and nearest.call(plug, socket):
				into.erase(socket)
		if into.is_empty():
			sockets_of.erase(plug_id)
	var base: Dictionary = {}       ## id -> its needs before the joints
	for node: Node2 in nodes:
		base[node.id] = node.needs.duplicate()
	if job != null and job.due():
		await job.next()
	var chosen: Dictionary = {}     ## plug id -> what it goes into first
	var low: Dictionary = {}        ## ...and the lowest of them
	for plug_id: int in sockets_of:
		var into: Array = (sockets_of[plug_id] as Array).duplicate()
		into.sort_custom(lowest)
		low[plug_id] = into[0]
		into.sort_custom(nearest)
		chosen[plug_id] = into[0]
	# Unless that closes a loop, where what it would go into rests on another
	# of the parts it joins: then the lowest, as before.
	for _attempt: int in 3:
		_pin(nodes, by_id, base, sockets_of, chosen)
		if job != null and job.due():
			await job.next()
		var differ: Array = chosen.keys().filter(func(id: int) -> bool:
			return chosen[id] != low[id])
		if differ.is_empty():
			break
		for node: Node2 in nodes:
			node.after = node.needs
		var looped: Dictionary = _cycles(nodes)
		var undone: bool = false
		for plug_id: int in differ:
			if looped.has(plug_id):
				chosen[plug_id] = low[plug_id]
				undone = true
		if not undone:
			break
		_pin(nodes, by_id, base, sockets_of, chosen)
	_wheels(nodes)


## Each plug into the part [param chosen] names, and the other parts it
## joins on it, on top of the needs in [param base].
static func _pin(nodes: Array[Node2], by_id: Dictionary, base: Dictionary,
		sockets_of: Dictionary, chosen: Dictionary) -> void:
	for node: Node2 in nodes:
		node.needs = (base[node.id] as PackedInt64Array).duplicate()
	for plug_id: int in sockets_of:
		var plug: Node2 = by_id[plug_id]
		var first: Node2 = chosen[plug_id]
		if not plug.needs.has(first.id):
			plug.needs.append(first.id)
		for other: Node2 in sockets_of[plug_id]:
			if other != first and not other.needs.has(plug.id) and not plug.needs.has(other.id):
				other.needs.append(plug.id)


## How far each part is from the table, through what holds it: the parts
## on the table 0, and a part one more than the nearest that holds it: a
## stud it sits on, a side stud, a pin or an axle either way, and failing
## those what its box sits on. Unreached parts are not in it.
##
## Which part a pin goes into first was the lowest of them, and a Technic
## model is not built from the bottom up: a beam under the frame, held by
## pins that go up into it, was the lowest of every pin it holds, so they
## all went into it, and it went in first, on nothing. In the 7 Technic
## files of the held-out sample a step left a thing floating in 31.5% of
## steps, against 13.2% in the rest. Into what holds it already, the pin
## holds it up.
static func _reach(nodes: Array[Node2], by_id: Dictionary, sockets_of: Dictionary) -> Dictionary:
	var next: Dictionary = {}    ## id -> ids it holds or is held by
	var link := func(one: int, other: int) -> void:
		if not next.has(one):
			next[one] = []
		(next[one] as Array).append(other)
	for node: Node2 in nodes:
		for top: int in node.carries:
			link.call(node.id, top)
		for other: int in node.held_by:
			link.call(node.id, other)
		for under: int in node.boxed:
			link.call(under, node.id)
	for plug_id: int in sockets_of:
		for socket: Node2 in sockets_of[plug_id]:
			link.call(plug_id, socket.id)
			link.call(socket.id, plug_id)
	# The table, or the lowest of a car that stands on its wheels: they go
	# on last. Not a pin or an axle, which goes into something: a truck's
	# axles are lower than its frame, and the frame went on them.
	var floor_y: float = INF
	for node: Node2 in nodes:
		if node.wheel == 0 and not sockets_of.has(node.id):
			floor_y = minf(floor_y, node.box.position.y)
	var reach: Dictionary = {}
	var wave: Array[int] = []
	for node: Node2 in nodes:
		if node.box.position.y <= floor_y + 2.0 and node.wheel == 0 \
				and not sockets_of.has(node.id):
			reach[node.id] = 0
			wave.append(node.id)
	var depth: int = 0
	while not wave.is_empty():
		depth += 1
		var after: Array[int] = []
		for id: int in wave:
			for other: int in next.get(id, []):
				if not reach.has(other) and by_id.has(other):
					reach[other] = depth
					after.append(other)
		wave = after
	return reach


## A wheel goes on what holds it, and a tyre on its wheel.
##
## Whether or not the joint between them was found: the example car's
## wheel pins are not a joint the library knows, so its wheels needed
## nothing, stood on the table, and were the first thing built — the
## first step of the first booklet a visitor makes.
static func _wheels(nodes: Array[Node2]) -> void:
	for wheel: Node2 in nodes:
		if wheel.wheel == 0:
			continue
		var box: AABB = wheel.box.grow(1.0)
		for other: Node2 in nodes:
			if other.id == wheel.id or not box.intersects(other.box) \
					or other.needs.has(wheel.id) or wheel.needs.has(other.id):
				continue
			# A rim needs what it is on; a tyre needs its rim.
			if (wheel.wheel == 1 and other.wheel == 0) \
					or (wheel.wheel == 2 and other.wheel == 1):
				wheel.needs.append(other.id)


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
	_hangers_of(nodes, null)


## [method _find_hangers], a slice at a time with a [param job].
static func _hangers_of(nodes: Array[Node2], job: Working.Job) -> void:
	if nodes.is_empty():
		return
	const CELL := 40.0
	# And by height, as _supports_of keeps them: a part only touches what
	# overlaps it up the tower too, and Orthanc's columns are hundreds of
	# parts tall.
	const LAYER := 40.0
	var floor_y: float = INF
	for node: Node2 in nodes:
		floor_y = minf(floor_y, node.box.position.y)
	var hanging: Dictionary = {}
	for index: int in nodes.size():
		var node: Node2 = nodes[index]
		if node.needs.is_empty() and node.box.position.y > floor_y + 2.0 \
				and node.wheel == 0:
			hanging[index] = true
	if hanging.is_empty():
		return
	var grid: Dictionary = {}
	for index: int in nodes.size():
		var grown: AABB = nodes[index].box.grow(1.0)
		for layer: int in range(floori(grown.position.y / LAYER), floori(grown.end.y / LAYER) + 1):
			for cell: Vector2i in _cells(grown, CELL):
				var key := Vector3i(cell.x, cell.y, layer)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(index)
	# Outward from what is held, a wave at a time: a part hangs from what
	# it touches that is already held, and is then held itself. A tower's
	# pinnacles are 1 x 1 plates clipped to round tiles clipped to a wall:
	# only the first touches the wall, and linking parts to held parts only
	# left the rest free — Orthanc put them at step 36, a hundred and fifty
	# studs up in the air.
	var held: Dictionary = {}
	var index_of: Dictionary = {}
	for index: int in nodes.size():
		index_of[nodes[index].id] = index
		if not hanging.has(index):
			held[index] = true
	var waiting: Dictionary = hanging.duplicate()
	# By what holds it, where something does: a tile on a side stud hangs from
	# the brick the stud is in, not from every part its box touches. By touch
	# only once nothing that holds it is held, wave on wave.
	var by_touch: bool = false
	for _wave: int in 64:
		var now_held: Array[int] = []
		for index: int in waiting:
			if job != null and job.due():
				await job.next()
				if job.cancelled:
					return
			var node: Node2 = nodes[index]
			for other_id: int in node.held_by:
				var at: int = index_of.get(other_id, -1)
				if at >= 0 and held.has(at) and not nodes[at].needs.has(node.id) \
						and not node.needs.has(other_id):
					node.needs.append(other_id)
			if not node.needs.is_empty():
				now_held.append(index)
				continue
			if not node.held_by.is_empty() and not by_touch:
				continue
			# By what its cover touches, where that is held: its box touched
			# parts it does not, and hung from those it floated.
			for other_id: int in node.contacts:
				var at: int = index_of.get(other_id, -1)
				if at >= 0 and held.has(at) and not nodes[at].needs.has(node.id) \
						and not node.needs.has(other_id):
					node.needs.append(other_id)
					node.weak.append(other_id)
			if not node.needs.is_empty():
				now_held.append(index)
				continue
			var box: AABB = node.box.grow(1.0)
			var lowest: int = floori(box.position.y / LAYER)
			var highest: int = floori(box.end.y / LAYER)
			var seen: Dictionary = {}
			for cell: Vector2i in _cells(box, CELL):
				# A square's parts in the order they are listed, as when
				# they were kept by the square alone.
				var near: Array = []
				for layer: int in range(lowest, highest + 1):
					near.append_array(grid.get(Vector3i(cell.x, cell.y, layer), []))
				if highest > lowest:
					near.sort()
				for other_index: int in near:
					if other_index == index or seen.has(other_index) \
							or not held.has(other_index):
						continue
					seen[other_index] = true
					if box.intersects(nodes[other_index].box) \
							and not nodes[other_index].needs.has(node.id):
						node.needs.append(nodes[other_index].id)
						node.weak.append(nodes[other_index].id)
			if not node.needs.is_empty():
				now_held.append(index)
		if now_held.is_empty():
			if by_touch:
				break
			by_touch = true
			continue
		by_touch = false
		for index: int in now_held:
			held[index] = true
			waiting.erase(index)
	# And a part that touches nothing at all — a design's floating detail,
	# a pinnacle a hair off its tower — goes in when the model has reached
	# it: after the nearest held part whose top is at its height or below.
	# Orthanc had 188 of these, and every one was free to go in at step 1.
	for index: int in waiting:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		var node: Node2 = nodes[index]
		var nearest: float = INF
		var under: int = -1
		for other_index: int in held:
			var other: Node2 = nodes[other_index]
			if other.box.end.y > node.box.position.y + 5.0 \
					or other.box.end.y < node.box.position.y - 48.0:
				continue
			var gap: float = other.box.get_center().distance_to(node.box.get_center())
			if gap < nearest:
				nearest = gap
				under = other_index
		if under >= 0:
			node.needs.append(nodes[under].id)
			node.weak.append(nodes[under].id)
	for node: Node2 in nodes:
		node.after = node.needs.duplicate()
	# Only a part on a loop gives up what it hangs from, not every part
	# downstream of one: clearing those too left a pinnacle that merely
	# hung below a loop free to go in first.
	var cleared: Array[int] = []
	for _attempt: int in 4:
		if job != null:
			await job.next()
			if job.cancelled:
				return
		var looped: Dictionary = {}
		await _cycles_into(looped, nodes, job)
		var undone: bool = false
		for index: int in hanging:
			var node: Node2 = nodes[index]
			if looped.has(node.id) and not node.needs.is_empty():
				node.needs = PackedInt64Array()
				node.after = PackedInt64Array()
				cleared.append(index)
				undone = true
		if not undone:
			break
	# A part that gave up what it hangs from still waits for the model to
	# reach its height: for the nearest part below it that does not, by
	# any route, wait for it. One at a time, so two of them cannot make a
	# loop between them.
	var dependents: Dictionary = {}
	if not cleared.is_empty():
		for other: Node2 in nodes:
			for need: int in other.after:
				if not dependents.has(need):
					dependents[need] = []
				(dependents[need] as Array).append(other.id)
	for index: int in cleared:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		var node: Node2 = nodes[index]
		var after_it: Dictionary = _waiting_on(dependents, node.id)
		var nearest: float = INF
		var under: int = -1
		for other_index: int in nodes.size():
			var other: Node2 = nodes[other_index]
			if other_index == index or after_it.has(other.id) \
					or other.box.end.y > node.box.position.y + 5.0 \
					or other.box.end.y < node.box.position.y - 48.0:
				continue
			var gap: float = other.box.get_center().distance_to(node.box.get_center())
			if gap < nearest:
				nearest = gap
				under = other_index
		if under >= 0:
			node.needs.append(nodes[under].id)
			node.weak.append(nodes[under].id)
			node.after = node.needs.duplicate()
			if not dependents.has(nodes[under].id):
				dependents[nodes[under].id] = []
			(dependents[nodes[under].id] as Array).append(node.id)
	_hung_under(nodes)


## A part that hangs from one resting on it goes in in that one's step, as a
## plate pressed up under a sign does ([method _pressed_up]): put in after
## it, it is put in under it, and before it, it floats. What rests on what
## is the parts' covers' ([member Node2.over]); not a pin or an axle, which
## goes in along its line. On the model only: a sub-assembly in the hand is
## any way up, and there it only hid the part under the one it hangs from.
##
## With [constant WHEELS_WITH_HOLDER], a wheel goes on with the holder its
## pin is in (in the step after, when that is the model's first: the example
## car began with its wheels standing on the table), and a tyre with its
## wheel. It is off: the sets' authors put their wheels on last, 81% of the
## way through on tune, and with the wheels on early a truck's order agreed
## with its author's at 0.39 where it had at 0.87. The build check asked for
## them early only because it held a half-built model by the floor under the
## finished one; it holds it by the table now (src/dev/steps_score.gd).
static func _hung_under(nodes: Array[Node2]) -> void:
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		by_id[node.id] = node
	for node: Node2 in nodes:
		for need: int in node.needs:
			var other: Node2 = by_id.get(need)
			if other == null or node.joined.has(need) or node.under.has(need) \
					or node.hung.has(need):
				continue
			# A wheel on the holder its pin is in, and a tyre on its wheel,
			# whichever way their covers meet.
			if node.wheel > 0:
				if WHEELS_WITH_HOLDER and (other.wheel == 0 or node.wheel == 2 and other.wheel == 1):
					node.hung.append(need)
				continue
			# Hanging: held from the side or by what it touches, and the other
			# rests on it. Not a part on the other's studs: two parts a stud
			# joins reach into each other, so each cover meets the other's
			# lifted, and read that way every part of a stack hung from the one
			# on top of it: 30300's first step took fourteen parts.
			if (node.weak.has(need) or node.held_by.has(need)) and node.over.has(need):
				node.hung.append(need)


## Every node that waits, by any route, for [param id], given who waits
## on whom directly.
static func _waiting_on(dependents: Dictionary, id: int) -> Dictionary:
	var found: Dictionary = {}
	var pending: Array = [id]
	while not pending.is_empty():
		var at: int = pending.pop_back()
		for dependent: int in dependents.get(at, []):
			if not found.has(dependent):
				found[dependent] = true
				pending.append(dependent)
	return found


## The nodes on a loop of needs — a part that, through what it rests on
## and hangs from, waits for itself. Not the ones merely waiting on such a
## loop (see [method _in_loops]). Strongly connected components, found
## with two passes of a depth-first walk kept on a stack of its own, since
## a tower of eight thousand bricks is deeper than GDScript's call stack.
static func _cycles(nodes: Array[Node2]) -> Dictionary:
	var looped: Dictionary = {}
	_cycles_into(looped, nodes, null)
	return looped


## [method _cycles] into [param looped]; a slice at a time with a
## [param job], asked every few hundred steps of the walk.
static func _cycles_into(looped: Dictionary, nodes: Array[Node2], job: Working.Job) -> void:
	const ASK_EVERY := 256
	var steps: int = 0
	var index_of: Dictionary = {}
	for index: int in nodes.size():
		index_of[nodes[index].id] = index
	# Plain arrays: a packed array taken out of an array is a copy, and
	# appending to it appended to nothing — the first version of this found
	# no loops at all.
	var forward: Array = []
	var backward: Array = []
	for index: int in nodes.size():
		forward.append([])
		backward.append([])
	for index: int in nodes.size():
		if job != null and job.due():
			await job.next()
		for need: int in nodes[index].after:
			if index_of.has(need):
				var target: int = index_of[need]
				(forward[index] as Array).append(target)
				(backward[target] as Array).append(index)
	var finished: PackedInt32Array = PackedInt32Array()
	var visited := PackedByteArray()
	visited.resize(nodes.size())
	for start: int in nodes.size():
		if visited[start] == 1:
			continue
		var stack: Array = [[start, 0]]
		visited[start] = 1
		while not stack.is_empty():
			steps += 1
			if job != null and steps % ASK_EVERY == 0 and job.due():
				await job.next()
			var top: Array = stack[-1]
			var edges: Array = forward[top[0]]
			if int(top[1]) < edges.size():
				var next: int = edges[top[1]]
				top[1] = int(top[1]) + 1
				if visited[next] == 0:
					visited[next] = 1
					stack.append([next, 0])
			else:
				finished.append(top[0])
				stack.pop_back()
	var component := PackedInt32Array()
	component.resize(nodes.size())
	component.fill(-1)
	var sizes: Array[int] = []
	for at: int in range(finished.size() - 1, -1, -1):
		var root: int = finished[at]
		if component[root] >= 0:
			continue
		var label: int = sizes.size()
		sizes.append(0)
		var pending: Array[int] = [root]
		component[root] = label
		while not pending.is_empty():
			steps += 1
			if job != null and steps % ASK_EVERY == 0 and job.due():
				await job.next()
			var here: int = pending.pop_back()
			sizes[label] += 1
			for previous: int in backward[here]:
				if component[previous] < 0:
					component[previous] = label
					pending.append(previous)
	for index: int in nodes.size():
		if sizes[component[index]] > 1 or (forward[index] as Array).has(index):
			looped[nodes[index].id] = true


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
	_survey_into(nodes, world, library, skip, null)
	return nodes


## Each brick as a node, into [param nodes]; a slice at a time with a
## [param job], which then counts them.
static func _survey_into(nodes: Array[Node2], world: BrickWorld, library: PartLibrary,
		skip: Dictionary, job: Working.Job) -> void:
	var bricks: Array = world.bricks()
	if job != null:
		job.say("Measuring %s parts…" % Working.comma(bricks.size()))
		job.count(0, bricks.size())
	for at: int in bricks.size():
		var brick: BrickWorld.Brick = bricks[at]
		if job != null and job.due():
			job.count(at)
			await job.next()
			if job.cancelled:
				return
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
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		# Past the marks LDraw puts before a name (an alias's "=", "~", "_"):
		# 51719, "=Wheel Rim 6.4 x 11", was no wheel to the planner, and went
		# on at step 1 with the plate its pin is in, its tyre with it.
		var name: String = info.name.strip_edges().lstrip("=~_|") if info != null else ""
		if name.begins_with("Wheel"):
			node.wheel = 1
		elif name.begins_with("Tyre") or name.begins_with("Tire"):
			node.wheel = 2
		nodes.append(node)


## Who rests on whom, and what holds what.
##
## By the studs, as the build check reads them (Joints.studs_in): a stud
## reaching up into a part is under it, so the part needs the stud's
## owner; one reaching down is on a part turned over on top of it, which
## needs what it is on. Its direction settles which of the two rests on the
## other, where their covers, read as touching, said each rested on each.
## Read against the parts' own covers (Covers), since the booklet's callers
## hold no lattice.
##
## Boxes were what this read before, and a slope's box, an L-shaped
## plate's, a bracket's are not the part: in 100 real sets a part was put
## in under one already there for 19.4% of things, and the planner's boxes
## had missed what it rested on for three in four of them; and a step left
## one floating in 19.1% of steps, most of them resting on parts whose
## boxes touched and whose shapes did not (docs/INSTRUCTIONS.md).
##
## A stud from the side holds a part without its resting on anything:
## [member Node2.held_by], which [method _find_hangers] hangs it from before
## what its box touches. A part no stud seats (a figure's, a Technic beam's,
## a tile on a side stud) rests on what its box sits on, as before
## ([method _boxes_under]). Clips, hinges and balls (Joints.rounds, balls)
## were read too and changed nothing measured but the planning time, which
## they took from 2.5 s to 4.1 s on fifteen files.
static func _find_supports(nodes: Array[Node2], world: BrickWorld,
		library: PartLibrary) -> void:
	_supports_of(nodes, world, library, null)


## How far up a stud must point to say which part is on which: 45 degrees.
const UPRIGHT := 0.7
## Parts whose studs are read between two looks at the clock, paced.
const SLICE := 100
## A part no stud seats whose cover rests on something rests on what its
## cover rests on, one way round, in place of what its box sat on (true), or
## on neither, as the planner has always had it (false). Tried on 2026-10-17
## and not kept: on the held-out sample, steps with a hidden new thing 11.4%
## to 10.4%, but the build check's floating parts 5.9% to 7.5% and tau 0.287
## to 0.279; read both ways round as well, steps with a floating thing 7.7%
## to 10.0% (docs/INSTRUCTIONS.md, lostappend).
const COVER_RESTS := false


## [method _find_supports], a slice at a time with a [param job].
static func _supports_of(nodes: Array[Node2], world: BrickWorld, library: PartLibrary,
		job: Working.Job, frame: Transform3D = Transform3D.IDENTITY) -> void:
	var by_id: Dictionary = {}
	var entries: Array = []
	var covers := Covers.new()
	for node: Node2 in nodes:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		by_id[node.id] = node
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		var part: Lbm.PartMesh = library.mesh_for(node.part_id)
		if brick == null or part == null:
			continue
		entries.append([node.id, frame * brick.transform, part])
		covers.add(node.id, frame * brick.transform, part)
	for start: int in range(0, entries.size(), SLICE):
		if job != null and job.due():
			job.count(start)
			await job.next()
			if job.cancelled:
				return
		for stud: Array in Joints.studs_in(entries.slice(start, start + SLICE), covers.at):
			var owner: Node2 = by_id[stud[0]]
			var into: Node2 = by_id[stud[1]]
			owner.studded = true
			into.studded = true
			var way: float = (stud[3] as Vector3).y
			if way > UPRIGHT:
				_seat(into, owner)
			elif way < -UPRIGHT:
				_seat(owner, into)
			else:
				_hold(owner, into)
	await _boxes_under(nodes, job)
	await _contacts_of(nodes, world, library, job, frame)
	# Where the cover of a part no stud seats rests on anything, what its
	# box sat on is not what it rests on: a slope's or a bracket's box, which
	# the part itself does not touch. So that goes, and with COVER_RESTS
	# what the cover rests on takes its place. Until 2026-10-17 what the
	# cover rests on was appended through a cast to a packed array in a
	# Dictionary, a copy, so it was always empty and only the going
	# happened; the planner was tuned that way, and is kept so.
	var under_it: Dictionary = {}     ## id -> Array of what its cover rests on
	for node: Node2 in nodes:
		for top: int in node.over:
			# Covers that meet both ways (a figure's arm in its torso, a hand
			# in its arm, a leg in its hips) say neither rests on the other.
			# Read as resting each on each, they waited each on the other, and
			# the order forced three times the steps it had.
			if COVER_RESTS and (by_id[top] as Node2).over.has(node.id):
				continue
			if not under_it.has(top):
				under_it[top] = []
			(under_it[top] as Array).append(node.id)
	for node: Node2 in nodes:
		if not node.seated and not node.boxed.is_empty() and under_it.has(node.id):
			var resting := PackedInt64Array(under_it[node.id]) if COVER_RESTS \
				else PackedInt64Array()
			if not Array(node.boxed).any(func(id: int) -> bool: return resting.has(id)):
				node.boxed = resting
		for need: int in node.boxed:
			if not node.needs.has(need):
				node.needs.append(need)
		# And a part on a side stud waits for what holds it, not only for
		# what its box sits on: Vernie's tiles went on before the bricks whose
		# side studs hold them, on nothing.
		if node.seated or node.boxed.is_empty():
			continue
		for other_id: int in node.held_by:
			var other: Node2 = by_id[other_id]
			if other.seated and not node.needs.has(other_id) and not other.needs.has(node.id):
				node.needs.append(other_id)
	_pressed_up(nodes, by_id)


## What rests on what by the parts' covers, as the build check weighs a
## model (Stability.contacts): a part's cover lifted a cell meets
## another's. Into [member Node2.contacts], both ways round. Not what the
## order waits on, which is read off the studs and the joints: what a part
## touches, so that it goes in once something it touches is built
## ([method _touching]). A square part's cover is the lattice's
## (BrickLattice.boxes_for); a turned part's is each of its boxes' bounds,
## a little generous.
static func _contacts_of(nodes: Array[Node2], world: BrickWorld, library: PartLibrary,
		job: Working.Job, frame: Transform3D = Transform3D.IDENTITY) -> void:
	const BUCKET := 40.0
	# By the plan and the height of each part's top, as _boxes_under keeps
	# them: what rests on a part has its underside near that part's top.
	const LAYER := 8.0
	# Every part, and apart those no stud seats: a part on studs is asked only
	# about those, since two parts on studs are read by their studs. Asked
	# about every part near it, most of them on studs too, it was most of
	# what reading the covers cost.
	var grid: Dictionary = {}
	var loose: Dictionary = {}
	for index: int in nodes.size():
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		var node: Node2 = nodes[index]
		var layer: int = floori(node.box.end.y / LAYER)
		for cell: Vector2i in _cells(node.box, BUCKET):
			var key := Vector3i(cell.x, cell.y, layer)
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(index)
			if not node.seated:
				if not loose.has(key):
					loose[key] = []
				(loose[key] as Array).append(index)
	# Each part's cover, as a shape ([method _shape]) and the cell it is
	# counted from: worked out only for a part that is asked about. A square
	# part's is its part's in that turn, from the cell its origin is in, as
	# BrickLattice.boxes_for counts it, and kept for every part of that part
	# in that turn: worked out for each of them, with its cover lifted a cell
	# and both their bounds, it was a third of what reading the covers cost.
	var covers: Dictionary = {}
	var shapes: Dictionary = {}        ## part id -> {Basis -> shape}
	var cover_of := func(index: int) -> Array:
		var known: Variant = covers.get(index)
		if known != null:
			return known
		var node: Node2 = nodes[index]
		var mine := PackedInt32Array()
		var from := Vector3i.ZERO
		var shape: Array = []
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		var part: Lbm.PartMesh = library.mesh_for(node.part_id)
		if brick != null and part != null:
			var at: Transform3D = frame * brick.transform
			if part.boxes.is_empty():
				mine = _cells_round(at * part.bounds)
			elif BrickLattice.is_square_to_grid(at.basis):
				from = BrickLattice.to_cell(at.origin)
				if not shapes.has(node.part_id):
					shapes[node.part_id] = {}
				var turns: Dictionary = shapes[node.part_id]
				if not turns.has(at.basis):
					turns[at.basis] = _shape(BrickLattice.boxes_for(part.boxes, Vector3i.ZERO,
						at.basis))
				shape = turns[at.basis]
			else:
				for box: AABB in part.boxes:
					mine.append_array(_cells_round(at * AABB(box.position * part.cell_ldu,
						box.size * part.cell_ldu)))
		# One part's own cover is read a few times, and is not put in order:
		# sorting each turned part's thousands of boxes cost more than all its
		# meetings, and 10315 planned in 9 s where it plans in 1.1 without.
		if shape.is_empty():
			shape = [mine, _bounds_of(mine)]
		var out: Array = [shape, from]
		covers[index] = out
		return out
	# Each part against those whose top is near its underside, or above it
	# and still under its top: what it may rest on.
	var seen := PackedInt32Array()
	seen.resize(nodes.size())
	seen.fill(-1)
	for index: int in nodes.size():
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		var node: Node2 = nodes[index]
		var lowest: int = floori((node.box.position.y - 2.5) / LAYER)
		var highest: int = floori((node.box.end.y + 2.5) / LAYER)
		var near: Dictionary = loose if node.seated else grid
		var top: float = node.box.end.y
		var under: float = node.box.position.y - 2.5
		# _overlaps_flat, written out: a call a pair asked was a good part of
		# the loop.
		var left: float = node.box.position.x
		var right: float = node.box.end.x
		var back: float = node.box.position.z
		var front: float = node.box.end.z
		for cell: Vector2i in _cells(node.box, BUCKET):
			for layer: int in range(lowest, highest + 1):
				var there: Variant = near.get(Vector3i(cell.x, cell.y, layer))
				if there == null:
					continue
				for other: int in there:
					# Each part once, marked with the index of the one asking.
					if other == index or seen[other] == index:
						continue
					seen[other] = index
					var them: Node2 = nodes[other]
					# Two parts on studs are read by their studs; what their
					# covers say is for a part no stud seats. Asked of every
					# pair, it tripled what reading supports cost.
					if node.seated and them.seated:
						continue
					# Each pair once, from the one whose top is higher; and
					# under it, the other's top within a cell of its
					# underside, or above it. The comparisons before the call.
					var box: AABB = them.box
					var their_top: float = box.end.y
					if their_top > top or their_top == top and other < index or their_top < under:
						continue
					# Their plans overlap, a shared edge not (_overlaps_flat).
					if not (left < box.end.x - 0.5 and box.position.x < right - 0.5
							and back < box.end.z - 0.5 and box.position.z < front - 0.5):
						continue
					# Kept, and worked out only the first time (cover_of).
					var mine: Variant = covers.get(index)
					if mine == null:
						mine = cover_of.call(index)
					var theirs: Variant = covers.get(other)
					if theirs == null:
						theirs = cover_of.call(other)
					if ((mine[0] as Array)[0] as PackedInt32Array).is_empty() \
							or ((theirs[0] as Array)[0] as PackedInt32Array).is_empty():
						continue
					# Each lifted a cell onto the other.
					var on_mine: bool = _meet(mine[0], (mine[1] as Vector3i) + Vector3i(0, 1, 0),
						theirs[0], theirs[1])
					var on_theirs: bool = _meet(theirs[0],
						(theirs[1] as Vector3i) + Vector3i(0, 1, 0), mine[0], mine[1])
					if on_mine:
						node.over.append(them.id)
					if on_theirs:
						them.over.append(node.id)
					if on_mine or on_theirs:
						node.contacts.append(them.id)
						them.contacts.append(node.id)


## The box round packed boxes (six ints each), as six ints.
static func _bounds_of(boxes: PackedInt32Array) -> PackedInt32Array:
	if boxes.is_empty():
		return PackedInt32Array([0, 0, 0, 0, 0, 0])
	var out := PackedInt32Array([boxes[0], boxes[1], boxes[2], boxes[3], boxes[4], boxes[5]])
	var n: int = 6
	while n < boxes.size():
		for k: int in 3:
			out[k] = mini(out[k], boxes[n + k])
			out[k + 3] = maxi(out[k + 3], boxes[n + k + 3])
		n += 6
	return out


## A cover of more boxes than this is kept in order of its boxes' heights
## too ([method _shape]).
const BANDED_FROM := 12


## Packed boxes (six ints each) as [method _meet] reads them: [boxes, their
## bounds, and for a cover of many boxes where each box begins in order of
## its low y, those low ys, where each begins in order of its high y, and
## those]. Two bricks one on the other meet in a layer a cell deep, and a
## stud's round cover is a hundred boxes, most of them nowhere near it: of a
## cover kept in order, only those that reach that layer are looked at.
static func _shape(boxes: PackedInt32Array) -> Array:
	var count: int = boxes.size() / 6
	if count <= BANDED_FROM:
		return [boxes, _bounds_of(boxes)]
	# Sorted natively, each box by its height and then where it is.
	const SHIFT := 24
	const OFFSET := 1 << 20
	var by_low := PackedInt64Array()
	var by_high := PackedInt64Array()
	by_low.resize(count)
	by_high.resize(count)
	for k: int in count:
		by_low[k] = ((boxes[k * 6 + 1] + OFFSET) << SHIFT) | k
		by_high[k] = ((boxes[k * 6 + 4] + OFFSET) << SHIFT) | k
	by_low.sort()
	by_high.sort()
	var low_starts := PackedInt32Array()
	var lows := PackedInt32Array()
	var high_starts := PackedInt32Array()
	var highs := PackedInt32Array()
	low_starts.resize(count)
	lows.resize(count)
	high_starts.resize(count)
	highs.resize(count)
	const MASK := (1 << SHIFT) - 1
	for k: int in count:
		low_starts[k] = (by_low[k] & MASK) * 6
		lows[k] = (by_low[k] >> SHIFT) - OFFSET
		high_starts[k] = (by_high[k] & MASK) * 6
		highs[k] = (by_high[k] >> SHIFT) - OFFSET
	return [boxes, _bounds_of(boxes), low_starts, lows, high_starts, highs]


## Where in [param shape]'s boxes those that may reach into cells
## [param low_y] up to [param high_y] begin: [starts, from, to], every box
## for a short cover (starts empty), else those whose low y is under
## [param high_y] or those whose high y is over [param low_y], whichever
## are fewer, found by halving natively.
static func _band(shape: Array, low_y: int, high_y: int) -> Array:
	if shape.size() == 2:
		return [PackedInt32Array(), 0, (shape[0] as PackedInt32Array).size() / 6]
	var lows: PackedInt32Array = shape[3]
	var highs: PackedInt32Array = shape[5]
	var under: int = lows.bsearch(high_y, true)
	var over_from: int = highs.bsearch(low_y, false)
	if under <= highs.size() - over_from:
		return [shape[2], 0, under]
	return [shape[4], over_from, highs.size()]


## Whether covers [param a] and [param b] ([method _shape]), counted from
## cells [param a_from] and [param b_from], share a cell, looking only at
## the boxes of each inside where their bounds meet. Read where they are
## counted from, a square part's boxes are worked out once for every part
## of its kind in its turn.
static func _meet(a: Array, a_from: Vector3i, b: Array, b_from: Vector3i) -> bool:
	var a_bounds: PackedInt32Array = a[1]
	var b_bounds: PackedInt32Array = b[1]
	var low := Vector3i(maxi(a_bounds[0] + a_from.x, b_bounds[0] + b_from.x),
		maxi(a_bounds[1] + a_from.y, b_bounds[1] + b_from.y),
		maxi(a_bounds[2] + a_from.z, b_bounds[2] + b_from.z))
	var high := Vector3i(mini(a_bounds[3] + a_from.x, b_bounds[3] + b_from.x),
		mini(a_bounds[4] + a_from.y, b_bounds[4] + b_from.y),
		mini(a_bounds[5] + a_from.z, b_bounds[5] + b_from.z))
	if high.x <= low.x or high.y <= low.y or high.z <= low.z:
		return false
	# Each part's boxes against where they meet, counted from its own cell.
	var bb: PackedInt32Array = b[0]
	var lo: Vector3i = low - b_from
	var hi: Vector3i = high - b_from
	var near_b: Array[int] = []
	var band: Array = _band(b, lo.y, hi.y)
	var starts: PackedInt32Array = band[0]
	for k: int in range(band[1], band[2]):
		var j: int = starts[k] if not starts.is_empty() else k * 6
		if bb[j] < hi.x and bb[j + 3] > lo.x and bb[j + 1] < hi.y and bb[j + 4] > lo.y \
				and bb[j + 2] < hi.z and bb[j + 5] > lo.z:
			near_b.append(j)
	if near_b.is_empty():
		return false
	var ab: PackedInt32Array = a[0]
	lo = low - a_from
	hi = high - a_from
	# b's boxes counted from a's cell.
	var s: Vector3i = b_from - a_from
	band = _band(a, lo.y, hi.y)
	starts = band[0]
	for k: int in range(band[1], band[2]):
		var i: int = starts[k] if not starts.is_empty() else k * 6
		if ab[i] < hi.x and ab[i + 3] > lo.x and ab[i + 1] < hi.y and ab[i + 4] > lo.y \
				and ab[i + 2] < hi.z and ab[i + 5] > lo.z:
			for at: int in near_b:
				if mini(ab[i + 3], bb[at + 3] + s.x) > maxi(ab[i], bb[at] + s.x) \
						and mini(ab[i + 4], bb[at + 4] + s.y) > maxi(ab[i + 1], bb[at + 1] + s.y) \
						and mini(ab[i + 5], bb[at + 5] + s.z) > maxi(ab[i + 2], bb[at + 2] + s.z):
					return true
	return false


## The lattice's cells [param box] (in LDU) reaches into, as one box.
static func _cells_round(box: AABB) -> PackedInt32Array:
	var cell: float = BrickLattice.CELL
	return PackedInt32Array([floori(box.position.x / cell), floori(box.position.y / cell),
		floori(box.position.z / cell), ceili(box.end.x / cell), ceili(box.end.y / cell),
		ceili(box.end.z / cell)])


## [param top] rests on [param bottom]'s studs.
static func _seat(top: Node2, bottom: Node2) -> void:
	top.seated = true
	if not top.needs.has(bottom.id):
		top.needs.append(bottom.id)
	if not bottom.carries.has(top.id):
		bottom.carries.append(top.id)


## A plate pressed up under parts by its own studs, with nothing beneath
## it: a 1 x 3 under a sign, a 2 x 2 under a lantern. Read by its studs
## alone, what it carries needs it, so it went in first, on nothing. It goes
## in once what it is pressed under is there, and in the same step as the
## last of them ([method _sequence_into]): put in after them it is put in
## under them, and before them it floats.
##
## Only under a part that rests on something else as well; a part that
## rests on nothing but the plate is held up by it.
static func _pressed_up(nodes: Array[Node2], by_id: Dictionary) -> void:
	var floor_y: float = INF
	for node: Node2 in nodes:
		floor_y = minf(floor_y, node.box.position.y)
	for node: Node2 in nodes:
		if node.seated or not node.needs.is_empty() or node.carries.is_empty() \
				or node.wheel > 0 or node.box.position.y <= floor_y + 2.0:
			continue
		for over_id: int in node.carries:
			var over: Node2 = by_id[over_id]
			if over.needs.size() < 2 or not over.needs.has(node.id):
				continue
			over.needs.remove_at(over.needs.find(node.id))
			node.needs.append(over.id)
			node.under.append(over.id)


## [param one] and [param other] hold each other without either resting on
## the other.
static func _hold(one: Node2, other: Node2) -> void:
	if not one.held_by.has(other.id):
		one.held_by.append(other.id)
	if not other.held_by.has(one.id):
		other.held_by.append(one.id)


## What a part no stud joins rests on: what its box sits on.
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
static func _boxes_under(nodes: Array[Node2], job: Working.Job) -> void:
	# +Y is up here. LDraw has −Y up, but the conversion to engine space
	# negated Y and Z, so by the time a brick reaches this its underside
	# is box.position.y and its top is box.end.y.
	#
	# This was the other way round and every check agreed with it,
	# because the probe had made the same assumption — so a stack of ten
	# passed "starts at the bottom" while building from the top. What
	# caught it was looking at a booklet: step one of the lighthouse was
	# the lamp, hanging in the air above an empty baseplate.
	#
	# Kept by where its top is as well as by the square of the plan: a
	# tower is hundreds of bricks up every square, and comparing each with
	# every other in its column was five of the six seconds Orthanc's
	# timeline took to open (2026-10-12). Only a part whose top is within
	# SLACK of this one's underside can hold it up, and those are in the
	# layer or two that height falls in. Same answers, in the same order:
	# a square's candidates are taken in the order the parts are listed.
	const SLACK := 5.0
	const CELL := 40.0
	const LAYER := 8.0
	var grid: Dictionary = {}
	for index: int in nodes.size():
		var other: Node2 = nodes[index]
		# A wheel holds nothing up: it goes on last, and a chassis whose
		# underside happens to meet a tyre's top is held by the axle, not
		# the tyre.
		if other.wheel > 0:
			continue
		var layer: int = floori(other.box.end.y / LAYER)
		for cell: Vector2i in _cells(other.box, CELL):
			var key := Vector3i(cell.x, cell.y, layer)
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(index)
	for index: int in nodes.size():
		if job != null and job.due():
			job.count(index)
			await job.next()
			if job.cancelled:
				return
		var node: Node2 = nodes[index]
		if node.seated:
			continue
		var lowest: int = floori((node.box.position.y - SLACK) / LAYER)
		var highest: int = floori((node.box.position.y + SLACK) / LAYER)
		var seen: Dictionary = {}
		for cell: Vector2i in _cells(node.box, CELL):
			var near: Array = []
			for layer: int in range(lowest, highest + 1):
				near.append_array(grid.get(Vector3i(cell.x, cell.y, layer), []))
			if highest > lowest:
				near.sort()
			for other_index: int in near:
				if other_index == index or seen.has(other_index):
					continue
				seen[other_index] = true
				var other: Node2 = nodes[other_index]
				# other is under node when other's top meets node's
				# underside, allowing for the stud that reaches up into it.
				var sits_on: bool = (other.box.end.y >= node.box.position.y - SLACK
					and other.box.end.y <= node.box.position.y + SLACK)
				if sits_on and _overlaps_flat(node.box, other.box):
					node.boxed.append(other.id)


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
	var found: Array[Assembly] = []
	_find_assemblies_into(found, nodes, world, library, null)
	return found


## [method _find_assemblies] into [param found]; a slice at a time with a
## [param job]. On Orthanc it was one frame of 410 ms (progress_probe,
## 2026-10-15).
static func _find_assemblies_into(found: Array[Assembly], nodes: Array[Node2],
		world: BrickWorld, library: PartLibrary, job: Working.Job) -> void:
	var tops: Dictionary = {}
	var inner: Dictionary = {}
	var floor_y: float = INF
	for node: Node2 in nodes:
		floor_y = minf(floor_y, node.box.position.y)
	for node: Node2 in nodes:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
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

	# Whether a sub-model is a figure asks the figures' index, which the
	# first question builds: every part of the library looked at. Only
	# when there is a sub-model to ask about: a model of one piece waited
	# for all 29,000 parts to be sorted for nothing, 27 s of a slowed
	# phone's 41 before a shared model's first step (share_steps_flow).
	if job != null and not tops.is_empty():
		await Minifig.index_paced(library)
	for top: String in tops:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		var members: Array = tops[top]
		var figure: bool = _is_figure(members, world, library)
		if figure or _holds_together(members, nodes.size(), _turned(members, world), true,
				floor_y):
			found.append(_assembly(top, members, figure, world))
			continue
		for sub: String in inner:
			if not sub.begins_with(top + "/"):
				continue
			if job != null and job.due():
				await job.next()
				if job.cancelled:
					return
			var parts: Array = inner[sub]
			var sub_figure: bool = _is_figure(parts, world, library)
			if sub_figure or _holds_together(parts, nodes.size(), _turned(parts, world), false,
					floor_y):
				found.append(_assembly(sub, parts, sub_figure, world))


## A flexible thing drawn in pieces (a hose LDraw draws a segment at a
## time, a string, a chain) is one part in a builder's hand: it goes in in
## one step, once what its pieces need is there. Built a piece at a time
## from its free end, 6891's hose was 52 things floating, in 28 of its 83
## steps. Its pieces are those the build check holds as one thing
## (Flex.one_thing), outside the assemblies already found.
static func _find_bundles(nodes: Array[Node2], world: BrickWorld, library: PartLibrary,
		assemblies: Array[Assembly]) -> void:
	_find_bundles_into(nodes, world, library, assemblies, null)


## [method _find_bundles], a slice at a time with a [param job]. It was the
## one part of the sub-assembly search read in one go, and on Orthanc that
## search's longest frame was 120 ms of its own (progress_probe, 2026-10-16).
static func _find_bundles_into(nodes: Array[Node2], world: BrickWorld, library: PartLibrary,
		assemblies: Array[Assembly], job: Working.Job) -> void:
	var taken: Dictionary = {}
	for made: Assembly in assemblies:
		for member: Node2 in made.members:
			taken[member.id] = true
	var entries: Array = []
	var by_id: Dictionary = {}
	for node: Node2 in nodes:
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		by_id[node.id] = node
		if taken.has(node.id):
			continue
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		var part: Lbm.PartMesh = library.mesh_for(node.part_id)
		if brick != null and part != null:
			entries.append([node.id, brick.transform, part, node.part_id,
				Assemblies.path_of(brick)])
	for group: Array in _flexible(entries, library):
		var made := Assembly.new()
		made.whole = true
		made.key = "flexible:%d" % int(group[0])
		made.name = "flexible"
		made.kind = made.key
		for id: int in group:
			made.members.append(by_id[id])
		assemblies.append(made)
	# And one in a sub-assembly built on the side goes in as one there
	# ([method _on_the_side]): 920's launch pad, built in the hand, put its
	# hose in 140 pieces, each floating.
	for made: Assembly in assemblies:
		if made.whole or made.figure:
			continue
		if job != null and job.due():
			await job.next()
			if job.cancelled:
				return
		var inside: Array = []
		for member: Node2 in made.members:
			var brick: BrickWorld.Brick = world.get_brick(member.id)
			var part: Lbm.PartMesh = library.mesh_for(member.part_id)
			if brick != null and part != null:
				inside.append([member.id, brick.transform, part, member.part_id,
					Assemblies.path_of(brick)])
		for group: Array in _flexible(inside, library):
			made.bundles.append(PackedInt64Array(group))


## The flexible things among [param entries] (as Flex.one_thing takes
## them), each the ids of its pieces, two or more.
static func _flexible(entries: Array, library: PartLibrary) -> Array:
	var parent: Dictionary = {}
	var root_of := func(id: int) -> int:
		var at: int = id
		while parent.has(at) and int(parent[at]) != at:
			at = parent[at]
		return at
	for pair: Array in Flex.one_thing(entries, library):
		var one: int = root_of.call(int(pair[0]))
		var other: int = root_of.call(int(pair[1]))
		parent[one] = one
		if one != other:
			parent[other] = one
	var groups: Dictionary = {}
	for id: int in parent:
		var root: int = root_of.call(id)
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(id)
	var out: Array = []
	for root: int in groups:
		if (groups[root] as Array).size() >= 2:
			out.append(groups[root])
	return out


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


## Small enough to be built on the side, one piece when it is, and put
## on something when it is done. Two plates lying on the table are not a
## sub-assembly, they are the start of the model: a callout is for
## something built away from the model and then attached to it.
##
## A sub-model put on at an angle ([param turned]) is built on the side
## whatever its size, up to half the model: square, in the hand, and then
## put on turned, as its author built it. One the model places itself
## ([param top]) is built so at any size short of the whole: a model on its
## stand, as 76161's Batwing stands on its edge, is that sub-model and the
## stand, and its author builds the Batwing flat and stands it up. Built where it stands, its parts
## went in at an angle against parts already there: on the five biggest
## files of the sample the planner was tuned on, 19 in 20 of the things put
## in under a part already there were turned parts of a sub-model too big
## to be a callout, and their authors put in none (docs/INSTRUCTIONS.md).
static func _holds_together(members: Array, total: int, turned: bool = false,
		top: bool = false, floor_y: float = -INF) -> bool:
	if members.size() < 2:
		return false
	if turned:
		if members.size() >= total or not top and members.size() * 2 > total:
			return false
	elif members.size() > ASSEMBLY_MOST or members.size() * 10 > total * 3:
		return false
	var own: Dictionary = {}
	for node: Node2 in members:
		own[node.id] = true
	var attached: bool = members.any(func(node: Node2) -> bool:
		return Array(node.needs).any(func(need: int) -> bool: return not own.has(need)))
	# Or off the table and joined to the rest, by a stud, a pin, a side stud or
	# its cover, though nothing of it waits on the rest: once what rests on
	# what was read off the covers, 7130's wings, put on the hull at an angle,
	# and 8032's steering knuckle waited on nothing outside them, and were
	# built in place where their authors build them on the side.
	if not attached and members.all(func(node: Node2) -> bool:
			return node.box.position.y > floor_y + 2.0):
		attached = members.any(func(node: Node2) -> bool:
			for list: PackedInt64Array in [node.carries, node.held_by, node.joined, node.contacts]:
				for other: int in list:
					if not own.has(other):
						return true
			return false)
	if not attached:
		return false
	# One piece: every part touches another, by their boxes grown by a
	# hair. Supports alone would split a window from the glass clipped
	# into its side. Each against those in the squares of the plan its box
	# is in: a turned section of a thousand parts, all against all, was a
	# million comparisons.
	const CELL := 40.0
	var grid: Dictionary = {}
	for index: int in members.size():
		for cell: Vector2i in _cells((members[index] as Node2).box.grow(1.0), CELL):
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(index)
	var reached: Dictionary = {0: true}
	var frontier: Array[int] = [0]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		var box: AABB = (members[at] as Node2).box.grow(1.0)
		for cell: Vector2i in _cells(box, CELL):
			for other: int in grid[cell]:
				if reached.has(other):
					continue
				if box.intersects((members[other] as Node2).box):
					reached[other] = true
					frontier.append(other)
	return reached.size() == members.size()


## Whether most of [param members] stand off the square: a sub-model put
## on at an angle.
static func _turned(members: Array, world: BrickWorld) -> bool:
	var off: int = 0
	for node: Node2 in members:
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		if brick != null and not BrickLattice.is_square_to_grid(brick.transform.basis):
			off += 1
	return off * 2 > members.size()


## A sub-assembly put on turned is built square in the hand, as its author
## built it: what rests on what in it, and so its order, is read in the
## frame its parts stand square in, where "under" means under. 76161's
## Batwing stands on its edge on a stand; built in the world's frame, 1,692
## of its 2,396 things went in under a part already there.
static func _frame_turned(assemblies: Array[Assembly], world: BrickWorld,
		library: PartLibrary, job: Working.Job) -> void:
	for made: Assembly in assemblies:
		if made.figure or made.whole or not _turned(made.members, world):
			continue
		var frame: Variant = _frame_of(made.members, world)
		if frame == null:
			continue
		var at := Transform3D(frame as Basis, Vector3.ZERO)
		var nodes: Array[Node2] = []
		for member: Node2 in made.members:
			var brick: BrickWorld.Brick = world.get_brick(member.id)
			var part: Lbm.PartMesh = library.mesh_for(member.part_id)
			if brick == null or part == null:
				continue
			var copy := Node2.new()
			copy.id = member.id
			copy.part_id = member.part_id
			copy.group = member.group
			copy.unit = member.unit
			copy.wheel = member.wheel
			copy.box = (at * brick.transform) * part.bounds
			nodes.append(copy)
		await _supports_of(nodes, world, library, job, at)
		if job != null and job.cancelled:
			return
		_find_joints(nodes, world, library, at)
		_tidy_needs(nodes)
		await _hangers_of(nodes, job)
		made.framed = nodes


## How far a turned basis may be from square and still be square, for the
## six decimals LDraw writes a turn in and the three it often gets.
const SQUARE_SLACK := 0.02


## The turn that stands most of [param members] square, upright as most
## of them stand, as a Basis from the world's frame to theirs; null when
## no one frame holds most of them square.
static func _frame_of(members: Array, world: BrickWorld) -> Variant:
	var bases: Array[Basis] = []
	for node: Node2 in members:
		var brick: BrickWorld.Brick = world.get_brick(node.id)
		if brick != null:
			bases.append(brick.transform.basis.orthonormalized())
	if bases.is_empty():
		return null
	# A few of the parts' own frames, and the one most of them are square in.
	var best: Basis = Basis.IDENTITY
	var most: int = 0
	var every: int = maxi(1, bases.size() / 12)
	for at: int in range(0, bases.size(), every):
		var back: Basis = bases[at].inverse()
		var square: int = 0
		for basis: Basis in bases:
			if _square(back * basis):
				square += 1
		if square > most:
			most = square
			best = back
	if most * 2 <= bases.size():
		return null
	# Turned so that most parts' studs point up in it.
	var ups: Dictionary = {}
	for basis: Basis in bases:
		var turned: Basis = best * basis
		if _square(turned):
			var up := Vector3i((turned * Vector3.UP).round())
			ups[up] = int(ups.get(up, 0)) + 1
	var upright := Vector3i.UP
	for up: Vector3i in ups:
		if int(ups[up]) > int(ups.get(upright, 0)):
			upright = up
	if upright == Vector3i.DOWN:
		best = Basis(Vector3.RIGHT, PI) * best
	elif upright != Vector3i.UP:
		best = Basis(Vector3(upright).cross(Vector3.UP).normalized(), PI / 2.0) * best
	return best


static func _square(basis: Basis) -> bool:
	for axis: int in 3:
		var column: Vector3 = basis[axis]
		for k: int in 3:
			var value: float = absf(column[k])
			if value > SQUARE_SLACK and absf(value - 1.0) > SQUARE_SLACK:
				return false
	return true


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
##
## But a loop closed by a guess is the guess's fault: what a part nothing
## holds was hung from because its box touched it, and then what a part
## with no studs was read to rest on by its box. Those are given up on the
## loop first, and only then the smallest assembly on it, one at a time: a
## hose drawn through a figure's hand, a track touching a bogie, cost a
## 664-part trailer, a locomotive and the figures riding them their
## callouts, all of them.
static func _contract(nodes: Array[Node2], assemblies: Array[Assembly]) -> Array[Node2]:
	var built: Array[Node2] = []
	_contract_into(built, nodes, assemblies, null)
	return built


## [method _contract] into [param out]; a slice at a time with a
## [param job]. On Orthanc its walk for loops was the longest frame of the
## sub-assembly search (progress_probe, 2026-10-15).
static func _contract_into(out: Array[Node2], nodes: Array[Node2],
		assemblies: Array[Assembly], job: Working.Job) -> void:
	var eased: int = 0
	for _attempt: int in 24:
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
			if job != null and job.due():
				await job.next()
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

		var looped: Dictionary = {}
		await _cycles_into(looped, built, job)
		var caught: Array[Assembly] = []
		for made: Assembly in assemblies:
			if looped.has(made.node.id):
				caught.append(made)
		if caught.is_empty():
			out.assign(built)
			return
		if eased < 3:
			eased += 1
			_ease(looped, nodes, member_of, eased)
			continue
		caught.sort_custom(func(a: Assembly, b: Assembly) -> bool:
			return a.members.size() < b.members.size())
		assemblies.erase(caught[0])
	# Nothing settled: build everything in place.
	assemblies.clear()
	for node: Node2 in nodes:
		node.after = node.needs.duplicate()
	out.assign(nodes)


## Give up the guessed needs on a loop: between two parts both on it, or in
## an assembly on it. From [param level] 2, what a part with no studs rests
## on by its box as well. From 3, any need into or out of a sub-assembly on
## the loop but a stud's: a pin's or an axle's, which of two parts goes
## first is a choice the plan made, and so is a part's waiting on what holds
## it from the side or a plate's on what it is pressed up under. A loop of
## those cost 18 of the 100 tune files 39 of their author's sub-assemblies
## (Vernie's arms, pinned to its body; 70816's walls, a plate pressed up
## under a part that stands on them), and with them their order.
static func _ease(looped: Dictionary, nodes: Array[Node2], member_of: Dictionary,
		level: int) -> void:
	var on_loop := func(id: int) -> bool:
		var made: Assembly = member_of.get(id)
		return looped.has(made.node.id if made != null else id)
	var by_id: Dictionary = {}
	if level >= 3:
		for node: Node2 in nodes:
			by_id[node.id] = node
	for node: Node2 in nodes:
		if (level < 3 and node.weak.is_empty() and (level < 2 or node.boxed.is_empty())) \
				or not on_loop.call(node.id):
			continue
		var kept := PackedInt64Array()
		for need: int in node.needs:
			var apart: bool = member_of.get(need) == null \
				or member_of.get(need) != member_of.get(node.id)
			if apart and on_loop.call(need) and (node.weak.has(need)
					or (level >= 2 and node.boxed.has(need))
					or (level >= 3 and _soft(node, need, by_id, member_of))):
				continue
			kept.append(need)
		node.needs = kept


## Whether [param node]'s need of [param need] crosses a sub-assembly's edge
## and is not a stud's: it does not rest on the other's studs, nor the other
## on its own turned over.
static func _soft(node: Node2, need: int, by_id: Dictionary, member_of: Dictionary) -> bool:
	if member_of.get(node.id) == null and member_of.get(need) == null:
		return false
	var other: Node2 = by_id.get(need)
	return other != null and not other.carries.has(node.id)


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
static func _sequence(nodes: Array[Node2], named: bool, per_step: int,
		in_hand: bool = false, parts_of: Dictionary = {}) -> Array:
	var steps: Array = []
	_sequence_into(steps, nodes, named, per_step, null, in_hand, parts_of)
	return steps


## [method _sequence] into [param steps]; a slice at a time with a
## [param job], which counts the bricks placed.
static func _sequence_into(steps: Array, nodes: Array[Node2], named: bool, per_step: int,
		job: Working.Job, in_hand: bool = false, parts_of: Dictionary = {}) -> void:
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
	if job != null:
		await job.next()
	var remaining: Dictionary = {}
	var ready: Dictionary = {}
	for node: Node2 in nodes:
		remaining[node.id] = node
		if int(waiting[node.id]) == 0:
			ready[node.id] = node
	# What is held only by guesses, off the table: the lowest that is not a
	# wheel, which goes on last.
	var floor_y: float = INF
	for node: Node2 in nodes:
		if node.wheel == 0:
			floor_y = minf(floor_y, node.box.position.y)
	for node: Node2 in nodes:
		node.guessed = node.assembly == null and node.wheel == 0 \
			and node.box.position.y > floor_y + 2.0 \
			and Array(node.needs).all(func(need: int) -> bool: return node.weak.has(need))

	var last_at: Vector3 = Vector3.ZERO
	var have_last: bool = false
	var placed: int = 0
	var pictures := Pictures.new()
	# What each node touches, and whether it would join what is built: see
	# [method _touching].
	var touches: Dictionary = _touching(nodes, parts_of)
	# What is built so far, in pieces by what touches what, and which pieces
	# stand: on the table, or joined to one that does. A part joined only to a
	# piece in the air went on it, and floated with it. The table is where the
	# model as it stands rests, its own lowest point: a car without its wheels
	# lies on its chassis. In the hand, the first step's parts are the piece.
	var piece: Dictionary = {}       ## placed id -> the id it is joined under
	var stands: Dictionary = {}      ## a piece's root -> true
	var members: Dictionary = {}     ## a piece's root -> its parts' ids
	var table: Array[float] = [INF]  ## the lowest underside built so far
	## What touches a standing piece: kept as pieces come to stand, not asked
	## of every part ready each time a part is chosen, which on 76161's
	## Batwing in the hand was most of what choosing cost.
	var by_standing: Dictionary = {}
	var stood := func(ids: Array) -> void:
		for id: int in ids:
			for other: int in touches.get(id, {}):
				by_standing[other] = true
	var joins := func(node: Node2) -> bool:
		if in_hand and steps.is_empty() or piece.is_empty():
			return true
		if not in_hand and node.box.position.y <= table[0] + 2.0:
			return true
		return by_standing.has(node.id)
	## The region being built, and what each one is called in the
	## booklet: its own name, or "part n" in the order they are reached.
	var current: String = ""
	var called: Dictionary = {}

	while not remaining.is_empty():
		if job != null and job.due():
			job.count(placed)
			await job.next()
			if job.cancelled:
				return
		var picked: Array[Node2] = []
		var section: String = ""
		var unsupported: bool = false
		## Ready and near, and left for the next step: each would hide a part
		## this one holds.
		var refused: Dictionary = {}
		## The parts of this step that join what was built when they went in:
		## those a part is kept from hiding.
		var held_here: Array[Node2] = []
		while picked.size() < per_step:
			# And between the parts of a step: each is looked for among
			# every part ready, and on Orthanc in a browser one step of them
			# was a 273 ms slice of the Timeline's (progress_check).
			if job != null and not picked.is_empty() and job.due():
				job.count(placed)
				await job.next()
				if job.cancelled:
					return
			var first: Node2 = picked[0] if not picked.is_empty() else null
			var chosen: Array = _next(ready, remaining, last_at, have_last,
				first, current, refused, joins, picked)
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
			# Not over a part this step puts in: the picture would hide it.
			# Unless that part joins nothing built but this one, which holds it.
			if not picked.is_empty() and pictures.would_hide(node, held_here):
				refused[node.id] = true
				continue
			if joins.call(node):
				held_here.append(node)

			# And a plate pressed up under it, now that the last thing it is
			# under is there: in this step, so it is neither on nothing before
			# them nor put in under them after.
			var placing: Array[Node2] = [node]
			while not placing.is_empty():
				var here: Node2 = placing.pop_back()
				remaining.erase(here.id)
				ready.erase(here.id)
				picked.append(here)
				pictures.accept(here)
				piece[here.id] = here.id
				members[here.id] = [here.id]
				if in_hand and steps.is_empty() or not in_hand \
						and here.box.position.y <= table[0] + 2.0:
					stands[here.id] = true
				if not in_hand:
					table[0] = minf(table[0], here.box.position.y)
				for other: int in touches.get(here.id, {}):
					if piece.has(other):
						var one: int = _root_of(piece, here.id)
						var two: int = _root_of(piece, other)
						if one == two:
							continue
						# The bigger keeps its root; a piece that comes to stand
						# makes all it touches joined.
						if (members[one] as Array).size() < (members[two] as Array).size():
							var swap: int = one
							one = two
							two = swap
						if stands.has(one) != stands.has(two):
							stood.call(members[two] if stands.has(one) else members[one])
							stands[one] = true
						piece[two] = one
						(members[one] as Array).append_array(members[two])
						members.erase(two)
				if stands.has(_root_of(piece, here.id)):
					stood.call([here.id])
				for dependent: int in dependents.get(here.id, []):
					waiting[dependent] = int(waiting[dependent]) - 1
					if int(waiting[dependent]) == 0 and remaining.has(dependent):
						ready[dependent] = by_id[dependent]
						var under_it: Node2 = by_id[dependent]
						if under_it.under.has(here.id) or not in_hand and under_it.hung.has(here.id) \
								and not (under_it.wheel > 0 and steps.is_empty()):
							placing.append(under_it)
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
		pictures.built(picked)
		for node: Node2 in picked:
			placed += node.assembly.members.size() if node.assembly != null else 1


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
		current: String = "", refused: Dictionary = {},
		joins: Callable = Callable(), step: Array = []) -> Array:
	var same_step: bool = first != null
	var kind: String = (first.assembly.kind
		if same_step and first.assembly != null and not first.assembly.whole else "")
	var fits := func(node: Node2) -> bool:
		if not same_step:
			return true
		# Wheels go on in a step of wheels: a step whose next part would hide
		# one it holds filled up with the wheels beside it instead, and the
		# example car began with its wheels.
		if (node.wheel > 0) != (first.wheel > 0):
			return false
		var loose: bool = node.assembly == null or node.assembly.whole
		if kind.is_empty():
			return loose
		# A step that puts a sub-assembly on puts on the parts that go on
		# beside it too, as the authors' do: one in nine of ours was the
		# sub-assembly alone, against one in two of theirs.
		if loose:
			return ATTACH_TAKES_PARTS and _near_step(node, step)
		return node.assembly.kind == kind

	var here: Node2 = _best(ready, last_at, have_last, same_step and kind.is_empty(),
		func(node: Node2) -> bool:
			return node.region == current and fits.call(node) and not refused.has(node.id),
		false, joins, step)
	# Nothing legal is near enough: end the step rather than reaching
	# across the model, or into another region, for the sake of filling it.
	if same_step:
		return [here, HERE]
	# A step begun with a part that joins nothing standing floats, and so
	# does all that goes on it until what holds it is reached: begin with
	# one this region waits for, or one elsewhere, that joins what stands.
	if STEADIER_FIRST and here != null and joins.is_valid() and not joins.call(here):
		var steady: Array = _steadier(ready, remaining, last_at, have_last, current, joins)
		if not steady.is_empty():
			return steady
	if here != null:
		return [here, HERE]

	var wanted: Dictionary = {}
	for node: Node2 in remaining.values():
		if node.region != current:
			continue
		for need: int in node.after:
			if remaining.has(need):
				wanted[need] = true
	var borrowed: Node2 = _best(ready, last_at, have_last, false,
		func(node: Node2) -> bool: return wanted.has(node.id), false, joins)
	if borrowed != null:
		return [borrowed, BORROWED]

	var moved: Node2 = _best(ready, last_at, have_last, false,
		func(_node: Node2) -> bool: return true, true, joins)
	if moved != null:
		return [moved, MOVED]
	# Nothing anywhere is ready: the lowest remaining goes in anyway, and
	# the step says so. With +Y up the underside is box.position.y, so the
	# smallest value is the one nearest the table. Not a wheel, which waits
	# on its axle and not on a loop: 8022's tyres went on before their rims.
	var lowest: Node2 = null
	for node: Node2 in remaining.values():
		if lowest == null:
			lowest = node
		elif (node.wheel > 0) != (lowest.wheel > 0):
			if lowest.wheel > 0:
				lowest = node
		elif node.box.position.y < lowest.box.position.y:
			lowest = node
	return [lowest, MOVED]


## A ready node that joins what stands ([param joins]), when the region's
## best does not: one the region waits for, then the nearest anywhere, as
## [method _next] borrows and moves. Empty when there is none.
static func _steadier(ready: Dictionary, remaining: Dictionary, last_at: Vector3,
		have_last: bool, current: String, joins: Callable) -> Array:
	# From another region: this one's were all looked at for the step's first.
	# What this one waits on is asked only when another region has a part
	# ready that joins what stands: in the hand, one region, it was every part
	# left read at every step's start, for nothing.
	# A loop, not any() with a lambda: in one region every part ready was a
	# call for nothing at each step's start.
	var elsewhere: bool = false
	for node: Node2 in ready.values():
		if node.region != current and joins.call(node):
			elsewhere = true
			break
	if elsewhere:
		var wanted: Dictionary = {}
		for node: Node2 in remaining.values():
			if node.region != current:
				continue
			for need: int in node.after:
				if remaining.has(need):
					wanted[need] = true
		var borrowed: Node2 = _best(ready, last_at, have_last, false,
			func(node: Node2) -> bool: return node.region != current and wanted.has(node.id),
			false, joins, [], true)
		if borrowed != null:
			return [borrowed, BORROWED]
	if not STEADIER_MOVES:
		return []
	var moved: Node2 = _best(ready, last_at, have_last, false,
		func(_node: Node2) -> bool: return true, true, joins, [], true)
	if moved != null:
		return [moved, MOVED]
	return []


## The best ready node among those [param allowed] admits, or null.
##
## Height dominates; distance only breaks ties within a layer, so a
## nearby brick two layers up never jumps the queue. Moving to a new
## region it is the other way round: nothing is built there yet, so
## whatever is ready is near the table anyway, and the nearest one keeps
## the build moving to the region next door rather than across the model.
static func _best(ready: Dictionary, last_at: Vector3, have_last: bool,
		same_step: bool, allowed: Callable, nearest_first: bool,
		joins: Callable = Callable(), step: Array = [], only_joined: bool = false) -> Node2:
	var best: Node2 = null
	var best_score: float = INF
	for node: Node2 in ready.values():
		var distance: float = (node.box.get_center().distance_to(last_at)
			if have_last else 0.0)
		# The cheap reasons first, and whether it joins what stands only for
		# one that could still be the best: asked of every part ready, every
		# time a part was chosen, it was most of what Orthanc's order cost.
		# Whether it is allowed too: a lambda or two a part ready.
		var base: float = (distance * 1000.0 + node.box.position.y
			if nearest_first
			else node.box.position.y * 1000.0 + distance)
		if base >= best_score:
			continue
		if not allowed.call(node):
			continue
		if same_step and distance > NEAR and not _near_step(node, step):
			continue
		var score: float = base
		# Wheels go on at the end, as a set's do, not with the chassis
		# plate they hang from at the bottom of it; unless they go on with
		# their holder ([constant WHEELS_WITH_HOLDER], [method _hung_under]).
		if node.wheel > 0 and node.hung.is_empty():
			score += WHEELS_LATER
		# And a part held only by a guess after what is held for certain:
		# begun first, it was a piece of its own in the air until the rest
		# reached it.
		elif node.guessed:
			score += 1.0e8
		# And one that touches nothing built yet after one that does: what it
		# rests on was let go to break a loop, or is outside the sub-assembly
		# being built in the hand, and put in first it floated, and what went
		# on it floated with it.
		if score >= best_score:
			continue
		if joins.is_valid() and not joins.call(node):
			if only_joined:
				continue
			score += UNJOINED_LATER
		if score < best_score:
			best_score = score
			best = node
	return best


## The root of [param id]'s piece, in a union of placed parts by id.
static func _root_of(piece: Dictionary, id: int) -> int:
	var at: int = id
	while int(piece[at]) != at:
		at = piece[at]
	# Every part on the way points at the root from now on: a union walked
	# from its newest part to its oldest was a list as long as the build.
	var on: int = id
	while on != at:
		var next: int = piece[on]
		piece[on] = at
		on = next
	return at


## Whether [param node] belongs in a step holding [param step] though it is
## not near the part put in last: near another of them, or one more of a
## part the step puts in at its height, a row of tiles or the 1 x 1s round a
## rim, within [constant LIKE_REACH]. A step reached only from the part
## before it ended at the first gap: one step in four of ours was one part
## (docs/INSTRUCTIONS.md).
static func _near_step(node: Node2, step: Array) -> bool:
	var at: Vector3 = node.box.get_center()
	for other: Node2 in step:
		var gap: float = at.distance_to(other.box.get_center())
		if gap <= NEAR:
			return true
		# Beside a sub-assembly the step puts on, wherever its middle is.
		if other.assembly != null and other.box.grow(NEAR / 4.0).intersects(node.box):
			return true
		if gap <= LIKE_REACH and other.part_id == node.part_id and not node.part_id.is_empty() \
				and absf(other.box.position.y - node.box.position.y) < 1.0:
			return true
	return false


## What each of [param nodes] touches among the others, by id: what it
## rests on and carries by the studs, what holds it from the side, a pin or
## axle either way, and what its cover rests on or carries (Node2's
## carries, held_by, joined and contacts), both ways round. Not what its box
## sits on or touches: those are guesses, and a part that only they hold
## floats. A node standing for several
## parts (a sub-assembly, or the pieces of a flexible thing in
## [param parts_of]) touches what any of them does.
static func _touching(nodes: Array[Node2], parts_of: Dictionary = {}) -> Dictionary:
	var node_of: Dictionary = {}     ## part id -> the node standing for it
	var parts: Dictionary = {}       ## node id -> its parts
	for node: Node2 in nodes:
		var mine: Array = []
		if parts_of.has(node.id):
			mine = parts_of[node.id]
		elif node.assembly != null:
			mine = node.assembly.members
		else:
			mine = [node]
		parts[node.id] = mine
		for part: Node2 in mine:
			node_of[part.id] = node.id
	var out: Dictionary = {}
	for node: Node2 in nodes:
		out[node.id] = {}
	for node: Node2 in nodes:
		for part: Node2 in parts[node.id]:
			for list: PackedInt64Array in [part.carries, part.held_by, part.joined,
					part.contacts]:
				for other: int in list:
					var into: Variant = node_of.get(other)
					if into == null or int(into) == node.id:
						continue
					(out[node.id] as Dictionary)[int(into)] = true
					(out[int(into)] as Dictionary)[node.id] = true
	return out


# -- steps -------------------------------------------------------------------


## Number the steps and open each sub-assembly into its callout: its own
## steps, then the step that puts it on.
static func _expand(raw: Array, world: BrickWorld) -> Array[Step]:
	_fold_lone_sections(raw)
	var out: Array[Step] = []
	var number: int = 0
	var callouts: int = 0
	for entry: Dictionary in raw:
		number += 1
		var picked: Array = entry["nodes"]
		var first: Node2 = picked[0]
		if first.assembly == null or first.assembly.whole:
			var step := Step.new()
			step.number = number
			step.section = str(entry["section"])
			step.unsupported = bool(entry["unsupported"])
			for node: Node2 in picked:
				if node.assembly != null:
					for member: Node2 in node.assembly.members:
						_add(step, member)
				else:
					_add(step, node)
			out.append(step)
			continue

		callouts += 1
		var made: Assembly = first.assembly
		# The copies it puts on, and the parts it puts on beside them.
		var loose: Array = picked.filter(func(node: Node2) -> bool:
			return node.assembly == null or node.assembly.whole)
		picked = picked.filter(func(node: Node2) -> bool:
			return node.assembly != null and not node.assembly.whole)
		# A section built on the side, past a callout's size, has framed
		# pages of its own, and steps of a page's size.
		var per: int = 99 if made.figure else (CALLOUT_PER_STEP
			if made.members.size() <= ASSEMBLY_MOST else _per_step(made.members.size()))
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
		for node: Node2 in loose:
			if node.assembly != null:
				for member: Node2 in node.assembly.members:
					_add(attach, member)
			else:
				_add(attach, node)
		out.append(attach)
	for index: int in out.size():
		out[index].index = index + 1
	return out


## A section of one step is no section: it goes under the banner of the
## section after it, or before it when it is the last. 8032's steering
## knuckle, a sub-model built in place, was "Cabrio Sub 6a" for one step and
## then "the rest", two banners on one page.
static func _fold_lone_sections(raw: Array) -> void:
	var runs: Array = []      ## [first entry, last entry] of each section's run
	for at: int in raw.size():
		if runs.is_empty() or str(raw[at]["section"]) != str(raw[(runs[-1] as Array)[1]]["section"]):
			runs.append([at, at])
		else:
			(runs[-1] as Array)[1] = at
	if runs.size() < 2:
		return
	for k: int in runs.size():
		var run: Array = runs[k]
		if int(run[0]) != int(run[1]) or str(raw[run[0]]["section"]).is_empty():
			continue
		# Into the one after, or else the one before, that it touches: a step
		# that touches neither is a thing of its own, a yard beside the
		# house, drawn on its own (BookletMaker._find_apart) under its banner.
		for into: Array in ([runs[k + 1]] if k + 1 < runs.size() else []) \
				+ ([runs[k - 1]] if k > 0 else []):
			if _touches_run(raw[run[0]]["nodes"], raw, into):
				raw[run[0]]["section"] = raw[into[0]]["section"]
				break


## Whether any of [param nodes] touches a node of the steps of [param raw]
## from [code]run[0][/code] to [code]run[1][/code], by their boxes.
static func _touches_run(nodes: Array, raw: Array, run: Array) -> bool:
	for node: Node2 in nodes:
		var box: AABB = node.box.grow(1.0)
		for at: int in range(int(run[0]), int(run[1]) + 1):
			for other: Node2 in raw[at]["nodes"]:
				if box.intersects(other.box):
					return true
	return false


static func _add(step: Step, node: Node2) -> void:
	step.brick_ids.append(node.id)
	step.parts[node.part_id] = int(step.parts.get(node.part_id, 0)) + 1


## A sub-assembly's own steps, built on the table: what its parts rest
## on among themselves, the lowest first. A figure goes together in one.
static func _on_the_side(made: Assembly, per_step: int) -> Array:
	var own: Dictionary = {}
	for member: Node2 in made.members:
		own[member.id] = true
	# A flexible thing in it goes in as one, as it does in the main build:
	# a node stands for it while the order is worked out.
	var bundle_of: Dictionary = {}   ## member id -> the node standing for its bundle
	var held: Dictionary = {}        ## that node's id -> its pieces
	for at: int in made.bundles.size():
		var stand := Node2.new()
		stand.id = -(at + 1)
		held[stand.id] = []
		for id: int in made.bundles[at]:
			bundle_of[id] = stand
	var members: Array[Node2] = []
	for member: Node2 in (made.framed if not made.framed.is_empty() else made.members):
		var stand: Node2 = bundle_of.get(member.id)
		if stand == null:
			member.after = _within(member.needs, own, bundle_of, null)
			member.region = ""
			members.append(member)
			continue
		if (held[stand.id] as Array).is_empty():
			stand.box = member.box
			stand.part_id = member.part_id
			members.append(stand)
		else:
			stand.box = stand.box.merge(member.box)
		(held[stand.id] as Array).append(member)
		for need: int in _within(member.needs, own, bundle_of, stand):
			if not stand.after.has(need):
				stand.after.append(need)
	var out: Array = _sequence(members, false, per_step, true, held)
	if held.is_empty():
		return out
	for chunk: Dictionary in out:
		var nodes: Array[Node2] = []
		for node: Node2 in chunk["nodes"]:
			if held.has(node.id):
				for piece: Node2 in held[node.id]:
					nodes.append(piece)
			else:
				nodes.append(node)
		chunk["nodes"] = nodes
	return out


## [param needs] among [param own], each piece of a flexible thing standing
## as its node ([param bundle_of]), and none of [param stand]'s own.
static func _within(needs: PackedInt64Array, own: Dictionary, bundle_of: Dictionary,
		stand: Node2) -> PackedInt64Array:
	var out := PackedInt64Array()
	for need: int in needs:
		if not own.has(need):
			continue
		var target: int = need
		var into: Node2 = bundle_of.get(need)
		if into != null:
			if into == stand:
				continue
			target = into.id
		if not out.has(target):
			out.append(target)
	return out


# -- the author's steps --------------------------------------------------------


## The build in the steps its author gave it: each step what the author put
## in it, in their order, a sub-model's own steps before the step that puts
## it on. A small sub-model the main build puts on whole is still built on
## the side, as a callout, found as the worked-out plan finds one (by
## unit); a big one is built in its own steps where it stands. Regions and
## the limit on parts a step are the worked-out plan's, not the author's,
## and are left out. Parts with no step — added since, by hand or by a
## design — come after the author's steps, in steps worked out for them.
static func _authored_plan(world: BrickWorld, library: PartLibrary,
		skip: Dictionary) -> Array[Step]:
	var steps := PackedInt32Array()
	var shape: Array = _shape_of(world, library, skip, steps)
	var kept: Dictionary = _shaped_as_before(shape)
	var nodes: Array[Node2] = []
	var paths := PackedStringArray()
	if kept.is_empty():
		nodes = _survey(world, library, skip)
		if nodes.is_empty():
			return []
		_find_supports(nodes, world, library)
		_find_joints(nodes, world, library)
		_tidy_needs(nodes)
		_find_hangers(nodes)
		paths = _paths_of(nodes)
		_keep_shaped(shape, nodes, paths)
	else:
		nodes = kept["nodes"]
		paths = kept["paths"]
	var given: PackedByteArray = _given_of(steps)
	var found: Array[Assembly] = _assemblies_as_before(shape, given)
	if found.is_empty():
		found = _find_assemblies(_given_a_step(nodes, given), world, library)
		_keep_assemblies(shape, given, found)
	return _authored_from(nodes, found, world, library, skip, steps, paths)


## What [method plan] reads of a model before it orders anything: each part
## surveyed, with what it rests on, is joined to and hangs from
## ([method _find_supports] to [method _find_hangers]). The reading the
## author's plan keeps (_shaped) when the model's shape is the one last
## read; else read, and kept for the next. With [param to_change], copies
## (Node2.take), which the caller may change; else the nodes kept, which it
## must not. Suggest sections reads it so: worked out on its own, it was a
## second of Orthanc's twelve, which the booklet or the timeline had read
## already (bigmodels2).
static func read_shape(world: BrickWorld, library: PartLibrary, skip: Dictionary,
		to_change: bool) -> Array[Node2]:
	var shape: Array = _shape_of(world, library, skip)
	var kept: Dictionary = _shaped_as_before(shape)
	var nodes: Array[Node2] = []
	if not kept.is_empty():
		nodes = kept["nodes"]
	else:
		nodes = _survey(world, library, skip)
		if nodes.is_empty():
			return nodes
		_find_supports(nodes, world, library)
		_find_joints(nodes, world, library)
		_tidy_needs(nodes)
		_find_hangers(nodes)
		_keep_shaped(shape, nodes, _paths_of(nodes))
	if not to_change:
		return nodes
	var copies: Array[Node2] = []
	copies.resize(nodes.size())
	for index: int in nodes.size():
		var own := Node2.new()
		own.take(nodes[index])
		copies[index] = own
	return copies


## What the author's plan last read of a model's shape: what each part
## rests on, is joined to and hangs from (_find_supports to _find_hangers),
## which only where its parts are says. {"shape" (_shape_of), "nodes", each
## node's "paths" (Assemblies.path_of), and once found, "given" (which have
## a step, _given_of) and the sub-assemblies "found" among those}. A step
## edit moves no part, and the timeline read the Wizard's Tower's 10,101
## parts again after every one: 1.3 s, the same as before it (race244).
## Plans run on workers too (ModelStore's file written on one), so it is
## read and written under a lock, and what it holds is only read once kept:
## what the plan goes on to change of a node, it changes of a copy
## (_authored_from).
static var _shaped: Dictionary = {}
static var _shaped_lock := Mutex.new()


## What that reading depends on: the parts [method _survey] makes nodes of,
## in its order, each with its sub-model and copy, where it is and the mesh
## it is read from; and its colour, which a sub-assembly's kind is named by
## (_assembly), for the sub-assemblies kept with it. Into [param steps],
## when given one, each one's step (-1 for none), read in the same pass.
static func _shape_of(world: BrickWorld, library: PartLibrary, skip: Dictionary,
		steps: PackedInt32Array = PackedInt32Array()) -> Array:
	var ids := PackedInt64Array()
	var parts := PackedStringArray()
	var groups := PackedStringArray()
	var units := PackedStringArray()
	var meshes := PackedInt64Array()
	var colours := PackedInt32Array()
	var places: Array[Transform3D] = []
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		ids.append(brick.id)
		parts.append(brick.part_id)
		groups.append(brick.group)
		units.append(brick.unit)
		meshes.append(mesh.get_instance_id())
		colours.append(brick.color_code)
		places.append(brick.transform)
		steps.append(brick.step)
	return [ids, parts, groups, units, meshes, colours, places]


## A 1 for each of [param steps] that is a step and a 0 for each that is
## none: which parts are built in the author's steps.
static func _given_of(steps: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(steps.size())
	for index: int in steps.size():
		out[index] = 1 if steps[index] >= 0 else 0
	return out


## Each node's place in the tree (Assemblies.path_of), from its sub-model
## and copy as surveyed.
static func _paths_of(nodes: Array[Node2]) -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node2 in nodes:
		out.append(Assemblies.path_from(node.group, node.unit))
	return out


## The nodes of [param nodes] (as surveyed, of the shape [param given] was
## read with) that have a step: [method _stepped], without asking the world.
static func _given_a_step(nodes: Array[Node2], given: PackedByteArray) -> Array[Node2]:
	var out: Array[Node2] = []
	for index: int in nodes.size():
		if given[index] == 1:
			out.append(nodes[index])
	return out


## {"nodes", "paths"} as read of [param shape] when it is the one last
## read; else empty. Read them; never change one.
static func _shaped_as_before(shape: Array) -> Dictionary:
	var out: Dictionary = {}
	_shaped_lock.lock()
	if not _shaped.is_empty() and _shaped["shape"] == shape:
		var nodes: Array[Node2] = (_shaped["nodes"] as Array[Node2]).duplicate()
		out = {"nodes": nodes, "paths": _shaped["paths"]}
	_shaped_lock.unlock()
	return out


static func _keep_shaped(shape: Array, nodes: Array[Node2], paths: PackedStringArray) -> void:
	_shaped_lock.lock()
	_shaped = {"shape": shape, "nodes": nodes.duplicate(), "paths": paths}
	_shaped_lock.unlock()


## The sub-assemblies found among the parts of [param shape] that have a
## step ([param given], _given_of) when they were found last of the same;
## else none. Read them; never change one: a step edit moves a part between
## steps, and which parts are built on the side is the same as before it.
static func _assemblies_as_before(shape: Array, given: PackedByteArray) -> Array[Assembly]:
	var out: Array[Assembly] = []
	_shaped_lock.lock()
	if _shaped.has("found") and _shaped["shape"] == shape and _shaped["given"] == given:
		out = (_shaped["found"] as Array[Assembly]).duplicate()
	_shaped_lock.unlock()
	return out


static func _keep_assemblies(shape: Array, given: PackedByteArray, found: Array[Assembly]) -> void:
	_shaped_lock.lock()
	if not _shaped.is_empty() and _shaped["shape"] == shape:
		_shaped["given"] = given
		_shaped["found"] = found.duplicate()
	_shaped_lock.unlock()


## [method _authored_plan] a slice at a time with a [param job], as the
## worked-out plan is read (plan_paced). Read in one go, the Wizard's
## Tower's own steps held Timeline's frame for 1.7 s (orthsteps212).
static func _authored_plan_paced(world: BrickWorld, library: PartLibrary,
		skip: Dictionary, job: Working.Job) -> Array[Step]:
	var steps := PackedInt32Array()
	var shape: Array = _shape_of(world, library, skip, steps)
	var kept: Dictionary = _shaped_as_before(shape)
	if not kept.is_empty():
		return await _authored_paced_from(shape, steps, kept["nodes"], kept["paths"], world,
			library, skip, job)
	var nodes: Array[Node2] = []
	await _survey_into(nodes, world, library, skip, job)
	if nodes.is_empty() or job.cancelled:
		return []
	var count: String = Working.comma(nodes.size())
	job.say("Finding what %s parts rest on…" % count)
	job.count(0, nodes.size())
	await _supports_of(nodes, world, library, job)
	if job.cancelled:
		return []
	job.say("Finding the joints between %s parts…" % count)
	job.count(0, 0)
	await job.next()
	await _joints_of(nodes, world, library, job)
	if job.due():
		await job.next()
	_tidy_needs(nodes)
	await job.next()
	if job.cancelled:
		return []
	job.say("Finding what hangs off %s parts…" % count)
	await _hangers_of(nodes, job)
	await job.next()
	if job.cancelled:
		return []
	# Kept only when nothing moved while it was read, a slice a frame.
	var now := PackedInt32Array()
	if _shape_of(world, library, skip, now) != shape or now != steps:
		return await _authored_paced_from([], steps, nodes, PackedStringArray(), world, library,
			skip, job)
	var paths: PackedStringArray = _paths_of(nodes)
	_keep_shaped(shape, nodes, paths)
	return await _authored_paced_from(shape, steps, nodes, paths, world, library, skip, job)


## The rest of [method _authored_plan_paced], from [param nodes] read of
## [param shape] ([] when it changed while it was read, and nothing is kept),
## with each one's step and path ([param steps], [param paths]) as it began.
static func _authored_paced_from(shape: Array, steps: PackedInt32Array, nodes: Array[Node2],
		paths: PackedStringArray, world: BrickWorld, library: PartLibrary, skip: Dictionary,
		job: Working.Job) -> Array[Step]:
	var given: PackedByteArray = _given_of(steps)
	# Not `[] if … else …`: that [] is untyped, and assigning it here stopped
	# the plan with a script error whenever shape came back empty (2026-10-30).
	var found: Array[Assembly] = []
	if not shape.is_empty():
		found = _assemblies_as_before(shape, given)
	if not found.is_empty():
		return _authored_from(nodes, found, world, library, skip, steps, paths)
	job.say("Finding what is built on the side…")
	await _find_assemblies_into(found, _stepped(nodes, world), world, library, job)
	await job.next()
	if job.cancelled:
		for made: Assembly in found:
			made.node = null
		return []
	# Read again after the frames it took: its steps as they are now.
	var now := PackedInt32Array()
	if not shape.is_empty() and _shape_of(world, library, skip, now) == shape \
			and _given_of(now) == given:
		_keep_assemblies(shape, given, found)
	return _authored_from(nodes, found, world, library, skip)


## The parts of [param nodes] the author gave a step.
static func _stepped(nodes: Array[Node2], world: BrickWorld) -> Array[Node2]:
	var out: Array[Node2] = []
	for node: Node2 in nodes:
		if world.get_brick(node.id).step >= 0:
			out.append(node)
	return out


## The author's steps of [param nodes], read and joined, with [param found]
## the sub-assemblies built on the side. [param steps] and [param paths], when
## given, are each node's step and path as they are now, read already
## (_authored_plan); else each is asked of the world.
static func _authored_from(nodes: Array[Node2], found: Array[Assembly], world: BrickWorld,
		library: PartLibrary, skip: Dictionary, steps: PackedInt32Array = PackedInt32Array(),
		paths: PackedStringArray = PackedStringArray()) -> Array[Step]:
	var lowest: Dictionary = AuthorSteps.lowest_under(world, skip)
	var first: Dictionary = AuthorSteps.first_under(world, skip)
	var stepped: Array[Node2] = []
	var unstepped: Array[Node2] = []
	var path_of: Dictionary = {}
	var step_of: Dictionary = {}
	var read: bool = steps.size() == nodes.size() and paths.size() == nodes.size()
	for index: int in nodes.size():
		var node: Node2 = nodes[index]
		var brick: BrickWorld.Brick = null if read else world.get_brick(node.id)
		var step: int = steps[index] if read else brick.step
		if step < 0:
			# A copy, which what is worked out for it below changes: the
			# node is kept, as read, for the next plan (_shaped).
			var own := Node2.new()
			own.take(node)
			unstepped.append(own)
			continue
		stepped.append(node)
		path_of[node.id] = paths[index] if read else Assemblies.path_of(brick)
		step_of[node.id] = step

	# The sub-assemblies built on the side: whole, every part of one stepped.
	var callouts: Array[Assembly] = []
	var in_callout: Dictionary = {}
	for made: Assembly in found:
		callouts.append(made)
		for member: Node2 in made.members:
			in_callout[member.id] = true

	# The author's steps, each by where it is: section|step -> entry.
	var entries: Dictionary = {}
	var entry_for := func(section: String, step: int) -> Dictionary:
		var id: String = "%s|%d" % [section, step]
		if not entries.has(id):
			entries[id] = {"section": section, "step": step, "nodes": [], "callouts": [],
				"key": AuthorSteps.key_of(world, section, step, lowest, first)}
		return entries[id]
	for node: Node2 in stepped:
		if not in_callout.has(node.id):
			(entry_for.call(str(path_of[node.id]), int(step_of[node.id]))["nodes"] as Array) \
				.append(node)
	for made: Assembly in callouts:
		var path: String = _path_of_key(made.key)
		var at: int = maxi(AuthorSteps.unit_step(world, path, lowest), 0)
		(entry_for.call(Assemblies.parent_of(path), at)["callouts"] as Array).append(made)
	var ordered: Array = entries.values()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return AuthorSteps.before(a["key"], b["key"]))

	var out: Array[Step] = []
	var number: int = 0
	var boxes: int = 0
	for entry: Dictionary in ordered:
		number += 1
		var last_attach: Step = null
		# Copies of one kind put on in one step are built once, "2x".
		var kinds: Dictionary = {}
		var made_list: Array = entry["callouts"]
		# In the order the step places them, as the file lists them.
		made_list.sort_custom(func(a: Assembly, b: Assembly) -> bool:
			return int(first.get(_path_of_key(a.key), 0)) < int(first.get(_path_of_key(b.key), 0)))
		for made: Assembly in made_list:
			if not kinds.has(made.kind):
				kinds[made.kind] = []
			(kinds[made.kind] as Array).append(made)
		for kind: String in kinds:
			boxes += 1
			last_attach = _authored_callout(kinds[kind], number, boxes, world, lowest, first,
				path_of, step_of, out)
			last_attach.authored_in = str(entry["section"])
			last_attach.authored_step = int(entry["step"])
		var loose: Array = entry["nodes"]
		if loose.is_empty():
			continue
		# The parts the step puts on as well, with the last sub-assembly it
		# puts on: one step, as the author made it.
		var step: Step = last_attach
		if step == null:
			step = Step.new()
			step.number = number
			step.authored_in = str(entry["section"])
			step.authored_step = int(entry["step"])
			out.append(step)
		# In the order the file had them, which is the author's too.
		loose.sort_custom(func(a: Node2, b: Node2) -> bool: return a.id < b.id)
		for node: Node2 in loose:
			_add(step, node)

	# What nobody gave a step, after the author's: worked out as a booklet's.
	if not unstepped.is_empty():
		var own: Dictionary = {}
		for node: Node2 in unstepped:
			own[node.id] = true
		for node: Node2 in unstepped:
			node.after = PackedInt64Array()
			for need: int in node.needs:
				if own.has(need):
					node.after.append(need)
			node.region = ""
		for chunk: Dictionary in _sequence(unstepped, false, _per_step(unstepped.size())):
			number += 1
			var step := Step.new()
			step.number = number
			step.unsupported = bool(chunk["unsupported"])
			for node: Node2 in chunk["nodes"]:
				_add(step, node)
			out.append(step)
	for index: int in out.size():
		out[index].index = index + 1
	return out


## A callout's key as a path: "Window#2" is one; "group:Gandalf" is the one
## copy of a group.
static func _path_of_key(key: String) -> String:
	return Assemblies.path_from(key.trim_prefix("group:"), "") if key.begins_with("group:") \
		else key


## The steps that build copies of one sub-assembly on the side, in the
## author's steps of each, and the step that puts them all on, added to
## [param out]. Returns that last one.
static func _authored_callout(copies: Array, number: int, box: int, world: BrickWorld,
		lowest: Dictionary, first_of: Dictionary, path_of: Dictionary, step_of: Dictionary,
		out: Array[Step]) -> Step:
	# Each copy's parts by their step within it, in order.
	var plans: Array = []
	for made: Assembly in copies:
		var depth: int = Assemblies.segments(_path_of_key(made.key)).size()
		var by_key: Dictionary = {}
		var keys: Array = []
		for member: Node2 in made.members:
			var full: Array = AuthorSteps.key_of(world, str(path_of[member.id]),
				int(step_of[member.id]), lowest, first_of)
			# Two numbers a level: the step it goes on in, and where.
			var inner: Array = full.slice(2 * depth)
			var id: String = str(inner)
			if not by_key.has(id):
				by_key[id] = []
				keys.append(inner)
			(by_key[id] as Array).append(member)
		keys.sort_custom(func(a: Array, b: Array) -> bool: return AuthorSteps.before(a, b))
		var chunks: Array = []
		for inner: Array in keys:
			var members: Array = by_key[str(inner)]
			members.sort_custom(func(a: Node2, b: Node2) -> bool: return a.id < b.id)
			chunks.append(members)
		plans.append(chunks)
	var first: Assembly = copies[0]
	var count: int = (plans[0] as Array).size()
	for at: int in count:
		var step := Step.new()
		step.number = number
		step.assembly = first.name
		step.figure = first.figure
		step.callout = box
		step.callout_step = at + 1
		step.callout_steps = count
		step.times = copies.size()
		for copy: int in plans.size():
			var chunks: Array = plans[copy]
			var taken: Array = [chunks[at]] if at < chunks.size() else []
			if at == count - 1 and chunks.size() > count:
				taken = chunks.slice(at)
			for members: Array in taken:
				for node: Node2 in members:
					_add(step, node)
					if copy == 0:
						step.shown_ids.append(node.id)
		var shown: Node2 = ((plans[0] as Array)[at] as Array)[0]
		step.authored_in = str(path_of[shown.id])
		step.authored_step = int(step_of[shown.id])
		out.append(step)
	var attach := Step.new()
	attach.number = number
	attach.assembly = first.name
	attach.figure = first.figure
	attach.callout = box
	attach.callout_steps = count
	attach.times = copies.size()
	for chunks: Array in plans:
		var ids := PackedInt64Array()
		for members: Array in chunks:
			for node: Node2 in members:
				ids.append(node.id)
		attach.copies.append(ids)
	out.append(attach)
	# Only where it was set: the sub-assemblies of the author's plan are
	# kept for the next (_assemblies_as_before), and only read.
	for made: Assembly in copies:
		if made.node != null:
			made.node = null
	return attach
