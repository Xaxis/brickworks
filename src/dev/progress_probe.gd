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
##   - and no frame's own work in the sub-assembly search is over
##     OWN_BUDGET_MS, judged in software too: the scripts' part of a frame,
##     from its start to its drawing, which a slow drawing does not stretch.
##     The search was one frame of 410 ms on Orthanc (2026-10-15);
##   - Cancel, and Timeline pressed again, both stop it and leave no bar
##     and no timeline;
##   - deleting all of it and undoing that say so first;
##   - Check stability and Everything connected, commands that go on after
##     they return (coroutines), run as their menu items run them
##     (Shell.run), and Everything connected as the properties panel's
##     button hands it over (Shell.attend): the bar up every frame until
##     their work is done and gone after, the cost Working.attend keeps for
##     them timed to that end, and no "async function without await" from
##     the engine, which a debug build printed for every one while
##     Working.attend still waited on them as Godot 3 did;
##   - the booklet of the example car counts its pictures, can be stopped,
##     and is gone from the bar when it is written.
##
## Frames are timed as freeze_probe times them, from one frame to the next,
## drawing included. On a machine drawing in software they are said and not
## judged. tools/web/progress_check.mjs is the same in a browser.
extends SceneTree

const BUDGET_MS := 200.0
## A frame's own work, drawing aside: on the desktop, against 250 ms in a
## browser (tools/web/progress_check.mjs), whose scripts are slower.
const OWN_BUDGET_MS := 100.0

var _failures: int = 0
var _last_us: int = 0
var _gaps: Array = []   ## [end in usec, ms]
## Each frame's own work, from process_frame to the drawing:
## [end in usec, ms, the bar's words as the frame ended].
var _own: Array = []
var _own_from: int = 0
var _software: bool = false
var _errors := _Errors.new()


## What the engine prints as an error, kept to be read: a script error in a
## debug build is printed and the run goes on.
class _Errors extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		lines.append("%s %s (%s:%d, %s)" % [code, rationale, file, line, function])
		_lock.unlock()

	func since(from: int) -> PackedStringArray:
		_lock.lock()
		var said: PackedStringArray = lines.slice(from)
		_lock.unlock()
		return said


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


func _process(_delta: float) -> bool:
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_gaps.append([now, (now - _last_us) / 1000.0])
	_last_us = now
	return false


## The longest frame of its own since [param from] while the bar said
## [param words], and the longest for each thing it said.
func _own_worst_since(from: int) -> Dictionary:
	var worst: Dictionary = {}
	for frame: Array in _own:
		if int(frame[0]) - int(float(frame[1]) * 1000.0) < from:
			continue
		var said: String = str(frame[2])
		worst[said] = maxf(float(worst.get(said, 0.0)), float(frame[1]))
	return worst


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
	# First of what runs in a frame: connected before any coroutine waits
	# on it, so what they do when they wake is counted.
	process_frame.connect(func() -> void: _own_from = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func() -> void:
		if _own_from > 0:
			var now: int = Time.get_ticks_usec()
			_own.append([now, (now - _own_from) / 1000.0,
				Working.current().words if Working.is_busy() else ""])
		_own_from = 0)
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

	# Opened as Open's menu opens an example: the bar up and drawn before
	# the one long frame the open is.
	var bar: ModelBar = main.get("_bar")
	var drawn_before: Array[int] = [-1]
	var parts_then: Array[int] = [-1]
	var open_watch := func() -> void:
		var now: Working.Job = Working.current()
		if now != null and now.words.begins_with("Opening") and drawn_before[0] < 0:
			drawn_before[0] = Engine.get_frames_drawn()
			parts_then[0] = world.brick_count()
	process_frame.connect(open_watch)
	var drawn_at_press: int = Engine.get_frames_drawn()
	var placed: int = await bar.open_with_progress("res://models/orthanc.ldr")
	process_frame.disconnect(open_watch)
	main.call("_lay_baseplate")
	await _frames(30)
	_check("Open's list says \"Opening orthanc.ldr…\" before it opens (%d parts then), and it opens: %d parts"
		% [parts_then[0], placed], placed > 9000 and drawn_before[0] >= drawn_at_press
		and parts_then[0] < 1000 and not Working.is_busy())
	# The status bar weighs it as a person reads it. The tower the home page
	# and the gallery show said "8 weak joints (overloaded)" once collision
	# covers took the parts' shapes: its door's arch stood on a 1 x 1 each side.
	var status: Label = main.get("_counts")
	var weighed: String = ""
	for _n: int in 2400:
		await process_frame
		if not bool(main.get("_weighing")) \
				and int(main.get("_stability_revision")) == world.revision \
				and (status.text.contains("stands up") or status.text.contains("weak joint")):
			weighed = status.text
			break
	_check("...and its status bar says it stands, with no weak joint: \"%s\"" % weighed,
		weighed.contains("stands up") and not weighed.contains("weak joint"))

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
	var own: Dictionary = _own_worst_since(began)
	var each := PackedStringArray()
	for said: String in own:
		each.append("%s %.0f" % [said if not said.is_empty() else "(the bar gone)", float(own[said])])
	print("    (each thing's longest frame of its own, ms: %s)" % ", ".join(each))
	var search: float = float(own.get("Finding what is built on the side…", -1.0))
	_check("...and the sub-assembly search's longest frame of its own %.0f ms (budget %.0f)"
		% [search, OWN_BUDGET_MS], search >= 0.0 and search <= OWN_BUDGET_MS)
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

	# -- commands that go on after they return ---------------------------
	# Tools, Check stability: the joints, then the balance weighed on a
	# worker over many frames. Said first (Shell.SLOW_FROM).
	shell.balance_shown = null
	await _goes_on(shell, "stability", func() -> bool: return shell.balance_shown != null)
	# Select by, Everything connected, from one part, followed a slice at a
	# time: on the station, since on Orthanc in a window drawn in software
	# every slice is a frame of over a second, and it takes minutes.
	main.call("_open", "res://models/station.ldr")
	main.call("_lay_baseplate")
	await _frames(30)
	var first_part: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id):
			first_part = brick.id
			break
	# Done when it selects what it found.
	var selected_again: Array[bool] = [false]
	var mark: Callable = func(_count: int) -> void: selected_again[0] = true
	# As its menu item runs it, and as the properties panel's button hands
	# the coroutine itself straight to Working.attend.
	for work: Callable in [Callable(), verbs.select_connected]:
		builder.selection.clear()
		builder.selection[first_part] = true
		builder.selection_changed.emit(1)
		await _frames(3)
		selected_again[0] = false
		builder.selection_changed.connect(mark)
		await _goes_on(shell, "select_connected", func() -> bool: return selected_again[0], work)
		builder.selection_changed.disconnect(mark)
		print("    (%d of %d parts selected)" % [builder.selection.size(), world.brick_count()])
	verbs.select_by("none")
	await _frames(3)

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


## Command [param name], a coroutine, run as its menu item runs it
## (Shell.run), or as a button hands its own [param work] over
## (Shell.attend), watched a frame at a time until [param done] says its
## work is done: the bar up every one of those frames and gone after, the
## cost Working.attend keeps for it at least as long as the work was seen
## going, and nothing from the engine about calling it without await.
##
## The work was seen going from when it had surely begun — at once, or for
## one said first (its words on the bar, Shell.doing), the first frame
## another job of its own was up — to the last frame before it was done.
func _goes_on(shell: Shell, name: String, done: Callable, work: Callable = Callable(),
		seconds: float = 120.0) -> void:
	var errors_from: int = _errors.lines.size()
	var parts: int = shell.work_size(name)
	# Only this run's cost, whatever ran under this name before.
	Working.costs.clear()
	var ran: bool = true
	if work.is_valid():
		shell.attend(name, work)
	else:
		ran = shell.run(name)
	var now: int = Time.get_ticks_usec()
	var said: Working.Job = Working.current() if Working.is_busy() \
		and Working.current().words == shell.doing(name) else null
	var begun_at: int = now if said == null else -1
	var going_at: int = now
	var frames: int = 0
	var bare: int = 0
	var finished: bool = false
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while ran and Time.get_ticks_msec() < until:
		await process_frame
		now = Time.get_ticks_usec()
		if bool(done.call()):
			finished = true
			break
		frames += 1
		going_at = now
		if begun_at < 0 and Working.is_busy() and Working.current() != said:
			begun_at = now
		if not (Working.is_busy() and Working.shown_in.visible):
			bare += 1
	var gone: bool = false
	for _n: int in 10:
		await process_frame
		if not Working.is_busy():
			gone = true
			break
	var seen_ms: float = (going_at - begun_at) / 1000.0 if begun_at >= 0 else -1.0
	var kept_ms: float = Working.expected_ms(name, parts)
	var unawaited: PackedStringArray = PackedStringArray(Array(_errors.since(errors_from)).filter(
		func(line: String) -> bool: return line.contains("async function")))
	_check("%s through %s%s: its work done after %d frames, the bar up in %d of them"
		% [name, "Shell.attend" if work.is_valid() else "Shell.run",
			" (said first)" if said != null else "", frames, frames - bare],
		ran and finished and frames > 0 and bare == 0)
	_check("...and gone once it was", gone)
	_check("...its cost timed to the end: %.0f ms kept, its work seen going %.0f ms"
		% [kept_ms, seen_ms], (seen_ms > 0.0 and kept_ms >= seen_ms)
			# Said first and done in the next frame: no frame saw it going,
			# and what it kept is all there is to read (select_connected on
			# a device that had not timed it, now said first by its size).
			or (said != null and frames <= 1 and kept_ms > 0.0))
	_check("...and no \"async function without await\" from the engine%s"
		% ("" if unawaited.is_empty() else ": " + unawaited[0]), unawaited.is_empty())


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
