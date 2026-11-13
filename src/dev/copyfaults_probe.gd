## Each copy of a sub-model stays itself through a rename, a duplicate, an
## undo and a swap over MCP; undoing a clear gives back what it took; the
## app's own lines stay under the model's title (copyfaults).
##
##   godot --headless --path . --script src/dev/copyfaults_probe.gd
##
## The faults, all live's as well as pre261's (docs/APP_UX7.md, unit 1):
## - rename: Tower#1 renamed, the blue Tower#2 came back red, its parts
##   new ones built from Tower#1's (kt4review);
## - duplicate: Tower#1 duplicated, the same;
## - rename_undo: the rename undone left the other copy "Turret#2", and a
##   save wrote it as a new Turret.ldr (kt4review);
## - swap: edit_model's remove + add where the part stood made a new part
##   with no sub-model, line or step (kt4review; copyfaults_towers.mpd);
## - clear_undo: clear_model undone lost every step and look (pkreview);
## - step_copy: a part of one copy of a wing placed twice moved to the
##   wing's other step showed on that copy alone, and opened again on both,
##   or on neither (snreview);
## - metas: TITLE and CUT_AWAY lines went in after "0 FILE x", above the
##   model's own title line, on every file with sub-models (kt4review), and
##   FROM_SET and AUTHORED_STEPS lines too;
## - numbers: a part turned 36 degrees recoloured or moved keeps the
##   numbers its line had (keeptext5 #7, checked).
## And cfcheck's, its fixtures src/dev/fixtures/cfc_* (copyfaults2): a twin
## follows part by part, never colour by colour, and keeps every part's
## number, order and line:
## - twin_steps: a step edit on one copy repainted and renumbered the other,
##   built again from it where the copies are placed in two colours;
## - twin_moves, twin_paints: one part moved, the other copy took the
##   moved one's colours, the colour each copy hands its parts of colour 16
##   (live's too); a part put down in a copy goes down in the other's;
## - clear_held: a clear undone lost the part the catalogue has not got from
##   the save and the autosave;
## - twin_relaid: a copy whose parts edit_model took off and put down again
##   counted as new, and its twin stayed;
## - clear_file: a clear undone gave the name back but not the file Save as
##   had written;
## - twin_nested: undoing a paint in a car's wheel left 14 parts for 10
##   (live's too);
## - clear_lit (lightpaths'): a clear undone lost a sub-model's own light and
##   view (BrickWorld.section_lines), and a save left them out of its section.
## And cf2check's (cffix):
## - twin_every, the invariant: one edit of each kind (put down, move, turn,
##   paint, delete, swap, a step edit; by hand and over MCP) in one copy at
##   depth 1, 2 and 3 (cf2_nest_same, cfc_nested, cf2_axles), and every copy
##   of each sub-model holds the same parts as each other: count, part,
##   place in its own frame, the same parts in the same steps, and colour by
##   the rule (its own colour in every copy, or each copy's placing colour;
##   a part painted from the placing colour in one copy keeps the other's
##   placing colour), after the edit, Undo, Redo, Save and open again, and
##   a second save the same file. A 3024 put down in Car#1/Wheel#1 went into
##   Car#2/Wheel#3 once with the wheel's copies and again with the car's;
##   three deep, once more with each copy round it. A session's edit says
##   the count of parts the follow left (cffix2);
## - clear_redo: a clear's undo landed a part on its way after the step, and
##   its redo left it on the bare baseplate.
## Each case opens its file (src/dev/fixtures/copyfaults_*, and for metas
## ten files with sub-models), makes its edit as a person or a session makes
## it, saves as Save saves, opens the save again, and compares parts,
## colours, copies, steps and lines as text, not by count.
##
##   COPYFAULTS_CASES=rename,metas   those cases
##   COPYFAULTS_KINDS=put,mcp_move   twin_every's edits, of EDITS
##   COPYFAULTS_DEPTHS=1,3           twin_every's copies edited, by depth
extends SceneTree

const FX := "res://src/dev/fixtures/"
const CASES: Array = ["rename", "duplicate", "rename_undo", "swap", "clear_undo", "step_copy",
	"metas", "numbers", "twin_steps", "twin_moves", "twin_paints", "clear_held", "twin_relaid",
	"clear_file", "twin_nested", "clear_lit", "twin_every", "clear_redo"]
## twin_every's files and the copy edited in each, one at each depth.
const EVERY: Array = [["cf2_nest_same.mpd", "Car#1"], ["cf2_nest_same.mpd", "Car#1/Wheel#1"],
	["cfc_nested.mpd", "Car#1"], ["cfc_nested.mpd", "Car#1/Wheel#1"],
	["cf2_axles.mpd", "Truck#1"], ["cf2_axles.mpd", "Truck#1/Axle#1"],
	["cf2_axles.mpd", "Truck#1/Axle#1/Wheel#1"]]
## twin_every's edits: by hand, and as a session makes them over MCP.
const EDITS: Array = ["put", "put_placing", "move", "turn", "paint", "delete", "swap", "step",
	"step_copy", "mcp_move", "mcp_turn", "mcp_paint", "mcp_delete", "mcp_swap", "mcp_step",
	"mcp_step_copy"]
## What a swap puts down for each part edited: as wide, another part.
const SWAP_FOR: Dictionary = {"6141": "3024", "3001": "3020", "3023": "3069b", "3062b": "3005"}
## Ten files with sub-models, for the app's own lines.
const METAS: Array = ["copyfaults_nest.mpd", "copyfaults_wing.ldr", "copyfaults_numbers.mpd",
	"kt3r_dupfile.mpd", "kt3r_title_author.mpd", "kt3r_whole.mpd", "kt_runs.mpd",
	"kt_crlf.mpd", "keep_text_notes.mpd", "telescope.mpd"]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _socket: CommandSocket
var _rpc_id: int = 0
## twin_every: each sub-model's copies as the file opened places them
## ([method _read_copies]), and the invariant's count, held and asked.
var _defs: Dictionary = {}
var _agreed: int = 0
var _asked: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("copyfaults probe: not finished in time")
		quit(1))
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
	var cases: Array = CASES if OS.get_environment("COPYFAULTS_CASES").is_empty() \
		else Array(OS.get_environment("COPYFAULTS_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"rename": await _case_rename()
			"duplicate": await _case_duplicate()
			"rename_undo": await _case_rename_undo()
			"swap": await _case_swap()
			"clear_undo": await _case_clear_undo()
			"step_copy": await _case_step_copy()
			"metas": await _case_metas()
			"numbers": await _case_numbers()
			"twin_steps": await _case_twin_steps()
			"twin_moves": await _case_twin_moves()
			"twin_paints": await _case_twin_paints()
			"clear_held": await _case_clear_held()
			"twin_relaid": await _case_twin_relaid()
			"clear_file": await _case_clear_file()
			"twin_nested": await _case_twin_nested()
			"clear_lit": await _case_clear_lit()
			"twin_every": await _case_twin_every()
			"clear_redo": await _case_clear_redo()
			_: _check("no such case %s" % name, false)
	print("\ncopyfaults probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- a copy renamed or duplicated -------------------------------------------------


## Tower#1 renamed Turret: the blue Tower#2 is the same parts, the same
## bricks, blue as it was, and the file's lines for it are as they were;
## opened again, it is still blue.
func _case_rename() -> void:
	var text: String = _fixture("copyfaults_nest.mpd")
	await _open(text)
	var twin: Array = _copy_said("Tower#2")
	var others: Dictionary = _copies_said(["Tower#1", "Tower#2"])
	print("  Tower#2 as opened: %s" % " | ".join(twin))
	_select_assembly("Tower#1")
	_shell.run("rename_assembly")
	await _frames(2)
	print("  %s" % _name_it("Turret"))
	await _frames(6)
	_shell.assemblies.leave_to("")
	_check("renamed: the paths %s" % str(_paths()),
		_paths().has("Turret#1") and _paths().has("Turret#2") and not _paths().has("Tower#2"))
	var now: Array = _copy_said("Turret#2")
	_check("...Turret#2 the same bricks, blue as Tower#2 was, byte for byte%s"
		% _unlike(twin, now), twin == now)
	_check("...every other copy as it was%s" % _unlike_dict(others,
		_copies_said(["Turret#1", "Turret#2"])), others == _copies_said(["Turret#1", "Turret#2"]))
	var shown: Array = _looks()
	var saved: String = _save()
	print("  saved: %s" % _diff(text, saved))
	_check("...saved: the tower named Turret, no Tower left", saved.contains("\n0 Turret")
		and not saved.contains("\n0 Tower"))
	await _open(saved)
	_check("...opened again: every part, its colour, place and step as shown%s"
		% _unlike(shown, _looks()), shown == _looks())
	_whole_write_note()


## Tower#1 duplicated and put down: Tower#2 is as it was, and so is the
## file's line for it.
func _case_duplicate() -> void:
	var text: String = _fixture("copyfaults_nest.mpd")
	await _open(text)
	var twin: Array = _copy_said("Tower#2")
	var first: Array = _copy_said("Tower#1")
	_select_assembly("Tower#1")
	(_main.get("_verbs") as EditVerbs).duplicate_selection(false)
	var put: int = await _put_down()
	_shell.assemblies.leave_to("")
	_check("duplicated Tower#1 and put it down (#%d): the paths %s" % [put, str(_paths())],
		put > 0 and _paths().has("Tower#3"))
	_check("...Tower#2 the same bricks, blue as it was, byte for byte%s"
		% _unlike(twin, _copy_said("Tower#2")), twin == _copy_said("Tower#2"))
	_check("...Tower#1 as it was%s" % _unlike(first, _copy_said("Tower#1")),
		first == _copy_said("Tower#1"))
	var made: Array = _placed(_copy_said("Tower#3"))
	_check("...Tower#3 red as Tower#1: %s" % " | ".join(made),
		made.size() == 3 and made.all(func(line: String) -> bool:
			return line.contains(" c4 ") or line.contains(" c14 ")))
	# Its step aside: the copy put down is in none yet (-1), and a save gives
	# it the one it is shown in.
	var shown: Array = _looks(false)
	var saved: String = _save()
	print("  saved: %s" % _diff(text, saved))
	await _open(saved)
	_check("...opened again: every part, its colour and place as shown%s"
		% _unlike(shown, _looks(false)), shown == _looks(false))
	var blue: int = 0
	for path: String in _paths():
		if _placed(_copy_said(path)) == _placed(twin):
			blue += 1
	_check("...one blue tower, as it was (%d)" % blue, blue == 1)
	_whole_write_note()


## The rename undone: no Turret anywhere, every part as it was, the save the
## file again; redone, the rename's save again.
func _case_rename_undo() -> void:
	var text: String = _fixture("copyfaults_nest.mpd")
	await _open(text)
	var before: Array = _every_part()
	var first: String = _save()
	var depth: int = _builder.history_depth()
	_select_assembly("Tower#1")
	_shell.run("rename_assembly")
	await _frames(2)
	print("  %s" % _name_it("Turret"))
	await _frames(6)
	_shell.assemblies.leave_to("")
	var renamed: String = _save()
	var after: Array = _every_part()
	_check("renamed in one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	_shell.run("undo")
	await _frames(6)
	_check("undone: the paths %s" % str(_paths()), not str(_paths()).contains("Turret"))
	_check("...every part as it was opened, byte for byte%s" % _unlike(before, _every_part()),
		before == _every_part())
	var undone: String = _save()
	_check("...saved: as before the rename, byte for byte (%s)" % _diff(first, undone),
		undone == first)
	_check("...no Turret in the file", not undone.contains("Turret"))
	_shell.run("redo")
	await _frames(6)
	_check("redone: every part as renamed, byte for byte%s" % _unlike(after, _every_part()),
		after == _every_part())
	var redone: String = _save()
	_check("...saved: as the rename saved (%s)" % _diff(renamed, redone), redone == renamed)


# -- a part swapped over MCP ----------------------------------------------------


## Over MCP, a 3062b of Tower#1 taken off and a 3005 put where it stood, in
## one edit_model: the new part is in Tower#1, on the 3062b's line, in its
## step, its colour; Tower#2 stays blue; the save opened again is what was
## shown; undone, the 3062b is back under its number on its line.
func _case_swap() -> void:
	var text: String = _fixture("copyfaults_towers.mpd")
	await _open(text)
	var round: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3062b" and brick.unit == "Tower#1":
			round = brick
	if not _check("Tower#1's 3062b found", round != null):
		return
	var was: Dictionary = {"group": round.group, "unit": round.unit, "step": round.step,
		"origin": round.origin, "at": _numbers(round.transform), "color": round.color_code}
	var where: Dictionary = _placement_of(round.id)
	var add: Dictionary = {"part": "3005", "color": round.color_code}
	for key: String in ["x", "y", "z", "face", "rot"]:
		if where.has(key):
			add[key] = where[key]
	var twin: Array = _copy_said("Tower#2")
	var said: String = await _say("edit_model", {"remove": [round.id], "add": [add],
		"picture": false})
	print("  edit_model: %s" % said.get_slice("\n", 0).left(300))
	var made: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3005" and brick.transform.origin.distance_to(round.transform.origin) < 0.6:
			made = brick
	if not _check("...a 3005 where the 3062b stood", made != null):
		return
	var now: Dictionary = {"group": made.group, "unit": made.unit, "step": made.step,
		"origin": made.origin, "at": _numbers(made.transform), "color": made.color_code}
	_check("...its sub-model, copy, step, line, place and colour the 3062b's (%s, was %s)"
		% [JSON.stringify(now), JSON.stringify(was)], now == was)
	var blue: Array = _placed(_copy_said("Tower#2"))
	_check("...Tower#2 blue still: %s" % " | ".join(blue), blue.size() == 3
		and blue.all(func(line: String) -> bool:
			return line.contains(" c1 ") or line.contains(" c14 ")))
	var shown: Array = _looks()
	var saved: String = _save()
	print("  saved: %s" % _diff(text, saved))
	await _open(saved)
	_check("...opened again: every part, its colour, place and step as shown%s"
		% _unlike(shown, _looks()), shown == _looks())
	_whole_write_note()
	await _open(text)
	round = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3062b" and brick.unit == "Tower#1":
			round = brick
	var opened: Array = _every_part()
	await _say("edit_model", {"remove": [round.id], "add": [add], "picture": false})
	var undone: String = await _say("undo", {})
	print("  undo: %s" % undone.get_slice("\n", 0).left(120))
	var back: BrickWorld.Brick = _world.get_brick(round.id)
	_check("...undone: the 3062b back, under its number, on its line", back != null
		and back.part_id == "3062b" and back.origin == str(was["origin"])
		and back.unit == str(was["unit"]))
	_check("...and every part as it was opened%s" % _unlike(opened, _every_part()),
		opened == _every_part())


# -- clear_model undone ------------------------------------------------------------


## The wing file (steps of its own, each named, two copies) cleared over
## MCP and undone: every part, step, copy, step name and line as it was,
## and the save the same; redone, nothing on the baseplate; undone again,
## all of it back once.
func _case_clear_undo() -> void:
	var text: String = _fixture("copyfaults_wing.ldr")
	await _open(text)
	var before: Array = _every_part()
	var tables: String = _tables()
	var first: String = _save()
	print("  as opened: %d parts, %s" % [before.size(), tables.left(300)])
	var said: String = await _say("clear_model", {})
	print("  clear_model: %s" % said.left(100))
	_check("...cleared: no part (%d)" % _every_part().size(), _every_part().is_empty())
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(120))
	await _frames(4)
	_check("...undone: every part, its step, copy and line as it was%s" % _unlike(before,
		_every_part()), before == _every_part())
	_check("...the copies' steps, step names and lines as they were (%s)" % _tables().left(400),
		_tables() == tables)
	var undone: String = _save()
	_check("...saved: as before the clear (%s)" % _diff(first, undone), undone == first)
	print("  redo: %s" % (await _say("undo", {"redo": true})).get_slice("\n", 0).left(120))
	await _frames(4)
	_check("...redone: no part (%d)" % _every_part().size(), _every_part().is_empty())
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(120))
	await _frames(4)
	_check("...undone again: every part once, as it was%s" % _unlike(before, _every_part()),
		before == _every_part())
	_check("...and the steps, step names and lines", _tables() == tables)


# -- a step edit on one copy -----------------------------------------------------


## A wing placed twice, built in its own two steps: a 3003 of one copy's
## second step moved to its first, over MCP. What the timeline shows then
## is what it shows when the save is opened again, for either copy.
func _case_step_copy() -> void:
	var text: String = _fixture("copyfaults_wing.ldr")
	for copy: int in [3, 5]:
		await _open(text)
		var opened: String = _steps_said()
		var brick: int = -1
		for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
			if step.number == copy:
				for id: int in step.brick_ids:
					if _world.get_brick(id).part_id == "3003":
						brick = id
						break
		var said: String = await _say("edit_steps", {"op": "prev", "bricks": [brick]})
		print("  a 3003 of step %d (copy %d's second) to the step before: %s" % [copy,
			1 if copy == 3 else 2, said.get_slice("\n", 0).left(100)])
		await _frames(4)
		var shown: String = _steps_said()
		print("  then: %s" % shown)
		await _say("undo", {})
		_check("...undone: both wings as opened (%s)" % _steps_said(), _steps_said() == opened)
		await _say("undo", {"redo": true})
		_check("...redone: as the edit left them", _steps_said() == shown)
		var saved: String = _save()
		await _open(saved)
		var again: String = _steps_said()
		_check("...opened again as the timeline showed it (%s)" % again, again == shown)
		# Steps 2 and 3 are the first wing's, 4 and 5 the second's: the same
		# parts in each, whatever the step's number.
		var parts_of := func(n: int) -> String: return shown.get_slice(" | ", n).get_slice("[", 1)
		_check("...both wings built the same way: %s" % shown,
			parts_of.call(1) == parts_of.call(3) and parts_of.call(2) == parts_of.call(4))


# -- the app's own lines in a file with sub-models ------------------------------------


## Each of ten files with sub-models given a saved view, a cut and a new
## name, saved, opened again and saved again: each time the line after the
## model's "0 FILE" is its title, and the VIEW, CUT_AWAY and TITLE lines
## are in the model's own section, under it.
func _case_metas() -> void:
	for name: String in METAS:
		var text: String = _fixture(name)
		await _open(text)
		var title: String = _first_title(text)
		_world.saved_views = [{"name": "front", "yaw": 0.5, "pitch": 0.3, "distance": 400.0,
			"focus": [0.0, 0.0, 0.0], "square": false}]
		# At an odd LDU, as the cut's own strip puts a plane (SeeInside._odd):
		# opened again, one at 10 is moved to 11.
		_world.cut_kept = {"shape": "plane", "axis": "x", "at": 11.0, "away": 1, "ghosts": false}
		_store.from_set = "6780-1"
		var saved: String = _store.to_text("Renamed Here", true)
		var said: String = _under_title(saved, title)
		_check("%s saved: %s" % [name, said if not said.is_empty() else "under the title %s" % title],
			said.is_empty())
		await _open(saved)
		var named: String = ModelStore.title_in(saved, "")
		_check("...opened again: its view, its cut and its name read back (%d, %s, %s)" % [
			_world.saved_views.size(), str(_world.cut_kept.get("shape", "none")), named],
			_world.saved_views.size() == 1 and not _world.cut_kept.is_empty()
			and named == "Renamed Here")
		var again: String = _store.to_text("Renamed Here", true)
		said = _under_title(again, title)
		_check("...saved again: %s" % (said if not said.is_empty() else "the same, under its title"
			+ _first_unlike(saved, again)), said.is_empty() and again == saved)


## Where [param text]'s own lines stand against its title [param title]: ""
## when the line after its first "0 FILE" (or its first line) is the title
## (or the new name, for a file of the app's own, which says it there and
## needs no TITLE line) and every VIEW, CUT_AWAY and TITLE line comes after
## that, in its section.
static func _under_title(text: String, title: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var start: int = 0
	if lines[0].trim_suffix("\r").begins_with("0 FILE "):
		start = 1
	if not lines[start].trim_suffix("\r") in ["0 " + title, "0 Renamed Here"]:
		return "line %d is %s, not the title %s" % [start + 1, lines[start].c_escape(), title]
	var ended: bool = false
	for n: int in lines.size():
		var line: String = lines[n].trim_suffix("\r")
		if n > start and (line.begins_with("0 FILE ") or line == "0 NOFILE"):
			ended = true
		for meta: String in [SavedViews.META, CutShape.META, ModelStore.TITLE_META,
				ModelStore.SET_META, LdrModel.AUTHORED_META]:
			if line.begins_with(meta) and (n <= start or ended):
				return "line %d, %s, is not under the title" % [n + 1, line.left(40)]
	for meta: String in [SavedViews.META, CutShape.META, ModelStore.SET_META]:
		if not text.contains(meta):
			return "no %sline" % meta.substr(14)
	if not text.contains(ModelStore.TITLE_META) and lines[start].trim_suffix("\r") != "0 Renamed Here":
		return "the new name nowhere"
	return ""


## Where two texts first part: "" when they are the same.
static func _first_unlike(a: String, b: String) -> String:
	if a == b:
		return ""
	var x: PackedStringArray = a.split("\n")
	var y: PackedStringArray = b.split("\n")
	for n: int in maxi(x.size(), y.size()):
		var one: String = x[n] if n < x.size() else "(none)"
		var two: String = y[n] if n < y.size() else "(none)"
		if one != two:
			return " (line %d was %s, is %s)" % [n + 1, one.left(90).c_escape(), two.left(90).c_escape()]
	return ""


static func _first_title(text: String) -> String:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("0 FILE "):
			continue
		return line.substr(2)
	return ""


# -- numbers as written ---------------------------------------------------------------


## A brick turned 36 degrees (0.806, 0.592), recoloured, and one in a turned
## sub-model moved: each line keeps the numbers the file wrote, but those the
## edit changed.
func _case_numbers() -> void:
	var text: String = _fixture("copyfaults_numbers.mpd")
	var turned: String = "1 4 10 -24 -30 0.806 0 0.592 0 1 0 -0.592 0 0.806 3001.dat"
	await _open(text)
	var brick: BrickWorld.Brick = null
	for each: BrickWorld.Brick in _world.bricks():
		if each.part_id == "3001" and each.color_code == 4:
			brick = each
	if not _check("the turned 3001 found", brick != null):
		return
	_builder.clear_selection()
	_builder.selection = {brick.id: true}
	_builder.paint_selection(2)
	_main.call("_on_model_edited")
	await _frames(4)
	var saved: String = _save()
	_check("recoloured: its line the same numbers, colour 2 (%s)" % _diff(text, saved),
		_minus(text, saved) == [turned] and _minus(saved, text) == [turned.replace("1 4 ", "1 2 ")])
	await _open(text)
	var inner: BrickWorld.Brick = null
	for each: BrickWorld.Brick in _world.bricks():
		if each.part_id == "3003":
			inner = each
	if not _check("the arm's turned 3003 found", inner != null):
		return
	_builder.clear_selection()
	_builder.selection = {inner.id: true}
	_builder.selection_changed.emit(1)
	var moved: int = _builder.move_selection(Vector3i(0, 0, 1))
	_main.call("_on_model_edited")
	await _frames(4)
	saved = _save()
	var lines: Array = _minus(saved, text)
	var was: PackedStringArray = "1 14 0.25 -24 0.5 0.806 0 0.592 0 1 0 -0.592 0 0.806 3003.dat".split(" ")
	var now: PackedStringArray = (lines[0] as String).split(" ") if lines.size() == 1 \
		else PackedStringArray()
	_check("moved %d: the line's turn as written (%s)" % [moved, _diff(text, saved)],
		now.size() == was.size() and now.slice(5, 14) == was.slice(5, 14)
		and now[1] == was[1] and now[14] == was[14])


# -- a copy follows its twin part by part (copyfaults2) ---------------------------


## (1) A step edit on one copy, over MCP, changes steps only: every other
## copy's parts keep their numbers, order, colours, places and lines, and
## copies that share their definition's steps are built in the same steps.
## The red post's 3005 of a sub-model placed red and blue put in the next
## step (cfc_owncolour.mpd), the red tower's 3003 of the nest, and the red
## wing's second step taken out (cfc_wing2.ldr).
func _case_twin_steps() -> void:
	for one: Array in [["cfc_owncolour.mpd", "Post#1", "3005", ["Post#2"], false],
			["copyfaults_nest.mpd", "Tower#1", "3003", ["Tower#2"], true],
			["cfc_wing2.ldr", "wing#1", "", ["wing#2"], true]]:
		print("  %s" % one[0])
		await _open(_fixture(one[0]))
		var opened: Array = _every_part()
		var tables: String = _tables()
		var kept: Dictionary = {}
		for path: String in one[3]:
			kept[path] = _twin_said(path, false)
		var said: String = ""
		if str(one[2]).is_empty():
			said = await _say("edit_steps", {"op": "delete", "step": 3})
		else:
			var brick: BrickWorld.Brick = _brick_of(one[1], one[2])
			said = await _say("edit_steps", {"op": "next", "bricks": [brick.id]})
		print("  edit_steps: %s" % said.get_slice("\n", 0).left(120))
		for path: String in one[3]:
			_check("...%s: every part's number, order, colour, place and line as opened%s"
				% [path, _unlike(kept[path], _twin_said(path, false))],
				kept[path] == _twin_said(path, false))
			if bool(one[4]):
				_check("...%s built in %s's steps (%s; %s)" % [path, one[1],
					", ".join(_shape_steps(path)), ", ".join(_shape_steps(one[1]))],
					_shape_steps(path) == _shape_steps(one[1]))
		await _round_of("the step edit", opened, tables)


## (2) A part of one copy moved where the copies are placed in two colours:
## each other copy moves its part alike and keeps every colour, number and
## line, part by part. The red post's 3005 a stud along (cfc_owncolour.mpd);
## the red cap's round brick, in the placing colour (cfc_cap.mpd); a blue
## car's wheel's top (cfc_nested.mpd), which three other wheels follow and
## the red car keeps red.
func _case_twin_moves() -> void:
	for one: Array in [["cfc_owncolour.mpd", "Post#1", "3005", ["Post#2"], Vector3i(10, 0, 0)],
			["cfc_cap.mpd", "Cap#1", "3062b", ["Cap#2"], Vector3i(10, 0, 0)],
			["cfc_nested.mpd", "Car#2/Wheel#4", "6141",
				["Car#1/Wheel#1", "Car#1/Wheel#2", "Car#2/Wheel#3"], Vector3i(0, 0, 10)]]:
		print("  %s" % one[0])
		await _open(_fixture(one[0]))
		var opened: Array = _every_part()
		var tables: String = _tables()
		var brick: BrickWorld.Brick = _brick_of(one[1], one[2])
		if not _check("...%s's %s found" % [one[1], one[2]], brick != null):
			continue
		var was: Vector3 = brick.transform.origin
		var before: Dictionary = {}
		for path: String in _paths():
			before[path] = _parts_of(path)
		_builder.clear_selection()
		_builder.selection = {brick.id: true}
		_builder.selection_changed.emit(1)
		var moved: int = _builder.move_selection(one[4])
		_main.call("_on_model_edited")
		await _frames(4)
		var by: Vector3 = brick.transform.origin - was
		print("  moved %d by %s" % [moved, str(by)])
		for path: String in _paths():
			if path == one[1]:
				continue
			var want: Array = _said_of(before[path], str(one[2]) if (one[3] as Array).has(path)
				else "", by)
			_check("...%s: %s%s" % [path, "its %s moved alike, every other part, colour, number and line as opened" % one[2]
				if (one[3] as Array).has(path) else "as opened", _unlike(want, _twin_said(path))],
				want == _twin_said(path))
		await _round_of("the move", opened, tables)


## (2) Paints, where the copies are placed in two colours (the nest's red and
## blue towers): a part in the placing colour painted in one copy keeps the
## other's its own; a part in a colour of its own painted paints the other's.
## And a part put down in the red post: in the post's red, the blue post's
## goes down blue; in green, green. Every other part as it was.
func _case_twin_paints() -> void:
	for one: Array in [["3003", 2, "c4"], ["6141", 1, "c1"]]:
		await _open(_fixture("copyfaults_nest.mpd"))
		var opened: Array = _every_part()
		var tables: String = _tables()
		var before: Array = _parts_of("Tower#1")
		var brick: BrickWorld.Brick = _brick_of("Tower#2", one[0])
		_builder.clear_selection()
		_builder.selection = {brick.id: true}
		_builder.selection_changed.emit(1)
		_builder.paint_selection(int(one[1]))
		_main.call("_on_model_edited")
		await _frames(4)
		var tile: bool = one[0] == "6141"
		var want: Array = _said_of(before, "", Vector3.ZERO).map(func(line: String) -> String:
			return line.replace(" c14 ", " c1 ") if tile and line.contains(" 6141 ") else line)
		_check("Tower#2's %s painted %d: Tower#1's %s, every other part as it was%s" % [one[0],
			one[1], one[2], _unlike(want, _twin_said("Tower#1"))], want == _twin_said("Tower#1"))
		await _round_of("the paint", opened, tables)
	for one: Array in [[4, 1], [2, 2]]:
		await _open(_fixture("cfc_owncolour.mpd"))
		var opened: Array = _every_part()
		var tables: String = _tables()
		var before: Array = _parts_of("Post#2")
		var top: BrickWorld.Brick = _brick_of("Post#1", "3005")
		var twin_top: BrickWorld.Brick = _brick_of("Post#2", "3005")
		var at: Transform3D = top.transform.translated(Vector3(0, 32, 0))
		var put: int = _builder.put_part("3024", int(one[0]), at)
		# As Builder.set_path puts it (by the class's name, Resource's answers).
		_world.get_brick(put).unit = "Post#1"
		_world.get_brick(put).group = "Post"
		_main.call("_on_model_edited")
		await _frames(4)
		var want: Array = _said_of(before, "", Vector3.ZERO)
		var fresh: Array = _twin_said("Post#2").slice(want.size())
		var fresh_at: String = _numbers(twin_top.transform.translated(Vector3(0, 32, 0)))
		_check("a 3024 put down in Post#1 in c%d: Post#2's parts as they were, and a 3024 c%d at %s (%s)"
			% [one[0], one[1], fresh_at, str(fresh)], _twin_said("Post#2").slice(0, want.size())
			== want and fresh.size() == 1 and str(fresh[0]).contains(" 3024 c%d %s " % [one[1],
			fresh_at]))
		await _round_of("the part put down", opened, tables)


## (3) A model holding a part the catalogue has not got, the app's own file
## (cfc_absent.ldr): cleared over MCP and undone, the save and the autosave
## keep its line; and a part on its way at the clear that has come by the
## undo is put down then.
func _case_clear_held() -> void:
	var text: String = _fixture("cfc_absent.ldr")
	await _open(text)
	var first: String = _save()
	_check("cfc_absent.ldr opened and saved: its zz9999 line kept", first.contains("zz9999.dat"))
	await _say("clear_model", {})
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
	await _frames(4)
	var undone: String = _save()
	_check("...cleared and undone, saved: the zz9999 line kept, as before the clear (%s)"
		% _diff(first, undone), undone.contains("zz9999.dat") and undone == first)
	_store.call("_write", ModelStore.autosave(), _store.title)
	_check("...autosaved: the zz9999 line kept",
		FileAccess.get_file_as_string(ModelStore.autosave()).contains("zz9999.dat"))
	await _open(undone)
	_check("...opened again and saved: the same file%s" % _first_unlike(undone, _save()),
		_save() == undone)
	await _open(text)
	var waiting := LdrModel.Placement.new("3001", 2, Transform3D(Basis.IDENTITY,
		Vector3(0, 200, 0)), 0)
	_store.awaited.append(waiting)
	await _say("clear_model", {})
	await _say("undo", {})
	await _frames(6)
	var landed: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001" and brick.color_code == 2:
			landed += 1
	_check("...a part on its way at the clear, come since, put down after the undo (%d; %d waiting)"
		% [landed, _store.awaited.size()], landed == 1 and _store.awaited.is_empty())


## (4) One edit_model takes both parts of the red post off and puts a 3005
## and a 3062b where they stood: the blue post follows, its 3005 under its
## number, a 3062b blue for its other.
func _case_twin_relaid() -> void:
	await _open(_fixture("cfc_posts.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var low: BrickWorld.Brick = _brick_of("Post#1", "3005", 0)
	var high: BrickWorld.Brick = _brick_of("Post#1", "3005", 1)
	var twin_low: Array = _twin_said("Post#2").slice(0, 1)
	var add: Array = []
	for pair: Array in [[_placement_of(low.id), "3005"], [_placement_of(high.id), "3062b"]]:
		var one: Dictionary = {"part": pair[1], "color": 4}
		for key: String in ["x", "y", "z", "face", "rot"]:
			if (pair[0] as Dictionary).has(key):
				one[key] = pair[0][key]
		add.append(one)
	var said: String = await _say("edit_model", {"remove": [low.id, high.id], "add": add,
		"picture": false})
	print("  edit_model: %s" % said.get_slice("\n", 0).left(160))
	var now: Array = _twin_said("Post#2")
	print("  Post#2: %s" % " | ".join(now))
	_check("...Post#2 follows: its 3005 as it was, under its number (%s)" % str(twin_low),
		now.size() == 2 and now.slice(0, 1) == twin_low)
	_check("...and a 3062b, blue, for its other 3005",
		now.size() == 2 and str(now[1]).contains(" 3062b c1 "))
	await _round_of("the edit", opened, tables)


## (5) A model saved to a file of its own (File, Save as), cleared over MCP
## and undone: Save writes that file again.
func _case_clear_file() -> void:
	await _open(_fixture("copyfaults_wing.ldr"))
	var bar: ModelBar = _main.get("_bar")
	var path: String = ProjectSettings.globalize_path("user://cf2_saved_as.ldr")
	print("  saved as %s: %s" % [path, str(await bar.save_to_file(path))])
	var wrote: String = FileAccess.get_file_as_string(path)
	_check("...written", wrote.contains("3020.dat"))
	await _say("clear_model", {})
	await _say("undo", {})
	await _frames(4)
	_check("...cleared and undone: the file to write still %s (%s)" % [path, bar.on_disk],
		bar.on_disk == path)
	DirAccess.remove_absolute(path)
	print("  saved: %s" % str(await bar._on_save()))
	_check("...Save writes it again, as before the clear%s" % _first_unlike(wrote,
		FileAccess.get_file_as_string(path)), FileAccess.get_file_as_string(path) == wrote)
	await _say("undo", {"redo": true})
	_check("...redone: no file to write (%s)" % bar.on_disk, bar.on_disk.is_empty())
	DirAccess.remove_absolute(path)


## (6) Two cars, red and blue, each with two wheels (cfc_nested.mpd): a
## wheel's black part painted green paints every wheel's, each car's top in
## its car's colour; undone, every part as opened, ten and no more.
func _case_twin_nested() -> void:
	await _open(_fixture("cfc_nested.mpd"))
	var opened: Array = _every_part()
	var tables: String = _tables()
	var before: Dictionary = {}
	for path: String in _paths():
		before[path] = _parts_of(path)
	var hub: BrickWorld.Brick = _brick_of("Car#1/Wheel#1", "3062b")
	_builder.clear_selection()
	_builder.selection = {hub.id: true}
	_builder.selection_changed.emit(1)
	_builder.paint_selection(2)
	_main.call("_on_model_edited")
	await _frames(4)
	_check("painted: the paths as opened (%s)" % str(_paths()), _paths() == before.keys())
	for path: String in before:
		var want: Array = _said_of(before[path], "", Vector3.ZERO).map(func(line: String) -> String:
			return line.replace(" 3062b c0 ", " 3062b c2 "))
		_check("...%s: %s%s" % [path, "its 3062b green, the rest as it was"
			if path.contains("Wheel") else "as it was", _unlike(want, _twin_said(path))],
			want == _twin_said(path))
	await _round_of("the paint", opened, tables)


## (lightpaths') A sub-model placed twice with a light and a view of its own
## (cfc_lit.mpd, the app's own file, so a save writes it whole): cleared over
## MCP and undone, the model keeps them; saved, they are in the sub-model's
## section, as before the clear, and opened again, still; redone, the model
## has none, and undone again, the same as the first undo.
func _case_clear_lit() -> void:
	var text: String = _fixture("cfc_lit.mpd")
	var own: Array = _lit_lines(text, "sub.ldr")
	await _open(text)
	var opened: Array = _every_part()
	var tables: String = _tables()
	var first: String = _save()
	_check("cfc_lit.mpd opened and saved: sub.ldr's light and view in its section (%s), none "
		% str(_lit_lines(first, "sub.ldr")) + "in main.ldr's",
		own.size() == 2 and _same_lit(_lit_lines(first, "sub.ldr"), _lit_saved(own, text, first))
		and _lit_lines(first, "main.ldr").filter(func(line: String) -> bool:
			return line.contains("sub view") or line.contains("#00ff00")).is_empty())
	await _say("clear_model", {})
	_check("...cleared: no part, no sub-model's lines (%s)" % JSON.stringify(_world.section_lines),
		_every_part().is_empty() and _world.section_lines.is_empty())
	print("  undo: %s" % (await _say("undo", {})).get_slice("\n", 0).left(100))
	await _frames(4)
	_check("...undone: every part as opened%s" % _unlike(opened, _every_part()),
		_every_part() == opened)
	_check("...the tables as opened, sub.ldr's lines with them (%s)" % _tables().left(300),
		_tables() == tables)
	var undone: String = _save()
	_check("...saved: sub.ldr's light and view in its own section (%s)"
		% str(_lit_lines(undone, "sub.ldr")),
		_same_lit(_lit_lines(undone, "sub.ldr"), _lit_saved(own, text, undone)))
	_check("...the save as before the clear%s" % _first_unlike(first, undone), undone == first)
	_shell.run("redo")
	await _frames(6)
	_check("...redone: no part, no sub-model's lines (%s)" % JSON.stringify(_world.section_lines),
		_every_part().is_empty() and _world.section_lines.is_empty())
	_shell.run("undo")
	await _frames(6)
	_check("...undone again: every part and table as opened", _every_part() == opened
		and _tables() == tables)
	await _open(undone)
	var again: String = _save()
	_check("...opened again and saved: sub.ldr's light and view in its own section (%s)"
		% str(_lit_lines(again, "sub.ldr")),
		_same_lit(_lit_lines(again, "sub.ldr"), _lit_saved(own, text, again)))
	_check("...the same file%s" % _first_unlike(_as_kept(undone), _as_kept(again)),
		_as_kept(again) == _as_kept(undone))


## The LIGHT and VIEW lines of [param text]'s section "0 FILE [param file]",
## in order, without line ends.
## [param own], sub.ldr's lines as [param read] has them, where a save that
## wrote [param saved] puts them: carried as its part is, from the frame the
## file wrote sub.ldr in to the one the save writes it in, so each stays where
## it was on the parts (Assemblies.lines_written, pcfix). A save writes the
## first copy where it stands, and up to 2026-11-12 this asked for the lines
## as read, which put the light 100 LDU off its part (lpcheck s7_a).
static func _lit_saved(own: Array, read: String, saved: String) -> Array:
	var was: Variant = _first_part(read, "sub.ldr")
	var now: Variant = _first_part(saved, "sub.ldr")
	if was == null or now == null:
		return own
	return Array(Assemblies.rebased(PackedStringArray(own),
		(now as Transform3D) * (was as Transform3D).affine_inverse()))


## The first part's line in [param file]'s section of [param text], as a
## transform in the file's coordinates; null for none.
static func _first_part(text: String, file: String) -> Variant:
	var inside: bool = false
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if bare.begins_with("0 FILE "):
			inside = bare == "0 FILE " + file
		elif inside and bare.begins_with("1 "):
			var f: PackedStringArray = bare.split(" ", false)
			if f.size() < 15:
				return null
			var n: Array = []
			for k: int in range(2, 14):
				n.append(float(f[k]))
			return Transform3D(Basis(Vector3(n[3], n[6], n[9]), Vector3(n[4], n[7], n[10]),
				Vector3(n[5], n[8], n[11])), Vector3(n[0], n[1], n[2]))
	return null


## Whether two lists of LIGHT and VIEW lines say the same, numbers to 0.01.
static func _same_lit(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for n: int in a.size():
		var one: String = str(a[n])
		var other: String = str(b[n])
		var cut: int = one.find("{")
		if cut < 0 or other.left(cut) != one.left(cut) \
				or not _about(JSON.parse_string(one.substr(cut)), JSON.parse_string(other.substr(cut))):
			return false
	return true


static func _about(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.01
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for n: int in (a as Array).size():
			if not _about(a[n], b[n]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		for key: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			if not _about((a as Dictionary).get(key), (b as Dictionary).get(key)):
				return false
		return true
	return a == b


static func _lit_lines(text: String, file: String) -> Array:
	var out: Array = []
	var inside: bool = false
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if bare.begins_with("0 FILE "):
			inside = bare == "0 FILE " + file
		elif inside and (bare.begins_with("0 !BRICKWORKS LIGHT ")
				or bare.begins_with("0 !BRICKWORKS VIEW ")):
			out.append(bare)
	return out


# -- cffix: each edit once in every copy, at every depth ------------------------------


## The invariant: every edit of [constant EDITS] made in each copy of
## [constant EVERY], each on its file as opened, and after it, its Undo,
## its Redo and its save opened again, every copy of each sub-model holds
## the same parts ([method _copies_agree]); and the round's own checks
## ([method _round_of]).
func _case_twin_every() -> void:
	var kinds: Array = EDITS if OS.get_environment("COPYFAULTS_KINDS").is_empty() \
		else Array(OS.get_environment("COPYFAULTS_KINDS").split(",", false))
	var depths: Array = Array(OS.get_environment("COPYFAULTS_DEPTHS").split(",", false))
	_agreed = 0
	_asked = 0
	for one: Array in EVERY:
		var path: String = one[1]
		var depth: int = Assemblies.segments(path).size()
		if not depths.is_empty() and not depths.has(str(depth)):
			continue
		for kind: String in kinds:
			var label: String = "%s %s (depth %d) %s" % [str(one[0]).get_basename(), path, depth,
				kind]
			print("\n  -- %s" % label)
			await _open(_fixture(one[0]))
			var read: String = _read_copies()
			if not _check("%s: each copy's frame read off its file's lines%s" % [label,
					"" if read.is_empty() else " (%s)" % read], read.is_empty()):
				continue
			_agree("%s opened" % label)
			var opened: Array = _every_part()
			var tables: String = _tables()
			var said: String = await _edit_every(kind, path)
			print("  %s" % said)
			if said.ends_with("nothing to do"):
				continue
			# A session's edit its checks refuse changes nothing, and nothing
			# follows: cf2_axles' axle plate is held by nothing, so a move,
			# turn or swap of it is refused (the wheels take them at depth 3).
			if said.contains(": Not applied") and _every_part() == opened:
				print("  refused by a session's checks: no edit, nothing to follow")
				continue
			if kind.contains("step"):
				print("  the copies' steps: %s" % JSON.stringify(_world.unit_steps))
			if not _check("...%s took: the model changed" % label, _every_part() != opened
					or _tables() != tables):
				continue
			_agree("%s, made" % label)
			# A session's edit says the count the copies that followed it
			# left: "Done. 4 bricks now." of the 3 a removal from one of two
			# copies left (pc2check, cffix2).
			var count: RegExMatch = RegEx.create_from_string("Done\\. (\\d+) bricks now").search(said)
			if count != null:
				_check("...%s: its reply counts the parts the follow left (said %s, %d stand)"
					% [label, count.get_string(1), _every_part().size()],
					int(count.get_string(1)) == _every_part().size())
			await _round_of(label, opened, tables, func(stage: String) -> void:
				if stage == "reopened":
					var again: String = _read_copies()
					if not again.is_empty():
						_check("...%s reopened: each copy's frame read off the save's lines (%s)"
							% [label, again], false)
						return
				_agree("%s, %s" % [label, stage]))
	print("\n  the invariant held %d times of %d" % [_agreed, _asked])
	_check("twin_every: every copy of each sub-model alike, every time (%d of %d)" % [_agreed,
		_asked], _asked > 0 and _agreed == _asked)


## Make the edit [param kind] in the copy at [param path]: on its highest
## part, or for a paint the highest of a colour of its own where it has one.
## Returns what was done.
func _edit_every(kind: String, path: String) -> String:
	var top: BrickWorld.Brick = null
	var low: BrickWorld.Brick = null
	var own: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) != path:
			continue
		if top == null or brick.transform.origin.y > top.transform.origin.y:
			top = brick
		if low == null or brick.transform.origin.y < low.transform.origin.y:
			low = brick
	if top == null:
		return "no part in %s" % path
	# A session's move, turn and swap are checked to hold together: on the
	# part the copy stands on, which stays on what it stood on.
	if kind in ["mcp_move", "mcp_turn", "mcp_swap"]:
		top = low
	if kind.ends_with("step_copy"):
		top = low
	var placing: int = _placing_shown(path, top.color_code)
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.color_code != placing and (own == null
				or brick.transform.origin.y > own.transform.origin.y):
			own = brick
	var painted: BrickWorld.Brick = own if own != null else top
	var swap: String = str(SWAP_FOR.get(top.part_id, "3024"))
	match kind:
		"put", "put_placing":
			var colour: int = 2 if kind == "put" else placing
			var put: int = await _hand_put_in("3024", colour,
				top.transform.translated(Vector3(0, 40, 0)), path)
			return "put down #%d, a 3024 in %d, in %s" % [put, colour, path]
		"move":
			_pick([top.id])
			var moved: int = _builder.move_selection(Vector3i(10, 0, 0))
			await _edited()
			return "moved #%d %s a stud: %d" % [top.id, top.part_id, moved]
		"turn":
			_pick([top.id])
			var turned: int = _builder.turn_selection(1)
			await _edited()
			return "turned #%d %s a quarter: %d" % [top.id, top.part_id, turned]
		"paint":
			_pick([painted.id])
			var count: int = _builder.paint_selection(2)
			await _edited()
			return "painted #%d %s (c%d) green: %d" % [painted.id, painted.part_id,
				painted.color_code, count]
		"delete":
			_pick([top.id])
			var count: int = _builder.remove_selection()
			await _edited()
			return "took off #%d %s: %d" % [top.id, top.part_id, count]
		"swap":
			_pick([top.id])
			var done: Vector2i = _builder.replace_selection(swap, true)
			await _edited()
			return "replaced #%d %s with a %s: %s" % [top.id, top.part_id, swap, str(done)]
		"step":
			var steps: StepsBar = _main.get("_steps")
			var said: String = _shell.change_steps("new", [top.id], steps.current_step())
			await _edited()
			return "#%d %s into a new step: %s" % [top.id, top.part_id, said]
		"step_copy", "mcp_step_copy":
			# A copy inside it into a new step of its own, the copy entered.
			var inner: String = ""
			for one: String in _paths():
				if Assemblies.parent_of(one) == path:
					inner = one
					break
			if inner.is_empty():
				return "no copy inside %s: nothing to do" % path
			var ids: Array = Array(_shell.assemblies.ids_under(inner))
			_shell.assemblies.enter(path)
			var said: String = ""
			if kind == "step_copy":
				var steps: StepsBar = _main.get("_steps")
				said = _shell.change_steps("new", ids, steps.current_step())
				await _edited()
			else:
				said = (await _say("edit_steps", {"op": "new", "bricks": ids})).replace("\n",
					" / ").left(400)
			_shell.assemblies.leave_to("")
			return "%s, in %s, into a new step: %s" % [inner, path, said]
		"mcp_move":
			return "edit_model move: " + (await _say("edit_model", {"move": [{"bricks": [top.id],
				"dx": 1}], "picture": false})).replace("\n", " / ").left(400)
		"mcp_turn":
			return "edit_model turn: " + (await _say("edit_model", {"turn": [{"bricks": [top.id],
				"yaw": 90}], "picture": false})).replace("\n", " / ").left(400)
		"mcp_paint":
			return "edit_model recolor: " + (await _say("edit_model", {"recolor": [{"bricks":
				[painted.id], "color": 2}], "picture": false})).replace("\n", " / ").left(400)
		"mcp_delete":
			return "edit_model remove: " + (await _say("edit_model", {"remove": [top.id],
				"picture": false})).replace("\n", " / ").left(400)
		"mcp_swap":
			var at: Dictionary = _placement_of(top.id)
			var one: Dictionary = {"part": swap, "color": top.color_code}
			for key: String in ["x", "y", "z", "face", "rot"]:
				if at.has(key):
					one[key] = at[key]
			return "edit_model swap for a %s: " % swap + (await _say("edit_model", {"remove":
				[top.id], "add": [one], "picture": false})).replace("\n", " / ").left(400)
		"mcp_step":
			return "edit_steps new: " + (await _say("edit_steps", {"op": "new",
				"bricks": [top.id]})).replace("\n", " / ").left(400)
	return "no such edit %s" % kind


## A part put down in the copy at [param path] by hand, as one step.
func _hand_put_in(part: String, colour: int, at: Transform3D, path: String) -> int:
	var put: int = _builder.put_part(part, colour, at)
	if put != 0:
		_world.get_brick(put).unit = path
		_world.get_brick(put).group = Assemblies.group_of(path)
	await _edited()
	return put


## Only the bricks [param ids] selected.
func _pick(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(ids.size())


## An edit by hand made: what the app does after one.
func _edited() -> void:
	_main.call("_on_model_edited")
	await _frames(4)


## The colour the copy at [param path] shows its parts of colour 16 in, as
## [method _read_copies] read it off its file against a copy placed in
## another; [param otherwise] where every copy is placed in one colour.
func _placing_shown(path: String, otherwise: int) -> int:
	for def: String in _defs:
		var placing: Dictionary = _defs[def]["placing"]
		if not placing.has(path):
			continue
		if not (placing[path] as Array).is_empty():
			return int(placing[path][1])
		for other: String in placing:
			if not (placing[other] as Array).is_empty():
				return int(placing[other][0])
	return otherwise


## Each sub-model's copies as the open file places them, into [member _defs]:
## definition -> {"paths", "frames" (path -> where it lies against the
## first copy: the same line's part of each, the one's place against the
## other's) and "placing" (path -> [the first copy's placing colour, its],
## or [] where the two show their parts of 16 alike)}. "" when each copy's
## frame agrees for every line; else why not.
func _read_copies() -> String:
	_defs.clear()
	var lines_of: Dictionary = {}    ## path -> line -> its part there
	for brick: BrickWorld.Brick in _world.bricks():
		var path: String = Assemblies.path_of(brick)
		if _store.scenery.has(brick.id) or path.is_empty():
			continue
		if brick.origin.is_empty():
			return "#%d %s in %s on no line" % [brick.id, brick.part_id, path]
		var line: String = brick.origin.get_slice("/", brick.origin.get_slice_count("/") - 1)
		if not lines_of.has(path):
			lines_of[path] = {}
		(lines_of[path] as Dictionary)[line] = brick
	for path: String in _paths():
		var def: String = Assemblies.definition(Assemblies.leaf(path))
		if not _defs.has(def):
			_defs[def] = {"paths": [], "frames": {}, "placing": {}}
		(_defs[def]["paths"] as Array).append(path)
	for def: String in _defs.keys():
		var paths: Array = _defs[def]["paths"]
		var first: Dictionary = lines_of.get(paths[0], {})
		# A sub-model of sub-models alone: its copies are said by theirs.
		if first.is_empty() and paths.all(func(path: String) -> bool:
				return not lines_of.has(path)):
			_defs.erase(def)
			continue
		for path: String in paths:
			var mine: Dictionary = lines_of.get(path, {})
			if mine.keys() != first.keys():
				return "%s's lines %s, %s's %s" % [path, str(mine.keys()), paths[0],
					str(first.keys())]
			var frame: Variant = null
			var placing: Array = []
			for line: String in first:
				var a: BrickWorld.Brick = first[line]
				var b: BrickWorld.Brick = mine[line]
				var t: Transform3D = b.transform * a.transform.affine_inverse()
				if frame == null:
					frame = t
				elif not _alike_at(t, frame):
					return "%s lies unlike %s on line %s" % [path, paths[0], line]
				if a.color_code != b.color_code:
					if placing.is_empty():
						placing = [a.color_code, b.color_code]
					elif placing != [a.color_code, b.color_code]:
						return "%s and %s differ in more than a placing colour" % [path, paths[0]]
			(_defs[def]["frames"] as Dictionary)[path] = frame
			(_defs[def]["placing"] as Dictionary)[path] = placing
	return ""


static func _alike_at(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.05 and a.basis.x.distance_to(b.basis.x) < 1e-3 \
		and a.basis.y.distance_to(b.basis.y) < 1e-3 and a.basis.z.distance_to(b.basis.z) < 1e-3


## Checked, said [param when]: every copy of each sub-model holds what its
## first copy does ([method _copies_agree]).
func _agree(when: String) -> void:
	var unlike: String = _copies_agree()
	_asked += 1
	_agreed += 1 if unlike.is_empty() else 0
	_check("...%s: every copy of each sub-model alike%s" % [when,
		"" if unlike.is_empty() else " (%s)" % unlike], unlike.is_empty())


## "" when every copy of each sub-model of [member _defs] holds the parts its
## first copy holds: as many, the same parts in the same places in its own
## frame, the same of them in a step together and in the same order of
## steps, and each in the colour the rule gives it (its own, or the copy's
## placing colour for one in the first copy's, or for one painted from it);
## else the first that does not.
func _copies_agree() -> String:
	for def: String in _defs:
		var paths: Array = _defs[def]["paths"]
		var first: Dictionary = _keyed(paths[0], Transform3D.IDENTITY)
		for path: String in paths.slice(1):
			var frame: Transform3D = _defs[def]["frames"][path]
			var placing: Array = _defs[def]["placing"][path]
			var mine: Dictionary = _keyed(path, frame)
			if mine.keys().size() != first.keys().size() or not mine.keys().all(
					func(key: String) -> bool: return first.has(key)):
				return "%s: %s; %s: %s" % [paths[0], _said_keys(first), path, _said_keys(mine)]
			for key: String in first:
				var theirs: Array = first[key]
				var ours: Array = mine[key]
				if theirs.size() != ours.size():
					return "%s has %d of %s, %s %d" % [paths[0], theirs.size(), key, path,
						ours.size()]
				theirs.sort()
				ours.sort()
				for n: int in theirs.size():
					var was: int = int(theirs[n])
					var is_now: int = int(ours[n])
					var given: int = int(placing[1]) if not placing.is_empty() \
						and was == int(placing[0]) else was
					var kept: bool = not placing.is_empty() and is_now == int(placing[1])
					if is_now != given and not kept:
						return "%s %s in c%d, in %s c%d" % [paths[0], key, was, path, is_now]
	return ""


## The parts directly in the copy at [param path], and the copies directly
## inside it, each laid back by [param frame] onto the first copy: "part at
## turned, step's place in the copy's order of steps" -> [their colours],
## and "copy of a definition at turned, the step it goes on in" -> [0].
func _keyed(path: String, frame: Transform3D) -> Dictionary:
	var bricks: Array = []
	var steps: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and Assemblies.path_of(brick) == path:
			bricks.append(brick)
			steps[brick.step] = true
	var inside: Array = _paths().filter(func(one: String) -> bool:
		return Assemblies.parent_of(one) == path)
	for one: String in inside:
		steps[int(_world.unit_steps.get(one, -1))] = true
	var order: Array = steps.keys()
	order.sort()
	var out: Dictionary = {}
	var back: Transform3D = frame.affine_inverse()
	for brick: BrickWorld.Brick in bricks:
		var at: Transform3D = back * brick.transform
		var key: String = "%s %s s%d" % [brick.part_id, _rounded(at), order.find(brick.step)]
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(brick.color_code)
	for one: String in inside:
		var def: String = Assemblies.definition(Assemblies.leaf(one))
		var placed: String = "?"
		if _defs.has(def) and (_defs[def]["frames"] as Dictionary).has(one):
			placed = _rounded(back * (_defs[def]["frames"][one] as Transform3D))
		var key: String = "copy-of-%s %s s%d" % [def, placed,
			order.find(int(_world.unit_steps.get(one, -1)))]
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(0)
	return out


static func _rounded(at: Transform3D) -> String:
	var out := PackedStringArray()
	for value: float in [at.origin.x, at.origin.y, at.origin.z]:
		var v: float = snappedf(value, 0.1)
		out.append("%.1f" % (0.0 if absf(v) < 0.05 else v))
	for axis: Vector3 in [at.basis.x, at.basis.y, at.basis.z]:
		for value: float in [axis.x, axis.y, axis.z]:
			out.append(str(roundi(value * 1000.0)))
	return ",".join(out)


static func _said_keys(keyed: Dictionary) -> String:
	var out: Array = []
	for key: String in keyed:
		out.append("%s x%d" % [key.get_slice(" ", 0) + " " + key.get_slice(" ", 1).left(24)
			+ " " + key.get_slice(" ", 2), (keyed[key] as Array).size()])
	out.sort()
	return " | ".join(out)


## cf2check F2: a session's clear of the app's own file with a part on its
## way (cfc_absent.ldr), undone as it has come: put down in the undo; its
## redo takes it off with the rest and the baseplate is bare; undone again,
## every part back once, and the save writes the part once.
func _case_clear_redo() -> void:
	var text: String = _fixture("cfc_absent.ldr")
	await _open(text)
	var count: int = _parts_here()
	_store.awaited.append(LdrModel.Placement.new("3001", 2, Transform3D(Basis.IDENTITY,
		Vector3(0, 200, 0)), 0))
	await _say("clear_model", {})
	await _say("undo", {})
	await _frames(6)
	_check("...undone: %d parts and the one come since (%d)" % [count, _parts_here()],
		_parts_here() == count + 1)
	await _say("undo", {"redo": true})
	await _frames(6)
	_check("...redone: the baseplate bare, nothing left behind (%d)" % _parts_here(),
		_parts_here() == 0)
	await _say("undo", {})
	await _frames(6)
	_check("...undone again: %d parts, each once (%d)" % [count + 1, _parts_here()],
		_parts_here() == count + 1)
	var saved: String = _save()
	_check("...saved: one green 3001 line, the zz9999 line kept (%d)"
		% RegEx.create_from_string("\\n1 2 [^\\n]*3001\\.dat").search_all(saved).size(),
		saved.contains("zz9999.dat") and RegEx.create_from_string("\\n1 2 [^\\n]*3001\\.dat")
			.search_all(saved).size() == 1)
	_shell.run("redo")
	await _frames(6)
	_check("...redone by hand: bare again (%d)" % _parts_here(), _parts_here() == 0)


func _parts_here() -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		n += 0 if _store.scenery.has(brick.id) else 1
	return n


# -- copyfaults2's helpers -----------------------------------------------------------


## The [param nth] lowest part [param part] of the copy at [param path].
func _brick_of(path: String, part: String, nth: int = 0) -> BrickWorld.Brick:
	var found: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path and brick.part_id == part:
			found.append(brick)
	found.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y < b.transform.origin.y)
	return found[nth] if nth < found.size() else null


## Each brick directly in the copy at [param path], in the model's order:
## number, part, colour, place, line and, where [param steps], step.
func _twin_said(path: String, steps: bool = true) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or Assemblies.path_of(brick) != path:
			continue
		out.append("#%d %s c%d %s o%s%s" % [brick.id, brick.part_id, brick.color_code,
			_numbers(brick.transform), brick.origin, " s%d" % brick.step if steps else ""])
	return out


## The bricks directly in the copy at [param path], in the model's order, as
## [number, part, colour, place, line, step]: what [method _said_of] reads.
func _parts_of(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and Assemblies.path_of(brick) == path:
			out.append([brick.id, brick.part_id, brick.color_code, brick.transform, brick.origin,
				brick.step])
	return out


## [param parts] ([method _parts_of]) as [method _twin_said] says them, each
## part [param moved] shifted [param by].
static func _said_of(parts: Array, moved: String, by: Vector3) -> Array:
	var out: Array = []
	for one: Array in parts:
		var at: Transform3D = one[3]
		if one[1] == moved:
			at = at.translated(by)
		out.append("#%d %s c%d %s o%s s%d" % [one[0], one[1], one[2], _numbers(at), one[4],
			one[5]])
	return out


## Each part of the copy at [param path] where it stands in the copy, with
## its step: "part x,y,z sN", sorted, from the copy's lowest corner.
func _shape_steps(path: String) -> Array:
	var low := Vector3(INF, INF, INF)
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path:
			low = low.min(brick.transform.origin)
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if Assemblies.path_of(brick) == path:
			var at: Vector3 = brick.transform.origin - low
			out.append("%s %d,%d,%d s%d" % [brick.part_id, roundi(at.x), roundi(at.y),
				roundi(at.z), brick.step])
	out.sort()
	return out


## Undo, redo, Save, open again and a second save of the edit just made,
## each checked: undone, every part (its number, colour, place, step, copy
## and line) and the world's tables as [param opened] and [param tables];
## redone, as the edit left them; saved and opened again, every part as
## shown; saved again, the same file, but for the title line a reopened
## whole write gains (metalines'). [param each], given, is told each of
## "undone", "redone" and "reopened" there. [param edits]: how many steps
## of history the edit took, each undone and redone.
func _round_of(what: String, opened: Array, tables: String, each: Callable = Callable(),
		edits: int = 1) -> void:
	var after: Array = _every_part()
	var after_tables: String = _tables()
	for i: int in edits:
		_shell.run("undo")
		await _frames(6)
	_check("...%s undone: every part as opened%s" % [what, _unlike(opened, _every_part())],
		_every_part() == opened)
	_check("...the tables as opened", _tables() == tables)
	if each.is_valid():
		each.call("undone")
	for i: int in edits:
		_shell.run("redo")
		await _frames(6)
	_check("...redone: every part as the edit left it%s" % _unlike(after, _every_part()),
		_every_part() == after)
	_check("...the tables as it left them", _tables() == after_tables)
	if each.is_valid():
		each.call("redone")
	var shown: Array = _looks()
	var shown_low: Array = _looks_low()
	var saved: String = _save()
	await _open(saved)
	# Opened, a model stands on the floor: one whose lowest part was taken
	# off or made lower stands lower, all of it alike.
	if shown != _looks() and shown_low == _looks_low():
		print("  note: opened again, the model stands on the floor, every part alike lower")
	_check("...saved and opened again: every part, colour, place and step as shown%s"
		% _unlike(shown, _looks()), shown == _looks() or shown_low == _looks_low())
	if each.is_valid():
		each.call("reopened")
	var again: String = _save()
	if again != saved and _as_kept(again) == _as_kept(saved):
		print("  note: saved again, %s; the same once those are set aside" % _first_unlike(saved,
			again).strip_edges())
	if not _check("...saved again: the same file%s" % _first_unlike(_as_kept(saved),
			_as_kept(again)), _as_kept(saved) == _as_kept(again)):
		print("    saved: %s\n    again: %s" % [saved.left(240).c_escape(), again.left(240).c_escape()])


## [param text] as a reopened whole write of it keeps it, as 7e6cb1aec wrote
## it too: its sub-models' sections in any order (so each without the line
## end after it), without a first copy's line. (A title line it gained,
## "0 !BRICKWORKS TITLE", was left out too until metalines wrote none.) A copy written as a sub-model of its own, "wing 2", opens again as
## "wing 2#1", which sorts before "wing#1", and is written first, saying it
## is copy 1 (cfc_wing2.ldr, any edit or none).
static func _as_kept(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		var bare: String = line.trim_suffix("\r")
		if bare != "0 !BRICKWORKS COPY 1":
			kept.append(line)
	var sections: PackedStringArray = "\n".join(kept).split("\n0 FILE ")
	var rest: Array = []
	for section: String in sections.slice(1):
		rest.append(section.strip_edges(false, true))
	rest.sort()
	return "\n0 FILE ".join(PackedStringArray([sections[0]] + rest))


# -- helpers ------------------------------------------------------------------------


## Each part of the copy at [param path]: its brick number, part, colour,
## place, step and line, sorted, as text.
func _copy_said(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id) or Assemblies.path_of(brick) != path:
			continue
		out.append("#%d %s c%d %s s%d o%s" % [brick.id, brick.part_id, brick.color_code,
			_numbers(brick.transform), brick.step, brick.origin])
	out.sort()
	return out


## [param said] without the brick numbers and lines: what a file opened
## again can give back.
static func _placed(said: Array) -> Array:
	var out: Array = said.map(func(line: String) -> String:
		return line.substr(line.find(" ") + 1).get_slice(" o", 0))
	out.sort()
	return out


func _copies_said(but: Array) -> Dictionary:
	var out: Dictionary = {}
	for path: String in _paths():
		if not but.has(path):
			out[path] = _copy_said(path)
	out["(model)"] = _copy_said("")
	return out


## Every part as it looks, sorted: part, colour, place and step, not which
## copy of what it is in, which a whole write may name afresh.
func _looks(with_steps: bool = true) -> Array:
	var out: Array = _placed(_every_part()).map(func(line: String) -> String:
		var looks: String = line.get_slice(" [", 0)
		return looks if with_steps else looks.left(looks.rfind(" s")))
	out.sort()
	return out


## [method _looks] from the lowest part's place up: as alike when the whole
## model stands higher or lower.
func _looks_low() -> Array:
	var low: float = INF
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			low = minf(low, brick.transform.origin.y)
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append("%s c%d %s s%d" % [brick.part_id, brick.color_code,
				_numbers(brick.transform.translated(Vector3(0, -low, 0))), brick.step])
	out.sort()
	return out


## Said, not checked: whether the copies of the tower are still one
## sub-model after a save opened again. A whole write (live's, which a
## rename, a duplicate or copies that differ make) writes a copy placed in
## another colour as a definition of its own (Assemblies.file_frames,
## LdrModel.write_tree's "1 16" references): savefix's lines.
func _whole_write_note() -> void:
	var defs: Dictionary = {}
	for path: String in _paths():
		defs[Assemblies.definition(Assemblies.leaf(path))] = true
	print("  note: opened again, the sub-models are %s" % str(defs.keys()))


## Every part, with its copy, as text, sorted: what an undo puts back.
func _every_part() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append("#%d %s c%d %s s%d [%s|%s] o%s" % [brick.id, brick.part_id, brick.color_code,
			_numbers(brick.transform), brick.step, brick.group, brick.unit, brick.origin])
	out.sort()
	return out


## The world's tables kept by path: each copy's step, which copy of the
## file each is, the step looks, and each sub-model's own lights and views.
func _tables() -> String:
	return JSON.stringify([_world.unit_steps, _world.unit_chains, _world.step_looks,
		_world.section_lines], "", true)


func _paths() -> Array:
	return Array(_shell.assemblies.paths())


static func _numbers(at: Transform3D) -> String:
	var b: Basis = at.basis
	return "%.3f %.3f %.3f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f" % [at.origin.x,
		at.origin.y, at.origin.z, b.x.x, b.y.x, b.z.x, b.x.y, b.y.y, b.z.y, b.x.z, b.y.z, b.z.z]


static func _unlike(a: Array, b: Array) -> String:
	if a == b:
		return ""
	var gone: Array = a.filter(func(line: Variant) -> bool: return not b.has(line))
	var new: Array = b.filter(func(line: Variant) -> bool: return not a.has(line))
	return " (was %s; now %s)" % [" | ".join(gone.slice(0, 4)), " | ".join(new.slice(0, 4))]


static func _unlike_dict(a: Dictionary, b: Dictionary) -> String:
	for key: Variant in a:
		if not b.has(key) or a[key] != b[key]:
			return " (%s%s)" % [key, _unlike(a[key], b.get(key, []))]
	return ""


## The lines of [param a] not in [param b], the app's own aside.
static func _minus(a: String, b: String) -> Array:
	var have: Dictionary = {}
	for line: String in b.split("\n"):
		var key: String = line.trim_suffix("\r")
		have[key] = int(have.get(key, 0)) + 1
	var out: Array = []
	for line: String in a.split("\n"):
		var key: String = line.trim_suffix("\r")
		if key.begins_with("0 !BRICKWORKS") or key.is_empty():
			continue
		if int(have.get(key, 0)) > 0:
			have[key] = int(have[key]) - 1
		else:
			out.append(key)
	return out


static func _diff(before: String, after: String) -> String:
	var out: Array = _minus(after, before).map(func(line: String) -> String: return "+ " + line.left(70))
	out.append_array(_minus(before, after).map(func(line: String) -> String: return "- " + line.left(70)))
	return "; ".join(out.slice(0, 8)) if not out.is_empty() else "no line changed"


func _save() -> String:
	return _store.to_text(_store.title, true)


func _fixture(name: String) -> String:
	return FileAccess.get_file_as_string(FX + name)


func _open(text: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, "model")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(10)


func _select_assembly(path: String) -> void:
	_shell.assemblies.leave_to(Assemblies.parent_of(path))
	_builder.clear_selection()
	for brick_id: int in _shell.assemblies.ids_under(path):
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


## The held copy put down beside the model, as a click would.
func _put_down() -> int:
	var carry: Carry = _builder.carrying
	if carry == null:
		return 0
	var low := Vector3(INF, INF, INF)
	var high := -low
	for brick: BrickWorld.Brick in _world.bricks():
		low = low.min(brick.transform.origin)
		high = high.max(brick.transform.origin)
	var room: float = 4.0 * BrickLattice.STUD
	carry.stand_where_lifted(_builder.lattice, _builder)
	carry.pin()
	for k: int in 6:
		var by := Vector3(high.x - low.x + room * (k + 1), 0.0, 0.0)
		if carry.show_moved(Transform3D(Basis.IDENTITY, by), _builder.lattice, _builder):
			var put: int = _builder.place()
			await _frames(4)
			_builder.cancel_carry()
			return put
	_builder.cancel_carry()
	return 0


## Where the assistant reads brick [param id] as standing, as a session's
## look_at_model gives it: x, y, z, face and rot.
func _placement_of(id: int) -> Dictionary:
	var assistant: Object = _main.get("_assistant")
	var model: Object = assistant.call("_model_from_world")
	for placement: Object in model.get("placements"):
		if int(placement.get("id")) == id:
			return {"x": placement.get("x"), "y": placement.get("y"), "z": placement.get("z"),
				"face": placement.get("face"), "rot": placement.get("rot")}
	return {}


func _steps_said() -> String:
	var out := PackedStringArray()
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		var parts := PackedStringArray()
		for id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null:
				parts.append("%s/%d" % [brick.part_id, brick.color_code])
		parts.sort()
		out.append("%d[%s]" % [step.number, ",".join(parts)])
	return " | ".join(out)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	await _frames(4)
	return "\n".join(lines)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
