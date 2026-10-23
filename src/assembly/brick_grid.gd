## Every part of a world kept by a box of its own, in step with the world, so
## a line from the eye finds the few parts it may pass near without asking
## every one.
##
## A part in hand asked every connector of every part down which one the
## pointer was aimed at (JointSnap.aimed_at), and a sticker in hand every
## part which face was under the pointer (Stickers.face_at), at every move:
## 11 and 14 ms a move on a 4,139-part Technic set, headless, and many times
## that in a browser. [method along] gives back every part whose box the
## line passes through, and maybe a few beside it, in the world's order, so
## whoever asks them finds exactly what asking them all found.
##
## When the model changes only the parts added, taken off, moved or changed
## are measured again ([method follow]): made afresh after every part put
## down, a grid of that set's connectors was 60 to 80 ms.
class_name BrickGrid
extends RefCounted

## How wide a cell is, in LDU: a couple of studs, so a line through a big
## model crosses a hundred or so and a cell holds a handful of parts.
const CELL := 40.0
## Every box is grown by this much, in LDU, so a line that meets a box at
## a cell's very edge is not lost to rounding.
const SLACK := 1.0

## What a part is kept by: (brick, its mesh or null) -> [its box, or null
## for none; anything kept with it (kept_with); whether, with no box, it is
## to be asked every time].
var _measure: Callable
var _library: PartLibrary
var _world_id: int = 0
var _revision: int = -1
## Brick id -> [part id, transform, mesh's instance id, the cells it is in,
## what was kept with it].
var _kept: Dictionary = {}
## Vector3i -> {brick id: true}.
var _cells: Dictionary = {}
## Brick id -> its place in the world's order, and the brick.
var _order: Dictionary = {}
var _bricks: Dictionary = {}
## Parts with no box that are asked every time.
var _always: Dictionary = {}
var _bound := AABB()
var _bounded: bool = false


func _init(library: PartLibrary, measure: Callable) -> void:
	_library = library
	_measure = measure


## In step with [param world]: only what changed since the last time is
## measured again, and nothing is done while the world has not changed.
func follow(world: BrickWorld) -> void:
	if world.get_instance_id() == _world_id and world.revision == _revision:
		return
	if world.get_instance_id() != _world_id or world.brick_count() == 0:
		_kept.clear()
		_cells.clear()
		_always.clear()
		_bricks.clear()
		_bounded = false
	_world_id = world.get_instance_id()
	_revision = world.revision
	_order.clear()
	var n: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		_order[brick.id] = n
		n += 1
		_bricks[brick.id] = brick
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var mesh_id: int = mesh.get_instance_id() if mesh != null else 0
		var was: Variant = _kept.get(brick.id)
		if was != null and was[0] == brick.part_id and was[1] == brick.transform \
				and was[2] == mesh_id:
			continue
		if was != null:
			_forget(brick.id)
		_keep(brick, mesh, mesh_id)
	if _kept.size() > _order.size():
		for brick_id: int in _kept.keys():
			if not _order.has(brick_id):
				_forget(brick_id)
				_bricks.erase(brick_id)


## The bricks of [param part_ids] (part id -> true) measured again at the
## next [method follow], though they have not changed: what is kept with them
## has (a part's exact shape, come in a browser after it was put down).
func remeasure(part_ids: Dictionary) -> void:
	for brick_id: int in _kept.keys():
		if part_ids.has(_kept[brick_id][0]):
			_forget(brick_id)
	_revision = -1


## What was kept with [param brick_id] when it was measured.
func kept_with(brick_id: int) -> Variant:
	var was: Variant = _kept.get(brick_id)
	return was[4] if was != null else null


## The bricks in every cell the line from [param from] going [param way]
## passes through, no further along it than [param most] (in LDU), and those
## asked every time, each once, in the world's order: every part whose box
## the line meets there.
func along(from: Vector3, way: Vector3, most: float = INF) -> Array:
	var found: Dictionary = _always.duplicate()
	var dir: Vector3 = way.normalized()
	if _bounded and dir.length_squared() > 0.5:
		_through(from, dir, most, found)
	var ids: Array = found.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(_order[a]) < int(_order[b]))
	var out: Array = []
	for brick_id: int in ids:
		out.append(_bricks[brick_id])
	return out


func _through(from: Vector3, dir: Vector3, most: float, found: Dictionary) -> void:
	var span: Vector2 = BrickLattice._through(_bound, from, dir)
	var start: float = maxf(span.x, 0.0)
	var end: float = minf(span.y, most)
	if span.x > span.y or start > end:
		return
	var at: Vector3 = from + dir * start
	var cell: Vector3i = _cell_of(at)
	var step := Vector3i(1 if dir.x > 0.0 else -1, 1 if dir.y > 0.0 else -1,
		1 if dir.z > 0.0 else -1)
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for axis: int in 3:
		var d: float = dir[axis]
		if absf(d) < 1e-9:
			continue
		var boundary: float = (cell[axis] + (1 if d > 0.0 else 0)) * CELL
		t_max[axis] = start + (boundary - at[axis]) / d
		t_delta[axis] = CELL / absf(d)
	# Every cell from where it enters the room to where it leaves: no more
	# than the cells across the room on each axis, and a few for rounding.
	var size: Vector3 = _bound.size / CELL
	for _n: int in ceili(size.x + size.y + size.z) + 8:
		var here: Variant = _cells.get(cell)
		if here != null:
			found.merge(here)
		var axis: int = 0 if t_max.x <= t_max.y and t_max.x <= t_max.z \
			else (1 if t_max.y <= t_max.z else 2)
		if t_max[axis] > end:
			break
		cell[axis] += step[axis]
		t_max[axis] += t_delta[axis]


func _keep(brick: BrickWorld.Brick, mesh: Lbm.PartMesh, mesh_id: int) -> void:
	var measured: Array = _measure.call(brick, mesh)
	var cells: Array = []
	if not (measured[0] is AABB):
		if bool(measured[2]):
			_always[brick.id] = true
	else:
		var box: AABB = (measured[0] as AABB).abs().grow(SLACK)
		_bound = box if not _bounded else _bound.merge(box)
		_bounded = true
		var lo: Vector3i = _cell_of(box.position)
		var hi: Vector3i = _cell_of(box.end)
		for x: int in range(lo.x, hi.x + 1):
			for y: int in range(lo.y, hi.y + 1):
				for z: int in range(lo.z, hi.z + 1):
					var key := Vector3i(x, y, z)
					var here: Variant = _cells.get(key)
					if here == null:
						here = {}
						_cells[key] = here
					(here as Dictionary)[brick.id] = true
					cells.append(key)
	_kept[brick.id] = [brick.part_id, brick.transform, mesh_id, cells, measured[1]]


func _forget(brick_id: int) -> void:
	var was: Variant = _kept.get(brick_id)
	if was == null:
		return
	for key: Vector3i in was[3]:
		var here: Variant = _cells.get(key)
		if here != null:
			(here as Dictionary).erase(brick_id)
			if (here as Dictionary).is_empty():
				_cells.erase(key)
	_always.erase(brick_id)
	_kept.erase(brick_id)


static func _cell_of(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x / CELL), floori(point.y / CELL), floori(point.z / CELL))
