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
##   with no sub-model, line or step (kt4review);
## - clear_undo: clear_model undone lost every step and look (pkreview);
## - step_copy: a part of one copy of a wing placed twice moved to the
##   wing's other step showed on that copy alone, and opened again on both,
##   or on neither (snreview);
## - metas: TITLE and CUT_AWAY lines went in after "0 FILE x", above the
##   model's own title line, on every file with sub-models (kt4review);
## - numbers: a part turned 36 degrees recoloured or moved keeps the
##   numbers its line had (keeptext5 #7, checked).
## Each case opens its file (src/dev/fixtures/copyfaults_*, and for metas
## ten files with sub-models), makes its edit as a person or a session makes
## it, saves as Save saves, opens the save again, and compares parts,
## colours, copies, steps and lines as text, not by count.
##
##   COPYFAULTS_CASES=rename,metas   those cases
extends SceneTree

const FX := "res://src/dev/fixtures/"
const CASES: Array = ["rename", "duplicate", "rename_undo", "swap", "clear_undo", "step_copy",
	"metas", "numbers"]
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


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(1200.0).timeout.connect(func() -> void:
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
	var saved: String = _save()
	_check("...saved: only the title lines changed (%s)" % _diff(text, saved),
		_minus(text, saved) == ["0 Tower"] and _minus(saved, text) == ["0 Turret"])
	_check("...no tower 2.ldr", not saved.to_lower().contains("tower 2"))
	await _open(saved)
	var again: Array = _copy_said("Turret#2")
	_check("...opened again: Turret#2 blue as it was%s" % _unlike(_placed(twin), _placed(again)),
		_placed(twin) == _placed(again))


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
	var saved: String = _save()
	var placing: String = "1 1 200 -24 0 1 0 0 0 1 0 0 0 1 tower.ldr"
	_check("...saved: Tower#2's line as it was, nothing of the file lost (%s)" % _diff(text, saved),
		saved.contains("\n" + placing + "\n") and _minus(text, saved).is_empty())
	_check("...no tower 2.ldr", not saved.to_lower().contains("tower 2"))
	await _open(saved)
	var by_line: Array = []
	for path: String in _paths():
		if Assemblies.definition(path) == "Tower" and _placed(_copy_said(path)).any(
				func(line: String) -> bool: return line.contains(" c1 ")):
			by_line.append(path)
	_check("...opened again: one blue tower, as it was: %s" % str(by_line), by_line.size() == 1
		and _placed(_copy_said(by_line[0] if not by_line.is_empty() else "")) == _placed(twin))


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
## step; Tower#2 follows it, blue; the file names 3005 on that line.
func _case_swap() -> void:
	var text: String = _fixture("copyfaults_nest.mpd")
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
	print("  edit_model: %s" % said.get_slice("\n", 0).left(160))
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
	var follows: Array = _placed(_copy_said("Tower#2"))
	_check("...Tower#2 blue still, a 3005 where its 3062b was: %s" % " | ".join(follows),
		follows == _placed(twin).map(func(line: String) -> String:
			return line.replace("3062b", "3005")))
	var saved: String = _save()
	_check("...saved: the 3062b's line names 3005, nothing else changed (%s)" % _diff(text, saved),
		_minus(text, saved) == ["1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3062b.dat"]
		and _minus(saved, text) == ["1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat"])
	var undone: String = await _say("undo", {})
	print("  undo: %s" % undone.get_slice("\n", 0).left(120))
	var back: BrickWorld.Brick = _world.get_brick(round.id)
	_check("...undone: the 3062b back, under its number, on its line", back != null
		and back.part_id == "3062b" and back.origin == str(was["origin"])
		and back.unit == str(was["unit"]))
	_check("...and Tower#2 as it was%s" % _unlike(twin, _copy_said("Tower#2")),
		twin == _copy_said("Tower#2"))


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
		var saved: String = _save()
		await _open(saved)
		var again: String = _steps_said()
		_check("...opened again as the timeline showed it (%s)" % again, again == shown)
		_check("...both wings built the same way: %s" % shown,
			shown.get_slice(" | ", 1) == shown.get_slice(" | ", 3)
			and shown.get_slice(" | ", 2) == shown.get_slice(" | ", 4))


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
		_world.cut_kept = {"shape": "plane", "axis": "x", "at": 10.0, "away": 1, "ghosts": false}
		var saved: String = _store.to_text("Renamed Here", true)
		var said: String = _under_title(saved, title)
		_check("%s saved: %s" % [name, said if not said.is_empty() else "under the title %s" % title],
			said.is_empty())
		await _open(saved)
		_check("...opened again: its view, its cut and its name read back (%d, %s, %s)" % [
			_world.saved_views.size(), str(_world.cut_kept.get("shape", "none")),
			ModelStore.title_meta_in(saved)], _world.saved_views.size() == 1
			and not _world.cut_kept.is_empty() and ModelStore.title_meta_in(saved) == "Renamed Here")
		var again: String = _store.to_text("Renamed Here", true)
		said = _under_title(again, title)
		_check("...saved again: %s" % (said if not said.is_empty() else "the same, under its title"),
			said.is_empty() and again == saved)


## Where [param text]'s own lines stand against its title [param title]: ""
## when the line after its first "0 FILE" (or its first line) is the title
## and every VIEW, CUT_AWAY and TITLE line comes after that, in its section.
static func _under_title(text: String, title: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var start: int = 0
	if lines[0].trim_suffix("\r").begins_with("0 FILE "):
		start = 1
	if lines[start].trim_suffix("\r") != "0 " + title:
		return "line %d is %s, not the title %s" % [start + 1, lines[start].c_escape(), title]
	var ended: bool = false
	for n: int in lines.size():
		var line: String = lines[n].trim_suffix("\r")
		if n > start and (line.begins_with("0 FILE ") or line == "0 NOFILE"):
			ended = true
		for meta: String in [SavedViews.META, CutShape.META, ModelStore.TITLE_META]:
			if line.begins_with(meta) and (n <= start or ended):
				return "line %d, %s, is not under the title" % [n + 1, line.left(40)]
	for meta: String in [SavedViews.META, CutShape.META, ModelStore.TITLE_META]:
		if not text.contains(meta):
			return "no %sline" % meta.substr(14)
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
## file each is, the step looks.
func _tables() -> String:
	return JSON.stringify([_world.unit_steps, _world.unit_chains, _world.step_looks], "", true)


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
