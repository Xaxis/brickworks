## Train tracks joined end to end (docs/APP_UX4.md, unit 5), done as a
## person does it: every act a click, a drag or a key sent to the window,
## every check what the model has after it. Over MCP as a session's calls.
##
##   tools/probe.sh tracks_probe
##   godot --path . --resolution 1280x720 --script src/dev/tracks_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh tracks_probe
##
## 1. A 9V curve dragged from the bin to near a 9V straight's free end joins
##    it in one drag: its end within 0.5 LDU of the straight's, the two
##    facing within 0.1 degree.
## 2. Sixteen 9V curves laid by sixteen clicks close a circle within 1 LDU.
## 3. R on a curve in hand on a track's end puts its other end to the joint.
##    Two 12V curves joined get the sleeper their joint needs, and one undo
##    takes both off.
## 4. An oval of 16 curves and 4 straights by a session in 3 calls or fewer.
##
## Where each end is comes from assets/ldraw/track_ends.json, read here on
## its own and not by the app's TrackSnap, so a build without the joints is
## told what a person could not do there.
## Pictures go to shots/tracks/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/tracks/"
const TABLE := "res://assets/ldraw/track_ends.json"
const STRAIGHT := "74746"
const CURVE := "74747"
const RAILS_CURVE := "3241ac01"
## Two ends joined: this near, LDU, and facing within this, degrees.
const MEET := 0.5
const FACING := 0.1

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _bin: PartsBin
var _library: PartLibrary
var _socket: CommandSocket
var _out: String = ""
var _acts: int = 0
var _pointer: Vector2 = Vector2.ZERO
var _rpc_id: int = 0
## Part -> its ends in its own frame, [at, out] each.
var _ends: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  tracks probe: needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_read_table()
	var size: Vector2i = DisplayServer.window_get_size()
	_out = "%s%dx%d/" % [SHOTS, size.x, size.y]
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_world = _main.get("_world")
		if _world != null and _world.brick_count() > 1 and _main.get("_shell") != null:
			break
	if _world == null or _main.get("_shell") == null:
		print("  tracks probe: SKIPPED — the window did not come up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_bin = _main.get("_bin")
	_library = _main.get("_library")
	_store.keeps = false
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	for _n: int in 600:
		if _library.search_ready():
			break
		await process_frame
	print("  a %d x %d window; %d tracks in the table" % [size.x, size.y, _ends.size()])
	_check("the table has the 9V straight and curve and the 12V curve",
		_ends.has(STRAIGHT) and _ends.has(CURVE) and _ends.has(RAILS_CURVE))
	if _failures == 0:
		await _one_drag()
		await _turned()
		await _sleeper()
		await _circle()
		await _oval()
	print("")
	if _failures == 0:
		print("tracks probe: all checks passed")
	else:
		print("tracks probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the bar -----------------------------------------------------------------------

## 1: a straight down, then a curve dragged from the bin onto its free end.
func _one_drag() -> void:
	print("── 1. a curve brought to a straight's free end, in one drag ──")
	await _new_model()
	await _hold(STRAIGHT)
	await _grey()
	await _click(_model_middle())
	var straight: int = _newest()
	_check("a straight is down", _is(straight, STRAIGHT))
	if straight == 0:
		return
	await _top_view(_world.get_brick(straight).transform.origin, 900.0)
	var free: Array = _free_ends()
	var target: Array = free[0] if not free.is_empty() else []
	_check("the straight has two free ends", free.size() == 2)
	if target.is_empty():
		return
	await _search(CURVE)
	var tile: Vector2 = _tile(CURVE)
	var near: Vector2 = _screen(target) + Vector2(5.0, 4.0)
	var acts: int = _acts
	await _left_drag(tile, near)
	var curve: int = _newest()
	_check("one drag put a curve down (%d act)" % (_acts - acts),
		_acts - acts == 1 and _is(curve, CURVE))
	var joint: Array = _joint(straight, curve)
	_check("1: its end meets the straight's, %.3f LDU apart, facing within %.4f degrees" % [
		joint[0], joint[1]], joint[0] <= MEET and joint[1] <= FACING)
	await _aside()
	await _shot("joined")


## 3: the curve still in hand, over the free end of the one down, and R.
func _turned() -> void:
	print("── 3. R puts the curve's other end to the joint ──")
	var free: Array = _free_of(_newest())
	_check("the curve down has a free end", not free.is_empty())
	if free.is_empty():
		return
	await _move(_screen(free[0]))
	var before: Array = _ghost_on(free[0])
	_check("over it, the curve in hand is on that end (its end %d, %.3f LDU, %.4f degrees)" % [
		before[0], before[1], before[2]], before[0] >= 0)
	await _key_of("rotate_held")
	var after: Array = _ghost_on(free[0])
	_check("3: after R its other end is on it (its end %d, %.3f LDU, %.4f degrees)" % [
		after[0], after[1], after[2]], after[0] >= 0 and after[0] != before[0])
	await _shot("turned")
	var count: int = _parts()
	await _click(_screen(free[0]))
	var placed: int = _newest()
	var joint: Array = _joint(int(free[0][0]), placed)
	_check("a click puts it there, turned: %.3f LDU, %.4f degrees" % [joint[0], joint[1]],
		_parts() == count + 1 and joint[0] <= MEET and joint[1] <= FACING)
	await _key(KEY_ESCAPE)


## Two 12V curves: their joint needs a sleeper under it, which comes with the
## second, and one undo takes both off.
func _sleeper() -> void:
	print("── the sleeper a 12V joint needs, in the same undo ──")
	await _new_model()
	await _hold(RAILS_CURVE)
	await _click(_model_middle())
	var first: int = _newest()
	_check("a 12V curve is down", _is(first, RAILS_CURVE))
	if first == 0:
		return
	await _top_view(_world.get_brick(first).transform.origin, 700.0)
	var free: Array = _free_of(first)
	if free.is_empty():
		_check("it has a free end", false)
		return
	var count: int = _parts()
	await _click(_screen(free[0]))
	var added: Array = _bricks().slice(count)
	var joint: Array = _joint(first, added[0] if not added.is_empty() else 0)
	var sleepers: Array = added.slice(1)
	_check("a click on its end puts the next on it (%.3f LDU, %.4f degrees) and a sleeper under the joint (%s)" % [
		joint[0], joint[1], ", ".join(PackedStringArray(sleepers.map(func(id: int) -> String:
			return _world.get_brick(id).part_id)))],
		joint[0] <= MEET and joint[1] <= FACING and sleepers.size() == 1)
	await _aside()
	await _shot("sleeper")
	await _key(KEY_ESCAPE)
	await _key_of("undo")
	_check("one undo takes the curve and its sleeper off (%d parts, were %d, %d had gone down)" % [
		_parts(), count, added.size()], added.size() == 2 and _parts() == count)


## 2: sixteen clicks, each on the free end of the curve last put down.
func _circle() -> void:
	print("── 2. sixteen curves by sixteen clicks ──")
	await _new_model()
	await _hold(CURVE)
	var acts: int = _acts
	await _click(_model_middle())
	var first: int = _newest()
	_check("the first curve is down", _is(first, CURVE))
	if first == 0:
		return
	await _top_view(_circle_middle(first), 1900.0)
	var clicks: int = 1
	var view: Rect2 = _main.call("_model_rect")
	for n: int in 15:
		var free: Array = _free_of(_newest())
		if free.is_empty():
			break
		if not view.has_point(_screen(free[0])):
			print("    the newest curve's free end is out of sight, at %s" % _screen(free[0]))
			break
		await _click(_screen(free[0]))
		clicks += 1
	var curves: Array = _bricks().filter(func(id: int) -> bool: return _is(id, CURVE))
	var last: int = _newest()
	var joint: Array = _joint(first, last)
	_check("2: %d curves by %d clicks (%d acts); the last meets the first %.3f LDU apart, facing within %.4f degrees; %d free ends" % [
		curves.size(), clicks, _acts - acts, joint[0], joint[1], _free_ends().size()],
		curves.size() == 16 and clicks == 16 and joint[0] <= 1.0 and _free_ends().is_empty())
	await _aside()
	await _shot("circle")


## 4: a session lays an oval: clear_model, then one submit_design whose
## parts each go on the last one's end.
func _oval() -> void:
	print("── 4. an oval of 16 curves and 4 straights over MCP ──")
	var calls: int = 0
	var said: String = await _say("clear_model", {})
	calls += 1
	var bricks: Array = []
	var order: Array = []
	for half: int in 2:
		for n: int in 8:
			order.append(CURVE)
		order.append(STRAIGHT)
		order.append(STRAIGHT)
	for n: int in order.size():
		var brick: Dictionary = {"part": order[n], "color": 8, "name": "t%d" % n}
		if n == 0:
			brick.merge({"x": 0, "y": 0, "z": 0})
		else:
			brick["attach"] = {"to": "t%d.track[1]" % (n - 1), "by": "track[0]"}
		bricks.append(brick)
	said = await _say("submit_design", {"name": "Oval", "bricks": bricks})
	calls += 1
	# A call still going after 20 s is a job (ToolJobs): asked about until
	# it answers, each ask a call of the session's.
	var job := RegEx.create_from_string("^Started job (\\d+)")
	var started: RegExMatch = job.search(said)
	while started != null and calls < 8:
		said = await _say("job", {"id": int(started.get_string(1))})
		calls += 1
		if not said.contains("is still going"):
			break
	var tracks: Array = _bricks().filter(func(id: int) -> bool:
		return _ends.has(_library.resolve(_world.get_brick(id).part_id)))
	var worst: Array = [0.0, 0.0]
	for n: int in tracks.size():
		var joint: Array = _joint(tracks[n], tracks[(n + 1) % tracks.size()]) \
			if tracks.size() > 1 else [INF, INF]
		worst = [maxf(worst[0], joint[0]), maxf(worst[1], joint[1])]
	_check("4: in %d calls, %d tracks down, every end on the next's (worst %.3f LDU, %.4f degrees), %d free ends" % [
		calls, tracks.size(), worst[0], worst[1], _free_ends().size()],
		calls <= 3 and tracks.size() == 20 and worst[0] <= MEET and worst[1] <= FACING
		and _free_ends().is_empty())
	if tracks.size() != 20:
		print("    the session heard: %s" % said.left(600))
	var box := AABB()
	for n: int in tracks.size():
		var at: Vector3 = _world.get_brick(tracks[n]).transform.origin
		box = AABB(at, Vector3.ZERO) if n == 0 else box.expand(at)
	await _top_view(box.get_center(), box.size.x + 400.0)
	await _shot("oval")


# -- ends, from the table ------------------------------------------------------------

func _read_table() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	if not parsed is Dictionary:
		return
	var tracks: Dictionary = (parsed as Dictionary).get("tracks", {})
	for part: String in tracks:
		var list: Array = []
		for row: Dictionary in (tracks[part] as Dictionary).get("ends", []):
			var at: Array = row["at"]
			var out: Array = row["out"]
			list.append([Vector3(float(at[0]), float(at[1]), float(at[2])),
				Vector3(float(out[0]), float(out[1]), float(out[2])).normalized()])
		_ends[part] = list


## A brick's ends where it stands: [brick, index, at, out] each.
func _placed(brick_id: int, where: Variant = null) -> Array:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null and where == null:
		return []
	var part: String = _library.resolve(brick.part_id if brick != null else _builder.held_part)
	var at: Transform3D = where if where != null else brick.transform
	var out: Array = []
	var ends: Array = _ends.get(part, [])
	for n: int in ends.size():
		out.append([brick_id, n, at * (ends[n][0] as Vector3),
			(at.basis * (ends[n][1] as Vector3)).normalized()])
	return out


## How near two ends are: [LDU apart, degrees from facing].
static func _apart(a: Array, b: Array) -> Array:
	var facing: float = clampf(-(a[3] as Vector3).dot(b[3]), -1.0, 1.0)
	return [(a[2] as Vector3).distance_to(b[2]), rad_to_deg(acos(facing))]


## The nearest two ends of two bricks: [LDU apart, degrees from facing].
func _joint(one: int, other: int) -> Array:
	var best: Array = [INF, INF]
	for a: Array in _placed(one):
		for b: Array in _placed(other):
			var gap: Array = _apart(a, b)
			if gap[0] < best[0]:
				best = gap
	return best


## Every end of every track down that no other track's end is on.
func _free_ends() -> Array:
	var all: Array = []
	for id: int in _bricks():
		all.append_array(_placed(id))
	var free: Array = []
	for a: Array in all:
		var met: bool = false
		for b: Array in all:
			if a[0] != b[0]:
				var gap: Array = _apart(a, b)
				met = met or (gap[0] <= 1.0 and gap[1] <= FACING)
		if not met:
			free.append(a)
	return free


func _free_of(brick_id: int) -> Array:
	return _free_ends().filter(func(end: Array) -> bool: return end[0] == brick_id)


## Which end of the part in hand is on [param end], by its ghost: [its
## index, LDU apart, degrees from facing], index -1 when none is.
func _ghost_on(end: Array) -> Array:
	var ghost: Transform3D = _builder.get("_ghost_transform")
	var best: Array = [-1, INF, INF]
	for mine: Array in _placed(0, ghost):
		var gap: Array = _apart(mine, end)
		if gap[0] < best[1]:
			best = [mine[1] if gap[0] <= MEET and gap[1] <= FACING else -1, gap[0], gap[1]]
	return best


## Where a circle of the curve [param first]'s turn has its middle.
func _circle_middle(first: int) -> Vector3:
	var ends: Array = _placed(first)
	var chord: float = (ends[0][2] as Vector3).distance_to(ends[1][2])
	var half: float = acos(clampf(-(ends[0][3] as Vector3).dot(ends[1][3]), -1.0, 1.0)) * 0.5
	var inward: Vector3 = ((ends[0][3] as Vector3) + (ends[1][3] as Vector3)).normalized()
	return ((ends[0][2] as Vector3) + (ends[1][2] as Vector3)) * 0.5 \
		+ inward * (chord * 0.5 / tan(half))


# -- the model -------------------------------------------------------------------------

func _bricks() -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


func _parts() -> int:
	return _bricks().size()


func _newest() -> int:
	var ids: Array = _bricks().filter(func(id: int) -> bool:
		return _ends.has(_library.resolve(_world.get_brick(id).part_id)))
	return ids.back() if not ids.is_empty() else 0


func _is(brick_id: int, part: String) -> bool:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return brick != null and _library.resolve(brick.part_id) == part


func _new_model() -> void:
	await (_main.get("_bar") as Node).call("_start_new")
	await _frames(10)


## Looking straight down on [param middle], [param across] LDU in sight.
func _top_view(middle: Vector3, across: float) -> void:
	_camera.set_view("top")
	_camera.frame(AABB(middle - Vector3(across, 40.0, across) * 0.5, Vector3(across, 40.0, across)),
		1.0)
	var was := Transform3D()
	for _n: int in 240:
		await process_frame
		if _camera.global_transform.is_equal_approx(was):
			break
		was = _camera.global_transform
	await _frames(5)


func _screen(end: Array) -> Vector2:
	return _camera.unproject_position((end[2] as Vector3) + Vector3.UP * 12.0)


func _model_middle() -> Vector2:
	return (_main.call("_model_rect") as Rect2).get_center()


## The pointer to a corner of the view, out of the way of what a picture
## shows: the tile's tooltip that followed a drag goes with it.
func _aside() -> void:
	var view: Rect2 = _main.call("_model_rect")
	await _move(view.position + Vector2(24.0, view.size.y - 24.0))
	await _frames(10)


## Dark bluish grey, as track is, clicked in the palette.
func _grey() -> void:
	var swatches: Dictionary = _bin.get("_swatches")
	var palette: Rect2 = (_bin.controls_by_name()["palette"] as Control).get_global_rect()
	for code: int in [72, 8, 71, 7]:
		var swatch: Control = swatches.get(code)
		if swatch != null and swatch.is_visible_in_tree() and palette.encloses(swatch.get_global_rect()):
			await _click(swatch.get_global_rect().get_center())
			_check("track grey (%d) in hand" % code, _builder.held_color == code)
			return
	print("    no grey in sight in the palette")


# -- the bin ----------------------------------------------------------------------------

## [param part] in hand: its number typed in the bin's search and its tile
## clicked.
func _hold(part: String) -> void:
	await _search(part)
	await _click(_tile(part))
	_check("%s in hand" % part, _builder.held_part == part)


## The field cleared and [param text] typed into it key by key, as a person does.
func _search(text: String) -> void:
	var field: LineEdit = _bin.controls_by_name()["part search"]
	await _click(field.get_global_rect().get_center())
	field.select_all()
	await _key(KEY_BACKSPACE)
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	for _n: int in 300:
		await process_frame
		if _tile_or_none(text) != Vector2.INF:
			break


func _tile_or_none(part: String) -> Vector2:
	var scroll: Control = _bin.controls_by_name()["parts list"]
	for tile: Node in _bin.find_children("*", "Button", true, false):
		var button := tile as Button
		if str(button.get_meta("part", "")) == part and button.is_visible_in_tree() \
				and scroll.get_global_rect().encloses(button.get_global_rect()):
			return button.get_global_rect().get_center()
	return Vector2.INF


func _tile(part: String) -> Vector2:
	var at: Vector2 = _tile_or_none(part)
	_check("the bin shows %s" % part, at != Vector2.INF)
	return at if at != Vector2.INF else Vector2.ZERO


# -- MCP ---------------------------------------------------------------------------------

func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	await _frames(5)
	return text


# -- acts ----------------------------------------------------------------------------------

func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


func _move(at: Vector2, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _pointer
	_pointer = motion.position
	motion.button_mask = mask
	Input.parse_input_event(motion)
	await _frames(3)


func _press(button: MouseButton, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	_acts += 1
	await _move(at)
	_press(MOUSE_BUTTON_LEFT, at, true)
	await _frames(2)
	_press(MOUSE_BUTTON_LEFT, at, false)
	await _frames(8)


func _left_drag(from: Vector2, to: Vector2) -> void:
	_acts += 1
	await _move(from)
	_press(MOUSE_BUTTON_LEFT, from, true)
	await _frames(2)
	for n: int in range(1, 9):
		await _move(from.lerp(to, n / 8.0), MOUSE_BUTTON_MASK_LEFT)
	_press(MOUSE_BUTTON_LEFT, to, false)
	await _frames(30)


func _key(code: Key) -> void:
	await _keys(Keymap.press_of(code))


## The key the person's keymap gives [param action], pressed.
func _key_of(action: String) -> void:
	var accel: int = Keymap.key_of(action)
	_check("%s has a key" % action, accel != 0)
	await _keys(Keymap.press_of(accel))


func _keys(down: InputEventKey) -> void:
	_acts += 1
	Input.parse_input_event(down)
	await process_frame
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
