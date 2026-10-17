## Does the app quit cleanly after a big model, and keep an edit made just
## before?
##
##   godot --headless --path . --script src/dev/quit_probe.gd
##
## Each way a person quits, in a run of the app of its own, since the quit is
## what is judged: the window's close request, and File, Quit (the shell's
## command, which is what Ctrl+Q runs). Each opens a model of 1,000 parts,
## keeps its working model, deletes a part (and the sub-model copy it is in)
## while the model's weigh is out on a worker (Main._weigh: 600 parts or
## more), and quits at once.
##
## Until 2026-10-16 the engine dumped core on the way out every time (SIGABRT;
## the weigh's task freed after GDScript had gone, WorkerTasks), and the edit
## was lost: the autosave waits 2.5 s for changes to settle, and nothing wrote
## it as the app closed. Pass: each run exits 0 and its autosave has the
## parts off.
##
## And the window closed a few seconds into a Brickify run on its worker
## (the bunny at BRICKIFY_STUDS): the run is told to stop and the app is
## gone within BRICKIFY_GONE ms, where it used to wait the run out.
extends SceneTree

const PARTS := 1000
const WAYS := ["close", "menu", "brickify"]
const BRICKIFY_STUDS := 64
const BRICKIFY_GONE := 8000

var _failures: int = 0


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--child"):
		_child()
	else:
		_parent()


func _parent() -> void:
	# -- --only=brickify runs one way.
	var ways: Array = WAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			ways = argument.trim_prefix("--only=").split(",")
	for way: String in ways:
		var said: Array = []
		var code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless",
			"--path", ProjectSettings.globalize_path("res://"), "--script",
			"res://src/dev/quit_probe.gd", "--", "--child", "--way=" + way]), said, true)
		var output: String = "".join(said)
		var ended: int = int(Time.get_unix_time_from_system() * 1000.0)
		if output.contains("SCRIPT ERROR") or output.contains("Parse Error"):
			print(output.right(3000))
			_check("%s: the run had no script error" % way, false)
			continue
		if way == "brickify":
			var asked: int = int(_said(output, "QUIT-AT "))
			_check("brickify: the window closed with a run on its worker (%s)"
				% _said(output, "BRICKIFYING "), _said(output, "BRICKIFYING ").begins_with("true"))
			_check("brickify: and the app was gone %.1f s later, the run stopped, not waited out "
				% ((ended - asked) / 1000.0) + "(at most %.0f s)" % (BRICKIFY_GONE / 1000.0),
				asked > 0 and ended - asked <= BRICKIFY_GONE)
			_check("brickify: and exited 0 (%d)" % code, code == 0)
			continue
		var before: int = int(_said(output, "AUTOSAVE-BEFORE "))
		var took: int = int(_said(output, "TOOK "))
		# The model as it stood at the quit, counted as its file would be (a
		# sub-model emptied by the Delete stays in it, and counts one).
		var now: int = int(_said(output, "NOW "))
		var weighing: bool = _said(output, "WEIGHING ") == "true"
		var out: int = int(_said(output, "TASKS-OUT "))
		var after: int = _parts(_said(output, "AUTOSAVE "))
		_check("%s: the app quit with the model's weigh on a worker (%d task out)" % [way, out],
			weighing and out > 0)
		_check("%s: and exited 0 (%d)" % [way, code], code == 0)
		_check("%s: the %d parts deleted just before are off in the autosave (%d parts, %d before, "
			% [way, took, after, before] + "%d at the quit)" % now,
			took > 0 and now < before and after == now)
	print("quit: %s" % ("quits cleanly and keeps the last edit" if _failures == 0
		else "%d failures" % _failures))
	quit(1 if _failures > 0 else 0)


## The app, the model, the edit, and the quit; the parent reads what it says.
func _child() -> void:
	await process_frame
	var way: String = "close"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--way="):
			way = argument.trim_prefix("--way=")
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	if way == "brickify":
		await _brickify_then_close(main)
		return
	var store: ModelStore = main.get("_store")
	var builder: Builder = main.get("_builder")
	var world: BrickWorld = main.get("_world")
	# A probe keeps no working model unless it turns that on (Main).
	store.keeps = true
	var made: String = load("res://src/dev/bigmodel_probe.gd").call("_made", PARTS)
	var result: Dictionary = store.open_text(made, "Quit Probe")
	(main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
	store.adopt()
	store.write_now()
	print("AUTOSAVE %s" % ProjectSettings.globalize_path(ModelStore.autosave()))
	print("AUTOSAVE-BEFORE %d" % _parts(ModelStore.autosave()))
	for _n: int in 600:
		if bool(main.get("_weighing")):
			break
		await process_frame
	print("WEIGHING %s" % bool(main.get("_weighing")))
	print("TASKS-OUT %d" % WorkerTasks.out())
	# A part clicked and Delete pressed (its sub-model copy goes with it), and
	# straight out.
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id):
			builder.select_brick(brick.id, false)
			break
	print("TOOK %d" % builder.remove_selection())
	print("NOW %d" % ModelStore.count_in(store.to_text(store.title)))
	match way:
		"menu":
			main.get("_shell").call("run", "quit")
		_:
			# What the window is sent when its close button is pressed.
			root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
			root.close_requested.emit()
	# A quit that never came is a failure, not a hang.
	for _n: int in 600:
		await process_frame
	print("the app did not quit")
	quit(3)


## The bunny brickified, and the window closed while the run is on its
## worker, past its measuring.
func _brickify_then_close(main: Node) -> void:
	var dialog: BrickifyDialog = main.get("_brickify")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/brickify/bunny.obj")
	dialog.show_for(MeshFile.read(bytes, "bunny.obj"))
	dialog.set_studs(BRICKIFY_STUDS)
	dialog.brickify()
	for _n: int in 6000:
		if int(dialog.get("_task")) >= 0:
			break
		await process_frame
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
	var progress: Brickify.Progress = dialog.get("_progress")
	print("BRICKIFYING %s, %s" % [int(dialog.get("_task")) >= 0,
		progress.said() if progress != null else "no run"])
	print("QUIT-AT %d" % int(Time.get_unix_time_from_system() * 1000.0))
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	root.close_requested.emit()
	for _n: int in 600:
		await process_frame
	print("the app did not quit")
	quit(3)


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
