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
## The most samples one pass gives every pixel, and what a pass may add
## to the window's own frame on the card.
const MOST_PER_PASS := 32
const PASS_MS := 28.0
## Glass, opal and the rest, as PartLibrary.BrickColor.Finish numbers them:
## those let no light through, clear or not.
const SOLID_FINISHES: Array[int] = [6, 7, 11]

## The product look's plastic, fitted to photographs (photoreal3): a solid
## colour's sRGB as the colour table gives it (0-255, "r,g,b") -> the linear
## albedo a camera's picture of the real part needs, through the camera's
## curve and PHOTO_LINEAR_SATURATION (StudioRender). Red, green and blue from
## the tent close-ups' faces (tools/bench/photoreal.py colour; red is the
## mean of the slope and the 2x2's, which want 0.46 and 0.78); black from the
## black 2x4's shaded side, L* 2 in its photograph, which the table's
## blue-grey black drew at 25. Colours not here keep the table's own. Fitting
## each colour's albedo keeps a face's light and shade, where the camera's
## saturation of 1.6 that photoreal2 fitted drew a lit red face one flat red
## and swallowed every highlight a red face took under its clipped channels.
const PRODUCT_ALBEDO: Dictionary = {
	"180,0,0": Color(0.60, 0.003, 0.003),
	"0,133,43": Color(0.004, 0.235, 0.031),
	"30,90,168": Color(0.019, 0.146, 0.564),
	"27,42,52": Color(0.009, 0.010, 0.012),
}

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
## The shader's "marks" version (photoreal9): the tracer with the wear
## that hands leave, made the first time a picture asks for it ([member
## marked]). The "plain" version is the code that drew every picture
## before it, so a picture without it is drawn exactly as it was: the
## shader with it compiled in, at 0, moved some 20,000 pixels of a close-up
## by up to 11 levels, the compiler ordering and fusing its arithmetic
## another way.
var _file: RDShaderFile
var _marked_shader: RID
var _marked_pipeline: RID
var _marked_sbt: RID
var _resolve_shader: RID
var _resolve_pipeline: RID
var _sampler: RID

## Mesh -> [BLAS, its corners' buffer, positions, normals, indices,
## vertex count]: kept between pictures, and shared by every
## tracer (Render's and the queue's: the queue's first picture built them
## all again, a quarter of a second of the window's frame), freed when the
## last of them is.
static var _shapes: Dictionary = {}
static var _holders: int = 0
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
## What a staged model stands on (photoreal7): a photographed tile of it,
## and the sampler that repeats it both ways.
var _surface_texture: RID
var _surface_for: Image = null
var _tile_sampler: RID
var _accum: RID
## What the eye's first hit is, summed over the samples (photoreal3): its
## normal and its albedo's lightness, for the product look's denoise.
var _guide: RID
var _picture: RID
var _trace_set: RID
var _resolve_set: RID
var _size := Vector2i.ZERO
var _has_glass: bool = false
## The card's timestamps of the last pass it has said, by frame.
var _timed_frame: int = -1

## What a picture is lit by and seen through, set before [method stage].
var scene := PackedFloat32Array()
## The product look, set before [method stage]: its plastic is traced as
## moulded (path_tracer.glsl's moulded(): edges and stud rims rounded, the
## logo raised on every stud, faces never quite flat), the window's as the
## window draws it.
var product: bool = false
## How far each of the product look's parts sits from exactly in place
## (photoreal4), set before [method stage]: at 1, up to SEAT_SHIFT off and
## SEAT_LIFT up, and SEAT_TURN degrees turned, each its own way, as a built
## set's parts never sit quite square. 0 for exactly. Each part's own way is
## from its place ([method _part_key]), so the surfaces a part is drawn in
## (its body, a print, a window) move together.
var seating: float = 0.0
const SEAT_SHIFT := 0.15
const SEAT_LIFT := 0.2
const SEAT_TURN := 0.3
## That seating as LEGO's own play lets a part sit (photoreal8), set before
## [method stage]: 0 as photoreal4 drew it, 1 as three_2x2_top's photograph
## measures it. Seen from above, its three bricks are square to each other
## to 0.01 degrees (the seating turned them 0.36 apart) and stand 0.13 to
## 0.17 LDU off line across (the seating 0.05), 0.39 to 0.60 LDU apart.
## At 1 a part's turn about the vertical is PLAY_TURN of the seating's and
## its slide across PLAY_SHIFT times it.
var play: float = 0.0
const PLAY_TURN := 0.15
const PLAY_SHIFT := 1.5
## How far each stud's logo and top differ from the next (photoreal8), set
## before [method stage]: 0 as before, 1 one stud's letters rubbed nearly
## flat and the next's full (path_tracer.glsl's stud_logo). It goes to the
## card with each part (its record's last number, 0 to 255), as the closest
## hit, which draws the logo, reads no scene.
var studs: float = 0.0
## How far each edge's rounding strays along it (photoreal13,
## RenderSettings.edge), set before [method stage]: 0 the same radius
## everywhere, 1 as a moulded part's (the radius straying, a nick here and
## there). It goes to the card with each part, as studs does (its record's
## last number, the byte above studs', in hundredths).
var edge: float = 0.0
## The stud's logo as the photographs show it (photoreal14,
## RenderSettings.logo), set before [method stage]: 0 as before, 1 its
## strokes thinner with gaps between the letters and one injection gate a
## part. It goes to the card with each part, as studs does (the byte above
## edge's, 0 to 255 of 1).
var logo: float = 0.0
## Whether the picture asks for the wear hands leave (photoreal9,
## RenderSettings.rubbed), set before [method stage]: it is then traced by
## the shader's "marks" version.
var marked: bool = false
## PRODUCT_ALBEDO by the colour a brick is drawn in (PartLibrary.shown_for
## of the table's): "r,g,b" (0-255) -> linear albedo. Made on first use.
var _fitted: Dictionary = {}
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
		return "Path tracing needs the desktop app, coming soon: a browser cannot trace rays."
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return "Path tracing needs the full graphics mode, and this window draws in the simpler one."
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
	_file = load("res://src/render/path_tracer.glsl") as RDShaderFile
	var resolve_file: RDShaderFile = load("res://src/render/path_tracer_resolve.glsl") as RDShaderFile
	if _file == null or resolve_file == null:
		return _refused("its shaders did not load")
	var made: Array = _pipeline_of("plain")
	if made.is_empty():
		return false
	_shader = made[0]
	_pipeline = made[1]
	_sbt = made[2]
	_range = made[3]
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
	var tile := RDSamplerState.new()
	tile.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	tile.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	tile.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	tile.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	_tile_sampler = _rd.sampler_create(tile)
	_holders += 1
	return true


## The shader's [param version] on the card: [shader, pipeline, its hit
## table, the table's range], or empty, refused.
func _pipeline_of(version: String) -> Array:
	var spirv: RDShaderSPIRV = _file.get_spirv(version)
	if spirv == null:
		_refused("its shader has no %s version" % version)
		return []
	for stage: String in ["raygen", "miss", "closest_hit"]:
		var error: String = spirv.get("compile_error_" + stage)
		if not error.is_empty():
			_refused("%s: %s" % [stage, error])
			return []
	var shader: RID = _rd.shader_create_from_spirv(spirv, "Path tracer" if version == "plain"
		else "Path tracer (%s)" % version)
	var raygen := RDPipelineShader.new()
	raygen.shader = shader
	var miss := RDPipelineShader.new()
	miss.shader = shader
	var closest := RDPipelineShader.new()
	closest.shader = shader
	var group := RDHitGroup.new()
	group.closest_hit_shader = closest
	var pipeline: RID = _rd.raytracing_pipeline_create([raygen], [miss], [group], 1)
	if not pipeline.is_valid():
		_rd.free_rid(shader)
		_refused("the card refused the pipeline")
		return []
	var sbt: RID = _rd.hit_sbt_create(pipeline, 1)
	var at: int = _rd.hit_sbt_range_alloc(sbt, 1)
	_rd.hit_sbt_range_update(sbt, at, 0, PackedInt32Array([0]))
	return [shader, pipeline, sbt, at]


## The "marks" version on the card (photoreal9), made the first time it is
## asked for. Its hit table's range is the plain one's, so the set's
## instances, which name the plain one's, are found in it.
func _make_marked() -> bool:
	if _marked_pipeline.is_valid():
		return true
	var made: Array = _pipeline_of("marks")
	if made.is_empty():
		return false
	_marked_shader = made[0]
	_marked_pipeline = made[1]
	_marked_sbt = made[2]
	if int(made[3]) != _range:
		return _refused("its marks' hit table is not the plain one's")
	return true


# -- the set -------------------------------------------------------------------


## The shape of one mesh on the card, made the first time it is staged,
## or asked for ahead (StudioRender asks a few a frame: each is the mesh
## read back from the card and a structure built, and the car's forty in
## one frame held the window half a second).
func shape_of(mesh: Mesh) -> Array:
	if _shapes.has(mesh):
		return _shapes[mesh]
	if not _make():
		return []
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
	var index_bytes: PackedByteArray = indices.to_byte_array()
	# The structure is built from each triangle's corners in turn, with no
	# index buffer. Godot 4.7.2 works out an index buffer's largest index
	# only in a debug build, so a release build's blas_create refused every
	# indexed shape as reaching past its vertices: Best in the 0.12.0
	# download traced nothing and was cancelled (2026-10-31), while the
	# editor, and every probe, traced. The hit shader finds a triangle's
	# corners by gl_PrimitiveID in its own index buffer, so triangle n is
	# the same triangle either way.
	var laid_out := PackedVector3Array()
	laid_out.resize(indices.size())
	for n: int in indices.size():
		laid_out[n] = points[indices[n]]
	var laid_out_bytes: PackedByteArray = laid_out.to_byte_array()
	var vertices: RID = _rd.vertex_buffer_create(laid_out_bytes.size(), laid_out_bytes, bits)
	var geometry := RDAccelerationStructureGeometry.new()
	geometry.vertex_buffer = vertices
	geometry.vertex_stride = 12
	geometry.vertex_count = laid_out.size()
	geometry.vertex_format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	geometry.flags = RenderingDevice.ACCELERATION_STRUCTURE_GEOMETRY_OPAQUE_BIT
	var blas: RID = _rd.blas_create([geometry],
		RenderingDevice.ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT)
	if not blas.is_valid() or _rd.blas_build(blas) != OK:
		push_error("path tracer: a shape of %d triangles was refused" % (indices.size() / 3))
		_shapes[mesh] = shape
		return shape
	shape = [blas, vertices, point_bytes, normals.to_byte_array(), index_bytes, points.size()]
	_shapes[mesh] = shape
	return shape


## Put the set on the card: every brick of [param batches] (the copy of the
## model's MultiMeshInstance3Ds), and [param sweep] when there is one.
## A part's place a hair off exact (seating), its own way by its [param number]:
## turned about its own origin, shifted across and lifted up.
## A placed part's own number, the same for every batch it is drawn in: a
## part with a print or a window is several batches, one per surface, each
## with its own instance, and all at the one place.
static func _part_key(place: Transform3D) -> int:
	var grid := Vector3.ONE * 0.0001
	return hash([place.origin.snapped(Vector3.ONE * 0.01), place.basis.x.snapped(grid),
		place.basis.y.snapped(grid), place.basis.z.snapped(grid)]) & 0x7fffffff


func _seated(place: Transform3D, key: int) -> Transform3D:
	if seating <= 0.0 or not product:
		return place
	var rng := RandomNumberGenerator.new()
	rng.seed = 2654435761 * (key + 1) + 97
	var turn := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-1.0, 1.0),
		rng.randf_range(-0.5, 0.5)) * deg_to_rad(SEAT_TURN) * seating
	var shift := Vector3(rng.randf_range(-1.0, 1.0) * SEAT_SHIFT, rng.randf() * SEAT_LIFT,
		rng.randf_range(-1.0, 1.0) * SEAT_SHIFT) * seating
	if play > 0.0:
		# As LEGO's own tolerance lets a part sit (photoreal8): its studs keep
		# it square to the next, and it slides a little across.
		turn.y *= lerpf(1.0, PLAY_TURN, play)
		shift.x *= lerpf(1.0, PLAY_SHIFT, play)
		shift.z *= lerpf(1.0, PLAY_SHIFT, play)
	return Transform3D(Basis.from_euler(turn) * place.basis, place.origin + shift)


## False when there is nothing to trace or no card to trace it on.
func stage(batches: Array, sweep: MeshInstance3D) -> bool:
	if not _make():
		return false
	if marked and not _make_marked():
		return false
	_free_picture_set()
	var shape_index: Dictionary = {}
	var shape_list: Array = []
	var records := PackedFloat32Array()
	var kinds := PackedInt32Array()
	var placed: Array[RDAccelerationStructureInstance] = []
	var stud_code: int = clampi(roundi(studs * 255.0), 0, 255) if product else 0
	if product:
		stud_code |= clampi(roundi(edge * 100.0), 0, 255) << 8
		stud_code |= clampi(roundi(logo * 255.0), 0, 255) << 16
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
		var shape: Array = shape_of(multimesh.mesh)
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
		# Where the part's studs begin (BrickWorld._body_top), and whether it
		# is moulded: the w of its box's two corners.
		var body_top: float = box_max.y
		if material != null and material.get_shader_parameter("part_body_top") != null:
			body_top = minf(float(material.get_shader_parameter("part_body_top")), box_max.y)
		var moulded: float = 1.0 if product else 0.0
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
			if product and kind == KIND_PLASTIC:
				lin = _fitted_albedo(colour, lin)
			var fleck: Color = Color(custom.r, custom.g, custom.b).srgb_to_linear()
			records.append_array([lin.r, lin.g, lin.b, colour.a,
				fleck.r, fleck.g, fleck.b, custom.a,
				box_min.x, box_min.y, box_min.z, body_top,
				box_max.x, box_max.y, box_max.z, moulded])
			var key: int = _part_key(whole * at)
			kinds.append_array([mesh_number, kind, key, stud_code])
			var instance := RDAccelerationStructureInstance.new()
			instance.blas = shape[0]
			instance.transform = _seated(whole * at, key)
			instance.id = placed.size()
			instance.mask = MASK_GLASS if kind == KIND_GLASS else MASK_SOLID
			instance.hit_sbt_range = _range
			instance.flags = RenderingDevice.ACCELERATION_STRUCTURE_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT
			placed.append(instance)
	if placed.is_empty():
		return false
	if sweep != null and sweep.is_visible_in_tree() and sweep.mesh != null:
		var shape: Array = shape_of(sweep.mesh)
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
		points.append_array(shape[2])
		normals.append_array(shape[3])
		corners.append_array(shape[4])
		vertex_base += int(shape[5])
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


## What a staged model stands on (photoreal7): [param image], a tile of a
## photographed surface, or null for none (a 2 x 2 white, unread).
func surface_with(image: Image) -> void:
	if image == _surface_for and _surface_texture.is_valid():
		return
	_free(_surface_texture)
	_surface_texture = RID()
	_surface_for = image
	var tile: Image = image
	if tile == null:
		tile = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		tile.fill(Color(1, 1, 1))
	elif tile.is_compressed() or tile.get_format() != Image.FORMAT_RGBA8:
		# StudioRender's tiles come RGBA8 already (read on a worker); any
		# other is made so here.
		tile = image.duplicate() as Image
		if tile.is_compressed():
			tile.decompress()
		tile.convert(Image.FORMAT_RGBA8)
	var format := RDTextureFormat.new()
	format.width = tile.get_width()
	format.height = tile.get_height()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_surface_texture = _rd.texture_create(format, RDTextureView.new(), [tile.get_data()])


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
	_free(_guide)
	_free(_picture)
	_trace_set = RID()
	_resolve_set = RID()
	_size = size
	var sums := RDTextureFormat.new()
	sums.width = size.x
	sums.height = size.y
	sums.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	sums.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_accum = _rd.texture_create(sums, RDTextureView.new())
	_guide = _rd.texture_create(sums, RDTextureView.new())
	var out := RDTextureFormat.new()
	out.width = size.x
	out.height = size.y
	out.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	out.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_picture = _rd.texture_create(out, RDTextureView.new())
	if not _accum.is_valid() or not _guide.is_valid() or not _picture.is_valid():
		return false
	_bind()
	return true


func _bind() -> void:
	_free(_trace_set)
	_free(_resolve_set)
	_free(_scene_buffer)
	if not _place_texture.is_valid():
		light_with(null)
	if not _surface_texture.is_valid():
		surface_with(null)
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
	uniforms.append(_uniform(10, RenderingDevice.UNIFORM_TYPE_IMAGE, [_guide]))
	uniforms.append(_uniform(11, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,
		[_tile_sampler, _surface_texture]))
	_trace_set = _rd.uniform_set_create(uniforms, _marked_shader if marked else _shader, 0)
	var resolving: Array[RDUniform] = [
		_uniform(0, RenderingDevice.UNIFORM_TYPE_IMAGE, [_accum]),
		_uniform(1, RenderingDevice.UNIFORM_TYPE_IMAGE, [_picture]),
		_uniform(2, RenderingDevice.UNIFORM_TYPE_IMAGE, [_guide])]
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


## Add [param count] samples to every pixel, or to [param rows] of them
## from [param row] down: they count once the last row has them, so a
## sample of a big picture can be spread over frames. The card does the
## work after this frame's own drawing; nothing waits for it here.
func trace(count: int, seed: int = 0, row: int = 0, rows: int = 0) -> void:
	if not _trace_set.is_valid() or count <= 0 or row >= _size.y:
		return
	var band: int = _size.y - row if rows <= 0 else mini(rows, _size.y - row)
	_rd.capture_timestamp("PathTracer %d %d" % [get_instance_id(), _size.x * band * count])
	var push := PackedByteArray()
	push.resize(32)
	push.encode_u32(0, samples)
	push.encode_u32(4, count)
	push.encode_u32(8, seed)
	push.encode_u32(12, 1 if samples == 0 else 0)
	push.encode_u32(16, row)
	var list: int = _rd.raytracing_list_begin()
	_rd.raytracing_list_bind_raytracing_pipeline(list, _marked_pipeline if marked else _pipeline)
	_rd.raytracing_list_bind_uniform_set(list, _trace_set, 0)
	_rd.raytracing_list_set_push_constant(list, push, push.size())
	_rd.raytracing_list_trace_rays(list, 0, _marked_sbt if marked else _sbt, _size.x, band, 1)
	_rd.raytracing_list_end()
	_rd.capture_timestamp("PathTracer %d" % get_instance_id())
	if row + band >= _size.y:
		samples += count


## What a pixel's sample took on the card in the last pass it has timed,
## in ms, a few frames after the pass; -1 when there is nothing new.
func sample_ms() -> float:
	if _rd.get_captured_timestamps_frame() == _timed_frame:
		return -1.0
	var mine: String = "PathTracer %d" % get_instance_id()
	var began: int = -1
	var work: int = 0
	for n: int in _rd.get_captured_timestamps_count():
		var name: String = _rd.get_captured_timestamp_name(n)
		if name.begins_with(mine + " "):
			began = _rd.get_captured_timestamp_gpu_time(n)
			work = name.trim_prefix(mine + " ").to_int()
		elif name == mine and began >= 0 and work > 0:
			_timed_frame = _rd.get_captured_timestamps_frame()
			# The card's times are in nanoseconds.
			return float(_rd.get_captured_timestamp_gpu_time(n) - began) / 1.0e6 / float(work)
	return -1.0


## The picture so far, exposed by [param exposure] and tone-mapped
## ([param tonemapper]: 2 Filmic, 3 ACES, 4 a camera's, at [param white]), with the
## product look's [param contrast] and [param saturation] after; the camera's
## response saturates by [param linear_saturation] in linear light first.
## [param camera] is the product look's camera on a backdrop (photoreal4): its
## sensor's noise in 8-bit levels, the light its lens loses at a corner, its
## colour fringes in pixels at a corner, and how soft it draws an edge
## (RenderSettings.grain, vignette, aberration, softness); zero for none.
## [param sharpen] is its processing's sharpening (RenderSettings.sharpen,
## photoreal6): the share of an edge's step added back after the curve.
func picture(exposure: float, tonemapper: int, white: float, contrast: float = 1.0,
		saturation: float = 1.0, transparent: bool = false, dither: bool = true,
		denoise: float = 0.0, linear_saturation: float = 1.0,
		camera: Vector4 = Vector4.ZERO, sharpen: float = 0.0, tone: float = 0.0) -> Image:
	if not _resolve_set.is_valid() or samples <= 0:
		return null
	var push := PackedFloat32Array([float(samples), exposure, white, float(tonemapper),
		contrast, saturation, 1.0 if transparent else 0.0, 1.0 if dither else 0.0,
		denoise, linear_saturation, camera.x, camera.y, camera.z, camera.w, sharpen, tone])
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


## The running sum's mean, the light each pixel saw before any exposure or
## tone curve (RGBAF, alpha the coverage), for the photo bench's colour
## measure (photoreal_probe --raw). Null when there is none.
func mean_image() -> Image:
	if not _accum.is_valid() or samples <= 0:
		return null
	var data: PackedByteArray = _rd.texture_get_data(_accum, 0)
	if data.size() != _size.x * _size.y * 16:
		return null
	var floats: PackedFloat32Array = data.to_float32_array()
	var share: float = 1.0 / float(samples)
	for n: int in floats.size():
		floats[n] *= share
	return Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBAF,
		floats.to_byte_array())


## The product look's albedo for a solid colour drawn [param colour]: the
## photographs' fit where PRODUCT_ALBEDO has one, else [param own].
func _fitted_albedo(colour: Color, own: Color) -> Color:
	if _fitted.is_empty():
		for key: String in PRODUCT_ALBEDO:
			var rgb: PackedStringArray = key.split(",")
			var shown: Color = PartLibrary.shown_for(Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])))
			_fitted[_byte_key(shown)] = PRODUCT_ALBEDO[key]
	return _fitted.get(_byte_key(colour), own)


static func _byte_key(colour: Color) -> String:
	return "%d,%d,%d" % [roundi(colour.r * 255.0), roundi(colour.g * 255.0), roundi(colour.b * 255.0)]


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
	for rid: RID in [_accum, _guide, _picture, _place_texture, _place_table, _surface_texture]:
		_free(rid)
	if _pipeline.is_valid():
		_holders -= 1
	if _holders <= 0:
		_holders = 0
		for shape: Array in _shapes.values():
			if not shape.is_empty():
				for rid: RID in [shape[0], shape[1]]:
					_free(rid)
		_shapes.clear()
	for rid: RID in [_sbt, _pipeline, _resolve_pipeline, _shader, _resolve_shader, _sampler,
			_tile_sampler, _marked_sbt, _marked_pipeline, _marked_shader]:
		_free(rid)
	_pipeline = RID()
	_marked_pipeline = RID()
	_marked_sbt = RID()
	_marked_shader = RID()
	_rd = null
