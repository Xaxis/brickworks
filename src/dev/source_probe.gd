## Does a person's own Render on a table give the model the large bright
## source its glossy tops mirror (photoreal14, on by default since photoreal16;
## docs/RENDERING.md 5r and 5t)?
##
##   tools/probe.sh source_probe [OUT]
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1600x1000 \
##       --script src/dev/source_probe.gd -- OUT
##
## As a person does it: the car opened, File, Render…, Best, the Product
## look, then each table under Background (On a desk, On a wooden table, On
## a leather desk pad, On terrazzo) and the seamless backdrop, Picture pressed,
## at the dialog's own size. Each picture and the window as the person sees
## it are kept in OUT (default shots/source): render_<stage>.png and
## dialog_<stage>.png; and in OUT/pair, <stage>_on.png and <stage>_off.png, the
## same picture at 640x360 as the app draws it and with the source asked off, one
## camera and seed: the after and the before side by side.
##
## Checks, on a card that traces rays (Forward+ with Vulkan RT):
##   each picture path traced at the dialog's own size, the stage chosen;
##   on each table the source on by default (StudioRender.PRODUCT_SOURCE, at
##     SOURCE_LEVEL), the picture at least CHANGED L* from the same picture
##     with it asked off (both 640x360, 64 samples, one seed); the seamless
##     without it (none in the tent), and its picture the same as with it
##     asked off;
##   on each table its own colour kept: where the meter reads its
##     white card (between the 55th and 65th hundredths of its lightness, the car's
##     place left out) within KEPT (CIEDE2000) of the same with the source off.
##     Mirroring the source whole drew it 29 to 39 off on wood, leather and
##     terrazzo, nearly white (photoreal14b, StudioRender.SOURCE_SPILL);
##   the car on each table at Best, 1280x720, 256 samples, as the app draws
##     it: the median of three no slower than CAR_MOST s (the app's own time,
##     ProbeTime); its time with the source asked off printed beside it.
## Elsewhere (Compatibility, the web, a card without ray tracing) Best has no
## path tracer and so no source: the probe checks each picture is drawn at
## the dialog's size and says so.
extends SceneTree

const MODEL := "res://models/car.ldr"
const TABLES := ["desk", "wood", "leather", "terrazzo"]
const CHANGED := 1.0
const CAR_MOST := 2.9
const KEPT := 8.0

var _failures: int = 0
var _main: Node
var _out: String = ""
var _last_screen := Vector2.ZERO
var _pair: Array[Image] = []


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
	DirAccess.make_dir_recursive_absolute(_out.path_join("pair"))
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
		if not stage.is_empty() and _pair.size() == 2:
			var on_colour: Vector3 = _table_colour(_pair[0])
			var off_colour: Vector3 = _table_colour(_pair[1])
			var apart: float = _de2000(off_colour, on_colour)
			_check("%s: the table keeps its own colour, %.1f apart (CIEDE2000, at most %.0f): L* %.1f a %.1f b %.1f, off %.1f %.1f %.1f"
				% [called, apart, KEPT, on_colour.x, on_colour.y, on_colour.z, off_colour.x, off_colour.y,
				off_colour.z], apart <= KEPT)
		if stage.is_empty():
			_check("seamless: no source in the tent (level %.0f), the picture as with it asked off (%.2f L*)"
				% [level, change], level == 0.0 and change < 0.05)
		else:
			_check("%s: the source on by default (level %.0f, the table's key at %.2f), "
				% [called, level, StudioRender.SOURCE_KEY]
				+ "the picture %.1f L* from it asked off" % change,
				level == StudioRender.PRODUCT_SOURCE and level == StudioRender.SOURCE_LEVEL and level > 0.0
				and change >= CHANGED)
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


## How far the dialog's picture, as the app draws it, is from the same
## picture with the source asked off: mean |dL*| over the whole picture, both
## drawn at 640x360, 64 samples, seed 1. Both are kept in OUT/pair.
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
	_pair = pictures
	pictures[0].save_png(_out.path_join("pair").path_join("%s_on.png" % called))
	pictures[1].save_png(_out.path_join("pair").path_join("%s_off.png" % called))
	var w: int = pictures[0].get_width()
	var h: int = pictures[0].get_height()
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			sum += absf(_lightness(pictures[0].get_pixel(x, y)) - _lightness(pictures[1].get_pixel(x, y)))
			count += 1
	return sum / maxf(float(count), 1.0)


## The car on each table at Best, as photoreal_probe --car times it, as the
## app draws it and with the source asked off.
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


## The table's colour where the meter reads its white card (StudioRender's
## _open_floor reads the 60th hundredth of the floor's lightness): the mean,
## in linear light, of what lies between the 55th and the 65th, the car's
## place (the middle of a 640x360 picture) left out; as CIE Lab.
static func _table_colour(picture: Image) -> Vector3:
	var seen: Array = []
	var w: int = picture.get_width()
	var h: int = picture.get_height()
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			if x >= w * 9 / 32 and x <= w * 47 / 64 and y >= h * 25 / 72 and y <= h * 31 / 36:
				continue
			var lin: Color = picture.get_pixel(x, y).srgb_to_linear()
			seen.append([0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b, Vector3(lin.r, lin.g, lin.b)])
	seen.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var sum := Vector3.ZERO
	var from: int = int(seen.size() * 0.55)
	var to: int = int(seen.size() * 0.65)
	for n: int in range(from, to):
		sum += seen[n][1]
	return _lab(sum / float(maxi(to - from, 1)))


## CIE Lab (D65) of a linear sRGB colour.
static func _lab(c: Vector3) -> Vector3:
	var x: float = (0.4124 * c.x + 0.3576 * c.y + 0.1805 * c.z) / 0.95047
	var y: float = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
	var z: float = (0.0193 * c.x + 0.1192 * c.y + 0.9505 * c.z) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 216.0 / 24389.0 else (24389.0 / 27.0 * t + 16.0) / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## CIEDE2000 between two Lab colours.
static func _de2000(one: Vector3, two: Vector3) -> float:
	var c1: float = Vector2(one.y, one.z).length()
	var c2: float = Vector2(two.y, two.z).length()
	var cm: float = (c1 + c2) / 2.0
	var g: float = 0.5 * (1.0 - sqrt(pow(cm, 7.0) / (pow(cm, 7.0) + pow(25.0, 7.0))))
	var a1: float = (1.0 + g) * one.y
	var a2: float = (1.0 + g) * two.y
	var c1p: float = Vector2(a1, one.z).length()
	var c2p: float = Vector2(a2, two.z).length()
	var h1: float = fposmod(rad_to_deg(atan2(one.z, a1)), 360.0)
	var h2: float = fposmod(rad_to_deg(atan2(two.z, a2)), 360.0)
	var dl: float = two.x - one.x
	var dc: float = c2p - c1p
	var dh: float = 0.0
	if c1p * c2p != 0.0:
		dh = h2 - h1
		if dh > 180.0:
			dh -= 360.0
		elif dh < -180.0:
			dh += 360.0
	var dhh: float = 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh / 2.0))
	var lm: float = (one.x + two.x) / 2.0
	var cpm: float = (c1p + c2p) / 2.0
	var hm: float = h1 + h2
	if c1p * c2p != 0.0:
		if absf(h1 - h2) <= 180.0:
			hm = (h1 + h2) / 2.0
		else:
			hm = (h1 + h2 + 360.0) / 2.0 if h1 + h2 < 360.0 else (h1 + h2 - 360.0) / 2.0
	var t: float = 1.0 - 0.17 * cos(deg_to_rad(hm - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hm)) \
		+ 0.32 * cos(deg_to_rad(3.0 * hm + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hm - 63.0))
	var theta: float = 30.0 * exp(-pow((hm - 275.0) / 25.0, 2.0))
	var rc: float = 2.0 * sqrt(pow(cpm, 7.0) / (pow(cpm, 7.0) + pow(25.0, 7.0)))
	var sl: float = 1.0 + 0.015 * pow(lm - 50.0, 2.0) / sqrt(20.0 + pow(lm - 50.0, 2.0))
	var sc: float = 1.0 + 0.045 * cpm
	var sh: float = 1.0 + 0.015 * cpm * t
	var rt: float = -sin(deg_to_rad(2.0 * theta)) * rc
	return sqrt(pow(dl / sl, 2.0) + pow(dc / sc, 2.0) + pow(dhh / sh, 2.0) + rt * (dc / sc) * (dhh / sh))


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
