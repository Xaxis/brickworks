## The lattice every brick sits on, and what is already on it.
##
## Everything here is integer. A position is a whole number of 2 LDU cells,
## a part's collision cover is a list of integer boxes, and an overlap test
## is integer comparison. There is no tolerance anywhere, so the same two
## bricks give the same answer every time and a model saved today loads
## identically tomorrow.
##
## 2 LDU is the coarsest cell that divides everything the system uses — the
## 20 LDU stud pitch, the 10 LDU half-pitch a jumper plate introduces, the
## 24 LDU brick and the 8 LDU plate. It has to survive a quarter turn,
## because a brick laid on its side is 24 LDU wide and 24 is not a multiple
## of 20; studs-not-on-top is half of how modern sets are built.
##
## Occupancy is kept as a sparse hash rather than a dense array. A model is
## mostly air — even a solid-looking build is a shell — and a dense grid
## big enough for a large layout would be hundreds of megabytes of nothing.
class_name BrickLattice
extends RefCounted

## LDU per cell. Must match tools/ldraw/occupancy.py.
const CELL := 2.0

const STUD := 20.0    ## LDU between stud centres
const PLATE := 8.0    ## LDU per plate
const BRICK := 24.0   ## LDU per brick, three plates

## How far past a whole unit a part may measure and still belong in it.
##
## Curved geometry overshoots its nominal box by a hair: a 2 x 2 round
## brick measures 40.001 LDU across where a square one measures 40.000.
## Rounded up, that is a part two studs wide described as three — which
## is how every round column, pillar and lamp in a model came to be
## listed with a stud of air around it. A design reading that leaves the
## gap.
##
## 0.4 LDU is the clearance LEGO designs to, 0.2 either side, so anything
## within it is the same stud. tools/ldraw/occupancy.py has guarded the
## same arithmetic since it was written; this side had not.
const CLEARANCE := 0.4

const CELLS_PER_STUD := 10    # 20 / 2
const CELLS_PER_PLATE := 4    # 8 / 2

## Cell -> brick id. One entry per occupied cell.
## brick id -> its world boxes, six ints each, high corner exclusive.
var _boxes: Dictionary = {}
## bucket -> the bricks with a box in it, so a query tests a handful.
var _bucket: Dictionary = {}
## The same, flattened to x and z, for "what is the top of this column".
var _column_bucket: Dictionary = {}
## brick id -> one box around all of its boxes, tested first so two
## bricks that are merely in the same bucket cost six comparisons.
var _bounds: Dictionary = {}


static func _bound_of(packed: PackedInt32Array) -> PackedInt32Array:
	if packed.is_empty():
		return packed
	var out := PackedInt32Array([packed[0], packed[1], packed[2],
		packed[3], packed[4], packed[5]])
	var n: int = 6
	while n < packed.size():
		out[0] = mini(out[0], packed[n])
		out[1] = mini(out[1], packed[n + 1])
		out[2] = mini(out[2], packed[n + 2])
		out[3] = maxi(out[3], packed[n + 3])
		out[4] = maxi(out[4], packed[n + 4])
		out[5] = maxi(out[5], packed[n + 5])
		n += 6
	return out
## Brick id -> PackedVector3Array of the cells it holds, for removal.
## Column (x, z) -> { y: how many cells are filled at that height }.
## Kept alongside the cell hash so "what is the surface here" is a lookup
## rather than a walk down four thousand empty cells.


## Which cell a point is in.
##
## Cell i is the half-open span [i * CELL, (i + 1) * CELL), which is
## what [method cells_for] and the occupancy hash both assume — so the
## answer is the floor, not the nearest.
##
## It was the nearest, which is a different question with the same
## shape: a point at 25 LDU is in cell 12, spanning 24 to 26, and
## rounding said 13. Everything that converts a cell-aligned position
## agrees either way, which is why this held for so long; what it got
## wrong is every point in between — where a ray struck, and where the
## tip of a stud lands.
static func to_cell(position: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(position.x / CELL)),
		int(floor(position.y / CELL)),
		int(floor(position.z / CELL)))


static func to_ldu(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL, cell.y * CELL, cell.z * CELL)


## The cells a part's collision cover occupies at a given placement.
##
## ``basis`` must be one of the 24 axis-aligned orientations; anything else
## would put a box's corners between cells and there would be no honest
## integer answer. [method snap_basis] gives the nearest legal one.
## How many cells a bucket spans on a side, for the coarse index that
## says which bricks are worth testing. Two studs: a 2x4 brick lands in
## about two of them, and a bucket in a dense model holds half a dozen
## bricks, so a query compares a handful of boxes rather than the model.
const BUCKET := 20


## The same spans as [method cells_for], kept as boxes instead of being
## expanded into every cell inside them.
##
## Six ints per box — low corner then high corner, the high exclusive —
## because that is what the cells were describing all along. cells_for
## works the world-space box out and then throws it away, and for a 2x4
## brick that turns one box into nine thousand six hundred cells. A
## model of eight thousand of them filled nine gigabytes, which is more
## than a browser will give the whole app, so the size of a model was
## capped by how its collision was stored rather than by anything about
## LEGO.
static func boxes_for(
	boxes: Array[AABB], origin_cell: Vector3i, basis: Basis
) -> PackedInt32Array:
	var out := PackedInt32Array()
	for box: AABB in boxes:
		var lo := Vector3(box.position)
		var hi := lo + Vector3(box.size)
		var a: Vector3 = basis * lo
		var b: Vector3 = basis * hi
		out.append(origin_cell.x + int(round(minf(a.x, b.x))))
		out.append(origin_cell.y + int(round(minf(a.y, b.y))))
		out.append(origin_cell.z + int(round(minf(a.z, b.z))))
		out.append(origin_cell.x + int(round(maxf(a.x, b.x))))
		out.append(origin_cell.y + int(round(maxf(a.y, b.y))))
		out.append(origin_cell.z + int(round(maxf(a.z, b.z))))
	return out


## The cells of a part that is not square to the grid, as boxes.
##
## A turned part has no box image, so its cells are worked out as before
## and then run-length merged along x. A 2x4 turned thirty degrees comes
## back as a few hundred runs instead of nine thousand six hundred cells,
## which is worth having even though sections are the only thing that
## turns.
static func boxes_for_turned(
	boxes: Array[AABB], origin_cell: Vector3i, basis: Basis
) -> PackedInt32Array:
	return compress(cells_for_turned(boxes, origin_cell, basis))


## Loose cells merged into runs along x.
static func compress(cells: Array[Vector3i]) -> PackedInt32Array:
	var out := PackedInt32Array()
	if cells.is_empty():
		return out
	var rows: Dictionary = {}       ## Vector2i(y, z) -> the x of each cell
	for cell: Vector3i in cells:
		var key := Vector2i(cell.y, cell.z)
		# Read out, appended to, put back. A PackedInt32Array is a value
		# in GDScript, so appending to what a Dictionary hands you
		# appends to a copy and the lattice comes back empty — which
		# reads as every collision and every support quietly vanishing.
		var xs: PackedInt32Array = rows.get(key, PackedInt32Array())
		xs.append(cell.x)
		rows[key] = xs
	## "x from, x to, z" -> the y it was found at, so layers that are the
	## same shape become one box instead of one box each.
	##
	## This matters only for turned parts, and it is the difference
	## between a usable number of boxes and an unusable one. A 2x4
	## turned about y has twelve identical layers: merged, forty boxes;
	## unmerged, four hundred and eighty, and comparing two of those is
	## a quarter of a million integer tests. The section probe stopped
	## finishing.
	var runs: Dictionary = {}
	for key: Vector2i in rows:
		var xs: PackedInt32Array = rows[key]
		xs.sort()
		var run_from: int = xs[0]
		var last: int = xs[0]
		for n: int in range(1, xs.size()):
			if xs[n] == last or xs[n] == last + 1:
				last = xs[n]
				continue
			_note_run(runs, run_from, last + 1, key.y, key.x)
			run_from = xs[n]
			last = xs[n]
		_note_run(runs, run_from, last + 1, key.y, key.x)

	for key: Vector3i in runs:
		var ys: PackedInt32Array = runs[key]
		ys.sort()
		var from_y: int = ys[0]
		var last_y: int = ys[0]
		for n: int in range(1, ys.size()):
			if ys[n] == last_y or ys[n] == last_y + 1:
				last_y = ys[n]
				continue
			out.append_array(PackedInt32Array([
				key.x, from_y, key.z, key.y, last_y + 1, key.z + 1]))
			from_y = ys[n]
			last_y = ys[n]
		out.append_array(PackedInt32Array([
			key.x, from_y, key.z, key.y, last_y + 1, key.z + 1]))
	return out


static func _note_run(runs: Dictionary, from_x: int, to_x: int,
		z: int, y: int) -> void:
	var key := Vector3i(from_x, to_x, z)
	var ys: PackedInt32Array = runs.get(key, PackedInt32Array())
	ys.append(y)
	runs[key] = ys


## The cells inside a set of boxes.
##
## For anything that still wants cells. Going this way round matters for
## a turned part: working its cover out tests every candidate cell
## against the turned box, and doing that once for the boxes and again
## for the cells runs the expensive half twice. The boxes already know
## the answer.
static func cells_in(packed: PackedInt32Array) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var n: int = 0
	while n < packed.size():
		for x: int in range(packed[n], packed[n + 3]):
			for y: int in range(packed[n + 1], packed[n + 4]):
				for z: int in range(packed[n + 2], packed[n + 5]):
					out.append(Vector3i(x, y, z))
		n += 6
	return out


static func cells_for(
	boxes: Array[AABB], origin_cell: Vector3i, basis: Basis
) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for box: AABB in boxes:
		# Rotate the box's two opposite corners and take the span between
		# them: for an axis-aligned rotation the image of a box is a box.
		var lo := Vector3(box.position)
		var hi := lo + Vector3(box.size)
		var a: Vector3 = basis * lo
		var b: Vector3 = basis * hi
		var from := Vector3i(
			int(round(minf(a.x, b.x))),
			int(round(minf(a.y, b.y))),
			int(round(minf(a.z, b.z))))
		var to := Vector3i(
			int(round(maxf(a.x, b.x))),
			int(round(maxf(a.y, b.y))),
			int(round(maxf(a.z, b.z))))
		for x: int in range(from.x, to.x):
			for y: int in range(from.y, to.y):
				for z: int in range(from.z, to.z):
					out.append(origin_cell + Vector3i(x, y, z))
	return out


## The six cells that share a face with a cell. Touching, rather than
## merely being near: two cells that meet only at an edge or a corner
## are two bricks passing, not two bricks joined.
const NEIGHBOURS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


## The twenty-six cells around a cell — faces, edges and corners.
##
## Touching, for something that is not square to the grid. Two cells
## that meet only at an edge are two bricks passing when both are on
## the grid, but a turned assembly meets a flat wall at a line or a
## corner and never squarely, so face-adjacency alone says a pylon
## resting against a hull is not touching it.
const AROUND: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(1, 1, 0), Vector3i(1, -1, 0), Vector3i(-1, 1, 0),
	Vector3i(-1, -1, 0), Vector3i(1, 0, 1), Vector3i(1, 0, -1),
	Vector3i(-1, 0, 1), Vector3i(-1, 0, -1), Vector3i(0, 1, 1),
	Vector3i(0, 1, -1), Vector3i(0, -1, 1), Vector3i(0, -1, -1),
	Vector3i(1, 1, 1), Vector3i(1, 1, -1), Vector3i(1, -1, 1),
	Vector3i(1, -1, -1), Vector3i(-1, 1, 1), Vector3i(-1, 1, -1),
	Vector3i(-1, -1, 1), Vector3i(-1, -1, -1),
]


## Whether an orientation is one of the twenty-four [method cells_for]
## can answer for exactly.
static func is_square_to_grid(basis: Basis) -> bool:
	return basis.is_equal_approx(snap_basis(basis))


## The cells a part fills when it is NOT square to the grid.
##
## [method cells_for] spans two rotated corners, which is the rotated
## box only for the twenty-four orientations it documents as its
## precondition. Anything else spans a diagonal, so the caller used to
## square the basis up first and a brick turned thirty degrees reserved
## exactly the cells of a brick turned none: nearly a stud of real
## plastic outside its own reservation, and empty air inside it. Overlap,
## floating and connectedness were all then answering about a shape that
## was not there — which is worse than refusing to answer, because it
## reads as a verdict.
##
## This walks the cells the turned box could reach and keeps the ones it
## actually touches. The test is the cell's centre against the box grown
## by the cell's own reach along each of the box's axes, which is the
## standard separating-axis test with the box's three axes: it can say
## yes to a cell the box only nearly touches, and never no to one it
## does. Over-reserving is the safe direction — it refuses a placement
## that would have fitted, rather than passing one that does not.
static func cells_for_turned(
	boxes: Array[AABB], origin_cell: Vector3i, basis: Basis
) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var taken: Dictionary = {}

	for box: AABB in boxes:
		var lo := Vector3(box.position)
		var hi := lo + Vector3(box.size)
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for n: int in 8:
			var corner: Vector3 = basis * Vector3(
				hi.x if n & 1 else lo.x,
				hi.y if n & 2 else lo.y,
				hi.z if n & 4 else lo.z)
			low = low.min(corner)
			high = high.max(corner)

		# The turned box, as a centre, three axes and three half-widths.
		var half: Vector3 = (hi - lo) * 0.5
		var middle: Vector3 = basis * ((lo + hi) * 0.5)
		for x: int in range(floori(low.x), ceili(high.x)):
			for y: int in range(floori(low.y), ceili(high.y)):
				for z: int in range(floori(low.z), ceili(high.z)):
					if not _touches(middle, basis, half, Vector3(
							float(x) + 0.5, float(y) + 0.5,
							float(z) + 0.5)):
						continue
					var cell: Vector3i = origin_cell + Vector3i(x, y, z)
					if taken.has(cell):
						continue
					taken[cell] = true
					out.append(cell)
	return out


## Whether a unit cell centred at [param at] is touched by the turned
## box given by its centre, its three axes and its three half-widths.
##
## The fifteen axes of a separating-axis test: the cell's three, the
## box's three, and the nine cross products. Anything less is an
## over-estimate, and the over-estimate is expensive here — measuring a
## turned part by a box grown along its own axes swells it by nearly a
## whole cell on every side, so a three-plate blade at an angle
## collided with everything it merely passed near. A design that had
## worked out a fifty-degree rake for its pylons hit exactly that,
## spent its remaining turns opening tenth-of-a-plate clearances by
## hand, and finished with nothing built.
static func _touches(middle: Vector3, basis: Basis, half: Vector3,
		at: Vector3) -> bool:
	var apart: Vector3 = middle - at
	var axes: Array[Vector3] = [
		Vector3.RIGHT, Vector3.UP, Vector3.BACK,
		basis[0].normalized(), basis[1].normalized(),
		basis[2].normalized()]
	for n: int in 3:
		for m: int in 3:
			var cross: Vector3 = axes[n].cross(axes[3 + m])
			if cross.length_squared() > 0.000001:
				axes.append(cross.normalized())

	var widths := PackedFloat32Array([half.x, half.y, half.z])
	for axis: Vector3 in axes:
		# Half the cell, projected: a unit cube reaches this far along
		# any direction.
		var cell_reach: float = 0.5 * (absf(axis.x) + absf(axis.y)
			+ absf(axis.z))
		var box_reach: float = 0.0
		for n: int in 3:
			box_reach += widths[n] * absf(axis.dot(basis[n].normalized()))
		if absf(apart.dot(axis)) > cell_reach + box_reach:
			return false
	return true


## Would a part placed here overlap anything already placed?
##
## ``ignore`` lets a brick being dragged not collide with itself.
func collides(cells: Array[Vector3i], ignore: int = 0) -> bool:
	return collides_boxes(compress(cells), ignore)


## Which bricks a placement would run into. Useful for telling someone why.
func blockers(cells: Array[Vector3i], ignore: int = 0) -> PackedInt64Array:
	return blockers_boxes(compress(cells), ignore)


## Whether to keep the column index that [method resting_height] reads.
##
## Keeping it is two thirds of what it costs to occupy a brick — 2.5
## seconds of the 3.8 it takes to place four hundred of them, and a third
## of the time it takes to check a design. Exactly one caller ever asks
## for it: the builder, working out where a brick would land under the
## pointer. The scratch lattices a design is checked against never do, so
## they turn it off and do not pay for it.
var keeps_columns: bool = true


## Put a brick in, as boxes.
func occupy_boxes(brick_id: int, packed: PackedInt32Array) -> void:
	_boxes[brick_id] = packed
	_bounds[brick_id] = _bound_of(packed)
	var seen: Dictionary = {}
	var n: int = 0
	while n < packed.size():
		var lo_x: int = packed[n]
		var lo_y: int = packed[n + 1]
		var lo_z: int = packed[n + 2]
		var hi_x: int = packed[n + 3]
		var hi_y: int = packed[n + 4]
		var hi_z: int = packed[n + 5]
		n += 6
		for bx: int in range(_floor_div(lo_x, BUCKET), _floor_div(hi_x - 1, BUCKET) + 1):
			for by: int in range(_floor_div(lo_y, BUCKET), _floor_div(hi_y - 1, BUCKET) + 1):
				for bz: int in range(_floor_div(lo_z, BUCKET), _floor_div(hi_z - 1, BUCKET) + 1):
					seen[Vector3i(bx, by, bz)] = true
	var flat: Dictionary = {}
	for key: Vector3i in seen:
		var here: PackedInt64Array = _bucket.get(key, PackedInt64Array())
		here.append(brick_id)
		_bucket[key] = here
		flat[Vector2i(key.x, key.z)] = true
	for key: Vector2i in flat:
		var column: PackedInt64Array = _column_bucket.get(key, PackedInt64Array())
		column.append(brick_id)
		_column_bucket[key] = column


## Which bricks these boxes would run into.
## [param skip] names bricks whose answer the caller already knows, and
## is consulted before the boxes are compared rather than after. A
## section asking what it runs into does not care about its own bricks,
## and comparing a turned brick with forty boxes against forty
## section-mates is sixty-four thousand tests to discard the lot.
func blockers_boxes(packed: PackedInt32Array, ignore: int = 0,
		skip: Dictionary = {}) -> PackedInt64Array:
	var found: Dictionary = {}
	var mine: PackedInt32Array = _bound_of(packed)
	for other: int in _near(packed):
		if other == ignore or skip.has(other):
			continue
		if not _overlaps(mine, _bounds.get(other, PackedInt32Array())):
			continue
		if _overlaps(packed, _boxes.get(other, PackedInt32Array())):
			found[other] = true
	return PackedInt64Array(found.keys())


func collides_boxes(packed: PackedInt32Array, ignore: int = 0) -> bool:
	var mine: PackedInt32Array = _bound_of(packed)
	for other: int in _near(packed):
		if other == ignore:
			continue
		if not _overlaps(mine, _bounds.get(other, PackedInt32Array())):
			continue
		if _overlaps(packed, _boxes.get(other, PackedInt32Array())):
			return true
	return false


## The bricks sharing a bucket with any of these boxes.
func _near(packed: PackedInt32Array) -> PackedInt64Array:
	var seen: Dictionary = {}
	var n: int = 0
	while n < packed.size():
		for bx: int in range(_floor_div(packed[n], BUCKET),
				_floor_div(packed[n + 3] - 1, BUCKET) + 1):
			for by: int in range(_floor_div(packed[n + 1], BUCKET),
					_floor_div(packed[n + 4] - 1, BUCKET) + 1):
				for bz: int in range(_floor_div(packed[n + 2], BUCKET),
						_floor_div(packed[n + 5] - 1, BUCKET) + 1):
					var here: Variant = _bucket.get(Vector3i(bx, by, bz))
					if here == null:
						continue
					for brick_id: int in here:
						seen[brick_id] = true
		n += 6
	return PackedInt64Array(seen.keys())


## Whether any box of one set meets any box of the other.
static func _overlaps(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	var i: int = 0
	while i < a.size():
		var j: int = 0
		while j < b.size():
			if a[i] < b[j + 3] and b[j] < a[i + 3] \
					and a[i + 1] < b[j + 4] and b[j + 1] < a[i + 4] \
					and a[i + 2] < b[j + 5] and b[j + 2] < a[i + 5]:
				return true
			j += 6
		i += 6
	return false


## Floor division that stays correct for negative coordinates, which a
## model below the baseplate has.
static func _floor_div(value: int, by: int) -> int:
	return (value - (by - 1)) / by if value < 0 else value / by


## Put a brick in, as loose cells. Kept for callers that still work in
## cells; they pay to have them merged into runs first.
func occupy(brick_id: int, cells: Array[Vector3i]) -> void:
	occupy_boxes(brick_id, compress(cells))


func release(brick_id: int) -> void:
	var packed: PackedInt32Array = _boxes.get(brick_id, PackedInt32Array())
	if packed.is_empty():
		_boxes.erase(brick_id)
		_bounds.erase(brick_id)
		return
	var seen: Dictionary = {}
	var n: int = 0
	while n < packed.size():
		for bx: int in range(_floor_div(packed[n], BUCKET),
				_floor_div(packed[n + 3] - 1, BUCKET) + 1):
			for by: int in range(_floor_div(packed[n + 1], BUCKET),
					_floor_div(packed[n + 4] - 1, BUCKET) + 1):
				for bz: int in range(_floor_div(packed[n + 2], BUCKET),
						_floor_div(packed[n + 5] - 1, BUCKET) + 1):
					seen[Vector3i(bx, by, bz)] = true
		n += 6
	var flat: Dictionary = {}
	for key: Vector3i in seen:
		var here: PackedInt64Array = _bucket.get(key, PackedInt64Array())
		var kept := PackedInt64Array()
		for other: int in here:
			if other != brick_id:
				kept.append(other)
		if kept.is_empty():
			_bucket.erase(key)
		else:
			_bucket[key] = kept
		flat[Vector2i(key.x, key.z)] = true
	for key: Vector2i in flat:
		var column: PackedInt64Array = _column_bucket.get(key, PackedInt64Array())
		var kept := PackedInt64Array()
		for other: int in column:
			if other != brick_id:
				kept.append(other)
		if kept.is_empty():
			_column_bucket.erase(key)
		else:
			_column_bucket[key] = kept
	_boxes.erase(brick_id)
	_bounds.erase(brick_id)


func brick_at(cell: Vector3i) -> int:
	var here: Variant = _bucket.get(Vector3i(
		_floor_div(cell.x, BUCKET), _floor_div(cell.y, BUCKET),
		_floor_div(cell.z, BUCKET)))
	if here == null:
		return 0
	for brick_id: int in here:
		var packed: PackedInt32Array = _boxes.get(brick_id, PackedInt32Array())
		var n: int = 0
		while n < packed.size():
			if cell.x >= packed[n] and cell.x < packed[n + 3] \
					and cell.y >= packed[n + 1] and cell.y < packed[n + 4] \
					and cell.z >= packed[n + 2] and cell.z < packed[n + 5]:
				return brick_id
			n += 6
	return 0


func occupied_cells() -> int:
	var total: int = 0
	for brick_id: int in _boxes:
		var packed: PackedInt32Array = _boxes[brick_id]
		var n: int = 0
		while n < packed.size():
			total += (packed[n + 3] - packed[n]) \
				* (packed[n + 4] - packed[n + 1]) \
				* (packed[n + 5] - packed[n + 2])
			n += 6
	return total


func clear() -> void:
	_boxes.clear()
	_bucket.clear()
	_column_bucket.clear()
	_bounds.clear()


## The height a part would rest at in this column: one cell above the
## highest thing in it, or ``floor_cell`` if the column is empty.
func surface_height(cell_x: int, cell_z: int, floor_cell: int = 0) -> int:
	# Asked of the boxes rather than of a stored column index. The index
	# held one entry per cell per column, which for a 2x4 brick is nine
	# thousand six hundred of them, and that is the other half of why a
	# large model would not fit in memory.
	var here: Variant = _column_bucket.get(Vector2i(
		_floor_div(cell_x, BUCKET), _floor_div(cell_z, BUCKET)))
	if here == null:
		return floor_cell
	var top: int = floor_cell
	for brick_id: int in here:
		var packed: PackedInt32Array = _boxes.get(brick_id, PackedInt32Array())
		var n: int = 0
		while n < packed.size():
			if cell_x >= packed[n] and cell_x < packed[n + 3] \
					and cell_z >= packed[n + 2] and cell_z < packed[n + 5] \
					and packed[n + 4] > top:
				top = packed[n + 4]
			n += 6
	return top


## The height a whole footprint would rest at: the highest surface under
## any of its columns, so a part laid across a step sits on the step.
func resting_height(
	columns: Array[Vector2i], floor_cell: int = 0
) -> int:
	var best: int = floor_cell
	for column: Vector2i in columns:
		var height: int = surface_height(column.x, column.y, floor_cell)
		if height > best:
			best = height
	return best


## The six ways a part's studs can point.
##
## Naming them by direction rather than by rotation is deliberate: the
## question a builder asks is "which way do the studs face", and the
## answer is a direction. Which rotation produces it is arithmetic, and
## arithmetic is what nobody should have to do to lay a brick on its
## side.
##
## In the order the builder cycles them, which is a part rolling forward
## about its own left-right axis and then round again.
const FACES: Array[String] = ["up", "+z", "down", "-z", "+x", "-x"]

const FACE_AXIS: Dictionary = {
	"up": Vector3.UP,
	"down": Vector3.DOWN,
	"+x": Vector3.RIGHT,
	"-x": Vector3.LEFT,
	"+z": Vector3.BACK,
	"-z": Vector3.FORWARD,
}


## The orientation a face and a quarter turn come to.
##
## The turn is about the part's own new up rather than the world's, so
## that rot means the same thing whichever way the part is facing: turn
## it on the spot.
static func basis_for(face: String, rot: int) -> Basis:
	var up: Vector3 = FACE_AXIS.get(face, Vector3.UP)
	var tip: Basis
	if up.is_equal_approx(Vector3.UP):
		tip = Basis.IDENTITY
	elif up.is_equal_approx(Vector3.DOWN):
		tip = Basis(Vector3.RIGHT, PI)
	else:
		tip = Basis(Vector3.UP.cross(up).normalized(), PI * 0.5)
	return snap_basis(Basis(up, rot * PI * 0.5) * tip)


## Which way the studs point, read back off an orientation.
static func face_of(basis: Basis) -> String:
	var up: Vector3 = (basis * Vector3.UP).normalized()
	var best: String = "up"
	var best_dot: float = -2.0
	for name: String in FACES:
		var d: float = up.dot(FACE_AXIS[name])
		if d > best_dot:
			best_dot = d
			best = name
	return best


## The turn that, with this face, reproduces this orientation.
##
## Found by trying all four rather than by trigonometry, because the
## four are the only answers there are and trying them cannot disagree
## with the rule that generated them.
static func turns_about(basis: Basis, face: String) -> int:
	var snapped: Basis = snap_basis(basis)
	for rot: int in 4:
		if basis_for(face, rot).is_equal_approx(snapped):
			return rot
	return 0


## The nearest of the 24 axis-aligned orientations.
##
## A brick can only be turned in quarter steps and still meet the lattice,
## so an arbitrary rotation is rounded to one that does. Each column of the
## basis becomes the axis it points most nearly along.
static func snap_basis(basis: Basis) -> Basis:
	var axes: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP,
		Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

	var columns: Array[Vector3] = []
	for n: int in 3:
		var column: Vector3 = basis[n].normalized()
		var best: Vector3 = axes[0]
		var best_dot: float = -2.0
		for axis: Vector3 in axes:
			var d: float = column.dot(axis)
			if d > best_dot:
				best_dot = d
				best = axis
		columns.append(best)

	var snapped := Basis(columns[0], columns[1], columns[2])
	# Rounding each column on its own can land two of them on the same
	# axis, which is not a rotation at all. Fall back rather than hand
	# back something degenerate.
	if absf(snapped.determinant() - 1.0) > 0.01:
		return Basis.IDENTITY
	return snapped


## Snap a position to the stud lattice, keeping the part's own phase.
##
## The phase matters: a brick two studs wide puts its studs at odd
## multiples of 10 LDU and a brick one stud wide puts its stud at zero, so
## rounding to the nearest multiple of 20 is right for one and wrong for
## the other. Passing the part's footprint in studs picks the right one.
static func snap_to_studs(position: Vector3, footprint: Vector2i) -> Vector3:
	# A part's origin is its centre, so where it may sit depends on how
	# wide it is. One stud across is centred ON a stud — an odd multiple
	# of half a pitch. Two across is centred on the line BETWEEN two
	# studs, which is a whole multiple.
	#
	# These were the other way round, which put every brick placed by
	# hand half a stud — four millimetres — out of step with every brick
	# the assistant placed, since the assistant builds its own transform
	# and never comes through here. Two models of the same thing would
	# not stack.
	var phase_x: float = STUD * 0.5 if footprint.x % 2 == 1 else 0.0
	var phase_z: float = STUD * 0.5 if footprint.y % 2 == 1 else 0.0
	return Vector3(
		round((position.x - phase_x) / STUD) * STUD + phase_x,
		position.y,
		round((position.z - phase_z) / STUD) * STUD + phase_z)


## What a ray hit, if anything.
class Hit extends RefCounted:
	var brick_id: int = 0
	var cell: Vector3i          ## the filled cell that was struck
	var normal: Vector3i        ## face it entered through, towards the ray
	var distance: float = 0.0   ## along the ray, in LDU

	func is_valid() -> bool:
		return brick_id != 0

	## The empty cell against that face — where a new part would go.
	func adjacent() -> Vector3i:
		return cell + normal


## March a ray through the lattice and return the first brick it meets.
##
## This is also how picking works, and it is the reason the lattice earns
## its keep twice. Bricks are drawn with MultiMesh, which has no per
## instance collision shape, so there is nothing for a physics raycast to
## hit; adding one body per brick would undo the batching that makes a
## hundred thousand of them cheap. Marching the occupancy grid costs
## nothing extra, is exact, and hands back the face that was entered as
## well as the brick — which is precisely what placing the next part needs.
##
## The march is the standard grid traversal: step to whichever axis has the
## nearer boundary, every cell along the line visited once, no cell missed.
func raycast(origin: Vector3, direction: Vector3, max_distance: float = 20000.0) -> Hit:
	var hit := Hit.new()
	var dir: Vector3 = direction.normalized()
	if dir.length_squared() < 0.5:
		return hit

	var cell: Vector3i = to_cell(origin)
	var step := Vector3i(
		1 if dir.x > 0.0 else -1,
		1 if dir.y > 0.0 else -1,
		1 if dir.z > 0.0 else -1)

	# Distance along the ray to the next boundary on each axis, and the
	# distance between successive boundaries. A component of exactly zero
	# never crosses, so its times stay at infinity.
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axis: int in 3:
		var d: float = dir[axis]
		if absf(d) < 1e-9:
			continue
		var boundary: float = (cell[axis] + (0.5 if step[axis] > 0 else -0.5)) * CELL
		t_max[axis] = (boundary - origin[axis]) / d
		t_delta[axis] = CELL / absf(d)

	var travelled: float = 0.0
	var entered := Vector3i.ZERO

	# A model is a shell, so most of the march is through air. The cap is
	# generous but finite: an unbounded loop on a ray that never hits
	# anything would hang the frame.
	for _n: int in 20000:
		var owner: int = brick_at(cell)
		if owner != 0:
			hit.brick_id = owner
			hit.cell = cell
			hit.normal = entered
			hit.distance = travelled
			return hit

		if t_max.x < t_max.y and t_max.x < t_max.z:
			cell.x += step.x
			travelled = t_max.x
			t_max.x += t_delta.x
			entered = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			cell.y += step.y
			travelled = t_max.y
			t_max.y += t_delta.y
			entered = Vector3i(0, -step.y, 0)
		else:
			cell.z += step.z
			travelled = t_max.z
			t_max.z += t_delta.z
			entered = Vector3i(0, 0, -step.z)

		if travelled > max_distance:
			break

	return hit
