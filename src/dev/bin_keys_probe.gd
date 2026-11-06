## Every key typed in the parts bin's search draws in a frame's budget: ten
## searches a builder types, a letter at a time, each key's frames timed.
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . \
##     --resolution 1400x900 --script src/dev/bin_keys_probe.gd
##   tools/probe.sh bin_keys_phone_probe     laid out for a phone, 390 x 844
##
## The bin's search runs on each key typed after a pause (PartsBin
## SEARCH_DEBOUNCE), and a person's keys a little apart are each one: here a
## key every [constant KEY_GAP_MS] ms, past it. Each key's frame searched the
## catalogue, freed the 64 tiles shown and made 64, each a button, a box, a
## picture, a label fitted word by word and a star: 67 to 191 ms a key at 1400
## x 900, a first letter's search and fold 50 to 100 of it (bintiles,
## 2026-11-05). At 60 Hz that is 4 to 11 frames of a held window a letter. The
## search is made on a worker now and the tiles kept, each bound to the next
## list's parts (PartsBin._seek, _keep_tiles).
##
## Checked, for each of the ten: every key's longest frame of its own (the
## frames from its press to the next key's, less the main thread's wait for a
## CPU) is under [constant BUDGET_MS] ms, three times that at a load past the
## box's cores (ProbeTime.slack). Each key's longest frame is said in its
## parts: the key's input, if it is in it; its processing up to its drawing (a
## list filled from the worker's search, the layout, the labels shaped, the
## tiles' _draw); the drawing. The first key of the run is a run's first
## search, which bin_first_probe times too.
##
## --parts says each query's search run whole once more, warm, in finer parts
## (the old page let go, the tiles made, laid out, drawn). --said=FILE writes
## what each key's first page shows, tile by tile (its part, its name as it
## reads, its "+N", its star, its picture's state), for a run before a change
## to be put beside one after it. --shots=DIR keeps a picture of the bin after
## each query. --phone, or bin_keys_phone_probe, lays it out for a finger.
extends SceneTree

## A frame's own, ms: two frames at 60 Hz.
const BUDGET_MS := 33.0
## A key every so often, past the bin's debounce: each key is a search.
const KEY_GAP_MS := 180
## Ten searches as a builder types them.
const QUERIES: Array = ["brick 2x4", "slope", "technic beam", "plate 1x2", "tile 2x2",
	"round 1x1", "hinge", "wedge", "panel", "axle"]

var _failures: int = 0
var _phone: bool = false
var _main: Node
var _bin: PartsBin
var _search: LineEdit
var _shots: String = ""
var _said_to: String = ""
var _said: Dictionary = {}
## What each frame is of, as it is drawn: a key ("query|n"), a query's last
## key settling ("query|settle"), or nothing.
var _tag: String = ""
## Each frame, at its end (frame_post_draw): {end, waited, key, input, typed,
## pre} in usec and ms, -1 where the frame had none of it.
var _frames: Array = []
var _sampling: bool = false
## Each frame drawn with tiles missing from the view (_short): its key and how many.
var _shorts := PackedStringArray()
var _began_us: int = 0
var _began_waited: float = 0.0
var _input_us: int = -1
var _typed_us: int = -1
var _pre_us: int = -1


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## "phone" for a script that is this one in a phone's window
## (bin_keys_phone_probe); "" here.
func _finger() -> String:
	return ""


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
		if arg.begins_with("--said="):
			_said_to = arg.trim_prefix("--said=")
	_phone = _finger() != "" or args.has("--phone")
	if _phone:
		Phone._on = 1
		Phone._wide = false
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if DisplayServer.get_name() == "headless":
		print("bin_keys: a window's frames are timed here; run it in one")
		quit(3)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var library: PartLibrary = _main.get("_library")
	_bin = _main.get("_bin")
	_search = _bin.get("_search")
	var since: int = Time.get_ticks_msec()
	while _bin.get("_offerable") == 0 and Time.get_ticks_msec() - since < 60000:
		await process_frame
	_check("the bin is filled (%d parts)" % int(_bin.get("_offerable")), int(_bin.get("_offerable")) > 0)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var size: Vector2i = DisplayServer.window_get_size()
	if _phone:
		var phone: PhoneShell = _main.get("_phone")
		_check("the layout for a finger is made", phone != null)
		if phone == null:
			quit(1)
			return
		(phone.get("_parts") as PhoneShell.Sheet).open("full")
		await _wait_ms(1000)
	else:
		(_main.get("_bin_dock") as SideDock).set_open(true)
		await _wait_ms(int(SideDock.SLIDE_SECONDS * 2000.0))
	since = Time.get_ticks_msec()
	while not library.search_ready() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _settled(20000)
	await _wait_ms(500)
	print("\nthe bin in a %dx%d window%s, %d tiles across; ten searches typed a key every %d ms (%s)"
		% [size.x, size.y, ", laid out for a finger" if _phone else "",
		(_bin.get("_grid") as GridContainer).columns, KEY_GAP_MS,
		ProbeTime.load_said(ProbeTime.box_load())])
	if _phone:
		_search.grab_focus()
	else:
		await _click(_search.get_global_rect().get_center())
		if not _search.has_focus():
			_search.grab_focus()
	_search.gui_input.connect(_on_key_in)
	# After the bin's own: the search and its tiles are made when this hears it.
	_search.text_changed.connect(_on_typed)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_sampling = true
	var worst: Array = []
	for query: String in QUERIES:
		await _key(KEY_A, true)
		await _typed_in(query)
		since = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < 10000 and not _answered(query):
			await process_frame
		_tag = "%s|settle" % query
		await _settled(20000)
		await _wait_ms(200)
		_tag = ""
		worst.append(_said_query(query))
		await _shot(query)
	_sampling = false
	RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	var most: float = 0.0
	for each: float in worst:
		most = maxf(most, each)
	var bar: float = BUDGET_MS * ProbeTime.slack(ProbeTime.box_load())
	print("")
	_check("every key's longest frame of its own, the ten searches: at most %.1f ms, under %.1f (%s)"
		% [most, bar, ProbeTime.load_said(ProbeTime.box_load())], most < bar)
	_check("no frame drawn with tiles missing from the view (%s)" % (", ".join(_shorts.slice(0, 8))
		if not _shorts.is_empty() else "none of %d" % _frames.size()), _shorts.is_empty())
	if args.has("--parts"):
		print("\n  each search run whole once more, warm, in its parts")
		for query: String in QUERIES:
			await _parts_of(query)
	if not _said_to.is_empty():
		var file: FileAccess = FileAccess.open(_said_to, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_said, "  ", false))
			file.close()
			print("    what each key's first page showed: %s" % _said_to)
	_main.queue_free()
	await _wait(5)
	print("")
	print("bin_keys: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## [param query] typed into the search, a key every [constant KEY_GAP_MS] ms,
## each pressed and let go a frame apart; each key's frames under its own
## name, and what its first page showed kept.
func _typed_in(query: String) -> void:
	for n: int in query.length():
		var c: String = query[n]
		var at: int = Time.get_ticks_msec()
		_tag = "%s|%d" % [query, n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
		while Time.get_ticks_msec() - at < KEY_GAP_MS:
			await process_frame
		# Whether its search was listed by then: at a load past the box's cores
		# a search on a worker can take longer than a key, and the page is the
		# last key's until it is.
		_said["%s|%d" % [query, n]] = {"text": _search.text, "answered": _answered(_search.text),
			"tiles": _page()}


## What the first page shows, tile by tile.
func _page() -> Array:
	var out: Array = []
	var grid: GridContainer = _bin.get("_grid")
	for cell: Node in grid.get_children():
		var one: Dictionary = {"part": str(cell.get_meta("part", ""))}
		if cell.has_meta("name_label"):
			one["name"] = (cell.get_meta("name_label") as Label).text
		if cell.has_meta("star"):
			one["star"] = (cell.get_meta("star") as Control).visible
		for child: Node in cell.get_children():
			if child is Button and (child as Button).visible:
				one["badge"] = (child as Button).text
		var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
		if tile is ThumbTile:
			one["colour"] = (tile as ThumbTile).color_code
		if cell is Button:
			one["pressed"] = (cell as Button).button_pressed
			one["tip"] = (cell as Button).tooltip_text
		out.append(one)
	return out


func _on_key_in(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _sampling and key != null and key.pressed and _input_us < 0:
		_input_us = Time.get_ticks_usec()


func _on_typed(_text: String) -> void:
	if _sampling:
		_typed_us = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	if _sampling and _pre_us < 0:
		_pre_us = Time.get_ticks_usec()
		var short: int = _short()
		if short > 0:
			_shorts.append("%s: %d" % [_tag, short])


## The tiles missing from the view as a frame is drawn: rows in sight with
## no tile where the list has parts for them, as a first page made alone left
## the rows under it for a frame.
func _short() -> int:
	var grid: GridContainer = _bin.get("_grid")
	var count: int = grid.get_child_count()
	if count == 0 or not grid.is_visible_in_tree():
		return 0
	var tall: float = (grid.get_child(0) as Control).size.y + float(grid.get_theme_constant("v_separation"))
	if tall <= 1.0:
		return 0
	var scroll: Control = _bin.get("_scroll")
	var rows: int = ceili(maxf(0.0, scroll.get_global_rect().end.y - grid.get_global_rect().position.y)
		/ tall)
	var listed: int = (_bin.get("_display") as Array).size()
	return maxi(0, mini(listed, rows * maxi(grid.columns, 1)) - count)


## A frame ends: kept, with what of its key's work it held.
func _on_post_draw() -> void:
	var now: int = Time.get_ticks_usec()
	var waited: float = ProbeTime.waited_ms()
	if _sampling and _began_us > 0:
		_frames.append({"ms": (now - _began_us) / 1000.0, "waited": waited - _began_waited,
			"key": _tag, "began": _began_us, "input": _input_us, "typed": _typed_us,
			"pre": _pre_us, "end": now})
	_began_us = now
	_began_waited = waited
	_input_us = -1
	_typed_us = -1
	_pre_us = -1


## [param query]'s keys said, each its longest frame of its own and that
## frame in its parts; the longest of them all given back.
func _said_query(query: String) -> float:
	var most: float = 0.0
	var line := PackedStringArray()
	var parts := PackedStringArray()
	for n: int in query.length():
		var tag: String = "%s|%d" % [query, n]
		var longest: Dictionary = {}
		for frame: Dictionary in _frames:
			if str(frame.key) == tag and (longest.is_empty() or _own(frame) > _own(longest)):
				longest = frame
		var own: float = _own(longest) if not longest.is_empty() else 0.0
		most = maxf(most, own)
		line.append("%s %.0f" % [query.substr(0, n + 1).replace(" ", "_"), own])
		parts.append(_parts_said(longest))
	var settle: float = 0.0
	for frame: Dictionary in _frames:
		if str(frame.key) == "%s|settle" % query:
			settle = maxf(settle, _own(frame))
	var grid: GridContainer = _bin.get("_grid")
	print("    \"%s\" (%d tiles): each key's longest frame of its own, ms: %s; its pictures landing %.0f"
		% [query, grid.get_child_count(), ", ".join(line), settle])
	print("        that frame in its parts, ms: %s" % "  ".join(parts))
	return most


## A frame's own, ms: from the last frame's end to its own, less the main
## thread's wait for a CPU (ProbeTime.waited_ms).
func _own(frame: Dictionary) -> float:
	return maxf(float(frame.ms) - float(frame.waited), 0.0)


## [param frame] in its parts: the key's input (the search, a list filled
## there) + its processing to its drawing (a search on a worker listed, the
## layout, the labels shaped, the tiles' _draw) + the drawing; or, a frame
## with no key in it, its processing + its drawing.
func _parts_said(frame: Dictionary) -> String:
	if frame.is_empty() or int(frame.pre) <= 0:
		return "-"
	if int(frame.input) > 0 and int(frame.typed) > 0:
		return "in %.0f+%.0f+%.0f" % [(int(frame.typed) - int(frame.input)) / 1000.0,
			(int(frame.pre) - int(frame.typed)) / 1000.0, (int(frame.end) - int(frame.pre)) / 1000.0]
	return "%.0f+%.0f" % [(int(frame.pre) - int(frame.began)) / 1000.0,
		(int(frame.end) - int(frame.pre)) / 1000.0]


## [param query] run whole, its parts timed on their own: the search, the old
## page let go, the tiles made, then the frame's processing and drawing.
func _parts_of(query: String) -> void:
	_search.set_text(query)
	_bin.set("_pending", false)
	var grid: GridContainer = _bin.get("_grid")
	var span := ProbeTime.Span.new()
	var found: Array = _bin.call("_find", query, _bin.get("_category"))
	var finding: float = span.end().own
	span = ProbeTime.Span.new()
	_bin.call("_run_search", query)
	var run: float = span.end().own
	var marks: Array = [[Time.get_ticks_usec(), ProbeTime.waited_ms()]]
	var drawing: Callable = func() -> void:
		if marks.size() == 1:
			marks.append([Time.get_ticks_usec(), ProbeTime.waited_ms()])
	RenderingServer.frame_pre_draw.connect(drawing)
	await RenderingServer.frame_post_draw
	marks.append([Time.get_ticks_usec(), ProbeTime.waited_ms()])
	RenderingServer.frame_pre_draw.disconnect(drawing)
	var spans: Array = []
	for n: int in range(1, marks.size()):
		spans.append(maxf((int(marks[n][0]) - int(marks[n - 1][0])) / 1000.0
			- (float(marks[n][1]) - float(marks[n - 1][1])), 0.0))
	print("    \"%s\" (%d found, %d tiles): the search %.1f ms, its page made %.1f; then processed %.1f, drawn %.1f"
		% [query, found.size(), grid.get_child_count(), finding, maxf(run - finding, 0.0),
			float(spans[0]) if spans.size() > 1 else 0.0, float(spans[-1])])
	await _settled(20000)


## A picture of the bin as [param query] left it.
func _shot(query: String) -> void:
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	var scroll: Control = _bin.get("_scroll")
	var scale: Vector2 = Vector2(shot.get_size()) / root.get_visible_rect().size
	var area := Rect2i(Vector2i(scroll.get_global_rect().position * scale),
		Vector2i(scroll.get_global_rect().size * scale)).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	DirAccess.make_dir_recursive_absolute(_shots)
	var path: String = _shots.path_join("%s.png" % query.replace(" ", "_"))
	shot.get_region(area).save_png(path)


## Whether the bin lists what [param query] asks: no search of it still on a
## worker (PartsBin._seek), where the bin makes one.
func _answered(query: String) -> bool:
	var seeking: Variant = _bin.get("_seeking")
	return _search.text == query and not bool(_bin.get("_pending")) and _bin.get("_waiting") != true \
		and not (seeking is int and int(seeking) >= 0) and not _bin.first_found(1).is_empty()


## Until every tile in sight has its picture and none is fading in, or
## [param ms] pass: whether they did.
func _settled(ms: int) -> bool:
	var since: int = Time.get_ticks_msec()
	var grid: GridContainer = _bin.get("_grid")
	while Time.get_ticks_msec() - since < ms:
		var waiting: int = 0
		var view: Rect2 = (_bin.get("_scroll") as Control).get_global_rect()
		for cell: Node in grid.get_children():
			var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
			if not tile is ThumbTile or not view.intersects((cell as Control).get_global_rect()):
				continue
			var one: ThumbTile = tile
			if one.state == ThumbTile.State.LOADING or one.is_processing():
				waiting += 1
		if waiting == 0 and grid.get_child_count() > 0:
			return true
		await process_frame
	return false


func _wait(count: int) -> void:
	for _n: int in count:
		await process_frame


func _wait_ms(ms: int) -> void:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < ms:
		await process_frame


# -- input, as a person sends it ------------------------------------------------


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or rect.x <= 0.0:
		return at
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.parse_input_event(move)
	await _wait(2)
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
