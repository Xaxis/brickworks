## File, Render's Building, and render_model kind "build": the model built up
## as a video (docs/APP_UX3.md, unit 5, buildvideo).
##
##   godot --path . --resolution 1280x720 --script src/dev/buildvideo_probe.gd
##   ... -- [OUT_DIR]   (the pictures of the dialog; the run's own data when not given)
##
## On the car, with Quick and 720p chosen in Render once before, as a person
## who made a draft first has them:
##  1. From the model, Render, Building's 20 s and Return: three actions, and
##     a 20 s video is drawn, 480 frames at 1280 x 720: a WebP of 480 frames,
##     480 PNGs and an MP4 of 20 s where ffmpeg is installed.
##  2. In every frame drawn, the parts on show (on the render's own stage, as
##     it drew that frame) are the first so many of the timeline's order, read
##     from Timeline itself, and never fewer than the frame before; the first
##     frame shows one, the last all 61, each where it stands in the model.
##  3. The last frame is the whole model: the same as a picture drawn with the
##     same choices, and far from the first frame.
##  4. render_model {"kind": "build"} over MCP in one call, a job, the job's
##     answer naming the parts, steps and length and the WebP of 480 frames.
##  5. Nothing went into the system's Downloads: a probe's run is held
##     (Outside), so every file went into its own data (Download.downloads).
##  6. The model stands as built after each, and its undo is as it was.
extends SceneTree

const MODEL := "res://models/car.ldr"
const SECONDS := 20

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _dialog: RenderDialog
var _out: String = ""
var _next: int = 0
var _last_screen := Vector2.ZERO
## Frame number -> the bricks on show on the render's stage as it drew it.
var _seen: Dictionary = {}
var _watched: PackedInt64Array = PackedInt64Array()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("buildvideo")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	if not StudioRender.possible():
		print("buildvideo probe: needs a window (tools/probe.sh runs it in one)")
		quit(3)
		return
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_dialog = _main.get("_render")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	(_main.get("_store") as ModelStore).keeps = false
	var placed: int = await (_main.get("_bar") as ModelBar).open_with_progress(MODEL)
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_builder.forget_history()
	if _check("%s opened, %d parts" % [MODEL, placed], placed > 0):
		await _by_hand()
		await _over_mcp()
	print("")
	if _failures == 0:
		print("buildvideo: Render, Building, Return drew the car going up in 480 frames, every frame a "
			+ "prefix of the timeline's order and the last the whole model; render_model build did the "
			+ "same in one call; nothing went into the system's Downloads")
	else:
		print("buildvideo: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- by hand --------------------------------------------------------------------


func _by_hand() -> void:
	print("── by hand: Render, Building, Return ──")
	var order: PackedInt64Array = await _timeline_order()
	if not _check("the timeline's order: %d parts" % order.size(), order.size() == _parts()):
		return
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	# Quick and 720p chosen once before, as a person who drew a draft has them.
	_shell().run("render")
	await _frames(20)
	await _click(_named("render_quick"))
	await _click(_named("render_size_720p"))
	await _shot("dialog_open")
	_dialog.close()
	await _frames(10)

	_watch(order)
	var actions: int = 0
	_shell().run("render")
	actions += 1
	await _frames(20)
	var choices: ScrollContainer = _named("render_choices")
	choices.ensure_control_visible(_named("render_length_%d" % SECONDS))
	await _frames(6)
	await _click(_named("render_length_%d" % SECONDS))
	actions += 1
	# The choices at their foot for the picture: Building's words under its lengths.
	choices.scroll_vertical = int(choices.get_v_scroll_bar().max_value)
	await _shot("dialog_building")
	await _key(KEY_ENTER)
	actions += 1
	var began: int = Time.get_ticks_msec()
	for _n: int in 200:
		await process_frame
		if _dialog.is_rendering():
			break
	_check("Return renders the building: %s" % _dialog._working, _dialog._working == "building")
	await _rendered(900)
	var took: float = float(Time.get_ticks_msec() - began) / 1000.0
	var last: Dictionary = _dialog._last
	_check("in %d actions from the model (Render, Building's %d s, Return): %s, %.0f s" % [actions,
		SECONDS, last.get("kind", "nothing"), took], actions <= 3 and last.get("kind", "") == "building")
	await _shot("dialog_built")
	var frames: int = SECONDS * 24
	var webp: String = _path_of(last, ".webp")
	_files(webp, frames, "the dialog's")
	_prefixes(order, frames)
	await _last_is_whole(webp.get_basename(), frames)
	_check("...and the model stands as built (%d parts off), its undo as it was (%d, was %d)"
		% [_off(built), _builder.history_depth(), depth], _off(built) == 0
		and _builder.history_depth() == depth)
	_dialog.close()
	await _frames(10)


## The order Timeline shows the model in, read from Timeline itself.
func _timeline_order() -> PackedInt64Array:
	_shell().run("timeline")
	var steps_bar: StepsBar = _main.get("_steps")
	for _n: int in 600:
		await process_frame
		if steps_bar.is_playing_back() and not steps_bar.is_starting():
			break
	var order := PackedInt64Array()
	var seen: Dictionary = {}
	for step: Instructions.Step in steps_bar.steps():
		for brick_id: int in step.brick_ids:
			if not seen.has(brick_id):
				seen[brick_id] = true
				order.append(brick_id)
	steps_bar.stop()
	await _frames(10)
	return order


## Each frame as the renderer draws it: which of [param order] stand on its
## stage at a size (a part not yet arrived is drawn at none).
func _watch(order: PackedInt64Array) -> void:
	_watched = order
	_seen.clear()
	var said := RegEx.create_from_string("^frame (\\d+) of (\\d+)$")
	_dialog.renderer.progress.connect(func(_fraction: float, words: String) -> void:
		var found: RegExMatch = said.search(words)
		if found == null:
			return
		var on := PackedInt64Array()
		for brick_id: int in _watched:
			if absf(_dialog.renderer.staged_transform(brick_id).basis.determinant()) > 1e-6:
				on.append(brick_id)
		_seen[int(found.get_string(1)) - 1] = [on, _homes_at(on)])


## How many of [param on] stand on the stage exactly where they stand in the model.
func _homes_at(on: PackedInt64Array) -> int:
	var home: int = 0
	for brick_id: int in on:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and _dialog.renderer.staged_transform(brick_id).is_equal_approx(brick.transform):
			home += 1
	return home


func _prefixes(order: PackedInt64Array, frames: int) -> void:
	var seen: Dictionary = _seen.duplicate()
	_seen.clear()
	_watched = PackedInt64Array()
	var bad: Array = []
	var before: int = 0
	var counts := PackedInt32Array()
	for n: int in frames:
		if not seen.has(n):
			bad.append("frame %d not seen" % (n + 1))
			continue
		var on: PackedInt64Array = seen[n][0]
		counts.append(on.size())
		var prefix: Dictionary = {}
		for k: int in on.size():
			prefix[order[k]] = true
		var all_in: bool = true
		for brick_id: int in on:
			all_in = all_in and prefix.has(brick_id)
		if not all_in or on.size() < before:
			bad.append("frame %d: %d on show, not the first %d" % [n + 1, on.size(), on.size()])
		before = on.size()
	print("    parts on show, every 40th frame: %s" % str(Array(counts).slice(0, counts.size(), 40)))
	_check("every frame of %d shows the first so many of the timeline's order, never fewer%s"
		% [frames, "" if bad.is_empty() else ": " + ", ".join(bad.slice(0, 4))], bad.is_empty())
	var first: int = (seen[0][0] as PackedInt64Array).size() if seen.has(0) else -1
	var last: Array = seen.get(frames - 1, [PackedInt64Array(), 0])
	_check("the first frame shows %d part, the last %d of %d, %d where they stand in the model"
		% [first, (last[0] as PackedInt64Array).size(), order.size(), last[1]], first == 1
		and (last[0] as PackedInt64Array).size() == order.size() and int(last[1]) == order.size())
	var build: BuildRender = _dialog._last.get("build")
	var planned: Array = Array(build.shown) if build != null else []
	_check("...as the build's own plan says, frame for frame (%d steps)" % (build.steps if build != null else 0),
		planned == Array(counts))


## The WebP, the frames and the MP4 of [param webp], [param frames] long,
## each in the run's own data and none in the system's Downloads.
func _files(webp: String, frames: int, whose: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(webp)
	var chunks: PackedStringArray = AnimatedWebP.chunk_tags(bytes)
	var still: Image = Image.new()
	still.load_webp_from_buffer(AnimatedWebP.still(bytes, frames - 1))
	_check("%s WebP: %d frames of %dx%d, %.1f MB (%s)" % [whose, chunks.count("ANMF"),
		still.get_width(), still.get_height(), bytes.size() / 1e6, webp.get_file()],
		chunks.count("ANMF") == frames and still.get_size() == Vector2i(1280, 720))
	var dir: String = webp.get_basename()
	var pngs: int = 0
	for file: String in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else []:
		if file.begins_with("frame_") and file.ends_with(".png"):
			pngs += 1
	var mp4: String = dir + ".mp4"
	var length: String = _mp4_length(mp4)
	_check("...%d PNGs; an MP4 of %s s" % [pngs, length if not length.is_empty() else "none"],
		pngs == frames and (RenderOutput.ffmpeg().is_empty() or absf(length.to_float() - SECONDS) < 0.1))
	var system: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var own: String = OS.get_user_data_dir()
	_check("...written in this run's own data (%s), not the system's Downloads (%s): held %s"
		% [webp.get_base_dir(), system, Outside.held()], Outside.held() and webp.begins_with(own)
		and (system.is_empty() or not webp.begins_with(system)) and FileAccess.file_exists(webp))


## The last frame against a picture drawn with the same choices, and the first.
func _last_is_whole(dir: String, frames: int) -> void:
	var last: Image = Image.load_from_file(dir.path_join("frame_%04d.png" % frames))
	var first: Image = Image.load_from_file(dir.path_join("frame_0001.png"))
	var chosen: RenderSettings = _dialog.settings.copy()
	chosen.contact_shadow = false
	var said: String = await _dialog.render_for("picture", chosen)
	var picture: Image = _dialog.last_picture()
	if not _check("a picture with the same choices: %s" % said, picture != null and last != null):
		return
	picture.convert(last.get_format())
	var off: Vector2 = _difference(last, picture)
	_check("the last frame is the whole model: %.2f grey levels from the picture on average, %.2f%% of "
		% [off.x, off.y * 100.0] + "pixels more than 16 off", off.x < 1.5 and off.y < 0.005)
	var start: Vector2 = _difference(first, last)
	_check("...and the first is far from it: %.1f%% of pixels more than 16 off" % (start.y * 100.0),
		start.y > 0.05)


# -- over MCP ---------------------------------------------------------------------


func _over_mcp() -> void:
	print("── over MCP: render_model {\"kind\": \"build\"} ──")
	var built: Dictionary = _poses()
	var depth: int = _builder.history_depth()
	var calls: int = 0
	var began: int = Time.get_ticks_msec()
	var started: Dictionary = await _rpc("tools/call", {"name": "render_model", "arguments": {"kind": "build"}})
	calls += 1
	var answer: String = _text(await _finished(started))
	_print(answer)
	var took: float = float(Time.get_ticks_msec() - began) / 1000.0
	var webp: String = ""
	var found: RegExMatch = RegEx.create_from_string("wrote (\\S+\\.webp)").search(answer)
	if found != null:
		webp = found.get_string(1)
	_check("in %d call and its job, %.0f s: %s" % [calls, took, _text(started).left(40)],
		calls == 1 and _text(started).begins_with("Started job")
		and answer.contains("%d parts in " % _parts()) and answer.contains("%d s" % SECONDS))
	if not webp.is_empty():
		_files(webp, SECONDS * 24, "render_model's")
	_check("...and the model stands as built (%d parts off), its undo as it was" % _off(built),
		_off(built) == 0 and _builder.history_depth() == depth)
	var refused: String = _text(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "build", "seconds": 90}}))
	_check("a length past 60 s is refused, saying the range: %s" % refused, refused == "seconds is 10 to 60.")


# -- the app ------------------------------------------------------------------------


func _shell() -> Shell:
	return _main.get("_shell")


func _named(key: String) -> Control:
	return _dialog.controls_by_name().get(key)


func _parts() -> int:
	return _world.brick_count() - (_main.get("_store") as ModelStore).scenery.size()


func _rendered(seconds: int) -> void:
	var until: int = Time.get_ticks_msec() + seconds * 1000
	while _dialog.is_rendering() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(5)


func _path_of(last: Dictionary, extension: String) -> String:
	var output: RenderOutput = last.get("output")
	if output == null:
		return ""
	for path: String in output.paths:
		if path.ends_with(extension):
			return path
	return ""


static func _mp4_length(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var said: Array = []
	OS.execute("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], said)
	return str(said[0]).strip_edges() if not said.is_empty() else ""


## The mean difference of two pictures in grey levels, and the share of
## pixels more than 16 levels off in any channel.
static func _difference(a: Image, b: Image) -> Vector2:
	if a == null or b == null or a.get_size() != b.get_size():
		return Vector2(255.0, 1.0)
	var total: float = 0.0
	var off: int = 0
	var count: int = 0
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			var most: float = maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) * 255.0 / 3.0
			if most > 16.0:
				off += 1
			count += 1
	return Vector2(total / float(count), float(off) / float(count))


func _poses() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = [brick.transform, brick.hidden]
	return out


## How many parts are not where [param built] has them, or not shown as they were.
func _off(built: Dictionary) -> int:
	var count: int = 0
	for key: Variant in built:
		var brick: BrickWorld.Brick = _world.get_brick(int(key))
		if brick == null or not brick.transform.is_equal_approx(built[key][0]) or brick.hidden != built[key][1]:
			count += 1
	return count


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, size.x, size.y])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _click(control: Control) -> void:
	await _frames(2)
	if control == null or not control.is_visible_in_tree():
		_check("the control to press shows (%s)" % (control.name if control != null else "none"), false)
		return
	var at: Vector2 = control.get_global_rect().get_center()
	await _move(at)
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
	await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


## [param result], or when it is a job, the job's answer once it ends.
func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 600:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


func _print(said: String) -> void:
	print("    " + said.replace("\n", "\n    "))


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
