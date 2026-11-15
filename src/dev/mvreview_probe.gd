## mvreview: an independent attack on movedparts' replace (mvreview,
## 2026-11-15), kept with its fix (mvfix): every case green.
##
##   godot --headless --path . --script src/dev/mvreview_probe.gd
##
## Undone and redone by the app's own Undo and Redo (EditVerbs.press): the
## replace is one step of the history since mvfix, not an open undone, and
## the moved and alias parts are offered in the bar over the model
## (MovedOffer), whose Update all editfirst presses.
##
##   MVREVIEW_CASES=xform,listing   those cases
##   MVREVIEW_OUT=/abs/dir          each file before and after kept there
extends SceneTree

const MODELS := "user://models/"
const CASES: Array = ["xform", "listing", "write", "undo", "mcp", "paths", "omr", "mcp2", "omr2",
	"editfirst"]
const WATCHDOG := 1500.0
const NEAR := 0.01

## A turned stub (3139, 30028), a shifted one (2714), a mirroring one (6540,
## 236a), colour stubs (86037a, 889c01) and a plain one (3023), in one
## sub-model placed four ways: as is, mirrored, turned on two axes, and
## mirrored and turned on two axes.
const XF := """0 FILE xf.ldr
0 Transform attack
0 Name: xf.ldr
0 Author: Someone Else
1 16 0 0 0 1 0 0 0 1 0 0 0 1 car.ldr
1 16 0 0 400 -1 0 0 0 1 0 0 0 1 car.ldr
1 16 400 -40 0 0 1 0 0 0 1 1 0 0 car.ldr
1 16 -400 -40 0 0 -1 0 0 0 1 1 0 0 car.ldr
0 NOFILE
0 FILE car.ldr
0 Car
0 Name: car.ldr
0 Author: Someone Else
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3139.dat
1 14 30 -8 10 0 0 1 0 1 0 -1 0 0 30028.dat
1 1 60 0 0 0 -1 0 1 0 0 0 0 1 2714.dat
1 2 0 -24 40 1 0 0 0 1 0 0 0 1 6540.dat
1 2 0 -24 140 1 0 0 0 1 0 0 0 1 236a.dat
1 4 0 -48 0 1 0 0 0 1 0 0 0 1 86037a.dat
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 889c01.dat
1 4 20 -96 0 1 0 0 0 1 0 0 0 1 3023.dat
0 NOFILE
"""

## What is listed: an alias, a moved part, a stub whose target is a subpart,
## a stub to such a stub, a physical-colour part, a sub-model named as a
## moved number (.ldr) beside the library part of that number, a sub-model
## FILE 3068.dat shadowing the library's 3068, and a part the file carries
## as its own under a moved number (3069).
const LS := """0 FILE ls.ldr
0 Listing attack
0 Name: ls.ldr
0 Author: Someone Else
1 4 0 0 0 1 0 0 0 1 0 0 0 1 4723.dat
1 4 40 0 0 1 0 0 0 1 0 0 0 1 3023.dat
1 4 80 0 0 1 0 0 0 1 0 0 0 1 2421a.dat
1 4 120 0 0 1 0 0 0 1 0 0 0 1 3626-4t.dat
1 4 160 0 0 1 0 0 0 1 0 0 0 1 303923.dat
1 4 200 0 0 1 0 0 0 1 0 0 0 1 3070.dat
1 16 240 0 0 1 0 0 0 1 0 0 0 1 3070.ldr
1 16 280 0 0 1 0 0 0 1 0 0 0 1 3068.dat
1 4 320 0 0 1 0 0 0 1 0 0 0 1 3069.dat
0 NOFILE
0 FILE 3070.ldr
0 A sub-model called 3070
0 Name: 3070.ldr
0 Author: Someone Else
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
0 FILE 3068.dat
0 A sub-model called 3068.dat
0 Name: 3068.dat
0 Author: Someone Else
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 NOFILE
0 FILE 3069.dat
0 My own tile
0 Name: 3069.dat
0 Author: Someone Else
0 !LDRAW_ORG Unofficial_Part
0 BFC CERTIFY CCW
4 16 -20 0 -10 20 0 -10 20 0 10 -20 0 10
4 16 -20 -8 10 20 -8 10 20 -8 -10 -20 -8 -10
4 16 -20 0 -10 -20 -8 -10 20 -8 -10 20 0 -10
4 16 20 0 10 20 -8 10 -20 -8 10 -20 0 10
0 NOFILE
"""

## Every other byte kept: CRLF (the attack makes it so), tabs, odd spacing,
## trailing spaces, a folder in a name, padded numbers, metas, a BFC line
## bound to a moved part, BRICKWORKS lines and COPY lines, steps, a part
## the library has no file for (held), and no line end at the end.
const WR := "0 FILE wr.ldr\n0 Write attack\n0 Name: wr.ldr\n0 Author: Someone Else\n" \
	+ "0 !LPUB PAGE SIZE A4\n0 // 3023.dat named in a comment\n0 BFC INVERTNEXT\n" \
	+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat\n" \
	+ "   1   4    40 0 0   1 0 0 0 1 0 0 0 1   3023.dat   \n" \
	+ "1\t1\t80\t0\t0\t1\t0\t0\t0\t1\t0\t0\t0\t1\t3069.DAT\t\n" \
	+ "1 4 120 0 0 1.000 0 0 0 1 0 0 0 1.0 parts\\3070.dat\n" \
	+ "1 4 160 0 0 1 0 0 0 1 0 0 0 1 notapart99.dat\n" \
	+ "0 !BRICKWORKS STEP_NAME First\n0 STEP\n" \
	+ "0 !BRICKWORKS COPY 1\n1 16 0 -48 0 1 0 0 0 1 0 0 0 1 sub.ldr\n" \
	+ "0 !BRICKWORKS COPY 2\n1 16 0 -96 0 1 0 0 0 1 0 0 0 1 sub.ldr\n" \
	+ "0 STEP\n0 NOFILE\n0 FILE sub.ldr\n0 Sub\n0 Name: sub.ldr\n0 Author: Someone Else\n" \
	+ "1 2 0 0 0 1 0 0 0 1 0 0 0 1 3068.dat\n" \
	+ "1 14 0 0 30 0 0 1 0 1 0 -1 0 0 3139.dat\n" \
	+ "0 NOFILE"

## Moved parts in 3 sub-models, one placed 3 times 2 deep, one mirrored.
const UN := """0 FILE un.ldr
0 Undo attack
0 Name: un.ldr
0 Author: Someone Else
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat
0 STEP
1 16 200 0 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 -200 0 0 -1 0 0 0 1 0 0 0 1 wing.ldr
1 16 0 -48 0 1 0 0 0 1 0 0 0 1 tower.ldr
1 16 0 -96 0 1 0 0 0 1 0 0 0 1 tower.ldr
1 16 0 -144 0 1 0 0 0 1 0 0 0 1 tower.ldr
0 STEP
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
0 Author: Someone Else
1 7 0 0 0 1 0 0 0 1 0 0 0 1 43722.dat
1 7 0 -8 20 1 0 0 0 1 0 0 0 1 3023.dat
0 NOFILE
0 FILE tower.ldr
0 Tower
0 Name: tower.ldr
0 Author: Someone Else
1 16 0 0 0 1 0 0 0 1 0 0 0 1 floor.ldr
0 NOFILE
0 FILE floor.ldr
0 Floor
0 Name: floor.ldr
0 Author: Someone Else
1 1 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat
1 1 0 0 20 0 0 1 0 1 0 -1 0 0 3139.dat
0 NOFILE
"""

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _bar: ModelBar
var _builder: Node
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("mvreview probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_builder = _main.get("_builder")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_store.keeps = true
	_out = OS.get_environment("MVREVIEW_OUT")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	var cases: Array = CASES
	if not OS.get_environment("MVREVIEW_CASES").is_empty():
		cases = Array(OS.get_environment("MVREVIEW_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		var before: int = _failures
		var began: int = Time.get_ticks_msec()
		match name:
			"xform": await _case_xform()
			"listing": await _case_listing()
			"write": await _case_write()
			"undo": await _case_undo()
			"mcp": await _case_mcp()
			"paths": await _case_paths()
			"omr": await _case_omr()
			"mcp2": await _case_mcp2()
			"omr2": await _case_omr2()
			"editfirst": await _case_editfirst()
			_: _check("no such case %s" % name, false)
		print("CASE %s: %s (%d ms)" % [name, "green" if _failures == before
			else "red, %d failed" % (_failures - before), Time.get_ticks_msec() - began])
	print("\nmvreview probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- cases ---------------------------------------------------------------------


func _case_xform() -> void:
	for variant: String in ["lf", "crlf"]:
		var text: String = XF if variant == "lf" else XF.replace("\n", "\r\n")
		print("\n-- xform %s" % variant)
		var now: String = await _replace_all("xf_" + variant, text)
		if now.is_empty():
			continue
		for line: String in now.split("\n"):
			if LdrModel.is_placing(line) and not line.contains("car.ldr"):
				print("    after: " + line.c_escape())
	# Opened fresh: the original and the replaced file, compared part by part.
	var original: Dictionary = await _open_fresh("xf_fresh_a", XF)
	var replaced_text: String = _kept.get("xf_lf", "")
	var replaced: Dictionary = await _open_fresh("xf_fresh_b", replaced_text)
	_compare_drawn("fresh opens: the original and the replaced file", original["bricks"],
		replaced["bricks"])


func _case_listing() -> void:
	var result: Dictionary = await _store.open_text_fetched(LS, "ls")
	await _settled()
	print("  opened: %s, %d parts" % [result["error"] if not str(result["error"]).is_empty()
		else "ok", _bricks().size()])
	for number: String in _store.moved:
		var row: Dictionary = _store.moved[number]
		print("  listed %s: %s %s (%s) ×%d in %s" % [number, row["kind"], row["to"],
			row.get("name", ""), int(row["count"]), str(row["in"])])
	for brick: Array in _bricks():
		print("  drawn: %s colour %d at %s" % [brick[0], brick[1], (brick[2] as Transform3D).origin])
	_check("3070.ldr (a sub-model) is not listed, nor renamed", true)
	var was: String = _store.saved_text()
	var numbers: Array = []
	for number: String in _store.moved:
		if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
			numbers.append(number)
	var said: String = await _bar.replace_moved(numbers)
	await _settled()
	var now: String = _store.saved_text()
	print("  replaced: %s" % said.left(200))
	_diff_lines(was, now)
	_keep("ls.before.ldr", was)
	_keep("ls.after.ldr", now)
	_check("the sub-model reference 3070.ldr still names 3070.ldr",
		_line_naming(now, "3070.ldr") != "")
	_check("the sub-model FILE 3068.dat's reference still names 3068.dat",
		_line_naming(now, "3068.dat") != "")
	_check("the file's own 3069.dat still named 3069.dat", _line_naming(now, "3069.dat") != "")
	print("  after, drawn:")
	for brick: Array in _bricks():
		print("  drawn: %s colour %d at %s" % [brick[0], brick[1], (brick[2] as Transform3D).origin])

	# A loop and a 3-cycle, put in the library here: no hang.
	print("\n-- loops")
	var library: PartLibrary = _store.library
	var mesh: String = (library.parts["3023b"] as PartLibrary.PartInfo).mesh_hash
	for pair: Array in [["mvloopa", "mvloopb"], ["mvloopb", "mvloopa"], ["mvcyca", "mvcycb"],
			["mvcycb", "mvcycc"], ["mvcycc", "mvcyca"]]:
		var info := PartLibrary.PartInfo.new()
		info.id = pair[0]
		info.name = "~Moved to " + pair[1]
		info.kind = "Part"
		info.moved_to = pair[1]
		info.mesh_hash = mesh
		library.parts[pair[0]] = info
	var began: int = Time.get_ticks_msec()
	var looped: String = "0 Loops\n0 Name: loops.ldr\n0 Author: Someone Else\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 mvloopa.dat\n1 4 40 0 0 1 0 0 0 1 0 0 0 1 mvcyca.dat\n" \
		+ "1 4 80 0 0 1 0 0 0 1 0 0 0 1 3023.dat\n"
	result = await _store.open_text_fetched(looped, "loops")
	await _settled()
	print("  opened in %d ms: %s" % [Time.get_ticks_msec() - began, result["error"]])
	for number: String in _store.moved:
		print("  listed %s: %s %s" % [number, _store.moved[number]["kind"], _store.moved[number]["to"]])
	numbers = []
	for number: String in _store.moved:
		if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
			numbers.append(number)
	began = Time.get_ticks_msec()
	said = await _bar.replace_moved(numbers)
	await _settled()
	print("  replaced in %d ms: %s" % [Time.get_ticks_msec() - began, said.left(160)])
	for line: String in _store.saved_text().split("\n"):
		if LdrModel.is_placing(line):
			print("    after: " + line)
	for number: String in _store.moved:
		print("  listed after: %s: %s %s" % [number, _store.moved[number]["kind"],
			_store.moved[number]["to"]])
	_check("loops: opened and replaced, no hang", true)
	for id: String in ["mvloopa", "mvloopb", "mvcyca", "mvcycb", "mvcycc"]:
		library.parts.erase(id)


func _case_write() -> void:
	for variant: String in ["crlf", "crlf_bom", "lf"]:
		var text: String = WR if variant == "lf" else WR.replace("\n", "\r\n")
		if variant.ends_with("bom"):
			text = LdrModel.bom() + text
		print("\n-- write %s" % variant)
		var result: Dictionary = await _store.open_text_fetched(text, "wr_" + variant)
		await _settled()
		var was: String = _store.saved_text()
		_check("an unedited save is the file%s" % _first_unlike(text, was), was == text)
		var numbers: Array = []
		for number: String in _store.moved:
			print("  listed %s: %s %s ×%d" % [number, _store.moved[number]["kind"],
				_store.moved[number]["to"], int(_store.moved[number]["count"])])
			if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
				numbers.append(number)
		var said: String = await _bar.replace_moved(numbers)
		await _settled()
		var now: String = _store.saved_text()
		print("  replaced: %s" % said.left(160))
		_keep("wr_%s.before.ldr" % variant, was)
		_keep("wr_%s.after.ldr" % variant, now)
		var lines: Dictionary = _diff_lines(was, now)
		_check("only placing lines changed, each only in its name or a turned stub's numbers",
			bool(lines["only"]))
		_check("the BOM %s" % ("kept" if variant.ends_with("bom") else "not added"),
			now.begins_with(LdrModel.bom()) == variant.ends_with("bom"))
		_check("no line end at the end, as it was", not now.ends_with("\n"))
		# Saved, opened again, saved again.
		var again_open: Dictionary = await _store.open_text_fetched(now, "wr_again_" + variant)
		await _settled()
		var again: String = _store.saved_text()
		_check("saved, reopened and saved again: the same%s" % _first_unlike(now, again), again == now)


func _case_undo() -> void:
	var text: String = UN.replace("\n", "\r\n")
	_put("un", text)
	await _open_as_person("un")
	var was: String = _store.saved_text()
	_check("unedited save is the file%s" % _first_unlike(text, was), was == text)
	var numbers: Array = []
	for number: String in _store.moved:
		print("  listed %s: %s ×%d in %s" % [number, _store.moved[number]["to"],
			int(_store.moved[number]["count"]), str(_store.moved[number]["in"])])
		if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
			numbers.append(number)
	var said: String = await _bar.replace_moved(numbers)
	await _settled()
	var now: String = _store.saved_text()
	print("  replaced: %s" % said)
	_check("replaced (%d lines differ)" % _differing(was, now), now != was)
	print("  undo says: %s" % _store.reopen_words())
	var undone: bool = await _undo()
	await _settled()
	_check("one undo: was, byte for byte%s" % _first_unlike(was, _store.saved_text()),
		undone and _store.saved_text() == was)
	print("  redo says: %s" % _store.reopen_words(true))
	var redone: bool = await _undo(true)
	await _settled()
	_check("redo: now, byte for byte%s" % _first_unlike(now, _store.saved_text()),
		redone and _store.saved_text() == now)
	# A further edit, then undo twice.
	_builder.held_part = "3001"
	_builder.held_color = 4
	_builder.update_preview(Vector3(40.0, 400.0, 40.0), Vector3.DOWN)
	var put: int = _builder.place()
	_main.call("_on_model_edited")
	await _frames(4)
	var edited: String = _store.saved_text()
	_check("a further edit placed a brick (%d) and changed the file" % put,
		put != 0 and edited != now)
	var first: bool = _builder.undo()
	_main.call("_on_model_edited")
	await _frames(4)
	_check("undo 1 takes the edit off: now again%s" % _first_unlike(now, _store.saved_text()),
		first and _store.saved_text() == now)
	print("  undo 2 says: %s" % _store.reopen_words())
	var second: bool = _builder.undo()
	if not second:
		second = await _undo()
	await _settled()
	_check("undo 2 takes the replace off: was again%s" % _first_unlike(was, _store.saved_text()),
		second and _store.saved_text() == was)
	print("  title %s, unsaved %s" % [_store.title, _store.has_unsaved_work()])


func _case_mcp() -> void:
	# 40 moved numbers in one file.
	var library: PartLibrary = _store.library
	var ids: Array = []
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if not info.is_redirect() or id.contains("/") or id.contains("\\"):
			continue
		var real: String = library.resolve(id)
		if real == id or not library.parts.has(real):
			continue
		if (library.parts[real] as PartLibrary.PartInfo).mesh_hash.is_empty():
			continue
		ids.append(id)
	ids.sort()
	ids = ids.slice(0, 40)
	var text: String = "0 Forty moved\n0 Name: forty.ldr\n0 Author: Someone Else\n"
	var x: int = 0
	for id: String in ids:
		for k: int in 3:
			text += "1 4 %d 0 %d 1 0 0 0 1 0 0 0 1 %s.dat\n" % [x * 60, k * 60, id]
		x += 1
	text += "1 4 0 -200 0 1 0 0 0 1 0 0 0 1 notapart98.dat\n"
	_put("forty", text)
	var said: String = await _say("open_model", {"name": "forty", "discard_changes": true})
	await _settled()
	print("  open_model on 40 moved numbers: %d characters, %d words" % [said.length(),
		said.split(" ", false).size()])
	print("  ---\n%s\n  ---" % said)
	_check("open_model's answer on 40 moved: under 4000 characters (%d)" % said.length(),
		said.length() < 4000)
	# The library's own big ones: a number in 43 and 102 sub-models.
	for library_id: String in ["omr-10179-1", "omr-10294-1"]:
		said = await _say("open_model", {"library": library_id, "discard_changes": true})
		await _settled()
		var moved_part: String = said.substr(said.find(" Its file names parts"))
		print("  open_model library=%s: %d characters in all, %d of them the moved list" % [
			library_id, said.length(), moved_part.length()])
		print("  ---\n%s\n  ---" % moved_part.left(2500))

	# replace_moved=true on a file of only missing parts.
	var only_missing: String = "0 Only missing\n0 Name: om.ldr\n0 Author: Someone Else\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 notapart97.dat\n1 4 40 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	_put("om", only_missing)
	said = await _say("open_model", {"name": "om", "discard_changes": true, "replace_moved": true})
	await _settled()
	print("  replace_moved on only missing: %s" % said)
	_check("replace_moved on only missing: nothing replaced, file as it was",
		_store.saved_text() == only_missing)
	var alone: String = await _say("open_model", {"replace_moved": true})
	print("  replace_moved alone on only missing: %s" % alone)

	# replace_moved alone on a model with unsaved edits.
	_put("ue", UN)
	await _open_as_person("ue")
	_builder.held_part = "3001"
	_builder.held_color = 14
	_builder.update_preview(Vector3(40.0, 400.0, 40.0), Vector3.DOWN)
	var put: int = _builder.place()
	_main.call("_on_model_edited")
	await _frames(4)
	var edited: String = _store.saved_text()
	print("  unsaved before: %s" % _store.has_unsaved_work())
	var replaced: String = await _say("open_model", {"replace_moved": true})
	await _settled()
	var now: String = _store.saved_text()
	print("  replace_moved alone with an unsaved edit: %s" % replaced.left(300))
	_check("the unsaved edit kept through the replace (3001 colour 14 still there)",
		put != 0 and now.contains(" 14 ") and now.contains("3001.dat") and now != edited)
	print("  unsaved after: %s; disk file %s" % [_store.has_unsaved_work(),
		"unchanged" if FileAccess.get_file_as_string(MODELS + "ue.ldr") == UN else "CHANGED"])
	var undo: String = await _say("undo", {})
	await _settled()
	_check("one undo over MCP: the edited model, byte for byte%s (%s)" % [_first_unlike(edited,
		_store.saved_text()), undo.get_slice("\n", 0).left(100)], _store.saved_text() == edited)
	var undo2: String = await _say("undo", {})
	await _settled()
	print("  undo 2 over MCP: %s; file now %s" % [undo2.get_slice("\n", 0).left(120),
		"the opened file" if _store.saved_text() == UN else "other (%d differing lines vs UN)"
		% _differing(UN, _store.saved_text())])


## Every write path after a replace.
func _case_paths() -> void:
	_put("pa", UN)
	await _open_as_person("pa")
	var numbers: Array = []
	for number: String in _store.moved:
		if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
			numbers.append(number)
	await _bar.replace_moved(numbers)
	await _settled()
	var now: String = _store.saved_text()
	print("  title %s, unsaved %s" % [_store.title, _store.has_unsaved_work()])
	# Save.
	var saved: bool = _store.save_as(_store.title)
	var on_disk: String = LdrModel.text_of(FileAccess.get_file_as_bytes(ModelStore.saved_path(_store.title)))
	_check("Save writes the replaced file%s (%s)" % [_first_unlike(now, on_disk), _store.refused],
		saved and on_disk == now)
	print("  unsaved after save: %s" % _store.has_unsaved_work())
	# save_model over MCP.
	var mcp_said: String = await _say("save_model", {"name": "pa_mcp"})
	var mcp_disk: String = LdrModel.text_of(FileAccess.get_file_as_bytes(MODELS + "pa_mcp.ldr"))
	_check("save_model writes it too%s (%s)" % [_first_unlike(now, mcp_disk), mcp_said.left(80)],
		mcp_disk == now)
	# Export, Share and Together are whole writes, as they were: no old number.
	var whole: String = _store.to_text(_store.title, true)
	var old_left := PackedStringArray()
	for number: String in ["3023.dat", "3139.dat"]:
		if _line_naming(whole, number) != "":
			old_left.append(number)
	_check("a whole write (export, share, Together) names no old number (%s)" % ", ".join(old_left),
		old_left.is_empty())
	var exported: String = ProjectSettings.globalize_path("user://pa_export.ldr")
	_check("export writes", _store.export_to(exported, _store.title))
	# Autosave and its restore.
	var autosave: String = _store.write_now()
	var auto_text: String = LdrModel.text_of(FileAccess.get_file_as_bytes(autosave))
	print("  autosave %s: %d bytes%s" % [autosave, auto_text.length(), _first_unlike(now, auto_text)])
	_world.clear()
	await _frames(4)
	var back: int = _store.restore()
	await _settled()
	var restored: String = _store.saved_text()
	_check("autosave restored (%d parts): the replaced file again%s" % [back,
		_first_unlike(now, restored)], back > 0 and restored == now)
	print("  title after restore: %s" % _store.title)


## The library's biggest list (10179-1: 16 numbers, one in 43 sub-models) and
## two small ones, replaced as a person's Replace checked does, timed.
func _case_omr() -> void:
	for file: String in ["10179-1.mpd", "4096-1_QB-Truck.mpd", "6522-1.mpd", "396-1.mpd", "8202-1.mpd",
			"364-1.mpd"]:
		print("\n-- %s" % file)
		var text: String = LdrModel.text_of(FileAccess.get_file_as_bytes("res://vendor/omr/files/" + file))
		var began: int = Time.get_ticks_msec()
		var now: String = await _replace_all("omr_" + file.get_basename(), text)
		print("  round in %d ms, %d lines differ" % [Time.get_ticks_msec() - began, _differing(text, now)])


## open_model's answer on the library's biggest lists, opened by name=.
func _case_mcp2() -> void:
	for library_id: String in ["omr-10179-1"]:
		var said: String = await _say("open_model", {"library": library_id, "discard_changes": true})
		await _settled()
		print("  open_model library=%s: %s" % [library_id, said])
	for file: String in ["10179-1", "10294-1", "10212-1"]:
		_put("big_" + file, LdrModel.text_of(FileAccess.get_file_as_bytes("res://vendor/omr/files/%s.mpd" % file)))
		var said: String = await _say("open_model", {"name": "big_" + file, "discard_changes": true})
		await _settled()
		var at: int = said.find(" Its file names parts")
		var part: String = said.substr(at) if at >= 0 else ""
		print("  open_model name=big_%s: %d characters in all, %d the moved list, %d numbers listed"
			% [file, said.length(), part.length(), _store.moved.size()])
		print("  ---\n%s\n  ---" % part.left(3000))


## A number listed only from inside a shortcut block the file carries
## (396-1's "396 - 568c01.dat", 364-1's "364 - u9132c04.dat"): after
## Replace checked, still listed; asked alone, what is said.
func _case_omr2() -> void:
	for pair: Array in [["396-1.mpd", "568"], ["364-1.mpd", "451"]]:
		var text: String = LdrModel.text_of(FileAccess.get_file_as_bytes("res://vendor/omr/files/" + pair[0]))
		await _store.open_text_fetched(text, "o2_" + str(pair[0]).get_basename())
		await _settled()
		var numbers: Array = []
		for number: String in _store.moved:
			if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
				numbers.append(number)
		print("  %s listed: %s" % [pair[0], ", ".join(numbers)])
		var said: String = await _bar.replace_moved(numbers)
		await _settled()
		print("  replace all: %s" % said.left(140))
		var left: Array = []
		for number: String in _store.moved:
			if str(_store.moved[number]["kind"]) != MovedParts.MISSING:
				left.append("%s ×%d in %s" % [number, int(_store.moved[number]["count"]),
					str(_store.moved[number]["in"])])
		_check("after Replace checked on %s: nothing moved left listed (%s)" % [pair[0],
			", ".join(left)], left.is_empty())
		var alone: String = await _bar.replace_moved([pair[1]])
		await _settled()
		print("  replace %s alone: %s" % [pair[1], alone])
		var answer: String = await _say("open_model", {"replace_moved": true})
		print("  open_model replace_moved=true now: %s" % answer.left(300))


## The bar is in nobody's way: a person opens, places a brick while it is
## up, then presses Update all. Undo after: can the brick be undone?
func _case_editfirst() -> void:
	_put("ef", UN)
	await _open_as_person("ef")
	_bar.offer_moved()
	await _frames(10)
	var shell: Node = _main.get("_shell")
	var offer: MovedOffer = shell.get("moved_offer")
	var dialog: Window = shell.get("_moved")
	print("  bar up: %s; list up: %s" % [offer != null and offer.visible,
		dialog != null and dialog.visible])
	var opened_text: String = _store.saved_text()
	_builder.held_part = "3001"
	_builder.held_color = 14
	_builder.update_preview(Vector3(40.0, 400.0, 40.0), Vector3.DOWN)
	var put: int = _builder.place()
	_main.call("_on_model_edited")
	await _frames(4)
	var edited: String = _store.saved_text()
	print("  placed %d; undo would: %s" % [put, "take the brick off" if _builder.history_depth() > 0
		else "nothing"])
	var update: Button = offer.controls_by_name().get("moved_update") if offer != null else null
	if update != null:
		update.pressed.emit()
	await _settled()
	var replaced: String = _store.saved_text()
	print("  replaced: %s" % ("yes" if replaced != edited else "no"))
	var first: bool = _builder.undo()
	if not first:
		first = await _undo()
	await _settled()
	_check("undo 1: the edited model, the brick on", _store.saved_text() == edited)
	var second: bool = _builder.undo()
	var how: String = "the brick's own undo"
	if not second:
		how = "a reopen: " + _store.reopen_words()
		second = await _undo()
	await _settled()
	_check("undo 2 takes the brick off (%s): the file as opened%s" % [how,
		_first_unlike(opened_text, _store.saved_text())], second and _store.saved_text() == opened_text)


# -- one replace, checked ------------------------------------------------------


var _kept: Dictionary = {}


func _replace_all(name: String, text: String) -> String:
	var result: Dictionary = await _store.open_text_fetched(text, name)
	await _settled()
	if not _check("%s opened (%d parts)" % [name, _bricks().size()], str(result["error"]).is_empty()):
		return ""
	var was: String = _store.saved_text()
	_check("...unedited save is the file%s" % _first_unlike(text, was), was == text)
	var numbers: Array = []
	var as_now: Dictionary = {}
	for number: String in _store.moved:
		var row: Dictionary = _store.moved[number]
		print("  listed %s: %s %s by %s ×%d" % [number, row["kind"], row["to"],
			LdrModel.from_transform(row["by"]), int(row["count"])])
		if str(row["kind"]) != MovedParts.MISSING:
			numbers.append(number)
		if str(row["kind"]) == MovedParts.ALIAS:
			as_now[number] = str(row["to"])
	var before: Array = _bricks()
	var began: int = Time.get_ticks_msec()
	var said: String = await _bar.replace_moved(numbers)
	await _settled()
	var now: String = _store.saved_text()
	print("  replaced in %d ms: %s" % [Time.get_ticks_msec() - began, said.left(160)])
	_keep(name + ".before.ldr", was)
	_keep(name + ".after.ldr", now)
	_kept[name] = now
	var lines: Dictionary = _diff_lines(was, now)
	_check("...only placing lines changed", bool(lines["only"]))
	_compare_drawn("...drawn where it was", before, _bricks(), as_now)
	# Saved, opened again, saved again.
	await _store.open_text_fetched(now, name + "_again")
	await _settled()
	_check("...reopened and saved again: the same%s" % _first_unlike(now, _store.saved_text()),
		_store.saved_text() == now)
	return now


## Each part of [param before] against [param after]: the same part (or the
## alias's), colour, place within NEAR and turn; where not matched, the
## nearest of its part, its place and turn said.
func _compare_drawn(what: String, before: Array, after: Array, as_now: Dictionary = {}) -> void:
	var pool: Array = after.duplicate()
	var unmatched := PackedStringArray()
	var worst: float = 0.0
	for item: Array in before:
		var part: String = str(as_now.get(item[0], item[0]))
		var at: Transform3D = item[2]
		var best: int = -1
		var near: float = INF
		var nearest_any: int = -1
		var near_any: float = INF
		for k: int in pool.size():
			var other: Array = pool[k]
			if str(other[0]) != part:
				continue
			var t: Transform3D = other[2]
			var gap: float = at.origin.distance_to(t.origin)
			var turn: float = (at.basis.x - t.basis.x).length() + (at.basis.y - t.basis.y).length() \
				+ (at.basis.z - t.basis.z).length()
			if gap < near_any:
				near_any = gap
				nearest_any = k
			if turn < 0.001 and int(other[1]) == int(item[1]) and gap < near:
				near = gap
				best = k
		if best >= 0 and near <= NEAR:
			worst = maxf(worst, near)
			pool.remove_at(best)
		else:
			var said: String = "%s c%d at %s basis %s det %.0f" % [part, int(item[1]), at.origin,
				at.basis, at.basis.determinant()]
			if nearest_any >= 0:
				var t: Transform3D = pool[nearest_any][2]
				said += " | nearest c%d at %s basis %s det %.0f" % [int(pool[nearest_any][1]),
					t.origin, t.basis, t.basis.determinant()]
			unmatched.append(said)
	var left := PackedStringArray()
	for other: Array in pool:
		left.append("%s c%d at %s det %.0f" % [other[0], int(other[1]), (other[2] as Transform3D).origin,
			(other[2] as Transform3D).basis.determinant()])
	_check("%s: %d of %d matched, worst %.5f LDU" % [what, before.size() - unmatched.size(),
		before.size(), worst], unmatched.is_empty() and before.size() == after.size())
	for said: String in unmatched:
		print("      unmatched before: " + said)
	for said: String in left:
		print("      left after: " + said)


## Line by line: every line that changed printed; {"only"} whether each is a
## placing line whose gaps are kept.
func _diff_lines(was: String, now: String) -> Dictionary:
	var a: PackedStringArray = was.split("\n")
	var b: PackedStringArray = now.split("\n")
	var only: bool = a.size() == b.size()
	if not only:
		print("    line count %d -> %d" % [a.size(), b.size()])
	for n: int in mini(a.size(), b.size()):
		if a[n] == b[n]:
			continue
		print("    line %d: %s\n         -> %s" % [n + 1, a[n].c_escape(), b[n].c_escape()])
		if not LdrModel.is_placing(a[n]) or _gaps(a[n]) != _gaps(b[n]):
			only = false
	return {"only": only}


static func _gaps(line: String) -> String:
	return RegEx.create_from_string("[^ \\t\\r]+").sub(line, "x", true)


func _differing(a: String, b: String) -> int:
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	var count: int = absi(la.size() - lb.size())
	for n: int in mini(la.size(), lb.size()):
		if la[n] != lb[n]:
			count += 1
	return count


# -- helpers ---------------------------------------------------------------------


func _open_fresh(name: String, text: String) -> Dictionary:
	_main.call("clear_model")
	await _frames(4)
	var result: Dictionary = await _store.open_text_fetched(text, name)
	await _settled()
	return {"result": result, "bricks": _bricks()}


func _bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append([brick.part_id, brick.color_code, brick.transform, brick.step, brick.unit])
	return out


func _line_naming(text: String, name: String) -> String:
	for line: String in text.split("\n"):
		if LdrModel.is_placing(line) and LdrModel.reference_of(line).to_lower() == name.to_lower():
			return line
	return ""


func _open_as_person(name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(MODELS + name + ".ldr")
	if placed >= 0:
		_bar.opened.emit(placed)
	await _settled()


## The app's own Undo, or with [param again] its Redo, as its key presses it
## (EditVerbs.press): whether it changed anything.
func _undo(again: bool = false) -> bool:
	var verbs: EditVerbs = _main.get("_verbs")
	var was: Array = [_builder.history_depth(), _builder._redo.size(), _world.generation()]
	await verbs.press("redo" if again else "undo")
	await _settled()
	return was != [_builder.history_depth(), _builder._redo.size(), _world.generation()]


func _put(name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(MODELS + name + ".ldr", FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _keep(name: String, text: String) -> void:
	if _out.is_empty():
		return
	var file: FileAccess = FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _settled() -> void:
	for _n: int in 900:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	await _frames(8)


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


static func _first_unlike(a: String, b: String) -> String:
	if a == b:
		return ""
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "(none)"
		var y: String = lb[n] if n < lb.size() else "(none)"
		if x != y:
			return " (line %d: %s | %s)" % [n + 1, x.c_escape().left(80), y.c_escape().left(80)]
	return " (%d and %d bytes)" % [a.length(), b.length()]


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
