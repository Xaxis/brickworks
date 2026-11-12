## cfcheck: an independent attack on copyfaults (7e6cb1aec). Reuses
## copyfaults_probe's helpers; fixtures in src/dev/fixtures/cfc_*.
##
## Kept by copyfaults2 as cfcheck wrote it (bench/results/cfcheck-2026-11-11)
## but for these: cap, stepdelname and replaceall run by default, as its later
## runs ran them, and metas2 only when asked (CFCHECK_CASES=metas2), red on
## 7e6cb1aec and live for metalines to fix; the name clearautosave restores
## is the one a restore with no clear gives (its control); a twin follows part by part (Assemblies
## .copies_follow), so a part in its copy's placing colour painted in one
## copy leaves the other's (twinpaint) and a step edit is on both copies of
## a sub-model built in its own steps (stepcolour); and "saved again" leaves
## out what a reopened whole write changes as 7e6cb1aec writes it too
## (copyfaults_probe._as_kept: its TITLE line, metalines' to fix).
##
##   godot --headless --path . --script src/dev/cfcheck_probe.gd
##
##   CFCHECK_CASES=owncolour,mirror   those cases
extends "res://src/dev/copyfaults_probe.gd"

const MINE: Array = ["owncolour", "own16", "ownstep", "mirror", "nested", "twinpaint",
	"relay", "stepcolour", "wing2steps", "ungroup", "makeunique", "emptystep", "clearids",
	"clearabsent", "clearautosave", "cap", "stepdelname", "replaceall"]


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1500.0).timeout.connect(func() -> void:
		print("cfcheck probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var cases: Array = MINE if OS.get_environment("CFCHECK_CASES").is_empty() \
		else Array(OS.get_environment("CFCHECK_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"owncolour": await _c_owncolour("cfc_owncolour.mpd")
			"own16": await _c_owncolour("cfc_own16.mpd")
			"ownstep": await _c_ownstep()
			"relay": await _c_relay()
			"cap": await _c_cap()
			"stepdelname": await _c_stepdelname()
			"savedump": await _c_savedump()
			"mirror": await _c_mirror()
			"nested": await _c_nested()
			"twinpaint": await _c_twinpaint()
			"replaceall": await _c_replaceall()
			"stepcolour": await _c_stepcolour()
			"wing2steps": await _c_wing2steps()
			"ungroup": await _c_regroups("ungroup")
			"makeunique": await _c_regroups("makeunique")
			"emptystep": await _c_emptystep()
			"clearids": await _c_clearids()
			"clearabsent": await _c_clearabsent()
			"clearautosave": await _c_clearautosave()
			"metas2": await _c_metas2()
			_: _check("no such case %s" % name, false)
	print("\ncfcheck probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- helpers --------------------------------------------------------------------------


## Each part of the copy at [param path] as part, colour and height (y),
## sorted: what a move along x or z leaves alone.
func _colours(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or Assemblies.path_of(brick) != path:
			continue
		out.append("%s c%d y%.1f" % [brick.part_id, brick.color_code, brick.transform.origin.y])
	out.sort()
	return out


func _part_in(path: String, part: String, nth: int = 0) -> BrickWorld.Brick:
	var found: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.part_id == part:
			found.append(brick)
	found.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y < b.transform.origin.y)
	return found[nth] if nth < found.size() else null


static func _ids_of(said: Array) -> Array:
	var out: Array = []
	for line: String in said:
		out.append(line.get_slice(" ", 0))
	return out


static func _kinds(step: Dictionary) -> String:
	var out := PackedStringArray()
	for inner: Variant in step.get("steps", []):
		if inner is Dictionary:
			out.append(str((inner as Dictionary).get("undo", "")))
	return ", ".join(out)


func _select(ids: Array) -> void:
	_builder.clear_selection()
	for id: int in ids:
		_builder.selection[id] = true
	_builder.selection_changed.emit(ids.size())


func _edited() -> void:
	_main.call("_on_model_edited")
	await _frames(4)


## Undo then redo by hand, each checked against [param opened] and
## [param after] (every part with its number, and the world's tables).
func _undo_redo(what: String, opened: Array, opened_tables: String, after: Array,
		after_tables: String) -> void:
	_shell.run("undo")
	await _frames(6)
	_check("%s undone: every part as opened%s" % [what, _unlike(opened, _every_part())],
		opened == _every_part())
	_check("...the tables as opened%s" % ("" if _tables() == opened_tables
		else " (" + _tables().left(300) + " vs " + opened_tables.left(300) + ")"),
		_tables() == opened_tables)
	_shell.run("redo")
	await _frames(6)
	_check("%s redone: every part as after%s" % [what, _unlike(after, _every_part())],
		after == _every_part())
	_check("...the tables as after%s" % ("" if _tables() == after_tables
		else " (" + _tables().left(300) + " vs " + after_tables.left(300) + ")"),
		_tables() == after_tables)


func _saved_reopened(what: String, with_steps: bool = true) -> void:
	var shown: Array = _looks(with_steps)
	var saved: String = _save()
	await _open(saved)
	_check("%s saved and opened again: every part, colour, place%s as shown%s" % [what,
		" and step" if with_steps else "", _unlike(shown, _looks(with_steps))],
		shown == _looks(with_steps))
	var second: String = _save()
	_check("...saved again: the same file%s" % _first_unlike(_as_kept(saved), _as_kept(second)),
		_as_kept(second) == _as_kept(saved))
	_whole_write_note()


# -- 1: the colour map ------------------------------------------------------------------


## A sub-model with a part of its own in red, placed in red and in blue:
## one part of either copy moved, the other keeps its colours.
func _c_owncolour(fixture: String) -> void:
	print("  %s" % fixture)
	var text: String = _fixture(fixture)
	for edited: String in ["Post#1", "Post#2"]:
		await _open(text)
		var twin: String = "Post#2" if edited == "Post#1" else "Post#1"
		var was: Array = _colours(twin)
		var opened: Array = _every_part()
		var opened_tables: String = _tables()
		var top: BrickWorld.Brick = _part_in(edited, "3005")
		if not _check("%s's 3005 found" % edited, top != null):
			continue
		_select([top.id])
		var moved: int = _builder.move_selection(Vector3i(10, 0, 0))
		await _edited()
		_check("%s's 3005 moved (%d): %s's colours as they were (was %s; now %s)" % [edited,
			moved, twin, ", ".join(was), ", ".join(_colours(twin))], _colours(twin) == was)
		await _undo_redo("the move", opened, opened_tables, _every_part(), _tables())
		await _saved_reopened("the move")


## A wing placed mirrored in red and as it is in blue: one part of either
## moved, the other keeps its colours.
func _c_mirror() -> void:
	var text: String = _fixture("cfc_mirror.mpd")
	for edited: String in ["Wing#1", "Wing#2"]:
		await _open(text)
		var twin: String = "Wing#2" if edited == "Wing#1" else "Wing#1"
		var was: Array = _colours(twin)
		var edited_was: Array = _colours(edited)
		var opened: Array = _every_part()
		var opened_tables: String = _tables()
		var small: BrickWorld.Brick = _part_in(edited, "3024")
		if not _check("%s's 3024 found" % edited, small != null):
			continue
		_select([small.id])
		var moved: int = _builder.move_selection(Vector3i(0, 0, 10))
		await _edited()
		_check("%s's 3024 moved (%d): %s's colours as they were (was %s; now %s)" % [edited,
			moved, twin, ", ".join(was), ", ".join(_colours(twin))], _colours(twin) == was)
		_check("...%s's own as they were (now %s)" % [edited, ", ".join(_colours(edited))],
			_colours(edited) == edited_was)
		await _undo_redo("the move", opened, opened_tables, _every_part(), _tables())
		await _saved_reopened("the move")


## Two cars, red and blue, each with two wheels of a black part and one in
## the car's colour: a wheel's black part painted green, then a wheel's top
## moved.
func _c_nested() -> void:
	var text: String = _fixture("cfc_nested.mpd")
	await _open(text)
	print("  paths: %s" % str(_paths()))
	var opened: Array = _every_part()
	var opened_tables: String = _tables()
	var hub: BrickWorld.Brick = _part_in("Car#1/Wheel#1", "3062b")
	if not _check("Car#1/Wheel#1's 3062b found", hub != null):
		return
	_select([hub.id])
	_builder.paint_selection(2)
	await _edited()
	var want: Dictionary = {"Car#1/Wheel#1": ["3062b c2", "6141 c4"],
		"Car#1/Wheel#2": ["3062b c2", "6141 c4"], "Car#2/Wheel#3": ["3062b c2", "6141 c1"],
		"Car#2/Wheel#4": ["3062b c2", "6141 c1"], "Car#1": ["3001 c4"], "Car#2": ["3001 c1"]}
	for path: String in want:
		var got: Array = _colours(path).map(func(s: String) -> String: return s.get_slice(" y", 0))
		_check("painted: %s is %s (%s)" % [path, str(want[path]), str(got)], got == want[path])
	print("  paths after the paint: %s" % str(_paths()))
	var painted_parts: int = _every_part().size()
	_shell.run("undo")
	await _frames(6)
	print("  undone: %d parts (opened %d, painted %d); Car#2/Wheel#3 holds %s" % [
		_every_part().size(), opened.size(), painted_parts, ", ".join(_colours("Car#2/Wheel#3"))])
	_shell.run("redo")
	await _frames(6)
	await _open(text)
	_select([_part_in("Car#1/Wheel#1", "3062b").id])
	_builder.paint_selection(2)
	await _edited()
	await _undo_redo("the paint", opened, opened_tables, _every_part(), _tables())
	await _saved_reopened("the paint")
	await _open(text)
	opened = _every_part()
	opened_tables = _tables()
	var top: BrickWorld.Brick = _part_in("Car#2/Wheel#4", "6141")
	_select([top.id])
	var moved: int = _builder.move_selection(Vector3i(0, 0, 10))
	await _edited()
	for path: String in _paths():
		print("  after the move: %s holds %s" % [path, ", ".join(_colours(path))])
	for path: String in want:
		var got: Array = _colours(path).map(func(s: String) -> String: return s.get_slice(" y", 0))
		var expect: Array = (want[path] as Array).map(func(s: String) -> String:
			return s.replace("3062b c2", "3062b c0"))
		_check("moved (%d): %s is %s (%s)" % [moved, path, str(expect), str(got)], got == expect)
	await _undo_redo("the move", opened, opened_tables, _every_part(), _tables())
	await _saved_reopened("the move")


## The blue tower's own parts painted: the 3003 green, then the yellow 4073
## blue. The 3003 is in the tower's placing colour (16 in tower.ldr), so the
## red tower's stays red; the 4073 is yellow of its own, so the red tower's
## goes blue (copyfaults2: the lead's rule, a paint paints the twin's part
## only where the part had a colour of its own).
func _c_twinpaint() -> void:
	var text: String = _fixture("copyfaults_nest.mpd")
	await _open(text)
	var opened: Array = _every_part()
	var opened_tables: String = _tables()
	var low: BrickWorld.Brick = _part_in("Tower#2", "3003")
	_select([low.id])
	_builder.paint_selection(2)
	await _edited()
	print("  Tower#1 after Tower#2's 3003 painted green: %s" % ", ".join(_colours("Tower#1")))
	print("  Tower#2: %s" % ", ".join(_colours("Tower#2")))
	var t1: Array = _colours("Tower#1").map(func(s: String) -> String: return s.get_slice(" y", 0))
	_check("Tower#1 keeps its 3003 red, the placing colour's: %s" % str(t1),
		t1 == ["3003 c4", "3062b c4", "6141 c14"])
	await _undo_redo("the paint", opened, opened_tables, _every_part(), _tables())
	await _saved_reopened("the paint")
	await _open(text)
	var cap: BrickWorld.Brick = _part_in("Tower#2", "6141")
	_select([cap.id])
	_builder.paint_selection(1)
	await _edited()
	var t1b: Array = _colours("Tower#1").map(func(s: String) -> String: return s.get_slice(" y", 0))
	_check("Tower#1 after Tower#2's 6141 painted blue: %s (a part painted goes in its new colour)"
		% str(t1b), t1b == ["3003 c4", "3062b c4", "6141 c1"])


## Every part of one copy of a two-part post replaced at once (Replace with
## both selected), and one part of it alone: the other copy follows.
func _c_replaceall() -> void:
	var text: String = _fixture("cfc_posts.mpd")
	for how: String in ["one", "all"]:
		await _open(text)
		var opened: Array = _every_part()
		var opened_tables: String = _tables()
		var ids: Array = []
		for brick: BrickWorld.Brick in _world.bricks():
			if Assemblies.path_of(brick) == "Post#1":
				ids.append(brick.id)
		ids.sort()
		if how == "one":
			ids = [_part_in("Post#1", "3005", 1).id]
		_select(ids)
		var done: Vector2i = _builder.replace_selection("3062b", true)
		await _edited()
		print("  replaced %s of Post#1 (%s): Post#1 %s; Post#2 %s" % [how, str(done),
			", ".join(_colours("Post#1")), ", ".join(_colours("Post#2"))])
		var p1: Array = _colours("Post#1").map(func(s: String) -> String: return s.get_slice(" y", 0))
		var p2: Array = _colours("Post#2").map(func(s: String) -> String: return s.get_slice(" y", 0))
		_check("Post#2 follows, blue: %s against Post#1's %s" % [str(p2), str(p1)],
			p2 == p1.map(func(s: String) -> String: return s.replace(" c4", " c1")))
		await _undo_redo("the replace", opened, opened_tables, _every_part(), _tables())
		await _saved_reopened("the replace", false)


## Over MCP, both parts of the red post taken off and a 3005 and a 3062b
## put where they stood, in one edit_model: the blue post follows, a 3005
## and a 3062b, blue.
func _c_relay() -> void:
	await _open(_fixture("cfc_posts.mpd"))
	var low: BrickWorld.Brick = _part_in("Post#1", "3005", 0)
	var high: BrickWorld.Brick = _part_in("Post#1", "3005", 1)
	var at_low: Dictionary = _placement_of(low.id)
	var at_high: Dictionary = _placement_of(high.id)
	var add: Array = []
	for pair: Array in [[at_low, "3005"], [at_high, "3062b"]]:
		var one: Dictionary = {"part": pair[1], "color": 4}
		for key: String in ["x", "y", "z", "face", "rot"]:
			if (pair[0] as Dictionary).has(key):
				one[key] = pair[0][key]
		add.append(one)
	var said: String = await _say("edit_model", {"remove": [low.id, high.id], "add": add,
		"picture": false})
	print("  edit_model: %s" % said.get_slice("\n", 0).left(200))
	print("  Post#1 %s; Post#2 %s; at the top %s" % [", ".join(_colours("Post#1")),
		", ".join(_colours("Post#2")), ", ".join(_colours(""))])
	var p2: Array = _colours("Post#2").map(func(c: String) -> String: return c.get_slice(" y", 0))
	_check("Post#2 follows: a 3005 and a 3062b, blue (%s)" % str(p2), p2 == ["3005 c1", "3062b c1"])


## A sub-model of a black 2x2 and a round brick in the placing colour,
## placed red and blue: the red copy's round brick moved a stud. The blue
## copy's round brick stays blue.
func _c_cap() -> void:
	await _open(_fixture("cfc_cap.mpd"))
	print("  paths: %s" % str(_paths()))
	var round: BrickWorld.Brick = _part_in("Cap#1", "3062b")
	if not _check("Cap#1's 3062b found", round != null):
		return
	var was: Array = _colours("Cap#2")
	_select([round.id])
	var moved: int = _builder.move_selection(Vector3i(10, 0, 0))
	await _edited()
	_check("Cap#1's 3062b moved (%d): Cap#2's colours as they were (was %s; now %s)" % [moved,
		", ".join(was), ", ".join(_colours("Cap#2"))], _colours("Cap#2") == was)


## The wing file: one copy's second step deleted (its parts go to the step
## before), then its first step named, over MCP: both copies built the same
## way, the name every copy's; undo, redo, save, reopen.
func _c_stepdelname() -> void:
	for fixture: String in ["copyfaults_wing.ldr", "cfc_wing2.ldr"]:
		await _open(_fixture(fixture))
		var opened: String = _steps_said()
		var said: String = await _say("edit_steps", {"op": "delete", "step": 3})
		print("  %s: delete step 3: %s" % [fixture, said.get_slice("\n", 0).left(120)])
		var shown: String = _steps_said()
		print("  then: %s" % shown)
		var bare: String = shown.replace("/4", "").replace("/1", "")
		var n: int = bare.count(" | ") + 1
		print("  %d steps" % n)
		said = await _say("edit_steps", {"op": "name", "step": 2, "name": "Wing first"})
		print("  name step 2: %s" % said.get_slice("\n", 0).left(120))
		var listed: String = await _say("edit_steps", {"op": "list"})
		print("  list: %s" % listed.replace("\n", " / ").left(500))
		print("  looks: %s" % JSON.stringify(_world.step_looks))
		var looks_after: String = JSON.stringify(_world.step_looks)
		var steps_after: String = _steps_said()
		await _say("undo", {})
		await _say("undo", {})
		_check("...both undone: as opened (%s)" % _steps_said(), _steps_said() == opened)
		await _say("undo", {"redo": true})
		await _say("undo", {"redo": true})
		_check("...both redone: steps and names as after", _steps_said() == steps_after
			and JSON.stringify(_world.step_looks) == looks_after)
		var saved: String = _save()
		await _open(saved)
		_check("...opened again: the steps as shown (%s)" % _steps_said(), _steps_said() == steps_after)
		_check("...and the names (%s)" % JSON.stringify(_world.step_looks),
			JSON.stringify(_world.step_looks) == looks_after)


## The first and the second save of the moved own-colour posts, as text.
func _c_savedump() -> void:
	await _open(_fixture("cfc_owncolour.mpd"))
	var top: BrickWorld.Brick = _part_in("Post#2", "3005")
	_select([top.id])
	_builder.move_selection(Vector3i(10, 0, 0))
	await _edited()
	var saved: String = _save()
	print("  first save:\n%s" % saved.left(900))
	await _open(saved)
	print("  title %s; second save:\n%s" % [_store.title, _save().left(900)])


## A step edit on the red post's 3005 (cfc_owncolour.mpd), over MCP: the
## blue post keeps its colours.
func _c_ownstep() -> void:
	await _open(_fixture("cfc_owncolour.mpd"))
	var was: Array = _colours("Post#2")
	var ids_was: Array = _ids_of(_copy_said("Post#2"))
	var top: BrickWorld.Brick = _part_in("Post#1", "3005")
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [top.id]})
	print("  edit_steps next: %s" % said.get_slice("\n", 0).left(120))
	_check("...Post#2's colours as they were (was %s; now %s)" % [", ".join(was),
		", ".join(_colours("Post#2"))], _colours("Post#2") == was)
	print("  Post#2's numbers: %s" % ("the same" if ids_was == _ids_of(_copy_said("Post#2"))
		else "new: %s, were %s" % [str(_ids_of(_copy_said("Post#2"))), str(ids_was)]))


# -- 5: steps follow ---------------------------------------------------------------------


## A step edit on the red tower's 3003, over MCP: the blue tower is the same
## bricks, byte for byte but for its 3003's step, which is the red one's (the
## tower is built in its own steps, which every copy shares: copyfaults'
## step_copy), and the save changes only that step.
func _c_stepcolour() -> void:
	var text: String = _fixture("copyfaults_nest.mpd")
	await _open(text)
	var twin: Array = _copy_said("Tower#2")
	var first: String = _save()
	var low: BrickWorld.Brick = _part_in("Tower#1", "3003")
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [low.id]})
	print("  edit_steps next on Tower#1's 3003: %s" % said.get_slice("\n", 0).left(160))
	var unstepped := func(said: Array) -> Array:
		return said.map(func(line: String) -> String:
			return line.get_slice(" s", 0) + " o" + line.get_slice(" o", 1))
	_check("...Tower#2 the same bricks, byte for byte but for the steps%s"
		% _unlike(twin, _copy_said("Tower#2")),
		unstepped.call(twin) == unstepped.call(_copy_said("Tower#2")))
	_check("...its 3003 in Tower#1's 3003's step (%d, %d)" % [_part_in("Tower#2", "3003").step,
		low.step], _part_in("Tower#2", "3003").step == low.step)
	var saved: String = _save()
	print("  saved: %s" % _diff(first, saved))
	await _saved_reopened("the step edit")


## The wing file with its copies placed red and blue (its parts in 16): a
## step edit on one copy, as copyfaults' step_copy, then undo, redo, save,
## reopen.
func _c_wing2steps() -> void:
	var text: String = _fixture("cfc_wing2.ldr")
	for copy: int in [3, 5]:
		await _open(text)
		var opened: String = _steps_said()
		var colours_was: Dictionary = {"wing#1": _colours("wing#1"), "wing#2": _colours("wing#2")}
		var brick: int = -1
		for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
			if step.number == copy:
				for id: int in step.brick_ids:
					if _world.get_brick(id).part_id == "3003":
						brick = id
						break
		if not _check("a 3003 of step %d found" % copy, brick > 0):
			continue
		var twin: String = "wing#2" if Assemblies.path_of(_world.get_brick(brick)) == "wing#1" \
			else "wing#1"
		var twin_ids: Array = _copy_said(twin)
		var said: String = await _say("edit_steps", {"op": "prev", "bricks": [brick]})
		print("  step %d's 3003 to the step before: %s" % [copy, said.get_slice("\n", 0).left(100)])
		var shown: String = _steps_said()
		print("  then: %s" % shown)
		_check("...both copies' colours as they were (%s; %s)" % [", ".join(_colours("wing#1")),
			", ".join(_colours("wing#2"))], _colours("wing#1") == colours_was["wing#1"]
			and _colours("wing#2") == colours_was["wing#2"] and not colours_was["wing#1"].is_empty())
		var now_ids: Array = _copy_said(twin)
		print("  %s's bricks: %s" % [twin, "the same numbers" if _ids_of(twin_ids) == _ids_of(now_ids)
			else "built again: " + _unlike(twin_ids, now_ids)])
		var bare: String = shown.replace("/4", "").replace("/1", "")
		var parts_of := func(n: int) -> String: return bare.get_slice(" | ", n).get_slice("[", 1)
		_check("...both wings built the same way: %s" % bare,
			parts_of.call(1) == parts_of.call(3) and parts_of.call(2) == parts_of.call(4))
		await _say("undo", {})
		_check("...undone: as opened (%s)" % _steps_said(), _steps_said() == opened)
		await _say("undo", {"redo": true})
		_check("...redone: as the edit left them", _steps_said() == shown)
		var saved: String = _save()
		await _open(saved)
		_check("...opened again as the timeline showed it (%s)" % _steps_said(),
			_steps_said() == shown)


# -- 2: extend_last's other callers -----------------------------------------------------


## The wing file's first wing (steps of its own, named) taken apart, or
## made a sub-model of its own: undo and redo give back every part and
## every table, the step names among them.
func _c_regroups(how: String) -> void:
	await _open(_fixture("copyfaults_wing.ldr"))
	var opened: Array = _every_part()
	var opened_tables: String = _tables()
	var depth: int = _builder.history_depth()
	if how == "ungroup":
		print("  ungrouped: %d" % _shell.assemblies.ungroup("wing#1"))
	else:
		print("  made its own: %s" % _shell.assemblies.make_unique("wing#1"))
	await _edited()
	print("  history steps: %d; the last %s" % [_builder.history_depth() - depth,
		_kinds(_builder.last_step())])
	print("  tables now: %s" % _tables().left(400))
	await _undo_redo(how, opened, opened_tables, _every_part(), _tables())
	await _saved_reopened(how)


## The main model's last step, one part with a name, emptied by a hand
## Delete: undo puts the part and its step's name back; redo takes both.
func _c_emptystep() -> void:
	await _open(_fixture("copyfaults_wing.ldr"))
	var opened: Array = _every_part()
	var opened_tables: String = _tables()
	var top: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001" and Assemblies.path_of(brick).is_empty():
			top = brick
	if not _check("the main's 3001 found", top != null):
		return
	_select([top.id])
	print("  removed: %d" % _builder.remove_selection())
	await _edited()
	print("  the step: %s" % _kinds(_builder.last_step()))
	await _undo_redo("the delete", opened, opened_tables, _every_part(), _tables())


# -- 4: clear_model's undo -------------------------------------------------------------


## The wing file cleared over MCP, a part put down on the bare baseplate,
## both undone, both redone: every part under its own number each time, the
## new part never one of the model's numbers.
func _c_clearids() -> void:
	await _open(_fixture("copyfaults_wing.ldr"))
	var opened: Array = _every_part()
	var opened_ids: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		opened_ids[brick.id] = true
	var tables: String = _tables()
	var title: String = _store.title
	var first: String = _save()
	print("  clear: %s" % (await _say("clear_model", {})).left(80))
	var plate: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		plate[brick.id] = brick.part_id
	print("  after the clear: scenery %s; title %s" % [str(plate), _store.title])
	var added: String = await _say("edit_model", {"add": [{"part": "3001", "color": 2,
		"x": 0, "y": 0, "z": 0}], "picture": false})
	print("  edit_model add: %s" % added.get_slice("\n", 0).left(160))
	var fresh: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001" and brick.color_code == 2:
			fresh = brick
	if not _check("a part put down on the bare baseplate", fresh != null):
		return
	var fresh_id: int = fresh.id
	_check("...its number %d none of the model's (%s)" % [fresh_id, str(opened_ids.keys())],
		not opened_ids.has(fresh_id))
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
	await _frames(4)
	_check("both undone: every part as opened%s" % _unlike(opened, _every_part()),
		opened == _every_part())
	_check("...the tables as opened", _tables() == tables)
	_check("...its name %s (was %s)" % [_store.title, title], _store.title == title)
	_check("...saved as before the clear (%s)" % _diff(first, _save()), _save() == first)
	print("  redo: %s" % (await _say("undo", {"redo": true})).get_slice("\n", 0).left(100))
	print("  redo: %s" % (await _say("undo", {"redo": true})).get_slice("\n", 0).left(100))
	await _frames(4)
	var back: BrickWorld.Brick = _world.get_brick(fresh_id)
	_check("both redone: the new part back under %d, and only it (%d parts)" % [fresh_id,
		_every_part().size()], back != null and back.part_id == "3001" and back.color_code == 2
		and _every_part().size() == 1)
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
	await _frames(4)
	_check("undone again: every part as opened%s" % _unlike(opened, _every_part()),
		opened == _every_part())
	# A part put down after the undo: a number of its own.
	var again: String = await _say("edit_model", {"add": [{"part": "3001", "color": 2,
		"x": 20, "y": 0, "z": 20}], "picture": false})
	print("  edit_model add after the undo: %s" % again.get_slice("\n", 0).left(120))
	var newest: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001" and brick.color_code == 2:
			newest = brick.id
	_check("...a part put down after it: number %d, none of the model's" % newest,
		newest > 0 and not opened_ids.has(newest))
	await _say("undo", {})
	_check("...undone: every part as opened%s" % _unlike(opened, _every_part()),
		opened == _every_part())
	await _say("undo", {"redo": true})
	_check("...redone: under %d again" % newest, _world.get_brick(newest) != null)


## A model holding a part the catalogue has not got, the app's own file and
## someone else's: cleared over MCP and undone, the save keeps that part.
func _c_clearabsent() -> void:
	for name: String in ["cfc_absent.ldr", "cfc_nest_absent.mpd"]:
		var text: String = _fixture(name)
		await _open(text)
		var first: String = _save()
		_check("%s opened and saved: the zz9999 line kept" % name, first.contains("zz9999.dat"))
		await _say("clear_model", {})
		print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
		await _frames(4)
		var undone: String = _save()
		_check("...cleared and undone, saved: the zz9999 line kept (%s)" % _diff(first, undone),
			undone.contains("zz9999.dat"))
		_check("...and the save as before the clear", undone == first)


## The wing file cleared over MCP and undone, then autosaved, the baseplate
## cleared as New does and the autosave restored: the model as it was.
func _c_clearautosave() -> void:
	await _open(_fixture("copyfaults_wing.ldr"))
	var control_title: String = _store.title
	_store.call("_write", ModelStore.autosave(), _store.title)
	_main.call("clear_model")
	await _frames(4)
	_store.restore()
	await _frames(10)
	var control_restored: String = _store.title
	print("  control, no clear: autosaved as %s, restored as %s" % [control_title, _store.title])
	await _open(_fixture("copyfaults_wing.ldr"))
	var shown: Array = _looks()
	var title: String = _store.title
	await _say("clear_model", {})
	await _say("undo", {})
	await _frames(4)
	_store.call("_write", ModelStore.autosave(), _store.title)
	var kept: String = FileAccess.get_file_as_string(ModelStore.autosave())
	print("  autosaved: %d bytes, %d part lines" % [kept.length(), kept.count("\n1 ")])
	_main.call("clear_model")
	await _frames(4)
	var back: int = _store.restore()
	await _frames(10)
	_check("restored (%d): every part, colour, place and step as before the clear%s" % [back,
		_unlike(shown, _looks())], shown == _looks())
	_check("...its name %s, as a restore with no clear names it (%s; was %s)" % [_store.title,
		control_restored, title], _store.title == control_restored)


# -- 6: into_main --------------------------------------------------------------------------


## Files with no FILE line, a main with no header, a BOM and CRLF, a title
## with brackets, and the nest: each given a view, a cut, a set, a share,
## the bins' sets and a new name with brackets, saved, opened again, saved
## again.
func _c_metas2() -> void:
	for name: String in ["cfc_plain.ldr", "cfc_noheader.mpd", "cfc_bom.mpd", "cfc_brackets.mpd",
			"copyfaults_nest.mpd"]:
		var text: String = _fixture(name)
		await _open(text)
		var shown: Array = _looks()
		_world.saved_views = [{"name": "front", "yaw": 0.5, "pitch": 0.3, "distance": 400.0,
			"focus": [0.0, 0.0, 0.0], "square": false}]
		_world.cut_kept = {"shape": "plane", "axis": "x", "at": 11.0, "away": 1, "ghosts": false}
		_store.from_set = "6780-1"
		_store.share_id = "abc123share"
		_store.bin_sets = PackedStringArray(["10497-1"])
		var renamed: String = "Renamed [x] (y)"
		var path: String = "user://cfc_metas_%s" % name.get_file()
		var wrote: bool = _store.call("_write", path, renamed, true)
		var saved: String = FileAccess.get_file_as_string(path)
		if name == "cfc_bom.mpd":
			text = "\ufeff" + text
			await _open(text)
			_world.saved_views = [{"name": "front", "yaw": 0.5, "pitch": 0.3, "distance": 400.0,
				"focus": [0.0, 0.0, 0.0], "square": false}]
			_world.cut_kept = {"shape": "plane", "axis": "x", "at": 11.0, "away": 1, "ghosts": false}
			_store.from_set = "6780-1"
			_store.share_id = "abc123share"
			_store.bin_sets = PackedStringArray(["10497-1"])
			_store.call("_write", path, renamed, true)
			saved = FileAccess.get_file_as_string(path)
			var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
			print("  bom fixture: written %d bytes, starts %s" % [raw.size(), str(raw.slice(0, 4))])
		print("  wrote %s: %s" % [path, str(wrote)])
		var span: Vector2i = LdrModel.main_span(saved)
		var where: String = _app_lines_where(saved)
		print("  %s saved, its first lines: %s" % [name, saved.left(260).c_escape()])
		_check("%s: every app line in the model's own section, after its first line%s" % [name,
			where], where.is_empty())
		var crlf: bool = text.contains("\r\n")
		_check("...line ends as the file's (%s)" % ("CRLF" if crlf else "LF"),
			saved.contains("\r\n") == crlf and (not crlf or saved.replace("\r\n", "").find("\n") < 0))
		_check("...a BOM as the file had", saved.begins_with("﻿") == text.begins_with("﻿")
			or not text.begins_with("﻿"))
		print("  (bom in: %s, out: %s; span %s)" % [str(text.begins_with("﻿")),
			str(saved.begins_with("﻿")), str(span)])
		await _open(saved)
		_check("...opened again: its name read %s" % ModelStore.title_in(saved, ""),
			ModelStore.title_in(saved, "") == renamed)
		_check("...set %s, share %s, bins %s, views %d, cut %s" % [_store.from_set,
			_store.share_id, str(_store.bin_sets), _world.saved_views.size(),
			str(not _world.cut_kept.is_empty())], _store.from_set == "6780-1"
			and saved.contains(ModelStore.SHARE_META + "abc123share")
			and saved.contains("10497-1") and _world.saved_views.size() == 1
			and not _world.cut_kept.is_empty())
		_check("...every part, colour, place and step as opened%s" % _unlike(shown, _looks()),
			shown == _looks())
		_store.call("_write", path, renamed, true)
		var again: String = FileAccess.get_file_as_string(path)
		_check("...saved again byte for byte%s" % _first_unlike(saved, again), again == saved)


## Where an app line (0 !BRICKWORKS) of [param text] is not in its model's
## own section after the section's first line: "" when all are.
static func _app_lines_where(text: String) -> String:
	var span: Vector2i = LdrModel.main_span(text)
	var first_end: int = text.find("\n", span.x)
	var at: int = 0
	var n: int = 0
	for line: String in text.split("\n"):
		n += 1
		if line.begins_with("0 !BRICKWORKS") and not line.begins_with("0 !BRICKWORKS COPY") \
				and not line.begins_with("0 !BRICKWORKS STEP_NAME"):
			if at <= first_end or at >= span.y:
				return " (line %d, %s, at %d; the section %s)" % [n, line.left(50), at, str(span)]
		at += line.length() + 1
	return ""
