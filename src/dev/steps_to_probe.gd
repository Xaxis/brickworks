## Parts moved to a step are in that step, and the edit says where (stepsto).
##
##   godot --headless --path . --script src/dev/steps_to_probe.gd
##
## A Claude Code session making the lighthouse's booklet over the connector
## (claudedir, 2026-11-03) called edit_steps {"op": "to", "step": 1} with the
## island's rocks and two parts of the tower, to put them with the baseplates
## in step 1. It was told "moved 236 parts to step 1", and the list then had
## them in steps 1 to 52 and the baseplates at 53: a part of a sub-model,
## named alone, stood for its whole sub-model, and a sub-model put on in a
## step is built before that step's own parts. The list never said which
## steps were the island's, and the words were worked out, not read back.
##
## Here a model built as the lighthouse is, from its file with its author's
## steps: a baseplate (step 1) and a brick of the model's own (2), an island
## of 80 parts built where it stands in six steps of its own (3 to 8, the
## first a single brick), a tower of 63 on it in seven (9 to 15), a keeper
## of four built in a callout and put on in step 16 with a brick of the
## model's, and a flag on the tower (17). Over MCP, as the connector calls
## it (CommandSocket.answer_rpc, tools/call), each edit read back off the
## booklet's plan and off edit_steps's list, never off its own words, and
## undone to the steps as they were:
## - the session's call, and one rock to step 1: refused, naming the tower and
##   the island and the steps each is built in, nothing changed;
## - a part of the model's own from the last step to step 1, from step 2 to
##   the last and to a middle one: in that step, its number said;
## - a rock from the island's first step to a middle one of its own, and
##   from its last to its first: in that step, said with its number now;
## - a part of the tower to the last step: refused;
## - the keeper whole to step 1, and the island whole to the last step:
##   the keeper in step 1's callout; the island built before step 17, said;
## - next and new on one rock: it alone moves, within the island.
## Then the steps panel's own: a click on a rock selects the island whole,
## and dropped on the last step it goes as the call did; the tower dropped on
## a step of the island is refused, naming the island. And Next step (E) on
## a brick put down since says the number the timeline gives its step, not
## the count of the model's own steps. Last, the isle with none of its
## author's steps, as the lighthouse was when the session edited it: a
## refusal names the steps the list gives the parts, where the lighthouse's
## tower was said to be "in step 0".
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0

var _plate: int = 0
var _own_early: int = 0       ## the 2 x 4 of step 2
var _own_late: int = 0        ## the flag, step 17
var _keeper_brick: int = 0    ## the 2 x 4 put on with the keeper
var _island: Array = []
var _tower: Array = []
var _keeper: Array = []
## The island's parts by their step within it.
var _rocks: Dictionary = {}
## Every part's step in the booklet, as opened.
var _as_opened: Dictionary = {}


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
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(_model(), "isle")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)
	_read_parts()
	_as_opened = _numbers_by_id()
	var listed: String = await _say("edit_steps", {})
	print(listed)
	if not _check("the model opens with its author's 17 steps: the plate 1, the island 3 to 8, "
			+ "the tower 9 to 15, the keeper 16, the flag 17 (%s)" % _where(_as_opened),
			_last() == 17 and _at(_plate) == 1 and _at(_own_early) == 2
			and _span(_island) == [3, 8] and _span(_tower) == [9, 15] and _span(_keeper) == [16, 16]
			and _at(_own_late) == 17):
		quit(1)
		return
	_check("...and its list names the island's steps as the island's (%s)" % _line(listed, 3),
		_line(listed, 3).contains("in the island, 1 of 6")
		and _line(listed, 8).contains("in the island, 6 of 6"))

	print("\nrefused, nothing changed")
	var call: Array = _island.duplicate()
	call.append_array(_tower.slice(0, 2))
	call.append(_own_early)
	await _refused({"op": "to", "step": 1, "bricks": call}, ["tower", "9 to 15"],
		"the session's call: the island's 80, two of the tower's and the model's own to step 1")
	await _refused({"op": "to", "step": 1, "bricks": [_rocks[5][0]]}, ["island", "3 to 8"],
		"a rock of the island's last step to step 1")
	await _refused({"op": "to", "step": 17, "bricks": [_tower[0]]}, ["tower", "9 to 15"],
		"a part of the tower to the last step")

	print("\nto a step, in it")
	await _to("the flag, the last step's, to step 1", [_own_late], 1,
		func() -> bool: return _at(_own_late) == 1 and _at(_plate) == 1 and _last() == 16)
	await _to("the 2 x 4 of step 2 to the last step", [_own_early], 17,
		func() -> bool: return _at(_own_early) == _at(_own_late) and _at(_own_late) == 16)
	await _to("the 2 x 4 of step 2 to step 16, a middle one, with the keeper", [_own_early], 16,
		func() -> bool: return _at(_own_early) == _at(_keeper_brick) and _at(_keeper_brick) == 15)
	await _to("the island's first step's one rock to its fourth, step 6", [_rocks[0][0]], 6,
		func() -> bool: return _at(_rocks[0][0]) == _at(_rocks[3][0]) and _at(_rocks[3][0]) == 5)
	await _to("a rock of the island's last step to its first, step 3", [_rocks[5][0]], 3,
		func() -> bool: return (_at(_rocks[5][0]) == 3 and _at(_rocks[0][0]) == 3
			and _span(_rocks[5].slice(1)) == [8, 8]))
	await _to("the keeper whole to step 1", _keeper, 1,
		func() -> bool: return _span(_keeper) == [1, 1] and _at(_plate) == 1)
	var island_said: String = await _to("the island whole to the last step", _island, 17,
		func() -> bool: return (_span(_island) == [11, 16] and _at(_own_late) == 17
			and _span(_tower) == [3, 9]))
	_check("...said: the island in steps 11 to 16, built before step 17 (\"%s\")" % island_said,
		island_said.contains("steps 11 to 16") and island_said.contains("before step 17"))

	print("\nnext and new, on one rock")
	var rock: int = _rocks[2][0]
	await _edit("next on a rock of the island's third step", {"op": "next", "bricks": [rock]},
		func() -> bool: return _at(rock) == 6 and _moved_only([rock]))
	await _edit("new on it", {"op": "new", "bricks": [rock]},
		func() -> bool: return (_at(rock) == 6 and _at(_rocks[2][1]) == 5
			and _at(_rocks[3][0]) == 7 and _span(_island) == [3, 9] and _span(_tower) == [10, 16]
			and _at(_own_late) == 18))

	print("\nthe steps panel")
	await _panel()
	print("\nnext step (E), as the person ends one")
	await _close()
	print("\nsteps the app works out")
	await _worked_out()

	if _failures == 0:
		print("steps_to probe: all checks passed")
	else:
		print("steps_to probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


## The model: a baseplate, an island built where it stands, a tower on it,
## a keeper built in a callout, and parts of the model's own between.
func _model() -> String:
	var lines := PackedStringArray(["0 FILE isle.ldr", "0 Isle", "0 Name: isle.ldr",
		"0 Author: steps_to probe", "",
		"1 2 0 0 0 1 0 0 0 1 0 0 0 1 3811.dat", "0 STEP",
		"1 4 200 -24 200 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 island.ldr", "0 STEP",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 tower.ldr", "0 STEP",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 keeper.ldr",
		"1 1 -200 -24 200 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 14 -130 -312 -130 1 0 0 0 1 0 0 0 1 3005.dat", "0 NOFILE",
		"0 FILE island.ldr", "0 island", "0 Name: island.ldr", "0 Author: steps_to probe", ""])
	# Five courses of sixteen 2 x 2 bricks; the first brick a step alone.
	for course: int in 5:
		for n: int in 16:
			lines.append("1 %d %d %d %d 1 0 0 0 1 0 0 0 1 3003.dat" % [[72, 71][(n + course) % 2],
				-140 + 40 * (n % 4), -24 * (course + 1), -140 + 40 * (n / 4)])
			if course == 0 and n == 0:
				lines.append("0 STEP")
		if course < 4:
			lines.append("0 STEP")
	lines.append_array(["0 NOFILE", "0 FILE tower.ldr", "0 tower", "0 Name: tower.ldr",
		"0 Author: steps_to probe", ""])
	# Seven courses of nine on the island.
	for course: int in 7:
		for n: int in 9:
			lines.append("1 %d %d %d %d 1 0 0 0 1 0 0 0 1 3003.dat" % [[15, 4][course % 2],
				-120 + 40 * (n % 3), -120 - 24 * (course + 1), -120 + 40 * (n / 3)])
		if course < 6:
			lines.append("0 STEP")
	lines.append_array(["0 NOFILE", "0 FILE keeper.ldr", "0 keeper", "0 Name: keeper.ldr",
		"0 Author: steps_to probe", "",
		"1 1 200 -24 -200 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 1 200 -48 -200 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 14 200 -72 -200 1 0 0 0 1 0 0 0 1 3003.dat",
		"1 0 210 -96 -200 1 0 0 0 1 0 0 0 1 3005.dat", "0 NOFILE"])
	return "\n".join(lines) + "\n"


func _read_parts() -> void:
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var path: String = Assemblies.path_of(brick)
		if path.begins_with("island"):
			_island.append(brick.id)
			if not _rocks.has(brick.step):
				_rocks[brick.step] = []
			(_rocks[brick.step] as Array).append(brick.id)
		elif path.begins_with("tower"):
			_tower.append(brick.id)
		elif path.begins_with("keeper"):
			_keeper.append(brick.id)
		elif brick.part_id == "3811":
			_plate = brick.id
		elif brick.part_id == "3005":
			_own_late = brick.id
		elif brick.transform.origin.x > 0.0:
			_own_early = brick.id
		else:
			_keeper_brick = brick.id
	for step: Variant in _rocks:
		(_rocks[step] as Array).sort()


# -- the edits ------------------------------------------------------------------


## An edit_steps call that must change nothing, its answer naming [param named].
func _refused(input: Dictionary, named: Array, what: String) -> void:
	var depth: int = _builder.history_depth()
	var said: String = await _say("edit_steps", input)
	var named_all: bool = named.all(func(word: String) -> bool: return said.contains(word))
	_check("%s: refused, naming %s (\"%s\")" % [what, " and ".join(named), said],
		named_all and not said.begins_with("moved"))
	_check("...and nothing changed (%d undo steps more, %d parts in another step)" % [
		_builder.history_depth() - depth, _changed()],
		_builder.history_depth() == depth and _changed() == 0)
	await _back_to(depth)


## edit_steps "to" [param step] with [param ids]: [param judged] true of the
## plan after it, the answer naming the step the list has the first of them
## in, one undo step, and undone to the steps as opened. Returns the answer.
func _to(what: String, ids: Array, step: int, judged: Callable) -> String:
	return await _edit("%s (to %d)" % [what, step], {"op": "to", "step": step, "bricks": ids},
		judged)


func _edit(what: String, input: Dictionary, judged: Callable) -> String:
	var depth: int = _builder.history_depth()
	var ids: Array = input["bricks"]
	var said: String = await _say("edit_steps", input)
	var listed: String = await _say("edit_steps", {})
	var span: Array = _span(ids)
	var named: String = ("step %d" % span[0]) if span[0] == span[1] \
		else "steps %d to %d" % [span[0], span[1]]
	_check("%s: %s" % [what, _where(_numbers_by_id(), ids)], bool(judged.call()))
	_check("...the list has #%d in step %d" % [int(ids[0]), _listed_at(listed, int(ids[0]))],
		ids.size() > 12 or _listed_at(listed, int(ids[0])) == int(span[0]))
	_check("...said where they are, %s (\"%s\")" % [named, said],
		RegEx.create_from_string("\\b%s(?!\\d)" % named).search(said) != null)
	_check("...one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(2)
	_check("...undone, every part in the step it was (%d not)" % _changed(), _changed() == 0)
	return said


## An edit that was to be refused undone, when it was not: the next case
## starts from the steps as opened, so each fails on its own.
func _back_to(depth: int) -> void:
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(2)


## Whether only [param ids] of the model's parts are in another step than
## the one each was in as opened.
func _moved_only(ids: Array) -> bool:
	var mine: Dictionary = {}
	for brick_id: Variant in ids:
		mine[int(brick_id)] = true
	var now: Dictionary = _numbers_by_id()
	for brick_id: int in now:
		if not mine.has(brick_id) and int(now[brick_id]) != int(_as_opened[brick_id]):
			return false
	return true


# -- the steps panel --------------------------------------------------------------


## As StepsBar._row_drop does with the selection dropped on a step's cell,
## and Move to step… with its number typed: Shell.change_steps("to") with
## the selection and that step of the plan the timeline shows.
func _panel() -> void:
	_builder.clear_selection()
	_builder.select_brick(_rocks[5][0], false)
	var selected: Array = _builder.selection.keys()
	_check("a click on a rock selects the island whole (%d parts)" % selected.size(),
		selected.size() == _island.size())
	var depth: int = _builder.history_depth()
	var said: String = _shell.change_steps("to", selected, _plan_step(17))
	_check("...dropped on step 17: the island in steps 11 to 16, before the flag's 17 (%s)"
		% _where(_numbers_by_id(), _island), _span(_island) == [11, 16] and _at(_own_late) == 17)
	_check("...said so (\"%s\")" % said, said.contains("steps 11 to 16")
		and said.contains("before step 17"))
	_check("...one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_builder.undo()
	await _frames(2)
	_check("...undone (%d parts in another step)" % _changed(), _changed() == 0)
	_builder.clear_selection()
	_builder.select_brick(_tower[0], false)
	selected = _builder.selection.keys()
	depth = _builder.history_depth()
	said = _shell.change_steps("to", selected, _plan_step(4))
	_check("the tower dropped on step 4, one of the island's: refused, naming the island (\"%s\")"
		% said, said.contains("island") and not said.begins_with("moved"))
	_check("...nothing changed (%d undo steps, %d parts)" % [_builder.history_depth() - depth,
		_changed()], _builder.history_depth() == depth and _changed() == 0)
	await _back_to(depth)
	_builder.clear_selection()


## Edit, Next step: a brick put down since the last step made a step after
## it, said with the number the booklet gives that step.
func _close() -> void:
	_builder.held_part = "3005"
	_builder.held_color = 4
	_builder.update_preview(Vector3(100.0, 400.0, 100.0), Vector3.DOWN)
	var put: int = _builder.place()
	if not _check("a brick put down on the baseplate (#%d)" % put, put != 0):
		return
	var said: String = _shell.change_steps("close", [], null)
	_check("Next step makes it step 18, after the flag's 17, and says so (\"%s\"; it is in %d)"
		% [said, _at(put)], _at(put) == 18 and said.begins_with("step 18:")
		and said.contains("starts step 19"))
	_builder.undo()
	_builder.undo()
	await _frames(2)
	_check("...both undone (%d parts in another step, #%d gone)" % [_changed(), put],
		_changed() == 0 and _world.get_brick(put) == null)


## The step numbered [param number] as the timeline's row has it: the main
## step, not one inside a callout.
func _plan_step(number: int) -> Instructions.Step:
	var found: Instructions.Step = null
	for step: Instructions.Step in _plan():
		if step.number == number and (found == null or step.callout_step == 0):
			found = step
	return found


## The isle again with none of its author's steps: the app works them out,
## and an edit makes them the model's own before it is made. Refused, it
## takes that back, and says where the parts are as the list numbers them.
func _worked_out() -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(
		_model().replace("0 STEP\n", ""), "isle")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)
	var island: Array = []
	var tower: Array = []
	var plate: int = 0
	var own: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_of(brick)
		if path.begins_with("island"):
			island.append(brick.id)
		elif path.begins_with("tower"):
			tower.append(brick.id)
		elif path.is_empty() and brick.part_id == "3811":
			plate = brick.id
		elif path.is_empty() and brick.part_id == "3001" and brick.transform.origin.x > 0.0:
			own = brick.id
	var listed: String = await _say("edit_steps", {})
	var plate_at: int = _listed_at(listed, plate)
	if not _check("the isle with no steps of its author's: \"%s\", the plate in %d"
			% [listed.get_slice("\n", 0), plate_at],
			listed.get_slice("\n", 0).contains("worked out by the app") and own != 0
			and plate_at > 0):
		return
	var call: Array = island.duplicate()
	call.append_array(tower.slice(0, 2))
	call.append(own)
	for case: Array in [[call, "tower", tower, "the session's call"],
			[[island[0]], "island", island, "a rock"]]:
		var span: Array = _listed_span(listed, case[2])
		var named: String = ("step %d" % span[0]) if span[0] == span[1] \
			else "steps %d to %d" % [span[0], span[1]]
		var depth: int = _builder.history_depth()
		var said: String = await _say("edit_steps", {"op": "to", "step": plate_at,
			"bricks": case[0]})
		_check("%s to the plate's step %d: refused, the %s in %s as the list has it (\"%s\")"
			% [case[3], plate_at, case[1], named, said],
			said.contains("of the %s, in %s" % [case[1], named])
			and RegEx.create_from_string("\\b%s(?!\\d)" % named).search(said) != null
			and not said.begins_with("moved"))
		var after: String = await _say("edit_steps", {})
		_check("...and the steps still the app's (%d undo steps more, the list %s)" % [
			_builder.history_depth() - depth, "as it was" if after == listed else "changed"],
			_builder.history_depth() == depth and after == listed)
		await _back_to(depth)


## The first and last step [param listed] (edit_steps's list) has any of
## [param ids] in.
func _listed_span(listed: String, ids: Array) -> Array:
	var first: int = 1 << 30
	var last: int = 0
	for brick_id: Variant in ids:
		var number: int = _listed_at(listed, int(brick_id))
		if number > 0:
			first = mini(first, number)
			last = maxi(last, number)
	return [first, last]


# -- reading the steps back ------------------------------------------------------


func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _store.scenery, {}, true)


## Every part's step in the booklet now, by id.
func _numbers_by_id() -> Dictionary:
	var out: Dictionary = {}
	for step: Instructions.Step in _plan():
		for brick_id: int in step.brick_ids:
			out[brick_id] = step.number
	return out


func _at(brick_id: int) -> int:
	return int(_numbers_by_id().get(brick_id, 0))


func _last() -> int:
	var steps: Array[Instructions.Step] = _plan()
	return steps[steps.size() - 1].number if not steps.is_empty() else 0


## The first and last step [param ids] are in.
func _span(ids: Array) -> Array:
	var now: Dictionary = _numbers_by_id()
	var first: int = 1 << 30
	var last: int = 0
	for brick_id: Variant in ids:
		var number: int = int(now.get(int(brick_id), 0))
		first = mini(first, number)
		last = maxi(last, number)
	return [first, last]


## How many parts are in another step than as opened.
func _changed() -> int:
	var now: Dictionary = _numbers_by_id()
	var count: int = 0
	for brick_id: int in _as_opened:
		if int(now.get(brick_id, 0)) != int(_as_opened[brick_id]):
			count += 1
	return count


## Where the parts are, for a check's line: the plate, the 2 x 4s, the
## flag, the island, the tower and the keeper ([param ids] first when given).
func _where(now: Dictionary, ids: Array = []) -> String:
	var spans := PackedStringArray()
	if not ids.is_empty():
		spans.append("these %s" % str(_span(ids)))
	spans.append("plate %d, 2x4 %d, flag %d, keeper's 2x4 %d" % [int(now.get(_plate, 0)),
		int(now.get(_own_early, 0)), int(now.get(_own_late, 0)), int(now.get(_keeper_brick, 0))])
	spans.append("island %s, tower %s, keeper %s" % [str(_span(_island)), str(_span(_tower)),
		str(_span(_keeper))])
	return "; ".join(spans)


## The list's line for step [param number] (its first, when it has several).
func _line(listed: String, number: int) -> String:
	for line: String in listed.split("\n"):
		var head: String = line.strip_edges().get_slice(":", 0)
		if head.get_slice(" ", 0) == str(number):
			return line.strip_edges()
	return ""


## The step the list has #[param brick_id] in, or 0.
func _listed_at(listed: String, brick_id: int) -> int:
	var named := RegEx.create_from_string("#%d\\b" % brick_id)
	for line: String in listed.split("\n"):
		var at: int = line.find(":")
		if at > 0 and named.search(line.substr(at)) != null:
			return line.strip_edges().get_slice(" ", 0).get_slice(":", 0).to_int()
	return 0


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	# What the tab says before every answer is not the answer.
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
