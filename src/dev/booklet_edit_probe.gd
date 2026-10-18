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


## A press at [param from], the pointer moved to [param to] in steps, and a
## release there: a drag as a person drags, in the window's own pixels.
func _drag_mouse(from: Vector2, to: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var moved := InputEventMouseMotion.new()
	moved.position = from * scale
	moved.global_position = moved.position
	Input.parse_input_event(moved)
	await _frames(3)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from * scale
	down.global_position = down.position
	Input.parse_input_event(down)
	await _frames(3)
	for n: int in range(1, 9):
		var step := InputEventMouseMotion.new()
		step.position = from.lerp(to, n / 8.0) * scale
		step.global_position = step.position
		step.button_mask = MOUSE_BUTTON_MASK_LEFT
		step.relative = (to - from) / 8.0 * scale
		Input.parse_input_event(step)
		await _frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to * scale
	up.global_position = up.position
	Input.parse_input_event(up)
	await _frames(4)


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
	if _only.is_empty() or _only == "gatehouse":
		await _gatehouse()
	for set: Array in SETS:
		if _only.is_empty() or str(set[1]) == _only:
			await _one_set(str(set[0]), str(set[1]))
	print("")
	print("booklet edit: %s" % ("every check passed" if _failures == 0
		else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- steps_flow's own case ----------------------------------------------------------


## What steps_flow.mjs does in a browser, here: gatehouse.mpd's yellow brick
## (step 2 of the model's own, the timeline's step 3) moved by Shift-] into
## the blue brick's step, Ctrl-Z, Shift-] again, and the file exported.
## The blue brick's step ends in a ROTSTEP that turns the windows' step
## after it; the yellow brick's step, emptied, goes. The export must have
## four steps of the model's own, the yellow with the blue in the second,
## the windows and the white brick in the third with the ROTSTEP before
## them still, the green plate in the fourth. m65 lost the ROTSTEP line, so
## the third step ran into the second (three steps).
func _gatehouse() -> void:
	_name = "gatehouse"
	print("")
	print("gatehouse.mpd, as steps_flow.mjs moves its yellow brick")
	await _open("res://tests/fixtures/steps/gatehouse.mpd")
	await _timeline()
	_steps.set_mode(StepsBar.AUTHORS)
	await _frames(2)
	var yellow: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3003":
			yellow = brick.id
	var third: Instructions.Step = _go(3)
	var said: String = _shell.change_steps("next", [yellow], third)
	_check("Shift-] on step 3's yellow brick: \"%s\"" % said, said.contains("moved 1 part"))
	_builder.undo()
	await _frames(2)
	_steps.refresh(3)
	said = _shell.change_steps("next", [yellow], _go(3))
	_check("...Ctrl-Z, and Shift-] again: \"%s\"" % said, said.contains("moved 1 part"))
	var text: String = _save()
	var kept: FileAccess = FileAccess.open(_out.path_join("gatehouse_moved.mpd"), FileAccess.WRITE)
	kept.store_string(text)
	kept.close()
	var main: Array = _main_steps(text)
	_check("exported: four steps of the model's own, the yellow brick with the blue (%s)"
		% JSON.stringify(main), main.size() == 4 and str(main[0]) == "base.ldr/16"
		and str(main[1]) == "3003.dat/14 3005.dat/1"
		and str(main[2]) == "3004.dat/15 window.ldr/16 window.ldr/16"
		and str(main[3]) == "3022.dat/2")
	_check("...the blue brick's step still ends in its ROTSTEP, which turns the windows' step",
		text.contains("3005.dat\n0 ROTSTEP 0 45 0 ABS\n") or text.contains("3005.dat\r\n0 ROTSTEP 0 45 0 ABS"))


## A file's model's own steps as steps_flow.mjs reads them: each step's
## parts, "file/colour", sorted, the model's section only.
static func _main_steps(text: String) -> Array:
	var main: String = text.split("0 NOFILE")[0]
	var steps: Array = []
	var now: Array = []
	for raw: String in main.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 STEP") or line.begins_with("0 ROTSTEP"):
			now.sort()
			steps.append(" ".join(now))
			now = []
		elif line.begins_with("1 "):
			var words: PackedStringArray = line.split(" ", false)
			now.append(words[words.size() - 1].to_lower() + "/" + words[1])
	if not now.is_empty():
		now.sort()
		steps.append(" ".join(now))
	return steps


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
		await _page_by_hand(base)
		await _page_over_mcp(base)
		await _follows(base)
		await _overlap_said(base)
		await _arrows(base)
		await _signs(base)
		await _callout_by_hand(base)
		# 30050-1 turns its sub-models with ROTSTEPs of its own.
		_step_player("as opened", name == "30050-1")
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
		_world.brick_count() > 10 and _store.awaited.is_empty())


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


static func _line_with(text: String, part: String, most: int = 150) -> String:
	for line: String in text.split("\n"):
		if line.contains(part):
			return line.strip_edges().left(most)
	return ""


## The page by hand, in Lay out the page (PageEditor): the page's first
## step's picture dragged by the mouse and let go a millimetre and a half
## off the page's top margin, which it snaps onto; its parts list widened by
## its corner; its number moved; words and a picture added; the new parts'
## outline turned off. Each one undo step, the file gaining exactly the
## line that says it (the picture its !DATA too), and one undo giving the
## file back byte for byte.
func _page_by_hand(base: String) -> void:
	var editor: PageEditor = _main.get("_page_editor")
	var own: Array[Instructions.Step] = _own_steps(2)
	var pick: Instructions.Step = own[mini(1, own.size() - 1)]
	_go(pick.number)
	await editor.open()
	await _frames(4)
	var state: Dictionary = editor.page_state()
	var first: int = int((state.get("steps", [0]) as Array)[0])
	var items: Dictionary = state.get("items", {})
	_check("Lay out the page on step %d: page %d, steps %s, %d items (%s)" % [pick.number,
		int(state.get("page", 0)), str(state.get("steps", [])), items.size(),
		", ".join(PackedStringArray(items.keys())).left(120)],
		items.has("page_picture_%d" % first) and _history() >= 0)
	var mouse: bool = DisplayServer.get_name() != "headless"
	if mouse:
		# The page's own pictures, drawn as Instructions draws them.
		var began: int = Time.get_ticks_msec()
		for _n: int in 3000:
			if (editor.page_state().get("drawn", []) as Array).size() == (state.get("steps", []) as Array).size():
				break
			await process_frame
		_check("...its %d steps' pictures drawn on it, in %.1f s" % [
			(editor.page_state().get("drawn", []) as Array).size(),
			(Time.get_ticks_msec() - began) / 1000.0],
			(editor.page_state().get("drawn", []) as Array).size() == (state.get("steps", []) as Array).size())
		await _frames(4)
		var drawn: Image = root.get_texture().get_image()
		if drawn != null:
			drawn.save_png(_out.path_join("%s_page_editor_open.png" % _name))
	# The picture, dragged.
	var history: int = _history()
	var name: String = "page_picture_%d" % first
	var at: int = editor.item_named(name)
	var was: Rect2 = editor._items[at]["rect"]
	var by := Vector2(30.0, Booklet.MARGIN + 1.5 - was.position.y)
	var others: Array = []
	for n: int in editor._items.size():
		if n != at:
			others.append(editor._items[n]["rect"])
	var want: Rect2 = Booklet.snapped_to(Rect2(was.position + by, was.size), others)["rect"]
	if mouse:
		var control: Control = editor._items[at]["control"]
		var from: Vector2 = control.get_global_rect().get_center()
		var k: float = editor._scale() * editor._canvas.get_global_transform().get_scale().x
		await _drag_mouse(from, from + by * k)
	else:
		await editor.place(at, want)
	await _until_laid(editor)
	var placed: Array = editor.page_state().get("items", {}).get(name, [])
	var diff: Array = _edited("%s %s from %s by %s to %s" % ["dragged by the mouse" if mouse
		else "placed", name, _mm(was), by, str(placed)], base, history)
	_check("...snapped onto the top margin (y %s, want %s), where the snapping rule puts it (%s)"
		% [str(placed[1]) if not placed.is_empty() else "?", Booklet.MARGIN, _mm(want)],
		not placed.is_empty() and is_equal_approx(float(placed[1]), Booklet.MARGIN)
		and absf(float(placed[0]) - want.position.x) < 0.6)
	await _judge(diff, _put_one(diff, "0 !BRICKWORKS PLACE PICTURE "), base)
	await _until_laid(editor)
	# The parts list, widened by its corner.
	name = "page_parts_%d" % first
	at = editor.item_named(name)
	if at >= 0:
		history = _history()
		was = editor._items[at]["rect"]
		if mouse:
			await _click((editor._items[at]["control"] as Control).get_global_rect().get_center())
			await _frames(3)
			var corner: Vector2 = editor._handle.get_global_rect().get_center()
			var k: float = editor._scale() * editor._canvas.get_global_transform().get_scale().x
			await _drag_mouse(corner, corner + Vector2(24.0, 0.0) * k)
		else:
			await editor.place(at, Rect2(was.position, was.size + Vector2(24.0, 0.0)))
		await _until_laid(editor)
		var wide: Array = editor.page_state().get("items", {}).get(name, [])
		diff = _edited("%s the parts list's corner by 24 mm: %s to %s" % ["dragged" if mouse else "moved",
			_mm(was), str(wide)], base, history)
		await _judge(diff, _put_one(diff, "0 !BRICKWORKS PLACE PARTS "), base)
		await _until_laid(editor)
	else:
		print("  (step %d has no parts list on its page)" % first)
	# The number, moved.
	name = "page_number_%d" % first
	at = editor.item_named(name)
	history = _history()
	was = editor._items[at]["rect"]
	await editor.place(at, Rect2(was.position + Vector2(0.0, 40.0), was.size))
	diff = _edited("step %d's number moved 40 mm down" % first, base, history)
	await _judge(diff, _put_one(diff, "0 !BRICKWORKS PLACE NUMBER "), base)
	await _until_laid(editor)
	# Words, added by the page's own button and typed over.
	history = _history()
	var said: String = await editor.add_text("Build two of these", Rect2(150, 160, 90, 14), 5.0)
	diff = _edited("Add words (\"%s\")" % said, base, history)
	_check("...shown on the page: %s" % str(editor.page_state().get("items", {}).keys().filter(
		func(item: String) -> bool: return item.begins_with("page_text"))),
		editor.page_state().get("items", {}).has("page_text_%d_0" % first))
	await _judge(diff, _put_one(diff, "0 !BRICKWORKS TEXT 150 160 90 14 5 Build two of these", true),
		base)
	await _until_laid(editor)
	# A picture of the designer's.
	history = _history()
	var picture := Image.create(64, 48, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.85, 0.2, 0.15))
	picture.fill_rect(Rect2i(8, 8, 24, 24), Color(1, 1, 1))
	said = await editor.add_image(picture)
	diff = _edited("Add a picture (\"%s\")" % said, base, history)
	var put: Array = diff[1]
	var image_line: bool = put.any(func(line: Variant) -> bool:
		return str(line).strip_edges().begins_with("0 !BRICKWORKS IMAGE ") \
			and str(line).strip_edges().ends_with(BookletLooks.IMAGE_PREFIX + "1.jpg"))
	var data_line: bool = put.any(func(line: Variant) -> bool:
		return str(line).strip_edges() == "0 !DATA " + BookletLooks.IMAGE_PREFIX + "1.jpg")
	var rest: Array = put.filter(func(line: Variant) -> bool:
		return not str(line).begins_with("0 !: ") and not str(line).strip_edges().is_empty())
	await _judge(diff, (diff[0] as Array).is_empty() and image_line and data_line and rest.size() == 3
		and _put_one([[], rest.filter(func(line: Variant) -> bool:
			return not str(line).begins_with("0 !DATA"))], "0 !BRICKWORKS IMAGE "), base)
	await _until_laid(editor)
	# The new parts' outline, off for the booklet.
	history = _history()
	said = _shell.change_look("highlight", _go(pick.number))
	diff = _edited("Outline new parts off (\"%s\")" % said, base, history)
	await _judge(diff, (diff[0] as Array).is_empty() and (diff[1] as Array).size() == 1
		and str(diff[1][0]).strip_edges() == "0 !BRICKWORKS HIGHLIGHT OFF", base)
	await _until_laid(editor)
	if mouse:
		var picture_path: String = _out.path_join("%s_page_editor.png" % _name)
		var shot: Image = root.get_texture().get_image()
		if shot != null:
			shot.save_png(picture_path)
	editor.close()


## The same over MCP: edit_booklet's place= and text=, one undo each and
## the line that says it; booklet_layout says where each is.
func _page_over_mcp(base: String) -> void:
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	var own: Array[Instructions.Step] = _own_steps(2)
	var pick: Instructions.Step = own[mini(1, own.size() - 1)]
	var history: int = _history()
	var said: String = str(await tools.run("edit_booklet", {"step": pick.number,
		"place": {"item": "picture", "x": 60, "y": 30, "w": 150, "h": 110}}))
	var diff: Array = _edited("edit_booklet place picture at 60, 30, 150 x 110 (\"%s\")" % said.left(80),
		base, history)
	var layout: String = str(await tools.run("booklet_layout", {}))
	_check("...booklet_layout says it: %s" % _line_with(layout, "%d (" % pick.number),
		_line_with(layout, "%d (" % pick.number).contains("picture at 60, 30 mm (150 wide, 110 high)"))
	await _judge(diff, _put_one(diff, "0 !BRICKWORKS PLACE PICTURE 60 30 150 110", true), base)
	history = _history()
	said = str(await tools.run("edit_booklet", {"step": pick.number,
		"text": {"words": "Turn the model round", "x": 20, "y": 170, "w": 70, "h": 10, "size": 4.5}}))
	diff = _edited("edit_booklet text \"Turn the model round\" (\"%s\")" % said.left(80), base, history)
	layout = str(await tools.run("booklet_layout", {}))
	_check("...booklet_layout says it: %s" % _line_with(layout, "%d (" % pick.number),
		_line_with(layout, "%d (" % pick.number).contains("text \"Turn the model round\" at 20, 170 mm"))
	await _judge(diff, _put_one(diff, "0 !BRICKWORKS TEXT 20 170 70 10 4.5 Turn the model round", true),
		base)
	history = _history()
	said = str(await tools.run("edit_booklet", {"step": pick.number, "highlight": false}))
	diff = _edited("edit_booklet highlight false (\"%s\")" % said.left(80), base, history)
	await _judge(diff, (diff[0] as Array).is_empty() and (diff[1] as Array).size() == 1
		and str(diff[1][0]).strip_edges() == "0 !BRICKWORKS HIGHLIGHT OFF", base)
	history = _history()
	said = str(await tools.run("edit_booklet", {"step": pick.number, "place": {"item": "picture",
		"x": 60}}))
	_check("edit_booklet place without y refuses, no undo step (\"%s\")" % said.left(70),
		said.contains("needs x and y") and _history() == history)


## What is placed goes with its step. A step's picture placed by hand in its
## room on the page, words put on its page; then two steps before it merged,
## so the pages flow again and the step lands in another room: its picture
## and words are in that room, where they were in the old one, and nothing on
## any page lies on anything else. Every undo back gives the file back.
func _follows(base: String) -> void:
	var editor: PageEditor = _main.get("_page_editor")
	var laid: Array[Booklet.Page] = await _laid()
	var target: Booklet.Entry = null
	for page: Booklet.Page in laid:
		if page.kind == "steps" and page.number > 2 and page.entries.size() >= 2:
			target = page.entries[page.entries.size() - 1]
			break
	if target == null:
		_check("a page of two steps or more to lay out by hand", false)
		return
	var history: int = _history()
	var room: Rect2 = target.panel
	var want := Rect2(room.position + room.size * Vector2(0.38, 0.12), room.size * 0.6)
	_go(target.number)
	await editor.open()
	await _until_laid(editor)
	var at: int = editor.item_named("page_picture_%d" % target.number)
	if at < 0:
		_check("step %d's picture on Lay out the page" % target.number, false)
		editor.close()
		return
	await editor.place(at, want)
	await _until_laid(editor)
	var words: String = _shell.change_look("text", _go(target.number), {"text": "Mind the hinge",
		"at": [room.position.x + 2.0, room.end.y - 10.0, 46.0, 8.0], "size": 4.0,
		"room": BookletLooks.said_rect(room)})
	editor.close()
	var saved: String = _save()
	_check("step %d's picture placed in its room %s at %s, and words (\"%s\"): the file says the room"
		% [target.number, _mm(room), _mm(want), words],
		saved.contains("0 !BRICKWORKS PANEL %s" % BookletLooks._numbers_said(BookletLooks.said_rect(room)))
		and _history() == history + 2)
	# The two steps before its page merged, and the next pair, until the step
	# lands in another room.
	var own: Array[Instructions.Step] = _own_steps()
	var moved: Booklet.Entry = null
	var merged: String = ""
	for n: int in own.size() - 1:
		if own[n + 1].number >= target.number - 1:
			break
		if own[n + 1].authored_in != own[n].authored_in or _seen_as(own[n]) != _seen_as(own[n + 1]):
			continue
		var before: int = _history()
		merged = _shell.change_steps("merge", [], _go(own[n].number))
		if _history() == before:
			continue
		for page: Booklet.Page in await _laid():
			for entry: Booklet.Entry in page.entries:
				if page.kind == "steps" and entry.place.has("picture"):
					moved = entry
		if moved != null and not BookletLooks.same_room(moved.panel, room):
			merged = "step %d merged with the next (\"%s\")" % [own[n].number, merged]
			break
		moved = null
		_builder.undo()
		await _frames(2)
		_steps.refresh()
	if moved == null:
		# No merge before it moves it (a short booklet): the step given a page
		# alone, which gives it the whole page.
		merged = _shell.change_look("alone", _go(target.number))
		for page: Booklet.Page in await _laid():
			for entry: Booklet.Entry in page.entries:
				if page.kind == "steps" and entry.place.has("picture"):
					moved = entry
		if moved != null and BookletLooks.same_room(moved.panel, room):
			moved = null
	if moved == null:
		_check("a merge before step %d that moves it to another room" % target.number, false)
	else:
		var went: Rect2 = BookletLooks._moved(want, room, moved.panel)
		var note: Rect2 = BookletLooks.rect_of((moved.notes[0] as Dictionary).get("at", [])) \
			if not moved.notes.is_empty() else Rect2()
		_check("%s: step %d (now %d) went from room %s to %s, its picture with it (%s, want %s), its words in its room (%s)"
			% [merged, target.number, moved.number, _mm(room), _mm(moved.panel), _mm(moved.rect),
				_mm(went), _mm(note)],
			moved.rect.position.distance_to(went.position) < 0.3
			and moved.rect.size.distance_to(went.size) < 0.3
			and moved.panel.grow(1.0).encloses(Booklet.ink_of(moved))
			and moved.panel.grow(1.0).encloses(note))
		var on_top: String = _on_top(await _laid())
		_check("...and nothing on any page lies on anything else: %s" % on_top, on_top == "none")
	while _history() > history:
		_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("...undone, the file as it was", _save() == base and _history() == history)


## Two items dropped on each other: on a page of two steps, the second
## step's picture dragged onto the first's model. The page says so, outlines
## it in red, and lays out nothing on anything else; the file keeps the
## picture where it was dropped.
func _overlap_said(base: String) -> void:
	var editor: PageEditor = _main.get("_page_editor")
	var laid: Array[Booklet.Page] = await _laid()
	var page: Booklet.Page = null
	for one: Booklet.Page in laid:
		if one.kind == "steps" and one.entries.size() >= 2:
			page = one
			break
	if page == null:
		_check("a page of two steps to drop one on the other", false)
		return
	var first: Booklet.Entry = page.entries[0]
	var second: Booklet.Entry = page.entries[1]
	var history: int = _history()
	_go(second.number)
	await editor.open()
	await _until_laid(editor)
	var at: int = editor.item_named("page_picture_%d" % second.number)
	var ink: Rect2 = Booklet.ink_of(first)
	await editor.place(at, Rect2(ink.get_center() - second.rect.size * 0.25, second.rect.size * 0.5))
	await _until_laid(editor)
	var state: Dictionary = editor.page_state()
	var after: Array[Booklet.Page] = await _laid()
	var now: Booklet.Page = null
	for one: Booklet.Page in after:
		if one.number == page.number:
			now = one
	_check("step %d's picture dropped on step %d's: the page says \"%s\", %s outlined" % [
		second.number, first.number, str(state.get("said", "")).left(110),
		str((state.get("overlaps", {}) as Dictionary).keys())],
		str(state.get("said", "")).begins_with("Overlapping:")
		and not (state.get("overlaps", {}) as Dictionary).is_empty())
	_check("...laid out with nothing on anything else (%s), step %d's picture where it was dropped"
		% [_on_top(after), second.number], now != null and _on_top(after) == "none"
		and (now.entries[1] as Booklet.Entry).place.has("picture"))
	if DisplayServer.get_name() != "headless":
		for _n: int in 3000:
			if (editor.page_state().get("drawn", []) as Array).size() == now.entries.size():
				break
			await process_frame
		await _frames(4)
		var shot: Image = root.get_texture().get_image()
		if shot != null:
			shot.save_png(_out.path_join("%s_page_editor_overlap.png" % _name))
	editor.close()
	_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("...undone, the file as it was", _save() == base and _history() == history)


## The designer's own arrows, on Lay out the page: Draw an arrow pressed and
## a drag on the page from where it starts to where it points, its middle
## dragged to bend it, Arrow colour and Arrow width, Ctrl-Z; then one over
## MCP, which booklet_layout lists. Each one undo and the file's one line
## (with the step's room the first time), and the file back at the end.
func _arrows(base: String) -> void:
	var editor: PageEditor = _main.get("_page_editor")
	var own: Array[Instructions.Step] = _own_steps(2)
	var pick: Instructions.Step = own[mini(1, own.size() - 1)]
	var history: int = _history()
	var start: int = history
	_go(pick.number)
	await editor.open()
	await _until_laid(editor)
	var mouse: bool = DisplayServer.get_name() != "headless"
	var from := Vector2(40.0, 60.0)
	var to := Vector2(90.0, 95.0)
	var k: float = editor._scale() * editor._canvas.get_global_transform().get_scale().x
	var origin: Vector2 = editor._canvas.get_global_rect().position
	if mouse:
		await _click((editor.controls_by_name()["page_add_arrow"] as Control).get_global_rect().get_center())
		_check("Draw an arrow pressed: the page is ready to draw on", bool(editor.page_state().get("arrow_mode", false)))
		await _drag_mouse(origin + from * k, origin + to * k)
	else:
		await editor.add_arrow(from, to)
	await _until_laid(editor)
	var arrows: Dictionary = editor.page_state().get("arrows", {})
	var diff: Array = _edited("an arrow %s from %s to %s mm on page %d: %s" % [
		"dragged by the mouse" if mouse else "drawn", from, to, int(editor.page_state().get("page", 0)),
		JSON.stringify(arrows)], base, history)
	var line: Array = (diff[1] as Array).filter(func(one: Variant) -> bool:
		return str(one).begins_with("0 !BRICKWORKS ARROW "))
	var words: PackedStringArray = str(line[0]).strip_edges().split(" ") if not line.is_empty() \
		else PackedStringArray()
	_check("...the file says it: %s" % (str(line[0]).strip_edges() if not line.is_empty() else "no ARROW line"),
		_put_one(diff, "0 !BRICKWORKS ARROW RED 0.9 ") and words.size() == 9
		and Vector2(words[5].to_float(), words[6].to_float()).distance_to(from) < Booklet.SNAP + 0.2
		and Vector2(words[7].to_float(), words[8].to_float()).distance_to(to) < Booklet.SNAP + 0.2
		and arrows.size() == 1)
	var name: String = arrows.keys()[0] if not arrows.is_empty() else ""
	var at: int = editor.item_named(name)
	if at < 0:
		editor.close()
		while _history() > start:
			_builder.undo()
		return
	editor._select(at)
	await _frames(3)
	# Its middle dragged 15 mm aside: bent.
	history = _history()
	var shown: Array = (editor.page_state().get("arrows", {})[name] as Dictionary)["at"]
	var middle := Vector2((float(shown[0]) + float(shown[2])) * 0.5, (float(shown[1]) + float(shown[3])) * 0.5)
	var aside: Vector2 = Vector2(float(shown[3]) - float(shown[1]), float(shown[0]) - float(shown[2])).normalized() * 15.0
	if mouse:
		var handle: Control = editor.controls_by_name().get("page_arrow_bend")
		await _drag_mouse(handle.get_global_rect().get_center(), handle.get_global_rect().get_center() + aside * k)
	else:
		editor._shell.change_look("arrow_edit", editor._items[at]["step"], {"index": 0,
			"at": shown.slice(0, 4) + [middle.x + aside.x, middle.y + aside.y],
			"room": BookletLooks.said_rect((editor._items[at]["entry"] as Booklet.Entry).panel)})
		await editor._lay_out(pick.number)
	await _until_laid(editor)
	var bent: Array = ((editor.page_state().get("arrows", {}) as Dictionary).get(name, {}) as Dictionary).get("at", [])
	_check("...its middle dragged %.0f mm aside: bent through %s, want near %s, one undo step (%d)"
		% [aside.length(), str(bent.slice(4)), middle + aside, _history() - history],
		bent.size() == 6 and Vector2(float(bent[4]), float(bent[5])).distance_to(middle + aside) < 1.0
		and _history() == history + 1 and _line_with(_save(), "!BRICKWORKS ARROW").strip_edges()
			.split(" ").size() == 11)
	# Colour and width by the page's buttons.
	history = _history()
	at = editor.item_named(name)
	editor._select(at)
	if mouse:
		await _click((editor.controls_by_name()["page_arrow_colour"] as Control).get_global_rect().get_center())
	else:
		await editor._pressed("page_arrow_colour")
	await _until_laid(editor)
	at = editor.item_named(name)
	editor._select(at)
	if mouse:
		await _click((editor.controls_by_name()["page_arrow_width"] as Control).get_global_rect().get_center())
	else:
		await editor._pressed("page_arrow_width")
	await _until_laid(editor)
	var styled: Dictionary = (editor.page_state().get("arrows", {}) as Dictionary).get(name, {})
	var saved: String = _save()
	_check("Arrow colour and Arrow width: %s, %s mm, two undo steps (%d); the file: %s" % [
		styled.get("colour", "?"), styled.get("width", "?"), _history() - history,
		_line_with(saved, "!BRICKWORKS ARROW").strip_edges()],
		str(styled.get("colour", "")) == "black" and is_equal_approx(float(styled.get("width", 0.0)), 1.4)
		and _history() == history + 2 and _line_with(saved, "!BRICKWORKS ARROW").strip_edges().begins_with("0 !BRICKWORKS ARROW BLACK 1.4 "))
	if mouse:
		await _key(KEY_Z, true)
		await _until_laid(editor)
	else:
		_builder.undo()
		await editor._lay_out(pick.number)
	styled = (editor.page_state().get("arrows", {}) as Dictionary).get(name, {})
	_check("...Ctrl-Z: the width back, the colour kept (%s, %s mm)" % [styled.get("colour", "?"),
		styled.get("width", "?")], str(styled.get("colour", "")) == "black"
		and is_equal_approx(float(styled.get("width", 0.0)), 0.9))
	if mouse:
		var shot: Image = root.get_texture().get_image()
		if shot != null:
			shot.save_png(_out.path_join("%s_page_editor_arrow.png" % _name))
	editor.close()
	while _history() > start:
		_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("...undone, the file as it was", _save() == base)
	# Over MCP.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	history = _history()
	var said: String = str(await tools.run("edit_booklet", {"step": pick.number,
		"arrow": {"x1": 30, "y1": 40, "x2": 70, "y2": 80, "bx": 60, "by": 45, "colour": "black"}}))
	diff = _edited("edit_booklet arrow from 30, 40 to 70, 80 through 60, 45, black (\"%s\")" % said.left(90),
		base, history)
	var layout: String = str(await tools.run("booklet_layout", {}))
	var listed: String = _line_with(layout, "%d (" % pick.number, 4000)
	_check("...booklet_layout lists it: %s" % listed.substr(maxi(0, listed.find("arrow") - 10), 120),
		listed.contains("a black arrow from 30, 40 to 70, 80 mm, bent through 60, 45, 0.9 mm wide"))
	await _judge(diff, _put_one(diff, "0 !BRICKWORKS ARROW BLACK 0.9 30 40 70 80 60 45", true), base)
	said = str(await tools.run("edit_booklet", {"step": pick.number, "arrow": {"x1": 30}}))
	_check("edit_booklet arrow without its points refuses, no undo step (\"%s\")" % said.left(70),
		said.contains("where it starts") and _history() == history)


## The turn sign. A step tilted 30 degrees lower than the one before has
## none (under the 45 a turn over needs); 60 lower has one, under its
## number. Taken off (TURN_SIGN OFF, one line, one undo), it is off; on Lay
## out the page it is a faint sign that Put back puts back and Delete takes
## off again; over MCP sign=false takes it off and booklet_layout says so.
func _signs(base: String) -> void:
	var own: Array[Instructions.Step] = _own_steps(1)
	var pick: Instructions.Step = null
	for n: int in range(2, own.size() - 1):
		if own[n].authored_in == own[n - 1].authored_in and _seen_as(own[n]) == _seen_as(own[n - 1]):
			pick = own[n]
			break
	if pick == null:
		_check("a step seen as the one before it, to tilt", false)
		return
	var start: int = _history()
	var number: int = pick.number
	_shell.change_look("tilt_down", _go(number))
	_shell.change_look("tilt_down", _go(number))
	var entry: Booklet.Entry = _entry_in(await _laid(), number)
	_check("step %d tilted 30° lower than step %d: no turn sign (%s)" % [number, number - 1,
		BookletLooks.said(_world, pick.authored_in, pick.authored_step)],
		entry != null and not entry.turned)
	_shell.change_look("tilt_down", _go(number))
	_shell.change_look("tilt_down", _go(number))
	entry = _entry_in(await _laid(), number)
	_check("...60° lower: the turn sign, under its number (%s)" % [_mm(Booklet.sign_rect(entry))
		if entry != null else "?"], entry != null and entry.turned
		and Booklet.sign_rect(entry).position.y >= entry.number_at.y + entry.number_size
		and absf(Booklet.sign_rect(entry).position.x - entry.number_at.x) < 0.01)
	var before: String = _save()
	var history: int = _history()
	var said: String = _shell.change_look("sign", _go(number))
	var diff: Array = _edited("its sign taken off (\"%s\")" % said, before, history)
	entry = _entry_in(await _laid(), number)
	_check("...the file: %s; laid out without it" % str(diff[1]), (diff[0] as Array).is_empty()
		and (diff[1] as Array).size() == 1
		and str(diff[1][0]).strip_edges() == "0 !BRICKWORKS TURN_SIGN OFF"
		and entry != null and not entry.turned and entry.sign_off)
	# On Lay out the page: put back, and taken off again.
	var editor: PageEditor = _main.get("_page_editor")
	_go(number)
	await editor.open()
	await _until_laid(editor)
	var name: String = "page_sign_%d" % number
	var at: int = editor.item_named(name)
	var mouse: bool = DisplayServer.get_name() != "headless"
	if at >= 0:
		editor._select(at)
		if mouse:
			await _click((editor.controls_by_name()["page_put_back"] as Control).get_global_rect().get_center())
		else:
			await editor._pressed("page_put_back")
		await _until_laid(editor)
		var back: bool = not _save().contains("TURN_SIGN OFF")
		at = editor.item_named(name)
		if at >= 0:
			editor._select(at)
			if mouse:
				await _click((editor._items[at]["control"] as Control).get_global_rect().get_center())
				await _key(KEY_DELETE)
			else:
				await editor._pressed("page_put_back")
			await _until_laid(editor)
		_check("Lay out the page: the faint sign put back (%s), and Delete takes it off again (%s)"
			% [back, _save().contains("TURN_SIGN OFF")], back and _save().contains("TURN_SIGN OFF")
			and _history() == history + 3)
		if mouse:
			var shot: Image = root.get_texture().get_image()
			if shot != null:
				shot.save_png(_out.path_join("%s_page_editor_sign.png" % _name))
	else:
		_check("Lay out the page shows step %d's sign, off" % number, false)
	editor.close()
	# Over MCP.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	said = str(await tools.run("edit_booklet", {"step": number, "sign": true}))
	var on: bool = not _save().contains("TURN_SIGN OFF")
	said = str(await tools.run("edit_booklet", {"step": number, "sign": false}))
	var layout: String = str(await tools.run("booklet_layout", {}))
	_check("edit_booklet sign=true puts it back (%s), sign=false takes it off: \"%s\"" % [on,
		said.left(90)], on and _save().contains("TURN_SIGN OFF")
		and _line_with(layout, "%d (" % number, 4000).contains("no turn sign"))
	while _history() > start:
		_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("...undone, the file as it was", _save() == base)


## A callout's own page laid out by hand: a sub-assembly built on pages of
## its own (its callout turned off), Lay out the page shown on that page
## (Next page), its first step's picture dragged, and an arrow drawn; each
## one undo, its line in the sub-model's part of the file; laid out again,
## the picture where it was put. Undone, the file as it was.
func _callout_by_hand(base: String) -> void:
	var unit: String = ""
	var attach: Instructions.Step = null
	for one: Instructions.Step in _steps.steps():
		if one.attaches() and one.callout_step == 0 \
				and not BookletLooks.attached(_world, one, one.authored_in).is_empty():
			attach = one
			unit = BookletLooks.definition_of(BookletLooks.attached(_world, one, one.authored_in))
			break
	if attach == null:
		print("  (no sub-assembly to build on pages of its own)")
		return
	var start: int = _history()
	_shell.change_look("callout", _go(attach.number))
	var editor: PageEditor = _main.get("_page_editor")
	_go(attach.number)
	await editor.open()
	await _until_laid(editor)
	# Its own pages come before the page of the step that puts it on:
	# Previous page or Next page to the first of them.
	var target: int = -1
	for one: Booklet.Page in editor._pages:
		if one.kind == "callout" and target < 0:
			target = one.number
	var page: int = -1
	for n: int in 30:
		var now: int = int(editor.page_state().get("page", -1))
		if str(editor.page_state().get("kind", "")) == "callout":
			page = now
			break
		if target < 0:
			break
		var button: String = "page_prev" if now > target else "page_next"
		if DisplayServer.get_name() != "headless":
			await _click((editor.controls_by_name()[button] as Control).get_global_rect().get_center())
		else:
			editor._pressed(button)
		await _frames(2)
		if int(editor.page_state().get("page", -1)) == now:
			break
	var state: Dictionary = editor.page_state()
	_check("Lay out the page, Previous or Next page to the %s's own page: page %d, \"%s\", %d items" % [unit, page,
		editor._title.text, (state.get("items", {}) as Dictionary).size()],
		page > 0 and (state.get("items", {}) as Dictionary).has("page_picture_1"))
	if page <= 0:
		editor.close()
		while _history() > start:
			_builder.undo()
		return
	var history: int = _history()
	var at: int = editor.item_named("page_picture_1")
	var was: Rect2 = editor._items[at]["rect"]
	var frame: Rect2 = editor._pages[editor._at].frame
	var want := Rect2(frame.position + Vector2(60.0, 30.0), Vector2(90.0, 70.0))
	if DisplayServer.get_name() != "headless":
		var control: Control = editor._items[at]["control"]
		var k: float = editor._scale() * editor._canvas.get_global_transform().get_scale().x
		var from: Vector2 = control.get_global_rect().get_center()
		await _drag_mouse(from, from + (want.position - was.position) * k)
		await _until_laid(editor)
		at = editor.item_named("page_picture_1")
		if at >= 0:
			await editor.place(at, Rect2(editor._items[at]["rect"].position, want.size))
	else:
		await editor.place(at, want)
	await _until_laid(editor)
	var placed: Array = (editor.page_state().get("items", {}) as Dictionary).get("page_picture_1", [])
	var keyed: String = ""
	for name: String in _world.step_looks:
		if name.begins_with(unit + "|") and (_world.step_looks[name] as Dictionary).has("place"):
			keyed = name
	_check("...its first step's picture dragged and sized: at %s, page %d still shown; kept on the %s's step (%s) and in the file: %s" % [
		str(placed), int(editor.page_state().get("page", -1)), unit, keyed,
		_line_with(_save(), "!BRICKWORKS PLACE PICTURE")],
		not placed.is_empty() and int(editor.page_state().get("page", -1)) == page
		and not keyed.is_empty() and _save().contains("0 !BRICKWORKS PLACE PICTURE")
		and _history() >= history + 1)
	var drawn: String = await editor.add_arrow(want.position + Vector2(-30.0, 40.0), want.get_center())
	_check("...an arrow drawn on it (\"%s\"): %s" % [drawn.left(70), _line_with(_save(), "!BRICKWORKS ARROW")],
		(editor.page_state().get("arrows", {}) as Dictionary).size() == 1
		and int(editor.page_state().get("page", -1)) == page)
	var laid: Array[Booklet.Page] = await _laid()
	var entry: Booklet.Entry = null
	for one: Booklet.Page in laid:
		if one.number == page and one.kind == "callout":
			entry = one.entries[0]
	_check("...laid out again: the %s's step 1 at %s, %d arrow" % [unit,
		_mm(entry.rect) if entry != null else "?", entry.drawn_arrows.size() if entry != null else 0],
		entry != null and entry.place.has("picture") and entry.drawn_arrows.size() == 1
		and entry.rect.position.distance_to(Vector2(float(placed[0]), float(placed[1]))) < 0.2)
	if DisplayServer.get_name() != "headless":
		for _n: int in 3000:
			if not (editor.page_state().get("drawn", []) as Array).is_empty():
				break
			await process_frame
		await _frames(4)
		var shot: Image = root.get_texture().get_image()
		if shot != null:
			shot.save_png(_out.path_join("%s_page_editor_callout.png" % _name))
	editor.close()
	while _history() > start:
		_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("...undone, the file as it was", _save() == base)


## Step [param number]'s entry on [param pages] of steps, or null.
static func _entry_in(pages: Array, number: int) -> Booklet.Entry:
	for page: Booklet.Page in pages:
		if page.kind != "steps":
			continue
		for entry: Booklet.Entry in page.entries:
			if entry.number == number:
				return entry
	return null


## The booklet's pages laid out now, without pictures.
func _laid() -> Array[Booklet.Page]:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, _name)
	maker.queue_free()
	return pages


## What lies on what on [param pages] of steps (Booklet.things_on): "none",
## or the first few.
static func _on_top(pages: Array) -> String:
	var found := PackedStringArray()
	for page: Booklet.Page in pages:
		if page.kind != "steps":
			continue
		var things: Array = Booklet.things_on(page)
		for a: int in things.size():
			for b: int in range(a + 1, things.size()):
				var shared: Rect2 = (things[a]["rect"] as Rect2).intersection(things[b]["rect"])
				if shared.size.x > Booklet.OVERLAP and shared.size.y > Booklet.OVERLAP:
					found.append("page %d: step %d's %s on step %d's %s" % [page.number,
						(things[b]["entry"] as Booklet.Entry).number, things[b]["kind"],
						(things[a]["entry"] as Booklet.Entry).number, things[a]["kind"]])
	return "none" if found.is_empty() else ", ".join(found.slice(0, 3))


## Whether [param diff] (lines out, lines in) is one line put in that says
## [param line] (begins with it, or is it when [param exact]), with the
## PANEL line the step's first thing placed on its page brings: the room
## the step has on its page, which what is placed goes with.
static func _put_one(diff: Array, line: String, exact: bool = false) -> bool:
	var put: Array = (diff[1] as Array).map(func(one: Variant) -> String: return str(one).strip_edges())
	var rooms: Array = put.filter(func(one: String) -> bool: return one.begins_with("0 !BRICKWORKS PANEL "))
	var rest: Array = put.filter(func(one: String) -> bool: return not one.begins_with("0 !BRICKWORKS PANEL "))
	return (diff[0] as Array).is_empty() and rooms.size() == 1 and rest.size() == 1 \
		and (str(rest[0]) == line if exact else str(rest[0]).begins_with(line))


## The step player (Build it, a shared link) sees each step from where its
## designer turned it, as the booklet draws it (BuildSteps.view).
func _step_player(when: String, need: bool = true) -> void:
	var made: Array[Instructions.Step] = _steps.steps()
	var pages: BuildSteps = BuildSteps.of(_world, _library, made, _store.scenery)
	var turned: int = 0
	var wrong: Array = []
	for page: int in range(1, pages.last() + 1):
		var step: Instructions.Step = pages.step_of(page)
		if step == null or step.authored_step < 0:
			continue
		var turn: Dictionary = BookletLooks.turn_at(_world, step.authored_in, step.authored_step)
		if turn.is_empty():
			continue
		turned += 1
		var from: Vector3 = pages.view(page)["from"]
		if (from - BookletLooks.direction(turn)).length() > 0.001:
			wrong.append(page)
	_check("the step player, %s: %d of %d pages turned as the designer turned them%s" % [when,
		turned - wrong.size(), turned, (", not %s" % str(wrong.slice(0, 5))) if not wrong.is_empty()
		else ""], (turned > 0 or not need) and wrong.is_empty())


func _until_laid(editor: PageEditor) -> void:
	for _n: int in 600:
		if not bool(editor.page_state().get("laying", false)):
			break
		await process_frame
	await _frames(3)


## The pixels of the outline's orange (booklet_ink's new_colour) in the
## first eight steps' pictures of [param entries] (number -> [entry, page]).
static func _orange(entries: Dictionary) -> int:
	var count: int = 0
	var numbers: Array = entries.keys()
	numbers.sort()
	for number: Variant in numbers.slice(0, 8):
		var entry: Booklet.Entry = entries[number][0]
		var uri: String = entry.image
		var image := Image.new()
		# A page laid out by hand has its pictures clear behind the model, in WebP.
		var read: int = image.load_jpg_from_buffer(Marshalls.base64_to_raw(uri.get_slice(",", 1))) \
			if uri.begins_with("data:image/jpeg;base64,") else (
				image.load_webp_from_buffer(Marshalls.base64_to_raw(uri.get_slice(",", 1)))
				if uri.begins_with("data:image/webp;base64,") else ERR_FILE_UNRECOGNIZED)
		if read != OK:
			continue
		var data: PackedByteArray = image.get_data()
		var channels: int = 4 if image.get_format() == Image.FORMAT_RGBA8 else 3
		for at: int in range(0, data.size() - channels, channels * 2):
			if data[at] > 225 and data[at + 1] > 100 and data[at + 1] < 165 and data[at + 2] < 70:
				count += 1
	return count


static func _mm(rect: Rect2) -> String:
	return "[%.1f, %.1f, %.1f, %.1f]" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


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
	# Headless there are no clicks to give: the commands themselves, there.
	if DisplayServer.get_name() == "headless":
		_shell.change_look("zoom_in", _go(int(picks["zoom"])))
		_shell.change_look("zoom_in", _go(int(picks["zoom"])))
	elif zoom != null and zoom.is_visible_in_tree():
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
	# And the page by hand, on the page step "new" heads: its picture, parts
	# list and number placed, words and a picture of the designer's on it;
	# 30050-1's booklet with the new parts not outlined.
	history = _history()
	var heads: Instructions.Step = _go(int(picks["new"]))
	var placed: Dictionary = {"picture": [120, 40, 130, 120], "parts": [12, 30, 70],
		"number": [12, 14]}
	for item: String in placed:
		_shell.change_look("place", heads, {"item": item, "at": placed[item]})
	_shell.change_look("text", heads, {"text": "Build the wheels first,\nthen the frame",
		"at": [12, 150, 90, 20], "size": 5.0})
	var picture := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.1, 0.45, 0.85, 1.0))
	picture.fill_rect(Rect2i(10, 10, 40, 40), Color(1.0, 0.85, 0.1, 0.0))
	_shell.change_look("image", heads, {"data": Marshalls.raw_to_base64(picture.save_png_to_buffer()),
		"kind": "png", "at": [200, 150, 48, 32]})
	# And an arrow of the designer's, bent, pointing into the picture.
	_shell.change_look("arrow", heads, {"at": [40, 120, 125, 95, 80, 125], "colour": "red",
		"width": 0.9})
	var outlined: bool = name != "30050-1"
	if not outlined:
		_shell.change_look("highlight", heads)
	_check("...and the page by hand, each its own undo step (%d)" % (_history() - history),
		_history() - history == 6 + (0 if outlined else 1))
	# And the callout built on pages of its own: its first step's picture placed.
	var callout_step: Instructions.Step = null
	for one: Instructions.Step in _steps.steps():
		if one.callout_step > 0 and one.authored_step >= 0 and not off.is_empty() \
				and BookletLooks.definition_of(one.authored_in) == off:
			callout_step = one
			break
	if callout_step != null:
		_shell.change_look("place", callout_step, {"item": "picture", "at": [80, 40, 110, 90]})
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
	# A model given the worked-out steps steps every copy of a sub-model as
	# its first, the copy a file writes: reopened, 10016-1's second wheels
	# build as they did before (AuthorSteps._copies_alike).
	_check("...the timeline's steps the same%s (%d, now %d%s)" % [
		", the worked-out steps taken" if adopted else "", timeline.size(), now.size(),
		differ], now == timeline)
	var again: String = _save()
	var drift: Array = _diff(saved, again)
	_check("...and saved again, the same file (%d out, %d in)" % [(drift[0] as Array).size(),
		(drift[1] as Array).size()], again == saved)
	_check("...the file says the page by hand: PLACE, TEXT, IMAGE and its !DATA%s"
		% ("" if outlined else ", HIGHLIGHT OFF"),
		saved.contains("0 !BRICKWORKS PLACE PICTURE 120 40 130 120")
		and saved.contains("0 !BRICKWORKS PLACE PARTS 12 30 70")
		and saved.contains("0 !BRICKWORKS PLACE NUMBER 12 14")
		and saved.contains("0 !BRICKWORKS TEXT 12 150 90 20 5 Build the wheels first,\\nthen the frame")
		and saved.contains("0 !BRICKWORKS IMAGE 200 150 48 32 " + BookletLooks.IMAGE_PREFIX + "1.png")
		and saved.contains("0 !DATA " + BookletLooks.IMAGE_PREFIX + "1.png")
		and saved.contains("0 !BRICKWORKS ARROW RED 0.9 40 120 125 95 80 125")
		and (outlined or saved.contains("0 !BRICKWORKS HIGHLIGHT OFF")))
	_step_player("after the turn, saved and opened again")
	# Laid out without pictures: the page by hand where it was put, and the
	# step alone filling its page.
	var laying := BookletMaker.new()
	laying.library = _library
	_main.add_child(laying)
	var laid: Array[Booklet.Page] = await laying.lay_out_only(_world, _store.scenery, name)
	laying.queue_free()
	var by_number: Dictionary = {}
	for page: Booklet.Page in laid:
		for entry: Booklet.Entry in page.entries:
			if page.kind == "steps":
				by_number[entry.number] = [entry, page]
	var head: Array = by_number.get(int(picks["new"]), [])
	var head_entry: Booklet.Entry = head[0] if not head.is_empty() else null
	_check("...laid out: step %d's picture at %s, parts list at %s, number at %s, %d notes" % [
		int(picks["new"]), _mm(head_entry.rect) if head_entry != null else "?",
		str(head_entry.parts_rect.position) if head_entry != null else "?",
		str(head_entry.number_at) if head_entry != null else "?",
		head_entry.notes.size() if head_entry != null else 0],
		head_entry != null and head_entry.rect.is_equal_approx(Rect2(120, 40, 130, 120))
		and (head_entry.lots.is_empty() or head_entry.parts_rect.position.is_equal_approx(Vector2(12, 30))
			and is_equal_approx(head_entry.parts_width, 70.0))
		and head_entry.number_at.is_equal_approx(Vector2(12, 14)) and head_entry.notes.size() == 2)
	var alone: Array = by_number.get(int(picks["alone"]), [])
	if not alone.is_empty():
		var entry: Booklet.Entry = alone[0]
		var area: Rect2 = Booklet.content()
		var fill: float = maxf(entry.subject.size.x * entry.scale / area.size.x,
			entry.subject.size.y * entry.scale / area.size.y)
		var most: float = Booklet.MOST_SCALE * Booklet.ALONE_MOST * Booklet._grown(entry)
		_check("...step %d alone fills its page: %.0f%% of it across, at %.2f mm an LDU (%.2f the most for a step not alone)"
			% [entry.number, fill * 100.0, entry.scale, Booklet.MOST_SCALE],
			fill > 0.75 or is_equal_approx(entry.scale, most))
	if not _booklets:
		return
	var made: Dictionary = await _booklet("after")
	var pages: Array = made["pages"]
	var document: Booklet.Document = made["document"]
	# The page by hand, as printed: the picture where it was put, the words
	# and the picture on the page, and the new parts outlined or not.
	var drawn_head: Array = (made["entries"] as Dictionary).get(int(picks["new"]), [])
	var html: String = FileAccess.get_file_as_string(_out.path_join("%s_after.html" % name))
	var section: String = ""
	if not drawn_head.is_empty():
		var page_number: int = (drawn_head[1] as Booklet.Page).number
		var from: int = html.find("id=\"page-%d\"" % page_number)
		section = html.substr(from, html.find("</section>", from) - from) if from >= 0 else ""
	# The added picture where it was put, or, where that lies on the model
	# in the step's picture, moved off it and said so.
	var image_moved: bool = not drawn_head.is_empty() and (drawn_head[1] as Booklet.Page).overlaps.any(
		func(one: Dictionary) -> bool: return str(one["item"]) == "image" and bool(one["moved"]))
	_check("the booklet's page %s: step %d's picture at %s, the words and the picture on it%s" % [
		str((drawn_head[1] as Booklet.Page).number) if not drawn_head.is_empty() else "?",
		int(picks["new"]), _mm((drawn_head[0] as Booklet.Entry).rect) if not drawn_head.is_empty() else "?",
		" (moved off the model)" if image_moved else ""],
		not drawn_head.is_empty()
		and (drawn_head[0] as Booklet.Entry).rect.is_equal_approx(Rect2(120, 40, 130, 120))
		and section.contains("--x:120.0;--y:40.0;--w:130.0;--h:120.0")
		and section.contains("Build the wheels first,<br>then the frame")
		and (image_moved or section.contains("--x:200.0;--y:150.0;--w:48.0;--h:32.0"))
		and section.contains("data:image/png;base64,"))
	# The arrow printed on that page, over all, and none in the booklet before
	# any was drawn: a file without arrows prints as it did.
	var before_html: String = FileAccess.get_file_as_string(_out.path_join("%s_before.html" % name))
	_check("...the arrow printed on it (%d drawn on the page), none in the booklet before (%d)" % [
		section.count("class=\"drawn-arrow\""), before_html.count("drawn-arrow")],
		section.count("class=\"drawn-arrow\"") == 1
		and section.contains("d=\"M40.0 120.0 Q77.5 142.5") and before_html.count("drawn-arrow") == 0)
	# The picture placed over the right of the page: the step beside it on
	# its page moved off it, and nothing printed on anything else.
	var said_over := PackedStringArray()
	for page: Booklet.Page in pages:
		if not page.overlaps.is_empty():
			said_over.append("page %d: %s" % [page.number, Booklet.overlaps_said(page)])
	_check("...printed with nothing on anything else (%s); moved off: %s" % [_on_top(pages),
		"; ".join(said_over).left(160) if not said_over.is_empty() else "nothing"],
		_on_top(pages) == "none")
	# A turn sign under the number of every step turned from the one before
	# it, and of no other; the step turned 90° has one.
	var signed: int = 0
	for page: Booklet.Page in document.pages:
		for entry: Booklet.Entry in page.entries:
			signed += int(entry.turned)
	var turn_entry: Array = (made["entries"] as Dictionary).get(int(picks["turn"]), [])
	_check("...a turn sign on each of the %d steps turned from the one before (%d printed), step %d's among them"
		% [signed, html.count("class=\"turn-sign\""), int(picks["turn"])],
		signed == html.count("class=\"turn-sign\"") and not turn_entry.is_empty()
		and (turn_entry[0] as Booklet.Entry).turned)
	var orange_before: int = _orange(before.get("entries", {}))
	var orange_after: int = _orange(made["entries"])
	if outlined:
		_check("...the new parts outlined in orange, before and after (%d and %d pixels)"
			% [orange_before, orange_after], orange_before > 200 and orange_after > 200)
	else:
		_check("...the new parts outlined by default (%d pixels) and not once turned off (%d)"
			% [orange_before, orange_after], orange_before > 200 and orange_after * 5 < orange_before)
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
		if callout_step != null:
			var own_page: String = ""
			for page: Booklet.Page in pages:
				if page.kind == "callout" and page.name == off and own_page.is_empty():
					var from: int = html.find("id=\"page-%d\"" % page.number)
					own_page = html.substr(from, html.find("</section>", from) - from) if from >= 0 else ""
			_check("...its first step's picture printed where it was placed on its own page (%s)"
				% ("at 80, 40" if own_page.contains("--x:80.0;--y:40.0;--w:110.0;--h:90.0") else "not there"),
				own_page.contains("--x:80.0;--y:40.0;--w:110.0;--h:90.0"))
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
