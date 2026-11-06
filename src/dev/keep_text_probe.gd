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
##
## And the edits a person makes to a model's sub-models (keeptext2), each on
## each file, in the order a person meets them: a sub-model renamed by its
## dialog, a copy duplicated and put down, a copy made unique, a part added
## (in the second copy of a sub-model placed more than once, where there is
## one, else in its smallest sub-model), a
## copy taken off, a part taken out of one copy (the others follow), and a
## sub-assembly made of parts; and a part of a copy placed mirrored moved,
## which is still written whole, the file's own lines put back beside their
## parts (SourceFile.kept_in). Each saved, undone and opened again: the
## lines of the file's own text lost, but those the edit itself changes (a
## sub-model's title, the line placing a copy taken off or made unique, a
## part taken out) and those it moves (the parts of a sub-assembly made,
## into its section). Until keeptext2 each wrote the file whole. Also a file
## of its own (src/dev/fixtures/keep_text_notes.mpd) with a comment between
## every part, LDCad's and MLCad's meta, two copies of a wing and a fin
## placed mirrored.
##
##   KEEP_TEXT_ONLY=7140,6650   those files;  KEEP_TEXT_EDITS=rename,copy   those edits
##   KEEP_TEXT_STEPS=0     no step edits, only the edits above
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
	["notes between every part (a file of the probe's own)", "res://src/dev/fixtures/keep_text_notes.mpd"],
]

## The edits to a model's sub-models, in the order a person meets them.
const EDITS: Array = ["rename", "copy", "make unique", "add a part", "take off a copy",
	"take a part out of one copy", "make a sub-assembly", "move a part of a mirrored copy"]

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
## Each edit's lines lost, for the summary: [file, edit, lost saved, lost
## saved again, lost undone, "whole"/"into the file"].
var _edit_summary: Array = []


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
	var steps: bool = OS.get_environment("KEEP_TEXT_STEPS") != "0"
	var edits: Array = EDITS if OS.get_environment("KEEP_TEXT_EDITS").is_empty() \
		else Array(OS.get_environment("KEEP_TEXT_EDITS").split(","))
	for model: Array in MODELS:
		var wanted: bool = only.is_empty()
		for word: String in only.split(",", false):
			wanted = wanted or str(model[1]).contains(word) or str(model[0]).contains(word)
		if wanted:
			if steps:
				await _model(str(model[0]), str(model[1]), model.size() > 2)
			await _edits(str(model[0]), str(model[1]), model.size() > 2, edits)
	print("\nlines lost by one step edit and a save:")
	for row: Array in _summary:
		print("  %-48s %4d in its section, %4d from the file, saved %s" % row)
	print("\nlines of the file's own text lost by each edit: saved (in its section, "
		+ "anywhere), saved again once opened, undone")
	for row: Array in _edit_summary:
		print("  %-36s %-28s %4d %4d %4d %4d  %s" % row)
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
## [param loose]: a part or copy put in no step (pasted) may come back in
## the step a save put it in.
func _reopened(what: String, saved: String, name: String, was: Dictionary,
		loose: bool = false) -> void:
	await _open(saved, name)
	var now: Dictionary = _state()
	var parts: Array = _unlike(was["parts"], now["parts"], loose)
	var units: Array = _unlike_dict(was["units"], now["units"], loose)
	_check("%s: %d of %d parts not where they were, in another step or copy%s" % [what,
		parts.size(), (was["parts"] as Array).size(), (": " + ", ".join(parts.slice(0, 3)))
		if not parts.is_empty() else ""], parts.is_empty())
	_check("...the same tree, %d sub-models, each copy in its step%s" % [
		(now["tree"] as Array).size(), (": " + ", ".join(units.slice(0, 3)))
		if not units.is_empty() else ""], now["tree"] == was["tree"] and units.is_empty())


# -- the edits to its sub-models --------------------------------------------------


## [param edits] of [constant EDITS], each on the file at [param path] opened
## afresh.
func _edits(name: String, path: String, anothers: bool, edits: Array) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if anothers:
		text = _as_anothers(text)
	_built_in = 0
	print("\n%s, its sub-models edited" % name)
	for edit: String in EDITS:
		if edits.has(edit):
			await _edit(name, text, edit)


## [param text] opened, given [param edit] as a person gives it, saved; the
## lines of the file's own text lost, but those the edit changes; undone,
## the file again; opened again, the same model, and saved again, itself.
func _edit(name: String, text: String, edit: String) -> void:
	await _open(text, name)
	var depth: int = _builder.history_depth()
	var done: Dictionary = await _do(edit, text)
	await _frames(6)
	_shell.assemblies.leave_to("")
	if done.has("skip"):
		print("  --    %s: %s" % [edit, done["skip"]])
		return
	var said: String = str(done["said"])
	if not _check("%s: %s" % [edit, said.get_slice("\n", 0).left(110)],
			_builder.history_depth() > depth and bool(done.get("ok", true))):
		_edit_summary.append([_short(name), edit, -1, -1, -1, -1, "not made"])
		return
	var whole: bool = _store.call("_source_text", name) == null
	var why: String = "" if not whole else SourceFile.why_whole \
		if _store.get("_source") != null else "the app's own file"
	var edited: Dictionary = _state()
	_saves += 1
	var file_name: String = "keep edit %d" % _saves
	var saved_ok: bool = _store.save_as(file_name)
	var saved: String = FileAccess.get_file_as_string(ModelStore.saved_path(file_name))
	var allowed: Array = done.get("lines", [])
	var moving: Array = done.get("moving", [])
	var lost: Array = _edit_lost(text, saved, allowed, moving)
	# Written whole, someone else's file keeps its comments, notes and meta
	# lines beside their parts (SourceFile.kept_in); its parts' and FILE
	# lines are the app's.
	var carried: bool = whole and _store.get("_source") != null
	var notes: Array = _edit_lost(text, saved, allowed, moving, false).filter(_is_note)
	_check("...saved %s: %d lines of the file's own text lost (%d the edit's)%s%s" % [
		"whole (%s)" % why if whole else "into the file", lost.size(),
		allowed.size() + moving.size(),
		", %d of its comments, notes and meta" % notes.size() if carried else "",
		_first(notes if carried else lost)],
		saved_ok and (notes.is_empty() if carried else lost.is_empty()))
	await _back_to(depth)
	var undone: String = _store.to_text(name, true)
	var back: Array = _lost(text, undone)
	var extra: Array = _lost(undone, text)
	_check("...undone: %d lines lost, %d not the file's%s" % [back.size(), extra.size(),
		_first(back + extra)], back.is_empty() and extra.is_empty())
	await _reopened("...opened again", saved, name, edited, true)
	var again: String = _store.to_text(name, true)
	var lost_again: Array = _edit_lost(text, again, allowed, moving)
	var notes_again: Array = _edit_lost(text, again, allowed, moving, false).filter(_is_note)
	var drift: int = _lost(saved, again).size() + _lost(again, saved).size()
	_check("...and saved again: %d lines of the file's own text lost, %d of the saved file's "
		% [lost_again.size(), drift] + "changed%s" % _first(
			(notes_again if carried else lost_again) + _lost(saved, again)),
		(notes_again.is_empty() if carried else lost_again.is_empty()) and drift == 0)
	_edit_summary.append([_short(name), edit, lost.size(),
		_edit_lost(text, saved, allowed, moving, false).size(), lost_again.size(),
		back.size() + extra.size(), "into the file" if not whole else "whole: " + why
			+ (", %d comments, notes, meta" % notes.size() if carried else "")])


## [method _lost] but for the lines the edit itself changes ([param allowed],
## "section: line" as [method _lost] says them) and those it moves to another
## section ([param moving], each a line's text), which must be in the file
## still, somewhere.
func _edit_lost(was: String, now: String, allowed: Array, moving: Array,
		by_section: bool = true) -> Array:
	var out: Array = _text_lost(was, now, by_section)
	for entry: String in allowed:
		out.erase(entry)
	var anywhere: Array = _lost(was, now, false)
	for line: String in moving:
		for entry: String in out:
			if entry.ends_with(": " + line):
				out.erase(entry)
				break
		for entry: String in anywhere:
			if entry.ends_with(": " + line):
				out.append("moved and gone: " + line)
				anywhere.erase(entry)
				break
	return out


## Whether [param entry] ("section: line", as [method _lost] says it) is a
## comment, a note or a meta line of the file's own: not a part's or a
## sub-model's line, not its FILE, NOFILE or Name line, not empty.
static func _is_note(entry: String) -> bool:
	var line: String = entry.substr(entry.find(": ") + 2).strip_edges()
	var words: PackedStringArray = line.split(" ", false)
	if words.is_empty() or words[0] != "0":
		return false
	return words.size() < 2 or not words[1].to_upper() in ["FILE", "NOFILE", "NAME:"]


static func _short(name: String) -> String:
	return name.get_slice(" (", 0).get_slice(",", 0).get_slice(" with ", 0).left(36)


## [param edit] given the model as a person gives it: {"said": what the app
## said, "lines": the lines of [param text] it changes ("section: line"),
## "moving": those it puts in another section}, or {"skip": why} when the
## model has nothing it applies to.
func _do(edit: String, text: String) -> Dictionary:
	var assemblies: Assemblies = _shell.assemblies
	var verbs: EditVerbs = _main.get("_verbs")
	var twice: Array = _placed_twice()
	match edit:
		"rename":
			var path: String = twice[1] if not twice.is_empty() else _smallest()
			if path.is_empty():
				return {"skip": "no sub-model"}
			var kind: String = Assemblies.definition(Assemblies.leaf(path))
			_select_assembly(path)
			_shell.run("rename_assembly")
			await _frames(2)
			return {"said": "%s: %s" % [path, _name_it("Renamed " + kind)],
				"lines": _title_of(text, kind)}
		"copy":
			var path: String = _smallest()
			if path.is_empty():
				return {"skip": "no sub-model"}
			_select_assembly(path)
			verbs.duplicate_selection(false)
			var put: int = await _put_down()
			# Another copy of it, beside it in the one it is in.
			var copy: String = _path_of(put)
			return {"said": "%s duplicated and put down (#%d, %s)" % [path, put, copy],
				"ok": put > 0 and copy != path
					and Assemblies.parent_of(copy) == Assemblies.parent_of(path)
					and Assemblies.definition(Assemblies.leaf(copy)) \
						== Assemblies.definition(Assemblies.leaf(path))}
		"make unique":
			if twice.is_empty():
				return {"skip": "no sub-model placed more than once"}
			var path: String = twice[1]
			var placing: Array = _placing(text, path)
			_select_assembly(path)
			_shell.run("make_unique")
			await _frames(2)
			return {"said": "made %s unique" % path, "lines": placing}
		"add a part":
			# Its second copy: a part moved or duplicated in one went into
			# the first, or into a new copy of the outermost, until
			# Carry.placements gave each its copy (keeptext2).
			var into: String = twice[1] if not twice.is_empty() else _smallest()
			var part: int = _part_in(into)
			if part <= 0:
				return {"skip": "no part in %s" % (into if not into.is_empty() else "the model")}
			if not into.is_empty():
				assemblies.enter(into)
			_select_only([part])
			verbs.duplicate_selection(false)
			var put: int = await _put_down(true)
			return {"said": "a %s added in %s (#%d, in %s)" % [_world.get_brick(part).part_id,
				into if not into.is_empty() else "the model", put, _path_of(put)],
				"ok": put > 0 and _path_of(put) == into}
		"take off a copy":
			if twice.is_empty():
				return {"skip": "no sub-model placed more than once"}
			var path: String = twice[1]
			var placing: Array = _placing(text, path)
			_select_assembly(path)
			_shell.run("delete")
			await _frames(2)
			return {"said": "took %s off" % path, "lines": placing}
		"take a part out of one copy":
			if twice.is_empty():
				return {"skip": "no sub-model placed more than once"}
			var path: String = twice[0]
			var part: int = _part_in(path)
			if part <= 0:
				return {"skip": "no part of its own in %s" % path}
			var line: Array = _lines_of_parts(text, [part])
			assemblies.enter(path)
			_select_only([part])
			_shell.run("delete")
			await _frames(2)
			return {"said": "took a %s out of %s" % [line[0] if not line.is_empty() else "?", path],
				"lines": line.map(func(entry: String) -> String: return entry), "removed": true}
		"make a sub-assembly":
			var level: String = ""
			var parts: Array = _parts_at("", 3)
			if parts.size() < 3:
				level = _biggest_once()
				parts = _parts_at(level, 3)
			if parts.size() < 2:
				return {"skip": "no parts to make one of"}
			var moving: Array = []
			for entry: String in _lines_of_parts(text, parts):
				moving.append(entry.substr(entry.find(": ") + 2))
			if not level.is_empty():
				assemblies.enter(level)
			_select_only(parts)
			_shell.run("make_submodel")
			await _frames(2)
			return {"said": "%d parts of %s: %s" % [parts.size(),
				level if not level.is_empty() else "the model", _name_it("Made Here")],
				"moving": moving}
		"move a part of a mirrored copy":
			# Written whole still (SourceFile.why_whole): its own lines kept
			# beside their parts all the same (SourceFile.kept_in).
			var path: String = _mirrored_copy()
			if path.is_empty():
				return {"skip": "no copy placed mirrored"}
			var part: int = _part_in(path)
			if part <= 0:
				return {"skip": "no part of its own in %s" % path}
			var line: Array = _lines_of_parts(text, [part])
			assemblies.enter(path)
			_select_only([part])
			var moved: int = 0
			for by: Vector3i in [Vector3i(0, 0, 4), Vector3i(0, 0, -4), Vector3i(4, 0, 0),
					Vector3i(-4, 0, 0), Vector3i(0, 8, 0), Vector3i(0, -8, 0)]:
				moved = _builder.move_selection(by)
				if moved > 0:
					break
			await _frames(2)
			return {"said": "moved a %s in %s" % [_world.get_brick(part).part_id, path],
				"ok": moved > 0, "lines": line}
	return {"skip": "no such edit"}


## The first copy the file places by a reference that mirrors it, or "".
func _mirrored_copy() -> String:
	var source: SourceFile = _store.get("_source")
	if source == null:
		return ""
	var units: Array = source.unit_frames.keys()
	units.sort()
	for unit: String in units:
		if (source.unit_frames[unit] as Transform3D).basis.determinant() < 0.0:
			return unit
	return ""


## The copies of the first sub-model, by name, the model places more than
## once (its first two), or [] for none.
func _placed_twice() -> Array:
	var by_kind: Dictionary = {}
	for path: String in _shell.assemblies.paths():
		var kind: String = Assemblies.definition(Assemblies.leaf(path))
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(path)
	var kinds: Array = by_kind.keys()
	kinds.sort()
	for kind: String in kinds:
		var paths: Array = by_kind[kind]
		if paths.size() >= 2 and _parts_at(paths[0], 1).size() > 0:
			paths.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
			return paths.slice(0, 2)
	return []


## The sub-model copy with the fewest parts, of those with a part of their own.
func _smallest() -> String:
	var best: String = ""
	var fewest: int = 1 << 30
	for path: String in _shell.assemblies.paths():
		var count: int = _shell.assemblies.ids_under(path).size()
		if count > 0 and count < fewest and _parts_at(path, 1).size() > 0:
			fewest = count
			best = path
	return best


## The sub-model copy with the most parts of its own that the model places
## once, of the model's own (not a figure's).
func _biggest_once() -> String:
	var best: String = ""
	var most: int = 0
	for path: String in _shell.assemblies.paths():
		if not _shell.assemblies.copies_of(path).is_empty():
			continue
		var count: int = _parts_at(path, 100000).size()
		if count > most:
			most = count
			best = path
	return best


## Up to [param most] parts of the copy at [param level] (the model's own
## for "") of its own, in a middle step of the plan, one after another.
func _parts_at(level: String, most: int) -> Array:
	var own: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		for brick_id: int in step.brick_ids:
			if _path_of(brick_id) == level:
				own.append(brick_id)
	if own.size() <= most:
		return own
	var from: int = (own.size() - most) / 2
	return own.slice(from, from + most)


func _part_in(level: String) -> int:
	var parts: Array = _parts_at(level, 1)
	return int(parts[0]) if not parts.is_empty() else -1


## What is in hand put down clear of the model, as a move typed in puts it
## (Carry.show_moved): beside it for a copy of a sub-model ([param up]
## false), above it for a part. The first part put down, or 0.
func _put_down(up: bool = false) -> int:
	var carry: Carry = _builder.carrying
	var low := Vector3(INF, INF, INF)
	var high := -low
	for brick: BrickWorld.Brick in _world.bricks():
		low = low.min(brick.transform.origin)
		high = high.max(brick.transform.origin)
	var room: float = 4.0 * BrickLattice.STUD
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	for k: int in 6:
		var by: Vector3 = Vector3(0.0, high.y - low.y + room * (k + 1), 0.0) if up \
			else Vector3(high.x - low.x + room * (k + 1), 0.0, 0.0)
		if carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
			var put: int = _builder.place()
			await _frames(4)
			_builder.cancel_carry()
			return put
	_builder.cancel_carry()
	return 0


func _select_assembly(path: String) -> void:
	_shell.assemblies.leave_to(Assemblies.parent_of(path))
	_select_only(Array(_shell.assemblies.ids_under(path)))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


## The naming dialog the command opened, [param name] typed in it and OK
## pressed. What the status bar then says.
func _name_it(name: String) -> String:
	var verbs: EditVerbs = _main.get("_verbs")
	var field: LineEdit = verbs.get("_name_field")
	var dialog: ConfirmationDialog = verbs.get("_naming")
	if field == null or dialog == null or not dialog.visible:
		return "no naming dialog"
	field.text = name
	dialog.hide()
	dialog.confirmed.emit()
	return "named %s" % name


## The title line of the sub-model [param kind] in [param text], as
## [method _lost] says a line: what a rename changes.
static func _title_of(text: String, kind: String) -> Array:
	var section: String = ""
	var titled: bool = true
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		var words: PackedStringArray = line.split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			section = line.substr(7).to_lower()
			titled = false
			continue
		if titled or words.size() < 2 or words[0] != "0":
			if words.size() >= 15 and words[0] == "1":
				titled = true
			continue
		var keyword: String = words[1].to_upper()
		if keyword.begins_with("!") or keyword in ["BFC", "NAME:", "AUTHOR:", "STEP"] \
				or words[1].begins_with("//"):
			continue
		titled = true
		if " ".join(words.slice(1)) == kind:
			return ["%s: %s" % [section, line]]
	return []


## The line placing the copy at [param path], as [method _lost] says it:
## what taking the copy off or making it unique changes.
func _placing(text: String, path: String) -> Array:
	var source: SourceFile = _store.get("_source")
	if source == null or not source.unit_lines.has(path):
		return []
	return [_said_line(text, int(source.unit_lines[path]))]


## The lines of [param text] the parts [param ids] were read from, as
## [method _lost] says them.
func _lines_of_parts(text: String, ids: Array) -> Array:
	var source: SourceFile = _store.get("_source")
	if source == null:
		return []
	var lift: Vector3 = _store.lift()
	var out: Array = []
	var used: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var at: Vector3 = brick.transform.origin - lift
		# The nearest line of its part in its copy: a part opened on the
		# lattice stands a little off where its line says.
		var best: int = -1
		var nearest: float = INF
		for line: int in source.by_line:
			if used.has(line):
				continue
			for origin: SourceFile.Read in source.by_line[line]:
				if origin.unit == Assemblies.path_of(brick) and origin.part_id == brick.part_id \
						and origin.colour == brick.color_code \
						and origin.at.origin.distance_to(at) < nearest:
					nearest = origin.at.origin.distance_to(at)
					best = line
		if best >= 0:
			used[best] = true
			out.append(_said_line(text, best))
	return out


## Line [param n] of [param text] as [method _lost] says it.
static func _said_line(text: String, n: int) -> String:
	var lines: PackedStringArray = text.split("\n")
	var section: String = ""
	for k: int in range(n, -1, -1):
		var words: PackedStringArray = lines[k].strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			section = lines[k].strip_edges().substr(7).to_lower()
			break
	return "%s: %s" % [section, lines[n].strip_edges()]


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


static func _unlike(a: Array, b: Array, loose: bool = false) -> Array:
	var have: Dictionary = {}
	for line: String in b:
		have[line] = int(have.get(line, 0)) + 1
	var out: Array = []
	for line: String in a:
		if int(have.get(line, 0)) > 0:
			have[line] = int(have[line]) - 1
		else:
			out.append(line)
	if loose and not out.is_empty():
		# A part in no step, in any step.
		var stepless: RegEx = RegEx.create_from_string(" step -?\\d+ ")
		var left: Dictionary = {}
		for line: String in have:
			for _n: int in int(have[line]):
				var key: String = stepless.sub(line, " step ? ")
				left[key] = int(left.get(key, 0)) + 1
		var still: Array = []
		for line: String in out:
			var key: String = stepless.sub(line, " step ? ")
			if line.contains(" step -1 ") and int(left.get(key, 0)) > 0:
				left[key] = int(left[key]) - 1
			else:
				still.append(line)
		out = still
	if out.is_empty() and a.size() != b.size():
		out.append("%d parts, %d before" % [b.size(), a.size()])
	return out


static func _unlike_dict(a: Dictionary, b: Dictionary, loose: bool = false) -> Array:
	var out: Array = []
	for key: Variant in a:
		if loose and int(a[key]) == -1 and not b.has(key):
			continue
		if not b.has(key) or int(b[key]) != int(a[key]):
			out.append("%s %s -> %s" % [str(key), str(a[key]), str(b.get(key, "none"))])
	for key: Variant in b:
		if loose:
			continue
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
