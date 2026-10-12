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
	## Triangles in one instance, read once when the batch is made.
	var triangles: int = 0
	## While the build animation plays (see [method begin_reveal]): how
	## many of [member brick_ids] were shown from the start, and the
	## places in the build order of the rest, which follow them in order.
	var shown: int = 0
	var ranks: PackedInt64Array = PackedInt64Array()
	var revealed: int = 0


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
func add_brick(part_id: String, color_code: int, at: Transform3D) -> int:
	var brick_id: int = _place(part_id, color_code, at)
	if brick_id != 0:
		_note({"op": "add", "id": brick_id, "part": _bricks[brick_id].part_id,
			"colour": color_code, "at": at})
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


func _place(part_id: String, color_code: int, at: Transform3D) -> int:
	if library == null:
		push_error("brick world: no part library set")
		return 0
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return 0

	# Whatever the number means today.
	#
	# Here rather than at each caller, because every placement comes
	# through this door — a design, an import, a hand-placed brick, an
	# undo. A retired number renders correctly, since its stub is a
	# reference to the part that replaced it, so the model looks right
	# and is wrong underneath: the parts list offers "~Moved to 3023b"
	# where a name should be, and so does the booklet.
	var real: String = library.resolve(part_id)
	var brick := Brick.new(_next_id, real, color_code, at)
	_next_id += 1
	_bricks[brick.id] = brick

	var keys := PackedStringArray()
	var info: PartLibrary.PartInfo = library.parts[part_id]
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


func move_brick(brick_id: int, to: Transform3D) -> bool:
	var brick: Brick = get_brick(brick_id)
	if brick == null:
		return false
	_touching_brick(brick_id)
	brick.transform = to
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
	_next_id = 1
	_note({"op": "clear"})
	_generation += 1


## Show only these bricks, hiding the rest. An empty set shows all of
## them again, which is what ends playback.
func show_only(visible_ids: Dictionary) -> void:
	_stop_reveal()
	var everything: bool = visible_ids.is_empty()
	var changed: bool = false
	for brick_id: int in _bricks:
		var brick: Brick = _bricks[brick_id]
		var hide: bool = not (everything or visible_ids.has(brick_id))
		if brick.hidden == hide:
			continue
		brick.hidden = hide
		changed = true
		for key: String in _brick_batches.get(brick_id, PackedStringArray()):
			_mark_dirty(key)
	if changed:
		_flush()


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
## for the booklet to draw its outlines from. Nothing about the model
## changes, and the next change to the world draws it as it was.
func draw_as(material: ShaderMaterial, colour_of: Callable) -> void:
	if _rebuild_queued:
		_flush()
	for key: String in _batches:
		var batch: Batch = _batches[key]
		batch.instance.material_override = material
		var slot: int = 0
		for brick_id: int in batch.brick_ids:
			if _bricks[brick_id].hidden:
				continue
			batch.multimesh.set_instance_color(slot, colour_of.call(brick_id))
			slot += 1


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
	var count: int = batch.brick_ids.size()
	_fresh_slots(batch, count)
	if count == 0:
		batch.multimesh.visible_instance_count = 0
		return

	var surface_index: int = key.split(":")[1].to_int()
	# One mesh per batch — the key is the mesh's hash — so one answer to
	# whether this surface follows the brick's colour or keeps its own.
	var surface_color: int = _surface_colour(batch, surface_index)
	# Hidden bricks are packed off the end rather than left as gaps: a
	# MultiMesh draws its first visible_instance_count slots, so the ones
	# to draw have to be the ones at the front.
	var slot: int = 0
	for brick_id: int in batch.brick_ids:
		var brick: Brick = _bricks[brick_id]
		if brick.hidden:
			continue
		_write_instance(batch, slot, brick, surface_color)
		slot += 1

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
		var box: AABB = brick.transform * batch.multimesh.mesh.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	batch.instance.custom_aabb = bounds


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
		surface_color: int) -> void:
	batch.multimesh.set_instance_transform(slot, brick.transform)
	# A surface moulded in a fixed colour ignores the brick's colour;
	# that is what keeps a printed face black on a yellow head.
	var code: int = brick.color_code if surface_color == Lbm.COLOR_INHERIT else surface_color
	var color: PartLibrary.BrickColor = library.color(code)
	batch.multimesh.set_instance_color(slot, color.shown)
	batch.multimesh.set_instance_custom_data(slot, color.instance_custom)


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
	if _reveal_order.is_empty():
		return
	for batch: Batch in _revealing:
		batch.multimesh.visible_instance_count = batch.brick_ids.size()
		batch.ranks = PackedInt64Array()
		batch.shown = 0
		batch.revealed = 0
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
	var bounds := AABB()
	for slot: int in count:
		var brick: Brick = _bricks[batch.brick_ids[slot]]
		_write_instance(batch, slot, brick, surface_color)
		var box: AABB = brick.transform * batch.multimesh.mesh.get_aabb()
		bounds = box if slot == 0 else bounds.merge(box)
	batch.multimesh.visible_instance_count = batch.shown
	# Bounds for all of them, shown or to come, so the batch is not culled
	# as it grows.
	batch.instance.custom_aabb = bounds


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
