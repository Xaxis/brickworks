## Turning a selection into its mirror image: the other wing, the other
## side of a symmetrical front.
##
## A LEGO model is mostly symmetrical and built one side at a time; the
## second side is the first one reflected. A reflection is not something
## plastic can do, so each part is put where its reflection would be and
## turned so that it looks reflected — which, for a part that is
## symmetrical itself, it then is. A part made in a left and a right hand
## (a wing, a wedge plate, a door) is swapped for its other hand, found by
## its name; a part that is neither keeps its own shape, turned, and is
## counted so the person can be told.
class_name Mirror
extends RefCounted

static var _by_name: Dictionary = {}     ## tidy name -> part id
static var _indexed: PartLibrary = null
## Whether each part's shape is the same reflected across each of its own
## axes: PartMesh -> [method _symmetry].
static var _symmetric: Dictionary = {}
## The most a part's cover may be from the same either side of an axis and
## be read as the same ([method _odd_moments]).
const ODD_MOST := 0.02


## The part made the other way round, or "" if it is not a handed part.
static func counterpart(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info == null:
		return ""
	var name: String = Inventory._tidy(info.name)
	var swapped: String = _swap_hands(name)
	if swapped == name:
		return ""
	_index(library)
	return str(_by_name.get(swapped, ""))


static func _swap_hands(name: String) -> String:
	var words: PackedStringArray = name.split(" ")
	for n: int in words.size():
		match words[n]:
			"Left": words[n] = "Right"
			"Right": words[n] = "Left"
	return " ".join(words)


static func _index(library: PartLibrary) -> void:
	if _indexed == library:
		return
	_indexed = library
	_by_name.clear()
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or not info.reachable:
			continue
		var name: String = Inventory._tidy(info.name)
		# The first of several with one name: the plain part, which the
		# catalogue lists before its prints.
		if not _by_name.has(name):
			_by_name[name] = id


## Where a part goes and how it is turned, reflected across the plane at
## ``across`` square to world axis ``axis`` (0 for x, 2 for z). With
## [param shape], the part's own, the own axis flipped is one the part is
## the same either side of ([method _symmetry]).
static func reflected(at: Transform3D, axis: int, across: float,
		shape: Lbm.PartMesh = null) -> Transform3D:
	var flip := Basis.IDENTITY
	flip[axis] = -flip[axis]
	# Which of the part's own axes lies along the one being reflected: it
	# is flipped too, so the two flips make a turn and not a reflection.
	var own: int = 0
	var best: float = -1.0
	for n: int in 3:
		var along: float = absf((at.basis[n]).normalized()[axis])
		if along > best:
			best = along
			own = n
	# That turn looks like the reflection only when the part is the same
	# either side of that axis, as a brick is across. A wheel on an axle
	# along it is not: its face is not its back (its connectors say so), and
	# the left wheels of the car mirrored to the right faced in (mcphand,
	# 2026-10-31). It is the same either side of its axle, so one of those is
	# flipped instead: any axis the part is the same either side of gives
	# its mirror image.
	if shape != null and not _symmetry(shape)[own]:
		for n: int in [(own + 1) % 3, (own + 2) % 3]:
			if _symmetry(shape)[n] and _symmetry(shape)[n + 3]:
				own = n
				break
	var local := Basis.IDENTITY
	local[own] = -local[own]
	var basis: Basis = flip * at.basis * local
	var origin: Vector3 = at.origin
	origin[axis] = 2.0 * across - origin[axis]
	return Transform3D(BrickLattice.snap_basis(basis) if BrickLattice.is_square_to_grid(at.basis)
		else basis, origin)


## Whether a part is the same reflected in the plane square to each of its
## own axes: [x, y, z] by its connectors, each onto one alike, which are
## exact; then [x, y, z] by its cover (the lattice's boxes), which is
## coarse, so it only confirms. Kept a shape.
static func _symmetry(shape: Lbm.PartMesh) -> Array:
	var kept: Variant = _symmetric.get(shape)
	if kept == null:
		kept = []
		for n: int in 3:
			kept.append(_connectors_mirror(shape, n))
		for n: int in 3:
			kept.append(_odd_moments(shape, n) < ODD_MOST)
		_symmetric[shape] = kept
	return kept


## How far a part's cover is from the same either side of the plane square to
## own axis [param n], as its moments odd in that axis, each over the volume
## and the reach: 0 for a cover that is. Its boxes are no help one by one:
## a wheel's cover is laid in boxes one way, and its mirror image in others.
## Cells laid at 2 LDU leave a symmetrical part a little off: a wheel 0.011
## across its axle, a Technic beam 0.03 along its length.
static func _odd_moments(shape: Lbm.PartMesh, n: int) -> float:
	var volume: float = 0.0
	var odd := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])    ## x, x^3, x y, x z
	var a: int = (n + 1) % 3
	var b: int = (n + 2) % 3
	for box: AABB in shape.boxes:
		var size: Vector3 = box.size
		var low: Vector3 = box.position
		var high: Vector3 = box.end
		volume += size.x * size.y * size.z
		var across: float = size[a] * size[b]
		odd[0] += across * (high[n] * high[n] - low[n] * low[n]) * 0.5
		odd[1] += across * (pow(high[n], 4) - pow(low[n], 4)) * 0.25
		odd[2] += size[b] * (high[n] * high[n] - low[n] * low[n]) * 0.5 \
			* (high[a] * high[a] - low[a] * low[a]) * 0.5
		odd[3] += size[a] * (high[n] * high[n] - low[n] * low[n]) * 0.5 \
			* (high[b] * high[b] - low[b] * low[b]) * 0.5
	if volume <= 0.0:
		return 0.0
	var reach: Vector3 = (shape.bounds.position.abs()).max(shape.bounds.end.abs()) \
		.max(Vector3.ONE)
	return maxf(maxf(absf(odd[0]) / (volume * reach[n]),
		absf(odd[1]) / (volume * pow(reach[n], 3))),
		maxf(absf(odd[2]) / (volume * reach[n] * reach[a]),
		absf(odd[3]) / (volume * reach[n] * reach[b])))


## Whether each connector has one alike where its mirror image is.
static func _connectors_mirror(shape: Lbm.PartMesh, n: int) -> bool:
	var flip := Vector3.ONE
	flip[n] = -1.0
	# Each as a key, on a half-LDU grid: a baseplate's thousands of studs
	# are as quick to look up as a brick's eight.
	var connectors: Dictionary = {}
	for connector: Lbm.Connector in shape.connectors:
		connectors[_key([connector.position, connector.axis * 100.0], connector.kind
			+ connector.gender)] = true
	for connector: Lbm.Connector in shape.connectors:
		if not connectors.has(_key([connector.position * flip, connector.axis * flip * 100.0],
				connector.kind + connector.gender)):
			return false
	return true


static func _key(points: Array, kind: String = "") -> String:
	var said := PackedStringArray([kind])
	for point: Vector3 in points:
		said.append("%d,%d,%d" % [roundi(point.x * 2.0), roundi(point.y * 2.0),
			roundi(point.z * 2.0)])
	return "|".join(said)
