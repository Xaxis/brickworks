## Renders part previews on demand, a few per frame.
##
## A parts bin needs a picture of each part, and there are 24,731 of them.
## Shipping pre-rendered images is out: even at 8 kB a thumbnail that is
## 200 MB, it would have to be regenerated whenever the look changed, and
## it would still be wrong for the 322 colours each part comes in.
##
## So previews are rendered live, from the same geometry the scene uses,
## into a small [SubViewport]. Only what is on screen is ever drawn —
## thirty or so at a time — and the results are cached by part and colour.
##
## The work is spread across frames deliberately. Rendering thirty parts
## in one frame drops it visibly; rendering two per frame fills a scrolled
## page in a quarter of a second and never stutters.
class_name PartThumbnails
extends Node

const SIZE := 96
## How many previews to render per frame. Two is under a millisecond and
## keeps a fast scroll filling in without the frame time moving.
## Nothing is gained by starting more than one, and something is lost:
## see _process. Kept as a constant so the reason stays written down.
const PER_FRAME := 1
## Beyond this many cached textures the least recently used are dropped.
## A page holds about 40; this is enough for a good deal of scrollback.
const CACHE_LIMIT := 600

var library: PartLibrary

var _viewport: SubViewport
var _camera: Camera3D
var _holder: MeshInstance3D
var _material: ShaderMaterial

var _cache: Dictionary = {}        ## String key -> ImageTexture
var _order: Array[String] = []     ## least recently used first
var _queue: Array[Dictionary] = []
var _queued: Dictionary = {}       ## key -> true, so nothing queues twice
## Parts whose geometry is on its way. The colour is not kept: a part
## fetched for one swatch is wanted for whichever is selected when it
## arrives, and re-queueing by part id covers both.
var _awaiting: Dictionary = {}
## True while a preview is waiting on a draw. The viewport, its camera
## and its one mesh holder are shared, so a second job started now would
## overwrite what the first is about to read.
var _drawing: bool = false

## Emitted when a preview someone asked for is ready.
## A part's geometry landed; whoever asked for a preview should ask
## again. Kept separate from [signal ready_for], which carries a texture.
signal geometry_arrived(part_id: String)

signal ready_for(part_id: String, color_code: int, texture: ImageTexture)


func _ready() -> void:
	# Geometry that arrives after a preview was asked for has to put the
	# work back on the queue, or the cell stays empty for ever having
	# been one frame too early.
	if library != null and not library.fetched.is_connected(_on_geometry_arrived):
		library.fetched.connect(_on_geometry_arrived)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	# Drawn on demand, not every frame: most frames render nothing.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.transparent_bg = true
	# The previews want their own lights, not the model's, so the viewport
	# gets its own world. Assigning one is enough on its own — also
	# setting own_world_3d makes Godot create a second world and then
	# strip the scenario from the first, which it complains about.
	# It has to happen before the node enters the tree: the world is only
	# created on entry, so reading world_3d beforehand gives null.
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.88, 0.94)
	environment.ambient_light_energy = 1.35
	world.environment = environment
	_viewport.world_3d = world

	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.5
	_camera.far = 8000.0
	_viewport.add_child(_camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	key_light.light_energy = 2.0
	_viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-14.0, 132.0, 0.0)
	fill_light.light_energy = 0.7
	fill_light.light_color = Color(0.86, 0.9, 1.0)
	_viewport.add_child(fill_light)

	_material = ShaderMaterial.new()
	_material.shader = BrickWorld.SHADERS["opaque"]
	_material.set_shader_parameter("linearise", BrickWorld._linearise_colors())

	_holder = MeshInstance3D.new()
	_holder.material_override = _material
	_viewport.add_child(_holder)


## The surfaces past the first, drawn only for a preview that asks for
## its print. One holder each, in its own fixed colour.
var _print_holders: Array[MeshInstance3D] = []


func _print_holder(n: int) -> MeshInstance3D:
	while _print_holders.size() <= n:
		var holder := MeshInstance3D.new()
		var material := ShaderMaterial.new()
		material.shader = BrickWorld.SHADERS["opaque"]
		material.set_shader_parameter("linearise", BrickWorld._linearise_colors())
		holder.material_override = material
		_viewport.add_child(holder)
		_print_holders.append(holder)
	return _print_holders[n]


func _process(_delta: float) -> void:
	# One at a time, and only once the last one has finished.
	#
	# _render is a coroutine: it sets the holder's mesh, the tint and
	# the camera, then waits for a draw. Starting two of them meant both
	# wrote to the one shared viewport and both woke on the same draw,
	# so they read back the same image — the second job's — and the
	# first cached it under its own key. Half the bin showed the wrong
	# part, and which half changed with the scroll.
	if _drawing or _queue.is_empty():
		return
	_render(_queue.pop_front())


## A preview for a part, if one is already cached.
##
## Returns null and queues the work otherwise; listen for [signal
## ready_for]. Callers want a texture *now* to fill a grid cell, and a
## placeholder that fills in shortly is better than a stalled frame.
##
## [param printed] draws the part's print as well. The bin leaves it off
## (see _render); a minifigure's head is chosen by its face, and every
## printed head drawn without its print is the same yellow blank.
func request(part_id: String, color_code: int, printed: bool = false) -> ImageTexture:
	var key: String = "%s:%d%s" % [part_id, color_code, ":printed" if printed else ""]
	if _cache.has(key):
		_touch(key)
		return _cache[key]
	if not _queued.has(key):
		_queued[key] = true
		_queue.append({"part": part_id, "color": color_code, "key": key,
			"printed": printed})
	return null


func _on_geometry_arrived(part_id: String) -> void:
	if not _awaiting.has(part_id):
		return
	_awaiting.erase(part_id)
	# Re-queued for whichever colour is wanted now rather than the one
	# that was wanted when the fetch started, which may be several
	# swatches ago.
	geometry_arrived.emit(part_id)


## Drop anything not on screen. Called when a view closes.
func trim(keep: PackedStringArray) -> void:
	var wanted: Dictionary = {}
	for key: String in keep:
		wanted[key] = true
	for key: String in _cache.keys():
		if not wanted.has(key):
			_cache.erase(key)
			_order.erase(key)


func clear_queue() -> void:
	_queue.clear()
	_queued.clear()


func cached_count() -> int:
	return _cache.size()


func _touch(key: String) -> void:
	_order.erase(key)
	_order.append(key)


func _render(job: Dictionary) -> void:
	var key: String = job["key"]
	_queued.erase(key)
	if library == null or _cache.has(key):
		return

	var part: Lbm.PartMesh = library.mesh_for(job["part"])
	if part == null or part.surfaces.is_empty():
		# On the web most parts are a request away rather than absent, and
		# giving up here left the bin showing a few hundred previews and
		# twenty-eight thousand empty squares. Ask for the geometry and
		# come back when it lands; the library caps how many are in the
		# air at once, so a scroll does not open a connection per cell.
		if library.request_mesh(job["part"]):
			_awaiting[job["part"]] = true
		return

	# Surface 0 is the recolourable one on almost every part, and a
	# printed part's fixed-colour detail is left off the thumbnail —
	# which reads better at 96 pixels than the print would anyway.
	#
	# "Almost" is the whole of it. 649 parts have no recolourable
	# surface at all, every one of them a sticker, and for those surface
	# 0 carries its own moulded colour. Tinting it anyway repainted a
	# Denmark flag in whatever swatch happened to be selected.
	_holder.mesh = part.surfaces[0]

	var moulded: int = part.surface_colors[0]
	var shown: int = int(job["color"]) if moulded == Lbm.COLOR_INHERIT else moulded
	var color: PartLibrary.BrickColor = library.color(shown)
	# The shader takes the colour through COLOR, which a lone MeshInstance
	# has no instance data for — so it rides in as a material tint here.
	_material.set_shader_parameter("tint_override", color.shown)
	_material.set_shader_parameter("finish_override", color.instance_custom)

	var printed: bool = bool(job.get("printed", false))
	for n: int in _print_holders.size():
		_print_holders[n].visible = false
	if printed:
		for n: int in range(1, part.surfaces.size()):
			var holder: MeshInstance3D = _print_holder(n - 1)
			holder.mesh = part.surfaces[n]
			var own: int = part.surface_colors[n]
			var ink: PartLibrary.BrickColor = library.color(
				int(job["color"]) if own == Lbm.COLOR_INHERIT else own)
			var material: ShaderMaterial = holder.material_override
			material.set_shader_parameter("tint_override", ink.shown)
			material.set_shader_parameter("finish_override", ink.instance_custom)
			holder.visible = true

	_frame(part.bounds, printed)

	_drawing = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var image: Image = _viewport.get_texture().get_image()
	_drawing = false
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	_cache[key] = texture
	_touch(key)
	while _order.size() > CACHE_LIMIT:
		var oldest: String = _order.pop_front()
		_cache.erase(oldest)

	ready_for.emit(job["part"], job["color"], texture)


## Point the camera at the part from a three-quarter view, sized so the
## part fills the frame whatever its extent — a 1x1 plate and a 32x32
## baseplate both want to read at 96 pixels.
##
## A print is looked at nearer face on: it is on a figure's front, and
## from three-quarters a face is half a face.
func _frame(bounds: AABB, printed: bool = false) -> void:
	var centre: Vector3 = bounds.get_center()
	var radius: float = maxf(bounds.size.length() * 0.5, 4.0)

	var direction := Vector3(0.72, 0.52, 0.86).normalized()
	if printed:
		direction = Vector3(0.34, 0.26, 0.9).normalized()
	_camera.global_position = centre + direction * (radius * 4.0 + 80.0)
	_camera.look_at(centre, Vector3.UP)
	# A little margin so nothing touches the edge of the cell.
	_camera.size = radius * 2.12
