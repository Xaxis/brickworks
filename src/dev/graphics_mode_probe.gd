## The simpler graphics mode, said once, and Settings, Graphics, kept for
## the next start (GraphicsMode).
##
##   godot --path . --resolution 1400x900 --script src/dev/graphics_mode_probe.gd
##
## Started again as a Mac's launcher starts a GPU the full mode cannot run
## on: --rendering-driver opengl3, BRICKWORKS_GRAPHICS saying why. The window
## must say "This computer's graphics run Brickworks in its simpler mode."
## (on a Mac, "This Mac's") above the model, once: not again in this run,
## nor in the next start, which reads the app's own folder. What needs the
## full mode must say so in its words, not "the desktop app": Best's path
## tracing and Good's light between the parts. Then Settings, Graphics,
## chosen as a person chooses: Simpler writes graphics.cfg, and an app
## started afterwards with no renderer named draws in Compatibility; Full
## writes the full one; Automatic removes the file, and the next start is
## Forward+ again. Each next start is this script again, as a child, with
## --report: it writes what it draws with and whether it would say the line.
extends SceneTree

const WHY := "Apple Paravirtual device, 1024 MB"

var _failures: int = 0


func _initialize() -> void:
	# What survives a restart is this probe's to check: its own data folder.
	ShellPrefs.kept_by_a_check = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			_report(argument.trim_prefix("--report="))
			return
	OS.set_environment("BRICKWORKS_GRAPHICS", WHY)
	if not GraphicsMode.simpler():
		_as_the_launcher_starts_it()
		return
	_run()


## This script again, on OpenGL, as the launcher starts the app on a GPU
## the full mode cannot run on; its lines and its verdict are this run's.
func _as_the_launcher_starts_it() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--path",
		ProjectSettings.globalize_path("res://"), "--resolution", "1400x900", "--rendering-driver",
		"opengl3", "--script", "res://src/dev/graphics_mode_probe.gd"], output, true)
	print("".join(output))
	quit(code)


## A next start: what it draws with, and whether it would say the line.
func _report(path: String) -> void:
	await process_frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": RenderingServer.get_current_rendering_method(),
		"says": GraphicsMode.to_say()}))
	file.close()
	quit(0)


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	_check("started in the simpler mode: %s" % RenderingServer.get_current_rendering_method(),
		GraphicsMode.simpler())
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	(main.get("_store") as ModelStore).keeps = false

	var line: String = "This Mac's graphics run Brickworks in its simpler mode." \
		if OS.get_name() == "macOS" else "This computer's graphics run Brickworks in its simpler mode."
	var notice: RestoreNotice = main.get("_graphics_notice")
	_check("the window says \"%s\"" % (notice.words() if notice != null else "nothing"),
		notice != null and notice.is_visible_in_tree() and notice.words() == line)
	var named: Dictionary = main.call("_page_controls")
	_check("...with Got it", named.has("graphics_got_it"))
	_check("...and not again in this run", GraphicsMode.to_say().is_empty())
	_check("the log says which mode, and why: %s" % GraphicsMode.describe(),
		GraphicsMode.describe().begins_with("graphics: simpler mode (automatic: %s)" % WHY))
	if named.has("graphics_got_it"):
		(named["graphics_got_it"] as Button).pressed.emit()
		await process_frame
		_check("Got it puts it away", not notice.visible)
	# As the launcher starts it again on the same Mac: OpenGL, named.
	var next: Dictionary = _next_start(["--rendering-driver", "opengl3"])
	_check("the next start is simpler too (%s) and says nothing: \"%s\"" % [next.get("method"),
		next.get("says")], next.get("method") == "gl_compatibility" and next.has("says")
		and str(next.get("says")).is_empty())

	_check("Best says path tracing needs the full mode: %s" % PathTracer.why_not(),
		PathTracer.why_not().contains("full graphics mode"))
	var render: Node = main.get("_render")
	(render.get("settings") as RenderSettings).quality = RenderSettings.Quality.GOOD
	render.call("_describe")
	var good: String = (render.get("_quality_note") as Label).text
	_check("Good says light between the parts needs the full mode: %s" % good,
		good.ends_with("needs the full graphics mode."))

	var settings: Node = main.get("_controls")
	settings.call("open")
	await process_frame
	var choice: OptionButton = settings.get("graphics_choice")
	var note: Label = settings.get("_graphics_note")
	if not _check("Settings has Graphics", choice != null and choice.is_visible_in_tree()):
		_done()
		return
	_check("...on Automatic, which says why: %s" % note.text,
		choice.selected == 0 and note.is_visible_in_tree() and note.text.contains(WHY))
	for pick: Array in [[2, "simpler", "gl_compatibility"], [1, "full", "forward_plus"],
			[0, "automatic", ""]]:
		choice.select(pick[0])
		choice.item_selected.emit(pick[0])
		await process_frame
		var kept: String = FileAccess.get_file_as_string(GraphicsMode.WHERE)
		_check("%s: %s" % [choice.get_item_text(pick[0]), kept.strip_edges().replace("\n", " ")
			if not kept.is_empty() else "no graphics.cfg"], kept.contains(pick[2]) if pick[2] != ""
			else not FileAccess.file_exists(GraphicsMode.WHERE))
		_check("...said: %s" % note.text.replace("\n", " "), GraphicsMode.chosen() == pick[1]
			and note.text.ends_with("From the next start.") == (pick[1] != "automatic"))
		if pick[1] != "full":
			next = _next_start()
			var drawn: String = "gl_compatibility" if pick[1] == "simpler" else "forward_plus"
			_check("...and the next start draws in %s: %s" % [drawn, next.get("method")],
				next.get("method") == drawn)
	_done()


## This script again in a window of its own, as the app starts next, with
## [param named] for its renderer (none, unless given), in the same data
## folder.
func _next_start(named: PackedStringArray = PackedStringArray()) -> Dictionary:
	var report: String = OS.get_user_data_dir().path_join("next_start.json")
	DirAccess.remove_absolute(report)
	var output: Array = []
	OS.execute(OS.get_executable_path(), PackedStringArray(["--path",
		ProjectSettings.globalize_path("res://"), "--resolution", "320x240"]) + named
		+ PackedStringArray(["--script", "res://src/dev/graphics_mode_probe.gd", "--",
		"--report=" + report]), output, true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report))
	if parsed is Dictionary:
		return parsed
	print("        next start said nothing: %s" % "".join(output).right(600))
	return {}


func _done() -> void:
	print("")
	if _failures == 0:
		print("the simpler mode is said once, and Settings, Graphics holds for the next start")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
