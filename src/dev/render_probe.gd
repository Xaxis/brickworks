## Does File, Render… draw a picture worth keeping, at every grade?
##
##   godot --path . --resolution 1280x800 --script src/dev/render_probe.gd
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x800 \
##       --script src/dev/render_probe.gd
##
## The first is the Compatibility renderer every browser gets (the plain
## godot here draws in software, with that renderer), the second Forward+
## on the graphics card: the two do not have the same effects, and Good is
## made differently on each. Run both.
##
## A small scene — a plate, a red tower, a slope, a chrome round, a clear
## brick and a thin column whose shadow falls on the floor — drawn at each
## grade, and asked what a person would ask of the picture:
##
##   the size asked for;
##   not empty: the model is in it, and it is not one flat colour;
##   the backdrop is the colour asked for, away from the model;
##   a soft shadow: the same picture drawn with the key's shadow taken away
##     differs by a shadow, and a good share of that shadow is penumbra —
##     partly lit — rather than a hard edge;
##   a contact shadow under the model, on transparent too;
##   a turntable's frames all different and written as an animated WebP
##     that has one frame chunk for each;
##   Cancel stops a Best render within a few frames, and the next render
##     after it still works;
##   no frame of a render holds the app up for long.
##
## Leaves shots/render/<renderer>_<grade>.png and the rest to look at.
##
## With -- --model=FILE it draws that model instead and asks nothing:
##   -- --model=models/castle.ldr --quality=best --size=1920x1080
##      --lighting=softbox --view=hero --picture=shots/render/castle_best.png
## (--picture, not --out: the app itself reads --out as "write the model
## there and quit")
extends SceneTree

const OUT := "res://shots/render/"

var _failures: int = 0
var _main: Node
var _render: StudioRender
var _world: BrickWorld
var _longest_frame_ms: float = 0.0
var _timing: bool = false
var _last_tick: int = 0
## Where the model is in the probe's pictures, and how it looked at Quick.
var _model_pixels := PackedVector2Array()
var _quick_look: Vector2 = Vector2.ZERO


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	if _timing:
		var now: int = Time.get_ticks_usec()
		if _last_tick > 0:
			_longest_frame_ms = maxf(_longest_frame_ms, float(now - _last_tick) / 1000.0)
		_last_tick = now
	return false


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
	(_main.get("_builder") as Builder).hide_preview()

	_render = StudioRender.new()
	_render.library = library
	_render.scenery = (_main.get("_store") as ModelStore).scenery
	_render.eye = _main.get("_camera")
	_render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)

	var wanted: String = _argument("--model")
	if _argument("--scene") == "minifigs":
		_minifig_scene(library)
		for _n: int in 4:
			await process_frame
		await _showcase()
		quit(0)
		return
	if not wanted.is_empty():
		await _showcase()
		quit(0)
		return

	_build_scene(library)
	await process_frame
	await process_frame

	var only: String = OS.get_environment("BW_ONLY")
	if not only.is_empty():
		var settings: RenderSettings = _settings({"quick": 0, "good": 1, "best": 2}[only])
		settings.size = Vector2i(960, 540)
		var picture: Image = await _render.render(_world, settings)
		picture.save_png(OUT + "%s_%s_big.png" % [method, only])
		quit(0)
		return
	# Which pixels are the model: the same shot on nothing, without its
	# contact shadow.
	var bare: RenderSettings = _settings(RenderSettings.Quality.QUICK)
	bare.transparent = true
	bare.contact_shadow = false
	var mask: Image = await _render.render(_world, bare)
	_model_pixels = PackedVector2Array()
	if mask != null:
		for y: int in range(0, mask.get_height(), 2):
			for x: int in range(0, mask.get_width(), 2):
				if mask.get_pixel(x, y).a > 0.95:
					_model_pixels.append(Vector2(x, y))
	for quality: int in [RenderSettings.Quality.QUICK, RenderSettings.Quality.GOOD,
			RenderSettings.Quality.BEST]:
		await _grade(quality, method)
	await _lighting(method)
	if OS.get_environment("BW_GRADES_ONLY") == "1":
		quit(1 if _failures else 0)
		return
	await _transparent(method)
	await _turntable(method)
	await _cancel()
	await _dialog(method)

	print("")
	print("%d failed" % _failures if _failures
		else "every grade draws a picture with a soft shadow, on %s" % method)
	quit(1 if _failures else 0)


func _build_scene(library: PartLibrary) -> void:
	_world.clear()
	var parts: Array = [
		# part, colour, where (LDU; y is the top of the part)
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
	# A thin column off to the side, whose shadow falls clear on the floor.
	for n: int in 7:
		_world.add_brick("3005", 1, Transform3D(Basis.IDENTITY,
			Vector3(110, 24.0 * float(n + 1), 30)))


func _settings(quality: int) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = quality
	settings.size = Vector2i(480, 270)
	settings.view = "hero"
	settings.samples = 24 if quality == RenderSettings.Quality.BEST else 0
	return settings


func _grade(quality: int, method: String) -> void:
	var name: String = ["quick", "good", "best"][quality]
	var settings: RenderSettings = _settings(quality)
	_timing = true
	_last_tick = 0
	_longest_frame_ms = 0.0
	var started: int = Time.get_ticks_msec()
	var image: Image = await _render.render(_world, settings)
	var took: int = Time.get_ticks_msec() - started
	_timing = false
	if image == null:
		_say("%s: drew a picture" % name, false)
		return
	image.save_png(OUT + "%s_%s.png" % [method, name])
	print("  %s: %d samples, %d ms, longest frame %.0f ms" % [name, _render.last_samples, took,
		_longest_frame_ms])
	_say("%s: %dx%d as asked" % [name, image.get_width(), image.get_height()],
		Vector2i(image.get_width(), image.get_height()) == settings.size)
	var backdrop: Color = settings.backdrop
	var differs: float = _share(image, func(c: Color) -> bool:
		return absf(c.get_luminance() - backdrop.get_luminance()) > 0.12)
	_say("%s: the model is in it (%.0f%% of it is not the backdrop)" % [name, differs * 100.0],
		differs > 0.03 and differs < 0.8)
	# The plastic keeps its colours: the model as light and as coloured as
	# the window draws it. Global illumination off a white sweep once
	# washed every colour towards pastel.
	var looked: Vector2 = _look_of(image)
	if quality == RenderSettings.Quality.QUICK:
		_quick_look = looked
	else:
		var lighter: float = looked.x / maxf(_quick_look.x, 0.001)
		var richer: float = looked.y / maxf(_quick_look.y, 0.001)
		_say("%s: the model is as light as at Quick (x%.2f) and as coloured (x%.2f)"
			% [name, lighter, richer],
			lighter > 0.85 and lighter < 1.18 and richer > 0.85 and richer < 1.25)
	print("    %s: the model's lightness %.3f, colour %.3f; exposure x%.2f, sweep x%.2f"
		% [name, looked.x, looked.y, _render.last_exposure, _render.last_level])
	var corner: Color = image.get_pixel(image.get_width() / 2, 4)
	_say("%s: the sweep behind reads as white (%s)" % [name, corner.to_html(false)],
		corner.get_luminance() > 0.72)

	# The key's shadow, by what taking it away changes.
	var unshadowed: RenderSettings = settings.copy()
	unshadowed.no_shadows = true
	unshadowed.contact_shadow = settings.contact_shadow
	var without: Image = await _render.render(_world, unshadowed)
	if without == null:
		_say("%s: drew it again without the shadow" % name, false)
		return
	without.save_png(OUT + "%s_%s_unshadowed.png" % [method, name])
	var soft: Array = _penumbra(image, without)
	var shadowed: int = soft[0]
	var partly: int = soft[1]
	var ratio: float = float(partly) / float(maxi(shadowed, 1))
	print("    %s shadow: %d pixels shadowed, %d of them partly (%.0f%%), at most %.2f darker"
		% [name, shadowed, partly, ratio * 100.0, float(soft[2]) if soft.size() > 2 else 0.0])
	_say("%s: the key casts a shadow" % name, shadowed > 300)
	var wants: float = 0.12 if quality == RenderSettings.Quality.QUICK else 0.25
	_say("%s: it is soft (%.0f%% penumbra, wants %.0f%%)" % [name, ratio * 100.0, wants * 100.0],
		ratio >= wants)


## The model's mean lightness, and its mean colourfulness (the spread
## between its strongest and weakest channel).
func _look_of(image: Image) -> Vector2:
	var light: float = 0.0
	var colour: float = 0.0
	for at: Vector2 in _model_pixels:
		var c: Color = image.get_pixelv(Vector2i(at))
		light += c.get_luminance()
		colour += maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	var count: float = float(maxi(_model_pixels.size(), 1))
	return Vector2(light / count, colour / count)


## What share of the picture's pixels pass.
static func _share(image: Image, passes: Callable) -> float:
	var hits: int = 0
	var seen: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			seen += 1
			if passes.call(image.get_pixel(x, y)):
				hits += 1
	return float(hits) / float(maxi(seen, 1))


## Pixels the shadow darkens, and of those how many it only partly darkens.
static func _penumbra(lit: Image, unlit: Image) -> Array:
	var drops: PackedFloat32Array = PackedFloat32Array()
	for y: int in lit.get_height():
		for x: int in lit.get_width():
			var drop: float = unlit.get_pixel(x, y).get_luminance() \
				- lit.get_pixel(x, y).get_luminance()
			if drop > 0.015:
				drops.append(drop)
	if drops.is_empty():
		return [0, 0]
	var sorted: PackedFloat32Array = drops.duplicate()
	sorted.sort()
	var full: float = sorted[int(float(sorted.size() - 1) * 0.9)]
	var partly: int = 0
	for drop: float in drops:
		if drop > full * 0.12 and drop < full * 0.8:
			partly += 1
	return [drops.size(), partly, full]


## Each photographed place lights the model about as brightly as the
## window's three lights, in about its colours, and casts a shadow.
func _lighting(method: String) -> void:
	for key: String in StudioRender.HDRIS:
		for quality: int in [RenderSettings.Quality.QUICK, RenderSettings.Quality.BEST]:
			var settings: RenderSettings = _settings(quality)
			settings.lighting = key
			var image: Image = await _render.render(_world, settings)
			if image == null:
				_say("%s: drew a picture" % key, false)
				continue
			var name: String = "%s_%s" % [key, ["quick", "good", "best"][quality]]
			image.save_png(OUT + "%s_%s.png" % [method, name])
			var looked: Vector2 = _look_of(image)
			var lighter: float = looked.x / maxf(_quick_look.x, 0.001)
			var richer: float = looked.y / maxf(_quick_look.y, 0.001)
			print("    %s: the model's lightness %.3f, colour %.3f; exposure x%.2f, sweep x%.2f"
				% [name, looked.x, looked.y, _render.last_exposure, _render.last_level])
			_say("%s: about as light as the three lights (x%.2f), as coloured (x%.2f)"
				% [name, lighter, richer],
				lighter > 0.75 and lighter < 1.3 and richer > 0.75 and richer < 1.35)


func _transparent(method: String) -> void:
	var settings: RenderSettings = _settings(RenderSettings.Quality.QUICK)
	settings.transparent = true
	var image: Image = await _render.render(_world, settings)
	if image == null:
		_say("transparent: drew a picture", false)
		return
	image.save_png(OUT + "%s_transparent.png" % method)
	var clear: float = _share(image, func(c: Color) -> bool: return c.a < 0.02)
	var partly: float = _share(image, func(c: Color) -> bool: return c.a > 0.04 and c.a < 0.9)
	_say("transparent: the background is clear (%.0f%%)" % (clear * 100.0), clear > 0.5)
	_say("transparent: the contact shadow is there, as a shadow on nothing (%.1f%%)"
		% (partly * 100.0), partly > 0.01)
	settings.contact_shadow = false
	var bare: Image = await _render.render(_world, settings)
	var bare_partly: float = _share(bare, func(c: Color) -> bool: return c.a > 0.04 and c.a < 0.9) \
		if bare != null else 1.0
	_say("transparent: and is not without it (%.1f%%)" % (bare_partly * 100.0),
		bare_partly < partly * 0.5)


func _turntable(method: String) -> void:
	var settings: RenderSettings = _settings(RenderSettings.Quality.QUICK)
	settings.size = Vector2i(240, 240)
	settings.frames = 6
	var webp := AnimatedWebP.new(settings.fps)
	var firsts: Array[Color] = []
	var done: int = await _render.turntable(_world, settings,
		func(n: int, image: Image) -> void:
			webp.add(image)
			firsts.append(image.get_pixel(120, 150))
			if n == 0:
				image.save_png(OUT + "%s_turntable_0.png" % method))
	_say("turntable: %d of 6 frames" % done, done == 6)
	var bytes: PackedByteArray = webp.bytes()
	var file: FileAccess = FileAccess.open(OUT + "%s_turntable.webp" % method, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var tags: PackedStringArray = AnimatedWebP.chunk_tags(bytes)
	# Godot reads stills only; every browser plays the whole (render_flow).
	var check := Image.new()
	var last: PackedByteArray = AnimatedWebP.still(bytes, 5)
	_say("turntable: its last frame is a picture of the model",
		check.load_webp_from_buffer(last) == OK and check.get_width() == 240)
	_say("turntable: an animated WebP with a frame for each (%s)" % ",".join(tags),
		tags.count("ANMF") == 6 and tags.has("ANIM") and tags[0] == "VP8X")
	var different: int = 0
	for n: int in range(1, firsts.size()):
		if not firsts[n].is_equal_approx(firsts[0]):
			different += 1
	_say("turntable: the model turns (%d of 5 frames differ from the first)" % different,
		different >= 3)


func _cancel() -> void:
	var settings: RenderSettings = _settings(RenderSettings.Quality.BEST)
	settings.samples = 400
	var started: int = Time.get_ticks_msec()
	var result: Array = [null, false]
	var waiting := func() -> void:
		result[0] = await _render.render(_world, settings)
		result[1] = true
	waiting.call()
	for _n: int in 20:
		await process_frame
	_render.cancel()
	var cancelled_at: int = Time.get_ticks_msec()
	for _n: int in 30:
		if result[1]:
			break
		await process_frame
	_say("cancel: the render stops (%d ms after)" % (Time.get_ticks_msec() - cancelled_at),
		result[1] and result[0] == null)
	print("    (it ran %d ms before the cancel)" % (cancelled_at - started))
	var again: Image = await _render.render(_world, _settings(RenderSettings.Quality.QUICK))
	_say("cancel: and the next render still draws", again != null)


## File, Render… as a person uses it: the menu opens the dialog, it draws
## a draft, Render picture writes a PNG of the size chosen, and Render
## turntable writes its frames, an animated WebP and, with ffmpeg here,
## an MP4.
func _dialog(method: String) -> void:
	var shell: Shell = _main.get("_shell")
	var dialog: RenderDialog = _main.get("_render")
	var files: String = ProjectSettings.globalize_path(OUT + "files_%s" % method)
	DirAccess.make_dir_recursive_absolute(files)
	# A run before this one, and Godot's importer (the folder is inside the
	# project, so an --import writes a .import beside each frame), leave
	# files in the turntable's folder as well as beside it.
	for folder: String in DirAccess.get_directories_at(files):
		for name: String in DirAccess.get_files_at(files.path_join(folder)):
			DirAccess.remove_absolute(files.path_join(folder).path_join(name))
	for name: String in DirAccess.get_files_at(files):
		DirAccess.remove_absolute(files.path_join(name))
	dialog.folder = files
	_say("dialog: File has Render…", shell.menu_id("render") >= 0 and shell.can("render"))
	shell.run("render")
	_say("dialog: it opens", dialog.visible)
	var drafted: bool = false
	for _n: int in 600:
		await process_frame
		if (dialog.get("_preview") as TextureRect).texture != null and dialog.get("_working") == "":
			drafted = true
			break
	_say("dialog: a draft is drawn without asking", drafted)
	var controls: Dictionary = dialog.controls_by_name()
	(controls["render_quick"] as Button).pressed.emit()
	(controls["render_size_custom"] as Button).pressed.emit()
	(dialog.get("_width") as SpinBox).value = 400
	(dialog.get("_height") as SpinBox).value = 300
	(controls["render_picture"] as Button).pressed.emit()
	await _until_done(dialog)
	var picture: String = files.path_join(RenderOutput.file_name(str(dialog.named.call()), "_render", "png"))
	var kept := Image.load_from_file(picture) if FileAccess.file_exists(picture) else null
	_say("dialog: Render picture wrote %s at 400x300" % picture.get_file(),
		kept != null and kept.get_width() == 400 and kept.get_height() == 300)
	print("    status: %s" % (dialog.get("_status") as Label).text)

	(controls["render_frames_24"] as Button).pressed.emit()
	(controls["render_turntable"] as Button).pressed.emit()
	await _until_done(dialog)
	var base: String = RenderOutput.file_name(str(dialog.named.call()), "_turntable", "x").get_basename()
	var frames: Array = Array(DirAccess.get_files_at(files.path_join(base)) \
		if DirAccess.dir_exists_absolute(files.path_join(base)) else PackedStringArray()) \
		.filter(func(name: String) -> bool: return name.begins_with("frame_") and name.ends_with(".png"))
	_say("dialog: the turntable's 24 frames are in a folder (%d)" % frames.size(),
		frames.size() == 24)
	var webp: PackedByteArray = FileAccess.get_file_as_bytes(files.path_join(base + ".webp"))
	_say("dialog: and an animated WebP of 24 frames (%d bytes)" % webp.size(),
		AnimatedWebP.chunk_tags(webp).count("ANMF") == 24)
	if RenderOutput.ffmpeg().is_empty():
		print("    (no ffmpeg here, so no MP4 to look for)")
	else:
		var mp4: String = files.path_join(base + ".mp4")
		var length: int = 0
		var opened: FileAccess = FileAccess.open(mp4, FileAccess.READ)
		if opened != null:
			length = opened.get_length()
			opened.close()
		_say("dialog: and an MP4 made by ffmpeg (%d bytes)" % length, length > 1000)
	print("    status: %s" % (dialog.get("_status") as Label).text)
	_say("dialog: the window's own model is not drawn behind it", dialog.get_viewport().disable_3d)
	dialog.close()
	_say("dialog: Close closes it, and the window draws its model again",
		not dialog.visible and not dialog.get_viewport().disable_3d)


func _until_done(dialog: RenderDialog) -> void:
	for _n: int in 3:
		await process_frame
	var until: int = Time.get_ticks_msec() + 300000
	while dialog.is_rendering() and Time.get_ticks_msec() < until:
		await process_frame
	for _n: int in 3:
		await process_frame


## A few minifigures on a plate before a wall: real figures from real parts
## (Minifig.surprise), the same ones every time.
func _minifig_scene(library: PartLibrary) -> void:
	_world.clear()
	var plate: String = "91405" if library.parts.has("91405") else "3958"
	_world.add_brick(plate, 19, Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	# A running bond the width of the plate in two greys, three courses
	# high: 1 x 8s, then a 1 x 8 between two 1 x 4s.
	for course: int in 3:
		var bricks: Array = [["3008", -80.0], ["3008", 80.0]] if course % 2 == 0 \
			else [["3010", -120.0], ["3008", 0.0], ["3010", 120.0]]
		for n: int in bricks.size():
			_world.add_brick(str(bricks[n][0]), [71, 72][(n + course) % 2],
				Transform3D(Basis.IDENTITY, Vector3(float(bricks[n][1]),
					8.0 + 24.0 * float(course + 1), -70.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	for n: int in 5:
		var figure: Minifig = Minifig.surprise(library, rng)
		var turn := Basis(Vector3.UP, deg_to_rad(-25.0 + 12.0 * float(n)))
		var at := Transform3D(turn, Vector3(-100.0 + 50.0 * float(n), 8.0,
			20.0 + 20.0 * absf(float(n) - 2.0)))
		for item: Dictionary in figure.assemble(library):
			_world.add_brick(str(item["part"]), int(item["color"]), at * (item["at"] as Transform3D))


func _showcase() -> void:
	var settings := RenderSettings.new()
	var quality: String = _argument("--quality")
	settings.quality = {"quick": 0, "good": 1, "best": 2}.get(quality, 2)
	var size: String = _argument("--size")
	if not size.is_empty():
		settings.size = Vector2i(size.get_slice("x", 0).to_int(), size.get_slice("x", 1).to_int())
	for key: String in ["lighting", "view"]:
		var said: String = _argument("--" + key)
		if not said.is_empty():
			settings.set(key, said)
	for key: String in ["focal_mm", "f_stop", "focus", "light_turn"]:
		var said: String = _argument("--" + key)
		if not said.is_empty():
			settings.set(key, said.to_float())
	var samples: String = _argument("--samples")
	if not samples.is_empty():
		settings.samples = samples.to_int()
	var backdrop: String = _argument("--backdrop")
	if not backdrop.is_empty():
		settings.backdrop = Color.html(backdrop)
	settings.transparent = _argument("--transparent") == "1"
	var out: String = _argument("--picture")
	if out.is_empty():
		out = OUT + "showcase.png"
	var started: int = Time.get_ticks_msec()
	_render.progress.connect(func(fraction: float, words: String) -> void:
		if int(fraction * 100.0) % 10 == 0:
			print("    %3d%%  %s" % [int(fraction * 100.0), words]))
	var image: Image = await _render.render(_world, settings)
	if image == null:
		print("  FAIL  no picture")
		return
	image.save_png(out)
	print("  wrote %s %dx%d, %d samples, %d tiles, %d ms" % [out, image.get_width(),
		image.get_height(), _render.last_samples, _render.last_tiles,
		Time.get_ticks_msec() - started])


func _say(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""
