## Someone else's file keeps its text through the edits that lost it
## (kt3review, keeptext4).
##
##   godot --headless --path . --script src/dev/kt3r_probe.gd
##
## kt3review (bench/results/keeptext3-2026-11-06/kt3review/report.md) found
## a save of someone else's file lost lines, notes and part numbers to
## edits keep_text did not make: one copy of several moved, Ungroup, a
## rename of a sub-model whose title is its Author line, a step edit near an
## author's empty step, LeoCAD's and Studio's lines about the next part, the
## only copy holding a part no library has moved or taken off, a file with
## two sections of one name; and (keeptext4's own) a part moved onto an
## author's empty page, and a last step with no STEP line after it emptied
## while two new steps go in before it. Until keeptext4 a save paired the model's parts
## with the file's lines again each time, by place, and wrote the file whole
## where that failed; now each part knows its line (SourceFile).
##
## Each case opens its file (src/dev/fixtures/kt3r_*, the castle made from
## models/castle.ldr) as the app opens it, makes its edit as a person makes
## it, and saves as Save saves. Each time:
## - the file is written into, never whole;
## - every line the edit did not touch is in the saved file, in order, byte
##   for byte;
## - the saved file opens again as the model saved: every part in place, in
##   its copy and step;
## - undone, the save is the file again; the saved file opened and saved
##   again is itself;
## and what the review saw lost is there. The castle's cases time the save.
##
##   KT3R_CASES=title,ungroup   those cases
extends SceneTree

const FX := "res://src/dev/fixtures/"
const CASTLE := "res://models/castle.ldr"
const CASES: Array = ["title", "whole", "emptystep", "emptystep2", "laststep", "move_copy",
	"move_copy_7140", "leocad", "ungroup", "delete_unshown_copy", "move_unshown", "odd",
	"castle"]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _timings: Array = []


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
	var cases: Array = CASES if OS.get_environment("KT3R_CASES").is_empty() \
		else Array(OS.get_environment("KT3R_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"title": await _case_title()
			"whole": await _case_whole()
			"emptystep": await _case_emptystep()
			"emptystep2": await _case_emptystep2()
			"laststep": await _case_laststep()
			"move_copy": await _case_move_copy()
			"move_copy_7140": await _case_move_copy_7140()
			"leocad": await _case_leocad()
			"ungroup": await _case_ungroup()
			"delete_unshown_copy": await _case_delete_unshown_copy()
			"move_unshown": await _case_move_unshown()
			"odd": await _case_odd()
			"castle": await _case_castle()
			_: _check("no such case %s" % name, false)
	if not _timings.is_empty():
		print("\nthe castle's save (SourceFile.write; to_text, what Save writes):")
		for row: Array in _timings:
			print("  %-44s %6.0f ms %6.0f ms" % row)
	print("\nkt3r probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- cases ---------------------------------------------------------------------


## A sub-model with no description line, its Author line read as its title,
## renamed: the Author line stays (kt3review #7).
func _case_title() -> void:
	var text: String = _fixture("kt3r_title_author.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var paths: Array = _shell.assemblies.paths()
	paths.sort()
	_select_assembly(str(paths[0]))
	_shell.run("rename_assembly")
	await _frames(2)
	print("  renamed %s: %s" % [paths[0], _name_it("Left Wing")])
	await _frames(4)
	_shell.assemblies.leave_to("")
	var saved: String = await _saved("rename", text, depth, [])
	_check("...its Author line kept: %s" % saved.contains("0 Author: Sam Other [sother]"),
		saved.contains("0 Author: Sam Other [sother]"))
	_check("...titled Left Wing", saved.contains("\n0 Left Wing"))


## A part of a copy placed mirrored moved, in a file with a sub-model
## nothing places and a picture (!DATA): written into the file, never whole
## (kt3review #5).
func _case_whole() -> void:
	var text: String = _fixture("kt3r_whole.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var path: String = _mirrored_copy()
	var part: int = _first_in(path)
	var line: String = "1 4 -20 -8 0 1 0 0 0 1 0 0 0 1 3023.dat"
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.part_id.begins_with("3023"):
			part = brick.id
	_shell.assemblies.enter(path)
	_select_only([part])
	var moved: int = _builder.move_selection(Vector3i(0, 0, 4))
	await _frames(4)
	_shell.assemblies.leave_to("")
	_check("moved %d part of %s, the copy placed mirrored" % [moved, path], moved == 1)
	var saved: String = await _saved("move in a mirrored copy", text, depth, [line])
	for kept: String in ["0 FILE runs - spare.ldr", "0 !DATA runs_logo.png", "0 FILE runs - fin.ldr",
			"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3710.dat"]:
		_check("...kept: %s" % kept, saved.contains(kept))
	_check("...the part moved still a 3023.dat", _count(saved, "3023.dat") == 2)


## A step with only a note and the ROTSTEP turning the model over, the
## section stepped again around it (kt3review #4): every STEP line, the
## note and the ROTSTEP where they were. A part moved back onto that page
## goes in it, after the note: seen turned over still, as it was
## (BookletLooks._turns_follow), so the turn is written before the page
## and the STEP after it.
func _case_emptystep() -> void:
	var text: String = _fixture("kt3r_emptystep.ldr")
	for spec: Array in [["next", 2], ["prev", 1], ["next", 14], ["prev", 2]]:
		await _open(text)
		var depth: int = _builder.history_depth()
		var parts: Array = []
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.color_code == int(spec[1]):
				parts.append(brick.id)
		var said: String = _shell.change_steps(str(spec[0]), [parts[0]], _step_holding(parts[0]))
		await _frames(4)
		var moved: String = _line_of(text, parts[0])
		print("\n  %s on a part of colour %d: %s" % [spec[0], spec[1], said.get_slice("\n", 0).left(90)])
		var onto: bool = spec == ["prev", 1]
		var saved: String = await _saved("%s, colour %d" % spec, text, depth,
			[moved, "0 STEP", "0 ROTSTEP 180 0 0 ABS"] if onto else [moved],
			["0 STEP"] if _empties_step(text, int(spec[1])) else [])
		if onto:
			_check("...the part moved onto the page after its note, seen turned over as it was",
				saved.contains("0 ROTSTEP 180 0 0 ABS\n0 // Turn the model over before the next step\n"
					+ moved + "\n0 STEP\n"))
		else:
			_check("...the note and the ROTSTEP still after the first STEP line",
				saved.contains("0 STEP\n0 // Turn the model over before the next step\n0 ROTSTEP 180 0 0 ABS\n"))


## A section whose last step has no STEP line after it (as LDraw allows),
## that step emptied by its part moved back, and two parts of the step
## before each put in a new step after it: the STEP line the emptied step
## lost was the one the new steps go in after, which took them with it.
func _case_laststep() -> void:
	var text: String = _fixture("kt3r_laststep.ldr")
	await _open(text)
	var depth: int = _builder.history_depth()
	var by_colour: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		by_colour[brick.color_code] = brick.id
	var said := PackedStringArray()
	for spec: Array in [["prev", 2], ["new", 1], ["new", 14]]:
		var part: int = int(by_colour[spec[1]])
		said.append(_shell.change_steps(str(spec[0]), [part], _step_holding(part)).get_slice("\n", 0).left(60))
		await _frames(4)
	print("\n  %s" % " / ".join(said))
	var saved: String = await _saved("the last step emptied, two new after the one before", text, depth,
		[_line_of(text, int(by_colour[2])), _line_of(text, int(by_colour[1])),
			_line_of(text, int(by_colour[14]))])
	var steps: Array = _colours_by_step(saved)
	_check("...red and green, then yellow, then blue, a step each: %s" % JSON.stringify(steps),
		steps == ["2 4", "14", "1"])


## A step with only a note, the page an author left for it (kt3review #4).
func _case_emptystep2() -> void:
	var text: String = _fixture("kt3r_emptystep2.ldr")
	await _open(text)
	var depth: int = _builder.history_depth()
	var part: int = -1
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == 2 and part < 0:
			part = brick.id
	_shell.change_steps("next", [part], _step_holding(part))
	await _frames(4)
	var saved: String = await _saved("next, colour 2", text, depth, [_line_of(text, part)])
	_check("...the page of its own between its STEP lines",
		saved.contains("0 STEP\n0 // Page 2: check that both bricks sit flat before going on\n0 STEP\n"))
	_check("...5 STEP lines, as the file had: %d" % _count(saved, "0 STEP"),
		_count(saved, "0 STEP") == 5)


## One of three copies of a sub-model moved whole (kt3review #1): only the
## line placing it changes.
func _case_move_copy() -> void:
	var text: String = _fixture("kt_runs.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var path: String = ""
	for p: String in _shell.assemblies.paths():
		if p.to_lower().contains("lamp") and Assemblies.copy_of(Assemblies.leaf(p)) == 2:
			path = p
	_select_assembly(path)
	var moved: int = _builder.move_selection(Vector3i(0, 0, 4))
	await _frames(4)
	_shell.assemblies.leave_to("")
	_check("moved %d parts: the copy %s" % [moved, path], moved == 3)
	var saved: String = await _saved("one copy moved", text, depth,
		["1 16 0 -24 -60 1 0 0 0 1 0 0 0 1 runs - lamp.ldr"])
	_check("...one placing line new", _minus(saved, text).size() == 1)
	_check("...4073 still 4073", _count(saved, "4073.dat") == 1 and _count(saved, "6141") == 0)


## A real set's copy moved: 7140-1's second Rear Engines.
func _case_move_copy_7140() -> void:
	var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/7140-1.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var path: String = ""
	for p: String in _shell.assemblies.paths():
		if Assemblies.definition(Assemblies.leaf(p)) == "Rear Engines" \
				and Assemblies.copy_of(Assemblies.leaf(p)) == 2:
			path = p
	_select_assembly(path)
	var moved: int = 0
	for by: Vector3i in [Vector3i(0, 0, 10), Vector3i(10, 0, 0), Vector3i(0, 0, -10),
			Vector3i(-10, 0, 0), Vector3i(0, -12, 0)]:
		moved = _builder.move_selection(by)
		if moved > 0:
			break
	await _frames(4)
	_shell.assemblies.leave_to("")
	_check("moved %d parts: the copy %s" % [moved, path], moved > 0)
	var source: SourceFile = _store.get("_source")
	var placing: String = text.split("\n")[int(source.unit_lines[path])].strip_edges()
	var saved: String = await _saved("one copy moved", text, depth, [placing], [], true)
	_check("...one placing line new: %d" % _minus(saved, text).size(), _minus(saved, text).size() == 1)


## LeoCAD's and Studio's lines about the next part (kt3review #3): gone
## with their part, moved with it.
func _case_leocad() -> void:
	var text: String = _fixture("kt3r_leocad.ldr")
	var hide := "0 !LEOCAD PIECE STEP_HIDE 3"
	var tex: Array = ["0 PE_TEX_PATH -1", "0 PE_TEX_INFO " + text.get_slice("PE_TEX_INFO ", 1).get_slice("\n", 0)]
	for spec: Array in [["delete", 1], ["next", 15], ["delete", 15]]:
		await _open(text)
		var depth: int = _builder.history_depth()
		var part: int = -1
		for brick: BrickWorld.Brick in _world.bricks():
			if brick.color_code == int(spec[1]):
				part = brick.id
		var line: String = _line_of(text, part)
		if str(spec[0]) == "delete":
			_select_only([part])
			_shell.run("delete")
		else:
			_shell.change_steps("next", [part], _step_holding(part))
		await _frames(4)
		print("\n  %s the part of colour %d" % spec)
		var bound: Array = [hide] if int(spec[1]) == 1 else tex
		var saved: String = await _saved("%s colour %d" % spec, text, depth, [line] + bound)
		var lines: PackedStringArray = saved.split("\n")
		if str(spec[0]) == "delete":
			for one: String in bound:
				_check("...gone with it: %s" % one.left(40), not saved.contains(one))
		else:
			var at: int = lines.find(line)
			_check("...moved with it, right above it",
				at >= 2 and lines[at - 2] == tex[0] and lines[at - 1] == tex[1])


## A sub-model placed once, with notes, an MLCad group and retired numbers,
## ungrouped (kt3review #2): its parts in the model under their numbers,
## with their lines; its section kept, placed by nothing.
func _case_ungroup() -> void:
	var text: String = _fixture("kt3r_ungroup.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var paths: Array = _shell.assemblies.paths()
	_select_assembly(str(paths[0]))
	_shell.run("leave_submodel")
	await _frames(4)
	_shell.assemblies.leave_to("")
	_check("ungrouped %s: copies now %s" % [paths[0], str(_shell.assemblies.paths())],
		_shell.assemblies.paths().is_empty())
	var saved: String = await _saved("ungroup", text, depth,
		["1 16 0 -8 0 1 0 0 0 1 0 0 0 1 roof.ldr"])
	_check("...4073 twice more, 3040 once more, no 6141 or 3040b",
		_count(saved, "4073.dat") == 4 and _count(saved, " 3040.dat") == 2
		and _count(saved, "6141") == 0 and _count(saved, "3040b") == 0)
	var house: String = saved.get_slice("0 FILE roof.ldr", 0)
	for kept: String in ["0 // two round tiles, under the number the author used",
			"0 MLCAD BTG Roof", "0 // the roof, a sub-model of its own"]:
		_check("...in the model with its parts: %s" % kept, house.contains(kept))


## The only copy of a sub-model holding a part no library has, taken off
## (kt3review #8): its line goes, and the sub-model with it, the part with
## them (SourceFile._gone_sections, as fidelity's sub-model emptied).
func _case_delete_unshown_copy() -> void:
	var text: String = _fixture("kt3r_unshown_copy.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var paths: Array = _shell.assemblies.paths()
	_select_assembly(str(paths[0]))
	_shell.run("delete")
	await _frames(4)
	_shell.assemblies.leave_to("")
	var sign: Array = Array(text.get_slice("0 FILE sign.ldr", 1).split("\n")).map(
		func(line: String) -> String: return line.strip_edges())
	sign[0] = "0 FILE sign.ldr"
	# A touched line is matched first where it first is: one the cart has
	# too (its Author line) is said twice, and the whole text checked below.
	var cart: Array = Array(text.get_slice("0 FILE sign.ldr", 0).split("\n"))
	var touched: Array = ["1 16 0 -8 0 1 0 0 0 1 0 0 0 1 sign.ldr",
		"0 // the sign on top, with its sticker"]
	for line: String in sign:
		if not line.is_empty():
			touched.append(line)
			if cart.has(line):
				touched.append(line)
	var saved: String = await _saved("the only copy taken off", text, depth, touched)
	var plain: String = "\n".join(Array(saved.split("\n")).filter(
		func(line: String) -> bool: return not line.begins_with("0 !BRICKWORKS")))
	_check("...the sub-model gone with it, its block and its end: %s" % plain.c_escape(),
		plain == text.get_slice("0 // the sign on top", 0) + "0 NOFILE\n")
	_check("...opened again, no part it cannot show: %s" % str(_store.unshown),
		_store.unshown.is_empty())


## The only copy of a sub-model holding a part no library has, moved
## (kt3review #6): the part goes with it.
func _case_move_unshown() -> void:
	var text: String = _fixture("kt3r_unshown_copy.mpd")
	await _open(text)
	var depth: int = _builder.history_depth()
	var paths: Array = _shell.assemblies.paths()
	_select_assembly(str(paths[0]))
	var moved: int = _builder.move_selection(Vector3i(0, 0, 4))
	await _frames(4)
	_shell.assemblies.leave_to("")
	_check("moved %d parts: the copy %s" % [moved, paths[0]], moved == 2)
	var saved: String = await _saved("the copy moved", text, depth,
		["1 16 0 -8 0 1 0 0 0 1 0 0 0 1 sign.ldr"])
	_check("...the sticker's line as it was, its copy's line new",
		saved.contains("1 16 0 -8 0 1 0 0 0 1 0 0 0 1 zz9001ps1.dat")
		and _minus(saved, text).size() == 1)


## Odd files (kt3review #9 and its no-crash list): opened, a part of the
## deepest copy duplicated in it and put down, saved.
func _case_odd() -> void:
	for file: String in ["kt3r_empty.ldr", "kt3r_fileonly.mpd", "kt3r_afternofile.mpd",
			"kt3r_dupfile.mpd"]:
		var text: String = _fixture(file)
		print("\n  %s (%d bytes)" % [file, text.length()])
		await _open(text)
		if _store.get("_source") == null:
			# An empty file is no model: not opened (ModelStore._why_not_a_model).
			_check("...not opened as a model, nothing to keep", text.strip_edges().is_empty())
			continue
		if _world.brick_count() == 0:
			var written: String = _store.to_text("odd", true)
			_check("...no parts; saved as it was (%d bytes)" % written.length(),
				_minus(text, written).is_empty())
			continue
		var depth: int = _builder.history_depth()
		var part: int = -1
		var deepest: int = -1
		for brick: BrickWorld.Brick in _world.bricks():
			var d: int = Assemblies.segments(Assemblies.path_of(brick)).size()
			if d > deepest:
				deepest = d
				part = brick.id
		var path: String = Assemblies.path_of(_world.get_brick(part))
		if not path.is_empty():
			_shell.assemblies.enter(path)
		_select_only([part])
		(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
		var put: int = await _put_down(true)
		_shell.assemblies.leave_to("")
		_check("...a %s of [%s] duplicated and put down in [%s]" % [_world.get_brick(part).part_id,
			path, Assemblies.path_of(_world.get_brick(put)) if put > 0 else "-"], put > 0)
		await _saved("a part added", text, depth, [], [], false, true)


## The castle as someone else's file, timed: saved unchanged, every part
## moved, 300 parts added, 400 made a sub-assembly; stepped, unstepped and
## with a copy placed mirrored.
func _case_castle() -> void:
	var castle: String = FileAccess.get_file_as_string(CASTLE)
	var foreign: String = castle.replace("0 Author: Brickworks", "0 Author: A. Builder [abuilder]")
	var plain := PackedStringArray()
	for line: String in foreign.split("\n"):
		if line.strip_edges() != "0 STEP" and not line.strip_edges().begins_with("0 ROTSTEP"):
			plain.append(line)
	var mirror: String = foreign.replace("1 16 0 -8 0 1 0 0 0 1 0 0 0 1 gatehouse.ldr\n",
		"1 16 0 -8 0 1 0 0 0 1 0 0 0 1 gatehouse.ldr\n1 16 0 -400 0 -1 0 0 0 1 0 0 0 1 mirror_fin.ldr\n")
	mirror = mirror.trim_suffix("\n") + "\n0 NOFILE\n0 FILE mirror_fin.ldr\n0 Mirror Fin\n" \
		+ "0 Name: mirror_fin.ldr\n0 Author: A. Builder [abuilder]\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3710.dat\n1 4 -20 -8 0 1 0 0 0 1 0 0 0 1 3023.dat\n0 NOFILE\n"
	for spec: Array in [["no edit", foreign], ["every part moved", foreign],
			["300 parts added", foreign], ["400 parts made a sub-assembly", foreign],
			["no steps: 400 parts made a sub-assembly", "\n".join(plain)],
			["a mirrored copy: every part moved", mirror]]:
		var what: String = spec[0]
		var text: String = spec[1]
		print("\n  the castle, %s" % what)
		await _open(text)
		var depth: int = _builder.history_depth()
		var own: Array = []
		var all: Array = []
		for brick: BrickWorld.Brick in _world.bricks():
			if _store.scenery.has(brick.id):
				continue
			all.append(brick.id)
			if Assemblies.path_of(brick).is_empty():
				own.append(brick.id)
		var allowed: Array = []
		var loose: bool = false
		if what.ends_with("every part moved"):
			_select_only(all)
			var moved: int = _builder.move_selection(Vector3i(0, 3, 0))
			await _frames(4)
			_check("moved %d of %d parts" % [moved, all.size()], moved == all.size())
			allowed = _placing_lines(text) + _own_part_lines(text)
		elif what == "300 parts added":
			_select_only(own.slice(0, 300))
			(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
			var put: int = await _put_down(true)
			_check("300 of the model's own parts duplicated and put down", put > 0)
			loose = true
		elif what.ends_with("made a sub-assembly"):
			var taken: Array = own.slice(0, 400)
			for brick_id: int in taken:
				allowed.append(_line_of(text, brick_id))
			_select_only(taken)
			_shell.run("make_submodel")
			await _frames(2)
			print("  make_submodel: %s" % _name_it("Made Here"))
			await _frames(4)
			_shell.assemblies.leave_to("")
		var t0: int = Time.get_ticks_usec()
		var into: Variant = _store.call("_source_text", "castle")
		var t1: int = Time.get_ticks_usec()
		_store.to_text("castle", true)
		var t2: int = Time.get_ticks_usec()
		_timings.append([what, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0])
		print("  timing: SourceFile.write %.0f ms, to_text %.0f ms" % [(t1 - t0) / 1000.0,
			(t2 - t1) / 1000.0])
		_check("...written into the file", into != null)
		await _saved(what, text, depth, allowed, [], true, loose,
			what.ends_with("made a sub-assembly") or what.ends_with("every part moved"))


# -- the checks ------------------------------------------------------------------


## The model saved as Save saves it, and checked: written into the file;
## every line of [param text] but [param touched] (and the lines right
## above each that say what it is) and [param steps] (STEP lines the edit
## may take out) in the save in order; opened again, the model saved;
## undone, the file again; saved again, itself. The save.
func _saved(what: String, text: String, depth: int, touched: Array, steps: Array = [],
		quiet: bool = false, loose: bool = false, moved_lines: bool = false) -> String:
	var edited: Dictionary = _state()
	var into: Variant = _store.call("_source_text", "model")
	var saved: String = _store.to_text("model", true)
	_check("%s: written into the file, not whole" % what, into != null)
	var lost: Array = _out_of_order(text, saved, touched, steps, moved_lines)
	if not _check("...every line it did not touch kept, in order: %d not%s" % [lost.size(),
			_first(lost)], lost.is_empty()) and not quiet:
		print("    | " + "\n    | ".join(Array(saved.split("\n")).slice(0, 80)))
	if not quiet:
		print("    + " + "\n    + ".join(_minus(saved, text).slice(0, 12).map(
			func(line: String) -> String: return line.left(110))))
		print("    - " + "\n    - ".join(_minus(text, saved).slice(0, 12).map(
			func(line: String) -> String: return line.left(110))))
	_back_to(depth)
	await _frames(4)
	var undone: String = _store.to_text("model", true)
	_check("...undone: the file again (%d lines lost, %d new)" % [_minus(text, undone).size(),
		_minus(undone, text).size()], _minus(text, undone).is_empty()
		and _minus(undone, text).is_empty())
	await _open(saved)
	var now: Dictionary = _state()
	var parts: Array = _unlike(edited["parts"], now["parts"], loose)
	var units: Array = _unlike_dict(edited["units"], now["units"], loose)
	_check("...opened again: %d of %d parts not as saved%s" % [parts.size(),
		(edited["parts"] as Array).size(), _first(parts)], parts.is_empty())
	_check("...the same copies, each in its step%s" % _first(units),
		now["tree"] == edited["tree"] and units.is_empty())
	var again: String = _store.to_text("model", true)
	_check("...saved again: itself (%d lines lost, %d new)" % [_minus(saved, again).size(),
		_minus(again, saved).size()], _minus(saved, again).is_empty()
		and _minus(again, saved).is_empty())
	return saved


## The lines of [param was] not in [param now] in their order, byte for
## byte: but those in [param touched] and the lines right above each that
## say what it is (type 0, unbroken by an empty line, a part, a STEP line
## or a section's FILE line), and STEP lines in [param steps]. The app's own
## lines ("0 !BRICKWORKS") are its to write again. [param moved_lines]: a
## line may be anywhere, but there.
static func _out_of_order(was: String, now: String, touched: Array, steps: Array,
		moved_lines: bool = false) -> Array:
	var lines: PackedStringArray = was.split("\n")
	var skip: Dictionary = {}
	var wanted: Dictionary = {}
	for line: Variant in touched:
		wanted[str(line)] = int(wanted.get(str(line), 0)) + 1
	for n: int in lines.size():
		var line: String = lines[n].trim_suffix("\r")
		if int(wanted.get(line, 0)) <= 0:
			continue
		wanted[line] = int(wanted[line]) - 1
		skip[n] = true
		var k: int = n - 1
		while k >= 0 and _binding(lines[k]):
			skip[k] = true
			k -= 1
	var steps_left: Dictionary = {}
	for line: Variant in steps:
		steps_left[str(line)] = int(steps_left.get(str(line), 0)) + 1
	var have: PackedStringArray = now.split("\n")
	var at: int = 0
	var out: Array = []
	var count: Dictionary = {}
	for line: String in have:
		count[line.trim_suffix("\r")] = int(count.get(line.trim_suffix("\r"), 0)) + 1
	for n: int in lines.size():
		var line: String = lines[n].trim_suffix("\r")
		if skip.has(n) or line.begins_with("0 !BRICKWORKS") \
				or (n == lines.size() - 1 and line.is_empty()):
			continue
		if moved_lines:
			if int(count.get(line, 0)) > 0:
				count[line] = int(count[line]) - 1
			else:
				out.append(line)
			continue
		var found: int = -1
		for k: int in range(at, have.size()):
			if have[k].trim_suffix("\r") == line:
				found = k
				break
		if found >= 0:
			at = found + 1
		elif int(steps_left.get(line.strip_edges(), 0)) > 0:
			steps_left[line.strip_edges()] = int(steps_left[line.strip_edges()]) - 1
		else:
			out.append("%d: %s" % [n, line])
	return out


static func _binding(line: String) -> bool:
	var words: PackedStringArray = LdrModel._fields(line.strip_edges())
	if words.size() < 2 or words[0] != "0":
		return false
	var keyword: String = words[1].to_upper()
	return not keyword in ["STEP", "ROTSTEP", "FILE", "NOFILE", "NAME:", "AUTHOR:", "!LICENSE"]


## The lines of [param a] [param b] has not got, as many times as they are
## there: but the app's own and the last empty one.
static func _minus(a: String, b: String) -> Array:
	var have: Dictionary = {}
	for line: String in b.split("\n"):
		var key: String = line.trim_suffix("\r")
		have[key] = int(have.get(key, 0)) + 1
	var out: Array = []
	var lines: PackedStringArray = a.split("\n")
	for n: int in lines.size():
		var key: String = lines[n].trim_suffix("\r")
		if key.begins_with("0 !BRICKWORKS") or (n == lines.size() - 1 and key.is_empty()):
			continue
		if int(have.get(key, 0)) > 0:
			have[key] = int(have[key]) - 1
		else:
			out.append(key)
	return out


## The colours of each step's parts in [param text], each step's sorted.
static func _colours_by_step(text: String) -> Array:
	var out: Array = []
	var now: Array = []
	for raw: String in text.split("\n"):
		var words: PackedStringArray = LdrModel._fields(raw.strip_edges())
		if words.size() >= 2 and words[0] == "0" and (words[1] == "STEP" or words[1] == "ROTSTEP"):
			now.sort()
			out.append(" ".join(now.map(func(c: int) -> String: return str(c))))
			now = []
		elif words.size() >= 15 and words[0] == "1":
			now.append(int(words[1]))
	if not now.is_empty():
		now.sort()
		out.append(" ".join(now.map(func(c: int) -> String: return str(c))))
	return out


static func _count(text: String, word: String) -> int:
	return text.count(word)


static func _first(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return ": " + " | ".join(lines.slice(0, 4).map(func(line: Variant) -> String:
		return str(line).left(100))) + (" ..." if lines.size() > 4 else "")


## Every part (its number, colour, copy, step and place in the file's
## coordinates) and every copy's step: steps as their order in the steps
## they are in, which an empty step or a step edit numbers otherwise.
func _state() -> Dictionary:
	var lift: Vector3 = _store.lift()
	var tree: Dictionary = {}
	var spaces: Dictionary = {}
	var bricks: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		bricks.append(brick)
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
		var t := Transform3D(brick.transform.basis, brick.transform.origin - lift)
		var place := PackedStringArray()
		for v: Vector3 in [t.origin / 10.0, t.basis.x, t.basis.y, t.basis.z]:
			for n: float in [v.x, v.y, v.z]:
				place.append("%.2f" % (snappedf(n, 0.01) + 0.0))
		parts.append("%s %d %s step %d at %s" % [brick.part_id, brick.color_code, path,
			int(ranks[_home(path)][brick.step]), " ".join(place)])
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
		# A part put down in no step comes back in the step a save put it in.
		var stepless: RegEx = RegEx.create_from_string(" step -?\\d+ ")
		var left: Dictionary = {}
		for line: String in have:
			for _n: int in int(have[line]):
				var key: String = stepless.sub(line, " step ? ")
				left[key] = int(left.get(key, 0)) + 1
		var still: Array = []
		for line: String in out:
			var key: String = stepless.sub(line, " step ? ")
			if int(left.get(key, 0)) > 0:
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
		if not b.has(key) or (str(b[key]) != str(a[key]) and not loose):
			out.append("%s %s -> %s" % [str(key), str(a[key]), str(b.get(key, "none"))])
	for key: Variant in b:
		if not a.has(key):
			out.append("%s new %s" % [str(key), str(b[key])])
	return out


# -- the file and the model ------------------------------------------------------


static func _fixture(file: String) -> String:
	return FileAccess.get_file_as_string(FX + file)


## The line of [param text] the part [param brick_id] was read from: by its
## origin, or, where the app keeps none (before keeptext4), the model's own
## line of its colour nearest where it is.
func _line_of(text: String, brick_id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var lines: PackedStringArray = text.split("\n")
	var origin: Variant = brick.get("origin")
	if origin != null and not str(origin).is_empty():
		var said: String = str(origin)
		return lines[said.get_slice("/", said.get_slice_count("/") - 1).to_int()].trim_suffix("\r")
	var at: Vector3 = brick.transform.origin - _store.lift()
	var best: String = ""
	var nearest: float = 0.5
	for raw: String in lines:
		var words: PackedStringArray = LdrModel._fields(raw.strip_edges())
		if words.size() < 15 or words[0] != "1" or int(words[1]) != brick.color_code:
			continue
		var numbers := PackedFloat64Array()
		for n: int in range(2, 14):
			numbers.append(words[n].to_float())
		var d: float = LdrModel.to_transform(numbers).origin.distance_to(at)
		if d < nearest:
			nearest = d
			best = raw.trim_suffix("\r")
	return best


## Whether the parts of colour [param colour] are a step of their own in
## [param text]: moved, they leave it empty.
static func _empties_step(text: String, colour: int) -> bool:
	var block: Array = []
	for line: String in text.split("\n"):
		if line.strip_edges() == "0 STEP":
			if not block.is_empty() and block.all(func(c: int) -> bool: return c == colour):
				return true
			block = []
		var words: PackedStringArray = LdrModel._fields(line.strip_edges())
		if words.size() >= 15 and words[0] == "1":
			block.append(int(words[1]))
	return false


## The model's own part lines in [param text]: those of its first section.
static func _own_part_lines(text: String) -> Array:
	var out: Array = []
	var files: int = 0
	for line: String in text.split("\n"):
		var words: PackedStringArray = LdrModel._fields(line.strip_edges())
		if words.size() >= 3 and words[0] == "0" and words[1].to_upper() == "FILE":
			files += 1
			if files > 1:
				break
		if words.size() >= 15 and words[0] == "1":
			out.append(line.trim_suffix("\r"))
	return out


## The lines of [param text] placing a sub-model.
static func _placing_lines(text: String) -> Array:
	var sections: Dictionary = {}
	for line: String in text.split("\n"):
		if line.strip_edges().to_upper().begins_with("0 FILE "):
			sections[LdrModel._key(line.strip_edges().substr(7))] = true
	var out: Array = []
	for line: String in text.split("\n"):
		var words: PackedStringArray = LdrModel._fields(line.strip_edges())
		if words.size() >= 15 and words[0] == "1" and sections.has(LdrModel._key(" ".join(words.slice(14)))):
			out.append(line.trim_suffix("\r"))
	return out


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


func _first_in(path: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path:
			return brick.id
	return -1


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


func _step_holding(brick_id: int) -> Instructions.Step:
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		if step.brick_ids.has(brick_id):
			return step
	return null


func _back_to(depth: int) -> void:
	while _builder.history_depth() > depth:
		_builder.undo()


func _open(text: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
