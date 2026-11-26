## simplereview2: an independent review's attacks on Simple mode phase 1
## (simple1, SimpleLayer): where a person in Simple loses work or is
## surprised. Every act is a finger's touch event (or the mouse's, on a
## desktop) through the app, as simplep1_probe sends them.
##
##   godot --path . --resolution 390x844 --script src/dev/simplereview2_probe.gd
##   PROBE_SIZE=390x844 tools/probe.sh simplereview2_probe -- --pictures=DIR
##   PROBE_SIZE=820x1180 tools/probe.sh simplereview2_probe -- --tablet --pictures=DIR
##   PROBE_SIZE=1280x800 tools/probe.sh simplereview2_probe -- --desktop --case=escape
##
## --case= fullsel, riders, copy, escape, offplate, switchmid, framing, save
## (all when not said; escape only on --desktop);
##   fullsel   parts selected in Full, some Simple leaves alone (a tilted brick,
##             a sub-assembly), into Simple: Delete, a colour and a drag there
##             leave those parts as they are.
##   riders    a 1 x 1 on a 2 x 4's end; the 2 x 4 tapped and dragged: what is
##             selected after, and what a colour and Delete then change.
##   copy      Copy, then Undo and Redo, byte for byte; Ctrl+D's copy in hand,
##             Undo while it is held, and a tap after.
##   escape    (a mouse) a brick chosen on the tray, Escape, then a click on a
##             brick: selected, nothing put down.
##   offplate  a brick let go over the room's top and beside the plate: where it
##             went, and Fit after.
##   switchmid the switch to Full and back mid tray drag, with a ghost shown,
##             mid move, with two fingers down, mid hold: nothing put down or
##             moved unasked, and one finger still builds after.
##   framing   a new sketch's plate in the room left it: margins each side.
##   save      6054-1 (bracket metas) and 5972-1 (LSynth hoses) opened in Full;
##             in Simple a part painted and turned, one moved by a finger, one
##             put down from the tray; saved: every line but the changed parts'
##             kept byte for byte and in order; reopened whole.
## Exits non-zero when a check fails.
extends "res://src/dev/simplep1_probe.gd"

var _cases: Array = []


func _run() -> void:
	if not await _start("fullsel,riders,copy,escape,offplate,switchmid,framing,save"):
		return
	for one: String in ["framing", "fullsel", "riders", "copy", "escape", "offplate", "switchmid", "save", "openin", "unseen"]:
		if not _cases.has(one):
			continue
		if one == "escape" and not _desktop:
			continue
		print("\n== %s" % one)
		match one:
			"framing":
				await _case_framing()
			"fullsel":
				await _case_fullsel()
			"riders":
				await _case_riders()
			"copy":
				await _case_copy()
			"escape":
				await _case_escape()
			"offplate":
				await _case_offplate()
			"switchmid":
				await _case_switchmid()
			"save":
				await _case_save()
			"openin":
				await _case_openin()
			"unseen":
				await _case_unseen()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplereview2_probe"


## The app up in Simple at the window's size, [param cases] run unless
## --case= names others: false (and quit) when it is not.
func _start(cases: String) -> bool:
	if DisplayServer.get_name() == "headless":
		print("%s: needs a window" % _probe_name())
		quit(1)
		return false
	_args()
	var asked: String = cases
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			asked = arg.get_slice("=", 1)
	_cases = asked.split(",", false)
	if _pictures == "res://shots/simplep1/":
		_pictures = "user://sr2/"
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
	if _phone != null:
		_phone.set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_store.keeps = false
	_simple = _main.get("_simple")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_pictures))
	print("%s: a %s window, %s" % [_probe_name(), _size, "desktop" if _desktop else ("tablet" if _tablet else "phone")])
	if not _check("Simple's layer is up", _simple != null and _simple.is_visible_in_tree()):
		quit(1)
		return false
	return true


func _note2(words: String) -> void:
	print("  ..   " + words)


func _text() -> String:
	return _store.to_text()


func _press_button(what: String) -> bool:
	var button: Button = _simple.call("button", what)
	if button == null or not button.is_visible_in_tree():
		return false
	await _tap_at(button.get_global_rect().get_center())
	await _frames(4)
	return true


func _plain_ids() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick.id)
	return out


func _records() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out[brick.id] = [brick.part_id, brick.color_code, brick.transform]
	return out


## Ids whose part, colour or place differ between two records; ids only in one.
func _changed(was: Dictionary, now: Dictionary) -> Dictionary:
	var changed: Array = []
	var gone: Array = []
	var made: Array = []
	for id: Variant in was:
		if not now.has(id):
			gone.append(id)
		elif was[id][0] != now[id][0] or was[id][1] != now[id][1] \
				or not (was[id][2] as Transform3D).is_equal_approx(now[id][2]):
			changed.append(id)
	for id: Variant in now:
		if not was.has(id):
			made.append(id)
	return {"changed": changed, "gone": gone, "made": made}


## A point on the screen where a finger lands on [param id] itself, in the
## model's room, or Vector2.INF.
func _point_on(id: int) -> Vector2:
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	room = room.grow(-Phone.px(root, 30.0))
	var box: AABB = _box_of(id)
	for spot: Vector3 in [Vector3(box.get_center().x, box.end.y, box.get_center().z), box.get_center(),
			Vector3(box.position.x + box.size.x * 0.25, box.end.y, box.get_center().z),
			Vector3(box.end.x - box.size.x * 0.25, box.end.y, box.get_center().z)]:
		var at: Vector2 = _camera.unproject_position(spot)
		if room.has_point(at) and _verbs.brick_at(at) == id:
			return at
	return Vector2.INF


# -- framing ---------------------------------------------------------------------------


func _case_framing() -> void:
	await _fresh()
	await _frames(10)
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var plate: Rect2 = _screen_box(_floor_box())
	var k: float = Phone.px(root, 1.0)
	_note2("room %s, plate %s (points: left %.0f right %.0f top %.0f bottom %.0f; plate %.0f%% of the room's width, %.0f%% of its height)"
		% [room, plate, (plate.position.x - room.position.x) / k, (room.end.x - plate.end.x) / k,
			(plate.position.y - room.position.y) / k, (room.end.y - plate.end.y) / k,
			100.0 * plate.size.x / room.size.x, 100.0 * plate.size.y / room.size.y])
	_check("a new sketch's plate whole in the room left it", room.grow(2.0).encloses(plate))
	# The round buttons over the model: is the plate under any of them, where
	# a finger's tap presses the button and not the plate?
	var floor: AABB = _floor_box()
	for what: String in ["undo", "redo", "fit"]:
		var button: Button = _simple.call("button", what)
		if button == null or not button.is_visible_in_tree():
			continue
		var rect: Rect2 = button.get_global_rect()
		var over: int = 0
		for n: int in 25:
			var at: Vector2 = rect.position + rect.size * Vector2((n % 5 + 0.5) / 5.0, (n / 5 + 0.5) / 5.0)
			var hit: Variant = Plane(Vector3.UP, floor.end.y).intersects_ray(_camera.ray_origin(at), _camera.ray_normal(at))
			if hit != null and (hit as Vector3).x >= floor.position.x and (hit as Vector3).x <= floor.end.x \
					and (hit as Vector3).z >= floor.position.z and (hit as Vector3).z <= floor.end.z:
				over += 1
		_note2("%s at %s: %d of 25 points over the plate" % [what, rect, over])
	await _shot("sr2_framing")
	# One brick on the plate's corner, then Fit: what it frames.
	var id: int = await _put("3001", 4, _base_point(-0.7, 0.6))
	await _seat_done()
	_builder.clear_selection()
	await _press_fit()
	plate = _screen_box(_floor_box())
	_note2("one brick down (%d), Fit: the plate %.0f x %.0f, %s the room" % [id, plate.size.x, plate.size.y,
		"whole in" if room.grow(2.0).encloses(plate) else "NOT whole in"])
	await _shot("sr2_framing_fit_one")


# -- fullsel ---------------------------------------------------------------------------


func _from_full_open() -> Dictionary:
	_main.call("use_controls", &"full")
	await _frames(6)
	var path: String = "user://sr2_from_full.mpd"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FROM_FULL)
	file.close()
	await _open(path)
	return _records()


func _select_all_in_full() -> void:
	_main.call("use_controls", &"full")
	await _frames(4)
	_builder.clear_selection()
	for id: Variant in _plain_ids():
		_builder.select_brick(int(id), true)
	await _frames(2)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()


func _alone_ids() -> Array:
	var out: Array = []
	for id: Variant in _plain_ids():
		if not str(_simple.call("left_alone", int(id))).is_empty():
			out.append(id)
	return out


func _case_fullsel() -> void:
	var opened: Dictionary = await _from_full_open()
	var text: String = _text()
	await _select_all_in_full()
	var alone: Array = _alone_ids()
	_note2("in Simple: %d selected from Full, %d of them parts Simple leaves alone; Turn, Copy, Delete shown: %s"
		% [_builder.selection.size(), alone.filter(func(id: Variant) -> bool: return _builder.selection.has(id)).size(),
			(_simple.call("button", "delete") as Button).is_visible_in_tree()])
	await _shot("sr2_fullsel")
	# Delete.
	if await _press_button("delete"):
		var now: Dictionary = _records()
		var lost: Array = alone.filter(func(id: Variant) -> bool: return not now.has(id))
		_check("Simple's Delete on Full's selection leaves the parts Simple leaves alone (%d of %d deleted; %d parts deleted in all)"
			% [lost.size(), alone.size(), opened.size() - now.size()], lost.is_empty())
		await _press_button("undo")
		_check("...Undo: the model as it was, byte for byte", _text() == text)
	# A colour.
	await _select_all_in_full()
	await _press_swatch(1)
	await _frames(3)
	var painted: Dictionary = _changed(opened, _records())
	var touched: Array = alone.filter(func(id: Variant) -> bool: return (painted["changed"] as Array).has(id))
	_check("a colour tapped in Simple on Full's selection leaves the parts Simple leaves alone (%d of %d painted)"
		% [touched.size(), alone.size()], touched.is_empty())
	if _text() != text:
		await _press_button("undo")
	_check("...Undo: the model as it was", _text() == text)
	# A drag on a part Simple may move, with Full's selection.
	await _select_all_in_full()
	var plain: int = 0
	for id: Variant in _plain_ids():
		if not alone.has(id) and _point_on(int(id)).x < INF:
			plain = int(id)
			break
	if plain == 0:
		_check("a plain part to drag", false)
		return
	var at: Vector2 = _point_on(plain)
	await _one_finger(at, at + Vector2(Phone.px(root, 50.0), Phone.px(root, 20.0)))
	await _seat_done()
	var moved: Dictionary = _changed(opened, _records())
	touched = alone.filter(func(id: Variant) -> bool: return (moved["changed"] as Array).has(id))
	_check("a drag in Simple on a part of Full's selection leaves the parts Simple leaves alone (%d of %d moved; %d moved in all)"
		% [touched.size(), alone.size(), (moved["changed"] as Array).size()], touched.is_empty())
	if _text() != text:
		await _press_button("undo")
	_check("...Undo: the model as it was", _text() == text)
	_builder.clear_selection()


# -- riders ----------------------------------------------------------------------------


func _case_riders() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	if not _check("a 2 x 4 down", a != 0):
		return
	_note2("a brick just put down from the tray is selected: %s" % _builder.selection.has(a))
	_builder.clear_selection()
	await _frames(2)
	var box: AABB = _box_of(a)
	var b: int = 0
	var b_box := AABB()
	# Aimed at the middle of the end stud's top, back row then front row.
	for z: float in [box.position.z + 10.0, box.end.z - 10.0]:
		var end_at: Vector2 = _camera.unproject_position(Vector3(box.position.x + 10.0, box.end.y, z))
		b = await _put("3005", 14, end_at)
		await _seat_done()
		_builder.clear_selection()
		b_box = _box_of(b) if b != 0 else AABB()
		_note2("the 1 x 1 aimed at the end stud (x %.0f, z %.0f) at %s: id %d, box %s; the 2 x 4's box %s"
			% [box.position.x + 10.0, z, end_at, b, b_box, _box_of(a)])
		await _shot("sr2_riders_put_%d" % int(absf(z)))
		if b != 0 and b_box.position.y >= box.end.y - 6.0:
			break
		if b != 0:
			await _press_button("undo")
	if not _check("a 1 x 1 on its end", b != 0 and b_box.position.y >= box.end.y - 6.0):
		return
	_builder.clear_selection()
	await _frames(2)
	var other: Vector2 = _camera.unproject_position(Vector3(box.end.x - 10.0, box.end.y, box.end.z - 10.0))
	await _tap_at(other)
	await _frames(3)
	_check("a tap on the 2 x 4 selects it alone (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(a))
	var before: Dictionary = _records()
	var to: Vector2 = _base_point(0.45, 0.3) + Vector2(0, Phone.px(root, float(_simple.get("lift_points"))))
	await _one_finger(other, to)
	await _seat_done()
	await _frames(3)
	var moved: Dictionary = _changed(before, _records())
	_note2("dragged: %d moved (%s), selected after: %s, the line says \"%s\""
		% [(moved["changed"] as Array).size(), str(moved["changed"]), str(_builder.selection.keys()),
			str(_simple.call("hint"))])
	await _shot("sr2_riders_after_move")
	_check("after the drag only the brick dragged is selected (selected: %d)" % _builder.selection.size(),
		_builder.selection.size() == 1 and _builder.selection.has(a))
	var text: String = _text()
	var was: Dictionary = _records()
	await _press_swatch(1)
	await _frames(3)
	var painted: Dictionary = _changed(was, _records())
	_check("a colour tapped then paints the brick dragged, not the 1 x 1 on it (painted: %s)" % str(painted["changed"]),
		not (painted["changed"] as Array).has(b))
	if _text() != text:
		await _press_button("undo")
	_check("...Undo: as before the colour", _text() == text)
	was = _records()
	if await _press_button("delete"):
		var gone: Dictionary = _changed(was, _records())
		_check("Delete then takes off the brick dragged, not the 1 x 1 on it (gone: %s)" % str(gone["gone"]),
			not (gone["gone"] as Array).has(b))
		await _press_button("undo")
		_check("...Undo: as before Delete", _text() == text)


# -- copy ------------------------------------------------------------------------------


func _case_copy() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	_builder.clear_selection()
	await _tap_at(_top_point(a))
	await _frames(3)
	var t0: String = _text()
	var depth: int = _builder.history_depth()
	var copied: bool = _builder.selection.has(a)
	if copied:
		copied = await _press_button("copy")
	if not _check("selected, Copy shown and pressed", copied):
		return
	await _seat_done()
	var t1: String = _text()
	_check("Copy: one more part, one undo step (%d parts, %d steps)" % [_plain_ids().size(), _builder.history_depth() - depth],
		_plain_ids().size() == 2 and _builder.history_depth() == depth + 1)
	await _press_button("undo")
	_check("Undo after Copy: byte for byte as before it", _text() == t0)
	await _press_button("redo")
	_check("Redo: the copy again, byte for byte", _text() == t1)
	await _press_button("undo")
	# Ctrl+D: Full's Duplicate, kept in Simple (SIMPLE_KEEPS).
	_builder.clear_selection()
	await _tap_at(_top_point(a))
	await _frames(3)
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.ctrl_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(6)
	var carrying: bool = _builder.is_carrying()
	_note2("Ctrl+D in Simple: %d parts, in hand %s, the line \"%s\"" % [_plain_ids().size(), carrying, str(_simple.call("hint"))])
	if carrying:
		var parts: int = _plain_ids().size()
		await _press_button("undo")
		_note2("Undo with the copy in hand: %d parts (was %d), in hand %s, text as before Ctrl+D %s"
			% [_plain_ids().size(), parts, _builder.is_carrying(), _text() == t0])
		var at: Vector2 = _base_point(-0.5, 0.4)
		await _tap_at(at)
		await _frames(4)
		_note2("then a tap on the plate: %d parts, in hand %s" % [_plain_ids().size(), _builder.is_carrying()])
		if _builder.is_carrying():
			_builder.cancel_carry()
	while _builder.history_depth() > 0 and _text() != t0:
		await _press_button("undo")
	_check("back to the one 2 x 4 by Undo", _text() == t0)


# -- escape (a mouse) --------------------------------------------------------------------


func _mouse(at: Vector2, down: bool) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = down
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	press.position = _as_event(at)
	press.global_position = _as_event(at)
	Input.parse_input_event(press)


func _mouse_move(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = _as_event(at)
	Input.parse_input_event(move)


func _click(at: Vector2) -> void:
	_mouse_move(at)
	await process_frame
	_mouse(at, true)
	await process_frame
	_mouse(at, false)
	await _frames(3)


func _case_escape() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	_builder.clear_selection()
	var tile: Control = _simple.call("tile_of", "3003")
	await _click(tile.get_global_rect().get_center())
	_note2("a click on the 2 x 2's tile: chosen \"%s\"" % str(_simple.call("chosen_brick")))
	_mouse_move(_base_point(0.5, 0.5))
	await _frames(3)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)
	_mouse_move(_base_point(0.45, 0.45))
	await _frames(3)
	_note2("after Escape: chosen \"%s\", tool %s, a ghost %s, the line \"%s\"" % [str(_simple.call("chosen_brick")),
		_verbs.mode, _builder.has_preview(), str(_simple.call("hint"))])
	await _shot("sr2_after_escape")
	var parts: int = _plain_ids().size()
	await _click(_top_point(a))
	await _frames(3)
	_check("after Escape, a click on a brick selects it and puts nothing down (%d parts, was %d; selected %s)"
		% [_plain_ids().size(), parts, str(_builder.selection.keys())],
		_plain_ids().size() == parts and _builder.selection.has(a))
	_builder.clear_selection()


# -- offplate --------------------------------------------------------------------------


func _case_offplate() -> void:
	var floor: AABB = AABB()
	for spot: Array in [["over the room's top", Vector2(0.5, 0.04)], ["beside the plate, right", Vector2(-1, 0)],
			["beside the plate, left", Vector2(-2, 0)]]:
		await _fresh()
		floor = _floor_box()
		var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
		var plate: Rect2 = _screen_box(floor)
		var at: Vector2 = room.position + room.size * (spot[1] as Vector2)
		if (spot[1] as Vector2).x == -1:
			at = Vector2(minf(plate.end.x + Phone.px(root, 24.0), room.end.x - Phone.px(root, 6.0)), plate.get_center().y)
		elif (spot[1] as Vector2).x == -2:
			at = Vector2(maxf(plate.position.x - Phone.px(root, 24.0), room.position.x + Phone.px(root, 6.0)), plate.get_center().y)
		var id: int = await _put("3001", 4, at)
		await _seat_done()
		if id == 0:
			_note2("%s (%s): nothing put down, said \"%s\"" % [spot[0], at, _said()])
			continue
		var origin: Vector3 = _world.get_brick(id).transform.origin
		var on: bool = origin.x >= floor.position.x and origin.x <= floor.end.x \
			and origin.z >= floor.position.z and origin.z <= floor.end.z
		var box: AABB = _box_of(id)
		_note2("%s (%s): put down at %s, %s the plate (plate x %.0f..%.0f z %.0f..%.0f), its bottom at y %.0f"
			% [spot[0], at, origin, "on" if on else "OFF", floor.position.x, floor.end.x, floor.position.z,
				floor.end.z, box.end.y])
		await _shot("sr2_offplate_%d" % int(absf((spot[1] as Vector2).x * 10)))
		if not on:
			var before: Rect2 = _screen_box(floor)
			await _press_fit()
			var after: Rect2 = _screen_box(floor)
			_note2("...Fit then: the plate %.0f x %.0f, was %.0f x %.0f" % [after.size.x, after.size.y, before.size.x,
				before.size.y])
			await _shot("sr2_offplate_fit_%d" % int(absf((spot[1] as Vector2).x * 10)))


# -- switchmid -------------------------------------------------------------------------


func _case_switchmid() -> void:
	var lift: float = Phone.px(root, float(_simple.get("lift_points")))
	# 1. Mid tray drag.
	await _fresh()
	var t0: String = _text()
	var tile: Control = _simple.call("tile_of", "3001")
	var from: Vector2 = tile.get_global_rect().get_center()
	var to: Vector2 = _base_point(0.0, 0.0) + Vector2(0, lift)
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, to, 10)
	_main.call("use_controls", &"full")
	await _frames(3)
	_touch(0, to, false)
	await _frames(4)
	_note2("into Full mid tray drag, let go: tool %s, in hand %s, a ghost %s" % [_verbs.mode,
		_builder.held_part if _verbs.mode == "place" else "-", _builder.has_preview()])
	_check("...nothing put down", _text() == t0)
	await _tap_at(_base_point(0.2, 0.2))
	await _frames(4)
	_check("...and a tap on the model in Full puts nothing down", _text() == t0)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	# 2. A ghost shown.
	await _fresh()
	t0 = _text()
	tile = _simple.call("tile_of", "3003")
	await _tap_at(tile.get_global_rect().get_center())
	await _frames(2)
	await _tap_at(_base_point(0.1, 0.1))
	await _frames(3)
	_note2("a ghost shown: %s" % bool(_simple.call("ghost_waits")))
	_main.call("use_controls", &"full")
	await _frames(4)
	_note2("into Full: tool %s, a ghost %s" % [_verbs.mode, _builder.has_preview()])
	await _tap_at(_base_point(-0.3, 0.2))
	await _frames(4)
	_check("...a tap on the model in Full puts nothing down", _text() == t0)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	# 3. Mid move.
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	_builder.clear_selection()
	var t1: String = _text()
	var depth: int = _builder.history_depth()
	var at: Vector2 = _top_point(a)
	_touch(0, at, true)
	await process_frame
	await _drag_along(0, at, at + Vector2(Phone.px(root, 40.0), Phone.px(root, -20.0)), 8)
	_note2("mid move: moving %s" % bool(_simple.get("_moving")))
	_main.call("use_controls", &"full")
	await _frames(3)
	await _drag_along(0, at + Vector2(Phone.px(root, 40.0), Phone.px(root, -20.0)), at + Vector2(Phone.px(root, 90.0), 0), 6)
	_touch(0, at + Vector2(Phone.px(root, 90.0), 0), false)
	await _frames(4)
	_check("into Full mid move and let go: the part where it was, byte for byte, no step (%d)"
		% (_builder.history_depth() - depth), _text() == t1 and _builder.history_depth() == depth)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	# 4. Two fingers down at the switch, let go in Full.
	_builder.clear_selection()
	var empty: Vector2 = _empty_point()
	_touch(0, empty, true)
	_touch(1, empty + Vector2(Phone.px(root, 60.0), 0), true)
	await _frames(3)
	_main.call("use_controls", &"full")
	await _frames(3)
	_touch(0, empty, false)
	_touch(1, empty + Vector2(Phone.px(root, 60.0), 0), false)
	await _frames(4)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	await _tap_at(_top_point(a))
	await _frames(3)
	_check("two fingers down at the switch, let go in Full: back in Simple a tap still selects (%s)"
		% str(_builder.selection.keys()), _builder.selection.has(a))
	_builder.clear_selection()
	var put: int = await _put("3005", 1, _base_point(-0.4, -0.3))
	_check("...and a drag from the tray still puts a brick down", put != 0)
	if put != 0:
		await _press_button("undo")
	_builder.clear_selection()
	# 5. A finger held still on a part at the switch.
	t1 = _text()
	at = _top_point(a)
	_touch(0, at, true)
	var held_from: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - held_from < 700:
		await process_frame
	_main.call("use_controls", &"full")
	await _frames(3)
	_touch(0, at, false)
	await _frames(4)
	_check("a finger held on a part at the switch, let go in Full: nothing changed", _text() == t1)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	_check("...back in Simple, nothing in hand (%s)" % _verbs.mode, not _builder.is_carrying())


# -- openin ------------------------------------------------------------------------------


## A model opened while Simple is up (Open, a key Simple keeps; the header's
## Menu on the web; a link opened on a device left in Simple): seen whole?
## Simple's sketch limits how far back the view goes (SimpleLayer._set_far),
## and only entering Simple, Fit and New frame again.
func _case_openin() -> void:
	for path: String in ["res://vendor/omr/files/6685-1.mpd", "res://vendor/omr/files/10030-1.mpd"]:
		var tag: String = path.get_file().get_basename()
		# Full first, as everyone has it: Open from the bar frames the model.
		_main.call("use_controls", &"full")
		await _frames(10)
		_main.call("clear_model")
		await _frames(10)
		await _bar_open(path)
		var full_box: Rect2 = _screen_box(_main.call("_model_bounds"))
		_note2("%s opened in Full from the bar: at %.0f (farthest %.0f), the model's picture %s in the window %s"
			% [tag, float(_camera.get("_target_distance")), _camera.max_distance, full_box, root.get_visible_rect()])
		_main.call("use_controls", &"simple")
		await _frames(10)
		await _fresh()
		var far_sketch: float = _camera.max_distance
		_say_nothing()
		await _bar_open(path)
		var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
		var box: Rect2 = _screen_box(_main.call("_model_bounds"))
		var whole: bool = room.grow(2.0).encloses(box)
		var alone: int = _alone_ids().size()
		_note2("%s opened in Simple: the view's farthest %.0f (the sketch's %.0f), at %.0f; the model's picture %s in the room %s"
			% [tag, _camera.max_distance, far_sketch, float(_camera.get("_target_distance")), box, room])
		_check("%s opened in Simple is seen whole" % tag, whole)
		_check("...and the %d parts Simple leaves alone in it are said (\"%s\")" % [alone, _said()],
			alone == 0 or _said().contains("leaves"))
		await _shot("sr2_openin_%s" % tag)
		await _press_fit()
		box = _screen_box(_main.call("_model_bounds"))
		_note2("...after Fit: the model's picture %s, %s" % [box, "whole" if room.grow(2.0).encloses(box) else "NOT whole"])


## Open as a person does from the bar's list (ModelBar._on_pick): the file
## opened with its progress, then the bar's opened, which frames it.
func _bar_open(path: String) -> void:
	var bar: Node = _main.get("_bar")
	var placed: int = await bar.call("open_with_progress", ProjectSettings.globalize_path(path))
	if placed >= 0:
		bar.emit_signal("opened", placed)
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(30)
	_builder.clear_selection()
	await _settle()
	await _frames(30)


# -- unseen ------------------------------------------------------------------------------


## simple1's one put that went astray (simple_switch_probe "unshown" at 390,
## once): the check puts a part by builder calls, update_preview then a frame
## then place(), a few frames after the switch into Simple. The switch moves
## the room the model is seen in, the lens eases after it, and each eased
## frame CadCamera.lens_moved -> Main._hover_again aims the ghost again at
## the pointer: the check's ghost is replaced by one at wherever the pointer
## last was. Each arm put 12 times on 4005-1, at 0..11 frames after the
## switch, the pointer parked over the model away from the spot:
##   A  the check's put as it is;
##   B  the same with lens_moved no longer aiming the ghost (cause removed);
##   C  Simple's own put (SimpleLayer._place_at: aimed and put in one call),
##      as a person's finger does it.
func _case_unseen() -> void:
	_main.call("use_controls", &"full")
	await _frames(6)
	await _open("res://vendor/omr/files/4005-1.mpd")
	await _settle()
	await _frames(40)
	var box: AABB = _main.call("_built_bounds")
	var spot := Vector3(snappedf(box.end.x + 60.0, 20.0), 0.0, snappedf(box.get_center().z, 20.0))
	var rect: Rect2 = root.get_visible_rect()
	var parked := Vector2(rect.size.x * 0.22, rect.size.y * 0.30)
	var eased: Array = [0]
	_camera.lens_moved.connect(func() -> void: eased[0] += 1)
	# Where the part goes with the lens at rest: the spot's own answer.
	var at_rest: Vector3 = await _check_put(spot, parked)
	# Simple's own put at rest, in Simple, for arm C.
	_main.call("use_controls", &"simple")
	await _frames(4)
	await _settle()
	await _frames(40)
	var simple_rest: Vector3 = await _simple_put(spot)
	_note2("4005-1: the spot %s; put with the lens at rest at %s (the check's), %s (Simple's own)"
		% [spot, at_rest, simple_rest])
	for arm: String in ["A", "B", "C"]:
		var expected: Vector3 = simple_rest if arm == "C" else at_rest
		var hover: Callable = Callable(_main, &"_hover_again")
		if arm == "B" and _camera.lens_moved.is_connected(hover):
			_camera.lens_moved.disconnect(hover)
		var astray: Array = []
		var lens_frames: int = 0
		for wait: int in 12:
			_main.call("use_controls", &"full")
			await _frames(4)
			await _settle()
			await _frames(30)
			_park(parked)
			await _frames(2)
			eased[0] = 0
			_main.call("use_controls", &"simple")
			_builder.clear_selection()
			await _frames(wait)
			var landed: Vector3
			if arm == "C":
				landed = await _simple_put(spot)
			else:
				landed = await _check_put(spot, parked, false)
			lens_frames += int(eased[0])
			if not landed.is_equal_approx(expected):
				astray.append("%d frames: %s" % [wait, landed])
		if arm == "B" and not _camera.lens_moved.is_connected(hover):
			_camera.lens_moved.connect(hover)
		_note2("arm %s: %d of 12 astray, the lens eased %d frames in all%s" % [arm, astray.size(), lens_frames,
			("" if astray.is_empty() else " (" + "; ".join(astray) + ")")])
		_check("arm %s: every put where the lens at rest puts it" % arm, astray.is_empty())


## The pointer parked at [param at] by a move the app sees, as a finger's
## or a mouse's last place.
func _park(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)


## The check's put (pastereview_probe._place_at, one spot): a 2 x 4 aimed
## straight down at [param spot] for six frames, then place(). Where it
## landed, the part taken off again.
func _check_put(spot: Vector3, parked: Vector2, settle: bool = true) -> Vector3:
	if settle:
		_park(parked)
		await _frames(2)
	_main.call("_on_part_chosen", "3001")
	_main.call("_on_color_chosen", 14)
	for _n: int in 6:
		_builder.update_preview(spot + Vector3(0, 600, 0), Vector3.DOWN)
		await process_frame
	var id: int = _builder.place()
	return await _took_back(id)


## Simple's own put at [param spot]: the tray's part aimed at its screen
## point and put down in the one call a finger's let-go makes.
func _simple_put(spot: Vector3) -> Vector3:
	_main.call("_on_part_chosen", "3001")
	_main.call("_on_color_chosen", 14)
	var point: Vector2 = _camera.unproject_position(spot + Vector3(0, 8, 0))
	_simple.call("_place_at", point)
	var id: int = 0
	var put: Array = (_simple.get("last_drop") as Dictionary).get("put", [])
	if not put.is_empty():
		id = int(put[0])
	return await _took_back(id)


func _took_back(id: int) -> Vector3:
	_verbs.set_mode("select")
	_builder.held_part = ""
	if id == 0:
		return Vector3(INF, INF, INF)
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var at: Vector3 = brick.transform.origin if brick != null else Vector3(INF, INF, INF)
	_builder.clear_selection()
	_builder.select_brick(id, false)
	_builder.remove_selection()
	await _frames(2)
	return at


# -- save --------------------------------------------------------------------------------


func _case_save() -> void:
	for path: String in ["res://vendor/omr/files/358-1.mpd", "res://vendor/omr/files/5540-1.mpd",
			"res://vendor/omr/files/6054-1.mpd", "res://vendor/omr/files/5972-1.mpd"]:
		await _save_one(path)


func _save_one(path: String) -> void:
	var tag: String = path.get_file().get_basename()
	_main.call("use_controls", &"full")
	await _frames(6)
	var original: String = FileAccess.get_file_as_string(path)
	if not await _open(path):
		_check("%s: opened" % tag, false)
		return
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	var unedited: String = ProjectSettings.globalize_path("user://sr2_%s_unedited.mpd" % tag)
	_check("%s: saved unedited in Simple, byte for byte" % tag,
		bool(_main.call("save_model", unedited)) and FileAccess.get_file_as_string(unedited) == original)
	var was: Dictionary = _records()
	var alone: Array = _alone_ids()
	var plain: Array = []
	for id: Variant in _plain_ids():
		if not alone.has(id) and _point_on(int(id)).x < INF:
			plain.append(id)
	var why: Dictionary = {}
	for id: Variant in alone:
		var reason: String = str(_simple.call("left_alone", int(id)))
		why[reason] = int(why.get(reason, 0)) + 1
	_note2("%s: %d parts, %d left alone %s, %d plain parts a finger can land on; said \"%s\"" % [tag, was.size(),
		alone.size(), str(why), plain.size(), _said()])
	await _shot("sr2_save_%s_in_simple" % tag)
	if plain.size() < 3:
		_check("%s: three plain parts to edit" % tag, false)
		return
	# One painted and turned.
	var p1: int = int(plain[0])
	await _tap_at(_point_on(p1))
	await _frames(3)
	var colour: int = 1 if _world.get_brick(p1).color_code != 1 else 4
	await _press_swatch(colour)
	await _press_button("turn")
	# One moved by a finger.
	var p2: int = int(plain[plain.size() / 2])
	var at: Vector2 = _point_on(p2)
	if at.x < INF:
		await _one_finger(at, at + Vector2(Phone.px(root, 30.0), Phone.px(root, -10.0)))
		await _seat_done()
	# One from the tray on a third.
	var p3: int = int(plain[plain.size() - 1])
	# Let go of the part moved first: a colour tapped with it selected paints
	# it (riders).
	await _tap_at(_empty_point())
	await _frames(3)
	_builder.clear_selection()
	var top: Vector2 = _point_on(p3)
	var put: int = 0
	if top.x < INF:
		put = await _put("3005", 14, top)
		await _seat_done()
	_builder.clear_selection()
	var now: Dictionary = _records()
	var diff: Dictionary = _changed(was, now)
	_note2("%s: changed %d (%s), made %d, gone %d; said \"%s\"" % [tag, (diff["changed"] as Array).size(),
		str(diff["changed"]), (diff["made"] as Array).size(), (diff["gone"] as Array).size(), _said()])
	var touched_alone: Array = alone.filter(func(id: Variant) -> bool: return (diff["changed"] as Array).has(id))
	_check("%s: no part Simple leaves alone changed (%d)" % [tag, touched_alone.size()], touched_alone.is_empty())
	var out: String = ProjectSettings.globalize_path("user://sr2_%s_edited.mpd" % tag)
	if not _check("%s: saved after the edits" % tag, bool(_main.call("save_model", out))):
		return
	var saved: String = FileAccess.get_file_as_string(out)
	var lines_a: PackedStringArray = original.split("\n")
	var lines_b: PackedStringArray = saved.split("\n")
	var others_a := PackedStringArray()
	var others_b := PackedStringArray()
	for line: String in lines_a:
		if not line.strip_edges().begins_with("1 "):
			others_a.append(line)
	for line: String in lines_b:
		if not line.strip_edges().begins_with("1 "):
			others_b.append(line)
	_check("%s: every line not a part's kept byte for byte and in order (%d of %d)" % [tag,
		others_b.size(), others_a.size()], others_a == others_b)
	var count_a: Dictionary = {}
	for line: String in lines_a:
		if line.strip_edges().begins_with("1 "):
			count_a[line] = int(count_a.get(line, 0)) + 1
	var added: Array = []
	for line: String in lines_b:
		if line.strip_edges().begins_with("1 "):
			if int(count_a.get(line, 0)) > 0:
				count_a[line] = int(count_a[line]) - 1
			else:
				added.append(line)
	var lost: Array = []
	for line: Variant in count_a:
		for _n: int in int(count_a[line]):
			lost.append(line)
	var edited: int = (diff["changed"] as Array).size()
	_check("%s: part lines lost %d = parts changed %d + gone %d; added %d = changed + made %d" % [tag, lost.size(),
		edited, (diff["gone"] as Array).size(), added.size(), (diff["made"] as Array).size()],
		lost.size() == edited + (diff["gone"] as Array).size()
		and added.size() == edited + (diff["made"] as Array).size())
	_main.call("use_controls", &"full")
	await _frames(4)
	await _open(out)
	_check("%s: reopened in Full, every part (%d, %d before the save)" % [tag, _plain_ids().size(), now.size()],
		_plain_ids().size() == now.size())
	_main.call("use_controls", &"simple")
	await _frames(6)
