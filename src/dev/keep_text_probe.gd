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
## And after every edit, save, reopen and undo, the model the saved file
## opens as has every part of the model before the edit, in place and in
## colour, the parts the app cannot show among them (not in the library, a
## hose's skin), plus the edit's own change and nothing else: counted
## lines could not see a part whose line stayed in the file placed by
## nothing (keeptext3). A line that says what the next is (LDCad's and
## MLCad's groups, MLCad's hidden part, BFC INVERTNEXT) is still right above
## the line it said it of; a file in CRLF is in CRLF still; its header and
## the lines before its first FILE line are where they were. Each of the
## review's findings is a file here (src/dev/fixtures/kt_*): one with a
## part no library has, a header line again in its body, a sub-model of one
## part with notes, tabs, lines before the first FILE line, CRLF, and every
## kind of line that says what the next is (kt_runs.mpd).
##
## And a saved model (the gatehouse) put down in each by File, Import, Into
## this model… over MCP (intomodel): saved, opened again and undone, the
## file's parts and the gatehouse's 14, and nothing else. And the lines the
## app keeps of its own (its floor, hidden colours, cut-away, motions, pins,
## the link it is shared at, the sets in its bin, a picture to trace, the set
## it is), each written into the CRLF file by its writer, then all of them,
## opened, saved and opened again: every line in CRLF and each read again
## (SourceFile.lines_put; each writer had put its line in with "\n" alone).
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
	# The review's (ktreview), each a file that lost a part or a line once.
	["the castle with a part no library has, no steps", "res://src/dev/fixtures/kt_castle_unshown.ldr"],
	["a cabin with a part no library has", "res://src/dev/fixtures/kt_unshown.mpd"],
	["a header line again in the body", "res://src/dev/fixtures/kt_hdrdup.mpd"],
	["a one-part mirrored sub-model with notes", "res://src/dev/fixtures/kt_onepart.mpd"],
	["tabs between the fields", "res://src/dev/fixtures/kt_tabs.mpd"],
	["lines before the first FILE", "res://src/dev/fixtures/kt_lead.mpd"],
	["CRLF line endings", "res://src/dev/fixtures/kt_crlf.mpd"],
	["lines that say what the next is, no steps", "res://src/dev/fixtures/kt_runs.mpd"],
	["names in another case, Unicode", "res://src/dev/fixtures/kt_names.mpd"],
	["no NOFILE, no last line break", "res://src/dev/fixtures/kt_nonl.mpd"],
]

## The edits to a model's sub-models, in the order a person meets them.
const EDITS: Array = ["rename", "copy", "make unique", "add a part", "take off a copy",
	"take a part out of one copy", "make a sub-assembly", "move a part of a mirrored copy",
	"put a saved model in"]

## The saved model put in each (intomodel_probe's): five sub-models in five
## steps, 14 parts.
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const CRLF_FILE := "res://src/dev/fixtures/kt_crlf.mpd"
## The lines the app keeps of its own in a model's text, each by its writer.
const META_KINDS: Array = ["floor", "hidden colours", "cut-away", "motions", "pins",
	"shared link", "sets in its bin", "picture to trace", "set"]
const HIDDEN := {"mode": "sections", "groups": [{"label": "Base", "colour": 4, "also": [],
	"sections": ["notes.ldr"]}]}
const CUT := {"shape": "box", "from": [-80, -100, -40], "to": [0, 10, 40], "ghosts": false}
const MOTION := ['0 !BRICKWORKS MOTION "Turn the brick" AFTER "" SECONDS 2',
	'0 !BRICKWORKS MOTION_TRACK "Turn the brick" 1 TURN AT 0 JOINT PART 3004 14 0 -48 0',
	'0 !BRICKWORKS MOTION_KEY "Turn the brick" 1 0 0 EASE',
	'0 !BRICKWORKS MOTION_KEY "Turn the brick" 1 2 90 EASE']
const SHARE := "kt3CrLfAbc"

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
	# The gatehouse, saved: one of the person's own models, to put in.
	var gatehouse: String = ModelStore.saved_path("Gatehouse")
	DirAccess.make_dir_recursive_absolute(gatehouse.get_base_dir())
	var file := FileAccess.open(gatehouse, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(GATEHOUSE))
	file.close()
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
	if only.is_empty() or only.contains("crlf") or only.contains("metas"):
		await _metas_crlf()
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
	# Every part the file opens as, the parts the app cannot show among them:
	# a step edit changes none of them.
	var parts: Array = _parts_of(text)
	var part: int = _chosen()
	if not _check("opened, %d parts (%d of the file's %d the app cannot show); #%d (%s in %s) "
			% [_world.brick_count(), _unshown_count(parts), parts.size(), part,
				_world.get_brick(part).part_id if part > 0 else "-", _path_of(part)]
			+ "to go to the next step", part > 0):
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
	_same_parts("...saved", parts, saved)
	_shape_kept("...saved", text, saved)
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
	_same_parts("...by MCP", parts, by_mcp)
	# The autosave, as the app writes it a few seconds after the edit.
	await _store._autosave_paced()
	var autosaved: String = FileAccess.get_file_as_string(ModelStore.autosave()) \
		if FileAccess.file_exists(ModelStore.autosave()) else ""
	_check("...autosaved: %d lines lost%s" % [_text_lost(text, autosaved).size(),
		_first(_text_lost(text, autosaved))], not autosaved.is_empty()
		and _text_lost(text, autosaved).is_empty())
	_same_parts("...autosaved", parts, autosaved)
	await _back_to(depth_now)
	var undone: String = _store.to_text(name, true)
	var back: Array = _lost(text, undone)
	var extra: Array = _lost(undone, text)
	_check("...undone: %d lines lost, %d not the file's%s" % [back.size(), extra.size(),
		_first(back + extra)], back.is_empty() and extra.is_empty())
	_same_parts("...undone", parts, undone)
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
	_same_parts("...saved again", parts, again)
	var next: int = _chosen()
	if next > 0:
		var said_again: String = _shell.change_steps("next", [next], _step_holding(next))
		await _frames(4)
		var second: String = _store.to_text(name, true)
		var second_lost: Array = _text_lost(text, second)
		_check("...and given another step edit (\"%s\"): %d lines of the first file lost%s" % [
			said_again.get_slice("\n", 0).left(80), second_lost.size(), _first(second_lost)],
			second_lost.is_empty())
		_same_parts("...after another step edit", parts, second)
		_shape_kept("...after another step edit", text, second)
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
	var parts: Array = _parts_of(text)
	var was: Dictionary = _world_parts()
	var done: Dictionary = await _do(edit, text)
	await _frames(6)
	_shell.assemblies.leave_to("")
	if done.has("skip"):
		print("  --    %s: %s" % [edit, done["skip"]])
		return
	# The model as the edit leaves it: the file's parts, but those the edit
	# took or moved, and those it put down.
	var expected: Array = _after_edit(parts, was, _world_parts(), done)
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
	var allowed: Array = _with_runs(text, done.get("lines", []))
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
	_same_parts("...saved", expected, saved)
	_shape_kept("...saved", text, saved)
	await _back_to(depth)
	var undone: String = _store.to_text(name, true)
	var back: Array = _lost(text, undone)
	var extra: Array = _lost(undone, text)
	_check("...undone: %d lines lost, %d not the file's%s" % [back.size(), extra.size(),
		_first(back + extra)], back.is_empty() and extra.is_empty())
	_same_parts("...undone", parts, undone)
	await _reopened("...opened again", saved, name, edited, true)
	var again: String = _store.to_text(name, true)
	_same_parts("...saved again", expected, again)
	_shape_kept("...saved again", text, again)
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


## [param entries] ("section: line", as [method _lost] says them), the lines
## an edit takes out or moves, and the lines right above each in
## [param text] that say what it is for another program ([method _binds]):
## they go where it goes.
static func _with_runs(text: String, entries: Array) -> Array:
	var out: Array = entries.duplicate()
	var wanted: Dictionary = {}
	for entry: Variant in entries:
		wanted[str(entry)] = int(wanted.get(str(entry), 0)) + 1
	var lines: Array = _lines_of(text)
	for n: int in lines.size():
		var entry: String = "%s: %s" % [lines[n][0], str(lines[n][1]).strip_edges()]
		if int(wanted.get(entry, 0)) <= 0:
			continue
		wanted[entry] = int(wanted[entry]) - 1
		var k: int = n - 1
		while k >= 0 and lines[k][0] == lines[n][0] and _binds(str(lines[k][1])):
			out.append("%s: %s" % [lines[k][0], str(lines[k][1]).strip_edges()])
			k -= 1
	return out


## Whether [param entry] ("section: line", as [method _lost] says it) is a
## comment, a note or a meta line of the file's own: not a part's or a
## sub-model's line, not its FILE, NOFILE or Name line, not empty.
static func _is_note(entry: String) -> bool:
	var line: String = entry.substr(entry.find(": ") + 2).strip_edges()
	var words: PackedStringArray = LdrModel._fields(line)
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
				"copied": [path, copy], "ok": put > 0 and copy != path
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
			return {"said": "took %s off" % path, "lines": placing, "taken": path}
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
			# Each with the lines saying what it is, which go with it.
			var moving: Array = []
			for entry: String in _with_runs(text, _lines_of_parts(text, parts)):
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
		"put a saved model in":
			# File, Import, Into this model… over MCP (intomodel): a saved
			# model put down in this one as a sub-assembly, with its steps.
			var said: String = await _say("open_model", {"into": true, "name": "Gatehouse"})
			await _frames(4)
			return {"said": said, "ok": said.begins_with("Put Gatehouse in the model")}
	return {"skip": "no such edit"}


# -- the app's own lines in a file in CRLF -------------------------------------------


## The lines the app keeps of its own in a model's text ([constant META_KINDS])
## written into a file in CRLF, each by its writer: each line in CRLF as the
## file's are, and read again. Each writer put its line in with "\n" alone; a
## save made the file CRLF again after the floor, hidden colours, cut-away,
## motions and pins (SourceFile.ended), but not after the link it is shared
## at, the sets in its bin and the picture to trace (ModelStore._write). Then
## the file with all of them opened, saved, opened again and saved again: in
## CRLF, every line, and each of them kept.
func _metas_crlf() -> void:
	print("\nthe app's own lines written into a file in CRLF")
	var text: String = FileAccess.get_file_as_string(CRLF_FILE)
	await _open(text, "CRLF metas")
	var part: int = _chosen()
	var pins := PinnedComments.new()
	pins.add(part, "the author's favourite", "probe", "", _world, _store.lift())
	var pin_lines: PackedStringArray = pins.lines(_world, _store.lift())
	var all: String = text
	for kind: String in META_KINDS:
		var one: String = _meta_written(kind, text, pin_lines)
		_check("%s written into it by itself: %d lines ending otherwise than the file's, read "
			% [kind, _endings_wrong(text, one)] + "again: %s" % _meta_read(kind, one),
			one != text and _endings_wrong(text, one) == 0 and _meta_read(kind, one))
		all = _meta_written(kind, all, pin_lines)
	var none: Array = META_KINDS.filter(func(kind: String) -> bool:
		return not _meta_read(kind, all))
	_check("all of them, one after another: %d lines ending otherwise, %d not read again%s"
		% [_endings_wrong(text, all), none.size(), _first(none)],
		_endings_wrong(text, all) == 0 and none.is_empty())
	var parts: Array = _parts_of(text)
	_same_parts("...with all of them", parts, all)
	_shape_kept("...with all of them", text, all)
	# As the app keeps them: opened, saved as Save saves it, opened again.
	await _open(all, "CRLF metas")
	_saves += 1
	var file_name: String = "keep metas %d" % _saves
	var saved_ok: bool = _store.save_as(file_name)
	var saved: String = FileAccess.get_file_as_string(ModelStore.saved_path(file_name))
	none = META_KINDS.filter(func(kind: String) -> bool: return not _meta_read(kind, saved))
	_check("opened and saved: %d lines ending otherwise than the file's, %d of them not kept%s"
		% [_endings_wrong(text, saved), none.size(), _first(none)],
		saved_ok and _endings_wrong(text, saved) == 0 and none.is_empty())
	_same_parts("...saved", parts, saved)
	_shape_kept("...saved", text, saved)
	await _open(saved, "CRLF metas")
	_saves += 1
	var again_name: String = "keep metas %d" % _saves
	saved_ok = _store.save_as(again_name)
	var again: String = FileAccess.get_file_as_string(ModelStore.saved_path(again_name))
	none = META_KINDS.filter(func(kind: String) -> bool: return not _meta_read(kind, again))
	_check("...opened again and saved again: %d lines ending otherwise, %d not kept, %d lines "
		% [_endings_wrong(text, again), none.size(), _lost(saved, again).size()
			+ _lost(again, saved).size()] + "changed%s" % _first(none + _lost(saved, again)),
		saved_ok and _endings_wrong(text, again) == 0 and none.is_empty()
		and _lost(saved, again).is_empty() and _lost(again, saved).is_empty())
	_same_parts("...saved again", parts, again)


## [param text] with the app's own line of [param kind] written in by its
## writer, as a save writes it.
func _meta_written(kind: String, text: String, pin_lines: PackedStringArray) -> String:
	match kind:
		"floor":
			return ModelFloor.make(ModelFloor.BASEPLATE, 16, 16, 2).written_into(text)
		"hidden colours":
			return HiddenColours.written_into(text, HIDDEN)
		"cut-away":
			return CutShape.written_into(text, CUT)
		"motions":
			return Motions.written_into(text, PackedStringArray(MOTION))
		"pins":
			return PinnedComments.written_into(text, pin_lines)
		"shared link":
			return ModelStore.with_share(text, SHARE)
		"sets in its bin":
			return SetBin.written_into(text, PackedStringArray(["6780-1"]))
		"picture to trace":
			return ReferenceImage.written_into(text, {"on": "floor", "at": [0, 0, 0],
				"width": 200, "picture": _picture()})
		"set":
			return ModelStore.with_set(text, "6780-1")
	return text


## Whether [param text] says what [method _meta_written] wrote of [param kind],
## read as the app reads it when it opens the file.
func _meta_read(kind: String, text: String) -> bool:
	match kind:
		"floor":
			var ground: ModelFloor = ModelFloor.read(text)
			return ground != null and ground.kind == ModelFloor.BASEPLATE and ground.across == 16
		"hidden colours":
			return HiddenColours.read(text).get("groups", []).size() == 1
		"cut-away":
			return not CutShape.read(text).is_empty()
		"motions":
			var motions: Motions = Motions.read(text)
			return motions.list.size() == 1 and motions.unread.is_empty()
		"pins":
			var pins: PinnedComments = PinnedComments.read(text)
			return pins.list.size() == 1 and pins.list[0].text == "the author's favourite"
		"shared link":
			return ModelStore.share_in(text) == SHARE
		"sets in its bin":
			return SetBin.read(text) == PackedStringArray(["6780-1"])
		"picture to trace":
			return ReferenceImage.read(text).get("picture", "") == _picture()
		"set":
			return ModelStore.set_in(text) == "6780-1"
	return false


## A picture to trace, as the app keeps one: a WebP in base64.
func _picture() -> String:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color(0.8, 0.2, 0.2))
	return Marshalls.raw_to_base64(image.save_webp_to_buffer())


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
		var words: PackedStringArray = LdrModel._fields(line)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			section = _file_name_of(line)
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


## The name a FILE line [param line] gives its section, as [method _lost]
## says it: in lower case, its spaces as they are, a tab after FILE read as
## LdrModel reads it.
static func _file_name_of(line: String) -> String:
	var said: String = line.strip_edges()
	if said.substr(0, 7).to_upper() == "0 FILE ":
		return said.substr(7).to_lower()
	return " ".join(LdrModel._fields(said).slice(2)).to_lower()


## Line [param n] of [param text] as [method _lost] says it.
static func _said_line(text: String, n: int) -> String:
	var lines: PackedStringArray = text.split("\n")
	var section: String = ""
	for k: int in range(n, -1, -1):
		var words: PackedStringArray = LdrModel._fields(lines[k].strip_edges())
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			section = _file_name_of(lines[k])
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
		# Its ending is [method _endings_wrong]'s: a CRLF file's last line,
		# with none, has one when a line is put after it.
		var line: String = lines[n].trim_suffix("\r")
		var words: PackedStringArray = LdrModel._fields(line.strip_edges())
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			section = _file_name_of(line)
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
		var words: PackedStringArray = LdrModel._fields(entry.substr(entry.find(": ") + 2))
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
		var words: PackedStringArray = LdrModel._fields(line)
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


# -- every part, and the lines that say what the next is ---------------------------


## Every part the model [param text] opens as, as ModelStore opens it: a
## Studio number as LDraw's, a mirrored copy's part in its other hand, a
## retired number as the part it became, where its stub puts it, a part
## drawn in one colour as the part it is in that colour. [part, colour,
## place in the file's coordinates, whether the app shows it, its copy] each,
## the parts the app cannot show among them (not in the library: their line
## is all the model has of them).
func _parts_of(text: String) -> Array:
	var out: Array = []
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return out
	for item: Variant in _drawn(model):
		var placement: LdrModel.Placement = item
		placement.part_id = ModelStore.studio_part(placement.part_id, _library)
		if placement.mirrored:
			Assemblies.unmirror(placement, _library)
		var real: String = _library.resolve(placement.part_id)
		if real != placement.part_id:
			placement.transform = placement.transform * _library.moved_by(placement.part_id)
			placement.part_id = real
		var colour: int = _library.current_colour(placement.part_id)
		if colour >= 0:
			placement.part_id = _library.current(placement.part_id)
			placement.color_code = colour
		out.append([placement.part_id, placement.color_code, placement.transform,
			_library.parts.has(placement.part_id), placement.unit])
	return out


## [param model]'s parts, a flexible part's skin the file carries as a part
## of its own as the pieces it draws: written whole, a rope goes as its skin
## (CustomParts), a part whose section holds the pieces the rope's did, and
## a reader draws those pieces. Counted as one part, 31037-1's rope was 50
## pieces lost and a part more.
func _drawn(model: LdrModel) -> Array:
	var out: Array = []
	for item: Variant in model.flatten(_library.parts):
		var placement: LdrModel.Placement = item
		var skin: String = str(model.embedded_parts.get(LdrModel._key(placement.part_id) + ".dat", ""))
		if not CustomParts.is_skin_text(skin):
			out.append(placement)
			continue
		var pieces: LdrModel = LdrModel.parse(skin, "skin")
		for one: Variant in pieces.flatten(_library.parts) if pieces != null else []:
			var piece: LdrModel.Placement = one
			piece.transform = placement.transform * piece.transform
			if piece.color_code == 16:
				piece.color_code = placement.color_code
			piece.unit = placement.unit
			out.append(piece)
	return out


static func _unshown_count(parts: Array) -> int:
	return parts.filter(func(entry: Array) -> bool: return not bool(entry[3])).size()


## The parts on the baseplate as [method _parts_of] has them, by id: in the
## file's coordinates, the lift the model was stood on the ground by taken
## off.
func _world_parts() -> Dictionary:
	var out: Dictionary = {}
	var lift: Vector3 = _store.lift()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out[brick.id] = [brick.part_id, brick.color_code,
			Transform3D(brick.transform.basis, brick.transform.origin - lift), true,
			Assemblies.path_of(brick)]
	return out


## The parts of [param a] that [param b] has not got: the same part in the
## same colour, within a twentieth of an LDU and turned alike, each of
## [param b] once.
static func _unmatched(a: Array, b: Array) -> Array:
	var open: Dictionary = {}       ## part|colour -> [index into b]
	for k: int in b.size():
		var key: String = "%s|%d" % [b[k][0], b[k][1]]
		if not open.has(key):
			open[key] = []
		(open[key] as Array).append(k)
	var used: Dictionary = {}
	var out: Array = []
	for entry: Array in a:
		var at: Transform3D = entry[2]
		var found: int = -1
		var nearest: float = 0.05
		for k: int in open.get("%s|%d" % [entry[0], entry[1]], []):
			if used.has(k):
				continue
			var other: Transform3D = b[k][2]
			var d: float = at.origin.distance_to(other.origin)
			if d > nearest:
				continue
			var alike: bool = true
			for axis: int in 3:
				if (at.basis[axis] - other.basis[axis]).length() > 0.002:
					alike = false
			if alike:
				nearest = d
				found = k
		if found < 0:
			out.append(entry)
		else:
			used[found] = true
	return out


## The parts the file opens as after the edit [param done] did: those of
## [param parts] but the ones it took or moved, and the ones it put down, as
## the baseplate before ([param was]) and after it ([param now]) says. A copy
## of a sub-model put down has its parts the app cannot show too, and one
## taken off has them no more.
func _after_edit(parts: Array, was: Dictionary, now: Dictionary, done: Dictionary) -> Array:
	var taken: Array = []
	var put: Array = []
	for id: int in was:
		if not now.has(id) or not _unmatched([was[id]], [now[id]]).is_empty():
			taken.append(was[id])
	for id: int in now:
		# A flexible part's skin is the file's own pieces ([method _parts_of]),
		# which a copy's carry below.
		if CustomParts.is_skin_text(_library.custom_source(str(now[id][0]))):
			continue
		if not was.has(id) or not _unmatched([now[id]], [was[id]]).is_empty():
			put.append(now[id])
	var out: Array = _unmatched(parts, taken) + put
	if done.has("copied"):
		var from: String = done["copied"][0]
		var to: String = done["copied"][1]
		var by: Vector3 = _middle_of(now, to) - _middle_of(now, from)
		for entry: Array in parts:
			if not bool(entry[3]) and _under(str(entry[4]), from):
				var at: Transform3D = entry[2]
				out.append([entry[0], entry[1], Transform3D(at.basis, at.origin + by), false, to])
	if done.has("taken"):
		var gone: Array = parts.filter(func(entry: Array) -> bool:
			return not bool(entry[3]) and _under(str(entry[4]), str(done["taken"])))
		out = _unmatched(out, gone)
	return out


static func _under(unit: String, path: String) -> bool:
	return unit == path or unit.begins_with(path + "/")


static func _middle_of(parts: Dictionary, path: String) -> Vector3:
	var sum := Vector3.ZERO
	var n: int = 0
	for id: int in parts:
		if _under(str(parts[id][4]), path):
			sum += (parts[id][2] as Transform3D).origin
			n += 1
	return sum / maxf(n, 1)


## Whether the model [param text] opens as is [param expected]: every part,
## shown or not, in place and in colour, and no other.
func _same_parts(what: String, expected: Array, text: String) -> bool:
	var got: Array = _parts_of(text)
	var missing: Array = _unmatched(expected, got)
	var extra: Array = _unmatched(got, expected)
	var named: Array = (missing.map(func(entry: Array) -> String: return "no %s" % _named(entry))
		+ extra.map(func(entry: Array) -> String: return "a %s more" % _named(entry)))
	return _check("%s: opens as %d parts (%d the app cannot show) of %d, %d missing or moved "
		% [what, got.size(), _unshown_count(got), expected.size(), missing.size()]
		+ "(%d of them unshown), %d more%s" % [_unshown_count(missing), extra.size(),
			_first(named)], missing.is_empty() and extra.is_empty())


static func _named(entry: Array) -> String:
	var at: Vector3 = (entry[2] as Transform3D).origin
	return "%s %d at %.1f %.1f %.1f in %s%s" % [entry[0], entry[1], at.x, at.y, at.z,
		entry[4] if not str(entry[4]).is_empty() else "the model",
		"" if bool(entry[3]) else " (unshown)"]


## Whether [param now], the file [param was] saved, kept what is not a line
## of its own to count: each line that says what the next is right above
## the line it said it of, the file's line endings, its header in its
## header and the lines before its first FILE line before it.
func _shape_kept(what: String, was: String, now: String) -> bool:
	var runs: Array = _runs_wrong(was, now)
	var ends: int = _endings_wrong(was, now)
	var header: Array = _header_wrong(was, now)
	return _check("%s: %d lines that say what the next is parted from it or given another, "
		% [what, runs.size()] + "%d lines ending otherwise than the file's, " % ends
		+ "%d header lines out of their place%s" % [header.size(), _first(runs + header)],
		runs.is_empty() and ends == 0 and header.is_empty())


## Whether [param line] says what the line after it is: LDCad's group of
## the next part, MLCad's group and hidden part, BFC's INVERTNEXT.
static func _binds(line: String) -> bool:
	var words: PackedStringArray = LdrModel._fields(line.strip_edges())
	if words.size() < 3 or words[0] != "0":
		return false
	return (words[1] + " " + words[2]).to_upper() in ["!LDCAD GROUP_NXT", "MLCAD BTG",
		"MLCAD HIDE", "BFC INVERTNEXT"]


## Each run of lines of [param text] that say what the next is, and what the
## line after them places: [the run, the part's number or "a sub-model",
## "" for a line that places nothing].
func _runs_of(text: String) -> Array:
	var lines: PackedStringArray = text.split("\n")
	var sections: Dictionary = {}
	for raw: String in lines:
		var words: PackedStringArray = LdrModel._fields(raw.strip_edges())
		if words.size() >= 3 and words[0] == "0" and words[1].to_upper() == "FILE":
			sections[LdrModel._key(" ".join(words.slice(2)))] = true
	var out: Array = []
	var run := PackedStringArray()
	for raw: String in lines:
		if _binds(raw):
			run.append(" ".join(LdrModel._fields(raw.strip_edges())))
			continue
		if run.is_empty():
			continue
		var words: PackedStringArray = LdrModel._fields(raw.strip_edges())
		var placed: String = ""
		if words.size() >= 15 and words[0] == "1":
			var key: String = LdrModel._key(" ".join(words.slice(14)))
			# By its number now: a part the app wrote again is written by it
			# (4073 as 6141).
			placed = "a sub-model" if sections.has(key) \
				else _library.resolve(key.trim_suffix(".dat"))
		out.append([" | ".join(run), placed])
		run = PackedStringArray()
	if not run.is_empty():
		out.append([" | ".join(run), ""])
	return out


func _runs_wrong(was: String, now: String) -> Array:
	var had: Dictionary = {}
	for pair: Array in _runs_of(was):
		had["%s -> %s" % pair] = true
	var out: Array = []
	for pair: Array in _runs_of(now):
		if str(pair[1]).is_empty():
			out.append("\"%s\" before no part" % pair[0])
		elif not had.has("%s -> %s" % pair):
			out.append("\"%s\" before a %s" % pair)
	return out


## How many lines of [param now] end otherwise than [param was]'s all do: in
## "\r\n", or in "\n" alone. None for a file of both.
static func _endings_wrong(was: String, now: String) -> int:
	var lines: PackedStringArray = was.split("\n")
	var crlf: int = 0
	for n: int in lines.size() - 1:
		if lines[n].ends_with("\r"):
			crlf += 1
	if crlf != 0 and crlf != lines.size() - 1:
		return 0
	var wrong: int = 0
	var saved: PackedStringArray = now.split("\n")
	for n: int in saved.size() - 1:
		if saved[n].ends_with("\r") != (crlf > 0):
			wrong += 1
	return wrong


## The lines of [param was]'s header (its author, licence, history, BFC
## line and the like) not in [param now]'s before the first part of its
## model, and the lines before its first FILE line not before [param now]'s.
static func _header_wrong(was: String, now: String) -> Array:
	var out: Array = []
	var lead_was: Array = _lead_of(was)
	var lead_now: Array = _lead_of(now)
	for line: String in lead_was:
		if not lead_now.has(line):
			out.append("before the first FILE: " + line)
	var head: Array = _head_of(now)
	for line: String in _head_of(was):
		if not head.has(line):
			out.append("header: " + line)
	return out


## The lines of [param text] before its first FILE line, when it has one.
static func _lead_of(text: String) -> Array:
	var out: Array = []
	for raw: String in text.split("\n"):
		var words: PackedStringArray = LdrModel._fields(raw.strip_edges())
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			return out
		if not words.is_empty() and words[0] != "0":
			return []
		if not words.is_empty():
			out.append(" ".join(words))
	return []


## The header lines of [param text]'s model (its author, licence, history,
## BFC certification, LDraw's own), before its first part or step.
static func _head_of(text: String) -> Array:
	var out: Array = []
	var files: int = 0
	for raw: String in text.split("\n"):
		var words: PackedStringArray = LdrModel._fields(raw.strip_edges())
		if words.is_empty():
			continue
		if words[0] != "0":
			break
		if words.size() < 2:
			continue
		var keyword: String = words[1].to_upper()
		if keyword == "FILE":
			files += 1
			if files > 1:
				break
			continue
		if keyword in ["STEP", "ROTSTEP", "NOFILE"]:
			break
		if keyword in ["AUTHOR:", "!LICENSE", "!HISTORY", "!LDRAW_ORG", "!CATEGORY",
				"!KEYWORDS", "!CMDLINE", "!HELP"] or keyword == "BFC" and words.size() > 2 \
				and words[2].to_upper() in ["CERTIFY", "NOCERTIFY"]:
			out.append(" ".join(words))
	return out


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
