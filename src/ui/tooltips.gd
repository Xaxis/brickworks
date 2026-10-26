## Tooltips that never take a click meant for what is under them.
##
## Account's "Open in Claude" link had its tooltip open over "Disconnect
## Claude" below it, and the click went to the tooltip, every time
## (oauth_flow, 2026-10-15). A Godot tooltip is a little window of its own,
## embedded in the app's: its mouse_passthrough flag is honoured for input
## but not for which window the pointer is over. The pointer that lands on
## it leaves the button underneath unhovered, and a button that is not
## hovered ignores a press. A plain tooltip does close when the pointer
## enters it, but only at the end of the frame: a move and a click in one
## frame (Playwright's, or a quick hand on the web, where a frame's input
## comes in one batch) still found it there. And a press on a tooltip over
## a dialog or a menu took the window's focus away from it, which closes a
## menu.
##
## So it goes before the window routes the event: every press closes it,
## and so does a pointer moving onto it. Hidden, it is out of the window's
## list at once; freed after.
class_name Tooltips
extends RefCounted


static var _windows: Dictionary = {}


## For every event [param window] is given, ahead of the window itself.
static func let_clicks_through(window: Window) -> void:
	if _windows.has(window.get_instance_id()):
		return
	_windows[window.get_instance_id()] = true
	window.window_input.connect(func(event: InputEvent) -> void: Tooltips._before(event, window))


static func _before(event: InputEvent, window: Window) -> void:
	var pointer: InputEventMouse = event as InputEventMouse
	var pressed: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) \
		and event.is_pressed()
	if pointer == null and not pressed:
		return
	# The window's units, which its embedded windows are placed in: the
	# event comes in the screen's.
	var at: Vector2 = Vector2(-1, -1)
	if pointer != null:
		at = window.get_final_transform().affine_inverse() * pointer.position
	for sub: Window in window.get_embedded_subwindows():
		if not is_tooltip(sub) or not sub.visible:
			continue
		if pressed or Rect2(Vector2(sub.position), Vector2(sub.size)).has_point(at):
			sub.hide()
			sub.queue_free()


## And every tooltip put up in [param window] kept inside it: one longer
## than [constant WIDEST] is laid out as lines that wide, or the window's
## width where that is less. Godot draws a tooltip's text as it is, one
## line a line, where it goes past the window's edge: a technique's ran
## off the window at 1280 (walk256 TQ1).
static func keep_inside(window: Window) -> void:
	var tree: SceneTree = window.get_tree()
	if tree == null or tree.node_added.is_connected(_added):
		return
	tree.node_added.connect(_added)


## The widest a tooltip's line is, in the window's units, and how far it
## keeps from the window's edges.
const WIDEST := 480.0
const EDGE := 8.0


static func _added(node: Node) -> void:
	if node is Window and is_tooltip(node as Window):
		# Once Godot has sized and placed it, which it does after adding it.
		_fit.call_deferred(node)


static func _fit(popup: Window) -> void:
	if not is_instance_valid(popup) or not popup.is_inside_tree():
		return
	var label: Label = null
	for child: Node in popup.get_children():
		if child is Label:
			label = child
			break
	# Placed in the window it is embedded in, the app's, a dialog's too.
	if label == null or not popup.is_embedded():
		return
	var room: Rect2 = popup.get_tree().root.get_visible_rect()
	var widest: float = minf(WIDEST, room.size.x - 2.0 * EDGE - (popup.size.x - label.size.x))
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var longest: float = 0.0
	for line: String in label.text.split("\n"):
		longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if longest > widest and widest > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = widest
		popup.size = Vector2i(popup.get_contents_minimum_size().ceil())
	var at := Vector2(popup.position)
	at.x = clampf(at.x, room.position.x + EDGE, maxf(room.position.x + EDGE, room.end.x - popup.size.x - EDGE))
	at.y = clampf(at.y, room.position.y + EDGE, maxf(room.position.y + EDGE, room.end.y - popup.size.y - EDGE))
	popup.position = Vector2i(at.round())


## Whether [param window] is a tooltip the engine put up.
static func is_tooltip(window: Window) -> bool:
	return window is PopupPanel and (window as PopupPanel).theme_type_variation == &"TooltipPanel"
