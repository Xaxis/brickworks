## stepreview: an independent review of stepedit (at a step, an edit reaches
## only what the step shows). The same probe runs on pre261 and on stepedit,
## from locked snapshots; its RESULT lines are compared between the two, and
## its checks are the bars a fix is judged on.
##
##   godot --path . --resolution 1280x720 --script src/dev/stepreview_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh stepreview_probe                the desktop
##   PROBE_SIZE=390x844 tools/probe.sh stepreview_probe                 a phone
##   PROBE_SIZE=1280x720 tools/probe.sh stepreview_probe --case=perf    10030 at a step
##
## --case= one of tear, tools, offstep, fixture, perf (all but perf when not said).
##   tear     346-2 at step 5: the house taken at a click, moved a stud, turned;
##            what of it moved and what stayed behind, the line after a step on,
##            undo, and the model saved and opened again part by part, each
##            part's step and sub-model included.
##   tools    the connector's tools that change a part it names, on a part of a
##            later step with no all_steps: print_part, make_unique, move_part,
##            edit_selection; replace_parts all_steps and the selection it leaves.
##   offstep  the same click, paint, Select all, Delete, undo, Select like this
##            and tool calls with the timeline put away: pre261 and stepedit must
##            say and do the same.
##   fixture  tests/fixtures/stepreview/steps_copies_fig.mpd: a sub-model used
##            twice, its second copy in a later step, and a minifigure built over
##            three steps: a paint of the first copy, and X over the torso.
##   perf     10030-1, every part selected at the timeline's end, then steps
##            back and on: each step's own time, with and without the selection.
## Pictures in shots/stepreview/. Exits non-zero when a check fails.
extends "res://src/dev/stepedit_probe.gd"

const FIX := "res://tests/fixtures/stepreview/steps_copies_fig.mpd"
const BIG := "res://vendor/omr/files/10030-1.mpd"
const SHOTS3 := "res://shots/stepreview/"
const SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect width='16' height='16' fill='#c00'/></svg>"

var _case: String = "all"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("stepreview_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.substr(7)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if _layout == "phone":
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	print("stepreview_probe: a %s window, laid out for a %s, case %s, code %s" % [_size, _layout, _case,
		"stepedit" if _builder.has_method("later_refusal") else "pre261"])
	if _case in ["all", "tear"]:
		await _tear()
	if _case in ["all", "tools"]:
		await _tools()
	if _case in ["all", "offstep"]:
		await _offstep()
	if _case in ["all", "fixture"]:
		await _fixture()
	if _case in ["all", "tools2"]:
		await _tools2()
	if _case in ["all", "drag"]:
		await _drag_house()
	if _case in ["all", "keep"]:
		await _keep()
	if _case in ["all", "undoahead"]:
		await _undo_ahead()
	if _case == "perf":
		await _perf()
	if _case == "perf2":
		await _perf2()
	print("\nstepreview_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _result(key: String, value: Variant) -> void:
	print("  RESULT %s %s = %s" % [_layout, key, str(value)])


# -- tear: a sub-assembly taken at a step, moved -----------------------------


func _tear() -> void:
	print("\nT. 346-2 at step 5: the house taken at a %s, moved and turned" % (
		"tap" if _layout == "phone" else "click"))
	if not await _at_step_5():
		return
	var house: Array = _house_part()
	if not _check("a part of the house under a point", not house.is_empty()):
		return
	var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
	var all_of: PackedInt64Array = _verbs.assemblies.ids_under(unit)
	var later: Array = Array(all_of).filter(func(id: int) -> bool: return _ahead(id))
	await _press_at(house[1])
	var took: int = _builder.selection.size()
	_result("tear.house", "%s: %d parts, %d later; a click took %d" % [unit, all_of.size(), later.size(), took])
	_result("tear.line_at_5", _line())
	# What the inspector says the sub-assembly is.
	var ids_label: Variant = _shell.inspector.get("_ids") if _shell.inspector != null else null
	var told: String = (ids_label as Label).text.replace("\n", " / ") if ids_label is Label else "(none)"
	_result("tear.inspector_at_5", told)
	var size_said: RegEx = RegEx.create_from_string("Sub-assembly of (\\d+) part")
	var sm: RegExMatch = size_said.search(told)
	_check("the inspector says no size of the house it is not (\"%s\", %d parts)" % [told.left(80), all_of.size()],
		sm == null or int(sm.get_string(1)) == all_of.size())
	# A step on, nothing more selected: what the line says of what is on.
	_steps.step_forward()
	await _frames(8)
	var on_now: int = Array(all_of).filter(func(id: int) -> bool: return not _ahead(id)).size()
	var line6: String = _line()
	_result("tear.line_at_6", "%s (selected %d, %d of the house on now)" % [line6, _builder.selection.size(), on_now])
	var said: RegEx = RegEx.create_from_string("(\\d+) of its (\\d+) parts on at this step")
	var m: RegExMatch = said.search(line6)
	_check("a step on: the line claims no count of the house on that is not so (\"%s\", %d on)"
		% [line6, on_now], m == null or int(m.get_string(1)) == on_now)
	_steps.step_back()
	await _frames(8)
	_was_ahead = _builder.lattice.ahead.duplicate()
	if _builder.selection.size() != took:
		await _press_at(house[1])
	var before: Dictionary = _full()
	var depth: int = _builder.history_depth()
	# Main's Up arrow with a selection (_nudge_by), a stud.
	_main.call("_nudge_by", Vector3i(0, 0, 10))
	var moved_n: int = _builder.history_depth() - depth
	await _frames(8)
	var after: Dictionary = _full()
	var moved: Array = _changed(before, after)
	var moved_later: Array = moved.filter(func(id: int) -> bool: return _was_ahead.has(id))
	var house_moved: int = moved.filter(func(id: int) -> bool: return all_of.has(id)).size()
	var outside: int = moved.filter(func(id: int) -> bool: return not all_of.has(id)).size()
	_result("tear.nudge", "moved %d (history +%d):%d of the house's %d, %d of its %d later parts, %d outside it; said \"%s\""
		% [moved.size(), moved_n, house_moved, all_of.size(), moved_later.size(), later.size(), outside, _said()])
	_check("a move of the house taken at a step leaves none of it behind: all %d of its parts moved, or none (%d moved)"
		% [all_of.size(), house_moved], house_moved == 0 or house_moved == all_of.size())
	await _pic3("T1_moved_at_step")
	# Its later steps shown: where the parts left behind stand.
	_steps.to_end()
	await _frames(10)
	await _pic3("T2_moved_seen_whole")
	_steps.to_start()
	for _n: int in 5:
		_steps.step_forward()
		await _frames(2)
	await _frames(6)
	# Undo puts every part back exactly.
	await _verbs.press("undo")
	await _frames(6)
	var undone: Array = _changed(before, _full())
	_check("undo puts every part back as it was, steps and sub-models too (%d differ, history %d, was %d)"
		% [undone.size(), _builder.history_depth(), depth], undone.is_empty() and _builder.history_depth() == depth)
	# Turned: the same question.
	if _builder.selection.size() != took:
		await _press_at(house[1])
	before = _full()
	await _verbs.press("rotate")
	await _frames(8)
	after = _full()
	moved = _changed(before, after)
	house_moved = moved.filter(func(id: int) -> bool: return all_of.has(id)).size()
	moved_later = moved.filter(func(id: int) -> bool: return _was_ahead.has(id))
	_result("tear.turn", "turned %d: %d of the house's %d, %d later; said \"%s\"" % [moved.size(), house_moved,
		all_of.size(), moved_later.size(), _said()])
	_check("a turn of the house taken at a step leaves none of it behind (%d of %d turned)"
		% [house_moved, all_of.size()], house_moved == 0 or house_moved == all_of.size())
	# Saved and opened again, part by part: each part's step and sub-model too.
	var wanted: Array = _signed(_full())
	await _saved_and_opened_full("stepreview tear %s" % _size, wanted, "T")


## Every part by id: [part, colour, place, step, sub-model path].
func _full() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = [brick.part_id, brick.color_code, _place(brick.transform), brick.step,
			Assemblies.path_from(brick.group, brick.unit)]
	return out


static func _signed(by_id: Dictionary) -> Array:
	var out: Array = []
	for one: Array in by_id.values():
		out.append("%s %d %s step %d in %s" % one)
	out.sort()
	return out


func _saved_and_opened_full(name: String, wanted: Array, label: String) -> void:
	_forget(name)
	_store.title = name
	if not _check("%s: saved" % label, _store.save_as(name)):
		return
	var path: String = ModelStore.saved_path(name)
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(20)
	var now: Array = _signed(_full())
	var missing: Array = wanted.filter(func(one: String) -> bool: return not now.has(one))
	var extra: Array = now.filter(func(one: String) -> bool: return not wanted.has(one))
	if not _check("%s: opened again, part by part with steps and sub-models as saved (%d parts, %d wanted; %d missing, %d not wanted)"
			% [label, now.size(), wanted.size(), missing.size(), extra.size()], now == wanted):
		for one: String in missing.slice(0, 4):
			print("      missing  %s" % one)
		for one: String in extra.slice(0, 4):
			print("      extra    %s" % one)
	_forget(name)


# -- tools: a part of a later step named -------------------------------------


func _tools() -> void:
	print("\nK. the connector's tools on a part of a later step, no all_steps")
	if not await _at_step_5():
		return
	var house: Array = _house_part()
	if house.is_empty():
		return
	var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
	var all_of: PackedInt64Array = _verbs.assemblies.ids_under(unit)
	var later: Array = Array(all_of).filter(func(id: int) -> bool: return _ahead(id))
	var shown: int = int(house[0])
	var one: int = int(later[0])
	_result("tools.parts", "shown #%d %s, later #%d %s" % [shown, _world.get_brick(shown).part_id, one,
		_world.get_brick(one).part_id])
	var cases: Array = [
		["print_part", {"brick": one, "sticker": true, "side": "+z", "svg": SVG, "name": "stepreview"}],
		["print_part", {"brick": one, "svg": SVG, "name": "stepreview2"}],
		["make_unique", {"brick": one}],
		["move_part", {"part": str(one), "degrees": 30}],
		["edit_model", {"recolor": [{"bricks": [str(one)], "color": PAINT}], "picture": false}],
		["edit_model", {"remove": [one], "all_steps": "true", "picture": false}],
	]
	for case: Array in cases:
		var before: Dictionary = _full()
		var depth: int = _builder.history_depth()
		var words: String = await _call(str(case[0]), case[1])
		await _frames(6)
		var diff: Array = _changed(before, _full())
		var reached: Array = diff.filter(func(id: int) -> bool: return _was_ahead.has(id))
		_result("tools.%s" % case[0], "%s -> %d parts differ, %d of a later step, history +%d: %s"
			% [JSON.stringify(case[1]).left(90), diff.size(), reached.size(), _builder.history_depth() - depth,
				words.left(220).replace("\n", " / ")])
		_check("%s on a later step's part, no all_steps: no part of a later step changed (%d)"
			% [case[0], reached.size()], reached.is_empty())
		while _builder.history_depth() > depth:
			_builder.undo()
			await _frames(2)
		await _frames(4)
	# edit_selection, the selection on show, a later part inside its box.
	await _press_at(house[1])
	var before2: Dictionary = _full()
	var words2: String = await _call("edit_selection", {"recolor": [{"bricks": [one], "color": PAINT}],
		"picture": false})
	var diff2: Array = _changed(before2, _full())
	_result("tools.edit_selection", "%d differ, %d later: %s" % [diff2.size(),
		diff2.filter(func(id: int) -> bool: return _was_ahead.has(id)).size(), words2.left(200).replace("\n", " / ")])
	_check("edit_selection on a later part: nothing of a later step changed",
		diff2.filter(func(id: int) -> bool: return _was_ahead.has(id)).is_empty())
	# replace_parts all_steps: the later parts changed, as asked; then the
	# selection it leaves, and a Delete of it.
	var part: String = _world.get_brick(one).part_id
	var depth3: int = _builder.history_depth()
	var before3: Dictionary = _full()
	var words3: String = await _call("replace_parts", {"find": {"part": part}, "replace": {"color": PAINT},
		"all_steps": true})
	await _frames(6)
	var diff3: Array = _changed(before3, _full())
	var sel_later: int = _builder.selection.keys().filter(func(id: int) -> bool: return _ahead(id)).size()
	_result("tools.replace_all_steps", "%d differ (%d later); then %d selected, %d of them not on show; line \"%s\"; %s"
		% [diff3.size(), diff3.filter(func(id: int) -> bool: return _was_ahead.has(id)).size(),
			_builder.selection.size(), sel_later, _line(), words3.left(200).replace("\n", " / ")])
	_check("after replace_parts all_steps, the person's selection holds nothing not on show (%d)" % sel_later,
		sel_later == 0)
	var before4: Dictionary = _full()
	await _verbs.press("delete")
	await _frames(6)
	var diff4: Array = _changed(before4, _full())
	_result("tools.delete_after", "Delete then took %d, %d of them later" % [diff4.size(),
		diff4.filter(func(id: int) -> bool: return _was_ahead.has(id)).size()])
	while _builder.history_depth() > depth3:
		_builder.undo()
		await _frames(2)


# -- tools2: each call on a model opened afresh at step 5 ---------------------


## Each call from 346-2 opened again at step 5, the later part's state said
## first: what one call left (an undo puts a part back under a new number)
## never decides the next.
func _tools2() -> void:
	print("\nK2. the gate's inputs, each on 346-2 opened afresh at step 5")
	var cases: Array = [
		["edit_model", {"recolor": [{"bricks": ["L"], "color": PAINT}], "picture": false}, "a number as an int"],
		["edit_model", {"recolor": [{"bricks": ["'L"], "color": PAINT}], "picture": false}, "a number as a string"],
		["edit_model", {"remove": ["L"], "all_steps": "true", "picture": false}, "all_steps as the string \"true\""],
		["edit_model", {"remove": ["L"], "all_steps": 1, "picture": false}, "all_steps as 1"],
		["edit_selection", {"recolor": [{"bricks": ["L"], "color": PAINT}], "picture": false}, "the house selected"],
		["replace_parts", {"find": {"part": "P"}, "replace": {"color": PAINT}, "all_steps": "true"}, "all_steps \"true\""],
		["print_part", {"brick": "L", "svg": SVG, "name": "stepreview"}, "a print"],
	]
	for case: Array in cases:
		if not await _at_step_5():
			return
		var house: Array = _house_part()
		var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
		var later: Array = Array(_verbs.assemblies.ids_under(unit)).filter(func(id: int) -> bool: return _ahead(id))
		var one: int = int(later[0])
		var part: String = _world.get_brick(one).part_id
		if str(case[0]) == "edit_selection":
			await _press_at(house[1])
		var args: Dictionary = _filled(case[1], one, part)
		var before: Dictionary = _full()
		var depth: int = _builder.history_depth()
		var words: String = await _call(str(case[0]), args)
		await _frames(6)
		var diff: Array = _changed(before, _full())
		var reached: Array = diff.filter(func(id: int) -> bool: return _was_ahead.has(id))
		_result("tools2.%s" % case[0], "%s (#%d later: %s) -> %d differ, %d later, history +%d: %s" % [case[2], one,
			_ahead(one) or not _world.get_brick(one), diff.size(), reached.size(), _builder.history_depth() - depth,
			words.left(200).replace("\n", " / ")])
		_check("%s, %s, at step 5 on a later part: refused or nothing of a later step changed (%d)"
			% [case[0], case[2], reached.size()], reached.is_empty())


## [param args] with "L" the later part's number, "'L" it as a string, and "P"
## its part.
static func _filled(args: Variant, one: int, part: String) -> Variant:
	if args is Dictionary:
		var out: Dictionary = {}
		for key: Variant in args:
			out[key] = _filled(args[key], one, part)
		return out
	if args is Array:
		return (args as Array).map(func(v: Variant) -> Variant: return _filled(v, one, part))
	if args is String and args == "L":
		return one
	if args is String and args == "'L":
		return str(one)
	if args is String and args == "P":
		return part
	return args


# -- undoahead: a later part a session changed, put back by the person's undo --


## At step 5 a session's print_part swaps a later step's part for a printed
## one; the person's Undo puts the part back. Is it still a part of its later
## step: not drawn, not under a click, not changed by the person's edits?
func _undo_ahead() -> void:
	print("\nU. a later part swapped by a session, put back by Undo, at step 5")
	if not await _at_step_5():
		return
	var house: Array = _house_part()
	var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
	var later: Array = Array(_verbs.assemblies.ids_under(unit)).filter(func(id: int) -> bool: return _ahead(id))
	var one: int = int(later[0])
	var step_of: int = _world.get_brick(one).step
	var words: String = await _call("print_part", {"brick": one, "svg": SVG, "name": "stepreview"})
	await _frames(6)
	await _verbs.press("undo")
	await _frames(10)
	var back: int = _builder._live(one)
	var brick: BrickWorld.Brick = _world.get_brick(back)
	_result("undoahead.back", "#%d (step %d) printed (%s), undone: #%d, step %d, ahead %s, hidden %s, ahead now %d (was %d)"
		% [one, step_of, words.left(60), back, brick.step if brick != null else -1, _ahead(back),
			brick.hidden if brick != null else false, _builder.lattice.ahead.size(), _was_ahead.size()])
	_check("the part Undo put back is still of its later step: not drawn and passed through at step 5 (ahead %s, hidden %s)"
		% [_ahead(back), brick.hidden if brick != null else false],
		brick != null and _ahead(back) and brick.hidden)
	# The person's own click and colour on it.
	var took: bool = _builder.select_brick(back, false)
	_builder.held_color = PAINT
	var before: Dictionary = _full()
	await _verbs.press("paint")
	await _frames(6)
	var diff: Array = _changed(before, _full())
	_result("undoahead.paint", "select_brick took it: %s; a colour then changed %d (it among them: %s)"
		% [took, diff.size(), diff.has(back)])
	_check("the person's paint at step 5 does not reach the later part Undo put back", not diff.has(back))


# -- drag: the house taken at step 5, dragged a little -----------------------


func _drag_house() -> void:
	print("\nD. 346-2 at step 5: the house dragged")
	if not await _at_step_5():
		return
	var house: Array = _house_part()
	var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
	var all_of: PackedInt64Array = _verbs.assemblies.ids_under(unit)
	await _press_at(house[1])
	var before: Dictionary = _full()
	var depth: int = _builder.history_depth()
	var to: Vector2 = (house[1] as Vector2) + Vector2(-90, 40)
	var how: Array = await _drag_from(house[1], to, 24)
	await _frames(10)
	var after: Dictionary = _full()
	var moved: Array = _changed(before, after)
	var of_house: int = moved.filter(func(id: int) -> bool: return all_of.has(id)).size()
	var later_moved: int = moved.filter(func(id: int) -> bool: return _was_ahead.has(id)).size()
	_result("drag.house", "grabbed %s carried %s: %d parts changed, %d of the house's %d, %d later; history +%d; said \"%s\""
		% [how[0], how[1], moved.size(), of_house, all_of.size(), later_moved, _builder.history_depth() - depth, _said()])
	_check("a drag of the house taken at a step leaves none of it behind (%d of %d moved)" % [of_house, all_of.size()],
		of_house == 0 or of_house == all_of.size())
	_steps.to_end()
	await _frames(10)
	await _pic3("D1_dragged_seen_whole")
	# Saved and opened again, each part's step and sub-model included.
	await _saved_and_opened_full("stepreview drag %s" % _size, _signed(_full()), "D")
	# A paint at step 5, saved and opened again the same way.
	if not await _at_step_5():
		return
	await _press_at(house[1])
	_builder.held_color = PAINT
	await _verbs.press("paint")
	await _frames(6)
	await _saved_and_opened_full("stepreview paint %s" % _size, _signed(_full()), "P")


# -- keep: the selection over steps back and on, undo, another model ----------


func _keep() -> void:
	print("\nS. the selection over a step back and on, an undo, another model")
	if not await _at_step_5():
		return
	var house: Array = _house_part()
	var unit: String = str(_verbs.assemblies.unit_path_of(int(house[0])))
	var all_of: PackedInt64Array = _verbs.assemblies.ids_under(unit)
	# Taken whole at the end, then back to step 5.
	_steps.to_end()
	await _frames(8)
	# A part of the house a click reaches with the whole model on (the roof
	# covers the first one).
	var spot: Vector2 = Vector2.INF
	for id: int in all_of:
		spot = _point_on(id)
		if spot != Vector2.INF:
			break
	await _press_at(spot)
	var at_end: int = _builder.selection.size()
	_steps.to_start()
	for _n: int in 5:
		_steps.step_forward()
		await _frames(2)
	await _frames(6)
	var at5: int = _builder.selection.size()
	var later_sel: int = _builder.selection.keys().filter(func(id: int) -> bool: return _ahead(id)).size()
	_result("keep.back", "taken at the end %d; at step 5 %d selected, %d of them not on; line \"%s\"" % [at_end, at5,
		later_sel, _line()])
	# An undo of an edit made at step 5, then the end.
	var before: Dictionary = _full()
	_builder.held_color = PAINT
	await _verbs.press("paint")
	await _frames(6)
	var painted: int = _changed(before, _full()).size()
	await _verbs.press("undo")
	await _frames(6)
	var undone: int = _changed(before, _full()).size()
	_steps.to_end()
	await _frames(8)
	_result("keep.after_undo", "painted %d at step 5, undo left %d differing; at the end %d selected (taken %d)"
		% [painted, undone, _builder.selection.size(), at_end])
	# Back to step 5, another model opened, this one again at step 5 and on.
	_steps.to_start()
	for _n: int in 5:
		_steps.step_forward()
		await _frames(2)
	await _frames(4)
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(FIX)
	_bar.opened.emit(placed)
	await _frames(20)
	var on_fix: int = _builder.selection.size()
	_shell.run("timeline")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	_steps.to_start()
	await _frames(4)
	_steps.to_end()
	await _frames(6)
	_result("keep.other_model", "another model opened: %d selected; its timeline to the end: %d selected"
		% [on_fix, _builder.selection.size()])
	_check("another model's timeline puts back nothing let go of in the last (%d)" % _builder.selection.size(),
		_builder.selection.is_empty())


# -- offstep: the same edits with the timeline put away ----------------------


func _offstep() -> void:
	print("\nO. 346-2, the timeline put away: the same edits")
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(SET)
	_bar.opened.emit(placed)
	await _frames(30)
	_builder.clear_selection()
	_verbs.set_mode("select")
	await _settle()
	await _frames(10)
	_result("off.ahead", _builder.lattice.ahead.size())
	# The house's biggest part on screen, as at a step.
	var best: Array = []
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		var unit: Variant = _verbs.assemblies.unit_path_of(brick.id)
		if unit == null or str(unit).is_empty():
			continue
		var under: int = _verbs.assemblies.ids_under(str(unit)).size()
		if under <= most:
			continue
		var at: Vector2 = _point_on(brick.id)
		if at == Vector2.INF:
			continue
		best = [brick.id, at]
		most = under
	if not _check("a part of the house under a point", not best.is_empty()):
		return
	await _press_at(best[1])
	_result("off.click", "%d selected; \"%s\"" % [_builder.selection.size(), _line()])
	var before: Dictionary = _full()
	_builder.held_color = PAINT
	await _verbs.press("paint")
	await _frames(6)
	_result("off.paint", "%d painted; \"%s\"" % [_changed(before, _full()).size(), _said()])
	await _verbs.press("undo")
	await _frames(6)
	_result("off.undo_paint", "%d differ" % _changed(before, _full()).size())
	before = _full()
	_main.call("_nudge_by", Vector3i(0, 0, 10))
	await _frames(6)
	_result("off.nudge", "moved %d" % _changed(before, _full()).size())
	await _verbs.press("undo")
	await _frames(6)
	var took: int = _verbs.select_by("all")
	await _frames(4)
	_result("off.select_all", "%d; \"%s\"" % [took, _said()])
	took = _verbs.select_by("all")
	await _frames(4)
	_result("off.select_all_again", "%d; \"%s\"; timeline open %s" % [took, _said(), _steps.is_playing_back()])
	before = _full()
	await _verbs.press("delete")
	await _frames(6)
	_result("off.delete", "%d gone; \"%s\"" % [_changed(before, _full()).size(), _said()])
	await _verbs.press("undo")
	await _frames(6)
	_result("off.undo_delete", "%d differ" % _changed(before, _full()).size())
	_builder.clear_selection()
	_builder.set("_hovered", int(best[0]))
	_result("off.select_alike", _builder.select_alike())
	_builder.clear_selection()
	var part: String = _world.get_brick(int(best[0])).part_id
	_result("off.replace_preview", (await _call("replace_parts", {"find": {"part": part}, "preview": true})
		).left(200).replace("\n", " / "))
	before = _full()
	var said: String = await _call("edit_model", {"recolor": [{"bricks": [int(best[0])], "color": PAINT}],
		"picture": false})
	_result("off.edit_model", "%d differ: %s" % [_changed(before, _full()).size(), said.left(120).replace("\n", " / ")])
	_builder.undo()
	await _frames(4)
	before = _full()
	said = await _call("mirror_parts", {"bricks": [int(best[0])], "picture": false})
	_result("off.mirror_parts", "%d differ: %s" % [_changed(before, _full()).size(), said.left(120).replace("\n", " / ")])


# -- fixture: copies in later steps, a figure over three steps ---------------


func _fixture() -> void:
	print("\nF. a sub-model used twice, a figure built over three steps")
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(FIX)
	_bar.opened.emit(placed)
	await _frames(30)
	var posts: Dictionary = {}
	var torso: int = 0
	var head: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_from(brick.group, brick.unit)
		if path.to_lower().contains("post"):
			if not posts.has(path):
				posts[path] = []
			(posts[path] as Array).append(brick.id)
		if brick.part_id.begins_with("973"):
			torso = brick.id
		if brick.part_id.begins_with("3626"):
			head = brick.id
	_result("fix.parts", "%d parts; posts %s; torso #%d head #%d, figure_of(torso) %d" % [_world.bricks().size(),
		str(posts.keys()), torso, head, _builder.figure_of(torso).size() if torso != 0 else 0])
	_shell.run("timeline")
	for _n: int in 600:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(6)
	_steps.to_start()
	await _frames(4)
	var copies_done: bool = false
	var figure_done: bool = false
	for n: int in 16:
		_steps.step_forward()
		await _frames(6)
		var at: Instructions.Step = _steps.current_step()
		var paths: Array = posts.keys()
		if not copies_done and paths.size() == 2:
			var first: Array = posts[paths[0]]
			var second: Array = posts[paths[1]]
			var a_on: bool = first.all(func(id: int) -> bool: return not _ahead(id))
			var b_ahead: bool = second.all(func(id: int) -> bool: return _ahead(id))
			var b_on: bool = second.all(func(id: int) -> bool: return not _ahead(id))
			var a_ahead: bool = first.all(func(id: int) -> bool: return _ahead(id))
			if (a_on and b_ahead) or (b_on and a_ahead):
				copies_done = true
				var shown: Array = first if a_on else second
				await _copies_at(shown, (second if a_on else first), at)
		if not figure_done and torso != 0 and head != 0 and not _ahead(torso) and _ahead(head):
			figure_done = true
			await _figure_at(torso, head, at)
	_check("the fixture showed a copy on with the other later (%s) and the torso on, the head later (%s)"
		% [copies_done, figure_done], copies_done and figure_done)


func _copies_at(shown: Array, later: Array, at: Instructions.Step) -> void:
	_was_ahead = _builder.lattice.ahead.duplicate()
	var point: Vector2 = _point_on(int(shown[-1]))
	if point == Vector2.INF:
		point = _point_on(int(shown[0]))
	if not _check("a part of the copy on show under a point", point != Vector2.INF):
		return
	await _press_at(point)
	var line: String = _line()
	var before: Dictionary = _full()
	_builder.held_color = PAINT
	await _verbs.press("paint")
	await _frames(6)
	var diff: Array = _changed(before, _full())
	var reached: Array = diff.filter(func(id: int) -> bool: return later.has(id))
	_result("fix.copies", "at step %d: a click took %d (\"%s\"); paint changed %d, %d of them the later copy's; said \"%s\""
		% [at.number if at != null else -1, _builder.selection.size(), line, diff.size(), reached.size(), _said()])
	_check("a paint at a step that also paints another copy in a later step says so (\"%s\")" % _said(),
		reached.is_empty() or _said().contains("cop"))
	await _pic3("F1_copy_painted")
	await _verbs.press("undo")
	await _frames(6)


func _figure_at(torso: int, head: int, at: Instructions.Step) -> void:
	_was_ahead = _builder.lattice.ahead.duplicate()
	_builder.clear_selection()
	var before: Dictionary = _full()
	var depth: int = _builder.history_depth()
	# X over the torso: Main's KEY_X, the part under the pointer lifted.
	var lifted: bool = _builder.lift_brick(torso)
	await _frames(6)
	var now: Dictionary = _full()
	var gone: Array = before.keys().filter(func(id: int) -> bool: return not now.has(id))
	var later_gone: Array = gone.filter(func(id: int) -> bool: return _was_ahead.has(id))
	_result("fix.figure_lift", "at step %d: lifted %s, %d parts off the model, %d of them later (the head %s)"
		% [at.number if at != null else -1, lifted, gone.size(), later_gone.size(), "too" if gone.has(head) else "stays"])
	_check("X over a figure's torso at a step lifts no part of a later step (%d)" % later_gone.size(),
		later_gone.is_empty())
	if _builder.is_carrying() or lifted:
		_verbs.put_away()
		await _frames(4)
	while _builder.history_depth() > depth:
		_builder.undo()
		await _frames(2)
	_result("fix.figure_back", "%d differ after putting it back" % _changed(before, _full()).size())


# -- perf: 10030 at a step, a big selection ----------------------------------


func _perf() -> void:
	print("\nP. 10030-1: a step back and on, with every part selected and with none")
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(BIG)
	_bar.opened.emit(placed)
	await _frames(60)
	_result("perf.parts", _world.bricks().size())
	_shell.run("timeline")
	for _n: int in 900:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(10)
	for selected: bool in [false, true, false, true]:
		_steps.to_end()
		await _frames(10)
		_builder.clear_selection()
		if selected:
			_verbs.select_by("all")
		await _frames(6)
		var count: int = _builder.selection.size()
		var back: Array = []
		var on: Array = []
		for _n: int in 12:
			var t0: int = Time.get_ticks_usec()
			_steps.step_back()
			back.append(Time.get_ticks_usec() - t0)
			await _frames(2)
		for _n: int in 12:
			var t0: int = Time.get_ticks_usec()
			_steps.step_forward()
			on.append(Time.get_ticks_usec() - t0)
			await _frames(2)
		back.sort()
		on.sort()
		_result("perf.%s" % ("selected" if selected else "none"), "%d selected: a step back median %.1f ms max %.1f; on median %.1f ms max %.1f; %d selected after"
			% [count, back[6] / 1000.0, back[-1] / 1000.0, on[6] / 1000.0, on[-1] / 1000.0, _builder.selection.size()])
	# A click on a sub-assembly at a step, its words asked.
	_steps.to_start()
	for _n: int in 40:
		_steps.step_forward()
	await _frames(10)
	_builder.clear_selection()
	var big: int = 0
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _ahead(brick.id):
			continue
		var unit: Variant = _verbs.assemblies.unit_path_of(brick.id)
		if unit == null or str(unit).is_empty():
			continue
		var under: int = _verbs.assemblies.ids_under(str(unit)).size()
		if under > most:
			most = under
			big = brick.id
	var t1: int = Time.get_ticks_usec()
	_builder.select_brick(big, false)
	_result("perf.click", "a sub-assembly of %d parts at a step: select_brick %.1f ms, %d selected"
		% [most, (Time.get_ticks_usec() - t1) / 1000.0, _builder.selection.size()])
	var longest: float = 0.0
	for _n: int in 60:
		await process_frame
		longest = maxf(longest, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_result("perf.frames_selected", "longest frame of 60 with it selected %.1f ms" % longest)


## Where the time goes: a click on 10030's biggest sub-assembly at step 40,
## each frame after it, and each listener of the selection timed alone; then a
## step back with every part selected, keep_shown and the outline alone.
func _perf2() -> void:
	print("\nP2. 10030-1: where a click's and a step's time goes")
	if _steps.is_playing_back():
		_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(BIG)
	_bar.opened.emit(placed)
	await _frames(60)
	_shell.run("timeline")
	for _n: int in 900:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(10)
	_steps.to_start()
	for _n: int in 40:
		_steps.step_forward()
	await _frames(20)
	var big: int = 0
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _ahead(brick.id):
			continue
		var unit: Variant = _verbs.assemblies.unit_path_of(brick.id)
		if unit == null or str(unit).is_empty():
			continue
		var under: int = _verbs.assemblies.ids_under(str(unit)).size()
		if under > most:
			most = under
			big = brick.id
	for trial: int in 2:
		_builder.clear_selection()
		await _frames(20)
		var t0: int = Time.get_ticks_usec()
		_builder.select_brick(big, false)
		var took: float = (Time.get_ticks_usec() - t0) / 1000.0
		var frames: PackedStringArray = PackedStringArray()
		for _n: int in 12:
			var f0: int = Time.get_ticks_usec()
			await process_frame
			frames.append("%.0f" % ((Time.get_ticks_usec() - f0) / 1000.0))
		_result("perf2.click%d" % trial, "%d of a %d-part sub-assembly selected in %.1f ms; the next frames ms %s"
			% [_builder.selection.size(), most, took, ",".join(frames)])
	# Each listener alone.
	var parts: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var whole: String = _verbs.assemblies.selected_assembly()
	parts["selected_assembly"] = Time.get_ticks_usec() - t
	# (parts_beyond, timed here too, went with c61134fd4.)
	var inspector: Inspector = _shell.inspector
	if inspector != null:
		inspector.set("_shown", "")
		t = Time.get_ticks_usec()
		inspector.call("_refresh", true)
		parts["inspector"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	_shell.outliner.call("_mark_selected")
	parts["outliner"] = Time.get_ticks_usec() - t
	var outline: Variant = _main.get("_outline")
	t = Time.get_ticks_usec()
	(outline as Object).call("show_selection", _builder.selection)
	parts["outline"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	_builder.selection_changed.emit(_builder.selection.size())
	parts["emit_all"] = Time.get_ticks_usec() - t
	var said: PackedStringArray = PackedStringArray()
	for key: String in parts:
		said.append("%s %.1f" % [key, int(parts[key]) / 1000.0])
	_result("perf2.listeners_ms", ", ".join(said) + " (whole \"%s\")" % whole)
	# A step back with every part selected: keep_shown and the outline alone.
	_steps.to_end()
	await _frames(10)
	_verbs.select_by("all")
	await _frames(10)
	var keep_ms: Array = []
	var step_ms: Array = []
	for _n: int in 6:
		var s0: int = Time.get_ticks_usec()
		_steps.step_back()
		step_ms.append((Time.get_ticks_usec() - s0) / 1000.0)
		await _frames(2)
	if _builder.has_method("keep_shown"):
		for _n: int in 6:
			var k0: int = Time.get_ticks_usec()
			_builder.call("keep_shown")
			keep_ms.append((Time.get_ticks_usec() - k0) / 1000.0)
	t = Time.get_ticks_usec()
	_builder.selection_changed.emit(_builder.selection.size())
	var emit_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	(outline as Object).call("show_selection", _builder.selection)
	var outline_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	_result("perf2.step_ms", "%d selected: steps back %s ms; keep_shown with nothing to do %s ms; one selection_changed %.1f ms; one outline %.1f ms"
		% [_builder.selection.size(), str(step_ms), str(keep_ms), emit_ms, outline_ms])


func _pic3(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS3))
	root.get_texture().get_image().save_png("%s%s_%s_%s.png" % [SHOTS3, _size, _layout, name])
