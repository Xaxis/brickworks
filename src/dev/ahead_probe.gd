## The builder's frames after a change, timed: a part turned on its joint
## (move_part, as a session moves it), an undo (Ctrl+Z), and a part placed
## by a click, each followed for a few seconds while the app reads the
## model's joints again (GrabDrag._ready_ahead) and weighs it (Main._weigh).
##
##   godot --headless --path . --script src/dev/ahead_probe.gd
##
## The frames are the main thread's: the clock between one frame and the
## next, headless, so nothing is drawn. Each act prints its longest frames,
## when they came after it, and how the joints were read. Then a press
## while the joints are read on a worker must take hold once they are, with
## the worker's reading, and one while a session's move is worked out must
## say why it does nothing. With --most-ms=N each act's longest frame is
## checked against N ms; PATHs after the -- replace the default models (the
## Ducati a session designed, in a git-ignored bench folder and skipped
## where it is not; 8808-1; 42004-1).
extends SceneTree

const MODELS: Array = [
	"/mnt/Projects/brickworks/bench/results/realset-2026-10-20-technic/42107-1/design.ldr",
	"res://vendor/omr/files/8808-1.mpd",
	"res://vendor/omr/files/42004-1.mpd",
]
## How long each act is followed, ms: the reading starts a quarter second
## after a change, the weighing within a second of it.
const FOLLOW_MS := 4000

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _grab: GrabDrag
var _store: ModelStore
var _tools: AppTools
var _most_ms: float = 0.0
var _last_screen := Vector2.ZERO


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	var paths: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--most-ms="):
			_most_ms = float(argument.trim_prefix("--most-ms="))
		elif argument.ends_with(".ldr") or argument.ends_with(".mpd"):
			paths.append(argument)
	if paths.is_empty():
		paths = MODELS
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_grab = _main.get("_grab_drag")
	_store = _main.get("_store")
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	for path: String in paths:
		await _one(path)
	print("\n%s" % ("ahead_probe: %d FAIL" % _failures if _failures > 0 else "ahead_probe: passed"))
	quit(1 if _failures > 0 else 0)


func _one(path: String) -> void:
	var file: String = path if not path.begins_with("res://") else ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(file):
		print("\n%s: not here, skipped" % path)
		return
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", file)
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
	_builder.forget_history()
	_builder.clear_selection()
	print("\n%s: %d parts" % [path.get_file(), _world.brick_count()])
	await _still()

	# move: the smallest section on a joint turned, as move_part turns it.
	var bodies: Bodies = _grab.read_bodies()
	var tried: Array = []
	for link: Bodies.Link in bodies.links if bodies != null else []:
		var child: int = link.b if bodies.parent_link.get(link.b) == link else link.a
		if bodies.parent_link.get(child) != link or link.kind == "stud" or link.axis == Vector3.ZERO:
			continue
		tried.append([bodies.parts_of(bodies.beyond(child)).size(), child])
	tried.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var moved: bool = false
	var moved_key: int = -1
	for entry: Array in tried.slice(0, 12):
		var key: int = int((bodies.members[int(entry[1])] as PackedInt64Array)[0])
		for degrees: float in [20.0, -20.0]:
			var depth: int = _builder.history_depth()
			var timed: Dictionary = await _timed(func() -> Variant:
				return await _tools.run("move_part", {"part": "#%d" % key, "degrees": degrees}))
			if _builder.history_depth() > depth:
				_report("move #%d %s°" % [key, degrees], timed)
				moved = true
				moved_key = key
				break
			await _still()
		if moved:
			break
	_check("%s: a part turned on its joint" % path.get_file(), moved)
	await _still()

	# undo, by its key.
	var undone: Dictionary = await _timed(func() -> Variant:
		_key_now(KEY_Z, true)
		return null)
	_report("undo", undone)
	await _still()

	# place: a 2 x 4 brick in hand, the pointer swept over the model until
	# it may go down, and a click.
	_main.call("_on_part_chosen", "3001")
	await _frames(10)
	var view: Rect2 = (_main.call("model_cover") as Dictionary)["view"] as Rect2
	var found: bool = false
	for row: int in 9:
		for column: int in 13:
			var at: Vector2 = view.position + view.size * Vector2((column + 1) / 14.0, (row + 1) / 10.0)
			_move(at, 0)
			await _frames(2)
			if _builder.can_place():
				found = true
				break
		if found:
			break
	var count: int = _world.brick_count()
	if found:
		var placed: Dictionary = await _timed(func() -> Variant:
			_button(_last_screen, true)
			await process_frame
			_button(_last_screen, false)
			return null)
		_report("place", placed)
	_check("%s: a part placed by a click" % path.get_file(), _world.brick_count() == count + 1)
	_key_now(KEY_ESCAPE)
	await _frames(4)
	if moved:
		await _presses(moved_key, path.get_file())


## A press on [param key] while the joints are read on a worker takes hold
## once the reading is done, and takes the worker's reading rather than
## reading again; one while a session's move is worked out says why it
## does nothing.
func _presses(key: int, file: String) -> void:
	await _still()
	var camera: CadCamera = _main.get("_camera")
	_key_now(KEY_Z, true)
	var waited: int = Time.get_ticks_msec()
	while not _grab.is_reading() and Time.get_ticks_msec() - waited < 5000:
		await process_frame
	var reading: bool = _grab.is_reading()
	var screen: Vector2 = camera.unproject_position(_world.get_brick(key).transform.origin)
	var pressed_at: int = Time.get_ticks_usec()
	var took: bool = _grab.press(key, screen)
	var press_ms: float = (Time.get_ticks_usec() - pressed_at) / 1000.0
	var held: bool = took and _grab.grab != null and _grab.grab.state == "moves"
	_check(("%s: a press while the joints are read on a worker (%s) takes hold once they are, "
		+ "in %.0f ms, with the worker's reading (%d ms %s)") % [file, reading, press_ms, _grab.ready_ms,
		"on a worker" if _grab.ready_off_thread else "here"],
		reading and held and _grab.ready_off_thread and _grab.is_ready())
	_grab.cancel()
	await _still()
	var depth: int = _builder.history_depth()
	var done: Array = [false]
	var moving: Callable = func() -> void:
		await _tools.run("move_part", {"part": "#%d" % key, "degrees": 15.0})
		done[0] = true
	moving.call()
	waited = Time.get_ticks_msec()
	while not bool(_grab.get("_session_moving")) and not done[0] and Time.get_ticks_msec() - waited < 5000:
		await process_frame
	var during: bool = bool(_grab.get("_session_moving"))
	var status: Label = (_main.get("_bar") as ModelBar).get("_status")
	status.text = ""
	_grab.press(key, screen)
	var said: String = status.text
	_check("%s: a press while a session's move is worked out (%s) says so: \"%s\"" % [file, during, said],
		during and said == GrabDrag.READING_WORDS and _grab.grab == null)
	waited = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - waited < 60000:
		await process_frame
	if _builder.history_depth() > depth:
		_builder.undo()


## Until the joints are read for the model as it stands and nothing is
## being worked out: then a second more, as a person pauses.
func _still() -> void:
	var waited: int = Time.get_ticks_msec()
	while (not _grab.is_ready() or _grab.is_settling() or bool(_main.get("_weighing"))) \
			and Time.get_ticks_msec() - waited < 60000:
		await process_frame
	var until: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await process_frame


## [param act] done, then each frame timed for [constant FOLLOW_MS]: the
## frames, ms, each with when it began after the act, and what was read.
func _timed(act: Callable) -> Dictionary:
	await process_frame
	var began: int = Time.get_ticks_usec()
	var frames: Array = []
	var last: int = began
	var done: Array = [false]
	var doing: Callable = func() -> void:
		await act.call()
		done[0] = true
	doing.call()
	var acted_at: int = -1
	while true:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append([(last - began) / 1000.0, (now - last) / 1000.0])
		last = now
		if done[0] and acted_at < 0:
			acted_at = now
		if acted_at >= 0 and now - acted_at > FOLLOW_MS * 1000:
			break
		if now - began > 120 * 1000000:
			break
	return {"frames": frames, "act_ms": (acted_at - began) / 1000.0, "ready_ms": _grab.ready_ms,
		"off_thread": _grab.ready_off_thread, "ready": _grab.is_ready(), "took": _grab.ready_took}


func _report(what: String, timed: Dictionary) -> void:
	var frames: Array = timed["frames"]
	var sorted: Array = frames.duplicate()
	sorted.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	var worst: float = sorted[0][1] if not sorted.is_empty() else 0.0
	var over: int = frames.filter(func(f: Array) -> bool: return f[1] > 50.0).size()
	var longest := PackedStringArray()
	for frame: Array in sorted.slice(0, 4):
		longest.append("%.0f ms at +%.0f" % [frame[1], frame[0]])
	print("  %s: longest frame %.0f ms; %d of %d frames over 50 ms; the act %.0f ms; read %d ms %s %s"
		% [what, worst, over, frames.size(), timed["act_ms"], timed["ready_ms"],
			"on a worker" if timed["off_thread"] else "here", str(timed["took"])])
	print("    longest: %s" % ", ".join(longest))
	if _most_ms > 0.0:
		_check("%s: the longest frame after it is under %.0f ms (%.0f)" % [what, _most_ms, worst],
			worst < _most_ms)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _move(at: Vector2, mask: int) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(at) - _as_event(_last_screen)
	move.button_mask = mask
	Input.parse_input_event(move)
	_last_screen = at


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)


func _key_now(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.meta_pressed = command and OS.get_name() == "macOS"
		Input.parse_input_event(event)
