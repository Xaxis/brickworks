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
## brick id -> its boxes laid out by the rows of cells (y, z) they cover
## ([method _rows_of]), for a brick of more than [constant ROWS_FROM] boxes:
## what a box meets of it is the few boxes on the rows that box covers, not
## every box of it. A turned part's cover is a box a row, and 42112's
## mixer drum, a part its file carries, turned on its truck, is 23,309.
var _rows: Dictionary = {}
## Boxes from which a brick is laid out by rows.
const ROWS_FROM := 24
## Bricks the pointer passes through: hidden ones, so the inside of a
## model can be reached with its roof hidden. They still take up their
## room — nothing can be put down inside a hidden brick.
var unseen: Dictionary = {}
## Bricks the pointer passes through because the eye does: x-ray's ghosts
## (SeeInside). Kept apart from unseen, which everything else reads as
## hidden by hand.
## Set whole, as SeeInside does, so the revision moves with it.
var see_through: Dictionary = {}:
	set(value):
		see_through = value
		revision += 1
## Bricks the pointer passes through because the timeline has not put them
## on yet (StepsBar): drawn nowhere, they took the click, and a part on
## the step showing could not be picked from under the step after it.
## Set whole, so the revision moves with it.
var ahead: Dictionary = {}:
	set(value):
		ahead = value
		revision += 1
## The cut-away (SeeInside): a ray passes through every cell on the side of
## this plane its normal points to, as the eye does. Off while the normal is
## zero.
var cut: Plane = Plane():
	set(value):
		cut = value
		revision += 1
## Goes up with every brick put in or taken out, and when x-ray or the cut
## changes what a ray passes through, so an answer kept from before can
## tell it still holds (EditVerbs.brick_at). Hiding by hand clears that
## answer itself (EditVerbs.apply_hidden).
var revision: int = 0
## Round every box ever put in since the last clear, in cells, low corner
## and high (exclusive): where a ray can meet anything at all. Not made
## smaller as bricks go, so it may be roomier than what stands.
var _extent: PackedInt32Array = PackedInt32Array()


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


## Whether a point is off the lattice: not on a cell corner on some axis,
## beyond float dust.
static func is_off_lattice(point: Vector3) -> bool:
	for axis: int in 3:
		var past: float = fposmod(point[axis], CELL)
		if past > 0.01 and past < CELL - 0.01:
			return true
	return false


## A cover cut back to the part it covers.
##
## A part's boxes are counted from the cell its origin is in. On the
## lattice that is exact; off it — a minifigure's parts, and whatever a
## figure stands on — it moves the cover down and back by up to a cell
## from the part: a flipper with its sole on a plate and its origin 3 LDU
## above it was reckoned from 2 LDU, and read as a cell into the plate,
## so a figure on flippers had to stand a LDU above it. So a square
## part's cover off the lattice is kept inside the part's own box, placed
## where it is and rounded out to whole cells. That only ever takes away
## cells the part is not in. (A turned part's cover is rounded out all
## round on purpose — a tipped section finds what it leans on by it —
## and is left alone.)
static func within(packed: PackedInt32Array, bounds: AABB, at: Transform3D) -> PackedInt32Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for n: int in 8:
		var corner: Vector3 = at * (bounds.position + bounds.size * Vector3(
			n & 1, (n >> 1) & 1, (n >> 2) & 1))
		lo = lo.min(corner)
		hi = hi.max(corner)
	var from := Vector3i(int(floor((lo.x + 0.01) / CELL)), int(floor((lo.y + 0.01) / CELL)),
		int(floor((lo.z + 0.01) / CELL)))
	var to := Vector3i(int(ceil((hi.x - 0.01) / CELL)), int(ceil((hi.y - 0.01) / CELL)),
		int(ceil((hi.z - 0.01) / CELL)))
	var out := PackedInt32Array()
	var n: int = 0
	while n + 5 < packed.size():
		var a := Vector3i(maxi(packed[n], from.x), maxi(packed[n + 1], from.y),
			maxi(packed[n + 2], from.z))
		var b := Vector3i(mini(packed[n + 3], to.x), mini(packed[n + 4], to.y),
			mini(packed[n + 5], to.z))
		if a.x < b.x and a.y < b.y and a.z < b.z:
			out.append_array([a.x, a.y, a.z, b.x, b.y, b.z])
		n += 6
	return out


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
## The boxes a brick occupies here, or nothing if it is not here.
func boxes_of(brick_id: int) -> PackedInt32Array:
	return _boxes.get(brick_id, PackedInt32Array())


## The same boxes, moved by whole cells.
##
## For asking what sits on top of something: a brick's boxes lifted one
## cell is exactly the space its studs would reach into, and whatever
## overlaps that is resting on it.
static func moved_by(packed: PackedInt32Array, by: Vector3i) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(packed.size())
	var n: int = 0
	while n < packed.size():
		out[n] = packed[n] + by.x
		out[n + 1] = packed[n + 1] + by.y
		out[n + 2] = packed[n + 2] + by.z
		out[n + 3] = packed[n + 3] + by.x
		out[n + 4] = packed[n + 4] + by.y
		out[n + 5] = packed[n + 5] + by.z
		n += 6
	return out


## How many cells two sets of boxes have in common.
##
## The number a joint's strength is measured in, and the reason it is
## here: counting it by walking cells is nine thousand six hundred
## lattice lookups per brick, which is thirty-seven milliseconds a brick
## and six minutes for a ten thousand brick model. The overlap of two
## boxes is a box, so the count is a product of three subtractions.
static func shared_cells(a: PackedInt32Array, b: PackedInt32Array) -> int:
	var total: int = 0
	var i: int = 0
	while i < a.size():
		var j: int = 0
		while j < b.size():
			var wide: int = mini(a[i + 3], b[j + 3]) - maxi(a[i], b[j])
			if wide > 0:
				var high: int = mini(a[i + 4], b[j + 4]) - maxi(a[i + 1], b[j + 1])
				if high > 0:
					var deep: int = mini(a[i + 5], b[j + 5]) \
						- maxi(a[i + 2], b[j + 2])
					if deep > 0:
						total += wide * high * deep
			j += 6
		i += 6
	return total


## The same count, with [param a] sorted into [method slices_of] first.
##
## A turned part's cover is a slice a cell deep for every z it spans
## ([method compress]): forty boxes for a turned 2 x 4, eight hundred for
## a big turned plate. Compared box against box, two of those are tens of
## thousands of tests, and on Orthanc (8,785 parts, 5,345 of them turned)
## the contact graph was 10.4 s of an 11 s weighing (2026-10-11). Sliced,
## each box of [param b] meets only the slices of [param a] at its own z.
static func shared_cells_sliced(a: PackedInt32Array, slices: Array,
		b: PackedInt32Array) -> int:
	var by_z: Dictionary = slices[0]
	var deep: PackedInt32Array = slices[1]
	var total: int = 0
	var j: int = 0
	while j < b.size():
		var lo_z: int = b[j + 2]
		var hi_z: int = b[j + 5]
		var across: Array = []
		if hi_z - lo_z <= by_z.size():
			for z: int in range(lo_z, hi_z):
				var here: Variant = by_z.get(z)
				if here != null:
					across.append(here)
		else:
			for z: int in by_z:
				if z >= lo_z and z < hi_z:
					across.append(by_z[z])
		across.append(deep)
		for offsets: PackedInt32Array in across:
			for i: int in offsets:
				var wide: int = mini(a[i + 3], b[j + 3]) - maxi(a[i], b[j])
				if wide <= 0:
					continue
				var high: int = mini(a[i + 4], b[j + 4]) - maxi(a[i + 1], b[j + 1])
				if high <= 0:
					continue
				var depth: int = mini(a[i + 5], hi_z) - maxi(a[i + 2], lo_z)
				if depth > 0:
					total += wide * high * depth
		j += 6
	return total


## Boxes a cell deep, by the z they are at, and the deeper ones apart:
## [Dictionary z -> offsets into [param packed], PackedInt32Array of the
## other offsets]. For [method shared_cells_sliced].
static func slices_of(packed: PackedInt32Array) -> Array:
	var by_z: Dictionary = {}
	var deep := PackedInt32Array()
	var n: int = 0
	while n < packed.size():
		var z: int = packed[n + 2]
		if packed[n + 5] - z == 1:
			var at: PackedInt32Array = by_z.get(z, PackedInt32Array())
			at.append(n)
			by_z[z] = at
		else:
			deep.append(n)
		n += 6
	return [by_z, deep]


## The lowest and highest cell a set of boxes covers, as [low, high].
##
## The same two corners walking every cell would find, in six reads per
## box instead of nine thousand six hundred per brick. A box already is
## its corners; expanding it to cells to find them back was most of what
## checking a large model cost.
static func corners_in(packed: PackedInt32Array) -> Array:
	if packed.is_empty():
		return []
	var lo := Vector3i(packed[0], packed[1], packed[2])
	var hi := Vector3i(packed[3] - 1, packed[4] - 1, packed[5] - 1)
	var n: int = 6
	while n < packed.size():
		lo = Vector3i(mini(lo.x, packed[n]), mini(lo.y, packed[n + 1]),
			mini(lo.z, packed[n + 2]))
		hi = Vector3i(maxi(hi.x, packed[n + 3] - 1),
			maxi(hi.y, packed[n + 4] - 1), maxi(hi.z, packed[n + 5] - 1))
		n += 6
	return [lo, hi]


## How many cells boxes cover, counted as [method cells_in] would count
## them, a box at a time and overlaps twice.
static func volume_of(packed: PackedInt32Array) -> int:
	var total: int = 0
	for n: int in range(0, packed.size(), 6):
		total += (packed[n + 3] - packed[n]) * (packed[n + 4] - packed[n + 1]) \
			* (packed[n + 5] - packed[n + 2])
	return total


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

		# The turned box, as a centre, three axes and three half-widths,
		# and the fifteen separating axes with how far apart along each a
		# cell and the box can be and still touch — worked out once per
		# box. They were worked out again for every cell, which on a turned
		# 2 x 4 is twenty thousand times: an Orthanc of a thousand angled
		# bricks took three minutes to place, on the one thread the app
		# answers on, so every look the design asked for timed out.
		var half: Vector3 = (hi - lo) * 0.5
		var middle: Vector3 = basis * ((lo + hi) * 0.5)
		var test: Array = _separating(basis, half)
		var axes: Array[Vector3] = test[0]
		var reaches: PackedFloat64Array = test[1]

		var z_from: int = floori(low.z)
		var z_to: int = ceili(high.z) - 1
		for x: int in range(floori(low.x), ceili(high.x)):
			for y: int in range(floori(low.y), ceili(high.y)):
				# Along a line of cells the ones that touch are one run:
				# the box grown by a cell is convex. So the run's ends,
				# from the same fifteen slabs, and the cells between.
				var px: float = float(x) + 0.5
				var py: float = float(y) + 0.5
				var t0: float = -INF
				var t1: float = INF
				var empty: bool = false
				for n: int in axes.size():
					var axis: Vector3 = axes[n]
					var k: float = middle.dot(axis) - px * axis.x - py * axis.y
					var r: float = reaches[n]
					if absf(axis.z) < 0.000001:
						if absf(k) > r:
							empty = true
							break
						continue
					var a: float = (k - r) / axis.z
					var b: float = (k + r) / axis.z
					t0 = maxf(t0, minf(a, b))
					t1 = minf(t1, maxf(a, b))
					if t0 > t1 + 1.0:
						empty = true
						break
				if empty:
					continue
				# The ends settled by the exact test, so a cell that only
				# just touches is decided the way it always was.
				var first: int = clampi(ceili(t0 - 0.5), z_from, z_to + 1)
				var last: int = clampi(floori(t1 - 0.5), z_from - 1, z_to)
				while first - 1 >= z_from and _touches_with(middle, axes,
						reaches, Vector3(px, py, float(first - 1) + 0.5)):
					first -= 1
				while first <= z_to and not _touches_with(middle, axes,
						reaches, Vector3(px, py, float(first) + 0.5)):
					first += 1
				while last + 1 <= z_to and _touches_with(middle, axes,
						reaches, Vector3(px, py, float(last + 1) + 0.5)):
					last += 1
				while last >= first and not _touches_with(middle, axes,
						reaches, Vector3(px, py, float(last) + 0.5)):
					last -= 1
				for z: int in range(first, last + 1):
					var cell: Vector3i = origin_cell + Vector3i(x, y, z)
					if taken.has(cell):
						continue
					taken[cell] = true
					out.append(cell)
	return out


## The fifteen separating axes for a turned box and a unit cell, and for
## each the farthest apart along it they can be and still touch: the
## same axes and reaches [method _touches] works out, once.
static func _separating(basis: Basis, half: Vector3) -> Array:
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
	var reaches := PackedFloat64Array()
	for axis: Vector3 in axes:
		var cell_reach: float = 0.5 * (absf(axis.x) + absf(axis.y)
			+ absf(axis.z))
		var box_reach: float = 0.0
		for n: int in 3:
			box_reach += widths[n] * absf(axis.dot(basis[n].normalized()))
		reaches.append(cell_reach + box_reach)
	return [axes, reaches]


## [method _touches], with its axes and reaches worked out already.
static func _touches_with(middle: Vector3, axes: Array[Vector3],
		reaches: PackedFloat64Array, at: Vector3) -> bool:
	var apart: Vector3 = middle - at
	for n: int in axes.size():
		if absf(apart.dot(axes[n])) > reaches[n]:
			return false
	return true


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


## Whether to keep the column index that [method surface_under] reads.
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
	revision += 1
	_boxes[brick_id] = packed
	_bounds[brick_id] = _bound_of(packed)
	_reach_round(_bounds[brick_id])
	var rows: Array = _rows_of(packed, _bounds[brick_id]) \
		if packed.size() > ROWS_FROM * 6 else []
	if rows.is_empty():
		_rows.erase(brick_id)
	else:
		_rows[brick_id] = rows
	_into_buckets(brick_id, _bounds[brick_id])


## A brick's cover as the lattice holds it, [its boxes, their bound, its
## rows], to be put back by [method occupy_moved] once it has been let go
## of: what a move of a selection takes out before it asks where the
## selection may go.
func cover_of(brick_id: int) -> Array:
	return [_boxes.get(brick_id, PackedInt32Array()), _bounds.get(brick_id, PackedInt32Array()),
		_rows.get(brick_id, [])]


## Put a brick in by a cover it had ([method cover_of]), moved [param by]
## whole cells: a part moved without turning covers the same cells, moved.
## Its boxes are moved, and its bound and rows (laid out relative to their
## low corner) carried over, rather than worked out again from the part:
## for a Technic part, a cover of hundreds of boxes, that was most of a
## millisecond, and a move of a selection of thousands of them, its undo
## and its redo did it for each part.
func occupy_moved(brick_id: int, cover: Array, by: Vector3i) -> void:
	var packed: PackedInt32Array = cover[0]
	if by != Vector3i.ZERO:
		packed = moved_by(packed, by)
	revision += 1
	_boxes[brick_id] = packed
	var bound: PackedInt32Array = cover[1]
	if bound.size() < 6:
		bound = _bound_of(packed)
	elif by != Vector3i.ZERO:
		bound = moved_by(bound, by)
	_bounds[brick_id] = bound
	_reach_round(bound)
	var rows: Array = cover[2]
	if rows.is_empty():
		_rows.erase(brick_id)
	else:
		_rows[brick_id] = [int(rows[0]) + by.y, int(rows[1]) + by.z, rows[2], rows[3], rows[4],
			rows[5], rows[6]]
	_into_buckets(brick_id, bound)


## Move a brick that is in by whole cells, as [method occupy_moved] puts
## one in: its boxes moved, its bound and rows carried over, and only the
## buckets it leaves and the ones it comes into changed. A stud's move
## leaves most of a part's buckets as they were, and an undo of a move of
## thousands of parts let go of every one and took it again.
func shift(brick_id: int, by: Vector3i) -> void:
	var packed: PackedInt32Array = _boxes.get(brick_id, PackedInt32Array())
	var bound: PackedInt32Array = _bounds.get(brick_id, PackedInt32Array())
	if packed.is_empty() or bound.size() < 6:
		var cover: Array = cover_of(brick_id)
		release(brick_id)
		occupy_moved(brick_id, cover, by)
		return
	if by == Vector3i.ZERO:
		return
	revision += 1
	var moved: PackedInt32Array = moved_by(bound, by)
	_rebucket(brick_id, bound, moved)
	_boxes[brick_id] = moved_by(packed, by)
	_bounds[brick_id] = moved
	_reach_round(moved)
	var rows: Array = _rows.get(brick_id, [])
	if not rows.is_empty():
		_rows[brick_id] = [int(rows[0]) + by.y, int(rows[1]) + by.z, rows[2], rows[3], rows[4],
			rows[5], rows[6]]


## [param brick_id] out of the buckets and columns bound [param was] reaches
## and [param now] does not, and into those [param now] reaches and [param
## was] did not.
func _rebucket(brick_id: int, was: PackedInt32Array, now: PackedInt32Array) -> void:
	var a: Array = _bucket_span(was)
	var b: Array = _bucket_span(now)
	for side: int in 2:
		var from: Array = a if side == 0 else b
		var other: Array = b if side == 0 else a
		for bx: int in range(from[0], from[3] + 1):
			var x_in: bool = bx >= other[0] and bx <= other[3]
			for bz: int in range(from[2], from[5] + 1):
				var z_in: bool = x_in and bz >= other[2] and bz <= other[5]
				for by: int in range(from[1], from[4] + 1):
					if z_in and by >= other[1] and by <= other[4]:
						continue
					var key := Vector3i(bx, by, bz)
					if side == 0:
						_take_out(_bucket, key, brick_id)
					else:
						var here: PackedInt64Array = _bucket.get(key, PackedInt64Array())
						_bucket.erase(key)
						here.append(brick_id)
						_bucket[key] = here
				if z_in:
					continue
				var flat := Vector2i(bx, bz)
				if side == 0:
					_take_out(_column_bucket, flat, brick_id)
				else:
					var column: PackedInt64Array = _column_bucket.get(flat, PackedInt64Array())
					_column_bucket.erase(flat)
					column.append(brick_id)
					_column_bucket[flat] = column


## The buckets a bound reaches, low and high on each axis, both inclusive.
static func _bucket_span(bound: PackedInt32Array) -> Array:
	return [_floor_div(bound[0], BUCKET), _floor_div(bound[1], BUCKET),
		_floor_div(bound[2], BUCKET), _floor_div(bound[3] - 1, BUCKET),
		_floor_div(bound[4] - 1, BUCKET), _floor_div(bound[5] - 1, BUCKET)]


## [param brick_id] into every bucket its bound reaches, and every column.
##
## By the bound, not box by box: a bucket holds every brick that might have
## a box in it, and whoever reads one tests the boxes. Found box by box, a
## Technic part's cover of hundreds of boxes was hundreds of bucket keys
## worked out and merged, at every put in and every let go: on a 4,139-part
## set (305,648 boxes) two and a half seconds for the lot.
func _into_buckets(brick_id: int, bound: PackedInt32Array) -> void:
	if bound.size() < 6:
		return
	for bx: int in range(_floor_div(bound[0], BUCKET), _floor_div(bound[3] - 1, BUCKET) + 1):
		for bz: int in range(_floor_div(bound[2], BUCKET), _floor_div(bound[5] - 1, BUCKET) + 1):
			for by: int in range(_floor_div(bound[1], BUCKET), _floor_div(bound[4] - 1, BUCKET) + 1):
				var key := Vector3i(bx, by, bz)
				var here: PackedInt64Array = _bucket.get(key, PackedInt64Array())
				# Out of the dictionary while it grows, so it grows in place
				# rather than being copied whole first (_take_out).
				_bucket.erase(key)
				here.append(brick_id)
				_bucket[key] = here
			var flat := Vector2i(bx, bz)
			var column: PackedInt64Array = _column_bucket.get(flat, PackedInt64Array())
			_column_bucket.erase(flat)
			column.append(brick_id)
			_column_bucket[flat] = column


## [param brick_id] out of every bucket and column its bound reaches.
func _out_of_buckets(brick_id: int, bound: PackedInt32Array) -> void:
	if bound.size() < 6:
		return
	for bx: int in range(_floor_div(bound[0], BUCKET), _floor_div(bound[3] - 1, BUCKET) + 1):
		for bz: int in range(_floor_div(bound[2], BUCKET), _floor_div(bound[5] - 1, BUCKET) + 1):
			for by: int in range(_floor_div(bound[1], BUCKET), _floor_div(bound[4] - 1, BUCKET) + 1):
				_take_out(_bucket, Vector3i(bx, by, bz), brick_id)
			_take_out(_column_bucket, Vector2i(bx, bz), brick_id)


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
	var plain: bool = _plain(packed)
	for other: int in _near(mine):
		if other == ignore or skip.has(other):
			continue
		var bound: PackedInt32Array = _bounds.get(other, PackedInt32Array())
		if not _overlaps_pairwise(mine, bound):
			continue
		if _meets(packed, mine, plain, other, bound):
			found[other] = true
	return PackedInt64Array(found.keys())


## The bricks whose bounds meet the bounds of these boxes: everything
## that could touch them, to be counted by the caller (Stability, which
## counts the cells shared and so needs no second, exact test first).
func near_bounds(packed: PackedInt32Array, ignore: int = 0) -> PackedInt64Array:
	var found := PackedInt64Array()
	var mine: PackedInt32Array = _bound_of(packed)
	for other: int in _near(mine):
		if other != ignore and _overlaps(mine, _bounds.get(other, PackedInt32Array())):
			found.append(other)
	return found


func collides_boxes(packed: PackedInt32Array, ignore: int = 0) -> bool:
	var mine: PackedInt32Array = _bound_of(packed)
	var plain: bool = _plain(packed)
	# The buckets of the bound: a bucket holds whatever might reach into it
	# (_into_buckets), and the boxes are what is tested.
	for other: int in _near(mine):
		if other == ignore:
			continue
		var bound: PackedInt32Array = _bounds.get(other, PackedInt32Array())
		if not _overlaps_pairwise(mine, bound):
			continue
		if _meets(packed, mine, plain, other, bound):
			return true
	return false


## Whether boxes ([param packed], [param mine] their bound, [param plain]
## none of them empty along an axis) meet brick [param other]'s, whose bound
## is [param bound]: by its rows where it is laid out by them, else as
## [method _overlaps] does.
func _meets(packed: PackedInt32Array, mine: PackedInt32Array, plain: bool, other: int,
		bound: PackedInt32Array) -> bool:
	var theirs: PackedInt32Array = _boxes.get(other, PackedInt32Array())
	var rows: Array = _rows.get(other, [])
	if plain and not rows.is_empty():
		return _meets_rows(packed, theirs, bound, rows)
	return _overlaps_within(packed, mine, theirs, bound)


## Whether none of these boxes is empty along an axis, where pair by pair
## and by rows could answer differently.
static func _plain(packed: PackedInt32Array) -> bool:
	var n: int = 0
	while n < packed.size():
		if packed[n] >= packed[n + 3] or packed[n + 1] >= packed[n + 4] \
				or packed[n + 2] >= packed[n + 5]:
			return false
		n += 6
	return true


## A brick's boxes laid out by the rows of cells (y, z) they cover, inside
## [param bound]: [lowest y, lowest z, rows high, rows deep, the first box on
## each row (-1 for none), the next on the same row of each entry, the box
## (its offset) of each entry]. Empty when a box is empty along an axis.
static func _rows_of(packed: PackedInt32Array, bound: PackedInt32Array) -> Array:
	if not _plain(packed):
		return []
	var lo_y: int = bound[1]
	var lo_z: int = bound[2]
	var high: int = bound[4] - bound[1]
	var deep: int = bound[5] - bound[2]
	var heads := PackedInt32Array()
	heads.resize(high * deep)
	heads.fill(-1)
	var next := PackedInt32Array()
	var whose := PackedInt32Array()
	var j: int = 0
	while j < packed.size():
		for y: int in range(packed[j + 1], packed[j + 4]):
			var row: int = (y - lo_y) * deep - lo_z
			for z: int in range(packed[j + 2], packed[j + 5]):
				next.append(heads[row + z])
				heads[row + z] = whose.size()
				whose.append(j)
		j += 6
	return [lo_y, lo_z, high, deep, heads, next, whose]


## Whether any of [param packed] (none empty along an axis) meets a box of
## [param theirs], laid out by [param rows] inside [param bound]. Each box
## asks the rows it covers there, or, where that is more rows than the
## other has boxes (a baseplate's one box against a small part), every box
## of the other, pair by pair: either answers exactly.
static func _meets_rows(packed: PackedInt32Array, theirs: PackedInt32Array,
		bound: PackedInt32Array, rows: Array) -> bool:
	var lo_y: int = rows[0]
	var lo_z: int = rows[1]
	var hi_y: int = lo_y + int(rows[2])
	var deep: int = rows[3]
	var hi_z: int = lo_z + deep
	var heads: PackedInt32Array = rows[4]
	var next: PackedInt32Array = rows[5]
	var whose: PackedInt32Array = rows[6]
	var boxes: int = theirs.size() / 6
	var i: int = 0
	while i < packed.size():
		var from_x: int = packed[i]
		var to_x: int = packed[i + 3]
		var y0: int = maxi(packed[i + 1], lo_y)
		var y1: int = mini(packed[i + 4], hi_y)
		var z0: int = maxi(packed[i + 2], lo_z)
		var z1: int = mini(packed[i + 5], hi_z)
		if from_x >= bound[3] or to_x <= bound[0] or y0 >= y1 or z0 >= z1:
			i += 6
			continue
		if (y1 - y0) * (z1 - z0) > boxes:
			var j: int = 0
			while j < theirs.size():
				if from_x < theirs[j + 3] and theirs[j] < to_x \
						and packed[i + 1] < theirs[j + 4] and theirs[j + 1] < packed[i + 4] \
						and packed[i + 2] < theirs[j + 5] and theirs[j + 2] < packed[i + 5]:
					return true
				j += 6
			i += 6
			continue
		for y: int in range(y0, y1):
			var row: int = (y - lo_y) * deep - lo_z
			for z: int in range(z0, z1):
				var at: int = heads[row + z]
				while at >= 0:
					var o: int = whose[at]
					if from_x < theirs[o + 3] and theirs[o] < to_x:
						return true
					at = next[at]
		i += 6
	return false


## The bricks sharing a bucket with any of these boxes, in the order they
## are first met. Each bucket is read once: a turned part's cover is
## hundreds of boxes in a handful of buckets, and every box read every brick
## in its bucket again.
func _near(packed: PackedInt32Array) -> PackedInt64Array:
	var seen: Dictionary = {}
	var read: Dictionary = {}
	var n: int = 0
	while n < packed.size():
		for bx: int in range(_floor_div(packed[n], BUCKET),
				_floor_div(packed[n + 3] - 1, BUCKET) + 1):
			for by: int in range(_floor_div(packed[n + 1], BUCKET),
					_floor_div(packed[n + 4] - 1, BUCKET) + 1):
				for bz: int in range(_floor_div(packed[n + 2], BUCKET),
						_floor_div(packed[n + 5] - 1, BUCKET) + 1):
					var key := Vector3i(bx, by, bz)
					if read.has(key):
						continue
					read[key] = true
					var here: Variant = _bucket.get(key)
					if here == null:
						continue
					for brick_id: int in here:
						seen[brick_id] = true
		n += 6
	return PackedInt64Array(seen.keys())


## Whether any box of one set meets any box of the other.
##
## Pair by pair it costs the product of the two counts, and a turned part's
## cover is a box a row of cells (compress): two Technic beams turned side
## by side were a hundred thousand tests to say they do not meet, and the
## checks that ask it of every part's neighbours (what it runs into, what
## sits on it, what a section touches, the pieces) took 42112's audit from
## 36 seconds to 16 minutes once its parts were checked where they stand.
## Past [constant PAIRWISE_UP_TO] pairs only the boxes inside where the two
## sets' bounds meet are taken, and one set is laid out by the rows of
## cells (y, z) it covers there, for each box of the other to look up the
## rows it covers: two boxes meet only where both bounds do, and only on a
## row both cover. The same answer as pair by pair, which still answers for
## a set with a box empty along an axis (a sliver's cover rounds to one).
static func _overlaps(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() * b.size() <= PAIRWISE_UP_TO * 36:
		return _overlaps_pairwise(a, b)
	return _overlaps_within(a, _bound_of(a), b, _bound_of(b))


## Pairs of boxes past which [method _overlaps] looks by rows.
const PAIRWISE_UP_TO := 48


## [method _overlaps] with each set's bound (_bound_of) given.
static func _overlaps_within(a: PackedInt32Array, bound_a: PackedInt32Array,
		b: PackedInt32Array, bound_b: PackedInt32Array) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	# A few boxes against many: every pair is no more than going through
	# the many once, which looking by rows does anyway.
	if a.size() * b.size() <= PAIRWISE_UP_TO * 36 or a.size() <= 24 or b.size() <= 24:
		return _overlaps_pairwise(a, b)
	# Where the two bounds meet: nothing meets outside it.
	var lo_x: int = maxi(bound_a[0], bound_b[0])
	var lo_y: int = maxi(bound_a[1], bound_b[1])
	var lo_z: int = maxi(bound_a[2], bound_b[2])
	var hi_x: int = mini(bound_a[3], bound_b[3])
	var hi_y: int = mini(bound_a[4], bound_b[4])
	var hi_z: int = mini(bound_a[5], bound_b[5])
	var region := PackedInt32Array([lo_x, lo_y, lo_z, hi_x, hi_y, hi_z])
	var mine: PackedInt32Array = _inside(a, region)
	var theirs: PackedInt32Array = _inside(b, region)
	# A box empty along an axis: pair by pair, as it always was.
	if mine.size() == 1 or theirs.size() == 1:
		return _overlaps_pairwise(a, b)
	if lo_x >= hi_x or lo_y >= hi_y or lo_z >= hi_z or mine.is_empty() or theirs.is_empty():
		return false
	var rows_mine: int = _rows_in(mine, region)
	var rows_theirs: int = _rows_in(theirs, region)
	# Laid out by rows only where that is cheaper than every pair.
	if (rows_mine + rows_theirs) * 2 >= (mine.size() / 6) * (theirs.size() / 6):
		return _overlaps_pairwise(mine, theirs)
	if rows_mine < rows_theirs:
		var swap: PackedInt32Array = mine
		mine = theirs
		theirs = swap
	# The smaller laid out: the boxes on each row, as lists through [next].
	var deep: int = hi_z - lo_z
	var heads := PackedInt32Array()
	heads.resize((hi_y - lo_y) * deep)
	heads.fill(-1)
	var next := PackedInt32Array()
	var whose := PackedInt32Array()
	var j: int = 0
	while j < theirs.size():
		for y: int in range(maxi(theirs[j + 1], lo_y), mini(theirs[j + 4], hi_y)):
			var row: int = (y - lo_y) * deep - lo_z
			for z: int in range(maxi(theirs[j + 2], lo_z), mini(theirs[j + 5], hi_z)):
				next.append(heads[row + z])
				heads[row + z] = whose.size()
				whose.append(j)
		j += 6
	var i: int = 0
	while i < mine.size():
		var from_x: int = mine[i]
		var to_x: int = mine[i + 3]
		for y: int in range(maxi(mine[i + 1], lo_y), mini(mine[i + 4], hi_y)):
			var row: int = (y - lo_y) * deep - lo_z
			for z: int in range(maxi(mine[i + 2], lo_z), mini(mine[i + 5], hi_z)):
				var at: int = heads[row + z]
				while at >= 0:
					var o: int = whose[at]
					if from_x < theirs[o + 3] and theirs[o] < to_x:
						return true
					at = next[at]
		i += 6
	return false


## The boxes of [param packed] that meet [param region], as they are; one
## number, 0, when a box of it is empty along an axis, whichever box it is.
## (An empty region can pass a box: say nothing of it then.)
static func _inside(packed: PackedInt32Array, region: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n: int = 0
	while n < packed.size():
		if packed[n] >= packed[n + 3] or packed[n + 1] >= packed[n + 4] \
				or packed[n + 2] >= packed[n + 5]:
			return PackedInt32Array([0])
		if packed[n] < region[3] and region[0] < packed[n + 3] \
				and packed[n + 1] < region[4] and region[1] < packed[n + 4] \
				and packed[n + 2] < region[5] and region[2] < packed[n + 5]:
			out.append_array(packed.slice(n, n + 6))
		n += 6
	return out


## How many rows of cells (y, z) the boxes cover inside [param region],
## counted a box at a time.
static func _rows_in(packed: PackedInt32Array, region: PackedInt32Array) -> int:
	var total: int = 0
	var n: int = 0
	while n < packed.size():
		total += (mini(packed[n + 4], region[4]) - maxi(packed[n + 1], region[1])) \
			* (mini(packed[n + 5], region[5]) - maxi(packed[n + 2], region[2]))
		n += 6
	return total


## [method _overlaps], pair by pair.
static func _overlaps_pairwise(a: PackedInt32Array, b: PackedInt32Array) -> bool:
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
	revision += 1
	_rows.erase(brick_id)
	var packed: PackedInt32Array = _boxes.get(brick_id, PackedInt32Array())
	if packed.is_empty():
		_boxes.erase(brick_id)
		_bounds.erase(brick_id)
		return
	_out_of_buckets(brick_id, _bounds.get(brick_id, _bound_of(packed)))
	_boxes.erase(brick_id)
	_bounds.erase(brick_id)


## [param brick_id] out of one bucket's list, by the engine's own search.
##
## Copied over in a loop here, a column of a tall model held thousands, and
## taking all of Orthanc off (Delete, Cut) cost a minute on one frame: every
## part's release walked its whole column (2026-10-13, command_probe).
static func _take_out(buckets: Dictionary, key: Variant, brick_id: int) -> void:
	var here: Variant = buckets.get(key)
	if here == null:
		return
	var list: PackedInt64Array = here
	here = null
	# Out of the dictionary while it changes, so it changes in place: held
	# by the dictionary too, the list was copied whole before each remove,
	# and a part let go of copied every bucket and column it was in.
	buckets.erase(key)
	var at: int = list.find(brick_id)
	while at >= 0:
		list.remove_at(at)
		at = list.find(brick_id, at)
	if not list.is_empty():
		buckets[key] = list


func brick_at(cell: Vector3i) -> int:
	var here: Variant = _bucket.get(Vector3i(
		_floor_div(cell.x, BUCKET), _floor_div(cell.y, BUCKET),
		_floor_div(cell.z, BUCKET)))
	if here == null:
		return 0
	for brick_id: int in here:
		# Its bound first: a bucket of turned parts is thousands of boxes.
		var bound: PackedInt32Array = _bounds.get(brick_id, PackedInt32Array())
		if bound.is_empty() or cell.x < bound[0] or cell.x >= bound[3] \
				or cell.y < bound[1] or cell.y >= bound[4] \
				or cell.z < bound[2] or cell.z >= bound[5]:
			continue
		var packed: PackedInt32Array = _boxes.get(brick_id, PackedInt32Array())
		var rows: Array = _rows.get(brick_id, [])
		if not rows.is_empty():
			# Inside its bound, so on one of its rows: the boxes on it.
			var heads: PackedInt32Array = rows[4]
			var next: PackedInt32Array = rows[5]
			var whose: PackedInt32Array = rows[6]
			var at: int = heads[(cell.y - int(rows[0])) * int(rows[3]) + cell.z - int(rows[1])]
			while at >= 0:
				var o: int = whose[at]
				if cell.x >= packed[o] and cell.x < packed[o + 3]:
					return brick_id
				at = next[at]
			continue
		var n: int = 0
		while n < packed.size():
			if cell.x >= packed[n] and cell.x < packed[n + 3] \
					and cell.y >= packed[n + 1] and cell.y < packed[n + 4] \
					and cell.z >= packed[n + 2] and cell.z < packed[n + 5]:
				return brick_id
			n += 6
	return 0


## Is anything standing on these studs? For each stud, [x, z] in studs on
## the grid, on a top face whose first cell above is [param top]: the brick
## in the room that stud takes (its square, from the face to past its tip),
## or nothing. A smooth top keeps to it: a tile where nothing stands, a stud
## where something does (Assistant._studs_where_stood_on); a pass that tiles
## open studs should ask it first. [param ignore] is the part the studs
## belong to.
func standing_on(studs: Array, top: int, ignore: int = 0) -> Dictionary:
	var out: Dictionary = {}
	var tall: int = int(ceil((4.0 + 2.0) / CELL))    ## a stud is 4 LDU
	for raw: Variant in studs:
		var stud: Vector2i = raw
		var found: PackedInt64Array = blockers_boxes(PackedInt32Array([
			stud.x * CELLS_PER_STUD, top, stud.y * CELLS_PER_STUD,
			(stud.x + 1) * CELLS_PER_STUD, top + tall, (stud.y + 1) * CELLS_PER_STUD]),
			ignore)
		if not found.is_empty():
			out[stud] = found[0]
	return out


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
	revision += 1
	_boxes.clear()
	_bucket.clear()
	_column_bucket.clear()
	_bounds.clear()
	_rows.clear()
	_extent = PackedInt32Array()
	unseen.clear()
	see_through.clear()
	ahead = {}


## A copy to be read on another thread while this one goes on changing.
## Shallow, and still a copy: every value is a packed array, and a packed
## array is copied the moment either side writes to it, so nothing the
## live lattice does afterwards reaches this one. Without the columns,
## which only placing a brick by hand asks about.
func copy_for_reading() -> BrickLattice:
	var copy := BrickLattice.new()
	copy.keeps_columns = false
	copy._boxes = _boxes.duplicate()
	copy._bucket = _bucket.duplicate()
	copy._bounds = _bounds.duplicate()
	copy._rows = _rows.duplicate()
	copy._extent = _extent
	return copy


## [member _extent] grown round a box, low corner and high.
func _reach_round(bound: PackedInt32Array) -> void:
	if bound.size() < 6:
		return
	if _extent.is_empty():
		_extent = bound.duplicate()
		return
	for axis: int in 3:
		_extent[axis] = mini(_extent[axis], bound[axis])
		_extent[axis + 3] = maxi(_extent[axis + 3], bound[axis + 3])


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


## The highest surface under a rectangle of columns, high corner
## exclusive: [method surface_height] for a whole box at once, and never
## below [param floor_cell]. Where a part in hand rests, asked once for its
## footprint rather than once per column — a 2 x 4 brick is eight hundred
## columns.
func surface_under(lo_x: int, lo_z: int, hi_x: int, hi_z: int,
		floor_cell: int = 0) -> int:
	return floor_cell + rise_onto(PackedInt32Array([lo_x, floor_cell, lo_z, hi_x,
		floor_cell + 1, hi_z]), floor_cell)


## How far, in cells, boxes must rise for each to rest on whatever is under
## its columns, and for none to be below [param floor_cell]: the most of
## each box's highest surface under it less its bottom, and at least the
## floor less the lowest bottom. [param by_x] and [param by_z] move them
## across first. What several parts held together drop onto (Carry.aim).
##
## The parts under them are each asked once, by their bound first, the
## highest first, and no further once none left could lift them more.
## Asked box by box and every part in a column bucket box by box, a copy of
## eight Technic parts over 42082-1's crane rescanned the parts in the
## tower's columns for each of its hundreds of boxes: 320 ms a move, and a
## 2 x 4 brick column by column 600 ms (sweep-2026-10-16).
func rise_onto(packed: PackedInt32Array, floor_cell: int, by_x: int = 0,
		by_z: int = 0) -> int:
	# Boxes over the same columns rest by the lowest of them.
	var lowest: Dictionary = {}
	var low: int = 1 << 30
	var lo_x: int = 1 << 30
	var lo_z: int = 1 << 30
	var hi_x: int = -(1 << 30)
	var hi_z: int = -(1 << 30)
	var n: int = 0
	while n < packed.size():
		var key := Vector4i(packed[n] + by_x, packed[n + 2] + by_z, packed[n + 3] + by_x,
			packed[n + 5] + by_z)
		var bottom: int = packed[n + 1]
		if bottom < int(lowest.get(key, 1 << 30)):
			lowest[key] = bottom
		low = mini(low, bottom)
		lo_x = mini(lo_x, key.x)
		lo_z = mini(lo_z, key.y)
		hi_x = maxi(hi_x, key.z)
		hi_z = maxi(hi_z, key.w)
		n += 6
	if lowest.is_empty():
		return 0
	var rise: int = floor_cell - low
	# The parts whose bounds meet those columns, each once, by the top of
	# their bound, highest first.
	var near := PackedInt64Array()
	var ids := PackedInt64Array()
	var seen: Dictionary = {}
	for bx: int in range(_floor_div(lo_x, BUCKET), _floor_div(hi_x - 1, BUCKET) + 1):
		for bz: int in range(_floor_div(lo_z, BUCKET), _floor_div(hi_z - 1, BUCKET) + 1):
			var here: Variant = _column_bucket.get(Vector2i(bx, bz))
			if here == null:
				continue
			for brick_id: int in here:
				if seen.has(brick_id):
					continue
				seen[brick_id] = true
				var bound: PackedInt32Array = _bounds.get(brick_id, PackedInt32Array())
				var top: int = 1 << 29
				if bound.size() == 6:
					if bound[0] >= hi_x or lo_x >= bound[3] or bound[2] >= hi_z \
							or lo_z >= bound[5]:
						continue
					top = bound[4]
				near.append(((top + (1 << 30)) << 31) | ids.size())
				ids.append(brick_id)
	near.sort()
	var under: Array = lowest.keys()
	for k: int in range(near.size() - 1, -1, -1):
		if (near[k] >> 31) - (1 << 30) - low <= rise:
			break
		var theirs: PackedInt32Array = _boxes.get(ids[near[k] & ((1 << 31) - 1)],
			PackedInt32Array())
		var m: int = 0
		while m < theirs.size():
			var top: int = theirs[m + 4]
			if top - low > rise and theirs[m] < hi_x and lo_x < theirs[m + 3] \
					and theirs[m + 2] < hi_z and lo_z < theirs[m + 5]:
				for key: Vector4i in under:
					if top - int(lowest[key]) > rise and theirs[m] < key.z \
							and key.x < theirs[m + 3] and theirs[m + 2] < key.w \
							and key.y < theirs[m + 5]:
						rise = top - int(lowest[key])
			m += 6
	return rise


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


## Whether a cell is on the far side of the cut, where nothing is drawn.
func _cut_away(cell: Vector3i) -> bool:
	if cut.normal == Vector3.ZERO:
		return false
	return cut.distance_to((Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL) > 0.0


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
	# Only the stretch of the line through what was ever filled can meet
	# anything: marched from a cell before it, and given up past it. From
	# the eye, the march went cell by cell through the air to the model,
	# and through the air beyond it to its 20,000th cell on a line that
	# missed, every frame the view moved under a still pointer.
	if _extent.is_empty():
		return hit
	var room := AABB(Vector3(_extent[0], _extent[1], _extent[2]) * CELL,
		Vector3(_extent[3] - _extent[0], _extent[4] - _extent[1],
			_extent[5] - _extent[2]) * CELL).grow(CELL * 2.0)
	var span: Vector2 = _through(room, origin, dir)
	if span.x > span.y or span.y < 0.0 or span.x > max_distance:
		return hit
	var skipped: float = maxf(span.x - CELL * 2.0, 0.0)
	max_distance = minf(max_distance, span.y + CELL * 2.0) - skipped
	var met: Hit = _march(origin + dir * skipped, dir, max_distance)
	met.distance += skipped
	return met


## Where a line from [param origin] along [param dir] enters and leaves
## [param box]: (in, out) along it, in out of order when it misses.
static func _through(box: AABB, origin: Vector3, dir: Vector3) -> Vector2:
	var near: float = -INF
	var far: float = INF
	for axis: int in 3:
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(dir[axis]) < 1e-9:
			if origin[axis] < lo or origin[axis] > hi:
				return Vector2(1.0, 0.0)
			continue
		var a: float = (lo - origin[axis]) / dir[axis]
		var b: float = (hi - origin[axis]) / dir[axis]
		near = maxf(near, minf(a, b))
		far = minf(far, maxf(a, b))
	return Vector2(near, far)


func _march(origin: Vector3, dir: Vector3, max_distance: float) -> Hit:
	var hit := Hit.new()
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
		if owner != 0 and not unseen.has(owner) and not see_through.has(owner) \
				and not ahead.has(owner) and not _cut_away(cell):
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
