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

## A minifigure about to be put down, as its parts in the figure's own
## frame ([{part, color, at}], what Minifig.assemble gives), and the name
## its parts will carry as their group. Empty while a single part is
## held. A figure is put down the way a part is — pointed at a stud,
## turned with R — and its parts go in together, as one step to undo.
var held_figure: Array = []
var held_figure_name: String = ""
var _figure_ghosts: Array[MeshInstance3D] = []

## Several parts in hand at once, when something is: a paste, a duplicate,
## or a selection picked up to move it. See [Carry].
var carrying: Carry

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

## The bricks that are scenery (ModelStore.scenery), for the steps that
## move a baseplate into the model and back (FloorLayer.adopt).
var scenery: Dictionary = {}
## Puts a floor down (FloorLayer.put) and returns the one it replaced, for
## the step that changes what the model stands on. Unset, the step does
## nothing.
var floor_hook: Callable = Callable()

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
	carrying = Carry.new()
	add_child(carrying)


## The build step a part put down by hand goes in: the step the timeline is
## showing, while it shows the author's steps (StepsBar, which sets this),
## given the place in the tree the part went to. -1 is none: worked out.
var place_step: Callable = Callable()


func _new_step(brick: BrickWorld.Brick) -> int:
	return int(place_step.call(Assemblies.path_of(brick))) if place_step.is_valid() else -1


## Register a brick that was placed by something other than the mouse —
## loading a model, or the design assistant — so the lattice agrees.
##
## A part's cover is its cover at cell zero moved to its cell wherever
## boxes_for says so ([method _cover_moves]), so it is worked out once for
## each part and turn, with its bound and rows, and moved
## (BrickLattice.occupy_moved), as a move of a selection moves it. Worked
## out again for every part, a Technic set's 74 boxes a part were each
## turned, rounded and laid out by rows 4,139 times over (42082-1).
func register(brick_id: int, part_id: String, at: Transform3D) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		lattice.occupy_boxes(brick_id, boxes_for(part, at))
		return true
	finish_covers()
	if not _cover_moves(part, at):
		lattice.occupy_boxes(brick_id, boxes_for(part, at))
		return true
	var by_basis: Variant = _covers.get(part.get_instance_id())
	if by_basis == null:
		by_basis = {}
		_covers[part.get_instance_id()] = by_basis
	var cover: Variant = (by_basis as Dictionary).get(at.basis)
	if cover == null:
		var packed: PackedInt32Array = boxes_for(part, Transform3D(at.basis, Vector3.ZERO))
		var bound: PackedInt32Array = BrickLattice._bound_of(packed)
		cover = [packed, bound, BrickLattice._rows_of(packed, bound)
			if packed.size() > BrickLattice.ROWS_FROM * 6 else []]
		(by_basis as Dictionary)[at.basis] = cover
	lattice.occupy_moved(brick_id, cover, BrickLattice.to_cell(at.origin))
	return true


## Covers at cell zero ([method register]), by part (its mesh's instance)
## and then by its basis exactly. Main thread only.
var _covers: Dictionary = {}


## Whether [method boxes_for] gives [param part] at [param at] its cover at
## cell zero moved to the cell [param at] is in: everywhere but a part square
## to the grid and off the lattice, which is cut back to where it stands
## (BrickLattice.within), and a part with no cover, made from its cells.
static func _cover_moves(part: Lbm.PartMesh, at: Transform3D) -> bool:
	if part.boxes.is_empty():
		return false
	if not BrickLattice.is_off_lattice(at.origin):
		return true
	var stretch := Vector3(at.basis.x.length(), at.basis.y.length(), at.basis.z.length())
	if not stretch.is_equal_approx(Vector3.ONE) and at.basis.determinant() > 0.0:
		return true
	return not BrickLattice.is_square_to_grid(at.basis)


## Place the held part where the ghost is, if the ghost is legal.
func place() -> int:
	if is_carrying():
		return _put_carried()
	if not _ghost_valid:
		return 0
	if not held_figure.is_empty():
		return _place_figure()
	var brick_id: int = world.add_brick(held_part, held_color, _ghost_transform)
	if brick_id == 0:
		return 0
	# Into the sub-assembly being edited, when one is.
	set_path(world.get_brick(brick_id), place_group)
	world.get_brick(brick_id).step = _new_step(world.get_brick(brick_id))

	var part: Lbm.PartMesh = library.mesh_for(held_part)
	lattice.occupy_boxes(brick_id, boxes_for(part, _ghost_transform))

	_history.append({"undo": "remove", "brick": brick_id})
	_redo.clear()
	placed.emit(brick_id, held_part)
	return brick_id


## Remove whatever is under the cursor.
func remove_hovered() -> bool:
	if _hovered == 0 or locked.has(_hovered):
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false

	_history.append({
		"undo": "add",
		"part": brick.part_id,
		"color": brick.color_code,
		"transform": brick.transform,
		"group": brick.group, "unit": brick.unit, "step": brick.step, "was": brick.id,
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
	if _hovered == 0 or locked.has(_hovered):
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
## lift_hovered for a brick named rather than aimed at: X over a part with
## nothing in hand, where no ghost has aimed at anything.
func lift_brick(brick_id: int) -> bool:
	_hovered = brick_id
	return lift_hovered()


func lift_hovered() -> bool:
	if _hovered == 0 or locked.has(_hovered):
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false
	if _lift_figure(_hovered):
		return true

	held_part = brick.part_id
	held_color = brick.color_code
	held_face = BrickLattice.face_of(brick.transform.basis)
	held_rotation = BrickLattice.turns_about(brick.transform.basis, held_face)

	_history.append({
		"undo": "add",
		"part": brick.part_id,
		"color": brick.color_code,
		"transform": brick.transform,
		"group": brick.group, "unit": brick.unit, "step": brick.step, "was": brick.id,
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
	_renumbered.clear()
	locked.clear()
	# The selection names bricks by id too, and after an Open those ids
	# are the new model's: a selection carried across lit up bricks the
	# person never chose, and Delete would have taken them.
	if not selection.is_empty():
		selection.clear()
		selection_changed.emit(0)
	# A selection picked up to move has no way back once the model it
	# came off is gone.
	if carrying != null and carrying.lifted:
		carrying.drop()


func undo() -> bool:
	if _history.is_empty():
		return false
	var step: Dictionary = _history.pop_back()
	# Said before it is undone, while the brick a step names is still
	# there to name, and kept with the step that redoes it: the step
	# reversed would read backwards ("removed" for a placing redone).
	var words: String = _words_for(step)
	var back: Dictionary = _apply(step)
	back["words"] = words
	_redo.append(back)
	settled = _history.back() if not _history.is_empty() else {}
	# What an undo took away is no longer selected: an outline round
	# nothing, and a Delete that finds nothing to delete.
	_living_selection()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var step: Dictionary = _redo.pop_back()
	var again: Dictionary = _apply(step)
	if step.has("words"):
		again["words"] = step["words"]
	_history.append(again)
	settled = again
	_living_selection()
	return true


## The newest step of the history when an undo or a redo left it newest:
## what followed from it when it was made (the other copies of an
## assembly, Assemblies.after_edit) is in it already, so there is nothing
## to follow up. Anything newer is not it.
var settled: Dictionary = {}


## How many parts the next undo (or with [param again], redo) changes: a
## group's steps, or one.
func next_change_size(again: bool = false) -> int:
	var steps: Array = _redo if again else _history
	if steps.is_empty():
		return 0
	var step: Dictionary = steps.back()
	return (step.get("steps", []) as Array).size() if step.get("undo", "") == "group" else 1


## What a redo would put back, in words: "placed Brick 2 x 4".
func redo_words() -> String:
	return str(_redo.back().get("words", "")) if not _redo.is_empty() else ""


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
		var reverse: Dictionary = {"undo": "group", "steps": back}
		# What it is called comes back with it, so a step redone reads
		# the same in the history as when it was first done.
		if step.has("words"):
			reverse["words"] = step["words"]
		return reverse

	if step.get("undo", "") == "move":
		var moving: int = _live(int(step["brick"]))
		var was: BrickWorld.Brick = world.get_brick(moving)
		if was == null:
			return step
		var previous: Transform3D = was.transform
		var to: Transform3D = step["transform"]
		# Moved without turning by whole cells, as a nudge and its undo are:
		# its cover moved, not worked out again from the part.
		var cells: Variant = _cells_moved(previous, to)
		if cells != null and not lattice.boxes_of(moving).is_empty():
			world.move_brick(moving, to)
			lattice.shift(moving, cells)
			return {"undo": "move", "brick": moving, "transform": previous}
		lattice.release(moving)
		world.move_brick(moving, to)
		lattice.occupy_boxes(moving,
			boxes_for(library.mesh_for(was.part_id), to))
		return {"undo": "move", "brick": moving, "transform": previous}

	# What the model stands on: put the floor the step names down, and the
	# step that puts back the one it replaced is the reverse.
	if step.get("undo", "") == "floor":
		var was: Variant = floor_hook.call(step["floor"]) if floor_hook.is_valid() \
			else step["floor"]
		return {"undo": "floor", "floor": was}

	# A baseplate made part of the model or scenery again: the brick stays
	# where it is, and only which of the two it belongs to changes.
	if step.get("undo", "") == "scenery":
		var plate_id: int = _live(int(step["brick"]))
		if world.get_brick(plate_id) == null:
			return step
		var was_scenery: bool = scenery.has(plate_id)
		if bool(step["scenery"]):
			scenery[plate_id] = true
			selection.erase(plate_id)
		else:
			scenery.erase(plate_id)
		return {"undo": "scenery", "brick": plate_id, "scenery": was_scenery}

	if step.get("undo", "") == "regroup":
		var named: BrickWorld.Brick = world.get_brick(_live(int(step["brick"])))
		if named == null:
			return step
		var before: String = named.group
		var before_unit: String = named.unit
		named.group = str(step["group"])
		named.unit = str(step.get("unit", named.unit))
		return {"undo": "regroup", "brick": named.id, "group": before, "unit": before_unit}

	# A part put in another build step, and a sub-assembly's copy (see
	# AuthorSteps): each its own reverse, the step it had kept.
	if step.get("undo", "") == "restep":
		var stepped: BrickWorld.Brick = world.get_brick(_live(int(step["brick"])))
		if stepped == null:
			return step
		var had: int = stepped.step
		stepped.step = int(step["step"])
		return {"undo": "restep", "brick": stepped.id, "step": had}

	# A section broken out of the model or put back (Sections): which
	# sections are out, and where each came from, set back to what the step
	# kept; the record it replaced is the reverse.
	if step.get("undo", "") == "sectionout":
		var section: String = str(step["path"])
		var had: Variant = world.broken_out.get(section)
		var record: Variant = step.get("record")
		if record is Dictionary:
			world.broken_out[section] = record
		else:
			world.broken_out.erase(section)
		return {"undo": "sectionout", "path": section, "record": had}

	if step.get("undo", "") == "unitstep":
		var unit: String = str(step["unit"])
		var held: int = int(world.unit_steps.get(unit, -1))
		if int(step["step"]) < 0:
			world.unit_steps.erase(unit)
		else:
			world.unit_steps[unit] = int(step["step"])
		return {"undo": "unitstep", "unit": unit, "step": held}

	if step.get("undo", "") == "recolor":
		# Its own reverse: put the old colour back and remember the one
		# that was there, so redo works without a second kind of entry.
		var brick_id: int = _live(int(step["brick"]))
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			return step
		var was: int = brick.color_code
		world.recolor_brick(brick_id, int(step["color"]))
		return {"undo": "recolor", "brick": brick_id, "color": was}

	if step.get("undo", "") == "remove":
		var brick_id: int = _live(int(step["brick"]))
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			return step
		var reverse: Dictionary = {
			"undo": "add",
			"part": brick.part_id,
			"color": brick.color_code,
			"transform": brick.transform,
			"group": brick.group, "unit": brick.unit, "step": brick.step, "was": brick.id,
			"cover": lattice.cover_of(brick_id),
		}
		lattice.release(brick_id)
		world.remove_brick(brick_id)
		return reverse

	var part_id: String = step.get("part", "")
	var at: Transform3D = step.get("transform", Transform3D.IDENTITY)
	var new_id: int = world.add_brick(part_id, int(step.get("color", 0)), at)
	if new_id != 0:
		world.get_brick(new_id).group = str(step.get("group", ""))
		world.get_brick(new_id).unit = str(step.get("unit", ""))
		world.get_brick(new_id).step = int(step.get("step", -1))
		# Put back where it was taken off: the cover it had then, kept with
		# the step, rather than worked out again from the part.
		var cover: Variant = step.get("cover")
		if cover is Array and not ((cover as Array)[0] as PackedInt32Array).is_empty():
			lattice.occupy_moved(new_id, cover, Vector3i.ZERO)
		else:
			lattice.occupy_boxes(new_id,
				boxes_for(library.mesh_for(part_id), at))
		# The brick that comes back is a new id. Steps further back that
		# name the one that went — a paint before a swap, a move before a
		# removal — are read through this, or undoing past it did nothing.
		if step.has("was"):
			_renumbered[int(step["was"])] = new_id
	return {"undo": "remove", "brick": new_id}


## Brick ids that went and came back as another: old id -> new id. Ids
## are never reused within a world, so the chain only grows until the
## world is replaced, which forgets it with the history.
var _renumbered: Dictionary = {}


func _live(brick_id: int) -> int:
	var seen: int = 0
	while _renumbered.has(brick_id) and seen < 64:
		brick_id = int(_renumbered[brick_id])
		seen += 1
	return brick_id


# -- working on several at once ------------------------------------------


## What a click with Select on this brick takes: none for a locked brick.
func takes(brick_id: int) -> PackedInt64Array:
	if brick_id == 0 or locked.has(brick_id):
		return PackedInt64Array()
	# A sub-assembly is one thing to whoever points at it, at the level
	# being edited; and nothing outside the one being edited is.
	if unit_of.is_valid():
		return unit_of.call(brick_id)
	# A figure is one thing too. Picking out its arm alone and moving it
	# would leave the arm floating beside the figure, which is not an edit
	# anybody means. Asked only here, where it is used: asked first and
	# thrown away, it was the hover's 180 ms over a panel of Brick Art,
	# 170 parts asked whether they were a figure (2026-10-15).
	var members: PackedInt64Array = figure_of(brick_id)
	return members if members.size() > 1 else PackedInt64Array([brick_id])


## Add the brick under the cursor to the selection, or take it out.
func toggle_hovered() -> bool:
	var members: PackedInt64Array = takes(_hovered)
	if members.is_empty():
		return false
	if members.size() > 1:
		var all_in: bool = true
		for brick_id: int in members:
			all_in = all_in and selection.has(brick_id)
		for brick_id: int in members:
			if all_in:
				selection.erase(brick_id)
			else:
				selection[brick_id] = true
		selection_changed.emit(selection.size())
		return true
	if selection.erase(_hovered):
		selection_changed.emit(selection.size())
		return true
	selection[_hovered] = true
	selection_changed.emit(selection.size())
	return true


## Pick one brick out, as a click with the Select tool does: the
## selection becomes it (its whole figure, for a minifigure part), or with
## ``add`` it is added or taken away.
func select_brick(brick_id: int, add: bool) -> bool:
	if brick_id == 0 or locked.has(brick_id) or world.get_brick(brick_id) == null:
		return false
	if not add:
		selection.clear()
	var was: int = _hovered
	_hovered = brick_id
	var done: bool = toggle_hovered()
	_hovered = was
	return done


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
		if caught and not selection.has(brick.id) and not locked.has(brick.id):
			# A box round part of a sub-assembly takes all of it.
			var members: PackedInt64Array = unit_of.call(brick.id) if unit_of.is_valid() \
				else PackedInt64Array([brick.id])
			for member: int in members:
				if not selection.has(member) and not locked.has(member):
					selection[member] = true
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
				and brick.color_code == seed.color_code
				and not locked.has(brick.id)):
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
			"color": brick.color_code, "transform": brick.transform,
			"group": brick.group, "unit": brick.unit, "step": brick.step, "was": brick.id,
			"cover": lattice.cover_of(brick_id)})
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
	if by == Vector3i.ZERO:
		return 0
	var shift: Vector3 = BrickLattice.to_ldu(by)
	return _reposition(func(at: Transform3D) -> Transform3D:
		return Transform3D(at.basis, at.origin + shift), "", by)


## Turn the selection a quarter at a time about the stud nearest its
## middle, where it stands, or refuse and change nothing.
##
## About a stud, so that every stud of every part lands on another stud.
## Nothing could turn a part once it was down: the only way to face a
## finished window the other way was to take it apart and build it again.
func turn_selection(quarter_turns: int) -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty() or posmod(quarter_turns, 4) == 0:
		return 0
	var bricks: Array = []
	for brick_id: int in alive:
		bricks.append(world.get_brick(brick_id))
	# The same point again for a selection turned again, so four turns
	# bring it back exactly where it was: the middle of a turned box can
	# round to a different stud than the middle of the box before it.
	var pivot: Vector3 = Carry.pivot_of(bricks, library)
	if _turned_last == _turn_state(alive):
		pivot = _turned_about
	var around: Transform3D = Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(Vector3.UP, quarter_turns * PI * 0.5), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var turned: int = _reposition(func(at: Transform3D) -> Transform3D:
		return _tidy(around * at, BrickLattice.is_square_to_grid(at.basis)),
		"turned %s" % _many(alive.size()))
	if turned > 0:
		_turned_about = pivot
		_turned_last = _turn_state(alive)
	return turned


## Turn the selection about the vertical by any angle, as one step: the
## Rotate tool and R at a turn step finer than a quarter. A right angle
## goes through turn_selection, which keeps every stud on a stud; anything
## else leaves the parts off the grid, held as turned covers the way a
## swung hinge is.
func turn_selection_by(degrees: float) -> int:
	var quarters: float = degrees / 90.0
	if is_equal_approx(quarters, roundf(quarters)):
		return turn_selection(roundi(quarters))
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0
	var bricks: Array = []
	for brick_id: int in alive:
		bricks.append(world.get_brick(brick_id))
	var pivot: Vector3 = Carry.pivot_of(bricks, library)
	if _turned_last == _turn_state(alive):
		pivot = _turned_about
	var around: Transform3D = Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(Vector3.UP, deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var turned: int = _reposition(func(at: Transform3D) -> Transform3D:
		var to: Transform3D = around * at
		to = Transform3D(to.basis.orthonormalized(), to.origin)
		return _tidy(to, BrickLattice.is_square_to_grid(to.basis)),
		"turned %s %d°" % [_many(alive.size()), roundi(degrees)])
	if turned > 0:
		_turned_about = pivot
		_turned_last = _turn_state(alive)
	return turned


## Turn the selection by any turn at all, about the point its turns go
## round, as one step: the inspector's Turn, Tilt and Roll together. A turn
## about the upright goes through [method turn_selection_by], which keeps
## a right angle on the studs; any other is about the selection's middle,
## its parts held as turned covers off the grid as a hinged panel's are.
## Refused, changing nothing, where it would run into something.
func turn_selection_basis(turn: Basis, words: String = "") -> int:
	turn = turn.orthonormalized()
	if turn.is_equal_approx(Basis.IDENTITY):
		return 0
	if (turn * Vector3.UP).dot(Vector3.UP) > 0.99999:
		var x: Vector3 = turn * Vector3.RIGHT
		return turn_selection_by(rad_to_deg(atan2(-x.z, x.x)))
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0
	var middle: Vector3 = _bounds_of(alive, Transform3D.IDENTITY).get_center()
	var around: Transform3D = Transform3D(Basis.IDENTITY, middle) \
		* Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -middle)
	return _reposition(func(at: Transform3D) -> Transform3D:
		var to: Transform3D = around * at
		to = Transform3D(to.basis.orthonormalized(), to.origin)
		return _tidy(to, BrickLattice.is_square_to_grid(to.basis)),
		words if not words.is_empty() else "turned %s" % _many(alive.size()))


## Tip the selection a quarter over, about a level axis through its middle
## (``axis`` is x or z), keeping its bottom where it was. Studio's up and
## down arrows; T here. One step; refused, changing nothing, where it would
## run into something.
func tip_selection(axis: Vector3, quarters: int) -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty() or posmod(quarters, 4) == 0:
		return 0
	var box: AABB = _bounds_of(alive, Transform3D.IDENTITY)
	var middle: Vector3 = box.get_center()
	var around: Transform3D = Transform3D(Basis.IDENTITY, middle) \
		* Transform3D(Basis(axis.normalized(), quarters * PI * 0.5), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -middle)
	var turned: AABB = _bounds_of(alive, around)
	var shift := Vector3(0.0, box.position.y - turned.position.y, 0.0)
	var lay: Transform3D = Transform3D(Basis.IDENTITY, shift) * around
	return _reposition(func(at: Transform3D) -> Transform3D:
		return _tidy(lay * at, true), "tipped %s over" % _many(alive.size()))


## The box round some bricks, each moved by ``by`` first.
func _bounds_of(ids: PackedInt64Array, by: Transform3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			continue
		var here: AABB = ((by * brick.transform) * mesh.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return box


## What a selection turned last looked like after the turn, and what it
## was turned about.
var _turned_last: String = ""
var _turned_about: Vector3 = Vector3.ZERO


func _turn_state(ids: PackedInt64Array) -> String:
	var parts := PackedStringArray()
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			parts.append("%d %s" % [brick_id, brick.transform])
	parts.sort()
	return "|".join(parts)


## How many whole cells [param to] is from [param from] when it is the same
## turn moved by whole cells, so the part covers the same cells moved
## (BrickLattice.shift); null for anything else.
static func _cells_moved(from: Transform3D, to: Transform3D) -> Variant:
	if from.basis != to.basis:
		return null
	var by: Vector3 = (to.origin - from.origin) / BrickLattice.CELL
	var cells := Vector3i(roundi(by.x), roundi(by.y), roundi(by.z))
	var off: Vector3 = (by - Vector3(cells)).abs()
	if maxf(off.x, maxf(off.y, off.z)) > 0.001:
		return null
	if BrickLattice.to_cell(to.origin) != BrickLattice.to_cell(from.origin) + cells:
		return null
	return cells


## A transform with the arithmetic's dust taken off: a turned basis put
## back on the axes it was on, and a position to the thousandth of an LDU
## LDraw writes. Turned a right angle four times, it drifts otherwise.
static func _tidy(at: Transform3D, square: bool) -> Transform3D:
	var basis: Basis = BrickLattice.snap_basis(at.basis) if square else at.basis
	var origin := Vector3(snappedf(at.origin.x, 0.001),
		snappedf(at.origin.y, 0.001), snappedf(at.origin.z, 0.001))
	return Transform3D(basis, origin)


## Put every selected brick where ``to`` says, as one step, or none of
## them if any would go through another brick or the floor.
func _reposition(to: Callable, words: String = "", by_cells: Variant = null) -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0

	# Out of the lattice first, so the selection does not collide with
	# where it used to be. A move by whole cells keeps each cover, to put
	# back moved (BrickLattice.occupy_moved).
	var was: Dictionary = {}
	var covers: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		if by_cells != null:
			covers[brick_id] = lattice.cover_of(brick_id)
		lattice.release(brick_id)

	var landing: Dictionary = {}
	var blocked: bool = false
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to_here: Transform3D = to.call(brick.transform)
		var shifted: bool = by_cells != null \
			and not (covers[brick_id][0] as PackedInt32Array).is_empty() \
			and _cells_moved(brick.transform, to_here) == by_cells
		var packed: PackedInt32Array = BrickLattice.moved_by(covers[brick_id][0], by_cells) \
			if shifted else boxes_for(library.mesh_for(brick.part_id), to_here)
		# Through the floor if any box starts below it. The low corner
		# is every sixth int, so the test is the box's bottom rather
		# than every cell inside it.
		var n: int = 1
		while n < packed.size():
			if packed[n] < GROUND_CELL:
				blocked = true
				break
			n += 6
		if blocked or lattice.collides_boxes(packed):
			blocked = true
			break
		landing[brick_id] = {"at": to_here, "boxes": packed, "shifted": shifted}

	if blocked:
		for brick_id: int in alive:
			if covers.has(brick_id) and not (covers[brick_id][0] as PackedInt32Array).is_empty():
				lattice.occupy_moved(brick_id, covers[brick_id], Vector3i.ZERO)
			else:
				lattice.occupy_boxes(brick_id, boxes_for(
					library.mesh_for(world.get_brick(brick_id).part_id),
					was[brick_id]))
		return 0

	var steps: Array = []
	for brick_id: int in alive:
		steps.append({"undo": "move", "brick": brick_id,
			"transform": was[brick_id]})
		world.move_brick(brick_id, landing[brick_id]["at"])
		if bool(landing[brick_id]["shifted"]):
			lattice.occupy_moved(brick_id, covers[brick_id], by_cells)
		else:
			lattice.occupy_boxes(brick_id, landing[brick_id]["boxes"])
	var step: Dictionary = {"undo": "group", "steps": steps}
	if not words.is_empty():
		step["words"] = words
	_history.append(step)
	_redo.clear()
	return steps.size()


## Move each of these bricks to its own new place, as one step: brick id
## -> Transform3D. Each that has room goes; one that would run into
## something stays where it was. Returns how many moved.
func move_bricks(moves: Dictionary) -> int:
	var was: Dictionary = {}
	for brick_id: int in moves:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		was[brick_id] = brick.transform
		lattice.release(brick_id)
	var steps: Array = []
	for brick_id: int in was:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var to: Transform3D = moves[brick_id]
		var packed: PackedInt32Array = boxes_for(part, to)
		if lattice.collides_boxes(packed):
			lattice.occupy_boxes(brick_id, boxes_for(part, was[brick_id]))
			continue
		world.move_brick(brick_id, to)
		lattice.occupy_boxes(brick_id, packed)
		steps.append({"undo": "move", "brick": brick_id, "transform": was[brick_id]})
	if steps.is_empty():
		return 0
	_history.append({"undo": "group", "steps": steps,
		"words": "seated %s on their studs" % _many(steps.size())})
	_redo.clear()
	return steps.size()


## Swap every selected brick for another part, in its colour, where it
## stands: a wall of 1 x 2s made 1 x 2 masonry bricks, a plain tile made a
## printed one. One step to undo. A part that would not fit where the old
## one was is left as it was. Returns [how many swapped, how many did not].
##
## Kept on its studs: a part of a different footprint is centred on the
## stud grid its own way, and stands on what the old one stood on. With
## [param in_place], exactly where the old one stood: a printed version of
## the same mould (PrintStudio.swap_to), whose print can reach a hair past
## the plain part's box, is the same part and must not move.
func replace_selection(part_id: String, in_place: bool = false) -> Vector2i:
	var alive: PackedInt64Array = _living_selection()
	var into: Lbm.PartMesh = library.mesh_for(part_id)
	if alive.is_empty() or into == null:
		return Vector2i.ZERO
	var steps: Array = []
	var refused: int = 0
	var swapped := PackedInt64Array()
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.part_id == part_id:
			continue
		var was: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var at: Transform3D = brick.transform if in_place \
			else _in_place_of(brick.transform, was, into)
		lattice.release(brick_id)
		var packed: PackedInt32Array = boxes_for(into, at)
		if lattice.collides_boxes(packed):
			lattice.occupy_boxes(brick_id, boxes_for(was, brick.transform))
			refused += 1
			continue
		var made: int = world.add_brick(part_id, brick.color_code, at)
		if made == 0:
			lattice.occupy_boxes(brick_id, boxes_for(was, brick.transform))
			refused += 1
			continue
		world.get_brick(made).group = brick.group
		world.get_brick(made).unit = brick.unit
		world.get_brick(made).step = brick.step
		lattice.occupy_boxes(made, packed)
		steps.append({"undo": "remove", "brick": made})
		steps.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
			"transform": brick.transform, "group": brick.group, "unit": brick.unit,
			"step": brick.step, "was": brick.id})
		world.remove_brick(brick_id)
		removed.emit(brick_id)
		swapped.append(made)
	if steps.is_empty():
		return Vector2i(0, refused)
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	_history.append({"undo": "group", "steps": steps, "words": "swapped %s for %s" % [
		_many(swapped.size()), Inventory._tidy(info.name) if info != null else part_id]})
	_redo.clear()
	selection.clear()
	for brick_id: int in swapped:
		selection[brick_id] = true
	selection_changed.emit(selection.size())
	return Vector2i(swapped.size(), refused)


## The selection made into its mirror image, in place, across the plane
## through its middle square to world axis ``axis`` (0 for x, 2 for z).
## Handed parts are swapped for their other hand (Mirror.counterpart).
## All or nothing, one step. Returns how many, or zero when it would run
## into something.
func mirror_selection(axis: int) -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0
	var bricks: Array = []
	for brick_id: int in alive:
		bricks.append(world.get_brick(brick_id))
	var pivot: Vector3 = Carry.pivot_of(bricks, library)
	var across: float = pivot[axis]
	var plan: Array = []
	for brick: BrickWorld.Brick in bricks:
		var part: String = brick.part_id
		var other: String = Mirror.counterpart(library, part)
		if not other.is_empty() and library.mesh_for(other) != null:
			part = other
		var at: Transform3D = _tidy(Mirror.reflected(brick.transform, axis, across),
			BrickLattice.is_square_to_grid(brick.transform.basis))
		plan.append({"brick": brick, "part": part, "at": at})
	for brick_id: int in alive:
		lattice.release(brick_id)
	var blocked: bool = false
	for item: Dictionary in plan:
		var packed: PackedInt32Array = boxes_for(library.mesh_for(str(item["part"])), item["at"])
		item["boxes"] = packed
		if lattice.collides_boxes(packed):
			blocked = true
			break
	if blocked:
		for brick: BrickWorld.Brick in bricks:
			lattice.occupy_boxes(brick.id, boxes_for(library.mesh_for(brick.part_id),
				brick.transform))
		return 0
	var steps: Array = []
	var made := PackedInt64Array()
	for item: Dictionary in plan:
		var brick: BrickWorld.Brick = item["brick"]
		steps.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
			"transform": brick.transform, "group": brick.group, "unit": brick.unit,
			"step": brick.step, "was": brick.id})
		world.remove_brick(brick.id)
		removed.emit(brick.id)
	for item: Dictionary in plan:
		var brick: BrickWorld.Brick = item["brick"]
		var new_id: int = world.add_brick(str(item["part"]), brick.color_code, item["at"])
		if new_id == 0:
			continue
		world.get_brick(new_id).group = brick.group
		world.get_brick(new_id).unit = brick.unit
		world.get_brick(new_id).step = brick.step
		lattice.occupy_boxes(new_id, item["boxes"])
		steps.push_front({"undo": "remove", "brick": new_id})
		made.append(new_id)
	_history.append({"undo": "group", "steps": steps,
		"words": "mirrored %s" % _many(made.size())})
	_redo.clear()
	selection.clear()
	for brick_id: int in made:
		selection[brick_id] = true
	selection_changed.emit(selection.size())
	return made.size()


## The sub-assembly a part put down goes into: the one being edited
## (Assemblies.entered), "" for the model.
var place_group: String = ""
## What a click on a brick selects with it, brick id -> PackedInt64Array:
## its whole sub-assembly (Assemblies.unit_of). Unset, a brick alone, or
## its minifigure.
var unit_of: Callable = Callable()
## The path a pasted part's path becomes, (path, renamed so far) -> path
## (Assemblies.group_for_copy). Unset, an assembly pasted is renamed as a
## new one.
var copy_group: Callable = Callable()


## Put a brick at a place in the tree of sub-assemblies: its unit the path,
## its group the path's outermost kind.
static func set_path(brick: BrickWorld.Brick, path: String) -> void:
	brick.unit = path
	brick.group = Assemblies.group_of(path)


## Move bricks to other places in the tree, as one step: brick id -> path.
func regroup(changes: Dictionary, words: String) -> int:
	var steps: Array = []
	for brick_id: int in changes:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var path: String = str(changes[brick_id])
		if brick == null or Assemblies.path_of(brick) == path:
			continue
		steps.append({"undo": "regroup", "brick": brick_id, "group": brick.group,
			"unit": brick.unit})
		set_path(brick, path)
	if steps.is_empty():
		return 0
	_history.append({"undo": "group", "steps": steps, "words": words})
	_redo.clear()
	return steps.size()


## The newest step of the history, or nothing.
func last_step() -> Dictionary:
	return _history.back() if not _history.is_empty() else {}


## Every place in the tree a history step touched: of the bricks it moved,
## painted or put down, and of those it took off or regrouped.
func touched_groups(step: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	_touched(step, out)
	return out


func _touched(step: Dictionary, out: Dictionary) -> void:
	if step.get("undo", "") == "group":
		for inner: Variant in step.get("steps", []):
			_touched(inner, out)
		return
	if step.has("group") or step.has("unit"):
		out[Assemblies.path_from(str(step.get("group", "")), str(step.get("unit", "")))] = true
	if step.has("brick"):
		var brick: BrickWorld.Brick = world.get_brick(_live(int(step["brick"])))
		if brick != null:
			out[Assemblies.path_of(brick)] = true


## Fold more steps into the newest, so one undo takes back both: what a
## person did and what followed from it (the other copies of an assembly).
func extend_last(steps: Array) -> void:
	if steps.is_empty():
		return
	if _history.is_empty():
		_history.append({"undo": "group", "steps": steps})
		return
	var last: Dictionary = _history.back()
	if last.get("undo", "") != "group":
		var words: String = _words_for(last)
		last = {"undo": "group", "steps": [last], "words": words}
		_history[_history.size() - 1] = last
	(last["steps"] as Array).append_array(steps)


## Everything kept since the history was [param depth] deep, as one step:
## one call of a session's tool is one undo, however many of the window's
## own commands it took (AppTools). The newest first, as they are undone.
func fold_since(depth: int) -> void:
	if _history.size() <= depth + 1:
		return
	var steps: Array = []
	var said := PackedStringArray()
	while _history.size() > depth:
		var last: Dictionary = _history.pop_back()
		said.insert(0, _words_for(last))
		steps.append(last)
	_history.append({"undo": "group", "steps": steps, "words": "; ".join(said)})


## A brick laid again as another number is the same brick to the history:
## a baseplate taken up and put back by a change of floor (FloorLayer).
func renumber(old_id: int, new_id: int) -> void:
	if old_id != new_id:
		_renumbered[old_id] = new_id


## Keep [param steps] as one step of the history, called [param words]:
## what a tool did that the builder did not (a hose laid, a pose).
func record(steps: Array, words: String) -> void:
	if steps.is_empty():
		return
	_history.append({"undo": "group", "steps": steps, "words": words})
	_redo.clear()


## Take these bricks off and put these down, without asking whether they
## fit: a copy of an assembly built again from another. ``adds`` are
## {part, color, at, path}. Returns the history steps, for extend_last.
func swap_bricks(remove_ids: PackedInt64Array, adds: Array) -> Array:
	var taken: Array = []
	for brick_id: int in remove_ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		taken.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
			"transform": brick.transform, "group": brick.group, "unit": brick.unit,
			"step": brick.step, "was": brick.id})
		lattice.release(brick_id)
		world.remove_brick(brick_id)
		selection.erase(brick_id)
		locked.erase(brick_id)
		removed.emit(brick_id)
	var put: Array = []
	for item: Dictionary in adds:
		var at: Transform3D = item["at"]
		var new_id: int = world.add_brick(str(item["part"]), int(item["color"]), at)
		if new_id == 0:
			continue
		set_path(world.get_brick(new_id), str(item.get("path", "")))
		world.get_brick(new_id).step = int(item.get("step", -1))
		lattice.occupy_boxes(new_id, boxes_for(library.mesh_for(str(item["part"])), at))
		put.append({"undo": "remove", "brick": new_id})
	# Undone in order: the new ones off first, then the old ones back.
	return put + taken


## Bricks that cannot be picked out, moved, painted or taken off until
## they are unlocked: id -> true. A finished base, kept safe while the
## building on it is worked on. Not saved with the model.
var locked: Dictionary = {}


## Lock the selection, or unlock it. Returns how many changed.
func lock_selection(lock: bool) -> int:
	var count: int = 0
	for brick_id: int in _living_selection():
		if lock and not locked.has(brick_id):
			locked[brick_id] = true
			count += 1
		elif not lock and locked.erase(brick_id):
			count += 1
	if lock:
		clear_selection()
	return count


## Unlock everything.
func unlock_all() -> int:
	var count: int = locked.size()
	locked.clear()
	return count


func is_locked(brick_id: int) -> bool:
	return locked.has(brick_id)


## Paint one brick, as one step: what Paint mode does to a brick clicked.
func paint_brick(brick_id: int, color_code: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or brick.color_code == color_code or locked.has(brick_id):
		return false
	_history.append({"undo": "recolor", "brick": brick_id, "color": brick.color_code})
	_redo.clear()
	return world.recolor_brick(brick_id, color_code)


## Take one brick off, as one step: what Delete mode does to a brick clicked.
func remove_brick_id(brick_id: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or locked.has(brick_id):
		return false
	_history.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
		"transform": brick.transform, "group": brick.group, "unit": brick.unit,
		"step": brick.step, "was": brick.id})
	_redo.clear()
	lattice.release(brick_id)
	world.remove_brick(brick_id)
	selection.erase(brick_id)
	removed.emit(brick_id)
	return true


## Make the selection a sub-model of its own under ``name``, or take it out
## of whatever sub-model it was in with "". One step to undo. A model's
## sub-models are what its .mpd is written as and what the booklet builds
## one at a time; until now only a design or an opened file could make one.
func name_group(name: String) -> int:
	var alive: PackedInt64Array = _living_selection()
	var steps: Array = []
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.group == name:
			continue
		steps.append({"undo": "regroup", "brick": brick_id, "group": brick.group})
		brick.group = name
	if steps.is_empty():
		return 0
	_history.append({"undo": "group", "steps": steps,
		"words": ("made %s the sub-model %s" % [_many(steps.size()), name]) if not name.is_empty()
			else "took %s out of its sub-model" % _many(steps.size())})
	_redo.clear()
	return steps.size()


## Turn the selection about the joint it hangs from — a hinge's pin, a
## clip on a bar, a turntable — by ``degrees``, as one step. The joint is
## a shaft of one part in a bore of another (Joints.rounds) with the
## selection on one side and the rest of the model on the other. Returns
## how many turned: zero when there is no such joint, or when the turn
## would run into anything but the part it is joined to.
##
## The parts it turns stand off the grid afterwards, which the lattice
## holds as turned covers, as it holds an angled section a design builds.
## Studio's hinge tool does this; here a hinged wing could only stand at
## the angle it was put down at.
func swing_selection(degrees: float) -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty() or is_zero_approx(degrees):
		return 0
	var joint: Dictionary = _joint_of(alive)
	if joint.is_empty():
		return 0
	var at_point: Vector3 = joint["point"]
	var axis: Vector3 = (joint["axis"] as Vector3).normalized()
	var around: Transform3D = Transform3D(Basis.IDENTITY, at_point) \
		* Transform3D(Basis(axis, deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -at_point)
	var partners: Dictionary = joint["partners"]
	var was: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		lattice.release(brick_id)
	var landing: Dictionary = {}
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to: Transform3D = around * brick.transform
		to = Transform3D(to.basis.orthonormalized(), to.origin)
		var packed: PackedInt32Array = boxes_for(library.mesh_for(brick.part_id), to)
		for other: int in lattice.blockers_boxes(packed):
			if not partners.has(other):
				for back: int in alive:
					lattice.occupy_boxes(back, boxes_for(
						library.mesh_for(world.get_brick(back).part_id), was[back]))
				return 0
		landing[brick_id] = {"at": to, "boxes": packed}
	var steps: Array = []
	for brick_id: int in alive:
		steps.append({"undo": "move", "brick": brick_id, "transform": was[brick_id]})
		world.move_brick(brick_id, landing[brick_id]["at"])
		lattice.occupy_boxes(brick_id, landing[brick_id]["boxes"])
	_history.append({"undo": "group", "steps": steps,
		"words": "swung %s on its joint" % _many(steps.size())})
	_redo.clear()
	return steps.size()


## The round joint between the selection and the rest of the model: a
## point on its axis, the axis, and every part on the far side of any such
## joint (which the swing may press against). Empty when there is none.
func _joint_of(ids: PackedInt64Array) -> Dictionary:
	var picked: Dictionary = {}
	var box := AABB()
	var first: bool = true
	var entries: Array = []
	for brick_id: int in ids:
		picked[brick_id] = true
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		entries.append([brick_id, brick.transform, part])
		if part != null:
			var here: AABB = (brick.transform * part.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	if first:
		return {}
	var reach: AABB = box.grow(BrickLattice.STUD * 2.0)
	for brick: BrickWorld.Brick in world.bricks():
		if picked.has(brick.id):
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part != null and (brick.transform * part.bounds).abs().intersects(reach):
			entries.append([brick.id, brick.transform, part])
	var held: Dictionary = Joints.rounds(entries)
	var found: Dictionary = {}
	var partners: Dictionary = {}
	for mine: Variant in held:
		if not picked.has(mine):
			continue
		for other: Variant in held[mine]:
			if picked.has(other):
				continue
			partners[other] = true
			var zones: Array = held[mine][other]
			if found.is_empty() and not zones.is_empty():
				found = {"point": zones[0][0], "axis": zones[0][1]}
	if found.is_empty():
		return {}
	found["partners"] = partners
	return found


## Where a part goes to take another's place: the same turn, its middle on
## the stud grid for its own footprint, its bottom where the other's was.
func _in_place_of(at: Transform3D, was: Lbm.PartMesh, into: Lbm.PartMesh) -> Transform3D:
	if was == null or not BrickLattice.is_square_to_grid(at.basis) \
			or absf((at.basis * Vector3.UP).y) < 0.99:
		return at
	var old_box: AABB = _rotated_bounds(was, at.basis)
	var new_box: AABB = _rotated_bounds(into, at.basis)
	var footprint := Vector2i(
		int(round(new_box.size.x / BrickLattice.STUD)),
		int(round(new_box.size.z / BrickLattice.STUD)))
	var middle: Vector3 = at.origin + old_box.get_center() - new_box.get_center()
	var snapped: Vector3 = BrickLattice.snap_to_studs(middle, footprint)
	var bottom: float = at.origin.y + old_box.position.y
	return Transform3D(at.basis, Vector3(snapped.x, bottom - new_box.position.y, snapped.z))


# -- several parts in hand ------------------------------------------------


func is_carrying() -> bool:
	return carrying != null and carrying.is_holding()


## Copy the selection to the clipboard. Returns how many parts.
func copy_selection() -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0
	Carry.clipboard = Carry.gather(world, library, Array(alive))
	return Carry.clipboard.size()


## Hold a copy of these parts, to put down where the pointer says.
func hold_copy(parts: Array) -> int:
	if parts.is_empty():
		return 0
	carrying.library = library
	carrying.hold(parts, false)
	return parts.size()


## Pick the selection up off the model to move it: it follows the pointer
## until a click puts it down, and picking it up and putting it down are
## one step to undo. Escape puts it back where it was.
func lift_selection() -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0
	var parts: Array = Carry.gather(world, library, Array(alive))
	if parts.is_empty():
		return 0
	var steps: Array = []
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		steps.append({"undo": "add", "part": brick.part_id,
			"color": brick.color_code, "transform": brick.transform,
			"group": brick.group, "unit": brick.unit, "step": brick.step, "was": brick.id,
			"cover": lattice.cover_of(brick_id)})
		lattice.release(brick_id)
		world.remove_brick(brick_id)
		removed.emit(brick_id)
	_history.append({"undo": "group", "steps": steps, "lift": true})
	_redo.clear()
	clear_selection()
	carrying.library = library
	carrying.hold(parts, true)
	return parts.size()


## Put away what is held without putting it down. What was lifted off
## the model goes back where it was, and is selected again.
func cancel_carry() -> bool:
	if not is_carrying():
		return false
	var lifted: bool = carrying.lifted
	carrying.drop()
	if lifted and _lift_on_top():
		var back: Dictionary = _apply(_history.pop_back())
		selection.clear()
		for step: Dictionary in back.get("steps", []):
			if step.get("undo", "") == "remove":
				selection[int(step["brick"])] = true
		selection_changed.emit(selection.size())
	return true


func _lift_on_top() -> bool:
	return not _history.is_empty() and bool(_history.back().get("lift", false))


## Put what is held down where its ghost is, as one step, and select it so
## it can be nudged or turned straight away.
func _put_carried() -> int:
	if not carrying.can_place():
		return 0
	var steps: Array = []
	var ids := PackedInt64Array()
	# A copy of a minifigure or a named assembly is another one, not more
	# of the same: "Guard" pasted beside "Guard" is "Guard 2".
	var renamed: Dictionary = {}
	for item: Dictionary in carrying.placements(self):
		var group: String = str(item["group"])
		var unit: String = str(item.get("unit", ""))
		var path: String = ""
		if not carrying.lifted and copy_group.is_valid():
			path = copy_group.call(Assemblies.path_from(group, unit), renamed)
		elif not carrying.lifted and not group.is_empty():
			if not renamed.has(group):
				renamed[group] = unused_group(group)
			group = renamed[group]
		var brick_id: int = world.add_brick(str(item["part"]),
			int(item["color"]), item["at"])
		if brick_id == 0:
			continue
		world.get_brick(brick_id).group = group
		world.get_brick(brick_id).unit = unit
		if not carrying.lifted and copy_group.is_valid():
			set_path(world.get_brick(brick_id), path)
		# Moved, a part keeps its build step; a copy goes in the step a
		# placed part would.
		world.get_brick(brick_id).step = int(item.get("step", -1)) if carrying.lifted \
			else _new_step(world.get_brick(brick_id))
		lattice.occupy_boxes(brick_id, item["boxes"])
		steps.append({"undo": "remove", "brick": brick_id})
		ids.append(brick_id)
	if ids.is_empty():
		return 0
	var words: String = "pasted %s" % _many(ids.size())
	if carrying.lifted and _lift_on_top():
		# One move: what picked it up and what put it down undo together.
		steps.append_array(_history.pop_back()["steps"])
		words = "moved %s" % _many(ids.size())
	_history.append({"undo": "group", "steps": steps, "words": words})
	_redo.clear()
	carrying.drop()
	selection.clear()
	for brick_id: int in ids:
		selection[brick_id] = true
	selection_changed.emit(selection.size())
	placed.emit(ids[0], world.get_brick(ids[0]).part_id)
	return ids[0]


## Work out where the held part would go, given a ray from the camera.
func update_preview(origin: Vector3, direction: Vector3) -> void:
	_joint_site = null
	if is_carrying():
		_ghost.visible = false
		_ghost_valid = false
		_hide_figure_ghosts()
		carrying.library = library
		_hovered = carrying.aim(lattice, self, origin, direction)
		return
	if not held_figure.is_empty():
		_preview_figure(origin, direction)
		return
	_hide_figure_ghosts()
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part == null:
		_ghost.visible = false
		_ghost_valid = false
		return
	if Stickers.sticks(library, held_part):
		_preview_sticker(part, origin, direction)
		return

	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	_hovered = hit.brick_id
	if _onto_a_joint(part, origin, direction.normalized(), hit):
		_show_ghost(part)
		return

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

	var onto: Variant = _onto_side_studs(part, basis, hit, origin, direction)
	_ghost_transform = onto if onto != null else _settle(part, basis, target, hit)
	_seated_on = hit.brick_id if onto != null else 0
	_ghost_valid = _fits_on_studs(part, _ghost_transform, _seated_on, Vector3i(hit.normal)) \
		if _seated_on != 0 else room_for(held_part, _ghost_transform)
	_show_ghost(part)


## Which way the screen's up is: a sticker in hand over a face that lies (a
## tile's top) is turned square to the edge nearest the screen's foot, as
## Put a sticker on… turns one. Main sets it with each aim.
var view_up: Vector3 = Vector3.UP


## A sticker in hand — one of LDraw's (its Sticker category) or one made
## here — goes on the face it is over, lying on it, its middle on the
## face's middle, and not on studs: a film is held by its glue, the face
## under it (Stickers.lies_on), and a sticker put down on the grid floated
## a plate over the brick it was for. R turns it about the face.
func _preview_sticker(part: Lbm.PartMesh, origin: Vector3, direction: Vector3) -> void:
	var face: Stickers.Face = Stickers.face_at(world, library, origin, direction, false, view_up)
	if face == null:
		_ghost.visible = false
		_ghost_valid = false
		_hovered = 0
		return
	_hovered = face.bricks[0]
	_ghost_transform = Stickers.laid_on(face, part.bounds, held_rotation)
	_seated_on = 0
	_ghost_valid = true
	_show_ghost(part)


func _show_ghost(part: Lbm.PartMesh) -> void:
	_ghost.mesh = part.surfaces[0]
	_ghost.transform = _ghost_transform
	_ghost.visible = true
	var tint: Color = library.color(held_color).shown
	_ghost_material.set_shader_parameter("tint", tint)
	_ghost_material.set_shader_parameter("valid", _ghost_valid)
	preview_changed.emit(held_part, _ghost_valid)


# -- onto a joint: a pin into a hole, a beam onto pins, a clip on a bar --


## How far the Turn setting on the toolbar turns a selection, in degrees.
## A part on a round joint turns by it when it is finer than
## JointSnap.ROUND_STEP; a cross in a cross always turns by quarters.
var turn_step: float = 90.0

## The end of a part down that the ghost is on, or null when it is not on
## one: what R turns about and T flips over, instead of the part's own up.
var _joint_site: JointSnap.End = null
var _joint_words: String = ""
## Which of the ways onto the joint (JointSnap.choices) and how many steps
## turned about it, as R and T leave them.
var _joint_way: int = 0
var _joint_roll: int = 0
## Degrees about the joint past the roll's steps: where the turn brings
## another end of the part onto an end of a part down (_closings), which
## no step reaches. 8841-1's Technic plates hang from an axle at 66.4
## degrees, their far holes on pins, and were off every turn a part had.
var _joint_extra: float = 0.0
## The ways onto the joint and the way the part was held, as the ghost was
## last worked out from them: what R finds the next stop by.
var _joint_options: Array = []
var _joint_basis: Basis = Basis.IDENTITY
## Whether R or T has been pressed on this joint. Until one has, the way
## that has room and joins the most is found for the person; after, what
## they chose is shown, red where it does not fit.
var _joint_chosen: bool = false
var _joint_key: String = ""
var _joint_part: String = ""
## The last pose worked out, by what it was worked out from, so a pointer
## moving over one joint does not search again at every motion.
var _joint_last: String = ""
var _joint_last_at: Transform3D = Transform3D.IDENTITY
var _joint_last_fits: bool = false
## Every end of every part down, and the world's revision it was read at.
var _sites: Array = []
var _sites_at: int = -1
var _sites_world: BrickWorld = null


## Whether the ghost is on a joint, where R turns the part about it.
func is_on_joint() -> bool:
	return _joint_site != null


## What the ghost is on, in words, or "": "the pin hole of Technic Brick
## 1 x 2 with Hole".
func joint_words() -> String:
	return _joint_words if _joint_site != null else ""


## Every connector of every part down that a part could be put onto, read
## again only when the model has changed.
func joint_sites() -> Array:
	if world != null and (_sites_at != world.revision or _sites_world != world):
		_sites = JointSnap.sites_in(world, library)
		_sites_at = world.revision
		_sites_world = world
	return _sites


## Put the ghost on the joint the pointer is aimed at, if the part in hand
## has an end for one there. False, leaving the ghost to the studs, when
## it is not aimed at one or the part has no ends.
func _onto_a_joint(part: Lbm.PartMesh, origin: Vector3, direction: Vector3,
		hit: BrickLattice.Hit) -> bool:
	_joint_site = null
	var held: Array = JointSnap.ends_of(part)
	if held.is_empty() or world == null:
		return false
	joint_sites()
	# A little past what the line met: a hole's middle is inside the part
	# whose face was struck.
	var before: float = hit.distance + BrickLattice.STUD * 1.2 if hit.is_valid() else INF
	var site: JointSnap.End = JointSnap.aimed_at(_sites, held, origin, direction, before,
		lattice.unseen)
	if site == null:
		return false
	var options: Array = JointSnap.choices(held, site, origin, direction)
	if options.is_empty():
		return false
	var key: String = "%d|%s|%s|%s" % [site.brick, site.kind, site.at, site.axis]
	if held_part != _joint_part:
		_joint_part = held_part
		_joint_way = 0
		_joint_roll = 0
		_joint_extra = 0.0
		_joint_chosen = false
	if key != _joint_key:
		_joint_key = key
		_joint_extra = 0.0
		_joint_chosen = false
	var basis: Basis = BrickLattice.basis_for(held_face, held_rotation)
	_joint_options = options
	_joint_basis = basis
	if _joint_asked(key, basis, options) != _joint_last:
		_joint_last_at = _joint_pose(options, posmod(_joint_way, options.size()),
			_joint_roll, site, basis, _joint_extra)
		_joint_last_fits = room_for(held_part, _joint_last_at, true)
		if not _joint_chosen:
			_best_on_joint(options, site, basis)
		_joint_last = _joint_asked(key, basis, options)
	_joint_site = site
	var struck: BrickWorld.Brick = world.get_brick(site.brick)
	var info: PartLibrary.PartInfo = library.parts.get(struck.part_id) \
		if struck != null else null
	_joint_words = JointSnap.describe(site,
		Inventory._tidy(info.name) if info != null else "a part")
	_hovered = site.brick
	_seated_on = 0
	_ghost_transform = _joint_last_at
	_ghost_valid = _joint_last_fits
	return true


## Everything the pose on a joint is worked out from, in one string: the
## joint, the model as it stands, the part and how it is held, what R and
## T have chosen, the turn step, and the first way on (which says which
## face is near and where along a bar the pointer is).
func _joint_asked(key: String, basis: Basis, options: Array) -> String:
	return "%s|%d|%s|%s|%d|%d|%s|%s|%s|%s|%s" % [key, world.revision, held_part, basis,
		_joint_way, _joint_roll, _joint_extra, _joint_chosen, turn_step, options[0][1],
		options[0][2]]


## The pose for one of the ways onto a joint, turned so many steps and
## [param extra] degrees more.
func _joint_pose(options: Array, way: int, roll: int, site: JointSnap.End,
		basis: Basis, extra: float = 0.0) -> Transform3D:
	var option: Array = options[way]
	var step: float = JointSnap.step_of(option[0], site, turn_step)
	return JointSnap.pose(option[0], site, int(option[1]), float(option[2]),
		roll * step + extra, basis)


## The turns about a round joint, in degrees from the way's own (roll 0),
## at which another end of the part in hand comes onto an end of a part
## down that takes it: a Technic plate on a pin swung until its far hole
## is over an axle, as Studio turns a part to fit its connections. Only
## about something round in something round (a pin, an axle in a pin
## hole); a cross turns by quarters, which the steps reach, and a clip
## slides on its bar.
func _closings(options: Array, way: int, site: JointSnap.End, basis: Basis) -> Array:
	var out: Array = []
	var held_end: JointSnap.End = options[way][0]
	if held_end.is_round() or JointSnap.step_of(held_end, site, 0.0) == JointSnap.CROSS_STEP:
		return out
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part == null:
		return out
	var at: Transform3D = _joint_pose(options, way, 0, site, basis)
	var axis: Vector3 = site.axis
	# The ends of the parts it could swing onto: near anywhere it reaches
	# turned about the joint, the box about the joint grown by its size.
	var size: float = part.bounds.size.length()
	var box := AABB(site.at - Vector3.ONE * size, Vector3.ONE * size * 2.0)
	var reach := PackedInt32Array([floori(box.position.x / BrickLattice.CELL),
		floori(box.position.y / BrickLattice.CELL), floori(box.position.z / BrickLattice.CELL),
		ceili(box.end.x / BrickLattice.CELL), ceili(box.end.y / BrickLattice.CELL),
		ceili(box.end.z / BrickLattice.CELL)])
	var downs: Array = []
	for other: int in lattice.near_bounds(reach):
		var brick: BrickWorld.Brick = world.get_brick(other)
		if brick == null:
			continue
		for end: JointSnap.End in JointSnap.ends_of(library.mesh_for(brick.part_id)):
			var placed: JointSnap.End = end.placed(brick.transform, other)
			if absf(placed.axis.dot(axis)) >= 0.999 and not placed.is_round():
				downs.append(placed)
	for mine: JointSnap.End in JointSnap.ends_of(part):
		if mine == held_end or mine.is_round():
			continue
		var p: Vector3 = at * mine.at
		if absf((at.basis * mine.axis).normalized().dot(axis)) < 0.999:
			continue
		var from_axis: Vector3 = _off_axis(p - site.at, axis)
		if from_axis.length() < 1.0:
			continue
		for down: JointSnap.End in downs:
			if not JointSnap.mates(mine, down):
				continue
			var to: Vector3 = _off_axis(down.at - site.at, axis)
			if absf(to.length() - from_axis.length()) > 0.5:
				continue
			# Near enough along the axis to meet (an axle's end is its tip,
			# and it may run a long way through): whether they do is asked
			# of the joints below.
			if absf((down.at - p).dot(axis)) > mine.reach + down.reach + BrickLattice.STUD * 4.0:
				continue
			var angle: float = fposmod(rad_to_deg(from_axis.signed_angle_to(to, axis)), 360.0)
			if not out.any(func(a: float) -> bool: return absf(a - angle) < 0.01):
				out.append(angle)
	# Only where it does join one more part than on the joint alone.
	if out.is_empty():
		return out
	var alone: int = _joins_made(at)
	return out.filter(func(angle: float) -> bool:
		return _joins_made(_joint_pose(options, way, 0, site, basis, angle)) > alone)


static func _off_axis(v: Vector3, axis: Vector3) -> Vector3:
	return v - axis * v.dot(axis)


## Of the ways onto the joint at each quarter turn, and turned where the
## part also joins another end (_closings), the one with room that joins
## the most parts, first found on a tie, leaving R and T on it. Bounded,
## since a long beam has a way for each hole: a quarter turn of each of a
## dozen of them, and where each swings onto another end.
const _JOINT_TRIES := 64


func _best_on_joint(options: Array, site: JointSnap.End, basis: Basis) -> void:
	var best_joins: int = -1
	if _joint_last_fits:
		best_joins = _joins_made(_joint_last_at)
	var tries: int = 0
	for n: int in options.size():
		var way: int = posmod(_joint_way + n, options.size())
		var step: float = JointSnap.step_of(options[way][0], site, turn_step)
		var quarter: int = maxi(roundi(90.0 / step), 1)
		# [roll, extra]: the quarters first, so a tie stays square.
		var turns: Array = []
		for q: int in 4:
			if not (n == 0 and q == 0):
				turns.append([_joint_roll + q * quarter, 0.0])
		for closing: float in _closings(options, way, site, basis):
			turns.append([0, closing])
		for turn: Array in turns:
			tries += 1
			if tries > _JOINT_TRIES:
				return
			var at: Transform3D = _joint_pose(options, way, int(turn[0]), site, basis,
				float(turn[1]))
			if not room_for(held_part, at, true):
				continue
			var joins: int = _joins_made(at)
			if joins > best_joins:
				best_joins = joins
				_joint_way = way
				_joint_roll = int(turn[0])
				_joint_extra = float(turn[1])
				_joint_last_at = at
				_joint_last_fits = true


## R on a joint: the next stop about it, a step on, or sooner where the
## part also joins another end there (_closings). [param by] is +1 or -1.
func _turn_on_joint(by: int) -> void:
	if _joint_options.is_empty():
		_joint_roll += by
		return
	var way: int = posmod(_joint_way, _joint_options.size())
	var step: float = JointSnap.step_of(_joint_options[way][0], _joint_site, turn_step)
	var now: float = _joint_roll * step + _joint_extra
	var next: float = (floorf(now / step + 0.001) + 1.0) * step if by > 0 \
		else (ceilf(now / step - 0.001) - 1.0) * step
	for closing: float in _closings(_joint_options, way, _joint_site, _joint_basis):
		var gone: float = fposmod((closing - now) * by, 360.0)
		if gone < 0.01 or gone > 359.99:
			continue
		var stop: float = now + gone * by
		if (by > 0 and stop < next) or (by < 0 and stop > next):
			next = stop
	var steps: float = next / step
	if absf(steps - roundf(steps)) < 0.001:
		_joint_roll = roundi(steps)
		_joint_extra = 0.0
	else:
		_joint_roll = 0
		_joint_extra = next


## How many parts down the part in hand would be joined to at a pose, by a
## pin, an axle or something round in something round.
func _joins_made(at: Transform3D) -> int:
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	var box: AABB = (at * part.bounds).abs().grow(BrickLattice.CELL * 2.0)
	var reach := PackedInt32Array([floori(box.position.x / BrickLattice.CELL),
		floori(box.position.y / BrickLattice.CELL), floori(box.position.z / BrickLattice.CELL),
		ceili(box.end.x / BrickLattice.CELL), ceili(box.end.y / BrickLattice.CELL),
		ceili(box.end.z / BrickLattice.CELL)])
	var entries: Array = [[0, at, part]]
	for other: int in lattice.near_bounds(reach):
		var brick: BrickWorld.Brick = world.get_brick(other)
		if brick != null:
			entries.append([other, brick.transform, library.mesh_for(brick.part_id)])
	var joined: Dictionary = (Joints.both_ways(entries).get(0, {}) as Dictionary).duplicate()
	joined.merge(Joints.rounds(entries).get(0, {}))
	return joined.size()


## Whether a part has room at a place: nothing in its way but parts it is
## joined to the way real parts are joined, by the rule check_design uses
## (Assistant._joints_out) and no more — a pin in the hole it lines up
## with, an axle in its axle hole, a pane in its frame, and something
## round in something round that fits it where the two meet inside the
## round. [param grounded] refuses it below the ground as well, which a
## part on a joint can be and one on the studs never is.
func room_for(part_id: String, at: Transform3D, grounded: bool = false) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	var packed: PackedInt32Array = boxes_for(part, at)
	if grounded:
		var n: int = 1
		while n < packed.size():
			if packed[n] < GROUND_CELL:
				return false
			n += 6
	var blockers: PackedInt64Array = lattice.blockers_boxes(packed)
	if blockers.is_empty():
		return true
	var entries: Array = [[0, at, part, library.resolve(part_id)]]
	for other: int in blockers:
		var brick: BrickWorld.Brick = world.get_brick(other) if world != null else null
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh == null:
			return false
		entries.append([other, brick.transform, mesh, library.resolve(brick.part_id)])
	var pinned: Dictionary = Joints.both_ways(entries).get(0, {})
	var turning: Dictionary = Joints.rounds(entries).get(0, {})
	# A gear put down in mesh with one already there, as check_design
	# forgives it (Joints.meshing).
	var in_mesh: Dictionary = Joints.meshing(entries).get(0, {})
	var mine: String = library.resolve(part_id)
	for n: int in range(1, entries.size()):
		var other: int = entries[n][0]
		var there: Transform3D = entries[n][1]
		if pinned.has(other) or in_mesh.has(other):
			continue
		var theirs: String = library.resolve(str(entries[n][3]))
		if Assistant._seated_in(mine, at, theirs, there) \
				or Assistant._seated_in(theirs, there, mine, at):
			continue
		if turning.has(other):
			var square: bool = BrickLattice.is_square_to_grid(at.basis) \
				and BrickLattice.is_square_to_grid(there.basis)
			var own: Array = [] if square else [
				[at, boxes_for(part, Transform3D.IDENTITY)],
				[there, boxes_for(entries[n][2], Transform3D.IDENTITY)]]
			if Joints.overlap_within(packed, lattice.boxes_of(other), turning[other],
					Transform3D.IDENTITY,
					Joints.ROUND_SLACK if square else Joints.ROUND_SLACK_TURNED, own):
				continue
		# A gear's square cover reaches past its teeth (Joints.past_the_teeth).
		if Joints.past_the_teeth(packed, lattice.boxes_of(other),
				Joints.gear_rounds([[mine, at], [theirs, there]], library), Transform3D.IDENTITY):
			continue
		return false
	return true


## How far apart the places a part can be put down are, across the
## ground, in LDU: a stud (the default), half a stud, or the lattice's
## own two LDU. Set from the toolbar's snap; a jumper plate's half-stud
## offset, or a part nudged off the grid, needs the finer ones.
var snap_across: float = BrickLattice.STUD


## A point put on the grid ``snap_across`` says: on the studs, keeping a
## part's own phase, at a stud; on whole multiples of the step otherwise.
func snap_across_to(target: Vector3, footprint: Vector2i) -> Vector3:
	if snap_across >= BrickLattice.STUD - 0.01:
		return BrickLattice.snap_to_studs(target, footprint)
	return Vector3(snappedf(target.x, snap_across), target.y,
		snappedf(target.z, snap_across))


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
	var snapped: Vector3 = snap_across_to(target, footprint)
	# Unless what hangs past its plate makes its box another size: a clip
	# plate's clip, a bracket's arm. Then its sockets say where the studs go.
	var phase: Variant = _socket_phase(part, basis, footprint)
	if phase != null and snap_across >= BrickLattice.STUD - 0.01:
		var on: Vector2 = phase
		snapped = Vector3(
			round((target.x - on.x) / BrickLattice.STUD) * BrickLattice.STUD + on.x, target.y,
			round((target.z - on.y) / BrickLattice.STUD) * BrickLattice.STUD + on.y)

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

	# Aimed at the underside of a part: hung under it, its top against
	# that underside, the way a plate is pressed up under an overhang.
	# Dropping it to whatever was below — the floor, usually — made the
	# underside of anything unreachable by hand, where Studio and
	# Mecabricks both attach there.
	# Never below the ground: under the baseplate is not somewhere a part
	# can be.
	if hit.is_valid() and hit.normal.y < 0:
		# The struck cell is the lowest of the part above, and a box's
		# cell n starts at n cells, as resting_height counts them.
		var top: float = hit.cell.y * BrickLattice.CELL
		# Against the top of its body, not of its studs: the studs go up
		# into the part above, as they do on a real one.
		var cover: PackedInt32Array = boxes_for(part, Transform3D(basis, Vector3.ZERO))
		var reach: float = box.end.y
		if not cover.is_empty():
			var highest: int = -(1 << 30)
			var n: int = 4
			while n < cover.size():
				highest = maxi(highest, cover[n])
				n += 6
			reach = highest * BrickLattice.CELL
		var hung: float = _on_cell(top - reach)
		if hung + box.position.y >= GROUND_CELL * BrickLattice.CELL:
			return Transform3D(basis, Vector3(snapped.x, hung, snapped.z))

	var rest_cell: int = lattice.resting_height(columns, GROUND_CELL)
	# Placing against a side face should not slide the part down onto the
	# floor, so a sideways hit keeps the height the face implies.
	if hit.is_valid() and hit.normal.y == 0:
		rest_cell = maxi(rest_cell, hit.adjacent().y)

	var y: float = rest_cell * BrickLattice.CELL - box.position.y
	# On its plate, not on what hangs below it, where that leaves room: the
	# clip plates of 5762-1's step 4 hang their clips 2 LDU below the plate,
	# over the edge of the plate they stand on, and stood 2 LDU up by their
	# box. Nothing struck from the side or below.
	var lift: float = _hangs_below(part, basis)
	if lift > 0.01 and not (hit.is_valid() and hit.normal.y <= 0):
		var low: float = y - lift
		var at := Transform3D(basis, Vector3(snapped.x, low, snapped.z))
		if low + box.position.y >= GROUND_CELL * BrickLattice.CELL - 0.01 \
				and room_for(held_part, at):
			return at
	return Transform3D(basis, Vector3(snapped.x, y, snapped.z))


## Where on the stud grid a part goes across, by its sockets, when its box
## puts it elsewhere: [x, z] of its origin modulo a stud, or null where the
## box and a socket agree (every plain part) or it has none. Studs stand at
## odd multiples of half a stud (BrickLattice.snap_to_studs), so a socket
## must too. Upright or upside down only: a part on its side has its
## sockets on a side.
func _socket_phase(part: Lbm.PartMesh, basis: Basis, footprint: Vector2i) -> Variant:
	if part.sockets.is_empty() or absf((basis * Vector3.UP).y) < 0.99:
		return null
	var half: float = BrickLattice.STUD * 0.5
	var by_box := Vector2(half if footprint.x % 2 == 1 else 0.0,
		half if footprint.y % 2 == 1 else 0.0)
	var counts: Dictionary = {}
	for socket: Vector2 in part.sockets:
		var at: Vector3 = basis * Vector3(socket.x, 0.0, socket.y)
		var phase := Vector2(fposmod(half - at.x, BrickLattice.STUD),
			fposmod(half - at.z, BrickLattice.STUD))
		phase = Vector2(snappedf(phase.x, 0.5), snappedf(phase.y, 0.5))
		if phase.distance_to(by_box) < 0.5:
			return null
		# Only a socket on the half-stud grid of the origin says where the
		# studs go: a wedge plate's (51739) are not, and taken at their word
		# put it 2 LDU off the studs.
		if not _on_half_stud(phase.x) or not _on_half_stud(phase.y):
			continue
		counts[phase] = int(counts.get(phase, 0)) + 1
	var best: Variant = null
	for phase: Vector2 in counts:
		if best == null or int(counts[phase]) > int(counts[best]):
			best = phase
	return best


static func _on_half_stud(phase: float) -> bool:
	return is_zero_approx(phase) or is_equal_approx(phase, BrickLattice.STUD * 0.5) \
		or is_equal_approx(phase, BrickLattice.STUD)


## How far the part reaches below its plate, where it sits on the studs of
## what is under it: the bottom of its cover under its sockets less the
## bottom of all of it. 0 for a plain part, which has nothing below its
## plate, and for one with no sockets or not upright.
func _hangs_below(part: Lbm.PartMesh, basis: Basis) -> float:
	if part.sockets.is_empty() or part.boxes.is_empty() \
			or (basis * Vector3.UP).y < 0.99:
		return 0.0
	var seat: float = INF
	var lowest: float = INF
	for cells: AABB in part.boxes:
		var low: Vector3 = cells.position * part.cell_ldu
		var high: Vector3 = cells.end * part.cell_ldu
		lowest = minf(lowest, low.y)
		for socket: Vector2 in part.sockets:
			if socket.x >= low.x - 0.01 and socket.x <= high.x + 0.01 \
					and socket.y >= low.z - 0.01 and socket.y <= high.z + 0.01:
				seat = minf(seat, low.y)
	return seat - lowest if seat < INF else 0.0


## A part laid on its side, aimed at a face with studs on it — a brick
## with studs on its side, a headlight brick — seated on those studs: its
## underside against the face, one of its sockets on the stud nearest the
## pointer, and the part as near the pointer as that allows. Null when
## there is no such stud or the part is not turned to take one, and the
## part is placed the ordinary way.
##
## The ordinary way put a sideways part against the face at whatever
## height the pointer was, on the lattice's two-LDU grid: off the side
## studs nearly always, and only right by chance. Studs not on top is
## half of how modern sets are built.
func _onto_side_studs(part: Lbm.PartMesh, basis: Basis, hit: BrickLattice.Hit,
		origin: Vector3, direction: Vector3) -> Variant:
	if not hit.is_valid() or hit.normal.y != 0 or part.sockets.is_empty():
		return null
	var out := Vector3(hit.normal)
	# The part's underside has to face the wall: its studs point out of it.
	if (basis * Vector3.UP).dot(out) < 0.99:
		return null
	var struck: BrickWorld.Brick = world.get_brick(hit.brick_id)
	if struck == null:
		return null
	var mesh: Lbm.PartMesh = library.mesh_for(struck.part_id)
	if mesh == null:
		return null
	var pointer: Vector3 = origin + direction.normalized() * hit.distance
	var nearest: Variant = null
	var best: float = INF
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud":
			continue
		if (struck.transform.basis * connector.axis).normalized().dot(out) < 0.99:
			continue
		var at: Vector3 = struck.transform * connector.position
		var away: float = (at - pointer).length()
		if away < best:
			best = away
			nearest = at
	if nearest == null or best > BrickLattice.STUD * 2.0:
		return null
	var stud: Vector3 = nearest
	var middle: Vector3 = part.bounds.get_center()
	# The face is where the stud stands on it: a stud's point is drawn at
	# its base. The pointer meets the stud's own cover first, half a
	# plate proud of the face, and a part seated there floated.
	var axis: int = 0 if hit.normal.x != 0 else 2
	var face: float = stud[axis]
	var chosen: Variant = null
	var closest: float = INF
	for socket: Vector2 in part.sockets:
		var under: Vector3 = basis * Vector3(socket.x, part.bounds.position.y, socket.y)
		var place: Vector3 = stud - under
		place[axis] = face - under[axis]
		var off: float = (place + basis * middle - pointer).length()
		if off < closest:
			closest = off
			chosen = place
	if chosen == null:
		return null
	var at: Vector3 = chosen
	return Transform3D(basis, Vector3(snappedf(at.x, 0.001), snappedf(at.y, 0.001),
		snappedf(at.z, 0.001)))


## The brick the ghost is seated on by its side studs, or 0.
var _seated_on: int = 0


## Whether a part seated on side studs fits: nothing in its way but the
## studs it is pressed onto. A side stud is in its brick's cover, as a
## stud on top is not, so the part overlaps it by the stud's height —
## moved out by that much it must clear the brick entirely.
func _fits_on_studs(part: Lbm.PartMesh, at: Transform3D, onto: int,
		out: Vector3i) -> bool:
	var packed: PackedInt32Array = boxes_for(part, at)
	var blockers: PackedInt64Array = lattice.blockers_boxes(packed)
	if blockers.is_empty():
		return true
	if blockers.size() > 1 or blockers[0] != onto:
		return false
	var stud_high: int = int(round(4.0 / BrickLattice.CELL))
	return not lattice.blockers_boxes(
		BrickLattice.moved_by(packed, out * stud_high)).has(onto)


## A height put on the lattice's own grid of cells.
static func _on_cell(y: float) -> float:
	return round(y / BrickLattice.CELL) * BrickLattice.CELL


func _rotated_bounds(part: Lbm.PartMesh, basis: Basis) -> AABB:
	var box: AABB = part.bounds
	var a: Vector3 = basis * box.position
	var b: Vector3 = basis * box.end
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return AABB(lo, hi - lo)


## The lattice cells a part's collision cover fills at a placement.
## The same cover as [method _cells_for], kept as boxes.
##
## This is what everything that touches the lattice should use. A 2x4
## brick is one box and nine thousand six hundred cells, and the cells
## were being built, handed over, and merged straight back into the one
## box they came from.
## Turned covers already worked out, by part and angle.
var _turned_cache: Dictionary = {}
## The same for a check running on a worker thread (Assistant._checked),
## kept apart so neither thread writes a Dictionary the other is reading,
## and locked because the design loop and a connector could both check.
var _turned_off_main: Dictionary = {}
var _turned_lock := Mutex.new()
## Stretched covers already worked out, by part and its basis exactly, as
## the turned ones are (each thread its own, the worker's locked).
var _stretched_cache: Dictionary = {}
var _stretched_off_main: Dictionary = {}


func boxes_for(part: Lbm.PartMesh, at: Transform3D) -> PackedInt32Array:
	if part == null:
		return PackedInt32Array()
	var cell: Vector3i = BrickLattice.to_cell(at.origin)
	var stretch := Vector3(at.basis.x.length(), at.basis.y.length(), at.basis.z.length())
	if not stretch.is_equal_approx(Vector3.ONE) and at.basis.determinant() > 0.0:
		# A part stretched, as LDraw lets a file do: a hose's one-LDU piece
		# of tube made four long (Flex). Its cover is its own made as long,
		# turned the way it is turned; the turned covers below take a turn
		# and nothing else, and gave a piece four long a cover one long.
		#
		# And worked out once for each part and basis, and shifted, as a
		# turned cover is: it never depends on where the part stands. A file
		# whose turns are written to five places has its columns a hair off
		# a length of one, so every such part of a real set is stretched, and
		# checked where it stands each was worked out cell by cell again: 273
		# of 42112's 1,224 parts.
		var exact: Array = [part.get_instance_id(), at.basis]
		var on_main: bool = OS.get_thread_caller_id() == OS.get_main_thread_id()
		var drawn: PackedInt32Array
		if on_main:
			drawn = _stretched_cache.get(exact, PackedInt32Array())
		else:
			_turned_lock.lock()
			drawn = _stretched_off_main.get(exact, PackedInt32Array())
			_turned_lock.unlock()
		if drawn.is_empty():
			drawn = BrickLattice.boxes_for_turned(_stretched_boxes(part, stretch), Vector3i.ZERO,
				at.basis.orthonormalized())
			if on_main:
				_stretched_cache[exact] = drawn
			else:
				_turned_lock.lock()
				_stretched_off_main[exact] = drawn
				_turned_lock.unlock()
		return BrickLattice.moved_by(drawn, cell)
	if part.boxes.is_empty():
		# No cover was built for this part, so fall back to the bounding
		# box by way of the cell path, which already handles the
		# clearance that keeps two round bricks from touching.
		return BrickLattice.compress(_cells_for(part, at))
	if BrickLattice.is_square_to_grid(at.basis):
		var square: PackedInt32Array = BrickLattice.boxes_for(part.boxes, cell, at.basis)
		# Counted from its origin's cell, a cover off the lattice reaches
		# up to a cell past the part (BrickLattice.within). A turned cover
		# is rounded out all round on purpose, and left so: what a tipped
		# section leans on is found by it.
		if BrickLattice.is_off_lattice(at.origin):
			return BrickLattice.within(square, part.bounds, at)
		return square

	# A turned part has no box image, so its cover is worked out cell by
	# cell and merged back into runs, which is far too slow to repeat per
	# brick. The shape depends only on the part and the angle and never
	# on where it sits, so it is worked out once and shifted. Every brick
	# in a section shares one angle, so a section of two hundred costs
	# one.
	var key: String = "%d|%s" % [part.get_instance_id(), at.basis]
	var shape: PackedInt32Array
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		shape = _turned_cache.get(key, PackedInt32Array())
		if shape.is_empty():
			shape = BrickLattice.boxes_for_turned(
				part.boxes, Vector3i.ZERO, at.basis)
			_turned_cache[key] = shape
	else:
		_turned_lock.lock()
		shape = _turned_off_main.get(key, PackedInt32Array())
		if shape.is_empty():
			shape = BrickLattice.boxes_for_turned(
				part.boxes, Vector3i.ZERO, at.basis)
			_turned_off_main[key] = shape
		_turned_lock.unlock()
	var out := PackedInt32Array()
	out.resize(shape.size())
	var n: int = 0
	while n < shape.size():
		out[n] = shape[n] + cell.x
		out[n + 1] = shape[n + 1] + cell.y
		out[n + 2] = shape[n + 2] + cell.z
		out[n + 3] = shape[n + 3] + cell.x
		out[n + 4] = shape[n + 4] + cell.y
		out[n + 5] = shape[n + 5] + cell.z
		n += 6
	return out


## A part's cover boxes made [param stretch] as long on each axis, for a
## stretched part's cover ([method boxes_for]).
static func _stretched_boxes(part: Lbm.PartMesh, stretch: Vector3) -> Array[AABB]:
	var stretched: Array[AABB] = []
	var source: Array[AABB] = part.boxes
	if source.is_empty():
		source = [AABB(part.bounds.position / BrickLattice.CELL,
			part.bounds.size / BrickLattice.CELL)]
	for box: AABB in source:
		stretched.append(AABB(box.position * stretch, box.size * stretch).abs())
	return stretched


## The turned and stretched covers [method boxes_for] will want for
## [param placements] (LdrModel.Placement) and has not kept yet, set going
## on the engine's worker threads, each as soon as its part is read, and
## kept by [method finish_covers]: worked out on this thread, a cell at a
## time, as a model was put down a part at a time, they were 5.5 s of
## opening 42082-1 (510 covers, 1.27 million cells). The same covers, by the
## same code, kept the same way: only when and where they are worked out
## changes. Nothing to do on a build without threads.
func prepare_covers(placements: Array) -> void:
	finish_covers()
	if OS.get_thread_caller_id() != OS.get_main_thread_id() \
			or (OS.has_feature("web") and not OS.has_feature("threads")):
		return
	## [stretched, key] of each cover set going, its task, and what it made.
	var jobs: Array = []
	var tasks: Array[int] = []
	var made: Dictionary = {}
	var writing := Mutex.new()
	var asked: Dictionary = {}
	for item: Variant in placements:
		var placement: LdrModel.Placement = item
		var part: Lbm.PartMesh = library.mesh_for(placement.part_id)
		if part == null:
			continue
		var basis: Basis = placement.transform.basis
		var stretch := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
		var boxes: Array[AABB]
		var turn: Basis
		if not stretch.is_equal_approx(Vector3.ONE) and basis.determinant() > 0.0:
			var exact: Array = [part.get_instance_id(), basis]
			if _stretched_cache.has(exact) or asked.has(exact):
				continue
			asked[exact] = true
			jobs.append([true, exact])
			boxes = _stretched_boxes(part, stretch)
			turn = basis.orthonormalized()
		elif not part.boxes.is_empty() and not BrickLattice.is_square_to_grid(basis):
			var key: String = "%d|%s" % [part.get_instance_id(), basis]
			if _turned_cache.has(key) or asked.has(key):
				continue
			asked[key] = true
			jobs.append([false, key])
			boxes = part.boxes
			turn = basis
		else:
			continue
		var n: int = jobs.size() - 1
		tasks.append(WorkerTasks.add(func() -> void:
			var shape: PackedInt32Array = BrickLattice.boxes_for_turned(boxes, Vector3i.ZERO, turn)
			writing.lock()
			made[n] = shape
			writing.unlock(), true, "a turned cover"))
	if not jobs.is_empty():
		_preparing = [jobs, tasks, made, writing]


## What [method prepare_covers] set going: [jobs, tasks, made, its lock].
var _preparing: Array = []


## Wait for the covers [method prepare_covers] set going, and keep them as
## [method boxes_for] keeps its own (none it found empty). Asked by
## [method register] too, so nothing reads a cover while one is still being
## worked out.
func finish_covers() -> void:
	if _preparing.is_empty():
		return
	var preparing: Array = _preparing
	_preparing = []
	for task: int in preparing[1]:
		WorkerTasks.collect(task)
	var jobs: Array = preparing[0]
	var made: Dictionary = preparing[2]
	for n: int in jobs.size():
		var shape: PackedInt32Array = made.get(n, PackedInt32Array())
		if shape.is_empty():
			continue
		if jobs[n][0]:
			_stretched_cache[jobs[n][1]] = shape
		else:
			_turned_cache[jobs[n][1]] = shape


func _cells_for(part: Lbm.PartMesh, at: Transform3D) -> Array[Vector3i]:
	if part == null:
		return []
	# cells_for takes the span between two rotated corners, which is the
	# rotated box only for the 24 orientations it documents as its
	# precondition; anything else spans a diagonal instead. Every basis
	# this project places is one of the 24, but one read out of somebody
	# else's .ldr need not be — and squaring it up first, which is what
	# used to happen here, meant a brick turned thirty degrees reserved
	# the cells of a brick turned none.
	var cell: Vector3i = BrickLattice.to_cell(at.origin)
	if BrickLattice.is_square_to_grid(at.basis):
		return BrickLattice.cells_for(_cover_boxes(part), cell, at.basis)
	return BrickLattice.cells_for_turned(_cover_boxes(part), cell, at.basis)


## The lowest and highest cell (both inclusive) of [method _cells_for], or
## [] when it gives none: for a part square to the grid, from its boxes'
## corners, with no cell made. The corner is all Seating and
## Assistant._corner_cell ask for, and making every cell of each Technic
## part's cover to find it was most of the 4.9 s 42082-1 took after it
## opened.
func _cell_span(part: Lbm.PartMesh, at: Transform3D) -> Array:
	if part == null:
		return []
	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var hi := -lo
	if not BrickLattice.is_square_to_grid(at.basis):
		for cell: Vector3i in _cells_for(part, at):
			lo = lo.min(cell)
			hi = hi.max(cell)
		return [] if lo.x == 0x7FFFFFFF else [lo, hi]
	# As BrickLattice.cells_for spans each box, without walking the span.
	for box: AABB in _cover_boxes(part):
		var a: Vector3 = at.basis * Vector3(box.position)
		var b: Vector3 = at.basis * (Vector3(box.position) + Vector3(box.size))
		var from := Vector3i(int(round(minf(a.x, b.x))), int(round(minf(a.y, b.y))),
			int(round(minf(a.z, b.z))))
		var to := Vector3i(int(round(maxf(a.x, b.x))), int(round(maxf(a.y, b.y))),
			int(round(maxf(a.z, b.z))))
		if from.x >= to.x or from.y >= to.y or from.z >= to.z:
			continue
		lo = lo.min(from)
		hi = hi.max(to - Vector3i.ONE)
	if lo.x == 0x7FFFFFFF:
		return []
	var cell: Vector3i = BrickLattice.to_cell(at.origin)
	return [lo + cell, hi + cell]


## The boxes a part's cells are made from: its cover, or its bounding box
## when it has none.
static func _cover_boxes(part: Lbm.PartMesh) -> Array[AABB]:
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
	return boxes


## Turn the part in hand: a quarter about its own up, or, on a joint, a
## step about the joint's axis (JointSnap.step_of).
func rotate_held(quarter_turns: int) -> void:
	if is_carrying():
		carrying.turn(quarter_turns)
		return
	if _joint_site != null:
		for _n: int in absi(quarter_turns):
			_turn_on_joint(signi(quarter_turns))
		_joint_chosen = true
		return
	held_rotation = posmod(held_rotation + quarter_turns, 4)


## Roll the held part onto its next face: up, forward, down, back, and
## then over onto each side. On a joint, the next way onto it instead: in
## from the other face, the other way up, the next hole of a beam.
func tip_held(steps: int = 1) -> void:
	if _joint_site != null:
		_joint_way += steps
		_joint_chosen = true
		# Swung onto another end, if this way can be: the first such turn.
		_joint_extra = 0.0
		if not _joint_options.is_empty():
			var closings: Array = _closings(_joint_options,
				posmod(_joint_way, _joint_options.size()), _joint_site, _joint_basis)
			if not closings.is_empty():
				_joint_roll = 0
				_joint_extra = closings[0]
		return
	var faces: Array[String] = BrickLattice.FACES
	var at: int = maxi(faces.find(held_face), 0)
	held_face = faces[posmod(at + steps, faces.size())]


func hovered_brick() -> int:
	return _hovered


## Whether the ghost is showing, which is whether the pointer is aimed at
## somewhere a part could go. A figure being held is shown by a ghost per
## part instead of the one ghost, which is hidden the whole time.
func has_preview() -> bool:
	if is_carrying():
		return carrying.is_aimed()
	if not held_figure.is_empty():
		for ghost: MeshInstance3D in _figure_ghosts:
			if ghost.visible:
				return true
		return false
	return _ghost != null and _ghost.visible


## Where the one ghost stands, in LDU; null while it is not showing.
func ghost_place() -> Variant:
	if not has_preview() or is_carrying() or not held_figure.is_empty():
		return null
	return _ghost_transform.origin


## The ghost's whole pose, place and turn (what place() puts down).
func ghost_transform() -> Transform3D:
	return _ghost_transform


## Whether a click would put the held part down where the ghost is.
func can_place() -> bool:
	if is_carrying():
		return carrying.can_place()
	return has_preview() and _ghost_valid


func hide_preview() -> void:
	_ghost.visible = false
	_ghost_valid = false
	_joint_site = null
	_hide_figure_ghosts()
	if carrying != null:
		carrying.hide_ghost()


# -- a minifigure, as one thing ------------------------------------------


## Hold a figure to put down: its parts in its own frame, as
## Minifig.assemble gives them, and the name its parts will carry.
func hold_figure(parts: Array, called: String) -> void:
	held_figure = parts.duplicate()
	held_figure_name = called if not called.strip_edges().is_empty() else "Minifig"
	held_face = "up"


## Go back to holding the part that was held before.
func drop_figure() -> void:
	held_figure = []
	held_figure_name = ""
	_hide_figure_ghosts()


func is_holding_figure() -> bool:
	return not held_figure.is_empty()


## Where a figure facing a quarter turn would stand, aimed at a point:
## centred on a pair of studs, on whatever is highest under its feet.
##
## A figure stands on two studs side by side, one under each leg, so it
## snaps the way a 1 x 2 plate does — across a pair of studs, along a
## row of them — and rests on the highest surface under either foot.
func settle_figure(target: Vector3, rotation: int,
		hit: BrickLattice.Hit = null) -> Transform3D:
	var basis: Basis = BrickLattice.basis_for("up", rotation)
	var footprint := Vector2i(1, 2) if posmod(rotation, 2) == 1 else Vector2i(2, 1)
	var snapped: Vector3 = BrickLattice.snap_to_studs(target, footprint)
	var half := Vector3(footprint.x, 0.0, footprint.y) * (BrickLattice.STUD * 0.5)
	var from: Vector3i = BrickLattice.to_cell(snapped - half)
	var to: Vector3i = BrickLattice.to_cell(snapped + half)
	var columns: Array[Vector2i] = []
	for x: int in range(from.x, to.x):
		for z: int in range(from.z, to.z):
			columns.append(Vector2i(x, z))
	var rest_cell: int = lattice.resting_height(columns, GROUND_CELL)
	if hit != null and hit.is_valid() and hit.normal.y == 0:
		rest_cell = maxi(rest_cell, hit.adjacent().y)
	return Transform3D(basis, Vector3(snapped.x, rest_cell * BrickLattice.CELL,
		snapped.z))


## Whether a figure fits where it would stand: every part's geometry to
## hand and none of them in anything already there. Its own parts are
## not tested against each other — a head is meant to sit on its neck.
func figure_fits(parts: Array, at: Transform3D) -> bool:
	for item: Dictionary in parts:
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if part == null:
			return false
		if lattice.collides_boxes(boxes_for(part, at * (item["at"] as Transform3D))):
			return false
	return true


## Put a figure's parts in the world and the lattice, as one group, and
## return their numbers. No history: whoever calls it decides what an
## undo takes back.
func put_figure(parts: Array, called: String, at: Transform3D) -> PackedInt64Array:
	var group: String = unused_group(called)
	var ids := PackedInt64Array()
	for item: Dictionary in parts:
		var where: Transform3D = at * (item["at"] as Transform3D)
		var brick_id: int = world.add_brick(str(item["part"]), int(item["color"]), where)
		if brick_id == 0:
			continue
		world.get_brick(brick_id).group = group
		lattice.occupy_boxes(brick_id,
			boxes_for(library.mesh_for(str(item["part"])), where))
		ids.append(brick_id)
	return ids


## Put a part exactly somewhere a click on the grid could not put it — a
## sticker laid on a face — as one step that undo takes back. Returns the
## brick, or 0.
func put_part(part_id: String, color_code: int, at: Transform3D) -> int:
	var brick_id: int = world.add_brick(part_id, color_code, at)
	if brick_id == 0:
		return 0
	lattice.occupy_boxes(brick_id, boxes_for(library.mesh_for(part_id), at))
	_history.append({"undo": "remove", "brick": brick_id})
	_redo.clear()
	placed.emit(brick_id, part_id)
	return brick_id


## Take a brick off as one step that undo puts back: a sticker peeled off.
func take_off(brick_id: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return false
	var step: Dictionary = _apply({"undo": "remove", "brick": brick_id})
	_history.append(step)
	_redo.clear()
	if selection.erase(brick_id):
		selection_changed.emit(selection.size())
	removed.emit(brick_id)
	return true


## A group name no part of the model carries yet: a second Guard is
## "Guard 2", so the two stay two figures in the file and in a selection.
func unused_group(wanted: String) -> String:
	var taken: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		taken[brick.group] = true
	var base: String = wanted.strip_edges()
	if base.is_empty():
		base = "Minifig"
	if not taken.has(base):
		return base
	var n: int = 2
	while taken.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


## The bricks of the figure a brick belongs to, or nothing when it is not
## part of one: the bricks sharing its group, when they are a figure.
func figure_of(brick_id: int) -> PackedInt64Array:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or brick.group.is_empty():
		return PackedInt64Array()
	var members: Array = []
	for other: BrickWorld.Brick in world.bricks():
		if other.group == brick.group:
			members.append(other)
	if not Minifig.is_figure(members, library):
		return PackedInt64Array()
	var ids := PackedInt64Array()
	for other: BrickWorld.Brick in members:
		ids.append(other.id)
	return ids


func _place_figure() -> int:
	var ids: PackedInt64Array = put_figure(held_figure, held_figure_name, _ghost_transform)
	if ids.is_empty():
		return 0
	var steps: Array = []
	for brick_id: int in ids:
		world.get_brick(brick_id).step = _new_step(world.get_brick(brick_id))
		steps.append({"undo": "remove", "brick": brick_id})
	_history.append({"undo": "group", "steps": steps})
	_redo.clear()
	placed.emit(ids[0], held_figure_name)
	return ids[0]


## Take a whole figure off the model and hold it, facing the way it
## faced, so the next click puts it down somewhere else.
func _lift_figure(brick_id: int) -> bool:
	var members: PackedInt64Array = figure_of(brick_id)
	if members.size() < 2:
		return false
	var bricks: Array = []
	for member: int in members:
		bricks.append(world.get_brick(member))
	var frame: Variant = Minifig.frame_of(bricks, library)
	if frame == null:
		return false
	var home: Transform3D = frame
	var parts: Array = []
	var steps: Array = []
	var unpicked: bool = false
	for brick: BrickWorld.Brick in bricks:
		parts.append({"part": brick.part_id, "color": brick.color_code,
			"at": home.affine_inverse() * brick.transform})
		steps.append({"undo": "add", "part": brick.part_id,
			"color": brick.color_code, "transform": brick.transform,
			"group": brick.group, "unit": brick.unit, "step": brick.step, "was": brick.id})
		lattice.release(brick.id)
		world.remove_brick(brick.id)
		unpicked = selection.erase(brick.id) or unpicked
		removed.emit(brick.id)
	if unpicked:
		selection_changed.emit(selection.size())
	_history.append({"undo": "group", "steps": steps})
	_redo.clear()
	hold_figure(parts, (bricks[0] as BrickWorld.Brick).group)
	held_rotation = BrickLattice.turns_about(BrickLattice.snap_basis(home.basis), "up")
	_hovered = 0
	return true


func _preview_figure(origin: Vector3, direction: Vector3) -> void:
	_ghost.visible = false
	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	_hovered = hit.brick_id
	var target: Vector3
	if hit.is_valid():
		target = BrickLattice.to_ldu(hit.adjacent())
	else:
		var ground := Plane(Vector3.UP, GROUND_CELL * BrickLattice.CELL)
		var landing: Variant = ground.intersects_ray(origin, direction)
		if landing == null:
			_hide_figure_ghosts()
			_ghost_valid = false
			return
		target = landing
	_ghost_transform = settle_figure(target, held_rotation, hit)
	_ghost_valid = figure_fits(held_figure, _ghost_transform)
	for n: int in held_figure.size():
		if n >= _figure_ghosts.size():
			var made := MeshInstance3D.new()
			var tinted := ShaderMaterial.new()
			tinted.shader = GHOST_SHADER
			made.material_override = tinted
			made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(made)
			_figure_ghosts.append(made)
		var item: Dictionary = held_figure[n]
		var ghost: MeshInstance3D = _figure_ghosts[n]
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if part == null or part.surfaces.is_empty():
			ghost.visible = false
			continue
		ghost.mesh = part.surfaces[0]
		ghost.transform = _ghost_transform * (item["at"] as Transform3D)
		var material: ShaderMaterial = ghost.material_override
		material.set_shader_parameter("tint", library.color(int(item["color"])).shown)
		material.set_shader_parameter("valid", _ghost_valid)
		ghost.visible = true
	for n: int in range(held_figure.size(), _figure_ghosts.size()):
		_figure_ghosts[n].visible = false
	preview_changed.emit(held_figure_name, _ghost_valid)


func _hide_figure_ghosts() -> void:
	for ghost: MeshInstance3D in _figure_ghosts:
		ghost.visible = false


func history_depth() -> int:
	return _history.size()


## The steps to undo and to redo as they stand, the same dictionaries the
## history holds: a step in one of these and not in another is somebody's
## doing in between (ClaudeStep).
func steps_now() -> Array:
	return [_history.duplicate(), _redo.duplicate()]


## What each step undo would take back said in words, the most recent
## first, at most ``most`` of them: "placed Brick 2 x 4", "moved 12 parts".
func history_words(most: int = 25) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in range(_history.size() - 1, maxi(_history.size() - 1 - most, -1), -1):
		out.append(_words_for(_history[n]))
	return out


func _words_for(step: Dictionary) -> String:
	if step.has("words"):
		return str(step["words"])
	var kind: String = str(step.get("undo", ""))
	if kind == "group":
		var inner: Array = step.get("steps", [])
		var kinds: Dictionary = {}
		for each: Dictionary in inner:
			kinds[str(each.get("undo", ""))] = true
		var count: int = inner.size()
		if kinds.size() == 1:
			var only: String = kinds.keys()[0]
			var verb: String = {"remove": "placed", "add": "removed", "recolor": "painted",
				"move": "moved"}.get(only, "changed")
			return "%s %s" % [verb, _many(count)]
		if kinds.has("remove") and kinds.has("add"):
			return "moved %s" % _many(count / 2)
		return "changed %s" % _many(count)
	var brick: BrickWorld.Brick = world.get_brick(int(step.get("brick", 0))) \
		if step.has("brick") else null
	var part: String = str(step.get("part", brick.part_id if brick != null else "a part"))
	var info: PartLibrary.PartInfo = library.parts.get(part) if library != null else null
	var name: String = Inventory._tidy(info.name) if info != null else part
	match kind:
		"remove":
			return "placed %s" % name
		"add":
			return "removed %s" % name
		"recolor":
			return "painted %s" % name
		"move":
			return "moved %s" % name
	return "changed %s" % name


static func _many(count: int) -> String:
	return "1 part" if count == 1 else "%d parts" % count


## Undo this many steps at once: going back through the history to a
## point in it. Returns how many were undone.
func undo_steps(count: int) -> int:
	var done: int = 0
	while done < count and undo():
		done += 1
	return done
