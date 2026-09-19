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

const CELLS_PER_STUD := 10    # 20 / 2
const CELLS_PER_PLATE := 4    # 8 / 2

## Cell -> brick id. One entry per occupied cell.
var _cells: Dictionary = {}
## Brick id -> PackedVector3Array of the cells it holds, for removal.
var _by_brick: Dictionary = {}
## Column (x, z) -> { y: how many cells are filled at that height }.
## Kept alongside the cell hash so "what is the surface here" is a lookup
## rather than a walk down four thousand empty cells.
var _columns: Dictionary = {}


static func to_cell(position: Vector3) -> Vector3i:
	"""LDU to whole cells, rounding towards negative infinity."""
	return Vector3i(
		int(floor(position.x / CELL + 0.5)),
		int(floor(position.y / CELL + 0.5)),
		int(floor(position.z / CELL + 0.5)))


static func to_ldu(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL, cell.y * CELL, cell.z * CELL)


## The cells a part's collision cover occupies at a given placement.
##
## ``basis`` must be one of the 24 axis-aligned orientations; anything else
## would put a box's corners between cells and there would be no honest
## integer answer. [method snap_basis] gives the nearest legal one.
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


## Would a part placed here overlap anything already placed?
##
## ``ignore`` lets a brick being dragged not collide with itself.
func collides(cells: Array[Vector3i], ignore: int = 0) -> bool:
	for cell: Vector3i in cells:
		var owner: int = _cells.get(cell, 0)
		if owner != 0 and owner != ignore:
			return true
	return false


## Which bricks a placement would run into. Useful for telling someone why.
func blockers(cells: Array[Vector3i], ignore: int = 0) -> PackedInt64Array:
	var found: Dictionary = {}
	for cell: Vector3i in cells:
		var owner: int = _cells.get(cell, 0)
		if owner != 0 and owner != ignore:
			found[owner] = true
	return PackedInt64Array(found.keys())


func occupy(brick_id: int, cells: Array[Vector3i]) -> void:
	var held := PackedVector3Array()
	held.resize(cells.size())
	for n: int in cells.size():
		var cell: Vector3i = cells[n]
		_cells[cell] = brick_id
		held[n] = Vector3(cell)

		var key := Vector2i(cell.x, cell.z)
		var column: Dictionary = _columns.get(key, {})
		column[cell.y] = int(column.get(cell.y, 0)) + 1
		_columns[key] = column
	_by_brick[brick_id] = held


func release(brick_id: int) -> void:
	var held: PackedVector3Array = _by_brick.get(brick_id, PackedVector3Array())
	for point: Vector3 in held:
		var cell := Vector3i(int(point.x), int(point.y), int(point.z))
		if _cells.get(cell, 0) != brick_id:
			continue
		_cells.erase(cell)

		var key := Vector2i(cell.x, cell.z)
		var column: Dictionary = _columns.get(key, {})
		var remaining: int = int(column.get(cell.y, 0)) - 1
		if remaining > 0:
			column[cell.y] = remaining
		else:
			column.erase(cell.y)
		if column.is_empty():
			_columns.erase(key)
		else:
			_columns[key] = column
	_by_brick.erase(brick_id)


func brick_at(cell: Vector3i) -> int:
	return _cells.get(cell, 0)


func occupied_cells() -> int:
	return _cells.size()


func clear() -> void:
	_cells.clear()
	_by_brick.clear()
	_columns.clear()


## The height a part would rest at in this column: one cell above the
## highest thing in it, or ``floor_cell`` if the column is empty.
func surface_height(cell_x: int, cell_z: int, floor_cell: int = 0) -> int:
	var column: Dictionary = _columns.get(Vector2i(cell_x, cell_z), {})
	if column.is_empty():
		return floor_cell
	var top: int = -0x7FFFFFFF
	for y: int in column:
		if y > top:
			top = y
	return top + 1


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
	var phase_x: float = 0.0 if footprint.x % 2 == 1 else STUD * 0.5
	var phase_z: float = 0.0 if footprint.y % 2 == 1 else STUD * 0.5
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
		var owner: int = _cells.get(cell, 0)
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
