## Find a step by what it places (stepsearch, APP_UX9 #13).
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw \
##     xvfb-run -a -s '-screen 0 1400x900x24' godot --path . --resolution 1280x720 \
##     --script src/dev/stepsearch_probe.gd
##   tools/probe.sh stepsearch_probe
##   tools/probe.sh stepsearch_phone_probe      a phone's, 390 x 844
##
## A builder hunting the step that put on a red 2 x 4 paged through every
## step: no step could be found by what it places, here or in LPub3D or
## Studio's instructions editor. Now a part's number, name or colour typed
## into the timeline's find lists every step that places it, and a click on
## one goes there. Here, as a person does it, real keys and clicks against
## the window:
## - the car (models/car.ldr): a number ("3024"), a number without its letter
##   ("3023" for 3023b), a colour and a number ("red 3024"), a name in the
##   catalogue's words and a builder's ("plate 2 x 4", "2x4 plate"), a colour
##   alone ("black"), and two that nothing answers ("blue 3024", the model's
##   3024s are other colours, and "zzzq"). Each list is the steps worked out
##   here from the bricks themselves, with how many each places; the row of
##   steps marks the same; and every key's list is on screen within 100 ms of
##   the key (ProbeTime: the app's own time, the bar times the load's slack).
##   A click on a listed step shows it, the model built to it; Enter goes to
##   the next found, Shift+Enter back, Escape clears.
## - edit_steps {"find": ...} over MCP, in 1 call each: the same steps, the
##   same counts; refused with another op or nothing to find; and no find,
##   by the window or MCP, changes the model (its saved text, its undo, its
##   steps' being its own).
## - 7140-1, its rear engines a sub-model built four times: a part only in
##   the sub-model is found in the sub-model's own steps, every copy counted,
##   never in the step that puts the engines on.
## - the largest model the probes open (models/orthanc.ldr, 10,119 parts):
##   every key of a number, a name, a colour and both within 100 ms.
## On a phone (stepsearch_phone_probe, or --phone): the car in a phone's
## layout, Find… opening the field in a sheet that stays above the on-screen
## keyboard, each listed step a fingertip tall, a tap on one going there and
## Done leaving its steps marked on the row.
## Pictures in shots/stepsearch/.
extends SceneTree

const CAR := "res://models/car.ldr"
const ENGINES := "res://vendor/omr/files/7140-1.mpd"
const BIG := "res://models/orthanc.ldr"
## The bar: a key's list on screen within this, ms.
const BAR_MS := 100.0

var _failures: int = 0
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _steps: StepsBar
var _library: PartLibrary
var _socket: CommandSocket
var _rpc_id: int = 0
var _phone: bool = false
var _size: String = ""
## Every key timed: [model, words so far, ProbeTime.Span].
var _keys: Array = []


func _initialize() -> void:
	_run.call_deferred()


## Whether to lay the window out for a phone: stepsearch_phone_probe's.
func _on_a_phone_wanted() -> bool:
	return false


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_phone = OS.get_cmdline_user_args().has("--phone") or _on_a_phone_wanted()
	if _phone:
		Phone._on = 1
		Phone._wide = false
		Input.emulate_touch_from_mouse = true
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if _phone and not OS.has_feature("web"):
		# A phone draws at a browser's scale, as open_menu_reach holds it.
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_steps = _main.get("_steps")
	_library = _main.get("_library")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("stepsearch probe at %s, %s" % [_size, "a phone's layout" if Phone.on() else "the desktop's"])
	# The parts' search, made as the app makes it at start.
	for _n: int in 3000:
		if _library.search_ready():
			break
		await process_frame
	if _phone:
		await _on_a_phone()
	else:
		await _car()
		await _engines()
		await _big()
		_report()
	if _failures == 0:
		print("stepsearch probe: all checks passed")
	else:
		print("stepsearch probe: %d checks failed" % _failures)
	_world.clear()
	await _frames(6)
	quit(1 if _failures > 0 else 0)


# -- the car ------------------------------------------------------------------


func _car() -> void:
	await _open(CAR, "car")
	await _timeline_up()
	var steps: Array[Instructions.Step] = _steps.steps()
	print("\n  the car: %d parts in %d steps (%s)" % [_world.brick_count(), steps.size(),
		"the author's" if _steps.mode() == StepsBar.AUTHORS else "worked out"])
	var field: LineEdit = _steps.find_field()
	_check("the timeline has the find, beside its buttons", field != null and field.is_visible_in_tree())
	await _click(field.get_global_rect().get_center())
	_check("...a click on it types in it", field.has_focus())
	var before: Dictionary = _model_now()

	var colours_3024: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3024":
			colours_3024[brick.color_code] = true
	var cases: Array = [
		["3024", ["3024"], -1],
		["3023", ["3023b"], -1],
		["red 3024", ["3024"], 4],
		["plate 2 x 4", ["3020"], -1],
		["2x4 plate", ["3020"], -1],
		["black", [], 0],
	]
	for case: Array in cases:
		await _find_typed("car", str(case[0]), field)
		var wanted: Array = _expected(case[1], int(case[2]))
		var listed: Array = _listed()
		_check("“%s”: %d steps listed, %s, as the bricks say (%s)" % [case[0], listed.size(),
			_said_steps(listed), _said_steps(wanted)], listed == wanted and not wanted.is_empty())
		var marked: Array = (_steps.row_state()["found"] as Array).duplicate()
		marked.sort()
		_check("...the row marks the same steps (%s)" % str(marked),
			marked == wanted.map(func(hit: Array) -> int: return int(hit[0])))
		var heard: String = await _say("edit_steps", {"find": case[0]})
		var over_mcp: Array = _mcp_steps(heard)
		_check("...edit_steps {\"find\": \"%s\"} in 1 call lists the same steps, the same counts (%s)"
			% [case[0], str(over_mcp)], over_mcp == _numbered(listed))
		if case[0] == "red 3024":
			await _shot("red_3024")
			print("    edit_steps: %s" % heard.replace("\n", " / "))

	# Nothing answers.
	await _find_typed("car", "blue 3024", field)
	var said: String = str(_steps.page_state().get("found", "(the timeline is away)"))
	_check("“blue 3024”, where the 3024s are other colours: none listed, and it says in how many (%s)"
		% said, _listed().is_empty() and said == "No step places “blue 3024”: the model has it in %d other colours"
			% colours_3024.size())
	var heard: String = await _say("edit_steps", {"find": "blue 3024"})
	_check("...edit_steps says the same: %s" % heard.get_slice("\n", 1), heard.get_slice("\n", 1)
		== said + ".")
	await _find_typed("car", "zzzq", field)
	said = str(_steps.page_state().get("found", "(the timeline is away)"))
	_check("“zzzq”: none listed, said so (%s), no step marked" % said, _listed().is_empty()
		and said == "No step places “zzzq”" and (_steps.row_state()["found"] as Array).is_empty())
	await _shot("none")

	# Gone to: a click, Enter, Shift+Enter, Escape.
	await _find_typed("car", "3024", field)
	var hits: Array = _listed()
	var chips: Array = _steps.get("_found_chips")
	if _check("“3024” lists more than one step to go between (%d)" % hits.size(), hits.size() >= 2):
		var second: Button = chips[1]
		await _click(second.get_global_rect().get_center())
		await _frames(6)
		var on: int = int(_steps.row_state()["lit"])
		var built: int = int((_steps.page_state()["at"] as Array)[0])
		var end_of: int = int((_steps.get("_step_ends") as Array)[int(hits[1][0])])
		_check("a click on the second listed step (%s) shows it: the timeline on it (%d, place %d), its button lit (%s), the model built to its end (%d of %d bricks)"
			% [second.text, on, int(hits[1][0]), second.button_pressed, built, end_of],
			on == int(hits[1][0]) and second.button_pressed and built == end_of)
		await _click(field.get_global_rect().get_center())
		await _press(KEY_ENTER)
		var after: int = int(hits[2][0]) if hits.size() > 2 else int(hits[0][0])
		_check("Enter goes to the next found (place %d, on %d)" % [after, _steps.row_state()["lit"]],
			_steps.row_state()["lit"] == after and field.has_focus())
		await _press(Keymap.SHIFT | KEY_ENTER)
		_check("Shift+Enter back to the one before (place %d, on %d)" % [int(hits[1][0]),
			_steps.row_state()["lit"]], _steps.row_state()["lit"] == int(hits[1][0]))
		await _press(KEY_RIGHT)
		_check("the arrows move in the words while typing, not the timeline (on %d)"
			% _steps.row_state()["lit"], _steps.row_state()["lit"] == int(hits[1][0]))
	await _press(KEY_ESCAPE)
	_check("Escape clears it: nothing typed, nothing listed or marked, the timeline up and the keys still in the find (%s)"
		% ("up" if _steps.is_playing_back() else "put away"),
		field.text.is_empty() and _listed().is_empty() and not (_steps.get("_found_line") as Control).visible
		and _steps.is_playing_back() and (_steps.row_state()["found"] as Array).is_empty()
		and field.has_focus())

	# Over MCP, refused where it cannot be.
	heard = await _say("edit_steps", {"op": "to", "find": "3024", "bricks": [1], "step": 1})
	_check("edit_steps with find= and another op is refused: %s" % heard, heard.begins_with("find= lists"))
	heard = await _say("edit_steps", {"find": "  "})
	_check("...and with nothing to find: %s" % heard, heard.begins_with("Give find="))
	var now: Dictionary = _model_now()
	_check("no find changed the model: its saved text, its undo (%d, %d) and its steps' being its own"
		% [before["depth"], now["depth"]], now == before)
	# Done, and the timeline opened again: an empty find.
	await _find_typed("car", "3024", field)
	_steps.stop()
	await _frames(4)
	await _timeline_up()
	_check("Done takes the find with it: opened again, nothing typed or listed",
		_steps.find_field().text.is_empty() and _listed().is_empty())


# -- a sub-model's steps --------------------------------------------------------


func _engines() -> void:
	await _open(ENGINES, "7140-1")
	await _timeline_up()
	var steps: Array[Instructions.Step] = _steps.steps()
	# A part, in one colour, that only a sub-model built more than once has.
	var inside: Dictionary = {}       ## "part colour" -> how many in a sub-model's steps
	var outside: Dictionary = {}      ## "part colour" -> true where a step of the model has one
	for step: Instructions.Step in steps:
		var own: bool = not step.in_callout() and not _built_in_place(step)
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			var key: String = "%s %d" % [brick.part_id, brick.color_code]
			if own:
				outside[key] = true
			elif step.times > 1 or _built_in_place(step):
				inside[key] = int(inside.get(key, 0)) + 1
	var pick: String = ""
	for key: String in inside:
		var part: String = key.get_slice(" ", 0)
		if not outside.has(key) and part.is_valid_int() and int(inside[key]) > int(inside.get(pick, 0)):
			pick = key
	print("\n  7140-1: %d parts in %d steps, %d in callouts" % [_world.brick_count(), steps.size(),
		steps.filter(func(step: Instructions.Step) -> bool: return step.in_callout()).size()])
	if not _check("a part only a sub-model built more than once has (%s, %d of them)" % [pick,
			int(inside.get(pick, 0))], not pick.is_empty()):
		return
	var part: String = pick.get_slice(" ", 0)
	var code: int = int(pick.get_slice(" ", 1))
	var colour: String = _library.color(code).name.replace("_", " ").to_lower()
	var asked: String = "%s %s" % [colour, part]
	var field: LineEdit = _steps.find_field()
	await _click(field.get_global_rect().get_center())
	await _find_typed("7140-1", asked, field)
	var listed: Array = _listed()
	var wanted: Array = _expected([part], code)
	var placed: int = 0
	var only_sub: bool = true
	for hit: Array in listed:
		placed += int(hit[1])
		var step: Instructions.Step = steps[int(hit[0])]
		only_sub = only_sub and (step.in_callout() or _built_in_place(step)) and not step.attaches()
	_check("“%s”: the sub-model's own steps, %s, as the bricks say" % [asked, _said_steps(listed)],
		listed == wanted and only_sub)
	_check("...every copy counted: %d placed, %d in the model" % [placed, int(inside[pick])],
		placed == int(inside[pick]))
	var words: Array = _steps.found_steps().map(func(hit: Dictionary) -> String: return str(hit["words"]))
	_check("...each listed with its sub-model and its place in its steps (%s)" % ", ".join(words),
		words.all(func(said: String) -> bool: return said.contains(" · ")))
	var heard: String = await _say("edit_steps", {"find": asked})
	_check("...and edit_steps {\"find\"} the same, each step in the sub-model (%s)"
		% heard.get_slice("\n", 2).strip_edges(), _mcp_steps(heard) == _numbered(listed)
		and heard.get_slice("\n", 2).contains("(in the "))
	await _shot("sub_model")
	await _press(KEY_ESCAPE)


func _built_in_place(step: Instructions.Step) -> bool:
	return step.callout == 0 and step.authored_step >= 0 and not step.authored_in.is_empty()


# -- the largest model -----------------------------------------------------------


func _big() -> void:
	var clock: int = Time.get_ticks_msec()
	await _open(BIG, "orthanc")
	await _timeline_up(1800)
	var steps: Array[Instructions.Step] = _steps.steps()
	print("\n  Orthanc: %d parts in %d steps, up in %.0f s" % [_world.brick_count(), steps.size(),
		(Time.get_ticks_msec() - clock) / 1000.0])
	if not _check("Orthanc's timeline is up", _steps.is_playing_back() and steps.size() > 100):
		return
	# Its commonest part and colour, by the bricks.
	var parts: Dictionary = {}
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			parts[brick.part_id] = int(parts.get(brick.part_id, 0)) + 1
			colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
	var part: String = _most(parts)
	var code: int = int(_most(colours))
	var name: String = _library.parts[part].name.to_lower().strip_edges()
	while name.contains("  "):
		name = name.replace("  ", " ")
	var colour: String = _library.color(code).name.replace("_", " ").to_lower()
	var field: LineEdit = _steps.find_field()
	await _click(field.get_global_rect().get_center())
	for asked: String in [part, name, colour, "%s %s" % [colour, part]]:
		await _find_typed("orthanc", asked, field)
		var listed: Array = _listed()
		var ids: Array = [] if asked == colour else [part]
		var wanted: Array = _expected(ids, code if asked.begins_with(colour) else -1)
		# A name finds every part of that name: its prints too.
		if asked == name:
			_check("“%s”: %d steps listed, among them every one with a %s (%d)" % [asked, listed.size(),
				part, wanted.size()], wanted.all(func(hit: Array) -> bool: return listed.any(
					func(got: Array) -> bool: return int(got[0]) == int(hit[0]))))
		else:
			_check("“%s”: %d steps listed, as the bricks say (%d)" % [asked, listed.size(), wanted.size()],
				listed == wanted)
	await _shot("orthanc")
	await _press(KEY_ESCAPE)


func _most(counts: Dictionary) -> Variant:
	var best: Variant = null
	for key: Variant in counts:
		if best == null or int(counts[key]) > int(counts[best]):
			best = key
	return best


# -- on a phone ----------------------------------------------------------------


func _on_a_phone() -> void:
	await _open(CAR, "car")
	await _timeline_up()
	var open: Control = _steps.controls_by_name().get("steps_find")
	# On a phone held upright (ux15) Find… is in the bar's More: tapped first.
	var more: Control = _steps.controls_by_name().get("steps_more")
	if open != null and not open.is_visible_in_tree() and more != null and more.is_visible_in_tree():
		await _click(_on_screen(more).get_center())
		await _frames(20)
	_check("the timeline has Find… on a phone, not a field under the keyboard (%s)" % (
		(open as Button).text if open is Button else str(open)), open is Button and open.is_visible_in_tree())
	await _click(_on_screen(open).get_center())
	await _frames(10)
	var sheet: AcceptDialog = _steps.get("_find_sheet")
	var field: LineEdit = _steps.find_field()
	_check("...a tap on it opens the find in a sheet, ready to type in", sheet != null and sheet.visible
		and field.has_focus())
	var touch: TouchSizing = _main.get("_touch")
	# The keyboard up, as a browser tells the app of it: 40% of the screen.
	var keys: float = roundf(root.get_visible_rect().size.y / Phone.per_point(root) * 0.4)
	touch.keyboard = keys
	touch.call("_place_all")
	await _frames(12)
	await _find_typed("phone", "red 3024", field)
	var listed: Array = _listed()
	_check("“red 3024” typed lists %s, as the bricks say" % _said_steps(listed),
		listed == _expected(["3024"], 4) and not listed.is_empty())
	var room: Rect2 = touch.room(sheet)
	var at: Rect2 = _in_root(sheet, field)
	_check("...the field above the keyboard (its foot at %d, the keyboard's top at %d)" % [at.end.y,
		room.end.y], at.end.y <= room.end.y + 1.0)
	var chips: Array = _steps.get("_found_chips")
	var chip: Button = chips[0]
	var tall: float = chip.size.y / Phone.per_point(root)
	_check("...each listed step a fingertip tall (%.0f points)" % tall, tall >= Phone.TARGET - 0.5)
	await _shot("phone_sheet")
	touch.keyboard = 0.0
	touch.call("_place_all")
	await _frames(8)
	var target: Rect2 = _in_root(sheet, chip)
	await _click(target.get_center())
	await _frames(6)
	_check("a tap on a listed step (%s) shows it" % chip.text, _steps.row_state()["lit"] == int(listed[0][0]))
	sheet.get_ok_button().pressed.emit()
	await _frames(6)
	_check("Done puts the sheet away, the steps found still marked on the row",
		not sheet.visible and not (_steps.row_state()["found"] as Array).is_empty())
	await _shot("phone_done")


## [param control]'s rect in the root's units, inside the window [param sheet].
func _in_root(sheet: Window, control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	return Rect2(Vector2(sheet.position) + rect.position, rect.size)


# -- what is said ---------------------------------------------------------------


func _report() -> void:
	print("\n  every key, its list on screen (the bar: %d ms, times the load's slack):" % BAR_MS)
	for model: String in ["car", "7140-1", "orthanc"]:
		var spans: Array = []
		var last: Array = []
		for key: Array in _keys:
			if key[0] == model:
				spans.append(key[2])
		if spans.is_empty():
			continue
		var worst: ProbeTime.Span = ProbeTime.slowest(spans)
		var clock: float = 0.0
		var total: float = 0.0
		for span: ProbeTime.Span in spans:
			clock = maxf(clock, span.ms)
			total += span.own
			last.append(span.own)
		print("    %s: %d keys, %.1f ms of its own on average, the slowest %s; on the clock at most %.0f ms"
			% [model, spans.size(), total / spans.size(), worst.said(), clock])
		_check("%s: every key's list on screen within %.0f ms of it (slowest %.0f ms of its own)" % [
			model, BAR_MS * worst.slack(), worst.own], worst.own <= BAR_MS * worst.slack())


# -- helpers ------------------------------------------------------------------


## The model opened from [param path], as Open opens a file.
func _open(path: String, name: String) -> void:
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(FileAccess.get_file_as_string(path), name)
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(20)


func _timeline_up(most_seconds: int = 120) -> void:
	if not _steps.is_playing_back():
		_shell.run("timeline")
	var until: int = Time.get_ticks_msec() + most_seconds * 1000
	while Time.get_ticks_msec() < until:
		if _steps.is_playing_back() and not _steps.is_starting():
			break
		await process_frame
	await _frames(10)


## What the model is: its saved text, its undo and whether its steps are its own.
func _model_now() -> Dictionary:
	return {"text": _store.to_text("car", true), "depth": _builder.history_depth(),
		"own": AuthorSteps.any(_world, _store.scenery)}


## The steps that place one of [param ids] (any part where empty) in [param
## colour] (any where -1), by their place in the timeline's steps, and how
## many each places: worked out here from the bricks themselves.
func _expected(ids: Array, colour: int) -> Array:
	var out: Array = []
	var steps: Array[Instructions.Step] = _steps.steps()
	for index: int in steps.size():
		var count: int = 0
		for brick_id: int in steps[index].brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick != null and (ids.is_empty() or brick.part_id in ids) \
					and (colour < 0 or brick.color_code == colour):
				count += 1
		if count > 0:
			out.append([index, count])
	return out


## What the find lists now: [place, how many] a step.
func _listed() -> Array:
	return _steps.found_steps().map(func(hit: Dictionary) -> Array:
		return [int(hit["index"]), int(hit["count"])])


## [place, count] as [the step's number, its place in a callout, count].
func _numbered(hits: Array) -> Array:
	var steps: Array[Instructions.Step] = _steps.steps()
	return hits.map(func(hit: Array) -> Array:
		return [steps[int(hit[0])].number, int(hit[1])])


## Each step edit_steps' find lists: [its number, how many it places].
func _mcp_steps(said: String) -> Array:
	var out: Array = []
	var number := RegEx.create_from_string("^  (\\d+)[ :]")
	var counts := RegEx.create_from_string("(\\d+) × ")
	for line: String in said.split("\n"):
		var found: RegExMatch = number.search(line)
		if found == null:
			continue
		var count: int = 0
		for each: RegExMatch in counts.search_all(line):
			count += int(each.get_string(1))
		out.append([int(found.get_string(1)), count])
	return out


func _said_steps(hits: Array) -> String:
	var steps: Array[Instructions.Step] = _steps.steps()
	var said := PackedStringArray()
	for hit: Array in hits.slice(0, 12):
		said.append("%d×%d" % [steps[int(hit[0])].number, int(hit[1])])
	if hits.size() > 12:
		said.append("and %d more" % (hits.size() - 12))
	return "steps " + ", ".join(said) if not said.is_empty() else "none"


## [param words] typed into [param field] as a person types them, a key at
## a time, after what was there is cleared with Escape; each key timed to its
## list on screen.
func _find_typed(model: String, words: String, field: LineEdit) -> void:
	if not field.has_focus() or not field.is_editing():
		field.grab_focus()
		field.edit()
		await _frames(2)
	if not field.text.is_empty():
		await _press(KEY_ESCAPE)
	for at: int in words.length():
		var character: String = words[at]
		var down := InputEventKey.new()
		down.keycode = KEY_SPACE if character == " " else OS.find_keycode_from_string(character.to_upper())
		down.physical_keycode = down.keycode
		down.unicode = character.unicode_at(0)
		down.pressed = true
		var span := ProbeTime.Span.new()
		Input.parse_input_event(down)
		# The key is read at the next frame's start, and its list drawn in it.
		await process_frame
		await RenderingServer.frame_post_draw
		span.end()
		var typed: String = words.substr(0, at + 1)
		if field.text != typed:
			_check("typed “%s” into the find (it says “%s”)" % [typed, field.text], false)
			return
		_keys.append([model, typed, span])
		var up: InputEventKey = down.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame
	await _frames(3)


func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


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


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


## A click (or a finger's tap) at [param at], in the root's units.
## Where [param control] is drawn in the window: a sheet's (an embedded
## Window's) controls are placed in the sheet.
func _on_screen(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	var window: Window = control.get_window()
	while window != null and window != root:
		rect.position += Vector2(window.position)
		window = window.get_parent().get_window() if window.get_parent() != null else null
	return rect


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	Input.warp_mouse(move.position)
	Input.parse_input_event(move)
	await _frames(2)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(2)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(named: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("res://shots/stepsearch")
	DirAccess.make_dir_recursive_absolute(folder)
	var image: Image = root.get_texture().get_image()
	image.save_png(folder.path_join("%s_%s.png" % [named, _size]))
