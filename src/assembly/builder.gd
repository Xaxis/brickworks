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

## The part about to be placed, and the colour it will be placed in. A
## part taken in hand any way but off the model by a joint ([method
## lift_brick]) is held by none ([member grip]).
var held_part: String = "3001":
	set(value):
		# Another part taken in hand (the bin, the eyedropper, a session's)
		# lets go of the one lifted by X: back where it stood.
		if value != held_part and holds_lifted_part():
			put_hand_back()
		held_part = value
		grip = null
var held_color: int = 4
## The joint the part in hand was picked up off the model by, which it goes
## on by (Grip, grabseat); null for a part from the bin. A drag carries its
## own ([member carry_grip]).
var grip: Grip = null
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

## A train track in hand on a free end of a track down (TrackSnap).
var tracks := TrackSnap.new()

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

## Whose a step is: a step kept by a session from outside holds the session
## under [constant BY] (its chat, CommandSocket.actor_of); a step without it
## is the person's own, made in their tab. A step is the person's unless the
## code that keeps it says otherwise, and only a session's own code does: it
## keeps its changes inside [method by], and a tool that lands a change
## frames later carries the session with it to the frame it lands in
## (EditVerbs.press, Working.attend). Nothing is read off the clock. Before,
## a step was a call's when it was kept while the call was at work, so a
## part the person laid while their Claude saved was folded into the save
## and its undo took it (savereview2 G2); and an act of the person's the
## app ran a frame late, a Delete of 320 said first, was written as the
## chat's (savereview3 F1). A session's undo and redo take back only steps
## that hold it (AppTools._undo); the person's Undo takes back any step.
## What a run's or a call's step holds goes the same way: only the changes
## its own code made inside [method by], noted part by part as they are made
## (BrickWorld.Ledger, ClaudeStep), never the model's difference over the
## time it was at work (savereview5 F1: a chat's review_model took 916 parts
## of the person's panel design laid meanwhile).
const BY := "by"

## The session keeping steps now ([constant BY]), "" for the person: of the
## code running now, so one for the whole app, as there is one main thread.
## Set only by [method by] and [method by_wait], for code that runs to its
## end without waiting: a step the person makes while a session's call waits
## on a frame can never be kept as the session's.
static var acting: String = ""

## The bricks that are scenery (ModelStore.scenery), for the steps that
## move a baseplate into the model and back (FloorLayer.adopt).
var scenery: Dictionary = {}
## Puts a floor down (FloorLayer.put) and returns the one it replaced, for
## the step that changes what the model stands on. Unset, the step does
## nothing.
var floor_hook: Callable = Callable()
## Told after an undo or a redo that put the model's motions back as a step
## kept them (a drive kept moves the whole model: Motions.moved): the whole
## move they had before it, and the parts the step moved itself, id ->
## true. What it did not move, a part that landed after it was made, the
## store puts where the model now stands (ModelStore._follow_motions).
## Unset, nothing else moves.
var motions_hook: Callable = Callable()
## The motions as the step being undone or redone found them, before it
## first put them back; null when it has not.
var _motions_before: Motions = null
## Sets the comments pinned to parts (PinnedComments.set_words) and returns
## what they were, for the step that pins, resolves or opens one again.
## Unset, the step does nothing.
var pins_hook: Callable = Callable()
## Puts the reference picture as a step left it (ReferenceImage.put) and
## returns how it was, for the steps that lay, move, size, fade, lock,
## replace or take it away. Unset, the step does nothing.
var reference_hook: Callable = Callable()
## Makes the model what a step kept of it beside its parts (ModelStore
## .put_identity: its name, its file, its views) and returns what it was, for
## the step a clear kept for its undo (Main.clear_model). Unset, the step does
## nothing.
var store_hook: Callable = Callable()

## A step's parts not on the baseplate put back or taken out (ModelStore
## ._held_undo: those a delete took with their copy), (step) -> its reverse.
var held_hook: Callable = Callable()
## What a copy of parts (Carry.gather's) brings of those not on the baseplate,
## (parts) -> [{path, part, color, at, step, kind}] (ModelStore._held_carried),
## and those put down with the copy a paste or a Pattern put down, ([[that,
## its path now, and how its copy moved]], or how the paste moved them all)
## (ModelStore._held_put). Unset, a copy brings none.
var held_carry: Callable = Callable()
var held_put: Callable = Callable()
## Moves those not on the baseplate with their copy, (brick id -> how it
## moved) (ModelStore._held_follow): what a move put down calls, as its
## parts are put down anew, not moved. Unset, they stay.
var held_follow: Callable = Callable()

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
	selection_changed.connect(_selection_changed_elsewhere)


func _ready() -> void:
	_ghost_material = ShaderMaterial.new()
	_ghost_material.shader = GHOST_SHADER
	_ghost = MeshInstance3D.new()
	_ghost.material_override = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	carrying = Carry.new()
	# Whatever is lifted, let go of by a new hold (a paste, a duplicate, a
	# model put in whole) or by the carry put away: back where it stood. A
	# figure lifted stayed lifted under a paste, which went down inside the
	# place it stands in the file, and Escape put it back into the paste
	# (figreview3 F3).
	carrying.let_go = func() -> void:
		if holds_lift():
			_let_go_of_hand()
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
	lattice.occupy_moved(brick_id, cover, BrickLattice.grid_cell(at.origin))
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


## Place the held part where the ghost is, if the ghost is legal. Nothing
## else moves: a part the model holds below the ground goes there, through
## the floor's baseplate, and the model stays where it stands
## ([member below]).
func place() -> int:
	below = 0.0
	pasted_said = ""
	if is_carrying():
		return _put_carried()
	# Kept where it stands while Connect asks for the point it goes on by.
	if not _ghost_valid or connect_picking:
		return 0
	if not held_figure.is_empty():
		return _place_figure()
	if holds_lifted_part():
		return _put_lifted_part()
	var brick_id: int = world.add_brick(held_part, held_color, _ghost_transform)
	if brick_id == 0:
		return 0
	# Into the sub-assembly being edited, when one is.
	set_path(world.get_brick(brick_id), place_group)
	world.get_brick(brick_id).step = _new_step(world.get_brick(brick_id))

	var part: Lbm.PartMesh = library.mesh_for(held_part)
	var packed: PackedInt32Array = boxes_for(part, _ghost_transform)
	lattice.occupy_boxes(brick_id, packed)

	var step: Dictionary = {"undo": "remove", "brick": brick_id}
	# The sleeper a train track's joint needs goes down with it, in the same
	# undo (TrackSnap).
	if tracks.on_end and not tracks.sleepers.is_empty():
		step = {"undo": "group", "steps": [step] + _put_sleepers(tracks.sleepers)}
	_keep(step)
	_redo.clear()
	below = maxf(0.0, -part.lowest_at(_ghost_transform)) if part != null else 0.0
	# A number typed is spent once it is put down: the next follows the pointer.
	_typed_from = null
	# The next of it in hand was picked up by nothing.
	grip = null
	placed.emit(brick_id, held_part)
	return brick_id


## Sleepers put down under a train track's joint ([member tracks]), as
## [method place] puts a part: [part, colour, where] each. Their undo steps.
func _put_sleepers(list: Array) -> Array:
	var steps: Array = []
	for one: Array in list:
		var where: Transform3D = one[2]
		var sleeper: int = world.add_brick(str(one[0]), int(one[1]), where)
		if sleeper == 0:
			continue
		set_path(world.get_brick(sleeper), place_group)
		world.get_brick(sleeper).step = _new_step(world.get_brick(sleeper))
		var mesh: Lbm.PartMesh = library.mesh_for(str(one[0]))
		if mesh != null:
			lattice.occupy_boxes(sleeper, boxes_for(mesh, where))
		steps.append({"undo": "remove", "brick": sleeper})
	return steps


## How far the part last put down reaches below the ground, in LDU, for the
## status line; 0 when it does not. A placement never moves the rest of the
## model: until walk239 (2026-10-24) the model rose by whole cells to stand
## on such a part, and a 24 on an axle in a Technic brick on the baseplate
## lifted the brick off the baseplate's studs, so the build stood loose on
## its gear, a drag on the gear carried it and the next tipped the build
## onto its end. 8643-1's bracket, wheels and tyres still go on where its
## booklet has them, below the plate it is built up from; the model stays.
var below: float = 0.0


## Remove whatever is under the cursor.
func remove_hovered() -> bool:
	if _hovered == 0 or locked.has(_hovered):
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false

	_keep({
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

	_keep({
		"undo": "recolor",
		"brick": _hovered,
		"color": brick.color_code,
	})
	_redo.clear()
	return world.recolor_brick(_hovered, color_code)


## Lift the brick under the cursor into hand, to put down somewhere else.
##
## This is how a brick moves. There was no way to move one at all: the
## only edit was remove-and-rebuild, and a brick in the middle of
## something means taking off everything above it first.
##
## Lifting rather than dragging, because dragging needs a grab, a live
## re-solve of where it would land, and a drop — three things to get
## right — and lifting reuses the placement machinery already there. The
## brick becomes what you are holding, at its own colour and rotation, and
## the next click puts it down: the same part, moved ([method
## _put_lifted_part]). Until then it is in hand and still the model's, where
## it stood ([method _take_into_hand]), as a figure or a selection lifted is;
## Escape, Undo or another part taken in hand puts it back.
##
## lift_brick: lift_hovered for a brick named rather than aimed at: X over a part with
## nothing in hand, where no ghost has aimed at anything.
## [param from] and [param way]: the pointer's line, for the joint it was
## picked up by (Grip.picked), which it then goes on by; none without one,
## as Connect lifts a part.
func lift_brick(brick_id: int, from: Vector3 = Vector3.ZERO, way: Vector3 = Vector3.ZERO) -> bool:
	var held_by: Grip = _grip_at(brick_id, from, way)
	_hovered = brick_id
	if not lift_hovered():
		return false
	grip = held_by if held_by != null and held_by.part == held_part else null
	_grip_chosen = false
	return true


## The joint of [param brick_id] the pointer's line from [param from] going
## [param way] holds it by, where the line meets it; null for none.
func _grip_at(brick_id: int, from: Vector3, way: Vector3) -> Grip:
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if world != null else null
	if brick == null or way.is_zero_approx():
		return null
	var hit: BrickLattice.Hit = lattice.raycast(from, way)
	if hit.brick_id != brick_id:
		return null
	return Grip.picked(library, brick.part_id, brick.transform, from, way.normalized(),
		hit.distance)


func lift_hovered() -> bool:
	if _hovered == 0 or locked.has(_hovered):
		return false
	var brick: BrickWorld.Brick = world.get_brick(_hovered)
	if brick == null:
		return false
	if _lift_figure(_hovered):
		return true
	# Into hand, as a one-part selection lifted is: up to handkeep2 X took it
	# off the model and held a part like it from the bin, so the autosave and
	# Ctrl+S had it nowhere while it was in hand, and put back where it stood
	# it was a new part, in the step showing (figreview3 F1).
	var lifting: int = _hovered
	put_hand_back()
	held_part = brick.part_id
	held_color = brick.color_code
	held_face = BrickLattice.face_of(brick.transform.basis)
	held_rotation = BrickLattice.turns_about(brick.transform.basis, held_face)
	_take_into_hand([lifting])
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
	_let_go.clear()
	# What was lifted into hand is let go of, back where it stood: a world
	# about to be replaced takes it with the rest, and one opened again has it
	# where its file does (figreview2 F5: a reload with a figure in hand, put
	# down, made a second figure). A figure from the maker stays in hand.
	put_hand_back()
	grip = null
	carry_grip = null


## Take back the newest thing done. [param person]: the person's own undo,
## for whom a lift is the newest thing done while nothing is recorded since
## (put back where it stood, nothing else: EditVerbs says so). A session's
## undo takes back the newest step recorded and leaves what the person holds
## in hand: it said "Undid lifted 8 parts" and put their figure back, its own
## paint left on the model (figreview3 F5). A step that names a part in hand
## lets go of it first (_apply), whoever undoes it.
func undo(person: bool = true) -> bool:
	if person and lift_newest():
		put_hand_back()
		return true
	if _history.is_empty():
		return false
	# A part lifted off and put back by the undo is no longer held by it.
	grip = null
	var step: Dictionary = _history.pop_back()
	# Said before it is undone, while the brick a step names is still
	# there to name, and kept with the step that redoes it: the step
	# reversed would read backwards ("removed" for a placing redone).
	var words: String = _words_for(step)
	_motions_before = null
	var back: Dictionary = _apply(step)
	_follow_motions(back)
	back["words"] = words
	# Still whoever made it, to redo: a session's redo laid again the part
	# the person had taken back themselves (savereview2 U4).
	carry_whose(step, back)
	_redo.append(back)
	settled = _history.back() if not _history.is_empty() else {}
	# What an undo took away is no longer selected: an outline round
	# nothing, and a Delete that finds nothing to delete.
	_living_selection()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	grip = null
	var step: Dictionary = _redo.pop_back()
	_motions_before = null
	var again: Dictionary = _apply(step)
	_follow_motions(again)
	if step.has("words"):
		again["words"] = step["words"]
	# Whoever made it, whoever redoes it: kept as it was, never as the
	# session redoing it.
	carry_whose(step, again)
	_history.append(again)
	settled = again
	_living_selection()
	return true


## Once a step is undone or redone, [param step] the one that reverses it:
## if it put the model's motions back, what it did not move itself told
## where the model now stands ([member motions_hook]), after all of it, so
## the joints are looked for with every part where the step leaves it.
func _follow_motions(step: Dictionary) -> void:
	var before: Motions = _motions_before
	_motions_before = null
	if before == null or not motions_hook.is_valid():
		return
	var moved_itself: Dictionary = {}
	_moved_by(step, moved_itself)
	motions_hook.call(before.moved, moved_itself)


## Into [param into], each part [param step] moves, takes off or puts
## down, by its id now: of a step that reverses one, the parts that one
## changed, and the parts on their way it put down (ModelStore.put_identity,
## "landed"), where the motions it put back stand them already.
func _moved_by(step: Dictionary, into: Dictionary) -> void:
	match str(step.get("undo", "")):
		"group":
			for inner: Variant in step.get("steps", []):
				_moved_by(inner, into)
		"move", "remove":
			into[_live(int(step["brick"]))] = true
		"add":
			if step.has("was"):
				into[_live(int(step["was"]))] = true
		"store":
			for landed: Variant in (step["store"] as Dictionary).get("landed", []):
				into[_live(int((landed as Array)[0]))] = true


## Move [param brick_id] to [param to] with no step of its own: one an undo
## or a redo carries along with what it moves ([member motions_hook]).
func put_at(brick_id: int, to: Transform3D) -> void:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return
	lattice.release(brick_id)
	world.move_brick(brick_id, to)
	lattice.occupy_boxes(brick_id, boxes_for(library.mesh_for(brick.part_id), to))


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

	# A step that names a part in hand (an undo or a redo reaching it): the
	# hand lets go first, every part back where it stood, its cover read
	# there ([method _hand_touched]).
	if not _hand.is_empty() and step.has("brick") and _hand.has(_live(int(step["brick"]))):
		_let_go_of_hand()

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

	# Comments pinned to parts: the whole set as it was, its own reverse.
	if step.get("undo", "") == "pins":
		return {"undo": "pins", "pins": pins_hook.call(step["pins"]) if pins_hook.is_valid()
			else step["pins"]}

	# What the model is beside its parts, as it was: its own reverse.
	if step.get("undo", "") == "store":
		return {"undo": "store", "store": store_hook.call(step["store"]) if store_hook.is_valid()
			else step["store"]}

	# Parts not on the baseplate a copy deleted took with it, or a paste
	# brought, put back or taken out again (ModelStore._held_go_with,
	# _held_put). One that has landed since (ModelStore.place_awaited) is a
	# brick: taken off with the rest, and put back as the brick it was
	# ("bricks"). Up to 2026-11-12 it stayed: a paste undone after its part
	# landed left that part in a copy of nothing else, and redone put a
	# second one beside it (pcredesign H_r1, H_r2).
	if step.get("undo", "") == "held":
		var gone: Array = []
		for pair: Variant in step.get("take", []):
			var placement: LdrModel.Placement = (pair as Array)[0]
			if placement.landed != 0:
				var off: Dictionary = _apply({"undo": "remove", "brick": placement.landed})
				if off.get("undo", "") == "add":
					gone.append(off)
		for brick_step: Dictionary in step.get("bricks", []):
			_apply(brick_step)
		var back: Dictionary = (held_hook.call(step) if held_hook.is_valid() else step).duplicate()
		back["bricks"] = gone
		return back

	# Parts not on the baseplate moved with their copy (ModelStore
	# ._held_follow): each [placement, where it goes], the reverse where it
	# was.
	if step.get("undo", "") == "heldmoved":
		var back: Array = []
		for pair: Variant in step.get("moves", []):
			var placement: LdrModel.Placement = (pair as Array)[0]
			back.append([placement, placement.transform])
			placement.transform = (pair as Array)[1]
		return {"undo": "heldmoved", "moves": back}

	# What another part of the app keeps of the model beside its parts, put
	# as the step left it: its "put" given what the step kept, and handing
	# back how it was, its own reverse (ModelStore.replace_moved: the lines
	# of the file it was opened from).
	if step.get("undo", "") == "put":
		var put: Callable = step["put"]
		return {"undo": "put", "put": put,
			"kept": put.call(step["kept"]) if put.is_valid() else step["kept"]}

	# The picture to build over, as it was: its own reverse.
	if step.get("undo", "") == "reference":
		return {"undo": "reference", "reference": reference_hook.call(step["reference"])
			if reference_hook.is_valid() else step["reference"]}

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

	# The app's own saved steps made the person's by their first step edit,
	# or back (BrickWorld.steps_own, AuthorSteps.ensure): its own reverse.
	if step.get("undo", "") == "stepsown":
		var was_own: bool = world.steps_own
		world.steps_own = bool(step["own"])
		return {"undo": "stepsown", "own": was_own}

	# A part the model holds and does not show put in another step
	# (AuthorSteps, BrickWorld.held), its own reverse; and the brick it was
	# put down as, when it came after the edit (ModelStore.place_awaited).
	if step.get("undo", "") == "heldstep":
		var placement: LdrModel.Placement = step["held"]
		var had: int = placement.step
		placement.step = int(step["step"])
		var landed: BrickWorld.Brick = world.get_brick(_live(placement.landed)) \
			if placement.landed != 0 else null
		if landed != null:
			had = landed.step
			landed.step = int(step["step"])
		return {"undo": "heldstep", "held": placement, "step": had}

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

	# The model's motions (Motions): the whole set as it was, its own
	# reverse. Copies, so a motion changed later is not changed in the past.
	if step.get("undo", "") == "motions":
		var had: Motions = world.motions.copy() if world.motions != null else Motions.new()
		if _motions_before == null:
			_motions_before = had
		world.motions = (step["motions"] as Motions).copy()
		return {"undo": "motions", "motions": had}

	# The program for the model's motors (HubProgram), as it was: its own
	# reverse.
	if step.get("undo", "") == "program":
		var had: String = world.program
		world.program = str(step["program"])
		return {"undo": "program", "program": had}

	# How the booklet shows its steps (BookletLooks): the whole table as it
	# was, its own reverse.
	if step.get("undo", "") == "steplooks":
		var looked: Dictionary = world.step_looks.duplicate(true)
		world.step_looks = (step["looks"] as Dictionary).duplicate(true)
		return {"undo": "steplooks", "looks": looked}

	# Each sub-model's own lights and views (BrickWorld.section_lines): the
	# whole table as it was, its own reverse.
	if step.get("undo", "") == "sectionlines":
		var lined: Dictionary = world.section_lines
		var framed: Dictionary = world.section_frames
		world.section_lines = (step["lines"] as Dictionary).duplicate(true)
		# And the frame each is in (BrickWorld.section_frames), with them.
		world.section_frames = (step.get("frames", framed) as Dictionary).duplicate(true)
		return {"undo": "sectionlines", "lines": lined, "frames": framed}

	# Where the parts not on the baseplate are in the tree (BrickWorld
	# .held_paths): the table as it was, and each of them that landed since
	# the change, where the table had it, with it (BrickWorld.held_landed). A
	# rename undone after its part on its way had landed left that part in a
	# copy of the new name.
	if step.get("undo", "") == "heldpaths":
		var had: Dictionary = world.held_paths
		var paths: Dictionary = (step["paths"] as Dictionary).duplicate()
		for id: Variant in world.held_landed:
			var landed: BrickWorld.Brick = world.get_brick(_live(int(id)))
			var open: String = str(world.held_landed[id])
			if landed != null and paths.has(open) \
					and Assemblies.path_of(landed) == str(had.get(open, open)):
				set_path(landed, str(paths[open]))
		world.held_paths = paths
		return {"undo": "heldpaths", "paths": had}

	# The name each section was read under (BrickWorld.section_files): the
	# whole table as it was, its own reverse.
	if step.get("undo", "") == "sectionfiles":
		var named: Dictionary = world.section_files
		world.section_files = (step["files"] as Dictionary).duplicate()
		return {"undo": "sectionfiles", "files": named}

	# The lines the model's file carried (BrickWorld.kept_lines), the table
	# as it was: set once at the open and never changed, so shared, not copied.
	if step.get("undo", "") == "keptlines":
		var had: Dictionary = world.kept_lines
		world.kept_lines = step["lines"]
		return {"undo": "keptlines", "lines": had}

	# Lights of the model's own (BrickWorld.scene_lights) a step took out or
	# put in: a sub-model's, taken apart into the model (Assemblies.ungroup).
	# Each found by what it is, not where it is in the list, and the list made
	# anew, as Render's are: a light placed or changed there, which keeps no
	# step, is left as it is.
	if step.get("undo", "") == "scenelights":
		var lights: Array = world.scene_lights.duplicate()
		var taken: Array = []
		for light: Dictionary in step.get("take", []):
			for n: int in lights.size():
				if SceneLights.same([lights[n]], [light]):
					taken.append(lights[n])
					lights.remove_at(n)
					break
		var put: Array = step.get("put", [])
		lights.append_array(put)
		world.scene_lights = lights
		return {"undo": "scenelights", "take": put, "put": taken}

	# Which copy of someone else's file each path is: the table as it was,
	# its own reverse.
	if step.get("undo", "") == "unitchains":
		var chained: Dictionary = world.unit_chains
		world.unit_chains = (step["chains"] as Dictionary).duplicate()
		return {"undo": "unitchains", "chains": chained}

	if step.get("undo", "") == "unitstep":
		var unit: String = str(step["unit"])
		var held: Dictionary = {"undo": "unitstep", "unit": unit,
			"step": int(world.unit_steps.get(unit, -1))}
		# A file's copy of no step says -1 (LdrModel), which "kept" puts back.
		if world.unit_steps.has(unit) and int(held["step"]) == -1:
			held["kept"] = true
		# -1 is none; AuthorSteps.IN_PARENT, a copy built in its parent's steps.
		if int(step["step"]) == -1 and not bool(step.get("kept", false)):
			world.unit_steps.erase(unit)
		else:
			world.unit_steps[unit] = int(step["step"])
		return held

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
	var new_id: int = world.add_brick(part_id, int(step.get("color", 0)), at,
		int(step.get("was", 0)))
	if new_id != 0:
		world.get_brick(new_id).group = str(step.get("group", ""))
		world.get_brick(new_id).unit = str(step.get("unit", ""))
		world.get_brick(new_id).step = int(step.get("step", -1))
		# The line of someone else's file it was (SourceFile), under
		# another number too.
		if new_id != int(step.get("was", new_id)):
			world.get_brick(new_id).origin = world.gone_origin(int(step["was"]))
		# Put back where it was taken off: the cover it had then, kept with
		# the step, rather than worked out again from the part.
		var cover: Variant = step.get("cover")
		if cover is Array and not ((cover as Array)[0] as PackedInt32Array).is_empty():
			lattice.occupy_moved(new_id, cover, Vector3i.ZERO)
		else:
			lattice.occupy_boxes(new_id,
				boxes_for(library.mesh_for(part_id), at))
		# The brick comes back under its old number (BrickWorld.add_brick),
		# or a new one when that is taken. Steps further back that name the
		# one that went — a paint before a swap, a move before a removal —
		# are read through this then, or undoing past it did nothing.
		if step.has("was"):
			renumber(int(step["was"]), new_id)
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


## What a click with Select on this brick takes: none for a locked brick,
## nor for one the timeline has not put on yet ([method shown_only]).
func takes(brick_id: int) -> PackedInt64Array:
	if brick_id == 0 or locked.has(brick_id) or is_ahead(brick_id):
		return PackedInt64Array()
	# At a step of the timeline, its parts on show: at a set's fifth step a
	# click took the whole house, 149 parts with 77 not on yet, and a colour
	# then painted them all (appwalk, stepedit). The rest is held with the
	# selection (hold_unseen), for a move to carry.
	return shown_only(_taken_whole(brick_id))


## The whole of what a click on [param brick_id] takes, on show or not.
func _taken_whole(brick_id: int) -> PackedInt64Array:
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


# -- what the step showing holds ---------------------------------------------
#
# While the timeline shows a step (StepsBar), the parts it has not put on
# yet are drawn nowhere and the pointer passes through them
# (BrickLattice.ahead). A selection holds only parts on show, and so every
# edit of it (a colour, Delete, a move, a turn, a mirror, Replace, Cut and
# Copy, a group) reaches only what the person sees, as Studio and LDCad edit
# at a step. Off the timeline, or at its last step, nothing is ahead and
# nothing here changes anything.


## More than nothing while an edit made for every step runs ([method
## in_every_step]): a session's call sent with all_steps (replace_parts).
var _every_step: int = 0


## Whether the timeline has not put [param brick_id] on yet, so nothing the
## person does at this step reaches it.
func is_ahead(brick_id: int) -> bool:
	return _every_step == 0 and lattice != null and lattice.ahead.has(brick_id)


## [param ids] without the parts the timeline has not put on yet.
func shown_only(ids: PackedInt64Array) -> PackedInt64Array:
	if _every_step > 0 or lattice == null or lattice.ahead.is_empty():
		return ids
	var out := PackedInt64Array()
	for brick_id: int in ids:
		if not lattice.ahead.has(brick_id):
			out.append(brick_id)
	return out


## Whether the timeline shows a step with parts still to come.
func at_a_step() -> bool:
	return lattice != null and not lattice.ahead.is_empty()


## The number of the step the timeline shows, -1 for none (Main).
var step_showing: Callable = Callable()


## Why a session's change to [param ids] is not made: some are in steps after
## the one the person is looking at, and [param all_steps] is not true. ""
## when it can go ahead. Refused before anything is written, the parts
## named, at most ten.
func later_refusal(ids: Array, all_steps: Variant) -> String:
	# Only a real true lets it through: read at the tool's edge
	# ([method all_steps_read]), and anything else here is no leave. A
	# Variant compared with == true was a script error for "true" and 1, and
	# the part was taken off with the gate skipped (stepreview F2).
	if (all_steps is bool and all_steps) or not at_a_step():
		return ""
	var later: Array = []
	var seen: Dictionary = {}
	for raw: Variant in ids:
		var brick_id: int = int(raw)
		if lattice.ahead.has(brick_id) and not seen.has(brick_id):
			seen[brick_id] = true
			later.append(brick_id)
	if later.is_empty():
		return ""
	var step: int = int(step_showing.call()) if step_showing.is_valid() else -1
	var named: Array = later.slice(0, 10).map(func(id: int) -> String: return "#%d" % id)
	return ("Not applied — the person is looking at %s of the timeline, and %d of the parts this "
		+ "changes are in later steps, not on the screen yet: %s%s. Change only parts on show, "
		+ "or send all_steps: true to change those too (say so to the person).") % [
		"step %d" % step if step > 0 else "a step", later.size(), ", ".join(PackedStringArray(named)),
		" and %d more" % (later.size() - 10) if later.size() > 10 else ""]


## all_steps as a session sent it, checked at the tool's edge (AppTools.
## refusal, Assistant._run_tool): only JSON's true reaches the parts a step
## has not put on, and false or no all_steps leaves them out. Anything else
## ("true", 1, "1", null, an object) is refused with these words before
## anything changes, never read as a leave: a leave to change what the
## person cannot see is never guessed (stepreview F2). "" for a bool or none.
static func all_steps_read(input: Dictionary) -> String:
	if not input.has("all_steps") or input["all_steps"] is bool:
		return ""
	return "Not applied — all_steps must be true or false, and it was %s; nothing changed." \
		% JSON.stringify(input["all_steps"]).left(40)


## [param edit] called with every step's parts in reach: what it returns.
func in_every_step(edit: Callable) -> Variant:
	_every_step += 1
	var out: Variant = edit.call()
	_every_step -= 1
	return out


## The selection let go of what the timeline no longer shows: a step back
## from the one it was made at, or the timeline opened on its first step.
## What it let go of comes back when the timeline shows it again or is put
## away, unless the selection was changed in between: parts selected, a look
## at the steps, and they are still selected after. [param changed]: the
## parts the step put on or took off (Main._steps_revealed_upto), the only
## ones looked at; null to look at the whole selection, as after the order
## itself changed. How many came or went.
##
## Nothing is said to the rest of the window here: its panels hear once the
## steps stop changing it ([method _settle_kept]). Told at every step,
## each of them read the whole selection again: on 10030 with every part
## selected a step took 113-179 ms against pre261's 18-21 (stepreview F3).
## The outline is drawn and the line said by Main as the step is shown.
func keep_shown(changed: Variant = null) -> int:
	if lattice == null:
		return 0
	var gone: Array = []
	var back: Array = []
	if changed is PackedInt64Array or changed is Array:
		for raw: Variant in changed:
			var brick_id: int = int(raw)
			if lattice.ahead.has(brick_id):
				if selection.has(brick_id):
					gone.append(brick_id)
			elif _let_go.has(brick_id) and _may_come_back(brick_id):
				back.append(brick_id)
	else:
		if not lattice.ahead.is_empty():
			for brick_id: int in selection:
				if lattice.ahead.has(brick_id):
					gone.append(brick_id)
		for brick_id: int in _let_go:
			if not lattice.ahead.has(brick_id) and _may_come_back(brick_id):
				back.append(brick_id)
	if gone.is_empty() and back.is_empty():
		return 0
	for brick_id: int in gone:
		selection.erase(brick_id)
		_let_go[brick_id] = true
	for brick_id: int in back:
		_let_go.erase(brick_id)
		selection[brick_id] = true
	_settle_kept()
	return gone.size() + back.size()


func _may_come_back(brick_id: int) -> bool:
	return world.get_brick(brick_id) != null and not locked.has(brick_id) \
		and not lattice.unseen.has(brick_id)


## The parts of the selection the step showing has not put on: let go of by
## a step back ([method keep_shown]), or the rest of a sub-assembly a click
## took at a step ([method hold_unseen]). They come back on show, and a move
## of the selection carries them ([method _moving_selection]); nothing else
## reaches them. Whether it is keep_shown saying the selection changed,
## which keeps them.
var _let_go: Dictionary = {}
var _keeping: bool = false
## How long the steps leave the selection alone before the window's panels
## are told of what they did to it: a step a press, or Play's every frame,
## tells them once, after.
const SETTLE_SECONDS := 0.3
var _kept_timer: Timer = null


func _settle_kept() -> void:
	if not is_inside_tree():
		_tell_kept()
		return
	if _kept_timer == null:
		_kept_timer = Timer.new()
		_kept_timer.one_shot = true
		_kept_timer.wait_time = SETTLE_SECONDS
		_kept_timer.timeout.connect(_tell_kept)
		add_child(_kept_timer)
	_kept_timer.start()


func _tell_kept() -> void:
	_keeping = true
	selection_changed.emit(selection.size())
	_keeping = false


## Any other change to the selection is the person's or a tool's: what a
## step back let go of stays let go, and the panels have heard of it.
func _selection_changed_elsewhere(_count: int) -> void:
	if not _keeping:
		_let_go.clear()
		if _kept_timer != null:
			_kept_timer.stop()


## The parts of [param whole] (a sub-assembly or a figure a click or a box
## took at a step) the step has not put on, held with the selection: a step
## on shows them selected, and a move of the selection carries them
## ([member _let_go]). Called after the selection said it changed.
func hold_unseen(whole: PackedInt64Array) -> void:
	if lattice == null or lattice.ahead.is_empty() or _every_step > 0:
		return
	for brick_id: int in whole:
		if lattice.ahead.has(brick_id) and not locked.has(brick_id):
			_let_go[brick_id] = true


## How many parts of later steps the last move of the selection carried
## with it ([method _moving_selection]), for what is said of it.
var riding_later: int = 0


## What a rigid move of the selection moves: the parts on show selected,
## and at a step of the timeline, the rest of what was taken with them,
## drawn or not. A move, a turn, a tip, a mirror, a swing, a drag, a lift
## into the hand and the arrows all move a sub-assembly whole: its later
## parts go with it, so it never comes apart where nobody can see it
## (stepreview F1: the house at step 5 was refused a stud's move by its own
## unseen roof, and a drag took 72 of its 149 parts and left the roof on
## the ground). They are
##  - the parts a step back took off the selection, and the rest of a
##    sub-assembly a click took at a step ([member _let_go]);
##  - every later part of a sub-assembly (Builder.unit_of, at the level being
##    edited) whose parts on show are all selected: Select all, a box.
## Moving with the rest, none of them is in its way. An edit that changes
## what a part is (a colour, Delete, Replace, Cut) reaches only the parts on
## show ([method _living_selection]). Says how many of them are later parts
## ([member riding_later]).
func _moving_selection() -> PackedInt64Array:
	var alive: PackedInt64Array = _living_selection()
	var moving: PackedInt64Array = _moving_of(alive)
	riding_later = moving.size() - alive.size()
	return moving


## What a rigid move of [param alive], the selection's parts on show, moves
## ([method _moving_selection]), told nobody: what the Hinge and the
## handles' rings ask of the joint a swing would turn.
func _moving_of(alive: PackedInt64Array) -> PackedInt64Array:
	if alive.is_empty() or not at_a_step() or _every_step > 0:
		return alive
	var moving: Dictionary = {}
	for brick_id: int in alive:
		moving[brick_id] = true
	# Nor any in hand: the hand puts them down, or back.
	for brick_id: int in _let_go:
		if lattice.ahead.has(brick_id) and world.get_brick(brick_id) != null \
				and not locked.has(brick_id) and not world.in_hand(brick_id):
			moving[brick_id] = true
	if unit_of.is_valid():
		var asked: Dictionary = {}
		for brick_id: int in alive:
			if asked.has(brick_id):
				continue
			var members: PackedInt64Array = unit_of.call(brick_id)
			for member: int in members:
				asked[member] = true
			if members.size() < 2:
				continue
			var later: Array = []
			var whole: bool = true
			for member: int in members:
				if lattice.ahead.has(member):
					later.append(member)
				elif not moving.has(member) and not lattice.unseen.has(member):
					whole = false
					break
			if whole:
				for member: int in later:
					if not locked.has(member) and world.get_brick(member) != null \
							and not world.in_hand(member):
						moving[member] = true
	if moving.size() == alive.size():
		return alive
	return PackedInt64Array(moving.keys())


## Said after a move that carried parts of later steps: "" when it carried
## none.
func riding_said() -> String:
	return "" if riding_later == 0 else "%d of them in later steps, not on the screen yet, went with it" \
		% riding_later


## Add the brick under the cursor to the selection, or take it out.
func toggle_hovered() -> bool:
	if _hovered == 0 or locked.has(_hovered) or is_ahead(_hovered):
		return false
	var whole: PackedInt64Array = _taken_whole(_hovered)
	var members: PackedInt64Array = shown_only(whole)
	if members.is_empty():
		return false
	# What the selection held unseen already stays held: its saying it
	# changed forgets it (_selection_changed_elsewhere).
	var held: Dictionary = _let_go.duplicate()
	var took: bool = true
	if members.size() > 1:
		var all_in: bool = true
		for brick_id: int in members:
			all_in = all_in and selection.has(brick_id)
		took = not all_in
		for brick_id: int in members:
			if all_in:
				selection.erase(brick_id)
			else:
				selection[brick_id] = true
		selection_changed.emit(selection.size())
	elif selection.erase(_hovered):
		took = false
		selection_changed.emit(selection.size())
	else:
		selection[_hovered] = true
		selection_changed.emit(selection.size())
	_let_go = held
	if took:
		hold_unseen(whole)
	else:
		for brick_id: int in whole:
			_let_go.erase(brick_id)
	return true


## Pick one brick out, as a click with the Select tool does: the
## selection becomes it (its whole figure, for a minifigure part), or with
## ``add`` it is added or taken away.
func select_brick(brick_id: int, add: bool) -> bool:
	if brick_id == 0 or locked.has(brick_id) or world.get_brick(brick_id) == null \
			or is_ahead(brick_id):
		return false
	if not add:
		selection.clear()
		_let_go.clear()
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
		_let_go.clear()
	var took: int = 0
	var wholes: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var on_screen: Variant = where.call(brick)
		if not (on_screen is Rect2):
			continue
		var caught: bool = (box.intersects(on_screen) if touching
			else box.encloses(on_screen))
		if caught and not selection.has(brick.id) and not locked.has(brick.id) \
				and not is_ahead(brick.id):
			# A box round part of a sub-assembly takes all of it: what of it
			# the step showing has on (takes), the rest held (hold_unseen).
			var whole: PackedInt64Array = unit_of.call(brick.id) if unit_of.is_valid() \
				else PackedInt64Array([brick.id])
			wholes.append(whole)
			for member: int in shown_only(whole):
				if not selection.has(member) and not locked.has(member):
					selection[member] = true
					took += 1
	if took > 0 or not add:
		var held: Dictionary = _let_go.duplicate()
		selection_changed.emit(selection.size())
		_let_go = held
		for whole: PackedInt64Array in wholes:
			hold_unseen(whole)
	return took


func clear_selection() -> void:
	# Let go of on purpose, with or without parts on show (keep_shown).
	_let_go.clear()
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
				and not locked.has(brick.id) and not is_ahead(brick.id)):
			selection[brick.id] = true
	selection_changed.emit(selection.size())
	return selection.size()


## Drop from the selection anything that is no longer in the world, and
## say how many are left. Called before every operation, because a brick
## can go away by undo or by the assistant rebuilding the model. Nor what
## the step showing has not put on: whatever put it in the selection, an
## edit reaches only what is on show ([method shown_only]).
func _living_selection() -> PackedInt64Array:
	# A part in hand picked again (a session's selection by number): the
	# hand lets go first, each part back where it stood, so what is done to
	# the selection is done to the model's own parts there.
	if not _hand.is_empty():
		for brick_id: int in selection:
			if _hand.has(brick_id):
				_let_go_of_hand()
				break
	var alive := PackedInt64Array()
	var gone: Array = []
	var unseen: Array = []
	for brick_id: int in selection:
		if world.get_brick(brick_id) == null:
			gone.append(brick_id)
		elif is_ahead(brick_id):
			unseen.append(brick_id)
		else:
			alive.append(brick_id)
	for brick_id: int in gone + unseen:
		selection.erase(brick_id)
	# Not on show, it is still the selection's, as a step back's are
	# (keep_shown): a move carries it, and a step on shows it selected.
	for brick_id: int in unseen:
		_let_go[brick_id] = true
	if not gone.is_empty() or not unseen.is_empty():
		_keeping = true
		selection_changed.emit(selection.size())
		_keeping = false
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
	_keep({"undo": "group", "steps": steps})
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
	_keep({"undo": "group", "steps": steps})
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
	var moved: int = _reposition(func(at: Transform3D) -> Transform3D:
		return Transform3D(at.basis, at.origin + shift), "", by)
	if moved > 0:
		var axis: int = shift.abs().max_axis_index()
		last_way = Vector3.ZERO
		last_way[axis] = signf(shift[axis])
	return moved


## Shift the selection by any amount in LDU, to the thousandth an LDraw
## file writes, or refuse and change nothing: the properties' X, Y and Z
## typed, as Studio's and LDCad's moves by a typed amount. Whole cells go
## through [method move_selection], which keeps each cover. A part a set
## has off the 2 LDU lattice (8841-1's pan hangs 0.35 LDU off it, 5762-1's
## lights stand an odd LDU out of their clips) could only be put a cell
## either side of where the file has it.
func move_selection_by(by: Vector3) -> int:
	var cells := Vector3i(roundi(by.x / BrickLattice.CELL), roundi(by.y / BrickLattice.CELL),
		roundi(by.z / BrickLattice.CELL))
	var rest: Vector3 = (by - BrickLattice.to_ldu(cells)).abs()
	if maxf(rest.x, maxf(rest.y, rest.z)) < 0.0005:
		var moved: int = move_selection(cells)
		if moved > 0:
			return moved
	return _moved_joined(by)


## The selection moved by [param by] as one step where each part has room
## by the rule a part put down has it (room_for): nothing in its way but
## what it joins as real parts join, a wheel round its pin, a plate's hole
## on an axle. A typed move onto a joint was refused by the bare lattice,
## which reads a pin in its bore as two parts in one place. Refused,
## changing nothing, where any would run into something.
func _moved_joined(by: Vector3) -> int:
	var alive: PackedInt64Array = _moving_selection()
	if alive.is_empty():
		return 0
	if _lock_refuses_ids(alive, func(at: Transform3D) -> Transform3D:
			return Transform3D(at.basis, at.origin + by)):
		return 0
	var was: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		lattice.release(brick_id)
	var landing: Dictionary = {}
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to: Transform3D = _tidy(Transform3D(brick.transform.basis,
			brick.transform.origin + by), BrickLattice.is_square_to_grid(brick.transform.basis))
		if not room_for(brick.part_id, to, true):
			for back: int in alive:
				lattice.occupy_boxes(back, boxes_for(
					library.mesh_for(world.get_brick(back).part_id), was[back]))
			return 0
		landing[brick_id] = to
	var steps: Array = []
	for brick_id: int in alive:
		steps.append({"undo": "move", "brick": brick_id, "transform": was[brick_id]})
		world.move_brick(brick_id, landing[brick_id])
		lattice.occupy_boxes(brick_id, boxes_for(
			library.mesh_for(world.get_brick(brick_id).part_id), landing[brick_id]))
	_keep({"undo": "group", "steps": steps,
		"words": "moved %s %s LDU" % [_many(steps.size()), _ldu_words(by)]})
	_redo.clear()
	return steps.size()


static func _ldu_words(by: Vector3) -> String:
	var words := PackedStringArray()
	for n: int in 3:
		words.append(String.num(snappedf(by[n], 0.001), 3))
	return ", ".join(words)


## Why the last move of the selection was refused when a joint locked held it
## (jointlock: Motions.locks): its words, which joint and how to unlock it,
## for whoever asked to say. "" when no lock refused it.
var refused_lock: String = ""


## Whether moving [param placed] (brick id -> where it goes) would turn or
## slide a joint locked; [member refused_lock] says which.
func _lock_refuses(placed: Dictionary) -> bool:
	refused_lock = ""
	if world.motions == null or world.motions.locks.is_empty():
		return false
	var lock: Motions.Lock = world.motions.lock_broken(placed, world, self)
	if lock == null:
		return false
	refused_lock = Motions.lock_words(lock, world, library, self)
	return true


## [method _lock_refuses] for [param ids] each moved by [param to]. Only a
## lock's own parts are placed: a lock asks of its two parts, so Select all
## on Orthanc moved asks of two, not of 10,101.
func _lock_refuses_ids(ids: PackedInt64Array, to: Callable) -> bool:
	refused_lock = ""
	if world.motions == null or world.motions.locks.is_empty():
		return false
	var ours: Dictionary = _lock_ids()
	var placed: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id) if ours.has(brick_id) else null
		if brick != null:
			placed[brick_id] = to.call(brick.transform)
	return _lock_refuses(placed)


## The parts of the joints locked, as they are now: brick id -> true.
func _lock_ids() -> Dictionary:
	var out: Dictionary = {}
	for lock: Motions.Lock in world.motions.locks:
		for side: Motions.Joint in [lock.a, lock.b]:
			var id: int = Motions.lock_part(side, world, self)
			if id != 0:
				out[id] = true
	return out


## Where the drag would put the parts of the joints locked, moved by
## [param by]: [method drag_places] cut to them.
func _lock_places(by: Transform3D) -> Dictionary:
	var out: Dictionary = {}
	var was: Dictionary = _dragged.get("was", {})
	for id: int in _lock_ids():
		if was.has(id):
			out[id] = _dragged_to(by, was[id])
	return out


## The most parts a selection may have for Properties to show its Hinge.
const HINGED_MOST := 60


## What a swing of the selection would turn ([method swing_selection]):
## its parts on show and, at a step, the later parts that go with them; empty
## for none, or for more than [constant HINGED_MOST]. The Hinge and the
## handles' rings ask its joint. Asked of the parts on show alone, a click
## at step 40 of 10030 on its biggest sub-assembly (31 of 2,927 on) read
## the joints of those 31 against the rest, its 2,896 later parts among
## them: a joint no swing turns, and 50 ms of the click (stepfast).
func _swinging() -> PackedInt64Array:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty() or alive.size() > HINGED_MOST:
		return PackedInt64Array()
	var moving: PackedInt64Array = _moving_of(alive)
	return moving if moving.size() <= HINGED_MOST else PackedInt64Array()


## How far the selection stands turned about the joint it hangs from, in
## degrees off square, -45 to 45; null when it hangs from none
## ([method _joint_of]). What the properties' Hinge shows and types over.
func hinge_angle() -> Variant:
	var alive: PackedInt64Array = _swinging()
	# What swings on a hinge is a handful of parts; asked of everything
	# selected, the joints of a whole big model would be read at Ctrl-A.
	if alive.is_empty():
		return null
	var joint: Dictionary = _joint_of(alive)
	if joint.is_empty():
		return null
	var axis: Vector3 = (joint["axis"] as Vector3).normalized()
	var basis: Basis = world.get_brick(alive[0]).transform.basis.orthonormalized()
	var off: Basis = basis * BrickLattice.snap_basis(basis).inverse()
	var across: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT)
	return rad_to_deg(across.signed_angle_to(off * across, axis))


## Turn the selection a quarter at a time about the stud nearest its
## middle, where it stands, or refuse and change nothing.
##
## About a stud, so that every stud of every part lands on another stud.
## Nothing could turn a part once it was down: the only way to face a
## finished window the other way was to take it apart and build it again.
func turn_selection(quarter_turns: int) -> int:
	var alive: PackedInt64Array = _moving_selection()
	if alive.is_empty() or posmod(quarter_turns, 4) == 0:
		return 0
	var bricks: Array = []
	for brick_id: int in alive:
		bricks.append(world.get_brick(brick_id))
	# The same point again for a selection turned again, so four turns
	# bring it back exactly where it was: the middle of a turned box can
	# round to a different stud than the middle of the box before it.
	var pivot: Vector3 = Carry.pivot_of(bricks, library)
	if posmod(quarter_turns, 4) == 2:
		# Half round, as a mirror both ways: any point on a half stud each
		# way takes studs onto studs, so the middle, and it lands on its own
		# footprint. A quarter's stud centre or corner can be half a stud
		# off it, and put the selection a stud over (mirror_selection).
		var middle: Vector3 = _bounds_of(alive, Transform3D.IDENTITY).get_center()
		pivot = Vector3(snappedf(middle.x, BrickLattice.STUD * 0.5), pivot.y,
			snappedf(middle.z, BrickLattice.STUD * 0.5))
	if _turned_last == _turn_state(alive):
		pivot = _turned_about
	var around: Transform3D = Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(Vector3.UP, quarter_turns * PI * 0.5), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var turned: int = _reposition(func(at: Transform3D) -> Transform3D:
		return _tidy(around * at, BrickLattice.is_square_to_grid(at.basis)),
		"turned %s" % _many(alive.size()))
	# Kept only where a quarter turn could go round it too: a stud centre or
	# corner both ways.
	if turned > 0 and is_zero_approx(fposmod(pivot.x - pivot.z, BrickLattice.STUD)):
		_turned_about = pivot
		_turned_last = _turn_state(alive)
	elif turned > 0:
		_turned_last = ""
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
	var alive: PackedInt64Array = _moving_selection()
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
	# The turn is square already; each part keeps its own turn as its file
	# rounded it, turned with the rest ([method _dragged_to]).
	var turned: int = _reposition(func(at: Transform3D) -> Transform3D:
		var to: Transform3D = around * at
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
	var alive: PackedInt64Array = _moving_selection()
	if alive.is_empty():
		return 0
	var middle: Vector3 = _bounds_of(alive, Transform3D.IDENTITY).get_center()
	var around: Transform3D = Transform3D(Basis.IDENTITY, middle) \
		* Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -middle)
	return _reposition(func(at: Transform3D) -> Transform3D:
		var to: Transform3D = around * at
		return _tidy(to, BrickLattice.is_square_to_grid(to.basis)),
		words if not words.is_empty() else "turned %s" % _many(alive.size()))


## Tip the selection a quarter over, about a level axis through its middle
## (``axis`` is x or z), keeping its bottom where it was. Studio's up and
## down arrows; T here. One step; refused, changing nothing, where it would
## run into something.
func tip_selection(axis: Vector3, quarters: int) -> int:
	var alive: PackedInt64Array = _moving_selection()
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


# -- handles: the selection turned or slid by a drag (Handles) ----------------


## What a handle's drag holds while the button is down: each part's place
## and cover as it began ({was, covers}), to put back exactly when it ends
## with no move. Empty when nothing is dragged.
var _dragged: Dictionary = {}


## A handle's drag begun on the selection (Handles, docs/APP_UX.md B3): its
## parts taken out of the lattice, so each place the drag asks about is
## weighed against the rest of the model alone. Nothing else changes until
## [method drag_end]: the parts, the history and the revision stay as they
## were, and the drag is drawn by BrickWorld.set_drawn. How many parts it
## holds; 0 when nothing selected is there to move.
func drag_begin() -> int:
	drag_end(Transform3D.IDENTITY)
	refused_lock = ""
	var alive: PackedInt64Array = _moving_selection()
	if alive.is_empty():
		return 0
	var was: Dictionary = {}
	var covers: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		covers[brick_id] = lattice.cover_of(brick_id)
		lattice.release(brick_id)
	_dragged = {"was": was, "covers": covers}
	return alive.size()


func is_dragging() -> bool:
	return not _dragged.is_empty()


## Where each part of the drag stands moved by [param by], a move in the
## model's frame: brick id -> Transform3D.
func drag_places(by: Transform3D) -> Dictionary:
	var out: Dictionary = {}
	var was: Dictionary = _dragged.get("was", {})
	for brick_id: int in was:
		out[brick_id] = _dragged_to(by, was[brick_id])
	return out


## The move made square, not the part: a part keeps the turn its file
## rounded (10030's 0.951/0.308) turned with the rest. Each part made square
## moved each of a copy's parts by its own turn, so no line of the copy
## could say the move (SourceFile._common_move) and each part's line was
## rewritten in every copy of its sub-model (exactsave).
func _dragged_to(by: Transform3D, was: Transform3D) -> Transform3D:
	var to: Transform3D = Transform3D(by.basis.orthonormalized(), by.origin) * was
	return _tidy(to, BrickLattice.is_square_to_grid(to.basis))


## Whether every part of the drag has room moved by [param by]: each by
## the rule a part put down has it ([method room_for]: nothing in its way
## but what it joins as real parts join), none below the ground. What was
## in the way is in [member refused_by].
func drag_fits(by: Transform3D) -> bool:
	return drag_room(by) >= 0


## [method drag_fits] a piece at a time, so a big selection's test can be
## spread over frames: the parts checked in order from the [param from]th
## until the clock (Time.get_ticks_usec) passes [param until], 0 for no end,
## at least one a call. How many are clear so far, all of them when every
## one fits; -1 at the first with no room.
func drag_room(by: Transform3D, from: int = 0, until: int = 0) -> int:
	refused_by = PackedInt64Array()
	# A joint locked that the drag would turn or slide (jointlock), asked once
	# at its first piece: [member refused_lock] says which.
	if from == 0:
		refused_lock = ""
		if world.motions != null and not world.motions.locks.is_empty() and _lock_refuses(_lock_places(by)):
			return -1
	var was: Dictionary = _dragged.get("was", {})
	var ids: Array = was.keys()
	var n: int = from
	while n < ids.size():
		if until != 0 and n > from and Time.get_ticks_usec() >= until:
			return n
		var brick: BrickWorld.Brick = world.get_brick(ids[n])
		var to: Transform3D = _dragged_to(by, was[ids[n]])
		if brick != null and not _clear_round(brick.part_id, to) \
				and not room_for(brick.part_id, to, true):
			if room_blocker != 0:
				refused_by = PackedInt64Array([room_blocker])
			return -1
		n += 1
	return n


## Whether nothing of the model, nor the ground, is within a cell of the
## box round [param part_id]'s cover at [param at]: room there for certain,
## its cover not worked out. A turned part's is worked out cell by cell
## (5 to 10 ms for a tyre) and kept for each angle, and a drag asks at a new
## angle every 5°. False says only that [method room_for] must decide.
func _clear_round(part_id: String, at: Transform3D) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	var whole: AABB = part.bounds
	for box: AABB in part.boxes:
		whole = whole.merge(box)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for n: int in 8:
		var corner: Vector3 = at * whole.get_endpoint(n)
		lo = lo.min(corner)
		hi = hi.max(corner)
	var from: Vector3i = BrickLattice.to_cell(lo) - Vector3i.ONE
	var to: Vector3i = BrickLattice.to_cell(hi) + Vector3i(2, 2, 2)
	if from.y < GROUND_CELL:
		return false
	return lattice.blockers_boxes(PackedInt32Array([from.x, from.y, from.z, to.x, to.y, to.z])) \
		.is_empty()


## The drag let go: the parts moved by [param by] as one step to undo,
## [param words] its name in the history, and back in the lattice there. No
## move, or no room there any longer (another hand built in the way
## meanwhile), puts every cover back as it was. How many moved.
func drag_end(by: Transform3D, words: String = "") -> int:
	if _dragged.is_empty():
		return 0
	var was: Dictionary = _dragged["was"]
	var covers: Dictionary = _dragged["covers"]
	var places: Dictionary = {}
	var moves: bool = not by.is_equal_approx(Transform3D.IDENTITY) and drag_fits(by)
	if moves:
		places = drag_places(by)
	_dragged = {}
	if not moves:
		for brick_id: int in was:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick == null:
				continue
			if not (covers[brick_id][0] as PackedInt32Array).is_empty():
				lattice.occupy_moved(brick_id, covers[brick_id], Vector3i.ZERO)
			else:
				lattice.occupy_boxes(brick_id, boxes_for(library.mesh_for(brick.part_id),
					was[brick_id]))
		return 0
	var steps: Array = []
	for brick_id: int in places:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		steps.append({"undo": "move", "brick": brick_id, "transform": was[brick_id]})
		world.move_brick(brick_id, places[brick_id])
		lattice.occupy_boxes(brick_id, boxes_for(library.mesh_for(brick.part_id),
			places[brick_id]))
	record(steps, words if not words.is_empty() else "moved %s" % _many(steps.size()))
	_turned_last = ""
	return steps.size()


## The round joint the selection hangs from ([method _joint_of]): {point,
## axis}, where a handle's rings stand by default; empty for none, or for a
## selection too big to ask ([constant HINGED_MOST]).
func hung_from() -> Dictionary:
	var alive: PackedInt64Array = _swinging()
	if alive.is_empty():
		return {}
	var joint: Dictionary = _joint_of(alive)
	if joint.is_empty():
		return {}
	return {"point": joint["point"], "axis": (joint["axis"] as Vector3).normalized()}


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
	if BrickLattice.grid_cell(to.origin) != BrickLattice.grid_cell(from.origin) + cells:
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


## The parts of the model the last move or turn of the selection refused
## for would have run into ([method _reposition]); empty when it was the
## floor, or nothing was refused. What a turn with no room shows red
## (EditVerbs.turn_by).
var refused_by := PackedInt64Array()


## Put every selected brick where ``to`` says, as one step, or none of
## them if any would go through another brick or the floor.
func _reposition(to: Callable, words: String = "", by_cells: Variant = null) -> int:
	var alive: PackedInt64Array = _moving_selection()
	if alive.is_empty():
		return 0
	# A joint locked that the move would turn or slide refuses it whole
	# (jointlock): R, T, the arrows and a typed move alike.
	refused_by = PackedInt64Array()
	if _lock_refuses_ids(alive, to):
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
	refused_by = PackedInt64Array()
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
		if blocked or lattice.collides_boxes(packed) and not _only_bands(lattice.blockers_boxes(packed)):
			blocked = true
			refused_by = _not_scenery(lattice.blockers_boxes(packed))
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
	_keep(step)
	_redo.clear()
	return steps.size()


## Whether every one of [param ids] is a rubber band's or a spring's piece
## (Bands): a part they are on moves, and they stretch after it (FlexTool).
func _only_bands(ids: PackedInt64Array) -> bool:
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or not Bands.is_piece_id(brick.part_id):
			return false
	return true


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
	_keep({"undo": "group", "steps": steps,
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
	var swapped := PackedInt64Array()
	var refused: int = _replace_from(alive, 0, part_id, into, in_place, steps, swapped)
	return _replaced(part_id, steps, swapped, refused)


## A selection of this many parts or more is asked where the part in hand
## fits on a worker ([method replace_selection_paced]).
const REPLACE_ON_A_WORKER_FROM := 600


## [method replace_selection], the same swaps, with where each part fits
## asked on a worker while the window draws: on Orthanc that asking was a
## second of one frame (replacefast). Asked of a copy of the lattice that
## changes as the swaps would ([method _replace_plan]), and the swaps then
## made here as planned. When the model changed meanwhile, all of it is
## asked again as it now is. A coroutine; its step is whoever began it's
## ([member acting] then), landed frames later.
func replace_selection_paced(part_id: String, in_place: bool = false) -> Vector2i:
	var maker: String = acting
	var alive: PackedInt64Array = _living_selection()
	var into: Lbm.PartMesh = library.mesh_for(part_id)
	if alive.is_empty() or into == null:
		return Vector2i.ZERO
	if alive.size() < REPLACE_ON_A_WORKER_FROM or OS.has_feature("nothreads"):
		return replace_selection(part_id, in_place)
	var parts := PackedStringArray()
	var places: Array[Transform3D] = []
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		parts.append(brick.part_id)
		places.append(brick.transform)
	var asked: BrickLattice = lattice.copy_for_reading()
	var model_at: Array = [world.generation(), world.revision, lattice.revision]
	var planned: Array = [null]
	var sharing := Mutex.new()
	library.begin_reading()
	var task: int = WorkerTasks.add(func() -> void:
		var made: Dictionary = _replace_plan(alive, parts, places, part_id, into, in_place, asked)
		sharing.lock()
		planned[0] = made
		sharing.unlock(), false, "ask where the part in hand fits")
	library.reading_in(task)
	while not WorkerThreadPool.is_task_completed(task):
		await Engine.get_main_loop().process_frame
	WorkerTasks.collect(task)
	library.end_reading(task)
	sharing.lock()
	var plan: Variant = planned[0]
	sharing.unlock()
	return by(maker, _land_replace.bind(alive, part_id, in_place, into, plan, model_at))


## The swaps [method replace_selection_paced] planned on a worker, made: or
## all of it asked again, the model changed since.
func _land_replace(alive: PackedInt64Array, part_id: String, in_place: bool, into: Lbm.PartMesh,
		plan: Variant, model_at: Array) -> Vector2i:
	if plan == null or model_at != [world.generation(), world.revision, lattice.revision]:
		return replace_selection(part_id, in_place)
	var decided: PackedByteArray = (plan as Dictionary)["decided"]
	var where: Dictionary = (plan as Dictionary)["where"]
	var steps: Array = []
	var swapped := PackedInt64Array()
	var refused: int = 0
	var asked_laid: bool = false
	for n: int in alive.size():
		if decided[n] == _REFUSED:
			refused += 1
		elif decided[n] == _ASK:
			var ask: Array = where[n]
			var brick: BrickWorld.Brick = world.get_brick(alive[n])
			if _joined_as_before(brick, part_id, ask[0]) \
					and _swap(brick, part_id, ask[0], ask[1], steps, swapped):
				asked_laid = true
			else:
				refused += 1
		elif decided[n] == _SWAPPED:
			var put: Array = where[n]
			# The plan asked the rest with an asked part's old one standing:
			# after one is laid, each is asked again of the lattice as it now
			# stands, which is the plan's but for those (a look, not a frame).
			if asked_laid and not has_room_swapped(world.get_brick(alive[n]), part_id, put[0], put[1]):
				refused += 1
				continue
			if not _swap(world.get_brick(alive[n]), part_id, put[0], put[1], steps, swapped):
				# Not put down after all (_swap): the plan went on as if it
				# had been, so the rest is asked as the original asks it.
				refused += 1 + _replace_from(alive, n + 1, part_id, into, in_place, steps,
					swapped)
				break
	return _replaced(part_id, steps, swapped, refused)


## What [method _replace_plan] decided of a part: the part in hand already,
## no room for it, or swapped for it.
const _SAME := 0
const _REFUSED := 1
const _SWAPPED := 2
## Runs into something, but a part of the old one's box laid where it stood:
## whether it is joined as the old one was is asked on the main thread
## ([method _joined_as_before]), which reads the shapes.
const _ASK := 3


## The swaps of [method _replace_from] for [param ids], from their parts
## ([param parts]) and places ([param places]) as they were read, asked of
## [param asked], a copy of the lattice (BrickLattice.copy_for_reading)
## changed as each swap changes the lattice: {"decided": what of each, by
## index (_SAME, _REFUSED, _SWAPPED), "where": index -> [where it goes, its
## cover]}. A swap's new part stands in [param asked] under an id of its
## own below 0, and is asked about as the new part is: as another part.
## Safe on a worker: it reads the library and the covers kept, and changes
## nothing but [param asked].
func _replace_plan(ids: PackedInt64Array, parts: PackedStringArray, places: Array[Transform3D],
		part_id: String, into: Lbm.PartMesh, in_place: bool, asked: BrickLattice) -> Dictionary:
	var decided := PackedByteArray()
	decided.resize(ids.size())
	var where: Dictionary = {}
	for n: int in ids.size():
		if parts[n] == part_id:
			decided[n] = _SAME
			continue
		var at: Transform3D = places[n] if in_place \
			else _in_place_of(places[n], library.mesh_for(parts[n]), into)
		var packed: PackedInt32Array = boxes_for(into, at)
		if asked.collides_boxes(packed, ids[n]):
			if at.is_equal_approx(places[n]) and same_box(library.mesh_for(parts[n]), into):
				decided[n] = _ASK
				where[n] = [at, packed]
			elif not at.is_equal_approx(places[n]) \
					and _meets_only_as_was(asked, ids[n], boxes_for(into, places[n])):
				# Moved to sit its own way it has no room: asked on the main
				# thread where the old part stood ([method _joined_as_before]).
				decided[n] = _ASK
				where[n] = [places[n], boxes_for(into, places[n])]
			else:
				decided[n] = _REFUSED
			continue
		asked.release(ids[n])
		asked.occupy_boxes(-(n + 1), packed)
		decided[n] = _SWAPPED
		where[n] = [at, packed]
	return {"decided": decided, "where": where}


## The swaps of [method replace_selection] for [param alive] from its
## [param start]th on, one after another as the lattice is now, into
## [param steps] and [param swapped]. Returns how many had no room.
func _replace_from(alive: PackedInt64Array, start: int, part_id: String, into: Lbm.PartMesh,
		in_place: bool, steps: Array, swapped: PackedInt64Array) -> int:
	var refused: int = 0
	for n: int in range(start, alive.size()):
		var brick_id: int = alive[n]
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.part_id == part_id:
			continue
		var at: Transform3D = brick.transform if in_place else swap_place(brick, part_id, into)
		var packed: PackedInt32Array = boxes_for(into, at)
		# Asked with the old part still standing, left out of the question:
		# one with no room stays as it was, with nothing to put back. Taken
		# out and put back each time, the 9,673 parts of Orthanc a 2 x 4 has
		# no room for were most of a replace's second (bigmodels).
		if not has_room_swapped(brick, part_id, at, packed):
			refused += 1
			continue
		if not _swap(brick, part_id, at, packed, steps, swapped):
			refused += 1
	return refused


## Whether [param part_id] at [param at], whose cover is [param packed], has
## room swapped in for [param brick] (Replace, Find and Replace, Use what I
## own): it runs into nothing, or it is the same mould laid where the old
## part stands, joined as that was ([method _joined_as_before]). Asked by
## collides_boxes alone, a part a file seats in a joint was refused for the
## part holding it: 2780 for 4459 in a beam's hole, 3815 for 3815b under the
## legs (jlfix, 2026-11-19).
func has_room_swapped(brick: BrickWorld.Brick, part_id: String, at: Transform3D,
		packed: PackedInt32Array) -> bool:
	return not lattice.collides_boxes(packed, brick.id) or _joined_as_before(brick, part_id, at)


## Whether [param part_id], of [param brick]'s box ([method same_box]: a
## print, a newer mould of the same part) and laid at [param at] exactly where
## [param brick] stands, meets nothing but what the old part meets there, as
## the file put them, and what it is joined to by the rule a part put down by
## hand is (room_for: a pin in its hole, a leg on the hips' pins, a bar in
## its clip), as the copies' follow lays a copy's part (Assemblies.
## in_the_way). The obsolete hips 3815 meet nothing; 3815b's pins reach into
## the legs they hold. Another box is not joined by the same joints as a
## rule, and what the old part met excuses nothing for it: 10179's 1 x 2
## plates made tiles would lie in what stood on their studs (swapfind
## big_room), a beam made a pin in the pin it held.
##
## Unless it is joined by them: of another box, where it makes every joint
## the old part made, laid where that stood ([method _keeps_joints]):
## 4991-1's axle with a stop 32209 made 59426, 2 LDU longer, sits in the
## holes the old one did; 6690-1's turntable top 3404 made 3404b sits on its
## base and under its parts as the old one did. Moved to sit its own way,
## each met what it is joined to (smalls12). A 1 x 6 for a 1 x 4 against a wall makes the 1 x 4's joints
## too, and runs into the wall the 1 x 4 never met: no room.
func _joined_as_before(brick: BrickWorld.Brick, part_id: String, at: Transform3D) -> bool:
	if brick == null or not at.is_equal_approx(brick.transform):
		return false
	if not same_box(library.mesh_for(brick.part_id), library.mesh_for(part_id)) \
			and not _keeps_joints(brick, library.mesh_for(part_id)):
		return false
	var met: Dictionary = {}
	for other: int in lattice.blockers_boxes(lattice.boxes_of(brick.id), brick.id):
		met[other] = true
	return room_for(part_id, at, false, false, brick.id, met)


## Where a swap lays [param part_id] ([param into]'s shape) for [param brick]:
## where Replace lays a part of another box ([method _in_place_of]: its
## bottom where the old one's was, its middle on the studs), or, where that
## has no room, where the old part stood if it has room there as the old
## one was joined ([method _joined_as_before]). Main thread.
func swap_place(brick: BrickWorld.Brick, part_id: String, into: Lbm.PartMesh) -> Transform3D:
	var moved: Transform3D = _in_place_of(brick.transform, library.mesh_for(brick.part_id), into)
	if moved.is_equal_approx(brick.transform) or has_room_swapped(brick, part_id, moved, boxes_for(into, moved)):
		return moved
	var stood: PackedInt32Array = boxes_for(into, brick.transform)
	if _meets_only_as_was(lattice, brick.id, stood) and _joined_as_before(brick, part_id, brick.transform):
		return brick.transform
	return moved


## Whether [param packed], a new part laid where [param brick_id] stands in
## [param asked], meets nothing the old part does not meet there: asked
## before the joints are (a look at the lattice), so a part of another box
## that runs into anything new is refused at once. Safe on a worker.
static func _meets_only_as_was(asked: BrickLattice, brick_id: int, packed: PackedInt32Array) -> bool:
	var met: Dictionary = {}
	for other: int in asked.blockers_boxes(asked.boxes_of(brick_id), brick_id):
		met[other] = true
	for other: int in asked.blockers_boxes(packed, brick_id):
		if not met.has(other):
			return false
	return true


## Whether [param into], laid where [param brick] stands, is joined to every
## part the old part is joined to there (by a pin, an axle, a stud or
## something round in something round, as [method _joins_made] counts
## them): a part that joins nothing keeps nothing.
func _keeps_joints(brick: BrickWorld.Brick, into: Lbm.PartMesh) -> bool:
	if into == null:
		return false
	var was: Dictionary = _joined_with(brick.transform, library.mesh_for(brick.part_id), brick.id)
	if was.is_empty():
		return false
	var now: Dictionary = _joined_with(brick.transform, into, brick.id)
	for other: Variant in was:
		if not now.has(other):
			return false
	return true


## Whether [param into] has [param was]'s box, its footprint and height to an
## LDU: a printed version of the same mould, whose print can reach a hair
## past the plain part's box, or a newer mould of the same part.
static func same_box(was: Lbm.PartMesh, into: Lbm.PartMesh) -> bool:
	return was != null and into != null and was.bounds.size.distance_to(into.bounds.size) < 1.0 \
		and was.bounds.get_center().distance_to(into.bounds.get_center()) < 1.0


## [param brick] swapped for [param part_id] at [param at], whose cover is
## [param packed], into [param steps] and [param swapped]. False, and the
## brick as it was, when the new part could not be put down.
func _swap(brick: BrickWorld.Brick, part_id: String, at: Transform3D, packed: PackedInt32Array,
		steps: Array, swapped: PackedInt64Array, colour: int = -1) -> bool:
	var brick_id: int = brick.id
	lattice.release(brick_id)
	var made: int = world.add_brick(part_id, brick.color_code if colour < 0 else colour, at)
	if made == 0:
		lattice.occupy_boxes(brick_id, boxes_for(library.mesh_for(brick.part_id), brick.transform))
		return false
	world.get_brick(made).group = brick.group
	world.get_brick(made).unit = brick.unit
	world.get_brick(made).step = brick.step
	# The part another file put there, on its line still (SourceFile).
	world.get_brick(made).origin = brick.origin
	lattice.occupy_boxes(made, packed)
	steps.append({"undo": "remove", "brick": made})
	steps.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
		"transform": brick.transform, "group": brick.group, "unit": brick.unit,
		"step": brick.step, "was": brick.id})
	_carry_locks(brick, made, steps)
	world.remove_brick(brick_id)
	removed.emit(brick_id)
	swapped.append(made)
	return true


## A joint lock (Motions.Lock) of [param was] moved to [param made], the part
## swapped in where it stood, with the swap's own undo after it (a group's
## steps are undone in order: the old part is back before its lock is). A
## joint locked stays locked through Find and Replace, Use what I own and a
## rare colour's swap; the lock named a part that was gone, held nothing and
## left the file at the next save, with nothing said.
func _carry_locks(was: BrickWorld.Brick, made: int, steps: Array) -> void:
	var motions: Motions = world.motions
	if motions == null or motions.locks.is_empty():
		return
	var had: Motions = null
	for lock: Motions.Lock in motions.locks:
		for joint: Motions.Joint in [lock.a, lock.b]:
			if Motions.lock_part(joint, world, self) != was.id:
				continue
			if had == null:
				had = motions.copy()
			joint.lead = made
			joint.part = world.get_brick(made).part_id
	if had != null:
		steps.append({"undo": "motions", "motions": had})


## Find and Replace's change (FindReplace), any parts anywhere in the model,
## in every sub-model: each of [param changes], {"brick", "part", "color",
## "at"}, swapped for its part in its colour at its place ([method _swap]),
## or painted where its part is the one it is. One step, called [param words],
## that after_edit makes every other copy follow as it does a hand's. One
## with no room for its new part stays as it was. Returns [how many changed,
## how many had no room], those changed selected.
func replace_bricks(changes: Array, words: String) -> Vector2i:
	var steps: Array = []
	var changed := PackedInt64Array()
	var refused: int = 0
	for change: Dictionary in changes:
		var brick: BrickWorld.Brick = world.get_brick(int(change["brick"]))
		if brick == null:
			continue
		var part: String = change["part"]
		var colour: int = int(change["color"])
		if part == brick.part_id:
			if colour != brick.color_code:
				steps.append({"undo": "recolor", "brick": brick.id, "color": brick.color_code})
				world.recolor_brick(brick.id, colour)
				changed.append(brick.id)
			continue
		var into: Lbm.PartMesh = library.mesh_for(part)
		var at: Transform3D = change["at"]
		var packed: PackedInt32Array = boxes_for(into, at) if into != null else PackedInt32Array()
		if into == null or not has_room_swapped(brick, part, at, packed) \
				or not _swap(brick, part, at, packed, steps, changed, colour):
			refused += 1
	if steps.is_empty():
		return Vector2i(0, refused)
	_keep({"undo": "group", "steps": steps, "words": words})
	_redo.clear()
	_select_changed(changed)
	return Vector2i(changed.size(), refused)


## The parts an edit just changed selected, those on show at the step the
## timeline shows, the rest held with them ([method hold_unseen]): a
## session's replace_parts with all_steps left the person's selection
## holding two later parts, and the line said "2 selected" of nothing on
## show (stepreview F7).
func _select_changed(changed: PackedInt64Array) -> void:
	selection.clear()
	_let_go.clear()
	for brick_id: int in changed:
		if not lattice.ahead.has(brick_id):
			selection[brick_id] = true
	selection_changed.emit(selection.size())
	hold_unseen(changed)


## A replace's swaps kept as one step, and selected: [how many, how many
## had no room].
func _replaced(part_id: String, steps: Array, swapped: PackedInt64Array,
		refused: int) -> Vector2i:
	if steps.is_empty():
		return Vector2i(0, refused)
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	_keep({"undo": "group", "steps": steps, "words": "swapped %s for %s" % [
		_many(swapped.size()), Inventory._tidy(info.name) if info != null else part_id]})
	_redo.clear()
	_select_changed(swapped)
	return Vector2i(swapped.size(), refused)


## The selection made into its mirror image, in place, across the plane
## through its middle square to world axis ``axis`` (0 for x, 2 for z).
## Handed parts are swapped for their other hand (Mirror.counterpart).
## All or nothing, one step. Returns how many, or zero when it would run
## into something.
func mirror_selection(axis: int) -> int:
	var made: PackedInt64Array = mirror_bricks(_moving_selection(), axis)
	if made.is_empty():
		return 0
	selection.clear()
	for brick_id: int in made:
		selection[brick_id] = true
	selection_changed.emit(selection.size())
	return made.size()


## The parts the last mirror made that are no mirror image of what they were
## made from: a part made in one hand only and the same no way round, turned
## as near its reflection as it goes (Mirror.image). The person is told
## which; empty when every part is its reflection.
var no_image := PackedInt64Array()


## [method mirror_selection] on the bricks [param alive], across the plane at
## [param across] LDU when it is given (on a half stud), and with [param copy]
## a mirrored copy put down and the bricks left where they are: a session's
## mirror_parts (HandTools). The new bricks, or none.
func mirror_bricks(alive: PackedInt64Array, axis: int, across: float = NAN,
		copy: bool = false) -> PackedInt64Array:
	no_image = PackedInt64Array()
	if alive.is_empty():
		return PackedInt64Array()
	var bricks: Array = []
	for brick_id: int in alive:
		bricks.append(world.get_brick(brick_id))
	# The plane through the selection's middle on that axis, on a half stud:
	# any such plane takes the studs onto studs. Not the point a turn goes
	# round (Carry.pivot_of), a stud centre or corner both ways, which the
	# other axis can decide: Orthanc's first step, x 380 to 440, was
	# reflected across x = 420 for its z, a stud over from where it stood
	# and onto the bricks beside it (2026-10-19).
	if is_nan(across):
		across = snappedf(_bounds_of(alive, Transform3D.IDENTITY).get_center()[axis],
			BrickLattice.STUD * 0.5)
	var plan: Array = []
	for brick: BrickWorld.Brick in bricks:
		var image: Dictionary = Later.script(&"Mirror").image(library, brick.part_id,
			brick.transform, axis, across, true)
		plan.append({"brick": brick, "part": str(image["part"]), "exact": bool(image["exact"]),
			"at": _tidy(image["at"], BrickLattice.is_square_to_grid(brick.transform.basis))})
	var picked: Dictionary = {}
	for brick_id: int in alive:
		picked[brick_id] = true
	if not copy:
		for brick_id: int in alive:
			lattice.release(brick_id)
	var blocked: bool = false
	for item: Dictionary in plan:
		var packed: PackedInt32Array = boxes_for(library.mesh_for(str(item["part"])), item["at"])
		item["boxes"] = packed
		if lattice.collides_boxes(packed) and not _meets_as_before(item["brick"], packed, picked):
			blocked = true
			break
	if blocked:
		if not copy:
			for brick: BrickWorld.Brick in bricks:
				lattice.occupy_boxes(brick.id, boxes_for(library.mesh_for(brick.part_id),
					brick.transform))
		return PackedInt64Array()
	var steps: Array = []
	var made := PackedInt64Array()
	if not copy:
		for item: Dictionary in plan:
			var brick: BrickWorld.Brick = item["brick"]
			steps.append({"undo": "add", "part": brick.part_id, "color": brick.color_code,
				"transform": brick.transform, "group": brick.group, "unit": brick.unit,
				"step": brick.step, "was": brick.id})
			world.remove_brick(brick.id)
			selection.erase(brick.id)
			removed.emit(brick.id)
	for item: Dictionary in plan:
		var brick: BrickWorld.Brick = item["brick"]
		var new_id: int = world.add_brick(str(item["part"]), brick.color_code, item["at"])
		if new_id == 0:
			continue
		# A mirrored copy is no copy of a sub-assembly, whose copies follow
		# each other (Assemblies): it goes in none.
		world.get_brick(new_id).group = "" if copy else brick.group
		world.get_brick(new_id).unit = "" if copy else brick.unit
		world.get_brick(new_id).step = brick.step
		world.get_brick(new_id).origin = "" if copy else brick.origin
		lattice.occupy_boxes(new_id, item["boxes"])
		steps.push_front({"undo": "remove", "brick": new_id})
		made.append(new_id)
		item["made"] = new_id
		if not bool(item["exact"]):
			no_image.append(new_id)
	var flip := Basis.IDENTITY
	flip[axis] = -flip[axis]
	var reflect := Transform3D(flip, Vector3.ZERO)
	reflect.origin[axis] = 2.0 * across
	# And where each part a file placed has its line, mirrored with it
	# (BrickWorld.kept_lines' "read_as"), so a copy mirrored whole is read in
	# the mirror image of its frame (Assemblies._read_vote), its section as
	# the file had it. Left as the open put it, a mirrored copy mirrored back
	# read no one frame, and its section went out in the window's.
	if not copy:
		var lined: Dictionary = _lines_mirrored(plan, reflect)
		if not lined.is_empty():
			steps.append({"undo": "keptlines", "lines": world.kept_lines})
			var kept: Dictionary = world.kept_lines.duplicate()
			kept["read_as"] = lined
			world.kept_lines = kept
	_keep({"undo": "group", "steps": steps,
		"words": ("mirrored a copy of %s" if copy else "mirrored %s") % _many(made.size())})
	_redo.clear()
	# Each copy mirrored whole is its mirror image, and so is the frame its
	# sub-model's lines are in: its lights and views go mirrored with it
	# (Assemblies.frames_carried). Up to 2026-11-11 its light was found again
	# from its parts and left where no reflection put it (pccheck FX).
	if not copy and not world.section_frames.is_empty():
		var moved: Dictionary = {}
		for brick_id: int in made:
			moved[brick_id] = reflect
		Assemblies.frames_carried(self, moved)
	return made


## [BrickWorld.kept_lines]' "read_as" (ModelStore._as_placed) with each
## part of [param plan] a file placed (its origin) mirrored by [param
## reflect]: the turn from the part put down to where its line puts it, that
## place mirrored, so a part put down otherwise than its line (a mirrored
## copy's reflection) or as it (a plain copy's) is read where the mirror
## takes its line. {} where no part of it has a line. One whose line is no
## one's now (Assemblies.line_of: swapped since) stays so, named for no part:
## taken for a line where it stands, a swapped part of a mirrored copy said
## the reflection of its copy's frame once mirrored back; and kept as it
## was, the mirror of a handed part swapped for its other hand put down the
## part the record names again, and the record held for it.
func _lines_mirrored(plan: Array, reflect: Transform3D) -> Dictionary:
	var read_as: Dictionary = world.kept_lines.get("read_as", {})
	var out: Dictionary = read_as.duplicate()
	var changed: bool = false
	for item: Dictionary in plan:
		var brick: BrickWorld.Brick = item["brick"]
		var made: BrickWorld.Brick = world.get_brick(int(item.get("made", 0)))
		if made == null or brick.origin.is_empty():
			continue
		var turn := Transform3D.IDENTITY
		var named: String = brick.part_id
		if read_as.has(brick.origin):
			var line: Array = Assemblies.line_of(read_as, brick.origin, brick.part_id)
			if line.is_empty():
				out[brick.origin] = ["", Transform3D.IDENTITY, ""]
				changed = true
				continue
			turn = line[0]
			named = str(line[1])
		out[brick.origin] = [made.part_id,
			made.transform.affine_inverse() * reflect * brick.transform * turn, named]
		changed = true
	return out if changed else {}


## Whether [param packed], where [param brick]'s mirror image goes, runs
## into nothing but what [param brick] runs into where it stands, of the
## parts not [param picked]: a wheel on its axle holder, as a file lays it,
## mirrored onto the holder too. Nothing new runs into anything. Shift+M
## refused the car's left half for its wheels (mcphand, 2026-10-31).
func _meets_as_before(brick: BrickWorld.Brick, packed: PackedInt32Array,
		picked: Dictionary) -> bool:
	var before: Dictionary = {}
	for other: int in lattice.blockers_boxes(boxes_for(library.mesh_for(brick.part_id),
			brick.transform), brick.id, picked):
		before[other] = true
	if before.is_empty():
		return false
	for other: int in lattice.blockers_boxes(packed):
		if not before.has(other):
			return false
	return true


## The sub-assembly a part put down goes into: the one being edited
## (Assemblies.entered), "" for the model.
var place_group: String = ""
## Why another copy of the sub-assembly being edited has no room for what
## goes down into it ({"items": [part id, where] each}, kept and handed back
## till answered), asked for no longer than the second argument in
## microseconds: "" when every copy has, null when not done yet
## (Assemblies.room_in_copies). Unset, none is asked.
var copies_room: Callable = Callable()
## Why the ghost is red though nothing in the copy being edited is in its
## way: another copy of it has no room for the twin a click would lay there,
## and the click's part would be taken straight back ([method _ask_copies]).
## "" otherwise.
var copies_refuse: String = ""
## [member copies_refuse], said as the ghost turns red for it.
signal copies_refused(words: String)
## How long an aim asks the copies, in microseconds: a hand of many parts
## put down into an assembly with several copies is asked by the click.
const COPIES_ASK_US := 4000
var _copies_asked: Array = []
var _copies_hand: Variant = null
## The ask not answered yet (Assemblies.room_in_copies keeps its place in it).
var _copies_ask: Dictionary = {}
## Whether the part's ghost was last drawn red for the copies.
var _drawn_red: bool = false
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
## Returns how many moved.
##
## What the model keeps by an assembly's path goes where the change puts the
## assembly, in the same step, so undo and redo carry it too: each copy's
## step (BrickWorld.unit_steps), a section broken out (broken_out) and a
## motion's joint on a sub-assembly (Motions). [param carry] says where:
## (path) -> the paths the assembly is at after the change, none when the
## change took it apart, two when it split it. Unset, no assembly moves:
## parts taken out of one. Left under the old names, the castle's renamed
## tower lost the entry that built it in the castle's steps, and its parts
## moved steps (unitsteps). [param numbers] are steps the change gives,
## {"bricks": id -> step, "units": path before the change -> step, -1 for
## none, "held": [[a part the model does not show (BrickWorld.held), its
## step]]}: a copy's steps made its parent's as it is taken apart
## (AuthorSteps.inlined), a sub-assembly made built in its parent's. What it
## put in a section other than the one it was stepped in, and numbers none
## of, is numbered in the one it is in now (AuthorSteps.rehomed), each step's
## look with its parts (BookletLooks.follow).
func regroup(changes: Dictionary, words: String, carry: Callable = Callable(),
		numbers: Dictionary = {}) -> int:
	var units: Dictionary = world.unit_steps.duplicate()
	var looked: Dictionary = BookletLooks.items_by_step(world, scenery)
	var was: Dictionary = {}
	var steps: Array = []
	for brick_id: int in changes:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var path: String = str(changes[brick_id])
		if brick == null or Assemblies.path_of(brick) == path:
			continue
		steps.append({"undo": "regroup", "brick": brick_id, "group": brick.group,
			"unit": brick.unit})
		was[brick_id] = Assemblies.path_of(brick)
		set_path(brick, path)
	var moved: int = steps.size()
	if moved == 0:
		return 0
	if carry.is_valid():
		steps.append_array(_carry(carry))
	var stepped: Dictionary = numbers.get("bricks", {})
	var kept: Dictionary = {}       ## a part whose step an entry here puts back
	for brick_id: int in stepped:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and brick.step != int(stepped[brick_id]):
			steps.append({"undo": "restep", "brick": brick_id, "step": brick.step})
			kept[brick_id] = true
			brick.step = int(stepped[brick_id])
	var given: Dictionary = numbers.get("units", {})
	for path: String in given:
		for to: String in (carry.call(path) if carry.is_valid() else [path]):
			if int(given[path]) == -1:
				world.unit_steps.erase(to)
			else:
				world.unit_steps[to] = int(given[path])
	# What the model holds and does not show, in the steps given with the rest.
	var kept_held: Dictionary = {}
	for pair: Array in numbers.get("held", []):
		var placement: LdrModel.Placement = pair[0]
		if placement.step != int(pair[1]):
			steps.append({"undo": "heldstep", "held": placement, "step": placement.step})
			kept_held[placement.get_instance_id()] = true
			placement.step = int(pair[1])
	# Each part's step once, as it was before all of it, as the copies' below.
	var rehomed: Array = AuthorSteps.rehomed(world, was, units, carry, numbers, scenery)
	steps.append_array(rehomed.filter(func(entry: Dictionary) -> bool:
		if str(entry["undo"]) == "heldstep":
			return not kept_held.has((entry["held"] as Object).get_instance_id())
		return str(entry["undo"]) == "restep" and not kept.has(int(entry["brick"]))))
	if not rehomed.is_empty():
		steps.append_array(BookletLooks.follow(world, looked, scenery))
	# Each copy's step once, as it was before all of it: a group's entries
	# are applied in the order kept, so one an entry carried and another
	# numbered would be put back to the step between.
	for path: String in units:
		if int(world.unit_steps.get(path, -1)) != int(units[path]) or not world.unit_steps.has(path):
			steps.append({"undo": "unitstep", "unit": path, "step": int(units[path]),
				"kept": true})
	for path: String in world.unit_steps:
		if not units.has(path):
			steps.append({"undo": "unitstep", "unit": path, "step": -1})
	_keep({"undo": "group", "steps": steps, "words": words})
	_redo.clear()
	return moved


## [method regroup]'s tables carried where [param carry] puts each path.
## Returns the undo of the sections and motions; the copies' steps are
## undone by regroup, each once.
func _carry(carry: Callable) -> Array:
	var undo: Array = []
	# A copy given the path an entry still holds (one taken off, kept for
	# its undo) takes the place of that entry: the copies moved are put
	# after the rest.
	var going: Dictionary = {}
	for path: String in world.unit_steps:
		var to: Array = carry.call(path)
		if to.size() != 1 or str(to[0]) != path:
			going[path] = to
	var held: Dictionary = {}
	for path: String in going:
		held[path] = world.unit_steps[path]
		world.unit_steps.erase(path)
	for path: String in going:
		for to: String in going[path]:
			world.unit_steps[to] = held[path]
	# A section broken out goes to the one path its parts went to. One taken
	# apart or split keeps its own: its record names its parts by number
	# (BrickWorld.home_of), so a save still writes them where they were.
	for section: String in world.broken_out.keys():
		var to: Array = carry.call(section)
		if to.size() == 1 and str(to[0]) != section:
			undo.append({"undo": "sectionout", "path": section, "record": world.broken_out[section]})
			undo.append({"undo": "sectionout", "path": str(to[0]),
				"record": world.broken_out.get(str(to[0]))})
			world.broken_out[str(to[0])] = world.broken_out[section]
			world.broken_out.erase(section)
	# A motion's joint on a sub-assembly, found again by its path.
	if world.motions != null:
		var had: Motions = null
		for joint: Motions.Joint in world.motions.joints:
			if joint.by != "assembly":
				continue
			var to: Array = carry.call(joint.assembly)
			if to.size() == 1 and str(to[0]) != joint.assembly:
				if had == null:
					had = world.motions.copy()
				joint.assembly = str(to[0])
		if had != null:
			undo.append({"undo": "motions", "motions": had})
	# Which copy of someone else's file each path is (SourceFile), where the
	# change takes it: one split is that copy in both places.
	if not world.unit_chains.is_empty():
		var chains: Dictionary = {}
		for path: String in world.unit_chains:
			for to: String in carry.call(path):
				if not chains.has(to) or to == path:
					chains[to] = world.unit_chains[path]
		if chains != world.unit_chains:
			undo.append({"undo": "unitchains", "chains": world.unit_chains})
			world.unit_chains = chains
	# Where the frame each copy's sub-model lines are in stands
	# (BrickWorld.section_frames, by its path): with the copy, renamed, made
	# part of another or split; none for one taken apart, whose lines its
	# take-apart places (Assemblies.ungroup).
	if not world.section_frames.is_empty():
		var frames: Dictionary = {}
		for path: String in world.section_frames:
			for to: String in carry.call(path):
				if not frames.has(to) or to == path:
					frames[to] = world.section_frames[path]
		if frames != world.section_frames:
			undo.append({"undo": "sectionlines", "lines": world.section_lines,
				"frames": world.section_frames})
			world.section_frames = frames
	# Where each part on its way, or one the catalogue lacks, is in the tree
	# (BrickWorld.held_paths): with the copy round it, so it lands in it, and
	# a save writes it in it, under the name it has now (Assemblies.carried).
	if not world.held_paths.is_empty():
		var paths: Dictionary = {}
		for open: String in world.held_paths:
			paths[open] = Assemblies.carried(carry, str(world.held_paths[open]))
		if paths != world.held_paths:
			undo.append({"undo": "heldpaths", "paths": world.held_paths})
			world.held_paths = paths
	return undo


## The newest step of the history, or nothing.
func last_step() -> Dictionary:
	return _history.back() if not _history.is_empty() else {}


## The newest step taken back as though it had never been made: an edit
## that some copy of a sub-model could not take (Assemblies.after_edit). It
## leaves nothing to redo; [param redo], the redo the edit cleared, is put
## back. The parts it took off come back, selected when nothing else is: a
## Delete's, a Replace's old ones.
func take_back(redo: Array = []) -> void:
	if _history.is_empty():
		return
	var back: Dictionary = _apply(_history.pop_back())
	if _redo.is_empty():
		_redo.assign(redo)
	settled = _history.back() if not _history.is_empty() else {}
	var put_back: Dictionary = {}
	_moved_by(back, put_back)
	_living_selection()
	if not selection.is_empty():
		return
	for brick_id: int in put_back:
		if world.get_brick(brick_id) != null and not scenery.has(brick_id):
			selection[brick_id] = true
	if not selection.is_empty():
		selection_changed.emit(selection.size())


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
		_keep({"undo": "group", "steps": steps})
		return
	var last: Dictionary = _history.back()
	# Said as what the person did, before what followed from it is folded
	# in: a hand Delete that emptied a step with a look (a group of one
	# "add") took its look in a "steplooks" after it, and its undo said
	# "changed 2 parts" where it had said "removed 1 part" (pkreview).
	if last.get("undo", "") != "group":
		var words: String = _words_for(last)
		var group: Dictionary = {"undo": "group", "steps": [last], "words": words}
		# What follows from a step is its maker's, as the step is.
		carry_whose(last, group)
		last = group
		_history[_history.size() - 1] = last
	elif not last.has("words"):
		last["words"] = _words_for(last)
	# Before what they followed, as a group's steps are kept, newest first
	# ([method fold_since]): an undo takes them back first. After it, the
	# rename's undo named its parts back to Tower#2, and the other copy built
	# again from Turret#1 was then put back as Turret#2 over it (copyfaults).
	last["steps"] = steps + (last["steps"] as Array)


## Everything [param by] kept since the history was [param depth] deep, as
## one step: one call of a session's tool is one undo, however many of the
## window's own commands it took (AppTools), and so is a person's drag. The
## newest first, as they are undone. Only [param by]'s own: a step of
## someone else's kept meanwhile stays where it was kept, a step of its own,
## and the steps on each side of it are folded each side. The history stays
## in the order things were done: a chat's paint lifted over the person's
## paint of the same brick was undone by the chat with the person's red, and
## the person's Undo then brought back the chat's yellow (savereview3 F2).
## [param by] null: whoever is [member acting] now.
func fold_since(depth: int, words: String = "", by: Variant = null) -> void:
	var from: int = maxi(depth, 0)
	if _history.size() <= from + 1:
		return
	var who: String = acting if by == null else str(by)
	var since: Array[Dictionary] = _history.slice(from)
	_history.resize(from)
	var run: Array[Dictionary] = []
	for step: Dictionary in since:
		if whose(step) == who:
			run.append(step)
			continue
		_fold_run(run, words, who)
		run.clear()
		_history.append(step)
	_fold_run(run, words, who)


## [param run], steps of [param by]'s kept one after another, kept as one
## step, newest: one step alone as it is.
func _fold_run(run: Array[Dictionary], words: String, by: String) -> void:
	if run.size() == 1:
		_history.append(run[0])
	if run.size() < 2:
		return
	var steps: Array = []
	var said := PackedStringArray()
	for step: Dictionary in run:
		said.append(_words_for(step))
		steps.push_front(step)
	var group: Dictionary = {"undo": "group", "steps": steps,
		"words": words if not words.is_empty() else "; ".join(said)}
	if not by.is_empty():
		group[BY] = by
	_history.append(group)


## The newest step said as [param words]: what it did, as only its maker
## knows once it is done. Find and Replace counts the parts it changed after
## the copies followed it, and its undo said "replaced 131" where 50 had
## changed (swreview F2).
func name_newest(words: String) -> void:
	if not _history.is_empty() and not words.is_empty():
		(_history.back() as Dictionary)["words"] = words


## A brick laid again as another number is the same brick to the history:
## a baseplate taken up and put back by a change of floor (FloorLayer).
func renumber(old_id: int, new_id: int) -> void:
	if old_id != new_id:
		_renumbered[old_id] = new_id


## Keep [param steps] as one step of the history, called [param words]:
## what a tool did that the builder did not (a hose laid, a pose). Newest,
## or [param at] steps deep when it came before the steps kept since.
func record(steps: Array, words: String, at: int = -1) -> void:
	if steps.is_empty():
		return
	_keep({"undo": "group", "steps": steps, "words": words}, at)
	_redo.clear()


## Keep [param step] in the history, newest or [param at] steps deep, as
## the session [member acting]'s when one is: one key written, nothing
## walked, whatever its size (savereview3 F3: 11 ms on a 6,000-part step).
func _keep(step: Dictionary, at: int = -1) -> void:
	if not acting.is_empty() and not step.has(BY):
		step[BY] = acting
	if at < 0 or at >= _history.size():
		_history.append(step)
	else:
		_history.insert(at, step)


## [param act] run, the steps it keeps kept as the session [param actor]'s
## ([constant BY]), "" the person's, and what it changes with no step noted
## as theirs ([method naming]); what it returns. [param act] runs to its end
## without waiting: one that waits goes through [method by_wait].
static func by(actor: String, act: Callable) -> Variant:
	var was: String = acting
	acting = actor
	_naming += 1
	var out: Variant = act.call()
	_naming -= 1
	acting = was
	return out


## How deep the code running now is in acts that say whose they are ([method
## by], the first stretch of [method by_wait]'s).
static var _naming: int = 0


## Whether the code running now says whose its changes are: only then is a
## change to the model with no step noted as [member acting]'s, for the step
## its run or call keeps as it ends (BrickWorld.Ledger, ClaudeStep). Code that
## says nothing changes the model as nobody's run: the person by hand,
## keeping their steps as they go, a model opened, a part whose shape came
## late. So a call's step holds only what its own code changed, never what
## changed while it was at work.
static func naming() -> bool:
	return _naming > 0


## [method by] for [param act] that may wait, awaited: `await
## Builder.by_wait(chat, func() -> Variant: return await tool())`. Its steps
## are [param actor]'s only as far as its first wait: what it keeps after one
## is the person's unless it says whose again, as a tool that lands its
## change frames later does with the session it began with
## (EditVerbs.press, replace_selection_paced). So whatever the person does
## while a session's call waits on a frame is theirs.
static func by_wait(actor: String, act: Callable) -> Variant:
	var going := _Acting.new()
	var was: String = acting
	acting = actor
	_naming += 1
	# Not awaited: it hands back at the act's first wait, and goes on.
	going.go(act)
	_naming -= 1
	acting = was
	if not going.finished:
		await going.ended
	return going.value


## An act run to its end however many frames it takes ([method by_wait]),
## as Working._Going runs a command: Godot 4 waits on a coroutine only with
## await, and taking its result without one is a script error in a debug
## build.
class _Acting extends RefCounted:
	signal ended
	var finished: bool = false
	var value: Variant = null

	func go(act: Callable) -> void:
		value = await act.call()
		finished = true
		ended.emit()


## Whose [param step] is: the session that kept it, "" the person's.
static func whose(step: Dictionary) -> String:
	return str(step.get(BY, ""))


## [param to] made whose [param from] is.
static func carry_whose(from: Dictionary, to: Dictionary) -> void:
	if from.has(BY):
		to[BY] = from[BY]
	else:
		to.erase(BY)


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
		world.get_brick(new_id).origin = str(item.get("origin", ""))
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
	_keep({"undo": "recolor", "brick": brick_id, "color": brick.color_code})
	_redo.clear()
	return world.recolor_brick(brick_id, color_code)


## Take one brick off, as one step: what Delete mode does to a brick clicked.
func remove_brick_id(brick_id: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or locked.has(brick_id):
		return false
	_keep({"undo": "add", "part": brick.part_id, "color": brick.color_code,
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
	_keep({"undo": "group", "steps": steps,
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
	var alive: PackedInt64Array = _moving_selection()
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
	if _lock_refuses_ids(alive, func(at: Transform3D) -> Transform3D: return around * at):
		return 0
	var was: Dictionary = {}
	for brick_id: int in alive:
		was[brick_id] = world.get_brick(brick_id).transform
		lattice.release(brick_id)
	var landing: Dictionary = {}
	for brick_id: int in alive:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var to: Transform3D = around * brick.transform
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
	_keep({"undo": "group", "steps": steps,
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
	# The parts near it by the lattice's buckets, not every part of the
	# model: Properties asks this at every selection (hinge_angle).
	var cells := PackedInt32Array([floori(reach.position.x / BrickLattice.CELL),
		floori(reach.position.y / BrickLattice.CELL), floori(reach.position.z / BrickLattice.CELL),
		ceili(reach.end.x / BrickLattice.CELL), ceili(reach.end.y / BrickLattice.CELL),
		ceili(reach.end.z / BrickLattice.CELL)])
	for other: int in lattice.near_bounds(cells):
		if picked.has(other):
			continue
		var brick: BrickWorld.Brick = world.get_brick(other)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
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
				# And the two parts it turns between: what a lock of it locks.
				found = {"point": zones[0][0], "axis": zones[0][1], "pair": [int(mine), int(other)]}
	if found.is_empty():
		return {}
	found["partners"] = partners
	return found


## Where a part goes to take another's place: exactly there where the two
## have one box ([method same_box]), else the same turn, its middle on the
## stud grid for its own footprint, its bottom where the other's was. Find
## and Replace kept a pin of the same box in its beam's hole; the hand's
## Replace put its middle on the stud grid, out of the hole (smalls10).
func _in_place_of(at: Transform3D, was: Lbm.PartMesh, into: Lbm.PartMesh) -> Transform3D:
	if was == null or same_box(was, into) or not BrickLattice.is_square_to_grid(at.basis) \
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


## What the last paste put down said of its sub-models' lights and views
## (Assemblies.lines_pasted): "" but where the model it went into kept its own.
var pasted_said: String = ""


## Copy the selection to the clipboard. Returns how many parts.
func copy_selection() -> int:
	var alive: PackedInt64Array = _living_selection()
	if alive.is_empty():
		return 0
	Carry.clipboard = Carry.gather(world, library, Array(alive))
	Carry.clipboard_lines = Assemblies.lines_held(world, Carry.clipboard)
	Carry.clipboard_frames = Assemblies.frames_held(world, Carry.clipboard)
	Carry.clipboard_held = held_carry.call(Carry.clipboard) if held_carry.is_valid() else []
	return Carry.clipboard.size()


## A stud across and a plate up, in LDU: where a copy beside the original
## goes (put_copy_beside).
const _STUD := 20.0
const _PLATE := 8.0


## Edit › Duplicate (ux14): a copy of the selection put down at once beside
## it, seated, and selected, as Studio's Duplicate puts its copy beside the
## original. Held in hand and put down where the pointer said, a copy of a
## sub-assembly on a car's nose landed in the air wherever the floor was
## clicked (ux13's walk, p7), and nothing seated it.
##
## Beside it is the first of: the view's right of the selection, its left,
## behind it, in front, one stud clear and then further out; at the height
## it stands at where something holds it there, else let down until it
## rests on what is under it or the floor. One step to undo. 0 when no
## place beside it has room, and nothing is put down.
## [param right]: the view's right along the model's axes.
func put_copy_beside(parts: Array, right: Vector3, lines: Dictionary = {}, frames: Dictionary = {},
		held_too: Array = []) -> int:
	if parts.is_empty():
		return 0
	var box := AABB()
	var first: bool = true
	for item: Dictionary in parts:
		var part: Lbm.PartMesh = library.mesh_for(str(item["part"]))
		if part == null:
			continue
		var at: Transform3D = item["was"] if item.get("was") is Transform3D else Transform3D.IDENTITY
		var here: AABB = (at * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	if first:
		return 0
	cancel_carry()
	hold_copy(parts)
	carrying.repeats = false
	carrying.lines = lines
	carrying.frames = frames
	carrying.held = held_too
	carrying.stand_where_lifted(lattice, self)
	var away: Vector3 = Vector3.UP.cross(right).normalized()
	var ways: Array[Vector3] = [right, -right, -away, away]
	var tries: Array = []
	for way: Vector3 in ways:
		var across: float = absf(box.size.dot(way))
		# Whole studs, one clear of it: the copy stays on the stud grid.
		var clear: float = ceilf(across / _STUD) * _STUD + _STUD
		for further: int in 4:
			tries.append(way * (clear + further * _STUD))
	# Held where it stands by what is under it, first; else let down.
	var lowest: Vector3 = Vector3.INF
	for side: Vector3 in tries:
		if not carrying.fits_moved(side, lattice, self):
			continue
		if not carrying.fits_moved(side + Vector3(0, -_PLATE, 0), lattice, self):
			lowest = side
			break
		if not (lowest.x < INF):
			var down: Vector3 = side
			for _n: int in 400:
				if not carrying.fits_moved(down + Vector3(0, -_PLATE, 0), lattice, self):
					break
				down += Vector3(0, -_PLATE, 0)
			lowest = down
	if not (lowest.x < INF):
		carrying.drop()
		return 0
	carrying.stand_moved(lowest, lattice, self)
	var put: int = place()
	if put != 0 and not _history.is_empty():
		_history.back()["words"] = "duplicated %s" % _many(selection.size())
	return put


## Hold a copy of these parts, to put down where the pointer says.
func hold_copy(parts: Array) -> int:
	if parts.is_empty():
		return 0
	carrying.library = library
	carrying.hold(parts, false)
	return parts.size()


## Pick the selection up off the model to move it: it follows the pointer
## until a click puts it down, and picking it up and putting it down are
## one step to undo. Escape puts it back where it was. [param grab]: the
## pointer's line a drag began on ([from, way]): one part dragged alone goes
## on by the joint it was picked up by there ([member carry_grip]).
func lift_selection(grab: Array = []) -> int:
	var alive: PackedInt64Array = _moving_selection()
	if alive.is_empty():
		return 0
	# Lifted, one side of a locked joint would leave the other (jointlock).
	refused_lock = ""
	if world.motions != null and not world.motions.locks.is_empty():
		var lifted: Dictionary = {}
		for brick_id: int in alive:
			lifted[brick_id] = true
		var lock: Motions.Lock = world.motions.lock_split(lifted, world, self)
		if lock != null:
			refused_lock = Motions.lock_words(lock, world, library, self)
			return 0
	# Into hand, each part still the model's where it stood until it is put
	# down ([method _take_into_hand]); one lifted before goes back first.
	put_hand_back()
	var parts: Array = Carry.gather(world, library, Array(alive), true)
	if parts.is_empty():
		return 0
	carry_grip = _grip_at(alive[0], grab[0], grab[1]) \
		if alive.size() == 1 and grab.size() == 2 else null
	_grip_chosen = false
	var held: Array = []
	for item: Dictionary in parts:
		held.append(int(item["brick"]))
	_take_into_hand(held)
	clear_selection()
	carrying.library = library
	carrying.hold(parts, true)
	return parts.size()


## Put away what is held without putting it down. What was lifted off
## the model goes back where it was, and is selected again: whatever was
## done while it was in hand, as nothing of it ever left the model. Up to
## handkeep a lift with a step laid over it (a session's edit) was let go of
## off the model, and lost.
func cancel_carry() -> bool:
	if not is_carrying():
		return false
	var back: Array = _put_hand_back() if carrying.lifted and holds_lift() else []
	carrying.drop()
	carry_grip = null
	if not back.is_empty():
		selection.clear()
		for brick_id: int in back:
			selection[brick_id] = true
		selection_changed.emit(selection.size())
	return true


## Put down a selection lifted off the model where the carry's ghost is: each
## part the same part, moved, in its own step, sub-model and line of the file,
## one move to undo however much was done while it was in hand. A copy moved
## whole takes its sub-model's lines and what it holds with it as a drag's
## move does (ModelStore.looks_follow_edit). Up to handkeep its parts were
## put down anew, from what the carry remembered of them.
func _put_lifted() -> int:
	var moves: Dictionary = {}
	for item: Dictionary in carrying.placements(self):
		var brick_id: int = int(item.get("brick", 0))
		if _hand.has(brick_id):
			moves[brick_id] = {"at": item["at"], "boxes": item["boxes"]}
	var steps: Array = _put_hand_down(moves) if holds_lift() else []
	carrying.drop()
	carry_grip = null
	if steps.is_empty():
		return 0
	_keep({"undo": "group", "steps": steps, "words": "moved %s" % _many(steps.size())})
	_redo.clear()
	selection.clear()
	for step: Dictionary in steps:
		selection[int(step["brick"])] = true
	selection_changed.emit(selection.size())
	var first: int = int(steps[0]["brick"])
	placed.emit(first, world.get_brick(first).part_id)
	return first


## Put what is held down where its ghost is, as one step, and select it so
## it can be nudged or turned straight away.
func _put_carried() -> int:
	if not carrying.can_place():
		return 0
	if carrying.lifted:
		return _put_lifted()
	var steps: Array = []
	var ids := PackedInt64Array()
	# A copy of a minifigure or a named assembly is another one, not more
	# of the same: "Guard" pasted beside "Guard" is "Guard 2".
	var renamed: Dictionary = {}
	# Its sub-models' lights and views, where this model has none of its
	# own: what it had before is kept (Assemblies.lines_pasted).
	var lines_in: bool = not carrying.lines.is_empty()
	var had: Dictionary = Assemblies.definitions_had(world) if lines_in else {}
	var pasted: Array = []
	# A model put into this one whole (ModelStore.held_from) goes in as it
	# was read, every name free already: each copy's path in hand under the
	# one being edited, each part in its own step.
	var bringing: bool = carrying.brought
	# Into a model with steps, or one of its own: each part of it in a step,
	# one its author gave none to in its sub-model's first, as a file read
	# again has it.
	var stepped_in: bool = bringing and _brought_stepped()
	for item: Dictionary in carrying.placements(self):
		var group: String = str(item["group"])
		var unit: String = str(item.get("unit", ""))
		var path: String = ""
		if bringing:
			path = Assemblies.join(place_group, Assemblies.path_from(group, unit))
			renamed[Assemblies.path_from(group, unit)] = path
		elif copy_group.is_valid():
			path = copy_group.call(Assemblies.path_from(group, unit), renamed)
		elif not group.is_empty():
			if not renamed.has(group):
				renamed[group] = unused_group(group)
			group = renamed[group]
		var brick_id: int = world.add_brick(str(item["part"]),
			int(item["color"]), item["at"])
		if brick_id == 0:
			continue
		if lines_in:
			pasted.append([Assemblies.path_from(str(item["group"]), unit),
				path if copy_group.is_valid() or bringing else Assemblies.path_from(group, unit)])
		world.get_brick(brick_id).group = group
		world.get_brick(brick_id).unit = unit
		if bringing or copy_group.is_valid():
			set_path(world.get_brick(brick_id), path)
		# A copy goes in the step a placed part would, and was read from no
		# line; a model put in whole, in the step its author gave it.
		world.get_brick(brick_id).step = maxi(int(item.get("step", -1)), 0 if stepped_in else -1) \
			if bringing else _new_step(world.get_brick(brick_id))
		lattice.occupy_boxes(brick_id, item["boxes"])
		steps.append({"undo": "remove", "brick": brick_id})
		ids.append(brick_id)
	if ids.is_empty():
		return 0
	var words: String = "pasted %s" % _many(ids.size())
	if bringing:
		words = _bring_steps(steps, renamed, ids)
	_keep({"undo": "group", "steps": steps, "words": words})
	_redo.clear()
	if lines_in:
		pasted_said = Assemblies.lines_pasted(self, carrying.lines, pasted, had, carrying.frames,
			carrying.moved())
	# And what its copies hold that is not on the baseplate, in the copies it
	# put down, moved as it moved them, in the same step (ModelStore
	# ._held_put). Up to 2026-11-12 none came, and a save wrote the pasted
	# copy as the sub-model: the part the catalogue lacks in the first was in
	# no file (pc2check A2, H).
	if not carrying.held.is_empty() and (copy_group.is_valid() or bringing) \
			and held_put.is_valid():
		var into: Array = []
		for one: Dictionary in carrying.held:
			var kept: Dictionary = one
			if stepped_in and int(one.get("step", -1)) < 0:
				kept = one.duplicate()
				kept["step"] = 0
			into.append([kept, Assemblies.join(place_group, str(one["path"])) if bringing
				else copy_group.call(str(one["path"]), renamed)])
		held_put.call(into, carrying.moved())
	# A clone or a duplicate: another copy in hand for the next, as it
	# was before anything was typed for this one, R's turn kept, and the
	# sub-models' lights and views it brings.
	if bringing:
		_brought_down(renamed)
	var again: Array = carrying.base_items() if carrying.repeats else []
	var turned: int = carrying.turns
	var brought: Array = [carrying.lines, carrying.frames, carrying.held]
	carrying.drop()
	carry_grip = null
	if not again.is_empty():
		carrying.hold(again, false)
		carrying.turns = turned
		carrying.repeats = true
		carrying.lines = brought[0]
		carrying.frames = brought[1]
		carrying.held = brought[2]
	selection.clear()
	for brick_id: int in ids:
		selection[brick_id] = true
	selection_changed.emit(selection.size())
	placed.emit(ids[0], world.get_brick(ids[0]).part_id)
	return ids[0]


# -- a model brought into this one -------------------------------------------


## The step a model brought into this one whole goes on in, within the
## sub-assembly being edited ([member place_group]): the step showing, as a
## part put down by hand goes in, else after that one's last step, built
## last and put on last; -1, none, in a model nobody gave steps. Its own
## parts and the scenery, [param skip], are not counted.
func _brought_step(skip: Dictionary) -> int:
	var shown: int = int(place_step.call(place_group)) if place_step.is_valid() else -1
	if shown >= 0:
		return shown
	var had: Array = AuthorSteps.steps_in(world, AuthorSteps.home(world, place_group), skip)
	return int(had.max()) + 1 if not had.is_empty() else -1


## Whether a model brought in whole goes in with steps: it has its
## author's, or the model it goes into has steps. The scenery's are none of
## them: a baseplate of the model's made the floor again keeps the step it
## had (FloorLayer.release), and read as the model's, a model with no steps
## went in with steps into one nobody gave any (sk2fix3).
func _brought_stepped() -> bool:
	return carrying.brought_units.values().any(func(step: Variant) -> bool: return int(step) >= 0) \
		or carrying.items.any(func(item: Dictionary) -> bool: return int(item.get("step", -1)) >= 0) \
		or AuthorSteps.any(world, scenery)


## A model brought in whole, its parts [param ids] down: each copy of a
## sub-model in it (Carry.brought_units) put on in the step its author gave
## it, under the path this put-down gave it ([param renamed]), and the whole
## after the last step of the one it went into ([method _brought_step]).
## Into a model nobody gave steps, one that has them makes the steps that
## model was shown its own first (AuthorSteps.adopt_plan), as its first step
## edit would: else its parts, numbered after the steps brought in, came
## after them, every step one later than the person had read it. Not into
## someone else's file with no steps ("host_flat"): given steps it is
## written afresh and its own lines go, so it is the one step LDraw reads it
## as once a part of it has steps, its parts and the model brought in on in
## it, as it reopens (AuthorSteps.one_step; intomodel_probe menu_file,
## imreview deep). Each a step of [param steps], so the one undo that takes
## its parts off takes these too. What the history calls it.
func _bring_steps(steps: Array, renamed: Dictionary, ids: PackedInt64Array) -> String:
	# Not the model's to step: the parts put in, and the scenery, as every
	# other reading of the steps leaves it out. Planned with the house, the
	# baseplate took a place in its first step, and every step after moved
	# by a part from where the person had read it (sk2review2 F1).
	var skip: Dictionary = scenery.duplicate()
	for brick_id: int in ids:
		skip[brick_id] = true
	var stepped: bool = carrying.brought_units.values().any(
		func(step: Variant) -> bool: return int(step) >= 0) or carrying.items.any(
		func(item: Dictionary) -> bool: return int(item.get("step", -1)) >= 0)
	var flat: bool = stepped and bool(carrying.brought_data.get("host_flat", false))
	if flat:
		steps.append_array(AuthorSteps.one_step(world, skip))
	elif stepped:
		var planned: bool = not AuthorSteps.any(world, skip)
		steps.append_array(AuthorSteps.adopt_plan(world, library, skip))
		if bool(carrying.brought_data.get("steps_saved", false)):
			# A model with the app's own saved steps (ModelStore.held_from's
			# "steps_saved") leaves them no one's: into the app's own, they
			# stay so; into a model nobody gave steps, the steps it was shown
			# are kept as the app's own with them (BrickWorld.steps_own), as a
			# save and an open would keep them. Made the person's, the save
			# wrote AUTHORED_STEPS though no one gave a step (sk2fix2).
			if planned and not world.steps_own:
				steps.append(_apply({"undo": "stepsown", "own": true}))
		elif world.steps_own:
			# Into the app's own saved steps, a model with its author's makes
			# them the person's, as a step edit does (AuthorSteps.ensure). Left
			# the app's own, the save wrote no AUTHORED_STEPS, and the author's
			# steps it brought were read again as no one's (ic3 clash and menu).
			steps.append(_apply({"undo": "stepsown", "own": false}))
	var at: int = 0 if flat else _brought_step(skip)
	var stepped_in: bool = at >= 0 or stepped
	var whole: String = ""
	for path: String in carrying.brought_units:
		var now: String = str(renamed.get(path, Assemblies.join(place_group, path)))
		var step: int = int(carrying.brought_units[path])
		if path == str(carrying.brought_data.get("root", "")):
			whole = now
			step = at
		elif step == -1 and stepped_in:
			step = 0
		if step != -1:
			steps.append(_apply({"undo": "unitstep", "unit": now, "step": step}))
	return "put in %s, %s" % [Assemblies.definition(Assemblies.leaf(whole)), _many(ids.size())] \
		if not whole.is_empty() else "put in %s" % _many(ids.size())


## What else a model brought in whole brings, in the step that put its
## parts down (the newest), so its one Undo takes them out: how its booklet
## shows its steps (BookletLooks: a ROTSTEP's turn, its pages' pictures) and
## each of its sections' file names (BrickWorld.section_files), under the
## names this put-down gave them ([param renamed]). A picture this model has
## of its own is kept; a look under one of those names, which a sub-model
## taken apart left, is not.
func _brought_down(renamed: Dictionary) -> void:
	var data: Dictionary = carrying.brought_data
	var named: Dictionary = {}
	for path: String in renamed:
		named[Assemblies.definition(Assemblies.leaf(path))] = \
			Assemblies.definition(Assemblies.leaf(str(renamed[path])))
	var undo: Array = []
	var brought_looks: Dictionary = data.get("looks", {})
	if not brought_looks.is_empty():
		var looks: Dictionary = world.step_looks.duplicate(true)
		# Its sub-models' names are no copy's here (Assemblies.names_taken):
		# looks under them are what a sub-model taken apart left, not theirs.
		var defs: Dictionary = {}
		for path: String in renamed:
			defs[Assemblies.definition(Assemblies.leaf(str(renamed[path])))] = true
		for key: String in looks.keys():
			if key != BookletLooks.DATA and defs.has(key.get_slice("|", 0)):
				looks.erase(key)
		for key: String in brought_looks:
			var look: Variant = brought_looks[key]
			if key == BookletLooks.DATA:
				var pictures: Dictionary = (looks.get(key, {}) as Dictionary).duplicate()
				for picture: String in look:
					if not pictures.has(picture):
						pictures[picture] = look[picture]
				looks[key] = pictures
				continue
			var kind: String = key.get_slice("|", 0)
			var mine: String = str(named.get(kind, kind)) + key.substr(kind.length())
			looks[mine] = (look as Dictionary).duplicate(true) if look is Dictionary else look
		undo.append(_apply({"undo": "steplooks", "looks": looks}))
	var files: Dictionary = data.get("files", {})
	if not files.is_empty():
		var kept: Dictionary = world.section_files.duplicate()
		for def: String in files:
			var mine: String = str(named.get(def, def))
			if not kept.has(mine):
				kept[mine] = files[def]
		undo.append(_apply({"undo": "sectionfiles", "files": kept}))
	if not undo.is_empty():
		extend_last(undo)


## Work out where the held part would go, given a ray from the camera.
func update_preview(origin: Vector3, direction: Vector3) -> void:
	# Kept where it is while a number is typed (TypedEntry).
	if is_pinned():
		return
	# What is aimed is the hand's (a part, figure or selection lifted, or
	# else nothing lifted at all): the cells its parts stood in are free to
	# it, and to nothing else (BrickLattice.hand_free).
	var was_free: bool = lattice.hand_free
	lattice.hand_free = true
	_aim_hand(origin, direction)
	lattice.hand_free = was_free


func _aim_hand(origin: Vector3, direction: Vector3) -> void:
	var was: Vector3 = carrying.pivot() if is_carrying() else _ghost_transform.origin
	_joint_site = null
	_grip_on = false
	tracks.on_end = false
	if is_carrying():
		_ghost.visible = false
		_ghost_valid = false
		_hide_figure_ghosts()
		carrying.library = library
		_hovered = carrying.aim(lattice, self, origin, direction)
		_ask_copies()
		_went(was, carrying.pivot())
		return
	_aim_single(origin, direction)
	_ask_copies()
	_went(was, _ghost_transform.origin)


## Whether the other copies of the sub-assembly being edited have room for
## what the ghost would put down ([member copies_room]): the ghost red where
## one has not, as where something is in its way, and why said once as it
## turns so ([signal copies_refused]). A click there is still the follow's
## to judge (Assemblies.after_edit), which says the same. Asked again only
## when the ghost, the model or the level edited moved; an ask longer than
## [constant COPIES_ASK_US] goes on next frame, the ghost as it was till then.
func _ask_copies() -> void:
	var asked: Array = []
	# Into the sub-assembly being edited, or parts lifted back into their own:
	# a selection carried, or one part X took into hand (moved, as a drag's).
	if copies_room.is_valid() and (not place_group.is_empty() or is_carrying() and carrying.lifted
			or not is_carrying() and holds_lifted_part()):
		if is_carrying():
			if carrying.is_aimed() and carrying._valid:
				asked = ["carried", carrying._frame, carrying.turns]
		elif _ghost_valid and _ghost.visible and held_figure.is_empty() and not _ghost_warming:
			asked = [held_part, _ghost_transform]
	if not asked.is_empty():
		asked.append_array([place_group, world.revision, BrickWorld.paths_written, lattice.revision])
	# What is carried by the hold, not its contents: a paste held again is a
	# new array, and a big hand is not compared part by part each frame. Null
	# for a part in hand.
	var hand: Variant = carrying.items if is_carrying() else null
	if asked != _copies_asked or not is_same(hand, _copies_hand):
		_copies_asked = asked
		_copies_hand = hand
		copies_refuse = ""
		_copies_ask = {} if asked.is_empty() else {"items": _going_down(),
			"frame": carrying._frame if is_carrying() else _ghost_transform}
	if not _copies_ask.is_empty():
		# What is in hand is asked as the click finds it, put down: the cells
		# it stood in free (BrickLattice.hand_free), on the frames an ask goes
		# on into too, as on the aim's.
		var was_free: bool = lattice.hand_free
		lattice.hand_free = true
		var answer: Variant = copies_room.call(_copies_ask, COPIES_ASK_US)
		lattice.hand_free = was_free
		if answer == null:
			if is_inside_tree() and not get_tree().process_frame.is_connected(_ask_copies):
				get_tree().process_frame.connect(_ask_copies, CONNECT_ONE_SHOT)
		else:
			_copies_ask = {}
			copies_refuse = str(answer)
			# Said each time it is answered red: as it turns red, and again as
			# it moves on red once the line has cleared (the shell says it only
			# where the line does not say it already).
			if not copies_refuse.is_empty():
				copies_refused.emit(copies_refuse)
	var red: bool = not copies_refuse.is_empty()
	if is_carrying():
		carrying.copies_red(red)
	elif red:
		_ghost_material.set_shader_parameter("valid", false)
	elif _drawn_red and _ghost.visible:
		_ghost_material.set_shader_parameter("valid", _ghost_valid)
	if red != _drawn_red and not is_carrying():
		preview_changed.emit(held_part, _ghost_valid and not red)
	_drawn_red = red


## What a click would put down, [part id, where in the hand's frame, the
## sub-assembly it goes into] each, as [method _put_carried] puts it: the
## part in hand where its ghost is, or each part carried where the carry puts
## it (the frame: the ghost's, the carry's). A part lifted off the model goes
## back into its own (one picked in the tree and dragged, the sub-assembly
## round it not entered, or taken into hand by X); anything else into [member
## place_group], the one being edited. "" for the model itself. Made once a
## hand, the same array each aim (Assemblies._hand_plan keeps what it read of
## it): every aim of a drag made the hand's placements afresh, 200 of them
## with their cells.
func _going_down() -> Array:
	var hand: Variant = carrying.items if is_carrying() else null
	var lifted: int = int(_hand.keys()[0]) if not is_carrying() and holds_lifted_part() else 0
	var key: Array = [place_group, carrying.lifted] if is_carrying() else [place_group, held_part, lifted]
	if is_same(hand, _going_hand) and key == _going_key:
		return _going
	_going_hand = hand
	_going_key = key
	if not is_carrying():
		var brick: BrickWorld.Brick = world.get_brick(lifted) if lifted != 0 else null
		# X's part is put down moved (_put_lifted_part), in its own sub-model:
		# up to wingkeep it was asked into the one being edited, or not at all.
		_going = [[held_part, Transform3D.IDENTITY, place_group]] if brick == null \
			else [[held_part, Transform3D.IDENTITY, Assemblies.path_from(brick.group, brick.unit),
				brick.transform]]
		return _going
	_going = []
	for item: Dictionary in carrying.items:
		# And where a part lifted off the model stood (Carry.framed's "was"):
		# two twins in one hand are found by it (Assemblies.room_in_copies).
		_going.append([str(item["part"]), item["at"], place_group if not carrying.lifted
			else Assemblies.path_from(str(item.get("group", "")), str(item.get("unit", ""))),
			item.get("was") if carrying.lifted else null])
	return _going


var _going: Array = []
var _going_hand: Variant = null
var _going_key: Array = []


func _aim_single(origin: Vector3, direction: Vector3) -> void:
	if not held_figure.is_empty():
		_preview_figure(origin, direction)
		return
	_hide_figure_ghosts()
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part == null:
		_ghost.visible = false
		_ghost_valid = false
		return
	if library.sticks(held_part):
		_preview_sticker(part, origin, direction)
		return

	var hit: BrickLattice.Hit = lattice.raycast(origin, direction)
	_hovered = hit.brick_id
	# A train track in hand onto a free end of a track down, within 12
	# pixels of the pointer: end to end, before any stud (TrackSnap).
	if tracks.aim(self, held_part, origin, direction.normalized()):
		_ghost_transform = tracks.at
		_ghost_valid = room_for(held_part, tracks.at, false, true)
		_hovered = tracks.target.brick
		_seated_on = 0
		_show_ghost(part)
		return
	# Picked up off the model by a joint: on by that joint (grabseat).
	if grip != null and connect_end == null \
			and _onto_by_grip(part, origin, direction.normalized(), hit, grip):
		_show_ghost(part)
		return
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

	var onto: Variant = null if stands_only else _onto_side_studs(part, basis, hit, origin, direction)
	_ghost_transform = onto if onto != null else _settle(part, basis, target, hit)
	_seated_on = hit.brick_id if onto != null else 0
	_ghost_valid = _fits_on_studs(part, _ghost_transform, _seated_on, Vector3i(hit.normal)) \
		if _seated_on != 0 else room_for(held_part, _ghost_transform, false, true)
	# Not on side studs: those are found where the struck part's own are.
	var framed: Variant = _in_frame_of(hit.brick_id, _ghost_transform) \
		if hit.is_valid() and onto == null else null
	if framed != null and room_for(held_part, framed, false, true):
		_ghost_transform = framed
		_ghost_valid = true
	var seated: Variant = _on_struck_studs(part, basis, hit, target, _ghost_transform) \
		if onto == null else null
	if seated != null:
		_ghost_transform = seated
		_ghost_valid = true
	# Never down a stud past its foot: up to its stop where its cover put it
	# lower (a cone's narrows to its stud).
	var lift: float = stud_feet_lift([[held_part, _ghost_transform]]) if onto == null else 0.0
	if lift > 0.0:
		_ghost_transform.origin.y += lift
		_ghost_valid = room_for(held_part, _ghost_transform, false, true)
	_show_ghost(part)


## How far parts in hand, [param parts] ([part id, where] each), are down
## studs of the parts around them past the studs' feet, up the way those
## studs point: what lifts them to the studs' stop, as the check reads it
## (Exact.sunk_pairs). A part rests on the covers under it, and a cover is
## the cells a part fills: a cone's (59900, 4589) stops 4 or 6 LDU under its
## top, where it narrows to its stud, as a baseplate's (911) does under its
## studs. Rested there, a cone, a round plate or a dome put on that stud went
## 4 or 6 LDU down it, into the part below, and the check seated it there
## (realjoints2, 2026-11-05). Studs that point up only, which what rests on
## them stands on. 0 for none, and where a shape is still on its way (the
## web fetches it; the aim after it arrives lifts it). [param skip]: bricks
## that move with them.
##
## Asked on every aim, so it costs what is at the holes, never the model:
## what is near each hole where a stud could take it, never one box the
## figure's height, and of those only the studs that could take it
## (Exact.sunk_under). Asked of the parts in hand and every part near all
## together (Exact.sunk_pairs), a figure's own parts, held on each other's
## studs, were weighed against each other by their shapes whenever anything
## was near, 200 ms, and aiming a figure took 80 ms a move over a big model
## (figlift, 2026-11-06).
func stud_feet_lift(parts: Array, skip: Dictionary = {}) -> float:
	if world == null or lattice == null:
		return 0.0
	var held: Array = []  ## [shape, where] each
	for one: Array in parts:
		var shape: Exact.Shape = Exact.shape_for(library, str(one[0]))
		if shape != null:
			held.append([shape, one[1]])
	var near: Dictionary = {}  ## brick id -> its Item, null without a shape
	var across: float = Exact.SUNK_ACROSS + 1.0
	# Lifted off one stud, a part can be down another a little higher: asked
	# again, a few times at most.
	var lift: float = 0.0
	for _round: int in 3:
		var most: float = 0.0
		for one: Array in held:
			var item := Exact.Item.new(one[0], one[1])
			var holes: Array = Exact.up_holes(item)
			var others: Dictionary = {}
			for hole: Array in holes:
				var at: Vector3 = hole[1]
				for other: int in lattice.near_bounds(PackedInt32Array([
						floori((at.x - across) / BrickLattice.CELL),
						floori((at.y - 1.0) / BrickLattice.CELL),
						floori((at.z - across) / BrickLattice.CELL),
						ceili((at.x + across) / BrickLattice.CELL),
						ceili((at.y + Exact.SUNK_REACH + 1.0) / BrickLattice.CELL),
						ceili((at.z + across) / BrickLattice.CELL)])):
					if not skip.has(other):
						others[other] = true
			for other: int in others:
				if not near.has(other):
					var brick: BrickWorld.Brick = world.get_brick(other)
					var shape: Exact.Shape = Exact.shape_for(library, brick.part_id) \
						if brick != null else null
					near[other] = Exact.Item.new(shape, brick.transform) if shape != null else null
				if near[other] != null:
					most = maxf(most, Exact.sunk_under(near[other], item, holes))
		if most <= 0.0:
			break
		lift += most
		for one: Array in held:
			one[1] = (one[1] as Transform3D).translated(Vector3(0.0, most, 0.0))
	return lift


## [param at], worked out against the lattice, put in the frame of the part
## it was aimed at when that part stands square but off the lattice: on its
## studs, under it, against its side, exactly as on a part on the lattice,
## where the lattice alone puts it up to a cell off. A part's cover off the
## lattice is counted from the cell its origin is in (BrickLattice.within),
## so what was aimed at by it is that far, the part's own place past the
## cell, from where the part is. 8841-1's pan hangs from its pins 0.35 LDU
## off the lattice and its plates went a third of an LDU off each other;
## 5762-1's lights stand an LDU out of the lattice. Null where there is
## nothing to follow: a part on the lattice, a turned one, none.
func _in_frame_of(brick_id: int, at: Transform3D) -> Variant:
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if world != null else null
	if brick == null or not BrickLattice.is_square_to_grid(brick.transform.basis) \
			or not BrickLattice.is_off_lattice(brick.transform.origin):
		return null
	var past: Vector3 = brick.transform.origin \
		- BrickLattice.to_ldu(BrickLattice.to_cell(brick.transform.origin))
	for n: int in 3:
		if past[n] < 0.01 or past[n] > BrickLattice.CELL - 0.01:
			past[n] = 0.0
	return _tidy(Transform3D(at.basis, at.origin + past), true)


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
	var stickers: GDScript = Later.script(&"Stickers")
	var face: RefCounted = stickers.face_at(world, library, origin, direction, false, view_up)
	if face == null:
		_ghost.visible = false
		_ghost_valid = false
		_hovered = 0
		return
	_hovered = face.bricks[0]
	_ghost_transform = stickers.laid_on(face, part.bounds, held_rotation)
	_seated_on = 0
	_ghost_valid = true
	_show_ghost(part)


func _show_ghost(part: Lbm.PartMesh) -> void:
	_ghost_warming = false
	_ghost.mesh = part.surfaces[0]
	_ghost.transform = _ghost_transform
	_ghost.visible = true
	var tint: Color = library.color(held_color).shown
	_ghost_material.set_shader_parameter("tint", tint)
	_ghost_material.set_shader_parameter("valid", _ghost_valid)
	preview_changed.emit(held_part, _ghost_valid)


# -- by the joint it was picked up by (grabseat) --------------------------------


## The joint a part dragged off the model alone was picked up by, while it is
## carried ([method seat_carried]); null for anything else carried.
var carry_grip: Grip = null
## Quarter turns about the stud or hole a part was picked up by, as R leaves
## them, and whether R has been pressed since the ghost went on the stud or
## hole it is on: until then, the first quarter with room is found.
var _grip_roll: int = 0
var _grip_chosen: bool = false
## Whether the ghost is on a stud or a hole by the one the part was picked up
## by: what R turns it about, and T lets go of.
var _grip_on: bool = false
## The stud or hole it is on, and the last seat worked out, by what it was
## worked out from.
var _grip_key: String = ""
var _grip_last: String = ""
var _grip_last_at: Transform3D = Transform3D.IDENTITY
var _grip_last_fits: bool = false


## The ghost on the joint the pointer is aimed at by [param by], the joint
## the part in hand was picked up by: a pin hole onto a pin, a side stud into
## a stud's hole. False where nothing there takes that joint, and the part
## goes on by what does, as one from the bin: a side stud over a brick's top
## studs, the brick on them by its foot. Where something takes it with no
## room, the ghost shows it so, red, on the joint held.
func _onto_by_grip(part: Lbm.PartMesh, origin: Vector3, direction: Vector3,
		hit: BrickLattice.Hit, by: Grip) -> bool:
	if not by.ends.is_empty() and _onto_a_joint(part, origin, direction, hit, by.ends):
		return true
	return not by.studs.is_empty() and _onto_studs_by(by, origin, direction, hit)


## The ghost with the stud or stud's hole [param by] holds on the stud or
## hole that takes it of the part pointed at, nearest the pointer's line,
## seen from it and within Grip.REACH: the two at one place and pointing one
## way, as the check joins them (Exact.meets), turned least from how the part
## is held and then R's quarter turns about them.
func _onto_studs_by(by: Grip, origin: Vector3, direction: Vector3,
		hit: BrickLattice.Hit) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(hit.brick_id) if hit.is_valid() else null
	var mine: Exact.Shape = Exact.shape_for(library, held_part)
	var theirs: Exact.Shape = Exact.shape_for(library, brick.part_id) if brick != null else null
	if mine == null or theirs == null:
		return false
	var item := Exact.Item.new(theirs, brick.transform)
	var target: Array = []
	var k: int = -1
	var nearest: float = Grip.REACH
	for t: int in theirs.connector_count():
		if not Grip.is_stud_joint(theirs, t):
			continue
		var taking: int = -1
		for one: int in by.studs:
			if Grip.takes(mine, one, theirs, t):
				taking = one
				break
		if taking < 0:
			continue
		var there: Array = item.connector(t)
		if not Grip.seen(there, theirs.kind[t] == Exact.STUD, direction):
			continue
		var met: Array = Grip.from_line(origin, direction, there[1], there[1])
		if float(met[1]) > hit.distance + Grip.DEEP or float(met[0]) > nearest:
			continue
		nearest = met[0]
		target = there
		k = taking
	if target.is_empty():
		return false
	var key: String = "%d|%d|%d" % [brick.id, int(target[0]), k]
	if key != _grip_key:
		_grip_key = key
		_grip_chosen = false
	var start: Basis = BrickLattice.basis_for(held_face, held_rotation)
	if _grip_asked(key, start) != _grip_last:
		_grip_last_at = Grip.pose(mine, k, start, target, _grip_roll)
		_grip_last_fits = room_for(held_part, _grip_last_at, false, true)
		# Until R is pressed, the next quarter turn about it with room.
		for q: int in (3 if not _grip_chosen and not _grip_last_fits else 0):
			var at: Transform3D = Grip.pose(mine, k, start, target, _grip_roll + q + 1)
			if room_for(held_part, at, false, true):
				_grip_roll = posmod(_grip_roll + q + 1, 4)
				_grip_last_at = at
				_grip_last_fits = true
				break
		_grip_last = _grip_asked(key, start)
	_grip_on = true
	_hovered = brick.id
	_seated_on = 0
	_ghost_transform = _grip_last_at
	_ghost_valid = _grip_last_fits
	return true


## Everything a seat by a stud or hole held is worked out from, in one string.
func _grip_asked(key: String, start: Basis) -> String:
	return "%s|%d|%s|%s|%d|%s" % [key, world.revision, held_part, start, _grip_roll,
		_grip_chosen]


## Where one part dragged off the model alone goes, on by the joint it was
## picked up by ([member carry_grip]), for the line from [param origin] going
## [param direction] that met [param hit]: [where, whether it has room there,
## the part it goes on], as the hand seats one held; null where nothing
## there takes that joint, and it is carried as any part is (Carry.aim).
func seat_carried(part_id: String, origin: Vector3, direction: Vector3,
		hit: BrickLattice.Hit) -> Variant:
	if carry_grip == null or carry_grip.part != part_id or not is_carrying() \
			or not carrying.lifted or carrying.count() != 1:
		return null
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return null
	# Worked out as for the part in hand, held as it stood: what is in hand
	# between drags (the bin's part) is put back after.
	var kept: Array = [held_part, held_face, held_rotation, grip, _ghost_transform, _ghost_valid]
	held_part = part_id
	held_face = BrickLattice.face_of(carry_grip.was.basis)
	held_rotation = BrickLattice.turns_about(carry_grip.was.basis, held_face)
	var on: bool = _onto_by_grip(part, origin, direction.normalized(), hit, carry_grip)
	var out: Variant = [_ghost_transform, _ghost_valid, _hovered] if on else null
	held_part = kept[0]
	held_face = kept[1]
	held_rotation = kept[2]
	grip = kept[3]
	_ghost_transform = kept[4]
	_ghost_valid = kept[5]
	return out


## What R and T have left the seat on a joint at: a carry aimed again when
## it changes (Carry.aim).
func grip_stamp() -> String:
	return "%d|%d|%s|%d|%s" % [_joint_way, _joint_roll, _joint_extra, _grip_roll,
		carry_grip != null]


# -- onto a joint: a pin into a hole, a beam onto pins, a clip on a bar --


## How far the Turn setting on the toolbar turns a selection, in degrees.
## A part on a round joint turns by it when it is finer than
## JointSnap.ROUND_STEP; a cross in a cross always turns by quarters.
var turn_step: float = 90.0

## The end of a part down that the ghost is on, or null when it is not on
## one: what R turns about and T flips over, instead of the part's own up.
var _joint_site: JointSnap.End = null
var _joint_words: String = ""
## A gear in hand on an axle: the gear beside it that it seats in mesh with,
## or why it meshes none there ([method _into_mesh]); "" for anything else.
var _mesh_words: String = ""
## The places along the axle the ghost is on where the gear in hand meshes
## a gear beside it, and why there are none, by what they were found for
## ([method _mesh_places]).
var _mesh_found: Dictionary = {}
var _mesh_asked: String = ""
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
## The end of a part down the ghost was last on, kept as [member _joint_key]
## is: an axle's other end, aimed at as near, does not take over from it
## (JointSnap.aimed_at), so R and T stay as they were chosen.
var _joint_was: JointSnap.End = null
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
## Every part down with its ends, by where they are (JointSnap.site_grid):
## only the parts that changed are read again.
var _site_grid: BrickGrid = null


## Whether the ghost is on a joint, where R turns the part about it.
func is_on_joint() -> bool:
	return _joint_site != null


## The end of the part in hand that goes onto the joint it is on, in the
## part's own frame, or null (JointMarks draws it).
func joint_end() -> JointSnap.End:
	return null if _joint_site == null or _joint_options.is_empty() \
		else _joint_options[posmod(_joint_way, _joint_options.size())][0]


## What the ghost is on, in words, or "": "the pin hole of Technic Brick
## 1 x 2 with Hole".
func joint_words() -> String:
	if _joint_site == null:
		return ""
	return _joint_words if _mesh_words.is_empty() else "%s, %s" % [_joint_words, _mesh_words]


## Every connector of every part down that a part could be put onto, in
## the order JointSnap.sites_in gives them, read again only for the parts
## that changed.
func joint_sites() -> Array:
	if world != null and (_sites_at != world.revision or _sites_world != world):
		var grid: BrickGrid = _joint_grid()
		_sites = []
		for brick: BrickWorld.Brick in world.bricks():
			_sites.append_array(grid.kept_with(brick.id))
		_sites_at = world.revision
		_sites_world = world
	return _sites


func _joint_grid() -> BrickGrid:
	if _site_grid == null:
		_site_grid = JointSnap.site_grid(library)
		if not library.exact_fetched.is_connected(_on_exact_fetched):
			library.exact_fetched.connect(_on_exact_fetched)
	_site_grid.follow(world)
	return _site_grid


## A part's exact shape come in a browser after its parts were put down: they
## are measured again for their hinge halves (JointSnap.hinges_of), so a door
## goes into a frame put down before the frame's shape was there.
func _on_exact_fetched(part_id: String) -> void:
	if _site_grid == null or world == null:
		return
	var shape: Exact.Shape = Exact.shape_for(library, part_id)
	if shape == null or not shape.kind.has(Exact.HINGE):
		return
	var parts: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.shaped_as(brick.part_id)
		if info != null and info.id == part_id:
			parts[brick.part_id] = true
	_site_grid.remeasure(parts)
	_sites_at = -1
	_joint_last = ""


## Put the ghost on the joint the pointer is aimed at, if the part in hand
## has an end for one there. False, leaving the ghost to the studs, when
## it is not aimed at one or the part has no ends. Aimed only at a part a
## hinge is on (JointSnap.framed), on the first of its hinges, nearest
## first, the part has room on some way: a shutter over its window's middle
## on the hinge outside it, not a pane's inside it; and a second door held
## over a frame with one in it on the frame's studs. [param only]: the ends
## of the joint the part was picked up off the model by (Grip), alone.
func _onto_a_joint(part: Lbm.PartMesh, origin: Vector3, direction: Vector3,
		hit: BrickLattice.Hit, only: Array = []) -> bool:
	_joint_site = null
	# Connect's chosen point alone, when there is one: a 1 x 16 on two pins
	# by the hole the person picked, not by whichever of its 30 ways T is on.
	# The same of the hole a beam was picked up off the model by.
	var held: Array = only if not only.is_empty() \
		else JointSnap.ends_for(library, held_part) if connect_end == null else [connect_end]
	if held.is_empty() or world == null:
		return false
	# A little past what the line met: a hole's middle is inside the part
	# whose face was struck. Only the ends near the line are asked.
	var before: float = hit.distance + BrickLattice.STUD * 1.2 if hit.is_valid() else INF
	var near: Array = JointSnap.near(_joint_grid(), origin, direction, before)
	var site: JointSnap.End = JointSnap.aimed_at(near, held, origin, direction, before,
		lattice.unseen, _joint_was)
	if site != null and site.is_hinge() and not JointSnap.within_reach(site, origin, direction):
		var framed: Array = JointSnap.framed(near, held, origin, direction, before, lattice.unseen)
		site = null
		for other: JointSnap.End in framed.slice(0, _FRAMED_TRIES):
			if _has_room_on(other, held, origin, direction):
				site = other
				break
	if site == null:
		return false
	var basis: Basis = BrickLattice.basis_for(held_face, held_rotation)
	var options: Array = _into_mesh(JointSnap.choices(held, site, origin, direction), site, basis)
	if options.is_empty():
		return false
	var key: String = "%d|%s|%s|%s" % [site.brick, site.kind, site.at, site.axis]
	var held_key: String = held_part if connect_end == null \
		else "%s@%s%s" % [held_part, connect_end.at, connect_end.axis]
	if not only.is_empty():
		held_key = "%s#%s%s" % [held_part, (only[0] as JointSnap.End).at,
			(only[0] as JointSnap.End).axis]
	if held_key != _joint_part:
		_joint_part = held_key
		_joint_way = 0
		_joint_roll = 0
		_joint_extra = 0.0
		_joint_chosen = false
	if key != _joint_key:
		_joint_key = key
		_joint_extra = 0.0
		_joint_chosen = false
	_joint_options = options
	_joint_basis = basis
	if _joint_asked(key, basis, options) != _joint_last:
		_joint_last_at = _joint_pose(options, posmod(_joint_way, options.size()),
			_joint_roll, site, basis, _joint_extra)
		_joint_last_fits = room_for(held_part, _joint_last_at, true, true)
		if not _joint_chosen:
			_best_on_joint(options, site, basis)
		_joint_last = _joint_asked(key, basis, options)
	_joint_site = site
	_joint_was = site
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


## How many of the hinges of a part pointed at are tried for room, nearest
## first ([method _onto_a_joint]): 3853 has six of one kind, a pane's two on
## each face inside it and a shutter's two outside, nearest last.
const _FRAMED_TRIES := 8
## Whether the part in hand has room on a hinge some way, by the hinge, for
## the model, part and turn [member _hinge_room_at] says.
var _hinge_room: Dictionary = {}
var _hinge_room_at: String = ""


## Whether the part in hand has room some way on [param site], a hinge's
## half: either way along it, at any quarter turn about it.
func _has_room_on(site: JointSnap.End, held: Array, origin: Vector3, direction: Vector3) -> bool:
	var basis: Basis = BrickLattice.basis_for(held_face, held_rotation)
	var stamp: String = "%d|%s|%s" % [world.revision, held_part, basis]
	if stamp != _hinge_room_at:
		_hinge_room.clear()
		_hinge_room_at = stamp
	var key: String = "%d|%s|%s" % [site.brick, site.at, site.axis]
	if _hinge_room.has(key):
		return _hinge_room[key]
	var fits: bool = false
	for option: Array in JointSnap.choices(held, site, origin, direction):
		for q: int in 4:
			if room_for(held_part, JointSnap.pose(option[0], site, int(option[1]),
					float(option[2]), q * 90.0, basis), true, true):
				fits = true
				break
		if fits:
			break
	_hinge_room[key] = fits
	return fits


## A gear in hand going onto an axle anywhere along it: the ways onto it
## ([param options], JointSnap.choices) that seat it where it meshes a gear
## beside it, when the pointer is within GearMesh.CAPTURE of there and it
## has room there; [param options] as they are otherwise. Two 24s pointed
## onto axles three studs apart went on wherever the pointer was along each,
## a stud apart in depth, and meshed nothing (walk180). Said in
## [member _mesh_words]: what it meshes, or why nothing.
func _into_mesh(options: Array, site: JointSnap.End, basis: Basis) -> Array:
	_mesh_words = ""
	if site.kind != "axle" or site.back <= 0.0 or options.is_empty() \
			or Mechanism.spec_of(held_part).is_empty():
		return options
	options = _on_its_middle(options)
	var found: Dictionary = _mesh_places(options, site, basis)
	var seated: Array = []
	var further: float = INF
	var with: String = ""
	for place: Array in found["places"]:
		# [the way's index, slide, the gear it meshes in words]
		var gap: float = absf(float(place[1]) - float(options[int(place[0])][2]))
		if gap <= GearMesh.CAPTURE:
			seated.append([options[int(place[0])][0], options[int(place[0])][1], float(place[1]),
				gap, place[2]])
		elif gap < further:
			further = gap
			with = str(place[2])
	if seated.is_empty():
		if further < INF:
			_mesh_words = "meshing nothing here: it meshes %s %s studs along the axle" % [
				with.get_slice(" (", 0), Balance.studs(further / BrickLattice.STUD)]
		elif not str(found["why"]).is_empty():
			_mesh_words = str(found["why"])
		return options
	seated.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) < float(b[3]))
	_mesh_words = "in mesh with %s" % seated[0][4] if not str(seated[0][4]).contains(", once") \
		else "meshing %s" % seated[0][4]
	var out: Array = []
	for one: Array in seated:
		out.append([one[0], one[1], one[2]])
	return out


## A gear goes on an axle by the hole in its middle: of [param options],
## the ways by a hole on the gear's own axis, that hole taken on the axis.
## A 36 went on by the hole a stud from its middle, and turned about it; a
## 16's hole is drawn 0.28 LDU off its middle, and two 16s on axles two
## studs apart turned each other 1:1.02. Real sets stand a gear's middle on
## its axle.
func _on_its_middle(options: Array) -> Array:
	var spec: Dictionary = Mechanism.spec_of(held_part)
	var axis: Vector3 = Mechanism._axis_of(spec.get("axis", "z"))
	var middle: Vector3 = axis * float(spec.get("plane", 0.0))
	var out: Array = []
	for option: Array in options:
		var end: JointSnap.End = option[0]
		if absf(end.axis.dot(axis)) < 0.99:
			continue
		var gap: Vector3 = end.at - middle
		var off: Vector3 = gap - axis * gap.dot(axis)
		if off.length() > Mechanism.LINE_SLACK:
			continue
		var centred := JointSnap.End.new()
		centred.kind = end.kind
		centred.at = end.at - off
		centred.axis = end.axis
		centred.reach = end.reach
		centred.radius = end.radius
		centred.back = end.back
		centred.brick = end.brick
		out.append([centred, option[1], option[2]])
	return out if not out.is_empty() else options


## Where along the axle [param site] the part in hand, put on it each of
## [param options]' ways, meshes a gear beside it with room there:
## {"places": [[the way's index, its slide, "the 24 beside it (8 teeth to
## 24)"], ...], "why": why none does, or ""}. Read once for the axle, the
## model and the part as it is held, not at every motion of the pointer.
func _mesh_places(options: Array, site: JointSnap.End, basis: Basis) -> Dictionary:
	var asked: String = "%d|%s|%s|%d|%s|%s|%d" % [site.brick, site.at, site.axis, world.revision,
		held_part, basis, options.size()]
	if asked == _mesh_asked:
		return _mesh_found
	_mesh_asked = asked
	_mesh_found = {"places": [], "why": ""}
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part == null:
		return _mesh_found
	# A way's slide moves the part this way along the axle (JointSnap.pose).
	var way: Vector3 = -site.axis
	var reach: float = part.bounds.size.length() * 0.5 + GearMesh.BESIDE + BrickLattice.STUD * 4.0
	var span := AABB(site.at, Vector3.ZERO).expand(site.at - site.axis * site.back).grow(reach)
	var near := PackedInt32Array([floori(span.position.x / BrickLattice.CELL),
		floori(span.position.y / BrickLattice.CELL), floori(span.position.z / BrickLattice.CELL),
		ceili(span.end.x / BrickLattice.CELL), ceili(span.end.y / BrickLattice.CELL),
		ceili(span.end.z / BrickLattice.CELL)])
	var partners: Array = []
	for other: int in lattice.near_bounds(near):
		var brick: BrickWorld.Brick = world.get_brick(other)
		if brick != null and other != site.brick:
			partners.append_array(GearMesh.gears_at(brick.part_id, brick.transform,
				library.mesh_for(brick.part_id), other))
	if partners.is_empty():
		return _mesh_found
	var local_axis: Vector3 = Mechanism._axis_of(Mechanism.spec_of(held_part).get("axis", "z"))
	var facing: float = GearMesh.facing(held_part, part)
	var whys: Array = []   ## [how far, why]
	for n: int in options.size():
		var end: JointSnap.End = options[n][0]
		var side: int = int(options[n][1])
		var at: Transform3D = JointSnap.pose(end, site, side, 0.0, 0.0, basis)
		var faces: Vector3 = (at.basis * local_axis).normalized() * facing
		for mine: Mechanism.Gear in GearMesh.gears_at(held_part, at, part):
			# Only a gear turning on the axle: its own axis on the axle's line.
			if not Mechanism._same_line(mine.centre, mine.axis, site.at, site.axis):
				continue
			for theirs: Mechanism.Gear in partners:
				if not GearMesh.beside(mine, theirs):
					continue
				var how_far: float = (theirs.centre - mine.centre).length()
				var said: String = "%s beside it" % GearMesh.named(theirs)
				var shifts: Dictionary = GearMesh.shifts(mine, way, theirs, faces)
				# Where only the other stands wrong, this one seats where it
				# meshes once the other is slid along its axle.
				var half: bool = shifts.has("seat")
				if shifts.has("why") and not half:
					whys.append([how_far, "%s does not mesh: %s" % [said, shifts["why"]]])
					continue
				for shift: float in shifts["seat" if half else "shifts"]:
					var slide: float = snappedf(shift, 0.001)
					if slide < 1.0 - end.reach or slide > site.back - end.reach:
						whys.append([how_far, "%s meshes it only past the axle's end" % said])
						continue
					var there: Transform3D = JointSnap.pose(end, site, side, slide, 0.0, basis)
					if not room_for(held_part, there, true, true):
						var named: String = _part_named(room_blocker)
						whys.append([how_far, "%s meshes it where %s is in the way" % [said,
							named if not named.is_empty() else "a part"]])
						continue
					(_mesh_found["places"] as Array).append([n, slide, "%s (%s)" % [said,
						_teeth_words(mine, theirs)] if not half else "%s, once it is slid along its axle: %s" % [
						said, shifts["why"]]])
	if (_mesh_found["places"] as Array).is_empty() and not whys.is_empty():
		whys.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		_mesh_found["why"] = whys[0][1]
	return _mesh_found


## "8 teeth to 24", "a worm to 24 teeth".
static func _teeth_words(mine: Mechanism.Gear, theirs: Mechanism.Gear) -> String:
	if mine.kind == "worm":
		return "a worm to %d teeth" % theirs.teeth
	if theirs.kind == "worm":
		return "%d teeth to a worm" % mine.teeth
	return "%d teeth to %d" % [mine.teeth, theirs.teeth]


## A part's name as the parts list has it, "" for none.
func _part_named(brick_id: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if brick_id != 0 else null
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
	return "the " + Inventory._tidy(info.name) if info != null else ""


## Everything the pose on a joint is worked out from, in one string: the
## joint, the model as it stands, the part and how it is held, what R and
## T have chosen, the turn step, the first way on (which says which face
## is near), and how far along each way goes: where along a bar the pointer
## is, and how far an axle's tip is pushed through (JointSnap._pushed),
## which is as often the second way's as the first's.
func _joint_asked(key: String, basis: Basis, options: Array) -> String:
	return "%s|%d|%s|%s|%d|%d|%s|%s|%s|%s|%s|%s" % [key, world.revision, held_part, basis,
		_joint_way, _joint_roll, _joint_extra, _joint_chosen, turn_step, options[0][1],
		options.map(func(option: Array) -> float: return option[2]), _joint_part]


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
	if held_end.is_round() or held_end.is_hinge() \
			or JointSnap.step_of(held_end, site, 0.0) == JointSnap.CROSS_STEP:
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
	var best_under: float = INF
	var best_turned: float = INF
	if _joint_last_fits:
		best_joins = _joins_made(_joint_last_at)
		best_under = _under_ground(_joint_last_at)
		best_turned = _turned_from_picked(_joint_last_at)
	var tries: int = 0
	for n: int in options.size():
		# Connect's pin or axle goes in from the face pointed at, as a
		# person pushes one in, while it has room there: not on through to
		# the beam behind for one join more (8841-1's pin into the back of
		# its beam, out to the column).
		if n > 0 and _joint_last_fits and connect_end != null and connect_end.is_male():
			break
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
			if not room_for(held_part, at, true, true):
				continue
			var joins: int = _joins_made(at)
			# Of two that join as many, the one above the ground: a 1 x 16
			# by its end hole on two pins stood up them, not down through
			# the floor, which holds a part that hangs below the model.
			var under: float = _under_ground(at)
			# And of those, the one turned least from how it stood when
			# Connect's point was picked on it.
			var turned: float = _turned_from_picked(at)
			if joins > best_joins or (joins == best_joins and (under < best_under - 0.5
					or (under < best_under + 0.5 and turned < best_turned - 0.01))):
				best_joins = joins
				best_under = under
				best_turned = turned
				_joint_way = way
				_joint_roll = int(turn[0])
				_joint_extra = float(turn[1])
				_joint_last_at = at
				_joint_last_fits = true


## How far [param at] is turned from the pose the part stood in when
## Connect's point was picked on it; 0 with no point picked.
func _turned_from_picked(at: Transform3D) -> float:
	if connect_end == null or _connect_from == null:
		return 0.0
	var from: Basis = (_connect_from as Transform3D).basis
	return (at.basis.x - from.x).length() + (at.basis.y - from.y).length() \
		+ (at.basis.z - from.z).length()


## How far the part in hand at [param at] reaches below the ground, in LDU.
func _under_ground(at: Transform3D) -> float:
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	return maxf(0.0, -part.lowest_at(at)) if part != null else 0.0


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
	return _joined_with(at, library.mesh_for(held_part)).size()


## The parts down [param part] at [param at] would be joined to, id -> how,
## [param without] (the part it stands for) left out.
func _joined_with(at: Transform3D, part: Lbm.PartMesh, without: int = 0) -> Dictionary:
	var box: AABB = (at * part.bounds).abs().grow(BrickLattice.CELL * 2.0)
	var reach := PackedInt32Array([floori(box.position.x / BrickLattice.CELL),
		floori(box.position.y / BrickLattice.CELL), floori(box.position.z / BrickLattice.CELL),
		ceili(box.end.x / BrickLattice.CELL), ceili(box.end.y / BrickLattice.CELL),
		ceili(box.end.z / BrickLattice.CELL)])
	var entries: Array = [[0, at, part]]
	for other: int in lattice.near_bounds(reach):
		var brick: BrickWorld.Brick = world.get_brick(other)
		if brick != null and other != without:
			entries.append([other, brick.transform, library.mesh_for(brick.part_id)])
	var joined: Dictionary = (Joints.both_ways(entries).get(0, {}) as Dictionary).duplicate()
	joined.merge(Joints.rounds(entries).get(0, {}))
	return joined


## Whether a part has room at a place: nothing in its way but parts it is
## joined to the way real parts are joined, by the rule check_design uses
## (Assistant._joints_out) and no more — a pin in the hole it lines up
## with, an axle in its axle hole, a pane in its frame, and something
## round in something round that fits it where the two meet inside the
## round. [param grounded] refuses it below the ground as well, which a
## part on a joint can be and one on the studs never is.
## [param held]: the part in hand where the model holds it, on a joint,
## on what it rests on, under or beside a part of it. Below the ground
## there, the floor's baseplate is not in its way: it goes down through it,
## and nothing else moves ([method place]). [param ignore]: a brick that
## is not in its way, the part itself standing there already (a copy's
## part a follow laid, Assemblies.in_the_way); [param skip], more such,
## brick -> true (the rest of that copy, and what it met where it stood).
func room_for(part_id: String, at: Transform3D, grounded: bool = false,
		held: bool = false, ignore: int = 0, skip: Dictionary = {}) -> bool:
	room_blocker = 0
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	var packed: PackedInt32Array = boxes_for(part, at)
	if grounded and not held:
		var n: int = 1
		while n < packed.size():
			if packed[n] < GROUND_CELL:
				return false
			n += 6
	var blockers: PackedInt64Array = _not_scenery(lattice.blockers_boxes(packed, ignore, skip)) \
		if held else lattice.blockers_boxes(packed, ignore, skip)
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
		# Two train tracks joined end to end: a tab in the other's slot.
		if TrackSnap.joined(mine, at, theirs, there):
			continue
		if Nests._seated_in(mine, at, theirs, there) \
				or Nests._seated_in(theirs, there, mine, at):
			continue
		# A hinge's two halves, which BrickNet's labels pair (a door and its
		# frame), meet inside each other's covers at the pins: where both have
		# exact shapes, the shapes say, as check_design's do. 60621 shut in
		# 60596 had no room, nor did any door swung open on its frame's hinge.
		if _hinged_clear(mine, at, theirs, there):
			continue
		# So do a ball and the socket on it, round the ball: 3730 on
		# 15456's towball had no room at any turn, the socket's cover a
		# whole cell round a ball inside it.
		if _balled_clear(mine, at, theirs, there, packed, lattice.boxes_of(other)):
			continue
		# So do a part and the one whose studs it is on, where both have
		# exact shapes and the shapes are clear, as check_design clears them:
		# a saddle on a horse's back had no room where every set has it.
		if _studded_clear(mine, at, theirs, there):
			continue
		# And two parts that meet as the LEGO Group's own sets meet them, where
		# the sets put the one against the other, as check_design forgives them
		# (ExactCheck.let_meet): a 3960 dish on a 3941 round brick.
		if _fits_as_sets(mine, at, theirs, there):
			continue
		# And where one of the two has an exact shape and the other none, as
		# check_design judges them (ExactCheck.drop_in_air): a pane put in its
		# frame's groove, a drawer in its cupboard, meet only in covers a layer
		# filled shut, which the frame's shape has as air.
		if _in_air_of_one(part_id, at, packed, str(entries[n][3]), there,
				lattice.boxes_of(other)):
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
		room_blocker = other
		return false
	return true


## Whether two parts are a hinge's two halves by BrickNet's labels
## (Exact.hinge_between) and their exact shapes are clear of each other.
func _hinged_clear(mine: String, at: Transform3D, theirs: String, there: Transform3D) -> bool:
	var one: Exact.Shape = Exact.shape_for(library, mine)
	var other: Exact.Shape = Exact.shape_for(library, theirs)
	if one == null or other == null or not one.kind.has(Exact.HINGE) \
			or not other.kind.has(Exact.HINGE):
		return false
	var a := Exact.Item.new(one, at)
	var b := Exact.Item.new(other, there)
	return not Exact.hinge_between(a, b).is_empty() and Exact.clash(a, b, true).is_empty()


## Whether one of two parts has its ball in the other's socket, the two
## centres together (JointSnap's ball ends), and they meet only inside the
## joint, by check_design's rule (ExactCheck.at_joint): their exact shapes
## clear, or every piece of the one that overlaps a piece of the other within
## the ball's round of its centre. A socket closes round its ball, and
## BrickNet's convex pieces fill a socket's mouth: 2736 on 2739a's ball, as
## 9396-1 has it, meets it by 1.4 LDU there. Where either has no exact shape,
## by their covers ([param cover] and [param their_cover], lattice boxes):
## every cell the two share within that round, as far as a cell's half
## reaches.
func _balled_clear(mine: String, at: Transform3D, theirs: String, there: Transform3D,
		cover: PackedInt32Array, their_cover: PackedInt32Array) -> bool:
	var centre := Vector3.INF
	for one: JointSnap.End in JointSnap.ends_for(library, mine):
		if not one.is_ball():
			continue
		for other: JointSnap.End in JointSnap.ends_for(library, theirs):
			if other.is_ball() and JointSnap.mates(one, other) \
					and (at * one.at).distance_to(there * other.at) <= JointSnap.SAME_BALL:
				centre = (at * one.at + there * other.at) * 0.5
				break
		if centre != Vector3.INF:
			break
	if centre == Vector3.INF:
		return false
	var round: float = float((Later.script(&"ExactCheck").get_script_constant_map()["JOINT_ROUND"]
		as Dictionary)["ball"])
	var a: Exact.Shape = Exact.shape_for(library, mine)
	var b: Exact.Shape = Exact.shape_for(library, theirs)
	if a == null or b == null or not a.has_pieces() or not b.has_pieces():
		var reach: float = round + BrickLattice.CELL * 0.87
		var i: int = 0
		while i < cover.size():
			var j: int = 0
			while j < their_cover.size():
				var from := Vector3i(maxi(cover[i], their_cover[j]), maxi(cover[i + 1], their_cover[j + 1]),
					maxi(cover[i + 2], their_cover[j + 2]))
				var to := Vector3i(mini(cover[i + 3], their_cover[j + 3]),
					mini(cover[i + 4], their_cover[j + 4]), mini(cover[i + 5], their_cover[j + 5]))
				for x: int in range(from.x, to.x):
					for y: int in range(from.y, to.y):
						for z: int in range(from.z, to.z):
							if (Vector3(x + 0.5, y + 0.5, z + 0.5) * BrickLattice.CELL).distance_to(centre) > reach:
								return false
				j += 6
			i += 6
		return true
	var ia := Exact.Item.new(a, at)
	var ib := Exact.Item.new(b, there)
	if Exact.clash(ia, ib, true).is_empty():
		return true
	for hit: Array in Exact.overlaps(ia, ib):
		if Exact.overlap_reach(ia, int(hit[1]), ib, int(hit[2]), centre) > round:
			return false
	return true


## Whether one of two parts is on the other's studs by BrickNet's labels (a
## stud in a hole) and their exact shapes are clear of each other: a cover is
## whole cells, and a saddle's and its horse's meet round the horse's back.
func _studded_clear(mine: String, at: Transform3D, theirs: String, there: Transform3D) -> bool:
	var one: Exact.Shape = Exact.shape_for(library, mine)
	var other: Exact.Shape = Exact.shape_for(library, theirs)
	if one == null or other == null or not one.has_pieces() or not other.has_pieces():
		return false
	var items: Array = [Exact.Item.new(one, at), Exact.Item.new(other, there)]
	for edge: Array in Exact.connections(items):
		var kinds: Array = [(items[edge[0]] as Exact.Item).shape.kind[edge[1]],
			(items[edge[2]] as Exact.Item).shape.kind[edge[3]]]
		if kinds.has(Exact.STUD) and kinds.has(Exact.HOLE):
			return Exact.clash(items[0], items[1], true).is_empty()
	return false


## Whether two parts with exact shapes meet no deeper than official sets meet
## those two kinds of part in that pose (ExactCheck.meet_as_sets), and neither
## is further down the other's stud than a stud reaches, as the check's
## ExactCheck._fit_sunk allows one.
func _fits_as_sets(mine: String, at: Transform3D, theirs: String, there: Transform3D) -> bool:
	var one: Exact.Shape = Exact.shape_for(library, mine)
	var other: Exact.Shape = Exact.shape_for(library, theirs)
	if one == null or other == null or not one.has_pieces() or not other.has_pieces():
		return false
	var a := Exact.Item.new(one, at)
	var b := Exact.Item.new(other, there)
	if not Later.script(&"ExactCheck").meet_as_sets(a, mine, b, theirs):
		return false
	return maxf(Exact.sunk(a, b), Exact.sunk(b, a)) <= Joints.STUD_REACH


## Whether two parts, one with an exact shape and the other with none, share
## only cells whose middles are in the shaped one's air (Exact.meet_in_air).
func _in_air_of_one(mine: String, at: Transform3D, my_boxes: PackedInt32Array,
		theirs: String, there: Transform3D, their_boxes: PackedInt32Array) -> bool:
	var one: Exact.Shape = Exact.shape_for(library, mine)
	var other: Exact.Shape = Exact.shape_for(library, theirs)
	var one_shaped: bool = one != null and one.has_pieces()
	var other_shaped: bool = other != null and other.has_pieces()
	if one_shaped == other_shaped:
		return false
	var item := Exact.Item.new(one, at) if one_shaped else Exact.Item.new(other, there)
	return Exact.meet_in_air(my_boxes, their_boxes, item, Transform3D.IDENTITY)


## The part [method room_for] last found in the way, by its shapes; 0 when
## it was in none's (below the ground, or no geometry).
var room_blocker: int = 0


## [param ids] less the floor's own bricks.
func _not_scenery(ids: PackedInt64Array) -> PackedInt64Array:
	if scenery.is_empty() or ids.is_empty():
		return ids
	var out := PackedInt64Array()
	for id: int in ids:
		if not scenery.has(id):
			out.append(id)
	return out


## How far apart the places a part can be put down are, across the
## ground, in LDU: a stud (the default), half a stud, or the lattice's
## own two LDU. Set from the toolbar's snap; a jumper plate's half-stud
## offset, or a part nudged off the grid, needs the finer ones.
var snap_across: float = BrickLattice.STUD

## Whether a part goes down only standing on what is under it, whatever face
## it is aimed at: on while Simple's controls are up
## (SimpleLayer._set_full_aside), for Simple puts a part only where it stands.
## Full builds out from a wall at the height the face implies, hangs a part
## under an overhang and puts one on side studs, each of which stands it in
## the air where nothing is under it (simplereview4's hidden case: a 2 x 4 let
## go on a brick's side stood 16 LDU up, joined to nothing). On, a part aimed
## at a side or an underside rests on what is under it, as aimed anywhere
## else, and side studs are not offered; a carried group (Carry.aim) the
## same. Joints still take a part (a wheel onto its axle): held, not stood.
var stands_only: bool = false


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
	var takes: Array = _takes_studs(held_part, part)
	var phase: Variant = _socket_phase(takes, basis, footprint)
	if phase != null and snap_across >= BrickLattice.STUD - 0.01:
		var on: Vector2 = phase
		snapped = Vector3(
			round((target.x - on.x) / BrickLattice.STUD) * BrickLattice.STUD + on.x, target.y,
			round((target.z - on.y) / BrickLattice.STUD) * BrickLattice.STUD + on.y)
	# Where it takes a stud is where it was drawn to, or labelled, its box and
	# its studs on top what they may: a moulded horse's back stands 6 LDU off
	# the grid its hooves are on.
	if snap_across >= BrickLattice.STUD - 0.01 and not (phase != null and takes[1]):
		snapped = _on_its_own_grid(part, basis, box, footprint, target, snapped, phase != null)
	# On the studs of the part aimed at, where those stand off the grid.
	if snap_across >= BrickLattice.STUD - 0.01 and hit.is_valid() and hit.normal.y > 0:
		var seated: Variant = _on_studs_off_the_grid(part, basis, hit, target, takes[0])
		if seated != null:
			snapped = Vector3((seated as Vector3).x, snapped.y, (seated as Vector3).z)
	# Against a side face, out from it until its near side meets the face, as
	# a carried group goes. Its middle in the cell beside the face, a part
	# longer than a stud across the face stood half inside the part aimed at
	# and was refused: 8841-1's 1 x 12 beam beside the 1 x 2 at its middle.
	if hit.is_valid() and hit.normal.y == 0:
		snapped = _out_from_face(part, basis, snapped, hit)

	# Then drop it: the resting height is the highest surface under any
	# column the part covers, so a part laid across a step sits on the step
	# rather than sinking into it. Asked of the rectangle at once: column
	# by column, a 2 x 4 brick asked eight hundred of them at every move.
	var from := BrickLattice.to_cell(Vector3(
		snapped.x + box.position.x, 0.0, snapped.z + box.position.z))
	var to := BrickLattice.to_cell(Vector3(
		snapped.x + box.end.x, 0.0, snapped.z + box.end.z))
	to = Vector3i(maxi(to.x, from.x + 1), 0, maxi(to.z, from.z + 1))

	# Aimed at the underside of a part: hung under it, its top against
	# that underside, the way a plate is pressed up under an overhang.
	# Dropping it to whatever was below — the floor, usually — made the
	# underside of anything unreachable by hand, where Studio and
	# Mecabricks both attach there.
	# Never below the ground: under the baseplate is not somewhere a part
	# can be.
	if hit.is_valid() and hit.normal.y < 0 and not stands_only:
		# The struck cell is the lowest of the part above, and a box's
		# cell n starts at n cells, as surface_under counts them.
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
		# Below the ground under a part of the model, which then rises to
		# stand on it; never under the floor's own baseplate.
		if hung + box.position.y >= GROUND_CELL * BrickLattice.CELL \
				or not scenery.has(hit.brick_id):
			return Transform3D(basis, Vector3(snapped.x, hung, snapped.z))

	var rest_cell: int = lattice.surface_under(from.x, from.z, to.x, to.z, GROUND_CELL)
	var y: float = rest_cell * BrickLattice.CELL - box.position.y \
		- _sinks_by(part, basis, snapped, rest_cell)
	# Placing against a side face should not slide the part down onto the
	# floor, so a sideways hit keeps the height the face implies, to the
	# plate the pointer is on, as a carried group keeps it: two LDU off
	# every course, a beam beside a brick stood a cell or two off it.
	if hit.is_valid() and hit.normal.y == 0 and not stands_only:
		var level: int = BrickLattice._floor_div(hit.adjacent().y,
			BrickLattice.CELLS_PER_PLATE) * BrickLattice.CELLS_PER_PLATE
		var beside: float = level * BrickLattice.CELL - box.position.y
		# Not up onto what overhangs it there: what is over its far end is
		# not what it is put beside. 8841-1's 1 x 12 beam went beside the 1 x
		# 2 at its middle and up onto the 1 x 4 over them both.
		if y > beside + 0.01 and room_for(held_part,
				Transform3D(basis, Vector3(snapped.x, beside, snapped.z)), false, true):
			return Transform3D(basis, Vector3(snapped.x, beside, snapped.z))
		y = maxf(y, beside)
	elif y + box.position.y <= GROUND_CELL * BrickLattice.CELL + 0.01:
		# Down on the ground: unless the model holds it lower.
		var held: Variant = _held_below_ground(part, basis, snapped, y)
		if held != null:
			return Transform3D(basis, Vector3(snapped.x, held, snapped.z))
	# On its plate, not on what hangs below it, where that leaves room: the
	# clip plates of 5762-1's step 4 hang their clips 2 LDU below the plate,
	# over the edge of the plate they stand on, and stood 2 LDU up by their
	# box. Nothing struck from the side or below.
	var lift: float = _hangs_below(part, basis)
	if lift > 0.01 and not (hit.is_valid() and hit.normal.y <= 0 and not stands_only):
		var low: float = y - lift
		var at := Transform3D(basis, Vector3(snapped.x, low, snapped.z))
		if low + box.position.y >= GROUND_CELL * BrickLattice.CELL - 0.01 \
				and room_for(held_part, at):
			return at
	return Transform3D(basis, Vector3(snapped.x, y, snapped.z))


## [param snapped] put on the stud grid by the part itself where its box's
## count of studs is not to be trusted. Across an axis its box is not whole
## studs on (a curved slope's flared sides, 50948 is 58.5 LDU across), its
## sockets were laid on the box's guess too, so its own top studs say where
## it goes: 8643-1's cab roof stood half a stud aside. Across an axis it is
## whole studs on, with no socket on the grid to say otherwise
## ([param by_sockets] false, and none of its sockets on the half-stud
## grid), its box's middle goes where the box's count puts a middle, not
## its origin: 50949's origin is its front row of studs, half a stud from
## its middle. A plain part, its origin its box's middle, is where it was.
func _on_its_own_grid(part: Lbm.PartMesh, basis: Basis, box: AABB, footprint: Vector2i,
		target: Vector3, snapped: Vector3, by_sockets: bool) -> Vector3:
	if (basis * Vector3.UP).y < 0.99:
		return snapped
	var on_grid: bool = false
	for socket: Vector2 in part.sockets:
		var at: Vector3 = basis * Vector3(socket.x, 0.0, socket.y)
		if _on_half_stud(fposmod(at.x, BrickLattice.STUD)) \
				and _on_half_stud(fposmod(at.z, BrickLattice.STUD)):
			on_grid = true
	var out: Vector3 = snapped
	for axis: int in [0, 2]:
		var across: float = box.size[axis] / BrickLattice.STUD
		var whole: bool = absf(across - roundf(across)) * BrickLattice.STUD \
			<= BrickLattice.CLEARANCE
		var phase: Variant = null
		if not whole:
			for connector: Lbm.Connector in part.connectors:
				if connector.kind != "stud" or (basis * connector.axis).y < 0.99:
					continue
				phase = fposmod(BrickLattice.STUD * 0.5 - (basis * connector.position)[axis],
					BrickLattice.STUD)
				break
		elif not on_grid and not by_sockets:
			var middle: float = box.position[axis] + box.size[axis] * 0.5
			var odd: bool = (footprint.x if axis == 0 else footprint.y) % 2 == 1
			phase = fposmod((BrickLattice.STUD * 0.5 if odd else 0.0) - middle,
				BrickLattice.STUD)
		if phase == null:
			continue
		var on: float = snappedf(float(phase), 0.5)
		out[axis] = round((target[axis] - on) / BrickLattice.STUD) * BrickLattice.STUD + on
	return out


## Where the part in hand sits on the studs of the part it is aimed at the
## top of, when those studs stand off the stud grid: a jumper plate's one
## stud is half a stud from every other stud, and so is every stud of a
## part on it. One socket of the part on the stud nearest the pointer, the
## part as near the pointer as that allows; [x, 0, z] of its origin, or
## null where the part aimed at has no stud off the grid near the pointer
## (the grid seats it), the part stands off the lattice ([method
## _in_frame_of] puts it in that part's frame) or the part in hand has no
## socket to sit by. 5762-1's tail fin (4286) stands on three jumpers'
## middle studs, and stood half a stud aside; the slope on top of it was
## typed. [param sockets] are where the part takes a stud ([method
## _takes_studs]): a frog stands on a jumper by the hole under it, a saddle
## on a horse's back by its two.
func _on_studs_off_the_grid(part: Lbm.PartMesh, basis: Basis, hit: BrickLattice.Hit,
		target: Vector3, sockets: PackedVector2Array) -> Variant:
	if sockets.is_empty() or (basis * Vector3.UP).y < 0.99 or world == null:
		return null
	var struck: BrickWorld.Brick = world.get_brick(hit.brick_id)
	if struck == null or scenery.has(hit.brick_id) \
			or not BrickLattice.is_square_to_grid(struck.transform.basis) \
			or BrickLattice.is_off_lattice(struck.transform.origin):
		return null
	var mesh: Lbm.PartMesh = library.mesh_for(struck.part_id)
	if mesh == null:
		return null
	var stud: Variant = null
	var nearest: float = BrickLattice.STUD * 1.5
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or (struck.transform.basis * connector.axis).y < 0.99:
			continue
		var at: Vector3 = struck.transform * connector.position
		var half: float = BrickLattice.STUD * 0.5
		if absf(fposmod(at.x - half + 0.25, BrickLattice.STUD) - 0.25) < 0.5 \
				and absf(fposmod(at.z - half + 0.25, BrickLattice.STUD) - 0.25) < 0.5:
			continue
		var away: float = Vector2(at.x - target.x, at.z - target.z).length()
		if away < nearest:
			nearest = away
			stud = at
	if stud == null:
		return null
	var middle: Vector3 = basis * part.bounds.get_center()
	var chosen: Variant = null
	var closest: float = INF
	for socket: Vector2 in sockets:
		var under: Vector3 = basis * Vector3(socket.x, 0.0, socket.y)
		var place := Vector3((stud as Vector3).x - under.x, 0.0, (stud as Vector3).z - under.z)
		var off: float = Vector2(place.x + middle.x - target.x, place.z + middle.z - target.z).length()
		if off < closest:
			closest = off
			chosen = place
	return chosen


## The part in hand on the studs of the part [param hit] struck the top of,
## where the ghost [param at] has none of the places it takes a stud on them:
## each of those places ([method _takes_studs], where it is sure of them) on
## one of that part's studs, at their foot, as near [param target] as has
## room ([method room_for], which the two parts' shapes decide), and never
## higher than the ghost, which hangs a part under that one or holds it below
## the ground (8643-1's bracket under its plate) where it means to. A
## horse stood on a plate has the studs on its back off the grid, its hooves
## being off theirs (4493's by 5 LDU, 10509p02's by 6), and off the lattice
## too where the set has it, and a saddle aimed at them went 6 LDU aside or
## 34 LDU up, on the cover of the horse's neck. Null where the ghost is on
## them already or there is no such place.
func _on_struck_studs(part: Lbm.PartMesh, basis: Basis, hit: BrickLattice.Hit,
		target: Vector3, at: Transform3D) -> Variant:
	if not hit.is_valid() or hit.normal.y <= 0 or (basis * Vector3.UP).y < 0.99 \
			or world == null or scenery.has(hit.brick_id):
		return null
	var takes: Array = _takes_studs(held_part, part)
	var struck: BrickWorld.Brick = world.get_brick(hit.brick_id)
	var mesh: Lbm.PartMesh = library.mesh_for(struck.part_id) if struck != null else null
	if not takes[1] or (takes[0] as PackedVector2Array).is_empty() or mesh == null:
		return null
	var box: AABB = _rotated_bounds(part, basis)
	var reach: float = Vector2(box.size.x, box.size.z).length() * 0.5 + BrickLattice.STUD * 2.0
	var studs := PackedVector3Array()
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind != "stud" or (struck.transform.basis * connector.axis).y < 0.99:
			continue
		var stud: Vector3 = struck.transform * connector.position
		if Vector2(stud.x - target.x, stud.z - target.z).length() <= reach:
			studs.append(stud)
	var turned := PackedVector2Array()
	for socket: Vector2 in takes[0]:
		var v: Vector3 = basis * Vector3(socket.x, 0.0, socket.y)
		turned.append(Vector2(v.x, v.z))
	var height: float = takes[2]
	var here := Vector2(at.origin.x, at.origin.z)
	for socket: Vector2 in turned:
		if _stud_at(studs, here + socket, at.origin.y + height) != null:
			return null
	# Each place its middle within a stud and a half of the pointer: socket k
	# on a stud near where the pointer puts it.
	var middle: Vector3 = basis * part.bounds.get_center()
	var aimed: Vector2 = Vector2(target.x - middle.x, target.z - middle.z)
	var places: Array = []
	for stud: Vector3 in studs:
		if stud.y - height > at.origin.y + 0.5:
			continue
		for k: int in turned.size():
			var origin: Vector2 = Vector2(stud.x, stud.z) - turned[k]
			if origin.distance_to(aimed) > BrickLattice.STUD * 1.5:
				continue
			var all_on: bool = true
			for socket: Vector2 in turned:
				all_on = all_on and _stud_at(studs, origin + socket, stud.y) != null
			if all_on:
				places.append([origin.distance_to(aimed),
					Vector3(origin.x, stud.y - height, origin.y)])
	places.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for place: Array in places.slice(0, 4):
		var seat := Transform3D(basis, place[1])
		if room_for(held_part, seat, false, true):
			return seat
	return null


## The stud of [param studs] at [param across] (x, z), its foot at [param
## foot], to half an LDU; null for none.
static func _stud_at(studs: PackedVector3Array, across: Vector2, foot: float) -> Variant:
	for stud: Vector3 in studs:
		if Vector2(stud.x, stud.z).distance_to(across) <= 0.5 and absf(stud.y - foot) <= 0.5:
			return stud
	return null


## [param snapped] pushed out of the side face [param hit] struck, by whole
## studs, until nothing of the part's cover is on the far side of the face:
## its near side against the face, as Carry puts a group against one.
func _out_from_face(part: Lbm.PartMesh, basis: Basis, snapped: Vector3,
		hit: BrickLattice.Hit) -> Vector3:
	var cover: PackedInt32Array = boxes_for(part, Transform3D(basis,
		Vector3(snapped.x, 0.0, snapped.z)))
	if cover.is_empty():
		return snapped
	var axis: int = 0 if hit.normal.x != 0 else 2
	var way: int = hit.normal.x if axis == 0 else hit.normal.z
	var face: int = hit.adjacent()[axis] if way > 0 else hit.adjacent()[axis] + 1
	var lo: int = 1 << 30
	var hi: int = -(1 << 30)
	var n: int = 0
	while n < cover.size():
		lo = mini(lo, cover[n + axis])
		hi = maxi(hi, cover[n + 3 + axis])
		n += 6
	var past: int = (face - lo) if way > 0 else (hi - face)
	if past <= 0:
		return snapped
	var out: Vector3 = snapped
	out[axis] += way * ceili(float(past) / BrickLattice.CELLS_PER_STUD) * BrickLattice.STUD
	return out


## Where the model holds a part below the ground, at [param snapped]
## across: resting on the parts of the model under its own boxes, the floor
## and its baseplate left out, when that is lower than [param y], where the
## ground held it up, and below the ground. Null otherwise. 8643-1's front
## bracket (2436a) hangs its arm 4 LDU below the plate the set is built up
## from, and its wheels and tyres go lower still: a model built from its
## first part on the ground had no room for any of them. Put down, it goes
## there and the model stays where it stands ([method place]).
func _held_below_ground(part: Lbm.PartMesh, basis: Basis, snapped: Vector3,
		y: float) -> Variant:
	var cover: PackedInt32Array = boxes_for(part, Transform3D(basis,
		Vector3(snapped.x, 0.0, snapped.z)))
	if cover.is_empty():
		return null
	const DEEP := -(1 << 20)
	var rise: int = lattice.rise_onto(cover, DEEP, 0, 0, scenery)
	var low: int = 1 << 30
	var n: int = 1
	while n < cover.size():
		low = mini(low, cover[n])
		n += 6
	# Nothing of the model under it, or not below the ground where it does.
	if rise + low <= DEEP + 1 or rise + low >= GROUND_CELL:
		return null
	var at: float = rise * BrickLattice.CELL
	return at if at < y - 0.01 else null


## How many LDU lower a part rests by its own cover than by its box, at
## [param snapped] across, where its box rests on [param rest_cell]: the
## cover's boxes each on what is under its own columns. A part that is not
## a box has room its box has not: 2420, a corner plate, goes round a wheel
## holder's arm with its missing corner, and by its box it stood on the
## arm, a plate up (8643-1's step 2, 2026-10-17). 0 for a part whose cover
## fills its box across, which is every plain part. Its origin then stands
## where the cover's rise puts it. Taken as whole cells off its box's
## height, a part whose box is not whole cells deep sank by what its cover
## rounds out: a thick clip plate's ring hangs 1.448 LDU under it, its
## cover 2, and a made 61252 went 0.552 LDU into the brick under it,
## refused (makepart2, 2026-11-07).
func _sinks_by(part: Lbm.PartMesh, basis: Basis, snapped: Vector3, rest_cell: int) -> float:
	var cover: PackedInt32Array = boxes_for(part, Transform3D(basis,
		Vector3(snapped.x, 0.0, snapped.z)))
	if cover.size() <= 6:
		return 0.0
	var low: int = 1 << 30
	var n: int = 1
	while n < cover.size():
		low = mini(low, cover[n])
		n += 6
	var rise: int = lattice.rise_onto(cover, GROUND_CELL)
	var sink: int = rest_cell - low - rise
	if sink <= 0:
		return 0.0
	# Lower only where it is held by its sockets there: the boxes that take
	# studs rest on what is under them. 5762-1's 4488 stands on a wedge
	# plate by the block under half of it, where its sockets are, the other
	# half a plate over the wing; the wedge's cover is short of its slanted
	# edge under that block, and lowered by its cover the 4488 sank a plate
	# into the wing (2026-10-17). Its box's rest is kept only where its
	# sockets are held there: where they are held by nothing at either, the
	# box stood on what is under the room the part has not, and stood the
	# part in the air. An inverted slope (3665a) over a minifig's arm, or a
	# double slope's ridge, under its sloped underside stood 14 to 18 LDU
	# over them, its foot over the tile it was aimed at, and Simple offered
	# it (simplereview5's corner_shop, bigghost 2026-11-28). It rests by its
	# cover, as the same part carried does (Carry.aim).
	if not part.sockets.is_empty() and absf((basis * Vector3.UP).y) > 0.99 \
			and not _seated_by_sockets(part, basis, snapped, cover, rise) \
			and _seated_by_sockets(part, basis, snapped, cover, rest_cell - low):
		return 0.0
	return maxf(0.0, (rest_cell - rise) * BrickLattice.CELL - _rotated_bounds(part, basis).position.y)


## Whether a socket of [param part] (turned by [param basis], across at
## [param snapped], its cover [param cover] at height 0 raised [param rise]
## cells) sits on what is under it: the bottom of its cover where the socket
## is meets the top of what the lattice has under that column.
func _seated_by_sockets(part: Lbm.PartMesh, basis: Basis, snapped: Vector3,
		cover: PackedInt32Array, rise: int) -> bool:
	for socket: Vector2 in part.sockets:
		var at: Vector3 = basis * Vector3(socket.x, 0.0, socket.y) + snapped
		var cx: int = floori(at.x / BrickLattice.CELL)
		var cz: int = floori(at.z / BrickLattice.CELL)
		var seat: int = 1 << 30
		var n: int = 0
		while n < cover.size():
			if cover[n] <= cx and cx < cover[n + 3] and cover[n + 2] <= cz and cz < cover[n + 5]:
				seat = mini(seat, cover[n + 1])
			n += 6
		if seat == 1 << 30:
			continue
		if lattice.surface_under(cx - 1, cz - 1, cx + 1, cz + 1, GROUND_CELL) == seat + rise:
			return true
	return false


## Where [param part] ([param part_id]) takes a stud from underneath, in its
## own LDU across and along, whether that is sure, and how high, where the
## foot of a stud in it stands: [sockets, sure, height]. Its
## sockets, sure where they are the receivers it draws. Otherwise the
## catalogue laid them as stud squares from its foot's edge, and an edge off
## its own stud grid puts them off: an owl's (40232) 3 LDU from the tube it
## draws (Lbm.receivers_of), a crouching cat's (6251) 11 from the hole under
## its feet, a saddle's (4491a) 6 from the holes over a horse's studs, and the
## ghost stood that far from where their sets have them; or it laid none, a
## wolf's (48812) foot being no stud square, and the ghost went by its box.
## So the receivers it draws, or the holes its exact shape has lowest
## (Exact's "hole", where a stud goes in), which the seat puts it by; a
## tube's label is not one, being where a stud goes inside a tube. Unless
## the tube is at its foot and the catalogue's places are not: where the
## part's own shape fills every one of those, so no stud could stand there,
## a stud goes in only by the tube. A 4740 dish's catalogue put it on four
## studs round its middle, where its dome comes down, and a dish clicked on
## a 6141's stud stood 14 LDU off it, refused. Of the sets' 836 4740s, 441
## stand on one stud in their tube and none on four (seatfix, 2026-11-08). A
## 3960 dish, which they stand on four studs 37 times and on one 61, has
## room on four and keeps them; a hat, its tube up where a head's stud
## goes, keeps its own.
func _takes_studs(part_id: String, part: Lbm.PartMesh) -> Array:
	# A part the maker made, where it drew it to take one: its box hangs
	# under its plate where a level clip's ring does (ElementMaker.seat_of).
	# The maker is loaded for a made part only: the first screen and the
	# connector compile none of it (Later).
	var info: PartLibrary.PartInfo = library.parts.get(part_id) if library != null else null
	if info != null and info.custom:
		var made: Array = Later.script(&"ElementMaker").seat_of(library, part_id, part)
		if not made.is_empty():
			return made
	if part.sockets_drawn:
		return [part.sockets, true, part.bounds.position.y]
	var drawn: PackedVector2Array = Lbm.receivers_of(part)
	if not drawn.is_empty():
		return [drawn, true, part.bounds.position.y]
	var shape: Exact.Shape = Exact.shape_for(library, part_id)
	var holes := PackedVector2Array()
	var lowest: float = INF
	for k: int in shape.connector_count() if shape != null else 0:
		var frame: Transform3D = shape.frames[k]
		if shape.kind[k] != Exact.HOLE or shape.sub[k] != Exact.S_HOLE \
				or (-frame.basis.y).y < 0.99 or frame.origin.y > lowest + 1.0:
			continue
		if frame.origin.y < lowest - 1.0:
			holes.clear()
		lowest = minf(lowest, frame.origin.y)
		holes.append(Vector2(frame.origin.x, frame.origin.z))
	if not holes.is_empty():
		return [holes, true, lowest]
	if not _by_tube.has(part_id):
		_by_tube[part_id] = _tubes_only(shape, part)
	var tubes: PackedVector2Array = _by_tube[part_id]
	return [tubes, true, part.bounds.position.y] if not tubes.is_empty() \
		else [part.sockets, false, part.bounds.position.y]


## Where a part takes a stud only in a tube ([method _takes_studs]), by id.
var _by_tube: Dictionary = {}


## The tubes at [param part]'s foot, pointing down, that a stud has room in,
## where its shape leaves room for one at none of the catalogue's sockets;
## else none.
static func _tubes_only(shape: Exact.Shape, part: Lbm.PartMesh) -> PackedVector2Array:
	var tubes := PackedVector2Array()
	if shape == null or not shape.has_pieces():
		return tubes
	var foot: float = part.bounds.position.y
	for socket: Vector2 in part.sockets:
		if _stud_has_room(shape, Vector3(socket.x, foot, socket.y)):
			return tubes
	for k: int in shape.connector_count():
		var frame: Transform3D = shape.frames[k]
		if shape.kind[k] == Exact.HOLE and shape.sub[k] == Exact.S_TUBE \
				and (-frame.basis.y).y >= 0.99 and absf(frame.origin.y - foot) <= 1.0 \
				and _stud_has_room(shape, Vector3(frame.origin.x, foot, frame.origin.z)):
			tubes.append(Vector2(frame.origin.x, frame.origin.z))
	return tubes


## Whether a stud standing at [param at] (its foot, in the part's frame) is in
## none of [param shape]'s pieces: its middle and a ring 4.5 LDU out, an LDU
## and three up the stud's 4.
static func _stud_has_room(shape: Exact.Shape, at: Vector3) -> bool:
	for up: float in [1.0, 3.0]:
		if Exact.in_shape(shape, at + Vector3(0.0, up, 0.0)):
			return false
		for k: int in 8:
			var turn: float = TAU * k / 8.0
			if Exact.in_shape(shape, at + Vector3(4.5 * cos(turn), up, 4.5 * sin(turn))):
				return false
	return true


## Where on the stud grid a part goes across, by its sockets, when its box
## puts it elsewhere: [x, z] of its origin modulo a stud, or null where the
## box and a socket agree (every plain part) or it has none. Studs stand at
## odd multiples of half a stud (BrickLattice.snap_to_studs), so a socket
## must too. Upright or upside down only: a part on its side has its
## sockets on a side. [param takes] is where the part takes a stud
## ([method _takes_studs]).
func _socket_phase(takes: Array, basis: Basis, footprint: Vector2i) -> Variant:
	var sockets: PackedVector2Array = takes[0]
	if sockets.is_empty() or absf((basis * Vector3.UP).y) < 0.99:
		return null
	var half: float = BrickLattice.STUD * 0.5
	var by_box := Vector2(half if footprint.x % 2 == 1 else 0.0,
		half if footprint.y % 2 == 1 else 0.0)
	var counts: Dictionary = {}
	for socket: Vector2 in sockets:
		var at: Vector3 = basis * Vector3(socket.x, 0.0, socket.y)
		var phase := Vector2(fposmod(half - at.x, BrickLattice.STUD),
			fposmod(half - at.z, BrickLattice.STUD))
		phase = Vector2(snappedf(phase.x, 0.5), snappedf(phase.y, 0.5))
		if phase.distance_to(by_box) < 0.5:
			return null
		# Only a socket on the half-stud grid of the origin says where the
		# studs go: a wedge plate's (51739) are not, and taken at their word
		# put it 2 LDU off the studs. Or one where the part is drawn or
		# labelled to take one, wherever that is: a moulded horse's hooves.
		if not takes[1] and (not _on_half_stud(phase.x) or not _on_half_stud(phase.y)):
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
## bottom of its box, which is what it was dropped by. 0 for a plain part,
## which has nothing below its plate, and for one with no sockets or not
## upright. Less the bottom of its cover, which is whole cells, it sank by
## what those round out: a thick clip's ring hangs 1.448 LDU under its plate
## (61252) and its cover 2, and a made one stood 0.552 LDU into the brick it
## was put on, refused (makepart2, 2026-11-07).
func _hangs_below(part: Lbm.PartMesh, basis: Basis) -> float:
	if part.sockets.is_empty() or part.boxes.is_empty() \
			or (basis * Vector3.UP).y < 0.99:
		return 0.0
	var seat: float = INF
	for cells: AABB in part.boxes:
		var low: Vector3 = cells.position * part.cell_ldu
		var high: Vector3 = cells.end * part.cell_ldu
		for socket: Vector2 in part.sockets:
			if socket.x >= low.x - 0.01 and socket.x <= high.x + 0.01 \
					and socket.y >= low.z - 0.01 and socket.y <= high.z + 0.01:
				seat = minf(seat, low.y)
	return maxf(0.0, seat - part.bounds.position.y) if seat < INF else 0.0


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
	# The floor's baseplate is not in the way of a part the model holds
	# below the ground: put down, it goes through it (place).
	var blockers: PackedInt64Array = _not_scenery(lattice.blockers_boxes(packed))
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
	var cell: Vector3i = BrickLattice.grid_cell(at.origin)
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
		# Looked up and kept under the lock, worked out outside it: held
		# while a cover was worked out (11 to 16 ms for a wheel), it made
		# workers asked for covers side by side take turns.
		_turned_lock.lock()
		shape = _turned_off_main.get(key, PackedInt32Array())
		_turned_lock.unlock()
		if shape.is_empty():
			shape = BrickLattice.boxes_for_turned(
				part.boxes, Vector3i.ZERO, at.basis)
			_turned_lock.lock()
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


## The cover [method boxes_for] would give [param part] at [param at], to be
## asked where something is rather than worked out (BrickLattice.TurnedCover),
## when it would be worked out afresh: turned, or stretched, and not kept
## yet. Null when boxes_for has it at hand or works it out quickly (square
## to the grid, kept, or no cover of its own).
func turned_cover(part: Lbm.PartMesh, at: Transform3D) -> BrickLattice.TurnedCover:
	if part == null:
		return null
	var cell: Vector3i = BrickLattice.grid_cell(at.origin)
	var on_main: bool = OS.get_thread_caller_id() == OS.get_main_thread_id()
	var stretch := Vector3(at.basis.x.length(), at.basis.y.length(), at.basis.z.length())
	if not stretch.is_equal_approx(Vector3.ONE) and at.basis.determinant() > 0.0:
		var exact: Array = [part.get_instance_id(), at.basis]
		var kept: bool
		if on_main:
			kept = _stretched_cache.has(exact)
		else:
			_turned_lock.lock()
			kept = _stretched_off_main.has(exact)
			_turned_lock.unlock()
		if kept:
			return null
		return BrickLattice.turned_cover(_stretched_boxes(part, stretch), cell, at.basis.orthonormalized())
	if part.boxes.is_empty() or BrickLattice.is_square_to_grid(at.basis):
		return null
	var key: String = "%d|%s" % [part.get_instance_id(), at.basis]
	var has: bool
	if on_main:
		has = _turned_cache.has(key)
	else:
		_turned_lock.lock()
		has = _turned_off_main.has(key)
		_turned_lock.unlock()
	if has:
		return null
	return BrickLattice.turned_cover(part.boxes, cell, at.basis)


## Whether [method boxes_for] on this thread would work out a turned cover
## for [param part] at [param basis] afresh: turned, not stretched, with a
## cover, and not kept yet.
func turned_wanted(part: Lbm.PartMesh, basis: Basis) -> bool:
	if part == null or part.boxes.is_empty() or BrickLattice.is_square_to_grid(basis) \
			or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return false
	var stretch := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
	if not stretch.is_equal_approx(Vector3.ONE) and basis.determinant() > 0.0:
		return false
	return not _turned_cache.has("%d|%s" % [part.get_instance_id(), basis])


## Whether [method boxes_for] on this thread would work out a cover for
## [param part] at [param basis] afresh, turned or stretched: what work paced
## a slice at a time asks before it (Assemblies.frames_paced). A file whose
## turns are written to four places has every tilted part stretched a hair,
## and each such cover of 10179's was 10 to 30 ms of one frame.
func cover_wanted(part: Lbm.PartMesh, basis: Basis) -> bool:
	if part == null or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return false
	var stretch := Vector3(basis.x.length(), basis.y.length(), basis.z.length())
	if not stretch.is_equal_approx(Vector3.ONE) and basis.determinant() > 0.0:
		return not _stretched_cache.has([part.get_instance_id(), basis])
	return turned_wanted(part, basis)


## Keep a turned cover worked out elsewhere (Grab, side by side on workers)
## as [method boxes_for] keeps its own on this thread.
func keep_turned(part: Lbm.PartMesh, basis: Basis, shape: PackedInt32Array) -> void:
	if OS.get_thread_caller_id() == OS.get_main_thread_id() and not shape.is_empty():
		_turned_cache["%d|%s" % [part.get_instance_id(), basis]] = shape


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
##
## With [param pace] (it is then a coroutine), set going a slice at a time:
## 8466-1's 1,234 parts were looked over in 0.41 s of a browser's frame. Left
## where it is when the world is cleared meanwhile.
func prepare_covers(placements: Array, pace: Working.Job = null) -> void:
	finish_covers()
	if OS.get_thread_caller_id() != OS.get_main_thread_id() \
			or (OS.has_feature("web") and not OS.has_feature("threads")):
		return
	var generation: int = world.generation()
	## [stretched, key] of each cover set going, its task, and what it made.
	var jobs: Array = []
	var tasks: Array[int] = []
	var made: Dictionary = {}
	var writing := Mutex.new()
	var asked: Dictionary = {}
	for item: Variant in placements:
		if pace != null and pace.due():
			await pace.next()
			if world.generation() != generation:
				return
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
		var job := func() -> void:
			var shape: PackedInt32Array = BrickLattice.boxes_for_turned(boxes, Vector3i.ZERO, turn)
			writing.lock()
			made[n] = shape
			writing.unlock()
		# The first of the app's run alone, before others run it at once
		# (WorkerTasks.first_here): on a worker too, the others waiting for it,
		# as worked out here it held the frame for as long as it took.
		tasks.append(WorkerTasks.add(func() -> void:
			if not WorkerTasks.first_here("a turned cover", job):
				job.call(), true, "a turned cover"))
	if not jobs.is_empty():
		_preparing = [jobs, tasks, made, writing]


## What [method prepare_covers] set going: [jobs, tasks, made, its lock].
var _preparing: Array = []


## Whether the covers [method prepare_covers] set going are all worked out,
## so [method finish_covers] waits for none: a model laid over frames waits
## for them a frame at a time (ModelStore._open_into).
func covers_ready() -> bool:
	if _preparing.is_empty():
		return true
	for task: int in _preparing[1]:
		if not WorkerThreadPool.is_task_completed(task):
			return false
	return true


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
	var cell: Vector3i = BrickLattice.grid_cell(at.origin)
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
	var cell: Vector3i = BrickLattice.grid_cell(at.origin)
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
	# One part dragged on by the joint it was picked up by turns about that
	# joint, as one in hand does (seat_carried).
	if is_carrying() and not carrying.is_posed():
		carrying.turn(quarter_turns)
		return
	if _grip_on:
		_grip_roll = posmod(_grip_roll + quarter_turns, 4)
		_grip_chosen = true
		return
	# On a train track's end: its next end to the joint (TrackSnap).
	if tracks.on_end:
		tracks.turn(quarter_turns)
		return
	if _joint_site != null:
		for _n: int in absi(quarter_turns):
			_turn_on_joint(signi(quarter_turns))
		_joint_chosen = true
		return
	held_rotation = posmod(held_rotation + quarter_turns, 4)


## Roll the held part onto its next face: up, forward, down, back, and
## then over onto each side. On a joint, the next way onto it instead: in
## from the other face, the other way up, the next hole of a beam. On a stud
## or hole by the one it was picked up by, it lets go of that one: the part
## goes on as one from the bin does, by its foot.
func tip_held(steps: int = 1) -> void:
	if _grip_on:
		_grip_on = false
		if is_carrying():
			carry_grip = null
		else:
			grip = null
		return
	if _joint_site != null:
		_joint_way += steps
		_joint_chosen = true
		# Swung onto another end, if this way can be: the first such turn.
		_joint_extra = 0.0
		if not _joint_options.is_empty():
			var way: int = posmod(_joint_way, _joint_options.size())
			var closings: Array = _closings(_joint_options, way, _joint_site, _joint_basis)
			if not closings.is_empty():
				_joint_roll = 0
				_joint_extra = closings[0]
				# The first with room above the ground, as the way on is chosen.
				for closing: float in closings:
					var at: Transform3D = _joint_pose(_joint_options, way, 0, _joint_site,
						_joint_basis, closing)
					if room_for(held_part, at, true, true) and _under_ground(at) < 0.5:
						_joint_extra = closing
						break
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
	return _ghost != null and _ghost.visible and not _ghost_warming


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
	if not copies_refuse.is_empty():
		return false
	if is_carrying():
		return carrying.can_place()
	return has_preview() and _ghost_valid


## The ghost drawn once, a thousandth of [param mesh]'s size at [param at],
## too small to cover a pixel: its shader's programs made before the first
## part is picked (Main._warm_first_pick). Meanwhile there is no preview
## ([method has_preview]), so nothing aims at it, marks round it
## (JointMarks) or tells the page of it; a part picked meanwhile takes the
## ghost over as ever, and keeps it.
func warm_ghost(mesh: Mesh, at: Vector3) -> void:
	if _ghost.visible or mesh == null:
		return
	_ghost_warming = true
	_ghost.mesh = mesh
	_ghost.transform = Transform3D(Basis().scaled(Vector3.ONE * 0.001), at)
	_ghost.visible = true
	await RenderingServer.frame_post_draw
	if _ghost_warming:
		_ghost_warming = false
		_ghost.visible = false


## Whether the ghost shows only for [method warm_ghost].
var _ghost_warming: bool = false


func hide_preview() -> void:
	if connect_picking:
		return
	unpin_hand()
	_ghost.visible = false
	_ghost_valid = false
	_joint_site = null
	_hide_figure_ghosts()
	if carrying != null:
		carrying.hide_ghost()


# -- connect: a point on the part in hand, onto a point of a part down -----


## The end of the part in hand (JointSnap.End, in its own frame) that alone
## goes onto the joint the pointer is aimed at, as Connect chose it; null
## for any of its ends, as the hand has always gone (ConnectTool).
var connect_end: JointSnap.End = null
## Whether Connect is asking which point of the part in hand it goes on by:
## the ghost is kept where it stands, and a click puts nothing down.
var connect_picking: bool = false
## The pose the part in hand stood in while its point was picked.
var _connect_from: Variant = null


## Hold the part in hand still where its ghost stands, or at [param at],
## for Connect's points to be picked off it. False when it stands nowhere.
func hold_still(at: Variant = null) -> bool:
	if is_carrying() or not held_figure.is_empty():
		return false
	if at != null:
		var part: Lbm.PartMesh = library.mesh_for(held_part)
		if part == null:
			return false
		_ghost_transform = at
		_ghost_valid = true
		_joint_site = null
		_show_ghost(part)
		_ask_copies()
	if not has_preview():
		return false
	connect_picking = true
	_typed_from = _ghost_transform
	_connect_from = _ghost_transform
	return true


## Let the part in hand follow the pointer again, by [param end] alone (or
## by any of its ends, for null).
func follow_by(end: JointSnap.End) -> void:
	connect_picking = false
	connect_end = end
	if end == null:
		_connect_from = null
	_typed_from = null
	_joint_last = ""


# -- typed: what is in hand moved by a number -----------------------------


## Which way the ghost last went, along one axis of the model (a unit
## vector), or zero before it has gone anywhere: a number typed alone
## moves what is in hand that way (TypedEntry), as SketchUp's typed
## distance goes the way the move was going.
var last_way: Vector3 = Vector3.ZERO


## The ghost went from [param from] to [param to]: [member last_way] is the
## axis it went furthest along, by at least a cell.
func _went(from: Vector3, to: Vector3) -> void:
	if not has_preview():
		return
	var by: Vector3 = to - from
	var axis: int = by.abs().max_axis_index()
	if absf(by[axis]) < BrickLattice.CELL - 0.01:
		return
	last_way = Vector3.ZERO
	last_way[axis] = signf(by[axis])


## The single part in hand, kept where its ghost stood when a number began
## to be typed, the pointer no longer moving it, and what it turns about
## there: the joint it is on, or the upright through its middle. Null when
## nothing is typed. A group in hand keeps its own (Carry.pin).
var _typed_from: Variant = null
var _typed_point: Vector3 = Vector3.ZERO
var _typed_axis: Vector3 = Vector3.UP


## Keep what is in hand where its ghost stands now, for a number to move
## it from there (TypedEntry). False when it stands nowhere, or is a
## minifigure, which nothing typed moves.
func pin_hand() -> bool:
	if is_carrying():
		return carrying.pin()
	if not held_figure.is_empty() or not has_preview():
		return false
	_typed_from = _ghost_transform
	if _joint_site != null:
		_typed_point = _joint_site.at
		_typed_axis = _joint_site.axis.normalized()
	else:
		var part: Lbm.PartMesh = library.mesh_for(held_part)
		_typed_point = (_ghost_transform * part.bounds).abs().get_center() if part != null \
			else _ghost_transform.origin
		_typed_axis = Vector3.UP
	return true


func is_pinned() -> bool:
	return _typed_from != null or (carrying != null and carrying.is_pinned())


## Let go of the pin: the ghost follows the pointer again.
func unpin_hand() -> void:
	_typed_from = null
	if carrying != null and carrying.is_pinned():
		carrying.unpin()


## What is in hand, kept where it was pinned, turned [param turn] degrees
## about its joint or the upright, tilted [param tilt] degrees about the
## level [param tilt_axis] through its middle (its bottom kept where it
## was, as T keeps it), then moved [param move] LDU along the model's
## axes: shown there, and whether it may go down there. One placement when
## put down, as any is.
func typed_hand(move: Vector3, turn: float, tilt: float, tilt_axis: Vector3) -> bool:
	if not is_pinned():
		return false
	var was_free: bool = lattice.hand_free
	lattice.hand_free = true
	var fits: bool = _typed_hand(move, turn, tilt, tilt_axis)
	lattice.hand_free = was_free
	return fits


func _typed_hand(move: Vector3, turn: float, tilt: float, tilt_axis: Vector3) -> bool:
	# A group turns about where R turns it, the upright through its pivot.
	var point: Vector3 = _typed_point if _typed_from != null else carrying.pivot()
	var axis: Vector3 = _typed_axis if _typed_from != null else Vector3.UP
	var by := Transform3D.IDENTITY
	if not is_zero_approx(turn):
		by = _about(point, Basis(axis, deg_to_rad(turn))) * by
	if not is_zero_approx(tilt):
		var box: AABB = _box_after(by)
		var tipped: Transform3D = _about(box.get_center(), Basis(tilt_axis.normalized(),
			deg_to_rad(tilt))) * by
		var lands: AABB = _box_after(tipped)
		by = Transform3D(Basis.IDENTITY, Vector3(0.0, box.position.y - lands.position.y, 0.0)) \
			* tipped
	by = Transform3D(Basis.IDENTITY, move) * by
	if is_carrying():
		var shown: bool = carrying.show_moved(by, lattice, self)
		# The copies asked where the number puts it, as the pointer's aim asks.
		_ask_copies()
		return shown
	var at: Transform3D = by * (_typed_from as Transform3D)
	at = _tidy(Transform3D(at.basis.orthonormalized(), at.origin),
		BrickLattice.is_square_to_grid(at.basis))
	_ghost_transform = at
	# Not typed down through the floor, unless it was held below it (on a
	# joint under the model) when the number began.
	_ghost_valid = room_for(held_part, at, false, true) \
		and (not _below_ground(held_part, at) or _below_ground(held_part, _typed_from))
	_seated_on = 0
	var part: Lbm.PartMesh = library.mesh_for(held_part)
	if part != null:
		_show_ghost(part)
	_ask_copies()
	return _ghost_valid


func _below_ground(part_id: String, at: Transform3D) -> bool:
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return false
	var packed: PackedInt32Array = boxes_for(part, at)
	var n: int = 1
	while n < packed.size():
		if packed[n] < GROUND_CELL:
			return true
		n += 6
	return false


static func _about(point: Vector3, turn: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point) * Transform3D(turn, Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -point)


## The box round what is in hand where it was pinned, or an empty one.
func pinned_box() -> AABB:
	return _box_after(Transform3D.IDENTITY) if is_pinned() else AABB()


## The box round what is in hand where it was pinned, moved by [param by].
func _box_after(by: Transform3D) -> AABB:
	if _typed_from == null:
		return carrying.bounds_moved(by)
	var mesh: Lbm.PartMesh = library.mesh_for(held_part)
	if mesh == null:
		return AABB(by * (_typed_from as Transform3D).origin, Vector3.ZERO)
	return ((by * (_typed_from as Transform3D)) * mesh.bounds).abs()


## What R and T have left in hand: the part's turn and face, its way and
## turn on a joint, and a group's parts and quarter turns. EditVerbs keeps
## it before R or T, so a number typed straight after takes their place
## (a turn of 23.58 instead of R's step), as SketchUp's typed angle does.
func hand_state() -> Dictionary:
	return {"rotation": held_rotation, "face": held_face, "way": _joint_way,
		"roll": _joint_roll, "extra": _joint_extra, "chosen": _joint_chosen,
		"items": carrying.items.duplicate(true) if is_carrying() else [],
		"turns": carrying.turns if is_carrying() else 0}


func set_hand_state(state: Dictionary) -> void:
	held_rotation = int(state.get("rotation", held_rotation))
	held_face = str(state.get("face", held_face))
	_joint_way = int(state.get("way", _joint_way))
	_joint_roll = int(state.get("roll", _joint_roll))
	_joint_extra = float(state.get("extra", _joint_extra))
	_joint_chosen = bool(state.get("chosen", _joint_chosen))
	var items: Array = state.get("items", [])
	if is_carrying() and not items.is_empty():
		var keep: bool = carrying.repeats
		carrying.hold(items, carrying.lifted)
		carrying.repeats = keep
		carrying.turns = int(state.get("turns", 0))


# -- what is in hand, still in the model ---------------------------------
#
# A figure lifted by X and a selection picked up to move go into hand, not
# off the model: each part stays the model's, where it stood, in its step,
# sub-model and line of the file (BrickWorld.take_in_hand), drawn nowhere and
# out of the lattice, until it is put down (one move, [method _put_hand_down])
# or put back where it stood ([method _put_hand_back]), which changes nothing.
# So every writer (the autosave, Ctrl+S, the window's close, an export, a
# share, a session's read and save) writes it where it stood, and a crash or a
# reload finds it there; the timeline is never worked out without it; an edit
# made while it is held is made beside it; and put down, each part is the same
# part, moved. Lifted off the model, the parts in hand were in no file
# (figreview2 F3), and what was put down was made again from what the hand
# remembered of them, which an edit in between made it forget (F1: a figure's
# parts out of their steps and sub-model, in a new fig_2).

## The parts in hand, id -> {"at": where it stood, "cover": its cover there}.
var _hand: Dictionary = {}
## The history's depth when they were lifted: while nothing since is in it,
## the lift is the newest thing done, and Undo puts them back.
var _hand_depth: int = 0


## Whether parts lifted off the model are in hand, put down nowhere yet.
## A world cleared or opened again let go of them (BrickWorld.clear), with
## the figure or the selection they were: what was opened has them where its
## file does, and nothing in hand to put down a second time (figreview2 F5).
func holds_lift() -> bool:
	if _hand.is_empty():
		return false
	if world != null and world.in_hand(int(_hand.keys()[0])):
		return true
	var figure: bool = not _figure_parts.is_empty()
	_hand = {}
	_figure_parts = {}
	if figure:
		held_figure = []
		held_figure_name = ""
		_hide_figure_ghosts()
	if carrying != null and carrying.lifted:
		carrying.drop()
		carry_grip = null
	return false


## Whether the lift is the newest thing done, nothing recorded since: Undo
## puts what is in hand back. With a change made since (a nudge, a session's
## edit), Undo takes that back first, the parts still in hand.
func lift_newest() -> bool:
	return holds_lift() and _history.size() <= _hand_depth


## What the lift is called in the history's words.
func _hand_words() -> String:
	return "lifted %s" % _many(_hand.size())


## Take [param ids] into hand, out of the lattice and the selection.
func _take_into_hand(ids: Array) -> void:
	_hand = {}
	world.hand_touched = _hand_touched
	var unpicked: bool = false
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or world.in_hand(brick_id):
			continue
		# Out of the lattice, its cells still in the way of anything but the
		# hand (BrickLattice.take_in_hand), as it is still there in the file.
		_hand[brick_id] = {"at": brick.transform, "cover": lattice.take_in_hand(brick_id)}
		world.take_in_hand(brick_id)
		unpicked = selection.erase(brick_id) or unpicked
	_hand_depth = _history.size()
	if unpicked:
		selection_changed.emit(selection.size())


## Every part in hand back where it stood, as it was: nothing in the model
## changes, and nothing is recorded. [param leave]: the one part whose cover
## whoever moves or takes it off next looks after (BrickWorld.hand_touched).
## The parts put back.
func _put_hand_back(leave: int = 0) -> Array:
	var held: Dictionary = _hand
	_hand = {}
	_figure_parts = {}
	var back: Array = []
	for brick_id: int in held:
		if not world.in_hand(brick_id):
			continue
		var at: Transform3D = held[brick_id]["at"]
		world.put_from_hand(brick_id, at)
		back.append(brick_id)
		if brick_id == leave:
			# Its cover is whoever moves or takes it off's to set: none kept
			# in the way where it stood.
			lattice.release(brick_id)
			continue
		var cover: Array = held[brick_id]["cover"]
		if not (cover[0] as PackedInt32Array).is_empty():
			lattice.occupy_moved(brick_id, cover, Vector3i.ZERO)
		else:
			lattice.occupy_boxes(brick_id, boxes_for(
				library.mesh_for(world.get_brick(brick_id).part_id), at))
	return back


## Every part in hand put down where [param moves] says (id -> {"at",
## "boxes"}), as one move: the steps that undo it, each part back where it
## stood.
func _put_hand_down(moves: Dictionary) -> Array:
	var held: Dictionary = _hand
	_hand = {}
	_figure_parts = {}
	var steps: Array = []
	for brick_id: int in held:
		if not world.in_hand(brick_id) or not moves.has(brick_id):
			continue
		var to: Transform3D = moves[brick_id]["at"]
		world.put_from_hand(brick_id, to)
		lattice.occupy_boxes(brick_id, moves[brick_id]["boxes"])
		steps.append({"undo": "move", "brick": brick_id, "transform": held[brick_id]["at"]})
	# One the move did not say where to put (none should be) goes back.
	for brick_id: int in held:
		if world.in_hand(brick_id):
			_hand[brick_id] = held[brick_id]
	_put_hand_back()
	return steps


## Whether the part in hand is one lifted by X (not a figure, nor a selection
## carried): still the model's where it stood, the ghost the part's own
## ([member held_part]), put down by a move ([method _put_lifted_part]).
func holds_lifted_part() -> bool:
	return holds_lift() and _figure_parts.is_empty() and not (carrying != null and carrying.lifted)


## Put the part lifted by X down where its ghost is: the same part, moved, in
## its own step, sub-model and line of the file; painted the colour in hand if
## another was chosen while it was held; with the sleepers a track's joint
## takes. One step to undo. Its kind stays in hand after, as a part from the
## bin does, to put down more of.
func _put_lifted_part() -> int:
	var brick_id: int = int(_hand.keys()[0])
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
	if part == null:
		return 0
	var steps: Array = _put_hand_down({brick_id: {"at": _ghost_transform,
		"boxes": boxes_for(part, _ghost_transform)}})
	if steps.is_empty():
		return 0
	if held_color != brick.color_code:
		steps.append({"undo": "recolor", "brick": brick_id, "color": brick.color_code})
		world.recolor_brick(brick_id, held_color)
	if tracks.on_end and not tracks.sleepers.is_empty():
		steps.append_array(_put_sleepers(tracks.sleepers))
	# Put down past the step the timeline shows (stepped back while it was in
	# hand): Main steps on to it and says so, as for a figure.
	put_unseen = PackedInt64Array([brick_id]) if is_ahead(brick_id) else PackedInt64Array()
	_keep({"undo": "group", "steps": steps, "words": "moved %s" % _many(1)})
	_redo.clear()
	below = maxf(0.0, -part.lowest_at(_ghost_transform))
	_typed_from = null
	grip = null
	placed.emit(brick_id, brick.part_id)
	return brick_id


## Let go of whatever lifted off the model is in hand, each part back where it
## stood, the figure or the selection in hand with it. How many went back.
func put_hand_back() -> int:
	return _let_go_of_hand() if holds_lift() else 0


func _let_go_of_hand(leave: int = 0) -> int:
	var figure: bool = not _figure_parts.is_empty()
	var back: Array = _put_hand_back(leave)
	if figure:
		held_figure = []
		held_figure_name = ""
		_hide_figure_ghosts()
	if carrying != null and carrying.lifted:
		carrying.drop()
		carry_grip = null
	hand_put_back.emit(back.size())
	return back.size()


## What was in hand went back where it stood without being put down: let go
## of ([method put_hand_back]), or a change to one of its parts made by
## something else ([method _hand_touched]: a session's edit, an undo or redo of
## a step that names it).
signal hand_put_back(count: int)


## A part in hand about to be changed by something other than the hand
## (BrickWorld.hand_touched): the hand let go of first, every part back where
## it stood, so the change is made to it there, and nothing it held is lost.
## Moved or taken off, the one part's cover is the changer's.
func _hand_touched(brick_id: int, kind: String) -> void:
	if _hand.has(brick_id):
		_let_go_of_hand(brick_id if kind != "paint" else 0)


# -- a minifigure, as one thing ------------------------------------------


## Hold a figure to put down: its parts in its own frame, as
## Minifig.assemble gives them, and the name its parts will carry. A figure
## lifted off the model and still in hand goes back where it stood first
## (figreview2 F4: X over a second figure left the first off the model).
func hold_figure(parts: Array, called: String) -> void:
	put_hand_back()
	held_figure = parts.duplicate()
	held_figure_name = called if not called.strip_edges().is_empty() else "Minifig"
	held_face = "up"
	_figure_parts = {}


## Go back to holding the part that was held before. A figure lifted off
## the model goes back where it stood, as Escape puts a carried selection
## back (figreview2 F2: it stayed off the model). Whether one went back.
func drop_figure() -> bool:
	var back: bool = is_holding_figure() and holds_lift() and not _figure_parts.is_empty()
	if back:
		_put_hand_back()
	held_figure = []
	held_figure_name = ""
	_figure_parts = {}
	_hide_figure_ghosts()
	return back


func is_holding_figure() -> bool:
	return not held_figure.is_empty()


## Whether the figure in hand is one lifted off the model (X over it), whose
## parts are still the model's where they stood (the hand): put down, it is
## moved.
func holds_lifted_figure() -> bool:
	return is_holding_figure() and not _figure_parts.is_empty() and holds_lift()


## Where a figure facing a quarter turn would stand, aimed at a point:
## centred on a pair of studs, on whatever is highest under its feet.
##
## A figure stands on two studs side by side, one under each leg, so it
## snaps the way a 1 x 2 plate does — across a pair of studs, along a
## row of them — and rests on the highest surface under either foot.
## Given its [param parts] (a figure's, "part" and "at" each), never down
## a stud past its foot ([method stud_feet_lift]): legs on two cones.
func settle_figure(target: Vector3, rotation: int,
		hit: BrickLattice.Hit = null, parts: Array = []) -> Transform3D:
	var basis: Basis = BrickLattice.basis_for("up", rotation)
	var footprint := Vector2i(1, 2) if posmod(rotation, 2) == 1 else Vector2i(2, 1)
	var snapped: Vector3 = BrickLattice.snap_to_studs(target, footprint)
	var half := Vector3(footprint.x, 0.0, footprint.y) * (BrickLattice.STUD * 0.5)
	var from: Vector3i = BrickLattice.to_cell(snapped - half)
	var to: Vector3i = BrickLattice.to_cell(snapped + half)
	var rest_cell: int = lattice.surface_under(from.x, from.z, to.x, to.z, GROUND_CELL)
	if hit != null and hit.is_valid() and hit.normal.y == 0:
		rest_cell = maxi(rest_cell, hit.adjacent().y)
	var at := Transform3D(basis, Vector3(snapped.x, rest_cell * BrickLattice.CELL, snapped.z))
	at.origin.y += figure_lift(parts, at)
	return at


## How far a figure's [param parts] standing at [param at] are down studs
## past their feet ([method stud_feet_lift]).
func figure_lift(parts: Array, at: Transform3D) -> float:
	var placed: Array = []
	for item: Dictionary in parts:
		placed.append([str(item["part"]), at * (item["at"] as Transform3D)])
	return stud_feet_lift(placed) if not placed.is_empty() else 0.0


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


## The whole of the figure in hand, "part" and "at" each: lifted off the model
## at a step, the parts of it on show ([member held_figure]) and those a step
## has not put on yet, which go with it. All are in hand and out of the
## lattice, so none holds its own feet up where it stood, nor is in its own
## way: aimed back where it stood, a figure with its head still to come stood
## on that head, 104 LDU up, and its plate to come was refused over studs the
## plate on show seats on (fastreview F1, F2). Up to stepfast a later head was
## put down inside a plate over the figure's shoulders, unasked.
func _figure_whole() -> Array:
	if _figure_parts.is_empty() or not holds_lift():
		return held_figure
	var whole: Array = []
	for brick_id: int in _figure_parts:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			whole.append({"part": brick.part_id, "at": _figure_parts[brick_id]})
	return whole


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
	_keep({"undo": "remove", "brick": brick_id})
	_redo.clear()
	placed.emit(brick_id, part_id)
	return brick_id


## Take a brick off as one step that undo puts back: a sticker peeled off.
func take_off(brick_id: int) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return false
	var step: Dictionary = _apply({"undo": "remove", "brick": brick_id})
	_keep(step)
	_redo.clear()
	if selection.erase(brick_id):
		selection_changed.emit(selection.size())
	removed.emit(brick_id)
	return true


## A group name the model has not got (Assemblies.names_in, Names.free_name): a
## second Guard is "Guard 2", so the two stay two figures in the file and in
## a selection.
func unused_group(wanted: String) -> String:
	return Names.free_name(wanted.strip_edges(), Assemblies.names_in(world), false, "Minifig")


## The bricks of the figure a brick belongs to, or nothing when it is not
## part of one: the bricks of the innermost copy round it that is a figure
## (Assemblies.path_of). By its group, the outermost copy's name, X over a
## driver lifted the whole car, and every copy of the car placed twice, and
## put it down seated by the driver's feet (figreview2 N1).
func figure_of(brick_id: int) -> PackedInt64Array:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or brick.group.is_empty():
		return PackedInt64Array()
	var path: String = Assemblies.path_of(brick)
	var within: Array = []
	for other: BrickWorld.Brick in world.bricks():
		if other.group == brick.group:
			within.append(other)
	while not path.is_empty():
		var members: Array = within.filter(func(other: BrickWorld.Brick) -> bool:
			return Assemblies.within(Assemblies.path_of(other), path))
		if Minifig.is_figure(members, library):
			var ids := PackedInt64Array()
			for other: BrickWorld.Brick in members:
				ids.append(other.id)
			return ids
		path = Assemblies.parent_of(path)
	return PackedInt64Array()


func _place_figure() -> int:
	# A figure lifted off the model is moved: its parts in hand, each still
	# in its own step, sub-model and line of the file, put down where the
	# ghost is (_put_hand_down), the parts of it a step has not put on with
	# it. One move to undo, whatever was done while it was in hand.
	if holds_lifted_figure():
		var moves: Dictionary = {}
		var later: int = 0
		# Put down where it was lifted from, each part goes back to the very
		# place it had, not one worked out again from the figure's frame.
		var home: bool = _ghost_at_home()
		for brick_id: int in _figure_parts:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			var to: Transform3D = (_hand[brick_id]["at"] as Transform3D) if home and _hand.has(brick_id) \
				else _ghost_transform * (_figure_parts[brick_id] as Transform3D)
			moves[brick_id] = {"at": to, "boxes": boxes_for(library.mesh_for(brick.part_id), to)}
			if is_ahead(brick_id):
				later += 1
		var first: int = int(_figure_parts.keys()[0])
		var steps: Array = _put_hand_down(moves)
		if steps.is_empty():
			return 0
		riding_later = later
		# None of it put down where the timeline shows it (its steps after
		# the one showing, the timeline stepped back while it was in hand):
		# Main steps on to them and says so (figreview2 F6: it went into its
		# own later steps with no word). Some of it in view, the parts of it
		# still to come stay to come, as they were.
		put_unseen = PackedInt64Array()
		for step: Dictionary in steps:
			if is_ahead(int(step["brick"])):
				put_unseen.append(int(step["brick"]))
		if put_unseen.size() < steps.size():
			put_unseen = PackedInt64Array()
		_keep({"undo": "group", "steps": steps, "words": "moved %s" % _many(steps.size())})
		_redo.clear()
		placed.emit(first, held_figure_name)
		return first
	var ids: PackedInt64Array = put_figure(held_figure, held_figure_name, _ghost_transform)
	if ids.is_empty():
		return 0
	var steps: Array = []
	for brick_id: int in ids:
		world.get_brick(brick_id).step = _new_step(world.get_brick(brick_id))
		steps.append({"undo": "remove", "brick": brick_id})
	riding_later = 0
	_keep({"undo": "group", "steps": steps})
	_redo.clear()
	placed.emit(ids[0], held_figure_name)
	return ids[0]


## The parts of the figure in hand lifted off the model (the hand's, each
## where it stands in the figure's frame), id -> Transform3D: those on show
## and those a step has not put on yet, which go where the figure is put
## down. Empty for a figure from the maker or a copy.
var _figure_parts: Dictionary = {}
## The parts the last figure put down went to where the timeline does not
## show them ([method _place_figure]), for Main to step on to; empty when
## all of it is in view.
var put_unseen := PackedInt64Array()


## Take a whole figure into hand to move it, facing the way it faced, so the
## next click puts it down somewhere else. Its parts stay the model's where
## they stood until then ([method _take_into_hand]).
func _lift_figure(brick_id: int) -> bool:
	# One lifted before goes back where it stood first (F4).
	put_hand_back()
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
	var shown: Array = []
	var held: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var at: Transform3D = home.affine_inverse() * brick.transform
		held[brick.id] = at
		# At a step, a part of it the timeline has not put on goes with it,
		# not drawn, in its own step: X over the torso at step 3 lifted the
		# head of step 4 too, put down in step 3 (stepreview F5).
		if not is_ahead(brick.id):
			shown.append({"part": brick.part_id, "color": brick.color_code, "at": at})
	hold_figure(shown, (bricks[0] as BrickWorld.Brick).group)
	_take_into_hand(Array(members))
	_figure_parts = held
	held_rotation = BrickLattice.turns_about(BrickLattice.snap_basis(home.basis), "up")
	_hovered = 0
	return true


## Where the figure lifted off the model stood (its frame, as [member
## _figure_parts] holds its parts in it), or null with none in hand.
func _figure_home() -> Variant:
	for brick_id: int in _figure_parts:
		if _hand.has(brick_id):
			return (_hand[brick_id]["at"] as Transform3D) * (_figure_parts[brick_id] as Transform3D).affine_inverse()
	return null


## Whether the ghost stands where the figure in hand was lifted from.
func _ghost_at_home() -> bool:
	var home: Variant = _figure_home()
	return home is Transform3D and _ghost_transform.is_equal_approx(home)


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
	# Seated and asked whole, its parts still to come where they go
	# ([method _figure_whole]).
	var whole: Array = _figure_whole()
	_ghost_transform = settle_figure(target, held_rotation, hit, whole)
	_ghost_valid = figure_fits(whole, _ghost_transform)
	# Aimed back at where it was lifted from, within a stud of it and turned as
	# it was, where the studs nearest do not take it: back exactly where it
	# stood, on the studs or not, when it fits there. Sets and other programs
	# seat a driver off the studs, between two rows: put back by the studs
	# nearest, its legs went 1 LDU into the brick behind the seat and it could
	# not go back (handkeep, figreview2's car). Where the studs take it, it is
	# seated on them as anywhere (fastreview's home).
	var home: Variant = _figure_home() if not _ghost_valid else null
	if home is Transform3D and _ghost_transform.basis.is_equal_approx((home as Transform3D).basis) \
			and _ghost_transform.origin.distance_to((home as Transform3D).origin) < BrickLattice.STUD \
			and figure_fits(whole, home):
		_ghost_transform = home
		_ghost_valid = true
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
## What is in hand lifted off the model is among them, where it was lifted:
## the person's Undo puts it back when it is the newest ([method lift_newest]).
## Not with [param hand] false: what a session's undo takes back ([method undo]).
func history_words(most: int = 25, hand: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	var lift_at: int = mini(_hand_depth, _history.size()) if hand and holds_lift() else -1
	var n: int = _history.size() - 1
	while out.size() < most and (n >= 0 or lift_at >= 0):
		if lift_at >= 0 and n < lift_at:
			out.append(_hand_words())
			lift_at = -1
			continue
		out.append(_words_for(_history[n]))
		n -= 1
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
		# Each line one whole pattern with its place, never words joined: a
		# language has an entry for "placed %s" (locale/*.po), and none can
		# have one for a verb set before a count by "%s %s" (langsweep).
		if kinds.size() == 1:
			var only: String = kinds.keys()[0]
			var said: String = {"remove": "placed %s", "add": "removed %s", "recolor": "painted %s",
				"move": "moved %s"}.get(only, "changed %s")
			return said % _many(count)
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
## Undo back to [param depth] what was kept only to be taken back (a
## motion kept so the next plays from where it ends, to render them), and
## put [param redo] back as redo was before it: nothing to redo is lost to
## a render, and the steps taken back are not offered to redo.
func take_back_to(depth: int, redo: Array) -> void:
	while _history.size() > depth and undo():
		pass
	_redo.assign(redo)


func undo_steps(count: int) -> int:
	var done: int = 0
	while done < count and undo():
		done += 1
	return done
