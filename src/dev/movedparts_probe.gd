## Missing and moved parts on open (movedparts, APP_UX8 #15): a file's parts
## named by a number LDraw has moved or keeps as an alias, and those it has
## no file for, listed as it opens, and the moved and alias ones replaced in
## every sub-model in one undo.
##
##   godot --headless --path . --script src/dev/movedparts_probe.gd
##   tools/probe.sh movedparts_probe
##   tools/probe.sh movedparts_phone_probe     the list in a phone's window
##
## - omr: 10 files of the LDraw model repository with moved or alias parts
##   and 3 with parts the library has no file for (FILES), each opened as
##   it is: every such number listed with what it points to (the moved
##   number's last move, an alias's part of the same geometry) and how many
##   it places, as the file read here independently says. Then all of them
##   replaced: the file Save writes changes in only those lines, each only
##   in its name (and a turned stub's numbers), every one of them changed;
##   each part drawn where it was, within 0.01 LDU; one undo puts back the
##   file Save wrote before, byte for byte, and redo the replaced one.
## - attack: one file of its own, CRLF and tabs, holding a moved part in a
##   mirrored copy, a sub-model placed 3 times 2 deep, a stub that turns and
##   shifts its part (30028), a chain of two moves (179, 4073, 6141), a
##   printed part (11202p01c01), upper and lower case names and an alias
##   (4723): the same, and the file saved, opened again and saved again the
##   same (the save a later build reads).
## - dialog: a person's open shows the list (MovedPartsDialog): moved and
##   alias rows checked, a missing one with Search; one row unchecked and
##   Replace checked replaces the others only; Keep as is changes nothing;
##   Search puts the number in the parts bin's search.
## - mcp: open_model names each with its target and count, and
##   replace_moved=true gives the same file as the dialog's in 1 call.
## - words: the list, its rows and what the bar says of a replace, in
##   German, French and Spanish, nothing left in English but names,
##   numbers and keys.
## - phone (movedparts_phone_probe): the list wholly in a phone's window,
##   every check box and button 44 points or more each way.
##
##   MOVEDPARTS_CASES=omr,attack   those cases
##   MOVEDPARTS_OUT=/abs/dir       each file before and after kept there
extends SceneTree

const MODELS := "user://models/"
const OMR := "res://vendor/omr/files/"
## 10 with moved or alias parts, then 3 with parts the library has no file
## for (tools/scan of vendor/omr/files, 2026-11-15).
const FILES: Array[String] = ["4096-1_QB-Truck.mpd", "6965-1.mpd", "4096-1_Cement-Mixer.mpd",
	"4347-1_Robo.mpd", "4349-1_Dragon-Fly.mpd", "30055-1.mpd", "6522-1.mpd", "7210-1.mpd",
	"30034-1.mpd", "7808-1.mpd", "6056-1.mpd", "8198-1.mpd", "6990-1.mpd"]
const CASES: Array = ["omr", "attack", "dialog", "mcp", "words"]
const WATCHDOG := 1500.0
const NEAR := 0.01

## The attack's file: CRLF, tabs, a mirrored copy, a sub-model 3 times 2
## deep, a turned stub, a chain, a print, upper case and an alias.
const ATTACK := """0 FILE attack.ldr
0 Moved parts, attacked
0 Name: attack.ldr
0 Author: Someone Else
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat
1\t1\t40\t0\t0\t1\t0\t0\t0\t1\t0\t0\t0\t1\t3023.DAT
1 14 0 -8 60 0 0 1 0 1 0 -1 0 0 30028.dat
1 15 80 0 0 1 0 0 0 1 0 0 0 1 179.dat
1 15 100 0 0 1 0 0 0 1 0 0 0 1 4073.dat
1 4 120 -24 0 1 0 0 0 1 0 0 0 1 11202P01C01.DAT
1 2 0 0 -100 1 0 0 0 1 0 0 0 1 4723.dat
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
var _shell: Shell
var _bar: ModelBar
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = ""
## Each file's replaced text, as the dialog's replace wrote it: what
## open_model replace_moved=true must give.
var _replaced: Dictionary = {}
## The figures for the report.
var _listed: int = 0
var _lines: int = 0
var _worst: float = 0.0


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
		print("movedparts probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	var phone: bool = _phone()
	if phone:
		Phone._on = 1
		Phone._wide = false
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as carryrest_probe holds it.
	if phone and DisplayServer.get_name() != "headless":
		(_main.get("_phone") as Node).set_process(false)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _frames(20)
	_world = _main.get("_world")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	# An open is undone from the copy the store keeps of the model it took
	# off, which a probe's store keeps only when asked.
	_store.keeps = true
	_out = OS.get_environment("MOVEDPARTS_OUT")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	var cases: Array = ["phone"] if phone else CASES
	if not OS.get_environment("MOVEDPARTS_CASES").is_empty():
		cases = Array(OS.get_environment("MOVEDPARTS_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		var before: int = _failures
		match name:
			"omr": await _case_omr()
			"attack": await _case_attack()
			"dialog": await _case_dialog()
			"mcp": await _case_mcp()
			"words": await _case_words()
			"phone": await _case_phone()
			_: _check("no such case %s" % name, false)
		print("CASE %s: %s" % [name, "green" if _failures == before
			else "red, %d failed" % (_failures - before)])
	print("\nmovedparts: %d numbers listed, %d lines replaced, worst place %.5f LDU" % [_listed,
		_lines, _worst])
	print("movedparts probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the cases ----------------------------------------------------------------------


func _case_omr() -> void:
	for file: String in FILES:
		print("\n-- %s" % file)
		var text: String = _text_kept(OMR + file)
		if not _check("%s read" % file, not text.is_empty()):
			continue
		await _round(file.get_basename(), text, false)


func _case_attack() -> void:
	var text: String = ATTACK.replace("\n", "\r\n")
	var replaced: String = await _round("attack", text, true)
	if replaced.is_empty():
		return
	_check("...CRLF kept: %d line ends, %d of them CRLF" % [replaced.count("\n"),
		replaced.count("\r\n")], replaced.count("\n") == replaced.count("\r\n")
		and replaced.count("\n") == text.count("\n"))
	var tabbed: String = _line_naming(replaced, "3023b.DAT")
	_check("...the tabbed line kept its tabs, the name in the file's case: %s" % tabbed.c_escape(),
		tabbed.count("\t") == 14)
	_check("...the chain followed to its end: 179 and 4073 as 6141",
		_line_naming(replaced, "179.dat").is_empty() and _line_naming(replaced, "4073.dat").is_empty()
		and replaced.count("6141.dat") == 2)
	var turned: String = _line_naming(replaced, "30028b.dat")
	_check("...the turned stub's turn and shift put into its line: %s" % turned.strip_edges(),
		not turned.is_empty() and not turned.contains(" 0 -8 60 0 0 1 0 1 0 -1 0 0 "))
	_check("...the print as its print: %s" % _line_naming(replaced, "11403P01.DAT").strip_edges(),
		not _line_naming(replaced, "11403P01.DAT").is_empty())
	_check("...the alias as its part: %s" % _line_naming(replaced, "3046.dat").strip_edges(),
		not _line_naming(replaced, "3046.dat").is_empty())
	# Saved, opened again and saved again: the same file, and nothing listed.
	var round_trip: Dictionary = await _store.open_text_fetched(replaced, "attack_again")
	await _settled()
	var again: String = _store.saved_text()
	var renumbered: int = 0
	for row: Dictionary in _store.moved.values():
		renumbered += 0 if str(row["kind"]) == MovedParts.MISSING else 1
	_check("...saved, opened again (%s) and saved again, byte for byte%s; %d listed" % [
		round_trip["error"] if not str(round_trip["error"]).is_empty() else "opened",
		_first_unlike(replaced, again), renumbered], again == replaced and renumbered == 0)


## The dialog, as a person meets it.
func _case_dialog() -> void:
	var text: String = _text_kept(OMR + "4349-1_Dragon-Fly.mpd") if true else ""
	await _open_as_person("dragonfly", text)
	var dialog: Window = _shell.get("_moved")
	if not _check("a person's open shows Missing and moved parts", dialog != null and dialog.visible):
		return
	var state: Dictionary = dialog.call("page_state")
	var rows: Dictionary = state["rows"]
	print("  note: %s" % str(state["note"]).left(160))
	var listed: Dictionary = _store.moved
	var all_checked: bool = true
	for number: String in listed:
		var row: Dictionary = rows.get(number, {})
		var missing: bool = str(listed[number]["kind"]) == MovedParts.MISSING
		all_checked = all_checked and not row.is_empty() and bool(row["checked"]) != missing
		print("  row %s: %s%s" % [number, "[x] " if bool(row.get("checked", false)) else "",
			str(row.get("words", "(none)")).left(110)])
	_check("...a row for each of the %d numbers listed, moved and alias checked" % listed.size(),
		rows.size() == listed.size() and all_checked)
	var controls: Dictionary = dialog.call("controls_by_name")
	_check("...Replace checked and Keep as is named for a browser check",
		controls.has("moved_replace") and controls.has("moved_keep"))
	# One unchecked: the others replaced, it kept.
	var kept: String = "3023"
	(controls["moved_check_" + kept] as CheckBox).button_pressed = false
	var was: String = _store.saved_text()
	# The replace begins once the bar has said so, a few frames on, and
	# ends with the bar's opened.
	var ended: Array = [false]
	var on_opened: Callable = func(_count: int) -> void: ended[0] = true
	_bar.opened.connect(on_opened)
	dialog.emit_signal("confirmed")
	for _n: int in 1800:
		if ended[0]:
			break
		await process_frame
	_bar.opened.disconnect(on_opened)
	await _settled()
	var now: String = _store.saved_text()
	var left: Dictionary = _store.moved
	_check("...Replace checked with %s unchecked: it kept, %d others replaced" % [kept,
		listed.size() - 1], left.has(kept) and left.size() == 1 and now != was
		and _line_naming(now, "3023.dat") != "")
	var bar_undo: bool = await _bar.reopen()
	await _settled()
	_check("...one undo: the file as it was, byte for byte%s" % _first_unlike(was,
		_store.saved_text()), bar_undo and _store.saved_text() == was)
	# Keep as is: nothing changed.
	await _open_as_person("dragonfly_keep", text)
	dialog = _shell.get("_moved")
	var before: String = _store.saved_text()
	var keep: Button = (dialog.call("controls_by_name") as Dictionary).get("moved_keep")
	if keep != null:
		keep.pressed.emit()
	await _settled()
	_check("...Keep as is: closed, the file as it opened%s" % _first_unlike(before,
		_store.saved_text()), not dialog.visible and _store.saved_text() == before
		and before == text)
	# A part with no file: Search looks for it among the parts.
	await _open_as_person("lion", _text_kept(OMR + "6056-1.mpd"))
	dialog = _shell.get("_moved")
	var search: Button = null
	var number: String = ""
	for name: String in (dialog.call("controls_by_name") as Dictionary):
		if name.begins_with("moved_search_"):
			search = (dialog.call("controls_by_name") as Dictionary)[name]
			number = name.trim_prefix("moved_search_")
	if _check("...a part with no file offers Search (%s)" % number, search != null):
		search.pressed.emit()
		await _frames(10)
		var bin: PartsBin = _main.get("_bin")
		var typed: String = (bin.get("_search") as LineEdit).text
		_check("...Search puts %s in the parts bin's search (\"%s\")" % [number, typed],
			typed == number and not dialog.visible)
	# A session's open shows nothing.
	_put("quiet", text)
	await _say("open_model", {"name": "quiet", "discard_changes": true})
	await _settled()
	_check("...a session's open shows no dialog", not (_shell.get("_moved") as Window).visible)


## In German, French and Spanish: the list's title, buttons, note and rows,
## and what the bar says replacing, replaced, undone and refused, each found
## in the language with only names, numbers and keys left as they are.
func _case_words() -> void:
	# Sub-models, a moved part in three of them, and a part with no file.
	var text: String = ATTACK.replace("0 STEP\n0 NOFILE\n0 FILE wing.ldr",
		"1 4 0 -200 0 1 0 0 0 1 0 0 0 1 71303p01.dat\n0 STEP\n0 NOFILE\n0 FILE wing.ldr")
	await _open_as_person("words", text)
	var dialog: Window = _shell.get("_moved")
	if not _check("the list shows", dialog != null and dialog.visible):
		return
	var state: Dictionary = dialog.call("page_state")
	var texts := PackedStringArray([dialog.title, (dialog as ConfirmationDialog).ok_button_text,
		(dialog as ConfirmationDialog).cancel_button_text, "Search",
		"Look for %s among the parts" % "71303p01"])
	texts.append_array(str(state["note"]).split("\n"))
	for number: String in state["rows"]:
		texts.append(str(state["rows"][number]["words"]))
	var rows: Dictionary = _store.moved
	var replaced: String = ModelStore.replaced_words(rows.duplicate(), rows)
	texts.append_array([Keymap.filled("%s — {undo|puts them back}") % replaced,
		"undid: %s" % replaced, "redid: %s" % replaced,
		ModelStore.replaced_words({"3023": 1}, rows),
		"Replacing moved parts in %s…" % "words",
		"could not replace them: %s" % "the model is still being laid",
		"could not replace them: %s" % "this model is only looked at",
		"could not replace them: %s" % "none of those is a moved or alias part of this model",
		"could not replace them: %s" % "none of their lines is in the file now",
		"Leave Build together first: replacing them lays the model again"])
	var english: RegEx = RegEx.create_from_string(
		"(?i)\\b(moved|alias|used|model|file|library|replaced?|numbers?|keep|search|look|together|laid|undid|redid|puts)\\b")
	(dialog.call("controls_by_name")["moved_keep"] as Button).pressed.emit()
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var unsaid := PackedStringArray()
		for words: String in texts:
			var said: String = Language.says(words)
			var left: Array = Language.left_in_english(words)
			var english_left: Array = left.filter(func(part: String) -> bool:
				return english.search(part) != null and not part in ["wing", "tower", "floor"])
			if said.is_empty() or not english_left.is_empty():
				unsaid.append("%s%s" % [words.left(60), "" if said.is_empty() else " (left: %s)"
					% ", ".join(english_left)])
		print("  %s: %s" % [code, Language.says(str(state["rows"].values()[0]["words"]))])
		_check("...%s: all %d said in it%s" % [code, texts.size(), "" if unsaid.is_empty()
			else "; not: " + " | ".join(unsaid)], unsaid.is_empty())
	Language.apply("en")


## Over MCP: open_model names each, and replace_moved gives the dialog's file.
func _case_mcp() -> void:
	var stem: String = "4096-1_Cement-Mixer"
	var text: String = _text_kept(OMR + stem + ".mpd")
	_put("mp_mixer", text)
	var said: String = await _say("open_model", {"name": "mp_mixer", "discard_changes": true})
	await _settled()
	print("  open_model: %s" % said.left(400))
	var named: bool = not _store.moved.is_empty()
	for number: String in _store.moved:
		var row: Dictionary = _store.moved[number]
		named = named and said.contains(number) and said.contains(str(row["to"])) \
			and said.contains("%d used" % int(row["count"]))
	_check("open_model names each moved, alias and missing part, its target and count", named)
	var expected: String = str(_replaced.get(stem, ""))
	if expected.is_empty():
		await _round(stem, text, false)
		expected = str(_replaced.get(stem, ""))
	_put("mp_mixer2", text)
	var replaced: String = await _say("open_model", {"name": "mp_mixer2", "replace_moved": true,
		"discard_changes": true})
	await _settled()
	print("  open_model replace_moved=true: %s" % replaced.left(300))
	var got: String = _store.saved_text()
	_check("...replace_moved=true in 1 call gives the dialog's file, byte for byte%s"
		% _first_unlike(expected, got), not expected.is_empty() and got == expected)
	var undone: String = await _say("undo", {})
	await _settled()
	_check("...and one undo puts back the file as it was%s (%s)" % [_first_unlike(text,
		_store.saved_text()), undone.get_slice("\n", 0).left(100)], _store.saved_text() == text)
	# Alone: in the model open now.
	var alone: String = await _say("open_model", {"replace_moved": true})
	await _settled()
	_check("...replace_moved=true alone replaces in the model open now: %s" % alone.left(120),
		_store.saved_text() == expected)


## Laid out for a phone: movedparts_phone_probe, in a phone's window, or
## --phone here.
func _phone() -> bool:
	return "--phone" in OS.get_cmdline_user_args()


## In a phone's layout: wholly in the window, every target 44 points or more.
func _case_phone() -> void:
	# A moved part, to check, and one with no file, to search for.
	await _open_as_person("phone", _text_kept(OMR + "6056-1.mpd"))
	var dialog: Window = _shell.get("_moved")
	if not _check("the list shows in a phone's layout", dialog != null and dialog.visible):
		return
	await _frames(20)
	var title: int = dialog.get_theme_constant("title_height")
	var whole := Rect2(dialog.position - Vector2i(0, title), dialog.size + Vector2i(0, title))
	_check("...wholly in the window: %s in %s" % [whole, root.get_visible_rect()],
		root.get_visible_rect().grow(0.5).encloses(whole))
	var least: float = INF
	var small := PackedStringArray()
	var controls: Dictionary = dialog.call("controls_by_name")
	for name: String in controls:
		var control: Control = controls[name]
		var size: Vector2 = control.size / Phone.per_point(root)
		least = minf(least, minf(size.x, size.y))
		if size.x < Phone.TARGET - 0.5 or size.y < Phone.TARGET - 0.5:
			small.append("%s %.0fx%.0f" % [name, size.x, size.y])
	_check("...its %d targets each 44 points or more (least %.1f)%s" % [controls.size(), least,
		"" if small.is_empty() else ": " + ", ".join(small)], small.is_empty() and controls.size() >= 3)
	if not _out.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("phone.png"))
	var keep: Button = controls.get("moved_keep")
	if keep != null:
		keep.pressed.emit()


# -- one file round ------------------------------------------------------------------


## [param text] opened as [param name], its listing checked against the
## file read here, all of it replaced, checked line by line and place by
## place, then undone and redone. The replaced file; "" when it failed.
func _round(name: String, text: String, attack: bool) -> String:
	var result: Dictionary = await _store.open_text_fetched(text, name)
	await _settled()
	if not _check("%s opened (%d parts)" % [name, _bricks().size()], str(result["error"]).is_empty()):
		return ""
	var expected: Dictionary = _expected(text)
	var listed: Dictionary = _store.moved
	var wrong := PackedStringArray()
	for number: String in expected:
		var row: Dictionary = listed.get(number, {})
		var want: Dictionary = expected[number]
		if row.is_empty() or str(row["kind"]) != str(want["kind"]) or int(row["count"]) != int(want["count"]):
			wrong.append("%s %s ×%d, listed %s" % [number, want["kind"], int(want["count"]),
				"nothing" if row.is_empty() else "%s ×%d" % [row["kind"], int(row["count"])]])
		elif str(want["kind"]) == MovedParts.MOVED and str(row["to"]) != str(want["to"]):
			wrong.append("%s to %s, listed %s" % [number, want["to"], row["to"]])
		elif str(want["kind"]) == MovedParts.ALIAS and not _same_geometry(number, str(row["to"])):
			wrong.append("%s alias of %s: not its geometry" % [number, row["to"]])
	for number: String in listed:
		if not expected.has(number):
			wrong.append("%s listed, not in the file so" % number)
	var words := PackedStringArray()
	for number: String in listed:
		words.append("%s %s %s ×%d" % [number, listed[number]["kind"], listed[number]["to"],
			int(listed[number]["count"])])
	print("  listed: %s" % ", ".join(words))
	_listed += listed.size()
	_check("...every moved, alias and missing number listed with what it points to and its count%s"
		% ("" if wrong.is_empty() else ": " + "; ".join(wrong)), wrong.is_empty() and not listed.is_empty())
	var renumbered: Array = []
	for number: String in listed:
		if str(listed[number]["kind"]) != MovedParts.MISSING:
			renumbered.append(number)
	var was: String = _store.saved_text()
	_check("...an unedited save is the file, byte for byte%s" % _first_unlike(text, was), was == text)
	if renumbered.is_empty():
		return ""
	var before: Array = _bricks()
	var rows: Dictionary = listed.duplicate(true)
	var said: String = await _bar.replace_moved(renumbered)
	await _settled()
	var now: String = _store.saved_text()
	_keep(name + ".before.ldr", was)
	_keep(name + ".after.ldr", now)
	print("  replaced: %s" % said.left(160))
	var diff: Dictionary = _only_numbers(was, now, rows)
	_lines += int(diff["changed"])
	_check("...Save's file changes only those numbers, %d lines of %d placing them%s" % [
		int(diff["changed"]), int(diff["placing"]), "" if str(diff["wrong"]).is_empty()
		else ": " + str(diff["wrong"])], str(diff["wrong"]).is_empty()
		and int(diff["changed"]) == int(diff["placing"]) and int(diff["changed"]) > 0)
	var moved_left: int = 0
	for row: Dictionary in _store.moved.values():
		moved_left += 0 if str(row["kind"]) == MovedParts.MISSING else 1
	_check("...none left to replace (%d)" % moved_left, moved_left == 0)
	# An alias was drawn as itself, and is now its part of the same shape.
	var as_now: Dictionary = {}
	for number: String in rows:
		if str(rows[number]["kind"]) == MovedParts.ALIAS:
			as_now[number] = str(rows[number]["to"])
	var placed: Dictionary = _same_places(before, _bricks(), as_now)
	_worst = maxf(_worst, float(placed["worst"]))
	_check("...each part drawn where it was: %d of %d, worst %.5f LDU%s" % [int(placed["matched"]),
		before.size(), float(placed["worst"]), str(placed["first"])],
		int(placed["matched"]) == before.size() and float(placed["worst"]) <= NEAR)
	_replaced[name] = now
	var undone: bool = await _bar.reopen()
	await _settled()
	var back: String = _store.saved_text()
	_check("...one undo puts back Save's file byte for byte%s" % _first_unlike(was, back),
		undone and back == was)
	_check("...and the model as it was: %d parts in their places" % _bricks().size(),
		int(_same_places(before, _bricks())["matched"]) == before.size())
	var redone: bool = await _bar.reopen(true)
	await _settled()
	_check("...redo: the replaced file again, byte for byte%s" % _first_unlike(now,
		_store.saved_text()), redone and _store.saved_text() == now)
	if attack:
		print("  attack's lines after:")
		for line: String in now.split("\n"):
			if LdrModel.is_placing(line):
				print("    " + line.c_escape())
	return now


## What the file says, read here: each number its models and sub-models
## place that the library has as a moved stub, an alias or nothing, with its
## kind, the part it points to and how many parts it places.
func _expected(text: String) -> Dictionary:
	var library: PartLibrary = _store.library
	var model: LdrModel = LdrModel.parse(text.trim_prefix(LdrModel.bom()), "expected")
	var out: Dictionary = {}
	for placement: LdrModel.Placement in model.flatten(library.parts):
		var number: String = placement.part_id
		var kind: String = ""
		var to: String = ""
		var info: PartLibrary.PartInfo = library.parts.get(ModelStore.studio_part(number, library))
		if info == null:
			kind = MovedParts.MISSING
		elif info.is_redirect():
			kind = MovedParts.MOVED
			to = info.id
			for _hop: int in 8:
				var at: PartLibrary.PartInfo = library.parts.get(to)
				if at == null or not at.is_redirect() or not library.parts.has(at.moved_to):
					break
				to = at.moved_to
		elif info.kind.contains("Alias"):
			kind = MovedParts.ALIAS
		if kind.is_empty():
			continue
		if not out.has(number):
			out[number] = {"kind": kind, "to": to, "count": 0}
		out[number]["count"] = int(out[number]["count"]) + 1
	# The app's own file writes a moved part by its new number already.
	if model.author.strip_edges() == "Brickworks":
		for number: String in out.keys():
			if str(out[number]["kind"]) == MovedParts.MOVED:
				out.erase(number)
	return out


func _same_geometry(alias: String, to: String) -> bool:
	var a: PartLibrary.PartInfo = _store.library.parts.get(alias)
	var b: PartLibrary.PartInfo = _store.library.parts.get(to)
	# An alias is named "=" and the part it stands for ("=Slope Brick 31 …"),
	# read here apart from any shape.
	var said: String = " ".join(a.name.trim_prefix("=").split(" ", false)) if a != null else "?"
	return a != null and b != null and a.mesh_hash == b.mesh_hash and not b.is_redirect() \
		and not b.kind.contains("Alias") and a.name.begins_with("=") \
		and " ".join(b.name.split(" ", false)).begins_with(said)


## Line by line, [param was] against [param now]: each line that changed is
## a placing line of a number [param rows] lists, now naming the part it
## points to, its colour and gaps as they were, and its numbers too unless
## its stub turns or shifts the part. {"changed", "placing" (the lines of the
## model and its sub-models that place a listed number), "wrong"}.
func _only_numbers(was: String, now: String, rows: Dictionary) -> Dictionary:
	var a: PackedStringArray = was.split("\n")
	var b: PackedStringArray = now.split("\n")
	var out: Dictionary = {"changed": 0, "placing": 0, "wrong": ""}
	var model: LdrModel = LdrModel.parse(was.trim_prefix(LdrModel.bom()), "was")
	for sub: LdrModel.SubModel in model.submodels.values():
		if sub.library_file:
			continue
		var seen: Dictionary = {}
		for placement: LdrModel.Placement in sub.placements:
			var row: Dictionary = rows.get(placement.part_id, {})
			if not row.is_empty() and str(row["kind"]) != MovedParts.MISSING and not seen.has(placement.line):
				seen[placement.line] = true
				out["placing"] = int(out["placing"]) + 1
	if a.size() != b.size():
		out["wrong"] = "%d lines, then %d" % [a.size(), b.size()]
		return out
	for n: int in a.size():
		if a[n] == b[n]:
			continue
		out["changed"] = int(out["changed"]) + 1
		var wa: PackedStringArray = LdrModel._fields(a[n])
		var wb: PackedStringArray = LdrModel._fields(b[n])
		var number: String = LdrModel.stem(LdrModel.reference_of(a[n]))
		var row: Dictionary = rows.get(number, {})
		var why: String = ""
		if wa.size() < 15 or wa[0] != "1" or wb.size() != wa.size():
			why = "not a placing line"
		elif row.is_empty() or str(row["kind"]) == MovedParts.MISSING:
			why = "%s is not listed to replace" % number
		elif LdrModel.stem(LdrModel.reference_of(b[n])) != str(row["to"]):
			why = "names %s, not %s" % [LdrModel.reference_of(b[n]), row["to"]]
		elif wa[1] != wb[1]:
			why = "its colour changed"
		elif _gaps(a[n]) != _gaps(b[n]):
			why = "its gaps changed"
		elif (row["by"] as Transform3D).is_equal_approx(Transform3D.IDENTITY) \
				and " ".join(wa.slice(2, 14)) != " ".join(wb.slice(2, 14)):
			why = "its numbers changed"
		if not why.is_empty() and str(out["wrong"]).is_empty():
			out["wrong"] = "line %d %s (%s -> %s)" % [n + 1, why, a[n].strip_edges(), b[n].strip_edges()]
	return out


## A line with each field one letter: its gaps, tabs and end as they are.
static func _gaps(line: String) -> String:
	return RegEx.create_from_string("[^ \\t\\r]+").sub(line, "x", true)


## The parts on the baseplate, as [part, colour, transform].
func _bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append([brick.part_id, brick.color_code, brick.transform])
	return out


## Each of [param before] matched to one of [param after] of its part (or
## the part [param as_now] names for it) and colour, its place within NEAR
## and its turn the same: {"matched", "worst" (the farthest a matched part
## moved), "first" (the first not matched)}.
static func _same_places(before: Array, after: Array, as_now: Dictionary = {}) -> Dictionary:
	var by: Dictionary = {}
	for item: Array in after:
		var key: String = "%s|%d" % [item[0], item[1]]
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(item[2])
	var matched: int = 0
	var worst: float = 0.0
	var first: String = ""
	for item: Array in before:
		var key: String = "%s|%d" % [as_now.get(item[0], item[0]), item[1]]
		var at: Transform3D = item[2]
		var pool: Array = by.get(key, [])
		var best: int = -1
		var near: float = INF
		for k: int in pool.size():
			var other: Transform3D = pool[k]
			var gap: float = at.origin.distance_to(other.origin)
			var turn: float = (at.basis.x - other.basis.x).length() + (at.basis.y - other.basis.y).length() \
				+ (at.basis.z - other.basis.z).length()
			if turn < 0.001 and gap < near:
				near = gap
				best = k
		if best >= 0 and near <= NEAR:
			matched += 1
			worst = maxf(worst, near)
			pool.remove_at(best)
		elif first.is_empty():
			first = "; %s at %s not found%s" % [key, at.origin,
				"" if best < 0 else " (nearest %.4f)" % near]
	return {"matched": matched, "worst": worst, "first": first}


func _line_naming(text: String, name: String) -> String:
	for line: String in text.split("\n"):
		if LdrModel.is_placing(line) and LdrModel.reference_of(line) == name:
			return line
	return ""


## [param text] opened as a person opens a file of theirs: put in their
## models and opened from File, Open, then the list offered.
func _open_as_person(name: String, text: String) -> void:
	_put(name, text)
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(MODELS + name + ".ldr")
	if placed >= 0:
		_bar.opened.emit(placed)
		_bar.offer_moved()
	await _settled()


# -- helpers --------------------------------------------------------------------------


static func _text_kept(path: String) -> String:
	return LdrModel.text_of(FileAccess.get_file_as_bytes(path))


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


## Where two texts first differ, said: "" when they are the same.
static func _first_unlike(a: String, b: String) -> String:
	if a == b:
		return ""
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "(none)"
		var y: String = lb[n] if n < lb.size() else "(none)"
		if x != y:
			return " (line %d: %s | %s)" % [n + 1, x.strip_edges().left(70), y.strip_edges().left(70)]
	return " (%d and %d bytes)" % [a.length(), b.length()]


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
