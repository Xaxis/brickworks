## Draws a model: every brick in it, batched by the geometry it shares.
##
## A model is a list of bricks, and a brick is a part id, a colour and a
## transform. Drawing them one node each would put tens of thousands of
## [MeshInstance3D]s in the tree and spend the whole frame on culling and
## draw calls, so bricks are grouped instead: one [MultiMesh] per distinct
## (surface geometry, material class), with the colour carried per instance.
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


## Whether the shader should linearise the instance colour itself.
##
## Forward+ renders in linear space and converts on output, so an sRGB
## palette value has to be linearised going in. The Compatibility
## renderer — which is what the web build gets, since Forward+ needs
## WebGPU — already accounts for it, and linearising a second time
## renders every part as a darker, duller version of itself.
static func _linearise_colors() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


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


## Place a brick. Returns its id, or 0 if the part has no geometry.
func add_brick(part_id: String, color_code: int, at: Transform3D) -> int:
	if library == null:
		push_error("brick world: no part library set")
		return 0
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return 0

	var brick := Brick.new(_next_id, part_id, color_code, at)
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
		batch.brick_ids.append(brick.id)
		keys.append(key)
		_mark_dirty(key)

	_brick_batches[brick.id] = keys
	return brick.id


func remove_brick(brick_id: int) -> bool:
	if not _bricks.has(brick_id):
		return false
	for key: String in _brick_batches.get(brick_id, PackedStringArray()):
		var batch: Batch = _batches.get(key)
		if batch == null:
			continue
		var at: int = batch.brick_ids.find(brick_id)
		if at >= 0:
			batch.brick_ids.remove_at(at)
		_mark_dirty(key)
	_brick_batches.erase(brick_id)
	_bricks.erase(brick_id)
	return true


func move_brick(brick_id: int, to: Transform3D) -> bool:
	var brick: Brick = _bricks.get(brick_id)
	if brick == null:
		return false
	brick.transform = to
	for key: String in _brick_batches.get(brick_id, PackedStringArray()):
		_mark_dirty(key)
	return true


func recolor_brick(brick_id: int, color_code: int) -> bool:
	var brick: Brick = _bricks.get(brick_id)
	if brick == null:
		return false
	# A colour change can move a brick between the opaque and transparent
	# batches, so it is a remove and re-add rather than an in-place edit.
	var at: Transform3D = brick.transform
	var part_id: String = brick.part_id
	remove_brick(brick_id)
	add_brick(part_id, color_code, at)
	return true


func clear() -> void:
	for key: String in _batches:
		var batch: Batch = _batches[key]
		batch.instance.queue_free()
	_batches.clear()
	_bricks.clear()
	_brick_batches.clear()
	_dirty.clear()
	_next_id = 1


func brick_count() -> int:
	return _bricks.size()


func get_brick(brick_id: int) -> Brick:
	return _bricks.get(brick_id)


func bricks() -> Array:
	return _bricks.values()


## The bounding box of everything placed, in LDU.
func model_bounds() -> AABB:
	var result := AABB()
	var first: bool = true
	for brick_id: int in _bricks:
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
	batch.multimesh.mesh = part.surfaces[surface_index]

	batch.instance = MultiMeshInstance3D.new()
	batch.instance.multimesh = batch.multimesh
	batch.instance.name = key
	var material_class: int = _material_class_for(part, surface_index, color_code)
	var two_sided: bool = part.surface_two_sided[surface_index] == 1
	batch.instance.material_override = _material(material_class, two_sided)
	add_child(batch.instance)
	return batch


func _mark_dirty(key: String) -> void:
	_dirty[key] = true
	if not _rebuild_queued:
		_rebuild_queued = true
		# One rebuild per frame however many bricks were touched.
		_flush.call_deferred()


func _flush() -> void:
	_rebuild_queued = false
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
			triangles += _triangles_of(batch.multimesh.mesh) * batch.multimesh.instance_count
	rebuilt.emit(_bricks.size(), live, triangles)


func _rebuild(batch: Batch, key: String) -> void:
	var count: int = batch.brick_ids.size()
	batch.multimesh.instance_count = count
	# Kept in step with instance_count explicitly: raising one does not
	# raise the other, and a batch that grows would otherwise keep
	# drawing only as many instances as it had before.
	batch.multimesh.visible_instance_count = count
	if count == 0:
		return

	var surface_index: int = key.split(":")[1].to_int()
	for slot: int in count:
		var brick: Brick = _bricks[batch.brick_ids[slot]]
		batch.multimesh.set_instance_transform(slot, brick.transform)

		# A surface moulded in a fixed colour ignores the brick's colour;
		# that is what keeps a printed face black on a yellow head.
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var surface_color: int = part.surface_colors[surface_index]
		var code: int = brick.color_code if surface_color == Lbm.COLOR_INHERIT else surface_color
		batch.multimesh.set_instance_color(slot, library.color(code).rgb)

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
	for slot: int in count:
		var brick: Brick = _bricks[batch.brick_ids[slot]]
		var box: AABB = brick.transform * batch.multimesh.mesh.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	batch.instance.custom_aabb = bounds


func _triangles_of(mesh: Mesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return indices.size() / 3
