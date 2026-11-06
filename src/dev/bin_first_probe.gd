## The parts bin's first search, typed as a person types it while the
## search's index is still being made, timed frame by frame against the same
## bin's later searches: the index is made off the frames a person watches,
## ahead of need, and a search typed before it is waits without holding one.
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . \
##     --resolution 1400x900 --script src/dev/bin_first_probe.gd
##
## The index (PartSearch, made by PartLibrary._finder) is every part's words,
## sizes, heights, first letters and numbers over the whole catalogue, 1.4 s
## to make on a quiet desktop; it is made on a worker once the bin is filled
## (PartLibrary.prepare_search). A first key typed before that was done waited
## for it on the frame of the key: 2.9-4.5 s at a load past the box's cores
## (mainthread, 2026-11-05). Two sessions of the app, each opened afresh, each
## with the search clicked and a word typed in it, a key every [constant
## KEY_GAP_MS] ms:
##
##   at once  typed as the index is being made: the index dropped and asked
##            for again as the first key comes, as the bin asks once filled
##            and again for a part made in the app, so a box of any speed has
##            the key meet it unmade. Its frames, and its answer when it
##            comes, which must be what the same search lists once
##            everything is ready, never an empty or another list.
##   settled  typed [constant PAUSE_MS] ms after the index is made, as a person
##            looks the window over first.
##
## Then, in the first, the later searches, each typed over the last: what a
## first search's frames are measured against. Each frame is the main
## thread's whole, from one to the next, less its wait for a CPU
## (ProbeTime.Frames.gaps); a first search's longest no more than [constant
## SLACK_MS] past the later searches' longest (three times that at a load
## past the box's cores).
##
## Both with threads, as the desktop and the web build have them, and then
## standing in for a browser without threads: the index made in frames under
## a budget (PartLibrary.index_on_a_worker off), no worker; and its own work in
## each frame, timed between two of the probe's own steps of the frame on
## either side of it, no more than [constant SLACK_MS] past the budget it is
## given (PartLibrary.INDEX_BUDGET_MS, or INDEX_WANTED_MS while a search
## waits; three times the slack at a load past the box's cores).
## In the second, a part made in the app, which lets the index go: it is made
## again ahead of the next search, no search asking (in frames under the same
## budget without threads), where the next key waited for it, and the part's
## name typed lists it first. --only=threads|nothreads runs one; --frames
## says every frame of a search over 30 ms.
extends SceneTree

## Of a first search's frame, the most past the later searches' longest.
const SLACK_MS := 12.0
## Between one key and the next, as a person types: past the bin's debounce
## (PartsBin.SEARCH_DEBOUNCE), so each key is a search.
const KEY_GAP_MS := 180
## How long a person looks the window over before the settled search.
const PAUSE_MS := 3000
## The first search, and the later ones, each typed over the last.
const FIRST := "brick"
const LATER: Array = ["plate 1x2", "3001", "technic pin", "slope"]
## A part made in the app, as a Part Designer part in a Studio file is.
const MADE_ID := "zzbinfirst"
const MADE_PART := """0 Zzbinfirst Probe Plate 1 x 1
0 Name: zzbinfirst.dat
0 !LDRAW_ORG Unofficial_Part
0 !CATEGORY Plate
4 16 10 0 10 -10 0 10 -10 0 -10 10 0 -10
4 16 10 8 10 10 8 -10 -10 8 -10 -10 8 10
"""

var _failures: int = 0
## The index's own work in each frame it was made in, ms, less the main
## thread's wait for a CPU; and where the frame's step before it began.
var _shares: Array[float] = []
var _share_from: Array = []
var _frames: ProbeTime.Frames
var _phase: String = ""
var _nothreads: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for threads: bool in [true, false]:
		if not only.is_empty() and only != ("threads" if threads else "nothreads"):
			continue
		_nothreads = not threads
		print("\n-- %s" % ("with threads" if threads else "standing in for a browser without threads"))
		var warm: Array = await _session(true)
		await _session(false, warm)
	print("")
	print("bin_first: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _wait(count: int) -> void:
	for _n: int in count:
		await process_frame


func _wait_ms(ms: int) -> void:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < ms:
		await process_frame


## The app opened afresh and its first search typed: [param at_once] as the
## index is being made, then the later searches, whose longest frame, [own
## ms, wait], is given back; else [constant PAUSE_MS] after the index is
## made, measured against [param warm].
func _session(at_once: bool, warm: Array = []) -> Array:
	print("\nthe bin's first search, typed %s" % (
		"as the index is being made" if at_once else "%d ms after the index is made" % PAUSE_MS))
	_frames = ProbeTime.Frames.new()
	_frames.label = func() -> String: return _phase
	root.add_child(_frames)
	_phase = "opening"
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	var library: PartLibrary = main.get("_library")
	var bin: PartsBin = main.get("_bin")
	var since: int = Time.get_ticks_msec()
	while bin._offerable == 0 and Time.get_ticks_msec() - since < 60000:
		await process_frame
	_check("the bin is filled (%d parts)" % bin._offerable, bin._offerable > 0)
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	await _wait(2)
	var stand_in: bool = _nothreads and "index_on_a_worker" in library
	if _nothreads and not stand_in:
		print("  (no index_on_a_worker in this build: nothing makes the index ahead where there are no threads, and the first search makes it on its key's frame)")
	if at_once:
		# Past the start, and the search clicked: then the index asked for
		# again, unmade, as the first key comes.
		since = Time.get_ticks_msec()
		while not _made(library) and Time.get_ticks_msec() - since < 60000:
			await process_frame
		await _click(bin._search.get_global_rect().get_center())
		if not bin._search.has_focus():
			bin._search.grab_focus()
		_phase = "first"
		if stand_in:
			library.set("index_on_a_worker", false)
			_bracket(true)
		_remake(library)
		if stand_in:
			_bracket(false)
	else:
		since = Time.get_ticks_msec()
		while not _made(library) and Time.get_ticks_msec() - since < 60000:
			await process_frame
		if stand_in:
			# Past the start, the window quiet: then the index made again in
			# frames, as a browser without threads makes it once the bin is
			# filled.
			_phase = "settling"
			await _wait_ms(2000)
			library.set("index_on_a_worker", false)
			_bracket(true)
			_remake(library)
			_bracket(false)
		_phase = "making"
		since = Time.get_ticks_msec()
		while not _made(library) and Time.get_ticks_msec() - since < 60000:
			await process_frame
		if stand_in:
			_check("the index is made in frames, %d of them in %d ms" % [_count("making"),
				Time.get_ticks_msec() - since], _made(library) and _count("making") > 1)
			_shared(library, "INDEX_BUDGET_MS", "as the window is looked over")
		_phase = "looking"
		await _wait_ms(PAUSE_MS)
		await _click(bin._search.get_global_rect().get_center())
		if not bin._search.has_focus():
			bin._search.grab_focus()
		_phase = "first"
	var unmade: bool = not _made(library)
	print("  the index made as the first key came: %s" % (not unmade))
	if at_once:
		_check("the first key came as the index was being made", unmade)
	var typed: int = Time.get_ticks_msec()
	await _type(FIRST)
	# Its answer: the tiles for what is typed, however long the index takes.
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 60000 and not _answered(bin, FIRST):
		await process_frame
	if stand_in and at_once:
		_shared(library, "INDEX_WANTED_MS", "as the search waits for it")
	var answered: int = Time.get_ticks_msec() - typed
	var shown: PackedStringArray = bin.first_found(40)
	_check("\"%s\" answered, %d ms after its first key (%s ...)" % [FIRST, answered,
		", ".join(shown.slice(0, 6))], _answered(bin, FIRST) and not shown.is_empty())
	await _wait(10)
	_phase = "after"
	await _wait_ms(300)
	var first: Array = _longest("first")
	print("  its frames from the first key: %d, the longest %.1f ms of its own (%.1f waiting for a CPU), %d over 50 ms"
		% [_count("first"), first[0], first[1], _over("first", 50.0)])
	# What the same search lists with everything ready.
	bin._run_search(FIRST)
	await _wait(3)
	var settled: PackedStringArray = bin.first_found(40)
	_check("its tiles are the ones it lists once everything is ready (%d of %d the same, in order)"
		% [_same(shown, settled), settled.size()], shown == settled and not settled.is_empty())
	var most: Array = warm
	if at_once:
		_phase = "later"
		for query: String in LATER:
			await _key(KEY_A, true)
			await _type(query)
			since = Time.get_ticks_msec()
			while Time.get_ticks_msec() - since < 10000 and not _answered(bin, query):
				await process_frame
			await _wait_ms(300)
		most = _longest("later")
		print("  the later searches (%s): %d frames, the longest %.1f ms of its own (%.1f waiting), %d over 50 ms"
			% [", ".join(LATER), _count("later"), most[0], most[1], _over("later", 50.0)])
	if "--frames" in OS.get_cmdline_user_args():
		_said_frames(["first", "later"])
	var bar: float = float(most[0]) + SLACK_MS * _frames.slack()
	_check("the first search's longest frame %.1f ms, against the later searches' %.1f: under %.1f (%s)"
		% [first[0], most[0], bar, ProbeTime.load_said(maxf(_frames.busy, ProbeTime.box_load()))],
		float(first[0]) < bar)
	if not at_once:
		await _made_part(library, bin)
	main.queue_free()
	_frames.queue_free()
	await _wait(10)
	return most


## A part made in the app: the index it lets go of made again with no search
## asking for it (PartLibrary.add_custom), and the part's name typed listing
## it first, as the index made again has it.
func _made_part(library: PartLibrary, bin: PartsBin) -> void:
	print("\na part made in the app")
	_phase = "made part"
	var stand_in: bool = _nothreads and library.get("index_on_a_worker") == false
	if stand_in:
		_bracket(true)
	var added: Dictionary = CustomParts.add(library, MADE_PART, MADE_ID, false)
	var problem: String = str(added.get("problem", ""))
	_check("the part is made (%s)" % (problem if not problem.is_empty() else MADE_ID), problem.is_empty())
	# The index asked for again once the frame's parts are in: the probe's
	# step after it connected after that.
	await _wait(2)
	if stand_in:
		_bracket(false)
	var since: int = Time.get_ticks_msec()
	while not _made(library) and Time.get_ticks_msec() - since < 60000:
		await process_frame
	_check("the index it let go of is made again, no search asking for it (%d ms)"
		% (Time.get_ticks_msec() - since), _made(library) and bin.get("_waiting") != true)
	if stand_in:
		_shared(library, "INDEX_BUDGET_MS", "again after it")
	await _key(KEY_A, true)
	await _type(MADE_ID)
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 10000 and not _answered(bin, MADE_ID):
		await process_frame
	var shown: PackedStringArray = bin.first_found(3)
	_check("its name typed lists it first (%s)" % ", ".join(shown),
		_answered(bin, MADE_ID) and not shown.is_empty() and shown[0] == MADE_ID)


## The probe's own steps of each frame, on either side of the index's
## (PartLibrary._index_frame): [param before] connected before the index
## asks for frames, and the other after. The connection order is the order
## of the calls.
func _bracket(before: bool) -> void:
	if before:
		_shares.clear()
		_share_from = []
		process_frame.connect(_share_begins)
	else:
		process_frame.connect(_share_ends)


func _share_begins() -> void:
	_share_from = [Time.get_ticks_usec(), ProbeTime.waited_ms()]


func _share_ends() -> void:
	if not _share_from.is_empty():
		_shares.append(maxf((Time.get_ticks_usec() - int(_share_from[0])) / 1000.0
			- (ProbeTime.waited_ms() - float(_share_from[1])), 0.0))
		_share_from = []


## The index's share of each frame it was made in, [param what], under the
## budget [param budget] (a PartLibrary constant's name) and the slack; the
## brackets let go.
func _shared(library: PartLibrary, budget: String, what: String) -> void:
	for step: Callable in [_share_begins, _share_ends]:
		if process_frame.is_connected(step):
			process_frame.disconnect(step)
	var most: float = 0.0
	for share: float in _shares:
		most = maxf(most, share)
	var given: float = float(library.get_script().get_script_constant_map().get(budget, 0.0))
	var bar: float = given + SLACK_MS * _frames.slack()
	_check("the index made in frames %s: its own work in a frame %.1f ms at most over %d frames, given %.0f: under %.1f (%s)"
		% [what, most, _shares.size(), given, bar, ProbeTime.load_said(maxf(_frames.busy,
			ProbeTime.box_load()))], not _shares.is_empty() and most < bar)


## The index dropped and asked for again, as the bin asks for it once it is
## filled and again for a part made in the app (PartLibrary.add_custom).
func _remake(library: PartLibrary) -> void:
	if library.has_method("forget_search"):
		library.call("forget_search")
	else:
		var task: int = int(library.get("_preparing"))
		if task >= 0:
			WorkerTasks.collect(task)
			library.set("_preparing", -1)
		library._search_lock.lock()
		library.set("_search_index", null)
		library._search_lock.unlock()
	library.prepare_search()


## Whether the bin lists what [param query] asks: its text, searched, and no
## search of it waiting, nor one on a worker (PartsBin._seek) still to be
## listed. Without the last, the list before the key was read as its answer.
func _answered(bin: PartsBin, query: String) -> bool:
	var seeking: Variant = bin.get("_seeking")
	return bin._search.text == query and not bin._pending and bin.get("_waiting") != true \
		and not (seeking is int and int(seeking) >= 0) and not bin.first_found(1).is_empty()


## Whether the library's index is made, asked without waiting for it.
func _made(library: PartLibrary) -> bool:
	if "index_on_a_worker" in library:
		return library.search_ready()
	if library.get("_index_making") != null:
		return false
	var preparing: int = int(library.get("_preparing"))
	if preparing >= 0 and not WorkerThreadPool.is_task_completed(preparing):
		return false
	return library.get("_search_index") != null


func _same(a: PackedStringArray, b: PackedStringArray) -> int:
	var same: int = 0
	for n: int in mini(a.size(), b.size()):
		if a[n] == b[n]:
			same += 1
	return same


## The frame of [param phase] with the most of the app's own work: [own ms,
## the wait in it].
func _longest(phase: String) -> Array:
	var most: Array = [0.0, 0.0]
	for entry: Array in _frames.gaps:
		if str(entry[3]) != phase:
			continue
		var own: float = maxf(float(entry[1]) - float(entry[2]), 0.0)
		if own > float(most[0]):
			most = [own, float(entry[2])]
	return most


## With --frames: each frame of [param phases] over 30 ms of its own, when it
## ended, its own ms and its wait.
func _said_frames(phases: Array) -> void:
	for entry: Array in _frames.gaps:
		var own: float = float(entry[1]) - float(entry[2])
		if str(entry[3]) in phases and own > 30.0:
			# Of it, the processing up to its drawing (Frames.work).
			var began: int = int(entry[0]) - roundi(float(entry[1]) * 1000.0)
			var worked: float = -1.0
			for work: Array in _frames.work:
				if int(work[0]) > began and int(work[0]) <= int(entry[0]):
					worked = float(work[1]) - float(work[2])
			print("    frame ending at %d ms: %.1f ms of its own, %.1f of it before its drawing, %.1f waiting (%s)" % [
				int(entry[0]) / 1000, own, worked, float(entry[2]), entry[3]])


func _count(phase: String) -> int:
	return _frames.gaps.filter(func(entry: Array) -> bool: return str(entry[3]) == phase).size()


func _over(phase: String, ms: float) -> int:
	return _frames.gaps.filter(func(entry: Array) -> bool:
		return str(entry[3]) == phase and float(entry[1]) - float(entry[2]) > ms).size()


# -- input, as a person sends it ------------------------------------------------


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _wait(2)


func _click(at: Vector2) -> void:
	await _move(at)
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _wait(2)
	await _wait(3)


## [param text] typed a key every [constant KEY_GAP_MS] ms, each pressed and
## let go a frame apart.
func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		var at: int = Time.get_ticks_msec()
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
		while Time.get_ticks_msec() - at < KEY_GAP_MS:
			await process_frame


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _wait(3)
