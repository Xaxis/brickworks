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
## The work is spread across frames deliberately, a few previews a frame,
## each in a stage of its own (see [constant STAGES]): a preview is drawn in
## a frame of the whole window, model and all, and drawn one a frame a
## screenful of the bin took 25 to 45 s to fill in a browser drawing in
## software (2026-10-13).
##
## What is drawn, and in what order, is what is in sight. A grid tells
## [method watch] which of its [ThumbTile]s are on screen, nearest the eye
## first, and those are drawn before anything else and handed their
## pictures. The bin used to ask for every cell of a 120-cell page the
## moment the page was made, in list order, so after a fast scroll the
## screen being looked at waited behind every page scrolled past on the
## way to it — and on the web each of those was a network fetch first.
##
## The tiles just out of sight, which a grid also names so that a scroll
## finds them drawn, are drawn only in a frame being drawn anyway. A
## preview is a frame of the whole window, model and all: the first part
## taken in hand resized the bin's palette, a dozen tiles below the fold
## came into the grid's next screenful, and their pictures drew the window
## again a dozen times while nothing on it changed — 23 s of a software
## renderer drawing the castle with the pointer still (idle_probe, 2026-10-13).
class_name PartThumbnails
extends Node

const SIZE := 96
## How many previews can be drawn in one frame: one per stage, each its own
## viewport, camera and holder. One shared viewport drew one a frame, since
## two started at once both wrote to it and both read back the second's
## picture: half the bin showed the wrong part. A preview is a 96-pixel
## square; the frame it is drawn in is the whole window, and in a browser
## drawing in software that frame is the whole model too, and the drawing
## is held until it is drawn (GpuFence): over Orthanc, 13 to 14 s a frame on
## a loaded machine, and eight at a time the first screenful of the bin held
## the drawing 37 s (2026-10-15, its fences timed in Chromium). A screenful
## is about thirty, so it is drawn in one frame.
const STAGES := 32
## Beyond this many cached textures the least recently used are dropped.
## A page holds about 40; this is enough for a good deal of scrollback.
const CACHE_LIMIT := 600
## How long a part that could not be drawn is left alone before a tile
## that comes into sight for it tries again. A fetch can fail for a
## moment's reason, and "no preview" for the rest of the session over one
## dropped connection would be wrong; trying on every scroll would be a
## request a frame for a part that is simply not there.
const RETRY_MSEC := 30000
## The most jobs taken in one frame when none of them starts a draw. A
## job whose geometry is not here yet only asks for it; taking those one
## a frame meant a screen of unfetched parts on a browser drawing a frame
## a second sent its last request forty seconds after its first.
const ASKS_PER_FRAME := 32

## A viewport a preview is drawn in, with its own world, lights, camera and
## holder, and whether a preview is being drawn in it.
class Stage extends RefCounted:
	var viewport: SubViewport
	var camera: Camera3D
	var holder: MeshInstance3D
	var material: ShaderMaterial
	var environment: Environment
	var key_light: DirectionalLight3D
	var fill_light: DirectionalLight3D
	## The surfaces past the first, drawn only for a preview that asks for
	## its print. One holder each, in its own fixed colour.
	var print_holders: Array[MeshInstance3D] = []
	var busy: bool = false


var library: PartLibrary

var _stages: Array[Stage] = []

var _cache: Dictionary = {}        ## String key -> ImageTexture
var _order: Array[String] = []     ## least recently used first
var _queue: Array[Dictionary] = []
var _queued: Dictionary = {}       ## key -> true, so nothing queues twice
## Parts whose geometry is on its way. The colour is not kept: a part
## fetched for one swatch is wanted for whichever is selected when it
## arrives, and the tiles in sight say which that is.
var _awaiting: Dictionary = {}
## Parts that could not be drawn -> when that was found, in msec.
var _failed: Dictionary = {}
## The previews being drawn now, by key, so that a tile is not given to two
## stages at once.
var _drawing: Dictionary = {}
## Who has tiles in sight, the one that last moved first: [owner's
## instance id, Array[ThumbTile] in the order to draw them].
var _watching: Array[Array] = []
## Something has changed since the tiles in sight were last looked
## through: a scroll, a picture, a part arriving or failing. Without it
## an idle bin would walk its tiles every frame to find nothing to do. It
## stays up while a tile out of sight waits for a frame drawn anyway.
var _look: bool = false
## Fetches have been asked for, or the tiles in sight have changed, since
## the library's queue was last put in their order.
var _reorder: bool = false


func _ready() -> void:
	# After every other node's _process, so that whether the frame is drawn
	# anyway is known (see _process).
	process_priority = 1000
	# Geometry that arrives after a preview was asked for has to put the
	# work back on the queue, or the cell stays empty for ever having
	# been one frame too early.
	if library != null and not library.fetched.is_connected(_on_geometry_arrived):
		library.fetched.connect(_on_geometry_arrived)
		library.fetch_failed.connect(_on_fetch_failed)

	for _n: int in STAGES:
		_stages.append(_stage())


func _stage() -> Stage:
	var stage := Stage.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	# Drawn on demand, not every frame: most frames render nothing.
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = true
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
	stage.environment = environment
	viewport.world_3d = world

	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	stage.viewport = viewport

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.5
	camera.far = 8000.0
	viewport.add_child(camera)
	stage.camera = camera

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	key_light.light_energy = 2.0
	viewport.add_child(key_light)
	stage.key_light = key_light

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-14.0, 132.0, 0.0)
	fill_light.light_energy = 0.7
	fill_light.light_color = Color(0.86, 0.9, 1.0)
	viewport.add_child(fill_light)
	stage.fill_light = fill_light

	var material := ShaderMaterial.new()
	material.shader = BrickWorld.SHADERS["opaque"]
	material.set_shader_parameter("linearise", BrickWorld._linearise_colors())
	stage.material = material

	var holder := MeshInstance3D.new()
	holder.material_override = material
	viewport.add_child(holder)
	stage.holder = holder
	return stage


## Less light on a light part.
##
## The lights are set for the middle of the palette, and on white they
## burn every face to the same white: a white 1 x 2 with studs on its
## sides was a flat silhouette with no studs, no top and no sides. Turned
## down as the colour gets lighter, so the faces part again; a dark part
## keeps all of it.
static func _light_for(stage: Stage, colour: Color) -> void:
	var tame: float = 1.0 - 0.42 * clampf((colour.get_luminance() - 0.5) / 0.45, 0.0, 1.0)
	stage.environment.ambient_light_energy = 1.35 * tame
	stage.key_light.light_energy = 2.0 * tame
	stage.fill_light.light_energy = 0.7 * tame


static func _print_holder(stage: Stage, n: int) -> MeshInstance3D:
	while stage.print_holders.size() <= n:
		var holder := MeshInstance3D.new()
		var material := ShaderMaterial.new()
		material.shader = BrickWorld.SHADERS["opaque"]
		material.set_shader_parameter("linearise", BrickWorld._linearise_colors())
		holder.material_override = material
		stage.viewport.add_child(holder)
		stage.print_holders.append(holder)
	return stage.print_holders[n]


func _process(_delta: float) -> void:
	# Whether this frame is being drawn whatever happens here: every frame
	# is, unless only what changed is drawn (IdleDraw), and then it is if
	# something else has changed what is on the screen. Asked after every
	# other node's _process (see _ready), which is what has made the changes.
	var drawn_anyway: bool = not OS.low_processor_usage_mode or RenderingServer.has_changed()
	# A draw in each stage that is free.
	#
	# _render is a coroutine: it sets its stage's holder, tint and camera,
	# then waits for a draw. Two in one stage both wrote to its viewport
	# and both woke on the same draw, so they read back the same image —
	# the second job's — and the first cached it under its own key: half
	# the bin showed the wrong part, and which half changed with the
	# scroll. So a stage takes one job at a time.
	#
	# A job that only asks for geometry starts no draw, so the next is
	# taken in the same frame. And a frame that draws tiles in sight draws
	# no tile out of sight: those are drawn after, nearest first.
	var in_sight: bool = false
	for _n: int in ASKS_PER_FRAME:
		var stage: Stage = _free_stage()
		if stage == null:
			break
		var job: Dictionary = _next_job(drawn_anyway)
		if job.is_empty():
			break
		if in_sight and not bool(job.get("in_sight", true)):
			break
		in_sight = in_sight or bool(job.get("in_sight", true))
		_render(job, stage)
	if _reorder:
		_reorder = false
		_prefer_in_sight()


func _free_stage() -> Stage:
	for stage: Stage in _stages:
		if not stage.busy:
			return stage
	return null


## The tiles a view has in sight, in the order it wants them drawn.
## Replaces whatever that view said before; an empty list says it has
## nothing in sight, as a view that closes or folds away should.
##
## The view most recently moved comes first: it is the one being used.
func watch(owner: Object, tiles: Array[ThumbTile]) -> void:
	var id: int = owner.get_instance_id()
	for n: int in _watching.size():
		if int(_watching[n][0]) == id:
			_watching.remove_at(n)
			break
	if not tiles.is_empty():
		_watching.push_front([id, tiles])
	_look = true
	_reorder = true


## The next preview to draw: the first tile in sight still waiting, then
## anything asked for through [method request]. Tiles whose picture is
## already to hand, or whose part cannot be drawn, are settled on the way.
## A tile out of sight waits for a frame [param drawn_anyway].
func _next_job(drawn_anyway: bool = true) -> Dictionary:
	if _look:
		var now: int = Time.get_ticks_msec()
		var put_off: bool = false
		for entry: Array in _watching:
			# Untyped until checked: a view that has just rebuilt its grid
			# has not said so yet, and its old tiles are already freed.
			for item: Variant in entry[1]:
				if not is_instance_valid(item):
					continue
				var tile: ThumbTile = item
				if tile.state != ThumbTile.State.LOADING:
					continue
				# Out of sight, its picture drawn and handed over only in a
				# frame drawn anyway: handed over, a tile is drawn again.
				if not tile.in_sight and not drawn_anyway:
					put_off = true
					continue
				var key: String = tile.key()
				if _drawing.has(key):
					continue
				if _cache.has(key):
					_touch(key)
					# Faded in where it can be seen; out of sight a fade is
					# a fifth of a second of frames nobody sees.
					tile.show_picture(_cache[key], tile.in_sight)
					continue
				if _awaiting.has(tile.part_id):
					continue
				if _failed.has(tile.part_id):
					if now - int(_failed[tile.part_id]) < RETRY_MSEC:
						tile.show_failed()
						continue
					_failed.erase(tile.part_id)
				return {"part": tile.part_id, "color": tile.color_code, "key": key,
					"printed": tile.printed, "in_sight": tile.in_sight}
		# Looked at again next frame while a tile out of sight waits.
		_look = put_off
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		if not _cache.has(job["key"]) and not _drawing.has(job["key"]):
			return job
		_queued.erase(job["key"])
	return {}


## The library fetches in the order it was asked, and it was asked in the
## order tiles came into sight — so after a scroll, the parts for the
## screen now showing would wait behind every part asked for on the way
## there. Put the ones in sight first.
func _prefer_in_sight() -> void:
	if library == null or _awaiting.is_empty():
		return
	var wanted := PackedStringArray()
	for entry: Array in _watching:
		for item: Variant in entry[1]:
			if not is_instance_valid(item):
				continue
			var tile: ThumbTile = item
			if tile.state == ThumbTile.State.LOADING and _awaiting.has(tile.part_id):
				wanted.append(tile.part_id)
	library.prefer(wanted)


## A preview for a part, if one is already cached.
##
## Returns null and queues the work otherwise, behind the tiles in
## sight; ask again. For a picture wanted outside a grid. A grid's tiles
## go through [method watch], which draws what is on screen first.
##
## [param printed] draws the part's print as well. The bin leaves it off
## (see _render); a minifigure's head is chosen by its face, and every
## printed head drawn without its print is the same yellow blank.
func request(part_id: String, color_code: int, printed: bool = false) -> ImageTexture:
	var key: String = key_for(part_id, color_code, printed)
	if _cache.has(key):
		_touch(key)
		return _cache[key]
	if not _queued.has(key):
		_queued[key] = true
		_queue.append({"part": part_id, "color": color_code, "key": key,
			"printed": printed})
	return null


## A preview already drawn, or null. Asks for nothing: a tile made with
## its picture to hand shows it at once, and one without waits to be in
## sight.
func peek(part_id: String, color_code: int, printed: bool = false) -> ImageTexture:
	var key: String = key_for(part_id, color_code, printed)
	if not _cache.has(key):
		return null
	_touch(key)
	return _cache[key]


static func key_for(part_id: String, color_code: int, printed: bool = false) -> String:
	return "%s:%d%s" % [part_id, color_code, ":printed" if printed else ""]


func _on_geometry_arrived(part_id: String) -> void:
	if not _awaiting.has(part_id):
		return
	_awaiting.erase(part_id)
	# Drawn in whichever colour the tiles in sight want now rather than
	# the one wanted when the fetch started, which may be several
	# swatches ago.
	_look = true


func _on_fetch_failed(part_id: String, _why: String) -> void:
	_fail(part_id)


## No picture can be had for this part. The tiles waiting on it say so
## the next time the tiles in sight are looked through.
func _fail(part_id: String) -> void:
	_awaiting.erase(part_id)
	_failed[part_id] = Time.get_ticks_msec()
	_look = true


## Drop anything not on screen. Called when a view closes.
func trim(keep: PackedStringArray) -> void:
	var wanted: Dictionary = {}
	for key: String in keep:
		wanted[key] = true
	for key: String in _cache.keys():
		if not wanted.has(key):
			_cache.erase(key)
			_order.erase(key)


func cached_count() -> int:
	return _cache.size()


func _touch(key: String) -> void:
	_order.erase(key)
	_order.append(key)


func _render(job: Dictionary, stage: Stage) -> void:
	var key: String = job["key"]
	_queued.erase(key)
	if library == null or _cache.has(key) or _drawing.has(key):
		return

	var part: Lbm.PartMesh = library.mesh_for(job["part"])
	if part == null:
		# On the web most parts are a request away rather than absent, and
		# giving up here left the bin showing a few hundred previews and
		# twenty-eight thousand empty squares. Ask for the geometry and
		# come back when it lands; the library caps how many are in the
		# air at once, so a scroll does not open a connection per cell.
		if library.request_mesh(job["part"]):
			_awaiting[job["part"]] = true
			_reorder = true
		else:
			_fail(job["part"])
		return
	if part.surfaces.is_empty():
		# Geometry that is here and has nothing in it. Asking for it again
		# was answered at once from the cache with "fetched", before the
		# part had been marked as waiting, so its cell waited for ever.
		_fail(job["part"])
		return

	# Surface 0 is the recolourable one on almost every part, and a
	# printed part's fixed-colour detail is left off the thumbnail —
	# which reads better at 96 pixels than the print would anyway.
	#
	# "Almost" is the whole of it. 649 parts have no recolourable
	# surface at all, every one of them a sticker, and for those surface
	# 0 carries its own moulded colour. Tinting it anyway repainted a
	# Denmark flag in whatever swatch happened to be selected.
	stage.holder.mesh = part.surfaces[0]

	var moulded: int = part.surface_colors[0]
	var shown: int = int(job["color"]) if moulded == Lbm.COLOR_INHERIT else moulded
	var color: PartLibrary.BrickColor = library.color(shown)
	# The shader takes the colour through COLOR, which a lone MeshInstance
	# has no instance data for — so it rides in as a material tint here.
	stage.material.set_shader_parameter("tint_override", color.shown)
	stage.material.set_shader_parameter("finish_override", color.instance_custom)
	_light_for(stage, color.shown)

	var printed: bool = bool(job.get("printed", false))
	for holder: MeshInstance3D in stage.print_holders:
		holder.visible = false
	if printed:
		for n: int in range(1, part.surfaces.size()):
			var holder: MeshInstance3D = _print_holder(stage, n - 1)
			holder.mesh = part.surfaces[n]
			var own: int = part.surface_colors[n]
			var ink: PartLibrary.BrickColor = library.color(
				int(job["color"]) if own == Lbm.COLOR_INHERIT else own)
			# A print drawn in the app is a picture on the surface.
			if not holder.has_meta("plain"):
				holder.set_meta("plain", holder.material_override)
			holder.material_override = holder.get_meta("plain")
			if part.prints.has(n):
				holder.material_override = PartPrints.material_for(
					holder.material_override, part.prints[n], false)
			var material: ShaderMaterial = holder.material_override
			material.set_shader_parameter("tint_override", ink.shown)
			material.set_shader_parameter("finish_override", ink.instance_custom)
			holder.visible = true

	_frame(stage.camera, part.bounds, printed)

	stage.busy = true
	_drawing[key] = true
	stage.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	# Read back once the card has drawn it (GpuFence, as ModelShot reads):
	# sooner, the read waits for it on the page's one thread, and a browser
	# drawing in software held the page eight seconds over the first page
	# of the bin (2026-10-12). The tiles still to come say so themselves;
	# a line in the status bar as well came and went with every scroll and
	# drew the whole window again for it.
	await GpuFence.finished()

	var image: Image = stage.viewport.get_texture().get_image()
	stage.busy = false
	_drawing.erase(key)
	var texture: ImageTexture = ImageTexture.create_from_image(image)

	_cache[key] = texture
	_touch(key)
	while _order.size() > CACHE_LIMIT:
		var oldest: String = _order.pop_front()
		_cache.erase(oldest)

	# Handed over by the next look through the tiles in sight, which is
	# also where the next job is found: every tile waiting on this key,
	# in every view, gets it.
	_look = true


## Point the camera at the part from a three-quarter view, sized so the
## part fills the frame whatever its extent — a 1x1 plate and a 32x32
## baseplate both want to read at 96 pixels.
##
## A print is looked at nearer face on: it is on a figure's front, and
## from three-quarters a face is half a face.
static func _frame(camera: Camera3D, bounds: AABB, printed: bool = false) -> void:
	var centre: Vector3 = bounds.get_center()
	var radius: float = maxf(bounds.size.length() * 0.5, 4.0)

	var direction := Vector3(0.72, 0.52, 0.86).normalized()
	if printed:
		direction = Vector3(0.34, 0.26, 0.9).normalized()
	camera.global_position = centre + direction * (radius * 4.0 + 80.0)
	camera.look_at(centre, Vector3.UP)
	# A little margin so nothing touches the edge of the cell.
	camera.size = radius * 2.12
