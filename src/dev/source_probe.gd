## Does a person's own Render on a table give the model the large bright
## source its glossy tops mirror (photoreal14, docs/RENDERING.md 5r)?
##
##   tools/probe.sh source_probe [OUT]
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1600x1000 \
##       --script src/dev/source_probe.gd -- OUT
##
## As a person does it: the car opened, File, Render…, Best, the Product
## look, then each table under Background (On a desk, On a wooden table, On
## a leather desk pad, On terrazzo) and the seamless backdrop, Picture pressed,
## at the dialog's own size. Each picture and the window as the person sees
## it are kept in OUT (default shots/source): render_<stage>.png,
## dialog_<stage>.png, and offs/render_<stage>.png, the same asked without the
## source.
##
## Checks, on a card that traces rays (Forward+ with Vulkan RT):
##   each picture path traced at the dialog's own size, the stage chosen;
##   on each table the source on by default (StudioRender.PRODUCT_SOURCE),
##     the tracer's "marks" version, and the picture at least CHANGED L* from
##     the same picture with the source asked off (both 640x360, 64 samples,
##     one seed); the seamless without it (none in the tent), and its picture
##     the same as with it asked off;
##   the car on each table at Best, 1280x720, 256 samples: the median of
##     three no slower than CAR_MOST s (the app's own time, ProbeTime).
## Elsewhere (Compatibility, the web, a card without ray tracing) Best has no
## path tracer and so no source: the probe checks each picture is drawn at
## the dialog's size and says so.
extends SceneTree

const MODEL := "res://models/car.ldr"
const TABLES := ["desk", "wood", "leather", "terrazzo"]
const CHANGED := 1.0
const CAR_MOST := 2.9

var _failures: int = 0
var _main: Node
var _out: String = ""
var _last_screen := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device: this probe needs a window")
		quit(1)
		return
	var named: Array = Array(OS.get_cmdline_user_args()).filter(
		func(one: String) -> bool: return not one.begins_with("--"))
	_out = str(named[0]) if not named.is_empty() else ProjectSettings.globalize_path("res://shots/source")
	DirAccess.make_dir_recursive_absolute(_out.path_join("offs"))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var world: BrickWorld = _main.get("_world")
	var library: PartLibrary = _main.get("_library")
	if world == null or library == null or library.parts.is_empty():
		_check("a world and a catalogue", false)
		_finish()
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	var bar: ModelBar = _main.get("_bar")
	world.clear()
	await _frames(2)
	var placed: int = await bar.open_with_progress(MODEL)
	await _frames(20)
	_check("%s opened (%d parts)" % [MODEL, world.brick_count()], placed > 0 and world.brick_count() > 0)
	var traced: bool = PathTracer.available()
	print("  renderer: %s on %s; path traced: %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), traced])
	_main.call("open_render")
	await _frames(10)
	var dialog: RenderDialog = _main.get("_render")
	if not _check("File, Render… is up", dialog != null and dialog.visible):
		_finish()
		return
	dialog.folder = _out
	dialog._make_renderer()
	var controls: Dictionary = dialog.controls_by_name()
	await _click(controls["render_best"])
	await _click(controls["render_look_product"])
	_check("Best, the Product look", dialog.settings.quality == RenderSettings.Quality.BEST
		and dialog.settings.look == "product")
	var size: Vector2i = dialog.settings.size
	for stage: String in TABLES + [""]:
		var picked: bool = await _pick_stage(dialog, controls["render_stage"] as OptionButton, stage)
		var called: String = stage if not stage.is_empty() else "seamless"
		if not _check("Background: %s chosen" % called, picked and dialog.settings.stage == stage):
			continue
		var started: int = Time.get_ticks_msec()
		await _click(controls["render_picture"])
		for _n: int in 3000:
			if not dialog.is_rendering():
				break
			await process_frame
		var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
		await _frames(10)
		var picture: Image = dialog.last_picture()
		var window: Image = await _window()
		window.save_png(_out.path_join("dialog_%s.png" % called))
		if not _check("%s: a picture (%.1f s from the press)" % [called, seconds], picture != null):
			continue
		picture.save_png(_out.path_join("render_%s.png" % called))
		var renderer: StudioRender = dialog.renderer
		var tracer: Object = renderer.get("_tracer")
		var version: String = ("marks" if bool(tracer.get("marked")) else "plain") if tracer != null else "none"
		_check("%s: %dx%d, the dialog's own size, %s" % [called, picture.get_width(),
			picture.get_height(), ("path traced, the tracer's %s version" % version) if renderer.traced_last()
			else "frames averaged (no path tracer here)"],
			picture.get_size() == size and renderer.traced_last() == traced)
		if not traced:
			_check("%s: no path tracer here, so no source (Best frames averaged as before)" % called, true)
			continue
		var level: float = renderer._source_level(dialog.settings)
		var change: float = await _against_off(dialog, world, called)
		if stage.is_empty():
			_check("seamless: no source in the tent (level %.0f), the picture as with it asked off (%.2f L*)"
				% [level, change], level == 0.0 and change < 0.05)
		else:
			_check("%s: the source on by default (level %.0f, the table's key at %.2f), the %s version, "
				% [called, level, StudioRender.SOURCE_KEY, version]
				+ "the picture %.1f L* from it asked off" % change,
				level == StudioRender.PRODUCT_SOURCE and version == "marks" and change >= CHANGED)
	if traced:
		await _times(dialog, world)
	_finish()


## The stage chosen in Background's list as a person chooses it: the item
## selected, as its popup's press selects it.
func _pick_stage(dialog: RenderDialog, choice: OptionButton, stage: String) -> bool:
	for n: int in choice.item_count:
		if str(choice.get_item_metadata(n)) == stage:
			choice.select(n)
			choice.item_selected.emit(n)
			await _frames(5)
			return dialog.settings.stage == stage
	return false


## How far the dialog's own picture is from the same picture with the source
## asked off: mean |dL*| over the whole picture, both drawn at 640x360, 64
## samples, seed 1. The one asked off is kept in OUT/offs.
func _against_off(dialog: RenderDialog, world: BrickWorld, called: String) -> float:
	var pictures: Array[Image] = []
	for off: bool in [false, true]:
		var settings: RenderSettings = dialog.settings.copy()
		settings.size = Vector2i(640, 360)
		settings.samples = 64
		settings.seed = 1
		if off:
			settings.source = 0.0
		var picture: Image = await dialog.renderer.render(world, settings)
		if picture == null:
			return 0.0
		pictures.append(picture)
	pictures[1].save_png(_out.path_join("offs").path_join("render_%s.png" % called))
	var w: int = pictures[0].get_width()
	var h: int = pictures[0].get_height()
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			sum += absf(_lightness(pictures[0].get_pixel(x, y)) - _lightness(pictures[1].get_pixel(x, y)))
			count += 1
	return sum / maxf(float(count), 1.0)


## The car on each table at Best, as photoreal_probe --car times it, with the
## source as by default and asked off.
func _times(dialog: RenderDialog, world: BrickWorld) -> void:
	for stage: String in TABLES:
		for off: bool in [false, true]:
			var times: Array[float] = []
			for n: int in 3:
				var settings: RenderSettings = dialog.settings.copy()
				settings.use_stage(stage)
				settings.size = Vector2i(1280, 720)
				settings.samples = 256
				settings.seed = 1 + n
				if off:
					settings.source = 0.0
				var span := ProbeTime.Span.new()
				var picture: Image = await dialog.renderer.render(world, settings)
				times.append(span.end().own / 1000.0)
				if picture == null:
					break
			times.sort()
			if off:
				print("  (the car on %s at Best with the source asked off: %s s)" % [stage,
					", ".join(times.map(func(t: float) -> String: return "%.2f" % t))])
				continue
			_check("the car on %s at Best, 1280x720, 256 samples: %s s, the median at most %.1f" % [stage,
				", ".join(times.map(func(t: float) -> String: return "%.2f" % t)), CAR_MOST],
				times.size() == 3 and times[1] <= CAR_MOST)


## CIE L* of an sRGB colour.
static func _lightness(colour: Color) -> float:
	var lin: Color = colour.srgb_to_linear()
	var y: float = 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


func _window() -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _click(control: Control) -> void:
	await _frames(2)
	if control == null or not control.is_visible_in_tree():
		_check("the control to press shows (%s)" % (control.name if control != null else "none"), false)
		return
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _move(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(at) - _as_event(_last_screen)
	Input.parse_input_event(move)
	_last_screen = at


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _finish() -> void:
	print("")
	print("source_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	print("  pictures in %s" % _out)
	if _main != null:
		_main.queue_free()
	for _n: int in 5:
		await process_frame
	quit(1 if _failures else 0)
