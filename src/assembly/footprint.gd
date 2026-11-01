## Where a part's footprint starts: the first cell of the studs it stands
## on, as the assistant names a placement (Assistant._corner_cell), for
## the core's own use.
##
## Opening a model asks it of every part that is off its studs (Seating,
## SeatOffer), and the start's own model has some: asked of the assistant,
## that loaded it before the first screen was up (Later). This is the
## core's copy of the assistant's rule, and tests/test_later.py fails when
## the two differ, line for line. See Assistant._corner_cell for why the
## footprint and not the cover, and the parts that showed it.
class_name Footprint
extends RefCounted

const STUD := 20.0

var builder: Builder
var library: PartLibrary

## Kept by part and then by the basis itself, as the assistant keeps it.
var _corner_cache: Dictionary = {}     ## part id -> {Basis: Vector3i}


func _init(of: Builder) -> void:
	builder = of
	library = of.library


## The cell a part's footprint starts at, turned by [param basis]: what
## x, y, z name when a part is placed.
func _corner_cell(part: Lbm.PartMesh, part_id: String, basis: Basis) -> Vector3i:
	var by_basis: Variant = _corner_cache.get(part_id)
	if by_basis == null:
		by_basis = {}
		_corner_cache[part_id] = by_basis
	var found: Variant = (by_basis as Dictionary).get(basis)
	if found != null:
		return found
	var lo: Vector3i = _work_out_corner(part, part_id, basis)
	(by_basis as Dictionary)[basis] = lo
	return lo


func _work_out_corner(part: Lbm.PartMesh, part_id: String, basis: Basis) -> Vector3i:
	# The corner and far corner of its cells, from its boxes (Builder._cell_span).
	var span: Array = builder._cell_span(part, Transform3D(basis, Vector3.ZERO))
	if span.is_empty():
		return Vector3i.ZERO
	var lo: Vector3i = span[0]
	var hi: Vector3i = span[1]
	# Upright or upside down only. On its side a part's height runs across,
	# and that is measured in plates, not studs. And not a minifigure's: a
	# skeleton's neck stud sits on a line and its arms reach past its legs,
	# and a figure is put together by its own transforms, not on studs.
	if absf((basis * Vector3.UP).y) > 0.99 and not _figure_part(part_id):
		lo.x = _footprint_start(part, basis, 0, lo.x, hi.x + 1)
		lo.z = _footprint_start(part, basis, 2, lo.z, hi.z + 1)
	return lo


## A minifigure's part or accessory, which stands on no stud grid.
func _figure_part(part_id: String) -> bool:
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	return info != null and info.family_category().begins_with("Minifig")


## The cell a part's footprint starts at along x (0) or z (2): its cover's
## first cell [param lo], moved to the nearest line of the part's own stud
## grid (Assistant._footprint_start says how, and why).
func _footprint_start(part: Lbm.PartMesh, basis: Basis, axis: int,
		lo: int, hi: int) -> int:
	var per: int = int(round(STUD / BrickLattice.CELL))
	var phases: Array[int] = []
	for kind: String in ["stud", "tube"]:
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != kind \
					or absf((basis * connector.axis).normalized().y) < 0.99:
				continue
			var at: int = int(round((basis * connector.position)[axis]
				/ BrickLattice.CELL))
			var middle: int = posmod(at - per / 2, per)
			phases = [middle, posmod(middle + per / 2, per)]
			break
		if not phases.is_empty():
			break
	if phases.is_empty():
		return lo
	# The stud's middle, unless the cover lies exactly on the other grid
	# and not on this one, which is what a jumper's does. Weighed any more
	# loosely the other grid won for a tap, whose spout leaves its cover
	# fitting neither.
	var fits: Array[int] = []
	for phase: int in phases:
		fits.append(absi(lo - _nearest_line(lo, phase, per, -1))
			+ absi(hi - _nearest_line(hi, phase, per, 1)))
	var phase: int = phases[1] if fits[1] == 0 and fits[0] > 0 else phases[0]
	return _nearest_line(lo, phase, per, -1)


## The line of a grid [param per] cells apart, offset [param phase], that
## is nearest [param at]; on a tie, the one on the [param out] side.
static func _nearest_line(at: int, phase: int, per: int, out: int) -> int:
	var below: int = at - posmod(at - phase, per)
	if below == at:
		return at
	var above: int = below + per
	if at - below < above - at or (at - below == above - at and out < 0):
		return below
	return above
