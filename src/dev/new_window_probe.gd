## File, New window on the desktop: a second window, on a new model of its
## own, and this one left as it is.
##
##   godot --headless --path . --script src/dev/new_window_probe.gd
##
## The owner asked how a person even starts a new model in another tab.
## Before New tab and New window there was no way from the app: a second
## window took the newest session nobody held, which was an older model,
## never a new one (src/parts/tab_session.gd).
##
## This window has the example car; another session nobody holds, with a
## tower of four in it, was written moments ago, as a window closed earlier
## leaves one. Then:
##
##   1. File, New window (its menu row, with Ctrl+Shift+N) starts the app
##      again: a process of its own, holding a session of its own, not the
##      tower's, and its working model is written at once with no parts, an
##      empty baseplate, Untitled. The tower's session is still nobody's and
##      as it was, and this window has the car it had.
##   2. A window opened as before (the same command line, without
##      --new-session) takes the newest session nobody holds: the tower's.
##
## Real processes in this run's data folder (tools/probe.sh gives one),
## stopped by their ids at the end. Headless, so the windows it starts are
## headless too (TabSession.window_arguments). Not in the suite: it starts
## two more copies of the app, each ~20 s to come up.
extends SceneTree

## How long a copy of the app has to come up and hold its session.
const PATIENCE_S := 240.0

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var tower: String = TabSession.fresh_id()
	DirAccess.make_dir_recursive_absolute(TabSession.ROOT + tower)
	var text: String = "0 Older Tower\n0 Name: autosave.ldr\n"
	for n: int in 4:
		text += "1 4 0 %d 0 1 0 0 0 1 0 0 0 1 3001.dat\n" % (-24 * n)
	_write(TabSession.ROOT + tower + "/autosave.ldr", text)

	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 60:
		await process_frame
	var shell: Shell = main.get("_shell")
	var world: BrickWorld = main.get("_world")
	var store: ModelStore = main.get("_store")
	var bricks: int = world.brick_count()
	var title: String = store.title
	_check("this window has a model: %s, %d parts" % [title, bricks], bricks > 0)

	print("\nthe menu row")
	var file: PopupMenu = shell.menu("File").get_popup()
	var row: int = file.get_item_index(shell.menu_id("new_window"))
	_check("File has New window, second, after New: \"%s\"" % file.get_item_text(row),
		row == file.get_item_index(shell.menu_id("new")) + 1
		and file.get_item_text(row) == "New window")
	_check("...saying what it does: \"%s\"" % file.get_item_tooltip(row),
		file.get_item_tooltip(row) == "Start a new model in a window of its own")
	var key := InputEventKey.new()
	key.keycode = KEY_N
	key.ctrl_pressed = true
	key.shift_pressed = true
	key.pressed = true
	_check("...on Ctrl+Shift+N (%s), with Ctrl+N still New"
		% Shell.key_text(shell.command("new_window").accel),
		shell.command_for_key(key) == "new_window"
		and Shell.key_text(shell.command("new_window").accel) == "Ctrl+Shift+N"
		and shell.command("new").accel == Shell.CTRL | KEY_N)

	print("\nFile, New window")
	var before: Dictionary = _sessions()
	file.id_pressed.emit(shell.menu_id("new_window"))
	var made: Dictionary = await _held_anew(before)
	var id: String = str(made.get("id", ""))
	var pid: int = int(made.get("pid", 0))
	_check("a second process holds a session of its own: %s by %d" % [id, pid],
		not id.is_empty() and pid > 0 and pid != OS.get_process_id())
	_check("...started as a new window (--new-session)",
		_cmdline(pid).has(TabSession.NEW_WINDOW))
	_check("...not the tower's session, which nobody held", id != tower)
	var autosave: String = TabSession.ROOT + id + "/autosave.ldr"
	var kept: String = FileAccess.get_file_as_string(autosave)
	_check("...its working model written at once, with no parts: %s"
		% kept.get_slice("\n", 0).strip_edges(),
		FileAccess.file_exists(autosave) and ModelStore.count_in(kept) == 0
		and kept.begins_with("0 Untitled"))
	_check("the tower's session is still nobody's, and as it was",
		not _sessions().has(tower)
		and FileAccess.get_file_as_string(TabSession.ROOT + tower + "/autosave.ldr") == text)
	_check("this window still has its model: %s, %d parts" % [store.title, world.brick_count()],
		store.title == title and world.brick_count() == bricks)

	print("\na window opened as before")
	var plain: PackedStringArray = TabSession.window_arguments()
	plain.resize(plain.size() - 2)
	_check("...is the same command line without --new-session: %s" % " ".join(plain),
		not plain.has(TabSession.NEW_WINDOW) and not plain.has("--script"))
	before = _sessions()
	var other: int = OS.create_instance(plain)
	var took: Dictionary = await _held_anew(before)
	_check("it takes the newest session nobody holds, the tower's: %s by %d"
		% [took.get("id", ""), int(took.get("pid", 0))],
		str(took.get("id", "")) == tower and int(took.get("pid", 0)) == other)
	_check("...and the new window still holds its own", _sessions().get(id, 0) == pid)

	_done()


## The sessions held by a process that is running: id -> process id.
func _sessions() -> Dictionary:
	var held: Dictionary = {}
	for name: String in DirAccess.get_directories_at(TabSession.ROOT):
		var pid_file: String = TabSession.ROOT + name + "/held/pid"
		if not FileAccess.file_exists(pid_file):
			continue
		var pid: int = FileAccess.get_file_as_string(pid_file).strip_edges().to_int()
		if pid > 0 and DirAccess.dir_exists_absolute("/proc/%d" % pid):
			held[name] = pid
	return held


## The first session held that was not in [param before], with its process
## id and, for a new one, its working model written: {id, pid}, or {}.
func _held_anew(before: Dictionary) -> Dictionary:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < PATIENCE_S * 1000.0:
		var now: Dictionary = _sessions()
		for name: String in now:
			if not before.has(name) \
					and FileAccess.file_exists(TabSession.ROOT + name + "/autosave.ldr"):
				return {"id": name, "pid": int(now[name])}
		await create_timer(0.5).timeout
	return {}


## The processes this one started, still running. Asked of pgrep by parent
## id: a file under /proc says it is empty, so FileAccess reads nothing.
func _children() -> Array[int]:
	var found: Array[int] = []
	var said: Array = []
	OS.execute("pgrep", ["-P", str(OS.get_process_id())], said)
	for line: String in "".join(said).split("\n", false):
		var pid: int = line.strip_edges().to_int()
		# Not pgrep itself, gone by now.
		if pid > 0 and DirAccess.dir_exists_absolute("/proc/%d" % pid):
			found.append(pid)
	return found


## What [param pid] was started with: its arguments, separated by NULs in
## /proc, which FileAccess reads as empty.
func _cmdline(pid: int) -> PackedStringArray:
	var said: Array = []
	OS.execute("sh", ["-c", "tr '\\0' '\\n' < /proc/%d/cmdline" % pid], said)
	return "".join(said).split("\n", false)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	# Every copy this started, found or not.
	var children: Array[int] = _children()
	for child: int in children:
		OS.kill(child)
	print("  stopped %s" % str(children))
	print("")
	if _failures == 0:
		print("New window starts a second window on a new model of its own")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
