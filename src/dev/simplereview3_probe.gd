## simplereview3: the third independent review's attacks on Simple mode after
## its root redesign (simple2: SimpleLayer owns what it acts on, its world and
## its moment). Every act is a finger's touch (or the mouse's, on a desktop)
## through the app, as simplep1_probe sends them.
##
##   PROBE_SIZE=390x844 tools/probe.sh simplereview3_probe -- --pictures=DIR
##   PROBE_SIZE=1280x800 tools/probe.sh simplereview3_probe -- --desktop --pictures=DIR
##   godot --path . --resolution 1280x800 --script src/dev/simplereview3_probe.gd -- --desktop
##   godot --headless --path . --script src/dev/simplereview3_probe.gd -- --headless-ok
##
## --case= subedit, snap, locked, undomid, wayback (all when not said);
##   subedit  Full editing inside a sub-assembly (Assemblies.enter), into
##            Simple: a brick from the tray put on a plain brick. Where it
##            goes (the model, or the sub-assembly Full was in), whether
##            Simple can then act on it, and the saved sub-assembly's lines.
##   snap     Full's snap (Free, Half) chosen, into Simple: a brick from the
##            tray let go where one went on the studs with Stud.
##   locked   a part locked in Full, tapped in Simple: selected or not, and
##            what the line says.
##   undomid  Undo pressed while a finger (a mouse, on a desktop) moves a
##            brick, then let go: nothing put twice or lost; a ghost shown by
##            a tap, a two-finger tap (Undo), then a tap on the ghost.
##   wayback  10030-1 and Orthanc in Full, a part selected and its count shown;
##            into Simple and back, every frame timed (on a CPU and in all,
##            beside frames with no switch); Properties' count after, held to
##            a look on the spot; a part chosen in Simple, the count after;
##            the switch made while the count is under way.
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview2_probe.gd"

const ORTHANC := "res://models/orthanc.ldr"
const ISD := "res://vendor/omr/files/10030-1.mpd"


func _run() -> void:
	if not await _start("subedit,snap,locked,undomid,wayback"):
		return
	for one: String in ["subedit", "snap", "locked", "undomid", "wayback"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"subedit":
				await _case_subedit()
			"snap":
				await _case_snap()
			"locked":
				await _case_locked()
			"undomid":
				await _case_undomid()
			"wayback":
				await _case_wayback()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplereview3_probe"


## As simplereview2's, and headless where --headless-ok says so (the cases that
## time nothing: subedit, snap, locked, undomid), the app in its 1600 x 900
## window, pictures not taken. One GPU slot on the box: these need none.
func _start(cases: String) -> bool:
	if DisplayServer.get_name() != "headless":
		return await super(cases)
	if not OS.get_cmdline_user_args().has("--headless-ok"):
		print("%s: needs a window (or --headless-ok)" % _probe_name())
		quit(1)
		return false
	_args()
	var asked: String = cases
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			asked = arg.get_slice("=", 1)
	_cases = asked.split(",", false)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Phone._on = 0 if _desktop else 1
	Phone._wide = _tablet
	ShellPrefs.put("controls", "simple")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_phone = _main.get("_phone")
	await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_store.keeps = false
	_simple = _main.get("_simple")
	var window: Vector2 = root.get_visible_rect().size
	_size = "%dx%d" % [window.x, window.y]
	print("%s: headless, the root's room %s (the window says %s), %s" % [_probe_name(), _size,
		str(DisplayServer.window_get_size()), "desktop" if _desktop else "phone"])
	if not _check("Simple's layer is up", _simple != null and _simple.is_visible_in_tree()):
		quit(1)
		return false
	return true


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await super(name)


## Headless the window says 0 x 0: an event is put where it is meant.
func _as_event(at: Vector2) -> Vector2:
	if DisplayServer.get_name() == "headless":
		return at
	return super(at)


## Headless nothing flushes Input's buffered events (the headless display
## server's process_events does nothing): each is sent on at once.
func _flush() -> void:
	if DisplayServer.get_name() == "headless":
		Input.flush_buffered_events()


func _touch(index: int, at: Vector2, down: bool) -> void:
	super(index, at, down)
	_flush()


func _drag(index: int, at: Vector2, by: Vector2) -> void:
	super(index, at, by)
	_flush()


func _mouse(at: Vector2, down: bool) -> void:
	super(at, down)
	_flush()


func _mouse_move(at: Vector2) -> void:
	super(at)
	_flush()


## Headless no tap reaches a button: Simple's own button pressed.
func _press_button(what: String) -> bool:
	if DisplayServer.get_name() != "headless":
		return await super(what)
	var button: Button = _simple.call("button", what)
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return false
	button.pressed.emit()
	await _frames(4)
	return true


## Headless the tray's own drop, by Simple's own calls (the tile's drag is a
## window's): the part in hand, let go where [param at] aims.
func _put(part: String, colour: int, at: Vector2) -> int:
	if DisplayServer.get_name() != "headless":
		return await super(part, colour, at)
	if int(_simple.call("chosen_colour")) != colour:
		_simple.call("_on_swatch", colour)
	_simple.call("_take", part)
	_simple.call("_drop_from_tray", at, at)
	await _frames(3)
	var drop: Dictionary = _simple.get("last_drop")
	var put: Array = drop.get("put", [])
	if put.is_empty():
		_note2("headless drop at %s: %s" % [str(at), str(drop)])
	return int(put[0]) if not put.is_empty() else 0


func _settle() -> void:
	if DisplayServer.get_name() != "headless":
		await super()
		return
	var last := Transform3D()
	var still: int = 0
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			still += 1
			if still >= 3:
				break
		else:
			still = 0
		last = _camera.global_transform


# -- subedit --------------------------------------------------------------------------


func _case_subedit() -> void:
	await _from_full_open()
	var text: String = _text()
	var shell: Shell = _main.get("_shell")
	var wing_part: int = 0
	var plain: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if wing_part == 0 and not Assemblies.path_of(brick).is_empty():
			wing_part = brick.id
		if plain == 0 and Assemblies.path_of(brick).is_empty() and brick.part_id.begins_with("3001") \
				and brick.color_code == 4:
			plain = brick.id
	_builder.clear_selection()
	_builder.select_brick(wing_part, false)
	var wing: String = shell.assemblies.selected_assembly()
	_builder.clear_selection()
	if not _check("a sub-assembly and a plain 2 x 4 in the model (\"%s\", %d)" % [wing, plain],
			not wing.is_empty() and plain != 0):
		return
	# Full: edit inside the sub-assembly, as a double-click on it does.
	shell.assemblies.enter(wing)
	await _frames(4)
	_note2("in Full, editing inside \"%s\": place_group \"%s\"" % [shell.assemblies.entered, _builder.place_group])
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	_note2("in Simple: still editing inside \"%s\" (place_group \"%s\"); the line \"%s\"" % [shell.assemblies.entered,
		_builder.place_group, str(_simple.call("hint"))])
	await _shot("sr3_subedit_in_simple")
	var at: Vector2 = _point_on(plain)
	if not _check("the plain 2 x 4 is on the screen", at.x < INF):
		return
	var put: int = await _put("3003", 14, at)
	await _seat_done()
	if not _check("a 2 x 2 from the tray put down on the plain 2 x 4 (%d)" % put, put != 0):
		return
	var brick: BrickWorld.Brick = _world.get_brick(put)
	var why: String = str(_simple.call("left_alone", put))
	_check("...it goes into the model, not into the sub-assembly Full was editing (its group \"%s\")" % brick.group,
		brick.group.is_empty())
	_check("...and Simple can act on it (left alone: \"%s\")" % why, why.is_empty())
	_say_nothing()
	_builder.clear_selection()
	await _frames(2)
	var top: Vector2 = _point_on(put)
	if top.x < INF:
		await _tap_at(top)
		await _frames(3)
		_check("...a tap on it selects it (selected %s; said \"%s\")" % [str(_builder.selection.keys()), _said()],
			_builder.selection.has(put))
		var drag_from: Vector2 = _point_on(put)
		var was: Transform3D = _world.get_brick(put).transform
		await _one_finger(drag_from, drag_from + Vector2(Phone.px(root, 40.0), Phone.px(root, 30.0)))
		await _seat_done()
		_check("...a finger's drag moves it", _world.get_brick(put) != null
			and not _world.get_brick(put).transform.is_equal_approx(was))
	await _shot("sr3_subedit_put")
	var out: String = ProjectSettings.globalize_path("user://sr3_subedit.mpd")
	if _check("saved", bool(_main.call("save_model", out))):
		var saved: String = FileAccess.get_file_as_string(out)
		var sub_lines: Array = _part_lines_of(saved, "simple_wing.ldr")
		var sub_was: Array = _part_lines_of(FROM_FULL, "simple_wing.ldr")
		_check("...the sub-assembly's file as it came: %d part lines, %d before (%s)" % [sub_lines.size(),
			sub_was.size(), ", ".join(sub_lines)], sub_lines.size() == sub_was.size())
	# Undone to the model as opened.
	for _n: int in 4:
		if _text() == text:
			break
		await _press_button("undo")
		await _frames(2)
	_check("...Undo: the model as opened, byte for byte", _text() == text)
	_main.call("use_controls", &"full")
	await _frames(4)
	_note2("back in Full: editing inside \"%s\"" % shell.assemblies.entered)
	shell.assemblies.leave_to("")
	_builder.clear_selection()


## The "1 " lines of the FILE named [param name] in an MPD's [param text].
func _part_lines_of(text: String, name: String) -> Array:
	var out: Array = []
	var inside: bool = false
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if bare.begins_with("0 FILE "):
			inside = bare.substr(7).strip_edges() == name
			continue
		if inside and bare.begins_with("1 "):
			out.append(bare.get_slice(" ", 14) if bare.get_slice_count(" ") > 14 else bare)
	return out


# -- locked --------------------------------------------------------------------------


func _case_locked() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	if not _check("a 2 x 4 down", a != 0):
		return
	_main.call("use_controls", &"full")
	await _frames(4)
	_builder.clear_selection()
	_builder.select_brick(a, false)
	_builder.lock_selection(true)
	await _frames(2)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	_say_nothing()
	var on_a: Vector2 = _point_on(a)
	if not _check("the locked 2 x 4 on the screen", on_a.x < INF):
		_builder.unlock_all()
		return
	var colour_was: int = int(_simple.call("chosen_colour"))
	if DisplayServer.get_name() == "headless":
		# Headless no touch reaches the layer's _unhandled_input: its own
		# press and release, as a finger's tap gives them.
		_simple.call("_press", on_a, 0)
		_simple.call("_release", on_a)
	else:
		await _tap_at(on_a)
	await _frames(3)
	_note2("...the colour strip: %d before the tap, %d after (the locked part is %d), held_color %d" % [
		colour_was, int(_simple.call("chosen_colour")), _world.get_brick(a).color_code, _builder.held_color])
	var said: String = _said()
	_note2("a tap on a part locked in Full: selected %s, the line \"%s\", left alone \"%s\"" % [
		str(_builder.selection.keys()), said if not said.is_empty() else str(_simple.call("hint")),
		str(_simple.call("left_alone", a))])
	_check("a tap on a part locked in Full says why nothing is selected (\"%s\")" % said,
		_builder.selection.has(a) or said.to_lower().contains("lock"))
	await _shot("sr3_locked_tap")
	_builder.unlock_all()


# -- snap ----------------------------------------------------------------------------


## Full's snap (the toolbar's Stud, Half, Free) carried into Simple: a brick
## from the tray let go at the same point with Stud, then with Free and Half
## chosen in Full. Where Stud puts it is on the studs; the others are held to it.
func _case_snap() -> void:
	await _fresh()
	var was: String = _verbs.snap
	var origins: Dictionary = {}
	for snap: String in ["stud", "free", "half"]:
		_main.call("use_controls", &"full")
		await _frames(4)
		_verbs.set_snap(snap)
		_main.call("use_controls", &"simple")
		await _frames(6)
		await _settle()
		# The same point of the plate each time, aimed by the view Simple framed.
		var at: Vector2 = _base_point(0.13, 0.27)
		var put: int = await _put("3001", 4, at)
		await _seat_done()
		if put == 0:
			_check("a 2 x 4 put down with %s chosen in Full" % snap, false)
			continue
		origins[snap] = _world.get_brick(put).transform.origin
		var joined: int = SelectBy.connected(_world, _builder.lattice, [put], _store.scenery, 2).size() - 1
		var bottom: float = _box_of(put).position.y
		_note2("%s: the brick at %s, its bottom %.1f, the plate's top %.1f, joined to %d" % [snap,
			str(origins[snap]), bottom, _floor_box().end.y, joined])
		# The plate's box takes in its studs (4 high): its face is 4 below.
		var face: float = _floor_box().end.y - 4.0
		_check("...with %s chosen in Full the brick from Simple's tray stands on the plate (bottom %.1f, the plate's face %.1f, joined to %d)"
			% [snap, bottom, face, joined], absf(bottom - face) < 1.0 or joined > 0)
		await _press_button("undo")
		_check("...and Simple's Undo takes it back", _world.get_brick(put) == null)
		await _frames(2)
	_main.call("use_controls", &"full")
	await _frames(4)
	_verbs.set_snap(was)
	_main.call("use_controls", &"simple")
	await _frames(4)
	if not origins.has("stud"):
		return
	var stud: Vector3 = origins["stud"]
	for snap: String in ["free", "half"]:
		if not origins.has(snap):
			continue
		var off: Vector3 = (origins[snap] as Vector3) - stud
		var on: bool = is_zero_approx(fposmod(off.x + 0.01, 20.0) - 0.01) and is_zero_approx(fposmod(off.z + 0.01, 20.0) - 0.01)
		_check("with %s chosen in Full, Simple's tray puts the brick on the studs (%s; with Stud %s; off %s)"
			% [snap, str(origins[snap]), str(stud), str(off)], on)


# -- undomid --------------------------------------------------------------------------


func _ctrl_z() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.physical_keycode = KEY_Z
	key.ctrl_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	_flush()
	await process_frame
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	_flush()
	await _frames(2)


func _case_undomid() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(-0.4, 0.0))
	await _seat_done()
	var b: int = await _put("3003", 1, _base_point(0.4, 0.3))
	await _seat_done()
	if not _check("a 2 x 4 and a 2 x 2 down", a != 0 and b != 0):
		return
	_builder.clear_selection()
	await _frames(2)
	var before: Dictionary = _records()
	var depth: int = _builder.history_depth()
	var from: Vector2 = _point_on(b)
	var to: Vector2 = _base_point(0.0, -0.4)
	if _desktop:
		_mouse_move(from)
		await process_frame
		_mouse(from, true)
		await process_frame
		for n: int in 10:
			var now: Vector2 = from.lerp(to, float(n + 1) / 10.0)
			_mouse_move(now)
			await process_frame
		var moving: bool = bool(_simple.get("_moving"))
		await _ctrl_z()
		var after_undo: Dictionary = _records()
		_mouse_move(to + Vector2(4, 4))
		await process_frame
		_mouse(to + Vector2(4, 4), false)
		await _frames(4)
		await _seat_done()
		var now: Dictionary = _records()
		var diff: Dictionary = _changed(before, now)
		_note2("mouse: moving %s when Ctrl+Z went; after it %d parts (%d before), undo depth %d (was %d); let go: changed %s, gone %s, made %s, carrying %s"
			% [moving, after_undo.size(), before.size(), _builder.history_depth(), depth, str(diff["changed"]),
				str(diff["gone"]), str(diff["made"]), _builder.is_carrying()])
		_check("Ctrl+Z while a brick is moved, then let go: no part made, none still in hand (made %s, carrying %s)"
			% [str(diff["made"]), _builder.is_carrying()], (diff["made"] as Array).is_empty() and not _builder.is_carrying())
	else:
		_touch(0, from, true)
		await process_frame
		await _drag_along(0, from, to, 10)
		var moving: bool = bool(_simple.get("_moving"))
		# The phone's Undo is on Simple's own bar, by the thumb: a second
		# finger on it puts the move back first (a second finger always does).
		var undo_at: Vector2 = (_simple.call("button", "undo") as Button).get_global_rect().get_center()
		_touch(1, undo_at, true)
		await process_frame
		_touch(1, undo_at, false)
		await _frames(2)
		_touch(0, to, false)
		await _frames(4)
		await _seat_done()
		var now: Dictionary = _records()
		var diff: Dictionary = _changed(before, now)
		_note2("finger: moving %s when Undo was touched; let go: %d parts (%d before), changed %s, gone %s, made %s, undo depth %d (was %d), carrying %s"
			% [moving, now.size(), before.size(), str(diff["changed"]), str(diff["gone"]), str(diff["made"]),
				_builder.history_depth(), depth, _builder.is_carrying()])
		_check("Undo touched while a brick is moved, then let go: no part made, none still in hand (made %s, carrying %s)"
			% [str(diff["made"]), _builder.is_carrying()], (diff["made"] as Array).is_empty() and not _builder.is_carrying())
	# A ghost shown by a tap, then the two-finger tap (Undo), then a tap on the ghost.
	await _fresh()
	a = await _put("3001", 4, _base_point(-0.4, 0.0))
	await _seat_done()
	b = await _put("3003", 1, _base_point(0.4, 0.3))
	await _seat_done()
	_builder.clear_selection()
	var tile: Control = _simple.call("tile_of", "3005")
	if _desktop:
		await _click(tile.get_global_rect().get_center())
	else:
		await _tap_at(tile.get_global_rect().get_center())
	await _frames(2)
	# The ghost aimed on the top of the last brick put down, which Undo takes.
	var spot: Vector2 = _point_on(b)
	if spot.x == INF:
		spot = _top_point(b)
	if _desktop:
		_mouse_move(spot)
		await _frames(3)
	else:
		await _tap_at(spot)
		await _frames(3)
	var ghost_up: bool = _builder.has_preview()
	var ghost_at: Vector3 = _builder.ghost_transform().origin if ghost_up else Vector3.INF
	before = _records()
	if _desktop:
		await _ctrl_z()
	else:
		var a_pt: Vector2 = _seen_middle() + Vector2(-Phone.px(root, 40.0), 0.0)
		var b_pt: Vector2 = _seen_middle() + Vector2(Phone.px(root, 40.0), 0.0)
		_touch(0, a_pt, true)
		_touch(1, b_pt, true)
		await process_frame
		_touch(0, a_pt, false)
		_touch(1, b_pt, false)
		await _frames(4)
	var undone: Dictionary = _changed(before, _records())
	var ghost_after: bool = _builder.has_preview()
	var chosen: String = str(_simple.call("chosen_brick"))
	if _desktop:
		await _click(spot)
	else:
		await _tap_at(spot)
	await _frames(3)
	var placed: Dictionary = _changed(before, _records())
	_note2("a ghost shown on the last brick (%s, at %s), then Undo (%s): gone %s; the ghost %s, chosen \"%s\"; then a %s at it: made %s"
		% [ghost_up, str(ghost_at), "Ctrl+Z" if _desktop else "two fingers", str(undone["gone"]), ghost_after, chosen,
			"click" if _desktop else "tap", str(placed["made"])])
	_check("...Undo with a ghost up takes back the last brick (gone %s)" % str(undone["gone"]),
		(undone["gone"] as Array).size() == 1)
	_check("...and the next tap puts at most one brick down (made %s)" % str(placed["made"]),
		(placed["made"] as Array).size() <= 1)
	for made: Variant in placed["made"]:
		var joined: int = SelectBy.connected(_world, _builder.lattice, [int(made)], _store.scenery, 2).size() - 1
		var on_plate: bool = _box_of(int(made)).position.y >= _floor_box().end.y - 1.0 \
			and _box_of(int(made)).position.y <= _floor_box().end.y + 1.0
		_check("...the brick put down stands on something: joined to %d, on the plate %s (at %s)"
			% [joined, on_plate, str(_world.get_brick(int(made)).transform.origin)], joined > 0 or on_plate)
		await _shot("sr3_undomid_ghost_put")
	if not str(_simple.call("chosen_brick")).is_empty():
		_simple.call("_tap_tile", str(_simple.call("chosen_brick")))


# -- wayback --------------------------------------------------------------------------


func _case_wayback() -> void:
	for one: Array in [["10030-1", ISD], ["orthanc", ORTHANC]]:
		await _wayback_one(str(one[0]), str(one[1]))


func _open_big(path: String) -> bool:
	_main.call("use_controls", &"full")
	await _frames(4)
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 6000:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(40)
	_builder.clear_selection()
	await _frames(4)
	return _world.brick_count() > 0 and not _store.laying


## The main thread's time on a CPU so far, in microseconds (/proc/thread-self/
## schedstat), or -1 where the system does not say.
func _cpu_us() -> int:
	var file := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if file == null:
		return -1
	var fields: PackedStringArray = file.get_line().split(" ", false)
	return fields[0].to_int() / 1000 if fields.size() >= 2 else -1


func _load() -> String:
	var file := FileAccess.open("/proc/loadavg", FileAccess.READ)
	return file.get_line().get_slice(" ", 0) if file != null else "?"


## [param count] frames timed, the first from [param from_us] (wall) and
## [param from_cpu] (CPU): [the most in all, the most on a CPU, frames over 50
## ms in all, frames over 50 ms on a CPU, the frame number of the longest].
func _timed_frames(count: int, from_us: int, from_cpu: int) -> Array:
	var wall_most: float = 0.0
	var cpu_most: float = 0.0
	var over_wall: int = 0
	var over_cpu: int = 0
	var at: int = -1
	var was_us: int = from_us
	var was_cpu: int = from_cpu
	for n: int in count:
		await process_frame
		var now_us: int = Time.get_ticks_usec()
		var now_cpu: int = _cpu_us()
		var wall: float = (now_us - was_us) / 1000.0
		var cpu: float = (now_cpu - was_cpu) / 1000.0 if now_cpu >= 0 and was_cpu >= 0 else -1.0
		if wall > wall_most:
			wall_most = wall
			at = n
		cpu_most = maxf(cpu_most, cpu)
		if wall > 50.0:
			over_wall += 1
		if cpu > 50.0:
			over_cpu += 1
		was_us = now_us
		was_cpu = now_cpu
	return [snappedf(wall_most, 0.1), snappedf(cpu_most, 0.1), over_wall, over_cpu, at]


func _want_joined(id: int) -> String:
	var joined: int = SelectBy.connected(_world, _builder.lattice, [id], _store.scenery,
		Inspector.JOINED_MOST + 1).size() - 1
	return "Joined to %s" % ("nothing" if joined <= 0 else (
		"1 other part" if joined == 1 else ("%s other parts, directly or through others"
			% ("%d" % joined if joined < Inspector.JOINED_MOST else "%d or more" % Inspector.JOINED_MOST))))


## The properties panel Full shows: down the right, or under the bin.
func _panels() -> Array:
	var out: Array = []
	var shell: Shell = _main.get("_shell")
	if shell != null and shell.inspector != null:
		out.append(shell.inspector)
	var under: Variant = _main.get("_bin_props")
	if under != null:
		out.append(under)
	return out


func _panel_says(panel: Inspector) -> String:
	return "%s%s: \"%s\" / \"%s\" (shows %s)" % ["seen" if panel.is_visible_in_tree() else "unseen",
		"" if panel.is_open() else ", folded", panel._count.text, panel._facts.text.get_slice("\n", 0),
		panel._shown.get_slice(" ", 0) if not panel._shown.is_empty() else "-"]


## Waits for the panel that counts to say "Joined to": frames waited, -1 for never.
func _await_joined(panel: Inspector, most: int = 3000) -> int:
	for n: int in most:
		if panel._facts.text.begins_with("Joined to") and panel._joining == null:
			return n
		await process_frame
	return -1


func _counting_panel() -> Inspector:
	for panel: Inspector in _panels():
		if panel.is_open() and not panel.compact:
			return panel
	var panels: Array = _panels()
	return panels[0] if not panels.is_empty() else null


func _wayback_one(tag: String, path: String) -> void:
	print("\nwayback: %s (%s), %s" % [tag, path.get_file(), _size])
	if not _check("%s: opened in Full" % tag, await _open_big(path)):
		return
	var panel: Inspector = _counting_panel()
	if not _check("%s: a properties panel that counts" % tag, panel != null):
		return
	var all: Array = _plain_ids()
	var plain: Array = []
	for id: Variant in all:
		if str(_simple.call("left_alone", int(id))).is_empty():
			plain.append(id)
	_note2("%s: %d parts, %d Simple may act on; load %s" % [tag, all.size(), plain.size(), _load()])
	var p: int = int(all[all.size() / 2])
	# One part alone, as a person gets it in a set: a click takes its whole
	# sub-assembly, so double-clicked down into it until the click takes it alone.
	var asm: Assemblies = (_main.get("_shell") as Shell).assemblies
	var down: bool = await _down_to(p)
	var inside: String = asm.entered
	_note2("%s: part %d alone in Full: %s, editing inside \"%s\"" % [tag, p, down, inside])
	var waited: int = await _await_joined(panel)
	var want_p: String = _want_joined(p)
	_check("%s: in Full, the part's count shown %d frames on: \"%s\" (a look: \"%s\")" % [tag, waited,
		panel._facts.text.get_slice("\n", 0), want_p], panel._facts.text.get_slice("\n", 0) == want_p)
	var idle: Array = await _timed_frames(60, Time.get_ticks_usec(), _cpu_us())
	_note2("%s: 60 frames with no switch: the longest %.1f ms in all, %.1f on a CPU (%d over 50 in all)"
		% [tag, idle[0], idle[1], idle[2]])
	# Into Simple and back, every frame after each timed.
	var into_us: int = Time.get_ticks_usec()
	var into_cpu: int = _cpu_us()
	_main.call("use_controls", &"simple")
	var into: Array = await _timed_frames(90, into_us, into_cpu)
	await _settle()
	var back_us: int = Time.get_ticks_usec()
	var back_cpu: int = _cpu_us()
	_main.call("use_controls", &"full")
	var back: Array = await _timed_frames(120, back_us, back_cpu)
	_note2("%s: into Simple, 90 frames from the press: the longest %.1f ms in all (frame %d), %.1f on a CPU; %d over 50 in all, %d on a CPU (load %s)"
		% [tag, into[0], into[4], into[1], into[2], into[3], _load()])
	_note2("%s: back to Full, 120 frames from the press: the longest %.1f ms in all (frame %d), %.1f on a CPU; %d over 50 in all, %d on a CPU"
		% [tag, back[0], back[4], back[1], back[2], back[3]])
	_check("%s: no frame over 50 ms on a CPU into Simple (%.1f) or back (%.1f)" % [tag, into[1], back[1]],
		into[3] == 0 and back[3] == 0)
	for one: Inspector in _panels():
		_note2("%s: back, %s" % [tag, _panel_says(one)])
	_check("%s: back in Full, the part selected as before (%s), still inside \"%s\" (\"%s\")" % [tag,
		str(_builder.selection.keys()), inside, asm.entered],
		_builder.selection.size() == 1 and _builder.selection.has(p) and asm.entered == inside)
	_check("%s: ...and its count as before, no stale line: \"%s\"" % [tag, panel._facts.text.get_slice("\n", 0)],
		panel._facts.text.get_slice("\n", 0) == want_p and panel._shown.begins_with("%d " % p))
	await _shot("sr3_wayback_%s_back" % tag)

	# A part chosen in Simple: back in Full, Properties show it and its count.
	if not plain.is_empty():
		var q: int = 0
		_main.call("use_controls", &"simple")
		await _frames(4)
		await _settle()
		for id: Variant in plain:
			if int(id) != p and _point_on(int(id)).x < INF:
				q = int(id)
				break
		if q != 0:
			await _tap_at(_point_on(q))
			await _frames(3)
			_check("%s: a part Simple may act on tapped: selected (%s)" % [tag, str(_builder.selection.keys())],
				_builder.selection.has(q))
			var us: int = Time.get_ticks_usec()
			var cpu: int = _cpu_us()
			_main.call("use_controls", &"full")
			var counted: Array = await _timed_frames(150, us, cpu)
			var frames_q: int = await _await_joined(panel)
			var want_q: String = _want_joined(q)
			_note2("%s: back with a part chosen in Simple: the longest frame %.1f ms in all, %.1f on a CPU; %d over 50 on a CPU"
				% [tag, counted[0], counted[1], counted[3]])
			_check("%s: ...Properties show the part chosen in Simple and its count: \"%s\" (a look: \"%s\"), shows %s"
				% [tag, panel._facts.text.get_slice("\n", 0), want_q, panel._shown.get_slice(" ", 0)],
				frames_q >= 0 and panel._facts.text.get_slice("\n", 0) == want_q and panel._shown.begins_with("%d " % q))
			_check("%s: ...no frame over 50 ms on a CPU while it counts (%.1f)" % [tag, counted[1]], counted[3] == 0)
			# Deleted in Simple: back in Full nothing is shown of it.
			_main.call("use_controls", &"simple")
			await _frames(4)
			await _settle()
			var at_q: Vector2 = _point_on(q)
			if at_q.x < INF:
				await _tap_at(at_q)
				await _frames(3)
				await _press_button("delete")
				var gone: bool = _world.get_brick(q) == null
				_main.call("use_controls", &"full")
				await _frames(8)
				_check("%s: a part deleted in Simple (%s): back in Full, Properties say \"%s\", no line of it (\"%s\")"
					% [tag, gone, panel._count.text, panel._facts.text.get_slice("\n", 0) if panel._scroll.visible else ""],
					gone and _builder.selection.is_empty() and panel._count.text == "nothing selected")
				await _verbs.own_undo(false)
				await _frames(3)
		else:
			_note2("%s: no part Simple may act on in the room" % tag)
			_main.call("use_controls", &"full")
			await _frames(4)
	else:
		_note2("%s: Simple leaves every part alone: nothing to choose there" % tag)

	# The switch made while the count is under way.
	var r: int = int(all[all.size() / 3])
	asm.leave_to("")
	await _frames(2)
	var down_r: bool = await _down_to(r)
	var midway: bool = panel._joining != null
	_note2("%s: part %d alone: %s, inside \"%s\"; its count under way %s" % [tag, r, down_r, asm.entered, midway])
	_main.call("use_controls", &"simple")
	await _frames(20)
	_main.call("use_controls", &"full")
	var frames_r: int = await _await_joined(panel)
	var want_r: String = _want_joined(r)
	_check("%s: the switch made %s the count: back in Full \"%s\" %d frames on (a look: \"%s\")" % [tag,
		"while it was under way, before" if midway else "after", panel._facts.text.get_slice("\n", 0), frames_r, want_r],
		panel._facts.text.get_slice("\n", 0) == want_r and panel._shown.begins_with("%d " % r))
	_builder.clear_selection()
	asm.leave_to("")
	await _frames(4)


## Double-clicked down (Assemblies.enter) until a click on [param id] takes
## it alone: whether it is selected alone.
func _down_to(id: int) -> bool:
	var asm: Assemblies = (_main.get("_shell") as Shell).assemblies
	for level: int in 8:
		_builder.select_brick(id, false)
		await _frames(2)
		if _builder.selection.size() <= 1:
			return _builder.selection.has(id)
		var path: String = asm.selected_assembly()
		if path.is_empty() or path == asm.entered:
			return false
		asm.enter(path)
		await _frames(2)
	return false
