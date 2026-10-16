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


## Whether [param window] is a tooltip the engine put up.
static func is_tooltip(window: Window) -> bool:
	return window is PopupPanel and (window as PopupPanel).theme_type_variation == &"TooltipPanel"
