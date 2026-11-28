## simple2: Simple owns what it acts on, its world and one reset of the
## moment (simplereview2 S1-S6, A). Each act is a finger's touch (or the
## mouse's, on a desktop) through the app, as simplereview2_probe's.
##
##   godot --path . --resolution 390x844 --script src/dev/simple2_probe.gd
##   PROBE_SIZE=390x844 tools/probe.sh simple2_probe -- --pictures=DIR
##   PROBE_SIZE=820x1180 tools/probe.sh simple2_probe -- --tablet --pictures=DIR
##   PROBE_SIZE=1280x800 tools/probe.sh simple2_probe -- --desktop --pictures=DIR
##
## --case= (all when not said):
##   offworld  a brick let go from the tray over the room's top and beside
##             the plate: nothing put down, the line says why; a ghost tapped
##             off the plate is not shown.
##   fitone    one brick on the plate's corner, then Fit: the plate whole.
##   movedoff  a brick on the plate dragged off it: back where it was, no step,
##             still chosen.
##   setaside  Full's selection into Simple: nothing chosen there, Turn, Copy
##             and Delete hidden; back in Full, Full's selection again.
##   keys      (a desktop) Delete and Ctrl+D on what Simple chose; with nothing
##             chosen, Delete takes nothing.
##   fingers   (a phone or tablet) two fingers down in Simple and lifted in
##             Full, and down in Full and lifted in Simple: nothing undone,
##             and after, a tap still chooses and two fingers tapped still
##             undo (simplereview2 S5: the lift was the other side's
##             two-finger tap, and took back the last brick).
##   header    Full's header: on a phone, Redo on the bar and, where the
##             switch is not, Simple a tile of More; on a desktop every menu
##             the row had before the switch, Simple a row of "…" where the
##             switch is put away; in de/fr/es too.
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview2_probe.gd"

const AppHeader := preload("res://src/ui/app_header.gd")


func _probe_name() -> String:
	return "simple2_probe"


func _run() -> void:
	if not await _start("offworld,fitone,movedoff,setaside,keys,fingers,header"):
		return
	for one: String in ["offworld", "fitone", "movedoff", "setaside", "keys", "fingers", "header"]:
		if not _cases.has(one) or (one == "keys" and not _desktop) or (one == "fingers" and _desktop):
			continue
		print("\n== %s" % one)
		match one:
			"offworld":
				await _case_offworld()
			"fitone":
				await _case_fitone()
			"movedoff":
				await _case_movedoff()
			"setaside":
				await _case_setaside()
			"keys":
				await _case_keys()
			"fingers":
				await _case_fingers()
			"header":
				await _case_header()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


## Points off the plate in the room: over its top (the sky past the plate),
## and beside the plate either side.
func _off_points() -> Array:
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var plate: Rect2 = _screen_box(_floor_box())
	var out: Array = [["over the room's top", room.position + room.size * Vector2(0.5, 0.04)]]
	# Beside the plate on each side: where a finger's ray meets the ground
	# three studs or more off the plate, the nearest such point on each half
	# of the room. Not beside the plate's box on the screen: at 390 across it
	# spans the room, and the ground off its edges is above and below it.
	var floor: AABB = _floor_box()
	var ground := Plane(Vector3.UP, floor.end.y)
	var least: float = BrickLattice.STUD * 3.0
	var best: Array = [[], []]
	for row: int in 13:
		for column: int in 25:
			var at: Vector2 = room.position + room.size * Vector2(0.04 + 0.92 * column / 24.0, 0.12 + 0.6 * row / 12.0)
			var hit: Variant = ground.intersects_ray(_camera.ray_origin(at), _camera.ray_normal(at))
			if hit == null:
				continue
			var on: Vector3 = hit
			var off: float = maxf(maxf(floor.position.x - on.x, on.x - floor.end.x),
				maxf(floor.position.z - on.z, on.z - floor.end.z))
			if off < least:
				continue
			var half: int = 0 if at.x < plate.get_center().x else 1
			if (best[half] as Array).is_empty() or off < float(best[half][1]):
				best[half] = [at, off]
	if not (best[0] as Array).is_empty():
		out.append(["beside the plate, left", best[0][0]])
	if not (best[1] as Array).is_empty():
		out.append(["beside the plate, right", best[1][0]])
	return out


func _case_offworld() -> void:
	await _fresh()
	var spots: Array = _off_points()
	_check("a place off the plate on each side to try (%d)" % spots.size(), spots.size() >= 2)
	for spot: Array in spots:
		await _fresh()
		var t0: String = _text()
		_say_nothing()
		var id: int = await _put("3001", 4, spot[1])
		await _frames(3)
		_check("%s (%s): a tray drag let go there puts nothing down (%d)" % [spot[0], spot[1], id],
			id == 0 and _text() == t0)
		_check("...and says why (\"%s\")" % _said(), _said() == _simple.atr("Put it on the plate or on a brick"))
		_check("...nothing left in hand, no ghost", not _builder.has_preview() and not _builder.is_carrying())
	await _shot("s2_offworld")
	# A tap with a brick chosen: the ghost a tap shows, never off the plate.
	await _fresh()
	var t1: String = _text()
	var tile: Control = _simple.call("tile_of", "3003")
	await _tap_at(tile.get_global_rect().get_center())
	await _frames(2)
	var off: Vector2 = (spots[spots.size() - 1] as Array)[1]
	await _tap_at(off)
	await _frames(3)
	_check("a brick chosen, a tap off the plate: no ghost shown there (%s)" % _builder.has_preview(),
		not bool(_simple.call("ghost_waits")) and not _builder.has_preview())
	await _tap_at(off)
	await _frames(3)
	_check("...and a second tap there puts nothing down", _text() == t1)
	await _tap_at(_base_point(0.2, -0.2))
	await _frames(3)
	_check("...a tap on the plate shows its ghost there", bool(_simple.call("ghost_waits")))
	_simple.call("reset")
	await _frames(2)


func _case_fitone() -> void:
	await _fresh()
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var id: int = await _put("3001", 4, _base_point(-0.7, 0.6))
	await _seat_done()
	_check("one brick down on the plate's corner", id != 0)
	await _press_fit()
	var plate: Rect2 = _screen_box(_floor_box())
	var brick: Rect2 = _screen_box(_box_of(id)) if id != 0 else Rect2()
	_check("Fit after one brick: the plate whole in the room (%s in %s)" % [plate, room],
		room.grow(2.0).encloses(plate))
	_check("...and the brick (%s)" % brick, room.grow(2.0).encloses(brick))
	await _shot("s2_fit_one")


func _case_movedoff() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.5, 0.0))
	await _seat_done()
	if not _check("a 2 x 4 down", a != 0):
		return
	_builder.clear_selection()
	var t0: String = _text()
	var depth: int = _builder.history_depth()
	var spots: Array = _off_points()
	var to: Vector2 = (spots[spots.size() - 1] as Array)[1]
	_say_nothing()
	await _one_finger(_top_point(a), to + Vector2(0, Phone.px(root, float(_simple.get("lift_points")))))
	await _seat_done()
	await _frames(3)
	_check("a brick dragged off the plate: back where it was, byte for byte, no step (%d)"
		% (_builder.history_depth() - depth), _text() == t0 and _builder.history_depth() == depth)
	_check("...said why (\"%s\")" % _said(), _said() == _simple.atr("Put it on the plate or on a brick"))
	_check("...and it is what is chosen (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(a))
	await _shot("s2_moved_off")


func _case_setaside() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	var b: int = await _put("3003", 1, _base_point(-0.5, -0.4))
	await _seat_done()
	if not _check("two bricks down", a != 0 and b != 0):
		return
	_main.call("use_controls", &"full")
	await _frames(6)
	_builder.clear_selection()
	_builder.select_brick(a, true)
	_builder.select_brick(b, true)
	await _frames(2)
	_main.call("use_controls", &"simple")
	await _frames(6)
	_check("into Simple with two selected in Full: nothing chosen in Simple (%s)" % str(_builder.selection.keys()),
		_builder.selection.is_empty())
	var shown: Array = []
	for what: String in ["turn", "copy", "delete"]:
		var button: Button = _simple.call("button", what)
		if button != null and button.is_visible_in_tree():
			shown.append(what)
	_check("...Turn, Copy and Delete hidden (shown: %s)" % ", ".join(shown), shown.is_empty())
	var t0: String = _text()
	await _press_swatch(1)
	await _frames(3)
	_check("...a colour tapped paints nothing", _text() == t0)
	_main.call("use_controls", &"full")
	await _frames(6)
	_check("back in Full: Full's selection again (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 2 and _builder.selection.has(a) and _builder.selection.has(b))
	# Chosen in Simple: that is what Full has after.
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	await _tap_at(_top_point(b))
	await _frames(3)
	_check("a tap in Simple chooses the brick alone (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(b))
	_main.call("use_controls", &"full")
	await _frames(6)
	_check("...and Full has what was chosen in Simple (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(b))
	_builder.clear_selection()
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()


func _key(code: Key, ctrl: bool = false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.ctrl_pressed = ctrl
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)


func _case_keys() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	_builder.clear_selection()
	await _frames(2)
	var parts: int = _plain_ids().size()
	await _key(KEY_DELETE)
	_check("Delete with nothing chosen in Simple takes nothing (%d parts, was %d)" % [_plain_ids().size(), parts],
		_plain_ids().size() == parts)
	await _click(_top_point(a))
	await _frames(3)
	_check("a click chooses the brick", _builder.selection.has(a))
	await _key(KEY_D, true)
	await _seat_done()
	_check("Ctrl+D: a copy beside it, as Copy does (%d parts, in hand %s)" % [_plain_ids().size(), _builder.is_carrying()],
		_plain_ids().size() == parts + 1 and not _builder.is_carrying())
	var copy: Array = _builder.selection.keys()
	await _key(KEY_DELETE)
	_check("...Delete takes off the copy chosen (%d parts)" % _plain_ids().size(),
		_plain_ids().size() == parts and copy.size() == 1 and _world.get_brick(int(copy[0])) == null)


## Two fingers put down under one set of controls and lifted under the
## other, [param into] first (&"full" or &"simple"): the model and its undo
## as they were.
func _fingers_across(into: StringName, back: StringName, at: Vector2) -> void:
	var t0: String = _text()
	var depth: int = _builder.history_depth()
	var step := Vector2(Phone.px(root, 60.0), 0.0)
	_touch(0, at, true)
	_touch(1, at + step, true)
	await _frames(3)
	_main.call("use_controls", into)
	await _frames(3)
	_touch(0, at, false)
	_touch(1, at + step, false)
	await _frames(4)
	_check("two fingers down, the switch into %s, lifted there: nothing undone (%d steps, was %d)"
		% [into, _builder.history_depth(), depth], _text() == t0 and _builder.history_depth() == depth)
	_main.call("use_controls", back)
	await _frames(6)
	await _settle()


func _case_fingers() -> void:
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	if not _check("a 2 x 4 down", a != 0):
		return
	_builder.clear_selection()
	await _frames(2)
	await _fingers_across(&"full", &"simple", _empty_point())
	await _tap_at(_top_point(a))
	await _frames(3)
	_check("...back in Simple a tap chooses the brick (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(a))
	_builder.clear_selection()
	_main.call("use_controls", &"full")
	await _frames(6)
	await _fingers_across(&"simple", &"simple", _empty_point())
	await _tap_at(_top_point(a))
	await _frames(3)
	_check("...in Simple after, a tap chooses the brick (%s)" % str(_builder.selection.keys()),
		_builder.selection.size() == 1 and _builder.selection.has(a))
	_builder.clear_selection()
	await _frames(2)
	var before: String = _text()
	var at: Vector2 = _empty_point()
	await _fingers_down_up([at, at + Vector2(Phone.px(root, 40.0), 0.0)])
	_check("...and two fingers tapped in Simple still undo the brick", _text() != before and _world.get_brick(a) == null)
	await _press_button("redo")
	await _frames(3)
	_check("...Redo: back, byte for byte", _text() == before)


func _case_header() -> void:
	_main.call("use_controls", &"full")
	await _frames(10)
	for lang: String in ["en", "de", "fr", "es"]:
		Language.choose(lang)
		await _frames(20)
		if _phone != null:
			var redo: Control = (_phone.get("_tool_buttons") as Dictionary).get("redo")
			var switch: Control = _phone.get("_switch")
			_check("%s, Full on a phone %s: Redo on the bar" % [lang, _size], redo != null and redo.is_visible_in_tree())
			if switch != null and not switch.is_visible_in_tree():
				_phone.call("_chose", "more")
				await _frames(20)
				var tile: Control = _phone.find_child("quick_simple_mode", true, false) as Control
				_check("...no room for Simple | Full on the bar: Simple a tile of More", tile != null and tile.is_visible_in_tree())
				if lang == "en":
					await _shot("s2_more_simple")
				_phone.call("_chose", "more")
				await _frames(20)
			else:
				_note2("%s: Simple | Full on the bar" % lang)
			if lang == "en":
				await _shot("s2_full_header")
			continue
		var bar: ModelBar = _main.get("_bar")
		var buttons: Array = bar.call("_menu_buttons")
		var gutter: float = AppHeader.GUTTER_NARROW if Room.across() < 600.0 else AppHeader.GUTTER
		var pt: float = AppHeader.points(bar)
		var least: float = minf(pt, ModelBar.LEAST_PT)
		var shown: int = 0
		for button: Variant in buttons:
			if (button as Control).visible:
				shown += 1
		# The row without the switch, Simple in "…" (ModelBar._shown_at).
		var without: int = int(bar.call("_shown_at", gutter, least, false))
		_check("%s, Full on a desktop %s: %d of %d menus on the row, as many as without the switch (%d), File among them"
			% [lang, _size, shown, buttons.size(), without], shown >= without and shown >= 1
			and (buttons[0] as Control).visible)
		var fits: float = float(bar.call("_fitting_pt", gutter, without, false))
		_check("...the header no smaller for the switch (%.2f, %.2f without it)" % [bar.points, minf(pt, fits)],
			bar.points >= minf(pt, fits) - 0.01)
		if not _phone and Room.across() >= 1200.0:
			_check("...every menu on the row at %s" % _size, shown == buttons.size())
		if bar.switch_folded:
			var popup: PopupMenu = bar.more.get_popup()
			popup.about_to_popup.emit()
			var found: bool = false
			for n: int in popup.item_count:
				found = found or popup.get_item_text(n) == "Simple mode"
			# Shut as it was "opened": "…" told only "about to popup" stayed
			# drawn pressed in the picture below (submenu_probe).
			popup.popup_hide.emit()
			_check("...Simple | Full put away: Simple a row of \"…\"", bar.more.is_visible_in_tree() and found)
		else:
			_check("...Simple | Full on the row", bar.controls.is_visible_in_tree())
		if lang == "en" or lang == "fr":
			await _shot("s2_full_header_%s" % lang)
	Language.choose("en")
	await _frames(10)
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
