## A set's page's two ways into the studio (sethub, 2026-11-23), as Main
## takes them from the address: /app?new=1&library=<id>&build (Build it) and
## /app?new=1&library=<id> (Make your own version).
##
##   godot --headless --path . --script src/dev/sethub_probe.gd
##
## A stand-in store (tools/web/serve.py --library tests/fixtures/library, on
## port 11763) plays the parts store's library/, as library_probe's does.
##
##   1. Make your own version: Moon Walker (6516-1) opened as it is, credited
##      to its LDraw modeller, its timeline down; how long the open took (the
##      bar: the studio's open time + 2 s).
##   2. Build it: the same set opened again with the build asked for, then
##      its timeline up at its first step (the parts of step 1 shown, of
##      all), and how long after the open that took.
##   3. A build asked for with no set (an id the store has not got): nothing
##      opened, and no timeline.
##   4. The library's index read off the frame (ModelLibrary.json_off_frame):
##      one as big as the real one (half a megabyte) read whole while the
##      frames go on, its longest frame said beside the same read on the
##      main thread; bytes that are not JSON read as null.
extends SceneTree

const PORT := 11763

var _failures: int = 0
var _main: Node
var _server: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(n: int) -> void:
	for _n: int in n:
		await process_frame


func _run() -> void:
	var fixture: String = ProjectSettings.globalize_path("res://tests/fixtures/library")
	var omr: String = ProjectSettings.globalize_path("res://vendor/omr/files")
	_server = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/web/serve.py"),
		fixture, str(PORT), "--library", fixture, "--omr", omr])
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:%d" % PORT)
	await create_timer(1.5).timeout
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var store: ModelStore = _main.get("_store")
	var world: BrickWorld = _main.get("_world")
	var bar: ModelBar = _main.get("_bar")
	var steps: StepsBar = _main.get("_steps")
	var moon: int = ModelStore.count_in(FileAccess.get_file_as_string("res://vendor/omr/files/6516-1.mpd"))

	print("\nMake your own version: /app?new=1&library=omr-6516-1")
	_main.set("_from_library", "omr-6516-1")
	_main.set("_from_library_build", false)
	var began: int = Time.get_ticks_msec()
	await _main.call("_maybe_open_library")
	var opened_ms: int = Time.get_ticks_msec() - began
	await _frames(10)
	_check("Moon Walker on the baseplate in %.2f s: %s, %d parts (its file places %d)" % [opened_ms / 1000.0,
		store.title, world.brick_count() - store.scenery.size(), moon],
		store.title == "6516-1 Moon Walker" and world.brick_count() - store.scenery.size() >= moon)
	_check("a copy credited to its LDraw modeller: %s" % ModelBar.credit_words(store.credit),
		str(store.credit.get("by", "")) == "Chris Böhnke"
		and str(store.credit.get("page", "")).begins_with("https://library.ldraw.org/omr/sets/"))
	_check("its timeline down, to change it: %s" % str(steps.page_state()), not steps.is_playing_back())

	print("\nBuild it: /app?new=1&library=omr-6516-1&build")
	_main.set("_from_library", "omr-6516-1")
	_main.set("_from_library_build", true)
	began = Time.get_ticks_msec()
	await _main.call("_maybe_open_library")
	var built_ms: int = Time.get_ticks_msec() - began
	await _frames(10)
	var ends: Array = steps.get("_step_ends")
	var at: Vector2i = steps.timeline_at()
	_check("opened, and its timeline up at its first step in %.2f s: %d of %d parts shown, step 1 ends at %s (%s)"
		% [built_ms / 1000.0, at.x, at.y, str(ends[0]) if not ends.is_empty() else "-", str(steps.page_state().get("caption", ""))],
		store.title == "6516-1 Moon Walker" and steps.is_playing_back() and not ends.is_empty()
		and at.x == int(ends[0]) and at.x < at.y)
	_check("the build asked for is taken once: %s" % str(_main.get("_from_library_build")),
		_main.get("_from_library_build") == false)
	steps.stop()

	print("\nA build asked for with a set the store has not got")
	_main.set("_from_library", "omr-99999-1")
	_main.set("_from_library_build", true)
	await _main.call("_maybe_open_library")
	await _frames(10)
	_check("said, nothing opened, no timeline: %s" % bar.status_text(),
		bar.status_text() == "could not open it: The library has no model omr-99999-1." and not steps.is_playing_back())

	print("\nThe library's index read off the frame")
	var models: Array = []
	for n: int in 2400:
		models.append({"id": "omr-%d-1" % n, "set": "%d-1" % n, "name": "%d-1 A set of the library" % n,
			"theme": "Town", "year": 1980, "parts": 200, "file": "library/omr/%d-1.mpd" % n,
			"cover": "library/covers/%d-1.webp" % n, "author": "A modeller", "licence": "cc-by-2.0"})
	var bytes: PackedByteArray = JSON.stringify({"models": models}).to_utf8_buffer()
	began = Time.get_ticks_usec()
	var here := JSON.new()
	here.parse(bytes.get_string_from_utf8())
	var here_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	var longest: Array = [0.0]
	var frame_at: Array = [Time.get_ticks_usec()]
	var frames: Array = [0]
	var timing: Callable = func() -> void:
		var now: int = Time.get_ticks_usec()
		longest[0] = maxf(longest[0], (now - int(frame_at[0])) / 1000.0)
		frame_at[0] = now
		frames[0] += 1
	process_frame.connect(timing)
	frame_at[0] = Time.get_ticks_usec()
	var read: Variant = await ModelLibrary.json_off_frame(bytes)
	process_frame.disconnect(timing)
	_check("%d KB read whole off the frame (%d models), %d frames meanwhile, the longest %.1f ms; on the main thread "
		% [bytes.size() / 1024, (read as Dictionary).get("models", []).size() if read is Dictionary else -1, frames[0],
		longest[0]] + "it was one frame of %.1f ms" % here_ms,
		read is Dictionary and (read as Dictionary)["models"].size() == 2400 and frames[0] >= 1)
	_check("bytes that are not JSON read as null",
		await ModelLibrary.json_off_frame("<html>not found</html>".to_utf8_buffer()) == null)
	_done()


func _done() -> void:
	if _server > 0:
		OS.kill(_server)
	print("")
	if _failures == 0:
		print("A set's page opens the set to build at its first step, or as a credited copy to make your own")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
