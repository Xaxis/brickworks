## Does every slow thing say so at once, and keep the window alive?
##
##   godot --path . --resolution 1400x900 --script src/dev/progress_probe.gd
##
## The owner pressed Timeline on a big model and the studio sat frozen with
## nothing on screen to say why (2026-10-12). Every slow thing now reports
## to one bar in the status bar (Working). This drives the real scene with
## Orthanc (9,429 parts) open, and checks, for each:
##
##   - the bar is up in the very frame the thing was pressed, before any of
##     the slow work has been done (the work starts the frame after);
##   - while Timeline works out the steps, no frame is over BUDGET_MS, the
##     count goes up, and the steps come out the same as Instructions.plan's;
##   - Cancel, and Timeline pressed again, both stop it and leave no bar
##     and no timeline;
##   - deleting all of it and undoing that say so first;
##   - the booklet of the example car counts its pictures, can be stopped,
##     and is gone from the bar when it is written.
##
## Frames are timed as freeze_probe times them, from one frame to the next,
## drawing included. On a machine drawing in software they are said and not
## judged. tools/web/progress_check.mjs is the same in a browser.
extends SceneTree

const BUDGET_MS := 200.0

var _failures: int = 0
var _last_us: int = 0
var _gaps: Array = []   ## [end in usec, ms]
var _software: bool = false


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_gaps.append([now, (now - _last_us) / 1000.0])
	_last_us = now
	return false


func _worst_since(from: int) -> float:
	var worst: float = 0.0
	for gap: Array in _gaps:
		if int(gap[0]) - int(float(gap[1]) * 1000.0) >= from:
			worst = maxf(worst, float(gap[1]))
	return worst


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Until nothing is being worked on, at most [param seconds]. The most a
## job counted to, and what it said along the way.
func _while_busy(seconds: float) -> Dictionary:
	var counted: int = 0
	var words: Dictionary = {}
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Working.is_busy() and Time.get_ticks_msec() < until:
		var job: Working.Job = Working.current()
		counted = maxi(counted, job.done)
		words[job.words] = true
		await process_frame
	return {"counted": counted, "words": words.keys()}


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var adapter: String = RenderingServer.get_video_adapter_name().to_lower()
	_software = adapter.contains("llvmpipe") or adapter.contains("lavapipe") \
		or adapter.contains("swiftshader")
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await _frames(120)
	var playback: BuildPlayback = main.get("_playback")
	playback.stop()
	var world: BrickWorld = main.get("_world")
	var library: PartLibrary = main.get("_library")
	var shell: Shell = main.get("_shell")
	var steps: StepsBar = main.get("_steps")
	var store: ModelStore = main.get("_store")
	_check("the status bar has the bar in it", Working.shown_in != null
		and Working.shown_in.is_inside_tree())

	# Opened as Open's menu opens an example: a slice at a time, counted.
	var bar: ModelBar = main.get("_bar")
	var opened_at: int = Time.get_ticks_usec()
	var counted_open: Array[int] = [0]
	var open_watch := func() -> void:
		var now: Working.Job = Working.current()
		if now != null and now.words.begins_with("Putting down"):
			counted_open[0] = maxi(counted_open[0], now.done)
	process_frame.connect(open_watch)
	var placed: int = await bar.open_with_progress("res://models/orthanc.ldr")
	process_frame.disconnect(open_watch)
	main.call("_lay_baseplate")
	await _frames(30)
	_check("Orthanc is open a slice at a time: %d parts, counted up to %d as they went down, the longest frame %.0f ms%s"
		% [placed, counted_open[0], _worst_since(opened_at),
			", in software, so not judged" if _software else ""],
		placed > 9000 and counted_open[0] > 0 and not Working.is_busy()
		and (_software or _worst_since(opened_at) <= BUDGET_MS * 2.0))

	# -- Timeline --------------------------------------------------------
	# B, as a person presses it: a key is handled before its frame's
	# processing, which is where starting the work at the next process_frame
	# went wrong — that is the same frame, not yet drawn.
	var began: int = Time.get_ticks_usec()
	_key(KEY_B)
	var job: Working.Job = null
	for _n: int in 10:
		await process_frame
		job = Working.current()
		if job != null:
			break
	var drawn: int = Engine.get_frames_drawn()
	_check("B puts the bar up in the frame it is pressed: \"%s\""
		% (job.line() if job != null else ""), job != null and not steps.visible
		and Working.shown_in.visible and job.done == 0 and Instructions.laps.is_empty())
	_check("...with Cancel", job != null and job.can_cancel)
	await process_frame
	_check("...and the bar is drawn before any of the work is done",
		job != null and Engine.get_frames_drawn() > drawn and job.done == 0
		and Instructions.laps.is_empty())
	var seen: Dictionary = await _while_busy(180.0)
	var took: float = (Time.get_ticks_usec() - began) / 1000.0
	var worst: float = _worst_since(began)
	_check("the steps are worked out in %.1f s, the longest frame %.0f ms (budget %.0f)%s; it said %s"
		% [took / 1000.0, worst, BUDGET_MS, ", in software, so not judged" if _software else "",
			", then ".join(PackedStringArray(seen["words"]))],
		steps.visible and (_software or worst <= BUDGET_MS))
	_check("...counting as it went (up to %d)" % int(seen["counted"]), int(seen["counted"]) > 1000)
	_check("...and the bar is gone once the timeline is up", not Working.is_busy())
	var laps: PackedStringArray = PackedStringArray(Instructions.laps.map(
		func(lap: Array) -> String: return "%s %d" % [lap[0], int(lap[1])]))
	print("    (ms: %s)" % ", ".join(laps))
	var plain: Array[Instructions.Step] = Instructions.plan(world, library, store.scenery)
	var at: Vector2i = steps.timeline_at()
	_check("the same %d steps as Instructions.plan, the timeline at %d of %d"
		% [plain.size(), at.x, at.y], plain.size() == steps._steps.size()
		and _same_order(plain, steps._steps))
	steps.stop()
	await _frames(5)

	# Cancelled with the bar's Cancel, and with Timeline pressed again.
	shell.run("timeline")
	await _frames(8)
	job = Working.current()
	if job != null:
		job.cancel()
	await _while_busy(30.0)
	await _frames(3)
	_check("Cancel stops it: no timeline, no bar", job != null and not steps.visible
		and not steps.is_starting() and not Working.is_busy())
	shell.run("timeline")
	await _frames(8)
	shell.run("timeline")
	await _while_busy(30.0)
	await _frames(3)
	_check("Timeline pressed again while it works stops it too", not steps.visible
		and not steps.is_starting() and not Working.is_busy())

	# -- a change to all of it -------------------------------------------
	var verbs: EditVerbs = main.get("_verbs")
	var builder: Builder = main.get("_builder")
	verbs.select_by("all")
	var selected: int = builder.selection.size()
	var standing: int = world.brick_count()
	verbs.press("delete")
	_check("Delete of %d parts puts the bar up first: \"%s\"" % [selected,
		Working.current().line() if Working.is_busy() else ""],
		Working.is_busy() and world.brick_count() == standing)
	await _while_busy(60.0)
	_check("...takes them off, and the bar goes: %d left" % world.brick_count(),
		world.brick_count() < standing - 9000 and not Working.is_busy())
	verbs.press("undo")
	_check("Undo of it says so first too: \"%s\"" % [
		Working.current().line() if Working.is_busy() else ""], Working.is_busy())
	await _while_busy(60.0)
	_check("...puts them back, and the bar goes: %d" % world.brick_count(),
		world.brick_count() == standing and not Working.is_busy())

	# -- the booklet of the example car ----------------------------------
	main.call("_open", "res://models/car.ldr")
	main.call("_lay_baseplate")
	await _frames(30)
	BookletMaker.open_when_written = false
	# Into the checkout's shots, never the person's own folder.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/progress_probe"))
	var path: String = "res://shots/progress_probe/booklet.html"
	var counts: Dictionary = {}
	var watcher := func() -> void:
		var now: Working.Job = Working.current()
		if now != null and now.total > 0:
			counts[now.words] = maxi(int(counts.get(now.words, 0)), now.done)
	process_frame.connect(watcher)
	began = Time.get_ticks_usec()
	var note: String = await main.call("_export_booklet", path)
	process_frame.disconnect(watcher)
	var booklet_worst: float = _worst_since(began)
	_check("the car's booklet: %s, counted %s, the longest frame %.0f ms" % [note,
		JSON.stringify(counts), booklet_worst], note.begins_with("wrote ")
		and counts.has("Drawing the steps…") and not Working.is_busy())
	# And stopped part way.
	var stopper := func() -> void:
		var now: Working.Job = Working.current()
		if now != null and now.words.begins_with("Drawing"):
			now.cancel()
	process_frame.connect(stopper)
	note = await main.call("_export_booklet", path)
	process_frame.disconnect(stopper)
	_check("...and Cancel stops it part way: %s" % note,
		note == "stopped drawing the booklet" and not Working.is_busy())

	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "every slow thing said so at once and kept the window alive")
	quit(1 if _failures else 0)


## A key pressed and let go, as the window would hand it over.
func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		Input.parse_input_event(key)


## Whether two plans put the same bricks in the same steps.
func _same_order(a: Array[Instructions.Step], b: Array[Instructions.Step]) -> bool:
	if a.size() != b.size():
		return false
	for n: int in a.size():
		if a[n].brick_ids != b[n].brick_ids:
			return false
	return true


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
