## A file opens as LDraw reads it, every sub-model whatever its name, and
## saves to a file LDraw reads the same (openfaults).
##
##   godot --headless --path . --script src/dev/openfaults_probe.gd
##
## Live (139b0aa4e) and pre261 read a file's sub-files by a bare stem (no
## folder, one extension off) and named a sub-model's section, written
## whole, after its title, ".ldr" put after it. So "0 FILE hssub.ldr" titled
## "hssub.ldr", as MLCad writes one, went out as "hssub.ldr.ldr", and the
## next open drew its copies as a part nobody has (hscheck); "Castle.ldr",
## placed by "castle.mpd", was the model itself; "Gate .ldr" was "Gate.ldr",
## a FILE named in control characters none, "parts\twin.ldr" "twin.ldr"
## (se3check); of two blocks of one name the open read the last and a whole
## write kept the first (sf2check du_stepnew, dp_stepnew); a renamed copy
## was written into a deleted one's section, the author's lines of it lost
## (co_del_rename_tail); and a copy gone its own way was written first at
## the next save, saying COPY 1, a file of its own each save (copyfaults2
## cfc_wing2). Then ofcheck: read so, a shortcut block named as a library
## part was a sub-model of the part's pieces (10251-1's door left its parts
## list and price), sections were written in the last open's order (a step
## edit's save and the next one's differed), and a sub-model named as the
## main file drew 1 part of 3.
##
## Each case opens its file (src/dev/fixtures/of_*) as the app opens one,
## as someone else's file or as the app's own ("Author: Brickworks", which
## is written whole), makes its edit as a person makes it, and checks:
## - the app has every part LDView draws, read here by LDView's rule apart
##   from LdrModel (the reader checked is not the checker): its number,
##   colour and place;
## - the Open list's count (ModelStore.count_in, which reads the text alone)
##   is the parts LDView draws from the text with no library to ask;
## - unedited, someone else's file saves byte for byte;
## - every way the model is written (Save, the autosave, export, share, the
##   copy kept for Undo, Save As and MCP save_model) is read by LDView's
##   rule as the app has the model, keeps the lines the case names and has
##   none of those it names gone;
## - the save opened again is the model saved, every part in place, colour,
##   copy and step; saved again it is the same file, byte for byte.
## Each case's texts go to OPENFAULTS_OUT/<case>/ (orig.ldr, saved.ldr,
## again.ldr, export.ldr and the others) for sf2check's readers.py.
##
##   OPENFAULTS_CASES=hs_own,twins_own   those cases
##   OPENFAULTS_OUT=DIR                  where the texts go (else user://openfaults)
extends SceneTree

const FX := "res://src/dev/fixtures/"
const A_BUILDER := "0 Author: A. Builder [abuilder]"
## A FILE named only in control characters (se3check names2).
const CONTROLS := "\u0001\u0002\u001f"

const CASES: Array = [
	# 0: a sub-model titled with its own file name, written whole every way
	# a model is written, and as someone else's with a part of it painted.
	{"name": "hs_own", "file": "of_hssub.ldr", "own": true,
		"keep": ["0 FILE hssub.ldr\n", "0 Name: hssub.ldr\n", " hssub.ldr\n"],
		"gone": ["hssub.ldr.ldr", "hssub.ldr.dat"]},
	{"name": "hs_theirs", "file": "of_hssub.ldr", "own": false,
		"edits": [{"op": "paint", "sel": {"part": "3010"}, "colour": 2}],
		"keep": ["0 FILE hssub.ldr\n", " hssub.ldr\n"], "gone": ["hssub.ldr.ldr"]},
	# 1: a sub-model named as the model is but for its extension.
	# Its main model has a copy built in its own steps (IN castle#1), which
	# a save writes as live writes it, never a patch (SourceFile.plan), so
	# unedited too: not the file byte for byte, and not this unit's.
	{"name": "castle_theirs", "file": "of_castle.mpd", "own": false, "in_parent": true,
		"edits": [{"op": "paint", "sel": {"part": "3003"}, "colour": 14}],
		"keep": ["0 FILE castle.mpd\n", "0 FILE Castle.ldr\n", "0 FILE keep.ldr\n"]},
	{"name": "castle_own", "file": "of_castle.mpd", "own": true,
		"keep": ["0 FILE Castle.ldr\n", "0 FILE keep.ldr\n", " Castle.ldr\n", " keep.ldr\n"]},
	# 2: names a space, a dot or a control character apart.
	{"name": "names2_theirs", "file": "of_names2.mpd", "own": false,
		"edits": [{"op": "paint", "sel": {"part": "3001", "nth": 0}, "colour": 2}],
		"keep": ["0 FILE Gate .ldr\n", "0 FILE Gate.ldr\n", "0 FILE " + CONTROLS + "\n"]},
	{"name": "names2_own", "file": "of_names2.mpd", "own": true,
		"keep": ["0 FILE Gate .ldr\n", "0 FILE Gate.ldr\n", "0 FILE " + CONTROLS + "\n",
			"0 FILE Tower..ldr\n", "0 FILE Tower.ldr\n"]},
	# 3: one name in three folders and cases.
	{"name": "twins_theirs", "file": "of_twins.mpd", "own": false,
		"edits": [{"op": "paint", "sel": {"part": "3001"}, "colour": 14}],
		"keep": ["0 FILE parts\\twin.ldr\n", "0 FILE twin.ldr\n"]},
	{"name": "twins_own", "file": "of_twins.mpd", "own": true,
		"keep": ["0 FILE parts\\twin.ldr\n", "0 FILE twin.ldr\n", " parts\\twin.ldr\n"]},
	# 4: two blocks of one name, unplaced and placed; a step edit.
	{"name": "du_theirs", "file": "of_dup_unplaced.mpd", "own": false,
		"edits": [{"op": "step_new", "sel": {"part": "3001", "colour": 1}}],
		"keep": ["3003.dat", "3010.dat", "0 Spare Two\n", "0 Spare Block\n"]},
	# The app's own file is written from the model: blocks nothing places
	# are not in it (only someone else's file carries them, SourceFile).
	{"name": "du_own", "file": "of_dup_unplaced.mpd", "own": true,
		"edits": [{"op": "step_new", "sel": {"part": "3001", "colour": 1}}],
		"gone": ["0 Spare Two\n", "0 Spare Block\n"]},
	{"name": "dp_theirs", "file": "of_dup_placed.mpd", "own": false,
		"edits": [{"op": "step_new", "sel": {"part": "3001", "colour": 4}}],
		"keep": ["0 Wing Other\n", "3010.dat", "0 Wing\n", "3003.dat"]},
	{"name": "dp_own", "file": "of_dup_placed.mpd", "own": true,
		"edits": [{"op": "step_new", "sel": {"part": "3001", "colour": 4}}],
		"keep": ["0 Wing\n", "3003.dat"], "gone": ["0 Wing Other\n", "3010.dat"]},
	# 5: a copy deleted and another renamed to its name.
	{"name": "corner_theirs", "file": "of_corner.mpd", "own": false,
		"edits": [{"op": "delete", "sel": {"copy": "Wing#1"}},
			{"op": "rename", "sel": {"copy": "Tail#1"}, "name": "Wing"}],
		"keep": ["1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat\n", "1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat\n"],
		"section": "wing.ldr"},
	{"name": "corner_own", "file": "of_corner.mpd", "own": true,
		"edits": [{"op": "delete", "sel": {"copy": "Wing#1"}},
			{"op": "rename", "sel": {"copy": "Tail#1"}, "name": "Wing"}]},
	# 6: a copy gone its own way, by Make unique; and a step edit over MCP
	# on the main model, which leaves the wings copies of one sub-model, in
	# red and in blue (copyfaults3: a whole write split them into "wing 2").
	{"name": "wing2_steps", "file": "of_wing2.ldr", "own": true,
		"edits": [{"op": "mcp", "tool": "edit_steps", "args": {"op": "delete", "step": 3}}]},
	{"name": "wing2_unique", "file": "of_wing2.ldr", "own": true,
		"edits": [{"op": "unique", "sel": {"copy": "wing#2"}}]},
	{"name": "wing2_unique_theirs", "file": "of_wing2.ldr", "own": false,
		"edits": [{"op": "unique", "sel": {"copy": "wing#2"}}]},
	# 7 (ofcheck F1): a block named as a part the library has, that says it
	# is a library file (a shortcut here), is that part: 10251-1's door
	# 60797c02, in the parts list and the price. A shortcut of a name the
	# library has not ("10265 - 42716c01.dat", as 73 OMR files have them)
	# is a sub-model, drawn as it is.
	{"name": "shortcut_theirs", "file": "of_shortcut.mpd", "own": false,
		"edits": [{"op": "paint", "sel": {"part": "3001"}, "colour": 2}],
		"keep": [" 60797c02.dat\n", "0 FILE 60797c02.dat\n", " 10265 - 42716c01.dat\n"]},
	{"name": "shortcut_own", "file": "of_shortcut.mpd", "own": true,
		"edits": [{"op": "rebase"}, {"op": "paint", "sel": {"part": "3001"}, "colour": 2}],
		"keep": [" 60797c02.dat\n", " 10265 - 42716c01.dat\n", "0 FILE 10265 - 42716c01.dat\n"]},
	# 8 (ofcheck F2): sections in the order the model builds, never the
	# last open's: a step edit putting Alpha's part first, saved, opened
	# and saved again.
	{"name": "order_own", "file": "of_order.mpd", "own": true,
		"edits": [{"op": "rebase"}, {"op": "step_first", "sel": {"part": "3004"}},
			{"op": "mcp", "tool": "edit_steps", "args": {"op": "list"}}]},
	# 9 (ofcheck F4): a sub-model named as the main file. LDView never puts
	# the model's own block in its table, so the later block is the one
	# the references mean.
	{"name": "mainname_theirs", "file": "of_mainname.mpd", "own": false,
		"edits": [{"op": "paint", "sel": {"part": "3001"}, "colour": 2}],
		"keep": ["0 FILE Keep.ldr\n", "0 Keep Sub\n"]},
	{"name": "mainname_own", "file": "of_mainname.mpd", "own": true,
		"edits": [{"op": "rebase"}, {"op": "paint", "sel": {"part": "3001"}, "colour": 2}]},
	# 10 (ofcheck F3): CRLF lines, tabs between fields, a name in two cases.
	{"name": "crlf_theirs", "file": "of_crlf.mpd", "own": false,
		"edits": [{"op": "paint", "sel": {"part": "3010"}, "colour": 2}],
		"keep": ["0 FILE spare.ldr\r\n", "0 FILE Upper.LDR\r\n", "0 Upper twin\r\n", "\t3001.dat\r\n"]},
	{"name": "crlf_own", "file": "of_crlf.mpd", "own": true,
		"edits": [{"op": "rebase"}, {"op": "paint", "sel": {"part": "3010"}, "colour": 2}]},
]

var _failures: int = 0
var _failed_in: Dictionary = {}
var _case_name: String = ""
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
		_failed_in[_case_name] = int(_failed_in.get(_case_name, 0)) + 1
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
	var connector: Variant = _main.get("_connector")
	_socket = (connector as ClaudeConnector).rpc if connector != null else null
	_out = OS.get_environment("OPENFAULTS_OUT")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("user://openfaults")
	print("openfaults probe: texts in %s" % _out)
	var only: String = OS.get_environment("OPENFAULTS_CASES")
	for item: Variant in CASES:
		var case: Dictionary = item
		if not only.is_empty() and not str(case["name"]) in only.split(","):
			continue
		_case_name = str(case["name"])
		print("\n== %s (%s)" % [_case_name, "the app's own" if bool(case["own"]) else "someone else's"])
		await _case(case)
	print("")
	for item: Variant in CASES:
		var name: String = str((item as Dictionary)["name"])
		if only.is_empty() or name in only.split(","):
			print("  %-20s %s" % [name, "ok" if not _failed_in.has(name)
				else "%d failed" % int(_failed_in[name])])
	print("\nopenfaults probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


func _case(case: Dictionary) -> void:
	var text: String = _as_whose(FileAccess.get_file_as_string(FX + str(case["file"])),
		bool(case["own"]))
	if text.is_empty():
		_check("read %s" % case["file"], false)
		return
	_write("orig.ldr", text)
	await _open(text)
	var opened: Dictionary = _state()
	_write("opened_state.txt", "\n".join(opened["parts"]) + "\n" + str(opened["units"]))
	_drawn_alike("opened: the parts LDView draws", _ldview(text, _library.parts), _shown())
	var listed: int = ModelStore.count_in(text)
	var alone: int = (_ldview(text, {})["full"] as Array).size()
	_check("the Open list's count, %d, is the parts LDView draws from the text alone, %d" % [listed, alone],
		listed == alone)
	_check("...someone else's file kept (%s)" % (_store.get("_source") != null),
		(_store.get("_source") != null) != bool(case["own"]))
	if not bool(case["own"]):
		var unchanged: String = _text(_title())
		_write("unchanged.ldr", unchanged)
		if bool(case.get("in_parent", false)):
			print("  note  saved unedited: %s (a copy built in its parent's steps)" % (
				"the file byte for byte" if _plain(unchanged) == _plain(text) else "as live writes it"))
			_read_back("unchanged", unchanged, _shown(), {})
		else:
			_check("saved unedited: the file byte for byte (the app's floor line aside)",
				_plain(unchanged) == _plain(text))
	for edit: Variant in case.get("edits", []):
		print("  edit %s: %s" % [JSON.stringify(edit), await _do(edit)])
	await _frames(4)
	_shell.assemblies.leave_to("")
	var edited: Dictionary = _renamed(_state(), case.get("renamed", {}))
	var shown: Dictionary = _shown()
	_write("edited_state.txt", "\n".join(edited["parts"]) + "\n" + str(edited["units"]))
	var title: String = _title()
	var saved: String = _text(title)
	_write("saved.ldr", saved)
	_read_back("saved", saved, shown, case)
	if case.has("section"):
		var was: String = _section(text, str(case["section"]))
		var now: String = _section(saved, str(case["section"]))
		_check("saved: the author's %s section as the file has it (%d lines; saved %d)" % [
			case["section"], was.count("\n"), now.count("\n")], not was.is_empty() and was == now)
	# Every other way the model is written.
	var path: String = OS.get_user_data_dir().path_join("of_export.ldr")
	var exported: bool = await _store.export_paced(path, title)
	var others: Dictionary = {
		"export": FileAccess.get_file_as_string(path) if exported else "",
		"share": await _store.text_for_file(title, "Writing it for its link…"),
		"set_aside": await _store._model_text(false),
	}
	await _store._autosave_paced()
	await _frames(4)
	others["autosave"] = FileAccess.get_file_as_string(ModelStore.autosave()) \
		if FileAccess.file_exists(ModelStore.autosave()) else ""
	if _socket != null:
		var said: String = await _say("save_model", {"name": "of_%s_mcp.ldr" % _case_name})
		print("  save_model: %s" % said.get_slice("\n", 0).left(160))
		others["save_model"] = FileAccess.get_file_as_string(
			ModelStore.SAVE_DIR + "of_%s_mcp.ldr" % _case_name)
	_store.refused = ""
	var as_name: String = "of_%s_as" % _case_name
	print("  save_as: %s %s" % [_store.save_as(as_name), _store.refused])
	others["save_as"] = FileAccess.get_file_as_string(ModelStore.SAVE_DIR + as_name + ".ldr")
	for how: String in others:
		_write("%s.ldr" % how, str(others[how]))
		_read_back(how, str(others[how]), shown, case)
	# Opened again, and saved again.
	await _open(saved)
	var now: Dictionary = _state()
	_write("reopened_state.txt", "\n".join(now["parts"]) + "\n" + str(now["units"]))
	var lost: Array = _unlike(edited["parts"], now["parts"])
	var gained: Array = _unlike(now["parts"], edited["parts"])
	_check("opened again: every part in place, colour, copy and step, %d of %d not%s" % [
		lost.size(), (edited["parts"] as Array).size(), _said_unlike(edited["parts"], now["parts"])],
		lost.is_empty() and gained.is_empty())
	_check("...the same copies and their steps%s" % str(_unlike_dict(edited["units"], now["units"]).slice(0, 4)),
		now["tree"] == edited["tree"] and _unlike_dict(edited["units"], now["units"]).is_empty())
	var again: String = _text(_title())
	_write("again.ldr", again)
	_check("saved again: the same file byte for byte%s" % _first_change(saved, again), again == saved)
	_read_back("again", again, _shown(), case)
	# The others opened again: the model as saved.
	for how: String in ["autosave", "export", "save_as"]:
		if str(others.get(how, "")).is_empty():
			continue
		await _open(str(others[how]))
		var back: Dictionary = _state()
		_check("%s opened again: every part in place, colour, copy and step%s" % [how,
			_said_unlike(edited["parts"], back["parts"])],
			_unlike(edited["parts"], back["parts"]).is_empty()
			and _unlike(back["parts"], edited["parts"]).is_empty())


## [param text], one way the model was written ([param how]): read by
## LDView's rule as the app has the model ([param shown]), with every line
## [param case] keeps and none it has gone.
func _read_back(how: String, text: String, shown: Dictionary, case: Dictionary) -> void:
	if text.is_empty():
		_check("%s: written" % how, false)
		return
	_drawn_alike("%s: LDView draws the model as the app has it" % how, _ldview(text, _library.parts), shown)
	var missing: Array = []
	for kept: Variant in case.get("keep", []):
		if not text.contains(str(kept)):
			missing.append(str(kept).strip_edges().c_escape())
	var there: Array = []
	for gone: Variant in case.get("gone", []):
		if text.contains(str(gone)):
			there.append(str(gone))
	_check("%s: keeps the file's lines and names (%s), has none gone (%s)" % [how,
		"missing " + str(missing) if not missing.is_empty() else "all %d" % case.get("keep", []).size(),
		"there: " + str(there) if not there.is_empty() else "none"], missing.is_empty() and there.is_empty())


# -- LDView's reading ---------------------------------------------------------------


## C's isspace, what LDView's reader (LDLModel, LDLCommentLine) trims and
## splits on.
const SPACE := " \t\n\u000b\u000c\r"


## [param text] read as LDView reads it (LDLMainModel, LDLModel::readComment,
## LDLModelLine): the first FILE section is the model (a file with none is
## one model); a section's name is its text after "0 FILE", a reference its
## text after the fourteenth field, each with C's space trimmed, and the two
## are one name in any case, "\" and "/" the same; the first block of a name
## is the one read (a later one is "already loaded"); the model's own block
## is in no table, so a later block of the model's name is the one its
## references mean (ofcheck F4); a reference naming no section is a part.
## One rule is the app's, not LDView's: a block that says it is a library
## file (its !LDRAW_ORG a part, shortcut or primitive, no model) under a
## number [param known] has is that part, as the library draws it (LDView
## draws the block, the part's own pieces: ofcheck F1, 10251-1's door).
## Each part drawn: "number colour at place", as [method _seen] says them.
static func _ldview(text: String, known: Dictionary) -> Dictionary:
	# A trimmed name never starts with a space: no block is named so.
	const MAIN := " (the model)"
	var sections: Dictionary = {}
	var any_file: bool = false
	var into: Variant = null
	var loose: Array = []
	for raw: String in text.trim_prefix("﻿").replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var words: PackedStringArray = _words(raw)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() in ["FILE", "NOFILE", "!DATA"]:
			into = null
			if words[1].to_upper() == "FILE":
				var key: String = MAIN if not any_file else _name_key(_after(raw, 2))
				any_file = true
				if not sections.has(key):
					sections[key] = []
					into = sections[key]
			continue
		if into != null:
			(into as Array).append(raw)
		elif not any_file:
			loose.append(raw)
	if not any_file:
		sections[MAIN] = loose
	for key: String in sections.keys():
		if key != MAIN and known.has(_number(key)) and _says_library_file(sections[key]):
			sections.erase(key)
	var out: Array = []
	_draw(sections, MAIN, PackedFloat64Array([0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]), 16, out, {})
	return _seen(out)


## Whether a block's header (its first 16 lines) has an !LDRAW_ORG line of
## a library file's kind: Part, Subpart, Shortcut, a Primitive, each maybe
## Unofficial_, never a Model.
static func _says_library_file(lines: Array) -> bool:
	for raw: Variant in lines.slice(0, 16):
		var words: PackedStringArray = _words(str(raw))
		if words.size() >= 3 and words[0] == "0" and words[1].to_upper() == "!LDRAW_ORG":
			return not words[2].to_lower().contains("model")
	return false


## A reference's part number: its last folder's name, its extension off.
static func _number(ref: String) -> String:
	var number: String = ref.get_slice("/", ref.get_slice_count("/") - 1)
	for suffix: String in [".dat", ".ldr", ".mpd"]:
		if number.ends_with(suffix):
			return number.trim_suffix(suffix)
	return number


static func _draw(sections: Dictionary, key: String, at: PackedFloat64Array, colour: int,
		out: Array, within: Dictionary) -> void:
	within[key] = true
	for raw: Variant in sections[key]:
		var words: PackedStringArray = _words(str(raw))
		if words.size() < 15 or words[0] != "1":
			continue
		var c: int = words[1].to_int()
		if c == 16:
			c = colour
		var numbers := PackedFloat64Array()
		for n: int in range(2, 14):
			numbers.append(words[n].to_float())
		var placed: PackedFloat64Array = _times(at, numbers)
		var named: String = _after(str(raw), 14)
		var ref: String = _name_key(named)
		if sections.has(ref):
			if not within.has(ref):
				_draw(sections, ref, placed, c, out, within)
			continue
		out.append([_number(ref), c, LdrModel.to_transform(placed)])
	within.erase(key)


static func _words(line: String) -> PackedStringArray:
	var spaced: String = line
	for c: String in ["\t", "\n", "\u000b", "\u000c", "\r"]:
		spaced = spaced.replace(c, " ")
	return spaced.split(" ", false)


## [param line] after its first [param count] fields, as written, C's space
## trimmed.
static func _after(line: String, count: int) -> String:
	var rest: String = line.lstrip(SPACE)
	for _n: int in count:
		var at: int = 0
		while at < rest.length() and not SPACE.contains(rest[at]):
			at += 1
		rest = rest.substr(at).lstrip(SPACE)
	return rest.rstrip(SPACE)


static func _name_key(name: String) -> String:
	return name.replace("\\", "/").to_lower()


## LDraw's 3x4 [param a] times [param b], each "x y z a b c d e f g h i".
static func _times(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for r: int in 3:
		out.append(a[r] + a[3 + r * 3] * b[0] + a[4 + r * 3] * b[1] + a[5 + r * 3] * b[2])
	for r: int in 3:
		for c: int in 3:
			out.append(a[3 + r * 3] * b[3 + c] + a[4 + r * 3] * b[6 + c] + a[5 + r * 3] * b[9 + c])
	return out


static func _place(t: Transform3D) -> String:
	var place := PackedStringArray()
	for v: Vector3 in [t.origin, t.basis.x, t.basis.y, t.basis.z]:
		for n: float in [v.x, v.y, v.z]:
			place.append("%.2f" % (snappedf(n, 0.01) + 0.0))
	return " ".join(place)


## The app's parts as LDView's reading says them ([method _seen]).
func _shown() -> Dictionary:
	var lift: Vector3 = _store.lift()
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append([brick.part_id, brick.color_code,
				Transform3D(brick.transform.basis, brick.transform.origin - lift)])
	return _seen(out)


## Parts, each [number, colour, place]: "full", each "number colour at
## place" with its turn; "where", each without its turn; "turned", the full
## ones of a turn that does not mirror. A part placed mirrored the app draws
## as its own mirror image or turned (ModelStore's mirrored lines), so LDView's
## turn of it is not the app's: it is held to its number, colour and place.
static func _seen(parts: Array) -> Dictionary:
	var full: Array = []
	var where: Array = []
	var turned: Array = []
	for part: Variant in parts:
		var t: Transform3D = part[2]
		var said: String = "%s %d at %s" % [part[0], part[1], _place(t)]
		full.append(said)
		where.append("%s %d at %s" % [part[0], part[1], _place(Transform3D(Basis.IDENTITY, t.origin))])
		if t.basis.determinant() > 0.0:
			turned.append(said)
	full.sort()
	where.sort()
	turned.sort()
	return {"full": full, "where": where, "turned": turned}


## Whether LDView's reading [param drawn] is the app's [param shown]: every
## part's number, colour and place, and the turn of each LDView turns but
## does not mirror.
func _drawn_alike(what: String, drawn: Dictionary, shown: Dictionary) -> bool:
	var where_ok: bool = _unlike(drawn["where"], shown["where"]).is_empty() \
		and _unlike(shown["where"], drawn["where"]).is_empty()
	var turns_off: Array = _unlike(drawn["turned"], shown["full"])
	var mirrored: int = (drawn["full"] as Array).size() - (drawn["turned"] as Array).size()
	return _check("%s, %d of %d%s%s%s" % [what, (drawn["full"] as Array).size(),
		(shown["full"] as Array).size(), " (%d mirrored)" % mirrored if mirrored > 0 else "",
		_said_unlike(drawn["where"], shown["where"]),
		" (turned otherwise: %s)" % str(turns_off.slice(0, 3)) if not turns_off.is_empty() else ""],
		where_ok and turns_off.is_empty())


## [param state] with each copy [param renamed] names under its new name.
static func _renamed(state: Dictionary, renamed: Dictionary) -> Dictionary:
	if renamed.is_empty():
		return state
	var name := func(path: String) -> String:
		for old: Variant in renamed:
			if path == str(old) or path.begins_with(str(old) + "/"):
				return str(renamed[old]) + path.substr(str(old).length())
		return path
	var parts: Array = []
	for line: Variant in state["parts"]:
		var words: PackedStringArray = str(line).split(" ")
		# "number colour path step ..." with a path of no space; a renamed
		# one has one, so the line is made again.
		parts.append(" ".join(PackedStringArray([words[0], words[1], name.call(words[2])]
			+ Array(words.slice(3)))))
	parts.sort()
	var units: Dictionary = {}
	for unit: Variant in state["units"]:
		units[name.call(str(unit))] = state["units"][unit]
	var tree: Array = (state["tree"] as Array).map(func(p: Variant) -> String: return name.call(str(p)))
	tree.sort()
	return {"parts": parts, "tree": tree, "units": units}


## The lines of the section named [param name] in [param text], the first
## block of that name, "" for none.
static func _section(text: String, name: String) -> String:
	var lines := PackedStringArray()
	var inside: bool = false
	for raw: String in text.replace("\r\n", "\n").split("\n"):
		var words: PackedStringArray = _words(raw)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() in ["FILE", "NOFILE"]:
			if inside:
				break
			inside = words[1].to_upper() == "FILE" and _name_key(_after(raw, 2)) == _name_key(name)
			continue
		if inside:
			lines.append(raw)
	return "\n".join(lines) + ("\n" if inside or not lines.is_empty() else "")


# -- the app ------------------------------------------------------------------------


## [param text] as the app's own file (its model's Author line "Brickworks",
## written whole) or as someone else's.
static func _as_whose(text: String, own: bool) -> String:
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].begins_with("0 Author:"):
			if own:
				lines[n] = "0 Author: Brickworks"
			elif lines[n].strip_edges() == "0 Author: Brickworks":
				lines[n] = A_BUILDER
			break
	return "\n".join(lines)


func _open(text: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


## The model written as a save writes it, saying how.
func _text(title: String) -> String:
	var text: String = _store.to_text(title, true)
	var whole: Variant = _store.get("last_whole")
	if _store.call("_live_source") == null:
		print("  WRITTEN whole (the app's own)")
	elif whole != null:
		print("  WRITTEN %s" % ("a patch" if str(whole).is_empty() else "as live writes it: " + str(whole)))
	return text


func _title() -> String:
	var source: Variant = _store.get("_source")
	if source == null or str((source as Object).get("own_title")).is_empty():
		return "model"
	return str((source as Object).get("own_title"))


func _write(file: String, text: String) -> void:
	var dir: String = _out.path_join(_case_name)
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join(file), FileAccess.WRITE)
	f.store_string(text)
	f.close()


## [param text] without the app's floor line, which every save writes.
static func _plain(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with("0 !BRICKWORKS FLOOR"):
			out.append(line)
	return "\n".join(out)


static func _first_change(a: String, b: String) -> String:
	if a == b:
		return ""
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "<end>"
		var y: String = lb[n] if n < lb.size() else "<end>"
		if x != y:
			return " (line %d was %s, is %s)" % [n + 1, x.c_escape(), y.c_escape()]
	return ""


func _do(edit: Dictionary) -> String:
	var op: String = edit["op"]
	var sel: Dictionary = edit.get("sel", {})
	if sel.has("copy"):
		var path: String = str(sel["copy"])
		if not _shell.assemblies.paths().has(path):
			_check("a copy %s to pick (copies %s)" % [path, str(_shell.assemblies.paths())], false)
			return "no copy %s" % path
		_shell.assemblies.leave_to(Assemblies.parent_of(path))
		_select_only(Array(_shell.assemblies.ids_under(path)))
	elif not sel.is_empty():
		var ids: Array = []
		for brick: BrickWorld.Brick in _sorted_bricks():
			if sel.has("part") and brick.part_id != str(sel["part"]):
				continue
			if sel.has("colour") and brick.color_code != int(sel["colour"]):
				continue
			ids.append(brick.id)
		if sel.has("nth"):
			ids = ids.slice(int(sel["nth"]), int(sel["nth"]) + 1)
		if ids.is_empty():
			_check("selector %s names a part" % JSON.stringify(sel), false)
			return "nothing selected"
		_select_only(ids)
	match op:
		"rebase":
			# The app's own file as the app writes it, opened: what the
			# next saves of it are held to.
			var written: String = _text(_title())
			_write("base.ldr", written)
			await _open(written)
			return "rebased: the app's own text, %d lines" % written.count("\n")
		"step_first":
			var picked: Array = _builder.selection.keys()
			var first: Instructions.Step = Instructions.plan(_world, _library, _store.scenery, {}, true)[0]
			var moved: String = _shell.change_steps("to", picked, first)
			await _frames(4)
			return moved.get_slice("\n", 0)
		"delete":
			_shell.run("delete")
			await _frames(4)
			return "deleted; copies %s" % str(_shell.assemblies.paths())
		"paint":
			var painted: int = _builder.paint_selection(int(edit["colour"]))
			await _frames(4)
			return "painted %d" % painted
		"rename":
			_shell.run("rename_assembly")
			await _frames(2)
			var named: String = _name_it(str(edit["name"]))
			await _frames(4)
			return "%s; copies %s" % [named, str(_shell.assemblies.paths())]
		"unique":
			_shell.run("make_unique")
			await _frames(4)
			return "made unique; copies %s" % str(_shell.assemblies.paths())
		"step_new":
			var ids: Array = _builder.selection.keys()
			var step: Instructions.Step = null
			for each: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
				if each.brick_ids.has(int(ids[0])):
					step = each
			var said: String = _shell.change_steps("new", ids, step)
			await _frames(4)
			return said.get_slice("\n", 0)
		"mcp":
			if _socket == null:
				_check("the connector is there to ask", false)
				return "no connector"
			var said: String = await _say(str(edit["tool"]), edit["args"])
			await _frames(6)
			return said.get_slice("\n", 0).left(160)
	return "no such op %s" % op


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


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _sorted_bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick)
	out.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	return out


## Every part: number, colour, copy, step (its rank among its home's steps)
## and place; the copies; each copy's step.
func _state() -> Dictionary:
	var lift: Vector3 = _store.lift()
	var tree: Dictionary = {}
	var spaces: Dictionary = {}
	var bricks: Array = _sorted_bricks()
	for brick: BrickWorld.Brick in bricks:
		var path: String = Assemblies.path_of(brick)
		var at: String = ""
		for segment: String in Assemblies.segments(path):
			at = Assemblies.join(at, segment)
			tree[at] = true
		_add(spaces, _home(path), brick.step)
	for unit: String in tree:
		var step: int = int(_world.unit_steps.get(unit, -1))
		if step != AuthorSteps.IN_PARENT:
			_add(spaces, _home(Assemblies.parent_of(unit)), step)
	var ranks: Dictionary = {}
	for home: String in spaces:
		var steps: Array = (spaces[home] as Dictionary).keys()
		steps.sort()
		var rank: Dictionary = {}
		for step: int in steps:
			rank[step] = -1 if step < 0 else rank.size() - (1 if rank.has(-1) else 0)
		ranks[home] = rank
	var parts: Array = []
	for item: Variant in bricks:
		var brick: BrickWorld.Brick = item
		var path: String = Assemblies.path_of(brick)
		parts.append("%s %d %s step %d at %s" % [brick.part_id, brick.color_code, path,
			int(ranks[_home(path)][brick.step]),
			_place(Transform3D(brick.transform.basis, brick.transform.origin - lift))])
	parts.sort()
	var units: Dictionary = {}
	for unit: String in tree:
		var step: int = int(_world.unit_steps.get(unit, -1))
		units[unit] = "in its parent's" if step == AuthorSteps.IN_PARENT \
			else str(ranks[_home(Assemblies.parent_of(unit))].get(step, step))
	var paths: Array = tree.keys()
	paths.sort()
	return {"parts": parts, "tree": paths, "units": units}


static func _add(spaces: Dictionary, home: String, step: int) -> void:
	if not spaces.has(home):
		spaces[home] = {}
	(spaces[home] as Dictionary)[step] = true


func _home(path: String) -> String:
	while not path.is_empty() and int(_world.unit_steps.get(path, -1)) == AuthorSteps.IN_PARENT:
		path = Assemblies.parent_of(path)
	return path


## What of [param a] [param b] has not, one for one.
static func _unlike(a: Array, b: Array) -> Array:
	var have: Dictionary = {}
	for line: Variant in b:
		have[line] = int(have.get(line, 0)) + 1
	var out: Array = []
	for line: Variant in a:
		if int(have.get(line, 0)) > 0:
			have[line] = int(have[line]) - 1
		else:
			out.append(line)
	return out


static func _said_unlike(a: Array, b: Array) -> String:
	var lost: Array = _unlike(a, b)
	var gained: Array = _unlike(b, a)
	if lost.is_empty() and gained.is_empty():
		return ""
	return " (not there %s; there besides %s)" % [str(lost.slice(0, 3)), str(gained.slice(0, 3))]


static func _unlike_dict(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in a:
		if not b.has(key) or str(b[key]) != str(a[key]):
			out.append("%s %s -> %s" % [str(key), str(a[key]), str(b.get(key, "none"))])
	for key: Variant in b:
		if not a.has(key):
			out.append("%s new %s" % [str(key), str(b[key])])
	return out


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
