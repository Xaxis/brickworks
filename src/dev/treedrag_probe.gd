## A model tree row carried onto another: by the mouse, and by a finger on a
## phone and a tablet (treedrag, 2026-11-11: no row's drag ever began unless
## that row was already chosen, so nobody's did).
##
##   godot --headless --path . --script src/dev/treedrag_probe.gd
##   godot --headless --path . --script src/dev/treedrag_probe.gd -- --phone
##   godot --headless --path . --script src/dev/treedrag_probe.gd -- --tablet
##   godot --headless --path . --script src/dev/treedrag_probe.gd -- --rows
##
## On 7140-1. Headless, where the place a drop is read at is the pointer the
## events gave (in a window it is the system's pointer, which a parsed event
## never moves). The mouse, each from a row not chosen, pressed and moved as
## a hand does and as a check's events do (no relative motion):
## - onto a sub-model's row: inside it, an outline on that row as it is over
##   it; one undo step, and the model, its sub-models and steps as before
##   after Undo, as dropped after Redo, after Save and after it is opened
##   again from that file;
## - a sub-model's sub-model onto the model's row: at the top, the same;
## - a suggested section onto another: merged, the model unchanged;
## - onto the 3D view, onto its own row, its own parent's, and a row inside
##   it: nothing changed, and no outline over the rows it may not go in;
## - a press let go where it came down, and one moved less than the window's
##   drag threshold: no drag, the row chosen.
## A finger (--phone, --tablet): held still, then moved onto a sub-model's
## row: inside it, the same undo, redo, save and reopen; one that moves at
## once, down and across, the tree's scroll; one held still and lifted: no
## drag; none changing the model.
## Both: on a model shared to look at, and while 10179-1 is being laid,
## no drag and no drop, nothing changed and no file written.
## --rows: sereview's row hits, the window 1400 x 900 and then 1280 x 720
## as its probe set them, at the top, part way and the bottom of the
## scrolled tree, a row near the middle pressed and moved 24 x 16 px as
## sereview's probe moved it: the drag carries that row.
extends SceneTree

var _main: Node
var _shell: Shell
var _store: ModelStore
var _world: BrickWorld
var _library: PartLibrary
var _builder: Builder
var _outliner: Outliner
var _tree: Tree
var _bar: ModelBar
var _out: String = ""
var _finger: bool = false
var _saves: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var rows: bool = args.has("--rows")
	_finger = args.has("--phone") or args.has("--tablet")
	if _finger:
		Phone._on = 1
		Phone._wide = args.has("--tablet")
	Account.where = "user://probe_session.json"
	Account._clear()
	_out = OS.get_user_data_dir().path_join("treedrag")
	DirAccess.make_dir_recursive_absolute(_out.path_join("files"))
	await process_frame
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
	if _finger and DisplayServer.get_name() == "headless":
		# A phone's window and a tablet's, as a person holds them.
		root.size = Vector2i(390, 844) if not Phone.wide() else Vector2i(1180, 820)
		await _frames(30)
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_store.keeps = false
	_world = _main.get("_world")
	_library = _main.get("_library")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	Download.folder = _out.path_join("files")
	print("\ntreedrag: %s, window %s, %s, %s" % [_kind(), str(root.get_visible_rect().size),
		DisplayServer.get_name(), "a tablet's layout" if Phone.wide() else "a phone's layout"
		if Phone.on() else "the desktop's"])
	await _open_file("res://vendor/omr/files/7140-1.mpd", "7140-1")
	if not await _show_tree():
		_finish()
		return
	if rows:
		await _rows()
	elif _finger:
		await _by_finger()
	else:
		await _by_mouse()
	await _gates()
	_finish()


func _finish() -> void:
	print("\ntreedrag: %s, %d failure(s)" % [_kind(), _failures])
	quit(1 if _failures > 0 else 0)


# -- the mouse -----------------------------------------------------------------------


func _by_mouse() -> void:
	var paths: PackedStringArray = _shell.assemblies.paths()
	print("\n  %d sub-models: %s" % [paths.size(), ", ".join(paths.slice(0, 6))])
	# A top-level figure onto a sub-model, as a hand moves (relative motion).
	var figure: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Minifig"))
	var vehicle: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Support Vehicle"))
	await _model_drop("a figure onto the support vehicle, as a hand moves", figure, vehicle,
		vehicle + "/" + Assemblies.leaf(figure), true)
	# A sub-model's sub-model onto the model's row, as a check's events move.
	var engine: String = _first(_shell.assemblies.paths(), func(p: String) -> bool:
		return Assemblies.parent_of(p).begins_with("Ship") and p.contains("Engine"))
	await _model_drop("a ship's engine onto the model, as a check moves", engine, "",
		Assemblies.leaf(engine), false)
	# Nothing changed: onto the 3D view, its own row, its own parent, a row in it.
	var ship: String = _first(_shell.assemblies.paths(), func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Ship"))
	var wing: String = _first(_shell.assemblies.paths(), func(p: String) -> bool:
		return Assemblies.parent_of(p) == ship)
	await _no_drop("the ship onto the 3D view", ship, "@view")
	await _no_drop("the ship onto its own row", ship, ship)
	await _no_drop("a wing onto its own ship", wing, ship)
	await _no_drop("the ship onto a wing in it", ship, wing)
	# A click, and a move under the threshold: no drag.
	await _no_drag("a click on a row not chosen", wing, Vector2.ZERO)
	await _no_drag("a move of 6 px", vehicle,
		Vector2(float(root.gui_drag_threshold) * 0.6, 0.0))
	await _suggestions()


## [param from]'s row carried onto [param onto]'s ("" the model's), with
## [param relative] motion or none, and the model checked: it is inside as
## [param lands], one undo step, and as it was after Undo, as dropped after
## Redo, Save and a reopen.
func _model_drop(what: String, from: String, onto: String, lands: String, relative: bool) -> void:
	print("\n  %s (%s -> %s)" % [what, from, onto if not onto.is_empty() else "Model"])
	if from.is_empty():
		_check("%s: the rows in sight" % what, false)
		return
	var before: Array = _state()
	var depth: int = _builder.history_depth()
	var seen: Dictionary = await _carry(from, onto, relative)
	var after: Array = _state()
	var paths: PackedStringArray = _shell.assemblies.paths()
	_check("%s: carried %s, the outline on the row under it %s (%s), dropped: it is %s" % [what,
		seen.get("carried"), seen.get("outline"), seen.get("under"), lands if paths.has(lands)
		else "not there (%s)" % ", ".join(paths)], seen.get("carried") == from
		and bool(seen.get("outline")) and paths.has(lands) and not paths.has(from))
	await _round_trip(what, before, after, depth)


## Undo, Redo, Save and opened again from the file.
func _round_trip(what: String, before: Array, after: Array, depth: int) -> void:
	_check("%s: one undo step (%d -> %d)" % [what, depth, _builder.history_depth()],
		_builder.history_depth() == depth + 1)
	await _shell.verbs.press("undo")
	await _frames(6)
	_check("%s: Undo: the model, its sub-models and steps as before %s" % [what,
		_unlike(before, _state())], _state() == before)
	await _shell.verbs.press("redo")
	await _frames(6)
	_check("%s: Redo: as dropped %s" % [what, _unlike(after, _state())], _state() == after)
	_saves += 1
	var name: String = "treedrag %s %d" % [_kind(), _saves]
	var stored: bool = _store.save_as(name)
	var text: String = FileAccess.get_file_as_string(ModelStore.saved_path(name))
	_check("%s: saved (%s, %d bytes, nothing unsaved after it %s)" % [what, stored, text.length(),
		not _store.has_unsaved_work()], stored and not text.is_empty() and not _store.has_unsaved_work())
	await _open_text(text, name)
	var reopened: Array = _state()
	_check("%s: opened again from the file: as dropped %s" % [what, _unlike(after, reopened)],
		reopened == after)
	await _show_tree()


## Carried and let go where nothing may take it: no change, no undo step,
## and no outline over the row.
func _no_drop(what: String, from: String, onto: String) -> void:
	if from.is_empty() or onto.is_empty():
		_check("%s: the rows in sight" % what, false)
		return
	var before: Array = _state()
	var depth: int = _builder.history_depth()
	var seen: Dictionary = await _carry(from, onto, true)
	_check("%s: carried %s, an outline %s, the model as it was %s, undo steps %d -> %d" % [what,
		seen.get("carried"), seen.get("outline"), _unlike(before, _state()), depth,
		_builder.history_depth()], seen.get("carried") == from and not bool(seen.get("outline"))
		and _state() == before and _builder.history_depth() == depth)


func _no_drag(what: String, path: String, by: Vector2) -> void:
	var at: Vector2 = (await _rect(path)).get_center()
	var before: Array = _state()
	_move(at, 0, Vector2.ZERO)
	await _frames(3)
	_button(at, true)
	await _frames(4)
	var began: bool = false
	for step: int in 6:
		_move(at + by * float(step + 1) / 6.0, MOUSE_BUTTON_MASK_LEFT, by / 6.0)
		await _frames(2)
		began = began or root.gui_is_dragging()
	_button(at + by, false)
	await _frames(8)
	var chosen: TreeItem = _tree.get_selected()
	_check("%s: a drag began %s; chosen %s; the model as it was %s" % [what, began,
		str(chosen.get_metadata(0)) if chosen != null else "(none)", _state() == before],
		not began and chosen != null and str(chosen.get_metadata(0)) == path and _state() == before)


func _suggestions() -> void:
	print("\n  a suggested section onto another")
	_shell.run("suggest_sections")
	var list: Array = []
	var until: int = Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < until:
		await process_frame
		if _outliner.sections != null:
			list = _outliner.sections.sections.suggested
			if list.size() >= 2:
				break
	if list.size() < 2:
		_check("suggestions made (%d)" % list.size(), false)
		return
	await _frames(10)
	var first: String = Outliner.SUGGESTION + str(list[0].number)
	var second: String = Outliner.SUGGESTION + str(list[1].number)
	var before: Array = _state()
	var count: int = list.size()
	var seen: Dictionary = await _carry(first, second, true)
	var now: int = _outliner.sections.sections.suggested.size()
	_check("suggestion %s onto %s: carried %s, the outline %s, %d suggestions -> %d, the model as it was %s" % [
		first, second, seen.get("carried"), seen.get("outline"), count, now, _state() == before],
		seen.get("carried") == first and bool(seen.get("outline")) and now == count - 1 and _state() == before)
	_outliner.call("_strip_pressed", "sections_dismiss")
	await _frames(30)


## A row pressed (not chosen), moved past the threshold, on to [param onto]'s
## row ("" the model's, "@view" the 3D view) and let go. What the drag
## carried, whether the tree outlined the row under it as it was over it,
## and that row.
func _carry(from: String, onto: String, relative: bool) -> Dictionary:
	_builder.clear_selection()
	await _frames(10)
	var at: Vector2 = (await _rect(from)).get_center()
	var out: Dictionary = {"carried": "(no drag)", "outline": false, "under": "(none)"}
	if at == Vector2.ZERO:
		return out
	_move(at, 0, Vector2.ZERO)
	await _frames(3)
	_button(at, true)
	await _frames(4)
	# Past the threshold, then on to where the row is now: the press chose
	# a row, which can lay the tree out again.
	var now: Vector2 = at
	for step: int in 6:
		var next: Vector2 = at + Vector2(4.0 * (step + 1), 0.0)
		_move(next, MOUSE_BUTTON_MASK_LEFT, (next - now) if relative else Vector2.ZERO)
		now = next
		await _frames(2)
		if root.gui_is_dragging():
			out["carried"] = _drag_name(root.gui_get_drag_data())
	var goal: Vector2 = root.get_visible_rect().get_center()
	if onto != "@view":
		goal = (await _rect(onto)).get_center()
	if goal == Vector2.ZERO:
		goal = now
	for step: int in 12:
		var next: Vector2 = now.lerp(goal, float(step + 1) / 12.0)
		_move(next, MOUSE_BUTTON_MASK_LEFT, (next - now) if relative else Vector2.ZERO)
		now = next
		await _frames(2)
		if root.gui_is_dragging() and out["carried"] == "(no drag)":
			out["carried"] = _drag_name(root.gui_get_drag_data())
	await _frames(4)
	var local: Vector2 = _tree.get_global_transform_with_canvas().affine_inverse() * goal
	if onto != "@view" and _tree.get_global_rect().has_point(goal):
		var row: TreeItem = _tree.get_item_at_position(local)
		out["under"] = str(row.get_metadata(0)) if row != null else "(none)"
		out["outline"] = root.gui_is_dragging() and _tree.drop_mode_flags != 0 \
			and _tree.get_drop_section_at_position(local) == 0
	_button(goal, false)
	await _frames(10)
	if root.gui_is_dragging():
		root.gui_cancel_drag()
		await _frames(2)
	return out


func _drag_name(data: Variant) -> String:
	if not data is Dictionary:
		return str(data)
	if (data as Dictionary).has("suggestion"):
		return Outliner.SUGGESTION + str((data as Dictionary)["suggestion"])
	return str((data as Dictionary).get("assembly", data))


# -- a finger ------------------------------------------------------------------------


func _by_finger() -> void:
	var paths: PackedStringArray = _shell.assemblies.paths()
	var figure: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Minifig"))
	print("\n  a finger held on %s, then moved onto a sub-model's row in sight" % figure)
	var before: Array = _state()
	var depth: int = _builder.history_depth()
	var seen: Dictionary = await _finger_carry(figure, "@sight", 0.7, Vector2.ZERO)
	var lands: String = str(seen.get("onto")) + "/" + Assemblies.leaf(figure)
	var after: Array = _state()
	paths = _shell.assemblies.paths()
	var what: String = "%s: held, then moved" % _kind()
	_check("%s: carried %s onto %s, the outline on %s %s, dropped: %s" % [what, seen.get("carried"),
		seen.get("onto"), seen.get("under"), seen.get("outline"), lands if paths.has(lands) else "not there"],
		seen.get("carried") == figure and bool(seen.get("outline")) and paths.has(lands)
		and not paths.has(figure))
	await _round_trip(what, before, after, depth)
	paths = _shell.assemblies.paths()
	var other: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Minifig"))
	for gesture: Array in [["moved down at once (a scroll)", 0.0, Vector2(0.0, 90.0)],
			["moved across at once", 0.0, Vector2(90.0, 0.0)],
			["held still and lifted", 0.7, Vector2.ZERO]]:
		before = _state()
		depth = _builder.history_depth()
		seen = await _finger_carry(other, "" if gesture[2] == Vector2.ZERO else "@by", float(gesture[1]),
			gesture[2])
		_check("%s: %s: a drag began %s, the model as it was %s, undo steps %d -> %d" % [_kind(),
			gesture[0], seen.get("carried") != "(no drag)", _state() == before, depth,
			_builder.history_depth()], seen.get("carried") == "(no drag)" and _state() == before
			and _builder.history_depth() == depth)


## A finger down on [param from]'s row, held [param hold] seconds, then
## moved onto [param onto]'s row ("@sight" a sub-model's row it may go into,
## in sight once it has been held; "@by" by [param by]; "" not moved) and
## lifted, as a phone's touch screen sends it (the window makes the mouse's
## events of it, as on a phone). Nothing scrolls the tree while the finger
## is down, as nothing would: a target out of sight is no target.
func _finger_carry(from: String, onto: String, hold: float, by: Vector2) -> Dictionary:
	_builder.clear_selection()
	await _frames(10)
	var out: Dictionary = {"carried": "(no drag)", "outline": false, "under": "(none)", "onto": "(none)"}
	var at: Vector2 = (await _rect(from)).get_center()
	if at == Vector2.ZERO:
		return out
	_touch(at, true)
	await _frames(2)
	if hold > 0.0:
		var until: int = Time.get_ticks_msec() + roundi(hold * 1000.0)
		while Time.get_ticks_msec() < until:
			await process_frame
	var now: Vector2 = at
	var goal: Vector2 = at + by
	if onto != "@by" and not onto.is_empty():
		# Where the rows are now that the press has chosen one (the tree may
		# have been laid out again by it), as the person sees them.
		var rows: Dictionary = _in_sight()
		if onto == "@sight":
			onto = _target_in_sight(from, rows, at)
		out["onto"] = onto
		if not rows.has(onto):
			_touch(now, false)
			await _frames(10)
			return out
		goal = (rows[onto] as Rect2).get_center()
	if not onto.is_empty():
		for step: int in 14:
			var next: Vector2 = now.lerp(goal, float(step + 1) / 14.0) if step < 13 else goal
			_drag(next, next - now)
			now = next
			await _frames(2)
			if root.gui_is_dragging() and out["carried"] == "(no drag)":
				out["carried"] = _drag_name(root.gui_get_drag_data())
	await _frames(4)
	var local: Vector2 = _tree.get_global_transform_with_canvas().affine_inverse() * now
	if _tree.get_global_rect().has_point(now):
		var row: TreeItem = _tree.get_item_at_position(local)
		out["under"] = str(row.get_metadata(0)) if row != null else "(none)"
		out["outline"] = root.gui_is_dragging() and _tree.drop_mode_flags != 0 \
			and _tree.get_drop_section_at_position(local) == 0
	_touch(now, false)
	await _frames(10)
	if root.gui_is_dragging():
		root.gui_cancel_drag()
		await _frames(2)
	return out


## Whether a row is one a drag carries: a sub-model's or a suggestion's
## (not the model's, nor the suggestions' heading). The probe's own, so it
## runs on a build before the fix, for its red.
func _carryable(meta: String) -> bool:
	return not meta.is_empty() and meta != Outliner.SUGGESTED


## The row in sight, of [param rows], that [param from] (a sub-model at
## the top) may go into: another at the top, not a figure where one is in
## sight (a figure goes into a vehicle more often than into a figure), the
## nearest to [param at] but not under it. "" when there is none.
func _target_in_sight(from: String, rows: Dictionary, at: Vector2) -> String:
	var best: String = ""
	var best_score: float = INF
	for meta: String in rows:
		if meta.is_empty() or meta == from or not Assemblies.parent_of(meta).is_empty() \
				or not _carryable(meta) or meta.begins_with(Outliner.SUGGESTION) \
				or (rows[meta] as Rect2).has_point(at):
			continue
		var score: float = (rows[meta] as Rect2).get_center().distance_to(at) \
			+ (10000.0 if meta.begins_with("Minifig") else 0.0)
		if score < best_score:
			best_score = score
			best = meta
	return best


# -- the gates -----------------------------------------------------------------------


func _gates() -> void:
	print("\n  the gates")
	var paths: PackedStringArray = _shell.assemblies.paths()
	var from: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Minifig"))
	var onto: String = _first(paths, func(p: String) -> bool:
		return Assemblies.parent_of(p).is_empty() and p.begins_with("Support Vehicle"))
	var files: Dictionary = _files()
	var before: Array = _state()
	_shell.read_only = true
	var heard: Array[String] = []
	var hear: Callable = func(text: String) -> void: heard.append(text)
	_bar.said.connect(hear)
	var seen: Dictionary = {}
	if _finger:
		seen = await _finger_carry(from, "@sight", 0.7, Vector2.ZERO)
	else:
		seen = await _carry(from, onto, true)
	_bar.said.disconnect(hear)
	var said: String = " | ".join(heard)
	_shell.read_only = false
	_check("%s: on a model shared to look at: a drag began %s, said \"%s\", the model as it was %s, files the same %s" % [
		_kind(), seen.get("carried") != "(no drag)", said, _state() == before, _files() == files],
		seen.get("carried") == "(no drag)" and said.contains("shared to look at")
		and _state() == before and _files() == files)
	# Asked while 10179-1 is being laid: a carry from 7140-1's tree, the
	# drop asked for once the laying has begun (the rows are gone with it).
	var data: Variant = {"assembly": from}
	var onto_at: Vector2 = (await _rect(onto)).get_center()
	var local: Vector2 = _tree.get_global_transform_with_canvas().affine_inverse() * onto_at
	var could: bool = bool(_outliner.call("_can_drop", local, data))
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/10179-1.mpd")
	_main.call("clear_model")
	await _frames(4)
	_bar.open_text_with_progress(text, "10179-1")
	var laid_seen: bool = false
	for _n: int in 600:
		await process_frame
		if _store.laying:
			laid_seen = true
			break
	var rows: Dictionary = _in_sight()
	var refused: bool = not bool(_outliner.call("_can_drop", local, data))
	var press: String = "(no row in sight)"
	var began: bool = false
	for meta: String in rows:
		if not _carryable(meta):
			continue
		var at: Vector2 = (rows[meta] as Rect2).get_center()
		_button(at, true)
		await _frames(2)
		for step: int in 8:
			_move(at + Vector2(4.0 * (step + 1), 0.0), MOUSE_BUTTON_MASK_LEFT, Vector2(4.0, 0.0))
			await _frames(1)
			began = began or root.gui_is_dragging()
		_button(at + Vector2(32.0, 0.0), false)
		press = meta
		break
	var still: bool = _store.laying
	_check("%s: while 10179-1 is laid (%s, still %s): the drop asked of 7140-1's carried row %s before, refused %s; a row's drag (%s) began %s; files the same %s" % [
		_kind(), laid_seen, still, could, refused, press, began, _files() == files],
		laid_seen and could and refused and not began and _files() == files)
	if root.gui_is_dragging():
		root.gui_cancel_drag()
	for _n: int in 3000:
		if not _store.laying:
			break
		await process_frame


## Every file the app could have written, by path, with its size and time.
func _files() -> Dictionary:
	var out: Dictionary = {}
	for dir: String in [ModelStore.SAVE_DIR, _out.path_join("files")]:
		for name: String in DirAccess.get_files_at(dir):
			var path: String = dir.path_join(name)
			out[path] = [FileAccess.get_size(path), FileAccess.get_modified_time(path)]
	return out


# -- sereview's rows -----------------------------------------------------------------


## sereview_probe's row hits (bench/results/sereview-2026-11-09/probe): the
## tree opened whole and scrolled to its top, part way and its foot, a row
## near the middle of those in sight pressed and moved 3 x 2 px eight times
## with no relative motion, as that probe moves it: the drag carries it.
func _rows() -> void:
	for size: Vector2i in [Vector2i(1400, 900), Vector2i(1280, 720)]:
		# The window at that size, as sereview's probe set it.
		root.size = size
		await _frames(30)
		if await _show_tree():
			await _rows_at(size)


func _rows_at(size: Vector2i) -> void:
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var row: TreeItem = stack.pop_back()
		if row == null:
			continue
		row.collapsed = false
		for child: TreeItem in row.get_children():
			stack.append(child)
	await _frames(10)
	var most: float = 0.0
	for _w: int in 200:
		var was: float = _tree.get_scroll().y
		_wheel(MOUSE_BUTTON_WHEEL_DOWN)
		await _frames(2)
		if is_equal_approx(was, _tree.get_scroll().y):
			break
	most = _tree.get_scroll().y
	for _w: int in 200:
		var was: float = _tree.get_scroll().y
		_wheel(MOUSE_BUTTON_WHEEL_UP)
		await _frames(2)
		if is_equal_approx(was, _tree.get_scroll().y):
			break
	for goal: float in [0.0, most * 0.5, most]:
		for _w: int in 200:
			if _tree.get_scroll().y >= goal - 1.0:
				break
			_wheel(MOUSE_BUTTON_WHEEL_DOWN)
			await _frames(2)
		await _frames(4)
		var rects: Dictionary = _in_sight()
		var keys: Array = rects.keys().filter(func(m: String) -> bool:
			return not m.is_empty() and not m.begins_with(Outliner.SUGGESTION) and m != Outliner.SUGGESTED)
		keys.sort_custom(func(a: String, b: String) -> bool:
			return (rects[a] as Rect2).position.y < (rects[b] as Rect2).position.y)
		if keys.is_empty():
			_check("%dx%d scrolled %d px: a row in sight" % [size.x, size.y, roundi(_tree.get_scroll().y)], false)
			continue
		var target: String = keys[keys.size() / 2]
		var at: Vector2 = (rects[target] as Rect2).get_center()
		var scrolled: int = roundi(_tree.get_scroll().y)
		var before: Array = _state()
		_button(at, true)
		await _frames(2)
		for step: int in 8:
			_move(at + Vector2(3.0 * (step + 1), 2.0 * (step + 1)), MOUSE_BUTTON_MASK_LEFT, Vector2.ZERO)
			await _frames(2)
		var data: Variant = root.gui_get_drag_data() if root.gui_is_dragging() else null
		var carried: String = _drag_name(data) if data != null else "(no drag)"
		if root.gui_is_dragging():
			root.gui_cancel_drag()
		_move(at, MOUSE_BUTTON_MASK_LEFT, Vector2.ZERO)
		await _frames(2)
		_button(at, false)
		await _frames(6)
		_check("%dx%d scrolled %d px: %d rows in sight, drag carried %s (pressed %s); the model as it was %s" % [
			size.x, size.y, scrolled, rects.size(), carried, target, _state() == before],
			carried == target and _state() == before)


## The rows in sight, metadata -> their rect in the window: as the tree draws
## them (get_item_area_rect is already scrolled).
func _in_sight() -> Dictionary:
	var out: Dictionary = {}
	var area: Rect2 = _tree.get_global_rect()
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var row: TreeItem = stack.pop_back()
		var rect: Rect2 = _tree.get_item_area_rect(row)
		if rect.size != Vector2.ZERO:
			rect.position += area.position
			if area.has_point(rect.get_center()):
				out[str(row.get_metadata(0))] = rect
		if not row.collapsed:
			for child: TreeItem in row.get_children():
				stack.append(child)
	return out


func _wheel(wheel: MouseButton) -> void:
	var over: Vector2 = _as_event(_tree.get_global_rect().get_center())
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = wheel
		event.pressed = down
		event.factor = 1.0
		event.position = over
		event.global_position = over
		Input.parse_input_event(event)


# -- the app -------------------------------------------------------------------------


## The model, its sub-models and steps: each sub-model's parts counted by
## what each copy is a copy of, and each part's step by what it is and
## where (a file opened again numbers both anew).
func _state() -> Array:
	var tree: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var kinds := PackedStringArray()
		for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
			kinds.append(Assemblies.definition(segment))
		var kind: String = "/".join(kinds)
		tree[kind] = int(tree.get(kind, 0)) + 1
	var steps: Dictionary = {}
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		for brick_id: int in step.brick_ids:
			steps[_key_of(brick_id)] = ("%d.%d" % [step.number, step.callout_step]) \
				if step.in_callout() else str(step.number)
	return [tree, steps]


func _key_of(brick_id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return "#%d" % brick_id
	var at: Transform3D = brick.transform
	var b: Basis = at.basis
	return "%s@%d,%d,%d/%d%d%d%d%d%d" % [brick.part_id, roundi(at.origin.x * 10.0),
		roundi(at.origin.y * 10.0), roundi(at.origin.z * 10.0), roundi(b.x.x), roundi(b.x.z),
		roundi(b.y.y), roundi(b.z.x), roundi(b.z.z), roundi(b.x.y)]


## How [param got] differs from [param want], briefly: "" when it does not.
func _unlike(want: Array, got: Array) -> String:
	if want == got:
		return ""
	var bits: PackedStringArray = []
	var a: Dictionary = want[0]
	var b: Dictionary = got[0]
	for kind: String in a:
		if int(b.get(kind, -1)) != int(a[kind]):
			bits.append("%s %d -> %d" % [kind, int(a[kind]), int(b.get(kind, 0))])
	for kind: String in b:
		if not a.has(kind):
			bits.append("%s new %d" % [kind, int(b[kind])])
	var moved: int = 0
	for key: String in want[1]:
		if str((got[1] as Dictionary).get(key, "")) != str(want[1][key]):
			moved += 1
	if moved > 0 or (want[1] as Dictionary).size() != (got[1] as Dictionary).size():
		bits.append("%d parts in another step (%d -> %d placed)" % [moved, (want[1] as Dictionary).size(),
			(got[1] as Dictionary).size()])
	return "(not: %s)" % "; ".join(bits.slice(0, 6))


func _first(paths: PackedStringArray, test: Callable) -> String:
	for path: String in paths:
		if test.call(path):
			return path
	return ""


func _open_file(path: String, name: String) -> void:
	await _open_text(FileAccess.get_file_as_string(path), name)


func _open_text(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var opened: Dictionary = await _bar.open_text_with_progress(text, name)
	_bar.opened.emit(int(opened.get("placed", 0)))
	for _n: int in 3000:
		if not _store.laying:
			break
		await process_frame
	await _frames(20)


func _show_tree() -> bool:
	var dock: Variant = _main.get("_props_dock")
	if dock == null:
		dock = _main.get("_bin_dock")
	if dock is SideDock and not (dock as SideDock).is_open():
		(dock as SideDock).set_open(true, false)
		await _frames(20)
	if not _shell.outliner.is_open():
		_shell.outliner.set_open(true)
	await _frames(20)
	_outliner = _shell.outliner
	_tree = _outliner.get("_tree")
	var shown: bool = _tree.is_visible_in_tree() and _tree.get_root() != null
	if not shown:
		_check("%s: the model tree shown" % _kind(), false)
	return shown


## Where [param path]'s row is in the window, scrolled into sight as a
## person scrolls to it (and a carry, at the tree's edge); an empty rect when
## it has none.
func _rect(path: String) -> Rect2:
	# The tree drawn again after the last change of what is chosen: it looks
	# twice a second (Outliner._process), and drawn again it scrolls to the
	# row chosen, which moves every row under a place read before it.
	await create_timer(0.6).timeout
	await _frames(2)
	var row: TreeItem = _outliner.call("_find", _tree.get_root(), path)
	if row == null:
		return Rect2()
	var up: TreeItem = row.get_parent()
	while up != null:
		up.collapsed = false
		up = up.get_parent()
	_tree.scroll_to_item(row)
	await _frames(4)
	row = _outliner.call("_find", _tree.get_root(), path)
	if row == null:
		return Rect2()
	var rect: Rect2 = _tree.get_item_area_rect(row)
	if rect.size == Vector2.ZERO:
		return Rect2()
	rect.position += _tree.get_global_rect().position
	return rect if _tree.get_global_rect().has_point(rect.get_center()) else Rect2()


func _kind() -> String:
	return "tablet" if Phone.wide() else "phone" if Phone.on() else "desktop"


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _move(at: Vector2, mask: int, relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.button_mask = mask
	motion.relative = _as_event_by(relative)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _drag(at: Vector2, by: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _as_event(at)
	drag.relative = _as_event_by(by)
	drag.screen_relative = drag.relative
	drag.velocity = drag.relative * 60.0
	Input.parse_input_event(drag)


## A place in the window's units as an event gives it, in its pixels, by
## the window's own transform: headless, with no screen, that is 1/25 (the
## window is 0 x 0), so a place is never rounded to a pixel, which there is
## 25 units, a row.
func _as_event(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


## A move by so much, likewise.
func _as_event_by(by: Vector2) -> Vector2:
	return root.get_final_transform().basis_xform(by)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
