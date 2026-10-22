## Draws a model: every brick in it, batched by the geometry it shares.
##
## A model is a list of bricks, and a brick is a part id, a colour and a
## transform. Drawing them one node each would put tens of thousands of
## [MeshInstance3D]s in the tree and spend the whole frame on culling and
## draw calls, so bricks are grouped instead: one [MultiMesh] per distinct
## (surface geometry, material class), with the colour carried per instance
## and so is the finish — chrome, glitter, rubber — in its custom data.
##
## The grouping key is the mesh hash rather than the part id, so the hundred
## part numbers that share one shape share one batch too.
##
## Rebuilds are deferred. Placing a brick marks its batch dirty and the
## rebuild happens once at the end of the frame, which is what keeps
## dropping a ten thousand piece model in from being quadratic.
class_name BrickWorld
extends Node3D

## Four variants cover every part: opaque or transparent, and culled or
## not. They differ only in render_mode, which a shader fixes at compile
## time; the shading itself is shared through plastic_body.gdshaderinc.
const SHADERS := {
	"opaque": preload("res://src/render/plastic.gdshader"),
	"opaque_two_sided": preload("res://src/render/plastic_two_sided.gdshader"),
	"trans": preload("res://src/render/plastic_trans.gdshader"),
	"trans_two_sided": preload("res://src/render/plastic_trans_two_sided.gdshader"),
}

## How a surface is drawn. Transparent plastic needs a different blend mode
## and draw order, so it cannot share a batch with opaque plastic even when
## the geometry is identical.
enum MaterialClass { OPAQUE, TRANSPARENT }


## One placed brick.
class Brick extends RefCounted:
	var id: int                       ## stable handle, unique within the world
	var part_id: String
	var color_code: int
	var transform: Transform3D
	## Kept out of the picture without being removed, so step playback
	## can walk a finished model forwards and back without rebuilding it.
	var hidden: bool = false
	## The part of the model it belongs to — an assembly a design named,
	## or a sub-model of the file it came from. Empty for most bricks.
	var group: String = ""
	## Which copy of which sub-model it was read from, for the booklet to
	## build as a sub-assembly: see LdrModel.Placement.unit.
	var unit: String = ""
	## The build step it goes on in, as the model's author set it, counted
	## from 0 within its own sub-model (its unit's, or the model's when it
	## is in none); -1 for a part nobody gave one, whose step is worked out
	## (Instructions.plan). A file's "0 STEP" lines were read and dropped,
	## so a Studio model opened and saved here lost its designer's steps.
	var step: int = -1

	func _init(brick_id: int, part: String, color: int, at: Transform3D) -> void:
		id = brick_id
		part_id = part
		color_code = color
		transform = at


## A MultiMesh and the bricks currently drawn by it.
class Batch extends RefCounted:
	var instance: MultiMeshInstance3D
	var multimesh: MultiMesh
	var brick_ids: PackedInt64Array = PackedInt64Array()
	var dirty: bool = false
	## Drawn from both sides (a surface whose winding LDraw does not
	## certify); the rest are culled to their outside.
	var two_sided: bool = false
	## Triangles in one instance, read once when the batch is made.
	var triangles: int = 0
	## While the build animation plays (see [method begin_reveal]): how
	## many of [member brick_ids] were shown from the start, and the
	## places in the build order of the rest, which follow them in order.
	var shown: int = 0
	var ranks: PackedInt64Array = PackedInt64Array()
	var revealed: int = 0
	## ...and what it was written with, slot by slot in the MultiMesh's own
	## layout (STRIDE floats: the transform's three rows, the colour, the
	## custom data), and the colour code its surface keeps: so one brick's
	## colour is changed by handing the batch this again, whole
	## ([method set_faded_in_order]), with nothing read back.
	var buffer: PackedFloat32Array = PackedFloat32Array()
	var surface_color: int = Lbm.COLOR_INHERIT
	## While x-ray is on (see [method set_xray]): the batch's ghosted
	## bricks, drawn by a MultiMesh of their own under the batch's.
	var xray: MultiMeshInstance3D = null
	## While a cut is on (see [method set_cut]): the batch's bricks the plane
	## goes through, drawn by a MultiMesh of their own with the shader that
	## cuts, and that shader's material.
	var through: MultiMeshInstance3D = null
	## While a cut is on: how far each brick written into the batch's own
	## MultiMesh reaches along the cut's normal, in the order written, which
	## is nearest first. The bricks wholly on the near side are then the
	## first so many, and moving the plane is a count changed.
	var reaches: PackedFloat32Array = PackedFloat32Array()
	## ...and how near each comes, the brick in each slot, the most any of
	## them spans along the normal, and the slots now drawn cut.
	var nears: PackedFloat32Array = PackedFloat32Array()
	var order: PackedInt64Array = PackedInt64Array()
	var extent: float = 0.0
	var cut_slots: PackedInt32Array = PackedInt32Array()
	## While a cut leaves ghosts: the same MultiMesh again, drawn faintly
	## past the plane.
	var beyond: MultiMeshInstance3D = null


var library: PartLibrary

var _bricks: Dictionary = {}         ## int id -> Brick
var _batches: Dictionary = {}        ## String key -> Batch
var _brick_batches: Dictionary = {}  ## int id -> PackedStringArray of keys
var _dirty: Dictionary = {}          ## String key -> true
var _next_id: int = 1
var _rebuild_queued: bool = false
var _materials: Dictionary = {}      ## int MaterialClass -> ShaderMaterial

## Emitted after a deferred rebuild settles, with the current totals.
signal rebuilt(brick_count: int, batch_count: int, triangle_count: int)
## Emitted when the build animation's reveal ends for any reason: played
## out, stopped, or overtaken by a change to the model.
signal reveal_ended

## Goes up by one with every change to what the model is: a brick added,
## removed, moved or recoloured, or the world cleared. Not with what is
## drawn — the build animation and the steps bar hide and show bricks
## without changing the model. Whatever is worked out from the model and
## not from the picture (whether it stands, a copy to photograph) is
## worked out again only when this has moved.
var revision: int = 0

## Whether to keep [member history]. A world that is a copy made to be
## photographed (ModelShot's) has no history worth keeping: it was cleared
## and filled again for every picture, 4,000 events a time on a set-sized
## model, kept to the cap.
var keeps_history: bool = true


## Whether the shader should linearise the instance colour itself.
##
## Forward+ renders in linear space and converts on output, so an sRGB
## palette value has to be linearised going in. The Compatibility
## renderer — which is what the web build gets, since Forward+ needs
## WebGPU — lights in sRGB space and writes the result out as it is:
## measured, a shader that writes linear 0.214 shows as #363636 there
## and as #7F7F7F under Forward+. Linearising for it would render every
## part as a darker, duller version of itself.
static func _linearise_colors() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## How strong a light should be under this renderer, given its strength
## under Forward+.
##
## Compatibility lights in sRGB space, so the same energy reads much
## brighter there: light multiplies the sRGB value itself rather than the
## linear one, and twice the light is twice the value where under
## Forward+ it is a fifth of the way to white. With the same lights as
## Forward+, dark bluish grey came out as light bluish grey and light
## bluish grey as white, which is how every grey looked on the web.
##
## And a light that casts shadows is drawn there as a pass of its own,
## which comes out several times stronger again: with the sun's shadow
## off, the lit greys dropped from L 0.74 to 0.57 at the same energy, and
## a sun at a ninth of its energy added what the whole of it adds under
## Forward+. Both factors were measured with src/dev/true_colour_probe.gd
## against what Forward+ draws: dark and light bluish grey's lit tops at
## L 0.59 and 0.78 here against 0.61 and 0.80 there, red #D32A31 against
## #DA242C, blue #3873BE against #3C78C3.
static func light_energy(forward_plus: float, casts_shadows: bool = false) -> float:
	if _linearise_colors():
		return forward_plus
	return forward_plus * (0.11 if casts_shadows else 0.6)


## A light's specular, set for Forward+, for whichever renderer is
## drawing. The energy above is cut to calibrate the diffuse, and the
## glint goes with it: at the specular that keeps a dark slope from going
## white under Forward+, transparent plastic on the web lost the glint
## that tells it from transparent rubber. Measured with
## src/dev/finish_probe.gd and src/dev/highlight_probe.gd on both: at
## one times, trans rubber stopped differing; at four, slopes went pale
## here too; at two, both hold.
static func light_specular(forward_plus: float) -> float:
	if _linearise_colors():
		return forward_plus
	return forward_plus * 2.0


## Materials are shared, not per batch: four of them cover everything, and
## sharing them lets Godot group the draws.
func _material(material_class: int, two_sided: bool) -> ShaderMaterial:
	var key: int = material_class * 2 + (1 if two_sided else 0)
	var existing: ShaderMaterial = _materials.get(key)
	if existing != null:
		return existing

	var name: String = "trans" if material_class == MaterialClass.TRANSPARENT else "opaque"
	if two_sided:
		name += "_two_sided"

	var material := ShaderMaterial.new()
	material.shader = SHADERS[name]
	material.set_shader_parameter("linearise", _linearise_colors())
	if material_class == MaterialClass.TRANSPARENT:
		# Transparent parts draw after every opaque one, whatever order the
		# batches were created in.
		material.render_priority = 1
	_materials[key] = material
	return material


## Every change to what is in the world, in order: the design history the
## timeline replays, "edits and removals included" — the owner asked for
## the build order and the order it was really made, both. Each event is
## {op: add|remove|move|paint|clear, key, ...}; a key is the brick's number
## and the generation it was placed in, because clear() starts the numbers
## again and the history must not mistake a new brick for an old one.
var history: Array = []
## The step each copy of a sub-assembly goes on in, within the sub-model
## that places it, as the author set it: unit path ("House#1/Window#3") ->
## step. Kept here and not on the bricks, so it outlives taking a copy's
## parts off and putting them back. See [member Brick.step].
var unit_steps: Dictionary = {}
## How the booklet shows each step, as its designer set it (BookletLooks):
## "<sub-model>|<step>" -> {turn, zoom, size, page, parts}, and the
## sub-models' and the booklet's own. Changed only by the history's steps.
var step_looks: Dictionary = {}
## The model's own named movements (Motions: "Open the doors"), read from
## its file and written into it. Changed only by the history's steps.
var motions: Motions = null
## The sections broken out of the model to be worked on (Sections.break_out):
## a sub-assembly's path -> {"offset": Vector3, how far it was moved, LDU;
## "home": brick id -> the Transform3D it stood at}. Changed only by the
## history's steps, so undo and redo carry it; and a file is written with
## each put back where it was ([method home_of]), so a save never keeps a
## section where it was pulled out to.
var broken_out: Dictionary = {}
var _generation: int = 0
## Enough for a long session's designs; past it the oldest go.
const HISTORY_MOST := 60000
## Bricks that are drawn and are not in the model: the timeline's history
## putting back what was taken out. Left out of bricks(), brick_count(),
## get_brick() and the bounds, so nothing that reads the model — a save,
## the autosave, the assistant over the connector, a pick — can take one
## for a brick. They were plain bricks at first, and a save made while the
## history was open would have written every one of them into the file.
var _ghosts: Dictionary = {}  ## int id -> true


func _note(event: Dictionary) -> void:
	revision += 1
	if not keeps_history:
		return
	if event.has("id"):
		event["key"] = key_of(int(event["id"]))
	history.append(event)
	if history.size() > HISTORY_MOST:
		history = history.slice(history.size() - HISTORY_MOST * 9 / 10)


## How many times the world has been cleared: what was placed in one
## generation is never put down in the next.
func generation() -> int:
	return _generation


## A brick's number as the history names it: with its generation.
func key_of(brick_id: int) -> String:
	return "%d:%d" % [_generation, brick_id]


## Place a brick. Returns its id, or 0 if the part has no geometry.
##
## [param as_id] puts a brick taken off back under the number it had
## (Builder's undo and redo), when that number is free: numbers are never
## handed out twice in a world, so it is unless the brick is back already.
## Back under a new one, every holder of the old went stale: a session's
## next edit by the number it was told found no brick, and a reject of the
## surface pass's pieces said they were off while they stood.
func add_brick(part_id: String, color_code: int, at: Transform3D, as_id: int = 0) -> int:
	var brick_id: int = _place(part_id, color_code, at, as_id)
	if brick_id != 0:
		_note({"op": "add", "id": brick_id, "part": _bricks[brick_id].part_id,
			"colour": color_code, "at": _bricks[brick_id].transform})
	return brick_id


## Draw a brick that is not in the model, and is not a change to it: see
## _ghosts. Returns its id, or 0 if the part has no geometry.
func add_ghost(part_id: String, color_code: int, at: Transform3D) -> int:
	var brick_id: int = _place(part_id, color_code, at)
	if brick_id != 0:
		_ghosts[brick_id] = true
	return brick_id


## Stop drawing every ghost.
func clear_ghosts() -> void:
	for brick_id: int in _ghosts:
		_unplace(brick_id)
	_ghosts.clear()


func _place(part_id: String, color_code: int, at: Transform3D, as_id: int = 0) -> int:
	if library == null:
		push_error("brick world: no part library set")
		return 0
	# Whatever the number means today.
	#
	# Here rather than at each caller, because every placement comes
	# through this door — a design, an import, a hand-placed brick, an
	# undo. A retired number renders correctly, since its stub is a
	# reference to the part that replaced it, so the model looks right
	# and is wrong underneath: the parts list offers "~Moved to 3023b"
	# where a name should be, and so does the booklet.
	#
	# And the new part goes where the stub puts it, which for 68 stubs is
	# turned or shifted (PartLibrary.moved_by), and is drawn as itself. Put
	# where the stub stood, a file's 3139 tyres were 3139b turned across
	# their own axles: drawn right, by the stub's geometry, and checked,
	# read back and saved a quarter turn wrong.
	var real: String = library.resolve(part_id)
	var by: Transform3D = library.moved_by(part_id)
	var drawn_as: String = real
	var part: Lbm.PartMesh = library.mesh_for(real)
	if part == null and real != part_id and by == Transform3D.IDENTITY:
		# The stub's geometry is the new part's, where it is to hand first.
		drawn_as = part_id
		part = library.mesh_for(part_id)
	if part == null:
		return 0
	var number: int = as_id if as_id > 0 and as_id < _next_id and not _bricks.has(as_id) \
		else _next_id
	var brick := Brick.new(number, real, color_code, at * by)
	if number == _next_id:
		_next_id += 1
	_bricks[brick.id] = brick

	var keys := PackedStringArray()
	var info: PartLibrary.PartInfo = library.parts[drawn_as]
	for surface_index: int in part.surface_count():
		var key: String = _batch_key(info.mesh_hash, surface_index, part, color_code)
		var batch: Batch = _batches.get(key)
		if batch == null:
			batch = _create_batch(key, part, surface_index, color_code)
			_batches[key] = batch
		_touching(batch)
		batch.brick_ids.append(brick.id)
		keys.append(key)
		_mark_dirty(key)

	_brick_batches[brick.id] = keys
	return brick.id


func remove_brick(brick_id: int) -> bool:
	if not _bricks.has(brick_id) or _ghosts.has(brick_id):
		return false
	_unplace(brick_id)
	_note({"op": "remove", "id": brick_id})
	return true


func _unplace(brick_id: int) -> void:
	for key: String in _brick_batches.get(brick_id, PackedStringArray()):
		var batch: Batch = _batches.get(key)
		if batch == null:
			continue
		_touching(batch)
		var at: int = batch.brick_ids.find(brick_id)
		if at >= 0:
			batch.brick_ids.remove_at(at)
		_mark_dirty(key)
	_brick_batches.erase(brick_id)
	_bricks.erase(brick_id)
	_spans.erase(brick_id)
	_drawn.erase(brick_id)


func move_brick(brick_id: int, to: Transform3D) -> bool:
	var brick: Brick = get_brick(brick_id)
	if brick == null:
		return false
	_touching_brick(brick_id)
	brick.transform = to
	_spans.erase(brick_id)
	for key: String in _brick_batches.get(brick_id, PackedStringArray()):
		_mark_dirty(key)
	_note({"op": "move", "id": brick_id, "at": to})
	return true


## Change a brick's colour, keeping the brick.
##
## A colour change can move a brick between the opaque and transparent
## batches, so the drawing side really is a remove and re-add. What must
## not change is the id: everything outside this file refers to a brick
## by it — the collision lattice, the undo history, which bricks the
## assistant placed, which are scenery.
##
## It did renumber, and the damage was quiet. The lattice went on
## reserving space for an id that no longer existed while the brick that
## replaced it occupied nothing, so parts would pass straight through a
## recoloured brick and undo had nothing to put back.
func recolor_brick(brick_id: int, color_code: int) -> bool:
	var brick: Brick = get_brick(brick_id)
	if brick == null or brick.color_code == color_code:
		return false
	_touching_brick(brick_id)

	# Out of its old batches, into the ones for the new colour, under the
	# same id throughout.
	for key: String in _brick_batches.get(brick_id, PackedStringArray()):
		var batch: Batch = _batches.get(key)
		if batch == null:
			continue
		var slot: int = batch.brick_ids.find(brick_id)
		if slot >= 0:
			batch.brick_ids.remove_at(slot)
		_mark_dirty(key)

	brick.color_code = color_code

	var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
	var info: PartLibrary.PartInfo = library.parts[brick.part_id]
	var keys := PackedStringArray()
	for surface_index: int in part.surface_count():
		var key: String = _batch_key(
			info.mesh_hash, surface_index, part, color_code)
		var batch: Batch = _batches.get(key)
		if batch == null:
			batch = _create_batch(key, part, surface_index, color_code)
			_batches[key] = batch
		_touching(batch)
		batch.brick_ids.append(brick_id)
		keys.append(key)
		_mark_dirty(key)
	_brick_batches[brick_id] = keys
	# Drawn with everything else at the end of the frame. It was drawn here
	# and then, so a restyle recolouring four hundred bricks rebuilt the
	# same few batches four hundred times over.
	_note({"op": "paint", "id": brick_id, "colour": color_code})
	return true


func clear() -> void:
	_stop_reveal()
	for key: String in _batches:
		var batch: Batch = _batches[key]
		batch.instance.queue_free()
	_batches.clear()
	_bricks.clear()
	_brick_batches.clear()
	_dirty.clear()
	_ghosts.clear()
	# Numbers start again, so x-ray's would name the next model's bricks.
	_xray.clear()
	_faded.clear()
	_tinted.clear()
	_spans.clear()
	_drawn.clear()
	_next_id = 1
	unit_steps.clear()
	step_looks.clear()
	motions = null
	broken_out.clear()
	_note({"op": "clear"})
	_generation += 1


## Show only these bricks, hiding the rest. An empty set shows all of
## them again, which is what ends playback.
func show_only(visible_ids: Dictionary) -> void:
	_stop_reveal()
	var everything: bool = visible_ids.is_empty()
	var changed: bool = false
	# Marked here and rebuilt now, not marked a call a key with a rebuild
	# put off to the frame's end as well: the timeline's first step hides
	# all of Orthanc but a few parts, and that was 20 ms of the desktop's
	# frame in calls alone.
	for brick: Brick in _bricks.values():
		var hide: bool = not (everything or visible_ids.has(brick.id))
		if brick.hidden == hide:
			continue
		brick.hidden = hide
		changed = true
		for key: String in _brick_batches.get(brick.id, NO_KEYS):
			_dirty[key] = true
	if changed:
		_flush()


var NO_KEYS: PackedStringArray = PackedStringArray()


## Draw only the bricks numbered below [param upto], which, in a world
## filled in one go with nothing hidden or removed, are the first ones
## added. The booklet's stage is filled in the order the booklet builds,
## so a step's picture is a prefix: each batch draws the front of its
## list, and the cost of a picture does not grow with the model. Undone
## by the next change to the world.
func show_first(upto: int) -> void:
	if _rebuild_queued:
		_flush()
	for key: String in _batches:
		var batch: Batch = _batches[key]
		# Numbers are handed out in order and appended in order, so each
		# batch's list is sorted, and its slots are in the same order.
		batch.multimesh.visible_instance_count = batch.brick_ids.bsearch(upto)


## Draw every brick with [param material] and in the colour
## [param colour_of] gives its number: a picture of which brick is which,
## for the booklet to draw its outlines from. With [param two_sided], the
## surfaces drawn from both sides take that one, so what the picture hides
## is what the plastic hides (SeenParts). Nothing about the model changes,
## and the next change to the world draws it as it was.
func draw_as(material: ShaderMaterial, colour_of: Callable,
		two_sided: ShaderMaterial = null) -> void:
	if _rebuild_queued:
		_flush()
	for key: String in _batches:
		var batch: Batch = _batches[key]
		batch.instance.material_override = two_sided if two_sided != null and batch.two_sided \
			else material
		var slot: int = 0
		for brick_id: int in batch.brick_ids:
			if _bricks[brick_id].hidden:
				continue
			batch.multimesh.set_instance_color(slot, colour_of.call(brick_id))
			slot += 1


## Give bricks other colours where they are drawn, without moving them in
## their batches: brick id -> LDraw code. recolor_brick takes a brick out of
## its batch and puts it at the end, which changes the order the batch is
## drawn in, and where two faces lie in one plane the order decides which
## shows. A picture before and after (SeenParts.pictures) wants only the
## colours to change. Colours of another material class are left alone.
func repaint_in_place(changes: Dictionary) -> void:
	for brick_id: int in changes:
		var brick: Brick = _bricks.get(brick_id)
		if brick == null:
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var code: int = int(changes[brick_id])
		var same_class: bool = true
		for surface_index: int in part.surface_count():
			if _material_class_for(part, surface_index, code) \
					!= _material_class_for(part, surface_index, brick.color_code):
				same_class = false
		if not same_class:
			continue
		brick.color_code = code
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			_mark_dirty(key)
	_flush()


## The instances that draw see-through plastic, glass and the like: what
## SeenParts leaves out, because a part behind a window is seen.
func see_through_instances() -> Array[MultiMeshInstance3D]:
	if _rebuild_queued:
		_flush()
	var out: Array[MultiMeshInstance3D] = []
	for key: String in _batches:
		if key.get_slice(":", 2).to_int() == MaterialClass.TRANSPARENT:
			out.append((_batches[key] as Batch).instance)
	return out


func brick_count() -> int:
	return _bricks.size() - _ghosts.size()


func get_brick(brick_id: int) -> Brick:
	if _ghosts.has(brick_id):
		return null
	return _bricks.get(brick_id)


func bricks() -> Array:
	if _ghosts.is_empty():
		return _bricks.values()
	var standing: Array = []
	for brick_id: int in _bricks:
		if not _ghosts.has(brick_id):
			standing.append(_bricks[brick_id])
	return standing


## The model's bricks, copied into a world of their own that draws nothing
## and is in no tree, to be read on another thread while this one goes on
## changing. The caller frees it.
func copy_for_reading() -> BrickWorld:
	var copy := BrickWorld.new()
	copy.library = library
	copy.keeps_history = false
	for brick_id: int in _bricks:
		if _ghosts.has(brick_id):
			continue
		var brick: Brick = _bricks[brick_id]
		var twin := Brick.new(brick.id, brick.part_id, brick.color_code,
			brick.transform)
		twin.group = brick.group
		copy._bricks[brick_id] = twin
	copy._next_id = _next_id
	return copy


## The model's bricks where they stand in the model as built ([method
## home_of]), each with its sub-assembly and step: what a file is written
## from while a section is broken out (ModelStore), sub-models' frames and
## all; with [param at_home] false, each where it stands, for a worker to
## read (Sections). Draws nothing and is in no tree; the caller frees it.
func copy_at_home(at_home: bool = true) -> BrickWorld:
	var copy := BrickWorld.new()
	copy.library = library
	copy.keeps_history = false
	copy.unit_steps = unit_steps.duplicate()
	copy.step_looks = step_looks.duplicate(true)
	copy.motions = motions
	for brick_id: int in _bricks:
		if _ghosts.has(brick_id):
			continue
		var brick: Brick = _bricks[brick_id]
		var twin := Brick.new(brick.id, brick.part_id, brick.color_code,
			home_of(brick) if at_home else brick.transform)
		twin.group = brick.group
		twin.unit = brick.unit
		twin.step = brick.step
		twin.hidden = brick.hidden
		copy._bricks[brick_id] = twin
	copy._next_id = _next_id
	return copy


## A brick written into a world of that kind, which draws nothing and keeps
## no history: a model that is not on the baseplate, to be measured and
## photographed (ModelShot reads a world's bricks and nothing else). A
## sketch is one (Assistant._hold_sketch). Its id, or 0 with no such part.
func add_unseen(part_id: String, color_code: int, at: Transform3D) -> int:
	if library == null or not library.parts.has(part_id):
		return 0
	var brick := Brick.new(_next_id, library.resolve(part_id), color_code,
		at * library.moved_by(part_id))
	_bricks[brick.id] = brick
	_next_id += 1
	return brick.id


## The bounding box of everything placed, in LDU.
func model_bounds() -> AABB:
	var result := AABB()
	var first: bool = true
	for brick_id: int in _bricks:
		if _ghosts.has(brick_id):
			continue
		var brick: Brick = _bricks[brick_id]
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info == null:
			continue
		var box: AABB = brick.transform * info.bounds
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


## How these bricks (id -> anything) are drawn, for the selection's outline
## (SelectionOutline) to draw them again: [the MultiMeshes of every batch
## all of whose bricks are among them, the world's own, so nothing is copied
## and they follow the world; surface mesh -> the places of the rest, a
## brick at a time; round all of them; how many triangles all that is].
## Hidden bricks are left out.
##
## All of Orthanc selected was 9,429 bricks written one at a time into
## MultiMeshes of the outline's own, again at every rebuild of the world.
func drawn_as(bricks: Dictionary) -> Array:
	var taken: Dictionary = {}  ## batch key -> the transforms of its bricks among them
	var bounds := AABB()
	var any: bool = false
	for brick_id: int in bricks:
		var brick: Brick = _bricks.get(brick_id)
		if brick == null or brick.hidden or _ghosts.has(brick_id):
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null:
			var box: AABB = drawn_at(brick) * info.bounds
			bounds = bounds.merge(box) if any else box
			any = true
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			var places: Array = taken.get(key, [])
			if places.is_empty():
				taken[key] = places
			places.append(drawn_at(brick))
	var whole: Array[MultiMesh] = []
	var loose: Dictionary = {}
	var triangles: int = 0
	for key: String in taken:
		var batch: Batch = _batches.get(key)
		if batch == null:
			continue
		var places: Array = taken[key]
		triangles += batch.triangles * places.size()
		if places.size() == batch.brick_ids.size():
			whole.append(batch.multimesh)
			# What a cut goes through, and what x-ray sees through, are
			# drawn by MultiMeshes of their own.
			for twin: MultiMeshInstance3D in [batch.through, batch.xray]:
				if twin != null:
					whole.append(twin.multimesh)
			continue
		var mesh: Mesh = batch.multimesh.mesh
		if loose.has(mesh):
			(loose[mesh] as Array).append_array(places)
		else:
			loose[mesh] = places
	return [whole, loose, bounds, triangles]


# -- batching ------------------------------------------------------------


func _batch_key(
	mesh_hash: String, surface_index: int, part: Lbm.PartMesh, color_code: int
) -> String:
	var material_class: int = _material_class_for(part, surface_index, color_code)
	return "%s:%d:%d" % [mesh_hash, surface_index, material_class]


func _material_class_for(
	part: Lbm.PartMesh, surface_index: int, color_code: int
) -> int:
	var surface_color: int = part.surface_colors[surface_index]
	var effective: int = color_code if surface_color == Lbm.COLOR_INHERIT else surface_color
	var color: PartLibrary.BrickColor = library.color(effective)
	return MaterialClass.TRANSPARENT if color.is_transparent() else MaterialClass.OPAQUE


func _create_batch(
	key: String, part: Lbm.PartMesh, surface_index: int, color_code: int
) -> Batch:
	var batch := Batch.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# Per-instance colour is the whole point: one copy of the geometry
	# serves every colour the part was ever moulded in.
	batch.multimesh.use_colors = true
	# And per-instance finish beside it, so chrome, glitter and rubber
	# share the batch and the draw call of the plain plastic: a material
	# per finish would multiply the batches by the finishes in use.
	# Always on, rather than only for batches that hold a finish: the
	# format is fixed before the batch has any bricks, and a batch that
	# carried none would have the shader read whatever the renderer
	# supplies for missing custom data as a finish.
	batch.multimesh.use_custom_data = true
	batch.multimesh.mesh = part.surfaces[surface_index]

	batch.instance = MultiMeshInstance3D.new()
	batch.instance.multimesh = batch.multimesh
	batch.instance.name = key
	var material_class: int = _material_class_for(part, surface_index, color_code)
	var two_sided: bool = part.surface_two_sided[surface_index] == 1
	batch.two_sided = two_sided
	# A copy per batch, carrying the part's box, so the shader can draw
	# the seam where this part meets the next: see plastic_body. Every
	# surface of a part gets the whole part's box, which is what an edge
	# of the part is measured against.
	var material: ShaderMaterial = _material(material_class, two_sided).duplicate()
	material.set_shader_parameter("part_box_min", part.bounds.position)
	material.set_shader_parameter("part_box_max", part.bounds.end)
	# A print drawn in the app is a picture on its surface (PartPrints).
	if part.prints.has(surface_index) and material_class == MaterialClass.OPAQUE:
		material = PartPrints.material_for(material, part.prints[surface_index], two_sided)
	batch.instance.material_override = material
	add_child(batch.instance)
	batch.triangles = _triangles_of(part.surfaces[surface_index])
	return batch


func _mark_dirty(key: String) -> void:
	_dirty[key] = true
	if not _rebuild_queued:
		_rebuild_queued = true
		# One rebuild per frame however many bricks were touched.
		_flush_when_due.call_deferred()


## What rewriting batches has cost, ms, and how many, since a probe timing
## a drag's frames last took them.
var rebuilt_ms: float = 0.0
var rebuilt_batches: int = 0


## Whether a big rebuild may be spread over frames (FramePace), batches
## not yet rebuilt drawing as they were a frame or two longer. The world on
## screen does: writing every batch of the owner's 4,242-part Falcon Heavy,
## once it was down, was most of a second of a browser's one thread. A copy
## made to be photographed does not, because its picture must be whole.
var rebuilds_in_slices: bool = false


## The deferred rebuild: all of it, or a slice a frame.
func _flush_when_due() -> void:
	if not rebuilds_in_slices:
		_flush()
		return
	_rebuild_queued = false
	if _drawing_held > 0:
		return
	var pace := FramePace.new()
	for key: String in _dirty.keys():
		_dirty.erase(key)
		var batch: Batch = _batches.get(key)
		if batch != null:
			_rebuild(batch, key)
		if pace.due() and not _dirty.is_empty():
			_rebuild_queued = true
			if not get_tree().process_frame.is_connected(_flush_when_due):
				get_tree().process_frame.connect(_flush_when_due, CONNECT_ONE_SHOT)
			return
	_flush()


## Holding what is drawn: changes are made but not drawn until the hold is
## released, so a design put down over several frames (Assistant._apply,
## gradually) appears whole rather than a slice at a time.
var _drawing_held: int = 0


func hold_drawing() -> void:
	_drawing_held += 1


func release_drawing() -> void:
	_drawing_held = maxi(0, _drawing_held - 1)
	if _drawing_held == 0 and not _dirty.is_empty() and not _rebuild_queued:
		_rebuild_queued = true
		_flush_when_due.call_deferred()


func is_drawing_held() -> bool:
	return _drawing_held > 0


func _flush() -> void:
	_rebuild_queued = false
	if _drawing_held > 0:
		return
	var triangles: int = 0
	for key: String in _dirty:
		var batch: Batch = _batches.get(key)
		if batch == null:
			continue
		_rebuild(batch, key)
	_dirty.clear()

	var live: int = 0
	for key: String in _batches:
		var batch: Batch = _batches[key]
		if batch.multimesh.instance_count > 0:
			live += 1
			triangles += batch.triangles * batch.multimesh.instance_count
	rebuilt.emit(brick_count(), live, triangles)


func _rebuild(batch: Batch, key: String) -> void:
	var began: int = Time.get_ticks_usec()
	_rebuild_batch(batch, key)
	rebuilt_ms += float(Time.get_ticks_usec() - began) / 1000.0
	rebuilt_batches += 1


func _rebuild_batch(batch: Batch, key: String) -> void:
	# Written as usual, a batch laid out for a reveal would draw the wrong
	# bricks at the next count: whatever writes it ends the reveal first.
	if not batch.ranks.is_empty():
		_stop_reveal()
	var count: int = batch.brick_ids.size()
	_fresh_slots(batch, count)
	if count == 0:
		batch.multimesh.visible_instance_count = 0
		_write_xray(batch, [], Lbm.COLOR_INHERIT)
		_write_through(batch, [], Lbm.COLOR_INHERIT)
		return

	var surface_index: int = key.split(":")[1].to_int()
	# One mesh per batch — the key is the mesh's hash — so one answer to
	# whether this surface follows the brick's colour or keeps its own.
	var surface_color: int = _surface_colour(batch, surface_index)
	# Hidden bricks are packed off the end rather than left as gaps: a
	# MultiMesh draws its first visible_instance_count slots, so the ones
	# to draw have to be the ones at the front. X-ray's ghosts go to a
	# MultiMesh of their own, drawn see-through; under a cut, the bricks
	# the plane goes through to one drawn with the shader that cuts, and
	# those wholly past it nowhere (see set_cut).
	var slot: int = 0
	var ghosts: Array = []
	var solid: Array = []
	for brick_id: int in batch.brick_ids:
		var brick: Brick = _bricks[brick_id]
		if brick.hidden:
			continue
		if _xray.has(brick_id):
			ghosts.append(brick)
			continue
		if _cut_on:
			solid.append(brick)
			continue
		_write_instance(batch, slot, brick, surface_color)
		slot += 1
	if _cut_on:
		slot = _write_cut(batch, solid, surface_color)
	else:
		batch.reaches = PackedFloat32Array()
		batch.cut_slots = PackedInt32Array()
		_write_through(batch, [], surface_color)
	_write_xray(batch, ghosts, surface_color)

	# Kept in step with instance_count explicitly: raising one does not
	# raise the other, and a batch that grows would otherwise keep
	# drawing only as many instances as it had before.
	batch.multimesh.visible_instance_count = slot

	# Give the instance bounds that cover where the bricks actually are.
	#
	# A MultiMesh derives its own AABB from the instance transforms, but
	# the per-surface meshes here carry a custom_aabb (set when the part
	# is loaded, to save a pass over every vertex), and a custom AABB on
	# the mesh is what the MultiMesh measures from. The result is bounds
	# around the origin rather than around the model, so a batch whose
	# bricks sit away from the origin is frustum-culled and never drawn —
	# which looks exactly like the bricks never having been added.
	var bounds := AABB()
	var first: bool = true
	for brick_id: int in batch.brick_ids:
		var brick: Brick = _bricks[brick_id]
		if brick.hidden:
			continue
		var box: AABB = drawn_at(brick) * batch.multimesh.mesh.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	_set_bounds(batch, bounds)


## A batch's slots let go and taken again, even at the same count, so what
## is written next goes to a new instance buffer.
##
## In a browser, instance data written over in place was never drawn: a
## brick turned, mirrored or nudged stayed on screen where it had been
## while its outline moved on, until something added or took off a brick
## of its batch — a new count, and so a new buffer. Desktop OpenGL drew the
## same writes. A buffer taken fresh is zeroed, not read back, so this
## costs no wait on the GPU. tools/web/redraw_check.mjs is the check.
func _fresh_slots(batch: Batch, count: int) -> void:
	batch.multimesh.instance_count = 0
	batch.multimesh.instance_count = count


## One brick into one slot of a batch.
func _write_instance(batch: Batch, slot: int, brick: Brick,
		surface_color: int, into: MultiMesh = null) -> void:
	var multimesh: MultiMesh = into if into != null else batch.multimesh
	multimesh.set_instance_transform(slot, drawn_at(brick))
	var color: PartLibrary.BrickColor = _brick_colour(brick, surface_color)
	multimesh.set_instance_color(slot, _shown_colour(brick, color))
	multimesh.set_instance_custom_data(slot, color.instance_custom)


## The colour a brick's surface is drawn in: a surface moulded in a fixed
## colour ignores the brick's colour; that is what keeps a printed face
## black on a yellow head.
func _brick_colour(brick: Brick, surface_color: int) -> PartLibrary.BrickColor:
	return library.color(brick.color_code if surface_color == Lbm.COLOR_INHERIT else surface_color)


## ...as it is drawn now: faded, tinted, or as it is.
func _shown_colour(brick: Brick, color: PartLibrary.BrickColor) -> Color:
	var shown: Color = faded(color.shown) if _faded.has(brick.id) else color.shown
	if _tinted.has(brick.id):
		shown = Color(shown.lerp(_tinted[brick.id], TINTING), shown.a)
	return shown


## Floats a slot of a MultiMesh's buffer: a Transform3D's three rows, a
## colour and the custom data.
const STRIDE := 20


## One brick into one slot of a buffer laid out as the MultiMesh lays out
## its own (MultiMesh.buffer): what _write_instance writes, call by call.
func _pack(buffer: PackedFloat32Array, slot: int, at: Transform3D, brick: Brick,
		surface_color: int) -> void:
	var o: int = slot * STRIDE
	var b: Basis = at.basis
	buffer[o] = b.x.x
	buffer[o + 1] = b.y.x
	buffer[o + 2] = b.z.x
	buffer[o + 3] = at.origin.x
	buffer[o + 4] = b.x.y
	buffer[o + 5] = b.y.y
	buffer[o + 6] = b.z.y
	buffer[o + 7] = at.origin.y
	buffer[o + 8] = b.x.z
	buffer[o + 9] = b.y.z
	buffer[o + 10] = b.z.z
	buffer[o + 11] = at.origin.z
	var color: PartLibrary.BrickColor = _brick_colour(brick, surface_color)
	_pack_colour(buffer, o, _shown_colour(brick, color))
	var custom: Color = color.instance_custom
	buffer[o + 16] = custom.r
	buffer[o + 17] = custom.g
	buffer[o + 18] = custom.b
	buffer[o + 19] = custom.a


static func _pack_colour(buffer: PackedFloat32Array, o: int, colour: Color) -> void:
	buffer[o + 12] = colour.r
	buffer[o + 13] = colour.g
	buffer[o + 14] = colour.b
	buffer[o + 15] = colour.a


func _surface_colour(batch: Batch, surface_index: int) -> int:
	if batch.brick_ids.is_empty():
		return Lbm.COLOR_INHERIT
	var part: Lbm.PartMesh = library.mesh_for(_bricks[batch.brick_ids[0]].part_id)
	return part.surface_colors[surface_index] if part != null else Lbm.COLOR_INHERIT


## Triangles in a part's surface, from the index count the mesh keeps.
##
## Not from its arrays: those are read back off the graphics card, on the
## web a synchronous getBufferSubData that waits for the card to finish
## everything queued. Drawn in software that is the frame before, and it
## came once for every new batch: a design of twenty shapes going down
## held the page 650 to 1,750 ms a frame, frame after frame, while Claude's
## check_design ran (tools/web/freeze_check.mjs, 2026-10-11). Cached per
## mesh it still cost that the first time each part was put down.
static func _triangles_of(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_array_index_len(0) / 3


# -- the build animation ---------------------------------------------------
#
# Watching a model go up is the bricks to come hidden, then shown a few at a
# time. Done with show_only, every step walked every brick in the model and
# rebuilt every batch it touched — on the 4,242-part Falcon Heavy that froze
# the page (src/render/build_playback.gd has the numbers). Instead each batch
# is written once with its bricks in the order they are built, so the ones on
# show are always the first so many, and a step is only a count raised.


## The bricks of [member _reveal_order] that are still to come, by id ->
## their place in it.
var _reveal_rank: Dictionary = {}
var _reveal_order: PackedInt64Array = PackedInt64Array()
## The batches holding bricks still to come.
var _revealing: Array[Batch] = []
## The order the timeline is showing by ([method reveal_upto]), by the key
## it gave it; -1 for none, or for the build animation's.
var _reveal_key: int = -1


func is_revealing() -> bool:
	return not _reveal_order.is_empty()


## Hide [param order]'s bricks, to be shown in that order by
## [method reveal_through]. Every other brick stays on show.
func begin_reveal(order: PackedInt64Array) -> void:
	# From a world with everything on show, so the order written below is
	# the whole truth about each batch. A batch written in order is written
	# whole, so one waiting to be rebuilt is not rebuilt first as well: the
	# rest are, at the end.
	show_only({})
	_reveal_key = -1
	_reveal_order = PackedInt64Array()
	for brick_id: int in order:
		var brick: Brick = get_brick(brick_id)
		if brick == null or _reveal_rank.has(brick_id):
			continue
		_reveal_rank[brick_id] = _reveal_order.size()
		_reveal_order.append(brick_id)
		brick.hidden = true
	if _reveal_order.is_empty():
		if not _dirty.is_empty():
			_flush()
		return
	_write_revealing()


## The timeline's way of showing a model a step at a time: the first
## [param count] bricks of [param order] on show and the rest of it hidden,
## everything else as it was; [param key] names the order, a new one each
## time it is worked out. The first time for an order every batch is written
## in that order, as [method begin_reveal] writes it; after that a step,
## forwards or back, is a count raised or lowered in each batch holding
## bricks of the order, and nothing is written again. It was show_only,
## every brick asked whether it was on show and every batch that held one
## that changed written again whole: a step of a 5,025-part set was most of
## a tenth of a second here, more in a browser.
##
## False, with nothing changed, under a cut or x-ray, which the writing in
## order does not draw: the caller shows the step by [method show_only].
## Anything that changes a batch of the order ends it ([signal
## reveal_ended]), everything on show, and the caller shows the step again.
func reveal_upto(order: PackedInt64Array, count: int, key: int) -> bool:
	if _cut_on or not _xray.is_empty():
		return false
	if key != _reveal_key or _reveal_order.is_empty():
		show_only({})
		# Ranked by the place in the order, gaps and all, so a count of the
		# order is a count of each batch's ranks.
		_reveal_order = order
		for n: int in order.size():
			var brick: Brick = get_brick(order[n])
			if brick == null or _reveal_rank.has(order[n]):
				continue
			_reveal_rank[order[n]] = n
			brick.hidden = true
		_write_revealing()
		_reveal_key = key
	for batch: Batch in _revealing:
		var upto: int = batch.ranks.bsearch(count)
		if upto == batch.revealed:
			continue
		for n: int in range(mini(upto, batch.revealed), maxi(upto, batch.revealed)):
			var brick: Brick = _bricks.get(_reveal_order[batch.ranks[n]])
			if brick != null:
				brick.hidden = n >= upto
		batch.revealed = upto
		batch.multimesh.visible_instance_count = batch.shown + upto
	return true


## Every batch holding bricks of [member _reveal_order] written in its
## order, those not of it first, and only those on show drawn.
func _write_revealing() -> void:
	if _reveal_rank.is_empty():
		_reveal_order = PackedInt64Array()
		if not _dirty.is_empty():
			_flush()
		return
	for key: String in _batches:
		var batch: Batch = _batches[key]
		var shown := PackedInt64Array()
		var ranks := PackedInt64Array()
		for brick_id: int in batch.brick_ids:
			var rank: Variant = _reveal_rank.get(brick_id)
			if rank == null:
				shown.append(brick_id)
			else:
				ranks.append(int(rank))
		if ranks.is_empty():
			continue
		ranks.sort()
		var ordered := shown.duplicate()
		for rank: int in ranks:
			ordered.append(_reveal_order[rank])
		batch.brick_ids = ordered
		batch.shown = shown.size()
		batch.ranks = ranks
		batch.revealed = 0
		_write_in_order(batch, key)
		_dirty.erase(key)
		_revealing.append(batch)
	if not _dirty.is_empty():
		_flush()


## Show every brick up to [param rank] in the order begun with: a count
## raised per batch, nothing rewritten.
func reveal_through(rank: int) -> void:
	for batch: Batch in _revealing:
		var upto: int = batch.ranks.bsearch(rank + 1)
		if upto == batch.revealed:
			continue
		for n: int in range(batch.revealed, upto):
			var brick: Brick = _bricks.get(_reveal_order[batch.ranks[n]])
			if brick != null:
				brick.hidden = false
		batch.revealed = upto
		batch.multimesh.visible_instance_count = batch.shown + upto
	if rank >= _reveal_order.size() - 1:
		_stop_reveal()


## Everything on show again, however far the reveal had got.
func end_reveal() -> void:
	_stop_reveal()


## A change to a batch whose bricks are being revealed in order: the order
## would no longer hold, so the reveal ends first, everything shown. A change
## anywhere else leaves it playing — the ground laid wider under a design
## that outgrew it, the moment it was built, ended every big one at once.
func _touching(batch: Batch) -> void:
	if not _reveal_order.is_empty() and _revealing.has(batch):
		_stop_reveal()


func _touching_brick(brick_id: int) -> void:
	if _reveal_order.is_empty():
		return
	for key: String in _brick_batches.get(brick_id, PackedStringArray()):
		var batch: Batch = _batches.get(key)
		if batch != null:
			_touching(batch)


func _stop_reveal() -> void:
	_reveal_key = -1
	if _reveal_order.is_empty():
		return
	for batch: Batch in _revealing:
		batch.multimesh.visible_instance_count = batch.brick_ids.size()
		batch.ranks = PackedInt64Array()
		batch.shown = 0
		batch.revealed = 0
		batch.buffer = PackedFloat32Array()
	# Written whole for the reveal, x-ray's ghosts and all, and the cut not
	# made: split again.
	if not _xray.is_empty() or _cut_on:
		for key: String in _batches:
			if _revealing.has(_batches[key]):
				_mark_dirty(key)
	for brick_id: int in _reveal_rank:
		var brick: Brick = _bricks.get(brick_id)
		if brick != null:
			brick.hidden = false
	_revealing.clear()
	_reveal_rank.clear()
	_reveal_order = PackedInt64Array()
	reveal_ended.emit()


## A batch written whole, in the order of its brick_ids, hidden bricks and
## all, with only those on show drawn.
func _write_in_order(batch: Batch, key: String) -> void:
	var count: int = batch.brick_ids.size()
	_fresh_slots(batch, count)
	var surface_color: int = _surface_colour(batch, key.split(":")[1].to_int())
	# The build going up is the model whole: x-ray's ghosts are drawn solid
	# and the cut is not made until it ends (_stop_reveal splits them off
	# again).
	_write_xray(batch, [], surface_color)
	_write_through(batch, [], surface_color)
	batch.reaches = PackedFloat32Array()
	batch.cut_slots = PackedInt32Array()
	# Packed here and handed over in one call, and kept: a step of the step
	# player changes a few bricks' colours in it and hands it over again
	# (set_faded_in_order), where writing a slot in place is never drawn
	# in a browser (_fresh_slots).
	var buffer := PackedFloat32Array()
	buffer.resize(count * STRIDE)
	var bounds := AABB()
	var mesh_box: AABB = batch.multimesh.mesh.get_aabb()
	for slot: int in count:
		var brick: Brick = _bricks[batch.brick_ids[slot]]
		var at: Transform3D = drawn_at(brick)
		_pack(buffer, slot, at, brick, surface_color)
		var box: AABB = at * mesh_box
		bounds = box if slot == 0 else bounds.merge(box)
	batch.multimesh.buffer = buffer
	batch.buffer = buffer
	batch.surface_color = surface_color
	batch.multimesh.visible_instance_count = batch.shown
	# Bounds for all of them, shown or to come, so the batch is not culled
	# as it grows.
	_set_bounds(batch, bounds)


## Turn the whole model a quarter turn about its own centre.
##
## Not the same thing as orbiting the camera, which changes where you
## stand rather than which way the model faces. This is picking the build
## up off the table and putting it back down the other way round, and it
## has to keep the lattice honest: every brick moves to a cell, not to
## somewhere near one.
##
## Returns the placements so the caller can rebuild its own lattice from
## them, because the world does not own that.
func rotate_model(quarter_turns: int, keep: Dictionary = {}) -> Array:
	var turns: int = posmod(quarter_turns, 4)
	if turns == 0 or brick_count() == 0:
		return []
	_stop_reveal()
	revision += 1
	_spans.clear()

	# Turn about the centre of the footprint, snapped to the stud grid so
	# a model on the lattice stays on it.
	var box: AABB = model_bounds()
	var pivot := Vector3(
		round(box.get_center().x / BrickLattice.STUD) * BrickLattice.STUD,
		0.0,
		round(box.get_center().z / BrickLattice.STUD) * BrickLattice.STUD)
	# Snapped here, once, rather than on every result.
	#
	# Built from trig a quarter turn is a hair off exact, and four of
	# them walked a model off the grid — so the composed basis used to
	# be snapped instead. That cured the drift and flattened every part
	# that was not square to the grid to begin with. An .ldr written
	# anywhere else can carry any rotation at all and the reader parses
	# it, so one press of Q straightened every angled part in an
	# imported model, silently and with no way back but undo.
	#
	# Snapping the turn makes it exactly integer. Composing it drifts by
	# nothing, and a part at thirty degrees stays at thirty degrees.
	var turn: Basis = BrickLattice.snap_basis(
		Basis(Vector3.UP, turns * PI * 0.5))

	var moved: Array = []
	for brick_id: int in _bricks.keys():
		if keep.has(brick_id) or _ghosts.has(brick_id):
			continue
		var brick: Brick = _bricks[brick_id]
		var offset: Vector3 = brick.transform.origin - pivot
		var at := Transform3D(
			turn * brick.transform.basis, pivot + turn * offset)
		# Exact already: the turn is whole numbers and the pivot is on a
		# stud, so a part on the lattice lands on the lattice. Only the
		# float dust is taken off, to the 1/10000 LDU a file keeps.
		#
		# This used to floor every origin onto a cell, which is the
		# basis bug of the paragraph above over again for positions: a
		# part that was never on the 2 LDU lattice was moved onto it. A
		# minifigure is nine such parts — an arm 15.552 out from its
		# torso — and one press of Q moved its arms up to 2 LDU off its
		# shoulders and its hands out of its arms.
		at.origin = at.origin.snapped(Vector3.ONE * 0.0001)
		moved.append({"id": brick_id, "part": brick.part_id,
			"colour": brick.color_code, "at": at})
		brick.transform = at
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			_mark_dirty(key)
	return moved


# -- seeing inside: the cut-away and x-ray -------------------------------------
#
# Both change the picture and nothing else, as hiding does: the bricks, the
# history and whatever is worked out from them are untouched. A world made to
# be photographed — the booklet's, the assistant's — never has either, which
# is how the booklet ignores them. SeeInside (src/ui/see_inside.gd) drives
# them, and keeps the pointer's lattice in step.
#
# Both are made to be quick on a set-sized model (Orthanc, 8,785 parts).
#
# The cut sorts every brick by where it is against the plane. A brick wholly
# on the near side is drawn as if there were no cut, by its batch, with the
# plain shader and its early depth test. A brick wholly past the plane is not
# drawn. Only the bricks the plane goes through are drawn with a shader that
# cuts, from a MultiMesh of each batch's own (Batch.through). The shader that
# cuts has to discard, which loses the early depth test: given the whole of a
# tower cut through the middle, a software renderer shaded every floor under
# the eye before the depth test threw them away, and a close view of Orthanc
# took minutes a frame. Each batch's bricks are written nearest the near side
# first, so those wholly on it are the first so many: moving the plane changes
# a count, and writes again only the few bricks it went through. X-ray writes
# each batch once when it is turned on, its ghosts into a MultiMesh of their
# own beside the batch's.


const SEE_THROUGH := preload("res://src/render/see_through.gdshader")

## The cut variant of each plastic shader, by the one it replaces.
static var _to_cut: Dictionary = {}

var _cut_on: bool = false
var _cut_plane: Plane = Plane()
var _cut_ghosts: bool = false
## Each brick's reach along the cut's normal, by id: Vector2(nearest,
## furthest) of its box, measured as the plane's d is. Worked out when a
## brick is first sorted, and again after it moves.
var _spans: Dictionary = {}
## Bricks x-ray draws see-through, by id.
var _xray: Dictionary = {}
var _xray_material: ShaderMaterial = null
var _beyond_material: ShaderMaterial = null


static func _cut_variants() -> void:
	if not _to_cut.is_empty():
		return
	_to_cut = {
		SHADERS["opaque"]: preload("res://src/render/plastic_cut.gdshader"),
		SHADERS["opaque_two_sided"]: preload("res://src/render/plastic_two_sided_cut.gdshader"),
		SHADERS["trans"]: preload("res://src/render/plastic_trans_cut.gdshader"),
		SHADERS["trans_two_sided"]:
			preload("res://src/render/plastic_trans_two_sided_cut.gdshader"),
		PartPrints.PRINT_SHADERS[false]: preload("res://src/render/plastic_print_cut.gdshader"),
		PartPrints.PRINT_SHADERS[true]:
			preload("res://src/render/plastic_print_two_sided_cut.gdshader"),
	}


## Cut the picture at [param plane]: the plastic on the side its normal
## points to is not drawn, and the faces the plane cuts through are drawn as
## faces. With [param ghosts], what is cut away is left as a faint ghost of
## itself. Off with [param on] false.
func set_cut(on: bool, plane: Plane = Plane(), ghosts: bool = false) -> void:
	var was_on: bool = _cut_on
	var was: Plane = _cut_plane
	var had_ghosts: bool = _cut_ghosts
	_cut_on = on
	_cut_plane = plane
	_cut_ghosts = on and ghosts
	if on != was_on or (on and (not plane.normal.is_equal_approx(was.normal)
			or _cut_ghosts != had_ghosts)):
		# Every brick sorted afresh.
		_spans.clear()
		for key: String in _batches:
			_touching(_batches[key])
			_mark_dirty(key)
	elif on and not is_equal_approx(plane.d, was.d):
		# Moved along its normal. Each batch is in order of how far its
		# bricks reach, so those wholly on the near side are the first so
		# many: a count changed. The bricks it now goes through are found by
		# two searches, and written again only where they changed. A batch
		# waiting to be written whole is left to that.
		_stop_reveal()
		for key: String in _batches:
			var batch: Batch = _batches[key]
			if _dirty.has(key) or batch.reaches.is_empty():
				continue
			batch.multimesh.visible_instance_count = batch.reaches.bsearch(plane.d, false)
			var slots: PackedInt32Array = _cut_slots(batch)
			if slots != batch.cut_slots:
				batch.cut_slots = slots
				_write_cut_slots(batch, _surface_colour(batch, key.split(":")[1].to_int()))
	var at: Vector4 = _plane_vector()
	for key: String in _batches:
		var batch: Batch = _batches[key]
		if batch.through != null:
			(batch.through.material_override as ShaderMaterial).set_shader_parameter(
				"cut_plane", at)
	_see_through_follows()


func is_cut() -> bool:
	return _cut_on


## The plane the picture is cut at; meaningless while [method is_cut] is false.
func cut_plane() -> Plane:
	return _cut_plane


## Whether what the cut takes away is left as a ghost.
func cut_leaves_ghosts() -> bool:
	return _cut_ghosts


## Which side of the cut a brick is: -1 wholly on the near side, 1 wholly
## past the plane, 0 across it.
func _side_of_brick(brick: Brick) -> int:
	var span: Variant = _spans.get(brick.id)
	if span == null:
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var box: AABB = brick.transform * (part.bounds if part != null else AABB())
		var middle: float = _cut_plane.normal.dot(box.get_center())
		var reach: float = (box.size * 0.5).dot(_cut_plane.normal.abs())
		span = Vector2(middle - reach, middle + reach)
		_spans[brick.id] = span
	if (span as Vector2).x > _cut_plane.d:
		return 1
	if (span as Vector2).y <= _cut_plane.d:
		return -1
	return 0


## A batch's solid bricks under a cut: every one into the batch's own
## MultiMesh, nearest first along the cut's normal, of which only those
## wholly on the near side are drawn — the first so many, the count
## returned — and those the plane goes through into the MultiMesh that cuts.
func _write_cut(batch: Batch, solid: Array, surface_color: int) -> int:
	# Sorted by a packed key — the reach, to 1/128 LDU, then the brick's
	# place in the list — which sorts natively: a sort with a callable
	# took most of the time of turning a cut on.
	var keys := PackedFloat64Array()
	keys.resize(solid.size())
	for n: int in solid.size():
		_side_of_brick(solid[n])
		var reach: float = (_spans[(solid[n] as Brick).id] as Vector2).y
		keys[n] = floorf(reach * 128.0) * 1048576.0 + n
	keys.sort()
	var reaches := PackedFloat32Array()
	var nears := PackedFloat32Array()
	var order := PackedInt64Array()
	reaches.resize(solid.size())
	nears.resize(solid.size())
	order.resize(solid.size())
	var extent: float = 0.0
	for slot: int in keys.size():
		var brick: Brick = solid[int(fposmod(keys[slot], 1048576.0))]
		_write_instance(batch, slot, brick, surface_color)
		var span: Vector2 = _spans[brick.id]
		reaches[slot] = span.y
		nears[slot] = span.x
		order[slot] = brick.id
		extent = maxf(extent, span.y - span.x)
	batch.reaches = reaches
	batch.nears = nears
	batch.order = order
	batch.extent = extent
	batch.cut_slots = _cut_slots(batch)
	_write_cut_slots(batch, surface_color)
	return reaches.bsearch(_cut_plane.d, false)


## The slots of a batch's bricks the plane goes through (and, leaving ghosts,
## those past it). In order of how far they reach, those are the ones past
## the near side's count and no further than the batch's longest brick past
## the plane, so they are found without looking at the rest.
func _cut_slots(batch: Batch) -> PackedInt32Array:
	var at: float = _cut_plane.d
	var start: int = batch.reaches.bsearch(at, false)
	var stop: int = batch.reaches.size() if _cut_ghosts \
		else batch.reaches.bsearch(at + batch.extent + 0.001, false)
	var out := PackedInt32Array()
	for slot: int in range(start, stop):
		if _cut_ghosts or batch.nears[slot] <= at:
			out.append(slot)
	return out


func _write_cut_slots(batch: Batch, surface_color: int) -> void:
	var through: Array = []
	for slot: int in batch.cut_slots:
		through.append(_bricks[batch.order[slot]])
	_write_through(batch, through, surface_color)


## A batch's bricks the plane goes through, written into their own MultiMesh
## drawn with the shader that cuts, and the ghost of what the cut takes away
## from the same MultiMesh; or both let go when there are none.
func _write_through(batch: Batch, bricks: Array, surface_color: int) -> void:
	if bricks.is_empty():
		if batch.through != null:
			batch.through.queue_free()
			batch.through = null
			batch.beyond = null
		return
	if batch.through == null:
		_cut_variants()
		var made := MultiMesh.new()
		made.transform_format = MultiMesh.TRANSFORM_3D
		made.use_colors = true
		made.use_custom_data = true
		made.mesh = batch.multimesh.mesh
		batch.through = MultiMeshInstance3D.new()
		batch.through.multimesh = made
		# The batch's own material — its part's box, its print — with the
		# shader that cuts.
		var material: ShaderMaterial = (batch.instance.material_override as ShaderMaterial) \
			.duplicate()
		var cutting: Shader = _to_cut.get(material.shader)
		if cutting != null:
			material.shader = cutting
		material.set_shader_parameter("cut_plane", _plane_vector())
		batch.through.material_override = material
		batch.instance.add_child(batch.through)
	if _cut_ghosts and batch.beyond == null:
		batch.beyond = MultiMeshInstance3D.new()
		batch.beyond.multimesh = batch.through.multimesh
		batch.beyond.material_override = _see_through(true)
		batch.beyond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.through.add_child(batch.beyond)
	elif not _cut_ghosts and batch.beyond != null:
		batch.beyond.queue_free()
		batch.beyond = null
	var multimesh: MultiMesh = batch.through.multimesh
	# Fresh slots, for the reason _fresh_slots gives.
	multimesh.instance_count = 0
	multimesh.instance_count = bricks.size()
	var bounds := AABB()
	for slot: int in bricks.size():
		var brick: Brick = bricks[slot]
		_write_instance(batch, slot, brick, surface_color, multimesh)
		var box: AABB = drawn_at(brick) * multimesh.mesh.get_aabb()
		bounds = box if slot == 0 else bounds.merge(box)
	batch.through.custom_aabb = bounds
	if batch.beyond != null:
		batch.beyond.custom_aabb = bounds


func _plane_vector() -> Vector4:
	return Vector4(_cut_plane.normal.x, _cut_plane.normal.y, _cut_plane.normal.z,
		_cut_plane.d)


## Draw these bricks see-through and every other as it is, so what they
## hide can be seen; an empty set is x-ray off. Each batch with a brick
## changing sides is written again, once, at the end of the frame.
func set_xray(see_through: Dictionary) -> void:
	var changed: Dictionary = {}
	for brick_id: int in _xray:
		if not see_through.has(brick_id):
			changed[brick_id] = true
	for brick_id: int in see_through:
		if not _xray.has(brick_id):
			changed[brick_id] = true
	_xray = see_through.duplicate()
	var keys: Dictionary = {}
	for brick_id: int in changed:
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			keys[key] = true
	for key: String in keys:
		var batch: Batch = _batches.get(key)
		if batch != null:
			_touching(batch)
			_mark_dirty(key)
	_see_through_follows()


## The bricks x-ray draws see-through.
func xray_ids() -> Dictionary:
	return _xray


## Bricks drawn faded, by id: in the step player (BuildMode), what is
## already built, so the step's new parts are the ones in full colour.
##
## Washed pale and still solid, rather than x-ray's see-through ghosts. A
## ghost is a few percent of fill and an edge: drawn under a step's new
## parts it left them floating, with nothing to say what they go on. A
## booklet draws the model built so far whole; drawn pale, it is there to
## find the place by and is not what the eye lands on.
var _faded: Dictionary = {}

## How far a faded brick's colour goes towards [constant FADED_TO].
const FADING := 0.62
const FADED_TO := Color(0.86, 0.87, 0.89)


## Draw these bricks faded and every other in its own colour; an empty set
## is none faded. Each batch with a brick changing is written again, once,
## at the end of the frame, as for x-ray.
func set_faded(ids: Dictionary) -> void:
	var changed: Dictionary = {}
	for brick_id: int in _faded:
		if not ids.has(brick_id):
			changed[brick_id] = true
	for brick_id: int in ids:
		if not _faded.has(brick_id):
			changed[brick_id] = true
	_faded = ids.duplicate()
	var keys: Dictionary = {}
	for brick_id: int in changed:
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			keys[key] = true
	for key: String in keys:
		var batch: Batch = _batches.get(key)
		if batch != null:
			_touching(batch)
			_mark_dirty(key)


## While the world shows an order a count at a time ([method reveal_upto]):
## these bricks drawn faded (id -> true) or in their own colours (id ->
## false), each written in its slot of the buffer its batch was written
## with, and each batch that holds one handed that buffer again — nothing
## else rewritten and the reveal going on. A page of the step player fades
## the page before's parts, not the model: set_faded asked every brick and
## rewrote every batch holding one that changed, the reveal ended. False,
## with nothing changed, for a brick that is not in the order or a batch
## not written in it: the caller then uses set_faded.
func set_faded_in_order(changes: Dictionary) -> bool:
	if _reveal_order.is_empty() or _rebuild_queued:
		return false
	for brick_id: int in changes:
		if not _reveal_rank.has(brick_id):
			return false
		for key: String in _brick_batches.get(brick_id, NO_KEYS):
			var batch: Batch = _batches.get(key)
			if batch == null or batch.ranks.is_empty() \
					or batch.buffer.size() != batch.brick_ids.size() * STRIDE:
				return false
	var touched: Dictionary = {}
	for brick_id: int in changes:
		var fade: bool = changes[brick_id]
		if fade == _faded.has(brick_id):
			continue
		if fade:
			_faded[brick_id] = true
		else:
			_faded.erase(brick_id)
		var brick: Brick = _bricks[brick_id]
		var rank: int = _reveal_rank[brick_id]
		for key: String in _brick_batches.get(brick_id, NO_KEYS):
			var batch: Batch = _batches[key]
			# The batch's bricks of the order follow those shown from the
			# start, by their place in it.
			var slot: int = batch.shown + batch.ranks.bsearch(rank)
			_pack_colour(batch.buffer, slot * STRIDE,
				_shown_colour(brick, _brick_colour(brick, batch.surface_color)))
			touched[batch] = true
	for batch: Batch in touched:
		# Into a buffer of its own, not the one drawn from written over: in
		# a browser what is written over in place is not drawn
		# (_fresh_slots), and the pages came up with what was built before
		# drawn dark where it should be faded, now and then.
		_fresh_slots(batch, batch.brick_ids.size())
		batch.multimesh.buffer = batch.buffer
		batch.multimesh.visible_instance_count = batch.shown + batch.revealed
	return true


func faded_ids() -> Dictionary:
	return _faded


## Bricks drawn tinted towards a colour: id -> Color. Tools, Check stability
## tints the stud joints carrying most against what their studs hold
## (Balance). An empty set is none.
var _tinted: Dictionary = {}
const TINTING := 0.7


func set_tinted(ids: Dictionary) -> void:
	var changed: Dictionary = {}
	for brick_id: int in _tinted:
		if not ids.has(brick_id) or ids[brick_id] != _tinted[brick_id]:
			changed[brick_id] = true
	for brick_id: int in ids:
		if not _tinted.has(brick_id):
			changed[brick_id] = true
	_tinted = ids.duplicate()
	var keys: Dictionary = {}
	for brick_id: int in changed:
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			keys[key] = true
	for key: String in keys:
		var batch: Batch = _batches.get(key)
		if batch != null:
			_touching(batch)
			_mark_dirty(key)


func tinted_ids() -> Dictionary:
	return _tinted


## Bricks drawn somewhere other than where they stand: id -> Transform3D.
## Tools, Simulate mechanism turns a gear train with these (SimulatePanel):
## what is drawn moves and the model does not. A brick keeps its transform,
## the lattice its cells, the history no step and [member revision] its
## count, so nothing that reads the model — a save, the autosave, undo, the
## assistant — sees the turn. An empty set draws every brick where it stands.
var _drawn: Dictionary = {}


func set_drawn(placed: Dictionary) -> void:
	var keys: Dictionary = {}
	for brick_id: int in _drawn:
		if not placed.has(brick_id):
			for key: String in _brick_batches.get(brick_id, PackedStringArray()):
				keys[key] = true
	for brick_id: int in placed:
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			keys[key] = true
	_drawn = placed.duplicate()
	for key: String in keys:
		var batch: Batch = _batches.get(key)
		if batch != null:
			_touching(batch)
			_mark_dirty(key)


func drawn_ids() -> Dictionary:
	return _drawn


## Where a brick is drawn: where it stands, unless [method set_drawn] moved
## its picture.
func drawn_at(brick: Brick) -> Transform3D:
	return _drawn.get(brick.id, brick.transform)


## Where a brick stands in the model as built: where it is, unless it is in
## a section broken out ([member broken_out]), whose parts are where they were
## pulled from — exactly, for a part not moved since, by its offset taken
## off for one put in or moved while it was out. What a file is written
## with (ModelStore).
func home_of(brick: Brick) -> Transform3D:
	if broken_out.is_empty():
		return brick.transform
	var path: String = Assemblies.path_of(brick)
	for section: String in broken_out:
		var record: Dictionary = broken_out[section]
		var home: Dictionary = record.get("home", {})
		if not home.has(brick.id) and not Assemblies.within(path, section):
			continue
		return Sections.home_for(brick.transform, record, brick.id)
	return brick.transform


## A colour as a faded brick is drawn in. Its alpha is kept: faded
## transparent plastic is still see-through.
static func faded(colour: Color) -> Color:
	var pale: Color = colour.lerp(FADED_TO, FADING)
	pale.a = colour.a
	return pale


## A batch's x-ray ghosts written into their own MultiMesh, or the MultiMesh
## let go when it has none.
func _write_xray(batch: Batch, ghosts: Array, surface_color: int) -> void:
	if ghosts.is_empty():
		if batch.xray != null:
			batch.xray.queue_free()
			batch.xray = null
		return
	if batch.xray == null:
		var made := MultiMesh.new()
		made.transform_format = MultiMesh.TRANSFORM_3D
		made.use_colors = true
		made.mesh = batch.multimesh.mesh
		batch.xray = MultiMeshInstance3D.new()
		batch.xray.multimesh = made
		batch.xray.material_override = _see_through(false)
		batch.xray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.instance.add_child(batch.xray)
	var multimesh: MultiMesh = batch.xray.multimesh
	# Fresh slots, for the reason _fresh_slots gives.
	multimesh.instance_count = 0
	multimesh.instance_count = ghosts.size()
	var bounds := AABB()
	for slot: int in ghosts.size():
		var brick: Brick = ghosts[slot]
		multimesh.set_instance_transform(slot, drawn_at(brick))
		var code: int = brick.color_code if surface_color == Lbm.COLOR_INHERIT \
			else surface_color
		multimesh.set_instance_color(slot, library.color(code).shown)
		var box: AABB = drawn_at(brick) * multimesh.mesh.get_aabb()
		bounds = box if slot == 0 else bounds.merge(box)
	batch.xray.custom_aabb = bounds


## The see-through material, for x-ray's ghosts or for what the cut leaves
## as ghosts ([param beyond]); one of each per world.
func _see_through(beyond: bool) -> ShaderMaterial:
	var existing: ShaderMaterial = _beyond_material if beyond else _xray_material
	if existing != null:
		return existing
	var material := ShaderMaterial.new()
	material.shader = SEE_THROUGH
	material.set_shader_parameter("linearise", _linearise_colors())
	material.set_shader_parameter("beyond", beyond)
	# After the transparent plastic, which is behind or inside them.
	material.render_priority = 2
	if beyond:
		_beyond_material = material
	else:
		_xray_material = material
	_see_through_follows()
	return material


## The ghosts cut as the plastic is: x-ray's on the near side of the plane
## unless the cut leaves ghosts anyway, and the cut's own past it.
func _see_through_follows() -> void:
	if _xray_material != null:
		_xray_material.set_shader_parameter("cut_on", _cut_on and not _cut_ghosts)
		_xray_material.set_shader_parameter("cut_plane", _plane_vector())
	if _beyond_material != null:
		_beyond_material.set_shader_parameter("cut_on", true)
		_beyond_material.set_shader_parameter("cut_plane", _plane_vector())


func _set_bounds(batch: Batch, bounds: AABB) -> void:
	batch.instance.custom_aabb = bounds
