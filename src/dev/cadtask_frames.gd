## The frames a builder feels, timed in the real window: turning the view,
## a part in hand moving over the model, selecting, undo, a step of the
## timeline, and opening the model.
##
##   godot --path . --resolution 1400x900 --script src/dev/cadtask_frames.gd -- --frames-out=FILE.json PATH ...
##
## Windowed (under xvfb-run on a machine with no screen): what is timed is
## the whole frame, the app's work and the drawing, between one frame and
## the next with vsync off. Each PATH is opened as File, Open opens a file
## (ModelStore.open_text, then the bar's opened signal: the baseplate laid
## and the view framed), then, each as an input event a person would make:
##
##   orbit      right-drag across the view, a step a frame, 60 frames
##   place      a 2 x 4 brick in hand (as a tile clicked in the bin), the
##              pointer swept across the model, 60 frames
##   select_100 100 parts selected, as shift-click adds each; the frames
##              after, the outline drawn
##   select_all Ctrl-A
##   delete     Delete of those 100, and undo, Ctrl-Z, putting them back
##   timeline   B, then Right once (does it step?), then its Next five times: a step
##              each (the timeline opens on them when the file has them)
##   open       from the text to the first frame drawn after it
##
## Not --out: the scene this loads reads that as "export the model there and
## quit" (Main's --model/--out), which it did, and timed nothing.
##
## --stress: View, Stress turned on once each model is open, and left on
## through every act: its own frames (stress_on: the model drawn faded, and
## then tinted when the weighing it asks for comes in, how long that took,
## and how many parts read red and amber) and every act's frames with it on.
##
## Nothing is judged here: tools/bench/cadtask.py reads the numbers. They
## are this machine's frames, on whatever draws for xvfb (software here).
## Not in the suite.
extends SceneTree

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _view: Rect2
var _last_us: int = 0
var _stress: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var out_path: String = ""
	var paths: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--frames-out="):
			out_path = argument.trim_prefix("--frames-out=")
		elif argument == "--stress":
			_stress = true
		else:
			paths.append(argument)
	if out_path.is_empty() or paths.is_empty():
		print("usage: cadtask_frames.gd -- --frames-out=FILE.json PATH ...")
		quit(2)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	var rows: Array = []
	for path: String in paths:
		print("frames: %s" % path.get_file())
		rows.append(await _one(path))
		var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(),
			"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"models": rows}, " "))
		file.close()
	print("frames: %d models written to %s" % [rows.size(), out_path])
	quit(0)


func _one(path: String) -> Dictionary:
	_main.call("clear_model")
	await _frames(20)
	var row: Dictionary = {"file": path.get_file()}
	var text: String = FileAccess.get_file_as_string(path)
	# open: the text read, placed, the view framed, and the frame drawn.
	await _frames(2)
	var began: int = Time.get_ticks_usec()
	var result: Dictionary = _store.open_text(text, path.get_file().get_basename())
	(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
	var opened_us: int = Time.get_ticks_usec() - began
	await process_frame
	await process_frame
	row["open"] = {"placed": int(result["placed"]), "call_ms": opened_us / 1000.0,
		"to_drawn_ms": (Time.get_ticks_usec() - began) / 1000.0}
	await _frames(60)
	_view = ((_main.call("model_cover") as Dictionary)["view"] as Rect2)
	row["idle"] = await _timed(30, func(_n: int) -> void: pass)
	if _stress:
		row["stress_on"] = await _stress_on()

	# orbit: right-drag across the middle of the view.
	var middle: Vector2 = _view.get_center()
	_press(MOUSE_BUTTON_RIGHT, middle, true)
	row["orbit"] = await _timed(60, func(n: int) -> void:
		_move(middle + Vector2(4.0 * n, 0.0), Vector2(4.0, 0.0), MOUSE_BUTTON_MASK_RIGHT))
	_press(MOUSE_BUTTON_RIGHT, middle + Vector2(240.0, 0.0), false)
	await _frames(10)

	# place: a brick in hand, the pointer swept across the model.
	_main.call("_on_part_chosen", "3001")
	await _frames(10)
	var from: Vector2 = middle - Vector2(_view.size.x * 0.25, 0.0)
	var across: float = _view.size.x * 0.5 / 60.0
	row["place"] = await _timed(60, func(n: int) -> void:
		_move(from + Vector2(across * n, 6.0 * sin(n * 0.3)), Vector2(across, 0.0), 0))
	row["place"]["ghost"] = _builder.ghost_place() != null
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _frames(10)

	# select_100: a hundred parts, a shift-click on each part not yet
	# selected, then the frames that draw it. A click takes a part's whole
	# sub-assembly (Builder.takes), so a click on a part already taken would
	# put the lot back: the first run of this clicked the first hundred
	# blindly and ended with nothing selected.
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	_builder.clear_selection()
	await _frames(5)
	var picked_at: int = Time.get_ticks_usec()
	for brick_id: int in ids:
		if _builder.selection.size() >= 100:
			break
		if not _builder.selection.has(brick_id):
			_builder.select_brick(brick_id, true)
	var select_call: float = (Time.get_ticks_usec() - picked_at) / 1000.0
	row["select_100"] = await _timed(20, func(_n: int) -> void: pass)
	row["select_100"]["call_ms"] = select_call
	row["select_100"]["selected"] = _builder.selection.size()

	# delete and undo, by their keys.
	var before: int = _world.brick_count()
	_move(middle, Vector2.ZERO, 0)
	row["delete"] = await _timed(20, func(n: int) -> void:
		if n == 0:
			_key_now(KEY_DELETE))
	row["delete"]["removed"] = before - _world.brick_count()
	row["undo"] = await _timed(20, func(n: int) -> void:
		if n == 0:
			_key_now(KEY_Z, true))
	row["undo"]["back"] = _world.brick_count() == before
	await _frames(10)

	# select_all, by its key.
	row["select_all"] = await _timed(20, func(n: int) -> void:
		if n == 0:
			_key_now(KEY_A, true))
	row["select_all"]["selected"] = _builder.selection.size()
	await _key(KEY_ESCAPE)
	_builder.clear_selection()
	await _frames(10)

	# timeline: B, then a step at a time.
	var steps: StepsBar = _main.get("_steps")
	var open_began: int = Time.get_ticks_usec()
	_key_now(KEY_B)
	for _n: int in 600:
		await process_frame
		if steps.is_playing_back() and not Working.is_busy():
			break
	row["timeline_open_ms"] = (Time.get_ticks_usec() - open_began) / 1000.0
	row["timeline_on"] = steps.is_playing_back()
	await _frames(20)
	# Right, which Main steps the timeline with: does it, here?
	var at_key: Vector2i = steps.timeline_at()
	await _key(KEY_RIGHT)
	await _frames(10)
	row["right_key_steps"] = steps.timeline_at().x != at_key.x
	# Then its Next, as a click on it does.
	var at_before: Vector2i = steps.timeline_at()
	var next: Button = steps.controls_by_name().get("steps_next")
	var stepping: Array = []
	for _k: int in 5:
		var one: Dictionary = await _timed(8, func(n: int) -> void:
			if n == 0 and next != null:
				next.pressed.emit())
		stepping.append(one)
	row["step"] = _merged(stepping)
	row["step"]["moved"] = [at_before.x, steps.timeline_at().x, steps.timeline_at().y]
	await _key(KEY_B)
	await _key(KEY_ESCAPE)
	await _frames(10)
	print("  %s: %s" % [path.get_file(), JSON.stringify(_said(row))])
	return row


## View, Stress turned on: the frames that draw the model faded, and then
## the wait for the weighing that tints it, and the frames after.
func _stress_on() -> Dictionary:
	var shell: Shell = _main.get("_shell")
	var asked_at: int = Time.get_ticks_usec()
	var out: Dictionary = await _timed(20, func(n: int) -> void:
		if n == 0:
			shell.run("stress"))
	for _n: int in 3000:
		if shell.stress.report != null:
			break
		await process_frame
	out["tinted_after_ms"] = (Time.get_ticks_usec() - asked_at) / 1000.0
	var red: int = 0
	for id: int in _world.stressed_ids():
		if _world.stressed_ids()[id] == StressView.RED:
			red += 1
	out["red"] = red
	out["amber"] = _world.stressed_ids().size() - red
	out["after"] = await _timed(20, func(_n: int) -> void: pass)
	return out


## [frames] frames, calling [act] with the frame's number before each, and
## the time of each frame in ms.
func _timed(frames: int, act: Callable) -> Dictionary:
	var spent: Array = []
	# The app's own work, apart from the drawing: the engine's process time,
	# read a frame later, when the frame it measured has finished.
	var own: Array = []
	await process_frame
	_last_us = Time.get_ticks_usec()
	for n: int in frames + 1:
		if n < frames:
			act.call(n)
		await process_frame
		var now: int = Time.get_ticks_usec()
		if n > 0:
			own.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		if n < frames:
			spent.append((now - _last_us) / 1000.0)
		_last_us = now
	var out: Dictionary = _stats(spent)
	var own_sorted: Array = own.duplicate()
	own_sorted.sort()
	out["own_median_ms"] = own_sorted[own_sorted.size() / 2] if not own_sorted.is_empty() else 0.0
	out["own_max_ms"] = own_sorted.back() if not own_sorted.is_empty() else 0.0
	return out


static func _stats(spent: Array) -> Dictionary:
	var sorted: Array = spent.duplicate()
	sorted.sort()
	var count: int = sorted.size()
	return {"frames": count, "median_ms": sorted[count / 2] if count > 0 else 0.0,
		"p95_ms": sorted[mini(count - 1, int(ceil(count * 0.95)) - 1)] if count > 0 else 0.0,
		"max_ms": sorted[count - 1] if count > 0 else 0.0,
		"first_ms": spent[0] if count > 0 else 0.0, "all_ms": spent}


static func _merged(parts: Array) -> Dictionary:
	var spent: Array = []
	var firsts: Array = []
	for one: Dictionary in parts:
		spent.append_array(one["all_ms"])
		firsts.append(one["max_ms"])
	var out: Dictionary = _stats(spent)
	out["each_max_ms"] = firsts
	var own: Array = []
	for one: Dictionary in parts:
		own.append(float(one.get("own_max_ms", 0.0)))
	out["own_max_ms"] = own.max() if not own.is_empty() else 0.0
	return out


static func _said(row: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in row:
		if row[key] is Dictionary and (row[key] as Dictionary).has("max_ms"):
			out[key] = [snappedf(row[key]["median_ms"], 0.1), snappedf(row[key]["max_ms"], 0.1)]
	out["open_ms"] = row["open"]["to_drawn_ms"]
	out["timeline_open_ms"] = row.get("timeline_open_ms", -1)
	return out


func _frames(how_many: int) -> void:
	for _n: int in how_many:
		await process_frame


func _press(which: int, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	if which == MOUSE_BUTTON_RIGHT and down:
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _move(at: Vector2, by: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = _as_event(by)
	event.button_mask = mask
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


func _key(code: Key) -> void:
	_key_now(code)
	await _frames(4)


## Viewport coordinates as the window coordinates an event carries: the
## interface is scaled (feel_probe's _as_event).
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)
