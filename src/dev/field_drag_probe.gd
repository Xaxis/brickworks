## Does a finger's drag that begins on a text field scroll the list round it,
## as a drag begun anywhere else in the list does, on a phone and a tablet?
##
##   godot --path . --resolution 390x844 --script src/dev/field_drag_probe.gd -- --phone
##   tools/probe.sh field_drag_probe --phone          a phone's layout, 390 x 844
##   tools/probe.sh field_drag_tablet_probe           a tablet's, 1024 x 768
##   ... --shots=DIR    the window as each is opened, to look at
##   ... --only=RE      only the containers whose names it finds (Properties|share)
##
## uifix (2026-10-31): a field takes a finger's press for itself (Godot's
## LineEdit accepts it, and its window focuses it first), so the list round
## it never heard a drag begin. On a phone or a tablet a panel full of
## fields (Properties, Settings, a dialog's form) scrolled only from the
## gaps between them, and a drag on one selected its words and put the
## keyboard up instead. FlingScroll, where a finger's drags are routed, now
## holds a finger's press on a field in a list until it is a tap, a hold or
## a drag.
##
## Here each container with fields a finger meets is opened as a person
## opens it: Properties with a part selected, Settings and its AI page, the
## parts' search, the assistant's drawer, and every dialog with a field the
## menus open (Find, the library's search, the command palette's and the
## rest). For each field showing in a list:
##   a drag begun on it moves the list with the finger (within a fifth of
##   how far the finger went, or to the list's end), and leaves the field
##   unfocused with nothing selected; in a list with nothing to scroll at
##   this size, it is left unfocused with nothing selected;
## and once in each list that scrolls:
##   a drag begun beside its fields moves it as far, the measure's own check;
##   a tap on a field focuses it, editing (the keyboard up), its caret where
##   the finger was (an empty field is given words for it);
##   a hold before the drag selects the field's words, and the list stays.
## A field in no list is counted and left as it is: a drag on it selects.
## One a finger there does not reach (under a sheet, or a button laid over
## it) is counted, not judged.
extends SceneTree

## The commands that open a dialog with a field, as the menus run them.
## Nothing that opens the system's file chooser, leaves the app or reaches
## the relay.
const OPENERS: Array[String] = [
	"save_as", "share", "library", "versions", "render", "pose", "select_find",
	"collection", "collection_need", "minifig", "mosaic", "brickify", "part_maker",
	"print_part", "sticker", "printed_versions", "floor_custom", "palette", "feedback",
	"account", "make_submodel", "pattern", "comments", "step_to", "reference", "keys",
]

## How far each drag goes, points.
const TRAVEL := 100.0
## A drag's list within this share of the finger's way.
const SLACK := 0.2

var _failures: int = 0
var _main: Node
var _shell: Shell
var _shots: String = ""
var _only: RegEx = null
var _shot: int = 0
## Each field looked at, by its id.
var _seen: Dictionary = {}
## Each list a tap and a hold were tried in, by its id.
var _tried: Dictionary = {}
var _counts: Dictionary = {"dragged": 0, "no list": 0, "nothing to scroll": 0,
	"out of sight": 0, "lists": 0}
## Where the finger is, in the window's input.
var _at := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


## Laid out for a tablet: field_drag_tablet_probe says so.
func _tablet() -> bool:
	return OS.get_cmdline_user_args().has("--tablet")


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Frames for [param ms] by the clock, two at least.
func _wait(ms: float) -> void:
	var began: int = Time.get_ticks_msec()
	await _frames(2)
	while Time.get_ticks_msec() - began < ms:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
		elif arg.begins_with("--only="):
			_only = RegEx.create_from_string(arg.trim_prefix("--only="))
	Phone._on = 1
	Phone._wide = _tablet()
	# A touch screen's: a list is dragged by a finger only where there is
	# one (ScrollContainer), and the app hears its touches as a browser's.
	Input.emulate_touch_from_mouse = true
	# Godot's own Save dialog, never the platform's.
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	# A phone draws at a browser's scale, as open_menu_reach_probe holds it.
	if not Phone.wide():
		(_main.get("_phone") as Node).set_process(false)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	var store: ModelStore = _main.get("_store")
	store.keeps = false
	_shell = _main.get("_shell")
	var room: Rect2 = root.get_visible_rect()
	print("\n  the window: %d x %d units, %s, FlingScroll %s" % [roundi(room.size.x),
		roundi(room.size.y), "a tablet's layout" if Phone.wide() else "a phone's layout",
		"in it" if _fling() != null else "NOT in it"])
	if not _check("the window is laid out for a finger, its drags routed by FlingScroll",
			_main.get("_phone") != null and _fling() != null):
		quit(1)
		return

	# A part selected, so the properties show it.
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick: int = world.add_brick("3001", 4, where)
	builder.register(brick, "3001", where)
	builder.select_brick(brick, false)
	await _frames(6)

	await _container("Properties", func() -> bool: return _shell.run("panel_properties"))
	await _container("Settings", func() -> bool: return _shell.run("settings"))
	var settings: ControlsDialog = _main.get("_controls")
	await _container("Settings, AI with a key of your own", func() -> bool:
		settings.open_ai()
		settings.ai.who_key.button_pressed = true
		return true)
	settings.ai.who_claude.button_pressed = true
	await _container("the parts' search", func() -> bool:
		(_main.get("_phone") as Node).call("_chose", "parts")
		return true)
	await _container("the assistant", func() -> bool:
		# Shown, its column opens.
		_main.call("set_assistant", true)
		var dock: SideDock = _main.get("_chat_dock")
		return dock.is_open() or _shell.run("panel_assistant"))
	for name: String in OPENERS:
		await _container(name, func() -> bool: return _shell.run(name))

	print("")
	print("  fields dragged in a list: %d, in %d lists; in no list: %d; in a list with nothing to scroll: %d; out of sight: %d"
		% [_counts["dragged"], _counts["lists"], _counts["no list"],
			_counts["nothing to scroll"], _counts["out of sight"]])
	_check("fields in lists that scroll were dragged (%d) in lists a tap and a hold were tried in (%d)"
		% [_counts["dragged"], _tried.size()], int(_counts["dragged"]) >= 5 and _tried.size() >= 3)
	if _failures == 0:
		print("field drag probe: a drag begun on a field scrolls its list as a drag beside it does; a tap and a hold are the field's")
	else:
		print("field drag probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _fling() -> FlingScroll:
	for child: Node in _main.get_children():
		if child is FlingScroll:
			return child
	return null


## Opens one with [param open], looks at each field it shows, and puts it
## away.
func _container(named: String, open: Callable) -> void:
	if _only != null and _only.search(named) == null:
		return
	var before: Dictionary = _shown()
	if not bool(open.call()):
		print("\n  --    %s cannot be opened now" % named)
		return
	await _frames(20)
	var fields: Array[LineEdit] = []
	_fields_in(root, fields)
	fields = fields.filter(func(field: LineEdit) -> bool: return not _seen.has(field.get_instance_id()))
	print("\n── %s: %d fields ──" % [named, fields.size()])
	_picture(named)
	for field: LineEdit in fields:
		_seen[field.get_instance_id()] = true
		if is_instance_valid(field) and field.is_visible_in_tree():
			await _field(named, field)
	await _put_away(before)


## A field: dragged by, and in each list once, tapped and held.
func _field(named: String, field: LineEdit) -> void:
	var what: String = "%s, %s" % [named, _named(field)]
	var list: ScrollContainer = _list_round(field)
	if list == null:
		_counts["no list"] += 1
		print("  --    %s: in no list" % what)
		return
	var room: float = _room(list)
	if not _in_sight(list, field):
		_centre(list, field)
		await _frames(4)
	if not _in_sight(list, field):
		_counts["out of sight"] += 1
		print("  --    %s: out of sight" % what)
		return
	await _settled(field)
	var centre: Vector2 = field.size / 2.0
	var over: Control = _hit(list, field.get_global_transform() * centre)
	if over != field:
		_counts["out of sight"] += 1
		print("  --    %s: under %s in its list" % [what, _named(over)])
		return
	if room < 1.0:
		_counts["nothing to scroll"] += 1
		if not (await _drag(list, field, centre))["heard"]:
			_counts["out of sight"] += 1
			print("  --    %s: under something in front of its list" % what)
			return
		_check("%s, in a list with nothing to scroll: a drag on it leaves it unfocused (%s), nothing selected (%s)"
			% [what, not field.has_focus(), not field.has_selection()],
			not field.has_focus() and not field.has_selection())
		_let_go(field)
		return
	var got: Dictionary = await _drag(list, field, centre)
	if not got["heard"]:
		_counts["out of sight"] += 1
		print("  --    %s: under something in front of its list" % what)
		return
	_counts["dragged"] += 1
	_check("%s: a drag on it moves its list %d of %d units, the field unfocused (%s), nothing selected (%s)"
		% [what, roundi(got["moved"]), roundi(got["wanted"]), not field.has_focus(), not field.has_selection()],
		_as_far(got) and not field.has_focus() and not field.has_selection())
	_let_go(field)
	await _frames(4)
	if _tried.has(list.get_instance_id()):
		return
	_tried[list.get_instance_id()] = true
	_counts["lists"] += 1
	# Beside its fields: the measure's own check.
	var gap: Dictionary = await _gap(list)
	if gap.is_empty():
		print("  --    %s: no gap between its list's fields to drag by" % what)
	else:
		var beside: Dictionary = await _drag(list, gap["control"], gap["at"])
		_check("%s: a drag beside the fields (on %s) moves the list %d of %d units"
			% [what, _named(gap["control"]), roundi(beside["moved"]), roundi(beside["wanted"])],
			_as_far(beside))
	await _tap(what, list, field)
	await _hold(what, list, field)


## Until [param control] has stood still three frames: a drawer or a sheet
## slides in.
func _settled(control: Control) -> void:
	var was: Vector2 = _window_at(control, Vector2.ZERO)
	var still: int = 0
	for _n: int in 90:
		await process_frame
		var now: Vector2 = _window_at(control, Vector2.ZERO)
		still = still + 1 if now.is_equal_approx(was) else 0
		was = now
		if still >= 3:
			return


## A finger's drag on [param control] at [param local] in [param list]: up
## where there is more of the list below, held still before it lifts so
## it does not glide. {moved, wanted, heard}: units the list went, the way
## the finger went, as far as the list could, and whether [param control]
## heard the finger come down.
func _drag(list: ScrollContainer, control: Control, local: Vector2) -> Dictionary:
	var heard: Array[bool] = [false]
	var hear := func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
			heard[0] = true
	control.gui_input.connect(hear)
	var from: int = list.scroll_vertical
	var room: float = _room(list)
	var up: bool = room - from >= from
	var units: float = Phone.px(root, TRAVEL) * (-1.0 if up else 1.0)
	var start: Vector2 = _window_at(control, local)
	var way: Vector2 = _window_at(control, local + Vector2(0, units)) - start
	_touch(start, true)
	await _frames(2)
	for step: int in 12:
		_move(start + way * (step + 1) / 12.0)
		await process_frame
	await _wait(250)
	_touch(_at, false)
	await _frames(20)
	var wanted: float = clampf(from - units, 0.0, room) - from
	if is_instance_valid(control):
		control.gui_input.disconnect(hear)
	return {"moved": float(list.scroll_vertical - from), "wanted": wanted, "heard": heard[0]}


static func _as_far(got: Dictionary) -> bool:
	var moved: float = got["moved"]
	var wanted: float = got["wanted"]
	return absf(moved - wanted) <= absf(wanted) * SLACK + 2.0 and absf(wanted) >= 1.0


## Words in an empty field for a caret to go along and a hold to select:
## its own text, else a number's or a few words.
static func _words_in(field: LineEdit) -> String:
	var was: String = field.text
	if was.is_empty():
		field.text = "12345" if field.get_parent() is SpinBox else "brick by brick"
	return was


## The field's far end, as far along as a finger there is on the field: off
## its × where it has one (the parts' search), which empties it, and off a
## button laid over it (the parts' search's photo).
func _far_end(list: ScrollContainer, field: LineEdit) -> Vector2:
	var room: float = Phone.px(root, 4.0)
	if field.clear_button_enabled:
		# As LineEdit finds its ×: the icon and the box's right margin.
		room += field.get_theme_icon(&"clear").get_width() \
			+ field.get_theme_stylebox(&"normal").get_margin(SIDE_RIGHT)
	var at := Vector2(field.size.x - room, field.size.y / 2.0)
	while at.x > field.size.x / 2.0 and _hit(list, field.get_global_transform() * at) != field:
		at.x -= Phone.px(root, 4.0)
	return at


## A tap at the field's far end: focused, editing, the caret at its end.
func _tap(what: String, list: ScrollContainer, field: LineEdit) -> void:
	_centre(list, field)
	await _frames(4)
	var was: String = _words_in(field)
	field.caret_column = 0
	var from: int = list.scroll_vertical
	var end: Vector2 = _far_end(list, field)
	_touch(_window_at(field, end), true)
	await _frames(3)
	_touch(_at, false)
	await _frames(8)
	var caret_ok: bool = field.caret_column == field.text.length()
	_check("%s: a tap on it focuses it (%s), editing (%s), its caret where the finger was (%d of %d), the list still (%d)"
		% [what, field.has_focus(), field.is_editing(), field.caret_column, field.text.length(),
			list.scroll_vertical - from],
		field.has_focus() and field.is_editing() and caret_ok and absi(list.scroll_vertical - from) <= 2)
	_let_go(field)
	field.text = was
	await _frames(4)


## A finger held still on the field, then drawn along it: its words
## selected, and the list where it was.
func _hold(what: String, list: ScrollContainer, field: LineEdit) -> void:
	_centre(list, field)
	await _frames(4)
	var was: String = _words_in(field)
	var from: int = list.scroll_vertical
	var start: Vector2 = _window_at(field, Vector2(Phone.px(root, 6.0), field.size.y / 2.0))
	var end: Vector2 = _window_at(field, _far_end(list, field))
	_touch(start, true)
	await _wait(800)
	for step: int in 8:
		_move(start + (end - start) * (step + 1) / 8.0)
		await process_frame
	await _frames(3)
	_touch(_at, false)
	await _frames(8)
	_check("%s: held, then drawn along: focused (%s), %s selected, the list still (%d)"
		% [what, field.has_focus(), "\"%s\"" % field.get_selected_text() if field.has_selection()
			else "NOTHING", list.scroll_vertical - from],
		field.has_focus() and field.has_selection() and absi(list.scroll_vertical - from) <= 2)
	_let_go(field)
	field.text = was
	await _frames(4)


func _let_go(field: LineEdit) -> void:
	if is_instance_valid(field):
		field.deselect()
		if field.has_focus():
			field.release_focus()


## A place in [param list], on screen, under no field: {control, at}, the
## control a finger there is on and the place in it; empty where there is
## none.
func _gap(list: ScrollContainer) -> Dictionary:
	var rect: Rect2 = list.get_global_rect()
	for across: float in [0.5, 0.15, 0.85]:
		for down: float in [0.5, 0.3, 0.7, 0.15, 0.85]:
			var point: Vector2 = rect.position + Vector2(rect.size.x * across, rect.size.y * down)
			var over: Control = _hit(list, point)
			if over == null or over is LineEdit or over is ScrollBar or _field_round(over) != null:
				continue
			# Nor a button laid on a button: a drag begun on the parts' "+N"
			# on a tile scrolls nothing, with FlingScroll's fields or without (the tile
			# scrolls the grid itself, PartsBin._cell_input; its "+N" not).
			if over is BaseButton and over.get_parent() is BaseButton:
				continue
			# Nor what scrolls itself (the AI page's list of models): a drag
			# there scrolls it, not the list round it.
			if _scrolls_itself(over, list):
				continue
			return {"control": over, "at": over.get_global_transform().affine_inverse() * point}
	return {}


static func _scrolls_itself(control: Control, list: ScrollContainer) -> bool:
	var up: Node = control
	while up != null and up != list:
		if up is ItemList or up is Tree or up is TextEdit or up is ScrollContainer:
			return true
		up = up.get_parent()
	return false


static func _field_round(control: Control) -> LineEdit:
	var up: Node = control
	while up != null and not up is Window:
		if up is LineEdit:
			return up
		up = up.get_parent()
	return null


## The control a finger at [param point] (its window's canvas) in
## [param control] comes down on, as the window finds it: the last drawn
## that has the point, through what clips it. Not the window's hover: a
## mouse's move, parsed or pushed, left that where the last finger was.
static func _hit(control: Control, point: Vector2) -> Control:
	if not control.visible:
		return null
	var inside: bool = control.get_global_rect().has_point(point)
	if control.clip_contents and not inside:
		return null
	for n: int in range(control.get_child_count(true) - 1, -1, -1):
		var child := control.get_child(n, true) as Control
		if child == null or child.top_level:
			continue
		var found: Control = _hit(child, point)
		if found != null:
			return found
	if inside and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return control
	return null


## A finger down or up at [param at], in the window's input.
func _touch(at: Vector2, pressed: bool) -> void:
	_at = at
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)


func _move(to: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = to
	drag.relative = to - _at
	drag.screen_relative = drag.relative
	_at = to
	Input.parse_input_event(drag)


## [param local] in [param control] in the window's input: through each
## window it is embedded in (its screen transform, in the main window's
## units), then the main window's stretch.
func _window_at(control: Control, local: Vector2) -> Vector2:
	return root.get_final_transform() * (control.get_screen_transform() * local)


## The list a finger's drag on [param control] scrolls up and down.
static func _list_round(control: Control) -> ScrollContainer:
	var up: Node = control.get_parent()
	while up != null and not up is Window:
		var list := up as ScrollContainer
		if list != null and list.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return list
		up = up.get_parent()
	return null


static func _room(list: ScrollContainer) -> float:
	var bar: VScrollBar = list.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


## Wholly inside its list's room and the window.
func _in_sight(list: ScrollContainer, field: LineEdit) -> bool:
	var rect: Rect2 = field.get_global_rect()
	if not list.get_global_rect().grow(1.0).encloses(rect):
		return false
	var top_left: Vector2 = _window_at(field, Vector2.ZERO)
	var foot: Vector2 = _window_at(field, field.size)
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(DisplayServer.window_get_size())).grow(1.0)
	return screen.has_point(top_left) and screen.has_point(foot)


## The list scrolled to [param field], in the middle of its room.
func _centre(list: ScrollContainer, field: LineEdit) -> void:
	var down: float = field.get_global_rect().get_center().y - list.get_global_rect().position.y \
		+ list.scroll_vertical
	list.scroll_vertical = roundi(clampf(down - list.size.y / 2.0, 0.0, _room(list)))


func _fields_in(node: Node, out: Array[LineEdit]) -> void:
	if node is Window and node != root and not (node as Window).visible:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	var field := node as LineEdit
	if field != null and field.is_visible_in_tree() and field.size.x >= 1.0 and field.size.y >= 1.0:
		out.append(field)
	for child: Node in node.get_children(true):
		_fields_in(child, out)


static func _named(control: Control) -> String:
	if control == null:
		return "nothing"
	var field := control as LineEdit
	var words: String = ""
	if field != null:
		words = field.placeholder_text if not field.placeholder_text.is_empty() else field.text
	if words.is_empty() and control.get_parent() is SpinBox:
		words = (control.get_parent() as SpinBox).accessibility_name
	if words.is_empty():
		words = control.accessibility_name
	if words.is_empty() and control is Button:
		words = (control as Button).text
	return "%s \"%s\"" % [control.get_class(), words.left(30)] if not words.is_empty() \
		else "%s %s" % [control.get_class(), control.name]


func _picture(named: String) -> void:
	if _shots.is_empty():
		return
	_shot += 1
	var image: Image = root.get_texture().get_image()
	image.save_png("%s/%02d_%s.png" % [_shots, _shot, named.validate_filename().replace(" ", "_")])


## Put away: Escape first, as a person would; the drawers and the phone's
## sheets closed; then any window still up that was not before.
func _put_away(before: Dictionary) -> void:
	_key(KEY_ESCAPE)
	await _frames(4)
	for dock_name: String in ["_bin_dock", "_chat_dock"]:
		var dock: SideDock = _main.get(dock_name)
		if dock != null and dock.is_open():
			dock.set_open(false, false)
	var phone: Node = _main.get("_phone")
	for sheet: Variant in phone.get("_sheets"):
		if sheet != null and bool(sheet.call("is_open")):
			sheet.call("close", false)
	await _frames(4)
	var touch: Node = _main.get("_touch")
	var open: Array = (touch.get("_open") as Array).duplicate() if touch != null else []
	for id: int in _shown():
		if before.has(id):
			continue
		var thing: Object = instance_from_id(id)
		if thing is AcceptDialog and (thing as Window).visible:
			(thing as Window).close_requested.emit()
		if thing is Window and (thing as Window).visible:
			(thing as Window).hide()
	for dialog: Variant in open:
		if dialog is Control and is_instance_valid(dialog) and (dialog as Control).visible:
			(dialog as Control).visible = false
	await _frames(6)


## The windows showing, by id.
func _shown() -> Dictionary:
	var out: Dictionary = {}
	_gather_windows(root, out)
	return out


func _gather_windows(node: Node, out: Dictionary) -> void:
	if node is Window and node != root:
		if (node as Window).visible:
			out[node.get_instance_id()] = true
	for child: Node in node.get_children(true):
		_gather_windows(child, out)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
