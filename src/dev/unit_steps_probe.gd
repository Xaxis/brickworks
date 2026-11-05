## Renaming, taking apart or cutting loose a sub-assembly keeps its steps
## (unitsteps).
##
##   godot --headless --path . --script src/dev/unit_steps_probe.gd
##
## Each copy of a sub-model keeps the step it is put on in by its path
## (BrickWorld.unit_steps), and a copy built in its parent's steps keeps
## AuthorSteps.IN_PARENT there. The tree's edits (Assemblies) changed the
## paths and not the table: a copy renamed, cut loose or put inside a new
## sub-assembly lost its entry, the castle's renamed tower went back to
## being built whole, and its parts moved steps in the booklet (stepskeep
## found it). Taken apart, a copy built in steps of its own left its parts
## numbered in steps of a sub-model that was gone.
##
## Here each edit, as a person makes it (the menu's command on the
## selection, the naming dialog) and as a session does over MCP
## (make_unique, make_sections), on:
## - the castle (models/castle.ldr), its steps made its own by one step
##   edit over MCP, every tower and wall built in the castle's steps: a
##   tower renamed, one taken apart, two made a sub-assembly, the model's
##   sections made; and with a second north-east tower, one made unique;
## - 7140-1 as its author stepped it, its sub-models built whole: the rear
##   engines (four copies) renamed, one made unique, an upper wing taken
##   apart.
## After each: no part in another step, by the plan and by edit_steps's
## list (an assembly taken apart: its steps the model's, the order of the
## build the same); the steps test saying what it said before; undo
## putting back every part's step, the table and the tree, and redo the
## edit; saved as Save saves it with nothing then unsaved; and the save
## opened again with every part, colour and place in the step it was in,
## and the same tree.
extends SceneTree

const CASTLE := "res://models/castle.ldr"
const AUTHORED := "res://vendor/omr/files/7140-1.mpd"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _verbs: EditVerbs
var _assemblies: Assemblies
var _socket: CommandSocket
var _rpc_id: int = 0
var _saves: int = 0


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
	_verbs = _main.get("_verbs")
	_assemblies = _shell.assemblies
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var only: String = OS.get_environment("UNIT_STEPS_ONLY")
	var castle: String = FileAccess.get_file_as_string(CASTLE)
	var authored: String = FileAccess.get_file_as_string(AUTHORED)
	if only.is_empty() or "castle".contains(only):
		await _castle(castle)
	if only.is_empty() or "copies".contains(only):
		await _castle_copies(castle)
	if only.is_empty() or "7140".contains(only):
		await _authored(authored)
	if _failures == 0:
		print("unit_steps probe: all checks passed")
	else:
		print("unit_steps probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the models and their edits ------------------------------------------------


func _castle(text: String) -> void:
	var name: String = "the castle, its steps its own"
	print("\n%s" % name)
	var tower: String = "north-east tower#1"
	var rename: Callable = func() -> String:
		_select_assembly(tower)
		_shell.run("rename_assembly")
		await _frames(2)
		return _name_it("Keep")
	await _edit(name, text, true, "renamed by its dialog", rename,
		func(units: Dictionary) -> Array: return _carried(units, {tower: "Keep#1"}))
	var other: String = "south-west tower#1"
	var ungroup: Callable = func() -> String:
		_select_assembly(other)
		_shell.run("leave_submodel")
		await _frames(2)
		return "ungrouped %s" % other
	await _edit(name, text, true, "taken apart by Ungroup", ungroup,
		func(units: Dictionary) -> Array: return _carried(units, {other: null}))
	var pair: Array = ["east curtain wall#1", "south-east tower#1"]
	var make: Callable = func() -> String:
		var ids: Array = Array(_assemblies.ids_under(pair[0])) + Array(_assemblies.ids_under(pair[1]))
		_select_only(ids)
		_shell.run("make_submodel")
		await _frames(2)
		return _name_it("East side")
	await _edit(name, text, true, "two made a sub-assembly by its dialog", make,
		func(units: Dictionary) -> Array: return _carried(units, {pair[0]: "East side#1/" + pair[0],
			pair[1]: "East side#1/" + pair[1]}, ["East side#1"]))
	var sections: Callable = func() -> String:
		var suggested: String = await _say("suggest_sections", {})
		return suggested.get_slice("\n", 0) + " / " + await _say("make_sections", {})
	await _edit(name, text, true, "its sections made over MCP", sections,
		func(units: Dictionary) -> Array: return _sections_carried(units))


func _castle_copies(text: String) -> void:
	var name: String = "the castle with a second north-east tower"
	print("\n%s" % name)
	# Beside the castle, on the ground: the castle's own copy stands on its
	# baseplates, a plate up.
	var lines: PackedStringArray = text.split("\n")
	var at: int = -1
	for n: int in lines.size():
		if lines[n].strip_edges().ends_with(" north_east_tower.ldr"):
			at = n
			break
	if not _check("the castle places its north-east tower (line %d)" % (at + 1), at >= 0):
		return
	lines.insert(at + 1, "1 16 1600 0 0 1 0 0 0 1 0 0 0 1 north_east_tower.ldr")
	var twice: String = "\n".join(lines)
	var by_menu: Callable = func() -> String:
		_select_assembly("north-east tower#2")
		_shell.run("make_unique")
		await _frames(2)
		return "made north-east tower#2 unique"
	await _edit(name, twice, true, "made unique by the menu", by_menu,
		func(units: Dictionary) -> Array:
			return _carried(units, {"north-east tower#2": "north-east tower 2#1"}))
	var by_mcp: Callable = func() -> String:
		return await _say("make_unique", {"assembly": "north-east tower#1"})
	await _edit(name, twice, true, "made unique over MCP", by_mcp,
		func(units: Dictionary) -> Array:
			return _carried(units, {"north-east tower#1": "north-east tower 2#1"}))


func _authored(text: String) -> void:
	var name: String = "7140-1 as its author stepped it"
	print("\n%s" % name)
	await _open(text, name)
	var engines: PackedStringArray = PackedStringArray()
	var wing: String = ""
	for path: String in _assemblies.paths():
		if Assemblies.definition(Assemblies.leaf(path)).ends_with("Rear Engines"):
			engines.append(path)
		elif Assemblies.definition(Assemblies.leaf(path)).ends_with("Upper Left Wing"):
			wing = path
	if not _check("its rear engines, %d copies (%s), and its upper left wing (%s)" % [
			engines.size(), ", ".join(engines), wing], engines.size() >= 3 and not wing.is_empty()
			and AuthorSteps.any(_world, _store.scenery)):
		return
	var kind: String = Assemblies.definition(Assemblies.leaf(engines[0]))
	var renamed: Dictionary = {}
	for path: String in engines:
		renamed[path] = Assemblies.join(Assemblies.parent_of(path),
			"Thrusters#%d" % Assemblies.copy_of(Assemblies.leaf(path)))
	var rename: Callable = func() -> String:
		_select_assembly(engines[1])
		_shell.run("rename_assembly")
		await _frames(2)
		return _name_it("Thrusters")
	await _edit(name, text, false, "the rear engines renamed by their dialog", rename,
		func(units: Dictionary) -> Array: return _carried(units, renamed))
	var unique: String = Assemblies.join(Assemblies.parent_of(engines[2]), kind + " 2#1")
	var by_mcp: Callable = func() -> String:
		return await _say("make_unique", {"assembly": engines[2]})
	await _edit(name, text, false, "a rear engine made unique over MCP", by_mcp,
		func(units: Dictionary) -> Array: return _carried(units, {engines[2]: unique}))
	var by_menu: Callable = func() -> String:
		_select_assembly(engines[0])
		_shell.run("make_unique")
		await _frames(2)
		return "made %s unique" % engines[0]
	var first: String = Assemblies.join(Assemblies.parent_of(engines[0]), kind + " 2#1")
	await _edit(name, text, false, "a rear engine made unique by the menu", by_menu,
		func(units: Dictionary) -> Array: return _carried(units, {engines[0]: first}))
	var ungroup: Callable = func() -> String:
		_select_assembly(wing)
		_shell.run("leave_submodel")
		await _frames(2)
		return "ungrouped %s" % wing
	await _edit(name, text, false, "its upper left wing taken apart by Ungroup", ungroup,
		func(units: Dictionary) -> Array: return _inlined_carried(units, wing), true)


## [param text] opened as [param name], its steps made its own by one step
## edit over MCP when [param stepped]; then [param edit] (its words), and
## [param kept] (the table as it was -> [ok, words]) saying whether each
## copy's entry went where the edit put the copy. Every part in the step
## it was in, or with [param regrouped] the build in the same order; undone
## and redone; saved and opened again.
func _edit(name: String, text: String, stepped: bool, what: String, edit: Callable,
		kept: Callable, regrouped: bool = false) -> void:
	await _open(text, name)
	if stepped:
		var part: int = _middle_part()
		var said: String = await _say("edit_steps", {"op": "next", "bricks": [part]})
		await _frames(2)
		var parented: int = _world.unit_steps.values().filter(func(step: int) -> bool:
			return step == AuthorSteps.IN_PARENT).size()
		if not _check("%s: its steps its own (%s), %d copies built in the castle's steps" % [what,
				said.get_slice("\n", 0), parented],
				AuthorSteps.any(_world, _store.scenery) and parented >= 9):
			return
	var before: Dictionary = _numbers()
	var said_before: Dictionary = await _said_now()
	var order_before: Array = _order()
	var units: Dictionary = _world.unit_steps.duplicate()
	var tree: Dictionary = _by_path()
	var tested_then: Dictionary = await _tested(_store.to_text(name, true))
	var tested_before: bool = _passes(tested_then)
	var depth: int = _builder.history_depth()
	var said: String = str(await edit.call())
	await _frames(4)
	var after: Dictionary = _numbers()
	var tree_after: Dictionary = _by_path()
	if not _check("%s (\"%s\"): the tree changed, %d sub-models now" % [what,
			said.get_slice("\n", 0).left(160), tree_after.size() - 1], tree_after != tree):
		await _back_to(depth)
		return
	if regrouped:
		var order_after: Array = _order()
		var differ: int = _first_apart(order_before, order_after)
		_check("...its steps now the model's: the build in the same order, %d steps, %s" % [
			order_after.size(), "the same" if differ < 0 else "apart from step %d of %d: %s / %s"
			% [differ + 1, order_before.size(), str(order_before[differ]).left(60) if differ
			< order_before.size() else "-", str(order_after[differ]).left(60) if differ
			< order_after.size() else "-"]], differ < 0)
	else:
		var moved: Array = _moved(before, after)
		_check("...%d of %d parts in another step%s" % [moved.size(), before.size(),
			_first(moved, before, after)], moved.is_empty() and after.size() == before.size())
		var said_after: Dictionary = await _said_now()
		var listed: Array = _moved(said_before, said_after, true)
		_check("...and in edit_steps's list, %d%s" % [listed.size(),
			_first(listed, said_before, said_after)], listed.is_empty())
	var carried: Array = kept.call(units)
	_check("...%s" % carried[1], bool(carried[0]))
	var saved: String = _store.to_text(name, true)
	var tested: Dictionary = await _tested(saved)
	_check("...the steps test as before: %s / %s" % [_verdict(tested_then).left(120),
		_verdict(tested)], _passes(tested) == tested_before)
	var units_after: Dictionary = _world.unit_steps.duplicate()
	var edited: Array = _placed(after)

	await _back_to(depth)
	var back: Array = _moved(before, _numbers())
	_check("...undone: %d parts in another step, the table %s, the tree %s" % [back.size(),
		"as it was" if _world.unit_steps == units else "not: %s" % _unlike(units, _world.unit_steps),
		"as it was" if _by_path() == tree else "not"],
		back.is_empty() and _world.unit_steps == units and _by_path() == tree)
	_builder.redo()
	await _frames(4)
	var again: Array = _moved(after, _numbers())
	_check("...redone: %d parts in another step, the table %s" % [again.size(),
		"as edited" if _world.unit_steps == units_after
		else "not: %s" % _unlike(units_after, _world.unit_steps)],
		again.is_empty() and _world.unit_steps == units_after and _by_path() == tree_after)
	# Saved as Save saves it, and nothing left unsaved: a model saved in the
	# steps a person sees said at once it had changes (mcp_walk3, 1d3d6e28).
	_saves += 1
	var file_name: String = "unit steps %d" % _saves
	var stored: bool = _store.save_as(file_name)
	_check("...saved as \"%s\": %s" % [file_name, ("nothing unsaved after it"
		if not _store.has_unsaved_work() else "it says it has changes not saved") if stored
		else "not saved: %s" % _store.refused], stored and not _store.has_unsaved_work())

	await _open(saved, name)
	var reopened: Array = _placed(_numbers())
	var apart: Array = _unmatched(edited, reopened)
	_check("...saved (%d lines say a sub-model built in its parent's steps) and opened again: "
		% _in_lines(saved) + "%d of %d parts not where they were, or in another step%s" % [
		apart.size(), edited.size(), (": " + ", ".join(apart.slice(0, 3).map(
			func(one: Array) -> String: return "%s at %s in %s" % [one[0], str(one[1]), one[2]])))
			if not apart.is_empty() else ""],
		apart.is_empty() and reopened.size() == edited.size())
	_check("...and the same tree, %d sub-models" % (_by_path().size() - 1),
		_by_kind(_by_path()) == _by_kind(tree_after))


## Whether each of [param moves]' copies (old path -> its new path, or null
## when the edit took it apart) has the entry it had in [param units] where
## the edit put it, and every other entry is as it was; [param made] are
## sub-assemblies the edit made, built in their parents' steps. [ok, words].
func _carried(units: Dictionary, moves: Dictionary, made: Array = []) -> Array:
	var wrong := PackedStringArray()
	var now: Dictionary = _world.unit_steps
	for path: String in units:
		var to: Variant = moves.get(path, path)
		if to == null:
			if now.has(path):
				wrong.append("%s still %d" % [path, int(now[path])])
			continue
		if int(now.get(str(to), -1)) != int(units[path]):
			wrong.append("%s %d, at %s %d" % [path, int(units[path]), str(to),
				int(now.get(str(to), -1))])
		elif str(to) != path and now.has(path):
			wrong.append("%s kept as well" % path)
	var built_in: bool = AuthorSteps.any(_world, _store.scenery)
	for path: String in made:
		if built_in and int(now.get(path, -1)) != AuthorSteps.IN_PARENT:
			wrong.append("%s made, %d" % [path, int(now.get(path, -1))])
	var named: Array = moves.keys().filter(func(path: String) -> bool:
		return units.has(path)).map(func(path: String) -> String:
			return "%s %d -> %s" % [path, int(units[path]), str(moves[path]) if moves[path] != null
				else "gone"])
	return [wrong.is_empty(), "each copy's step where it went (%s)%s" % [", ".join(named),
		"" if wrong.is_empty() else ": " + ", ".join(wrong.slice(0, 4))]]


## Ungroup's [param units] check for [param wing], a copy built in steps of
## its own: nothing kept at its path or under it; each copy that was in it
## at its path in the parent, its step one of the parent's now; and the
## steps the copies go on in, in the section that had the wing and in the
## wing, in the order they were built: the wing's where it went on, before
## what else its step put on. Every other entry as it was. [ok, words].
func _inlined_carried(units: Dictionary, wing: String) -> Array:
	var now: Dictionary = _world.unit_steps
	var parent: String = Assemblies.parent_of(wing)
	var home_of := func(path: String) -> String:
		while not path.is_empty() and int(units.get(path, -1)) == AuthorSteps.IN_PARENT:
			path = Assemblies.parent_of(path)
		return path
	var outer: String = home_of.call(parent)
	var at: int = int(units.get(wing, -1))
	var wrong := PackedStringArray()
	var named := PackedStringArray()
	var keyed: Array = []           ## [the order it was built in, its step now, its path]
	for path: String in units:
		if path == wing:
			if now.has(wing):
				wrong.append("%s still %d" % [wing, int(now[wing])])
			continue
		var to: String = path
		if path.begins_with(wing + "/"):
			to = Assemblies.join(parent, path.substr(wing.length() + 1))
			if now.has(path):
				wrong.append("%s kept as well" % path)
			named.append("%s %d -> %s %d" % [path, int(units[path]), to, int(now.get(to, -1))])
		var step: int = int(units[path])
		if not now.has(to):
			wrong.append("%s %d, none at %s" % [path, step, to])
			continue
		var section: String = home_of.call(Assemblies.parent_of(path))
		if step == AuthorSteps.IN_PARENT or (section != outer and section != wing):
			if int(now[to]) != step:
				wrong.append("%s %d, at %s %d" % [path, step, to, int(now[to])])
		elif section == wing:
			keyed.append([[at, 0, step], int(now[to]), to])
		else:
			keyed.append([[step, 1 if step == at else 0, 0], int(now[to]), to])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for n: int in range(1, keyed.size()):
		var was: Array = keyed[n - 1]
		var one: Array = keyed[n]
		if (one[0] == was[0]) != (int(one[1]) == int(was[1])) or int(one[1]) < int(was[1]):
			wrong.append("%s %d after %s %d" % [one[2], int(one[1]), was[2], int(was[1])])
	return [wrong.is_empty() and not named.is_empty(), "each copy's step where it went, "
		+ "in the order built (%s gone; %s)%s" % [wing, ", ".join(named.slice(0, 3)),
		"" if wrong.is_empty() else ": " + ", ".join(wrong.slice(0, 4))]]


## make_sections' [param units] check: each copy's entry at every path its
## parts went to (two when a section took some of it), and every section
## made built in the model's steps. [ok, words].
func _sections_carried(units: Dictionary) -> Array:
	var now: Dictionary = _world.unit_steps
	var at: Dictionary = {}         ## a copy's path before -> {its paths now: true}
	var made: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_of(brick)
		for copy: String in units:
			var found: int = path.find(copy)
			if found < 0 or (found > 0 and path[found - 1] != "/") \
					or (path.length() > found + copy.length() and path[found + copy.length()] != "/"):
				continue
			if not at.has(copy):
				at[copy] = {}
			(at[copy] as Dictionary)[path.substr(0, found + copy.length())] = true
			if found > 0:
				made[path.substr(0, found - 1)] = true
	var wrong := PackedStringArray()
	var moved: int = 0
	for copy: String in at:
		for path: String in at[copy]:
			if path != copy:
				moved += 1
			if int(now.get(path, -1)) != int(units[copy]):
				wrong.append("%s %d, at %s %d" % [copy, int(units[copy]), path, int(now.get(path, -1))])
	for path: String in made:
		if int(now.get(path, -1)) != AuthorSteps.IN_PARENT:
			wrong.append("%s made, %d" % [path, int(now.get(path, -1))])
	return [wrong.is_empty() and moved > 0, "%d copies put in %d sections, each built in the "
		% [moved, made.size()] + "castle's steps where it went%s" % ("" if wrong.is_empty()
		else ": " + ", ".join(wrong.slice(0, 4)))]


# -- driving it as a person ------------------------------------------------------


## The parts of the copy at [param path] selected, as a click on it at the
## level it is in selects them: the level above it entered first.
func _select_assembly(path: String) -> void:
	_assemblies.leave_to(Assemblies.parent_of(path))
	_select_only(Array(_assemblies.ids_under(path)))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


## The naming dialog the command opened, [param name] typed in it and OK
## pressed. What the status bar then says.
func _name_it(name: String) -> String:
	var field: LineEdit = _verbs.get("_name_field")
	var dialog: ConfirmationDialog = _verbs.get("_naming")
	if field == null or dialog == null or not dialog.visible:
		return "no naming dialog"
	field.text = name
	dialog.hide()
	dialog.confirmed.emit()
	_assemblies.leave_to("")
	return "named %s" % name


# -- reading the steps back ------------------------------------------------------


func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _store.scenery, {}, true)


## A part of a step in the middle of the build, outside a callout, of two
## parts or more: what the step edit moves on.
func _middle_part() -> int:
	var steps: Array[Instructions.Step] = _plan()
	for step: Instructions.Step in steps.slice(steps.size() / 2):
		if not step.in_callout() and step.brick_ids.size() >= 2:
			return step.brick_ids[0]
	return 0


## Every part's step in the booklet now, by id: "12", or "12.3" in the
## callout step 12 puts on.
func _numbers() -> Dictionary:
	var out: Dictionary = {}
	for step: Instructions.Step in _plan():
		for brick_id: int in step.brick_ids:
			out[brick_id] = ("%d.%d" % [step.number, step.callout_step]) if step.in_callout() \
				else str(step.number)
	return out


## The build as the booklet orders it, by what each step adds: its parts'
## numbers, a step a line, whatever it is numbered.
func _order() -> Array:
	var out: Array = []
	for step: Instructions.Step in _plan():
		var ids: Array = Array(step.brick_ids)
		if ids.is_empty():
			continue
		ids.sort()
		out.append(",".join(ids.map(func(id: int) -> String: return str(id))))
	return out


static func _first_apart(a: Array, b: Array) -> int:
	for n: int in mini(a.size(), b.size()):
		if a[n] != b[n]:
			return n
	return -1 if a.size() == b.size() else mini(a.size(), b.size())


## Each part's step off edit_steps's list, by id (steps_kept_probe).
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
		var more: RegExMatch = RegEx.create_from_string("from=(\\d+)").search(listed)
		if more == null or page > 40:
			break
		page += 1
		listed = await _say("edit_steps", {"from": more.get_string(1).to_int()})
	return out


## How many parts each sub-model's path holds now, the model's own as "".
func _by_path() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			var path: String = Assemblies.path_of(brick)
			out[path] = int(out.get(path, 0)) + 1
	return out


## [param tree] ([method _by_path]) by what each copy is a copy of, as a file
## opened again names it: two copies of one number, a copy split by a
## section, are numbered anew.
static func _by_kind(tree: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for path: String in tree:
		var kinds := PackedStringArray()
		for segment: String in Assemblies.segments(path):
			kinds.append(Assemblies.definition(segment))
		var kind: String = "/".join(kinds)
		out[kind] = int(out.get(kind, 0)) + int(tree[path])
	return out


## Each of [param numbers]' parts as [its number and colour, where it
## is, its step]: a file opened again gives its parts new ids.
func _placed(numbers: Dictionary) -> Array:
	var out: Array = []
	for brick_id: int in numbers:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		out.append(["%s/%d" % [brick.part_id, brick.color_code], brick.transform, str(numbers[brick_id])])
	return out


## The parts of [param before] with none in [param after] alike, in the
## same place and turn to a twentieth of an LDU, in the same step.
static func _unmatched(before: Array, after: Array) -> Array:
	var free: Array = after.duplicate()
	var out: Array = []
	for one: Array in before:
		var found: int = -1
		for index: int in free.size():
			var other: Array = free[index]
			if other[0] == one[0] and other[2] == one[2] \
					and (other[1] as Transform3D).origin.distance_to((one[1] as Transform3D).origin) < 0.05 \
					and (other[1] as Transform3D).basis.is_equal_approx((one[1] as Transform3D).basis):
				found = index
				break
		if found < 0:
			out.append([one[0], (one[1] as Transform3D).origin, one[2]])
		else:
			free.remove_at(found)
	return out


static func _moved(before: Dictionary, after: Dictionary, both: bool = false) -> Array:
	var out: Array = []
	for brick_id: Variant in before:
		if both and not after.has(brick_id):
			continue
		if str(after.get(brick_id, "")) != str(before[brick_id]):
			out.append(int(brick_id))
	out.sort()
	return out


static func _first(ids: Array, was: Dictionary, now: Dictionary) -> String:
	if ids.is_empty():
		return ""
	var named := PackedStringArray()
	for brick_id: int in ids.slice(0, 4):
		named.append("#%d %s->%s" % [brick_id, str(was.get(brick_id, "?")),
			str(now.get(brick_id, "?"))])
	return ": " + ", ".join(named) + (" ..." if ids.size() > 4 else "")


static func _unlike(a: Dictionary, b: Dictionary) -> String:
	var out := PackedStringArray()
	for key: Variant in a:
		if not b.has(key) or b[key] != a[key]:
			out.append("%s %s->%s" % [str(key), str(a[key]), str(b.get(key, "none"))])
	for key: Variant in b:
		if not a.has(key):
			out.append("%s new %s" % [str(key), str(b[key])])
	return ", ".join(out.slice(0, 4)) + (" ..." if out.size() > 4 else "")


static func _in_lines(text: String) -> int:
	var count: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(LdrModel.IN_META):
			count += 1
	return count


func _tested(text: String) -> Dictionary:
	return (await SharedPages.attach_tested(text, _library, _store))["tested"]


func _passes(tested: Dictionary) -> bool:
	return bool(((tested.get("tests", {}) as Dictionary).get("steps", {}) as Dictionary) \
		.get("ok", false))


func _verdict(tested: Dictionary) -> String:
	var why: String = str(((tested.get("tests", {}) as Dictionary).get("steps", {}) as Dictionary) \
		.get("why", ""))
	return ("passes" if _passes(tested) else "fails") + ("" if why.is_empty() else ", " + why.left(120))


# -- the app -----------------------------------------------------------------------


func _open(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, name)
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _back_to(depth: int) -> void:
	while _builder.history_depth() > depth:
		_builder.undo()
	await _frames(4)


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
