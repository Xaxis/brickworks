## Does the pointer say what the mouse will do, and what it is doing?
##
##   godot --path . --resolution 1400x900 --script src/dev/cursor_probe.gd
##
## Asked for by the owner: "the app's cursor should change based on which
## function is being performed." Each state is reached the way a hand
## reaches it — events through Input, so the camera's and the box's own
## watch over the buttons sees them — and then the shape the window was
## actually given is read back from the display server, not from the
## code that asked for it. A cursor the app chose and the window never
## showed is the bug this is for.
##
## Needs a window, because a headless display server has no cursor: it
## answers "arrow" to everything. And a virtual one, because it moves the
## system's pointer (see [method _move_to]):
##
##   xvfb-run -a --server-args="-screen 0 1400x900x24" \
##     godot --path . --resolution 1400x900 --script src/dev/cursor_probe.gd
##
## On a desktop it leaves the pointer alone and says so, and the checks
## that need the pointer where the probe points will fail rather than
## take somebody's mouse away from them.
##
## And after every gesture, the way back. A cursor that does not return
## is a stale cursor, and those are the ones people notice: the arrow of
## a dialog that has gone, a turn that ended outside the window, Escape.
##
## Leaves pictures in shots/cursors/: every cursor at 1x and 2x with its
## hotspot marked, the controls strip, and the controls panel. Look at
## them.
extends SceneTree

var _failures: int = 0
var _finished: bool = false
var _main: Node
var _world: BrickWorld
var _camera: CadCamera
var _builder: Builder
var _cursors: Cursors
var _middle: Vector2
var _out: String = ""
## Where the last event put the pointer, in the window's coordinates, so
## a drag's motion can say how far it moved.
var _pointer: Vector2 = Vector2.ZERO
## Whether this is a screen nobody is looking at, so the system's pointer
## is the probe's to move. xvfb-run keeps its authority file in a
## directory of its own name.
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Counted in frames, and a window nothing is looking at gets one a
	# second on this machine.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_out = ProjectSettings.globalize_path("res://shots/cursors")
	DirAccess.make_dir_recursive_absolute(_out)
	# Headless, every shape read back is the arrow, and that was 107
	# failures that looked like a broken merge (2026-10-12). One says why.
	if DisplayServer.get_name() == "headless":
		print("  a headless display server has no cursor: it answers \"arrow\" to")
		print("  everything. Run this in a window, on Xvfb as tools/check.sh does:")
		print("    xvfb-run -a --server-args=\"-screen 0 1400x900x24\" \\")
		print("      godot --path . --resolution 1400x900 --script src/dev/cursor_probe.gd")
		_check("there is a window to read the pointer back from", false)
		_finish()
		return
	if not _virtual:
		print("  not on Xvfb, so the system pointer is left where it is;")
		print("  the checks that replay a motion where it stands will fail")

	print("  the pictures")
	_pictures()

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_builder = _main.get("_builder")
	_cursors = _main.get("_cursors")
	if _cursors == null:
		_check("the app has a pointer to put in states", false)
		_finish()
		return
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()

	# Something to point at, in the middle of the view.
	var store: ModelStore = _main.get("_store")
	_world.clear()
	_builder.lattice.clear()
	store.scenery.clear()
	for n: int in 6:
		var at := Transform3D(Basis.IDENTITY, Vector3(n * 40.0, 24.0, 0.0))
		var brick_id: int = _world.add_brick("3001", 4, at)
		_builder.register(brick_id, "3001", at)
	# The middle of the model's part of the window, where the view is
	# centred (CadCamera.seen), not the window's.
	_middle = ((_main.call("model_cover") as Dictionary)["view"] as Rect2).get_center()
	_builder.held_part = "3005"
	var library: PartLibrary = _main.get("_library")
	for _n: int in 2400:
		if library.mesh_for("3001") != null and library.mesh_for("3005") != null:
			break
		await process_frame

	await _settle()
	print("")
	print("  over the model")
	await _over_the_model()
	print("")
	print("  dragging")
	await _dragging()
	print("")
	print("  the wheel and the keys")
	await _wheel_and_keys()
	print("")
	print("  over the panels")
	await _over_the_panels()
	print("")
	print("  the wheel over the interface")
	await _wheel_over_the_interface()
	print("")
	print("  the way back")
	await _the_way_back()
	print("")
	print("  the tools, the keys held, and what is under the pointer")
	await _tools_and_contexts()
	print("")
	print("  buttons pressed with the view tools on and the keys held")
	await _buttons_while_the_view_is_lent()
	print("")
	print("  the controls list")
	await _the_list()
	_finish()


func _finish() -> void:
	print("")
	if _failures == 0:
		print("the pointer says what the mouse will do, and what it is doing")
	else:
		print("%d FAILURE(S)" % _failures)
	_finished = true
	quit(1 if _failures else 0)


## The app quitting part way through ends the probe with exit code 0 and
## every check after it unrun, which reads as a pass.
func _finalize() -> void:
	if not _finished:
		print("  FAIL the app quit before the probe finished")


# -- the pictures --------------------------------------------------------------


## Every cursor drawn at 1x and 2x, the size it should be, with its
## hotspot on something that is drawn — a hotspot in an empty corner is
## a pointer that clicks somewhere other than where it points.
func _pictures() -> void:
	var sheet := Image.create(4 * 80, Cursors.HOTSPOTS.size() * 80, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.42, 0.44, 0.47))
	var row: int = 0
	for state: String in Cursors.HOTSPOTS:
		var path: String = Icons.CURSORS + state + ".svg"
		var column: int = 0
		for scale: float in [1.0, 2.0]:
			var picture: Image = Icons.image(path, scale)
			var wants: int = int(32 * scale)
			_check("%s is drawn at %dx, %s" % [state, int(scale),
				"missing" if picture == null else "%dx%d" % [picture.get_width(), picture.get_height()]],
				picture != null and picture.get_width() == wants and picture.get_height() == wants)
			if picture == null:
				continue
			var hotspot: Vector2i = Vector2i((Cursors.HOTSPOTS[state] as Vector2 * scale).floor())
			_check("...its hotspot %s is on the picture" % hotspot,
				_drawn_near(picture, hotspot, int(2 * scale)))
			for ground: Color in [Color(0.10, 0.11, 0.13), Color(0.85, 0.86, 0.88)]:
				var cell := Image.create(80, 80, false, Image.FORMAT_RGBA8)
				cell.fill(ground)
				var shown: Image = picture.duplicate()
				var mark: Vector2i = hotspot
				if scale == 1.0:
					shown.resize(64, 64, Image.INTERPOLATE_NEAREST)
					mark *= 2
				cell.blend_rect(shown, Rect2i(Vector2i.ZERO, shown.get_size()), Vector2i(8, 8))
				# The hotspot, in red, so the sheet shows where it points.
				for dx: int in range(-1, 2):
					for dy: int in range(-1, 2):
						var at: Vector2i = mark + Vector2i(8 + dx, 8 + dy)
						if Rect2i(0, 0, 80, 80).has_point(at):
							cell.set_pixelv(at, Color(1, 0.1, 0.1))
				sheet.blit_rect(cell, Rect2i(0, 0, 80, 80), Vector2i(column * 80, row * 80))
				column += 1
		row += 1
	sheet.save_png(_out + "/cursor_sheet.png")
	print("  wrote %s/cursor_sheet.png" % _out)


func _drawn_near(picture: Image, at: Vector2i, reach: int) -> bool:
	for dx: int in range(-reach, reach + 1):
		for dy: int in range(-reach, reach + 1):
			var here: Vector2i = at + Vector2i(dx, dy)
			if here.x < 0 or here.y < 0 or here.x >= picture.get_width() \
					or here.y >= picture.get_height():
				continue
			if picture.get_pixelv(here).a > 0.5:
				return true
	return false


# -- states ----------------------------------------------------------------------


func _over_the_model() -> void:
	# Select is where the app rests: over a part, the pointer says a
	# click takes it.
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.set_mode("select")
	await _move_to(_middle)
	await _expect("nothing in hand, over a part", "select")
	await _key_down(KEY_Q, true)
	await _key_down(KEY_Q, false)
	await _move_to(_middle)
	await _expect("a part in hand (Q) over the model", "place")

	# The right button is for looking: down and let go, it lets go of the
	# part in hand and takes nothing off.
	var before: int = _world.brick_count()
	_press(MOUSE_BUTTON_RIGHT, _middle, true)
	await _expect("the right button down over a brick", "place")
	_press(MOUSE_BUTTON_RIGHT, _middle, false)
	await _frames(4)
	_check("...and letting go took nothing off, %d -> %d, and let go of the part"
		% [before, _world.brick_count()], _world.brick_count() == before
		and verbs.mode == "select")
	await _settle()
	await _expect("...and then the pointer is back to selecting", "select")
	await _key_down(KEY_Q, true)
	await _key_down(KEY_Q, false)

	# Shift over a brick: a click picks it out instead.
	await _key_down(KEY_SHIFT, true)
	await _move_to(_middle)
	await _expect("shift over a brick, with a part in hand: a drag slides", "hand")
	await _key_down(KEY_SHIFT, false)
	await _move_to(_middle)
	await _expect("...and let go of", "place")

	# A part that has not arrived: a click would do nothing yet. Made to
	# be on its way the way the library marks one, not by asking the
	# cursor for "busy".
	var library: PartLibrary = _main.get("_library")
	var waiting := PartLibrary.PartInfo.new()
	waiting.id = "probe-in-flight"
	waiting.mesh_hash = "probe-in-flight-geometry"
	library.parts[waiting.id] = waiting
	library._fetching[waiting.mesh_hash] = [waiting.id]
	var held: String = _builder.held_part
	_builder.held_part = waiting.id
	await _move_to(_middle)
	await _expect("a part still on its way", "busy")
	library._fetching.erase(waiting.mesh_hash)
	library.parts.erase(waiting.id)
	_builder.held_part = held
	await _move_to(_middle)
	await _expect("...and once it is not", "place")

	# Nowhere legal to put it. The builder settles every part on top of
	# whatever is under it, so a real collision is hard to stand up from
	# here; the choice is checked as a rule, and the shape it maps to by
	# showing it and reading the window back — with the app's own
	# per-frame choice held off for those frames, or it puts "place"
	# straight back before the window has drawn anything.
	var now := Cursors.Situation.new()
	now.in_hand = true
	now.aimed = true
	now.can_place = false
	_check("a ghost that cannot go down is shown as blocked",
		Cursors.choose(now) == "blocked")
	now.can_place = true
	_check("...and one that can, as the crosshair", Cursors.choose(now) == "place")
	now.aimed = false
	_check("...and in hand over nothing it could go on, as a turn",
		Cursors.choose(now) == "orbit")
	_main.set_process(false)
	_cursors.show_state("blocked")
	var shown_as: int = -1
	for _n: int in 30:
		await process_frame
		shown_as = DisplayServer.cursor_get_shape()
		if shown_as == DisplayServer.CURSOR_FORBIDDEN:
			break
	_main.set_process(true)
	_check("...which the window shows as the forbidden sign, got %d" % shown_as,
		shown_as == DisplayServer.CURSOR_FORBIDDEN)
	await _move_to(_middle)
	await _expect("...and the next frame puts it back", "place")


func _dragging() -> void:
	# Turning, with the right button.
	await _move_to(_middle)
	_press(MOUSE_BUTTON_RIGHT, _middle, true)
	await _frames(2)
	for n: int in range(1, 5):
		await _move_to(_middle + Vector2(n * 12.0, 0.0), MOUSE_BUTTON_MASK_RIGHT)
	await _expect("a right drag", "grabbing")
	_check("...with the sheet up so it keeps its shape over panels",
		_cursors.shielding())
	# Across a panel and still turning: the pointer stays the turn.
	var panel: Vector2 = _panel_point()
	await _move_to(panel, MOUSE_BUTTON_MASK_RIGHT)
	await _expect("...carried over a panel", "grabbing")
	await _move_to(_middle, MOUSE_BUTTON_MASK_RIGHT)
	_press(MOUSE_BUTTON_RIGHT, _middle, false)
	await _expect("...and let go of", "place")
	_check("...with the sheet gone", not _cursors.shielding())

	# The middle button, which slides in Studio's preset (the default) and
	# turns with shift — and the other way round in Blender's.
	ViewPrefs.use("studio")
	await _drag_and_look(MOUSE_BUTTON_MIDDLE, false, "a middle drag", "grabbing")
	await _drag_and_look(MOUSE_BUTTON_MIDDLE, true, "shift and a middle drag", "grabbing")
	ViewPrefs.use("blender")
	await _drag_and_look(MOUSE_BUTTON_MIDDLE, false, "in Blender's, a middle drag", "grabbing")
	await _drag_and_look(MOUSE_BUTTON_MIDDLE, true, "...and with shift", "grabbing")
	ViewPrefs.use("studio")

	# A left drag turns the view, with a part in hand too, and places
	# nothing; with Ctrl it draws a box.
	_builder.clear_selection()
	var placed: int = _world.brick_count()
	await _drag_and_look(MOUSE_BUTTON_LEFT, false, "a left drag", "grabbing")
	_check("...which placed nothing", _world.brick_count() == placed)
	await _drag_and_look(MOUSE_BUTTON_LEFT, true, "shift and a left drag", "grabbing")
	_ctrl = true
	await _drag_and_look(MOUSE_BUTTON_LEFT, false, "Ctrl and a left drag", "box")
	_ctrl = false
	_check("...which placed nothing either", _world.brick_count() == placed)
	_builder.clear_selection()


## Drag with a button, see the state while it is held, let go and see
## the pointer come back.
func _drag_and_look(which: int, shift: bool, what: String, state: String) -> void:
	await _settle()
	var mask: int = {MOUSE_BUTTON_LEFT: MOUSE_BUTTON_MASK_LEFT,
		MOUSE_BUTTON_RIGHT: MOUSE_BUTTON_MASK_RIGHT,
		MOUSE_BUTTON_MIDDLE: MOUSE_BUTTON_MASK_MIDDLE}[which]
	var from: Vector2 = _middle - Vector2(60.0, 40.0)
	await _move_to(from)
	if shift:
		await _key_down(KEY_SHIFT, true)
	_press(which, from, true, shift)
	await _frames(2)
	for n: int in range(1, 6):
		await _move_to(from + Vector2(n * 14.0, n * 9.0), mask, shift)
	await _expect(what, state)
	var to: Vector2 = from + Vector2(70.0, 45.0)
	_press(which, to, false, shift)
	if shift:
		await _key_down(KEY_SHIFT, false)
	await _expect_over("...and let go of", state)
	# Placing again once the model is back under the pointer: the drag
	# may have turned it away, and over empty sky the arrow is right.
	await _settle()
	await _expect("...and over the model again, placing", "place")


func _wheel_and_keys() -> void:
	await _settle()
	await _move_to(_middle)
	_press(MOUSE_BUTTON_WHEEL_UP, _middle, true)
	_press(MOUSE_BUTTON_WHEEL_UP, _middle, false)
	await _expect("a notch of the wheel up", "zoom_in")
	await _expect("...for a moment, and then back", "place")
	_press(MOUSE_BUTTON_WHEEL_DOWN, _middle, true)
	_press(MOUSE_BUTTON_WHEEL_DOWN, _middle, false)
	await _expect("a notch down", "zoom_out")
	await _expect("...and back", "place")

	await _key_down(KEY_SHIFT, true)
	_press(MOUSE_BUTTON_WHEEL_UP, _middle, true, true)
	_press(MOUSE_BUTTON_WHEEL_UP, _middle, false, true)
	await _expect("shift and the wheel", "hand")
	await _key_down(KEY_SHIFT, false)
	await _expect("...and back", "place")

	await _key_down(KEY_RIGHT, true)
	await _expect("an arrow key held", "orbit")
	await _key_down(KEY_RIGHT, false)
	await _expect("...and let go of", "place")

	# Holding C paints whatever comes under the pointer.
	await _settle()
	await _move_to(_middle)
	await _key_down(KEY_C, true)
	await _expect("C held", "paint")
	await _key_down(KEY_C, false)
	await _move_to(_middle)
	await _expect("...and let go of", "place")


func _over_the_panels() -> void:
	var bin: PartsBin = _main.get("_bin")
	var search: LineEdit = bin.get("_search")
	await _move_to(_centre(search))
	await _expect_shape("over the parts search", DisplayServer.CURSOR_IBEAM)
	var help: Button = _button_called(_main.get("_bar"), "Help")
	_check("there is a Help button to point at", help != null)
	if help != null:
		await _move_to(_centre(help))
		await _expect_shape("over a button", DisplayServer.CURSOR_POINTING_HAND)
	var title: Label = _label_called(bin, "Colour")
	if title != null:
		await _move_to(_centre(title))
		await _expect_shape("over a panel's own background",
			DisplayServer.CURSOR_ARROW)
	await _move_to(_middle)
	await _expect("back over the model", "place")


## A wheel, a swipe or a pinch over any panel or dialog belongs to it.
##
## Asked for by the owner: "when i'm scrolling within a modal or control
## panel ... it continues to move and effect the model in the main window
## behind it". Godot passes a scroll on through a control that does not
## use it, so the cases that matter are the ones where nothing scrolls: a
## list already at its end, a dialog with nothing to scroll. Each is
## checked by the camera not having moved at all — distance, angles and
## where it looks — and the wheel over the model is checked to still zoom,
## or a camera that ignored every wheel would pass.
func _wheel_over_the_interface() -> void:
	await _settle()
	var bin: PartsBin = _main.get("_bin")
	var list: ScrollContainer = bin.get("_scroll")
	# A list that can still scroll: it scrolls, and the model stays put.
	list.scroll_vertical = 0
	await _frames(2)
	var on_list: Vector2 = _centre(list)
	await _move_to(on_list)
	var before: Array = _camera_now()
	await _notch(MOUSE_BUTTON_WHEEL_DOWN, on_list)
	_check("the parts list scrolls under the wheel, to %d" % list.scroll_vertical,
		list.scroll_vertical > 0)
	_check("...and the model stays where it was", _camera_now() == before)
	# The same list at the top, scrolled further up: nothing in the list
	# moves, which is when Godot lets the wheel through.
	list.scroll_vertical = 0
	await _frames(2)
	await _unmoved_by_scrolling("the parts list already at its top", on_list)
	list.scroll_vertical = int(list.get_v_scroll_bar().max_value)
	await _frames(2)
	await _unmoved_by_scrolling("the parts list already at its end", on_list)
	list.scroll_vertical = 0
	var colours: ScrollContainer = bin.get("_palette_scroll")
	await _unmoved_by_scrolling("the colours", _centre(colours))
	# A window with room for one column beside the model shows one at a
	# time, the assistant's on a first visit: each is opened for its own
	# checks, the assistant's here and the bin's again after.
	var chat_dock: SideDock = _main.get("_chat_dock")
	var bin_dock: SideDock = _main.get("_bin_dock")
	if not chat_dock.is_open():
		chat_dock.set_open(true, false)
		await _frames(5)
	await _unmoved_by_scrolling("the assistant panel", _centre(_main.get("_chat")))
	await _unmoved_by_scrolling("the toolbar", _centre(_main.get("_bar")))

	# A popup: the model chooser in the assistant panel.
	var which: OptionButton = null
	for option: OptionButton in _all(_main.get("_chat"), "OptionButton"):
		if option.is_visible_in_tree():
			which = option
			break
	if which != null:
		which.show_popup()
		await _frames(3)
		var popup: PopupMenu = which.get_popup()
		var on_popup: Vector2 = Vector2(popup.position) + Vector2(popup.size) * 0.5
		await _unmoved_by_scrolling("a menu that is open", on_popup)
		popup.hide()
		await _frames(2)
	else:
		_check("there is a menu in the assistant panel to open", false)
	if not bin_dock.is_open():
		bin_dock.set_open(true, false)
		await _frames(5)

	# The dialogs, each open over the model.
	var controls: ControlsDialog = _main.get("_controls")
	controls.open()
	await _frames(3)
	await _unmoved_by_scrolling("the controls panel", _centre(controls))
	controls.visible = false
	var figures: Control = _main.get("_figures")
	if figures != null:
		_main._open_figures()
		await _frames(6)
		await _unmoved_by_scrolling("the minifigure builder", _centre(figures))
		figures.call("close")
		await _frames(2)
	var elements: Control = _main.get("_elements")
	if elements != null:
		elements.call("open", _builder.held_part)
		await _frames(6)
		await _unmoved_by_scrolling("Make a part", _centre(elements))
		elements.visible = false
		await _frames(2)
	var mosaic: MosaicDialog = _main.get("_mosaic")
	var picture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.8, 0.2, 0.2))
	mosaic.show_for(picture)
	await _frames(4)
	await _unmoved_by_scrolling("the mosaic dialog", _centre(mosaic))
	mosaic.visible = false
	var inventory: InventoryPanel = _main.get("_inventory")
	_main._toggle_parts()
	await _frames(6)
	await _unmoved_by_scrolling("the parts list (inventory)", _middle)
	inventory.hide_list()
	var steps: StepsBar = _main.get("_steps")
	_main._toggle_steps()
	await _frames(6)
	await _unmoved_by_scrolling("the timeline bar", _centre(steps))
	steps.stop()
	await _frames(4)

	# The checks above can fail. Each was also run with the camera not
	# asking, and some of these panels then let the wheel through to the
	# model — which is the owner's report, reproduced. Not every one does
	# (a list that scrolls takes the wheel itself), so this asks only that
	# the fault was there to be caught somewhere.
	_check("without the question the wheel reached the model over: %s"
		% ", ".join(_leaked), not _leaked.is_empty())

	# And the model itself still answers to all of it.
	await _settle()
	await _move_to(_middle)
	var far: float = _camera._target_distance
	await _notch(MOUSE_BUTTON_WHEEL_UP, _middle)
	_check("the wheel over the model still zooms, %.0f -> %.0f"
		% [far, _camera._target_distance], _camera._target_distance < far)
	var yaw: float = _camera._target_yaw
	_swipe(_middle)
	await _frames(3)
	_check("...and a swipe over it still turns it",
		not is_equal_approx(_camera._target_yaw, yaw))
	await _settle()


## Panels the wheel got through to the model when the camera was not
## asking. See [method _wheel_over_the_interface].
var _leaked: PackedStringArray = []


## Every way of scrolling, over one point, and the camera exactly where it
## was afterwards. Also the two buttons that start a drag of the view.
##
## Then the same again with the camera not asking whether the point is
## over the interface, to see whether this panel would have let it
## through: a check over a panel that never leaked proves nothing.
func _unmoved_by_scrolling(what: String, at: Vector2) -> void:
	await _move_to(at)
	var before: Array = _camera_now()
	await _scroll_every_way(at)
	var wheel_moved: bool = _camera_now() != before
	# A drag of the view begun here is the panel's too.
	_press(MOUSE_BUTTON_MIDDLE, at, true)
	await _frames(2)
	await _move_to(at + Vector2(30.0, 12.0), MOUSE_BUTTON_MASK_MIDDLE)
	_press(MOUSE_BUTTON_MIDDLE, at + Vector2(30.0, 12.0), false)
	await _frames(3)
	_check("over %s, the wheel, a swipe and a pinch leave the model alone%s"
		% [what, "" if not wheel_moved else ": it moved"], not wheel_moved)
	_check("...and so does a middle drag begun there", _camera_now() == before)
	var asking: Callable = _camera.over_interface
	_camera.over_interface = Callable()
	var bare: Array = _camera_now()
	await _scroll_every_way(at)
	if _camera_now() != bare:
		_leaked.append(what)
	_camera.over_interface = asking


## Up twice and down three times, so a list at either end is scrolled
## past it; sideways; shift and the wheel; a swipe; a pinch.
func _scroll_every_way(at: Vector2) -> void:
	await _notch(MOUSE_BUTTON_WHEEL_UP, at)
	await _notch(MOUSE_BUTTON_WHEEL_UP, at)
	await _notch(MOUSE_BUTTON_WHEEL_DOWN, at)
	await _notch(MOUSE_BUTTON_WHEEL_DOWN, at)
	await _notch(MOUSE_BUTTON_WHEEL_DOWN, at)
	await _notch(MOUSE_BUTTON_WHEEL_LEFT, at)
	await _key_down(KEY_SHIFT, true)
	await _notch(MOUSE_BUTTON_WHEEL_UP, at, true)
	await _key_down(KEY_SHIFT, false)
	_swipe(at)
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = _as_event(at)
	pinch.factor = 1.3
	Input.parse_input_event(pinch)
	await _frames(3)


## The camera's targets: where it is going, which is what an input moves.
func _camera_now() -> Array:
	return [_camera._target_distance, _camera._target_yaw,
		_camera._target_pitch, _camera._target_focus]


func _notch(which: int, at: Vector2, shift: bool = false) -> void:
	_press(which, at, true, shift)
	_press(which, at, false, shift)
	await _frames(2)


func _swipe(at: Vector2) -> void:
	var swipe := InputEventPanGesture.new()
	swipe.position = _as_event(at)
	swipe.delta = Vector2(3.0, 1.0)
	Input.parse_input_event(swipe)


func _the_way_back() -> void:
	# A turn that ends outside the window: the pointer leaves with the
	# button down and lets go out there.
	await _settle()
	await _move_to(_middle)
	_press(MOUSE_BUTTON_RIGHT, _middle, true)
	await _frames(2)
	for n: int in range(1, 6):
		await _move_to(_middle + Vector2(n * 14.0, 0.0), MOUSE_BUTTON_MASK_RIGHT)
	await _expect("a turn under way", "grabbing")
	var outside := Vector2(-60.0, -40.0)
	await _move_to(outside, MOUSE_BUTTON_MASK_RIGHT)
	_press(MOUSE_BUTTON_RIGHT, outside, false)
	await _frames(4)
	_check("a turn let go outside the window is over, got '%s'" % _cursors.shown(),
		_cursors.shown() != "grabbing" and not _cursors.shielding())
	await _move_to(_middle)
	await _expect("...and coming back in, the pointer places", "place")

	# Escape in the middle of a box: thrown away, with the button
	# still down, and its release is not a click.
	#
	# Drawn leftwards, which takes anything the box so much as touches,
	# across the middle of the model: had Escape not thrown it away, its
	# release would have selected something.
	await _settle()
	_builder.clear_selection()
	_ctrl = true
	var from: Vector2 = _middle + Vector2(90.0, 50.0)
	await _move_to(from)
	_press(MOUSE_BUTTON_LEFT, from, true)
	await _frames(2)
	for n: int in range(1, 6):
		await _move_to(from - Vector2(n * 20.0, n * 12.0), MOUSE_BUTTON_MASK_LEFT)
	await _expect("a box under way", "box")
	await _key_tap(KEY_ESCAPE)
	await _expect("...Escape throws it away, button still down", "place")
	var placed: int = _world.brick_count()
	var end: Vector2 = from - Vector2(120.0, 70.0)
	await _move_to(end, MOUSE_BUTTON_MASK_LEFT)
	_press(MOUSE_BUTTON_LEFT, end, false)
	await _frames(4)
	_check("...and letting go after it places nothing and selects nothing",
		_world.brick_count() == placed and _builder.selection.is_empty())
	# The same box not thrown away does select, or the check above
	# proves nothing.
	await _settle()
	await _move_to(from)
	_press(MOUSE_BUTTON_LEFT, from, true)
	await _frames(2)
	for n: int in range(1, 7):
		await _move_to(from - Vector2(n * 20.0, n * 12.0), MOUSE_BUTTON_MASK_LEFT)
	_press(MOUSE_BUTTON_LEFT, end, false)
	await _frames(4)
	_check("...where the same box let go of selects %d" % _builder.selection.size(),
		not _builder.selection.is_empty())
	_ctrl = false
	_builder.clear_selection()
	await _move_to(_middle)
	await _expect("...and the pointer is placing again", "place")

	# The controls panel opens on top of the pointer and closes from
	# under it, with the pointer never moving: the shape has to follow
	# what is there, not what was there when it last moved.
	var controls: ControlsDialog = _main.get("_controls")
	await _move_to(_middle)
	await _key_tap(KEY_COMMA)
	_check("comma opens the controls", controls.visible)
	var on_it: Vector2 = _centre(controls)
	await _move_to(on_it)
	await _expect_shape("over the controls panel", DisplayServer.CURSOR_ARROW)
	await _key_tap(KEY_ESCAPE)
	_check("Escape closes the controls", not controls.visible)
	await _expect("...and with the pointer not moved, it places again", "place")

	# Done, which puts a pointing hand under the pointer and then takes
	# the whole panel away.
	await _key_tap(KEY_COMMA)
	var done: Button = _button_called(controls, "Done")
	if done != null:
		await _move_to(_centre(done))
		await _expect_shape("over Done", DisplayServer.CURSOR_POINTING_HAND)
		_press(MOUSE_BUTTON_LEFT, _centre(done), true)
		await _frames(1)
		_press(MOUSE_BUTTON_LEFT, _centre(done), false)
		await _frames(4)
		_check("Done closes the controls", not controls.visible)
		# Not "place" necessarily: Done sits over the model, and the
		# pointer is wherever Done was. Whatever is there, it is not the
		# hand of a button that has gone.
		await _expect_not_shape("...and the hand goes with it",
			DisplayServer.CURSOR_POINTING_HAND)
	await _move_to(_middle)
	await _expect("back to placing", "place")


## Every tool, every key that lends the left button to the view, and what
## is under the pointer.
##
## The owner, on the live site: "we're not seeing the cursor change based
## on the mode and context, as you obviously need to do." Hide, Clone,
## Rotate, Hinge and Move showed Select's pointing hand, the background
## the arrow though a drag there turns the view, and the Orbit, Pan and
## Zoom tools, Space and Alt nothing at all.
func _tools_and_contexts() -> void:
	var verbs: EditVerbs = _main.get("_verbs")
	await _key_tap(KEY_ESCAPE)
	verbs.set_mode("select")
	_builder.clear_selection()
	await _settle()
	var nothing: Vector2 = _nothing_point()
	await _move_to(_middle)
	await _expect("Select, over a part: a click picks it", "select")
	await _move_to(nothing)
	await _expect("Select, over nothing: a drag turns the view", "orbit")
	await _key_down(KEY_SHIFT, true)
	await _expect("...with Shift: a drag slides it", "hand")
	await _move_to(_middle, 0, true)
	await _expect("...over a part as well", "hand")
	await _key_down(KEY_SHIFT, false)
	await _key_down(KEY_CTRL, true)
	await _expect("Ctrl over a part: a drag copies it", "copy")
	await _move_to(nothing)
	await _expect("Ctrl over nothing: a drag draws a box", "box")
	await _key_down(KEY_CTRL, false)
	await _expect("...and let go of", "orbit")

	for tool: Array in [["paint", "paint"], ["delete", "delete"], ["hide", "hide"],
			["clone", "copy"], ["rotate", "rotate"], ["hinge", "hinge"], ["move", "move"]]:
		verbs.set_mode(tool[0])
		await _move_to(_middle)
		await _expect("%s, over a part" % str(tool[0]).capitalize(), tool[1])
		await _move_to(nothing)
		await _expect("...and over nothing", tool[1])
	verbs.set_mode("select")

	# The view tools: their own pointer over everything, the other verb
	# with Shift, and a closed hand while they hold the view.
	for tool: Array in [["orbit", "orbit", "hand"], ["pan", "hand", "orbit"],
			["zoom", "zoom_in", "zoom_out"]]:
		verbs.view_tool(tool[0])
		await _move_to(_middle)
		await _expect("the %s tool, over a part" % str(tool[0]).capitalize(), tool[1])
		await _key_down(KEY_SHIFT, true)
		await _expect("...with Shift", tool[2])
		await _key_down(KEY_SHIFT, false)
		await _left_drag_held("...dragging", "grabbing")
		_check("...which had hold of the view", _held_the_view)
		await _expect("...and let go of", tool[1])
	await _key_tap(KEY_ESCAPE)
	_check("Esc is Select again (%s)" % verbs.mode, verbs.mode == "select")

	# The keys held that lend the left button to the view, in any tool.
	await _settle()
	await _move_to(_middle)
	await _expect("Select over a part again", "select")
	await _key_down(KEY_SPACE, true)
	await _expect("Space held: a drag slides the view", "hand")
	await _left_drag_held("...dragging", "grabbing")
	await _expect("...and let go of the button", "hand")
	# The slide moved the model under the pointer, by however far the
	# pointer the probe warps and the events it sends added up to: on a
	# loaded machine the middle was left on a part's edge, and missed it.
	# Back over a part, wherever the slide left them, Space still held.
	for _n: int in 40:
		_camera._apply(0.5)
		await process_frame
	await _move_to(_part_point())
	await _key_down(KEY_SPACE, false)
	await _expect("...and of Space", "select")
	await _key_down(KEY_ALT, true)
	await _expect("Alt held: a drag turns the view", "orbit")
	await _key_down(KEY_SHIFT, true)
	await _expect("Alt and Shift: it slides", "hand")
	await _key_down(KEY_SHIFT, false)
	await _key_down(KEY_CTRL, true)
	await _expect("Alt and Ctrl: it zooms", "zoom_in")
	await _key_down(KEY_CTRL, false)
	await _key_down(KEY_ALT, false)
	await _expect("...and let go of", "select")

	# A part in hand: the crosshair where it would go, a turn where there
	# is nothing it could go on.
	await _settle()
	await _key_tap(KEY_Q)
	await _move_to(_middle)
	await _expect("a part in hand, over a spot it fits", "place")
	var sky: Vector2 = await _sky_point()
	_check("there is somewhere with nothing to put it on (%s)" % sky, sky != Vector2.ZERO)
	if sky != Vector2.ZERO:
		await _expect("...over nothing: a drag turns the view", "orbit")
	_camera.set_view("default")
	await _key_tap(KEY_ESCAPE)
	verbs.set_mode("select")

	# A part taken by a drag: held, it is a closed hand.
	await _settle()
	_builder.clear_selection()
	await _move_to(_middle)
	await _expect("over a part to drag", "select")
	await _left_drag_held("dragging a part", "grabbing")
	_check("...which had hold of the part, not the view", _held_a_part and not _held_the_view)
	await _expect_not("...and let go of", "grabbing")

	# The interface: the view cube is pressed, so it points; a splitter
	# resizes. The app has no splitter of its own yet, so one is put over
	# the model for the length of the check, to see that a picture never
	# hangs on the shapes Godot gives its controls.
	var cube: Control = _main.get("_gizmo")
	if cube != null and cube.is_visible_in_tree():
		await _move_to(_centre(cube))
		await _expect_shape("over the view cube", DisplayServer.CURSOR_POINTING_HAND)
	else:
		_check("there is a view cube to point at", false)
	var split := HSplitContainer.new()
	split.position = _middle - Vector2(200.0, 80.0)
	split.size = Vector2(400.0, 160.0)
	for _n: int in 2:
		var side := Panel.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(side)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(split)
	root.add_child(layer)
	await _frames(3)
	await _move_to(_middle)
	await _expect_shape("over a splitter", DisplayServer.CURSOR_HSPLIT)
	_check("...which no picture hangs on", not Cursors.SLOTS.has(Input.CURSOR_HSPLIT)
		and not Cursors.SLOTS.has(Input.CURSOR_VSPLIT))
	layer.queue_free()
	await _frames(3)


## What the last [method _left_drag_held] had hold of.
var _held_a_part: bool = false
var _held_the_view: bool = false


## A left drag from the middle, checked while the button is still down,
## then let go of.
func _left_drag_held(what: String, state: String) -> void:
	var from: Vector2 = _middle
	_press(MOUSE_BUTTON_LEFT, from, true)
	await _frames(2)
	for n: int in range(1, 6):
		await _move_to(from + Vector2(n * 12.0, n * 5.0), MOUSE_BUTTON_MASK_LEFT)
	await _expect(what, state)
	_held_a_part = bool(_main.get("_dragging_part"))
	_held_the_view = _camera.is_dragging()
	var to: Vector2 = from + Vector2(60.0, 25.0)
	_press(MOUSE_BUTTON_LEFT, to, false)
	await _frames(4)
	await _move_to(_middle)


## A view tool on, or a key held that lends the left button to the view,
## and a click on the toolbar or a panel still presses what it is on.
##
## The sheet that keeps a drag's pointer over the panels went up for a
## state's name, not for a drag: with Orbit on it covered the window for
## as long as the tool was, and every click on a button turned the view
## instead (brickworks.diy, 2026-10-12). Held Ctrl did the same in Select.
func _buttons_while_the_view_is_lent() -> void:
	var verbs: EditVerbs = _main.get("_verbs")
	var shell: Shell = _main.get("_shell")
	var bin: PartsBin = _main.get("_bin")
	var paint: Control = shell.toolbar.controls_by_name().get("tool_mode_paint")
	var part: Control = bin.controls_by_name().get("first part")
	_check("there is Paint on the toolbar and a part in the bin to press",
		paint != null and part != null)
	if paint == null or part == null:
		return
	var nothing: Vector2 = _nothing_point()
	for tool: String in ["orbit", "pan", "zoom"]:
		verbs.set_mode("select")
		verbs.view_tool(tool)
		await _move_to(nothing)
		await _frames(3)
		_check("%s on, no button down: nothing over the panels (%s)"
			% [tool.capitalize(), _cursors.shown()], not _cursors.shielding())
		await _click(_centre(paint))
		_check("...and a click on Paint on the toolbar presses it (%s)" % verbs.mode,
			verbs.mode == "paint")
		verbs.view_tool(tool)
		await _move_to(nothing)
		await _frames(3)
		await _click(_centre(part))
		_check("...and a click on a part in the parts bin takes it (%s)" % verbs.mode,
			verbs.mode == "place")
		await _key_tap(KEY_ESCAPE)
	verbs.set_mode("select")
	for held: Array in [[KEY_CTRL, "Ctrl"], [KEY_SPACE, "Space"], [KEY_ALT, "Alt"]]:
		verbs.set_mode("select")
		await _move_to(nothing)
		_ctrl = held[0] == KEY_CTRL
		await _key_down(held[0], true)
		await _frames(3)
		_check("%s held over nothing: nothing over the panels (%s)"
			% [held[1], _cursors.shown()], not _cursors.shielding())
		await _click(_centre(paint))
		_check("...and a click on Paint presses it (%s)" % verbs.mode, verbs.mode == "paint")
		await _key_down(held[0], false)
		_ctrl = false
	verbs.set_mode("select")
	await _frames(3)


## Down and up where it is, as a click.
func _click(at: Vector2) -> void:
	await _move_to(at)
	_press(MOUSE_BUTTON_LEFT, at, true)
	await _frames(2)
	_press(MOUSE_BUTTON_LEFT, at, false)
	await _frames(4)


## A point over the model's part of the window with no part under it.
func _nothing_point() -> Vector2:
	var verbs: EditVerbs = _main.get("_verbs")
	var size: Vector2 = root.get_visible_rect().size
	for offset: Vector2 in [Vector2(0, 220), Vector2(0, -200), Vector2(-260, 160),
			Vector2(260, 160), Vector2(-300, -120), Vector2(0, 300)]:
		var at: Vector2 = _middle + offset
		if Rect2(Vector2.ZERO, size).has_point(at) and verbs.brick_at(at) == 0 \
				and not _main._over_panel_at(at):
			return at
	_check("there is somewhere over the model with no part under it", false)
	return _middle + Vector2(0, 220)


## The point nearest the middle with a part under it, off the panels.
func _part_point() -> Vector2:
	var verbs: EditVerbs = _main.get("_verbs")
	var size: Vector2 = root.get_visible_rect().size
	for ring: int in range(0, 12):
		for step: int in range(maxi(ring * 8, 1)):
			var turn: float = TAU * step / maxf(ring * 8, 1)
			var at: Vector2 = _middle + Vector2(cos(turn), sin(turn)) * ring * 20.0
			if Rect2(Vector2.ZERO, size).has_point(at) and verbs.brick_at(at) != 0 \
					and not _main._over_panel_at(at):
				return at
	_check("there is somewhere over the model with a part under it", false)
	return _middle


## A point where the part in hand has nowhere to go, walking up from the
## middle into the sky; ZERO if there is none. From the front, level: from
## above, every ray down reaches the ground, which a part can go on.
func _sky_point() -> Vector2:
	_camera.set_view("front")
	for _n: int in 40:
		_camera._apply(0.5)
		await process_frame
	var y: float = _middle.y
	while y > 30.0:
		var at := Vector2(_middle.x, y)
		if not _main._over_panel_at(at):
			await _move_to(at)
			if not _builder.has_preview():
				return at
		y -= 25.0
	return Vector2.ZERO


func _the_list() -> void:
	var controls: ControlsDialog = _main.get("_controls")
	controls.open()
	await _frames(6)
	var density: float = Icons.density(controls)
	var pictures: int = 0
	var caps: int = 0
	for picture: TextureRect in _all(controls, "TextureRect"):
		if picture.texture != null:
			pictures += 1
	for cap: PanelContainer in _all(controls, "PanelContainer"):
		if cap != controls:
			caps += 1
	_check("the controls panel draws the mouse and fingers (%d pictures) and keys (%d caps)"
		% [pictures, caps], pictures >= 20 and caps >= 25)

	# The middle button's row follows the setting: its verb, and the
	# pointer it shows. Changed through the panel's own box.
	var preset: OptionButton = (controls as ControlsDialog).preset_choice
	_check("the panel has the navigation preset", preset != null)
	if preset != null:
		preset.select(ViewPrefs.PRESETS.find("blender"))
		preset.item_selected.emit(ViewPrefs.PRESETS.find("blender"))
		await _frames(3)
		_check("set to Blender's, the middle row shows the turning pointer",
			_middle_row_pointer(controls, density) == "orbit")
		preset.select(ViewPrefs.PRESETS.find("studio"))
		preset.item_selected.emit(ViewPrefs.PRESETS.find("studio"))
		await _frames(3)
		_check("set to Studio's, it shows the sliding one",
			_middle_row_pointer(controls, density) == "hand")
		var hint: ControlsHint = _main.get("_hint")
		var says: String = ""
		for label: Label in _all(hint, "Label"):
			if label.text == "slide":
				says = label.text
		_check("...and the strip says slide too", says == "slide")

	await _shot(_out + "/help_dialog.png")
	controls.visible = false
	await _frames(4)
	await _shot(_out + "/strip_full.png")
	var whole: Image = Image.load_from_file(_out + "/strip_full.png")
	if whole != null:
		var hint: ControlsHint = _main.get("_hint")
		var rect: Rect2 = root.get_final_transform() * hint.get_global_rect()
		var band := Rect2i(Vector2i(int(rect.position.x) - 8, int(rect.position.y) - 8),
			Vector2i(int(rect.size.x) + 16, int(rect.size.y) + 16)).intersection(
				Rect2i(Vector2i.ZERO, whole.get_size()))
		var strip: Image = whole.get_region(band)
		strip.save_png(_out + "/strip.png")
		var big: Image = strip.duplicate()
		big.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
		big.save_png(_out + "/strip@2x-zoom.png")
		print("  wrote strip.png and strip@2x-zoom.png")


## Which pointer the middle-drag row of the panel shows, by comparing
## its picture with the ones the panel would draw for each.
func _middle_row_pointer(controls: ControlsDialog, density: float) -> String:
	for keys: Control in _all(controls, "HBoxContainer"):
		if keys.tooltip_text != "middle-drag":
			continue
		var row: Node = keys.get_parent().get_parent()
		for picture: TextureRect in _all(row, "TextureRect"):
			for state: String in ["orbit", "hand"]:
				if picture.texture == Icons.texture_for(Icons.CURSORS + state + ".svg",
						ControlsDialog.POINTER_TALL, density):
					return state
	return ""


# -- driving ----------------------------------------------------------------------


## Wait for the app to be in a state and the window to be showing it.
##
## In time, not frames: a moment of the wheel lasts a third of a second,
## and with the frame rate uncapped that is anything from twenty frames
## to two hundred.
##
## A picture's shape is whichever slot it hangs on (Cursors.SLOTS), so
## it is asked for as it is shown.
func _expect(what: String, state: String, seconds: float = 3.0) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		var wants: int = _cursors.shape_of(state)
		if _cursors.shown() == state and wants != -1 \
				and DisplayServer.cursor_get_shape() == wants:
			_check("%s: %s" % [what, state], true)
			return
	_check("%s: wanted %s (shape %d), got %s (shape %d)" % [what, state,
		_cursors.shape_of(state), _cursors.shown(), DisplayServer.cursor_get_shape()], false)


## Wait for the pointer to have left a state, whatever it went to.
func _expect_not(what: String, state: String) -> void:
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		if _cursors.shown() != state and not _cursors.shielding():
			_check("%s: %s" % [what, _cursors.shown()], true)
			return
	_check("%s: still %s" % [what, state], false)


## Wait for a drag's state to be over: neither the app nor the window
## still showing it, and the sheet gone.
func _expect_over(what: String, state: String) -> void:
	var was: int = _cursors.shape_of(state)
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		if _cursors.shown() != state and DisplayServer.cursor_get_shape() != was \
				and not _cursors.shielding():
			_check("%s: %s" % [what, _cursors.shown()], true)
			return
	_check("%s: still %s (shape %d)" % [what, _cursors.shown(),
		DisplayServer.cursor_get_shape()], false)


func _expect_shape(what: String, shape: int) -> void:
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		if DisplayServer.cursor_get_shape() == shape:
			_check("%s: shape %d" % [what, shape], true)
			return
	_check("%s: wanted shape %d, got %d (state %s)" % [what, shape,
		DisplayServer.cursor_get_shape(), _cursors.shown()], false)


func _expect_not_shape(what: String, shape: int) -> void:
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		if DisplayServer.cursor_get_shape() != shape:
			_check("%s: shape %d" % [what, DisplayServer.cursor_get_shape()], true)
			return
	_check("%s: still shape %d" % [what, shape], false)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(how_many: int) -> void:
	for _n: int in how_many:
		await process_frame


## The model framed, the pointer over it and a brick under it.
func _settle() -> void:
	await _follow_the_view()
	_camera.frame(_world.model_bounds())
	for _n: int in 40:
		_camera._apply(0.5)
		await process_frame
	_builder.hide_preview()
	await _move_to(_middle)
	for _n: int in 600:
		await process_frame
		if _builder.hovered_brick() != 0:
			return


## Through Input, not the viewport: the camera asks the Input singleton
## whether a button is still down, and push_input leaves it untouched.
## See feel_probe.
## Ctrl held for the presses that follow: a left drag with it draws a box.
var _ctrl: bool = false


func _press(which: int, at: Vector2, down: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.shift_pressed = shift
	event.ctrl_pressed = _ctrl
	event.position = _as_event(at)
	event.global_position = event.position
	_pointer = event.position
	Input.parse_input_event(event)


## The pointer moved, as an event and for real.
##
## For real as well, because the app replays a motion where the pointer
## is whenever something may have changed under it (Cursors._input), and
## Godot takes "where the pointer is" from the system, not from the last
## event. Moved only by events, the system's pointer sat wherever Xvfb
## put it, and every replay aimed the ghost there: after Escape the
## pointer said "arrow" for a spot the probe was not pointing at.
func _move_to(at: Vector2, mask: int = 0, shift: bool = false) -> void:
	if _virtual:
		Input.warp_mouse(_as_event(at))
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	event.button_mask = mask
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await _frames(2)


func _key_down(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.shift_pressed = code == KEY_SHIFT and down
	Input.parse_input_event(event)
	await _frames(2)


func _key_tap(code: Key) -> void:
	await _key_down(code, true)
	await _key_down(code, false)


## Viewport coordinates to the window coordinates an event carries. See
## feel_probe: the interface is scaled, so the two are not the same.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## A point over a panel, found by walking in from the right edge.
func _panel_point() -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var x: int = int(rect.x) - 6
	while float(x) > rect.x * 0.55:
		var at := Vector2(float(x), rect.y * 0.5)
		if _main._over_panel_at(at):
			return at
		x -= 6
	return Vector2(rect.x - 20.0, rect.y * 0.5)


func _all(from: Node, kind: String) -> Array:
	var found: Array = []
	if from.is_class(kind):
		found.append(from)
	for child: Node in from.get_children():
		found.append_array(_all(child, kind))
	return found


func _button_called(from: Node, text: String) -> Button:
	for button: Button in _all(from, "Button"):
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


func _checkbox_called(from: Node, starting: String) -> CheckBox:
	for box: CheckBox in _all(from, "CheckBox"):
		if box.text.begins_with(starting):
			return box
	return null


func _label_called(from: Node, text: String) -> Label:
	for label: Label in _all(from, "Label"):
		if label.text == text and label.is_visible_in_tree():
			return label
	return null


## The window as it is now. Forced, not awaited: a window nobody looks at
## is not asked to redraw (see main._capture).
func _shot(path: String) -> void:
	for _n: int in 3:
		await process_frame
		RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
	print("  wrote %s" % path)


## Wait for a column sliding in or out, and aim at the middle of the model's
## part of the window as it then is: the view is centred there
## (CadCamera.seen), and a column opening or folding moves it.
func _follow_the_view() -> void:
	var room: Vector2 = root.get_visible_rect().size
	for _n: int in 600:
		await process_frame
		var seen: Rect2 = _camera.seen_rect()
		var drawn_at: Vector2 = _camera.unproject_position(_camera.focus)
		if _camera._shift == seen.get_center() - room * 0.5 \
				and drawn_at.distance_to(seen.get_center()) < 0.5:
			break
	_middle = ((_main.call("model_cover") as Dictionary)["view"] as Rect2).get_center()
