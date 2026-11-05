## The steps a person saw are the steps that are kept (stepsnum).
##
##   godot --headless --path . --script src/dev/steps_kept_probe.gd
##
## A model nobody gave steps is shown the steps Brickworks works out, and
## its first step edit makes them the model's own (AuthorSteps.ensure). The
## lighthouse a session made over the connector (claudedir, 2026-11-03) was
## listed with its island in steps 5 to 44 and 46 and the keeper put on in
## 45; one edit later the keeper was step 5 and the island 6 to 46. A person
## who read step 5, changed it, and found their parts in step 6 can't trust
## the numbers, and a session naming steps by number gets the wrong ones.
##
## Here the lighthouse (tests/fixtures/steps/lighthouse.ldr, as the session
## had it) and a real set from the library with its steps taken out
## (7140-1), each listed over MCP, then one edit at a time, each undone:
## - a step's look set, over MCP (edit_booklet) and by the Booklet row
##   (Shell.change_look): no part in another step;
## - one part to the next step, over MCP (edit_steps next) and by the
##   timeline's Shift-] (Shell.change_steps), and one to another step of
##   its sub-model (edit_steps to): only that part in another step;
## - a part recoloured (edit_model): no part in another step;
## every other part in the step it was listed in, by the plan and by the
## list, and the undo gives the worked-out steps back. Then the steps made
## the model's own are saved and opened again: every part where it was.
##
## And the booklet's section marks, its chapters (sectionmarks): the step
## each sub-model's or stage's banner starts on, and its name, the same
## through every edit, every undo, and the save opened again, and the saved
## file saying them. They were the worked-out plan's alone, and the first
## edit lost every one. A model with steps of its own (7140-1 as its author
## stepped it) and one of no sub-models are given none: no mark, and no
## line in the file, after an edit. And the castle (models/castle.ldr),
## whose sub-models built whole put 31 parts in the air (suitesteps): its
## towers and walls go up a course of each in turn, so each is kept built
## in the steps of the model that places it (AuthorSteps.IN_PARENT,
## stepskeep). The first edit gave it the steps of sub-models built whole,
## every step from 45 numbered anew, the booklet asking for bricks in the
## air. Now one part moved on over MCP and by Shift-], each undone: every
## other part in the step it was listed in, the steps test passing the
## model's own steps after it, and the save opened again with every part in
## its step, here and as another LDraw reader builds the file.
extends SceneTree

const MODELS: Array = [
	["the lighthouse", "res://tests/fixtures/steps/lighthouse.ldr"],
	["7140-1, its steps taken out", "res://vendor/omr/files/7140-1.mpd"],
]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0

## Every part's step as the model was listed, by id: "12", or "12.3" for
## the third step of the callout step 12 puts on.
var _listed: Dictionary = {}
## The same off edit_steps's list.
var _said: Dictionary = {}
## The section marks as the model was listed ([method _marks]).
var _marked: Array = []


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
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
	var only: String = OS.get_environment("STEPS_KEPT_ONLY")
	for model: Array in MODELS:
		if only.is_empty() or str(model[1]).contains(only):
			await _model(str(model[0]), str(model[1]))
	if only.is_empty():
		await _unmarked("7140-1 as its author stepped it",
			FileAccess.get_file_as_string("res://vendor/omr/files/7140-1.mpd"))
		await _unmarked("a wall of no sub-models", _wall())
	if only.is_empty() or "castle".contains(only):
		await _turned_down("the castle, its kept steps turned down", "res://models/castle.ldr")
	if _failures == 0:
		print("steps_kept probe: all checks passed")
	else:
		print("steps_kept probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _model(name: String, path: String) -> void:
	print("\n%s" % name)
	var text: String = FileAccess.get_file_as_string(path)
	if not _check("%s read (%d bytes)" % [path, text.length()], not text.is_empty()):
		return
	await _open(_without_steps(text), name)
	if not _check("opened with no steps of its own, %d parts" % _listed.size(),
			not AuthorSteps.any(_world, _store.scenery) and _listed.size() > 100):
		return
	_check("...its booklet in %d sections: %s" % [_marked.size(), ", ".join(_marked)],
		_marked.size() >= 2)
	var listed: String = await _say("edit_steps", {})
	var unlike: Array = _said.keys().filter(func(id: int) -> bool:
		return str(_said[id]) != str(_listed.get(id, "")).get_slice(".", 0))
	_check("...listed as worked out (\"%s\", %s), %d parts, %d not where the plan has them" % [
		listed.get_slice("\n", 0), "the steps it can keep" if _kept_shown()
			else "the order worked out", _said.size(), unlike.size()],
		listed.get_slice("\n", 0).contains("worked out by the app") and _said.size() > 50
		and unlike.is_empty())
	var at: Array = _chosen()
	if not _check("a middle step of a sub-model's, with parts of its own after it: step %s, #%s"
			% [str(at[0]), str(at[1])], int(at[0]) > 0):
		return
	var number: int = int(at[0])
	var part: int = int(at[1])
	var later: int = int(at[2])

	print("  a step's look, set")
	await _kept("edit_booklet turn= on step %d" % number, [], func() -> String:
		return await _say("edit_booklet", {"step": number, "turn": 30}))
	await _kept("the Booklet row's Zoom in on step %d" % number, [], func() -> String:
		return _shell.change_look("set", _step_numbered(number), {"zoom": 1.5}))
	print("  one part to another step")
	await _kept("edit_steps next on #%d" % part, [part], func() -> String:
		return await _say("edit_steps", {"op": "next", "bricks": [part]}))
	await _kept("Shift-] on #%d" % part, [part], func() -> String:
		return _shell.change_steps("next", [part], _step_numbered(number)))
	await _kept("edit_steps to step %d with #%d" % [later, part], [part], func() -> String:
		return await _say("edit_steps", {"op": "to", "step": later, "bricks": [part]}))
	print("  a part recoloured")
	var colour: int = 14 if _world.get_brick(part).color_code == 4 else 4
	await _kept("edit_model recolor on #%d" % part, [], func() -> String:
		return await _say("edit_model", {"recolor": [{"bricks": [part], "color": colour}]}))

	print("  saved and opened again")
	var depth: int = _builder.history_depth()
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [part]})
	var edited: Array = _placed(_numbers())
	var listed_marks: Array = _marked
	var kept: int = 0
	for marks: Dictionary in BookletLooks.marks_of(_world).values():
		kept += marks.size()
	var saved: String = _store.to_text(name, true)
	await _open(saved, name)
	var reopened: Array = _placed(_numbers())
	var moved: Array = _unmatched(edited, reopened)
	_check("after %s, saved and opened again: %d of %d parts in another step%s" % [said,
		moved.size(), edited.size(), (": " + ", ".join(moved.slice(0, 3).map(
			func(one: Array) -> String: return "%s at %s in %s" % [one[0], str(one[1]), one[2]])))
			if not moved.is_empty() else ""],
		AuthorSteps.any(_world, _store.scenery) and moved.is_empty()
		and reopened.size() == edited.size())
	_marks_kept("...its sections", listed_marks)
	var lines: PackedStringArray = _section_lines(saved)
	_check("...the file has a line for each of the %d marks on its steps: %s" % [kept,
		" | ".join(lines)], kept > 0 and lines.size() == kept)
	await _back_to(depth)


## The steps as listed, after [param edit] and after it is undone: no part
## but [param moves] in another step, by the plan and by edit_steps's list,
## and the worked-out steps back after the undo.
func _kept(what: String, moves: Array, edit: Callable) -> void:
	var depth: int = _builder.history_depth()
	var said: String = str(await edit.call())
	await _frames(2)
	var now: Dictionary = _numbers()
	var said_now: Dictionary = await _said_now()
	var others: Array = _moved(_listed, now).filter(func(id: int) -> bool:
		return not moves.has(id))
	_check("%s (\"%s\"): %d other parts in another step%s" % [what, said.get_slice("\n", 0),
		others.size(), _first(others, now)], others.is_empty())
	var listed_others: Array = _moved(_said, said_now, true).filter(func(id: int) -> bool:
		return not moves.has(id))
	_check("...and in the list, %d%s" % [listed_others.size(), _first(listed_others, said_now)],
		listed_others.is_empty())
	if not moves.is_empty():
		_check("...#%d moved, %s to %s" % [int(moves[0]), _listed.get(moves[0], "?"),
			now.get(moves[0], "?")], now.get(moves[0]) != _listed.get(moves[0]))
	_marks_kept("...its sections", _marked)
	await _back_to(depth)
	var back: Array = _moved(_listed, _numbers())
	_check("...undone: the worked-out steps again, %d parts in another step" % back.size(),
		back.is_empty() and not AuthorSteps.any(_world, _store.scenery))
	_marks_kept("...undone, its sections", _marked)
	_check("...and no mark kept on its steps", BookletLooks.marks_of(_world).is_empty())


## Whether the plan shows the steps the model can keep (stepsnum), not the
## order worked out: kept steps are named among the model's.
func _kept_shown() -> bool:
	return _plan().any(func(step: Instructions.Step) -> bool: return step.authored_step >= 0)


## A model shown the order worked out, its kept steps turned down
## (suitesteps): [param path], opened, a part of a middle step moved on.
## Every other part in the section it was in, and in the file, and the undo
## gives back the worked-out sections.
func _turned_down(name: String, path: String) -> void:
	print("\n%s" % name)
	await _open(FileAccess.get_file_as_string(path), name)
	var held_in: Dictionary = _by_path()
	var steps: Array[Instructions.Step] = _plan()
	var opened: Dictionary = await _tested(_store.to_text(name, true))
	if not _check("opened with no steps of its own, %d parts, shown %s, in %d sections: %s; the steps test: %s" % [
			_listed.size(), "the steps it can keep, built in their parents' steps"
				if AuthorSteps.in_place_plan(_world, steps) else ("the steps it can keep"
				if _kept_shown() else "the order worked out"), _marked.size(),
			", ".join(_marked.slice(0, 6)), _verdict(opened)],
			not AuthorSteps.any(_world, _store.scenery) and _marked.size() >= 2
			and _passes(opened)):
		return
	var part: int = 0
	var number: int = 0
	for step: Instructions.Step in steps.slice(steps.size() / 2):
		if not step.in_callout() and step.brick_ids.size() >= 2:
			part = step.brick_ids[0]
			number = step.number
			break
	print("  one part moved on, #%d of step %d (%s)" % [part, number,
		Assemblies.path_of(_world.get_brick(part))])
	await _kept("edit_steps next on #%d" % part, [part], func() -> String:
		return await _say("edit_steps", {"op": "next", "bricks": [part]}))
	await _kept("Shift-] on #%d" % part, [part], func() -> String:
		return _shell.change_steps("next", [part], _step_numbered(number)))

	print("  the model's own steps, tested, saved and opened again")
	var depth: int = _builder.history_depth()
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [part]})
	await _frames(2)
	var edited: Array = _placed(_numbers())
	var saved: String = _store.to_text(name, true)
	var tested: Dictionary = await _tested(saved)
	_check("after %s, the steps test of its own steps: %s" % [said.get_slice("\n", 0),
		_verdict(tested)], _passes(tested))
	var read: Array = _as_others_read(saved, edited)
	_check("...another LDraw reader builds the file in the same steps: %d of %d parts in another%s"
		% [read.size(), edited.size(), (": " + ", ".join(read.slice(0, 3).map(
			func(one: Array) -> String: return "%s in %s" % [one[0], one[2]])))
			if not read.is_empty() else ""], read.is_empty())
	await _back_to(depth)
	_marks_kept("...undone, its sections", _marked)
	_check("...and no mark kept on its steps", BookletLooks.marks_of(_world).is_empty())
	await _open(saved, name, false)
	var reopened: Array = _placed(_numbers())
	var apart: Array = _unmatched(edited, reopened)
	_check("...saved (%d lines say a sub-model built in the model's steps) and opened again: "
		% _in_lines(saved) + "%d of %d parts in another step%s" % [apart.size(), edited.size(),
		(": " + ", ".join(apart.slice(0, 3).map(func(one: Array) -> String:
			return "%s in %s" % [one[0], one[2]]))) if not apart.is_empty() else ""],
		AuthorSteps.any(_world, _store.scenery) and apart.is_empty()
		and reopened.size() == edited.size())
	var now: Dictionary = _by_path()
	_check("...every sub-model kept, part for part: %d sub-models, %s" % [now.size() - 1,
		", ".join(now.keys().slice(0, 4).map(func(path: String) -> String:
			return "%s %d" % [path if not path.is_empty() else "its own", int(now[path])]))],
		now == held_in and now.size() > 2)


## The Tested mark's tests of the model in [param text], as a shared page
## carries them (SharedPages.attach_tested).
func _tested(text: String) -> Dictionary:
	return (await SharedPages.attach_tested(text, _library, _store))["tested"]


func _passes(tested: Dictionary) -> bool:
	return bool(((tested.get("tests", {}) as Dictionary).get("steps", {}) as Dictionary) \
		.get("ok", false))


func _verdict(tested: Dictionary) -> String:
	var why: String = str(((tested.get("tests", {}) as Dictionary).get("steps", {}) as Dictionary) \
		.get("why", ""))
	return ("passes" if _passes(tested) else "fails") + ("" if why.is_empty() else ", " + why.left(120))


## The lines of [param text] naming a sub-model built in its parent's steps.
static func _in_lines(text: String) -> int:
	var count: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(LdrModel.IN_META):
			count += 1
	return count


## How many parts each sub-model's path holds now, the model's own as "".
func _by_path() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			var path: String = Assemblies.path_of(brick)
			out[path] = int(out.get(path, 0)) + 1
	return out


## The parts of [param placed] ([method _placed], the steps as the app reads
## them) another LDraw reader puts down in another step of the file
## [param text]: one that knows none of the app's own lines and builds each
## sub-model whole in the step that places it. Its steps are matched to the
## app's by the order they come in, the first part of each of its steps
## telling which of the app's that is.
func _as_others_read(text: String, placed: Array) -> Array:
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.strip_edges().begins_with("0 !BRICKWORKS"):
			kept.append(line)
	var model: LdrModel = LdrModel.parse("\n".join(kept), "model")
	var read: Array = []
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		if not _library.parts.has(placement.part_id):
			continue
		var top: String = placement.unit.get_slice("/", 0)
		var at: int = placement.step if top.is_empty() else int(model.unit_steps.get(top, 0))
		read.append(["%s/%d" % [placement.part_id, placement.color_code],
			placement.transform.origin, at])
	# The app stands the model on the ground: the same parts, moved as one.
	var shift := Vector3.ZERO
	if not read.is_empty() and not placed.is_empty():
		var sum_read := Vector3.ZERO
		for one: Array in read:
			sum_read += one[1]
		var sum_ours := Vector3.ZERO
		for one: Array in placed:
			sum_ours += one[1]
		shift = sum_ours / placed.size() - sum_read / read.size()
	# Each of its steps the main step of the app's its parts are in, by order.
	var main: Dictionary = {}       ## its step -> the app's number
	var by_part: Array = []
	for one: Array in read:
		by_part.append([one[0], (one[1] as Vector3) + shift, one[2]])
	var matched: Array = []
	var free: Array = placed.duplicate()
	for one: Array in by_part:
		for index: int in free.size():
			var other: Array = free[index]
			if other[0] == one[0] and (other[1] as Vector3).distance_to(one[1]) < 0.1:
				matched.append([one, str(other[2]).get_slice(".", 0).to_int()])
				free.remove_at(index)
				break
	var out: Array = []
	for pair: Array in matched:
		var theirs: int = int((pair[0] as Array)[2])
		if not main.has(theirs):
			main[theirs] = int(pair[1])
		elif int(main[theirs]) != int(pair[1]):
			out.append([(pair[0] as Array)[0], (pair[0] as Array)[1], "their step %d, our %d"
				% [theirs + 1, int(pair[1])]])
	# The same steps in the same order: theirs one to one with ours.
	var order: Array = main.keys()
	order.sort()
	for index: int in range(1, order.size()):
		if int(main[order[index]]) <= int(main[order[index - 1]]):
			out.append(["step %d" % (int(order[index]) + 1), Vector3.ZERO,
				"ours %d after %d" % [int(main[order[index]]), int(main[order[index - 1]])]])
	for one: Array in free:
		out.append([one[0], one[1], "not read"])
	return out


## Every part's section in the booklet now, by id.
func _sections() -> Dictionary:
	var out: Dictionary = {}
	for step: Instructions.Step in _plan():
		for brick_id: int in step.brick_ids:
			out[brick_id] = step.section
	return out


## A model whose booklet has no sections of the app's: [param text] opened,
## a part of a middle step moved on, and its sections, its marks and its
## file as they were.
func _unmarked(name: String, text: String) -> void:
	print("\n%s" % name)
	await _open(text, name)
	var before: Array = _marks()
	var steps: Array[Instructions.Step] = _plan()
	var part: int = 0
	for step: Instructions.Step in steps.slice(steps.size() / 2):
		if not step.in_callout() and step.brick_ids.size() >= 2:
			part = step.brick_ids[0]
			break
	if not _check("opened, %d steps, sections %s; a part of a middle step: #%d" % [steps.size(),
			str(before), part], part > 0):
		return
	var depth: int = _builder.history_depth()
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [part]})
	await _frames(2)
	var saved: String = _store.to_text(name, true)
	_check("after %s: sections %s, %d marks, %d lines in its file" % [said.get_slice("\n", 0),
		str(_marks()), BookletLooks.marks_of(_world).size(), _section_lines(saved).size()],
		_marks() == before and BookletLooks.marks_of(_world).is_empty()
		and _section_lines(saved).is_empty() and AuthorSteps.any(_world, _store.scenery))
	await _back_to(depth)


## Twenty 2 x 4 bricks, a wall of five courses, in one file of no sub-models.
static func _wall() -> String:
	var lines := PackedStringArray(["0 Wall", "0 Name: wall.ldr", "0 Author: A. Builder"])
	for course: int in 5:
		for at: int in 4:
			lines.append("1 4 %d %d 0 1 0 0 0 1 0 0 0 1 3001.dat" % [at * 80 + (course % 2) * 40,
				-24 * (course + 1)])
	return "\n".join(lines) + "\n"


## The lines of [param text] that mark a section of the booklet.
static func _section_lines(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(BookletLooks.META + "SECTION"):
			out.append(line.strip_edges())
	return out


## The booklet's section marks now the same as [param was] ([method _marks]).
func _marks_kept(what: String, was: Array) -> void:
	var now: Array = _marks()
	var lost: Array = was.filter(func(mark: String) -> bool: return not now.has(mark))
	var gained: Array = now.filter(func(mark: String) -> bool: return not was.has(mark))
	_check("%s: %d of %d marks%s%s" % [what, was.size() - lost.size(), was.size(),
		(", lost " + ", ".join(lost.slice(0, 4))) if not lost.is_empty() else "",
		(", new " + ", ".join(gained.slice(0, 4))) if not gained.is_empty() else ""],
		now == was)


## A step of an in-place sub-model's (the model's own when it has none) in
## the middle of the build, of two parts or more, its section with a step
## after it: [its number, its first part, the number of the next step of
## its section past the one after it], or [0, 0, 0].
func _chosen() -> Array:
	var steps: Array[Instructions.Step] = _plan()
	var section_of: Callable = func(step: Instructions.Step) -> String:
		return Assemblies.path_of(_world.get_brick(step.brick_ids[0]))
	for want_sub: bool in [true, false]:
		for index: int in range(steps.size() / 3, steps.size()):
			var step: Instructions.Step = steps[index]
			if step.in_callout() or step.brick_ids.size() < 2:
				continue
			var section: String = section_of.call(step)
			if want_sub == section.is_empty():
				continue
			if not Array(step.brick_ids).all(func(id: int) -> bool:
					return Assemblies.path_of(_world.get_brick(id)) == section):
				continue
			var after: Array = []
			for other: Instructions.Step in steps.slice(index + 1):
				if not other.in_callout() and not other.brick_ids.is_empty() \
						and section_of.call(other) == section:
					after.append(other.number)
			if after.size() >= 2:
				return [step.number, step.brick_ids[0], after[1]]
	return [0, 0, 0]


func _open(text: String, name: String, listed: bool = true) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, name)
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)
	if listed and not AuthorSteps.any(_world, _store.scenery):
		_listed = _numbers()
		_said = await _said_now()
		_marked = _marks()


## [param text] with no STEP or ROTSTEP lines: a model nobody gave steps.
static func _without_steps(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		var words: String = line.strip_edges().to_upper()
		if words == "0 STEP" or words.begins_with("0 ROTSTEP"):
			continue
		kept.append(line)
	return "\n".join(kept)


# -- reading the steps back ------------------------------------------------------


func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _store.scenery, {}, true)


func _step_numbered(number: int) -> Instructions.Step:
	var found: Instructions.Step = null
	for step: Instructions.Step in _plan():
		if step.number == number and (found == null or step.callout_step == 0):
			found = step
	return found


## Every part's step in the booklet now, by id: "12", or "12.3" in the
## callout step 12 puts on.
func _numbers() -> Dictionary:
	var out: Dictionary = {}
	for step: Instructions.Step in _plan():
		for brick_id: int in step.brick_ids:
			out[brick_id] = ("%d.%d" % [step.number, step.callout_step]) if step.in_callout() \
				else str(step.number)
	return out


## The booklet's section marks: each step its banner starts on, as
## Booklet.lay_out reads them off the steps outside a callout, "12 island".
func _marks() -> Array:
	var out: Array = []
	var section: String = ""
	for step: Instructions.Step in _plan():
		if step.in_callout() or step.section == section:
			continue
		section = step.section
		out.append("%d %s" % [step.number, section])
	return out


## Each part's step off edit_steps's list, by id: the number its line
## starts with (a line names twelve of a step's parts, and what its step is
## part of, which the model's own steps name and worked-out ones do not).
func _said_now() -> Dictionary:
	var listed: String = await _say("edit_steps", {})
	var out: Dictionary = {}
	var page: int = 1
	while true:
		for line: String in listed.split("\n"):
			if line.find(": #") < 0:
				continue
			var head: String = line.strip_edges().get_slice(":", 0).get_slice(" ", 0)
			for word: String in line.substr(line.find(":") + 1).split(" ", false):
				if word.begins_with("#") and word.substr(1).is_valid_int():
					out[word.substr(1).to_int()] = head
		# A long list goes on from=.
		var more: RegExMatch = RegEx.create_from_string("from=(\\d+)").search(listed)
		if more == null or page > 40:
			break
		page += 1
		listed = await _say("edit_steps", {"from": more.get_string(1).to_int()})
	return out


## Each of [param numbers]'s parts as [its number and colour, where it
## is, its step]: a file opened again gives its parts new ids.
func _placed(numbers: Dictionary) -> Array:
	var out: Array = []
	for brick_id: int in numbers:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		out.append(["%s/%d" % [brick.part_id, brick.color_code], brick.transform.origin,
			str(numbers[brick_id])])
	return out


## The parts of [param before] ([method _placed]) with none in [param after]
## alike, where it was to a twentieth of an LDU, in the same step: two alike
## in one place are either.
static func _unmatched(before: Array, after: Array) -> Array:
	var free: Array = after.duplicate()
	var out: Array = []
	for one: Array in before:
		var found: int = -1
		for index: int in free.size():
			var other: Array = free[index]
			if other[0] == one[0] and other[2] == one[2] \
					and (other[1] as Vector3).distance_to(one[1]) < 0.05:
				found = index
				break
		if found < 0:
			out.append(one)
		else:
			free.remove_at(found)
	return out


## The parts of [param before] in another step in [param after], by id;
## with [param both], of those in both.
static func _moved(before: Dictionary, after: Dictionary, both: bool = false) -> Array:
	var out: Array = []
	for brick_id: Variant in before:
		if both and not after.has(brick_id):
			continue
		if str(after.get(brick_id, "")) != str(before[brick_id]):
			out.append(int(brick_id))
	out.sort()
	return out


func _first(ids: Array, now: Dictionary) -> String:
	if ids.is_empty():
		return ""
	var named := PackedStringArray()
	for brick_id: int in ids.slice(0, 4):
		named.append("#%d %s->%s" % [brick_id, str(_listed.get(brick_id, "?")),
			str(now.get(brick_id, "?"))])
	return ": " + ", ".join(named) + (" ..." if ids.size() > 4 else "")


func _back_to(depth: int) -> void:
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(2)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
