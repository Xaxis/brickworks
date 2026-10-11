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


## Register a brick that was placed by something other than the mouse —
## loading a model, or the design assistant — so the lattice agrees.
func register(brick_id: int, part_id: String, at: Transform3D) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	lattice.occupy_boxes(brick_id, boxes_for(part, at))
	return true


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

	var part: Lbm.PartMesh = library.mesh_for(held_part)
	lattice.occupy_boxes(brick_id, boxes_for(part, _ghost_transform))

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
		"group": brick.group, "was": brick.id,
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
		"group": brick.group, "was": brick.id,
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
	_redo.append(_apply(step))
	# What an undo took away is no longer selected: an outline round
	# nothing, and a Delete that finds nothing to delete.
	_living_selection()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	var step: Dictionary = _redo.pop_back()
	_history.append(_apply(step))
	_living_selection()
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
		lattice.release(moving)
		world.move_brick(moving, to)
		lattice.occupy_boxes(moving,
			boxes_for(library.mesh_for(was.part_id), to))
		return {"undo": "move", "brick": moving, "transform": previous}

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
			"group": brick.group, "was": brick.id,
		}
		lattice.release(brick_id)
		world.remove_brick(brick_id)
		return reverse

	var part_id: String = step.get("part", "")
	var at: Transform3D = step.get("transform", Transform3D.IDENTITY)
	var new_id: int = world.add_brick(part_id, int(step.get("color", 0)), at)
	if new_id != 0:
		world.get_brick(new_id).group = str(step.get("group", ""))
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


## Add the brick under the cursor to the selection, or take it out.
func toggle_hovered() -> bool:
	if _hovered == 0:
		return false
	# A figure is one thing to whoever points at it. Picking out its
	# arm alone and moving it would leave the arm floating beside the
	# figure, which is not an edit anybody means.
	var members: PackedInt64Array = figure_of(_hovered)
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
			"color": brick.color_code, "transform": brick.transform,
			"group": brick.group, "was": brick.id})
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
		return Transform3D(at.basis, at.origin + shift))


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
func _reposition(to: Callable, words: String = "") -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0

	# Out of the lattice first, so the selection does not collide with
	# where it used to be.
	var was: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		lattice.release(brick_id)

	var landing: Dictionary = {}
	var blocked: bool = false
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to_here: Transform3D = to.call(brick.transform)
		var packed: PackedInt32Array = boxes_for(
			library.mesh_for(brick.part_id), to_here)
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
		landing[brick_id] = {"at": to_here, "boxes": packed}

	if blocked:
		for brick_id: int in alive:
			lattice.occupy_boxes(brick_id, boxes_for(
				library.mesh_for(world.get_brick(brick_id).part_id),
				was[brick_id]))
		return 0

	var steps: Array = []
	for brick_id: int in alive:
		steps.append({"undo": "move", "brick": brick_id,
			"transform": was[brick_id]})
		world.move_brick(brick_id, landing[brick_id]["at"])
		lattice.occupy_boxes(brick_id, landing[brick_id]["boxes"])
	var step: Dictionary = {"undo": "group", "steps": steps}
	if not words.is_empty():
		step["words"] = words
	_history.append(step)
	_redo.clear()
	return steps.size()


## Swap every selected brick for another part, in its colour, where it
## stands: a wall of 1 x 2s made 1 x 2 masonry bricks, a plain tile made a
## printed one. One step to undo. A part that would not fit where the old
## one was is left as it was. Returns [how many swapped, how many did not].
##
## Kept on its studs: a part of a different footprint is centred on the
## stud grid its own way, and stands on what the old one stood on.
func replace_selection(part_id: String) -> Vector2i:
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
		var at: Transform3D = _in_place_of(brick.transform, was, into)
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
		lattice.occupy_boxes(made, packed)
		steps.append({"undo": "remove", "brick": made})
		steps.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
			"transform": brick.transform, "group": brick.group, "was": brick.id})
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
			"transform": brick.transform, "group": brick.group, "was": brick.id})
		world.remove_brick(brick.id)
		removed.emit(brick.id)
	for item: Dictionary in plan:
		var brick: BrickWorld.Brick = item["brick"]
		var new_id: int = world.add_brick(str(item["part"]), brick.color_code, item["at"])
		if new_id == 0:
			continue
		world.get_brick(new_id).group = brick.group
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
			"group": brick.group, "was": brick.id})
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
		if not carrying.lifted and not group.is_empty():
			if not renamed.has(group):
				renamed[group] = unused_group(group)
			group = renamed[group]
		var brick_id: int = world.add_brick(str(item["part"]),
			int(item["color"]), item["at"])
		if brick_id == 0:
			continue
		world.get_brick(brick_id).group = group
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

	var onto: Variant = _onto_side_studs(part, basis, hit, origin, direction)
	_ghost_transform = onto if onto != null else _settle(part, basis, target, hit)
	_seated_on = hit.brick_id if onto != null else 0
	_ghost_valid = _fits_on_studs(part, _ghost_transform, _seated_on, Vector3i(hit.normal)) \
		if _seated_on != 0 else not lattice.collides_boxes(boxes_for(part, _ghost_transform))

	_ghost.mesh = part.surfaces[0]
	_ghost.transform = _ghost_transform
	_ghost.visible = true
	var tint: Color = library.color(held_color).shown
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
	return Transform3D(basis, Vector3(snapped.x, y, snapped.z))


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


func boxes_for(part: Lbm.PartMesh, at: Transform3D) -> PackedInt32Array:
	if part == null:
		return PackedInt32Array()
	var cell: Vector3i = BrickLattice.to_cell(at.origin)
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
	var shape: PackedInt32Array = _turned_cache.get(key, PackedInt32Array())
	if shape.is_empty():
		shape = BrickLattice.boxes_for_turned(
			part.boxes, Vector3i.ZERO, at.basis)
		_turned_cache[key] = shape
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
	if is_carrying():
		carrying.turn(quarter_turns)
		return
	held_rotation = posmod(held_rotation + quarter_turns, 4)


## Roll the held part onto its next face: up, forward, down, back, and
## then over onto each side.
func tip_held(steps: int = 1) -> void:
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


## Whether a click would put the held part down where the ghost is.
func can_place() -> bool:
	if is_carrying():
		return carrying.can_place()
	return has_preview() and _ghost_valid


func hide_preview() -> void:
	_ghost.visible = false
	_ghost_valid = false
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
	for brick: BrickWorld.Brick in bricks:
		parts.append({"part": brick.part_id, "color": brick.color_code,
			"at": home.affine_inverse() * brick.transform})
		steps.append({"undo": "add", "part": brick.part_id,
			"color": brick.color_code, "transform": brick.transform,
			"group": brick.group, "was": brick.id})
		lattice.release(brick.id)
		world.remove_brick(brick.id)
		selection.erase(brick.id)
		removed.emit(brick.id)
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
