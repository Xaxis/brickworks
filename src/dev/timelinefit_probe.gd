## APP_UX6 unit 2, timelinefit: the timeline, the top bar and the status bar
## inside the window with every panel open, as a person meets them.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1400x900 \
##     --script src/dev/timelinefit_probe.gd
##
## The window is made 1280 x 720, then 1400 x 900, inside Xvfb's screen of the
## header's size, as roomfit_probe makes its sizes. timelinefit_tablet_probe
## is this laid out for a finger in a tablet's 1024 x 768.
##
## The walk found at 1280 x 720, with the bin, Properties (a wheel rim
## selected), Stress's panel and the timeline open, the whole layout wider
## than the window: the timeline's "Step N of M", Instructions and Done past
## its right edge, with the Account button, the right-hand column and the
## status bar's right half; at 1400 x 900 the assistant's column cut in half.
## The bar (docs/APP_UX6.md, the units, row 2), at each size:
##   - with the bin, Properties, Stress's panel, the assistant and the
##     timeline open, every control of the timeline, the top bar (the menus
##     and the toolbar) and the status bar lies inside the window, 0 px past
##     its right edge; and here every column and rail beside the model too;
##   - Done and Instructions answer a click where they are drawn:
##     Instructions asks where the booklet goes (its Save dialog, cancelled
##     here), Done puts the timeline away;
##   - the model's room (Main._model_rect), as much of it as is in the
##     window, is 400 px wide or more.
##
## The sample car, the assistant turned on as Settings does, a wheel rim
## picked out (its properties shown), and the timeline (Build › Timeline),
## Stress (View › Stress) and the columns (by their rails) opened in two
## orders: the bin last, and the assistant last. Everything inside the window
## after each one is opened, and the bar's three at the end. In the second,
## the same in the author's steps, whose rows of step edits and booklet looks
## show too (the rim made a step of its own, New step from selection), undone
## after. And the timeline alone beside the model: its buttons on one line,
## as they always were, where the room has them on one.
## Pictures in shots/timelinefit/<width>x<height>[_tablet]/.
extends SceneTree

const SHOTS := "res://shots/timelinefit/"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1400, 900)]
## The bar's least width of the model's room, in the window's pixels.
const LEAST_ROOM_PX := 400.0
## The longest a run takes, with room to spare (about 3 minutes).
const WATCHDOG := 900.0
## How far a control may stand past an edge and be inside it: rounding.
const SLACK := 0.5
## The timeline's row of buttons, by their names (StepsBar.controls_by_name).
const ROW: Array[String] = ["steps_start", "steps_back", "steps_play", "steps_next", "steps_end",
	"steps_order", "steps_booklet", "steps_done"]

var _failures: int = 0
var _main: Node
var _shell: Shell
var _steps: StepsBar
var _builder: Builder
var _world: BrickWorld
var _bin_dock: SideDock
var _chat: SideDock
var _props: SideDock
var _tablet: bool = false
var _rim: int = 0
var _out: String = ""
var _pointer: Vector2 = Vector2.ZERO


## "tablet" for the script that is this one laid out for a finger
## (timelinefit_tablet_probe); "" here.
func _finger() -> String:
	return ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  timelinefit probe: needs a window")
		quit(1)
		return
	_tablet = _finger() == "tablet"
	if _tablet:
		# The layout for a finger, as a tablet's browser gets it.
		Phone._on = 1
		Phone._wide = true
	await process_frame
	# A script error stops the run without quitting it, holding the GPU.
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("timelinefit: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Godot's own Save dialog, which a probe can see and answer.
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_world") != null and _main.get("_shell") != null:
			break
	if _main.get("_shell") == null:
		print("  timelinefit probe: SKIPPED — the window did not come up")
		quit(3)
		return
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_bin_dock = _main.get("_bin_dock")
	_chat = _main.get("_chat_dock")
	_props = _main.get("_props_dock")

	var placed: int = int(_main.call("_open", "res://models/car.ldr"))
	await _settled()
	_check("the sample car opens (%d parts)" % placed, placed > 50)
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("4624"):
			_rim = brick.id
			break
	_check("a wheel rim in it to pick out (#%d)" % _rim, _rim != 0)
	# As Settings' switch turns it on.
	_main.call("set_assistant", true)
	await _settle()

	var sizes: Array[Vector2i] = SIZES
	if _tablet:
		sizes = [DisplayServer.window_get_size()]
	var table: Array[String] = []
	for size: Vector2i in sizes:
		table.append(await _at(size))
	print("")
	print("  size        arrangement              furthest past the right edge   model's room")
	for line: String in table:
		print(line)
	print("")
	if _failures == 0:
		print("timelinefit: the timeline, the top bar and the status bar inside the window, Done and Instructions answering, the model 400 px or more")
	else:
		print("timelinefit: %d FAILED" % _failures)
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- a size ---------------------------------------------------------------------


func _at(size: Vector2i) -> String:
	if not _tablet:
		root.size = size
		await _frames(40)
		await _settle()
	var got: Vector2i = DisplayServer.window_get_size()
	_out = "%s%dx%d%s/" % [SHOTS, got.x, got.y, "_tablet" if _tablet else ""]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print("")
	print("%d x %d (%.0f x %.0f units, %.3f px a unit, columns \"%s\")%s" % [got.x, got.y,
		root.get_visible_rect().size.x, root.get_visible_rect().size.y, _px(),
		_main.get("_columns"), ", laid out for a tablet" if _tablet else ""])
	if got != size:
		_check("the window is %s, as asked (got %s)" % [size, got], false)
		return "  %dx%d not made" % [size.x, size.y]
	var lines: Array[String] = []
	lines.append(await _alone())
	var orders: Array = [["timeline", "rim", "stress", "parts", "properties", "assistant"],
		["timeline", "rim", "stress", "assistant", "properties", "parts"]] if _tablet \
		else [["timeline", "rim", "stress", "assistant", "bin"],
			["timeline", "rim", "stress", "bin", "assistant"]]
	for n: int in orders.size():
		lines.append(await _arrangement(orders[n], n == orders.size() - 1))
	var out: String = ""
	for line: String in lines:
		out += "  %-10s  %s\n" % ["%dx%d" % [got.x, got.y], line]
	return out.trim_suffix("\n")


## The timeline alone beside the model: everything inside the window, and its
## buttons on one line where the room has them on one, as they always were.
func _alone() -> String:
	print("\n  the timeline alone")
	await _close_all()
	await _open("timeline")
	await _settle()
	var past: Dictionary = _past_the_window()
	var room: Rect2 = _room()
	var lines: int = _row_lines()
	print("    open: %s; the model's room %.0f px wide; the timeline %.0f x %.0f units, its buttons on %d line%s"
		% [_open_now(), room.size.x * _px(), _steps.size.x, _steps.size.y, lines,
		"" if lines == 1 else "s"])
	_check("...everything inside the window (%s)" % _said(past), (past["names"] as Array).is_empty())
	# One line needs the row's least width; where the room is narrower (a
	# tablet's, its buttons a fingertip) two are what fits.
	var one_line: float = _row_least()
	if room.size.x >= one_line + 40.0:
		_check("...its buttons on one line, as they were, in a room with space for one (%d line%s, %.0f wanted of %.0f)"
			% [lines, "" if lines == 1 else "s", one_line, room.size.x], lines == 1)
	else:
		print("    (the room, %.0f units, has no space for one line of %.0f)" % [room.size.x, one_line])
	await _shot("alone")
	return "%-24s %4.0f px                         %4.0f px" % ["the timeline alone",
		float(past["px"]), room.size.x * _px()]


## The panels opened in [param order]'s order, as a person opens them; after
## each, everything inside the window; at the end the bar's three, and in
## [param authored] the same again in the author's steps.
func _arrangement(order: Array, authored: bool) -> String:
	var name: String = "%s_last" % str(order[-1])
	print("\n  %s" % ", then ".join(order))
	await _close_all()
	var worst: float = 0.0
	var worst_after: String = ""
	for what: String in order:
		await _open(what)
		var past: Dictionary = _past_the_window()
		print("    %s opened: open %s; past the window: %s" % [what, _open_now(), _said(past)])
		worst = maxf(worst, float(past["px"]))
		if worst_after.is_empty() and not (past["names"] as Array).is_empty():
			worst_after = what
	await _settle()
	var past: Dictionary = _past_the_window()
	var room: Rect2 = _room()
	var room_px: float = room.size.x * _px()
	print("    all opened: open %s; the model's room %.0f x %.0f units (%.0f px wide)" % [_open_now(),
		room.size.x, room.size.y, room_px])
	_check("...every control of the timeline, the top bar and the status bar, every column and rail, inside the window (%s)"
		% _said(past), (past["names"] as Array).is_empty())
	_check("...and after each one was opened (the furthest past the right edge %.0f px%s)" % [worst,
		"" if worst_after.is_empty() else ", first outside after " + worst_after],
		worst <= SLACK and worst_after.is_empty())
	_check("...the model's room %.0f px wide, %.0f or more" % [room_px, LEAST_ROOM_PX],
		room_px >= LEAST_ROOM_PX)
	await _shot(name)
	if authored:
		await _authors_steps()
	await _press_the_ends()
	return "%-24s %4.0f px                         %4.0f px" % [name.replace("_", " "), worst, room_px]


## The rim made a step of its own, so the timeline shows the author's steps
## with their row of step edits and the booklet's row: everything still
## inside the window; undone after.
func _authors_steps() -> void:
	_builder.clear_selection()
	_builder.select_brick(_rim, false)
	_shell.edit_steps("new")
	await _frames(20)
	if _steps.mode() != StepsBar.AUTHORS:
		_steps.set_mode(StepsBar.AUTHORS)
	await _settle()
	var named: Dictionary = _steps.controls_by_name()
	var edits: Control = named["steps_earlier"]
	var looks: Control = named["booklet_turn_left"]
	var past: Dictionary = _past_the_window()
	print("    the author's steps: the step edits %s, the booklet's row %s; the timeline %.0f x %.0f units"
		% ["shown" if edits.is_visible_in_tree() else "not shown",
		"shown" if looks.is_visible_in_tree() else "not shown", _steps.size.x, _steps.size.y])
	_check("...in the author's steps, its step edits and booklet row shown, all inside the window (%s)"
		% _said(past), _steps.mode() == StepsBar.AUTHORS and edits.is_visible_in_tree()
		and looks.is_visible_in_tree() and (past["names"] as Array).is_empty())
	var room: Rect2 = _room()
	_check("...and the model's room %.0f px wide, %.0f or more" % [room.size.x * _px(), LEAST_ROOM_PX],
		room.size.x * _px() >= LEAST_ROOM_PX)
	await _shot("authors_steps")
	_shell.run("undo")
	await _settled()


## Instructions, then Done, each pressed where it is drawn.
func _press_the_ends() -> void:
	var named: Dictionary = _steps.controls_by_name()
	var booklet: Button = named["steps_booklet"]
	var reached: bool = await _press_on(booklet)
	for _n: int in 120:
		if SaveTo.showing != null:
			break
		await process_frame
	_check("...Instructions, %s where it is drawn, asks where the booklet goes (%s)" % [
		"tapped" if _tablet else "clicked", "its Save dialog" if SaveTo.showing != null
		else ("no dialog" if reached else "not in the window to press")],
		reached and SaveTo.showing != null)
	if SaveTo.showing != null:
		# Put away as a person does, by its Cancel: hidden, then freed.
		SaveTo.showing.get_cancel_button().pressed.emit()
		await _frames(10)
	var done: Button = named["steps_done"]
	reached = await _press_on(done)
	await _frames(10)
	_check("...Done, %s where it is drawn, puts the timeline away (%s)" % [
		"tapped" if _tablet else "clicked", "away" if not _steps.visible
		else ("still up" if reached else "not in the window to press")],
		reached and not _steps.visible)
	if _steps.visible:
		_steps.stop()
		await _frames(6)


# -- opening and closing ------------------------------------------------------------


func _open(what: String) -> void:
	match what:
		"timeline":
			if not _steps.visible:
				_shell.run("timeline")
				for _n: int in 900:
					await process_frame
					if _steps.is_playing_back() and not _steps.is_starting():
						break
		"rim":
			_builder.clear_selection()
			_builder.select_brick(_rim, false)
		"stress":
			if not _shell.stress.panel.is_visible_in_tree():
				_shell.run("stress")
		"bin":
			if not _bin_dock.is_open():
				await _by_rail(_bin_dock, "the bin's")
		"assistant":
			if _tablet:
				var phone: PhoneShell = _main.get("_phone")
				if not _chat.is_open():
					await _press_on(phone.get("_assistant"))
			elif not _chat.is_open():
				await _by_rail(_chat, "the assistant's")
		"parts":
			var phone: PhoneShell = _main.get("_phone")
			(phone.get("_parts") as PhoneShell.Sheet).open("half")
		"properties":
			_shell.run("panel_properties")
	await _settle()


## A column opened by a click on its rail, where the rail is in the window;
## a rail past its edge is said, and the column opened as its command does.
func _by_rail(dock: SideDock, whose: String) -> void:
	var rail: Rect2 = dock.rail().get_global_rect()
	if root.get_visible_rect().grow(SLACK).encloses(rail):
		await _press_at(rail.get_center())
		return
	_check("%s rail inside the window, to be clicked (at %.0f to %.0f of %.0f)" % [whose,
		rail.position.x, rail.end.x, root.get_visible_rect().size.x], false)
	dock.set_open(true)


func _close_all() -> void:
	if _steps.visible:
		_steps.stop()
	if _shell.stress.panel.is_visible_in_tree():
		_shell.run("stress")
	await _settle()
	if _tablet:
		var phone: PhoneShell = _main.get("_phone")
		var parts: PhoneShell.Sheet = phone.get("_parts")
		if parts.is_open():
			parts.close()
	for dock: SideDock in [_chat, _props, _bin_dock]:
		if dock != null and dock.is_open():
			dock.set_open(false, false)
	_builder.clear_selection()
	await _settle()


func _open_now() -> String:
	var open: Array[String] = []
	if _steps.visible:
		open.append("the timeline")
	if not _builder.selection.is_empty():
		open.append("the rim's properties%s" % ("" if _props == null or not _props.is_open()
			else " (their column)"))
	if _shell.stress.panel.is_visible_in_tree():
		open.append("Stress")
	if _bin_dock.is_open():
		open.append("the bin" if not _tablet else "the tree and properties' drawer")
	if _chat.is_open():
		open.append("the assistant")
	if _tablet:
		var phone: PhoneShell = _main.get("_phone")
		if (phone.get("_parts") as PhoneShell.Sheet).is_open():
			open.append("the parts sheet")
	return ", ".join(open) if not open.is_empty() else "nothing"


# -- the measures ------------------------------------------------------------------


## The model's room (Main._model_rect), as much of it as is in the window.
func _room() -> Rect2:
	var room: Rect2 = _main.call("_model_rect")
	return room.intersection(root.get_visible_rect())


## Window pixels to an interface unit.
func _px() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x


## What a person needs to see and press along the window's edges and beside
## the model: the timeline, the top bar, the status bar, and the columns and
## rails. By what they are called here.
func _parts() -> Dictionary:
	var out: Dictionary = {"the timeline": _steps, "the status bar": _shell.status}
	if _tablet:
		var phone: PhoneShell = _main.get("_phone")
		out["the top bar"] = phone.get("_top")
		out["the foot's row"] = phone.get("_row")
	else:
		out["the menus"] = _main.get("_bar")
		out["the toolbar"] = _shell.toolbar
	for pair: Array in [["the bin's column", _bin_dock], ["the properties' column", _props],
			["the assistant's column", _chat]]:
		var dock: SideDock = pair[1]
		if dock == null or not dock.is_visible_in_tree():
			continue
		if dock.rail() != null:
			out[str(pair[0]).replace("column", "rail")] = dock.rail()
		if dock.is_open():
			out[pair[0]] = dock
	var tools: Control = _main.get("_tool_column")
	if tools != null and tools.is_visible_in_tree():
		out["the tools' column (Stress)"] = tools
	return out


## Those of [method _parts] drawn past an edge of the window, by name, and how
## far the furthest of them stands past its right edge, in px.
func _past_the_window() -> Dictionary:
	var screen: Rect2 = root.get_visible_rect()
	var names: Array[String] = []
	var furthest: float = 0.0
	var parts: Dictionary = _parts()
	for part: String in parts:
		var top: Control = parts[part]
		if top == null or not top.is_visible_in_tree():
			continue
		var walk: Array[Node] = [top]
		# A column is judged whole, as a rail is: what scrolls inside it is
		# its own (a long list's rows below its fold are not off the window).
		var whole: bool = part.ends_with("column") or part.ends_with("rail") \
			or part.begins_with("the tools'")
		while not walk.is_empty():
			var node: Node = walk.pop_back()
			var control := node as Control
			if control == null or not control.is_visible_in_tree():
				continue
			if not whole:
				walk.append_array(node.get_children())
			var rect: Rect2 = control.get_global_rect()
			if not rect.has_area():
				continue
			furthest = maxf(furthest, rect.end.x - screen.end.x)
			if not screen.grow(SLACK).encloses(rect):
				names.append("%s's %s" % [part, _name_of(control)])
	return {"names": names, "px": maxf(furthest, 0.0) * _px()}


static func _name_of(control: Control) -> String:
	if control is Button and not (control as Button).text.is_empty():
		return "\"%s\"" % (control as Button).text
	if control is Label and not (control as Label).text.is_empty():
		return "\"%s\"" % (control as Label).text.left(30)
	return control.get_class() if control.name.begins_with("@") else str(control.name)


func _said(past: Dictionary) -> String:
	var names: Array = past["names"]
	if names.is_empty():
		return "nothing past it"
	var shown: Array = names.slice(0, 6)
	return "%.0f px past the right edge: %s%s" % [float(past["px"]), ", ".join(shown),
		" and %d more" % (names.size() - shown.size()) if names.size() > shown.size() else ""]


## How many lines the timeline's buttons lie on: their middles, a pixel or two
## apart on one line, a line's height apart on the next.
func _row_lines() -> int:
	var named: Dictionary = _steps.controls_by_name()
	var middles: Array[float] = []
	for key: String in ROW:
		var control: Control = named.get(key)
		if control != null and control.is_visible_in_tree():
			middles.append(control.get_global_rect().get_center().y)
	middles.sort()
	var lines: int = 0 if middles.is_empty() else 1
	for n: int in range(1, middles.size()):
		if middles[n] - middles[n - 1] > 8.0:
			lines += 1
	return lines


## The width the timeline's row of buttons takes on one line: each button's
## least width and the gaps between, and the bar's margins.
func _row_least() -> float:
	var named: Dictionary = _steps.controls_by_name()
	var start: Control = named["steps_start"]
	var row: Node = start.get_parent()
	var wide: float = 0.0
	var count: int = 0
	for child: Node in row.get_children():
		var control := child as Control
		if control != null and control.visible:
			wide += control.get_combined_minimum_size().x
			count += 1
	return wide + 6.0 * maxf(count - 1, 0) + 24.0


# -- hands and the window -------------------------------------------------------


func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


## [param control] pressed where a person sees it: the middle of what of it is
## in the window. False, and nothing pressed, where less than a sliver of it
## is: a press off the screen reaches a control as well as one on it, which no
## hand can make.
func _press_on(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var seen: Rect2 = control.get_global_rect().intersection(root.get_visible_rect())
	if seen.size.x < 8.0 or seen.size.y < 8.0:
		return false
	await _press_at(seen.get_center())
	return true


## A click where [param at] is, or laid out for a finger a tap.
func _press_at(at: Vector2) -> void:
	if _tablet:
		var whole: Vector2 = _as_event(at).floor()
		for down: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = down
			touch.position = whole
			Input.parse_input_event(touch)
			await _frames(3)
		await _frames(8)
		return
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _pointer
	_pointer = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		if down:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(8)


## Until the world has drawn everything waiting to be drawn.
func _settled() -> void:
	for _n: int in 600:
		await process_frame
		if (_world.get("_dirty") as Dictionary).is_empty() and not bool(_world.get("_rebuild_queued")):
			break
	await _frames(3)


func _settle() -> void:
	await create_timer(SideDock.SLIDE_SECONDS * 2.0 + 0.3).timeout
	await _frames(6)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	image.save_png(path)
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
