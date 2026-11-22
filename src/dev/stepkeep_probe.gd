## stepkeep2: does a model come back in the steps it was saved in, and does an
## edit change only the steps it touches?
##
## fpjudge (2026-11-22) found the app's own models ("Author: Brickworks", no
## AUTHORED_STEPS) worked out afresh at every open: the castle saved and opened
## again had 2,363 of its 2,496 parts in another step. Now the 0 STEP lines a
## file carries are the model's steps on opening it (LdrModel.steps_are_saved,
## BrickWorld.steps_own), and nothing is added to the file: worked out only for
## a file with none. An edit of such a model changes only its own steps: a part
## put down goes in the step of what it rests on, or a new last step; one moved
## keeps its step unless it would be in the air there; one taken off leaves its
## step, an emptied one gone (AuthorSteps.follow_saved). A step edit by the
## person makes the steps theirs (AUTHORED_STEPS, as before). For each model:
##   as filed  castle and station as shipped, the robot as an older build saved
##             it: their steps the file's, every part in the step the file has it
##             in, the whole write adding no line
##   reopened  saved, opened from the file as File › Open does: the plan the one
##             shown before the save, step for step; the whole write the file,
##             byte for byte; saved again unedited, byte for byte
##   added     one part put on the model's top: in the step of what it rests on
##             (someone's file: after the last), every other step as it was;
##             Undo, Redo; saved and opened again, the plan with it
##   taken     one part taken off a step in the middle: every other step as it
##             was (10179-1 is someone else's, stepped by its author)
## And on the station: F a brick on the floor beside it (a new last step), C a
## brick of the first steps moved onto the top (into the top's step), C2 one
## moved onto a brick of an earlier step (its step kept), E a step edit (the
## steps the person's, AUTHORED_STEPS written; undone, no one's again), P
## Plan steps on the timeline and edit_steps "plan" (the steps worked out
## afresh, one undo each, undone exactly), N2 the
## autosave's text with a part put on (Save's steps, and opened as a restore,
## the plan with it). On the castle and the robot: A a copy built on the side
## renamed (still built on the side, and a sub-model of the file), B a part put
## on such a copy's top (in the step that puts the copy on), D a sub-model's
## copy pasted beside the model (each part in a step, the copy put on in one,
## saved and opened again the same). nosteps: the
## castle's and the station's files with their STEP lines taken out (a model
## built here, or an older build's autosave), worked out afresh, saved and
## opened again: the steps worked out, the booklet's banners near those
## worked out, and saved again byte for byte. time: what an open of the castle and of Orthanc takes,
## said. shipped: every model the app ships (res://models/, the examples;
## tools/web/gallery_seeds/, the gallery's own) whose saved steps open as they
## are (LdrModel.steps_are_saved): its steps test, as a share runs it, puts no
## part in the air. Those are ours, not an owner's: an older build's planner
## wrote the castle's, and held, they put 48 of its parts down in the air (the
## gallery's potted cactus 1, its sports car 25); worked out again and saved,
## none (stepkeep2, 2026-11-22). SK_SHIP_OUT=DIR works out again each that
## puts one there (Plan steps) and writes it as Save does into DIR; reopened,
## the steps the ones worked out, none in the air, saved again byte for byte.
## Save writes it whole: a sub-model built in its model's steps has no section
## of its own (IN lines), the floor's line is written, the title is its name.
##
##   godot --headless --path . --script src/dev/stepkeep_probe.gd
##   SK_ONLY=castle,station,robot,10179,edits,callouts,nosteps,time,shipped  only those
##   SK_OUT=DIR  the texts written there
extends SceneTree

const MODELS: Array = [
	["castle", "res://models/castle.ldr"],
	["station", "res://models/station.ldr"],
	["robot", "res://src/dev/fixtures/house/robot.ldr"],
	["10179", "res://vendor/omr/files/10179-1.mpd"],
]
const STATION := "res://models/station.ldr"
const CASTLE := "res://models/castle.ldr"
const ROBOT := "res://src/dev/fixtures/house/robot.ldr"
const ORTHANC := "res://models/orthanc.ldr"
## Where the models the app ships are: its examples, and the gallery's own.
const SHIPPED: Array = ["res://models/", "res://tools/web/gallery_seeds/"]
const AUTHORED := "0 !BRICKWORKS AUTHORED_STEPS"
## Parts a copy of which stands square on top of one: bricks and plates.
const STACKS: Array = ["3001", "3002", "3003", "3004", "3005", "3008", "3009", "3010", "3622",
	"3020", "3021", "3022", "3023", "3024", "3710", "3666", "3460", "3795", "3034", "3832", "3623"]

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _shell: Shell
var _out: String = ""
var _only: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_out = OS.get_environment("SK_OUT")
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
	for _n: int in 30:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_store.keeps = true
	_only = OS.get_environment("SK_ONLY").split(",", false)
	for model: Array in MODELS:
		if _asked(str(model[0])):
			print("\n== %s" % model[0])
			await _case(str(model[0]), str(model[1]))
	if _asked("edits"):
		await _station_edits()
	if _asked("callouts"):
		await _callouts("castle", CASTLE)
		await _callouts("robot", ROBOT)
	if _asked("nosteps"):
		await _no_steps()
	if _asked("time"):
		await _time()
	if _asked("shipped"):
		await _shipped()
	print("")
	if _failures == 0:
		print("every model comes back in the steps it was saved in, and an edit changes only the steps it touches")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _asked(name: String) -> bool:
	return _only.is_empty() or _only.has(name)


# -- each model ------------------------------------------------------------------


func _case(label: String, path: String) -> void:
	var called: String = "Stepkeep2 " + label
	_forget(called)
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: LdrModel = LdrModel.parse(text, path.get_file())
	# The app's own: as steps_are_saved reads it, and on a build before it too.
	var own: bool = not parsed.steps_are_authored()
	await _open(path)
	if own:
		_check("%s: as filed (%d STEP lines): its steps kept and no one's (%s, %s)"
			% [label, text.count("\n0 STEP"), _own_steps(), AuthorSteps.any(_world, _store.scenery)],
			_own_steps() and AuthorSteps.any(_world, _store.scenery))
		var written: String = _store.to_text(_store.title, true)
		var off: int = _file_moved(text, written)
		_check("%s: every part in the step the file has it in (in another step %d), no AUTHORED_STEPS written"
			% [label, off], off == 0 and not written.contains(AUTHORED))
	_store.title = called
	var before: Array = _plan()
	var sig_before: Dictionary = _signatures()
	if not _check("%s: saved" % label, _store.save_as(called)):
		return
	var saved_at: String = ModelStore.saved_path(called)
	var first: String = FileAccess.get_file_as_string(saved_at)
	_keep(label + "_saved.ldr", first)
	_check("%s: the file says no more of its steps than before (AUTHORED_STEPS %s, someone's: %s)"
		% [label, first.contains(AUTHORED), not own],
		first.contains(AUTHORED) == text.contains(AUTHORED) and not first.contains("PLANNED_STEPS"))

	# Opened again from the saved file, as File › Open does.
	await _reopen(saved_at)
	if own:
		_check("%s: reopened, its steps the file's (steps_own %s)" % [label, _own_steps()],
			_own_steps())
	var reopened: Array = _plan()
	var sig_reopened: Dictionary = _signatures()
	var moved: int = _moved_between(before, sig_before, reopened, sig_reopened)
	_check("%s: the plan after the reopen is the one shown before the save (%d steps, %d steps; parts in another step %d)"
		% [label, before.size(), reopened.size(), moved], moved == 0 and before.size() == reopened.size())
	var rewritten: String = _store.to_text(_store.title, true)
	_keep(label + "_written_after.ldr", rewritten)
	if not _check("%s: the save's whole write after the reopen is the file, byte for byte (in another step %d)"
			% [label, _file_moved(first, rewritten)], rewritten == first):
		_first_diff(first, rewritten)
	_store.save_as(called)
	var second: String = FileAccess.get_file_as_string(saved_at)
	_check("%s: saved again unedited, byte for byte (%d bytes)" % [label, first.length()], second == first)
	print("  ....%s's steps test, as shared: %s" % [label, await _steps_test(first)])

	# One part put on the model's top, as a person's edit is followed.
	var top: BrickWorld.Brick = _top_of(func(_brick: BrickWorld.Brick) -> bool: return true)
	if not _check("%s: a brick or plate on top to put a part on" % label, top != null):
		return
	var added: int = _put_on(top)
	await _edited()
	if not _check("%s: a %s put on top" % [label, top.part_id], added != 0):
		return
	var with_part: Array = _plan()
	var at: Dictionary = _on_model_at(with_part)
	var changed: int = _changed_steps(reopened, _without(with_part, added))
	if own:
		_added_ok("%s: the part put on top" % label, added, reopened, with_part)
	else:
		_check("%s: the part put on top is in step %d of %d, after step %d, which puts on what it rests on; every other step as it was (changed %d)"
			% [label, int(at.get(added, -2)) + 1, with_part.size(), int(at.get(top.id, -2)) + 1, changed],
			at.has(top.id) and int(at.get(added, -1)) > int(at[top.id]) and changed == 0)
	if changed > 0:
		_say_changed(reopened, _without(with_part, added))
	_builder.undo()
	await _frames(2)
	var undone: Array = _plan()
	_check("%s: Undo gives back the plan before it (changed %d)" % [label, _changed_steps(reopened, undone)],
		_changed_steps(reopened, undone) == 0)
	_check("%s: ...and the save before it, byte for byte" % label,
		_store.to_text(_store.title, true) == rewritten)
	_builder.redo()
	await _frames(2)
	var redone: Array = _plan()
	_check("%s: Redo gives back the plan with it (changed %d)" % [label, _changed_steps(with_part, redone)],
		_changed_steps(with_part, redone) == 0)
	var sig_with: Dictionary = _signatures()
	_store.save_as(called)
	var third: String = FileAccess.get_file_as_string(saved_at)
	_keep(label + "_saved_added.ldr", third)
	_check("%s: saved with it, the file one part more (%d, %d), every other part in its step (in another step %d)"
		% [label, ModelStore.count_in(first), ModelStore.count_in(third), _file_moved(first, third) - 1],
		ModelStore.count_in(third) == ModelStore.count_in(first) + 1
		and (not own or _file_moved(first, third) == 1))
	await _reopen(saved_at)
	var again: Array = _plan()
	var moved_again: int = _moved_between(with_part, sig_with, again, _signatures())
	_check("%s: saved with the part and opened again, the plan with it (parts in another step %d)"
		% [label, moved_again], moved_again == 0 and again.size() == with_part.size())

	# One part taken off, from a step in the middle.
	var now: Array = _plan()
	var middle: Array = now[now.size() / 2]
	var ids: Array = middle[2]
	if ids.is_empty():
		_forget(called)
		return
	var gone: int = int(ids[0])
	var gone_brick: BrickWorld.Brick = _world.get_brick(gone)
	var gone_said: String = "%s in %s" % [gone_brick.part_id, Assemblies.path_of(gone_brick)]
	var before_taking: String = _store.to_text(_store.title, true)
	_builder.remove_brick_id(gone)
	await _edited()
	var taken: Array = _plan()
	# Taken off a sub-model placed more than once, it is gone from every
	# copy: each of them is the part taken off.
	var gone_all: Array = []
	for step: Array in now:
		for id: Variant in step[2]:
			if _world.get_brick(int(id)) == null and not gone_all.has(id):
				gone_all.append(id)
	var changed_taken: int = _changed_steps(_without(now, gone_all), taken)
	_check("%s: one part (%s, in %d cop%s) taken off step %d, every other step as it was (steps changed %d)"
		% [label, gone_said, gone_all.size(), "y" if gone_all.size() == 1 else "ies", now.size() / 2 + 1,
		changed_taken], changed_taken == 0 and gone_all.has(gone))
	if changed_taken > 0:
		_say_changed(_without(now, gone_all), taken)
	_builder.undo()
	await _frames(2)
	_check("%s: Undo puts it back in its step" % label, _changed_steps(now, _plan()) == 0)
	_check("%s: ...and the save before it, byte for byte" % label,
		_store.to_text(_store.title, true) == before_taking)
	_forget(called)


# -- the station's edits ---------------------------------------------------------


func _station_edits() -> void:
	print("\n== edits (station)")
	await _open(STATION)
	var base: Array = _plan()
	var at: Dictionary = _on_model_at(base)
	print("  plan: %d steps" % base.size())

	# F: a brick on the floor beside the model.
	var low: BrickWorld.Brick = _lowest()
	if _check("F: a brick or plate on the floor to put another beside", low != null):
		var box: AABB = _world.model_bounds()
		var beside := Transform3D(low.transform.basis, Vector3(box.position.x - 160.0,
			low.transform.origin.y, box.position.z - 160.0))
		var floor_id: int = _builder.put_part(low.part_id, 4, beside)
		await _edited()
		var with_floor: Array = _plan()
		var now: Dictionary = _on_model_at(with_floor)
		var others: int = _changed_steps(base, _without(with_floor, floor_id))
		_check("F: a %s put on the floor beside the model is in step %d of %d, a new last step; every other step as it was (changed %d)"
			% [low.part_id, int(now.get(floor_id, -2)) + 1, with_floor.size(), others],
			floor_id != 0 and int(now.get(floor_id, -1)) == with_floor.size() - 1
			and with_floor.size() == base.size() + 1 and others == 0)
		_builder.undo()
		await _frames(2)

	# C: a brick of the first steps moved onto one of a later step with room
	# on it: in the air in its own step, so in that one's.
	var stacks: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return _stack(brick) and at.has(brick.id))
	var latest_first: Array = stacks.duplicate()
	latest_first.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at[a.id]) > int(at[b.id]))
	var earliest_first: Array = stacks.duplicate()
	earliest_first.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at[a.id]) < int(at[b.id]))
	var top: BrickWorld.Brick = null
	var moved_id: int = 0
	for under: BrickWorld.Brick in latest_first.slice(0, 80):
		for brick: BrickWorld.Brick in earliest_first.slice(0, 40):
			if int(at[brick.id]) >= int(at[under.id]):
				break
			if _builder.move_bricks({brick.id: _onto(under, brick)}) > 0:
				moved_id = brick.id
				top = under
				break
		if moved_id != 0:
			break
	if _check("C: a brick of the first steps with room on one of a later step", moved_id != 0):
		await _edited()
		var after: Array = _plan()
		_added_ok("C: a %s moved from step %d onto the %s of step %d" % [_world.get_brick(moved_id).part_id,
			int(at.get(moved_id, -2)) + 1, top.part_id, int(at.get(top.id, -2)) + 1], moved_id,
			_without(base, moved_id), after)
		var sig_after: Dictionary = _signatures()
		var called: String = "Stepkeep2 station moved"
		_forget(called)
		_store.title = called
		_store.save_as(called)
		var path: String = ModelStore.saved_path(called)
		_keep("station_moved.ldr", FileAccess.get_file_as_string(path))
		await _reopen(path)
		var reread: Array = _plan()
		var moved_reread: int = _moved_between(after, sig_after, reread, _signatures())
		_check("C: saved and opened again, the plan with it moved (%d steps, were %d; parts in another step %d)"
			% [reread.size(), after.size(), moved_reread], moved_reread == 0 and reread.size() == after.size())
		_forget(called)

	# C2: a brick moved onto one of an earlier step keeps its step.
	await _open(STATION)
	var plan2: Array = _plan()
	var at2: Dictionary = _on_model_at(plan2)
	var stacks2: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return _stack(brick) and at2.has(brick.id))
	var late: Array = stacks2.duplicate()
	late.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at2[a.id]) > int(at2[b.id]))
	var early: Array = stacks2.duplicate()
	early.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return int(at2[a.id]) < int(at2[b.id]))
	var kept_id: int = 0
	var onto: BrickWorld.Brick = null
	for under: BrickWorld.Brick in early:
		for brick: BrickWorld.Brick in late.slice(0, 40):
			if int(at2[brick.id]) <= int(at2[under.id]):
				break
			if _builder.move_bricks({brick.id: _onto(under, brick)}) > 0:
				kept_id = brick.id
				onto = under
				break
		if kept_id != 0:
			break
	if _check("C2: a brick with room on one of an earlier step", kept_id != 0):
		await _edited()
		var after2: Array = _plan()
		var now2: Dictionary = _on_model_at(after2)
		var changed2: int = _changed_steps(plan2, after2)
		_check("C2: a %s of step %d moved onto the %s of step %d keeps its step (%d); every step as it was (changed %d)"
			% [_world.get_brick(kept_id).part_id, int(at2[kept_id]) + 1, onto.part_id, int(at2[onto.id]) + 1,
			int(now2.get(kept_id, -2)) + 1, changed2], changed2 == 0)
		_builder.undo()
		await _frames(2)

	# E: a step edit by the person makes the steps theirs.
	var plan3: Array = _plan()
	var part: int = int((plan3[plan3.size() / 2] as Array)[2][0])
	var said: String = _shell.change_steps("next", [part], null)
	await _frames(2)
	var theirs: String = _store.to_text(_store.title, true)
	_check("E: a part moved a step later by the person (%s): the steps theirs, AUTHORED_STEPS written (%s, %s)"
		% [said.get_slice("\n", 0).left(80), not _own_steps(), theirs.contains(AUTHORED)],
		not _own_steps() and theirs.contains(AUTHORED))
	_builder.undo()
	await _frames(2)
	var back: String = _store.to_text(_store.title, true)
	_check("E: undone, the steps no one's again, no AUTHORED_STEPS (%s, %s), every step as it was (changed %d)"
		% [_own_steps(), back.contains(AUTHORED), _changed_steps(plan3, _plan())],
		_own_steps() and not back.contains(AUTHORED) and _changed_steps(plan3, _plan()) == 0)

	# P: planned again only when asked: the timeline's Plan steps, then
	# edit_steps "plan" over MCP, each one undo.
	var plan4: Array = _plan()
	var text4: String = _store.to_text(_store.title, true)
	var depth: int = _builder.history_depth()
	var steps_bar: Node = _main.get("_steps")
	var button: Button = (steps_bar.get("_named") as Dictionary).get("steps_plan") as Button
	if _check("P: the timeline has Plan steps", button != null):
		# Pressed with the timeline open, in the model's own steps, as a
		# person presses it: it lays the steps out again as it opens.
		await steps_bar.call("start", _world, _world.library, _store.scenery)
		var mode_before: int = int(steps_bar.call("mode"))
		button.pressed.emit()
		for _n: int in 3600:
			await process_frame
			if steps_bar.get("_job") == null:
				break
		await _frames(2)
		var shown: int = (steps_bar.get("_steps") as Array).size()
		_check("P: the timeline laid out again in the order worked out (%d steps, the plan %d; order %d, was %d)"
			% [shown, _plan().size(), int(steps_bar.call("mode")), mode_before],
			shown == _plan().size() and int(steps_bar.call("mode")) == 0 and mode_before == 3)
		steps_bar.call("stop")
		await _frames(2)
		var planned: String = _store.to_text(_store.title, true)
		_check("P: Plan steps takes the saved steps off in one undo (any %s, own %s, depth +%d), the save still in steps, no AUTHORED_STEPS (%s)"
			% [AuthorSteps.any(_world, _store.scenery), _own_steps(), _builder.history_depth() - depth,
			planned.contains(AUTHORED)],
			not AuthorSteps.any(_world, _store.scenery) and not _own_steps()
			and _builder.history_depth() == depth + 1 and planned.contains("\n0 STEP")
			and not planned.contains(AUTHORED))
		_builder.undo()
		await _frames(2)
		_check("P: undone, the saved steps back, own (%s), every step as it was (changed %d)"
			% [_own_steps(), _changed_steps(plan4, _plan())],
			_own_steps() and _changed_steps(plan4, _plan()) == 0)
		_check("P: ...and the save before it, byte for byte",
			_store.to_text(_store.title, true) == text4)
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var by_mcp: String = str(await tools.run("edit_steps", {"op": "plan"}))
	await _frames(2)
	_check("P: edit_steps plan (\"%s\"): the same, one undo (any %s, depth +%d)"
		% [by_mcp.left(80), AuthorSteps.any(_world, _store.scenery), _builder.history_depth() - depth],
		not AuthorSteps.any(_world, _store.scenery) and _builder.history_depth() == depth + 1)
	var again: String = str(await tools.run("edit_steps", {"op": "plan"}))
	_check("P: asked again, nothing to do (\"%s\"), no undo added" % again.left(80),
		_builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(2)
	_check("P: undone, every step as it was (changed %d)" % _changed_steps(plan4, _plan()),
		_own_steps() and _changed_steps(plan4, _plan()) == 0)
	_check("P: ...and the save before it, byte for byte", _store.to_text(_store.title, true) == text4)

	# N2: the autosave's text with a part put on, as Save's.
	var high: BrickWorld.Brick = _top_of(func(_brick: BrickWorld.Brick) -> bool: return true)
	var added: int = _put_on(high) if high != null else 0
	await _edited()
	var with_part: Array = _plan()
	var saved: String = _store.to_text(_store.title, true)
	var autosaved: String = _store.to_text(_store.title)
	var off: int = _file_moved(saved, autosaved)
	_check("N2: with a part put on (%d), the autosave's text has every part in Save's step (in another %d)"
		% [added, off], added != 0 and off == 0)
	var restore_sig: Dictionary = _signatures()
	var file_path: String = "user://stepkeep_restore.ldr"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(autosaved)
	file.close()
	await _reopen(file_path)
	var restored: Array = _plan()
	var moved_restore: int = _moved_between(with_part, restore_sig, restored, _signatures())
	_check("N2: the autosave opened as a restore opens it: the plan with the part (%d steps, were %d; parts in another step %d)"
		% [restored.size(), with_part.size(), moved_restore],
		moved_restore == 0 and restored.size() == with_part.size())


# -- copies built on the side ----------------------------------------------------


func _callouts(label: String, from: String) -> void:
	print("\n== callouts (%s)" % label)
	await _open(from)
	var assemblies: Assemblies = _shell.assemblies
	var aside: Array[String] = []
	for unit: String in _world.unit_steps:
		if int(_world.unit_steps[unit]) >= 0 and not assemblies.ids_under(unit).is_empty():
			aside.append(unit)
	var base: Array = _plan()
	var base_sig: Dictionary = _signatures(false)
	print("  plan: %d steps, %d callouts; copies built on the side: %d %s" % [base.size(),
		_callout_count(base), aside.size(), str(aside.slice(0, 6))])
	if aside.is_empty():
		print("  no copy built on the side here")
		return

	# A: a copy built on the side renamed.
	var called: String = "Stepkeep2 %s callouts" % label
	_forget(called)
	_store.title = called
	_store.save_as(called)
	var path: String = ModelStore.saved_path(called)
	var before_text: String = FileAccess.get_file_as_string(path)
	await _reopen(path)
	assemblies = _shell.assemblies
	var copy: String = _biggest(aside, assemblies)
	var named: String = assemblies.rename(copy, "Stepkeep keep")
	await _edited()
	var renamed: Array = _plan()
	var renamed_sig: Dictionary = _signatures(false)
	var moved: int = _moved_between(base, base_sig, renamed, renamed_sig)
	_check("A: %s renamed %s: %d steps (were %d), %d callouts (were %d), parts in another step %d"
		% [copy, named, renamed.size(), base.size(), _callout_count(renamed), _callout_count(base), moved],
		moved == 0 and renamed.size() == base.size() and _callout_count(renamed) == _callout_count(base))
	_store.save_as(called)
	var after_text: String = FileAccess.get_file_as_string(path)
	_keep(label + "_renamed.ldr", after_text)
	_check("A: saved renamed, still a sub-model: 0 FILE lines %d (were %d), IN lines %d (were %d), lines placing a sub-model %d (were %d)"
		% [_files(after_text), _files(before_text), after_text.count("0 !BRICKWORKS IN "),
		before_text.count("0 !BRICKWORKS IN "), _sub_refs(after_text), _sub_refs(before_text)],
		_files(after_text) == _files(before_text)
		and after_text.count("0 !BRICKWORKS IN ") == before_text.count("0 !BRICKWORKS IN ")
		and _sub_refs(after_text) == _sub_refs(before_text))
	await _reopen(path)
	var reread: Array = _plan()
	var moved_reread: int = _moved_between(renamed, renamed_sig, reread, _signatures(false))
	_check("A: saved renamed and opened again, the plan as it was (%d steps; parts in another step %d)"
		% [reread.size(), moved_reread], moved_reread == 0 and reread.size() == renamed.size())

	# B: a part put on the top of a copy built on the side, in the model's own.
	var support: BrickWorld.Brick = _top_of(func(brick: BrickWorld.Brick) -> bool:
		return not AuthorSteps.home(_world, Assemblies.path_of(brick)).is_empty())
	if _check("B: a brick or plate on top of a copy built on the side", support != null):
		var plain: Array = _plan()
		var added: int = _put_on(support)
		await _edited()
		var with_part: Array = _plan()
		var changed: int = _added_ok("B: a %s put on the %s of %s" % [support.part_id, support.part_id,
			Assemblies.path_of(support)], added, plain, with_part)
		if changed > 0:
			_say_changed(plain, _without(with_part, added))
		_builder.undo()
		await _frames(2)

	# D: a copy of a sub-model pasted beside the model, as Copy and Paste put
	# one down: built as its other copies are, put on in a step, and saved
	# and opened again the same.
	assemblies = _shell.assemblies
	var smallest: String = ""
	for unit: String in _world.unit_steps:
		var count: int = assemblies.ids_under(unit).size()
		if count > 0 and not unit.contains("/") and (smallest.is_empty()
				or count < assemblies.ids_under(smallest).size()):
			smallest = unit
	if _check("D: a sub-model's copy to paste (%s)" % smallest, not smallest.is_empty()):
		var put: int = await _paste_beside(smallest)
		await _edited()
		# A copy with no step in what places it, and a part with none.
		var pasted: String = ""
		var unstepped: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if _store.scenery.has(brick.id):
				continue
			if brick.step < 0:
				unstepped += 1
			var at: String = ""
			for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
				at = Assemblies.join(at, segment)
				if not _world.unit_steps.has(at):
					pasted = at
		var with_copy: Array = _plan()
		var sig_copy: Dictionary = _signatures(false)
		_check("D: %d parts of %s pasted beside the model: every part in a step (%d not), every copy put on in one (%s)"
			% [put, smallest, unstepped, "yes" if pasted.is_empty() else pasted + " not"],
			put > 0 and unstepped == 0 and pasted.is_empty())
		_store.save_as(called)
		_keep(label + "_pasted.ldr", FileAccess.get_file_as_string(path))
		await _reopen(path)
		var pasted_again: Array = _plan()
		var moved_pasted: int = _moved_between(with_copy, sig_copy, pasted_again, _signatures(false))
		_check("D: saved with the copy and opened again, the plan as it was (%d steps, were %d; parts in another step %d)"
			% [pasted_again.size(), with_copy.size(), moved_pasted],
			moved_pasted == 0 and pasted_again.size() == with_copy.size())
	_forget(called)


# -- a file with no steps, and the time an open takes -------------------------------


func _no_steps() -> void:
	for model: Array in [["castle", CASTLE], ["station", STATION]]:
		await _no_steps_of(str(model[0]), str(model[1]))


## A model built here and saved for the first time: [param from]'s file with
## its STEP lines taken out, as a model nobody gave steps is, opened, worked
## out, saved and opened again as File › Open does.
func _no_steps_of(label: String, from: String) -> void:
	print("\n== nosteps %s" % label)
	var text: String = FileAccess.get_file_as_string(from)
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges() != "0 STEP":
			kept.append(line)
	var file_path: String = "user://stepkeep_nosteps.ldr"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string("\n".join(kept))
	file.close()
	await _reopen(file_path)
	var plan: Array = _plan()
	var most: int = 0
	for step: Array in plan:
		most = maxi(most, (step[2] as Array).size())
	_check("nosteps %s: with no STEP lines worked out afresh (steps_own %s, any %s): %d steps, the biggest %d parts of %d"
		% [label, _own_steps(), AuthorSteps.any(_world, _store.scenery), plan.size(), most, _parts_on()],
		not _own_steps() and not AuthorSteps.any(_world, _store.scenery) and plan.size() > 10
		and most * 4 < _parts_on())
	var saved: String = _store.to_text(_store.title, true)
	_check("nosteps %s: saved, its worked-out steps written (%d STEP lines), no AUTHORED_STEPS"
		% [label, saved.count("\n0 STEP")], saved.count("\n0 STEP") > 10 and not saved.contains(AUTHORED))
	_keep("nosteps_%s_saved" % label, saved)
	print("  ....its steps test, as shared: %s" % await _steps_test(saved))
	# The goal itself: a model's first save opened again shows the steps it
	# was saved in, and the booklet's banners with them.
	var sig: Dictionary = _signatures()
	var banners: Array = _banners()
	var saved_path: String = "user://stepkeep_nosteps_saved.ldr"
	file = FileAccess.open(saved_path, FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	await _reopen(saved_path)
	var again: Array = _plan()
	var moved: int = _moved_between(plan, sig, again, _signatures())
	_check("nosteps %s: saved and opened again, its steps the file's (own %s), the plan the one worked out (%d steps, were %d; parts in another step %d)"
		% [label, _own_steps(), again.size(), plan.size(), moved],
		_own_steps() and again.size() == plan.size() and moved == 0)
	var banners_again: Array = _banners()
	var off: int = absi(banners.size() - banners_again.size())
	for index: int in mini(banners.size(), banners_again.size()):
		if banners[index] != banners_again[index]:
			off += 1
	# Where the order worked out moved on to a region is not in the file:
	# near it, a tenth of the steps at most under another banner.
	_check("nosteps %s: the booklet's banners near those worked out (%d sections, were %d; %d of %d steps under another)"
		% [label, _sections_in(banners_again), _sections_in(banners), off, banners.size()],
		off * 10 <= banners.size() and (_sections_in(banners) < 2 or _sections_in(banners_again) >= 2))
	var resaved: String = _store.to_text(_store.title, true)
	_check("nosteps %s: saved again, byte for byte (lines moved %d)" % [label, _file_moved(saved, resaved)],
		resaved == saved)
	if resaved != saved:
		_first_diff(saved, resaved)


## What the steps test says of [param text] shared, as a model page shows it.
func _steps_test(text: String) -> String:
	var tested: Dictionary = (await SharedPages.attach_tested(text, _world.library, _store))["tested"]
	var steps: Dictionary = (tested.get("tests", {}) as Dictionary).get("steps", {})
	return ("passes" if bool(steps.get("ok", false)) else "fails") + ", " + str(steps.get("why", "")).left(160)


## Each step's banner, as the booklet shows it (Step.section).
func _banners() -> Array:
	var out: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _world.library, _store.scenery, {}, true):
		out.append(step.section)
	return out


func _sections_in(banners: Array) -> int:
	var count: int = 0
	var was: String = ""
	for banner: Variant in banners:
		if str(banner) != was and not str(banner).is_empty():
			count += 1
		was = str(banner)
	return count


func _time() -> void:
	print("\n== time (said, not checked)")
	for path: String in [CASTLE, ORTHANC]:
		_main.call("clear_model")
		await _frames(4)
		var start: int = Time.get_ticks_usec()
		_store.open(path)
		var opened: float = float(Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		var plan: Array = _plan()
		var planned: float = float(Time.get_ticks_usec() - start) / 1000.0
		print("  %s: opened in %.0f ms, its %d steps read in %.0f ms (steps own %s, any %s)" % [path.get_file(),
			opened, plan.size(), planned, _own_steps(), AuthorSteps.any(_world, _store.scenery)])
	# Orthanc as the app's own held steps, its AUTHORED_STEPS line taken out:
	# the biggest model whose edits are followed. Its open, one part put on and
	# followed, and Plan steps, each the work of one frame (16 ms is the bar).
	var own_path: String = "user://stepkeep_orthanc_own.ldr"
	var file: FileAccess = FileAccess.open(own_path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(ORTHANC).replace(AUTHORED + "\n", ""))
	file.close()
	_main.call("clear_model")
	await _frames(4)
	var began: int = Time.get_ticks_usec()
	_store.open(own_path)
	var open_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	await _frames(4)
	var own: bool = _own_steps()
	var top: BrickWorld.Brick = _top_of(func(_brick: BrickWorld.Brick) -> bool: return true)
	began = Time.get_ticks_usec()
	var put: int = _put_on(top) if top != null else 0
	_main.call("_on_model_edited")
	var edit_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	await _frames(2)
	began = Time.get_ticks_usec()
	var answer: String = _shell.change_steps("plan", [], null)
	var plan_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	print("  orthanc as its own (steps own %s): opened in %.0f ms; a part put on (%s) and followed in %.1f ms; Plan steps (\"%s\") in %.1f ms"
		% [own, open_ms, put != 0, edit_ms, answer.left(60), plan_ms])


# -- the models the app ships -------------------------------------------------------


func _shipped() -> void:
	print("\n== shipped")
	var out: String = OS.get_environment("SK_SHIP_OUT")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
	var seen: int = 0
	for folder: String in SHIPPED:
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.get_extension().to_lower() not in ["ldr", "mpd"]:
				continue
			var path: String = folder + file_name
			var text: String = FileAccess.get_file_as_string(path)
			var parsed: LdrModel = LdrModel.parse(text, file_name)
			if parsed == null or not parsed.steps_are_saved():
				print("  --    %s: %s" % [path, "its author's steps" if parsed != null
					and parsed.steps_are_authored() else "no steps to keep"])
				continue
			seen += 1
			var faults: Array = await _air(text)
			if out.is_empty() or int(faults[0]) == 0:
				_check("shipped %s: its saved steps put no part in the air (%d in the air, %d hidden)"
					% [path, faults[0], faults[1]], int(faults[0]) == 0)
				continue
			print("  shipped %s: its saved steps put %d parts in the air (%d hidden): worked out again"
				% [path, faults[0], faults[1]])
			await _planned_again(path, text, out.path_join(file_name), faults)
	_check("shipped: %d of the models it ships hold their saved steps" % seen, seen > 0)


## [param text]'s parts put down in the air and hidden behind what is built,
## as a share's steps test finds them (Tested): [in the air, hidden], -1 for
## each when it was not tested.
func _air(text: String) -> Array:
	var tested: Dictionary = (await SharedPages.attach_tested(text, _world.library, _store))["tested"]
	var tests: Dictionary = tested.get("tests", {})
	if not tests.has("steps"):
		return [-1, -1]
	if bool((tests["steps"] as Dictionary).get("ok", false)):
		return [0, 0]
	var said: Array = Tested.said_all.get("steps", [])
	var air: int = said.filter(func(line: Variant) -> bool: return str(line).ends_with("in the air")).size()
	return [air, said.size() - air]


## The shipped model at [param path] worked out again as Plan steps does and
## saved as Save writes it, to [param into]: reopened, every part in the step
## worked out; its steps test, no part in the air; saved again, byte for byte.
## Its lines besides its parts and steps, as the file had them.
func _planned_again(path: String, text: String, into: String, before: Array) -> void:
	await _open(path)
	var called: String = _store.title
	var said: String = _shell.change_steps("plan", [], null)
	await _frames(4)
	var planned: Array = _plan()
	var sig: Dictionary = _signatures()
	_forget(called)
	if not _check("shipped %s: worked out again (\"%s\") and saved as %s" % [path, said, called],
			_store.save_as(called)):
		return
	var saved_at: String = ModelStore.saved_path(called)
	var saved: String = FileAccess.get_file_as_string(saved_at)
	var file: FileAccess = FileAccess.open(into, FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	var gone: Array = _besides_steps(text).filter(func(line: String) -> bool:
		return not _besides_steps(saved).has(line))
	var new: Array = _besides_steps(saved).filter(func(line: String) -> bool:
		return not _besides_steps(text).has(line))
	print("  note  shipped %s: written whole, its lines besides its parts and steps: %d gone %s, %d new %s"
		% [path, gone.size(), gone.slice(0, 3), new.size(), new.slice(0, 3)])
	_check("shipped %s: the same parts, %d (were %d)" % [path, ModelStore.count_in(saved),
		ModelStore.count_in(text)], ModelStore.count_in(saved) == ModelStore.count_in(text))
	await _reopen(saved_at)
	var reopened: Array = _plan()
	var moved: int = _moved_between(planned, sig, reopened, _signatures())
	_check("shipped %s: opened again, the steps worked out (%d steps, were %d; parts in another step %d), its own (%s)"
		% [path, reopened.size(), planned.size(), moved, _own_steps()],
		moved == 0 and reopened.size() == planned.size() and _own_steps())
	var after: Array = await _air(saved)
	_check("shipped %s: its steps test puts no part in the air (%d, were %d; hidden %d, were %d)"
		% [path, after[0], before[0], after[1], before[1]], int(after[0]) == 0)
	_store.save_as(called)
	var again: String = FileAccess.get_file_as_string(saved_at)
	_check("shipped %s: saved again unedited, byte for byte (%d bytes)" % [path, saved.length()],
		again == saved)
	_forget(called)


## [param text]'s lines that are neither a part, a reference to a sub-model nor
## a step: its header, sub-models' names and the app's own lines.
static func _besides_steps(text: String) -> Array:
	var out: Array = []
	for raw: String in text.replace("\r\n", "\n").split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("1 ") or line == "0 STEP" or line.begins_with("0 ROTSTEP"):
			continue
		out.append(line)
	return out


# -- reading the plan --------------------------------------------------------------


## The plan the timeline and the booklet show: each step [its callout, its
## step in it, its parts' and copies' ids, sorted].
func _plan() -> Array:
	var out: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _world.library, _store.scenery, {}, true):
		var ids: Array = Array(step.brick_ids)
		for copy: PackedInt64Array in step.copies:
			ids.append_array(Array(copy))
		ids.sort()
		out.append([step.callout, step.callout_step, ids])
	return out


func _callout_count(plan: Array) -> int:
	var seen: Dictionary = {}
	for step: Array in plan:
		if int(step[0]) != 0:
			seen[int(step[0])] = true
	return seen.size()


## Each part's id -> what it is and where, the same in another opening; with
## its copy's path unless [param with_path] is false (a rename changes it).
func _signatures(with_path: bool = true) -> Dictionary:
	var low: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			low = minf(low, brick.transform.origin.y)
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var at: Vector3 = brick.transform.origin
		out[brick.id] = "%s|%d|%d|%d|%d|%s" % [brick.part_id, brick.color_code, roundi(at.x),
			roundi(at.y - low), roundi(at.z), Assemblies.path_of(brick) if with_path else ""]
	return out


## How many parts of [param b] are in another step than in [param a], each
## plan's parts by what they are and where.
func _moved_between(a: Array, sig_a: Dictionary, b: Array, sig_b: Dictionary) -> int:
	var at: Dictionary = {}
	for index: int in a.size():
		for id: Variant in (a[index] as Array)[2]:
			var key: String = "%s#%d" % [sig_a.get(int(id), "?"), index]
			at[key] = int(at.get(key, 0)) + 1
	var off: int = 0
	for index: int in b.size():
		for id: Variant in (b[index] as Array)[2]:
			var key: String = "%s#%d" % [sig_b.get(int(id), "?"), index]
			if int(at.get(key, 0)) > 0:
				at[key] = int(at[key]) - 1
			else:
				off += 1
	return off


## How many steps of [param b] are not [param a]'s, in turn.
func _changed_steps(a: Array, b: Array) -> int:
	var changed: int = absi(a.size() - b.size())
	for index: int in mini(a.size(), b.size()):
		if str(a[index]) != str(b[index]):
			changed += 1
	return changed


## The first few steps where [param a] and [param b] differ, said.
func _say_changed(a: Array, b: Array) -> void:
	var said: int = 0
	for index: int in maxi(a.size(), b.size()):
		var x: String = str(a[index]) if index < a.size() else "(none)"
		var y: String = str(b[index]) if index < b.size() else "(none)"
		if x == y:
			continue
		print("      step %d: %s\n            / %s" % [index + 1, x.left(160), y.left(160)])
		said += 1
		if said >= 4:
			return


## [param plan] without the part or parts [param gone], a step only they
## were in gone, and a callout's steps after it numbered as the app numbers
## them then.
func _without(plan: Array, gone: Variant) -> Array:
	var away: Array = gone if gone is Array else [gone]
	var out: Array = []
	var dropped: Dictionary = {}    ## a callout -> how many of its steps went
	for step: Array in plan:
		var ids: Array = (step[2] as Array).duplicate()
		var had: bool = false
		for id: Variant in away:
			if ids.has(id):
				had = true
				ids.erase(id)
		if had and ids.is_empty():
			if int(step[1]) > 0:
				dropped[step[0]] = int(dropped.get(step[0], 0)) + 1
			continue
		# A callout's steps after one emptied are numbered one less, the
		# emptied step gone: the same steps.
		out.append([step[0], int(step[1]) - int(dropped.get(step[0], 0)) if int(step[1]) > 0
			else step[1], ids])
	return out


## Each part's id -> the first step that has it on the model: its own, or the
## one that puts on the copy built on the side it is in.
func _on_model_at(plan: Array) -> Dictionary:
	var out: Dictionary = {}
	for index: int in plan.size():
		var step: Array = plan[index]
		if int(step[1]) != 0:
			continue
		for id: Variant in step[2]:
			if not out.has(int(id)):
				out[int(id)] = index
	return out


## Each part of the files in another step than in [param a], by what it is,
## where, its copy and its step in its section, as LDraw reads them.
func _file_moved(a: String, b: String) -> int:
	var at: Dictionary = {}
	for placement: LdrModel.Placement in LdrModel.parse(a, "m").flatten(_world.library.parts):
		var key: String = _file_key(placement)
		at[key] = int(at.get(key, 0)) + 1
	var off: int = 0
	for placement: LdrModel.Placement in LdrModel.parse(b, "m").flatten(_world.library.parts):
		var key: String = _file_key(placement)
		if int(at.get(key, 0)) > 0:
			at[key] = int(at[key]) - 1
		else:
			off += 1
	return off


func _file_key(placement: LdrModel.Placement) -> String:
	var at: Vector3 = placement.transform.origin
	return "%s|%d|%d|%d|%d|%s|%s|%d" % [placement.part_id, placement.color_code, roundi(at.x),
		roundi(at.y), roundi(at.z), placement.group, placement.unit, placement.step]


func _files(text: String) -> int:
	return text.count("\n0 FILE ") + int(text.begins_with("0 FILE "))


## How many type-1 lines of [param text] place a .ldr (a sub-model).
func _sub_refs(text: String) -> int:
	var count: int = 0
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if bare.begins_with("1 ") and bare.to_lower().ends_with(".ldr"):
			count += 1
	return count


func _biggest(paths: Array[String], assemblies: Assemblies) -> String:
	var best: String = paths[0]
	var most: int = -1
	for path: String in paths:
		var count: int = assemblies.ids_under(path).size()
		if count > most:
			most = count
			best = path
	return best


# -- parts -----------------------------------------------------------------------


func _stack(brick: BrickWorld.Brick) -> bool:
	if _store.scenery.has(brick.id) or not STACKS.has(brick.part_id.get_basename()):
		return false
	for turn: Basis in [Basis.IDENTITY, Basis(Vector3.UP, PI / 2.0), Basis(Vector3.UP, PI),
			Basis(Vector3.UP, -PI / 2.0)]:
		if brick.transform.basis.is_equal_approx(turn):
			return true
	return false


## The highest brick or plate square on the baseplate that [param which] takes.
func _top_of(which: Callable) -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not _stack(brick) or not bool(which.call(brick)):
			continue
		if best == null or brick.transform.origin.y > best.transform.origin.y:
			best = brick
	return best


## The lowest brick or plate square on the baseplate.
func _lowest() -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if _stack(brick) and (best == null or brick.transform.origin.y < best.transform.origin.y):
			best = brick
	return best


func _rise(brick: BrickWorld.Brick) -> float:
	var info: PartLibrary.PartInfo = _world.library.parts.get(brick.part_id)
	return 24.0 if info != null and info.bounds.size.y >= 24.0 else 8.0


## A part like [param on] put on its top, as put_part puts one: in no copy.
func _put_on(on: BrickWorld.Brick) -> int:
	return _builder.put_part(on.part_id, 4, on.transform.translated(Vector3(0.0, _rise(on), 0.0)))


## Whether the part [param added] is in the step of its section that has
## what it rests on: that part's own where it is of the section, else the
## one the section puts its copy on in, the latest of them; on the model
## never before any of them; every other step of [param before] as it was in
## [param after]. Returns how many other steps changed.
func _added_ok(what: String, added: int, before: Array, after: Array) -> int:
	var at: Dictionary = _on_model_at(after)
	var changed: int = _changed_steps(before, _without(after, added))
	var brick: BrickWorld.Brick = _world.get_brick(added)
	var section: String = AuthorSteps.home(_world, Assemblies.path_of(brick))
	var rests: Array = _rests(added)
	var latest: int = -1
	var in_file: int = -1
	for under: BrickWorld.Brick in rests:
		latest = maxi(latest, int(at.get(under.id, -1)))
		in_file = maxi(in_file, _step_holding(under, section))
	_check("%s is in step %d of %d, its section's step %d, the one that has what it rests on (%d; %d part%s under it, on the model by step %d); every other step as it was (changed %d)"
		% [what, int(at.get(added, -2)) + 1, after.size(), brick.step + 1, in_file + 1,
		rests.size(), "" if rests.size() == 1 else "s", latest + 1, changed],
		not rests.is_empty() and in_file >= 0 and brick.step == in_file
		and int(at.get(added, -1)) >= latest and changed == 0)
	_say_around(before, after, int(at.get(added, -1)))
	return changed


## The copy [param path] copied and pasted beside the model, as Copy and
## Paste put it down. How many parts were put down.
func _paste_beside(path: String) -> int:
	var assemblies: Assemblies = _shell.assemblies
	assemblies.leave_to(Assemblies.parent_of(path))
	_builder.clear_selection()
	for brick_id: int in assemblies.ids_under(path):
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())
	_builder.copy_selection()
	assemblies.leave_to("")
	_builder.hold_copy(Carry.clipboard)
	var carry: Carry = _builder.carrying
	var box: AABB = _world.model_bounds()
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	var put: int = 0
	for k: int in 6:
		var by := Vector3(box.size.x + 4.0 * BrickLattice.STUD * (k + 1), 0.0, 0.0)
		if carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
			put = _builder.place()
			break
	await _frames(4)
	_builder.cancel_carry()
	_builder.clear_selection()
	return put


## Where [param brick] stands on [param under]'s top, turned as it is.
func _onto(under: BrickWorld.Brick, brick: BrickWorld.Brick) -> Transform3D:
	return Transform3D(under.transform.basis, under.transform.origin + Vector3(0.0, _rise(brick), 0.0))


## What [param id] rests on: the parts one layer under it.
func _rests(id: int) -> Array:
	var lattice: BrickLattice = _builder.lattice
	var out: Array = []
	for other_id: int in lattice.blockers_boxes(BrickLattice.moved_by(lattice.boxes_of(id),
			Vector3i(0, -1, 0)), id, _store.scenery):
		if _world.get_brick(other_id) != null:
			out.append(_world.get_brick(other_id))
	return out


## The step of [param section] that has [param brick] on: its own, where it
## is of the section, else the step that puts on the copy holding it. -1
## for one outside the section.
func _step_holding(brick: BrickWorld.Brick, section: String) -> int:
	var path: String = Assemblies.path_of(brick)
	if AuthorSteps.home(_world, path) == section:
		return brick.step
	if not section.is_empty() and not path.begins_with(section + "/"):
		return -1
	var copy: String = section
	for segment: String in Assemblies.segments(path).slice(Assemblies.segments(section).size()):
		copy = Assemblies.join(copy, segment)
		var given: int = int(_world.unit_steps.get(copy, -1))
		if given != AuthorSteps.IN_PARENT:
			return given
	return -1


## The steps round [param index] before and after an edit, said.
func _say_around(before: Array, after: Array, index: int) -> void:
	for at: int in range(maxi(0, index - 2), mini(after.size(), index + 3)):
		print("      step %d: %s / %s" % [at + 1, str(before[at]).left(70) if at < before.size()
			else "(none)", str(after[at]).left(70)])


## What follows a person's edit, as the app runs it after each
## (Main._on_model_edited: ModelStore.looks_follow_edit).
func _edited() -> void:
	_main.call("_on_model_edited")
	await _frames(2)


# -- the rest --------------------------------------------------------------------


func _open(path: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	_store.open(path)
	_bar.opened.emit(_parts_on())
	await _frames(6)


func _reopen(path: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


func _first_diff(a: String, b: String) -> void:
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "(none)"
		var y: String = lb[n] if n < lb.size() else "(none)"
		if x != y:
			print("      first difference at line %d of %d/%d:\n        < %s\n        > %s" % [n + 1, la.size(),
				lb.size(), x, y])
			return


func _keep(name: String, text: String) -> void:
	if _out.is_empty():
		return
	var file: FileAccess = FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _forget(name: String) -> void:
	DirAccess.remove_absolute(ModelStore.saved_path(name))
	var folder: String = ModelVersions.folder(ModelStore._safe_name(name))
	if DirAccess.dir_exists_absolute(folder):
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)


## Whether the world says its steps are the app's own saved ones
## (BrickWorld.steps_own); false on a build before it, for the counts before.
func _own_steps() -> bool:
	return _world.get("steps_own") == true


func _parts_on() -> int:
	return _world.brick_count() - _store.scenery.size()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	if ok:
		print("  ok    %s" % what)
	else:
		_failures += 1
		print("  FAIL  %s" % what)
	return ok
