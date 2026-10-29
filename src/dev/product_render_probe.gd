## Does File, Render…'s Product look draw, each backdrop as named, and leave
## the window as it was?
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x800 \
##       --script src/dev/product_render_probe.gd
##
## Forward+ on the graphics card, where the look has everything it is made
## of. A small scene (a plate, a red tower, a slope, a chrome round, a clear
## brick, a blue column) drawn with RenderSettings.look "product", and asked:
##
##   the copy of the model a render draws is in the product shaders, and
##     the window's own model never is;
##   it draws, and differs from the window's look of the same shot;
##   each of render_model's backdrops comes out as named: white white to
##     its corners, gradient bright under the model and falling away to its
##     corners, dark dark;
##   depth of field softens the picture;
##   the window's frame costs what it did before (its own measured time on
##     the card, the median of 120 frames, before and after), with its
##     environment as it was.
##
## Leaves shots/render/product_*.png to look at.
extends SceneTree

const OUT := "res://shots/render/"

var _failures: int = 0
var _main: Node
var _render: StudioRender
var _world: BrickWorld


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	_world = _main.get("_world")
	var library: PartLibrary = _main.get("_library")
	if _world == null or library == null or library.parts.is_empty():
		print("  FAIL  no world or no catalogue")
		quit(1)
		return
	var method: String = RenderingServer.get_current_rendering_method()
	print("  renderer: %s" % method)
	if method != "forward_plus":
		print("product_render probe: SKIPPED, it needs Forward+ (run it on the GPU)")
		quit(0)
		return
	(_main.get("_builder") as Builder).hide_preview()
	_build_scene(library)
	for _n: int in 30:
		await process_frame

	var environment: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var window_look: Array = [environment.tonemap_mode, environment.ssil_enabled,
		environment.adjustment_enabled, environment.sky]
	var before: float = await _window_frame_ms()
	print("  the window's frame on the card before: %.3f ms" % before)

	_render = StudioRender.new()
	_render.library = library
	_render.scenery = (_main.get("_store") as ModelStore).scenery
	_render.eye = _main.get("_camera")
	_render.look = environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)

	# The window's look and the product look of one shot.
	var window_shot: Image = await _render.render(_world, _settings("window", "white"))
	var product_shot: Image = await _render.render(_world, _settings("product", "white"))
	_say("the product look draws a picture", product_shot != null
		and product_shot.get_size() == Vector2i(480, 270))
	if window_shot == null or product_shot == null:
		quit(1)
		return
	product_shot.save_png(OUT + "product_white.png")
	window_shot.save_png(OUT + "product_window_look.png")
	var stage: BrickWorld = _render.get("_stage")
	var shaders: Array = BrickWorld.PRODUCT_SHADERS.values()
	var batches: int = 0
	var in_product: int = 0
	for child: Node in stage.get_children():
		var batch := child as MultiMeshInstance3D
		if batch == null or batch.material_override == null:
			continue
		batches += 1
		if (batch.material_override as ShaderMaterial).shader in shaders:
			in_product += 1
	_say("every batch of the render's copy is in a product shader, %d of %d" % [in_product,
		batches], batches > 0 and in_product == batches)
	var window_product: int = 0
	for child: Node in _world.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null and batch.material_override is ShaderMaterial \
				and (batch.material_override as ShaderMaterial).shader in shaders:
			window_product += 1
	_say("...and none of the window's, %d" % window_product, window_product == 0)
	var camera: Camera3D = _render.get("_camera")
	_say("the product look is graded through a film curve",
		camera.environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC)
	var differs: float = _model_difference(window_shot, product_shot)
	_say("it differs from the window's look of the same shot, %.3f" % differs, differs > 0.03)

	# Each backdrop as named.
	var white_corner: float = _corners(product_shot)
	_say("white: white to its corners, %.2f" % white_corner, white_corner > 0.85)
	var gradient: Image = await _render.render(_world, _settings("product", "gradient"))
	if gradient != null:
		gradient.save_png(OUT + "product_gradient.png")
		var middle: float = _floor_under(gradient)
		var corner: float = _corners(gradient)
		_say("gradient: %.2f under the model, %.2f in its corners" % [middle, corner],
			middle > 0.8 and middle - corner > 0.1)
	else:
		_say("gradient: drew a picture", false)
	var dark: Image = await _render.render(_world, _settings("product", "dark"))
	if dark != null:
		dark.save_png(OUT + "product_dark.png")
		var corner: float = _corners(dark)
		var middle: float = _floor_under(dark)
		_say("dark: %.2f in its corners, %.2f under the model" % [corner, middle],
			corner < 0.12 and middle >= corner)
	else:
		_say("dark: drew a picture", false)

	# Depth of field, at Best.
	var sharp_settings: RenderSettings = _settings("product", "white")
	sharp_settings.quality = RenderSettings.Quality.BEST
	sharp_settings.samples = 16
	var sharp: Image = await _render.render(_world, sharp_settings)
	var soft_settings: RenderSettings = sharp_settings.copy()
	soft_settings.f_stop = 2.0
	soft_settings.focus = 0.0
	var soft: Image = await _render.render(_world, soft_settings)
	if sharp != null and soft != null:
		soft.save_png(OUT + "product_depth_of_field.png")
		var crisp: float = _detail(sharp)
		var blurred: float = _detail(soft)
		_say("depth of field softens it: detail %.4f, %.4f with the lens open" % [crisp, blurred],
			blurred < crisp * 0.92)
	else:
		_say("depth of field: drew both pictures", false)

	# The window, after.
	for _n: int in 30:
		await process_frame
	var after: float = await _window_frame_ms()
	print("  the window's frame on the card after: %.3f ms" % after)
	_say("the window's frame costs what it did, %.3f ms then %.3f ms" % [before, after],
		after <= before * 1.1 + 0.3)
	var now: Array = [environment.tonemap_mode, environment.ssil_enabled,
		environment.adjustment_enabled, environment.sky]
	_say("...and its environment is as it was", now == window_look)

	print("")
	print("%d failed" % _failures if _failures
		else "the product look draws every backdrop and leaves the window as it was")
	quit(1 if _failures else 0)


func _build_scene(library: PartLibrary) -> void:
	_world.clear()
	var parts: Array = [
		["3958", 71, Vector3(0, 8, 0)],
		["3001", 4, Vector3(-20, 32, -20)],
		["3001", 4, Vector3(-20, 56, -20)],
		["3001", 4, Vector3(-20, 80, -20)],
		["3039", 14, Vector3(30, 32, 20)],
		["3062b", 383, Vector3(-40, 32, 40)],
		["3001", 47, Vector3(30, 32, -30)],
	]
	for part: Array in parts:
		if library.parts.has(str(part[0])):
			_world.add_brick(str(part[0]), int(part[1]), Transform3D(Basis.IDENTITY, part[2]))
		else:
			_say("the library has %s" % part[0], false)
	for n: int in 7:
		_world.add_brick("3005", 1, Transform3D(Basis.IDENTITY,
			Vector3(110, 24.0 * float(n + 1), 30)))


func _settings(look: String, backdrop: String) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.GOOD
	settings.size = Vector2i(480, 270)
	settings.view = "hero"
	settings.look = look
	settings.use_backdrop(backdrop)
	return settings


## The window's own measured time on the card, ms: the median of 120 frames.
func _window_frame_ms() -> float:
	var window: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(window, true)
	for _n: int in 20:
		await process_frame
	var times := PackedFloat32Array()
	for _n: int in 120:
		await process_frame
		times.append(RenderingServer.viewport_get_measured_render_time_gpu(window))
	RenderingServer.viewport_set_measure_render_time(window, false)
	times.sort()
	return times[times.size() / 2]


## How much the model's pixels differ between two pictures of one shot,
## on average, 0 to 1: the pixels that are not the backdrop's in either.
func _model_difference(a: Image, b: Image) -> float:
	var sum: float = 0.0
	var count: int = 0
	var backdrop: Color = a.get_pixel(4, 4)
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			var one: Color = a.get_pixel(x, y)
			var two: Color = b.get_pixel(x, y)
			if absf(one.get_luminance() - backdrop.get_luminance()) < 0.04:
				continue
			sum += (absf(one.r - two.r) + absf(one.g - two.g) + absf(one.b - two.b)) / 3.0
			count += 1
	return sum / float(count) if count > 0 else 0.0


## The lightness of the picture's four corners, averaged.
func _corners(image: Image) -> float:
	var sum: float = 0.0
	var w: int = image.get_width()
	var h: int = image.get_height()
	for at: Vector2i in [Vector2i(3, 3), Vector2i(w - 4, 3), Vector2i(3, h - 4),
			Vector2i(w - 4, h - 4)]:
		sum += image.get_pixelv(at).get_luminance()
	return sum / 4.0


## The floor's lightness just below the model, in the middle of the picture.
func _floor_under(image: Image) -> float:
	var x: int = image.get_width() / 2
	var best: float = 0.0
	for y: int in range(int(image.get_height() * 0.8), int(image.get_height() * 0.95)):
		best = maxf(best, image.get_pixel(x, y).get_luminance())
	return best


## How much fine detail a picture has: the mean difference between
## neighbouring pixels.
func _detail(image: Image) -> float:
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(1, image.get_height()):
		for x: int in range(1, image.get_width()):
			var here: float = image.get_pixel(x, y).get_luminance()
			sum += absf(here - image.get_pixel(x - 1, y).get_luminance()) \
				+ absf(here - image.get_pixel(x, y - 1).get_luminance())
			count += 1
	return sum / float(count)


func _say(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
