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
##   -- --fit           each set shot's camera fitted to its photograph's outline
##                      (photoreal4): shots/photoreal/masks/<name>.png, from
##                      tools/bench/photoreal.py masks, against the model's own
##                      outline drawn from the camera; yaw, pitch, roll, zoom,
##                      shift and lens moved one at a time while the overlap
##                      (intersection over union) grows. Writes
##                      shots/photoreal/<tag>/<name>_fit.json and _fit.png (the
##                      two outlines over each other); draws nothing else.
##   -- --shots=PATH    the shots from another file than tools/photoreal/shots.json
##   -- --without=a,b   these of the shot's camera and wear (grain, vignette,
##                      aberration, softness, sharpen, jpeg, age, dust, paper, seating, the parts'
##                      batch, handling, studs and play (photoreal8), its edges'
##                      rounding (edge, photoreal13), and the
##                      camera's tone and balance) at 0, and its
##                      surface (photoreal5) paper, to measure what each brings (photoreal4)
##   -- --draw=N        the tracer's seed (default 1): another draw of the same
##                      tree, its noise and lens samples only (photoreal6)
##   -- --cycles        also each shot's scene as drawn, for Cycles through
##                      Blender (tools/photoreal/cycles/, photoreal6):
##                      <name>.cycles.ldr, the parts where they stood, seated,
##                      in LDraw's space, and <name>.cycles.json, the camera,
##                      lens, tent or place, key, sweep, exposure and the
##                      camera's marks, in the app's space (LDU, +y up)
##   -- --stage=K       every shot staged on K (StudioRender.STAGES; "none" for
##                      the seamless) instead of its own (photoreal7)
##   -- --keys=R:F:S,.. each shot with its staged key at each of these: R
##                      degrees up, F model radii away, S as bright, named
##                      <name>[_t<turn>]_k<R>x<F>x<S>, to fit the light to the
##                      photograph (tools/photoreal/fit_light.py, photoreal7)
##   -- --width=N       each picture N pixels wide, its shape kept (a fit's
##                      quick draws)
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


## A stage asked for by name, as render_model and render_queue ask
## (photoreal7, RenderSettings.take and use_stage): its colour on the
## backdrop unless a backdrop is asked too, none for the seamless backdrop,
## and refused, changing nothing, with backdrop none or a name it lacks.
func _stage_asked() -> void:
	var asked := RenderSettings.new()
	var said: String = asked.take({"stage": "wood"})
	_check("stage=wood: the stage, its colour, something under it",
		said.is_empty() and asked.stage == "wood" and not asked.transparent
		and asked.backdrop.is_equal_approx(StudioRender.STAGES["wood"][6]))
	said = asked.take({"stage": "terrazzo", "backdrop": "grey"})
	var grey := RenderSettings.new()
	grey.use_backdrop("grey")
	_check("stage=terrazzo with backdrop=grey keeps the grey",
		said.is_empty() and asked.stage == "terrazzo" and asked.backdrop.is_equal_approx(grey.backdrop))
	said = asked.take({"stage": "none"})
	_check("stage=none: the seamless backdrop", said.is_empty() and asked.stage.is_empty())
	said = asked.take({"stage": "wood", "backdrop": "none"})
	_check("stage=wood with backdrop=none refused, no stage (%s)" % said,
		not said.is_empty() and asked.stage.is_empty())
	said = RenderSettings.new().take({"stage": "marble"})
	_check("stage=marble refused, naming the stages (%s)" % said, said.contains("leather"))


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
	var shots_file: String = _arg("shots", SHOTS)
	var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(shots_file))
	if not said is Dictionary or not (said as Dictionary).get("shots") is Array:
		_check("%s read" % shots_file, false)
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
	if not car_only:
		_stage_asked()
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
		if OS.get_cmdline_user_args().has("--fit"):
			if str(shot.get("kind", "")) == "set":
				await _fit(shot, name, out)
			continue
		var yaws: PackedStringArray = _arg("yaws", "").split(",", false)
		var lit: PackedStringArray = _arg("turns", "").split(",", false)
		var lightings: PackedStringArray = _arg("lighting", "").split(",", false)
		if lightings.is_empty():
			lightings.append("")
		var keys: PackedStringArray = _arg("keys", "").split(",", false)
		if keys.is_empty():
			keys.append("")
		var turns: Array = [null] if yaws.is_empty() else Array(yaws)
		for turn: Variant in turns:
			for light: Variant in ([null] if lit.is_empty() else Array(lit)):
				for lighting: String in lightings:
					for key: String in keys:
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
						if not key.is_empty():
							var parts: PackedStringArray = key.split(":")
							asked["key_rise"] = float(parts[0])
							asked["key_far"] = float(parts[1]) if parts.size() > 1 else -1.0
							asked["key_share"] = float(parts[2]) if parts.size() > 2 else -1.0
							called = "%s_k%s" % [called, key.replace(":", "x")]
						await _draw(asked, called, samples, out)
	if (car_only or only.is_empty()) and not OS.get_cmdline_user_args().has("--fit"):
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
	if OS.get_cmdline_user_args().has("--cycles"):
		_check("%s: its scene written for Cycles" % name, _cycles_scene(settings, name, out))
	var traced: bool = _render.traced_last()
	_check("%s: %d parts, %dx%d, %s in %.1f s" % [name, _world.brick_count(), picture.get_width(),
		picture.get_height(), ("path traced, %d samples" % _render.last_samples) if traced
		else "frames averaged", seconds],
		picture.get_size() == settings.size and (traced or not PathTracer.available()))


## The shot just drawn, for Cycles through Blender (photoreal6), read back
## from the render itself so both renderers are given one scene: the parts
## where they stood, seated as the tracer seated them, as a flat LDraw file
## (LDraw's space: the app's with y and z turned over); and the camera, its
## lens, the tent or the photographed place, the tent's key, the sweep, the
## exposure the white card metered and the camera's marks as JSON, in the
## app's space (LDU, +y up). tools/photoreal/cycles/render.py reads both.
func _cycles_scene(settings: RenderSettings, name: String, out: String) -> bool:
	var shot: StudioRender.Shot = _render.last_shot
	var tracer: Object = _render.get("_tracer")
	var backdrop: MeshInstance3D = _render.get("_backdrop")
	if shot == null or tracer == null or backdrop == null or backdrop.mesh == null:
		return false
	var lines: PackedStringArray = ["0 %s, the parts as photoreal_probe drew them (photoreal6)" % name,
		"0 Name: %s.cycles.ldr" % name]
	var flip := Basis.from_scale(LdrModel.FLIP)
	for found: Variant in _world.bricks():
		var brick: BrickWorld.Brick = found
		if brick.hidden:
			continue
		var place: Transform3D = tracer.call("_seated", brick.transform, PathTracer._part_key(brick.transform))
		var m: Basis = flip * place.basis * flip
		var p: Vector3 = place.origin * LdrModel.FLIP
		var colour: String = ("0x%X" % brick.color_code) if brick.color_code >= 0x2000000 \
			else str(brick.color_code)
		var numbers: PackedStringArray = []
		for value: float in [p.x, p.y, p.z, m.x.x, m.y.x, m.z.x, m.x.y, m.y.y, m.z.y, m.x.z, m.y.z, m.z.z]:
			numbers.append("%.6f" % value)
		var part: String = brick.part_id if brick.part_id.get_extension() in ["dat", "ldr"] \
			else brick.part_id + ".dat"
		lines.append("1 %s %s %s" % [colour, " ".join(numbers), part])
	var file := FileAccess.open(out + name + ".cycles.ldr", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("\n".join(lines) + "\n")
	file.close()
	var tent: bool = _render.call("_tented", settings)
	var lights: Array = _render.get("_lights")
	var key: Variant = null
	if tent and not lights.is_empty() and (lights[0] as DirectionalLight3D).visible:
		key = {"toward": _xyz((lights[0] as Node).get_meta("toward", Vector3.UP)),
			"spread": StudioRender.TENT_KEY_SPREAD, "energy": StudioRender.TENT_KEY}
	var lit_by: StudioPanorama = _render.get("_lit_by")
	var place_said: Variant = null
	if not tent and lit_by != null:
		place_said = {"path": ProjectSettings.globalize_path(lit_by.texture.resource_path),
			"average": lit_by.average, "energy": StudioRender.HDRI_LEVEL / maxf(lit_by.average, 0.0001),
			"turn": float(_render.get("_turn"))}
	var arrays: Array = backdrop.mesh.surface_get_arrays(0)
	var corners: Array = []
	for at: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		corners.append(_xyz(at))
	var order: Variant = arrays[Mesh.ARRAY_INDEX]
	var tint: Color = StudioRender._paper_tint(settings)
	var bounds: AABB = _world.model_bounds()
	var said: Dictionary = {
		"name": name, "size": [settings.size.x, settings.size.y], "draw": settings.seed,
		"samples": settings.samples,
		"camera": {"origin": _xyz(shot.origin), "x": _xyz(shot.basis.x), "y": _xyz(shot.basis.y),
			"z": _xyz(shot.basis.z), "fov": shot.fov, "focus_distance": shot.focus_distance,
			"aperture": shot.aperture, "near": shot.near, "far": shot.far},
		"bounds": [_xyz(bounds.position), _xyz(bounds.end)],
		"tent": tent, "tint": [tint.r, tint.g, tint.b], "tent_top": StudioRender.TENT_TOP,
		"tent_box": StudioRender.TENT_BOX, "key": key, "place": place_said,
		"backdrop": "#" + settings.backdrop.to_html(false), "exposure": _render.last_drawn_at,
		"linear_saturation": StudioRender.PHOTO_LINEAR_SATURATION,
		"sweep": {"visible": backdrop.visible, "origin": _xyz(backdrop.global_transform.origin),
			"x": _xyz(backdrop.global_transform.basis.x), "y": _xyz(backdrop.global_transform.basis.y),
			"z": _xyz(backdrop.global_transform.basis.z), "vertices": corners,
			"indices": Array(order) if order != null else []},
		"grain": settings.grain, "vignette": settings.vignette, "aberration": settings.aberration,
		"softness": settings.softness, "paper": settings.paper, "surface": settings.surface,
		"seating": settings.seating, "age": settings.age, "dust": settings.dust,
		"sharpen": settings.sharpen, "jpeg": settings.jpeg,
	}
	file = FileAccess.open(out + name + ".cycles.json", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(said, " "))
	file.close()
	return true


static func _xyz(at: Vector3) -> Array:
	return [at.x, at.y, at.z]


## The camera a set's photograph was taken from, found by its outline (photoreal4):
## the model's outline drawn quickly (the window's own look, nothing behind
## it, no shadow) at the mask's size from each camera tried, and its overlap
## with the photograph's outline. One setting moved at a time by its step,
## either way, kept while the overlap grows; every step halved when none does.
func _fit(shot: Dictionary, name: String, out: String) -> void:
	var path: String = ProjectSettings.globalize_path("res://shots/photoreal/masks/%s.png"
		% str(shot.get("mask_of", name)))
	var target: Image = Image.load_from_file(path)
	if target == null:
		_check("%s: a mask at %s (tools/bench/photoreal.py masks)" % [name, path], false)
		return
	target.convert(Image.FORMAT_L8)
	var want: PackedByteArray = target.get_data()
	var size := Vector2i(target.get_width(), target.get_height())
	var at: Dictionary = {"yaw": float(shot.get("yaw", -35.0)), "pitch": float(shot.get("pitch", 30.0)),
		"roll": float(shot.get("roll", 0.0)), "zoom": float(shot.get("zoom", 1.0)),
		"shift_x": float((shot.get("shift", [0.0, 0.0]) as Array)[0]),
		"shift_y": float((shot.get("shift", [0.0, 0.0]) as Array)[1]),
		"focal_mm": float(shot.get("focal_mm", 50.0))}
	var step: Dictionary = {"yaw": 8.0, "pitch": 5.0, "roll": 2.0, "zoom": 0.1, "shift_x": 0.06,
		"shift_y": 0.06, "focal_mm": 0.3}
	var started: Dictionary = at.duplicate()
	var best: float = await _overlap(shot, at, size, want, null)
	var first: float = best
	var tries: int = 0
	while tries < 260:
		var moved: bool = false
		for key: String in step:
			for sign: float in [1.0, -1.0]:
				var trial: Dictionary = at.duplicate()
				# The lens by a factor, the others by a step.
				trial[key] = float(at[key]) * exp(sign * float(step[key])) if key == "focal_mm" \
					else float(at[key]) + sign * float(step[key])
				trial["pitch"] = clampf(float(trial["pitch"]), -5.0, 85.0)
				trial["focal_mm"] = clampf(float(trial["focal_mm"]), 18.0, 400.0)
				var score: float = await _overlap(shot, trial, size, want, null)
				tries += 1
				if score > best + 0.0005:
					best = score
					at = trial
					moved = true
					break
		if not moved:
			var small: bool = true
			for key: String in step:
				step[key] = float(step[key]) * 0.5
				small = small and float(step[key]) < (0.25 if key in ["yaw", "pitch", "roll"] else 0.005)
			if small:
				break
	var drawn := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	await _overlap(shot, at, size, want, drawn)
	drawn.save_png(out + name + "_fit.png")
	var said := FileAccess.open(out + name + "_fit.json", FileAccess.WRITE)
	said.store_string(JSON.stringify({"name": name, "from": started, "to": at, "overlap_from": first,
		"overlap_to": best, "tries": tries}, " "))
	said.close()
	_check("%s: camera fitted to the photograph's outline, overlap %.3f to %.3f in %d tries: yaw %.1f, pitch %.1f, roll %.1f, zoom %.3f, shift %.3f, %.3f, %.0f mm"
		% [name, first, best, tries, at["yaw"], at["pitch"], at["roll"], at["zoom"], at["shift_x"],
		at["shift_y"], at["focal_mm"]], best > first or best > 0.9)


## How much of the model's outline from the camera [param at] and the
## photograph's [param want] (one byte a pixel, the model non-zero) overlap:
## their intersection over their union. With [param drawn], both are drawn
## into it: the photograph's alone red, the render's alone blue, both white.
func _overlap(shot: Dictionary, at: Dictionary, size: Vector2i, want: PackedByteArray,
		drawn: Variant) -> float:
	var asked: Dictionary = shot.duplicate()
	for key: String in ["yaw", "pitch", "roll", "zoom", "focal_mm"]:
		asked[key] = at[key]
	asked["shift"] = [at["shift_x"], at["shift_y"]]
	asked["size"] = [size.x, size.y]
	var settings: RenderSettings = _settings(asked, 1)
	settings.quality = RenderSettings.Quality.QUICK
	settings.transparent = true
	settings.contact_shadow = false
	settings.no_shadows = true
	settings.f_stop = 0.0
	var picture: Image = await _render.render(_world, settings)
	if picture == null:
		return 0.0
	if picture.get_size() != size:
		picture.resize(size.x, size.y)
	picture.convert(Image.FORMAT_RGBA8)
	var got: PackedByteArray = picture.get_data()
	var both: int = 0
	var either: int = 0
	for i: int in size.x * size.y:
		var mine: bool = got[i * 4 + 3] > 25
		var theirs: bool = want[i] > 127
		if mine and theirs:
			both += 1
		if mine or theirs:
			either += 1
		if drawn != null:
			(drawn as Image).set_pixel(i % size.x, i / size.x, Color.WHITE if mine and theirs
				else Color(0.85, 0.1, 0.1) if theirs else Color(0.1, 0.3, 0.9) if mine else Color.BLACK)
	return float(both) / float(maxi(either, 1))
func _settings(shot: Dictionary, samples: int) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.BEST
	settings.look = "product"
	var size: Array = shot["size"]
	settings.size = Vector2i(int(size[0]), int(size[1]))
	var width: int = int(_arg("width", "0"))
	if width > 0 and samples > 1:
		settings.size = Vector2i(width, maxi(roundi(float(width) * float(size[1]) / float(size[0])), 8))
	settings.samples = samples
	settings.seed = maxi(int(_arg("draw", "1")), 1)
	settings.backdrop = Color.html(str(shot.get("backdrop", "#ffffff")))
	settings.backdrop_gradient = bool(shot.get("gradient", false))
	settings.lighting = str(shot.get("lighting", "studio"))
	settings.light_turn = float(shot.get("light_turn", 0.0))
	settings.focal_mm = float(shot.get("focal_mm", 50.0))
	settings.f_stop = float(shot.get("f_stop", 0.0))
	settings.focus = float(shot.get("focus", 0.5))
	# The photograph's camera and the photographed parts' wear (photoreal4),
	# where the shot says; otherwise the product look's own.
	var without: PackedStringArray = _arg("without", "").split(",", false)
	for key: String in ["grain", "vignette", "aberration", "softness", "sharpen", "jpeg", "age",
			"dust", "paper", "seating", "tone", "balance", "batch", "handling", "studs", "play",
			"rubbed", "table", "table_light", "fill", "edge", "source", "source_rise", "source_turn",
			"source_wide", "source_tall", "source_fall", "source_key", "source_spill"]:
		if key in without:
			settings.set(key, 0.0)
		elif shot.has(key):
			settings.set(key, float(shot[key]))
	# What the photograph's parts stand on (photoreal5): 0 paper, 1 a desk.
	settings.surface = 0 if "surface" in without else int(shot.get("surface", 0))
	# Its staging (photoreal7): what it stands on and the key near it.
	var stage: String = _arg("stage", str(shot.get("stage", "")))
	settings.stage = "" if stage == "none" else stage
	for key: String in ["key_rise", "key_far", "key_size", "key_share"]:
		if shot.has(key):
			settings.set(key, float(shot[key]))
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
