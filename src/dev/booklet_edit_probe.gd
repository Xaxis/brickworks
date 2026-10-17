## The booklet edited by hand, as a designer edits one in Studio's
## Instruction Maker: steps merged, split, reordered and a part moved; a
## step's picture turned and zoomed; page breaks, a step alone, its size,
## its parts list and a callout. Each through the window's own commands
## (Shell.change_steps, Shell.change_look: the timeline's buttons, the
## Booklet page menu and edit_booklet over MCP all come here).
##
##   ~/.claude/claude-core/bin/gpu env XDG_DATA_HOME=$PWD/.scratch-data MESA_VK_WSI_DEBUG=sw \
##     xvfb-run -a --server-args="-screen 0 1400x900x24" godot --path . --resolution 1280x800 \
##     --script src/dev/booklet_edit_probe.gd -- [--into=DIR] [--no-booklet] [--only=SET]
##
## Windowed, on the GPU, under Xvfb: on a display with no monitor the
## booklet's pictures were never drawn (each given up after 20 s).
## --no-booklet judges the file and the edits alone, headless.
##
## On two real sets with their designers' steps, 30050-1 (sub-models, and
## seven ROTSTEPs, ABS) and 106-1 (a car, a figure and its wheels as
## sub-models), and one without any, 10016-1. For each edit: one undo step;
## the file saved after it differs from the file as opened only where the
## edit says (a merge is one STEP line fewer, a split one more, a reorder
## and a move only lines moved, a turn the step's last line a ROTSTEP, the
## rest one line of the app's each), every other line byte for byte; and
## the undo gives back the file exactly. A file opened and saved with
## nothing changed is the file. Then every look at once, saved, opened
## again (the looks and the timeline the same) and saved again (the same
## text); and the booklet made from them: the new page's step heads its
## page, the step alone is alone, no page has more than the steps a page
## asked, the parts list left off is off, the callout turned off has pages
## of its own, the turned step is drawn from its turn, the zoomed one
## larger. Its pages laid out without pictures (booklet_layout) are the
## made booklet's. A model with no steps given a look takes the worked-out
## steps in the same undo, and one undo takes both back.
##
## --into=DIR writes each set's booklet before and after (SET_before.html,
## SET_after.html) and a JSON of its pages; print them with
## tools/web/booklet_print.mjs, which checks the PDF has the booklet's
## pages. Never writes to Downloads (Download.folder is DIR).
extends SceneTree

const SETS: Array = [
	["res://vendor/omr/files/30050-1.mpd", "30050-1"],
	["res://vendor/omr/files/106-1.mpd", "106-1"],
	["res://vendor/omr/files/10016-1.mpd", "10016-1"],
]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _steps: StepsBar
var _library: PartLibrary
var _out: String = ""
var _booklets: bool = true
var _name: String = ""
## --only=SET: that set alone.
var _only: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## A click where a person clicks, in the window's own pixels.
func _click(at: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var moved := InputEventMouseMotion.new()
	moved.position = at * scale
	moved.global_position = moved.position
	Input.parse_input_event(moved)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at * scale
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(3)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.substr(7)
		if arg == "--no-booklet":
			_booklets = false
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("sessions/probe/booklet_edit")
	DirAccess.make_dir_recursive_absolute(_out)
	Download.folder = _out
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	_library = _main.get("_library")
	# With the assistant switched off, as a person may have it: every one of
	# these is the window's own.
	_shell.set_assistant(false)
	var menu: Array = Shell.SUBMENUS.get("booklet", [])
	var missing: Array = menu.filter(func(id: String) -> bool:
		return id != "-" and not _shell._commands.has(id))
	_check("the assistant off, Build, Booklet page has its %d commands"
		% menu.filter(func(id: String) -> bool: return id != "-").size(),
		not menu.is_empty() and missing.is_empty() and not _shell.assistant_shown)
	if not FileAccess.file_exists(str(SETS[0][0])):
		print("booklet edit: vendor/omr is not in this checkout; nothing judged")
		quit(0)
		return
	for set: Array in SETS:
		if _only.is_empty() or str(set[1]) == _only:
			await _one_set(str(set[0]), str(set[1]))
	print("")
	print("booklet edit: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- one set -----------------------------------------------------------------------


func _one_set(path: String, name: String) -> void:
	_name = name
	print("")
	print("%s" % name)
	var original: String = FileAccess.get_file_as_string(path)
	await _open(path)
	var stepped: bool = AuthorSteps.any(_world, _store.scenery)
	var base: String = _save()
	var diff: Array = _diff(original, base)
	_check("opened and saved with nothing changed, the file is the file (%d lines out, %d in: %s)"
		% [(diff[0] as Array).size(), (diff[1] as Array).size(), _few(diff[1])],
		(diff[0] as Array).is_empty() and _only_app_lines(diff[1]))
	await _timeline()
	var before: Dictionary = {}
	if _booklets:
		before = await _booklet("before")
	if stepped:
		await _merge(base)
		await _split(base)
		await _reorder(base)
		await _move(base)
		await _looks_one_by_one(base, name)
		await _over_mcp(base)
	else:
		await _first_look_adopts(base)
	await _all_looks(name, before)


func _open(path: String) -> void:
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)
	_check("opened %s: %d parts, %s" % [path.get_file(), _world.brick_count(),
		"the author's steps" if AuthorSteps.any(_world, _store.scenery) else "no steps of its own"],
		_world.brick_count() > 20 and _store.awaited.is_empty())


func _timeline() -> void:
	if not _steps.visible:
		await _steps.start(_world, _library, _store.scenery)
	await _frames(4)


func _save() -> String:
	return _store.to_text(_name, true)


## The step of the model numbered [param number] showing on the timeline.
func _go(number: int) -> Instructions.Step:
	_steps.refresh(number)
	return _steps.current_step()


## The model's own steps (not inside a callout) with at least [param parts]
## parts of their own, and the step [param plus] after each in the same
## section.
func _own_steps(parts: int = 1) -> Array[Instructions.Step]:
	var out: Array[Instructions.Step] = []
	for step: Instructions.Step in _steps.steps():
		if step.callout_step == 0 and step.authored_step >= 0 and step.brick_ids.size() >= parts \
				and not step.attaches():
			out.append(step)
	return out


func _history() -> int:
	return _builder._history.size()


## After an edit said by [param words]: one undo step more than [param
## history], and the file's lines taken out and put in against [param base].
func _edited(words: String, base: String, history: int) -> Array:
	_check("%s: one undo step (%d)" % [words, _history() - history], _history() == history + 1)
	return _diff(base, _save())


## [param diff] as the edit should have left the file, said; then one undo
## gives the file back exactly.
func _judge(diff: Array, right: bool, base: String) -> void:
	_check("...the file changed only so: out %s, in %s" % [_few(diff[0]), _few(diff[1])], right)
	_builder.undo()
	await _frames(2)
	_steps.refresh()
	var back: String = _save()
	var after: Array = _diff(base, back)
	_check("...and one undo gives the file back, byte for byte (%d out, %d in)"
		% [(after[0] as Array).size(), (after[1] as Array).size()], back == base)


func _merge(base: String) -> void:
	var own: Array[Instructions.Step] = _own_steps()
	var pick: Instructions.Step = null
	for at: int in own.size() - 1:
		if own[at + 1].authored_in == own[at].authored_in \
				and _seen_as(own[at]) == _seen_as(own[at + 1]):
			pick = own[at]
			break
	if pick == null:
		_check("a step to merge with the next", false)
		return
	await _step_edit("merge", pick, [], base, -1)


func _split(base: String) -> void:
	var pick: Instructions.Step = null
	for step: Instructions.Step in _own_steps(3):
		pick = step
		break
	if pick == null:
		_check("a step of three parts to split", false)
		return
	await _step_edit("new", pick, Array(pick.brick_ids).slice(pick.brick_ids.size() / 2),
		base, 1)


func _reorder(base: String) -> void:
	var own: Array[Instructions.Step] = _own_steps()
	var can: Instructions.Step = null
	var cannot: Instructions.Step = null
	for at: int in range(1, own.size()):
		var step: Instructions.Step = own[at]
		if own[at - 1].authored_in != step.authored_in:
			continue
		var blocked: String = AuthorSteps.blocked_swap(_world, step.authored_in,
			step.authored_step, -1, _store.scenery)
		if blocked.is_empty() and can == null and _seen_as(own[at - 1]) == _seen_as(step):
			can = step
		elif not blocked.is_empty() and cannot == null:
			cannot = step
	if cannot != null:
		var history: int = _history()
		var said: String = _shell.change_steps("earlier", [], _go(cannot.number))
		_check("step %d stands on the one before: Earlier refuses (\"%s\"), no undo step"
			% [cannot.number, said], said.contains("cannot go") and _history() == history
			and _save() == base)
	else:
		_check("a step standing on the one before, to refuse", false)
	if can == null:
		_check("a step free to go earlier", false)
		return
	await _step_edit("earlier", can, [], base, 0)


func _move(base: String) -> void:
	var pick: Instructions.Step = null
	for step: Instructions.Step in _own_steps(2):
		pick = step
		break
	if pick == null:
		_check("a step of two parts to move one from", false)
		return
	await _step_edit("next", pick, [pick.brick_ids[0]], base, 99)


## A step edit by the timeline's own command on [param at]: one undo step;
## the file's parts' lines only moved, never rewritten; the steps one fewer
## ([param more] -1), one more (1) or as many (0; 99 either); every part
## seen from the same side as before; and one undo gives the file back.
## Where the sub-model has no step of only a ROTSTEP, a merge is exactly
## its STEP line out and a split one STEP line in.
func _step_edit(op: String, at: Instructions.Step, ids: Array, base: String, more: int) -> void:
	var history: int = _history()
	var views: Dictionary = _views()
	var count: int = _steps_of(at.authored_in)
	var empty: bool = _has_empty_steps(at.authored_in)
	var said: String = _shell.change_steps(op, ids, _go(at.number))
	var diff: Array = _edited("%s on step %d (\"%s\")" % [op, at.number, said], base, history)
	var out: Array = diff[0]
	var put: Array = diff[1]
	var now: int = _steps_of(at.authored_in)
	_check("...%d steps in its sub-model, now %d" % [count, now],
		now - count == more or more == 99 and absi(now - count) <= 1)
	_check("...every part seen from the side it was", _views() == views)
	var exact: bool = true
	if not empty and op == "merge":
		exact = out.size() == 1 and _is_step_line(str(out[0])) and put.is_empty()
	elif not empty and op == "new":
		exact = out.size() == put.size() - 1 and put.has("0 STEP")
	await _judge(diff, _parts_moved_only(out, put) and exact, base)


## The turn the steps are seen from, by part: what an edit of the steps
## must not change.
func _views() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.step < 0:
			continue
		out[brick.id] = JSON.stringify(BookletLooks.turn_at(_world, Assemblies.path_of(brick),
			brick.step))
	return out


func _seen_as(step: Instructions.Step) -> String:
	return JSON.stringify(BookletLooks.turn_at(_world, step.authored_in, step.authored_step))


func _steps_of(section: String) -> int:
	return AuthorSteps.steps_in(_world, section, _store.scenery).size()


## Whether the file's sub-model has a step with no part in it (a ROTSTEP
## alone, which an edit of its steps takes out).
func _has_empty_steps(section: String) -> bool:
	var steps: Array = AuthorSteps.steps_in(_world, section, _store.scenery)
	return not steps.is_empty() and int(steps[-1]) + 1 != steps.size()


## Each look alone, by the Booklet row's own commands: the file gains the
## line that says it, one undo, and the undo gives the file back.
func _looks_one_by_one(base: String, name: String) -> void:
	var own: Array[Instructions.Step] = _own_steps(2)
	var pick: Instructions.Step = own[mini(2, own.size() - 1)]
	var section: String = pick.authored_in
	var step: int = pick.authored_step
	var turned: Dictionary = BookletLooks.turn_at(_world, section, step)
	for look: Array in [
			["turn_right", "the step's last line a ROTSTEP"],
			["zoom_in", "0 !BRICKWORKS ZOOM 1.25"],
			["bigger", "0 !BRICKWORKS SIZE 1.25"],
			["new_page", "0 !BRICKWORKS PAGE NEW"],
			["alone", "0 !BRICKWORKS PAGE ALONE"],
			["parts", "0 !BRICKWORKS PARTS OFF"],
			["per_page", "0 !BRICKWORKS PER_PAGE 1"]]:
		var op: String = look[0]
		var history: int = _history()
		var said: String = _shell.change_look(op, _go(pick.number))
		if op == "turn_right":
			var now: Dictionary = BookletLooks.turn_at(_world, section, step)
			var by: float = BookletLooks._vector(now.get("turn", [0, 0, 0])).y
			var was: float = BookletLooks._vector(turned.get("turn", [0, 0, 0])).y
			_check("Turn right: step %d's view 45 degrees on (%s to %s, %s)" % [pick.number,
				was, by, str(now.get("how", ""))], is_equal_approx(fposmod(by - was, 360.0), 45.0))
			var diff: Array = _edited("Turn right on step %d (\"%s\")" % [pick.number, said], base, history)
			var out: Array = diff[0]
			var put: Array = diff[1]
			await _judge(diff, out.size() == 1 and _is_step_line(str(out[0])) and put.size() == 1 and str(put[0]).strip_edges().begins_with("0 ROTSTEP "), base)
			continue
		var line: String = look[1]
		var diff: Array = _edited("%s on step %d (\"%s\")" % [op.capitalize(), pick.number, said], base, history)
		var out: Array = diff[0]
		var put: Array = diff[1]
		await _judge(diff, out.is_empty() and put.size() == 1 and str(put[0]).strip_edges() == line, base)
	# A sub-assembly's callout: on the step that puts one on.
	var attach: Instructions.Step = null
	for one: Instructions.Step in _steps.steps():
		if one.attaches() and one.callout_step == 0 \
				and not BookletLooks.attached(_world, one, one.authored_in).is_empty():
			attach = one
			break
	if attach == null:
		print("  (no step puts a callout on in %s)" % name)
		return
	var history: int = _history()
	var said: String = _shell.change_look("callout", _go(attach.number))
	var diff: Array = _edited("Callout off on step %d (\"%s\")" % [attach.number, said], base, history)
	var out: Array = diff[0]
	var put: Array = diff[1]
	await _judge(diff, out.is_empty() and put.size() == 1 and str(put[0]).strip_edges() == "0 !BRICKWORKS CALLOUT OFF", base)


## The same over MCP, as a session does it: booklet_layout changes nothing
## and says what the pages are; edit_booklet is one undo and says it in the
## file, and the layout read again says it too.
func _over_mcp(base: String) -> void:
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var history: int = _history()
	var layout: String = str(await tools.run("booklet_layout", {}))
	_check("booklet_layout: %s" % layout.get_slice("\n", 0).left(110),
		layout.contains("  page 2:") and _history() == history and _save() == base)
	var own: Array[Instructions.Step] = _own_steps(2)
	var pick: Instructions.Step = own[mini(3, own.size() - 1)]
	var said: String = str(await tools.run("edit_booklet", {"step": pick.number, "zoom": 1.5,
		"page": "new", "parts": false}))
	var diff: Array = _edited("edit_booklet step %d zoom 1.5, a new page, no parts list (\"%s\")"
		% [pick.number, said.left(90)], base, history)
	var put: Array = (diff[1] as Array).map(func(line: Variant) -> String: return str(line).strip_edges())
	var again: String = str(await tools.run("booklet_layout", {}))
	_check("...booklet_layout says it: %s" % _line_with(again, "%d (" % pick.number),
		_line_with(again, "%d (" % pick.number).contains("zoom 1.5x, new page, no parts list"))
	await _judge(diff, (diff[0] as Array).is_empty() and put.size() == 3
		and put.has("0 !BRICKWORKS ZOOM 1.5") and put.has("0 !BRICKWORKS PAGE NEW")
		and put.has("0 !BRICKWORKS PARTS OFF"), base)
	history = _history()
	said = str(await tools.run("edit_booklet", {"step": pick.number, "turn": 90, "tilt": 15}))
	diff = _edited("edit_booklet step %d turn 90, tilt 15 (\"%s\")" % [pick.number, said.left(90)],
		base, history)
	await _judge(diff, (diff[1] as Array).size() == 1
		and str(diff[1][0]).strip_edges().begins_with("0 ROTSTEP 15 90 0 REL"), base)
	history = _history()
	said = str(await tools.run("edit_booklet", {"step": 999}))
	_check("edit_booklet on a step there is not refuses, no undo step (\"%s\")" % said.left(70),
		said.begins_with("There is no step") and _history() == history)


static func _line_with(text: String, part: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(part):
			return line.strip_edges().left(150)
	return ""


## A model with no steps of its own given a look: the worked-out steps
## taken in the same undo, and that undo takes both back.
func _first_look_adopts(base: String) -> void:
	var history: int = _history()
	var at: Instructions.Step = _go(3)
	var said: String = _shell.change_look("zoom_in", at)
	var saved: String = _save()
	_check("a model with no steps of its own, Zoom in on step 3 (\"%s\"): one undo step, the "
		% said + "worked-out steps its own", _history() == history + 1
		and AuthorSteps.any(_world, _store.scenery))
	_check("...saved with its steps, said to be the author's, and the zoom",
		saved.contains("\n0 STEP") and saved.contains(LdrModel.AUTHORED_META)
		and saved.contains("0 !BRICKWORKS ZOOM 1.25"))
	_builder.undo()
	await _frames(2)
	_steps.set_mode(0)
	_steps.refresh()
	_check("...and one undo: no steps of its own again, no looks, the file as it was",
		not AuthorSteps.any(_world, _store.scenery) and _world.step_looks.is_empty()
		and _save() == base)


# -- every look at once, the file and the booklet --------------------------------


func _all_looks(name: String, before: Dictionary) -> void:
	var adopted: bool = not AuthorSteps.any(_world, _store.scenery)
	var own: Array[Instructions.Step] = _own_steps(1)
	if own.size() < 6:
		own = []
		for step: Instructions.Step in _steps.steps():
			if step.callout_step == 0 and not step.attaches():
				own.append(step)
	if own.size() < 7:
		_check("seven steps of the model's own to set (%d)" % own.size(), false)
		return
	var history: int = _history()
	var picks: Dictionary = {
		"turn": own[1].number, "zoom": own[2].number, "new": own[3].number,
		"alone": own[4].number, "parts": own[5].number, "size": own[6].number}
	_shell.change_look("turn_right", _go(int(picks["turn"])))
	_shell.change_look("turn_right", _go(int(picks["turn"])))
	_shell.change_look("tilt_up", _go(int(picks["turn"])))
	# Zoom by the row's own button, clicked, twice; and Ctrl-Z, Ctrl-Shift-Z.
	_go(int(picks["zoom"]))
	await _frames(6)
	var zoom: Button = _steps.controls_by_name().get("booklet_zoom_in")
	if zoom != null and zoom.is_visible_in_tree():
		await _click(zoom.get_global_rect().get_center())
		await _click(zoom.get_global_rect().get_center())
		var said: String = str(_steps.page_state().get("look", ""))
		_check("Zoom in on the Booklet row, clicked twice: \"%s\"" % said,
			said.contains("zoom 1.5x"))
		await _key(KEY_Z, true)
		var undone: String = str(_steps.page_state().get("look", ""))
		await _key(KEY_Z, true, true)
		var redone: String = str(_steps.page_state().get("look", ""))
		_check("...Ctrl-Z one zoom back (\"%s\"), Ctrl-Shift-Z again (\"%s\")" % [undone, redone],
			undone.contains("zoom 1.25x") and redone.contains("zoom 1.5x"))
		var picture: Image = root.get_texture().get_image()
		if picture != null:
			picture.save_png(_out.path_join("%s_window.png" % name))
	else:
		_check("the Booklet row's Zoom in is on screen", false)
		_shell.change_look("zoom_in", _go(int(picks["zoom"])))
		_shell.change_look("zoom_in", _go(int(picks["zoom"])))
	_shell.change_look("new_page", _go(int(picks["new"])))
	_shell.change_look("alone", _go(int(picks["alone"])))
	_shell.change_look("parts", _go(int(picks["parts"])))
	_shell.change_look("bigger", _go(int(picks["size"])))
	_shell.change_look("per_page", _go(1))
	_shell.change_look("per_page", _go(1))
	var off: String = ""
	for one: Instructions.Step in _steps.steps():
		if one.attaches() and one.callout_step == 0 \
				and not BookletLooks.attached(_world, one, one.authored_in).is_empty():
			_shell.change_look("callout", _go(one.number))
			off = BookletLooks.definition_of(BookletLooks.attached(_world, one, one.authored_in))
			break
	_check("every look set, each its own undo step (%d)" % (_history() - history),
		_history() - history == 11 + (0 if off.is_empty() else 1))
	var looks: Dictionary = _world.step_looks.duplicate(true)
	var saved: String = _save()
	var timeline: Array = _captions()
	# Opened again from what was saved: the same looks and steps.
	var file: String = _out.path_join("%s_edited.ldr" % name)
	var writing: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	writing.store_string(saved)
	writing.close()
	await _open(file)
	await _timeline()
	_check("saved and opened again: every look as it was set (%d)" % looks.size(),
		_without_lines(_world.step_looks) == _without_lines(looks))
	var now: Array = _captions()
	var differ: String = ""
	for at: int in mini(now.size(), timeline.size()):
		if now[at] != timeline[at]:
			differ = ": first apart at %s, was %s" % [now[at], timeline[at]]
			break
	# A model given the worked-out steps has each copy of a sub-model built
	# in its own order, and a file writes a sub-model once: reopened, every
	# copy is built as the first (10016-1's second wheels). Said, and only
	# the count judged there.
	if adopted:
		_check("...as many steps (%d, now %d%s)" % [timeline.size(), now.size(), differ],
			now.size() == timeline.size())
	else:
		_check("...the timeline's steps the same (%d, now %d%s)" % [timeline.size(), now.size(),
			differ], now == timeline)
	var again: String = _save()
	var drift: Array = _diff(saved, again)
	_check("...and saved again, the same file (%d out, %d in)" % [(drift[0] as Array).size(),
		(drift[1] as Array).size()], again == saved)
	if not _booklets:
		return
	var made: Dictionary = await _booklet("after")
	var pages: Array = made["pages"]
	var document: Booklet.Document = made["document"]
	var entries: Dictionary = {}
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			if page.kind == "steps":
				entries[entry.number] = [entry, page]
	var new_at: Array = entries.get(int(picks["new"]), [])
	_check("the booklet: step %d heads a new page" % int(picks["new"]),
		not new_at.is_empty() and (new_at[1] as Booklet.Page).entries[0] == new_at[0])
	var alone_at: Array = entries.get(int(picks["alone"]), [])
	var next_at: Array = entries.get(int(picks["alone"]) + 1, [])
	_check("...step %d alone on its page" % int(picks["alone"]),
		not alone_at.is_empty() and (alone_at[1] as Booklet.Page).entries.size() == 1
		and (next_at.is_empty() or next_at[1] != alone_at[1]))
	var most: int = 0
	for page: Booklet.Page in pages:
		if page.kind == "steps":
			most = maxi(most, page.entries.size())
	_check("...no page of more than 2 steps (the most is %d)" % most, most <= 2)
	var parts_at: Array = entries.get(int(picks["parts"]), [])
	_check("...step %d with no parts box" % int(picks["parts"]),
		not parts_at.is_empty() and (parts_at[0] as Booklet.Entry).lots.is_empty()
		and not document.lots.is_empty())
	var turn_at: Array = entries.get(int(picks["turn"]), [])
	var want: Vector3 = Vector3.ZERO
	var turn_step: Instructions.Step = _go(int(picks["turn"]))
	var turned: Dictionary = BookletLooks.turn_at(_world, turn_step.authored_in,
		turn_step.authored_step)
	if not turned.is_empty():
		want = BookletLooks.direction(turned)
	_check("...step %d drawn from its turn (%s, want %s)" % [int(picks["turn"]),
		(turn_at[0] as Booklet.Entry).from if not turn_at.is_empty() else "none", want],
		not turn_at.is_empty() and (turn_at[0] as Booklet.Entry).fixed
		and ((turn_at[0] as Booklet.Entry).from - want).length() < 0.001)
	var zoom_at: Array = entries.get(int(picks["zoom"]), [])
	var zoom_before: Array = (before.get("entries", {}) as Dictionary).get(int(picks["zoom"]), [])
	_check("...step %d drawn larger, zoomed (%.3f to %.3f mm an LDU)" % [int(picks["zoom"]),
		(zoom_before[0] as Booklet.Entry).scale if not zoom_before.is_empty() else 0.0,
		(zoom_at[0] as Booklet.Entry).scale if not zoom_at.is_empty() else 0.0],
		not zoom_at.is_empty() and not zoom_before.is_empty()
		and (zoom_at[0] as Booklet.Entry).scale > (zoom_before[0] as Booklet.Entry).scale * 1.2)
	if not off.is_empty():
		var framed: bool = false
		for page: Booklet.Page in pages:
			if page.kind == "callout" and page.name == off:
				framed = true
		_check("...the %s built on pages of its own" % off, framed)
	# Laid out without pictures, as booklet_layout reads it: the same pages.
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var dry: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, name)
	maker.queue_free()
	_check("...laid out without pictures, the same pages (%s / %s)" % [_pages_of(dry).left(80),
		_pages_of(pages).left(80)], _pages_of(dry) == _pages_of(pages))


## The booklet made as Instructions makes it, written to the out folder
## with its pages as JSON. {pages, document, entries: number -> [entry, page]}.
func _booklet(when: String) -> Dictionary:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var html: String = await maker.make(_world, _store.scenery, _name)
	var document: Booklet.Document = maker.document
	maker.queue_free()
	var file: String = _out.path_join("%s_%s.html" % [_name, when])
	var writing: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	writing.store_string(html)
	writing.close()
	var pages: Array = []
	var layout: Array = []
	var entries: Dictionary = {}
	for page: Booklet.Page in document.pages:
		if page.kind == "steps" or page.kind == "callout":
			pages.append(page)
		var numbers: Array = []
		for entry: Booklet.Entry in page.entries:
			numbers.append(entry.number)
			if page.kind == "steps":
				entries[entry.number] = [entry, page]
		layout.append({"page": page.number, "kind": page.kind, "steps": numbers})
	var json: FileAccess = FileAccess.open(_out.path_join("%s_%s.json" % [_name, when]),
		FileAccess.WRITE)
	json.store_string(JSON.stringify({"pages": document.pages.size(), "layout": layout}, " "))
	json.close()
	_check("the booklet %s: %d pages, %d steps, written to %s" % [when, document.pages.size(),
		document.steps, file.get_file()], not html.is_empty() and document.pages.size() > 3)
	return {"pages": pages, "document": document, "entries": entries}


# -- reading the file -----------------------------------------------------------


func _captions() -> Array:
	var out: Array = []
	for step: Instructions.Step in _steps.steps():
		out.append("%d %s/%d %d" % [step.number, step.authored_in, step.authored_step,
			step.brick_ids.size()])
	return out


static func _pages_of(pages: Array) -> String:
	var out := PackedStringArray()
	for page: Booklet.Page in pages:
		if page.kind != "steps" and page.kind != "callout":
			continue
		var numbers := PackedStringArray()
		for entry: Booklet.Entry in page.entries:
			numbers.append(str(entry.number))
		out.append("%s:%s" % [page.kind.left(1), ",".join(numbers)])
	return " ".join(out)


static func _without_lines(looks: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for name: String in looks:
		var look: Dictionary = (looks[name] as Dictionary).duplicate()
		look.erase("line")
		out[name] = look
	return out


static func _is_step_line(line: String) -> bool:
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	return words.size() >= 2 and words[0] == "0" \
		and (words[1].to_upper() == "STEP" or words[1].to_upper() == "ROTSTEP")


## The lines of the app's own that any save writes (what it stands on, the
## set it is, its steps said to be the author's): not a change to the file.
static func _only_app_lines(lines: Array) -> bool:
	for line: Variant in lines:
		if not str(line).begins_with("0 !BRICKWORKS "):
			return false
	return true


## Only the parts' lines moved, none rewritten: what went out came back in,
## the same text; the lines that end steps aside.
static func _parts_moved_only(out: Array, put: Array) -> bool:
	var counts: Dictionary = {}
	for line: Variant in out:
		if not _is_step_line(str(line)):
			counts[str(line)] = int(counts.get(str(line), 0)) + 1
	for line: Variant in put:
		if not _is_step_line(str(line)):
			counts[str(line)] = int(counts.get(str(line), 0)) - 1
	for line: String in counts:
		if int(counts[line]) != 0:
			return false
	return true


## Only lines moved: what went out came back in, the same text, with
## [param extra] put in besides; the app's own lines aside.
static func _moved_only(out: Array, put: Array, extra: Array) -> bool:
	var counts: Dictionary = {}
	for line: Variant in out:
		counts[str(line)] = int(counts.get(str(line), 0)) + 1
	for line: Variant in put:
		counts[str(line)] = int(counts.get(str(line), 0)) - 1
	for line: Variant in extra:
		counts[str(line)] = int(counts.get(str(line), 0)) + 1
	for line: String in counts:
		if int(counts[line]) != 0:
			return false
	return true


static func _few(lines: Variant) -> String:
	var shown := PackedStringArray()
	for line: Variant in (lines as Array).slice(0, 3):
		shown.append("\"%s\"" % str(line).strip_edges().left(48))
	if (lines as Array).size() > 3:
		shown.append("and %d more" % ((lines as Array).size() - 3))
	return "[%s]" % ", ".join(shown)


## The lines of [param a] not in [param b] and of [param b] not in [param a],
## by the longest run they share, in order: [taken out, put in].
static func _diff(a: String, b: String) -> Array:
	var x: PackedStringArray = a.replace("\r", "").split("\n")
	var y: PackedStringArray = b.replace("\r", "").split("\n")
	# What both begin and end with is shared: the table is for the middle.
	var head: int = 0
	while head < x.size() and head < y.size() and x[head] == y[head]:
		head += 1
	var tail: int = 0
	while tail < x.size() - head and tail < y.size() - head \
			and x[x.size() - 1 - tail] == y[y.size() - 1 - tail]:
		tail += 1
	var xs: PackedStringArray = x.slice(head, x.size() - tail)
	var ys: PackedStringArray = y.slice(head, y.size() - tail)
	var n: int = xs.size()
	var m: int = ys.size()
	if n * m > 4000000:
		return [Array(xs), Array(ys)]
	var table := PackedInt32Array()
	table.resize((n + 1) * (m + 1))
	for i: int in range(n - 1, -1, -1):
		for j: int in range(m - 1, -1, -1):
			table[i * (m + 1) + j] = table[(i + 1) * (m + 1) + j + 1] + 1 if xs[i] == ys[j] \
				else maxi(table[(i + 1) * (m + 1) + j], table[i * (m + 1) + j + 1])
	var out: Array = []
	var put: Array = []
	var i: int = 0
	var j: int = 0
	while i < n and j < m:
		if xs[i] == ys[j]:
			i += 1
			j += 1
		elif table[(i + 1) * (m + 1) + j] >= table[i * (m + 1) + j + 1]:
			out.append(xs[i])
			i += 1
		else:
			put.append(ys[j])
			j += 1
	while i < n:
		out.append(xs[i])
		i += 1
	while j < m:
		put.append(ys[j])
		j += 1
	return [out, put]
