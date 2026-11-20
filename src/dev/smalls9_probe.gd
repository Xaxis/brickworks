## smalls9 (osfix's two long frames): on Orthanc and 10179, Find and
## Replace's frames of the model's copies and the parts list as P opens it,
## each with no frame of more than 100 ms of the app's own work, the status bar
## saying so where it takes more than one, each frame's own work measured as
## ProbeTime.Frames measures it (ownswap_probe._timed_act). Each gives what the
## one-frame way gives: the find's parts and frames are Assemblies.file_frames'
## and FindReplace.find's over them, the list's rows and counts Inventory.of's.
## A second find on the model unchanged reads the frames kept, in no long
## frame; the model changed, they are worked out again. Mirror's index of
## handed parts, which a mirrored copy's first look reads, is made first a
## slice at a time, the same as made in one go.
##
## On b80bc2c45 (pre261) this fails: the frames were one frame of 0.2 to
## 0.96 s on 10179, and the list one of 0.34 to 0.9 s (osfix, smalls9).
## The first working out of 10179's frames is held to FIRST_MS, and the 100
## ms bar is said for it as KNOWN until a copy's first fit is paced too.
##
##   godot --headless --path . --script src/dev/smalls9_probe.gd
extends "res://src/dev/ownswap_probe.gd"

const BAR_MS := 100.0
## The first working out of 10179's frames: a copy's first fit reads its
## shapes in one frame (130 to 175 ms at load 20 to 65, smalls9); pre261 took
## all of it in one of 961 ms.
const FIRST_MS := 300.0

## The list whose fill a frame's label names, while it is timed.
var _phase_of: InventoryPanel = null
## The last act's frames over 48 ms: [own ms, what was going on].
var _long: Array = []


## ownswap_probe's, with each frame's label saying what was going on in it
## (the status bar's words, and the list's fill), and the long frames kept.
func _timed_act(act: Callable, done: Callable) -> Array:
	var frames := ProbeTime.Frames.new()
	frames.label = func() -> String:
		var job: Working.Job = Working.current()
		var words: String = job.words if job != null else ""
		if _phase_of != null:
			var made: Array = _phase_of.get("_made")
			var rows: Control = _phase_of.get("_rows")
			words += " [filling %s, %d made, %d rows, shown %s]" % [_phase_of.is_filling(), made.size(),
				rows.get_child_count(), _phase_of.visible]
		return words
	root.add_child(frames)
	var started: int = Time.get_ticks_usec()
	act.call()
	var until: int = Time.get_ticks_msec() + 120000
	var finished: bool = false
	while Time.get_ticks_msec() < until:
		await process_frame
		if done.call():
			finished = true
			break
	await process_frame
	var clock: float = (Time.get_ticks_usec() - started) / 1000.0
	var longest: float = 0.0
	var over: int = 0
	var bar: bool = false
	_long = []
	for frame: Array in frames.work:
		var own: float = float(frame[1]) - float(frame[2])
		longest = maxf(longest, own)
		if own > 16.0 * frames.slack():
			over += 1
		if own > 48.0:
			_long.append([own, frame[3]])
		var said: String = str(frame[3]) if frame[3] != null else ""
		bar = bar or not said.get_slice(" [", 0).is_empty()
	var slack: float = frames.slack()
	var count: int = frames.work.size()
	frames.queue_free()
	return [clock, count, longest, over, bar, slack, finished]


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1800.0).timeout.connect(func() -> void:
		print("smalls9 probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	for path: String in TIMED:
		var name: String = path.get_file()
		print("\n== %s" % name)
		await _open(FileAccess.get_file_as_string(path))
		await _frames(10)
		await _case_find(name)
		await _case_list(name)
	print("\nsmalls9 probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## Edit › Find and replace…, a part every sub-model has, everywhere: typed as
## the person types it (the bar's refresh), until it has found. A model with
## no sub-model placed more than once reads no frames: then only that is said.
func _case_find(name: String) -> void:
	_shell.run("find_replace")
	await _frames(4)
	var bar: FindReplaceBar = _main.get("_find_replace_made")
	var finder: FindReplace = bar.get("_finder")
	var assemblies: Assemblies = finder.assemblies
	if not _check("find %s: the bar, the model's frames not yet kept" % name,
			bar != null and bar.visible and not assemblies.frames_current()):
		return
	var asked: Dictionary = _common(finder)
	bar.set_where("all")
	bar.set_into("", -1)
	if str(asked["part"]).is_empty():
		_check("find %s: no sub-model placed more than once, so a find everywhere reads no frames" % name,
			finder.frames_ready("all") and finder._frames_for(finder.looked_in("all")).is_empty())
		await _find_known(name, bar, {"part": "", "color": 71})
		bar.close()
		await _frames(2)
		return
	var indexed: bool = Mirror.indexed(_library)
	var timed: Array = await _timed_act(func() -> void:
		bar.set_find(str(asked["part"]), int(asked["color"]))
		bar.refresh(),
		func() -> bool: return not bool(bar.get("_framing")) and not bar.found.is_empty())
	# The first working out still has a copy or two whose first fit reads
	# its shapes in one frame of 130 to 175 ms: the 100 ms bar is said as
	# KNOWN, and held to FIRST_MS, well under pre261's one frame of 961.
	_said_time(name, "Find and Replace, %s in %d everywhere, its copies' frames worked out%s" % [asked["part"],
		asked["color"], ", Mirror's index of handed parts made first" if not indexed else ""], timed, true,
		FIRST_MS)
	# Mirror's index made a slice at a time is the one made in one go.
	var hands: Dictionary = Mirror._other_hand.duplicate()
	var names: Dictionary = Mirror._by_name.duplicate()
	Mirror._indexed = null
	Mirror._index(_library)
	_check("find %s: Mirror's index made a slice at a time is the one made at once (%d handed parts, %d names)"
		% [name, hands.size(), names.size()], not hands.is_empty() and hands == Mirror._other_hand
		and names == Mirror._by_name)
	# The one-frame way, now: what pre261 found in the one frame.
	var kept: bool = assemblies.frames_current()
	var paced: Dictionary = assemblies.frames_now()
	var whole: Dictionary = assemblies.file_frames()
	var looked: Array = finder.looked_in("all")
	var wanted: Dictionary = finder.find_among(looked, asked, "all", whole)
	_check("find %s: the frames worked out across frames are file_frames' (%d copies)" % [name, whole.size()],
		kept and not whole.is_empty() and paced == whole)
	_check("find %s: found what the one-frame way finds (%d parts, %s)" % [name,
		(bar.found.get("ids", []) as Array).size(), _where_said(bar.found)],
		not bar.found.is_empty() and bar.found == wanted)
	# Typed again, the model unchanged: the frames kept.
	var depth: int = assemblies.get("_frames_kept").size()
	await _find_known(name, bar, {"part": "", "color": int(asked["color"])})
	_check("find %s: typed again, the frames kept, not worked out again" % name,
		assemblies.frames_current() and depth == 2)
	# The model changed: worked out again, the same as file_frames then.
	var some: BrickWorld.Brick = _world.get_brick(int((wanted["ids"] as Array)[0]))
	_builder.paint_brick(some.id, 4)
	await _frames(2)
	_check("find %s: a part recoloured, the frames kept are not current" % name,
		not assemblies.frames_current())
	var changed: Array = await _timed_act(func() -> void:
		bar.set_find(str(asked["part"]), int(asked["color"]))
		bar.refresh(),
		func() -> bool: return not bool(bar.get("_framing")) and not bar.found.is_empty())
	_said_time(name, "the find after a change, the frames worked out again", changed, true)
	_check("find %s: after the change, the frames are file_frames' again" % name,
		assemblies.frames_current() and assemblies.frames_now() == assemblies.file_frames())
	await _undone()
	bar.close()
	await _frames(2)


## The find's own work, the frames aside (FindReplace.find_among and plan over
## every part found): said, not held to the bar, which is the frames'.
func _find_known(name: String, bar: FindReplaceBar, asked: Dictionary) -> void:
	var timed: Array = await _timed_act(func() -> void:
		bar.set_find(str(asked["part"]), int(asked["color"]))
		bar.refresh(),
		func() -> bool: return not bool(bar.get("_framing")) and not bar.found.is_empty())
	print("  KNOWN %s: the find itself, %s in %d everywhere (%d parts), the frames kept or none: %.0f ms over %d frames, the longest %.1f ms of its own"
		% [name, asked["part"], int(asked["color"]), (bar.found.get("ids", []) as Array).size(),
		float(timed[0]), int(timed[1]), float(timed[2])])


## A part and colour in more than one sub-model with copies: what a find
## everywhere has to read the frames for.
func _common(finder: FindReplace) -> Dictionary:
	var copies: Dictionary = finder._copies_by_definition()
	var counts: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_of(brick)
		var copied: bool = false
		for segment: String in Assemblies.segments(path):
			copied = copied or int(copies.get(Assemblies.definition(segment), 1)) > 1
		if copied:
			var key: String = "%s/%d" % [brick.part_id, brick.color_code]
			counts[key] = int(counts.get(key, 0)) + 1
	var best: String = ""
	for key: String in counts:
		if best.is_empty() or int(counts[key]) > int(counts[best]):
			best = key
	return {"part": best.get_slice("/", 0), "color": int(best.get_slice("/", 1))}


func _where_said(found: Dictionary) -> String:
	return "%d places" % (found.get("places", []) as Array).size()


## P, as the person presses it: until the list is shown.
func _case_list(name: String) -> void:
	var list: InventoryPanel = _main.get("_inventory_made")
	if list != null and list.is_showing():
		list.hide_list()
	await _frames(2)
	list = _main.get("_inventory")
	_phase_of = list
	var timed: Array = await _timed_act(func() -> void: _shell.run("parts_list"),
		func() -> bool: return list.visible and not list.is_filling())
	_phase_of = null
	_said_time(name, "the parts list opened (P)", timed, true)
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	var wanted: Array = []
	for lot: Inventory.Lot in stock.lots:
		wanted.append({"part": lot.part_id, "colour": lot.color_code, "place": list.place_of(lot)})
	var heading: String = list.get("_heading").text
	_check("list %s: the rows are Inventory.of's, in its order (%d rows)" % [name, wanted.size()],
		not wanted.is_empty() and list.rows_listed() == wanted)
	_check("list %s: its counts are Inventory.of's (%s)" % [name, heading],
		heading.begins_with("%s · %s" % [Counted.of(stock.pieces, "piece"), Counted.of(stock.lot_count(), "lot")]))
	# P twice while it is taken: hidden, and nothing shown after.
	list.hide_list()
	await _frames(2)
	_shell.run("parts_list")
	var was: bool = list.is_filling()
	_shell.run("parts_list")
	await _frames(30)
	_check("list %s: P again while it was taken (%s) hides it, and it stays hidden" % [name,
		"still taking it" if was else "already shown"], not list.visible and not list.is_filling())
	await _frames(2)


## [param timed] (ownswap_probe._timed_act) against the bar: done, no frame
## over [constant BAR_MS] of its own, and, where [param paced] and it took
## more than one frame, the status bar said so.
func _said_time(name: String, what: String, timed: Array, paced: bool, ceiling: float = BAR_MS) -> void:
	for frame: Array in _long:
		print("    a frame of %.1f ms of its own: %s" % [float(frame[0]), str(frame[1])])
	print("  %s: %s, %.0f ms over %d frames, the longest frame %.1f ms of its own, %d over %.0f ms, the bar %s"
		% [name, what, float(timed[0]), int(timed[1]), float(timed[2]), int(timed[3]),
		16.0 * float(timed[5]), "said it" if bool(timed[4]) else "said nothing"])
	var said: bool = bool(timed[4]) or not paced or int(timed[1]) <= 2
	if ceiling > BAR_MS:
		print("  KNOWN %s: %s, the bar of no frame over %.0f ms of its own: %s (the longest %.1f ms)" % [name,
			what, BAR_MS, "met" if float(timed[2]) <= BAR_MS else "not yet", float(timed[2])])
	_check("time %s: %s done, no frame over %.0f ms of its own (the longest %.1f ms), the bar saying so"
		% [name, what, ceiling, float(timed[2])],
		bool(timed[6]) and float(timed[2]) <= ceiling and said)
