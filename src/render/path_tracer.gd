## Best, path traced, where the graphics card traces rays: StudioRender's
## set (the copy of the model, the sweep, the lights, the sky or a
## photographed place) followed bounce by bounce (path_tracer.glsl), the
## picture getting cleaner with every pass until it has its samples.
##
## BrickLink Studio's Eyesight is a path tracer on an NVIDIA card; this is
## one on any card Vulkan gives ray tracing (NVIDIA RTX, AMD RX 6000 and
## later, Intel Arc), in the app, on the model as it stands. Where there is
## none (an older card, a browser), Best stays frames averaged
## (StudioRender), and the dialog says which it is.
##
## The model is two levels, as the card wants it: one shape for each
## distinct part geometry (a BLAS, kept between renders, so a model's
## second render builds only its new parts), and one instance for every
## brick of every batch of the copy on the stage (the TLAS, built each
## picture: a turntable's frame moves the bricks). The colour, the finish
## and the part's box for its seam go beside each instance; the normals the
## closest-hit shader reads go in one buffer of every shape in the picture.
##
## Work goes to the card a pass at a time, a frame of the app's each, so
## the window keeps answering while it renders (RenderQueue renders one
## after another behind a person who goes on building).
class_name PathTracer
extends RefCounted

## The most bounces a path takes off the plastic and the sweep.
const BOUNCES := 6
## Cells across and down of the table a photographed place is picked from.
const PLACE_CELLS := Vector2i(256, 128)
## The most samples one pass gives every pixel, and the frame a pass is
## kept to on the card: the window's own frame and this together stay
## under a few dozen milliseconds.
const MOST_PER_PASS := 32
const PASS_MS := 28.0
## Glass, opal and the rest, as PartLibrary.BrickColor.Finish numbers them:
## those let no light through, clear or not.
const SOLID_FINISHES: Array[int] = [6, 7, 11]

const KIND_PLASTIC := 0
const KIND_GLASS := 1
const KIND_SWEEP := 2
const MASK_SOLID := 0x01
const MASK_GLASS := 0x02
const MASK_SWEEP := 0x04

static var _checked: bool = false
static var _can: bool = false

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sbt: RID
var _range: int = 0
var _resolve_shader: RID
var _resolve_pipeline: RID
var _sampler: RID

## Mesh -> [BLAS, vertex buffer, index buffer, positions, normals,
## indices, vertex count]: kept between pictures.
var _shapes: Dictionary = {}
## What one picture is built of, freed when the next is staged.
var _tlas: RID
var _scene_buffer: RID
var _instances: RID
var _meshes: RID
var _positions: RID
var _normals: RID
var _indices: RID
var _place_texture: RID
var _place_table: RID
var _place_for: StudioPanorama = null
var _accum: RID
var _picture: RID
var _trace_set: RID
var _resolve_set: RID
var _size := Vector2i.ZERO
var _has_glass: bool = false

## What a picture is lit by and seen through, set before [method stage].
var scene := PackedFloat32Array()
## Samples in the running sum so far.
var samples: int = 0
## Instances in the last picture staged, and distinct shapes.
var instance_count: int = 0
var shape_count: int = 0


## Whether this machine traces rays: the desktop's renderer on a card with
## Vulkan ray tracing. Never in a browser.
static func available() -> bool:
	if _checked:
		return _can
	_checked = true
	_can = false
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return false
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return false
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	_can = rd != null and rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE) \
		and rd.has_feature(RenderingDevice.SUPPORTS_BUFFER_DEVICE_ADDRESS)
	return _can


## Why Best is not path traced here, in plain words for the person asking.
static func why_not() -> String:
	if available():
		return ""
	if OS.has_feature("web"):
		return "Path tracing needs the desktop app: a browser cannot trace rays."
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return "Path tracing needs the desktop app's full renderer."
	return "Path tracing needs a graphics card that traces rays, and this one does not."


## A card that said it traces rays and then would not: said once, and
## Best is frames averaged from then on.
static func _refused(what: String) -> bool:
	push_error("path tracer: " + what)
	_can = false
	return false


## The pipeline, the first time it is wanted. False when the card refused.
func _make() -> bool:
	if _pipeline.is_valid():
		return true
	if not available():
		return false
	_rd = RenderingServer.get_rendering_device()
	var file: RDShaderFile = load("res://src/render/path_tracer.glsl") as RDShaderFile
	var resolve_file: RDShaderFile = load("res://src/render/path_tracer_resolve.glsl") as RDShaderFile
	if file == null or resolve_file == null:
		return _refused("its shaders did not load")
	var spirv: RDShaderSPIRV = file.get_spirv()
	for stage: String in ["raygen", "miss", "closest_hit"]:
		var error: String = spirv.get("compile_error_" + stage)
		if not error.is_empty():
			return _refused("%s: %s" % [stage, error])
	_shader = _rd.shader_create_from_spirv(spirv, "Path tracer")
	var raygen := RDPipelineShader.new()
	raygen.shader = _shader
	var miss := RDPipelineShader.new()
	miss.shader = _shader
	var closest := RDPipelineShader.new()
	closest.shader = _shader
	var group := RDHitGroup.new()
	group.closest_hit_shader = closest
	_pipeline = _rd.raytracing_pipeline_create([raygen], [miss], [group], 1)
	if not _pipeline.is_valid():
		return _refused("the card refused the pipeline")
	_sbt = _rd.hit_sbt_create(_pipeline, 1)
	_range = _rd.hit_sbt_range_alloc(_sbt, 1)
	_rd.hit_sbt_range_update(_sbt, _range, 0, PackedInt32Array([0]))
	var resolve_spirv: RDShaderSPIRV = resolve_file.get_spirv()
	if not resolve_spirv.compile_error_compute.is_empty():
		return _refused("resolve: %s" % resolve_spirv.compile_error_compute)
	_resolve_shader = _rd.shader_create_from_spirv(resolve_spirv, "Path tracer resolve")
	_resolve_pipeline = _rd.compute_pipeline_create(_resolve_shader)
	var sampler := RDSamplerState.new()
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _rd.sampler_create(sampler)
	return true


# -- the set -------------------------------------------------------------------


## The shape of one mesh on the card, made the first time it is staged.
func _shape(mesh: Mesh) -> Array:
	if _shapes.has(mesh):
		return _shapes[mesh]
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
		if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(points.size() - points.size() % 3)
		for n: int in indices.size():
			indices[n] = n
	if normals.size() != points.size():
		normals = PackedVector3Array()
		normals.resize(points.size())
	var shape: Array = []
	if points.is_empty() or indices.is_empty():
		_shapes[mesh] = shape
		return shape
	var bits: int = RenderingDevice.BUFFER_CREATION_DEVICE_ADDRESS_BIT \
		| RenderingDevice.BUFFER_CREATION_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT
	var point_bytes: PackedByteArray = points.to_byte_array()
	var vertices: RID = _rd.vertex_buffer_create(point_bytes.size(), point_bytes, bits)
	var index_bytes: PackedByteArray = indices.to_byte_array()
	var triangles: RID = _rd.index_buffer_create(indices.size(),
		RenderingDevice.INDEX_BUFFER_FORMAT_UINT32, index_bytes, false, bits)
	var geometry := RDAccelerationStructureGeometry.new()
	geometry.vertex_buffer = vertices
	geometry.vertex_stride = 12
	geometry.vertex_count = points.size()
	geometry.vertex_format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	geometry.index_buffer = triangles
	geometry.index_count = indices.size()
	geometry.flags = RenderingDevice.ACCELERATION_STRUCTURE_GEOMETRY_OPAQUE_BIT
	var blas: RID = _rd.blas_create([geometry],
		RenderingDevice.ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT)
	if not blas.is_valid() or _rd.blas_build(blas) != OK:
		push_error("path tracer: a shape of %d triangles was refused" % (indices.size() / 3))
		_shapes[mesh] = shape
		return shape
	shape = [blas, vertices, triangles, point_bytes, normals.to_byte_array(), index_bytes,
		points.size()]
	_shapes[mesh] = shape
	return shape


## Put the set on the card: every brick of [param batches] (the copy of the
## model's MultiMeshInstance3Ds), and [param sweep] when there is one.
## False when there is nothing to trace or no card to trace it on.
func stage(batches: Array, sweep: MeshInstance3D) -> bool:
	if not _make():
		return false
	_free_picture_set()
	var shape_index: Dictionary = {}
	var shape_list: Array = []
	var records := PackedFloat32Array()
	var kinds := PackedInt32Array()
	var placed: Array[RDAccelerationStructureInstance] = []
	_has_glass = false
	for node: Variant in batches:
		var batch := node as MultiMeshInstance3D
		if batch == null or not batch.is_visible_in_tree() or batch.multimesh == null \
				or batch.multimesh.mesh == null:
			continue
		var multimesh: MultiMesh = batch.multimesh
		var count: int = multimesh.visible_instance_count if multimesh.visible_instance_count >= 0 \
			else multimesh.instance_count
		if count <= 0:
			continue
		var shape: Array = _shape(multimesh.mesh)
		if shape.is_empty():
			continue
		if not shape_index.has(multimesh.mesh):
			shape_index[multimesh.mesh] = shape_list.size()
			shape_list.append(shape)
		var mesh_number: int = shape_index[multimesh.mesh]
		var box_min := Vector3.ZERO
		var box_max := Vector3.ZERO
		var material := batch.material_override as ShaderMaterial
		if material != null:
			box_min = material.get_shader_parameter("part_box_min")
			box_max = material.get_shader_parameter("part_box_max")
		var whole: Transform3D = batch.global_transform
		var buffer: PackedFloat32Array = multimesh.buffer
		var stride: int = 12 + (4 if multimesh.use_colors else 0) \
			+ (4 if multimesh.use_custom_data else 0)
		for n: int in count:
			var o: int = n * stride
			var at := Transform3D(
				Basis(Vector3(buffer[o], buffer[o + 4], buffer[o + 8]),
					Vector3(buffer[o + 1], buffer[o + 5], buffer[o + 9]),
					Vector3(buffer[o + 2], buffer[o + 6], buffer[o + 10])),
				Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]))
			var colour := Color(1, 1, 1, 1)
			var custom := Color(0, 0, 0, 0)
			if multimesh.use_colors:
				colour = Color(buffer[o + 12], buffer[o + 13], buffer[o + 14], buffer[o + 15])
			if multimesh.use_custom_data:
				var c: int = o + (16 if multimesh.use_colors else 12)
				custom = Color(buffer[c], buffer[c + 1], buffer[c + 2], buffer[c + 3])
			var finish: int = floori(custom.a + 0.001)
			var kind: int = KIND_GLASS if colour.a < 0.99 and not finish in SOLID_FINISHES \
				else KIND_PLASTIC
			_has_glass = _has_glass or kind == KIND_GLASS
			var lin: Color = colour.srgb_to_linear()
			var fleck: Color = Color(custom.r, custom.g, custom.b).srgb_to_linear()
			records.append_array([lin.r, lin.g, lin.b, colour.a,
				fleck.r, fleck.g, fleck.b, custom.a,
				box_min.x, box_min.y, box_min.z, 0.0,
				box_max.x, box_max.y, box_max.z, 0.0])
			kinds.append_array([mesh_number, kind, 0, 0])
			var instance := RDAccelerationStructureInstance.new()
			instance.blas = shape[0]
			instance.transform = whole * at
			instance.id = placed.size()
			instance.mask = MASK_GLASS if kind == KIND_GLASS else MASK_SOLID
			instance.hit_sbt_range = _range
			instance.flags = RenderingDevice.ACCELERATION_STRUCTURE_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT
			placed.append(instance)
	if placed.is_empty():
		return false
	if sweep != null and sweep.is_visible_in_tree() and sweep.mesh != null:
		var shape: Array = _shape(sweep.mesh)
		if not shape.is_empty():
			if not shape_index.has(sweep.mesh):
				shape_index[sweep.mesh] = shape_list.size()
				shape_list.append(shape)
			records.append_array([1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0,
				0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			kinds.append_array([shape_index[sweep.mesh], KIND_SWEEP, 0, 0])
			var floor := RDAccelerationStructureInstance.new()
			floor.blas = shape[0]
			floor.transform = sweep.global_transform
			floor.id = placed.size()
			floor.mask = MASK_SWEEP
			floor.hit_sbt_range = _range
			floor.flags = RenderingDevice.ACCELERATION_STRUCTURE_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT
			placed.append(floor)
	# Every instance's record: 16 floats, then 4 numbers, as path_tracer.glsl
	# reads Instance (five vec4s, the last unsigned).
	var bytes := PackedByteArray()
	bytes.resize(placed.size() * 80)
	for n: int in placed.size():
		for k: int in 16:
			bytes.encode_float(n * 80 + k * 4, records[n * 16 + k])
		for k: int in 4:
			bytes.encode_u32(n * 80 + 64 + k * 4, kinds[n * 4 + k])
	_instances = _storage(bytes)
	# The shapes' points, normals and corners, one after another.
	var meshes := PackedByteArray()
	meshes.resize(shape_list.size() * 16)
	var points := PackedByteArray()
	var normals := PackedByteArray()
	var corners := PackedByteArray()
	var vertex_base: int = 0
	for n: int in shape_list.size():
		var shape: Array = shape_list[n]
		meshes.encode_u32(n * 16, vertex_base)
		meshes.encode_u32(n * 16 + 4, corners.size() / 4)
		points.append_array(shape[3])
		normals.append_array(shape[4])
		corners.append_array(shape[5])
		vertex_base += int(shape[6])
	_meshes = _storage(meshes)
	_positions = _storage(points)
	_normals = _storage(normals)
	_indices = _storage(corners)
	_tlas = _rd.tlas_create(placed.size(), RenderingDevice.ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT)
	if not _tlas.is_valid() or _rd.tlas_build(_tlas, placed) != OK:
		push_error("path tracer: the card refused %d instances" % placed.size())
		return false
	instance_count = placed.size()
	shape_count = shape_list.size()
	return true


func _storage(bytes: PackedByteArray) -> RID:
	if bytes.size() < 16:
		bytes.resize(16)
	return _rd.storage_buffer_create(bytes.size(), bytes)


## Light the set with a photographed place: its picture, and a table for
## picking directions in proportion to its light. Null for none.
func light_with(place: StudioPanorama) -> void:
	if place == _place_for and _place_texture.is_valid():
		return
	_free(_place_texture)
	_free(_place_table)
	_place_texture = RID()
	_place_table = RID()
	_place_for = place
	var image: Image = null
	if place != null and place.texture != null:
		image = place.texture.get_image()
		if image != null and image.is_compressed():
			image.decompress()
	if image == null:
		image = Image.create(2, 2, false, Image.FORMAT_RGBAF)
		image.fill(Color(1, 1, 1))
	image.convert(Image.FORMAT_RGBAF)
	var format := RDTextureFormat.new()
	format.width = image.get_width()
	format.height = image.get_height()
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_place_texture = _rd.texture_create(format, RDTextureView.new(), [image.get_data()])
	# The table: rows' cumulative shares, then each row's cells', from a
	# small copy weighed by the solid angle each cell covers.
	var small: Image = image.duplicate() as Image
	small.resize(PLACE_CELLS.x, PLACE_CELLS.y, Image.INTERPOLATE_BILINEAR)
	var wide: int = PLACE_CELLS.x
	var tall: int = PLACE_CELLS.y
	var table := PackedFloat32Array()
	table.resize(tall + tall * wide)
	var rows := PackedFloat32Array()
	rows.resize(tall)
	var data: PackedFloat32Array = small.get_data().to_float32_array()
	for y: int in tall:
		var sine: float = sin(PI * (float(y) + 0.5) / float(tall))
		var running: float = 0.0
		for x: int in wide:
			var o: int = (y * wide + x) * 4
			var level: float = 0.2126 * data[o] + 0.7152 * data[o + 1] + 0.0722 * data[o + 2]
			running += maxf(level, 0.0) * sine + 1e-6
			table[tall + y * wide + x] = running
		rows[y] = running
		for x: int in wide:
			table[tall + y * wide + x] /= running
	var all: float = 0.0
	for y: int in tall:
		all += rows[y]
		table[y] = all
	for y: int in tall:
		table[y] /= all
	_place_table = _storage(table.to_byte_array())


## The running sum and the picture, at [param size]: started again.
func begin(size: Vector2i) -> bool:
	if not _make() or not _tlas.is_valid():
		return false
	samples = 0
	if size == _size and _accum.is_valid():
		_bind()
		return true
	_free(_trace_set)
	_free(_resolve_set)
	_free(_accum)
	_free(_picture)
	_trace_set = RID()
	_resolve_set = RID()
	_size = size
	var sums := RDTextureFormat.new()
	sums.width = size.x
	sums.height = size.y
	sums.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	sums.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	_accum = _rd.texture_create(sums, RDTextureView.new())
	var out := RDTextureFormat.new()
	out.width = size.x
	out.height = size.y
	out.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	out.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_picture = _rd.texture_create(out, RDTextureView.new())
	if not _accum.is_valid() or not _picture.is_valid():
		return false
	_bind()
	return true


func _bind() -> void:
	_free(_trace_set)
	_free(_resolve_set)
	_free(_scene_buffer)
	if not _place_texture.is_valid():
		light_with(null)
	var bytes: PackedByteArray = scene.to_byte_array()
	_scene_buffer = _storage(bytes)
	var uniforms: Array[RDUniform] = []
	uniforms.append(_uniform(0, RenderingDevice.UNIFORM_TYPE_ACCELERATION_STRUCTURE, [_tlas]))
	uniforms.append(_uniform(1, RenderingDevice.UNIFORM_TYPE_IMAGE, [_accum]))
	uniforms.append(_uniform(2, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_scene_buffer]))
	uniforms.append(_uniform(3, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_instances]))
	uniforms.append(_uniform(4, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_meshes]))
	uniforms.append(_uniform(5, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_positions]))
	uniforms.append(_uniform(6, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_normals]))
	uniforms.append(_uniform(7, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_indices]))
	uniforms.append(_uniform(8, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[_sampler, _place_texture]))
	uniforms.append(_uniform(9, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, [_place_table]))
	_trace_set = _rd.uniform_set_create(uniforms, _shader, 0)
	var resolving: Array[RDUniform] = [
		_uniform(0, RenderingDevice.UNIFORM_TYPE_IMAGE, [_accum]),
		_uniform(1, RenderingDevice.UNIFORM_TYPE_IMAGE, [_picture])]
	_resolve_set = _rd.uniform_set_create(resolving, _resolve_shader, 0)


static func _uniform(binding: int, type: int, ids: Array) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.binding = binding
	uniform.uniform_type = type as RenderingDevice.UniformType
	for id: RID in ids:
		uniform.add_id(id)
	return uniform


## Whether the set has clear plastic, which shadow rays look through.
func has_glass() -> bool:
	return _has_glass


# -- tracing -------------------------------------------------------------------


## Add [param count] samples to every pixel. The card does the work after
## this frame's own drawing; nothing waits for it here.
func trace(count: int, seed: int = 0) -> void:
	if not _trace_set.is_valid() or count <= 0:
		return
	var push := PackedByteArray()
	push.resize(16)
	push.encode_u32(0, samples)
	push.encode_u32(4, count)
	push.encode_u32(8, seed)
	push.encode_u32(12, 1 if samples == 0 else 0)
	var list: int = _rd.raytracing_list_begin()
	_rd.raytracing_list_bind_raytracing_pipeline(list, _pipeline)
	_rd.raytracing_list_bind_uniform_set(list, _trace_set, 0)
	_rd.raytracing_list_set_push_constant(list, push, push.size())
	_rd.raytracing_list_trace_rays(list, 0, _sbt, _size.x, _size.y, 1)
	_rd.raytracing_list_end()
	samples += count


## The picture so far, exposed by [param exposure] and tone-mapped
## ([param tonemapper]: 2 Filmic, 3 ACES, at [param white]), with the
## product look's [param contrast] and [param saturation] after.
func picture(exposure: float, tonemapper: int, white: float, contrast: float = 1.0,
		saturation: float = 1.0, transparent: bool = false, dither: bool = true) -> Image:
	if not _resolve_set.is_valid() or samples <= 0:
		return null
	var push := PackedFloat32Array([float(samples), exposure, white, float(tonemapper),
		contrast, saturation, 1.0 if transparent else 0.0, 1.0 if dither else 0.0])
	var bytes: PackedByteArray = push.to_byte_array()
	var list: int = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _resolve_pipeline)
	_rd.compute_list_bind_uniform_set(list, _resolve_set, 0)
	_rd.compute_list_set_push_constant(list, bytes, bytes.size())
	_rd.compute_list_dispatch(list, ceili(_size.x / 8.0), ceili(_size.y / 8.0), 1)
	_rd.compute_list_end()
	var data: PackedByteArray = _rd.texture_get_data(_picture, 0)
	if data.size() != _size.x * _size.y * 4:
		return null
	return Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, data)


# -- freeing -------------------------------------------------------------------


## A uniform set goes with the first thing in it that is freed, so it is
## let go only while it is still there.
func _free(rid: RID) -> void:
	if not rid.is_valid() or _rd == null:
		return
	if rid in [_trace_set, _resolve_set] and not _rd.uniform_set_is_valid(rid):
		return
	_rd.free_rid(rid)


func _free_picture_set() -> void:
	for rid: RID in [_trace_set, _tlas, _instances, _meshes, _positions, _normals, _indices]:
		_free(rid)
	_trace_set = RID()
	_tlas = RID()
	_instances = RID()
	_meshes = RID()
	_positions = RID()
	_normals = RID()
	_indices = RID()


## Everything on the card let go: the renderer is going.
func release() -> void:
	if _rd == null:
		return
	_free(_resolve_set)
	_free(_scene_buffer)
	_free_picture_set()
	for rid: RID in [_accum, _picture, _place_texture, _place_table]:
		_free(rid)
	for shape: Array in _shapes.values():
		if not shape.is_empty():
			for rid: RID in [shape[0], shape[1], shape[2]]:
				_free(rid)
	_shapes.clear()
	for rid: RID in [_sbt, _pipeline, _resolve_pipeline, _shader, _resolve_shader, _sampler]:
		_free(rid)
	_pipeline = RID()
	_rd = null
