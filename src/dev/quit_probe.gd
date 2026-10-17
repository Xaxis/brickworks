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
##
## And the window closed with File, Render… at work on the sample car:
##   render        its first open, while the draft is being drawn;
##   render-again  its second open, the same;
##   render-keep   a 4K picture drawn and being encoded: the PNG is written
##                 whole as the app closes, and the app says so;
##   render-cut    a Good 1080p picture half drawn: nothing is written, and
##                 the app says so;
##   render-turn   a turntable a few frames in: the frames drawn are kept,
##                 and the app says it was not finished.
## Each exits 0, and nothing of the app's scripts is left on the signals of
## RenderingServer or any engine singleton as the scene tree goes: they
## outlive GDScript, and a lambda left on frame_pre_draw dumped core on the
## way out (SIGABRT, exit 134), as a probe's timing left one during a draft
## once (2026-10-17).
## A draft is drawn only with a display: run with -- --windowed under
## xvfb-run (on the GPU) for the drawing; headless, the first two open and
## close Render with no draft, and the rest are left out. --runs=N runs
## each way N times, closing the draft a few frames later each time.
extends SceneTree

const PARTS := 1000
const WAYS := ["close", "menu", "brickify", "render", "render-again", "render-keep", "render-cut",
	"render-turn"]
const BRICKIFY_STUDS := 64
const BRICKIFY_GONE := 8000

## Frames after the draft starts that the window is closed, run by run: a
## draft on the card is 9-18 frames, so each lands somewhere in it.
const DRAFT_DELAYS := [0, 1, 2, 3, 4, 5, 6, 7]

var _failures: int = 0


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--child"):
		_child()
	else:
		_parent()


func _parent() -> void:
	# -- --only=brickify runs one way.
	var ways: Array = WAYS
	var windowed: bool = OS.get_cmdline_user_args().has("--windowed")
	var runs: int = 1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			ways = argument.trim_prefix("--only=").split(",")
		elif argument.begins_with("--runs="):
			runs = maxi(int(argument.trim_prefix("--runs=")), 1)
	var all: Array = []
	for way: String in ways:
		if way in ["render-keep", "render-cut", "render-turn"] and not windowed:
			print("  (%s: left out headless, where nothing is drawn; run -- --windowed)" % way)
			continue
		for run: int in runs:
			all.append([way, run])
	for each: Array in all:
		var way: String = each[0]
		var arguments := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://src/dev/quit_probe.gd", "--", "--child", "--way=" + way,
			"--delay=%d" % DRAFT_DELAYS[int(each[1]) % DRAFT_DELAYS.size()]])
		arguments = (PackedStringArray(["--resolution", "1400x900"]) if windowed
			else PackedStringArray(["--headless"])) + arguments
		var said: Array = []
		var code: int = OS.execute(OS.get_executable_path(), arguments, said, true)
		var output: String = "".join(said)
		var ended: int = int(Time.get_unix_time_from_system() * 1000.0)
		if output.contains("SCRIPT ERROR") or output.contains("Parse Error"):
			print(output.right(3000))
			_check("%s: the run had no script error" % way, false)
			continue
		if way.begins_with("render"):
			_judge_render(way, code, output, windowed)
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


## What a run that closed the window with Render at work said, judged.
func _judge_render(way: String, code: int, output: String, windowed: bool) -> void:
	var doing: String = _said(output, "DOING ")
	var left: String = _said(output, "LEFT-ON-ENGINE ")
	if windowed:
		_check("%s: the window closed with Render at work (%s)" % [way, doing],
			doing.begins_with("true"))
	else:
		_check("%s: the window closed with Render open (headless: no draft is drawn)" % way,
			_said(output, "OPEN ") == "true")
	_check("%s: nothing of the app's scripts was left on the engine's signals (%s)"
		% [way, left if not left.is_empty() else "not said"], left == "none")
	_check("%s: and exited 0 (%d)" % [way, code], code == 0)
	var lines := PackedStringArray()
	for line: String in output.split("\n"):
		if line.begins_with("render, as the app closed: "):
			lines.append(line.trim_prefix("render, as the app closed: "))
	var folder: String = _said(output, "RENDER-FOLDER ")
	var written: PackedStringArray = DirAccess.get_files_at(folder) \
		if not folder.is_empty() and DirAccess.dir_exists_absolute(folder) else PackedStringArray()
	match way:
		"render-keep":
			var path: String = folder.path_join(_said(output, "PICTURE "))
			var image: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
			_check("render-keep: the picture being encoded was written whole as the app closed "
				+ "(%s, %s)" % [path.get_file(), str(image.get_size()) if image != null else "none"],
				image != null and image.get_size() == Vector2i(3840, 2160))
			_check("render-keep: and the app said so (%s)" % "; ".join(lines),
				lines.size() == 1 and lines[0].begins_with("wrote "))
		"render-cut":
			_check("render-cut: nothing was written of the picture half drawn (%s)"
				% (", ".join(written) if not written.is_empty() else "no file"), written.is_empty())
			_check("render-cut: and the app said so (%s)" % "; ".join(lines),
				lines.size() == 1 and lines[0].contains("not finished"))
		"render-turn":
			var frames_dir: String = folder.path_join(_said(output, "TURNTABLE "))
			var frames: int = 0
			if DirAccess.dir_exists_absolute(frames_dir):
				for name: String in DirAccess.get_files_at(frames_dir):
					if name.begins_with("frame_") and name.ends_with(".png") \
							and Image.load_from_file(frames_dir.path_join(name)) != null:
						frames += 1
			var said: String = "; ".join(lines)
			_check("render-turn: the frames drawn before the close are kept (%d in %s)"
				% [frames, frames_dir.get_file()], frames >= 3)
			_check("render-turn: and the app said it was not finished, and how many (%s)" % said,
				lines.size() == 1 and said.contains("not finished: %d frames kept" % frames))
			_check("render-turn: no WebP of it (%s)" % ", ".join(written), written.is_empty())
		_:
			_check("%s: a draft is not a render: nothing written, nothing said (%d files, %d lines)"
				% [way, written.size(), lines.size()], written.is_empty() and lines.is_empty())


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
	if way.begins_with("render"):
		await _render_then_close(main, way)
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


## Render opened on the sample car, and the window closed while it is at
## work (see the ways at the top).
func _render_then_close(main: Node, way: String) -> void:
	var delay: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--delay="):
			delay = int(argument.trim_prefix("--delay="))
	var shell: Shell = main.get("_shell")
	var dialog: RenderDialog = main.get("_render")
	# Its own folder, emptied, never Downloads.
	var folder: String = ProjectSettings.globalize_path("user://quit_probe_render")
	DirAccess.make_dir_recursive_absolute(folder)
	for inside: String in DirAccess.get_directories_at(folder):
		for name: String in DirAccess.get_files_at(folder.path_join(inside)):
			DirAccess.remove_absolute(folder.path_join(inside).path_join(name))
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	dialog.folder = folder
	print("RENDER-FOLDER %s" % folder)
	root.tree_exiting.connect(_left_on_engine)
	shell.run("render")
	var drawing: bool = StudioRender.possible()
	if way != "render" and drawing:
		await _until(func() -> bool: return _drafted(dialog), 6000)
	if way == "render-again":
		dialog.close()
		for _n: int in 10:
			await process_frame
		shell.run("render")
	var controls: Dictionary = dialog.controls_by_name()
	match way:
		"render-keep":
			(controls["render_quick"] as Button).pressed.emit()
			(controls["render_size_4k"] as Button).pressed.emit()
			(controls["render_picture"] as Button).pressed.emit()
			print("PICTURE %s" % RenderOutput.file_name(str(dialog.named.call()), "_render", "png"))
			await _until(func() -> bool:
				var writing: RenderOutput = dialog.get("_output")
				return writing != null and writing.writing(), 6000)
		"render-cut":
			(controls["render_good"] as Button).pressed.emit()
			(controls["render_size_1080p"] as Button).pressed.emit()
			(controls["render_picture"] as Button).pressed.emit()
			await _until(func() -> bool: return float(dialog.get("_fraction")) >= 0.3, 6000)
		"render-turn":
			(controls["render_quick"] as Button).pressed.emit()
			(controls["render_size_720p"] as Button).pressed.emit()
			(controls["render_frames_24"] as Button).pressed.emit()
			(controls["render_turntable"] as Button).pressed.emit()
			print("TURNTABLE %s" % RenderOutput.file_name(str(dialog.named.call()), "_turntable",
				"x").get_basename())
			await _until(func() -> bool:
				var writing: RenderOutput = dialog.get("_output")
				return writing != null and writing.frames_added() >= 4, 12000)
		_:
			if drawing:
				await _until(func() -> bool: return dialog.renderer != null \
					and dialog.renderer.is_busy(), 6000)
				for _n: int in delay:
					await process_frame
	var output: RenderOutput = dialog.get("_output")
	var doing: String = str(dialog.get("_working"))
	var busy: bool = dialog.renderer != null and dialog.renderer.is_busy()
	if way == "render-keep":
		busy = output != null and output.writing()
		doing = "writing the picture" if busy else "not writing"
	print("OPEN %s" % dialog.visible)
	# What the renderer did in the frame before (StudioRender._doing).
	var step: String = str(dialog.renderer.get("_step")) if dialog.renderer != null else ""
	print("DOING %s, %s, %s%s" % [busy, doing, (dialog.get("_status") as Label).text,
		", " + step if not step.is_empty() else ""])
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	root.close_requested.emit()
	for _n: int in 600:
		await process_frame
	print("the app did not quit")
	quit(3)


## Until [param done] says so, or [param frames] have gone.
func _until(done: Callable, frames: int) -> void:
	for _n: int in frames:
		if done.call():
			return
		await process_frame


static func _drafted(dialog: RenderDialog) -> bool:
	return str(dialog.get("_working")) == "" and dialog.renderer != null \
		and not dialog.renderer.is_busy() \
		and (dialog.get("_preview") as TextureRect).texture != null


## As the scene tree goes, last of all: anything of the app's scripts still
## on the signals of RenderingServer, or of any of the engine's singletons.
## They outlive GDScript, and a lambda (or a callable bound to an object of
## a script) left there is freed after GDScript has gone, which aborts the
## exit (SIGABRT). A node's (or the tree's) own method or lambda goes with
## it, and a coroutine waiting on a signal is let go of as GDScript ends.
func _left_on_engine() -> void:
	var left := PackedStringArray()
	for singleton: String in Engine.get_singleton_list():
		var holder: Object = Engine.get_singleton(singleton)
		if holder == null:
			continue
		for signal_info: Dictionary in holder.get_signal_list():
			var name: String = signal_info["name"]
			for connection: Dictionary in holder.get_signal_connection_list(name):
				# A lambda's object is its script, or the object of a script
				# it runs on; the engine's own are objects with no script, or
				# none (its static functions).
				var callable: Callable = connection["callable"]
				var target: Object = callable.get_object()
				if not callable.is_custom() or target == null or target is Node \
						or target is SceneTree \
						or (not target is Script and target.get_script() == null):
					continue
				left.append("%s on %s.%s" % [str(callable), singleton, name])
	print("LEFT-ON-ENGINE %s" % (", ".join(left) if not left.is_empty() else "none"))


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
