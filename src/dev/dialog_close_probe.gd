## Does the window's close button close the app with a dialog of its own up?
##
##   godot --path . --resolution 1280x720 --script src/dev/dialog_close_probe.gd
##   tools/probe.sh dialog_close_probe
##   ... -- --shots=DIR    each dialog's picture as the close is sent, kept there
##   ... -- --only=open    one way (a list, by commas)
##
## The close is sent as a window manager sends it when the title bar's X is
## clicked, Alt+F4 pressed or the session ends: WM_DELETE_WINDOW to the main
## window (tools/x11_close.py), which goes through the engine as a person's
## does. quit_probe's close only emits the window's signal, which never
## meets what held it.
##
## The engine drops a close request while the window has an exclusive child,
## and every AcceptDialog, ConfirmationDialog and FileDialog of the main
## window was one: with Godot's own file dialog up (a Linux desktop with no
## file-dialog portal, as here; File, Open's always), or any question, the X
## did nothing until it was answered (desktop018, 0.18.0 and 0.19.0).
## ModalDialogs holds them since.
##
## Each way is the app run once, at 1280x720, with Godot's own dialogs:
##   none      nothing up: the close works here at all;
##   open      File, Import, LDraw model…: the file chooser;
##   save-as   File, Save as…, a part taken off first (work not saved);
##   confirm   File, New over a part taken off: "Start a new model?";
##   accept    Help, About Brickworks.
## Pass: the app hears the close and is gone within GONE_MS of it, exit 0,
## no abort said. The app asks nothing as it closes, dialog or none: the
## model as it stands is kept as the working model and comes back at the
## next start (Main._exit_tree), so where a part was taken off, the working
## model has it off. And open shows the dialog still holds the window: a
## click on File beside it opens no menu and leaves the keys with it, and
## Ctrl+N beside it starts nothing.
## On pre261 (2026-11-07) every way with a dialog up was still there 5 s
## after the close, exit 3, and a click beside the dialog left the keys
## with nothing.
extends SceneTree

const WAYS := ["none", "open", "save-as", "confirm", "accept"]
## How soon after the close the app must be gone, process and all.
const GONE_MS := 2000
## How long a run waits for its close before it says it was ignored.
const WAIT_MS := 5000
const SIZE := "1280x720"
## What the C library and the engine say as a run dies on its way out.
const ABORTS := ["corrupted size", "malloc", "free(): ", "double free", "Program crashed",
	"terminate called", "handle_crash"]
const CLOSER := "res://tools/x11_close.py"

var _failures: int = 0
var _shots: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
	if OS.get_cmdline_user_args().has("--child"):
		_child()
	else:
		_parent()


func _parent() -> void:
	if DisplayServer.get_name() != "X11":
		print("dialog_close probe: SKIPPED: the close is sent through X11 (run it as its header says)")
		quit(0)
		return
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots)
	var ways: Array = WAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			ways = argument.trim_prefix("--only=").split(",")
	# The atoms a window manager makes first: without them on a bare Xvfb
	# the app never says it takes a close request. This window, open all
	# the while, keeps the server from resetting and losing them.
	var made: Array = []
	OS.execute("python3", ["-I", ProjectSettings.globalize_path(CLOSER), "--atoms"], made, true)
	print("  %s" % "".join(made).strip_edges())
	for way: String in ways:
		var arguments := PackedStringArray(["--resolution", SIZE,
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://src/dev/dialog_close_probe.gd", "--", "--child", "--way=" + way])
		if not _shots.is_empty():
			arguments.append("--shots=" + _shots)
		var said: Array = []
		var code: int = OS.execute(OS.get_executable_path(), arguments, said, true)
		var ended: int = int(Time.get_unix_time_from_system() * 1000.0)
		_judge(way, code, "".join(said), ended)
	print("dialog_close: %s" % ("the close button closes the app with each dialog up"
		if _failures == 0 else "%d failures" % _failures))
	quit(1 if _failures > 0 else 0)


## What a run said, judged.
func _judge(way: String, code: int, output: String, ended: int) -> void:
	if output.contains("SCRIPT ERROR") or output.contains("Parse Error"):
		print(output.right(3000))
		_check("%s: the run had no script error" % way, false)
		return
	var up: String = _said(output, "UP ")
	_check("%s: %s as the close was sent" % [way, "nothing up" if way == "none" else up + " up"],
		(up == "none") == (way == "none") and not up.is_empty())
	if way == "open":
		for line: String in output.split("\n"):
			if line.begins_with("HOLDS "):
				var held: String = line.trim_prefix("HOLDS ")
				_check("open: %s" % held.trim_prefix("yes ").trim_prefix("no "), held.begins_with("yes "))
	_check("%s: the close was sent as a window manager sends it (%s)" % [way, _said(output, "X11 ")],
		_said(output, "X11 ").begins_with("0 "))
	var sent: int = int(_said(output, "SENT "))
	var heard: String = _said(output, "HEARD ")
	_check("%s: the app heard it (%s)" % [way, "%d ms after" % (int(heard) - sent)
		if not heard.is_empty() else "never: " + ("still up %.0f s later" % (WAIT_MS / 1000.0)
			if output.contains("the app did not quit") else "nothing said")], not heard.is_empty())
	_check("%s: and was gone %d ms after it (%d at most)" % [way, ended - sent, GONE_MS],
		sent > 0 and not output.contains("the app did not quit") and ended - sent <= GONE_MS)
	var aborts := PackedStringArray()
	for line: String in output.split("\n"):
		for abort: String in ABORTS:
			if line.contains(abort):
				aborts.append(line.strip_edges())
	_check("%s: nothing aborted the exit (%s)" % [way, "; ".join(aborts) if not aborts.is_empty()
		else "nothing said"], aborts.is_empty())
	_check("%s: exited 0 (%d)" % [way, code], code == 0)
	if way in ["save-as", "confirm"]:
		var now: int = int(_said(output, "NOW "))
		var before: int = int(_said(output, "BEFORE "))
		var kept: int = _parts(_said(output, "AUTOSAVE "))
		_check("%s: asked nothing, and the working model has the part taken off (%d parts, %d before)"
			% [way, kept, before], before > 0 and now == before - 1 and kept == now)


## The app, a dialog up, and the close; the parent reads what it says.
func _child() -> void:
	await process_frame
	var way: String = "none"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--way="):
			way = argument.trim_prefix("--way=")
	# Godot's own Save dialog: the platform's would open on the desktop
	# this shell's bus belongs to, where nothing could close it.
	SaveTo.native = false
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var shell: Shell = main.get("_shell")
	var bar: ModelBar = main.get("_bar")
	var store: ModelStore = main.get("_store")
	var ear := _Ear.new()
	root.add_child(ear)
	if way in ["save-as", "confirm"]:
		# A probe keeps no working model unless it turns that on (Main).
		# The working model written as it stands, then a part taken off: only
		# the close writes that (the autosave waits 2.5 s for changes to settle).
		store.keeps = true
		store.write_now()
		print("BEFORE %d" % ModelStore.count_in(store.to_text(store.title)))
		var builder: Builder = main.get("_builder")
		for brick: BrickWorld.Brick in (main.get("_world") as BrickWorld).bricks():
			if not store.scenery.has(brick.id):
				builder.select_brick(brick.id, false)
				break
		builder.remove_selection()
		print("AUTOSAVE %s" % ProjectSettings.globalize_path(ModelStore.autosave()))
		print("NOW %d" % ModelStore.count_in(store.to_text(store.title)))
	var dialog: Window = null
	match way:
		"open":
			shell.run("import_ldraw")
			await _until(func() -> bool: return _picker_dialog(bar) != null \
				and _picker_dialog(bar).visible, 600)
			dialog = _picker_dialog(bar)
		"save-as":
			shell.run("save_as")
			await _until(func() -> bool: return SaveTo.showing != null and SaveTo.showing.visible, 600)
			dialog = SaveTo.showing
		"confirm":
			shell.run("new")
			dialog = bar.get("_confirm_new")
			await _until(func() -> bool: return dialog.visible, 600)
		"accept":
			shell.run("about")
			dialog = shell.get("_about")
			await _until(func() -> bool: return dialog.visible, 600)
	# A person reads it a moment first.
	var until: int = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await process_frame
	print("UP %s" % ("none" if dialog == null else "%s “%s”" % [dialog.get_class(), dialog.title]
		if dialog.visible else "not up"))
	if way == "open" and dialog != null:
		await _holds(main, dialog)
	await _shot(way)
	# The close button pressed: the window manager's message to the main window.
	var window: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	var said: Array = []
	var sent: int = OS.execute("python3", ["-I", ProjectSettings.globalize_path(CLOSER),
		str(window)], said, true)
	print("SENT %d" % int(Time.get_unix_time_from_system() * 1000.0))
	print("X11 %d %s" % [sent, "".join(said).strip_edges()])
	until = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < until:
		await process_frame
	await _shot(way + "_after")
	print("the app did not quit")
	quit(3)


## Whether [param dialog] still holds the main window: a click on File
## beside it, and Ctrl+N, each said on a HOLDS line.
func _holds(main: Node, dialog: Window) -> void:
	var file: MenuButton = (main.get("_shell") as Shell).controls_by_name().get("menu_file")
	var confirm_new: ConfirmationDialog = (main.get("_bar") as ModelBar).get("_confirm_new")
	var store: ModelStore = main.get("_store")
	var parts: int = ModelStore.count_in(store.to_text(store.title))
	if file == null:
		print("HOLDS no File menu to click beside it")
		return
	var at: Vector2 = file.get_global_transform_with_canvas() * (file.size / 2.0)
	var beside: bool = not Rect2(Vector2(dialog.position), Vector2(dialog.size)).grow(40.0).has_point(at)
	await _click(at)
	print("HOLDS %s a click on File beside the dialog (%s) opened no menu and left it up"
		% ["yes" if beside and not file.get_popup().visible and dialog.visible else "no", at.round()])
	print("HOLDS %s the keys went back to the dialog (%s)" % ["yes" if dialog.has_focus() else "no",
		"it has them" if dialog.has_focus() else "nothing has them"])
	await _key(KEY_N, true)
	var after: int = ModelStore.count_in(store.to_text(store.title))
	print("HOLDS %s Ctrl+N beside it started nothing (parts %d, then %d; New's question %s)"
		% ["yes" if after == parts and not confirm_new.visible and dialog.visible else "no", parts,
		after, "up" if confirm_new.visible else "not up"])
	if file.get_popup().visible:
		file.get_popup().hide()


static func _picker_dialog(bar: ModelBar) -> FileDialog:
	var picker: Node = bar.get("_picker")
	return picker.get("_dialog") if picker != null else null


func _click(at: Vector2) -> void:
	var where: Vector2 = root.get_final_transform() * at
	var move := InputEventMouseMotion.new()
	move.position = where
	move.global_position = where
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = where
		event.global_position = where
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _key(code: Key, command: bool) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _until(done: Callable, frames: int) -> void:
	for _n: int in frames:
		if done.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join("dialog_close_%s.png" % name))


static func _said(output: String, key: String) -> String:
	for line: String in output.split("\n"):
		if line.begins_with(key):
			return line.trim_prefix(key).strip_edges()
	return ""


## The parts in a model file, as the app counts them once it is open.
static func _parts(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return -1
	return ModelStore.count_in(FileAccess.get_file_as_string(path))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## Says when the close request reaches the app's nodes, as the window
## tells each of them.
class _Ear extends Node:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			print("HEARD %d" % int(Time.get_unix_time_from_system() * 1000.0))
