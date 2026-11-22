## Does Best, Product look, draw LEGO® bricks as a photograph shows them?
## The render half of the side-by-side harness (photoreal1).
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x800 \
##       --script src/dev/photoreal_probe.gd -- --tag=after
##
## Each shot in tools/photoreal/shots.json is a real photograph (a free macro
## photograph of a part, or a set's own picture) and how to stand where its
## camera stood: the model, the direction looked from (yaw round from the
## front, pitch up), the lens, how much of the frame the model fills and where,
## the sweep's colour and the light. Each is drawn at Best (path traced where the
## card traces rays), Product look, at the photograph's own shape, into
## shots/photoreal/<tag>/<name>.png. tools/bench/photoreal.py then puts each
## beside its photograph and asks a blind judge which is the photograph.
##
##   -- --tag=NAME      the folder the pictures go in (default "now")
##   -- --only=a,b      only these shots
##   -- --samples=N     samples a pixel (default 256, Best's own)
##   -- --yaws=0,90     each shot from these yaws instead of its own, named
##                      <name>_y<yaw>, to find which way a model faces
##   -- --turns=0,90    each shot with its light turned by these degrees instead
##                      of its own, named <name>_t<turn>, to find where the
##                      photograph's light stood (photoreal2)
##   -- --lighting=K,L  each shot lit by each of these instead of its own,
##                      named <name>[_t<turn>]_<K>
##   -- --raw           also each picture's light before its exposure and tone
##                      curve, <name>.exr, and what it was drawn at, <name>.json,
##                      for tools/bench/photoreal.py colour's fit (photoreal2)
##   -- --car           only the car (the render probe's model) at Best, Product
##                      look, 1280x720, 256 samples, three times: the median at
##                      most CAR_MOST s (twice the 3.3-4.2 s the window look
##                      took). Run bare, the probe draws every shot and then
##                      times the car.
##
## Checks: every shot is drawn, path traced where the card can, at its size;
## and prints each one's time, for the bar on Best's speed.
extends SceneTree

const SHOTS := "res://tools/photoreal/shots.json"
const CAR_MOST := 8.4

var _failures: int = 0
var _main: Node
var _render: StudioRender
var _world: BrickWorld


func _initialize() -> void:
	_run()


func _check(words: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", words])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _arg(name: String, fallback: String) -> String:
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--%s=" % name):
			return given.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	await process_frame
	var tag: String = _arg("tag", "now")
	var only: PackedStringArray = _arg("only", "").split(",", false)
	var samples: int = int(_arg("samples", "256"))
	var out: String = "res://shots/photoreal/%s/" % tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS))
	if not said is Dictionary or not (said as Dictionary).get("shots") is Array:
		_check("%s read" % SHOTS, false)
		quit(1)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	_world = _main.get("_world")
	var library: PartLibrary = _main.get("_library")
	if _world == null or library == null or library.parts.is_empty():
		_check("a world and a catalogue", false)
		quit(1)
		return
	(_main.get("_builder") as Builder).hide_preview()
	print("  renderer: %s on %s; path traced: %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), PathTracer.available()])
	_render = StudioRender.new()
	_render.library = library
	_render.scenery = (_main.get("_store") as ModelStore).scenery
	_render.eye = _main.get("_camera")
	_render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)
	_render.keep_mean = OS.get_cmdline_user_args().has("--raw")
	var bar: ModelBar = _main.get("_bar")
	var car_only: bool = OS.get_cmdline_user_args().has("--car")
	for shot: Dictionary in ([] if car_only else said["shots"]):
		var name: String = str(shot["name"])
		if not only.is_empty() and not name in only:
			continue
		_world.clear()
		await _frames(2)
		var placed: int = await bar.open_with_progress(str(shot["model"]))
		await _frames(10)
		if placed <= 0 or _world.brick_count() == 0:
			_check("%s: %s opened" % [name, shot["model"]], false)
			continue
		var yaws: PackedStringArray = _arg("yaws", "").split(",", false)
		var lit: PackedStringArray = _arg("turns", "").split(",", false)
		var lightings: PackedStringArray = _arg("lighting", "").split(",", false)
		if lightings.is_empty():
			lightings.append("")
		var turns: Array = [null] if yaws.is_empty() else Array(yaws)
		for turn: Variant in turns:
			for light: Variant in ([null] if lit.is_empty() else Array(lit)):
				for lighting: String in lightings:
					var asked: Dictionary = shot.duplicate()
					var called: String = name
					if turn != null:
						asked["yaw"] = float(turn)
						called = "%s_y%s" % [name, turn]
					if light != null:
						asked["light_turn"] = float(light)
						called = "%s_t%s" % [called, light]
					if not lighting.is_empty():
						asked["lighting"] = lighting
						called = "%s_%s" % [called, lighting]
					await _draw(asked, called, samples, out)
	if car_only or only.is_empty():
		await _car(bar, out)
	print("")
	print("%d failed" % _failures if _failures else "every shot drawn, in %s" % out)
	quit(1 if _failures else 0)


## Best on the car, Product look, three times: its own time (less the main
## thread's waits for a CPU, ProbeTime), the median against CAR_MOST.
func _car(bar: ModelBar, out: String) -> void:
	_world.clear()
	await _frames(2)
	await bar.open_with_progress("res://models/car.ldr")
	await _frames(10)
	var times: Array[float] = []
	for n: int in 3:
		var settings := RenderSettings.new()
		settings.quality = RenderSettings.Quality.BEST
		settings.look = "product"
		settings.size = Vector2i(1280, 720)
		settings.samples = 256
		settings.seed = 1 + n
		settings.backdrop_gradient = true
		var span := ProbeTime.Span.new()
		var picture: Image = await _render.render(_world, settings)
		times.append(span.end().own / 1000.0)
		if picture != null and n == 0:
			picture.save_png(out + "car_product_best.png")
	times.sort()
	_check("the car, Best, Product, 1280x720, 256 samples: %.2f, %.2f and %.2f s, the median at most %.1f (%s)"
		% [times[0], times[1], times[2], CAR_MOST, "path traced" if _render.traced_last()
		else "frames averaged"], times[1] <= CAR_MOST)


func _draw(shot: Dictionary, name: String, samples: int, out: String) -> void:
	var settings: RenderSettings = _settings(shot, samples)
	var started: int = Time.get_ticks_msec()
	var picture: Image = await _render.render(_world, settings)
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	if picture == null:
		_check("%s drawn" % name, false)
		return
	picture.save_png(out + name + ".png")
	if _render.last_mean != null:
		_render.last_mean.save_exr(out + name + ".exr")
		var said := FileAccess.open(out + name + ".json", FileAccess.WRITE)
		said.store_string(JSON.stringify({"drawn_at": _render.last_drawn_at}))
		said.close()
	var traced: bool = _render.traced_last()
	_check("%s: %d parts, %dx%d, %s in %.1f s" % [name, _world.brick_count(), picture.get_width(),
		picture.get_height(), ("path traced, %d samples" % _render.last_samples) if traced
		else "frames averaged", seconds],
		picture.get_size() == settings.size and (traced or not PathTracer.available()))


## A shot's settings: Best, Product, the photograph's shape, and the eye
## standing where its camera stood.
func _settings(shot: Dictionary, samples: int) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.BEST
	settings.look = "product"
	var size: Array = shot["size"]
	settings.size = Vector2i(int(size[0]), int(size[1]))
	settings.samples = samples
	settings.seed = 1
	settings.backdrop = Color.html(str(shot.get("backdrop", "#ffffff")))
	settings.backdrop_gradient = bool(shot.get("gradient", false))
	settings.lighting = str(shot.get("lighting", "studio"))
	settings.light_turn = float(shot.get("light_turn", 0.0))
	settings.focal_mm = float(shot.get("focal_mm", 50.0))
	settings.f_stop = float(shot.get("f_stop", 0.0))
	settings.focus = float(shot.get("focus", 0.5))
	var bounds: AABB = _world.model_bounds()
	var yaw: float = deg_to_rad(float(shot.get("yaw", -35.0)))
	var pitch: float = deg_to_rad(float(shot.get("pitch", 30.0)))
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var basis: Basis = StudioRender._looking_from(direction.normalized())
	var roll: float = deg_to_rad(float(shot.get("roll", 0.0)))
	if roll != 0.0:
		basis = Basis(basis.z, roll) * basis
	var fov: float = settings.fov_degrees()
	var aspect: float = float(settings.size.x) / float(settings.size.y)
	var origin: Vector3 = StudioRender._fit(basis, bounds, fov, aspect)
	# Nearer or further than the fit, and the model off the picture's middle
	# as the photograph has it (a fraction of the half frame, right and up).
	var forward: Vector3 = -basis.z
	var centre: Vector3 = bounds.get_center()
	var depth: float = (centre - origin).dot(forward)
	var zoom: float = float(shot.get("zoom", 1.0))
	origin += forward * depth * (1.0 - 1.0 / maxf(zoom, 0.05))
	depth /= maxf(zoom, 0.05)
	var shift: Array = shot.get("shift", [0.0, 0.0])
	var half_up: float = tan(deg_to_rad(fov) * 0.5) * depth
	origin -= basis.x * float(shift[0]) * half_up * aspect + basis.y * float(shift[1]) * half_up
	settings.view = "current"
	settings.eye_transform = Transform3D(basis, origin)
	settings.eye_fov = fov
	settings.eye_orthogonal = false
	settings.eye_focus = centre
	return settings
