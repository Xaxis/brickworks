## A step edit never costs a file its own text (keeptext).
##
##   godot --headless --path . --script src/dev/keep_text_probe.gd
##
## A model opened from someone else's file keeps the file (SourceFile), so
## a save writes back what nobody changed byte for byte: the author's name,
## the licence, the history, comments, LDCad's meta. Where SourceFile.write
## could not say a change in the file as it was, the model was written
## whole, and all of that went but the header and the parts. The first step
## edit of a model with no steps of its own gave it steps it could only say
## whole, and since stepskeep its copies built in its steps
## (AuthorSteps.IN_PARENT) could only be said whole too.
##
## Here real files with text of their own, each opened, given one step edit
## by the timeline's Shift-] and the same over MCP (edit_steps next), and
## saved as Save saves it:
## - 6780-1 from the LDraw model repository: its author, licence, history
##   and comments, stepped by its author;
## - 7140-1 as its author stepped it, four copies of its rear engines;
## - 10016-1, which has no steps of its own, two copies of its wheels;
## - 7755-1, no steps of its own, and four lines its notes say are mended;
## - 6650-1, LDCad's rope with its path, skin and generated lines;
## - 31037-1's helicopter, no steps of its own, an LDCad rope and two lights;
## - the castle (models/castle.ldr), the app's own, its copies built in its
##   steps after the edit, and a comment of its own: the app writes its own
##   files whole on every save, so of it every line of its own text, its
##   description, is kept, anywhere;
## - the castle as someone else's file with no steps of its own: its first
##   step edit builds its ten sub-models in the castle's steps.
## Each saved file has every line of the file the edit did not touch, byte
## for byte, in its section, and opens again to the same parts, steps and
## tree. Undone, the save is the file again; redone, the edit's; the
## autosave keeps it; the file saved and opened again saves to itself; and
## the reopened file given another step edit keeps its text too.
extends SceneTree

const MODELS: Array = [
	["6780-1 (author, licence, history, comments)", "res://vendor/omr/files/6780-1.mpd"],
	["7140-1 as its author stepped it", "res://vendor/omr/files/7140-1.mpd"],
	["10016-1, no steps of its own", "res://vendor/omr/files/10016-1.mpd"],
	["7755-1, no steps of its own, a correction noted", "res://vendor/omr/files/7755-1.mpd"],
	["6650-1, LDCad's rope", "res://vendor/omr/files/6650-1.mpd"],
	["31037-1's helicopter, no steps, LDCad's rope", "res://vendor/omr/files/31037-1_Helicopter.mpd"],
	["the castle", "res://models/castle.ldr"],
	["the castle as another's file with no steps", "res://models/castle.ldr", "another's"],
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
var _saves: int = 0
## What each file lost, for the summary: name -> [lines lost in its section,
## lines lost from the whole file, whole?].
var _summary: Array = []
## How many copies the file placed whole the step edit built in their
## parent's steps: the lines placing them are the edit's.
var _built_in: int = 0


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
	var only: String = OS.get_environment("KEEP_TEXT_ONLY")
	for model: Array in MODELS:
		if only.is_empty() or str(model[1]).contains(only) or str(model[0]).contains(only):
			await _model(str(model[0]), str(model[1]), model.size() > 2)
	print("\nlines lost by one step edit and a save:")
	for row: Array in _summary:
		print("  %-48s %4d in its section, %4d from the file, saved %s" % row)
	if _failures == 0:
		print("keep_text probe: all checks passed")
	else:
		print("keep_text probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _model(name: String, path: String, anothers: bool = false) -> void:
	print("\n%s" % name)
	var text: String = FileAccess.get_file_as_string(path)
	if anothers:
		text = _as_anothers(text)
	if not _check("%s read (%d lines)" % [path, text.split("\n").size()], not text.is_empty()):
		return
	await _open(text, name)
	var part: int = _chosen()
	if not _check("opened, %d parts; #%d (%s in %s) to go to the next step" % [
			_world.brick_count(), part, _world.get_brick(part).part_id if part > 0 else "-",
			_path_of(part)], part > 0):
		return
	var depth: int = _builder.history_depth()
	var by_menu: String = _shell.change_steps("next", [part], _step_holding(part))
	await _frames(4)
	var whole: bool = _store.call("_source_text", name) == null
	var edited: Dictionary = _state()
	var parented: int = _world.unit_steps.values().filter(func(step: int) -> bool:
		return step == AuthorSteps.IN_PARENT).size()
	_saves += 1
	var file_name: String = "keep text %d" % _saves
	_check("Shift-] on #%d (\"%s\"): %d copies built in the steps of the one placing them; "
		% [part, by_menu.get_slice("\n", 0).left(100), parented] + "saved as \"%s\"" % file_name,
		_builder.history_depth() > depth and _store.save_as(file_name)
		and (not anothers or parented >= 9))
	var saved: String = FileAccess.get_file_as_string(ModelStore.saved_path(file_name))
	# The lines placing the copies the edit built in their parent's steps
	# are the edit's: those copies are their parts there now.
	_built_in = 0 if _app_own(text) else parented
	var lost: Array = _text_lost(text, saved)
	var anywhere: Array = _text_lost(text, saved, false)
	_summary.append([name, lost.size(), anywhere.size(), "whole" if whole
		else "into the file"])
	_check("...saved %s: %d lines of the file lost or changed in their section, %d from the file "
		% ["whole" if whole else "into the file it was opened from", lost.size(), anywhere.size()]
		+ "(and %d placing copies now built in their parent's steps)%s"
		% [_lost(text, saved).size() - lost.size(), _first(lost)], lost.is_empty())
	await _reopened("...opened again", saved, name, edited)
	await _open(text, name)
	part = _chosen()

	# Undone, redone, and the same over MCP.
	var depth_now: int = _builder.history_depth()
	var said: String = await _say("edit_steps", {"op": "next", "bricks": [part]})
	await _frames(4)
	var by_mcp: String = _store.to_text(name, true)
	_check("edit_steps next on #%d (\"%s\"): saved, %d lines lost" % [part,
		said.get_slice("\n", 0).left(100), _text_lost(text, by_mcp).size()],
		_builder.history_depth() > depth_now and _text_lost(text, by_mcp).is_empty())
	_check("...the same file as by Shift-]", _same_file(by_mcp, saved))
	# The autosave, as the app writes it a few seconds after the edit.
	await _store._autosave_paced()
	var autosaved: String = FileAccess.get_file_as_string(ModelStore.autosave()) \
		if FileAccess.file_exists(ModelStore.autosave()) else ""
	_check("...autosaved: %d lines lost%s" % [_text_lost(text, autosaved).size(),
		_first(_text_lost(text, autosaved))], not autosaved.is_empty()
		and _text_lost(text, autosaved).is_empty())
	await _back_to(depth_now)
	var undone: String = _store.to_text(name, true)
	var back: Array = _lost(text, undone)
	var extra: Array = _lost(undone, text)
	_check("...undone: %d lines lost, %d not the file's%s" % [back.size(), extra.size(),
		_first(back + extra)], back.is_empty() and extra.is_empty())
	_builder.redo()
	await _frames(4)
	var redone: String = _store.to_text(name, true)
	_check("...redone: the edit's file again", _same_file(redone, by_mcp))

	# The saved file, opened again: it saves to itself, and keeps its text
	# through another step edit.
	await _open(saved, name)
	var again: String = _store.to_text(name, true)
	_check("...the saved file opened again saves to itself: %d lines lost, %d new" % [
		_lost(saved, again).size(), _lost(again, saved).size()],
		_lost(saved, again).is_empty() and _lost(again, saved).is_empty())
	var next: int = _chosen()
	if next > 0:
		var said_again: String = _shell.change_steps("next", [next], _step_holding(next))
		await _frames(4)
		var second: String = _store.to_text(name, true)
		var second_lost: Array = _text_lost(text, second)
		_check("...and given another step edit (\"%s\"): %d lines of the first file lost%s" % [
			said_again.get_slice("\n", 0).left(80), second_lost.size(), _first(second_lost)],
			second_lost.is_empty())
		var state: Dictionary = _state()
		await _reopened("...that opened again", second, name, state)


## [param text], the app's own file, as someone else's with no steps of its
## own: its first step edit builds its copies in the model's steps.
static func _as_anothers(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		var words: String = line.strip_edges().to_upper()
		if words == "0 STEP" or words.begins_with("0 ROTSTEP"):
			continue
		kept.append("0 Author: A. Builder [abuilder]" if line.strip_edges() == "0 Author: Brickworks"
			else line)
	return "\n".join(kept)


## [param saved] opened again: the same parts, steps and tree as [param was].
func _reopened(what: String, saved: String, name: String, was: Dictionary) -> void:
	await _open(saved, name)
	var now: Dictionary = _state()
	var parts: Array = _unlike(was["parts"], now["parts"])
	var units: Array = _unlike_dict(was["units"], now["units"])
	_check("%s: %d of %d parts not where they were, in another step or copy%s" % [what,
		parts.size(), (was["parts"] as Array).size(), (": " + ", ".join(parts.slice(0, 3)))
		if not parts.is_empty() else ""], parts.is_empty())
	_check("...the same tree, %d sub-models, each copy in its step%s" % [
		(now["tree"] as Array).size(), (": " + ", ".join(units.slice(0, 3)))
		if not units.is_empty() else ""], now["tree"] == was["tree"] and units.is_empty())


# -- the file ------------------------------------------------------------------


## The lines of [param was] that [param now] has not got, byte for byte, in
## the same FILE section ([param by_section]) or anywhere in it: each
## "section: line". A STEP line is the edit's to put in or take out. Of the
## app's own file, written whole on every save, its own text: every line
## that is not a part, a step or a line the app writes itself, anywhere.
static func _lost(was: String, now: String, by_section: bool = true) -> Array:
	if _app_own(was):
		by_section = false
	var have: Dictionary = {}
	for entry: Array in _lines_of(now):
		var key: String = (str(entry[0]) + "\n" if by_section else "") + str(entry[1])
		have[key] = int(have.get(key, 0)) + 1
	var out: Array = []
	for entry: Array in (_own_text(was) if _app_own(was) else _lines_of(was)):
		var key: String = (str(entry[0]) + "\n" if by_section else "") + str(entry[1])
		if int(have.get(key, 0)) > 0:
			have[key] = int(have[key]) - 1
		else:
			out.append("%s: %s" % [entry[0], str(entry[1]).strip_edges()])
	return out


## [section, line] for each line of [param text] but its STEP lines, the
## lines the app writes again on every save, and the file's last empty one.
static func _lines_of(text: String) -> Array:
	var out: Array = []
	var section: String = ""
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		var line: String = lines[n]
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			section = line.strip_edges().substr(7).to_lower()
		if words.size() == 2 and words[0] == "0" and words[1].to_upper() == "STEP":
			continue
		if line.begins_with("0 !BRICKWORKS "):
			continue
		if n == lines.size() - 1 and line.strip_edges().is_empty():
			continue
		out.append([section, line])
	return out


## [method _lost], but for as many lines placing a sub-model of the file as
## the edit built copies in their parent's steps ([member _built_in]).
func _text_lost(was: String, now: String, by_section: bool = true) -> Array:
	var out: Array = []
	var placing: int = 0
	var sections: Dictionary = {}
	for line: String in was.split("\n"):
		if line.strip_edges().to_upper().begins_with("0 FILE "):
			sections[line.strip_edges().substr(7).strip_edges().to_lower()] = true
	for entry: String in _lost(was, now, by_section):
		var words: PackedStringArray = entry.substr(entry.find(": ") + 2).split(" ", false)
		if placing < _built_in and words.size() >= 15 and words[0] == "1" \
				and sections.has(" ".join(words.slice(14)).to_lower()):
			placing += 1
			continue
		out.append(entry)
	return out


## Whether [param text] is a file the app wrote, which it writes whole.
static func _app_own(text: String) -> bool:
	return text.left(2000).contains("\n0 Author: Brickworks")


## The lines of the app's own file that are its own text: [section, line]
## for each that is not a part, a step, a FILE line, a section's title, its
## Name: or author, an empty line or one the app writes itself.
static func _own_text(text: String) -> Array:
	var out: Array = []
	var titled: bool = true
	for entry: Array in _lines_of(text):
		var line: String = str(entry[1]).strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.size() < 2 or words[0] != "0":
			continue
		var keyword: String = words[1].to_upper()
		if keyword == "FILE":
			titled = false
			continue
		if keyword in ["NOFILE", "STEP", "ROTSTEP", "NAME:"] or line == "0 Author: Brickworks":
			continue
		if not titled:
			titled = true
			continue
		out.append(["", entry[1]])
	return out


## Whether [param a] and [param b] are one file but for the lines the app
## writes on every save; of the app's own, one text of its own.
static func _same_file(a: String, b: String) -> bool:
	if _app_own(a):
		return _lost(a, b).is_empty() and _lost(b, a).is_empty()
	var lines_a: Array = _lines_of(a).map(func(entry: Array) -> String: return str(entry[1]))
	var lines_b: Array = _lines_of(b).map(func(entry: Array) -> String: return str(entry[1]))
	return lines_a == lines_b


static func _first(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return ": " + " | ".join(lines.slice(0, 4).map(func(line: String) -> String:
		return line.left(90))) + (" ..." if lines.size() > 4 else "")


# -- the model -----------------------------------------------------------------


## Every part, its colour, copy, place and step, and every copy's step and
## the tree: what a file opened again must give back.
func _state() -> Dictionary:
	var parts: Array = []
	var tree: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var t: Transform3D = brick.transform
		var place := PackedStringArray()
		for v: Vector3 in [t.origin / 10.0, t.basis.x, t.basis.y, t.basis.z]:
			for n: float in [v.x, v.y, v.z]:
				place.append("%.3f" % (snappedf(n, 0.001) + 0.0))
		var path: String = Assemblies.path_of(brick)
		parts.append("%s %d %s step %d at %s" % [brick.part_id, brick.color_code, path,
			brick.step, " ".join(place)])
		var at: String = ""
		for segment: String in Assemblies.segments(path):
			at = Assemblies.join(at, segment)
			tree[at] = true
	parts.sort()
	var paths: Array = tree.keys()
	paths.sort()
	var units: Dictionary = {}
	for unit: String in _world.unit_steps:
		if tree.has(unit):
			units[unit] = int(_world.unit_steps[unit])
	return {"parts": parts, "tree": paths, "units": units}


static func _unlike(a: Array, b: Array) -> Array:
	var have: Dictionary = {}
	for line: String in b:
		have[line] = int(have.get(line, 0)) + 1
	var out: Array = []
	for line: String in a:
		if int(have.get(line, 0)) > 0:
			have[line] = int(have[line]) - 1
		else:
			out.append(line)
	if out.is_empty() and a.size() != b.size():
		out.append("%d parts, %d before" % [b.size(), a.size()])
	return out


static func _unlike_dict(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in a:
		if not b.has(key) or int(b[key]) != int(a[key]):
			out.append("%s %s -> %s" % [str(key), str(a[key]), str(b.get(key, "none"))])
	for key: Variant in b:
		if not a.has(key):
			out.append("%s new %s" % [str(key), str(b[key])])
	return out


## A part to move to the next step: in a sub-model the model has two copies
## of or more, when it has one, else the model's own; in a middle step of
## the plan, with others in its step.
func _chosen() -> int:
	var copies: Dictionary = {}     ## definition -> how many copies
	for path: String in _shell.assemblies.paths():
		var named: String = Assemblies.definition(Assemblies.leaf(path))
		copies[named] = int(copies.get(named, 0)) + 1
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery,
		{}, true)
	var best: int = -1
	var plain: int = -1
	for index: int in range(steps.size() / 3, steps.size() - 1):
		var step: Instructions.Step = steps[index]
		if step.brick_ids.size() < 2:
			continue
		for brick_id: int in step.brick_ids:
			var path: String = _path_of(brick_id)
			if path.is_empty():
				if plain < 0:
					plain = brick_id
				continue
			if best < 0 and int(copies.get(Assemblies.definition(Assemblies.leaf(path)), 0)) >= 2:
				best = brick_id
		if best > 0:
			return best
	if plain > 0:
		return plain
	for index: int in range(steps.size() / 3, steps.size() - 1):
		if steps[index].brick_ids.size() >= 2:
			return steps[index].brick_ids[0]
	return -1


func _path_of(brick_id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return Assemblies.path_of(brick) if brick != null else ""


func _step_holding(brick_id: int) -> Instructions.Step:
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		if step.brick_ids.has(brick_id):
			return step
	return null


# -- the app -------------------------------------------------------------------


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
