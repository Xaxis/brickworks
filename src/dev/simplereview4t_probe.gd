## simplereview4: simplereview3's headless cases (subedit, snap, locked) and
## its T2 (a finger's waiting ghost, Undo, a tap on the ghost) by the layer's
## own calls, so the one GPU slot is not needed, on both trees: simple2 as
## simplereview3 found it and simple3. Headless no touch reaches the layer
## (memory headless-simple-probe-input), so a finger's touches and drags are
## handed to SimpleLayer's own _input and _unhandled_input here.
## T2's Undo is run both ways a person gives it: Simple's big Undo button, and
## Shell's undo key (a phone's two-finger tap and Ctrl+Z both end there:
## phone_shell.gd _fingers_tapped, simple_layer.gd _fingers_tapped). What it
## puts down is judged by both plate checks: simplereview3's as written (the
## brick's bottom at the top of the plate's studs) and simple3's bca22c8ec (at
## the plate's face, 4 below).
##
##   godot --headless --path . --script src/dev/simplereview4t_probe.gd -- --headless-ok --desktop
##   godot --headless --path . --script src/dev/simplereview4t_probe.gd -- --headless-ok
##
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview3_probe.gd"


func _run() -> void:
	if not await _start("subedit,snap,locked,t2"):
		return
	for one: String in ["subedit", "snap", "locked", "t2"]:
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
			"t2":
				await _case_t2(false)
				await _case_t2(true)
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplereview4t_probe"


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _press_fit() -> void:
	if not _headless():
		await super()
		return
	_simple.call("fit")
	await _settle()


## A finger's touch, to the layer itself when headless.
func _touch(index: int, at: Vector2, down: bool) -> void:
	if not _headless():
		super(index, at, down)
		return
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = at
	_simple.call("_input", touch)
	_simple.call("_unhandled_input", touch)


func _drag(index: int, at: Vector2, by: Vector2) -> void:
	if not _headless():
		super(index, at, by)
		return
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = at
	drag.relative = by
	_simple.call("_input", drag)
	_simple.call("_unhandled_input", drag)


func _layer_tap(at: Vector2) -> void:
	_touch(0, at, true)
	await _frames(1)
	_touch(0, at, false)
	await _frames(3)


func _case_t2(by_key: bool) -> void:
	var how: String = "Shell's undo key (two fingers, Ctrl+Z)" if by_key else "Simple's Undo button"
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(-0.4, 0.0))
	await _seat_done()
	var b: int = await _put("3003", 1, _base_point(0.4, 0.3))
	await _seat_done()
	if not _check("[%s] a 2 x 4 and a 2 x 2 down" % how, a != 0 and b != 0):
		return
	_builder.clear_selection()
	_simple.call("_tap_tile", "3005")
	await _frames(2)
	var spot: Vector2 = _point_on(b)
	if spot.x == INF:
		spot = _top_point(b)
	# A finger's tap shows the ghost there; a tap on it would put it down.
	await _layer_tap(spot)
	var ghost_up: bool = _builder.has_preview()
	var ghost_at: Vector3 = _builder.ghost_transform().origin if ghost_up else Vector3.INF
	var before: Dictionary = _records()
	if by_key:
		(_main.get("_shell") as Shell).run_key("undo")
	else:
		var undo: Button = _simple.call("button", "undo")
		undo.pressed.emit()
	await _frames(4)
	var undone: Dictionary = _changed(before, _records())
	var ghost_after: bool = _builder.has_preview()
	var after_at: Vector3 = _builder.ghost_transform().origin if ghost_after else Vector3.INF
	await _layer_tap(spot)
	var placed: Dictionary = _changed(before, _records())
	_note2("[%s] a ghost shown on the 2 x 2 (%s at %s), then Undo: gone %s; the ghost %s (at %s); then a tap at it: made %s"
		% [how, ghost_up, str(ghost_at), str(undone["gone"]), ghost_after, str(after_at), str(placed["made"])])
	_check("[%s] ...a ghost was waiting on the 2 x 2 before the Undo" % how, ghost_up)
	_check("[%s] ...Undo with a ghost up takes back the last brick (gone %s)" % [how, str(undone["gone"])],
		(undone["gone"] as Array).size() == 1)
	_check("[%s] ...and the next tap puts at most one brick down (made %s)" % [how, str(placed["made"])],
		(placed["made"] as Array).size() <= 1)
	var top: float = _floor_box().end.y
	for made: Variant in placed["made"]:
		var joined: int = SelectBy.connected(_world, _builder.lattice, [int(made)], _store.scenery, 2).size() - 1
		var bottom: float = _box_of(int(made)).position.y
		var as_written: bool = bottom >= top - 1.0 and bottom <= top + 1.0
		var at_face: bool = absf(bottom - (top - 4.0)) < 1.0
		_note2("[%s] the brick put down at %s: bottom %.1f, the plate's studs' top %.1f, its face %.1f, joined to %d; on the plate by simplereview3's check %s, by simple3's %s"
			% [how, str(_world.get_brick(int(made)).transform.origin), bottom, top, top - 4.0, joined, as_written,
				at_face])
		_check("[%s] ...simplereview3's check as written: stands on something (joined %d, on the plate %s)" % [how,
			joined, as_written], joined > 0 or as_written)
		_check("[%s] ...simple3's check (bca22c8ec): stands on something (joined %d, on the plate %s)" % [how,
			joined, at_face], joined > 0 or at_face)
	if not str(_simple.call("chosen_brick")).is_empty():
		_simple.call("_tap_tile", str(_simple.call("chosen_brick")))
