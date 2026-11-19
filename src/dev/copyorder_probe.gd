## A file saved, opened and saved again with no edit is the same file, and
## every copy keeps its number through the save and the open, nested ones
## too (copyorder).
##
##   godot --headless --path . --script src/dev/copyorder_probe.gd
##
## cf3check's two faults (bench/results/cf3check-2026-11-12, its attack
## cf3attack_probe.gd), both live's as well as pre261's:
## - s2: a model of the app's own nobody gave steps, a tower placed twice
##   whose 1 x 1 brick stands in its 2 x 4's room under one 2 x 2, saved and
##   opened again: the 2 x 4 and the 1 x 1 swapped steps at every save. The
##   planner pressed up the first of the two it asked (Instructions
##   ._pressed_up), in the order the file had them, and the one built first
##   is written first. Asked largest first now, by place and part: the 2 x 4
##   goes in with the 2 x 2 and the 1 x 1 holds it. Smallest first hid parts
##   in 2 stabletext2brick models the file's order did not (coreview F1).
## - o1: a wing placed green, in two red cars and blue, the green one made
##   unlike the others: "Car#2/Wing#3" opened as "Car#2/Wing#2", the first
##   car's wing as "Wing#5", and every save numbered them anew. A section is
##   written once, so its COPY lines said one car's numbers; each other copy's
##   line says its own now (LdrModel.COPY_META, "0 !BRICKWORKS COPY 2
##   Wing#2=3").
## And around them: the tower's lines the other way round (s2_flipped), both
## towers red and one tower (s4s5); three deep, a truck duplicated by the app
## (nested); a sub-model placed twice and once mirrored (mirror); CRLF and
## tabs (crlf); a file written before COPY lines said the copies inside
## (older), as live writes it and as live reads ours; the COPY line's numbers
## said every way, read by one rule here and on the site (numbers); an edit
## undone and redone (undo); and the house, the castle (copies built in its
## steps) and 7128-1 and 8845-1 of the LDraw model repository as the app's
## own and as someone else's (models). And the car of sub-models with no
## steps, each sub-model used two or four times (whole): the plan orders
## steps but never builds a sub-model in its parent's, so each is written
## once. When the mend's judge of whole sub-model steps also counted parts
## put in under and apart in the hand (buildorder), the car's Sill went into
## its sides' steps and was written nowhere (rel-m304). Each saved three
## times in a row; the
## site reads each copy by the name the app does
## (tools/web/copy_names_check.mjs).
##
## COPYORDER_CASES=s2,o1 runs those alone.
extends "res://src/dev/copyfaults_probe.gd"

const ORDER_CASES: Array = ["s2", "s2_flipped", "s4s5", "o1", "nested", "mirror", "crlf", "older",
	"numbers", "undo", "models", "whole"]
const HEAD := "0 Name: %s\n0 Author: %s\n"
const OMR := "res://vendor/omr/files/"
var _scratch: String = ""


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("copyorder probe: not finished in time")
		quit(1))
	await process_frame
	_scratch = OS.get_user_data_dir().path_join("copyorder")
	DirAccess.make_dir_recursive_absolute(_scratch)
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
	var cases: Array = ORDER_CASES if OS.get_environment("COPYORDER_CASES").is_empty() \
		else Array(OS.get_environment("COPYORDER_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"s2": await _case_s2()
			"s2_flipped": await _case_s2_flipped()
			"s4s5": await _case_s4s5()
			"o1": await _case_o1()
			"nested": await _case_nested()
			"mirror": await _case_mirror()
			"crlf": await _case_crlf()
			"older": await _case_older()
			"numbers": await _case_numbers()
			"undo": await _case_undo()
			"models": await _case_models()
			"whole": await _case_whole()
			_: _check("no such case %s" % name, false)
	print("\ncopyorder probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- helpers ----------------------------------------------------------------------


static func _file(name: String, author: String, sections: Array) -> String:
	var out: String = ""
	for n: int in sections.size():
		var one: Array = sections[n]
		out += "0 FILE %s\n0 %s\n" % [str(one[0]), str(one[0]).get_basename().capitalize()] \
			+ HEAD % [str(one[0]), author] + "\n".join(PackedStringArray(one.slice(1))) + "\n0 NOFILE\n"
	return out


## cf3check's S2: the app's own, no steps, a tower red and blue whose 3005
## stands in its 3001's room, under its 3003.
static func _s2_text(colours: Array = ["4", "1"], flipped: bool = false) -> String:
	var tower: Array = ["tower.ldr", "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 16 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat", "1 14 0 -72 0 1 0 0 0 1 0 0 0 1 3062b.dat",
		"1 15 20 -24 0 1 0 0 0 1 0 0 0 1 3005.dat"]
	if flipped:
		tower = [tower[0], tower[4], tower[3], tower[2], tower[1]]
	var main: Array = ["s2.mpd", "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "1 7 0 0 100 1 0 0 0 1 0 0 0 1 3020.dat"]
	for n: int in colours.size():
		main.append("1 %s %d -8 0 1 0 0 0 1 0 0 0 1 tower.ldr" % [colours[n], 200 * n])
	main.append("1 14 0 -8 100 1 0 0 0 1 0 0 0 1 3001.dat")
	return _file("s2.mpd", "Brickworks", [main, tower])


## cf3check's O1: a wing placed green, in two red cars and blue.
static func _o1_text() -> String:
	return _file("o1.mpd", "Brickworks", [
		["o1.mpd", "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "0 STEP",
			"1 2 0 -8 300 1 0 0 0 1 0 0 0 1 wing.ldr",
			"1 4 0 -8 0 1 0 0 0 1 0 0 0 1 car.ldr", "1 4 200 -8 0 1 0 0 0 1 0 0 0 1 car.ldr",
			"1 1 400 -8 300 1 0 0 0 1 0 0 0 1 wing.ldr", "0 STEP"],
		["car.ldr", "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 16 0 -48 0 1 0 0 0 1 0 0 0 1 wing.ldr"],
		["wing.ldr", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat", "1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3024.dat"]])


## O1 opened and the green wing's 3024 taken out of it, as cf3check made it: the
## cars' wings and the blue one go their own way.
func _o1_opened() -> void:
	await _open(_o1_text())
	var first: String = ""
	for path: String in _paths():
		if not path.contains("/") and path.begins_with("Wing#"):
			first = path
			break
	var tile: BrickWorld.Brick = _brick_of(first, "3024")
	_builder.regroup({tile.id: ""}, "out of the green wing")
	await _frames(4)
	_main.call("_on_model_edited")
	await _frames(4)


## The model's copies, sorted.
func _names() -> Array:
	var out: Array = _paths()
	out.sort()
	return out


## The model saved as Save saves it: the build order worked out a slice at a
## time on a big model (ModelStore.to_text_paced), as the save does.
func _saved() -> String:
	if not _store.paces():
		return _save()
	var job: Working.Job = Working.begin("Saving", 0, true)
	var text: String = await _store.to_text_paced(_store.title, job)
	job.end()
	return text


## Saved, opened and saved [param times] times in a row, from the model as it
## stands: each save the one before to the byte, every copy by the name it
## had, and the site reading each copy by the app's name. Returns the first.
func _rounds(label: String, times: int = 3) -> String:
	var names: Array = _names()
	var parts: Array = _looks(false)
	var first: String = await _saved()
	var before: String = first
	var said: Array = []
	for n: int in times:
		await _open(before)
		var again: String = await _saved()
		said.append("%s%s" % ["same" if again == before else "APART", "" if _names() == names
			else " (names %s)" % _unlike(names, _names())])
		_check("%s: opened again (%d), every part where it was%s" % [label, n + 1,
			_unlike(parts, _looks(false))], _looks(false) == parts)
		before = again
	_check("%s: %d saves in a row, each the one before to the byte, every copy by its name: %s"
		% [label, times, ", ".join(said)], said.all(func(one: String) -> bool: return one == "same"))
	_site_names(label, first)
	return first


## The site reads the copies of [param text] by the names the app reads them
## by (Assemblies.label, each of the path's), as the app has them open.
func _site_names(label: String, text: String) -> void:
	var file: String = _scratch.path_join("site_%s.mpd" % label.validate_filename())
	var out: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	var said: Array = []
	var code: int = OS.execute("node", [ProjectSettings.globalize_path("res://tools/web/copy_names_check.mjs"),
		file], said, true)
	var site: Array = Array(str(said[0] if not said.is_empty() else "").strip_edges().split("\n", false)) \
		if code == 0 else ["exit %d: %s" % [code, str(said).left(200)]]
	var app: Array = []
	for path: String in _paths():
		var labels := PackedStringArray()
		var at: String = ""
		for segment: String in path.split("/"):
			at = segment if at.is_empty() else at + "/" + segment
			labels.append(Assemblies.label(at))
		app.append("/".join(labels))
	app.sort()
	_check("%s: the site reads each of its %d copies by the app's name%s" % [label, app.size(),
		_unlike(app, site)], app == site)


# -- cases ------------------------------------------------------------------------


## S2 (cf3check S2_unedited): saved, opened and saved again with no edit, the
## same file; the tower's 1 x 1 in its first step and the 2 x 4 pressed up
## under the 2 x 2 with it, whichever the file has first.
func _case_s2() -> void:
	await _open(_s2_text())
	# Planned as an edited model is (kbkeep): opened and saved with no edit,
	# the file is written as it is.
	_store.forget_kept()
	var first: String = await _rounds("s2")
	var tower: String = first.substr(first.find("0 FILE tower.ldr"))
	var body: PackedStringArray = tower.split("\n")
	var lines: Array = []
	for line: String in body:
		if line.begins_with("1 ") or line == "0 STEP":
			lines.append(line.get_slice(" ", line.get_slice_count(" ") - 1) if line.begins_with("1 ") else "STEP")
	_check("s2: the tower's 3005 alone in its first step, the 3001 with the 3003 (%s)" % " ".join(lines),
		" ".join(lines) == "3005.dat STEP 3001.dat 3003.dat 3062b.dat")


## The tower's lines the other way round: the same plan saved, each planned
## as an edited model is.
func _case_s2_flipped() -> void:
	await _open(_s2_text())
	_store.forget_kept()
	var plain: String = await _saved()
	await _open(_s2_text(["4", "1"], true))
	_store.forget_kept()
	var flipped: String = await _saved()
	_check("s2_flipped: the tower's lines in the other order save the same file (%s)"
		% _diff(plain, flipped), flipped == plain)
	await _rounds("s2_flipped")


## Both towers red (cf3check S4), and one tower (S5).
func _case_s4s5() -> void:
	await _open(_s2_text(["4", "4"]))
	await _rounds("s4 both red")
	await _open(_s2_text(["4"]))
	await _rounds("s5 one tower")


## O1: every copy by its number after the save and the open, and three saves.
func _case_o1() -> void:
	await _o1_opened()
	var names: Array = _names()
	_check("o1: the copies as cf3check had them (%s)" % ", ".join(names),
		names.has("Car#1/Wing#2") and names.has("Car#2/Wing#3") and names.has("Wing#1")
		and names.has("Wing#4"))
	var saved: String = await _rounds("o1")
	_check("o1: the second car's line says its wing is Wing#3 (%s)"
		% Array(saved.split("\n")).filter(func(line: String) -> bool:
			return line.begins_with(LdrModel.COPY_META)).map(func(line: String) -> String:
				return line.trim_prefix(LdrModel.COPY_META + " ")), saved.contains(LdrModel.COPY_META + " 2 Wing#2=3\n"))


## Three deep (cf3check N2): a truck red and blue, two axles each, two wheels
## each; then the blue truck duplicated by the app and put down, its axles and
## wheels numbered as the app numbers a new copy: each kept through the save
## and the open.
func _case_nested() -> void:
	var text: String = _file("n2.mpd", "Brickworks", [
		["n2.mpd", "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "0 STEP",
			"1 4 0 -8 0 1 0 0 0 1 0 0 0 1 truck.ldr", "1 1 0 -8 400 0 0 1 0 1 0 -1 0 0 truck.ldr", "0 STEP"],
		["truck.ldr", "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
			"1 16 -40 0 0 1 0 0 0 1 0 0 0 1 axle.ldr", "1 16 40 0 0 1 0 0 0 1 0 0 0 1 axle.ldr"],
		["axle.ldr", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3023.dat",
			"1 0 0 0 -30 1 0 0 0 1 0 0 0 1 wheel.ldr", "1 0 0 0 30 -1 0 0 0 1 0 0 0 -1 wheel.ldr"],
		["wheel.ldr", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3024.dat", "1 15 0 -8 0 1 0 0 0 1 0 0 0 1 3070b.dat"]])
	await _open(text)
	await _rounds("nested")
	await _open(text)
	_select_assembly("Truck#2")
	(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
	var put: int = await _put_down()
	_shell.assemblies.leave_to("")
	await _edited()
	var names: Array = _names()
	_check("nested: the blue truck duplicated and put down (#%d) as Truck#3, its own axles and wheels (%s)"
		% [put, ", ".join(names.filter(func(path: String) -> bool: return path.begins_with("Truck#3")))],
		names.has("Truck#3") and names.filter(func(path: String) -> bool:
			return path.begins_with("Truck#3/")).size() == 6)
	await _rounds("nested duplicated")


## A sub-model holding a copy of another placed twice and once mirrored, the
## two placed ones in red and blue.
func _case_mirror() -> void:
	await _open(_file("mirror.mpd", "Brickworks", [
		["mirror.mpd", "1 7 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "0 STEP",
			"1 4 200 -8 0 1 0 0 0 1 0 0 0 1 hand.ldr", "1 1 -200 -8 0 1 0 0 0 1 0 0 0 1 hand.ldr",
			"1 4 0 -8 200 -1 0 0 0 1 0 0 0 1 hand.ldr", "0 STEP"],
		["hand.ldr", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "1 16 20 -8 0 1 0 0 0 1 0 0 0 1 finger.ldr",
			"1 14 -30 -8 -10 1 0 0 0 1 0 0 0 1 3024.dat"],
		["finger.ldr", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3040b.dat", "1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3024.dat"]]))
	await _rounds("mirror")


## O1's save with CRLF line ends and tabs between its fields: the same copies
## by the same names as the save itself, and saved the same.
func _case_crlf() -> void:
	await _o1_opened()
	var names: Array = _names()
	var saved: String = await _saved()
	var crlf: String = saved.replace(" ", "\t").replace("\t!BRICKWORKS\t", " !BRICKWORKS ") \
		.replace("\n", "\r\n")
	await _open(crlf)
	_check("crlf: opened with CRLF and tabs, every copy by its name%s" % _unlike(names, _names()),
		_names() == names)
	var again: String = await _saved()
	# The lines it writes whole in spaces, those it kept as the file had them
	# (the floor's) in its tabs still.
	var spaced: String = again.replace("\r\n", "\n").replace("\t", " ")
	_check("crlf: ...saved, the file the LF one saves, its lines ended CRLF as it had them (%s)"
		% _diff(saved, spaced), spaced == saved and again.count("\r\n") == again.count("\n"))
	await _open(again)
	var third: String = await _saved()
	_check("crlf: ...and that, opened and saved, to the byte (%s)" % _diff(again, third), third == again)


## A file written before a COPY line said the copies inside its copy (live's,
## cf3check's O1 save1 of pre261): opened, its copies as live reads them; saved,
## opened and saved again, each by that name. And ours read as live reads it
## (the COPY line's own number alone): every part where it was.
func _case_older() -> void:
	await _o1_opened()
	var ours: String = await _saved()
	var parts: Array = _looks(false)
	var older: PackedStringArray = []
	for line: String in ours.split("\n"):
		older.append(line.get_slice(" ", 0) + " " + line.get_slice(" ", 1) + " " + line.get_slice(" ", 2)
			+ " " + line.get_slice(" ", 3) if line.begins_with(LdrModel.COPY_META) else line)
	var text: String = "\n".join(older)
	_check("older: the save without the numbers of the copies inside (%d lines said them)"
		% ours.count("=") , text != ours and not text.contains("Wing#2="))
	await _open(text)
	var names: Array = _names()
	_check("older: opened, every part where it was, its copies as the file numbers them (%s)"
		% ", ".join(names), _looks(false) == parts and names.has("Car#1/Wing#5") and names.has("Car#2/Wing#2"))
	await _rounds("older")


## The COPY line's numbers, its own and those it says of the copies inside,
## read by one rule in the app and on the site: 1 to 9 digits, else none
## (LdrModel.copy_number, api/_parts.js copyNumber; coreview F2). O1's save
## with the second car's line said each way: every part where it was, and the
## site reads each copy by the app's name.
func _case_numbers() -> void:
	var said: Array = []
	for word: Array in [["3", 3], ["03", 3], ["999999999", 999999999], ["1000000000", 0], ["+3", 0],
			["-3", 0], ["3.5", 0], ["0x3", 0], ["", 0], ["Wing#2=3", 0], [String.chr(0x663), 0]]:
		if LdrModel.copy_number(str(word[0])) != int(word[1]):
			said.append("%s read as %d" % [word[0], LdrModel.copy_number(str(word[0]))])
	_check("numbers: 1 to 9 digits read, every other word none (%s)" % ", ".join(said), said.is_empty())
	await _o1_opened()
	var ours: String = await _saved()
	var parts: Array = _looks(false)
	var line: String = LdrModel.COPY_META + " 2 Wing#2=3\n"
	_check("numbers: O1's save says the second car's wing on its line", ours.contains(line))
	for form: Array in [["plus", "2 Wing#2=+3"], ["overflow", "2 Wing#2=99999999999999999999"],
			["ten_digits", "2 Wing#2=1000000003"], ["own_plus", "+2 Wing#2=3"],
			["no_own_number", "Wing#2=3"], ["lead0", "02 Wing#2=03"]]:
		var text: String = ours.replace(line, "%s %s\n" % [LdrModel.COPY_META, form[1]])
		await _open(text)
		_check("numbers %s: every part where it was" % form[0], _looks(false) == parts)
		_site_names("numbers %s" % form[0], text)


## An edit undone and redone: the save before it, and after the redo the save
## of the edit.
func _case_undo() -> void:
	await _o1_opened()
	var before: String = await _saved()
	var tile: BrickWorld.Brick = _brick_of("Car#2/Wing#3", "3003")
	_pick([tile.id])
	_builder.paint_selection(14)
	await _edited()
	var edited: String = await _saved()
	_check("undo: Car#2's wing painted, saved otherwise (%s)" % _diff(before, edited), edited != before)
	_shell.run("undo")
	await _frames(6)
	var undone: String = await _saved()
	_check("undo: undone, the save before it to the byte (%s)" % _diff(before, undone), undone == before)
	_shell.run("redo")
	await _frames(6)
	var redone: String = await _saved()
	_check("undo: redone, the edit's save to the byte (%s)" % _diff(edited, redone), redone == edited)
	_shell.run("undo")
	await _frames(6)
	await _rounds("undo")


## The house and the castle (copies built in its steps), each once saved by
## the app; and 7128-1's speeder bikes (a sub-model placed twice holding
## another) and 21008-1's tower (wings of a part placed in other sub-models)
## as their authors wrote them. Saved first from a file this build did not
## write, the house and the castle are worked out again once at the next
## open from the order the save wrote, and the save after differs (pre261's
## too): said, not checked, and the rounds start from that save.
func _case_models() -> void:
	for name: String in ["res://models/house.ldr", "res://models/castle.ldr", OMR + "7128-1.mpd",
			OMR + "21008-1.mpd"]:
		var text: String = FileAccess.get_file_as_string(name)
		if not name.begins_with(OMR):
			await _open(text)
			var first: String = await _saved()
			await _open(first)
			var second: String = await _saved()
			print("  note: %s's first save opened and saved again: %s" % [name.get_file(),
				"the same" if second == first else "worked out again (%s)" % _diff(first, second)])
			text = second
		await _open(text)
		await _rounds(name.get_file())


## The car of sub-models (swapfind's fixture) with no steps and no COPY
## lines, as someone's model nobody gave steps: Side, Sill and Axle placed
## twice, Wheel four times. Saved, every sub-model written once, and the
## save opened and saved again to the byte.
func _case_whole() -> void:
	var lines := PackedStringArray()
	for line: String in FileAccess.get_file_as_string("res://src/dev/fixtures/swapfind_car.mpd").split("\n"):
		if line.strip_edges() != "0 STEP" and not line.begins_with(LdrModel.COPY_META):
			lines.append(line)
	await _open("\n".join(lines))
	var first: String = await _rounds("whole")
	var written: Array = []
	for file: String in ["side.ldr", "sill.ldr", "axle.ldr", "wheel.ldr"]:
		written.append("%s %d" % [file, first.count("0 FILE %s" % file)])
	_check("whole: each sub-model written once, none built in its parent's steps (%s)"
		% ", ".join(written), written.all(func(one: String) -> bool: return one.ends_with(" 1"))
		and not first.contains(LdrModel.IN_META))
