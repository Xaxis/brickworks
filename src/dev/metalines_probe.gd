## The app's own lines in a model's file ("0 !BRICKWORKS ...") are found
## once and written once (MetaIndex, metalines): a save keeps every line it
## cannot read, where the file has it; each line written ends as the file's
## lines do; an unedited save is the file, byte for byte.
##
##   godot --headless --path . --script src/dev/metalines_probe.gd
##
## Each case opens its file as a person does (open_model over MCP, from the
## person's models), makes the edit the feature that owns the lines makes,
## saves as Save does (the bar's Save; save_model over MCP; Save As), opens
## the save again and saves it again. The faults, from the brief
## (APP_UX7 #2), each red on the base this was built from:
## - newer_view: a view line a later build wrote went at the next save,
##   unsaid; now kept byte for byte where it was, and the open says so;
## - motions: a refused MOTION_KEY moved after the keys read (kt5check F1),
##   and a car's MOTION_PATH, WHEEL and STEER lines kept in place;
## - crlf30: 3 files whose lines end CRLF, each edited 10 ways (floor, view,
##   light, step name, page, motion, hidden colours, cut, set and link,
##   Save As a new name) and saved: no line ends LF alone;
## - pictures: a sub-model's page picture kept over a save, and the model's
##   new picture behind its pages under a name of its own (booklook2);
## - empty_step: a step edit keeps a file's own empty step and its looks
##   (pkreview3);
## - name_twice: a step renamed to its second name line says it once
##   (sncheck N1);
## - undo_open: an open undone gives back the light lines it could not read;
## - sub_lines: a sub-model's FLOOR, CUT_AWAY, BIN, SHARE, FROM_SET and PIN
##   lines are its own: not read as the model's, not moved, not lost;
## - no_title: a model with no title line, and one with sub-models, saved
##   twice whole is one file, and gains no TITLE line (cfcheck);
## - name_bump: a model named apart from a section of its file says that
##   name on its Name line; a file of tabs' autosave comes back with its
##   parts; LDCad's group definitions kept in a whole write (sf2check);
## - unedited: someone else's file opened and saved with nothing changed is
##   the file, byte for byte, from the bar and over MCP, with no FLOOR GRID
##   or TITLE added and no look line moved (hscheck);
## - tabs: tabs between the words, a CR in a file of LF and "0 FiLe" read
##   as LDraw reads them, and a line changed where it was;
## - castle: a whole write of the castle, in ms and ms per MB, said for the
##   cost (METALINES_CASTLE_MS_PER_MB: the most it may be).
##
##   METALINES_CASES=newer_view,motions   those cases
##   METALINES_OUT=/abs/dir               every save copied there
extends SceneTree

const MODELS := "user://models/"
const FX := "res://src/dev/fixtures/metalines/"
const CASES: Array = ["newer_view", "motions", "crlf30", "pictures", "empty_step", "name_twice",
	"undo_open", "sub_lines", "no_title", "name_bump", "unedited", "tabs", "castle"]
const WATCHDOG := 2400.0
const ORBIT := "0 !BRICKWORKS VIEW {\"name\":\"orbit\",\"path\":[[0,0,0],[40,0,0]],\"kind\":\"orbit\",\"speed\":2}"
const SPRING := "0 !BRICKWORKS MOTION_KEY \"Lift\" 1 1 45 SPRING"
const LASER := "0 !BRICKWORKS LIGHT {\"kind\":\"laser\",\"at\":[0,-200,0]}"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0
var _out: String = ""
## crlf30's count of LF-only lines, by edit.
var _lf_by_edit: Dictionary = {}


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
		print("metalines probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_out = OS.get_environment("METALINES_OUT")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	print("BUILD has MetaIndex: %s" % ResourceLoader.exists("res://src/parts/meta_index.gd"))
	var cases: Array = CASES if OS.get_environment("METALINES_CASES").is_empty() \
		else Array(OS.get_environment("METALINES_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		var before: int = _failures
		match name:
			"newer_view": await _case_newer_view()
			"motions": await _case_motions()
			"crlf30": await _case_crlf30()
			"pictures": await _case_pictures()
			"empty_step": await _case_empty_step()
			"name_twice": await _case_name_twice()
			"undo_open": await _case_undo_open()
			"sub_lines": await _case_sub_lines()
			"no_title": await _case_no_title()
			"name_bump": await _case_name_bump()
			"unedited": await _case_unedited()
			"tabs": await _case_tabs()
			"castle": await _case_castle()
			_: _check("no such case %s" % name, false)
		print("CASE %s: %s" % [name, "green" if _failures == before
			else "red, %d failed" % (_failures - before)])
	print("\nmetalines probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the cases ----------------------------------------------------------------------


const NEWER_VIEW := """0 FILE nv.ldr
0 Newer view
0 Name: nv.ldr
0 Author: Someone Else
0 !BRICKWORKS VIEW {"distance":400,"focus":[0,0,0],"name":"main view","pitch":-25,"yaw":30}
%s
0 !BRICKWORKS VIEW {"distance":300,"focus":[0,0,0],"name":"side","pitch":-10,"yaw":90}
1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
0 NOFILE
"""


## A view line a later build wrote (a kind of view this one cannot read):
## kept byte for byte between the views either side of it, through a view
## saved and a save, and said by the open.
func _case_newer_view() -> void:
	var text: String = NEWER_VIEW % ORBIT
	await _open("ml_newer_view", text)
	var said: String = ModelBar.unshown_words(_store)
	_check("the open says a view line is kept unread (\"%s\")" % said.strip_edges(),
		said.contains("view line"))
	print("  save_view: %s" % (await _say("save_view", {"name": "Top"})).get_slice("\n", 0).left(120))
	var saved: String = await _bar_save("newer_view_1")
	var lines: PackedStringArray = saved.split("\n")
	var at: int = lines.find(ORBIT)
	var main_at: int = _index_of(lines, "\"name\":\"main view\"")
	var side_at: int = _index_of(lines, "\"name\":\"side\"")
	_check("the later build's view line back byte for byte (line %d)" % at, at >= 0
		and saved.count(ORBIT) == 1)
	_check("...where it was, between the views either side (%d < %d < %d)" % [main_at, at, side_at],
		main_at >= 0 and main_at < at and at < side_at)
	_check("...and the view saved, written (%s)" % str(saved.contains("\"name\":\"Top\"")),
		saved.contains("\"name\":\"Top\""))
	await _reopen_same("newer_view", saved)


## kt5check F1: the refused key between the keys either side of it; an
## unknown word's lines kept; a car's drive lines kept, each edited by a
## motion of its own put in.
func _case_motions() -> void:
	for name: String in ["apps.mpd", "drive.ldr"]:
		var text: String = _with_hinge(_fixture(name))
		await _open("ml_motions_" + name.get_basename(), text)
		var lead: int = _id_of("3938")
		var kept: String = await _say("define_motion", {"name": "Probe swing", "tracks": [
			{"joint": "#%d" % lead, "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 30}]}]})
		print("  %s define_motion on #%d: %s" % [name, lead, kept.get_slice("\n", 0).left(100)])
		var saved: String = await _bar_save("motions_" + name.get_basename())
		# And written whole, as the app's own file is and someone else's is
		# where the patch cannot be made (kt5check found the move there).
		var whole: String = _store.to_text(_store.title, true)
		_keep("motions_%s_whole.ldr" % name.get_basename(), whole)
		for written: Array in [["saved", saved], ["written whole", whole]]:
			var lines: PackedStringArray = str(written[1]).split("\n")
			for line: String in text.split("\n"):
				if line.contains("MOTION_PATH") or line.contains("MOTION_WHEEL") \
						or line.contains("MOTION_STEER") or line.contains("FUTURE_KIND") \
						or line.contains("VIEW_EXTRA"):
					_check("%s %s: kept byte for byte: %s" % [name, written[0], line.left(60)],
						lines.has(line))
			if name == "apps.mpd":
				var spring: int = lines.find(SPRING)
				var zero: int = _index_of(lines, "MOTION_KEY \"Lift\" 1 0 0 EASE")
				var ninety: int = _index_of(lines, "MOTION_KEY \"Lift\" 1 2 90 EASE")
				_check("apps.mpd %s: the refused key between the 0 and 90 keys (%d < %d < %d)"
					% [written[0], zero, spring, ninety], zero >= 0 and zero < spring
					and spring < ninety)
		_check("%s: the motion put in is written (%s)" % [name, str(saved.contains("Probe swing"))],
			saved.contains("Probe swing") or lead == 0)
		await _reopen_same("motions_" + name.get_basename(), saved)


## 3 files of CRLF lines, each edited 10 ways and saved: no line of any
## save ends LF alone.
func _case_crlf30() -> void:
	var total: int = 0
	var files: int = 0
	# Two of someone else's, saved as patches, and one of the app's own,
	# written whole.
	for name: String in ["apps.mpd", "F_theirs_lf.ldr", "empty_own.ldr"]:
		var raw: String = _fixture(name) if name != "empty_own.ldr" \
			else FileAccess.get_file_as_string("res://src/dev/fixtures/pullkept/empty_own.ldr")
		var text: String = _with_hinge(raw).replace("\r\n", "\n").replace("\n", "\r\n")
		for edit: String in ["floor", "view", "light", "step_name", "page", "motion", "hidden",
				"cut", "set_link", "save_as"]:
			var case_name: String = "ml_crlf_%s_%s" % [name.get_basename(), edit]
			await _open(case_name, text)
			var saved: String = await _crlf_edit(edit, case_name)
			var lf: int = _lf_only(saved)
			total += lf
			files += 1
			_lf_by_edit[edit] = int(_lf_by_edit.get(edit, 0)) + lf
			if lf > 0:
				print("    %s %s: %d lines end LF alone, first: %s" % [name, edit, lf,
					_first_lf(saved).c_escape().left(100)])
	print("  LF-only lines by edit: %s" % JSON.stringify(_lf_by_edit))
	_check("%d CRLF files edited and saved: %d lines end LF alone" % [files, total],
		total == 0 and files == 30)


func _crlf_edit(edit: String, case_name: String) -> String:
	var said: String = ""
	match edit:
		"floor":
			said = await _say("set_floor", {"kind": "baseplate", "across": 16})
		"view":
			said = await _say("save_view", {"name": "Crlf view"})
		"light":
			said = await _say("light_model", {"op": "add", "kind": "point"})
		"step_name":
			said = await _say("edit_steps", {"op": "name", "step": 1, "name": "First of crlf"})
		"page":
			said = await _say("page_setup", {"size": "A5"})
		"motion":
			var lead: int = _id_of("3938")
			said = await _say("define_motion", {"name": "Crlf swing", "tracks": [
				{"joint": "#%d" % lead, "keys": [{"t": 0, "place": 0}, {"t": 1, "place": 30}]}]})
		"hidden":
			said = await _say("colour_hidden_parts", {"mode": HiddenColours.MODES[1], "apply": true,
				"agreed": true})
		"cut":
			_world.cut_kept = {"shape": "plane", "axis": "x", "at": 11.0, "away": 1, "ghosts": false}
			said = "cut set"
		"set_link":
			_store.from_set = "6780-1"
			_store.share_id = "crlfshare1"
			said = "set and link set"
		"save_as":
			var ok: bool = _store.save_as("Crlf renamed " + case_name.right(12))
			var bar: ModelBar = _main.get("_bar")
			await _frames(6)
			var text: String = FileAccess.get_file_as_string(MODELS + bar.model_name() + ".ldr")
			print("    save_as %s: %s" % [bar.model_name(), ok])
			_keep(case_name + ".ldr", text)
			return text
	await _frames(6)
	print("    %s: %s" % [edit, said.get_slice("\n", 0).left(90)])
	return await _bar_save(case_name.trim_prefix("ml_"))


## The sub-model's page picture as the file has it, kept: over a save with
## nothing changed, and over the model given a picture behind its pages
## named as the sub-model's is, which goes in under a name of its own.
func _case_pictures() -> void:
	var text: String = _fixture("sub_pic.mpd")
	var block: String = text.substr(text.find("0 !DATA brickworks-page-behind.jpg"))
	await _open("ml_pictures", text)
	var saved: String = await _bar_save("pictures_1_unedited")
	_check("saved unedited: the sub-model's picture kept, byte for byte", saved.contains(block))
	_check("...the file, byte for byte%s" % _first_unlike(text, saved), saved == text)
	var image: Image = Image.create_empty(32, 24, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.5, 0.8))
	var data: String = Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.8))
	print("  page_setup picture: %s" % (await _say("page_setup", {"picture_data": data}))
		.get_slice("\n", 0).left(120))
	saved = await _bar_save("pictures_2_main_picture")
	var names: PackedStringArray = PackedStringArray()
	for line: String in saved.split("\n"):
		if line.begins_with("0 !DATA "):
			names.append(line.substr(8).strip_edges())
	_check("the sub-model's picture still its own, byte for byte", saved.contains(block.strip_edges()))
	_check("...two pictures, two names: %s" % ", ".join(names), names.size() == 2
		and names[0] != names[1])
	var sub_setup: bool = saved.contains("0 !BRICKWORKS PAGE_SETUP A5 PICTURE brickworks-page-behind.jpg")
	_check("...the sub-model's page still names its own", sub_setup)
	await _reopen_same("pictures", saved)


## pkreview3: a part moved on a step: the file's own empty step stays, with
## its seven look lines in it, in their order.
func _case_empty_step() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/dev/fixtures/pullkept/empty_own.ldr")
	await _open("ml_empty_step", text)
	var moved: int = _id_of("3001")
	print("  edit_steps next #%d: %s" % [moved, (await _say("edit_steps", {"op": "next",
		"bricks": [moved]})).get_slice("\n", 0).left(120)])
	var saved: String = await _bar_save("empty_step")
	var looks := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("0 !BRICKWORKS ") and not line.contains("AUTHORED_STEPS"):
			looks.append(line)
	var lines: PackedStringArray = saved.split("\n")
	var at: int = -1
	var order: bool = true
	for line: String in looks:
		var found: int = lines.find(line)
		order = order and found > at
		at = found
	_check("the empty step's %d look lines kept, in order" % looks.size(), order and at >= 0)
	# In a step of their own: no part line from the STEP before them to the one after.
	var first: int = lines.find(looks[0])
	var start: int = first
	while start > 0 and not lines[start].begins_with("0 STEP"):
		start -= 1
	var end: int = first
	while end < lines.size() and not lines[end].begins_with("0 STEP"):
		end += 1
	var parts_in: int = 0
	for n: int in range(start + 1, end):
		if lines[n].begins_with("1 "):
			parts_in += 1
	_check("...in a step of their own, empty (%d parts in it)" % parts_in, first >= 0
		and parts_in == 0 and start > 0)


## sncheck N1: step 2 named as its second name line says: said once.
func _case_name_twice() -> void:
	var text: String = _fixture("merge_theirs_five.ldr")
	await _open("ml_name_twice", text)
	print("  edit_steps name: %s" % (await _say("edit_steps", {"op": "name", "step": 2,
		"name": "Charlie one"})).get_slice("\n", 0).left(120))
	var saved: String = await _bar_save("name_twice")
	var count: int = saved.count("STEP_NAME Charlie one")
	_check("\"Charlie one\" said once (%d)" % count, count == 1)
	_check("...\"Bravo bricks\" gone (%d)" % saved.count("STEP_NAME Bravo bricks"),
		saved.count("STEP_NAME Bravo bricks") == 0)
	await _reopen_same("name_twice", saved)


## An open undone: the light lines its file had that this cannot read are
## the model's again, said, and saved.
func _case_undo_open() -> void:
	var text: String = _fixture("merge_theirs_five.ldr")
	# An open is undone from the copy the store keeps of the model it took
	# off (ModelStore.reopen), which a probe's store keeps only when asked.
	_store.keeps = true
	await _open("ml_undo_open", text)
	var unread: String = _store.lights_unread_words
	_put("ml_undo_other", "0 Other\n0 Name: ml_undo_other.ldr\n0 Author: Someone\n"
		+ "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	print("  open another: %s" % (await _say("open_model", {"name": "ml_undo_other"}))
		.get_slice("\n", 0).left(100))
	await _settled()
	var bar: ModelBar = _main.get("_bar")
	var back: bool = await bar.reopen()
	await _settled()
	print("  undo of the open: %s; lights unread before \"%s\", after \"%s\"" % [back, unread,
		_store.lights_unread_words])
	_check("the open undone", back)
	_check("...its unread light said again", not unread.is_empty()
		and _store.lights_unread_words == unread)
	var saved: String = await _bar_save("undo_open")
	_store.keeps = false
	_check("...and saved, byte for byte where it was", saved.contains("\n" + LASER + "\n")
		and saved.find(LASER) < saved.find("0 !BRICKWORKS FLOOR GRID"))


## A sub-model's own lines: not the model's on the open, kept in the
## sub-model as they are over an edit of the model's own and a save.
func _case_sub_lines() -> void:
	var cut: String = CutShape.META + JSON.stringify({"shape": "plane", "axis": "x", "at": 11.0,
		"away": 1, "ghosts": false})
	var pin: String = "0 !BRICKWORKS PIN {\"id\":\"p1\",\"part\":\"3001\",\"colour\":4,\"at\":[0,0,0],"
	var sub := PackedStringArray(["0 !BRICKWORKS FLOOR BASEPLATE 32 24 2", cut,
		SetBin.META + "10497-1", ModelStore.SHARE_META + "abc123share", ModelStore.SET_META + "6780-1",
		pin + "\"text\":\"Sub pin\",\"by\":\"Ana\",\"tint\":\"#ffcc00\",\"when\":\"2026-11-01\"}"])
	var main_pin: String = pin + "\"text\":\"Main pin\",\"by\":\"Ana\",\"tint\":\"#ffcc00\",\"when\":\"2026-11-01\"}"
	var text: String = "0 FILE main.ldr\n0 Sub lines\n0 Name: main.ldr\n0 Author: Someone Else\n" \
		+ main_pin + "\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
		+ "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 sub.ldr\n0 NOFILE\n" \
		+ "0 FILE sub.ldr\n0 Sub\n0 Name: sub.ldr\n0 Author: Someone Else\n" + "\n".join(sub) \
		+ "\n1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat\n0 NOFILE\n"
	await _open("ml_sub_lines", text)
	var pins: Array = _store.pins.list if _store.pins != null else []
	_check("opened: the model's floor its own (%s)" % _store.model_floor.to_meta(),
		not _store.model_floor.to_meta().contains("32 24"))
	_check("...no cut, bin, link or set of the sub-model's (%s %s \"%s\" \"%s\")" % [
		str(not _world.cut_kept.is_empty()), str(_store.bin_sets), _store.share_id, _store.from_set],
		_world.cut_kept.is_empty() and _store.bin_sets.is_empty() and _store.share_id.is_empty()
		and _store.from_set.is_empty())
	_check("...one pin, the model's (%d: %s)" % [pins.size(), pins[0].text if not pins.is_empty() else ""],
		pins.size() == 1 and pins[0].text == "Main pin")
	print("  set_floor: %s" % (await _say("set_floor", {"kind": "baseplate", "across": 16}))
		.get_slice("\n", 0).left(100))
	var saved: String = await _bar_save("sub_lines")
	var sub_at: int = saved.find("0 FILE sub.ldr")
	for line: String in sub:
		var at: int = saved.find(line)
		_check("the sub-model's line kept in it byte for byte: %s" % line.left(60),
			at > sub_at and saved.count(line) == 1)
	_check("...the model's pin and floor in the model", saved.find(main_pin) < sub_at
		and saved.find("FLOOR BASEPLATE 16") < sub_at and saved.find("FLOOR BASEPLATE 16") > 0)
	await _reopen_same("sub_lines", saved)


## cfcheck: a model with no title line, and one with sub-models: written
## whole, opened again and written whole again, one file, no TITLE added.
func _case_no_title() -> void:
	for name: String in ["cfc_noheader.mpd", "cfc_nested.mpd"]:
		var text: String = FileAccess.get_file_as_string("res://src/dev/fixtures/" + name)
		await _open("ml_no_title_" + name.get_basename(), text)
		_world.saved_views = [{"name": "front", "yaw": 0.5, "pitch": 0.3, "distance": 400.0,
			"focus": [0.0, 0.0, 0.0], "square": false}]
		_world.cut_kept = {"shape": "plane", "axis": "x", "at": 11.0, "away": 1, "ghosts": false}
		_store.from_set = "6780-1"
		var title: String = _store.title
		var first: String = _store.to_text(title, true)
		_keep("no_title_%s_1.ldr" % name.get_basename(), first)
		await _open("ml_no_title_%s_again" % name.get_basename(), first)
		var second: String = _store.to_text(_store.title, true)
		_keep("no_title_%s_2.ldr" % name.get_basename(), second)
		_check("%s: written whole twice, one file%s" % [name, _first_unlike(first, second)],
			first == second)
		_check("...no TITLE line said (%d, %d)" % [first.count("!BRICKWORKS TITLE"),
			second.count("!BRICKWORKS TITLE")], text.count("!BRICKWORKS TITLE")
			== first.count("!BRICKWORKS TITLE") and first.count("!BRICKWORKS TITLE")
			== second.count("!BRICKWORKS TITLE"))
		var floors: int = first.count("!BRICKWORKS FLOOR")
		_check("...one floor line (%d)" % floors, floors <= 1)


## sf2check: the model named apart from a section of its file, on its
## Name line too; a file of tabs' autosave read back with its parts; LDCad's
## groups kept in a whole write.
func _case_name_bump() -> void:
	for name: String in ["named_like.mpd", "title_model.mpd"]:
		var text: String = _fixture(name)
		await _open("ml_bump_" + name.get_basename(), text)
		var whole: String = _store.to_text(_store.title, true)
		_keep("name_bump_%s.ldr" % name.get_basename(), whole)
		var file_line: String = whole.get_slice("\n", 0)
		var file_name: String = file_line.substr(7).strip_edges()
		var named: String = ""
		for line: String in whole.split("\n").slice(0, 8):
			if line.begins_with("0 Name: "):
				named = line.substr(8).strip_edges()
				break
		_check("%s: \"%s\" named \"%s\" on its Name line" % [name, file_line, named],
			file_line.begins_with("0 FILE ") and named == file_name)
	var tabs: String = _fixture("tabs.ldr")
	_check("tabs.ldr: counted %d parts" % ModelStore.count_in(tabs), ModelStore.count_in(tabs) == 2)
	await _open("ml_tabs_autosave", tabs)
	var path: String = _store.autosave()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(tabs)
	file.close()
	var back: String = str(_store.call("_autosaved"))
	_check("tabs.ldr: its autosave read back as a model with parts (%d bytes, left empty %s)"
		% [back.length(), str(_store.left_empty)], back == tabs and not _store.left_empty)
	var groups: String = _fixture("crlf_unplaced.mpd")
	await _open("ml_groups", groups)
	var written: String = _store.to_text(_store.title, true)
	_keep("name_bump_groups.ldr", written)
	_check("crlf_unplaced.mpd: written whole, its LDCad group definition kept",
		written.contains("!LDCAD GROUP_DEF [topLevel=true] [LID=1] [GID=aaaa] [name=Group 1]"))


## hscheck: someone else's files opened and saved with nothing changed, from
## the bar and over MCP: each the file, byte for byte.
func _case_unedited() -> void:
	var crlf: String = _fixture("F_theirs_lf.ldr").replace("\n", "\r\n")
	var same: int = 0
	var all: int = 0
	for entry: Array in [["F_theirs_lf", _fixture("F_theirs_lf.ldr")], ["F_theirs_crlf", crlf],
			["apps", _fixture("apps.mpd")], ["drive", _fixture("drive.ldr")],
			["merge_theirs_five", _fixture("merge_theirs_five.ldr")]]:
		var name: String = entry[0]
		var text: String = entry[1]
		await _open("ml_unedited_" + name, text)
		var bar_saved: String = await _bar_save("unedited_%s_bar" % name)
		all += 1
		if bar_saved == text:
			same += 1
		_check("%s: the bar's Save, byte for byte%s" % [name, _first_unlike(text, bar_saved)],
			bar_saved == text)
		await _open("ml_unedited_%s_in" % name, text)
		print("  save_model: %s" % (await _say("save_model", {"name": "ml_unedited_%s_mcp.ldr" % name}))
			.get_slice("\n", 0).left(100))
		var mcp_saved: String = FileAccess.get_file_as_string(MODELS + "ml_unedited_%s_mcp.ldr" % name)
		_keep("unedited_%s_mcp.ldr" % name, mcp_saved)
		all += 1
		if mcp_saved == text:
			same += 1
		_check("%s: save_model, byte for byte, no TITLE added%s" % [name,
			_first_unlike(text, mcp_saved)], mcp_saved == text)
	print("  unedited saves byte for byte: %d of %d" % [same, all])


## Tabs between a line's words, a CR in a file of LF and "0 FiLe": read as
## LDraw reads them; the floor changed on the line the file had it on.
func _case_tabs() -> void:
	var text: String = "0 FiLe tabbed.ldr\n0 Tabbed\n0 Name: tabbed.ldr\n0 Author: Someone Else\n" \
		+ "0\t!BRICKWORKS\tFLOOR\tBASEPLATE\t32\t24\t2\n" \
		+ "0 !BRICKWORKS PIN\t{\"id\":\"t1\",\"part\":\"3001\",\"colour\":4,\"at\":[0,0,0],\"text\":\"Tabbed pin\",\"by\":\"Ana\",\"tint\":\"#ffcc00\",\"when\":\"2026-11-01\"}\n" \
		+ "0 !BRICKWORKS VIEW {\"distance\":400,\"focus\":[0,0,0],\"name\":\"cr view\",\"pitch\":-25,\"yaw\":30}\r\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 NOFILE\n"
	await _open("ml_tabs", text)
	_check("the tabbed floor read (%s)" % _store.model_floor.to_meta(),
		_store.model_floor.to_meta() == "0 !BRICKWORKS FLOOR BASEPLATE 32 24 2")
	var pins: Array = _store.pins.list if _store.pins != null else []
	_check("the tabbed pin read (%d)" % pins.size(), pins.size() == 1)
	_check("the view with a CR read (%d)" % _world.saved_views.size(), _world.saved_views.size() == 1)
	var saved: String = await _bar_save("tabs_1_unedited")
	_check("saved unedited: the file, byte for byte%s" % _first_unlike(text, saved), saved == text)
	print("  set_floor: %s" % (await _say("set_floor", {"kind": "baseplate", "across": 16}))
		.get_slice("\n", 0).left(100))
	saved = await _bar_save("tabs_2_floor")
	var lines: PackedStringArray = saved.split("\n")
	_check("the floor changed on its own line, one floor line (%d at %d)" % [
		saved.count("!BRICKWORKS FLOOR") + saved.count("!BRICKWORKS\tFLOOR"),
		_index_of(lines, "FLOOR BASEPLATE 16")], saved.count("FLOOR") == 1
		and _index_of(lines, "FLOOR BASEPLATE 16") == 4)
	_check("...the pin and the view lines as they were", saved.contains(text.get_slice("\n", 5))
		and saved.contains(text.get_slice("\n", 6)))


## The cost: the castle written whole, five times, its median in ms and ms
## per MB of the file written.
func _case_castle() -> void:
	var bar: ModelBar = _main.get("_bar")
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await bar.open_with_progress("res://models/castle.ldr")
	bar.opened.emit(placed)
	await _frames(30)
	var times: Array = []
	var size: int = 0
	for _n: int in 5:
		var at: int = Time.get_ticks_usec()
		var text: String = _store.to_text(_store.title, true)
		times.append(float(Time.get_ticks_usec() - at) / 1000.0)
		size = text.to_utf8_buffer().size()
		await _frames(2)
	times.sort()
	var median: float = times[2]
	var per_mb: float = median / maxf(0.001, float(size) / 1048576.0)
	print("  castle: %d parts, %d bytes; whole write %s ms, median %.1f ms, %.1f ms per MB" % [
		_world.brick_count(), size, str(times), median, per_mb])
	var most: String = OS.get_environment("METALINES_CASTLE_MS_PER_MB")
	_check("castle written whole at %.1f ms per MB%s" % [per_mb, "" if most.is_empty()
		else " (the most %s)" % most], most.is_empty() or per_mb <= float(most))


# -- helpers ------------------------------------------------------------------------


## [param text] with a hinge on a brick of its own after its first part, the
## joint a motion is defined on (motions_probe's hinge.ldr).
static func _with_hinge(text: String) -> String:
	var at: int = text.find("\n1 ") + 1
	at = text.find("\n", at) + 1
	return text.substr(0, at) + "1 4 200 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" \
		+ "1 71 200 -24 0 1 0 0 0 1 0 0 0 1 3937.dat\n" \
		+ "1 71 200 -24 0 1 0 0 0 1 0 0 0 1 3938.dat\n" + text.substr(at)


func _fixture(name: String) -> String:
	return FileAccess.get_file_as_string(FX + name)


func _put(name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(MODELS + name + ".ldr", FileAccess.WRITE)
	file.store_string(text)
	file.close()


## [param text] put in the person's models as [param name] and opened from
## there as open_model opens one.
func _open(name: String, text: String) -> void:
	_put(name, text)
	_main.call("clear_model")
	await _frames(4)
	print("  open %s: %s" % [name, (await _say("open_model", {"name": name})).get_slice("\n", 0)
		.left(140)])
	await _settled()


func _settled() -> void:
	for _n: int in 900:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	await _frames(8)


## The bar's Save, and the file it wrote.
func _bar_save(label: String) -> String:
	var bar: ModelBar = _main.get("_bar")
	var ok: bool = await bar._on_save()
	await _frames(4)
	var text: String = FileAccess.get_file_as_string(MODELS + bar.model_name() + ".ldr")
	print("  bar save %s as %s: %s (%d bytes)" % [label, bar.model_name(), ok, text.length()])
	_keep(label + ".ldr", text)
	return text


## The save [param saved] opened again and saved again: the same file.
func _reopen_same(label: String, saved: String) -> void:
	await _open("ml_%s_again" % label, saved)
	var again: String = await _bar_save(label + "_again")
	_check("...opened again and saved again, byte for byte%s" % _first_unlike(saved, again),
		again == saved)


func _keep(name: String, text: String) -> void:
	if _out.is_empty():
		return
	var file: FileAccess = FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


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


func _id_of(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.id
	return 0


static func _index_of(lines: PackedStringArray, piece: String) -> int:
	for n: int in lines.size():
		if lines[n].contains(piece):
			return n
	return -1


static func _lf_only(text: String) -> int:
	return text.count("\n") - text.count("\r\n")


static func _first_lf(text: String) -> String:
	var at: int = 0
	while true:
		at = text.find("\n", at)
		if at < 0:
			return ""
		if at == 0 or text.unicode_at(at - 1) != 13:
			var start: int = text.rfind("\n", at - 1) + 1
			return text.substr(start, at - start)
		at += 1
	return ""


## Where [param a] and [param b] first differ, said: "" when they are one.
static func _first_unlike(a: String, b: String) -> String:
	if a == b:
		return ""
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for n: int in maxi(la.size(), lb.size()):
		var x: String = la[n] if n < la.size() else "<none>"
		var y: String = lb[n] if n < lb.size() else "<none>"
		if x != y:
			return " (line %d: %s | %s)" % [n + 1, x.c_escape().left(80), y.c_escape().left(80)]
	return " (the same lines, %d and %d bytes)" % [a.length(), b.length()]


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
