## simplereview4: the fourth independent review's attacks on Simple mode with
## its own placing context (simple3: SimpleLayer sets Full's sub-assembly,
## snap, turn and tool aside on the way in and puts them back on the way out).
## Headless (a CPU slot, no GPU): the layer's own calls stand for a finger, as
## simplereview3_probe's headless cases do (no touch reaches the layer
## headless). Runs in a tree that has simplereview3_probe (simple3's branch).
##
##   godot --headless --path . --script src/dev/simplereview4_probe.gd -- --headless-ok --desktop
##   godot --headless --path . --script src/dev/simplereview4_probe.gd -- --headless-ok
##   godot --headless --path . --script src/dev/simplereview4_probe.gd -- --headless-ok --tablet
##
## --case= ctx, undo, unsaved, steps, carry, peer, hidden, session (all when not said):
##   ctx      Full with its whole context (inside a sub-assembly with a part of
##            it selected, Half snap, a 45 degree turn, the Paint tool or a
##            part in hand, x-ray, a part hidden, a part locked): into Simple
##            and out with nothing done, then with a brick put down, then with
##            a part chosen. Full's state compared field by field.
##   undo     acts in Simple and in Full in turn, then Undo and Redo across
##            the switch: the model's text byte for byte at every step.
##   unsaved  a saved file opened, into Simple and out unedited: Save writes the
##            file's bytes; a brick put in Simple: unsaved work, and the save
##            reopened has every part, the sub-model's file as it was.
##   steps    a model in its author's steps, the timeline on step 1 in Full: a
##            brick put in Simple, then Full again: is it seen, in which step.
##   carry    a part, a sub-assembly and a paste carried in Full, into Simple:
##            a tap there, what goes down and where; Undo exact.
##   peer     a waiting ghost and a chosen part, and another window's edit
##            (Together's own way) takes the part under them away.
##   hidden   a part hidden in Full, a brick from Simple's tray let go there.
##   session  a session's floor change while Simple is up (the assistant at
##            work): Simple's world follows, a drop on the new plate.
## Exits non-zero when a check fails.
extends "res://src/dev/simplereview3_probe.gd"

const STEPS_MODEL := """0 FILE sr4_steps.ldr
0 Simple and the author's steps
0 Name: sr4_steps.ldr
1 4 -40 -8 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 -40 -32 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 14 -40 -56 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
"""


func _run() -> void:
	if not await _start("ctx,undo,unsaved,same,steps,carry,peer,hidden,session"):
		return
	for one: String in ["ctx", "undo", "unsaved", "same", "steps", "carry", "peer", "hidden", "session"]:
		if not _cases.has(one):
			continue
		print("\n== %s" % one)
		match one:
			"ctx":
				await _case_ctx()
			"same":
				await _case_same()
			"undo":
				await _case_undo()
			"unsaved":
				await _case_unsaved()
			"steps":
				await _case_steps()
			"carry":
				await _case_carry()
			"peer":
				await _case_peer()
			"hidden":
				await _case_hidden()
			"session":
				await _case_session()
	print("\n%s: %s" % [_probe_name(), "all passed" if _failures == 0 else "%d failed" % _failures])
	quit(1 if _failures else 0)


func _probe_name() -> String:
	return "simplereview4_probe"


func _shell() -> Shell:
	return _main.get("_shell")


## Headless no tap reaches Fit: Simple's own Fit.
func _press_fit() -> void:
	if DisplayServer.get_name() != "headless":
		await super()
		return
	_simple.call("fit")
	await _settle()


## Full's state that Simple says it sets aside and puts back, and the rest a
## person would see change.
func _full_state() -> Dictionary:
	var shell: Shell = _shell()
	var sel: Array = _builder.selection.keys()
	sel.sort()
	var unseen: Array = _builder.lattice.unseen.keys()
	unseen.sort()
	var locked: Array = _builder.locked.keys()
	locked.sort()
	return {"entered": shell.assemblies.entered, "place_group": _builder.place_group, "snap": _verbs.snap,
		"snap_across": _builder.snap_across, "turn_step": _verbs.turn_step, "mode": _verbs.mode,
		"selection": sel, "held": [_builder.held_part, _builder.held_color, _builder.held_rotation,
			_builder.held_face], "xray": shell.see_inside.seeing_through, "unseen": unseen, "locked": locked,
		"carrying": _builder.is_carrying(), "prefs_snap": str(ShellPrefs.value("snap")),
		"controls": String(_main.call("controls_layer"))}


func _differ(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in a:
		if str(a[key]) != str(b.get(key)):
			out.append("%s: %s -> %s" % [key, str(a[key]), str(b.get(key))])
	return out


func _id_where(test: Callable) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and bool(test.call(brick)):
			return brick.id
	return 0


func _to_simple() -> void:
	_main.call("use_controls", &"simple")
	await _frames(6)
	await _settle()
	await _frames(4)


func _to_full() -> void:
	_main.call("use_controls", &"full")
	await _frames(6)


## A finger's tap at [param at], by the layer's own press and release.
func _layer_tap(at: Vector2) -> void:
	_simple.call("_press", at, 0)
	_simple.call("_release", at)
	await _frames(3)


func _undo_full() -> void:
	_shell().run("undo")
	await _frames(3)


func _redo_full() -> void:
	_shell().run("redo")
	await _frames(3)


## The model as the file opened from [param text] at user://models/, in Full:
## the path it was opened from.
func _open_saved(text: String, file: String) -> String:
	await _to_full()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR))
	var path: String = ModelStore.SAVE_DIR + file
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	await _open(path)
	_builder.forget_history()
	return path


# -- ctx ----------------------------------------------------------------------------


## FROM_FULL in Full with every piece of Full's context set: [wing path, the
## wing part selected, the plain red, the hidden blue, the turned yellow].
func _full_context(paint_tool: bool) -> Dictionary:
	await _from_full_open()
	var shell: Shell = _shell()
	var red: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 4 and b.group.is_empty())
	var blue: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 1 and b.group.is_empty())
	var yellow: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 14)
	var wing_part: int = _id_where(func(b: BrickWorld.Brick) -> bool: return not Assemblies.path_of(b).is_empty())
	_builder.clear_selection()
	_builder.select_brick(wing_part, false)
	var wing: String = shell.assemblies.selected_assembly()
	# Hidden: the blue 2 x 4; locked: the turned yellow one.
	_builder.clear_selection()
	_builder.select_brick(blue, false)
	_verbs.hide_selection()
	_builder.clear_selection()
	_builder.select_brick(yellow, false)
	_builder.lock_selection(true)
	_builder.clear_selection()
	_builder.forget_history()
	shell.assemblies.enter(wing)
	await _frames(3)
	_builder.select_brick(wing_part, false)
	_verbs.set_snap("half")
	ShellPrefs.put("snap", "half")
	_verbs.turn_step = 45.0
	if paint_tool:
		_verbs.set_mode("paint")
		_builder.held_color = 2
	else:
		_main.call("_on_part_chosen", "3062b")
		_builder.held_color = 25
		_builder.held_rotation = 1
	shell.see_inside.set_xray(true)
	await _frames(4)
	return {"wing": wing, "wing_part": wing_part, "red": red, "blue": blue, "yellow": yellow}


func _case_ctx() -> void:
	for variant: String in ["nothing", "put", "chose"]:
		for paint_tool: bool in [true, false]:
			var got: Dictionary = await _full_context(paint_tool)
			var text: String = _text()
			var s0: Dictionary = _full_state()
			var label: String = "%s, %s" % [variant, "Paint tool" if paint_tool else "a 1 x 1 round in hand"]
			_note2("[%s] Full before: %s" % [label, str(s0)])
			await _to_simple()
			var inside: Dictionary = _full_state()
			_check("[%s] in Simple: at the model's top, Stud, a quarter turn, Select (%s, %s, %.0f, %s)" % [label,
				inside["place_group"], inside["snap"], inside["turn_step"], inside["mode"]],
				str(inside["place_group"]).is_empty() and inside["snap"] == "stud" and is_equal_approx(
					float(inside["turn_step"]), 90.0) and (inside["mode"] == "select" or inside["mode"] == "place"))
			var put: int = 0
			if variant == "put" or variant == "chose":
				put = await _put("3003", 14, _base_point(0.35, 0.35))
				await _seat_done()
				var brick: BrickWorld.Brick = _world.get_brick(put)
				_check("[%s] a 2 x 2 from the tray down at the model's top (%d, group \"%s\")" % [label, put,
					brick.group if brick != null else "?"], brick != null and brick.group.is_empty())
				_note2("[%s] after the put: selection %s, chose here %s" % [label, str(_builder.selection.keys()),
					str(_simple.get("_chose_here"))])
			if variant == "chose" and put != 0:
				var at: Vector2 = _point_on(put)
				if at.x < INF:
					await _layer_tap(at)
				_check("[%s] a tap chose it (%s)" % [label, str(_builder.selection.keys())], _builder.selection.has(put))
			await _to_full()
			var s1: Dictionary = _full_state()
			var diff: Array = _differ(s0, s1)
			if variant == "chose":
				# By design: a part chosen in Simple is Full's selection, at the top.
				diff = diff.filter(func(line: String) -> bool:
					return not (line.begins_with("selection") or line.begins_with("entered")
						or line.begins_with("place_group") or line.begins_with("xray")))
			_check("[%s] back in Full, as it was: %s" % [label, "same" if diff.is_empty() else "; ".join(diff)],
				diff.is_empty())
			if variant == "nothing":
				_check("[%s] ...and the model's text byte for byte, nothing to undo (%d)" % [label,
					_builder.history_depth()], _text() == text and _builder.history_depth() == 0)
			else:
				for _n: int in 6:
					if _text() == text:
						break
					await _undo_full()
				_check("[%s] ...Full's Undo gives the model as it was, byte for byte" % label, _text() == text)
			# Leave clean for the next variant.
			_shell().assemblies.leave_to("")
			_verbs.set_mode("select")
			_verbs.set_snap("stud")
			ShellPrefs.put("snap", "stud")
			_verbs.turn_step = 90.0
			_shell().see_inside.set_xray(false)
			_builder.unlock_all()
			_builder.lattice.unseen.clear()
			_verbs.apply_hidden()
			_builder.clear_selection()


# -- undo ---------------------------------------------------------------------------


func _case_undo() -> void:
	await _from_full_open()
	_builder.forget_history()
	var texts: Array[String] = [_text()]
	var where: Array[String] = ["opened"]
	# S1: a brick from Simple's tray.
	await _to_simple()
	var a: int = await _put("3003", 4, _base_point(0.3, 0.3))
	await _seat_done()
	texts.append(_text())
	where.append("Simple: a red 2 x 2 put")
	# F1: Full paints it blue.
	await _to_full()
	_builder.clear_selection()
	_builder.select_brick(a, false)
	_builder.paint_selection(1)
	_main.call("_on_model_edited")
	await _frames(2)
	texts.append(_text())
	where.append("Full: painted blue")
	# S2: Simple turns it.
	await _to_simple()
	var at: Vector2 = _point_on(a)
	if at.x < INF:
		await _layer_tap(at)
	var turned: int = int(_simple.call("turn_selected"))
	await _frames(3)
	texts.append(_text())
	where.append("Simple: turned (%d)" % turned)
	# S3: Simple copies it.
	var copied: int = int(_simple.call("copy_selected"))
	await _frames(3)
	await _seat_done()
	texts.append(_text())
	where.append("Simple: copied (%d)" % copied)
	# F2: Full deletes the first.
	await _to_full()
	_builder.clear_selection()
	_builder.select_brick(a, false)
	_builder.remove_selection()
	_main.call("_on_model_edited")
	await _frames(2)
	texts.append(_text())
	where.append("Full: deleted the first")
	var steps: int = texts.size() - 1
	_note2("acts: %s; history depth %d" % [", ".join(where), _builder.history_depth()])
	# Undo all: two in Full, then the rest in Simple, its big button.
	var n: int = steps
	for _i: int in 2:
		await _undo_full()
		n -= 1
		_check("Full's Undo to \"%s\": byte for byte" % where[n], _text() == texts[n])
	await _to_simple()
	while n > 0:
		await _press_button("undo")
		await _frames(2)
		n -= 1
		_check("Simple's Undo to \"%s\": byte for byte" % where[n], _text() == texts[n])
	_check("...nothing more to undo but what was before", _text() == texts[0])
	# Redo all: two in Simple, the rest in Full.
	for _i: int in 2:
		await _press_button("redo")
		await _frames(2)
		n += 1
		_check("Simple's Redo to \"%s\": byte for byte" % where[n], _text() == texts[n])
	await _to_full()
	while n < steps:
		await _redo_full()
		n += 1
		_check("Full's Redo to \"%s\": byte for byte" % where[n], _text() == texts[n])


# -- unsaved ------------------------------------------------------------------------


func _case_unsaved() -> void:
	var path: String = await _open_saved(FROM_FULL, "sr4_unsaved.mpd")
	var bytes0: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var own: String = _store.saved_path(_store.title)
	_note2("opened %s (%d bytes), the model's own path %s" % [path, bytes0.size(), own])
	_check("opened: no unsaved work", not _store.has_unsaved_work())
	# Into Simple and out, nothing done, a look and Fit only.
	await _to_simple()
	await _press_fit()
	_check("in Simple, nothing done: no unsaved work", not _store.has_unsaved_work())
	await _to_full()
	_check("back in Full: no unsaved work", not _store.has_unsaved_work())
	_check("Save after Simple with nothing done", bool(_main.call("save_model", own)))
	var bytes1: PackedByteArray = FileAccess.get_file_as_bytes(own)
	_check("...writes the file's own bytes (%d of %d)" % [bytes1.size(), bytes0.size()], bytes1 == bytes0)
	# A brick put in Simple.
	var before: Dictionary = _records()
	await _to_simple()
	var put: int = await _put("3003", 14, _base_point(0.3, 0.3))
	await _seat_done()
	_check("a brick put in Simple (%d): unsaved work, in Simple" % put, put != 0 and _store.has_unsaved_work())
	await _to_full()
	_check("...and back in Full", _store.has_unsaved_work())
	_check("Save", bool(_main.call("save_model", own)))
	_check("...then no unsaved work", not _store.has_unsaved_work())
	var saved: String = FileAccess.get_file_as_string(own)
	var sub_lines: Array = _part_lines_of(saved, "simple_wing.ldr")
	_check("...the sub-model's file as it was (%d part lines: %s)" % [sub_lines.size(), ", ".join(sub_lines)],
		sub_lines.size() == 2)
	var top_lines: Array = _part_lines_of(saved, "simple_from_full.ldr")
	_check("...the main model one part line more (%d)" % top_lines.size(), top_lines.size() == 5)
	# Reopened: every part in place and colour, and the new one.
	var after: Dictionary = _records()
	await _open(own)
	var reopened: Dictionary = _records()
	var want: Array = []
	for id: Variant in after:
		want.append("%s %d %s" % [after[id][0], after[id][1], str((after[id][2] as Transform3D).origin.snapped(Vector3.ONE * 0.01))])
	var have: Array = []
	for id: Variant in reopened:
		have.append("%s %d %s" % [reopened[id][0], reopened[id][1], str((reopened[id][2] as Transform3D).origin.snapped(Vector3.ONE * 0.01))])
	want.sort()
	have.sort()
	_check("reopened: every part in place and colour (%d of %d; before Simple %d)" % [have.size(), want.size(),
		before.size()], want == have)
	# A brick put and taken back by Undo in Simple: the model is the file again.
	await _to_simple()
	var again: int = await _put("3003", 2, _base_point(-0.3, 0.3))
	await _seat_done()
	await _press_button("undo")
	await _frames(3)
	var gone: bool = _world.get_brick(again) == null
	_note2("a brick put and undone in Simple (%d gone %s): unsaved work %s, history %d, redo %d" % [again, str(gone),
		str(_store.has_unsaved_work()), _builder.history_depth(), _builder._redo.size()])
	await _to_full()
	_check("Save after a put and Undo in Simple", bool(_main.call("save_model", own)))
	_check("...writes the reopened file's bytes", FileAccess.get_file_as_string(own) == saved)


# -- same ---------------------------------------------------------------------------


## The bytes a Save writes after one act in Simple, beside the same act in
## Full on the same file: a yellow 2 x 2 put on the plate, the same place.
func _case_same() -> void:
	await _open_saved(FROM_FULL, "sr4_same.mpd")
	var own: String = _store.saved_path(_store.title)
	await _to_simple()
	var put: int = await _put("3003", 14, _base_point(0.3, 0.3))
	await _seat_done()
	var at: Transform3D = _world.get_brick(put).transform if put != 0 else Transform3D()
	await _to_full()
	_check("Simple: a yellow 2 x 2 put (%d) and saved" % put, put != 0 and bool(_main.call("save_model", own)))
	var by_simple: String = FileAccess.get_file_as_string(own)
	# The same file again, the same part put by Full's own place.
	await _open_saved(FROM_FULL, "sr4_same.mpd")
	_main.call("_on_part_chosen", "3003")
	_builder.held_color = 14
	_builder.held_rotation = 0
	await _frames(2)
	_builder.update_preview(at.origin + Vector3(0.0, 400.0, 0.0), Vector3.DOWN)
	var placed: int = _builder.place()
	await _frames(4)
	await _seat_done()
	var at_full: Transform3D = _world.get_brick(placed).transform if placed != 0 else Transform3D()
	_check("Full: the same part put (%d) and saved" % placed, placed != 0 and bool(_main.call("save_model", own)))
	var by_full: String = FileAccess.get_file_as_string(own)
	var lines_s: PackedStringArray = by_simple.split("\n")
	var lines_f: PackedStringArray = by_full.split("\n")
	var only_s: Array = []
	var only_f: Array = []
	for line: String in lines_s:
		if not lines_f.has(line):
			only_s.append(line)
	for line: String in lines_f:
		if not lines_s.has(line):
			only_f.append(line)
	_note2("Simple's put at %s, Full's at %s; %d and %d bytes; lines only in Simple's save %s; only in Full's %s"
		% [str(at.origin), str(at_full.origin), by_simple.length(), by_full.length(), str(only_s), str(only_f)])
	if at_full.is_equal_approx(at):
		_check("...the same act saves the same bytes in Simple and in Full", by_simple == by_full)
	else:
		# Put at another stud by Full's aim: only the part's own line may differ.
		_check("...the saves differ only in the one part line (Full's aim put it elsewhere)",
			only_s.size() <= 1 and only_f.size() <= 1 and lines_s.size() == lines_f.size())
	_builder.forget_history()


# -- steps --------------------------------------------------------------------------


func _case_steps() -> void:
	await _open_saved(STEPS_MODEL, "sr4_steps.ldr")
	var steps: StepsBar = _main.get("_steps")
	_main.call("_toggle_steps")
	for _n: int in 300:
		await process_frame
		if steps.is_playing_back():
			break
	await _frames(10)
	steps.show_step(1)
	await _frames(6)
	var ahead_was: int = _builder.lattice.ahead.size()
	var at: Instructions.Step = steps.current_step()
	_note2("Full: the timeline on step %d, %d parts ahead" % [at.number if at != null else -1, ahead_was])
	if not _check("Full's timeline on step 1 with parts ahead", at != null and ahead_was > 0):
		return
	await _to_simple()
	_check("in Simple: the timeline put away, the whole model (%d ahead)" % _builder.lattice.ahead.size(),
		not steps.is_playing_back() and _builder.lattice.ahead.is_empty())
	var put: int = await _put("3003", 14, _base_point(0.4, 0.4))
	await _seat_done()
	_check("a brick put in Simple (%d)" % put, put != 0)
	await _to_full()
	for _n: int in 300:
		await process_frame
		if steps.is_playing_back():
			break
	await _frames(10)
	var now: Instructions.Step = steps.current_step()
	var brick: BrickWorld.Brick = _world.get_brick(put)
	var seen: bool = put != 0 and not _builder.lattice.ahead.has(put)
	_note2("back in Full: the timeline on step %d of %d; the Simple brick's step %d, seen %s, hidden %s" % [
		now.number if now != null else -1, steps.steps().size(), brick.step if brick != null else -9, str(seen),
		str(brick.hidden if brick != null else false)])
	_check("back in Full the timeline is on step 1 again (%d)" % (now.number if now != null else -1),
		now != null and now.number == 1)
	_check("...and the brick just put in Simple is seen in Full (not ahead of the step shown)", seen)
	steps.stop()
	await _frames(4)


# -- carry --------------------------------------------------------------------------


func _case_carry() -> void:
	for one: String in ["part", "wing", "paste", "part+bin", "paste+bin"]:
		await _from_full_open()
		_builder.forget_history()
		var text: String = _text()
		# what: the label; kind: part, wing or paste. "+bin": a part chosen from
		# Full's bin first, so Full's tool is Place.
		var what: String = one
		var kind: String = one.get_slice("+", 0)
		if one.ends_with("+bin"):
			_main.call("_on_part_chosen", "3005")
		else:
			_verbs.set_mode("select")
		await _frames(2)
		var blue: int = _id_where(func(b: BrickWorld.Brick) -> bool: return b.color_code == 1 and b.group.is_empty())
		var wing_part: int = _id_where(func(b: BrickWorld.Brick) -> bool: return not Assemblies.path_of(b).is_empty())
		var id: int = blue if kind == "part" else wing_part
		var from: Vector2 = _camera.unproject_position(_box_of(id).get_center())
		var ok: bool = false
		if kind == "paste":
			_builder.clear_selection()
			_builder.select_brick(wing_part, false)
			_shell().run("copy")
			await _frames(2)
			_shell().run("paste")
			await _frames(4)
			ok = _builder.is_carrying()
		else:
			_builder.clear_selection()
			ok = _verbs.drag_start(id, false, false, [_camera.ray_origin(from), _camera.ray_normal(from)])
			await _frames(2)
		var carried: int = _builder.carrying.items.size() if _builder.is_carrying() else 0
		if not _check("[%s] Full carries it (%d parts in hand)" % [what, carried], ok and _builder.is_carrying()):
			_builder.cancel_carry()
			continue
		await _to_simple()
		_note2("[%s] in Simple: carrying %s, tool %s, the line \"%s\"" % [what, str(_builder.is_carrying()),
			_verbs.mode, str(_simple.call("hint"))])
		var spot: Vector2 = _base_point(0.4, -0.4)
		var before: Dictionary = _records()
		await _layer_tap(spot)
		await _seat_done()
		var taps: int = 1
		var ghost_after_one: bool = _builder.has_preview()
		# A finger's first tap may only show the ghost (Simple's two taps): the
		# second, on it, puts it down.
		if _builder.is_carrying() and ghost_after_one:
			await _layer_tap(spot)
			await _seat_done()
			taps = 2
		var change: Dictionary = _changed(before, _records())
		var alone: Array = []
		for brick_id: Variant in change["changed"] + change["made"]:
			var why: String = str(_simple.call("left_alone", int(brick_id)))
			if not why.is_empty():
				alone.append("%d %s" % [int(brick_id), why])
		_note2("[%s] %d tap(s) in Simple (a ghost after the first %s): still carrying %s; changed %s, made %s; Simple leaves alone of them: %s (a sub-assembly's parts, by design)"
			% [what, taps, str(ghost_after_one), str(_builder.is_carrying()), str(change["changed"]),
				str(change["made"]), str(alone)])
		_check("[%s] Simple's tap(s) put Full's carry down, nothing lost (%d parts before, %d now)" % [what,
			before.size(), _records().size()], not _builder.is_carrying() and _records().size() >= before.size())
		await _to_full()
		for _n: int in 6:
			if _text() == text:
				break
			await _undo_full()
		_check("[%s] Undo gives the model as opened, byte for byte" % what, _text() == text)
		if _builder.is_carrying():
			_builder.cancel_carry()


# -- peer ---------------------------------------------------------------------------


## Another window's change, as Together puts a peer's: past the history.
func _peer_delete(id: int) -> void:
	_world.outside += 1
	_builder.lattice.release(id)
	_world.remove_brick(id)
	_builder.selection.erase(id)
	await _frames(3)


func _case_peer() -> void:
	await _to_simple()
	await _fresh()
	var a: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	if not _check("a 2 x 4 down", a != 0):
		return
	# A ghost waiting on it for its second tap, as a finger shows one.
	_simple.call("_tap_tile", "3005")
	await _frames(2)
	var on_a: Vector2 = _point_on(a)
	await _layer_tap(on_a)
	var waiting: bool = bool(_simple.call("ghost_waits"))
	_note2("a 1 x 1 chosen, a tap on the 2 x 4: a ghost waits %s" % str(waiting))
	await _peer_delete(a)
	await _frames(4)
	_check("another window takes the 2 x 4 away: the ghost no longer waits (%s)" % str(_simple.call("ghost_waits")),
		not bool(_simple.call("ghost_waits")))
	var count: int = _records().size()
	var was: Dictionary = _records()
	await _layer_tap(on_a)
	var made: Array = _changed(was, _records())["made"]
	var floating: Array = []
	for id: int in made:
		var joined: int = SelectBy.connected(_world, _builder.lattice, [id], _store.scenery, 2).size() - 1
		var face: float = _floor_box().end.y - 4.0
		if joined == 0 and absf(_box_of(id).position.y - face) >= 1.0:
			floating.append(id)
	_check("...a tap where it was puts nothing in the air (%d parts before, %d now, floating %s)" % [count,
		_records().size(), str(floating)], floating.is_empty())
	if not str(_simple.call("chosen_brick")).is_empty():
		_simple.call("_tap_tile", str(_simple.call("chosen_brick")))
	# A part chosen in Simple taken away by another window: Turn, Copy, Delete.
	var b: int = await _put("3001", 1, _base_point(-0.3, 0.2))
	await _seat_done()
	var on_b: Vector2 = _point_on(b)
	if on_b.x < INF:
		await _layer_tap(on_b)
	_check("a blue 2 x 4 chosen in Simple", _builder.selection.has(b))
	await _peer_delete(b)
	var parts: int = _records().size()
	var depth: int = _builder.history_depth()
	var t: int = int(_simple.call("turn_selected"))
	var c: int = int(_simple.call("copy_selected"))
	var d: int = int(_simple.call("delete_selected"))
	await _frames(3)
	_check("...then Turn, Copy and Delete act on nothing (%d %d %d; parts %d -> %d; history %d -> %d)" % [t, c, d,
		parts, _records().size(), depth, _builder.history_depth()],
		t == 0 and c == 0 and d == 0 and _records().size() == parts and _builder.history_depth() == depth)


# -- hidden -------------------------------------------------------------------------


func _case_hidden() -> void:
	await _to_simple()
	await _fresh()
	var spot: Vector2 = _base_point(0.2, 0.2)
	var a: int = await _put("3001", 4, spot)
	await _seat_done()
	if not _check("a 2 x 4 down", a != 0):
		return
	var a_at: Transform3D = _world.get_brick(a).transform
	await _to_full()
	_builder.clear_selection()
	_builder.select_brick(a, false)
	_verbs.hide_selection()
	await _frames(2)
	await _to_simple()
	var count: int = int(_simple.get("counts").get("left_alone", 0))
	var b: int = await _put("3001", 1, spot)
	await _seat_done()
	var said: String = _said()
	var drop: Dictionary = _simple.get("last_drop")
	var where: String = str(_world.get_brick(b).transform.origin) if b != 0 else "-"
	_note2("a part hidden in Full where a brick from Simple's tray is let go: put %d at %s (the hidden one at %s); why \"%s\"; the line \"%s\"" % [
		b, where, str(a_at.origin), str(drop.get("why", "")), said])
	_check("...Simple says something a person can act on, or puts it where it is seen (not \"No room there\" over an empty plate)",
		b != 0 or not said.to_lower().contains("no room"))
	if b != 0:
		# What holds it up: the parts it is joined to, and whether its foot is on
		# the plate's face (the plate's box takes in its studs, 4 high).
		var joined: Array = SelectBy.connected(_world, _builder.lattice, [b], _store.scenery, 2)
		joined.erase(b)
		var seen_under: Array = joined.filter(func(id: Variant) -> bool:
			return not _builder.lattice.unseen.has(int(id)))
		var face: float = _floor_box().end.y - 4.0
		var on_plate: bool = absf(_box_of(b).position.y - face) < 1.0
		_note2("...the brick's foot %.1f over the plate's face; joined to %s, of them seen %s; Simple's taps on parts it leaves alone %d"
			% [_box_of(b).position.y - face, str(joined), str(seen_under), count])
		_check("...in Simple it stands on something a person can see (on the plate %s, on a seen part %s)" % [on_plate,
			str(seen_under)], on_plate or not seen_under.is_empty())
	_builder.lattice.unseen.clear()
	_verbs.apply_hidden()
	await _frames(2)


# -- session ------------------------------------------------------------------------


func _case_session() -> void:
	await _to_simple()
	await _fresh()
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var box_was: AABB = _simple.call("world_box")
	var said: Variant = await tools.run("set_floor", {"kind": "baseplate", "across": 32, "deep": 32})
	await _frames(6)
	var box_now: AABB = _simple.call("world_box")
	_note2("a session's set_floor 32 x 32 while Simple is up: %s; Simple's world %s -> %s" % [str(said).left(120),
		str(box_was.size), str(box_now.size)])
	_check("Simple's world follows the session's floor", box_now.size.x > box_was.size.x + 1.0)
	await _press_fit()
	# Beyond the sketch's 16 x 16, on the new plate.
	var at: Vector2 = _base_point(0.8, 0.8)
	var put: int = await _put("3003", 4, at)
	await _seat_done()
	_check("a brick put on the session's new plate past the old one (%d, why \"%s\")" % [put,
		str((_simple.get("last_drop") as Dictionary).get("why", ""))], put != 0)
	await _press_button("undo")
	await _frames(3)
	_check("...Simple's Undo takes the person's brick, not the session's floor (%d left, floor %s)" % [
		_records().size(), _store.model_floor.to_meta()], _world.get_brick(put) == null
		and _store.model_floor.to_meta().contains("32"))
