## Does a tooltip ever take a click meant for what is under it?
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" \
##     godot --path . --resolution 1400x900 --script src/dev/tooltip_probe.gd
##   … -- --no-sweep          the three stacks alone, without the panels
##
## Account's "Open in Claude" had its tooltip open over "Disconnect Claude"
## below it, and the click meant for Disconnect went to the tooltip, every
## time (oauth_flow, 2026-10-15). In the real scene, with the app's own
## window (Tooltips), this stacks a link with a tooltip over a button, rests
## the pointer on the link until its tooltip is up over the button, and
## clicks the button through it: moved and then clicked, as a hand does, and
## moved and clicked in one go, as Playwright and a quick hand on the web do,
## a frame's input coming in one batch there. The same in a dialog, a window
## of its own, and in a menu, where the press on a tooltip took the menu's
## focus and closed it.
##
## Then every panel a person opens: the window as it opens, the parts bin,
## Properties, the assistant, Account, Settings and Render, each control
## with a tooltip rested on until it shows. Where its tooltip covers
## something that takes a click, that is pressed through it in one go, the
## press caught at the control and kept from doing anything, and must reach
## it. The menus' rows are said, not pressed: a row pressed runs its
## command.
extends SceneTree

## At most this many controls with a tooltip are rested on in one panel.
const MOST_IN_A_PANEL := 40

## Whether this is a screen nobody is looking at, so the system's pointer
## is the probe's to move (as cursor_probe): xvfb-run keeps its authority
## file in a directory of its own name.
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")

var _failures: int = 0
var _main: Node
var _presses: int = 0
var _menu_pressed: int = -1
var _caught: Control = null
## [panel, owner, what its tooltip covered] for the summary.
var _found: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)

	print("two controls stacked, in the window")
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var pair: Array[Control] = _stack(holder, Vector2(520, 260))
	for together: bool in [false, true]:
		await _click_through(pair[0], pair[1], together)

	print("...in a dialog")
	var dialog := AcceptDialog.new()
	dialog.title = "A dialog"
	dialog.exclusive = false
	var inside := Control.new()
	inside.custom_minimum_size = Vector2(320, 120)
	dialog.add_child(inside)
	root.add_child(dialog)
	var in_dialog: Array[Control] = _stack(inside, Vector2(20, 10))
	dialog.popup_centered()
	await _frames(10)
	for together: bool in [false, true]:
		await _click_through(in_dialog[0], in_dialog[1], together)
	_check("...and the dialog is still open", dialog.visible)
	dialog.hide()
	await _frames(5)

	print("...in a menu")
	await _menu_through()

	if not OS.get_cmdline_user_args().has("--no-sweep"):
		await _sweep()

	print("")
	print("%d FAILURE(S)" % _failures if _failures
		else "a tooltip never took a click meant for what is under it")
	quit(1 if _failures else 0)


## A link with a tooltip over a button with one, as Account had them.
func _stack(parent: Control, at: Vector2) -> Array[Control]:
	var column := VBoxContainer.new()
	column.position = at
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var upper := LinkButton.new()
	upper.text = "Open in Claude"
	upper.tooltip_text = "Opens claude.ai with Brickworks filled in"
	column.add_child(upper)
	var lower := Button.new()
	lower.text = "Disconnect Claude"
	lower.tooltip_text = "Claude can no longer reach your Brickworks"
	lower.pressed.connect(func() -> void: _presses += 1)
	column.add_child(lower)
	return [upper, lower]


func _click_through(upper: Control, lower: Control, together: bool) -> void:
	var how: String = "moved and clicked in one go" if together else "moved, then clicked"
	var tip: Window = await _tooltip_of(upper)
	var spot: Vector2 = _spot_in(tip, lower)
	_check("the link's tooltip is up over the button (%s)" % how, spot.x >= 0.0)
	if spot.x < 0.0:
		return
	var before: int = _presses
	await _press_at(spot, together)
	_check("...and a click on the button through it presses the button (%s): %d press(es)"
		% [how, _presses - before], _presses - before == 1)
	_move(_away())
	await _frames(20)


## A menu whose first row's tooltip covers the second row, the second
## pressed through it.
func _menu_through() -> void:
	var menu := PopupMenu.new()
	for n: int in 4:
		menu.add_item("Row %d of the menu" % n, n)
		menu.set_item_tooltip(n, "What row %d does, said at some length" % n)
	menu.id_pressed.connect(func(id: int) -> void: _menu_pressed = id)
	root.add_child(menu)
	menu.popup(Rect2i(700, 300, 0, 0))
	await _frames(10)
	var row: float = (menu.size.y - _margins(menu)) / float(menu.item_count)
	var top: float = menu.position.y + menu.get_theme_stylebox("panel").get_margin(SIDE_TOP)
	var first := Rect2(menu.position.x, top, menu.size.x, row)
	var second := Rect2(menu.position.x, top + row, menu.size.x, row)
	_move(Vector2(first.get_center().x - 40.0, first.end.y - 3.0))
	await _frames(3)
	_move(Vector2(first.get_center().x - 39.0, first.end.y - 3.0))
	var tip: Window = await _wait_for_tooltip()
	var spot: Vector2 = Vector2(-1, -1)
	if tip != null:
		var both: Rect2 = _rect_of(tip).intersection(second)
		if both.size.x > 2.0 and both.size.y > 2.0:
			spot = both.get_center()
	_check("the first row's tooltip is up over the second row", spot.x >= 0.0)
	if spot.x >= 0.0:
		_menu_pressed = -1
		await _press_at(spot, true)
		_check("...and a click on the second row through it chooses it: %d" % _menu_pressed,
			_menu_pressed == 1)
	menu.hide()
	menu.queue_free()
	_move(_away())
	await _frames(10)


func _margins(menu: PopupMenu) -> float:
	var panel: StyleBox = menu.get_theme_stylebox("panel")
	return panel.get_margin(SIDE_TOP) + panel.get_margin(SIDE_BOTTOM)


# -- every panel ---------------------------------------------------------------


func _sweep() -> void:
	var shell: Shell = _main.get("_shell")
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var bin_dock: SideDock = _main.get("_bin_dock")
	bin_dock.set_open(true, false)
	await _frames(20)
	await _panel("the window", root)
	# Properties: the right-hand column's panel of what is selected.
	SideDock.of(shell.inspector).set_open(true, false)
	for brick: BrickWorld.Brick in world.bricks():
		if builder.select_brick(brick.id, false):
			break
	await _frames(20)
	await _panel("Properties", shell.inspector)
	builder.selection.clear()
	builder.selection_changed.emit(0)
	_main.call("set_assistant", true)
	var chat_dock: SideDock = _main.get("_chat_dock")
	chat_dock.set_open(true, false)
	await _frames(20)
	await _panel("the assistant", _main.get("_chat"))
	var account: AccountPanel = _main.get("_account_panel")
	account.open()
	await _frames(10)
	await _panel("Account", account)
	account.visible = false
	var controls: ControlsDialog = _main.get("_controls")
	controls.open()
	await _frames(10)
	await _panel("Settings", controls)
	controls.visible = false
	var render: RenderDialog = _main.get("_render")
	render.open()
	await _frames(10)
	await _panel("Render", render)
	render.close()
	await _frames(10)
	for title: String in ["File", "Edit", "View", "Build", "Make", "Tools", "Help"]:
		var button: MenuButton = shell.menu(title)
		if button != null:
			await _rows(title, button.get_popup())

	print("")
	print("  where a tooltip covered something that takes a click (%d):" % _found.size())
	for one: Array in _found:
		print("    %s: %s covered %s" % one)


## Every control in [param panel] with a tooltip, rested on until it shows;
## and where it covers something that takes a click, a click on that in
## one go through it.
func _panel(name: String, panel: Node) -> void:
	var owners: Array[Control] = []
	_owners_in(panel, owners)
	var rested: int = 0
	var shown: int = 0
	var covering: int = 0
	for owner: Control in owners.slice(0, MOST_IN_A_PANEL):
		if not owner.is_visible_in_tree():
			continue
		rested += 1
		var tip: Window = await _tooltip_of(owner)
		if tip == null:
			var over: Control = root.gui_get_hovered_control()
			print("    (no tooltip over %s: the pointer was over %s)" % [_named(owner),
				_named(over) if over != null else "nothing of the window's"])
			continue
		shown += 1
		var cover: Rect2 = _rect_of(tip)
		for under: Control in _clickable_under(cover, owner):
			var spot: Vector2 = _rect_of_control(under).intersection(cover).get_center()
			# What the pointer finds there with no tooltip up: the control
			# a click there is meant for.
			_move(_away())
			await _frames(3)
			_move(spot)
			await _frames(3)
			var meant: Control = root.gui_get_hovered_control()
			if meant == null or not _takes_clicks(meant):
				continue
			tip = await _tooltip_of(owner)
			if tip == null or not _rect_of(tip).has_point(spot):
				continue
			covering += 1
			_found.append([name, _named(owner), _named(meant)])
			var reached: bool = await _caught_press(meant, spot)
			_check("%s: %s's tooltip over %s, a click on it through the tooltip reaches it"
				% [name, _named(owner), _named(meant)], reached)
			break
	print("  %s: %d controls with a tooltip rested on, %d tooltips shown, %d over something that takes a click"
		% [name, rested, shown, covering])


## A menu's rows whose tooltip covers another row, said.
func _rows(title: String, menu: PopupMenu) -> void:
	var tipped: int = 0
	for index: int in menu.item_count:
		if not menu.get_item_tooltip(index).is_empty() and not menu.is_item_separator(index):
			tipped += 1
	if tipped == 0:
		print("  the %s menu: no row has a tooltip" % title)
		return
	menu.popup(Rect2i(300, 120, 0, 0))
	await _frames(10)
	var rows: int = menu.item_count
	var row: float = (menu.size.y - _margins(menu)) / float(rows)
	var top: float = menu.position.y + menu.get_theme_stylebox("panel").get_margin(SIDE_TOP)
	var covered: int = 0
	var looked: int = 0
	for index: int in rows:
		if menu.get_item_tooltip(index).is_empty() or looked >= 6:
			continue
		looked += 1
		var at := Vector2(menu.position.x + menu.size.x * 0.3, top + row * (index + 0.5))
		_move(at)
		await _frames(3)
		_move(at + Vector2(1, 0))
		var tip: Window = await _wait_for_tooltip()
		if tip != null and _rect_of(tip).end.y > top + row * (index + 1) + 2.0 and index + 1 < rows:
			covered += 1
			_found.append(["the %s menu" % title, "\"%s\"" % menu.get_item_text(index),
				"the row under it"])
	menu.hide()
	_move(_away())
	await _frames(10)
	print("  the %s menu: %d rows with a tooltip, %d looked at, %d covering the row under them"
		% [title, tipped, looked, covered])


func _owners_in(node: Node, out: Array[Control]) -> void:
	if node is Window and node != root:
		return
	if node is CanvasLayer and node.get_parent() == root and node != _main.get_node_or_null("HUD"):
		return
	if node is Control:
		var control: Control = node
		if not control.is_visible_in_tree():
			return
		if not control.tooltip_text.strip_edges().is_empty() \
				and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and control.size.x >= 4.0 and control.size.y >= 4.0 \
				and root.get_visible_rect().encloses(_rect_of_control(control)):
			out.append(control)
	for child: Node in node.get_children():
		_owners_in(child, out)


## Clickable controls whose rectangle [param cover] overlaps, other than
## [param owner] and what holds it or is in it.
func _clickable_under(cover: Rect2, owner: Control) -> Array[Control]:
	var all: Array[Control] = []
	_clickable_in(_main.get_node("HUD"), all)
	var out: Array[Control] = []
	for control: Control in all:
		if control == owner or control.is_ancestor_of(owner) or owner.is_ancestor_of(control):
			continue
		var both: Rect2 = _rect_of_control(control).intersection(cover)
		if both.size.x >= 3.0 and both.size.y >= 3.0:
			out.append(control)
	return out


func _clickable_in(node: Node, out: Array[Control]) -> void:
	if node is Window:
		return
	if node is Control:
		var control: Control = node
		if not control.is_visible_in_tree():
			return
		if _takes_clicks(control):
			out.append(control)
	for child: Node in node.get_children():
		_clickable_in(child, out)


func _takes_clicks(control: Control) -> bool:
	return control.mouse_filter != Control.MOUSE_FILTER_IGNORE and (control is BaseButton
		or control is LineEdit or control is TextEdit or control is Range
		or control is ItemList or control is Tree or control is TabBar)


## A press and a release at [param spot] in one go, caught at
## [param meant] and kept from doing anything: whether it got there, and a
## button with the pointer over it, as the window saw it. A button only takes
## a press while the pointer is over it, and a pointer on a tooltip is over
## the tooltip: the press reached Disconnect Claude, which did nothing with
## it. A text field or a list takes the press either way.
func _caught_press(meant: Control, spot: Vector2) -> bool:
	_caught = null
	var catch := func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var over: Control = meant.get_viewport().gui_get_hovered_control()
			var hovered: bool = over != null and (over == meant or meant.is_ancestor_of(over))
			if (event as InputEventMouseButton).pressed and (hovered or not (meant is BaseButton)):
				_caught = meant
			meant.accept_event()
	meant.gui_input.connect(catch)
	await _press_at(spot, true)
	meant.gui_input.disconnect(catch)
	_move(_away())
	await _frames(5)
	return _caught == meant


func _named(control: Control) -> String:
	var words: String = ""
	for property: String in ["text", "tooltip_text"]:
		var value: Variant = control.get(property)
		if typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty():
			words = str(value).strip_edges().get_slice("\n", 0).left(40)
			break
	return "%s \"%s\"" % [control.get_class(), words]


# -- the pointer -----------------------------------------------------------------


## [param control] rested on until its tooltip is up: the pointer near its
## foot, where a tooltip opens over what is below.
func _tooltip_of(control: Control) -> Window:
	_move(_away())
	await _frames(3)
	var rect: Rect2 = _rect_of_control(control)
	var at := Vector2(rect.get_center().x, rect.end.y - minf(3.0, rect.size.y / 2.0))
	_move(at)
	await _frames(3)
	_move(at + Vector2(1, 0))
	return await _wait_for_tooltip()


func _wait_for_tooltip() -> Window:
	var until: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < until:
		await process_frame
		for sub: Window in root.get_embedded_subwindows():
			if _is_tooltip(sub) and sub.visible:
				await _frames(2)
				return sub
	return null


## The engine's own tooltip: the probe asks without the app's help, so it
## reads the same on a build from before Tooltips.
func _is_tooltip(window: Window) -> bool:
	return window is PopupPanel and (window as PopupPanel).theme_type_variation == &"TooltipPanel"


## Where the pointer goes to rest between tries: over the model, where
## nothing has a tooltip.
func _away() -> Vector2:
	return root.get_visible_rect().size * Vector2(0.55, 0.62)


## A point inside both [param tip] and [param under], or (-1, -1).
func _spot_in(tip: Window, under: Control) -> Vector2:
	if tip == null:
		return Vector2(-1, -1)
	var both: Rect2 = _rect_of(tip).intersection(_rect_of_control(under))
	if both.size.x < 2.0 or both.size.y < 2.0:
		return Vector2(-1, -1)
	return both.get_center()


func _press_at(spot: Vector2, together: bool) -> void:
	_move(spot)
	if not together:
		await _frames(3)
	_button(spot, true)
	if not together:
		await _frames(2)
	_button(spot, false)
	await _frames(6)


## In the window's own units, as its embedded windows are placed.
func _rect_of(window: Window) -> Rect2:
	return Rect2(Vector2(window.position), Vector2(window.size))


## In the window's own units too, wherever it is: in a dialog, a window of
## its own, its global rectangle is the dialog's, not the window's. (The
## window embeds the others, so their "screen" is its own units.)
func _rect_of_control(control: Control) -> Rect2:
	return control.get_screen_transform() * Rect2(Vector2.ZERO, control.size)


func _as_event(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


## The pointer moved, as an event and, on Xvfb, for real: the app replays a
## motion where the system says the pointer is whenever the control under
## it changes (Cursors._process). Moved only by events, the system's pointer
## sat in the middle of Xvfb's screen, the replay took the pointer off the
## link as soon as it got there, and no tooltip ever came (2026-10-18). A
## hand's pointer and its events are in one place.
func _move(at: Vector2) -> void:
	if _virtual:
		Input.warp_mouse(_as_event(at))
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, held: bool) -> void:
	print("  %s %s" % ["ok  " if held else "FAIL", what])
	if not held:
		_failures += 1
