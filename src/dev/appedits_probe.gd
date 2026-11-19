## Is an edit that writes only the app's own lines ("0 !BRICKWORKS …", and a
## step's turn, its ROTSTEP) work not saved, as a part put down is? New asks
## first, a session's open_model is refused, and Save keeps it; undone back
## to the saved model it is saved again, as a part's edit undone is.
##
##   godot --headless --path . --script src/dev/appedits_probe.gd
##
## smalls6 item 4 (found by hpfix): ModelStore.has_unsaved_work compared the
## saved file's part lines alone, and so a motion kept, a step's look, a step
## renamed or the floor changed on a saved model was nothing to lose: New
## started over without a word and the edit was in no file (the program, the
## views and the lights had a check each). Each edit by the window's own
## commands (the timeline's Name…, Build › Booklet page, Motions… Keep,
## View › Floor) and over MCP (edit_steps, edit_booklet, page_setup,
## define_motion, set_floor, save_view), on a model saved by Brickworks
## (five.ldr: the author's steps, a name each) and another author's
## (theirs_odd.ldr), and on hubprogram's arm (a sub-model, a floor, a
## program). Quit asks nothing for any edit, parts too: the working model is
## kept as it goes and comes back at the next start (Shell "quit").
extends SceneTree

const FIVE_FIX := "res://src/dev/fixtures/stepnames/five.ldr"
const THEIRS_FIX := "res://src/dev/fixtures/stepnames/theirs_odd.ldr"
const ARM_FIX := "res://src/dev/fixtures/hubprogram/arm_program.ldr"
## A real set whose doors are suggested to open (motions_probe's).
const DOORS_FIX := "res://vendor/omr/files/1484-1.mpd"
const FIVE := "App Edits Five"
const THEIRS := "App Edits Theirs"
const ARM := "App Edits Arm"
const DOORS := "App Edits Doors"
const OTHER := "App Edits Other"
const ORTHANC := "App Edits Orthanc"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _shell: Shell
var _verbs: EditVerbs
var _steps: StepsBar
var _tools: AppTools
## Each model's file as it was saved first.
var _files: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_store.keeps = true
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	for named: Array in [[FIVE, FIVE_FIX], [THEIRS, THEIRS_FIX], [ARM, ARM_FIX], [DOORS, DOORS_FIX],
			[OTHER, FIVE_FIX]]:
		_forget(named[0])
		_store.open(named[1])
		_bar.opened.emit(_parts())
		await _settle()
		_check("%s saved" % named[0], _store.save_as(named[0]))
		_files[named[0]] = FileAccess.get_file_as_string(ModelStore.saved_path(named[0]))

	print("\nopened, nothing done")
	for name: String in [FIVE, THEIRS, ARM, DOORS]:
		await _open(name)
		_check("%s opened: nothing to lose (%s)" % [name, _store.has_unsaved_work()],
			not _store.has_unsaved_work())

	print("\nfor comparison, a part taken off")
	await _case(FIVE, "a part taken off (Delete)", func() -> Array:
		_builder.select_brick(_first_part().id, false)
		await _verbs.press("delete")
		return ["deleted", false])

	print("\nthe app's own lines alone")
	await _case(FIVE, "step 3 named by hand (the timeline's Name…)", _name_by_hand.bind(3, "By hand"))
	await _case(FIVE, "step 3 named over MCP (edit_steps)", func() -> String:
		return str(await _tools.run("edit_steps", {"op": "name", "step": 3, "name": "Over MCP"})))
	await _case(THEIRS, "another author's step 2 named over MCP (edit_steps)", func() -> String:
		return str(await _tools.run("edit_steps", {"op": "name", "step": 2, "name": "Renamed"})))
	await _case(FIVE, "step 4's picture zoomed in by hand (Booklet page › Zoom in)", func() -> String:
		await _timeline_at(4)
		return "pressed %s" % _shell.run("booklet_zoom_in"))
	await _case(FIVE, "step 2's picture turned by hand (Booklet page › Turn the view left)", func() -> String:
		await _timeline_at(2)
		return "pressed %s" % _shell.run("booklet_turn_left"))
	await _case(FIVE, "step 2's parts pulled out over MCP (edit_booklet)", func() -> String:
		return str(await _tools.run("edit_booklet", {"step": 2, "pull": 2})))
	await _case(FIVE, "the booklet's page set up over MCP (page_setup)", func() -> String:
		return str(await _tools.run("page_setup", {"size": "A5"})))
	await _case(ARM, "the floor changed by hand (View › Floor, the grid)", func() -> String:
		var grid: ModelFloor = _store.model_floor.copy()
		grid.kind = ModelFloor.GRID
		_main.call("choose_floor", grid)
		return "chose %s" % grid.words())
	await _case(ARM, "the floor changed over MCP (set_floor 48 x 48)", func() -> String:
		return str(await _tools.run("set_floor", {"across": 48})))
	await _case(DOORS, "a motion kept by hand (Motions…, a suggestion's Keep)", _keep_by_hand)
	await _case(DOORS, "a motion defined over MCP (define_motion)", func() -> String:
		return str(await _tools.run("define_motion", {"name": "Open the doors", "suggested": true})))
	await _case(FIVE, "a view saved over MCP (save_view; checked since savedviews)", func() -> String:
		return str(await _tools.run("save_view", {"name": "From the probe"})))

	print("\nan edit and another taking it back, not an undo")
	await _back_by_hand()

	print("\nOrthanc: how long the question takes")
	await _orthanc()

	for name: String in [FIVE, THEIRS, ARM, DOORS, OTHER]:
		_forget(name)
	print("")
	if _failures == 0:
		print("an edit of the app's own lines alone is work not saved: New asks, open_model refuses, "
			+ "Save keeps it, and undone it is saved again, as a part's edit")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## [param name] opened from its file as it was saved; [param edit] done to
## it (returning what it said, or [what, false] for an edit of a part's
## line); then New, open_model, Undo, Redo and Save asked.
func _case(name: String, what: String, edit: Callable) -> void:
	await _open(name)
	var file: String = _files[name]
	var depth: int = _builder.history_depth()
	var said: Variant = await edit.call()
	await _settle()
	var lines_only: bool = not (said is Array)
	var words: String = str(said[0] if said is Array else said).replace("\n", " ").left(110)
	var written: String = _store.saved_text()
	var changed: PackedStringArray = _changed_lines(file, written)
	print("  %s: %s (%d undo step%s); Save would change %s" % [what, words,
		_builder.history_depth() - depth, "" if _builder.history_depth() - depth == 1 else "s",
		" | ".join(changed).left(220) if not changed.is_empty() else "nothing"])
	if changed.is_empty():
		_check("%s: the edit was made (Save would write it)" % what, false)
		return
	if lines_only:
		_check("%s: only the app's own lines change" % what, _app_only(changed))
	var unsaved: bool = _store.has_unsaved_work()
	_check("%s: work not saved (%s)" % [what, unsaved], unsaved)
	if unsaved:
		_bar.ask_for_new()
		await _frames(3)
		var asked: ConfirmationDialog = _bar.get("_confirm_new")
		_check("%s: New asks first (\"%s\")" % [what, asked.dialog_text.left(70) if asked.visible else "nothing asked"],
			asked.visible)
		asked.hide()
		await _frames(2)
		var refused: String = str(await _tools.run("open_model", {"name": OTHER}))
		_check("%s: a session's open_model refused (%s)" % [what, refused.left(80)],
			_store.title == name and refused.contains("not saved"))
		await _settle()
	else:
		_note("New would start over without asking, and the edit is in no file")
	if _builder.history_depth() == depth:
		# A view saved is kept in no step of the history (save_view: its own
		# way back is to take the view out).
		_note("%s: no undo step, so no undo or redo to ask about" % what)
	else:
		await _undo_redo(what, file)
	var kept: bool = _store.save_as(name)
	var now: String = FileAccess.get_file_as_string(ModelStore.saved_path(name))
	_check("%s: saved (%s), it is in the file and nothing is left to lose (%s)" % [what, kept,
		_store.has_unsaved_work()], kept and now == written and not _store.has_unsaved_work())
	_write(ModelStore.saved_path(name), file)


func _undo_redo(what: String, file: String) -> void:
	await _verbs.press("undo")
	await _settle()
	_check("%s: undone, the saved model again, nothing to lose (%s; Save the file as saved: %s)" % [what,
		_store.has_unsaved_work(), _store.saved_text() == file], not _store.has_unsaved_work())
	await _verbs.press("redo")
	await _settle()
	_check("%s: redone, work not saved again (%s)" % [what, _store.has_unsaved_work()],
		_store.has_unsaved_work())


## A step renamed and named back by a second edit, not an undo: the model is
## its file again, nothing to lose, as a part put down and taken off again.
func _back_by_hand() -> void:
	await _open(FIVE)
	var had: String = ""
	for step: Instructions.Step in Instructions.plan(_world, _store.library, _store.scenery, {}, true):
		if step.number == 3 and not step.in_callout():
			had = step.name
	await _tools.run("edit_steps", {"op": "name", "step": 3, "name": "For a moment"})
	await _settle()
	var between: bool = _store.has_unsaved_work()
	await _tools.run("edit_steps", {"op": "name", "step": 3, "name": had})
	await _settle()
	_check("step 3 renamed (unsaved %s) and named \"%s\" again: nothing to lose (%s), Save the file (%s)" % [
		between, had, _store.has_unsaved_work(), _store.saved_text() == _files[FIVE]],
		between and not _store.has_unsaved_work())


## Orthanc saved, its floor changed and changed back by undo, then asked
## three times: the whole model written out and compared, as New and an open
## over it ask it (it was a third of a second before smalls6, and is a
## question asked once, not a frame's work).
func _orthanc() -> void:
	_forget(ORTHANC)
	_store.open("res://models/orthanc.ldr")
	_bar.opened.emit(_parts())
	await _settle()
	_store.save_as(ORTHANC)
	_files[ORTHANC] = FileAccess.get_file_as_string(ModelStore.saved_path(ORTHANC))
	await _open(ORTHANC)
	await _tools.run("set_floor", {"kind": "grid"})
	await _settle()
	var edited: bool = _store.has_unsaved_work()
	await _verbs.press("undo")
	await _settle()
	var times := PackedStringArray()
	var most: int = 0
	var unsaved: bool = true
	# Against what the question cost before smalls6, the model written out
	# once (to_text), timed beside it at the same load: a bound of 1.5 s
	# alone failed at load 80 (2.7 s), where the writing alone takes as long.
	var before_most: int = 0
	for _n: int in 3:
		var began: int = Time.get_ticks_usec()
		_store.to_text(ModelStore.UNTITLED)
		before_most = maxi(before_most, (Time.get_ticks_usec() - began) / 1000)
		began = Time.get_ticks_usec()
		unsaved = _store.has_unsaved_work()
		var took: int = (Time.get_ticks_usec() - began) / 1000
		most = maxi(most, took)
		times.append("%d" % took)
		await _frames(2)
	_check("Orthanc (%d parts): its floor changed is unsaved (%s), undone it is not (%s), asked in %s ms (the model written out alone, as it was asked before: %d ms at most; within 1.5 times it)" % [
		_parts(), edited, unsaved, ", ".join(times), before_most],
		edited and not unsaved and most <= before_most * 3 / 2 + 100)
	_forget(ORTHANC)


## The timeline up in the author's steps, at the end of step [param number].
func _timeline_at(number: int) -> void:
	if not _steps.visible:
		await _steps.start(_world, _store.library, _store.scenery)
	_steps.set_mode(StepsBar.AUTHORS)
	await _frames(4)
	_steps.refresh(number)
	await _frames(2)


func _name_by_hand(number: int, name: String) -> String:
	await _timeline_at(number)
	var at: Instructions.Step = _steps.booklet_step()
	if at == null or at.number != number:
		return "no step %d on the timeline" % number
	if _steps.get("_naming") == null:
		_steps.call("_make_naming")
	_steps.set("_naming_step", at)
	var field: LineEdit = _steps.get("_naming_field")
	field.text = name
	field.text_submitted.emit(name)
	await _settle()
	return "named step %d \"%s\"" % [number, name]


## Build › Motions…, and the first motion it suggests kept by its Keep.
func _keep_by_hand() -> String:
	var pose: Node = _main.get("_pose")
	pose.call("open")
	await _frames(10)
	var keeps: Array = pose.get("_keep_buttons")
	if keeps.is_empty():
		return "nothing suggested to keep"
	(keeps[0] as Button).pressed.emit()
	await _frames(4)
	var said: String = "kept the first suggestion"
	pose.call("close")
	await _frames(4)
	return said


## The lines of [param after] that [param before] has not, and the other way.
static func _changed_lines(before: String, after: String) -> PackedStringArray:
	var had: Dictionary = {}
	for line: String in before.split("\n"):
		had[line.strip_edges()] = int(had.get(line.strip_edges(), 0)) + 1
	var out := PackedStringArray()
	for line: String in after.split("\n"):
		var bare: String = line.strip_edges()
		if int(had.get(bare, 0)) > 0:
			had[bare] = int(had[bare]) - 1
		else:
			out.append("+" + bare)
	for bare: String in had:
		for _n: int in int(had[bare]):
			out.append("-" + str(bare))
	return out


static func _app_only(changed: PackedStringArray) -> bool:
	for line: String in changed:
		var fields: PackedStringArray = line.substr(1).split(" ", false)
		if fields.size() < 2 or fields[0] != "0":
			return false
		var word: String = fields[1].to_upper()
		if word != "!BRICKWORKS" and word != "ROTSTEP" and word != "STEP":
			return false
	return true


func _open(name: String) -> void:
	_write(ModelStore.saved_path(name), _files[name])
	await _bar.open_with_progress(ModelStore.saved_path(name))
	_bar.opened.emit(_parts())
	await _settle()


func _first_part() -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			return brick
	return null


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _settle() -> void:
	for _n: int in 40:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	await _frames(6)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _forget(name: String) -> void:
	if FileAccess.file_exists(ModelStore.saved_path(name)):
		DirAccess.remove_absolute(ModelStore.saved_path(name))


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _note(what: String) -> void:
	print("  note  %s" % what)
