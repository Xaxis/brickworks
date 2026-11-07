## Turning a selection into its mirror image: the other wing, the other
## side of a symmetrical front.
##
## A LEGO model is mostly symmetrical and built one side at a time; the
## second side is the first one reflected. A reflection is not something
## plastic can do, so each part is put where its reflection would be and
## turned so that it is that reflection: a part that is its own mirror
## image some way round (a brick, a cheese slope, a headlight brick) is
## turned that way, and a part made in a left and a right hand (a wing, a
## wedge plate, a door) is swapped for its other hand, found by its name,
## and turned the way that lies on the reflection. A part that is neither
## keeps its own shape, turned as near its reflection as it goes, and is
## said so the person can be told ([method image]).
##
## Which way round is read off the part's shape, the corners of its
## surfaces, and its connectors. The same means as a person sees it: a
## part's file is not always its own mirror to the corner (an extra corner
## where a face is cut, a detail a fraction of an LDU off), so a part is
## its mirror image when all but a few of its corners in each colour lie on
## the reflection's; a print that reads the other way, or a hair parted on
## one side, does not. Read off its connectors, a headlight brick, whose face has
## none, was the same front and back, and a cheese slope, whose slope has
## none, the same both ways: on a car's pod mirrored over MCP the
## headlight faced in and the slope fell the wrong way, and the tool said
## it had mirrored them (seeing2, 2026-11-06).
class_name Mirror
extends RefCounted

static var _by_name: Dictionary = {}     ## tidy name -> its part ids, in the catalogue's order
static var _other_hand: Dictionary = {}  ## part id -> its other hand's, each the other's
static var _indexed: PartLibrary = null
## The 24 turns of a part's own axes that reflect it: each axis onto an
## axis, either way, the whole a reflection. One of them after the mirror's
## reflection is a turn, and it lays the part on its reflection when the
## part's shape is the same so reflected.
static var _flips: Array[Basis] = _reflections()
## What each part's shape was found to lie on reflected: its PartMesh ->
## the PartMesh of the part it is made into -> [method _weighed]. Read and
## written under [member _lock]: a part read off a file is made its other
## hand wherever the file is read.
static var _found: Dictionary = {}
static var _lock: Mutex = Mutex.new()
## Corners less than a cell apart, LDU, are one corner.
const CELL := 0.125
## How far, LDU, a corner may be from where a reflection puts another and
## be the same: a part's file keeps its corners to 1/64 LDU.
const NEAR := 0.02
## How much bigger one part's box may be than another's either way, LDU,
## and be the same box.
const BOX_NEAR := 0.1
## The share of a part's corners in each colour that must lie on its
## reflection's for it to be that reflection: 2401, a 10 x 10 plate cut
## across a corner, has its cut 0.16 LDU off its own diagonal on 6 corners,
## and 1750's curved bottom a lip 0.5 LDU lower on one side, and either is
## its own mirror image to anyone's eye; a print's letters read backwards
## lay a quarter of that colour's corners or more off.
const SAME := 0.98
## How many of a part's corners its nearest pose is weighed by, when it has
## no mirror image.
const SAMPLE := 400


## Let go of every pair weighed: a run through every shape the bin offers
## holds no more of them than memory does.
static func forget() -> void:
	_lock.lock()
	_found.clear()
	_lock.unlock()


## The part made the other way round, or "" if it is not a handed part:
## the one named so, and of several named so, the one whose number is
## nearest its own, each of a pair the other's. Taken as the first named
## so, 3816b, a right leg, was mirrored into 3817, a left leg of another
## mould, and that back into 3816, and 67 parts so came back as another
## (mirrorfix's run over the bin).
static func counterpart(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null:
		return ""
	var name: String = Inventory._tidy(info.name)
	var swapped: String = _swap_hands(name)
	if swapped == name:
		return ""
	_lock.lock()
	_index(library)
	var other: String = str(_other_hand.get(part_id, ""))
	if other.is_empty():
		# A part the bin does not offer (a retired number), as the nearest.
		var nearest: int = 1 << 30
		for each: String in _by_name.get(swapped, PackedStringArray()) as PackedStringArray:
			var apart: int = _letters_apart(part_id, each)
			if apart < nearest:
				nearest = apart
				other = each
	_lock.unlock()
	return other


static func _swap_hands(name: String) -> String:
	var words: PackedStringArray = name.split(" ")
	for n: int in words.size():
		match words[n]:
			"Left": words[n] = "Right"
			"Right": words[n] = "Left"
	return " ".join(words)


## Called under [member _lock].
static func _index(library: PartLibrary) -> void:
	if _indexed == library:
		return
	_indexed = library
	_by_name.clear()
	_other_hand.clear()
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or not info.reachable:
			continue
		var name: String = Inventory._tidy(info.name)
		var ids: PackedStringArray = _by_name.get(name, PackedStringArray())
		ids.append(id)
		_by_name[name] = ids
	for name: String in _by_name:
		var swapped: String = _swap_hands(name)
		# Each pair of names once, the same whichever is read first.
		if swapped > name and _by_name.has(swapped):
			_pair(_by_name[name], _by_name[swapped])


## Pairs the parts of one name with those of its other hand's, the nearest
## numbers first (3816b with 3817b, 11477d11 with 11477d12), then the
## catalogue's order; a part left over takes the nearest, whose pair is
## another.
static func _pair(one: PackedStringArray, other: PackedStringArray) -> void:
	var ways := PackedInt64Array()
	for i: int in one.size():
		for j: int in other.size():
			ways.append((_letters_apart(one[i], other[j]) << 40) | (i << 20) | j)
	ways.sort()
	for way: int in ways:
		var a: String = one[(way >> 20) & 0xFFFFF]
		var b: String = other[way & 0xFFFFF]
		if not _other_hand.has(a) and not _other_hand.has(b):
			_other_hand[a] = b
			_other_hand[b] = a
	for way: int in ways:
		var a: String = one[(way >> 20) & 0xFFFFF]
		var b: String = other[way & 0xFFFFF]
		if not _other_hand.has(a):
			_other_hand[a] = b
	for way: int in ways:
		var a: String = one[(way >> 20) & 0xFFFFF]
		var b: String = other[way & 0xFFFFF]
		if not _other_hand.has(b):
			_other_hand[b] = a


## How many letters one part number differs from another by: those to
## change, add or take away.
static func _letters_apart(one: String, other: String) -> int:
	var row := PackedInt32Array()
	for j: int in other.length() + 1:
		row.append(j)
	for i: int in one.length():
		var diagonal: int = row[0]
		row[0] = i + 1
		for j: int in other.length():
			var above: int = row[j + 1]
			row[j + 1] = mini(mini(above, row[j]) + 1, diagonal + (0 if one[i] == other[j] else 1))
			diagonal = above
	return row[other.length()]


## What a mirror says of the [param count] parts it made that have no mirror
## image, [param named] (each part, or each kind with how many): never said
## as done, since a part made in one hand only, the same no way round, is not
## its reflection however it is turned. The first 12 named. Said alike by
## mirror_parts (HandTools) and a design's mirror pattern (Assistant).
static func said_without_image(named: PackedStringArray, count: int) -> String:
	var lone: PackedStringArray = named
	if lone.size() > 12:
		lone = lone.slice(0, 12)
		lone.append("and %d more" % (named.size() - 12))
	return ("%s no mirror image: %s. %s not the same any way round, and the library "
		+ "has no part named as %s other hand, so %s turned as near the reflection as %s; "
		+ "look at %s, and swap or rebuild %s if the reflection matters there.") % [
		"1 part has" if count == 1 else "%d parts have" % count,
		", ".join(lone), "It is" if count == 1 else "They are",
		"its" if count == 1 else "their", "it is" if count == 1 else "they are",
		"it goes" if count == 1 else "they go", "it" if count == 1 else "them",
		"it" if count == 1 else "them"]


## [param part_id] at [param at], reflected across the plane at [param across]
## square to world axis [param axis] (0 for x, 2 for z): {"part": the part
## that is its reflection, its other hand where it has one; "at": where that
## goes and how it is turned; "exact": whether it is the reflection or its
## other hand, false for a part that has no mirror image, turned as near it
## as it goes}. Its other hand is the one a builder reaches for even where
## its shape is not the reflection to the corner: a sticker for the right
## side whose letters read the same way, a print each side of a car. With
## [param held], its other hand only when that is here to put down now.
## Turned by its shape when that is here, and as a part the same either
## side of its own axis along the mirror's when it is not yet (a web page
## reading a file before fetching its parts).
static func image(library: PartLibrary, part_id: String, at: Transform3D, axis: int,
		across: float, held: bool = false) -> Dictionary:
	var part: String = part_id
	var other: String = counterpart(library, part_id)
	if not other.is_empty() and (library.mesh_for(other) != null if held
			else library.parts.has(other)):
		part = other
	var placed: Dictionary = reflected(library.mesh_for(part_id), library.mesh_for(part), at,
		axis, across)
	placed["part"] = part
	placed["exact"] = bool(placed["exact"]) or part != part_id
	return placed


## [param shape] at [param at] reflected across the plane at [param across]
## square to world axis [param axis], as [param made], the same shape or its
## other hand: {"at": where made goes and how it is turned, "exact": whether
## it is then the reflection}. Either shape null, as a part the same either
## side of its own axis along the mirror's.
static func reflected(shape: Lbm.PartMesh, made: Lbm.PartMesh, at: Transform3D, axis: int,
		across: float) -> Dictionary:
	var turn: Dictionary = _turn(shape, made, at.basis, axis)
	var flip := Basis.IDENTITY
	flip[axis] = -flip[axis]
	var basis: Basis = flip * at.basis * (turn["turn"] as Basis)
	var origin: Vector3 = at.origin
	origin[axis] = 2.0 * across - origin[axis]
	# The part's own middle where the reflection's is, for a part whose
	# shape is the same either side of a plane not through its origin.
	origin += flip * at.basis * (turn["shift"] as Vector3)
	if BrickLattice.is_square_to_grid(at.basis):
		basis = BrickLattice.snap_basis(basis)
	return {"at": Transform3D(basis, origin), "exact": turn["exact"]}


## How [param made] is turned in its own axes to lie on [param shape] at
## [param basis] reflected across world axis [param axis]: {"turn": a turn
## of its axes that reflects them, "shift": where its middle goes in the
## shape's own axes, "exact": whether it then lies on the reflection}. Of
## the turns that do, the one with the fewest corners off; then one that
## lays each connector on one pointing the same way, a wheel's hub on its
## hub's side, so it faces out: the car's left tyres, the same either side
## of their axle but for their tread, were turned so on the right as its
## author laid them (mcphand); then the one nearest flipping only the own
## axis along the mirror's, which leaves a brick square to the mirror as it
## was: a part mirrored back comes back as it was.
##
## Where none does, the turn that lays the most of either part on the
## other, of the turns that are their own undoing (a reflection across a
## plane through the part's middle, or through the middle itself): mirrored
## back, the part is weighed the same, takes the same turn, and comes back
## where it was. Weighed one way and nearest the plain flip, 109 prints,
## stickers and halves of a pair came back turned some other way (mirrorfix's
## run over the bin). Of those as near, the one laying its connectors
## pointing the same way, then the plain flip, then the first.
static func _turn(shape: Lbm.PartMesh, made: Lbm.PartMesh, basis: Basis, axis: int) -> Dictionary:
	var own: int = 0
	var best: float = -1.0
	for n: int in 3:
		var along: float = absf((basis[n]).normalized()[axis])
		if along > best:
			best = along
			own = n
	var plain := Basis.IDENTITY
	plain[own] = -plain[own]
	var weighed: Dictionary = _weighed(shape, made)
	if weighed.is_empty():
		return {"turn": plain, "shift": Vector3.ZERO, "exact": true}
	var off: PackedInt32Array = weighed["off"]
	var near: PackedFloat32Array = weighed["near"]
	var ways: PackedByteArray = weighed["ways"]
	var pick: int = -1
	for n: int in _flips.size():
		if off[n] < 0:
			continue
		if pick < 0 or off[n] < off[pick] or (off[n] == off[pick]
				and _before(n, pick, own, ways)):
			pick = n
	var exact: bool = pick >= 0
	if not exact:
		pick = _nearest(near, ways, _flips.find(plain))
	var turn: Basis = _flips[pick]
	return {"turn": turn, "exact": exact,
		"shift": (weighed["middle"] as Vector3) - turn * (weighed["made_middle"] as Vector3)}


## Of the flips that are their own undoing, the one laying the most of the
## part on the other ([param near], weighed both ways, -1 for the rest); of
## those as near, the one laying its connectors pointing the same way
## ([param ways]), then [param plain], then the first. Each step reads the
## same weighed from either part, so the part mirrored back takes the same
## flip: the plain flip is the same flip after it.
static func _nearest(near: PackedFloat32Array, ways: PackedByteArray, plain: int) -> int:
	var top: float = -1.0
	for n: int in _flips.size():
		top = maxf(top, near[n])
	var pick: int = -1
	for n: int in _flips.size():
		if near[n] < top - 0.0001:
			continue
		if pick < 0 or ways[n] > ways[pick] or (ways[n] == ways[pick] and n == plain):
			pick = n
	return pick


## Whether flip [param n] goes before [param pick], the two laying as much
## of the part on its reflection: the one laying its connectors pointing
## the same way ([param ways]), then the one nearer the plain flip.
static func _before(n: int, pick: int, own: int, ways: PackedByteArray) -> bool:
	if ways[n] != ways[pick]:
		return ways[n] > ways[pick]
	return _nearness(own, n) > _nearness(own, pick)


## How near flip [param n] is to flipping own axis [param own] alone.
static func _nearness(own: int, n: int) -> float:
	var flip: Basis = _flips[n]
	return flip[0][0] + flip[1][1] + flip[2][2] - 2.0 * flip[own][own]


## Which of [member _flips] lay [param made] on [param shape] reflected:
## {"off": per flip how many corners of either, in its colour, lie on none
## of the other's, -1 when more than all but SAME of a colour's do or a
## connector lies on none alike; "near": per flip that is its own undoing
## the share of either's corners it lays on the other's, both ways added,
## and 1 more for the same box, -1 for every other flip, read only when
## every flip is -1; "ways": per flip 1 when every
## connector lies on one alike pointing the same way, a round read from its
## start ([method _connector_cells] pointing); "middle",
## "made_middle": each part's middle, its corners' box's, which a flip
## turns about}. Empty without both shapes, or off the main thread for a
## pair not weighed yet: their corners are the renderer's.
static func _weighed(shape: Lbm.PartMesh, made: Lbm.PartMesh) -> Dictionary:
	if shape == null or made == null:
		return {}
	_lock.lock()
	var kept: Variant = (_found.get(shape, {}) as Dictionary).get(made)
	_lock.unlock()
	if kept != null:
		return kept
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {}
	var mine: Dictionary = _corners(shape)
	var theirs: Dictionary = mine if made == shape else _corners(made)
	var studs: Dictionary = _connector_cells(shape, mine["middle"])
	var made_studs: Dictionary = studs if made == shape else _connector_cells(made, theirs["middle"])
	var pointing: Dictionary = _connector_cells(shape, mine["middle"], true)
	var made_pointing: Dictionary = pointing if made == shape \
		else _connector_cells(made, theirs["middle"], true)
	var ways := PackedByteArray()
	ways.resize(_flips.size())
	for n: int in _flips.size():
		var flip: Basis = _flips[n]
		ways[n] = 1 if _connectors_lie(flip, made_pointing, pointing) \
			and _connectors_lie(flip.transposed(), pointing, made_pointing) else 0
	var off := PackedInt32Array()
	off.resize(_flips.size())
	off.fill(-1)
	var any: bool = false
	for n: int in _flips.size():
		var flip: Basis = _flips[n]
		if not (_same_box(flip, theirs["size"], mine["size"])
				and _connectors_lie(flip, made_studs, studs)
				and _connectors_lie(flip.transposed(), studs, made_studs)):
			continue
		var there: int = _off(flip, theirs, mine)
		var back: int = _off(flip.transposed(), mine, theirs) if there >= 0 else -1
		if back >= 0:
			off[n] = there + back
			any = true
	var near := PackedFloat32Array()
	near.resize(_flips.size())
	near.fill(-1.0)
	if not any:
		for n: int in _flips.size():
			var flip: Basis = _flips[n]
			if flip != flip.transposed():
				continue
			near[n] = _share(flip, theirs, mine) + _share(flip, mine, theirs) \
				+ (1.0 if _same_box(flip, theirs["size"], mine["size"]) else 0.0)
	var weighed: Dictionary = {"off": off, "near": near, "ways": ways, "middle": mine["middle"],
		"made_middle": theirs["middle"]}
	_lock.lock()
	if not _found.has(shape):
		_found[shape] = {}
	(_found[shape] as Dictionary)[made] = weighed
	_lock.unlock()
	return weighed


## A part's corners: {"middle", "size": their box's; "cells": colour ->
## {Vector3i: true}, each corner as the cell it is in, CELL LDU a side,
## counted from the middle; "near": colour -> the cells a corner NEAR from
## its cell's side is in too}. A part with no corners to read has the box
## its file gives and none.
static func _corners(shape: Lbm.PartMesh) -> Dictionary:
	var lists: Array = []
	var low := Vector3.INF
	var high := -Vector3.INF
	for n: int in maxi(shape.surfaces.size(), shape.arrays.size()):
		var colour: int = shape.surface_colors[n] if n < shape.surface_colors.size() else 16
		var arrays: Array = shape.surfaces[n].surface_get_arrays(0) \
			if n < shape.surfaces.size() and shape.surfaces[n].get_surface_count() > 0 \
			else (shape.arrays[n] if n < shape.arrays.size() else [])
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for point: Vector3 in points:
			low = low.min(point)
			high = high.max(point)
		lists.append([colour, points])
	if lists.is_empty():
		return {"middle": shape.bounds.get_center(), "size": shape.bounds.size, "cells": {},
			"near": {}}
	var middle: Vector3 = (low + high) * 0.5
	var cells: Dictionary = {}
	var near: Dictionary = {}
	var reach: float = NEAR / CELL
	for list: Array in lists:
		var colour: int = list[0]
		if not cells.has(colour):
			cells[colour] = {}
			near[colour] = {}
		var mine: Dictionary = cells[colour]
		var close: Dictionary = near[colour]
		for point: Vector3 in list[1] as PackedVector3Array:
			var at: Vector3 = (point - middle) / CELL
			mine[Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))] = true
			for x: int in range(roundi(at.x - reach), roundi(at.x + reach) + 1):
				for y: int in range(roundi(at.y - reach), roundi(at.y + reach) + 1):
					for z: int in range(roundi(at.z - reach), roundi(at.z + reach) + 1):
						close[Vector3i(x, y, z)] = true
	return {"middle": middle, "size": high - low, "cells": cells, "near": near}


## How many corners of [param from] turned by [param flip] lie on no
## corner of [param onto] in their colour; -1 once more than all but SAME
## of one colour's do.
static func _off(flip: Basis, from: Dictionary, onto: Dictionary) -> int:
	var into: Dictionary = onto["near"]
	var off: int = 0
	for colour: int in from["cells"]:
		var cells: Dictionary = from["cells"][colour]
		var close: Dictionary = into.get(colour, {})
		var allowed: int = floori(cells.size() * (1.0 - SAME))
		var here: int = 0
		for cell: Vector3i in cells:
			if not close.has(Vector3i(flip * Vector3(cell))):
				here += 1
				if here > allowed:
					return -1
		off += here
	return off


## The share of [param from]'s corners, SAMPLE of them spread through it,
## that [param flip] lays on a corner of [param onto] in its colour.
static func _share(flip: Basis, from: Dictionary, onto: Dictionary) -> float:
	var total: int = 0
	for colour: int in from["cells"]:
		total += (from["cells"][colour] as Dictionary).size()
	if total == 0:
		return 1.0
	var stride: int = maxi(1, total / SAMPLE)
	var into: Dictionary = onto["near"]
	var seen: int = 0
	var laid: int = 0
	var n: int = 0
	for colour: int in from["cells"]:
		var close: Dictionary = into.get(colour, {})
		for cell: Vector3i in from["cells"][colour]:
			n += 1
			if n % stride != 0:
				continue
			seen += 1
			if close.has(Vector3i(flip * Vector3(cell))):
				laid += 1
	return float(laid) / float(maxi(seen, 1))


## Whether [param flip] turns a box [param size] into one [param onto].
static func _same_box(flip: Basis, size: Vector3, onto: Vector3) -> bool:
	var turned: Vector3 = (flip * size).abs()
	return absf(turned.x - onto.x) <= BOX_NEAR and absf(turned.y - onto.y) <= BOX_NEAR \
		and absf(turned.z - onto.z) <= BOX_NEAR


## A part's connectors about [param middle]: {"cells": [kind, cell, axis,
## whether a round] for each, "near": [kind, cell, axis] with the cells NEAR
## from its cell's side}. A
## shaft or a bore (a bar, a hole through) is a length of round, the same
## read from either end: its cell is its middle's and its axis either way
## ([method _either_way]). Read from its start, 2540's handle, a bar
## across a plate, was not the same either side. With [param pointing], a
## round is read from its start the way it points, as every other kind is.
static func _connector_cells(shape: Lbm.PartMesh, middle: Vector3,
		pointing: bool = false) -> Dictionary:
	var cells: Array = []
	var near: Dictionary = {}
	var reach: float = NEAR / CELL
	for connector: Lbm.Connector in shape.connectors:
		var kind: String = connector.kind + connector.gender
		var position: Vector3 = connector.position
		var axis := Vector3i((connector.axis * 100.0).round())
		var either: bool = Lbm.ROUNDS.has(connector.kind) and not pointing
		if either:
			kind = "%s%d" % [kind, roundi(connector.length * 4.0)]
			position += connector.axis * connector.length * 0.5
			axis = _either_way(axis)
		var at: Vector3 = (position - middle) / CELL
		cells.append([kind, Vector3i(roundi(at.x), roundi(at.y), roundi(at.z)), axis, either])
		for x: int in range(roundi(at.x - reach), roundi(at.x + reach) + 1):
			for y: int in range(roundi(at.y - reach), roundi(at.y + reach) + 1):
				for z: int in range(roundi(at.z - reach), roundi(at.z + reach) + 1):
					near[[kind, Vector3i(x, y, z), axis]] = true
	return {"cells": cells, "near": near}


## Whether every connector of [param from] turned by [param flip] lies on
## one alike of [param onto].
static func _connectors_lie(flip: Basis, from: Dictionary, onto: Dictionary) -> bool:
	var into: Dictionary = onto["near"]
	for each: Array in from["cells"]:
		var axis := Vector3i(flip * Vector3(each[2] as Vector3i))
		if not into.has([each[0], Vector3i(flip * Vector3(each[1] as Vector3i)),
				_either_way(axis) if each[3] else axis]):
			return false
	return true


## A round's [param axis] the same whichever end it is read from: its first
## component not 0 made more than 0.
static func _either_way(axis: Vector3i) -> Vector3i:
	if axis.x < 0 or (axis.x == 0 and (axis.y < 0 or (axis.y == 0 and axis.z < 0))):
		return -axis
	return axis


static func _reflections() -> Array[Basis]:
	var out: Array[Basis] = []
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for order: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		for signs: int in 8:
			var flip := Basis(
				axes[order[0]] * (-1.0 if signs & 1 else 1.0),
				axes[order[1]] * (-1.0 if signs & 2 else 1.0),
				axes[order[2]] * (-1.0 if signs & 4 else 1.0))
			if flip.determinant() < 0.0:
				out.append(flip)
	return out
