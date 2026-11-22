## fpjudge: the review's (fpreview's) file checks on Lay, asked of the model
## as it is kept, not of the text a save would plan afresh.
##
## fpreview's "reopened, the same file" compared ModelStore.saved_text()
## before and after a reopen. saved_text() is the save's whole write
## (to_text), never the kept text an unedited Save writes, and for a model
## whose steps are no one's (the app's own, "Author: Brickworks" with no
## AUTHORED_STEPS line) to_text plans the steps afresh from the parts as
## they stand: the same parts read back in the planned order plan to other
## steps (the castle 398 of 400, the station 73 of 125), and with them the
## IN lines that open each run of a copy's parts in a step. Its controls,
## a part taken off by hand and no Lay, fail the same way. So, here:
##   files     fpreview's 14 files, every kind ticked: Lay, Undo, Redo; then
##             Save, open the saved file as File › Open does, Save again:
##             the second save byte for byte the first (an unedited save),
##             and the model reopened holds every part of the one saved, in
##             colour and place, in the same copy of the same sub-model.
##             Where the file's steps are someone's, saved_text() too is the
##             same before and after, as fpreview asked.
##   controls  castle and station, one part taken off by hand, the same.
##   defaults  castle and station, the bar's defaults: no line but parts,
##             steps and IN lines lost by Lay (those two are the plan's),
##             and each part Lay leaves keeps its copy.
##   ghost     another model opened: none of the old model's ghost is drawn,
##             and what is drawn is the new model's own reading (the bar
##             reads again on any change of the world, fpfix's M2).
##   byturns   (by hand only) fpfix's laytime on Orthanc judged by turns: a
##             part put down by hand, ten times, then Lay, then ten by hand
##             again, each frame's own work; what the world does after any
##             one part on Orthanc, against the Lay's longest frames.
##
##   godot --headless --path . --script src/dev/fpjudge_probe.gd
##   FPJ_CASES=files,controls  only these; FPJ_FILES=castle,station  only those
##   FPJ_OUT=DIR  each text written there (saved, reopened), to diff by hand
extends "res://src/dev/fpfix_probe.gd"

const FILES: Array = ["res://src/dev/fixtures/metalines/apps.mpd",
	"res://src/dev/fixtures/metalines/sub_pic.mpd", "res://src/dev/fixtures/metalines/drive.ldr",
	"res://src/dev/fixtures/house/robot.ldr", "res://src/dev/fixtures/copyfaults_wing.ldr",
	"res://src/dev/fixtures/copyfaults_nest.mpd", "res://src/dev/fixtures/telescope.mpd",
	"res://src/dev/fixtures/keep_text_notes.mpd", "res://src/dev/fixtures/stepnames/row.ldr",
	"res://src/dev/fixtures/cfc_wing2.ldr", "res://src/dev/fixtures/kt3r_whole.mpd",
	"res://models/castle.ldr", "res://models/station.ldr", "res://models/orrery.ldr"]

var _out: String = ""


func _run() -> void:
	_out = OS.get_environment("FPJ_OUT")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Account.where = "user://probe_session.json"
	Account._clear()
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
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	var cases: String = OS.get_environment("FPJ_CASES")
	if cases.is_empty():
		cases = "files,controls,defaults,ghost"
	var only: PackedStringArray = OS.get_environment("FPJ_FILES").split(",", false)
	for name: String in cases.split(","):
		print("\n== %s" % name)
		match name:
			"files":
				for path: String in FILES:
					if only.is_empty() or only.has(path.get_file().get_basename()):
						await _case_file(path)
			"controls":
				for path: String in ["res://models/castle.ldr", "res://models/station.ldr"]:
					await _case_control(path)
			"defaults":
				for path: String in ["res://models/castle.ldr", "res://models/station.ldr"]:
					await _case_defaults(path)
			"ghost": await _case_open_ghost()
			"byturns": await _case_by_turns()
	print("fpjudge: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


# -- reading a file ---------------------------------------------------------------


## Each part line of [param text] as [line, copy, step]: the copy is the FILE
## it is in and the IN line in force there (LdrModel.IN_META, to the next
## IN line or the end of the step), the step counted in its FILE.
static func _file_parts(text: String) -> Array:
	var out: Array = []
	var file: String = "(main)"
	var step: int = 0
	var copy: String = ""
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 FILE "):
			file = line.substr(7)
			step = 0
			copy = ""
		elif line == "0 STEP" or line.begins_with("0 ROTSTEP"):
			step += 1
			copy = ""
		elif line.begins_with(LdrModel.IN_META):
			copy = line.substr(LdrModel.IN_META.length()).strip_edges()
		elif line.begins_with("1 "):
			out.append([" ".join(line.split(" ", false)), file + " | " + copy, step])
	return out


## [param parts] (from [method _file_parts]) counted by the line alone, or by
## the line and its copy: key -> how many.
static func _tally(parts: Array, with_copy: bool) -> Dictionary:
	var out: Dictionary = {}
	for one: Array in parts:
		var key: String = (str(one[0]) + "  in " + str(one[1])) if with_copy else str(one[0])
		out[key] = int(out.get(key, 0)) + 1
	return out


## What [param a] has more of than [param b]: key -> how many more.
static func _more_in(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in a:
		var more: int = int(a[key]) - int(b.get(key, 0))
		if more > 0:
			out[key] = more
	return out


static func _total(counts: Dictionary) -> int:
	var n: int = 0
	for key: Variant in counts:
		n += int(counts[key])
	return n


static func _some(counts: Dictionary, most: int = 4) -> String:
	var out := PackedStringArray()
	for key: Variant in counts:
		if out.size() >= most:
			break
		out.append("%s x%d" % [str(key).right(70), int(counts[key])])
	return " || ".join(out)


## The parts of the model on the baseplate, each "part colour place" in the
## file's own numbers, with its copy's path: key -> how many.
func _world_parts() -> Dictionary:
	var back := Transform3D(Basis.IDENTITY, -_store._lift_now())
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Transform3D = back * brick.transform
		var numbers := PackedStringArray()
		for v: float in [at.origin.x, at.origin.y, at.origin.z]:
			numbers.append(str(snappedf(v, 0.01) + 0.0))
		for axis: Vector3 in [at.basis.x, at.basis.y, at.basis.z]:
			for v: float in [axis.x, axis.y, axis.z]:
				numbers.append(str(snappedf(v, 0.001) + 0.0))
		var key: String = "%s %d %s in %s" % [brick.part_id, brick.color_code, " ".join(numbers),
			Assemblies.path_of(brick)]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _keep(name: String, text: String) -> void:
	if _out.is_empty():
		return
	var file := FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Saved with Save, opened from that file as File › Open opens it, and saved
## again with no edit, against the model as it stood before the save:
## the second save is the first byte for byte; the model reopened holds
## every part, in colour, place and copy; and, where the file's steps are
## someone's, saved_text() is the same too. [param label] names the checks
## and the file, each case its own.
func _saved_and_reopened(label: String) -> void:
	var before: Dictionary = _world_parts()
	var floor_before: int = _store.scenery.size()
	var bricks_before: int = _world.bricks().size()
	var planned: String = _store.saved_text()
	var stepped_by_someone: bool = LdrModel.parse(planned, "model").steps_are_authored()
	if not _store.save_as(label):
		_check("%s: saved" % label, false)
		return
	var path: String = _store.saved_path(_store.title)
	var first: String = FileAccess.get_file_as_string(path)
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var placed: int = await bar.open_with_progress(path)
	bar.opened.emit(placed)
	await _frames(10)
	var after: Dictionary = _world_parts()
	# The floor's baseplates are the world's bricks too (fpreview counted
	# them): laid under the model at an open, as many as it now stands on.
	print("    %s: the world's bricks %d -> %d, of them the floor's %d -> %d" % [label, bricks_before,
		_world.bricks().size(), floor_before, _store.scenery.size()])
	var replanned: String = _store.saved_text()
	if not _store.save_as(_store.title):
		_check("%s: saved again" % label, false)
		return
	var second: String = FileAccess.get_file_as_string(_store.saved_path(_store.title))
	_keep(label.replace(" ", "_") + "_saved.ldr", first)
	_keep(label.replace(" ", "_") + "_planned_after.ldr", replanned)
	if not _check("%s: saved, opened from the file, saved again unedited: byte for byte (%d bytes)"
			% [label, first.length()], second == first):
		_first_diff(first, second)
	var lost: Dictionary = _more_in(before, after)
	var gained: Dictionary = _more_in(after, before)
	_check("%s: reopened, every part in colour, place and copy (%d, %d; lost %d, gained %d: %s)"
		% [label, _total(before), _total(after), _total(lost), _total(gained),
		_some(lost) + (" ++ " + _some(gained) if not gained.is_empty() else "")],
		lost.is_empty() and gained.is_empty())
	# The file against itself planned again: the parts, then their copies,
	# then their steps.
	var in_file: Array = _file_parts(first)
	var in_plan: Array = _file_parts(replanned)
	var copies_off: int = _total(_more_in(_tally(in_file, true), _tally(in_plan, true)))
	var steps_off: int = 0
	var at_step: Dictionary = {}
	for one: Array in in_file:
		var key: String = "%s#%d" % [one[0], int(one[2])]
		at_step[key] = int(at_step.get(key, 0)) + 1
	for one: Array in in_plan:
		var key: String = "%s#%d" % [one[0], int(one[2])]
		if int(at_step.get(key, 0)) > 0:
			at_step[key] = int(at_step[key]) - 1
		else:
			steps_off += 1
	print("    %s: steps %s; the saved file's parts %d, planned again %d; in another copy %d, in another step %d"
		% [label, "someone's" if stepped_by_someone else "no one's (planned at each save)",
		in_file.size(), in_plan.size(), copies_off, steps_off])
	if stepped_by_someone:
		if not _check("%s: someone's steps, planned the same after the reopen" % label,
				replanned == first):
			_first_diff(first, replanned)


# -- the cases --------------------------------------------------------------------


func _case_file(path: String) -> void:
	var name: String = path.get_file()
	await _open(FileAccess.get_file_as_string(path))
	var called: String = path.get_file().get_basename().replace("_", " ")
	_set_name(called)
	await _frames(6)
	var s0: String = _store.saved_text()
	var bar: FinishBar = await _open_bar()
	if bar == null:
		_check("%s: bar read" % name, false)
		return
	if bar.counts().is_empty():
		print("  %s: nothing to finish" % name)
		bar.close()
		return
	for kind: String in FinishBar.KINDS:
		bar.set_kind(kind, true)
	var laid: Dictionary = await bar.lay_now()
	await _frames(6)
	if int(laid.get("laid", 0)) == 0:
		print("  %s: nothing laid" % name)
		bar.close()
		return
	var s1: String = _store.saved_text()
	_lines_kept(name, s0, s1, int(laid.get("taken", 0)))
	await _undo()
	await _shell.verbs.press("redo")
	await _frames(8)
	_keep(name + "_s0.ldr", s0)
	_keep(name + "_s1.ldr", s1)
	await _saved_and_reopened(name)


## No line but parts, steps and IN lines lost; the parts Lay left in place
## each in the copy it was in.
func _lines_kept(name: String, s0: String, s1: String, taken: int) -> void:
	var before: Dictionary = {}
	var after: Dictionary = {}
	for pair: Array in [[s0, before], [s1, after]]:
		for raw: String in (pair[0] as String).split("\n"):
			var line: String = raw.strip_edges()
			if line.begins_with("1 ") or line == "0 STEP" or line.begins_with("0 ROTSTEP") \
					or line.begins_with(LdrModel.IN_META):
				continue
			(pair[1] as Dictionary)[line] = int((pair[1] as Dictionary).get(line, 0)) + 1
	var lost: Dictionary = _more_in(before, after)
	_check("%s: no line but parts, steps and IN lines lost by Lay (%s)" % [name, _some(lost)],
		lost.is_empty())
	var p0: Array = _file_parts(s0)
	var p1: Array = _file_parts(s1)
	var gone: Dictionary = _more_in(_tally(p0, false), _tally(p1, false))
	var moved: Dictionary = _more_in(_tally(p0, true), _tally(p1, true))
	# Each (line, copy) of s0 not in s1 must be a part taken off.
	var unexplained: Dictionary = {}
	var left: Dictionary = gone.duplicate()
	for key: String in moved:
		var line: String = key.get_slice("  in ", 0)
		var n: int = int(moved[key])
		var by_taking: int = mini(n, int(left.get(line, 0)))
		left[line] = int(left.get(line, 0)) - by_taking
		if n > by_taking:
			unexplained[key] = n - by_taking
	_check("%s: Lay took %d parts off (%d by the file), every other part in its copy (%d moved: %s)"
		% [name, taken, _total(gone), _total(unexplained), _some(unexplained)],
		unexplained.is_empty() and _total(gone) == taken)


## fpreview2's control: a part taken off by hand, no Lay.
func _case_control(path: String) -> void:
	var name: String = path.get_file().get_basename()
	await _open(FileAccess.get_file_as_string(path))
	_set_name(name)
	await _frames(6)
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		ids.append(brick.id)
	ids.sort()
	_builder.remove_brick_id(int(ids[ids.size() / 2]))
	_main.call("_on_model_edited")
	await _frames(6)
	await _saved_and_reopened("control " + name)


## fpreview2's defaults: Lay with the bar's own ticks.
func _case_defaults(path: String) -> void:
	var name: String = path.get_file().get_basename()
	await _open(FileAccess.get_file_as_string(path))
	_set_name(name)
	await _frames(6)
	var s0: String = _store.saved_text()
	var bar: FinishBar = await _open_bar()
	if bar == null:
		_check("%s defaults: bar read" % name, false)
		return
	var laid: Dictionary = await bar.lay_now()
	await _frames(6)
	var s1: String = _store.saved_text()
	print("  %s defaults: laid %s" % [name, str(laid).left(200)])
	_lines_kept(name + " defaults", s0, s1, int(laid.get("taken", 0)))
	await _saved_and_reopened(name + " defaults")


## fpreview's ghost at an open, told apart: the house's pieces, and the car's
## own read for it after.
func _case_open_ghost() -> void:
	await _open_model("res://models/house.ldr", "house")
	var bar: FinishBar = await _open_bar()
	var old: Array = _ghost_pieces(bar)
	print("  the house's ghost: %d pieces drawn" % _shown_of(old))
	await _open(FileAccess.get_file_as_string("res://models/car.ldr"))
	_set_name("car")
	await _frames(20)
	await _until(func() -> bool: return not bar.busy, 300000)
	await _frames(4)
	_check("ghost: another model opened, none of the house's %d pieces drawn (%d), what is drawn the car's own (%d pieces, read_at %d, revision %d)"
		% [old.size(), _shown_of(old), _visible_ghosts(bar), bar.read_at, _world.revision],
		old.size() > 0 and _shown_of(old) == 0 and _ghost_true(bar, "car"))
	bar.close()


## fpfix's laytime on Orthanc, by turns: ten parts put down by hand (each in
## a frame, as a click puts one: the part, its undo step, the edit told),
## then the Lay, then ten by hand again, each frame's own work and what was
## in it, so the Lay's longest frames are set against what any one part
## costs the world on Orthanc at the same moment.
func _case_by_turns() -> void:
	await _open_model("res://models/orthanc.ldr", "orthanc")
	var hand_a: Array = await _by_hand("hand before")
	var bar: FinishBar = await _open_bar()
	if bar == null:
		_check("byturns: the bar read Orthanc", false)
		return
	var frames: ProbeTime.Frames = _labelled()
	var laid: Dictionary = await bar.lay_now()
	await _frames(8)
	var lay: Array = _longest(frames, "lay")
	var labels: Dictionary = {}
	for frame: Array in frames.work:
		var own: float = float(frame[1]) - float(frame[2])
		if own > 60.0:
			var what: String = str(frame[3]).get_slice("|", 1).strip_edges()
			labels[what] = labels.get(what, []) + [snappedf(own, 0.1)]
	frames.queue_free()
	print("  lay: %d parts, longest %.1f ms own, %d frames over 100; frames over 60 ms by phase %s"
		% [int(laid.get("parts", 0)), float(lay[0]), int(lay[1]), str(labels)])
	await _undo()
	var hand_b: Array = await _by_hand("hand after")
	print("SUMMARY byturns orthanc: by hand longest %.1f / %.1f ms own (%d / %d of 10 over 100), Lay %.1f ms (%d frames over 100)"
		% [float(hand_a[0]), float(hand_b[0]), int(hand_a[1]), int(hand_b[1]), float(lay[0]), int(lay[1])])


## Ten parts put down by hand on the model, one a turn, each taken back
## after: [the longest frame's own work, how many turns had one over 100 ms].
func _by_hand(what: String) -> Array:
	var top: float = _world.model_bounds().end.y
	var longest: float = 0.0
	var over: int = 0
	var each := PackedStringArray()
	for n: int in 10:
		await _frames(4)
		var frames: ProbeTime.Frames = _labelled()
		var at := Transform3D(Basis.IDENTITY, Vector3(20.0 * n, top + 200.0, 0.0))
		var steps: Array = _builder.swap_bricks(PackedInt64Array(), [{"part": "3024", "color": 4, "at": at}])
		_builder.record(steps, "put")
		_main.call("_on_model_edited")
		await _frames(4)
		var turn: float = 0.0
		for frame: Array in frames.work:
			turn = maxf(turn, float(frame[1]) - float(frame[2]))
		frames.queue_free()
		each.append("%.0f" % turn)
		longest = maxf(longest, turn)
		if turn > 100.0:
			over += 1
		await _undo()
	print("  %s: each part's longest frame %s ms own" % [what, ", ".join(each)])
	return [longest, over]
