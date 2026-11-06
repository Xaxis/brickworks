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
	if only.is_empty() or "siblings".contains(only):
		await _siblings(castle, authored)
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
## [param opts]: "before" () -> words, an edit made first, as the model
## stood; "place" true reads each part by what and where it is, not
## its number (copies follow: the copy built again is new parts); "tree"
## false for an edit that changes no path; "touched" () -> the ids of the
## parts the person moved, read before it, which may be in another step and
## nothing else may; "then" (state before) -> [ok, words], a check of the
## edit's own after it.
func _edit(name: String, text: String, stepped: bool, what: String, edit: Callable,
		kept: Callable, regrouped: bool = false, opts: Dictionary = {}) -> void:
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
	if opts.has("before"):
		var set_up: String = str(await (opts["before"] as Callable).call())
		print("  ....first: %s" % set_up.get_slice("\n", 0).left(160))
		await _frames(4)
	var place: bool = bool(opts.get("place", false))
	var touched: Dictionary = {}
	if opts.has("touched"):
		for brick_id: Variant in (opts["touched"] as Callable).call():
			touched[_key_of(int(brick_id)) if place else int(brick_id)] = true
	var state: Dictionary = (await (opts["state"] as Callable).call()) if opts.has("state") \
		else {}
	var before: Dictionary = _numbers(place)
	var said_before: Dictionary = _keyed(await _said_now()) if place else await _said_now()
	var order_before: Array = _order()
	var units: Dictionary = _world.unit_steps.duplicate()
	var tree: Dictionary = _by_path()
	var tested_then: Dictionary = await _tested(_store.to_text(name, true))
	var tested_before: bool = _passes(tested_then)
	var whole_before: bool = _store.call("_source_text", name) == null
	var depth: int = _builder.history_depth()
	var said: String = str(await edit.call())
	await _frames(4)
	var after: Dictionary = _numbers(place)
	var tree_after: Dictionary = _by_path()
	var tree_too: bool = bool(opts.get("tree", true))
	if not _check("%s (\"%s\"): %s, %d sub-models now" % [what,
			said.get_slice("\n", 0).left(160), "the tree changed" if tree_too
			else "the tree as it was", tree_after.size() - 1],
			(tree_after != tree) == tree_too and _builder.history_depth() > depth):
		await _back_to(depth)
		return
	if opts.has("then"):
		var own: Array = await (opts["then"] as Callable).call(state)
		_check("...%s" % own[1], bool(own[0]))
	if opts.get("order", false):
		var kept_out: Dictionary = {}
		for brick_id: Variant in touched:
			kept_out[int(brick_id)] = true
		var now: Array = _order(kept_out)
		var then: Array = _order(kept_out, order_before)
		var differ: int = _first_apart(then, now)
		_check("...the rest built in the same order, %d steps of it, %s" % [now.size(),
			"the same" if differ < 0 else "apart from step %d: %s / %s" % [differ + 1,
			str(then[differ]).left(60) if differ < then.size() else "-",
			str(now[differ]).left(60) if differ < now.size() else "-"]], differ < 0)
	elif regrouped:
		var order_after: Array = _order()
		var differ: int = _first_apart(order_before, order_after)
		_check("...its steps now the model's: the build in the same order, %d steps, %s" % [
			order_after.size(), "the same" if differ < 0 else "apart from step %d of %d: %s / %s"
			% [differ + 1, order_before.size(), str(order_before[differ]).left(60) if differ
			< order_before.size() else "-", str(order_after[differ]).left(60) if differ
			< order_after.size() else "-"]], differ < 0)
	else:
		var moved: Array = _moved(before, after)
		var theirs: Array = moved.filter(func(one: Variant) -> bool: return touched.has(one))
		var others: Array = moved.filter(func(one: Variant) -> bool: return not touched.has(one))
		_check("...%d of %d parts in another step%s%s" % [others.size(), before.size(),
			"" if touched.is_empty() else " beside the %d the person moved (%d of them in "
			% [touched.size(), theirs.size()] + "another)", _first(others, before, after, 8)],
			others.is_empty() and after.size() == before.size())
		var said_after: Dictionary = _keyed(await _said_now()) if place else await _said_now()
		var listed: Array = _moved(said_before, said_after, true).filter(
			func(one: Variant) -> bool: return not touched.has(one))
		_check("...and in edit_steps's list, %d%s" % [listed.size(),
			_first(listed, said_before, said_after)], listed.is_empty())
	var carried: Array = kept.call(units)
	_check("...%s" % carried[1], bool(carried[0]))
	var saved: String = _store.to_text(name, true)
	var whole_after: bool = _store.call("_source_text", name) == null
	print("  ....saved %s before it, %s after it" % ["whole" if whole_before
		else "into the file it was opened from", "whole" if whole_after
		else "into the file it was opened from"])
	var tested: Dictionary = await _tested(saved)
	_check("...the steps test as before: %s / %s" % [_verdict(tested_then).left(120),
		_verdict(tested)], _passes(tested) == tested_before)
	var units_after: Dictionary = _world.unit_steps.duplicate()
	var edited: Array = _placed(_numbers())

	await _back_to(depth)
	var back: Array = _moved(before, _numbers(place))
	_check("...undone: %d parts in another step, the table %s, the tree %s" % [back.size(),
		"as it was" if _world.unit_steps == units else "not: %s" % _unlike(units, _world.unit_steps),
		"as it was" if _by_path() == tree else "not"],
		back.is_empty() and _world.unit_steps == units and _by_path() == tree)
	_builder.redo()
	await _frames(4)
	var again: Array = _moved(after, _numbers(place))
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


# -- every other edit of a sub-model (stepsiblings) -----------------------------


## The seven edits of a sub-model unitsteps left, each on the castle after one
## step edit (every copy built in the castle's steps), as a person makes it and
## over MCP where a tool makes it; and where the castle, all one section, cannot
## show one, on 7140-1, whose sub-models its author built in steps of their own.
func _siblings(castle: String, authored: String) -> void:
	var stepped: String = "the castle, its steps its own"
	var both: String = "the castle with a second north-east tower"
	var twice: String = _with_second_tower(castle)
	var tower: String = "north-east tower#1"
	var twin: String = "north-east tower#2"

	print("\n1. a copy built again from the one that changed (Assemblies.realize)")
	var red_in := func(path: String) -> int:
		return Array(_assemblies.ids_under(path)).filter(func(brick_id: int) -> bool:
			return _world.get_brick(brick_id).color_code == 4).size()
	var red_then := func() -> Dictionary: return {"red": red_in.call(twin)}
	var followed := func(state: Dictionary) -> Array:
		var now: int = red_in.call(twin)
		return [now == int(state["red"]) + 1, "the other copy followed: %d of its parts red, %d "
			% [now, int(state["red"])] + "before"]
	var paint: Callable = func() -> String:
		var brick: int = _not_red(tower)
		_assemblies.enter(tower)
		_select_only([brick])
		_builder.held_color = 4
		_shell.run("paint")
		await _frames(3)
		_assemblies.leave_to("")
		return "painted #%d of %s red by Paint" % [brick, tower]
	await _edit(both, twice, true, "1. a part of one tower painted by the menu", paint,
		_as_it_was, false, {"place": true, "tree": false, "state": red_then, "then": followed})
	# The session's change to the person's selection, which its other copies
	# follow (edit_model's own changes are no copy's: nothing follows them).
	var recolour: Callable = func() -> String:
		var brick: int = _not_red(tower)
		_assemblies.enter(tower)
		_select_only([brick])
		var said: String = await _say("edit_selection", {"recolor": [{"bricks": [brick],
			"color": 4}], "picture": false})
		_assemblies.leave_to("")
		return said
	await _edit(both, twice, true, "1. a part of one tower painted over MCP (edit_selection)", recolour,
		_as_it_was, false, {"place": true, "tree": false, "state": red_then, "then": followed})

	print("\n2. the file a model was opened from (SourceFile), saved after a tree edit")
	var rename: Callable = func() -> String:
		_select_assembly(tower)
		_shell.run("rename_assembly")
		await _frames(2)
		return _name_it("Keep")
	await _edit(stepped, castle, true, "2. a tower renamed by its dialog, then saved", rename,
		func(units: Dictionary) -> Array: return _carried(units, {tower: "Keep#1"}), false,
		{"then": func(_state: Dictionary) -> Array: return _looks_by_name()})

	print("\n3. a sub-assembly dragged onto another in the model tree (Assemblies.move_into)")
	var wall: String = "east curtain wall#1"
	var onto: String = "south-east tower#1"
	await _edit(stepped, castle, true, "3. the castle's east wall dragged onto its south-east tower",
		func() -> String: return _drag_row(wall, onto),
		func(units: Dictionary) -> Array: return _carried(units, {wall: onto + "/" + wall}))

	print("\n4. some of a sub-assembly's parts taken out of it (Ungroup on them)")
	var three := func() -> Array: return Array(_assemblies.ids_under(tower)).slice(0, 3)
	await _edit(stepped, castle, true, "4. three parts of a tower taken out of it by Ungroup",
		func() -> String: return await _take_out(tower, three.call()), _as_it_was, false,
		{"touched": three})

	print("\n5. parts made a sub-model by name (Builder.name_group)")
	var loose := func() -> Array:
		var out: Array = []
		for brick: BrickWorld.Brick in _world.bricks():
			if Assemblies.path_of(brick).is_empty() and not _store.scenery.has(brick.id) \
					and brick.step >= 0 and out.size() < 4:
				out.append(brick.id)
		return out
	var make: Callable = func() -> String:
		_select_only(loose.call())
		_shell.run("make_submodel")
		await _frames(2)
		return _name_it("Gate plates")
	await _edit(stepped, castle, true, "5. four of the castle's own parts made a sub-model by Ctrl-G",
		make, func(units: Dictionary) -> Array: return _carried(units, {}, ["Gate plates#1"]), false,
		{"then": func(_state: Dictionary) -> Array: return [_verbs.assemblies == _assemblies,
			"Ctrl-G and Ungroup edit the tree through its sub-assemblies (EditVerbs.assemblies is "
			+ "the shell's), the only way Builder.name_group is passed by: a window with no tree"]})

	print("\n6 and 7. the castle's copies have no steps of their own, so no looks of their own")
	var other: String = "south-west tower#1"
	var looks_then := func() -> Dictionary: return {"looks": _world.step_looks.duplicate(true)}
	await _edit(stepped, castle, true, "6/7. a tower taken apart by Ungroup",
		func() -> String:
			_select_assembly(other)
			_shell.run("leave_submodel")
			await _frames(2)
			return "ungrouped %s" % other,
		func(units: Dictionary) -> Array: return _carried(units, {other: null}), false,
		{"state": looks_then, "then": func(state: Dictionary) -> Array:
			var same: bool = JSON.stringify(state["looks"]) == JSON.stringify(_world.step_looks)
			var named: Array = _looks_by_name()
			return [same and bool(named[0]), "its steps' looks as they were (%s); %s" % [
				"the same" if same else "not", named[1]]]})

	# 7140-1: each sub-model built in steps of its own, as its author stepped it.
	var name: String = "7140-1 as its author stepped it"
	await _open(authored, name)
	var at: Dictionary = {}
	for path: String in _assemblies.paths():
		var kind: String = Assemblies.definition(Assemblies.leaf(path))
		for wanted: String in ["Upper Left Wing", "Ship", "Biggs Darklighter",
				"Support Vehicle Section 1", "Rear Engines"]:
			if kind.ends_with(wanted) and (wanted == "Rear Engines" or not at.has(wanted)):
				if wanted == "Rear Engines":
					if not at.has(wanted):
						at[wanted] = []
					(at[wanted] as Array).append(path)
				elif not (wanted == "Ship" and kind.ends_with("Ship Nose")):
					at[wanted] = path
	if not _check("7140-1: its upper left wing (%s), ship (%s), Biggs (%s), support section 1 "
			% [at.get("Upper Left Wing", "-"), at.get("Ship", "-"), at.get("Biggs Darklighter", "-")]
			+ "(%s) and rear engines (%d)" % [at.get("Support Vehicle Section 1", "-"),
			(at.get("Rear Engines", []) as Array).size()], at.size() == 5):
		return
	var wing: String = at["Upper Left Wing"]
	var ship: String = at["Ship"]

	print("\n3. 7140-1: a sub-assembly built in steps of its own dragged out of another")
	await _edit(name, authored, false, "3. the upper left wing dragged out of the ship onto the model",
		func() -> String: return _drag_row(wing, ""),
		func(units: Dictionary) -> Array: return _put_on_with(units, wing, Assemblies.leaf(wing),
			ship), false,
		{"touched": func() -> Array: return Array(_assemblies.ids_under(wing)), "order": true})

	print("\n4. 7140-1: some of a sub-assembly's parts taken out of it")
	var two := func() -> Array:
		var own: Array = Array(_assemblies.ids_under(wing)).filter(func(brick_id: int) -> bool:
			return Assemblies.path_of(_world.get_brick(brick_id)) == wing)
		var last: int = -1
		for brick_id: int in own:
			last = maxi(last, _world.get_brick(brick_id).step)
		# Its tip, the dish and the cone on the end of its bar: what is left
		# still holds together, so it is still built on the side.
		return own.filter(func(brick_id: int) -> bool:
			return _world.get_brick(brick_id).step == last).slice(-2)
	var aside := func() -> int:
		var count: int = 0
		for step: Instructions.Step in _plan():
			if step.in_callout() and step.assembly == Assemblies.definition(Assemblies.leaf(wing)):
				count += 1
		return count
	var put_on := func() -> Dictionary:
		return {"at": int(_world.unit_steps.get(wing, -1)), "ids": two.call(),
			"aside": aside.call()}
	await _edit(name, authored, false, "4. two parts of the upper left wing taken out of it by Ungroup",
		func() -> String: return await _take_out(wing, two.call()), _as_it_was, false,
		{"touched": two, "state": put_on, "then": func(state: Dictionary) -> Array:
			var wrong := PackedStringArray()
			for brick_id: int in state["ids"]:
				var brick: BrickWorld.Brick = _world.get_brick(brick_id)
				var home: String = AuthorSteps.home(_world, Assemblies.path_of(brick))
				if home != ship or brick.step != int(state["at"]):
					wrong.append("#%d in step %d of %s" % [brick_id, brick.step, home])
			var now: int = aside.call()
			return [wrong.is_empty() and now == int(state["aside"]), "taken out, they go on in "
				+ "the step of the ship that put the wing on (%d)%s" % [int(state["at"]),
				"" if wrong.is_empty() else ": " + ", ".join(wrong)]
				+ "; the wing built on the side in %d steps, %d before" % [now,
				int(state["aside"])]]})

	print("\n6. 7140-1: a sub-model given a name whose looks a sub-model taken apart left")
	var section: String = at["Support Vehicle Section 1"]
	var engines: Array = at["Rear Engines"]
	var called: String = Assemblies.definition(Assemblies.leaf(section))
	var renamed: Dictionary = {}
	for path: String in engines:
		renamed[path] = Assemblies.join(Assemblies.parent_of(path),
			"%s#%d" % [called, Assemblies.copy_of(Assemblies.leaf(path))])
	var engine: String = engines[0]
	await _edit(name, authored, false, "6. the rear engines renamed by their dialog as the section was",
		func() -> String:
			_select_assembly(engine)
			_shell.run("rename_assembly")
			await _frames(2)
			return _name_it(called),
		func(units: Dictionary) -> Array: return _carried(units, renamed), false,
		{"before": func() -> String:
			_select_assembly(section)
			_shell.run("leave_submodel")
			await _frames(2)
			return "took %s apart, %d of its looks left under its name" % [section,
				_world.step_looks.keys().filter(func(key: String) -> bool:
					return key.begins_with(called + "|")).size()],
		"state": func() -> Dictionary: return {"turns": _turns_of(engine)},
		"then": func(state: Dictionary) -> Array:
			var now: Array = _turns_of(str(renamed[engine]))
			return [now == state["turns"], "each of its steps seen as it was: %s / %s" % [
				str(state["turns"]), str(now)]]})

	print("\n7. 7140-1: a figure built in steps of its own taken apart")
	var biggs: String = at["Biggs Darklighter"]
	await _edit(name, authored, false, "7. Biggs taken apart by Ungroup",
		func() -> String:
			_select_assembly(biggs)
			_shell.run("leave_submodel")
			await _frames(2)
			return "ungrouped %s" % biggs,
		func(units: Dictionary) -> Array:
			var gone: Array = units.keys().filter(func(path: String) -> bool:
				return path != biggs and not _world.unit_steps.has(path))
			return [not _world.unit_steps.has(biggs) and gone.is_empty(),
				"its entry gone, every other copy's kept%s" % ("" if gone.is_empty()
				else ": not " + ", ".join(gone))], true,
		{"state": func() -> Dictionary:
			var ids: Array = Array(_assemblies.ids_under(biggs))
			return {"ids": ids, "views": await _views_of(ids)},
		"then": func(state: Dictionary) -> Array:
			var now: Array = await _views_of(state["ids"])
			return [now == state["views"], "its steps drawn from where they were, in degrees round: "
				+ "%s / %s" % [str(state["views"]), str(now)]]})


## The castle with a second north-east tower beside it, on the ground.
func _with_second_tower(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].strip_edges().ends_with(" north_east_tower.ldr"):
			lines.insert(n + 1, "1 16 1600 0 0 1 0 0 0 1 0 0 0 1 north_east_tower.ldr")
			break
	return "\n".join(lines)


## A part of [param path] not yet red.
func _not_red(path: String) -> int:
	for brick_id: int in _assemblies.ids_under(path):
		if _world.get_brick(brick_id).color_code != 4:
			return brick_id
	return 0


## [ok, words]: every copy's step as it was in [param units].
func _as_it_was(units: Dictionary) -> Array:
	return [_world.unit_steps == units, "each copy's step as it was%s" % (""
		if _world.unit_steps == units else ": " + _unlike(units, _world.unit_steps))]


## [ok, words]: no look is kept under a sub-model's name, as in a model
## every copy of which is built in its steps.
func _looks_by_name() -> Array:
	var named: Array = _world.step_looks.keys().filter(func(key: String) -> bool:
		return not key.get_slice("|", 0).is_empty())
	return [named.is_empty(), "the model's looks %d, %d of them under a sub-model's name%s" % [
		_world.step_looks.size(), named.size(), "" if named.is_empty()
		else ": " + ", ".join(named.slice(0, 3))]]


## The row of [param path] dragged onto [param into]'s in the model tree, as
## its drop does (Outliner._drop): what the status bar then says.
func _drag_row(path: String, into: String) -> String:
	var moved: String = _assemblies.move_into(path, into)
	_verbs.edited.call()
	return "%s is in %s now" % [Assemblies.label(moved), "the model" if into.is_empty()
		else Assemblies.label(into)]


## [param ids], parts of [param path], selected inside it and taken out of it
## by Ungroup.
func _take_out(path: String, ids: Array) -> String:
	_assemblies.enter(path)
	_select_only(ids)
	_shell.run("leave_submodel")
	await _frames(3)
	_assemblies.leave_to("")
	return "took %s out of %s by Ungroup" % [", ".join(ids.map(func(brick_id: int) -> String:
		return "#%d" % brick_id)), path]


## [ok, words]: the copy that was at [param was] goes on at [param now] in the
## step that puts [param with] on, where its parts were taken out to.
func _put_on_with(units: Dictionary, was: String, now: String, with: String) -> Array:
	var step: int = int(_world.unit_steps.get(now, -9))
	var wanted: int = int(units.get(with, -1))
	var wrong := PackedStringArray()
	if step != wanted:
		wrong.append("in step %d" % step)
	if _world.unit_steps.has(was):
		wrong.append("%s kept as well" % was)
	return [wrong.is_empty(), "%s goes on in the step %s goes on in (%d)%s" % [now, with, wanted,
		"" if wrong.is_empty() else ": " + ", ".join(wrong)]]


## The turn each step of the copy at [param path] is seen at, in order.
func _turns_of(path: String) -> Array:
	var out: Array = []
	for step: int in AuthorSteps.steps_in(_world, path, _store.scenery):
		var turn: Dictionary = BookletLooks.turn_at(_world, path, step)
		out.append(str(turn.get("turn", "-")))
	return out


## The way each step that puts any of [param ids] down is drawn from in the
## booklet as it lays out now (BookletMaker.lay_out_only), in whole degrees
## round from straight in front; "?" where no page has it.
func _views_of(ids: Array) -> Array:
	var wanted: Dictionary = {}
	for brick_id: Variant in ids:
		wanted[int(brick_id)] = true
	# By where each step is in the plan, which the booklet's entries keep
	# ("step"): a step puts on several callouts, each its own entry.
	var asked: Array = []
	var plan: Array[Instructions.Step] = _plan()
	for index: int in plan.size():
		for brick_id: int in plan[index].brick_ids:
			if wanted.has(brick_id):
				asked.append(index)
				break
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "Model")
	maker.queue_free()
	var from_of: Dictionary = {}
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			var shown: Array = [entry]
			if entry.callout != null:
				shown.append_array(entry.callout.steps)
			for one: Booklet.Entry in shown:
				if one.has_meta("step") and not from_of.has(int(one.get_meta("step"))):
					from_of[int(one.get_meta("step"))] = one.from
	var out: Array = []
	for index: int in asked:
		if not from_of.has(index):
			out.append("?")
			continue
		var from: Vector3 = from_of[index]
		out.append(roundi(rad_to_deg(atan2(from.x, from.z))))
	return out


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
## callout step 12 puts on. With [param place], by what and where each is
## ([method _key_of]).
func _numbers(place: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for step: Instructions.Step in _plan():
		for brick_id: int in step.brick_ids:
			out[brick_id] = ("%d.%d" % [step.number, step.callout_step]) if step.in_callout() \
				else str(step.number)
	return _keyed(out) if place else out


## A part by what it is and where, not its number, nor its colour: the
## copy that follows another is built again of new parts (Assemblies.realize).
func _key_of(brick_id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return "#%d" % brick_id
	var at: Transform3D = brick.transform
	var b: Basis = at.basis
	return "%s@%d,%d,%d/%d%d%d%d%d%d" % [brick.part_id, roundi(at.origin.x * 10.0),
		roundi(at.origin.y * 10.0), roundi(at.origin.z * 10.0), roundi(b.x.x), roundi(b.x.z),
		roundi(b.y.y), roundi(b.z.x), roundi(b.z.z), roundi(b.x.y)]


## [param by_id] (id -> anything) by [method _key_of].
func _keyed(by_id: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: Variant in by_id:
		out[_key_of(int(brick_id))] = by_id[brick_id]
	return out


## The build as the booklet orders it, by what each step adds: its parts'
## numbers, a step a line, whatever it is numbered. Without the parts
## [param leaving] out (id -> true), of [param from] (an order read before)
## when given.
func _order(leaving: Dictionary = {}, from: Variant = null) -> Array:
	var lines: Array = []
	if from == null:
		for step: Instructions.Step in _plan():
			var ids: Array = Array(step.brick_ids)
			ids.sort()
			lines.append(ids)
	else:
		for line: String in from:
			lines.append(Array(line.split(",", false)).map(func(id: String) -> int:
				return id.to_int()))
	var out: Array = []
	for ids: Array in lines:
		var kept: Array = ids.filter(func(id: int) -> bool: return not leaving.has(id))
		if kept.is_empty():
			continue
		out.append(",".join(kept.map(func(id: int) -> String: return str(id))))
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
			out.append(int(brick_id) if not (brick_id is String) else brick_id)
	out.sort()
	return out


static func _first(ids: Array, was: Dictionary, now: Dictionary, most: int = 4) -> String:
	if ids.is_empty():
		return ""
	var named := PackedStringArray()
	for one: Variant in ids.slice(0, most):
		named.append("%s %s->%s" % [("#%d" % one) if one is int else str(one),
			str(was.get(one, "?")), str(now.get(one, "?"))])
	return ": " + ", ".join(named) + (" ..." if ids.size() > most else "")


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
