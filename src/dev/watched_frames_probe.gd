## The frames a person watches while a part, a shape or a mesh is read for
## the first time, timed against the same frames once it has been: none of
## it is read on the main thread.
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . \
##     --resolution 1400x900 --script src/dev/watched_frames_probe.gd
##
## Each part times the main thread's frames whole, from one to the next, its
## input and its drawing in it (ProbeTime.Frames.gaps: a click's own work is
## in its input, before the frame's processing), less its wait for a CPU, and
## checks the longest of the first time against the longest of the same act
## done again, warm: no more than [constant SLACK_MS] past it (three times
## that at a load past the box's cores). --only=aim|viewer|fetched runs one.
##
##   aim      A part not read yet found in the bin by its number, taken by a
##            click on its tile, the pointer resting on it a moment first,
##            and moved onto the floor by the mouse, as a person does: its
##            search, its tile's picture, the click and the first aims. Three
##            Technic parts of 4,600 to 7,700 triangles, then the first again,
##            warm. The search's tiles' parts were read on the main thread for
##            their pictures, 20 to 30 a frame, and the part taken read its
##            exact shape for its hinges on the click's frame (25-60 ms): what
##            each step read there is counted (PartLibrary.read_here,
##            Exact.read_here) and must be none. The click's and the aims'
##            frames are checked against warm; the search's and the tiles'
##            pictures' are said (warm, nothing is drawn).
##   viewer   8808-1 opened by its link in the viewer, as share_play_probe
##            opens it: what was read on the main thread from the model up
##            until what moves is said, which must be nothing, and the frames
##            that asked for shapes against the same viewer settled. It read 8
##            parts' exact shapes a frame there (Main._play_frame), 30 in all.
##            After aim, the editor's library is checked gone with the
##            editor first: a person's viewer is a run of its own.
##   fetched  The web build's way in for an exact shape, a fetch's answer
##            (PartLibrary._on_fetched_exact), stood in for here: 8808-1's
##            shapes forgotten and their files handed in four a frame, as
##            answers land, on a worker where there are threads and paced in
##            frames where there are none (read_on_a_worker off); then frames
##            with none coming. Each was read on the frame it came in.
extends SceneTree

const SET := "res://vendor/omr/files/8808-1.mpd"
const ID := "W4tch3dFr1"
## Of a cold frame, the most past the warm one's.
const SLACK_MS := 6.0
## Parts the aim takes: none is in the bin's first page or in 8808-1.
const COLD: Array = ["32278", "64179", "41239"]
## How many fetched shapes land in one frame.
const PER_FRAME := 4
## How long the pointer rests on a tile before it is clicked, ms.
const HOVER_MS := 250

var _failures: int = 0
var _main: Node
var _frames: ProbeTime.Frames
var _phase: String = ""
var _library: PartLibrary
## The editor's library, once the editor is gone: let go of with it.
var _editor_library: WeakRef


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "can_write": false, "why_not": "signed out"}}

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}


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
	if only.is_empty() or only == "aim":
		await _aim()
		_check("the editor's part library went with it, before the viewer opens",
			_editor_library.get_ref() == null)
	if only.is_empty() or only in ["viewer", "fetched"]:
		await _viewer(only)
	print("")
	print("watched_frames: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _wait(count: int) -> void:
	for _n: int in count:
		await process_frame


## Frames timed from now, each with what [member _phase] said as it ended.
func _time() -> void:
	if _frames != null:
		_frames.queue_free()
	_frames = ProbeTime.Frames.new()
	_frames.label = func() -> String: return _phase
	root.add_child(_frames)


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


func _count(phase: String) -> int:
	return _frames.gaps.filter(func(entry: Array) -> bool: return str(entry[3]) == phase).size()


## The longest frame of [param cold] against the longest of [param warm]:
## no more than [constant SLACK_MS] past it (three times that at a load past
## the box's cores).
func _against(what: String, cold: String, warm: String) -> void:
	var first: Array = _longest(cold)
	var again: Array = _longest(warm)
	var most: float = float(again[0]) + SLACK_MS * _frames.slack()
	_check("%s: its longest frame %.1f ms of its own (%d frames, %.1f waiting for a CPU), warm %.1f (%d frames); under %.1f (%s)"
		% [what, first[0], _count(cold), first[1], again[0], _count(warm), most,
			ProbeTime.load_said(maxf(_frames.busy, ProbeTime.box_load()))],
		float(first[0]) < most)


# -- a new part, taken from the bin and aimed -----------------------------------


func _aim() -> void:
	print("\na part not read yet, taken from the bin and aimed")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _wait(120)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var library: PartLibrary = _main.get("_library")
	var builder: Builder = _main.get("_builder")
	var camera: CadCamera = _main.get("_camera")
	var bin: PartsBin = _main.get("_bin")
	_main.call("clear_model")
	camera.frame(AABB(Vector3(-240, 0, -160), Vector3(480, 80, 320)))
	await _wait(60)
	for number: String in COLD:
		_check("%s is not read before it is asked for" % number, not library.is_resident(number))
	_time()
	_library = library
	for n: int in COLD.size():
		await _take_and_aim(bin, builder, camera, COLD[n], "cold %d" % n)
	await _take_and_aim(bin, builder, camera, COLD[0], "warm")
	for n: int in COLD.size():
		for step: String in ["taken", "aimed"]:
			_against("%s, %s" % [COLD[n], step], "cold %d %s" % [n, step], "warm %s" % step)
		# The search's frames and its tiles' are not compared, only said: the
		# first waits for the search's index, any can take seconds of the
		# search itself at a load past the cores, and warm no picture is
		# drawn. What they read here is checked (_read_none).
		for step: String in ["search", "found"]:
			print("  (%s, %s: its longest frame %.1f ms of its own, warm %.1f)"
				% [COLD[n], step, _longest("cold %d %s" % [n, step])[0], _longest("warm " + step)[0]])
	# The editor goes whole, its library with it, before the viewer is
	# timed. Kept here, the editor's library (30,000 parts' entries and the
	# search's index, 270-300 ms to let go of) went in the viewer's first
	# frame up, as this took the viewer's in its place: a frame of 320 to
	# 480 ms that no person has, the viewer being a run of its own (--view,
	# a page), never the editor's (viewerframe).
	_editor_library = weakref(library)
	library = null
	_library = null
	_main.queue_free()
	_main = null
	await _wait(5)


## [param number] found in the bin's search, taken by its tile and moved onto
## the floor: each step's frames under "[param label] found", "taken" and
## "aimed".
func _take_and_aim(bin: PartsBin, builder: Builder, camera: CadCamera, number: String,
		label: String) -> void:
	var cold: bool = label != "warm"
	_phase = "%s search" % label
	var reads: Array = _reads()
	await _click(bin._search.get_global_rect().get_center())
	if not bin._search.has_focus():
		print("    (the click found %s, not the search: focused; bin shown %s, search at %s, window %s)" % [
			root.gui_get_focus_owner(), bin.is_visible_in_tree(), bin._search.get_global_rect(),
			root.get_visible_rect()])
		bin._search.grab_focus()
	await _key(KEY_A, true)
	await _type(number)
	_phase = "%s found" % label
	var tile: Control = null
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 5000:
		for cell: Node in bin._grid.get_children():
			if cell is Control and str(cell.get_meta("part", "")) == number:
				tile = cell
		if tile != null:
			break
		await process_frame
	# Its picture drawn: the tile's part read for it.
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 500:
		await process_frame
	_check("%s: the search lists its tile" % number, tile != null)
	if tile == null:
		print("    the search says %s; tiles %s" % [bin._search.text,
			bin._grid.get_children().slice(0, 6).map(func(c: Node) -> String: return str(c.get_meta("part", "?")))])
		return
	_read_none(cold, "%s: its search and its tiles' pictures" % number, reads)
	_phase = "%s taken" % label
	reads = _reads()
	var from: Vector2 = tile.get_global_rect().get_center()
	# The pointer rests on it a moment before the click, as a person's does.
	await _move(from)
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < HOVER_MS:
		await process_frame
	await _click(from)
	_check("%s: its tile puts it in hand (%s)" % [number, builder.held_part], builder.held_part == number)
	_read_none(cold, "%s: the pointer on its tile and the click" % number, reads)
	_phase = "%s aimed" % label
	reads = _reads()
	var target: Vector2 = camera.unproject_position(Vector3(0, 0, 0))
	for n: int in 6:
		await _move(from.lerp(target, float(n + 1) / 6.0))
	await _wait(10)
	_check("%s: its ghost on the floor under the pointer" % number, builder.ghost_place() != null)
	_read_none(cold, "%s: its first aims" % number, reads)
	_phase = "%s let go" % label
	await _key(KEY_ESCAPE)
	await _wait(10)


## Parts' geometry and exact shapes read on the main thread so far.
func _reads() -> Array:
	return [_library.read_here, Exact.read_here]


## That none was read on the main thread since [param before]: checked when
## [param cold], said otherwise.
func _read_none(cold: bool, what: String, before: Array) -> void:
	var now: Array = _reads()
	var said: String = "%s: %d parts' geometry and %d exact shapes read on the main thread" % [
		what, int(now[0]) - int(before[0]), int(now[1]) - int(before[1])]
	if cold:
		_check(said, now == before)
	else:
		print("  (%s)" % said)


# -- the viewer, and a fetched shape ---------------------------------------------


func _viewer(only: String) -> void:
	var text: String = FileAccess.get_file_as_string(SET)
	if text.is_empty():
		_check("%s is here (tools/fetch_data.sh)" % SET, false)
		return
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe Racer", "author": "Probe Builder",
		"parts": 93, "url": "https://brickworks.diy/m/" + ID, "model": text}}
	_time()
	print("\n8808-1 opened by its link in the viewer")
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", ID)
	_main.set("_shared", fake)
	_phase = "opening"
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 2400:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_check("the shared model opened (%s)" % (view.state if view != null else "none"),
		view != null and view.state == "ready")
	if view == null or view.state != "ready":
		return
	_library = _main.get("_library")
	# What a person watches once the model is up: the viewer reading what
	# moves (a worker's) and, before, asking every part's shape on its
	# frames (Main._play_frame); then the same viewer settled.
	var reads: Array = _reads()
	var asking: Array = _main.get("_shapes_to_ask")
	print("  up, %d shapes to ask for on its frames" % asking.size())
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 120000 and (not view.play_ready or not asking.is_empty()):
		# Each frame said by whether it began with shapes to ask for.
		_phase = "asking" if not asking.is_empty() else "viewing"
		await process_frame
		asking = _main.get("_shapes_to_ask")
	_read_none(true, "8808-1 in the viewer until what moves is said", reads)
	_phase = "settled"
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 2000:
		await process_frame
	if only.is_empty() or only == "viewer":
		_against("8808-1 in the viewer, the frames that asked for shapes", "asking", "settled")
		# Not this probe's: what else the viewer works out as it comes up.
		print("  (the viewer's other frames until what moves is said: its longest %.1f ms of its own)"
			% _longest("viewing")[0])
	if only.is_empty() or only == "fetched":
		await _fetched(_library, _main.get("_world"))
	_main.queue_free()
	_main = null
	await _wait(5)


## 8808-1's shapes forgotten, then handed in as fetches answer, [constant
## PER_FRAME] a frame, and waited for.
func _fetched(library: PartLibrary, world: BrickWorld) -> void:
	print("\n8808-1's exact shapes handed in as fetches answer")
	var ids: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.shaped_as(brick.part_id)
		if info != null and info.exact and not ids.has(info.id) \
				and FileAccess.file_exists(Exact.file_for(library, info.id)):
			ids.append(info.id)
	var bytes: Dictionary = {}
	for id: String in ids:
		bytes[id] = FileAccess.get_file_as_bytes(Exact.file_for(library, id))
	await _wait(30)
	_phase = "idle"
	await _wait(30)
	for paced: bool in [false, true]:
		if paced and not "read_on_a_worker" in library:
			continue
		var label: String = "paced" if paced else "landing"
		if "read_on_a_worker" in library:
			library.set("read_on_a_worker", not paced and not OS.has_feature("nothreads"))
		Exact._shapes_lock.lock()
		for id: String in ids:
			Exact._shapes.erase(library.shaped_as(id).mesh_hash)
		Exact._shapes_lock.unlock()
		var heard: Array = [0]
		var hear := func(_part_id: String) -> void: heard[0] += 1
		library.exact_fetched.connect(hear)
		_phase = label
		for n: int in ids.size():
			var info: PartLibrary.PartInfo = library.shaped_as(ids[n])
			library._fetching_exact[info.mesh_hash] = true
			library._on_fetched_exact(200, bytes[ids[n]], info.mesh_hash, info.id)
			if n % PER_FRAME == PER_FRAME - 1:
				await process_frame
		var since: int = Time.get_ticks_msec()
		while heard[0] < ids.size() and Time.get_ticks_msec() - since < 30000:
			await process_frame
		library.exact_fetched.disconnect(hear)
		var kept: int = ids.filter(func(id: String) -> bool:
			return Exact.known(library, id) and Exact.shape_for(library, id) != null).size()
		_check("%s: all %d shapes kept and said (%d heard), none still on its way"
			% [label, ids.size(), heard[0]],
			kept == ids.size() and heard[0] == ids.size()
				and ids.all(func(id: String) -> bool: return not library.is_exact_on_its_way(id)))
		_phase = "idle"
		await _wait(20)
		_against("%d shapes landing %d a frame%s" % [ids.size(), PER_FRAME, ", paced" if paced else ""],
			label, "idle")
	if "read_on_a_worker" in library:
		library.set("read_on_a_worker", not OS.has_feature("nothreads"))


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


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
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
