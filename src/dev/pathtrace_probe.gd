## Is Best path traced, quick enough, clean enough, lit as light is, and
## does the render queue draw while the window is used (APP_UX3 pathtrace)?
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/pathtrace_probe.gd
##
## On a graphics card that traces rays (the box's RX 6700 XT); elsewhere it
## says Best is not path traced there, and why, and passes on that alone.
##
##   the car at 1280x720, 256 samples, in 60 s or less, path traced;
##   its noise against a 4,096-sample picture of the same, traced with
##     other samples, below NOISE_MOST (and 16 samples' well above it, so
##     the measure sees noise);
##   soft shadows: a column's shadow on the floor is wider at its tip than
##     at its foot, measured at three points along it;
##   light bounced off the floor: a white wall on an orange floor is tinted
##     orange low down and less so higher up, at three heights, where Best
##     frames averaged has no tint;
##   the queue: File, Render queue… opens its panel; three renders, two
##     from the panel's Add and one from render_queue over MCP, each of the
##     view and the model as they were when added, are drawn in turn and
##     written, while the window is turned every frame; render_queue lists
##     them and shows the last.
##
## Leaves shots/pathtrace/: the car traced and frames averaged, the
## measured scenes, and the window with the queue at 1400x900 and 1280x720.
extends SceneTree

const OUT := "res://shots/pathtrace/"
## The most the 256-sample car may differ from the 4,096-sample one, root
## mean square over every pixel's channels, 0 to 1: 5 of 255.
const NOISE_MOST := 0.02
const CAR_SECONDS := 60.0
const ORANGE := Color(0.95, 0.45, 0.1)

var _failures: int = 0
var _main: Node
var _render: StudioRender
var _world: BrickWorld
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _check(words: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", words])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	_world = _main.get("_world")
	_library = _main.get("_library")
	if _world == null or _library == null or _library.parts.is_empty():
		_check("a world and a catalogue", false)
		quit(1)
		return
	(_main.get("_builder") as Builder).hide_preview()
	print("  renderer: %s on %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name()])
	if not PathTracer.available():
		print("  Best is not path traced here: %s" % PathTracer.why_not())
		_check("it says why", not PathTracer.why_not().is_empty())
		quit(1 if _failures else 0)
		return
	_render = StudioRender.new()
	_render.library = _library
	_render.scenery = (_main.get("_store") as ModelStore).scenery
	_render.eye = _main.get("_camera")
	_render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)

	var bar: ModelBar = _main.get("_bar")
	await bar.open_with_progress("res://models/car.ldr")
	await _frames(10)
	print("  the car: %d parts" % _world.brick_count())
	await _car()
	await _queue()
	await _light()
	print("")
	print("%d failed" % _failures if _failures else "Best is path traced, and the queue draws in turn")
	quit(1 if _failures else 0)


func _best(size: Vector2i, samples: int) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.BEST
	settings.size = size
	settings.samples = samples
	settings.view = "hero"
	return settings


# -- the car: time and noise --------------------------------------------------


func _car() -> void:
	print("\n  the car at 1280x720")
	var settings: RenderSettings = _best(Vector2i(1280, 720), 256)
	settings.seed = 1
	var started: int = Time.get_ticks_msec()
	var picture: Image = await _render.render(_world, settings)
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	if picture == null:
		_check("the car is drawn", false)
		return
	picture.save_png(OUT + "car_best_traced_1280x720.png")
	_check("the car, 256 samples, path traced (%s, %d samples)" % [_render.traced_last(),
		_render.last_samples], _render.traced_last() and _render.last_samples == 256)
	_check("in %.1f s on %s (at most %.0f s; the longest frame %.0f ms, %s)" % [seconds,
		RenderingServer.get_video_adapter_name(), CAR_SECONDS, _render.worst_frame_ms,
		_render.worst_step], seconds <= CAR_SECONDS)

	# The same picture with 4,096 other samples is as near the truth as
	# this measure needs: what the 256 differ from it by is their noise.
	var reference_settings: RenderSettings = settings.copy()
	reference_settings.samples = 4096
	reference_settings.seed = 2
	started = Time.get_ticks_msec()
	var reference: Image = await _render.render(_world, reference_settings)
	var reference_seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	var rough_settings: RenderSettings = settings.copy()
	rough_settings.samples = 16
	rough_settings.seed = 3
	var rough: Image = await _render.render(_world, rough_settings)
	if reference == null or rough == null:
		_check("the reference and 16 samples are drawn", false)
		return
	reference.save_png(OUT + "car_best_traced_4096.png")
	rough.save_png(OUT + "car_best_traced_16.png")
	var noise: float = _rmse(picture, reference)
	var rough_noise: float = _rmse(rough, reference)
	_check("its noise against 4,096 samples (%.0f s): %.4f, at most %.4f" % [reference_seconds,
		noise, NOISE_MOST], noise <= NOISE_MOST)
	_check("and the measure sees noise: 16 samples are %.4f, %.1f times as much" % [rough_noise,
		rough_noise / maxf(noise, 0.0001)], rough_noise > noise * 2.5)

	# Best as it was, frames averaged, for the report's before and after.
	var before: RenderSettings = _best(Vector2i(1280, 720), 0)
	before.traced = false
	started = Time.get_ticks_msec()
	var raster: Image = await _render.render(_world, before)
	if raster != null:
		raster.save_png(OUT + "car_best_frames_1280x720.png")
		print("    frames averaged, as Best was: %d frames in %.1f s" % [_render.last_samples,
			float(Time.get_ticks_msec() - started) / 1000.0])


## Root mean square difference over every channel of every pixel, 0 to 1.
static func _rmse(a: Image, b: Image) -> float:
	var first: PackedByteArray = a.get_data() if a.get_format() == Image.FORMAT_RGB8 \
		else _rgb(a).get_data()
	var second: PackedByteArray = b.get_data() if b.get_format() == Image.FORMAT_RGB8 \
		else _rgb(b).get_data()
	if first.size() != second.size() or first.is_empty():
		return 1.0
	var sum: float = 0.0
	for n: int in first.size():
		var d: float = float(first[n] - second[n])
		sum += d * d
	return sqrt(sum / float(first.size())) / 255.0


static func _rgb(image: Image) -> Image:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGB8)
	return copy


# -- the light: soft shadows and bounce, at three points each --------------------


func _light() -> void:
	print("\n  soft shadows and light off the floor")
	_world.clear()
	await _frames(2)
	# A white wall, three bricks high, its face to the front.
	for n: int in 3:
		_world.add_brick("3001", 15, Transform3D(Basis.IDENTITY, Vector3(0, 24.0 * (n + 1), 0)))
	var wall: AABB = _world.model_bounds()
	# A thin white column off to the side, seven bricks high.
	var column_at := Vector3(140, 0, -20)
	for n: int in 7:
		_world.add_brick("3005", 15, Transform3D(Basis.IDENTITY,
			column_at + Vector3(0, 24.0 * (n + 1), 0)))
	await _frames(3)
	var column_top: float = 24.0 * 7.0

	# Bounce, from the front: the wall's face at three heights.
	var front: RenderSettings = _best(Vector2i(960, 540), 512)
	front.view = "front"
	front.backdrop = ORANGE
	var traced: Image = await _render.render(_world, front)
	var traced_shot: StudioRender.Shot = _render.last_shot
	var frames_front: RenderSettings = front.copy()
	frames_front.traced = false
	frames_front.samples = 0
	var raster: Image = await _render.render(_world, frames_front)
	var raster_shot: StudioRender.Shot = _render.last_shot
	if traced == null or raster == null:
		_check("the wall is drawn", false)
		return
	traced.save_png(OUT + "bounce_traced.png")
	raster.save_png(OUT + "bounce_frames.png")
	var face_z: float = wall.end.z if traced_shot.origin.z > wall.get_center().z \
		else wall.position.z
	var tints: Array = []
	for share: float in [0.12, 0.5, 0.88]:
		var at := Vector3(wall.get_center().x, wall.position.y + wall.size.y * share,
			face_z + signf(traced_shot.origin.z - face_z) * 0.5)
		var with: float = _tint(_patch(traced, _project(traced_shot, at, traced.get_size())))
		var without: float = _tint(_patch(raster, _project(raster_shot, at, raster.get_size())))
		tints.append([share, with, without])
		print("    the wall's face %d%% up: orange %.3f path traced, %.3f frames averaged"
			% [roundi(share * 100.0), with, without])
	var low: Array = tints[0]
	var high: Array = tints[2]
	_check("light off the orange floor tints the wall low down (%.3f) more than high up (%.3f)"
		% [low[1], high[1]], float(low[1]) > float(high[1]) + 0.02 and float(tints[1][1])
			>= float(high[1]) - 0.005)
	_check("where frames averaged has no such tint (%.3f low, %.3f high)" % [low[2], high[2]],
		float(low[1]) - float(low[2]) > 0.03 and absf(float(low[2]) - float(high[2])) < 0.02)

	# Shadow, from above: the column's on the floor, across it at three
	# points from its foot to its tip.
	var above: RenderSettings = _best(Vector2i(960, 540), 512)
	above.view = "top"
	await _render.render(_world, above)
	var key: Vector3 = _key_direction()
	if key.y >= -0.05:
		_check("the key light shines down (%s)" % key, false)
		return
	var along := Vector3(key.x, 0.0, key.z) / -key.y
	var tip: Vector3 = column_at + along * column_top
	# A flat tile past the tip, so the picture is framed on the shadow too.
	_world.add_brick("3024", 15, Transform3D(Basis.IDENTITY, tip + along.normalized() * 60.0
		+ Vector3(0, 8, 0)))
	await _frames(3)
	var lit: Image = await _render.render(_world, above)
	var shot: StudioRender.Shot = _render.last_shot
	var unlit_settings: RenderSettings = above.copy()
	unlit_settings.no_shadows = true
	var unlit: Image = await _render.render(_world, unlit_settings)
	var frames_above: RenderSettings = above.copy()
	frames_above.traced = false
	frames_above.samples = 0
	var lit_frames: Image = await _render.render(_world, frames_above)
	var frames_shot: StudioRender.Shot = _render.last_shot
	frames_above.no_shadows = true
	var unlit_frames: Image = await _render.render(_world, frames_above)
	if lit == null or unlit == null or lit_frames == null or unlit_frames == null:
		_check("the shadow is drawn", false)
		return
	lit.save_png(OUT + "shadow_traced.png")
	lit_frames.save_png(OUT + "shadow_frames.png")
	var widths: Array = []
	var floor_y: float = 0.5
	for share: float in [0.25, 0.5, 0.8]:
		var at: Vector3 = column_at + Vector3(0, floor_y, 0) + along * column_top * share
		var width: float = _penumbra(lit, unlit, shot, at, along)
		var width_frames: float = _penumbra(lit_frames, unlit_frames, frames_shot, at, along)
		widths.append(width)
		print("    the shadow %d%% of the way to its tip: its edge %.1f LDU wide path traced, "
			% [roundi(share * 100.0), width] + "%.1f frames averaged" % width_frames)
	_check("the shadow softens from its foot to its tip (%.1f, %.1f, %.1f LDU)" % widths,
		float(widths[0]) > 0.0 and float(widths[1]) > float(widths[0])
			and float(widths[2]) > float(widths[1]) and float(widths[2]) > float(widths[0]) * 1.5)


## Which way the key light shines, as the last render dressed it.
func _key_direction() -> Vector3:
	var best: DirectionalLight3D = null
	for light: DirectionalLight3D in _render.get("_lights"):
		if light.visible and (best == null or light.light_energy > best.light_energy):
			best = light
	return -best.global_transform.basis.z.normalized() if best != null else Vector3.ZERO


## Where [param at] is in a picture of [param size] taken from [param shot].
static func _project(shot: StudioRender.Shot, at: Vector3, size: Vector2i) -> Vector2:
	var local: Vector3 = shot.basis.inverse() * (at - shot.origin)
	if local.z >= -0.001:
		return Vector2(-1, -1)
	var tan_half: float = tan(deg_to_rad(shot.fov) * 0.5)
	var aspect: float = float(size.x) / float(size.y)
	var x: float = local.x / (-local.z * tan_half * aspect)
	var y: float = local.y / (-local.z * tan_half)
	return Vector2((x + 1.0) * 0.5 * size.x, (1.0 - y) * 0.5 * size.y)


## The mean colour of a 7 by 7 patch round [param at].
static func _patch(image: Image, at: Vector2) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count: int = 0
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var x: int = roundi(at.x) + dx
			var y: int = roundi(at.y) + dy
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				sum += image.get_pixel(x, y)
				count += 1
	return sum / float(maxi(count, 1))


## How orange: red over blue, as a share of the whole.
static func _tint(colour: Color) -> float:
	return (colour.r - colour.b) / maxf(colour.r + colour.g + colour.b, 0.001)


## How wide the shadow's edge is, in LDU, across it at [param at]: from
## where it is 90% as dark as its middle to where it is 10%, the mean of
## its two sides. Each step across is the mean of five along, against the
## grain of the samples.
func _penumbra(lit: Image, unlit: Image, shot: StudioRender.Shot, at: Vector3,
		along: Vector3) -> float:
	var forward: Vector3 = along.normalized()
	var across: Vector3 = Vector3.UP.cross(forward).normalized()
	var steps: PackedFloat32Array = PackedFloat32Array()
	var drops: PackedFloat32Array = PackedFloat32Array()
	var reach: float = 40.0
	var step: float = 0.5
	var offset: float = -reach
	while offset <= reach:
		var drop: float = 0.0
		for n: int in range(-2, 3):
			var point: Vector3 = at + across * offset + forward * float(n)
			var pixel: Vector2 = _project(shot, point, lit.get_size())
			var x: int = clampi(roundi(pixel.x), 0, lit.get_width() - 1)
			var y: int = clampi(roundi(pixel.y), 0, lit.get_height() - 1)
			drop += unlit.get_pixel(x, y).get_luminance() - lit.get_pixel(x, y).get_luminance()
		steps.append(offset)
		drops.append(drop / 5.0)
		offset += step
	var deepest: float = 0.0
	var middle: int = 0
	for n: int in drops.size():
		if drops[n] > deepest:
			deepest = drops[n]
			middle = n
	if deepest < 0.03:
		return -1.0
	var width: float = 0.0
	for way: int in [-1, 1]:
		var inner: float = steps[middle]
		var outer: float = steps[middle]
		var n: int = middle
		while n >= 0 and n < drops.size() and drops[n] >= deepest * 0.9:
			inner = steps[n]
			n += way
		while n >= 0 and n < drops.size() and drops[n] >= deepest * 0.1:
			outer = steps[n]
			n += way
		width += absf(outer - inner)
	return width * 0.5


# -- the queue -------------------------------------------------------------------


func _queue() -> void:
	print("\n  the render queue, with the window in use")
	var shell: Shell = _main.get("_shell")
	_check("File has Render queue…", shell.menu_id("render_queue") >= 0
		and shell.can("render_queue"))
	shell.run("render_queue")
	await _frames(3)
	var queue: RenderQueue = _main.get_node("HUD").get_node_or_null("RenderQueue") as RenderQueue
	_check("it opens its panel", queue != null and queue.visible)
	if queue == null:
		return
	var folder: String = ProjectSettings.globalize_path(OUT + "queue")
	DirAccess.make_dir_recursive_absolute(folder)
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	queue.folder = folder
	var dialog: RenderDialog = _main.get("_render")
	dialog.settings.quality = RenderSettings.Quality.BEST
	dialog.settings.size = Vector2i(960, 540)
	dialog.settings.samples = 128
	dialog.settings.view = "current"
	var camera: Node = _main.get("_camera")
	var controls: Dictionary = queue.controls_by_name()

	# One as the window looks now.
	(controls["queue_add"] as Button).pressed.emit()
	# Then a bright green brick on the roof, and the view turned.
	var roof: AABB = _world.model_bounds()
	var green: int = _world.add_brick("3001", 2, Transform3D(Basis.IDENTITY,
		Vector3(roof.get_center().x, roof.end.y + 24.0, roof.get_center().z)))
	camera.call("turn_by_drag", Vector2(160, 0))
	await _frames(2)
	(controls["queue_add"] as Button).pressed.emit()
	camera.call("turn_by_drag", Vector2(160, 0))
	await _frames(2)
	# And one by the session's tool.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var said: String = str(await tools.run("render_queue", {"action": "add"}))
	print("    render_queue add: %s" % said.get_slice("\n", 0))
	_check("render_queue adds a third", queue.items.size() == 3)

	# The window used while they are drawn: turned a little every frame.
	var began: Dictionary = {}
	var ended: Dictionary = {}
	var watch := func() -> void:
		for item: RenderQueue.Item in queue.items:
			if item.state == "drawing" and not began.has(item.number):
				began[item.number] = Time.get_ticks_msec()
			if item.finished() and not ended.has(item.number):
				ended[item.number] = Time.get_ticks_msec()
	queue.changed.connect(watch)
	var frames: PackedFloat32Array = PackedFloat32Array()
	var last: int = Time.get_ticks_usec()
	var shot_taken: bool = false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 240000:
		camera.call("turn_by_drag", Vector2(2, 0))
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		watch.call()
		if not shot_taken and queue.is_drawing() and Time.get_ticks_msec() - started > 1500:
			shot_taken = true
			await _shoot("queue_window_1400x900")
		var left: int = 0
		for item: RenderQueue.Item in queue.items:
			if not item.finished():
				left += 1
		if left == 0:
			break
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	for line: String in queue.lines():
		print("    %s" % line)
	var done: int = 0
	for item: RenderQueue.Item in queue.items:
		if item.state == "done":
			done += 1
	_check("three queued renders made (%d done in %.1f s)" % [done, seconds], done == 3)
	var in_turn: bool = began.size() == 3 and ended.size() == 3
	for n: int in [1, 2]:
		in_turn = in_turn and int(ended.get(n, 0)) <= int(began.get(n + 1, 0))
	_check("one after the other (began %s, ended %s)" % [_times(began, started),
		_times(ended, started)], in_turn)
	var sorted: PackedFloat32Array = frames.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 999.0
	var p95: float = sorted[int(float(sorted.size() - 1) * 0.95)] if not sorted.is_empty() \
		else 999.0
	_check("the window drew %d frames meanwhile, turning: median %.0f ms, 95%% within %.0f ms"
		% [frames.size(), median, p95] + ", the longest %.0f ms" % (sorted[-1] if not
			sorted.is_empty() else 0.0), median <= 34.0 and p95 <= 60.0)

	var pictures: Array[Image] = []
	for item: RenderQueue.Item in queue.items:
		var image := Image.new()
		var ok: bool = not item.path.is_empty() and image.load(item.path) == OK
		pictures.append(image if ok else null)
		_check("%d written: %s" % [item.number, item.path.get_file()], ok
			and image.get_size() == Vector2i(960, 540))
	if pictures.has(null):
		return
	_check("each of its own view (1 and 2 differ by %.3f, 2 and 3 by %.3f)"
		% [_rmse(pictures[0], pictures[1]), _rmse(pictures[1], pictures[2])],
		_rmse(pictures[0], pictures[1]) > 0.03 and _rmse(pictures[1], pictures[2]) > 0.03)
	var greens: Array[float] = []
	for image: Image in pictures:
		greens.append(_green_share(image))
	_check("each of the model as it was: no green brick in 1 (%.2f%%), one in 2 (%.2f%%)"
		% [greens[0] * 100.0, greens[1] * 100.0], greens[0] < 0.001 and greens[1] > 0.002)
	_check("each path traced, 128 samples (%s)" % ", ".join(PackedStringArray(queue.items.map(
		func(item: RenderQueue.Item) -> String: return "%s %d" % [item.traced, item.samples]))),
		queue.items.all(func(item: RenderQueue.Item) -> bool:
			return item.traced and item.samples == 128))
	said = str(await tools.run("render_queue", {"action": "list"}))
	_check("render_queue lists all three, done", said.count("wrote") == 3)
	var shown: Variant = await tools.run("render_queue", {"action": "list", "number": 3})
	_check("render_queue number=3 shows the picture", shown is Array
		and str((shown as Array)[1].get("type", "")) == "image")
	# The window at the other size, with the panel.
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(20)
	await _shoot("queue_window_1280x720")
	DisplayServer.window_set_size(Vector2i(1400, 900))
	await _frames(10)
	queue.close()
	_world.remove_brick(green)


func _times(at: Dictionary, since: int) -> String:
	var out := PackedStringArray()
	for n: int in [1, 2, 3]:
		out.append("%.1f" % (float(int(at.get(n, since)) - since) / 1000.0))
	return ", ".join(out)


## The share of pixels the bright green of LDraw's colour 2 (Green).
static func _green_share(image: Image) -> float:
	var hits: int = 0
	var seen: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			seen += 1
			if c.g > 0.25 and c.g > c.r * 1.6 and c.g > c.b * 1.4:
				hits += 1
	return float(hits) / float(maxi(seen, 1))


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(OUT + name + ".png")
	print("    the window: %s.png (%dx%d)" % [name, image.get_width(), image.get_height()])
