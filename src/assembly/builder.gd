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
## Which way the held part's studs point. Everything used to point up,
## so the assistant could lay a brick on its side and the person using
## the app could not — which makes a tool that builds things you cannot
## edit.
var held_face: String = "up"

var _ghost: MeshInstance3D
var _ghost_material: ShaderMaterial
var _ghost_valid: bool = false
var _ghost_transform: Transform3D = Transform3D.IDENTITY
var _hovered: int = 0

## Bricks picked out to be worked on together, as id -> true.
##
## Every edit until now was one brick at a time, which is fine for
## placing and hopeless for changing your mind: recolouring a roof meant
## painting forty bricks one click at a time, and moving a wall two
## studs left meant taking it apart and rebuilding it.
var selection: Dictionary = {}

signal selection_changed(count: int)

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


## Take the brick under the cursor off the model and hold it.
##
## This is how a brick moves. There was no way to move one at all: the
## only edit was remove-and-rebuild, and a brick in the middle of
## something means taking off everything above it first.
##
## Lifting rather than dragging, because dragging needs a grab, a live
## re-solve of where it would land, and a drop — three things to get
## right — and lifting reuses the placement machinery already there. The
## brick comes off, becomes what you are holding, at its own colour and
## rotation, and the next click puts it down. Undo puts it back where it
## was, because the removal is an ordinary history step.
func lift_hovered() -> bool:
	if _hovered == 0:
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false

	held_part = brick.part_id
	held_color = brick.color_code
	held_face = BrickLattice.face_of(brick.transform.basis)
	held_rotation = BrickLattice.turns_about(brick.transform.basis, held_face)

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
	picked.emit(held_part, held_color)
	return true


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
	held_face = BrickLattice.face_of(brick.transform.basis)
	held_rotation = BrickLattice.turns_about(brick.transform.basis, held_face)
	picked.emit(brick.part_id, brick.color_code)
	return true


## Quarter turns about Y. Measured off the X axis: Vector3.FORWARD is
## (0, 0, -1), so an unrotated basis read off it comes back a half turn
## out.
static func _quarter_turns(basis: Basis) -> int:
	var right: Vector3 = basis * Vector3.RIGHT
	return posmod(int(round(atan2(-right.z, right.x) / (PI * 0.5))), 4)


## Forget what has been done, because it is about to stop being true.
##
## BrickWorld numbers bricks from one and starts again at one when it is
## cleared, so a history kept across a Clear or an Open refers to ids
## that now belong to entirely different bricks. Undo then does not fail
## — it succeeds, on the wrong model, removing whatever happens to hold
## the id a step remembers.
##
## Called wherever the world is replaced rather than left to each caller
## to remember, which is how this was missed: every one of those sites
## already clears the lattice on the adjacent line.
func forget_history() -> void:
	_history.clear()
	_redo.clear()


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
	# A group is one step as far as undo is concerned. Recolouring
	# forty bricks that needed forty undos to take back would not be an
	# improvement on recolouring them one at a time.
	if step.get("undo", "") == "group":
		var back: Array = []
		for inner: Variant in step.get("steps", []):
			back.append(_apply(inner))
		back.reverse()
		return {"undo": "group", "steps": back}

	if step.get("undo", "") == "move":
		var moving: int = int(step["brick"])
		var was: BrickWorld.Brick = world.get_brick(moving)
		if was == null:
			return step
		var previous: Transform3D = was.transform
		var to: Transform3D = step["transform"]
		lattice.release(moving)
		world.move_brick(moving, to)
		lattice.occupy(moving,
			_cells_for(library.mesh_for(was.part_id), to))
		return {"undo": "move", "brick": moving, "transform": previous}

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


# -- working on several at once ------------------------------------------


## Add the brick under the cursor to the selection, or take it out.
func toggle_hovered() -> bool:
	if _hovered == 0:
		return false
	if selection.erase(_hovered):
		selection_changed.emit(selection.size())
		return true
	selection[_hovered] = true
	selection_changed.emit(selection.size())
	return true


## Take everything a box on the screen covers.
##
## ``where`` turns a brick into its rectangle on screen; ``touching``
## says whether to take what the box merely overlaps or only what falls
## wholly inside it. Which of those a drag means is a CAD convention —
## left to right for wholly inside, right to left for touching — and
## the caller knows the direction, so it is passed in rather than
## guessed at here.
func select_in(box: Rect2, where: Callable, touching: bool,
		add: bool = true) -> int:
	if not add:
		selection.clear()
	var took: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		var on_screen: Variant = where.call(brick)
		if not (on_screen is Rect2):
			continue
		var caught: bool = (box.intersects(on_screen) if touching
			else box.encloses(on_screen))
		if caught and not selection.has(brick.id):
			selection[brick.id] = true
			took += 1
	if took > 0 or not add:
		selection_changed.emit(selection.size())
	return took


func clear_selection() -> void:
	if selection.is_empty():
		return
	selection.clear()
	selection_changed.emit(0)


## Everything of the same part and colour as the brick under the cursor.
##
## The way anyone actually wants to select a roof: point at one tile of
## it and take the lot.
func select_alike() -> int:
	if _hovered == 0:
		return 0
	var seed: BrickWorld.Brick = world.get_brick(_hovered)
	if seed == null:
		return 0
	for brick: BrickWorld.Brick in world.bricks():
		if (brick.part_id == seed.part_id
				and brick.color_code == seed.color_code):
			selection[brick.id] = true
	selection_changed.emit(selection.size())
	return selection.size()


## Drop from the selection anything that is no longer in the world, and
## say how many are left. Called before every operation, because a brick
## can go away by undo or by the assistant rebuilding the model.
func _living_selection() -> PackedInt64Array:
	var alive := PackedInt64Array()
	var gone: Array = []
	for brick_id: int in selection:
		if world.get_brick(brick_id) == null:
			gone.append(brick_id)
		else:
			alive.append(brick_id)
	for brick_id: int in gone:
		selection.erase(brick_id)
	if not gone.is_empty():
		selection_changed.emit(selection.size())
	return alive


func paint_selection(color_code: int) -> int:
	var alive: PackedInt64Array = _living_selection()
	var steps: Array = []
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.color_code == color_code:
			continue
		steps.append({"undo": "recolor", "brick": brick_id,
			"color": brick.color_code})
		world.recolor_brick(brick_id, color_code)
	if steps.is_empty():
		return 0
	_history.append({"undo": "group", "steps": steps})
	_redo.clear()
	return steps.size()


func remove_selection() -> int:
	var alive: PackedInt64Array = _living_selection()
	var steps: Array = []
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		steps.append({"undo": "add", "part": brick.part_id,
			"color": brick.color_code, "transform": brick.transform})
		lattice.release(brick_id)
		world.remove_brick(brick_id)
		removed.emit(brick_id)
	if steps.is_empty():
		return 0
	_history.append({"undo": "group", "steps": steps})
	_redo.clear()
	clear_selection()
	return steps.size()


## Shift the selection by whole cells, or refuse and change nothing.
##
## All or nothing on purpose. Moving the ones that fit and leaving the
## rest is how a wall becomes two half walls, and there is no way to see
## that it happened until later.
func move_selection(by: Vector3i) -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty() or by == Vector3i.ZERO:
		return 0

	# Out of the lattice first, so the selection does not collide with
	# where it used to be.
	var was: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		lattice.release(brick_id)

	var shift: Vector3 = BrickLattice.to_ldu(by)
	var landing: Dictionary = {}
	var blocked: bool = false
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to := Transform3D(brick.transform.basis,
			brick.transform.origin + shift)
		var cells: Array[Vector3i] = _cells_for(
			library.mesh_for(brick.part_id), to)
		for cell: Vector3i in cells:
			if cell.y < GROUND_CELL:
				blocked = true
				break
		if blocked or lattice.collides(cells):
			blocked = true
			break
		landing[brick_id] = {"at": to, "cells": cells}

	if blocked:
		for brick_id: int in alive:
			lattice.occupy(brick_id, _cells_for(
				library.mesh_for(world.get_brick(brick_id).part_id),
				was[brick_id]))
		return 0

	var steps: Array = []
	for brick_id: int in alive:
		steps.append({"undo": "move", "brick": brick_id,
			"transform": was[brick_id]})
		world.move_brick(brick_id, landing[brick_id]["at"])
		lattice.occupy(brick_id, landing[brick_id]["cells"])
	_history.append({"undo": "group", "steps": steps})
	_redo.clear()
	return steps.size()


## Work out where the held part would go, given a ray from the camera.
func update_preview(origin: Vector3, direction: Vector3) -> void:
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part == null:
		_ghost.visible = false
		_ghost_valid = false
		return

	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	_hovered = hit.brick_id

	var basis: Basis = BrickLattice.basis_for(held_face, held_rotation)
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
		# No cover was built for this part; fall back to its bounding
		# box, which over-reports rather than under-reports. That can
		# refuse a legal placement but never allows an illegal one.
		#
		# It did under-report: the size was rounded up but measured from
		# an origin that had been rounded down, which loses a cell
		# whenever the box neither starts nor ends on a boundary. Both
		# ends are taken outward now, which is what the paragraph above
		# was always claiming.
		var box: AABB = part.bounds
		# Pulled in by the moulding clearance at both ends. A round
		# brick's geometry overshoots its nominal box by a thousandth of
		# an LDU, and rounding that outward gives it a cell of collision
		# it does not have — so two of them standing side by side, which
		# is what a colonnade is, report as overlapping.
		var slack: float = BrickLattice.CLEARANCE
		var from := Vector3(
			floor((box.position.x + slack) / BrickLattice.CELL),
			floor((box.position.y + slack) / BrickLattice.CELL),
			floor((box.position.z + slack) / BrickLattice.CELL))
		var to := Vector3(
			ceil((box.end.x - slack) / BrickLattice.CELL),
			ceil((box.end.y - slack) / BrickLattice.CELL),
			ceil((box.end.z - slack) / BrickLattice.CELL))
		boxes = [AABB(from, (to - from).max(Vector3.ONE))]
	# cells_for takes the span between two rotated corners, which is the
	# rotated box only for the 24 orientations it documents as its
	# precondition; anything else spans a diagonal instead. Every basis
	# this project places is one of the 24, but one read out of somebody
	# else's .ldr need not be — and squaring it up first, which is what
	# used to happen here, meant a brick turned thirty degrees reserved
	# the cells of a brick turned none.
	var cell: Vector3i = BrickLattice.to_cell(at.origin)
	if BrickLattice.is_square_to_grid(at.basis):
		return BrickLattice.cells_for(boxes, cell, at.basis)
	return BrickLattice.cells_for_turned(boxes, cell, at.basis)


func rotate_held(quarter_turns: int) -> void:
	held_rotation = posmod(held_rotation + quarter_turns, 4)


## Roll the held part onto its next face: up, forward, down, back, and
## then over onto each side.
func tip_held(steps: int = 1) -> void:
	var faces: Array[String] = BrickLattice.FACES
	var at: int = maxi(faces.find(held_face), 0)
	held_face = faces[posmod(at + steps, faces.size())]


func hovered_brick() -> int:
	return _hovered


func hide_preview() -> void:
	_ghost.visible = false
	_ghost_valid = false


func history_depth() -> int:
	return _history.size()
