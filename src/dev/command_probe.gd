## Every command, timed: how long each holds the window, on Orthanc and on
## the example car, and whether the status bar said so before it did.
##
##   godot --path . --resolution 1400x900 --script src/dev/command_probe.gd -- \
##       [--subjects=car,orthanc] [--only=save,new] [--table=shots/commands.json] [--judge]
##
## The owner (2026-10-13): "a standard 'progress indicator or working
## indicator' for actions taken in the app … when I clicked 'Save and then
## new' it seemingly froze the app … for probably all actions
## comprehensively." This runs every command in the shell's table
## (Shell._commands) as its menu item does (Shell.run), with the selection
## everything where a command needs one, and records for each:
##
##   own      the longest of the app's own work in one frame while it ran:
##            from the frame's start to the end of its processing, drawing
##            left out (OwnFrames), which is what holds a browser's page;
##   frame    the longest from one frame to the next, drawing included;
##   said     whether the status bar's bar (Working) was up and drawn
##            before that longest frame began;
##   total    from the press until nothing is being worked on.
##
## Skipped: what opens a file dialog, reaches the network or leaves the app.
## A command that changes the model is undone after (Builder.undo), or the
## model opened again when it was replaced. What the exports hand over goes
## into user://command_probe_downloads (Download.folder), never Downloads.
##
## With --judge it fails a command whose own work in one frame is over
## BUDGET_MS and was not said first, and checks that the bar does not come
## up for Mirror, Paint and Duplicate of three parts of a big model. Built so the same file runs on a
## checkout from before Working.attend: it asks nothing of it.
extends SceneTree

const BUDGET_MS := 250.0
## How long a command may go on before it is stopped (Cancel), or left.
const LONGEST_S := 90.0

const SKIP: Dictionary = {
	"import_ldraw": "file dialog", "import_io": "file dialog", "import_lxf": "file dialog",
	"import_mesh": "file dialog", "mosaic": "file dialog", "brickify": "file dialog",
	"account": "network", "share": "network", "connector": "network",
	"ask_claude": "network", "website": "opens a browser", "docs": "opens a browser", "quit": "leaves the app",
	"full_screen": "the window, not the app", "new_window": "starts another window",
}

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _bar: ModelBar
var _frames_seen: Array = []  ## [began usec, own ms, gap ms, bar up at start, ended usec]
var _began_us: int = 0
var _last_us: int = 0
var _bar_up_at_start: bool = false
var _rows: Array = []


class _End extends Node:
	var probe: Object

	func _ready() -> void:
		process_priority = 1000000

	func _process(_delta: float) -> void:
		probe.call("_frame_ended_later")


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	_began_us = now
	_bar_up_at_start = Working.is_busy() and Working.shown_in != null \
		and Working.shown_in.visible
	return false


func _frame_ended_later() -> void:
	_frame_ended.call_deferred()


func _frame_ended() -> void:
	var now: int = Time.get_ticks_usec()
	var gap: float = (_began_us - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_frames_seen.append([_began_us, (now - _began_us) / 1000.0, gap, _bar_up_at_start, now])
	_last_us = _began_us
	if _frames_seen.size() > 20000:
		_frames_seen = _frames_seen.slice(-10000)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _argument(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.substr(name.length() + 3)
	return fallback


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	BookletMaker.open_when_written = false
	# Every file a command hands over goes here, never into Downloads.
	var downloads: String = OS.get_user_data_dir().path_join("command_probe_downloads")
	DirAccess.make_dir_recursive_absolute(downloads)
	Download.folder = downloads
	var end := _End.new()
	end.probe = self
	root.add_child(end)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	(_main.get("_playback") as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	# Save and Save as write into the saved models; what they write goes again
	# at the end, so the next probe in this folder finds what it left.
	var saved_before: PackedStringArray = DirAccess.get_files_at(ModelStore.SAVE_DIR)
	var only: PackedStringArray = _argument("only", "").split(",", false)
	var judge: bool = OS.get_cmdline_user_args().has("--judge")
	print("adapter: %s" % RenderingServer.get_video_adapter_name())
	for model: String in _argument("subjects", "car,orthanc").split(",", false):
		await _open(model)
		var names: Array = (_shell.get("_commands") as Dictionary).keys()
		for name: String in names:
			if not only.is_empty() and not name in only:
				continue
			await _time(model, name)
	_report(judge)
	if judge:
		await _no_flash()
	for file_name: String in DirAccess.get_files_at(ModelStore.SAVE_DIR):
		if not file_name in saved_before:
			DirAccess.remove_absolute(ModelStore.SAVE_DIR.path_join(file_name))
	var out: String = _argument("table", "shots/commands.json")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"rows": _rows}, " "))
		file.close()
	print("wrote %s" % out)
	# A big model left standing at the quit can take the engine down with it
	# (a double free tearing down Orthanc's drawing, before this probe too).
	_world.clear()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	quit(1 if _failures else 0)


var _standing: int = 0
var _model: String = ""


func _open(model: String) -> void:
	_model = model
	var path: String = "res://models/%s.ldr" % model
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _quiet(120.0)
	_standing = _world.brick_count()
	print("%s: %d parts open" % [model, _standing])


## Until nothing is being worked on and a few frames have gone by with no
## work of their own to speak of, or [param seconds].
func _quiet(seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var calm: int = 0
	while Time.get_ticks_msec() < until:
		await process_frame
		var last: Array = _frames_seen.back() if not _frames_seen.is_empty() else [0, 0.0]
		if Working.is_busy() or float(last[1]) > 40.0:
			calm = 0
		else:
			calm += 1
		if calm >= 8:
			return true
	return false


func _time(model: String, name: String) -> void:
	var row: Dictionary = {"model": model, "name": name}
	if SKIP.has(name):
		row["skipped"] = SKIP[name]
		_rows.append(row)
		return
	if not _shell.can(name):
		(_main.get("_verbs") as EditVerbs).select_by("all")
		await _frames(3)
	if not _shell.can(name):
		row["skipped"] = "not available here"
		_rows.append(row)
		await _tidy()
		return
	var depth: int = _builder.history_depth()
	var from: int = Time.get_ticks_usec()
	var said: Dictionary = {}
	var call_from: int = Time.get_ticks_usec()
	_shell.run(name)
	var call_ms: float = (Time.get_ticks_usec() - call_from) / 1000.0
	var until: int = Time.get_ticks_msec() + int(LONGEST_S * 1000.0)
	var cancelled: bool = false
	var calm: int = 0
	while true:
		await process_frame
		if Working.is_busy():
			said[Working.current().words] = true
			calm = 0
		else:
			var last: Array = _frames_seen.back() if not _frames_seen.is_empty() else [0, 0.0]
			calm = calm + 1 if float(last[1]) <= 40.0 else 0
		if calm >= 8:
			break
		if Time.get_ticks_msec() > until:
			var job: Working.Job = Working.current()
			if job != null and job.can_cancel:
				job.cancel()
				cancelled = true
				await _quiet(30.0)
			break
	var total: float = (Time.get_ticks_usec() - from) / 1000.0
	var own: float = call_ms
	var gap: float = 0.0
	var said_first: bool = true
	var own_at: int = -1
	# The frames that ended after the press: the one it was pressed in too.
	for n: int in _frames_seen.size():
		var frame: Array = _frames_seen[n]
		if int(frame[4]) < from:
			continue
		gap = maxf(gap, float(frame[2]))
		if float(frame[1]) > own:
			own = float(frame[1])
			own_at = n
	# The command ran inside the probe's frame, before it was recorded.
	if own_at >= 0:
		said_first = bool(_frames_seen[own_at][3])
	else:
		said_first = false
	row["own_ms"] = roundi(own)
	row["frame_ms"] = roundi(gap)
	row["total_ms"] = roundi(total)
	row["said_first"] = said_first
	row["said"] = said.keys()
	row["cancelled"] = cancelled
	_rows.append(row)
	print("  %-8s %-22s own %6d ms  frame %6d ms  total %7d ms  %s%s%s" % [model, name,
		roundi(own), roundi(gap), roundi(total), "said first" if said_first else "          ",
		"  [" + ", ".join(said.keys()) + "]" if not said.is_empty() else "",
		"  (stopped)" if cancelled else ""])
	await _tidy(depth)


## Back to the model as it was opened, nothing open over it.
func _tidy(depth: int = -1) -> void:
	for _n: int in 4:
		_escape()
		await _frames(2)
	_close_windows(root)
	var steps: StepsBar = _main.get("_steps")
	if steps != null and steps.is_playing_back():
		steps.stop()
	var inventory: Variant = _main.get("_inventory")
	if inventory != null and inventory.is_showing():
		inventory.hide_list()
	if _shell.tour != null and _shell.tour.is_running():
		_shell.tour.stop()
	if _shell.see_inside.cutting:
		_shell.see_inside.set_cut(false)
	if _shell.see_inside.seeing_through:
		_shell.see_inside.set_xray(false)
	if _builder.is_carrying():
		(_main.get("_verbs") as EditVerbs).put_away()
	(_main.get("_verbs") as EditVerbs).set_mode("select")
	(_main.get("_verbs") as EditVerbs).show_all()
	if depth >= 0:
		var gone_back: int = 0
		while _builder.history_depth() > depth and gone_back < 20:
			_builder.undo()
			gone_back += 1
		if _builder.history_depth() < depth or _world.brick_count() != _standing:
			# Replaced (New, Clear, Open): opened again.
			await _open(_model)
	(_main.get("_verbs") as EditVerbs).select_by("none")
	await _quiet(60.0)


func _close_windows(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Window and child != root and (child as Window).visible:
			(child as Window).hide()
		_close_windows(child)


func _escape() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		Input.parse_input_event(key)


## A command known to be slow on all of a big model is not said first on
## three parts of it: the bar never comes up for what takes no time.
func _no_flash() -> void:
	if _standing < 1000:
		return
	var verbs: EditVerbs = _main.get("_verbs")
	for name: String in ["mirror", "paint", "duplicate"]:
		verbs.select_by("all")
		var three: Array = _builder.selection.keys().slice(0, 3)
		_builder.selection.clear()
		for brick_id: int in three:
			_builder.selection[brick_id] = true
		_builder.selection_changed.emit(3)
		await _frames(3)
		var depth: int = _builder.history_depth()
		var up: bool = false
		_shell.run(name)
		for _n: int in 10:
			up = up or Working.is_busy()
			await process_frame
		print("  %s %s of 3 parts of %s: the bar %s" % ["ok  " if not up else "FAIL", name,
			_model, "came up" if up else "stayed down"])
		if up:
			_failures += 1
		await _tidy(depth)


func _report(judge: bool) -> void:
	print("")
	print("| model | command | own work, longest frame | frame, drawing included | total | said first | what it said |")
	print("|---|---|--:|--:|--:|---|---|")
	for row: Dictionary in _rows:
		if row.has("skipped"):
			continue
		print("| %s | %s | %d ms | %d ms | %d ms | %s | %s |" % [row["model"], row["name"],
			row["own_ms"], row["frame_ms"], row["total_ms"], "yes" if row["said_first"] else "",
			"; ".join(row["said"])])
	var over: Array = _rows.filter(func(row: Dictionary) -> bool:
		return not row.has("skipped") and int(row["own_ms"]) > BUDGET_MS)
	var unsaid: Array = over.filter(func(row: Dictionary) -> bool:
		return not bool(row["said_first"]))
	var skipped: Array = _rows.filter(func(row: Dictionary) -> bool: return row.has("skipped"))
	print("")
	print("skipped: %s" % ", ".join(skipped.map(func(row: Dictionary) -> String:
		return "%s (%s)" % [row["name"], row["skipped"]]).slice(0, 40)))
	print("%d commands timed; %d held a frame of their own over %d ms, %d of them without saying so first: %s"
		% [_rows.size() - skipped.size(), over.size(), BUDGET_MS, unsaid.size(),
			", ".join(unsaid.map(func(row: Dictionary) -> String:
				return "%s on %s (%d ms)" % [row["name"], row["model"], row["own_ms"]]))])
	if judge:
		for row: Dictionary in unsaid:
			print("  FAIL %s on %s holds %d ms without saying so first" % [row["name"],
				row["model"], row["own_ms"]])
			_failures += 1
