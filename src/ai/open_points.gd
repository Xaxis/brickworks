## Where a selection can take a part, and whether a part put down near it
## would fit and hold: the open studs, anti-studs, side studs, pin holes,
## bars and clips of the parts selected, and the placements that seat a
## part on them.
##
## The first real request about a selection (Orthanc's west horn, "more
## jagged spikes") spent 865 s and had 22 edits refused, 17 for an overlap
## and 5 for a part left afloat, while Claude searched for the studs of a
## horn laid in a section turned 25 degrees. Every one of those answers was
## already known to the app: the check reads where each stud is and which
## way it points, and what its tip reaches into. This says it before the
## edit rather than after, and after one that is refused says the nearest
## place the part does fit.
##
## The tests are the check's own rules, asked of one part at a time against
## the live lattice (Builder.lattice) rather than of a whole model: a part
## fits where none of its cells is another's, square in its section's own
## frame against its section-mates, and holds where a stud of its own
## reaches into another part, or another's into it, or a pin, axle, bar or
## clip joins them. Where both parts have an exact shape, the shapes decide
## as they do for the check (ExactCheck): a cover is whole cells with its
## studs cut away, so a stud pushed into another's solid is clear by covers.
## where_to_attach offered a 49668 on Orthanc's west horn with its tooth over
## the next stud of the wing it stood on, a lattice fit, and edit_selection
## refused it as the collision it is. The edit itself is still checked whole.
class_name OpenPoints
extends RefCounted

const STUD := 20.0
const PLATE := 8.0
## How far past a stud's base the check samples for what it holds
## (Assistant._studs_reaching_in), and how far under an anti-stud.
const TIP := 5.0
const UNDER := 2.0
## Kinds of connector worth naming, as a person says them.
const NAMES: Dictionary = {
	"stud": "stud", "anti-stud": "anti-stud", "pin_hole": "pin hole",
	"axle_hole": "axle hole", "pin": "pin", "axle": "axle", "bar": "bar",
	"clip": "clip", "ball": "ball", "socket": "socket",
}
## What goes into what, for whether a hole or a clip is taken.
const MATES: Dictionary = {
	"pin_hole": ["pin", "axle"], "axle_hole": ["axle"], "clip": ["bar"],
	"socket": ["ball"], "pin": ["pin_hole"], "axle": ["axle_hole", "pin_hole"],
	"bar": ["clip"], "ball": ["socket"],
}


## One place on a part where another joins it.
class Point extends RefCounted:
	var kind: String = "stud"
	## The part that carries it, by number, and what it is.
	var brick: int = 0
	var part: String = ""
	## Where, in the world, LDU, and which way it points out of the part.
	var at := Vector3.ZERO
	var way := Vector3.UP
	## The frame the part is laid in: a section's name, or "" for the
	## model's own square one. Its position and face in that frame.
	var section: String = ""
	var local_at := Vector3.ZERO
	var face: String = "up"
	## What is on it or in it, by number; 0 when it is free.
	var by: int = 0
	## Its number in a list, and on the picture.
	var number: int = 0


var assistant: Assistant
## The model as edit_model reads it, and its placements by brick id.
var model: Assistant.Model
var by_id: Dictionary = {}
## The parts by their exact shapes, as the check reads them: each brick
## standing near a part tried, read once ([member _item_of], brick id ->
## item), and each part tried, an item of its own.
var _exact := ExactCheck.new({}, 0)
var _item_of: Dictionary = {}


static func read(of: Assistant) -> OpenPoints:
	var points := OpenPoints.new()
	points.assistant = of
	points.model = of._model_from_world()
	for placement: Assistant.Placement in points.model.placements:
		if placement.id != 0:
			points.by_id[placement.id] = placement
	return points


## The frame a brick is laid in: its section, carried, or the world.
func frame_of(brick_id: int) -> Transform3D:
	var placement: Assistant.Placement = by_id.get(brick_id)
	if placement == null or placement.section.is_empty():
		return Transform3D.IDENTITY
	var section: Assistant.Section = model.sections.get(placement.section)
	return section.placed() if section != null else Transform3D.IDENTITY


func section_of(brick_id: int) -> String:
	var placement: Assistant.Placement = by_id.get(brick_id)
	return placement.section if placement != null else ""


## Every connection point of these bricks, free and taken.
func points_of(ids: Array) -> Array[Point]:
	var out: Array[Point] = []
	var lattice: BrickLattice = assistant.builder.lattice
	for raw: Variant in ids:
		var brick: BrickWorld.Brick = assistant.world.get_brick(int(raw))
		if brick == null:
			continue
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var at: Transform3D = brick.transform
		var frame: Transform3D = frame_of(brick.id)
		var section: String = section_of(brick.id)
		for connector: Lbm.Connector in mesh.connectors:
			var kind: String = connector.kind
			if kind == "stud" and connector.gender != "male":
				continue
			if kind == "shaft":
				# A round of a bar's size, which a clip or a hollow stud takes.
				if connector.radius > 4.5 or connector.length < 4.0:
					continue
				kind = "bar"
			elif not NAMES.has(kind):
				continue
			var point := _point(kind, brick, at * connector.position,
				(at.basis * connector.axis).normalized(), frame, section)
			if kind == "stud":
				point.by = _other_at(lattice, point.at + point.way * TIP, brick.id)
			out.append(point)
		# The hollows underneath that take a stud: the part's own record of
		# them, on its underside.
		var bottom: float = mesh.bounds.position.y
		for socket: Vector2 in mesh.sockets:
			var point := _point("anti-stud", brick, at * Vector3(socket.x, bottom, socket.y),
				(at.basis * Vector3.DOWN).normalized(), frame, section)
			point.by = _other_at(lattice, point.at + point.way * UNDER, brick.id)
			out.append(point)
	_mate_round_ones(out)
	return out


func _point(kind: String, brick: BrickWorld.Brick, at: Vector3, way: Vector3,
		frame: Transform3D, section: String) -> Point:
	var point := Point.new()
	point.kind = kind
	point.brick = brick.id
	point.part = brick.part_id
	point.at = at
	point.way = way
	point.section = section
	var back: Transform3D = frame.affine_inverse()
	point.local_at = back * at
	point.face = nearest_face(back.basis * way)
	return point


## Holes, pins, bars and clips are taken when something of the kind that
## goes in them lines up with them, as Joints matches them for the check.
func _mate_round_ones(points: Array[Point]) -> void:
	var round_ones: Array[Point] = []
	var box := AABB()
	for point: Point in points:
		if MATES.has(point.kind):
			box = AABB(point.at, Vector3.ZERO) if round_ones.is_empty() else box.expand(point.at)
			round_ones.append(point)
	if round_ones.is_empty():
		return
	var near: Array = []    ## [brick id, kind, at, way]
	var lattice: BrickLattice = assistant.builder.lattice
	var cells: PackedInt32Array = _box_cells(box.grow(STUD * 2.0))
	for other: int in lattice.near_bounds(cells):
		var brick: BrickWorld.Brick = assistant.world.get_brick(other)
		if brick == null:
			continue
		var mesh: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		for connector: Lbm.Connector in mesh.connectors:
			var kind: String = "bar" if connector.kind == "shaft" else connector.kind
			if MATES.has(kind):
				near.append([brick.id, kind, brick.transform * connector.position,
					(brick.transform.basis * connector.axis).normalized()])
	for point: Point in round_ones:
		var takes: Array = MATES[point.kind]
		for other: Array in near:
			if int(other[0]) == point.brick or not takes.has(other[1]):
				continue
			if Joints.lines_up(point.at, point.way, other[2], other[3]) \
					or Joints.lines_up(other[2], other[3], point.at, point.way):
				point.by = int(other[0])
				break


## The brick whose cells hold this point, other than [param own]; 0 for none.
static func _other_at(lattice: BrickLattice, point: Vector3, own: int) -> int:
	var found: int = lattice.brick_at(BrickLattice.to_cell(point))
	return 0 if found == own else found


## The face a direction is nearest, of the six.
static func nearest_face(way: Vector3) -> String:
	var best: String = "up"
	var most: float = -2.0
	for name: String in BrickLattice.FACE_AXIS:
		var d: float = way.dot(BrickLattice.FACE_AXIS[name])
		if d > most:
			most = d
			best = name
	return best


## A box in LDU as lattice boxes, for asking what is near it.
static func _box_cells(box: AABB) -> PackedInt32Array:
	var lo: Vector3i = BrickLattice.to_cell(box.position)
	var hi: Vector3i = BrickLattice.to_cell(box.end) + Vector3i.ONE
	return PackedInt32Array([lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])


# -- fitting a part --------------------------------------------------------


## Placements of [param part_id] seated on [param point] that fit and hold
## where the model now stands: every way round the part goes on it, each
## of its own anti-studs (or studs, for a point underneath) on that one.
## [param skip] are bricks the edit takes off or moves, which are not in
## the way; [param inside] the room it must keep to, when it has one.
func fits_on(point: Point, part_id: String, color: int, skip: Dictionary = {},
		inside: AABB = AABB(), most: int = 4, also: Array = []) -> Array[Assistant.Placement]:
	var out: Array[Assistant.Placement] = []
	var mesh: Lbm.PartMesh = assistant.library.mesh_for(part_id)
	if mesh == null or point.by != 0:
		return out
	if point.kind != "stud" and point.kind != "anti-stud":
		return out
	# Seated on a stud, the part's own up is the stud's way, and one of the
	# hollows under it is on the stud. Under an anti-stud, the part's up is
	# into it, and one of its studs is in it.
	var face: String = point.face if point.kind == "stud" \
		else nearest_face(-(frame_of(point.brick).basis.inverse() * point.way))
	var anchors: Array[Vector3] = []
	if point.kind == "stud":
		var bottom: float = mesh.bounds.position.y
		for socket: Vector2 in mesh.sockets:
			anchors.append(Vector3(socket.x, bottom, socket.y))
	else:
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and connector.axis.dot(Vector3.UP) > 0.99:
				anchors.append(connector.position)
	var seen: Dictionary = {}
	for rot: int in 4:
		var basis: Basis = BrickLattice.basis_for(face, rot)
		for anchor: Vector3 in anchors:
			var origin: Vector3 = point.local_at - basis * anchor
			var placement: Assistant.Placement = placement_at(part_id, color, mesh,
				Transform3D(basis, origin), face, rot, point.section)
			var key: String = "%s %d %s" % [placement.where(), rot, face]
			if seen.has(key):
				continue
			seen[key] = true
			var trial: Dictionary = test(placement, skip, also)
			if not bool(trial["fits"]) or (trial["held_by"] as Array).is_empty():
				continue
			if inside.has_volume() and not inside.grow(SelectionScope.SLACK).encloses(
					trial["box"] as AABB):
				continue
			out.append(placement)
			if out.size() >= most:
				return out
	return out


## A placement written the way edit_model reads one, for a part standing at
## [param square] in a frame: the section's, or the world's.
func placement_at(part_id: String, color: int, mesh: Lbm.PartMesh,
		square: Transform3D, face: String, rot: int, section: String) -> Assistant.Placement:
	var placement := Assistant.Placement.new()
	placement.part = part_id
	placement.color = color
	placement.face = face
	placement.rot = rot
	placement.section = section
	# To the nearest cell, not the one below: a stud read back through a
	# section's turn is at 73.9999 as often as at 74, and the cell below
	# sank the part a cell into the one it stands on.
	var cell := Vector3i(roundi(square.origin.x / BrickLattice.CELL),
		roundi(square.origin.y / BrickLattice.CELL), roundi(square.origin.z / BrickLattice.CELL))
	var want: Vector3i = cell + assistant._corner_cell(mesh, part_id, square.basis)
	var corner: Vector3 = BrickLattice.to_ldu(want)
	placement.x = snappedf(corner.x / STUD, 0.01)
	placement.y = snappedf(corner.y / PLATE, 0.01)
	placement.z = snappedf(corner.z / STUD, 0.01)
	return placement


## Where a placement stands in the world.
func world_of(placement: Assistant.Placement, mesh: Lbm.PartMesh) -> Transform3D:
	var section: Assistant.Section = model.sections.get(placement.section) \
		if not placement.section.is_empty() else null
	return assistant._transform(placement, mesh, section)


## One part, asked as the check would ask it: what it runs into and what
## holds it. {"fits", "hits": brick ids, "held_by": brick ids, "rests_on",
## "box": its box in LDU}. [param skip] are bricks taken off or moved, and
## [param also] other parts the same edit puts down, as [key, mesh, world
## transform, part id] with negative keys.
func test(placement: Assistant.Placement, skip: Dictionary = {},
		also: Array = []) -> Dictionary:
	var answer: Dictionary = {"fits": false, "hits": [], "held_by": [], "rests_on": 0,
		"box": AABB(), "known": false}
	var mesh: Lbm.PartMesh = assistant.library.mesh_for(placement.part)
	if mesh == null:
		return answer
	answer["known"] = true
	var section: Assistant.Section = model.sections.get(placement.section) \
		if not placement.section.is_empty() else null
	if not placement.section.is_empty() and section == null:
		return answer
	var at: Transform3D = assistant._transform(placement, mesh, section)
	var builder: Builder = assistant.builder
	var packed: PackedInt32Array = builder.boxes_for(mesh, at)
	answer["box"] = (at * mesh.bounds).abs()
	if (answer["box"] as AABB).position.y < -1.0:
		answer["hits"] = ["the ground"]
		return answer
	var me: int = _item(placement.part, at, placement.section)
	var also_items: Dictionary = {}    ## key in [param also] -> its item
	for one: Array in also:
		if one.size() > 3:
			also_items[int(one[0])] = _item(str(one[3]), one[2], "")
	var hits: Array = []
	var square: PackedInt32Array = PackedInt32Array()
	for other: int in builder.lattice.blockers_boxes(packed, 0, skip):
		if assistant.scenery.has(other):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(other)
		if brick == null:
			continue
		var theirs: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		# Square to each other in the section they share, as the check
		# asks it: a turned cover is rounded out, and two section-mates
		# that abut would read as meeting.
		if section != null and section_of(other) == placement.section:
			if square.is_empty():
				square = builder.boxes_for(mesh, assistant._square_transform(placement, mesh))
			var mate: Assistant.Placement = by_id.get(other)
			if mate != null and theirs != null:
				var own := BrickLattice.new()
				own.keeps_columns = false
				own.occupy_boxes(1, builder.boxes_for(theirs,
					assistant._square_transform(mate, theirs)))
				if not own.collides_boxes(square):
					continue
		if theirs != null and _joined(mesh, at, theirs, brick.transform, placement.part,
				brick.part_id):
			continue
		if theirs != null and assistant._seated(placement.part, at, brick.part_id,
				brick.transform):
			continue
		# Their exact shapes decide where both have one (ExactCheck.drop_cleared).
		if _clear(me, _standing_item(brick)):
			continue
		hits.append(other)
	var near: PackedInt64Array = builder.lattice.near_bounds(_grown(packed, 4))
	# And what the covers cannot see, as the check refuses it
	# (Assistant._exact_collisions): the studs cut out of a cover and pushed
	# into another's solid, and any overlap a joint forgave above that is not
	# inside the joint.
	for other: int in near:
		if hits.has(other) or skip.has(other) or assistant.scenery.has(other):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(other)
		if brick != null and _refused(me, _standing_item(brick), mesh, at, placement.part,
				assistant.library.mesh_for(brick.part_id), brick.transform, brick.part_id):
			hits.append(other)
	var extra := BrickLattice.new()
	extra.keeps_columns = false
	for one: Array in also:
		extra.occupy_boxes(int(one[0]), builder.boxes_for(one[1], one[2]))
	var met: Dictionary = {}
	for key: int in extra.blockers_boxes(packed):
		met[key] = true
		if not _clear(me, int(also_items.get(key, -1))):
			hits.append(key)
	for one: Array in also:
		if not met.has(int(one[0])) and one.size() > 3 and _refused(me,
				int(also_items.get(int(one[0]), -1)), mesh, at, placement.part, one[1], one[2],
				str(one[3])):
			hits.append(int(one[0]))
	answer["hits"] = hits
	answer["fits"] = hits.is_empty()
	answer["held_by"] = _held_by(mesh, at, packed, skip, also, extra, near, me, also_items)
	# Resting on something, which the check counts as held and calls loose.
	var floor_y: int = 0x7FFFFFFF
	for n: int in range(1, packed.size(), 6):
		floor_y = mini(floor_y, packed[n])
	var under := PackedInt32Array()
	for n: int in range(0, packed.size(), 6):
		if packed[n + 1] == floor_y:
			under.append_array(PackedInt32Array([packed[n], floor_y - 1, packed[n + 2],
				packed[n + 3], floor_y, packed[n + 5]]))
	for below: int in builder.lattice.blockers_boxes(under, 0, skip):
		if not assistant.scenery.has(below):
			answer["rests_on"] = below
			break
	if floor_y <= 0:
		answer["rests_on"] = -1
	return answer


## What holds a part standing at [param at]: a stud of its own reaching
## into another, another's reaching into it, or a pin, axle, bar or clip.
## [param near] are the bricks round it, and [param me] its exact item.
## Between two parts with exact shapes, only a connection of BrickNet's
## holds, as the check has it (Assistant._exact_unheld): a stud's tip in a
## cover's cell can be in a hollow that takes no stud, or in solid.
func _held_by(mesh: Lbm.PartMesh, at: Transform3D, packed: PackedInt32Array,
		skip: Dictionary, also: Array, extra: BrickLattice, near: PackedInt64Array,
		me: int, also_items: Dictionary) -> Array:
	var held: Dictionary = {}
	var lattice: BrickLattice = assistant.builder.lattice
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var tip: Vector3 = at * (connector.position + connector.axis.normalized() * TIP)
		var cell: Vector3i = BrickLattice.to_cell(tip)
		var into: int = lattice.brick_at(cell)
		if into != 0 and not skip.has(into) and not assistant.scenery.has(into):
			held[into] = true
		var into_new: int = extra.brick_at(cell)
		if into_new != 0:
			held[into_new] = true
	var mine := BrickLattice.new()
	mine.keeps_columns = false
	mine.occupy_boxes(1, packed)
	var entries: Array = [[0, at, mesh]]
	for other: int in near:
		if skip.has(other) or held.has(other):
			continue
		var brick: BrickWorld.Brick = assistant.world.get_brick(other)
		if brick == null:
			continue
		var theirs: Lbm.PartMesh = assistant.library.mesh_for(brick.part_id)
		if theirs == null:
			continue
		entries.append([other, brick.transform, theirs])
		if assistant.scenery.has(other):
			# The baseplate holds what is on it, and only then.
			continue
		if _reaches_into(theirs, brick.transform, mine):
			held[other] = true
	for one: Array in also:
		if not held.has(one[0]) and _reaches_into(one[1], one[2], mine):
			held[one[0]] = true
		entries.append([one[0], one[2], one[1]])
	for pair: Array in Joints.pairs(entries):
		if int(pair[0]) == 0 and int(pair[1]) != 0:
			held[pair[1]] = true
		elif int(pair[1]) == 0 and int(pair[0]) != 0:
			held[pair[0]] = true
	var rounds: Dictionary = Joints.rounds(entries)
	for other: Variant in rounds.get(0, {}):
		if int(other) != 0:
			held[int(other)] = true
	if not _exact._shaped(me) or held.is_empty():
		return held.keys()
	var item_of: Dictionary = {}    ## holder -> its exact item, where it has a shape
	for key: Variant in held:
		var item: int = int(also_items.get(int(key), -1)) if int(key) < 0 \
			else _standing_item(assistant.world.get_brick(int(key)))
		if _exact._shaped(item):
			item_of[key] = item
	if item_of.is_empty():
		return held.keys()
	var joined: Dictionary = {}
	var only := PackedInt32Array([me])
	for key: Variant in item_of:
		only.append(int(item_of[key]))
	for edge: Array in Exact.connections(_exact.items, only):
		if int(edge[0]) == me or int(edge[2]) == me:
			joined[int(edge[2]) if int(edge[0]) == me else int(edge[0])] = true
	for key: Variant in item_of:
		if not joined.has(int(item_of[key])):
			held.erase(key)
	return held.keys()


# -- by their exact shapes ----------------------------------------------------


## A part as an item of the exact shapes, its index: one tried, at [param
## at] in [param section]. No shape where the part has none, or is one of
## the prism pattern's walls, which the check judges by their covers.
func _item(part_id: String, at: Transform3D, section: String) -> int:
	var shapes: Dictionary = _exact.shapes
	if not shapes.has(part_id):
		shapes[part_id] = Exact.shape_for(assistant.library, part_id)
	var index: int = _exact.items.size()
	_exact.parts.append(part_id)
	_exact.items.append(Exact.Item.new(shapes[part_id], at)
		if shapes[part_id] != null and not section.begins_with("prism ") else null)
	return index


## A brick standing as an item of the exact shapes, read once; -1 for none.
func _standing_item(brick: BrickWorld.Brick) -> int:
	if brick == null:
		return -1
	if not _item_of.has(brick.id):
		_item_of[brick.id] = _item(brick.part_id, brick.transform, section_of(brick.id))
	return _item_of[brick.id]


## Whether items [param one] and [param other] are clear by their exact
## shapes: false where either has none.
func _clear(one: int, other: int) -> bool:
	var found: Variant = _exact.between(one, other)
	return found is Dictionary and (found as Dictionary).is_empty()


## Whether the check refuses items [param one] and [param other] for their
## exact shapes, which their covers did not refuse: they overlap by more
## than a build allows, and not as a joint's own parts, a wheel spun on its
## axle (ExactCheck.forgiven) or gears in mesh do.
func _refused(one: int, other: int, one_mesh: Lbm.PartMesh, one_at: Transform3D,
		one_id: String, other_mesh: Lbm.PartMesh, other_at: Transform3D,
		other_id: String) -> bool:
	if not _exact._shaped(one) or not _exact._shaped(other):
		return false
	var a: Exact.Item = _exact.items[one]
	var b: Exact.Item = _exact.items[other]
	# Their boxes first, as ExactCheck.pairs_near asks it.
	if minf(a.hi.x, b.hi.x) - maxf(a.lo.x, b.lo.x) <= Exact.TAU \
			or minf(a.hi.y, b.hi.y) - maxf(a.lo.y, b.lo.y) <= Exact.TAU \
			or minf(a.hi.z, b.hi.z) - maxf(a.lo.z, b.lo.z) <= Exact.TAU:
		return false
	var found: Variant = _exact.between(one, other)
	if not (found is Dictionary) or (found as Dictionary).is_empty():
		return false
	if _exact.forgiven(one, other):
		return false
	return Joints.meshing([[1, one_at, one_mesh, one_id],
		[2, other_at, other_mesh, other_id]]).is_empty()


## Whether a stud of a part standing at [param at] reaches into the cells
## of [param into].
static func _reaches_into(mesh: Lbm.PartMesh, at: Transform3D, into: BrickLattice) -> bool:
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var tip: Vector3 = at * (connector.position + connector.axis.normalized() * TIP)
		if into.brick_at(BrickLattice.to_cell(tip)) != 0:
			return true
	return false


## Whether a pin, axle, bar or clip joins two parts, or they are gears in
## mesh, which the check forgives as it does a joint (Joints.meshing).
static func _joined(one: Lbm.PartMesh, one_at: Transform3D, two: Lbm.PartMesh,
		two_at: Transform3D, one_id: String = "", two_id: String = "") -> bool:
	var entries: Array = [[1, one_at, one, one_id], [2, two_at, two, two_id]]
	return not Joints.pairs(entries).is_empty() or not Joints.rounds(entries).is_empty() \
		or not Joints.meshing(entries).is_empty()


static func _grown(packed: PackedInt32Array, cells: int) -> PackedInt32Array:
	var lo := Vector3i(packed[0], packed[1], packed[2])
	var hi := Vector3i(packed[3], packed[4], packed[5])
	for n: int in range(6, packed.size(), 6):
		lo = Vector3i(mini(lo.x, packed[n]), mini(lo.y, packed[n + 1]), mini(lo.z, packed[n + 2]))
		hi = Vector3i(maxi(hi.x, packed[n + 3]), maxi(hi.y, packed[n + 4]),
			maxi(hi.z, packed[n + 5]))
	return PackedInt32Array([lo.x - cells, lo.y - cells, lo.z - cells,
		hi.x + cells, hi.y + cells, hi.z + cells])


## The nearest place to [param placement], in its own frame, where it
## fits and holds: a plate up or down, half a stud or a stud along, or
## both. Null when nothing within that reach does.
func nearest_fit(placement: Assistant.Placement, skip: Dictionary = {},
		also: Array = [], inside: AABB = AABB()) -> Assistant.Placement:
	var steps: Array = []
	for dy: int in range(-3, 4):
		for dx: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			for dz: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				if dy == 0 and dx == 0.0 and dz == 0.0:
					continue
				steps.append(Vector3(dx, dy, dz))
	steps.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector3(a.x * STUD, a.y * PLATE, a.z * STUD).length() \
			< Vector3(b.x * STUD, b.y * PLATE, b.z * STUD).length())
	for by: Vector3 in steps:
		var moved: Assistant.Placement = copy_of(placement)
		moved.x = snappedf(placement.x + by.x, 0.01)
		moved.y = snappedf(placement.y + by.y, 0.01)
		moved.z = snappedf(placement.z + by.z, 0.01)
		var trial: Dictionary = test(moved, skip, also)
		if bool(trial["fits"]) and not (trial["held_by"] as Array).is_empty():
			if inside.has_volume() and not inside.grow(SelectionScope.SLACK).encloses(
					trial["box"] as AABB):
				continue
			return moved
	return null


static func copy_of(placement: Assistant.Placement) -> Assistant.Placement:
	var out := Assistant.Placement.new()
	out.part = placement.part
	out.color = placement.color
	out.x = placement.x
	out.y = placement.y
	out.z = placement.z
	out.face = placement.face
	out.rot = placement.rot
	out.section = placement.section
	out.id = placement.id
	return out


# -- said -------------------------------------------------------------------


## A placement as edit_model and edit_selection take it, to copy as it is.
static func as_json(placement: Assistant.Placement) -> String:
	var out: Dictionary = {"part": placement.part, "color": placement.color,
		"x": placement.x, "y": placement.y, "z": placement.z, "face": placement.face,
		"rot": placement.rot}
	if not placement.section.is_empty():
		out["section"] = placement.section
	return JSON.stringify(out, "", false).replace(".0,", ",").replace(".0}", "}")


## Where a point is, in studs and plates, in the frame it was laid in.
static func where_of(point: Point) -> String:
	var at: Vector3 = point.local_at
	var said: String = "x=%s y=%s z=%s" % [_num(at.x / STUD), _num(at.y / PLATE),
		_num(at.z / STUD)]
	return said if point.section.is_empty() else "%s in '%s'" % [said, point.section]


static func _num(value: float) -> String:
	return Assistant.Placement._num(snappedf(value, 0.01))


## Which way a group of points looks, in words: the face in its frame and,
## for a turned one, where that is in the world.
static func heading(point: Point) -> String:
	if point.section.is_empty():
		return "pointing %s" % point.face
	var flat := Vector2(point.way.x, point.way.z)
	if flat.length() < 0.5:
		return "pointing %s in section '%s'" % [point.face, point.section]
	var nearest: String = nearest_face(point.way)
	var off: float = rad_to_deg((BrickLattice.FACE_AXIS[nearest] as Vector3).angle_to(point.way))
	return "pointing %s in section '%s' (in the world %d degrees round from %s)" % [
		point.face, point.section, roundi(off), nearest]
