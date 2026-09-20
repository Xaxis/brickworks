## Placing and removing bricks with a mouse.
##
## Holds the three things that have to agree about a model and keeps them
## in step: the [BrickWorld] that draws it, the [BrickLattice] that knows
## what space is taken, and the undo history.
##
## Placement works the way it does in the hand. Point at a face, and the
## part goes against that face — on top of a stud surface, or out from a
## wall. What is under the cursor is found by marching the occupancy grid,
## which gives the brick and the face in one step, so there is never a
## question of which of two touching bricks was meant.
class_name Builder
extends Node3D

const GHOST_SHADER := preload("res://src/render/ghost.gdshader")

## The plane bricks rest on when nothing else is under them, in cells.
const GROUND_CELL := 0

var world: BrickWorld
var lattice: BrickLattice
var library: PartLibrary

## The part about to be placed, and the colour it will be placed in.
var held_part: String = "3001"
var held_color: int = 4
## Quarter turns about Y applied to the held part.
var held_rotation: int = 0

var _ghost: MeshInstance3D
var _ghost_material: ShaderMaterial
var _ghost_valid: bool = false
var _ghost_transform: Transform3D = Transform3D.IDENTITY
var _hovered: int = 0

## Undo entries, most recent last. Each is what to do to reverse a step.
var _history: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

signal placed(brick_id: int, part_id: String)
signal removed(brick_id: int)
signal preview_changed(part_id: String, valid: bool)
## The eyedropper took a part and colour off the model; the bin and the
## palette should follow.
signal picked(part_id: String, color_code: int)


func _init() -> void:
	# The lattice needs no scene tree, and creating it here rather than in
	# _ready means a Builder is usable the moment it exists — which the
	# headless checks rely on.
	lattice = BrickLattice.new()


func _ready() -> void:
	_ghost_material = ShaderMaterial.new()
	_ghost_material.shader = GHOST_SHADER
	_ghost = MeshInstance3D.new()
	_ghost.material_override = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


## Register a brick that was placed by something other than the mouse —
## loading a model, or the design assistant — so the lattice agrees.
func register(brick_id: int, part_id: String, at: Transform3D) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	var cells: Array[Vector3i] = _cells_for(part, at)
	lattice.occupy(brick_id, cells)
	return true


## Place the held part where the ghost is, if the ghost is legal.
func place() -> int:
	if not _ghost_valid:
		return 0
	var brick_id: int = world.add_brick(held_part, held_color, _ghost_transform)
	if brick_id == 0:
		return 0

	var part: Lbm.PartMesh = library.mesh_for(held_part)
	lattice.occupy(brick_id, _cells_for(part, _ghost_transform))

	_history.append({"undo": "remove", "brick": brick_id})
	_redo.clear()
	placed.emit(brick_id, held_part)
	return brick_id


## Remove whatever is under the cursor.
func remove_hovered() -> bool:
	if _hovered == 0:
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false

	_history.append({
		"undo": "add",
		"part": brick.part_id,
		"color": brick.color_code,
		"transform": brick.transform,
	})
	_redo.clear()

	lattice.release(_hovered)
	world.remove_brick(_hovered)
	removed.emit(_hovered)
	_hovered = 0
	return true


## Recolour the brick under the cursor, without taking it out and
## putting it back.
##
## Until this there was no way to change a brick once placed — the only
## edit was to remove it and rebuild, which on an interior brick means
## dismantling what is on top of it. BrickWorld could already do it;
## nothing had ever asked.
func paint_hovered(color_code: int) -> bool:
	if _hovered == 0:
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null or brick.color_code == color_code:
		return false

	_history.append({
		"undo": "recolor",
		"brick": _hovered,
		"color": brick.color_code,
	})
	_redo.clear()
	return world.recolor_brick(_hovered, color_code)


## Adopt the part and colour of the brick under the cursor.
##
## The fastest way to match something you built twenty bricks ago, and
## much faster than finding the part again in a catalogue of 28,319 —
## which is what anyone would otherwise have to do.
func pick_hovered() -> bool:
	if _hovered == 0:
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false
	held_part = brick.part_id
	held_color = brick.color_code
	held_rotation = _quarter_turns(brick.transform.basis)
	picked.emit(brick.part_id, brick.color_code)
	return true


## Quarter turns about Y. Measured off the X axis: Vector3.FORWARD is
## (0, 0, -1), so an unrotated basis read off it comes back a half turn
## out.
static func _quarter_turns(basis: Basis) -> int:
	var right: Vector3 = basis * Vector3.RIGHT
	return posmod(int(round(atan2(-right.z, right.x) / (PI * 0.5))), 4)


func undo() -> bool:
	if _history.is_empty():
		return false
	var step: Dictionary = _history.pop_back()
	_redo.append(_apply(step))
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var step: Dictionary = _redo.pop_back()
	_history.append(_apply(step))
	return true


## Carry out a history step and return the step that would reverse it.
func _apply(step: Dictionary) -> Dictionary:
	if step.get("undo", "") == "recolor":
		# Its own reverse: put the old colour back and remember the one
		# that was there, so redo works without a second kind of entry.
		var brick_id: int = int(step["brick"])
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			return step
		var was: int = brick.color_code
		world.recolor_brick(brick_id, int(step["color"]))
		return {"undo": "recolor", "brick": brick_id, "color": was}

	if step.get("undo", "") == "remove":
		var brick_id: int = int(step["brick"])
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			return step
		var reverse: Dictionary = {
			"undo": "add",
			"part": brick.part_id,
			"color": brick.color_code,
			"transform": brick.transform,
		}
		lattice.release(brick_id)
		world.remove_brick(brick_id)
		return reverse

	var part_id: String = step.get("part", "")
	var at: Transform3D = step.get("transform", Transform3D.IDENTITY)
	var new_id: int = world.add_brick(part_id, int(step.get("color", 0)), at)
	if new_id != 0:
		lattice.occupy(new_id, _cells_for(library.mesh_for(part_id), at))
	return {"undo": "remove", "brick": new_id}


## Work out where the held part would go, given a ray from the camera.
func update_preview(origin: Vector3, direction: Vector3) -> void:
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part == null:
		_ghost.visible = false
		_ghost_valid = false
		return

	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	_hovered = hit.brick_id

	var basis: Basis = Basis(Vector3.UP, held_rotation * PI * 0.5)
	var target: Vector3

	if hit.is_valid():
		# Against the face that was struck. On a top face that means
		# resting on it; on a side face it means butting up to it.
		target = BrickLattice.to_ldu(hit.adjacent())
	else:
		# Nothing under the cursor: fall to the ground plane.
		var ground := Plane(Vector3.UP, GROUND_CELL * BrickLattice.CELL)
		var landing: Variant = ground.intersects_ray(origin, direction)
		if landing == null:
			_ghost.visible = false
			_ghost_valid = false
			return
		target = landing

	_ghost_transform = _settle(part, basis, target, hit)
	var cells: Array[Vector3i] = _cells_for(part, _ghost_transform)
	_ghost_valid = not lattice.collides(cells)

	_ghost.mesh = part.surfaces[0]
	_ghost.transform = _ghost_transform
	_ghost.visible = true
	var tint: Color = library.color(held_color).rgb
	_ghost_material.set_shader_parameter("tint", tint)
	_ghost_material.set_shader_parameter("valid", _ghost_valid)
	preview_changed.emit(held_part, _ghost_valid)


## Snap a target point to the lattice and drop the part onto what is below.
func _settle(
	part: Lbm.PartMesh, basis: Basis, target: Vector3, hit: BrickLattice.Hit
) -> Transform3D:
	var box: AABB = _rotated_bounds(part, basis)

	# Snap across the stud grid, keeping the part's own phase: a part two
	# studs wide puts its studs at odd multiples of 10 LDU and a part one
	# stud wide puts its stud at zero.
	var footprint := Vector2i(
		int(round(box.size.x / BrickLattice.STUD)),
		int(round(box.size.z / BrickLattice.STUD)))
	var snapped: Vector3 = BrickLattice.snap_to_studs(target, footprint)

	# Then drop it: the resting height is the highest surface under any
	# column the part covers, so a part laid across a step sits on the step
	# rather than sinking into it.
	var columns: Array[Vector2i] = []
	var from := BrickLattice.to_cell(Vector3(
		snapped.x + box.position.x, 0.0, snapped.z + box.position.z))
	var to := BrickLattice.to_cell(Vector3(
		snapped.x + box.end.x, 0.0, snapped.z + box.end.z))
	for x: int in range(from.x, maxi(to.x, from.x + 1)):
		for z: int in range(from.z, maxi(to.z, from.z + 1)):
			columns.append(Vector2i(x, z))

	var rest_cell: int = lattice.resting_height(columns, GROUND_CELL)
	# Placing against a side face should not slide the part down onto the
	# floor, so a sideways hit keeps the height the face implies.
	if hit.is_valid() and hit.normal.y == 0:
		rest_cell = maxi(rest_cell, hit.adjacent().y)

	var y: float = rest_cell * BrickLattice.CELL - box.position.y
	return Transform3D(basis, Vector3(snapped.x, y, snapped.z))


func _rotated_bounds(part: Lbm.PartMesh, basis: Basis) -> AABB:
	var box: AABB = part.bounds
	var a: Vector3 = basis * box.position
	var b: Vector3 = basis * box.end
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return AABB(lo, hi - lo)


## The lattice cells a part's collision cover fills at a placement.
func _cells_for(part: Lbm.PartMesh, at: Transform3D) -> Array[Vector3i]:
	if part == null:
		return []
	var boxes: Array[AABB] = part.boxes
	if boxes.is_empty():
		# No cover was built for this part; fall back to its bounding box,
		# which over-reports rather than under-reports. That can refuse a
		# legal placement but never allows an illegal one.
		var box: AABB = part.bounds
		boxes = [AABB(
			Vector3(
				floor(box.position.x / BrickLattice.CELL),
				floor(box.position.y / BrickLattice.CELL),
				floor(box.position.z / BrickLattice.CELL)),
			Vector3(
				ceil(box.size.x / BrickLattice.CELL),
				ceil(box.size.y / BrickLattice.CELL),
				ceil(box.size.z / BrickLattice.CELL)))]
	return BrickLattice.cells_for(
		boxes, BrickLattice.to_cell(at.origin), at.basis)


func rotate_held(quarter_turns: int) -> void:
	held_rotation = posmod(held_rotation + quarter_turns, 4)


func hovered_brick() -> int:
	return _hovered


func hide_preview() -> void:
	_ghost.visible = false
	_ghost_valid = false


func history_depth() -> int:
	return _history.size()
