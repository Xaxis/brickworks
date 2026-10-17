## Sections on real sets: suggested, accepted, broken out and put back,
## exploded, evaluated, and the same over MCP.
##
##   godot --headless --path . --script src/dev/sections_probe.gd
##   godot --path . --resolution 1400x900 --script src/dev/sections_probe.gd -- --shots=DIR
##   ... -- --sets=21016-1.mpd,31025-1.mpd  (vendor/omr/files names; the four below by default)
##
## Four sets from vendor/omr/files, chosen once and kept: 21016-1
## Sungnyemun (325 parts, built as one model, no sub-models), 31025-1
## Mountain Hut (543, ten sub-models of its author's), 42093-1 (Technic,
## 712, pins and axles) and 10179-1 (4,545, the big one). For each:
##   the suggestion covers the model, every part in exactly one section;
##     each section (not the minifigures) is connected by the joint graph
##     and one piece by the build check on it alone, and has its own steps;
##   the parts add up: each section's count, as the parts list counts, and
##     weight, summed, are the whole model's;
##   accepted, they are sub-assemblies in one undo step, and undo takes them
##     all away;
##   a section broken out moves by whole studs or bricks, as one undo step,
##     and the file written meanwhile is the file written before; put back,
##     every part is where it was to the bit; each way undoes and redoes;
##   the exploded view moves what is drawn and nothing of the model;
##   evaluate_section, suggest_sections and break_out_section over MCP say
##     the same, and the read-only ones leave the model as it was.
## With --shots, pictures of the suggestion in the tree, a section broken
## out and the exploded view, drawn by the GPU, into DIR.
extends SceneTree

const SETS: Array[String] = ["21016-1.mpd", "31025-1.mpd", "42093-1.mpd", "10179-1.mpd"]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _verbs: EditVerbs
var _ui: SectionsUi
var _sections: Sections
var _socket: CommandSocket
var _shots: String = ""
var _next: int = 0
var _report: Array = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_ui = _shell.sections
	_sections = _ui.sections
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var out: String = OS.get_user_data_dir().path_join("sections_probe")
	DirAccess.make_dir_recursive_absolute(out)
	(_main.get("_exports") as Exports).folder = out
	Download.folder = out
	BookletMaker.open_when_written = false
	_shots = _arg("shots", "")
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots)
	await process_frame

	_stud_cells()
	var sets: Array = _arg("sets", ",".join(SETS)).split(",", false)
	for name: String in sets:
		await _one_set(name)

	print("")
	var line: String = JSON.stringify(_report)
	print("report: %s" % line)
	var written: String = _arg("report", "")
	if not written.is_empty():
		var file: FileAccess = FileAccess.open(written, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(_report, "  "))
			file.close()
	if _failures == 0:
		print("sections: suggested, covering, one piece each, adding up, accepted in one "
			+ "step, broken out and put back exactly, exploded, evaluated, over MCP")
	else:
		print("sections: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The cells Stability.contacts shares across one stud: a 2 x 4 brick on
## another is eight studs (Sections.STUD_CELLS).
func _stud_cells() -> void:
	_main.call("clear_model")
	await process_frame
	var below: int = _builder.put_part("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	var above: int = _builder.put_part("3001", 1, Transform3D(Basis.IDENTITY, Vector3(0, 48, 0)))
	var graph: Dictionary = _sections.joint_graph([_world.get_brick(below), _world.get_brick(above)])
	var studs: int = int((graph["studs"] as Dictionary).values()[0]) \
		if not (graph["studs"] as Dictionary).is_empty() else 0
	var judge := Stability.new()
	judge.library = _library
	judge.lattice = _builder.lattice
	var raw: Dictionary = judge.contacts([_world.get_brick(below), _world.get_brick(above)])
	print("  cells shared across a 2 x 4 on a 2 x 4: %s" % str(raw["above"]))
	_check("a 2 x 4 on a 2 x 4 is held by 8 studs in the joint graph (%d)" % studs, studs == 8)
	_main.call("clear_model")


func _one_set(name: String) -> void:
	var path: String = "res://vendor/omr/files/" + name
	print("\n%s" % name)
	if not FileAccess.file_exists(path):
		print("  (no vendor/omr here; skipped)")
		return
	_main.call("clear_model")
	await process_frame
	var opened: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), name.get_basename())
	for _n: int in 10:
		await process_frame
	_shell.assemblies.changed.emit()
	var row: Dictionary = {"set": name, "opened": int(opened.get("placed", 0))}
	var whole_parts: int = Inventory.pieces_in(_world, _library, _store.scenery)
	var whole: Inventory = Inventory.of(_world, _library, _store.scenery)
	# The window's frames idle first, the same model in view: on a box this
	# loaded, a frame with nothing to do took up to 140 ms (2026-10-17).
	var idle: float = 0.0
	if level_count() >= Sections.ON_A_WORKER_FROM:
		var idle_at: int = Time.get_ticks_usec()
		for _n: int in 300:
			await process_frame
			var now_idle: int = Time.get_ticks_usec()
			idle = maxf(idle, (now_idle - idle_at) / 1000.0)
			idle_at = now_idle
	var started: int = Time.get_ticks_msec()
	var frames: Array = [0, Time.get_ticks_usec(), 0, ""]   # longest, last, how many, when
	var watch: Callable = func() -> void:
		var now: int = Time.get_ticks_usec()
		if now - int(frames[1]) > int(frames[0]):
			frames[0] = now - int(frames[1])
			frames[3] = "after %s, %d ms in" % [str(_sections.laps.back()[0])
				if not _sections.laps.is_empty() else "the start",
				(now - started * 1000) / 1000]
		frames[1] = now
		frames[2] = int(frames[2]) + 1
	process_frame.connect(watch)
	await _ui.suggest()
	process_frame.disconnect(watch)
	var took: int = Time.get_ticks_msec() - started
	var longest_ms: float = int(frames[0]) / 1000.0
	row["suggest_frames"] = int(frames[2])
	if not _sections.laps.is_empty():
		print("    on the window's thread: %s; the longest frame %s" % [str(_sections.laps),
			str(frames[3])])
	row["suggest_longest_frame_ms"] = snappedf(longest_ms, 0.1)
	if level_count() >= Sections.ON_A_WORKER_FROM:
		# At most 100 ms, or no longer than the idle window's own longest.
		row["idle_longest_frame_ms"] = snappedf(idle, 0.1)
		_check("%s: the window keeps drawing while it is worked out on a worker: %d frames "
			% [name, int(frames[2])] + "in %d ms, the longest %.0f ms (at most 100, or the "
			% [took, longest_ms] + "%.0f ms of 300 idle frames)" % idle,
			(longest_ms <= 100.0 or longest_ms <= idle + 10.0) and int(frames[2]) > 5)
	var made: Array = _sections.suggested
	row["suggest_ms"] = took
	row["sections"] = made.size()
	row["level"] = _sections.level
	print("  %d parts, %d sections in %d ms at %s" % [whole_parts, made.size(), took,
		"the model" if _sections.level.is_empty() else _sections.level])
	for one: Sections.Suggestion in made:
		print("    " + one.said())
	_check("%s: two or more sections suggested (%d)" % [name, made.size()], made.size() >= 2)

	# Covers the model, every part once.
	var seen: Dictionary = {}
	var twice: int = 0
	for one: Sections.Suggestion in made:
		for brick_id: int in one.ids:
			if seen.has(brick_id):
				twice += 1
			seen[brick_id] = true
	var level_parts: Array = _sections._bricks_in(_sections.level)
	var missing: int = level_parts.filter(func(b: BrickWorld.Brick) -> bool:
		return not seen.has(b.id)).size()
	_check("%s: every part in exactly one section (%d missing, %d twice, of %d)"
		% [name, missing, twice, level_parts.size()], missing == 0 and twice == 0)

	# Connected, one piece by the build check alone, its own steps; sizes.
	var sizes: Array = []
	var unjoined := PackedStringArray()
	var not_one := PackedStringArray()
	var steps_none := PackedStringArray()
	var sum_parts: int = 0
	var sum_grams: float = 0.0
	var assistant: Assistant = _main.get("_assistant")
	var checked: int = 0
	for one: Sections.Suggestion in made:
		sizes.append(one.ids.size())
		var bricks: Array = []
		for brick_id: int in one.ids:
			bricks.append(_world.get_brick(brick_id))
		var pieces: int = Sections._pieces(bricks, _sections.joint_graph(bricks))
		if not one.apart and pieces != 1:
			unjoined.append("%s (%d pieces)" % [one.name, pieces])
		if _arg("weigh", "yes") == "no":
			continue
		var weighed: Dictionary = await _ui.evaluate("", one.number)
		sum_parts += int(weighed.get("parts", 0))
		sum_grams += float(weighed.get("grams", 0.0))
		if not one.apart:
			checked += 1
			if int(weighed.get("check_pieces", 1)) != 1:
				not_one.append("%s (%d, %s)" % [one.name, int(weighed["check_pieces"]),
					str(weighed.get("check", ""))])
			if int(weighed.get("steps", 0)) <= 0:
				steps_none.append(one.name)
	sizes.sort()
	row["sizes"] = sizes
	row["loose"] = 0
	for one: Sections.Suggestion in made:
		if one.apart and one.name.begins_with("Loose"):
			row["loose"] = one.ids.size()
	var backwards := PackedStringArray()
	for one: Sections.Suggestion in made:
		for under: int in one.onto:
			if under >= one.number:
				backwards.append("%d onto %d" % [one.number, under])
	# Measured, not required: interlocked sub-models (a Technic frame, a
	# UCS hull) need each other both ways, and no cut of them is in turn.
	var needing: Dictionary = {}
	for pair: String in backwards:
		needing[pair.get_slice(" ", 0)] = true
	print("    built in turn: %s" % ("every section only onto earlier ones" if backwards.is_empty()
		else "%d of %d sections need a later one (%s)" % [needing.size(), made.size(),
			", ".join(backwards.slice(0, 8))]))
	row["need_later"] = needing.size()
	# The joint graph reads studs, pins, axles and clips, not a tyre on its
	# rim or a part held by friction, which the build check does: its word
	# is the one that counts, and this is for reading.
	print("    by the joint graph alone, %s" % ("each one piece" if unjoined.is_empty()
		else "not one piece: " + ", ".join(unjoined)))
	# Every one on a model of a few hundred parts; on the big one, all but
	# a few in a hundred: 10179-1's "Back 14" holds 4 parts its file has
	# off their studs, and the joint graph reads no clip on a bar or tile
	# held from the side as the build check does.
	var allowed: int = 0 if checked < 20 else floori(checked * 0.05)
	_check("%s: each of %d one piece by the build check on it alone%s" % [name, checked,
		"" if not_one.is_empty() else " but %d (at most %d): %s" % [not_one.size(), allowed,
			", ".join(not_one)]], not_one.size() <= allowed)
	row["not_one_piece"] = not_one.size()
	_check("%s: each has its own steps%s" % [name, "" if steps_none.is_empty()
		else ": not " + ", ".join(steps_none)], steps_none.is_empty())
	_check("%s: the sections' parts add up to the model's (%d of %d)" % [name, sum_parts,
		whole_parts], sum_parts == whole_parts)
	_check("%s: ...and their weight (%.1f g of %.1f g)" % [name, sum_grams, whole.grams],
		absf(sum_grams - whole.grams) < 0.5)
	row["parts"] = whole_parts
	row["grams"] = snappedf(whole.grams, 0.1)

	if not _shots.is_empty():
		_shell.outliner.set_open(true)
		_shell.outliner._refresh(true)
		_shell.outliner._select_suggestion(mini(2, made.size()))
		var chosen: TreeItem = _shell.outliner._find(_shell.outliner._tree.get_root(),
			Outliner.SUGGESTION + str(mini(2, made.size())))
		if chosen != null:
			_shell.outliner._marking = true
			chosen.select(0)
			_shell.outliner._marking = false
			_shell.outliner._update_strip()
		_main.get("_camera").frame(_main.call("_built_bounds"), 1.15)
		await _frames(20)
		await _shot(name.get_basename() + "_suggested")
		_builder.clear_selection()

	# Split and merged back, as the model tree's buttons do.
	var before_split: int = _sections.suggested.size()
	var split_said: String = _sections.split(1)
	var after_split: int = _sections.suggested.size()
	var merge_said: String = _sections.merge(2)
	_check("%s: split parts suggestion 1 in two (%s), merge puts it back (%s)" % [name,
		split_said, merge_said], after_split == before_split + 1
		and _sections.suggested.size() == before_split)
	await _ui.suggest()

	await _over_mcp(name, row)
	await _cancelled(name)
	await _ui.suggest()

	# Accepted: sub-assemblies, one undo step.
	var depth: int = _builder.history_depth()
	var before_paths: int = _shell.assemblies.paths().size()
	var path_was: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		path_was[brick.id] = Assemblies.path_of(brick)
	var said: String = _ui.accept()
	var made_paths: PackedStringArray = PackedStringArray()
	for one: Dictionary in _sections.sections():
		made_paths.append(str(one["path"]))
	_check("%s: accept all makes them sub-assemblies, one undo step (%s; history %d -> %d)"
		% [name, said.left(80), depth, _builder.history_depth()],
		_builder.history_depth() == depth + 1 and _shell.assemblies.paths().size() > before_paths)
	var made_count: int = _shell.assemblies.paths().size()
	var accepted_depth: int = _builder.history_depth()
	_builder.undo()
	_main.call("_on_model_edited")
	var after_undo: int = _shell.assemblies.paths().size()
	var undo_depth: int = _builder.history_depth()
	var differ: Array = []
	var gone: int = 0
	for brick_id: int in path_was:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			gone += 1
		elif Assemblies.path_of(brick) != str(path_was[brick_id]):
			differ.append("%d %s -> %s" % [brick_id, path_was[brick_id], Assemblies.path_of(brick)])
	if not differ.is_empty() or gone > 0:
		print("    (after undo %d parts gone, %d elsewhere: %s)" % [gone, differ.size(),
			"; ".join(differ.slice(0, 4))])
	_builder.redo()
	_main.call("_on_model_edited")
	_check("%s: ...undone in one, and redone (%d paths, %d made, %d undone, %d redone; history %d, %d, %d)"
		% [name, before_paths, made_count, after_undo, _shell.assemblies.paths().size(),
		accepted_depth, undo_depth, _builder.history_depth()], after_undo == before_paths
		and _shell.assemblies.paths().size() == made_count)

	if not _shots.is_empty():
		# What Evaluate the section… shows of the first.
		var first: Array = _sections.sections()
		if not first.is_empty():
			await _ui.show_evaluation(str((first[0] as Dictionary)["path"]))
			await _frames(20)
			await _shot(name.get_basename() + "_evaluated")
			if _ui._dialog != null:
				_ui._dialog.hide()
			# Its own booklet: the booklet's code with the rest left out.
			if name == SETS[0]:
				var steps: int = int(_ui.last_evaluation.get("steps", 0))
				var to: String = _shots.path_join(name.get_basename() + "_section_booklet.html")
				var note: String = await _ui.booklet(to)
				# Its author's steps when the file has them, as the booklet
				# keeps; the evaluation counts the worked-out ones.
				_check("%s: the section's own booklet is written (%s; %d steps worked out)"
					% [name, note, steps], FileAccess.file_exists(to)
					and FileAccess.get_file_as_string(to).length() > 1000
					and note.contains(" steps"))
	await _break_out_and_back(name, row)
	await _exploded(name, row)
	_report.append(row)


## A section broken out and put back: exact, one step each, and a file
## written meanwhile that is the file written before.
func _break_out_and_back(name: String, row: Dictionary) -> void:
	var tops: Array = _sections.sections()
	if tops.is_empty():
		_check("%s: a section to break out" % name, false)
		return
	# The last built (the top, usually), and one that comes off sideways.
	var picks: Array = [tops.back()]
	for one: Dictionary in tops:
		var own: Dictionary = {}
		for brick_id: int in one["ids"]:
			own[brick_id] = true
		if _sections.way_off(own).y == 0.0 and one != tops.back():
			picks.append(one)
			break
	var file_before: String = _store.to_text("Probe")
	for pick: Dictionary in picks:
		var path: String = pick["path"]
		var before: Dictionary = {}
		for brick: BrickWorld.Brick in _world.bricks():
			before[brick.id] = brick.transform
		var depth: int = _builder.history_depth()
		var done: Dictionary = _sections.break_out(path)
		var step_size: int = _builder.next_change_size()
		_main.call("_on_model_edited")
		var gone: int = 0
		for brick_id: int in before:
			if _world.get_brick(brick_id) == null:
				gone += 1
		if gone > 0 or _builder.next_change_size() != step_size:
			print("    (after the break-out was edited, %d parts gone, its step %d -> %d)" % [
				gone, step_size, _builder.next_change_size()])
		var offset: Vector3 = done.get("offset", Vector3.ZERO)
		var moved_right: bool = bool(done.get("ok", false))
		for brick_id: int in _shell.assemblies.ids_under(path):
			var was: Transform3D = before[brick_id]
			var now: Transform3D = _world.get_brick(brick_id).transform
			if now.basis != was.basis or now.origin.distance_to(was.origin + offset) > 0.001:
				moved_right = false
		var others_still: bool = true
		var own: Dictionary = {}
		for brick_id: int in _shell.assemblies.ids_under(path):
			own[brick_id] = true
		for brick_id: int in before:
			if not own.has(brick_id) and _world.get_brick(brick_id) != null \
					and _world.get_brick(brick_id).transform != before[brick_id]:
				others_still = false
		var whole_steps: bool = is_zero_approx(fmod(absf(offset.x), BrickLattice.STUD)) \
			and is_zero_approx(fmod(absf(offset.z), BrickLattice.STUD)) \
			and is_zero_approx(fmod(absf(offset.y), BrickLattice.BRICK))
		_check("%s: %s broken out %s by %s LDU, one undo step, every part of it moved alike "
			% [name, Assemblies.label(path), Sections.way_words(offset.normalized()), str(offset)]
			+ "and nothing else", moved_right and others_still and whole_steps
			and _builder.history_depth() == depth + 1)
		var file_out: String = _store.to_text("Probe")
		_check("%s: ...a file written while it is out is the file written before" % name,
			file_out == file_before)
		if file_out != file_before:
			_first_difference(file_before, file_out)
		if not _shots.is_empty():
			_shell.outliner._refresh(true)
			_main.get("_camera").frame(_main.call("_built_bounds"), 1.1)
			await _frames(20)
			await _shot("%s_out_%s" % [name.get_basename(), Assemblies.definition(
				Assemblies.leaf(path)).to_snake_case()])
		# Put back: exact.
		var back: Dictionary = _sections.put_back(path)
		_main.call("_on_model_edited")
		var exact: bool = bool(back.get("ok", false))
		for brick_id: int in before:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick != null and brick.transform != before[brick_id]:
				exact = false
		_check("%s: ...put back, every part where it was to the bit, one more undo step (%s, %d steps, %s)"
			% [name, "exact" if exact else "NOT exact", _builder.history_depth() - depth,
			str(back.get("words", ""))], exact and _builder.history_depth() == depth + 2
			and _world.broken_out.is_empty())
		# Each way undoes and redoes.
		_builder.undo()
		var out_again: bool = not _world.broken_out.is_empty() and \
			_world.get_brick(_shell.assemblies.ids_under(path)[0]).transform \
			== (before[_shell.assemblies.ids_under(path)[0]] as Transform3D).translated(offset)
		_builder.undo()
		var home_again: bool = _world.broken_out.is_empty()
		for brick_id: int in before:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick != null and brick.transform != before[brick_id]:
				home_again = false
		_builder.redo()
		_builder.redo()
		var redone: bool = _world.broken_out.is_empty()
		for brick_id: int in before:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick != null and brick.transform != before[brick_id]:
				redone = false
		_main.call("_on_model_edited")
		_check("%s: ...undo puts it out again, undo again home exactly, redo both back"
			% name, out_again and home_again and redone)
		row["out_" + Assemblies.label(path)] = [offset.x, offset.y, offset.z]


## The exploded view: what is drawn moves, the model does not.
func _exploded(name: String, row: Dictionary) -> void:
	var revision: int = _world.revision
	var text: String = _store.to_text("Probe")
	var depth: int = _builder.history_depth()
	var was_exploded: bool = _ui.is_exploded()
	var camera: CadCamera = _main.get("_camera")
	var view_was: Array = [camera._target_focus, camera._target_distance]
	_ui.explode_now(true)
	var drawn: int = _world.drawn_ids().size()
	if drawn == 0:
		print("    (exploded before %s, shifts %d, apart %d)" % [was_exploded, _ui._shifts.size(),
			_sections.exploded(1.0, _sections.explode_groups()).size()])
	var groups: int = _sections.explode_groups().size()
	_check("%s: the exploded view draws %d sections apart (%d parts drawn moved)"
		% [name, groups, drawn], drawn > 0 and groups >= 2)
	_check("%s: ...and changes nothing of the model (revision, history, file)" % name,
		_world.revision == revision and _builder.history_depth() == depth
		and _store.to_text("Probe") == text)
	# Framed on what is drawn apart: every section's drawn box in the window.
	await _frames(90)
	var tops: Array = _sections.sections()
	var outside := PackedStringArray()
	var view: Rect2 = root.get_visible_rect()
	var highest: String = ""
	var top_y: float = -INF
	for one: Dictionary in tops:
		var box: AABB = _ui.drawn_bounds(str(one["path"]))
		if box.end.y > top_y:
			top_y = box.end.y
			highest = str(one["path"])
		for corner: int in 8:
			var point: Vector3 = box.get_endpoint(corner)
			if camera.is_position_behind(point) \
					or not view.grow(2.0).has_point(camera.unproject_position(point)):
				outside.append(Assemblies.label(str(one["path"])))
				break
	_check("%s: ...the view framed on it, every section drawn in the window%s" % [name,
		"" if outside.is_empty() else ": not " + ", ".join(outside)], outside.is_empty())
	# A click picks what is drawn: the highest section, at its drawn middle.
	var middle: Vector2 = camera.unproject_position(_ui.drawn_bounds(highest).get_center())
	var picked: int = _verbs.brick_at(middle)
	var picked_path: String = Assemblies.path_of(_world.get_brick(picked)) \
		if _world.get_brick(picked) != null else ""
	_verbs.set_mode("select")
	_verbs.click(middle, false)
	var chosen: String = _shell.assemblies.selected_assembly()
	_check("%s: ...a click on %s where it is drawn chooses it (picked %s, chosen %s)" % [name,
		Assemblies.label(highest), picked_path, chosen],
		Assemblies.within(picked_path, highest) and chosen == highest)
	if not _shots.is_empty():
		await _frames(10)
		await _shot(name.get_basename() + "_exploded")
	_builder.clear_selection()
	_ui.explode_now(false)
	await _frames(5)
	_check("%s: ...and back together, nothing drawn moved, the view where it was" % name,
		_world.drawn_ids().is_empty() and not _ui.is_exploded()
		and camera._target_focus.is_equal_approx(view_was[0])
		and is_equal_approx(camera._target_distance, float(view_was[1])))
	row["exploded_groups"] = groups


## The same over MCP, as the connector calls it.
## The parts the suggestion is made of: the model's, or the sub-assembly's.
func level_count() -> int:
	return _sections._bricks_in(_sections._level()).size()


## Cancel stops a suggestion part way: nothing suggested, said so.
func _cancelled(name: String) -> void:
	if level_count() < Sections.ON_A_WORKER_FROM:
		return
	var job: Working.Job = Working.begin("Suggesting sections…", Sections.PHASES, true)
	_cancel_after(job, 3)
	var made: Array = await _sections.suggest(job)
	job.end()
	_check("%s: Cancel stops it: nothing suggested (%s)" % [name, _sections.why_none],
		made.is_empty() and _sections.why_none.begins_with("stopped"))


func _cancel_after(job: Working.Job, count: int) -> void:
	await _frames(count)
	job.cancel()


func _over_mcp(name: String, row: Dictionary) -> void:
	var text: String = _store.to_text("Probe")
	var depth: int = _builder.history_depth()
	var revision: int = _world.revision
	var listed: String = await _say("suggest_sections", {})
	var first_line: String = listed.get_slice("\n", 0)
	_check("%s: suggest_sections lists them (%s)" % [name, first_line],
		listed.contains("sections") and listed.contains("1. "))
	var weighed: String = await _say("evaluate_section", {"suggestion": 1})
	_check("%s: evaluate_section weighs suggestion 1 (%s)" % [name, weighed.get_slice("\n", 0)],
		weighed.contains("Holds together") and weighed.contains("Its parts"))
	_check("%s: ...and neither changed the model (revision, history, file)" % name,
		_world.revision == revision and _builder.history_depth() == depth
		and _store.to_text("Probe") == text)
	row["mcp_suggest"] = first_line
	row["mcp_evaluate"] = weighed.get_slice("\n", 0)
	if name != SETS[0]:
		return
	# Made, broken out and put back by a session: one undo step each.
	var made: String = await _say("make_sections", {})
	var tops: Array = _sections.sections()
	_check("%s: make_sections makes them sub-assemblies, one undo step (%s)" % [name,
		made.left(90)], tops.size() >= 2 and _builder.history_depth() == depth + 1)
	var section: String = Assemblies.label(str((tops.back() as Dictionary)["path"]))
	var out: String = await _say("break_out_section", {"section": section})
	_check("%s: break_out_section pulls %s out (%s)" % [name, section, out.left(100)],
		not _world.broken_out.is_empty() and _builder.history_depth() == depth + 2)
	var file_out: String = _store.to_text("Probe")
	var back: String = await _say("break_out_section", {"section": section, "put_back": true})
	_check("%s: ...and put_back puts it back (%s)" % [name, back.left(80)],
		_world.broken_out.is_empty() and _builder.history_depth() == depth + 3)
	_check("%s: ...the file written while it was out the same as after" % name,
		file_out == _store.to_text("Probe"))
	var undo: String = await _say("undo", {"steps": 3})
	_check("%s: the session's three steps undo (%s)" % [name, undo.left(60)],
		_builder.history_depth() == depth and _sections.sections().is_empty())
	# Named and merged by a session: two suggestions as one section called
	# Gate, the first as it is; one step, undone.
	await _ui.suggest()
	var count: int = _sections.suggested.size()
	var merged: String = await _say("make_sections", {"sections": [
		{"name": "Gate", "from": [2, 3]}, {"from": [1]}]})
	var gate: String = _sections.find_section("Gate")
	_check("%s: make_sections merges two into Gate, keeps one, one undo step (%s)" % [name,
		merged.left(80)], count == 3 and not gate.is_empty()
		and _sections.sections().size() == 2 and _builder.history_depth() == depth + 1)
	await _say("undo", {})
	# The suggestion again, for the window's own checks after this.
	await _ui.suggest()


func _first_difference(a: String, b: String) -> void:
	var one: PackedStringArray = a.split("\n")
	var other: PackedStringArray = b.split("\n")
	for n: int in mini(one.size(), other.size()):
		if one[n] != other[n]:
			print("    (line %d differs: %s | %s)" % [n, one[n].left(120), other[n].left(120)])
			return
	print("    (%d lines against %d)" % [one.size(), other.size()])


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _shots.path_join(name + ".png")
	image.save_png(path)
	print("    picture: %s" % path)
