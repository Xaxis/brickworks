## A model checked against its set's own steps (setcheck, APP_UX10 #4), as a
## person and their Claude use it: ten sets of LDraw's model repository, each
## opened from the library as File, Open, From the library… opens one, then
## changed by a script as a person changes one (3 parts taken away, 2
## recoloured, 2 swapped for a near mould, 1 moved a stud, 1 taken out of its
## sub-model into the one round it), and checked with File, Compare with the
## set… and with compare_with_set.
##
##   godot --headless --path . --script src/dev/setcheck_probe.gd
##   SETCHECK_ONLY=7140-1 for one set, SETCHECK_ONLY=time for the biggest sets' times.
##
## What counts: each set, opened, matches its set. Changed, every change is
## found and none more: its kind, the part it was, the set's step it is in
## (read again here from the file's own STEP lines) and where it is in the
## model (its sub-model, and the line of the file it was read from). A row
## clicked selects that part. compare_with_set says the same in one call.
## Undone, it matches again. Nothing written: the model's parts, its history,
## whether it is unsaved, and a saved file's bytes, the same after a check.
## The walk's g1 (7140-1 opened, two parts changed, compared with the set) in
## 3 calls. And the time: 10179 and the library's biggest sets, by parts
## (42100-1) and by file (8466-1, 36 MB), checked with the status bar saying
## so and the window's frames going on.
##
## The library is played by tools/web/serve.py (port 10901) from an index
## of these sets written here and the repository's own files.
extends SceneTree

const PORT := 10901
const SETS: Array[String] = ["7140-1", "6080-1", "6399-1", "6542-1", "8880-1", "10030-1",
	"10212-1", "4558-1", "6285-1", "10179-1"]
## The biggest sets of the library: by parts, and by file.
const BIGGEST := "42100-1"
## Reads and matches of each set on workers while the frames change things.
const STRESS_RUNS := 3
const BIGGEST_FILE := "8466-1"
## The colours a part is recoloured to: Red, else Blue.
const RED := 4
const BLUE := 1

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _assemblies: Assemblies
var _shell: Shell
var _compare: Control
var _socket: CommandSocket
var _server: int = 0
var _next: int = 0
## The job polls _say made following long calls.
var _polls: int = 0
var _failures: int = 0
## Part family (Collection.family_of) -> its numbers the library has.
var _families: Dictionary = {}
## The tally the report gives: found, missed, false, by set.
var _tally: Array = []
## The stress's runs, what they found and named that was not changed, and the
## frames that changed the library and the model as they ran.
var _stress: Array = [0, 0, 0, 0]


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var only: String = OS.get_environment("SETCHECK_ONLY")
	var shelf: String = _write_index()
	_server = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/web/serve.py"),
		shelf, str(PORT), "--library", shelf, "--omr",
		ProjectSettings.globalize_path("res://vendor/omr/files")])
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:%d" % PORT)
	await create_timer(1.5).timeout
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_assemblies = _shell.assemblies
	_compare = _shell.compare
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame
	for part: String in _library.parts:
		var family: String = Collection.family_of(part)
		if not _families.has(family):
			_families[family] = []
		(_families[family] as Array).append(part)

	await _menu()
	await _g1()
	for number: String in SETS:
		if only.is_empty() or only == number:
			await _one_set(number)
	if only.is_empty():
		await _nothing_written()
	# SETCHECK_ONLY=time: the biggest sets' times alone.
	if only.is_empty() or only == "time":
		await _biggest()
	print("")
	var found: int = 0
	var missed: int = 0
	var wrong: int = 0
	for row: Array in _tally:
		print("  %-9s found %d, missed %d, false %d" % row)
		found += int(row[1])
		missed += int(row[2])
		wrong += int(row[3])
	if int(_stress[0]) > 0:
		print("  stress: %d runs on workers, %d frames changing the library and the model: %d found, %d false" % [
			_stress[0], _stress[3], _stress[1], _stress[2]])
	print("setcheck: %d sets, %d found, %d missed, %d false; %s" % [_tally.size(), found, missed,
		wrong, "all pass" if _failures == 0 else "%d FAILED" % _failures])
	_done()


func _done() -> void:
	if _server > 0:
		OS.kill(_server)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## An index of the sets checked here, in the library's own form
## (tools/library_build.py), named from the repository's index.
func _write_index() -> String:
	var shelf: String = ProjectSettings.globalize_path("user://setcheck_shelf")
	DirAccess.make_dir_recursive_absolute(shelf)
	var names: Dictionary = {}
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://vendor/omr/index.json"))
	if listed is Array:
		for row: Variant in listed:
			if row is Dictionary:
				names[str(row.get("number", ""))] = row
	var models: Array = []
	var all: Array[String] = SETS.duplicate()
	all.append_array([BIGGEST, BIGGEST_FILE])
	for number: String in all:
		var row: Dictionary = names.get(number, {})
		models.append({"id": "omr-" + number, "kind": "set", "set": number,
			"name": str(row.get("name", number)), "theme": str(row.get("theme", "")),
			"year": int(str(row.get("year", "0"))), "parts": 0,
			"file": "library/omr/%s.mpd" % number, "author": "LDraw OMR", "licence": "CCAL 2.0",
			"page": "", "alternate_of": null})
	# serve.py --library DIR answers /library/index.json from DIR/index.json.
	var out := FileAccess.open(shelf + "/index.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"version": 1, "models": models}))
	out.close()
	return shelf


func _say(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	# A long call (an open at load) is a job: followed to its answer, as a
	# session follows it, each poll a call of its own.
	var job: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(text)
	if job != null and tool != "job":
		for _n: int in 600:
			for _frame: int in 30:
				await process_frame
			_polls += 1
			var polled: String = await _say("job", {"id": int(job.get_string(1))})
			if not polled.contains(" is still going"):
				return polled
	return text


## Opened as a session opens a set (open_model library=), over whatever was
## there, and waited for until every part is down.
func _open(number: String) -> String:
	var said: String = await _say("open_model", {"library": "omr-" + number, "discard_changes": true})
	await _settled()
	return said


func _settled() -> void:
	var last: int = -1
	var calm: int = 0
	for _n: int in 3000:
		await process_frame
		var now: int = _world.brick_count()
		calm = calm + 1 if now == last and not _store.laying and _store.awaited_now().is_empty() else 0
		last = now
		if calm >= 20:
			return


## What the model is, to the byte: every part, its colour, place and
## sub-model; to see a check changed none of it.
func _standing(ids: bool = true) -> String:
	var rows := PackedStringArray()
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		rows.append("%s %s %d %s %s" % [str(brick.id) if ids else "", brick.part_id, brick.color_code,
			var_to_str(brick.transform.orthonormalized().origin.snapped(Vector3.ONE * 0.01)),
			Assemblies.path_of(brick)])
	rows.sort()
	return "\n".join(rows).sha256_text()


# -- the menu --------------------------------------------------------------------


func _menu() -> void:
	print("\nthe menu")
	var rows: Array = Shell.SUBMENUS.get("compares", [])
	_check("File › Compare has it after Compare two sets or models: %s (%s)"
		% [Keymap.menu_row("compare_set"), ", ".join(rows)],
		rows.find("compare_set") == rows.find("compare_sets") + 1 and rows.find("compare_sets") >= 0
		and Keymap.menu_row("compare_set") == "File › Compare › Compare with the set"
		and _shell.menu_id("compare_set") >= 0)


# -- g1: 7140-1 opened, two parts changed, compared with the set -------------------


func _g1() -> void:
	print("\ng1: 7140-1 opened, two parts changed, compared with the set step by step")
	var calls: int = 0
	var polls: int = _polls
	var began: int = Time.get_ticks_msec()
	var opened: String = await _open("7140-1")
	calls += 1
	var bricks: Array = _loose_parts()
	var recolour: BrickWorld.Brick = bricks[bricks.size() / 3]
	var take: BrickWorld.Brick = bricks[2 * bricks.size() / 3]
	var old_colour: int = recolour.color_code
	var colour: int = RED if old_colour != RED else BLUE
	var edited: String = await _say("edit_model", {"recolor": [{"bricks": [recolour.id], "color": colour}],
		"remove": [take.id]})
	calls += 1
	var said: String = await _say("compare_with_set", {})
	calls += 1 + _polls - polls
	var ms: int = Time.get_ticks_msec() - began
	print("    " + said.replace("\n", "\n    ").left(1600))
	_check("opened: %s" % opened.left(80).replace("\n", " "), _world.brick_count() > 300)
	_check("changed two parts: %s" % edited.left(80).replace("\n", " "),
		_world.get_brick(take.id) == null and _world.get_brick(recolour.id).color_code == colour)
	_check("compared in the same answer: 1 taken away, 1 recoloured, each by the set's step and its line",
		said.contains("Checked against 7140-1") and said.contains("1 taken away")
		and said.contains("1 recoloured") and said.contains("line %d" % (SetCheck.line_of(take.origin) + 1))
		and said.contains("line %d" % (SetCheck.line_of(recolour.origin) + 1))
		and said.contains("(#%d)" % recolour.id) and said.contains("step ")
		and said.contains("edit_model recolor bricks [%d] color %d" % [recolour.id, old_colour]))
	_check("g1 in %d calls (at most 3), %.1f s" % [calls, ms / 1000.0], calls <= 3)
	# The number as pasted from a web page, and words that are no number.
	var pasted: String = await _say("compare_with_set", {"set": "\u00a07140-1\u200b "})
	_check("a pasted number with a no-break and a zero-width space is the set: %s" % pasted.get_slice("\n", 0).left(60),
		pasted.begins_with("Checked against 7140-1"))
	var junk: String = await _say("compare_with_set", {"set": "x".repeat(5000)})
	_check("5,000 letters are refused in words, %d long: %s" % [junk.length(), junk.left(60)],
		junk.length() < 200 and junk.contains("not a set's number"))
	var quiet: String = await _say("compare_with_set", {"show": false, "most": 60})
	_check("show=false and most=60 say what nothing given says", quiet == said)


## The model's parts read from its file, not the baseplate's, in order.
func _loose_parts() -> Array:
	var out: Array = []
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if not _store.scenery.has(brick.id) and not brick.origin.is_empty():
			out.append(brick)
	out.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	return out


# -- ten sets, nine changes each ----------------------------------------------------


## One planned change: its kind, the brick, the set's line it was read from,
## and what it became.
class Planned extends RefCounted:
	var kind: String = ""
	var id: int = 0
	var part: String = ""
	var line: int = -1
	var path: String = ""
	var into: String = ""
	var found: SetCheck.Change = null


func _one_set(number: String) -> void:
	print("\n%s" % number)
	var opened: String = await _open(number)
	var text: String = (await (_main.get("_model_library") as ModelLibrary).fetch_model("omr-" + number))["text"]
	_check("opened: %s" % opened.left(70).replace("\n", " "), _world.brick_count() > 0)
	# As opened: it matches.
	var was: String = _standing(false)
	var unsaved: bool = _store.has_unsaved_work()
	var depth: int = _builder.history_depth()
	if number == SETS[0]:
		# The first from its menu row, as a person opens it.
		_check("File › Compare › Compare with the set can be pressed", _shell.run("compare_set"))
		for _n: int in 900:
			await process_frame
			if _compare.visible and _compare.checked != null and not _compare.checking:
				break
	else:
		await _compare.open_set()
	var fields: Dictionary = _compare.set_fields()
	var check: SetCheck = _compare.checked
	_check("as opened, the panel says it matches: %s" % str(fields.get("head", "")).left(110),
		check != null and check.matches() and str(fields["head"]).contains("It matches the set")
		and str(fields["number"]) == number)
	if check != null and not check.matches():
		for change: SetCheck.Change in check.changes.slice(0, 6):
			print("      " + check.line_words(change, _library))
	if number == SETS[0]:
		await _enter_once(number)
	_compare.close()
	# Changed by a script, as a person changes one.
	var plan: Array = _change(number)
	if plan.size() != 9:
		_check("nine changes made (%d)" % plan.size(), false)
		_tally.append([number, 0, 9, 0])
		return
	var after: String = _standing()
	unsaved = _store.has_unsaved_work()
	depth = _builder.history_depth()
	await _compare.open_set()
	check = _compare.checked
	fields = _compare.set_fields()
	if check == null:
		_check("checked: %s" % str(fields.get("head", "")), false)
		_tally.append([number, 0, 9, 0])
		return
	print("    %s (%.0f ms to match)" % [check.heading(), check.matched_ms])
	var lines: PackedStringArray = text.split("\n")
	var claimed: Dictionary = {}
	for planned: Planned in plan:
		for change: SetCheck.Change in check.changes:
			if not claimed.has(change) and _is(change, planned):
				planned.found = change
				claimed[change] = true
				break
	var found: int = 0
	for planned: Planned in plan:
		var change: SetCheck.Change = planned.found
		if change == null:
			_check("found: %s %s (line %d)" % [planned.kind, planned.part, planned.line + 1], false)
			continue
		found += 1
		var row: String = check.line_words(change, _library)
		var step: String = check.step_of(change)
		var counted: int = _step_in_file(lines, planned.line)
		var where: String = SetCheck.where_words(planned.into if planned.kind == SetCheck.REGROUPED
			else planned.path)
		_check("%s, %s: %s" % [planned.kind, step, row],
			row.contains("line %d" % (planned.line + 1)) and row.contains(where)
			and step.begins_with("step %d" % counted) and _innermost(change) == counted)
	var wrong: int = check.changes.size() - claimed.size()
	for change: SetCheck.Change in check.changes:
		if not claimed.has(change):
			print("      not changed, but named: " + check.line_words(change, _library))
	_check("9 found, 0 missed, 0 named that were not changed (%d named)" % check.changes.size(),
		found == 9 and wrong == 0)
	_tally.append([number, found, 9 - found, wrong])
	_check("the panel lists them by the set's steps: %d rows under %d steps" % [
		(fields["rows"] as Array).size(), (fields["steps"] as Array).size()],
		(fields["rows"] as Array).size() == check.changes.size() and not (fields["steps"] as Array).is_empty()
		and str(fields["steps"][0]).begins_with("Step"))
	# A row clicked selects its part.
	var named: Dictionary = _compare.controls_by_name()
	var selected: int = 0
	var to_select: int = 0
	for n: int in check.changes.size():
		var change: SetCheck.Change = check.changes[n]
		var button: Button = named.get("compare_set_row_%d" % n)
		if button == null:
			continue
		button.pressed.emit()
		await process_frame
		if change.now != null and change.now.id != 0:
			to_select += 1
			if _builder.selection.size() == 1 and _builder.selection.has(change.now.id):
				selected += 1
	_check("a row clicked selects its part: %d of %d" % [selected, to_select],
		to_select >= 6 and selected == to_select)
	# compare_with_set says the same, in one call.
	var said: String = await _say("compare_with_set", {"set": number})
	var all_said: bool = said.contains(check.summary())
	for planned: Planned in plan:
		all_said = all_said and said.contains("line %d" % (planned.line + 1))
	_check("compare_with_set says the same in one call: %s" % said.get_slice("\n", 0).left(120), all_said)
	# Nothing written by the check, the clicks or the call.
	_check("nothing changed: the parts, the history (%d) and unsaved (%s) as before" % [depth, unsaved],
		_standing() == after and _builder.history_depth() == depth and _store.has_unsaved_work() == unsaved)
	_compare.close()
	# Read and matched again on workers, the frames changing the library
	# and the model meanwhile.
	await _stressed(number, text, plan)
	# Undone, it matches again.
	_builder.clear_selection()
	_builder.undo_steps(plan.size())
	await process_frame
	await _compare.open_set()
	check = _compare.checked
	_check("undone, it matches the set again: %s" % (check.summary() if check != null else "no check"),
		check != null and check.matches() and _standing(false) == was)
	_compare.close()


## [method SetCheck.read_set_paced] and the match, [constant STRESS_RUNS]
## times, each read and match on a worker (SetCheck.always_off_frame) while
## every frame adds parts to the library as a fetched part arriving does
## (its Dictionary written), and edits the model: bricks moved and put back,
## one added and taken away, each within the frame, so that a worker that
## read either would see them change under it. What each finds is the same.
func _stressed(number: String, text: String, plan: Array) -> void:
	var entry: Dictionary = _compare.get("_set_entry")
	var bricks: Array = _world.bricks()
	var going: Array = [true]
	var frames: Array = [0]
	var added: Array = []
	(func() -> void:
		while going[0]:
			await process_frame
			frames[0] += 1
			for _n: int in 8:
				var made := PartLibrary.PartInfo.new()
				made.id = "setcheck-stress-%d" % added.size()
				made.name = "Stress %d" % added.size()
				_library.parts[made.id] = made
				added.append(made.id)
			for k: int in 20:
				var brick: BrickWorld.Brick = bricks[(int(frames[0]) * 20 + k) % bricks.size()]
				var home: Transform3D = brick.transform
				_world.move_brick(brick.id, home.translated(Vector3(0, -400, 0)))
				_world.move_brick(brick.id, home)
			_world.remove_brick(_world.add_brick("3001", RED, Transform3D(Basis.IDENTITY,
				Vector3(9000, 0, 9000))))).call()
	SetCheck.always_off_frame = true
	var found: int = 0
	var wrong: int = 0
	for _n: int in STRESS_RUNS:
		var side: SetCheck.Reading = await SetCheck.read_set_paced(text, _library, number)
		var check: SetCheck = await SetCheck.of_model(side, entry, _world, _store, _library)
		var got: Array = _found(check, plan)
		found += int(got[0])
		wrong += int(got[1])
	SetCheck.always_off_frame = false
	going[0] = false
	await process_frame
	for id: String in added:
		_library.parts.erase(id)
	_stress[0] += STRESS_RUNS
	_stress[1] += found
	_stress[2] += wrong
	_stress[3] += int(frames[0])
	_check("read and matched %d times on workers, %d frames changing the library and the model meanwhile: %d found, %d named that were not changed" % [
		STRESS_RUNS, frames[0], found, wrong], found == 9 * STRESS_RUNS and wrong == 0)


## Of [param plan], how many [param check] found, and how many changes it
## named that were not made: [found, false].
func _found(check: SetCheck, plan: Array) -> Array:
	var claimed: Dictionary = {}
	var found: int = 0
	for planned: Planned in plan:
		for change: SetCheck.Change in check.changes:
			if not claimed.has(change) and _is(change, planned):
				claimed[change] = true
				found += 1
				break
	return [found, check.changes.size() - claimed.size()]


## The number typed in the panel's field and Enter pressed, as a person
## does it, with the field focused: one check, not two.
func _enter_once(number: String) -> void:
	var field: LineEdit = _compare.controls_by_name()["compare_set_number"]
	field.grab_focus()
	field.text = ""
	for letter: String in number:
		var typed := InputEventKey.new()
		typed.unicode = letter.unicode_at(0)
		typed.keycode = OS.find_keycode_from_string(letter)
		typed.pressed = true
		Input.parse_input_event(typed)
		await process_frame
	var before: int = _compare.compared
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame
	for _n: int in 900:
		await process_frame
		if not _compare.checking and _compare.compared > before:
			break
	for _n: int in 30:
		await process_frame
	_check("typed \"%s\" and Enter in the field: checked %d time(s), once" % [field.text, _compare.compared - before],
		field.text == number and _compare.compared - before == 1)


## Whether [param change] is the one planned.
func _is(change: SetCheck.Change, planned: Planned) -> bool:
	if change.kind != planned.kind:
		return false
	if planned.kind == SetCheck.TAKEN:
		return change.was.line == planned.line and change.was.part_id == planned.part
	if change.was == null or change.was.line != planned.line:
		return false
	match planned.kind:
		SetCheck.SWAPPED:
			return change.near_mould and change.now != null and change.now.part_id != planned.part
		SetCheck.REGROUPED:
			return change.now.id == planned.id and change.now.path == planned.into
	return change.now != null and change.now.id == planned.id


## The step, from 1, a line of [param lines] is in within its sub-model, read
## from the file itself: the STEP lines before it in its FILE's section.
func _step_in_file(lines: PackedStringArray, line: int) -> int:
	var steps: int = 0
	for n: int in range(line - 1, -1, -1):
		var words: PackedStringArray = lines[n].strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() == "FILE":
			break
		if words.size() >= 2 and words[0] == "0" and words[1].to_upper() in ["STEP", "ROTSTEP"]:
			steps += 1
	return steps + 1


func _innermost(change: SetCheck.Change) -> int:
	return int(change.chain[change.chain.size() - 1][1]) + 1


## The script: nine changes on parts in a sub-model of one copy or the
## model itself (a part in a sub-model of two copies is changed in both,
## as a person's edit is), each as the window makes it.
func _change(number: String) -> Array:
	var plan: Array = []
	var bricks: Array = []
	for brick: BrickWorld.Brick in _loose_parts():
		if _one_copy(Assemblies.path_of(brick)) and _library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
	if bricks.size() < 30:
		print("    only %d parts to change" % bricks.size())
		return plan
	var used: Dictionary = {}
	var pick := func(from: int, wanted: Callable) -> BrickWorld.Brick:
		for k: int in bricks.size():
			var brick: BrickWorld.Brick = bricks[(from + k * 7) % bricks.size()]
			if not used.has(brick.id) and bool(wanted.call(brick)):
				used[brick.id] = true
				return brick
		return null
	var any := func(_brick: BrickWorld.Brick) -> bool: return true
	# Taken away: three, spread through the model.
	for n: int in 3:
		var brick: BrickWorld.Brick = pick.call(bricks.size() * n / 3, any)
		plan.append(_planned(SetCheck.TAKEN, brick))
		_select(brick.id)
		_builder.remove_selection()
	# Recoloured: two.
	for n: int in 2:
		var brick: BrickWorld.Brick = pick.call(bricks.size() * (2 * n + 1) / 4, any)
		plan.append(_planned(SetCheck.RECOLOURED, brick))
		_select(brick.id)
		_builder.paint_selection(RED if brick.color_code != RED else BLUE)
	# Swapped for a near mould: two, each another moulding of its number.
	for n: int in 2:
		var swapped: bool = false
		for _try: int in 40:
			var brick: BrickWorld.Brick = pick.call(bricks.size() * (n + 1) / 3, func(b: BrickWorld.Brick) -> bool:
				return not _moulds_of(b.part_id).is_empty())
			if brick == null:
				break
			var planned: Planned = _planned(SetCheck.SWAPPED, brick)
			for other: String in _moulds_of(brick.part_id):
				_select(brick.id)
				if _builder.replace_selection(other, true).x != 1:
					continue
				# The part now where it stood is truly another one.
				var now: BrickWorld.Brick = _world.get_brick(int(_builder.selection.keys()[0])) \
					if _builder.selection.size() == 1 else null
				if now != null and now.part_id != brick.part_id:
					used[now.id] = true
					swapped = true
					break
				_builder.undo_steps(1)
			if swapped:
				plan.append(planned)
				break
		if not swapped:
			print("    no part of %s could be swapped for another mould" % number)
	# Moved a stud, where there is room.
	var moved: bool = false
	for _try: int in 60:
		var brick: BrickWorld.Brick = pick.call(bricks.size() / 2, any)
		if brick == null:
			break
		for by: Vector3 in [Vector3(20, 0, 0), Vector3(-20, 0, 0), Vector3(0, 0, 20), Vector3(0, 0, -20)]:
			var planned: Planned = _planned(SetCheck.MOVED, brick)
			if _builder.move_bricks({brick.id: Transform3D(brick.transform.basis, brick.transform.origin + by)}) == 1:
				plan.append(planned)
				moved = true
				break
		if moved:
			break
	# Taken out of its sub-model, into the one round it (Edit, Take out of
	# sub-assembly): one of a sub-model of three parts or more.
	var brick: BrickWorld.Brick = pick.call(bricks.size() / 5, func(b: BrickWorld.Brick) -> bool:
		var path: String = Assemblies.path_of(b)
		return not path.is_empty() and _assemblies.bricks_under(path).size() >= 3)
	if brick != null:
		var planned: Planned = _planned(SetCheck.REGROUPED, brick)
		planned.into = Assemblies.parent_of(planned.path)
		if _assemblies.take_out([brick.id]) == 1:
			plan.append(planned)
	_builder.clear_selection()
	var kinds: Dictionary = {}
	for planned: Planned in plan:
		kinds[planned.kind] = int(kinds.get(planned.kind, 0)) + 1
	print("    changed: %s" % str(kinds))
	return plan


func _planned(kind: String, brick: BrickWorld.Brick) -> Planned:
	var planned := Planned.new()
	planned.kind = kind
	planned.id = brick.id
	planned.part = brick.part_id
	planned.line = SetCheck.line_of(brick.origin)
	planned.path = Assemblies.path_of(brick)
	return planned


func _select(brick_id: int) -> void:
	_builder.selection.clear()
	_builder.selection[brick_id] = true
	_builder.selection_changed.emit(1)


## Whether no other copy of [param path], or of any sub-model round it, is
## in the model: a part changed in it is changed only there.
func _one_copy(path: String) -> bool:
	var at: String = path
	while not at.is_empty():
		if not _assemblies.copies_of(at).is_empty():
			return false
		at = Assemblies.parent_of(at)
	return true


## Another moulding of [param part] the library can draw (3794a for 3794b).
func _moulds_of(part: String) -> Array:
	var out: Array = []
	var itself: String = _library.resolve(part)
	for other: String in _families.get(Collection.family_of(part), []):
		var info: PartLibrary.PartInfo = _library.parts.get(other)
		if other != part and _library.resolve(other) != itself and info != null \
				and not info.is_redirect() and _library.mesh_for(other) != null:
			out.append(other)
	return out


# -- nothing written ----------------------------------------------------------------


## A saved model's file is the same, byte for byte, after a check of it, and
## it is still saved.
func _nothing_written() -> void:
	print("\nnothing written: a saved model checked")
	await _open("7140-1")
	var bricks: Array = _loose_parts()
	_select((bricks[10] as BrickWorld.Brick).id)
	_builder.paint_selection(RED if (bricks[10] as BrickWorld.Brick).color_code != RED else BLUE)
	_builder.clear_selection()
	var name: String = "setcheck probe 7140"
	_check("saved as \"%s\"" % name, _store.save_as(name))
	var path: String = ModelStore.SAVE_DIR + ModelStore._safe_name(name) + ".ldr"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var modified: int = FileAccess.get_modified_time(path)
	var unsaved: bool = _store.has_unsaved_work()
	await _compare.open_set("7140-1")
	var check: SetCheck = _compare.checked
	var said: String = await _say("compare_with_set", {"set": "7140-1", "show": true})
	await process_frame
	_compare.close()
	_check("checked: %s" % (check.summary() if check != null else "no check"),
		check != null and check.count(SetCheck.RECOLOURED) == 1 and said.contains("1 recoloured"))
	_check("its file the same, %d bytes, not written again, and still saved (%s)" % [bytes.size(), not unsaved],
		FileAccess.get_file_as_bytes(path) == bytes and FileAccess.get_modified_time(path) == modified
		and _store.has_unsaved_work() == unsaved and not unsaved)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# -- the time --------------------------------------------------------------------


## 10179 and the library's biggest set by parts opened and checked, the
## longest frame of the check measured; the biggest file read and matched
## against itself on the worker it is read on.
func _biggest() -> void:
	print("\nthe time")
	for number: String in ["10179-1", BIGGEST]:
		await _open(number)
		var parts: int = _world.brick_count()
		var said: Array = []
		var longest: Array = [0]
		var going: Array = [true]
		(func() -> void:
			var last: int = Time.get_ticks_usec()
			while going[0]:
				await process_frame
				var now: int = Time.get_ticks_usec()
				longest[0] = maxi(int(longest[0]), now - last)
				last = now
				var job: Working.Job = Working.current()
				if job != null and said.is_empty():
					said.append(job.line())).call()
		var began: int = Time.get_ticks_usec()
		await _compare.open_set(number)
		var took: float = (Time.get_ticks_usec() - began) / 1000.0
		going[0] = false
		await process_frame
		var check: SetCheck = _compare.checked
		_check("%s, %d parts: checked in %.0f ms (%.0f ms matching), its longest frame %.0f ms; %s; the status bar said \"%s\"" % [
			number, parts, took, check.matched_ms if check != null else -1.0, int(longest[0]) / 1000.0,
			check.summary() if check != null else "no check", said[0] if not said.is_empty() else ""],
			check != null and check.matches() and (took < 1000.0 or (not said.is_empty()
			and int(longest[0]) < 1000000)))
		_compare.close()
	# The biggest file, 36 MB: read on a worker, the frames going on.
	var got: Dictionary = await (_main.get("_model_library") as ModelLibrary).fetch_model("omr-" + BIGGEST_FILE)
	var text: String = got["text"]
	var longest: Array = [0]
	var going: Array = [true]
	(func() -> void:
		var last: int = Time.get_ticks_usec()
		while going[0]:
			await process_frame
			var now: int = Time.get_ticks_usec()
			longest[0] = maxi(int(longest[0]), now - last)
			last = now).call()
	var began: int = Time.get_ticks_usec()
	var side: SetCheck.Reading = await SetCheck.read_set_paced(text, _library, BIGGEST_FILE)
	var read_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	going[0] = false
	var check: SetCheck = SetCheck.between(side, side, SetCheck.moulds_of([side], _library), true)
	_check("%s, %.0f MB, %d parts: read in %.0f ms on a worker, its longest frame %.0f ms; matched in %.0f ms: %s" % [
		BIGGEST_FILE, text.length() / 1048576.0, side.parts.size(), read_ms, int(longest[0]) / 1000.0,
		check.matched_ms, check.summary()],
		side.parts.size() > 1000 and check.matches() and int(longest[0]) < 1000000 and check.matched_ms < 1000.0)
