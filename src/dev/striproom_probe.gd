## APP_UX5 unit 11, striproom: Cut away's strip inside the model's room,
## every button on it in sight and reachable, as a person meets it.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1280x720 \
##     --script src/dev/striproom_probe.gd
##
## Run at 1400 x 900 too (PROBE_SIZE=1400x900 tools/probe.sh striproom), and
## laid out for a finger by striproom_phone_probe (390 x 844) and
## striproom_tablet_probe (1024 x 768).
##
## The bar (docs/APP_UX5.md, the units, row 11): the strip inside the
## model's room, every button in sight and reachable, at 1280 x 720 and
## 1400 x 900 with Stress, the bin and the assistant open; it wraps, or
## narrows, as the render queue does. The walk found it ran past the room
## with those open: at 1400 x 900 its Ghost cut in half and its × under the
## assistant's column; at 1280 x 720 the × half under the right-hand
## column's edge.
##
## The sample car, cut by a plane, a box, a sphere and a cylinder in turn,
## with the columns beside the model opened as a person opens them (the
## bin's rail and the assistant's clicked, Stress from the View menu's
## command), in four arrangements: Stress, the assistant, then the bin;
## Stress, the bin, then the assistant; the bin and the assistant without
## Stress; and nothing open beside the model. For each cut:
##   - every control the strip shows lies inside the model's room
##     (Main._model_rect) and the window, over none of the columns or their
##     rails, and clear of the key strip and the timeline along the foot;
##   - every one of them does what it is for when clicked where it is drawn
##     (a tap, laid out for a finger): the shape's list opens, X, Y and Z
##     cut along their axis, the slider moves the plane, Flip turns it,
##     Shrink and Grow change the shape a plate, Ghost leaves the ghosts and
##     takes them away, and × puts the model back;
##   - where the room has the strip on one line, it is on one line, as wide
##     as it always was.
## Laid out for a finger, the arrangements are the phone's and the tablet's
## own (the model alone; Stress; on a tablet, the parts beside the model),
## and every button is a fingertip each way.
##
## Pictures in shots/striproom/<width>x<height>[_phone|_tablet]/.
extends SceneTree

const SHOTS := "res://shots/striproom/"
const PLANE := 0
const BOX := 1
const SPHERE := 2
const CYLINDER := 3
const SHAPE_NAMES: Array[String] = ["a plane", "a box", "a sphere", "a cylinder"]
## The command a person chooses each by (View › Cut away by).
const COMMANDS: Array[String] = ["cut_y", "cut_box", "cut_sphere", "cut_cylinder"]
## How far a control may stand past an edge and be inside it: rounding.
const SLACK := 0.5

var _failures: int = 0
var _main: Node
var _shell: Shell
var _see: SeeInside
var _world: BrickWorld
var _camera: CadCamera
var _bin_dock: SideDock
var _chat: SideDock
var _phone: bool = false
var _out: String = ""
var _pointer: Vector2 = Vector2.ZERO
## The pictures to keep: "arrangement/shape" names.
var _pictured: Dictionary = {}


## "phone" or "tablet" for a script that is this one laid out for a finger
## (striproom_phone_probe, striproom_tablet_probe); "" here.
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
		print("  striproom probe: needs a window")
		quit(1)
		return
	_phone = _finger() != ""
	if _phone:
		# The layout for a finger, as a phone's or a tablet's browser gets it.
		Phone._on = 1
		Phone._wide = _finger() == "tablet"
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	_out = "%s%dx%d%s/" % [SHOTS, window.x, window.y, ("_" + _finger()) if _phone else ""]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_world") != null and _main.get("_shell") != null:
			break
	if _main.get("_shell") == null:
		print("  striproom probe: SKIPPED — the window did not come up")
		quit(3)
		return
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_see = _shell.see_inside
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_bin_dock = _main.get("_bin_dock")
	_chat = _main.get("_chat_dock")
	print("  a %d x %d window, %.0f units across%s" % [window.x, window.y,
		root.get_visible_rect().size.x, (", laid out for a " + _finger()) if _phone else ""])

	var placed: int = int(_main.call("_open", "res://models/car.ldr"))
	await _settled()
	_check("the sample car opens (%d parts)" % placed, placed > 50)
	_camera.look_from(Vector3(-0.45, 1.05, 1.0))
	_camera.frame(_main.call("_built_bounds"))
	await _frames(30)

	if _phone:
		_pictured = {"alone/a plane": true, "alone/a box": true, "stress/a plane": true,
			"stress/a box": true, "parts/a plane": true, "parts/a box": true}
		await _arrangement("alone", [])
		await _arrangement("stress", ["stress"])
		if _finger() == "tablet":
			await _arrangement("parts", ["parts"])
	else:
		# As the assistant is offered: Settings' switch, its column then
		# opened by its tab.
		_main.call("set_assistant", true)
		await _settle()
		_pictured = {"stress_assistant_bin/a plane": true, "stress_assistant_bin/a box": true,
			"stress_bin_assistant/a box": true, "bin_assistant/a plane": true,
			"nothing/a plane": true, "nothing/a box": true}
		await _arrangement("stress_assistant_bin", ["stress", "assistant", "bin"])
		await _arrangement("stress_bin_assistant", ["stress", "bin", "assistant"])
		await _arrangement("bin_assistant", ["bin", "assistant"])
		await _arrangement("nothing", [])

	print("")
	if _failures == 0:
		print("striproom: Cut away's strip lies in the model's room, every button on it in sight and doing what it says")
	else:
		print("striproom: %d FAILED" % _failures)
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the arrangements -------------------------------------------------------------


## The columns beside the model opened in [param opens]'s order, as a person
## opens them, then every cut tried in that room; all put away after.
func _arrangement(name: String, opens: Array) -> void:
	print("\n  %s" % name.replace("_", ", "))
	await _close_all()
	for what: String in opens:
		await _open(what)
	await _settle()
	var room: Rect2 = _main.call("_model_rect")
	print("    open: %s; the model's room %.0f x %.0f at %.0f, %.0f" % [_open_now(), room.size.x,
		room.size.y, room.position.x, room.position.y])
	if "stress" in opens:
		_check("...Stress's panel shown beside the model", _shell.stress.panel.is_visible_in_tree())
	for kind: int in [PLANE, BOX, SPHERE, CYLINDER]:
		await _cut(name, kind)
	await _close_all()


func _open(what: String) -> void:
	match what:
		"stress":
			if not _shell.stress.panel.is_visible_in_tree():
				_shell.run("stress")
		"bin":
			if not _bin_dock.is_open():
				await _press_at(_bin_dock.rail().get_global_rect().get_center())
		"assistant":
			if not _chat.is_open():
				await _press_at(_chat.rail().get_global_rect().get_center())
		"parts":
			var phone: PhoneShell = _main.get("_phone")
			(phone.get("_parts") as PhoneShell.Sheet).open("half")
	await _settle()


func _close_all() -> void:
	if _see.cutting:
		_see.set_cut(false)
	if _shell.stress.panel.is_visible_in_tree():
		_shell.run("stress")
		await _settle()
	if _phone:
		var phone: PhoneShell = _main.get("_phone")
		var parts: PhoneShell.Sheet = phone.get("_parts")
		if parts.is_open():
			parts.close()
	for dock: SideDock in [_chat, _bin_dock]:
		if dock.is_open():
			dock.set_open(false, false)
	await _settle()


func _open_now() -> String:
	var open: Array[String] = []
	if _shell.stress.panel.is_visible_in_tree():
		open.append("Stress")
	if _bin_dock.is_open():
		open.append("the bin")
	if _chat.is_open():
		open.append("the assistant")
	if _phone:
		var phone: PhoneShell = _main.get("_phone")
		if (phone.get("_parts") as PhoneShell.Sheet).is_open():
			open.append("the parts sheet")
	return ", ".join(open) if not open.is_empty() else "nothing beside the model"


# -- a cut --------------------------------------------------------------------------


## The car cut by [param kind] in the room as it is: where its strip lies,
## then each of its controls pressed where it is drawn.
func _cut(arrangement: String, kind: int) -> void:
	var what: String = SHAPE_NAMES[kind]
	_shell.run(COMMANDS[kind])
	await _settled()
	await _frames(8)
	_check("%s: View › Cut away by cuts the car by %s" % [arrangement, what], _see.cutting
		and _see.shape == kind and _see.bar.is_visible_in_tree())
	if not _see.bar.is_visible_in_tree():
		return
	var room: Rect2 = _main.call("_model_rect")
	var screen: Rect2 = root.get_visible_rect()
	var strip: Rect2 = _see.bar.get_global_rect()
	var shown: Dictionary = _shown_controls()
	var lines: int = _lines()
	print("    %s: the strip %.0f x %.0f at %.0f, %.0f, %d line%s, in a room %.0f wide" % [what,
		strip.size.x, strip.size.y, strip.position.x, strip.position.y, lines,
		"" if lines == 1 else "s", room.size.x])
	var out_of_room: Array[String] = []
	var off_screen: Array[String] = []
	var under: Array[String] = []
	var columns: Dictionary = _columns()
	for name: String in shown:
		var rect: Rect2 = (shown[name] as Control).get_global_rect()
		if not room.grow(SLACK).encloses(rect):
			out_of_room.append(name)
		if not screen.grow(SLACK).encloses(rect):
			off_screen.append(name)
		for column: String in columns:
			if (columns[column] as Rect2).grow(-SLACK).intersects(rect):
				under.append("%s under %s" % [name, column])
	_check("...every control on its strip inside the model's room (%s)" % (
		"all %d" % shown.size() if out_of_room.is_empty() else "not " + ", ".join(out_of_room)),
		out_of_room.is_empty())
	_check("...and in the window (%s)" % ("all" if off_screen.is_empty()
		else "not " + ", ".join(off_screen)), off_screen.is_empty())
	_check("...over none of the columns beside the model, nor their rails (%s)" % (
		"none" if under.is_empty() else ", ".join(under)), under.is_empty())
	var foot: Array[String] = []
	for below: Control in _see.below:
		if below != null and below.is_visible_in_tree() \
				and below.get_global_rect().grow(-SLACK).intersects(strip):
			foot.append(below.name)
	_check("...clear of the key strip and the timeline along the room's foot (%s)" % (
		"clear" if foot.is_empty() else "over " + ", ".join(foot)), foot.is_empty())
	if _phone:
		# What the phone's layout lays over the model: the line saying what
		# was just done (or what a finger does), and the button that fits
		# the view. Drawn over the strip, they hid its slider and Grow.
		var phone: PhoneShell = _main.get("_phone")
		var over: Array[String] = []
		for pair: Array in [["the hint line", phone.get("_pill")], ["Fit", phone.get("_fit")]]:
			var laid: Control = pair[1]
			if laid != null and laid.is_visible_in_tree() \
					and laid.get_global_rect().grow(-SLACK).intersects(strip):
				over.append(str(pair[0]))
		_check("...nothing of the phone's laid over it (%s)" % ("nothing" if over.is_empty()
			else ", ".join(over)), over.is_empty())
		var finger: float = Phone.px(root, Phone.TARGET)
		var small: Array[String] = []
		for name: String in shown:
			var control: Control = shown[name]
			if TouchSizing.takes(control) and (control.size.x < finger - SLACK
					or control.size.y < finger - SLACK):
				small.append("%s %.0f x %.0f" % [name, control.size.x, control.size.y])
		_check("...every button a fingertip each way, %.0f units (%s)" % [finger,
			"all" if small.is_empty() else ", ".join(small)], small.is_empty())
	elif arrangement == "nothing":
		# Where the room has it on one line, it is on one line, as wide as
		# the strip always was.
		_check("...on one line where the room has it, as it was (%d line%s, %.0f wide)" % [
			lines, "" if lines == 1 else "s", strip.size.x], lines == 1)
	if _pictured.has("%s/%s" % [arrangement, what]):
		await _shot("%s_%s" % [arrangement, what.trim_prefix("a ")])
	await _press_each(arrangement, kind)


## Each of the strip's controls pressed where it is drawn, and what it is
## for seen done; × last, which puts the model back.
func _press_each(arrangement: String, kind: int) -> void:
	var missed: Array[String] = []
	var named: Dictionary = _see.controls_by_name()
	# The list of what the cut is by opens.
	var choice: OptionButton = named["cut_shape"]
	await _press_on(choice)
	var popup: PopupMenu = choice.get_popup()
	if not popup.visible:
		missed.append("the shape's list")
	popup.hide()
	await _frames(6)
	if kind == PLANE:
		for n: int in 3:
			var axis: Button = named["cut_" + SeeInside.AXES[n].to_lower()]
			if not await _press_on(axis) or _see.axis != n or not _see.cutting or _see.shape != PLANE:
				missed.append(SeeInside.AXES[n])
		var slider: HSlider = named["cut_slider"]
		var was: float = _see.at
		var track: Rect2 = slider.get_global_rect().intersection(root.get_visible_rect())
		# A quarter along from whichever end the plane is not at, of what of
		# it is in the window.
		var ratio: float = 0.25 if slider.get_as_ratio() > 0.5 else 0.75
		if track.size.x >= 8.0:
			await _press_at(Vector2(track.position.x + track.size.x * ratio, track.get_center().y))
		if absf(_see.at - was) < 1.0:
			missed.append("the slider (at %.0f, was %.0f)" % [_see.at, was])
		var side: bool = _see.cuts_positive
		var flip: Control = named.get("cut_flip", _strip_button("Flip"))
		if flip == null:
			missed.append("Flip (not found)")
		elif not await _press_on(flip) or _see.cuts_positive == side:
			missed.append("Flip")
	else:
		for way: int in [-1, 1]:
			var button: Button = named["cut_shrink" if way < 0 else "cut_grow"]
			var before: float = _volume(_see.room)
			await _press_on(button)
			var after: float = _volume(_see.room)
			if (after - before) * way <= 0.0:
				missed.append("%s (%.0f to %.0f)" % ["Shrink" if way < 0 else "Grow", before, after])
	var ghost: CheckBox = named["cut_ghosts"]
	# Ghost is kept between cuts: one press missed in an arrangement before
	# would leave it on, and every press after would read backwards.
	_see.set_ghosts(false)
	for on: bool in [true, false]:
		if not await _press_on(ghost) or _see.leaves_ghosts != on:
			missed.append("Ghost %s" % ("on" if on else "off"))
	var close: Control = named.get("cut_close", _strip_button("×"))
	if close == null:
		missed.append("× (not found)")
	else:
		await _press_on(close)
		await _settled()
		if _see.cutting:
			missed.append("×")
	_check("...each control %s where it is drawn does what it is for (%s)" % [
		"tapped" if _phone else "clicked", "all" if missed.is_empty()
		else "not " + ", ".join(missed)], missed.is_empty())
	if _see.cutting:
		_see.set_cut(false)
		await _settled()


## What the strip shows, by name: its buttons, its slider and its words.
func _shown_controls() -> Dictionary:
	var out: Dictionary = {}
	var walk: Array[Node] = [_see.bar]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		walk.append_array(node.get_children())
		var control := node as Control
		if control == null or control == _see.bar or not control.is_visible_in_tree() \
				or control is Container:
			continue
		var name: String = control.name
		if control is OptionButton:
			name = "the shape's list"
		elif control is Button and not (control as Button).text.is_empty():
			name = (control as Button).text
		elif control is Slider:
			name = "the slider"
		elif control is Label:
			name = "\"%s\"" % (control as Label).text
		out[name] = control
	return out


## The strip's button that reads [param words], for a Brickworks whose
## strip does not name it.
func _strip_button(words: String) -> Button:
	var walk: Array[Node] = [_see.bar]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		walk.append_array(node.get_children())
		if node is Button and (node as Button).text == words:
			return node as Button
	return null


## How many lines the strip's controls lie on: their middles, which on one
## line are a pixel or two apart at most, a line's height apart on the next.
func _lines() -> int:
	var middles: Array[float] = []
	for control: Control in _shown_controls().values():
		middles.append(control.get_global_rect().get_center().y)
	middles.sort()
	var lines: int = 0 if middles.is_empty() else 1
	for n: int in range(1, middles.size()):
		if middles[n] - middles[n - 1] > 8.0:
			lines += 1
	return lines


## The columns beside the model and their rails, where shown.
func _columns() -> Dictionary:
	var out: Dictionary = {}
	var props: SideDock = _main.get("_props_dock")
	for pair: Array in [["the bin", _bin_dock], ["the assistant", _chat],
			["the properties", props]]:
		var dock: SideDock = pair[1]
		if dock == null or not dock.is_visible_in_tree():
			continue
		if dock.rail() != null and dock.rail().is_visible_in_tree():
			out[str(pair[0]) + "'s rail"] = dock.rail().get_global_rect()
		# A drawer, on a phone or a tablet, lies over the model while it is
		# open and is put away to build: its rail is beside the model.
		if dock.is_open() and _main.get("_columns") != "drawers":
			out[pair[0]] = dock.get_global_rect()
	var tools: Control = _main.get("_tool_column")
	if tools != null and tools.is_visible_in_tree():
		out["the tools' column (Stress)"] = tools.get_global_rect()
	return out


static func _volume(box: AABB) -> float:
	return box.size.x * box.size.y * box.size.z


# -- hands and the window -------------------------------------------------------


func _as_event(at: Vector2) -> Vector2:
	return at * (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)


## [param control] pressed where a person sees it: the middle of what of it
## is in the window. False, and nothing pressed, where less than a sliver
## of it is: a press off the screen reaches a control as well as one on it,
## which no hand can make.
func _press_on(control: Control) -> bool:
	var seen: Rect2 = control.get_global_rect().intersection(root.get_visible_rect())
	if seen.size.x < 8.0 or seen.size.y < 8.0:
		return false
	await _press_at(seen.get_center())
	return true


## A click where [param at] is, or laid out for a finger a tap.
func _press_at(at: Vector2) -> void:
	if _phone:
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
