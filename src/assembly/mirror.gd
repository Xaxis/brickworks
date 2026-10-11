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
## ``across`` square to world axis ``axis`` (0 for x, 2 for z).
static func reflected(at: Transform3D, axis: int, across: float) -> Transform3D:
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
	var local := Basis.IDENTITY
	local[own] = -local[own]
	var basis: Basis = flip * at.basis * local
	var origin: Vector3 = at.origin
	origin[axis] = 2.0 * across - origin[axis]
	return Transform3D(BrickLattice.snap_basis(basis) if BrickLattice.is_square_to_grid(at.basis)
		else basis, origin)
